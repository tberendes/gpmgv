;===============================================================================
;+
; Copyright © 2013, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; pr2tmi_nn.pro          Morris/SAIC/GPM_GV      January 2013
;
; DESCRIPTION
; -----------
; Performs a resampling of TMI and PR data to common volumes, defined by the
; TMI footprint sizes and locations.  The matchup is performed on the swath
; data in the area-in-common between the TMI and PR scans.  A matched set of
; PR and TMI orbit subset products (orbit number/subset, TRMM version) is
; input to the routine.  At a minimum the TMI 2A-12 and PR 2A-25 products
; must be present.  Returns a structure containing:
;
;   - TMI rain rate from the 2A-12 file (all TMI footprints in file)
;   - Count of PR footprints mapped to each of the above, based on 'radius'
;   - Mean PR 2A-25 near-surface rain rate matched to the TMI 2A-12 footprints
;   - Count of non-zero 2A-25 rain rates in above average
;   - Mean PR/TMI 2B-31 combined rain rate matched to the TMI 2A-12 footprints
;   - Count of non-zero 2B-31 rain rates in above average
;   - Count of PR footprints having rain type Convective, for each TMI footprint
;
; This procedure differs from pr2tmi.pro in the manner in which the PR
; footprints are matched to the TMI footprints.  This algorithm uses a nearest-
; neighbor approach, where each PR footprint is mapped to its nearest TMI
; footprint, rather than to every TMI footprint within a fixed radius.  In this
; procedure, the radius parameter is the maximum distance that a PR footprint
; can be from the nearest TMI footprint and still be linked to the TMI
; footprint.  Also, this procedure is speed-optimized for use with full-orbit
; input products, with no degradation in accuracy.
;
; MODULES
; -------
; 1)  pr2tmi_nn:             Main function to matchup PR rainfall to TMI,
;                            given a TMI 2A-12 filename as input.
; 2)  find_pr_for_tmi:       Utility to find PR products matching a TMI
;                            2A-12 product in orbit#, orbit subset, and
;                            TRMM product version.
; 3)  compute_averages:      Computes averages of array data, with options
;                            to:  a) set negative values to 0 in averaging, 
;                            or:  b) exclude them from the average.
; 4)  nearest_tmi_to_pr:     Identify the index of the TMI footprint nearest to
;                            the location of a given PR footprint, based on x-
;                            and y-coordinates of each.  No longer called in
;                            this version of the code, but still included for
;                            any reversion for "Open Source" posting.
;
; HISTORY
; -------
; 1/2013 by Bob Morris, GPM GV (SAIC)
;  - Created.
; 02/06/13  Morris/GPM GV/SAIC
; - Added NSPECIES to COMMON definition in pr2tmi_nn().
; 03/12/13  Morris/GPM GV/SAIC
; - Massively modified to speed up for full-orbit calculations & conserve memory.
; 10/07/14  Morris/GPM GV/SAIC
; - Renamed NSPECIES to NSPECIES_TMI.
;
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;===============================================================================

; MODULE 4:  nearest_tmi_to_pr
;
; DESCRIPTION
; -----------
; Identify the index of the TMI footprint nearest to the location of a given PR
; footprint and still within a cutoff distance defined by 'radius', based on x-
; and y-coordinates of each.  The parameter roughdxdy defines a starting
; distance threshold in terms of dx and dy within which to search for the
; closest TMI footprint, where radius <= roughdxdy.

FUNCTION nearest_tmi_to_pr, prfootxy, tmi_x, tmi_y, roughdxdy, radius, min_dist, tmi_master_idx

   tmi_index_nearest_pr = -1L  ; initialize return value to "not found"
   IF roughdxdy LT radius THEN roughdxdy = radius * 1.5
   radius_sq = radius^2  ; avoid the use of SQRT in array comparisons

   ; do the rough distance check based on Delta x and y
   idxrough = WHERE( ( ABS(tmi_x-prfootxy[0]) LT roughdxdy ) $
                 AND ( ABS(tmi_y-prfootxy[1]) LT roughdxdy ), count_tm )

   if count_tm GT 0 then begin
      ; compute accurate PR-TMI footprint distances for this subset of TMI footprints
      truedist_sq = REFORM( (tmi_x[idxrough]-prfootxy[0])^2 + $
                            (tmi_y[idxrough]-prfootxy[1])^2 )

      min_dist_sq = MIN( truedist_sq, idx_min_dist )
      IF min_dist_sq LE radius_sq THEN BEGIN
         tmi_index_nearest_pr = tmi_master_idx[idxrough[idx_min_dist]]
         min_dist = SQRT(min_dist_sq)
      ENDIF
   endif else begin
      print, "PR index: ", ifoot2do, " has no TMI footprints in rough check distance"
      min_dist = 9999.99
   endelse

   return, tmi_index_nearest_pr
end

;===============================================================================

; MODULE 3:  compute_average_and_n

FUNCTION compute_average_and_n, values_in, n_non_zero

; DESCRIPTION
; -----------
; Compute average of array elements included in values_in array, and the number
; of non-zero values ("n_non_zero") contained in the average.  This function
; used to do more, which is why it still exists.

meanval = MEAN(values_in)
idx_gt_zero = WHERE( values_in GT 0.0, n_non_zero)

return, meanval
end

;===============================================================================

; MODULE 2:  FUNCTION find_pr_for_tmi

; DESCRIPTION
; -----------
; Given the directory path and file basename of a TMI 2A-12 file, searches
; for the corresponding (by site, date, orbit, TRMM version) PR file of the
; requested type (e.g., 2A25) under a PR-product-specific directory under the
; "common" TRMM product directory defined by convention as the next higher
; directory above /2A12.  If a matching PR file of the requested type is not
; found, then a well-known bogus file name will be returned in the FILE_XXXX
; keyword value (e.g., "no_2A25_file").  By default, only looks for the matching
; HDF-format file.  If TRY_NC is set, then will also look for a matching netCDF
; (.nc file extension) file if the HDF file is not found first.  Returns a
; structure with a tag for each PR product type, whose values indicate which
; format ('HDF' or 'NC') of file was found for each product type requested, or
; 'None' if the product type was not found or not requested.
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
; try_nc          - Binary parameter.  If set, then look for the matching netCDF
;                   file if an HDF-format file is not found.  Tally which type
;                   of file (or None) was found for each PR product type in the
;                   tag/value pairs in the returned structure.
;
; HISTORY
; -------
; 09/20/12  Morris/GPM GV/SAIC
; - Created.
; 03/28/13  Morris/GPM GV/SAIC
; - Added TRY_NC option to look for a subsetted netCDF version of the PR data
;   if the matching HDF version is not present in the searched path.
; - Changed to FUNCTION, returning a structure indicating which PR file format
;   (or 'None', if not found) was found for each PR product type requested.
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;===============================================================================

