;===============================================================================
;+
; Copyright © 2012, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; matchup_prgr2tmigr_merged.pro
;
; - Morris/SAIC/GPM_GV  October 2012
;
; DESCRIPTION
; -----------
; Performs a matchup of PR-GR volume-matched data in PR coordinates to lower-
; resolution volume-matched TMI-GR data in TMI coordinates.  That is, the data
; at PR horizontal resolution are resampled to a nominal TMI resolution.  The
; nominal TMI resolution is defined as a radius from the center of the TMI
; footprint, and is a user-specified parameter.  All PR-GR samples whose center
; lies within the defined radius around the TMI center are averaged to produce
; the matchup to the TMI-GR data.  The matching-up is done sweep-by-sweep on the
; GR elevation scan surfaces for the 3-D variables, and at the earth surface for
; the single-level variables.  PR rain type is matched by computing the
; number of in-radius PR footprints mapped to each TMI footprint, and the
; numbers of these footprints having PR rain type "convective and "stratiform".
;
; Only those TMI footprints which lie within the PR/GR overlap area are matched.
; The matched-up PR-GR and TMI-GR data are returned in a structure containing
; the averaged/processed PR-GR data fields; and the full set of TMI-GR volume-
; match variables, spatially subsetted to the PR/GR overlap area.  The PR-GR
; variables matched up to TMI include:
;
; - Number of PR footprints matched to each TMI footprint, at each sweep level (numPR3d)
; - GR reflectivity from the PR-GR volume-match data, on the sweep levels (gvz)
; - PR attenuation-corrected reflectivity from the PR-GR volume-match data,
;   on the sweep levels (zcor)
; - PR 3-D rain rate from the PR-GR volume-match data, on the sweep levels (rain3)
; - Mean Percent Above Threshold for PR zcor (pctgoodpr)
; - Mean Percent Above Threshold for GR gvz (pctgoodgv)
; - PR near-surface rain rate (nearSurfRain)
; - Number of PR footprints matched to each TMI footprint, at the surface (numPRsfc)
; - Number of above footprints of PR rain type Convective (rnTypeConv)
; - Ditto, Stratiform rain type (rnTypeStrat)
; - Ditto, but number indicating PR rain certain (rnCertain)
; 
;
; INTERNAL MODULES
; ----------------
; 1) matchup_prgr2tmigr_merged - Main procedure called by user.
;
; 2) compute_averages - Computes averages of array data, with options to set
;                       negative values to 0 or ignore negative values.
;
; HISTORY
; -------
; 10/23/2012 Morris, GPM GV, SAIC
; - Created.
;
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;===============================================================================

; MODULE 1:  compute_averages

FUNCTION compute_averages, values, NEGSTOZERO=negsToZero

; Compute average of array elements included in "values" array.  If keyword
; NEGSTOZERO is set, then set all negative values to 0.0, and average over all
; values.  If not set, then only average the non-negative values (if any), or
; just return the first element of "values" array as the average.

negsToZero = KEYWORD_SET(negsToZero)
IF negsToZero THEN BEGIN
   idxNegs = WHERE( values LT 0.0, countnegs)
   IF countnegs GT 0 THEN values[idxNegs] = 0.0
   meanval = MEAN(values)
ENDIF ELSE BEGIN
   idx2do = WHERE( values GE 0.0, count2do)
   IF count2do GT 0 THEN meanval = MEAN(values[idx2do]) ELSE meanval = values[0]
ENDELSE

return, meanval
end

;===============================================================================

; MODULE 2:  matchup_prgr2tmigr_merged

FUNCTION matchup_prgr2tmigr_merged, gr2tmifile, gr2prfile, heights, CAPPI_idx, $
                                    radius, pctAbvThresh

; "include" file for PR data constants
@pr_params.inc

bname = file_basename( gr2tmifile )
prlen = strlen( bname )
pctString = STRTRIM(STRING(FIX(pctabvthresh)),2)
parsed = STRSPLIT( bname, '.', /extract )
site = parsed[1]
yymmdd = parsed[2]
orbit = parsed[3]
version = parsed[4]

bbparms = {meanBB : 4.0, BB_HgtLo : -99, BB_HgtHi : -99}
RRcut = 0.1 ;10.      ; TMI/GV rainrate lower cutoff of points to use in mean diff. calcs.
rangecut = 100.

CAPPI_height = heights[CAPPI_idx]
print, ""
print, "CAPPI level (km): ", CAPPI_height
print, ""

;----------------------------------------------------------------------------------------

; READ THE TMI MATCHUP FILE

