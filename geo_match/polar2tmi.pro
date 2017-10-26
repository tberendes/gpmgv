;===============================================================================
;+
; Copyright © 2011, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; polar2tmi.pro          Morris/SAIC/GPM_GV      May 2011
;
; DESCRIPTION
; -----------
; Performs a resampling of TMI and GR data to common 3-D volumes, as defined in
; the horizontal by the location of TMI rays, and in the vertical by the heights
; of the intersection of the TMI rays with the top and bottom edges of individual
; elevation sweeps of a ground radar scanning in PPI mode.  The data domain is
; determined by the location of the ground radars overpassed by the TMI swath,
; and by the cutoff range (range_threshold_km) which is a mandatory parameter
; for this procedure.  The TMI and GR (ground radar) files to be processed are
; specified in the control_file, which is a mandatory parameter containing the
; fully-qualified file name of the control file to be used in the run.  Optional
; parameters (PR_ROOT and DIRGV) allow for non-default local paths to the TMI and
; GR files whose partial pathnames are listed in the control file.  The defaults
; for these paths are as specified in the environs.inc file.  All file path
; optional parameter values must begin with a leading slash (e.g., '/mydata')
; and be enclosed in quotes, as shown.  Optional binary keyword parameters
; control as-produced plotting of matched TMI rainrate and GR reflectivity
; sweep-by-sweep in the form of PPIs on a map background (/PLOT_PPIS), and
; plotting of the matching TMI and GV bin horizontal outlines (/PLOT_BINS) for
; the 'common' 3-D volume.  In the case of the TMI, the same surface rain rate
; field is plotted against each elevation sweep of the GR.
;
; A second set of matching GR volumes is computed along the local vertical (not
; along the TMI path), at the location of the TMI surface footprint, over the
; area of the TMI footprint.  In either case, the TMI footprint fixed diameter
; is computed as the maximum distance between adjacent TMI footprint center
; locations for the middle TMI scan line of those intersecting the GR location
; within a distance defined by the range_threshold_km value, specified as
; an input parameter.
;
; The control file is of a specific layout and contains specific fields in a
; fixed order and format.  See the script "doTMIGeoMatch4NewRainCases.sh", which
; creates the control file and invokes IDL to run this procedure.  Completed
; TMI and GR matchup data for an individual site overpass event (i.e., a given
; TRMM orbit and ground radar site) are written to a netCDF file.  The size of
; the dimensions in the data fields in the netCDF file vary from one case to
; another, depending on the number of elevation sweeps in the GV radar volume
; scan and the number of TMI footprints within the cutoff range from the GR site.
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
; NOTE: THE SET OF CODE CONTAINED IN THIS FILE IS NOT THE COMPLETE POLAR2TMI
;       PROCEDURE.  THE REMAINING CODE IN THE FULL PROCEDURE IS CONTAINED IN
;       THE FILE "polar2tmi_resampling.pro", WHICH IS INCORPORATED INTO THIS
;       FILE/PROCEDURE BY THE IDL "include" MECHANISM.
;
;
; MODULES
; -------
;   1) FUNCTION  plot_bins_bailout
;   2) PROCEDURE polar2tmi
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
; TMI: 1) Only TMI Versions 6 and 7, or other TMI versions with HDF files in TMI
;         Version 6's or 7's format, are supported by this code.
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
; 5/2011 by Bob Morris, GPM GV (SAIC)
;  - Created from polar2pr_23.pro.
; 5/18/2011 by Bob Morris, GPM GV (SAIC)
;  - Added GR samples along local earth vertical from surface footprint center,
;    ignoring TMI view parallax.
; 7/14/2011 by Bob Morris, GPM GV (SAIC)
;  - Added PoP and freezingHeight variables from V7 2A-12 to the single-level
;    fields written to the netCDF file.  Handle V6 vs. V7 differences in data
;    availability and array sizing to avoid potential errors.
; 11/15/11 by Bob Morris, GPM GV (SAIC)
;  - Write scalar variable for GR weighting function radius of influence to
;    the netCDF file.
; 02/06/13  Morris/GPM GV/SAIC
; - Added NSPECIES to COMMON definition in polar2tmi procedure.
; 10/17/13 by Bob Morris, GPM GV (SAIC)
;  - Added processing of GR rainrate field from radar data files, when present.
; 10/07/14  Morris/GPM GV/SAIC
; - Renamed NSPECIES to NSPECIES_TMI.
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

PRO skip_gr_events, lun, nsites
   line = ""
   FOR igv=0,nsites-1  DO BEGIN
     ; read and print the control file GR site ID, lat, lon, elev, filename, etc.
      READF, lun, line
      PRINT, igv+1, ": ", line
   ENDFOR
END

;*******************************************************************************

PRO polar2tmi, control_file, range_threshold_km, PR_ROOT=prroot, $
               DIR2A12=dir2a12, DIRGV=dirgv, SCORES=run_scores, $
               PLOT_PPIS=plot_PPIs, PLOT_BINS=plot_bins, NC_DIR=nc_dir, $
               NC_NAME_ADD=ncnameadd, MARK_EDGES=mark_edges, $
               DBZ_MIN=dBZ_min, TMI_RAIN_MIN=tmi_rain_min

IF KEYWORD_SET(plot_bins) THEN BEGIN
   reply = plot_bins_bailout()
   IF reply EQ 'Y' THEN plot_bins = 0
ENDIF

IF N_ELEMENTS( mark_edges ) EQ 1 THEN BEGIN
   IF mark_edges NE 0 THEN mark_edges=1
ENDIF ELSE mark_edges = 0

COMMON sample, start_sample, sample_range, num_range, NPIXEL_TMI, NSPECIES_TMI

; "Include" file for DATA_PRESENT, NO_DATA_PRESENT
@grid_def.inc
; "Include" file for TMI-product-specific parameters (i.e., NPIXEL_TMI):
@tmi_params.inc
; "Include" file for names, paths, etc.:
@environs.inc
; "Include" file for special values in netCDF files: Z_BELOW_THRESH, etc.
@pr_params.inc

; set to a constant, until database provides TMI product version override values
TMI_version = 6

