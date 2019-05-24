;+
; Copyright © 2011, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; DESCRIPTION:
;       Contains two modules used to produce a multiplot with scatter plots of
;       PR and GV data, one for each breakout of the data by rain type and
;       surface type.  Output is to the display.
;
;       Primary Module:  plot_scatter_by_sfc_type, title, prz_in, gvz_in, $
;                            raintype_in, sfctype_in, npts, idxBySfcType, $
;                            MIN_XY=minXY, MAX_XY=maxXY, UNITS=units, $
;                            Y_TITLE=y_title
;       Internal Module: plot_scat, pos, sub_title, ncolor, charsz, xdata, $
;                            ydata, ndata, S2KU=s2ku, MIN_XY=minXY, $
;                            MAX_XY=maxXY, UNITS=units, Y_TITLE=y_title
;
; HISTORY:
;       Bob Morris/GPM GV (SAIC), June, 2011
;       - Created from plot_scatter_by_bb_prox.pro.  Left s2ku as internal
;         parameter, just in case.
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;------------------------------------------------------------------------------

pro plot_scat, pos, sub_title, ncolor, charsz, xdata, ydata, ndata, S2KU=s2ku, $
               MIN_XY=minXY, MAX_XY=maxXY, UNITS=units, Y_TITLE=y_title

IF N_ELEMENTS(minXY) EQ 1 THEN xymin = minXY ELSE xymin = 15.0  ; default to dBZ
IF N_ELEMENTS(maxXY) EQ 1 THEN xymax = maxXY ELSE xymax = 65.0  ; default to dBZ
IF N_ELEMENTS(units) NE 1 THEN units = 'dBZ'
IF units NE 'dBZ' THEN errlimit=5.0 ELSE errlimit=3.0  ; for +/- error lines
IF N_ELEMENTS(y_title) NE 1 THEN BEGIN
   IF units EQ 'dBZ' THEN y_title='TRMM PR (attenuation corrected), dBZ' ELSE $
   y_title='TMI rainate, '+units
ENDIF

IF ( N_PARAMS() GT 4 ) THEN BEGIN

   ; --- Define symbol as filled circle
   A = FINDGEN(17) * (!PI*2/16.)
   USERSYM, COS(A), SIN(A), /FILL

  ; define the x-coordinate label, depending on GV adjustment status
   IF ( s2ku ) THEN xtitle='GV Radar, '+units+' (Ku-adjusted)' $
               ELSE xtitle='GV Radar, '+units
   IF units EQ 'dBZ' THEN BEGIN
     plot,POSITION=pos,xdata[0:ndata-1],ydata[0:ndata-1],$
       xticklen=+0.04, yticklen=0.04,/noerase, $
       xticks=5,xrange=[xymin,xymax],yrange=[xymin,xymax], $
       xstyle=1, ystyle=1, $
       yticks=5, xminor=5,yminor=5, ytickname=['15','25','35','45','55','65'], $
       title=sub_title, $
       ytitle=y_title, $ ;'TRMM PR (attenuation corrected), dBZ', $
       xtitle=xtitle, $
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
       ytitle=y_title, $ ;'TMI rainrate, , '+units, $
       xtitle=xtitle, $
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
       ytitle=y_title, $ ;'TRMM PR (attenuation corrected), dBZ', $
       xtitle='GV Radar, dBZ', $
       color=ncolor, charsize=charsz
   ENDIF ELSE BEGIN
     plot,POSITION=pos,[xymin,xymax],[xymin,xymax], /nodata, $
       xticklen=+0.04, yticklen=0.04,/noerase, $
       xticks=5,xrange=[xymin,xymax],yrange=[xymin,xymax], $
       /xlog, /ylog, $
       yticks=5, xminor=5,yminor=5, $
       title=sub_title, $
       ytitle=y_title, $ ;'TMI rainrate, '+units, $
       xtitle='GV Radar, '+units, $
       color=ncolor,charsize=charsz
   ENDELSE  
   xyouts, pos[0]+0.05, pos[3]-0.15, "NO DATA POINTS IN CATEGORY", $
       charsize=charsz, color=ncolor, alignment=0, /normal

