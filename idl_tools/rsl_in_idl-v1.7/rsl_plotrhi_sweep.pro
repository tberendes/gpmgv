pro rsl_plotrhi_sweep, sweep, radar_h, maxrange=maxrange, $
        maxheight=maxheight, new_window=new_window, title=title, $
        windowsize=windowsize, about_field=aboutfield, like_field=like_field, $
        advance=advance, charsize=charsize, bgwhite=bgwhite, $
	cb_vertical=cb_vertical, _extra=extra

; Plot RHI radar image.
;
; Syntax:
;     rsl_plotrhi_sweep, sweep, radar_h [, MAXRANGE=value]
;         [, MAXHEIGHT=value] [, /NEW_WINDOW] [, WINDOWSIZE=windowsize]
;         [, LIKE_FIELD=string] [, ABOUT_FIELD=string]
;         [, TITLE=string] [, CHARSIZE=value]
;
; Arguments:
;    sweep:   Sweep structure.
;    radar_h: Radar header structure.  Provides time stamp and radar location.
;
; Keywords:
;    MAXRANGE:    Maximum range to be plotted, in kilometers.  Default is 250.
;    MAXHEIGHT:   Maximum height to be plotted, in kilometers.  Default is 15.
;    NEW_WINDOW:  Set this to open a new plot window.
;    TITLE:       Title to appear above plot.  Default is site name followed
;                 by date and time data was recorded.
;    WINDOWSIZE:  Window size in pixels.  Windowsize may be scalar or a 2
;                 element array.  If scalar, this value is used for the
;                 x and y lengths.  If an array, the first element is the
;                 x length, the second the y length.
;                 Setting this keyword causes a new plot window to be opened.
;    ABOUT_FIELD: Information about the field which will appear in TITLE.  This
;                 replaces the default field information, which is simply the
;                 field type, such as 'DZ' or 'VR'.
;    LIKE_FIELD:  String specifying the field type to use in selecting color
;                 table and data scaling.  This is necessary when the user
;                 has created a new field type not recognized by rsl_plotrhi.
;    CHARSIZE:    IDL graphics character size.  Default is 1.
;    BGWHITE:     Set this for white background.  Default is black.
;
; Written by:  Bart Kelley, SSAI, July 2007
;***************************************************************************

; Declare function for color plotting.  It is in rsl_loadcolortable.pro.
forward_function rsl_mapcolors

on_error, 2  ; Return to calling routine.

if radar_h.scan_mode ne 'RHI' then begin
    message,'radar.h.scan_mode is ' + radar.h.scan_mode + ', should be RHI.', $
        /continue
    return
endif

if n_elements(windowsize) gt 0 then begin
    xsize = windowsize[0]
    if n_elements(windowsize) eq 1 then ysize = xsize*.75 $
    else ysize = windowsize[1]
endif

nbadray = 0
error = 0
yomargin_set = 0

field = sweep.h.field_type
fieldinfo = field
if n_elements(like_field) ne 0 then begin
    field = like_field
    field = strupcase(field)
endif

if n_elements(aboutfield) gt 0 then fieldinfo = aboutfield

if not keyword_set(title) then begin
    ; Find good ray for azimuth.
    for iray=0, sweep.h.nrays-1 do begin
	if sweep.ray[iray].h.nbins gt 0 then break
    endfor
    title = strtrim(radar_h.radar_name) + $
   string(radar_h.day, monthname(radar_h.month), radar_h.year, $
          radar_h.hour, radar_h.minute, fix(radar_h.sec), $
          format='(2x,i2.2," ",a3,i5,1x,i2.2,2(":",i2.2)," UTC  ")') + $
   'RHI  ' + fieldinfo + $
   '  Az: ' + strtrim(string(sweep.ray[iray].h.azimuth,format='(f5.1)'),1)
endif

if sweep.h.beam_width le 0. then begin
    message,'Can not plot because beam width =' + $
        string(sweep.h.beam_width,f='(f5.1)'),/continue
    return
