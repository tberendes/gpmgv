;===============================================================================
;+
; Copyright © 2011, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; tmi2gr_rainrate_comparisons.pro
; - Morris/SAIC/GPM_GV  June 2011
;
; DESCRIPTION
; -----------
; Performs a case-by-case statistical analysis of geometry-matched TMI and GR
; rain rate from data contained in a geo-match netCDF file.  Rain rate for GR
; is derived from the volume-averaged reflectivity using a Z-R relationship. 
; TMI rainrate is the near-surface rain rate stored in the netCDF file and
; originates within the 2A-12 product.
;
; INTERNAL MODULES
; ----------------
; 1) tmi2gr_rainrate_comparisons - Main procedure called by user.  Checks
;                                  input parameters and sets defaults.
;
; 2) geo_match_rr_plots - Workhorse procedure to read data, compute statistics,
;                         create vertical profile, histogram, scatter plots, and
;                         tables of PR-GR rainrate differences, and display PR
;                         and GR reflectivity PPI plots in an animation sequence.
;
; HISTORY
; -------
; 06/03/11 Morris, GPM GV, SAIC
; - Created from geo_match_rainrate_comparisons.pro
; 06/15/11 Morris, GPM GV, SAIC
; - Added option to plot histograms of GR PCT_ABV_THRESH.
; 07/12/11 Morris, GPM GV, SAIC
; - Added call to get_gr_geo_match_rain_type() to compute GR-derived rain type
;   from vertical profiles of GR reflectivity (gvz_vpr field).
; 08/01/11 Morris, GPM GV, SAIC
; - Fixed bug where pctgoodgv would not be computed if pctabvthresh=0.0,
;   resulting in a blank PPI plot for the SHOW_THRESH_PPI plots.
; 11/21/11 Morris, GPM GV, SAIC
; - Modified PDF and scatter plots to only include data for one selected CAPPI
;   level, and added the CAPPI_idx parameter to specify the array index of the
;   CAPPI height level to use, based on the 'heights' array definition in
;   geo_match_rr_plots().
; - Removed the GV_CONVECTIVE and GV_STRATIFORM parameters.
; - Added reading and use of the PoP variable in the V7 matchup files to filter
;   footprints based on a PoP threshold of 50%.
; 08/15/13 Morris, GPM GV, SAIC
; - Removed unused 'histo_Width' parameter and 'bs' variable from internal
;   modules and external call to calc_geo_pr_gv_meandiffs_wght_idx.
; 10/18/13 by Bob Morris, GPM GV (SAIC)
;  - Added ability to read and use GR rain rate variables from version 2.0
;    GRtoTMI matchup files in place of Z-R derived GR rain rate.
;  - Added siteID and x_title to parameters for plot_scatter_by_sfc_type3x3[_ps].
;  - Fixed use of PoP threshold so that it only applies over ocean surface type.
;  - Made pop_threshold a parameter to optionally override the 50% default value.
;
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;===============================================================================
;
; MODULE 1:  geo_match_rr_plots
;
; DESCRIPTION
; -----------
; Reads TMI rainrate and GV Z, and spatial fields from a user-selected geo_match
; netCDF file, builds index arrays of categories of range, rain type, 
; and arrays of actual range and of estimated rain type based on reflectivity. 
; Computes mean TMI-GV rainrate differences for each of the 3 underlying surface
; type categories for points within 100 km of the ground radar and reports the
; results in a table to stdout.  Also produces graphs of the Probability
; Density Function of TMI and GV rainrate for each of these 3 surface
; types where data exists for that type, and vertical profiles of
; mean TMI and GV rainrate, for each of 3 rain type categories: Any,
; Stratiform, and Convective. 
;
; Optionally produces a single frame or an animation loop of GV and equivalent
; TMI PPI images for N=elevs2show frames.  Footprints in the PPIs are encoded by
; rain type by pattern: solid=Other, vertical=Convective, horizontal=Stratiform.
;
; Also, optionally produces histogram plots of GV percent above threshold for
; the data samples in the file, for 3 categories of either Rain Type or Surface
; Type, as specified in the input parameter PLOT_PCT_CAT.  Option is disabled if
; PLOT_PCT_CAT is unspecified or its value is not 'RainType' or 'SurfaceType'.
;
; If PS_DIR is specified then the output is to a Postscript file under ps_dir,
; otherwise all output is to the screen.  When outputting to Postscript, the
; PPI animation is still to the screen but the PDF and scatter plots go to the
; Postscript device, as well as a copy of the last frame of the PPI images in
; the animation loop.  The name of the Postscript file uses the station ID,
; datestamp, and orbit number taken from the geo_match netCDF data file.
; If b_w is set, then Postscript output will be black and white, otherwise it's
; in color.
;

FUNCTION gr2tmi_rr_plots, mygeomatchfile, looprate, elevs2show, startelev, $
                          PPIorient, windowsize, pctabvthresh, PPIbyThresh, $ 
                          hideTotals, CAPPI_idx, POP_THRESHOLD=pop_threshold, $
                          PS_DIR=ps_dir, B_W=b_w, USE_VPR=use_vpr, $
                          PLOT_PCT_CAT=plot_pct_cat

; "include" file for read_geo_match_netcdf() structs returned
@geo_match_nc_structs.inc

; "include" file for PR data constants
@pr_params.inc

bname = file_basename( mygeomatchfile )
prlen = strlen( bname )
pctString = STRTRIM(STRING(FIX(pctabvthresh)),2)
popString = STRTRIM(STRING(FIX(pop_threshold)),2)
parsed = STRSPLIT( bname, '.', /extract )
site = parsed[1]
yymmdd = parsed[2]
orbit = parsed[3]
version = parsed[4]

bbparms = {meanBB : 4.0, BB_HgtLo : -99, BB_HgtHi : -99}
RRcut = 0.1 ;10.      ; TMI/GV rainrate lower cutoff of points to use in mean diff. calcs.
rangecut = 100.

; Define the list of fixed-height levels for the vertical profile statistics
heights = [1.5,3.0,4.5,6.0,7.5,9.0,10.5,12.0,13.5,15.0,16.5,18.0,19.5]
;hgtinterval = 1.5
;heights = [1.0,2.0,3.0,4.0,5.0,6.0,7.0,8.0,9.0,10.0,11.0,12.0,13.0,14.0,15.0,16.0,17.0,18.0]
;heights = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0]

hgtinterval = 1.5
halfdepth=(heights[1]-heights[0])/2.0
print, 'pctAbvThresh = ', pctAbvThresh

; find and assign CAPPI height whose data are to be included scatter and PDF plots
ncappis=N_ELEMENTS(heights)
IF ( CAPPI_idx GT (ncappis-1) ) THEN BEGIN
   print, "CAPPI_idx value larger than heights array allows, overriding to highest value: ", ncappis-1
   CAPPI_idx = ncappis-1
ENDIF
CAPPI_height = heights[CAPPI_idx]
print, ""
print, "CAPPI level (km): ", CAPPI_height
print, ""

cpstatus = uncomp_file( mygeomatchfile, myfile )
if(cpstatus eq 'OK') then begin
  status = 1   ; init to FAILED
  mygeometa = get_geo_match_nc_struct( 'matchup' )
  mysweeps = get_geo_match_nc_struct( 'sweeps' )
  mysite = get_geo_match_nc_struct( 'site' )
  myflags = get_geo_match_nc_struct( 'fields_tmi' )
  myfiles =  get_geo_match_nc_struct( 'files' )
  status = read_tmi_geo_match_netcdf( myfile, matchupmeta=mygeometa, $
     sweepsmeta=mysweeps, sitemeta=mysite, fieldflags=myflags, filesmeta=myfiles )

 ; create data field arrays of correct dimensions and read data fields
  nfp = mygeometa.num_footprints
  nswp = mygeometa.num_sweeps

  gvexp=intarr(nfp,nswp)
  gvrej=intarr(nfp,nswp)
  gvexp_vpr=gvexp
  gvrej_vpr=gvrej
  gvz=fltarr(nfp,nswp)
  gvzmax=fltarr(nfp,nswp)
  gvzstddev=fltarr(nfp,nswp)
  gvz_vpr=fltarr(nfp,nswp)
  gvzmax_vpr=fltarr(nfp,nswp)
  gvzstddev_vpr=fltarr(nfp,nswp)
  IF ( mygeometa.nc_file_version GE 2.0 $
   AND myflags.have_GR_RR_VPR EQ 1 ) THEN BEGIN
    ; set flag for presence of GR rain rate and init. variables to read it
     have_rr = 1
     gv_rr_rej=intarr(nfp,nswp)
     gv_rr_rej_vpr=gv_rr_rej
     gv_rr=fltarr(nfp,nswp)
     gv_rr_max=fltarr(nfp,nswp)
     gv_rr_stddev=fltarr(nfp,nswp)
     gv_rr_vpr=fltarr(nfp,nswp)
     gv_rr_max_vpr=fltarr(nfp,nswp)
     gv_rr_stddev_vpr=fltarr(nfp,nswp)
  ENDIF ELSE have_RR = 0
