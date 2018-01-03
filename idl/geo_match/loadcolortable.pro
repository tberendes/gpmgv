;===============================================================================
;+
; Copyright © 2008, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; loadcolortable.pro          Morris/SAIC/GPM_GV      September 2008
;
; DESCRIPTION
; -----------
; This file is a modified version of the TRMM-GV Radar Software Library routine
; rsl_loadcolortable.pro, for the specific purposes of PR and GV data plotting
; in the GPM-GV polar2pr() procedure.
;
; HISTORY
; -------
; 9/2008 by Bob Morris, GPM GV (SAIC)
;  - Created from rsl_loadcolortable.pro.
; 1/23/2012 by Bob Morris, GPM GV (SAIC)
;  - Modified (lightened) gray 1 and 2 for DZ colors.
; 1/31/2014 by Bob Morris, GPM GV (SAIC)
;  - Added FH, D0 and NW fields, cleaned up confusing documentation re. names
;    and locations of modules.
; 01/14/15 by Bob Morris
;  - Accept either D0 or Dm as the drop size parameter field ID.  Modified
;    color assignments for the D0/Dm and KD fields for the missing and below
;    threshold values.
; 04/28/15 by Bob Morris
;  - Accept any of RC, RP, or RR as rain rate field ID.  Map to RR colors.
; 08/25/15 by Bob Morris
;  - Accept either NW or N2 as Nw field ID.  Map to NW colors.
; 10/08/15 by Bob Morris
;  - Accept Z-R as rain rate field ID.  Map to RR colors.
; 08/15/16 by Bob Morris
;  - Added dRR (rain rate difference) and Tbb (brightness temperature) fields,
;    and added maxval/minval range checks for NW field.
;
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;===============================================================================

; This file contains routines for mapping data to colors.
;
; When adding a new field, three routines must be modified.  Each routine
; contains a case statement which selects by radar field, and which must be
; modified to include the new field.  The routines and modifications are as
; follows:
;
; Routine              Modification
; -------              ------------
; loadcolortable      (This file) Add color table for the new field.
;
; mapcolors           (This file) Add the algorithm for mapping the data to
;                     color table indexes.
;
; vn_colorbar         (In file common_utils/vn_colorbar.pro). Add the labels
;                     and units for the color bar.
;
;*****************************************************************************
;

;*****************************;
;          mapcolors          ;
;*****************************;

function mapcolors, ray, field

; This function takes the data from a ray and converts it to indexes to the
; color table.  It returns the indexes in an array of size nbins.
; If an error occurs, the function returns -1.

compile_opt hidden

coloray = -1
;if ray.h.nbins eq 0 then goto, finished

range = ray
nyquist=0.

fieldtype = field
if field eq 'CZ' or field eq 'ZT' then fieldtype = 'DZ'
if field eq 'ZD' then fieldtype = 'DR'
if field eq 'DR' or field eq 'KD' then fieldtype = 'DR or KD'
if field eq 'D0' or field eq 'Dm' then fieldtype = 'D0 or Dm'
if field eq 'RC' or field eq 'RP' or field eq 'RR' or field eq 'Z-R' $
   then fieldtype = 'RR'
if field eq 'N2' then fieldtype = 'NW'