cpstatus = uncomp_file( gr2tmifile, tmi_file )
if(cpstatus eq 'OK') then begin
  status = 1   ; init to FAILED
  tmi_geometa = get_geo_match_nc_struct( 'matchup' )
  tmi_sweeps = get_geo_match_nc_struct( 'sweeps' )
  tmi_site = get_geo_match_nc_struct( 'site' )
  tmi_flags = get_geo_match_nc_struct( 'fields_tmi' )
  tmi_files =  get_geo_match_nc_struct( 'files' )
  status = read_tmi_geo_match_netcdf( tmi_file, matchupmeta=tmi_geometa, $
     sweepsmeta=tmi_sweeps, sitemeta=tmi_site, fieldflags=tmi_flags, filesmeta=tmi_files )

 ; create data field arrays of correct dimensions and read data fields
  nfp = tmi_geometa.num_footprints
  nswp = tmi_geometa.num_sweeps

 ; define index array into the sweeps-level arrays
  tmi_data3_idx = indgen(nfp, nswp)

  tmi_gvexp=intarr(nfp, nswp)
  tmi_gvrej=intarr(nfp, nswp)
  tmi_gvexp_vpr=tmi_gvexp
  tmi_gvrej_vpr=tmi_gvrej
  tmi_gvz=fltarr(nfp, nswp)
  tmi_gvzmax=fltarr(nfp, nswp)
  tmi_gvzstddev=fltarr(nfp, nswp)
  tmi_gvz_vpr=fltarr(nfp, nswp)
  tmi_gvzmax_vpr=fltarr(nfp, nswp)
  tmi_gvzstddev_vpr=fltarr(nfp, nswp)
  tmi_top=fltarr(nfp, nswp)
  tmi_botm=fltarr(nfp, nswp)
  tmi_top_vpr=tmi_top
  tmi_botm_vpr=tmi_botm
  tmi_xcorner=fltarr(4,nfp,nswp)
  tmi_ycorner=fltarr(4,nfp,nswp)
  tmi_lat=fltarr(nfp, nswp)
  tmi_lon=fltarr(nfp, nswp)
  tmi_sfclat=fltarr(nfp)
  tmi_sfclon=fltarr(nfp)
  tmi_sfctyp=intarr(nfp)
  tmi_sfcrain=fltarr(nfp)
  tmi_rnflag=intarr(nfp)
  tmi_dataflag=intarr(nfp)
  IF ( tmi_geometa.tmi_version EQ 7 ) THEN PoP=intarr(nfp)   ; only has data if V7
  tmi_index=lonarr(nfp)

  status = read_tmi_geo_match_netcdf( tmi_file, $
    grexpect_int=tmi_gvexp, grreject_int=tmi_gvrej, $
    grexpect_vpr_int=tmi_gvexp_vpr, grreject_vpr_int=tmi_gvrej_vpr, $
    dbzgv_viewed=tmi_gvz, dbzgv_vpr=tmi_gvz_vpr, $
    gvStdDev_viewed=tmi_gvzstddev, gvMax_viewed=tmi_gvzmax, $
    gvStdDev_vpr=tmi_gvzstddev_vpr, gvMax_vpr=tmi_gvzmax_vpr, $
    topHeight_viewed=tmi_top, bottomHeight_viewed=tmi_botm, $
    xCorners=tmi_xCorner, yCorners=tmi_yCorner, $
    latitude=tmi_lat, longitude=tmi_lon, $
    topHeight_vpr=tmi_top_vpr, bottomHeight_vpr=tmi_botm_vpr,           $
    TMIlatitude=tmi_sfclat, TMIlongitude=tmi_sfclon, $
    surfaceRain=tmi_sfcrain, sfctype_int=tmi_sfctyp, rainflag_int=tmi_rnFlag, $
    dataflag_int=tmi_dataFlag, PoP_int=PoP, tmi_idx_long=tmi_index )

  command3 = "rm  -v " + tmi_file
  spawn, command3
endif else begin
  print, 'Cannot copy/unzip TMI geo_match netCDF file: ', gr2tmifile
  print, cpstatus
  command3 = "rm  -v " + tmi_file
  spawn, command3
  goto, errorExit
endelse

IF (status EQ 1) THEN GOTO, errorExit

IF ( tmi_geometa.tmi_version EQ 7 ) THEN BEGIN
   ; fix the early matchup files, restore PoP "Missing value"
   idxpopmiss = WHERE( PoP GT 100, npopmiss )
   IF npopmiss GT 0 THEN PoP[idxpopmiss] = -99  
   idxpopok = WHERE( PoP GE 50, countpopok )
   idxtmirain = WHERE( tmi_sfcrain GE RRcut, nsfcrainy )
   print, countpopok, nsfcrainy, N_ELEMENTS(PoP), $
         FORMAT='("# PoP footprints GE 50% = ", I0, ", # TMI rainy: ", I0, ",  # footprints = ", I0)'
;   print, PoP
ENDIF

; READ THE PR MATCHUP DATA FILE

; set up pointers for each field to be returned from fprep_geo_match_profiles()
; -- we have commented-out those we don't currently need for this application

ptr_geometa=ptr_new(/allocate_heap)
ptr_sweepmeta=ptr_new(/allocate_heap)
ptr_sitemeta=ptr_new(/allocate_heap)
;ptr_filesmeta=ptr_new(/allocate_heap)
;ptr_fieldflags=ptr_new(/allocate_heap)
ptr_gvz=ptr_new(/allocate_heap)
;ptr_gvzmax=ptr_new(/allocate_heap)
;ptr_gvzstddev=ptr_new(/allocate_heap)
ptr_zcor=ptr_new(/allocate_heap)
;ptr_zraw=ptr_new(/allocate_heap)
ptr_rain3=ptr_new(/allocate_heap)
;ptr_top=ptr_new(/allocate_heap)
;ptr_botm=ptr_new(/allocate_heap)
ptr_lat=ptr_new(/allocate_heap)
ptr_lon=ptr_new(/allocate_heap)
ptr_pr_lat=ptr_new(/allocate_heap)
ptr_pr_lon=ptr_new(/allocate_heap)
ptr_nearSurfRain=ptr_new(/allocate_heap)
ptr_nearSurfRain_2b31=ptr_new(/allocate_heap)
ptr_rnFlag=ptr_new(/allocate_heap)
ptr_rnType=ptr_new(/allocate_heap)
;ptr_landOcean=ptr_new(/allocate_heap)
ptr_bbHeight=ptr_new(/allocate_heap)
;ptr_bbstatus=ptr_new(/allocate_heap)
;ptr_status_2a23=ptr_new(/allocate_heap)
ptr_pr_index=ptr_new(/allocate_heap)
;ptr_xCorner=ptr_new(/allocate_heap)
;ptr_yCorner=ptr_new(/allocate_heap)
;ptr_bbProx=ptr_new(/allocate_heap)
;ptr_hgtcat=ptr_new(/allocate_heap)
;ptr_dist=ptr_new(/allocate_heap)
IF ( N_ELEMENTS(pctAbvThresh) EQ 1 ) THEN BEGIN
   ptr_pctgoodpr=ptr_new(/allocate_heap)
   ptr_pctgoodgv=ptr_new(/allocate_heap)
   ptr_pctgoodrain=ptr_new(/allocate_heap)
