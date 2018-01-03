;===============================================================================
;+
; Copyright © 2014, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; get_gridded_gr_rain_type.pro    Morris/SAIC/GPM_GV    April 2014
;
; DESCRIPTION
; -----------
; Takes 3-D gridded (z,x,y) grids of GR reflectivity and height data, converts
; them to 2-D arrays of GR reflectivity and height data where the first dimension
; is the horizontal location and the second is the along-vertical dimension;
; and a set of array indices defining the set of points under consideration for
; one level of the grid arrays. Extracts vertical profiles of GR reflectivity for
; these points, and examines the vertical profiles to determine a GR rain type.
;
; Stratiform rain type is indicated by either low reflectivity values all along
; the profile or the clear presence of an elevated reflectivity maximum in a
; reasonable range of possible bright band heights.  Convective rain is
; indicated by high reflectivity values nearly constant at the lower levels or
; continuously decreasing with increasing height.
;
; Locations where none of these criteria are clear are given a rain type value
; of Other.  Rain type category values are as defined in the file pr_params.inc.
;
; PARAMETERS
; ----------
; idx_in     - INPUT: Indices into one level of the gvz and height arrays
;              indicating the points to be evaluated.  idx_in are provided
;              in terms of 1-D IDL indices of the lowest layer of the full
;              gvz grid.
; gvz        - INPUT: 3-D (z,x,y) grid of averaged Ground Radar reflectivity
;              for each GR sweep level, averaged over 4km gridpoints.
; top        - INPUT: GR beam top height of each sample in the gvz array, in km.
; botm       - INPUT: GR beam bottom of each sample in the gvz array, in km.
; verbose    - INPUT: Indicates whether and which diagnostic PRINT messages to
;              activate.
; meanBB     - INPUT/OUTPUT: Mean bright band height computed by this function.
;              If a parameter is provided, the mean BB height is returned in it.
;
; HISTORY
; -------
; 06/20/11 Morris, GPM GV, SAIC
; - Created from get_gr_geo_match_rain_type.pro.  Modified original program as
;   little as possible, so there are some clunky things in this version of the
;   program (rays, scans, grid dimension reversing, etc.).
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;===============================================================================

FUNCTION get_gridded_gr_rain_type, idx_in, gvz, top, botm, MEANBB=meanBB, $
                                   VERBOSE=verbose

@pr_params.inc   ; for GPM VN rain type category values

IF N_ELEMENTS( verbose ) EQ 0 THEN verbose=0   ; set to No Diagnostic Print

   sgvz = SIZE(gvz, /DIMENSIONS)
   if n_elements(sgvz) NE 3 then message, "Don't have a 3D gvz grid."
   if sgvz[0] GE MIN(sgvz[1:2]) then message, "More vertical layers than horizontal, this ain't kosher."

   ; Build the corresponding scan and ray numbers for points defined by idx_in:

   rainTypeOut = MAKE_ARRAY( N_ELEMENTS(idx_in), /INTEGER, VALUE=RainType_no_rain )
   nfooties = n_elements(idx_in)

  ; expand this subset of grid master indices into its scan,ray (x,y) coordinates.
   onelayer = REFORM(gvz[0,*,*])
   rayscan = ARRAY_INDICES(onelayer,idx_in)
   raypr = rayscan[0,*]
   scanpr = rayscan[1,*]

  ; convert gvz, top, and botm grids to 2 dimensions, with the second being z
   gvzprofiles = fltarr(N_ELEMENTS(idx_in),sgvz[0])
   topprofiles = gvzprofiles
   botmprofiles = gvzprofiles

   for zlev = 0, sgvz[0]-1 do begin
      onelayer = REFORM(gvz[zlev,*,*], sgvz[1]*sgvz[2])
      gvzprofiles[*,zlev] = onelayer[idx_in]
      onelayer = REFORM(top[zlev,*,*], sgvz[1]*sgvz[2])
      topprofiles[*,zlev] = onelayer[idx_in]
      onelayer = REFORM(botm[zlev,*,*], sgvz[1]*sgvz[2])
      botmprofiles[*,zlev] = onelayer[idx_in]
   endfor

S = SIZE(gvz, /DIMENSIONS)
nvols = S[1]

; initialize the array of computed GR rain types to be returned
grRainType = MAKE_ARRAY( nfooties, /INTEGER, VALUE=RainType_no_rain )
; and an array of BB heights and reflectivity found
BBhgtByRay = FLTARR(3,nfooties)   ; tally the BB top, bottom, and center heights
BB_Z_ByRay = FLTARR(nfooties)

