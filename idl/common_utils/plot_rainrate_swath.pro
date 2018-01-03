;+
; Copyright © 2012, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; plot_rainrate_swath.pro
;
; DESCRIPTION
; -----------
; Produces map plot of along-swath, volume-matched PR, COM, and TMI
; rainrate ('zdata'), in either a static window (TMI only), or 
; in an animation window with all 3 data types.
;
; PARAMETERS
; ----------
; matchup       - structure containing  along-swath, volume-matched PR, COM,
;                 and TMI rainrate fields and metadata fields
;
; animate       - binary keyword parameter, indicates whether 
;
; precut        - binary keyword parameter, indicates whether the matchup data
;                 fields have already been pared down to the TMI footprints
;                 within the narrower PR swath (PRECUT=1), or all the TMI
;                 footprints in the TMI swath are included in the matchup data
;                 arrays (PRECUT=0, or unset/unspecified).
;
; do_ps         - binary keyword parameter, indicates whether to write/plots the
;                 output to a Postscript file.
;
; HISTORY
; -------
; 12/12/12  Morris/GPM GV/SAIC
; - Created.
; 03/16/13  Morris/GPM GV/SAIC
; - Added logic to handle precut structure values recieved from updated matchup
;   routine.
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-

pro plot_rainrate_swath, matchup, ANIMATE=animate, PRECUT=precut, DO_PS=do_ps

orig_device = !D.NAME

winsiz = 525  ; hard code for now
zbuf = 1
animate = KEYWORD_SET(animate)
precut = KEYWORD_SET(precut)
do_ps = KEYWORD_SET(do_ps)
IF ( N_ELEMENTS(winsiz) EQ 1 ) THEN winsize = winsiz
xsize = winsize & ysize = xsize

IF (precut) THEN BEGIN
   sz = SIZE(matchup.tmirain)
   nscans = sz[1]
   nrays = sz[2]
   min_scan = 0
   max_scan = nscans-1
   min_ray = 0
   max_ray = nrays-1
   IF WHERE(tag_names(matchup) EQ 'MATCHUPMETA') NE -1 THEN BEGIN
      ; structure is from a read of the matchup netCDF file
      center_lat = matchup.matchupmeta.centerLat
      center_lon = matchup.matchupmeta.centerLon
      file2a12 = matchup.filesmeta.file_2a12
      parsed = STRSPLIT(file2a12, '.', /EXTRACT)
      orbit = LONG(parsed(2))
      version = matchup.matchupmeta.TRMM_version
   ENDIF ELSE BEGIN
      ; structure is from the matchup program
      center_lat = matchup.center_lat
      center_lon = matchup.center_lon
      orbit = matchup.orbit
      version = matchup.version
   ENDELSE
ENDIF ELSE BEGIN
   ; structure is from the matchup program, with no subsetting done
   nscans = matchup.max_scan - matchup.min_scan + 1
   nrays = matchup.max_ray - matchup.min_ray +1
   min_scan = matchup.min_scan
   max_scan = matchup.max_scan
   min_ray = matchup.min_ray
   max_ray = matchup.max_ray
   center_lat = matchup.center_lat
   center_lon = matchup.center_lon
   orbit = matchup.orbit
   version = matchup.version
ENDELSE
xcorners = matchup.xcorners[*,min_scan:max_scan, min_ray:max_ray]
ycorners = matchup.ycorners[*,min_scan:max_scan, min_ray:max_ray]
titlemeta = ' Rain Rate, Orbit '+STRING(orbit, FORMAT='(I0)')+ $
            ', '+version ;', V'+STRING(version, FORMAT='(I0)')

;IF do_ps THEN GOTO, psOnly

