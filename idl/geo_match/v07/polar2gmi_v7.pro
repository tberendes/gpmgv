;===============================================================================
;+
; Copyright © 2014, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; polar2gmi_v7.pro          Morris/SAIC/GPM_GV      January 2014
;
; DESCRIPTION
; -----------
; (In the descriptions that follow, only the GPM GMI instrument is referenced,
;  whereas the code is designed to use 2A-GPROF data from any satellite and
;  instrument for which the 2A-GPROF product is produced.)

; Performs a resampling of GMI and GR data to common 3-D volumes, as defined in
; the horizontal by the location of GMI rays, and in the vertical by the heights
; of the intersection of the GMI rays with the top and bottom edges of individual
; elevation sweeps of a ground radar scanning in PPI mode.  The data domain is
; determined by the location of the ground radars overpassed by the GMI swath,
; and by the cutoff range (range_threshold_km) which is a mandatory parameter
; for this procedure.  The GMI and GR (ground radar) files to be processed are
; specified in the control_file, which is a mandatory parameter containing the
; fully-qualified file name of the control file to be used in the run.  Optional
; parameters (GPM_ROOT and DIRGV) allow for non-default local paths to the GMI and
; GR files whose partial pathnames are listed in the control file.  The defaults
; for these paths are as specified in the environs.inc file.  All file path
; optional parameter values must begin with a leading slash (e.g., '/mydata')
; and be enclosed in quotes, as shown.  Optional binary keyword parameters
; control as-produced plotting of matched GMI rainrate and GR reflectivity
; sweep-by-sweep in the form of PPIs on a map background (/PLOT_PPIS), and
; plotting of the matching GMI and GV bin horizontal outlines (/PLOT_BINS) for
; the 'common' 3-D volume.  In the case of the GMI, the same surface rain rate
; field is plotted against each elevation sweep of the GR.
;
; A second set of matching GR volumes is computed along the local vertical (not
; along the GMI path), at the location of the GMI surface footprint, over the
; area of the GMI footprint.  In either case, the GMI footprint fixed diameter
; is computed as the maximum distance between adjacent GMI footprint center
; locations for the middle GMI scan line of those intersecting the GR location
; within a distance defined by the range_threshold_km value, specified as
; an input parameter.
;
; The control file is of a specific layout and contains specific fields in a
; fixed order and format.  See the script "doTMIGeoMatch4NewRainCases.sh", which
; creates the control file and invokes IDL to run this procedure.  Completed
; GMI and GR matchup data for an individual site overpass event (i.e., a given
; TRMM orbit and ground radar site) are written to a netCDF file.  The size of
; the dimensions in the data fields in the netCDF file vary from one case to
; another, depending on the number of elevation sweeps in the GV radar volume
; scan and the number of GMI footprints within the cutoff range from the GR site.
;
; The optional parameter NC_FILE specifies the directory to which the output
; netCDF files will be written.  It is created if it does not yet exist.  Its
; default value is derived from the variables NCGRIDS_ROOT+GEO_MATCH_NCDIR as
; specified in the environs.inc file.  If the binary parameter FLAT_NCPATH is
; set then the output netCDF files are written directly under the NC_FILE
; directory (legacy behavior).  Otherwise a hierarchical subdirectory tree is
; (as needed) created under the NC_FILE directory, of the form:
;     SATELLITE/INSTRUMENT/2AGPROF/PPS_VERSION/MATCHUP_VERSION/YEAR
; and the output netCDF files are written to this subdirectory.  The 2AGPROF
; subdirectory name is the literal value "2AGPROF".  The remaining path
; components are determined in this procedure.
;
; An optional parameter (NC_NAME_ADD) specifies a component to be added to the
; output netCDF file name, to specify uniqueness in the case where more than
; one version of input data are used, a different range threshold is used, etc.
;
; NOTE: THE SET OF CODE CONTAINED IN THIS FILE IS NOT THE COMPLETE POLAR2GMI
;       PROCEDURE.  THE REMAINING CODE IN THE FULL PROCEDURE IS CONTAINED IN
;       THE FILE "polar2gmi_resampling.pro", WHICH IS INCORPORATED INTO THIS
;       FILE/PROCEDURE BY THE IDL "include" MECHANISM.
;
;
; MODULES
; -------
;   1) FUNCTION  plot_bins_bailout
;   2) PROCEDURE polar2gmi
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
; GMI: 1) Only 2A-GPROF HDF5 files are supported by this code.
;  GV: 1) Only radar data files in Universal Format (UF) are supported by this
;         code, although radar files in other formats supported by the TRMM Radar
;         Software Library (RSL) may work, depending on constraint 2, below.
;      2) UF files for sites not 'known' to this code must label their quality-
;         controlled reflectivity data field name as 'CZ'.  This constraint is
;         implemented in the function common_utils/get_site_specific_z_volume.pro
;
;
; HISTORY
; -------
; 1/2014 by Bob Morris, GPM GV (SAIC)
;  - Created from polar2tmi.pro.
; 3/2014 by Bob Morris, GPM GV (SAIC)
;  - Modified to use GPROF-specific variable names.  Eliminated freezingHeight
;    and dataFlag variables not present in GPROF product.
;  - Added the full set of GR dual-polarization variables to the matchups.
;  - Changed the output netCDF file name convention to include satellite and
;    instrument IDs and character-type product versions.
;  - RR_MIN parameter is added for future use in thresholding GR rain rate, but
;    is not currently used.
; 4/7/2014 by Bob Morris, GPM GV (SAIC)
;  - Fixed bug in defining tocdf_gr_HID variables when have_gv_hid is false.
; 10/07/14  Morris/GPM GV/SAIC
; - Including gmi_params.inc in place of tmi_params.inc
; - Renamed NSPECIES to NSPECIES_GMI.
; 10/09/14  Morris/GPM GV/SAIC
; - Modified to allow either TMI or GMI GPROF products to be used.  Calls
;   read_2agprof_hdf5() in place of GMI-specific read_2agprofgmi_hdf5().  Still
;   needs more modifications to allow use of constellation satellite products.
; 11/06/14 by Bob Morris, GPM GV (SAIC)
;  - Added processing of GR RC and RP rainrate fields for version 1.1 file.
; 03/02/15 by Bob Morris, GPM GV (SAIC)
;  - Added FLAT_NCPATH parameter to control whether we generate the hierarchical
;    netCDF output file paths (default) or continue to write the netCDF files to
;    the "flat" directory defined by NC_DIR or NCGRIDS_ROOT+GEO_MATCH_NCDIR (if
;    FLAT_NCPATH is set to 1).
; 03/16/15 by Bob Morris, GPM GV (SAIC)
; - Changed the hard-coded assignment of the non-Z ufstruct field IDs to instead
;   use the field ID returned by get_site_specific_z_volume(), so that when a
;   substitution for our standard UF ID happens, the structure reflects the UF
;   field that actually exists in, and was read from, the UF file.
; 10/20/15 by Bob Morris, GPM GV (SAIC)
; - Changed the idx2A = WHERE() test string to just .GPROF to permit any
;   core/constellation satellite/instruments to be processed.
; 11/13/15 by Bob Morris, GPM GV (SAIC)
;  - Added DIR_BLOCK parameter and related processing of GR_blockage* variables
;    and their presence flags for version 1.11 file.
; 07/01/16 by Bob Morris, GPM GV (SAIC)
;  - Added processing of Tc and related Quality variables from 1C-R-XCAL files
;    for version 1.2 file.  Changed position of fields in satellite lines of
;    control file for this version.
; 01/05/21 by Todd Berendes UAH/ITSC
;  - Added new variables for V7 GMI data
; 4/6/22 by Todd Berendes UAH/ITSC
;  - Added new GR liquid and frozen water content fields
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

PRO skip_gr_events, lun, nsites
   line = ""
   FOR igv=0,nsites-1  DO BEGIN
     ; read and print the control file GR site ID, lat, lon, elev, filename, etc.
      READF, lun, line
      PRINT, igv+1, ": ", line
   ENDFOR
END

;*******************************************************************************

PRO polar2gmi_v7, control_file, range_threshold_km, GPM_ROOT=gpmroot,          $
               DIRGV=dirgv, NC_DIR=nc_dir, NC_NAME_ADD=ncnameadd,           $
               SCORES=run_scores, PLOT_PPIS=plot_PPIs, PLOT_BINS=plot_bins, $
               MARK_EDGES=mark_edges, DBZ_MIN=dBZ_min, RR_MIN=RR_min,       $
               GMI_RAIN_MIN=gmi_rain_min, FLAT_NCPATH=flat_ncpath,          $
               DIR_BLOCK=dir_block

IF KEYWORD_SET(plot_bins) THEN BEGIN
   reply = plot_bins_bailout()
   IF reply EQ 'Y' THEN plot_bins = 0
ENDIF

IF N_ELEMENTS( mark_edges ) EQ 1 THEN BEGIN
   IF mark_edges NE 0 THEN mark_edges=1
ENDIF ELSE mark_edges = 0

; check existence of blockage files if dir_block is specified
try_blockage = 0
IF N_ELEMENTS(dir_block) EQ 1 THEN BEGIN
   IF FILE_TEST(dir_block, /DIRECTORY) THEN BEGIN
     ; look up the list of site-specific subdirectories under dir_block
      sitepaths = FILE_SEARCH( dir_block, '*', /TEST_DIRECTORY, count=nd )
      IF nd EQ 0 THEN BEGIN
         message, "No site subdirs found under "+dir_block
      ENDIF ELSE BEGIN
         try_blockage = 1
         blkSites = file_basename(sitepaths)   ; strip list down to just site IDs
         IF KEYWORD_SET(verbose) THEN print, "Blockage subdirs: ", blkSites
      ENDELSE
   ENDIF ELSE message, "DIR_BLOCK directory does not exist: "+dir_block
ENDIF

; TAB 3/2/21 removed this line, caused compile error
;COMMON sample, start_sample, sample_range, num_range, NPIXEL_GMI, NSPECIES_GMI

; "Include" file for DATA_PRESENT, NO_DATA_PRESENT
@grid_def.inc
; "Include" file for GMI-product-specific parameters (i.e., NPIXEL_GMI):
@gmi_params.inc
; "Include" file for names, paths, etc.:
@environs_v7.inc
; "Include" file for special values in netCDF files: Z_BELOW_THRESH, etc.
@pr_params.inc

; set to a constant, pending extraction of override value "PPSversion" from
; the control file
GPROF_version = 'V00'

; Values for "have_somegridfield" flags: (now defined within grid_def.inc
; via INCLUDE mechanism, and reversed from previous values to align with C and
; IDL True/False interpretation of values 1 and 0)
;DATA_PRESENT = 1
;NO_DATA_PRESENT = 0  ; default fill value, defined in grid_def.inc and used in
                      ; gen_gprof_geo_match_netcdf_v7.pro


; ***************************** Local configuration ****************************

   ; where provided, override file path default values from environs.inc:
    in_base_dir =  GVDATA_ROOT ; default root dir for UF files
    IF N_ELEMENTS(dirgv)  EQ 1 THEN in_base_dir = dirgv

    IF N_ELEMENTS(gpmroot) EQ 1 THEN SUBSETS_ROOT = gpmroot

   ; the following is not used currently as this information should be in the
   ; control file entries as the partial path to the 2AGPROF files
;    IF N_ELEMENTS(dir2AGPROF) EQ 1 THEN DIR_2AGPROF = dir2AGPROF
    
    IF N_ELEMENTS(nc_dir)  EQ 1 THEN BEGIN
       NCGRIDSOUTDIR = nc_dir
    ENDIF ELSE BEGIN
       NCGRIDSOUTDIR = NCGRIDS_ROOT+GEO_MATCH_NCDIR
    ENDELSE

   ; tally number of reflectivity bins below this dBZ value in GR Z averages
    IF N_ELEMENTS(dBZ_min) NE 1 THEN BEGIN
       dBZ_min = 15.0   ; low-end GR cutoff, for now
       PRINT, "Assigning default value of 15 dBZ to DBZ_MIN for ground radar."
    ENDIF
   ; tally number of rain rate bins (mm/h) below this value in GMI rr averages
    IF N_ELEMENTS(gmi_rain_min) NE 1 THEN BEGIN
       GMI_RAIN_MIN = 0.01
       PRINT, "Assigning default value of 0.01 mm/h to GMI_RAIN_MIN."
    ENDIF
   ; tally number of DP rainrate bins (mm/h) below this value in GR RR averages
    IF N_ELEMENTS(RR_min) NE 1 THEN BEGIN
       RR_min = 0.01   ; low-end RR cutoff, for now
       PRINT, "Assigning default value of 0.01 mm/h to RR_MIN for ground radar."
    ENDIF

; ******************************************************************************


; will skip processing GMI points beyond this distance from a ground radar
rough_threshold = range_threshold_km * 1.1

; initialize the variables into which file records are read as strings
dataGMI = ''
dataGR = ''

; open and process control file, and generate the matchup data for the events

OPENR, lun0, control_file, ERROR=err, /GET_LUN
WHILE NOT (EOF(lun0)) DO BEGIN 

  ; get GMI filenames and count of GR file pathnames to do for an orbit
  ; - read the '|'-delimited input file record into a single string:
   READF, lun0, dataGMI

  ; parse dataGMI into its component fields: 2AGPROF file name, orbit number, 
  ; number of sites, YYMMDD, and GMI subset
   parsed=STRSPLIT( dataGMI, '|', /extract )
  ; get filenames as listed in/on the database/disk

;   idx2A = WHERE(STRPOS(parsed,'GPM.GMI.GPROF') GE 0, count2A)
   idx2A = WHERE(STRPOS(parsed,'.GPROF') GE 0, count2A)   ; allow anything now
   if count2A EQ 1 THEN origGprofFileName = STRTRIM(parsed[idx2A],2) $
                   ELSE origGprofFileName='no_2AGPROF_file'
  ; old control file had 2AGPROF filename at the beginning, now it's at the end
  ; followed by the 1CRXCAL filename.  Adjust other positions accordingly.
   IF idx2A GT 0 THEN ctloff=1 ELSE ctloff=0

   idx1C = WHERE(STRPOS(parsed,'.XCAL') GE 0, count1C)
   if count1C EQ 1 THEN BEGIN
      origXcalFileName = STRTRIM(parsed[idx1C],2)
      if origXcalFileName NE 'no_1CRXCAL_file' THEN have_1c=1 ELSE have_1c=0
   endif ELSE BEGIN
      origXcalFileName='no_1CRXCAL_file'
      have_1c=0
   endelse

   orbit = parsed[1-ctloff]
   nsites = FIX( parsed[2-ctloff] )
   IF (nsites LE 0 OR nsites GT 99) THEN BEGIN
      PRINT, "Illegal number of GR sites in control file: ", parsed[2+parseoffset]
      PRINT, "Line: ", dataGMI
      PRINT, "Quitting processing."
      GOTO, bailOut
   ENDIF
   IF ( origGprofFileName EQ 'no_2AGPROF_file' ) THEN BEGIN
      PRINT, ""
      PRINT, "ERROR finding 2AGPROF product file name in control file: ", control_file
      PRINT, "Line: ", dataGMI
      PRINT, "Skipping events for orbit = ", orbit
      skip_gr_events, lun0, nsites
      PRINT, ""
      GOTO, nextOrbit
   ENDIF
   DATESTAMP = parsed[3-ctloff]      ; in YYMMDD format
   subset = parsed[4-ctloff]
   IF N_ELEMENTS(parsed) GE 6 THEN BEGIN
      print, ''
      print, "Overriding GPROF_version with value from control file: ", parsed[5-ctloff]
      print, ''
      GPROF_version = parsed[5-ctloff]   ;control file includes GPROF_version
   ENDIF