have_RR = 0
  top=fltarr(nfp,nswp)
  botm=fltarr(nfp,nswp)
  top_vpr=top
  botm_vpr=botm
  xcorner=fltarr(4,nfp,nswp)
  ycorner=fltarr(4,nfp,nswp)
  lat=fltarr(nfp,nswp)
  lon=fltarr(nfp,nswp)
  sfclat=fltarr(nfp)
  sfclon=fltarr(nfp)
  sfctyp=intarr(nfp)
  sfcrain=fltarr(nfp)
  rnflag=intarr(nfp)
  dataflag=intarr(nfp)
  IF ( mygeometa.tmi_version EQ 7 ) THEN PoP=intarr(nfp)   ; only has data if V7
  tmi_index=lonarr(nfp)

  status = read_tmi_geo_match_netcdf( myfile, $
    grexpect_int=gvexp, grreject_int=gvrej, $
    grexpect_vpr_int=gvexp_vpr, grreject_vpr_int=gvrej_vpr, $
    dbzgv_viewed=gvz, dbzgv_vpr=gvz_vpr, $
    gvStdDev_viewed=gvzstddev, gvMax_viewed=gvzmax, $
    gvStdDev_vpr=gvzstddev_vpr, gvMax_vpr=gvzmax_vpr, $

    gr_rr_reject_int=gv_rr_rej, gr_rr_reject_vpr_int=gv_rr_rej_vpr, $
    rr_gv_viewed=gv_rr, rr_gv_vpr=gv_rr_vpr, $
    gvrrMax_viewed=gv_rr_max, gvrrStdDev_viewed=gv_rr_stddev, $
    gvrrMax_vpr=gv_rr_max_vpr, gvrrStdDev_vpr=gv_rr_stddev_vpr, $

    topHeight_viewed=top, bottomHeight_viewed=botm, $
    xCorners=xCorner, yCorners=yCorner, $
    latitude=lat, longitude=lon, $
    topHeight_vpr=top_vpr, bottomHeight_vpr=botm_vpr,           $
    TMIlatitude=sfclat, TMIlongitude=sfclon, $
    surfaceRain=sfcrain, sfctype_int=sfctyp, rainflag_int=rnFlag, $
    dataflag_int=dataFlag, PoP_int=PoP, tmi_idx_long=tmi_index )

  command3 = "rm  " + myfile
  spawn, command3
endif else begin
  print, 'Cannot copy/unzip geo_match netCDF file: ', mygeomatchfile
  print, cpstatus
  command3 = "rm  " + myfile
  spawn, command3
  goto, errorExit
endelse

IF (status EQ 1) THEN GOTO, errorExit

IF ( mygeometa.tmi_version EQ 7 ) THEN BEGIN
   idxpopmiss = WHERE( PoP GT 100, npopmiss )
   IF npopmiss GT 0 THEN PoP[idxpopmiss] = -99   ; fix the early matchup files, restore PoP "Missing value"
   idxpopok = WHERE( PoP GE pop_threshold AND sfctyp/10 EQ 1, countpopok )
   idxtmirain = WHERE( sfcrain GE RRcut, nsfcrainy )
   print, popString, countpopok, nsfcrainy, N_ELEMENTS(PoP), $
         FORMAT='("# Ocean w. PoP GE ", A0, "% = ", I0, ", # TMI rainy: ", I0, ",  # footprints = ", I0)'
;   print, PoP
ENDIF

; substitute GR vertical profile fields for along-TMI samples if indicated
IF KEYWORD_SET( use_vpr ) THEN BEGIN
   print, "Using VPR variables for Z, RR, top, botm, Reject counts."
   gvz = gvz_vpr
   gvexp = gvexp_vpr
   gvrej = gvrej_vpr
   top = top_vpr
   botm = botm_vpr
  ; use lowest-sweep's pixel outlines for each level (ignore TMI parallax)
   FOR level = 1, mygeometa.num_sweeps-1 DO BEGIN
      xCorner[*,*,level] = xCorner[*,*,0]
      yCorner[*,*,level] = yCorner[*,*,0]
   ENDFOR
   IF (have_RR) THEN BEGIN
      gv_rr = gv_rr_vpr
      gvrej = gv_rr_rej_vpr
      print, "Using RR-based reject count for percent above threshold computations."
   ENDIF
ENDIF ELSE BEGIN
   IF (have_RR) THEN BEGIN
      gvrej = gv_rr_rej
      print, "Using RR-based reject count for percent above threshold computations."
   ENDIF
ENDELSE

 ; open a file to hold output stats to be appended to the Postscript file,
 ; if Postscript output is indicated
  IF KEYWORD_SET( ps_dir ) THEN BEGIN
     do_ps = 1
     temptext = ps_dir + '/dbzdiffstats_temp.txt'
     OPENW, tempunit, temptext, /GET_LUN
  ENDIF ELSE do_ps = 0

nfp = mygeometa.num_footprints
nswp = mygeometa.num_sweeps
site_lat = mysite.site_lat
site_lon = mysite.site_lon
siteID = string(mysite.site_id)
nsweeps = mygeometa.num_sweeps

; get array indices of the non-bogus (i.e., "actual") footprints
; -- tmi_index is defined for one slice (sweep level), while most fields are
;    multiple-level (have another dimension: nswp).  Deal with this later on.
idxpractual = where(tmi_index GE 0L, countactual)
if (countactual EQ 0) then begin
   print, "No non-bogus data points, quitting case."
   status = 1
   goto, errorExit
endif
; get the subset of tmi_index values for actual TMI rays in the matchup
tmi_idx_actual = tmi_index[idxpractual]

; re-set the number of footprints in the geo_match_meta structure to the
; subsetted value
mygeometa.num_footprints = countactual

idx3d=long(gvexp)           ; take one of the 2D arrays, make it LONG type
idx3d[*,*] = 0L             ; re-set all point values to 0
idx3d[idxpractual,0] = 1L   ; set first-sweep-level values to 1 where non-bogus

; copy the first sweep values to the other levels, and while in the same loop,
; make the single-level arrays for categorical fields the same dimension as the
; sweep-level by array concatenation
IF ( nswp GT 1 ) THEN BEGIN  
   rnFlagApp = rnFlag
   sfcRainApp = sfcRain
   tmi_indexApp = tmi_index
   sfctypApp=sfctyp
   dataFlagApp=dataFlag
   IF ( mygeometa.tmi_version EQ 7 ) THEN PoPApp= PoP

   FOR iswp=1, nswp-1 DO BEGIN
      idx3d[*,iswp] = idx3d[*,0]    ; copy first level values to iswp'th level
      rnFlag = [rnFlag, rnFlagApp]  ; concatenate another level's worth for rain flag
      sfcRain = [sfcRain, sfcRainApp]  ; ditto for sfc rain
      tmi_index = [tmi_index, tmi_indexApp]  ; ditto for tmi_index
      sfctyp = [sfctyp, sfctypApp]  ; ditto for sfctyp
      dataFlag = [dataFlag, dataFlagApp]  ; ditto for dataFlag
      IF ( mygeometa.tmi_version EQ 7 ) THEN PoP = [PoP, PoPApp] 
   ENDFOR
ENDIF

; make copies of the full 2-D arrays of Z and RR for later plotting, and
; make tmi_index of the same dimesionality as the multi-level variables, it
; is a 1-D array after concatenation - get_gr_geo_match_rain_type() needs it to
; be same as gvz, top, botm, etc.
rain3_in = REFORM( sfcRain, nfp, nswp, /OVERWRITE )
tmi_index = REFORM( tmi_index, nfp, nswp, /OVERWRITE )
gvz_in = gvz
IF (have_RR) THEN gv_rr_in = gv_rr
print, ''

;-------------------------------------------------

; compute a rain type and BB height estimate from the GR vertical profiles

rntype = FIX(gvz) & rntype[*,*] = 3      ; Initialize a 2-D rainType array to 'Other'
;HELP, RNTYPE
meanBBgr = -99.99
rntype4ppi = get_gr_geo_match_rain_type( tmi_index, gvz_vpr, top_vpr, botm_vpr, $
                                         SINGLESCAN=0, VERBOSE=0, MEANBB=meanBBgr )
; copy the single-level rain type field to each level of 2-D array
FOR level = 0, mygeometa.num_sweeps-1 DO BEGIN
   rnType[*,level] = rntype4ppi
ENDFOR

; make copies of the full raintype and surfacetype fields for later plot of
;   optional PctAbvThresh histograms
rntype4pctabv = rnType
sfctype4pctabv = sfctyp/10  ; reassign surface type values (10,20,30) to (1,2,3)

; - - - - - - - - - - - - - - - - - - - - - - - -

; build an array of sample point ranges from the GV radar
; via map projection x,y coordinates computed from lat and lon:

; initialize a gv-centered map projection for the ll<->xy transformations:
sMap = MAP_PROJ_INIT( 'Azimuthal Equidistant', center_latitude=site_lat, $
                      center_longitude=site_lon )
XY_km = map_proj_forward( lon, lat, map_structure=smap ) / 1000.
dist = SQRT( XY_km[0,*]^2 + XY_km[1,*]^2 )
dist = REFORM( dist, countactual, nswp )

; - - - - - - - - - - - - - - - - - - - - - - - -

; build an array of height category for the fixed-height levels, for profiles

hgtcat = rnType   ; for a starter
hgtcat[*] = -99   ; re-initialize to -99
beamhgt = botm    ; for a starter, to build array of center of beam
nhgtcats = N_ELEMENTS(heights)
num_in_hgt_cat = LONARR( nhgtcats )
idxhgtdef = where( botm GT halfdepth AND top GT halfdepth, counthgtdef )
IF ( counthgtdef GT 0 ) THEN BEGIN
   beamhgt[idxhgtdef] = (top[idxhgtdef]+botm[idxhgtdef])/2
   hgtcat[idxhgtdef] = FIX((beamhgt[idxhgtdef]-halfdepth)/(halfdepth*2.0))
  ; deal with points that are too low or too high with respect to the
  ; height layers that have been defined
   idx2low = where( beamhgt[idxhgtdef] LT halfdepth, n2low )
   if n2low GT 0 then hgtcat[idxhgtdef[idx2low]] = -1
   idx2high = where( beamhgt[idxhgtdef] GT (heights[nhgtcats-1]+halfdepth), n2high )
   if n2high GT 0 then hgtcat[idxhgtdef[idx2high]] = -1
ENDIF ELSE BEGIN
   print, "No valid beam heights, quitting case."
   status = 1   ; set to FAILED
   goto, errorExit
ENDELSE

; - - - - - - - - - - - - - - - - - - - - - - - -

; Compute GV percent of expected points in bin-averaged results that were
; above dBZ thresholds set when the matchups were done.

pctgoodgv = fltarr( N_ELEMENTS(gvexp) )
pctgoodgv[*] = -99.9
IF (have_RR) THEN grsourcepct = 'Rainrate' ELSE grsourcepct = 'Reflectivity'
print, "======================================================="
print, "Computing Percent Above Threshold for GR "+grsourcepct+"."
idxexpgt0 = WHERE( gvexp GT 0, countexpgt0 )
IF ( countexpgt0 EQ 0 ) THEN BEGIN
   print, "No valid volume-average points, quitting case."
   print, "======================================================="
   status = 1
   goto, errorExit