case fieldtype of
    'DZ': begin
        maxval = 65.
        minval = 15.
        color_bin_size = 3. ; dBZ
        ncolors = (maxval - minval) / color_bin_size + 1.
        ncolors = ncolors + 2 ; include indexes for out-of-bounds colors.
        below_minval_color = 1
        above_maxval_color = ncolors
        color_offset = 2. ; 0 is reserved for black, 1 for below-minval color.
        coloray = long( ( (range-15.)>0. )/color_bin_size + color_offset)
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
        ncolors = ncolors + 3 ; include indexes for out-of-bounds colors.
        below_minval_color = 1
        above_maxval_color = ncolors-1
        color_offset = 2. ; 0 is reserved for black, 1 for below-minval color.
        adjust = color_offset + abs(minval)/color_bin_size ; for negative values
        coloray = long(range/color_bin_size + adjust)
        s = where(range gt maxval)
        if size(s,/n_dimensions) gt 0 then coloray[s] = above_maxval_color
        s = where(range lt minval and range ge -20.)
        if size(s,/n_dimensions) gt 0 then coloray[s] = below_minval_color 
        s = where(range lt -20.)  ; actual PR ray with no above-thresh PR/GR dBZ bins
        if size(s,/n_dimensions) gt 0 then coloray[s] = NCOLORS  ; NEEDED ANOTHER COLOR FOR THIS
    end
    'RH': begin
        color_offset = 1

        ; Since majority of values should be greater than 0.8, we want more
        ; detail in that range.  Therefore the values are binned as follows:
        ; 0. .2 .4 .6 .80 .84 .88 .90 .92 .94 .96 .98

        coloray = intarr(n_elements(range)) ; initialized with no data (=0).
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
        ; Range: 0 to 179 degrees.
        ncolors = 12
        color_bin_size = 180./ncolors ; deg
        color_offset = 1
        coloray = intarr(n_elements(range)) ; initialized with no data (=0).
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
    'FH': begin
        maxval = 10
        minval = 0
        color_bin_size = 1  ; categories 0-10
        ncolors = (maxval - minval) / color_bin_size + 1
        color_offset = 1   ; 0 is reserved for black.
        coloray = fix(range) + color_offset
        s = where(range gt maxval OR range lt minval)
        if size(s,/n_dimensions) gt 0 then coloray[s] = 0  ; assign to MISSING
    end
    'D0 or Dm': begin
        maxval = 7.0
        minval = 0.
        color_bin_size = 0.5
        ; need a color beyond top of expected range for bad/missing, so add 2
        ncolors = (maxval - minval) / color_bin_size + 2
        color_offset = 1   ; 0 is reserved for black.
        coloray = long(range/color_bin_size + color_offset)
        s = where(range le minval) ; missing value, include 0.0 average D0
        if size(s,/n_dimensions) gt 0 then coloray[s] = ncolors
        s = where(range gt maxval)
        if size(s,/n_dimensions) gt 0 then coloray[s] = ncolors
    end
    'NW': begin
        maxval = 7.0
        minval = 0.
        color_bin_size = 0.5
        ; need a color beyond top of expected range for bad/missing, so add 2
        ncolors = (maxval - minval) / color_bin_size + 2
        color_offset = 1   ; 0 is reserved for black.
        coloray = long(range/color_bin_size + color_offset)
        s = where(range le minval, nbad) ; missing value
        if nbad gt 0 then coloray[s] = ncolors
        s = where(range gt maxval, nbad)
        if nbad gt 0 then coloray[s] = ncolors
    end
    'Tbb': begin
        maxval = 300.0
        minval = 90.
        color_bin_size = 15.0
        ; need a color beyond top of expected range for bad/missing, so add 2
        ncolors = (maxval - minval) / color_bin_size + 2
        color_offset = 1   ; 0 is reserved for black.
        coloray = long( ((range-minval)>0)/color_bin_size + color_offset)
        s = where(range le minval, nbad) ; missing value
        if nbad gt 0 then coloray[s] = ncolors
        s = where(range gt maxval, nbad)
        if nbad gt 0 then coloray[s] = ncolors
    end
    'dRR': begin
       ; rain rate differences - here are the color/label ranges
       ; labels = ['>50','25','10','5','1','.25','.1','0','-.1','-.25','-1','-5','-10','-25','<-50']
        abs_thresholds = [0.1,0.25,1.0,5.0,10.0,25.0,50.0]
        coloray = intarr(n_elements(range)) ; initialized with no data (=0).
       ; center the zero-difference point at color index 14
        idxthisdiff = WHERE( ABS(range) LT 0.1, countrng )
        if countrng GT 0 then coloray[idxthisdiff] = 14
       ; do the remaining thresholds with respect to the anchor color 14 (white)
       ; - see loadcolortable (below), and vn_colorbar.pro
        for irng = 0, n_elements(abs_thresholds)-1 do begin
           idxthisdiff = WHERE( range GT abs_thresholds[irng], countrng )
           if countrng GT 0 then coloray[idxthisdiff] = 14+irng
           idxthisdiff = WHERE( range LT (-1)*abs_thresholds[irng], countrng )
           if countrng GT 0 then coloray[idxthisdiff] = 14-irng
        endfor
       ; - clip the differences at +/- 100.0 mm/h
        idxthisdiff  = WHERE( ABS(range) GT 100., countrng )
        if countrng GT 0 then coloray[idxthisdiff] = 0
    end
