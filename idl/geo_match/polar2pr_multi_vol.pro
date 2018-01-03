;===============================================================================
;+
; Copyright © 2008, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; polar2pr_multi_vol.pro          Morris/SAIC/GPM_GV      September 2010
;
; DESCRIPTION
; -----------
; Performs a resampling of PR and GV data to common 3-D volumes, as defined in
; the horizontal by the location of PR rays, and in the vertical by the heights
; of the intersection of the PR rays with the top and bottom edges of individual
; elevation sweeps of a ground radar scanning in PPI mode.  The data domain is
; determined by the location of the ground radars overpassed by the PR swath,
; and by the cutoff range (range_threshold_km) which is a mandatory parameter
; for this procedure.  The PR and GV (ground radar) files to be processed are
; specified in the control_file, which is a mandatory parameter containing the
; fully-qualified file name of the control file to be used in the run.  Optional
; parameters (PR_ROOT and DIRxx) allow for non-default local paths to the PR and
; GV files whose partial pathnames are listed in the control file.  The defaults
; for these paths are as specified in the environs.inc file.  All file path
; optional parameter values must begin with a leading slash (e.g., '/mydata')
; and be enclosed in quotes, as shown.  Optional binary keyword parameters
; control immediate output of PR-GV reflectivity differences (/SCORES), plotting
; of the matched PR and GV reflectivity fields sweep-by-sweep in the form of
; PPIs on a map background (/PLOT_PPIS), and plotting of the matching PR and GV
; bin horizontal outlines (/PLOT_BINS) for the common 3-D volume.
;
; The control file is of a specific layout and contains specific fields in a
; fixed order and format.  See the script "doGeoMatch4SelectCases.sh", which
; creates the control file and invokes IDL to run this procedure.  Completed
; PR and GV matchup data for an individual site overpass event (i.e., a given
; TRMM orbit and ground radar site) are written to a netCDF file.  The size of
; the dimensions in the data fields in the netCDF file vary from one case to
; another, depending on the number of elevation sweeps in the GV radar volume
; scan and the number of PR footprints within the cutoff range from the GV site.
;
; The optional parameter NC_FILE specifies the directory to which the output
; netCDF files will be written.  It is created if it does not yet exist.  Its
; default value is derived from the variables NCGRIDS_ROOT+GEO_MATCH_NCDIR as
; specified in the environs.inc file.
;
; An optional parameter (NC_NAME_ADD) specifies a component to be added to the
; output netCDF file name, to specify uniqueness in the case where more than
; one version of input data are used, a different range threshold is used, etc.
;
; NOTE: THE SET OF CODE CONTAINED IN THIS FILE IS NOT THE COMPLETE POLAR2PR
;       PROCEDURE.  THE REMAINING CODE IN THE FULL PROCEDURE IS CONTAINED IN
;       THE FILE "polar2pr_resampling.pro", WHICH IS INCORPORATED INTO THIS
;       FILE/PROCEDURE BY THE IDL "include" MECHANISM.
;
;
; MODULES
; -------
;   1) FUNCTION  plot_bins_bailout
;   2) PROCEDURE polar2pr
;
;
; EXTERNAL LIBRARIES
; ------------------
; Selected IDL procedures and functions of the RSL_IN_IDL library, Version 1.3.9
; or later, are required to compile and run this procedure.  This library may be
; obtained from the TRMM GV web site at http://trmm-fc.gsfc.nasa.gov/index.html
;
;
; CONSTRAINTS
; -----------
; PR: 1) Only PR Version 6, or other PR versions with HDF files in PR Version 6's
;        format, are supported by this code.
; GV: 1) Only radar data files in Universal Format (UF) are supported by this
;        code, although radar files in other formats supported by the TRMM Radar
;        Software Library (RSL) may work, depending on constraint 2, below.
;     2) UF files for sites not 'known' to this code must label their quality-
;        controlled reflectivity data field name as 'CZ'.  This constraint is
;        implemented in the function common_utils/get_site_specific_z_volume.pro
;
;
; HISTORY
; -------
; 9/2008 by Bob Morris, GPM GV (SAIC)
;  - Created.
; 10/2008 by Bob Morris, GPM GV (SAIC)
;  - Implemented selective PR footprint LUT/averages generation
; 10/17/2008 by Bob Morris, GPM GV (SAIC)
;  - Added call to new function UNIQ_SWEEPS to improve removal of duplicate
;    sweeps at (nominally) the same elevation
; 10/20/2008 by Bob Morris, GPM GV (SAIC)
;  - Added spawned command to gzip the output netCDF file after writing
;  - Changed the PR dBZ threshold (PR_DBZ_MIN) from 15.0 to 18.0
; 1/6/2009 by Bob Morris, GPM GV (SAIC)
;  - Added optional parameter NC_NAME_ADD to be added to the output netCDF
;    file name generated within this procedure, to allow more than one version
;    of matchup data to exist without conflicting filenames.  Needed this for
;    KWAJ data processing, where a second set of GV data was provided.
; 2/6/2009 by Bob Morris, GPM GV (SAIC)
;  - Small in-line documentation enhancements
; 6/15/2009 by Bob Morris, GPM GV (SAIC)
;  - Added NC_DIR parameter to the optional keywords, to specify the output
;    file path for the netCDF files.  Generates a fully-qualified netCDF file
;    name using this path, for the call to gen_geo_match_netcdf_multi() function.
;  - Use value in environs.inc for dafault common path to UF files, and put a
;    '/' after this path when used to build the UF file pathname.  All rel/abs
;    file path parameters are now consistent in requiring a leading '/'
; 6/16/2010 by Bob Morris, GPM GV (SAIC)
;  - Added MARK_EDGES parameter to make addition of 'bogus' footprints optional.
;  - Streamlined call to map_proj_forward() to eliminate FOR looping.
; 8/19/2010 by Bob Morris, GPM GV (SAIC)
;  - Added PRINT statements to output the netCDF file name, and added verbose
;    switch to gzip command that follows closing of netCDF output file.
;  - Added WDELETE commands to close PPI windows following netCDF file closure,
;    in the case where PLOT_PPIS keyword option is set.
;  - Moved FUNCTION plot_bins_bailout() to the beginning of the source file to
;    alleviate any compile/run ordering issues.
; 9/3/2010 by Bob Morris, GPM GV (SAIC)
;  - Created from polar2pr.pro.  Modified to process multiple GR volume
;    scans for a single radar site, and save to a single netCDF file for the
;    specific orbit/site combo.
; 9/10/2010 by Bob Morris, GPM GV (SAIC)
;  - Dealt with 'siteElev' parameter in ground radar lines in control file so
;    that it can be used in code inside polar2pr_resampling_multi.
;  - Output siteElev value to new netCDF file variable "site_elev".
; 11/4/2010 by Bob Morris, GPM GV (SAIC)
;  - Only write PR matchups for GR volume
;
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;===============================================================================

