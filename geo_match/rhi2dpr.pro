;===============================================================================
;+
; Copyright © 2014, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; rhi2dpr.pro          Morris/SAIC/GPM_GV      August 2014
;
; DESCRIPTION
; -----------
; Performs a resampling of DPR and GR data to common 3-D volumes, as defined in
; the horizontal by the location of DPR rays, and in the vertical by the heights
; of the intersection of the DPR rays with the top and bottom edges of
; individual ray elevations of a ground radar scanning in RHI mode.  The data
; domain is determined by the location of the ground radars relative to the DPR
; swath, the azimuth angle(s) at which the ground radar performed the RHI scan,
; and by the cutoff range (range_threshold_km) which is a mandatory parameter
; for this procedure.  The DPR and GR (ground radar) files to be processed are
; specified in the control_file, which is a mandatory parameter containing the
; fully-qualified file name of the control file to be used in the run.  Optional
; parameters (GPM_ROOT and DIRxx) define non-default local paths to the DPR and
; GR files whose partial pathnames are listed in the control file.  The defaults
; for these paths are as specified in the environs.inc file.  All file path
; optional parameter values must begin with a leading slash (e.g., '/mydata')
; and be enclosed in quotes, as shown.  Optional binary keyword parameters
; control immediate output of DPR-GR reflectivity differences (/SCORES), and
; plotting of the matched DPR and GR reflectivity fields in the form of RHIs
; (/PLOT_RHIS).
;
; The control file is of a specific layout and contains specific fields in a
; fixed order and format.  See the script "do_DPR_GeoMatch.sh", which
; creates the control file and invokes IDL to run this procedure.  Completed
; DPR and GR matchup data for an individual site overpass event (i.e., a given
; GPM orbit and ground radar site) are written to a netCDF file.  The size of
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
; NOTE: THE SET OF CODE CONTAINED IN THIS FILE IS NOT THE COMPLETE RHI2DPR
;       PROCEDURE.  THE REMAINING CODE IN THE FULL PROCEDURE IS CONTAINED IN
;       THE FILE "rhi2dpr_resampling.pro", WHICH IS INCORPORATED INTO THIS
;       FILE/PROCEDURE BY THE IDL "include" MECHANISM.
;
;
; MODULES
; -------
;   1) PROCEDURE skip_gr_events     (this file)
;   2) PROCEDURE rhi2dpr          (this file, with rhi2dpr_resampling.pro)
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
; 8/2014 by Bob Morris, GPM GV (SAIC)
;  - Created from polar2dpr.pro.
; 9/11/2014 by Bob Morris, GPM GV (SAIC)
;  - Fixed bugs in computing (x,y) coordinates along radial and in finding DPR
;    footprints at either end of RHI radials.
; 11/05/14 by Bob Morris, GPM GV (SAIC)
;  - Added processing of GR RC and RP rainrate fields for version 1.1 file.
; 03/12/15 by Bob Morris, GPM GV (SAIC)
;  - Added a check of elevation angles to handle where negative elevations
;    have been wrapped around 360 degrees and become large positive angles.
; 03/17/15 by Bob Morris, GPM GV (SAIC)
;  - Added FLAT_NCPATH parameter to control whether we generate the hierarchical
;    netCDF output file paths (default) or continue to write the netCDF files to
;    the "flat" directory defined by NC_DIR or NCGRIDS_ROOT+GEO_MATCH_NCDIR (if
;    FLAT_NCPATH is set to 1).
;  - Added NON_PPS_FILES binary keyword parameter to ignore expected PPS
;    filename convention for GPM product filenames in control file when set.
;  - Added assignment of ELLIPSOID_BIN_DPR to ELLIPSOID_BIN_HS or
;    ELLIPSOID_BIN_NS_MS depending on swath, for 2ADPR/2AKu/2AKa ellipsoid
;    fixed gate positions.
;  - Handle situation of no paramDSD field present in SLV group (2ADPR/MS).
;  - Moved assignment of DR_KD_MISSING out of conditional blocks so that it is
;    always defined, as required.
;  - Added DPR heightStormTop and piaFinal fields to version 1.1 file.
;  - Changed the hard-coded assignment of the non-Z ufstruct field IDs to instead
;    use the field ID returned by get_site_specific_z_volume(), so that when a
;    substitution for our standard UF ID happens, the structure reflects the UF
;    field that actually exists in, and was read from, the UF file.
; 06/19/15 by Bob Morris, GPM GV (SAIC)
;  - Changed data type of tocdf_rayNum to short INT (FIX) to match data type as
;    defined in the netCDF file.
;
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;===============================================================================

PRO skip_gr_events, lun, nsites
   line = ""
   FOR igv=0,nsites-1  DO BEGIN
     ; read and print the control file GR site ID, lat, lon, elev, filename, etc.
      READF, lun, line
      PRINT, igv+1, ": ", line
   ENDFOR
END

;*******************************************************************************