hgtprofiles = (topprofiles + botmprofiles) / 2.

bbhgt = 0.0  ; 
for ifoot = 0, nfooties-1 DO BEGIN
   IF verbose GT 0 THEN $
      print, "===================== RAY ", STRING(ifoot+1, FORMAT='(I0)'), " ====================="
  ; grab the individual profile at the footprint
   gvprofile_all=REFORM(gvzprofiles[ifoot,*])
   hgtprofile_all=REFORM(hgtprofiles[ifoot,*])

  ; compute max height of the samples, so that we can skip
  ; locations where insufficient data exist to determine rain type
   profilehgt = MAX(hgtprofile_all)

  ; do we have any actual reflectivity values in this profile?  If so, grab just
  ; these samples for evaluation
   idxactual = WHERE(gvprofile_all GT 0.0, countactual)
   IF (countactual LT 2) THEN BEGIN
      IF ( MAX(gvprofile_all) GT 15.0 ) THEN BEGIN
         IF verbose GT 0 THEN print, "Only ", STRING(countactual, FORMAT='(I0)'), $
                               " 15 dBZ+ values in ray "+STRING(ifoot, FORMAT='(I0)') $
                               +", set to Other RainType."
         grRainType[ifoot] = RainType_other
;print, "gvprofile_all:", gvprofile_all
;stop
      ENDIF ELSE IF verbose GT 0 THEN print, "No > 15 dBZ values in ray "+STRING(ifoot, FORMAT='(I0)') $
                                       +", set to RainType_no_rain"
;print, "gvprofile_all:", gvprofile_all
;stop
      CONTINUE   ; leave profile as Other, skip to next ray
   ENDIF ELSE BEGIN
      gvprofile = gvprofile_all[idxactual]
      hgtprofile = hgtprofile_all[idxactual]
     ; compute sample depths for this ray -- use min difference between sample
     ; center heights to best assure we are looking at adjacent samples
      avgdepth = MIN(hgtprofile[1:countactual-1]-hgtprofile[0:countactual-2])
   ENDELSE

  ; look for the convective-by-threshold cases
   max_z = MAX(gvprofile, idxmax)
   IF max_z GE 45.0 THEN BEGIN
     ; look at the reflectivity below the max, if it drops off significantly
     ; then don't call it convective just yet
      IF idxmax GT 0 THEN mean_z_below = MEAN(gvprofile[0:idxmax-1]) $
      ELSE mean_z_below = max_z
      IF (max_z - mean_z_below) LT max_z/12.0 THEN BEGIN
         grRainType[ifoot] = RainType_convective
         IF verbose GT 0 THEN print, "Certain convective by 45 dBZ threshold"
         CONTINUE   ; skip to next ray
      ENDIF ELSE IF verbose GT 0 THEN print, $
            "Reserving judgement on max column dBZ of ", STRING(max_z, format='(F0.1)')
   ENDIF

; if not convective by threshold, skip rain type determination for points too
; near the radar, as determined by depth of samples (range-dependent)
   IF profilehgt LT 5.5 THEN BEGIN
      grRainType[ifoot] = RainType_other
      IF verbose GT 0 THEN print, "Profile too shallow, sample depths = ", STRING(avgdepth, format='(F0.1)'), $
       ", leaving ray as Other."
      CONTINUE
   ENDIF
  ; look for the stratiform-by-threshold cases
   IF MAX(gvprofile) LE 25.0 THEN BEGIN
      grRainType[ifoot] = RainType_stratiform
      IF verbose GT 0 THEN print, "Certain stratiform by 25 dBZ threshold"
      CONTINUE
   ENDIF

   IF ( countactual LT 3 ) THEN BEGIN
      grRainType[ifoot] = RainType_other
      CONTINUE
   ENDIF ELSE BEGIN
      is_bb = INTARR(countactual-1)   ; use to track BB signatures
     ; look at the reflectivity profile
     ; -- first, define a threshold BB enhancement based on overall reflectivity
      bbThreshBase = 1.5 ; dBZ/km
     ; where/what is the maximum gvz value?
      gvmax = MAX( gvprofile[idxactual], idxmax )
      hgtmax = hgtprofile[idxmax]
      IF hgtmax GT 6.5 THEN BEGIN
         grRainType[ifoot] = RainType_other  ; punt -- too high to be BB
      ENDIF ELSE BEGIN
        ; compute a mean depth of the samples -- use it to adjust the threshold BB
        ; by reducing the required slope for vertically deeper samples
