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
;
; HISTORY
; -------
; 07/2009  Morris/GPM GV/SAIC  Changed color steps to 3 dBZ to match the
;                              geo-match data's PPI color scale by calling
;                              modified RSL routines loadcolortable, mapcolors
;                              and vn_colorbar.
; 04/2010  Morris/GPM GV/SAIC  Modified to accept MAXRNGKM keyword to plot over
;                              the maximum range of the data as indicated in
;                              the data files, rather than a fixed cutoff.

;*****************************;
;    rsl_plotsweep2pixmap     ;
;*****************************;

FUNCTION rsl_plotsweep2pixmap, sweep, radar_h, maxrange=maxrange, $
        new_window=new_window, title=title, about_field=aboutfield, $
	windowsize=windowsize, like_field=like_field, advance=advance, $
	charsize=charsize, cbarx=cbarx, cbary=cbary, $
	bgwhite=bgwhite, MAXRNGKM=maxrngkm, LATLON=latlon, _extra=extra
;
; Plot radar image for one sweep.
;
; Syntax:
;     rsl_plotsweep, sweep, radar_h  [, MAXRANGE=maxrange] [, /NEW_WINDOW]
;         [, TITLE=title] [, WINDOWSIZE=windowsize]
;         [, LIKE_FIELD=field_type] [, ABOUT_FIELD=field_description],
;         [, /ADVANCE] [, CHARSIZE=charsize] [, /BGWHITE]
;
; Inputs:
;    sweep:   a sweep structure.
;    radar_h: the radar header.
;
; Keyword parameters:
;    MAXRANGE:    Maximum range to be plotted, in kilometers.  This is used for
;                 scaling the image and is not necessarily the true maximum
;                 radar range.  Default is 220 unless the radar site is
;                 Kwajalein, in which case it is 200.
;    NEW_WINDOW:  Set this to open a new plot window.
;    TITLE:       Title to appear above plot.  Default is site name followed
;                 by date and time data was recorded.
;    WINDOWSIZE:  Window size in pixels.  Windowsize may be scalar or a 2
;                 element array.  If scalar, this value is used for the
;                 x and y lengths.  If an array, the first element is the
;                 x length, the second the y length.  Default is 525.
;    ABOUT_FIELD: Information about the field which will appear in TITLE.  This
;                 replaces the default field information, which is simply the
;                 field type (DZ, VR, . . .).
;    LIKE_FIELD:  String specifying the field type to use in selecting color
;                 table and data scaling.  This is necessary when the user
;                 has created a new field type not recognized by rsl_plotsweep.
;    ADVANCE:     This keyword is passed to IDL's MAP_SET procedure.  When set,
;                 and !p.multi is set, IDL advances to the next plot position
;                 in a multiple plots window.
;    CHARSIZE:    IDL graphics character size.  Default is 1.
;    BGWHITE:     Set this for white background.  Default is black.
;
; Written by:  Bob Morris, SAIC, GPM GV, Feb. 2009
; - Made into FUNCTION, now plots output to pixmap returned from the function
;   rather than directly to a WINDOW.
;
; Based on rsl_plotsweep by Bart Kelley, GMU, May 2002
; - Based on plot_2a53 by David B. Wolff.
;
; Thanks to Eyal Amitai for his advice on making a scientifically meaningful
; color scale.
;
; HISTORY
; -------
; 08/14/12 Morris, GPM GV, SAIC
; - Modified calling parameters to map_continents() to match those in
;   plot_sweep_2_zbuf.pro so that maps are the same in interleaved animations
;   in the cross sections program.
; - Added LATLON optional parameter to override the lat/lon fields in the
;   radar structure.  Is FLTARR(2), lat in first element, then lon, in decimal
;   degrees.
; - Set up text character sizes to match what is done in plot_sweep_2_zbuf.pro.
;
;**************************************************************************

on_error, 2 ; On error, return to caller.

; Declare function for color plotting.  It is in loadcolortable.pro.
forward_function mapcolors

SET_PLOT,'Z'
if not keyword_set(windowsize) then windowsize = 525
xsize = windowsize[0]
if n_elements(windowsize) eq 1 then ysize = xsize else ysize = windowsize[1]
DEVICE, SET_RESOLUTION = [xsize,ysize], SET_CHARACTER_SIZE=[8,12]
;charsize = 0.75
textfac = xsize/375.
charsize = 0.75*textfac

nbadray = 0
error = 0
yomargin_set = 0

if n_params() lt 2 then begin
    message,'Missing argument.  Usage: rsl_plotsweep,' + ' sweep, radar.h', $
        /continue
    return, 0
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

