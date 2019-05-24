;+
; Copyright © 2009, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; DESCRIPTION:
;       Contains two modules used to produce a multiplot with scatter plots of
;       PR and GV data, one for each breakout of the data by rain type and
;       surface type.  Output is to the display.
;
;       Primary Module: plot_scatter_prgrdiff_vs_pratten, title, siteID, histo2d_in, winsiz, $
;                             S2KU=s2ku_in, MIN_XY=minXY, MAX_XY=maxXY, $
;                             UNITS=units, Y_TITLE=y_title, BBWITHIN=bbwithin
;       Internal Module: plot_scat, pos, sub_title, siteID, ncolor, charsz, $
;                            xdata, ydata, colors, ndata, S2KU=s2ku, MIN_XY=minXY, $
;                            MAX_XY=maxXY, UNITS=units, Y_TITLE=y_title
;
; HISTORY:
;       Bob Morris/GPM GV (SAIC), 29 October 2013
;       - Created from plot_scatter_by_bb_prox.pro
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;------------------------------------------------------------------------------

pro plot_scat, pos, sub_title, siteID, ncolor, charsz, xdata, ydata, colors, ndata, S2KU=s2ku, $
               MIN_XY=minXY, MAX_XY=maxXY, UNITS=units, Y_TITLE=y_title

IF N_ELEMENTS(minXY) EQ 1 THEN xymin = minXY ELSE xymin = 15.0  ; default to dBZ
IF N_ELEMENTS(maxXY) EQ 1 THEN xymax = maxXY ELSE xymax = 65.0  ; default to dBZ
IF N_ELEMENTS(units) NE 1 THEN units = 'dBZ'
IF units NE 'dBZ' THEN errlimit=5.0 ELSE errlimit=3.0  ; for +/- error lines
IF N_ELEMENTS(y_title) NE 1 THEN BEGIN
   IF units EQ 'dBZ' THEN y_title='PR (corrected) - GR, dBZ' ELSE $
   y_title='TRMM PR, '+units
ENDIF
; define the x-coordinate label, depending on GV adjustment status
IF keyword_set(s2ku) THEN xtitle=siteID+' Radar, '+units+' (Ku-adjusted)' $
ELSE xtitle='PRcor-PRraw, dBZ '

IF ( N_PARAMS() GT 5 ) THEN BEGIN

   ; --- Define symbol as filled circle
   A = FINDGEN(17) * (!PI*2/16.)
   USERSYM, COS(A), SIN(A), /FILL
xmaxdata = (FIX(MAX(xdata)/5 + 1) * 5) < 15
xmindata = -5
     plot, POSITION=pos, [-5.0,15.0], [0.0,0.0], $
       xticklen=+0.04, yticklen=0.04,/noerase, $
       xticks=4,xrange=[-5.0, 15.0],yrange=[-20.,20.], $ ;[-5.0,xmaxdata],yrange=[-20.,20.], $  ;
       xstyle=1, ystyle=1, $
       yticks=8, xminor=5,yminor=5, $;ytickname=['15','25','35','45','55','65'], $
       title=sub_title, $
       ytitle=y_title, $
       xtitle=xtitle, $
       color=ncolor,charsize=charsz
   oplot, [0.0,0.0], [-20.0,20.0], color=ncolor
   FOR ipix=0,ndata-1 DO BEGIN
      oplot, [xdata[ipix],xdata[ipix]], [ydata[ipix],ydata[ipix]], color=colors[ipix], psym=8, symsize=0.5
   ENDFOR
            
ENDIF ELSE BEGIN
  ; print, 'Plotting empty panel for ', sub_title
     plot, POSITION=pos, [xymin,xymax],[xymin,xymax], /nodata, /noerase, $
       xticklen=+0.04, yticklen=0.04, xticks=5, yticks=8, $
       xminor=5, yminor=5, xtickname=['-5','0','5','10','15','20'], $
       ytickname=['-20','-15','-10','-5','0','5','10','15','20'], title=sub_title, $
       ytitle=y_title, $
       xtitle=xtitle, $
       color=ncolor, charsize=charsz
   xyouts, pos[0]+0.05, pos[3]-0.15, "NO DATA POINTS IN CATEGORY", $
       charsize=charsz, color=ncolor, alignment=0, /normal

ENDELSE
end                     

;------------------------------------------------------------------------------


pro plot_scatter_prgrdiff_vs_pratten, title, siteID, histo2d_in, winsiz, $
                             S2KU=s2ku_in, MIN_XY=minXY, MAX_XY=maxXY, $
                             UNITS=units, Y_TITLE=y_title, BBWITHIN=bbwithin

orig_device = !D.NAME
s2ku = KEYWORD_SET( s2ku_in )

; set proportions of WINDOW
xsize=6.5
; do we have 3 rows of plots (is within-BB row included or excluded?)
IF KEYWORD_SET(bbwithin) THEN ysize=9.75 ELSE ysize=6.5

; work from a default window size of 375 (PPI_SIZE keyword in parent procedure),
; set character size based on 0.75 for the default size, increment by 0.25
winfac = winsiz/5
charsz = 0.25*(winsiz/125)