PRO rhi2dpr, control_file, range_threshold_km, GPM_ROOT=gpmroot, $
             DIRDPR=dir2adpr, DIRKU=dir2aku, DIRKA=dir2aka, DIRCOMB=dircomb, $
             DIRGV=dirgv, SCORES=run_scores, PLOT_RHIS=plot_RHIs, $
             NC_DIR=nc_dir, NC_NAME_ADD=ncnameadd, DPR_DBZ_MIN=dpr_dbz_min, $
             DBZ_MIN=dBZ_min, DPR_RAIN_MIN=dpr_rain_min, $
             NON_PPS_FILES=non_pps_files, FLAT_NCPATH=flat_ncpath

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
   Instrument_ID = parsed[5]        ; 2A algorithm/product: Ka, Ku, or DPR
   DPR_scantype = parsed[6]        ; HS, MS, or NS


  ; set up the date/product-specific output filepath
  ; Note we won't use this if the FLAT_NCPATH keyword is set

   matchup_file_version=0.0  ; give it a bogus value, for now
  ; Call gen_geo_match_netcdf with the option to only get current file version
  ; so that it can become part of the matchup file name
   throwaway = gen_dpr_geo_match_netcdf( GEO_MATCH_VERS=matchup_file_version )

  ; substitute an underscore for the decimal point in matchup_file_version
   verarr=strsplit(string(matchup_file_version,FORMAT='(F0.1)'),'.',/extract)
   verstr=verarr[0]+'_'+verarr[1]

  ; generate the netcdf matchup file path
   IF KEYWORD_SET(flat_ncpath) THEN BEGIN
      NC_OUTDIR = NCGRIDSOUTDIR
   ENDIF ELSE BEGIN
      NC_OUTDIR = NCGRIDSOUTDIR+'/GPM/2A'+Instrument_ID+'/'+DPR_scantype+'/'+ $
                  DPR_version+'/'+verstr+'/20'+STRMID(DATESTAMP, 0, 2)  ; 4-digit Year
   ENDELSE


  ; get filenames as listed in/on the database/disk
   IF KEYWORD_SET(non_pps_files) THEN BEGIN
      origFileDPRName='no_2ADPR_file'
      origFileKaName='no_2AKA_file'
      origFileKuName='no_2AKU_file'
      origFileCMBName = 'no_2BCMB_file'
      ; don't expect a PPS-type filename, just set file based on Instrument_ID
      DPR_filepath = STRTRIM(parsed[7],2)
      CASE Instrument_ID OF
         'DPR' : origFileDPRName = DPR_filepath
          'Ka' : origFileKaName = DPR_filepath
          'Ku' : origFileKuName = DPR_filepath
          ELSE : BEGIN
                    print, "Error(s) in DPR/Ka/Ku control file specification."
                    PRINT, "Line: ", dataPR
                    PRINT, "Skipping events for orbit = ", orbit
                    skip_gr_events, lun0, nsites
                    PRINT, ""
                    GOTO, nextOrbit
                 END
      ENDCASE
   ENDIF ELSE BEGIN
      ; expect a PPS-type filename, check for it
      idxDPR = WHERE(STRMATCH(parsed, '*2A*.GPM.DPR*', /FOLD_CASE) EQ 1, countDPR)
      if countDPR EQ 1 THEN origFileDPRName = STRTRIM(parsed[idxDPR],2) $
         ELSE origFileDPRName='no_2ADPR_file'
      idxKU = WHERE(STRMATCH(parsed,'*2A*.GPM.Ku*', /FOLD_CASE) EQ 1, countKU)
      if countKU EQ 1 THEN origFileKuName = STRTRIM(parsed[idxKU],2) $
         ELSE origFileKuName='no_2AKU_file'
      idxKA = WHERE(STRMATCH(parsed,'*2A*.GPM.Ka*', /FOLD_CASE) EQ 1, countKA)
      if countKA EQ 1 THEN origFileKaName = STRTRIM(parsed[idxKA],2) $
         ELSE origFileKaName='no_2AKA_file'
      idxCMB = WHERE(STRMATCH(parsed,'*2B*.GPM.DPRGMI*', /FOLD_CASE) EQ 1, countCMB)
      IF countCMB EQ 1 THEN origFileCMBName = STRTRIM(parsed[idxCMB],2) $
                       ELSE origFileCMBName = 'no_2BCMB_file'
      IF ( origFileKaName EQ 'no_2AKA_file' AND $
           origFileKuName EQ 'no_2AKU_file' AND $
           origFileDPRName EQ 'no_2ADPR_file' ) THEN BEGIN
         PRINT, ""
         PRINT, "ERROR finding a 2A-DPR, 2A-KA , or 2A-KU product file name", $
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
      dataQuality = (*ptr_swath.PTR_FLG).QUALITYDATA  ; new variable to deal with
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
           orbit = parsed[1]
           siteID = parsed[2]    ; GPMGV siteID
           dpr_dtime = parsed[3]
           dpr_dtime_ticks = parsed[4]
           siteLat = FLOAT( parsed[5] )
           siteLon = FLOAT( parsed[6] )
           siteElev = FLOAT( parsed[7] )
           origUFName = parsed[8]  ; filename as listed in/on the database/disk
         END
     6 : BEGIN   ; streamlined control file format, already have orbit #
           siteID = parsed[0]    ; GPMGV siteID
           dpr_dtime = parsed[1]
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
           origUFName = parsed[5]  ; filename as listed in/on the database/disk
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
   ENDIF ELSE BEGIN
      if radar.h.scan_mode ne 'RHI' then begin
          message, file_1CUF + ' radar.h.scan_mode is ' + radar.h.scan_mode + $
              ', should be RHI.', /continue
          GOTO, nextGRfile
      endif
   ENDELSE

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
              NW_ID:    'Unspecified' }

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

   DR_KD_MISSING = (radar_dp_parameters()).DR_KD_MISSING ; always needs defined

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
      PRINT, "Error finding 'RR' volume in radar structure from file: ", file_1CUF
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
      ufstruct.HID_ID = 'FH'
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
      ufstruct.D0_ID = 'D0'
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
      ufstruct.NW_ID = 'NW'
   ENDELSE

  ; get the number of RHI cuts in the volume -- RSL stores an RHI cut in sweep
  ; structures
  nrhi = radar.volume[z_vol_num].h.NSWEEPS

  ; get the array of RHI azimuth angles
  rhiAzimuths = radar.volume[z_vol_num].sweep[*].h.ELEV

  ; get the number of "real" elevation steps in the RHI by looking for rays
  ; with non-zero bin counts.  There seems to be a fixed minimum number of
  ; "rays" (i.e., elevations) in the RHI files, with some being empty padding
