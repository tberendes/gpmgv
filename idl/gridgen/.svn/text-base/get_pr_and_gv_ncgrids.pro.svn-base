;+
; Copyright © 2008, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;
;-------------------------------------------------------------------------------
; get_pr_and_gv_ncgrids.pro    Bob Morris, GPM GV (SAIC)    December 2006
;
;
; DESCRIPTION
; -----------
; Reads an interleaved, delimited text file listing 1C21, 2A25, and 2B31 files,
; their orbit number, and the number N of GPMGV NEXRAD sites overpassed by the
; PR for the orbit on one line; followed by the ID, volume scan time (unix
; ticks), latitude and longitude, and the 2A55, 2A54 and 2A53 file pathnames
; of each overpassed site on 1:N separate lines, one site's data per line. 
; These sequences repeat for each PR filepair/orbit to be processed in a run
; of this program (typically all those in a given day).
;
; - See doAllGrids_w_GV.sh script for how the delimited file is created in SQL.
;
; For each file/orbit and site, the HDF files are gunzip'ped and procedures
; are called to open and read the files and generate the 300x300 km grids of
; 4 km resolution centered on the radar site lat/lon for the various elements
; for the PR and ground radar.  The resulting PR and ground radar grids are
; then written separately to a pair of site/orbit/source-specific netCDF files.
;
; "get_pr_and_gv_ncgrids.pro" is based very loosely on Liang Liao's
;  "comparison_PR_GV_dBZ.pro" routine.
; "generate_pr_ncgrids.pro" is a highly-modified version of Liang's
;  routine "access1C21_2A25.pro".
; "generate_2A55_ncgrids" is a highly-modified version of Liang's
;  routine "access2A55.pro".
; "read_1c21_ppi", "read_2a25", "read_2a55", and "coordinate_b_to_a.pro" are
;  slightly modified from Liang's routines (using modified commons and/or
;  arguments).
; "distance_a_and_b.pro" is renamed but unmodified from Liang's version.
;
;
; FILES
; -----
; TMP_DIR/PR_files_sites4grid.YYMMDD.txt (INPUT) - lists PR subset files,
;    their orbit, and information on the (one or more) overpassed NEXRAD
;    sites and their corresponding 2A5x radar site files, where YYMMDD is
;    the year, month, day of the parent script's run.  File pathname is
;    externally specified by the GETMYMETA environment variable's value, and
;    is can be whatever is desired as long as the file format is correct.
;
;    This control file has the following structure.  The block labels in
;    parentheses are not part of the file:
;
;       1C21_filename|2A25_filename|2B31_filename|ORBIT_NUMBER|NSITES|DATESTAMP|SUBSET       (first block)
;       event_num_1|siteID_1|siteLat_1|siteLon_1|siteElev_1|2A55_filepath1|2A54_filepath1|2A53_filepath1
;       event_num_2|siteID_2|siteLat_2|siteLon_2|siteElev_2|2A55_filepath2|2A54_filepath2|2A53_filepath2
;         . 
;         .   repeats M = NSITES times [1..M]
;         . 
;       event_num_M|siteID_M|siteLat_M|siteLon_M|siteElev_M|2A55_filepathM|2A54_filepathM|2A53_filepathM
;       1C21_filename|2A25_filename|2B31_filename|ORBIT_NUMBER|NSITES|DATESTAMP|SUBSET       (second block)
;       event_num_1|siteID_1|siteLat_1|siteLon_1|siteElev_1|2A55_filepath1|2A54_filepath1|2A53_filepath1
;       event_num_2|siteID_2|siteLat_2|siteLon_2|siteElev_2|2A55_filepath2|2A54_filepath2|2A53_filepath2
;         . 
;         .   repeats N = NSITES times [1..N]
;         . 
;       event_num_N|siteID_N|siteLat_N|siteLon_N|siteElev_N|2A55_filepathN|2A54_filepathN|2A53_filepathN
;
;   Thus, a "pattern block" is defined in the control file for each orbit/subset whose
;   data are to be processed: one row listing the three orbit subset PR filenames,
;   the orbit number, the number of sites to process for the orbit, and (optionally)
;   the datestamp of the orbit and the PR subset to which the PR files apply; followed
;   by one-to-many rows listing the GV site information for each site overpass
;   "event" for which a PR/GV grid pair will be produced for the orbit.
;   Pattern block repeats for each ORBIT/SUBSET combination to be processed.
;   For a given orbit and subset combination (and its associated 1C21/2A25/2B31
;   file triplet) there are NSITES sites overpassed, and output netCDF grids
;   will be produced for each of these sites.
;
;   The 2A55_filepath is a partial pathname to the specific 2A55 HDF file.  The
;   'in-common' part of the path is prepended to the partial pathname to get the
;   complete file path.  The in-common path is specified in the include file
;   'environs.inc' as the variable GVDATA_ROOT.  A special value is defined for
;   the cases where no 2A55 data are available for the overpass event, but it is
;   still desired to produce gridded PR data for the site overpass.  In this
;   case, the file pathname value should be specified in the control file as
;   'no_2A55_file', without the quotes.  The same applies to the 2A54_filepath
;   and 2A53_filepath, except missing files are indicated by 'no_2A54_file' and
;   'no_2A53_file', respectively (sans quotes).
;
;   The event_num value is a unique number for each site overpass event within
;   the full GPM Validation Network prototype system, and is the database key
;   value which serves to identify both an overpassed ground site ID and the
;   orbit in which it is overpassed.  It is not used in the current processing,
;   it is only printed as the event's grids are processed.  Any value may be
;   substituted for event_num if running this code outside the full GPM
;   Validation Network environment.  It is not constrained to being unique
;   within this code.
;
; PRDATA_ROOT/1C21/1C21.YYMMDD.ORBIT#.6.sub-GPMGV1.hdf.gz (INPUT) - 1C21
;    data files to be processed, where YYMMDD is the year/month/day and ORBIT#
;    is the TRMM orbit number, as listed (as FILE BASENAME only) in the
;    PR_files_sites4grid.YYMMDD.txt file.
;
; PRDATA_ROOT/2A25/2A25.YYMMDD.ORBIT#.6.sub-GPMGV1.hdf.gz (INPUT) - 2A25
;    data files to be processed, where YYMMDD is the year/month/day and ORBIT#
;    is the TRMM orbit number, as listed (as FILE BASENAME only) in the
;    PR_files_sites4grid.YYMMDD.txt file.
;
; GVDATA_ROOT/SITE/level_2/YYYY/gvs_2A-55-dc_SITE_MM-YYYY/2A55.YYMMDD.h(h).site.HDF.gz
;    (INPUT) - TRMM-GV-produced HDF data files to be processed, where SITE is
;    the NWS ID of the NEXRAD radar (e.g. KMLB), YYYY is the year of the data,
;    MM is the month of the data, YYMMDD.h(h) are the year-month-day and
;    nominal hour (1-24, one or two digits, rounded up) of the radar volume,
;    and "site" is the TRMM GV ID of the NEXRAD site, as listed (a partial
;    file pathname beginning with SITE) in the PR_files_sites4grid.YYMMDD.txt
;    file.
;
; GVDATA_ROOT/SITE/level_2/YYYY/gvs_2A-54-dc_SITE_MM-YYYY/2A54.YYMMDD.h(h).site.HDF.gz
;    (INPUT) - As for the preceding file, but for the TRMM GV 2A-54 product.
;
; GVDATA_ROOT/SITE/level_2/YYYY/gvs_2A-53-dc_SITE_MM-YYYY/2A53.YYMMDD.h(h).site.HDF.gz
;    (INPUT) - As for the preceding file, but for the TRMM GV 2A-53 product.
;
; TMP_DIR/templatePRgrids.nc (INPUT) - empty netCDF "template" file for the
;    2-D and 3-D grids for the PR 1C-21 and 2A-25 data (below).  Template file
;    is copied to a site/orbit specific filename before being populated.
;
; NCGRIDS_ROOT/PR_NCGRIDDIR/PRgrids.Kxxx.ORBIT.YYMMDD-HHMM.nc (OUTPUT) - netCDF
;    file holding the 2-D and 3-D gridded data for the 1C21 and 2A25 elements
;    for a given overpassed NEXRAD site (Kxxx) for a given ORBIT number.
;    -- Kxxx is the WSR-88D siteID as read from the control file.
;    -- ORBIT is the TRMM orbit number as read from the control file.
;    -- YYMMDD is given by the RUNDATE environment variable's value.
;    -- HHMM is the hour and minute of the site overpass from the control file.
;    -- The prefix 'PRgrids.' and extension '.nc' are defined in 'environs.inc'
;       by the variables PR_NCGRIDPRE and NC_FILE_EXT, respectively.
;
; TMP_DIR/templateGVgrids.nc (INPUT) - empty netCDF "template" file for the
;    3-D grids for the GV 2A-55/54/53 data (below).  Template file
;    is copied to a site/orbit specific filename before being populated.
;
; NCGRIDS_ROOT/GV_NCGRIDDIR/GVgrids.Kxxx.ORBIT.YYMMDD-HHMM.nc (OUTPUT) - netCDF
;    file holding the resolution-reduced 3-D gridded data for the 2A55, 2A54,
;    and 2A53 elements for a given overpassed NEXRAD site (Kxxx) and TRMM
;    orbit number (ORBIT).
;    -- Kxxx is the WSR-88D siteID as read from the control file.
;    -- ORBIT is the TRMM orbit number as read from the control file.
;    -- YYMMDD is given by the RUNDATE environment variable's value.
;    -- HHMM is the hour and minute of the site overpass, from the control file.
;    -- The prefix 'GVgrids.' and extension '.nc' are defined in 'environs.inc'
;       by the variables PR_NCGRIDPRE and NC_FILE_EXT, respectively.
;
; The actual values of the file/path variables used above and within the body
; of this procedure, as listed below, must be defined in the "include" file
; 'environs.inc':
;
;   TMP_DIR  NCGRIDS_ROOT  PRDATA_ROOT  GVDATA_ROOT  PR_NCGRIDDIR  GV_NCGRIDDIR
;   PR_NCGRIDPRE  PR_NCGRIDTEMPLATE  GV_NCGRIDPRE  GV_NCGRIDTEMPLATE
;   NC_FILE_EXT
;
;
; ARGUMENTS
; -------------------------------
; 1) DATESTAMP  - year, month, and day of parent script's run in YYMMDD format
; 2) FILES4NC   - fully-qualified file pathname to INPUT CONTROL file
;
;
; CONSTRAINTS
; -----------
; 1) Program is expected to process one (UTC) day's data.  All orbits/overpass
;    events in the control file are expected to be for the date specified in
;    DATESTAMP.  Output NETCDF files contain DATESTAMP as part of the file name.
;    However, these are not hard-and-fast constraints, and DATESTAMP can be any
;    string that is a valid part of a unix filename, and the control file can
;    include files/orbits from any date or dates, as the combination of siteID
;    and orbit number will still result in unique output netCDF filenames.
; 2) Working directory must be writeable, as the 1C21, 2A25, and 2A5x files are
;    copied into this directory to be unzipped, and then the copy deleted. 
; 3) Both the 1C21 and 2A25 data files for an orbit are required.
;
; HISTORY
; -------
; 06/12/2007 Morris        Added processing of 2A-54 and 2A-53 GV products.
;                          Changed logic to still produce a PR netCDF gridfile
;                            in case of missing 2A53 and/or 2A55 GV products.
; 08/02/2007 Morris        Folded in the 2B-31 product processing additions
;                            provided by Jerry Wang (TRMM GV).
; 08/08/2011 Morris        Added siteElevation to the control file and PR data
;                            processing.
;
;-------------------------------------------------------------------------------
;-

