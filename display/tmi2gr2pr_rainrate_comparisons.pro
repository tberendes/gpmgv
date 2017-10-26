;===============================================================================
;+
; Copyright © 2012, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; tmi2gr2pr_rainrate_comparisons.pro
; - Morris/SAIC/GPM_GV  October 2012
;
;
; DESCRIPTION
; -----------
; Performs a case-by-case statistical analysis of geometry-matched TMI and GR
; rain rate and its matching PR/GR rain rate from data contained in a pair of 
; geo-match netCDF files for a given case.  Rain rate for the GR is derived
; from the volume-averaged reflectivity analyzed to a set of CAPPI surfaces as
; defined by the internal 'heights' parameter, using a Z-R relationship.  For
; the scatter diagrams, PDF plots, and tabular statistics broken out by surface
; type, GR rain rate data are extracted for one user-specified CAPPI surface.
; TMI rainrate is the surface rain rate stored in the GRtoTMI netCDF file
; and originates within the 2A-12 product.  PR rainrate is the near-surface rain
; rate stored in the GRtoPR netCDF file and originates within the 2A-25 product.
;
; In the tabular output, TMI rain rates are compared to both GR and PR rain
; rates.  For the graphics (PPI animation, scatter plots, profiles and PDFs of
; rain rate) TMI is compared to either PR or GR only, as determined by the
; GV_VAR parameter (GR by default, if not specified).
;
; Volume-match PR/GR data are matched up the the TMI volume-match data by
; averaging the PR/GR samples within 'radius' distance from the TMI footprint
; centers, taking into account the parallax offsets of the TMI and PR footprints
; with height on the GR sweep surfaces.  See matchup_prgr2tmigr_merged.pro for
; the code to do this matchup.
;
;
; PARAMETERS
; ----------
; See the prologue of tmi2gr2pr_rainrate_comparisons, the last code module in
; this file.
;
;
; INTERNAL MODULES
; ----------------
; 1) tmi2gr2pr_rainrate_comparisons - Main procedure called by user.  Checks
;                                     input parameters and sets defaults.
;
; 2) gr2tmi2pr_rr_plots - Workhorse procedure to read data, compute statistics,
;                         create vertical profile, histogram, scatter plots, and
;                         tables of PR-GR rainrate differences, and display PR
;                         and GR reflectivity PPI plots in an animation sequence.
;
; 3) print_table_headers - Does what it says.
;
;
; HISTORY
; -------
; 10/16/2012 Morris, GPM GV, SAIC
; - Created from tmi2gr_rainrate_comparisons.pro
; 08/15/13 Morris, GPM GV, SAIC
; - Removed unused 'histo_Width' parameter and 'bs' variable from internal
;   modules and external call to calc_geo_pr_gv_meandiffs_wght_idx.
;
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;===============================================================================
;
; MODULE 3:  print_table_headers
;

pro print_table_headers, var1, var2, CAPPI_HEIGHT=CAPPI_height, PS_UNIT=tempunit

IF N_ELEMENTS(tempunit) EQ 1 THEN do_ps=1 ELSE do_ps=0

; set up spacing based on lengths of var1 and var2
CASE (STRLEN(var1)*10+STRLEN(var2)) OF
   22 : BEGIN
           diffvar = ' '+var1+'-'+var2
           maxvars = ' '+ var1 + 'MaxRR   '+ var2 +'MaxRR'
        END
   23 : BEGIN
           diffvar = var1+'-'+var2
           maxvars = ' '+ var1 + 'MaxRR  '+ var2 +'MaxRR'
        END
   32 : BEGIN
           diffvar = var1+'-'+var2
           maxvars = var1 + 'MaxRR   '+ var2 +'MaxRR'
        END
   ELSE : message, 'illegal string lengths for var1 and var2, must sum to 4 or 5'
ENDCASE

IF N_ELEMENTS(CAPPI_height) EQ 0 THEN BEGIN
   ; print the header for stats broken out by CAPPI levels and rain type
   print, '' & IF (do_ps EQ 1) THEN printf, tempunit, ''
   textout = 'Statistics grouped by fixed height levels (km):'
   print, textout & IF (do_ps EQ 1) THEN printf, tempunit, textout
   print, '' & IF (do_ps EQ 1) THEN printf, tempunit, ''
   textout = ' Vert. |   Any Rain Type  |    Stratiform    |' $
             +'    Convective     |     Dataset Statistics      |'
   print, textout & IF (do_ps EQ 1) THEN printf, tempunit, textout
   textout = ' Layer | '+diffvar+'    NumPts | '+diffvar+'    NumPts |' $
             +' '+diffvar+'    NumPts  | AvgDist  '+maxvars+' |'
   print, textout & IF (do_ps EQ 1) THEN printf, tempunit, textout
   textout = ' ----- | -------   ------ | -------   ------ |' $
             +' -------   ------  | -------  --------  -------- |'
   print, textout & IF (do_ps EQ 1) THEN printf, tempunit, textout

ENDIF ELSE BEGIN
   ; print the header for stats broken out by underlying surface
   print, '' & IF (do_ps EQ 1) THEN printf, tempunit, ''
   print, '' & IF (do_ps EQ 1) THEN printf, tempunit, ''
   textout = 'Statistics grouped by underlying surface type, on ' $
             +STRING(CAPPI_height, FORMAT='(F0.1)')+" km CAPPI surface:"
   print, textout & IF (do_ps EQ 1) THEN printf, tempunit, textout
   print, '' & IF (do_ps EQ 1) THEN printf, tempunit, ''
   textout = 'Surface|   Any Rain Type  |    Stratiform    |' $
             +'    Convective     |     Dataset Statistics      |'
   print, textout & IF (do_ps EQ 1) THEN printf, tempunit, textout
   textout = ' type  | '+diffvar+'    NumPts | '+diffvar+'    NumPts |' $
             +' '+diffvar+'    NumPts  | AvgDist  '+maxvars+' |'
   print, textout & IF (do_ps EQ 1) THEN printf, tempunit, textout
   textout = ' ----- | -------   ------ | -------   ------ |' $
             +' -------   ------  | -------  --------  -------- |'
   print, textout & IF (do_ps EQ 1) THEN printf, tempunit, textout

ENDELSE

end

;===============================================================================
;
; MODULE 2:  gr2tmi2pr_rr_plots
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

FUNCTION gr2tmi2pr_rr_plots, mygeomatchfile, looprate, elevs2show, startelev, $
                             PPIorient, windowsize, pctabvthresh, PPIbyThresh, $
                             hideTotals, heights, CAPPI_idx, matchupStruct, $
                             VAR2=var2, PS_DIR=ps_dir, B_W=b_w, $
                             USE_VPR=use_vpr, PLOT_PCT_CAT=plot_pct_cat

; "include" file for read_geo_match_netcdf() structs returned
@geo_match_nc_structs.inc

; "include" file for PR data constants
@pr_params.inc

bname = file_basename( mygeomatchfile )
prlen = strlen( bname )