FUNCTION find_pr_for_tmi, tmi_filepath, FILE_1C21=file_1c21,        $
                          FILE_2A23=file_2a23, FILE_2A25=file_2a25, $
                          FILE_2B31=file_2b31, TRY_NC=try_nc

pathname_len = STRLEN(tmi_filepath)
pathTypePos = STRPOS(tmi_filepath, '2A12/2A12')
typesPR = { type1c21 : 'None', type2a23 : 'None', $
            type2a25 : 'None', type2b31 : 'None'  }

IF pathTypePos NE -1 THEN BEGIN

   rootpath = STRMID(tmi_filepath, 0, pathTypePos)
   postname = STRMID(tmi_filepath, pathTypePos+9, pathname_len-(pathTypePos+8))
   ;print, 'postname = ', postname
   ;print, 'rootpath = ', rootpath
   IF KEYWORD_SET(try_nc) THEN BEGIN
      ; set a flag to look for '.nc' file matches, and format file postfix text
      nc_too = 1
      hdfPos = STRPOS(STRUPCASE(postname), "HDF")
      IF hdfPos EQ -1 THEN BEGIN
         ; disable searching for '.nc' file matches, can't substitute
         print, "Can't find/replace 'HDF*' in HDF filename "+tmi_filepath
         nc_too = 0
      ENDIF ELSE postname_nc = STRMID(postname,0,hdfPos)+"nc*"
   ENDIF ELSE nc_too = 0

   IF N_ELEMENTS(file_1c21) NE 0 THEN BEGIN
      file_1c21 = 'no_1C21_file'
      file_1c21_2match = rootpath+'1C21/1C21'+postname
      IF FIND_ALT_FILENAME(file_1c21_2match, foundfile) NE 0 THEN BEGIN
         file_1c21 = foundfile
         typesPR.type1c21 = 'HDF'
      ENDIF ELSE BEGIN
         IF nc_too EQ 1 THEN BEGIN
            file_1c21_2match = rootpath+'1C21/1C21'+postname_nc
            IF FIND_ALT_FILENAME(file_1c21_2match, foundfile) NE 0 THEN BEGIN
               file_1c21 = foundfile
               typesPR.type1c21 = 'NC'
               print, "Found netCDF format file: ", foundfile
            ENDIF
         ENDIF
      ENDELSE
   ENDIF

   IF N_ELEMENTS(file_2a23) NE 0 THEN BEGIN
      file_2a23 = 'no_2A23_file'
      file_2a23_2match = rootpath+'2A23/2A23'+postname
      IF FIND_ALT_FILENAME(file_2a23_2match, foundfile) NE 0 THEN BEGIN
         file_2a23 = foundfile
         typesPR.type2a23 = 'HDF'
      ENDIF ELSE BEGIN
         IF nc_too EQ 1 THEN BEGIN
            file_2a23_2match = rootpath+'2A23/2A23'+postname_nc
            IF FIND_ALT_FILENAME(file_2a23_2match, foundfile) NE 0 THEN BEGIN
               file_2a23 = foundfile
               typesPR.type2a23 = 'NC'
               print, "Found netCDF format file: ", foundfile
            ENDIF
         ENDIF
      ENDELSE
   ENDIF

   IF N_ELEMENTS(file_2a25) NE 0 THEN BEGIN
      file_2a25 = 'no_2A25_file'
      file_2a25_2match = rootpath+'2A25/2A25'+postname
      IF FIND_ALT_FILENAME(file_2a25_2match, foundfile) NE 0 THEN BEGIN
         file_2a25 = foundfile
         typesPR.type2a25 = 'HDF'
      ENDIF ELSE BEGIN
         IF nc_too EQ 1 THEN BEGIN
            file_2a25_2match = rootpath+'2A25/2A25'+postname_nc
            IF FIND_ALT_FILENAME(file_2a25_2match, foundfile) NE 0 THEN BEGIN
               file_2a25 = foundfile
               typesPR.type2a25 = 'NC'
               print, "Found netCDF format file: ", foundfile
            ENDIF
         ENDIF
      ENDELSE
   ENDIF

   IF N_ELEMENTS(file_2b31) NE 0 THEN BEGIN
      file_2b31 = 'no_2B31_file'
      file_2b31_2match = rootpath+'2B31/2B31'+postname
      IF FIND_ALT_FILENAME(file_2b31_2match, foundfile) NE 0 THEN BEGIN
         file_2b31 = foundfile
         typesPR.type2b31 = 'HDF'
      ENDIF ELSE BEGIN
         IF nc_too EQ 1 THEN BEGIN
            file_2b31_2match = rootpath+'2B31/2B31'+postname_nc
            IF FIND_ALT_FILENAME(file_2b31_2match, foundfile) NE 0 THEN BEGIN
               file_2b31 = foundfile
               typesPR.type2b31 = 'NC'
               print, "Found netCDF format file: ", foundfile
            ENDIF
         ENDIF
      ENDELSE
   ENDIF

ENDIF

return, typesPR
end

;===============================================================================

; MODULE 1:  FUNCTION pr2tmi_nn

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
; radius        - Non-default maximum radius to use for limiting PR footprints
;                 to be included in the PR data average surrounding each TMI
;                 surface footprint location.
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
; try_nc        - Binary parameter.  If set, then look for the PR netCDF files
;                 matching the TMI 2A12 file if HDF-format files are not found.
;
; print_times   - Binary option.  If set, then the elapsed time required to
;                 complete major components of the matchup will be printed to
;                 the terminal.
;
; HISTORY
; -------
; 1/3/13  Morris/GPM GV/SAIC
; - Created.
; 1/31/13  Morris/GPM GV/SAIC
; - Added BBheight to 2A23 variables to be read, and calling running_avg_bb() to
;   compute fit of BB height to PR scan line number.
; - Added check of PR products to make sure they have the same number of scans.
; - Added BBheight to output structure and write to netCDF file.
; - Added return value of -1 in case of failures.
; 02/06/13  Morris/GPM GV/SAIC
; - Added NSPECIES to COMMON definition.
; 03/12/13  Morris/GPM GV/SAIC
; - Massively modified to speed up for full-orbit calculations, conserve memory.
; 03/28/13  Morris/GPM GV/SAIC
; - Added TRY_NC keyword option to pass along to find_pr_for_tmi().
; - Modified call to find_pr_for_tmi() to FUNCTION call.
; - Added logic to look at structure returned from find_pr_for_tmi() to decide
;   which function should be called to read the PR files based on their product
;   formats (HDF vs. netCDF).
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;===============================================================================

