;===============================================================================
;+
; Copyright © 2016, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; dpr2gr_prematch_v7.pro          Morris/SAIC/GPM_GV      March 2016
;
; DESCRIPTION
; -----------
; Performs a resampling and merger of DPR data to 3-D volumes in common with GR
; data previously volume matched to the DPR footprints, for each of the DPR scan
; types (HS, FS) that apply to the 2A file type (2ADPR, 2AKa, or 2AKu), and
; for each ground radar site associated to the 2A file, as specified in a
; control file for a run.  GR data previously matched to all 3 DPR scans is in a
; netCDF file which contains, along with the GR variables, precomputed geometry
; variables needed to perform the DPR volume matching.  Volumes are defined in
; the horizontal by the location of DPR rays, and in the vertical by the heights
; of the intersection of the DPR rays with the top and bottom edges of individual
; elevation sweeps of a ground radar scanning in PPI mode.  The data domain is
; determined by the location of the ground radars relative to the DPR scan swath
; and the cutoff range (range_threshold_km) which is defined in the GR netCDF
; data file.  Once the volume matching of the DPR data for the selected scan
; type and GR site are completed, these data are written, along with the volume-
; matched GR data, to a new GRtoDPR matchup netCDF file of a format defined by
; the function gen_dpr_geo_match_netcdf_v7().
;
; The DPR and GR (ground radar) files to process are specified in the mandatory
; parameter 'control_file', a fully-qualified file name of the control file to
; use in the run.  The control file is of a specific layout and contains
; specific fields in a fixed order and format.  The same control file used in
; the GR-only volume matching to DPR is input to this procedure.  See the script
; "do_DPR_GeoMatch.sh", which creates the control file for this and other GR-DPR
; matchup procedures.  By convention, the control file lists data files for one
; day's data, but this is not a requirement.
;
; The optional parameter GPM_ROOT accommodates the situation of a non-default
; local path to the DPR files whose partial pathnames are listed in the control
; file.  The original GR UF file names listed in the control file are used in
; this procedure to generate the "well-known" GR matchup netCDF partial file
; pathnames for each GR overpass event listed in the control file. The optional
; parameter DIR_GR_NC gives the non-default top level directory under which the
; GR matchup netcdf files are located.  If DIR_GR_NC is not specified then the
; top-level directory defaults to NCGRIDS_ROOT+GEO_MATCH_NCDIR.  The components
; for these default paths are defined in the environs_v7.inc file.  All file path
; optional parameter values must begin with a leading slash (e.g., '/mydata')
; and be enclosed in quotes, as shown.  Optional binary keyword parameters
; control immediate output of DPR-GR reflectivity differences (/SCORES) and
; plotting of the matched DPR and GR reflectivity fields sweep-by-sweep in the
; form of PPIs on a map background (/PLOT_PPIS).
;
; The control file is of a specific layout and contains specific fields in a
; fixed order and format.  See the script "do_DPR_GeoMatch.sh", which
; creates the control file and invokes IDL to run this procedure.  Completed
; DPR and GR matchup data for an individual site overpass event (i.e., a given
; GPM orbit and ground radar site) are written to a netCDF file.  The size of
; the dimensions in the data fields in the netCDF file vary from one case to
; another, depending on the number of elevation sweeps in the GR radar volume
; scan and the number of DPR footprints within the cutoff range from the GR
; site.
;
; The optional parameter NC_FILE specifies the directory to which the output
; netCDF files will be written.  It is created if it does not yet exist.  If
; a value for NC_FILE is not provided, then a default value is derived as a
; concatenation of the variables NCGRIDS_ROOT+GEO_MATCH_NCDIR defined in the
; environs_v7.inc "Include" file.  If the binary parameter FLAT_NCPATH is
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
; PARAMETERS
; ----------
;
; control_file - Fully-qualified pathname of the control file to be processed
;                in a run of dpr2gr_prematch, giving instructions on the 2A and
;                its matching GR overpass events for an orbit.
;
; GPM_ROOT=gpmroot - Non-default value of the top-level "common" directory under
;                    which the GPM 2ADPR, 2AKu, and 2AKa files are located.  If
;                    unspecified, defaults to GPMDATA_ROOT value defined in the
;                    IDL "Include" file "environs_v7.inc".
;
; DIRDPR=dir2adpr  - Non-default value of the mid-level "common" directory under
;                    which the GPM 2ADPR files are located.  This is the part of
;                    the path between gpmroot and the partial 2ADPR file name
;                    listed in the control file.  If unspecified, defaults to
;                    the DIR_2ADPR value defined in the IDL "Include" file
;                    environs_v7.inc.  If the combination of gpmroot, '/', and the
;                    partial 2ADPR file name in the control file is the complete
;                    pathname to the 2A file, then the DIRDPR parameter must be
;                    specified with the value '/.' (e.g., DIRDPR='/.').
;
; DIRKU=dir2aku - As in DIRDPR=dir2adpr, but for processing of a 2AKu matchup.
;                 If unspecified, defaults to the DIR_2AKU value defined in the
;                 IDL "Include" file environs_v7.inc.
;
; DIRKA=dir2aka - As in DIRDPR=dir2adpr, but for processing of a 2AKa matchup.
;                 If unspecified, defaults to the DIR_2AKA value defined in the
;                 IDL "Include" file environs_v7.inc.
;
;
; DIR_GV_NC=dir_gv_nc - Non-default value of the top-level "common" directory
;                       under which the previously computed GR volume match data
;                       files are located.  This part of the path is used along
;                       with the values of gr_nc_version, ncnameadd, and values
;                       extracted from the fields in the control file to compose
;                       the complete, "well-known" pathname to the matching
;                       GRtoDPR_HS_FS netCDF file for the site and orbit.
;                       If unspecified, defaults to the combined path value:
;                          NCGRIDS_ROOT+GR_DPR_GEO_MATCH_NCDIR
;                       of these two variables as defined in the IDL "Include"
;                       file environs_v7.inc.
;
; GR_NC_VERSION=gr_nc_version - Non-default value of the GRtoDPR_HS_FS netCDF
;                               matchup file version to be used.  Default='1_0'
;                               Must be specfied as an IDL STRING in the format
;                               'N_n' or 'N.n', where N is the major version and
;                               n is the minor version.  If specified as 'N.n',
;                               then the value is converted to the 'N_n' format
;                               used for the version field in GRtoDPR_HS_FS
;                               netCDF file names.
;
; VERSION2MATCH=version2match  - Optional parameter.  Specifies that a different
;                                PPS version from that of the 2ADPR, 2AKa, or
;                                2AKu file being processed is to be used to
;                                identify the GRtoDPR_HS_FS netCDF file that
;                                is the match to the 2A file.  Other attributes
;                                of the two files (orbit, date, ncnameadd) must
;                                still be the same for the files to be
;                                considered "matching".  Allows a newer 2A data
;                                version to be merged with existing GR-only
;                                volume match data from an older PPS version if
;                                the geometry (DPR footprint latitude/longitude)
;                                does not change between PPS versions.
;
; PLOT_PPIS=plot_PPIs - Binary parameter.  If set to 1 then PPIs of the volume
;                       matched GR and DPR reflectivity will be displayed for
;                       each sweep elevation as the matchup data are completed.
;                       Default=0 (no display of PPIs).
;
; SCORES=run_scores - Binary parameter.  If set to 1 then bias of the volume
;                     matched GR and DPR reflectivity will be computed for
;                     each sweep elevation as the matchup data are completed.
;                     Default=0 (no display of biases).
;
; NC_DIR=nc_dir - Non-default value of the top-level "common" directory under
;                 which the completed GRtoDPR matchup netCDF files will be
;                 written.  If the binary parameter FLAT_NCPATH is set to 1 (on)
;                 then the output files will be written directly in this
;                 directory with no subdirectory structure to organize the files
;                 by source, version, type, etc.  Otherwise, the output files
;                 will be written into a default subdirectory structure under
;                 nc_dir of the following form: /GPM/2Axx/XS/Vnnv/N_n/YYYY
;                 where: /GPM = literal path
;                        /2Axx = 2A file type (2ADPR, 2AKa, or 2AKu)
;                        /XS = scan type (HS, MS, or NS)
;                        /Vnnv = 2A file version, e.g. V04A
;                        /N_n = GRtoDPR matchup file version, e.g. 1_2 or 1_21
;                        /YYYY = 4-digit year of the data
;
; FLAT_NCPATH=flat_ncpath - See NC_DIR.  Default=0 (write output files under
;                           expanded subdirectory paths).
;
; NC_NAME_ADD=ncnameadd - Optional component of the input and output file base
;                         names to distinguish them from the default file names
;                         in the case where more than one set of matchup files
;                         may have been created from the same GR and DPR data.
;                         See DIR_GV_NC for constraints on usage of ncnameadd.
;
; DPR_DBZ_MIN=dpr_dbz_min - Minimum value of DPR reflectivity gates to be
;                           included in the volume averages of corrected and
;                           measured DPR reflectivity.  Values below dpr_dbz_min
;                           are rejected from the volume averaging, and the
;                           number of rejected gates are tabulated in the data.
;
; DPR_RAIN_MIN=dpr_rain_min - As for dpr_dbz_min, but for DPR rain rate volume
;                             averages.
;
; NON_PPS_FILES=non_pps_files - Binary parameter.  If set to 1 then no checking
;                               of the 2A file basenames against the PPS file
;                               name convention is performed.  Default=0 (do
;                               file name checks and exit with errors if found).
;
; DECLUTTER=declutter - Binary parameter.  If set to 1 then run internal
;                       algorithm to detect, flag, and reject DPR clutter gates
;                       from the corrected and measured DPR reflectivity and 3-D
;                       rain rate volume averages.
;
;
; MODULES
; -------
;   1) PROCEDURE skip_gr_events          (this file)
;   2) PROCEDURE dpr2gr_prematch_scan_v7    (this file)
;   3) PROCEDURE dpr2gr_prematch_v7         (this file)
;
;
; CONSTRAINTS
; -----------
; DPR: 1) Only GPM 2AKa, 2AKu, and 2ADPR data files in HDF5 format are supported
;         by this code.
;      2) The GR data must have already been volume matched to the DPR rays
;         and written to a GRtoDPR_HS_FS netCDF file by the program
;         polar2dpr_hs_fs.pro, for each of the DPR and GR files listed
;         in the control file to be processed in a run of this procedure.
;         The exception is for missing GR data identified as 'no_1CUF_file' in
;         the control file, which will be skipped over in processing.
;      3) If a NC_NAME_ADD parameter value is specified, then the same value
;         must have been used to create the GRtoDPR_HS_FS netCDF file names
;         or the matching GRtoDPR_HS_FS file will not be found.  Likewise,
;         if a NC_NAME_ADD parameter value was used in the generation of the
;         GRtoDPR_HS_FS netCDF file names, the same value must be specified
;         as the NC_NAME_ADD parameter value for dpr2gr_prematch_v7().
;
;
; HISTORY
; -------
; 3/2016 by Bob Morris, GPM GV (SAIC)
;  - Created from code adapted from polar2dpr.pro and polar2dpr_resampling.pro.
; 03/17/16 by Bob Morris, GPM GV (SAIC)
;  - Moved copy, reassign of binRealSurface further up in this code file, as
;    it needs to be done only once for a given 2A file.
; 03/25/16 by Bob Morris, GPM GV (SAIC)
;  - Modified to do all scan types applicable to a given 2A[DPR|Ka|Ku] file, in
;    sequence, in a single run of the script, so that the file does not have to
;    be re-read each time another scan type is processed.
;  - Use binEllipsoid to compute range gates for rough check of existence of
;    DPR gates above the detection threshold along total ray.
;  - Added optional clutterFlag parameter to calls to get_dpr_layer_average()
;    for DPR measured Z, 3-D rain rate, Dm, and Nw.  Before this the elevated
;    clutter gates were rejected only from the DPR corrected Z volume averages.
;  - Changed default value for dpr_dbz_min to 15.0 dBZ.
;  - Changed default value for dir_gv_nc to NCGRIDS_ROOT+GR_DPR_GEO_MATCH_NCDIR.
;  - Dropped DIRCOMB keyword parameter and its use in the code as this product
;    type does not apply.
;  - Cleaned up the code indentation in major loops.
;  - Added input parameter descriptions and rules for use.
; 07/29/16 by Bob Morris, GPM GV (SAIC)
;  - Added DPR epsilon and n_dpr_epsilon_rejected variables and its presence
;    flag for updated version 1.21.
; 12/14/16 by Bob Morris, GPM GV (SAIC)
;  - Added processing of overlooked qualityData variable which was already
;    in the netCDF file definition but never populated.
; 02/27/17 Morris, GPM GV, SAIC
;  - Added VERSION2MATCH optional parameter to look for a GRtoDPR_HS_MS_NS file
;    matching the 2A[DPR/Ka|Ku] file specified in the control file, but having a
;    different PPS Version from the 2A file.
; 09/04/18 Berendes, UAH
;  - Added mods for SWE variables
; 09/30/20 Berendes, UAH
;  - Added pwat_integ_liquid and pwat_integ_solid variables
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