ENDIF ELSE BEGIN
   pctgoodgv[idxexpgt0] = $
      100.0 * FLOAT( gvexp[idxexpgt0] - gvrej[idxexpgt0] ) / gvexp[idxexpgt0]
ENDELSE

; - - - - - - - - - - - - - - - - - - - - - - - -

; reassign surface type values (10,20,30) to (1,2,3).
ixCoast = WHERE(sfcTyp GT 12, countCoast)
ixLand = WHERE(sfcTyp GT 2 AND sfcTyp LT 13, countLand)
ixOcean = WHERE(sfcTyp GT 0 AND sfcTyp LT 3, countOcean)
sfcCat = sfcTyp/20
help, countCoast, countLand, countOcean
if countCoast gt 0 then sfcCat[ixCoast] = 3
if countLand gt 0 then sfcCat[ixLand] = 2
if countOcean gt 0 then sfcCat[ixOcean] = 1
print, sfcCat
; get info from array of surface type
num_over_SfcType = LONARR(4)
idxmix = WHERE( sfcCat EQ 3, countmix )  ; Coast
num_over_SfcType[3] = countmix
idxsea = WHERE( sfcCat EQ 1, countsea )  ; Ocean
num_over_SfcType[1] = countsea
idxland = WHERE( sfcCat EQ 2, countland )    ; Land
num_over_SfcType[2] = countland

; - - - - - - - - - - - - - - - - - - - - - - - -

; generate the CAPPI level arrays now that we have pctgoodgv

gvzCAP=FLTARR(nfp,ncappis)
hgtCAP=FLTARR(nfp,ncappis)
pctgoodgvCAP=FLTARR(nfp,ncappis)
sfcRainCAP=FLTARR(nfp,ncappis)
rnTypeCAP=INTARR(nfp,ncappis)
distCAP=FLTARR(nfp,ncappis)
sfcTypCAP=INTARR(nfp,ncappis)
CAPPIlev=FLTARR(nfp,ncappis)   ; height of fixed CAPPI levels, from "heights"
voldepthCAP=FLTARR(nfp,ncappis)
IF have_RR THEN gv_rrCAP=FLTARR(nfp,ncappis)
IF ( mygeometa.tmi_version EQ 7 ) THEN PoPCAP=INTARR(nfp,ncappis)

samphgt = (top+botm)/2

FOR ifram=0,ncappis-1 DO BEGIN
  ; vertical offset from CAPPI height level to center of sample volumes
   hgtdiff = ABS( samphgt - heights[ifram] )

  ; ray by ray, which sample is closest to the CAPPI height level?
   CAPPIdist = MIN( hgtdiff, idxcappi, DIMENSION=2 )

   hgtCAP[*,ifram] = samphgt[idxcappi]
   gvzCAP[*,ifram] = gvz[idxcappi]
   pctgoodgvCAP[*,ifram] = pctgoodgv[idxcappi]
   sfcRainCAP[*,ifram] = sfcRain[idxcappi]
   rnTypeCAP[*,ifram] = rnType[idxcappi]
   distCAP[*,ifram] = dist[idxcappi]
   sfcTypCAP[*,ifram] = sfcCat[idxcappi]
   CAPPIlev[*,ifram] = heights[ifram]
   voldepthCAP[*,ifram] = top[idxcappi] - botm[idxcappi]
   IF have_RR THEN gv_rrCAP[*,ifram] = gv_rr[idxcappi]
   IF ( mygeometa.tmi_version EQ 7 ) THEN PoPCAP[*,ifram] = PoP[idxcappi]
ENDFOR

; Preview our CAPPI level data - diagnostic output only

;idxmycappi = WHERE( CAPPIlev EQ CAPPI_height, countatcappi )
;IF ( countatcappi GT 0 ) THEN BEGIN
;   print, "sfcRain:" & print, sfcRainCAP[idxmycappi]
;   print, "gvz:" & print,  gvzCAP[idxmycappi]
;   print, "height:" & print,  hgtCAP[idxmycappi]
;   print, "rnType:" & print,  rnTypeCAP[idxmycappi]
;   print, "dist:" & print,  distCAP[idxmycappi]
;   print, "voldepth:" & print,  voldepthCAP[idxmycappi]
;   ; reassign surface type values (10,20,30) to (1,2,3).
;   print, "sfcCat:" & print,  sfcTypCAP[idxmycappi]/10
;ENDIF ELSE print, 'NO POINTS TO PRINT FOR CAPPI LEVEL'

; - - - - - - - - - - - - - - - - - - - - - - - -

; clip the arrays of CAPPI data that are used for the scatter diagrams and PDFs.
; If pctAbvThresh unspecified or set to zero, include all points regardless of
; 'completeness' of the volume averages.  IF V7, also filter on PoP >= pop_threshold

IF ( pctAbvThresh GT 0.0 ) THEN BEGIN
    ; clip to the 'good' points, where 'pctAbvThresh' fraction of bins in average
    ; were above threshold
   IF ( mygeometa.tmi_version EQ 7 ) THEN BEGIN
      idxgoodenuff = WHERE( (pctgoodgvCAP GE pctAbvThresh AND sfcTypCAP NE 1) OR $
          (pctgoodgvCAP GE pctAbvThresh AND PoPCAP GE pop_threshold AND sfcTypCAP EQ 1), countgoodpct )
      PRINT, 'ALSO FILTERING BASED ON V7 PoP GE '+popString
      print, "======================================================="
   ENDIF ELSE idxgoodenuff = WHERE( pctgoodgvCAP GE pctAbvThresh, countgoodpct )
ENDIF ELSE BEGIN
  ; pctAbvThresh is 0, take/plot ALL non-missing points
   IF ( mygeometa.tmi_version EQ 7 ) THEN BEGIN
      idxgoodenuff = WHERE( (pctgoodgvCAP GT 0.0 AND sfcTypCAP NE 1) OR $
          (pctgoodgvCAP GT 0.0 AND PoPCAP GE pop_threshold AND sfcTypCAP EQ 1), countgoodpct )
      PRINT, 'FILTERING BASED ON V7 PoP GE '+popString
      print, "======================================================="
   ENDIF ELSE idxgoodenuff = WHERE( pctgoodgvCAP GT 0.0, countgoodpct )
ENDELSE

IF ( countgoodpct GT 0 ) THEN BEGIN
    hgtCAP = hgtCAP
    IF have_RR THEN gvrrCAP = gv_rrCAP[idxgoodenuff] $
    ELSE gvrrCAP = z_r_rainrate(gvzCAP[idxgoodenuff])
    pctgoodgvCAP = pctgoodgvCAP[idxgoodenuff]
    sfcRainCAP = sfcRainCAP[idxgoodenuff]
    rnTypeCAP = rnTypeCAP[idxgoodenuff]
    distCAP = distCAP[idxgoodenuff]
    sfcTypCAP = sfcTypCAP[idxgoodenuff]
    CAPPIlev = CAPPIlev[idxgoodenuff]
    voldepthCAP = voldepthCAP[idxgoodenuff]
    IF ( mygeometa.tmi_version EQ 7 ) THEN PoPCAP = PoPCAP[idxgoodenuff]
ENDIF ELSE BEGIN
    print, "No complete-volume CAPPI points, quitting case."
    goto, errorExit
ENDELSE

; - - - - - - - - - - - - - - - - - - - - - - - -

; clip the arrays of data that are used for the vertical profile
; If pctAbvThresh unspecified or set to zero, include all points regardless of
; 'completeness' of the volume averages.

IF ( pctAbvThresh GT 0.0 ) THEN BEGIN
    ; clip to the 'good' points, where 'pctAbvThresh' fraction of bins in average
    ; were above threshold
   IF ( mygeometa.tmi_version EQ 7 ) THEN BEGIN
      idxgoodenuff = WHERE( (pctgoodgv GE pctAbvThresh AND sfcTyp NE 1) OR $
          (pctgoodgv GE pctAbvThresh AND PoPCAP GE pop_threshold AND sfcTyp EQ 1), countgoodpct )
   ENDIF ELSE idxgoodenuff = WHERE( pctgoodgv GE pctAbvThresh, countgoodpct )
ENDIF ELSE BEGIN
  ; pctAbvThresh is 0, take/plot ALL non-missing points
   IF ( mygeometa.tmi_version EQ 7 ) THEN BEGIN
      idxgoodenuff = WHERE( (pctgoodgv GT 0.0 AND sfcTyp NE 1) OR $
          (pctgoodgv GT 0.0 AND PoP GE pop_threshold AND sfcTyp EQ 1), countgoodpct )
   ENDIF ELSE idxgoodenuff = WHERE( pctgoodgv GT 0.0, countgoodpct )
ENDELSE

IF ( countgoodpct GT 0 ) THEN BEGIN
   IF have_RR THEN gvrr = gv_rr[idxgoodenuff] ELSE gvrr = z_r_rainrate(gvz[idxgoodenuff])
   top = top[idxgoodenuff]
   botm = botm[idxgoodenuff]
   lat = lat[idxgoodenuff]
   lon = lon[idxgoodenuff]
   rnFlag = rnFlag[idxgoodenuff]
   rnType = rnType[idxgoodenuff]
   dist = dist[idxgoodenuff]
   hgtcat = hgtcat[idxgoodenuff]
   sfcRain = sfcRain[idxgoodenuff]
   sfcTyp = sfcTyp[idxgoodenuff]
   IF ( mygeometa.tmi_version EQ 7 ) THEN PoPCAP = PoPCAP[idxgoodenuff]
   IF ( PPIbyThresh ) THEN BEGIN
       idx2plot=idxgoodenuff  ;idxpractual2d[idxgoodenuff]
       n2plot=countgoodpct
   ENDIF
ENDIF ELSE BEGIN
   print, "No complete-volume points, quitting case."
   goto, errorExit
ENDELSE

; as above, but optional data *blanking* based on percent completeness of the
; volume averages for PPI plots, operating on the full arrays of gvz and sfcrain:

IF ( PPIbyThresh ) THEN BEGIN
  ; we only use unclipped arrays for PPIs, so we work with copies of the z arrays
   idx3d = LONG( gvz_in )   ; make a copy
  ; re-set this for our later use in PPI plotting
   idx3d[*,*] = 0L       ; initialize all points to 0
   idx3d[idx2plot] = 2L  ; tag the points to be plotted in post-threshold PPI
   idx2blank = WHERE( idx3d EQ 0L, count2blank )
;HELP, GVZ_IN, GVZ_IN2
   IF (have_RR) THEN  gvz_in2 = gv_rr_in $
   ELSE gvz_in2 = REFORM( z_r_rainrate(gvz_in), nfp, nswp )
;   gvz_in = gvz_in2  ; plot rain rate for unthresholded GR also
;HELP, GVZ_IN, GVZ_IN2
   rain3_in2 = rain3_in
   IF ( count2blank GT 0 ) THEN BEGIN
     gvz_in2[idx2blank] = 0.0
     rain3_in2[idx2blank] = 0.0
PRINT, "NUMBER OF FOOTPRINTS TO BLANK BASED ON POP/PCT: ", count2blank
   ENDIF
  ; determine the non-missing points-in-common between PR and GV, data value-wise,
  ; to make sure the same points are plotted on PR and GV post-threshold PPIs
   idx2blank2 = WHERE( (gvz_in2 LT 0.0) OR (rain3_in2 LT 0.0), count2blank2 )
   IF ( count2blank2 GT 0 ) THEN BEGIN
     gvz_in2[idx2blank2] = 0.0
     rain3_in2[idx2blank2] = 0.0
PRINT, "NUMBER OF FOOTPRINTS TO BLANK BASED ON MATCHING NON-ZERO: ", count2blank2
   ENDIF
ENDIF

; - - - - - - - - - - - - - - - - - - - - - - - -

; build an array of range categories from the GV radar, using ranges previously
; computed from lat and lon by fprep_geo_match_profiles():
; - range categories: 0 for 0<=r<50, 1 for 50<=r<100, 2 for r>=100, etc.
;   (for now we only have points roughly inside 100km, so limit to 2 categs.)
distcat = ( FIX(dist) / 50 ) < 1
distcatCAP = ( FIX(distCAP) / 50 ) < 1

; get info from array of height category for the fixed-height levels, for profiles
nhgtcats = N_ELEMENTS(heights)
num_in_hgt_cat = LONARR( nhgtcats )
FOR i=0, nhgtcats-1 DO BEGIN
   hgtstr =  string(heights[i], FORMAT='(f0.1)')
   idxhgt = where(hgtcat EQ i, counthgts)
   num_in_hgt_cat[i] = counthgts
ENDFOR

; build an array of sample volume depth for weighting of the layer averages and
; mean differences
voldepth = (top-botm) > 0.0

; define a structure to hold difference statistics computed within and returned
; by the called function calc_geo_pr_gv_meandiffs_wght_idx()
the_struc = { diffsset, $
              meandiff: -99.999, meandist: -99.999, fullcount: 0L,  $
              maxpr: -99.999, maxgv: -99.999, $
              meandiffc: -99.999, countc: 0L, $
              meandiffs: -99.999, counts: 0L, $
              AvgDifByHist: -99.999 $
            }

print, ''
textout = 'TMI-GR Rain Rate difference statistics (mm/h) - GV Site: '+siteID $
          +'   Orbit: '+orbit+'   V'+version
print, textout & IF (do_ps EQ 1) THEN printf, tempunit, textout
textout ='TMI time = '+mygeometa.atimeNearestApproach+'   GV start time = '+mysweeps[0].atimeSweepStart
print, textout & IF (do_ps EQ 1) THEN printf, tempunit, textout
textout = 'Required percent of above-threshold GV bins in matched volumes >= '+pctString+"%"
print, textout & IF (do_ps EQ 1) THEN printf, tempunit, textout
IF have_RR THEN BEGIN
   textout = siteID + ' rain rate from dual-pol RR field'
ENDIF ELSE BEGIN
   textout = siteID + ' rain rate from Z-R relationship'
ENDELSE
print, textout & IF (do_ps EQ 1) THEN printf, tempunit, textout
print, '' & IF (do_ps EQ 1) THEN printf, tempunit, ''
;print, '' & IF (do_ps EQ 1) THEN printf, tempunit, ''
textout = 'Statistics grouped by fixed height levels (km):'
print, textout & IF (do_ps EQ 1) THEN printf, tempunit, textout
print, '' & IF (do_ps EQ 1) THEN printf, tempunit, ''
textout =  ' Vert. |   Any Rain Type  |    Stratiform    |    Convective     |     Dataset Statistics      |'
print, textout & IF (do_ps EQ 1) THEN printf, tempunit, textout
textout = ' Layer | TMI-GR    NumPts | TMI-GR    NumPts | TMI-GR    NumPts  | AvgDist  TMIMaxRR  GR MaxRR |'
print, textout & IF (do_ps EQ 1) THEN printf, tempunit, textout
textout = ' ----- | -------   ------ | -------   ------ | -------   ------  | -------  --------  -------- |'
print, textout & IF (do_ps EQ 1) THEN printf, tempunit, textout

mnprarr = fltarr(3,nhgtcats)  ; each level, for raintype all, stratiform, convective
mngvarr = fltarr(3,nhgtcats)  ; each level, for raintype all, stratiform, convective
levhasdata = intarr(nhgtcats) & levhasdata[*] = 0
levsdata = 0
max_hgt_w_data = 0.0

; - - - - - - - - - - - - - - - - - - - - - - - -

; Compute a mean rainrate difference at each level

for lev2get = 0, nhgtcats-1 do begin
   havematch = 0
   thishgt = (lev2get+1)*hgtinterval
   IF thishgt GT 6.0 THEN BREAK
   IF ( num_in_hgt_cat[lev2get] GT 0 ) THEN BEGIN
      flag = ''
      idx4hist = lonarr(num_in_hgt_cat[lev2get])  ; array indices used for point-to-point mean diffs
      idx4hist[*] = -1L
      if (lev2get eq BBparms.BB_HgtLo OR lev2get eq BBparms.BB_HgtHi) then flag = ' @ BB'
      diffstruc = the_struc
      calc_geo_pr_gv_meandiffs_wght_idx, sfcRain, gvrr, rnType, dist, distcat, hgtcat, $
                             lev2get, RRcut, rangecut, mnprarr, mngvarr, $
                             havematch, diffstruc, idx4hist, voldepth
      if(havematch eq 1) then begin
         levsdata = levsdata + 1
         levhasdata[lev2get] = 1
         max_hgt_w_data = thishgt
        ; format level's stats for table output
         stats55 = STRING(diffstruc.meandiff, diffstruc.fullcount, $
                       diffstruc.meandiffs, diffstruc.counts, $
                       diffstruc.meandiffc, diffstruc.countc, $
                       diffstruc.meandist, diffstruc.maxpr, diffstruc.maxgv, $
                       FORMAT='(3("    ",f7.3,"    ",i4),"  ",3("   ",f7.3))' )
        ; extract/format level's stats for graphic plots output
         rr_pr2 = sfcRain[idx4hist[0:diffstruc.fullcount-1]]
         rr_gv2 = gvrr[idx4hist[0:diffstruc.fullcount-1]]
         mndifhstr = string(diffstruc.AvgDifByHist, FORMAT='(f0.3)')
         mndifstr = string(diffstruc.meandiff, diffstruc.fullcount, FORMAT='(f0.3," (",i0,")")')
         mndifstrc = string(diffstruc.meandiffc, diffstruc.countc, FORMAT='(f0.3," (",i0,")")')
         mndifstrs = string(diffstruc.meandiffs, diffstruc.counts, FORMAT='(f0.3," (",i0,")")')
         idx4hist[*] = -1L
         textout = STRING(heights[lev2get], stats55, flag, FORMAT='(" ",f4.1,a0," ",a0)')
         print, textout & IF (do_ps EQ 1) THEN printf, tempunit, textout
      endif else begin
         textout = "No above-threshold points at height " + STRING(heights[lev2get], FORMAT='(f0.3)')
         print, textout & IF (do_ps EQ 1) THEN printf, tempunit, textout
      endelse
   ENDIF ELSE BEGIN
      print, "No points at height " + string(heights[lev2get], FORMAT='(f0.3)')
   ENDELSE

endfor         ; lev2get = 0, nhgtcats-1

if (levsdata eq 0) then begin
   print, "No valid data levels found for reflectivity!"
   nframes = 0
   goto, nextFile
endif

; - - - - - - - - - - - - - - - - - - - - - - - -

; Build the mean Z profile plot panel

orig_device = !D.NAME

IF ( do_ps EQ 1 ) THEN BEGIN
  ; set up postscript plot params. and file path/name
   cd, ps_dir
   b_w = keyword_set(b_w)
   ;IF ( s2ku ) THEN add2nm = '_S2Ku' ELSE add2nm = ''
   IF KEYWORD_SET( use_vpr ) THEN add2nm = '_by_VPR' ELSE add2nm = ''

;FIX THIS BNAME SUBSTRING EXTRACTION HERE AND BELOW, CAN'T RELY ON POSITION/LENGTH!!

   PSFILEpdf = ps_dir+'/'+strmid( bname, 8, 17)+".V"+version+'.Pct'+pctString+add2nm+'_PDF_SCATR.ps'
   print, "Output sent to ", PSFILEpdf
   set_plot,/copy,'ps'
   device,filename=PSFILEpdf,/color,bits=8,/inches,xoffset=0.25,yoffset=2.55, $
          xsize=8.,ysize=8.

   ; Set up color table
   ;
   common colors, r_orig, g_orig, b_orig, r_curr, g_curr, b_curr ;load color table
   IF ( b_w EQ 0) THEN  LOADCT, 6, /SILENT  ELSE  LOADCT, 33, /SILENT
   ncolor=255
   red=bytarr(256) & green=bytarr(256) & blue=bytarr(256)
   red=r_curr & green=g_curr & blue=b_curr
   red(0)=255 & green(0)=255 & blue(0)=255
   red(1)=115 & green(1)=115 & blue(1)=115  ; gray for GV
   red(ncolor)=0 & green(ncolor)=0 & blue(ncolor)=0 
   tvlct,red,green,blue
   !P.COLOR=0 ; make the title and axis annotation black
   !X.THICK=2 ; make the ticks and borders thicker
   !Y.THICK=2 ; ditto
   !P.FONT=0 ; use the device fonts supplied by postscript

   IF ( b_w EQ 0) THEN BEGIN
     PR_COLR=200
     GV_COLR=60
     ST_LINE=1    ; dotted for stratiform
     CO_LINE=2    ; dashed for convective
   ENDIF ELSE BEGIN
     PR_COLR=ncolor
     GV_COLR=ncolor
     ST_LINE=0    ; solid for stratiform
     CO_LINE=1    ; dotted for convective
   ENDELSE

   CHARadj=0.75
   THIKadjPR=1.5
   THIKadjGV=0.5
   ST_THK=1
   CO_THK=1
