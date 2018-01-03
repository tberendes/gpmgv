;===============================================================================
;+
; Copyright © 2011, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; read_geo_match2structures.pro      Morris/SAIC/GPM_GV      August 2011
;
; DESCRIPTION
; -----------
; Reads PR and GV reflectivity and spatial fields from a user-selected geo_match
; netCDF file, builds index arrays of categories of range, rain type, bright
; band proximity (above, below, within), and an array of actual range. Single-
; level arrays (pr_index, rainType, etc.) are replicated to the same number of
; levels/dimensions as the sweep-level variables (PR and GR reflectivity. etc.).
; "Bogus" border points that enclose the actual match-up data at each level are
; removed so that only the profiles with actual data are returned to the caller.
; All original/replicated spatial data fields are restored to the form of 2-D
; arrays of dimensions (number of PR rays, number of sweeps) to facilitate
; analysis as vertical profiles.  Returns an anonymous structure, itself
; containing the three structures bbparms, metaparms, and dataparms, as defined
; below under RETURN VALUE.
;
; For the array of heights passed, or for a default set of heights, the
; routine will compute an array of the dimensions of the sweep-level data
; that assigns each sample point in the sweep-level data to a fixed-height
; level based on the vertical midpoint of the sample.  The assigned values
; are the array index value of the corresponding height in the default/passed
; array of heights.
;
; The mean height of the bright band, and the array index of the highest and
; lowest fixed-height level affected by the bright band will be computed and
; returned in the 'bbparms' structure.  See the code for rules on how
; fixed-height layers affected by the bright band are determined.
;
; The function will also compute 3 arrays holding the percentage of raw bins
; included in the volume average whose physical values were at/above the
; fixed thresholds for:
;
; 1) PR reflectivity (18 dBZ, or as defined in the geo_match netcdf file)
; 2) GR reflectivity (15 dBZ, or as defined in the geo_match netcdf file)
; 3) PR rainrate (0.01 mm/h, or as defined in the geo_match netcdf file).
;
; These 3 thresholds are available in the "mygeometa" variable, a structure
; of type "geo_match_meta" (see geo_match_nc_structs.inc), populated in
; the call to read_geo_match_netcdf(), in the structure variables PR_dBZ_min,
; GV_dBZ_min, and rain_min, respectively.
;
; If s2ku binary parameter is set, then the Liao/Meneghini S-to-Ku band
; reflectivity adjustment will be made to the volume-matched ground radar
; reflectivity field, gvz.
;
; PARAMETERS
; ----------
; ncfilepr     - fully qualified path/name of the geo_match netCDF file to read
;
; heights      - array of fixed height levels used to compute the height
;                categories assigned to the 3-D data samples.  If none is
;                provided, a default set of 13 levels from 1.5-19.5 km is used
;
; s2ku         - Binary parameter, controls whether or not to apply the Liao/
;                Meneghini S-band to Ku-band adjustment to GV reflectivity.
;                Default = no
;
; RETURN VALUE
; ------------
; struct3      - an anonymous structure with 3 tags: bbparms, metaparms, and
;                dataparms, each referencing another structure of the same name,
;                as defined by the following:
;
;    bbparms   - structure to hold computed bright band variables: mean BB
;                height, and lowest and highest fixed-layer heights affected by
;                the bright band (see heights parameter and DESCRIPTION section)
;                All heights are in relation to Above Ground Level starting with
;                version 1.1 netCDF data files.
;
;    metaparms - structure to hold the metadata structures read from the netCDF
;                file, as listed below
;
;    dataparms - structure to hold the data arrays read from the file, as listed below
; 
; Metadata Structures held in the metaparm structure:
; --------------------------------------------------
; mygeometa     a structure holding dimensioning information for the matchup data
; mysweeps      a structure holding GR volume info - sweep elevations etc.
; mysite        a structure holding GR location, station ID, etc.
; myflags       a structure holding flags indicating whether data fields are good, or just fill values
; myfiles       a structure holding the names of the input PR and GR files used in the matchup
;
; Refer to the IDL "include" file geo_match_nc_structs.inc for the definition and contents
; of these 5 metadata structures.
;
; Data Arrays held in the dataparm structure:
; ------------------------------------------
; gvz           a subsetted array of volume-matched GR mean reflectivity
; gvzmax        a subsetted array of volume-matched GR maximum reflectivity
; gvzstddev     a subsetted array of volume-matched GR reflectivity standard deviation
; zraw          a subsetted array of volume-matched PR 1C21 reflectivity
; zcor          a subsetted array of volume-matched PR 2A25 corrected reflectivity
; rain3         a subsetted array of volume-matched PR 3D rainrate
; top           a subsetted array of volume-match sample point top heights, km
; botm          a subsetted array of volume-match sample point bottom heights, km
; lat           a subsetted array of volume-match sample point latitude
; lon           a subsetted array of volume-match sample point longitude
; nearSurfRain        a subsetted array of volume-matched near-surface PR rainrate *
; nearSurfRain_2b31   a subsetted array of volume-matched 2B31 PR rainrate *
; pr_index            a subsetted array of 1-D indices of the original (scan,ray) PR product coordinates *
; rnFlag              a subsetted array of volume-match sample point yes/no rain flag value *
; rnType              a subsetted array of volume-match sample point rain type *,#
; landOceanFlag       a subsetted array of volume-match sample point surface type *
; XY_km               an array of volume-match sample point X and Y coordinates, radar-centric, km *
; dist                an array of volume-match sample point range from radar, km *
; hgtcat              an array of volume-match sample point height layer indices, 0-12, representing 1.5-19.5 km
; bbProx              an array of volume-match sample point proximity to mean bright band:
;                     1 (below), 2 (within), 3 (above)
; bbHeight            an array of PR 2A25 bright band height from RangeBinNums, m *
; bbStatus            an array of PR 2A23 bright band status *
; status_2a23         an array of PR 2A23 status flag *
; pctgoodpr           an array of volume-match sample point percent of original PR dBZ bins above threshold
; pctgoodgv           an array of volume-match sample point percent of original GR dBZ bins above threshold
; pctgoodrain         an array of volume-match sample point percent of original PR rainrate bins above threshold
;
; The arrays should all be of the same size when done, with the exception of
; the xCorner and yCorner fields that have an additional dimension that
; needs to be dealt with.  
;
; * indicates variables existing as single-level fields in the netCDF file
; (e.g., nearSurfRain) that are replicated to the N sweep levels of the GR volume
; scan to match the multi-level fields before the data get subsetted. Subsetting
; involves paring off the "bogus" data points that enclose the area of the
; actual PR/GR overlap data.
;
; # indicates that rain type is dumbed down to simple categories 1 (Stratiform),
; 2 (Convective), or 3 (Other), from the original PR 3-digit subcategories
;
;
; HISTORY
; -------
; 08/09/11 Morris, GPM GV, SAIC
; - Created from fprep_geo_match_profiles2_1.pro, modified to return structures
;   containing all data in the netCDF file and the utility fields derived in
;   this routine.
; 08/12/11 Morris, GPM GV, SAIC
; - Added landOceanFlag to the dataparms structure.
;
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;===============================================================================


