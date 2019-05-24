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
;       Primary Module: plot_scatter_by_bb_prox, title, siteID, prz_in, gvz_in, $
;                            raintype_in, bbprox_in, npts, idxByBB, $
;                            MIN_XY=minXY, MAX_XY=maxXY, UNITS=units, $
;                            Y_TITLE=y_title, X_TITLE=x_title
;       Internal Module: plot_scat, pos, sub_title, siteID, ncolor, charsz, $
;                            xdata, ydata, ndata, S2KU=s2ku, MIN_XY=minXY, $
;                            MAX_XY=maxXY, UNITS=units, Y_TITLE=y_title, $
;                            X_TITLE=x_title
;
; HISTORY:
;       Bob Morris/GPM GV (SAIC), February, 2009
;       - Created from grid-based version, plot_scaPoint.pro.  Near-total
;         rewrite to plot to screen, adjust text for window size, and use data
;         from the geo-match netCDF files of the GPM Validation Network.
;       08/04/09, Bob Morris/GPM GV (SAIC)
;       - Added S2KU keyword to control text in x-axis title to indicate
;         when GV reflectivity has been Ku-adjusted.
;       03/05/10, Bob Morris/GPM GV (SAIC)
;       - Added MIN_XY and MAX_XY keyword to control range of x and y axes,
;         and UNITS keyword to control log vs. linear plots and labeling.
;       - Modified plotting of +/- error bounds lines to accommodate log scale.
;       03/11/10, Bob Morris/GPM GV (SAIC)
;       - Added Y_TITLE keyword to accommodate multiple rainrate sources and
;         properly label the y axes on scatter plots.
;       01/24/12, Bob Morris/GPM GV (SAIC)
;       - Added siteID to parameter lists and to x-axis title.
;       08/14/13, Bob Morris/GPM GV (SAIC)
;       - Added KEYWORD_SET check/init on S2KU keyword value in top routine
;         plot_scatter_by_bb_prox to eliminate undefined error when not
;         specified by caller.
;       09/26/13, Bob Morris/GPM GV (SAIC)
;       - Added X_TITLE keyword to accommodate alternate rainrate sources and
;         properly label the x axes on scatter plots.
;       - Added logic to handle s2ku option in axis titles when titles with
;         'ZR' are specified
;       04/28/14, Bob Morris/GPM GV (SAIC)
;       - Added SAT_INSTR keyword to override the default y-axis "TRMM PR"
;         labeling when Y_TITLE is not specified.
;       - Added SKIP_BB keyword to plot a single "Unknown BB" set of plots when
;         set.
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;------------------------------------------------------------------------------

pro plot_scat, pos, sub_title, siteID, ncolor, charsz, xdata, ydata, ndata, $
               S2KU=s2ku, MIN_XY=minXY, MAX_XY=maxXY, UNITS=units, $
               Y_TITLE=y_title_in, X_TITLE=x_title_in, SAT_INSTR=sat_instr

IF N_ELEMENTS(minXY) EQ 1 THEN xymin = minXY ELSE xymin = 15.0  ; default to dBZ
IF N_ELEMENTS(maxXY) EQ 1 THEN xymax = maxXY ELSE xymax = 65.0  ; default to dBZ
IF N_ELEMENTS(units) NE 1 THEN units = 'dBZ'
IF units NE 'dBZ' THEN errlimit=5.0 ELSE errlimit=3.0  ; for +/- error lines

IF N_ELEMENTS(sat_instr) NE 1 THEN satinstrument = 'TRMM PR' $
                              ELSE satinstrument = sat_instr

IF N_ELEMENTS(y_title_in) NE 1 THEN BEGIN
   IF units EQ 'dBZ' THEN y_title=satinstrument+' (attenuation corrected), dBZ' $
                     ELSE y_title=satinstrument+', '+units
ENDIF ELSE BEGIN
   y_title = y_title_in + ', ' + units
   IF keyword_set(s2ku) THEN BEGIN
      IF STRPOS(y_title, 'ZR') NE -1 THEN y_title = y_title+' (Ku-adjusted)
   ENDIF