ENDIF ELSE BEGIN
  ; set up x-window plot params.
   device, decomposed = 0
   LOADCT, 2, /SILENT
   Window, xsize=700, ysize=700, TITLE = strmid( bname, 8, 17)+".V"+version+"  --  " $
        +"With % of averaged bins above dBZ thresholds "+'>= '+pctString+"%", $
        RETAIN=2
   PR_COLR=30
   GV_COLR=70
   ST_LINE=1    ; dotted for stratiform
   CO_LINE=2    ; dashed for convective
   CHARadj=1.0
   THIKadjPR=1.0
   THIKadjGV=1.0
   ST_THK=3
   CO_THK=2
ENDELSE


!P.Multi=[0,2,2,0,0]

idxlev2plot = WHERE( levhasdata EQ 1 )
h2plot = heights[idxlev2plot]

; figure out the y-axis range.  Use the greater of max_hgt_w_data*2.0
; and meanbb*2 as the proposed range.  Cut off at 20 km if result>20.
prop_max_y = max_hgt_w_data*2.0 > (FIX((BBparms.meanbb*2)/1.5) + 1) *1.5
plot, [0.1,150], [0,20 < prop_max_y], /NODATA, COLOR=255, $
      XSTYLE=1, YSTYLE=1, YTICKINTERVAL=hgtinterval, YMINOR=1, thick=1, $
      XTITLE='Level Mean Rain Rate, mm/h', YTITLE='Height Level, km', $
      CHARSIZE=1*CHARadj, BACKGROUND=0, /xlog

IF (~ hideTotals) THEN BEGIN
  ; plot the profile for all points regardless of rain type
   prmnz2plot = mnprarr[0,*]
   prmnz2plot = prmnz2plot[idxlev2plot]
   gvmnz2plot = mngvarr[0,*]
   gvmnz2plot = gvmnz2plot[idxlev2plot]
   oplot, prmnz2plot, h2plot, COLOR=PR_COLR, thick=1*THIKadjPR
   oplot, gvmnz2plot, h2plot, COLOR=GV_COLR, thick=1*THIKadjGV
ENDIF

; plot the profile for stratiform rain type points
prmnz2plot = mnprarr[1,*]
prmnz2plot = prmnz2plot[idxlev2plot]
gvmnz2plot = mngvarr[1,*]
gvmnz2plot = gvmnz2plot[idxlev2plot]
idxhavezs = WHERE( prmnz2plot GT 0.0 and gvmnz2plot GT 0.0, counthavezs )
IF ( counthavezs GT 0 ) THEN BEGIN
   oplot, prmnz2plot[idxhavezs], h2plot[idxhavezs], COLOR=PR_COLR, LINESTYLE=ST_LINE, thick=3*THIKadjPR
   oplot, gvmnz2plot[idxhavezs], h2plot[idxhavezs], COLOR=GV_COLR, LINESTYLE=ST_LINE, thick=3*THIKadjGV
ENDIF

; plot the profile for convective rain type points
prmnz2plot = mnprarr[2,*]
prmnz2plot = prmnz2plot[idxlev2plot]
gvmnz2plot = mngvarr[2,*]
gvmnz2plot = gvmnz2plot[idxlev2plot]
idxhavezs = WHERE( prmnz2plot GT 0.0 and gvmnz2plot GT 0.0, counthavezs )
IF ( counthavezs GT 0 ) THEN BEGIN
   oplot, prmnz2plot[idxhavezs], h2plot[idxhavezs], COLOR=PR_COLR, LINESTYLE=CO_LINE, thick=3*THIKadjPR
   oplot, gvmnz2plot[idxhavezs], h2plot[idxhavezs], COLOR=GV_COLR, LINESTYLE=CO_LINE, thick=3*THIKadjGV
ENDIF

xvals = [0.1,150]
xvalsleg1 = [37,39] & yvalsleg1 = 18

yvalsbb = [meanBBgr, meanBBgr]
plots, xvals, yvalsbb, COLOR=255, LINESTYLE=2;, THICK=3*THIKadjGV
yvalsleg2 = 14
plots, [0.29,0.33], [0.805,0.805], COLOR=255, /NORMAL, LINESTYLE=2
XYOutS, 0.34, 0.8, 'Mean BB Hgt', COLOR=255, CHARSIZE=1*CHARadj, /NORMAL

; - - - - - - - - - - - - - - - - - - - - - - - -

; Compute a mean rainrate difference over each surface type and plot PDFs

mnprarrbb = fltarr(3,4)  ; each BB-relative level, for raintype all, stratiform, convective
mngvarrbb = fltarr(3,4)  ; each BB-relative level, for raintype all, stratiform, convective
levhasdatabb = intarr(4) & levhasdatabb[*] = 0
levsdatabb = 0
SfcType_str = [' N/A ', 'Ocean', ' Land', 'Coast']
xoff = [0.0, 0.0, -0.5, 0.0 ]  ; for positioning legend in PDFs
yoff = [0.0, 0.0, -0.5, -0.5 ]

; use the CAPPI elements at the selected CAPPI level in the PDF and scatter
; plots.  Extract this level's data from the percent-filtered arrays already
; computed

idxmycappi = WHERE( CAPPIlev EQ CAPPI_height, countatcappi )
IF ( countatcappi GT 0 ) THEN BEGIN
   sfcRain = sfcRainCAP[idxmycappi]
   gvrr = gvrrCAP[idxmycappi]
   rnType = rnTypeCAP[idxmycappi]
   dist = distCAP[idxmycappi]
   distcat = distcatCAP[idxmycappi]
   voldepth = voldepthCAP[idxmycappi]
   ; reassign surface type values (10,20,30) to (1,2,3).
   sfcCat = sfcTypCAP[idxmycappi]
   ; get info from array of surface type
;   num_over_SfcType = LONARR(4)
   idxmix = WHERE( sfcCat EQ 3, countmix )  ; Coast
   num_over_SfcType[3] = countmix
   idxsea = WHERE( sfcCat EQ 1, countsea )  ; Ocean
   num_over_SfcType[1] = countsea
   idxland = WHERE( sfcCat EQ 2, countland )    ; Land
   num_over_SfcType[2] = countland
   idxrrabvthresh = WHERE( sfcRain GE RRcut AND gvrr GE RRcut, num_rr_abv_thresh )
ENDIF ELSE BEGIN
;   num_over_SfcType = LONARR(4)
   num_over_SfcType[*] = 0
   num_rr_abv_thresh = 0
ENDELSE

; nobody gets preferential treatment, weight-wise
voldepth[*] = 1.0

;help, sfcRain, gvrr, rnType, dist, distcat, sfcCat, voldepth, num_over_SfcType
print, '' & IF (do_ps EQ 1) THEN printf, tempunit, ''
print, '' & IF (do_ps EQ 1) THEN printf, tempunit, ''
print, CAPPI_height, num_rr_abv_thresh, countatcappi, $
       FORMAT='("Number of rainy points on ", F0.1, " km CAPPI level: ", I0, " of ", I0, " total")'

; some fixed legend stuff for PDF plots
headline = 'TMI-'+siteID+' Biases'
CAPPI_label = 'on '+STRING(CAPPI_height, FORMAT='(F0.1)')+' km CAPPI'

print, '' & IF (do_ps EQ 1) THEN printf, tempunit, ''
textout = 'Statistics grouped by underlying surface type, on '+STRING(CAPPI_height, FORMAT='(F0.1)')+" km CAPPI surface:"
print, textout & IF (do_ps EQ 1) THEN printf, tempunit, textout
print, '' & IF (do_ps EQ 1) THEN printf, tempunit, ''
textout = 'Surface|   Any Rain Type  |    Stratiform    |    Convective     |     Dataset Statistics      |'
print, textout & IF (do_ps EQ 1) THEN printf, tempunit, textout
textout = ' type  | TMI-GR    NumPts | TMI-GR    NumPts | TMI-GR    NumPts  | AvgDist  TMIMaxRR  GR MaxRR |'
print, textout & IF (do_ps EQ 1) THEN printf, tempunit, textout
textout = ' ----- | -------   ------ | -------   ------ | -------   ------  | -------  --------  -------- |'
print, textout & IF (do_ps EQ 1) THEN printf, tempunit, textout

