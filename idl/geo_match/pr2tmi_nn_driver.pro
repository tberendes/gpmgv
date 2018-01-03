;===============================================================================
;+
; Copyright © 2013, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; pr2tmi_nn_driver.pro          Morris/SAIC/GPM_GV      January 2013
;
; DESCRIPTION
; -----------
; Driver routine for function pr2tmi_nn().  Queries the 'gpmgv' database to get
; a list of 2A-12 file names for rainy cases, and calls pr2tmi_nn to generate
; TMI/PR rain rate matchups.  Provides options to request that the data be
; written to a netCDF file, and optionally displayed on the screen as either a
; static display of the TMI rain rate, or as an animation of the TMI with its
; resolution-matched PR and Combined PR-TMI rain rates, either on a map
; background or in a simple ray vs. scan image.  The user can specify the
; maximum radius from the nearest-neighbor TMI footprint center over which PR
; samples are averaged to produce a resolution-matched volume to the TMI data.
;
; PARAMETERS
; ----------
; display   - binary parameter, select whether or not to display the matchup
;             data as images.  Default=0 (do not display)
; animate   - if DISPLAY parameter is set to ON (1), then ANIMATE specifies the
;             type of data display to be shown.  Options are 0 (static image of
;             TMI rainrate on a map), 1 (animation of alternating images of TMI,
;             PR, and Combined PR/TMI rain rate on a map), or 2 (as in [1], but
;             as a simple image in ray vs. scan coordinates, with no geography).
;             Default=0 (static TMI image)
; write2nc  - Binary parameter, determines whether the matchup data are to be
;             written to a netCDF file or just computed and held in memory for
;             optional display.  Default = 0 (no netCDF file output).
; radius    - Determines maximum center-to-center distance between a TMI surface
;             footprint and the surface footprint locations of the PR samples
;             whose data values are to be averaged to produce a resolution
;             match to the TMI sample.
; path_out  - Override to the default path for the output netCDF files.  If
;             not specified, then the path will default to the directory
;             given by the combination of NCGRIDS_ROOT+PR_TMI_MATCH_NCDIR as
;             defined in the "include" file, environs.inc.
; files2a12 - Optional list of 2A-12 files to process, overrides database query
;             method normally used to build the list of files.
; try_nc    - Binary parameter.  If set, then look for the PR netCDF files
;             matching the TMI 2A12 file if HDF-format files are not found.
; print_times - Binary option.  If set, then the elapsed time required to
;               complete major components of the matchup will be printed to
;               the terminal.
;
;
; HISTORY
; -------
; 1/2013 by Bob Morris, GPM GV (SAIC)
;  - Created.
; 3/2013 by Bob Morris, GPM GV (SAIC)
;  - Added FILES2A12 keyword parameter and associated logic to read a list of
;    files to process from the file files2a12 in place of database query.
;  - Added PRINT_TIMES keyword parameter and associated logic to print elapsed
;    time for each matchup.
;  - Corrected the interactive logic dependent on number of files to process.
;  - Updated parameters for calls to pr2tmi_nn and plot_rainrate_swath.
; 03/28/13  Morris/GPM GV/SAIC
;  - Added TRY_NC keyword option to pass along to pr2tmi_nn().
; 04/10/13  Morris/GPM GV/SAIC
;  - Let FILES2A12 parameter value be in the form of a system command that
;    returns a list of files to process.  Add logic to determine whether the
;    value is a filename to be read, or a command to be executed.
; 04/11/13  Morris/GPM GV/SAIC
;  - Added binary keyword SKIP_EXISTING and related logic to skip the creation
;    of a new matchup netCDF file if one of the same name already exists.
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;===============================================================================

pro pr2tmi_nn_driver, DISPLAY=display, WRITE2NC=write2nc, RADIUS=radius, $
                      PATH_OUT=path_out, ANIMATE=animate, FILES2A12=files2a12, $
                      TRY_NC=try_nc, PRINT_TIMES=print_times, $
                      SKIP_EXISTING=skip_existing

; "Include" file for names, paths, etc.:
@environs.inc

