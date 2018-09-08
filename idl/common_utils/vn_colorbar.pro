;===============================================================================
;+
; Copyright © 2009, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; vn_colorbar.pro          Morris/SAIC/GPM_GV      July 2009
;
; DESCRIPTION
; -----------
; This file is a modified version of the TRMM-GV Radar Software Library routine
; rsl_colorbar.pro, for the specific purposes of PR and GV data plotting
; in the GPM-GV Validation Network geometry-matched data display procedures.
;
; HISTORY
; -------
; 7/2009 by Bob Morris, GPM GV (SAIC)
;  - Created from rsl_colorbar.pro.  Modified the scale for the DZ field
;    to use 3 dBZ steps from 15 dBZ.
; 07/29/09 by Bob Morris, GPM GV (SAIC)
;  - Made text colors for labels an array so that text would show up in either
;    light or dark background colors.  Only for DZ field case, for now.
; 1/23/2012 by Bob Morris, GPM GV (SAIC)
;  - Reversed text color (to black) for lightened gray 2 for DZ colors.
; 12/21/2012 by Bob Morris, GPM GV (SAIC)
;  - Made array of text colors for RR case, as for DZ, above.
; 1/31/2014 by Bob Morris, GPM GV (SAIC)
;  - Added FH (Hydromet Identifier) and D0 (median drop diameter) and NW
;    (normalized intercept parameter) fields.
; 12/04/14 by Bob Morris
;  - Renamed units for NW, can't fit actual units.  Changed some label text
;    colors and values to be visible and fit better.
; 01/14/15 by Bob Morris
;  - Removed MM label from top of D0 and Nw.  Changed 0.0 label to >0 and
;    changed its plotted color to black for D0 and Nw.
;  - Accept either D0 or Dm as the drop size parameter field ID.
; 04/28/15 by Bob Morris
;  - Accept any of RC, RP, or RR as rain rate field ID.  Map to RR colors.
; 08/25/15 by Bob Morris
;  - Accept either NW or N2 as Nw field ID.  Map to NW colors.
;  - Added optional unitscolor parameter to specifically set text color of
;    units label independently from color parameter.
; 10/08/15 by Bob Morris
;  - Accept Z-R as rain rate field ID.  Map to RR colors.
; 09/12/16 by Bob Morris
;  - Added dRR (rain rate difference) and Tbb (brightness temperature) fields.
;  - Added default assignment for COLOR parameter to avoid undefined errors.
;  - Added missing definitions of input parameters.
; 06/20/18 by Bob Morris
;  - Added AGL (height above ground in km) field, using DM scale.
; 09/07/18 Todd Berendes
;  - Added SW table for SWE RR
;
; TO DO: Add options for height and width of colorbar.
;
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;===============================================================================
;*****************************;
;         vn_colorbar         ;   
;*****************************;

pro vn_colorbar, field, xpos=xpos, ypos=ypos, color=color, $
    charsize=charsize, horizontal=horizontal, thick=thick, $
    unitscolor=unitscolor

; This procedure adds a value-labeled colorbar to a radar or other data image.
;
; Arguments:
;    field:    String specifying the radar data field to use for color bar
;              definition, for example, 'DZ'.  See note below.
;
; Keywords:
;    XPOS        X position of left side of color bar, in normalized
;                coordinates (0.0 <= xpos < 1.0 ). Default is 0.95. Ignored in
;                the case of a horizontal color bar.
;    YPOS        Y position of top of color bar, in normalized coordinates.
;                Default is 0.9. Ignored in the case of a vertical color bar.
;    COLOR       Color index to be used for plotting label values (text) in the
;                color bar.  Default=255 if not specified.
;    HORIZONTAL  Binary keyword.  Set this to 1 to plot a horizontal color bar.
;                Default (=0) is vertical.
;    CHARSIZE:   IDL graphics character size for text labels.  Default is 1.
;    THICK       Width in pixels of the colorbar.  Default is 20 (if vertical)
;                or 18 (if horizontal).
;    UNITSCOLOR  Color index to be used to plot the units label for the color
;                bar.  Defaults to COLOR if not specified.
;
; When adding a new field ID, three routines must be modified.  Each routine
; contains a case statement which selects by radar field, and which must be
; modified to include the new field.  The routines and modifications are as
; follows:
;
; Routine              Modification
; -------              ------------
; loadcolortable      (In file geo_match/loadcolortable.pro). Add color 
;                     table for the new field.
;
; mapcolors           (File above) Add the algorithm for mapping the data to
;                     color table indexes.
;
; vn_colorbar         (This file) Add the labels and units for the color bar.
;
;*****************************************************************************