; define a 2D array to capture array indices of values used for point-to-point
; mean diffs, for each of the 3 sfcCat levels, for plotting these points in the
; scatter plots
numZpts = N_ELEMENTS(sfcRain)
idx4hist3 = lonarr(3,numZpts)
idx4hist3[*,*] = -1L
num4hist3 = lonarr(3)  ; track number of points used in each sfcCat layer
idx4hist = idx4hist3[0,*]  ; a 1-D array for passing to function in the layer loop
for SfcType_2get = 1, 3 do begin
   havematch = 0
   !P.Multi=[4-SfcType_2get,2,2,0,0]
   IF ( num_over_SfcType[SfcType_2get] GT 0 ) THEN BEGIN
      flag = ''
      if (SfcType_2get eq 2) then flag = ' @ BB'
      diffstruc = the_struc
      calc_geo_pr_gv_meandiffs_wght_idx, sfcRain, gvrr, rnType, dist, distcat, sfcCat, $
                             SfcType_2get, RRcut, rangecut, mnprarrbb, mngvarrbb, $
                             havematch, diffstruc, idx4hist, voldepth
      if(havematch eq 1) then begin
         levsdatabb = levsdatabb + 1
         levhasdatabb[SfcType_2get] = 1
        ; format level's stats for table output
         stats55 = STRING(diffstruc.meandiff, diffstruc.fullcount, $
                       diffstruc.meandiffs, diffstruc.counts, $
                       diffstruc.meandiffc, diffstruc.countc, $
                       diffstruc.meandist, diffstruc.maxpr, diffstruc.maxgv, $
                       FORMAT='("  ",f7.3,"    ",i4,2("    ",f7.3,"    ",i4),"  ",3("   ",f7.3))' )
        ; capture points used, and format level's stats for graphic plots output
         num4hist3[SfcType_2get-1] = diffstruc.fullcount
         idx4hist3[SfcType_2get-1,*] = idx4hist
         rr_pr2 = sfcRain[idx4hist[0:diffstruc.fullcount-1]]
         rr_gv2 = gvrr[idx4hist[0:diffstruc.fullcount-1]]
         type2 = rnType[idx4hist[0:diffstruc.fullcount-1]]
         sfcCat2 = sfcCat[idx4hist[0:diffstruc.fullcount-1]]
         mndifhstr = string(diffstruc.AvgDifByHist, FORMAT='(f0.3)')
         mndifstr = string(diffstruc.meandiff, diffstruc.fullcount, FORMAT='(f0.3," (",i0,")")')
         IF diffstruc.countc EQ 0 THEN mndifstrc = 'None' $
         ELSE mndifstrc = string(diffstruc.meandiffc, diffstruc.countc, FORMAT='(f0.3," (",i0,")")')
         IF diffstruc.counts EQ 0 THEN mndifstrs = 'None' $
         ELSE mndifstrs = string(diffstruc.meandiffs, diffstruc.counts, FORMAT='(f0.3," (",i0,")")')
         idx4hist[*] = -1
         textout = " " + SfcType_str[SfcType_2get] + " " + stats55
         print, textout & IF (do_ps EQ 1) THEN printf, tempunit, textout

        ; Plot the PDF graph for this level
         hgtline = 'Layer = ' + SfcType_str[SfcType_2get]

        ; DO ANY/ALL RAINTYPE PDFS FIRST
        ; define a set of 18 log-spaced range boundaries - yields 19 rainrate categories
         logbins = 10^(findgen(18)/5.-1)
        ; figure out where each point falls in the log ranges: from -1 (below lowest bound)
        ; to 18 (above highest bound)
         bin4pr = VALUE_LOCATE( logbins, rr_pr2 )
         bin4gr = VALUE_LOCATE( logbins, rr_gv2 )  ; ditto for GR rainrate
        ; compute histogram of log range category, ignoring the lowest (below 0.1 mm/h)
         prhist = histogram( bin4pr, min=0, max=18,locations = prhiststart )
         nxhist = histogram( bin4gr, min=0, max=18,locations = prhiststart )
         labelbins=[STRING(10^(findgen(5)*4./5.-1),FORMAT='(F6.2)'),'>250.0']
         plot, [0,MAX(prhiststart)],[0,FIX((MAX(prhist)>MAX(nxhist))*1.1)], $
                  /NODATA, COLOR=255, CHARSIZE=1*CHARadj, $
                  XTITLE=SfcType_str[SfcType_2get]+' Rain Rate, mm/h', $
                  YTITLE='Number of TMI Footprints', $
                  YRANGE=[ 0, FIX((MAX(prhist)>MAX(nxhist))*1.1) + 1 ], $
                  BACKGROUND=0, xtickname=labelbins,xtickinterval=4,xminor=4

         IF ( ~ hideTotals ) THEN BEGIN
            oplot, prhiststart, prhist, COLOR=PR_COLR
            oplot, prhiststart, nxhist, COLOR=GV_COLR
            xyouts, 0.34, 0.95, 'TMI (all)', COLOR=PR_COLR, /NORMAL, $
                    CHARSIZE=1*CHARadj
            plots, [0.29,0.33], [0.955,0.955], COLOR=PR_COLR, /NORMAL
            xyouts, 0.34, 0.925, siteID+' (all)', COLOR=GV_COLR, /NORMAL, $
                    CHARSIZE=1*CHARadj
            plots, [0.29,0.33], [0.93,0.93], COLOR=GV_COLR, /NORMAL
         ENDIF

         xyouts, 0.775+xoff[SfcType_2get],0.93+yoff[SfcType_2get], headline, $
                 COLOR=255, /NORMAL, CHARSIZE=1*CHARadj
         xyouts, 0.775+xoff[SfcType_2get],0.91+yoff[SfcType_2get], CAPPI_label+':', $
                 COLOR=255, /NORMAL, CHARSIZE=1*CHARadj

         mndifline = 'Any/All: ' + mndifstr
         mndiflinec = 'Convective: ' + mndifstrc
         mndiflines = 'Stratiform: ' + mndifstrs
         mndifhline = 'By Area Mean: ' + mndifhstr
         xyouts, 0.775+xoff[SfcType_2get],0.875+yoff[SfcType_2get], mndifline, $
                 COLOR=255, /NORMAL, CHARSIZE=1*CHARadj
         xyouts, 0.775+xoff[SfcType_2get],0.85+yoff[SfcType_2get], mndiflinec, $
                 COLOR=255, /NORMAL, CHARSIZE=1*CHARadj
         xyouts, 0.775+xoff[SfcType_2get],0.825+yoff[SfcType_2get], mndiflines, $
                 COLOR=255, /NORMAL, CHARSIZE=1*CHARadj

        ; OVERLAY CONVECTIVE RAINTYPE PDFS, IF ANY POINTS
         idxconvhist= WHERE( type2 EQ RainType_convective, nconv )
         IF ( nconv GT 0 ) THEN BEGIN
           bin4pr = VALUE_LOCATE( logbins, rr_pr2[idxconvhist] )  ; see Any/All logic above
           bin4gr = VALUE_LOCATE( logbins, rr_gv2[idxconvhist] )
           prhist = histogram( bin4pr, min=0, max=18,locations = prhiststart )
           nxhist = histogram( bin4gr, min=0, max=18,locations = prhiststart )
           oplot, prhiststart, prhist, COLOR=PR_COLR, LINESTYLE=CO_LINE, thick=3*THIKadjPR
           oplot, prhiststart, nxhist, COLOR=GV_COLR, LINESTYLE=CO_LINE, thick=3*THIKadjGV
           xyouts, 0.34, 0.85, 'TMI (Conv)', COLOR=PR_COLR, /NORMAL, CHARSIZE=1*CHARadj
           xyouts, 0.34, 0.825, siteID+' (Conv)', COLOR=GV_COLR, /NORMAL, CHARSIZE=1*CHARadj
           plots, [0.29,0.33], [0.855,0.855], COLOR=PR_COLR, /NORMAL, LINESTYLE=CO_LINE, thick=3*THIKadjPR
           plots, [0.29,0.33], [0.83,0.83], COLOR=GV_COLR, /NORMAL, LINESTYLE=CO_LINE, thick=3*THIKadjGV
         ENDIF

        ; OVERLAY STRATIFORM RAINTYPE PDFS, IF ANY POINTS
         idxstrathist= WHERE( type2 EQ RainType_stratiform, nstrat )
         IF ( nstrat GT 0 ) THEN BEGIN
           bin4pr = VALUE_LOCATE( logbins, rr_pr2[idxstrathist] )  ; see Any/All logic above
           bin4gr = VALUE_LOCATE( logbins, rr_gv2[idxstrathist] )
           prhist = histogram( bin4pr, min=0, max=18,locations = prhiststart )
           nxhist = histogram( bin4gr, min=0, max=18,locations = prhiststart )
           oplot, prhiststart, prhist, COLOR=PR_COLR, LINESTYLE=ST_LINE, thick=3*THIKadjPR
           oplot, prhiststart, nxhist, COLOR=GV_COLR, LINESTYLE=ST_LINE, thick=3*THIKadjGV
           xyouts, 0.34, 0.9, 'TMI (Strat)', COLOR=PR_COLR, /NORMAL, CHARSIZE=1*CHARadj
           xyouts, 0.34, 0.875, siteID+' (Strat)', COLOR=GV_COLR, /NORMAL, CHARSIZE=1*CHARadj
           plots, [0.29,0.33], [0.905,0.905], COLOR=PR_COLR, /NORMAL, LINESTYLE=ST_LINE, thick=3*THIKadjPR
           plots, [0.29,0.33], [0.88,0.88], COLOR=GV_COLR, /NORMAL, LINESTYLE=ST_LINE, thick=3*THIKadjGV
         ENDIF
 
      endif else begin
         print, "No above-threshold points for ", SfcType_str[SfcType_2get]
      endelse
   ENDIF ELSE BEGIN
      print, "No points over ", SfcType_str[SfcType_2get]
      xyouts, 0.6+xoff[SfcType_2get],0.75+yoff[SfcType_2get], SfcType_str[SfcType_2get] + $
              ": NO POINTS", COLOR=255, /NORMAL, CHARSIZE=1.5
   ENDELSE

endfor         ; SfcType_2get = 1,3

IF ( do_ps EQ 1 ) THEN BEGIN
   erase                 ; start a new page in the PS file
;   device, /landscape   ; change page setup
   FREE_LUN, tempunit    ; close the temp file for writing
   OPENR, tempunit2, temptext, /GET_LUN  ; open the temp file for reading
   statstr = ''
   fmt='(a0)'
   xtext = 0.05 & ytext = 0.95
  ; write the stats tables out to the Postscript file
   while (eof(tempunit2) ne 1) DO BEGIN
     readf, tempunit2, statstr, format=fmt
     xyouts, xtext, ytext, '!11'+statstr+'!X', /NORMAL, COLOR=255, CHARSIZE=0.667
     ytext = ytext - 0.02
   endwhile
   FREE_LUN, tempunit2             ; close the temp file
ENDIF
; - - - - - - - - - - - - - - - - - - - - - - - -

; Build the Scatter Plots
SCATITLE = strmid( bname, 8, 17)+".V"+version+STRING(CAPPI_height, FORMAT='(" on ",F0.1)') $
           +" km CAPPI,  % bins above threshold " +'>= '+pctString