; set up GR % above thresh text for graphics labels
pctString = STRTRIM(STRING(FIX(pctabvthresh)),2)
IF pctabvthresh GT 0.0 THEN BEGIN
   pctLabel = "GR bins above Z threshold >= " + pctString + "%"
   pctLabelPPI = "GR bins above threshold " + '!m' + STRING("142B) + pctString + "%"
ENDIF ELSE BEGIN
   pctLabel = "all non-zero points"
   pctLabelPPI = pctLabel
ENDELSE

parsed = STRSPLIT( bname, '.', /extract )
site = parsed[1]
yymmdd = parsed[2]
orbit = parsed[3]
version = parsed[4]

bbparms = matchupStruct.bbparms  ;{meanBB : 4.0, BB_HgtLo : -99, BB_HgtHi : -99}
RRcut = 0.1 ;10.      ; TMI/GV rainrate lower cutoff of points to use in mean diff. calcs.
rangecut = 100.

hgtinterval = heights[1]-heights[0]
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

  site_lat = mysite.site_lat
  site_lon = mysite.site_lon
  siteID = string(mysite.site_id)

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
   idxpopok = WHERE( PoP GE 50, countpopok )
   idxtmirain = WHERE( sfcrain GE RRcut, nsfcrainy )
   print, countpopok, nsfcrainy, N_ELEMENTS(PoP), $
         FORMAT='("# PoP footprints GE 50% = ", I0, ", # TMI rainy: ", I0, ",  # footprints = ", I0)'
;   print, PoP
ENDIF

; substitute GR vertical profile fields for along-TMI samples if indicated
IF KEYWORD_SET( use_vpr ) THEN BEGIN
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
ENDIF

 ; open a file to hold output stats to be appended to the Postscript file,
 ; if Postscript output is indicated
  IF KEYWORD_SET( ps_dir ) THEN BEGIN
     do_ps = 1
     temptext = ps_dir + '/dbzdiffstats_temp.txt'
     OPENW, tempunit, temptext, /GET_LUN
  ENDIF ELSE do_ps = 0

; get array indices of the non-bogus (i.e., "actual") footprints
; -- tmi_index is defined for one slice (sweep level), while most fields are
;    multiple-level (have another dimension: nswp).  Deal with this later on.
idxpractual = where(tmi_index GE 0L, countactual)
if (countactual EQ 0) then begin
   print, "No non-bogus data points, quitting case."
   status = 1
   goto, errorExit
endif

; copy the first sweep values to the other levels, and while in the same loop,
; make the single-level arrays for categorical fields the same dimension as the
; sweep-level by array concatenation
IF ( nswp GT 1 ) THEN BEGIN  
   rnFlagApp = rnFlag
   sfcRainApp = sfcRain
   nearSurfRain = matchupStruct.dataparms.nearSurfRain
   nearSurfRainApp = matchupStruct.dataparms.nearSurfRain
   tmi_indexApp = tmi_index
   sfctypApp=sfctyp
   dataFlagApp=dataFlag
   IF ( mygeometa.tmi_version EQ 7 ) THEN PoPApp= PoP
  FOR iswp=1, nswp-1 DO BEGIN
      rnFlag = [rnFlag, rnFlagApp]  ; concatenate another level's worth for rain flag
      sfcRain = [sfcRain, sfcRainApp]  ; ditto for sfc rain
      nearSurfRain = [nearSurfRain, nearSurfRainApp]  ; ditto for PR sfc rain
      tmi_index = [tmi_index, tmi_indexApp]  ; ditto for tmi_index
      sfctyp = [sfctyp, sfctypApp]  ; ditto for sfctyp
      dataFlag = [dataFlag, dataFlagApp]  ; ditto for dataFlag
      IF ( mygeometa.tmi_version EQ 7 ) THEN PoP = [PoP, PoPApp] 
   ENDFOR
ENDIF

; make copies of the full 2-D arrays of Z and RR for later plotting, and
; make tmi_index of the same dimensionality as the multi-level variables, it
; is a 1-D array after concatenation - get_gr_geo_match_rain_type() needs it to
; be same as gvz, top, botm, etc.
rain3_in = REFORM( sfcRain, nfp, nswp, /OVERWRITE )
tmi_index = REFORM( tmi_index, nfp, nswp, /OVERWRITE )
gvz_in = gvz

print, ''

;-------------------------------------------------

; compute a rain type and BB height estimate from the GR vertical profiles

rntype = FIX(gvz) & rntype[*,*] = 3      ; Initialize a 2-D rainType array to 'Other'
;HELP, RNTYPE
meanBBgr = -99.99
rntype4ppi = get_gr_geo_match_rain_type( tmi_index, gvz_vpr, top_vpr, botm_vpr, $
                                         SINGLESCAN=0, VERBOSE=0, MEANBB=meanBBgr )

; compute a dominant rain type from set of PR 2A25 rain types mapped to TMI footprints
rntypepr = INTARR(matchupStruct.dataparms.numTMIsfc, nswp)
temptypepr = INTARR(matchupStruct.dataparms.numTMIsfc) & temptypepr[*] = -1
idxprnonzero = WHERE( matchupStruct.dataparms.numPRsfc GT 0, countnonzero )
IF countnonzero GT 0 THEN BEGIN
   pctConvPR = FLOAT(matchupStruct.dataparms.rnTypeConv[idxprnonzero]) $
                   / matchupStruct.dataparms.numPRsfc[idxprnonzero]
   idxthistype = WHERE(pctConvPR LE 0.3, countthistype)
   if countthistype GT 0 THEN temptypepr[idxprnonzero[idxthistype]] = 1     ; stratiform
   idxthistype = WHERE(pctConvPR GT 0.3 AND pctConvPR LE 0.7, countthistype)
   if countthistype GT 0 THEN temptypepr[idxprnonzero[idxthistype]] = 3     ; other/mixed
   idxthistype = WHERE(pctConvPR GT 0.7)
   if countthistype GT 0 THEN temptypepr[idxprnonzero[idxthistype]] = 2     ; convective
ENDIF

; copy the single-level rain type fields to each level of 2-D array
FOR level = 0, mygeometa.num_sweeps-1 DO BEGIN
   rnType[*,level] = rntype4ppi
   rntypepr[*,level] = temptypepr
ENDFOR
  help, rntypepr, rnType
; - - - - - - - - - - - - - - - - - - - - - - - -

 ; pare the TMI arrays down to the samples with matching PR data

  nfp = matchupStruct.dataparms.numTMIsfc   ; reset the 1st dimension size

  gvexp=gvexp[matchupStruct.dataparms.GRtoTMI_idx_3d]
  gvexp=REFORM(gvexp, nfp,nswp, /OVERWRITE)
  gvrej=gvrej[matchupStruct.dataparms.GRtoTMI_idx_3d]
  gvrej=REFORM(gvrej,nfp,nswp, /OVERWRITE)
  gvz=gvz[matchupStruct.dataparms.GRtoTMI_idx_3d]
  gvz=REFORM(gvz,nfp,nswp, /OVERWRITE)
  gvz_in=gvz_in[matchupStruct.dataparms.GRtoTMI_idx_3d]
  gvz_in=REFORM(gvz_in,nfp,nswp, /OVERWRITE)
  gvzmax=gvzmax[matchupStruct.dataparms.GRtoTMI_idx_3d]
  gvzmax=REFORM(gvzmax,nfp,nswp, /OVERWRITE)
  gvzstddev=gvzstddev[matchupStruct.dataparms.GRtoTMI_idx_3d]
  gvzstddev=REFORM(gvzstddev,nfp,nswp, /OVERWRITE)
  top=top[matchupStruct.dataparms.GRtoTMI_idx_3d]
  top=REFORM(top,nfp,nswp, /OVERWRITE)
  botm=botm[matchupStruct.dataparms.GRtoTMI_idx_3d]
  botm=REFORM(botm,nfp,nswp, /OVERWRITE)
  lat=lat[matchupStruct.dataparms.GRtoTMI_idx_3d]
  lat=REFORM(lat,nfp,nswp, /OVERWRITE)
  lon=lon[matchupStruct.dataparms.GRtoTMI_idx_3d]
  lon=REFORM(lon,nfp,nswp, /OVERWRITE)
  sfctyp=sfctyp[matchupStruct.dataparms.GRtoTMI_idx_3d]
  sfctyp=REFORM(sfctyp, nfp,nswp, /OVERWRITE)
  sfcrain=sfcrain[matchupStruct.dataparms.GRtoTMI_idx_3d]
  sfcrain=REFORM(sfcrain, nfp,nswp, /OVERWRITE)
  rain3_in=rain3_in[matchupStruct.dataparms.GRtoTMI_idx_3d]
  rain3_in=REFORM(rain3_in,nfp,nswp, /OVERWRITE)
  rnflag=rnflag[matchupStruct.dataparms.GRtoTMI_idx_3d]
  rnflag=REFORM(rnflag, nfp,nswp, /OVERWRITE)

  rnType=rnType[matchupStruct.dataparms.GRtoTMI_idx_3d]
  rnType=REFORM(rnType, nfp,nswp, /OVERWRITE)

  rntype4ppi=REFORM(rnTypePR[*,0])                ; grab one level only for PPI plots

  dataflag=dataflag[matchupStruct.dataparms.GRtoTMI_idx_3d]
  dataflag=REFORM(dataflag, nfp,nswp, /OVERWRITE)
  IF ( mygeometa.tmi_version EQ 7 ) THEN BEGIN
     PoP=PoP[matchupStruct.dataparms.GRtoTMI_idx_3d]
     PoP=REFORM(PoP, nfp,nswp, /OVERWRITE)
  ENDIF
  tmi_index=tmi_index[matchupStruct.dataparms.GRtoTMI_idx_3d]
  tmi_index=REFORM(tmi_index, nfp,nswp, /OVERWRITE)

  oldxcorner = xcorner
  oldycorner = ycorner
  xcorner=fltarr(4,nfp,nswp)
  ycorner=fltarr(4,nfp,nswp)
  for corneridx = 0,3 do begin
     temp = REFORM(oldxcorner[corneridx, *, *])
     temp = temp[matchupStruct.dataparms.GRtoTMI_idx_3d]
     temp = REFORM(temp, nfp,nswp, /OVERWRITE)
     xcorner[corneridx, *, *] = temp
     temp = REFORM(oldycorner[corneridx, *, *])
     temp = temp[matchupStruct.dataparms.GRtoTMI_idx_3d]
     temp = REFORM(temp, nfp,nswp, /OVERWRITE)
     ycorner[corneridx, *, *] = temp
  endfor

  ; get copy of the PR 3D rainrate matched to TMI, and restore dimensions of
  ; replicated nearSurfRain and copy as sfcrn_pr_in
  rain3_pr_in = matchupStruct.dataparms.rain3
  nearSurfRain = REFORM( nearSurfRain, nfp, nswp, /OVERWRITE )
  sfcrn_pr_in = nearSurfRain

; - - - - - - - - - - - - - - - - - - - - - - - -

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
dist = REFORM( dist, nfp, nswp )

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
stop
   status = 1   ; set to FAILED
   goto, errorExit
ENDELSE

; - - - - - - - - - - - - - - - - - - - - - - - -

; Compute GV percent of expected points in bin-averaged results that were
; above dBZ thresholds set when the matchups were done.

pctgoodgv = fltarr( N_ELEMENTS(gvexp) )
pctgoodgv[*] = -99.9
print, "======================================================="
print, "Computing Percent Above Threshold for GR Reflectivity."
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

; generate CAPPI fields at each height in 'heights' array now that we have pctgoodgv

gvzCAP=FLTARR(nfp,ncappis)
hgtCAP=FLTARR(nfp,ncappis)
pctgoodgvCAP=FLTARR(nfp,ncappis)
sfcRainCAP=FLTARR(nfp,ncappis)
rnTypeCAP=INTARR(nfp,ncappis)
PRsfcRainCAP=FLTARR(nfp,ncappis)
PRrnTypeCAP=INTARR(nfp,ncappis)
distCAP=FLTARR(nfp,ncappis)
sfcTypCAP=INTARR(nfp,ncappis)
CAPPIlev=FLTARR(nfp,ncappis)   ; height of fixed CAPPI levels, from "heights"
voldepthCAP=FLTARR(nfp,ncappis)
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
   PRsfcRainCAP[*,ifram] = nearSurfRain[idxcappi]
   PRrnTypeCAP[*,ifram] = rnTypepr[idxcappi]
   distCAP[*,ifram] = dist[idxcappi]
   sfcTypCAP[*,ifram] = sfcTyp[idxcappi]
   CAPPIlev[*,ifram] = heights[ifram]
   voldepthCAP[*,ifram] = top[idxcappi] - botm[idxcappi]
   IF ( mygeometa.tmi_version EQ 7 ) THEN PoPCAP[*,ifram] = PoP[idxcappi]
ENDFOR

; Preview our CAPPI level data - diagnostic output only

;idxmycappi = WHERE( CAPPIlev EQ CAPPI_height, countatcappi )
;IF ( countatcappi GT 0 ) THEN BEGIN
;   print, "sfcRain:" & print, sfcRainCAP[idxmycappi]
;   print, "gvz:" & print,  gvzCAP[idxmycappi]
;   print, "height:" & print,  hgtCAP[idxmycappi]
;   print, "rnType:" & print,  rnTypeCAP[idxmycappi]
;   print, "PRrnType:" & print,  PRrnTypeCAP[idxmycappi]
;   print, "dist:" & print,  distCAP[idxmycappi]
;   print, "voldepth:" & print,  voldepthCAP[idxmycappi]
;   ; reassign surface type values (10,20,30) to (1,2,3).
;   print, "sfcCat:" & print,  sfcTypCAP[idxmycappi]/10
;ENDIF ELSE print, 'NO POINTS TO PRINT FOR CAPPI LEVEL'

; - - - - - - - - - - - - - - - - - - - - - - - -

; clip the arrays of CAPPI data that are used for the scatter diagrams and PDFs.
; If pctAbvThresh unspecified or set to zero, include all points regardless of
; 'completeness' of the volume averages.  IF V7, also filter on PoP >= 50

IF ( pctAbvThresh GT 0.0 ) THEN BEGIN
    ; clip to the 'good' points, where 'pctAbvThresh' fraction of bins in average
    ; were above threshold
   IF ( mygeometa.tmi_version EQ 7 ) THEN BEGIN
      idxgoodenuff = WHERE( pctgoodgvCAP GE pctAbvThresh AND PoPCAP GE 50, countgoodpct )
      PRINT, 'ALSO FILTERING BASED ON V7 PoP GE 50'
      print, "======================================================="
   ENDIF ELSE idxgoodenuff = WHERE( pctgoodgvCAP GE pctAbvThresh, countgoodpct )
ENDIF ELSE BEGIN
  ; pctAbvThresh is 0, take/plot ALL non-missing points
   IF ( mygeometa.tmi_version EQ 7 ) THEN BEGIN
      idxgoodenuff = WHERE( pctgoodgvCAP GT 0.0 AND PoPCAP GE 50, countgoodpct )
      PRINT, 'FILTERING BASED ON V7 PoP GE 50'
      print, "======================================================="
   ENDIF ELSE idxgoodenuff = WHERE( pctgoodgvCAP GT 0.0, countgoodpct )
ENDELSE

IF ( countgoodpct GT 0 ) THEN BEGIN
    hgtCAP = hgtCAP
    gvrrCAP = z_r_rainrate(gvzCAP[idxgoodenuff])
    pctgoodgvCAP = pctgoodgvCAP[idxgoodenuff]
    sfcRainCAP = sfcRainCAP[idxgoodenuff]
    rnTypeCAP = rnTypeCAP[idxgoodenuff]
    PRsfcRainCAP = PRsfcRainCAP[idxgoodenuff]
    PRrnTypeCAP = PRrnTypeCAP[idxgoodenuff]
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
; If pctAbvThresh unspecified or set to zero then include all points,
; regardless of 'completeness' of the volume averages.

IF ( pctAbvThresh GT 0.0 ) THEN BEGIN
    ; clip to the 'good' points, where 'pctAbvThresh' fraction of bins in average
    ; were above threshold
   IF ( mygeometa.tmi_version EQ 7 ) THEN BEGIN
      idxgoodenuff = WHERE( pctgoodgv GE pctAbvThresh AND PoP GE 50, countgoodpct )
   ENDIF ELSE idxgoodenuff = WHERE( pctgoodgv GE pctAbvThresh, countgoodpct )
ENDIF ELSE BEGIN
  ; pctAbvThresh is 0, take/plot ALL non-missing points
   IF ( mygeometa.tmi_version EQ 7 ) THEN BEGIN
      idxgoodenuff = WHERE( pctgoodgv GT 0.0 AND PoP GE 50, countgoodpct )
   ENDIF ELSE idxgoodenuff = WHERE( pctgoodgv GT 0.0, countgoodpct )
ENDELSE

IF ( countgoodpct GT 0 ) THEN BEGIN
   gvrr = z_r_rainrate(gvz[idxgoodenuff])
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
   nearSurfRain = nearSurfRain[idxgoodenuff]
   rnTypepr = rnTypepr[idxgoodenuff]
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
   gvz_in2 = REFORM( z_r_rainrate(gvz_in), nfp, nswp )
   rain3_in2 = rain3_in
   sfcrn_pr_in2 = sfcrn_pr_in
   IF ( count2blank GT 0 ) THEN BEGIN
     gvz_in2[idx2blank] = 0.0
     rain3_in2[idx2blank] = 0.0
     sfcrn_pr_in2[idx2blank] = 0.0
     PRINT, "NUMBER OF FOOTPRINTS TO BLANK BASED ON POP/PCT: ", count2blank
   ENDIF
ENDIF ELSE BEGIN
   sfcrn_pr_in2 = sfcrn_pr_in  ; just make copy of full array for PPI plots
   rain3_in2 = rain3_in
   gvz_in2 = REFORM( z_r_rainrate(gvz_in), nfp, nswp )
ENDELSE

; determine the non-missing points-in-common between PR and GV, data value-wise,
; to make sure the same points are plotted on PR and GV PPIs
idx2blank2 = WHERE( (gvz_in2 LT 0.0) OR (rain3_in2 LT 0.0) OR (sfcrn_pr_in2 LT 0.0), count2blank2 )
IF ( count2blank2 GT 0 ) THEN BEGIN
   gvz_in2[idx2blank2] = 0.0
   rain3_in2[idx2blank2] = 0.0
   sfcrn_pr_in2[idx2blank2] = 0.0
   PRINT, "NUMBER OF FOOTPRINTS TO BLANK BASED ON MATCHING NON-ZERO: ", count2blank2
ENDIF
; - - - - - - - - - - - - - - - - - - - - - - - -

; build an array of range categories from the GV radar, using ranges previously
; computed from lat and lon:
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

; reassign surface type values (10,20,30) to (1,2,3).
sfcCat = sfcTyp/10
; get info from array of surface type
num_over_SfcType = LONARR(4)
idxmix = WHERE( sfcCat EQ 3, countmix )  ; Coast
num_over_SfcType[3] = countmix
idxsea = WHERE( sfcCat EQ 1, countsea )  ; Ocean
num_over_SfcType[1] = countsea
idxland = WHERE( sfcCat EQ 2, countland )    ; Land
num_over_SfcType[2] = countland

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
print, '' & IF (do_ps EQ 1) THEN printf, tempunit, ''
textout = 'TMI-GR Rain Rate difference statistics (mm/h) - GV Site: '+siteID $
          +'   Orbit: '+orbit+'   V'+version
print, textout & IF (do_ps EQ 1) THEN printf, tempunit, textout
textout ='TMI time = '+mygeometa.atimeNearestApproach+'   GV start time = '+mysweeps[0].atimeSweepStart
print, textout & IF (do_ps EQ 1) THEN printf, tempunit, textout
textout = 'Required percent of above-threshold GV bins in matched volumes >= '+pctString+"%"
IF pctabvthresh LE 0.0 THEN textout = textout + " (all non-zero samples)"
print, textout & IF (do_ps EQ 1) THEN printf, tempunit, textout

mnTMIarr = fltarr(3,nhgtcats)  ; each level, for raintype all, stratiform, convective
mngvarr = fltarr(3,nhgtcats)  ; each level, for raintype all, stratiform, convective
levhasdata = intarr(nhgtcats)

; - - - - - - - - - - - - - - - - - - - - - - - -

sources = [['TMI','PR'],['TMI','GR']]
; Figure out which of the 2nd sources is the one matching var2, the source to
; plot vs. TMI in the PDF/profile and scatter plots.  Won't need in the loop
; over levels, but will need it later in the loop over surface types
idx4pdfprof=where(sources[1,*] EQ var2)

FOR isources = 0, 1 DO BEGIN
   rntype2use = rnTypePR

   src1 = sources[0,isources]
   src2 = sources[1,isources]
   ; we set up the CASE for all possibilities, though src1 is always TMI here
   CASE src1 OF
      'TMI' : yvar = sfcrain
       'PR' : BEGIN
                 yvar = nearSurfRain
                 rntype2use = rnTypePR
              END
       'GR' : yvar = gvrr
   ENDCASE
   CASE src2 OF
      'TMI' : xvar = sfcrain
       'PR' : BEGIN
                 xvar = nearSurfRain
                 rntype2use = rnTypePR
              END
       'GR' : xvar = gvrr
   ENDCASE

   print_table_headers, src1, src2, PS_UNIT=tempunit
   levhasdata[*] = 0
   levsdata = 0
   max_hgt_w_data = 0.0

   ; Compute a mean rainrate difference at each level

   for lev2get = 0, nhgtcats-1 do begin
      havematch = 0
      thishgt = (lev2get+1)*hgtinterval
      IF thishgt GT 6.0 THEN BREAK

      IF ( num_in_hgt_cat[lev2get] EQ 0 ) THEN BEGIN
         print, "No points at height " + string(heights[lev2get], FORMAT='(f0.3)')
      ENDIF ELSE BEGIN
         flag = ''
         idx4hist = lonarr(num_in_hgt_cat[lev2get])  ; array indices used for point-to-point mean diffs
         idx4hist[*] = -1L
         if (lev2get eq BBparms.BB_HgtLo OR lev2get eq BBparms.BB_HgtHi) then flag = ' @ BB'
         diffstruc = the_struc
         calc_geo_pr_gv_meandiffs_wght_idx, yvar, xvar, rnType2use, dist, distcat, hgtcat, $
                             lev2get, RRcut, rangecut, mnTMIarr, mngvarr, $
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
            rr_TMI2 = sfcRain[idx4hist[0:diffstruc.fullcount-1]]
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
      ENDELSE

   endfor         ; lev2get = 0, nhgtcats-1

   IF isources EQ idx4pdfprof THEN BEGIN
      mnTMIarr4pdf = mnTMIarr
      mngvarr4pdf = mngvarr
   ENDIF

ENDFOR         ; sources

print, '' & IF (do_ps EQ 1) THEN printf, tempunit, ''

if (levsdata eq 0) then begin
   print, "No valid data levels found for reflectivity!"
   IF (do_ps EQ 1) THEN printf, tempunit, "No valid data levels found for reflectivity!"
   nframes = 0
   print, ''
   goto, nextFile
endif else begin
   print, '' & IF (do_ps EQ 1) THEN printf, tempunit, ''
endelse

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
   Window, xsize=700, ysize=700, TITLE = strmid( bname, 8, 17) $
           + ".V"+version + "  --  " + "With " + pctLabel, RETAIN=2
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
   TMImnz2plot = mnTMIarr4pdf[0,*]
   TMImnz2plot = TMImnz2plot[idxlev2plot]
   gvmnz2plot = mngvarr4pdf[0,*]
   gvmnz2plot = gvmnz2plot[idxlev2plot]
   oplot, TMImnz2plot, h2plot, COLOR=PR_COLR, thick=1*THIKadjPR
   oplot, gvmnz2plot, h2plot, COLOR=GV_COLR, thick=1*THIKadjGV
ENDIF

; plot the profile for stratiform rain type points
TMImnz2plot = mnTMIarr4pdf[1,*]
TMImnz2plot = TMImnz2plot[idxlev2plot]
gvmnz2plot = mngvarr4pdf[1,*]
gvmnz2plot = gvmnz2plot[idxlev2plot]
idxhavezs = WHERE( TMImnz2plot GT 0.0 and gvmnz2plot GT 0.0, counthavezs )
IF ( counthavezs GT 0 ) THEN BEGIN
   oplot, TMImnz2plot[idxhavezs], h2plot[idxhavezs], COLOR=PR_COLR, LINESTYLE=ST_LINE, thick=3*THIKadjPR
   oplot, gvmnz2plot[idxhavezs], h2plot[idxhavezs], COLOR=GV_COLR, LINESTYLE=ST_LINE, thick=3*THIKadjGV
ENDIF

; plot the profile for convective rain type points
TMImnz2plot = mnTMIarr4pdf[2,*]
TMImnz2plot = TMImnz2plot[idxlev2plot]
gvmnz2plot = mngvarr4pdf[2,*]
gvmnz2plot = gvmnz2plot[idxlev2plot]
idxhavezs = WHERE( TMImnz2plot GT 0.0 and gvmnz2plot GT 0.0, counthavezs )
IF ( counthavezs GT 0 ) THEN BEGIN
   oplot, TMImnz2plot[idxhavezs], h2plot[idxhavezs], COLOR=PR_COLR, LINESTYLE=CO_LINE, thick=3*THIKadjPR
   oplot, gvmnz2plot[idxhavezs], h2plot[idxhavezs], COLOR=GV_COLR, LINESTYLE=CO_LINE, thick=3*THIKadjGV
ENDIF

IF var2 EQ 'GR' THEN var2id = siteID ELSE var2id = var2
; plot line/legend material
IF ( ~ hideTotals ) THEN BEGIN
   xyouts, 0.34, 0.95, 'TMI (all)', COLOR=PR_COLR, /NORMAL, CHARSIZE=1*CHARadj
   plots, [0.29,0.33], [0.955,0.955], COLOR=PR_COLR, /NORMAL
   xyouts, 0.34, 0.925, var2id+' (all)', COLOR=GV_COLR, /NORMAL, CHARSIZE=1*CHARadj
   plots, [0.29,0.33], [0.93,0.93], COLOR=GV_COLR, /NORMAL
ENDIF
xyouts, 0.34, 0.85, 'TMI (Conv)', COLOR=PR_COLR, /NORMAL, CHARSIZE=1*CHARadj
xyouts, 0.34, 0.825, var2id+' (Conv)', COLOR=GV_COLR, /NORMAL, CHARSIZE=1*CHARadj
plots, [0.29,0.33], [0.855,0.855], COLOR=PR_COLR, /NORMAL, LINESTYLE=CO_LINE, thick=3*THIKadjPR
plots, [0.29,0.33], [0.83,0.83], COLOR=GV_COLR, /NORMAL, LINESTYLE=CO_LINE, thick=3*THIKadjGV
xyouts, 0.34, 0.9, 'TMI (Strat)', COLOR=PR_COLR, /NORMAL, CHARSIZE=1*CHARadj
xyouts, 0.34, 0.875, var2id+' (Strat)', COLOR=GV_COLR, /NORMAL, CHARSIZE=1*CHARadj
plots, [0.29,0.33], [0.905,0.905], COLOR=PR_COLR, /NORMAL, LINESTYLE=ST_LINE, thick=3*THIKadjPR
plots, [0.29,0.33], [0.88,0.88], COLOR=GV_COLR, /NORMAL, LINESTYLE=ST_LINE, thick=3*THIKadjGV

; plot mean BB level from PR
xvals = [0.1,150]
yvalsbb = [bbparms.meanbb,bbparms.meanbb]
plots, xvals, yvalsbb, COLOR=255, LINESTYLE=2;, THICK=3*THIKadjGV
plots, [0.29,0.33], [0.805,0.805], COLOR=255, /NORMAL, LINESTYLE=2
XYOutS, 0.34, 0.8, 'Mean BB (PR)', COLOR=255, CHARSIZE=1*CHARadj, /NORMAL
; plot mean BB level from GR
yvalsbb = [meanBBgr, meanBBgr]
plots, xvals, yvalsbb, COLOR=GV_COLR, LINESTYLE=2
plots, [0.29,0.33], [0.78,0.78], COLOR=GV_COLR, /NORMAL, LINESTYLE=2
XYOutS, 0.34, 0.775, 'Mean BB (GR)', COLOR=GV_COLR, CHARSIZE=1*CHARadj, /NORMAL

; - - - - - - - - - - - - - - - - - - - - - - - -

; Compute a mean rainrate difference over each surface type and plot PDFs

mnTMIarrbb = fltarr(3,4)  ; each BB-relative level, for raintype all, stratiform, convective
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
   nearSurfRain = PRsfcRainCAP[idxmycappi]
   PRrnType = PRrnTypeCAP[idxmycappi]
   gvrr = gvrrCAP[idxmycappi]
   rnType = rnTypeCAP[idxmycappi]
   dist = distCAP[idxmycappi]
   distcat = distcatCAP[idxmycappi]
   voldepth = voldepthCAP[idxmycappi]
   ; reassign surface type values (10,20,30) to (1,2,3).
   sfcCat = sfcTypCAP[idxmycappi]/10
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
   PRrnType = -1          ; need to define something for variable
ENDELSE

; nobody gets preferential treatment, weight-wise
voldepth[*] = 1.0

;help, sfcRain, gvrr, rnType, dist, distcat, sfcCat, voldepth, num_over_SfcType
print, ''
print, CAPPI_height, num_rr_abv_thresh, countatcappi, $
       FORMAT='("Number of rainy points on ", F0.1, " km CAPPI level: ", I0, " of ", I0, " total")'

; some fixed legend stuff for PDF plots
IF var2 EQ 'GR' THEN BEGIN
   headline = 'TMI-'+var2id+' Biases'
   CAPPI_label = 'on '+STRING(CAPPI_height, FORMAT='(F0.1)')+' km CAPPI'
ENDIF ELSE BEGIN
    headline = 'TMI-'+var2id+' Biases for'
   CAPPI_label = 'Surface rain rate'
ENDELSE

; define a 2D array to capture array indices of values used for point-to-point
; mean diffs, for each of the 3 sfcCat levels, for plotting these points in the
; scatter plots
numZpts = N_ELEMENTS(sfcRain)
idx4hist3 = lonarr(3,numZpts)
idx4hist3[*,*] = -1L
num4hist3 = lonarr(3)  ; track number of points used in each sfcCat layer
idx4hist = idx4hist3[0,*]  ; a 1-D array for passing to function in the layer loop

FOR isources = 0, 1 DO BEGIN

   src1 = sources[0,isources]
   src2 = sources[1,isources]
   rntype2use = rnTypePR

   CASE src1 OF
      'TMI' : yvar = sfcrain
       'PR' : BEGIN
                 yvar = nearSurfRain
                 rntype2use = PRrnType
              END
       'GR' : yvar = gvrr
   ENDCASE
   CASE src2 OF
      'TMI' : xvar = sfcrain
       'PR' : BEGIN
                 xvar = nearSurfRain
                 rntype2use = PRrnType
              END
       'GR' : xvar = gvrr
   ENDCASE

   print_table_headers, src1, src2, CAPPI_HEIGHT=CAPPI_height, PS_UNIT=tempunit

   for SfcType_2get = 1, 3 do begin
      havematch = 0
      !P.Multi=[4-SfcType_2get,2,2,0,0]
      IF ( num_over_SfcType[SfcType_2get] GT 0 ) THEN BEGIN
         flag = ''
         if (SfcType_2get eq 2) then flag = ' @ BB'
         diffstruc = the_struc
         calc_geo_pr_gv_meandiffs_wght_idx, yvar, xvar, rnType2use, dist, distcat, sfcCat, $
                                SfcType_2get, RRcut, rangecut, mnTMIarrbb, mngvarrbb, $
                                havematch, diffstruc, idx4hist, voldepth
         if (havematch eq 1) then begin
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
            rr_TMI2 = yvar[idx4hist[0:diffstruc.fullcount-1]]
            rr_gv2 = xvar[idx4hist[0:diffstruc.fullcount-1]]
            type2 = rnType2use[idx4hist[0:diffstruc.fullcount-1]]
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

            IF isources NE idx4pdfprof THEN GOTO, skipPDFs

           ; Plot the PDF graph for this level
            hgtline = 'Layer = ' + SfcType_str[SfcType_2get]

           ; DO ANY/ALL RAINTYPE PDFS FIRST
           ; define a set of 18 log-spaced range boundaries - yields 19 rainrate categories
            logbins = 10^(findgen(18)/5.-1)
           ; figure out where each point falls in the log ranges: from -1 (below lowest bound)
           ; to 18 (above highest bound)
            bin4pr = VALUE_LOCATE( logbins, rr_TMI2 )
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
;               xyouts, 0.34, 0.95, 'TMI (all)', COLOR=PR_COLR, /NORMAL, $
;                       CHARSIZE=1*CHARadj
;               plots, [0.29,0.33], [0.955,0.955], COLOR=PR_COLR, /NORMAL
;               xyouts, 0.34, 0.925, siteID+' (all)', COLOR=GV_COLR, /NORMAL, $
;                       CHARSIZE=1*CHARadj
;               plots, [0.29,0.33], [0.93,0.93], COLOR=GV_COLR, /NORMAL
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
              bin4pr = VALUE_LOCATE( logbins, rr_TMI2[idxconvhist] )  ; see Any/All logic above
              bin4gr = VALUE_LOCATE( logbins, rr_gv2[idxconvhist] )
              prhist = histogram( bin4pr, min=0, max=18,locations = prhiststart )
              nxhist = histogram( bin4gr, min=0, max=18,locations = prhiststart )
              oplot, prhiststart, prhist, COLOR=PR_COLR, LINESTYLE=CO_LINE, thick=3*THIKadjPR
              oplot, prhiststart, nxhist, COLOR=GV_COLR, LINESTYLE=CO_LINE, thick=3*THIKadjGV
;              xyouts, 0.34, 0.85, 'TMI (Conv)', COLOR=PR_COLR, /NORMAL, CHARSIZE=1*CHARadj
;              xyouts, 0.34, 0.825, siteID+' (Conv)', COLOR=GV_COLR, /NORMAL, CHARSIZE=1*CHARadj
;              plots, [0.29,0.33], [0.855,0.855], COLOR=PR_COLR, /NORMAL, LINESTYLE=CO_LINE, thick=3*THIKadjPR
;              plots, [0.29,0.33], [0.83,0.83], COLOR=GV_COLR, /NORMAL, LINESTYLE=CO_LINE, thick=3*THIKadjGV
            ENDIF

           ; OVERLAY STRATIFORM RAINTYPE PDFS, IF ANY POINTS
            idxstrathist= WHERE( type2 EQ RainType_stratiform, nstrat )
            IF ( nstrat GT 0 ) THEN BEGIN
              bin4pr = VALUE_LOCATE( logbins, rr_TMI2[idxstrathist] )  ; see Any/All logic above
              bin4gr = VALUE_LOCATE( logbins, rr_gv2[idxstrathist] )
              prhist = histogram( bin4pr, min=0, max=18,locations = prhiststart )
              nxhist = histogram( bin4gr, min=0, max=18,locations = prhiststart )
              oplot, prhiststart, prhist, COLOR=PR_COLR, LINESTYLE=ST_LINE, thick=3*THIKadjPR
              oplot, prhiststart, nxhist, COLOR=GV_COLR, LINESTYLE=ST_LINE, thick=3*THIKadjGV
;              xyouts, 0.34, 0.9, 'TMI (Strat)', COLOR=PR_COLR, /NORMAL, CHARSIZE=1*CHARadj
;              xyouts, 0.34, 0.875, siteID+' (Strat)', COLOR=GV_COLR, /NORMAL, CHARSIZE=1*CHARadj
;              plots, [0.29,0.33], [0.905,0.905], COLOR=PR_COLR, /NORMAL, LINESTYLE=ST_LINE, thick=3*THIKadjPR
;              plots, [0.29,0.33], [0.88,0.88], COLOR=GV_COLR, /NORMAL, LINESTYLE=ST_LINE, thick=3*THIKadjGV
            ENDIF

            skipPDFs:   ; jumps to here if no PDF plot is to be done for this set of sources

         endif else begin   ; else for (havematch eq 1)
            print, " " + SfcType_str[SfcType_2get] + "    (No above-threshold points)"
            IF (do_ps EQ 1) THEN printf, tempunit, $
                " " + SfcType_str[SfcType_2get] + "    (No above-threshold points)"
         endelse
      ENDIF ELSE BEGIN      ; ELSE for num_over_SfcType[SfcType_2get] GT 0
         print, " " + SfcType_str[SfcType_2get] + "    (No data points)"
         IF (do_ps EQ 1) THEN printf, tempunit, $
                " " + SfcType_str[SfcType_2get] + "    (No data points)"
         xyouts, 0.6+xoff[SfcType_2get],0.75+yoff[SfcType_2get], SfcType_str[SfcType_2get] + $
                 ": NO POINTS", COLOR=255, /NORMAL, CHARSIZE=1.5
      ENDELSE

   endfor         ; SfcType_2get = 1,3
ENDFOR         ; isources = 0,1

print, '' & IF (do_ps EQ 1) THEN printf, tempunit, ''
print, '' & IF (do_ps EQ 1) THEN printf, tempunit, ''

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
IF var2 EQ 'GR' THEN secondString = ", TMI vs. " + siteID + STRING(CAPPI_height,  $
                                  FORMAT='(" on ",F0.1)') + " km CAPPI" $
                ELSE secondString = ", TMI vs. PR Surface Rain Rate"
SCATITLE = strmid( bname, 8, 17)+".V" + version + secondString + ", " + pctLabel

IF ( do_ps EQ 1 ) THEN BEGIN
   erase
   device,/inches,xoffset=0.25,yoffset=0.55,xsize=8.,ysize=10.,/portrait
   plot_scatter_by_sfc_type3x3_ps, PSFILEpdf, SCATITLE, var2id, sfcRain, gvrr, $
                                   rnTypePR, sfcCat, num4hist3, idx4hist3, $
                                   MIN_XY=0.5, MAX_XY=150.0, UNITS='mm/h'
ENDIF ELSE BEGIN
   plot_scatter_by_sfc_type3x3, SCATITLE, var2id, sfcRain, gvrr, rnTypePR, $
                                sfcCat, num4hist3, idx4hist3, windowsize, $
                                MIN_XY=0.5, MAX_XY=150.0, UNITS='mm/h'
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
                             yCorner, tmi_index, nfp, $
                             ifram+startelev, rntype4ppi, $
                             WINSIZ=windowsize, TITLE=prtitle, FIELD='RR' )
    CASE var2 OF
     'GR' : BEGIN
            gvtitle = mysite.site_ID+" rainrate, for " + pctLabelPPI
            mygvbuf = plot_sweep_2_zbuf( gvz_in2, mysite.site_lat, mysite.site_lon, xCorner, $
                             yCorner, tmi_index, nfp, $
                             ifram+startelev, rntype4ppi, $
                             WINSIZ=windowsize, TITLE=gvtitle, FIELD='RR' )
            END
     'PR' : BEGIN
            gvtitle = "PR V"+version+" Near-Surface rain rate at TMI resolution"
            mygvbuf = plot_sweep_2_zbuf( sfcrn_pr_in2, mysite.site_lat, mysite.site_lon, xCorner, $
                             yCorner, tmi_index, nfp, $
                             ifram+startelev, rntype4ppi, $
                             WINSIZ=windowsize, TITLE=gvtitle, FIELD='RR' )
            END
    ENDCASE
    IF ( PPIbyThresh ) THEN BEGIN
       prtitle = "TMI V"+version+", for " + pctLabelPPI
       myprbuf2 = plot_sweep_2_zbuf( rain3_in2, mysite.site_lat, mysite.site_lon, xCorner, $
                                 yCorner, tmi_index, nfp, $
                                 ifram+startelev, rntype4ppi, $
                                 WINSIZ=windowsize, TITLE=prtitle, FIELD='RR' )
       CASE var2 OF
        'PR' : BEGIN
               gvtitle = mysite.site_ID+" rainrate, for " + pctLabelPPI
               mygvbuf2 = plot_sweep_2_zbuf( gvz_in2, mysite.site_lat, mysite.site_lon, xCorner, $
                                 yCorner, tmi_index, nfp, $
                                 ifram+startelev, rntype4ppi, $
                                 WINSIZ=windowsize, TITLE=gvtitle, FIELD='RR' )
               END
        'GR' : BEGIN
               gvtitle = "PR V"+version+", for " + pctLabelPPI
               mygvbuf2 = plot_sweep_2_zbuf( sfcrn_pr_in2, mysite.site_lat, mysite.site_lon, xCorner, $
                             yCorner, tmi_index, nfp, $
                             ifram+startelev, rntype4ppi, $
                             WINSIZ=windowsize, TITLE=gvtitle, FIELD='RR' )
               END
       ENDCASE
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
; MODULE 1:  tmi2gr2pr_rainrate_comparisons
;
; DESCRIPTION
; -----------
; Driver for the gr2tmi2pr_rr_plots function (included).  Sets up user/default
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
;
; use_vpr       - Binary parameter.  If unset or 0, use the GR samples along the
;                 TMI line-of-sight.  If set, use the GR samples computed along
;                 the local vertical above the TMI surface footprint.
;
; plot_pct_by   - Specifies which parameter the GR percent-above-threshold
;                 histogram plots are categorized by.  Options are (S)urfaceType
;                 and (R)ainType.  Only the first character ('R' or 'S') is
;                 significant, and is not case-dependent.  Leaving the parameter
;                 unspecified, or specifying any other value than 'R' or 'S'
;                 disables the plot.  Plot is unaffected by the pctAbvThresh
;                 parameter value.
;
; CAPPI_idx      - Index of the height at which to compute scatter and PDFs of 
;                 rain rate, in terms of indices (zero-based) of elements in the
;                 'heights' array defined in the gr2tmi2pr_rr_plots() function,
;                 above.  If not specified, takes the value of "s" in the N.s
;                 number in the elevs2show parameter, or its default value of 0.
;
; heights       - Array of height values at which the rainrate profiles will be
;                 computed, and to which CAPPI_idx applies.
;
; radius        - Radius in km defining the area around a TMI footprint center
;                 within which to find and average GRtoPR matchup samples.
;
; gv_var        - Source of the rain rates which are compared to the TMI in the
;                 graphical portion of the output.  Valid values are 'PR', 'GR',
;                 or 'GV' (same affect as 'GR').  Default = 'GR'
;

