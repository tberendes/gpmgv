;===============================================================================
;+
; Copyright © 2014, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; polar2dprgmi_v7.pro          Morris/SAIC/GPM_GV      May 2014
;
; DESCRIPTION
; -----------
; Performs a resampling of DPRGMI and GR data to common 3-D volumes, as defined
; in the horizontal by the location of DPRGMI rays, and in the vertical by the
; heights of the intersection of the DPRGMI rays with the top and bottom edges
; of individual elevation sweeps of a scanning ground radar.  Data domains are
; determined by the locations of ground radars overpassed by the DPRGMI swaths,
; and by the cutoff range (range_threshold_km) which is a mandatory parameter
; for this procedure.  The DPRGMI and GR (ground radar) files to be processed
; in a run are specified in the control_file, whose fully-qualified file name is
; a mandatory parameter for the procedure.  Optional parameters (GPM_ROOT and
; DIRxx) allow for non-default local paths to the DPRGMI and GR files whose
; partial pathnames are listed in the control file.  The defaults for these
; paths are as specified in the environs_v7.inc file.  All file path optional
; parameter values must begin with a leading slash (e.g., '/mydata') and be
; enclosed in quotes, as shown.  Optional binary keyword parameters control
; immediate output of DPRGMI-GR reflectivity differences (/SCORES), plotting
; of the matched DPRGMI and GR reflectivity fields sweep-by-sweep in the form of
; PPIs on a map background (/PLOT_PPIS), and plotting of the matching DPRGMI and
; GR bin horizontal outlines (/PLOT_BINS) for the common 3-D volume.
;
; The control file is of a specific layout and contains specific fields in a
; fixed order and format.  See the script "doDPRGMIGeoMatch4RainDates.sh", which
; creates the control file and invokes IDL to run this procedure.  Completed
; DPRGMI and GR matchup data for an individual site overpass event (i.e., a 
; given GPM orbit and ground radar site) are written to a netCDF file.  The size
; of the dimensions in the data fields in the netCDF file vary from one case to
; another, depending on the number of elevation sweeps in the GR radar volume
; scan and the number of DPRGMI footprints for each swath within the cutoff
; range of the GR site.
;
; The optional parameter NC_FILE specifies the directory to which the output
; netCDF files will be written.  It is created if it does not yet exist.  Its
; default value is derived from the variables NCGRIDS_ROOT+GEO_MATCH_NCDIR as
; specified in the environs_v7.inc file.  If the binary parameter FLAT_NCPATH is
; set then the output netCDF files are written directly under the NC_FILE
; directory (legacy behavior).  Otherwise a hierarchical subdirectory tree is
; (as needed) created under the NC_FILE directory, of the form:
;     /GPM/2BDPRGMI/PPS_VERSION/MATCHUP_VERSION/YEAR
; and the output netCDF files are written to this subdirectory.  The GPM and
; 2BDPRGMI subdirectory names are literal values "GPM" and "2BDPRGMI".  The
; remaining path components are determined in this procedure.
;
; An optional parameter (NC_NAME_ADD) specifies a component to be added to the
; output netCDF file name, to specify uniqueness in the case where more than
; one version of input data are used, a different range threshold is used, etc.
;
; NOTE: THE SET OF CODE CONTAINED IN THIS FILE IS NOT THE COMPLETE POLAR2DPRGMI
;       PROCEDURE.  THE REMAINING CODE IN THE FULL PROCEDURE IS CONTAINED IN
;       THE FILE "polar2dprgmi_resampling.pro", WHICH IS INCORPORATED INTO THIS
;       FILE/PROCEDURE BY THE IDL "include" MECHANISM.
;
;
; MODULES
; -------
;   1) FUNCTION  plot_bins_bailout  (this file)
;   2) PROCEDURE skip_gr_events     (this file)
;   3) PROCEDURE polar2dprgmi       (this file, with polar2dprgmi_resampling.pro
;                                    included by the IDL "include" mechanism)
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
; DPRGMI: 1) Only GPM 2B-DPRGMI data files in HDF5 format are supported.
;     GR: 1) Only radar data files in Universal Format (UF) are supported,
;         although radar files in other formats supported by the Radar
;         Software Library (RSL) may work, depending on constraint 2, below.
;      2) UF files for sites not 'known' to this code must label their quality-
;         controlled reflectivity data field name as 'CZ'.  This constraint is
;         coded in the function common_utils/get_site_specific_z_volume.pro
;
;
; HISTORY
; -------
; 5/2013 by Bob Morris, GPM GV (SAIC)
;  - Created from polar2dpr.pro.
; 10/13/2013  by Bob Morris, GPM GV (SAIC)
;  - Changed dBZ_min default value to 18.0 dBZ.
;  - Modified to skip over orbits without reading 2BDPRGMI product in cases
;    where all GR data files are missing.
;  - Modified to still try to do NS swath in cases where no MS footprints are
;    within range of the GR site.
; 11/10/14 by Bob Morris, GPM GV (SAIC)
;  - Added processing of GR RC and RP rainrate fields for version 1.1 file.
; 11/11/14 by Bob Morris, GPM GV (SAIC)
;  - Assign GATE_SPACE to BIN_SPACE_DPRGMI rather than BIN_SPACE_NS_MS to match
;    redefinition of gate spacings for MS and NS swaths in 2B-DPRGMI products.
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
; 06/16/15 by Bob Morris, GPM GV (SAIC)
;  - Added zeroDegAltitude and zeroDegBin fields to substitute for bright band
;    height not available in the 2BDPRGMI.
; 12/23/15 by Bob Morris, GPM GV (SAIC)
;  - Added DIR_BLOCK parameter and related processing of GR_blockage variable
;    and its presence flag for version 1.2 file.
; 01/21/16 by Bob Morris, GPM GV (SAIC)
;  - Added USE_DPR_ROI (radius of influence) parameter as an optional override
;    to the default radius of influence max_DPR_footprint_diag_halfwidth
;    computed internally at run time.  If set, use DPR_ROI value from the
;    include file dpr_params.inc.
; 04/19/16 by Bob Morris, GPM GV (SAIC)
;  - Added tabulation and netCDF output of clutterStatus values for both swaths
;    for version 1.21 file.
;  - Use clutterStatus to set DPRGMI science values to missing where layer is
;    totally below lowest clutter-free bin.
;  - Only write swath-invariant MS variables in Ku iteration.
;  - Let Ku/MS define which DPR rays have echoes for all MS processing, and
;    reinitialize dpr_echoes array between swath types.
;  - Handle 2 decimal places in matchup file version for netCDF file naming.
; 07/11/16 by Bob Morris, GPM GV (SAIC)
;  - Added processing of GR Dm and N2 dual-pol fields for version 1.3 file.
;  - Fixed bug where gen_dpr_geo_match_netcdf was called to get output netCDF
;    file version, rather than gen_dprgmi_geo_match_netcdf_v6.
; 11/19/16 by Bob Morris, GPM GV (SAIC)
;  - Added DPRGMI stormTopAltitude field for version 1.3 file.
; 11/17/20 by Todd Berendes, UAH
;  - Modified for GPM V7
;   removed precipTotPSDparamLow (Nw), PSDparamLowNode, precipTotPSDparamHigh(Dm)
;   added precipTotDm, precipTotLogNw, precipTotMu
; 4/6/22 by Todd Berendes UAH/ITSC
;  - Added new GR liquid and frozen water content fields
; 4/11/23 Todd Berendes UAH/ITSC
;  - removed Ground Radar DZERO and N2
;  - added n_gr_precip fields for Nw,Dm,RC,RR,RP,Mw,Mi
; 5/18/23 Todd Berendes UAH/ITSC
;  - added GR_sigmaDm variables
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

PRO polar2dprGMI_v7, control_file, range_threshold_km, GPM_ROOT=gpmroot, $
                  DIRCOMB=dircomb, DIRGV=dirgv, SCORES=run_scores, $
                  PLOT_PPIS=plot_PPIs, PLOT_BINS=plot_bins, NC_DIR=nc_dir, $
                  NC_NAME_ADD=ncnameadd, DPR_DBZ_MIN=dpr_dbz_min, $
                  MARK_EDGES=mark_edges, USE_DPR_ROI=use_dpr_roi, $
                  DBZ_MIN=dBZ_min, DPR_RAIN_MIN=dpr_rain_min, $
                  FLAT_NCPATH=flat_ncpath, DIR_BLOCK=dir_block

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

 COMMON sample, start_sample, sample_range, num_range, RAYSPERSCAN

; "Include" file for DATA_PRESENT, NO_DATA_PRESENT
@grid_def.inc
; "Include" file for DPR-product-specific parameters (i.e., RAYSPERSCAN):
@dpr_params_v7.inc
; "Include" file for names, paths, etc.:
@environs_v7.inc

; set to a constant, until database supports DPR product version override values
DPR_version = '0'

; for debugging
;!EXCEPT=2


; ***************************** Local configuration ****************************

   ; where provided, override file path default values from environs_v7.inc:
    in_base_dir =  GVDATA_ROOT ; default root dir for UF files
    IF N_ELEMENTS(dirgv)  EQ 1 THEN in_base_dir = dirgv

    IF N_ELEMENTS(gpmroot)  EQ 1 THEN GPMDATA_ROOT = gpmroot
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
       dBZ_min = 18.0   ; low-end GR cutoff, for now
       PRINT, "Assigning default value of 18 dBZ to DBZ_MIN for ground radar."
    ENDIF
   ; tally number of rain rate bins (mm/h) below this value in DPR rr averages
    IF N_ELEMENTS(dpr_rain_min) NE 1 THEN BEGIN
       DPR_RAIN_MIN = 0.01
       PRINT, "Assigning default value of 0.01 mm/h to DPR_RAIN_MIN."
    ENDIF

   ; set up to override computed radius of influence if USE_DPR_ROI is set
    IF KEYWORD_SET(use_dpr_roi) THEN DPR_ROI2USE = DPR_ROI

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
  ; 2BCMB file name.  All 8 fields must be included in the control file in the
  ; order shown, and a valid 2BCMB (i.e., 2ADPRGMI) file name must be included
  ; and match the value of 'Instrument_ID'.

  ; -- Instrument_ID is the part of the algorithm name with the data level
  ;    stripped off.  For example, for algorithm '2ADPR', Instrument_ID = 'DPR'.
  ;    In the PPS file name convention, this would match to a filename beginning
  ;    with the literal field "2A.GPM.DPR" (DataLevel.Satellite.Intrument_ID)

   parsed=STRSPLIT( dataPR, '|', /extract )
   parseoffset = 0
   IF N_ELEMENTS(parsed) LT 7 THEN message, $
      "Incomplete DPR line in control file: "+dataPR

   orbit = parsed[0]
   nsites = FIX( parsed[1] )
   IF (nsites LE 0 OR nsites GT 99) THEN BEGIN
      PRINT, "IDL Error Exit: Illegal number of GR sites in control file: ", parsed[1]
      PRINT, "Line: ", dataPR
      PRINT, "Quitting processing."
      GOTO, bailOut
   ENDIF

   DATESTAMP = parsed[2]           ; in YYMMDD format
   subset = parsed[3]
   DPR_version = parsed[4]
   Instrument_ID = parsed[5]        ; 2A algorithm/product: Ka, Ku, or DPR