;         avgdepth = MEAN(hgtprofile[1:countactual-1]-hgtprofile[0:countactual-2])
         bbthreshadj = (1.25/avgdepth) < 1.0
         bbThresh = bbThreshBase * bbthreshadj
         IF verbose GT 0 THEN print, "BBthresh: ", bbThresh

        ; compute the slopes of the reflectivity profile
         slopes = (gvprofile[1:countactual-1]-gvprofile[0:countactual-2]) / $
                  (hgtprofile[1:countactual-1]-hgtprofile[0:countactual-2])

         nbbtops = 0
         nbbbotms = 0
         nslopechg = 0  ; number of changes in slope sense (+ to - or vice versa)
         nRelMax = 0      ; no. changes of slope from + to - (like at BB)
         nRelMin = 0      ; no. changes of slope from - to + (low echo region)
         slopethresh = 0.5   ; threshold for slope to be considered non-zero, dBZ/km
         haveBBbotm = 0 & haveBBtop = 0   ; flags for when slope exceeded BB threshold
         zavg_below = -99.99    ; mean reflectivity below BB bottom (if found) or BB top
         stop_zavg = 0   ; flag to quit adding levels to zavg_below once BB detected
         stop_looking = 0  ; flag to quit looking for a BB above the level of the max Z (idxmax)

        ; assign positive slopes to +1, negative slopes to -1, below threshold to 0
         IF ABS(slopes[0]) LT slopethresh THEN lastslopedir=0 ELSE lastslopedir=slopes[0]/ABS(slopes[0])

         FOR islope = 0, countactual-2 DO BEGIN
           ; if we've hit the level of max Z and found a possible BB, then quit looking for one/others
            IF stop_looking EQ 1 THEN BREAK

           ; detect a BB bottom by Z lapse rate
            IF slopes[islope]/bbThresh GT 1.0 THEN BEGIN
               haveBBbotm = 1
               BBbotmHgt = (hgtprofile[islope]+hgtprofile[islope+1])/2.0
               IF nbbbotms GT nbbtops THEN stop_zavg = 0  ; keep averaging below-BB layer
               nbbbotms++
;print, "slope, islope at botm = ", slopes[islope],islope
            ENDIF
           ; detect a BB top by Z lapse rate
            IF slopes[islope]/bbThresh LT -1.0 THEN BEGIN
               haveBBtop = 1
               BBtopHgt = (hgtprofile[islope]+hgtprofile[islope+1])/2.0
               nbbtops++
               IF verbose GT 0 THEN print, "slope, islope at top = ", slopes[islope],islope
            ENDIF
           ; determine the mean reflectivity below the BB-affected level
            IF ((haveBBbotm+haveBBtop EQ 0) OR (haveBBbotm EQ 1 AND stop_zavg EQ 0)) THEN BEGIN
               zavg_below = MEAN( gvprofile[0:islope] )
               n_below = islope+1
;print, islope+1, N_ELEMENTS(gvprofile[0:islope])
               IF haveBBbotm EQ 1 THEN stop_zavg = 1   ; already hit BB bottom, quit adding layers to zavg_below
            ENDIF
           ; assign next slope sense
            IF ABS(slopes[islope]) LT slopethresh THEN thisslopedir=0 $
               ELSE thisslopedir=slopes[islope]/ABS(slopes[islope])

            CASE lastslopedir-thisslopedir OF
              2 : BEGIN
                     IF verbose GT 0 THEN print, "Found relmax by slope at slope layer: ", islope, $
                                                 " top slope: ", slopes[islope]
                     nslopechg++   ; we have a significant change in the profile
                     nRelMax++     ; we have a possible bright band signature