FUNCTION memory_test_child, tmi2a12file, RADIUS=radius, NCFILE_OUT=ncfile_out, $
                    PATH_OUT=path_out, TRY_NC=try_nc, PRINT_TIMES=print_times, $
                    SKIP_EXISTING=skip_existing

COMMON sample, start_sample, sample_range, num_range, NPIXEL_TMI_PR, NSPECIES_TMI

; "Include" file for DATA_PRESENT, NO_DATA_PRESENT
@grid_def.inc
; "Include" file for TMI-product-specific parameters (i.e., NPIXEL_TMI):
@tmi_params.inc
; "Include" file for names, paths, etc.:
@environs.inc
; "Include" file for special values in netCDF files: Z_BELOW_THRESH, etc.
@pr_params.inc

print_times=KEYWORD_SET(print_times)

datastruc = -1 

; set the default radius if one is not provided or is out-of-range
IF N_ELEMENTS(radius) EQ 0 THEN BEGIN
   print, "Setting maximum radius from TMI footprint to 14 km" & print, ""
   radius = 14.0
ENDIF ELSE BEGIN
   IF (radius LT 10.0) OR (radius GT 50.0) THEN BEGIN
      print, "Radius must be between 10.0 and 50.0 km, supplied value = ", radius
      print, "Setting maximum radius from TMI footprint to 14 km" & print, ""
      radius = 14.0
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
; Full orbit files from the DAAC have 'HDF' in the 5th section of the file name
; rather than the PPS convention of the orbit subset name.  Override it.
IF subset EQ 'HDF' THEN BEGIN
   print, "Overriding non-existent orbit subset to 'FullOrbit'"
   subset = 'FullOrbit'
ENDIF

; set up the output netCDF filename if we are writing one
ncfile_out = KEYWORD_SET( ncfile_out )
IF ( ncfile_out ) THEN BEGIN
   do_nc = 1
   ncfile_base = 'PRtoTMI_NN.' + yymmdd + '.' + orbit + '.' $
                 + TRMM_vers_str + '.' + subset + '_' + radiusStr + 'km.nc'
   IF N_ELEMENTS(path_out) EQ 0 THEN $
      ncfile_out = NCGRIDS_ROOT+PR_TMI_MATCH_NCDIR+'/'+ncfile_base $
   ELSE ncfile_out = path_out + '/' + ncfile_base
   print,"" & print, "Writing output to netCDF file: ", ncfile_out & print,""
   IF KEYWORD_SET(skip_existing) THEN BEGIN
      IF FIND_ALT_FILENAME(ncfile_out+'.gz', foundfile) NE 0 THEN BEGIN
         print, "File ", foundfile, " already exists, skipping case."
         return, -1
      ENDIF
   ENDIF
ENDIF ELSE do_nc = 0

   ; find the PR files matching the TMI file specification
   file_1c21 = 'no_1C21_file'
   file_2a23 = 'no_2A23_file'
   file_2a25 = 'no_2A25_file'
   file_2b31 = 'no_2B31_file'
   prformats = find_pr_for_tmi( tmi2a12file, $  ;FILE_1C21=file_1c21, $
                                FILE_2A23=file_2a23, FILE_2A25=file_2a25, $
                                FILE_2B31=file_2b31, TRY_NC=try_nc )

   IF file_2a25 EQ 'no_2A25_file' THEN BEGIN
      print, "In pr2tmi.pro: Could not find 2A25 file to match ", tmi2a12file
      print, "Exiting with error."
      return, 0
   ENDIF

   ; set up the output array of TMI and PR filenames for netCDF file
   IF do_nc THEN $
      tmiprfiles = [tmi2a12file, file_1c21, file_2a23, file_2a25, file_2b31]
;goto, skip2

   ; read the TMI 2A12 and PR 2A25 files
   ; initialize TMI variables/arrays and read 2A12 fields
      SAMPLE_RANGE=0
      START_SAMPLE=0
      geolocation = FLTARR(sample_range>1, NPIXEL_TMI, 2)
         dataFlag = BYTARR(sample_range>1, NPIXEL_TMI)
      TMIrainFlag = BYTARR(sample_range>1, NPIXEL_TMI)
      surfaceType = INTARR(sample_range>1, NPIXEL_TMI)
      surfaceRain = FLTARR(sample_range>1, NPIXEL_TMI)
              PoP = INTARR(sample_range>1, NPIXEL_TMI)
   freezingHeight = INTARR(sample_range>1, NPIXEL_TMI)

   ;  read the TMI fields needed
   status = read_tmi_2a12_memtest( tmi2a12file, $
                                  GEOL=geolocation, $
                                  DATAFLAG=dataFlag, $
                                  RAINFLAG=TMIrainFlag, $
                                  SURFACETYPE=surfaceType, $
                                  SURFACERAIN=surfaceRain, $
                                  POP=PoP, $
                                  FREEZINGHEIGHT=freezingHeight )

   IF ( status NE 0 ) THEN BEGIN
      PRINT, ""
      PRINT, "pr2tmi.pro:  ERROR reading fields from ", tmi2a12file
      PRINT, "Exiting with error."
      return, 0
   ENDIF
goto, skipover

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


; grab the number of TMI scans read
n_tmi_scans = sample_range

; split GEOL data fields into tmiLats and tmiLons arrays
tmiLons = FLTARR(NPIXEL_TMI,n_tmi_scans)
tmiLats = FLTARR(NPIXEL_TMI,n_tmi_scans)
tmiLons[*,*] = geolocation[1,*,*]
tmiLats[*,*] = geolocation[0,*,*]