pro tmi2gr2pr_rainrate_comparisons, SPEED=looprate, $
                                    ELEVS2SHOW=elevs2show, $
                                    NCPATH=ncpath, $
                                    SITE=sitefilter, $
                                    NO_PROMPT=no_prompt, $
                                    PPI_VERTICAL=ppi_vertical, $
                                    PPI_SIZE=ppi_size, $
                                    PCT_ABV_THRESH=pctAbvThresh, $
                                    SHOW_THRESH_PPI=show_thresh_ppi, $
                                    HIDE_TOTALS=hide_totals, $
                                    PS_DIR=ps_dir, $
                                    B_W=b_w, $
                                    USE_VPR=use_vpr, $
                                    PLOT_PCT_BY=plot_pct_by, $
                                    CAPPI_idx=CAPPI_idx, $
                                    HEIGHTS=heights, $
                                    RADIUS=radius, $
                                    GV_VAR=gv_var


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

nhgts2do = N_ELEMENTS(heights)
IF nhgts2do EQ 0 THEN $
; Define the list of fixed-height levels for the vertical profile statistics
heights = [1.5,3.0,4.5,6.0,7.5,9.0,10.5,12.0,13.5,15.0,16.5,18.0,19.5]
nhgts2do = N_ELEMENTS(heights)