;HELP, GPROF_version, origGprofFileName, nsites, ORBIT, DATESTAMP, SUBSET, $
;      origXcalFileName, have_1c
;STOP

;  add the well-known (or local) paths to get the fully-qualified file names
;  and check for their existence
   file_2AGPROF = SUBSETS_ROOT+"/"+origGprofFileName
   IF FILE_TEST( file_2AGPROF ) NE 1 THEN BEGIN
      PRINT, ""
      PRINT, "ERROR finding 2AGPROF product file: ", file_2AGPROF
      PRINT, "Skipping events for orbit = ", orbit
      skip_gr_events, lun0, nsites
      PRINT, ""
      GOTO, nextOrbit
   ENDIF
   IF have_1c THEN BEGIN
      file_1CRXCAL = SUBSETS_ROOT+"/"+origXcalFileName
      IF FILE_TEST( file_1CRXCAL ) NE 1 THEN BEGIN
         PRINT, ""
         PRINT, "ERROR finding 1C-R-XCAL product file: ", file_1CRXCAL
         PRINT, "Skipping Tc data processing for orbit = ", orbit
         PRINT, ""
         have_1c = 0
      ENDIF
   ENDIF

; store the file basenames in a string to be passed to gen_gprof_geo_match_netcdf_v7.pro()
   infileNameArr = STRARR(3)
   infileNameArr[0] = FILE_BASENAME(origGprofFileName)
   infileNameArr[1] = FILE_BASENAME(origXcalFileName)

; parse the 2AGPROF file pathname to get satelliteID, instrumentID
   parsedPath = STRSPLIT(origGprofFileName, '/', /extract )
   satelliteID = parsedPath[0]
   instrumentID = parsedPath[1]
; combine them for inclusion in the netCDF filename
   sat_instr = satelliteID + '.' + instrumentID + '.'


  ; generate the netcdf matchup file path

   matchup_file_version=0.0  ; give it a null value, for now
  ; Call gen_gprof_geo_match_netcdf_v7.pro with the option to only get current file version
  ; so that it can become part of the matchup file path/name
   throwaway = gen_gprof_geo_match_netcdf_v7( GEO_MATCH_VERS=matchup_file_version )

  ; separate version into integer and decimal parts, with 2 decimal places
   verarr=strsplit(string(matchup_file_version,FORMAT='(F0.2)'),'.',/extract)
  ; strip trailing zero from version string decimal part, if any
   verarr1_len = STRLEN(verarr[1])
   IF verarr1_len GT 1 and STRMID(verarr[1], verarr1_len-1, 1) EQ '0' $
      THEN verarr[1]=strmid(verarr[1], 0, verarr1_len-1)
  ; substitute an underscore for the decimal point in matchup_file_version
   verstr=verarr[0]+'_'+verarr[1]

   IF KEYWORD_SET(flat_ncpath) THEN BEGIN
      NC_OUTDIR = NCGRIDSOUTDIR
   ENDIF ELSE BEGIN
      NC_OUTDIR = NCGRIDSOUTDIR+'/'+satelliteID+'/'+instrumentID+'/2AGPROF/' $
                  +GPROF_version+'/'+verstr+'/20'+STRMID(DATESTAMP, 0, 2)  ; 4-digit Year
   ENDELSE


   status = read_2agprof_hdf5_v7( file_2AGPROF, /READ_ALL )

   s=SIZE(status, /TYPE)
   CASE s OF
      8 :         ; expected structure to be returned, just proceed
      2 : BEGIN
          IF ( status EQ -1 ) THEN BEGIN
            PRINT, ""
            PRINT, "ERROR reading fields from ", file_2AGPROF
            PRINT, "Skipping events for orbit = ", orbit
            skip_gr_events, lun0, nsites
            PRINT, ""
            GOTO, nextOrbit
          ENDIF ELSE message, "Unknown type returned from read_2agprofgmi_hdf5."
          END
       ELSE : message, "Passed argument type not an integer or a structure."
   ENDCASE


; extract pointer data fields into gmiLats and gmiLons arrays
   gmiLons = (*status.S1.ptr_datasets).Longitude
   gmiLats = (*status.S1.ptr_datasets).Latitude

;  extract pointer data fields into scLats and scLons arrays
   scLons =  (*status.S1.ptr_scStatus).SClongitude
   scLats =  (*status.S1.ptr_scStatus).SClatitude

;  extract scanTime fields 
   stYear = (*status.S1.ptr_ScanTime).Year
   stMonth = (*status.S1.ptr_ScanTime).Month
   stDayOfMonth = (*status.S1.ptr_ScanTime).DayOfMonth
   stHour = (*status.S1.ptr_ScanTime).Hour
   stMinute = (*status.S1.ptr_ScanTime).Minute
   stSecond = (*status.S1.ptr_ScanTime).Second

; NOTE THAT THE ARRAYS ARE IN (RAY,SCAN) COORDINATES.  NEED TO ACCOUNT FOR THIS
; WHEN ASSIGNING "gmi_master_idx" ARRAY INDICES.

