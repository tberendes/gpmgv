;===============================================================================
;
; prep_geo_match_fields.pro
;
; DESCRIPTION
; -----------
; Reads PR and GV reflectivity and spatial fields from a user-selected geo_match
; netCDF file, builds index arrays of categories of range, rain type, bright
; band proximity (above, below, within), and an array of actual range. 
;
; If the pctAbvThresh parameter is specified, then the data points will be
; subset to those where the percentage of raw bins included in the volume
; average whose physical values were at/above the fixed thresholds for
; reflectivity (18 dBZ for PR, 15 dBZ for GV) is => pctAbvThresh.  The
; thresholding ignores the rainrate threshold (0.01 mm/h) in the subsetting.
;
; If s2ku binary parameter is set, then the Liao/Meneghini S-to-Ku band
; reflectivity adjustment will be made to GV reflectivity field.
;
; PARAMETERS
; ----------
; ncfilepr     - fully qualified path/name of the geo_match netCDF file to read
;
; pctAbvThresh - constraint on the percent of bins in the geometric-matching
;                volume that were above their respective Z thresholds, specified
;                at the time the geo-match dataset was created.  Essentially a
;                measure of "beam-filling goodness".  100 means use only those
;                matchup points where all the PR and GV bins in the volume
;                averages were above threshold (complete volume filled with
;                above threshold bin values).  0 means use all matchup points
;                available, with no regard for thresholds (the default, if no
;                pctAbvThresh value is specified)
;
; s2ku         - Binary parameter, controls whether or not to apply the Liao/
;                Meneghini S-band to Ku-band adjustment to GV reflectivity.
;                Default = no
;
; DATA FIELDS
; -----------
; At the end of the procedure, you will have the following data fields available
; for processing.  It's up to you to decide how to pass them on to another
; procedure.
;
; mygeometa     a structure holding dimensioning information for the matchup data
; mysweeps      a structure holding GR volume info - sweep elevations etc.
; mysite        a structure holding GR location, station ID, etc.
; myflags       a structure holding flags indicating whether data fields are good, or just fill values
; gvz           a subsetted array of volume-matched GR reflectivity
; zraw          a subsetted array of volume-matched PR 1C21 reflectivity
; zcor          a subsetted array of volume-matched PR 2A25 corrected reflectivity
; rain3         a subsetted array of volume-matched PR 3D rainrate
; top           a subsetted array of volume-match sample point top heights, km
; botm          a subsetted array of volume-match sample point bottom heights, km
; lat           a subsetted array of volume-match sample point latitude
; lon           a subsetted array of volume-match sample point longitude
; nearSurfRain        a subsetted array of volume-matched near-surface PR rainrate *
; nearSurfRain_2b31   a subsetted array of volume-matched 2B31 PR rainrate *
; rnFlag              a subsetted array of volume-match sample point yes/no rain flag value *
; rnType              a subsetted array of volume-match sample point rain type *,#
; XY_km               an array of volume-match sample point X and Y coordinates, radar-centric, km *
; dist                an array of volume-match sample point range from radar, km *
; hgtcat              an array of volume-match sample point height layer indices, 0-12, representing 1.5-19.5 km
; bbProx              an array of volume-match sample point proximity to bright band: 1 (below), 2 (within), 3 (above)
; voldepth            an array of volume-match sample point vertical depth, units as for top and botm
;
; The arrays should all be of the same size when done.  Those marked by * are
; originally single-level fields like nearSurfRain that are replicated to the
; N sweep levels in the volume scan to match the multi-level fields before the
; data get subsetted.  Subsetting involves two things: pare off the "bogus"
; data points that enclose the area of the actual overlap data; and if the
; PCT_ABV_THRESH parameter is non-zero, pare down to those points meeting
; the "percent averaged bins above detection thresholds" criteria.
;
; # indicates that rain type is dumbed down to simple categories 1 (Stratiform),
; 2 (Convective), or 3 (Other), from the original PR 3-digit subcategories
;
; The xCorner and yCorner fields are read from the matchup netCDF file, but are
; not subsetted for use.  They have an additional dimension that would need to
; be dealt with.