endif

if keyword_set(new_window) or keyword_set(windowsize) then $
    rsl_new_window, xsize=xsize, ysize=ysize

; Increase top margin if more than 4 plots are being plotted in one window, so
; that title won't be squinched.

if !p.multi[1] * !p.multi[2] gt 4 and total(!y.omargin) eq 0 then begin
    !y.omargin[1] = 3.
    yomargin_set = 1
endif

npts = 4
x = fltarr(npts)
y = fltarr(npts)
lat = fltarr(npts)
lon = fltarr(npts)

half_beamwidth = sweep.h.beam_width / 2. * !DTOR

if n_elements(maxrange) eq 0 then maxrange = 250 ; kilometers
if n_elements(maxheight) eq 0 then maxheight = 15 ; kilometers
ht_limits = [0,maxheight]
rng_limits = [0,maxrange]

if keyword_set(bgwhite) then begin
    prev_background = !p.background
    !p.background = 255
endif
if !p.background eq 255 then color = 0

; Use PLOT with /NODATA to set up axes and titles.
plot, rng_limits, ht_limits, title=title, xtitle='Range (km)', $
    ytitle='Height (km)', /nodata, color=color, charsize=charsize, $
    _extra=extra

rsl_loadcolortable, field, error
if error then return

erad = 4./3. * 6374.  ; Effective earth radius in km.

for iray = 0, sweep.h.nrays - 1 do begin
    ray = sweep.ray[iray]
    if ray.h.nbins eq 0 then continue

    color_index = rsl_mapcolors(ray, field)
    if size(color_index,/n_dimensions) eq 0 then begin
	nbadray = nbadray + 1
	continue ; skip bad ray.
    endif

    ; Plot the value of each bin using polyfill.  Points for polyfill are
    ; computed at elevation angle +/- half-beamwidth at start and end of
    ; range bin.
    ; Equation to determine height from range and elevation is adapted from
    ; "RADAR For Meteorologists" by Ronald E. Rinehart.

    elev = ray.h.elev * !DTOR
    elevplus = elev + half_beamwidth
    elevminus = elev - half_beamwidth
    range_bin1 = ray.h.range_bin1 / 1000.
    gate_size = ray.h.gate_size / 1000.

    for ibin = 0, ray.h.nbins-1 do begin
	if color_index[ibin] eq 0 then continue

	; Convert elev and range to x and y.

	; Get polyfill vertices for beginning of this range bin.
	range = range_bin1 + float(ibin)*gate_size
	x[0] = range * cos(elevplus)
	y[0] = sqrt(range^2.+erad^2. +2*range*erad*sin(elevplus)) - erad
	x[1] = range * cos(elevminus)
	y[1] = sqrt(range^2.+erad^2. +2*range*erad*sin(elevminus))- erad

	; Get polyfill points for end of this range bin.
	range = range + gate_size
	x[2] = range * cos(elevminus)
	y[2] = sqrt(range^2.+erad^2. +2*range*erad*sin(elevminus))- erad
	x[3] = range * cos(elevplus)
	y[3] = sqrt(range^2.+erad^2. +2*range*erad*sin(elevplus)) - erad
	polyfill, x, y, color=color_index[ibin],/data, noclip=0
    endfor ; for each bin
endfor ; for each ray

; Draw horizontal colorbar unless vertical specified.
cb_horizontal = 1
if keyword_set(cb_vertical) then cb_horizontal = 0
rsl_colorbar, field, horizontal=cb_horizontal, color=color, _extra=extra

; This places NASA label in lower right corner of window, taking into account
; multiple plotting.
if !p.multi[0] eq 0 then begin
    x = .99 * !x.region[1]
    y = !y.region[0] + .01 * (!y.region[1] - !y.region[0])
    xyouts,x,y,'NASA/GPM',/normal,align=1.,color=color,charsize=charsize
endif
if n_elements(prev_background) ne 0 then !p.background = prev_background
end