ENDELSE
end                     

;------------------------------------------------------------------------------


pro plot_scatter_by_sfc_type, title, prz_in, gvz_in, raintype_in, $
                              sfctype_in, npts, idxBySfcType, winsiz, $
                              MIN_XY=minXY, MAX_XY=maxXY, UNITS=units, $
                              Y_TITLE=y_title

orig_device = !D.NAME

; set proportions of WINDOW
xsize=6.5
ysize=9.75

; work from a default window size of 375 (PPI_SIZE keyword in parent procedure),
; set character size based on 0.75 for the default size, increment by 0.25
winfac = winsiz/5
charsz = 0.25*(winsiz/125)

; Set up color table
;
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
red(1)=215 & green(1)=215 & blue(1)=215  ;gray background
red(ncolor)=forecolor[0] & green(ncolor)=forecolor[1] & blue(ncolor)=forecolor[2]
tvlct,red,green,blue

WINDOW, 3, TITLE=title, XSIZE=xsize*winfac, YSIZE=ysize*winfac, RETAIN=2

;bblevstr = ['  N/A ', 'Below BB', 'Within BB', 'Above BB']
SfcType_str = [' N/A ', 'Ocean', ' Land', 'Coast']
typestr = ['Any Type ', 'Stratiform, ', 'Convective, ']

xs = 0.4  &  ys = xs * xsize / ysize
x0 = 0.075  &  y0 = x0 * xsize / ysize
x00 = 0.1  &  y00 = 0.06

pos = fltarr(4)

for i=0,2 do begin     ;row, count from bottom -- also, surface type

  proxim = i+1     ; 1='Ocean', 2='Land', 3='Coast'
  IF ( npts[i] GT 0 ) THEN BEGIN
     idxthislev = idxBySfcType[i,0:npts[i]-1]
     prz = prz_in[idxthislev]
     gvz = gvz_in[idxthislev]
     raintype = raintype_in[idxthislev]
     sfctype = sfctype_in[idxthislev]
  ENDIF

 ; don't indicate Ku-corrected for TMI plots
  s2ku4sca = 0

  for j=0,1 do begin   ;column, count from left; also, strat/conv raintype index
    raincat = j+1   ; 1=Stratiform, 2=Convective
    x1=x0+j*(xs+x00)
    y1=y0+i*(ys+y00)  
    x2=x1+xs
    y2=y1+ys          
    pos[*] = [x1,y1,x2,y2]
    subtitle = typestr[raincat]+SfcType_str[proxim]
    IF ( npts[i] GT 0 ) THEN BEGIN
      idxsub = WHERE( sfctype EQ proxim AND raintype EQ raincat, nfound )
      IF ( nfound GT 0 ) THEN BEGIN
         prsub = prz[idxsub] & gvsub = gvz[idxsub]
         plot_scat, pos, subtitle, ncolor, charsz, gvsub, prsub, nfound, $
                    S2KU=s2ku4sca, MIN_XY=minXY, MAX_XY=maxXY, UNITS=units, $
                    Y_TITLE=y_title
      ENDIF ELSE BEGIN
         print, 'No points in rain category ', typestr[raincat], SfcType_str[proxim]
         plot_scat, pos, subtitle, ncolor, charsz, MIN_XY=minXY, MAX_XY=maxXY, $
                    UNITS=units, Y_TITLE=y_title
      ENDELSE
    ENDIF ELSE BEGIN
;      print, 'no points at BB proximity level'
      plot_scat, pos, subtitle, ncolor, charsz, MIN_XY=minXY, MAX_XY=maxXY, $
                    UNITS=units, Y_TITLE=y_title
    ENDELSE
  endfor

endfor

SET_PLOT, orig_device
end