pro get_pr_and_gv_ncgrids, DATESTAMP, FILES4NC

common sample,       start_sample, sample_range, num_range, dbz_min
common time,         event_time, volscantime, orbit
common groundSite,   event_num, siteID, siteLong, siteLat, siteElev, nsites
common sample_rain,  RAIN_MIN, RAIN_MAX                  ; for access2A25
common trig_precalc, cos_inc_angle, tan_inc_angle

; "Include" files for constants, names, paths, etc.
@environs.inc
@grid_def.inc
@pr_params.inc

Tbegin = SYSTIME(1)

DBZ_MIN = 15

; find, open the input file listing the HDF files and NEXRAD sites/lats/lons

if ( DATESTAMP eq '' ) then begin
   message, 'DATESTAMP not set'
endif

if ( FILES4NC eq '' ) then begin
   message, 'Control file pathname not set'
endif

inctlfile = file_search(FILES4NC, COUNT=nf)
if ( nf NE 1 ) then begin
   message, 'Control file not found/not unique: ' + FILES4NC
endif

ctlfilebase = FILE_BASENAME(FILES4NC)
date_embedded = STRPOS( ctlfilebase, DATESTAMP )
if (date_embedded eq -1) then begin
   print, ''
   print, 'NOTE:  Supplied DATETIME not included within control file name'
   print, ''
   Print, 'DATETIME:      ', DATESTAMP
   print, 'Control File:  ', ctlfilebase
   print, ''
