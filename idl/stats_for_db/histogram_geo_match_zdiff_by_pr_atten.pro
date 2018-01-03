;+
; histogram_geo_match_zdiff_by_pr_atten.pro 
; - Morris/SAIC/GPM_GV   October 2013
;
; DESCRIPTION
; -----------
; Reads PR and GR reflectivity and spatial fields from geo_match netCDF files,
; builds index arrays of categories of range, rain type, bright band proximity
; (above, below, within), and height (13 categories, 1.5-19.5 km levels); and
; an array of actual range.  Computes a 2-D histogram of mean PR-GR reflectivity
; differences as a function of the amount of PR attenuation correction (i.e.,
; the difference between the 2A25 and 1C21 PR reflectivity) for the sample.
; for each of the 13 height levels for points within 100 km of the ground radar.
;
; Statistical results are stratified by raincloud type (Convective, Stratiform)
; and vertical location w.r.t the bright band (above, within, below), and in
; total for all eligible points, for a total of 7 permutations.  
;
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
; s2ku          - Binary parameter.  If set, then apply Liao/Meneghini S-to-Ku
;                 frequency adjustments to GR reflectivity.
;
; name_add      - String to be inserted into the output filename to identify a
;                 unique set of data, indicate parameter values used, etc.
;
; ndfilelist    - Pathname to a text file listing the matchup netCDF files to
;                 be processed, one file per line.  Lists either the full
;                 pathnames to the files, or if ncsitepath is specified, is a
;                 partial pathname to be prepended by ncsitepath to get the
;                 complete pathname to the files listed.
;
; ncsitepath    - Pathname pattern to the matchup netCDF files to be processed.
;                 Defaults to /data/netcdf/geo_match/GRtoPR*.7.*.nc*.  If
;                 ncfilelist is specified, then ncsitepath is a just a directory
;                 location to be prepended to partial file pathnames listed
;                 within ncfilelist.
;
; first_orbit   - Optional parameter to define the first orbit to be processed
;                 during this run of the procedure.  Files for earlier orbits
;                 are excluded.
;
; bbwidth       - Override to the default half-width of the bright band layer.
;
;
; FILES
; -----
;
; GRtoPR*.v.*.nc*                      INPUT: The set of site/orbit specific
;                                             netCDF grid files for which
;                                             stats are to be computed, where
;                                             'v' is the TRMM version (6 or 7).
;                                             Files used are as specified
;                                             by the ncsitepath and ncfilelist
;                                             parameters.
;
;
; CALLS
; -----
; fprep_geo_match_profiles()
;
;
; HISTORY
; -------
; 10/25/13 Morris, GPM GV, SAIC
; - Created.
;
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;===============================================================================


function histogram_geo_match_zdiff_by_pr_atten, PCT_ABV_THRESH=pctAbvThresh,  $
                                                S2KU=s2ku,                    $
                                                NAME_ADD=name_add,            $
                                                NCSITEPATH=ncsitepath,        $
                                                NCFILELIST=ncfilelist,        $
                                                BBWIDTH=bbwidth

; "include" file for structs returned by read_geo_match_netcdf()
@geo_match_nc_structs.inc

; "include" file for PR data constants
@pr_params.inc


CASE GETENV('HOSTNAME') OF
   'ds1-gpmgv.gsfc.nasa.gov' : datadirroot = '/data/gpmgv'
   'ws1-gpmgv.gsfc.nasa.gov' : datadirroot = '/data'
   ELSE : BEGIN
          print, "Unknown system ID, setting 'datadirroot' to user's home directory"
          datadirroot = '~/data'
          END
ENDCASE

IF N_ELEMENTS(ncfilelist) EQ 1 THEN BEGIN
  ; find out how many files are listed in the file 'ncfilelist'
   command = 'wc -l ' + ncfilelist
   spawn, command, result
   nf = LONG(result[0])
   IF (nf LE 0) THEN BEGIN
      print, "" 
      print, "No files listed in ", ncfilelist
      print, " -- Exiting."
      GOTO, errorExit
   ENDIF
   IF N_ELEMENTS(ncsitepath) EQ 1 THEN ncpre=ncsitepath+'/' ELSE ncpre=''
   prfiles = STRARR(nf)
   OPENR, ncunit, ncfilelist, ERROR=err, /GET_LUN
   ; initialize the variables into which file records are read as strings
   dataPR = ''
   ncnum=0
   WHILE NOT (EOF(ncunit)) DO BEGIN 
     ; get GRtoPR filename
      READF, ncunit, dataPR
      ncfull = ncpre + STRTRIM(dataPR,2)
      IF FILE_TEST(ncfull, /REGULAR) THEN BEGIN
         prfiles[ncnum] = ncfull
         ncnum++
      ENDIF ELSE message, "File "+ncfull+" does not exist!", /INFO
   ENDWHILE  ; each matchup file to process in control file
   CLOSE, ncunit
   nf = ncnum
   IF (nf LE 0) THEN BEGIN
      print, "" 
      message, "No files listed in "+ncfilelist+" were found.", /INFO
      print, " -- Exiting."
      GOTO, errorExit
   ENDIF
   IF STREGEX(prfiles[0], '.6.') EQ -1 THEN verstr='_v7' ELSE verstr='_v6'