;===============================================================================

;*******************************************************************************
;
; dpr2gr_prematch_scan_v7
;
; DESCRIPTION
; -----------
; Performs a resampling and merger of DPR data to 3-D volumes in common with GR
; data previously volume matched to the DPR footprints, for any of the three DPR
; scan types (HS, FS).  Only one scan type is processed at a time in a call
; to this procedure.

PRO dpr2gr_prematch_scan_v7, dpr_data, data_GR2DPR, dataGR, DPR_scantype, $
               DPR_version, mygeometa, mysweeps, mysite, myflags, myfiles, $
               grverstr, Instrument_ID, infileNameArr, fname_netCDF, $
               PLOT_PPIS=plot_PPIs, SCORES=run_scores, $
               NC_DIR=nc_dir, FLAT_NCPATH=flat_ncpath, NC_NAME_ADD=ncnameadd, $
               DPR_DBZ_MIN=dpr_dbz_min, DPR_RAIN_MIN=dpr_rain_min, $
               NON_PPS_FILES=non_pps_files, DECLUTTER=declutter

; for debugging
;!EXCEPT=2

; "Include" file for DATA_PRESENT, NO_DATA_PRESENT
@grid_def.inc
; "Include" file for DPR-product-specific parameters (i.e., RAYSPERSCAN):
@dpr_params_v7.inc
; "Include" file for names, paths, etc.:
@environs_v7.inc
; for structures to be read from GR netCDF file
@dpr_geo_match_nc_structs_v7.inc

   decluttered = KEYWORD_SET(declutter)
   
   DO_KUKA = 0
   ; initialize to Ku
   indexKuKa = 0

   DO_RAIN_CORR = 1   ; set flag to do 3-D rain_corr processing by default

   ; get the group structures for the specified scantype, tags vary by swathname
   SWITCH DPR_scantype OF
      'HS' : BEGIN
                RAYSPERSCAN = RAYSPERSCAN_HS
                GATE_SPACE = BIN_SPACE_HS
                ELLIPSOID_BIN_DPR = ELLIPSOID_BIN_HS
                ptr_swath = dpr_data.HS
                break
             END
      'FS_Ka' : indexKuKa = 1 ; set to Ka
      'FS_Ku' : DO_KUKA = 1 ; KuKa will already be default to Ku
      'FS' : BEGIN
                RAYSPERSCAN = RAYSPERSCAN_FS
                GATE_SPACE = BIN_SPACE_FS
                ELLIPSOID_BIN_DPR = ELLIPSOID_BIN_FS
                DO_RAIN_CORR = 0   ; set flag to skip 3-D rainrate
                ptr_swath = dpr_data.FS
                break
             END
       ELSE: message, 'dpr2gr_prematch: error, unknown scan type '+DPR_scantype
   ENDSWITCH

   ; get the number of scans in the dataset
   SAMPLE_RANGE = ptr_swath.SWATHHEADER.NUMBERSCANSBEFOREGRANULE $
                + ptr_swath.SWATHHEADER.NUMBERSCANSGRANULE $
                + ptr_swath.SWATHHEADER.NUMBERSCANSAFTERGRANULE
                
   ; get the number of scans present in the original DPR file
   numDPRScans = mygeometa.numDPRScans
   numDPRrays_gr = data_GR2DPR.NUMRAYS

   ; TAB 2-17-22
   ; compare original dpr scans with the dataset scans.  If the same continue processing, else find mapping for DPR to dataset scans
   ; This is done to adjust Ka product subsets to the same area as DPR and Ku.  The Ka product subset generated by PPS often is not 
   ; the same number of scans do the the smaller width of the Ka HS scan.  We will compute an offset to make them line up.
   ; ##################################################################################
   if SAMPLE_RANGE ne numDPRScans then begin
   	   print, 'dpr2gr_prematch: numDPRScans ',numDPRScans,' does not match product scans ',SAMPLE_RANGE, ' for scan ',DPR_scantype
	   scan_offset = 0
	   ray_offset = 0
	   for ifp = 0, numDPRrays_gr-1 do begin
	      ray_num = data_GR2DPR.RAYNUM[ifp]
	      scan_num = data_GR2DPR.SCANNUM[ifp]
	      lat = data_GR2DPR.latitude[ifp]
	      lon = data_GR2DPR.longitude[ifp]
	      ; find offset in subset product file, search for closest lat/lon match for footprints
	      min_dist=1000.0
	      min_scan=-1
	      min_ray=-1
	      for scan=0,SAMPLE_RANGE-1 do begin
	          for ray=0,RAYSPERSCAN-1 do begin
	          	  swath_lat = (*ptr_swath.PTR_DATASETS).LATITUDE[ray,scan]
	          	  swath_lon = (*ptr_swath.PTR_DATASETS).LONGITUDE[ray,scan]
	          	  if swath_lat ge -90.0 and swath_lon ge -180.0 then begin
		              dy = lat - (*ptr_swath.PTR_DATASETS).LATITUDE[ray,scan]
		              dx = lon - (*ptr_swath.PTR_DATASETS).LONGITUDE[ray,scan]
		          	  dist = dx*dx + dy*dy
		          	  if dist lt min_dist then begin
		          	  	  min_dist=dist
		          	  	  min_scan=scan
		          	  	  min_ray=ray
		          	  endif
	          	  endif else begin
	      			  print, 'missing lat/lon in swath, fp ',ifp
	          	  endelse
	          endfor
	      endfor
	      s_off = scan_num - min_scan
	      r_off = ray_num - min_ray
	      if s_off ne scan_offset or r_off ne ray_offset then begin
	          scan_offset = s_off
	          ray_offset = r_off
	          print, 'scan/ray offset changed:'
		      print, 'DPR scan ',scan_num,' -> ',min_scan
		      print, 'DPR ray ',ray_num,' -> ',min_ray
		      print, 'distance ',min_dist
		      print, 'scan offset ',scan_offset
		      print, 'ray offset ',ray_offset
	      endif
	      
	      ; REMOVE, testing.....
	      ;goto, bailOut

;#####################################
	      
   	   endfor
   	   
   	   ; REMOVE, testing.....
	   goto, bailOut