; NOTE THAT THE GEOLOCATION ARRAYS ARE IN (RAY,SCAN) COORDINATES, WHILE ALL THE
; OTHER ARRAYS ARE IN (SCAN,RAY) COORDINATE ORDER.  NEED TO ACCOUNT FOR THIS
tmiLons = TRANSPOSE(tmiLons)
tmiLats = TRANSPOSE(tmiLats)

tmi_master_idx = LINDGEN(n_tmi_scans, NPIXEL_TMI)  ; "actual" TMI footprints
n_tmi_feet = N_ELEMENTS(tmi_master_idx)             ; number of TMI footprints defined
; get arrays of TMI scan and ray number
rayscan = ARRAY_INDICES(surfaceType, tmi_master_idx)
rayscan = REFORM(rayscan, 2, n_tmi_scans, NPIXEL_TMI)
scantmi = REFORM(rayscan[0,*,*])
raytmi = REFORM(rayscan[1,*,*])

; holds info on how many PR footprints there are in each TMI ray position:
npertmiray = LONARR(NPIXEL_TMI)

; hold PR science values averaged/boiled down to TMI resolution defined by "radius"
; -- how many PR footprints "map" to the TMI footprint, by radius criterion
PRinRadius2TMI = MAKE_ARRAY(n_tmi_scans, NPIXEL_TMI, /INT, VAL=0)
; -- averages of PR 2a25 and 2b31 rain rate, and non-zero count, by TMI footprint
PRsfcRainByTMI = MAKE_ARRAY(n_tmi_scans, NPIXEL_TMI, /FLOAT, VAL=-99.0)
PRcountSfcRainByTMI = MAKE_ARRAY(n_tmi_scans, NPIXEL_TMI, /INT, VAL=0)
PRsfcRain2b31ByTMI = MAKE_ARRAY(n_tmi_scans, NPIXEL_TMI, /FLOAT, VAL=-99.0)
PRcountSfc2b31RainByTMI = MAKE_ARRAY(n_tmi_scans, NPIXEL_TMI, /INT, VAL=0)
; -- number of PR footprints of rain type Convective
PRcountRainConv = MAKE_ARRAY(n_tmi_scans, NPIXEL_TMI, /INT, VAL=0)
; -- mean bright band height from PR running average BB height
PRbbHeight = MAKE_ARRAY(n_tmi_scans, NPIXEL_TMI, /FLOAT, VAL=-99.0)

; figure out our domain bounds relative to TMI coverage
latmax = MAX(tmiLats, MIN=latmin)
lonmax = MAX(tmiLons, MIN=lonmin)

; set up a Mercator map projection and compute TMI footprint cartesian coordinates in km
centerLat = (latmax+latmin)/2.0
centerLon = (lonmax+lonmin)/2.0
mymap = MAP_PROJ_INIT('Mercator', CENTER_LON=centerLon, CENTER_LAT=centerLat)
tmi_xy = MAP_PROJ_FORWARD(tmiLons, tmiLats, MAP=mymap) / 1000.

; if our footprints approach the map x-edges, then set up to check map limits
; later on when we compute the footprint corners
IF lonmax-lonmin GT 355.0 THEN BEGIN
   CheckMapLimits=1
   ; compute the maximum and minimum x values on this map
   maxlonmap = centerLon+179.9999
   minlonmap = centerLon-179.9999
   IF maxlonmap GT 180.0 THEN maxlonmap = 360.0 - maxlonmap
   IF minlonmap LT -180.0 THEN minlonmap = minlonmap + 360.0
   min_xy = MAP_PROJ_FORWARD(minlonmap, centerLat, MAP=mymap) / 1000.
   max_xy = MAP_PROJ_FORWARD(maxlonmap, centerLat, MAP=mymap) / 1000.
   ;print, "Map min X, max X: ", min_xy[0], max_xy[0]
ENDIF ELSE CheckMapLimits=0

; separate the x and y arrays for footprint corner calculations, later on
tmi_x0 = REFORM(tmi_xy[0,*], n_tmi_scans, NPIXEL_TMI)
tmi_y0 = REFORM(tmi_xy[1,*], n_tmi_scans, NPIXEL_TMI)
skip2:
   ; initialize PR variables/arrays and read 2A25 fields from the file format
   ; we previously identified in find_pr_for_tmi()
   CASE prformats.type2a25 OF
      'HDF' : BEGIN
                 SAMPLE_RANGE=0
                 START_SAMPLE=0
                 num_range = NUM_RANGE_2A25
                 geolocation=FLTARR(2,RAYSPERSCAN,sample_range>1)
                 rainType=INTARR(sample_range>1,RAYSPERSCAN)
                 surfRain_2a25=FLTARR(sample_range>1,RAYSPERSCAN)
                 status = read_pr_2a25_fields( file_2a25, GEOL=geolocation, $
                                               TYPE=rainType, $
                                               SURFACE_RAIN=surfRain_2a25 )
              END ;;
       'NC' : BEGIN
                 geolocation=1
                 rainType=1
                 surfRain_2a25=1
                 status = read_2a25_netcdf( file_2a25, GEOL=geolocation, $
                                            TYPE=rainType, $
                                            SURFACE_RAIN=surfRain_2a25 )
              END ;;
       ELSE : message, "Illegal product format '"+prformats.type2a25 + $
                       "' for 2A25 file: "+file_2a25  ;;
   ENDCASE

   IF ( status NE 0 ) THEN BEGIN
      PRINT, ""
      PRINT, "ERROR reading fields from ", file_2a25
      PRINT, "Skipping events for orbit = ", orbit
      PRINT, ""
      return, 0
   ENDIF
