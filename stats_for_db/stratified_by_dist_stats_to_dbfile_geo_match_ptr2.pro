;+
; stratified_by_dist_stats_to_dbfile_geo_match_ptr2.pro 
; - Morris/SAIC/GPM_GV   October 2008
;
; DESCRIPTION
; -----------
; Reads PR and GV reflectivity and spatial fields from geo_match netCDF files,
; builds index arrays of categories of range, rain type, bright band proximity
; (above, below, within), and height (13 categories, 1.5-19.5 km levels); and
; an array of actual range.  Computes max and mean PR and GV reflectivity and 
; mean PR-GV reflectivity differences and standard deviation of the differences
; for each of the 13 height levels for points within 100 km of the ground radar.
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
; stratify_diffs21dist_geo   stratify_diffs_geo    printf_stat_struct21dist
; fprep_geo_match_profiles()
;
; HISTORY
; -------
; 01/26/09 Morris, GPM GV, SAIC
; - Added GV rain type consistency check with PR rain type, based on GV dBZ
;   values: GV is convective if >=35 dBZ; GV is stratiform if <=25 dBZ.
; 01/27/09 Morris, GPM GV, SAIC
; - Added a threshold for the percent of expected bins above their cutoff values
;   as set at the time the matchups were generated.  We had been requiring 100%
;   complete (gvrej EQ 0 AND zcorrej EQ 0).  Now we set a threshold and write
;   this value in first column of the output data.
; 03/04/09 Morris, GPM GV, SAIC
; - Added gv_convective and gv_stratiform as optional parameters to replace
;   hard-coded values.
; 03/25/09 Morris, GPM GV, SAIC
; - Changed width of bright band influence to 500m above thru 750m below meanBB,
;   from original +/-250m of meanBB, based on what PR cross sections show.
; 06/10/09 Morris, GPM GV, SAIC
; - Added ability to call S-band to Ku-band adjustment function, and added
;   CORRECT_S_BAND binary keyword parameter that controls whether these
;   corrections are to be applied.
; Late2009 Morris, GPM GV, SAIC
; - Added checks for duplicate events (site.orbit combinations).
; 03/15/10 Morris, GPM GV, SAIC
; - Minor change to print statements for level by level vs BB information
; 04/23/10  Morris/GPM GV/SAIC
; - Modified computation of the mean bright band height to exclude points with
;   obvious overestimates of BB height in the 2A25 rangeBinNums.  Modified the
;   depth-of-influence of the bright band to +/- 750m of mean BB height.
; 05/25/10  Morris/GPM GV/SAIC
; - Created from stratified_by_dist_stats_to_dbfile_geo_match.pro.  Modified to
;   call fprep_geo_match_profiles() to read netCDF files and compute most of the
;   derived fields needed for this procedure, including mean bright band height
;   and proximity to bright band as in 4/23/10 changes.
; 11/10/10  Morris/GPM GV/SAIC
; - Modified filtering based on pctAbvThresh to at least filter out no-data
;   points when the percent threshold is zero (take all points).
; - Changed CORRECT_S_BAND binary keyword parameter name to S2KU
; - Added NAME_ADD parameter to distinguish output filenames for different runs,
;   and NCSITEPATH parameter to filter input geo_match netCDF file set.
; 11/30/10  Morris/GPM GV/SAIC
; - Drop geo_match variables not used: top, botm, lat, lon, xcorner, ycorner,
;   pr_index.
; - Add reading and processing of gvzmax and gvzstddev if Version 2 netcdf file.
; 12/6/10  Morris/GPM GV/SAIC
; - Modified to continue to next file in case of error status from
;   fprep_geo_match_profiles2().
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;===============================================================================


pro stratified_by_dist_stats_to_dbfile_geo_match_ptr2, PCT_ABV_THRESH=pctAbvThresh,  $
                                                  GV_CONVECTIVE=gv_convective,  $
                                                  GV_STRATIFORM=gv_stratiform,  $
                                                  S2KU=s2ku, NAME_ADD=name_add, $
                                                  NCSITEPATH=ncsitepath,        $
                                                  OUTPATH=outpath,              $
                                                  GRMAXTHRESH=grmaxthresh,      $
                                                  GRSTDDEVTHRESH=grstddevthresh