ENDIF ELSE BEGIN
   IF N_ELEMENTS(ncsitepath) EQ 1 THEN BEGIN
      IF STREGEX( ncsitepath, '(.6.|.7.)' ) EQ -1 THEN BEGIN
         print, ""
         print, "No version specification in NCSITEPATH parameter, try again!"
      ENDIF ELSE BEGIN
         ; find the TRMM product version and wildcard file pattern
         IF STREGEX(ncsitepath, '.6.') EQ -1 THEN verstr='_v7' ELSE verstr='_v6'
         pathpr=ncsitepath+'*'
      ENDELSE
   ENDIF ELSE BEGIN
      print, "" & print, "Running PR v7 matchups only." & print, ""
      verstr='_v7'
      pathpr = datadirroot+'/netcdf/geo_match/GRtoPR.*.7.*.nc*'
   ENDELSE
  ; get the list of files to be processed based on file pattern "pathpr"
   prfiles = file_search(pathpr,COUNT=nf)
   IF (nf LE 0) THEN BEGIN
      print, "" 
      print, "No files found for pattern = ", pathpr
      print, " -- Exiting."
      GOTO, errorExit
   ENDIF
ENDELSE

;STOP

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

s2ku = KEYWORD_SET( s2ku )

; define the output file name according to parameters in effect

lastsite='NA'
lastorbitnum=0
lastncfile='NA'

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

; define array to hold all 9 permutations of the 2-D histograms
all2Dhist = LONARR(9,401,201)
; define array to hold counts of neg. atten and total samples for the permutations
negattenbycombo = LONARR(9,2)

FOR fnum = 0, nf-1 DO BEGIN

   ncfilepr = prfiles(fnum)
   bname = file_basename( ncfilepr )
   prlen = strlen( bname )
   print, ""

   parsed = strsplit(bname, '.', /EXTRACT)
   site = parsed[1]
   orbit = parsed[3]
   orbitnum = LONG(orbit)

; uncomment IF block and edit minimum orbit number if processing new orbits only
   IF N_ELEMENTS( first_orbit ) EQ 1 THEN BEGIN
      IF orbitnum LT first_orbit THEN BEGIN
         PRINT, "orbitnum, orbit: ", orbitnum, ', ', orbit
         print, "Skip GeoMatch netCDF file: ", ncfilepr, " by orbit threshold."
         CONTINUE
      ENDIF
   ENDIF
   print, "GeoMatch netCDF file: ", ncfilepr

; set up to skip the non-calibrated KWAJ data files, else we get duplicates
   kwajver = parsed[4]
   skipping=0
;   IF ( site EQ 'KWAJ' and kwajver NE 'cal' ) THEN skipping=1
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

   status = fprep_geo_match_profiles( ncfilepr, heights, $
       PCT_ABV_THRESH=pctAbvThresh, GV_CONVECTIVE=gvconvective, $
       GV_STRATIFORM=gvstratiform, S2KU=s2ku, PTRfieldflags=ptr_fieldflags, $
       PTRgeometa=ptr_geometa, PTRsweepmeta=ptr_sweepmeta, PTRsitemeta=ptr_sitemeta, $
       PTRGVZ=ptr_gvz, PTRGVMAX=ptr_gvzmax, PTRGVSTDDEV=ptr_gvzstddev, $
       PTRzcor=ptr_zcor, PTRzraw=ptr_zraw, PTRrain3d=ptr_rain3, $
       PTRsfcrainpr=ptr_nearSurfRain, PTRsfcraincomb=ptr_nearSurfRain_2b31, $
       PTRrainflag_int=ptr_rnFlag, PTRraintype_int=ptr_rnType, PTRbbProx=ptr_bbProx, $
       PTRhgtcat=ptr_hgtcat, PTRdist=ptr_dist, PTRpctgoodpr=ptr_pctgoodpr, $
       PTRpctgoodgv=ptr_pctgoodgv, PTRpctgoodrain=ptr_pctgoodrain, BBPARMS=BBparms, $
       BB_RELATIVE=bb_relative, BBWIDTH=bbwidth )

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
   pr_time = mygeometa.timeNearestApproach
  ; get the array of sweep times
   gr_times = mysweeps.timeSweepStart
  ; compute the mean time difference between the PR and GR -- take a sweep
  ; at 1/3 the way through the volume as the GR time
   timediff = gr_times[nsweeps/3]-pr_time

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

