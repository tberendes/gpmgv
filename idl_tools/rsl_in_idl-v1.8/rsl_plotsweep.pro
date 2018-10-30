; Copyright (C) 2002-2003  NASA/TRMM Satellite Validation Office
;
; This program is free software; you can redistribute it and/or modify
; it under the terms of the GNU General Public License as published by
; the Free Software Foundation; either version 2 of the License, or
; (at your option) any later version.
;
; This program is distributed in the hope that it will be useful,
; but WITHOUT ANY WARRANTY; without even the implied warranty of
; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
; GNU General Public License for more details.
;
; You should have received a copy of the GNU General Public License
; along with this program; if not, write to the Free Software
; Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
;**************************************************************************
;

;*****************************;
;        rsl_plotsweep        ;
;*****************************;

pro rsl_plotsweep, sweep, radar_h, maxrange=maxrange, $
        new_window=new_window, title=title, about_field=aboutfield, $
	windowsize=windowsize, like_field=like_field, advance=advance, $
	charsize=charsize, cbarx=cbarx, cbary=cbary, $
	range_ring_interval=range_ring_interval, azim_spokes=azim_spokes, $
	bgwhite=bgwhite, _extra=extra, $
	range_azim_spokes=range_azim_spokes
;+
; Plot radar image for one sweep.
;
; Syntax:
;     rsl_plotsweep, sweep, radar_h  [, MAXRANGE=maxrange] [, /NEW_WINDOW]
;         [, TITLE=title] [, WINDOWSIZE=windowsize]
;         [, LIKE_FIELD=field_type] [, ABOUT_FIELD=field_description],
;         [, /ADVANCE] [, CHARSIZE=charsize] [, /BGWHITE]
;         [, AZIM_SPOKES=azim_spokes] [, RANGE_AZIM_SPOKES=range_azim_spokes]
;         [, RANGE_RING_INTERVAL=range_ring_interval]
;
; Inputs:
;    sweep:   Sweep structure.
;    radar_h: Radar header structure.  Provides time stamp and radar location.
;
; Keyword parameters:
;    MAXRANGE:    Maximum range to be plotted, in kilometers.  Default is 220
;                 unless the radar site is Kwajalein, in which case it is 200.
;    NEW_WINDOW:  Set this to open a new plot window.
;    TITLE:       Title to appear above plot.  Default is site name followed
;                 by date and time data was recorded.
;    WINDOWSIZE:  Window size in pixels.  Windowsize may be scalar or a 2
;                 element array.  If scalar, this value is used for the
;                 x and y lengths.  If an array, the first element is the
;                 x length, the second the y length.  Default is x = y = 525.
;                 Setting this keyword causes a new plot window to be opened.
;    ABOUT_FIELD: A string containing information about the field which will
;                 appear in TITLE.  This replaces the default field information,
;                 which is simply the field type (DZ, VR, . . .).
;    LIKE_FIELD:  String specifying the field type to use in selecting color
;                 table and data scaling.  This is necessary when the user
;                 has created a new field type not recognized by rsl_plotsweep.
;    ADVANCE:     This keyword is passed to IDL's MAP_SET procedure.  When set,
;                 and !P.MULTI is set, IDL advances to the next plot position
;                 in a multiple plots window.
;    AZIM_SPOKES: The interval in degrees between azimuth spokes.  The default
;                 is 30 degrees.  To prevent display of azimuth spokes, set
;                 AZIM_SPOKES to zero.
;    RANGE_AZIM_SPOKES:
;                 Range in kilometers for azimuth spokes, i.e., the range at
;                 which each spoke ends.  Default is the range of the outermost
;                 range ring.
;    RANGE_RING_INTERVAL:
;                 The interval between range rings, in kilometers. Default is
;                 50 km.  Set this to zero to turn off range ring display.
;    CHARSIZE:    IDL graphics character size.  Default is 1.
;    BGWHITE:     Set this for white background.  Default is black.
;
; Written by:  Bart Kelley, GMU, May 2002
;
; Based on plot_2a53 by David B. Wolff.
;
; Thanks to Eyal Amitai for his advice on making a scientifically meaningful
; color scale.
;**************************************************************************
;-

on_error, 2 ; On error, return to caller.