ENDIF


; read the geometry-match variables and arrays from the file, and preprocess them
; to remove the 'bogus' PR ray positions.  Return a pointer to each variable read.

status = fprep_geo_match_profiles( gr2prfile, heights, $
            PCT_ABV_THRESH=pctAbvThresh, GV_CONVECTIVE=0, GV_STRATIFORM=0, $
            PTRfieldflags=ptr_fieldflags, PTRgeometa=ptr_geometa, $
            PTRsweepmeta=ptr_sweepmeta, PTRsitemeta=ptr_sitemeta, $
            PTRfilesmeta=ptr_filesmeta, $
            PTRzcor=ptr_zcor, PTRzraw=ptr_zraw, PTRrain3d=ptr_rain3, $
            PTRGVZ=ptr_gvz, PTRGVMAX=ptr_gvzmax, PTRGVSTDDEV=ptr_gvzstddev, $
            PTRtop=ptr_top, PTRbotm=ptr_botm, PTRlat=ptr_lat, PTRlon=ptr_lon, $
            PTRprlat=ptr_pr_lat, PTRprlon=ptr_pr_lon, $
            PTRsfcrainpr=ptr_nearSurfRain, PTRsfcraincomb=ptr_nearSurfRain_2b31, $
            PTRrainflag_int=ptr_rnFlag, PTRraintype_int=ptr_rnType, $
            PTRlandOcean_int=ptr_landOcean, PTRpridx_long=ptr_pr_index, $
            PTRbbHgt=ptr_bbHeight, PTRbbStatus=ptr_bbstatus, PTRstatus2A23=ptr_status_2a23, $
            PTRxCorners=ptr_xCorner, PTRyCorners=ptr_yCorner, $
            PTRbbProx=ptr_bbProx, PTRhgtcat=ptr_hgtcat, PTRdist=ptr_dist, $
            PTRpctgoodpr=ptr_pctgoodpr, PTRpctgoodgv=ptr_pctgoodgv, $
            PTRpctgoodrain=ptr_pctgoodrain, $
            BBPARMS=BBparms, BBWIDTH=bbwidth )

IF (status EQ 1) THEN GOTO, errorExit

; create local data field arrays/structures needed here, and free pointers we
; no longer need to free the memory held by these pointer variables

  mygeometa=*ptr_geometa
  mysite=*ptr_sitemeta
  mysweeps=*ptr_sweepmeta
;  myflags=*ptr_fieldflags
;  filesmeta=*ptr_filesmeta
  gvz=*ptr_gvz
;  gvz_in = gvz     ; for plotting as PPI
;  gvzmax=*ptr_gvzmax
;  gvzstddev=*ptr_gvzstddev
  zcor=*ptr_zcor
;  zcor_in = zcor   ; for plotting as PPI
;  zraw=*ptr_zraw
  rain3=*ptr_rain3
;  top=*ptr_top
;  botm=*ptr_botm
  lat=*ptr_lat
  lon=*ptr_lon
  pr_lat=*ptr_pr_lat
  pr_lon=*ptr_pr_lon
  nearSurfRain=*ptr_nearSurfRain
  nearSurfRain_2b31=*ptr_nearSurfRain_2b31
  rnflag=*ptr_rnFlag
  rntype=*ptr_rnType
;  landOceanFlag=*ptr_landOcean
  bbHeight=*ptr_bbHeight
;  bbstatus=*ptr_bbstatus
;  status_2a23=*ptr_status_2a23
  pr_index=*ptr_pr_index
;  xcorner=*ptr_xCorner
;  ycorner=*ptr_yCorner
;  bbProx=*ptr_bbProx
;  hgtcat=*ptr_hgtcat
;  dist=*ptr_dist
  IF ( N_ELEMENTS(pctAbvThresh) EQ 1 ) THEN BEGIN
     pctgoodpr=*ptr_pctgoodpr
       ptr_free,ptr_pctgoodpr
     pctgoodgv=*ptr_pctgoodgv
       ptr_free,ptr_pctgoodgv
     pctgoodrain=*ptr_pctgoodrain
       ptr_free,ptr_pctgoodrain
  ENDIF
    ptr_free,ptr_geometa
    ptr_free,ptr_sitemeta
    ptr_free,ptr_sweepmeta
;    ptr_free,ptr_fieldflags
;    ptr_free,ptr_filesmeta
    ptr_free,ptr_gvz
;    ptr_free,ptr_gvzmax
;    ptr_free,ptr_gvzstddev
    ptr_free,ptr_zcor
;    ptr_free,ptr_zraw
    ptr_free,ptr_rain3
