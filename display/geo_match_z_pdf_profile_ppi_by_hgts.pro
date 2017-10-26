;===============================================================================
;+
; Copyright © 2009, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; geo_match_z_pdf_profile_ppi_by_hgts.pro    Morris/SAIC/GPM_GV    February 2009
;
; DESCRIPTION
; -----------
; Driver for the geo_match_z_plots function (included).  Sets up user/default
; parameters defining the plots and animations, and the method by which the next
; case is selected: either prompt the user to select the file, or just take the
; next one in the sequence.
;
; PARAMETERS
; ----------
; pdf_level    - height level (km) whose data are plotted in the reflectivity
;                histogram (Probability Density Function) section of output
;                plot.  Defaults to 3.0 if unspecified
;
; looprate     - initial animation rate for the PPI animation loop on startup.
;                Defaults to 3 if unspecified or outside of allowed 0-100 range
;
; elevs2show   - number of PPIs to display in the PPI image animation, starting
;                with the lowest elevation angle in the volume. Disables PPI
;                plot if <= 0, static plot if = 1. Defaults to 7 if unspecified
;
; ncpath       - local directory path to the geo_match netCDF files' location.
;                Defaults to /data/netcdf/geo_match
;
; sitefilter   - file pattern which acts as the filter limiting the set of input
;                files showing up in the file selector or over which the program
;                will iterate, depending on the select mode parameter. Default=*
;
; no_prompt    - method by which the next file in the set of files defined by
;                ncpath and sitefilter is selected. Binary parameter. If unset,
;                defaults to DialogPickfile()
;
; ppi_vertical - controls orientation for PPI plot/animation subpanels. Binary 
;                parameter. If unset, or if SHOW_THRESH_PPI is On, then defaults
;                to horizontal (PR PPI to left of GV PPI).  If set, then PR PPI
;                is plotted above the GV PPI
;
; ppi_size     - size in pixels of each subpanel in PPI plot.  Default=375
;
; pctAbvThresh - constraint on the percent of bins in the geometric-matching
;                volume that were above their respective thresholds, specified
;                at the time the geo-match dataset was created.  Essentially a
;                measure of "beam-filling goodness".  100 means use only those
;                matchup points where all the PR and GV bins in the volume
;                averages were above threshold (complete volume filled with
;                above threshold bin values).  0 means use all matchup points
;                available, with no regard for thresholds (the default, if no
;                pctAbvThresh value is specified)
;
; show_thresh_ppi - Binary parameter, controls whether to create and display a
;                   2nd set of PPIs plotting only those PR and GR points meeting
;                   the pctAbvThresh constraint.  If set to On, then ppi_vertical
;                   defaults to horizontal (PR on left, GR on right)
;
; gv_convective - GV reflectivity threshold at/above which GV data are considered
;                 to be of Convective Rain Type.  Default = 35.0 if not specified.
;                 If set to <= 0, then GV reflectivity is ignored in evaluating
;                 whether PR-indicated Stratiform Rain Type matches GV type.
;
; gv_stratiform - GV reflectivity threshold at/below which GV data are considered
;                 to be of Stratiform Rain Type.  Default = 25.0 if not specified.
;                 If set to <= 0, then GV reflectivity is ignored in evaluating
;                 whether PR-indicated Convective Rain Type matches GV type.
;
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;===============================================================================
pro geo_match_z_pdf_profile_ppi_by_hgts, PDF_LEVEL=pdf_level, SPEED=looprate, $
                                  ELEVS2SHOW=elevs2show, NCPATH=ncpath, $
                                  SITE=sitefilter, NO_PROMPT=no_prompt, $
                                  PPI_VERTICAL=ppi_vertical, PPI_SIZE=ppi_size, $
                                  PCT_ABV_THRESH=pctAbvThresh, $
                                  SHOW_THRESH_PPI=show_thresh_ppi, $
                                  GV_CONVECTIVE=gv_convective, GV_STRATIFORM=gv_stratiform

FORWARD_FUNCTION geo_match_z_plots

; set up the height level to show in the PDF plot
allowedheight = [1.5, 3.0, 4.5, 6.0, 7.5, 9.0, 10.5, 12.0, 13.5, 15.0, 16.5, 18.0, 19.5]
IF ( N_ELEMENTS(pdf_level) EQ 1 ) THEN BEGIN
   inhgtidx = WHERE(allowedheight eq pdf_level, counthgt)
   if (counthgt ne 1) then begin
   print, ''
      print, '******************************************************************'
      print, ''
      print, 'Height value "', pdf_level, '" not one of the grid height levels:'
      print, allowedheight, FORMAT='(12(f0.1, ", "),f0.1)'
      print, ''
      print, "Defaulting to 3.0 km for the PDF level."
      height = 3.0
   endif else height = pdf_level
ENDIF ELSE BEGIN
   print, "Defaulting to 3.0 km for the PDF level."
   height = 3.0
ENDELSE

; set up the loop speed for xinteranimate, 0<= speed <= 100
IF ( N_ELEMENTS(looprate) EQ 1 ) THEN BEGIN
  IF ( looprate LT 0 OR looprate GT 100 ) THEN looprate = 3
ENDIF ELSE BEGIN
   looprate = 3
ENDELSE

; set up the max # of sweeps to show in animation loop
IF ( N_ELEMENTS(elevs2show) NE 1 ) THEN BEGIN
   print, "Defaulting to 7 for the number of PPI levels to plot."
   elevs2show = 7