goto, skipover

   dataflags_pr = get_geo_match_nc_struct( 'fields' )
   idxcheck = WHERE(surfRain_2a25 NE 0.0)
   if idxcheck[0] NE -1 THEN dataflags_pr.have_nearSurfRain = 1
   idxcheck = WHERE(rainType NE 0)
   if idxcheck[0] NE -1 THEN dataflags_pr.have_rainType = 1
   ; copy statuses from dataflags_pr to matching dataflags tags
   dataflags.have_nearSurfRain = dataflags_pr.have_nearSurfRain
   dataflags.have_rainType = dataflags_pr.have_rainType
   dataflags.have_BBheight = dataflags_pr.have_BBheight
   dataflags.have_nearSurfRain_2b31 = dataflags_pr.have_nearSurfRain_2b31

   ; boil down rain type to 3 categories: 1,2,3
   rainType = rainType/100

   ; split GEOL data fields into prlats and prlons arrays and transpose
   ; into order of science data fields
   prLons = REFORM( geolocation[1,*,*] )
   prLons = TRANSPOSE(prLons)
   prLats = REFORM( geolocation[0,*,*] )
   prLats = TRANSPOSE(prLats)
   geolocation = 0b  ; free some memory

   ; compute PR footprint cartesian coordinates, in km
   pr_xy = MAP_PROJ_FORWARD(prLons, prLats, MAP=mymap) / 1000.

   n_pr_scans = sample_range
   pr_master_idx = LINDGEN(n_pr_scans, RAYSPERSCAN)  ; 1-D indices of all PR footprints
   n_pr_feet = N_ELEMENTS(pr_master_idx)               ; number of PR footprints defined
   ; get arrays of PR scan and ray number
   rayscan = ARRAY_INDICES(rainType, pr_master_idx)
   rayscan = REFORM(rayscan, 2, n_pr_scans, RAYSPERSCAN)
   scanpr = REFORM(rayscan[0,*,*])
   raypr = REFORM(rayscan[1,*,*])
   rayscan = 0b  ; free some memory

IF (print_times) THEN BEGIN
   print, ''
   print, "Beginning PR-TMI spatial matching..."
   timestart=systime(1)
ENDIF

ntmimatchtrue = 0L
maxPRinRadius = 0

; Skip over the following large block of code in favor of call to match_2d.pro,
; but keep this code around in case we go Open Source

GOTO, SkipOverOldMatchup
;====================================================================================
; track the index of the nearest TMI footprint to each PR footprint
tmi_index_nearest_pr = MAKE_ARRAY(n_pr_feet, /LONG, value = -1)

; find TMI footprints in rough range of PR footprints based on lat/lon,
; then find nearest TMI footprint to the PR footprint based on x,y
roughlat = (radius*1.5)/111.1
roughlon = roughlat*1.3
roughdxdy = radius * 1.25

; define a subset of the center TMI rays to limit the number of calculations
; performed in the PR matchup to TMI locations
tmiLats_SUB = tmiLats[*,70:135]
tmiLons_SUB = tmiLons[*,70:135]
tmi_x0_SUB = tmi_x0[*,70:135]
tmi_y0_SUB = tmi_y0[*,70:135]
tmi_master_idx_SUB = tmi_master_idx[*,70:135]

; first, find the relationship between PR scan number and TMI scan number
tmi_scan_first_pr = -1
for iscan2do = 0L, n_pr_scans/3  do begin
   ; grab the middle ray of the 1st PR scan and find the nearest TMI footprint
   pridx = pr_master_idx[iscan2do, RAYSPERSCAN/2]
   prfootxy = pr_xy[*, pridx]
   tmi_index_nearest = nearest_tmi_to_pr( prfootxy, tmi_x0_SUB, tmi_y0_SUB, $
                                          roughdxdy, radius, min_dist, $
                                          tmi_master_idx_SUB )
   IF min_dist LE 6.0 AND tmi_index_nearest GE 0 THEN BEGIN
      tmi_scan_first_pr = scantmi[tmi_index_nearest]
      pr_scan_first = iscan2do
      print, "TMI index = ", tmi_scan_first_pr, " for PR scan ", iscan2do
      break
   ENDIF ELSE BEGIN
      print, "No TMI footprint within 6 km for PR scan ", iscan2do
   ENDELSE
endfor

tmi_scan_last_pr = -1
for iscan2do = n_pr_scans-1, (n_pr_scans*2)/3, -1  do begin
   ; grab the middle ray of the last PR scan and find the nearest TMI footprint
   pridx = pr_master_idx[iscan2do, RAYSPERSCAN/2]
   prfootxy = pr_xy[*, pridx]
   tmi_index_nearest = nearest_tmi_to_pr( prfootxy, tmi_x0_SUB, tmi_y0_SUB, $
                                          roughdxdy, radius, min_dist, $
                                          tmi_master_idx_SUB )
   IF min_dist LE 6.0 AND tmi_index_nearest GE 0 THEN BEGIN
      tmi_scan_last_pr = scantmi[tmi_index_nearest]
      pr_scan_last = iscan2do
      print, "TMI index = ", tmi_scan_last_pr, " for PR scan ", iscan2do
      print, "Last PR scan in dataset = ", n_pr_scans-1
      break
   ENDIF ELSE BEGIN
      print, "No TMI footprint within 6 km for PR scan ", iscan2do
   ENDELSE
endfor

IF tmi_scan_first_pr GE 0 AND tmi_scan_last_pr GT tmi_scan_first_pr THEN BEGIN
   ; compute the linear fit 'y=mx+b' of TMI scan number y to PR scan number x
   IF pr_scan_last NE pr_scan_first THEN BEGIN
      ; get slope 'm'
      m = FLOAT(tmi_scan_last_pr-tmi_scan_first_pr) $
          / FLOAT(pr_scan_last-pr_scan_first)
      ; get intercept 'b'
      b = tmi_scan_last_pr - m * pr_scan_last
   ENDIF ELSE message, "Line slope is undefined, TMI scan vs. PR scan."
ENDIF ELSE message, "Line slope is zero or undefined, TMI scan vs. PR scan."

for iprscan = 0L, n_pr_scans-1 do begin
   tmiscanmid = LONG(m * iprscan + b +0.5)
   tmiscan1 = (tmiscanmid-3) > 0
   tmiscan2 = (tmiscanmid+3) < (n_tmi_scans-1)
   tmi_x0_SUB2 = tmi_x0_SUB[tmiscan1:tmiscan2,*]
   tmi_y0_SUB2 = tmi_y0_SUB[tmiscan1:tmiscan2,*]
   tmi_master_idx_SUB2 = tmi_master_idx_SUB[tmiscan1:tmiscan2,*]
   for iprray = 0L, RAYSPERSCAN-1 do begin
      ifoot2do = pr_master_idx[iprscan,iprray]
      prfootlat = prLats[ifoot2do]
      prfootlon = prLons[ifoot2do]
      prfootxy = pr_xy[*, ifoot2do]
      tmi_index_nearest = nearest_tmi_to_pr( prfootxy, tmi_x0_SUB2, $
                                             tmi_y0_SUB2, roughdxdy, radius, $
                                             min_dist, tmi_master_idx_SUB2 )
      IF tmi_index_nearest NE -1 THEN $
         tmi_index_nearest_pr[ifoot2do] = tmi_index_nearest $
      ELSE print, "PR index: ", ifoot2do, " has no TMI footprints in radius ", $
                  radius, " km, nearest = ", min_dist, " km"
   endfor