endif

; Create and make sure PR and GV netCDF template files exist
pr_template_file = ''
gv_template_file = ''

gen_pr_netcdf_template, pr_template_file
if (pr_template_file eq '') then $
   message, 'Error creating PR netCDF template file.'

gen_gv_netcdf_template, gv_template_file
if (gv_template_file eq '') then $
   message, 'Error creating GV netCDF template file.'

; eliminate repetitive trig calculations by storing precomputed results
;RAYSPERSCAN = 49
angle = findgen(RAYSPERSCAN) - RAYSPERSCAN/2
;rays at approx. 0.71 deg. increments - removed abs(), no diff. for cos()
angle = 0.71*3.1415926D*(angle)/180. 
cos_inc_angle = cos(angle)  ;precomputed for gateN, below
tan_inc_angle = tan(angle)  ;precomputed for dR calculations below

; initialize the variables into which file records are read as strings
data4 = ''
event_site_lat_lon = ''


OPENR, lun0, FILES4NC, ERROR=err, /GET_LUN

While not (EOF(lun0)) Do Begin 

;  read the '|'-delimited input file record into a single string
   READF, lun0, data4

;  parse data4 into its component fields: 1C21 file name, 2A25 file name,
;  2B31 file name, orbit number, number of sites

   parsed=strsplit( data4, '|', /extract )
   origFile21Name = parsed[0] ; filename as listed in/on the database/disk
   origFile25Name = parsed[1] ; filename as listed in/on the database/disk
   origFile31Name = parsed[2] ; filename as listed in/on the database/disk
   orbit = long( parsed[3] )
   nsites = fix( parsed[4] )
   if ( n_elements(parsed) gt 5 ) then begin
      print, "Overriding DATESTAMP parameter from: ", DATESTAMP, $
             " to control file value: ", parsed[5]
      DATESTAMP = parsed[5]
   endif
   if ( n_elements(parsed) gt 6 ) then subset = parsed[6]

