;===============================================================================
;+
; Copyright © 2015, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; select_geomatch_subarea.pro       Morris/SAIC/GPM_GV    April 2015
;
; DESCRIPTION
; -----------
; Allows a user to select a location on PPI plot of volume-matched reflectivity
; and extract a subset of volume-matched data within a given range of the
; selected location, or for a "storm" defined as a contiguous area of Z or rain
; rate above a threshold, where the threshold is applied to the maximum value of
; the variable along a ray.  The arrays of volume-matched data to be subset are
; in a "known" but anonymous-type structure passed to this function.  Returns a
; new structure with the subsetted values and subset location information if a
; valid location is selected by the user; otherwise returns -1 if the user
; aborts the location selection or errors occur in the subsetting process.
;
; NON-SYSTEM ROUTINES CALLED
; --------------------------
; 1) plot_sweep_2_zbuf()
; 2) plot_sweep_2_zbuf_4xsec()
; 3) get_in_range_footprints()
; 4) get_storm_by_thresh()
;
; HISTORY
; -------
; 04/09/15  Morris/GPM GV/SAIC
; - Created.
; 04/28/15  Morris/GPM GV/SAIC
; - Hard-coded CREF parameter value to On. Move pctgoodrrgv calculation under
;   have_gvrr IF block. Added rr_field_used tag to structure.
; 05/04/15  Morris/GPM GV/SAIC
; - Added processing of DSD parameters, if present in data_struct.
; 06/24/15  Morris/GPM GV/SAIC
; - Added capability to process GRtoDPRGMI matchup data.
; - Removed ncfilepr positional parameter from call sequence, its filename
;   metadata is now passed in the data structure.
; - General cleanup and reformatting.
; 07/16/15 Morris, GPM GV, SAIC
; - Added clutterStatus tag/value pair to I/O data_struct structures.  It gets
;   subsetted only if it is an array.
; - Added GR_NW_N2 tag/value pair to I/O data_struct structures in DSD case to
;   identify the UF ID of the GR Nw data being used (NW or N2).
; - Changed case of GR_DP_Nw to gr_dp_nw to distinguish variable from UF ID.
; 11/2015 Morris, GPM GV, SAIC
; - Added subsetting of GR_blockage array variable, if available.
; 12/2015 Morris, GPM GV, SAIC
; - Modified to return scalar values for latitude and longitude of storm center
;   in structure.
; 01/2017 Morris, GPM GV, SAIC
; - Added check of dimensions of DSD variables to determine whether they are
;   real data arrays or just scalar placeholders indicating missing data.
; 03/24/17 Morris, GPM GV, SAIC
; - Added landOcean variable processing from data structures.
;
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;===============================================================================
;

FUNCTION select_geomatch_subarea_v88, hide_rntype, pr_or_dpr, elev2show, $
                                  data_struct, SUBSET_METHOD=method, $
                                  RR_OR_Z=rr_or_z, RANGE_MAX=range_max


; "include" file for PR data constants
@pr_params.inc
; "Include" file for DPR-product-specific parameters (i.e., RAYSPERSCAN):
@dpr_params.inc

; pull copies of all the data variables out of the passed structure

; left these here just to show what else is available
;have_gvrr = data_struct.haveFlags.have_gvrr
;haveHID = data_struct.haveFlags.haveHID
;haveD0 = data_struct.haveFlags.haveD0
;haveZdr = data_struct.haveFlags.haveZdr
;haveKdp = data_struct.haveFlags.haveKdp
;haveRHOhv = data_struct.haveFlags.haveRHOhv
have_pia = data_struct.haveFlags.have_pia
have_gr_blockage = data_struct.haveFlags.have_GR_blockage

; now pull the data variables:
gvz = data_struct.gvz
zraw = data_struct.zraw
zcor = data_struct.zcor
rain3 = data_struct.rain3
gvrr = data_struct.gvrr
HIDcat = data_struct.HIDcat
Dzero = data_struct.Dzero
Zdr = data_struct.Zdr
Kdp = data_struct.Kdp
RHOhv = data_struct.RHOhv
GR_blockage = data_struct.GR_blockage
top = data_struct.top
botm = data_struct.botm
lat = data_struct.lat
lon = data_struct.lon
pia = data_struct.pia
rnflag = data_struct.rnflag
rntype = data_struct.rntype
landOcean = data_struct.landOcean
pr_index = data_struct.pr_index
xcorner = data_struct.xcorner
ycorner = data_struct.ycorner
bbProx = data_struct.bbProx
dist = data_struct.dist
hgtcat = data_struct.hgtcat
pctgoodpr = data_struct.pctgoodpr
pctgoodgv = data_struct.pctgoodgv
pctgoodrain = data_struct.pctgoodrain
pctgoodrrgv = data_struct.pctgoodrrgv
clutterStatus = data_struct.clutterStatus