; build an array of BB proximity: 0 if below, 1 if within, 2 if above
; NOTE THESE CATEGORY NUMBERS ARE ONE LOWER THAN THOSE IN FPREP_GEO_MATCH_PROFILES() !!
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

;=========================================================================

;  - we didn't compute pct_abv_thresh for zraw, so we need to limit the dataset
;    to those where the 1C21 is 18.0 dBZ and above.

   idxzraw18 = WHERE( zraw GE 18.0, countzraw18)
   IF countzraw18 GT 0 THEN BEGIN
      gvz = gvz[idxzraw18]
      zraw = zraw[idxzraw18]
      zcor = zcor[idxzraw18]
      rain3 = rain3[idxzraw18]
      gvzmax = gvzmax[idxzraw18]
      gvzstddev = gvzstddev[idxzraw18]
      rnFlag = rnFlag[idxzraw18]
      rnType = rnType[idxzraw18]
      dist = dist[idxzraw18]
      bbProx = bbProx[idxzraw18]
      hgtcat = hgtcat[idxzraw18]
   ENDIF ELSE BEGIN
      print, "No complete-volume Zraw points, quitting case."
      goto, nextFile
   ENDELSE

; generate histograms of PR-GR reflectivity vs. PR2A25-PR1C21 reflectivity
; for the various categories of rain type, BB proximity
  
  for rain_cat=1,3 do begin        ; stratiform, convective, other
     for bbprox_cat=0,2 do begin   ; below, within, above
        combo = rain_cat*10 + bbprox_cat
        idxrainbbcat = WHERE( rnType EQ rain_cat AND bbProx EQ bbprox_cat, countcombo )
        IF countcombo GT 0 THEN BEGIN
           prgrdiff = zcor[idxrainbbcat]-gvz[idxrainbbcat]
           diffatten = zcor[idxrainbbcat]-zraw[idxrainbbcat]
idxnegatten=WHERE(diffatten LT -0.05, countnegatten)
if countnegatten GT 0 then print, 'Combo, neg. atten: ', combo, diffatten[idxnegatten]
           diffByDiff = HIST_2D(prgrdiff, diffatten, BIN1=0.1, BIN2=0.1, $
                                MAX1=20.0, MAX2=15.0, MIN1=-20.0, MIN2=-5.0)
           CASE combo OF
             10 : BEGIN
                     all2Dhist[0,*,*] += diffByDiff   ; strat/below
                     negattenbycombo[0,*] += [countnegatten,countcombo]
                  END
             11 : BEGIN
                     all2Dhist[1,*,*] += diffByDiff   ; strat/within
                     negattenbycombo[1,*] += [countnegatten,countcombo]
                  END
             12 : BEGIN
                     all2Dhist[2,*,*] += diffByDiff   ; strat/above
                     negattenbycombo[2,*] += [countnegatten,countcombo]
                  END
             20 : BEGIN
                     all2Dhist[3,*,*] += diffByDiff   ; conv/below
                     negattenbycombo[3,*] += [countnegatten,countcombo]
                  END
             21 : BEGIN
                     all2Dhist[4,*,*] += diffByDiff   ; conv/within
                     negattenbycombo[4,*] += [countnegatten,countcombo]
                  END
             22 : BEGIN
                     all2Dhist[5,*,*] += diffByDiff   ; conv/above
                     negattenbycombo[5,*] += [countnegatten,countcombo]
                  END
             30 : BEGIN
                     all2Dhist[6,*,*] += diffByDiff   ; other/below
                     negattenbycombo[6,*] += [countnegatten,countcombo]
                  END
             31 : BEGIN
                     all2Dhist[7,*,*] += diffByDiff   ; other/within
                     negattenbycombo[7,*] += [countnegatten,countcombo]
                  END
             32 : BEGIN
                     all2Dhist[8,*,*] += diffByDiff   ; other/above
                     negattenbycombo[8,*] += [countnegatten,countcombo]
                  END
           ENDCASE
        ENDIF ELSE print, "No samples for combo ", combo
     endfor
  endfor




;=========================================================================

   nextFile:
   lastorbitnum=orbitnum
   lastncfile=bname
   lastsite=site

ENDFOR    ; end of loop over fnum = 0, nf-1

print, '' & print, negattenbycombo & print, ''

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

return, all2Dhist

errorExit: return, -1
end
