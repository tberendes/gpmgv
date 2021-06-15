;===============================================================================
;+
; Copyright © 2013, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; polar2dpr.pro          Morris/SAIC/GPM_GV      June 2013
;
; DESCRIPTION
; -----------
; Performs a resampling of DPR and GR data to common 3-D volumes, as defined in
; the horizontal by the location of DPR rays, and in the vertical by the heights
; of the intersection of the DPR rays with the top and bottom edges of individual
; elevation sweeps of a ground radar scanning in PPI mode.  The data domain is
; determined by the location of the ground radars overpassed by the DPR swath,
; and by the cutoff range (range_threshold_km) which is a mandatory parameter
; for this procedure.  The DPR and GR (ground radar) files to be processed are
; specified in the control_file, which is a mandatory parameter containing the
; fully-qualified file name of the control file to be used in the run.  Optional
; parameters (GPM_ROOT and DIRxx) allow for non-default local paths to the DPR and
; GR files whose partial pathnames are listed in the control file.  The defaults
; for these paths are as specified in the environs.inc file.  All file path
; optional parameter values must begin with a leading slash (e.g., '/mydata')
; and be enclosed in quotes, as shown.  Optional binary keyword parameters
; control immediate output of DPR-GR reflectivity differences (/SCORES), plotting
; of the matched DPR and GR reflectivity fields sweep-by-sweep in the form of
; PPIs on a map background (/PLOT_PPIS), and plotting of the matching DPR and GR
; bin horizontal outlines (/PLOT_BINS) for the common 3-D volume.
;
; The control file is of a specific layout and contains specific fields in a
; fixed order and format.  See the script "do_DPR_GeoMatch.sh", which
; creates the control file and invokes IDL to run this procedure.  Completed
; DPR and GR matchup data for an individual site overpass event (i.e., a given
; TRMM orbit and ground radar site) are written to a netCDF file.  The size of
; the dimensions in the data fields in the netCDF file vary from one case to
; another, depending on the number of elevation sweeps in the GR radar volume
; scan and the number of DPR footprints within the cutoff range from the GR site.
;
; The optional parameter NC_FILE specifies the directory to which the output
; netCDF files will be written.  It is created if it does not yet exist.  Its
; default value is derived from the variables NCGRIDS_ROOT+GEO_MATCH_NCDIR as
; specified in the environs.inc file.  If the binary parameter FLAT_NCPATH is
; set then the output netCDF files are written directly under the NC_FILE
; directory (legacy behavior).  Otherwise a hierarchical subdirectory tree is
; (as needed) created under the NC_FILE directory, of the form:
;     SATELLITE/2A_PRODUCT/SCANTYPE/PPS_VERSION/MATCHUP_VERSION/YEAR
; and the output netCDF files are written to this subdirectory.
;
; An optional parameter (NC_NAME_ADD) specifies a component to be added to the
; output netCDF file name, to specify uniqueness in the case where more than
; one version of input data are used, a different range threshold is used, etc.
;
; NOTE: THE SET OF CODE CONTAINED IN THIS FILE IS NOT THE COMPLETE POLAR2DPR
;       PROCEDURE.  THE REMAINING CODE IN THE FULL PROCEDURE IS CONTAINED IN
;       THE FILE "polar2dpr_resampling.pro", WHICH IS INCORPORATED INTO THIS
;       FILE/PROCEDURE BY THE IDL "include" MECHANISM.
;
;
; MODULES
; -------
;   1) FUNCTION  plot_bins_bailout  (this file)
;   2) PROCEDURE skip_gr_events     (this file)
;   3) PROCEDURE polar2dpr          (this file, with polar2dpr_resampling.pro)
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
; DPR: 1) Only GPM Ka, Ku, DPR, and COMB data files in HDF5 format are supported
;         by this code.
;      2) Only one instrument and scantype may be processed in a single run
;         (e.g., Ka-HS) since multiple DPR footprint geometries are not yet 
;         supported.
; GR:  1) Only radar data files in Universal Format (UF) are supported by this
;         code, although radar files in other formats supported by the Radar
;         Software Library (RSL) may work, depending on constraint 2, below.
;      2) UF files for sites not 'known' to this code must label their quality-
;         controlled reflectivity data field name as 'CZ'.  This constraint is
;         coded in the function common_utils/get_site_specific_z_volume.pro
;
;
; HISTORY
; -------
; 6/2013 by Bob Morris, GPM GV (SAIC)
;  - Created from polar2pr.pro.
; 7/24/13 by Bob Morris, GPM GV (SAIC)
;  - Added processing of GR rainrate field from radar data files, when present.
; 1/21/14 by Bob Morris, GPM GV (SAIC)
;  - Changed handling of 'DPR_Version' from Integer to String to match version
;    specification for GPM (e.g., "V01A").
;  - Added a second possible file pattern for the 2B-GPM-Combined file to handle
;    test data that has been provided.
;  - Updated structure element tags PRECIPTOTRATE and SURFPRECIPTOTRATE for data
;    read from 2B-GPM-Combined.
; 3/31/14 by Bob Morris, GPM GV (SAIC)
;  - Fixed origFileKaName cut/paste errors in first CASE statement.
; 4/4/14 by Bob Morris, GPM GV (SAIC)
;  - Changed handling of file pathnames in control file.  Adding all the GR
;    dual-pol fields to the matchups.
; 5/2/14 by Bob Morris, GPM GV (SAIC)
;  - Fixed handling of file pathnames from control file in no_XXXX_file cases.
; 6/24/14 by Bob Morris, GPM GV (SAIC)
;  - Added processing of DPR Dm and Nw fields taken from the paramDSD variable
;    in the DPR data files.
; 8/1/14 by Bob Morris, GPM GV (SAIC)
;  - Added logic to determine if there is any non-missing GR data for the orbit
;    before trying to read the DPR and GR files.  If not, then save time and
;    just skip over the orbit's entries in the control file without reading any
;    data files.
; 11/04/14 by Bob Morris, GPM GV (SAIC)
;  - Added processing of GR RC and RP rainrate fields for version 1.1 file.
; 11/19/14 by Bob Morris, GPM GV (SAIC)
;  - Added assignment of ELLIPSOID_BIN_DPR to ELLIPSOID_BIN_HS or
;    ELLIPSOID_BIN_NS_MS depending on swath, for 2ADPR/2AKu/2AKa ellipsoid
;    fixed gate positions.
; 12/03/14 by Bob Morris, GPM GV (SAIC)
;  - Handle situation of no paramDSD field present in SLV group (2ADPR/MS).
; 12/26/14 by Bob Morris, GPM GV (SAIC)
;  - Added NON_PPS_FILES binary keyword parameter to ignore expected PPS
;    filename convention for GPM product filenames in control file when set.
; 02/05/15 by Bob Morris, GPM GV (SAIC)
;  - Moved assignment of DR_KD_MISSING out of conditional blocks so that it is
;    always defined, as required.
; 02/27/15 by Bob Morris, GPM GV (SAIC)
;  - Added DPR heightStormTop and piaFinal fields to version 1.1 file.
; 03/02/15 by Bob Morris, GPM GV (SAIC)
;  - Added FLAT_NCPATH parameter to control whether we generate the hierarchical
;    netCDF output file paths (default) or continue to write the netCDF files to
;    the "flat" directory defined by NC_DIR or NCGRIDS_ROOT+GEO_MATCH_NCDIR (if
;    FLAT_NCPATH is set to 1).
; 03/05/15 by Bob Morris, GPM GV (SAIC)
; - Changed the hard-coded assignment of the non-Z ufstruct field IDs to instead
;   use the field ID returned by get_site_specific_z_volume(), so that when a
;   substitution for our standard UF ID happens, the structure reflects the UF
;   field that actually exists in, and was read from, the UF file.
; 03/23/15 by Bob Morris, GPM GV (SAIC)
;  - Changed data type of tocdf_rayNum to short INT (FIX) to match data type as
;    defined in the netCDF file.
; 07/13/15 by Bob Morris, GPM GV (SAIC)
;  - Added DECLUTTER parameter to control whether we generate an internal
;    clutter flag for the DPR full-resolution reflectivity gates and use it to
;    identify and exclude these gates from the DPR volume average reflectivity.
; 08/20/15 by Bob Morris, GPM GV (SAIC)
;  - Added processing of GR Dm and N2 dual-pol fields.
; 11/05/15 by Bob Morris, GPM GV (SAIC)
;  - Added DIR_BLOCK parameter and related processing of GR_blockage variable
;    and its presence flag for version 1.21 file.
; 03/02/16 by Bob Morris, GPM GV (SAIC)
;  - Added calls to STRTRIM for STRING variables read from control file.
; 03/17/16 by Bob Morris, GPM GV (SAIC)
;  - Moved copy, reassign of binRealSurface out of polar2dpr_resampling.pro and
;    into this code file, as it needs to be done only once for a given 2A file.
; 07/29/16 by Bob Morris, GPM GV (SAIC)
;  - Added DPR epsilon and n_dpr_epsilon_rejected variables and its presence
;    flag for updated version 1.21.
; 12/14/16 by Bob Morris, GPM GV (SAIC)
;  - Added processing of overlooked qualityData variable which was already
;    in the netCDF file definition but never populated.
; 10/18/17 by Bob Morris, GPM GV (SAIC)
;  - Added capability to process TRMM Version 8 2APR matchups.  Added new
;    keyword parameters TRMM_ROOT, DIRPR and DIRCMBPRTMI to point to non-default
;    subdirectories for these products.
;
; EMAIL QUESTIONS OR COMMENTS AT:
;       https://pmm.nasa.gov/contact
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

PRO polar2dpr, control_file, range_threshold_km, DIRGV=dirgv, GPM_ROOT=gpmroot, $
               DIRDPR=dir2adpr, DIRKU=dir2aku, DIRKA=dir2aka, DIRCOMB=dircomb, $
               TRMM_ROOT=trmmroot, DIRPR=dir2apr, DIRCMBPRTMI=dir2bprtmi, $
               SCORES=run_scores, PLOT_PPIS=plot_PPIs, PLOT_BINS=plot_bins, $
               NC_DIR=nc_dir, NC_NAME_ADD=ncnameadd, MARK_EDGES=mark_edges, $
               DPR_DBZ_MIN=dpr_dbz_min, DBZ_MIN=dBZ_min, $
               DPR_RAIN_MIN=dpr_rain_min, NON_PPS_FILES=non_pps_files, $
               FLAT_NCPATH=flat_ncpath, DECLUTTER=declutter, DIR_BLOCK=dir_block

IF KEYWORD_SET(plot_bins) THEN BEGIN
   reply = plot_bins_bailout()
   IF reply EQ 'Y' THEN plot_bins = 0
ENDIF

IF N_ELEMENTS( mark_edges ) EQ 1 THEN BEGIN
   IF mark_edges NE 0 THEN mark_edges=1
ENDIF ELSE mark_edges = 0

decluttered = KEYWORD_SET(declutter)

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

 COMMON sample, start_sample, sample_range, num_range, RAYSPERSCAN

; "Include" file for DATA_PRESENT, NO_DATA_PRESENT
@grid_def.inc
; "Include" file for DPR-product-specific parameters (i.e., RAYSPERSCAN):
@dpr_params.inc
; "Include" file for names, paths, etc.:
@environs.inc

; set to a constant, until database supports DPR product version override values
DPR_version = '0'


