; This file contains routines for mapping data to colors.
;
; When adding a new field, three routines must be modified.  Each routine
; contains a case statement which selects by radar field, and must be
; modified to include the new field.  The routines and modifications are as
; follows:
;
; Routine              Modification
;
; rsl_loadcolortable   Add color table for the new field.
;
; rsl_mapcolors        Add the algorithm for mapping the data to color table
;                      indexes.
;
; rsl_colorbar         Add the labels and units for the color bar.
;                      Note: rsl_colorbar is located in file rsl_colorbar.pro. 
;
;*****************************************************************************
;

;*****************************;
;        rsl_mapcolors        ;
;*****************************;

function rsl_mapcolors, ray, field

; This function takes the data from a ray and converts it to indexes to the
; color table.  It returns the indexes in an array of size nbins.
; If an error occurs, the function returns -1.

compile_opt hidden

coloray = -1
if ray.h.nbins eq 0 then goto, finished

range = ray.range[0:ray.h.nbins-1]
nyquist = ray.h.nyq_vel

fieldtype = strupcase(field)
if fieldtype eq 'CZ' or fieldtype eq 'ZT' then fieldtype = 'DZ'
if fieldtype eq 'ZV' or fieldtype eq 'TV' then fieldtype = 'DZ'
if fieldtype eq 'CR' or fieldtype eq 'CC' then fieldtype = 'DZ'
if fieldtype eq 'V2' or fieldtype eq 'V3' then fieldtype = 'VR'
if fieldtype eq 'S2' or fieldtype eq 'S3' then fieldtype = 'SW'
if fieldtype eq 'ZD' then fieldtype = 'DR'
if fieldtype eq 'DR' or fieldtype eq 'KD' then fieldtype = 'DR or KD'
if fieldtype eq 'DM' then fieldtype = 'D0'