;
;  add the well-known paths to get the fully-qualified file names
   file_1c21 = PRDATA_ROOT+DIR_1C21+"/"+origFile21Name
   file_2a25 = PRDATA_ROOT+DIR_2A25+"/"+origFile25Name
   file_2b31 = PRDATA_ROOT+DIR_2B31+"/"+origFile31Name
   if ( DATESTAMP eq 'v7test' ) then file_2a25 = "/data/tmp/prsubsets_v7_test/"+origFile25Name
;
   print, ""
   print, '================================================================'
   print, ""
   print, 'ORBIT: ', orbit, '    Qualifying overpass sites: ', nsites
   print, 'PR files:  ', file_1c21
   print, '           ', file_2a25
   print, '           ', file_2b31
   print, ""
;

; Read 1c21 Normal Sample and Land-Ocean flag
;
; Check status of file_1c21 before proceeding -  actual file
; name on disk may differ if file has been uncompressed already.
;
   havefile = find_alt_filename( file_1c21, found1c21 )
   if ( havefile ) then begin
;     Get an uncompressed copy of the found file
      cpstatus = uncomp_file( found1c21, file21_2do )
      if(cpstatus eq 'OK') then begin
;        Initialize variables for 1C21 use
         SAMPLE_RANGE=0
         START_SAMPLE=0
         END_SAMPLE=0
         num_range = NUM_RANGE_1C21
         dbz_1c21=fltarr(sample_range>1,1,num_range)
         landOceanFlag=intarr(sample_range>1,RAYSPERSCAN)
         binS=intarr(sample_range>1,RAYSPERSCAN)
         rayStart=intarr(RAYSPERSCAN)