FUNCTION read_geo_match2structures, ncfilepr, heights, $
                                    S2KU=s2ku, BB_RELATIVE=bb_relative

; "include" file for metadata structs returned from read_geo_match_netcdf()
;@geo_match_nc_structs.inc  ; instead, now call GET_GEO_MATCH_NC_STRUCT()

; "include" file for PR data constants
@pr_params.inc

s2ku = keyword_set( s2ku )

; if convective or stratiform reflectivity thresholds are not specified, disable
; rain type overrides by setting values to zero
IF ( N_ELEMENTS(gvconvective) NE 1 ) THEN gvconvective=0.0
IF ( N_ELEMENTS(gvstratiform) NE 1 ) THEN gvstratiform=0.0

; Get an uncompressed copy of the netCDF file - we never touch the original
cpstatus = uncomp_file( ncfilepr, ncfile1 )

status = 1   ; init return status to FAILED

if (cpstatus eq 'OK') then begin

 ; create <<initialized>> structures to hold the metadata variables
  mygeometa=GET_GEO_MATCH_NC_STRUCT('matchup')  ;{ geo_match_meta }
  mysweeps=GET_GEO_MATCH_NC_STRUCT('sweeps')    ;{ gv_sweep_meta }
  mysite=GET_GEO_MATCH_NC_STRUCT('site')        ;{ gv_site_meta }
  myflags=GET_GEO_MATCH_NC_STRUCT('fields')     ;{ pr_gv_field_flags }
  myfiles=GET_GEO_MATCH_NC_STRUCT( 'files' )

 ; read the file to populate only the structures
  status = read_geo_match_netcdf( ncfile1, matchupmeta=mygeometa, $
     sweepsmeta=mysweeps, sitemeta=mysite, fieldflags=myflags, filesmeta=myfiles )
 ; remove the netCDF file copy and exit, if problems reading file
  IF (status EQ 1) THEN BEGIN
     command3 = "rm -v " + ncfile1
     spawn, command3
     GOTO, errorExit
  ENDIF

  site_lat = mysite.site_lat
  site_lon = mysite.site_lon
  siteID = string(mysite.site_id)
  site_elev = mysite.site_elev

 ; now create data field arrays of correct dimensions and read ALL data fields

  nfp = mygeometa.num_footprints  ; # of PR rays in dataset (real+bogus)
  nswp = mygeometa.num_sweeps     ; # of GR elevation sweeps in dataset

  gvexp=intarr(nfp,nswp)
  gvrej=intarr(nfp,nswp)
  prexp=intarr(nfp,nswp)
  zrawrej=intarr(nfp,nswp)
  zcorrej=intarr(nfp,nswp)
  rainrej=intarr(nfp,nswp)
  gvz=fltarr(nfp,nswp)
  gvzmax=fltarr(nfp,nswp)
  gvzstddev=fltarr(nfp,nswp)
  zraw=fltarr(nfp,nswp)
  zcor=fltarr(nfp,nswp)
  rain3=fltarr(nfp,nswp)
  top=fltarr(nfp,nswp)
  botm=fltarr(nfp,nswp)
  lat=fltarr(nfp,nswp)
  lon=fltarr(nfp,nswp)
  bbHeight=fltarr(nfp)
  nearSurfRain=fltarr(nfp)
  nearSurfRain_2b31=fltarr(nfp)
  rnflag=intarr(nfp)
  rntype=intarr(nfp)
  landOceanFlag=intarr(nfp)
  bbStatus=intarr(nfp)
  status_2a23=intarr(nfp)
  pr_index=lonarr(nfp)
  xcorner=fltarr(4,nfp,nswp)
  ycorner=fltarr(4,nfp,nswp)

  status = read_geo_match_netcdf( ncfile1,  $
    gvexpect_int=gvexp, gvreject_int=gvrej, prexpect_int=prexp, $
    zrawreject_int=zrawrej, zcorreject_int=zcorrej, rainreject_int=rainrej, $
    dbzgv=gvz, dbzcor=zcor, dbzraw=zraw, rain3d=rain3, topHeight=top, $
    bottomHeight=botm, latitude=lat, longitude=lon, bbhgt=BBHeight, $
    sfcrainpr=nearSurfRain, sfcraincomb=nearSurfRain_2b31, $
    rainflag_int=rnFlag, raintype_int=rnType, sfctype_int=landOceanFlag, $
    xCorners=xCorner, yCorners=yCorner, gvStdDev=gvzstddev, gvMax=gvzmax, $
    status_2a23_int=status_2a23, BBstatus_int=bbStatus, pridx_long=pr_index )

 ; remove the uncompressed file copy
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