;#####################################

   endif

   ; extract DPR variables/arrays from struct pointers
   IF PTR_VALID(ptr_swath.PTR_DATASETS) THEN BEGIN
      prlons = (*ptr_swath.PTR_DATASETS).LONGITUDE
      prlats = (*ptr_swath.PTR_DATASETS).LATITUDE
   ENDIF ELSE BEGIN
      message, "IDL Error Exit: Invalid pointer to PTR_DATASETS.", /INFO
      goto, bailOut
   ENDELSE

   IF PTR_VALID(ptr_swath.PTR_CSF) THEN BEGIN
      BB_hgt = (*ptr_swath.PTR_CSF).HEIGHTBB
      bbstatus = (*ptr_swath.PTR_CSF).QUALITYBB       ; got to convert to TRMM?
      rainType = (*ptr_swath.PTR_CSF).TYPEPRECIP      ; got to convert to TRMM?
   ENDIF ELSE BEGIN
      message, "IDL Error Exit: Invalid pointer to PTR_CSF.", /INFO
      goto, bailOut
   ENDELSE
   idxrntypedefined = WHERE(rainType GE 0, countrndef)
   IF countrndef GT 0 THEN rainType[idxrntypedefined] = $
      rainType[idxrntypedefined]/10000000L      ; truncate to TRMM 3-digit type

   IF PTR_VALID(ptr_swath.PTR_DSD) THEN BEGIN
   ENDIF ELSE message, "Invalid pointer to PTR_DSD.", /INFO

   IF PTR_VALID(ptr_swath.PTR_FLG) THEN BEGIN
      qualityData = (*ptr_swath.PTR_FLG).QUALITYDATA  ; new variable to deal with
   ENDIF ELSE BEGIN
      message, "IDL Error Exit: Invalid pointer to PTR_FLG.", /INFO
      goto, bailOut
   ENDELSE

   IF PTR_VALID(ptr_swath.PTR_PRE) THEN BEGIN
   	  if DO_KUKA then begin
	      dbz_meas = reform((*ptr_swath.PTR_PRE).ZFACTORMEASURED[indexKuKa,*,*,*]) ; in FS indexed by frequency
	      binRealSurface = reform((*ptr_swath.PTR_PRE).BINREALSURFACE[indexKuKa,*,*]) ; in FS indexed by frequency
	      localZenithAngle = reform((*ptr_swath.PTR_PRE).localZenithAngle[indexKuKa,*,*]) ; in FS indexed by frequency   	  
   	  endif else begin
	      dbz_meas = (*ptr_swath.PTR_PRE).ZFACTORMEASURED
	      binRealSurface = (*ptr_swath.PTR_PRE).BINREALSURFACE
	      localZenithAngle = (*ptr_swath.PTR_PRE).localZenithAngle
	  endelse
      binClutterFreeBottom = (*ptr_swath.PTR_PRE).binClutterFreeBottom
      landOceanFlag = (*ptr_swath.PTR_PRE).LANDSURFACETYPE
      rainFlag = (*ptr_swath.PTR_PRE).FLAGPRECIP
      heightStormTop = (*ptr_swath.PTR_PRE).heightStormTop
   ENDIF ELSE BEGIN
      message, "IDL Error Exit: Invalid pointer to PTR_PRE.", /INFO
      goto, bailOut
   ENDELSE
   
   ; TAB 2/16/21 added heightZeroDeg from VER
   IF PTR_VALID(ptr_swath.PTR_VER) THEN BEGIN
      ; help, *ptr_swath.PTR_VER
      heightZeroDeg = (*ptr_swath.PTR_VER).HEIGHTZERODEG   
   ENDIF ELSE BEGIN
      message, "IDL Error Exit: Invalid pointer to PTR_VER.", /INFO
      goto, bailOut
   ENDELSE

   IF PTR_VALID(ptr_swath.PTR_SLV) THEN BEGIN
   	  if DO_KUKA then begin
	      dbz_corr = reform((*ptr_swath.PTR_SLV).ZFACTORCORRECTED[indexKuKa,*,*,*]) ; in FS indexed by frequency
	      piaFinal = reform((*ptr_swath.PTR_SLV).piaFinal[indexKuKa,*,*]) ; in FS indexed by frequency
   	  endif else begin
	      dbz_corr = (*ptr_swath.PTR_SLV).ZFACTORCORRECTED
	      piaFinal = (*ptr_swath.PTR_SLV).piaFinal
	  endelse

      epsilon = (*ptr_swath.PTR_SLV).EPSILON
      rain_corr = (*ptr_swath.PTR_SLV).PRECIPRATE
      surfRain_corr = (*ptr_swath.PTR_SLV).PRECIPRATEESURFACE
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
      ; TAB 9/30/20 
      pwat_integ_liquid = REFORM( (*ptr_swath.PTR_SLV).precipWaterIntegrated[0,*,*] )
      pwat_integ_solid = REFORM( (*ptr_swath.PTR_SLV).precipWaterIntegrated[1,*,*] )
   ENDIF ELSE BEGIN
      message, "IDL Error Exit: Invalid pointer to PTR_SLV.", /INFO
      goto, bailOut
   ENDELSE

   IF PTR_VALID(ptr_swath.PTR_SRT) THEN BEGIN
   ENDIF ELSE message, "Invalid pointer to PTR_SRT.", /INFO

   IF PTR_VALID(ptr_swath.PTR_VER) THEN BEGIN
   ENDIF ELSE message, "Invalid pointer to PTR_VER.", /INFO

   ; make a copy of binRealSurface and set all values to the fixed
   ; bin number at the ellipsoid for the swath being processed.
   binEllipsoid = binRealSurface
   binEllipsoid[*,*] = ELLIPSOID_BIN_DPR

   ; precompute the reuseable ray angle trig variables for parallax -- in GPM,
   ; we have the local zenith angle for every ray/scan (i.e., footprint)
   cos_inc_angle = COS( 3.1415926D * localZenithAngle / 180. )
   tan_inc_angle = TAN( 3.1415926D * localZenithAngle / 180. )

;   PRINT, "Skipping 2BCMB processing for orbit = ", orbit
   havefile2bcmb = 0

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
;              GOTO, nextGRfile
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
;           GOTO, nextGRfile
         END
   ENDCASE

   tocdf_elev_angle = mysweeps[*].ELEVATIONANGLE
   num_elevations_out = N_ELEMENTS(tocdf_elev_angle)
  ; precompute cos(elev) for later repeated use
   cos_elev_angle = COS( tocdf_elev_angle * !DTOR )

   ufstruct={ CZ_ID:    mygeometa.GV_UF_Z_field, $
              ZDR_ID  : mygeometa.GV_UF_ZDR_field, $
              KDP_ID  : mygeometa.GV_UF_KDP_field, $
              RHOHV_ID: mygeometa.GV_UF_RHOHV_field, $
              RC_ID:    mygeometa.GV_UF_RC_field, $
              RP_ID:    mygeometa.GV_UF_RP_field, $
              RR_ID:    mygeometa.GV_UF_RR_field, $
              HID_ID:   mygeometa.GV_UF_HID_field, $
              D0_ID:    mygeometa.GV_UF_D0_field, $
              NW_ID:    mygeometa.GV_UF_NW_field, $
              DM_ID:    mygeometa.GV_UF_DM_field, $
              N2_ID:    mygeometa.GV_UF_N2_field }

  ; Determine how many DPR footprints fall inside the analysis area
   numDPRrays = data_GR2DPR.NUMRAYS

  PRINT, "numDPRrays for ", siteID, " ", numDPRrays
  print, "scan_type ", DPR_scantype
  
  ; Create temp array of DPR (ray, scan) 1-D index locators for in-range points.
  ;   Use flag values of -1 for 'bogus' DPR points (out-of-range DPR footprints
  ;   just adjacent to the first/last in-range point of the scan), or -2 for
  ;   off-DPR-scan-edge but still-in-range points.  These bogus points will then
  ;   totally enclose the set of in-range, in-scan points and allow gridding of
  ;   the in-range dataset to a regular grid using a nearest-neighbor analysis,
  ;   assuring that the bounds of the in-range data are preserved (this gridding
  ;   in not needed or done within the current analysis).
   dpr_master_idx = data_GR2DPR.RAYNUM + data_GR2DPR.SCANNUM*RAYSPERSCAN

  ; Create temp array used to flag whether there are ANY above-threshold DPR bins
  ; in the ray.  If none, we'll skip the time-consuming GR LUT computations.
   dpr_echoes = BYTARR(numDPRrays)
   dpr_echoes[*] = 0B             ; initialize to zero (skip the DPR ray)

   for ifp = 0, numDPRrays-1 do begin
      ray_num = data_GR2DPR.RAYNUM[ifp]
      scan_num = data_GR2DPR.SCANNUM[ifp]
	   ; determine whether the DPR ray has any bins above the dBZ threshold
	   ; - look at corrected Z between 0.75 and 19.25 km, and
           ;   use the above-threshold bin counting in get_dpr_layer_average()
      topCorrGate = 0 & botmCorrGate = 0
      topCorrGate = dpr_gate_num_for_height( 19.25, GATE_SPACE,  $
                       cos_inc_angle, ray_num, scan_num, binEllipsoid )
      botmCorrGate = dpr_gate_num_for_height( 0.75, GATE_SPACE,  $
                        cos_inc_angle, ray_num, scan_num, binEllipsoid )
      dbz_ray_avg = get_dpr_layer_average(topCorrGate, botmCorrGate,   $
                       scan_num, ray_num, dbz_corr, DBZSCALECORR, $
                       DPR_DBZ_MIN, numDPRgates )
      IF ( numDPRgates GT 0 ) THEN dpr_echoes[ifp] = 1B
   endfor

  ; end of DPR GEO-preprocessing

  ; ============================================================================

  ; Initialize and/or populate data fields to be written to the netCDF file.
  ; NOTE WE DON'T SAVE THE SURFACE X,Y FOOTPRINT CENTERS AND CORNERS TO NETCDF

   IF ( numDPRrays GT 0 ) THEN BEGIN
     ; Trim the dpr_master_idx, lat/lon temp arrays and x,y corner arrays down
     ;   to numDPRrays elements in that dimension, in prep. for writing to netCDF
     ;    -- these elements are complete, data-wise
      tocdf_pr_idx = dpr_master_idx
      tocdf_x_poly = data_GR2DPR.XCORNERS
      tocdf_y_poly = data_GR2DPR.YCORNERS
      tocdf_lat = data_GR2DPR.LATITUDE
      tocdf_lon = data_GR2DPR.LONGITUDE
      tocdf_lat_sfc = data_GR2DPR.DPRLATITUDE
      tocdf_lon_sfc = data_GR2DPR.DPRLONGITUDE

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
      
      ; TAB 9/30/20 
      tocdf_pwat_integ_liquid = MAKE_ARRAY(numDPRrays, /float, VALUE=FLOAT_RANGE_EDGE)
      tocdf_pwat_integ_solid = MAKE_ARRAY(numDPRrays, /float, VALUE=FLOAT_RANGE_EDGE)
      tocdf_heightZeroDeg = MAKE_ARRAY(numDPRrays, /float, VALUE=FLOAT_RANGE_EDGE)

     ; Create new subarrays of dimensions (numDPRrays, num_elevations_out) for each
     ;   3-D science and status variable: 
      tocdf_gr_dbz = data_GR2DPR.GR_Z
      tocdf_gr_stddev = data_GR2DPR.GR_Z_STDDEV
      tocdf_gr_max = data_GR2DPR.GR_Z_MAX
      tocdf_gr_rc = data_GR2DPR.GR_RC_RAINRATE
      tocdf_gr_rc_stddev = data_GR2DPR.GR_RC_RAINRATE_STDDEV
      tocdf_gr_rc_max = data_GR2DPR.GR_RC_RAINRATE_MAX
      tocdf_gr_rp = data_GR2DPR.GR_RP_RAINRATE
      tocdf_gr_rp_stddev = data_GR2DPR.GR_RP_RAINRATE_STDDEV
      tocdf_gr_rp_max = data_GR2DPR.GR_RP_RAINRATE_MAX
      tocdf_gr_rr = data_GR2DPR.GR_RR_RAINRATE
      tocdf_gr_rr_stddev = data_GR2DPR.GR_RR_RAINRATE_STDDEV
      tocdf_gr_rr_max = data_GR2DPR.GR_RR_RAINRATE_MAX
      tocdf_gr_zdr = data_GR2DPR.GR_ZDR
      tocdf_gr_zdr_stddev = data_GR2DPR.GR_ZDR_STDDEV
      tocdf_gr_zdr_max = data_GR2DPR.GR_ZDR_MAX
      tocdf_gr_kdp = data_GR2DPR.GR_KDP
      tocdf_gr_kdp_stddev = data_GR2DPR.GR_KDP_STDDEV
      tocdf_gr_kdp_max = data_GR2DPR.GR_KDP_MAX
      tocdf_gr_rhohv = data_GR2DPR.GR_RHOHV
      tocdf_gr_rhohv_stddev = data_GR2DPR.GR_RHOHV_STDDEV
      tocdf_gr_rhohv_max = data_GR2DPR.GR_RHOHV_MAX
      tocdf_gr_HID = data_GR2DPR.GR_HID
      tocdf_gr_Dzero = data_GR2DPR.GR_DZERO
      tocdf_gr_Dzero_stddev = data_GR2DPR.GR_DZERO_STDDEV
      tocdf_gr_Dzero_max = data_GR2DPR.GR_DZERO_MAX
      tocdf_gr_Nw = data_GR2DPR.GR_NW
      tocdf_gr_Nw_stddev = data_GR2DPR.GR_NW_STDDEV
      tocdf_gr_Nw_max = data_GR2DPR.GR_NW_MAX
      tocdf_gr_Dm = data_GR2DPR.GR_DM
      tocdf_gr_Dm_stddev = data_GR2DPR.GR_DM_STDDEV
      tocdf_gr_Dm_max = data_GR2DPR.GR_DM_MAX
      tocdf_gr_N2 = data_GR2DPR.GR_N2
      tocdf_gr_N2_stddev = data_GR2DPR.GR_N2_STDDEV
      tocdf_gr_N2_max = data_GR2DPR.GR_N2_MAX
      tocdf_gr_blockage = data_GR2DPR.GR_BLOCKAGE
      tocdf_gr_swedp = data_GR2DPR.GR_SWEDP
      tocdf_gr_swedp_stddev = data_GR2DPR.GR_SWEDP_STDDEV
      tocdf_gr_swedp_max = data_GR2DPR.GR_SWEDP_MAX
      tocdf_gr_swe25 = data_GR2DPR.GR_SWE25
      tocdf_gr_swe25_stddev = data_GR2DPR.GR_SWE25_STDDEV
      tocdf_gr_swe25_max = data_GR2DPR.GR_SWE25_MAX
      tocdf_gr_swe50 = data_GR2DPR.GR_SWE50
      tocdf_gr_swe50_stddev = data_GR2DPR.GR_SWE50_STDDEV
      tocdf_gr_swe50_max = data_GR2DPR.GR_SWE50_MAX
      tocdf_gr_swe75 = data_GR2DPR.GR_SWE75
      tocdf_gr_swe75_stddev = data_GR2DPR.GR_SWE75_STDDEV
      tocdf_gr_swe75_max = data_GR2DPR.GR_SWE75_MAX
      tocdf_gr_swemqt = data_GR2DPR.GR_SWEMQT
      tocdf_gr_swemqt_stddev = data_GR2DPR.GR_SWEMQT_STDDEV
      tocdf_gr_swemqt_max = data_GR2DPR.GR_SWEMQT_MAX
      tocdf_gr_swemrms = data_GR2DPR.GR_SWEMRMS
      tocdf_gr_swemrms_stddev = data_GR2DPR.GR_SWEMRMS_STDDEV
      tocdf_gr_swemrms_max = data_GR2DPR.GR_SWEMRMS_MAX
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
      tocdf_top_hgt = data_GR2DPR.TOPHEIGHT
      tocdf_botm_hgt = data_GR2DPR.BOTTOMHEIGHT
      tocdf_gr_rejected = data_GR2DPR.N_GR_Z_REJECTED
      tocdf_gr_rc_rejected = data_GR2DPR.N_GR_RC_REJECTED
      tocdf_gr_rp_rejected = data_GR2DPR.N_GR_RP_REJECTED
      tocdf_gr_rr_rejected = data_GR2DPR.N_GR_RR_REJECTED
      tocdf_gr_zdr_rejected = data_GR2DPR.N_GR_ZDR_REJECTED
      tocdf_gr_kdp_rejected = data_GR2DPR.N_GR_KDP_REJECTED
      tocdf_gr_rhohv_rejected = data_GR2DPR.N_GR_RHOHV_REJECTED
      tocdf_gr_hid_rejected = data_GR2DPR.N_GR_HID_REJECTED
      tocdf_gr_dzero_rejected = data_GR2DPR.N_GR_DZERO_REJECTED
      tocdf_gr_nw_rejected = data_GR2DPR.N_GR_NW_REJECTED
      tocdf_gr_dm_rejected = data_GR2DPR.N_GR_DM_REJECTED
      tocdf_gr_n2_rejected = data_GR2DPR.N_GR_N2_REJECTED
      tocdf_gr_expected = data_GR2DPR.N_GR_EXPECTED
      tocdf_gr_swedp_rejected = data_GR2DPR.N_GR_SWEDP_REJECTED
      tocdf_gr_swe25_rejected = data_GR2DPR.N_GR_SWE25_REJECTED
      tocdf_gr_swe50_rejected = data_GR2DPR.N_GR_SWE50_REJECTED
      tocdf_gr_swe75_rejected = data_GR2DPR.N_GR_SWE75_REJECTED
      tocdf_gr_swemqt_rejected = data_GR2DPR.N_GR_SWEMQT_REJECTED
      tocdf_gr_swemrms_rejected = data_GR2DPR.N_GR_SWEMRMS_REJECTED
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
;      if countprgood eq 0L then print," **** no valid footprints **** "
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
         tocdf_rayNum = data_GR2DPR.RAYNUM
         tocdf_scanNum = data_GR2DPR.SCANNUM
         
         ; TAB 9/30/20 
      	 tocdf_pwat_integ_liquid[prgoodidx] = pwat_integ_liquid[pr_idx_2get]
      	 tocdf_pwat_integ_solid[prgoodidx] = pwat_integ_solid[pr_idx_2get]
      	 tocdf_heightZeroDeg[prgoodidx] = heightZeroDeg[pr_idx_2get]
         
     ENDIF ELSE BEGIN
         PRINT, ""
         PRINT, "No valid (non zero) DPR footprints found for ", siteID, ", skipping."
         PRINT, ""
         GOTO, nextGRfile
   	 ENDELSE

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
         
         ; TAB 9/30/20
         tocdf_pwat_integ_liquid[predgeidx] = FLOAT_OFF_EDGE
      	 tocdf_pwat_integ_solid[predgeidx] = FLOAT_OFF_EDGE
      	 tocdf_heightZeroDeg[predgeidx] = FLOAT_OFF_EDGE
         
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