;   DPR_scantype = parsed[6]        ; HS, MS, or NS


  ; generate the netcdf matchup file path

   matchup_file_version=0.0  ; give it a null value, for now
  ; Call gen_geo_match_netcdf with the option to only get current file version
  ; so that it can become part of the matchup file name
   throwaway = gen_dprgmi_geo_match_netcdf_v7( GEO_MATCH_VERS=matchup_file_version )

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
      NC_OUTDIR = NCGRIDSOUTDIR+'/GPM/2BDPRGMI/'+DPR_version+'/'+verstr+ $
                  '/20'+STRMID(DATESTAMP, 0, 2)  ; 4-digit Year
   ENDELSE


  ; get filenames as listed in/on the database/disk
   idxCMB = WHERE(STRMATCH(parsed,'*2B*.GPM.DPRGMI*', /FOLD_CASE) EQ 1, countCMB)
   IF countCMB EQ 1 THEN origFileCMBName = STRTRIM(parsed[idxCMB],2) $
                    ELSE origFileCMBName = 'no_2BCMB_file'
   IF ( origFileCMBName EQ 'no_2BCMB_file' ) THEN BEGIN
      PRINT, ""
      PRINT, "ERROR finding a 2A-DPRGMI product file name in control file: ", $
             control_file
      PRINT, "Line: ", dataPR
      PRINT, "Skipping events for orbit = ", orbit
      skip_gr_events, lun0, nsites
      PRINT, ""
      GOTO, nextOrbit
   ENDIF

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
        10 : BEGIN   ; new control file format with additional freezing level height
              origUFName = parsed[8]  ; filename as listed in/on the database/disk
              IF file_basename(origUFName) NE 'no_1CUF_file' THEN numUFgood++
            END
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

   file_2bcmb = GPMDATA_ROOT+DIR_COMB+"/"+origFileCMBName

   DO_RAIN_CORR = 1   ; set flag to do 3-D rain_corr processing by default

; read 2BCMB rainrate field

   havefile2bcmb = 1
   IF ( FILE_BASENAME(origFileCMBName) EQ 'no_2BCMB_file' ) THEN BEGIN
      msgpref = "No 2BDPRGMI file"
      PRINT, ""
      PRINT, msgpref,", skipping 2BCMB processing for orbit = ", orbit
      PRINT, ""
      havefile2bcmb = 0
   ENDIF ELSE BEGIN
      print, '' & print, "Reading file: ", file_2bcmb & print, ''
     ; read both swaths, but only default variables
      data_COMB = read_2bcmb_hdf5_v7( file_2bcmb )
      IF SIZE(data_COMB, /TYPE) NE 8 THEN BEGIN
         PRINT, ""
         PRINT, "ERROR reading fields from ", file_2bcmb
         PRINT, "Skipping 2BCMB processing for orbit = ", orbit
         PRINT, ""
         havefile2bcmb = 0
      ENDIF
   ENDELSE

  ; read the control file GR site ID, lat, lon, elev, filename, etc.
  ;  - outer loop through each site

   lastsite = ""
   FOR igv=0,nsites-1  DO BEGIN
;   READF, lun0, dataGR
  ; PRINT, igv+1, ": ", dataGR
  ;  - grab each overpassed site's information from the string array
   dataGR = dataGRarr[igv]

  ; parse dataGR into its component fields: event_num, orbit number, siteID,
  ; overpass datetime, time in ticks, site lat, site lon, site elev,
  ; 1CUF file unique pathname
   parsed=STRSPLIT( dataGR, '|', count=nGRfields, /extract )
   freezing_level = -9999.
   CASE nGRfields OF
     10 : BEGIN   ; legacy control file format
           event_num = LONG( parsed[0] )
           orbit = parsed[1]
           siteID = parsed[2]    ; GPMGV siteID
           dpr_dtime = parsed[3]
           dpr_dtime_ticks = parsed[4]
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
              NW_ID:    'Unspecified', $
              MW_ID:    'Unspecified', $
              MI_ID:    'Unspecified', $
              DM_ID:    'Unspecified'}

  ; check existence of blockage files for this siteID if dir_block is specified
   have_gv_blockage = 0
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

  ; TAB 8/27/18 Added have_gv_swe flag
  if (have_gv_kdp eq 1) and (have_gv_hid eq 1) then begin
  	  have_gv_swe = 1
  endif else begin
      PRINT, ""
      PRINT, "No KDP or HID fields for SWE in file ", file_1CUF
      PRINT, ""
  	  have_gv_swe = 0  
  endelse

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
      have_gv_sigmadm = 0
   ENDIF ELSE BEGIN
      have_gv_dm = 1
      have_gv_sigmadm = 1
      ufstruct.DM_ID = gv_dm_field
   ENDELSE

 ; Retrieve the desired radar volumes from the radar structure
   zvolume = rsl_get_volume( radar, z_vol_num )
   IF have_gv_zdr THEN zdrvolume = rsl_get_volume( radar, zdr_vol_num )
   IF have_gv_kdp THEN kdpvolume = rsl_get_volume( radar, kdp_vol_num )
   IF have_gv_rhohv THEN rhohvvolume = rsl_get_volume( radar, rhohv_vol_num )
   IF have_gv_rc THEN rcvolume = rsl_get_volume( radar, rc_vol_num )
   IF have_gv_rp THEN rpvolume = rsl_get_volume( radar, rp_vol_num )
   IF have_gv_rr THEN rrvolume = rsl_get_volume( radar, rr_vol_num )
   IF have_gv_hid THEN hidvolume = rsl_get_volume( radar, hid_vol_num )
   IF have_gv_nw THEN nwvolume = rsl_get_volume( radar, nw_vol_num )
   IF have_gv_mw THEN mwvolume = rsl_get_volume( radar, mw_vol_num )
   IF have_gv_mi THEN mivolume = rsl_get_volume( radar, mi_vol_num )
   IF have_gv_dm THEN dmvolume = rsl_get_volume( radar, dm_vol_num )

  ; get the number of elevation sweeps in the vol, and the array of elev angles
   num_elevations = get_sweep_elevs( z_vol_num, radar, elev_angle )
  ; make a copy of the array of elevations, from which we eliminate any
  ;   duplicate tilt angles for subsequent data processing/output