; ***************************** Local configuration ****************************

   ; where provided, override file path default values from environs.inc:
    in_base_dir =  GVDATA_ROOT ; default root dir for UF files
    IF N_ELEMENTS(dirgv)  EQ 1 THEN in_base_dir = dirgv

    IF N_ELEMENTS(gpmroot)  EQ 1 THEN GPMDATA_ROOT = gpmroot
    IF N_ELEMENTS(dir2adpr) EQ 1 THEN DIR_2ADPR = dir2adpr
    IF N_ELEMENTS(dir2aku)  EQ 1 THEN DIR_2AKU = dir2aku
    IF N_ELEMENTS(dir2aka)  EQ 1 THEN DIR_2AKA = dir2aka
    IF N_ELEMENTS(dircomb)  EQ 1 THEN DIR_COMB = dircomb
    IF N_ELEMENTS(trmmroot)  EQ 1 THEN TRMMDATA_ROOT = trmmroot
    IF N_ELEMENTS(dir2apr)  EQ 1 THEN DIR_2APR = dir2apr
    IF N_ELEMENTS(dir2bprtmi) EQ 1 THEN DIR_2BPRTMI = dir2bprtmi
    
    IF N_ELEMENTS(nc_dir)  EQ 1 THEN BEGIN
       NCGRIDSOUTDIR = nc_dir
    ENDIF ELSE BEGIN
       NCGRIDSOUTDIR = NCGRIDS_ROOT+GEO_MATCH_NCDIR
    ENDELSE

   ; tally number of reflectivity bins below this dBZ value in DPR Z averages
    IF N_ELEMENTS(dpr_dbz_min) NE 1 THEN BEGIN
       dpr_dbz_min = 18.0
       PRINT, "Assigning default value of 18 dBZ to DPR_DBZ_MIN."
    ENDIF
   ; tally number of reflectivity bins below this dBZ value in GR Z averages
    IF N_ELEMENTS(dBZ_min) NE 1 THEN BEGIN
       dBZ_min = 15.0   ; low-end GR cutoff, for now
       PRINT, "Assigning default value of 15 dBZ to DBZ_MIN for ground radar."
    ENDIF
   ; tally number of rain rate bins (mm/h) below this value in DPR rr averages
    IF N_ELEMENTS(dpr_rain_min) NE 1 THEN BEGIN
       DPR_RAIN_MIN = 0.01
       PRINT, "Assigning default value of 0.01 mm/h to DPR_RAIN_MIN."
    ENDIF

; ******************************************************************************


; will skip processing DPR points beyond this distance from a ground radar
rough_threshold = range_threshold_km * 1.1

; initialize the variables into which file records are read as strings
dataPR = ''
dataGR = ''

; open and process control file, and generate the matchup data for the events

OPENR, lun0, control_file, ERROR=err, /GET_LUN
WHILE NOT (EOF(lun0)) DO BEGIN 

  ; get DPR filenames and count of GR file pathnames to do for an orbit
  ; - read the '|'-delimited input file record into a single string:
   READF, lun0, dataPR

  ; parse dataPR into its component fields: orbit number, number of sites,
  ; YYMMDD, orbit subset, DPR version, GPM instrument ID, DPR scan type,
  ; 2ADPR file name, 2AKU file name, 2AKA file name, 2BCMB file name.  All of
  ; the first 7 fields must be included in the control file in the order shown,
  ; and at least one valid 2ADPR file name, 2AKU file name, or 2AKA file name
  ; must be included and match the value of 'Instrument_ID'.  The 2BCMB file name
  ; is optional, depending on whether the Combined GMI-DPR rainrate data are to
  ; be included in the output matchup dataset.

  ; -- Instrument_ID is the part of the algorithm name with the data level
  ;    stripped off.  For example, for algorithm '2ADPR', Instrument_ID = 'DPR'.
  ;    In the PPS file name convention, this would match to a filename beginning
  ;    with the literal field "2A.GPM.DPR" (DataLevel.Satellite.Intrument_ID)

   parsed=STRSPLIT( dataPR, '|', /extract )
   parseoffset = 0
   IF N_ELEMENTS(parsed) LT 8 THEN message, $
      "Incomplete DPR line in control file: "+dataPR

   orbit = parsed[0]
   nsites = FIX( parsed[1] )
   IF (nsites LE 0 OR nsites GT 99) THEN BEGIN
      PRINT, "Illegal number of GR sites in control file: ", parsed[1]
      PRINT, "Line: ", dataPR
      PRINT, "Quitting processing."
      GOTO, bailOut
   ENDIF

   DATESTAMP = parsed[2]           ; in YYMMDD format
   subset = parsed[3]
   DPR_version = parsed[4]
   Instrument_ID = parsed[5]       ; 2A algorithm/product: PR, Ka, Ku, or DPR
   DPR_scantype = parsed[6]        ; HS, MS, or NS


  ; set up the date/product-specific output filepath
  ; Note we won't use this if the FLAT_NCPATH keyword is set

   matchup_file_version=0.0  ; give it a bogus value, for now
  ; Call gen_geo_match_netcdf with the option to only get current file version
  ; so that it can become part of the matchup file name
   throwaway = gen_dpr_geo_match_netcdf( GEO_MATCH_VERS=matchup_file_version )

  ; separate version into integer and decimal parts, with 2 decimal places
   verarr=strsplit(string(matchup_file_version,FORMAT='(F0.2)'),'.',/extract)
  ; strip trailing zero from version string decimal part, if any
   verarr1_len = STRLEN(verarr[1])
   IF verarr1_len GT 1 and STRMID(verarr[1], verarr1_len-1, 1) EQ '0' $
      THEN verarr[1]=strmid(verarr[1], 0, l-1)
  ; substitute an underscore for the decimal point in matchup_file_version
   verstr=verarr[0]+'_'+verarr[1]

  ; generate the netcdf matchup file path
   IF KEYWORD_SET(flat_ncpath) THEN BEGIN
      NC_OUTDIR = NCGRIDSOUTDIR
   ENDIF ELSE BEGIN
      IF Instrument_ID EQ 'PR' THEN SAT_DIR = '/TRMM' ELSE SAT_DIR = '/GPM'
      NC_OUTDIR = NCGRIDSOUTDIR+SAT_DIR+'/2A'+Instrument_ID+'/'+DPR_scantype+'/'+ $
                  DPR_version+'/'+verstr+'/20'+STRMID(DATESTAMP, 0, 2)  ; 4-digit Year
   ENDELSE


  ; get filenames as listed in/on the database/disk
   IF KEYWORD_SET(non_pps_files) THEN BEGIN
      origFileDPRName='no_2ADPR_file'
      origFileKaName='no_2AKA_file'
      origFileKuName='no_2AKU_file'
      origFileCMBName = 'no_2BCMB_file'
      origFilePRName = 'no_2APR_file'
      origFile2BPRTMIName = 'no_2BPRTMI_file'
      ; don't expect a PPS-type filename, just set file based on Instrument_ID
      DPR_filepath = STRTRIM(parsed[7],2)
      CASE Instrument_ID OF
         'DPR' : origFileDPRName = DPR_filepath
          'Ka' : origFileKaName = DPR_filepath
          'Ku' : origFileKuName = DPR_filepath
          'PR' : origFilePRName = DPR_filepath
          ELSE : BEGIN
                    print, "Error(s) in DPR/Ka/Ku/PR control file specification."
                    PRINT, "Line: ", dataPR
                    PRINT, "Skipping events for orbit = ", orbit
                    skip_gr_events, lun0, nsites
                    PRINT, ""
                    GOTO, nextOrbit
                 END
      ENDCASE
   ENDIF ELSE BEGIN
      ; expect a PPS-type filename, check for it
      idxPROD = WHERE(STRMATCH(parsed, '*2A*.GPM.DPR*', /FOLD_CASE) EQ 1, countPROD)
      if countPROD EQ 1 THEN origFileDPRName = STRTRIM(parsed[idxPROD],2) $
         ELSE origFileDPRName='no_2ADPR_file'
      idxPROD = WHERE(STRMATCH(parsed,'*2A*.GPM.Ku*', /FOLD_CASE) EQ 1, countPROD)
      if countPROD EQ 1 THEN origFileKuName = STRTRIM(parsed[idxPROD],2) $
         ELSE origFileKuName='no_2AKU_file'
      idxPROD = WHERE(STRMATCH(parsed,'*2A*.GPM.Ka*', /FOLD_CASE) EQ 1, countPROD)
      if countPROD EQ 1 THEN origFileKaName = STRTRIM(parsed[idxPROD],2) $
         ELSE origFileKaName='no_2AKA_file'
      idxPROD = WHERE(STRMATCH(parsed,'*2B*.GPM.DPRGMI*', /FOLD_CASE) EQ 1, countPROD)
      IF countPROD EQ 1 THEN origFileCMBName = STRTRIM(parsed[idxPROD],2) $
                       ELSE origFileCMBName = 'no_2BCMB_file'
      idxPROD = WHERE(STRMATCH(parsed, '*2A*.TRMM.PR*', /FOLD_CASE) EQ 1, countPROD)
      if countPROD EQ 1 THEN origFilePRName = STRTRIM(parsed[idxPROD],2) $
         ELSE origFilePRName='no_2APR_file'
      idxPROD = WHERE(STRMATCH(parsed,'*2B*.TRMM.PRTMI*', /FOLD_CASE) EQ 1, countPROD)
      IF countPROD EQ 1 THEN origFile2BPRTMIName = STRTRIM(parsed[idxPROD],2) $
                       ELSE origFile2BPRTMIName = 'no_2BPRTMI_file'
      IF (  origFileKaName EQ 'no_2AKA_file' AND $
            origFileKuName EQ 'no_2AKU_file' AND $
           origFileDPRName EQ 'no_2ADPR_file' AND $
            origFilePRName EQ 'no_2APR_file' ) THEN BEGIN
         PRINT, ""
         PRINT, "ERROR finding a 2A-PR, 2A-DPR, 2A-KA , or 2A-KU product file name", $
                " in control file: ", control_file
         PRINT, "Line: ", dataPR
         PRINT, "Skipping events for orbit = ", orbit
         skip_gr_events, lun0, nsites
         PRINT, ""
         GOTO, nextOrbit
      ENDIF
   ENDELSE

   dataGRarr = STRARR( nsites )   ; array to store GR-type control file lines
   numUFgood = 0
   FOR igv=0,nsites-1  DO BEGIN
     ; read and parse the control file GR filename to determine which lines
     ; have "actual" GR data file names
     ;  - read each overpassed site's information as a '|'-delimited string
      READF, lun0, dataGR
      dataGRarr[igv] = dataGR      ; write the whole line to the string array
      PRINT, igv+1, ": ", dataGR

     ; parse dataGR to get its 1CUF file pathname, and increment numUFgood
     ; count for each non-missing UF file anme

      parsed=STRSPLIT( dataGR, '|', count=nGRfields, /extract )
      CASE nGRfields OF
        9 : BEGIN   ; legacy control file format
              origUFName = parsed[8]  ; filename as listed in/on the database/disk
              IF file_basename(origUFName) NE 'no_1CUF_file' THEN numUFgood++
            END
        6 : BEGIN   ; streamlined control file format, already have orbit #
              origUFName = parsed[5]  ; filename as listed in/on the database/disk
              IF file_basename(origUFName) NE 'no_1CUF_file' THEN numUFgood++
            END
        ELSE : BEGIN
                 print, ""
                 print, "Incorrect number of GR-type fields in control file:"
                 print, dataGR
                 print, ""
               END
      ENDCASE
   ENDFOR

  ; if there are no good ground radar files, don't even bother reading DPR,
  ; just skip to the next orbit's control file information
   IF numUFgood EQ 0 THEN BEGIN
      PRINT, "No non-missing UF files, skip processing for orbit = ", orbit
      PRINT, ""
      GOTO, nextOrbit
   ENDIF

;  Add the static common (local) paths to get the fully-qualified file names.
;  GPMDATA_ROOT is /data/gpmgv/orbit_subset/GPM, the Instrument/Algorithm parts
;  of the paths are well-known or provided as overrides. The orig* filenames
;  then must have the following components in their pathname structure in the
;  control file:

;       version/subset/yyyy/mm/dd/filebasename

   file_2adpr = GPMDATA_ROOT+DIR_2ADPR+"/"+origFileDPRName
   file_2aku  = GPMDATA_ROOT+DIR_2AKU+"/"+origFileKuName
   file_2aka  = GPMDATA_ROOT+DIR_2AKA+"/"+origFileKaName
   file_2bcmb = GPMDATA_ROOT+DIR_COMB+"/"+origFileCMBName
   file_2apr = TRMMDATA_ROOT+DIR_2APR+"/"+origFilePRName
   file_2bprtmi = TRMMDATA_ROOT+DIR_2BPRTMI+"/"+origFile2BPRTMIName

   DO_RAIN_CORR = 1   ; set flag to do 3-D rain_corr processing by default

   ; check Instrument_ID, filename, and DPR_scantype consistency
   CASE STRUPCASE(Instrument_ID) OF
       'KA' : BEGIN
                 ; do we have a 2AKA filename?
                 IF FILE_BASENAME(origFileKaName) EQ 'no_2AKA_file' THEN $
                    message, "KA specified on control file line, but no " + $
                             "valid 2A-KA file name: " + dataPR
                 ; 2AKA has only HS and MS scan/swath types
                 CASE STRUPCASE(DPR_scantype) OF
                    'HS' : BEGIN
                              RAYSPERSCAN = RAYSPERSCAN_HS
                              GATE_SPACE = BIN_SPACE_HS
                              ELLIPSOID_BIN_DPR = ELLIPSOID_BIN_HS
                           END
                    'MS' : BEGIN
                              RAYSPERSCAN = RAYSPERSCAN_MS
                              GATE_SPACE = BIN_SPACE_NS_MS
                              ELLIPSOID_BIN_DPR = ELLIPSOID_BIN_NS_MS
                           END
                    ELSE : message,"Illegal scan type '"+DPR_scantype+"' for KA"
                 ENDCASE
                 print, '' & print, "Reading file: ", file_2aka & print, ''
                 dpr_data = read_2akaku_hdf5(file_2aka, SCAN=DPR_scantype)
                 dpr_file_read = origFileKaName
              END
       'KU' : BEGIN
                 IF FILE_BASENAME(origFileKuName) EQ 'no_2AKU_file' THEN $
                    message, "KU specified on control file line, but no " + $
                             "valid 2A-KU file name: " + dataPR
                 ; 2AKU has only NS scan/swath type
                 CASE STRUPCASE(DPR_scantype) OF
                    'NS' : BEGIN
                              print, '' & print, "Reading file: ", file_2aku
                              print, ''
                              dpr_data = read_2akaku_hdf5(file_2aku, $
                                         SCAN=DPR_scantype)
                              dpr_file_read = origFileKuName
                              RAYSPERSCAN = RAYSPERSCAN_NS
                              GATE_SPACE = BIN_SPACE_NS_MS
                              ELLIPSOID_BIN_DPR = ELLIPSOID_BIN_NS_MS
                           END
                    ELSE : message,"Illegal scan type '"+DPR_scantype+"' for KU"
                  ENDCASE            
              END
      'DPR' : BEGIN
                 IF FILE_BASENAME(origFileDPRName) EQ 'no_2ADPR_file' THEN $
                    message, "DPR specified on control file line, but no " + $
                             "valid 2ADPR file name: " + dataPR
                 ; 2ADPR has all 3 scan/swath types
                 CASE STRUPCASE(DPR_scantype) OF
                    'HS' : BEGIN
                              RAYSPERSCAN = RAYSPERSCAN_HS
                              GATE_SPACE = BIN_SPACE_HS
                              ELLIPSOID_BIN_DPR = ELLIPSOID_BIN_HS
                           END
                    'MS' : BEGIN
                              RAYSPERSCAN = RAYSPERSCAN_MS
                              GATE_SPACE = BIN_SPACE_NS_MS
                              ELLIPSOID_BIN_DPR = ELLIPSOID_BIN_NS_MS
                              DO_RAIN_CORR = 0   ; set flag to skip 3-D rainrate
                           END
                    'NS' : BEGIN
                              RAYSPERSCAN = RAYSPERSCAN_NS
                              GATE_SPACE = BIN_SPACE_NS_MS
                              ELLIPSOID_BIN_DPR = ELLIPSOID_BIN_NS_MS
                           END
                    ELSE : message, "Illegal scan type '"+DPR_scantype+"'"
                 ENDCASE
                 print, '' & print, "Reading file: ", file_2adpr & print, ''
                 dpr_data = read_2adpr_hdf5(file_2adpr, SCAN=DPR_scantype)
                 dpr_file_read = origFileDPRName
              END
       'PR' : BEGIN
                 IF FILE_BASENAME(origFilePRName) EQ 'no_2APR_file' THEN $
                    message, "PR specified on control file line, but no " + $
                             "valid 2A-PR file name: " + dataPR
                 ; 2APR has only NS scan/swath type
                 CASE STRUPCASE(DPR_scantype) OF
                    'NS' : BEGIN
                              print, '' & print, "Reading file: ", file_2apr
                              print, ''
                              dpr_data = read_2akaku_hdf5(file_2apr, $
                                         SCAN=DPR_scantype)
                              dpr_file_read = origFilePRName
                              RAYSPERSCAN = RAYSPERSCAN_NS
                              GATE_SPACE = BIN_SPACE_NS_MS
                              ELLIPSOID_BIN_DPR = ELLIPSOID_BIN_NS_MS
                           END
                    ELSE : message,"Illegal scan type '"+DPR_scantype+"' for PR"
                  ENDCASE            
              END
   ENDCASE

   ; check dpr_data structure for read failures
   IF SIZE(dpr_data, /TYPE) NE 8 THEN $
     message, "Error reading data from: "+dpr_file_read $
   ELSE PRINT, "Extracting data fields from structure."
   print, ''

   ; get the group structures for the specified scantype, tags vary by swathname
   CASE STRUPCASE(DPR_scantype) OF
      'HS' : ptr_swath = dpr_data.HS
      'MS' : ptr_swath = dpr_data.MS
      'NS' : ptr_swath = dpr_data.NS
   ENDCASE
   ; get the number of scans in the dataset
   SAMPLE_RANGE = ptr_swath.SWATHHEADER.NUMBERSCANSBEFOREGRANULE $
                + ptr_swath.SWATHHEADER.NUMBERSCANSGRANULE $
                + ptr_swath.SWATHHEADER.NUMBERSCANSAFTERGRANULE

   ; extract DPR variables/arrays from struct pointers
   IF PTR_VALID(ptr_swath.PTR_DATASETS) THEN BEGIN
      prlons = (*ptr_swath.PTR_DATASETS).LONGITUDE
      prlats = (*ptr_swath.PTR_DATASETS).LATITUDE
      ptr_free, ptr_swath.PTR_DATASETS
   ENDIF ELSE message, "Invalid pointer to PTR_DATASETS."

   IF PTR_VALID(ptr_swath.PTR_CSF) THEN BEGIN
      BB_hgt = (*ptr_swath.PTR_CSF).HEIGHTBB
      bbstatus = (*ptr_swath.PTR_CSF).QUALITYBB       ; got to convert to TRMM?
      rainType = (*ptr_swath.PTR_CSF).TYPEPRECIP      ; got to convert to TRMM?
   ENDIF ELSE message, "Invalid pointer to PTR_CSF."
   idxrntypedefined = WHERE(rainType GE 0, countrndef)
   IF countrndef GT 0 THEN rainType[idxrntypedefined] = $
      rainType[idxrntypedefined]/10000000L      ; truncate to TRMM 3-digit type

;   IF PTR_VALID(ptr_swath.PTR_DSD) THEN BEGIN
;   ENDIF ELSE message, "Invalid pointer to PTR_DSD."

   IF PTR_VALID(ptr_swath.PTR_FLG) THEN BEGIN
      qualityData = (*ptr_swath.PTR_FLG).QUALITYDATA  ; new variable to deal with
   ENDIF ELSE message, "Invalid pointer to PTR_FLG."

   IF PTR_VALID(ptr_swath.PTR_PRE) THEN BEGIN
      dbz_meas = (*ptr_swath.PTR_PRE).ZFACTORMEASURED
      binRealSurface = (*ptr_swath.PTR_PRE).BINREALSURFACE
      binClutterFreeBottom = (*ptr_swath.PTR_PRE).binClutterFreeBottom
      landOceanFlag = (*ptr_swath.PTR_PRE).LANDSURFACETYPE
      rainFlag = (*ptr_swath.PTR_PRE).FLAGPRECIP
      localZenithAngle = (*ptr_swath.PTR_PRE).localZenithAngle
      heightStormTop = (*ptr_swath.PTR_PRE).heightStormTop
      ptr_free, ptr_swath.PTR_PRE
   ENDIF ELSE message, "Invalid pointer to PTR_PRE."

   IF PTR_VALID(ptr_swath.PTR_SLV) THEN BEGIN
      dbz_corr = (*ptr_swath.PTR_SLV).ZFACTORCORRECTED
      rain_corr = (*ptr_swath.PTR_SLV).PRECIPRATE
      surfRain_corr = (*ptr_swath.PTR_SLV).PRECIPRATEESURFACE
      piaFinal = (*ptr_swath.PTR_SLV).piaFinal
      epsilon = (*ptr_swath.PTR_SLV).EPSILON
      ; MS swath in 2A-DPR product does not have paramDSD, deal with it here
      ; - if there is no paramDSD its structure element is the string "UNDEFINED"
      type_paramdsd = SIZE( (*ptr_swath.PTR_SLV).PARAMDSD, /TYPE )
      IF type_paramdsd EQ 7 THEN BEGIN
         have_paramdsd = 0
      ENDIF ELSE BEGIN
         have_paramdsd = 1
         dpr_Nw = REFORM( (*ptr_swath.PTR_SLV).PARAMDSD[0,*,*,*] )
         dpr_Dm = REFORM( (*ptr_swath.PTR_SLV).PARAMDSD[1,*,*,*] )
      ENDELSE
      ptr_free, ptr_swath.PTR_SLV
   ENDIF ELSE message, "Invalid pointer to PTR_SLV."

   IF PTR_VALID(ptr_swath.PTR_SRT) THEN BEGIN
   ENDIF ELSE message, "Invalid pointer to PTR_SRT."

   IF PTR_VALID(ptr_swath.PTR_VER) THEN BEGIN
   ENDIF ELSE message, "Invalid pointer to PTR_VER."

   ; free the remaining memory/pointers in data structure
   free_ptrs_in_struct, dpr_data ;, /ver

  ; make a copy of binRealSurface and set all values to the fixed
  ; bin number at the ellipsoid for the swath being processed.
   binEllipsoid = binRealSurface
   binEllipsoid[*,*] = ELLIPSOID_BIN_DPR

; NOTE THAT THE TRMM ARRAYS ARE IN (SCAN,RAY) COORDINATES, WHILE ALL GPM
; ARRAYS ARE IN (RAY,SCAN) COORDINATE ORDER.  NEED TO ACCOUNT FOR THIS WHEN
; ADDRESSING DATASETS BY ARRAY INDICES.

   dpr_index_all = LINDGEN(SIZE(rainFlag, /DIMENSIONS))

   ; precompute the reuseable ray angle trig variables for parallax -- in GPM,
   ; we have the local zenith angle for every ray/scan (i.e., footprint)
   cos_inc_angle = COS( 3.1415926D * localZenithAngle / 180. )
   tan_inc_angle = TAN( 3.1415926D * localZenithAngle / 180. )


