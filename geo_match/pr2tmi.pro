;===============================================================================
;+
; Copyright © 2012, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; pr2tmi.pro          Morris/SAIC/GPM_GV      November 2012
;
; DESCRIPTION
; -----------
; Performs a resampling of TMI and PR data to common volumes, defined by the
; TMI footprint sizes and locations.  The matchup is performed on the swath
; data in the area in common between the TMI and PR scans.  A matched set of
; PR and TMI orbit subset products (orbit/subset, TRMM version) is input to
; the routine.  At a minimum the TMI 2A-12 and PR 2A-25 products must be
; present.  Returns a structure containing:
;
;   - TMI rain rate from the 2A-12 file (all TMI footprints in file)
;   - Count of PR footprints mapped to each of the above, based on 'radius'
;   - Mean PR 2A-25 near-surface rain rate matched to the TMI 2A-12 footprints
;   - Count of non-zero 2A-25 rain rates in above average
;   - Mean PR/TMI 2B-31 combined rain rate matched to the TMI 2A-12 footprints
;   - Count of non-zero 2B-31 rain rates in above average
;   - Count of PR footprints having rain type Convective, for each TMI footprint
;
;
; MODULES
; -------
; 1)  pr2tmi:                Main function to matchup PR rainfall to TMI,
;                            given a TMI 2A-12 filename as input.
; 2)  find_pr_for_tmi:       Utility to find PR products matching a TMI
;                            2A-12 product in orbit#, orbit subset, and
;                            TRMM product version.
; 3)  compute_averages:      Computes averages of array data, with options
;                            to:  a) set negative values to 0 in averaging, 
;                            or:  b) exclude them from the average.
;
; HISTORY
; -------
; 11/2012 by Bob Morris, GPM GV (SAIC)
;  - Created.
; 02/06/13  Morris/GPM GV/SAIC
; - Added NSPECIES to COMMON definition in pr2tmi().
;
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;===============================================================================

; MODULE 3:  compute_average_and_n

FUNCTION compute_average_and_n, values, n_non_zero, NEGSTOZERO=negsToZero

; Compute average of array elements included in "values" array, and the number
; of non-zero values ("n_non_zero") contained in the average.  If keyword
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

idx_gt_zero = WHERE( values GT 0.0, n_non_zero)

return, meanval
end

;===============================================================================

; MODULE 2:  PROCEDURE find_pr_for_tmi

; DESCRIPTION
; -----------
; Given the directory path and file basename of a TMI 2A-12 file, searches
; for the corresponding (by site, date, orbit, TRMM version) PR file of the
; requested type (e.g., 2A25) under a PR-product-specific directory under the
; "common" TRMM product directory defined by convention as the next higher
; directory above /2A12.  If a matching PR file of the requested type is not
; found, then a well-known bogus file name will be returned in the FILE_XXXX
; keyword value (e.g., "no_2A25_file").
;
; PARAMETERS
; ----------
; tmi_filepath    - Fully-qualified pathname to the TMI file whose matching
;                   PR file(s) are to be found.
;
; file_xxxx       - File name of the matching PR file of type 'xxxx', where
;                   xxxx is one of the types 1C21, 2A23, 2A25, or 2B31.  Any
;                   or all of the XXXX parameters/file types may be requested.
;
; HISTORY
; -------
; 09/20/12  Morris/GPM GV/SAIC
; - Created.
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;===============================================================================

PRO find_pr_for_tmi, tmi_filepath, FILE_1C21=file_1c21, FILE_2A23=file_2a23, $
                     FILE_2A25=file_2a25, FILE_2B31=file_2b31

pathname_len = STRLEN(tmi_filepath)
pathTypePos = STRPOS(tmi_filepath, '2A12/2A12')