FUNCTION plot_bins_bailout
   PRINT, ""
   PRINT, "PLOT_BINS is activated, this is EXTREMELY slow."
   prompt2do = "Disable PLOT_BINS? (enter Y or N): "
   choicenum = 1
   tryagain:
   reply = 'x'
   WHILE (reply NE 'Y' AND reply NE 'N') DO BEGIN
      READ, reply, PROMPT=prompt2do
      IF (reply EQ 'Y' OR reply EQ 'y') THEN reply='Y'
      IF (reply EQ 'N' OR reply EQ 'n') THEN reply='N'
   ENDWHILE
   IF reply EQ 'Y' THEN BEGIN
      PRINT, "PLOT_BINS option disabled.  Good choice."
   ENDIF ELSE BEGIN
      IF choicenum EQ 1 THEN BEGIN
         choicenum = 2
         prompt2do = "Really?  PLOT_BINS is active.  Disable it now? (Y/N):"
         goto, tryagain
      ENDIF
      PRINT, "PLOT_BINS is active.  Good Luck!"
   ENDELSE
   PRINT, ""
   return, reply
END

;*******************************************************************************

FUNCTION dtime_fields_from_UF_filename, filename, DTIMESTR=ufdtimestr, $
                                        TICKS=ufdtimeticks

   IF N_PARAMS() NE 1 THEN BEGIN
      PRINT, "Expected one parameter in dtime_fields_from_UF_filename(), got ", N_PARAMS()
      return, "Error"
   ENDIF

   parsed = STRSPLIT( filename, '.', COUNT=nparsed, /EXTRACT)
   IF nparsed LT 6  THEN BEGIN
      PRINT, "Expected at least 6 filename parts in dtime_fields_from_UF_filename(), got ", nparsed
      PRINT, "Filename provided: ", filename
      return, "Error"
   ENDIF

   yymmdd = parsed[0]
   hhmm = parsed[4]
   numtest1 = DOUBLE(yymmdd)
   IF numtest1 EQ 0d THEN BEGIN
      PRINT, "Illegal YYMMDD in first subfield of file name: ", filename
      return, "Error"
   ENDIF
   numtest2 = DOUBLE(hhmm)
   IF (numtest2 EQ 0d AND hhmm NE '0000') OR numtest2 GE 2400d THEN BEGIN
      PRINT, "Illegal HHMM in fifth subfield of file name: ", filename
      return, "Error"
   ENDIF

   century = '20'
   IF numtest1 GT 900000d THEN century = '19'

   IF N_ELEMENTS(ufdtimestr) EQ 1 THEN BEGIN
     ufdtimestr=century+STRMID(yymmdd,0,2)+'-'+STRMID(yymmdd,2,2)+'-' $
         +STRMID(yymmdd,4,2)+' '+STRMID(hhmm,0,2)+':'+STRMID(hhmm,2,2)+':00+00'
   ENDIF

   IF N_ELEMENTS(ufdtimeticks) EQ 1 THEN BEGIN
     year=FIX(century+STRMID(yymmdd,0,2))
     month=FIX(STRMID(yymmdd,2,2))
     day=FIX(STRMID(yymmdd,4,2))
     hour=FIX(STRMID(hhmm,0,2))
     mins=FIX(STRMID(hhmm,2,2))
     secs=0
     ufdtimeticks = unixtime( year, month, day, hour, mins, secs )
   ENDIF

return, yymmdd+"_"+hhmm
END

;*******************************************************************************

PRO polar2pr_multi_vol, $
              control_file, range_threshold_km, PR_ROOT=prroot, DIR1C=dir1c, $
              DIR2A=dir2a, DIR2B=dir2b, DIRGV=dirgv, SCORES=run_scores, $
              PLOT_PPIS=plot_PPIs, PLOT_BINS=plot_bins, NC_DIR=nc_dir, $
              NC_NAME_ADD=ncnameadd, MARK_EDGES=mark_edges

COMMON sample, start_sample, sample_range, num_range, RAYSPERSCAN

; "Include" file for PR-product-specific parameters (i.e., RAYSPERSCAN):
@pr_params.inc
; "Include" file for names, paths, etc.:
@environs.inc

IF KEYWORD_SET(plot_bins) THEN BEGIN
   reply = plot_bins_bailout()
   IF reply EQ 'Y' THEN plot_bins = 0
ENDIF

IF N_ELEMENTS( mark_edges ) EQ 1 THEN BEGIN
   IF mark_edges NE 0 THEN mark_edges=1
ENDIF ELSE mark_edges = 0


; ***************************** Local configuration ****************************
   ; where provided, override file path default values from environs.inc:
    in_base_dir =  GVDATA_ROOT ; default root dir for UF files
    IF N_ELEMENTS(dirgv)  EQ 1 THEN in_base_dir = dirgv

    IF N_ELEMENTS(prroot) EQ 1 THEN PRDATA_ROOT = prroot
    IF N_ELEMENTS(dir1c)  EQ 1 THEN DIR_1C21 = dir1c
    IF N_ELEMENTS(dir2a)  EQ 1 THEN DIR_2A25 = dir2a
    IF N_ELEMENTS(dir2b)  EQ 1 THEN DIR_2B31 = dir2b
    
    IF N_ELEMENTS(nc_dir)  EQ 1 THEN BEGIN
       NCGRIDSOUTDIR = nc_dir
    ENDIF ELSE BEGIN
       NCGRIDSOUTDIR = NCGRIDS_ROOT+GEO_MATCH_NCDIR
    ENDELSE
; ******************************************************************************

; Take a walk through the UF files in the control file to see which orbits
; meet the criterion that all the GR volumes associated to the event have the
; same set of sweep elevation angles.

orbits2do=lonarr(10)  ; assumes no more than 10 rainy orbits in a day
nswps_by_orbit=intarr(10)
ngoodorbits = CHECK_VOS_ELEV_ANGLES( control_file, in_base_dir, orbits2do, $
                                     nswps_by_orbit )
IF ( ngoodorbits EQ 0 ) THEN BEGIN
   PRINT, "No orbits where all GR volumes have identical sweep angles, quitting."
   goto, noCases
ENDIF

; set to a constant, until database supports PR product versions
PR_version = 6

; Values for "have_somegridfield" flags:

DATA_PRESENT = 0
NO_DATA_PRESENT = 1  ; default fill value, defined in gen_geo_match_netcdf_multi.pro

; will skip processing PR points beyond this distance from a ground radar
rough_threshold = range_threshold_km * 1.1

; flag PR averages that include any reflectivity bins below this dBZ value
PR_DBZ_MIN = 18.0

; flag GV averages that include any reflectivity bins below this dBZ value
dBZ_min = 15.0   ; low-end GV cutoff, for now

; flag PR averages that include bins with rain rates (mm/h) below this value
PR_RAIN_MIN = 0.01

; precompute the reuseable ray angle trig variables for parallax:
cos_inc_angle = DBLARR(RAYSPERSCAN)
tan_inc_angle = DBLARR(RAYSPERSCAN)
cos_and_tan_of_pr_angle, cos_inc_angle, tan_inc_angle

; initialize the variables into which file records are read as strings
dataPR = ''
dataGV = ''

; open and process control file, and generate the matchup data for the events