PRO prep_geo_match_fields, ncfilepr, PCT_ABV_THRESH=pctAbvThresh, S2KU=s2ku

; "include" file for structs returned from read_geo_match_netcdf()
@geo_match_nc_structs.inc

; "include" file for PR data constants
@pr_params.inc

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

s2ku = keyword_set(s2ku)

bname = file_basename( ncfilepr )
prlen = strlen( bname )
pctString = STRTRIM(STRING(FIX(pctabvthresh)),2)
parsed = STRSPLIT( bname, '.', /extract )
site = parsed[1]
yymmdd = parsed[2]
orbit = parsed[3]

; Get uncompressed copy of the found files
cpstatus = uncomp_file( ncfilepr, ncfile1 )

if (cpstatus eq 'OK') then begin

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
  nearSurfRain=fltarr(nfp)
  nearSurfRain_2b31=fltarr(nfp)
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
    sfcrainpr=nearSurfRain, sfcraincomb=nearSurfRain_2b31, $
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

; get array indices of the non-bogus (i.e., "actual") PR footprints
; -- pr_index is defined for one slice (sweep level), while most fields are
;    multiple-level (have another dimension: nsweeps).  Deal with this later on.
idxpractual = where(pr_index GE 0L, countactual)
if (countactual EQ 0) then begin
   print, "No non-bogus data points, quitting case."
   goto, errorExit
endif

; Reclassify rain types down to simple categories 1 (Stratiform), 2 (Convective),
;  or 3 (Other), where defined
idxrnpos = where(rntype ge 0, countrntype)
if (countrntype GT 0 ) then rntype(idxrnpos) = rntype(idxrnpos)/100

; - - - - - - - - - - - - - - - - - - - - - - - -

; clip the data fields down to the actual footprint points.  Deal with the
; single-level vs. multi-level fields first by replicating the single-level
; fields 'nsweeps' times (pr_index, rnType, rnFlag).