; Values for "have_somegridfield" flags: (now defined within grid_def.inc
; via INCLUDE mechanism, and reversed from previous values to align with C and
; IDL True/False interpretation of values 1 and 0)
;DATA_PRESENT = 1
;NO_DATA_PRESENT = 0  ; default fill value, defined in grid_def.inc and used in
                      ; gen_tmi_geo_match_netcdf.pro


; ***************************** Local configuration ****************************

   ; where provided, override file path default values from environs.inc:
    in_base_dir =  GVDATA_ROOT ; default root dir for UF files
    IF N_ELEMENTS(dirgv)  EQ 1 THEN in_base_dir = dirgv

    IF N_ELEMENTS(prroot) EQ 1 THEN PRDATA_ROOT = prroot
    IF N_ELEMENTS(dir2a12)  EQ 1 THEN DIR_2A12 = dir2a12
    
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
   ; tally number of rain rate bins (mm/h) below this value in TMI rr averages
    IF N_ELEMENTS(tmi_rain_min) NE 1 THEN BEGIN
       TMI_RAIN_MIN = 0.01
       PRINT, "Assigning default value of 0.01 mm/h to TMI_RAIN_MIN."
    ENDIF

; ******************************************************************************


; will skip processing TMI points beyond this distance from a ground radar
rough_threshold = range_threshold_km * 1.1

; initialize the variables into which file records are read as strings
dataTMI = ''
dataGR = ''

; open and process control file, and generate the matchup data for the events

OPENR, lun0, control_file, ERROR=err, /GET_LUN
WHILE NOT (EOF(lun0)) DO BEGIN 

  ; get TMI filenames and count of GR file pathnames to do for an orbit
  ; - read the '|'-delimited input file record into a single string:
   READF, lun0, dataTMI

  ; parse dataTMI into its component fields: 2A12 file name, orbit number, 
  ; number of sites, YYMMDD, and TMI subset
   parsed=STRSPLIT( dataTMI, '|', /extract )
  ; get filenames as listed in/on the database/disk
   idx12 = WHERE(STRPOS(parsed,'2A12') GE 0, count12)
   if count12 EQ 1 THEN origFile12Name = STRTRIM(parsed[idx12],2) ELSE origFile12Name='no_2A12_file'
   orbit = parsed[1]
   nsites = FIX( parsed[2] )
   IF (nsites LE 0 OR nsites GT 99) THEN BEGIN
      PRINT, "Illegal number of GR sites in control file: ", parsed[2+parseoffset]
      PRINT, "Line: ", dataTMI
      PRINT, "Quitting processing."
      GOTO, bailOut
   ENDIF
   IF ( origFile12Name EQ 'no_2A12_file' ) THEN BEGIN
      PRINT, ""
      PRINT, "ERROR finding 2A12 product file name in control file: ", control_file
      PRINT, "Line: ", dataTMI
      PRINT, "Skipping events for orbit = ", orbit
      skip_gr_events, lun0, nsites
      PRINT, ""
      GOTO, nextOrbit
   ENDIF
   DATESTAMP = parsed[3]      ; in YYMMDD format
   subset = parsed[4]
   IF N_ELEMENTS(parsed) EQ 6 THEN BEGIN
      print, '' & print, "Overriding TMI_version with value from control file: ", parsed[5] & print, ''
      TMI_version = FIX( parsed[5] )  ;control file includes TMI_version
   ENDIF

;  add the well-known (or local) paths to get the fully-qualified file names
   file_2a12 = PRDATA_ROOT+DIR_2A12+"/"+origFile12Name

; store the file basenames in a string to be passed to gen_tmi_geo_match_netcdf()
   infileNameArr = STRARR(2)
   infileNameArr[0] = origFile12Name

; initialize TMI variables/arrays and read 2A12 fields
   SAMPLE_RANGE=0
   START_SAMPLE=0
   geolocation = FLTARR(sample_range>1, NPIXEL_TMI, 2)
    sc_lat_lon = FLTARR(2, sample_range>1)
      dataFlag = BYTARR(sample_range>1, NPIXEL_TMI)
      rainFlag = BYTARR(sample_range>1, NPIXEL_TMI)
   surfaceType = INTARR(sample_range>1, NPIXEL_TMI)
   surfaceRain = FLTARR(sample_range>1, NPIXEL_TMI)
           PoP = INTARR(sample_range>1, NPIXEL_TMI)
freezingHeight = INTARR(sample_range>1, NPIXEL_TMI)

   status = read_tmi_2a12_fields( file_2a12, $
                                  DATAFLAG=dataFlag, $
                                  RAINFLAG=rainFlag, $
                                  SURFACETYPE=surfaceType, $
                                  SURFACERAIN=surfaceRain, $
                                  POP=PoP, $
                                  FREEZINGHEIGHT=freezingHeight, $
                                  SC_LAT_LON=sc_lat_lon, $
                                  GEOL=geolocation )

   IF ( status NE 0 ) THEN BEGIN
      PRINT, ""
      PRINT, "ERROR reading fields from ", file_2a12
      PRINT, "Skipping events for orbit = ", orbit
      skip_gr_events, lun0, nsites
      PRINT, ""
      GOTO, nextOrbit
   ENDIF

; split GEOL data fields into tmiLats and tmiLons arrays
   tmiLons = FLTARR(NPIXEL_TMI,sample_range>1)
   tmiLats = FLTARR(NPIXEL_TMI,sample_range>1)
   tmiLons[*,*] = geolocation[1,*,*]
   tmiLats[*,*] = geolocation[0,*,*]

; split SC_LAT_LON data fields into scLats and scLons arrays
   scLons = FLTARR(sample_range>1)
   scLats = FLTARR(sample_range>1)
   scLons[*] = sc_lat_lon[1,*]
   scLats[*] = sc_lat_lon[0,*]

; NOTE THAT THE GEOLOCATION ARRAYS ARE IN (RAY,SCAN) COORDINATES, WHILE ALL THE
; OTHER ARRAYS ARE IN (SCAN,RAY) COORDINATE ORDER.  NEED TO ACCOUNT FOR THIS
; WHEN USING "tmi_master_idx" ARRAY INDICES.

   lastsite = ""