OPENR, lun0, control_file, ERROR=err, /GET_LUN
WHILE NOT (EOF(lun0)) DO BEGIN 

  ; get PR filenames and count of GV file pathnames to do for an orbit
  ; - read the '|'-delimited input file record into a single string:
   READF, lun0, dataPR

  ; parse dataPR into its component fields: 1C21 file name, 2A25 file name,
  ; 2B31 file name, orbit number, number of sites, YYMMDD, and PR subset
   parsed=STRSPLIT( dataPR, '|', /extract )
   origFile21Name = parsed[0] ; filename as listed in/on the database/disk
   origFile25Name = parsed[1] ; filename as listed in/on the database/disk
   origFile31Name = parsed[2] ; filename as listed in/on the database/disk
   orbit = LONG( parsed[3] )
   nvols = FIX( parsed[4] )
   DATESTAMP = parsed[5]      ; in YYMMDD format
   subset = parsed[6]

  ; Decide whether or not to process this orbit's data based on volume scan
  ; angles being constant for each associated VOS
   skiporbit = 0
   idxorbitok = WHERE( orbits2do EQ orbit, norbsok )

   IF norbsok NE 1 THEN BEGIN
      PRINT, "Volume scan angles vary for VOSs in orbit ", orbit, ", skipping."
      skiporbit = 1
   ENDIF ELSE BEGIN
     ; add the well-known (or local) paths to get the fully-qualified file names
      file_1c21 = PRDATA_ROOT+DIR_1C21+"/"+origFile21Name
      file_2a25 = PRDATA_ROOT+DIR_2A25+"/"+origFile25Name
      file_2b31 = PRDATA_ROOT+DIR_2B31+"/"+origFile31Name

    ; initialize PR variables/arrays and read 1C21 fields
      SAMPLE_RANGE=0
      START_SAMPLE=0
      num_range = NUM_RANGE_1C21
      dbz_1c21=FLTARR(sample_range>1,1,num_range)
      landOceanFlag=INTARR(sample_range>1,RAYSPERSCAN)
      binS=INTARR(sample_range>1,RAYSPERSCAN)
      rayStart=INTARR(RAYSPERSCAN)
      status = read_pr_1c21_fields( file_1c21, DBZ=dbz_1c21,       $
                                    OCEANFLAG=landOceanFlag,       $
                                    BinS=binS, RAY_START=rayStart )
      IF ( status NE 0 ) THEN BEGIN
         PRINT, ""
         PRINT, "ERROR reading fields from ", file_1c21
         PRINT, "Skipping events for orbit = ", orbit
         PRINT, ""
         skiporbit = 1
         GOTO, siteLoop
      ENDIF

     ; initialize PR variables/arrays and read 2A25 fields
      SAMPLE_RANGE=0
      START_SAMPLE=0
      num_range = NUM_RANGE_2A25
      dbz_2a25=FLTARR(sample_range>1,1,num_range)
      rain_2a25 = FLTARR(sample_range>1,1,num_range)
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
         skiporbit = 1
         GOTO, siteLoop
      ENDIF

     ; split GEOL data fields into prlats and prlons arrays
      prlons = FLTARR(RAYSPERSCAN,sample_range>1)
      prlats = FLTARR(RAYSPERSCAN,sample_range>1)
      prlons[*,*] = geolocation[1,*,*]
      prlats[*,*] = geolocation[0,*,*]

; NOTE THAT THE GEOLOCATION ARRAYS ARE IN (RAY,SCAN) COORDINATES, WHILE ALL THE
; OTHER ARRAYS ARE IN (SCAN,RAY) COORDINATE ORDER.  NEED TO ACCOUNT FOR THIS
; WHEN USING "pr_master_idx" ARRAY INDICES.

     ; Extract the 2-D range bin number of the bright band level from the 3-D array
     ;   and initialize a matching bright band height array
      BB_Bins = rangeBinNums[*,*,3]
      BB_hgt = FLOAT(BB_Bins)
      BB_hgt[*,*] = BBHGT_UNDEFINED
   
;*******************************************************************************
;*******************************************************************************
; NEED TO GET A 'COMMON' SET OF SCANS BETWEEN ALL PR PRODUCTS READ/USED?  THEY
; MAY NOT BE ABLE TO SHARE THE 2A25 GEOLOCATION, AS ASSUMED BY THIS ALGORITHM.
;*******************************************************************************
;*******************************************************************************

   ; read 2B31 rainrate field
   ; The following test allows PR processing to proceed without the
   ; 2B-31 data file being available.

      havefile2b31 = 1
      IF ( origFile31Name EQ 'no_2B31_file' ) THEN BEGIN
         PRINT, ""
         PRINT, "No 2B31 file, skipping 2B31 processing for orbit = ", orbit
         PRINT, ""
         havefile2b31 = 0
      ENDIF ELSE BEGIN
         surfRain_2b31=FLTARR(sample_range>1,RAYSPERSCAN)
         status = read_pr_2b31_fields( file_2b31, surfRain_2b31)
         IF ( status NE 0 ) THEN BEGIN
            PRINT, ""
            PRINT, "ERROR reading fields from ", file_2a25
            PRINT, "Skipping 2B31 processing for orbit = ", orbit
            PRINT, ""
            havefile2b31 = 0
         ENDIF
      ENDELSE

   ENDELSE  ; IF norbsok NE 1

siteLoop:

writePR = 'no'

FOR igv=0,nvols-1  DO BEGIN
  ; read and parse the control file GV site ID, lat, lon, elev, filename, etc.
  ;  - read each overpassed site's information as a '|'-delimited string
   READF, lun0, dataGV

  ; check whether this is a step-through or a good orbit to process
   IF ( skiporbit EQ 1 ) THEN GOTO, nextGVfile

  ; parse dataGV into its component fields: event_num, orbit number, siteID,
  ; overpass datetime, time in ticks, site lat, site lon, site elev,
  ; 1CUF file unique pathname

   nparsed = 0
   parsed=STRSPLIT( dataGV, '|', COUNT=nparsed, /extract )
   IF nparsed NE 9 THEN MESSAGE, "Incorrect number of fields in GV control file string."
   event_num = LONG( parsed[0] )
   orbit = parsed[1]
   siteID = parsed[2]    ; GPMGV siteID
   pr_dtime = parsed[3]
   pr_dtime_ticks = DOUBLE( parsed[4] )
   siteLat = FLOAT( parsed[5] )
   siteLon = FLOAT( parsed[6] )
   siteElev = FLOAT( parsed[7] )
  ; assume that if siteElev value is 4.0 or more, its units are m - km needed
   IF (siteElev GE 4.0) THEN siteElev=siteElev/1000.
  ; don't allow below-sea-level siteElev to be below -400 m (-0.4 km) (Dead Sea)
   IF (siteElev LT -0.4) THEN siteElev=( (siteElev/1000.) > (-0.4) )
   origUFName = parsed[8]  ; filename as listed in/on the database/disk
  ; adding the well-known (or local) path to get the fully-qualified file name:
   base_1CUF = file_basename(origUFName)
   IF ( base_1CUF eq 'no_1CUF_file' ) THEN BEGIN
      PRINT, "No 1CUF file for event = ", event_num, ", site = ", $
              siteID, ", skipping."
      GOTO, nextGVfile
   ENDIF
   file_1CUF = in_base_dir + "/" + base_1CUF
   IF igv EQ 0 THEN firstsite = siteID
   IF ( siteID NE firstsite ) THEN BEGIN
      PRINT, "Site changed in control file, first site was ", firstsite, $
             ", current site is ", siteID, ", skipping."
      GOTO, nextGVfile
   ENDIF

  ; get the volume scan time from the UF file name as a "YYMMDD_hhmm" string,
  ; as a postgreSQL DATETIME string (YYYY-MM-DD hh:mm:ss+00), and in unix ticks
   ufdtimestr = ""    ; the postgreSQL string
   ufdtimeticks = 0D  ; in ticks
   ufdtimeID = dtime_fields_from_UF_filename( base_1CUF, DTIMESTR=ufdtimestr, $
                                              TICKS=ufdtimeticks )

   PRINT, ""
   PRINT, '----------------------------------------------------------------'
   PRINT, ""
   PRINT, igv+1, ": ", event_num, "  ", siteID, siteLat, siteLon

  ; copy/unzip/open the UF file and read the entire volume scan into an
  ;   RSL_in_IDL radar structure, and then close UF file and delete copy:

   status=get_rsl_radar(file_1CUF, radar)
   IF ( status NE 0 )  THEN BEGIN
      PRINT, ""
      PRINT, "Error reading radar structure from file ", file_1CUF
      PRINT, ""
      GOTO, nextGVfile
   ENDIF

  ; find the volume with the correct reflectivity field for the GV site/source,
  ;   and the ID of the field itself
   gv_z_field = ''
   z_vol_num = get_site_specific_z_volume( siteID, radar, gv_z_field )
   IF ( z_vol_num LT 0 )  THEN BEGIN
      PRINT, ""
      PRINT, "Error finding volume in radar structure from file ", file_1CUF
      PRINT, ""
      GOTO, nextGVfile
   ENDIF

  ; get the number of elevation sweeps in the vol, and the array of elev angles
   num_elevations = get_sweep_elevs( z_vol_num, radar, elev_angle )
  ; make a copy of the array of elevations, from which we eliminate any
  ;   duplicate tilt angles for subsequent data processing/output