; get array indices of the non-bogus (i.e., "actual") PR footprints
; -- pr_index is defined for one slice (sweep level), while most fields are
;    multiple-level (have another dimension: nswp).  Deal with this later on.
idxpractual = where(pr_index GE 0L, countactual)
if (countactual EQ 0) then begin
   print, "No non-bogus data points, quitting case."
   status = 1
   goto, errorExit
endif
; get the subset of pr_index values for actual PR rays in the matchup
pr_idx_actual = pr_index[idxpractual]

; re-set the number of footprints in the geo_match_meta structure to the
; subsetted value
mygeometa.num_footprints = countactual

; Reclassify rain types down to simple categories 1 (Stratiform), 2 (Convective),
;  or 3 (Other), where defined
idxrnpos = where(rntype ge 0, countrntype)
if (countrntype GT 0 ) then rntype[idxrnpos] = rntype[idxrnpos]/100

; - - - - - - - - - - - - - - - - - - - - - - - -

; clip the data fields down to the actual footprint points.  Deal with the
; single-level vs. multi-level fields first by replicating the single-level
; fields 'nswp' times (pr_index, rnType, rnFlag, nearSurfRain, nearSurfRain_2b31).

; Clip single-level fields we will use for mean BB calculations:
BB = BBHeight[idxpractual]
bbStatusCode = bbStatus[idxpractual]