IF ( N_ELEMENTS(CAPPI_idx) NE 1 ) THEN BEGIN
   CAPPI_idx = (2 LT (nhgts2do-1)) ? 2 : nhgts2do-1
   print, "Assigning default value for CAPPI_idx:", CAPPI_idx
ENDIF ELSE BEGIN
   IF CAPPI_idx GT (nhgts2do-1) THEN BEGIN
      print, "CAPPI_idx value: ", CAPPI_idx, $
             " exceeds max array index for heights array: ", nhgts2do-1
      CAPPI_idx = nhgts2do-1
      print, "Assigning default value for CAPPI_idx:", CAPPI_idx
   ENDIF
ENDELSE

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

IF ( N_ELEMENTS(radius) NE 1 ) THEN BEGIN
   print, "Defaulting to 7.0 km for TMI radius."
   radius = 7.0
ENDIF ELSE BEGIN
   IF radius LT 3.0 OR radius GT 20.0 THEN BEGIN
      print, "RADIUS parameter must be between 3.0 and 20.0, value is ", radius
      print, "Defaulting to 7.0 km for TMI radius."
      radius = 7.0
   ENDIF
ENDELSE

; Determine whether to plot TMI vs. GR or TMI vs. PR in the PDF/scatter plots
IF N_ELEMENTS( gv_var ) NE 1 THEN BEGIN
   var2 = 'GR'