; plot the TMI rainrate on a map, either in a static window (animate=0) or
; in the Z-buffer if building an animation of all 3 rainrate sources (animate=1)
zdata = matchup.tmirain[min_scan:max_scan, min_ray:max_ray]
bufftmi = plot_swath_2_map(zdata, center_lat, center_lon, $
                           xcorners, ycorners, nscans, nrays, FIELD='RR', $
                           title = 'GMI'+titlemeta, WINSIZ=winsiz, $
                           ZBUF=zbuf, /BG)

; if ANIMATE is set, then plot all 3 rainrate sources in an animation window
IF (animate) THEN BEGIN
   print, ''
   print, "Building animation loop, please wait..."
   print, ''
   zdata = matchup.prrain[min_scan:max_scan, min_ray:max_ray]
   buffpr = plot_swath_2_map(zdata, center_lat, center_lon, $
                          xcorners, ycorners, nscans, nrays, FIELD='RR', $
                          title = 'GMI-mapped DPR'+titlemeta, WINSIZ=winsiz, $
                          ZBUF=zbuf, /BG)
   zdata = matchup.comrain[min_scan:max_scan, min_ray:max_ray]
   buffcom = plot_swath_2_map(zdata, center_lat, center_lon, $
                           xcorners, ycorners, nscans, nrays, FIELD='RR', $
                           title = 'GMI-mapped COM'+titlemeta, WINSIZ=winsiz, $
                           ZBUF=zbuf, /BG)
   SET_PLOT,'X'
   device, decomposed = 0, SET_CHARACTER_SIZE=[8,12]
   window, 1, XSIZE=xsize, YSIZE=ysize, pixmap=animate
   error=0
   loadcolortable, field, error
   if error then begin
       print, "error from loadcolortable"
   ;    goto, bailout
   endif
   xinteranimate, set=[xsize, ysize, 4], /TRACK
   TV, bufftmi
   xinteranimate, frame = 0, window=1
   TV, buffpr
   xinteranimate, frame = 1, window=1
   TV, buffcom
   xinteranimate, frame = 2, window=1
   TV, bufftmi
   xinteranimate, frame = 3, window=1
   print, "Click End Animation button to proceed to next case."
   xinteranimate, 3, /BLOCK
ENDIF ELSE BEGIN
   ; just display the one image
   SET_PLOT,'X'
   device, decomposed = 0, SET_CHARACTER_SIZE=[8,12]
   window, 1, XSIZE=xsize, YSIZE=ysize, pixmap=animate
   error=0
   loadcolortable, field, error
   if error then begin
       print, "error from loadcolortable"
   ;    goto, bailout
   endif
   TV, bufftmi
ENDELSE

psOnly:
IF do_ps THEN BEGIN
   set_plot,/copy,'ps'
   erase
   zdata = matchup.tmirain[min_scan:max_scan, min_ray:max_ray]
   bufftmi = plot_swath_2_map(zdata, center_lat, center_lon, $
                           xcorners, ycorners, nscans, nrays, FIELD='RR', $
                           title = 'TMI'+titlemeta, WINSIZ=winsiz, $
                           ZBUF=0, /BG, /PSDIRECT)
   IF (animate) THEN BEGIN
      erase
      zdata = matchup.prrain[min_scan:max_scan, min_ray:max_ray]
      buffpr = plot_swath_2_map(zdata, center_lat, center_lon, $
                          xcorners, ycorners, nscans, nrays, FIELD='RR', $
                          title = 'TMI-matched PR'+titlemeta, WINSIZ=winsiz, $
                          ZBUF=0, /BG, /PSDIRECT)
      erase
      zdata = matchup.comrain[min_scan:max_scan, min_ray:max_ray]
      buffcom = plot_swath_2_map(zdata, center_lat, center_lon, $
                           xcorners, ycorners, nscans, nrays, FIELD='RR', $
                           title = 'TMI-matched COM'+titlemeta, WINSIZ=winsiz, $
                           ZBUF=0, /BG, /PSDIRECT)
   ENDIF
ENDIF

SET_PLOT, orig_device


end