IF pathTypePos NE -1 THEN BEGIN
   IF N_ELEMENTS(file_1c21) NE 0 THEN BEGIN
      file_1c21_2match = STRMID(tmi_filepath, 0, pathTypePos)+'1C21/1C21'+ $
          STRMID(tmi_filepath, pathTypePos+9, pathname_len-(pathTypePos+8))
      IF FIND_ALT_FILENAME(file_1c21_2match, foundfile) EQ 0 THEN $
         file_1c21 = 'no_1C21_file' ELSE file_1c21 = foundfile
   ENDIF
   IF N_ELEMENTS(file_2a23) NE 0 THEN BEGIN
      file_2a23_2match = STRMID(tmi_filepath, 0, pathTypePos)+'2A23/2A23'+ $
          STRMID(tmi_filepath, pathTypePos+9, pathname_len-(pathTypePos+8))
      IF FIND_ALT_FILENAME(file_2a23_2match, foundfile) EQ 0 THEN $
         file_2a23 = 'no_2A23_file' ELSE file_2a23 = foundfile
   ENDIF
   IF N_ELEMENTS(file_2a25) NE 0 THEN BEGIN
      file_2a25_2match = STRMID(tmi_filepath, 0, pathTypePos)+'2A25/2A25'+ $
          STRMID(tmi_filepath, pathTypePos+9, pathname_len-(pathTypePos+8))
      IF FIND_ALT_FILENAME(file_2a25_2match, foundfile) EQ 0 THEN $
         file_2a25 = 'no_2A25_file' ELSE file_2a25 = foundfile
   ENDIF
   IF N_ELEMENTS(file_2b31) NE 0 THEN BEGIN
      file_2b31_2match = STRMID(tmi_filepath, 0, pathTypePos)+'2B31/2B31'+ $
          STRMID(tmi_filepath, pathTypePos+9, pathname_len-(pathTypePos+8))
      IF FIND_ALT_FILENAME(file_2b31_2match, foundfile) EQ 0 THEN $
         file_2b31 = 'no_2B31_file' ELSE file_2b31 = foundfile
   ENDIF
ENDIF

end

;===============================================================================

; MODULE 1:  FUNCTION pr2tmi

; DESCRIPTION
; -----------
; Top-level function called by the user or external calling routine.  See the
; prologue at the top of this file for the detailed description.
;
;
; PARAMETERS
; ----------
; tmi2a12file   - Full pathname of a TRMM TMI 2A-12 product file, located in the
;                 product-specific subdirectory (/2A12) under the common TRMM
;                 products top-level directory (e.g., /data/gpmgv/prsubsets).
;
; radius        - Non-default radius to use for identifying PR footprints to be
;                 included in the PR data average surrounding each TMI surface
;                 footprint location.
;
; ncfile_out    - Binary option.  If set, then the TMI-PR matchup data will
;                 be written to a netCDF file which will include additional
;                 scalar variables and data arrays not contained in the data
;                 structure returned by this function.
;
; path_out      - Override to the default path for the output netCDF files.  If
;                 not specified, then the path will default to the directory
;                 given by the combination of NCGRIDS_ROOT+PR_TMI_MATCH_NCDIR as
;                 defined in the "include" file, environs.inc.
;
;
; HISTORY
; -------
; 11/26/12  Morris/GPM GV/SAIC
; - Created.
; 02/06/13  Morris/GPM GV/SAIC
; - Added NSPECIES to COMMON definition.
; 10/07/14  Morris/GPM GV/SAIC
; - Renamed NSPECIES to NSPECIES_TMI.
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;===============================================================================

FUNCTION pr2tmi, tmi2a12file, RADIUS=radius, NCFILE_OUT=ncfile_out, $
                 PATH_OUT=path_out

COMMON sample, start_sample, sample_range, num_range, NPIXEL_TMI_PR, NSPECIES_TMI

; "Include" file for DATA_PRESENT, NO_DATA_PRESENT
@grid_def.inc
; "Include" file for TMI-product-specific parameters (i.e., NPIXEL_TMI):
@tmi_params.inc
; "Include" file for names, paths, etc.:
@environs.inc
; "Include" file for special values in netCDF files: Z_BELOW_THRESH, etc.
@pr_params.inc

; set the default radius if one is not provided or is out-of-range
IF N_ELEMENTS(radius) EQ 0 THEN BEGIN
   print, "Setting default radius for TMI footprint to 7.0 km" & print, ""
   radius = 7.0
ENDIF ELSE BEGIN
   IF (radius LT 5.0) OR (radius GT 50.0) THEN BEGIN
      print, "Radius must be between 5.0 and 50.0 km, supplied value = ", radius
      print, "Setting default radius for TMI footprint to 7.0 km" & print, ""
      radius = 7.0
   ENDIF
ENDELSE
radiusStr = STRING(radius, FORMAT="(f0.1)")

NPIXEL_TMI_PR = NPIXEL_TMI   ; set common value to TMI's constant, for a start