;        Read the uncompressed 1C21 file copy
         read_1c21, file21_2do, DBZ=dbz_1c21, OCEANFLAG=landOceanFlag, $
                     BinS=binS, RAY_START=rayStart
;        Delete the temporary file copy
         print, "Remove 1C21 file copy:"
         command = 'rm ' + file21_2do
         print, command
         spawn, command
      endif else begin
         print, cpstatus
         goto, errorExit
      endelse
   endif else begin
      print, "Cannot find regular/compressed file " + file_1c21
      goto, errorExit
   endelse

; Read 2a25 elements and (shared) geolocation

; Check status of file_2a25 before proceeding -  check if compressed (.Z, .gz,)
; or not.  We start with filename as listed in database, not actual file
; name on disk which may differ if file has been uncompressed already.
;
   havefile = find_alt_filename( file_2a25, found2a25 )
   if ( havefile ) then begin
;     Get an uncompressed copy of the found file
      cpstatus = uncomp_file( found2a25, file25_2do )
      if(cpstatus eq 'OK') then begin
;
;        reinitialize the common variables
;
         SAMPLE_RANGE=0
         START_SAMPLE=0
         END_SAMPLE=0
         RAIN_MIN = 0.01
         RAIN_MAX = 60.
;
;        Read 2a25 Correct dBZ (and friends) from HDF file
;
;        Initialize variables for 2A25 use
;
         num_range = NUM_RANGE_2A25
         dbz_2a25=fltarr(sample_range>1,1,num_range)
         rain_2a25 = fltarr(sample_range>1,1,num_range)
         surfRain_2a25=fltarr(sample_range>1,RAYSPERSCAN)
         geolocation=fltarr(2,RAYSPERSCAN,sample_range>1)
         rangeBinNums=intarr(sample_range>1,RAYSPERSCAN,7)
         rainFlag=intarr(sample_range>1,RAYSPERSCAN)
         rainType=intarr(sample_range>1,RAYSPERSCAN)

         read_2a25, file25_2do, DBZ=dbz_2a25, RAIN=rain_2a25, TYPE=rainType, $
                    SURFACE_RAIN=surfRain_2a25, GEOL=geolocation, $
                    RANGE_BIN=rangeBinNums, RN_FLAG=rainFlag
;        Delete the temporary file copy
         print, "Remove 2A25 file copy:"
         command = 'rm ' + file25_2do
         print,command
         spawn,command
      endif else begin
         print, cpstatus
         goto, errorExit
      endelse
   endif else begin
      print, "Cannot find regular/compressed file " + file_2a25
      goto, errorExit
   endelse

   lons = fltarr(RAYSPERSCAN,sample_range>1)
   lats = fltarr(RAYSPERSCAN,sample_range>1)
   lons[*,*] = geolocation[1,*,*]
   lats[*,*] = geolocation[0,*,*]

; -----------------------------------------------------------------------

; The following test allows PR grid generation to proceed without the
; 2B-31 data file being available.  This is for the interim where the
; 2B-31's are not yet filled in back to the start of GPMGV TSDIS data.

   IF ( origFile31Name EQ 'no_2B31_file' ) THEN BEGIN
      havefile2b31 = 0
   ENDIF ELSE BEGIN