; BIG ASSUMPTION THAT ALL RHIs HAVE THE SAME NUMBER OF REAL STEPS
  num_elevations = 999L
  nbyrhi = LONARR(nrhi)
  nbins2grab = 0                ; use later to "reform" RHI to PPI sector
  FOR iswp = 0, nrhi-1 DO BEGIN
     binsperray = radar.volume[z_vol_num].sweep[0].ray[*].h.nbins
     idxrayok = WHERE( binsperray GT 0, count )
     nbyrhi[iswp] = count
     IF count LT num_elevations THEN num_elevations = count
     IF MAX(binsperray) GT nbins2grab THEN nbins2grab = MAX(binsperray)
  ENDFOR
  n2grab = MIN(nbyrhi, MAX=n2sizefor)
  IF n2sizefor NE n2grab OR num_elevations NE n2grab THEN $
     message, 'nrays in each RHI differs: ' + STRING(nbyrhi)

  lastbin2grab = nbins2grab-1   ; use later to "reform" RHI to PPI sector

  ; get the arrays of elev angles for each RHI
  all_elevs = FLTARR(num_elevations, nrhi)
  FOR iswp = 0, nrhi-1 DO all_elevs[*,iswp] = $
     radar.volume[z_vol_num].sweep[iswp].ray[0:num_elevations-1].h.elev

  ; check for situation where negative elevations "wrap around" 360 degrees
  idxwrapped = WHERE( all_elevs GT 350.0, countwrapped)
  IF countwrapped GT 0 THEN all_elevs[idxwrapped] = all_elevs[idxwrapped]-360.

  IF nrhi GT 1 THEN BEGIN
     ; compare each RHI's elevations against a "baseline" to see if they
     ; are "aligned".  Compare the ray-to-ray elevation increment against
     ; the RHI-to-RHI elevation difference at a given ray position.  If the
     ; latter difference is less than half the elevation increment, then
     ; the RHIs are considered to be aligned.
 
     idxstartelev = FLTARR(nrhi)
     idxendelev = FLTARR(nrhi)
     idxendelev[*] = num_elevations-1
     nbyrhi = INTARR(nrhi)
     nbyrhi[*] = num_elevations
     eldifVert = all_elevs[1,0]-all_elevs[0,0]  ; step between rays in vertical
     maxelev1 = MAX(all_elevs[0,*], MIN=minelev1)
;     base_elev = MAX(all_elevs[0,*])  ; highest start elevation of all RHIs
     ; take an angle 3/4 of the way up between the max and min starting
     ; elevations as the basis for determining alignment at the bottom of RHI.
     ; - this only works if the difference in start elevations is not greatly
     ;   larger than the increment between rays
     base_elev = maxelev1 - (maxelev1-minelev1)/4
;     max_shift = FIX( (base_elev - MIN(all_elevs[0,*]))/eldifVert + 0.5 )
     max_shift = FIX( (base_elev - minelev1)/eldifVert + 0.5 )
     FOR iswp = 0, nrhi-1 DO BEGIN
        ; compare starting elevation of each RHI to that of the highest-start RHI
        eldifHorz = base_elev-all_elevs[0,iswp]
        IF eldifHorz GT eldifVert/2 THEN BEGIN
           ; we are NOT aligned ray-to-ray at the bottom, put on a shift
           n2shift = FIX( eldifHorz/eldifVert + 0.5 )
           ; next ray starts at a lower elevation than the highest, shift its
           ; starting elevation index.
           idxstartelev[iswp] = n2shift
           ; if shifting less than max_shift, then also truncate idxendelev
           IF n2shift LT max_shift THEN idxendelev[iswp] = $
              idxendelev[iswp] - (max_shift-n2shift)
           nbyrhi[iswp] = nbyrhi[iswp] - max_shift
        ENDIF ELSE BEGIN
           ; we ARE aligned ray-to-ray at the bottom, just truncate idxendelev
           idxendelev[iswp] = idxendelev[iswp] - max_shift
           nbyrhi[iswp] = nbyrhi[iswp] - max_shift
        ENDELSE
     ENDFOR
     ; grab the aligned elevations for all RHIs
     num_elevations = MIN(nbyrhi)
     idxdiffers = WHERE( nbyrhi NE num_elevations, ndiffers )
     IF ndiffers NE 0 THEN message, "nrays in each RHI differs" + STRING(nbyrhi)
     aligned_elevs = FLTARR(num_elevations, nrhi)
     FOR iswp = 0, nrhi-1 DO BEGIN
        aligned_elevs[*,iswp] = $
           all_elevs[idxstartelev[iswp]:idxendelev[iswp],iswp]
     ENDFOR
     ; compute a new mean set of elevations from the aligned values
     mean_elevs = MEAN(aligned_elevs, DIMENSION=2)

  ENDIF ELSE BEGIN   ; else, if nrhi GT 1

     idxstartelev = 0
     idxendelev = num_elevations-1
     nbyrhi = num_elevations
     mean_elevs = all_elevs

  ENDELSE            ; endelse, if nrhi GT 1