FOR igv=0,nsites-1  DO BEGIN
  ; read and parse the control file GR site ID, lat, lon, elev, filename, etc.
  ;  - read each overpassed site's information as a '|'-delimited string
   READF, lun0, dataGR
  ; PRINT, igv+1, ": ", dataGR

  ; parse dataGR into its component fields: event_num, orbit number, siteID,
  ; overpass datetime, time in ticks, site lat, site lon, site elev,
  ; 1CUF file unique pathname

   parsed=STRSPLIT( dataGR, '|', count=nGVfields, /extract )
   CASE nGVfields OF
     9 : BEGIN   ; legacy control file format
           event_num = LONG( parsed[0] )
           orbit = parsed[1]
           siteID = parsed[2]    ; GPMGV siteID
           tmi_dtime = parsed[3]
           tmi_dtime_ticks = parsed[4]
           siteLat = FLOAT( parsed[5] )
           siteLon = FLOAT( parsed[6] )
           siteElev = FLOAT( parsed[7] )
           origUFName = parsed[8]  ; filename as listed in/on the database/disk
         END
     6 : BEGIN   ; streamlined control file format, already have orbit #
           siteID = parsed[0]    ; GPMGV siteID
           tmi_dtime = parsed[1]
           tmi_dtime_ticks = ticks_from_datetime( tmi_dtime )
           IF STRING(tmi_dtime_ticks) EQ "Bad Datetime" THEN BEGIN
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

; store the file basename in the string array to be passed to gen_tmi_geo_match_netcdf()
   infileNameArr[1] = base_1CUF

   PRINT, igv+1, ": ", tmi_dtime, "  ", siteID, siteLat, siteLon
;   PRINT, igv+1, ": ", file_1CUF

  ; initialize a gv-centered map projection for the ll<->xy transformations:
   sMap = MAP_PROJ_INIT( 'Azimuthal Equidistant', center_latitude=siteLat, $
                         center_longitude=siteLon )
  ; TMI-site latitude and longitude differences for coarse filter
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

  ; find the volume with the correct reflectivity field for the GR site/source,
  ;   and the ID of the field itself
   gv_z_field = ''
   z_vol_num = get_site_specific_z_volume( siteID, radar, gv_z_field )
   IF ( z_vol_num LT 0 )  THEN BEGIN
      PRINT, ""
      PRINT, "Error finding volume in radar structure from file ", file_1CUF
      PRINT, ""
      GOTO, nextGVfile
   ENDIF

  ; find the volume with the rainrate field for the GV site/source
   gv_rr_field = ''
   rr_field2get = 'RR'
   rr_vol_num = get_site_specific_z_volume( siteID, radar, gv_rr_field, $
                                            UF_FIELD=rr_field2get )
   IF ( rr_vol_num LT 0 )  THEN BEGIN
      PRINT, ""
      PRINT, "Error finding 'RR' volume in radar structure from file: ", file_1CUF
      PRINT, ""
      have_gv_rr = 0
   ENDIF ELSE have_gv_rr = 1

  ; get the number of elevation sweeps in the vol, and the array of elev angles
   num_elevations = get_sweep_elevs( z_vol_num, radar, elev_angle )

  ; make a copy of the array of elevations, from which we eliminate any
  ;   duplicate tilt angles for subsequent data processing/output
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

  ; Determine an upper limit to how many TMI footprints fall inside the analysis
  ;   area, so that we can hold x, y, and various z values for each element to
  ;   analyze.  We give the TMI a 5km resolution and use this nominal resolution
  ;   to figure out how many of these are required to cover the in-range area.

   grid_area_km = rough_threshold * rough_threshold  ; could use area of circle
   max_tmi_fp = grid_area_km / 5.0

  ; Create temp array of TMI (ray, scan) 1-D index locators for in-range points.
  ;   Use flag values of -1 for 'bogus' TMI points (out-of-range TMI footprints
  ;   just adjacent to the first/last in-range point of the scan), or -2 for
  ;   off-TMI-scan-edge but still-in-range points.  These bogus points will then
  ;   totally enclose the set of in-range, in-scan points and allow gridding of
  ;   the in-range dataset to a regular grid using a nearest-neighbor analysis,
  ;   assuring that the bounds of the in-range data are preserved (this gridding
  ;   in not needed or done within the current analysis).
   tmi_master_idx = LONARR(max_tmi_fp)
   tmi_master_idx[*] = -99L

  ; Create temp array used to flag whether there are ANY above-threshold TMI bins
  ; in the ray.  If none, we'll skip the time-consuming GR LUT computations.
   tmi_echoes = BYTARR(max_tmi_fp)
   tmi_echoes[*] = 0B             ; initialize to zero (skip the TMI ray)

  ; Create temp arrays to hold lat/lon of all TMI footprints to be analyzed,
  ;   including those extrapolated to mark the edge of the scan
   tmi_lon_sfc = FLTARR(max_tmi_fp)
   tmi_lat_sfc = tmi_lon_sfc

  ; ditto, but surface x and y
   x_sfc = FLTARR(max_tmi_fp)
   y_sfc = x_sfc

  ; create temp subarrays with additional dimension num_elevations_out to hold
  ;   parallax-adjusted TMI point X,Y and lon/lat coordinates, and TMI corner X,Ys
   tmi_x_center = FLTARR(max_tmi_fp, num_elevations_out)
   tmi_y_center = tmi_x_center
   tmi_x_corners = FLTARR(4, max_tmi_fp, num_elevations_out)
   tmi_y_corners = tmi_x_corners
  ; holds lon/lat array returned by MAP_PROJ_INVERSE()
   tmi_lon_lat = DBLARR(2, max_tmi_fp, num_elevations_out)

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

  ; GEO-Preprocess the TMI data, extracting rays that intersect this radar volume
  ; within the specified range threshold, and computing footprint x,y corner
  ; coordinates and adjusted center lat/lon at each of the intersection sweep
  ; intersection heights, taking into account the parallax of the TMI rays.
  ; (Optionally) surround the TMI footprints within the range threshold with a border
  ; of "bogus" tagged TMI points to facilitate any future gridding of the data.
  ; Algorithm assumes that TMI footprints are contiguous, non-overlapping,
  ; and quasi-rectangular in their native ray,scan coordinates, and that the PR
  ; middle ray of the scan is nadir-pointing (zero roll/pitch of satellite).

  ; First, find scans with any point within range of the radar volume, roughly
   start_scan = 0 & end_scan = 0 & nscans2do = 0
   start_found = 0
   FOR scan_num = 0,SAMPLE_RANGE-1  DO BEGIN
      found_one = 0
      FOR ray_num = 0,NPIXEL_TMI-1  DO BEGIN
         ; Compute distance between GV radar and TMI sample lats/lons using
         ;   crude, fast algorithm
         IF ( ABS(tmiLons[ray_num,scan_num]-siteLon) LT max_deg_lon ) AND $
            ( ABS(tmiLats[ray_num,scan_num]-siteLat) LT max_deg_lat ) THEN BEGIN
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
  ; Populate arrays holding 'exact' TMI at-surface X and Y and range values for
  ; the in-range subset of scans.  THESE ARE NOT WRITTEN TO NETCDF FILE - YET.
   XY_km = map_proj_forward( tmiLons[*,start_scan:end_scan], $
                             tmiLats[*,start_scan:end_scan], $
                             map_structure=smap ) / 1000.
   tmi_x0 = XY_km[0,*]
   tmi_y0 = XY_km[1,*]
   tmi_x0 = REFORM( tmi_x0, NPIXEL_TMI, nscans2do, /OVERWRITE )
   tmi_y0 = REFORM( tmi_y0, NPIXEL_TMI, nscans2do, /OVERWRITE )
   precise_range = SQRT( tmi_x0^2 + tmi_y0^2 )
 
   numTMIrays = 0      ; number of in-range, scan-edge, and range-adjacent points
   numTMI_inrange = 0   ; number of in-range-only points found
  ; Variables used to find 'farthest from nadir' in-range TMI footprint:
   maxrayidx = 0
   minrayidx = NPIXEL_TMI-1