display = KEYWORD_SET(display)
write2nc = KEYWORD_SET(write2nc)

IF N_ELEMENTS( animate ) NE 1 THEN BEGIN
   loopit = 0
ENDIF ELSE BEGIN
   CASE animate OF
      0 : loopit = 0
      1 : loopit = 1
      2 : loopit = 2
      ELSE : BEGIN
               print, "Invalid value for ANIMATE parameter, 0, 1, and 2 allowed."
               print, '0=no animation; 1=animate map; 2=animate ray/scan'
               print, "Setting to default, no animation."
             END
   ENDCASE
ENDELSE

print_times=KEYWORD_SET(print_times)

CASE GETENV('HOSTNAME') OF
   'ds1-gpmgv.gsfc.nasa.gov' : BEGIN
          datadirroot = '/data/gpmgv'
          IF N_ELEMENTS(path_out) NE 1 THEN path_out=datadirroot+'/tmp'
          END
   'ws1-gpmgv.gsfc.nasa.gov' : BEGIN
          datadirroot = '/data'
          IF N_ELEMENTS(path_out) NE 1 THEN path_out=datadirroot+'/tmp'
          END
   ELSE : BEGIN
          print, "Unknown system ID, setting path_out to user's home directory"
          datadirroot = '~/data'
          IF N_ELEMENTS(path_out) NE 1 THEN path_out='~'
          END
ENDCASE
IF write2nc THEN PRINT, "Assigning default output file path: ", path_out

; set the default radius if one is not provided or is out-of-range
IF N_ELEMENTS(radius) EQ 0 THEN BEGIN
   print, "Setting maximum radius from TMI footprint to 14 km" & print, ""
   radius = 14.0
ENDIF ELSE BEGIN
   IF (radius LT 10.0) OR (radius GT 50.0) THEN BEGIN
      print, "Radius must be between 10.0 and 50.0 km, supplied value = ", radius
      print, "Setting maximum radius from TMI footprint to 14 km" & print, ""
      radius = 14.0
   ENDIF
ENDELSE

IF N_ELEMENTS( files2a12 ) NE 0 THEN BEGIN
   CASE N_ELEMENTS(STRSPLIT(files2a12, ' ', /extract)) OF
         1 : SQLSTR='cat '+files2a12
         2 : SQLSTR=files2a12 ;;
      ELSE : message, 'Unable to process FILES2A12 parameter: '+files2a12 ;;
   ENDCASE
ENDIF ELSE BEGIN
   quote="'"
   SQLSTR='echo "\t \a \\\select a.filename from orbit_subset_product a join ' $
          +'rain_by_orbit_swath b using (orbit, subset, version) where '       $
          +'a.product_type = '+quote+'2A12'+quote+' and a.sat_id='+quote+'TMI' $
          +quote+' and (b.conv_ocean+b.strat_ocean) > 999 order by a.orbit;"'  $
          +' | psql -q -d gpmgv'
ENDELSE

;print, sqlstr
SPAWN, sqlstr, event_data, COUNT=num_events

IF ( num_events LT 1 ) THEN BEGIN
   message, "No rows returned from DB query: ", SQLSTR
ENDIF ELSE BEGIN
  ; print the query statistics
   PRINT, ""  &  PRINT, 'total number of events = ', num_events  &  PRINT, ""
ENDELSE

IF write2nc EQ 0 and display EQ 0 THEN BEGIN
   PRINT, ''
   PRINT, "No file or display output specified, skipping matchups.  Bye!"
   PRINT, ''
   GOTO, noaction
ENDIF

skippedLast = 0  ; indicates whether we skipped case of pre-existing netCDF