;   idx_uniq_elevs = UNIQ(elev_angle)
   uniq_elev_angle = elev_angle
   idx_uniq_elevs = UNIQ_SWEEPS(elev_angle, uniq_elev_angle)

   tocdf_elev_angle = elev_angle[idx_uniq_elevs]
   num_elevations_out = N_ELEMENTS(tocdf_elev_angle)
   IF num_elevations NE num_elevations_out THEN BEGIN
      print, ""
      print, "Duplicate sweep elevations ignored!"
      print, "Original sweep elevations:"
      print, elev_angle
      print, "Unique sweep elevations to be processed/output"
      print, tocdf_elev_angle
   ENDIF

  ; Get the times of the first ray in each sweep -- text_times are formatted
  ;   as YYYY-MM-DD hh:mm:ss, e.g., '2008-07-09 00:10:56'
   num_times = get_sweep_times( z_vol_num, radar, dtimestruc )
   text_sweep_times_1vol = dtimestruc.textdtime  ; STRING array, human-readable
   ticks_sweep_times_1vol = dtimestruc.ticks     ; DOUBLE array, time in unix ticks
   IF num_elevations NE num_elevations_out THEN BEGIN
      ticks_sweep_times_1vol = ticks_sweep_times_1vol[idx_uniq_elevs]
      text_sweep_times_1vol =  text_sweep_times_1vol[idx_uniq_elevs]
   ENDIF
  ; initialize/append this volume's times to the netCDF output array
   IF igv EQ 0 THEN BEGIN $
      ticks_sweep_times = ticks_sweep_times_1vol
      text_sweep_times =  text_sweep_times_1vol
   ENDIF ELSE BEGIN
      ticks_sweep_times = [ticks_sweep_times, ticks_sweep_times_1vol]
      text_sweep_times =  [text_sweep_times, text_sweep_times_1vol]
   ENDELSE

; DETERMINE WHETHER THIS IS THE TIME-MATCHED VOS FOR THE PR OVERPASS, AND IF SO,
; SET UP WRITING THE PR VOLUME-MATCH VARIABLES FOR THIS VOS ONLY TO THE NETCDF
; PR ARRAY VARIABLES.  OTHERWISE, WE MISS A LOT OF PR DATA POINTS DUE TO THE
; MISMATCH OF PR AND GR ECHO LOCATIONS IN THE LUT GENERATION WHEN THE LAST VOS
; MATCHUP IS THE DATA THAT GETS OUTPUT.  SELECT THE FIRST VOS WHOSE START TIME
; IS WITHIN +/- 4 1/2 MINUTES (+/-270 SECS) OF THE PR OVERPASS TIME.

   IF ( writePR EQ 'no' AND ABS(ticks_sweep_times_1vol[0]-pr_dtime_ticks) LE 270.0D ) THEN BEGIN
      writePR = 'yes'
      PRINT, "**********************"
      PRINT, "Output PR matchup variables where PR time = ", pr_dtime, $
             " and GR time = ", text_sweep_times_1vol[0]
      PRINT, "**********************"
   ENDIF