if radar_h.scan_mode eq 'RHI' then begin
    rsl_plotrhi_sweep, sweep, radar_h, maxrange=maxrange, $
        new_window=new_window, title=title, about_field=aboutfield, $
        windowsize=windowsize, like_field=like_field, advance=advance, $
	charsize=charsize, bgwhite=bgwhite, _extra=extra
    return
endif

; Declare function for color plotting.  It is in rsl_loadcolortable.pro.
forward_function rsl_mapcolors

if n_elements(windowsize) gt 0 then begin
    xsize = windowsize[0]
    if n_elements(windowsize) eq 1 then ysize = xsize else ysize = windowsize[1]
endif

nbadray = 0
error = 0
yomargin_set = 0

if n_params() lt 2 then begin
    message,'Missing argument.  Usage: rsl_plotsweep, sweep, radar.h', $
        /continue
    return
endif

field = sweep.h.field_type
fieldinfo = field
if n_elements(like_field) ne 0 then begin
    field = like_field
    field = strupcase(field)
endif
if n_elements(aboutfield) gt 0 then fieldinfo = aboutfield

if not keyword_set(title) then title = strtrim(radar_h.radar_name) + $
   string(radar_h.day, monthname(radar_h.month), radar_h.year, $
       radar_h.hour, radar_h.minute, fix(radar_h.sec), $
       format='(2x,i2.2," ",a3,i5,1x,i2.2,2(":",i2.2)," UTC  ")') + $
       fieldinfo + '  Elev: ' + strtrim(string(sweep.h.elev, format='(f6.2)'),1)

if keyword_set(new_window) or keyword_set(windowsize) then $
    rsl_new_window, xsize=xsize, ysize=ysize

; Increase top margin if more than 4 plots are being plotted in one window, so
; that title won't be squinched.

if !p.multi[1] * !p.multi[2] gt 4 and total(!y.omargin) eq 0 then begin
    !y.omargin[1] = 3.
    yomargin_set = 1
endif

if keyword_set(bgwhite) then begin
    prev_background = !p.background
    !p.background = 255
endif
if !p.background eq 255 then color = 0

if not keyword_set(maxrange) then $
    if strpos(radar_h.radar_name,'KWAJ') lt 0 then maxrange = 220. $
    else maxrange = 200. ; kilometers

; Get the map boundaries corresponding to maxrange.

radar_lat = radar_h.latd + radar_h.latm/60. + radar_h.lats/3600.
radar_lon = radar_h.lond +  radar_h.lonm/60. + radar_h.lons/3600.
maxrange_meters = maxrange * 1000.
meters_to_lat = 1. / 111177.
meters_to_lon =  1. / (111177. * cos(radar_lat * !dtor))

nb = radar_lat + maxrange_meters * meters_to_lat 
sb = radar_lat - maxrange_meters * meters_to_lat 
eb = radar_lon + maxrange_meters * meters_to_lon 
wb = radar_lon - maxrange_meters * meters_to_lon 

map_set, radar_lat, radar_lon, limit=[sb,wb,nb,eb],/grid, advance=advance, $
    charsize=charsize, color=color, _extra=extra

beam_width = sweep.h.beam_width
if beam_width le 0. then beam_width = 1.
half_beamwidth =  beam_width / 2. * !DTOR

; Widen beamwidth for smoother image.
widen = 1.1
if radar_h.radar_name eq 'CPOL' and sweep.h.beam_width lt 1.1 then widen = 1.4
half_beamwidth = half_beamwidth * widen

rsl_loadcolortable, field, error
if error then return

; Arrays for polyfill.
npts = 4
x = fltarr(npts)
y = fltarr(npts)
lat = fltarr(npts)
lon = fltarr(npts)

; Plot sweep.