; Now do the sweep-level arrays - have to build an array index of actual
; points, replicated over all the sweep levels
idx3d=long(gvexp)           ; take one of the 2D arrays, make it LONG type
idx3d[*,*] = 0L             ; re-set all point values to 0
idx3d[idxpractual,0] = 1L   ; set first-sweep-level values to 1 where non-bogus

; now copy the first sweep values to the other levels, and while in the same loop,
; make the single-level arrays for categorical fields the same dimension as the
; sweep-level by array concatenation
IF ( nswp GT 1 ) THEN BEGIN  
   rnFlagApp = rnFlag
   rnTypeApp = rnType
   landOceanFlagApp=landOceanFlag
   nearSurfRainApp = nearSurfRain
   nearSurfRain_2b31App = nearSurfRain_2b31
   pr_indexApp = pr_index
   bbStatusApp=bbStatus
   status_2a23App=status_2a23
   BBHeightApp=BBHeight

   FOR iswp=1, nswp-1 DO BEGIN
      idx3d[*,iswp] = idx3d[*,0]    ; copy first level values to iswp'th level
      rnFlag = [rnFlag, rnFlagApp]  ; concatenate another level's worth for rain flag
      rnType = [rnType, rnTypeApp]  ; ditto for rain type
      landOceanFlag = [landOceanFlag, landOceanFlagApp]  ; ditto for landOceanFlag
      nearSurfRain = [nearSurfRain, nearSurfRainApp]  ; ditto for sfc rain
      nearSurfRain_2b31 = [nearSurfRain_2b31, nearSurfRain_2b31App]  ; ditto for sfc rain
      pr_index = [pr_index, pr_indexApp]  ; ditto for pr_index
      bbStatus = [bbStatus, bbStatusApp]  ; ditto for bbStatus
      status_2a23 = [status_2a23, status_2a23App]  ; ditto for status_2a23
      BBHeight = [BBHeight, BBHeightApp]  ; ditto for BBHeight
   ENDFOR
ENDIF

; get the indices of all the non-bogus points in the 2D sweep-level arrays
idxpractual2d = where( idx3d EQ 1L, countactual2d )
if (countactual2d EQ 0) then begin
  ; this shouldn't be able to happen
   print, "No non-bogus 2D data points, quitting case."
   status = 1   ; set to FAILED
   goto, errorExit
endif

; clip the sweep-level arrays to the locations of actual PR footprints only
gvexp = gvexp[idxpractual2d]
gvrej = gvrej[idxpractual2d]
prexp = prexp[idxpractual2d]
zrawrej = zrawrej[idxpractual2d]
zcorrej = zcorrej[idxpractual2d]
rainrej = rainrej[idxpractual2d]
gvz = gvz[idxpractual2d]
gvzmax = gvzmax[idxpractual2d]
gvzstddev = gvzstddev[idxpractual2d]
zraw = zraw[idxpractual2d]
zcor = zcor[idxpractual2d]
rain3 = rain3[idxpractual2d]
top = top[idxpractual2d]
botm = botm[idxpractual2d]
lat = lat[idxpractual2d]
lon = lon[idxpractual2d]
rnFlag = rnFlag[idxpractual2d]
rnType = rnType[idxpractual2d]
landOceanFlag = landOceanFlag[idxpractual2d]
nearSurfRain = nearSurfRain[idxpractual2d]
nearSurfRain_2b31 = nearSurfRain_2b31[idxpractual2d]
bbStatus = bbStatus[idxpractual2d]
status_2a23 = status_2a23[idxpractual2d]
BBHeight = BBHeight[idxpractual2d]
pr_index = pr_index[idxpractual2d]

