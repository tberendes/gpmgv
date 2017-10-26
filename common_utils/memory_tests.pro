;===============================================================================
;+
;
; memory_tests.pro          Morris/SAIC/GPM_GV      April 2013
;
; DESCRIPTION
; -----------
; Driver routine for function memory_test_child().  Gets a list of 2A-12
; file names, and calls memory_test_child to do a bunch of file operations
; to see how memory use is affected.
;
; PARAMETERS
; ----------
; files2a12 - Optional list of 2A-12 files to process, overrides database query
;             method normally used to build the list of files.
; try_nc    - Binary parameter.  If set, then look for the PR netCDF files
;             matching the TMI 2A12 file if HDF-format files are not found.
; print_times - Binary option.  If set, then the elapsed time required to
;               complete major components of the matchup will be printed to
;               the terminal.
;
;===============================================================================

pro memory_tests, FILES2A12=files2a12, TRY_NC=try_nc, PRINT_TIMES=print_times

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

IF N_ELEMENTS( files2a12 ) NE 0 THEN BEGIN
   CASE N_ELEMENTS(STRSPLIT(files2a12, ' ', /extract)) OF
         1 : SQLSTR='cat '+files2a12 ;;
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

for i = 0, (num_events-1) do begin

   ; set up bailout prompt for every 5th matchup and/or static image case
   doodah = ""
;   IF i EQ 0 THEN GOTO, skipBail
;   IF i MOD 5 EQ 0 THEN BEGIN
;      PRINT, ''
;      READ, doodah, PROMPT='Hit Return to do next case, Q to Quit: '
;   ENDIF
;   IF doodah EQ 'Q' OR doodah EQ 'q' THEN break

   ; clear the prior static image, if it exists

   skipBail:

   print, event_data[i]
   ; if we have a filename with no path info, then prepend the well-known path
   IF FILE_DIRNAME(event_data[i]) EQ '.' THEN $
        tmi2a12file = datadirroot+'/prsubsets/2A12/'+event_data[i] $
   ELSE tmi2a12file = event_data[i]

   IF (print_times) THEN BEGIN
      print, ''
      print, '============================'
      print, "  Starting PR-TMI matchup."
      print, '============================'
      timestart=systime(1)
   ENDIF

   datastructure = memory_test_child( tmi2a12file, TRY_NC=try_nc, $
                                      PRINT_TIMES=print_times )

   IF (print_times) THEN BEGIN
      print, ''
      print, '======================================================'
      print, "  Finished.  Elapsed seconds: ", systime(1)-timestart
      print, '======================================================'
      print, ''
   ENDIF

   szback = SIZE(datastructure, /TYPE)
   IF szback NE 8 THEN BEGIN
      print, "No PR file match for case, skipping."
      continue
   ENDIF

endfor

print, "Done!"

noaction:
end