; read 2BCMB rainrate field
; The following test allows DPR processing to proceed without the
; 2BCMB data file being available.

   IF Instrument_ID EQ 'PR' THEN BEGIN
     ; 2BPRTMI files do not exist yet, set flag to false
      havefile2bcmb = 0
   ENDIF ELSE BEGIN
     ; see whether we have, and can read, the 2BDPRGMI product
      havefile2bcmb = 1
      IF ( FILE_BASENAME(origFileCMBName) EQ 'no_2BCMB_file' OR DPR_scantype EQ 'HS') THEN BEGIN
         IF FILE_BASENAME(origFileCMBName) EQ 'no_2BCMB_file' THEN msgpref = "No 2BCMB file" $
         ELSE msgpref = "No 'HS' swath in 2BCMB files"
         PRINT, ""
         PRINT, msgpref,", skipping 2BCMB processing for orbit = ", orbit
         PRINT, ""
         havefile2bcmb = 0
      ENDIF ELSE BEGIN
         print, '' & print, "Reading file: ", file_2bcmb & print, ''
         data_COMB = read_2bcmb_hdf5( file_2bcmb, SCAN=DPR_scantype)
         IF SIZE(data_COMB, /TYPE) NE 8 THEN BEGIN
            PRINT, ""
            PRINT, "ERROR reading fields from ", file_2bcmb
            PRINT, "Skipping 2BCMB processing for orbit = ", orbit
            PRINT, ""
         havefile2bcmb = 0
         ENDIF ELSE BEGIN
           ; get the group structure for the specified scantype, tags vary by swath
           CASE STRUPCASE(DPR_scantype) OF
             'HS' : message, "Logic error, how did we get here?"
             'MS' : ptr_swath_COMB = data_COMB.MS
             'NS' : ptr_swath_COMB = data_COMB.NS
           ENDCASE
            ; pull surfPrecipRate out of data structure and assign to surfRain_2bcmb
            PRINT, "Extracting data fields from structure."
            print, ''
            IF PTR_VALID(ptr_swath_COMB.PTR_DATASETS) THEN BEGIN
               lat_COMB = (*ptr_swath_COMB.PTR_DATASETS).LATITUDE
               rain_COMB = (*ptr_swath_COMB.PTR_DATASETS).PRECIPTOTRATE
               surfRain_2bcmb = (*ptr_swath_COMB.PTR_DATASETS).SURFPRECIPTOTRATE
               ; free the memory/pointers in data structure
               free_ptrs_in_struct, data_COMB ;, /ver
            ENDIF ELSE message, "Invalid pointer to '"+DPR_scantype+"' group."
         
            ; verify that we are looking at the same subset of scans
            ; (size-wise, anyway) between the DPR and 2bcmb product
            IF N_ELEMENTS(prlats) NE N_ELEMENTS(lat_COMB) THEN BEGIN
               PRINT, ""
               PRINT, "Mismatch between #scans in ", file_2bcmb, " and ", dpr_file_read
               PRINT, "Skipping 2BCMB processing for orbit = ", orbit
               PRINT, ""
               havefile2bcmb = 0
            ENDIF
         ENDELSE
      ENDELSE
   ENDELSE

   lastsite = ""
FOR igv=0,nsites-1  DO BEGIN
  ; parse the control file lines for GR site ID, lat, lon, elev, filename, etc.
  ;  - grab each overpassed site's information from the string array
   dataGR = dataGRarr[igv]
  ; parse dataGR into its component fields: event_num, orbit number, siteID,
  ; overpass datetime, time in ticks, site lat, site lon, site elev,
  ; 1CUF file unique pathname

   parsed=STRSPLIT( dataGR, '|', count=nGRfields, /extract )
   CASE nGRfields OF
     9 : BEGIN   ; legacy control file format
           event_num = LONG( parsed[0] )
           orbit = STRTRIM(parsed[1],2)
           siteID = STRTRIM(parsed[2],2)    ; GPMGV siteID
           dpr_dtime = STRTRIM(parsed[3],2)
           dpr_dtime_ticks = STRTRIM(parsed[4],2)
           siteLat = FLOAT( parsed[5] )
           siteLon = FLOAT( parsed[6] )
           siteElev = FLOAT( parsed[7] )
           origUFName = STRTRIM(parsed[8],2)  ; filename as listed in/on the database/disk
         END
     6 : BEGIN   ; streamlined control file format, already have orbit #
           siteID = STRTRIM(parsed[0],2)    ; GPMGV siteID
           dpr_dtime = STRTRIM(parsed[1],2)
           dpr_dtime_ticks = ticks_from_datetime( dpr_dtime )
           IF STRING(dpr_dtime_ticks) EQ "Bad Datetime" THEN BEGIN
              print, ""
              print, "Bad overpass datetime field in control file:"
              print, dataGR
              print, "Skipping site event." & print, ""
              GOTO, nextGRfile
           END
           siteLat = FLOAT( parsed[2] )
           siteLon = FLOAT( parsed[3] )
           siteElev = FLOAT( parsed[4] )
           origUFName = STRTRIM(parsed[5],2)  ; filename as listed in/on the database/disk
         END
     ELSE : BEGIN
           print, ""
           print, "Incorrect number of GR-type fields in control file:"
           print, dataGR
           print, "Skipping site event." & print, ""
           GOTO, nextGRfile
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
      GOTO, nextGRfile
   ENDIF
   IF ( siteID EQ lastsite ) THEN BEGIN
      PRINT, "Multiple 1CUF files for orbit = ", orbit, ", site = ", $
              siteID, ", skipping."
      lastsite = siteID
      GOTO, nextGRfile
   ENDIF
   lastsite = siteID

   PRINT, igv+1, ": ", dpr_dtime, "  ", siteID, siteLat, siteLon
;   PRINT, igv+1, ": ", file_1CUF

  ; initialize a gv-centered map projection for the ll<->xy transformations:
   sMap = MAP_PROJ_INIT( 'Azimuthal Equidistant', center_latitude=siteLat, $
                         center_longitude=siteLon )
  ; DPR-site latitude and longitude differences for coarse filter
   max_deg_lat = rough_threshold / 111.1
   max_deg_lon = rough_threshold / (cos(!DTOR*siteLat) * 111.1 )

  ; copy/unzip/open the UF file and read the entire volume scan into an
  ;   RSL_in_IDL radar structure, and then close UF file and delete copy:

   status=get_rsl_radar(file_1CUF, radar)
   IF ( status NE 0 )  THEN BEGIN
      PRINT, ""
      PRINT, "Error reading radar structure from file ", file_1CUF
      PRINT, ""
      GOTO, nextGRfile
   ENDIF

  ; set up the structure holding the UF IDs for the fields we find in this file
  ; - the default values in this structure must be coordinated with those
  ;   defined in gen_gprof_geo_match_netcdf.pro
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
              DM_ID:    'Unspecified', $
              N2_ID:    'Unspecified' }

  ; need to define this parameter whether or not KD or DR volumes are present
   DR_KD_MISSING = (radar_dp_parameters()).DR_KD_MISSING
  ; ditto for blockage flag, we don't know whether we can compute it yet
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
;         print, "Available blockage sites: ", blkSites
      ENDELSE
   ENDIF

  ; find the volume with the correct reflectivity field for the GR site/source,
  ;   and the ID of the field itself
   gv_z_field = ''
   z_vol_num = get_site_specific_z_volume( siteID, radar, gv_z_field )
   IF ( z_vol_num LT 0 )  THEN BEGIN
      PRINT, ""
      PRINT, "Error finding volume in radar structure from file ", file_1CUF
      PRINT, ""
      GOTO, nextGRfile
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

  ; find the volume with the RC rainrate field for the GV site/source
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

  ; find the volume with the RP rainrate field for the GV site/source
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

  ; find the volume with the RR rainrate field for the GV site/source
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

  ; find the volume with the DM field for the GV site/source
   gv_dm_field = ''
   dm_field2get = 'DM'
   dm_vol_num = get_site_specific_z_volume( siteID, radar, gv_dm_field, $
                                               UF_FIELD=dm_field2get )
   IF ( dm_vol_num LT 0 )  THEN BEGIN
      PRINT, ""
      PRINT, "No 'DM' volume in radar structure from file: ", file_1CUF
      PRINT, ""
      have_gv_dm = 0
   ENDIF ELSE BEGIN
      have_gv_dm = 1
      ufstruct.DM_ID = gv_dm_field
   ENDELSE

  ; find the volume with the N2 field for the GV site/source
   gv_n2_field = ''
   n2_field2get = 'N2'
   n2_vol_num = get_site_specific_z_volume( siteID, radar, gv_n2_field, $
                                            UF_FIELD=n2_field2get )
   IF ( n2_vol_num LT 0 )  THEN BEGIN
      PRINT, ""
      PRINT, "No 'N2' volume in radar structure from file: ", file_1CUF
      PRINT, ""
      have_gv_n2 = 0
   ENDIF ELSE BEGIN
      have_gv_n2 = 1
      ufstruct.N2_ID = gv_n2_field
   ENDELSE

  ; get the number of elevation sweeps in the vol, and the array of elev angles
   num_elevations = get_sweep_elevs( z_vol_num, radar, elev_angle )
  ; make a copy of the array of elevations, from which we eliminate any
  ;   duplicate tilt angles for subsequent data processing/output
;   idx_uniq_elevs = UNIQ(elev_angle)
   uniq_elev_angle = elev_angle
   idx_uniq_elevs = UNIQ_SWEEPS(elev_angle, uniq_elev_angle)

   tocdf_elev_angle = elev_angle[idx_uniq_elevs]
   num_elevations_out = N_ELEMENTS(tocdf_elev_angle)
   ; TAB 6/15/21, fix for some bad files in May/June 2015
   good_ind = where (elev_angle gt 0, good_cnt)
   IF good_cnt eq 0 THEN BEGIN
      PRINT, "Error: Elevation angles are all negative for orbit = ", orbit, ", site = ", $
              siteID, ", skipping."
      GOTO, nextGRfile
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
            print, 'Enter .CONTINUE command to proceed, .RESET to quit:'
            stop
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
         stop
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

  ; Determine an upper limit to how many DPR footprints fall inside the analysis
  ;   area, so that we can hold x, y, and various z values for each element to
  ;   analyze.  We gave the DPR a 4km resolution in the 'include' file
  ;   pr_params.inc, and use this nominal resolution to figure out how many
  ;   of these are required to cover the in-range area.

   grid_area_km = rough_threshold * rough_threshold  ; could use area of circle
   max_dpr_fp = grid_area_km / NOM_DPR_RES_KM

  ; Create temp array of DPR (ray, scan) 1-D index locators for in-range points.
  ;   Use flag values of -1 for 'bogus' DPR points (out-of-range DPR footprints
  ;   just adjacent to the first/last in-range point of the scan), or -2 for
  ;   off-DPR-scan-edge but still-in-range points.  These bogus points will then
  ;   totally enclose the set of in-range, in-scan points and allow gridding of
  ;   the in-range dataset to a regular grid using a nearest-neighbor analysis,
  ;   assuring that the bounds of the in-range data are preserved (this gridding
  ;   in not needed or done within the current analysis).
   dpr_master_idx = LONARR(max_dpr_fp)
   dpr_master_idx[*] = -99L

  ; Create temp array used to flag whether there are ANY above-threshold DPR bins
  ; in the ray.  If none, we'll skip the time-consuming GR LUT computations.
   dpr_echoes = BYTARR(max_dpr_fp)
   dpr_echoes[*] = 0B             ; initialize to zero (skip the DPR ray)

  ; Create temp arrays to hold lat/lon of all DPR footprints to be analyzed,
  ;   including those extrapolated to mark the edge of the scan
   dpr_lon_sfc = FLTARR(max_dpr_fp)
   dpr_lat_sfc = dpr_lon_sfc

  ; create temp subarrays with additional dimension num_elevations_out to hold
  ;   parallax-adjusted DPR point X,Y and lon/lat coordinates, and DPR corner X,Ys
   dpr_x_center = FLTARR(max_dpr_fp, num_elevations_out)
   dpr_y_center = dpr_x_center
   dpr_x_corners = FLTARR(4, max_dpr_fp, num_elevations_out)
   dpr_y_corners = dpr_x_corners
  ; holds lon/lat array returned by MAP_PROJ_INVERSE()
   dpr_lon_lat = DBLARR(2, max_dpr_fp, num_elevations_out)

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

  ; GEO-Preprocess the DPR data, extracting rays that intersect this radar volume
  ; within the specified range threshold, and computing footprint x,y corner
  ; coordinates and adjusted center lat/lon at each of the intersection sweep
  ; intersection heights, taking into account the parallax of the DPR rays.
  ; (Optionally) surround the DPR footprints within the range threshold with a border
  ; of "bogus" tagged DPR points to facilitate any future gridding of the data.
  ; Algorithm assumes that DPR footprints are contiguous, non-overlapping,
  ; and quasi-rectangular in their native ray,scan coordinates, and that the DPR
  ; scans through nadir (zero roll/pitch of satellite).

  ; First, find scans with any point within range of the radar volume, roughly
   start_scan = 0 & end_scan = 0 & nscans2do = 0
   start_found = 0
   FOR scan_num = 0,SAMPLE_RANGE-1  DO BEGIN
      found_one = 0
      FOR ray_num = 0,RAYSPERSCAN-1  DO BEGIN
         ; Compute distance between GR radar and DPR sample lats/lons using
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

   IF ( nscans2do EQ 0 ) THEN BEGIN
      print, "No footprints in range of GR by lat/lon difference check, bailing."
      GOTO, nextGRfile
   ENDIF