;-------------------------------------------------------------------------------
  ; Identify actual TMI points within range of the radar, actual TMI points just
  ; off the edge of the range cutoff, and extrapolated TMI points along the edge
  ; of the scans but within range of the radar.  Tag each point as to these 3
  ; types, and compute parallax-corrected x,y and lat/lon coordinates for these
  ; points at TMI ray's intersection of each sweep elevation.  Compute TMI
  ; footprint corner x,y's for the first type of points (actual TMI points
  ; within the cutoff range).

  ; flag for adding 'bogus' point if in-range at edge of scan TMI (2), or just
  ;   beyond max_ranges[elev] (-1), or just a regular, in-range point (1):
   action2do = 0  ; default -- do nothing

   FOR scan_num = start_scan,end_scan  DO BEGIN
      subset_scan_num = scan_num - start_scan

      FOR ray_num = 0,NPIXEL_TMI-1  DO BEGIN
        ; Set flag value according to where the TMI footprint lies w.r.t. the GV radar.
         action2do = 0  ; default -- do nothing

        ; is to-sfc projection of any point along TMI ray within range of GR volume?
         IF ( precise_range[ray_num,subset_scan_num] LE max_ranges[0] ) THEN BEGIN
           ; add point to subarrays for TMI 2D index and for footprint lat/lon & x,y
           ; - MAKE THE INDEX IN TERMS OF THE (SCAN,RAY) COORDINATE ARRAYS
            tmi_master_idx[numTMIrays] = LONG(ray_num) * LONG(SAMPLE_RANGE) + LONG(scan_num)
            tmi_lat_sfc[numTMIrays] = tmiLats[ray_num,scan_num]
            tmi_lon_sfc[numTMIrays] = tmiLons[ray_num,scan_num]
            x_sfc[numTMIrays] = tmi_x0[ray_num, subset_scan_num]
            y_sfc[numTMIrays] = tmi_y0[ray_num, subset_scan_num]

            action2do = 1                      ; set up to process this in-range point
            maxrayidx = ray_num > maxrayidx    ; track highest ray num occurring in GR area
            minrayidx = ray_num < minrayidx    ; track lowest ray num in GR area
            numTMI_inrange = numTMI_inrange + 1    ; increment # of actual in-range footprints

	   ; determine whether the TMI ray has any retrieval data
            IF ( dataFlag[scan_num, ray_num] EQ 0 ) THEN tmi_echoes[numTMIrays] = 1B
; tmi_echoes[numTMIrays] = 1B  ; TEST PERFORMANCE OF DOING ALL FOOTIES

           ; If TMI scan edge point, then set flag to add bogus TMI data point to
           ;   subarrays for each TMI spatial field, with TMI index flagged as
           ;   "off-scan-edge", and compute the extrapolated location parameters
            IF ( (ray_num EQ 0 OR ray_num EQ NPIXEL_TMI-1) AND mark_edges EQ 1 ) THEN BEGIN
              ; set flag and find the x,y offsets to extrapolated off-edge point
               action2do = 2                   ; set up to also process bogus off-edge point
              ; extrapolate X and Y to the bogus, off-scan-edge point
               if ( ray_num EQ 0 ) then begin 
                 ; offsets extrapolate X and Y to where (angle = angle-1) would be
                 ; Get offsets using the next footprint's X and Y
                  Xoff = tmi_x0[ray_num, subset_scan_num] - tmi_x0[ray_num+1, subset_scan_num]
                  Yoff = tmi_y0[ray_num, subset_scan_num] - tmi_y0[ray_num+1, subset_scan_num]
               endif else begin
                 ; extrapolate X and Y to where (angle = angle+1) would be
                 ; Get offsets using the preceding footprint's X and Y
                  Xoff = tmi_x0[ray_num, subset_scan_num] - tmi_x0[ray_num-1, subset_scan_num]
                  Yoff = tmi_y0[ray_num, subset_scan_num] - tmi_y0[ray_num-1, subset_scan_num]
               endelse
              ; compute the resulting lon/lat value of the extrapolated footprint
              ;  - we will add to temp lat/lon arrays in action sections, below
               XX = tmi_x0[ray_num, subset_scan_num] + Xoff
               YY = tmi_y0[ray_num, subset_scan_num] + Yoff
              ; need x and y in meters for MAP_PROJ_INVERSE:
               extrap_lon_lat = MAP_PROJ_INVERSE (XX*1000., YY*1000., MAP_STRUCTURE=smap)
            ENDIF

         ENDIF ELSE BEGIN
            IF mark_edges EQ 1 THEN BEGIN
              ; Is footprint immediately adjacent to the in-range area?  If so, then
              ;   'ring' the in-range points with a border of TMI bogosity, even for
              ;   scans with no rays in-range. (Is like adding a range ring at the
              ;   outer edge of the in-range area)
               IF ( precise_range[ray_num,subset_scan_num] LE $
                    (max_ranges[0] + NOM_TMI_RES_KM*1.1) ) THEN BEGIN
                   tmi_master_idx[numTMIrays] = -1L  ; store beyond-range indicator as TMI index
                   tmi_lat_sfc[numTMIrays] = tmiLats[ray_num,scan_num]
                   tmi_lon_sfc[numTMIrays] = tmiLons[ray_num,scan_num]
                   x_sfc[numTMIrays] = tmi_x0[ray_num, subset_scan_num]
                   y_sfc[numTMIrays] = tmi_y0[ray_num, subset_scan_num]
                   action2do = -1  ; set up to process bogus beyond-range point
               ENDIF
            ENDIF
         ENDELSE          ; ELSE for precise range[] LE max_ranges[0]

        ; If/As flag directs, add TMI point(s) to the subarrays for each elevation
         IF ( action2do NE 0 ) THEN BEGIN
           ; compute the at-surface x,y values for the 4 corners of the current TMI footprint
            if scan_num LT end_scan THEN $
            xy = footprint_corner_x_and_y( subset_scan_num, ray_num, tmi_x0, tmi_y0, $
                                           nscans2do, NPIXEL_TMI ) $
            else $
            xy = footprint_corner_x_and_y( subset_scan_num, ray_num, tmi_x0, tmi_y0, $
                                           nscans2do, NPIXEL_TMI, /DO_PRINT )

           ; compute parallax-corrected x-y values for each sweep height
            FOR i = 0, num_elevations_out - 1 DO BEGIN
              ; NEXT 4+ COMMANDS COULD BE ITERATIVE, TO CONVERGE TO A dR THRESHOLD (function?)
              ; compute GR beam height for elevation angle at precise_range
               rsl_get_slantr_and_h, precise_range[ray_num,subset_scan_num], $
                                     tocdf_elev_angle[i], slant_range, hgt_at_range

              ; compute TMI parallax corrections dX and dY at this height (adjusted to MSL),
              ;   and apply to footprint center X and Y to get XX and YY