; Read 2B31 surface rain

; Check status of file_2b31 before proceeding -  check if compressed (.Z, .gz,)
; or not.  We start with filename as listed in database, not actual file
; name on disk which may differ if file has been uncompressed already.
;
      havefile2b31 = find_alt_filename( file_2b31, found2b31 )
      if ( havefile2b31 ) then begin
;        Get an uncompressed copy of the found file
         cpstatus = uncomp_file( found2b31, file31_2do )
         if(cpstatus eq 'OK') then begin
            flag = load_2b31(file31_2do,struct_2b31)
	    if ( flag eq 'OK') then begin
               surfRain_2b31=struct_2b31.rain

; transpose surfRain_2b31 so that it's same as surfRain_2a25 
               surfRain_2b31=transpose(surfRain_2b31)
;            help,surfRain_2b31,surfRain_2a25
            endif else begin
	       print, "Skipping 2B31 data processing for this file."
	       havefile2b31 = 0
	    endelse

;           Delete the temporary file copy
            print, "Remove 2b31 file copy:"
            command = 'rm ' + file31_2do
            print,command
            spawn,command
         endif else begin
            print, cpstatus
            goto, errorExit
         endelse
      endif else begin
         print, "Cannot find regular/compressed file " + file_2b31
         goto, errorExit
     endelse
  ENDELSE
      
; -----------------------------------------------------------------------

;
   print, ""
   print, 'Process grids for each site overpassed for this orbit/filename'
   print, ""
;
   event_num = 0L
   siteID = ""
   event_time = 0.0D+0
   siteLat = -999.0
   siteLong = -999.0
   file_2a55 = ""

   for i=0, nsites-1 do begin
;     read each overpassed site's information as a '|'-delimited string
      READF, lun0, event_site_lat_lon
;      print, i+1, ": ", event_site_lat_lon
;     parse the delimited string into event_num, siteID, latitude, and
;     longitude fields
      parsed=strsplit( event_site_lat_lon, '|', /extract )
      event_num = long( parsed[0] )
      siteID = parsed[1]
      event_time = double( parsed[2] )
      siteLat = float( parsed[3] )
      siteLong = float( parsed[4] )
      siteElev = parsed[5]
      file_2a55 = parsed[6]
      file_2a54 = parsed[7]
      file_2a53 = parsed[8]
      print, '----------------------------------------------------------------'
      print, i+1, ": ", event_num, "  ", siteID, siteLat, siteLong, siteElev
      print, i+1, ": ", file_2a55
      print, i+1, ": ", file_2a54
      print, i+1, ": ", file_2a53
;
;     Generate the PR NetCDF file name for this event and copy template
;     ("empty") netCDF file to this name
;
      ncpathprefix = NCGRIDS_ROOT + PR_NCGRIDDIR + PR_NCGRIDPRE
      ncfile = string(ncpathprefix, siteID, DATESTAMP, orbit, NC_FILE_EXT, $
         format = '(a0, a0, ".", a0, ".", i0, a0)')
;      print, "NetCDF file name:  ", ncfile
      command = "cp " + pr_template_file + ' ' + ncfile
      print, command
      spawn,command
;
;     Call generate_pr_ncgrids to analyze/write grids to netCDF file
;
;     The following test allows PR grid generation to proceed without the
;     2B-31 data file being available.  This is for the interim where the
;     2B-31's are not yet filled in back to the start of GPMGV TSDIS data.

      if ( havefile2b31 ) then begin
         generate_pr_ncgrids, nAvgHeight=2, ncfile, lons, lats,   $
                              dbz_2a25, rain_2a25, surfRain_2a25, $
                              COMBO_RAIN = surfRain_2b31,         $
                              rangeBinNums, rainFlag, rainType,   $
                              dbz_1c21, landOceanFlag, binS, rayStart
      endif else begin
         generate_pr_ncgrids, nAvgHeight=2, ncfile, lons, lats,   $
                              dbz_2a25, rain_2a25, surfRain_2a25, $
                              rangeBinNums, rainFlag, rainType,   $
                              dbz_1c21, landOceanFlag, binS, rayStart
      endelse