; Need to check the depth over which this occurred, can't be more than ~3 km, depending on beamwidth
                     IF haveBBbotm EQ 1 AND haveBBtop EQ 1 THEN BEGIN
                        thisBBhgt = (BBbotmHgt+BBtopHgt)/2
                        thisBBdepth = BBtopHgt-BBbotmHgt
                        IF verbose GT 0 THEN BEGIN
                           print, "BB certain, ray " + STRING(ifoot+1, format='(I0)') + $
                               "; hgt " + STRING(thisBBhgt, format='(F0.1)') + $
                               "; deep " + STRING(thisBBdepth, format='(F0.1)') + $
                               "; Z at " + STRING(gvprofile[islope], format='(F0.1)') + $
                               "; Z below " + STRING(zavg_below, format='(F0.1)') + $
                               "; # below " + STRING(n_below, format='(I0)') + $
                               "; botm " + STRING(BBbotmHgt, format='(F0.1)') + $
                               "; dZdh abv " + STRING(MEAN(slopes[islope:countactual-2]), format='(F0.1)')
                        ENDIF
                        IF thisBBhgt LE 6.5 AND thisBBdepth LT thisBBhgt $
                        AND gvprofile[islope]/zavg_below GT 1.03 THEN BEGIN
                           is_BB[islope] = 2   ; BB "certain"
                           BBhgtByRay[0, ifoot] = BBbotmHgt
                           BBhgtByRay[1, ifoot] = BBtopHgt
                           BBhgtByRay[2, ifoot] = thisBBhgt
                           BB_Z_ByRay[ifoot] = gvprofile[islope]
                           lastslopedir=thisslopedir
                           haveBBbotm = 0 & haveBBtop = 0  & stop_zavg = 0 ; reset flags for BB
                           IF islope GE idxmax THEN stop_looking = 1   ; stop looking above level of Zmax
                        ENDIF ELSE IF verbose GT 0 THEN print, "Too high/deep/flat to be BB !"
                     ENDIF $
                     ELSE IF haveBBbotm EQ 1 THEN IF verbose GT 0 THEN $
                         print, "Reserving judgement on relmax as BB, top slope: ", slopes[islope]
                  END
             -2 : BEGIN
                     nslopechg++   ; we have a significant change in the profile
                     nRelMin++     ; we have an echo minimum
                     lastslopedir=thisslopedir
                     haveBBtop = 0   ; reset flag for BB top detected
                  END
             ; deal with the monotonic and "to/from flat" areas
              0 : IF thisslopedir NE 0 THEN BEGIN
                    ; check for BB top detected by the lowest slope
                     IF islope EQ 0 AND haveBBtop EQ 1 THEN BEGIN ;AND avgdepth GT 1.0 THEN BEGIN
                        n_below = islope
                        thisBBhgt = hgtprofile[islope]   ; use max Z sample's midpoint - bottom unknown
                        is_BB[islope] = 1   ; BB "possible"
                        BBhgtByRay[0, ifoot] = -99.0
                        BBhgtByRay[1, ifoot] = BBtopHgt
                        BBhgtByRay[2, ifoot] = thisBBhgt
                        BB_Z_ByRay[ifoot] = gvprofile[islope]
                        IF verbose GT 0 THEN BEGIN
                           print, "BB possible for ray " + STRING(ifoot+1, format='(I0)') + $
                               "; height " + STRING(thisBBhgt, format='(F0.1)') + $
                               "; Z at " + STRING(gvprofile[islope], format='(F0.1)') + $
                               "; # below " + STRING(n_below, format='(I0)') + $
                               "; dZdh abv " + STRING(MEAN(slopes[islope:countactual-2]), format='(F0.1)')
                        ENDIF
                        IF islope GE idxmax THEN stop_looking = 1   ; stop looking above level of Zmax
                     ENDIF
                    ; same non-zero slope sense as last segment
                     lastslopedir=thisslopedir
                  ENDIF
              1 : IF thisslopedir NE 0 THEN BEGIN
                    ; transition from 'flat' to 'negative' dZ/dH
                     lastslopedir=thisslopedir
                     IF slopes[islope]/bbThresh LT -1.0 THEN BEGIN
                        zavg_below = MEAN( gvprofile[0:islope-1] )
                        n_below = islope
                        thisBBhgt = hgtprofile[islope]   ; use max Z sample's midpoint - bottom unknown
                        IF verbose GT 0 THEN BEGIN
                           print, "BB possible for ray " + STRING(ifoot+1, format='(I0)') + $
                               "; height " + STRING(thisBBhgt, format='(F0.1)') + $
                               "; Z at " + STRING(gvprofile[islope], format='(F0.1)') + $
                               "; Z below " + STRING(zavg_below, format='(F0.1)') + $
                               "; # below " + STRING(n_below, format='(I0)') + $
                               "; dZdh abv " + STRING(MEAN(slopes[islope:countactual-2]), format='(F0.1)')
                        ENDIF
                        IF thisBBhgt LE 6.5 AND gvprofile[islope]/zavg_below GT 1.03 THEN BEGIN
                           is_BB[islope] = 1   ; BB "possible"
                           BBhgtByRay[0, ifoot] = -99.0
                           BBhgtByRay[1, ifoot] = BBtopHgt
                           BBhgtByRay[2, ifoot] = thisBBhgt
                           BB_Z_ByRay[ifoot] = gvprofile[islope]
                           IF islope GE idxmax THEN stop_looking = 1   ; stop looking above level of Zmax
                        ENDIF ELSE IF verbose GT 0 THEN print, "Too high/flat to be BB !"
                     ENDIF