if N_ELEMENTS(color) ne 1 then color=255
if N_ELEMENTS(unitscolor) eq 1 then ucolor=unitscolor else ucolor=color

; Make data labels for colorbar.  Fields that have the same units can
; share a field type for the purpose of labeling the color bar.  For example,
; DZ, CZ and ZT are all in units of dBZ.  Since labeling is defined for DZ in
; the case statement below, we can use that for all three fields.

; Note that the zero-th color (black, typically) is not shown in the color
; bar, nor labeled.

; compress field definitions for same variable categories
fieldtype = field
if field eq 'CZ' or field eq 'ZT' then fieldtype = 'DZ'
if field eq 'ZD' then fieldtype = 'DR'
if field eq 'D0' or field eq 'Dm' then fieldtype = 'D0 or Dm'
if field eq 'RC' or field eq 'RP' or field eq 'RR' or field eq 'Z-R' $
   then fieldtype = 'RR'
if field eq 'N2' then fieldtype = 'NW'

; offset between colorbar segments and color table indices
coloroffset=0

case fieldtype of
    'DZ': begin
;       labels = ['70','65','60','55','50','45','40','35','30','25','20','15', $
;           '10','5','0','<0']
       labels = ['57','54','51','48','45','42','39','36','33','30','27','24','21', $
           '18','15','BT']
       units = 'dBZ'
      ; set up array of text colors for labels, compatible with color bar colors
      ; - these must be given in reverse order of the labels
       txtcolr=[color,0,0,color,color,0,color,color,0,0,color,color,color, $
           color,color,color]
    end
    'VR': begin
       labels = ['RF','30','25','20','15','10','5','0','-5','-10','-15','-20',$
           '-25','-30']
       units = 'm/s'
       txtcolr = 0
    end
    'SW': begin
       labels = ['RF','>21','20','18','16','14','12','10','8','6','4','2','0'] 
       units = 'm/s'
       txtcolr = 0
    end
    'DR': begin
       labels = ['>3','3.0','2.5','2.0','1.5','1.0','0.5','0.0','-0.5','-1',$
           '-1.5','-2','-2.5','-3','<-3']
       units = 'dB'
       ;txtcolr = 0
       txtcolr = intarr(n_elements(labels))
       txtcolr[*] = color
       indicesDRK=[1,4,5,7,8,9]
       txtcolr[indicesDRK]=0
    end
    'KD': begin
       labels = ['>3','3.0','2.5','2.0','1.5','1.0','0.5','0.0','-0.5','-1',$
           '-1.5','-2','<-2']
       units = 'deg/km'
       ;txtcolr = 0
       txtcolr = intarr(n_elements(labels))
       txtcolr[*] = color
       indicesDRK=[0,2,3,5,6,7]
       txtcolr[indicesDRK]=0
    end
    'RH': begin
       labels = ['.98','.96','.94','.92','.90','.88','.84','.80', $
           '.60','.40','.20','0.0']
       units = ''
       txtcolr = 0
    end
    'PH': begin
       labels = ['165','150','135','120','105','90','75','60','45','30','15',$
           '0']
       units = 'deg'
       txtcolr = 0
    end
    'RR': begin
       labels = strtrim(80-indgen(17)*5,1) ; 80 to 0, increment -5.
       labels[16] = '1' ; use 1 to label lowest color in bar. 0 will be black.
       units = 'mm/h'
       if n_elements(ypos) eq 0 then ypos = .95
       ;txtcolr = 0
       color2=color ;color2 = 255-color
       txtcolr = [0,0,0,color2,color2,0,0,0,0,0,0,color2,color2,color2,color2,color2,0]
    end
    'SW': begin
    ;0,.5,1,1.5,2,2.5,3,4,5,6,7,8,9,10,12,14,17,20
       labels = ['20+','17','14','12','10','9','8','7','6','5','4','3','2.5','2','1.5','1','0.5']
       units = 'mm/h'
       if n_elements(ypos) eq 0 then ypos = .95
       ;txtcolr = 0
       color2=color ;color2 = 255-color
       txtcolr = [0,0,0,color2,color2,0,0,0,0,0,0,color2,color2,color2,color2,color2,0]
    end
    'FH': begin