;
;     gzip the PR netCDF grid file
      command = "gzip " + ncfile
      spawn, command
;
;     Check whether we have either a matching 2A-55 or 2A-53 data file for site
;     overpass.  If not then skip regridding and netCDF file creation for NEXRAD.
;
      if file_2A55 eq 'no_2A55_file' and file_2A53 eq 'no_2A53_file' then begin
        print, 'Skipping, no 2A-53/55 data files for event_num = ', event_num
        print, ""

      endif else begin
;
;       Generate the GV NetCDF file name for this event
;
        ncgvpathprefix = NCGRIDS_ROOT + GV_NCGRIDDIR + GV_NCGRIDPRE
        ncgvfile = string(ncgvpathprefix, siteID, DATESTAMP, orbit, $
                          NC_FILE_EXT, $
           format = '(a0, a0, ".", a0, ".", i0, a0)')
;        print, "GV NetCDF file name:  ", ncgvfile
        command = "cp " + gv_template_file + ' ' + ncgvfile
        print, command
        spawn, command
;
        gvfiles = strarr(3)
        gvfiles[0] = file_2a55
        gvfiles[1] = file_2a54
        gvfiles[2] = file_2a53
        FOR gvfilenum = 0, 2 do begin
;         See whether the GV file is indicated as missing
          check4miss = STRPOS( gvfiles[gvfilenum], 'no_2A5' )
          IF ( check4miss eq -1 ) then begin
;           Prepare the 2A5x file for reading. Add the well-known path to get
;           the fully-qualified file name.  Must copy the 2A-5x gzip'd file
;           to working directory, don't have permissions to unzip them in-place.
;
            fileOrig_2a5x = GVDATA_ROOT + "/" + gvfiles[gvfilenum]
;            print, "Full 2A-5x file name: ", fileOrig_2a5x
            havefile = find_alt_filename( fileOrig_2a5x, found2a5x )
            if ( havefile ) then begin
;              Get an uncompressed copy of the found file
               cpstatus = uncomp_file( found2a5x, file_2do )
               if(cpstatus eq 'OK') then begin
;
;                 Call generate_2A5x_ncgrids to produce and write
;                  reduced-resolution GV grids to netCDF file.
;
                  case gvfilenum of
                       0 : generate_2A55_ncgrids, file_2do, ncgvfile
                       1 : generate_2A54_ncgrids, file_2do, ncgvfile
                       2 : generate_2A53_ncgrids, file_2do, ncgvfile
                    else : print, 'Trouble with a capital T !!'
                  endcase
;
;                 Remove the temporary 2A-5x file copy
                  command = "rm " + file_2do
                  spawn,command
;
               endif else begin
                  print, cpstatus
                  goto, errorExit
               endelse
            endif else begin
               print, "Cannot find regular/compressed file " + fileOrig_2a5x
               goto, errorExit
            endelse
          ENDIF
        ENDFOR
;       gzip the GV netCDF grid file
        command = "gzip " + ncgvfile
        spawn, command
        print, 'PR-GV time difference: ', event_time - volscantime

      endelse  ; 2A55 and/or 2A53 file not flagged as missing

   endfor

EndWhile

errorExit:
CLOSE, lun0  &   FREE_LUN, lun0

print
print, "Elapsed time in seconds: ", SYSTIME(1) - Tbegin
print

END

@gen_pr_netcdf_template.pro
@gen_gv_netcdf_template.pro
@find_alt_filename.pro
@fmtdatetime.pro
@generate_pr_ncgrids.pro
@generate_2a55_ncgrids.pro
@generate_2a54_ncgrids.pro
@generate_2a53_ncgrids.pro
@load_2b31.pro
@read_1c21.pro
@read_2a25.pro
@coordinate_b_to_a