; STUFF TO DO ONLY FOR THE FIRST VOS IN THE ORBIT STARTS HERE

   IF ( igv EQ 0 ) THEN BEGIN

  ; initialize a gv-centered map projection for the ll<->xy transformations:
   sMap = MAP_PROJ_INIT( 'Azimuthal Equidistant', center_latitude=siteLat, $
                         center_longitude=siteLon )
  ; PR-site latitude and longitude differences for coarse filter
   max_deg_lat = rough_threshold / 111.1
   max_deg_lon = rough_threshold / (cos(!DTOR*siteLat) * 111.1 )

  ; precompute cos(elev) for later repeated use
   cos_elev_angle = COS( tocdf_elev_angle * !DTOR )

  ; Determine an upper limit to how many PR footprints fall inside the analysis
  ;   area, so that we can hold x, y, and various z values for each element to
  ;   analyze.  We gave the PR a 4km resolution in the 'include' file
  ;   pr_params.inc, and use this nominal resolution to figure out how many
  ;   of these are required to cover the in-range area.

   grid_area_km = rough_threshold * rough_threshold  ; could use area of circle
   max_pr_fp = grid_area_km / NOM_PR_RES_KM

  ; Create temp array of PR (ray, scan) 1-D index locators for in-range points.
  ;   Use flag values of -1 for 'bogus' PR points (out-of-range PR footprints
  ;   just adjacent to the first/last in-range point of the scan), or -2 for
  ;   off-PR-scan-edge but still-in-range points.  These bogus points will then
  ;   totally enclose the set of in-range, in-scan points and allow gridding of
  ;   the in-range dataset to a regular grid using a nearest-neighbor analysis,
  ;   assuring that the bounds of the in-range data are preserved (this gridding
  ;   in not needed or done within the current analysis).
   pr_master_idx = LONARR(max_pr_fp)
   pr_master_idx[*] = -99L

  ; Create temp array to indicate whether there are ANY above-threshold PR bins
  ; in the ray.  If none, we'll skip the time-consuming GV LUT computations.
   pr_echoes = BYTARR(max_pr_fp)
   pr_echoes[*] = 0B             ; initialize to zero (skip point)

  ; Create temp arrays to hold lat/lon of all PR footprints to be analyzed,
  ;   including those extrapolated to mark the edge of the scan
   pr_lon_sfc = FLTARR(max_pr_fp)
   pr_lat_sfc = pr_lon_sfc

  ; create temp subarrays with additional dimension num_elevations_out to hold
  ;   parallax-adjusted PR point X,Y and lon/lat coordinates, and PR corner X,Ys
   pr_x_center = FLTARR(max_pr_fp, num_elevations_out)
   pr_y_center = pr_x_center
   pr_x_corners = FLTARR(4, max_pr_fp, num_elevations_out)
   pr_y_corners = pr_x_corners
  ; holds lon/lat array returned by MAP_PROJ_INVERSE()
   pr_lon_lat = DBLARR(2, max_pr_fp, num_elevations_out)

  ; restrict max range at each elevation to where beam center is 19.5 km or less
   max_ranges = FLTARR( num_elevations_out )
   FOR i = 0, num_elevations_out - 1 DO BEGIN
      rsl_get_slantr_and_h, range_threshold_km, tocdf_elev_angle[i], $
                            slant_range, max_ht_at_range
      IF ( max_ht_at_range LT 19.5 ) THEN BEGIN
         max_ranges[i] = range_threshold_km
      ENDIF ELSE BEGIN
         max_ranges[i] = get_range_km_at_beam_hgt_km(tocdf_elev_angle[i], 19.5)
      ENDELSE
   ENDFOR

  ; ======================================================================================================

  ; GEO-Preprocess the PR data, extracting rays that intersect this radar volume
  ; within the specified range threshold, and computing footprint x,y corner
  ; coordinates and adjusted center lat/lon at each of the intersection sweep
  ; intersection heights, taking into account the parallax of the PR rays.
  ; Surround the PR footprints within the range threshold with a border of
  ; "bogus" tagged PR points to facilitate any future gridding of the data.
  ; Algorithm assumes that PR footprints are contiguous, non-overlapping,
  ; and quasi-rectangular in their native ray,scan coordinates, and that the PR
  ; middle ray of the scan is nadir-pointing (zero roll/pitch of satellite).

  ; First, find scans with any point within range of the radar volume, roughly
   start_scan = 0 & end_scan = 0 & nscans2do = 0
   start_found = 0
   FOR scan_num = 0,SAMPLE_RANGE-1  DO BEGIN
      found_one = 0
      FOR ray_num = 0,RAYSPERSCAN-1  DO BEGIN
         ; Compute distance between GV radar and PR sample lats/lons using
         ;   crude, fast algorithm
         IF ( ABS(prlons[ray_num,scan_num]-siteLon) LT max_deg_lon ) AND $
            ( ABS(prlats[ray_num,scan_num]-siteLat) LT max_deg_lat ) THEN BEGIN
            found_one = 1
            IF (start_found EQ 0) THEN BEGIN
               start_found = 1
               start_scan = scan_num
            ENDIF
            end_scan = scan_num        ; tag as last scan within range
            nscans2do = nscans2do + 1
            BREAK                      ; skip the rest of the rays for this scan
         ENDIF
      ENDFOR
      IF ( start_found EQ 1 AND found_one EQ 0 ) THEN BREAK   ; no more in range
   ENDFOR

   IF ( nscans2do EQ 0 ) THEN GOTO, nextGVfile

;-------------------------------------------------------------------------------
  ; Populate arrays holding 'exact' PR at-surface X and Y and range values for
  ; the in-range subset of scans.  THESE ARE NOT WRITTEN TO NETCDF FILE - YET.
   subset_scan_num = 0
   XY_km = map_proj_forward( prlons[*,start_scan:end_scan], $
                             prlats[*,start_scan:end_scan], $
                             map_structure=smap ) / 1000.
   pr_x0 = XY_km[0,*]
   pr_y0 = XY_km[1,*]
   pr_x0 = REFORM( pr_x0, RAYSPERSCAN, nscans2do, /OVERWRITE )
   pr_y0 = REFORM( pr_y0, RAYSPERSCAN, nscans2do, /OVERWRITE )
   precise_range = SQRT( pr_x0^2 + pr_y0^2 )
 
   numPRrays = 0      ; number of in-range, scan-edge, and range-adjacent points
   numPRinrange = 0   ; number of in-range-only points found
  ; Variables used to find 'farthest from nadir' in-range PR footprint:
   maxrayidx = 0 & minrayidx = RAYSPERSCAN-1