ENDELSE

; define/modify the x-coordinate label, depending on GV adjustment status
IF N_ELEMENTS(x_title_in) NE 1 THEN BEGIN
   IF keyword_set(s2ku) THEN x_title=siteID+' Radar, '+units+' (Ku-adjusted)' $
   ELSE x_title=siteID+' Radar, '+units
ENDIF ELSE BEGIN
   x_title = x_title_in + ', ' + units
   IF keyword_set(s2ku) THEN BEGIN
      IF STRPOS(x_title, 'ZR') NE -1 THEN x_title = x_title+' (Ku-adjusted)
   ENDIF
ENDELSE

IF ( N_PARAMS() GT 5 ) THEN BEGIN

   ; --- Define symbol as filled circle
   A = FINDGEN(17) * (!PI*2/16.)
   USERSYM, COS(A), SIN(A), /FILL

   IF units EQ 'dBZ' THEN BEGIN
     plot,POSITION=pos,xdata[0:ndata-1],ydata[0:ndata-1],$
       xticklen=+0.04, yticklen=0.04,/noerase, $
       xticks=5,xrange=[xymin,xymax],yrange=[xymin,xymax], $
       xstyle=1, ystyle=1, $
       yticks=5, xminor=5,yminor=5, ytickname=['15','25','35','45','55','65'], $
       title=sub_title, $
       ytitle=y_title, $
       xtitle=x_title, $
       color=ncolor,charsize=charsz, psym=1, symsize=0.5
      ; plot lines of +/- 3dbz error
       oplot,[xymin+errlimit,xymax],[xymin,xymax-errlimit],color=ncolor, LINESTYLE=2
       oplot,[xymin,xymax-errlimit],[xymin+errlimit,xymax],color=ncolor, LINESTYLE=2
   ENDIF ELSE BEGIN
     plot,POSITION=pos,xdata[0:ndata-1],ydata[0:ndata-1],$
       xticklen=+0.04, yticklen=0.04,/noerase, $
       xticks=5,xrange=[xymin,xymax],yrange=[xymin,xymax], $
       /xlog, /ylog, $
       yticks=5, xminor=5,yminor=5, $
       title=sub_title, $
       ytitle=y_title, $
       xtitle=x_title, $
       color=ncolor,charsize=charsz, psym=1, symsize=0.5
    ; plot lines of +/- 1, 5, and 25 mm/hr error
     FOR loc = xymin, xymax DO BEGIN
        FOR expon = 0,2 DO BEGIN
           oplot,[loc+errlimit^expon,loc+errlimit^expon+1],[loc,loc+1],color=ncolor, LINESTYLE=2
           oplot,[loc,loc+1],[loc+errlimit^expon,loc+errlimit^expon+1],color=ncolor, LINESTYLE=2
        ENDFOR
     ENDFOR
   ENDELSE  
   oplot,[xymin,xymax],[xymin,xymax],color=ncolor

   IF ndata GT 4 THEN BEGIN
      correlation = correlate(xdata[0:ndata-1],ydata[0:ndata-1])

      xyouts,pos[0]+0.03, pos[3]-0.025, "Correlation = "+string(correlation, $
            format='(f4.2)')+"", $
            charsize=charsz,color=ncolor,alignment=0,/normal

      standard_error, xdata[0:ndata-1],ydata[0:ndata-1], STD_ERROR=std_error

      xyouts,pos[0]+0.03, pos[3]-0.038, "Std. error = "+string(std_error, $
            format='(f4.2)')+"", $
            charsize=charsz,color=ncolor,alignment=0,/normal

      IF units EQ 'dBZ' THEN BEGIN
       ; plot the best-fit line
        fitted = linfit(xdata[0:ndata-1],ydata[0:ndata-1])
       ; figure out where it intersects the plot bounds
        IF ( fitted[0] LT 0.0 ) THEN BEGIN
          xstart=(xymin-fitted[0])/fitted[1]
          ystart = xymin
        ENDIF ELSE BEGIN
            xstart = xymin
            ystart = fitted[0]+fitted[1]*xymin
        ENDELSE
        yend = fitted[0]+fitted[1]*xymax
        xend = xymax
        IF ( yend GT xymax ) THEN BEGIN
          xend = (xymax-fitted[0])/fitted[1]
          yend = xymax
        ENDIF
        plots, [xstart,xend], [ystart,yend], LINESTYLE=1, THICK=1.5, color=ncolor
      ENDIF
   ENDIF

   if ndata ge 0 and ndata lt 10 then fmt='(i1)'
   if ndata ge 10 and ndata lt 100 then fmt='(i2)'
   if ndata ge 100 and ndata lt 1000 then fmt='(i3)'
   if ndata ge 1000 and ndata lt 10000 then fmt='(i4)'
   if ndata ge 10000 and ndata lt 100000 then fmt='(i5)'

   xyouts,pos[0]+0.03, pos[3]-0.051, "Points = "+string(ndata, $
         format=fmt)+"", charsize=charsz,color=ncolor,alignment=0,/normal
            