endfor
; END OF CODE BLOCK FOR 'OLD' PR-TMI SPATIAL MATCHUP
;====================================================================================
SkipOverOldMatchup:

; here is the code block for the new spatial matchup.  Split out PR and TMI
; x and y coordinate arrays for call to match_2d(), which does it all
x2 = REFORM(tmi_xy[0,*])
y2 = REFORM(tmi_xy[1,*])
tmi_xy = 0b  ; free array's memory
x1 = REFORM(pr_xy[0,*])
y1 = REFORM(pr_xy[1,*])
pr_xy = 0b  ; free array's memory
match_distance=1.0
tmi_index_nearest_pr = match_2d( x1, y1, x2, y2, radius, $
                                 MATCH_DISTANCE=match_distance )
x1=0b & x2=0b & y1=0b & y2=0b  ; free arrays' memory
print, ''
print, "Max. PR-TMI distance (km): ", MAX( match_distance )
print, ''
match_distance = 0b  ; free array's memory

IF (print_times) THEN BEGIN
   print, "Finished PR-TMI spatial matching, elapsed seconds: ", systime(1)-timestart
   print, ''
   print, "Starting PR file reading..."
   print, ''
   timestart=systime(1)
ENDIF

   ; initialize PR variables/arrays and read fields
   ; -- read the rest of the fields needed for the averaging now
   SAMPLE_RANGE=0
   START_SAMPLE=0
   num_range = NUM_RANGE_2A25

   ;  we don't have any 1c21 fields/files involved, tally it as such
   havefile1c21 = 0

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
      ; read either the hdf or netcdf file, as indicated
      CASE prformats.type2a23 OF
         'HDF' : BEGIN
                    BBheight=intarr(sample_range>1,RAYSPERSCAN)
                    status_2a23=INTARR(sample_range>1,RAYSPERSCAN)
                    bbstatus=INTARR(sample_range>1,RAYSPERSCAN)
                    status = read_pr_2a23_fields(file_2a23, BBHEIGHT=BBheight, $
                                                 STATUSFLAG=status_2a23, $
                                                 BBstatus=bbstatus)
                 END ;;
          'NC' : BEGIN
                    BBheight=1
                    status_2a23=1
                    bbstatus=1
                    status = read_2a23_netcdf( file_2a23, BBHEIGHT=BBheight, $
                                               STATUSFLAG=status_2a23, $
                                               BBstatus=bbstatus )
                 END ;;
          ELSE : message, "Illegal product format '"+prformats.type2a23 + $
                          "' for 2A23 file: "+file_2a23  ;;
      ENDCASE

      IF ( status NE 0 ) THEN BEGIN
         PRINT, ""
         PRINT, "ERROR reading fields from ", file_2a23
         PRINT, "Skipping 2A23 processing for orbit = ", orbit
         PRINT, ""
         havefile2a23 = 0
      ENDIF ELSE BEGIN
         ; verify that we are looking at the same subset of scans (size-wise, anyway)
         ; between the 2a23 and 2a25 product
         IF N_ELEMENTS(BBheight) NE N_ELEMENTS(rainType) THEN BEGIN
            PRINT, ""
            PRINT, "Mismatch between #scans in ", file_2a25, " and ", file_2a23
            HELP, BBheight, rainType
            PRINT, "Quitting processing."
            havefile2a23 = 0
;            GOTO, bailOut
         ENDIF
      ENDELSE
   ENDELSE

   ; compute a running-average mean bright band height
   IF havefile2a23 EQ 1 THEN BEGIN
      ;idxcheck = WHERE(status_2a23 NE 0)  ; no good!  status=0 for GOOD/Ocean
      ;if idxcheck[0] NE -1 THEN dataflags_pr.have_status_2a23 = 1
      dataflags_pr.have_status_2a23 = 1
      dataflags_pr.have_BBheight = 1
      idxcheck = WHERE(bbstatus NE 0)
      if idxcheck[0] NE -1 THEN BEGIN
         dataflags_pr.have_BBstatus = 1
         max_gap = 0  ; maximum # PR scans between good BB measurements
         meanBBrunning = running_avg_bb( BBheight, bbstatus, $
                         MAX_GAP=max_gap, VERBOSE=0 )
         idxcheck = WHERE(meanBBrunning GT 0.0)
         if idxcheck[0] NE -1 THEN dataflags_pr.have_BBheight = 1
      endif
   ENDIF

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
      ; read either the hdf or netcdf file, as indicated
      CASE prformats.type2b31 OF
         'HDF' : BEGIN
                    surfRain_2b31=FLTARR(sample_range>1,RAYSPERSCAN)
                    status = read_pr_2b31_fields( file_2b31, surfRain_2b31)
                 END ;;
          'NC' : BEGIN
                    surfRain_2b31=1
                    status = read_2b31_netcdf( file_2b31, $
                                               SURFACE_RAIN_2B31=surfRain_2b31 )
                 END ;;
          ELSE : message, "Illegal product format '"+prformats.type2b31 + $
                          "' for 2B31 file: "+file_2b31  ;;
      ENDCASE

      IF ( status NE 0 ) THEN BEGIN
         PRINT, ""
         PRINT, "ERROR reading fields from ", file_2b31
         PRINT, "Skipping 2B31 processing for orbit = ", orbit
         PRINT, ""
         havefile2b31 = 0
      ENDIF ELSE BEGIN
         ; verify that we are looking at the same subset of scans (size-wise, anyway)
         ; between the 2b31 and 2a25 product
         IF N_ELEMENTS(surfRain_2b31) NE N_ELEMENTS(rainType) THEN BEGIN
            PRINT, ""
            PRINT, "Mismatch between #scans in ", file_2a25, " and ", file_2b31
            HELP, surfRain_2b31, rainType
            PRINT, "Quitting processing."
            havefile2b31 = 0
;            GOTO, bailOut
         ENDIF
      ENDELSE
   ENDELSE

   idxcheck = WHERE(surfRain_2b31 NE 0)
   if idxcheck[0] NE -1 THEN dataflags_pr.have_nearSurfRain_2b31 = 1