parsed = STRSPLIT(FILE_BASENAME(tmi2a12file), '.', /EXTRACT)
yymmdd = parsed[1]
orbit = parsed[2]
TRMM_vers = FIX(parsed[3])
TRMM_vers_str = parsed[3]
subset = parsed[4]

; set up the output netCDF filename if we are writing one
ncfile_out = KEYWORD_SET( ncfile_out )
IF ( ncfile_out ) THEN BEGIN
   do_nc = 1
   ncfile_base = PR_TMI_MATCH_PRE + yymmdd +'.'+ orbit +'.'+ TRMM_vers_str $
                 +'.'+ subset +'_'+ radiusStr + 'km.nc'
   IF N_ELEMENTS(path_out) EQ 0 THEN $
      ncfile_out = NCGRIDS_ROOT+PR_TMI_MATCH_NCDIR+'/'+ncfile_base $
   ELSE ncfile_out = path_out+'/'+ncfile_base
   print,"" & print, "Writing output to netCDF file: ", ncfile_out & print,""
ENDIF ELSE do_nc = 0

; find the PR files matching the TMI file specification
file_1c21 = 'no_1C21_file'
file_2a23 = 'no_2A23_file'
file_2a25 = 'no_2A25_file'
file_2b31 = 'no_2B31_file'
find_pr_for_tmi, tmi2a12file, FILE_1C21=file_1c21, FILE_2A23=file_2a23, $
                     FILE_2A25=file_2a25, FILE_2B31=file_2b31

IF file_2a25 EQ 'no_2A25_file' THEN BEGIN
   print, "In pr2tmi.pro: Could not find 2A25 file to match ", tmi2a12file
   print, "Exiting with error."
   return, 0
ENDIF

; set up the output array of TMI and PR filenames for netCDF file
IF do_nc THEN tmiprfiles = [tmi2a12file, file_1c21, file_2a23, file_2a25, file_2b31]

; read the TMI 2A12 and PR 2A25 files
; initialize TMI variables/arrays and read 2A12 fields
   SAMPLE_RANGE=0
   START_SAMPLE=0
   geolocation = FLTARR(sample_range>1, NPIXEL_TMI, 2)
    sc_lat_lon = FLTARR(2, sample_range>1)
      dataFlag = BYTARR(sample_range>1, NPIXEL_TMI)
   TMIrainFlag = BYTARR(sample_range>1, NPIXEL_TMI)
   surfaceType = INTARR(sample_range>1, NPIXEL_TMI)
   surfaceRain = FLTARR(sample_range>1, NPIXEL_TMI)
           PoP = INTARR(sample_range>1, NPIXEL_TMI)
freezingHeight = INTARR(sample_range>1, NPIXEL_TMI)

   status = read_tmi_2a12_fields( tmi2a12file, $
                                  DATAFLAG=dataFlag, $
                                  RAINFLAG=TMIrainFlag, $
                                  SURFACETYPE=surfaceType, $
                                  SURFACERAIN=surfaceRain, $
                                  POP=PoP, $
                                  FREEZINGHEIGHT=freezingHeight, $
                                  SC_LAT_LON=sc_lat_lon, $
                                  GEOL=geolocation )

   IF ( status NE 0 ) THEN BEGIN
      PRINT, ""
      PRINT, "pr2tmi.pro:  ERROR reading fields from ", tmi2a12file
      PRINT, "Exiting with error."
      return, 0
   ENDIF

; grab the number of TMI scans read
NSCAN_TMI = sample_range

; figure out which fields we got from the 2A12 file and tabulate in structure
dataflags = get_geo_match_nc_struct( 'fields_swath' )
idxcheck = WHERE(dataFlag NE 0)
if idxcheck[0] NE -1 THEN dataflags.have_dataFlag = 1
idxcheck = WHERE(TMIrainFlag NE 0b)
if idxcheck[0] NE -1 THEN dataflags.have_rainFlag = 1
idxcheck = WHERE(surfaceType NE 0b)
if idxcheck[0] NE -1 THEN dataflags.have_surfaceType = 1
idxcheck = WHERE(surfaceRain NE 0.0)
if idxcheck[0] NE -1 THEN dataflags.have_surfaceRain = 1
idxcheck = WHERE(PoP NE 0)
if idxcheck[0] NE -1 THEN dataflags.have_PoP = 1
idxcheck = WHERE(freezingHeight NE 0)
if idxcheck[0] NE -1 THEN dataflags.have_freezingHeight = 1
;help, dataflags, /struc

