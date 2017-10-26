;===============================================================================
;+
; Copyright © 2012, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; pr2tmi_driver.pro          Morris/SAIC/GPM_GV      December 2012
;
; DESCRIPTION
; -----------
; Driver routine for function pr2tmi().  Queries the 'gpmgv' database to get a
; list of 2A-12 file names for rainy cases, and calls pr2tmi to generate
; TMI/PR rain rate matchups.  Provides options to request that the data be
; written to a netCDF file, and optionally displayed on the screen as either a
; static display of the TMI rain rate, or as an animation of the TMI with its
; resolution-matched PR and Combined PR-TMI rain rates, either on a map
; background or in a simple ray vs. scan image.  The user can specify the radius
; from the TMI footprint center over which PR samples are averaged to produce a
; resolution-matched volume to the lower-resolution TMI data.
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
; path_out  - Optional override to the internally-determined destination
;             directory for the optional netCDF matchup files.
;
; HISTORY
; -------
; 12/2012 by Bob Morris, GPM GV (SAIC)
;  - Created.
;
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;===============================================================================

pro pr2tmi_driver, DISPLAY=display, WRITE2NC=write2nc, RADIUS=radius, $
                   PATH_OUT=path_out, ANIMATE=animate

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

quote="'"

SQLSTR='echo "\t \a \\\select a.filename from orbit_subset_product a join rain_by_orbit_swath b using (orbit, subset, version) where a.product_type = '+quote+'2A12'+quote+' and a.sat_id='+quote+'TMI'+quote+' and (b.conv_ocean+b.strat_ocean) > 999 order by a.orbit;" | psql -q -d gpmgv'

;print, sqlstr
SPAWN, sqlstr, event_data, COUNT=num_events

IF ( num_events LT 1 ) THEN BEGIN
   message, "No/too few rows returned from DB query: "+STRING(num_events,FORMAT='(I0)')
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

tmi_min=208
tmi_max=0
for i = 0, (num_events-1) do begin

   ; set up bailout prompt
   doodah = ""
   IF (display AND (i MOD 5 EQ 0)) OR (display AND (loopit EQ 0)) THEN BEGIN
      PRINT, ''
      READ, doodah, $
      PROMPT='Hit Return to do next case, Q to Quit: '
   ENDIF
   IF doodah EQ 'Q' OR doodah EQ 'q' THEN break

   print, event_data[i]
   tmi2a12file = datadirroot+'/prsubsets/2A12/'+event_data[i]
   datastructure = pr2tmi( tmi2a12file, RADIUS=radius, NCFILE_OUT=write2nc, PATH_OUT=path_out )
   szback = SIZE(datastructure, /TYPE)
   IF szback NE 8 THEN BEGIN
      print, "No PR file match for case, skipping."
      continue
   ENDIF
   IF datastructure.min_ray LT tmi_min THEN tmi_min = datastructure.min_ray
   IF datastructure.max_ray GT tmi_max THEN tmi_max = datastructure.max_ray
   IF (display) THEN BEGIN
      IF (datastructure.min_scan GE 0 AND datastructure.max_scan GE 0) THEN BEGIN
         CASE loopit OF
           0 : plot_rainrate_swath, datastructure, ANIMATE=loopit
           1 : plot_rainrate_swath, datastructure, ANIMATE=loopit
           2 : animate_rainrate_bscan, datastructure
         ENDCASE
      ENDIF ELSE BEGIN
         print, "No data to show, min_scan or max_scan out of range: ", $
                datastructure.min_scan, datastructure.max_scan
      ENDELSE
   ENDIF
endfor

IF (display) AND loopit EQ 0 THEN WDELETE, 1
;print, "Max, Min TMI Rays: ", tmi_max, tmi_min

noaction:
end