; - get dimensions (#footprints, #scans) from gmiLons array
   s = SIZE(gmiLons, /DIMENSIONS)
   IF N_ELEMENTS(s) EQ 2 THEN BEGIN
      IF s[0] EQ status.s1.SWATHHEADER.NUMBERPIXELS THEN NPIXEL_GMI = s[0] $
        ELSE message, 'Mismatch in data array dimension NUMBERPIXELS.'
      IF s[1] EQ status.s1.SWATHHEADER.MAXIMUMNUMBERSCANSTOTAL $
        THEN NSCANS_GMI = s[1] $
        ELSE message, 'Mismatch in data array dimension NUMBERSCANS.', /INFO
NSCANS_GMI = s[1]
   ENDIF ELSE message, "Don't have a 2-D array for Longitude, quitting."

; extract pointer data fields into instrument data arrays
   pixelStatus = (*status.S1.ptr_datasets).pixelStatus
   surfaceType = (*status.S1.ptr_datasets).surfaceTypeIndex
   surfacePrecipitation = (*status.S1.ptr_datasets).surfacePrecipitation
   PoP = (*status.S1.ptr_datasets).probabilityOfPrecip
   
   ; additional variables for GPROf VN version 2.0 files
   frozenPrecipitation = (*status.S1.ptr_datasets).frozenPrecipitation
   convectivePrecipitation = (*status.S1.ptr_datasets).convectivePrecipitation
   rainWaterPath = (*status.S1.ptr_datasets).rainWaterPath
   cloudWaterPath = (*status.S1.ptr_datasets).cloudWaterPath
   iceWaterPath = (*status.S1.ptr_datasets).iceWaterPath
   
   is_version_7 = 1
   
   ; new V7 variables for GPROf VN version 2.0 files
   stSunLocalTime = (*status.S1.ptr_datasets).sunLocalTime
   airmassLiftIndex = (*status.S1.ptr_datasets).airmassLiftIndex
   precipitationYesNoFlag = (*status.S1.ptr_datasets).precipitationYesNoFlag
   if (typename(stSunLocalTime) eq 'STRING') then begin
   		IF ( stSunLocalTime EQ 'N/A' ) THEN BEGIN
   			is_version_7 = 0
   		endif
   endif

  ; get the 1CRXCAL Tc and Quality variables if file is available.  Tc values
  ; for all channels for a given instrument may be distributed among more than
  ; one swath in the data file and the structure returned from reading the file.
  ; We need to find the Tc values for each swath inside nested substructures in
  ; the returned structure from read_1c_any_mi_hdf5().  The tag name(s) for the
  ; nested structure(s) is the name of the swath, e.g., "S1", "S2", and the
  ; names of the swaths are given in a string array in the structure whose tag
  ; name is 'SWATHS'.  See read_1c_any_mi_hdf5.pro if there is any confusion.

   IF have_1c THEN BEGIN
      data1c = read_1c_any_mi_hdf5( file_1CRXCAL )
     ; get the number and names of the tags in the structure
      ntags1c = N_TAGS(data1c)
      datatags1c = TAG_NAMES(data1c)
     ; get the number of swath names and matching nested data structures
     ; contained in the data1c structure
      nsw1c = N_ELEMENTS(data1c.swaths)
     ; find the nested substructure for each swath name and get its Tc
     ; data array information
      nchannels = INTARR(nsw1c)
      for i=0,nsw1c-1 do begin
        ; find the index number of the tag in the structure whose name is
        ; the same as swath "i"
         idxsw = WHERE( STRMATCH(datatags1c, data1c.swaths[i]) EQ 1, nmatch)
         IF nmatch NE 1 THEN $
            message, "Error extracting swath data from 1C data structure."
        ; get the Tc array dimensions for this swath from its nested substructure,
        ; where we address the nested structure by index number rather than by tag
         tcdims = SIZE( (*data1c.(idxsw).PTR_DATASETS).Tc )
         IF tcdims[0] NE 3 THEN message, "Wrong number of dimensions for Tc array!"
         nchannels[i] = tcdims[1]
        ; set up and do some checking of Tc array dimensions between swaths
         if i EQ 0 THEN BEGIN
            npixlast = tcdims[2]
            nscanslast = tcdims[3]
         endif else begin
            if ( npixlast NE tcdims[2] OR nscanslast NE tcdims[3] ) THEN $
               message, "Mismatched Tc ray,scan dimensions between swaths!"
         endelse
      endfor

      nchan1c = TOTAL(nchannels)    ; number of channels in all swaths

     ; define arrays sized to hold the Tc and Quality
     ; values for all swaths/channels
      Tc_all = FLTARR( nchan1c, npixlast, nscanslast )
      Quality_all = INTARR( nchan1c, npixlast, nscanslast )

     ; define arrays sized to hold the latitude and longitude
     ; values for all swaths
      Lat1c_all = FLTARR( nsw1c, npixlast, nscanslast )
      Lon1c_all = Lat1c_all

     ; define a STRING array to hold the names of all the channels
      Tc_Names = STRARR( nchan1c )

     ; step through the swaths' data and populate the combined data arrays
      idxchanstart = 0  ; first dimension's starting value for current swath's channel
      idxchanend = TOTAL(nchannels, /CUMULATIVE)  ; first dimension's next start
      for i=0,nsw1c-1 do begin
         idxsw = WHERE( STRMATCH(datatags1c, data1c.swaths[i]) EQ 1, nmatch)
        ; get and assign swath's lat/lon data into their merged arrays
         Lat1c_all[i,*,*] = (*data1c.(idxsw).PTR_DATASETS).LATITUDE
         Lon1c_all[i,*,*] = (*data1c.(idxsw).PTR_DATASETS).LONGITUDE
        ; get the Tc array and longnames string and the Quality array for this swath
         Tc = (*data1c.(idxsw).PTR_DATASETS).Tc
         Qual = (*data1c.(idxsw).PTR_DATASETS).Quality
         tcNamesStr = (*data1c.(idxsw).PTR_DATASETS).TC_LONGNAME
        ; assign swath's data into the merged arrays
         Tc_all[idxchanstart:idxchanend[i]-1, *, *] = Tc
        ; copy the in-common Quality values for the set of channels to each
        ; channel's slot in the merged array so that every Tc value has a
        ; corresponding Quality value
         for ichan = idxchanstart, idxchanend[i]-1 do Quality_all[ichan, *, *] = Qual
        ; call extract_tc_channel_names to assign TcNames for this swath's channels
         tcNameStatus = extract_tc_channel_names(Tc_Names, tcNamesStr, $
                                                 idxchanstart, nchannels[i])
         idxchanstart = idxchanend[i]  ; reset start channel for next swath
      endfor

     ; convert the unsigned byte Quality values to their signed value to match
     ; up to the meanings defined in the GPM PPS Products File Specification,
     ; as IDL treats all byte values as unsigned (0-255) rather than signed
     ; (-128 to 127)
      idx2sign = WHERE(Quality_all GT 127, n2sign)
      if n2sign GT 0 then Quality_all[idx2sign] = Quality_all[idx2sign]-256

     ; find the point locations where lat and lon are non-missing for all 1C swaths
      minlats = MIN(Lat1c_all, DIMENSION=1)
      minlons = MIN(Lon1c_all, DIMENSION=1)
      ; TAB 6/15/21 added count check on lat/lon check to handle missing values
      idxllgood=WHERE(minlats GT -90.0 and minlons GE -180.0, idxcount)  ; NOT missing
      IF idxcount eq 0 THEN BEGIN
      	PRINT, "Warning: Lat/lons are all missing for orbit = ", orbit, " skipping events..."
        skip_gr_events, lun0, nsites
      	GOTO, nextOrbit
      ENDIF

      llidx = array_indices(minlons, IDXLLGOOD)
     ; grab the first good point and make sure its lat/lon are "the same" between
     ; the 2AGPROF and the 1CRXCAL product.  If not, then bail out, subsets'
     ; scans are not the same.  We don't yet try to "line up" the 2A and 1C.
      ray1 = llidx[0,0]
      scan1 = llidx[1,0]
      lat1c2chk = Lat1c_all[0,ray1,scan1]
      lon1c2chk = Lon1c_all[0,ray1,scan1]
      lat2a2chk = gmiLats[ray1,scan1]
      lon2a2chk = gmiLons[ray1,scan1]
     ; get the larger of the lat and lon difference between 1C and 2A
      bigdiff = ABS(lat1c2chk-lat2a2chk) > ABS(lon1c2chk-lon2a2chk)
     ; if 0.1 degrees or less difference, call them "the same", otherwise
     ; bail out of 1C processing
      IF bigdiff GT 0.1 THEN BEGIN
         message, "Subsets for 2AGPROF and 1CRXCAL do not line up in lat/lon:", /INFO
         help, lat1c2chk, lat2a2chk, lon1c2chk, lon2a2chk
         print, "Disabling 1C brightness temperature processing." & print, ''
         have_1c = 0
      ENDIF
   ENDIF


   lastsite = ""
FOR igv=0,nsites-1  DO BEGIN
  ; read and parse the control file GR site ID, lat, lon, elev, filename, etc.
  ;  - read each overpassed site's information as a '|'-delimited string
   READF, lun0, dataGR
  ; PRINT, igv+1, ": ", dataGR

  ; parse dataGR into its component fields: event_num, orbit number, siteID,
  ; overpass datetime, time in ticks, site lat, site lon, site elev,
  ; 1CUF file unique pathname

   freezing_level = -9999.

   parsed=STRSPLIT( dataGR, '|', count=nGVfields, /extract )
   CASE nGVfields OF
     10 : BEGIN   ; legacy control file format
           event_num = LONG( parsed[0] )
           orbit = parsed[1]
           siteID = parsed[2]    ; GPMGV siteID
           gmi_dtime = parsed[3]
           gmi_dtime_ticks = parsed[4]
           siteLat = FLOAT( parsed[5] )
           siteLon = FLOAT( parsed[6] )
           siteElev = FLOAT( parsed[7] )
           origUFName = parsed[8]  ; filename as listed in/on the database/disk
           freezing_level = parsed[9]
         END
     9 : BEGIN   ; legacy control file format
           event_num = LONG( parsed[0] )
           orbit = parsed[1]
           siteID = parsed[2]    ; GPMGV siteID
           gmi_dtime = parsed[3]
           gmi_dtime_ticks = parsed[4]
           siteLat = FLOAT( parsed[5] )
           siteLon = FLOAT( parsed[6] )
           siteElev = FLOAT( parsed[7] )
           origUFName = parsed[8]  ; filename as listed in/on the database/disk
         END
     6 : BEGIN   ; streamlined control file format, already have orbit #
           siteID = parsed[0]    ; GPMGV siteID
           gmi_dtime = parsed[1]
           gmi_dtime_ticks = ticks_from_datetime( gmi_dtime )
           IF STRING(gmi_dtime_ticks) EQ "Bad Datetime" THEN BEGIN
              print, ""
              print, "Bad overpass datetime field in control file:"
              print, dataGR
              print, "Skipping site event." & print, ""
              GOTO, nextGVfile
           END
           siteLat = FLOAT( parsed[2] )
           siteLon = FLOAT( parsed[3] )
           siteElev = FLOAT( parsed[4] )
           origUFName = parsed[5]  ; filename as listed in/on the database/disk
         END
     ELSE : BEGIN
           print, ""
           print, "Incorrect number of GR-type fields in control file:"
           print, dataGR
           print, "Skipping site event." & print, ""
           GOTO, nextGVfile
         END
   ENDCASE

   PRINT, ""
   PRINT, '----------------------------------------------------------------'
   PRINT, ""

  ; assume that if siteElev value is 4.0 or more, its units are m - km needed
   IF (siteElev GE 4.0) THEN siteElev=siteElev/1000.
  ; don't allow below-sea-level siteElev to be below -400 m (-0.4 km) (Dead Sea)
   IF (siteElev LT -0.4) THEN siteElev=( (siteElev/1000.) > (-0.4) )

  ; adding the well-known (or local) path to get the fully-qualified file name:
   file_1CUF = in_base_dir + "/" + origUFName
   base_1CUF = file_basename(file_1CUF)
   IF ( base_1CUF eq 'no_1CUF_file' ) THEN BEGIN
      PRINT, "No 1CUF file for orbit = ", orbit, ", site = ", $
              siteID, ", skipping."
      GOTO, nextGVfile
   ENDIF
   IF ( siteID EQ lastsite ) THEN BEGIN
      PRINT, "Multiple 1CUF files for orbit = ", orbit, ", site = ", $
              siteID, ", skipping."
      lastsite = siteID
      GOTO, nextGVfile
   ENDIF
   lastsite = siteID

; store the file basename in the string array to be passed to gen_gprgen_gprof_geo_match_netcdf_v7.pro()
   infileNameArr[2] = base_1CUF

   PRINT, igv+1, ": ", gmi_dtime, "  ", siteID, siteLat, siteLon
;   PRINT, igv+1, ": ", file_1CUF

  ; initialize a gv-centered map projection for the ll<->xy transformations:
   sMap = MAP_PROJ_INIT( 'Azimuthal Equidistant', center_latitude=siteLat, $
                         center_longitude=siteLon )
  ; GMI-site latitude and longitude differences for coarse filter
   max_deg_lat = rough_threshold / 111.1
   max_deg_lon = rough_threshold / (cos(!DTOR*siteLat) * 111.1 )

  ; copy/unzip/open the UF file and read the entire volume scan into an
  ;   RSL_in_IDL radar structure, and then close UF file and delete copy:

   status=get_rsl_radar(file_1CUF, radar)
   IF ( status NE 0 )  THEN BEGIN
      PRINT, ""
      PRINT, "Error reading radar structure from file ", file_1CUF
      PRINT, ""
      GOTO, nextGVfile
   ENDIF

  ; set up the structure holding the UF IDs for the fields we find in this file
  ; - the default values in this structure must be coordinated with those
  ;   defined in gen_gprof_geo_match_netcdf_v7.pro
   ufstruct={ CZ_ID:    'Unspecified', $
              ZDR_ID  : 'Unspecified', $
              KDP_ID  : 'Unspecified', $
              RHOHV_ID: 'Unspecified', $
              RC_ID:    'Unspecified', $
              RP_ID:    'Unspecified', $
              RR_ID:    'Unspecified', $
              HID_ID:   'Unspecified', $
              D0_ID:    'Unspecified', $
              NW_ID:    'Unspecified', $
              MW_ID:    'Unspecified', $
              MI_ID:    'Unspecified' }

  ; need to define this parameter, we don't know whether we can compute it yet
   have_gv_blockage = 0

  ; check existence of blockage files for this siteID if dir_block is specified
   do_blockage = 0
   IF try_blockage EQ 1 THEN BEGIN
      IF TOTAL( STRMATCH(blkSites, siteID) ) EQ 1 THEN BEGIN
        ; grab the pathnames of blockage files for this site, if any
         blkfiles = FILE_SEARCH( dir_block+'/'+siteID, $
                                 siteID+".BeamBlockage_*.sav", count=nf )
         IF nf EQ 0 THEN BEGIN
            message, "No BeamBlockage .sav files found under " $
                     +dir_block+'/'+siteID
         ENDIF ELSE BEGIN
            do_blockage = 1
            IF KEYWORD_SET(verbose) THEN print, "Blockage files: ", blkfiles
         ENDELSE
      ENDIF ELSE BEGIN
         message,"No blockage files for "+siteID+", set blockage to missing.", $
                  /INFO
         print, "Available blockage sites: ", blkSites
      ENDELSE
   ENDIF

  ; find the volume with the correct reflectivity field for the GV site/source,
  ;   and the ID of the field itself
   gv_z_field = ''
   z_vol_num = get_site_specific_z_volume( siteID, radar, gv_z_field )
   IF ( z_vol_num LT 0 )  THEN BEGIN
      PRINT, ""
      PRINT, "Error finding Z volume in radar structure from file: ", file_1CUF
      PRINT, ""
      GOTO, nextGVfile
   ENDIF ELSE ufstruct.CZ_ID = gv_z_field

  ; find the volume with the Zdr field for the GV site/source
   gv_zdr_field = ''
   zdr_field2get = 'DR'
   zdr_vol_num = get_site_specific_z_volume( siteID, radar, gv_zdr_field, $
                                            UF_FIELD=zdr_field2get )
   IF ( zdr_vol_num LT 0 )  THEN BEGIN
      PRINT, ""
      PRINT, "No 'DR' volume in radar structure from file: ", file_1CUF
      PRINT, ""
      have_gv_zdr = 0
   ENDIF ELSE BEGIN
      have_gv_zdr = 1
      ufstruct.ZDR_ID = gv_zdr_field
      DR_KD_MISSING = (radar_dp_parameters()).DR_KD_MISSING
   ENDELSE

  ; find the volume with the Kdp field for the GV site/source
   gv_kdp_field = ''
   kdp_field2get = 'KD'
   kdp_vol_num = get_site_specific_z_volume( siteID, radar, gv_kdp_field, $
                                            UF_FIELD=kdp_field2get )
   IF ( kdp_vol_num LT 0 )  THEN BEGIN
      PRINT, ""
      PRINT, "No 'KD' volume in radar structure from file: ", file_1CUF
      PRINT, ""
      have_gv_kdp = 0
   ENDIF ELSE BEGIN
      have_gv_kdp = 1
      ufstruct.KDP_ID = gv_kdp_field
      DR_KD_MISSING = (radar_dp_parameters()).DR_KD_MISSING
   ENDELSE

  ; find the volume with the RHOhv field for the GV site/source
   gv_rhohv_field = ''
   rhohv_field2get = 'RH'
   rhohv_vol_num = get_site_specific_z_volume( siteID, radar, gv_rhohv_field, $
                                            UF_FIELD=rhohv_field2get )
   IF ( rhohv_vol_num LT 0 )  THEN BEGIN
      PRINT, ""
      PRINT, "No 'RH' volume in radar structure from file: ", file_1CUF
      PRINT, ""
      have_gv_rhohv = 0
   ENDIF ELSE BEGIN
      have_gv_rhohv = 1
      ufstruct.RHOHV_ID = gv_rhohv_field
   ENDELSE

  ; find the volume with the Cifelli rainrate field for the GV site/source
   gv_rc_field = ''
   rc_field2get = 'RC'
   rc_vol_num = get_site_specific_z_volume( siteID, radar, gv_rc_field, $
                                            UF_FIELD=rc_field2get )
   IF ( rc_vol_num LT 0 )  THEN BEGIN
      PRINT, ""
      PRINT, "No 'RC' volume in radar structure from file: ", file_1CUF
      PRINT, ""
      have_gv_rc = 0
   ENDIF ELSE BEGIN
      have_gv_rc = 1
      ufstruct.RC_ID = gv_rc_field
   ENDELSE

  ; find the volume with the PolZR rainrate field for the GV site/source
   gv_rp_field = ''
   rp_field2get = 'RP'
   rp_vol_num = get_site_specific_z_volume( siteID, radar, gv_rp_field, $
                                            UF_FIELD=rp_field2get )
   IF ( rp_vol_num LT 0 )  THEN BEGIN
      PRINT, ""
      PRINT, "No 'RP' volume in radar structure from file: ", file_1CUF
      PRINT, ""
      have_gv_rp = 0
   ENDIF ELSE BEGIN
      have_gv_rp = 1
      ufstruct.RP_ID = gv_rp_field
   ENDELSE

  ; find the volume with the DROPS rainrate field for the GV site/source
   gv_rr_field = ''
   rr_field2get = 'RR'
   rr_vol_num = get_site_specific_z_volume( siteID, radar, gv_rr_field, $
                                            UF_FIELD=rr_field2get )
   IF ( rr_vol_num LT 0 )  THEN BEGIN
      PRINT, ""
      PRINT, "No 'RR' volume in radar structure from file: ", file_1CUF
      PRINT, ""
      have_gv_rr = 0
   ENDIF ELSE BEGIN
      have_gv_rr = 1
      ufstruct.RR_ID = gv_rr_field
   ENDELSE

  ; find the volume with the HID field for the GV site/source
   gv_hid_field = ''
   hid_field2get = 'FH'
   hid_vol_num = get_site_specific_z_volume( siteID, radar, gv_hid_field, $
                                             UF_FIELD=hid_field2get )
   IF ( hid_vol_num LT 0 )  THEN BEGIN
      PRINT, ""
      PRINT, "No 'FH' volume in radar structure from file: ", file_1CUF
      PRINT, ""
      have_gv_hid = 0
   ENDIF ELSE BEGIN
      have_gv_hid = 1
      ufstruct.HID_ID = gv_hid_field
     ; need #categories for netcdf dimensioning of tocdf_gr_dp_hid
      HID_structs = radar_dp_parameters()
      n_hid_cats = HID_structs.n_hid_cats
   ENDELSE

  ; find the volume with the D0 field for the GV site/source
   gv_dzero_field = ''
   dzero_field2get = 'D0'
   dzero_vol_num = get_site_specific_z_volume( siteID, radar, gv_dzero_field, $
                                               UF_FIELD=dzero_field2get )
   IF ( dzero_vol_num LT 0 )  THEN BEGIN
      PRINT, ""
      PRINT, "No 'D0' volume in radar structure from file: ", file_1CUF
      PRINT, ""
      have_gv_dzero = 0
   ENDIF ELSE BEGIN
      have_gv_dzero = 1
      ufstruct.D0_ID = gv_dzero_field
   ENDELSE

  ; find the volume with the Nw field for the GV site/source
   gv_nw_field = ''
   nw_field2get = 'NW'
   nw_vol_num = get_site_specific_z_volume( siteID, radar, gv_nw_field, $
                                            UF_FIELD=nw_field2get )
   IF ( nw_vol_num LT 0 )  THEN BEGIN
      PRINT, ""
      PRINT, "No 'NW' volume in radar structure from file: ", file_1CUF
      PRINT, ""
      have_gv_nw = 0
   ENDIF ELSE BEGIN
      have_gv_nw = 1
      ufstruct.NW_ID = gv_nw_field
   ENDELSE

  ; TAB 4/6/22 added new GR liquid and frozen water content fields
  ; find the volume with the Mw field for the GV site/source
   gv_mw_field = ''
   mw_field2get = 'MW'
   mw_vol_num = get_site_specific_z_volume( siteID, radar, gv_mw_field, $
                                            UF_FIELD=mw_field2get )
   IF ( mw_vol_num LT 0 )  THEN BEGIN
      PRINT, ""
      PRINT, "No 'MW' volume in radar structure from file: ", file_1CUF
      PRINT, ""
      have_gv_mw = 0
   ENDIF ELSE BEGIN
      have_gv_mw = 1
      ufstruct.MW_ID = gv_mw_field
   ENDELSE

  ; find the volume with the Mi field for the GV site/source
   gv_mi_field = ''
   mi_field2get = 'MI'
   mi_vol_num = get_site_specific_z_volume( siteID, radar, gv_mi_field, $
                                            UF_FIELD=mi_field2get )
   IF ( mi_vol_num LT 0 )  THEN BEGIN
      PRINT, ""
      PRINT, "No 'MI' volume in radar structure from file: ", file_1CUF
      PRINT, ""
      have_gv_mi = 0
   ENDIF ELSE BEGIN
      have_gv_mi = 1
      ufstruct.MI_ID = gv_mi_field
   ENDELSE

  ; get the number of elevation sweeps in the vol, and the array of elev angles
   num_elevations = get_sweep_elevs( z_vol_num, radar, elev_angle )

  ; make a copy of the array of elevations, from which we eliminate any
  ;   duplicate tilt angles for subsequent data processing/output
   uniq_elev_angle = elev_angle
   idx_uniq_elevs = UNIQ_SWEEPS(elev_angle, uniq_elev_angle)

   tocdf_elev_angle = elev_angle[idx_uniq_elevs]
   num_elevations_out = N_ELEMENTS(tocdf_elev_angle)
   ; TAB 6/15/21, fix for some bad files in May/June 2015
   good_ind = where (elev_angle gt 0, good_cnt)
   IF good_cnt eq 0 THEN BEGIN
      PRINT, "Error: Elevation angles are all negative for orbit = ", orbit, ", site = ", $
              siteID, ", skipping."
      GOTO, nextGVfile
   ENDIF
   IF num_elevations NE num_elevations_out THEN BEGIN
      print, ""
      print, "Duplicate sweep elevations ignored!"
      print, "Original sweep elevations:"
      print, elev_angle
      print, "Unique sweep elevations to be processed/output"
      print, tocdf_elev_angle
   ENDIF

   IF do_blockage THEN BEGIN
     ; define the list of elevations that have blockage files available
     ; according to their fixed strings in filename convention
      blkgElev_str = [ '00.50', '00.90', '01.30', '01.45', '01.50', '01.80', $
                       '02.40', '02.50', '03.10', '03.35', '03.50', '04.00', $
                       '04.30', '04.50', '05.10', '05.25', '06.00', '06.20', $
                       '06.40', '07.50', '08.00', '08.70', '09.90', '10.00', $
                       '12.00', '12.50', '14.00', '14.60', '15.60', '16.70', $
                       '19.50' ]
     ; numerical version of the above elevations
      blockageElevs = FLOAT(blkgElev_str)

     ; test the list of elevation angles against the available blockage levels
     ; if attempting to compute blockage, and save the file pathname of the
     ; matching blockage level for each scanned elevation
      BlockFileBySweep = STRARR(num_elevations_out)
      for iswpblk = 0, num_elevations_out-1 do begin
       ; find the nearest fixed angle to this measured sweep elevation
        ; -- for now we assume it's close enough to be valid
         nearest = -1L   ; array index of the nearest fixed angle
         diffmin = MIN( ABS(blockageElevs - tocdf_elev_angle[iswpblk]), nearest )
        ; sanity check
         thisdiff = ABS(blockageElevs[nearest] - tocdf_elev_angle[iswpblk])
         if thisdiff GT 0.5 THEN BEGIN
            print, "Elevation angle difference too large: "+STRING(thisdiff)
            print, "Scanned Elevation Angle: ", tocdf_elev_angle[iswpblk]
            do_blockage = 0        ; disable blockage computations
            help, blockageElevs
            help, do_blockage
;            print, 'Enter .CONTINUE command to proceed, .RESET to quit:'
;            stop
         endif ELSE BEGIN
            BlockFileBySweep[iswpblk] = dir_block + '/' + siteid + '/' $
                    + siteID + ".BeamBlockage_" + blkgElev_str[nearest] + ".sav"
         endelse
      endfor
     ; check that at least the first sweep's blockage file exists. If not, then
     ; halt and disable blockage checking
      IF FILE_TEST(BlockFileBySweep[0]) NE 1 THEN BEGIN
         print, "Cannot find first sweep blockage file: ", BlockFileBySweep[0]
         do_blockage = 0        ; disable blockage computations
         help, do_blockage
;         stop
      ENDIF
   ENDIF

  ; precompute cos(elev) for later repeated use
   cos_elev_angle = COS( tocdf_elev_angle * !DTOR )

  ; Get the times of the first ray in each sweep -- text_sweep_times will be
  ;   formatted as YYYY-MM-DD hh:mm:ss, e.g., '2008-07-09 00:10:56'
   num_times = get_sweep_times( z_vol_num, radar, dtimestruc )
   text_sweep_times = dtimestruc.textdtime  ; STRING array, human-readable
   ticks_sweep_times = dtimestruc.ticks     ; DOUBLE array, time in unix ticks
   IF num_elevations NE num_elevations_out THEN BEGIN
      ticks_sweep_times = ticks_sweep_times[idx_uniq_elevs]
      text_sweep_times =  text_sweep_times[idx_uniq_elevs]
   ENDIF

  ; Determine an upper limit to how many GMI footprints fall inside the analysis
  ;   area, so that we can hold x, y, and various z values for each element to
  ;   analyze.  We give the GMI a 5km resolution and use this nominal resolution
  ;   to figure out how many of these are required to cover the in-range area.

   grid_area_km = rough_threshold * rough_threshold  ; could use area of circle
   max_gmi_fp = grid_area_km / 5.0

  ; Create temp array of GMI (ray, scan) 1-D index locators for in-range points.
  ;   Use flag values of -1 for 'bogus' GMI points (out-of-range GMI footprints
  ;   just adjacent to the first/last in-range point of the scan), or -2 for
  ;   off-GMI-scan-edge but still-in-range points.  These bogus points will then
  ;   totally enclose the set of in-range, in-scan points and allow gridding of
  ;   the in-range dataset to a regular grid using a nearest-neighbor analysis,
  ;   assuring that the bounds of the in-range data are preserved (this gridding
  ;   in not needed or done within the current analysis).
   gmi_master_idx = LONARR(max_gmi_fp)
   gmi_master_idx[*] = -99L

  ; Create temp array used to flag whether there are ANY above-threshold GMI bins
  ; in the ray.  If none, we'll skip the time-consuming GR LUT computations.
   gmi_echoes = BYTARR(max_gmi_fp)
   gmi_echoes[*] = 0B             ; initialize to zero (skip the GMI ray)

  ; Create temp arrays to hold lat/lon of all GMI footprints to be analyzed,
  ;   including those extrapolated to mark the edge of the scan
   gmi_lon_sfc = FLTARR(max_gmi_fp)
   gmi_lat_sfc = gmi_lon_sfc

  ; ditto, but surface x and y
   x_sfc = FLTARR(max_gmi_fp)
   y_sfc = x_sfc

  ; create temp subarrays with additional dimension num_elevations_out to hold
  ;   parallax-adjusted GMI point X,Y and lon/lat coordinates, and GMI corner X,Ys
   gmi_x_center = FLTARR(max_gmi_fp, num_elevations_out)
   gmi_y_center = gmi_x_center
   gmi_x_corners = FLTARR(4, max_gmi_fp, num_elevations_out)
   gmi_y_corners = gmi_x_corners
  ; holds lon/lat array returned by MAP_PROJ_INVERSE()
   gmi_lon_lat = DBLARR(2, max_gmi_fp, num_elevations_out)

  ; define multi-level arrays of x and y coordinates to hold the at-surface
  ; x and y GMI coordinates replicated to each level, for use in VPR case of
  ; call to compute_mean_blockage().  Fill in polar2gmi_resampling ielev loop
   IF do_blockage THEN BEGIN
      sfc_x_center = gmi_x_center
      sfc_y_center = gmi_x_center
   ENDIF

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

  ; GEO-Preprocess the GMI data, extracting rays that intersect this radar volume
  ; within the specified range threshold, and computing footprint x,y corner
  ; coordinates and adjusted center lat/lon at each of the intersection sweep
  ; intersection heights, taking into account the parallax of the GMI rays.
  ; (Optionally) surround the GMI footprints within the range threshold with a border
  ; of "bogus" tagged GMI points to facilitate any future gridding of the data.
  ; Algorithm assumes that GMI footprints are contiguous, non-overlapping,
  ; and quasi-rectangular in their native ray,scan coordinates, and that the PR
  ; middle ray of the scan is nadir-pointing (zero roll/pitch of satellite).

  ; First, find scans with any point within range of the radar volume, roughly
   start_scan = 0 & end_scan = 0 & nscans2do = 0
   start_found = 0
   FOR scan_num = 0,NSCANS_GMI-1  DO BEGIN
      found_one = 0
      FOR ray_num = 0,NPIXEL_GMI-1  DO BEGIN
         ; Compute distance between GV radar and GMI sample lats/lons using
         ;   crude, fast algorithm
         IF ( ABS(gmiLons[ray_num,scan_num]-siteLon) LT max_deg_lon ) AND $
            ( ABS(gmiLats[ray_num,scan_num]-siteLat) LT max_deg_lat ) AND $
            ABS(gmiLats[ray_num,scan_num]) LE 90.0 AND $
            ABS(gmiLons[ray_num,scan_num]) LE 180.0 THEN BEGIN
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
  ; Populate arrays holding 'exact' GMI at-surface X and Y and range values for
  ; the in-range subset of scans.  THESE ARE NOT WRITTEN TO NETCDF FILE - YET.
   XY_km = map_proj_forward( gmiLons[*,start_scan:end_scan], $
                             gmiLats[*,start_scan:end_scan], $
                             map_structure=smap ) / 1000.
   gmi_x0 = XY_km[0,*]
   gmi_y0 = XY_km[1,*]
   gmi_x0 = REFORM( gmi_x0, NPIXEL_GMI, nscans2do, /OVERWRITE )
   gmi_y0 = REFORM( gmi_y0, NPIXEL_GMI, nscans2do, /OVERWRITE )
   precise_range = SQRT( gmi_x0^2 + gmi_y0^2 )
 
   numGMIrays = 0      ; number of in-range, scan-edge, and range-adjacent points
   numGMI_inrange = 0   ; number of in-range-only points found
  ; Variables used to find 'farthest from nadir' in-range GMI footprint:
   maxrayidx = 0
   minrayidx = NPIXEL_GMI-1

;-------------------------------------------------------------------------------
  ; Identify actual GMI points within range of the radar, actual GMI points just
  ; off the edge of the range cutoff, and extrapolated GMI points along the edge
  ; of the scans but within range of the radar.  Tag each point as to these 3
  ; types, and compute parallax-corrected x,y and lat/lon coordinates for these
  ; points at GMI ray's intersection of each sweep elevation.  Compute GMI
  ; footprint corner x,y's for the first type of points (actual GMI points
  ; within the cutoff range).

  ; flag for adding 'bogus' point if in-range at edge of scan GMI (2), or just
  ;   beyond max_ranges[elev] (-1), or just a regular, in-range point (1):
   action2do = 0  ; default -- do nothing
   
   ; TAB new processing for scStatus and scanTime variables
   ; allocate memory for temporary arrays
   ; extract pointer data fields into gmiLats and gmiLons arrays
   tmp_scLons =  MAKE_ARRAY(NPIXEL_GMI, NSCANS_GMI, /float, VALUE=FLOAT_RANGE_EDGE)
   tmp_scLats =  MAKE_ARRAY(NPIXEL_GMI, NSCANS_GMI, /float, VALUE=FLOAT_RANGE_EDGE)

   tmp_timeGMIscan = MAKE_ARRAY(NPIXEL_GMI, NSCANS_GMI, /float, VALUE=FLOAT_RANGE_EDGE)
   tmp_stSunLocalTime = MAKE_ARRAY(NPIXEL_GMI, NSCANS_GMI, /float, VALUE=FLOAT_RANGE_EDGE)

   ; populate pixel/scan arrays with scan values
   FOR scan_num = 0,NSCANS_GMI-1  DO BEGIN
   	  ; create scan time date/time string "YYYY-MM-DD hh:mm:ss"
   	  str=string(stYear[scan_num],stMonth[scan_num],stDayOfMonth[scan_num], $
         stHour[scan_num], stMinute[scan_num], stSecond[scan_num], $
         format='%4d-%02d-%02d %02d:%02d:%02d')
      ;print, 'scan time: ',str
      ; need to convert scan time date to seconds since 1970
   	  scantime = ticks_from_datetime(str)
      ;print, 'scan time secs since 1970: ', scantime
   	  
      FOR ray_num = 0,NPIXEL_GMI-1  DO BEGIN
      	  tmp_scLons[ray_num,scan_num] = scLons[scan_num]
      	  tmp_scLats[ray_num,scan_num] = scLats[scan_num]
   		  
   		  ; need to convert scan time date to seconds since 1970
   		  tmp_timeGMIscan[ray_num,scan_num] = scantime
   		  