;  >>>>>>>>>>>>>> BEGINNING OF DPR-GR VOLUME MATCHING, ALL SWEEPS <<<<<<<<<<<<<<<

  ; Map this GR radar's data to these DPR footprints, where DPR rays
  ; intersect the elevation sweeps

   FOR ielev = 0, num_elevations_out - 1 DO BEGIN
      print, ""
      print, "Elevation: ", tocdf_elev_angle[ielev]

     ; =========================================================================
     ; COMPUTE THE DPR AND GR REFLECTIVITY AND 3D RAIN RATE AVERAGES

     ; The LUTs are complete for this sweep, now do the resampling/averaging.
     ; Build the DPR-GR intersection "data cone" for the sweep, in DPR coordinates
     ; (horizontally) and within the vertical layer defined by the GV radar
     ; beam top/bottom:

      FOR jpr=0, numDPRrays-1 DO BEGIN
        ; init output variables defined/set in loop/if
         writeMISSING = 1
         dpr_gates_expected = 0UL      ; # DPR gates within the sweep vert. bounds
         n_meas_zgates_rejected = 0UL  ; # of above that are below DPR dBZ cutoff
         n_corr_zgates_rejected = 0UL  ; ditto, for corrected DPR Z
         n_corr_rgates_rejected = 0UL  ; # gates below DPR rainrate cutoff
         n_epsilon_gates_rejected = 0UL  ; # gates with missing epsilon
         n_dpr_dm_gates_rejected = 0UL  ; # gates with missing Dm
         n_dpr_nw_gates_rejected = 0UL  ; # gates with missing Nw
         clutterStatus = 0UL           ; result of clutter proximity for volume

         dpr_index = dpr_master_idx[jpr]
         crankem = (dpr_echoes[jpr] NE 0B) AND $
                   (data_GR2DPR.TOPHEIGHT[jpr,ielev] GT 0.0) AND $
                   (data_GR2DPR.BOTTOMHEIGHT[jpr,ielev] GT 0.0)

         IF ( dpr_index GE 0 AND crankem ) THEN BEGIN
              writeMissing = 0
              raydpr = data_GR2DPR.RAYNUM[jpr]
              scandpr = data_GR2DPR.SCANNUM[jpr]

              ; compute height above ellipsoid for computing DPR gates that
              ; intersect the GR beam boundaries.  Assume ellipsoid and geoid
              ; (MSL surface) are the same
               meantopMSL = data_GR2DPR.TOPHEIGHT[jpr,ielev] + siteElev
               meanbotmMSL = data_GR2DPR.BOTTOMHEIGHT[jpr,ielev] + siteElev

              ; find DPR reflectivity gate #s bounding the top/bottom heights
               topMeasGate = 0 & botmMeasGate = 0
               topCorrGate = 0 & botmCorrGate = 0
               topCorrGate = dpr_gate_num_for_height(meantopMSL, GATE_SPACE,  $
                             cos_inc_angle, raydpr, scandpr, binEllipsoid)
               topMeasGate=topCorrGate
               botmCorrGate = dpr_gate_num_for_height(meanbotmMSL, GATE_SPACE, $
                              cos_inc_angle, raydpr, scandpr, binEllipsoid)
               botmMeasGate=botmCorrGate

              ; number of DPR gates to be averaged in the vertical:
               dpr_gates_expected = botmCorrGate - topCorrGate + 1

              ; do layer averaging for 3-D DPR fields
               numDPRgates = 0
               dbz_meas_avg = get_dpr_layer_average(           $
                                    topMeasGate, botmMeasGate, $
                                    scandpr, raydpr, dbz_meas, $
                                    DBZSCALEMEAS, dpr_dbz_min, $
                                    numDPRgates, binClutterFreeBottom, $
                                    CLUTTERFLAG=clutterFlag, /LOGAVG )
               n_meas_zgates_rejected = dpr_gates_expected - numDPRgates

               numDPRgates = 0
               clutterStatus = 0  ; get once for all 3 fields, same value applies
               dbz_corr_avg = get_dpr_layer_average(           $
                                    topCorrGate, botmCorrGate, $
                                    scandpr, raydpr, dbz_corr, $
                                    DBZSCALECORR, dpr_dbz_min, $
                                    numDPRgates, binClutterFreeBottom, $
                                    CLUTTERFLAG=clutterFlag, clutterStatus, $
                                    /LOGAVG )
               n_corr_zgates_rejected = dpr_gates_expected - numDPRgates