; split GEOL data fields into tmiLats and tmiLons arrays
tmiLons = FLTARR(NPIXEL_TMI,sample_range>1)
tmiLats = FLTARR(NPIXEL_TMI,sample_range>1)
tmiLons[*,*] = geolocation[1,*,*]
tmiLats[*,*] = geolocation[0,*,*]

; NOTE THAT THE GEOLOCATION ARRAYS ARE IN (RAY,SCAN) COORDINATES, WHILE ALL THE
; OTHER ARRAYS ARE IN (SCAN,RAY) COORDINATE ORDER.  NEED TO ACCOUNT FOR THIS
tmiLons = TRANSPOSE(tmiLons)
tmiLats = TRANSPOSE(tmiLats)

; split SC_LAT_LON data fields into scLats and scLons arrays
scLons = FLTARR(sample_range>1)
scLats = FLTARR(sample_range>1)
scLons[*] = sc_lat_lon[1,*]
scLats[*] = sc_lat_lon[0,*]

tmi_master_idx = LINDGEN(sample_range, NPIXEL_TMI)  ; "actual" TMI footprints
n_tmi_feet = N_ELEMENTS(tmi_master_idx)             ; number of TMI footprints defined
; get arrays of TMI scan and ray number
rayscan = ARRAY_INDICES(surfaceRain, tmi_master_idx)
rayscan = REFORM(rayscan, 2, sample_range, NPIXEL_TMI)
scantmi = REFORM(rayscan[0,*,*])
raytmi = REFORM(rayscan[1,*,*])

; define arrays for TMI footprint "corners" for image plots
xCornersTMI = FLTARR(4, NSCAN_TMI, NPIXEL_TMI)
yCornersTMI = FLTARR(4, NSCAN_TMI, NPIXEL_TMI)

; holds info on how many PR footprints there are in each TMI ray position:
npertmiray = LONARR(NPIXEL_TMI)

; hold PR science values averaged/boiled down to TMI resolution defined by "radius"
; -- how many PR footprints "map" to the TMI footprint, by radius criterion
PRinRadius2TMI = MAKE_ARRAY(sample_range, NPIXEL_TMI, /INT, VAL=0)
; -- averages of PR 2a25 and 2b31 rain rate, and non-zero count, by TMI footprint
PRsfcRainByTMI = MAKE_ARRAY(sample_range, NPIXEL_TMI, /FLOAT, VAL=-99.0)
PRcountSfcRainByTMI = MAKE_ARRAY(sample_range, NPIXEL_TMI, /INT, VAL=0)
PRsfcRain2b31ByTMI = MAKE_ARRAY(sample_range, NPIXEL_TMI, /FLOAT, VAL=-99.0)
PRcountSfc2b31RainByTMI = MAKE_ARRAY(sample_range, NPIXEL_TMI, /INT, VAL=0)
; -- number of PR footprints of rain type Convective
PRcountRainConv = MAKE_ARRAY(sample_range, NPIXEL_TMI, /INT, VAL=0)

; allow for one extrapolated footprint off the ends of each actual scan line, and
; two 'bogus' extrapolated scans at the beginning and end of the actual data, for
; the array of tmi_index values to analyze to grid
n_tmi_feet_extrap = (sample_range+2)*(NPIXEL_TMI+2)
tmi_indexes_extrap = LONARR(n_tmi_feet_extrap)
tmi_indexes_extrap[*] = -99L                        ; fill with 'unassigned' values

; assign actual TMI footprint indices to extrapolated array
tmi_indexes_extrap[0] = tmi_master_idx

; figure out our domain bounds relative to TMI coverage
latmax = MAX(tmiLats, MIN=latmin)
lonmax = MAX(tmiLons, MIN=lonmin)

; set up a Mercator map projection and compute TMI footprint cartesian coordinates in km
centerLat = (latmax+latmin)/2.0
centerLon = (lonmax+lonmin)/2.0
mymap = MAP_PROJ_INIT('Mercator', CENTER_LON=centerLon, CENTER_LAT=centerLat)
tmi_xy = MAP_PROJ_FORWARD(tmiLons, tmiLats, MAP=mymap) / 1000.

; separate the x and y arrays for footprint corner calculations, later on
tmi_x0 = REFORM(tmi_xy[0,*], NSCAN_TMI, NPIXEL_TMI)
tmi_y0 = REFORM(tmi_xy[1,*], NSCAN_TMI, NPIXEL_TMI)
; flip them back to ray,scan coordinates as expected in FOOTPRINT_CORNER_X_AND_Y()
tmi_x0 = TRANSPOSE(tmi_x0)
tmi_y0 = TRANSPOSE(tmi_y0)