; TAB new in V7, uncomment this when V7 is available
		  if ( is_version_7 eq 1 ) then begin
   		  		tmp_stSunLocalTime[ray_num,scan_num] = stSunLocalTime[scan_num]
   		  endif   		  
	  ENDFOR
   ENDFOR   

   FOR scan_num = start_scan,end_scan  DO BEGIN
      subset_scan_num = scan_num - start_scan

      FOR ray_num = 0,NPIXEL_GMI-1  DO BEGIN
      
      	; new variables from scStatus and scanTime
      	
      	
        ; Set flag value according to where the GMI footprint lies w.r.t. the GV radar.
         action2do = 0  ; default -- do nothing

        ; is to-sfc projection of any point along GMI ray within range of GR volume?
         IF ( precise_range[ray_num,subset_scan_num] LE max_ranges[0] ) THEN BEGIN
           ; add point to subarrays for GMI 2D index and for footprint lat/lon & x,y
           ; - MAKE THE INDEX IN TERMS OF THE (SCAN,RAY) COORDINATE ARRAYS
            gmi_master_idx[numGMIrays] = LONG(scan_num) * LONG(NPIXEL_GMI) + LONG(ray_num)
            gmi_lat_sfc[numGMIrays] = gmiLats[ray_num,scan_num]
            gmi_lon_sfc[numGMIrays] = gmiLons[ray_num,scan_num]
            x_sfc[numGMIrays] = gmi_x0[ray_num, subset_scan_num]
            y_sfc[numGMIrays] = gmi_y0[ray_num, subset_scan_num]

            action2do = 1                      ; set up to process this in-range point
            maxrayidx = ray_num > maxrayidx    ; track highest ray num occurring in GR area
            minrayidx = ray_num < minrayidx    ; track lowest ray num in GR area
            numGMI_inrange = numGMI_inrange + 1    ; increment # of actual in-range footprints

	   ; determine whether the GMI ray has any retrieval data
            IF ( pixelStatus[ray_num, scan_num] EQ 0 ) THEN gmi_echoes[numGMIrays] = 1B
