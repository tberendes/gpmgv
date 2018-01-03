;+
; stratified_by_dist_rr_stats_to_dbfile_geo_match.pro 
; - Morris/SAIC/GPM_GV   October 2008
;
; DESCRIPTION
; -----------
; Reads PR and GV reflectivity and rainrate fields from geo_match netCDF files,
; builds index arrays of categories of range, rain type, bright band proximity
; (above, below, within), and height (13 categories, 1.5-19.5 km levels); and
; an array of actual range.  Computes max and mean PR and GV rainrate and 
; mean PR-GV rainrate differences and standard deviation of the differences
; for each of the 13 height levels for points within 100 km of the ground radar.
;
; GV rainrate is computed from the ground radar reflectivity using a default Z-R
; relationship for the WSR-88D: Z=300R^1.4 as defined in z_r_rainrate().
;
; Statistical results are stratified by raincloud type (Convective, Stratiform)
; and vertical location w.r.t the bright band (above, within, below), and in
; total for all eligible points, for a total of 7 permutations.  These 7
; permutations are further stratified by the points' distance from the radar in
; 3 categories: 0-49km, 50-99km, and (if present) 100-150km, for a grand total
; of 21 raintype/location/range categories.  The results and their identifying
; metadata are written out to an ASCII, delimited text file in a format ready
; to be loaded into the table 'dbzdiff_stats_by_dist_geo' in the 'gpmgv'
; database.
;
; PARAMETERS
; ----------
; None.
;
; FILES
; -----
; /data/tmp/StatsByDistToDBbyGeo.unl   OUTPUT: Formatted ASCII text file holding
;                                              the computed, stratified PR-GV
;                                              reflectivity statistics and its
;                                              identifying metadata fields.
; /data/netcdf/geo_match/*              INPUT: The set of site/orbit specific
;                                              netCDF grid files for which
;                                              stats are to be computed.  The
;                                              files used are controlled in code
;                                              by the file pattern specified for
;                                              the 'pathpr' internal variable.
;
; PARAMETERS
; ----------
;
; pctAbvThresh - constraint on the percent of bins in the geometric-matching
;                volume that were above their respective thresholds, specified
;                at the time the geo-match dataset was created.  Essentially a
;                measure of "beam-filling goodness".  100 means use only those
;                matchup points where all the PR and GV bins in the volume
;                averages were above threshold (complete volume filled with
;                above threshold bin values).  0 means use all matchup points
;                available, with no regard for thresholds.  Default=100
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
; CALLS
; -----
; uncomp_file()    stratify_diffs21dist_geo    printf_stat_struct21dist
; gv_orbit_match()
;
; HISTORY
; -------
; 03/15/10 Morris, GPM GV, SAIC
; - Created from stratified_by_dist_stats_to_dbfile_geo_match.pro, modified to
;   compute 3-D rainrate differences.
; 04/23/10  Morris/GPM GV/SAIC
; - Modified computation of the mean bright band height to exclude points with
;   obvious overestimates of BB height in the 2A25 rangeBinNums.
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;===============================================================================


pro stratified_by_dist_rr_stats_to_dbfile_geo_match, $
         PCT_ABV_THRESH=pctAbvThresh, GV_CONVECTIVE=gv_convective,  $
         GV_STRATIFORM=gv_stratiform, CORRECT_S_BAND=correct_s_band

; "include" file for structs returned by read_geo_match_netcdf()
@geo_match_nc_structs.inc

; "include" file for PR data constants
@pr_params.inc

dbfile = '/data/tmp/RR_StatsByDistToDBbyGeo_23Apr2010newBBallGVorig.unl'
OPENW, DBunit, dbfile, /GET_LUN

statsset = { event_stats, $
            AvgDif: -99.999, StdDev: -99.999, $
            PRmaxZ: -99.999, PRavgZ: -99.999, $
            GVmaxZ: -99.999, GVavgZ: -99.999, $
            N: 0L $
           }

allstats = { stats7ways, $
	    stats_total:       {event_stats}, $
            stats_convbelow:   {event_stats}, $
	    stats_convin:      {event_stats}, $
	    stats_convabove:   {event_stats}, $
	    stats_stratbelow:  {event_stats}, $
	    stats_stratin:     {event_stats}, $
	    stats_stratabove:  {event_stats}  $
           }

; We will make a copy of this structure variable for each level and GV type
; we process so that everything is re-initialized.
statsbydist = { stats21ways, $
              km_le_50:    {stats7ways}, $
              km_50_100:     {stats7ways}, $
              km_gt_100:   {stats7ways}, $
              pts_le_50:  0L, $
              pts_50_100:   0L, $
              pts_gt_100: 0L  $
             }


; Decide which PR and GV points to include, based on percent of expected points
; in bin-averaged results that were above dBZ thresholds set when the matchups
; were done.  If unspecified, set to 100% of bins required (as before this code
; change).  If set to zero, include all points regardless of 'completeness' of
; the volume averages.

IF ( N_ELEMENTS(pctAbvThresh) NE 1 ) THEN BEGIN
   print, "Defaulting to 100 for PERCENT BINS ABOVE THRESHOLD."
   pctAbvThresh = 100
   pctAbvThreshF = FLOAT(pctAbvThresh)
ENDIF ELSE BEGIN
   pctAbvThreshF = FLOAT(pctAbvThresh)
   IF ( pctAbvThreshF LT 0.0 OR pctAbvThreshF GT 100.0 ) THEN BEGIN
      print, "Invalid value for PCT_ABV_THRESH: ", pctAbvThresh, $
             ", must be between 0 and 100."
      print, "Defaulting to 100 for PERCENT BINS ABOVE THRESHOLD."
      pctAbvThreshF = 100.0
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

correct_s_band = KEYWORD_SET( correct_s_band )

pathpr = '/data/netcdf/geo_match/GRtoPR.*.nc.*'
lastsite='NA'
lastorbitnum=0
lastncfile='NA'
;ncfilepr = dialog_pickfile(path=pathpr)

;while ncfilepr ne '' do begin

prfiles = file_search(pathpr,COUNT=nf)
if nf gt 0 then begin

for fnum = 0, nf-1 do begin

ncfilepr = prfiles(fnum)
bname = file_basename( ncfilepr )
prlen = strlen( bname )
print, "GeoMatch netCDF file: ", ncfilepr

parsed = strsplit(bname, '.', /EXTRACT)
site = parsed[1]
orbit = parsed[3]
orbitnum=FIX(orbit)

; set up to skip the non-calibrated KWAJ data files, else we get duplicates
kwajver = parsed[4]
IF ( site EQ 'KWAJ' and kwajver NE 'cal' ) THEN CONTINUE

; skip duplicate orbit for given site
IF ( site EQ lastsite AND orbitnum EQ lastorbitnum ) THEN BEGIN
   print, ""
   print, "Skipping duplicate site/orbit file ", bname, ", last file done was ", lastncfile
   CONTINUE
ENDIF

; Get uncompressed copy of the found files
cpstatus = uncomp_file( ncfilepr, ncfile1 )
if ( cpstatus eq 'OK' ) then begin
  status = 1   ; init to FAILED

 ; initialize metadata structures and read metadata
  mygeometa={ geo_match_meta }
  mysweeps={ gv_sweep_meta }
  mysite={ gv_site_meta }
  myflags={ pr_gv_field_flags }
  status = read_geo_match_netcdf( ncfile1, matchupmeta=mygeometa, $
     sweepsmeta=mysweeps, sitemeta=mysite, fieldflags=myflags )

 ; create data field arrays of correct dimensions and read data fields
  nfp = mygeometa.num_footprints
  nswp = mygeometa.num_sweeps
  gvexp=intarr(nfp,nswp)
  gvrej=intarr(nfp,nswp)
  prexp=intarr(nfp,nswp)
  zrawrej=intarr(nfp,nswp)
  zcorrej=intarr(nfp,nswp)
  rainrej=intarr(nfp,nswp)
  gvz=intarr(nfp,nswp)
  zraw=fltarr(nfp,nswp)
  zcor=fltarr(nfp,nswp)
  rain3=fltarr(nfp,nswp)
  top=fltarr(nfp,nswp)
  botm=fltarr(nfp,nswp)
  lat=fltarr(nfp,nswp)
  lon=fltarr(nfp,nswp)
  bb=fltarr(nfp)
  rnflag=intarr(nfp)
  rntype=intarr(nfp)
  pr_index=lonarr(nfp)

  status = read_geo_match_netcdf( ncfile1, $
     gvexpect_int=gvexp, gvreject_int=gvrej, prexpect_int=prexp, $
     zrawreject_int=zrawrej, zcorreject_int=zcorrej, rainreject_int=rainrej, $
     dbzgv=gvz, dbzcor=zcor, dbzraw=zraw, rain3d=rain3, topHeight=top, $
     bottomHeight=botm, latitude=lat, longitude=lon, bbhgt=BB, $
     rainflag_int=rnFlag, raintype_int=rnType, pridx_long=pr_index )

  command3 = "rm -v " + ncfile1
  spawn, command3
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

max_gvz_per_fp = MAX( gvz, DIMENSION=2)  ; max GV dBZ along each PR ray
IF ( gvstratiform GT 0.0 ) THEN BEGIN
   idx2other = WHERE( rnType EQ 2 AND max_gvz_per_fp LE gvstratiform, count2other )
   IF ( count2other GT 0 ) THEN rnType[idx2other] = 3
   fmtstrng='("No. of footprints switched from Convective to Other = ",I0,",' $
            +' based on Stratiform dBZ threshold = ",F0.1)'
   print, FORMAT=fmtstrng, count2other, gvstratiform
ENDIF ELSE BEGIN
   print, "Leaving PR Convective Rain Type assignments unchanged."
ENDELSE
IF ( gvconvective GT 0.0 ) THEN BEGIN
   idx2other = WHERE( rnType EQ 1 AND max_gvz_per_fp GE gvconvective, count2other )
   IF ( count2other GT 0 ) THEN rnType[idx2other] = 3
   fmtstrng='("No. of footprints switched from Stratiform to Other = ",I0,",' $
            +' based on Convective dBZ threshold = ",F0.1)'
   print, FORMAT=fmtstrng, count2other, gvconvective
ENDIF ELSE BEGIN
   print, "Leaving PR Stratiform Rain Type assignments unchanged."
ENDELSE

;-------------------------------------------------------------
; clip the data fields down to the "actual footprint" points

; get array indices of the non-bogus footprints
idxpractual = where(pr_index GE 0L, countactual)
if (countactual EQ 0) then begin
   print, "No non-bogus data points, quitting case."
   goto, errorExit
endif

;------------------------
; Clip single-level field first (don't need BB replicated to all sweeps):
BB = BB[idxpractual]

;------------------------
; Now do the sweep-level arrays - have to build an array index of actual
; points, replicated over all the sweep levels
idx3d=long(gvexp)   ; take one of the 2D arrays, make it LONG type
idx3d[*,*] = 0L     ; initialize all points to 0

; set the first sweep level's values to 1 where non-bogus
idx3d[idxpractual,0] = 1L
  
; copy the first sweep to the other levels, and make the single-level arrays
; for categorical fields the same dimension as the sweep-levels', using IDL's
; array concatenation feature
rnFlagApp = rnFlag
rnTypeApp = rnType
IF ( nsweeps GT 1 ) THEN BEGIN  
   FOR iswp=1, nsweeps-1 DO BEGIN
      idx3d[*,iswp] = idx3d[*,0]
      rnFlag = [rnFlag, rnFlagApp]  ; concatenate another level's worth
      rnType = [rnType, rnTypeApp]
   ENDFOR
ENDIF

; get the indices of all the non-bogus points in the multi-level arrays
idxpractual2d = where( idx3d EQ 1L, countactual2d )
if (countactual2d EQ 0) then begin
  ; this shouldn't be able to happen
   print, "No non-bogus 2D data points, quitting case."
   goto, errorExit
endif

; clip the sweep-level arrays to the non-bogus point set
gvexp = gvexp[idxpractual2d]
gvrej = gvrej[idxpractual2d]
prexp = prexp[idxpractual2d]
zrawrej = zrawrej[idxpractual2d]
zcorrej = zcorrej[idxpractual2d]
rainrej = rainrej[idxpractual2d]
gvz = gvz[idxpractual2d]
zraw = zraw[idxpractual2d]
zcor = zcor[idxpractual2d]
rain3 = rain3[idxpractual2d]
top = top[idxpractual2d]
botm = botm[idxpractual2d]
lat = lat[idxpractual2d]
lon = lon[idxpractual2d]
rnFlag = rnFlag[idxpractual2d]
rnType = rnType[idxpractual2d]

;=========================================================================

; data clipping based on percent completeness of the volume averages

IF ( pctAbvThreshF GT 0.0 ) THEN BEGIN
   IF ( pctAbvThreshF EQ 100.0 ) THEN BEGIN
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
      endif ELSE BEGIN
         print, "No complete-volume points, quitting case."
         goto, nextFile
      endelse
   ENDIF ELSE BEGIN
    ; clip to the 'good' points, where 'pctAbvThreshF' fraction of bins in average
    ; were above threshold
      idxexpgt0 = WHERE( prexp GT 0 AND gvexp GT 0, countexpgt0 )
      IF ( countexpgt0 EQ 0 ) THEN BEGIN
         print, "No valid volume-average points, quitting case."
         goto, nextFile
      ENDIF ELSE BEGIN
         pctgoodpr = 100.0 * FLOAT( prexp[idxexpgt0] - zcorrej[idxexpgt0] ) / prexp[idxexpgt0]
         pctgoodgv = 100.0 * FLOAT( gvexp[idxexpgt0] - gvrej[idxexpgt0] ) / gvexp[idxexpgt0]
         idxgoodpct = WHERE( pctgoodpr GE pctAbvThreshF $
                        AND  pctgoodgv GE pctAbvThreshF, countgoodpct )
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
         ENDIF ELSE BEGIN
            print, "No complete-volume points, quitting case."
            goto, nextFile
         ENDELSE
      ENDELSE
   ENDELSE
ENDIF

;-------------------------------------------------------------

; convert bright band heights from m to km, where defined, and get mean BB hgt
; first, find the indices of stratiform rays with BB defined
idxbbdef = where(bb GT 0.0 AND rnTypeApp[idxpractual] EQ 1, countBB)
if ( countBB GT 0 ) THEN BEGIN
  ; grab the subset of BB values for defined/stratiform
   bb2hist = bb[idxbbdef]/1000.  ; with conversion to km
   bs=0.2  ; bin width, in km, for HISTOGRAM in get_mean_bb_height()
  ; do some sorcery to find the best mean BB height estimate, in km
   meanbb = get_mean_bb_height( bb2hist, BS=bs )
   meanbb_m = FIX(meanbb*1000.)        ; back to m, in INT
;  Level below BB is affected if BB_Hgt is within 1000m above layer center,
;  so BB_HgtLo is index of lowest layer considered to be within the BB
   BB_HgtLo = (meanbb_m-1001)/1500
;  Level above BB is affected if BB_Hgt is 1000m or less below layer center,
;  so BB_HgtHi is index of highest layer considered to be within the BB
   BB_HgtHi = (meanbb_m-500)/1500
   BB_HgtLo = BB_HgtLo < 12
   BB_HgtHi = BB_HgtHi < 12
print, 'Mean BB (km), bblo, bbhi = ', meanbb, BB_HgtLo, BB_HgtHi
ENDIF ELSE BEGIN
   print, "No valid bright band heights, quitting case."
   goto, nextFile
ENDELSE

; build an array of BB proximity: 0 if below, 1 if within, 2 if above
BBprox = gvexp & BBprox[*] = 1
; define above (below) BB as bottom (top) of beam at least 750m above
; (750m below) mean BB height
idxbelowbb = where( top LE (meanbb-0.750), countbelowbb )
if ( countbelowbb GT 0 ) then BBprox[idxbelowbb] = 0
idxabovebb = where( botm GE (meanbb+0.750), countabovebb )
if ( countabovebb GT 0 ) then BBprox[idxabovebb] = 2
;idxinbb = where( BBprox EQ 1, countinbb )

; APPLY FREQUENCY DIFFERENCE CORRECTION TO REFLECTIVITIES IF PARAMETER IS SET

IF ( correct_s_band ) THEN BEGIN
   print, "=================================================================="
   print, "Applying rain/snow adjustments to S-band to match Ku reflectivity."
   print, "=================================================================="
   if ( countabovebb GT 0 ) then begin
     ; apply correction to above-BB (snow) S-band GV samples
      gvz4snow = gvz[idxabovebb]
     ; find those points with non-missing reflectivity values
      idx2ku = WHERE( gvz4snow GT 0.0, count2ku )
      IF count2ku GT 0 THEN BEGIN
        ; perform the conversion and replace the original values
         gvz[idxabovebb[idx2ku]] = s_band_to_ku_band( gvz4snow[idx2ku], 'S' )
      ENDIF ELSE print, "No above-BB points for S-to-Ku snow correction"
   endif

   if ( countbelowbb GT 0 ) then begin
     ; apply correction to below-BB (all-rain) S-band GV samples
      gvz4rain = gvz[idxbelowbb]
      idx2ku = WHERE( gvz4rain GT 0.0, count2ku )
      IF count2ku GT 0 THEN BEGIN
         gvz[idxbelowbb[idx2ku]] = s_band_to_ku_band( gvz4rain[idx2ku], 'R' )
      ENDIF ELSE print, "No below-BB points for S-to-Ku rain correction"
   endif
ENDIF

; CONVERT GR REFLECTIVITY TO RAIN RATE USING DEFAULT WSR-88D Z-R RELATIONSHIP
gvrr = z_r_rainrate(gvz)

; discard the points where rain rate volume averages are zero or missing
idxrrgt0 = WHERE (gvrr GT 0.0 AND rain3 GT 0.0, countrainok)
IF countrainok GT 0 THEN BEGIN
   gvz = gvz[idxrrgt0]
   zraw = zraw[idxrrgt0]
   zcor = zcor[idxrrgt0]
   gvrr = gvrr[idxrrgt0]
   rain3 = rain3[idxrrgt0]
   top = top[idxrrgt0]
   botm = botm[idxrrgt0]
   lat = lat[idxrrgt0]
   lon = lon[idxrrgt0]
   rnFlag = rnFlag[idxrrgt0]
   rnType = rnType[idxrrgt0]
ENDIF ELSE BEGIN
   print, "No above-zero rainrate points, quitting case."
   goto, nextFile
ENDELSE

; build an array of ranges, range categories from the GV radar
; initialize a gv-centered map projection for the ll<->xy transformations:
sMap = MAP_PROJ_INIT( 'Azimuthal Equidistant', center_latitude=site_lat, $
                      center_longitude=site_lon )
XY_km = map_proj_forward( lon, lat, map_structure=smap ) / 1000.
dist = SQRT( XY_km[0,*]^2 + XY_km[1,*]^2 )

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
      if ( counthgts GT 0 ) THEN BEGIN
         print, "HEIGHT = "+hgtstr+" km: npts = ", counthgts, " min = ", $
            min(beamhgt[idxhgt]), " max = ", max(beamhgt[idxhgt])
      endif else begin
         print, "HEIGHT = "+hgtstr+" km: npts = ", counthgts
      endelse
   ENDFOR
ENDIF ELSE BEGIN
   maxbeamtop = max( (top+botm)/2.0 )
   print, ""
   print, "Highest beam midpoint = ", maxbeamtop
   print, "No valid beam heights, quitting case."
   print, ""
   goto, nextFile
ENDELSE

;# # # # # # # # # # # # # # # # # # # # # # # # #
; Compute a mean RAINRATE difference at each level

for lev2get = 0, 12 do begin
   IF ( num_in_hgt_cat[lev2get] GT 0 ) THEN BEGIN
      thishgt = (lev2get+1)*1.5
     ; identify the subset of points at this height level
      idxathgt = WHERE( hgtcat EQ lev2get, countathgt )
      dbzcorlev = rain3[idxathgt]
      dbznexlev = gvrr[idxathgt]
      raintypelev = rntype[idxathgt]
      distcatlev = distcat[idxathgt]
      BBproxlev = BBprox[idxathgt]
      this_statsbydist = {stats21ways}

      stratify_diffs21dist_geo, dbzcorlev, dbznexlev, raintypelev, BBproxlev, $
                                distcatlev, this_statsbydist

     ; Write Delimited Output for database
      printf_stat_struct21dist, this_statsbydist, pctAbvThresh, 'GeoM', siteID, $
                                orbit, lev2get, DBunit
   ENDIF
endfor


nextFile:
lastorbitnum=orbitnum
lastncfile=bname
lastsite=site
endfor    ; fnum = 0, nf-1
endif     ; nf gt 0

print, ''
print, 'Done!'
print, ''
print, 'Output file status:'
command = 'ls -al ' + dbfile
spawn, command
errorExit:

FREE_LUN, DBunit

end

@stratify_diffs21dist_geo.pro
@printf_stat_struct21dist.pro