;-------------------------------------------------------------------------------
  ; Populate arrays holding 'exact' DPR at-surface X and Y and range values for
  ; the in-range subset of scans.  THESE ARE NOT WRITTEN TO NETCDF FILE - YET.
   XY_km = map_proj_forward( prlons[*,start_scan:end_scan], $
                             prlats[*,start_scan:end_scan], $
                             map_structure=smap ) / 1000.
   dpr_x0 = XY_km[0,*]
   dpr_y0 = XY_km[1,*]
   dpr_x0 = REFORM( dpr_x0, RAYSPERSCAN, nscans2do, /OVERWRITE )
   dpr_y0 = REFORM( dpr_y0, RAYSPERSCAN, nscans2do, /OVERWRITE )
   precise_range = SQRT( dpr_x0^2 + dpr_y0^2 )

   numDPRrays = 0      ; number of in-range, scan-edge, and range-adjacent points
   numPRinrange = 0   ; number of in-range-only points found
  ; Variables used to find 'farthest from nadir' in-range DPR footprint:
   maxrayidx = 0
   minrayidx = RAYSPERSCAN-1

;-------------------------------------------------------------------------------
  ; Identify actual DPR points within range of the radar, actual DPR points just
  ; off the edge of the range cutoff, and extrapolated DPR points along the edge
  ; of the scans but within range of the radar.  Tag each point as to these 3
  ; types, and compute parallax-corrected x,y and lat/lon coordinates for these
  ; points at DPR ray's intersection of each sweep elevation.  Compute DPR
  ; footprint corner x,y's for the first type of points (actual DPR points
  ; within the cutoff range).

  ; flag for adding 'bogus' point if in-range at edge of scan DPR (2), or just
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
        ; Set flag value according to where the DPR footprint lies w.r.t. the GR radar.
         action2do = 0  ; default -- do nothing

        ; is to-sfc projection of any point along DPR ray is within range of GR volume?
         IF ( precise_range[ray_num,subset_scan_num] LE max_ranges[0] ) THEN BEGIN
           ; add point to subarrays for DPR 2D index and for footprint lat/lon
           ; - MAKE THE INDEX IN TERMS OF THE (RAY,SCAN) COORDINATE ARRAYS

            dpr_master_idx[numDPRrays] = dpr_index_all[ray_num,scan_num] ; for GPM
            dpr_lat_sfc[numDPRrays] = prlats[ray_num,scan_num]
            dpr_lon_sfc[numDPRrays] = prlons[ray_num,scan_num]

            action2do = 1                      ; set up to process this in-range point
            maxrayidx = ray_num > maxrayidx    ; track highest ray num occurring in GR area
            minrayidx = ray_num < minrayidx    ; track lowest ray num in GR area
            numPRinrange = numPRinrange + 1    ; increment # of actual in-range footprints

	   ; determine whether the DPR ray has any bins above the dBZ threshold
	   ; - look at corrected Z between 0.75 and 19.25 km, and
           ;   use the above-threshold bin counting in get_dpr_layer_average()
	    topMeasGate = 0 & botmMeasGate = 0
            topCorrGate = 0 & botmCorrGate = 0
            topCorrGate = dpr_gate_num_for_height( 19.25, GATE_SPACE,  $
                             cos_inc_angle, ray_num, scan_num, binRealSurface )
            botmCorrGate = dpr_gate_num_for_height( 0.75, GATE_SPACE,  $
                              cos_inc_angle, ray_num, scan_num, binRealSurface )
            ;PRINT, "GATES AT 0.75 and 19.25 KM, and GATE_SPACE: ", $
            ;        botmCorrGate, topCorrGate, GATE_SPACE
            dbz_ray_avg = get_dpr_layer_average(topCorrGate, botmCorrGate,   $
                             scan_num, ray_num, dbz_corr, DBZSCALECORR, $
                             DPR_DBZ_MIN, numDPRgates )
            IF ( numDPRgates GT 0 ) THEN dpr_echoes[numDPRrays] = 1B

           ; If DPR scan edge point, then set flag to add bogus DPR data point to
           ;   subarrays for each DPR spatial field, with DPR index flagged as
           ;   "off-scan-edge", and compute the extrapolated location parameters
            IF ( (ray_num EQ 0 OR ray_num EQ RAYSPERSCAN-1) AND mark_edges EQ 1 ) THEN BEGIN
              ; set flag and find the x,y offsets to extrapolated off-edge point
               action2do = 2                   ; set up to also process bogus off-edge point
              ; extrapolate X and Y to the bogus, off-scan-edge point
               if ( ray_num LT RAYSPERSCAN/2 ) then begin 
                  ; offsets extrapolate X and Y to where (angle = angle-1) would be
                  ; Get offsets using the next footprint's X and Y
                  Xoff = dpr_x0[ray_num, subset_scan_num] - dpr_x0[ray_num+1, subset_scan_num]
                  Yoff = dpr_y0[ray_num, subset_scan_num] - dpr_y0[ray_num+1, subset_scan_num]
               endif else begin
                  ; extrapolate X and Y to where (angle = angle+1) would be
                  ; Get offsets using the preceding footprint's X and Y
                  Xoff = dpr_x0[ray_num, subset_scan_num] - dpr_x0[ray_num-1, subset_scan_num]
                  Yoff = dpr_y0[ray_num, subset_scan_num] - dpr_y0[ray_num-1, subset_scan_num]
               endelse
              ; compute the resulting lon/lat value of the extrapolated footprint
              ;  - we will add to temp lat/lon arrays in action sections, below
               XX = dpr_x0[ray_num, subset_scan_num] + Xoff
               YY = dpr_y0[ray_num, subset_scan_num] + Yoff
              ; need x and y in meters for MAP_PROJ_INVERSE:
               extrap_lon_lat = MAP_PROJ_INVERSE (XX*1000., YY*1000., MAP_STRUCTURE=smap)
            ENDIF

         ENDIF ELSE BEGIN
            IF mark_edges EQ 1 THEN BEGIN
              ; Is footprint immediately adjacent to the in-range area?  If so, then
              ;   'ring' the in-range points with a border of DPR bogosity, even for
              ;   scans with no rays in-range. (Is like adding a range ring at the
              ;   outer edge of the in-range area)
               IF ( precise_range[ray_num,subset_scan_num] LE $
                    (max_ranges[0] + NOM_DPR_RES_KM*1.5) ) THEN BEGIN
                   dpr_master_idx[numDPRrays] = -1L  ; store beyond-range indicator as DPR index
                   dpr_lat_sfc[numDPRrays] = prlats[ray_num,scan_num]
                   dpr_lon_sfc[numDPRrays] = prlons[ray_num,scan_num]
                   action2do = -1  ; set up to process bogus beyond-range point
               ENDIF
            ENDIF
         ENDELSE          ; ELSE for precise range[] LE max_ranges[0]

        ; If/As flag directs, add DPR point(s) to the subarrays for each elevation
         IF ( action2do NE 0 ) THEN BEGIN
           ; compute the at-surface x,y values for the 4 corners of the current DPR footprint
            xy = footprint_corner_x_and_y( subset_scan_num, ray_num, dpr_x0, dpr_y0, $
                                           nscans2do, RAYSPERSCAN )
           ; compute parallax-corrected x-y values for each sweep height
            FOR i = 0, num_elevations_out - 1 DO BEGIN
              ; NEXT 4+ COMMANDS COULD BE ITERATIVE, TO CONVERGE TO A dR THRESHOLD (function?)
              ; compute GR beam height for elevation angle at precise_range
               rsl_get_slantr_and_h, precise_range[ray_num,subset_scan_num], $
                                     tocdf_elev_angle[i], slant_range, hgt_at_range

              ; compute DPR parallax corrections dX and dY at this height (adjusted to MSL),
              ;   and apply to footprint center X and Y to get XX and YY
               get_parallax_dx_dy, hgt_at_range + siteElev, ray_num, RAYSPERSCAN, $
                                   m, dy_sign, tan_inc_angle, dx, dy
               XX = dpr_x0[ray_num, subset_scan_num] + dx
               YY = dpr_y0[ray_num, subset_scan_num] + dy

              ; recompute precise_range of parallax-corrected DPR footprint from radar (if converging)

              ; compute lat,lon of parallax-corrected DPR footprint center:
               lon_lat = MAP_PROJ_INVERSE( XX*1000., YY*1000., MAP_STRUCTURE=smap )  ; x and y in meters

              ; compute parallax-corrected X and Y coordinate values for the DPR
              ;   footprint corners; hold in temp arrays xcornerspc and ycornerspc
               xcornerspc = xy[0,*] + dx
               ycornerspc = xy[1,*] + dy

              ; store DPR-GR sweep intersection (XX,YY), offset lat and lon, and
              ;  (if non-bogus) corner (x,y)s in elevation-specific slots
               dpr_x_center[numDPRrays,i] = XX
               dpr_y_center[numDPRrays,i] = YY
               dpr_x_corners[*,numDPRrays,i] = xcornerspc
               dpr_y_corners[*,numDPRrays,i] = ycornerspc
               dpr_lon_lat[*,numDPRrays,i] = lon_lat
            ENDFOR
            numDPRrays = numDPRrays + 1   ; increment counter for # DPR rays stored in arrays
         ENDIF

         IF ( action2do EQ 2 ) THEN BEGIN
           ; add another DPR footprint to the analyzed set, to delimit the DPR scan edge
            dpr_master_idx[numDPRrays] = -2L    ; store off-scan-edge indicator as DPR index
            dpr_lat_sfc[numDPRrays] = extrap_lon_lat[1]  ; store extrapolated lat/lon
            dpr_lon_sfc[numDPRrays] = extrap_lon_lat[0]

            FOR i = 0, num_elevations_out - 1 DO BEGIN
              ; - grab the parallax-corrected footprint center and corner x,y's just
              ;     stored for the in-range DPR edge point, and apply Xoff and Yoff offsets
               XX = dpr_x_center[numDPRrays-1,i] + Xoff
               YY = dpr_y_center[numDPRrays-1,i] + Yoff
               xcornerspc = dpr_x_corners[*,numDPRrays-1,i] + Xoff
               ycornerspc = dpr_y_corners[*,numDPRrays-1,i] + Yoff
              ; - compute lat,lon of parallax-corrected DPR footprint center:
               lon_lat = MAP_PROJ_INVERSE(XX*1000., YY*1000., MAP_STRUCTURE=smap)  ; x,y to m
              ; store in elevation-specific slots
               dpr_x_center[numDPRrays,i] = XX
               dpr_y_center[numDPRrays,i] = YY
               dpr_x_corners[*,numDPRrays,i] = xcornerspc
               dpr_y_corners[*,numDPRrays,i] = ycornerspc
               dpr_lon_lat[*,numDPRrays,i] = lon_lat
            ENDFOR
            numDPRrays = numDPRrays + 1
         ENDIF

      ENDFOR              ; ray_num
   ENDFOR                 ; scan_num = start_scan,end_scan 

  ; ONE TIME ONLY: compute max diagonal size of a DPR footprint, halve it,
  ;   and assign to max_DPR_footprint_diag_halfwidth.  Ignore the variability
  ;   with height.  Take middle scan of DPR/GR overlap within subset arrays:
   subset_scan_4size = FIX( (end_scan-start_scan)/2 )
  ; find which ray used was farthest from nadir ray at RAYSPERSCAN/2
   nadir_off_low = ABS(minrayidx - RAYSPERSCAN/2)
   nadir_off_hi = ABS(maxrayidx - RAYSPERSCAN/2)
   ray4size = (nadir_off_hi GT nadir_off_low) ? maxrayidx : minrayidx
  ; get DPR footprint max diag extent at [ray4size, scan4size], and halve it
  ; Is it guaranteed that [subset_scan4size,ray4size] is one of our in-range
  ;   points?  Don't know, so get the corner x,y's for this point
   xy = footprint_corner_x_and_y( subset_scan_4size, ray4size, dpr_x0, dpr_y0, $
                                  nscans2do, RAYSPERSCAN )
   diag1 = SQRT((xy[0,0]-xy[0,2])^2+(xy[1,0]-xy[1,2])^2)
   diag2 = SQRT((xy[0,1]-xy[0,3])^2+(xy[1,1]-xy[1,3])^2)
   max_DPR_footprint_diag_halfwidth = (diag1 > diag2) / 2.0

  ; end of DPR GEO-preprocessing

  ; ============================================================================

  ; Initialize and/or populate data fields to be written to the netCDF file.
  ; NOTE WE DON'T SAVE THE SURFACE X,Y FOOTPRINT CENTERS AND CORNERS TO NETCDF

   IF ( numPRinrange GT 0 ) THEN BEGIN
     ; Trim the dpr_master_idx, lat/lon temp arrays and x,y corner arrays down
     ;   to numDPRrays elements in that dimension, in prep. for writing to netCDF
     ;    -- these elements are complete, data-wise
      tocdf_pr_idx = dpr_master_idx[0:numDPRrays-1]
      tocdf_x_poly = dpr_x_corners[*,0:numDPRrays-1,*]
      tocdf_y_poly = dpr_y_corners[*,0:numDPRrays-1,*]
      tocdf_lat = REFORM(dpr_lon_lat[1,0:numDPRrays-1,*])   ; 3D to 2D
      tocdf_lon = REFORM(dpr_lon_lat[0,0:numDPRrays-1,*])
      tocdf_lat_sfc = dpr_lat_sfc[0:numDPRrays-1]
      tocdf_lon_sfc = dpr_lon_sfc[0:numDPRrays-1]

     ; Create new subarrays of dimension equal to the numDPRrays for each 2-D
     ;   DPR science variable: landOceanFlag, nearSurfRain, nearSurfRain_2bcmb,
     ;   BBheight, rainFlag, rainType, BBstatus, status, piaFinal, heightStormTop
      tocdf_corr_srain = MAKE_ARRAY(numDPRrays, /float, VALUE=FLOAT_RANGE_EDGE)
      tocdf_2bcmb_srain = MAKE_ARRAY(numDPRrays, /float, VALUE=FLOAT_RANGE_EDGE)
      tocdf_piaFinal = MAKE_ARRAY(numDPRrays, /float, VALUE=FLOAT_RANGE_EDGE)
      tocdf_BB_Hgt = MAKE_ARRAY(numDPRrays, /float, VALUE=FLOAT_RANGE_EDGE)
      tocdf_rainflag = MAKE_ARRAY(numDPRrays, /int, VALUE=INT_RANGE_EDGE)
      tocdf_raintype = MAKE_ARRAY(numDPRrays, /int, VALUE=INT_RANGE_EDGE)
      tocdf_landocean = MAKE_ARRAY(numDPRrays, /int, VALUE=INT_RANGE_EDGE)
      tocdf_BBstatus = MAKE_ARRAY(numDPRrays, /int, VALUE=INT_RANGE_EDGE)
      tocdf_qualityData = MAKE_ARRAY(numDPRrays, /long, VALUE=LONG(INT_RANGE_EDGE))
      tocdf_heightStormTop = MAKE_ARRAY(numDPRrays, /int, VALUE=INT_RANGE_EDGE)

     ; Create new subarrays of dimensions (numDPRrays, num_elevations_out) for each
     ;   3-D science and status variable: 
      tocdf_gr_dbz = MAKE_ARRAY(numDPRrays, num_elevations_out, /float, $
                                VALUE=FLOAT_RANGE_EDGE)
      tocdf_gr_stddev = MAKE_ARRAY(numDPRrays, num_elevations_out, /float, $
                                   VALUE=FLOAT_RANGE_EDGE)
      tocdf_gr_max = MAKE_ARRAY(numDPRrays, num_elevations_out, /float, $
                                VALUE=FLOAT_RANGE_EDGE)
      tocdf_gr_rc = MAKE_ARRAY(numDPRrays, num_elevations_out, /float, $
                               VALUE=FLOAT_RANGE_EDGE)
      tocdf_gr_rc_stddev = MAKE_ARRAY(numDPRrays, num_elevations_out, /float, $
                                      VALUE=FLOAT_RANGE_EDGE)
      tocdf_gr_rc_max = MAKE_ARRAY(numDPRrays, num_elevations_out, /float, $
                                   VALUE=FLOAT_RANGE_EDGE)
      tocdf_gr_rp = MAKE_ARRAY(numDPRrays, num_elevations_out, /float, $
                               VALUE=FLOAT_RANGE_EDGE)
      tocdf_gr_rp_stddev = MAKE_ARRAY(numDPRrays, num_elevations_out, /float, $
                                      VALUE=FLOAT_RANGE_EDGE)
      tocdf_gr_rp_max = MAKE_ARRAY(numDPRrays, num_elevations_out, /float, $
                                   VALUE=FLOAT_RANGE_EDGE)
      tocdf_gr_rr = MAKE_ARRAY(numDPRrays, num_elevations_out, /float, $
                               VALUE=FLOAT_RANGE_EDGE)
      tocdf_gr_rr_stddev = MAKE_ARRAY(numDPRrays, num_elevations_out, /float, $
                                      VALUE=FLOAT_RANGE_EDGE)
      tocdf_gr_rr_max = MAKE_ARRAY(numDPRrays, num_elevations_out, /float, $
                                   VALUE=FLOAT_RANGE_EDGE)
      tocdf_gr_zdr = MAKE_ARRAY(numDPRrays, num_elevations_out, /float, $
                                VALUE=FLOAT_RANGE_EDGE)
      tocdf_gr_zdr_stddev = MAKE_ARRAY(numDPRrays, num_elevations_out, /float, $
                                       VALUE=FLOAT_RANGE_EDGE)
      tocdf_gr_zdr_max = MAKE_ARRAY(numDPRrays, num_elevations_out, /float, $
                                    VALUE=FLOAT_RANGE_EDGE)
      tocdf_gr_kdp = MAKE_ARRAY(numDPRrays, num_elevations_out, /float, $
                                VALUE=FLOAT_RANGE_EDGE)
      tocdf_gr_kdp_stddev = MAKE_ARRAY(numDPRrays, num_elevations_out, /float, $
                                       VALUE=FLOAT_RANGE_EDGE)
      tocdf_gr_kdp_max = MAKE_ARRAY(numDPRrays, num_elevations_out, /float, $
                                    VALUE=FLOAT_RANGE_EDGE)
      tocdf_gr_rhohv = MAKE_ARRAY(numDPRrays, num_elevations_out, /float, $
                                  VALUE=FLOAT_RANGE_EDGE)
      tocdf_gr_rhohv_stddev = MAKE_ARRAY(numDPRrays, num_elevations_out, $
                                         /float, VALUE=FLOAT_RANGE_EDGE)
      tocdf_gr_rhohv_max = MAKE_ARRAY(numDPRrays, num_elevations_out, /float, $
                                      VALUE=FLOAT_RANGE_EDGE)
      IF ( have_gv_hid ) THEN $  ; don't have n_hid_cats unless have_gv_hid set
         tocdf_gr_HID = MAKE_ARRAY(n_hid_cats, numDPRrays, num_elevations_out, $
                                   /int, VALUE=INT_RANGE_EDGE)
      tocdf_gr_Dzero = MAKE_ARRAY(numDPRrays, num_elevations_out, /float, $
                                  VALUE=FLOAT_RANGE_EDGE)
      tocdf_gr_Dzero_stddev = MAKE_ARRAY(numDPRrays, num_elevations_out, $
                                         /float, VALUE=FLOAT_RANGE_EDGE)
      tocdf_gr_Dzero_max = MAKE_ARRAY(numDPRrays, num_elevations_out, /float, $
                                      VALUE=FLOAT_RANGE_EDGE)
      tocdf_gr_Nw = MAKE_ARRAY(numDPRrays, num_elevations_out, /float, $
                               VALUE=FLOAT_RANGE_EDGE)
      tocdf_gr_Nw_stddev = MAKE_ARRAY(numDPRrays, num_elevations_out, /float, $
                                      VALUE=FLOAT_RANGE_EDGE)
      tocdf_gr_Nw_max = MAKE_ARRAY(numDPRrays, num_elevations_out, /float, $
                                   VALUE=FLOAT_RANGE_EDGE)
      tocdf_gr_Dm = MAKE_ARRAY(numDPRrays, num_elevations_out, /float, $
                               VALUE=FLOAT_RANGE_EDGE)
      tocdf_gr_Dm_stddev = MAKE_ARRAY(numDPRrays, num_elevations_out, /float, $
                                      VALUE=FLOAT_RANGE_EDGE)
      tocdf_gr_Dm_max = MAKE_ARRAY(numDPRrays, num_elevations_out, /float, $
                                   VALUE=FLOAT_RANGE_EDGE)
      tocdf_gr_N2 = MAKE_ARRAY(numDPRrays, num_elevations_out, /float, $
                               VALUE=FLOAT_RANGE_EDGE)
      tocdf_gr_N2_stddev = MAKE_ARRAY(numDPRrays, num_elevations_out, /float, $
                                      VALUE=FLOAT_RANGE_EDGE)
      tocdf_gr_N2_max = MAKE_ARRAY(numDPRrays, num_elevations_out, /float, $
                                   VALUE=FLOAT_RANGE_EDGE)
      tocdf_gr_blockage = MAKE_ARRAY(numDPRrays, num_elevations_out, /float, $
                                     VALUE=FLOAT_RANGE_EDGE)
      tocdf_meas_dbz = MAKE_ARRAY(numDPRrays, num_elevations_out, /float, $
                                  VALUE=FLOAT_RANGE_EDGE)
      tocdf_corr_dbz = MAKE_ARRAY(numDPRrays, num_elevations_out, /float, $
                                  VALUE=FLOAT_RANGE_EDGE)
      tocdf_corr_rain = MAKE_ARRAY(numDPRrays, num_elevations_out, /float, $
                                   VALUE=FLOAT_RANGE_EDGE)
      tocdf_epsilon = MAKE_ARRAY(numDPRrays, num_elevations_out, /float, $
                                 VALUE=FLOAT_RANGE_EDGE)
      tocdf_dm = MAKE_ARRAY(numDPRrays, num_elevations_out, /float, $
                            VALUE=FLOAT_RANGE_EDGE)
      tocdf_nw = MAKE_ARRAY(numDPRrays, num_elevations_out, /float, $
                            VALUE=FLOAT_RANGE_EDGE)
      tocdf_top_hgt = MAKE_ARRAY(numDPRrays, num_elevations_out, /float, $
                                 VALUE=FLOAT_RANGE_EDGE)
      tocdf_botm_hgt = MAKE_ARRAY(numDPRrays, num_elevations_out, /float, $
                                  VALUE=FLOAT_RANGE_EDGE)
      tocdf_gr_rejected = UINTARR(numDPRrays, num_elevations_out)
      tocdf_gr_rc_rejected = UINTARR(numDPRrays, num_elevations_out)
      tocdf_gr_rp_rejected = UINTARR(numDPRrays, num_elevations_out)
      tocdf_gr_rr_rejected = UINTARR(numDPRrays, num_elevations_out)
      tocdf_gr_zdr_rejected = UINTARR(numDPRrays, num_elevations_out)
      tocdf_gr_kdp_rejected = UINTARR(numDPRrays, num_elevations_out)
      tocdf_gr_rhohv_rejected = UINTARR(numDPRrays, num_elevations_out)
      tocdf_gr_hid_rejected = UINTARR(numDPRrays, num_elevations_out)
      tocdf_gr_dzero_rejected = UINTARR(numDPRrays, num_elevations_out)
      tocdf_gr_nw_rejected = UINTARR(numDPRrays, num_elevations_out)
      tocdf_gr_dm_rejected = UINTARR(numDPRrays, num_elevations_out)
      tocdf_gr_n2_rejected = UINTARR(numDPRrays, num_elevations_out)
      tocdf_gr_expected = UINTARR(numDPRrays, num_elevations_out)
      tocdf_meas_z_rejected = UINTARR(numDPRrays, num_elevations_out)
      tocdf_corr_z_rejected = UINTARR(numDPRrays, num_elevations_out)
      tocdf_corr_r_rejected = UINTARR(numDPRrays, num_elevations_out)
      tocdf_epsilon_rejected = UINTARR(numDPRrays, num_elevations_out)
      tocdf_dpr_dm_rejected = UINTARR(numDPRrays, num_elevations_out)
      tocdf_dpr_nw_rejected = UINTARR(numDPRrays, num_elevations_out)
      tocdf_dpr_expected = UINTARR(numDPRrays, num_elevations_out)
      tocdf_clutterStatus = UINTARR(numDPRrays, num_elevations_out)

     ; get the indices of actual DPR footprints and load the 2D element subarrays
     ;   (no more averaging/processing needed) with data from the product arrays

      prgoodidx = WHERE( tocdf_pr_idx GE 0L, countprgood )
      IF ( countprgood GT 0 ) THEN BEGIN
         pr_idx_2get = tocdf_pr_idx[prgoodidx]
         tocdf_corr_srain[prgoodidx] = surfRain_corr[pr_idx_2get]
         IF ( havefile2bcmb EQ 1 ) THEN BEGIN
            tocdf_2bcmb_srain[prgoodidx] = surfRain_2bcmb[pr_idx_2get]
         ENDIF
         tocdf_piaFinal[prgoodidx] = piaFinal[pr_idx_2get]
         tocdf_BB_Hgt[prgoodidx] = BB_Hgt[pr_idx_2get]
         tocdf_rainflag[prgoodidx] = rainFlag[pr_idx_2get]
         tocdf_raintype[prgoodidx] = rainType[pr_idx_2get]
         tocdf_landocean[prgoodidx] = landOceanFlag[pr_idx_2get]
         tocdf_BBstatus[prgoodidx] = BBstatus[pr_idx_2get]
         tocdf_qualityData[prgoodidx] = qualityData[pr_idx_2get]
         tocdf_heightStormTop[prgoodidx] = heightStormTop[pr_idx_2get]
        ; get the scan and ray number arrays for the footprint locations
        ; defined by pr_idx_2get.  Keep scanNum as long int, convert rayNum
        ; to short int, as they are each defined in netCDF file
         tocdf_rayNum = FIX(tocdf_pr_idx)
         tocdf_scanNum = tocdf_pr_idx
         rayscan = ARRAY_INDICES(BBstatus, pr_idx_2get)
         tocdf_rayNum[prgoodidx] = FIX( REFORM(rayscan[0,*]) )
         tocdf_scanNum[prgoodidx] = REFORM(rayscan[1,*])
         rayscan=0    ; free some space
     ENDIF

     ; get the indices of any bogus scan-edge DPR footprints
      predgeidx = WHERE( tocdf_pr_idx EQ -2, countpredge )
      IF ( countpredge GT 0 ) THEN BEGIN
        ; set the single-level DPR element subarrays with the special values for
        ;   the extrapolated points
         tocdf_corr_srain[predgeidx] = FLOAT_OFF_EDGE
         tocdf_2bcmb_srain[predgeidx] = FLOAT_OFF_EDGE
         tocdf_piaFinal[predgeidx] = FLOAT_OFF_EDGE
         tocdf_BB_Hgt[predgeidx] = FLOAT_OFF_EDGE
         tocdf_rainflag[predgeidx] = INT_OFF_EDGE
         tocdf_raintype[predgeidx] = INT_OFF_EDGE
         tocdf_landocean[predgeidx] = INT_OFF_EDGE
         tocdf_qualityData[predgeidx] = LONG(INT_OFF_EDGE)
         tocdf_heightStormTop[predgeidx] = INT_OFF_EDGE
      ENDIF

   ENDIF ELSE BEGIN
      PRINT, ""
      PRINT, "No in-range DPR footprints found for ", siteID, ", skipping."
      PRINT, ""
      GOTO, nextGRfile
   ENDELSE

  ; ============================================================================
  ; If the DECLUTTER keyword is set, then compute a clutter flag for the DPR
  ; corrected reflectivity using a custom technique in flag_clutter.pro

   IF KEYWORD_SET(declutter) THEN BEGIN
      PRINT, "" & PRINT, "Computing clutter gates in DPR Zcor"
     ; grab the scan and ray coordinates for the actual DPR master indices
      raydpr = tocdf_rayNum[prgoodidx] & scandpr = tocdf_scanNum[prgoodidx]
     ; define an array to flag clutter gates and call flag_clutter to assign
     ; values for the locations of "actual" DPR footprints
      clutterFlag = BYTARR(SIZE(dbz_corr, /DIMENSIONS))
      flag_clutter, scandpr, raydpr, dbz_corr, clutterFlag, $
                    binClutterFreeBottom, VERBOSE=verbose
      idxclutter=where(CLUTTERFLAG GT 0, nclutr)
      ;HELP, clutterFlag, scandpr, raydpr, nclutr
      PRINT, STRING(nclutr, FORMAT='(I0)'), " clutter gates found in ", $
             STRING(countprgood, FORMAT='(I0)'), " rays."
      PRINT, ""
      raydpr=0 & scandpr=0    ; free some space
   ENDIF