; left these here just to show what else is available
;BBparms = data_struct.BBparms
;heights = data_struct.heights
;hgtinterval = data_struct.hgtinterval

IF pr_or_dpr EQ 'DPRGMI' THEN BEGIN
   CASE data_struct.swath OF
     'MS' : nfp = data_struct.mygeometa.num_footprints_MS
     'NS' : nfp = data_struct.mygeometa.num_footprints_NS
     ELSE : message, "Invalid swath/scanType: "+data_struct.swath
   ENDCASE
ENDIF ELSE nfp = data_struct.mygeometa.num_footprints

; check whether DSD variables are present in structure AND are arrays
haveDSDvars = 0
allTags = TAG_NAMES(data_struct)
idxdsd = WHERE( STRMATCH(allTags, 'DPR_DM') EQ 1, countdsd )
IF countdsd EQ 1 THEN BEGIN
   dpr_dm = data_struct.dpr_Dm
   dpr_nw = data_struct.dpr_nw
   GR_DM_D0 = data_struct.GR_DM_D0
   gr_dp_nw = data_struct.gr_dp_nw
   GR_NW_N2 = data_struct.GR_NW_N2
   phase = data_struct.phase
   phaseNearSurface = data_struct.phaseNearSurface
   phaseHeightAGL = data_struct.phaseHeightAGL
  ; are they data arrays or just defined as scalars of -1 value?
   IF N_ELEMENTS(dpr_dm) GT 1 AND N_ELEMENTS(dpr_nw) GT 1 $
      AND N_ELEMENTS(gr_dp_nw) GT 1 THEN haveDSDvars = 1
ENDIF
   
;-------------------------------------------------

frequency = data_struct.KuKa        ; 'DPR', 'KA', or 'KU', from input GPM 2Axxx file
orbit = data_struct.orbit
DATESTAMP = data_struct.DATESTAMP      ; in YYMMDD format
ncsite = data_struct.mysite.site_id
version = data_struct.version
DPR_scantype = STRUPCASE(data_struct.swath)
; put the "Instrument" ID from the passed structure into its PPS designation
CASE STRUPCASE(frequency) OF
    'KA' : freqName='Ka'
    'KU' : freqName='Ku'
   'DPR' : freqName='DPR'
    ELSE : freqName=''
ENDCASE

sourceLabel = freqName + "/" + DPR_scantype
print, sourceLabel, " ", orbit, " ", DATESTAMP, " ", ncsite

nframes = data_struct.mygeometa.num_sweeps
IF pr_or_dpr NE 'PR' THEN BEGIN
   CASE DPR_scantype OF
      'HS' : RAYSPERSCAN = RAYSPERSCAN_HS
      'MS' : RAYSPERSCAN = RAYSPERSCAN_MS
      'NS' : RAYSPERSCAN = RAYSPERSCAN_NS
      ELSE : message, "Illegal scan type '"+DPR_scantype+"'"
   ENDCASE
ENDIF

; put together a title field
IF pr_or_dpr NE 'PR' THEN $
   verstring = STRTRIM( STRING(data_struct.mygeometa.DPR_Version), 2 ) $
ELSE verstring = "V" + STRTRIM( STRING(data_struct.mygeometa.PR_Version), 2 )

; extract rain type for the first sweep to make the single-level array
; for PPI plots generated in plot_sweep_2_zbuf()
rnTypeIn = rnType[*,0]
; if rain type "hiding" is on, set all samples to "Other" rain type
hide_rntype = KEYWORD_SET( hide_rntype )
IF hide_rntype THEN rnTypeIn[*,*] = 3