; Need to look at reflectivity below this level, compared to the BB value.
; -- If not lower below, then is not stratiform
                  ENDIF
             -1 : IF thisslopedir NE 0 THEN BEGIN
                   ; transition from 'flat' to 'positive' dZ/dH
                     lastslopedir=thisslopedir
                  ENDIF
            ENDCASE
         ENDFOR
         bbhist = HISTOGRAM( is_BB, BINSIZE=1, MIN=0, NBINS=3 )
         IF bbhist[2] EQ 1 THEN BEGIN
            grRainType[ifoot] = RainType_stratiform
;print, "Certain stratiform"
         ENDIF ELSE BEGIN
            IF bbhist[2] EQ 0 AND bbhist[1] EQ 1 THEN BEGIN
               grRainType[ifoot] = RainType_stratiform   ; for now. may decide to make 'other' later
;print, "Maybe stratiform"
            ENDIF ELSE BEGIN
               grRainType[ifoot] = RainType_other
               IF verbose GT 0 THEN print, "Other, no BB signature, uncertain Z for ray ", $
                                           STRING(ifoot+1, format='(I0)')
            ENDELSE
         ENDELSE
      ENDELSE
   ENDELSE

endfor

; Compute the mean BB height of all "good" stratiform profiles
; -- exclude profiles with multiple BB levels detected  ????
; first, look at points with BBbotm heights assigned, these have matching BBtop by default

countbbgood = 0 & meanBB = -99.99 & meanBB_Z = -99.99 & stdev_BB_Z = -99.99
idxstrat = WHERE( grRainType EQ RainType_stratiform, countstrat )
IF countstrat GT 0 THEN BEGIN
   idxbbdef = WHERE( BBhgtByRay[0,idxstrat] GT 0.0, countbbdef )
   idxbbmaybe = WHERE( BBhgtByRay[0,idxstrat] LE 0.0 AND BBhgtByRay[2,idxstrat] GT 0.0, countbbmaybe )
  ; if there are more maybes than definites, use them all, otherwise use definites
   IF (countbbdef GT 0) AND (countbbdef GT countbbmaybe) THEN BEGIN
     ; compute a mean BB height and Z for all columns with a BB top and bottom detected
      meanBBall = MEAN( BBhgtByRay[2,idxstrat[idxbbdef]] )
      MEAN_STD, BB_Z_ByRay[idxstrat[idxbbdef]], MEAN=meanBB_Z_all, STD=stdev_BB_Z_all
;      meanBB_Z_all = MEAN( BB_Z_ByRay[idxstrat[idxbbdef]] )
     ; find/re-average those within 1 km of the mean; in none, then just take meanBBall
      idxbbgood = WHERE( ABS(BBhgtByRay[2,idxstrat[idxbbdef]]-meanBBall) LE 1.0, countbbgood )
      IF countbbgood GT 0 THEN BEGIN
         meanBB = MEAN(BBhgtByRay[2,idxstrat[idxbbdef[idxbbgood]]])
         MEAN_STD, BB_Z_ByRay[idxstrat[idxbbdef[idxbbgood]]], MEAN=meanBB_Z, STD=stdev_BB_Z
      ENDIF ELSE BEGIN
         meanBB = meanBBall
         meanBB_Z = meanBB_Z_all
         stdev_BB_Z = stdev_BB_Z_all
      ENDELSE
   ENDIF ELSE BEGIN
     ; otherwise, compute a mean of ANY columns with a BB detected (thisBBhgt was non-zero)
      idxbbdef = WHERE( BBhgtByRay[2,idxstrat] GT 0.0, countbbdef )
      IF countbbdef GT 0 THEN BEGIN
         meanBBall = MEAN( BBhgtByRay[2,idxstrat[idxbbdef]] )
         MEAN_STD, BB_Z_ByRay[idxstrat[idxbbdef]], MEAN=meanBB_Z_all, STD=stdev_BB_Z_all