;   idx_uniq_elevs = UNIQ(elev_angle)
   uniq_elev_angle = elev_angle
   idx_uniq_elevs = UNIQ_SWEEPS(elev_angle, uniq_elev_angle)

   tocdf_elev_angle = elev_angle[idx_uniq_elevs]
   num_elevations_out = N_ELEMENTS(tocdf_elev_angle)
   ; TAB 2/3/21, fix for some bad files in May/June 2015
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
     ; these elevations are used to create filename patterns, most higher elevation angles will 
     ; never actually have corresponding blockage files
     ; TAB 5/9/23 added some larger elevations for CPOL/DARW to avoid 'difference too large' errors
     ; added additional elevations for various sites
     ; 9.2�, 11�, 18.7�, 20.5�, 24.6�, 29�, 35�, and 90�
     ; 7�, 21.5�, 25.5�
     
      blkgElev_str = [ '00.50', '00.90', '01.30', '01.45', '01.50', '01.80', $
                       '02.40', '02.50', '03.10', '03.35', '03.50', '04.00', $
                       '04.30', '04.50', '05.10', '05.25', '06.00', '06.20', $
                       '06.40', '07.00', '07.50', '08.00', '08.70', '09.20', '09.90', '10.00', $
                       '11.00', '12.00', '12.50', '13.30', '14.00', '14.60', '15.60', $
                       '16.70', '17.90', '18.70', '19.50', '20.50', '21.50', '23.90', '24.60', $
                       '25.50', '29.00', '32.00', '35.00', '43.10', '90.00' ]

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

  ; Determine an upper limit to how many DPR footprints fall inside the analysis
  ;   area, so that we can hold x, y, and various z values for each element to
  ;   analyze.  We gave the DPR a 4km resolution in the 'include' file
  ;   pr_params.inc, and use this nominal resolution to figure out how many
  ;   of these are required to cover the in-range area.

   grid_area_km = rough_threshold * rough_threshold  ; could use area of circle
   max_dpr_fp = grid_area_km / NOM_DPR_RES_KM

  ; Create temp arrays of DPR (ray, scan) 1-D index locators, DPR scan number,
  ; and DPR ray number for in-range points.
   dpr_master_idx = LONARR(max_dpr_fp)
   dpr_master_idx[*] = -99L
   dpr_scan_num = INTARR(max_dpr_fp)
   dpr_scan_num[*] = -99
   dpr_ray_num = dpr_scan_num

  ; Create temp array used to flag whether there are ANY above-threshold DPR bins
  ; in the ray.  If none, we'll skip the time-consuming GR LUT computations.
   dpr_echoes = BYTARR(max_dpr_fp)
   dpr_echoes[*] = 0B             ; initialize to zero (skip the DPR ray)

  ; Create temp arrays to hold lat/lon of all DPR footprints to be analyzed
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

  ;-----------------------------------------------------------------------------

  ; Begin first-time inner loop over swath/source types: FS/Ku, FS/Ka, NS/Ku
  ; just to get information needed to dimension the netCDF variables

   swathIDs = ['FS','FS','NS']
   instruments = ['Ku','Ka','Ku']
  ; indices for finding correct subarray in FS swath for variables
  ; with the nKuKa dimension:
   idxKuKa = [0,1,0]

  ; holds number of in-range footprints for each swath/source combo, for setting
  ; dimensions in the matchup netCDF file
   num_fp_by_source = INTARR(3)

  ; ditto, but holds number of in-range scans for each swath/source for
  ; dimensioning date/time variables:
   nscansBySwath = INTARR(3)

  ; get the numbers of in-range footprints for each combo

   for swathID = 0, N_ELEMENTS(swathIDs)-1 do begin
     ; get the group structure for the specified scantype, tags vary by swath
      DPR_scantype = swathIDs[swathID]
      CASE STRUPCASE(DPR_scantype) OF
         'FS' : BEGIN
                   RAYSPERSCAN = RAYSPERSCAN_FS
                   GATE_SPACE = BIN_SPACE_DPRGMI
                   ptr_swath = data_COMB.FS
                END
         'NS' : BEGIN
                   RAYSPERSCAN = RAYSPERSCAN_NS
                   GATE_SPACE = BIN_SPACE_DPRGMI
                   ptr_swath = data_COMB.NS
                END
         ELSE : message, "Illegal scan type '"+DPR_scantype+"'"
      ENDCASE
      ; get the number of scans in the dataset
      SAMPLE_RANGE = ptr_swath.SWATHHEADER.NUMBERSCANSBEFOREGRANULE $
                   + ptr_swath.SWATHHEADER.NUMBERSCANSGRANULE $
                   + ptr_swath.SWATHHEADER.NUMBERSCANSAFTERGRANULE

      ; extract DPR variables/arrays from struct pointers
      IF PTR_VALID(ptr_swath.PTR_DATASETS) THEN BEGIN
         prlons = (*ptr_swath.PTR_DATASETS).LONGITUDE
         prlats = (*ptr_swath.PTR_DATASETS).LATITUDE
      ENDIF ELSE message, "Invalid pointer to PTR_DATASETS."

     ; Find scans with any point within range of the radar volume, roughly
      start_scan = 0
      end_scan = 0
      nscans2do = 0
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

     ; arrays holding 'exact' DPR at-surface X and Y and range values for
     ; the in-range subset of scans
      XY_km = map_proj_forward( prlons[*,start_scan:end_scan], $
                                prlats[*,start_scan:end_scan], $
                                map_structure=smap ) / 1000.
      dpr_x0 = XY_km[0,*]
      dpr_y0 = XY_km[1,*]
      
      ; some bad radar files are causing this to crash.  
      ; check combined size of remaining dimensions of dpy_y0 and make
      ; sure they match what we want in the reform dimensions
      size_x0 = size(dpr_x0)
      size_y0 = size(dpr_y0)
      if size_x0[0] ne 2 then begin
          print, "size_x0 ", size_x0
          print, "Dimension size error dpr_x0 in radar file, skipping file..."
          GOTO, nextGRfile     
      endif else begin
          total_x0 = size_x0[1]*size_x0[2]
          if total_x0 ne RAYSPERSCAN*nscans2do then begin
          	 print, "Reform dimensions don't match for dpr_x0 in radar file, skipping file..."
          	 GOTO, nextGRfile     
          endif
      endelse
      if size_y0[0] ne 2 then begin
          print, "size_y0 ", size_y0
          print, "Dimension size error dpr_y0 in radar file, skipping file..."
          GOTO, nextGRfile     
      endif else begin
          total_y0 = size_y0[1]*size_y0[2]
          if total_y0 ne RAYSPERSCAN*nscans2do then begin
          	 print, "Reform dimensions don't match for dpr_y0 in radar file, skipping file..."
          	 GOTO, nextGRfile     
          endif
      endelse
      
      dpr_x0 = REFORM( dpr_x0, RAYSPERSCAN, nscans2do, /OVERWRITE )
      dpr_y0 = REFORM( dpr_y0, RAYSPERSCAN, nscans2do, /OVERWRITE )
      precise_range = SQRT( dpr_x0^2 + dpr_y0^2 )

      numPRinrange = 0     ; number of in-range-only points found
      numScansinrange = 0  ; number of in-range-only scans found
     ; Identify actual DPR points within range of the radar
      FOR scan_num = start_scan,end_scan  DO BEGIN
         subset_scan_num = scan_num - start_scan
         foundAnotherScan = 0
         FOR ray_num = 0,RAYSPERSCAN-1  DO BEGIN
           ; is to-sfc projection of any point along DPR ray is within range of GR volume?
            IF ( precise_range[ray_num,subset_scan_num] LE max_ranges[0] ) THEN BEGIN
               numPRinrange = numPRinrange + 1   ; increment # of in-range footprints
               foundAnotherScan = 1
            ENDIF
         ENDFOR              ; ray_num
         IF ( foundAnotherScan EQ 1 ) THEN numScansinrange = numScansinrange + 1
      ENDFOR                 ; scan_num = start_scan,end_scan 

      num_fp_by_source[swathID] = numPRinrange
      nscansBySwath[swathID] = numScansinrange
   endfor   ; swathID, first time through swath/source combos

  ; check for inconsistencies in footprint counts between FS/Ku and FS/Ka
   IF (nscansBySwath[0] NE nscansBySwath[1]) THEN BEGIN
      print, "nscansBySwath: ", nscansBySwath
      message, "No. of in-range footprints differs between FS/Ku and FS/Ka data."
   ENDIF

  ;-----------------------------------------------------------------------------

  ; generate the netcdf matchup file path/name
   IF N_ELEMENTS(ncnameadd) EQ 1 THEN BEGIN
      fname_netCDF = NC_OUTDIR+'/'+COMB_GEO_MATCH_PRE+siteID+'.'+DATESTAMP+'.' $
                      +orbit+'.'+DPR_version+'.'+verstr+'.'+ncnameadd+NC_FILE_EXT
   ENDIF ELSE BEGIN
      fname_netCDF = NC_OUTDIR+'/'+COMB_GEO_MATCH_PRE+siteID+'.'+DATESTAMP+'.' $
                      +orbit+'.'+DPR_version+'.'+verstr+NC_FILE_EXT
   ENDELSE

   ; store the file basenames in a string array to be passed to
   ; gen_dprgmi_geo_match_netcdf_v7()
   infileNameArr = STRARR(2)
   infileNameArr[0] = FILE_BASENAME(origFileCMBName)
   infileNameArr[1] = base_1CUF

  ; Create a netCDF file with the proper dimensions, passing the global
  ; attribute values along

   ncfile = gen_dprgmi_geo_match_netcdf_v7( fname_netCDF, num_fp_by_source[0],     $
                                         num_fp_by_source[2], tocdf_elev_angle, $
                                         nscansBySwath[0], nscansBySwath[2],    $
                                         ufstruct, DPR_version, siteID,         $
                                         infileNameArr, FREEZING_LEVEL=freezing_level )

   IF ( fname_netCDF EQ "NoGeoMatchFile" ) THEN $
      message, "Error in creating output netCDF file "+fname_netCDF

  ; Open the netCDF file for writing
   ncid = NCDF_OPEN( ncfile, /WRITE )

  ; Write the available scalar values to the netCDF file

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
;   NCDF_VARPUT, ncid, 'numScans', SAMPLE_RANGE
;   NCDF_VARPUT, ncid, 'numRays', RAYSPERSCAN


;-------------------------------------------------------------------------------

; HERE BEGINS THE BIG LOOP OVER SWATH/SOURCE COMBINATIONS.  READ THE SWATH OF
; INTEREST IN EACH ITERATION, EXTRACT DPRGMI VARIABLES, RUN GEOMETRY MATCHING
; TO THE GROUND RADAR, AND WRITE MATCHUP VARIABLES TO SWATH/COMBO-SPECIFIC
; VARIABLES IN THE NETCDF FILE.

   for swathID = 0, N_ELEMENTS(swathIDs)-1 do begin
     ; get the group structure for the specified scantype, tags vary by swath
      DPR_scantype = swathIDs[swathID]
      instrumentID = instruments[swathID]
     ; reinitialize flags to skip a DPR ray to zero unless in Ka/FS iteration,
     ; where we'll just re-use the flag values already assigned for Ku/FS
      IF idxKuKa[swathID] EQ 0 THEN dpr_echoes[*] = 0B

      print, ''
      PRINT, "Extracting ", instrumentID+' '+DPR_scantype+" data fields from structure."
      print, ''
         
      CASE STRUPCASE(DPR_scantype) OF
         'FS' : BEGIN
                   RAYSPERSCAN = RAYSPERSCAN_FS
                   GATE_SPACE = BIN_SPACE_DPRGMI
                   ptr_swath = data_COMB.FS
                END
         'NS' : BEGIN
                   RAYSPERSCAN = RAYSPERSCAN_NS
                   GATE_SPACE = BIN_SPACE_DPRGMI
                   ptr_swath = data_COMB.NS
                END
         ELSE : message, "Illegal scan type '"+DPR_scantype+"'"
      ENDCASE

      ; get the number of scans in the dataset
      SAMPLE_RANGE = ptr_swath.SWATHHEADER.NUMBERSCANSBEFOREGRANULE $
                   + ptr_swath.SWATHHEADER.NUMBERSCANSGRANULE $
                   + ptr_swath.SWATHHEADER.NUMBERSCANSAFTERGRANULE

      ; extract DPR variables/arrays from struct pointers
      IF PTR_VALID(ptr_swath.PTR_SCANTIME) THEN BEGIN
         Year = (*ptr_swath.PTR_SCANTIME).Year
         Month = (*ptr_swath.PTR_SCANTIME).Month
         DayOfMonth = (*ptr_swath.PTR_SCANTIME).DayOfMonth
         Hour = (*ptr_swath.PTR_SCANTIME).Hour
         Minute = (*ptr_swath.PTR_SCANTIME).Minute
         Second = (*ptr_swath.PTR_SCANTIME).Second
         Millisecond = (*ptr_swath.PTR_SCANTIME).MilliSecond
      ENDIF ELSE message, "Invalid pointer to PTR_SCANTIME."

      IF PTR_VALID(ptr_swath.PTR_DATASETS) THEN BEGIN
         prlons = (*ptr_swath.PTR_DATASETS).LONGITUDE
         prlats = (*ptr_swath.PTR_DATASETS).LATITUDE
         ;PSDparamLowNode = (*ptr_swath.PTR_DATASETS).PSDparamLowNode
         correctedReflectFactor = $
                (*ptr_swath.PTR_DATASETS).correctedReflectFactor  ;nKuKa
         ; TAB: put new stuff for additional fields here:       
                
         phaseBinNodes = (*ptr_swath.PTR_DATASETS).phaseBinNodes
         pia = (*ptr_swath.PTR_DATASETS).pia                      ;nKuKa
         precipTotWaterCont = (*ptr_swath.PTR_DATASETS).precipTotWaterCont
         precipTotWaterContSigma = (*ptr_swath.PTR_DATASETS).precipTotWaterContSigma
         cloudLiqWaterCont = (*ptr_swath.PTR_DATASETS).cloudLiqWaterCont
         cloudIceWaterCont = (*ptr_swath.PTR_DATASETS).cloudIceWaterCont
         tbSim = (*ptr_swath.PTR_DATASETS).simulatedBrightTemp
;tbSim_19v = 3rd nemiss index
;tbSim_37v = 6th nemiss index
;tbSim_89v = 8th nemiss index
;tbSim_183_3v = 12th nemiss index 
         tbSim_19v = reform(tbSim[2,*,*])
         tbSim_37v = reform(tbSim[5,*,*])
         tbSim_89v = reform(tbSim[7,*,*])
         tbSim_183_3v = reform(tbSim[11,*,*])
         precipTotDm = (*ptr_swath.PTR_DATASETS).precipTotDm
         precipTotLogNw = (*ptr_swath.PTR_DATASETS).precipTotLogNw
         precipTotMu = (*ptr_swath.PTR_DATASETS).precipTotMu
;         precipTotPSDparamHigh = (*ptr_swath.PTR_DATASETS).precipTotPSDparamHigh
;         precipTotPSDparamLow = (*ptr_swath.PTR_DATASETS).precipTotPSDparamLow
         precipTotRate = (*ptr_swath.PTR_DATASETS).precipTotRate
         surfPrecipTotRate = (*ptr_swath.PTR_DATASETS).surfPrecipTotRate
;         ptr_free, ptr_swath.PTR_DATASETS
      ENDIF ELSE message, "Invalid pointer to PTR_DATASETS."

      IF PTR_VALID(ptr_swath.PTR_Input) THEN BEGIN
         ellipsoidBinOffset = (*ptr_swath.PTR_Input).ellipsoidBinOffset      ;nKuKa
         localZenithAngle = (*ptr_swath.PTR_Input).localZenithAngle
         lowestClutterFreeBin = (*ptr_swath.PTR_Input).lowestClutterFreeBin  ;nKuKa
         precipitationFlag = (*ptr_swath.PTR_Input).precipitationFlag        ;nKuKa
         precipitationType = (*ptr_swath.PTR_Input).precipitationType
         surfaceElevation = (*ptr_swath.PTR_Input).surfaceElevation
         surfaceRangeBin = (*ptr_swath.PTR_Input).surfaceRangeBin            ;nKuKa
         surfaceType = (*ptr_swath.PTR_Input).surfaceType
         zeroDegAltitude = (*ptr_swath.PTR_Input).zeroDegAltitude
         zeroDegBin = (*ptr_swath.PTR_Input).zeroDegBin
         stormTopAltitude = (*ptr_swath.PTR_Input).stormTopAltitude