; gmi_echoes[numGMIrays] = 1B  ; TEST PERFORMANCE OF DOING ALL FOOTIES

           ; If GMI scan edge point, then set flag to add bogus GMI data point to
           ;   subarrays for each GMI spatial field, with GMI index flagged as
           ;   "off-scan-edge", and compute the extrapolated location parameters
            IF ( (ray_num EQ 0 OR ray_num EQ NPIXEL_GMI-1) AND mark_edges EQ 1 ) THEN BEGIN
              ; set flag and find the x,y offsets to extrapolated off-edge point
               action2do = 2                   ; set up to also process bogus off-edge point
              ; extrapolate X and Y to the bogus, off-scan-edge point
               if ( ray_num EQ 0 ) then begin 
                 ; offsets extrapolate X and Y to where (angle = angle-1) would be
                 ; Get offsets using the next footprint's X and Y
                  Xoff = gmi_x0[ray_num, subset_scan_num] - gmi_x0[ray_num+1, subset_scan_num]
                  Yoff = gmi_y0[ray_num, subset_scan_num] - gmi_y0[ray_num+1, subset_scan_num]
               endif else begin
                 ; extrapolate X and Y to where (angle = angle+1) would be
                 ; Get offsets using the preceding footprint's X and Y
                  Xoff = gmi_x0[ray_num, subset_scan_num] - gmi_x0[ray_num-1, subset_scan_num]
                  Yoff = gmi_y0[ray_num, subset_scan_num] - gmi_y0[ray_num-1, subset_scan_num]
               endelse
              ; compute the resulting lon/lat value of the extrapolated footprint
              ;  - we will add to temp lat/lon arrays in action sections, below
               XX = gmi_x0[ray_num, subset_scan_num] + Xoff
               YY = gmi_y0[ray_num, subset_scan_num] + Yoff
              ; need x and y in meters for MAP_PROJ_INVERSE:
               extrap_lon_lat = MAP_PROJ_INVERSE (XX*1000., YY*1000., MAP_STRUCTURE=smap)
            ENDIF

         ENDIF ELSE BEGIN
            IF mark_edges EQ 1 THEN BEGIN
              ; Is footprint immediately adjacent to the in-range area?  If so, then
              ;   'ring' the in-range points with a border of GMI bogosity, even for
              ;   scans with no rays in-range. (Is like adding a range ring at the
              ;   outer edge of the in-range area)
               IF ( precise_range[ray_num,subset_scan_num] LE $
                    (max_ranges[0] + NOM_GMI_RES_KM*1.1) ) THEN BEGIN
                   gmi_master_idx[numGMIrays] = -1L  ; store beyond-range indicator as GMI index
                   gmi_lat_sfc[numGMIrays] = gmiLats[ray_num,scan_num]
                   gmi_lon_sfc[numGMIrays] = gmiLons[ray_num,scan_num]
                   x_sfc[numGMIrays] = gmi_x0[ray_num, subset_scan_num]
                   y_sfc[numGMIrays] = gmi_y0[ray_num, subset_scan_num]
                   action2do = -1  ; set up to process bogus beyond-range point
               ENDIF
            ENDIF
         ENDELSE          ; ELSE for precise range[] LE max_ranges[0]

        ; If/As flag directs, add GMI point(s) to the subarrays for each elevation
         IF ( action2do NE 0 ) THEN BEGIN
           ; compute the at-surface x,y values for the 4 corners of the current GMI footprint
            if scan_num LT end_scan THEN $
            xy = footprint_corner_x_and_y( subset_scan_num, ray_num, gmi_x0, gmi_y0, $
                                           nscans2do, NPIXEL_GMI ) $
            else $
            xy = footprint_corner_x_and_y( subset_scan_num, ray_num, gmi_x0, gmi_y0, $
                                           nscans2do, NPIXEL_GMI, /DO_PRINT )

           ; compute parallax-corrected x-y values for each sweep height
            FOR i = 0, num_elevations_out - 1 DO BEGIN
              ; NEXT 4+ COMMANDS COULD BE ITERATIVE, TO CONVERGE TO A dR THRESHOLD (function?)
              ; compute GR beam height for elevation angle at precise_range
               rsl_get_slantr_and_h, precise_range[ray_num,subset_scan_num], $
                                     tocdf_elev_angle[i], slant_range, hgt_at_range

              ; compute GMI parallax corrections dX and dY at this height (adjusted to MSL),
              ;   and apply to footprint center X and Y to get XX and YY
;               get_parallax_dx_dy, hgt_at_range + siteElev, ray_num, NPIXEL_GMI, $
;                                   m, dy_sign, tan_inc_angle, dx, dy

               get_tmi_parallax_dx_dy, hgt_at_range, siteElev, scan_num, ray_num, $
                                       smap, tocdf_elev_angle[i], gmiLats, gmiLons, $
                                       scLats, scLons, dx, dy

               XX = gmi_x0[ray_num, subset_scan_num] + dx
               YY = gmi_y0[ray_num, subset_scan_num] + dy

              ; recompute precise_range of parallax-corrected GMI footprint from radar (if converging)

              ; compute lat,lon of parallax-corrected GMI footprint center:
               lon_lat = MAP_PROJ_INVERSE( XX*1000., YY*1000., MAP_STRUCTURE=smap )  ; x and y in meters

              ; compute parallax-corrected X and Y coordinate values for the GMI
              ;   footprint corners; hold in temp arrays xcornerspc and ycornerspc
               xcornerspc = xy[0,*] + dx
               ycornerspc = xy[1,*] + dy

              ; store GMI-GR sweep intersection (XX,YY), offset lat and lon, and
              ;  (if non-bogus) corner (x,y)s in elevation-specific slots
               gmi_x_center[numGMIrays,i] = XX
               gmi_y_center[numGMIrays,i] = YY
               gmi_x_corners[*,numGMIrays,i] = xcornerspc
               gmi_y_corners[*,numGMIrays,i] = ycornerspc
               gmi_lon_lat[*,numGMIrays,i] = lon_lat
            ENDFOR
            numGMIrays = numGMIrays + 1   ; increment counter for # GMI rays stored in arrays
         ENDIF

         IF ( action2do EQ 2 ) THEN BEGIN
           ; add another GMI footprint to the analyzed set, to delimit the GMI scan edge
            gmi_master_idx[numGMIrays] = -2L    ; store off-scan-edge indicator as GMI index
            gmi_lat_sfc[numGMIrays] = extrap_lon_lat[1]  ; store extrapolated lat/lon
            gmi_lon_sfc[numGMIrays] = extrap_lon_lat[0]
            x_sfc[numGMIrays] = gmi_x0[ray_num, subset_scan_num] + Xoff  ; ditto, extrap. x,y
            y_sfc[numGMIrays] = gmi_y0[ray_num, subset_scan_num] + Yoff

            FOR i = 0, num_elevations_out - 1 DO BEGIN
              ; - grab the parallax-corrected footprint center and corner x,y's just
              ;     stored for the in-range GMI edge point, and apply Xoff and Yoff offsets
               XX = gmi_x_center[numGMIrays-1,i] + Xoff
               YY = gmi_y_center[numGMIrays-1,i] + Yoff
               xcornerspc = gmi_x_corners[*,numGMIrays-1,i] + Xoff
               ycornerspc = gmi_y_corners[*,numGMIrays-1,i] + Yoff
              ; - compute lat,lon of parallax-corrected GMI footprint center:
               lon_lat = MAP_PROJ_INVERSE(XX*1000., YY*1000., MAP_STRUCTURE=smap)  ; x,y to m
              ; store in elevation-specific slots
               gmi_x_center[numGMIrays,i] = XX
               gmi_y_center[numGMIrays,i] = YY
               gmi_x_corners[*,numGMIrays,i] = xcornerspc
               gmi_y_corners[*,numGMIrays,i] = ycornerspc
               gmi_lon_lat[*,numGMIrays,i] = lon_lat
            ENDFOR
            numGMIrays = numGMIrays + 1
         ENDIF

      ENDFOR              ; ray_num
   ENDFOR                 ; scan_num = start_scan,end_scan 

  ; ONE TIME ONLY: compute max diagonal size of a GMI footprint, halve it,
  ;   and assign to max_GMI_footprint_diag_halfwidth.  Ignore the variability
  ;   with height.  Take middle scan of GMI/GR overlap within subset arrays:
   subset_scan_4size = FIX( (end_scan-start_scan)/2 )
  ; find which ray used was farthest from nadir ray at NPIXEL_GMI/2
   nadir_off_low = ABS(minrayidx - NPIXEL_GMI/2)
   nadir_off_hi = ABS(maxrayidx - NPIXEL_GMI/2)
   ray4size = (nadir_off_hi GT nadir_off_low) ? maxrayidx : minrayidx
  ; get GMI footprint max diag extent at [ray4size, scan4size], and halve it
  ; Is it guaranteed that [subset_scan4size,ray4size] is one of our in-range
  ;   points?  Don't know, so get the corner x,y's for this point
   xy = footprint_corner_x_and_y( subset_scan_4size, ray4size, gmi_x0, gmi_y0, $
                                  nscans2do, NPIXEL_GMI )
   diag1 = SQRT((xy[0,0]-xy[0,2])^2+(xy[1,0]-xy[1,2])^2)
   diag2 = SQRT((xy[0,1]-xy[0,3])^2+(xy[1,1]-xy[1,3])^2)
   max_GMI_footprint_diag_halfwidth = (diag1 > diag2) / 2.0
   print, ''
   print, "Computed radius of influence, km: ", max_GMI_footprint_diag_halfwidth
   print, ''

  ; end of GMI GEO-preprocessing

  ; ======================================================================================================

  ; Initialize and/or populate data fields to be written to the netCDF file.
  ; NOTE WE DON'T SAVE THE SURFACE X,Y FOOTPRINT CENTERS AND CORNERS TO NETCDF

   IF ( numGMI_inrange GT 0 ) THEN BEGIN
     ; Trim the gmi_master_idx, lat/lon temp arrays and x,y corner arrays down
     ;   to numGMIrays elements in that dimension, in prep. for writing to netCDF
     ;    -- these elements are complete, data-wise
      tocdf_gmi_idx = gmi_master_idx[0:numGMIrays-1]
      tocdf_x_poly = gmi_x_corners[*,0:numGMIrays-1,*]
      tocdf_y_poly = gmi_y_corners[*,0:numGMIrays-1,*]
      tocdf_lat = REFORM(gmi_lon_lat[1,0:numGMIrays-1,*])   ; 3D to 2D
      tocdf_lon = REFORM(gmi_lon_lat[0,0:numGMIrays-1,*])
      tocdf_lat_sfc = gmi_lat_sfc[0:numGMIrays-1]
      tocdf_lon_sfc = gmi_lon_sfc[0:numGMIrays-1]

     ; Create new subarrays of dimension equal to the numGMIrays for each 2-D
     ;   GMI science variable: surfaceType, surfacePrecipitation, pixelStatus
      tocdf_2AGPROF_srain = MAKE_ARRAY(numGMIrays, /float, VALUE=FLOAT_RANGE_EDGE)
      tocdf_pixelStatus = MAKE_ARRAY(numGMIrays, /int, VALUE=INT_RANGE_EDGE)
      tocdf_surfaceType = MAKE_ARRAY(numGMIrays, /int, VALUE=INT_RANGE_EDGE)
      tocdf_PoP = MAKE_ARRAY(numGMIrays, /int, VALUE=INT_RANGE_EDGE)
