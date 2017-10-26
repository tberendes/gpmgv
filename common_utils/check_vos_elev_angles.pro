;===============================================================================
;+
; Copyright © 2008, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; check_vos_elev_angles.pro          Morris/SAIC/GPM_GV      September 2010
;
; DESCRIPTION
; -----------
; Steps through a polar2pr_multi_vol control file, opens and reads the list of
; elevation angles in each ground radar UF file associated to the PR orbit, and
; determines whether the list of elevation angles in each GR volume is
; identical.  If so, adds the orbit number for the PR/GR set to the orbits2do
; array passed in as a parameter, and writes the number of sweeps per volume
; for the volumes in this orbit to nswps.  Repeats for each orbit in the control
; file. Returns the number of 'good' orbits found.
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;===============================================================================

FUNCTION check_vos_elev_angles, control_file, in_base_dir, orbits2do, nswps

; initialize the variables into which file records are read as strings
dataPR="" & dataGV=""

; initialize variables to tally orbits where every associated GR volume has
; identical sweeps
orbit2tag=0

; open and process control file, and generate the matchup data for the events
OPENR, lun0, control_file, ERROR=err, /GET_LUN

WHILE NOT (EOF(lun0)) DO BEGIN 

   keeper=1     ; initialize to OK
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
   nsites = FIX( parsed[4] )
   DATESTAMP = parsed[5]      ; in YYMMDD format
   subset = parsed[6]

FOR igv=0,nsites-1  DO BEGIN
  ; read and parse the control file GV site ID, lat, lon, elev, filename, etc.
  ;  - read each overpassed site's information as a '|'-delimited string
   READF, lun0, dataGV
   IF ( keeper EQ 0 ) THEN GOTO, nextGVfile

  ; parse dataGV into its component fields: event_num, orbit number, siteID,
  ; overpass datetime, time in ticks, site lat, site lon, site elev,
  ; 1CUF file unique pathname

   nparsed = 0
   parsed=STRSPLIT( dataGV, '|', COUNT=nparsed, /extract )
   IF nparsed NE 9 THEN MESSAGE, "Incorrect number of fields in GV control file string."
   event_num = LONG( parsed[0] )
   orbitGV = parsed[1]
   siteID = parsed[2]    ; GPMGV siteID
   pr_dtime = parsed[3]
   pr_dtime_ticks = parsed[4]
   siteLat = FLOAT( parsed[5] )
   siteLon = FLOAT( parsed[6] )
   siteElev = FLOAT( parsed[7] )   ; required units are km !!!
   origUFName = parsed[8]  ; filename as listed in/on the database/disk,
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
      keeper=0
      GOTO, nextGVfile
   ENDIF

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
      keeper=0
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
      keeper=0
      GOTO, nextGVfile
   ENDIF

  ; get the number of elevation sweeps in the vol, and the array of elev angles
   num_elevations = get_sweep_elevs( z_vol_num, radar, elev_angle )
  ; make a copy of the array of elevations, from which we eliminate any
  ;   duplicate tilt angles for subsequent data processing/output
   uniq_elev_angle = elev_angle
   idx_uniq_elevs = UNIQ_SWEEPS(elev_angle, uniq_elev_angle)

   tocdf_elev_angle = elev_angle[idx_uniq_elevs]
   IF igv EQ 0 THEN first_angles = tocdf_elev_angle
   num_elevations_out = N_ELEMENTS(tocdf_elev_angle)
   IF num_elevations NE num_elevations_out THEN BEGIN
      print, ""
      print, "Duplicate sweep elevations ignored!"
      print, "Original sweep elevations:"
      print, elev_angle
   ENDIF
   IF igv GT 0 AND ARRAY_EQUAL(tocdf_elev_angle, first_angles) NE 1 THEN BEGIN
      print, "First set of elevations in set:"
      print, first_angles
      print, "Unique sweep elevations to be processed/output"
      print, tocdf_elev_angle
      keeper=0
   ENDIF

   nextGVfile:

ENDFOR    ; each GV site for orbit

IF ( keeper EQ 1 ) THEN BEGIN
   orbits2do[orbit2tag] = orbit
   nswps[orbit2tag] = num_elevations_out
   orbit2tag = orbit2tag+1
ENDIF

nextOrbit:

ENDWHILE  ; each orbit/PR file set to process in control file

ngood = orbit2tag

return, ngood

END