;         meanBB_Z_all = MEAN( BB_Z_ByRay[idxstrat[idxbbdef]] )
        ; find/re-average those within 1 km of the mean; in none, then just take meanBBall
         idxbbgood = WHERE( ABS(BBhgtByRay[2,idxstrat[idxbbdef]]-meanBBall) LE 1.0, countbbgood )
         IF countbbgood GT 0 THEN BEGIN
            meanBB = MEAN(BBhgtByRay[2,idxstrat[idxbbdef[idxbbgood]]])
            MEAN_STD, BB_Z_ByRay[idxstrat[idxbbdef[idxbbgood]]], MEAN=meanBB_Z, STD=stdev_BB_Z
;            meanBB_Z = MEAN( BB_Z_ByRay[idxstrat[idxbbdef[idxbbgood]]] )
         ENDIF ELSE BEGIN
            meanBB = meanBBall
            meanBB_Z = meanBB_Z_all
            stdev_BB_Z = stdev_BB_Z_all
         ENDELSE
      ENDIF
   ENDELSE
ENDIF

IF verbose GT 1 THEN print, "countstrat: ", countstrat
IF verbose GT 1 THEN print, "mean/stddev BB dBZ, # BB in mean: ", meanBB_Z, stdev_BB_Z, countbbgood
;print, ''
IF verbose GT 1 THEN print, "all BB heights: ", BBhgtByRay[2,*]

IF meanBB GT 0.0 THEN BEGIN
  ; will check samples with bases more than 0.75km above BB for high reflectivities,
  ; so need a set of sample base heights
;   botmprofiles = botm
;   topprofiles = top
  ; need a set of the original rain type determinations to keep Convective from
  ; 'spreading' when changing to Convective by checking for adjacent Convective
   grRainTypePass1 = grRainType
  ; need to tally profiles where checks for adjacent convective profiles are being
  ; made, so that we can make a final pass for these in case a subsequent adjacent
  ; profile is changed to convective according to high height/reflectivity
   checkagain = INTARR(nfooties)
   n_to_recheck =0
  ; number of profiles changed to convective based on 30 dBZ above BB
   n_changed_to_conv = 0

  ; walk through the profiles once again.  If any Z above meanBB height is > 30 dBZ,
  ; then reset type to Convective if Other, or to Convective from Stratiform iff BB
  ; height is not within 1 km or the max sample depth (whichever is greater) of the
  ; meanBB.  If Stratiform and BB height is not within this distance of meanBB, then
  ; reset to Other

  ; need to go scan by scan if we are processing the full set of scans, so find
  ; 1st and last scan for multiscans

   minscan = MIN(scanpr, MAX=maxscan)

   FOR iscan = minscan, maxscan DO BEGIN
   IF verbose GT 0 THEN print, "scan num = ", iscan
   idxthisscan = WHERE( scanpr EQ iscan, nraysthisscan )
   pr_rays_in_scan = raypr[idxthisscan]
   raystart = MIN( pr_rays_in_scan, idxmin, MAX=rayend, $
                   SUBSCRIPT_MAX=idxmax )
   IF verbose GT 0 THEN print, "ray start, end: ", raystart, rayend