ENDIF ELSE BEGIN
   gv_var = STRUPCASE(gv_var)
   CASE gv_var OF
        'PR' : var2 = gv_var
        'GR' : var2 = gv_var
        'GV' : var2 = 'GR'
        ELSE : BEGIN
               print, "Illegal value for GV_VAR, only PR, GR or GV are allowed."
               print, "Overriding GV_VAR to type GR"
               var2 = 'GR'
               END
   ENDCASE
ENDELSE

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
         gr2prfile = find_gr2pr4gr2tmi(pathpr, FILE_BASENAME(mygeomatchfile))
         IF gr2prfile EQ '' THEN break
         matchupStruct = matchup_prgr2tmigr_merged(mygeomatchfile, gr2prfile, heights, $
                                                   CAPPI_idx, radius, pctAbvThresh)
;stop
         szstruc = size(matchupStruct)
         sztype = szstruc[szstruc[0] + 1]
         IF sztype NE 8 THEN BEGIN   ; i.e., matchupStruct EQ "NO DATA"
            print, matchupStruct + " Error returned from matchup_prgr2tmigr(), exiting."
            break
         ENDIF
         action = 0
         action = gr2tmi2pr_rr_plots( mygeomatchfile, looprate, elevs2show, startelev, $
                                      PPIorient, ppi_size, pctAbvThresh, PPIbyThresh, $
                                      hideTotals, heights, CAPPI_idx, matchupStruct, $
                                      VAR2=var2, PS_DIR=ps_dir, B_W=b_w, $
                                      USE_VPR=use_vpr, PLOT_PCT_CAT=plot_pct_cat )
         if (action) then break
      endfor
   endelse