;-------------------------------------------------------------------------------
  ; Identify actual PR points within range of the radar, actual PR points just
  ; off the edge of the range cutoff, and extrapolated PR points along the edge
  ; of the scans but within range of the radar.  Tag each point as to these 3
  ; types, and compute parallax-corrected x,y and lat/lon coordinates for these
  ; points at PR ray's intersection of each sweep elevation.  Compute PR
  ; footprint corner x,y's for the first type of points (actual PR points
  ; within the cutoff range).

  ; flag for adding 'bogus' point if in-range at edge of scan PR (2), or just
  ;   beyond max_ranges[elev] (-1), or just a regular, in-range point (1):
   action2do = 0  ; default -- do nothing

   FOR scan_num = start_scan,end_scan  DO BEGIN
      subset_scan_num = scan_num - start_scan
     ; prep variables for parallax computations
      m = 0.0        ; SLOPE AS DX/DY
      dy_sign = 0.0  ; SENSE IN WHICH Y CHANGES WITH INCR. SCAN ANGLE, = -1 OR +1
      get_scan_slope_and_sense, smap, prlats, prlons, scan_num, RAYSPERSCAN, $
                                m, dy_sign

      FOR ray_num = 0,RAYSPERSCAN-1  DO BEGIN
        ; Set flag value according to where the PR footprint lies w.r.t. the GV radar.
         action2do = 0  ; default -- do nothing

        ; is to-sfc projection of any point along PR ray is within range of GV volume?
         IF ( precise_range[ray_num,subset_scan_num] LE max_ranges[0] ) THEN BEGIN
           ; add point to subarrays for PR 2D index and for footprint lat/lon
           ; - MAKE THE INDEX IN TERMS OF THE (SCAN,RAY) COORDINATE ARRAYS
            pr_master_idx[numPRrays] = LONG(ray_num) * LONG(SAMPLE_RANGE) + LONG(scan_num)
            pr_lat_sfc[numPRrays] = prlats[ray_num,scan_num]
            pr_lon_sfc[numPRrays] = prlons[ray_num,scan_num]

            action2do = 1                      ; set up to process this in-range point
            maxrayidx = ray_num > maxrayidx    ; track highest ray num occurring in GV area
            minrayidx = ray_num < minrayidx    ; track lowest ray num in GV area
            numPRinrange = numPRinrange + 1    ; increment # of actual in-range footprints

	   ; determine whether the PR ray has any bins above the dBZ threshold
	   ; - look at 2A-25 corrected Z between 0.75 and 19.25 km
	    top1C21gate = 0 & botm1C21gate = 0
            top2A25gate = 0 & botm2A25gate = 0
            gate_num_for_height, 19.25, GATE_SPACE, cos_inc_angle,  $
                      ray_num, scan_num, binS, rayStart,            $
                      GATE1C21=top1C21gate, GATE2A25=top2A25gate
            gate_num_for_height, 0.75, GATE_SPACE, cos_inc_angle,   $
                      ray_num, scan_num, binS, rayStart,            $
                      GATE1C21=botm1C21gate, GATE2A25=botm2A25gate
           ; use the above-threshold bin counting in get_pr_layer_average()
            dbz_ray_avg = get_pr_layer_average(top2A25gate, botm2A25gate,   $
                                 scan_num, ray_num, dbz_2a25, DBZSCALE2A25, $
                                 PR_DBZ_MIN, numPRgates )
            IF ( numPRgates GT 0 ) THEN pr_echoes[numPRrays] = 1B

	   ; while we are here, compute bright band height for the ray
            IF ( BB_Bins[scan_num,ray_num] LE 79 ) THEN BEGIN
               BB_hgt[scan_num,ray_num] = $
                (79-BB_Bins[scan_num,ray_num]) * GATE_SPACE * cos_inc_angle[ray_num]
            ENDIF ELSE BEGIN
               BB_hgt[scan_num,ray_num] = BB_MISSING
            ENDELSE

           ; If PR scan edge point, then set flag to add bogus PR data point to
           ;   subarrays for each PR spatial field, with PR index flagged as
           ;   "off-scan-edge", and compute the extrapolated location parameters
            IF ( (ray_num EQ 0 OR ray_num EQ RAYSPERSCAN-1) AND mark_edges EQ 1 ) THEN BEGIN
              ; set flag and find the x,y offsets to extrapolated off-edge point
               action2do = 2                   ; set up to also process bogus off-edge point
              ; extrapolate X and Y to the bogus, off-scan-edge point
               if ( ray_num LT RAYSPERSCAN/2 ) then begin 
                  ; offsets extrapolate X and Y to where (angle = angle-1) would be
                  ; Get offsets using the next footprint's X and Y
                  Xoff = pr_x0[ray_num, subset_scan_num] - pr_x0[ray_num+1, subset_scan_num]
                  Yoff = pr_y0[ray_num, subset_scan_num] - pr_y0[ray_num+1, subset_scan_num]
               endif else begin
                  ; extrapolate X and Y to where (angle = angle+1) would be
                  ; Get offsets using the preceding footprint's X and Y
                  Xoff = pr_x0[ray_num, subset_scan_num] - pr_x0[ray_num-1, subset_scan_num]
                  Yoff = pr_y0[ray_num, subset_scan_num] - pr_y0[ray_num-1, subset_scan_num]
               endelse
              ; compute the resulting lon/lat value of the extrapolated footprint
              ;  - we will add to temp lat/lon arrays in action sections, below
               XX = pr_x0[ray_num, subset_scan_num] + Xoff
               YY = pr_y0[ray_num, subset_scan_num] + Yoff
              ; need x and y in meters for MAP_PROJ_INVERSE:
               extrap_lon_lat = MAP_PROJ_INVERSE (XX*1000., YY*1000., MAP_STRUCTURE=smap)
            ENDIF

         ENDIF ELSE BEGIN
            IF mark_edges EQ 1 THEN BEGIN
              ; Is footprint immediately adjacent to the in-range area?  If so, then
              ;   'ring' the in-range points with a border of PR bogosity, even for
              ;   scans with no rays in-range. (Is like adding a range ring at the
              ;   outer edge of the in-range area)
               IF ( precise_range[ray_num,subset_scan_num] LE $
                    (max_ranges[0] + NOM_PR_RES_KM*1.5) ) THEN BEGIN
                   pr_master_idx[numPRrays] = -1L  ; store beyond-range indicator as PR index
                   pr_lat_sfc[numPRrays] = prlats[ray_num,scan_num]
                   pr_lon_sfc[numPRrays] = prlons[ray_num,scan_num]
                   action2do = -1  ; set up to process bogus beyond-range point
               ENDIF
            ENDIF
         ENDELSE          ; ELSE for precise range[] LE max_ranges[0]

        ; If/As flag directs, add PR point(s) to the subarrays for each elevation
         IF ( action2do NE 0 ) THEN BEGIN
           ; compute the at-surface x,y values for the 4 corners of the current PR footprint
            xy = footprint_corner_x_and_y( subset_scan_num, ray_num, pr_x0, pr_y0, $
                                           nscans2do, RAYSPERSCAN )
           ; compute parallax-corrected x-y values for each sweep height
            FOR i = 0, num_elevations_out - 1 DO BEGIN
              ; NEXT 4+ COMMANDS COULD BE ITERATIVE, TO CONVERGE TO A dR THRESHOLD (function?)
              ; compute GV beam height for elevation angle at precise_range
               rsl_get_slantr_and_h, precise_range[ray_num,subset_scan_num], $
                                     tocdf_elev_angle[i], slant_range, hgt_at_range

              ; compute PR parallax corrections dX and dY at this height, and
              ;   apply to footprint center X and Y to get XX and YY
               get_parallax_dx_dy, hgt_at_range, ray_num, RAYSPERSCAN, $
                                   m, dy_sign, tan_inc_angle, dx, dy
               XX = pr_x0[ray_num, subset_scan_num] + dx
               YY = pr_y0[ray_num, subset_scan_num] + dy

              ; recompute precise_range of parallax-corrected PR footprint from radar (if converging)

              ; compute lat,lon of parallax-corrected PR footprint center:
               lon_lat = MAP_PROJ_INVERSE( XX*1000., YY*1000., MAP_STRUCTURE=smap )  ; x and y in meters

              ; compute parallax-corrected X and Y coordinate values for the PR
              ;   footprint corners; hold in temp arrays xcornerspc and ycornerspc
               xcornerspc = xy[0,*] + dx
               ycornerspc = xy[1,*] + dy

              ; store PR-GV sweep intersection (XX,YY), offset lat and lon, and
              ;  (if non-bogus) corner (x,y)s in elevation-specific slots
               pr_x_center[numPRrays,i] = XX
               pr_y_center[numPRrays,i] = YY
               pr_x_corners[*,numPRrays,i] = xcornerspc
               pr_y_corners[*,numPRrays,i] = ycornerspc
               pr_lon_lat[*,numPRrays,i] = lon_lat
            ENDFOR
            numPRrays = numPRrays + 1   ; increment counter for # PR rays stored in arrays
         ENDIF

         IF ( action2do EQ 2 ) THEN BEGIN
           ; add another PR footprint to the analyzed set, to delimit the PR scan edge
            pr_master_idx[numPRrays] = -2L    ; store off-scan-edge indicator as PR index
            pr_lat_sfc[numPRrays] = extrap_lon_lat[1]  ; store extrapolated lat/lon
            pr_lon_sfc[numPRrays] = extrap_lon_lat[0]

            FOR i = 0, num_elevations_out - 1 DO BEGIN
              ; - grab the parallax-corrected footprint center and corner x,y's just
              ;     stored for the in-range PR edge point, and apply Xoff and Yoff offsets
               XX = pr_x_center[numPRrays-1,i] + Xoff
               YY = pr_y_center[numPRrays-1,i] + Yoff
               xcornerspc = pr_x_corners[*,numPRrays-1,i] + Xoff
               ycornerspc = pr_y_corners[*,numPRrays-1,i] + Yoff
              ; - compute lat,lon of parallax-corrected PR footprint center:
               lon_lat = MAP_PROJ_INVERSE(XX*1000., YY*1000., MAP_STRUCTURE=smap)  ; x,y to m
              ; store in elevation-specific slots
               pr_x_center[numPRrays,i] = XX
               pr_y_center[numPRrays,i] = YY
               pr_x_corners[*,numPRrays,i] = xcornerspc
               pr_y_corners[*,numPRrays,i] = ycornerspc
               pr_lon_lat[*,numPRrays,i] = lon_lat
            ENDFOR
            numPRrays = numPRrays + 1
         ENDIF

      ENDFOR              ; ray_num
   ENDFOR                 ; scan_num = start_scan,end_scan 

  ; ONE TIME ONLY: compute max diagonal size of a PR footprint, halve it,
  ;   and assign to max_PR_footprint_diag_halfwidth.  Ignore the variability
  ;   with height.  Take middle scan of PR overlap within subset arrays:
   subset_scan_4size = FIX( (end_scan-start_scan)/2 )
  ; find which ray used was farthest from nadir ray at RAYSPERSCAN/2
   nadir_off_low = ABS(minrayidx - RAYSPERSCAN/2)
   nadir_off_hi = ABS(maxrayidx - RAYSPERSCAN/2)
   ray4size = (nadir_off_hi GT nadir_off_low) ? maxrayidx : minrayidx
  ; get PR footprint max diag extent at [ray4size, scan4size], and halve it
  ; Is it guaranteed that [subset_scan4size,ray4size] is one of our in-range
  ;   points?  Don't know, so get the corner x,y's for this point
   xy = footprint_corner_x_and_y( subset_scan_4size, ray4size, pr_x0, pr_y0, $
                                  nscans2do, RAYSPERSCAN )
   diag1 = SQRT((xy[0,0]-xy[0,2])^2+(xy[1,0]-xy[1,2])^2)
   diag2 = SQRT((xy[0,1]-xy[0,3])^2+(xy[1,1]-xy[1,3])^2)
   max_PR_footprint_diag_halfwidth = (diag1 > diag2) / 2.0

  ; end of PR GEO-preprocessing

  ; ======================================================================================================

  ; Initialize and/or populate data fields to be written to the netCDF file.
  ; NOTE WE DON'T SAVE THE SURFACE X,Y FOOTPRINT CENTERS AND CORNERS TO NETCDF

   IF ( numPRinrange GT 0 ) THEN BEGIN
     ; Trim the pr_master_idx, lat/lon temp arrays and x,y corner arrays down
     ;   to numPRrays elements in that dimension, in prep. for writing to netCDF
     ;    -- these elements are complete, data-wise
      tocdf_pr_idx = pr_master_idx[0:numPRrays-1]
      tocdf_x_poly = pr_x_corners[*,0:numPRrays-1,*]
      tocdf_y_poly = pr_y_corners[*,0:numPRrays-1,*]
      tocdf_lat = REFORM(pr_lon_lat[1,0:numPRrays-1,*])   ; 3D to 2D
      tocdf_lon = REFORM(pr_lon_lat[0,0:numPRrays-1,*])
      tocdf_lat_sfc = pr_lat_sfc[0:numPRrays-1]
      tocdf_lon_sfc = pr_lon_sfc[0:numPRrays-1]

     ; Create new subarrays of dimension equal to the numPRrays for each 2-D
     ;   PR science variable: landOceanFlag, nearSurfRain, nearSurfRain_2b31,
     ;   BBheight, rainFlag, rainType
      tocdf_2a25_srain = MAKE_ARRAY(numPRrays, /float, VALUE=FLOAT_RANGE_EDGE)
      tocdf_2b31_srain = MAKE_ARRAY(numPRrays, /float, VALUE=FLOAT_RANGE_EDGE)
      tocdf_BB_Hgt = MAKE_ARRAY(numPRrays, /float, VALUE=FLOAT_RANGE_EDGE)
      tocdf_rainflag = MAKE_ARRAY(numPRrays, /int, VALUE=INT_RANGE_EDGE)
      tocdf_raintype = MAKE_ARRAY(numPRrays, /int, VALUE=INT_RANGE_EDGE)
      tocdf_landocean = MAKE_ARRAY(numPRrays, /int, VALUE=INT_RANGE_EDGE)

     ; Create new subarrays of dimensions (numPRrays, num_elevations_out) for each
     ;  PR 3-D science and status variable: 
      tocdf_1c21_dbz = MAKE_ARRAY(numPRrays, num_elevations_out, /float, VALUE=FLOAT_RANGE_EDGE)
      tocdf_2a25_dbz = MAKE_ARRAY(numPRrays, num_elevations_out, /float, VALUE=FLOAT_RANGE_EDGE)
      tocdf_2a25_rain = MAKE_ARRAY(numPRrays, num_elevations_out, /float, VALUE=FLOAT_RANGE_EDGE)
      tocdf_top_hgt = MAKE_ARRAY(numPRrays, num_elevations_out, /float, VALUE=FLOAT_RANGE_EDGE)
      tocdf_botm_hgt = MAKE_ARRAY(numPRrays, num_elevations_out, /float, VALUE=FLOAT_RANGE_EDGE)
      tocdf_1c21_z_rejected = UINTARR(numPRrays, num_elevations_out)
      tocdf_2a25_z_rejected = UINTARR(numPRrays, num_elevations_out)
      tocdf_2a25_r_rejected = UINTARR(numPRrays, num_elevations_out)
      tocdf_pr_expected = UINTARR(numPRrays, num_elevations_out)

     ; Create new subarrays of dimensions (nvols, numPRrays, num_elevations_out) for each
     ;  GR 3-D science and status variable: 
      tocdf_gv_dbz = MAKE_ARRAY(numPRrays, num_elevations_out, nvols, /float, VALUE=FLOAT_RANGE_EDGE)
      tocdf_gv_rejected = UINTARR(numPRrays, num_elevations_out, nvols)
      tocdf_gv_expected = UINTARR(numPRrays, num_elevations_out, nvols)

     ; get the indices of actual PR footprints and load the 2D element subarrays
     ;   (no more averaging/processing needed) with data from the product arrays

      prgoodidx = WHERE( tocdf_pr_idx GE 0L, countprgood )
      IF ( countprgood GT 0 ) THEN BEGIN
         pr_idx_2get = tocdf_pr_idx[prgoodidx]
         tocdf_2a25_srain[prgoodidx] = surfRain_2a25[pr_idx_2get]
         IF ( havefile2b31 EQ 1 ) THEN BEGIN
            tocdf_2b31_srain[prgoodidx] = surfRain_2b31[pr_idx_2get]
         ENDIF
         tocdf_BB_Hgt[prgoodidx] = BB_Hgt[pr_idx_2get]
         tocdf_rainflag[prgoodidx] = rainFlag[pr_idx_2get]
         tocdf_raintype[prgoodidx] = rainType[pr_idx_2get]
         tocdf_landocean[prgoodidx] = landOceanFlag[pr_idx_2get]
      ENDIF

     ; get the indices of any bogus scan-edge PR footprints
      predgeidx = WHERE( tocdf_pr_idx EQ -2, countpredge )
      IF ( countpredge GT 0 ) THEN BEGIN
        ; set the single-level PR element subarrays with the special values for
        ;   the extrapolated points
         tocdf_2a25_srain[predgeidx] = FLOAT_OFF_EDGE
         tocdf_2b31_srain[predgeidx] = FLOAT_OFF_EDGE
         tocdf_BB_Hgt[predgeidx] = FLOAT_OFF_EDGE
         tocdf_rainflag[predgeidx] = INT_OFF_EDGE
         tocdf_raintype[predgeidx] = INT_OFF_EDGE
         tocdf_landocean[predgeidx] = INT_OFF_EDGE
      ENDIF

   ENDIF ELSE BEGIN
      PRINT, ""
      PRINT, "No in-range PR footprints found for ", siteID, ", skipping."
      PRINT, ""
      skiporbit = 1
      GOTO, nextGVfile
   ENDELSE