;               get_parallax_dx_dy, hgt_at_range + siteElev, ray_num, NPIXEL_TMI, $
;                                   m, dy_sign, tan_inc_angle, dx, dy

               get_tmi_parallax_dx_dy, hgt_at_range, siteElev, scan_num, ray_num, $
                                       smap, tocdf_elev_angle[i], tmiLats, tmiLons, $
                                       scLats, scLons, dx, dy

               XX = tmi_x0[ray_num, subset_scan_num] + dx
               YY = tmi_y0[ray_num, subset_scan_num] + dy

              ; recompute precise_range of parallax-corrected TMI footprint from radar (if converging)

              ; compute lat,lon of parallax-corrected TMI footprint center:
               lon_lat = MAP_PROJ_INVERSE( XX*1000., YY*1000., MAP_STRUCTURE=smap )  ; x and y in meters

              ; compute parallax-corrected X and Y coordinate values for the TMI
              ;   footprint corners; hold in temp arrays xcornerspc and ycornerspc
               xcornerspc = xy[0,*] + dx
               ycornerspc = xy[1,*] + dy

              ; store TMI-GR sweep intersection (XX,YY), offset lat and lon, and
              ;  (if non-bogus) corner (x,y)s in elevation-specific slots
               tmi_x_center[numTMIrays,i] = XX
               tmi_y_center[numTMIrays,i] = YY
               tmi_x_corners[*,numTMIrays,i] = xcornerspc
               tmi_y_corners[*,numTMIrays,i] = ycornerspc
               tmi_lon_lat[*,numTMIrays,i] = lon_lat
            ENDFOR
            numTMIrays = numTMIrays + 1   ; increment counter for # TMI rays stored in arrays
         ENDIF

         IF ( action2do EQ 2 ) THEN BEGIN
           ; add another TMI footprint to the analyzed set, to delimit the TMI scan edge
            tmi_master_idx[numTMIrays] = -2L    ; store off-scan-edge indicator as TMI index
            tmi_lat_sfc[numTMIrays] = extrap_lon_lat[1]  ; store extrapolated lat/lon
            tmi_lon_sfc[numTMIrays] = extrap_lon_lat[0]
            x_sfc[numTMIrays] = tmi_x0[ray_num, subset_scan_num] + Xoff  ; ditto, extrap. x,y
            y_sfc[numTMIrays] = tmi_y0[ray_num, subset_scan_num] + Yoff

            FOR i = 0, num_elevations_out - 1 DO BEGIN
              ; - grab the parallax-corrected footprint center and corner x,y's just
              ;     stored for the in-range TMI edge point, and apply Xoff and Yoff offsets
               XX = tmi_x_center[numTMIrays-1,i] + Xoff
               YY = tmi_y_center[numTMIrays-1,i] + Yoff
               xcornerspc = tmi_x_corners[*,numTMIrays-1,i] + Xoff
               ycornerspc = tmi_y_corners[*,numTMIrays-1,i] + Yoff
              ; - compute lat,lon of parallax-corrected TMI footprint center:
               lon_lat = MAP_PROJ_INVERSE(XX*1000., YY*1000., MAP_STRUCTURE=smap)  ; x,y to m
              ; store in elevation-specific slots
               tmi_x_center[numTMIrays,i] = XX
               tmi_y_center[numTMIrays,i] = YY
               tmi_x_corners[*,numTMIrays,i] = xcornerspc
               tmi_y_corners[*,numTMIrays,i] = ycornerspc
               tmi_lon_lat[*,numTMIrays,i] = lon_lat
            ENDFOR
            numTMIrays = numTMIrays + 1
         ENDIF

      ENDFOR              ; ray_num
   ENDFOR                 ; scan_num = start_scan,end_scan 

  ; ONE TIME ONLY: compute max diagonal size of a TMI footprint, halve it,
  ;   and assign to max_TMI_footprint_diag_halfwidth.  Ignore the variability
  ;   with height.  Take middle scan of TMI/GR overlap within subset arrays:
   subset_scan_4size = FIX( (end_scan-start_scan)/2 )
  ; find which ray used was farthest from nadir ray at NPIXEL_TMI/2
   nadir_off_low = ABS(minrayidx - NPIXEL_TMI/2)
   nadir_off_hi = ABS(maxrayidx - NPIXEL_TMI/2)
   ray4size = (nadir_off_hi GT nadir_off_low) ? maxrayidx : minrayidx
  ; get TMI footprint max diag extent at [ray4size, scan4size], and halve it
  ; Is it guaranteed that [subset_scan4size,ray4size] is one of our in-range
  ;   points?  Don't know, so get the corner x,y's for this point
   xy = footprint_corner_x_and_y( subset_scan_4size, ray4size, tmi_x0, tmi_y0, $
                                  nscans2do, NPIXEL_TMI )
   diag1 = SQRT((xy[0,0]-xy[0,2])^2+(xy[1,0]-xy[1,2])^2)
   diag2 = SQRT((xy[0,1]-xy[0,3])^2+(xy[1,1]-xy[1,3])^2)
   max_TMI_footprint_diag_halfwidth = (diag1 > diag2) / 2.0
   print, ''
   print, "Computed radius of influence, km: ", max_TMI_footprint_diag_halfwidth
   print, ''

  ; end of TMI GEO-preprocessing

  ; ======================================================================================================

  ; Initialize and/or populate data fields to be written to the netCDF file.
  ; NOTE WE DON'T SAVE THE SURFACE X,Y FOOTPRINT CENTERS AND CORNERS TO NETCDF

   IF ( numTMI_inrange GT 0 ) THEN BEGIN
     ; Trim the tmi_master_idx, lat/lon temp arrays and x,y corner arrays down
     ;   to numTMIrays elements in that dimension, in prep. for writing to netCDF
     ;    -- these elements are complete, data-wise
      tocdf_tmi_idx = tmi_master_idx[0:numTMIrays-1]
      tocdf_x_poly = tmi_x_corners[*,0:numTMIrays-1,*]
      tocdf_y_poly = tmi_y_corners[*,0:numTMIrays-1,*]
      tocdf_lat = REFORM(tmi_lon_lat[1,0:numTMIrays-1,*])   ; 3D to 2D
      tocdf_lon = REFORM(tmi_lon_lat[0,0:numTMIrays-1,*])
      tocdf_lat_sfc = tmi_lat_sfc[0:numTMIrays-1]
      tocdf_lon_sfc = tmi_lon_sfc[0:numTMIrays-1]

     ; Create new subarrays of dimension equal to the numTMIrays for each 2-D
     ;   TMI science variable: surfaceType, surfaceRain, rainFlag, dataFlag
      tocdf_2a12_srain = MAKE_ARRAY(numTMIrays, /float, VALUE=FLOAT_RANGE_EDGE)
      tocdf_rainflag = MAKE_ARRAY(numTMIrays, /int, VALUE=INT_RANGE_EDGE)
      tocdf_dataFlag = MAKE_ARRAY(numTMIrays, /int, VALUE=INT_RANGE_EDGE)
      tocdf_surfaceType = MAKE_ARRAY(numTMIrays, /int, VALUE=INT_RANGE_EDGE)
      tocdf_PoP = MAKE_ARRAY(numTMIrays, /int, VALUE=INT_RANGE_EDGE)
      tocdf_freezingHeight = MAKE_ARRAY(numTMIrays, /int, VALUE=INT_RANGE_EDGE)

     ; Create new subarrays of dimensions (numTMIrays, num_elevations_out) for each
     ;   3-D science and status variable for along-TMI-FOV samples: 
      tocdf_gr_dbz = MAKE_ARRAY(numTMIrays, num_elevations_out, /float, VALUE=FLOAT_RANGE_EDGE)
      tocdf_gr_stddev = MAKE_ARRAY(numTMIrays, num_elevations_out, /float, VALUE=FLOAT_RANGE_EDGE)
      tocdf_gr_max = MAKE_ARRAY(numTMIrays, num_elevations_out, /float, VALUE=FLOAT_RANGE_EDGE)
      tocdf_gr_rr = MAKE_ARRAY(numTMIrays, num_elevations_out, /float, VALUE=FLOAT_RANGE_EDGE)
      tocdf_gr_rr_stddev = MAKE_ARRAY(numTMIrays, num_elevations_out, /float, VALUE=FLOAT_RANGE_EDGE)
      tocdf_gr_rr_max = MAKE_ARRAY(numTMIrays, num_elevations_out, /float, VALUE=FLOAT_RANGE_EDGE)
      tocdf_top_hgt = MAKE_ARRAY(numTMIrays, num_elevations_out, /float, VALUE=FLOAT_RANGE_EDGE)
      tocdf_botm_hgt = MAKE_ARRAY(numTMIrays, num_elevations_out, /float, VALUE=FLOAT_RANGE_EDGE)
      tocdf_gr_rejected = UINTARR(numTMIrays, num_elevations_out)
      tocdf_gr_rr_rejected = UINTARR(numTMIrays, num_elevations_out)
      tocdf_gr_expected = UINTARR(numTMIrays, num_elevations_out)

     ; Create new subarrays of dimensions (numTMIrays, num_elevations_out) for each
     ;   3-D science and status variable for along-local-vertical samples: 
      tocdf_gr_VPR_dbz = MAKE_ARRAY(numTMIrays, num_elevations_out, /float, VALUE=FLOAT_RANGE_EDGE)
      tocdf_gr_StdDev_VPR = MAKE_ARRAY(numTMIrays, num_elevations_out, /float, VALUE=FLOAT_RANGE_EDGE)
      tocdf_gr_Max_VPR = MAKE_ARRAY(numTMIrays, num_elevations_out, /float, VALUE=FLOAT_RANGE_EDGE)
      tocdf_gr_rr_VPR = MAKE_ARRAY(numTMIrays, num_elevations_out, /float, VALUE=FLOAT_RANGE_EDGE)
      tocdf_gr_rr_StdDev_VPR = MAKE_ARRAY(numTMIrays, num_elevations_out, /float, VALUE=FLOAT_RANGE_EDGE)
      tocdf_gr_rr_Max_VPR = MAKE_ARRAY(numTMIrays, num_elevations_out, /float, VALUE=FLOAT_RANGE_EDGE)
      tocdf_top_hgt_VPR = MAKE_ARRAY(numTMIrays, num_elevations_out, /float, VALUE=FLOAT_RANGE_EDGE)
      tocdf_botm_hgt_VPR = MAKE_ARRAY(numTMIrays, num_elevations_out, /float, VALUE=FLOAT_RANGE_EDGE)
      tocdf_gr_VPR_rejected = UINTARR(numTMIrays, num_elevations_out)
      tocdf_gr_rr_VPR_rejected = UINTARR(numTMIrays, num_elevations_out)
      tocdf_gr_VPR_expected = UINTARR(numTMIrays, num_elevations_out)

     ; get the indices of actual TMI footprints and load the 2D element subarrays
     ;   (no more averaging/processing needed) with data from the product arrays

      prgoodidx = WHERE( tocdf_tmi_idx GE 0L, countprgood )
      IF ( countprgood GT 0 ) THEN BEGIN
         tmi_idx_2get = tocdf_tmi_idx[prgoodidx]
         tocdf_2a12_srain[prgoodidx] = surfaceRain[tmi_idx_2get]
        ; avoid indexing errors for rainFlag field not read from V7 2A-12
         IF TMI_version EQ 6 THEN tocdf_rainflag[prgoodidx] = rainFlag[tmi_idx_2get]
         tocdf_dataFlag[prgoodidx] = dataFlag[tmi_idx_2get]
         tocdf_surfaceType[prgoodidx] = surfaceType[tmi_idx_2get]
         IF TMI_version EQ 7 THEN BEGIN
           ; can only index/assign these if they were read from V7 2A-12
            tocdf_PoP[prgoodidx] = PoP[tmi_idx_2get]
            tocdf_freezingHeight[prgoodidx] = freezingHeight[tmi_idx_2get]
         ENDIF
      ENDIF

     ; get the indices of any bogus scan-edge TMI footprints
      predgeidx = WHERE( tocdf_tmi_idx EQ -2, countpredge )
      IF ( countpredge GT 0 ) THEN BEGIN
        ; set the single-level TMI element subarrays with the special values for
        ;   the extrapolated points
         tocdf_2a12_srain[predgeidx] = FLOAT_OFF_EDGE
         IF TMI_version EQ 6 THEN tocdf_rainflag[predgeidx] = INT_OFF_EDGE
         tocdf_dataFlag[predgeidx] = INT_OFF_EDGE
         tocdf_surfaceType[predgeidx] = INT_OFF_EDGE
         IF TMI_version EQ 7 THEN BEGIN
            tocdf_PoP[predgeidx] = INT_OFF_EDGE
            tocdf_freezingHeight[predgeidx] = INT_OFF_EDGE
         ENDIF
      ENDIF

   ENDIF ELSE BEGIN
      PRINT, ""
      PRINT, "No in-range TMI footprints found for ", siteID, ", skipping."
      PRINT, ""
      GOTO, nextGVfile
   ENDELSE

  ; ================================================================================================
  ; Map this GV radar's data to the these TMI footprints, where TMI rays
  ; intersect the elevation sweeps.  This part of the algorithm continues
  ; in code in a separate file, included below:

   @polar2tmi_resampling.pro

  ; ================================================================================================

   matchup_file_version=0.0  ; give it a null value, for now
  ; Call gen_tmi_geo_match_netcdf with the option to only get current file version
  ; so that it can become part of the matchup file name
   throwaway = gen_tmi_geo_match_netcdf( GEO_MATCH_VERS=matchup_file_version )
  ; substitute an underscore for the decimal point
   verarr=strsplit(string(matchup_file_version,FORMAT='(F0.1)'),'.',/extract)
   verstr=verarr[0]+'_'+verarr[1]
   tmiverstr=string(TMI_version,FORMAT='(I0)')
  ; generate the netcdf matchup file path/name
   IF N_ELEMENTS(ncnameadd) EQ 1 THEN BEGIN
      fname_netCDF = NCGRIDSOUTDIR+'/'+TMI_GEO_MATCH_PRE+siteID+'.'+DATESTAMP+'.' $
                      +orbit+'.'+tmiverstr+'.'+verstr+'.'+ncnameadd+NC_FILE_EXT
   ENDIF ELSE BEGIN
      fname_netCDF = NCGRIDSOUTDIR+'/'+TMI_GEO_MATCH_PRE+siteID+'.'+DATESTAMP+'.' $
                      +orbit+'.'+tmiverstr+'.'+verstr+NC_FILE_EXT
   ENDELSE

  ; Create a netCDF file with the proper 'numTMIrays' and 'num_elevations_out'
  ; dimensions, passing the global attribute values along
   ncfile = gen_tmi_geo_match_netcdf( fname_netCDF, numTMIrays, tocdf_elev_angle, $
                                      gv_z_field, TMI_version, infileNameArr )
   IF ( fname_netCDF EQ "NoGeoMatchFile" ) THEN $
      message, "Error in creating output netCDF file "+fname_netCDF

  ; Open the netCDF file and write the completed field values to it
   ncid = NCDF_OPEN( ncfile, /WRITE )

  ; Write the scalar values to the netCDF file

   NCDF_VARPUT, ncid, 'site_ID', siteID
   NCDF_VARPUT, ncid, 'site_lat', siteLat
   NCDF_VARPUT, ncid, 'site_lon', siteLon
   NCDF_VARPUT, ncid, 'site_elev', siteElev
   NCDF_VARPUT, ncid, 'timeNearestApproach', tmi_dtime_ticks
   NCDF_VARPUT, ncid, 'atimeNearestApproach', tmi_dtime
   NCDF_VARPUT, ncid, 'timeSweepStart', ticks_sweep_times
   NCDF_VARPUT, ncid, 'atimeSweepStart', text_sweep_times
   NCDF_VARPUT, ncid, 'rangeThreshold', range_threshold_km
   NCDF_VARPUT, ncid, 'GR_dBZ_min', dBZ_min
   NCDF_VARPUT, ncid, 'tmi_rain_min', TMI_RAIN_MIN
   NCDF_VARPUT, ncid, 'radiusOfInfluence', max_TMI_footprint_diag_halfwidth