;    ptr_free,ptr_top
;    ptr_free,ptr_botm
    ptr_free,ptr_lat
    ptr_free,ptr_lon
    ptr_free,ptr_pr_lat
    ptr_free,ptr_pr_lon
    ptr_free,ptr_nearSurfRain
    ptr_free,ptr_nearSurfRain_2b31
    ptr_free,ptr_rnFlag
    ptr_free,ptr_rnType
;    ptr_free,ptr_landOcean
    ptr_free,ptr_bbHeight
;    ptr_free,ptr_bbstatus
;    ptr_free,ptr_status_2a23
    ptr_free,ptr_pr_index
;    ptr_free,ptr_xCorner
;    ptr_free,ptr_yCorner
;    ptr_free,ptr_bbProx
;    ptr_free,ptr_hgtcat
;    ptr_free,ptr_dist

;----------------------------------------------------------------------------------------

pr_nfp = mygeometa.num_footprints
pr_nswp = mygeometa.num_sweeps
site_lat = mysite.site_lat
site_lon = mysite.site_lon
siteID = string(mysite.site_id)
nsweeps = mygeometa.num_sweeps

IF nswp NE pr_nswp THEN BEGIN
   print, "Number of sweeps different between TMI and PR matchups! Exiting with error."
   goto, errorExit
ENDIF
; blank out reflectivity for samples not meeting 'percent complete' threshold

IF ( pctAbvThresh GT 0.0 ) THEN BEGIN
  ; clip to the 'good' points, where 'pctAbvThresh' fraction of bins in average
  ; were above threshold
   idxgoodenuff = WHERE( pctgoodpr GE pctAbvThresh $
                    AND  pctgoodgv GE pctAbvThresh, countgoodpct )
   IF ( countgoodpct GT 0 ) THEN BEGIN
      ;idxgoodenuff = idxexpgt0[idxgoodpct]
      ;idx2plot=idxgoodenuff
      n2plot=countgoodpct
   ENDIF ELSE BEGIN
      print, "No complete-volume points based on PctAbvThresh, quitting case."
      goto, errorExit
   ENDELSE
  ; blank out reflectivity for all samples not meeting completeness thresholds
   idx3d = pr_index      ; just for creation/sizing
   idx3d[*,*] = 0L       ; initialize all points to 0 (blank-out flag)
   idx3d[idxgoodenuff] = 2L  ; points to keep
   idx2blank = WHERE( idx3d EQ 0L, count2blank )
   IF ( count2blank GT 0 ) THEN BEGIN
     gvz[idx2blank] = 0.0
     zcor[idx2blank] = 0.0
   ENDIF
ENDIF

; - - - - - - - - - - - - - - - - - - - - - - - -

; initialize a GR-centered map projection for the ll<->xy transformations:
sMap = MAP_PROJ_INIT( 'Azimuthal Equidistant', center_latitude=site_Lat, $
                       center_longitude=site_Lon )

; compute the PR sweep-level footprint x,y coordinates
XY_km = map_proj_forward( lon, lat, map_structure=smap ) / 1000.
pr_x = REFORM( XY_km[0,*], pr_nfp,pr_nswp )
pr_y = REFORM( XY_km[1,*], pr_nfp,pr_nswp )

; ditto, but for the PR surface footprint location.  Must extract one sweep
; level from the array returned by fprep_geo_match_profiles
pr_lat0 = REFORM(pr_lat[*,0])
pr_lon0 = REFORM(pr_lon[*,0])
XY_km = map_proj_forward( pr_lon0, pr_lat0, map_structure=smap ) / 1000.
pr_x0 = REFORM( XY_km[0,*] )
pr_y0 = REFORM( XY_km[1,*] )

; compute the TMI surface x,y coordinates and distances from GR
XY_km = map_proj_forward( tmi_sfclon, tmi_sfclat, map_structure=smap ) / 1000.
tmi_x0 = REFORM( XY_km[0,*] )
tmi_y0 = REFORM( XY_km[1,*] )
tmi_dist_sfc = SQRT(tmi_x0^2 + tmi_y0^2)

; compute the TMI along-ray, sweep-level x,y coordinates
XY_km = map_proj_forward( tmi_lon, tmi_lat, map_structure=smap ) / 1000.
tmi_x = REFORM( XY_km[0,*], nfp,nswp )
tmi_y = REFORM( XY_km[1,*], nfp,nswp )
tmi_dist_3d = SQRT(tmi_x^2 + tmi_y^2)

; Define LUT arrays of a size such that each PR footprint can match to up to
; "maxPRfp" TMI footprints. Each position in the following six LUT arrays holds
; the index of the sweep level (-1 for the at-surface level, -99 fill value), the
; TMI_index of a TMI footprint, the PR_index of a PR footprint within 'radius'
; km of this TMI footprint, the PR-TMI distance, the array position index of
; the matching samples in the GRtoPR data arrays, and the array position index of
; the matching samples in the GRtoTMI data arrays.  LUT == Look-Up Table