; deal with the x- and y-corner arrays with the extra dimension
xcornew = fltarr(4, countactual, nswp)
ycornew = fltarr(4, countactual, nswp)
FOR icorner = 0,3 DO BEGIN
   xcornew[icorner,*,*] = xCorner[icorner,idxpractual,*]
   ycornew[icorner,*,*] = yCorner[icorner,idxpractual,*]
ENDFOR

; - - - - - - - - - - - - - - - - - - - - - - - -

; compute percent completeness of the volume averages

   ;print, "============================================================================="
   ;print, "Computing Percent Above Threshold for PR and GR Reflectivity and PR Rainrate."
   ;print, "============================================================================="
   pctgoodpr = fltarr( N_ELEMENTS(prexp) )
   pctgoodgv =  fltarr( N_ELEMENTS(prexp) )
   pctgoodrain = fltarr( N_ELEMENTS(prexp) )
   idxexpgt0 = WHERE( prexp GT 0 AND gvexp GT 0, countexpgt0 )
   IF ( countexpgt0 EQ 0 ) THEN BEGIN
      print, "No valid volume-average points, quitting case."
      status = 1
      goto, errorExit
   ENDIF ELSE BEGIN
      pctgoodpr[idxexpgt0] = $
         100.0 * FLOAT( prexp[idxexpgt0] - zcorrej[idxexpgt0] ) / prexp[idxexpgt0]
      pctgoodgv[idxexpgt0] = $
         100.0 * FLOAT( gvexp[idxexpgt0] - gvrej[idxexpgt0] ) / gvexp[idxexpgt0]
      pctgoodrain[idxexpgt0] = $
         100.0 * FLOAT( prexp[idxexpgt0] - rainrej[idxexpgt0] ) / prexp[idxexpgt0]
   ENDELSE

; - - - - - - - - - - - - - - - - - - - - - - - -

; restore the subsetted arrays to two dimensions of (PRfootprints, GRsweeps)
gvz = REFORM( gvz, countactual, nswp )
gvzmax = REFORM( gvzmax, countactual, nswp )
gvzstddev = REFORM( gvzstddev, countactual, nswp )
zraw = REFORM( zraw, countactual, nswp )
zcor = REFORM( zcor, countactual, nswp )
rain3 = REFORM( rain3, countactual, nswp )
top = REFORM( top, countactual, nswp )
botm = REFORM( botm, countactual, nswp )
lat = REFORM( lat, countactual, nswp )
lon = REFORM( lon, countactual, nswp )
rnFlag = REFORM( rnFlag, countactual, nswp )
rnType = REFORM( rnType, countactual, nswp )
landOceanFlag = REFORM( landOceanFlag, countactual, nswp )
nearSurfRain = REFORM( nearSurfRain, countactual, nswp )
nearSurfRain_2b31 = REFORM( nearSurfRain_2b31, countactual, nswp )
pr_index = REFORM( pr_index, countactual, nswp )
bbStatus = REFORM( bbStatus, countactual, nswp )
status_2a23 = REFORM( status_2a23, countactual, nswp )
BBHeight = REFORM( BBHeight, countactual, nswp )
pctgoodpr = REFORM( pctgoodpr, countactual, nswp )
pctgoodgv =  REFORM( pctgoodgv, countactual, nswp )
pctgoodrain = REFORM( pctgoodrain, countactual, nswp )

; - - - - - - - - - - - - - - - - - - - - - - - -

IF ( N_ELEMENTS(heights) EQ 0 ) THEN BEGIN
   print, ''
   print, "In read_geo_match2structures(): assigning 13 default height levels, 1.5-19.5km"
   heights = [1.5,3.0,4.5,6.0,7.5,9.0,10.5,12.0,13.5,15.0,16.5,18.0,19.5]
ENDIF
halfdepth=(heights[1]-heights[0])/2.0