; Set up color table
;
device, decomposed=0
common colors, r_orig, g_orig, b_orig, r_curr, g_curr, b_curr ;load color table
loadct,33
ncolor=!d.table_size-1
ncolor=255
forecolor=[0,0,0]   ; change to 255's for white plot on black background
backcolor=[255,255,255]-forecolor
red=bytarr(256) & green=bytarr(256) & blue=bytarr(256)
red=r_curr & green=g_curr & blue=b_curr
;red(0)=255 & green(0)=255 & blue(0)=255
red(0)=backcolor[0] & green(0)=backcolor[1] & blue(0)=backcolor[2]
;red(1)=215 & green(1)=215 & blue(1)=215  ;gray background
red(ncolor)=forecolor[0] & green(ncolor)=forecolor[1] & blue(ncolor)=forecolor[2]
tvlct,red,green,blue

WINDOW, 3, TITLE=title, XSIZE=xsize*winfac, YSIZE=ysize*winfac, RETAIN=2

bblevstr = ['  N/A ', 'Below BB', 'Within BB', 'Above BB']
typestr = ['Other ', 'Stratiform, ', 'Convective, ']

xs = 0.4  &  ys = xs * xsize / ysize     ; x- and y-spans
x0 = 0.075  &  y0 = x0 * xsize / ysize   ; x- and y-offset from edge of plot subarea
x00 = 0.1  &  y00 = 0.09*(xsize/ysize)   ;0.06 x- and y-step between subareas

pos = fltarr(4)
IF KEYWORD_SET(bbwithin) THEN step=1 ELSE step=2

for i=0,2,step do begin     ;row, count from bottom -- also, bbprox type

  proxim = i+1     ; 1=' Below', 2='Within', 3=' Above'

 ; don't indicate Ku-corrected for within-BB plots
  IF ( s2ku ) THEN BEGIN
     IF ( proxim EQ 2 ) THEN s2ku4sca = 0 ELSE s2ku4sca = s2ku
  ENDIF ELSE s2ku4sca = 0

  for j=0,1 do begin   ;column, count from left; also, strat/conv raintype index
    raincat = j+1   ; 1=Stratiform, 2=Convective
   ; set the plot bounds
    x1=x0+j*(xs+x00)
    yjump = i/step        ; vertical row position to plot in next
    y1=y0+yjump*(ys+y00)
    x2=x1+xs
    y2=y1+ys          
    pos[*] = [x1,y1,x2,y2]

   ; extract the histogram for this raintype/bbprox combination
    subtitle = typestr[raincat]+bblevstr[proxim]
    combo = raincat*10 + i
    CASE combo OF
       10 : biasByAtten = REFORM(histo2d_in[0,*,*])    ; strat/below
       11 : biasByAtten = REFORM(histo2d_in[1,*,*])    ; strat/within
       12 : biasByAtten = REFORM(histo2d_in[2,*,*])    ; strat/above
       20 : biasByAtten = REFORM(histo2d_in[3,*,*])    ; conv/below
       21 : biasByAtten = REFORM(histo2d_in[4,*,*])    ; conv/within
       22 : biasByAtten = REFORM(histo2d_in[5,*,*])    ; conv/above
       30 : biasByAtten = REFORM(histo2d_in[6,*,*])    ; other/below
       31 : biasByAtten = REFORM(histo2d_in[7,*,*])    ; other/within
       32 : biasByAtten = REFORM(histo2d_in[8,*,*])    ; other/above
    ENDCASE

   ; extract the points to be plotted (non-zero histogram total)
    idxnotzero = WHERE(biasByAtten GT 0, npts)
    IF ( npts GT 0 ) THEN BEGIN
      ; get the positions of the non-zero values in the histo array
       xypos = ARRAY_INDICES(biasByAtten, idxnotzero)
      ; convert the indices back to histogram bin physical values
       atten = REFORM(xypos[1,*])/10.0-5.0   ; 0.1dBZ steps starting from -5.0
       biasprgr = REFORM(xypos[0,*])/10.0-20.0  ; 0.1dBZ steps from -20.0 to 20.0
      ; assign color indices 1-255 based on histogram counts (# occurences in bin)
       scaler = MAX(biasByAtten)/254 + 1  ;MAX(histo2d_in[0:5,*,*])/256 + 1 ;
       colors = biasByAtten[idxnotzero]/scaler + 1 < 254
       maxcolor = MAX(colors)
print, 'maxcolor = ', maxcolor
       Mean_atten=TOTAL(atten*biasByAtten[idxnotzero])/TOTAL(biasByAtten[idxnotzero])
       Mean_bias=TOTAL(biasprgr*biasByAtten[idxnotzero])/TOTAL(biasByAtten[idxnotzero])
       xyouts,pos[0]+0.13, pos[3]-0.051, "Mean PR-GR = "+string(Mean_bias, $
         format='(F0.2)')+"", charsize=charsz,color=ncolor,alignment=0,/normal
       xyouts,pos[0]+0.13, pos[3]-0.071, "Mean PRcor-PRraw = "+string(Mean_atten, $
         format='(F0.2)')+"", charsize=charsz,color=ncolor,alignment=0,/normal
;      IF maxcolor LT 127 THEN colors=colors*(256/maxcolor)  ; scale up to full color range
       plot_scat, pos, subtitle, siteID, ncolor, charsz, atten, biasprgr, colors, npts, $
                  S2KU=s2ku4sca, MIN_XY=minXY, MAX_XY=maxXY, UNITS=units, $
                  Y_TITLE=y_title
    ENDIF ELSE BEGIN
       print, 'No points in rain category ', typestr[raincat], bblevstr[proxim]
       plot_scat, pos, subtitle, siteID, ncolor, charsz, S2KU=s2ku4sca, $
                  MIN_XY=minXY, MAX_XY=maxXY, UNITS=units, Y_TITLE=y_title
    ENDELSE
  endfor
endfor

SET_PLOT, orig_device
end