; Set up the pixmap window for the PPI plots
windowsize = 350
xsize = windowsize[0]
ysize = xsize
title = "All available samples shown"
window, 0, xsize=xsize, ysize=ysize*2, xpos = 75, TITLE = title, /PIXMAP

; hardwire the ground radar x and y coordinates in the window, don't know how to
; get these values from IDL based on the map projection setup vs. windowsize
x_gr = 175
y_gr = 170  ; close enough, can be 171 if southern hemisphere

error = 0
loadcolortable, 'CZ', error
if error then begin
    print, "error from loadcolortable"
    goto, errorExit
endif

;-------------------------------------------------

; If a sweep number is not specified, pick one about 1/3 of the way up:
IF ( N_ELEMENTS(elev2show) EQ 1 ) THEN BEGIN
   IF (elev2show LE nframes) THEN ifram=elev2show-1>0 ELSE ifram=nframes-1>0
ENDIF ELSE ifram=nframes/3

; Build the 'true' PPI image buffers
cref = 1                ;KEYWORD_SET(cref)  ; hard-wire for comp. reflect. PPIs
IF (cref) THEN BEGIN
   prtitle = frequency+"-band/"+DPR_scantype+"/"+verstring+" Composite Ze"
ENDIF ELSE BEGIN
   elevstr =  string(data_struct.mysweeps[ifram].elevationAngle, FORMAT='(f0.1)')
   prtitle = frequency+"-band/"+DPR_scantype+"/"+verstring+ $
             " Ze along "+data_struct.mysite.site_ID+" "+elevstr+" degree sweep"
ENDELSE
myprbuf = plot_sweep_2_zbuf( zcor, data_struct.mysite.site_lat, data_struct.mysite.site_lon, $
                             xCorner, yCorner, pr_index, nfp, ifram, $
                             rnTypeIn, WINSIZ=windowsize, TITLE=prtitle, $
                             MAXRNGKM=data_struct.mygeometa.rangeThreshold, CREF=1 )

IF (cref) THEN gvtitle = data_struct.mysite.site_ID+" Composite Ze, "+ $
                         data_struct.mysweeps[nframes/3].atimeSweepStart $
          ELSE gvtitle = data_struct.mysite.site_ID+" at "+elevstr+" deg., "+ $
                         data_struct.mysweeps[ifram].atimeSweepStart

mygvbuf = plot_sweep_2_zbuf( gvz, data_struct.mysite.site_lat, data_struct.mysite.site_lon, $
                             xCorner, yCorner, pr_index, nfp, ifram, $
                             rnTypeIn, WINSIZ=windowsize, TITLE=gvtitle, $
                             MAXRNGKM=data_struct.mygeometa.rangeThreshold, CREF=1 )

; grab 'clean' PPIs without burn-ins
myprbufClean = myprbuf
mygvbufClean = mygvbuf
myprbufClean[WHERE(myprbuf EQ 255b)] = 122b  ; set up for merged color tables
mygvbufClean[WHERE(mygvbuf EQ 255b)] = 122b

;-------------------------------------------------

; Build the corresponding PR scan and ray number buffers (not displayed).  Need
; to cut one layer out of pr_index, which has been replicated over each sweep
; level by fprep_geo_match_profiles():
pr_scan = pr_index[*,0] & pr_ray = pr_index[*,0]
idx2get = WHERE( pr_index[*,0] GE 0 )  ; this should be ALL points if from fprep_geo_match_profiles()
pridx2get = pr_index[idx2get,0]

IF pr_or_dpr NE 'PR' THEN BEGIN
   ; analyze the pr_index, decomposed into DPR-product-relative scan and ray number
   raypr = pridx2get MOD RAYSPERSCAN   ; for GPM
   scanpr = pridx2get/RAYSPERSCAN      ; for GPM
ENDIF ELSE BEGIN
  ; derive the original number of scans in the file using the 'step' between
  ;   rays of the same scan - this **USUALLY** works, but is a bit of trickery
   print, 'Using trickery to derive scan and ray numbers, this may fail...'
   print, ''
  ; find the statistical mode of the pridx change from one point to the next
  ; -- this should be equal to the value of sample_range used to determine the
  ;    original pr_master_index values
  ; the following algorithm is documented at http://www.dfanning.com/code_tips/mode.html
   ngoodpr = n_elements(pridx2get)
   array= (ABS(pridx2get[0:ngoodpr-2]-pridx2get[1:ngoodpr-1]))
   array = array[Sort(array)]
   wh = where(array ne Shift(array,-1), cnt)
   if cnt eq 0 then mode = array[0] else begin
      void = Max(wh-[-1,wh], mxpos)
      mode = array[wh[mxpos]]
   endelse
   sample_range = mode
  ; expand this subset of PR master indices into its scan,ray coordinates.
   raypr = pridx2get/sample_range
   scanpr = pridx2get MOD sample_range