;stop
  ; ============================================================================

  ; Map this GR radar's data to these DPR footprints, where DPR rays
  ; intersect the elevation sweeps.  This part of the algorithm continues
  ; in code in a separate file, included below:

   @polar2dpr_resampling.pro

  ; ============================================================================

  ; generate the netcdf matchup file path/name

   IF N_ELEMENTS(ncnameadd) EQ 1 THEN BEGIN
      fname_netCDF = NC_OUTDIR+'/'+DPR_GEO_MATCH_PRE+siteID+'.'+DATESTAMP+'.' $
                      +orbit+'.'+DPR_version+'.'+STRUPCASE(Instrument_ID)+'.' $
                      +STRUPCASE(DPR_scantype)+'.'+verstr+'.'+ncnameadd+NC_FILE_EXT
   ENDIF ELSE BEGIN
      fname_netCDF = NC_OUTDIR+'/'+DPR_GEO_MATCH_PRE+siteID+'.'+DATESTAMP+'.' $
                      +orbit+'.'+DPR_version+'.'+STRUPCASE(Instrument_ID)+'.' $
                      +STRUPCASE(DPR_scantype)+'.'+verstr+NC_FILE_EXT
   ENDELSE

   ; store the file basenames in a string array to be passed to
   ; gen_dpr_geo_match_netcdf(), in the same order as the tags in the
   ; dpr_gr_input_files structure defined in dpr_geo_match_nc_structs.inc
   infileNameArr = STRARR(7)
   infileNameArr[0] = FILE_BASENAME(origFileDPRName)
   infileNameArr[1] = FILE_BASENAME(origFileKuName)
   infileNameArr[2] = FILE_BASENAME(origFileKaName)
   infileNameArr[3] = FILE_BASENAME(origFileCMBName)
   infileNameArr[4] = base_1CUF
   infileNameArr[5] = FILE_BASENAME(origFilePRName)
   infileNameArr[6] = FILE_BASENAME(origFile2BPRTMIName)

  ; Create a netCDF file with the proper 'numDPRrays' and 'num_elevations_out'
  ; dimensions, also passing the global attribute values along
   ncfile = gen_dpr_geo_match_netcdf( fname_netCDF, numDPRrays, $
                                      tocdf_elev_angle, ufstruct, $
                                      STRUPCASE(DPR_scantype), DPR_version, $
                                      siteID, infileNameArr, $
                                      DECLUTTERED=decluttered, $
                                      NON_PPS_FILES=non_pps_files )

   IF ( fname_netCDF EQ "NoGeoMatchFile" ) THEN $
      message, "Error in creating output netCDF file "+fname_netCDF

  ; Open the netCDF file and write the completed field values to it
   ncid = NCDF_OPEN( ncfile, /WRITE )

  ; Write the scalar values to the netCDF file

   NCDF_VARPUT, ncid, 'site_ID', siteID
   NCDF_VARPUT, ncid, 'site_lat', siteLat
   NCDF_VARPUT, ncid, 'site_lon', siteLon
   NCDF_VARPUT, ncid, 'site_elev', siteElev
   NCDF_VARPUT, ncid, 'timeNearestApproach', dpr_dtime_ticks
   NCDF_VARPUT, ncid, 'atimeNearestApproach', dpr_dtime
   NCDF_VARPUT, ncid, 'timeSweepStart', ticks_sweep_times
   NCDF_VARPUT, ncid, 'atimeSweepStart', text_sweep_times
   NCDF_VARPUT, ncid, 'rangeThreshold', range_threshold_km
   NCDF_VARPUT, ncid, 'DPR_dBZ_min', DPR_DBZ_MIN
   NCDF_VARPUT, ncid, 'GR_dBZ_min', dBZ_min
   NCDF_VARPUT, ncid, 'rain_min', DPR_RAIN_MIN
   NCDF_VARPUT, ncid, 'numScans', SAMPLE_RANGE
   NCDF_VARPUT, ncid, 'numRays', RAYSPERSCAN