ENDIF ELSE BEGIN
   IF ( elevs2show LE 0 ) THEN BEGIN
      print, "Disabling PPI animation plot, ELEVS2SHOW <= 0"
      elevs2show = 0
   ENDIF
ENDELSE

IF ( N_ELEMENTS(ncpath) NE 1 ) THEN BEGIN
   print, "Defaulting to /data/netcdf/geo_match for file path."
   pathpr = '/data/netcdf/geo_match'
ENDIF ELSE pathpr = ncpath

IF ( N_ELEMENTS(sitefilter) NE 1 ) THEN BEGIN
   print, "Defaulting to * for file pattern."
   ncfilepatt = '*'
ENDIF ELSE ncfilepatt = '*'+sitefilter+'*'

PPIorient = keyword_set(ppi_vertical)
PPIbyThresh = keyword_set(show_thresh_ppi)

IF ( N_ELEMENTS(ppi_size) NE 1 ) THEN BEGIN
   print, "Defaulting to 375 for PPI size."
   ppi_size = 375
ENDIF

; Decide which PR and GV points to include, based on percent of expected points
; in bin-averaged results that were above dBZ thresholds set when the matchups
; were done.  If unspecified or set to zero, include all points regardless of
; 'completeness' of the volume averages.

IF ( N_ELEMENTS(pctAbvThresh) NE 1 ) THEN BEGIN
   print, "Defaulting to 0 for PERCENT BINS ABOVE THRESHOLD."
   pctAbvThresh = 0.0
ENDIF ELSE BEGIN
   pctAbvThresh = FLOAT(pctAbvThresh)
   IF ( pctAbvThresh LT 0.0 OR pctAbvThresh GT 100.0 ) THEN BEGIN
      print, "Invalid value for PCT_ABV_THRESH: ", pctAbvThresh, $
             ", must be between 0 and 100."
      print, "Defaulting to 0 for PERCENT BINS ABOVE THRESHOLD."
      pctAbvThresh = 0.0
   ENDIF
END      
   
; Set up for the PR-GV rain type matching based on GV reflectivity

IF ( N_ELEMENTS(gv_Convective) NE 1 ) THEN BEGIN
   print, "Defaulting to 35.0 dBZ for GV Convective floor threshold."
   gvConvective = 35.0
ENDIF ELSE BEGIN
   gvConvective = FLOAT(gv_Convective)
ENDELSE

IF ( N_ELEMENTS(gv_Stratiform) NE 1 ) THEN BEGIN
   print, "Defaulting to 25.0 dBZ for GV Stratiform ceiling threshold."
   gvStratiform = 25.0
ENDIF ELSE BEGIN
   gvStratiform = FLOAT(gv_Stratiform)
ENDELSE

; Figure out how the next file to process will be obtained.  If no_prompt is
; set, then we will automatically loop over the file sequence.  Otherwise we
; will prompt the user for the next file with dialog_pickfile() (DEFAULT).

no_prompt = keyword_set(no_prompt)

IF (no_prompt) THEN BEGIN

   prfiles = file_search(pathpr+'/'+ncfilepatt,COUNT=nf)

   if nf eq 0 then begin
      print, 'No netCDF files matching file pattern: ', pathpr+'/'+ncfilepatt
   endif else begin
      for fnum = 0, nf-1 do begin
        ; set up for bailout prompt every 5 cases if animating PPIs w/o file prompt
         doodah = ""
         IF ( ((fnum+1) MOD 5) EQ 0 AND elevs2show GT 1 AND no_prompt ) THEN BEGIN $
             READ, doodah, $
             PROMPT='Hit Return to do next 5 cases, Q to Quit, D to Disable this bail-out option: '
             IF doodah EQ 'Q' OR doodah EQ 'q' THEN break
             IF doodah EQ 'D' OR doodah EQ 'd' THEN no_prompt=0   ; never ask again
         ENDIF
        ;
         ncfilepr = prfiles(fnum)
         action = 0
         action = geo_match_z_plots( ncfilepr, height, looprate, elevs2show, $
                                     PPIorient, ppi_size, pctAbvThresh, PPIbyThresh, $
                                     gvconvective, gvstratiform )

         if (action) then break
      endfor
   endelse
ENDIF ELSE BEGIN
   ncfilepr = dialog_pickfile(path=pathpr, filter = ncfilepatt)
   while ncfilepr ne '' do begin
      action = 0
      action=geo_match_z_plots( ncfilepr, height, looprate, elevs2show, $
                                PPIorient, ppi_size, pctAbvThresh, PPIbyThresh, $
                                gvconvective, gvstratiform )
      if (action) then break
      ncfilepr = dialog_pickfile(path=pathpr, filter = ncfilepatt)
   endwhile
ENDELSE

print, "" & print, "Done!"
END

;===============================================================================
;
FUNCTION geo_match_z_plots, ncfilepr, height, looprate, elevs2show, PPIorient, $
                            windowsize, pctabvthresh, PPIbyThresh, gvconvective, $
                            gvstratiform
;
; DESCRIPTION
; -----------
; Reads PR and GV reflectivity and spatial fields from a user-selected geo_match
; netCDF file, builds index arrays of categories of range, rain type, bright
; band proximity (above, below, within), and height (13 categories, 1.5-19.5 km
; levels); and an array of actual range.  Computes mean PR-GV reflectivity
; differences for each of the 13 height levels for points within 100 km of the
; ground radar and reports the results in a table to stdout.  Also produces a
; graph of the Probability Density Function of PR and GV reflectivity at a given
; height level (input) if data exists at that level, and a vertical profile of
; mean PR and GV reflectivity. Optionally produces a single frame or an
; animation loop of GV and equivalent PR PPI images for N=elevs2show frames.
;===============================================================================