; "include" file for structs returned by read_geo_match_netcdf()
@geo_match_nc_structs.inc

; "include" file for PR data constants
@pr_params.inc

statsset = { event_stats, $
            AvgDif: -99.999, StdDev: -99.999, $
            PRmaxZ: -99.999, PRavgZ: -99.999, $
            GVmaxZ: -99.999, GVavgZ: -99.999, $
            GVabsmaxZ: -99.999, GVmaxstddevZ: -99.999, $
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

IF N_ELEMENTS(name_add) EQ 1 THEN $
   addme = '_'+STRTRIM(STRING(name_add),2) $
ELSE addme = ''

IF N_ELEMENTS(grstddevthresh) EQ 1 THEN $
   addme = '_GRStdDev'+STRTRIM(STRING(grstddevthresh),2) + addme

IF N_ELEMENTS(grmaxthresh) EQ 1 THEN $
   addme = '_GRMax'+STRTRIM(STRING(grmaxthresh),2) + addme

s2ku = KEYWORD_SET( s2ku )

IF N_ELEMENTS(outpath) NE 1 THEN BEGIN
   outpath='/data/tmp'
   PRINT, "Assigning default output file path: ", outpath
ENDIF
IF ( s2ku ) THEN dbfile = outpath+'/StatsByDistToDBGeo_Pct'+strtrim(string(pctAbvThresh),2)+addme+'_S2Ku.unl' $
ELSE dbfile = outpath+'/StatsByDistToDBGeo_Pct'+strtrim(string(pctAbvThresh),2)+addme+'_DefaultS.unl'

PRINT, "Write output to: ", dbfile
OPENW, DBunit, dbfile, /GET_LUN

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

IF N_ELEMENTS(ncsitepath) EQ 1 THEN pathpr=ncsitepath+'*' $
ELSE pathpr = '/data/netcdf/geo_match/GRtoPR.*.nc*'

lastsite='NA'
lastorbitnum=0
lastncfile='NA'

prfiles = file_search(pathpr,COUNT=nf)
IF (nf LE 0) THEN BEGIN
   print, "" 
   print, "No files found for pattern = ", pathpr
   print, " -- Exiting."
   GOTO, errorExit
ENDIF

; set up pointers for each field to be returned from fprep_geo_match_profiles()
ptr_geometa=ptr_new(/allocate_heap)
ptr_sweepmeta=ptr_new(/allocate_heap)
ptr_sitemeta=ptr_new(/allocate_heap)
ptr_fieldflags=ptr_new(/allocate_heap)
ptr_gvz=ptr_new(/allocate_heap)
 ; new in Version 2 geo-match files
  ptr_gvzmax=ptr_new(/allocate_heap)
  ptr_gvzstddev=ptr_new(/allocate_heap)
ptr_zcor=ptr_new(/allocate_heap)
ptr_zraw=ptr_new(/allocate_heap)
ptr_rain3=ptr_new(/allocate_heap)
ptr_nearSurfRain=ptr_new(/allocate_heap)
ptr_nearSurfRain_2b31=ptr_new(/allocate_heap)
ptr_rnFlag=ptr_new(/allocate_heap)
ptr_rnType=ptr_new(/allocate_heap)
ptr_bbProx=ptr_new(/allocate_heap)
ptr_hgtcat=ptr_new(/allocate_heap)
ptr_dist=ptr_new(/allocate_heap)
ptr_pctgoodpr=ptr_new(/allocate_heap)
ptr_pctgoodgv=ptr_new(/allocate_heap)
ptr_pctgoodrain=ptr_new(/allocate_heap)

; structure to hold bright band variables
BBparms = {meanBB : -99.99, BB_HgtLo : -99, BB_HgtHi : -99}

; Define the list of fixed-height levels for the vertical profile statistics
heights = [1.5,3.0,4.5,6.0,7.5,9.0,10.5,12.0,13.5,15.0,16.5,18.0,19.5]
hgtinterval = 1.5
;heights = [1.0,2.0,3.0,4.0,5.0,6.0,7.0,8.0,9.0,10.0,11.0,12.0,13.0,14.0,15.0,16.0,17.0,18.0]
;hgtinterval = 1.0
print, 'pctAbvThresh = ', pctAbvThresh

FOR fnum = 0, nf-1 DO BEGIN

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
   skipping=0
   IF ( site EQ 'KWAJ' and kwajver NE 'cal' ) THEN skipping=1
;   IF ( site EQ 'KWAJ' and STRPOS(bname, 'v') NE -1 ) THEN skipping=1
;   IF ( site EQ 'KMLB' and STRPOS(bname, 'v') NE -1 ) THEN skipping=1
   IF ( STRPOS(bname, 'Multi') NE -1 ) THEN skipping=1
   IF ( skipping EQ 1 ) THEN BEGIN
      print, "Skipping file: ", bname
      CONTINUE
   ENDIF

; skip duplicate orbit for given site
   IF ( site EQ lastsite AND orbitnum EQ lastorbitnum ) THEN BEGIN
      print, ""
      print, "Skipping duplicate site/orbit file ", bname, ", last file done was ", lastncfile
      CONTINUE
   ENDIF

; read the geometry-match variables and arrays from the file, and preprocess them
; to remove the 'bogus' PR ray positions.  Return a pointer to each variable read.

   status = fprep_geo_match_profiles2( ncfilepr, heights, $
       PCT_ABV_THRESH=pctAbvThresh, GV_CONVECTIVE=gvconvective, $
       GV_STRATIFORM=gvstratiform, S2KU=s2ku, PTRfieldflags=ptr_fieldflags, $
       PTRgeometa=ptr_geometa, PTRsweepmeta=ptr_sweepmeta, PTRsitemeta=ptr_sitemeta, $
       PTRGVZ=ptr_gvz, PTRGVMAX=ptr_gvzmax, PTRGVSTDDEV=ptr_gvzstddev, $
       PTRzcor=ptr_zcor, PTRzraw=ptr_zraw, PTRrain3d=ptr_rain3, $
       PTRsfcrainpr=ptr_nearSurfRain, PTRsfcraincomb=ptr_nearSurfRain_2b31, $
       PTRrainflag_int=ptr_rnFlag, PTRraintype_int=ptr_rnType, PTRbbProx=ptr_bbProx, $
       PTRhgtcat=ptr_hgtcat, PTRdist=ptr_dist, PTRpctgoodpr=ptr_pctgoodpr, $
       PTRpctgoodgv=ptr_pctgoodgv, PTRpctgoodrain=ptr_pctgoodrain, BBPARMS=BBparms )

   IF (status EQ 1) THEN GOTO, nextFile

; memory-pass pointer variables to "normal-named" data field arrays/structures
; -- this is so we can use existing code without the need to use pointer
;    dereferencing syntax
   mygeometa=temporary(*ptr_geometa)
   mysite=temporary(*ptr_sitemeta)
   mysweeps=temporary(*ptr_sweepmeta)
   myflags=temporary(*ptr_fieldflags)
   gvz=temporary(*ptr_gvz)
  gvzmax=*ptr_gvzmax
  gvzstddev=*ptr_gvzstddev
   zraw=temporary(*ptr_zraw)
   zcor=temporary(*ptr_zcor)
   rain3=temporary(*ptr_rain3)
   nearSurfRain=temporary(*ptr_nearSurfRain)
   nearSurfRain_2b31=temporary(*ptr_nearSurfRain_2b31)
   rnflag=temporary(*ptr_rnFlag)
   rntype=temporary(*ptr_rnType)
   bbProx=temporary(*ptr_bbProx)
   hgtcat=temporary(*ptr_hgtcat)
   dist=temporary(*ptr_dist)
   pctgoodpr=temporary(*ptr_pctgoodpr)
   pctgoodgv=temporary(*ptr_pctgoodgv)
   pctgoodrain=temporary(*ptr_pctgoodrain)

; extract some needed values from the metadata structures
   site_lat = mysite.site_lat
   site_lon = mysite.site_lon
   siteID = string(mysite.site_id)
   nsweeps = mygeometa.num_sweeps

;=========================================================================

; Optional data clipping based on percent completeness of the volume averages:

; Decide which PR and GV points to include, based on percent of expected points
; in bin-averaged results that were above dBZ thresholds set when the matchups
; were done.  If unspecified or set to zero, include all points regardless of
; 'completeness' of the volume averages, as long as there was at least one valid
; gate value in the sample average.


   IF ( pctAbvThreshF GT 0.0 ) THEN BEGIN
       ; clip to the 'good' points, where 'pctAbvThreshF' fraction of bins in average
       ; were above threshold
      idxgoodenuff = WHERE( pctgoodpr GE pctAbvThreshF $
                       AND  pctgoodgv GE pctAbvThreshF, countgoodpct )
   ENDIF ELSE BEGIN
      idxgoodenuff = WHERE( pctgoodpr GT 0.0 AND pctgoodgv GT 0.0, countgoodpct )
   ENDELSE

      IF ( countgoodpct GT 0 ) THEN BEGIN
          gvz = gvz[idxgoodenuff]
          zraw = zraw[idxgoodenuff]
          zcor = zcor[idxgoodenuff]
          rain3 = rain3[idxgoodenuff]
          gvzmax = gvzmax[idxgoodenuff]
          gvzstddev = gvzstddev[idxgoodenuff]
          rnFlag = rnFlag[idxgoodenuff]
          rnType = rnType[idxgoodenuff]
          dist = dist[idxgoodenuff]
          bbProx = bbProx[idxgoodenuff]
          hgtcat = hgtcat[idxgoodenuff]
      ENDIF ELSE BEGIN
          print, "No complete-volume points, quitting case."
          goto, nextFile
      ENDELSE

;-------------------------------------------------------------

; build an array of BB proximity: 0 if below, 1 if within, 2 if above
;#######################################################################################
; NOTE THESE CATEGORY NUMBERS ARE ONE LOWER THAN THOSE IN FPREP_GEO_MATCH_PROFILES() !!
;#######################################################################################
   BBprox = BBprox - 1


; build an array of range categories from the GV radar, using ranges previously
; computed from lat and lon by fprep_geo_match_profiles():
; - range categories: 0 for 0<=r<50, 1 for 50<=r<100, 2 for r>=100, etc.
;   (for now we only have points roughly inside 100km, so limit to 2 categs.)
   distcat = ( FIX(dist) / 50 ) < 1


; get info from array of height category for the fixed-height levels, for profiles
   nhgtcats = N_ELEMENTS(heights)
   num_in_hgt_cat = LONARR( nhgtcats )
   FOR i=0, nhgtcats-1 DO BEGIN
      hgtstr =  string(heights[i], FORMAT='(f0.1)')
      idxhgt = where(hgtcat EQ i, counthgts)
      num_in_hgt_cat[i] = counthgts
      if ( counthgts GT 0 ) THEN print, "HEIGHT = "+hgtstr+" km: npts = ", counthgts
   ENDFOR

  ;# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
  ; HSIAO-FEI : Replace this block of code with your
  ; own code to build up the data points for the
  ; histogram, by appending arrays or writing the
  ; values to a file.
  ;# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

  ; Compute a mean dBZ difference at each level
   for lev2get = 0, 12 do begin
      IF ( num_in_hgt_cat[lev2get] GT 0 ) THEN BEGIN
         thishgt = (lev2get+1)*1.5
        ; identify the subset of points at this height level
         idxathgt = WHERE( hgtcat EQ lev2get, countathgt )
         dbzcorlev = zcor[idxathgt]
         dbznexlev = gvz[idxathgt]
         raintypelev = rntype[idxathgt]
         distcatlev = distcat[idxathgt]
         BBproxlev = BBprox[idxathgt]
         gvzmaxlev = gvzmax[idxathgt]
         gvzstddevlev = gvzstddev[idxathgt]
         this_statsbydist = {stats21ways}

         stratify_diffs21dist_geo2, dbzcorlev, dbznexlev, raintypelev, BBproxlev, $
                            distcatlev, gvzmaxlev, gvzstddevlev, this_statsbydist

        ; Write Delimited Output for database
         printf_stat_struct21dist2, this_statsbydist, pctAbvThresh, 'GeoM', siteID, $
                                    orbit, lev2get, DBunit
      ENDIF
   endfor

  ;# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
  ;# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

   nextFile:
   lastorbitnum=orbitnum
   lastncfile=bname
   lastsite=site

ENDFOR    ; end of loop over fnum = 0, nf-1


; pass memory of local-named data field array/structure names back to pointer variables
*ptr_geometa=temporary(mygeometa)
*ptr_sitemeta=temporary(mysite)
*ptr_sweepmeta=temporary(mysweeps)
*ptr_fieldflags=temporary(myflags)
*ptr_gvz=temporary(gvz)
*ptr_zraw=temporary(zraw)
*ptr_zcor=temporary(zcor)
*ptr_rain3=temporary(rain3)
 *ptr_gvzmax=temporary(gvzmax)
 *ptr_gvzstddev=temporary(gvzstddev)
*ptr_nearSurfRain=temporary(nearSurfRain)
*ptr_nearSurfRain_2b31=temporary(nearSurfRain_2b31)
*ptr_rnflag=temporary(rnFlag)
*ptr_rntype=temporary(rnType)
*ptr_bbProx=temporary(bbProx)
*ptr_hgtcat=temporary(hgtcat)
*ptr_dist=temporary(dist)
*ptr_pctgoodpr=temporary(pctgoodpr)
*ptr_pctgoodgv=temporary(pctgoodgv)
*ptr_pctgoodrain=temporary(pctgoodrain)

;  free the memory held by the pointer variables
if (ptr_valid(ptr_geometa) eq 1) then ptr_free,ptr_geometa
if (ptr_valid(ptr_sitemeta) eq 1) then ptr_free,ptr_sitemeta
if (ptr_valid(ptr_sweepmeta) eq 1) then ptr_free,ptr_sweepmeta
if (ptr_valid(ptr_fieldflags) eq 1) then ptr_free,ptr_fieldflags
if (ptr_valid(ptr_gvz) eq 1) then ptr_free,ptr_gvz
if (ptr_valid(ptr_zraw) eq 1) then ptr_free,ptr_zraw
if (ptr_valid(ptr_zcor) eq 1) then ptr_free,ptr_zcor
if (ptr_valid(ptr_rain3) eq 1) then ptr_free,ptr_rain3
 if (ptr_valid(ptr_gvzmax) eq 1) then ptr_free,ptr_gvzmax
 if (ptr_valid(ptr_gvzstddev) eq 1) then ptr_free,ptr_gvzstddev
if (ptr_valid(ptr_nearSurfRain) eq 1) then ptr_free,ptr_nearSurfRain
if (ptr_valid(ptr_nearSurfRain_2b31) eq 1) then ptr_free,ptr_nearSurfRain_2b31
if (ptr_valid(ptr_rnFlag) eq 1) then ptr_free,ptr_rnFlag
if (ptr_valid(ptr_rnType) eq 1) then ptr_free,ptr_rnType
if (ptr_valid(ptr_bbProx) eq 1) then ptr_free,ptr_bbProx
if (ptr_valid(ptr_hgtcat) eq 1) then ptr_free,ptr_hgtcat
if (ptr_valid(ptr_dist) eq 1) then ptr_free,ptr_dist
if (ptr_valid(ptr_pctgoodpr) eq 1) then ptr_free,ptr_pctgoodpr
if (ptr_valid(ptr_pctgoodgv) eq 1) then ptr_free,ptr_pctgoodgv
if (ptr_valid(ptr_pctgoodrain) eq 1) then ptr_free,ptr_pctgoodrain
; help, /memory

print, ''
print, 'Done!'

errorExit:

print, ''
print, 'Output file status:'
command = 'ls -al ' + dbfile
spawn, command
print, ''
FREE_LUN, DBunit

end