ENDIF ELSE BEGIN
  ; print, 'Plotting empty panel for ', sub_title
   IF units EQ 'dBZ' THEN BEGIN
     plot, POSITION=pos, [xymin,xymax],[xymin,xymax], /nodata, /noerase, $
       xticklen=+0.04, yticklen=0.04, xticks=5, yticks=5, $
       xminor=5, yminor=5, xtickname=['15','25','35','45','55','65'], $
       ytickname=['15','25','35','45','55','65'], title=sub_title, $
       ytitle=y_title, $
       xtitle=x_title, $
       color=ncolor, charsize=charsz
   ENDIF ELSE BEGIN
     plot,POSITION=pos,[xymin,xymax],[xymin,xymax], /nodata, $
       xticklen=+0.04, yticklen=0.04,/noerase, $
       xticks=5,xrange=[xymin,xymax],yrange=[xymin,xymax], $
       /xlog, /ylog, $
       yticks=5, xminor=5,yminor=5, $
       title=sub_title, $
       ytitle=y_title, $
       xtitle=x_title, $
       color=ncolor,charsize=charsz
   ENDELSE  
   xyouts, pos[0]+0.05, pos[3]-0.15, "NO DATA POINTS IN CATEGORY", $
       charsize=charsz, color=ncolor, alignment=0, /normal

ENDELSE
end                     

;------------------------------------------------------------------------------


pro plot_scatter_by_bb_prox, title, siteID, prz_in, gvz_in, raintype_in, $
                             bbprox_in, npts, idxByBB, winsiz, S2KU=s2ku_in, $
                             MIN_XY=minXY, MAX_XY=maxXY, UNITS=units, $
                             Y_TITLE=y_title, X_TITLE=x_title, $
                             SAT_INSTR=sat_instr, SKIP_BB=skip_BB_in

orig_device = !D.NAME
s2ku = KEYWORD_SET( s2ku_in )
skip_BB = KEYWORD_SET( skip_BB_in )

; set proportions of WINDOW
xsize=6.5
ysize=9.75
;IF skip_BB EQ 0 THEN ysize=9.75 ELSE ysize=3.25

; work from a default window size of 375 (PPI_SIZE keyword in parent procedure),
; set character size based on 0.75 for the default size, increment by 0.25
winfac = winsiz/5
charsz = 0.25*(winsiz/125)