;  Write single-level results/flags to netcdf file

   NCDF_VARPUT, ncid, 'DPRlatitude', tocdf_lat_sfc
   NCDF_VARPUT, ncid, 'DPRlongitude', tocdf_lon_sfc
   NCDF_VARPUT, ncid, 'LandSurfaceType', tocdf_landocean     ; data
    NCDF_VARPUT, ncid, 'have_LandSurfaceType', DATA_PRESENT  ; data presence flag
   NCDF_VARPUT, ncid, 'PrecipRateSurface', tocdf_corr_srain     ; data
    NCDF_VARPUT, ncid, 'have_PrecipRateSurface', DATA_PRESENT   ; data presence flag
   IF ( havefile2bcmb EQ 1 ) THEN BEGIN
      NCDF_VARPUT, ncid, 'SurfPrecipTotRate', tocdf_2bcmb_srain      ; data
       NCDF_VARPUT, ncid, 'have_SurfPrecipTotRate', DATA_PRESENT    ; dp flag
   ENDIF
   NCDF_VARPUT, ncid, 'piaFinal', tocdf_piaFinal       ; data
    NCDF_VARPUT, ncid, 'have_piaFinal', DATA_PRESENT    ; data presence flag
   NCDF_VARPUT, ncid, 'BBheight', tocdf_BB_Hgt          ; data
    NCDF_VARPUT, ncid, 'have_BBheight', DATA_PRESENT    ; data presence flag
   NCDF_VARPUT, ncid, 'FlagPrecip', tocdf_rainflag      ; data
    NCDF_VARPUT, ncid, 'have_FlagPrecip', DATA_PRESENT  ; data presence flag
   NCDF_VARPUT, ncid, 'TypePrecip', tocdf_raintype      ; data
    NCDF_VARPUT, ncid, 'have_TypePrecip', DATA_PRESENT  ; data presence flag
   NCDF_VARPUT, ncid, 'heightStormTop', tocdf_heightStormTop  ; data
    NCDF_VARPUT, ncid, 'have_heightStormTop', DATA_PRESENT  ; data presence flag