; "include" file for read_geo_match_netcdf() structs returned
@geo_match_nc_structs.inc

; "include" file for PR data constants
@pr_params.inc

;FORWARD_FUNCTION plot_sweep_2_zbuf
   bname = file_basename( ncfilepr )
   prlen = strlen( bname )
   pctString = STRTRIM(STRING(FIX(pctabvthresh)),2)

; Get uncompressed copy of the found files
cpstatus = uncomp_file( ncfilepr, ncfile1 )
if(cpstatus eq 'OK') then begin
  status = 1   ; init to FAILED
  mygeometa={ geo_match_meta }
  mysweeps={ gv_sweep_meta }
  mysite={ gv_site_meta }
  myflags={ pr_gv_field_flags }
  status = read_geo_match_netcdf( ncfile1, matchupmeta=mygeometa, $
     sweepsmeta=mysweeps, sitemeta=mysite, fieldflags=myflags )
  IF (status EQ 1) THEN BEGIN
     command3 = "rm -v " + ncfile1
     spawn, command3
     GOTO, errorExit
  ENDIF

 ; create data field arrays of correct dimensions and read data fields
  nfp = mygeometa.num_footprints
  nswp = mygeometa.num_sweeps
  gvexp=intarr(nfp,nswp)
  gvrej=intarr(nfp,nswp)
  prexp=intarr(nfp,nswp)
  zrawrej=intarr(nfp,nswp)
  zcorrej=intarr(nfp,nswp)
  rainrej=intarr(nfp,nswp)
  gvz_in=intarr(nfp,nswp)
  zraw=fltarr(nfp,nswp)
  zcor_in=fltarr(nfp,nswp)
  rain3=fltarr(nfp,nswp)
  top=fltarr(nfp,nswp)
  botm=fltarr(nfp,nswp)
  lat=fltarr(nfp,nswp)
  lon=fltarr(nfp,nswp)
  bb=fltarr(nfp)
  rnflag=intarr(nfp)
  rntype=intarr(nfp)
  pr_index=lonarr(nfp)
  xcorner=fltarr(4,nfp,nswp)
  ycorner=fltarr(4,nfp,nswp)

  status = read_geo_match_netcdf( ncfile1,  $
    gvexpect_int=gvexp, gvreject_int=gvrej, prexpect_int=prexp, $
    zrawreject_int=zrawrej, zcorreject_int=zcorrej, rainreject_int=rainrej, $
    dbzgv=gvz_in, dbzcor=zcor_in, dbzraw=zraw, rain3d=rain3, topHeight=top, $
    bottomHeight=botm, latitude=lat, longitude=lon, bbhgt=BB, $
    rainflag_int=rnFlag, raintype_int=rnType, pridx_long=pr_index, $
    xCorners=xCorner, yCorners=yCorner )

  command3 = "rm -v " + ncfile1
  spawn, command3
  IF (status EQ 1) then GOTO, errorExit
endif else begin
  print, 'Cannot copy/unzip netCDF file: ', ncfilepr
  print, cpstatus
  command3 = "rm -v " + ncfile1
  spawn, command3
  goto, errorExit
endelse

site_lat = mysite.site_lat
site_lon = mysite.site_lon
siteID = string(mysite.site_id)
nsweeps = mygeometa.num_sweeps

; get array indices of the non-bogus footprints
idxpractual = where(pr_index GE 0L, countactual)
if (countactual EQ 0) then begin
   print, "No non-bogus data points, quitting case."
   goto, errorExit
endif

; Reclassify rain types down to simple categories 1 (Stratiform), 2 (Convective),
;  or 3 (Other), where defined
idxrnpos = where(rntype ge 0, countrntype)
if (countrntype GT 0 ) then rntype(idxrnpos) = rntype(idxrnpos)/100

; For each 'column' of data, find the maximum GV reflectivity value for the
;  footprint, and use this value to define a GV match to the PR-indicated rain type.
;  Using Default GV dBZ thresholds of >=35 for "GV Convective" and <=25 for 
;  "GV Stratiform", or other GV dBZ thresholds provided as user parameters,
;  set PR rain type to "other" (3) where: PR type is Convective and GV is not, or
;  PR is Stratiform and GV indicates Convective.  For GV reflectivities between
;  'gvstratiform' and 'gvconvective' thresholds, leave the PR rain type as-is.

print, ''
max_gvz_per_fp = MAX( gvz_in, DIMENSION=2)
IF ( gvstratiform GT 0.0 ) THEN BEGIN
   idx2other = WHERE( rnType EQ 2 AND max_gvz_per_fp LE gvstratiform, count2other )
   IF ( count2other GT 0 ) THEN rnType[idx2other] = 3
   print, FORMAT='("No. of footprints switched from Convective to Other = ", I0,", based on Stratiform dBZ threshold = ",F0.1)', count2other, gvstratiform
ENDIF ELSE BEGIN
   print, "Leaving PR Convective Rain Type assignments unchanged."