print, idxstartelev
print, idxendelev
for jrhi=0,nrhi-1 do print, all_elevs[idxstartelev[jrhi],jrhi],all_elevs[idxendelev[jrhi],jrhi]
print, ''
print, "mean_elevs: ", mean_elevs 

  ; define an array to hold a PPI-like data structure for each of our field(s),
  ; and read the "aligned" RHI data into this array

  z_ppi = FLTARR(nbins2grab, nrhi, num_elevations)
  n_bins_filled = INTARR(nrhi, num_elevations)     ; # bins of non-fill in each ray
  range_bin1 = INTARR(nrhi, num_elevations)        ; # bins of fill at start of ray
  FOR iswp = 0, nrhi-1 DO BEGIN
     jray=0
     FOR iray = idxstartelev[iswp], idxendelev[iswp] DO BEGIN
         z_ppi[*, iswp, jray] = $
           radar.volume[z_vol_num].sweep[iswp].ray[iray].range[0:lastbin2grab]
         n_bins_filled[iswp,jray] = $
           radar.volume[z_vol_num].sweep[iswp].ray[iray].h.nbins
         range_bin1[iswp,jray] = $
           radar.volume[z_vol_num].sweep[iswp].ray[iray].h.range_bin1
         jray++
     ENDFOR
   ENDFOR
   IF ( zdr_vol_num GE 0 )  THEN BEGIN
      zdr_ppi = FLTARR(nbins2grab, nrhi, num_elevations)
      FOR iswp = 0, nrhi-1 DO BEGIN
         jray=0
         FOR iray = idxstartelev[iswp], idxendelev[iswp] DO BEGIN
             zdr_ppi[*, iswp, jray] = $
               radar.volume[zdr_vol_num].sweep[iswp].ray[iray].range[0:lastbin2grab]
             jray++
         ENDFOR
       ENDFOR
   ENDIF
   IF ( kdp_vol_num GE 0 )  THEN BEGIN
      kdp_ppi = FLTARR(nbins2grab, nrhi, num_elevations)
      FOR iswp = 0, nrhi-1 DO BEGIN
         jray=0
         FOR iray = idxstartelev[iswp], idxendelev[iswp] DO BEGIN
             kdp_ppi[*, iswp, jray] = $
               radar.volume[kdp_vol_num].sweep[iswp].ray[iray].range[0:lastbin2grab]
             jray++
         ENDFOR
       ENDFOR
   ENDIF
   IF ( rhohv_vol_num GE 0 )  THEN BEGIN
      rhohv_ppi = FLTARR(nbins2grab, nrhi, num_elevations)
      FOR iswp = 0, nrhi-1 DO BEGIN
         jray=0
         FOR iray = idxstartelev[iswp], idxendelev[iswp] DO BEGIN
             rhohv_ppi[*, iswp, jray] = $
               radar.volume[rhohv_vol_num].sweep[iswp].ray[iray].range[0:lastbin2grab]
             jray++
         ENDFOR
       ENDFOR
   ENDIF
   IF ( rc_vol_num GE 0 )  THEN BEGIN
      rc_ppi = FLTARR(nbins2grab, nrhi, num_elevations)
      FOR iswp = 0, nrhi-1 DO BEGIN
         jray=0
         FOR iray = idxstartelev[iswp], idxendelev[iswp] DO BEGIN
             rc_ppi[*, iswp, jray] = $
               radar.volume[rc_vol_num].sweep[iswp].ray[iray].range[0:lastbin2grab]
             jray++
         ENDFOR
       ENDFOR
   ENDIF
   IF ( rp_vol_num GE 0 )  THEN BEGIN
      rp_ppi = FLTARR(nbins2grab, nrhi, num_elevations)
      FOR iswp = 0, nrhi-1 DO BEGIN
         jray=0
         FOR iray = idxstartelev[iswp], idxendelev[iswp] DO BEGIN
             rp_ppi[*, iswp, jray] = $
               radar.volume[rp_vol_num].sweep[iswp].ray[iray].range[0:lastbin2grab]
             jray++
         ENDFOR
       ENDFOR
   ENDIF
   IF ( rr_vol_num GE 0 )  THEN BEGIN
      rr_ppi = FLTARR(nbins2grab, nrhi, num_elevations)
      FOR iswp = 0, nrhi-1 DO BEGIN
         jray=0
         FOR iray = idxstartelev[iswp], idxendelev[iswp] DO BEGIN
             rr_ppi[*, iswp, jray] = $
               radar.volume[rr_vol_num].sweep[iswp].ray[iray].range[0:lastbin2grab]
             jray++
         ENDFOR
       ENDFOR
   ENDIF
   IF ( hid_vol_num GE 0 )  THEN BEGIN
      hid_ppi = FLTARR(nbins2grab, nrhi, num_elevations)
      FOR iswp = 0, nrhi-1 DO BEGIN
         jray=0
         FOR iray = idxstartelev[iswp], idxendelev[iswp] DO BEGIN
             hid_ppi[*, iswp, jray] = $
               radar.volume[hid_vol_num].sweep[iswp].ray[iray].range[0:lastbin2grab]
             jray++
         ENDFOR
       ENDFOR
   ENDIF
   IF ( dzero_vol_num GE 0 )  THEN BEGIN
      dzero_ppi = FLTARR(nbins2grab, nrhi, num_elevations)
      FOR iswp = 0, nrhi-1 DO BEGIN
         jray=0
         FOR iray = idxstartelev[iswp], idxendelev[iswp] DO BEGIN
             dzero_ppi[*, iswp, jray] = $
               radar.volume[dzero_vol_num].sweep[iswp].ray[iray].range[0:lastbin2grab]
             jray++
         ENDFOR
       ENDFOR
   ENDIF
   IF ( nw_vol_num GE 0 )  THEN BEGIN
      nw_ppi = FLTARR(nbins2grab, nrhi, num_elevations)
      FOR iswp = 0, nrhi-1 DO BEGIN
         jray=0
         FOR iray = idxstartelev[iswp], idxendelev[iswp] DO BEGIN
             nw_ppi[*, iswp, jray] = $
               radar.volume[nw_vol_num].sweep[iswp].ray[iray].range[0:lastbin2grab]
             jray++
         ENDFOR
       ENDFOR
   ENDIF

   tocdf_elev_angle = mean_elevs
   num_elevations_out = N_ELEMENTS(tocdf_elev_angle)

  ; precompute cos(elev) for later repeated use
   cos_elev_angle = COS( tocdf_elev_angle * !DTOR )

  ; Get the times of the first ray in each sweep -- text_sweep_times will be
  ;   formatted as YYYY-MM-DD hh:mm:ss, e.g., '2008-07-09 00:10:56'
   num_times = get_sweep_times( z_vol_num, radar, dtimestruc )
   text_sweep_timesRHI = dtimestruc.textdtime  ; STRING array, human-readable
   ticks_sweep_timesRHI = dtimestruc.ticks     ; DOUBLE array, time in unix ticks

  ; Only have one time value per RHI cut, but we need one value per elevation cut
  ; for the netCDF file, so grab the middle time and replicate it
   text_sweep_times = REPLICATE(text_sweep_timesRHI[nrhi/2],num_elevations_out)
   ticks_sweep_times = REPLICATE(ticks_sweep_timesRHI[nrhi/2],num_elevations_out)

  ; get the other radar structure variables we need for the resampling portion
   beam_width = radar.volume[z_vol_num].sweep[0].h.beam_width
   gate_space_gv = radar.volume[z_vol_num].sweep[0].ray[0].h.gate_size/1000.  ; units converted to km

  ;  WE ARE DONE WITH THE 'radar' STRUCTURE AT THIS POINT, FREE UP ITS SPACE
   radar = 0

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

   ; generate arrays of scan and ray number for each DPR footprint in the prlats
   ; or prlons arrays
   all_1D_idx = LINDGEN(N_ELEMENTS(prlats))
   all_2D_idx = ARRAY_INDICES(prlats,all_1D_idx)
   all_raynums = REFORM(all_2D_idx[0,*],RAYSPERSCAN,SAMPLE_RANGE)
   all_scannums = REFORM(all_2D_idx[1,*],RAYSPERSCAN,SAMPLE_RANGE)
   all_1D_idx = 0   ; free up array storage
   all_2D_idx = 0   ; free up array storage
   subset_raynum = all_raynums[*,start_scan:end_scan]
   subset_scannum = all_scannums[*,start_scan:end_scan]
   subset_DPRindex = dpr_index_all[*,start_scan:end_scan]   ; 2-D indices previously computed