ENDELSE

scanoff = MIN(scanpr)
scanmax = MAX(scanpr)

;   pr_index uses -1 for 'bogus' PR points (out-of-range PR footprints
;   just adjacent to the first/last in-range point of the scan), or -2 for
;   off-PR-scan-edge but still-in-range points.  Negative point values will be
;   reset to zero in plot_sweep_2_zbuf_4xsec(), so we will add 3 to the analyzed
;   values and readjust when we query the resulting pixmaps.  After analysis, 
;   anything with an unadjusted ray or scan value of zero should then be outside
;   the PPI/PR overlap area.
;   -- In actuality, any samples with negative pr_index have already been
;      removed within fprep_geo_match_profiles(), leaving only the 'actual'
;      data points at each level.  Morris, 9/5/2012
pr_scan[idx2get] = scanpr-scanoff  ; setting scan values for 'actual' points
pr_ray[idx2get] = raypr            ; ditto for ray values
pr_scan = pr_scan+3L & pr_ray = pr_ray+3L   ; offsetting all values for analysis

myscanbuf = plot_sweep_2_zbuf_4xsec( pr_scan, data_struct.mysite.site_lat, $
                                     data_struct.mysite.site_lon, xCorner, yCorner, pr_index, $
                                     nfp, ifram, WINSIZ=windowsize, TITLE=idxtitle, /NOCOLOR, $
                                     MAXRNGKM=data_struct.mygeometa.rangeThreshold )

myraybuf = plot_sweep_2_zbuf_4xsec( pr_ray, data_struct.mysite.site_lat, $
                                    data_struct.mysite.site_lon, xCorner, yCorner, pr_index, $
                                    nfp, ifram, WINSIZ=windowsize, TITLE=idxtitle, /NOCOLOR, $
                                    MAXRNGKM=data_struct.mygeometa.rangeThreshold )

;-------------------------------------------------

; Render the PR and GR PPI plot - we don't actually view the scan and ray buffers
SET_PLOT, 'X'
device, decomposed=0, RETAIN=2
;HELP, !D, /structure

TV, myprbuf, 0
TV, mygvbuf, 1

window, 1, xsize=xsize, ysize=ysize*2, xpos = 350, ypos=50, TITLE = "Click on a Storm:" ;title
Device, Copy=[0,0,xsize,ysize*2,0,0,0]

;-------------------------------------------------

IF method  EQ 'V' THEN BEGIN
  ; get the maximum value in each column for each source (GR and (D)PR), and then
  ; the greater value of the two sources at each point
   CASE rr_or_z OF
    ; if rain rate, use GR and (D)PR rain rates if available, else (D)PR only
     'RR' : IF data_struct.haveFlags.have_gvrr THEN composite_data = $
              MAX(gvrr, DIMENSION=2) > MAX(rain3, DIMENSION=2) $
            ELSE composite_data = MAX(rain3, DIMENSION=2)
      'Z' : composite_data = MAX(gvz, DIMENSION=2) > MAX(zcor, DIMENSION=2)
   ENDCASE
ENDIF
           
; Let the user select the cross-section locations:
print, ''
print, '---------------------------------------------------------------------'
print, ''
print, ' > Left click on a point to select a storm to analyze, Right click to exit'
print, ''
!Mouse.Button=1
havestorm = 0
verbose=1