IF have_RR THEN x_title = siteID+' RR' ELSE x_title = siteID+' ZR'

IF ( do_ps EQ 1 ) THEN BEGIN
   erase
   device,/inches,xoffset=0.25,yoffset=0.55,xsize=8.,ysize=10.,/portrait
   plot_scatter_by_sfc_type3x3_ps, PSFILEpdf, SCATITLE, siteID, sfcRain, gvrr, $
                            rnType, sfcCat, num4hist3, idx4hist3, $
                            MIN_XY=0.5, MAX_XY=150.0, UNITS='mm/h', X_TITLE=x_title
ENDIF ELSE BEGIN
   plot_scatter_by_sfc_type3x3, SCATITLE, siteID, sfcRain, gvrr, rnType, sfcCat, $
                            num4hist3, idx4hist3, windowsize, $
                            MIN_XY=0.5, MAX_XY=150.0, UNITS='mm/h', X_TITLE=x_title
ENDELSE

SET_PLOT, orig_device

; - - - - - - - - - - - - - - - - - - - - - - - -

; Build the PctAbvThresh histogram plot
; ELIMINATE THE POINTS WITH ZERO REFLECTIVITY (CLEAR AIR) SO THAT
; ONLY POINTS WITH SOME RETURNS ARE TALLIED IN THE ZERO PERCENT BIN. 
; -- GVZ VALUES ARE >0.0 ONLY IF ONE OR MORE BINS ARE > DBZ_MIN, OTHERWISE
;    THEY ARE SET TO Z_BELOW_THRESH

havewin4 = 0
IF N_ELEMENTS( plot_pct_cat ) EQ 1 THEN BEGIN
   idxgvnotzero = WHERE( gvz_in[idxexpgt0] GT 0.0, countnonzero )
   IF countnonzero GT 0 THEN BEGIN
      pctgood = pctgoodgv[idxexpgt0[idxgvnotzero]]
      PRINT, "number of points for pctAbvThresh histograms: ", N_ELEMENTS(pctgood)
      idxzeropct = WHERE( pctgood EQ 0.0, countpctzero )
      PRINT, "number of points with 0.0 pctAbvThresh: ", countpctzero
      havewin4 = 1
      CASE plot_pct_cat OF
         'RainType' : BEGIN
                 typ4pct = rntype4pctabv[idxexpgt0[idxgvnotzero]]
                 plot_pct_abv_thresh_pdfs, pctgood, typ4pct, plot_pct_cat
               END
         'SurfaceType' : BEGIN
                 typ4pct = sfctype4pctabv[idxexpgt0[idxgvnotzero]]
                 plot_pct_abv_thresh_pdfs, pctgood, typ4pct, plot_pct_cat
               END
          ELSE : BEGIN
                 print, "Unrecognized field name for plot_pct_cat: ", $
                 "must be 'SurfaceType' or 'RainType'.  Skipping plot."
                 havewin4 = 0
               END
      ENDCASE
   ENDIF ELSE print, "No non-zero GR reflectivity samples, skipping pctAbvThresh histograms."
ENDIF

; - - - - - - - - - - - - - - - - - - - - - - - -

; Build the PPI animation loop.

; Check that we have as many sweeps as (startelev+elevs2show); if not, adjust
; elevs2show

IF (startelev LE mygeometa.num_sweeps ) THEN BEGIN
   IF (elevs2show+startelev) LE mygeometa.num_sweeps THEN BEGIN
        nframes = elevs2show
   ENDIF ELSE BEGIN
        nframes = mygeometa.num_sweeps - (startelev + 1)
        print, "Number of sweeps present = ", mygeometa.num_sweeps
        print, "First, Last sweep requested = ", startelev+1, ',', startelev+elevs2show
        print, "Number of sweeps to show (adjusted): ", nframes
   ENDELSE
ENDIF ELSE BEGIN
     elevs2show = 1
     nframes = 1
     startelev = mygeometa.num_sweeps - 1
     print, "Number of sweeps present = ", mygeometa.num_sweeps
     print, "First, Last sweep requested = ", startelev+1, ',', startelev+elevs2show
     print, "Showing only sweep number: ", startelev+1
ENDELSE

IF ( elevs2show EQ 0 ) THEN GOTO, nextFile
do_pixmap=0
IF ( elevs2show GT 1 ) THEN BEGIN
   do_pixmap=1
   retain = 0
ENDIF ELSE retain = 2

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
window, 2, xsize=xsize*nx, ysize=ysize*ny, xpos = 75, TITLE = title, $
        PIXMAP=do_pixmap, RETAIN=retain

; instantiate animation widget, if multiple PPIs
IF nframes GT 1 THEN xinteranimate, set=[xsize*nx, ysize*ny, nframes], /TRACK

error = 0
loadcolortable, 'CZ', error
if error then begin
    print, ''
    print, "In geo_match_z_plots: error from loadcolortable"
    something = ""
    READ, something, PROMPT='Hit Return to proceed to next case, Q to Quit: '
    goto, errorExit2
endif