; first, need upper limit on how many PR footprints in a circle of 'radius' km,
; using a PR nominal sample spacing of 4.3 km along/between scans
maxPRfp = FIX( (radius*2)/4.3 )^2 > 4
; how many PR footprints, times how many TMI each maps to, is LUT size estimate
max_LUT_pairs = LONG(pr_nfp) * LONG(pr_nswp+1) * maxPRfp
n_LUT_in_layer = LONARR(pr_nswp+1)
sweep_idxLUT = MAKE_ARRAY( max_LUT_pairs, /INTEGER, VALUE=-99 )  ; LUT 1
tmi_indexLUT = LONARR(max_LUT_pairs)   ; LUT 2, 2A-12 product-relative array index
pr_indexLUT = LONARR(max_LUT_pairs)    ; LUT 3, 2A-25 product-relative array index
pr2tmi_dist = FLTARR(max_LUT_pairs)    ; LUT 4
grtoprLUT = LONARR(max_LUT_pairs)      ; LUT 5, GRtoPR matchup file 3-d array index
grtotmiLUT = LONARR(max_LUT_pairs)     ; LUT 6, GRtoTMI matchup file 3-d array index
nextLUTpos = 0L    ; array position to begin writing the PR-TMI matchup pairs to
n_LUT_values = 0L  ; cumulative number of pairings written to LUT arrays
n_this_layer = 0L  ; number of pairings written to LUT arrays for this layer/level

; compute the locations of PR footprints within 'radius' km of each TMI footprint
; -- earth-surface locations first

for tfoot = 0, nfp-1 do begin
   ; compute distance of all PR surface footprints from this TMI sfc footprint,
   ; using surface x,y arrays
   tmiprdist0 = SQRT((pr_x0 - tmi_x0[tfoot])^2 + (pr_y0 - tmi_y0[tfoot])^2)
   ; find the PR locations within the specified radius around the TMI footprint
   idxin14 = WHERE( tmiprdist0 LE radius, countin14 )
   IF countin14 GT 0 THEN BEGIN
      IF (countin14+n_LUT_values) GT max_LUT_pairs THEN BEGIN
         ; probably should just extend the arrays, but bail out for now
         print, "Dang, too many surface LUT pairings for sized arrays."
         goto, errorExit
      ENDIF
      ; write the various indexes and distances to the LUT arrays
      lastLUTpos = nextLUTpos+countin14-1
      ; -- write scalars to LUT arrays 'countin14' times
      sweep_idxLUT[nextLUTpos:lastLUTpos] = -1  ; indicator for at-surface level, not on a sweep
      tmi_indexLUT[nextLUTpos:lastLUTpos] = tmi_index[tfoot]
      grtotmiLUT[nextLUTpos:lastLUTpos] = tfoot
      ; -- write subarrays to LUT arrays starting at nextLUTpos
      pr_indexLUT[nextLUTpos] = pr_index[idxin14]
      pr2tmi_dist[nextLUTpos] = tmiprdist0[idxin14]
      grtoprLUT[nextLUTpos] = idxin14
      nextLUTpos = lastLUTpos+1
      n_LUT_values = n_LUT_values + countin14
      n_this_layer = n_this_layer + countin14
   ENDIF ;ELSE print, "No PR points mapped to TMI sample at range of ", $
          ;              SQRT( tmi_x0[tfoot]^2+tmi_y0[tfoot]^2 ), $
          ;              " TMI lat/lon of ", tmi_sfclat[tfoot], tmi_sfclon[tfoot]
endfor

;print, 'finished 1d matchups'
n_LUT_in_layer[0] = n_LUT_values

;help, n_LUT_values , tmi_indexLUT, pr_indexLUT, pr2tmi_dist
;stop

; -- now do the 3-d sample matchups, sweep by sweep

for sweepidx = 0, nswp-1 do begin
   n_this_layer = 0L  ; number of pairings written to LUT arrays for this layer/level
   for tfoot = 0, nfp-1 do begin
      ; compute the PR footprint distances from this TMI footprint, using x,y
      ; values on this sweep surface
      tmiprdist = SQRT( ( pr_x[*,sweepidx] - tmi_x[tfoot,sweepidx] )^2 $
                      + ( pr_y[*,sweepidx] - tmi_y[tfoot,sweepidx] )^2 )
      idxin14 = WHERE( tmiprdist LE radius, countin14 )
      IF countin14 GT 0 THEN BEGIN
         IF (countin14 + n_LUT_values) GT max_LUT_pairs THEN BEGIN
            print, "Dang, too many on-sweep LUT pairings for sized arrays."
            goto, errorExit
         ENDIF
         ; write the indexes and distances to the LUT arrays
         lastLUTpos = nextLUTpos+countin14-1
         ; -- write scalars to array 'countin14' times
         sweep_idxLUT[nextLUTpos:lastLUTpos] = sweepidx  ; indicator for sweep level
         tmi_indexLUT[nextLUTpos:lastLUTpos] = tmi_index[tfoot]
         grtotmiLUT[nextLUTpos:lastLUTpos] = tmi_data3_idx[tfoot, sweepidx] ;tfoot + sweepidx * LONG(nfp)
         ; -- write subarrays to LUT arrays starting at nextLUTpos
         pr_indexLUT[nextLUTpos] = pr_index[idxin14]
         pr2tmi_dist[nextLUTpos] = tmiprdist[idxin14]
         grtoprLUT[nextLUTpos] = idxin14

         nextLUTpos = lastLUTpos+1
         n_LUT_values = n_LUT_values + countin14
         n_this_layer = n_this_layer + countin14
      ENDIF ;ELSE print, "No PR points mapped to TMI sample at range of ", $
             ;           SQRT( tmi_x[tfoot,sweepidx]^2+tmi_y[tfoot,sweepidx]^2 ), $
              ;          " TMI lat/lon of ", tmi_lat[tfoot,sweepidx], tmi_lon[tfoot,sweepidx], $
               ;         " TMI_index, sweep# of ", tmi_index[tfoot], sweepidx
   endfor
   n_LUT_in_layer[sweepidx+1] = n_this_layer
   ;print, "Did ", n_this_layer, " points in PPI level", sweepidx