WHILE ( !Mouse.Button EQ 1 ) DO BEGIN

   WSet, 1
   CURSOR, xppi, yppi, /DEVICE, /DOWN
   IF ( !Mouse.Button NE 1 ) THEN BREAK
   IF KEYWORD_SET(verbose) THEN print, "X: ", xppi, "  Y: ", yppi MOD ysize
   scanNum = myscanbuf[xppi, yppi MOD ysize]

   IF ( scanNum GT 2 AND scanNum LT 250B ) THEN BEGIN
      havestorm = 1   ; for now -- may change if pixel value is below threshold
     ; account for +3 offset in scan/ray buffers
      scanNumpr = scanNum + scanoff - 3L
      IF KEYWORD_SET(verbose) THEN print, $
         "Product-relative scan number: ", scanNumpr+1  ; 1-based
      rayNum = myraybuf[xppi, yppi MOD ysize]
      rayNumpr = rayNum - 3L

     ; find the pr_index and matchup-array-relative index of the selected point
      IF pr_or_dpr NE 'PR' THEN the_pr_index = scanNumPR*RAYSPERSCAN + rayNumPR $
      ELSE the_pr_index = rayNumPR*SAMPLE_RANGE + scanNumPR
      the_loc_idx = WHERE(pr_index[*,0] EQ the_pr_index, countloc)

      IF KEYWORD_SET(verbose) THEN print, pr_or_dpr+" ray number: ", rayNumpr+1  ; 1-based
;      oplot, [xppi], [yppi MOD ysize], psym=1, COLOR=255, SYMSIZE=3, THICK=3
;      oplot, [xppi], [(yppi MOD ysize)+ysize], psym=1, COLOR=255, SYMSIZE=3
     ; plot a cross symbol at the selected footprint
      plots, [xppi-10, xppi+10], [yppi MOD ysize, yppi MOD ysize], COLOR=255, /DEVICE, THICK=2
      plots, [xppi, xppi], [(yppi MOD ysize)-10, (yppi MOD ysize)+10], COLOR=255, /DEVICE, THICK=2
      plots, [xppi-10, xppi+10], [yppi MOD ysize, yppi MOD ysize]+ysize, COLOR=255, /DEVICE, THICK=2
      plots, [xppi, xppi], [(yppi MOD ysize)-10, (yppi MOD ysize)+10]+ysize, COLOR=255, /DEVICE, THICK=2

      IF method  EQ 'V' THEN BEGIN
        ; test this point's composite value to see if it is above the cutoff threshold
         IF composite_data[the_loc_idx] GE range_max THEN break $
         ELSE BEGIN
            print, "Selected sample is below the ",rr_or_z," cutoff value: ", range_max
            print, "Your value: ", composite_data[the_loc_idx]
            print, "Pick another point in the PPIs."
           ; reset flag to No Storm in case user right-clicks to abort
           ; before finding an above-thresold starting point
            havestorm=0
         ENDELSE
      ENDIF ELSE break

   ENDIF ELSE BEGIN   ; ( scanNum GT 2 AND scanNum LT 250B )
      print, "Point outside "+pr_or_dpr+"/", data_struct.mysite.site_ID, $
             " overlap area, choose another..."
   ENDELSE   ; ( scanNum GT 2 AND scanNum LT 250B )

ENDWHILE     ; ( !Mouse.Button EQ 1 )


IF havestorm EQ 0 THEN BEGIN
   print, "No storm selected, no data to be subsetted."
   wdelete, 1
   goto, errorexit