; STUFF TO DO ONLY FOR THE FIRST VOS IN THE ORBIT (MOSTLY) ENDS HERE
   ENDIF  ; igv EQ 0

  ; ================================================================================================
  ; Map this GV radar's data to the these PR footprints, where PR rays
  ; intersect the elevation sweeps.  This part of the algorithm continues
  ; in code in a separate file, included below:

   @polar2pr_resampling_multi.pro

  ; ================================================================================================

   nextGVfile:

ENDFOR    ; each GV site for orbit

; check whether this is a step-through or a good orbit to process
IF ( skiporbit EQ 0 ) THEN BEGIN

  ; Create a netCDF file with the proper numPRrays and num_elevations_out dimensions
   IF N_ELEMENTS(ncnameadd) EQ 1 THEN BEGIN
      fname_netCDF = NCGRIDSOUTDIR+'/'+GEO_MATCH_PRE+'Multi.'+siteID+'.'+DATESTAMP+'.' $
                      +orbit+'.'+ncnameadd+NC_FILE_EXT
   ENDIF ELSE BEGIN
      fname_netCDF = NCGRIDSOUTDIR+'/'+GEO_MATCH_PRE+'Multi.'+siteID+'.'+DATESTAMP+'.' $
                      +orbit+NC_FILE_EXT
   ENDELSE
   ncfile = gen_geo_match_netcdf_multi( fname_netCDF, numPRrays, tocdf_elev_angle, $
                                        nvols, gv_z_field, PR_version )

  ; Open file and write the completed field values to the netCDF file
   ncid = NCDF_OPEN( ncfile, /WRITE )
   NCDF_VARPUT, ncid, 'site_ID', siteID
   NCDF_VARPUT, ncid, 'site_lat', siteLat
   NCDF_VARPUT, ncid, 'site_lon', siteLon
   NCDF_VARPUT, ncid, 'site_elev', siteElev
   NCDF_VARPUT, ncid, 'timeNearestApproach', pr_dtime_ticks
   NCDF_VARPUT, ncid, 'atimeNearestApproach', pr_dtime