; compute the TMI footprint corners
for itmifoot = 0L, n_tmi_feet-1 do begin
   xy = footprint_corner_x_and_y( scantmi[itmifoot], raytmi[itmifoot], tmi_x0, tmi_y0, $
                                          NSCAN_TMI , NPIXEL_TMI )
   xCornersTMI[*, scantmi[itmifoot], raytmi[itmifoot]] = xy[0,*]
   yCornersTMI[*, scantmi[itmifoot], raytmi[itmifoot]] = xy[1,*]
endfor

; initialize PR variables/arrays and read 2A25 fields
   SAMPLE_RANGE=0
   START_SAMPLE=0
   num_range = NUM_RANGE_2A25
;   dbz_2a25=FLTARR(sample_range>1,1,num_range)
;   rain_2a25 = FLTARR(sample_range>1,1,num_range)
   surfRain_2a25=FLTARR(sample_range>1,RAYSPERSCAN)
   geolocation=FLTARR(2,RAYSPERSCAN,sample_range>1)
   rangeBinNums=INTARR(sample_range>1,RAYSPERSCAN,7)
   rainFlag=INTARR(sample_range>1,RAYSPERSCAN)
   rainType=INTARR(sample_range>1,RAYSPERSCAN)
   status = read_pr_2a25_fields( file_2a25, DBZ=dbz_2a25, RAIN=rain_2a25,   $
                                 TYPE=rainType, SURFACE_RAIN=surfRain_2a25, $
                                 GEOL=geolocation, RANGE_BIN=rangeBinNums,  $
                                 RN_FLAG=rainFlag )
   IF ( status NE 0 ) THEN BEGIN
      PRINT, ""
      PRINT, "ERROR reading fields from ", file_2a25
      PRINT, "Skipping events for orbit = ", orbit
      PRINT, ""
      return, 0
   ENDIF

   dataflags_pr = get_geo_match_nc_struct( 'fields' )
   idxcheck = WHERE(surfRain_2a25 NE 0.0)
   if idxcheck[0] NE -1 THEN dataflags_pr.have_nearSurfRain = 1
   idxcheck = WHERE(rainType NE 0)
   if idxcheck[0] NE -1 THEN dataflags_pr.have_rainType = 1
   idxcheck = WHERE(rainFlag NE 0)
   if idxcheck[0] NE -1 THEN dataflags_pr.have_rainFlag = 1
   idxcheck = WHERE(rangeBinNums NE 0)
   ;if idxcheck[0] NE -1 THEN dataflags_pr.have_BBheight = 1

   ; boil down rain type to 3 categories: 1,2,3
   rainType = rainType/100

   ; split GEOL data fields into prlats and prlons arrays and transpose
   ; into order of science data fields
   prLons = REFORM( geolocation[1,*,*] )
   prLons = TRANSPOSE(prLons)
   prLats = REFORM( geolocation[0,*,*] )
   prLats = TRANSPOSE(prLats)

   ; compute PR footprint cartesian coordinates, in km
   pr_xy = MAP_PROJ_FORWARD(prLons, prLats, MAP=mymap) / 1000.

; read 1C21 fields
;   havefile1c21 = 1
;   IF ( file_1c21 EQ 'no_1C21_file' ) THEN BEGIN
;      PRINT, ""
;      PRINT, "No 1C21 file, skipping 1C21 processing for orbit = ", orbit
;      PRINT, ""
      havefile1c21 = 0
;   ENDIF ELSE BEGIN
;      SAMPLE_RANGE=0
;      START_SAMPLE=0
;      num_range = NUM_RANGE_1C21
;      dbz_1c21=FLTARR(sample_range>1,1,num_range)
;      landOceanFlag=INTARR(sample_range>1,RAYSPERSCAN)
;      binS=INTARR(sample_range>1,RAYSPERSCAN)
;      rayStart=INTARR(RAYSPERSCAN)
;      status = read_pr_1c21_fields( file_1c21, DBZ=dbz_1c21,       $
;                                    OCEANFLAG=landOceanFlag,       $
;                                    BinS=binS, RAY_START=rayStart )
;      IF ( status NE 0 ) THEN BEGIN
;         PRINT, ""
;         PRINT, "ERROR reading fields from ", file_1c21
;         PRINT, "Skipping events for orbit = ", orbit
;         PRINT, ""
;         return, 0
;      ENDIF
;   ENDELSE