;-------------------------------------------------------------------------------
  ; Populate arrays holding 'exact' DPR at-surface X and Y and range values for
  ; the in-range subset of scans.
   XY_km = map_proj_forward( prlons[*,start_scan:end_scan], $
                             prlats[*,start_scan:end_scan], $
                             map_structure=smap ) / 1000.
   dpr_x0 = XY_km[0,*]
   dpr_y0 = XY_km[1,*]
   dpr_x0 = REFORM( dpr_x0, RAYSPERSCAN, nscans2do, /OVERWRITE )
   dpr_y0 = REFORM( dpr_y0, RAYSPERSCAN, nscans2do, /OVERWRITE )

   precise_range = SQRT( dpr_x0^2 + dpr_y0^2 )

   ; get x,y coordinates at the far end of the RHI radials - near end is (0,0)
   x_rhis = range_threshold_km * SIN( rhiAzimuths * !DTOR )
   y_rhis = range_threshold_km * COS( rhiAzimuths * !DTOR )
   ; append the origin x and y to these arrays
   x_rhis = [x_rhis, 0.0]
   y_rhis = [y_rhis, 0.0]
   ; determine the min and max x and y for the line segments
   x_rhi_min = MIN( x_rhis, MAX = x_rhi_max )
   y_rhi_min = MIN( y_rhis, MAX = y_rhi_max )
   ; extend these bounds out by 3 km in each direction to define an x,y "box"
   ; enclosing the RHI (truncated PPI) domain
   x_rhi_min = x_rhi_min - 3.0
   x_rhi_max = x_rhi_max + 3.0
   y_rhi_min = y_rhi_min - 3.0
   y_rhi_max = y_rhi_max + 3.0

   ; identify the DPR footprints inside the RHI domain box
   idxDPRinBox = WHERE(dpr_x0 GE x_rhi_min AND dpr_x0 LE x_rhi_max AND $
                       dpr_y0 GE y_rhi_min AND dpr_y0 LE y_rhi_max, countInBox)

   IF ( countInBox EQ 0 ) THEN BEGIN
      print, "No footprints in range of RHI coverage, bailing."
      GOTO, nextGRfile
   ENDIF

   ; grab the dpr_x0, dpr_y0, subset_raynum, and subset_scannum values inside box
   dpr_x0_box = dpr_x0[idxDPRinBox]
   dpr_y0_box = dpr_y0[idxDPRinBox]
   subset_raynum_box = subset_raynum[idxDPRinBox]
   subset_scannum_box = subset_scannum[idxDPRinBox]
   subset_DPRindex_box = subset_DPRindex[idxDPRinBox]

   ; compute the equation of the line connecting each endpoint of the RHIs,
   ; and find the nearest DPR footprint to either end of the line
   scanstart=LONARR(nrhi) & scanend=LONARR(nrhi)
   raystart=LONARR(nrhi) & rayend=LONARR(nrhi)

   FOR irhi = 0, nrhi-1 DO BEGIN

      ; compute the slope and intercept of the line from (0,0) to RHI end
      ; defined by x_rhis and y_rhis
      IF (ABS(x_rhis[irhi]) GT 0.001) THEN BEGIN  ; changed to ABS() on 9/11/14
         ; slope is finite, compute the line parameters
         slope = y_rhis[irhi]/x_rhis[irhi]    ; Duh!
         yintercept=0.0                       ; Duh! again
         IF ABS(slope) GT 0.0001 THEN slopesign = slope/ABS(slope) $    ; positive or negative slope?
         ELSE BEGIN
            slope = 0.0001   ; avoid divide by zero
            slopesign = 0.0
         ENDELSE
         ; next, walk along the radial from the origin point and find the
         ; x- and y-coordinates every 1 km along that line
         IF ABS(slope) GT 1.0 THEN BEGIN
            ; define the number of points along the line
            nwalk = FIX( ABS(y_rhis[irhi]) + 0.5 )
            xline = FLTARR(nwalk+1) & yline = xline
            ; increment y, compute new x, and store points in xline and yline
            IF y_rhis[irhi] GT 0.0 THEN BEGIN
               yend = nwalk
               yinc = 1               ; step in +y direction
            ENDIF ELSE BEGIN
               yend = -1*nwalk
               yinc = -1              ; step in -y direction
            ENDELSE
            FOR ypix = 0, yend, yinc DO BEGIN
               idx = ABS(ypix)
               yline[idx] = FLOAT(ypix)
               xline[idx] = (ypix-yintercept)/slope + 0.5*slopesign*yinc
            ENDFOR
         ENDIF ELSE BEGIN
            ; define the number of points along the line
            nwalk = FIX( ABS(x_rhis[irhi]) + 0.5 )
            xline = FLTARR(nwalk+1) & yline = xline
            ; increment x, compute new y, and store points in xline and yline
            IF x_rhis[irhi] GT 0.0 THEN BEGIN
               xend = nwalk
               xinc = 1
            ENDIF ELSE BEGIN
               xend = -1*nwalk
               xinc = -1
            ENDELSE
            FOR xpix = 0, xend, xinc DO BEGIN
               idx = ABS(xpix)
               xline[idx] = FLOAT(xpix)
               yline[idx] = yintercept + slope*xpix + 0.5*slopesign*xinc
            ENDFOR
         ENDELSE
      ENDIF ELSE BEGIN   ; if (x_rhis[irhi] NE 0.0)
         ; slope is infinite, just walk up/down in y-direction
         nwalk = FIX( ABS(y_rhis[irhi]) + 0.5 )
         xline = FLTARR(nwalk)
         xline[*] = 0.0
         yline = FINDGEN(nwalk)
         IF y_rhis[irhi] LT 0.0 THEN yline = -1.0*yline
      ENDELSE

      ; find the nearest DPR footprint and its distance to each (xline,yline)
      ; point along the radial, using our fast match utility with a search
      ; radius of 4.0 km
      DPRdist=0.0  ; just define variable for match_2d call
      idxnearestDPR = match_2d( xline, yline, dpr_x0_box, dpr_y0_box, 4.0, $
                                MATCH_DISTANCE=DPRdist)
      ; limit ourselves to points along the line with assigned DPR footprints
      idxinrange = WHERE(idxnearestDPR GE 0, ninrange)
      IF ninrange EQ 0 THEN BEGIN
         message, "No footprints in range along RHI radial.  Must have code error.", /INFO
         GOTO, nextGRfile
      ENDIF
      startinglineidx=idxinrange[0]
      endinglineindex=idxinrange[ninrange-1]

      ; Starting from either end, find the nearest DPR footprint to that end of
      ; the line.  If first point on line is at an internal DPR scan point
      ; (0<raynum<NRAYSPERSCAN), then that DPR footprint is the starting DPR
      ; footprint of those nearest to the radial.  If point(s) along the line
      ; have a -1 value for the nearest DPR footprint, then the point is beyond
      ; the search radius from the nearest DPR (outside the DPR swath) and we
      ; need to step along the line until we find a valid DPR footprint.  Once
      ; we find a valid DPR footprint, it will either be at the raynum=0 edge of
      ; the DPR swath, or the raynum=RAYSPERSCAN end of the DPR swath.  Once we
      ; figure out which end of the swath we are nearest to, find the first DPR
      ; footprint with a distance-to-line of 3 km or less.  Then, once we
      ; have identified the two ends of the RHI/DPR overlap, step along the
      ; points along the line between, and including, these two endpoints;
      ; then grab the DPR footprint indices for all these points, sort the DPR
      ; indices, and remove duplicates.

      ; find our starting footprint/point pairing
