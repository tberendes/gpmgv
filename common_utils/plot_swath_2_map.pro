;+
; Copyright © 2012, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; plot_swath_2_map.pro
;
; Produces map plot of along-swath, volume-matched PR, COM, or TMI rainrate
; (a.k.a. 'zdata'), in the form of:
;  1) an IDL Z-buffer, if ZBUF is set, or
;  2) plotted directly on screen if ZBUF and PSDIRECT are unset, or
;  3) directly to Postscript (or the current device) if ZBUF is unset and
;     PSDIRECT is set. 
;
; If ZBUF is set, then the Z-buffer is the function's return value, otherwise
; 0 is returned.
;
; HISTORY
; -------
; 12/12/12  Morris/GPM GV/SAIC
; - Created from plot_sweep_2_zbuf.pro.
; 03/16/13  Morris/GPM GV/SAIC
; - Added latitude and longitude bounds checks and limit adjustments.
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-


FUNCTION plot_swath_2_map, zdata, centerLat, centerLon, xpoly, ypoly, $
                           nscans, nrays, RNYTPE=rntype, FIELD=field, $
                           WINSIZ=winsiz, TITLE=title, ZBUF=zbuf, $
                           BGWHITE=bgwhite, PSDIRECT=psdirect

pixmap = KEYWORD_SET(zbuf)
psdirect = KEYWORD_SET(psdirect)

IF N_ELEMENTS( title ) EQ 0 THEN BEGIN
  title = 'TMI Rain Rate'
ENDIF
;print, title

IF N_ELEMENTS( field ) EQ 0 THEN field = 'CZ'
cref = KEYWORD_SET(cref)

; Declare function for color plotting.  It is in loadcolortable.pro.
forward_function mapcolors
winsize = 525
IF ( N_ELEMENTS(winsiz) EQ 1 ) THEN winsize = winsiz
xsize = winsize & ysize = xsize

; text/title position/size fit is based on default window size of 375, adjust
; for other window sizes via textfac multiplier
textfac = winsize/375.

;DEVICE, SET_RESOLUTION = [xsize,ysize], SET_CHARACTER_SIZE=[8,12]
IF pixmap THEN BEGIN
   SET_PLOT,'Z'
   DEVICE, SET_RESOLUTION = [xsize,ysize], SET_CHARACTER_SIZE=[8,12]
;   window, XSIZE=xsize, YSIZE=ysize, PIXMAP=pixmap
ENDIF ELSE BEGIN
   IF NOT psdirect THEN BEGIN
      SET_PLOT,'X'
      device, decomposed = 0, SET_CHARACTER_SIZE=[8,12]
      window, 1, XSIZE=xsize, YSIZE=ysize
   ENDIF
ENDELSE

;help, !D, /structure
error = 0
charsize = 0.75*textfac

if keyword_set(bgwhite) then begin
    prev_background = !p.background
    !p.background = 255
endif
if !p.background eq 255 then color = 0

; Get the map boundaries corresponding to max/min x and y.
meters_to_lat = 1. / 111177.
meters_to_lon =  1. / (111177. * cos(centerLat * !dtor))
max_x = MAX(xpoly, MIN=min_x)
max_y = MAX(ypoly, MIN=min_y)
mymap = MAP_PROJ_INIT('Mercator', CENTER_LON=centerLon, CENTER_LAT=centerLat)

nb = centerLat + (max_y+100.0) * 1000. * meters_to_lat 
sb = centerLat + (min_y-100.0) * 1000. * meters_to_lat 
eb = centerLon + (max_x+100.0) * 1000. * meters_to_lon 
wb = centerLon + (min_x-100.0) * 1000. * meters_to_lon 
IF ABS(eb-wb) GT 360. THEN BEGIN
;   print, "Old eb, wb: ", eb, wb
   adjlon = ( (ABS(eb-wb) - 360.0) + .0001 )/2.0
   eb -= adjlon
   wb += adjlon