; read 2A23 status fields
; The following test allows PR processing to proceed without the
; 2A-23 data file being available.

   havefile2a23 = 1
   IF ( file_2a23 EQ 'no_2A23_file' ) THEN BEGIN
      PRINT, ""
      PRINT, "No 2A23 file, skipping 2A23 processing for orbit = ", orbit
      PRINT, ""
      havefile2A23 = 0
   ENDIF ELSE BEGIN
      status_2a23=INTARR(sample_range>1,RAYSPERSCAN)
      bbstatus=INTARR(sample_range>1,RAYSPERSCAN)
      status = read_pr_2a23_fields( file_2a23, STATUSFLAG=status_2a23, $
                                    BBstatus=bbstatus)
      IF ( status NE 0 ) THEN BEGIN
         PRINT, ""
         PRINT, "ERROR reading fields from ", file_2a23
         PRINT, "Skipping 2A23 processing for orbit = ", orbit
         PRINT, ""
         havefile2a23 = 0
      ENDIF
   ENDELSE

   idxcheck = WHERE(status_2a23 NE 0)
   if idxcheck[0] NE -1 THEN dataflags_pr.have_status_2a23 = 1
   idxcheck = WHERE(bbstatus NE 0)
   if idxcheck[0] NE -1 THEN dataflags_pr.have_BBstatus = 1

; read 2B31 rainrate field
; The following test allows PR processing to proceed without the
; 2B-31 data file being available.

   havefile2b31 = 1
   IF ( file_2b31 EQ 'no_2B31_file' ) THEN BEGIN
      PRINT, ""
      PRINT, "No 2B31 file, skipping 2B31 processing for orbit = ", orbit
      PRINT, ""
      havefile2b31 = 0
   ENDIF ELSE BEGIN
      surfRain_2b31=FLTARR(sample_range>1,RAYSPERSCAN)
      status = read_pr_2b31_fields( file_2b31, surfRain_2b31)
      IF ( status NE 0 ) THEN BEGIN
         PRINT, ""
         PRINT, "ERROR reading fields from ", file_2b31
         PRINT, "Skipping 2B31 processing for orbit = ", orbit
         PRINT, ""
         havefile2b31 = 0
      ENDIF
   ENDELSE

   idxcheck = WHERE(surfRain_2b31 NE 0)
   if idxcheck[0] NE -1 THEN dataflags_pr.have_nearSurfRain_2b31 = 1

; find PR footprints in rough range of TMI footprints, based on lat/lon
; -- restrict ourselves to only those TMI rays covering the PR swath,
;    nominally rays between 76 and 130.  Give ourselves 2-3 footprints of slop
tmiIdx2do = tmi_master_idx[*,74:132]
n_tmi_feet2do = N_ELEMENTS(tmiIdx2do)

ntmimatchrough = 0L
ntmimatchtrue = 0L
maxPRinRadius = 0
roughlat = (radius*1.5)/111.1
roughlon = roughlat*1.3

for itmifoot2do = 0L, n_tmi_feet2do-1 do begin
   itmifoot = tmiIdx2do[itmifoot2do]
   tmifootlat = tmiLats[itmifoot]
   tmifootlon = tmiLons[itmifoot]
   tmifootxy = tmi_xy[*,itmifoot]
   n_non_zero = 0                   ; number of non-zero PR values in average

   ; do the rough distance check based on Delta lat and lon
   idxrough = WHERE( ( ABS(prLats-tmifootlat) LT roughlat ) $
                 AND ( ABS(prLons-tmifootlon) LT roughlon ), countpr )
   if countpr GT 0 then begin
      ntmimatchrough++
;      print, "TMI Lat, Lon: ", tmifootlat, tmifootlon
;      print, "PR, PR Lat, Lon: ", countpr, prLats[idxrough], prLons[idxrough]
      ; compute accurate PR-TMI footprint distances for this subset of PR footprints
      truedist = REFORM( SQRT( (tmifootxy[0]-pr_xy[0, idxrough])^2 + $
                               (tmifootxy[1]-pr_xy[1, idxrough])^2 ) )