IF (print_times) THEN BEGIN
   print, ''
   print, "Finished PR file reading.  Elapsed seconds: ", systime(1)-timestart
   print, ''
   print, "Starting PR averaging..."
   timestart=systime(1)
ENDIF

; every PR footprint should have a TMI footprint linked to it, but check anyway
pridxtmimapped = WHERE(tmi_index_nearest_pr GE 0, ntmimapped)
IF ntmimapped EQ 0 THEN BEGIN
   message, "No TMI locations mapped to PR!"
ENDIF ELSE BEGIN
   ; preset the negative values of 2a25 and 2b31 rain rate to zero
   idxrainneg = WHERE(surfRain_2a25 LT 0.0, nneg)
   IF nneg GT 0 THEN surfRain_2a25[idxrainneg] = 0.0
   idxrainneg = WHERE(surfRain_2b31 LT 0.0, nneg)
   IF nneg GT 0 THEN surfRain_2b31[idxrainneg] = 0.0
   idxrainneg = 0b    ; 'free' the memory

   ; pare list down to those with tmi_index values mapped to PR footprints
   tmi_idx_set = tmi_index_nearest_pr[pridxtmimapped]
   ; do a histogram of tmi_index within the defined values in tmi_idx_set
   tmihist = HISTOGRAM(tmi_idx_set, LOCATIONS=tmiidxvals, REVERSE_INDICES=R)
   ; get list of histo bins which have one or more PR indices mapped to them
   idxtmihistdef = WHERE(tmihist GT 0, ntmimatchtrue)
   ; loop thru the mapped tmi_indexes, find those PR footprints mapped to each,
   ; and compute PR/COM averages and max/min TMI ray/scan values
   for itmi = 0L, ntmimatchtrue-1 do begin
      ; get the tmi_index value itself
      this_tmi_idx = tmiidxvals[idxtmihistdef[itmi]]
      ; get PR array indices mapped to this TMI footprint via the
      ; reverse indices assigned to this bin/tmi index
      ibin1 = idxtmihistdef[itmi]
      IF itmi LT ntmimatchtrue-1 THEN ibin2 = idxtmihistdef[itmi+1] $
      ELSE ibin2 = idxtmihistdef[itmi] + 1
      ; get the indices of the tmi_idx_set elements mapped to this_tmi_idx
      RthisTMI = R[R[ibin1] : R[ibin2]-1]
      pr_idx2avg = pridxtmimapped[ RthisTMI ]
      n_pr2avg = N_ELEMENTS(pr_idx2avg)

      n_non_zero = 0                   ; number of non-zero PR values in average
      ; do the PR and COM rainrate averages for footprints mapped to this TMI footprint
      PRinRadius2TMI[this_tmi_idx] = n_pr2avg
      ; do averages of PR 2a25 and 2b31 rain rate, and non-zero count, by TMI footprint
      PRsfcRainByTMI[this_tmi_idx] = $
         compute_average_and_n( surfRain_2a25[pr_idx2avg], n_non_zero )
      PRcountSfcRainByTMI[this_tmi_idx] = n_non_zero

      IF havefile2b31 EQ 1 THEN BEGIN
         PRsfcRain2b31ByTMI[this_tmi_idx] = $
            compute_average_and_n( surfRain_2b31[pr_idx2avg], n_non_zero )
         PRcountSfc2b31RainByTMI[this_tmi_idx] = n_non_zero
      ENDIF

      IF havefile2a23 EQ 1 THEN BEGIN
         PRbbHeight[this_tmi_idx] = $
            compute_average_and_n( meanBBrunning[pr_idx2avg], n_non_zero )
         ;if PRbbHeight[this_tmi_idx] GT 0.0 THEN print, itmi, PRbbHeight[this_tmi_idx]
      ENDIF

      ; -- number of PR footprints of rain type Convective
      idxPRconv = WHERE( rainType[pr_idx2avg] EQ 2, counttemp)
      PRcountRainConv[this_tmi_idx] = counttemp

      IF n_pr2avg GT maxPRinRadius THEN maxPRinRadius = n_pr2avg
      npertmiray[raytmi[this_tmi_idx]] = npertmiray[raytmi[this_tmi_idx]] + n_pr2avg
   endfor
ENDELSE

IF (print_times) THEN BEGIN
   print, "Finished averaging.  Elapsed seconds: ", systime(1)-timestart
   print, ''
ENDIF

prunmapped = N_ELEMENTS(tmi_index_nearest_pr)-ntmimapped
IF prunmapped GT 0 THEN print, "#PR footprints unmapped to TMI: ", prunmapped, $
                               " of total: ", N_ELEMENTS(tmi_index_nearest_pr) $