; Clip single-level first (don't need BB replicated to all sweeps):
BB = BB[idxpractual]

; Now do the sweep-level arrays - have to build an array index of actual
; points, replicated over all the sweep levels
idx3d=long(gvexp)           ; take one of the 2D arrays, make it LONG type
idx3d[*,*] = 0L             ; re-set all point values to 0
idx3d[idxpractual,0] = 1L   ; set first-sweep-level values to 1 where non-bogus

; now copy the first sweep values to the other levels, and make the single-level
; arrays for categorical fields the same dimension as the sweep-level by array
; concatenation
rnFlagApp = rnFlag
rnTypeApp = rnType
nearSurfRainApp = nearSurfRain
nearSurfRain_2b31App = nearSurfRain_2b31
IF ( nsweeps GT 1 ) THEN BEGIN  
   FOR iswp=1, nsweeps-1 DO BEGIN
      idx3d[*,iswp] = idx3d[*,0]    ; copy first level values to iswp'th level
      rnFlag = [rnFlag, rnFlagApp]  ; concatenate another level's worth for rain flag
      rnType = [rnType, rnTypeApp]  ; ditto for rain type
      nearSurfRain = [nearSurfRain, nearSurfRainApp]  ; ditto for sfc rain
      nearSurfRain_2b31 = [nearSurfRain_2b31, nearSurfRain_2b31App]  ; ditto for sfc rain
   ENDFOR
ENDIF

; get the indices of all the non-bogus points in the 2D sweep-level arrays
idxpractual2d = where( idx3d EQ 1L, countactual2d )
if (countactual2d EQ 0) then begin
  ; this shouldn't be able to happen
   print, "No non-bogus 2D data points, quitting case."
   goto, errorExit
endif

; clip the sweep-level arrays to the locations of actual PR footprints only
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
nearSurfRain = nearSurfRain[idxpractual2d]
nearSurfRain_2b31 = nearSurfRain_2b31[idxpractual2d]

; - - - - - - - - - - - - - - - - - - - - - - - -

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
         nearSurfRain = nearSurfRain[idxallgood]
         nearSurfRain_2b31 = nearSurfRain_2b31[idxallgood]
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
            nearSurfRain = nearSurfRain[idxgoodenuff]
            nearSurfRain_2b31 = nearSurfRain_2b31[idxgoodenuff]
         ENDIF ELSE BEGIN
            print, "No complete-volume points, quitting case."
            goto, errorExit
         ENDELSE
      ENDELSE
   ENDELSE
ENDIF

; - - - - - - - - - - - - - - - - - - - - - - - -

; convert bright band heights from m to km, where defined, and get mean BB hgt

idxbbdef = where(bb GT 0.0, countBB)
if ( countBB GT 0 ) THEN BEGIN
   meanbb_m = FIX(MEAN(bb[idxbbdef]))  ; in meters
   meanbb = meanbb_m/1000.        ; in km
   BB_HgtLo = (meanbb_m-1001)/1500
;  Level above BB is affected if BB_Hgt is 1000m or less below layer center,
;  so BB_HgtHi is highest fixed-height layer considered to be within the BB
;  (see 'heights' array below)
   BB_HgtHi = (meanbb_m-500)/1500
   BB_HgtLo = BB_HgtLo < 12
   BB_HgtHi = BB_HgtHi < 12
   print, 'Mean BB (km), bblo, bbhi = ', meanbb, 1.5*(BB_HgtLo+1), 1.5*(BB_HgtHi+1)
ENDIF ELSE BEGIN
   print, "No valid bright band heights, quitting case."
   goto, errorExit
ENDELSE

; build an array of sample point ranges from the GV radar
; via map projection x,y coordinates computed from lat and lon:

; initialize a gv-centered map projection for the ll<->xy transformations:
sMap = MAP_PROJ_INIT( 'Azimuthal Equidistant', center_latitude=site_lat, $
                      center_longitude=site_lon )
XY_km = map_proj_forward( lon, lat, map_structure=smap ) / 1000.
dist = SQRT( XY_km[0,*]^2 + XY_km[1,*]^2 )
dist = REFORM(dist)

; build an array of height category for the traditional VN levels, for profiles

hgtcat = rnType   ; for a starter
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
   ENDFOR
ENDIF ELSE BEGIN
   print, "No valid beam heights, quitting case."
   goto, errorExit
ENDELSE

; build an array of proximity to the bright band: above (=3), within (=2), below (=1)
; -- define above (below) BB as bottom (top) of beam at least 500m above
;    (750m below) mean BB height

num_in_BB_Cat = LONARR(4)
bbProx = rnType   ; for a starter
bbProx[*] = 0  ; re-init to Not Defined
idxabv = WHERE( botm GT (meanbb+0.500), countabv )
num_in_BB_Cat[3] = countabv
IF countabv GT 0 THEN bbProx[idxabv] = 3
idxblo = WHERE( top LT (meanbb-0.750), countblo )
num_in_BB_Cat[1] = countblo
IF countblo GT 0 THEN bbProx[idxblo] = 1
idxin = WHERE( (botm LE (meanbb+0.500)) AND (top GE (meanbb-0.750)), countin )
num_in_BB_Cat[2] = countin
IF countin GT 0 THEN bbProx[idxin] = 2

; apply the S-to-Ku band adjustment if parameter s2ku is set

IF ( s2ku ) THEN BEGIN
   print, "=================================================================="
   print, "Applying rain/snow adjustments to S-band to match Ku reflectivity."
   print, "=================================================================="
   IF countabv GT 0 THEN BEGIN
     ; grab the above-bb points of the GV reflectivity
      gvz4snow = gvz[idxabv]
     ; perform the conversion and replace the original values
      gvz[idxabv] = s_band_to_ku_band( gvz4snow, 'S' )
   ENDIF
   IF countblo GT 0 THEN BEGIN
      gvz4rain = gvz[idxblo]
      gvz[idxblo] = s_band_to_ku_band( gvz4rain, 'R' )
   ENDIF
ENDIF

; build an array of sample volume depth for weighting of the layer averages and
; mean differences
voldepth = (top-botm) > 0.0

errorExit:

END
