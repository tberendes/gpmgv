;===============================================================================
;+
; Copyright © 2012, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; get_model_sounding.pro -- Morris/SAIC/GPM_GV  May 2012
;
; DESCRIPTION
; -----------
; Reads isobaric temperature, relative humidity (RH), and u- and v-wind speeds
; from a user-selected North American Mesoscale Analysis (NAMANL) model analysis
; GRIB format data file, and extracts model soundings at locations of GPM VN
; WSR-88D sites overpassed by the TRMM PR for each orbit related to the model
; analysis time.  The relationships between the model analysis time, the TRMM
; orbits, and the WSR-88D sites in the PR area of coverage for each orbit are
; defined by data in the 'gpmgv' database, which is queried to determine the
; site sounding locations to be processed for the NAMANL file.
;
; Only sites within 250 km of the TRMM orbit subtracks are processed (i.e.,
; only those significantly overlapped by the TRMM Precipitation Radar (PR)
; swath.  Sites outside the PR swath but within the TRMM Microwave Imager (TMI)
; data swath are ignored.  This constraint is driven by the site overpass data
; tabulated in the 'gpmgv' database 'overpass_event' table.
;
; Requires IDL Version 8.1 or greater, with built-in GRIB read/write utilities.
;
; PARAMETERS
; ----------
; controlfile  - fully qualified path/name to the control file listing the GRIB
;                files and GR sites to be processed for soundings
; gribpath     - directory path to the NAM/NAMANL GRIB files to read
; rotfilepath  - fully qualified path/name to IDL "SAVE" file containing the
;                gridpoint latitude, longitude, and wind rotation angle variables
; verbose      - binary parameter, enables the output of diagnostic information
;                when set
;
; NON-SYSTEM ROUTINES CALLED
; --------------------------
; - extract_site_soundings_from_grib()
;   - find_alt_filename()
;   - grib_get_record()   (from Mark Piper's IDL GRIB webinar example code)
;   - uncomp_file()
; - write_site_sounding_netcdf()
;
; HISTORY
; -------
; 05/03/12 - Morris, GPM GV, SAIC
; - Created.
; 05/07/12- Morris, GPM GV, SAIC
; - Added surface soil temperature and moisture scalar variables to the sounding
;   VERBOSE print option, as they are now included in the sounding structures.
; 05/15/12- Morris, GPM GV, SAIC
; - Added ROTFILE keyword parameter for static IDL SAVE file holding the wind
;   rotation angles to convert from grid- to earth-relative wind components.
; 05/23/12- Morris, GPM GV, SAIC
; - Modified to accept a control file from the calling script, listing the GRIB
;   files to process and the sites to process for each set of GRIB files.
; - Added mandatory parameter for the path to which the output netCDF files are
;   written.
; 05/31/12 - Morris, GPM GV, SAIC
; - Added check on write_site_sounding_netcdf's status of writing the sounding
;   file metadata to 'gpmgv' database.  Exit processing on error.
;
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;===============================================================================

pro get_model_sounding, controlfile, gribpath, sndpath, ROTFILE=rotfilepath, $
                        VERBOSE=verbose

IF N_PARAMS() NE 3 THEN message, "Requires non-keyword parameters specifying" $
     +" the pathname of the control file and the paths to the GRIB files " $
     +" and the output netCDF sounding files."

cond1 = strlowcase(!version.os_family) eq 'windows'
cond2 = float(!version.release) lt 8.1
if cond1 || cond2 then message, 'IDL''s GRIB API requires 8.1; Mac OS X or Linux.'

; initialize the variables into which file records are read as strings
dataGRIB = ''
dataGR = ''
gribfilepath = STRARR(3)

; open and process control file, and generate the matchup data for the events

OPENR, lun0, controlfile, ERROR=err, /GET_LUN
WHILE NOT (EOF(lun0)) DO BEGIN 

  ; get filenames and count of GV sites to do for a forecast cycle
  ; - read the '|'-delimited input file record into a single string:
   READF, lun0, dataGRIB

  ; parse dataGRIB into its component fields: n_GV, cycle, GRIB analysis file name,
  ; GRIB 6h forecast file name, GRIB 3h forecast file name

   ctlparsed = STRSPLIT( dataGRIB, '|', /extract )
   num_sites = FIX(ctlparsed[0])
   cycle_dtime = ctlparsed[1]
   gribfile = ctlparsed[2]
   gribfile6 = ctlparsed[3]
   gribfile3 = ctlparsed[4]

  ; get the GRIB file's datestamp/cycle values from the file base name
   parsed = STRSPLIT(gribfile, '_', /extract )
   DATESTAMP = STRJOIN( parsed[2] )
   CYCLE = STRJOIN( parsed[3] )
  ; get the full pathnames to the GRIB files
   gribfilepath[0] = gribpath + '/' + gribfile
   gribfilepath[1] = gribpath + '/' + gribfile6
   gribfilepath[2] = gribpath + '/' + gribfile3

   IF KEYWORD_SET(verbose) THEN print, "DATESTAMP, CYCLE: ", DATESTAMP, '   ', CYCLE
   IF KEYWORD_SET(verbose) THEN print, "GRIB files: ", gribfilepath

   IF ( num_sites LT 1 ) THEN BEGIN
      message, "No/too few GR rows specified in control file."
   ENDIF ELSE BEGIN
     ; load the row data into arrays
      IF KEYWORD_SET(verbose) THEN PRINT, 'Total number of sites = ', num_sites
      site_arr   = STRARR(num_sites)
      lat_arr = FLTARR(num_sites)
      lon_arr = FLTARR(num_sites)
      datetimes_arr = STRARR(num_sites)

      FOR i=0,num_sites-1 DO BEGIN
         READF, lun0, dataGR
         parsed = strsplit( dataGR, '|', /extract )
         site_arr[i] = parsed[0]
;         datetimes_arr[i] = parsed[0]
         lat_arr[i] = float(parsed[1])
         lon_arr[i] = float( parsed[2] )
         IF KEYWORD_SET(verbose) THEN $
            print, site_arr[i], lat_arr[i], lon_arr[i]
      ENDFOR

      soundings = extract_site_soundings_from_grib( gribfilepath, $
                                                    site_arr,     $
                                                    lat_arr,      $
                                                    lon_arr,      $
                                                    SAVEFILE=rotfilepath, $
                                                    VERBOSE=verbose )

      if size(soundings, /type) EQ 8 then begin   ; 8 = 'STRUCT'
         print, '' & print, ''
         print, "Number of site soundings: " + string(n_elements(soundings), FORMAT='(I0)')
         ncfile = write_site_sounding_netcdf( soundings, DATESTAMP, CYCLE, gribfilepath, sndpath )
         IF ncfile[0] NE 'dbError' THEN BEGIN
         print, ncfile
         IF KEYWORD_SET(verbose) THEN BEGIN
           ; print the soundings
            fmtstr="(2X,F7.2,2X,'|',4X,F8.3,5X,'|',3X,F8.3,4X,'|',3X,F8.3,3X,'|',3X,F8.3)"
            for siteidx=0, n_elements(soundings)-1 do begin
               print, ''
               print, "Date: ", datestamp, "    Cycle: ", cycle
               print, "Site, Latitude, Longitude: ", (soundings)[siteidx].site, $
                      (soundings)[siteidx].latitude, (soundings)[siteidx].Longitude
               print, (soundings)[siteidx].soiltemp, FORMAT='("Surface soil temperature (K): ", F8.3)'
               print, (soundings)[siteidx].soilmoist, FORMAT='("Surface soil moisture (0.0-1.0): ", F8.3)'
               print, (soundings)[siteidx].precip6h, FORMAT='("6-h Total precipitation (kg/m^^2): ", F8.3)'
;               print, ''
               print, (soundings)[siteidx].n_levels, FORMAT='("Number of levels: ", I0)'
               print, ''
               print, "Level (mb) | Temperature (K) | Rel. Hum. (%) | U-wind (m/s) | V-wind (m/s)"
               print, "--------------------------------------------------------------------------"

               for ilev = 0, (soundings)[siteidx].n_levels - 1 do begin
                  print, (soundings)[siteidx].levels[ilev], (soundings)[siteidx].temperatures[ilev], $
                      (soundings)[siteidx].RH[ilev], (soundings)[siteidx].uwind[ilev], $
                      (soundings)[siteidx].vwind[ilev], FORMAT=fmtstr
               endfor
            endfor
         ENDIF
         ENDIF ELSE BEGIN
            print, "Error writing sounding file information!  Quitting."
            break
         ENDELSE
         print, ''
      endif else begin
         if size(soundings, /type) EQ 2 && soundings eq -1 then $
            print, "Error in extract_site_soundings_from_grib()." $
         else begin
            print, "Unknown status returned from extract_site_soundings_from_grib()."
            help, soundings
         endelse
      endelse
   ENDELSE

ENDWHILE  ; each GRIB file set to process in control file

end