endfor

;help, n_LUT_values , tmi_indexLUT, pr_indexLUT, pr2tmi_dist, site_lat, site_lon

; pare down the LUT arrays to the actual number of matchup points
sweep_idxLUTall = sweep_idxLUT[0:n_LUT_values-1]
tmi_indexLUTall = tmi_indexLUT[0:n_LUT_values-1]
grtotmiLUTall = grtotmiLUT[0:n_LUT_values-1] ; tmi_data3_idx[0:n_LUT_values-1]
pr_indexLUTall = pr_indexLUT[0:n_LUT_values-1]
pr2tmi_distLUTall = pr2tmi_dist[0:n_LUT_values-1]
grtoprLUTall = grtoprLUT[0:n_LUT_values-1]

; THIS WOULD BE THE PLACE TO SAVE THE LUT ARRAYS ABOVE IN A FILE FOR RE-USE

; "free" the original LUT memory
sweep_idxLUT = 0
tmi_indexLUT = 0
pr_indexLUT = 0
pr2tmi_dist = 0
grtoprLUT = 0
grtotmiLUT = 0

;-----------------------------------------------------

; assign output array of TMI index at sfc level
; -- unique list of TMI_index for this matchup:
TMIidxSfcOut = tmi_indexLUTall[UNIQ(tmi_indexLUTall,SORT(tmi_indexLUTall))]
numTMIsfcOut = N_ELEMENTS(TMIidxSfcOut)  ; how many TMI samples have matching PR, at sfc

; define the other output arrays/values

nsampout = N_ELEMENTS(TMIidxSfcOut)       ; how many averaged values to output at each level
GRtoTMIidxSfcOut = LONARR(nsampout)       ; define output array of GRtoTMI matchup data index, at sfc
GRtoTMIidxSfcOut[*] = -99                 ; initialize data index to MISSING
TMIidx3dOut = LONARR(nsampout,nswp)       ; define output array of TMI index on sweeps
TMIidx3dOut[*,*] = -99                    ; initialize TMI_index to MISSING
GRtoTMIidx3dOut = LONARR(nsampout,nswp)   ; define output array of GRtoTMI matchup data index on sweeps
GRtoTMIidx3dOut[*,*] = -99                ; initialize GRtoTMI index to MISSING
;numTMIsfcOut = 0                          ; how many TMI samples have matching PR, at sfc
numTMI3dOut = INTARR(nswp)                ; how many TMI samples have matching PR, on sweep surfaces
numPRsfcOut = INTARR(nsampout)            ; how many PR samples map to the TMI sample, at sfc
numPR3dOut = INTARR(nsampout,nswp)        ; ditto, on sweep surfaces
zcor3dOut = FLTARR(nsampout,nswp)         ; define output array of mean PR Zcor on sweeps
grz3dOut = FLTARR(nsampout,nswp)          ; define output array of mean GR Z on sweeps
rain3dOut = FLTARR(nsampout,nswp)         ; define output array of mean PR rainrate on sweeps
rainPRsfcOut  = FLTARR(nsampout)          ; define output array of mean PR surface rainrate
numRaintypeStratOut = INTARR(nsampout)    ; define output array of # of Stratiform PR rain type
numRaintypeConvOut = INTARR(nsampout)     ; define output array of # of Convective PR rain type
numRainCertainOut = INTARR(nsampout)      ; define output array of # of Convective PR rain type
pctgoodPRout = FLTARR(nsampout,nswp)      ; define output array of mean PR pct abv thresh on sweeps
pctgoodGRout = FLTARR(nsampout,nswp)      ; define output array of mean GR pct abv thresh on sweeps
meanBBhgtOut = FLTARR(nsampout)           ; define output array of mean PR BB height for sample

pr_index_1_level = REFORM(pr_index[*,0])          ; cut out one level, for later position matches
rain_flag_one_level = REFORM(rnflag[*,0]) AND 2b  ; cut out one level, and ID 2A25 rain certain bit

; compute the PRtoGR sample averages for each TMI sample, level by level

for sweepidx = -1, nswp-1 do begin
   ntmi = 0
   ; grab the indices of the LUT elements at this level
   idxThisSwp = WHERE(sweep_idxLUTall EQ sweepidx)
   for itmi = 0, numTMIsfcOut-1 do begin
      tmiIdx = TMIidxSfcOut[itmi]
      ; get the indices of all LUT elements at this level mapped to this TMI index
      tmiset = WHERE(tmi_indexLUTall[idxThisSwp] EQ tmiIdx, counttmiset)
      IF counttmiset GT 0 THEN BEGIN
         ; identify the GRtoPR data index values that map to this TMI_index, for this level
         grtopridx4tmi = grtoprLUTall[idxThisSwp[tmiset]]
         IF sweepidx EQ -1 THEN BEGIN
            ; evaluate the surface-level PR elements
            idxprsfc = pr_index_1_level[grtopridx4tmi]
            idxprsfcByLUT = pr_indexLUTall[idxThisSwp[tmiset]]
            if TOTAL(idxprsfc NE idxprsfcByLUT) NE 0 THEN PRINT, "mismatched PR_index values!" ; $