;         ptr_free, ptr_swath.PTR_Input
      ENDIF ELSE message, "Invalid pointer to PTR_Input."

      ; deal with the nKuKa dimension in FS swath.  Get either the Ku or Ka
      ; subarray depending on where we are in the inner (swathID) loop
       IF ( DPR_scantype EQ 'FS' ) THEN BEGIN
          KKidx = idxKuKa[swathID]
          correctedReflectFactor = REFORM(correctedReflectFactor[KKidx,*,*,*])
          pia = REFORM(pia[KKidx,*,*])
          ellipsoidBinOffset = REFORM(ellipsoidBinOffset[KKidx,*,*])
          lowestClutterFreeBin = REFORM(lowestClutterFreeBin[KKidx,*,*])
          precipitationFlag = REFORM(precipitationFlag[KKidx,*,*])
          surfaceRangeBin = REFORM(surfaceRangeBin[KKidx,*,*])
          stormTopAltitude = REFORM(stormTopAltitude[KKidx,*,*])
       ENDIF

       dpr_index_all = LINDGEN(SIZE(surfPrecipTotRate, /DIMENSIONS))

      ; precompute the reuseable ray angle trig variables for parallax -- in GPM,
      ; we have the local zenith angle for every ray/scan (i.e., footprint)
       cos_inc_angle = COS( 3.1415926D * localZenithAngle / 180. )
       tan_inc_angle = TAN( 3.1415926D * localZenithAngle / 180. )

  ; ======================================================================================================

  ; GEO-Preprocess the DPR data, extracting rays that intersect this radar volume
  ; within the specified range threshold, and computing footprint x,y corner
  ; coordinates and adjusted center lat/lon at each of the intersection sweep
  ; intersection heights, taking into account the parallax of the DPR rays.
  ; Algorithm assumes that DPR footprints are contiguous, non-overlapping,
  ; and quasi-rectangular in their native ray,scan coordinates, and that the DPR
  ; scans through nadir (zero roll/pitch of satellite).

  ; First, find scans with any point within range of the radar volume, roughly
   start_scan = 0
   end_scan = 0
   nscans2do = 0
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
      print, "No ", DPR_scantype, " swath footprints in range of GR", $
             " by lat/lon difference check, bailing."
      IF DPR_scantype EQ 'FS' THEN GOTO, skippedSwath ELSE GOTO, emptyFile
   ENDIF

;-------------------------------------------------------------------------------
  ; Populate arrays holding 'exact' DPR at-surface X and Y and range values for
  ; the in-range subset of scans.  THESE ARE NOT WRITTEN TO NETCDF FILE.

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
  ; Identify actual DPR points within range of the radar, and compute
  ; parallax-corrected x,y and lat/lon coordinates for these points at DPR
  ; ray's intersection of each sweep elevation.  Compute DPR footprint corner
  ; x,y's for the DPR points within the cutoff range.

   FOR scan_num = start_scan,end_scan  DO BEGIN
      subset_scan_num = scan_num - start_scan
     ; prep variables for parallax computations
      m = 0.0        ; SLOPE AS DX/DY
      dy_sign = 0.0  ; SENSE IN WHICH Y CHANGES WITH INCR. SCAN ANGLE, = -1 OR +1
      get_scan_slope_and_sense, smap, prlats, prlons, scan_num, RAYSPERSCAN, $
                                m, dy_sign
;                                m, dy_sign, do_print=1
; remove do_print !!!!!!!!!!!!!!

      FOR ray_num = 0,RAYSPERSCAN-1  DO BEGIN
        ; is to-sfc projection of any point along DPR ray is within range of GR volume?
         IF ( precise_range[ray_num,subset_scan_num] LE max_ranges[0] ) THEN BEGIN
           ; add point to subarrays for DPR 1-D index and for DPR scanand ray num and
           ; footprint lat/lon
            dpr_master_idx[numDPRrays] = dpr_index_all[ray_num,scan_num] ; for GPM
            dpr_scan_num[numDPRrays] = scan_num
            dpr_ray_num[numDPRrays] = ray_num
            dpr_lat_sfc[numDPRrays] = prlats[ray_num,scan_num]
            dpr_lon_sfc[numDPRrays] = prlons[ray_num,scan_num]
            maxrayidx = ray_num > maxrayidx    ; track highest ray num occurring in GR area
            minrayidx = ray_num < minrayidx    ; track lowest ray num in GR area
            numPRinrange = numPRinrange + 1    ; increment # of actual in-range footprints

            IF idxKuKa[swathID] EQ 0 THEN BEGIN
              ; determine whether the DPR ray has any bins above the dBZ threshold
              ; - look at corrected Z between 0.75 and 19.25 km, and
              ;   use the above-threshold bin counting in get_dpr_layer_average()
              ; - just use what the Ku found for the Ka/FS case (idxKuKa[swathID]=1)
               topMeasGate = 0 & botmMeasGate = 0
               topCorrGate = 0 & botmCorrGate = 0
               topCorrGate = dpr_gate_num_for_height( 19.25, GATE_SPACE,  $
                                cos_inc_angle, ray_num, scan_num, surfaceRangeBin )
               botmCorrGate = dpr_gate_num_for_height( 0.75, GATE_SPACE,  $
                                 cos_inc_angle, ray_num, scan_num, surfaceRangeBin )
               ;PRINT, "GATES AT 0.75 and 19.25 KM, and GATE_SPACE: ", $
               ;        botmCorrGate, topCorrGate, GATE_SPACE
               dbz_ray_avg = get_dpr_layer_average(topCorrGate, botmCorrGate,   $
                                scan_num, ray_num, correctedReflectFactor, 1.0, $
                                DPR_DBZ_MIN, numDPRgates )
               IF ( numDPRgates GT 0 ) THEN dpr_echoes[numDPRrays] = 1B
            ENDIF

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
      ENDFOR              ; ray_num
   ENDFOR                 ; scan_num = start_scan,end_scan 

  ; check for match between number of in-range footprints found here and in the
  ; initial loop over scans and rays
   IF ( numDPRrays NE num_fp_by_source[swathID] ) THEN BEGIN
      message, "Inconsistent count of in-range footprints for " $
               +DPR_scantype+InstrumentID+" for netCDF sizing", /INFO
      NCDF_CLOSE, ncid
     ; rename the unfinished netCDF file
      PRINT
      PRINT, "Output netCDF file:"
      PRINT, ncfile
      PRINT, "is being renamed, and processing is quitting for this event."
      PRINT
      command = "mv -v " + ncfile +' '+ ncfile+'.bad'
      spawn, command
      GOTO, nextGRfile
   ENDIF

  ; check the two legacy footprint counts against each other. TO DO: eliminate one later
   IF ( numDPRrays NE numPRinrange ) THEN BEGIN
      message, "Inconsistent internal count of in-range footprints for " $
               +DPR_scantype+InstrumentID, /INFO
      NCDF_CLOSE, ncid
     ; rename the unfinished netCDF file
      PRINT
      PRINT, "Output netCDF file:"
      PRINT, ncfile
      PRINT, "is being renamed, and processing is quitting for this event."
      PRINT
      command = "mv -v " + ncfile +' '+ ncfile+'.bad'
      spawn, command
      GOTO, nextGRfile
   ENDIF

   IF N_ELEMENTS( DPR_ROI2USE ) EQ 1 THEN BEGIN
     ; override the default computed DPR beam width to use as GR radius of
     ; influence in GR volume average
      max_DPR_footprint_diag_halfwidth = DPR_ROI2USE
   ENDIF ELSE BEGIN
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
   ENDELSE

  ; end of DPR GEO-preprocessing

  ; ============================================================================

  ; Initialize and/or populate data fields to be written to the netCDF file.
  ; NOTE WE DON'T SAVE THE SURFACE X,Y FOOTPRINT CENTERS AND CORNERS TO NETCDF

   IF ( numPRinrange GT 0 ) THEN BEGIN
     ; Trim the dpr_master_idx, lat/lon temp arrays and x,y corner arrays down
     ;   to numDPRrays elements in that dimension, in prep. for writing to netCDF
     ;    -- these elements are complete, data-wise
      tocdf_pr_idx = dpr_master_idx[0:numDPRrays-1]
      tocdf_scanNum = dpr_scan_num[0:numDPRrays-1]
      tocdf_rayNum = dpr_ray_num[0:numDPRrays-1]
      tocdf_x_poly = dpr_x_corners[*,0:numDPRrays-1,*]
      tocdf_y_poly = dpr_y_corners[*,0:numDPRrays-1,*]
      tocdf_lat = REFORM(dpr_lon_lat[1,0:numDPRrays-1,*])   ; 3D to 2D
      tocdf_lon = REFORM(dpr_lon_lat[0,0:numDPRrays-1,*])
      tocdf_lat_sfc = dpr_lat_sfc[0:numDPRrays-1]
      tocdf_lon_sfc = dpr_lon_sfc[0:numDPRrays-1]
      tocdf_startScan = MIN(tocdf_scanNum, MAX=tocdf_endScan)
      tocdf_Year = Year[tocdf_startScan:tocdf_endScan]
      tocdf_Month = Month[tocdf_startScan:tocdf_endScan]
      tocdf_DayOfMonth = DayOfMonth[tocdf_startScan:tocdf_endScan]
      tocdf_Hour = Hour[tocdf_startScan:tocdf_endScan]
      tocdf_Minute = Minute[tocdf_startScan:tocdf_endScan]
      tocdf_Second = Second[tocdf_startScan:tocdf_endScan]
      tocdf_Millisecond = Millisecond[tocdf_startScan:tocdf_endScan]

     ; Create new subarrays of dimension equal to the numDPRrays for each 2-D
     ;   DPR science variable: surfaceType, phaseBinNodes,
     ;   precipitationType, surfaceElevation, surfPrecipTotRate
      tocdf_phaseBinNodes = MAKE_ARRAY(nPhsBnN, numDPRrays, /int, VALUE=INT_RANGE_EDGE)
      tocdf_surfPrecipTotRate = MAKE_ARRAY(numDPRrays, /float, VALUE=FLOAT_RANGE_EDGE)
      tocdf_precipitationType = MAKE_ARRAY(numDPRrays, /long, VALUE=INT_RANGE_EDGE)
      tocdf_surfaceType = MAKE_ARRAY(numDPRrays, /long, VALUE=INT_RANGE_EDGE)
      tocdf_surfaceElevation = MAKE_ARRAY(numDPRrays, /float, VALUE=FLOAT_RANGE_EDGE)
      tocdf_zeroDegAltitude = MAKE_ARRAY(numDPRrays, /float, VALUE=FLOAT_RANGE_EDGE)
      tocdf_zeroDegBin = MAKE_ARRAY(numDPRrays, /int, VALUE=INT_RANGE_EDGE)
      tocdf_tbSim_19v = MAKE_ARRAY(numDPRrays, /float, VALUE=FLOAT_RANGE_EDGE)
      tocdf_tbSim_37v = MAKE_ARRAY(numDPRrays, /float, VALUE=FLOAT_RANGE_EDGE)
      tocdf_tbSim_89v = MAKE_ARRAY(numDPRrays, /float, VALUE=FLOAT_RANGE_EDGE)
      tocdf_tbSim_183_3v = MAKE_ARRAY(numDPRrays, /float, VALUE=FLOAT_RANGE_EDGE)

     ; deal with the variables with the extra dimension for the FS swath
     ; -- create once, write twice (Ku and Ka FS values)
      IF idxKuKa[swathID] EQ 0 THEN BEGIN
         CASE (DPR_scantype) OF
            'FS' : BEGIN
                   tocdf_ellipsoidBinOffset = MAKE_ARRAY(nKuKa,numDPRrays, /float, $
                                                VALUE=FLOAT_RANGE_EDGE)
                   tocdf_lowestClutterFreeBin = MAKE_ARRAY(nKuKa,numDPRrays, /int, $
                                                VALUE=INT_RANGE_EDGE)
                   tocdf_precipitationFlag = MAKE_ARRAY(nKuKa,numDPRrays, /long, $
                                                VALUE=INT_RANGE_EDGE)
                   tocdf_surfaceRangeBin = MAKE_ARRAY(nKuKa,numDPRrays, /int, $
                                                VALUE=INT_RANGE_EDGE)
                   tocdf_pia = MAKE_ARRAY(nKuKa,numDPRrays, /float, $
                                                VALUE=FLOAT_RANGE_EDGE)
                   tocdf_clutterStatus = UINTARR(nKuKa, numDPRrays, num_elevations_out)  ; not in netcdf file yet
                   tocdf_stormTopAltitude = MAKE_ARRAY(nKuKa,numDPRrays, /float, $
                                                VALUE=FLOAT_RANGE_EDGE)
                   END
            'NS' : BEGIN
                   tocdf_ellipsoidBinOffset = MAKE_ARRAY(numDPRrays, /float, $
                                                VALUE=FLOAT_RANGE_EDGE)
                   tocdf_lowestClutterFreeBin = MAKE_ARRAY(numDPRrays, /int, $
                                                VALUE=INT_RANGE_EDGE)
                   tocdf_precipitationFlag = MAKE_ARRAY(numDPRrays, /long, $
                                                VALUE=INT_RANGE_EDGE)
                   tocdf_surfaceRangeBin = MAKE_ARRAY(numDPRrays, /int, $
                                                VALUE=INT_RANGE_EDGE)
                   tocdf_pia = MAKE_ARRAY(numDPRrays, /float, $
                                                VALUE=FLOAT_RANGE_EDGE)
                   tocdf_clutterStatus = UINTARR(numDPRrays, num_elevations_out)  ; not in netcdf file yet
                   tocdf_stormTopAltitude = MAKE_ARRAY(numDPRrays, /float, $
                                                VALUE=FLOAT_RANGE_EDGE)
                   END
         ENDCASE
      ENDIF
     ; Create new subarrays of dimensions (numDPRrays, num_elevations_out) for each
     ;   3-D science and status variable.  GR variables first:
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
; **********
      tocdf_gr_swedp = MAKE_ARRAY(numDPRrays, num_elevations_out, /float, $
                               VALUE=FLOAT_RANGE_EDGE)
      tocdf_gr_swedp_stddev = MAKE_ARRAY(numDPRrays, num_elevations_out, /float, $
                                      VALUE=FLOAT_RANGE_EDGE)
      tocdf_gr_swedp_max = MAKE_ARRAY(numDPRrays, num_elevations_out, /float, $
                                   VALUE=FLOAT_RANGE_EDGE)

      tocdf_gr_swe25 = MAKE_ARRAY(numDPRrays, num_elevations_out, /float, $
                               VALUE=FLOAT_RANGE_EDGE)
      tocdf_gr_swe25_stddev = MAKE_ARRAY(numDPRrays, num_elevations_out, /float, $
                                      VALUE=FLOAT_RANGE_EDGE)
      tocdf_gr_swe25_max = MAKE_ARRAY(numDPRrays, num_elevations_out, /float, $
                                   VALUE=FLOAT_RANGE_EDGE)
                                   
      tocdf_gr_swe50 = MAKE_ARRAY(numDPRrays, num_elevations_out, /float, $
                               VALUE=FLOAT_RANGE_EDGE)
      tocdf_gr_swe50_stddev = MAKE_ARRAY(numDPRrays, num_elevations_out, /float, $
                                      VALUE=FLOAT_RANGE_EDGE)
      tocdf_gr_swe50_max = MAKE_ARRAY(numDPRrays, num_elevations_out, /float, $
                                   VALUE=FLOAT_RANGE_EDGE)                             

      tocdf_gr_swe75 = MAKE_ARRAY(numDPRrays, num_elevations_out, /float, $
                               VALUE=FLOAT_RANGE_EDGE)
      tocdf_gr_swe75_stddev = MAKE_ARRAY(numDPRrays, num_elevations_out, /float, $
                                      VALUE=FLOAT_RANGE_EDGE)
      tocdf_gr_swe75_max = MAKE_ARRAY(numDPRrays, num_elevations_out, /float, $
                                   VALUE=FLOAT_RANGE_EDGE)
                                   
      tocdf_gr_swemqt = MAKE_ARRAY(numDPRrays, num_elevations_out, /float, $
                               VALUE=FLOAT_RANGE_EDGE)
      tocdf_gr_swemqt_stddev = MAKE_ARRAY(numDPRrays, num_elevations_out, /float, $
                                      VALUE=FLOAT_RANGE_EDGE)
      tocdf_gr_swemqt_max = MAKE_ARRAY(numDPRrays, num_elevations_out, /float, $
                                   VALUE=FLOAT_RANGE_EDGE)

      tocdf_gr_swemrms = MAKE_ARRAY(numDPRrays, num_elevations_out, /float, $
                               VALUE=FLOAT_RANGE_EDGE)
      tocdf_gr_swemrms_stddev = MAKE_ARRAY(numDPRrays, num_elevations_out, /float, $
                                      VALUE=FLOAT_RANGE_EDGE)
      tocdf_gr_swemrms_max = MAKE_ARRAY(numDPRrays, num_elevations_out, /float, $
                                   VALUE=FLOAT_RANGE_EDGE)
                                   
                                   