FOR ifram=0,nframes-1 DO BEGIN
    elevstr =  string(mysweeps[ifram+startelev].elevationAngle, FORMAT='(f0.1)')
    prtitle = "TMI V"+version+" for "+elevstr+" degree sweep, "+mygeometa.atimeNearestApproach
    myprbuf = plot_sweep_2_zbuf( rain3_in, mysite.site_lat, mysite.site_lon, xCorner, $
                             yCorner, tmi_index, mygeometa.num_footprints, $
                             ifram+startelev, rntype4ppi, $
                             WINSIZ=windowsize, TITLE=prtitle, FIELD='RR' )
    gvtitle = mysite.site_ID+" Ze at "+elevstr+" degrees, "+mysweeps[ifram].atimeSweepStart
    mygvbuf = plot_sweep_2_zbuf( gvz_in, mysite.site_lat, mysite.site_lon, xCorner, $
                             yCorner, tmi_index, mygeometa.num_footprints, $
                             ifram+startelev, rntype4ppi, $
                             WINSIZ=windowsize, TITLE=gvtitle ) ;, FIELD='RR' )
    IF ( PPIbyThresh ) THEN BEGIN
       prtitle = "TMI V"+version+", for "+'!m'+STRING("142B)+pctString+"% of GR bins above threshold"
       myprbuf2 = plot_sweep_2_zbuf( rain3_in2, mysite.site_lat, mysite.site_lon, xCorner, $
                                 yCorner, tmi_index, mygeometa.num_footprints, $
                                 ifram+startelev, rntype4ppi, $
                                 WINSIZ=windowsize, TITLE=prtitle, FIELD='RR' )

       IF have_RR THEN gvsrc = ' RR' ELSE gvsrc = ' Z-R'
       gvtitle = mysite.site_ID + gvsrc + " rainrate, for " $
             +'!m'+STRING("142B) + pctString + "% of bins above threshold"
       mygvbuf2 = plot_sweep_2_zbuf( gvz_in2, mysite.site_lat, mysite.site_lon, xCorner, $
                                 yCorner, tmi_index, mygeometa.num_footprints, $
                                 ifram+startelev, rntype4ppi, $
                                 WINSIZ=windowsize, TITLE=gvtitle, FIELD='RR' )
    ENDIF

    SET_PLOT, 'X'
    device, decomposed=0
    TV, myprbuf, 0
    TV, mygvbuf, 1
    IF ( PPIbyThresh ) THEN BEGIN
       TV, myprbuf2, 2
       TV, mygvbuf2, 3
    ENDIF

    IF ( do_ps EQ 1 ) THEN BEGIN  ; plot the PPIs to the postscript file
       set_plot,/copy,'ps'
       erase
       TV, myprbuf, 0, /inches, xsize=4, ysize=4
       TV, mygvbuf, 1, /inches, xsize=4, ysize=4
       IF ( PPIbyThresh ) THEN BEGIN
          TV, myprbuf2, 2, /inches, xsize=4, ysize=4
          TV, mygvbuf2, 3, /inches, xsize=4, ysize=4
       ENDIF
       SET_PLOT, orig_device
    ENDIF

    IF nframes GT 1 THEN xinteranimate, frame = ifram, window=2

ENDFOR

IF nframes GT 1 THEN BEGIN
   print, ''
   print, 'Click END ANIMATION button or close Animation window to proceed to next case:
   xinteranimate, looprate, /BLOCK
ENDIF

IF ( do_ps EQ 1 ) THEN BEGIN  ; wrap up the postscript file
   set_plot,/copy,'ps'
   device,/close
   SET_PLOT, orig_device
  ; try to convert it from PS to PDF, using ps2pdf utility
   if !version.OS_NAME eq 'Mac OS X' then ps_util_name = 'pstopdf' $
   else ps_util_name = 'ps2pdf'
   command1 = 'which '+ps_util_name
   spawn, command1, result, errout
   IF result NE '' THEN BEGIN
      print, 'Converting ', PSFILEpdf, ' to PDF format.'
      command2 = ps_util_name+ ' ' + PSFILEpdf
      spawn, command2, result, errout
      print, 'Removing Postscript version'
      command3 = 'rm -v '+PSFILEpdf
      spawn, command3, result, errout
   ENDIF
ENDIF

; - - - - - - - - - - - - - - - - - - - - - - -

nextFile:

something = ""
IF nframes LT 2 THEN BEGIN
   print, ''
   READ, something, PROMPT='Hit Return to proceed to next case, Q to Quit: '
ENDIF
IF ( elevs2show GT 0 AND nframes GT 0 ) THEN WDELETE, 2

errorExit2:

if ( levsdata NE 0 AND do_ps EQ 0 ) THEN BEGIN
   WDELETE, 0
   WDELETE, 3
   IF havewin4 EQ 1 THEN WDELETE, 4
endif

status = 0
IF something EQ 'Q' OR something EQ 'q' THEN status = 1

errorExit:

return, status
end

;===============================================================================
;
; MODULE 2:  tmi2gr_rainrate_comparisons
;
; DESCRIPTION
; -----------
; Driver for the geo_match_rr_plots function (included).  Sets up user/default
; parameters defining the plots and animations, and the method by which the next
; case is selected: either prompt the user to select the file, or just take the
; next one in the sequence.
;
; PARAMETERS
; ----------
; looprate     - initial animation rate for the PPI animation loop on startup.
;                Defaults to 3 if unspecified or outside of allowed 0-100 range
;
; elevs2show   - number of PPIs to display in the PPI image animation, starting
;                at a specifed elevation angle in the volume, in the form 'N.s',
;                where N is the number of PPIs to show, and s is the starting
;                sweep (1-based, where 1 = first). Disables PPI plot if N <= 0,
;                static plot if N = 1. Defaults to N=7.1 if unspecified.  If s
;                is zero or if only N is specified, then s = 1.
;
; ncpath       - local directory path to the geo_match netCDF files' location.
;                Defaults to /data/netcdf/geo_match
;
; sitefilter   - file pattern which acts as the filter limiting the set of input
;                files showing up in the file selector or over which the program
;                will iterate, depending on the select mode parameter.
;                Default=GR2TMI.*
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
; pctAbvThresh - constraint on the percent of bins in the geometric-matching GV
;                volume that were above the preselected threshold, specified
;                at the time the geo-match dataset was created.  Essentially a
;                measure of "beam-filling goodness".  100 means use only those
;                matchup points where all the GV bins in the volume
;                averages were above threshold (complete volume filled with
;                above threshold bin values).  0 means use all matchup points
;                available, with no regard for thresholds (the default, if no
;                pctAbvThresh value is specified).  If no sample locations meet
;                the criterion, all statistical and graphical output is skipped
;                for the case
;
; pop_threshold - constraint on the percent Probability of Precipitation for V7
;                 data that defines a rain certain sample over ocean surfaces.
;                 Data below this threshold are excluded from consideration.
;                 Default = 50.0 (percent)
;
; show_thresh_ppi - Binary parameter, controls whether to create and display a
;                   2nd set of PPIs plotting only those TMI and GR points meeting
;                   the pctAbvThresh constraint.  If set to On, then ppi_vertical
;                   defaults to horizontal (TMI on left, GR on right)
;
; hide_totals   - Binary parameter, controls whether to show (default) or hide
;                 the PDF and profile plots for rain type = "Any".
;
; ps_dir        - Directory to which postscript output will be written.  If not
;                 specified, output is directed only to the screen.
;
; b_w           - Binary parameter, controls whether to plot PDFs in Postscript
;                 file in color (default) or in black-and-white.
; use_vpr       - Binary parameter.  If unset or 0, use the GR samples along the
;                 TMI line-of-sight.  If set, use the GR samples computed along
;                 the local vertical above the TMI surface footprint.
; plot_pct_by   - Specifies which parameter the GR percent-above-threshold
;                 histogram plots are categorized by.  Options are (S)urfaceType
;                 and (R)ainType.  Only the first character ('R' or 'S') is
;                 significant, and is not case-dependent.  Leaving the parameter
;                 unspecified, or specifying any other value than 'R' or 'S'
;                 disables the plot.  Plot is unaffected by the pctAbvThresh
;                 parameter value.
;
; CAPPI_idx     - Index of the height at which to compute scatter and PDFs of 
;                 rain rate, in terms of indices (zero-based) of elements in the
;                 'heights' array defined in the gr2tmi_rr_plots() function,
;                 above.  If not specified, takes the value of "s" in the N.s
;                 number in the elevs2show parameter, or its default value of 0.
;

pro tmi2gr_rainrate_comparisons, SPEED=looprate, $
                                 ELEVS2SHOW=elevs2show, $
                                 NCPATH=ncpath, $
                                 SITE=sitefilter, $
                                 NO_PROMPT=no_prompt, $
                                 PPI_VERTICAL=ppi_vertical, $
                                 PPI_SIZE=ppi_size, $
                                 PCT_ABV_THRESH=pctAbvThresh, $
                                 POP_THRESHOLD=pop_threshold, $
                                 SHOW_THRESH_PPI=show_thresh_ppi, $
                                 HIDE_TOTALS=hide_totals, $
                                 PS_DIR=ps_dir, $
                                 B_W=b_w, $
                                 USE_VPR=use_vpr, $
                                 PLOT_PCT_BY=plot_pct_by, $
                                 CAPPI_idx=CAPPI_idx


; set up the loop speed for xinteranimate, 0<= speed <= 100
IF ( N_ELEMENTS(looprate) EQ 1 ) THEN BEGIN
  IF ( looprate LT 0 OR looprate GT 100 ) THEN looprate = 3
ENDIF ELSE BEGIN
   looprate = 3
ENDELSE

; set up the starting and max # of sweeps to show in animation loop
IF ( N_ELEMENTS(elevs2show) NE 1 ) THEN BEGIN
   print, "Defaulting to 7 for the number of PPI levels to plot, ", $
          "starting with the first."
   elevs2show = 7
   startelev = 0
ENDIF ELSE BEGIN
   IF ( elevs2show LE 0 ) THEN BEGIN
      print, "Disabling PPI animation plot, ELEVS2SHOW <= 0"
      elevs2show = 0
      startelev = 0
   ENDIF ELSE BEGIN
     ; determine whether an INT or a FLOAT was specified
      e2sType = SIZE( elevs2show, /TYPE )
      CASE e2sType OF
        2 : startelev = 0          ; an integer elevs2show was input
        4 : BEGIN                  ; a FLOAT elevs2show was input
              etemp = elevs2show+.00001   ; make temp copy
              elevs2show = FIX( etemp )   ; extract the whole part as elevs2show
             ; extract the tenths part as the starting sweep number
              startelev = ( FIX( (etemp - elevs2show)*10.0 ) - 1 ) > 0
            END
      ENDCASE
      print, "PPIs to plot = ", elevs2show, ", Starting sweep = ", startelev + 1
   ENDELSE
ENDELSE

IF ( N_ELEMENTS(CAPPI_idx) NE 1 ) THEN BEGIN
   print, "Defaulting to startelev value for CAPPI_idx:", startelev
   CAPPI_idx = startelev
ENDIF

IF ( N_ELEMENTS(ncpath) NE 1 ) THEN BEGIN
   print, "Defaulting to /data/netcdf/geo_match for file path."
   pathpr = '/data/netcdf/geo_match'
ENDIF ELSE pathpr = ncpath

IF ( N_ELEMENTS(sitefilter) NE 1 ) THEN BEGIN
   print, "Defaulting to GRtoTMI* for file pattern."
   ncfilepatt = 'GRtoTMI*'
ENDIF ELSE ncfilepatt = '*'+sitefilter+'*'

PPIorient = keyword_set(ppi_vertical)
PPIbyThresh = keyword_set(show_thresh_ppi)
hideTotals = keyword_set(hide_totals)
b_w = keyword_set(b_w)

IF ( N_ELEMENTS(ppi_size) NE 1 ) THEN BEGIN
   print, "Defaulting to 375 for PPI size."
   ppi_size = 375
ENDIF

; Decide which points to include, based on GV percent of expected points
; in bin-averaged results above the dBZ threshold set when the matchups
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
   
; Decide which categories to plot pct_abv_thresh histograms for:
; (R)ain type, (S)urface type, or no plot (default)
IF ( N_ELEMENTS(plot_pct_by) NE 1 || plot_pct_by EQ "" ) THEN BEGIN
   print, "Not plotting histograms of PCT_ABV_THRESH"
ENDIF ELSE BEGIN
   CASE STRUPCASE(STRMID(STRTRIM(plot_pct_by, 1), 0,1)) OF
      'R' : plot_pct_cat = "RainType"
      'S' : plot_pct_cat = "SurfaceType"
     ELSE : print, "Unrecognized field name for plot_pct_by: ", $
              "must be SurfaceType (S) or RainType (R).  Skipping plot."
   ENDCASE
ENDELSE

IF ( N_ELEMENTS(pop_threshold) EQ 1 ) THEN BEGIN
  IF ( pop_threshold LT 0. OR pop_threshold GT 100. ) THEN BEGIN
     print, "PoP_threshold must lie between 0 and 100, value is: ", pop_threshold
     print, "Defaulting to 50.0 for pop_threshold."
     pop_threshold = 50.
  ENDIF
ENDIF ELSE BEGIN
   pop_threshold = 50.
ENDELSE

; set up for Postscript vs. On-Screen output
IF ( N_ELEMENTS( ps_dir ) NE 1 || ps_dir EQ "" ) THEN BEGIN
   print, "Defaulting to screen output for scatter plot."
   ps_dir = ''
ENDIF ELSE BEGIN
   mydirstruc = FILE_INFO(ps_dir )
   IF (mydirstruc.directory) THEN print, "Postscript files will be written to: ", ps_dir $
   ELSE BEGIN
      MESSAGE, "Directory "+ps_dir+" specified for PS_DIR does not exist, exiting."
   ENDELSE
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
         mygeomatchfile = prfiles(fnum)
         action = 0
         action = gr2tmi_rr_plots( mygeomatchfile, looprate, elevs2show, startelev, $
                                      PPIorient, ppi_size, pctAbvThresh, PPIbyThresh, $
                                      hideTotals, CAPPI_idx, POP_THRESHOLD=pop_threshold, $
                                      PS_DIR=ps_dir, B_W=b_w, USE_VPR=use_vpr, $
                                      PLOT_PCT_CAT=plot_pct_cat )

         if (action) then break
      endfor
   endelse
ENDIF ELSE BEGIN
   mygeomatchfile = dialog_pickfile(path=pathpr, filter = ncfilepatt)
   while mygeomatchfile ne '' do begin
      action = 0
      action=gr2tmi_rr_plots( mygeomatchfile, looprate, elevs2show, startelev, $
                                 PPIorient, ppi_size, pctAbvThresh, PPIbyThresh, $
                                 hideTotals, CAPPI_idx, POP_THRESHOLD=pop_threshold, $
                                 PS_DIR=ps_dir, B_W=b_w, USE_VPR=use_vpr, $
                                 PLOT_PCT_CAT=plot_pct_cat )
      if (action) then break
      mygeomatchfile = dialog_pickfile(path=pathpr, filter = ncfilepatt)
   endwhile
ENDELSE

print, "" & print, "Done!"

END