case fieldtype of
    'DZ': begin
	maxval = 65.
	minval = 0.
        color_bin_size = 5. ; dBZ
	ncolors = (maxval - minval) / color_bin_size + 1.
	ncolors = ncolors + 2 ; include indexes for out-of-bounds colors.
	below_minval_color = 1
	above_maxval_color = ncolors
	color_offset = 2. ; 0 is reserved for black, 1 for below-minval color.
	coloray = long(range/color_bin_size + color_offset)
	s = where(range gt maxval)
	if size(s,/n_dimensions) gt 0 then coloray[s] = above_maxval_color
	s = where(range lt minval)
	if size(s,/n_dimensions) gt 0 then coloray[s] = below_minval_color 
	s = where(range lt -10000.) ; bad or missing value
	if size(s,/n_dimensions) gt 0 then coloray[s] = 0
    end
   'VR': begin
        rangefolded = 14
        color_bin_size = 5. ; m/s
	adjust = 7.5  ; adjust for negative values.
	coloray = long(range/color_bin_size + adjust)
	if nyquist gt 0. then begin
	    s = where(abs(range) gt nyquist)
	    if size(s,/n_dimensions) gt 0 then coloray[s] = rangefolded
	endif
	s = where(range lt -10000.) ; bad or missing value
	if size(s,/n_dimensions) gt 0 then coloray[s] = 0
    end
    'SW': begin
        color_bin_size = 2. ; m/s
	color_offset = 1.
        maxval = 21.
        high_color = 12
	rangefolded = 13
	coloray = long(range/color_bin_size + color_offset)
	s = where(range gt maxval)
	if size(s,/n_dimensions) gt 0 then coloray[s] = high_color
	if nyquist gt 0. then begin
	    s = where(range gt nyquist)
	    if size(s,/n_dimensions) gt 0 then coloray[s] = rangefolded
	endif
	s = where(range lt -10000.) ; bad or missing value
	if size(s,/n_dimensions) gt 0 then coloray[s] = 0
    end
    'DR or KD': begin
	maxval = 3.
	if field eq 'DR' then minval = -3. else minval = -2.
        color_bin_size = .5 ; units: dBZ for DR, deg/km for KDP
	ncolors = (maxval - minval) / color_bin_size + 1.
	ncolors = ncolors + 2 ; include indexes for out-of-bounds colors.
	below_minval_color = 1
	above_maxval_color = ncolors
	color_offset = 2. ; 0 is reserved for black, 1 for below-minval color.
	adjust = color_offset + abs(minval)/color_bin_size ; for negative values
	coloray = long(range/color_bin_size + adjust)
	s = where(range gt maxval)
	if size(s,/n_dimensions) gt 0 then coloray[s] = above_maxval_color
	s = where(range lt minval)
	if size(s,/n_dimensions) gt 0 then coloray[s] = below_minval_color 
	s = where(range lt -10000.) ; bad or missing value
	if size(s,/n_dimensions) gt 0 then coloray[s] = 0
    end
    'RH': begin
	color_offset = 1

	; Most values should be greater than 0.8, so we want more detail
	; in that range.  Therefore the values are binned as follows:
	; 0. .2 .4 .6 .8 .84 .88 .90 .92 .94 .96 .98

        coloray = intarr(n_elements(range))
	s = where(range ge 0. and range lt .2)
	if size(s,/n_dimensions) gt 0 then coloray[s] = color_offset
	s = where(range ge .2 and range lt .4)
	if size(s,/n_dimensions) gt 0 then coloray[s] = color_offset + 1
	s = where(range ge .4 and range lt .6)
	if size(s,/n_dimensions) gt 0 then coloray[s] = color_offset + 2
	s = where(range ge .6 and range lt .8)
	if size(s,/n_dimensions) gt 0 then coloray[s] = color_offset + 3
	s = where(range ge .8 and range lt .84)
	if size(s,/n_dimensions) gt 0 then coloray[s] = color_offset + 4
	s = where(range ge .84 and range lt .88)
	if size(s,/n_dimensions) gt 0 then coloray[s] = color_offset + 5
	s = where(range ge .88 and range lt .90)
	if size(s,/n_dimensions) gt 0 then coloray[s] = color_offset + 6
	s = where(range ge .90 and range lt .92)
	if size(s,/n_dimensions) gt 0 then coloray[s] = color_offset + 7
	s = where(range ge .92 and range lt .94)
	if size(s,/n_dimensions) gt 0 then coloray[s] = color_offset + 8
	s = where(range ge .94 and range lt .96)
	if size(s,/n_dimensions) gt 0 then coloray[s] = color_offset + 9
	s = where(range ge .96 and range lt .98)
	if size(s,/n_dimensions) gt 0 then coloray[s] = color_offset + 10
	s = where(range ge .98)
	if size(s,/n_dimensions) gt 0 then coloray[s] = color_offset + 11
    end
    'PH': begin
        ncolors = 12

        ; Range: 0 to 179 degrees.
        color_bin_size = 180./ncolors ; deg
        ; Range: 0 to 360 degrees.
        color_bin_size = 360./ncolors ; deg

        color_offset = 1
        coloray = intarr(n_elements(range))
        s = where(range gt -10000.) ; good data
        if size(s,/n_dimensions) gt 0 then $
           coloray[s] = fix(range[s]/color_bin_size + color_offset)
     end
    'RR': begin
	maxval = 80.
	minval = 0.
        color_bin_size = 5. ; mm/hr
	ncolors = (maxval - minval) / color_bin_size + 1.
	color_offset = 1. ; 0 is reserved for black.
	coloray = long(range/color_bin_size + color_offset)
	s = where(range le 0.) ; 0. or missing value
	if size(s,/n_dimensions) gt 0 then coloray[s] = 0
	s = where(range gt maxval)
	if size(s,/n_dimensions) gt 0 then coloray[s] = ncolors
    end
    'HC': begin
	coloray = long(range)
	; 1 byte HC or 2?
	if max(coloray) le 255 then maxval=255 else maxval=65535
	s = where(range eq 0 or range eq maxval or range lt -10000.)
	if size(s,/n_dimensions) gt 0 then coloray[s] = 0
    end
    'D0': begin
        maxval = 4.
        minval = 0.
        color_bin_size = .25
	ncolors = (maxval - minval) / color_bin_size + 1.
	color_offset = 1. ; 0 is reserved for black.
	coloray = long(range/color_bin_size + color_offset)
	s = where(range le 0.) ; 0. or missing value
	if size(s,/n_dimensions) gt 0 then coloray[s] = 0
	s = where(range gt maxval)
	if size(s,/n_dimensions) gt 0 then coloray[s] = ncolors
    end
endcase

finished:
return, coloray
end ; rsl_mapcolors

;*****************************;
;      rsl_loadcolortable     ;
;*****************************;

pro rsl_loadcolortable, field, error

; Load colortable for radar images.

compile_opt hidden

r = indgen(256)
g = r
b = r

if n_elements(field) eq 0 then field = 'DZ'

fieldtype = strupcase(field)
if fieldtype eq 'CZ' or fieldtype eq 'ZT' then fieldtype = 'DZ'
if fieldtype eq 'ZV' or fieldtype eq 'TV' then fieldtype = 'DZ'
if fieldtype eq 'CR' or fieldtype eq 'CC' then fieldtype = 'DZ'
if fieldtype eq 'V2' or fieldtype eq 'V3' then fieldtype = 'VR'
if fieldtype eq 'S2' or fieldtype eq 'S3' then fieldtype = 'SW'
if fieldtype eq 'ZD' then fieldtype = 'DR' ; Darwin uses ZD for DR.
if fieldtype eq 'DM' then fieldtype = 'D0'

