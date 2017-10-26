;+
; Copyright © 2008, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; plot_sweep_2_zbuf_geo_vs_uf.pro
;
; Alternate version of plot_sweep_2_zbuf.pro, without encoding of rain type in
; the plotted polygons for the footprints (i.e., uses solid fill only).
; Produces PPI plot of PR or GV reflectivity 'zdata' at a selected sweep
; elevation angle index 'ilev', in the form of an IDL Z-buffer.  Returns the
; Z-buffer as the return value.
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-


;===============================================================================

FUNCTION plot_sweep_2_zbuf_geo_vs_uf, zdata, radar_lat, radar_lon, $
                                      xpoly, ypoly,  pr_index, nfootprints, $
                                      ilev, WINSIZ=winsiz, TITLE=title

IF N_ELEMENTS( title ) EQ 0 THEN BEGIN
  title = 'level ' + STRING(ilev)
ENDIF
print, title

; Declare function for color plotting.  It is in loadcolortable.pro.
forward_function mapcolors

SET_PLOT,'Z'
winsize = 525
IF ( N_ELEMENTS(winsiz) EQ 1 ) THEN winsize = winsiz
xsize = winsize & ysize = xsize
DEVICE, SET_RESOLUTION = [xsize,ysize]
error = 0
charsize = 0.75

if keyword_set(bgwhite) then begin
    prev_background = !p.background
    !p.background = 255
endif
if !p.background eq 255 then color = 0

maxrange = 125. ; kilometers

; Get the map boundaries corresponding to maxrange.
maxrange_meters = maxrange * 1000.
meters_to_lat = 1. / 111177.
meters_to_lon =  1. / (111177. * cos(radar_lat * !dtor))

nb = radar_lat + maxrange_meters * meters_to_lat 
sb = radar_lat - maxrange_meters * meters_to_lat 
eb = radar_lon + maxrange_meters * meters_to_lon 
wb = radar_lon - maxrange_meters * meters_to_lon 

map_set, radar_lat, radar_lon, limit=[sb,wb,nb,eb],/grid, advance=advance, $
    charsize=charsize,color=color

npts = 4
x = fltarr(npts)
y = fltarr(npts)
lat = fltarr(npts)
lon = fltarr(npts)

loadcolortable, 'CZ', error
if error then begin
    print, "error from loadcolortable"
    goto, bailout
endif

ray = zdata[*,ilev]
inegidx = where( ray lt 0, countneg )
if countneg gt 0 then ray[inegidx] = 0.0

color_index = mapcolors(ray, 'CZ')
if size(color_index,/n_dimensions) eq 0 then begin
    print, "error from mapcolors in PR array"
    goto, bailout
endif

for ifoot = 0, nfootprints-1 do begin
    if pr_index[ifoot] LT 0 THEN CONTINUE
    x = xpoly[*,ifoot,7]
    y = ypoly[*,ifoot,7]
   ; Convert points to latitude and longitude coordinates.
    lon = radar_lon + meters_to_lon * x * 1000.
    lat = radar_lat + meters_to_lat * y * 1000.
    polyfill, lon, lat, color=color_index[ifoot],/data
endfor

map_grid, /label, lonlab=sb, latlab=wb, latalign=0.0,/noerase, $
    charsize=charsize, color=color
map_continents,/hires,/usa,/coasts,/countries, color=color

for range = 50.,maxrange,50. do $
    plot_range_rings2, range, radar_lon, radar_lat, color=color

rsl_colorbar, 'CZ', charsize=charsize, color=color

; add image labels
   xyouts, 5, ysize-15, title, CHARSIZE=1, COLOR=255, /DEVICE

bufout = TVRD()
bailout:

return, bufout
end