;               IF clutterStatus GE 10 $
;                  THEN print, "Clutter found at level,ray,scan ", ielev, raydpr, scandpr

               IF DO_RAIN_CORR THEN BEGIN
                  numDPRgates = 0
                  rain_corr_avg = get_dpr_layer_average(           $
                                    topCorrGate, botmCorrGate,  $
                                    scandpr, raydpr, rain_corr, $
                                    RAINSCALE, dpr_rain_min, $
                                    numDPRgates, binClutterFreeBottom, $
                                    CLUTTERFLAG=clutterFlag )
                  n_corr_rgates_rejected = dpr_gates_expected - numDPRgates
               ENDIF ELSE BEGIN
                  ; we have no rain_corr field for this instrument/swath
                  rain_corr_avg = Z_MISSING
                  n_corr_rgates_rejected = dpr_gates_expected
               ENDELSE

               numDPRgates = 0
               epsilon_avg = get_dpr_layer_average( topCorrGate, botmCorrGate, $
                                                    scandpr, raydpr, epsilon, $
                                                    1.0, 0.0,  numDPRgates, $
                                                    binClutterFreeBottom )
               n_epsilon_gates_rejected = dpr_gates_expected - numDPRgates

               IF ( have_paramdsd ) THEN BEGIN
                  numDPRgates = 0
                  dpr_dm_avg = get_dpr_layer_average(                   $
                                     topMeasGate, botmMeasGate,         $
                                     scandpr, raydpr, dpr_Dm, 1.0, 0.1, $
                                     numDPRgates, binClutterFreeBottom, $
                                     CLUTTERFLAG=clutterFlag )
                  n_dpr_dm_gates_rejected = dpr_gates_expected - numDPRgates

                  numDPRgates = 0
                  dpr_nw_avg = get_dpr_layer_average(                   $
                                     topMeasGate, botmMeasGate,         $
                                     scandpr, raydpr, dpr_Nw, 1.0, 1.0, $
                                     numDPRgates, binClutterFreeBottom, $
                                     CLUTTERFLAG=clutterFlag )
                  n_dpr_nw_gates_rejected = dpr_gates_expected - numDPRgates
               ENDIF
         ENDIF ELSE BEGIN          ; dpr_index GE 0 AND dpr_echoes[jpr] NE 0B
           ; case where no corr DPR gates in the ray are above dBZ threshold,
           ; or sample heights are undefined due to no valid GR bins, set
           ; averages to BELOW_THRESH special value
            IF ( dpr_index GE 0 AND crankem EQ 0 ) THEN BEGIN
               writeMissing = 0
               dbz_meas_avg = Z_BELOW_THRESH
               dbz_corr_avg = Z_BELOW_THRESH
               rain_corr_avg = SRAIN_BELOW_THRESH
               epsilon_avg = Z_BELOW_THRESH
               IF ( have_paramdsd ) THEN BEGIN
                  dpr_dm_avg = Z_BELOW_THRESH
                  dpr_nw_avg = Z_BELOW_THRESH
               ENDIF
               ;meantop = 0.0    ; should calculate something for this
               ;meanbotm = 0.0   ; ditto
            ENDIF
         ENDELSE          ; ELSE for dpr_index GE 0 AND dpr_echoes[jpr] NE 0B

     ; =========================================================================
     ; WRITE COMPUTED AVERAGES AND METADATA TO OUTPUT ARRAYS FOR NETCDF

         IF ( writeMissing EQ 0 )  THEN BEGIN
         ; normal rainy footprint, write computed science variables
                  tocdf_meas_dbz[jpr,ielev] = dbz_meas_avg
                  tocdf_corr_dbz[jpr,ielev] = dbz_corr_avg
                  tocdf_corr_rain[jpr,ielev] = rain_corr_avg
                  tocdf_epsilon[jpr,ielev] = epsilon_avg
                  IF ( have_paramdsd ) THEN BEGIN
                     tocdf_dm[jpr,ielev] = dpr_dm_avg
                     tocdf_nw[jpr,ielev] = dpr_nw_avg
                  ENDIF
         ENDIF ELSE BEGIN
            CASE dpr_index OF
                -1  :  BREAK
                      ; is range-edge point, science values in array were already
                      ;   initialized to special values for this, so do nothing
                -2  :  BEGIN
                      ; off-scan-edge point, set science values to special values
                          tocdf_meas_dbz[jpr,ielev] = FLOAT_OFF_EDGE
                          tocdf_corr_dbz[jpr,ielev] = FLOAT_OFF_EDGE
                          tocdf_corr_rain[jpr,ielev] = FLOAT_OFF_EDGE
                          tocdf_epsilon[jpr,ielev] = FLOAT_OFF_EDGE
                          tocdf_dm[jpr,ielev] = FLOAT_OFF_EDGE
                          tocdf_nw[jpr,ielev] = FLOAT_OFF_EDGE
                       END
              ELSE  :  BEGIN
                      ; data internal issues, set science values to missing
                          tocdf_meas_dbz[jpr,ielev] = Z_MISSING
                          tocdf_corr_dbz[jpr,ielev] = Z_MISSING
                          tocdf_corr_rain[jpr,ielev] = Z_MISSING
                          tocdf_epsilon[jpr,ielev] = Z_MISSING
                          tocdf_dm[jpr,ielev] = Z_MISSING
                          tocdf_nw[jpr,ielev] = Z_MISSING
                       END
            ENDCASE
         ENDELSE

        ; assign the computed meta values to the output array slots
         tocdf_meas_z_rejected[jpr,ielev] = UINT(n_meas_zgates_rejected)
         tocdf_corr_z_rejected[jpr,ielev] = UINT(n_corr_zgates_rejected)
         tocdf_corr_r_rejected[jpr,ielev] = UINT(n_corr_rgates_rejected)
         tocdf_epsilon_rejected[jpr,ielev] = UINT(n_epsilon_gates_rejected)
         IF ( have_paramdsd ) THEN BEGIN
            tocdf_dpr_dm_rejected[jpr,ielev] = UINT(n_dpr_dm_gates_rejected)
            tocdf_dpr_nw_rejected[jpr,ielev] = UINT(n_dpr_nw_gates_rejected)
         ENDIF
         tocdf_dpr_expected[jpr,ielev] = UINT(dpr_gates_expected)
         tocdf_clutterStatus[jpr,ielev] = UINT(clutterStatus)

      ENDFOR  ; each DPR subarray point: jpr=0, numDPRrays-1

     ; END OF DPR-TO-GR RESAMPLING, THIS SWEEP

     ; =========================================================================

    ; *********** OPTIONAL PPI PLOTTING FOR SWEEP **********

      IF keyword_set(plot_PPIs) THEN BEGIN
         titlepr = 'DPR at ' + dpr_dtime + ' UTC'
         titlegv = siteID+', Elevation = '$
                   + STRING(tocdf_elev_angle[ielev],FORMAT='(f4.1)') $
                   +', '+ mysweeps[ielev].ATIMESWEEPSTART
         titles = [titlepr, titlegv]

         plot_elevation_gv_to_pr_z, tocdf_corr_dbz, tocdf_gr_dbz, sitelat, $
            sitelon, tocdf_x_poly, tocdf_y_poly, numDPRrays, ielev, TITLES=titles

       ; if restricting plot to the 'best' DPR and GR sample points
         ;plot_elevation_gv_to_pr_z, tocdf_corr_dbz*(tocdf_corr_z_rejected EQ 0), $
         ;   tocdf_gr_dbz*(tocdf_gr_dbz GE dpr_dbz_min)*(tocdf_gr_rejected EQ 0), $
         ;   sitelat, sitelon, tocdf_x_poly, tocdf_y_poly, numDPRrays, ielev, TITLES=titles

       ; to plot a full-res radar PPI for this elevation sweep:
         ;rsl_plotsweep_from_radar, radar, ELEVATION=elev_angle[ielev], $
         ;                          VOLUME_INDEX=z_vol_num, /NEW_WINDOW, MAXRANGE=200
         ;stop
      ENDIF

     ; =========================================================================

   ENDFOR     ; each elevation sweep: ielev = 0, num_elevations_out - 1

;  >>>>>>>>>>>>>>>>> END OF DPR-GR VOLUME MATCHING, ALL SWEEPS <<<<<<<<<<<<<<<<<<

;  OPTIONAL SCORE COMPUTATIONS, ALL SWEEPS COMBINED
   IF keyword_set(run_scores) THEN BEGIN
      ; overall scores, all sweeps
      print, ""
      print, "All Sweeps Combined:"
      idxBBdef = WHERE( tocdf_BB_Hgt GT 0.0 AND tocdf_rainType EQ 1, countBBdef )
      IF countBBdef GT 0 THEN BEGIN
       ; convert bright band heights from m to km, where defined, and get mean BB hgt
       ; first, find the indices of stratiform rays with BB defined
        bb2hist = tocdf_BB_Hgt[idxBBdef]/1000.  ; with conversion to km
        bs=0.2  ; bin width, in km, for HISTOGRAM in get_mean_bb_height()
       ; do some sorcery to find the best mean BB height estimate, in km
        meanbb = get_mean_bb_height( bb2hist, BS=bs, HIST_WINDOW=hist_window )
        print, "MEAN BB (km): ", meanBB
      ENDIF ELSE print, "No stratiform points with BB defined."
      print, ""
      IF countBBdef GT 0 THEN BEGIN
         idx2score = WHERE( tocdf_corr_z_rejected EQ 0 $
                       AND  tocdf_gr_rejected EQ 0     $
                       AND  tocdf_dpr_expected GT 0     $
                       AND  tocdf_top_hgt LT meanBB-0.75, count2score )
         IF count2score gt 0 THEN BEGIN
            print, "BELOW BB Mean DPR-GR, Npts: ", MEAN( tocdf_corr_dbz[idx2score] $
                                      - tocdf_gr_dbz[idx2score] ), count2score
         ENDIF
         idx2score = WHERE( tocdf_corr_z_rejected EQ 0 $
                       AND  tocdf_gr_rejected EQ 0     $
                       AND  tocdf_dpr_expected GT 0     $
                       AND  tocdf_botm_hgt GT meanBB+0.75, count2score )
         IF count2score gt 0 THEN BEGIN
            print, "ABOVE BB Mean DPR-GR, Npts: ", MEAN( tocdf_corr_dbz[idx2score] $
                                      - tocdf_gr_dbz[idx2score] ), count2score
         ENDIF
      ENDIF ELSE BEGIN
         idx2score = WHERE( tocdf_corr_z_rejected EQ 0 $
                       AND  tocdf_gr_rejected EQ 0     $
                       AND  tocdf_dpr_expected GT 0, count2score )