;      FOR idx = startinglineidx, endinglineindex DO BEGIN
      FOR idx = 0, ninrange-1 DO BEGIN
         raynumNearest = subset_raynum_box[idxnearestDPR[idxinrange[idx]]]
         IF (raynumNearest EQ 0) OR (raynumNearest EQ RAYSPERSCAN) THEN BEGIN
            ; check the distance to the footprint, if it's within 3 km take
            ; this point as our starting DPR footprint
            IF DPRdist[idxinrange[idx]] LT 3.0 THEN BEGIN
               idxLineStart = idx
               BREAK
            ENDIF
         ENDIF ELSE BEGIN
            ; we have an internal DPR footprint, tag our starting point
            idxLineStart = idx
            BREAK
         ENDELSE
      ENDFOR
      ; now find our ending footprint/point pairing
      FOR idx = ninrange-1, 0, -1  DO BEGIN
         raynumNearest = subset_raynum_box[idxnearestDPR[idxinrange[idx]]]
         IF (raynumNearest EQ 0) OR (raynumNearest EQ RAYSPERSCAN) THEN BEGIN
            ; check the distance to the footprint, if it's within 3 km take
            ; this point as our ending DPR footprint
            IF DPRdist[idxinrange[idx]] LT 3.0 THEN BEGIN
               idxLineEnd = idx
               BREAK
            ENDIF
         ENDIF ELSE BEGIN
            ; we have an internal DPR footprint, tag our ending point
            idxLineEnd = idx
            BREAK
         ENDELSE
      ENDFOR
      ; check for consistency, can't have end < start
      IF idxLineStart GT idxLineEnd THEN message, "Problem finding start/end footprints."

      ; grab the DPR subset indices of all the points along the line, sort them,
      ; and extract unique values
      DPRindexRHIline = subset_DPRindex_box[idxnearestDPR[idxinrange[idxLineStart:idxLineEnd]]]
      DPRindex2add = DPRindexRHIline[UNIQ(DPRindexRHIline,SORT(DPRindexRHIline))]
      IF irhi EQ 0 THEN BEGIN
         dprRHIidx = DPRindex2add  ; initialize "accumulated" DPR index array
      ENDIF ELSE BEGIN
         ; append this radial's DPR index values to accumulated value array
         dprRHIidx=[dprRHIidx, DPRindex2add]
         ; eliminate duplicates again
         dprRHIidx=dprRHIidx[UNIQ(dprRHIidx,SORT(dprRHIidx))]
      ENDELSE

   ENDFOR  ; loop over RHI radials

   numDPRrays = 0      ; number of in-range, scan-edge, and range-adjacent points
   numPRinrange = 0   ; number of in-range-only points found
  ; Variables used to find 'farthest from nadir' in-range DPR footprint:
   maxrayidx = 0
   minrayidx = RAYSPERSCAN-1