case fieldtype of
    'DZ': begin
      r[0:16]= [0,102,153,  0,  0, 0,  0,  0, 0,255,255,255,241,196,151,239,135]
      g[0:16]= [0,102,153,218,109, 0,241,190,139,253,195,138, 0,  0,  0,  0, 35]
      b[0:16]= [0,102,153,223,227,232, 1,  0,  0,  0,  0,  0, 0,  0,  0,255,255]
    end
    'VR': begin
      vr_zero = 255 ; white for black background.
      if !p.background eq 255 then vr_zero = 231 ; gray for white background.
      r[0:14]= [0,  0,  0,  0,  0,  0,  0, vr_zero, 246,255,255,241,196,151,239]
      g[0:14]= [0,  0,109,218,139,190,241, vr_zero, 246,195,138,  0,  0,  0,  0]
      b[0:14]= [0,232,223,227,  0,  0,  1, vr_zero,   0,  0,  0,  0,  0,  0,255]
    end
    'SW': begin
      r[0:13]= [0,  0,  0,  0,   0,   0,   0, 255, 255, 255, 241, 196, 151, 239]
      g[0:13]= [0, 218, 109,  0, 241, 190, 139, 253, 195, 138,    0,  0, 0,   0]
      b[0:13]= [0, 223, 227, 232,  1,   0,   0,   0,   0,   0,    0,  0, 0, 255]
    end
    'DR': begin
      r[0:15]= [0,153,  0,  0, 0,  0,  0,  0,255,255,255,241,196,151,239,135]
      g[0:15]= [0,153,218,109, 0,241,190,139,253,195,138,  0,  0,  0,  0, 35]
      b[0:15]= [0,153,223,227,232, 1,  0,  0,  0,  0,  0,  0,  0,  0,255,255]
    end
    'KD': begin
      r[0:13]= [0,  0,  0,  0,  0,  0,255,255,255,241,196,151,239,135]
      g[0:13]= [0,218,  0,241,190,139,253,195,138,  0,  0,  0,  0, 35]
      b[0:13]= [0,223,232,  1,  0,  0,  0,  0,  0,  0,  0,  0,255,255]
    end
    'RH': begin
      r[0:12]= [0,  0,  0,  0,  0,  0,  0,246,255,255,241,196,151]
      g[0:12]= [0,  0,109,218,139,190,241,246,195,138,  0,  0,  0]
      b[0:12]= [0,232,223,227,  0,  0,  1,  0,  0,  0,  0,  0,  0]
    end
    'PH': begin
      r[0:12]= [0,  0,  0,  0,  0,  0,  0,246,255,255,241,196,151]
      g[0:12]= [0,  0,109,218,139,190,241,246,195,138,  0,  0,  0]
      b[0:12]= [0,232,223,227,  0,  0,  1,  0,  0,  0,  0,  0,  0]
    end
    'HC': begin
      r[0:7]= [0, 72,   0,   0, 153,   0, 239, 135]
      g[0:7]= [0, 72, 109, 218, 153, 241,   0,  35]
      b[0:7]= [0, 72, 227, 223, 153,   0, 255, 255]
    end
    'RR': begin
      r[0:17]= [0,102,  0, 0, 0, 0, 0, 0, 0,255,255,255,241,196,151,239,135,255]
      g[0:17]= [0,153,153,218,109, 0,241,190,139,253,195,138,0,0, 0,  0, 35,255]
      b[0:17]= [0,153,153,223,227,232, 1,  0,  0,  0,  0,  0,0,0, 0,255,255,255]
    end
    'D0': begin
      r[0:16]= [0,102,153,  0,  0, 0,  0,  0, 0,255,255,255,241,196,151,239,135]
      g[0:16]= [0,102,153,218,109, 0,241,190,139,253,195,138, 0,  0,  0,  0, 35]
      b[0:16]= [0,102,153,223,227,232, 1,  0,  0,  0,  0,  0, 0,  0,  0,255,255]
    end
    else: begin
        message, "Unknown field '" + field + "'.", /informational
	print,"  Suggestion: Try using LIKE_FIELD keyword.  For example"
	print,"    rsl_plotsweep_from_radar, radar, field='"+field+$
	    "', like_field='DZ'"
	error = 1
	return
    end
endcase

; Make the last color white.  Plotting routines use this for axes, grids, etc.

r[255] = 255
g[255] = 255
b[255] = 255

tvlct, r, g, b  ; load colortable.

end ; rsl_loadcolortable