ENDELSE
IF ( gvconvective GT 0.0 ) THEN BEGIN
   idx2other = WHERE( rnType EQ 1 AND max_gvz_per_fp GE gvconvective, count2other )
   IF ( count2other GT 0 ) THEN rnType[idx2other] = 3
   print, FORMAT='("No. of footprints switched from Stratiform to Other = ", I0,", based on Convective dBZ threshold = ",F0.1)', count2other, gvconvective
ENDIF ELSE BEGIN
   print, "Leaving PR Stratiform Rain Type assignments unchanged."
ENDELSE

;=========================================================================
; clip the data fields down to the actual footprint points

; Single-level first (don't need BB replicated to all sweeps):
BB = BB[idxpractual]

; Now do the sweep-level arrays - have to build an array index of actual
; points over all the sweep levels
idx3d=long(gvexp)   ; take one of the 2D arrays, make it LONG type
idx3d[*,*] = 0L     ; initialize all points to 0
idx3d[idxpractual,0] = 1L      ; set the first sweep to 1 where non-bogus

; copy the first sweep to the other levels, and make the single-level arrays
; for categorical fields the same dimension as the sweep-level
rnFlagIn = rnFlag
rnTypeIn = rnType
IF ( nsweeps GT 1 ) THEN BEGIN  
   FOR iswp=1, nsweeps-1 DO BEGIN
      idx3d[*,iswp] = idx3d[*,0]
      rnFlag = [rnFlag, rnFlagIn]  ; concatenate another level's worth
      rnType = [rnType, rnTypeIn]
   ENDFOR
ENDIF
; get the indices of all the non-bogus points in the 2D arrays
idxpractual2d = where( idx3d EQ 1L, countactual2d )
if (countactual2d EQ 0) then begin
  ; this shouldn't be able to happen
   print, "No non-bogus 2D data points, quitting case."
   goto, errorExit
endif

; clip the sweep-level arrays
gvexp = gvexp[idxpractual2d]
gvrej = gvrej[idxpractual2d]
prexp = prexp[idxpractual2d]
zrawrej = zrawrej[idxpractual2d]
zcorrej = zcorrej[idxpractual2d]
rainrej = rainrej[idxpractual2d]
gvz = gvz_in[idxpractual2d]
zraw = zraw[idxpractual2d]
zcor = zcor_in[idxpractual2d]
rain3 = rain3[idxpractual2d]
top = top[idxpractual2d]
botm = botm[idxpractual2d]
lat = lat[idxpractual2d]
lon = lon[idxpractual2d]
rnFlag = rnFlag[idxpractual2d]
rnType = rnType[idxpractual2d]

;=========================================================================
; optional data clipping based on percent completeness of the volume averages

IF ( pctAbvThresh GT 0.0 ) THEN BEGIN
   IF ( pctAbvThresh EQ 100.0 ) THEN BEGIN
    ; clip to the 'good' points, where ALL bins in average were above threshold
      idxallgood = WHERE( prexp GT 0 AND gvrej EQ 0 AND zcorrej EQ 0, countgood )
      if ( countgood GT 0 ) THEN BEGIN
         gvz = gvz[idxallgood]
         zraw = zraw[idxallgood]
         zcor = zcor[idxallgood]
         rain3 = rain3[idxallgood]
         top = top[idxallgood]
         botm = botm[idxallgood]
         lat = lat[idxallgood]
         lon = lon[idxallgood]
         rnFlag = rnFlag[idxallgood]
         rnType = rnType[idxallgood]
         IF ( PPIbyThresh ) THEN BEGIN
            idx2plot=idxpractual2d[idxallgood]
            n2plot=countgood
         ENDIF
      endif ELSE BEGIN
         print, "No complete-volume points, quitting case."
         goto, errorExit
      endelse
   ENDIF ELSE BEGIN
    ; clip to the 'good' points, where 'pctAbvThresh' fraction of bins in average
    ; were above threshold
      idxexpgt0 = WHERE( prexp GT 0 AND gvexp GT 0, countexpgt0 )
      IF ( countexpgt0 EQ 0 ) THEN BEGIN
         print, "No valid volume-average points, quitting case."
         goto, errorExit
      ENDIF ELSE BEGIN
         pctgoodpr = 100.0 * FLOAT( prexp[idxexpgt0] - zcorrej[idxexpgt0] ) / prexp[idxexpgt0]
         pctgoodgv = 100.0 * FLOAT( gvexp[idxexpgt0] - gvrej[idxexpgt0] ) / gvexp[idxexpgt0]
         idxgoodpct = WHERE( pctgoodpr GE pctAbvThresh $
                        AND  pctgoodgv GE pctAbvThresh, countgoodpct )
         IF ( countgoodpct GT 0 ) THEN BEGIN
            idxgoodenuff = idxexpgt0[idxgoodpct]
            gvz = gvz[idxgoodenuff]
            zraw = zraw[idxgoodenuff]
            zcor = zcor[idxgoodenuff]
            rain3 = rain3[idxgoodenuff]
            top = top[idxgoodenuff]
            botm = botm[idxgoodenuff]
            lat = lat[idxgoodenuff]
            lon = lon[idxgoodenuff]
            rnFlag = rnFlag[idxgoodenuff]
            rnType = rnType[idxgoodenuff]
            IF ( PPIbyThresh ) THEN BEGIN
               idx2plot=idxpractual2d[idxgoodenuff]
               n2plot=countgoodpct
            ENDIF
         ENDIF ELSE BEGIN
            print, "No complete-volume points, quitting case."
            goto, errorExit
         ENDELSE
      ENDELSE
   ENDELSE

ENDIF ELSE BEGIN
   IF ( PPIbyThresh ) THEN BEGIN
      idx2plot=idxpractual2d
      n2plot=countactual2d
   ENDIF
ENDELSE

IF ( PPIbyThresh ) THEN BEGIN
  ; re-set this for our later use in PPI plotting
   idx3d[*,*] = 0L     ; initialize all points to 0
   idx3d[idx2plot] = 2L
   idx2blank = WHERE( idx3d EQ 0L, count2blank )
   gvz_in2 = gvz_in
   zcor_in2 = zcor_in
   IF ( count2blank GT 0 ) THEN BEGIN
     gvz_in2[idx2blank] = 0.0
     zcor_in2[idx2blank] = 0.0
   ENDIF
  ; determine the non-missing points-in-common between PR and GV, data value-wise
   idx2blank2 = WHERE( (gvz_in2 LT 0.0) OR (zcor_in2 LE 0.0), count2blank2 )
   IF ( count2blank2 GT 0 ) THEN BEGIN
     gvz_in2[idx2blank2] = 0.0
     zcor_in2[idx2blank2] = 0.0
   ENDIF
ENDIF

;=========================================================================

; convert bright band heights from m to km, where defined, and get mean BB hgt
idxbbdef = where(bb GT 0.0, countBB)
if ( countBB GT 0 ) THEN BEGIN
   meanbb_m = FIX(MEAN(bb[idxbbdef]))  ; in meters
   meanbb = meanbb_m/1000.        ; in km
   BB_HgtLo = (meanbb_m-1001)/1500
;  Level above BB is affected if BB_Hgt is 1000m or less below layer center,
;  so BB_HgtHi is highest grid layer considered to be within the BB
   BB_HgtHi = (meanbb_m-500)/1500
   BB_HgtLo = BB_HgtLo < 12
   BB_HgtHi = BB_HgtHi < 12
   print, 'Mean BB (km), bblo, bbhi = ', meanbb, BB_HgtLo, BB_HgtHi
ENDIF ELSE BEGIN
   print, "No valid bright band heights, quitting case."
   goto, errorExit
ENDELSE

; build an array of ranges, range categories from the GV radar

; 1) range via great circle formula:
;phif = !DTOR * lat
;thetaf = !DTOR * lon
;phis = !DTOR * site_lat
;thetas = !DTOR * site_lon
;re = 6371.0   ; radius of earth, km
;term1 = ( sin( (phif-phis)/2 ) )^2
;term2 = cos(phif) * cos(phis) * ( sin((thetaf-thetas)/2) )^2
;dist_by_gc = re * 2 * asin( sqrt( term1+term2 ) )