;   ticks_sweep_times=REFORM(ticks_sweep_times,num_elevations_out,nvols)
   NCDF_VARPUT, ncid, 'timeSweepStart', REFORM(ticks_sweep_times,num_elevations_out,nvols)
;   text_sweep_times = REFORM(text_sweep_times,num_elevations_out,nvols)
   NCDF_VARPUT, ncid, 'atimeSweepStart', REFORM(text_sweep_times,num_elevations_out,nvols)
   NCDF_VARPUT, ncid, 'rangeThreshold', range_threshold_km
   NCDF_VARPUT, ncid, 'PR_dBZ_min', PR_DBZ_MIN
   NCDF_VARPUT, ncid, 'GV_dBZ_min', dBZ_min
   NCDF_VARPUT, ncid, 'rain_min', PR_RAIN_MIN

;  Write single-level results/flags to netcdf file

   NCDF_VARPUT, ncid, 'PRlatitude', tocdf_lat_sfc
   NCDF_VARPUT, ncid, 'PRlongitude', tocdf_lon_sfc
   NCDF_VARPUT, ncid, 'landOceanFlag', tocdf_landocean     ; data
    NCDF_VARPUT, ncid, 'have_landOceanFlag', DATA_PRESENT  ; data presence flag
   NCDF_VARPUT, ncid, 'nearSurfRain', tocdf_2a25_srain     ; data
    NCDF_VARPUT, ncid, 'have_nearSurfRain', DATA_PRESENT   ; data presence flag
   IF ( havefile2b31 EQ 1 ) THEN BEGIN
      NCDF_VARPUT, ncid, 'nearSurfRain_2b31', tocdf_2b31_srain      ; data
       NCDF_VARPUT, ncid, 'have_nearSurfRain_2b31', DATA_PRESENT    ; dp flag
   ENDIF
   NCDF_VARPUT, ncid, 'BBheight', tocdf_BB_Hgt        ; data
    NCDF_VARPUT, ncid, 'have_BBheight', DATA_PRESENT  ; data presence flag
   NCDF_VARPUT, ncid, 'rainFlag', tocdf_rainflag      ; data
    NCDF_VARPUT, ncid, 'have_rainFlag', DATA_PRESENT  ; data presence flag
   NCDF_VARPUT, ncid, 'rainType', tocdf_raintype      ; data
    NCDF_VARPUT, ncid, 'have_rainType', DATA_PRESENT  ; data presence flag
   NCDF_VARPUT, ncid, 'rayIndex', tocdf_pr_idx

;  Write sweep-level results/flags to netcdf file

   NCDF_VARPUT, ncid, 'latitude', tocdf_lat
   NCDF_VARPUT, ncid, 'longitude', tocdf_lon
   NCDF_VARPUT, ncid, 'xCorners', tocdf_x_poly
   NCDF_VARPUT, ncid, 'yCorners', tocdf_y_poly
   NCDF_VARPUT, ncid, 'threeDreflect', tocdf_gv_dbz            ; data
    NCDF_VARPUT, ncid, 'have_threeDreflect', DATA_PRESENT      ; data presence flag
   NCDF_VARPUT, ncid, 'dBZnormalSample', tocdf_1c21_dbz        ; data
    NCDF_VARPUT, ncid, 'have_dBZnormalSample', DATA_PRESENT    ; data presence flag
   NCDF_VARPUT, ncid, 'correctZFactor', tocdf_2a25_dbz         ; data
    NCDF_VARPUT, ncid, 'have_correctZFactor', DATA_PRESENT     ; data presence flag
   NCDF_VARPUT, ncid, 'rain', tocdf_2a25_rain                  ; data
    NCDF_VARPUT, ncid, 'have_rain', DATA_PRESENT               ; data presence flag
   NCDF_VARPUT, ncid, 'topHeight', tocdf_top_hgt
   NCDF_VARPUT, ncid, 'bottomHeight', tocdf_botm_hgt
   NCDF_VARPUT, ncid, 'n_gv_rejected', tocdf_gv_rejected
   NCDF_VARPUT, ncid, 'n_gv_expected', tocdf_gv_expected
   NCDF_VARPUT, ncid, 'n_1c21_z_rejected', tocdf_1c21_z_rejected
   NCDF_VARPUT, ncid, 'n_2a25_z_rejected', tocdf_2a25_z_rejected
   NCDF_VARPUT, ncid, 'n_2a25_r_rejected', tocdf_2a25_r_rejected
   NCDF_VARPUT, ncid, 'n_pr_expected', tocdf_pr_expected

   NCDF_CLOSE, ncid
  ; gzip the GV netCDF grid file
   PRINT
   PRINT, "Output netCDF file:"
   PRINT, ncfile
   PRINT, "is being compressed."
   PRINT
   command = "gzip -v " + ncfile
   spawn, command

   IF keyword_set(plot_ppis) THEN BEGIN
     ; delete the two PPI windows at the end
      wdelete, !d.window
      wdelete, !d.window
   ENDIF
ENDIF

ENDWHILE  ; each orbit/PR file set to process in control file

noCases:

print, ""
print, "Done!"

END