ENDIF ELSE BEGIN
   ;print, "Subsetting DPR around ray,scan ", rayNumPR+1, scanNumPR+1
   the_ranges = 0  ; just initialize to anything so parameter value is defined
   if countloc NE 1 THEN message, "pr_index not found!"
   the_lat = lat[the_loc_idx,0]
   the_lon = lon[the_loc_idx,0]
   print, "Subsetting "+pr_or_dpr+" around lat, lon (", $
      STRING(the_lat,FORMAT='(F0.2)')+","+STRING(the_lon,FORMAT='(F0.2)') + ")"
   CASE method OF
     'D' : idxInSubset = get_In_Range_Footprints( the_loc_idx, lat[*,0], lon[*,0], $
                                                  RANGE_MAX=range_max, RANGES=the_ranges )
     'V' : idxInSubset = get_storm_by_thresh( the_loc_idx, raypr, scanpr, $
                                              composite_data, range_max )
   ENDCASE
   IF idxInSubset[0] EQ -1 THEN BEGIN
      print, "No in-range/storm cell samples, no data to be subsetted."
      wdelete, 1
      goto, errorexit
   ENDIF

   countactual = N_ELEMENTS(idxInSubset)
   ; build an array index of actual points, replicated over all the sweep levels
   idx3d=long(pr_index)           ; take one of the 2D arrays, make it LONG type
   idx3d[*,*] = 0L                ; re-set all point values to 0
   idx3d[idxInSubset,0] = 1L       ; set first-sweep-level values to 1 where in-range

   ; now copy the first sweep values to the other levels
   IF ( nframes GT 1 ) THEN FOR iswp=1, nframes-1 DO idx3d[*,iswp] = idx3d[*,0]

   ; get the indices of all the in-range points in the 2D sweep-level arrays
   idxpractual2d = where( idx3d EQ 1L, countactual2d )
   if (countactual2d EQ 0) then begin
    ; this shouldn't be able to happen
      print, "No non-bogus 2D data points, quitting case."
      wdelete, 1
      goto, errorExit
   endif

   ; clip the sweep-level 2-d arrays to the locations of in-range footprints only
   ; and restore to 2 dimensions
   gvz = REFORM(gvz[idxpractual2d], countactual, nframes)
   zraw = REFORM(zraw[idxpractual2d], countactual, nframes)
   zcor = REFORM(zcor[idxpractual2d], countactual, nframes)
   rain3 = REFORM(rain3[idxpractual2d], countactual, nframes)
   IF data_struct.haveFlags.have_gvrr THEN BEGIN
      gvrr = REFORM(gvrr[idxpractual2d], countactual, nframes)
      pctgoodrrgv = REFORM(pctgoodrrgv[idxpractual2d], countactual, nframes)
   ENDIF
   IF haveDSDvars THEN BEGIN
      dpr_dm = REFORM(dpr_Dm[idxpractual2d], countactual, nframes)
      dpr_nw = REFORM(dpr_nw[idxpractual2d], countactual, nframes)
      ;GR_DM_D0 = data_struct.GR_DM_D0  ; an ID, not an array. Ditto GR_NW_N2
      gr_dp_nw = REFORM(gr_dp_nw[idxpractual2d], countactual, nframes)
      phase = REFORM(phase[idxpractual2d], countactual, nframes)
      phaseHeightAGL = REFORM(phaseHeightAGL[idxpractual2d], countactual, nframes)
      phaseNearSurface = REFORM(phaseNearSurface[idxpractual2d], countactual, nframes)
   ENDIF
   HIDcat = REFORM(HIDcat[idxpractual2d], countactual, nframes)
   Dzero = REFORM(Dzero[idxpractual2d], countactual, nframes)
   Zdr = REFORM(Zdr[idxpractual2d], countactual, nframes)
   Kdp = REFORM(Kdp[idxpractual2d], countactual, nframes)
   RHOhv = REFORM(RHOhv[idxpractual2d], countactual, nframes)
   IF data_struct.haveFlags.have_GR_blockage THEN $
      GR_blockage = REFORM(GR_blockage[idxpractual2d], countactual, nframes)
   top = REFORM(top[idxpractual2d], countactual, nframes)
   botm = REFORM(botm[idxpractual2d], countactual, nframes)
   lat = REFORM(lat[idxpractual2d], countactual, nframes)
   lon = REFORM(lon[idxpractual2d], countactual, nframes)
   IF data_struct.haveFlags.have_pia THEN $
      pia = REFORM(pia[idxpractual2d], countactual, nframes)
   rnflag = REFORM(rnflag[idxpractual2d], countactual, nframes)
   rntype = REFORM(rntype[idxpractual2d], countactual, nframes)
   landOcean = REFORM(landOcean[idxpractual2d], countactual, nframes)
   pr_index = REFORM(pr_index[idxpractual2d], countactual, nframes)
   bbProx = REFORM(bbProx[idxpractual2d], countactual, nframes)
   dist = REFORM(dist[idxpractual2d], countactual, nframes)
   hgtcat = REFORM(hgtcat[idxpractual2d], countactual, nframes)
   pctgoodpr = REFORM(pctgoodpr[idxpractual2d], countactual, nframes)
   pctgoodgv = REFORM(pctgoodgv[idxpractual2d], countactual, nframes)
   pctgoodrain = REFORM(pctgoodrain[idxpractual2d], countactual, nframes)

   ; deal with the clutterStatus, which is an array only if in use
   IF ( N_ELEMENTS(clutterStatus) GT 1 ) THEN $
      clutterStatus = REFORM(clutterStatus[idxpractual2d], countactual, nframes)

   ; deal with the x- and y-corner arrays with the extra dimension
   xcornew = fltarr(4, countactual, nframes)
   ycornew = fltarr(4, countactual, nframes)
   FOR icorner = 0,3 DO BEGIN
      xcornew[icorner,*,*] = xCorner[icorner, idxInSubset, *]
      ycornew[icorner,*,*] = yCorner[icorner, idxInSubset, *]
   ENDFOR

   ; reset the dimension that has been clipped
   IF pr_or_dpr EQ 'DPRGMI' THEN BEGIN
      CASE data_struct.swath OF
        'MS' : data_struct.mygeometa.num_footprints_MS = countactual
        'NS' : data_struct.mygeometa.num_footprints_NS = countactual
        ELSE : message, "Invalid swath/scanType: "+data_struct.swath
      ENDCASE
   ENDIF ELSE data_struct.mygeometa.num_footprints = countactual

   ; set the storm lat and lon to the mean of the trimmed samples if using
   ; subset by threshold
   IF method EQ 'V' THEN BEGIN
      the_lat = MEAN(lat)
      the_lon = MEAN(lon)
      print, "Area centroid lat, lon (", STRING( the_lat, FORMAT='(F0.2)' ) + $
             "," + STRING( the_lon, FORMAT='(F0.2)' ) + ")"
   ENDIF