;   for ifoot = 0, nfooties-1 DO BEGIN
   for irayidx = idxmin, idxmax DO BEGIN
     ; compute the index of this ray relative to full grRainType array
      ifoot = idxthisscan[irayidx]
     ; if ray is NO RAIN, skip over it
      IF grRainType[ifoot] EQ RainType_no_rain THEN BEGIN
         IF verbose GT 0 THEN print, "Leaving Rain Type as No Rain for RAY ", $
                                     STRING(ifoot+1, format='(I0)')
         CONTINUE
      ENDIF

     ; if ray is already convective, skip over it, too
      IF grRainType[ifoot] EQ RainType_convective THEN BEGIN
         IF verbose GT 0 THEN print, "Leaving Rain Type as Convective for RAY ", $
                                     STRING(ifoot+1, format='(I0)')
         CONTINUE
      ENDIF

     ; otherwise, grab the individual profile at the footprint
      gvprofile_all=REFORM(gvzprofiles[ifoot,*])
      botmprofile_all=REFORM(botmprofiles[ifoot,*])
      topprofile_all=REFORM(topprofiles[ifoot,*])
     ; do we have any actual reflectivity values in this profile?
      idxactual = WHERE(gvprofile_all GT 0.0, countactual)
      IF (countactual LT 2 ) THEN BEGIN
         IF verbose GT 0 THEN BEGIN
            print, "Too few samples, leaving Rain Type as ", $
                 STRING(grRainType[ifoot], format='(I0)'), " for Ray ", $
                 STRING(ifoot+1, format='(I0)')
         ENDIF
         CONTINUE
      ENDIF ELSE BEGIN
         gvprofile = gvprofile_all[idxactual]
         botmprofile = botmprofile_all[idxactual]
         topprofile = topprofile_all[idxactual]
         maxsampledepth = MAX(topprofile-botmprofile)
        ; look at the MAX Z for samples whose bottoms are > 0.75km above meanBB
         idxabvbb = WHERE( botmprofile GT (meanBB+0.75), countabvbb )
         IF countabvbb GT 0 THEN maxZabv = MAX(gvprofile[idxabvbb]) ELSE maxZabv = 0.0
        ; look at the MAX Z for samples whose bottoms are <= 0.75km above meanBB
         idxnotabvbb = WHERE( botmprofile LE (meanBB+0.75), countnotabv )
         IF countnotabv GT 0 THEN maxZnotabv = MAX(gvprofile[idxnotabvbb]) ELSE maxZnotabv = maxZabv
        ; get the max Z within the BB layer for comparison to above & below
         idxinbb = WHERE( botmprofile LE (meanBB+0.75) AND topprofile GE (meanBB-0.75), countin)
         IF countin GT 0 THEN maxzin = MAX(gvprofile[idxinbb]) ELSE maxzin = 0.0
      ENDELSE

     ; decide what to do based on maxZabv, rain type, and ray BB height.
     ; We require that there be 30 dBZ or greater both above and below the BB
     ; or more than one standard deviation above the mean BB reflectivity,
     ; whichever is greater, in order to override the rain type to convective
      conv_thresh_above = 30.0 > (meanBB_Z + stdev_BB_Z/3.0)
      conv_thresh_below = 30.0 > (meanBB_Z + stdev_BB_Z)
      IF maxZabv GT conv_thresh_above AND maxZnotabv GT conv_thresh_below THEN BEGIN
         CASE grRainType[ifoot] OF
            RainType_other : BEGIN
               grRainType[ifoot] = RainType_convective
               grRainTypePass1[ifoot] = RainType_convective  ; change 'original' type also
               n_changed_to_conv++
               IF verbose GT 0 THEN BEGIN

                  print, "Changing Other to Convective based on max Z of ", $
                      STRING(maxZabv, format='(F0.1)'), " for RAY ", $
                      STRING(ifoot+1, format='(I0)')
               ENDIF
               END
            RainType_stratiform : BEGIN
               IF ABS( BBhgtByRay[2,ifoot]-meanBB ) GT (1.0>maxsampledepth) THEN BEGIN
                 ; reset to convective, Z too high and BB height too far off
                  grRainType[ifoot] = RainType_convective
                  grRainTypePass1[ifoot] = RainType_convective  ; change 'original' type also
                  n_changed_to_conv++
                  IF verbose GT 0 THEN BEGIN
                     print, "Changing Stratiform to Convective based on max Z above BB of ", $
                         STRING(maxZabv, format='(F0.1)'), " and BB height of ", $
                         STRING(BBhgtByRay[2,ifoot], format='(F0.1)'), " for RAY ", $
                         STRING(ifoot+1, format='(I0)')
                  ENDIF
               ENDIF ELSE BEGIN
                  IF verbose GT 0 THEN BEGIN
                     print, "Leaving Rain Type as Stratiform for RAY ", $
                         STRING(ifoot+1, format='(I0)'), " even with max Z above BB of ", $
                         STRING(maxZabv, format='(F0.1)'), " and BB height of ", $
                         STRING(BBhgtByRay[2,ifoot], format='(F0.1)'), " for RAY ", $
                         STRING(ifoot+1, format='(I0)')
                  ENDIF
               ENDELSE
               END
            ELSE : IF verbose GT 0 THEN print, "ERROR for RAY ", STRING(ifoot+1, format='(I0)')
         ENDCASE
      ENDIF ELSE BEGIN
        ; if stratiform, check BB height for this ray against meanBB and if difference
        ; is too large then change to Other, or to Convective if an adjacent profile is
        ; Convective.  If profile is Other, then if an adjacent footprint is Convective
        ; change to Convective; otherwise leave it as Other.
         startfoot = (ifoot-1) > 0
         endfoot = (ifoot+1) < (nfooties-1)
         idxadjconv = WHERE( grRainTypePass1[startfoot:endfoot] EQ RainType_convective, nadjconv )
         CASE grRainType[ifoot] OF
            RainType_other : BEGIN
               IF nadjconv GT 0 THEN BEGIN
                  grRainType[ifoot] = RainType_convective
                  IF verbose GT 0 THEN print, "Changing Other to Convective based on adjacent Convective for RAY ", $
                                              STRING(ifoot+1, format='(I0)')
               ENDIF ELSE BEGIN
                  checkagain[ifoot] = 1
                  n_to_recheck++
                  IF verbose GT 0 THEN print, "Leaving Rain Type as Other for RAY ", $
                                              STRING(ifoot+1, format='(I0)')
               ENDELSE
               END
            RainType_stratiform : BEGIN
               IF (BBhgtByRay[2,ifoot] GT 0.0) AND (ABS( BBhgtByRay[2,ifoot]-meanBB ) GT (1.0>maxsampledepth)) THEN BEGIN
                 ; reset to Other if defined BB height is too far off, unless adjacent is Convective
                  IF nadjconv GT 0 THEN BEGIN
                     grRainType[ifoot] = RainType_convective
                     IF verbose GT 0 THEN print, "Changing Stratiform to Convective based on ", $
                                                 "adjacent Convective and on BB height of ", $
                                                 STRING(BBhgtByRay[2,ifoot], format='(F0.1)'),  $
                                                 " for RAY ", STRING(ifoot+1, format='(I0)')
                  ENDIF ELSE BEGIN
                     grRainType[ifoot] = RainType_other
                     checkagain[ifoot] = 1
                     n_to_recheck++
                     IF verbose GT 0 THEN print, "Changing Stratiform to Other based on BB height of ", $
                                                 STRING(BBhgtByRay[2,ifoot], format='(F0.1)'),  $
                                                 " for RAY ", STRING(ifoot+1, format='(I0)')
                  ENDELSE
               ENDIF ELSE IF verbose GT 0 THEN print, "Leaving Rain Type as Stratiform for RAY ", $
                                                      STRING(ifoot+1, format='(I0)')
               END
            ELSE : IF verbose GT 0 THEN print, "ERROR for RAY ", STRING(ifoot+1, format='(I0)')
         ENDCASE   
      ENDELSE
   endfor  ; iray loop
   ENDFOR  ; minscan to maxscan

   ; make one final pass to check whether a profile reassigned as convective will
   ; make a difference to a profile being checked for adjacent convective profiles
   IF n_to_recheck GT 0 AND n_changed_to_conv GT 0 THEN BEGIN
      IF verbose GT 0 THEN BEGIN
         print, ''
         print, "Re-checking for adjacent convective changes, last pass."
         print, ''
      ENDIF
      idxrecheck = WHERE( checkagain EQ 1, countrecheck )
      for jfoot = 0, countrecheck-1 DO BEGIN
         startfoot = (idxrecheck[jfoot]-1) > 0
         endfoot = (idxrecheck[jfoot]+1) < (nfooties-1)
         idxadjconv = WHERE( grRainTypePass1[startfoot:endfoot] EQ RainType_convective, nadjconv )
         CASE grRainType[idxrecheck[jfoot]] OF
            RainType_other : BEGIN
               IF nadjconv GT 0 THEN BEGIN
                  grRainType[idxrecheck[jfoot]] = RainType_convective
                  IF verbose GT 0 THEN print, "Changing Other to Convective based on new adjacent Convective for RAY ", $
                                              STRING(idxrecheck[jfoot]+1, format='(I0)')
               ENDIF
               END
            RainType_stratiform : BEGIN
                 ; reset to Other if defined BB height is too far off, unless adjacent is Convective
                  IF nadjconv GT 0 THEN BEGIN
                     grRainType[idxrecheck[jfoot]] = RainType_convective
                     IF verbose GT 0 THEN print, "Changing Stratiform to Convective based on new ", $
                                                  "adjacent Convective and on BB height of ", $
                                                  STRING(BBhgtByRay[2,idxrecheck[jfoot]], format='(F0.1)'),  $
                                                  " for RAY ", STRING(idxrecheck[jfoot]+1, format='(I0)')
                  ENDIF
               END
            ELSE : IF verbose GT 0 THEN print, "ERROR for RAY ", STRING(idxrecheck[jfoot]+1, format='(I0)')
         ENDCASE   
      endfor
   ENDIF

ENDIF   ; meanBB GT 0.0

done:
IF verbose GT 0 THEN BEGIN
   print, ""
   print, grRainType
   print, ""
   print, "From get_gr_geo_match_rain_type(), mean BB, # BB in mean: ", meanBB, countbbgood
   print, ""
ENDIF

;IF verbose GT 1 THEN print, idx2get
;IF verbose GT 1 THEN help, idx2get, grRainType

rainTypeOut = grRainType
RETURN, rainTypeOut
END