;  Write single-level results/flags to netcdf file

   NCDF_VARPUT, ncid, 'TMIlatitude', tocdf_lat_sfc
   NCDF_VARPUT, ncid, 'TMIlongitude', tocdf_lon_sfc
   NCDF_VARPUT, ncid, 'surfaceType', tocdf_surfaceType     ; data
    NCDF_VARPUT, ncid, 'have_surfaceType', DATA_PRESENT  ; data presence flag
   NCDF_VARPUT, ncid, 'surfaceRain', tocdf_2a12_srain     ; data
    NCDF_VARPUT, ncid, 'have_surfaceRain', DATA_PRESENT   ; data presence flag
   IF TMI_version EQ 6 THEN BEGIN
     ; only have Rain Flag for V6, leave initialized to No Data for V7
      NCDF_VARPUT, ncid, 'rainFlag', tocdf_rainflag      ; data
       NCDF_VARPUT, ncid, 'have_rainFlag', DATA_PRESENT  ; data presence flag
   ENDIF
   NCDF_VARPUT, ncid, 'dataFlag', tocdf_dataFlag      ; data
    NCDF_VARPUT, ncid, 'have_dataFlag', DATA_PRESENT  ; data presence flag
   IF TMI_version EQ 7 THEN BEGIN
     ; only have PoP and freezingHeight for V7, leave initialized to No Data for V6
      NCDF_VARPUT, ncid, 'PoP', tocdf_PoP      ; data
       NCDF_VARPUT, ncid, 'have_PoP', DATA_PRESENT  ; data presence flag
      NCDF_VARPUT, ncid, 'freezingHeight', tocdf_freezingHeight      ; data
       NCDF_VARPUT, ncid, 'have_freezingHeight', DATA_PRESENT  ; data presence flag
   ENDIF
   NCDF_VARPUT, ncid, 'rayIndex', tocdf_tmi_idx