ENDELSE
goto, normalExit

errorExit:
return, -1

normalExit:
; fill and return a new data structure with the clipped arrays

dataStruc = { haveFlags : data_struct.haveFlags, $
              mygeometa : data_struct.mygeometa, $
              mysite : data_struct.mysite, $
              mysweeps : data_struct.mysweeps, $
              gvz : gvz, $
              zraw : zraw, $
              zcor : zcor, $
              rain3 : rain3, $
              gvrr : gvrr, $
              rr_field_used : data_struct.rr_field_used, $
              HIDcat : HIDcat, $
              Dzero : Dzero, $
              Zdr : Zdr, $
              Kdp : Kdp, $
              RHOhv : RHOhv, $
              GR_blockage : GR_blockage, $
              top : top, $
              botm : botm, $
              lat : lat, $
              lon : lon, $
              pia : pia, $
              rnflag : rnflag, $
              rntype : rntype, $
              landOcean : landOcean, $
              pr_index : pr_index, $
              xcorner : xcornew, $
              ycorner : ycornew, $
              bbProx : bbProx, $
              dist : dist, $
              hgtcat : hgtcat, $
              pctgoodpr : pctgoodpr, $
              pctgoodgv : pctgoodgv, $
              pctgoodrain : pctgoodrain, $
              pctgoodrrgv : pctgoodrrgv, $
              clutterStatus : clutterStatus, $
              BBparms : data_struct.BBparms, $
              heights : data_struct.heights, $
              hgtinterval : data_struct.hgtinterval, $
              is_subset : 1, $
              DATESTAMP : data_struct.DATESTAMP, $
              orbit : data_struct.orbit, $
              version : data_struct.version, $
              KuKa : data_struct.KuKa, $
              swath : data_struct.swath, $
              storm_lat : the_lat[0], $      ; convert array[1] to scalar
              storm_lon : the_lon[0] }       ; ditto

IF haveDSDvars THEN BEGIN
  ; define a structure with the clipped DSD variables and append it to the basic
  ; structure
   dataStrucDSD = { dpr_dm : dpr_Dm, $
                    dpr_nw : dpr_nw, $
                    GR_DM_D0 : GR_DM_D0, $    ; UF ID of Dzero
                    gr_dp_nw : gr_dp_nw, $    ; data variable
                    GR_NW_N2 : GR_NW_N2, $    ; UF ID of gr_dp_nw
                    phase : phase, $
                    phaseNearSurface : phaseNearSurface, $
                    phaseHeightAGL : phaseHeightAGL }
   dataStrucOut = CREATE_STRUCT( TEMPORARY(dataStruc), TEMPORARY(dataStrucDSD) )
ENDIF ELSE dataStrucOut = TEMPORARY(dataStruc)

return, dataStrucOut
end