;      tocdf_freezingHeight = MAKE_ARRAY(numGMIrays, /int, VALUE=INT_RANGE_EDGE)


   	; additional variables for GPROf VN version 2.0 files
      tocdf_frozenPrecipitation = MAKE_ARRAY(numGMIrays, /float, VALUE=FLOAT_RANGE_EDGE)
   	  tocdf_convectivePrecipitation = MAKE_ARRAY(numGMIrays, /float, VALUE=FLOAT_RANGE_EDGE)
      tocdf_rainWaterPath = MAKE_ARRAY(numGMIrays, /float, VALUE=FLOAT_RANGE_EDGE)
      tocdf_cloudWaterPath = MAKE_ARRAY(numGMIrays, /float, VALUE=FLOAT_RANGE_EDGE)
      tocdf_iceWaterPath = MAKE_ARRAY(numGMIrays, /float, VALUE=FLOAT_RANGE_EDGE)
   
    ; new V7 variables for GPROf VN version 2.0 files
      tocdf_airmassLiftIndex = MAKE_ARRAY(numGMIrays, /int, VALUE=INT_RANGE_EDGE)
      tocdf_precipitationYesNoFlag = MAKE_ARRAY(numGMIrays, /int, VALUE=INT_RANGE_EDGE)
    
    ; new scanTime and scStatus variables
    
      tocdf_scLons =  MAKE_ARRAY(numGMIrays, /float, VALUE=FLOAT_RANGE_EDGE)
      tocdf_scLats =  MAKE_ARRAY(numGMIrays, /float, VALUE=FLOAT_RANGE_EDGE)

      tocdf_timeGMIscan = MAKE_ARRAY(numGMIrays, /float, VALUE=FLOAT_RANGE_EDGE)
      tocdf_stSunLocalTime = MAKE_ARRAY(numGMIrays, /float, VALUE=FLOAT_RANGE_EDGE)

      IF have_1c THEN BEGIN
        ; Create new subarrays of dimension nchan1c,numGMIrays for the GPROF Tc
        ; and Quality variables
         tocdf_1CRXCAL_Tc = MAKE_ARRAY(nchan1c, numGMIrays, /float, VALUE=FLOAT_RANGE_EDGE)
         tocdf_Quality =  MAKE_ARRAY(nchan1c, numGMIrays, /int)
      ENDIF

     ; Create new subarrays of dimensions (numGMIrays, num_elevations_out) for each
     ;   3-D science and status variable for along-GMI-FOV samples: 
      tocdf_gr_dbz = MAKE_ARRAY(numGMIrays, num_elevations_out, /float, $
                                VALUE=FLOAT_RANGE_EDGE)
      tocdf_gr_dbz_stddev = MAKE_ARRAY(numGMIrays, num_elevations_out, /float, $
                                   VALUE=FLOAT_RANGE_EDGE)
      tocdf_gr_dbz_max = MAKE_ARRAY(numGMIrays, num_elevations_out, /float, $
                                VALUE=FLOAT_RANGE_EDGE)
      tocdf_gr_rc = MAKE_ARRAY(numGMIrays, num_elevations_out, /float, $
                               VALUE=FLOAT_RANGE_EDGE)
      tocdf_gr_rc_stddev = MAKE_ARRAY(numGMIrays, num_elevations_out, /float, $
                                      VALUE=FLOAT_RANGE_EDGE)
      tocdf_gr_rc_max = MAKE_ARRAY(numGMIrays, num_elevations_out, /float, $
                                   VALUE=FLOAT_RANGE_EDGE)
      tocdf_gr_rp = MAKE_ARRAY(numGMIrays, num_elevations_out, /float, $
                               VALUE=FLOAT_RANGE_EDGE)
      tocdf_gr_rp_stddev = MAKE_ARRAY(numGMIrays, num_elevations_out, /float, $
                                      VALUE=FLOAT_RANGE_EDGE)
      tocdf_gr_rp_max = MAKE_ARRAY(numGMIrays, num_elevations_out, /float, $
                                   VALUE=FLOAT_RANGE_EDGE)
      tocdf_gr_rr = MAKE_ARRAY(numGMIrays, num_elevations_out, /float, $
                               VALUE=FLOAT_RANGE_EDGE)
      tocdf_gr_rr_stddev = MAKE_ARRAY(numGMIrays, num_elevations_out, /float, $
                                      VALUE=FLOAT_RANGE_EDGE)
      tocdf_gr_rr_max = MAKE_ARRAY(numGMIrays, num_elevations_out, /float, $
                                   VALUE=FLOAT_RANGE_EDGE)
      tocdf_gr_zdr = MAKE_ARRAY(numGMIrays, num_elevations_out, /float, $
                                VALUE=FLOAT_RANGE_EDGE)
      tocdf_gr_zdr_stddev = MAKE_ARRAY(numGMIrays, num_elevations_out, /float, $
                                       VALUE=FLOAT_RANGE_EDGE)
      tocdf_gr_zdr_max = MAKE_ARRAY(numGMIrays, num_elevations_out, /float, $
                                    VALUE=FLOAT_RANGE_EDGE)
      tocdf_gr_kdp = MAKE_ARRAY(numGMIrays, num_elevations_out, /float, $
                                VALUE=FLOAT_RANGE_EDGE)
      tocdf_gr_kdp_stddev = MAKE_ARRAY(numGMIrays, num_elevations_out, /float, $
                                       VALUE=FLOAT_RANGE_EDGE)
      tocdf_gr_kdp_max = MAKE_ARRAY(numGMIrays, num_elevations_out, /float, $
                                    VALUE=FLOAT_RANGE_EDGE)
      tocdf_gr_rhohv = MAKE_ARRAY(numGMIrays, num_elevations_out, /float, $
                                  VALUE=FLOAT_RANGE_EDGE)
      tocdf_gr_rhohv_stddev = MAKE_ARRAY(numGMIrays, num_elevations_out, $
                                         /float, VALUE=FLOAT_RANGE_EDGE)
      tocdf_gr_rhohv_max = MAKE_ARRAY(numGMIrays, num_elevations_out, /float, $
                                      VALUE=FLOAT_RANGE_EDGE)
      IF ( have_gv_hid ) THEN $  ; don't have n_hid_cats unless have_gv_hid set
         tocdf_gr_HID = MAKE_ARRAY(n_hid_cats, numGMIrays, num_elevations_out, $
                                /int, VALUE=INT_RANGE_EDGE)
      tocdf_gr_Dzero = MAKE_ARRAY(numGMIrays, num_elevations_out, /float, $
                                  VALUE=FLOAT_RANGE_EDGE)
      tocdf_gr_Dzero_stddev = MAKE_ARRAY(numGMIrays, num_elevations_out, $
                                         /float, VALUE=FLOAT_RANGE_EDGE)
      tocdf_gr_Dzero_max = MAKE_ARRAY(numGMIrays, num_elevations_out, /float, $
                                      VALUE=FLOAT_RANGE_EDGE)
      tocdf_gr_Nw = MAKE_ARRAY(numGMIrays, num_elevations_out, /float, $
                               VALUE=FLOAT_RANGE_EDGE)
      tocdf_gr_Nw_stddev = MAKE_ARRAY(numGMIrays, num_elevations_out, /float, $
                                      VALUE=FLOAT_RANGE_EDGE)
      tocdf_gr_Nw_max = MAKE_ARRAY(numGMIrays, num_elevations_out, /float, $
                                   VALUE=FLOAT_RANGE_EDGE)
      tocdf_gr_Mw = MAKE_ARRAY(numGMIrays, num_elevations_out, /float, $
                               VALUE=FLOAT_RANGE_EDGE)
      tocdf_gr_Mw_stddev = MAKE_ARRAY(numGMIrays, num_elevations_out, /float, $
                                      VALUE=FLOAT_RANGE_EDGE)
      tocdf_gr_Mw_max = MAKE_ARRAY(numGMIrays, num_elevations_out, /float, $
                                   VALUE=FLOAT_RANGE_EDGE)
      tocdf_gr_Mi = MAKE_ARRAY(numGMIrays, num_elevations_out, /float, $
                               VALUE=FLOAT_RANGE_EDGE)
      tocdf_gr_Mi_stddev = MAKE_ARRAY(numGMIrays, num_elevations_out, /float, $
                                      VALUE=FLOAT_RANGE_EDGE)
      tocdf_gr_Mi_max = MAKE_ARRAY(numGMIrays, num_elevations_out, /float, $
                                   VALUE=FLOAT_RANGE_EDGE)
      tocdf_gr_blockage = MAKE_ARRAY(numGMIrays, num_elevations_out, /float, $
                                     VALUE=FLOAT_RANGE_EDGE)
      tocdf_top_hgt = MAKE_ARRAY(numGMIrays, num_elevations_out, /float, $
                                 VALUE=FLOAT_RANGE_EDGE)
      tocdf_botm_hgt = MAKE_ARRAY(numGMIrays, num_elevations_out, /float, $
                                  VALUE=FLOAT_RANGE_EDGE)
      tocdf_gr_z_rejected = UINTARR(numGMIrays, num_elevations_out)
      tocdf_gr_rc_rejected = UINTARR(numGMIrays, num_elevations_out)
      tocdf_gr_rp_rejected = UINTARR(numGMIrays, num_elevations_out)
      tocdf_gr_rr_rejected = UINTARR(numGMIrays, num_elevations_out)
      tocdf_gr_zdr_rejected = UINTARR(numGMIrays, num_elevations_out)
      tocdf_gr_kdp_rejected = UINTARR(numGMIrays, num_elevations_out)
      tocdf_gr_rhohv_rejected = UINTARR(numGMIrays, num_elevations_out)
      tocdf_gr_hid_rejected = UINTARR(numGMIrays, num_elevations_out)
      tocdf_gr_dzero_rejected = UINTARR(numGMIrays, num_elevations_out)
      tocdf_gr_nw_rejected = UINTARR(numGMIrays, num_elevations_out)
      tocdf_gr_mw_rejected = UINTARR(numGMIrays, num_elevations_out)
      tocdf_gr_mi_rejected = UINTARR(numGMIrays, num_elevations_out)
      tocdf_gr_expected = UINTARR(numGMIrays, num_elevations_out)

     ; Create new subarrays of dimensions (numGMIrays, num_elevations_out) for each
     ;   3-D science and status variable for along-local-vertical samples: 
      tocdf_gr_dbz_VPR = MAKE_ARRAY(numGMIrays, num_elevations_out, /float, $
                                    VALUE=FLOAT_RANGE_EDGE)
      tocdf_gr_dbz_stddev_VPR = MAKE_ARRAY(numGMIrays, num_elevations_out, $
                                           /float, VALUE=FLOAT_RANGE_EDGE)
      tocdf_gr_dbz_Max_VPR = MAKE_ARRAY(numGMIrays, num_elevations_out, $
                                        /float, VALUE=FLOAT_RANGE_EDGE)
      tocdf_gr_rc_VPR = MAKE_ARRAY(numGMIrays, num_elevations_out, /float, $
                                   VALUE=FLOAT_RANGE_EDGE)
      tocdf_gr_rc_StdDev_VPR = MAKE_ARRAY(numGMIrays, num_elevations_out, $
                                          /float, VALUE=FLOAT_RANGE_EDGE)
      tocdf_gr_rc_Max_VPR = MAKE_ARRAY(numGMIrays, num_elevations_out, /float, $
                                       VALUE=FLOAT_RANGE_EDGE)
      tocdf_gr_rp_VPR = MAKE_ARRAY(numGMIrays, num_elevations_out, /float, $
                                   VALUE=FLOAT_RANGE_EDGE)
      tocdf_gr_rp_StdDev_VPR = MAKE_ARRAY(numGMIrays, num_elevations_out, $
                                          /float, VALUE=FLOAT_RANGE_EDGE)
      tocdf_gr_rp_Max_VPR = MAKE_ARRAY(numGMIrays, num_elevations_out, /float, $
                                       VALUE=FLOAT_RANGE_EDGE)
      tocdf_gr_rr_VPR = MAKE_ARRAY(numGMIrays, num_elevations_out, /float, $
                                   VALUE=FLOAT_RANGE_EDGE)
      tocdf_gr_rr_StdDev_VPR = MAKE_ARRAY(numGMIrays, num_elevations_out, $
                                          /float, VALUE=FLOAT_RANGE_EDGE)
      tocdf_gr_rr_Max_VPR = MAKE_ARRAY(numGMIrays, num_elevations_out, /float, $
                                       VALUE=FLOAT_RANGE_EDGE)
      tocdf_gr_zdr_VPR = MAKE_ARRAY(numGMIrays, num_elevations_out, /float, $
                                    VALUE=FLOAT_RANGE_EDGE)
      tocdf_gr_zdr_stddev_VPR = MAKE_ARRAY(numGMIrays, num_elevations_out, $
                                           /float, VALUE=FLOAT_RANGE_EDGE)
      tocdf_gr_zdr_max_VPR = MAKE_ARRAY(numGMIrays, num_elevations_out, $
                                        /float, VALUE=FLOAT_RANGE_EDGE)
      tocdf_gr_kdp_VPR = MAKE_ARRAY(numGMIrays, num_elevations_out, /float, $
                                    VALUE=FLOAT_RANGE_EDGE)
      tocdf_gr_kdp_stddev_VPR = MAKE_ARRAY(numGMIrays, num_elevations_out, $
                                           /float, VALUE=FLOAT_RANGE_EDGE)
      tocdf_gr_kdp_max_VPR = MAKE_ARRAY(numGMIrays, num_elevations_out, /float, $
                                        VALUE=FLOAT_RANGE_EDGE)
      tocdf_gr_rhohv_VPR = MAKE_ARRAY(numGMIrays, num_elevations_out, /float, $
                                      VALUE=FLOAT_RANGE_EDGE)
      tocdf_gr_rhohv_stddev_VPR = MAKE_ARRAY(numGMIrays, num_elevations_out, $
                                             /float, VALUE=FLOAT_RANGE_EDGE)
      tocdf_gr_rhohv_max_VPR = MAKE_ARRAY(numGMIrays, num_elevations_out, $
                                          /float, VALUE=FLOAT_RANGE_EDGE)
      IF ( have_gv_hid ) THEN $  ; don't have n_hid_cats unless have_gv_hid set
         tocdf_gr_HID_VPR = MAKE_ARRAY(n_hid_cats, numGMIrays, num_elevations_out, $
                                       /int, VALUE=INT_RANGE_EDGE)
      tocdf_gr_Dzero_VPR = MAKE_ARRAY(numGMIrays, num_elevations_out, /float, $
                                      VALUE=FLOAT_RANGE_EDGE)
      tocdf_gr_Dzero_stddev_VPR = MAKE_ARRAY(numGMIrays, num_elevations_out, $
                                             /float, VALUE=FLOAT_RANGE_EDGE)
      tocdf_gr_Dzero_max_VPR = MAKE_ARRAY(numGMIrays, num_elevations_out, $
                                          /float, VALUE=FLOAT_RANGE_EDGE)
      tocdf_gr_Nw_VPR = MAKE_ARRAY(numGMIrays, num_elevations_out, /float, $
                                   VALUE=FLOAT_RANGE_EDGE)
      tocdf_gr_Nw_stddev_VPR = MAKE_ARRAY(numGMIrays, num_elevations_out, $
                                          /float, VALUE=FLOAT_RANGE_EDGE)
      tocdf_gr_Nw_max_VPR = MAKE_ARRAY(numGMIrays, num_elevations_out, /float, $
                                       VALUE=FLOAT_RANGE_EDGE)
      tocdf_gr_Mw_VPR = MAKE_ARRAY(numGMIrays, num_elevations_out, /float, $
                                   VALUE=FLOAT_RANGE_EDGE)
      tocdf_gr_Mw_stddev_VPR = MAKE_ARRAY(numGMIrays, num_elevations_out, $
                                          /float, VALUE=FLOAT_RANGE_EDGE)
      tocdf_gr_Mw_max_VPR = MAKE_ARRAY(numGMIrays, num_elevations_out, /float, $
                                       VALUE=FLOAT_RANGE_EDGE)
      tocdf_gr_Mi_VPR = MAKE_ARRAY(numGMIrays, num_elevations_out, /float, $
                                   VALUE=FLOAT_RANGE_EDGE)
      tocdf_gr_Mi_stddev_VPR = MAKE_ARRAY(numGMIrays, num_elevations_out, $
                                          /float, VALUE=FLOAT_RANGE_EDGE)
      tocdf_gr_Mi_max_VPR = MAKE_ARRAY(numGMIrays, num_elevations_out, /float, $
                                       VALUE=FLOAT_RANGE_EDGE)
      tocdf_gr_blockage_VPR = MAKE_ARRAY(numGMIrays, num_elevations_out, /float, $
                                         VALUE=FLOAT_RANGE_EDGE)
      tocdf_top_hgt_VPR = MAKE_ARRAY(numGMIrays, num_elevations_out, /float, $
                                     VALUE=FLOAT_RANGE_EDGE)
      tocdf_botm_hgt_VPR = MAKE_ARRAY(numGMIrays, num_elevations_out, /float, $
                                      VALUE=FLOAT_RANGE_EDGE)
      tocdf_gr_z_VPR_rejected = UINTARR(numGMIrays, num_elevations_out)
      tocdf_gr_rc_VPR_rejected = UINTARR(numGMIrays, num_elevations_out)
      tocdf_gr_rp_VPR_rejected = UINTARR(numGMIrays, num_elevations_out)
      tocdf_gr_rr_VPR_rejected = UINTARR(numGMIrays, num_elevations_out)
      tocdf_gr_zdr_VPR_rejected = UINTARR(numGMIrays, num_elevations_out)
      tocdf_gr_kdp_VPR_rejected = UINTARR(numGMIrays, num_elevations_out)
      tocdf_gr_rhohv_VPR_rejected = UINTARR(numGMIrays, num_elevations_out)
      tocdf_gr_hid_VPR_rejected = UINTARR(numGMIrays, num_elevations_out)
      tocdf_gr_dzero_VPR_rejected = UINTARR(numGMIrays, num_elevations_out)
      tocdf_gr_nw_VPR_rejected = UINTARR(numGMIrays, num_elevations_out)
      tocdf_gr_mw_VPR_rejected = UINTARR(numGMIrays, num_elevations_out)
      tocdf_gr_mi_VPR_rejected = UINTARR(numGMIrays, num_elevations_out)
      tocdf_gr_VPR_expected = UINTARR(numGMIrays, num_elevations_out)

     ; get the indices of actual GMI footprints and load the 2D element subarrays
     ;   (no more averaging/processing needed) with data from the product arrays

      prgoodidx = WHERE( tocdf_gmi_idx GE 0L, countprgood )
      IF ( countprgood GT 0 ) THEN BEGIN
         gmi_idx_2get = tocdf_gmi_idx[prgoodidx]
         tocdf_2AGPROF_srain[prgoodidx] = surfacePrecipitation[gmi_idx_2get]
         tocdf_pixelStatus[prgoodidx] = pixelStatus[gmi_idx_2get]
         tocdf_surfaceType[prgoodidx] = surfaceType[gmi_idx_2get]
         tocdf_PoP[prgoodidx] = PoP[gmi_idx_2get]
         
         ; additional variables for GPROf VN version 2.0 files
   		 tocdf_frozenPrecipitation[prgoodidx] = frozenPrecipitation[gmi_idx_2get]
   		 tocdf_convectivePrecipitation[prgoodidx] = convectivePrecipitation[gmi_idx_2get]
   		 tocdf_rainWaterPath[prgoodidx] = rainWaterPath[gmi_idx_2get]
   		 tocdf_cloudWaterPath[prgoodidx] = cloudWaterPath[gmi_idx_2get]
   		 tocdf_iceWaterPath[prgoodidx] = iceWaterPath[gmi_idx_2get]
   
   		 ; new V7 variables for GPROf VN version 2.0 files
   		 if ( is_version_7 eq 1 ) then begin
   		     tocdf_airmassLiftIndex[prgoodidx] = airmassLiftIndex[gmi_idx_2get]
   		     tocdf_precipitationYesNoFlag[prgoodidx] = precipitationYesNoFlag[gmi_idx_2get]
   		 endif 

	     ; new scStatus and scanTime variables
      	 tocdf_scLons[prgoodidx] = tmp_scLons[gmi_idx_2get]
      	 tocdf_scLats[prgoodidx] = tmp_scLats[gmi_idx_2get]
   		 tocdf_timeGMIscan[prgoodidx] = tmp_timeGMIscan[gmi_idx_2get]
   		 tocdf_stSunLocalTime[prgoodidx] = tmp_stSunLocalTime[gmi_idx_2get]
         
        ; handle the arrays with the extra dimension of channel number
         IF have_1c THEN BEGIN
            for k = 0, nchan1c-1 do begin
               ; extract one channel of data to have a 2D array of scan vs. ray
               ; that can be addressed by gmi_idx_2get
                oneChan = REFORM(Tc_all[k,*,*])
                tocdf_1CRXCAL_Tc[k,prgoodidx] = oneChan[gmi_idx_2get]
                oneChan = REFORM(Quality_all[k,*,*])
                tocdf_Quality[k,prgoodidx] = oneChan[gmi_idx_2get]
            endfor
            oneChan=''  ; 'undefine' array
         ENDIF
      ENDIF

     ; get the indices of any bogus scan-edge GMI footprints
      predgeidx = WHERE( tocdf_gmi_idx EQ -2, countpredge )
      IF ( countpredge GT 0 ) THEN BEGIN
        ; set the single-level GMI element subarrays with the special values for
        ;   the extrapolated points
         tocdf_2AGPROF_srain[predgeidx] = FLOAT_OFF_EDGE
         tocdf_pixelStatus[predgeidx] = INT_OFF_EDGE
         tocdf_surfaceType[predgeidx] = INT_OFF_EDGE
         tocdf_PoP[predgeidx] = INT_OFF_EDGE
        ; handle the arrays with the extra dimension of channel number
         IF have_1c THEN BEGIN
            for k = 0, nchan1c-1 do begin
                tocdf_1CRXCAL_Tc[k,predgeidx] = FLOAT_OFF_EDGE
                tocdf_Quality[k,predgeidx] = INT_OFF_EDGE
            endfor
         ENDIF
      ENDIF

   ENDIF ELSE BEGIN
      PRINT, ""
      PRINT, "No in-range GMI footprints found for ", siteID, ", skipping."
      PRINT, ""
      GOTO, nextGVfile
   ENDELSE

  ; ================================================================================================
  ; Map this GV radar's data to the these GMI footprints, where GMI rays
  ; intersect the elevation sweeps.  This part of the algorithm continues
  ; in code in a separate file, included below:

   @polar2gmi_resampling_v7.pro

  ; ================================================================================================

  ; generate the netcdf matchup file path/name
   IF N_ELEMENTS(ncnameadd) EQ 1 THEN BEGIN
      fname_netCDF = NC_OUTDIR+'/'+GMI_GEO_MATCH_PRE+sat_instr+siteID+'.'+DATESTAMP+'.' $
                      +orbit+'.'+GPROF_version+'.'+verstr+'.'+ncnameadd+NC_FILE_EXT
   ENDIF ELSE BEGIN
      fname_netCDF = NC_OUTDIR+'/'+GMI_GEO_MATCH_PRE+sat_instr+siteID+'.'+DATESTAMP+'.' $
                      +orbit+'.'+GPROF_version+'.'+verstr+NC_FILE_EXT
   ENDELSE

  ; Create a netCDF file with the proper 'numGMIrays' and 'num_elevations_out'
  ; and Tc channels dimensions, passing the global attribute values along
   ncfile = gen_gprof_geo_match_netcdf_v7( fname_netCDF, numGMIrays, $
                                        tocdf_elev_angle, ufstruct, $
                                        GPROF_version, siteID, $
                                        infileNameArr, Tc_Names, FREEZING_LEVEL=freezing_level )

   IF ( fname_netCDF EQ "NoGeoMatchFile" ) THEN $
      message, "Error in creating output netCDF file "+fname_netCDF

  ; Open the netCDF file and write the completed field values to it
   ncid = NCDF_OPEN( ncfile, /WRITE )

  ; Write the scalar values to the netCDF file

   NCDF_VARPUT, ncid, 'site_ID', siteID
   NCDF_VARPUT, ncid, 'site_lat', siteLat
   NCDF_VARPUT, ncid, 'site_lon', siteLon
   NCDF_VARPUT, ncid, 'site_elev', siteElev
   NCDF_VARPUT, ncid, 'timeNearestApproach', gmi_dtime_ticks
   NCDF_VARPUT, ncid, 'atimeNearestApproach', gmi_dtime
   NCDF_VARPUT, ncid, 'timeSweepStart', ticks_sweep_times
   NCDF_VARPUT, ncid, 'atimeSweepStart', text_sweep_times
   NCDF_VARPUT, ncid, 'rangeThreshold', range_threshold_km
   NCDF_VARPUT, ncid, 'GR_dBZ_min', dBZ_min
   NCDF_VARPUT, ncid, 'gprof_rain_min', GMI_RAIN_MIN
   NCDF_VARPUT, ncid, 'radiusOfInfluence', max_GMI_footprint_diag_halfwidth