if sweep.h.beam_width le 0. then begin
    message,'Can not plot because beam width =' + $
        string(sweep.h.beam_width,f='(f5.1)'),/continue
    return, 0
endif

; If device is not Z-buffer, open a window for plotting.

;if !d.name ne 'Z' then begin
;    iwindow = !d.window
;    if iwindow eq -1 or keyword_set(new_window) then begin
;        iwindow = !d.window + 1
;        window, iwindow, xsize=xsize, ysize=ysize
;    endif
;endif

; Increase top margin if more than 4 plots are being plotted in one window, so
; that title won't be squinched.

;if !p.multi[1] * !p.multi[2] gt 4 and total(!y.omargin) eq 0 then begin
;    !y.omargin[1] = 3.
;    yomargin_set = 1
;endif

if keyword_set(bgwhite) then begin
    prev_background = !p.background
    !p.background = 255
endif
if !p.background eq 255 then color = 0

IF N_ELEMENTS( maxrngkm ) EQ 1 THEN maxrange = ( FIX(maxrngkm) / 25 + 1 ) * 25.0 $
ELSE maxrange = 125.

;if not keyword_set(maxrange) then $
;    if strpos(radar_h.radar_name,'KWAJ') lt 0 then maxrange = 220. $
;    else maxrange = 200. ; kilometers
;maxrange = 125. ; kilometers

; Get the map boundaries corresponding to maxrange.

IF N_ELEMENTS(latlon) NE 2 THEN BEGIN
   radar_lat = radar_h.latd + radar_h.latm/60. + radar_h.lats/3600.
   radar_lon = radar_h.lond +  radar_h.lonm/60. + radar_h.lons/3600.
ENDIF ELSE BEGIN
   radar_lat = latlon[0]
   radar_lon = latlon[1]
ENDELSE
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

half_beamwidth = sweep.h.beam_width / 2. * !DTOR

; Widen beamwidth for smoother image.
widen = 1.1
if radar_h.radar_name eq 'CPOL' and sweep.h.beam_width lt 1.1 then widen = 1.4
half_beamwidth = half_beamwidth * widen

loadcolortable, field, error
if error then return, 0

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
        range = ray.range[0:ray.h.nbins-1]  ;need to do this first for mapcolors
	color_index = mapcolors(range, field)
	if size(color_index,/n_dimensions) eq 0 then begin
	    nbadray = nbadray + 1
	    continue ; skip bad ray.
	endif

	; Plot the value of each bin using polyfill.  Points for polyfill are
	; computed at azimuth +/- half-beamwidth at start and end of range bin.

	for ibin = 0, ray.h.nbins-1 do begin
		if color_index[ibin] eq 0 then continue
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
		polyfill, lon, lat, color=color_index[ibin],/data
	endfor ; for each bin
endfor ; for each ray
if nbadray gt 0 then message,'Warning: Sweep contained '+strtrim(nbadray,1)+$
    ' bad rays.',/informational

map_grid, /label, lonlab=sb, latlab=wb, latalign=0.0,/noerase, $
    charsize=charsize, color=color
;map_continents,/hires,/coasts,/rivers,/countries, color=color
map_continents,/hires,/usa,/coasts,/countries, color=color

for range = 50.,maxrange,50. do $
    plot_range_rings2, range, radar_lon, radar_lat, color=color

; Write title
; For !p.multi: adjust normal coordinates for ![xy].region
ytpos = !y.window[1]+(!y.region[1]-!y.window[1])/3.5
xtpos = !x.region[0] + .5 * (!x.region[1] - !x.region[0])
increase = 1.25 ; This is factor used by IDL to compute title character size.
titlecharsize = increase
if n_elements(charsize) ne 0 then titlecharsize = increase * charsize else $
    if !p.charsize ne 0. then titlecharsize = increase * !p.charsize
xyouts,xtpos,ytpos,title,/norm,charsize=titlecharsize,align=0.5,color=color

; Credit NASA/TRMM Office.
xtpos = !x.region[0] + .98 * (!x.region[1] - !x.region[0])
ytpos = !y.region[0] + .001 * (!y.region[1] - !y.region[0])
xyouts,xtpos,ytpos,'NASA/TRMM Office',/normal,charsize=charsize,color=color, $
    align=1.

vn_colorbar, field, xpos=cbarx, ypos=cbary, charsize=charsize, color=color, $
    _extra=extra

; Restore settings.
if yomargin_set then !y.omargin = 0.
if n_elements(prev_background) ne 0 then !p.background = prev_background

bufout = TVRD()
return, bufout
end