endcase

finished:
return, coloray
end    ; mapcolors module

;*****************************;
;        loadcolortable       ;
;*****************************;

pro loadcolortable, field, error

; Load colortable for radar images.

compile_opt hidden

r = indgen(256)
g = r
b = r

if n_elements(field) eq 0 then field = 'DZ'

fieldtype = field
if field eq 'CZ' or field eq 'ZT' then fieldtype = 'DZ'
if field eq 'ZD' then fieldtype = 'DR' ; Darwin uses ZD for DR.
if field eq 'D0' or field eq 'Dm' then fieldtype = 'D0 or Dm'
if field eq 'RC' or field eq 'RP' or field eq 'RR' or field eq 'Z-R' $
   then fieldtype = 'RR'
if field eq 'N2' then fieldtype = 'NW'

case fieldtype of
    'DZ': begin
      r[0:16]= [0,92,183,  0,  0, 0,  0,100,  0,255,255,255,241,196,151,239,135]
      g[0:16]= [0,92,183,218,109, 0,241,190,139,253,195,138,  0,  0,  0,  0, 35]
      b[0:16]= [0,92,183,223,227,232, 1,  0,100,  0,  0,  0,  0,  0,  0,255,255]
      r[17:32]= [238,189, 95,  0,255,255,106,250,255,173,128,188,210,165,128,102]
      g[17:32]= [130,183,158,255,160,105, 90,250,192,255,128,143,105, 42,  0,205]
      b[17:32]= [238,107,160,255,122,180,105,210,203, 47,  0,143, 30, 42,  0,170]
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
      r[0:16]= [0,183,  0,  0, 0,  0,  0,  0,255,255,255,241,196,151,239,135,92]
      g[0:16]= [0,183,218,109, 0,241,190,139,253,195,138,  0,  0,  0,  0, 35,92]
      b[0:16]= [0,183,223,227,232, 1,  0,  0,  0,  0,  0,  0,  0,  0,255,255,92]
    end
    'KD': begin
      r[0:14]= [0,  0,  0,  0,  0,  0,255,255,255,241,196,151,239,135,92]
      g[0:14]= [0,218,  0,241,190,139,253,195,138,  0,  0,  0,  0, 35,92]
      b[0:14]= [0,223,232,  1,  0,  0,  0,  0,  0,  0,  0,  0,255,255,92]
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
    'RR': begin
      r[0:17]= [0,102,  0, 0, 0, 0, 0, 0, 0,255,255,255,241,196,151,239,135,255]
      g[0:17]= [0,153,153,218,109, 0,241,190,139,253,195,138,0,0, 0,  0, 35,255]
      b[0:17]= [0,153,153,223,227,232, 1,  0,  0,  0,  0,  0,0,0, 0,255,255,255]
    end
    'FH': begin
      rgb_fh = BYTARR(3,11)  ; 11 hydromet ID categories, 0-10
      rgb_fh[*,0] = !COLOR.dark_cyan
      rgb_fh[*,1] = !COLOR.blue_violet
      rgb_fh[*,2] = !COLOR.blue
      rgb_fh[*,3] = !COLOR.orange
      rgb_fh[*,4] = !COLOR.pink
      rgb_fh[*,5] = !COLOR.cyan
      rgb_fh[*,6] = !COLOR.dark_gray
      rgb_fh[*,7] = !COLOR.lime_green
      rgb_fh[*,8] = !COLOR.yellow
      rgb_fh[*,9] = !COLOR.red
      rgb_fh[*,10] = !COLOR.magenta
      r[1:11] = rgb_fh[0,*]
      g[1:11] = rgb_fh[1,*]
      b[1:11] = rgb_fh[2,*]
    end
    'D0 or Dm': begin
      rgb2 = BYTARR(3,16)
      rgb2[*,0] = 210b ;!COLOR.gray
      rgb2[*,1] = !COLOR.cyan
      rgb2[*,2] = !COLOR.dodger_blue
      rgb2[*,3] = !COLOR.blue
      rgb2[*,4] = !COLOR.lime_green
      rgb2[*,5] = !COLOR.green
      rgb2[*,6] = !COLOR.dark_green
      rgb2[*,7] = !COLOR.yellow
      rgb2[*,8] = !COLOR.gold
      rgb2[*,9] = !COLOR.orange
      rgb2[*,10] = !COLOR.red
      rgb2[*,11] = !COLOR.firebrick
      rgb2[*,12] = !COLOR.dark_red
      rgb2[*,13] = !COLOR.magenta
      rgb2[*,14] = !COLOR.blue_violet
      rgb2[*,15] = 92b ;!COLOR.dim_gray ;black
      r[1:16] = rgb2[0,*]
      g[1:16] = rgb2[1,*]
      b[1:16] = rgb2[2,*]
    end
    'NW': begin
      rgb2 = BYTARR(3,16)
      rgb2[*,0] = 210b ;!COLOR.gray
      rgb2[*,1] = !COLOR.cyan
      rgb2[*,2] = !COLOR.dodger_blue
      rgb2[*,3] = !COLOR.blue
      rgb2[*,4] = !COLOR.lime_green
      rgb2[*,5] = !COLOR.green
      rgb2[*,6] = !COLOR.dark_green
      rgb2[*,7] = !COLOR.yellow
      rgb2[*,8] = !COLOR.gold
      rgb2[*,9] = !COLOR.orange
      rgb2[*,10] = !COLOR.red
      rgb2[*,11] = !COLOR.firebrick
      rgb2[*,12] = !COLOR.dark_red
      rgb2[*,13] = !COLOR.magenta
      rgb2[*,14] = !COLOR.blue_violet
      rgb2[*,15] = 92b ;!COLOR.black
      r[1:16] = rgb2[0,*]
      g[1:16] = rgb2[1,*]
      b[1:16] = rgb2[2,*]
    end
    'Tbb': begin
      rgb2 = BYTARR(3,16)
      rgb2[*,0] = 210b ;!COLOR.gray
      rgb2[*,1] = !COLOR.cyan
      rgb2[*,2] = !COLOR.dodger_blue
      rgb2[*,3] = !COLOR.blue
      rgb2[*,4] = !COLOR.lime_green
      rgb2[*,5] = !COLOR.green
      rgb2[*,6] = !COLOR.dark_green
      rgb2[*,7] = !COLOR.yellow
      rgb2[*,8] = !COLOR.gold
      rgb2[*,9] = !COLOR.orange
      rgb2[*,10] = !COLOR.red
      rgb2[*,11] = !COLOR.firebrick
      rgb2[*,12] = !COLOR.dark_red
      rgb2[*,13] = !COLOR.magenta
      rgb2[*,14] = !COLOR.blue_violet
      rgb2[*,15] = 92b ;!COLOR.black
      r[1:16] = rgb2[0,*]
      g[1:16] = rgb2[1,*]
      b[1:16] = rgb2[2,*]
    end
    'dRR': begin
      rgb24=[ $
      [0,0,0],$      ;black
      [255,255,255],$   ;white
      [105,105,105],$   ;dim gray
      [211,211,211],$   ;light gray
      [255,20,147],$    ;deep pink
      [255,105,180],$   ;hot pink
      [255,192,203],$   ;pink
      [255,0,0],$       ;red
      [255,160,122],$   ;light salmon
      [205,92,92],$     ;indian red
      [139,0,0],$       ;dark red
      [255,140,0],$     ;dark orange
      [255,205,0],$     ;gold
      [255,255,0],$     ;yellow
      [255,255,255],$   ;white
      [173,255,47],$    ;SpringGreen
      [128,128,0],$     ;olive
      [0,80,0],$        ;green
      [0,139,139],$     ;dark cyan
      [0,255,255],$     ;cyan
      [65,105,225],$    ;royal blue
      [0,0,255], $      ;blue
      [153,50,204],$    ;dark orchid
      [128,0,128],$     ;purple
      [255,0,255] $     ;magenta
      ]

      r[0:24]=rgb24[0,*]
      g[0:24]=rgb24[1,*]
      b[0:24]=rgb24[2,*]

      ; set up unassigned/missing areas as gray
      r[230:250] = 100b ;128b ; made darker to split gray from olive green
      g[230:250] = 100b ;128b
      b[230:250] = 100b ;128b
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

end    ; loadcolortable module