;            else print, "TMI_index, matching PR_index: ", tmiIdx, idxprsfc

            ; all the GRtoTMI-relative indices should be the same for this set of LUT elements, 
            ; (i.e., for this TMI_index) so grab the first one
            GRtoTMIidxSfcOut[itmi] = grtotmiLUTall[idxThisSwp[tmiset[0]]]

            numPRsfcOut[itmi] = N_ELEMENTS(grtopridx4tmi)   ; number of PR samples to average
            rainPRsfc2do = nearSurfRain[grtopridx4tmi]      ; grab sfc rain samples to average
            rainPRsfcOut[itmi] = compute_averages( rainPRsfc2do, NEGSTOZERO=1 )
            idxprstrat = WHERE(rnType[grtopridx4tmi] EQ 1, counttemp)
            numRaintypeStratOut[itmi] = counttemp
            idxprconv = WHERE(rnType[grtopridx4tmi] EQ 2, counttemp)
            numRaintypeConvOut[itmi] = counttemp
            idxprraining = WHERE(rain_flag_one_level[grtopridx4tmi] EQ 2, counttemp)
            numRainCertainOut[itmi] = counttemp
            meanBBhgtOut[itmi] = compute_averages( bbHeight[grtopridx4tmi] )
         ENDIF ELSE BEGIN
            ; evaluate the sweeps-level PR elements
            TMIidx3dOut[itmi,sweepidx] = tmiIdx     ; tally the TMI_index value for this level
            indexOffset = sweepidx * LONG(pr_nfp)   ; offset to GRtoPR positions for current sweep
            idxprlvl = pr_index_1_level[grtopridx4tmi]
            grtopridx4tmi2 = grtopridx4tmi + indexOffset
            idxprlvl2 = pr_index[grtopridx4tmi2]
            idxprlvlByLUT = pr_indexLUTall[idxThisSwp[tmiset]]
            if TOTAL(idxprlvl NE idxprlvl2) NE 0 THEN PRINT, "mismatched 3-d PR_index values (1)!" ; $
            if TOTAL(idxprlvl NE idxprlvlByLUT) NE 0 THEN PRINT, "mismatched 3-d PR_index values (2)!"

            ; all the GRtoTMI-relative indices should be the same for this set of LUT elements, 
            ; (i.e., for this TMI_index) so grab the first one
            GRtoTMIidx3dOut[itmi,sweepidx] = grtotmiLUTall[idxThisSwp[tmiset[0]]]

            numPR3dOut[itmi,sweepidx] = N_ELEMENTS(grtopridx4tmi)
            zcor3dOut[itmi,sweepidx] = compute_averages( zcor[grtopridx4tmi2], NEGSTOZERO=1 )
            grz3dOut[itmi,sweepidx] = compute_averages( gvz[grtopridx4tmi2], NEGSTOZERO=1 )
            rain3dOut[itmi,sweepidx] = compute_averages( rain3[grtopridx4tmi2], NEGSTOZERO=1 )
            pctgoodPRout[itmi,sweepidx] = compute_averages( pctgoodPR[grtopridx4tmi2], NEGSTOZERO=1 )
            pctgoodGRout[itmi,sweepidx] = compute_averages( pctgoodGV[grtopridx4tmi2], NEGSTOZERO=1 )

         ENDELSE
         ntmi++
      ENDIF ELSE BEGIN
         ; just tag the TMI indices
         IF sweepidx EQ -1 THEN BEGIN
            GRtoTMIidxSfcOut[itmi] = tmi_data3_idx[itmi]
            numPRsfcOut[itmi] = 0
            rainPRsfcOut[itmi] = -99.
            numRaintypeStratOut[itmi] = -99
            numRaintypeConvOut[itmi] = -99
            numRainCertainOut[itmi] = -99
            meanBBhgtOut[itmi] = -99.
         ENDIF ELSE BEGIN
            ; evaluate the sweeps-level PR elements
            TMIidx3dOut[itmi,sweepidx] = tmiIdx     ; tally the TMI_index value for this level
            GRtoTMIidx3dOut[itmi,sweepidx] = tmi_data3_idx[itmi, sweepidx]
            numPR3dOut[itmi,sweepidx] = 0
            zcor3dOut[itmi,sweepidx] = -99.
            grz3dOut[itmi,sweepidx] = -99.
            rain3dOut[itmi,sweepidx] = -99.
            pctgoodPRout[itmi,sweepidx] = -99
            pctgoodGRout[itmi,sweepidx] = -99
         ENDELSE
      ENDELSE
   endfor ;each
   IF sweepidx NE -1 THEN numTMI3dOut[sweepidx] = ntmi
endfor

;-------------------------------------------------