;  Write sweep-level results/flags to netcdf file & close it up

   NCDF_VARPUT, ncid, 'latitude', tocdf_lat
   NCDF_VARPUT, ncid, 'longitude', tocdf_lon
   NCDF_VARPUT, ncid, 'xCorners', tocdf_x_poly
   NCDF_VARPUT, ncid, 'yCorners', tocdf_y_poly
   NCDF_VARPUT, ncid, 'GR_Z_along_TMI', tocdf_gr_dbz            ; data
    NCDF_VARPUT, ncid, 'have_GR_Z_along_TMI', DATA_PRESENT      ; data presence flag
   NCDF_VARPUT, ncid, 'GR_Z_StdDev_along_TMI', tocdf_gr_stddev     ; data
    NCDF_VARPUT, ncid, 'have_GR_Z_StdDev_along_TMI', DATA_PRESENT  ; data presence flag
   NCDF_VARPUT, ncid, 'GR_Z_Max_along_TMI', tocdf_gr_max            ; data
    NCDF_VARPUT, ncid, 'have_GR_Z_Max_along_TMI', DATA_PRESENT      ; data presence flag
   IF ( have_gv_rr ) THEN BEGIN
      NCDF_VARPUT, ncid, 'GR_RR_along_TMI', tocdf_gr_rr            ; data
       NCDF_VARPUT, ncid, 'have_GR_RR_along_TMI', DATA_PRESENT      ; data presence flag
      NCDF_VARPUT, ncid, 'GR_RR_StdDev_along_TMI', tocdf_gr_rr_stddev     ; data
       NCDF_VARPUT, ncid, 'have_GR_RR_StdDev_along_TMI', DATA_PRESENT  ; data presence flag
      NCDF_VARPUT, ncid, 'GR_RR_Max_along_TMI', tocdf_gr_rr_max            ; data
       NCDF_VARPUT, ncid, 'have_GR_RR_Max_along_TMI', DATA_PRESENT      ; data presence flag
   ENDIF
   NCDF_VARPUT, ncid, 'topHeight', tocdf_top_hgt
   NCDF_VARPUT, ncid, 'bottomHeight', tocdf_botm_hgt
   NCDF_VARPUT, ncid, 'n_gr_rejected', tocdf_gr_rejected
   NCDF_VARPUT, ncid, 'n_gr_rr_rejected', tocdf_gr_rr_rejected
   NCDF_VARPUT, ncid, 'n_gr_expected', tocdf_gr_expected
   NCDF_VARPUT, ncid, 'GR_Z_VPR', tocdf_gr_VPR_dbz            ; data
    NCDF_VARPUT, ncid, 'have_GR_Z_VPR', DATA_PRESENT      ; data presence flag
   NCDF_VARPUT, ncid, 'GR_Z_StdDev_VPR', tocdf_gr_StdDev_VPR     ; data
    NCDF_VARPUT, ncid, 'have_GR_Z_StdDev_VPR', DATA_PRESENT  ; data presence flag
   NCDF_VARPUT, ncid, 'GR_Z_Max_VPR', tocdf_gr_Max_VPR            ; data
    NCDF_VARPUT, ncid, 'have_GR_Z_Max_VPR', DATA_PRESENT      ; data presence flag
   IF ( have_gv_rr ) THEN BEGIN
      NCDF_VARPUT, ncid, 'GR_RR_VPR', tocdf_gr_rr_VPR            ; data
       NCDF_VARPUT, ncid, 'have_GR_RR_VPR', DATA_PRESENT      ; data presence flag
      NCDF_VARPUT, ncid, 'GR_RR_StdDev_VPR', tocdf_gr_rr_StdDev_VPR     ; data
       NCDF_VARPUT, ncid, 'have_GR_RR_StdDev_VPR', DATA_PRESENT  ; data presence flag
      NCDF_VARPUT, ncid, 'GR_RR_Max_VPR', tocdf_gr_rr_Max_VPR            ; data
       NCDF_VARPUT, ncid, 'have_GR_RR_Max_VPR', DATA_PRESENT      ; data presence flag
   ENDIF
   NCDF_VARPUT, ncid, 'topHeight_vpr', tocdf_top_hgt_VPR
   NCDF_VARPUT, ncid, 'bottomHeight_vpr', tocdf_botm_hgt_VPR
   NCDF_VARPUT, ncid, 'n_gr_vpr_rejected', tocdf_gr_VPR_rejected
   NCDF_VARPUT, ncid, 'n_gr_rr_vpr_rejected', tocdf_gr_rr_VPR_rejected
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

ENDWHILE  ; each orbit/TMI file set to process in control file

print, ""
print, "Done!"

bailOut:
CLOSE, lun0

END