;      print, "TMI-PR range: ", truedist
;      print, ''
      idxtruetmp = WHERE( truedist LE radius, counttrue )
      IF counttrue GT 0 THEN BEGIN
         ntmimatchtrue++                   ; increment count of TMI footprints with PR mapped to them
         idxprtrue = idxrough[idxtruetmp]  ; PR array indices mapped to this TMI footprint

         ; do the PR and COM rainrate averages for footprints mapped to this TMI footprint
         PRinRadius2TMI[itmifoot] = counttrue
         ; do averages of PR 2a25 and 2b31 rain rate, and non-zero count, by TMI footprint
         PRsfcRainByTMI[itmifoot] = compute_average_and_n( surfRain_2a25[idxprtrue], $
                                                           n_non_zero, /NEGSTOZERO )
         PRcountSfcRainByTMI[itmifoot] = n_non_zero

         IF havefile2b31 EQ 1 THEN BEGIN
            PRsfcRain2b31ByTMI[itmifoot] = $
               compute_average_and_n( surfRain_2b31[idxprtrue], n_non_zero, /NEGSTOZERO )
            PRcountSfc2b31RainByTMI[itmifoot] = n_non_zero
         ENDIF

         ; -- number of PR footprints of rain type Convective
         idxPRconv = WHERE( rainType[idxprtrue] EQ 2, counttemp)
         PRcountRainConv[itmifoot] = counttemp

;         print, "TMI-PR range <= ", radiusStr, " km: ", counttrue, truedist[idxtruetmp]
;         print, ''
         IF counttrue GT maxPRinRadius THEN maxPRinRadius = counttrue
         IF counttrue GT npertmiray[raytmi[itmifoot]] THEN npertmiray[raytmi[itmifoot]] = counttrue
;         print, "TMI Ray, counttrue: ", raytmi[itmifoot], counttrue
         npertmiray[raytmi[itmifoot]] = npertmiray[raytmi[itmifoot]] + counttrue
      ENDIF
   endif
endfor

;print, "Max. PR footprints in ", radiusStr, " km: ", maxPRinRadius
;print, "PR footprints per TMI ray: ", npertmiray

idxwithpr=WHERE(npertmiray GT 0)
idxmaxpr=MAX(idxwithpr, min=idxminpr)
print, 'TMI start/end rays with PR coverage:', idxminpr, idxmaxpr

; determine whether we have any PR/TMI overlaps in dataset, only create netCDF
; if there is overlap data to write and netCDF output is specified