; convert bright band heights from m to km, where defined, and get mean BB hgt.
; - first, find the indices of stratiform rays with BB defined

idxbbdef = where(bb GT 0.0 AND rnType[*,0] EQ 1, countBB)
IF ( countBB GT 0 ) THEN BEGIN
  ; grab the subset of BB values for defined/stratiform
   bb2hist = bb[idxbbdef]/1000.  ; with conversion to km

   bs=0.2  ; bin width, in km, for HISTOGRAM in get_mean_bb_height()
;   hist_window = 9  ; uncomment to plot BB histogram and print diagnostics

  ; - now, do some sorcery to find the best mean BB height estimate, in km
;print, "myflags.have_BBstatus: ", myflags.have_BBstatus
   IF myflags.have_BBstatus EQ 1 THEN BEGIN
     ; try to get mean BB using BBstatus of 'good' or 'fair'
      bbstatusstrat = bbStatusCode[idxbbdef]
      meanbb_MSL = get_mean_bb_height2( bb2hist, bbstatusstrat, BS=bs, $
                                       HIST_WINDOW=hist_window )
   ENDIF ELSE BEGIN
     ; use histogram analysis of BB heights to get mean height
      meanbb_MSL = get_mean_bb_height2( bb2hist, BS=bs, HIST_WINDOW=hist_window )
   ENDELSE

  ; BB height in netCDF file is height above MSL -- must adjust mean BB to
  ; height above ground level for comparison to "heights"
   meanbb = meanbb_MSL - site_elev

   IF keyword_set(bb_relative) THEN BEGIN
     ; level affected by BB is simply the zero-height BB-relative layer
      idxBB_HgtHi = WHERE( heights EQ 0.0, nbbzero)
      IF nbbzero EQ 1 THEN BEGIN
         BB_HgtHi = idxBB_HgtHi
         BB_HgtLo = BB_HgtHi
      ENDIF ELSE BEGIN
         print, "ERROR assigning BB-affected layer number."
         status = 1   ; set to FAILED
         goto, errorExit
      ENDELSE
   ENDIF ELSE BEGIN
     ; Level below BB is affected if layer top is 500m (0.5 km) or less below BB_Hgt, so
     ; BB_HgtLo is index of lowest fixed-height layer considered to be within the BB
     ; (see 'heights' array and halfdepth, above)
      idxbelowbb = WHERE( (heights+halfdepth) LT (meanbb-0.5), countbelowbb )
      if (countbelowbb GT 0) THEN BB_HgtLo = (MAX(idxbelowbb) + 1) < (N_ELEMENTS(heights)-1) $
      else BB_HgtLo = 0
     ; Level above BB is affected if BB_Hgt is 500m (0.5 km) or less below layer bottom,
     ; so BB_HgtHi is highest fixed-height layer considered to be within the BB
      idxabvbb = WHERE( (heights-halfdepth) GT (meanbb+0.5), countabvbb )
      if (countabvbb GT 0) THEN BB_HgtHi = (MIN(idxabvbb) - 1) > 0 $
      else if (meanbb GE (heights(N_ELEMENTS(heights)-1)-halfdepth) ) then $
      BB_HgtHi = (N_ELEMENTS(heights)-1) else BB_HgtHi = 0
   ENDELSE

   bbparms = {meanBB : -99.99, BB_HgtLo : -99, BB_HgtHi : -99}
   bbparms.meanbb = meanbb
   bbparms.BB_HgtLo = BB_HgtLo < BB_HgtHi
   bbparms.BB_HgtHi = BB_HgtHi > BB_HgtLo
   print, 'Mean BB (km AGL), bblo, bbhi = ', meanbb, heights[0]+halfdepth*2*bbparms.BB_HgtLo, $
          heights[0]+halfdepth*2*bbparms.BB_HgtHi
   print, ''
ENDIF ELSE BEGIN
   print, "In read_geo_match2structures(): No valid bright band heights, quitting case."
   print, ''
   status = 1   ; set to FAILED
   goto, errorExit