;  Write single-level results/flags to netcdf file

   NCDF_VARPUT, ncid, 'XMIlatitude', tocdf_lat_sfc
   NCDF_VARPUT, ncid, 'XMIlongitude', tocdf_lon_sfc
   NCDF_VARPUT, ncid, 'surfaceTypeIndex', tocdf_surfaceType     ; data
    NCDF_VARPUT, ncid, 'have_surfaceTypeIndex', DATA_PRESENT  ; data presence flag
   NCDF_VARPUT, ncid, 'surfacePrecipitation', tocdf_2AGPROF_srain     ; data
    NCDF_VARPUT, ncid, 'have_surfacePrecipitation', DATA_PRESENT   ; data presence flag
   NCDF_VARPUT, ncid, 'pixelStatus', tocdf_pixelStatus      ; data
    NCDF_VARPUT, ncid, 'have_pixelStatus', DATA_PRESENT  ; data presence flag
   NCDF_VARPUT, ncid, 'PoP', tocdf_PoP      ; data
    NCDF_VARPUT, ncid, 'have_PoP', DATA_PRESENT  ; data presence flag
   
; additional variables for GPROf VN version 2.0 files
   NCDF_VARPUT, ncid, 'frozenPrecipitation', tocdf_frozenPrecipitation      ; data
    NCDF_VARPUT, ncid, 'have_frozenPrecipitation', DATA_PRESENT  ; data presence flag
   NCDF_VARPUT, ncid, 'convectivePrecipitation', tocdf_convectivePrecipitation      ; data
    NCDF_VARPUT, ncid, 'have_convectivePrecipitation', DATA_PRESENT  ; data presence flag
   NCDF_VARPUT, ncid, 'rainWaterPath', tocdf_rainWaterPath      ; data
    NCDF_VARPUT, ncid, 'have_rainWaterPath', DATA_PRESENT  ; data presence flag
   NCDF_VARPUT, ncid, 'cloudWaterPath', tocdf_cloudWaterPath      ; data
    NCDF_VARPUT, ncid, 'have_cloudWaterPath', DATA_PRESENT  ; data presence flag
   NCDF_VARPUT, ncid, 'iceWaterPath', tocdf_iceWaterPath      ; data
    NCDF_VARPUT, ncid, 'have_iceWaterPath', DATA_PRESENT  ; data presence flag

; scantime and scstatus variables for each footprint    
   NCDF_VARPUT, ncid, 'scLons', tocdf_scLons      ; data
    NCDF_VARPUT, ncid, 'have_scLons', DATA_PRESENT  ; data presence flag
   NCDF_VARPUT, ncid, 'scLats', tocdf_scLats      ; data
    NCDF_VARPUT, ncid, 'have_scLats', DATA_PRESENT  ; data presence flag
   NCDF_VARPUT, ncid, 'timeGMIscan', tocdf_timeGMIscan      ; data
    NCDF_VARPUT, ncid, 'have_timeGMIscan', DATA_PRESENT  ; data presence flag
   NCDF_VARPUT, ncid, 'stSunLocalTime', tocdf_stSunLocalTime      ; data
    NCDF_VARPUT, ncid, 'have_stSunLocalTime', DATA_PRESENT  ; data presence flag

; new V7 variables for GPROf VN version 2.0 files
   NCDF_VARPUT, ncid, 'airmassLiftIndex', tocdf_airmassLiftIndex      ; data
    NCDF_VARPUT, ncid, 'have_airmassLiftIndex', DATA_PRESENT  ; data presence flag
   NCDF_VARPUT, ncid, 'precipitationYesNoFlag', tocdf_precipitationYesNoFlag      ; data
    NCDF_VARPUT, ncid, 'have_precipitationYesNoFlag', DATA_PRESENT  ; data presence flag
    
   NCDF_VARPUT, ncid, 'rayIndex', tocdf_gmi_idx
   IF have_1c THEN BEGIN
      NCDF_VARPUT, ncid, 'Tc', tocdf_1CRXCAL_Tc
      NCDF_VARPUT, ncid, 'Quality', tocdf_Quality
      NCDF_VARPUT, ncid, 'have_Tc', DATA_PRESENT
   ENDIF