; pare the TMI arrays down to the samples with matching PR data

  tmi_geometa.num_footprints = nsampout

  tmi_gvexp = REFORM( tmi_gvexp[GRtoTMIidx3dOut], nsampout, nswp)
  tmi_gvrej = REFORM( tmi_gvrej[GRtoTMIidx3dOut], nsampout, nswp)
  tmi_gvexp_vpr = tmi_gvexp
  tmi_gvrej_vpr = tmi_gvrej
  tmi_gvz = REFORM( tmi_gvz[GRtoTMIidx3dOut], nsampout, nswp)
  tmi_gvzmax = REFORM( tmi_gvzmax[GRtoTMIidx3dOut], nsampout, nswp)
  tmi_gvzstddev = REFORM( tmi_gvzstddev[GRtoTMIidx3dOut], nsampout, nswp)
  tmi_gvz_vpr = REFORM( tmi_gvz_vpr[GRtoTMIidx3dOut], nsampout, nswp)
  tmi_gvzmax_vpr = REFORM( tmi_gvzmax_vpr[GRtoTMIidx3dOut], nsampout, nswp)
  tmi_gvzstddev_vpr = REFORM( tmi_gvzstddev_vpr[GRtoTMIidx3dOut], nsampout, nswp)
  tmi_top = REFORM( tmi_top[GRtoTMIidx3dOut], nsampout, nswp)
  tmi_botm = REFORM( tmi_botm[GRtoTMIidx3dOut], nsampout, nswp)
  tmi_top_vpr = tmi_top
  tmi_botm_vpr = tmi_botm
  tmi_lat = REFORM( tmi_lat[GRtoTMIidx3dOut], nsampout, nswp)
  tmi_lon = REFORM( tmi_lon[GRtoTMIidx3dOut], nsampout, nswp)
  tmi_dist_3d = REFORM( tmi_dist_3d[GRtoTMIidx3dOut], nsampout, nswp)
  tmi_sfclat = tmi_sfclat[GRtoTMIidxSfcOut]
  tmi_sfclon = tmi_sfclon[GRtoTMIidxSfcOut]
  tmi_dist_sfc = tmi_dist_sfc[GRtoTMIidxSfcOut]
  tmi_sfctyp = tmi_sfctyp[GRtoTMIidxSfcOut]
  tmi_sfcrain = tmi_sfcrain[GRtoTMIidxSfcOut]
  tmi_rnflag = tmi_rnflag[GRtoTMIidxSfcOut]
  tmi_dataflag = tmi_dataflag[GRtoTMIidxSfcOut]
  IF ( tmi_geometa.tmi_version EQ 7 ) THEN PoP = PoP[GRtoTMIidxSfcOut] $
  ELSE PoP = make_array(nsampout, /INTEGER, VALUE=-99)  ; create, set to MISSING if not V7

  oldxcorner = tmi_xcorner
  oldycorner = tmi_ycorner
  tmi_xcorner=fltarr(4, nsampout,nswp)
  tmi_ycorner=fltarr(4, nsampout,nswp)
  for corneridx = 0,3 do begin
     temp = REFORM(oldxcorner[corneridx, *, *])
     temp = temp[GRtoTMIidx3dOut]
     temp = REFORM(temp, nsampout,nswp, /OVERWRITE)
     tmi_xcorner[corneridx, *, *] = temp
     temp = REFORM(oldycorner[corneridx, *, *])
     temp = temp[GRtoTMIidx3dOut]
     temp = REFORM(temp, nsampout,nswp, /OVERWRITE)
     tmi_ycorner[corneridx, *, *] = temp
  endfor

;-------------------------------------------------

; populate structure variables to be returned

metaparms = {geometa : mygeometa, $
             sweepmeta : mysweeps, $
             sitemeta : mysite }

dataparms = {numTMIsfc : numTMIsfcOut, $
             numTMI3d : numTMI3dOut, $
             numPRsfc : numPRsfcOut, $
             numPR3d : numPR3dOut, $
             TMI_index_sfc : TMIidxSfcOut, $
             TMI_index_3d : TMIidx3dOut, $
             GRtoTMI_idx_sfc : GRtoTMIidxSfcOut, $
             GRtoTMI_idx_3d : GRtoTMIidx3dOut, $
             gvz : grz3dOut, $
             zcor : zcor3dOut, $
             rain3 : rain3dOut, $
             nearSurfRain : rainPRsfcOut, $
;             rnFlag : rnFlag, $
             rnTypeStrat : numRaintypeStratOut, $
             rnTypeConv : numRaintypeConvOut, $
             rnCertain : numRainCertainOut, $
             bbHeight : meanBBhgtOut, $
             pctgoodpr : pctgoodPRout, $
             pctgoodgv : pctgoodGRout, $
             tmi_geometa : tmi_geometa, $
             tmi_sweeps : tmi_sweeps, $
             tmi_site : tmi_site, $
             tmi_flags : tmi_flags, $
             tmi_files :  tmi_files, $
             tmi_gvexp : tmi_gvexp, $
             tmi_gvrej : tmi_gvrej, $
             tmi_gvexp_vpr : tmi_gvexp_vpr, $
             tmi_gvrej_vpr : tmi_gvrej_vpr, $
             tmi_gvz : tmi_gvz, $
             tmi_gvzmax : tmi_gvzmax, $
             tmi_gvzstddev : tmi_gvzstddev, $
             tmi_gvz_vpr : tmi_gvz_vpr, $
             tmi_gvzmax_vpr : tmi_gvzmax_vpr, $
             tmi_gvzstddev_vpr : tmi_gvzstddev_vpr, $
             tmi_top : tmi_top, $
             tmi_botm : tmi_botm, $
             tmi_top_vpr : tmi_top_vpr, $
             tmi_botm_vpr : tmi_botm_vpr, $
             tmi_xcorner : tmi_xcorner, $
             tmi_ycorner : tmi_ycorner, $
             tmi_lat : tmi_lat, $
             tmi_lon : tmi_lon, $
             tmi_dist_3d : tmi_dist_3d, $
             tmi_sfclat : tmi_sfclat, $
             tmi_sfclon : tmi_sfclon, $
             tmi_dist_sfc : tmi_dist_sfc, $
             tmi_sfctyp : tmi_sfctyp, $
             tmi_sfcrain : tmi_sfcrain, $
             tmi_rnflag : tmi_rnflag, $
             tmi_dataflag : tmi_dataflag, $
             PoP : PoP }

structs3 = {bbparms:bbparms, metaparms:metaparms, dataparms:dataparms}

status = 0   ; set to SUCCESS
GOTO, goodExit

;-------------------------------------------------

errorExit:
structs3 = "NO DATA"

goodExit:
return, structs3
end