ENDIF ELSE BEGIN
   mygeomatchfile = dialog_pickfile(path=pathpr, filter = ncfilepatt)
   while mygeomatchfile ne '' do begin
      gr2prfile = find_gr2pr4gr2tmi(pathpr, FILE_BASENAME(mygeomatchfile))
      IF gr2prfile EQ '' THEN break
      matchupStruct = matchup_prgr2tmigr_merged(mygeomatchfile, gr2prfile, heights, $
                                                CAPPI_idx, radius, pctAbvThresh)
      szstruc = size(matchupStruct)
      sztype = szstruc[szstruc[0] + 1]
      IF sztype NE 8 THEN BEGIN   ; i.e., matchupStruct EQ "NO DATA"
         print, matchupStruct + " Error returned from matchup_prgr2tmigr(), exiting."
         break
      ENDIF
;stop
      action = 0
      action=gr2tmi2pr_rr_plots( mygeomatchfile, looprate, elevs2show, startelev, $
                                 PPIorient, ppi_size, pctAbvThresh, PPIbyThresh, $
                                 hideTotals, heights, CAPPI_idx, matchupStruct, $
                                 VAR2=var2, PS_DIR=ps_dir, B_W=b_w, $
                                 USE_VPR=use_vpr, PLOT_PCT_CAT=plot_pct_cat )
      if (action) then break
      mygeomatchfile = dialog_pickfile(path=pathpr, filter = ncfilepatt)
   endwhile
ENDELSE

print, "" & print, "Done!"

END