; 2) range via map projection x,y coordinates:
; initialize a gv-centered map projection for the ll<->xy transformations:
sMap = MAP_PROJ_INIT( 'Azimuthal Equidistant', center_latitude=site_lat, $
                      center_longitude=site_lon )
XY_km = map_proj_forward( lon, lat, map_structure=smap ) / 1000.
dist = SQRT( XY_km[0,*]^2 + XY_km[1,*]^2 )
;dist_by_xy = SQRT( XY_km[0,*]^2 + XY_km[1,*]^2 )

; array of range categories: 0 for 0<=r<50, 1 for 50<=r<100, 2 for r>=100, etc.
;   (for now we only have points roughly inside 100km, so limit to 2 categs.)
distcat = ( FIX(dist) / 50 ) < 1

; build an array of height category for the traditional VN levels
hgtcat = distcat  ; for a starter
hgtcat[*] = -99   ; re-initialize to -99
beamhgt = botm    ; for a starter, to build array of center of beam
heights = [1.5,3.0,4.5,6.0,7.5,9.0,10.5,12.0,13.5,15.0,16.5,18.0,19.5]
nhgtcats = N_ELEMENTS(heights)
num_in_hgt_cat = LONARR( nhgtcats )
halfdepth = 0.75
idxhgtdef = where( botm GT halfdepth AND top GT halfdepth, counthgtdef )
IF ( counthgtdef GT 0 ) THEN BEGIN
   beamhgt[idxhgtdef] = (top[idxhgtdef]+botm[idxhgtdef])/2
   hgtcat[idxhgtdef] = FIX((beamhgt[idxhgtdef]-halfdepth)/(halfdepth*2.0))
   idx2low = where( beamhgt[idxhgtdef] LT halfdepth, n2low )
   if n2low GT 0 then hgtcat[idxhgtdef[idx2low]] = -1

   FOR i=0, nhgtcats-1 DO BEGIN
      hgtstr =  string(heights[i], FORMAT='(f0.1)')
      idxhgt = where(hgtcat EQ i, counthgts)
      num_in_hgt_cat[i] = counthgts
;      if ( counthgts GT 0 ) THEN BEGIN
;         print, "HEIGHT = "+hgtstr+" km: npts = ", counthgts, " min = ", $
;            min(beamhgt[idxhgt]), " max = ", max(beamhgt[idxhgt])
;      endif else begin
;         print, "HEIGHT = "+hgtstr+" km: npts = ", counthgts
;      endelse
   ENDFOR
ENDIF ELSE BEGIN
   print, "No valid beam heights, quitting case."
   goto, errorExit
ENDELSE