for iray = 0, sweep.h.nrays - 1 do begin
	ray = sweep.ray[iray]
	if ray.h.nbins eq 0 then continue
	; Convert azimuth to polar angle (azimuth 0 = north; sweep
	; is clockwise).
	azimuth = ray.h.azimuth
	azimuth = 90. - azimuth
	if azimuth lt 0. then azimuth = azimuth + 360.

	azimuth = azimuth * !DTOR ; convert to radians.

	coloray = rsl_mapcolors(ray, field)
	if size(coloray,/n_dimensions) eq 0 then begin
	    nbadray = nbadray + 1
	    continue ; skip bad ray.
	endif

	; Plot the value of each bin using polyfill.  Points for polyfill are
	; computed at azimuth +/- half-beamwidth at start and end of range bin.

	for ibin = 0, ray.h.nbins-1 do begin
		if coloray[ibin] eq 0 then continue
		begin_of_bin = ray.h.range_bin1 + float(ibin)*ray.h.gate_size
		end_of_bin = begin_of_bin + ray.h.gate_size

		; Convert to cartesian coordinates for polyfill.  Note that
		; in polar coordinates angle increases CCW, which means that
		; cos(azimuth + halfbw) < cos(azimuth - halfbw). I tend to
		; forget this when I haven't looked at the code in awhile.

		x[0] = begin_of_bin * cos(azimuth + half_beamwidth)
		y[0] = begin_of_bin * sin(azimuth + half_beamwidth)

		x[1] = begin_of_bin * cos(azimuth - half_beamwidth)
		y[1] = begin_of_bin * sin(azimuth - half_beamwidth)

		x[2] = end_of_bin * cos(azimuth - half_beamwidth)
		y[2] = end_of_bin * sin(azimuth - half_beamwidth)

		x[3] = end_of_bin * cos(azimuth + half_beamwidth)
		y[3] = end_of_bin * sin(azimuth + half_beamwidth)
		
		; Convert points to latitude and longitude coordinates.
		lon = radar_lon + meters_to_lon * x
		lat = radar_lat + meters_to_lat * y
		polyfill, lon, lat, color=coloray[ibin],/data
	endfor ; for each bin
endfor ; for each ray
if nbadray gt 0 then message,'Warning: Sweep contained '+strtrim(nbadray,1)+$
    ' bad rays.',/informational

map_grid, /label, lonlab=sb, latlab=wb, latalign=0.0,/noerase, $
    charsize=charsize, color=color
map_continents,/hires,/coasts,/rivers,/countries, color=color

; Plot range rings.
if n_elements(range_ring_interval) eq 0 then range_ring_interval = 50.
if range_ring_interval eq 1 then range_ring_interval = 50. 
if range_ring_interval gt 0 then $
    for range = range_ring_interval, maxrange, range_ring_interval do $
	plot_range_rings2, range, radar_lon, radar_lat, color=color

; Overlay azimuth spokes.
if n_elements(azim_spokes) eq 0 then azim_spokes = 30.
if azim_spokes gt 0 then begin
    if range_ring_interval gt 0 and n_elements(range_azim_spokes) eq 0 then begin
	range_azim_spokes = floor(maxrange / range_ring_interval) $
	    * range_ring_interval
    endif
    ; If azim_spokes was set as a boolean keyword, use default interval.
    if azim_spokes eq 1 then azim_spokes = 30.
    rsl_draw_azimuth_spokes, radar_lon, radar_lat, azim_spokes, $
        maxrange=range_azim_spokes, color=color
endif

; Write title
; For !p.multi: adjust normal coordinates for ![xy].region
ytpos = !y.window[1]+(!y.region[1]-!y.window[1])/3.5
xtpos = !x.region[0] + .5 * (!x.region[1] - !x.region[0])
increase = 1.25 ; This is factor used by IDL to compute title character size.
titlecharsize = increase
if n_elements(charsize) ne 0 then titlecharsize = increase * charsize else $
    if !p.charsize ne 0. then titlecharsize = increase * !p.charsize
xyouts,xtpos,ytpos,title,/norm,charsize=titlecharsize,align=0.5,color=color

; Credit NASA/GPM
xtpos = !x.region[0] + .98 * (!x.region[1] - !x.region[0])
ytpos = !y.region[0] + .001 * (!y.region[1] - !y.region[0])
xyouts,xtpos,ytpos,'NASA/GPM',/normal,charsize=charsize,color=color, $
    align=1.

rsl_colorbar, field, xpos=cbarx, ypos=cbary, charsize=charsize, color=color, $
    _extra=extra

; Restore settings.
if yomargin_set then !y.omargin = 0.
if n_elements(prev_background) ne 0 then !p.background = prev_background
end