;***********                                   


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
      tocdf_gr_Nw = MAKE_ARRAY(numDPRrays, num_elevations_out, /float, $
                               VALUE=FLOAT_RANGE_EDGE)
      tocdf_gr_Nw_stddev = MAKE_ARRAY(numDPRrays, num_elevations_out, /float, $
                                      VALUE=FLOAT_RANGE_EDGE)
      tocdf_gr_Nw_max = MAKE_ARRAY(numDPRrays, num_elevations_out, /float, $
                                   VALUE=FLOAT_RANGE_EDGE)
      tocdf_gr_Mw = MAKE_ARRAY(numDPRrays, num_elevations_out, /float, $
                               VALUE=FLOAT_RANGE_EDGE)
      tocdf_gr_Mw_stddev = MAKE_ARRAY(numDPRrays, num_elevations_out, /float, $
                                      VALUE=FLOAT_RANGE_EDGE)
      tocdf_gr_Mw_max = MAKE_ARRAY(numDPRrays, num_elevations_out, /float, $
                                   VALUE=FLOAT_RANGE_EDGE)
      tocdf_gr_Mi = MAKE_ARRAY(numDPRrays, num_elevations_out, /float, $
                               VALUE=FLOAT_RANGE_EDGE)
      tocdf_gr_Mi_stddev = MAKE_ARRAY(numDPRrays, num_elevations_out, /float, $
                                      VALUE=FLOAT_RANGE_EDGE)
      tocdf_gr_Mi_max = MAKE_ARRAY(numDPRrays, num_elevations_out, /float, $
                                   VALUE=FLOAT_RANGE_EDGE)
      tocdf_gr_Dm = MAKE_ARRAY(numDPRrays, num_elevations_out, /float, $
                               VALUE=FLOAT_RANGE_EDGE)
      tocdf_gr_Dm_stddev = MAKE_ARRAY(numDPRrays, num_elevations_out, /float, $
                                      VALUE=FLOAT_RANGE_EDGE)
      tocdf_gr_Dm_max = MAKE_ARRAY(numDPRrays, num_elevations_out, /float, $
                                   VALUE=FLOAT_RANGE_EDGE)
      tocdf_gr_sigmaDm = MAKE_ARRAY(numDPRrays, num_elevations_out, /float, $
                               VALUE=FLOAT_RANGE_EDGE)
      tocdf_gr_sigmaDm_stddev = MAKE_ARRAY(numDPRrays, num_elevations_out, /float, $
                                      VALUE=FLOAT_RANGE_EDGE)
      tocdf_gr_sigmaDm_max = MAKE_ARRAY(numDPRrays, num_elevations_out, /float, $
                                   VALUE=FLOAT_RANGE_EDGE)
      tocdf_gr_blockage = MAKE_ARRAY(numDPRrays, num_elevations_out, /float, $
                                     VALUE=FLOAT_RANGE_EDGE)
      tocdf_meas_dbz = MAKE_ARRAY(numDPRrays, num_elevations_out, /float, $
                                   VALUE=FLOAT_RANGE_EDGE)
      tocdf_corr_dbz = MAKE_ARRAY(numDPRrays, num_elevations_out, /float, $
                                   VALUE=FLOAT_RANGE_EDGE)
      tocdf_corr_rain = MAKE_ARRAY(numDPRrays, num_elevations_out, /float, $
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
      tocdf_gr_nw_rejected = UINTARR(numDPRrays, num_elevations_out)
      tocdf_gr_mw_rejected = UINTARR(numDPRrays, num_elevations_out)
      tocdf_gr_mi_rejected = UINTARR(numDPRrays, num_elevations_out)
      tocdf_gr_dm_rejected = UINTARR(numDPRrays, num_elevations_out)
      tocdf_gr_sigmadm_rejected = UINTARR(numDPRrays, num_elevations_out)
      tocdf_gr_expected = UINTARR(numDPRrays, num_elevations_out)
      tocdf_gr_swedp_rejected = UINTARR(numDPRrays, num_elevations_out)
      tocdf_gr_swe25_rejected = UINTARR(numDPRrays, num_elevations_out)
      tocdf_gr_swe50_rejected = UINTARR(numDPRrays, num_elevations_out)
      tocdf_gr_swe75_rejected = UINTARR(numDPRrays, num_elevations_out)
      tocdf_gr_swemqt_rejected = UINTARR(numDPRrays, num_elevations_out)
      tocdf_gr_swemrms_rejected = UINTARR(numDPRrays, num_elevations_out)

      tocdf_gr_nw_n_precip = UINTARR(numDPRrays, num_elevations_out)
      tocdf_gr_mw_n_precip = UINTARR(numDPRrays, num_elevations_out)
      tocdf_gr_mi_n_precip = UINTARR(numDPRrays, num_elevations_out)
      tocdf_gr_dm_n_precip = UINTARR(numDPRrays, num_elevations_out)
      tocdf_gr_sigmadm_n_precip = UINTARR(numDPRrays, num_elevations_out)
      tocdf_gr_rr_n_precip = UINTARR(numDPRrays, num_elevations_out)
      tocdf_gr_rc_n_precip = UINTARR(numDPRrays, num_elevations_out)
      tocdf_gr_rp_n_precip = UINTARR(numDPRrays, num_elevations_out)

     ; DPRGMI 3-D variables:
      tocdf_precipTotDm = $
         MAKE_ARRAY(numDPRrays, num_elevations_out, /float, VALUE=FLOAT_RANGE_EDGE)
      tocdf_precipTotLogNw = $
         MAKE_ARRAY(numDPRrays, num_elevations_out, /float, VALUE=FLOAT_RANGE_EDGE)
      tocdf_precipTotMu = $
         MAKE_ARRAY(numDPRrays, num_elevations_out, /float, VALUE=FLOAT_RANGE_EDGE)
;      tocdf_precipTotPSDparamHigh = $
;         MAKE_ARRAY(numDPRrays, num_elevations_out, /float, VALUE=FLOAT_RANGE_EDGE)
;      tocdf_precipTotPSDparamLow = $
;         MAKE_ARRAY(nPSDlo, numDPRrays, num_elevations_out, /float, VALUE=FLOAT_RANGE_EDGE)
      tocdf_precipTotRate = $
         MAKE_ARRAY(numDPRrays, num_elevations_out, /float, VALUE=FLOAT_RANGE_EDGE)
      tocdf_precipTotWaterCont = $
         MAKE_ARRAY(numDPRrays, num_elevations_out, /float, VALUE=FLOAT_RANGE_EDGE)
      tocdf_precipTotWaterContSigma = $
         MAKE_ARRAY(numDPRrays, num_elevations_out, /float, VALUE=FLOAT_RANGE_EDGE)
      tocdf_cloudLiqWaterCont = $
         MAKE_ARRAY(numDPRrays, num_elevations_out, /float, VALUE=FLOAT_RANGE_EDGE)
      tocdf_cloudIceWaterCont = $
         MAKE_ARRAY(numDPRrays, num_elevations_out, /float, VALUE=FLOAT_RANGE_EDGE)
      tocdf_n_precipTotDm_rejected = $
         MAKE_ARRAY(numDPRrays, num_elevations_out, /int, VALUE=INT_RANGE_EDGE)
      tocdf_n_precipTotLogNw_rejected = $
         MAKE_ARRAY(numDPRrays, num_elevations_out, /int, VALUE=INT_RANGE_EDGE)
      tocdf_n_precipTotMu_rejected = $
         MAKE_ARRAY(numDPRrays, num_elevations_out, /int, VALUE=INT_RANGE_EDGE)
;      tocdf_n_precipTotPSDparamHigh_rejected = $
;         MAKE_ARRAY(numDPRrays, num_elevations_out, /int, VALUE=INT_RANGE_EDGE)
;      tocdf_n_precipTotPSDparamLow_rejected = $
;         MAKE_ARRAY(nPSDlo, numDPRrays, num_elevations_out, /int, VALUE=INT_RANGE_EDGE)
      tocdf_n_precipTotRate_rejected = $
         MAKE_ARRAY(numDPRrays, num_elevations_out, /int, VALUE=INT_RANGE_EDGE)
      tocdf_n_precipTotWaterCont_rejected = $
         MAKE_ARRAY(numDPRrays, num_elevations_out, /int, VALUE=INT_RANGE_EDGE)
      tocdf_n_precipTotWaterContSigma_rejected = $
         MAKE_ARRAY(numDPRrays, num_elevations_out, /int, VALUE=INT_RANGE_EDGE)
      tocdf_n_cloudLiqWaterCont_rejected = $
         MAKE_ARRAY(numDPRrays, num_elevations_out, /int, VALUE=INT_RANGE_EDGE)
      tocdf_n_cloudIceWaterCont_rejected = $
         MAKE_ARRAY(numDPRrays, num_elevations_out, /int, VALUE=INT_RANGE_EDGE)
     ; deal with the extra dimension for correctedReflectFactor for FS swath
     ; -- create once, write twice (Ku and Ka FS values)
      IF idxKuKa[swathID] EQ 0 THEN BEGIN
         CASE (DPR_scantype) OF
            'FS' : BEGIN
                   tocdf_correctedReflectFactor = MAKE_ARRAY(nKuKa, numDPRrays, $
                      num_elevations_out, /float, VALUE=FLOAT_RANGE_EDGE)
                   tocdf_n_dpr_expected = MAKE_ARRAY(nKuKa, numDPRrays, $
                      num_elevations_out, /int, VALUE=INT_RANGE_EDGE)
                   tocdf_n_correctedReflectFactor_rejected = MAKE_ARRAY(nKuKa, $
                      numDPRrays, num_elevations_out, /float, VALUE=FLOAT_RANGE_EDGE)
                   END
            'NS' : BEGIN
                   tocdf_correctedReflectFactor = MAKE_ARRAY(numDPRrays, $
                      num_elevations_out, /float, VALUE=FLOAT_RANGE_EDGE)
                   tocdf_n_dpr_expected = MAKE_ARRAY(numDPRrays, $
                      num_elevations_out, /int, VALUE=INT_RANGE_EDGE)
                   tocdf_n_correctedReflectFactor_rejected = MAKE_ARRAY(numDPRrays, $
                      num_elevations_out, /float, VALUE=FLOAT_RANGE_EDGE)
                   END
         ENDCASE
      ENDIF

     ; get the indices of actual DPR footprints and create and load the 2D element
     ;   subarrays (no averaging/processing needed) with data from the product arrays

      prgoodidx = WHERE( tocdf_pr_idx GE 0L, countprgood )
      IF ( countprgood GT 0 ) THEN BEGIN
         pr_idx_2get = tocdf_pr_idx[prgoodidx]
         tocdf_precipitationType[prgoodidx] = precipitationType[pr_idx_2get]
         tocdf_surfPrecipTotRate[prgoodidx] = surfPrecipTotRate[pr_idx_2get]
         tocdf_surfaceElevation[prgoodidx] = surfaceElevation[pr_idx_2get]
         tocdf_surfaceType[prgoodidx] = surfaceType[pr_idx_2get]
         tocdf_phaseBinNodes[*,prgoodidx] = phaseBinNodes[*,pr_idx_2get]
         tocdf_zeroDegAltitude[prgoodidx] = zeroDegAltitude[pr_idx_2get]
         tocdf_zeroDegBin[prgoodidx] = zeroDegBin[pr_idx_2get]
         tocdf_tbSim_19v[prgoodidx] = tbSim_19v[pr_idx_2get]
         tocdf_tbSim_37v[prgoodidx] = tbSim_37v[pr_idx_2get]
         tocdf_tbSim_89v[prgoodidx] = tbSim_89v[pr_idx_2get]
         tocdf_tbSim_183_3v[prgoodidx] = tbSim_183_3v[pr_idx_2get]

        ; deal with the extra dimension for these variables for FS swath
         CASE (DPR_scantype) OF
            'FS' : BEGIN
                   tocdf_ellipsoidBinOffset[idxKuKa[swathID], prgoodidx] = $
                      ellipsoidBinOffset[pr_idx_2get]
                   tocdf_lowestClutterFreeBin[idxKuKa[swathID], prgoodidx] = $
                      lowestClutterFreeBin[pr_idx_2get]
                   tocdf_precipitationFlag[idxKuKa[swathID], prgoodidx] = $
                      precipitationFlag[pr_idx_2get]
                   tocdf_surfaceRangeBin[idxKuKa[swathID], prgoodidx] = $
                      surfaceRangeBin[pr_idx_2get]
                   tocdf_pia[idxKuKa[swathID], prgoodidx] = pia[pr_idx_2get]
                   tocdf_stormTopAltitude[idxKuKa[swathID], prgoodidx] = $
                      stormTopAltitude[pr_idx_2get]
                   END
            'NS' : BEGIN
                   tocdf_ellipsoidBinOffset[prgoodidx] = $
                      ellipsoidBinOffset[pr_idx_2get]
                   tocdf_lowestClutterFreeBin[prgoodidx] = $
                      lowestClutterFreeBin[pr_idx_2get]
                   tocdf_precipitationFlag[prgoodidx] = $
                      precipitationFlag[pr_idx_2get]
                   tocdf_surfaceRangeBin[prgoodidx] = $
                      surfaceRangeBin[pr_idx_2get]
                   tocdf_pia[prgoodidx] = pia[pr_idx_2get]
                   tocdf_stormTopAltitude[prgoodidx] = $
                      stormTopAltitude[pr_idx_2get]
                   END
         ENDCASE
     ENDIF

   ENDIF ELSE BEGIN
      PRINT, ""
      PRINT, "No in-range DPR footprints found for ", siteID, ", swath ", $
             DPR_scantype, ", instrument ", instrumentID, ", skipping."
      PRINT, ""
      GOTO, skippedSwath
   ENDELSE

  ; ============================================================================

  ; Map this GR radar's data to these DPR footprints, where DPR rays
  ; intersect the elevation sweeps.  This part of the algorithm continues
  ; in code in a separate file, included below:

   @polar2dprgmi_resampling_v7.pro

  ; ============================================================================


   IF idxKuKa[swathID] EQ 0 THEN BEGIN
     ;  Write the swath-invariant FS values the first time through only
     ;  (Ku processing), don't overwrite for Ka instance.

     ;  Write single-level results/flags to netcdf file
      NCDF_VARPUT, ncid, 'DPRlatitude_'+DPR_scantype, tocdf_lat_sfc
      NCDF_VARPUT, ncid, 'DPRlongitude_'+DPR_scantype, tocdf_lon_sfc
      NCDF_VARPUT, ncid, 'rayNum_'+DPR_scantype, tocdf_rayNum
      NCDF_VARPUT, ncid, 'scanNum_'+DPR_scantype, tocdf_scanNum
      NCDF_VARPUT, ncid, 'Year_'+DPR_scantype, tocdf_Year
      NCDF_VARPUT, ncid, 'Month_'+DPR_scantype, tocdf_Month
      NCDF_VARPUT, ncid, 'DayOfMonth_'+DPR_scantype, tocdf_DayOfMonth
      NCDF_VARPUT, ncid, 'Hour_'+DPR_scantype, tocdf_Hour
      NCDF_VARPUT, ncid, 'Minute_'+DPR_scantype, tocdf_Minute
      NCDF_VARPUT, ncid, 'Second_'+DPR_scantype, tocdf_Second
      NCDF_VARPUT, ncid, 'Millisecond_'+DPR_scantype, tocdf_Millisecond
      NCDF_VARPUT, ncid, 'startScan_'+DPR_scantype, tocdf_startScan
      NCDF_VARPUT, ncid, 'endScan_'+DPR_scantype, tocdf_endScan
      NCDF_VARPUT, ncid, 'numRays_'+DPR_scantype, numPRinrange
      NCDF_VARPUT, ncid, 'precipitationType_'+DPR_scantype, tocdf_precipitationType
      NCDF_VARPUT, ncid, 'surfPrecipTotRate_'+DPR_scantype, tocdf_surfPrecipTotRate
      NCDF_VARPUT, ncid, 'surfaceElevation_'+DPR_scantype, tocdf_surfaceElevation
      NCDF_VARPUT, ncid, 'surfaceType_'+DPR_scantype, tocdf_surfaceType
      NCDF_VARPUT, ncid, 'zeroDegAltitude_'+DPR_scantype, tocdf_zeroDegAltitude
      NCDF_VARPUT, ncid, 'zeroDegBin_'+DPR_scantype, tocdf_zeroDegBin
      NCDF_VARPUT, ncid, 'phaseBinNodes_'+DPR_scantype, tocdf_phaseBinNodes
      NCDF_VARPUT, ncid, 'tbSim_19v_'+DPR_scantype, tocdf_tbSim_19v
      NCDF_VARPUT, ncid, 'tbSim_37v_'+DPR_scantype, tocdf_tbSim_37v
      NCDF_VARPUT, ncid, 'tbSim_89v_'+DPR_scantype, tocdf_tbSim_89v
      NCDF_VARPUT, ncid, 'tbSim_183_3v_'+DPR_scantype, tocdf_tbSim_183_3v

     ;  Write sweep-level results/flags to netcdf file

     ; Geometry variables first
      NCDF_VARPUT, ncid, 'latitude_'+DPR_scantype, tocdf_lat
      NCDF_VARPUT, ncid, 'longitude_'+DPR_scantype, tocdf_lon
      NCDF_VARPUT, ncid, 'xCorners_'+DPR_scantype, tocdf_x_poly
      NCDF_VARPUT, ncid, 'yCorners_'+DPR_scantype, tocdf_y_poly
      NCDF_VARPUT, ncid, 'topHeight_'+DPR_scantype, tocdf_top_hgt
      NCDF_VARPUT, ncid, 'bottomHeight_'+DPR_scantype, tocdf_botm_hgt

     ; GR variables next
      NCDF_VARPUT, ncid, 'GR_Z_'+DPR_scantype, tocdf_gr_dbz             ; data
       NCDF_VARPUT, ncid, 'have_GR_Z', DATA_PRESENT       ; data presence flag
      NCDF_VARPUT, ncid, 'GR_Z_StdDev_'+DPR_scantype, tocdf_gr_stddev    ; data
      NCDF_VARPUT, ncid, 'GR_Z_Max_'+DPR_scantype, tocdf_gr_max          ; data
      IF ( have_gv_rc ) THEN BEGIN
         NCDF_VARPUT, ncid, 'GR_RC_rainrate_'+DPR_scantype, tocdf_gr_rc            ; data
         NCDF_VARPUT, ncid, 'GR_RC_rainrate_StdDev_'+DPR_scantype, tocdf_gr_rc_stddev
         NCDF_VARPUT, ncid, 'GR_RC_rainrate_Max_'+DPR_scantype, tocdf_gr_rc_max
      ENDIF
      NCDF_VARPUT, ncid, 'have_GR_RC_rainrate', have_gv_rc      ; data presence flag
      IF ( have_gv_rp ) THEN BEGIN
         NCDF_VARPUT, ncid, 'GR_RP_rainrate_'+DPR_scantype, tocdf_gr_rp            ; data
         NCDF_VARPUT, ncid, 'GR_RP_rainrate_StdDev_'+DPR_scantype, tocdf_gr_rp_stddev
         NCDF_VARPUT, ncid, 'GR_RP_rainrate_Max_'+DPR_scantype, tocdf_gr_rp_max
      ENDIF
      NCDF_VARPUT, ncid, 'have_GR_RP_rainrate', have_gv_rp      ; data presence flag
      IF ( have_gv_rr ) THEN BEGIN
         NCDF_VARPUT, ncid, 'GR_RR_rainrate_'+DPR_scantype, tocdf_gr_rr            ; data
         NCDF_VARPUT, ncid, 'GR_RR_rainrate_StdDev_'+DPR_scantype, tocdf_gr_rr_stddev
         NCDF_VARPUT, ncid, 'GR_RR_rainrate_Max_'+DPR_scantype, tocdf_gr_rr_max
      ENDIF
      NCDF_VARPUT, ncid, 'have_GR_RR_rainrate', have_gv_rr      ; data presence flag
      IF ( have_gv_zdr ) THEN BEGIN
         NCDF_VARPUT, ncid, 'GR_Zdr_'+DPR_scantype, tocdf_gr_zdr            ; data
         NCDF_VARPUT, ncid, 'GR_Zdr_StdDev_'+DPR_scantype, tocdf_gr_zdr_stddev     ; data
         NCDF_VARPUT, ncid, 'GR_Zdr_Max_'+DPR_scantype, tocdf_gr_zdr_max            ; data
      ENDIF
      NCDF_VARPUT, ncid, 'have_GR_Zdr', have_gv_zdr      ; data presence flag
      IF ( have_gv_kdp ) THEN BEGIN
         NCDF_VARPUT, ncid, 'GR_Kdp_'+DPR_scantype, tocdf_gr_kdp            ; data
         NCDF_VARPUT, ncid, 'GR_Kdp_StdDev_'+DPR_scantype, tocdf_gr_kdp_stddev     ; data
         NCDF_VARPUT, ncid, 'GR_Kdp_Max_'+DPR_scantype, tocdf_gr_kdp_max            ; data
      ENDIF
      NCDF_VARPUT, ncid, 'have_GR_Kdp', have_gv_kdp      ; data presence flag
      IF ( have_gv_rhohv ) THEN BEGIN
         NCDF_VARPUT, ncid, 'GR_RHOhv_'+DPR_scantype, tocdf_gr_rhohv            ; data
         NCDF_VARPUT, ncid, 'GR_RHOhv_StdDev_'+DPR_scantype, tocdf_gr_rhohv_stddev     ; data
         NCDF_VARPUT, ncid, 'GR_RHOhv_Max_'+DPR_scantype, tocdf_gr_rhohv_max            ; data
      ENDIF
      NCDF_VARPUT, ncid, 'have_GR_RHOhv', have_gv_rhohv      ; data presence flag
      IF ( have_gv_hid ) THEN BEGIN
         NCDF_VARPUT, ncid, 'GR_HID_'+DPR_scantype, tocdf_gr_hid            ; data
      ENDIF
      NCDF_VARPUT, ncid, 'have_GR_HID', have_gv_hid      ; data presence flag
      IF ( have_gv_nw ) THEN BEGIN
         NCDF_VARPUT, ncid, 'GR_Nw_'+DPR_scantype, tocdf_gr_nw            ; data
         NCDF_VARPUT, ncid, 'GR_Nw_StdDev_'+DPR_scantype, tocdf_gr_nw_stddev     ; data
         NCDF_VARPUT, ncid, 'GR_Nw_Max_'+DPR_scantype, tocdf_gr_nw_max            ; data
      ENDIF
      NCDF_VARPUT, ncid, 'have_GR_Nw', have_gv_nw      ; data presence flag
	  IF ( have_gv_mw ) THEN BEGIN
	      NCDF_VARPUT, ncid, 'GR_liquidWaterContent_'+DPR_scantype, tocdf_gr_mw            ; data
	      NCDF_VARPUT, ncid, 'GR_liquidWaterContent_StdDev_'+DPR_scantype, tocdf_gr_mw_stddev     ; data
	      NCDF_VARPUT, ncid, 'GR_liquidWaterContent_Max_'+DPR_scantype, tocdf_gr_mw_max            ; data
	  ENDIF
	  NCDF_VARPUT, ncid, 'have_GR_liquidWaterContent', have_gv_mw      ; data presence flag
	  IF ( have_gv_mi ) THEN BEGIN
	      NCDF_VARPUT, ncid, 'GR_frozenWaterContent_'+DPR_scantype, tocdf_gr_mi            ; data
	      NCDF_VARPUT, ncid, 'GR_frozenWaterContent_StdDev_'+DPR_scantype, tocdf_gr_mi_stddev     ; data
	      NCDF_VARPUT, ncid, 'GR_frozenWaterContent_Max_'+DPR_scantype, tocdf_gr_mi_max            ; data
	  ENDIF
	  NCDF_VARPUT, ncid, 'have_GR_frozenWaterContent', have_gv_mi      ; data presence flag
	  IF ( have_gv_dm ) THEN BEGIN
	      NCDF_VARPUT, ncid, 'GR_Dm_'+DPR_scantype, tocdf_gr_dm             ; data
	      NCDF_VARPUT, ncid, 'GR_Dm_StdDev_'+DPR_scantype, tocdf_gr_dm_stddev      ; data
	      NCDF_VARPUT, ncid, 'GR_Dm_Max_'+DPR_scantype, tocdf_gr_dm_max            ; data
	  ENDIF
	  NCDF_VARPUT, ncid, 'have_GR_Dm', have_gv_dm      ; data presence flag
	  IF ( have_gv_sigmadm ) THEN BEGIN
	      NCDF_VARPUT, ncid, 'GR_sigmaDm_'+DPR_scantype, tocdf_gr_sigmadm             ; data
	      NCDF_VARPUT, ncid, 'GR_sigmaDm_StdDev_'+DPR_scantype, tocdf_gr_sigmadm_stddev      ; data
	      NCDF_VARPUT, ncid, 'GR_sigmaDm_Max_'+DPR_scantype, tocdf_gr_sigmadm_max            ; data
	  ENDIF
	  NCDF_VARPUT, ncid, 'have_GR_sigmaDm', have_gv_sigmadm      ; data presence flag
      IF ( have_gv_blockage ) THEN BEGIN
         NCDF_VARPUT, ncid, 'GR_blockage_'+DPR_scantype, tocdf_gr_blockage      ; data
      ENDIF
      NCDF_VARPUT, ncid, 'have_GR_blockage', have_gv_blockage      ; data presence flag

	   if ( have_gv_swe ) then begin
	      NCDF_VARPUT, ncid, 'GR_SWEDP_'+DPR_scantype, tocdf_gr_swedp            ; data
	      NCDF_VARPUT, ncid, 'GR_SWEDP_StdDev_'+DPR_scantype, tocdf_gr_swedp_stddev
	      NCDF_VARPUT, ncid, 'GR_SWEDP_Max_'+DPR_scantype, tocdf_gr_swedp_max   
	
	      NCDF_VARPUT, ncid, 'GR_SWE25_'+DPR_scantype, tocdf_gr_swe25            ; data
	      NCDF_VARPUT, ncid, 'GR_SWE25_StdDev_'+DPR_scantype, tocdf_gr_swe25_stddev
	      NCDF_VARPUT, ncid, 'GR_SWE25_Max_'+DPR_scantype, tocdf_gr_swe25_max   
	
	      NCDF_VARPUT, ncid, 'GR_SWE50_'+DPR_scantype, tocdf_gr_swe50            ; data
	      NCDF_VARPUT, ncid, 'GR_SWE50_StdDev_'+DPR_scantype, tocdf_gr_swe50_stddev
	      NCDF_VARPUT, ncid, 'GR_SWE50_Max_'+DPR_scantype, tocdf_gr_swe50_max   
	
	      NCDF_VARPUT, ncid, 'GR_SWE75_'+DPR_scantype, tocdf_gr_swe75            ; data
	      NCDF_VARPUT, ncid, 'GR_SWE75_StdDev_'+DPR_scantype, tocdf_gr_swe75_stddev
	      NCDF_VARPUT, ncid, 'GR_SWE75_Max_'+DPR_scantype, tocdf_gr_swe75_max   
	      
	      NCDF_VARPUT, ncid, 'GR_SWEMQT_'+DPR_scantype, tocdf_gr_swemqt            ; data
	      NCDF_VARPUT, ncid, 'GR_SWEMQT_StdDev_'+DPR_scantype, tocdf_gr_swemqt_stddev
	      NCDF_VARPUT, ncid, 'GR_SWEMQT_Max_'+DPR_scantype, tocdf_gr_swemqt_max   
	      
	      NCDF_VARPUT, ncid, 'GR_SWEMRMS_'+DPR_scantype, tocdf_gr_swemrms            ; data
	      NCDF_VARPUT, ncid, 'GR_SWEMRMS_StdDev_'+DPR_scantype, tocdf_gr_swemrms_stddev
	      NCDF_VARPUT, ncid, 'GR_SWEMRMS_Max_'+DPR_scantype, tocdf_gr_swemrms_max   
	      
	   endif
	   NCDF_VARPUT, ncid, 'have_GR_SWE', have_gv_swe      ; data presence flag

      NCDF_VARPUT, ncid, 'n_gr_z_rejected_'+DPR_scantype, tocdf_gr_rejected
      NCDF_VARPUT, ncid, 'n_gr_rc_rejected_'+DPR_scantype, tocdf_gr_rc_rejected
      NCDF_VARPUT, ncid, 'n_gr_rp_rejected_'+DPR_scantype, tocdf_gr_rp_rejected
      NCDF_VARPUT, ncid, 'n_gr_rr_rejected_'+DPR_scantype, tocdf_gr_rr_rejected
      NCDF_VARPUT, ncid, 'n_gr_zdr_rejected_'+DPR_scantype, tocdf_gr_zdr_rejected
      NCDF_VARPUT, ncid, 'n_gr_kdp_rejected_'+DPR_scantype, tocdf_gr_kdp_rejected
      NCDF_VARPUT, ncid, 'n_gr_rhohv_rejected_'+DPR_scantype, tocdf_gr_rhohv_rejected
      NCDF_VARPUT, ncid, 'n_gr_hid_rejected_'+DPR_scantype, tocdf_gr_hid_rejected
      NCDF_VARPUT, ncid, 'n_gr_nw_rejected_'+DPR_scantype, tocdf_gr_nw_rejected
      NCDF_VARPUT, ncid, 'n_gr_liquidWaterContent_rejected_'+DPR_scantype, tocdf_gr_mw_rejected
      NCDF_VARPUT, ncid, 'n_gr_frozenWaterContent_rejected_'+DPR_scantype, tocdf_gr_mi_rejected
      NCDF_VARPUT, ncid, 'n_gr_dm_rejected_'+DPR_scantype, tocdf_gr_dm_rejected
      NCDF_VARPUT, ncid, 'n_gr_sigmadm_rejected_'+DPR_scantype, tocdf_gr_sigmadm_rejected
   	  NCDF_VARPUT, ncid, 'n_gr_swedp_rejected_'+DPR_scantype, tocdf_gr_swedp_rejected
      NCDF_VARPUT, ncid, 'n_gr_swe25_rejected_'+DPR_scantype, tocdf_gr_swe25_rejected
      NCDF_VARPUT, ncid, 'n_gr_swe50_rejected_'+DPR_scantype, tocdf_gr_swe50_rejected
      NCDF_VARPUT, ncid, 'n_gr_swe75_rejected_'+DPR_scantype, tocdf_gr_swe75_rejected
      NCDF_VARPUT, ncid, 'n_gr_swemqt_rejected_'+DPR_scantype, tocdf_gr_swemqt_rejected
      NCDF_VARPUT, ncid, 'n_gr_swemrms_rejected_'+DPR_scantype, tocdf_gr_swemrms_rejected
      NCDF_VARPUT, ncid, 'n_gr_expected_'+DPR_scantype, tocdf_gr_expected

   	  NCDF_VARPUT, ncid, 'n_gr_nw_precip_'+DPR_scantype, tocdf_gr_nw_n_precip
      NCDF_VARPUT, ncid, 'n_gr_liquidWaterContent_precip_'+DPR_scantype, tocdf_gr_mw_n_precip
      NCDF_VARPUT, ncid, 'n_gr_frozenWaterContent_precip_'+DPR_scantype, tocdf_gr_mi_n_precip
      NCDF_VARPUT, ncid, 'n_gr_dm_precip_'+DPR_scantype, tocdf_gr_dm_n_precip
      NCDF_VARPUT, ncid, 'n_gr_sigmadm_precip_'+DPR_scantype, tocdf_gr_sigmadm_n_precip
      NCDF_VARPUT, ncid, 'n_gr_rr_precip_'+DPR_scantype, tocdf_gr_rr_n_precip
      NCDF_VARPUT, ncid, 'n_gr_rc_precip_'+DPR_scantype, tocdf_gr_rc_n_precip
      NCDF_VARPUT, ncid, 'n_gr_rp_precip_'+DPR_scantype, tocdf_gr_rp_n_precip

     ; DPRGMI variables last
      NCDF_VARPUT, ncid, 'precipTotDm_'+DPR_scantype, tocdf_precipTotDm
      NCDF_VARPUT, ncid, 'precipTotLogNw_'+DPR_scantype, tocdf_precipTotLogNw
      NCDF_VARPUT, ncid, 'precipTotMu_'+DPR_scantype, tocdf_precipTotMu
;      NCDF_VARPUT, ncid, 'precipTotPSDparamHigh_'+DPR_scantype, tocdf_precipTotPSDparamHigh
;      NCDF_VARPUT, ncid, 'precipTotPSDparamLow_'+DPR_scantype, tocdf_precipTotPSDparamLow
      NCDF_VARPUT, ncid, 'precipTotRate_'+DPR_scantype, tocdf_precipTotRate
      NCDF_VARPUT, ncid, 'precipTotWaterCont_'+DPR_scantype, tocdf_precipTotWaterCont
      NCDF_VARPUT, ncid, 'precipTotWaterContSigma_'+DPR_scantype, tocdf_precipTotWaterContSigma
      NCDF_VARPUT, ncid, 'cloudLiqWaterCont_'+DPR_scantype, tocdf_cloudLiqWaterCont
      NCDF_VARPUT, ncid, 'cloudIceWaterCont_'+DPR_scantype, tocdf_cloudIceWaterCont
      NCDF_VARPUT, ncid, 'n_dpr_expected_'+DPR_scantype, tocdf_n_dpr_expected
      NCDF_VARPUT, ncid, 'n_precipTotDm_rejected_'+DPR_scantype, $
                   tocdf_n_precipTotDm_rejected
      NCDF_VARPUT, ncid, 'n_precipTotLogNw_rejected_'+DPR_scantype, $
                   tocdf_n_precipTotLogNw_rejected
      NCDF_VARPUT, ncid, 'n_precipTotMu_rejected_'+DPR_scantype, $
                   tocdf_n_precipTotMu_rejected
;      NCDF_VARPUT, ncid, 'n_precipTotPSDparamHigh_rejected_'+DPR_scantype, $
;                   tocdf_n_precipTotPSDparamHigh_rejected
;      NCDF_VARPUT, ncid, 'n_precipTotPSDparamLow_rejected_'+DPR_scantype, $
;                   tocdf_n_precipTotPSDparamLow_rejected
      NCDF_VARPUT, ncid, 'n_precipTotRate_rejected_'+DPR_scantype, $
                   tocdf_n_precipTotRate_rejected
      NCDF_VARPUT, ncid, 'n_precipTotWaterCont_rejected_'+DPR_scantype, $
                   tocdf_n_precipTotWaterCont_rejected
      NCDF_VARPUT, ncid, 'n_precipTotWaterContSigma_rejected_'+DPR_scantype, $
                   tocdf_n_precipTotWaterContSigma_rejected
      NCDF_VARPUT, ncid, 'n_cloudLiqWaterCont_rejected_'+DPR_scantype, $
                   tocdf_n_cloudLiqWaterCont_rejected
      NCDF_VARPUT, ncid, 'n_cloudIceWaterCont_rejected_'+DPR_scantype, $
                   tocdf_n_cloudIceWaterCont_rejected
      IF DPR_scantype EQ 'NS' THEN BEGIN
        ; write variables for the NS swath with only Ku values that have both
        ; Ku and Ka values in the MS swath instance
         NCDF_VARPUT, ncid, 'ellipsoidBinOffset_'+DPR_scantype, $
                      tocdf_ellipsoidBinOffset
         NCDF_VARPUT, ncid, 'lowestClutterFreeBin_'+DPR_scantype, $
                      tocdf_lowestClutterFreeBin
         NCDF_VARPUT, ncid, 'clutterStatus_'+DPR_scantype, $
                      tocdf_clutterStatus
         NCDF_VARPUT, ncid, 'precipitationFlag_'+DPR_scantype, $
                      tocdf_precipitationFlag
         NCDF_VARPUT, ncid, 'surfaceRangeBin_'+DPR_scantype, tocdf_surfaceRangeBin
         NCDF_VARPUT, ncid, 'pia_'+DPR_scantype, tocdf_pia
         NCDF_VARPUT, ncid, 'stormTopAltitude_'+DPR_scantype, tocdf_stormTopAltitude
         NCDF_VARPUT, ncid, 'correctedReflectFactor_'+DPR_scantype, $
                      tocdf_correctedReflectFactor
         NCDF_VARPUT, ncid, 'n_correctedReflectFactor_rejected_'+DPR_scantype, $
                      tocdf_n_correctedReflectFactor_rejected
      ENDIF
   ENDIF ELSE BEGIN
     ; write variables for the FS swath with both Ku and Ka values that were
     ; incomplete on the 1st (Ku) FS pass
      NCDF_VARPUT, ncid, 'ellipsoidBinOffset_'+DPR_scantype, $
                   tocdf_ellipsoidBinOffset
      NCDF_VARPUT, ncid, 'lowestClutterFreeBin_'+DPR_scantype, $
                   tocdf_lowestClutterFreeBin
      NCDF_VARPUT, ncid, 'clutterStatus_'+DPR_scantype, $
                   tocdf_clutterStatus
      NCDF_VARPUT, ncid, 'precipitationFlag_'+DPR_scantype, $
                   tocdf_precipitationFlag
      NCDF_VARPUT, ncid, 'surfaceRangeBin_'+DPR_scantype, tocdf_surfaceRangeBin
      NCDF_VARPUT, ncid, 'pia_'+DPR_scantype, tocdf_pia
         NCDF_VARPUT, ncid, 'stormTopAltitude_'+DPR_scantype, tocdf_stormTopAltitude
      NCDF_VARPUT, ncid, 'correctedReflectFactor_'+DPR_scantype, $
                   tocdf_correctedReflectFactor
      NCDF_VARPUT, ncid, 'n_correctedReflectFactor_rejected_'+DPR_scantype, $
                   tocdf_n_correctedReflectFactor_rejected
   ENDELSE


   skippedSwath:

   endfor   ; swathID, second time through swath/source combos

   IF keyword_set(plot_ppis) THEN BEGIN
     ; delete the two PPI windows at the end
      wdelete, !d.window
      wdelete, !d.window
   ENDIF

   emptyFile:
   NCDF_CLOSE, ncid

  ; gzip the finished netCDF file
   PRINT
   PRINT, "Output netCDF file:"
   PRINT, ncfile
   PRINT, "is being compressed."
   PRINT
   command = "gzip -v " + ncfile
   spawn, command

   nextGRfile:

ENDFOR    ; each GR site for orbit

nextOrbit:

ENDWHILE  ; each orbit/DPR file set to process in control file

print, ""
print, "Done!"

bailOut:
CLOSE, lun0

END