bs = 1.
;minz4hist = 18.  ; not used, replaced with dbzcut
maxz4hist = 55.
dbzcut = 10.      ; absolute PR/GV dBZ cutoff of points to use in mean diff. calcs.
rangecut = 100.

device, decomposed = 0
LOADCT, 2

the_struc = { diffsset, $
              meandiff: -99.999, meandist: -99.999, fullcount: 0L,  $
              maxpr: -99.999, maxgv: -99.999, $
              meandiffc: -99.999, countc: 0L, $
              meandiffs: -99.999, counts: 0L, $
              AvgDifByHist: -99.999 $
            }

print, ''
print, ' Vert. |   Any Rain Type  |    Stratiform    |    Convective     |     Dataset Statistics      |     |'
print, ' Layer |  PR-GV    NumPts |  PR-GV    NumPts |  PR-GV    NumPts  | AvgDist   PR MaxZ   GV MaxZ | BB? |'
print, ' ----- | -------   ------ | -------   ------ | -------   ------  | -------   -------   ------- | --- |'

mnprarr = fltarr(3,13)  ; each level, for raintype all, stratiform, convective
mngvarr = fltarr(3,13)  ; each level, for raintype all, stratiform, convective
levhasdata = intarr(13) & levhasdata[*] = 0
levsdata = 0

;# # # # # # # # # # # # # # # # # # # # # # # # #
; Compute a mean dBZ difference at each level

for lev2get = 0, 12 do begin
   havematch = 0
   thishgt = (lev2get+1)*1.5
   IF ( num_in_hgt_cat[lev2get] GT 0 ) THEN BEGIN
      flag = ''
      prz4hist = fltarr(num_in_hgt_cat[lev2get])  ; PR dBZ values used for point-to-point mean diffs
      gvz4hist = fltarr(num_in_hgt_cat[lev2get])  ; GV dBZ values used for point-to-point mean diffs
      type4hist = intarr(num_in_hgt_cat[lev2get])  ; rain type values used for point-to-point mean diffs
      prz4hist[*] = 0.0
      gvz4hist[*] = 0.0
      type4hist[*] = RainType_missing
      if (lev2get eq BB_HgtLo OR lev2get eq BB_HgtHi) then flag = ' @ BB'
      diffstruc = the_struc
      calc_geo_pr_gv_meandiffs, zcor, gvz, rnType, dist, distcat, hgtcat, $
                             lev2get, dbzcut, rangecut, bs, mnprarr, mngvarr, $
                             havematch, diffstruc,  prz4hist, gvz4hist, type4hist
      if(havematch eq 1) then begin
         levsdata = levsdata + 1
         levhasdata[lev2get] = 1
        ; format level's stats for table output
         stats55 = STRING(diffstruc.meandiff, diffstruc.fullcount, $
                       diffstruc.meandiffs, diffstruc.counts, $
                       diffstruc.meandiffc, diffstruc.countc, $
                       diffstruc.meandist, diffstruc.maxpr, diffstruc.maxgv, $
                       FORMAT='(3("    ",f7.3,"    ",i4),"  ",3("   ",f7.3))' )
        ; extract/format level's stats for graphic plots output
         dbzpr2 = prz4hist[0:diffstruc.fullcount-1]
         dbzgv2 = gvz4hist[0:diffstruc.fullcount-1]
         mndifhstr = string(diffstruc.AvgDifByHist, FORMAT='(f0.3)')
         mndifstr = string(diffstruc.meandiff, diffstruc.fullcount, FORMAT='(f0.3," (",i0,")")')
         mndifstrc = string(diffstruc.meandiffc, diffstruc.countc, FORMAT='(f0.3," (",i0,")")')
         mndifstrs = string(diffstruc.meandiffs, diffstruc.counts, FORMAT='(f0.3," (",i0,")")')
         prz4hist[*] = 0.0
         gvz4hist[*] = 0.0
         print, (lev2get+1)*1.5, stats55, flag, FORMAT='(" ",f4.1,a0," ",a0)'
      endif else begin
         print, "No above-threshold points at height " $
                 + string(heights[lev2get], FORMAT='(f0.3)')
      endelse
   ENDIF ELSE BEGIN
      print, "No points at height " + string(heights[lev2get], FORMAT='(f0.3)')
   ENDELSE
  ; Plot the PDF graph for preselected level
   if ( thishgt eq height ) then begin
      hgtstr = string(thishgt, FORMAT='(f0.1)')
      hgtline = 'Height = ' + hgtstr + ' km'
      if ( havematch eq 0 ) then begin
         print, ""
         print, "No valid data found for ", hgtline, ", skipping reflectivity histogram.
         Window, xsize=500, ysize=350
         !P.Multi=[0,1,1,0,0]
      endif else begin

       ; Build the PDF plots for 'thishgt' level
         Window, xsize=500, ysize=700
         !P.Multi=[0,1,2,0,0]

         if ( havematch eq 1) then begin