;      print, "Points with no regard to mean BB:"
         IF count2score gt 0 THEN BEGIN
         print, "Mean DPR-GR, Npts: ", MEAN(tocdf_corr_dbz[idx2score] $
                                   - tocdf_gr_dbz[idx2score]), count2score
         ENDIF ELSE BEGIN
            print, "Mean DPR-GR: no points meet criteria."
         ENDELSE
      ENDELSE

      PRINT, ""
      PRINT, "End of scores/processing for ", siteID
      PRINT, ""
   ENDIF  ; run_scores

   ; ************ END OPTIONAL SCORE COMPUTATIONS, ALL SWEEPS *****************

  ; ============================================================================

  ; Create a netCDF file with the proper 'numDPRrays' and 'num_elevations_out'
  ; dimensions, also passing the global attribute values along
   ncfile = gen_dpr_geo_match_netcdf_v7( fname_netCDF, numDPRrays, $
                                      tocdf_elev_angle, ufstruct, $
                                      DPR_scantype, DPR_version, $
;                                      DPR_scantype, DPR_version, $
                                      siteID, infileNameArr, $
                                      DECLUTTERED=decluttered, $
                                      NON_PPS_FILES=non_pps_files )

   IF ( fname_netCDF EQ "NoGeoMatchFile" ) THEN BEGIN
      message, "IDL Error Exit: Error in creating output netCDF file "+fname_netCDF, /INFO
      goto, bailOut
   ENDIF

  ; Open the netCDF file and write the completed field values to it
   ncid = NCDF_OPEN( ncfile, /WRITE )

  ; Write the scalar values to the netCDF file

   NCDF_VARPUT, ncid, 'site_ID', siteID
   NCDF_VARPUT, ncid, 'site_lat', siteLat
   NCDF_VARPUT, ncid, 'site_lon', siteLon
   NCDF_VARPUT, ncid, 'site_elev', siteElev
   NCDF_VARPUT, ncid, 'timeNearestApproach', dpr_dtime_ticks
   NCDF_VARPUT, ncid, 'atimeNearestApproach', dpr_dtime
   NCDF_VARPUT, ncid, 'timeSweepStart', mysweeps[*].TIMESWEEPSTART
   NCDF_VARPUT, ncid, 'atimeSweepStart', mysweeps[*].ATIMESWEEPSTART
   NCDF_VARPUT, ncid, 'rangeThreshold', mygeometa.RANGETHRESHOLD
   NCDF_VARPUT, ncid, 'DPR_dBZ_min', DPR_DBZ_MIN
   NCDF_VARPUT, ncid, 'GR_dBZ_min', mygeometa.GR_dBZ_min
   NCDF_VARPUT, ncid, 'rain_min', DPR_RAIN_MIN
   NCDF_VARPUT, ncid, 'numScans', SAMPLE_RANGE
   NCDF_VARPUT, ncid, 'numRays', RAYSPERSCAN

;  Write single-level results/flags to netcdf file

   NCDF_VARPUT, ncid, 'DPRlatitude', tocdf_lat_sfc
   NCDF_VARPUT, ncid, 'DPRlongitude', tocdf_lon_sfc
   NCDF_VARPUT, ncid, 'LandSurfaceType', tocdf_landocean
    NCDF_VARPUT, ncid, 'have_LandSurfaceType', DATA_PRESENT
   NCDF_VARPUT, ncid, 'PrecipRateSurface', tocdf_corr_srain
    NCDF_VARPUT, ncid, 'have_PrecipRateSurface', DATA_PRESENT
   IF ( havefile2bcmb EQ 1 ) THEN BEGIN
      NCDF_VARPUT, ncid, 'SurfPrecipTotRate', tocdf_2bcmb_srain
       NCDF_VARPUT, ncid, 'have_SurfPrecipTotRate', DATA_PRESENT
   ENDIF
   NCDF_VARPUT, ncid, 'piaFinal', tocdf_piaFinal
    NCDF_VARPUT, ncid, 'have_piaFinal', DATA_PRESENT
   NCDF_VARPUT, ncid, 'BBheight', tocdf_BB_Hgt
    NCDF_VARPUT, ncid, 'have_BBheight', DATA_PRESENT
   NCDF_VARPUT, ncid, 'FlagPrecip', tocdf_rainflag
    NCDF_VARPUT, ncid, 'have_FlagPrecip', DATA_PRESENT
   NCDF_VARPUT, ncid, 'TypePrecip', tocdf_raintype
    NCDF_VARPUT, ncid, 'have_TypePrecip', DATA_PRESENT
   NCDF_VARPUT, ncid, 'heightStormTop', tocdf_heightStormTop
    NCDF_VARPUT, ncid, 'have_heightStormTop', DATA_PRESENT
;   NCDF_VARPUT, ncid, 'rayIndex', tocdf_pr_idx
   NCDF_VARPUT, ncid, 'rayNum', tocdf_rayNum
   NCDF_VARPUT, ncid, 'scanNum', tocdf_scanNum
   NCDF_VARPUT, ncid, 'BBstatus', tocdf_BBstatus
     NCDF_VARPUT, ncid, 'have_BBstatus', DATA_PRESENT
   NCDF_VARPUT, ncid, 'qualityData', tocdf_qualityData       ; data
    NCDF_VARPUT, ncid, 'have_qualityData', DATA_PRESENT    ; data presence flag
    
   ; TAB 9/30/20
   NCDF_VARPUT, ncid, 'pwatIntegrated_liquid', tocdf_pwat_integ_liquid
   NCDF_VARPUT, ncid, 'pwatIntegrated_solid', tocdf_pwat_integ_solid   
    NCDF_VARPUT, ncid, 'have_pwatIntegrated', DATA_PRESENT    ; data presence flag

   NCDF_VARPUT, ncid, 'heightZeroDeg', tocdf_heightZeroDeg       ; data
    NCDF_VARPUT, ncid, 'have_heightZeroDeg', DATA_PRESENT    ; data presence flag

;  Write sweep-level results/flags to netcdf file & close it up

   NCDF_VARPUT, ncid, 'latitude', tocdf_lat
   NCDF_VARPUT, ncid, 'longitude', tocdf_lon
   NCDF_VARPUT, ncid, 'xCorners', tocdf_x_poly
   NCDF_VARPUT, ncid, 'yCorners', tocdf_y_poly

   NCDF_VARPUT, ncid, 'GR_Z', tocdf_gr_dbz
    NCDF_VARPUT, ncid, 'have_GR_Z', myflags.HAVE_THREEDREFLECT
   NCDF_VARPUT, ncid, 'GR_Z_StdDev', tocdf_gr_stddev
   NCDF_VARPUT, ncid, 'GR_Z_Max', tocdf_gr_max

   NCDF_VARPUT, ncid, 'GR_RC_rainrate', tocdf_gr_rc
    NCDF_VARPUT, ncid, 'have_GR_RC_rainrate', myflags.HAVE_GR_RC_RAINRATE
   NCDF_VARPUT, ncid, 'GR_RC_rainrate_StdDev', tocdf_gr_rc_stddev
   NCDF_VARPUT, ncid, 'GR_RC_rainrate_Max', tocdf_gr_rc_max

   NCDF_VARPUT, ncid, 'GR_RP_rainrate', tocdf_gr_rp
    NCDF_VARPUT, ncid, 'have_GR_RP_rainrate', myflags.HAVE_GR_RP_RAINRATE
   NCDF_VARPUT, ncid, 'GR_RP_rainrate_StdDev', tocdf_gr_rp_stddev
   NCDF_VARPUT, ncid, 'GR_RP_rainrate_Max', tocdf_gr_rp_max

   NCDF_VARPUT, ncid, 'GR_RR_rainrate', tocdf_gr_rr
    NCDF_VARPUT, ncid, 'have_GR_RR_rainrate', myflags.HAVE_GR_RR_RAINRATE
   NCDF_VARPUT, ncid, 'GR_RR_rainrate_StdDev', tocdf_gr_rr_stddev
   NCDF_VARPUT, ncid, 'GR_RR_rainrate_Max', tocdf_gr_rr_max

   NCDF_VARPUT, ncid, 'GR_Zdr', tocdf_gr_zdr
    NCDF_VARPUT, ncid, 'have_GR_Zdr', myflags.HAVE_GR_ZDR
   NCDF_VARPUT, ncid, 'GR_Zdr_StdDev', tocdf_gr_zdr_stddev
   NCDF_VARPUT, ncid, 'GR_Zdr_Max', tocdf_gr_zdr_max

   NCDF_VARPUT, ncid, 'GR_Kdp', tocdf_gr_kdp
    NCDF_VARPUT, ncid, 'have_GR_Kdp', myflags.HAVE_GR_KDP
   NCDF_VARPUT, ncid, 'GR_Kdp_StdDev', tocdf_gr_kdp_stddev
   NCDF_VARPUT, ncid, 'GR_Kdp_Max', tocdf_gr_kdp_max

   NCDF_VARPUT, ncid, 'have_GR_SWE', myflags.HAVE_GR_SWE
   NCDF_VARPUT, ncid, 'GR_SWEDP', tocdf_gr_swedp
   NCDF_VARPUT, ncid, 'GR_SWEDP_StdDev', tocdf_gr_swedp_stddev
   NCDF_VARPUT, ncid, 'GR_SWEDP_Max', tocdf_gr_swedp_max
   NCDF_VARPUT, ncid, 'GR_SWE25', tocdf_gr_swe25
   NCDF_VARPUT, ncid, 'GR_SWE25_StdDev', tocdf_gr_swe25_stddev
   NCDF_VARPUT, ncid, 'GR_SWE25_Max', tocdf_gr_swe25_max
   NCDF_VARPUT, ncid, 'GR_SWE50', tocdf_gr_swe50
   NCDF_VARPUT, ncid, 'GR_SWE50_StdDev', tocdf_gr_swe50_stddev
   NCDF_VARPUT, ncid, 'GR_SWE50_Max', tocdf_gr_swe50_max
   NCDF_VARPUT, ncid, 'GR_SWE75', tocdf_gr_swe75
   NCDF_VARPUT, ncid, 'GR_SWE75_StdDev', tocdf_gr_swe75_stddev
   NCDF_VARPUT, ncid, 'GR_SWE75_Max', tocdf_gr_swe75_max
   NCDF_VARPUT, ncid, 'GR_SWEMQT', tocdf_gr_swemqt
   NCDF_VARPUT, ncid, 'GR_SWEMQT_StdDev', tocdf_gr_swemqt_stddev
   NCDF_VARPUT, ncid, 'GR_SWEMQT_Max', tocdf_gr_swemqt_max
   NCDF_VARPUT, ncid, 'GR_SWEMRMS', tocdf_gr_swemrms
   NCDF_VARPUT, ncid, 'GR_SWEMRMS_StdDev', tocdf_gr_swemrms_stddev
   NCDF_VARPUT, ncid, 'GR_SWEMRMS_Max', tocdf_gr_swemrms_max

   NCDF_VARPUT, ncid, 'GR_RHOhv', tocdf_gr_rhohv
    NCDF_VARPUT, ncid, 'have_GR_RHOhv', myflags.HAVE_GR_RHOHV
   NCDF_VARPUT, ncid, 'GR_RHOhv_StdDev', tocdf_gr_rhohv_stddev
   NCDF_VARPUT, ncid, 'GR_RHOhv_Max', tocdf_gr_rhohv_max

   NCDF_VARPUT, ncid, 'GR_HID', tocdf_gr_hid
    NCDF_VARPUT, ncid, 'have_GR_HID', myflags.HAVE_GR_HID

   NCDF_VARPUT, ncid, 'GR_Dzero', tocdf_gr_dzero
    NCDF_VARPUT, ncid, 'have_GR_Dzero', myflags.HAVE_GR_DZERO
   NCDF_VARPUT, ncid, 'GR_Dzero_StdDev', tocdf_gr_dzero_stddev
   NCDF_VARPUT, ncid, 'GR_Dzero_Max', tocdf_gr_dzero_max

   NCDF_VARPUT, ncid, 'GR_Nw', tocdf_gr_nw
    NCDF_VARPUT, ncid, 'have_GR_Nw', myflags.HAVE_GR_NW
   NCDF_VARPUT, ncid, 'GR_Nw_StdDev', tocdf_gr_nw_stddev
   NCDF_VARPUT, ncid, 'GR_Nw_Max', tocdf_gr_nw_max

   NCDF_VARPUT, ncid, 'GR_Dm', tocdf_gr_dm
    NCDF_VARPUT, ncid, 'have_GR_Dm', myflags.HAVE_GR_DM
   NCDF_VARPUT, ncid, 'GR_Dm_StdDev', tocdf_gr_dm_stddev
   NCDF_VARPUT, ncid, 'GR_Dm_Max', tocdf_gr_dm_max

   NCDF_VARPUT, ncid, 'GR_N2', tocdf_gr_n2
    NCDF_VARPUT, ncid, 'have_GR_N2', myflags.HAVE_GR_N2
   NCDF_VARPUT, ncid, 'GR_N2_StdDev', tocdf_gr_n2_stddev
   NCDF_VARPUT, ncid, 'GR_N2_Max', tocdf_gr_n2_max

   NCDF_VARPUT, ncid, 'GR_blockage', tocdf_gr_blockage
    NCDF_VARPUT, ncid, 'have_GR_blockage', myflags.HAVE_GR_BLOCKAGE

   NCDF_VARPUT, ncid, 'ZFactorMeasured', tocdf_meas_dbz
    NCDF_VARPUT, ncid, 'have_ZFactorMeasured', DATA_PRESENT
   NCDF_VARPUT, ncid, 'ZFactorCorrected', tocdf_corr_dbz
    NCDF_VARPUT, ncid, 'have_ZFactorCorrected', DATA_PRESENT
   NCDF_VARPUT, ncid, 'Epsilon', tocdf_Epsilon                  ; data
    NCDF_VARPUT, ncid, 'have_Epsilon', DATA_PRESENT             ; data presence flag
   NCDF_VARPUT, ncid, 'PrecipRate', tocdf_corr_rain
    IF DO_RAIN_CORR THEN NCDF_VARPUT, ncid, 'have_PrecipRate', DATA_PRESENT
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
   NCDF_VARPUT, ncid, 'n_gr_swedp_rejected', tocdf_gr_swedp_rejected
   NCDF_VARPUT, ncid, 'n_gr_swe25_rejected', tocdf_gr_swe25_rejected
   NCDF_VARPUT, ncid, 'n_gr_swe50_rejected', tocdf_gr_swe50_rejected
   NCDF_VARPUT, ncid, 'n_gr_swe75_rejected', tocdf_gr_swe75_rejected
   NCDF_VARPUT, ncid, 'n_gr_swemqt_rejected', tocdf_gr_swemqt_rejected
   NCDF_VARPUT, ncid, 'n_gr_swemrms_rejected', tocdf_gr_swemrms_rejected
   NCDF_VARPUT, ncid, 'n_dpr_meas_z_rejected', tocdf_meas_z_rejected
   NCDF_VARPUT, ncid, 'n_dpr_corr_z_rejected', tocdf_corr_z_rejected
   NCDF_VARPUT, ncid, 'n_dpr_epsilon_rejected', tocdf_epsilon_rejected
   NCDF_VARPUT, ncid, 'n_dpr_corr_r_rejected', tocdf_corr_r_rejected
   IF ( have_paramdsd ) THEN BEGIN
      NCDF_VARPUT, ncid, 'n_dpr_dm_rejected', tocdf_dpr_dm_rejected
      NCDF_VARPUT, ncid, 'n_dpr_nw_rejected', tocdf_dpr_nw_rejected
   ENDIF
   NCDF_VARPUT, ncid, 'n_dpr_expected', tocdf_dpr_expected
   NCDF_VARPUT, ncid, 'clutterStatus', tocdf_clutterStatus
    NCDF_VARPUT, ncid, 'have_clutterStatus', DATA_PRESENT

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
nextOrbit:

print, ""
print, "Done!"

bailOut:

END

;===============================================================================

PRO dpr2gr_prematch_v7, control_file, GPM_ROOT=gpmroot, DIRDPR=dir2adpr, $
                     DIRKU=dir2aku, DIRKA=dir2aka, DIR_GV_NC=dir_gv_nc,  $
                     GR_NC_VERSION=gr_nc_version, VERSION2MATCH=version2match, $
                     PLOT_PPIS=plot_PPIs, SCORES=run_scores, NC_DIR=nc_dir, $
                     FLAT_NCPATH=flat_ncpath, NC_NAME_ADD=ncnameadd, $
                     DPR_DBZ_MIN=dpr_dbz_min, DPR_RAIN_MIN=dpr_rain_min, $
                     NON_PPS_FILES=non_pps_files, DECLUTTER=declutter


; "Include" file for DATA_PRESENT, NO_DATA_PRESENT
@grid_def.inc
; "Include" file for DPR-product-specific parameters (i.e., RAYSPERSCAN):
@dpr_params_v7.inc
; "Include" file for names, paths, etc.:
@environs_v7.inc
; for structures to be read from GR netCDF file
@dpr_geo_match_nc_structs_v7.inc

decluttered = KEYWORD_SET(declutter)

; set to a constant, until database supports DPR product version override values
DPR_version = '0'

;IF N_ELEMENTS(gr_nc_version) EQ 0 THEN grverstr = '1_0' ELSE BEGIN
; 8/30/18 TAB changed default version of grverstr to 1_1
IF N_ELEMENTS(gr_nc_version) EQ 0 THEN grverstr = '2_0' ELSE BEGIN
  ; check whether we have '.' or '_' between the units and decimal places
   IF STRPOS(gr_nc_version, '.') NE -1 THEN BEGIN
     ; substitute an underscore for the decimal point
      verarr=strsplit(string(matchup_file_version,FORMAT='(F0.1)'),'.',/extract)
      grverstr=verarr[0]+'_'+verarr[1]
   ENDIF ELSE BEGIN
      IF STRPOS(gr_nc_version, '_') NE -1 THEN grverstr = gr_nc_version $
      ELSE message, "Cannot parse gr_nc_version value: "+STRING(gr_nc_version)
   ENDELSE
ENDELSE

; ***************************** Local configuration ****************************

; where provided, override file path default values from environs_v7.inc:
in_base_dir = NCGRIDS_ROOT+GR_DPR_GEO_MATCH_NCDIR ; default root dir for GR netCDF
IF N_ELEMENTS(dir_gv_nc) EQ 1 THEN in_base_dir = dir_gv_nc

IF N_ELEMENTS(gpmroot)  EQ 1 THEN GPMDATA_ROOT = gpmroot
IF N_ELEMENTS(dir2adpr) EQ 1 THEN DIR_2ADPR = dir2adpr
IF N_ELEMENTS(dir2aku)  EQ 1 THEN DIR_2AKU = dir2aku
IF N_ELEMENTS(dir2aka)  EQ 1 THEN DIR_2AKA = dir2aka
;IF N_ELEMENTS(dircomb)  EQ 1 THEN DIR_COMB = dircomb
    
IF N_ELEMENTS(nc_dir)  EQ 1 THEN BEGIN
   NCGRIDSOUTDIR = nc_dir
ENDIF ELSE BEGIN
   NCGRIDSOUTDIR = NCGRIDS_ROOT+GEO_MATCH_NCDIR
ENDELSE

; tally number of reflectivity bins below this dBZ value in DPR Z averages
IF N_ELEMENTS(dpr_dbz_min) NE 1 THEN BEGIN
   dpr_dbz_min = 15.0
   PRINT, "Assigning default value of 15 dBZ to DPR_DBZ_MIN."
ENDIF

; tally number of rain rate bins (mm/h) below this value in DPR rr averages
IF N_ELEMENTS(dpr_rain_min) NE 1 THEN BEGIN
   DPR_RAIN_MIN = 0.01
   PRINT, "Assigning default value of 0.01 mm/h to DPR_RAIN_MIN."
ENDIF

; ******************************************************************************

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
   IF N_ELEMENTS(parsed) LT 8 THEN BEGIN
      message, "IDL Error Exit: Incomplete DPR line in control file: "+dataPR, /INFO
      goto, bailOut
   ENDIF

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
  ; DPR_scantype is passed parameter, ignore this field in the control file
   ;DPR_scantype = parsed[6]

  ; determine which PPS Version of GRtoDPR_HS_FS netCDF file to match up
  ; to this 2A file's PPS Version
   IF N_ELEMENTS(version2match) EQ 0 THEN GRtoDPRx3_version=DPR_version $
   ELSE GRtoDPRx3_version=version2match

  ; set up the date/product-specific output filepath
  ; Note we won't use this if the FLAT_NCPATH keyword is set

   matchup_file_version=0.0  ; give it a bogus value, for now
  ; Call gen_geo_match_netcdf with the option to only get current file version
  ; so that it can become part of the matchup file name
   throwaway = gen_dpr_geo_match_netcdf_v7( GEO_MATCH_VERS=matchup_file_version )

  ; separate version into integer and decimal parts, with 2 decimal places
   verarr=strsplit(string(matchup_file_version,FORMAT='(F0.2)'),'.',/extract)
  ; strip trailing zero from version string decimal part, if any
   verarr1_len = STRLEN(verarr[1])
   IF verarr1_len GT 1 and STRMID(verarr[1], verarr1_len-1, 1) EQ '0' $
      THEN verarr[1]=strmid(verarr[1], 0, verarr1_len-1)
  ; substitute an underscore for the decimal point in matchup_file_version
   verstr=verarr[0]+'_'+verarr[1]

  ; generate the GR netcdf matchup file paths
   IF KEYWORD_SET(flat_ncpath) THEN BEGIN
      NC_GR_DIR = in_base_dir
   ENDIF ELSE BEGIN
      NC_GR_DIR = in_base_dir+'/GPM/2ADPR/'+GRtoDPRx3_version+'/'+grverstr+ $
                  '/20'+STRMID(DATESTAMP, 0, 2)  ; 4-digit Year
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
         'DPRX' : origFileDPRName = DPR_filepath
          'Ka' : origFileKaName = DPR_filepath
          'KaX' : origFileKaName = DPR_filepath
          'Ku' : origFileKuName = DPR_filepath
          'KuX' : origFileKuName = DPR_filepath
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
     ; have "non-missing" GR data file names
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
  ;  control file:  version/subset/yyyy/mm/dd/filebasename