;   NCDF_VARPUT, ncid, 'rayIndex', tocdf_pr_idx
   NCDF_VARPUT, ncid, 'rayNum', tocdf_rayNum
   NCDF_VARPUT, ncid, 'scanNum', tocdf_scanNum
   NCDF_VARPUT, ncid, 'BBstatus', tocdf_BBstatus
     NCDF_VARPUT, ncid, 'have_BBstatus', DATA_PRESENT    ; dp flag
   NCDF_VARPUT, ncid, 'qualityData', tocdf_qualityData       ; data
    NCDF_VARPUT, ncid, 'have_qualityData', DATA_PRESENT    ; data presence flag

;  Write sweep-level results/flags to netcdf file & close it up

   NCDF_VARPUT, ncid, 'latitude', tocdf_lat
   NCDF_VARPUT, ncid, 'longitude', tocdf_lon
   NCDF_VARPUT, ncid, 'xCorners', tocdf_x_poly
   NCDF_VARPUT, ncid, 'yCorners', tocdf_y_poly

   NCDF_VARPUT, ncid, 'GR_Z', tocdf_gr_dbz             ; data
    NCDF_VARPUT, ncid, 'have_GR_Z', DATA_PRESENT       ; data presence flag
   NCDF_VARPUT, ncid, 'GR_Z_StdDev', tocdf_gr_stddev    ; data
   NCDF_VARPUT, ncid, 'GR_Z_Max', tocdf_gr_max          ; data
   IF ( have_gv_rc ) THEN BEGIN
      NCDF_VARPUT, ncid, 'GR_RC_rainrate', tocdf_gr_rc            ; data
       NCDF_VARPUT, ncid, 'have_GR_RC_rainrate', DATA_PRESENT      ; data presence flag
      NCDF_VARPUT, ncid, 'GR_RC_rainrate_StdDev', tocdf_gr_rc_stddev
      NCDF_VARPUT, ncid, 'GR_RC_rainrate_Max', tocdf_gr_rc_max
   ENDIF
   IF ( have_gv_rp ) THEN BEGIN
      NCDF_VARPUT, ncid, 'GR_RP_rainrate', tocdf_gr_rp            ; data
       NCDF_VARPUT, ncid, 'have_GR_RP_rainrate', DATA_PRESENT      ; data presence flag
      NCDF_VARPUT, ncid, 'GR_RP_rainrate_StdDev', tocdf_gr_rp_stddev
      NCDF_VARPUT, ncid, 'GR_RP_rainrate_Max', tocdf_gr_rp_max
   ENDIF
   IF ( have_gv_rr ) THEN BEGIN
      NCDF_VARPUT, ncid, 'GR_RR_rainrate', tocdf_gr_rr            ; data
       NCDF_VARPUT, ncid, 'have_GR_RR_rainrate', DATA_PRESENT      ; data presence flag
      NCDF_VARPUT, ncid, 'GR_RR_rainrate_StdDev', tocdf_gr_rr_stddev
      NCDF_VARPUT, ncid, 'GR_RR_rainrate_Max', tocdf_gr_rr_max
   ENDIF
   IF ( have_gv_zdr ) THEN BEGIN
      NCDF_VARPUT, ncid, 'GR_Zdr', tocdf_gr_zdr            ; data
       NCDF_VARPUT, ncid, 'have_GR_Zdr', DATA_PRESENT      ; data presence flag
      NCDF_VARPUT, ncid, 'GR_Zdr_StdDev', tocdf_gr_zdr_stddev     ; data
      NCDF_VARPUT, ncid, 'GR_Zdr_Max', tocdf_gr_zdr_max            ; data
   ENDIF
   IF ( have_gv_kdp ) THEN BEGIN
      NCDF_VARPUT, ncid, 'GR_Kdp', tocdf_gr_kdp            ; data
       NCDF_VARPUT, ncid, 'have_GR_Kdp', DATA_PRESENT      ; data presence flag
      NCDF_VARPUT, ncid, 'GR_Kdp_StdDev', tocdf_gr_kdp_stddev     ; data
      NCDF_VARPUT, ncid, 'GR_Kdp_Max', tocdf_gr_kdp_max            ; data
   ENDIF
   IF ( have_gv_rhohv ) THEN BEGIN
      NCDF_VARPUT, ncid, 'GR_RHOhv', tocdf_gr_rhohv            ; data
       NCDF_VARPUT, ncid, 'have_GR_RHOhv', DATA_PRESENT      ; data presence flag
      NCDF_VARPUT, ncid, 'GR_RHOhv_StdDev', tocdf_gr_rhohv_stddev     ; data
      NCDF_VARPUT, ncid, 'GR_RHOhv_Max', tocdf_gr_rhohv_max            ; data
   ENDIF
   IF ( have_gv_hid ) THEN BEGIN
      NCDF_VARPUT, ncid, 'GR_HID', tocdf_gr_hid            ; data
       NCDF_VARPUT, ncid, 'have_GR_HID', DATA_PRESENT      ; data presence flag
   ENDIF
   IF ( have_gv_dzero ) THEN BEGIN
      NCDF_VARPUT, ncid, 'GR_Dzero', tocdf_gr_dzero            ; data
       NCDF_VARPUT, ncid, 'have_GR_Dzero', DATA_PRESENT      ; data presence flag
      NCDF_VARPUT, ncid, 'GR_Dzero_StdDev', tocdf_gr_dzero_stddev     ; data
      NCDF_VARPUT, ncid, 'GR_Dzero_Max', tocdf_gr_dzero_max            ; data
   ENDIF
   IF ( have_gv_nw ) THEN BEGIN
      NCDF_VARPUT, ncid, 'GR_Nw', tocdf_gr_nw            ; data
       NCDF_VARPUT, ncid, 'have_GR_Nw', DATA_PRESENT      ; data presence flag
      NCDF_VARPUT, ncid, 'GR_Nw_StdDev', tocdf_gr_nw_stddev     ; data
      NCDF_VARPUT, ncid, 'GR_Nw_Max', tocdf_gr_nw_max            ; data
   ENDIF
   IF ( have_gv_dm ) THEN BEGIN
      NCDF_VARPUT, ncid, 'GR_Dm', tocdf_gr_dm             ; data
       NCDF_VARPUT, ncid, 'have_GR_Dm', DATA_PRESENT      ; data presence flag
      NCDF_VARPUT, ncid, 'GR_Dm_StdDev', tocdf_gr_dm_stddev      ; data
      NCDF_VARPUT, ncid, 'GR_Dm_Max', tocdf_gr_dm_max            ; data
   ENDIF
   IF ( have_gv_n2 ) THEN BEGIN
      NCDF_VARPUT, ncid, 'GR_N2', tocdf_gr_n2             ; data
       NCDF_VARPUT, ncid, 'have_GR_N2', DATA_PRESENT      ; data presence flag
      NCDF_VARPUT, ncid, 'GR_N2_StdDev', tocdf_gr_n2_stddev      ; data
      NCDF_VARPUT, ncid, 'GR_N2_Max', tocdf_gr_n2_max            ; data
   ENDIF
   IF ( have_gv_blockage ) THEN BEGIN
      NCDF_VARPUT, ncid, 'GR_blockage', tocdf_gr_blockage      ; data
       NCDF_VARPUT, ncid, 'have_GR_blockage', DATA_PRESENT      ; data presence flag
   ENDIF

   NCDF_VARPUT, ncid, 'ZFactorMeasured', tocdf_meas_dbz         ; data
    NCDF_VARPUT, ncid, 'have_ZFactorMeasured', DATA_PRESENT     ; data presence flag
   NCDF_VARPUT, ncid, 'ZFactorCorrected', tocdf_corr_dbz        ; data
    NCDF_VARPUT, ncid, 'have_ZFactorCorrected', DATA_PRESENT    ; data presence flag
   NCDF_VARPUT, ncid, 'Epsilon', tocdf_Epsilon                  ; data
    NCDF_VARPUT, ncid, 'have_Epsilon', DATA_PRESENT             ; data presence flag
   NCDF_VARPUT, ncid, 'PrecipRate', tocdf_corr_rain             ; data
    IF DO_RAIN_CORR THEN NCDF_VARPUT, ncid, 'have_PrecipRate', DATA_PRESENT  ; dp flag
   IF ( have_paramdsd ) THEN BEGIN
       NCDF_VARPUT, ncid, 'Dm', tocdf_dm
       NCDF_VARPUT, ncid, 'Nw', tocdf_nw
   ENDIF
    NCDF_VARPUT, ncid, 'have_paramDSD', have_paramdsd

   NCDF_VARPUT, ncid, 'topHeight', tocdf_top_hgt
   NCDF_VARPUT, ncid, 'bottomHeight', tocdf_botm_hgt

   NCDF_VARPUT, ncid, 'n_gr_z_rejected', tocdf_gr_rejected
   NCDF_VARPUT, ncid, 'n_gr_rc_rejected', tocdf_gr_rc_rejected
   NCDF_VARPUT, ncid, 'n_gr_rp_rejected', tocdf_gr_rp_rejected
   NCDF_VARPUT, ncid, 'n_gr_rr_rejected', tocdf_gr_rr_rejected
   NCDF_VARPUT, ncid, 'n_gr_zdr_rejected', tocdf_gr_zdr_rejected
   NCDF_VARPUT, ncid, 'n_gr_kdp_rejected', tocdf_gr_kdp_rejected
   NCDF_VARPUT, ncid, 'n_gr_rhohv_rejected', tocdf_gr_rhohv_rejected
   NCDF_VARPUT, ncid, 'n_gr_hid_rejected', tocdf_gr_hid_rejected
   NCDF_VARPUT, ncid, 'n_gr_dzero_rejected', tocdf_gr_dzero_rejected
   NCDF_VARPUT, ncid, 'n_gr_nw_rejected', tocdf_gr_nw_rejected
   NCDF_VARPUT, ncid, 'n_gr_dm_rejected', tocdf_gr_dm_rejected
   NCDF_VARPUT, ncid, 'n_gr_n2_rejected', tocdf_gr_n2_rejected
   NCDF_VARPUT, ncid, 'n_gr_expected', tocdf_gr_expected
   NCDF_VARPUT, ncid, 'n_dpr_meas_z_rejected', tocdf_meas_z_rejected
   NCDF_VARPUT, ncid, 'n_dpr_corr_z_rejected', tocdf_corr_z_rejected
   NCDF_VARPUT, ncid, 'n_dpr_corr_r_rejected', tocdf_corr_r_rejected
   NCDF_VARPUT, ncid, 'n_dpr_epsilon_rejected', tocdf_epsilon_rejected
   IF ( have_paramdsd ) THEN BEGIN
      NCDF_VARPUT, ncid, 'n_dpr_dm_rejected', tocdf_dpr_dm_rejected
      NCDF_VARPUT, ncid, 'n_dpr_nw_rejected', tocdf_dpr_nw_rejected
   ENDIF
   NCDF_VARPUT, ncid, 'n_dpr_expected', tocdf_dpr_expected
   NCDF_VARPUT, ncid, 'clutterStatus', tocdf_clutterStatus
    NCDF_VARPUT, ncid, 'have_clutterStatus', DATA_PRESENT          ; data presence flag

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

   nextGRfile:

ENDFOR    ; each GR site for orbit

nextOrbit:

ENDWHILE  ; each orbit/DPR file set to process in control file

print, ""
print, "Done!"

bailOut:
CLOSE, lun0

END