; Set up color table
;
common colors, r_orig, g_orig, b_orig, r_curr, g_curr, b_curr ;load color table
loadct,33, /SILENT
ncolor=!d.table_size-1
ncolor=255
forecolor=[0,0,0]   ; change to 255's for white plot on black background
backcolor=[255,255,255]-forecolor
red=bytarr(256) & green=bytarr(256) & blue=bytarr(256)
red=r_curr & green=g_curr & blue=b_curr
;red(0)=255 & green(0)=255 & blue(0)=255
red(0)=backcolor[0] & green(0)=backcolor[1] & blue(0)=backcolor[2]
red(1)=215 & green(1)=215 & blue(1)=215  ;gray background
red(ncolor)=forecolor[0] & green(ncolor)=forecolor[1] & blue(ncolor)=forecolor[2]
tvlct,red,green,blue

WINDOW, 3, TITLE=title, XSIZE=xsize*winfac, YSIZE=ysize*winfac, RETAIN=2

bblevstr = ['Unknown BB', 'Below BB', 'Within BB', 'Above BB']
typestr = ['Any Type ', 'Stratiform, ', 'Convective, ']

xs = 0.4  &  ys = xs * xsize / ysize
x0 = 0.075  &  y0 = x0 * xsize / ysize
x00 = 0.1  &  y00 = 0.06

pos = fltarr(4)
IF skip_BB EQ 0 THEN BEGIN
   increment = 1    ; set up for legacy behavior
   catend = 2
ENDIF ELSE BEGIN
   increment = 0
   catend = 0
   y0 = y0+ys+y00   ; place our one row at the middle of the page
ENDELSE

for i=0,catend do begin     ;row, count from bottom -- also, bbprox type

  proxim = i+increment     ; 0= 'Unknown', 1=' Below', 2='Within', 3=' Above'
  IF ( npts[i] GT 0 ) THEN BEGIN
     idxthislev = idxByBB[i,0:npts[i]-1]
     prz = prz_in[idxthislev]
     gvz = gvz_in[idxthislev]
     raintype = raintype_in[idxthislev]
     bbprox = bbprox_in[idxthislev]
  ENDIF

 ; don't indicate Ku-corrected for within-BB plots
  IF ( s2ku ) THEN BEGIN
     IF ( proxim EQ 2 ) THEN s2ku4sca = 0 ELSE s2ku4sca = s2ku
  ENDIF ELSE s2ku4sca = 0

  for j=0,1 do begin   ;column, count from left; also, strat/conv raintype index
    raincat = j+1   ; 1=Stratiform, 2=Convective
    x1=x0+j*(xs+x00)
    y1=y0+i*(ys+y00)  
    x2=x1+xs
    y2=y1+ys          
    pos[*] = [x1,y1,x2,y2]
    subtitle = typestr[raincat]+bblevstr[proxim]
    IF ( npts[i] GT 0 ) THEN BEGIN
      idxsub = WHERE( bbprox EQ proxim AND raintype EQ raincat, nfound )
      IF ( nfound GT 0 ) THEN BEGIN
         prsub = prz[idxsub] & gvsub = gvz[idxsub]
         plot_scat, pos, subtitle, siteID, ncolor, charsz, gvsub, prsub, nfound, $
                    S2KU=s2ku4sca, MIN_XY=minXY, MAX_XY=maxXY, UNITS=units, $
                    Y_TITLE=y_title, X_TITLE=x_title, SAT_INSTR=sat_instr
      ENDIF ELSE BEGIN
         print, 'No points in rain category ', typestr[raincat], bblevstr[proxim]
         plot_scat, pos, subtitle, siteID, ncolor, charsz, S2KU=s2ku4sca, $
                    MIN_XY=minXY, MAX_XY=maxXY, UNITS=units, Y_TITLE=y_title, $
                    X_TITLE=x_title, SAT_INSTR=sat_instr
      ENDELSE
    ENDIF ELSE BEGIN
;      print, 'no points at BB proximity level'
      plot_scat, pos, subtitle, siteID, ncolor, charsz, S2KU=s2ku4sca, $
                 MIN_XY=minXY, MAX_XY=maxXY, UNITS=units, Y_TITLE=y_title, $
                 X_TITLE=x_title, SAT_INSTR=sat_instr
    ENDELSE
  endfor

endfor

SET_PLOT, orig_device
end