ELSE print, "All ", ntmimapped, " PR footprints mapped to TMI"
print, "TMI footprints matched: ", ntmimatchtrue
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
   print, ''
   IF (print_times) THEN BEGIN
      print, "Beginning TMI footprint corner calculations..."
      timestart=systime(1)
   ENDIF

   ; define arrays for TMI footprint "corners" for image plots
   xCornersTMI = FLTARR(4, maxtmi-mintmi+1, idxmaxpr-idxminpr+1)
   yCornersTMI = FLTARR(4, maxtmi-mintmi+1, idxmaxpr-idxminpr+1)
   
   ; extract or compute extrapolated arrays
   IF mintmi GT 0 AND maxtmi LT (n_tmi_scans-1) AND idxminpr GT 0 $
   AND idxmaxpr LT (NPIXEL_TMI-1) THEN BEGIN
      IF (print_times) THEN print, 'Cut out the "extrapolated" subset arrays '
      tmi_x_ext = tmi_x0[mintmi-1:maxtmi+1, idxminpr-1:idxmaxpr+1]
      tmi_y_ext = tmi_y0[mintmi-1:maxtmi+1, idxminpr-1:idxmaxpr+1]
      ; subset the x and y arrays to our rectangle of overlap
      tmi_x0 = tmi_x0[mintmi:maxtmi, idxminpr:idxmaxpr]
      tmi_y0 = tmi_y0[mintmi:maxtmi, idxminpr:idxmaxpr]
   ENDIF ELSE BEGIN
      IF (print_times) THEN print, 'Extrapolating existing subset arrays '
      ; cut the x and y arrays to the existing rectangle of overlap
      tmi_x0 = tmi_x0[mintmi:maxtmi, idxminpr:idxmaxpr]
      tmi_y0 = tmi_y0[mintmi:maxtmi, idxminpr:idxmaxpr]
      tmi_x_ext = tmi_x0  ; size extrapolated array the same as original, going in
      tmi_y_ext = tmi_y0
      ; compute extrapolated arrays, resizing tmi_x_ext and tmi_y_ext
      extrap_x_y_arrays, tmi_x0, tmi_y0, tmi_x_ext, tmi_y_ext
   ENDELSE

   IF (CheckMapLimits) THEN $
        footprint_corner_x_and_y_by2d, tmi_x_ext, tmi_y_ext, xCornersTMI, $
                                       yCornersTMI, min_xy[0], max_xy[0], $
                                       VERBOSE=print_times                $
   ELSE footprint_corner_x_and_y_by2d, tmi_x_ext, tmi_y_ext, xCornersTMI, $
                                       yCornersTMI, VERBOSE=print_times
   IF (print_times) THEN BEGIN
      print, "Finished TMI footprint corner calculations.  Elapsed seconds: ", systime(1)-timestart
      print, ''
   ENDIF

   ; free up some memory
   tmi_x_ext = 0b
   tmi_y_ext = 0b

   IF do_nc THEN BEGIN
      ; determine the overlap begin/end in terms of TMI scans, already have
      ; first and last TMI rays in overlap region
      ncscans = (maxtmi-mintmi)+1
      ncrays = (idxmaxpr-idxminpr)+1
      ; create a netCDF file to hold the overlapping matchup data
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

      ; write the overlap-subsetted geospatial arrays -- corners already subset
      NCDF_VARPUT, ncid, 'xCorners', xCornersTMI
      NCDF_VARPUT, ncid, 'yCorners', yCornersTMI
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

      NCDF_VARPUT, ncid, 'BBheight', PRbbHeight[mintmi:maxtmi, idxminpr:idxmaxpr]
      NCDF_VARPUT, ncid, 'have_BBheight', dataflags_pr.have_BBheight

      NCDF_VARPUT, ncid, 'numPRinRadius', PRinRadius2TMI[mintmi:maxtmi, idxminpr:idxmaxpr]
      NCDF_VARPUT, ncid, 'numPRsfcRain', PRcountSfcRainByTMI[mintmi:maxtmi, idxminpr:idxmaxpr]
      NCDF_VARPUT, ncid, 'numPRsfcRainCom', PRcountSfc2b31RainByTMI[mintmi:maxtmi, idxminpr:idxmaxpr]
      NCDF_VARPUT, ncid, 'numConvectiveType', PRcountRainConv[mintmi:maxtmi, idxminpr:idxmaxpr]

      NCDF_CLOSE, ncid

      command = 'gzip -v '+ncfile_out
      spawn, command
;      command = 'ls -al '+ncfile_out+'*'
;      spawn, command
   ENDIF   ; (do_nc)

   ; define and populate data structure with the subsetted matchup arrays
   IF TRMM_vers_str EQ '7' THEN BEGIN
   datastruc = {   orbit : orbit, $
                 version : TRMM_vers, $
                  subset : subset, $
                 tmirain : surfaceRain[mintmi:maxtmi, idxminpr:idxmaxpr], $
                  tmipop : PoP[mintmi:maxtmi, idxminpr:idxmaxpr], $
               tmifreeze : freezingHeight[mintmi:maxtmi, idxminpr:idxmaxpr], $
                   numpr : PRinRadius2TMI[mintmi:maxtmi, idxminpr:idxmaxpr], $
                  prrain : PRsfcRainByTMI[mintmi:maxtmi, idxminpr:idxmaxpr], $
                 numprrn : PRcountSfcRainByTMI[mintmi:maxtmi, idxminpr:idxmaxpr], $
                 comrain : PRsfcRain2b31ByTMI[mintmi:maxtmi, idxminpr:idxmaxpr], $
                numcomrn : PRcountSfc2b31RainByTMI[mintmi:maxtmi, idxminpr:idxmaxpr], $
               numprconv : PRcountRainConv[mintmi:maxtmi, idxminpr:idxmaxpr], $
              prbbheight : PRbbHeight[mintmi:maxtmi, idxminpr:idxmaxpr], $
                 min_ray : idxminpr, $
                 max_ray : idxmaxpr, $
                min_scan : mintmi, $
                max_scan : maxtmi, $
              center_lat : centerLat, $
              center_lon : centerLon, $
                xcorners : xCornersTMI, $
                ycorners : yCornersTMI }
   ENDIF ELSE BEGIN
   datastruc = {   orbit : orbit, $
                 version : TRMM_vers, $
                  subset : subset, $
                 tmirain : surfaceRain[mintmi:maxtmi, idxminpr:idxmaxpr], $
               tmifreeze : freezingHeight, $   ; can't subset, no V6 data field
                  tmipop : PoP, $              ; ditto 
                   numpr : PRinRadius2TMI[mintmi:maxtmi, idxminpr:idxmaxpr], $
                  prrain : PRsfcRainByTMI[mintmi:maxtmi, idxminpr:idxmaxpr], $
                 numprrn : PRcountSfcRainByTMI[mintmi:maxtmi, idxminpr:idxmaxpr], $
                 comrain : PRsfcRain2b31ByTMI[mintmi:maxtmi, idxminpr:idxmaxpr], $
                numcomrn : PRcountSfc2b31RainByTMI[mintmi:maxtmi, idxminpr:idxmaxpr], $
               numprconv : PRcountRainConv[mintmi:maxtmi, idxminpr:idxmaxpr], $
              prbbheight : PRbbHeight[mintmi:maxtmi, idxminpr:idxmaxpr], $
                 min_ray : idxminpr, $
                 max_ray : idxmaxpr, $
                min_scan : mintmi, $
                max_scan : maxtmi, $
              center_lat : centerLat, $
              center_lon : centerLon, $
                xcorners : xCornersTMI, $
                ycorners : yCornersTMI }
   ENDELSE
ENDIF ELSE BEGIN
   ;mintmi = -1
   ;maxtmi = -1
   datastruc = -1
   print, ''
   print, "****************************************"
   print, "* No TMI footprints are matched by PR! *"
   print, "****************************************"
   print, ''
ENDELSE

skipover:

; return the structure (or -1) to the caller
return, datastruc
end