;-------------------------------------------------------------------------------

  ; determine a new list of scans to iterate over, based on the set of
  ; scans mapped to the RHIs
   mapped_scan = all_scannums[dprRHIidx]
   RHI_scan_list = mapped_scan[UNIQ(mapped_scan,SORT(mapped_scan))]

  ; Identify actual DPR points mapped to the RHI radials.  Compute DPR
  ; footprint corner x,y's for these points, and parallax adjusted corners and
  ; lat/lons for each mean elevation angle in the RHIs.

   mapped_rays = all_raynums[dprRHIidx]

   FOR iscan = 0, N_ELEMENTS(RHI_scan_list)-1  DO BEGIN
      scan_num = RHI_scan_list[iscan]
      subset_scan_num = scan_num - start_scan   ; need this to index into precise_range
     ; prep scan-dependent variables for parallax computations
      m = 0.0        ; SLOPE AS DX/DY
      dy_sign = 0.0  ; SENSE IN WHICH Y CHANGES WITH INCR. SCAN ANGLE, = -1 OR +1
      get_scan_slope_and_sense, smap, prlats, prlons, scan_num, RAYSPERSCAN, $
                                m, dy_sign

      ; find out which rays in this scan are mapped to the RHI
      idxthismappedscan = WHERE(mapped_scan EQ scan_num, nrays_for_scan)
      IF nrays_for_scan GT 0 THEN RHI_rays_for_scan = mapped_rays[idxthismappedscan] $
      ELSE message, "No rays found for the mapped scan: "+STRING(scan_num)

      FOR iray = 0, nrays_for_scan-1  DO BEGIN
         ray_num = RHI_rays_for_scan[iray]
        ; add point to subarrays for DPR 2D index and for footprint lat/lon
        ; - MAKE THE INDEX IN TERMS OF THE (RAY,SCAN) COORDINATE ARRAYS

         dpr_master_idx[numDPRrays] = dpr_index_all[ray_num,scan_num] ; for GPM
         dpr_lat_sfc[numDPRrays] = prlats[ray_num,scan_num]
         dpr_lon_sfc[numDPRrays] = prlons[ray_num,scan_num]
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

        ; add DPR point(s) to the subarrays for each elevation
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

      ENDFOR              ; iray
   ENDFOR                 ; iscan 

  ; ONE TIME ONLY: compute max diagonal size of a DPR footprint, halve it,
  ;   and assign to max_DPR_footprint_diag_halfwidth.  Ignore the variability
  ;   with height.  Take middle scan of DPR/GR overlap within subset arrays:
   subset_scan_4size = mapped_scan[numDPRrays/2] - start_scan
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
      tocdf_meas_dbz = MAKE_ARRAY(numDPRrays, num_elevations_out, /float, $
                                  VALUE=FLOAT_RANGE_EDGE)
      tocdf_corr_dbz = MAKE_ARRAY(numDPRrays, num_elevations_out, /float, $
                                  VALUE=FLOAT_RANGE_EDGE)
      tocdf_corr_rain = MAKE_ARRAY(numDPRrays, num_elevations_out, /float, $
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
      tocdf_gr_expected = UINTARR(numDPRrays, num_elevations_out)
      tocdf_meas_z_rejected = UINTARR(numDPRrays, num_elevations_out)
      tocdf_corr_z_rejected = UINTARR(numDPRrays, num_elevations_out)
      tocdf_corr_r_rejected = UINTARR(numDPRrays, num_elevations_out)
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
         tocdf_heightStormTop[prgoodidx] = heightStormTop[pr_idx_2get]
        ; get the scan and ray number arrays for the footprint locations
        ; defined by pr_idx_2get
         tocdf_rayNum = FIX(tocdf_pr_idx)
         tocdf_scanNum = tocdf_pr_idx
         rayscan = ARRAY_INDICES(BBstatus, pr_idx_2get)
         tocdf_rayNum[prgoodidx] = FIX( REFORM(rayscan[0,*]) )
         tocdf_scanNum[prgoodidx] = REFORM(rayscan[1,*])
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
         tocdf_heightStormTop[predgeidx] = INT_OFF_EDGE
      ENDIF

   ENDIF ELSE BEGIN
      PRINT, ""
      PRINT, "No in-range DPR footprints found for ", siteID, ", skipping."
      PRINT, ""
      GOTO, nextGRfile
   ENDELSE

  ; ============================================================================

  ; Map this GR radar's data to these DPR footprints, where DPR rays
  ; intersect the elevation sweeps.  This part of the algorithm continues
  ; in code in a separate file, included below:

   @rhi2dpr_resampling.pro

  ; ============================================================================

  ; generate the netcdf matchup file path/name

   IF N_ELEMENTS(ncnameadd) EQ 1 THEN BEGIN
      fname_netCDF = NC_OUTDIR+'/'+DPR_GEO_MATCH_PRE+siteID+'.' $
                      +DATESTAMP+'.'+orbit+'.'+DPR_version+'.' $
                      +STRUPCASE(Instrument_ID)+'.'+STRUPCASE(DPR_scantype) $
                      +'.'+verstr+'.RHI.'+ncnameadd+NC_FILE_EXT
   ENDIF ELSE BEGIN
      fname_netCDF = NC_OUTDIR+'/'+DPR_GEO_MATCH_PRE+siteID+'.' $
                      +DATESTAMP+'.'+orbit+'.'+DPR_version+'.' $
                      +STRUPCASE(Instrument_ID)+'.'+STRUPCASE(DPR_scantype) $
                      +'.'+verstr+'.RHI'+NC_FILE_EXT
   ENDELSE

   ; store the file basenames in a string array to be passed to gen_geo_match_netcdf()
   infileNameArr = STRARR(5)
   infileNameArr[0] = FILE_BASENAME(origFileDPRName)
   infileNameArr[1] = FILE_BASENAME(origFileKuName)
   infileNameArr[2] = FILE_BASENAME(origFileKaName)
   infileNameArr[3] = FILE_BASENAME(origFileCMBName)
   infileNameArr[4] = base_1CUF

  ; Create a netCDF file with the proper 'numDPRrays' and 'num_elevations_out'
  ; dimensions, passing the global attribute values along
   ncfile = gen_dpr_geo_match_netcdf( fname_netCDF, numDPRrays, tocdf_elev_angle, $
                                  ufstruct, STRUPCASE(DPR_scantype), $
                                  DPR_version, siteID, infileNameArr )
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
   NCDF_VARPUT, ncid, 'BBheight', tocdf_BB_Hgt        ; data
    NCDF_VARPUT, ncid, 'have_BBheight', DATA_PRESENT  ; data presence flag
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

   NCDF_VARPUT, ncid, 'ZFactorMeasured', tocdf_meas_dbz         ; data
    NCDF_VARPUT, ncid, 'have_ZFactorMeasured', DATA_PRESENT     ; data presence flag
   NCDF_VARPUT, ncid, 'ZFactorCorrected', tocdf_corr_dbz        ; data
    NCDF_VARPUT, ncid, 'have_ZFactorCorrected', DATA_PRESENT    ; data presence flag
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
   NCDF_VARPUT, ncid, 'n_gr_expected', tocdf_gr_expected
   NCDF_VARPUT, ncid, 'n_dpr_meas_z_rejected', tocdf_meas_z_rejected
   NCDF_VARPUT, ncid, 'n_dpr_corr_z_rejected', tocdf_corr_z_rejected
   NCDF_VARPUT, ncid, 'n_dpr_corr_r_rejected', tocdf_corr_r_rejected
   NCDF_VARPUT, ncid, 'n_dpr_dm_rejected', tocdf_dpr_dm_rejected
   NCDF_VARPUT, ncid, 'n_dpr_nw_rejected', tocdf_dpr_nw_rejected
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
     ; delete the two RHI windows at the end
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
