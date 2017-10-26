;===============================================================================
;+
; Copyright © 2008, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; plot_elevation_gv_to_pr_z.pro          Morris/SAIC/GPM_GV      September 2008
;
; DESCRIPTION
; -----------
; This file is derived from the TRMM-GV Radar Software Library (RSL) routine
; rsl_plotsweep.pro, for the specific purposes of PR and GV data plotting
; in the GPM-GV polar2pr() procedure.  It plots the polygons defined by the
; borders of PR 'footprints' with valid reflectivities on a map background,
; with the fill color of the polygon defined by the reflectivity value of the
; corresponding data point.  PR and GV reflectivity data are plotted in
; separate windows.
;
; HISTORY
; -------
; 9/2008 by Bob Morris, GPM GV (SAIC)
;  - Created, modeled on the RSL procedure rsl_plotsweep.pro
; 6/2009 by Bob Morris, GPM GV (SAIC)
;  - Fixed bug in hard-coding of elevation index in extraction of xpoly and
;    ypoly values for a given footprint and sweep number.
; 7/2009 by Bob Morris, GPM GV (SAIC)
;  - Changed call to rsl_colorbar to instead call vn_colorbar, so that colors
;    are correctly labeled.
; 2/2013 by Bob Morris, GPM GV (SAIC)
;  - Added loadcolortable.pro as included file to eliminate compile errors of
;    not finding mapcolors(), a separate function inside that file.
;
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;===============================================================================

@loadcolortable.pro   ;contains function mapcolors, loadcolortable not called

PRO plot_elevation_gv_to_pr_z, prz, gvz, radar_lat, radar_lon, xpoly, ypoly, $
                               nfootprints, ilev, TITLES=titles

IF N_ELEMENTS( titles ) NE 2 THEN BEGIN
  title0 = 'PR: level ' + STRING(ilev)
  title1 = 'GV: level ' + STRING(ilev)
ENDIF ELSE BEGIN
  title0 = titles[0]
  title1 = titles[1]
ENDELSE

device, decomposed=0
windowsize = 525
xsize = windowsize[0]
ysize = xsize
error = 0

;ilev = 0  ; sweep # to plot

window, 0, xsize=xsize, ysize=ysize, xpos = 75, TITLE = title0

if keyword_set(bgwhite) then begin
    prev_background = !p.background
    !p.background = 255
endif
if !p.background eq 255 then color = 0

maxrange = 200. ; kilometers


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

ray = prz[*,ilev]
inegidx = where( ray lt 0, countneg )
if countneg gt 0 then ray[inegidx] = 0.0

color_index = mapcolors(ray, 'CZ')
if size(color_index,/n_dimensions) eq 0 then begin
    print, "error from mapcolors in PR array"
    goto, bailout
endif

for ifoot = 0, nfootprints-1 do begin
x = xpoly[*,ifoot,ilev]
y = ypoly[*,ifoot,ilev]
; Convert points to latitude and longitude coordinates.
lon = radar_lon + meters_to_lon * x * 1000.
lat = radar_lat + meters_to_lat * y * 1000.
polyfill, lon, lat, color=color_index[ifoot],/data

endfor

map_grid, /label, lonlab=sb, latlab=wb, latalign=0.0,/noerase, $
    charsize=charsize, color=color
map_continents,/hires,/coasts,/rivers,/countries, color=color

for range = 50.,maxrange,50. do $
    plot_range_rings2, range, radar_lon, radar_lat, color=color

vn_colorbar, 'CZ', charsize=charsize, color=color

window, 1, xsize=xsize, ysize=ysize, xpos = 625, TITLE = title1

ray = gvz[*,ilev]
inegidx = where( ray lt 0, countneg )
if countneg gt 0 then ray[inegidx] = 0.0

color_index = mapcolors(ray, 'CZ')
if size(color_index,/n_dimensions) eq 0 then begin
    print, "error from mapcolors in GV array"
    goto, bailout
endif

for ifoot = 0, nfootprints-1 do begin
x = xpoly[*,ifoot,ilev]
y = ypoly[*,ifoot,ilev]
; Convert points to latitude and longitude coordinates.
lon = radar_lon + meters_to_lon * x * 1000.
lat = radar_lat + meters_to_lat * y * 1000.
polyfill, lon, lat, color=color_index[ifoot],/data

endfor

map_grid, /label, lonlab=sb, latlab=wb, latalign=0.0,/noerase, $
    charsize=charsize, color=color
map_continents,/hires,/coasts,/rivers,/countries, color=color

for range = 50.,maxrange,50. do $
    plot_range_rings2, range, radar_lon, radar_lat, color=color

vn_colorbar, 'CZ', charsize=charsize, color=color

bailout:

end