;  Write sweep-level results/flags to netcdf file & close it up

   NCDF_VARPUT, ncid, 'latitude', tocdf_lat
   NCDF_VARPUT, ncid, 'longitude', tocdf_lon
   NCDF_VARPUT, ncid, 'xCorners', tocdf_x_poly
   NCDF_VARPUT, ncid, 'yCorners', tocdf_y_poly
   NCDF_VARPUT, ncid, 'GR_Z_slantPath', tocdf_gr_dbz            ; data
    NCDF_VARPUT, ncid, 'have_GR_Z_slantPath', DATA_PRESENT      ; data presence flag
   NCDF_VARPUT, ncid, 'GR_Z_StdDev_slantPath', tocdf_gr_dbz_stddev     ; data
   NCDF_VARPUT, ncid, 'GR_Z_Max_slantPath', tocdf_gr_dbz_max            ; data
   IF ( have_gv_rc ) THEN BEGIN
      NCDF_VARPUT, ncid, 'GR_RC_rainrate_slantPath', tocdf_gr_rc            ; data
      NCDF_VARPUT, ncid, 'GR_RC_rainrate_StdDev_slantPath', tocdf_gr_rc_stddev     ; data
      NCDF_VARPUT, ncid, 'GR_RC_rainrate_Max_slantPath', tocdf_gr_rc_max            ; data
   ENDIF
   NCDF_VARPUT, ncid, 'have_GR_RC_rainrate_slantPath', have_gv_rc      ; data presence flag
   IF ( have_gv_rp ) THEN BEGIN
      NCDF_VARPUT, ncid, 'GR_RP_rainrate_slantPath', tocdf_gr_rp            ; data
      NCDF_VARPUT, ncid, 'GR_RP_rainrate_StdDev_slantPath', tocdf_gr_rp_stddev     ; data
      NCDF_VARPUT, ncid, 'GR_RP_rainrate_Max_slantPath', tocdf_gr_rp_max            ; data
   ENDIF
   NCDF_VARPUT, ncid, 'have_GR_RP_rainrate_slantPath', have_gv_rp      ; data presence flag
   IF ( have_gv_rr ) THEN BEGIN
      NCDF_VARPUT, ncid, 'GR_RR_rainrate_slantPath', tocdf_gr_rr            ; data
      NCDF_VARPUT, ncid, 'GR_RR_rainrate_StdDev_slantPath', tocdf_gr_rr_stddev     ; data
      NCDF_VARPUT, ncid, 'GR_RR_rainrate_Max_slantPath', tocdf_gr_rr_max            ; data
   ENDIF
   NCDF_VARPUT, ncid, 'have_GR_RR_rainrate_slantPath', have_gv_rr      ; data presence flag
   IF ( have_gv_zdr ) THEN BEGIN
      NCDF_VARPUT, ncid, 'GR_Zdr_slantPath', tocdf_gr_zdr            ; data
      NCDF_VARPUT, ncid, 'GR_Zdr_StdDev_slantPath', tocdf_gr_zdr_stddev     ; data
      NCDF_VARPUT, ncid, 'GR_Zdr_Max_slantPath', tocdf_gr_zdr_max            ; data
   ENDIF
   NCDF_VARPUT, ncid, 'have_GR_Zdr_slantPath', have_gv_zdr      ; data presence flag
   IF ( have_gv_kdp ) THEN BEGIN
      NCDF_VARPUT, ncid, 'GR_Kdp_slantPath', tocdf_gr_kdp            ; data
      NCDF_VARPUT, ncid, 'GR_Kdp_StdDev_slantPath', tocdf_gr_kdp_stddev     ; data
      NCDF_VARPUT, ncid, 'GR_Kdp_Max_slantPath', tocdf_gr_kdp_max            ; data
   ENDIF
   NCDF_VARPUT, ncid, 'have_GR_Kdp_slantPath', have_gv_kdp      ; data presence flag
   IF ( have_gv_rhohv ) THEN BEGIN
      NCDF_VARPUT, ncid, 'GR_RHOhv_slantPath', tocdf_gr_rhohv            ; data
      NCDF_VARPUT, ncid, 'GR_RHOhv_StdDev_slantPath', tocdf_gr_rhohv_stddev     ; data
      NCDF_VARPUT, ncid, 'GR_RHOhv_Max_slantPath', tocdf_gr_rhohv_max            ; data
   ENDIF
   NCDF_VARPUT, ncid, 'have_GR_RHOhv_slantPath', have_gv_rhohv      ; data presence flag
   IF ( have_gv_hid ) THEN BEGIN
      NCDF_VARPUT, ncid, 'GR_HID_slantPath', tocdf_gr_hid            ; data
   ENDIF
   NCDF_VARPUT, ncid, 'have_GR_HID_slantPath', have_gv_hid      ; data presence flag
   IF ( have_gv_dzero ) THEN BEGIN
      NCDF_VARPUT, ncid, 'GR_Dzero_slantPath', tocdf_gr_dzero            ; data
      NCDF_VARPUT, ncid, 'GR_Dzero_StdDev_slantPath', tocdf_gr_dzero_stddev     ; data
      NCDF_VARPUT, ncid, 'GR_Dzero_Max_slantPath', tocdf_gr_dzero_max            ; data
   ENDIF
   NCDF_VARPUT, ncid, 'have_GR_Dzero_slantPath', have_gv_dzero      ; data presence flag
   IF ( have_gv_nw ) THEN BEGIN
      NCDF_VARPUT, ncid, 'GR_Nw_slantPath', tocdf_gr_nw            ; data
      NCDF_VARPUT, ncid, 'GR_Nw_StdDev_slantPath', tocdf_gr_nw_stddev     ; data
      NCDF_VARPUT, ncid, 'GR_Nw_Max_slantPath', tocdf_gr_nw_max            ; data
   ENDIF
   NCDF_VARPUT, ncid, 'have_GR_Nw_slantPath', have_gv_nw      ; data presence flag
   IF ( have_gv_mw ) THEN BEGIN
      NCDF_VARPUT, ncid, 'GR_liquidWaterContent_slantPath', tocdf_gr_mw            ; data
      NCDF_VARPUT, ncid, 'GR_liquidWaterContent_StdDev_slantPath', tocdf_gr_mw_stddev     ; data
      NCDF_VARPUT, ncid, 'GR_liquidWaterContent_Max_slantPath', tocdf_gr_mw_max            ; data
   ENDIF
   NCDF_VARPUT, ncid, 'have_GR_liquidWaterContent_slantPath', have_gv_mw      ; data presence flag
   IF ( have_gv_mi ) THEN BEGIN
      NCDF_VARPUT, ncid, 'GR_frozenWaterContent_slantPath', tocdf_gr_mi            ; data
      NCDF_VARPUT, ncid, 'GR_frozenWaterContent_StdDev_slantPath', tocdf_gr_mi_stddev     ; data
      NCDF_VARPUT, ncid, 'GR_frozenWaterContent_Max_slantPath', tocdf_gr_mi_max            ; data
   ENDIF
   NCDF_VARPUT, ncid, 'have_GR_frozenWaterContent_slantPath', have_gv_mi      ; data presence flag
   IF ( have_gv_blockage ) THEN BEGIN
      NCDF_VARPUT, ncid, 'GR_blockage_slantPath', tocdf_gr_blockage      ; data
   ENDIF
   NCDF_VARPUT, ncid, 'have_GR_blockage_slantPath', have_gv_blockage      ; data presence flag
   
   NCDF_VARPUT, ncid, 'topHeight', tocdf_top_hgt
   NCDF_VARPUT, ncid, 'bottomHeight', tocdf_botm_hgt
   NCDF_VARPUT, ncid, 'n_gr_z_rejected', tocdf_gr_z_rejected
   NCDF_VARPUT, ncid, 'n_gr_rc_rejected', tocdf_gr_rc_rejected
   NCDF_VARPUT, ncid, 'n_gr_rp_rejected', tocdf_gr_rp_rejected
   NCDF_VARPUT, ncid, 'n_gr_rr_rejected', tocdf_gr_rr_rejected
   NCDF_VARPUT, ncid, 'n_gr_zdr_rejected', tocdf_gr_zdr_rejected
   NCDF_VARPUT, ncid, 'n_gr_kdp_rejected', tocdf_gr_kdp_rejected
   NCDF_VARPUT, ncid, 'n_gr_rhohv_rejected', tocdf_gr_rhohv_rejected
   NCDF_VARPUT, ncid, 'n_gr_hid_rejected', tocdf_gr_hid_rejected
   NCDF_VARPUT, ncid, 'n_gr_dzero_rejected', tocdf_gr_dzero_rejected
   NCDF_VARPUT, ncid, 'n_gr_nw_rejected', tocdf_gr_nw_rejected
   NCDF_VARPUT, ncid, 'n_gr_liquidWaterContent_rejected', tocdf_gr_mw_rejected
   NCDF_VARPUT, ncid, 'n_gr_frozenWaterContent_rejected', tocdf_gr_mi_rejected
   NCDF_VARPUT, ncid, 'n_gr_expected', tocdf_gr_expected

   NCDF_VARPUT, ncid, 'GR_Z_VPR', tocdf_gr_dbz_VPR            ; data
    NCDF_VARPUT, ncid, 'have_GR_Z_VPR', DATA_PRESENT      ; data presence flag
   NCDF_VARPUT, ncid, 'GR_Z_StdDev_VPR', tocdf_gr_dbz_stddev_VPR     ; data
   NCDF_VARPUT, ncid, 'GR_Z_Max_VPR', tocdf_gr_dbz_Max_VPR            ; data
   IF ( have_gv_rc ) THEN BEGIN
      NCDF_VARPUT, ncid, 'GR_RC_rainrate_VPR', tocdf_gr_rc_VPR            ; data
      NCDF_VARPUT, ncid, 'GR_RC_rainrate_StdDev_VPR', tocdf_gr_rc_StdDev_VPR     ; data
      NCDF_VARPUT, ncid, 'GR_RC_rainrate_Max_VPR', tocdf_gr_rc_Max_VPR            ; data
   ENDIF
   NCDF_VARPUT, ncid, 'have_GR_RC_rainrate_VPR', have_gv_rc      ; data presence flag
   IF ( have_gv_rp ) THEN BEGIN
      NCDF_VARPUT, ncid, 'GR_RP_rainrate_VPR', tocdf_gr_rp_VPR            ; data
      NCDF_VARPUT, ncid, 'GR_RP_rainrate_StdDev_VPR', tocdf_gr_rp_StdDev_VPR     ; data
      NCDF_VARPUT, ncid, 'GR_RP_rainrate_Max_VPR', tocdf_gr_rp_Max_VPR            ; data
   ENDIF
   NCDF_VARPUT, ncid, 'have_GR_RP_rainrate_VPR', have_gv_rp      ; data presence flag
   IF ( have_gv_rr ) THEN BEGIN
      NCDF_VARPUT, ncid, 'GR_RR_rainrate_VPR', tocdf_gr_rr_VPR            ; data
      NCDF_VARPUT, ncid, 'GR_RR_rainrate_StdDev_VPR', tocdf_gr_rr_StdDev_VPR     ; data
      NCDF_VARPUT, ncid, 'GR_RR_rainrate_Max_VPR', tocdf_gr_rr_Max_VPR            ; data
   ENDIF
   NCDF_VARPUT, ncid, 'have_GR_RR_rainrate_VPR', have_gv_rr      ; data presence flag
   IF ( have_gv_zdr ) THEN BEGIN
      NCDF_VARPUT, ncid, 'GR_Zdr_VPR', tocdf_gr_zdr_VPR            ; data
      NCDF_VARPUT, ncid, 'GR_Zdr_StdDev_VPR', tocdf_gr_zdr_stddev_VPR     ; data
      NCDF_VARPUT, ncid, 'GR_Zdr_Max_VPR', tocdf_gr_zdr_max_VPR            ; data
   ENDIF
   NCDF_VARPUT, ncid, 'have_GR_Zdr_VPR', have_gv_zdr      ; data presence flag
   IF ( have_gv_kdp ) THEN BEGIN
      NCDF_VARPUT, ncid, 'GR_Kdp_VPR', tocdf_gr_kdp_VPR            ; data
      NCDF_VARPUT, ncid, 'GR_Kdp_StdDev_VPR', tocdf_gr_kdp_stddev_VPR     ; data
      NCDF_VARPUT, ncid, 'GR_Kdp_Max_VPR', tocdf_gr_kdp_max_VPR            ; data
   ENDIF
   NCDF_VARPUT, ncid, 'have_GR_Kdp_VPR', have_gv_kdp      ; data presence flag
   IF ( have_gv_rhohv ) THEN BEGIN
      NCDF_VARPUT, ncid, 'GR_RHOhv_VPR', tocdf_gr_rhohv_VPR            ; data
      NCDF_VARPUT, ncid, 'GR_RHOhv_StdDev_VPR', tocdf_gr_rhohv_stddev_VPR     ; data
      NCDF_VARPUT, ncid, 'GR_RHOhv_Max_VPR', tocdf_gr_rhohv_max_VPR            ; data
   ENDIF
   NCDF_VARPUT, ncid, 'have_GR_RHOhv_VPR', have_gv_rhohv      ; data presence flag
   IF ( have_gv_hid ) THEN BEGIN
      NCDF_VARPUT, ncid, 'GR_HID_VPR', tocdf_gr_hid_VPR            ; data
       NCDF_VARPUT, ncid, 'have_GR_HID_VPR', DATA_PRESENT      ; data presence flag
   ENDIF
   IF ( have_gv_dzero ) THEN BEGIN
      NCDF_VARPUT, ncid, 'GR_Dzero_VPR', tocdf_gr_dzero_VPR            ; data
      NCDF_VARPUT, ncid, 'GR_Dzero_StdDev_VPR', tocdf_gr_dzero_stddev_VPR     ; data
      NCDF_VARPUT, ncid, 'GR_Dzero_Max_VPR', tocdf_gr_dzero_max_VPR            ; data
   ENDIF
   NCDF_VARPUT, ncid, 'have_GR_Dzero_VPR', have_gv_dzero      ; data presence flag
   IF ( have_gv_nw ) THEN BEGIN
      NCDF_VARPUT, ncid, 'GR_Nw_VPR', tocdf_gr_nw_VPR            ; data
      NCDF_VARPUT, ncid, 'GR_Nw_StdDev_VPR', tocdf_gr_nw_stddev_VPR     ; data
      NCDF_VARPUT, ncid, 'GR_Nw_Max_VPR', tocdf_gr_nw_max_VPR            ; data
   ENDIF
   NCDF_VARPUT, ncid, 'have_GR_Nw_VPR', have_gv_nw      ; data presence flag
   IF ( have_gv_mw ) THEN BEGIN
      NCDF_VARPUT, ncid, 'GR_liquidWaterContent_VPR', tocdf_gr_mw_VPR            ; data
      NCDF_VARPUT, ncid, 'GR_liquidWaterContent_StdDev_VPR', tocdf_gr_mw_stddev_VPR     ; data
      NCDF_VARPUT, ncid, 'GR_liquidWaterContent_Max_VPR', tocdf_gr_mw_max_VPR            ; data
   ENDIF
   NCDF_VARPUT, ncid, 'have_GR_liquidWaterContent_VPR', have_gv_mw      ; data presence flag
   IF ( have_gv_mi ) THEN BEGIN
      NCDF_VARPUT, ncid, 'GR_frozenWaterContent_VPR', tocdf_gr_mi_VPR            ; data
      NCDF_VARPUT, ncid, 'GR_frozenWaterContent_StdDev_VPR', tocdf_gr_mi_stddev_VPR     ; data
      NCDF_VARPUT, ncid, 'GR_frozenWaterContent_Max_VPR', tocdf_gr_mi_max_VPR            ; data
   ENDIF
   NCDF_VARPUT, ncid, 'have_GR_frozenWaterContent_VPR', have_gv_mi      ; data presence flag
   IF ( have_gv_blockage ) THEN BEGIN
      NCDF_VARPUT, ncid, 'GR_blockage_VPR', tocdf_gr_blockage_VPR      ; data
   ENDIF
   NCDF_VARPUT, ncid, 'have_GR_blockage_VPR', have_gv_blockage      ; data presence flag
   
   NCDF_VARPUT, ncid, 'topHeight_vpr', tocdf_top_hgt_VPR
   NCDF_VARPUT, ncid, 'bottomHeight_vpr', tocdf_botm_hgt_VPR
   NCDF_VARPUT, ncid, 'n_gr_z_vpr_rejected', tocdf_gr_z_VPR_rejected
   NCDF_VARPUT, ncid, 'n_gr_rc_vpr_rejected', tocdf_gr_rc_VPR_rejected
   NCDF_VARPUT, ncid, 'n_gr_rp_vpr_rejected', tocdf_gr_rp_VPR_rejected
   NCDF_VARPUT, ncid, 'n_gr_rr_vpr_rejected', tocdf_gr_rr_VPR_rejected
   NCDF_VARPUT, ncid, 'n_gr_zdr_vpr_rejected', tocdf_gr_zdr_vpr_rejected
   NCDF_VARPUT, ncid, 'n_gr_kdp_vpr_rejected', tocdf_gr_kdp_vpr_rejected
   NCDF_VARPUT, ncid, 'n_gr_rhohv_vpr_rejected', tocdf_gr_rhohv_vpr_rejected
   NCDF_VARPUT, ncid, 'n_gr_hid_vpr_rejected', tocdf_gr_hid_vpr_rejected
   NCDF_VARPUT, ncid, 'n_gr_dzero_vpr_rejected', tocdf_gr_dzero_vpr_rejected
   NCDF_VARPUT, ncid, 'n_gr_nw_vpr_rejected', tocdf_gr_nw_vpr_rejected
   NCDF_VARPUT, ncid, 'n_gr_liquidWaterContent_vpr_rejected', tocdf_gr_mw_vpr_rejected
   NCDF_VARPUT, ncid, 'n_gr_frozenWaterContent_vpr_rejected', tocdf_gr_mi_vpr_rejected
   NCDF_VARPUT, ncid, 'n_gr_vpr_expected', tocdf_gr_VPR_expected

   NCDF_CLOSE, ncid

  ; gzip the finished netCDF file
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

   nextGVfile:

ENDFOR    ; each GR site for orbit

nextOrbit:

ENDWHILE  ; each orbit/GMI file set to process in control file

print, ""
print, "Done!"

bailOut:
CLOSE, lun0

END