;            prhist = histogram(dbzpr2, min=minz4hist, max=maxz4hist, binsize = bs, $
            prhist = histogram(dbzpr2, min=dbzcut, max=maxz4hist, binsize = bs, $
                               locations = prhiststart)
;            nxhist = histogram(dbzgv2, min=minz4hist, max=maxz4hist, binsize = bs)
            nxhist = histogram(dbzgv2, min=dbzcut, max=maxz4hist, binsize = bs)
            plot, [15,MAX(prhiststart)],[0,FIX((MAX(prhist)>MAX(nxhist))*1.1)], /NODATA, COLOR = 255, $
                  XTITLE=hgtstr+' km Reflectivity, dBZ', $
                  YTITLE='Number of PR Footprints', $
                  YRANGE=[0,FIX((MAX(prhist)>MAX(nxhist))*1.1)], $
;                  TITLE = strmid( bname, 7, prlen-10), CHARSIZE=1
                  TITLE = strmid( bname, 7, 17)+"  "+'!m'+STRING("142B)+pctString+ $
                          "% of averaged bins above dBZ thresholds", $
                          CHARSIZE=1, BACKGROUND=0
            oplot, prhiststart, prhist, COLOR = 30
            xyouts, 0.19, 0.95, 'PR', COLOR = 30, /NORMAL, CHARSIZE=1
            plots, [0.14,0.18], [0.955,0.955], COLOR = 30, /NORMAL
            xyouts, 0.6,0.925, hgtline, COLOR = 255, /NORMAL, CHARSIZE=1.5
;            xyouts, 0.6,0.675, tdiffline, COLOR = 255, /NORMAL, CHARSIZE=1
            mndifline = 'PR-'+siteID+' Bias: ' + mndifstr
            mndifhline = 'PR-'+siteID+' Histo Bias: ' + mndifhstr
            mndiflinec = 'PR-'+siteID+' Bias(Conv): ' + mndifstrc
            mndiflines = 'PR-'+siteID+' Bias(Strat): ' + mndifstrs
            oplot, prhiststart, nxhist, COLOR = 70
            xyouts, 0.19, 0.925, siteID, COLOR = 70, /NORMAL, CHARSIZE=1
            plots, [0.14,0.18], [0.93,0.93], COLOR = 70, /NORMAL
            xyouts, 0.6,0.875, mndifline, COLOR = 255, /NORMAL, CHARSIZE=1
            xyouts, 0.6,0.85, mndifhline, COLOR = 255, /NORMAL, CHARSIZE=1
            xyouts, 0.6,0.825, mndiflinec, COLOR = 255, /NORMAL, CHARSIZE=1
            xyouts, 0.6,0.8, mndiflines, COLOR = 255, /NORMAL, CHARSIZE=1
         endif
         if (flag ne '') then xyouts, 0.6,0.75,'Bright Band Affected', $
                              COLOR = 150, /NORMAL, CHARSIZE=1
      endelse ; if ( havematch eq 1 )
   endif  ; if thishgt eq height
endfor

; Build the mean Z profile plot panel

if (levsdata eq 0) then begin
   print, "No valid data levels found for reflectivity!"
   nframes = 0
   goto, nextFile
endif

;print, levhasdata
idxlev2plot = WHERE( levhasdata EQ 1 )

h2plot = (findgen(13) + 1) * 1.5
h2plot = h2plot[idxlev2plot]
; plot the profile for all points regardless of rain type
prmnz2plot = mnprarr[0,*]
prmnz2plot = prmnz2plot[idxlev2plot]
gvmnz2plot = mngvarr[0,*]
gvmnz2plot = gvmnz2plot[idxlev2plot]
plot, [15,50], [0,20], /NODATA, COLOR = 255, $
      XSTYLE=1, YSTYLE=1, YTICKINTERVAL=1.5, YMINOR=1, thick=1, $
      XTITLE='Level Mean Reflectivity, dBZ', YTITLE='Height Level, km'
oplot, prmnz2plot, h2plot, COLOR = 30, thick=1
oplot, gvmnz2plot, h2plot, COLOR = 70, thick=1

; plot the profile for stratiform rain type points
prmnz2plot = mnprarr[1,*]
prmnz2plot = prmnz2plot[idxlev2plot]
gvmnz2plot = mngvarr[1,*]
gvmnz2plot = gvmnz2plot[idxlev2plot]
idxhavezs = WHERE( prmnz2plot GT 0.0 and gvmnz2plot GT 0.0, counthavezs )
IF ( counthavezs GT 0 ) THEN BEGIN
   oplot, prmnz2plot[idxhavezs], h2plot[idxhavezs], COLOR = 30, LINESTYLE=1, thick=3
   oplot, gvmnz2plot[idxhavezs], h2plot[idxhavezs], COLOR = 70, LINESTYLE=1, thick=3
ENDIF

; plot the profile for convective rain type points
prmnz2plot = mnprarr[2,*]
prmnz2plot = prmnz2plot[idxlev2plot]
gvmnz2plot = mngvarr[2,*]
gvmnz2plot = gvmnz2plot[idxlev2plot]
idxhavezs = WHERE( prmnz2plot GT 0.0 and gvmnz2plot GT 0.0, counthavezs )
IF ( counthavezs GT 0 ) THEN BEGIN
   oplot, prmnz2plot[idxhavezs], h2plot[idxhavezs], COLOR = 30, LINESTYLE=2, thick=2
   oplot, gvmnz2plot[idxhavezs], h2plot[idxhavezs], COLOR = 70, LINESTYLE=2, thick=2
ENDIF

xvals = [15,50]
yvals = [height, height]
plots, xvals, yvals, COLOR = 255, LINESTYLE=4;, THICK=3
xvalsleg1 = [37,39] & yvalsleg1 = 18
plots, xvalsleg1, yvalsleg1, COLOR = 255, LINESTYLE=4;, THICK=3
XYOutS, 39.5, 17.9, 'Stats Height', COLOR = 255, CHARSIZE=1

yvalsbb = [meanbb, meanbb]
plots, xvals, yvalsbb, COLOR = 255, LINESTYLE=2;, THICK=3
yvalsleg2 = 17
plots, xvalsleg1, yvalsleg2, COLOR = 255, LINESTYLE=2
XYOutS, 39.5, 16.9, 'Mean BB Hgt', COLOR = 255, CHARSIZE=1

yvalsleg2 = 16
plots, xvalsleg1, yvalsleg2, COLOR = 255
XYOutS, 39.5, 15.9, 'Any Type', COLOR = 255, CHARSIZE=1

yvalsleg2 = 15
plots, xvalsleg1, yvalsleg2, COLOR = 255, LINESTYLE=1, THICK=3
XYOutS, 39.5, 14.9, 'Stratiform', COLOR = 255, CHARSIZE=1

yvalsleg2 = 14
plots, xvalsleg1, yvalsleg2, COLOR = 255, LINESTYLE=2, THICK=2
XYOutS, 39.5, 13.9, 'Convective', COLOR = 255, CHARSIZE=1

;==============================================================================
; Build the PPI animation loop.

nframes = mygeometa.num_sweeps < elevs2show
IF ( elevs2show EQ 0 ) THEN GOTO, nextFile
do_pixmap=0
IF ( elevs2show GT 1 ) THEN do_pixmap=1
!P.MULTI=[0,1,1]
IF ( N_ELEMENTS(windowsize) NE 1 ) THEN windowsize = 375
xsize = windowsize[0]
ysize = xsize

nppis=1
IF ( PPIbyThresh ) THEN nppis=2

; set up the orientation of the PPIs - side-by-side, or vertical
IF (PPIorient) THEN BEGIN
   nx = nppis
   ny = 2
ENDIF ELSE BEGIN
   nx = 2
   ny = nppis
ENDELSE
window, 1, xsize=xsize*nx, ysize=ysize*ny, xpos = 75, TITLE = title, PIXMAP=do_pixmap

; instantiate animation widget
IF nframes GT 1 THEN xinteranimate, set=[xsize*nx, ysize*ny, nframes], /TRACK

error = 0
loadcolortable, 'CZ', error
if error then begin
    print, "In geo_match_z_plots: error from loadcolortable"
    something = ""
    READ, something, PROMPT='Hit Return to proceed to next case, Q to Quit: '
    goto, errorExit2
endif

FOR ifram=0,nframes-1 DO BEGIN
elevstr =  string(mysweeps[ifram].elevationAngle, FORMAT='(f0.1)')
prtitle = "PR for "+elevstr+" degree sweep, "+mygeometa.atimeNearestApproach
myprbuf = plot_sweep_2_zbuf( zcor_in, mysite.site_lat, mysite.site_lon, xCorner, $
                             yCorner, pr_index, mygeometa.num_footprints, ifram, $
                             rnTypeIn, WINSIZ=windowsize, TITLE=prtitle )
gvtitle = mysite.site_ID+" at "+elevstr+" degrees, "+mysweeps[ifram].atimeSweepStart
mygvbuf = plot_sweep_2_zbuf( gvz_in, mysite.site_lat, mysite.site_lon, xCorner, $
                             yCorner, pr_index, mygeometa.num_footprints, ifram, $
                             rnTypeIn, WINSIZ=windowsize, TITLE=gvtitle )
IF ( PPIbyThresh ) THEN BEGIN
   prtitle = "PR, for "+'!m'+STRING("142B)+pctString+"% of PR/GV bins above threshold"
   myprbuf2 = plot_sweep_2_zbuf( zcor_in2, mysite.site_lat, mysite.site_lon, xCorner, $
                             yCorner, pr_index, mygeometa.num_footprints, ifram, $
                             rnTypeIn, WINSIZ=windowsize, TITLE=prtitle )
   gvtitle = mysite.site_ID+", for "$
             +'!m'+STRING("142B)+pctString+"% of PR/GV bins above threshold"
   mygvbuf2 = plot_sweep_2_zbuf( gvz_in2, mysite.site_lat, mysite.site_lon, xCorner, $
                             yCorner, pr_index, mygeometa.num_footprints, ifram, $
                             rnTypeIn, WINSIZ=windowsize, TITLE=gvtitle )
ENDIF
;print, "Finished zbuf pair ", ifram+1
;print, mysweeps[ifram].atimeSweepStart
SET_PLOT, 'X'
device, decomposed=0
TV, myprbuf, 0
TV, mygvbuf, 1
IF ( PPIbyThresh ) THEN BEGIN
   TV, myprbuf2, 2
   TV, mygvbuf2, 3
ENDIF

IF nframes GT 1 THEN xinteranimate, frame = ifram, window=1
ENDFOR

IF nframes GT 1 THEN BEGIN
   print, ''
   print, 'Click END ANIMATION button or close Animation window to proceed to next case:
;   print, ''
   xinteranimate, looprate, /BLOCK
ENDIF
;==============================================================================

nextFile:

something = ""
IF nframes LT 2 THEN READ, something, PROMPT='Hit Return to proceed to next case, Q to Quit: '
IF ( elevs2show GT 0 AND nframes GT 0 ) THEN WDELETE, 1

errorExit2:

if ( levsdata NE 0 ) THEN WDELETE, 0
status = 0
IF something EQ 'Q' OR something EQ 'q' THEN status = 1

errorExit:

return, status
end