for i = 0, (num_events-1) do begin

   ; set up bailout prompt for every 5th matchup and/or static image case
   doodah = ""
   IF i EQ 0 THEN GOTO, skipBail
   IF (display AND (i MOD 5 EQ 0)) OR (display AND (loopit EQ 0)) THEN BEGIN
      PRINT, ''
      READ, doodah, PROMPT='Hit Return to do next case, Q to Quit: '
   ENDIF
   IF doodah EQ 'Q' OR doodah EQ 'q' THEN break

   ; clear the prior static image, if it exists
   IF display AND (loopit EQ 0) AND (skippedLast EQ 0) THEN WDELETE, 1

   skipBail:

   print, event_data[i]
   ; if we have a filename with no path info, then prepend the well-known path
   IF FILE_DIRNAME(event_data[i]) EQ '.' THEN $
      tmi2a12file = datadirroot+'/prsubsets/2A12/'+event_data[i] $
   ELSE tmi2a12file = event_data[i]

   parsed = STRSPLIT(FILE_BASENAME(tmi2a12file), '.', /EXTRACT)
   yymmdd = parsed[1]
   orbit = parsed[2]
   TRMM_vers = FIX(parsed[3])
   TRMM_vers_str = parsed[3]
   subset = parsed[4]
   ; Full orbit files from the DAAC have 'HDF' in the 5th section of the file name
   ; rather than the PPS convention of the orbit subset name.  Override it.
   IF subset EQ 'HDF' THEN BEGIN
      print, "Overriding non-existent orbit subset to 'FullOrbit'"
      subset = 'FullOrbit'
   ENDIF

   ; set up the output netCDF filename if we are writing one
;   ncfile_out = KEYWORD_SET( ncfile_out )
   IF write2nc THEN BEGIN
      ncfile_base = 'PRtoTMI_NN.' + yymmdd + '.' + orbit + '.' $
                    + TRMM_vers_str + '.' + subset + '_' $
                    + STRING(radius, FORMAT="(f0.1)") + 'km.nc'
      IF N_ELEMENTS(path_out) EQ 0 THEN $
         ncfile_out = NCGRIDS_ROOT+PR_TMI_MATCH_NCDIR+'/'+ncfile_base $
      ELSE ncfile_out = path_out + '/' + ncfile_base
      print,"" & print,"Writing output to netCDF file: ",ncfile_out & print,""
      ; check whether the output file already exists in some form (gzip or not)
      IF FIND_ALT_FILENAME(ncfile_out+'.gz', foundfile) NE 0 $
      AND KEYWORD_SET(skip_existing) THEN BEGIN
         message, "Already have output file: "+foundfile, /info
         print, "Skipping netCDF file output for orbit ", orbit & print, ""
         skippedLast = 1
         continue
      ENDIF ELSE skippedLast = 0
   ENDIF

   IF (print_times) THEN BEGIN
      print, ''
      print, "Starting PR-TMI matchup."
      timestart=systime(1)
   ENDIF

   datastructure = pr2tmi_nn( tmi2a12file, RADIUS=radius, $
                              NCFILE_OUT=ncfile_out, TRY_NC=try_nc, $
                              PRINT_TIMES=print_times )

   IF (print_times) THEN BEGIN
      print, "Finished PR-TMI matchup.  Elapsed seconds: ", systime(1)-timestart
   ENDIF

   szback = SIZE(datastructure, /TYPE)
   IF szback NE 8 THEN BEGIN
      print, "No PR file match for case, skipping."
      continue
   ENDIF

   IF (display) THEN BEGIN
      IF (datastructure.min_scan GE 0 AND datastructure.max_scan GE 0) THEN BEGIN
         CASE loopit OF
           0 : plot_rainrate_swath, datastructure, ANIMATE=loopit, /PRECUT
           1 : plot_rainrate_swath, datastructure, ANIMATE=loopit, /PRECUT
           2 : animate_rainrate_bscan, datastructure, /PRECUT
         ENDCASE
      ENDIF ELSE BEGIN
         print, "No data to show, min_scan or max_scan out of range: ", $
                datastructure.min_scan, datastructure.max_scan
      ENDELSE
   ENDIF
endfor

IF (display) AND (loopit EQ 0) AND (skippedLast EQ 0) THEN BEGIN
   IF i EQ 1 AND num_events EQ 1 THEN BEGIN
      PRINT, ''
      READ, doodah, PROMPT='Hit Return to finish: '
   ENDIF
   WDELETE, 1
ENDIF

print, "Done!"

noaction:
end