;       labels = ['UC','DZ','RN','CR','DS','WS','VI','LDG','HDG','HA','BD']
       labels = ['BD','HA','HDG','LDG','VI','WS','DS','CR','RN','DZ','UC']
       units = 'HID'
       if n_elements(ypos) eq 0 then ypos = .95
       txtcolr = [color,color,color,0,0,0,0,0,0,color,color]
    end
    'D0 or Dm': begin
       labels=string(findgen(15)/2.0, format='(f0.1)')
       labels[0] = '>0'
;       labels=[labels,'MM']
       labels=reverse(labels)  ; need in high->low order
       units = 'mm'
       if n_elements(ypos) eq 0 then ypos = .95
       txtcolr = intarr(n_elements(labels))
       txtcolr[*] = color
       indicesDRK=[0,1,4,7,8,9]
       txtcolr[indicesDRK]=0
;       txtcolr = reverse(txtcolr)
    end
    'NW': begin
       labels=string(findgen(15)/2.0, format='(f0.1)')
       labels[0] = '>0'
;       labels=[labels,'MM']
       labels=reverse(labels)  ; need in high->low order
       units = 'Nw'  ;'mm-1*m-3'  ; can't plot more than 2-3 chars on colorbar
       if n_elements(ypos) eq 0 then ypos = .95
       txtcolr = intarr(n_elements(labels))
       txtcolr[*] = color
       indicesDRK=[0,1,4,7,8,9]
       txtcolr[indicesDRK]=0
;       txtcolr = reverse(txtcolr)
    end
    'dRR': begin
      ; rain rate differences
       labels = ['>50','25','10','5','1','.25','.1','0','-.1','-.25','-1','-5','-10','-25','<-50']
       units = 'mm/h'
       txtcolr = [color,color,0,color,color,0,0,0,0,0,0,color,0,0,0]  ; in 'labels' order
       txtcolr = reverse(txtcolr)  ; bottom to top
       coloroffset=6   ; 6+1+7 puts segment '0' at color index 14 (white)
    end
    'Tbb': begin
      ; brightness temperature from 90 to 300 K in 15 K steps
       labels=string(indgen(15)*15+90, format='(i0)')
       labels=reverse(labels)  ; need in high->low order
       units = 'K'
       txtcolr = intarr(n_elements(labels))
       txtcolr[*] = 0
       indicesLgt=[3,5,6,11,12,14]
       txtcolr[indicesLgt]=color
    end
    'AGL': begin
       labels=string(findgen(15)/2.0, format='(f0.1)')
       labels[0] = '>0'
;       labels=[labels,'MM']
       labels=reverse(labels)  ; need in high->low order
       units = 'km'
       if n_elements(ypos) eq 0 then ypos = .95
       txtcolr = intarr(n_elements(labels))
       txtcolr[*] = color
       indicesDRK=[0,1,4,7,8,9]
       txtcolr[indicesDRK]=0
;       txtcolr = reverse(txtcolr)
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
plots,x,y,/norm,/cont,col=indgen(ncolors)+1+coloroffset,thick=thickness

; Write value labels on color scale.  Vertically center the labels.
; Note that labels need to be reversed here. This may (probably should) change.
if vertical then begin
    xyouts,xs,y-.75*cbseg,reverse(labels),/normal,align=.5,color=txtcolr,charsize=charsize
endif else begin
    chr_ht = float(!d.y_ch_size)/!d.y_size
    ylabpos = y-.4*chr_ht
    xyouts,x-.5*cbseg,ylabpos,reverse(labels),/normal,align=.5,color=txtcolr, $
        charsize=charsize
endelse

; Write units label.
if vertical then xyouts,x,y[ncolors-1]+.25*cbseg,units, $
    align=.5,charsize=charsize,/normal, color=ucolor $
else xyouts,x[0]-1.5*cbseg,y,units,align=1.,charsize=charsize,/normal, $
    color=ucolor

end