idxwithpr=WHERE(PRinRadius2TMI GT 0, countwithin)
IF countwithin GT 0 THEN BEGIN
   mintmi = MIN(scantmi[idxwithpr], MAX=maxtmi)
   print, 'TMI start/end scan with PR coverage:', mintmi, maxtmi
   IF do_nc THEN BEGIN
      ; determine the overlap begin/end in terms of TMI scans, already have
      ; first and last TMI rays in overlap region
      ncscans = (maxtmi-mintmi)+1
      ncrays = (idxmaxpr-idxminpr)+1
      ; create a netCDF file to hold the overlappiing matchup data
      ncfile = gen_tmi_pr_orbit_match_netcdf( ncfile_out, ncscans, ncrays, $
                                              radius, centerLat, centerLon, $
                                              TRMM_vers, tmiprfiles, $
                                              GEO_MATCH_VERS=geo_match_vers )
      IF ( ncfile EQ "NoGeoMatchFile" ) THEN $
         message, "Error in creating output netCDF file "+ncfile_out

      ; Open the netCDF file for writing
      ncid = NCDF_OPEN( ncfile, /WRITE )

      ; Write the scalar values to the netCDF file
      NCDF_VARPUT, ncid, 'tmi_rain_min', 0.01

      ; write the overlap-subsetted geospatial arrays
      NCDF_VARPUT, ncid, 'xCorners', xCornersTMI[*, mintmi:maxtmi, idxminpr:idxmaxpr]
      NCDF_VARPUT, ncid, 'yCorners', yCornersTMI[*, mintmi:maxtmi, idxminpr:idxmaxpr]
      NCDF_VARPUT, ncid, 'TMIlatitude', tmiLats[mintmi:maxtmi, idxminpr:idxmaxpr]
      NCDF_VARPUT, ncid, 'TMIlongitude', tmiLons[mintmi:maxtmi, idxminpr:idxmaxpr]

      ; write the overlap-subsetted science and TMIrayIndex arrays,
      ; and data field existence flags

      NCDF_VARPUT, ncid, 'surfaceType', surfaceType[mintmi:maxtmi, idxminpr:idxmaxpr]
      NCDF_VARPUT, ncid, 'have_surfaceType',  dataflags.have_surfaceType

      NCDF_VARPUT, ncid, 'surfaceRain', surfaceRain[mintmi:maxtmi, idxminpr:idxmaxpr]
      NCDF_VARPUT, ncid, 'have_surfaceRain',  dataflags.have_surfaceRain

      IF TRMM_vers EQ 6 THEN NCDF_VARPUT, ncid, 'rainFlag', $
                             TMIrainFlag[mintmi:maxtmi, idxminpr:idxmaxpr]
      NCDF_VARPUT, ncid, 'have_rainFlag',  dataflags.have_rainFlag

      NCDF_VARPUT, ncid, 'dataFlag', dataFlag[mintmi:maxtmi, idxminpr:idxmaxpr]
      NCDF_VARPUT, ncid, 'have_dataFlag', dataflags.have_dataFlag

      IF TRMM_vers_str EQ '7' THEN NCDF_VARPUT, ncid, 'PoP', $
                                   PoP[mintmi:maxtmi, idxminpr:idxmaxpr]
      NCDF_VARPUT, ncid, 'have_PoP', dataflags.have_PoP

      IF TRMM_vers_str EQ '7' THEN NCDF_VARPUT, ncid, 'freezingHeight', $
                                   freezingHeight[mintmi:maxtmi, idxminpr:idxmaxpr]
      NCDF_VARPUT, ncid, 'have_freezingHeight', dataflags.have_freezingHeight

      NCDF_VARPUT, ncid, 'TMIrayIndex', tmi_master_idx[mintmi:maxtmi, idxminpr:idxmaxpr]

      NCDF_VARPUT, ncid, 'nearSurfRain', PRsfcRainByTMI[mintmi:maxtmi, idxminpr:idxmaxpr]
      NCDF_VARPUT, ncid, 'have_nearSurfRain', dataflags_pr.have_nearSurfRain

      NCDF_VARPUT, ncid, 'nearSurfRain_2b31', PRsfcRain2b31ByTMI[mintmi:maxtmi, idxminpr:idxmaxpr]
      NCDF_VARPUT, ncid, 'have_nearSurfRain_2b31', dataflags_pr.have_nearSurfRain_2b31

     ;NCDF_VARPUT, ncid, 'BBheight', 
     ;NCDF_VARPUT, ncid, 'have_BBheight', dataflags_pr.have_BBheight

      NCDF_VARPUT, ncid, 'numPRinRadius', PRinRadius2TMI[mintmi:maxtmi, idxminpr:idxmaxpr]
      NCDF_VARPUT, ncid, 'numPRsfcRain', PRcountSfcRainByTMI[mintmi:maxtmi, idxminpr:idxmaxpr]
      NCDF_VARPUT, ncid, 'numPRsfcRainCom', PRcountSfc2b31RainByTMI[mintmi:maxtmi, idxminpr:idxmaxpr]
      NCDF_VARPUT, ncid, 'numConvectiveType', PRcountRainConv[mintmi:maxtmi, idxminpr:idxmaxpr]

      NCDF_CLOSE, ncid

      command = 'ls -al '+ncfile_out
      spawn, command
   ENDIF
ENDIF ELSE BEGIN
   mintmi = -1
   maxtmi = -1
   print, ''
   print, "****************************************"
   print, "* No TMI footprints are matched by PR! *"
   print, "****************************************"
   print, ''
ENDELSE

; define and populate data structure with the full matchup arrays, no subsetting
datastruc = {   orbit : orbit, $
              version : TRMM_vers, $
               subset : subset, $
              tmirain : surfaceRain, $
                numpr : PRinRadius2TMI, $
               prrain : PRsfcRainByTMI, $
              numprrn : PRcountSfcRainByTMI, $
              comrain : PRsfcRain2b31ByTMI, $
             numcomrn : PRcountSfc2b31RainByTMI, $
            numprconv : PRcountRainConv, $
              min_ray : idxminpr, $
              max_ray : idxmaxpr, $
             min_scan : mintmi, $
             max_scan : maxtmi, $
           center_lat : centerLat, $
           center_lon : centerLon, $
             xcorners : xCornersTMI, $
             ycorners : yCornersTMI }

; return the structure to the caller
return, datastruc
end