ENDELSE

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
   IF keyword_set(bb_relative) THEN beamhgt[idxhgtdef] = (top[idxhgtdef]+botm[idxhgtdef])/2 - meanbb + 6.0 $
   ELSE beamhgt[idxhgtdef] = (top[idxhgtdef]+botm[idxhgtdef])/2
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

;print, (top[idxhgtdef]+botm[idxhgtdef])/2 - meanbb, heights[hgtcat[idxhgtdef]]

; build an array of proximity to the bright band: above (=3), within (=2), below (=1)
; -- define above (below) BB as bottom (top) of beam at least 750m above
;    (750m below) mean BB height

num_in_BB_Cat = LONARR(4)
bbProx = rnType   ; for a starter
bbProx[*] = 0  ; re-init to Not Defined
idxabv = WHERE( botm GT (meanbb+0.750), countabv )
num_in_BB_Cat[3] = countabv
IF countabv GT 0 THEN bbProx[idxabv] = 3
idxblo = WHERE( top LT (meanbb-0.750), countblo )
num_in_BB_Cat[1] = countblo
IF countblo GT 0 THEN bbProx[idxblo] = 1
idxin = WHERE( (botm LE (meanbb+0.750)) AND (top GE (meanbb-0.750)), countin )
num_in_BB_Cat[2] = countin
IF countin GT 0 THEN bbProx[idxin] = 2

; - - - - - - - - - - - - - - - - - - - - - - - -

; apply the S-to-Ku band adjustment if parameter s2ku is set

IF ( s2ku ) THEN BEGIN
   print, "=================================================================="
   print, "Applying rain/snow adjustments to S-band to match Ku reflectivity."
   print, "=================================================================="
   IF countabv GT 0 THEN BEGIN
     ; grab the above-bb points of the GV reflectivity
      gvz4snow = gvz[idxabv]
     ; find those points with non-missing reflectivity values
      idx2ku = WHERE( gvz4snow GT 0.0, count2ku )
      IF count2ku GT 0 THEN BEGIN
        ; perform the conversion and replace the original values
         gvz[idxabv[idx2ku]] = s_band_to_ku_band( gvz4snow[idx2ku], 'S' )
      ENDIF ELSE print, "No above-BB points for S-to-Ku snow correction"
   ENDIF
   IF countblo GT 0 THEN BEGIN
      gvz4rain = gvz[idxblo]
      idx2ku = WHERE( gvz4rain GT 0.0, count2ku )
      IF count2ku GT 0 THEN BEGIN
         gvz[idxblo[idx2ku]] = s_band_to_ku_band( gvz4rain[idx2ku], 'R' )
      ENDIF ELSE print, "No below-BB points for S-to-Ku rain correction"
   ENDIF
ENDIF

; - - - - - - - - - - - - - - - - - - - - - - - -

; populate structure variables provided as parameters, as provided

metaparms = {geometa : mygeometa, $
             sweepmeta : mysweeps, $
             sitemeta : mysite, $
             fieldflags : myflags, $
             filesmeta : myfiles}
dataparms = {gvz : gvz, $
             gvzmax : gvzmax, $
             gvzstddev : gvzstddev, $
             zraw : zraw, $
             zcor : zcor, $
             rain3 : rain3, $
             top : top, $
             botm : botm, $
             lat : lat, $
             lon : lon, $
             nearSurfRain : nearSurfRain, $
             nearSurfRain_2b31 : nearSurfRain_2b31, $
             rnFlag : rnFlag, $
             rnType : rnType, $
             landOceanFlag : landOceanFlag, $
             bbstatus : bbStatus, $
             status_2a23 : status_2a23, $
             bbHeight :bbHeight, $
             pr_index : pr_index, $
             bbProx : bbProx, $
             hgtcat : hgtcat, $
             dist : dist, $
             xCorner : xcornew, $
             yCorner : ycornew, $
             pctgoodpr : pctgoodpr, $
             pctgoodgv : pctgoodgv, $
             pctgoodrain : pctgoodrain}

structs3 = {bbparms:bbparms, metaparms:metaparms, dataparms:dataparms}
status = 0   ; set to SUCCESS
GOTO, goodExit

errorExit:
structs3 = "NO DATA"

goodExit:
return, structs3

END