;   message, "Adjusted long. bounds by "+ $
;      STRTRIM(STRING(adjlon, FORMAT='(F7.5)'))+" degrees.", /info
;   print, "Adjusted eb, wb: ", eb, wb
ENDIF
; adjust the map to be approximately square if rectangular beyond a threshold
ns=nb-sb
ew=(eb-wb)*cos(centerLat * !dtor)
aspect = ns GT ew ? ns/ew : ew/ns
if aspect GT 1.25 THEN BEGIN
;   print, "Aspect, old nb, sb, eb, wb: ", nb, sb, eb, wb
   if ns gt ew THEN BEGIN
      offset = (ns-ew)/3.0
      eb = eb+offset
      wb = wb-offset
   endif else begin
      offset = (ew-ns)/3.0
      nb = (nb+offset) < 80.0     ; can't plot beyond +/-80 degrees
      sb = (sb-offset) > (-80.0)
   endelse
;   print, "New nb, sb, eb, wb: ", nb, sb, eb, wb
endif

; Convert point corner x/y's to latitude and longitude coordinates using the
; same map projection used to compute x and y.
llcorners = MAP_PROJ_INVERSE(xpoly * 1000., ypoly * 1000., MAP_STRUC=mymap)
cornerlon = REFORM(llcorners[0,*], 4, nscans, nrays)
cornerlat = REFORM(llcorners[1,*], 4, nscans, nrays)

npts = 4
x = fltarr(npts)
y = fltarr(npts)
lat = fltarr(npts)
lon = fltarr(npts)

loadcolortable, field, error
if error then begin
    print, "error from loadcolortable"
    goto, bailout
endif

ray = zdata[*,*]
inegidx = where( ray lt 0, countneg )
if countneg gt 0 then ray[inegidx] = 0.0

color_index = mapcolors(ray, field)
if size(color_index,/n_dimensions) eq 0 then begin
    print, "error from mapcolors in PR array"
    goto, bailout
endif

; build 3 fill patterns: slanted, vertical, and solid
; array indices are opposite of what you might expect
npat = 4
pat1 = [0b,1b,1b,0b]
horiz = BYTARR(npat,npat)
FOR j = 0, npat-1 DO BEGIN
    ;horiz[j,*] = BYTE(j MOD 2)*1B
    horiz[j,*] = pat1
ENDFOR

vertical = BYTARR(npat,npat)
FOR i = 0, npat-1 DO BEGIN
  ;vertical[*,i] = BYTE(i MOD 2)*1B
  vertical[*,i] = pat1
ENDFOR

solid = BYTARR(npat,npat)
solid[*,*] = 1B

; redefine the map projection to equatorial mercator for plotting swath, by
; setting centerLat to 0.0
map_set, 0.0, centerLon, limit=[sb,wb,nb,eb],/grid, advance=advance, $
         charsize=charsize,color=color, /mercator, /isotropic

for iscan = 0, nscans-1 do begin
  for iray = 0, nrays-1 do begin
    lon = cornerlon[*,iscan,iray]
    lat = cornerLat[*,iscan,iray]
    ; Determine a fill pattern if rntype is provided
    IF N_ELEMENTS(rntype) GT 0 THEN BEGIN
       CASE rntype[iscan,iray] OF
         3 : pattern=solid      ; other
         2 : pattern=vertical   ; convective
         1 : pattern=horiz      ; stratiform
         ELSE : pattern=solid   ; not defined
       ENDCASE
       polyfill, lon, lat, /data,PATTERN=pattern*BYTE(color_index[iscan,iray])
    ENDIF ELSE polyfill, lon, lat, color=color_index[iscan,iray],/data
  endfor
endfor

map_grid, /label, lonlab=sb, latlab=wb, latalign=0.0,/noerase, $
    charsize=charsize, color=color
map_continents,/hires,/usa,/coasts,/countries, color=color

IF psdirect THEN thick=60  ; set a non-default width for colorbar for direct
                           ; plots to Postscript device
vn_colorbar, field, charsize=charsize, color=color, thick=thick

; add image labels
IF psdirect THEN xyouts, 0.01, 0.9, title,   $
                 CHARSIZE=1, COLOR=color, /NORMAL $
ELSE xyouts, FIX(5*textfac), ysize-FIX(15*textfac), title, CHARSIZE=1*textfac, $
     COLOR=color, /DEVICE

IF pixmap THEN bufout = TVRD() ELSE bufout = 0
bailout:
if keyword_set(bgwhite) then !p.background = prev_background

return, bufout
end