;help, GPMDATA_ROOT, DIR_2ADPR
;print, origFileDPRName
   file_2adpr = GPMDATA_ROOT+DIR_2ADPR+"/"+origFileDPRName
   file_2aku  = GPMDATA_ROOT+DIR_2AKU+"/"+origFileKuName
   file_2aka  = GPMDATA_ROOT+DIR_2AKA+"/"+origFileKaName
   file_2bcmb = GPMDATA_ROOT+DIR_COMB+"/"+origFileCMBName

  ; check Instrument_ID, filename, and DPR_scantype consistency
   SWITCH STRUPCASE(Instrument_ID) OF
       'KA' : 
       'KAX' : BEGIN
                 ; do we have a 2AKA filename?
                 IF FILE_BASENAME(origFileKaName) EQ 'no_2AKA_file' THEN BEGIN
                    message, "IDL Error Exit: KA specified on control file line, but no " + $
                             "valid 2A-KA file name: " + dataPR, /INFO
                    goto, bailOut
                 ENDIF
                 ; 2AKA has HS and FS scan/swath types, read them all at once
                 DPR_scans = ['HS', 'FS']
                 print, '' & print, "Reading file: ", file_2aka & print, ''
                 dpr_data = read_2akaku_hdf5_v7(file_2aka)
                 dpr_file_read = origFileKaName
                 break
              END
       'KU' : 
       'KUX' : BEGIN
                 IF FILE_BASENAME(origFileKuName) EQ 'no_2AKU_file' THEN BEGIN
                    message, "IDL Error Exit: KU specified on control file line, but no " + $
                             "valid 2A-KU file name: " + dataPR, /INFO
                    goto, bailOut
                 ENDIF
                 ; 2AKU has only FS scan/swath type
                 DPR_scans = ['FS']
                 print, '' & print, "Reading file: ", file_2aku & print, ''
                 dpr_data = read_2akaku_hdf5_v7(file_2aku)
                 dpr_file_read = origFileKuName
                 break
              END
      'DPR' : 
      'DPRX' : BEGIN
                 IF FILE_BASENAME(origFileDPRName) EQ 'no_2ADPR_file' THEN BEGIN
                    message, "IDL Error Exit: DPR specified on control file line, but no " + $
                             "valid 2ADPR file name: " + dataPR, /INFO
                    goto, bailOut
                 ENDIF
                 ; 2ADPR has all HS and FS scan/swath types, read them all at once
                 DPR_scans = ['HS', 'FS_Ku', 'FS_Ka']
                 print, '' & print, "Reading file: ", file_2adpr & print, ''
                 dpr_data = read_2adpr_hdf5_v7(file_2adpr)
                 dpr_file_read = origFileDPRName
                 break
              END
   ENDSWITCH

   ; check dpr_data structure for read failures
   IF SIZE(dpr_data, /TYPE) NE 8 THEN BEGIN
      message, "IDL Error Exit: Error reading data from: "+dpr_file_read, /INFO
      goto, bailOut
   ENDIF ELSE PRINT, "Extracting data fields from dpr_data structure."
   print, ''

  ; assuming we have valid GR data for one or more sites for this orbit, loop
  ; over these sites, read the GR-only matchup data file, and loop over the
  ; scan types, calling dpr2gr_prematch_scan to produce the merged GRtoDPR
  ; matchup netCDF file for each site/scan

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

     ; adding the default or local path, just to get a fully-qualified file name
     ; (recognizing that in_base_dir does not actually apply here):
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

     ; store the file basenames in a string array to be passed to
     ; gen_dpr_geo_match_netcdf_v7() via dpr2gr_prematch_scan_v7()
      infileNameArr = STRARR(5)
      infileNameArr[0] = FILE_BASENAME(origFileDPRName)
      infileNameArr[1] = FILE_BASENAME(origFileKuName)
      infileNameArr[2] = FILE_BASENAME(origFileKaName)
      infileNameArr[3] = FILE_BASENAME(origFileCMBName)
      infileNameArr[4] = base_1CUF

     ;-----------------------------------------------------------------------------

     ; generate the GR netcdf matchup file path/name CHECK DIRECTORY STRUCTURE!!!
      IF N_ELEMENTS(ncnameadd) EQ 1 THEN BEGIN
         gr_netcdf_file = NC_GR_DIR + '/' + GR_DPR_GEO_MATCH_PRE + siteID + '.' $
                          + DATESTAMP + '.' + orbit + '.' + GRtoDPRx3_version + '.' $
                          + grverstr + '.' + ncnameadd + NC_FILE_EXT
      ENDIF ELSE BEGIN
         gr_netcdf_file = NC_GR_DIR + '/' + GR_DPR_GEO_MATCH_PRE + siteID + '.' $
                          + DATESTAMP + '.' + orbit + '.' + GRtoDPRx3_version + '.' $
                          + grverstr + NC_FILE_EXT
      ENDELSE
     ; look for the file in both .nc and .nc.gz forms
      GRFILES = FILE_SEARCH(gr_netcdf_file + "*")
      IF GRFILES[0] EQ '' THEN BEGIN
         message, "Cannot find GR netCDF file: "+gr_netcdf_file, /INFO
         goto, nextGRfile
         ;goto, bailOut
      ENDIF
      IF N_ELEMENTS(GRFILES) NE 1 THEN BEGIN
         print, ''
         message, "Found multiple matching files, taking first in list:", /INFO
         print, GRFILES & print, ''
      ENDIF
      gr_netcdf_file=GRFILES[0]

     ; READ THE GR-ONLY GEO MATCH netCDF FILE DATA FOR THE DPR SWATH

     ; Get an uncompressed copy of the netCDF file - we never touch the original
      cpstatus = uncomp_file( gr_netcdf_file, ncfile1 )
      if (cpstatus eq 'OK') then begin
         data_HS=1  ; initialize to anything
         data_FS_Ku=1  ; initialize to anything
         data_FS_Ka=1  ; initialize to anything
         mygeometa={ dpr_geo_match_meta }
         mysweeps={ gr_sweep_meta }
         mysite={ gr_site_meta }
         myflags={ dpr_gr_field_flags }
         myfiles={ dpr_gr_input_files }
         CATCH, error
         IF error EQ 0 THEN BEGIN
            status=read_gr_hs_fs_geo_match_netcdf_v7( ncfile1, $
                        matchupmeta=mygeometa, sweepsmeta=mysweeps, $
                        sitemeta=mysite, fieldflags=myflags, $
                        filesmeta=myfiles, DATA_HS=data_HS, $
                        DATA_FS_Ku=data_FS_Ku, DATA_FS_Ka=data_FS_Ka)
         ENDIF ELSE BEGIN
            help,!error_state,/st
            Catch, /Cancel
            message, 'err='+STRING(error)+", "+!error_state.msg, /INFO
            status=1   ;return, -1
         ENDELSE
         Catch, /Cancel

        ; remove the uncompressed file copy
         command3 = "rm -v " + ncfile1
         spawn, command3
         ; TAB 9/18/18 changed this to continue to next GR file instead of bailing
         IF (status EQ 1) then GOTO, nextGRfile
;         IF (status EQ 1) then GOTO, bailOut
      endif else begin
         print, 'Cannot copy/unzip netCDF file: ', gr_netcdf_file
         print, cpstatus
         command3 = "rm -v " + ncfile1
         spawn, command3
         ; TAB 9/18/18 changed this to continue to next GR file instead of bailing
         IF (status EQ 1) then GOTO, nextGRfile
         ;goto, bailOut
      endelse

      for iscan = 0, N_ELEMENTS(DPR_SCANS)-1 DO BEGIN
         DPR_scantype = DPR_scans[iscan]
         CASE DPR_scantype OF
           'HS' : data_GR2DPR = DATA_HS
           'FS' : begin
			      CASE Instrument_ID OF
			          'Ka' : data_GR2DPR = DATA_FS_Ka
			          'KaX' : data_GR2DPR = DATA_FS_Ka
			          'Ku' : data_GR2DPR = DATA_FS_Ku
			          'KuX' : data_GR2DPR = DATA_FS_Ku
			      ENDCASE
           		  end
           'FS_Ku' : data_GR2DPR = DATA_FS_Ku
           'FS_Ka' : data_GR2DPR = DATA_FS_Ka
           else: message, 'unknown scan type: '+DPR_scantype
         ENDCASE

		;help, data_GR2DPR
        ; check for the case of no footprints for the swath
         IF data_GR2DPR.NUMRAYS GT 0 THEN BEGIN
           ; generate the output netcdf matchup file path
            IF KEYWORD_SET(flat_ncpath) THEN BEGIN
               NC_OUTDIR = NCGRIDSOUTDIR
            ENDIF ELSE BEGIN
               NC_OUTDIR = NCGRIDSOUTDIR+'/GPM/2A'+Instrument_ID+'/'+DPR_scantype+'/'+ $
                           DPR_version+'/'+verstr+'/20'+STRMID(DATESTAMP, 0, 2)  ; 4-digit Year
            ENDELSE

           ; generate the GRtoDPR netcdf matchup file path/name
            IF N_ELEMENTS(ncnameadd) EQ 1 THEN BEGIN
               fname_netCDF = NC_OUTDIR+'/'+DPR_GEO_MATCH_PRE+siteID+'.'+DATESTAMP+'.' $
                              +orbit+'.'+DPR_version+'.'+STRUPCASE(Instrument_ID)+'.' $
                              +DPR_scantype+'.'+verstr+'.'+ncnameadd+NC_FILE_EXT
;                              +STRUPCASE(DPR_scantype)+'.'+verstr+'.'+ncnameadd+NC_FILE_EXT
            ENDIF ELSE BEGIN
               fname_netCDF = NC_OUTDIR+'/'+DPR_GEO_MATCH_PRE+siteID+'.'+DATESTAMP+'.' $
                              +orbit+'.'+DPR_version+'.'+STRUPCASE(Instrument_ID)+'.' $
                              +DPR_scantype+'.'+verstr+NC_FILE_EXT
;                              +STRUPCASE(DPR_scantype)+'.'+verstr+NC_FILE_EXT
            ENDELSE

            dpr2gr_prematch_scan_v7, dpr_data, data_GR2DPR, dataGR, DPR_scantype, $
               DPR_version, mygeometa, mysweeps, mysite, myflags, myfiles, $
               grverstr, Instrument_ID, infileNameArr, fname_netCDF, $
               PLOT_PPIS=plot_PPIs, SCORES=run_scores, $
               NC_DIR=nc_dir, FLAT_NCPATH=flat_ncpath, NC_NAME_ADD=ncnameadd, $
               DPR_DBZ_MIN=dpr_dbz_min, DPR_RAIN_MIN=dpr_rain_min, $
               NON_PPS_FILES=non_pps_files, DECLUTTER=declutter
         ENDIF ELSE BEGIN
            print, ''
            print, "No samples for scan type ", DPR_scantype
            print, ''
         ENDELSE
      endfor
      nextGRfile:

   ENDFOR    ; each GR site for orbit

  ; free the memory/pointers in the dpr_data structure
   free_ptrs_in_struct, dpr_data ;, /ver

   nextOrbit:

ENDWHILE
print, ""
print, "Done!"

bailOut:
CLOSE, lun0

END

