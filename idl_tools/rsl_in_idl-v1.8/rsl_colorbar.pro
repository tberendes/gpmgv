;*****************************;
;        rsl_colorbar         ;   
;*****************************;

pro rsl_colorbar, field, xpos=xpos, ypos=ypos, color=color, $
    charsize=charsize, horizontal=horizontal, thick=thick

; This procedure adds a colorbar to the radar image.
;
; Arguments:
;    field:    String specifying the radar data field to use for color
;              placement, for example, 'DZ'.
;
; Keywords:
;    XPOS        X position of left side of color bar, in normalized
;                coordinates. Default is 0.95.
;    YPOS        Y position of top of color bar, in normalized coordinates.
;                Default is 0.9.
;    HORIZONTAL  Set this for horizontal color bar.  Default is vertical.
;    CHARSIZE:   IDL graphics character size.  Default is 1.
;
; TODO: Add options for height and width of colorbar.
;

fieldtype = strupcase(field)

; Make data labels for colorbar.  Fields that have the same units can
; share a field type for the purpose of labeling the color bar.  For example,
; DZ, CZ and ZT are all in units of dBZ.  Since labeling is defined for DZ in
; the case statement below, we can use that for all three fields.

if fieldtype eq 'CZ' or fieldtype eq 'ZT' then fieldtype = 'DZ'
if fieldtype eq 'ZV' or fieldtype eq 'TV' then fieldtype = 'DZ'
if fieldtype eq 'CR' or fieldtype eq 'CC' then fieldtype = 'DZ'
if fieldtype eq 'V2' or fieldtype eq 'V3' then fieldtype = 'VR'
if fieldtype eq 'S2' or fieldtype eq 'S3' then fieldtype = 'SW'
if fieldtype eq 'ZD' then fieldtype = 'DR'
if fieldtype eq 'DM' then fieldtype = 'D0'
units = ''

case fieldtype of
    'DZ': begin
       labels = ['70','65','60','55','50','45','40','35','30','25','20','15', $
           '10','5','0','<0']
       units = 'dBZ'
    end
    'VR': begin
       labels = ['RF','30','25','20','15','10','5','0','-5','-10','-15','-20',$
           '-25','-30']
       units = 'm/s'
    end
    'SW': begin
       labels = ['RF','22','20','18','16','14','12','10','8','6','4','2','0'] 
       units = 'm/s'
    end
    'DR': begin
       labels = ['>3.','3.0','2.5','2.0','1.5','1.0','0.5','0.0','-0.5','-1.0',$
           '-1.5','-2.0','-2.5','-3.0','<-3.']
       units = 'dB'
    end
    'KD': begin
       labels = ['>3.','3.0','2.5','2.0','1.5','1.0','0.5','0.0','-0.5','-1.0',$
           '-1.5','-2.0','<-2.']
       units = 'deg/km'
    end
    'RH': begin
       labels = ['.98','.96','.94','.92','.90','.88','.84','.80', $
           '.60','.40','.20','0.0']
       units = ''
    end
    'PH': begin
;       labels = ['165','150','135','120','105','90','75','60','45','30','15',$
;           '0']
; DBW change
       labels = ['330','300','270','240','210','180','150','120','90','60','30',$
           '0']
       units = 'deg'
    end
    'RR': begin
       labels = strtrim(80-indgen(17)*5,1) ; 80 to 0, increment -5.
       labels[16] = '1' ; use 1 to label lowest color in bar. 0 will be black.
       units = 'mm/hr'
       if n_elements(ypos) eq 0 then ypos = .95
    end
    'HC': begin
	labels = ['>6','6','5','4','3','2','1']
    end
    'D0': begin
       labels = reverse(string(findgen(16)*.25,f='(f3.1)'))
       units = 'mm'
    end
endcase

; If needed, set color bar starting coordinates.
if n_elements(xpos) eq 0 then xs =.95 else xs = xpos
if n_elements(ypos) eq 0 then ys =.9 else ys = ypos

; This adjusts coordinates if !p.multi is in use.
xs = !x.region[0] + xs * (!x.region[1] - !x.region[0])
ys = !y.window[0] + ys * (!y.window[1] - !y.window[0])
;print,'xs=',xs,',  ys=',ys ; testing

ncolors = n_elements(labels)
if not keyword_set(horizontal) then vertical = 1 else vertical = 0

; Use window size to set colorbar size.

if vertical then windowsize = !y.window[1] - !y.window[0] $
else windowsize = !x.window[1] - !x.window[0]
cbpctwin = .6
cbarlen = windowsize * cbpctwin

cbstart = (windowsize-cbarlen)/2.
cbseg = cbarlen/ncolors

if vertical then begin
    x = xs
    y = cbstart + !y.window[0]
    thickness = 20 ; TODO this should be scaled.
endif else begin
    y = ys
    x = cbstart + !x.window[0]
    thickness = 18 ; TODO this should be scaled.
endelse

if n_elements(thick) ne 0 then thickness = thick
;print, 'thickness = ', thickness ; testing
;print,'x=',x,',  y=',y,',  cbstart=',cbstart ; testing

plots,x,y,/norm
if vertical then y = y+(indgen(ncolors)+1)*cbseg $
else x = x+(indgen(ncolors)+1)*cbseg
plots,x,y,/norm,/cont,col=indgen(ncolors)+1,thick=thickness

; Write value labels on color scale.  Vertically center the labels.
; Note that labels need to be reversed here. This may (probably should) change.
if vertical then xyouts,xs,y-.75*cbseg, $
    reverse(labels),/normal,align=.5,color=0,charsize=charsize $
else begin
    chr_ht = float(!d.y_ch_size)/!d.y_size
    ylabpos = y-.4*chr_ht
    xyouts,x-.5*cbseg,ylabpos,reverse(labels),/normal,align=.5,color=0, $
        charsize=charsize
endelse

; Write units label.
if vertical then xyouts,x,y[ncolors-1]+.25*cbseg,units, $
    align=.5,charsize=charsize,/normal, color=color $
else xyouts,x[0]-1.5*cbseg,y,units,align=1.,charsize=charsize,/normal, $
    color=color

end
