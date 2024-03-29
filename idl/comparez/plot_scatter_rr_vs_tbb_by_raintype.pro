;+
; Copyright © 2016, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; DESCRIPTION:
;       Contains two modules used to produce a multiplot with scatter plots of
;       GMI and GV rainrate data versus GMI instrument calibrated temperature,
;       one for each breakout of the data by rain type.  Output is to the
;       display.
;
;       Primary Module:  plot_scatter_rr_vs_tbb_by_raintype, title, pr_rr_in, $
;                            gv_rr_in, Tbb_in, raintype, $
;                            GV_UNITS=units, Y_TITLE=y_title, X_TITLE=x_title
;       Internal Module: plot_rr_tbb_scat, pos, sub_title, siteID, ncolor, $
;                            charsz, xdata, ydata, ndata, UNITS=units, $
;                            Y_TITLE=y_title_in, X_TITLE=x_title_in
;
; HISTORY:
;       Bob Morris/GPM GV (SAIC), August, 2016
;       - Created from plot_scatter_by_sfc_type3x3.pro.
;
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;------------------------------------------------------------------------------

function configure_axis, units, TICK_INTRVL=tick_intrvl

SWITCH units OF
    'mm/h' : BEGIN
                minRR = 0.1
                maxRR = 100.0
                range=[minRR,maxRR]
                logScale=1
                xlog=0
                ticks=5
                minor=5
                BREAK
             END
      'km' : BEGIN
                minKm = 0.0
                maxKm = 15.0
                range=[minKm,maxKm]
                logScale=0
                ticks=5
                minor=3
                tick_intrvl=3.0
                BREAK
             END
       'K' :
     'Tbb' : BEGIN
                minTbb = 90.0
                maxTbb = 300.0
                range=[minTbb,maxTbb]
                logScale=0
                ticks=7
                minor=3
                tick_intrvl=30
                BREAK
             END
      ELSE : message, "Unknown units name: "+STRING(units[0])
ENDSWITCH

axisStruct = { range : range, $
               logScale : logScale, $
               ticks : ticks, $
               minor : minor }

return, axisStruct
end

;------------------------------------------------------------------------------

pro plot_rr_tbb_scat, pos, sub_title, siteID, ncolor, charsz, xdata, ydata, $
                      ndata, X_UNITS=x_units, Y_UNITS=y_units, $
                      X_TITLE=x_title_in, Y_TITLE=y_title_in

IF N_ELEMENTS(x_units) NE 1 THEN x_units = 'K'
IF N_ELEMENTS(y_units) NE 1 THEN y_units = 'mm/h'
IF N_ELEMENTS(x_title_in) NE 1 THEN x_title = 'GMI 89v Tbb, K' $
   ELSE x_title = x_title_in
IF N_ELEMENTS(y_title_in) NE 1 THEN y_title = 'GMI rainate, mm/h' $
   ELSE y_title = y_title_in

xAx = configure_axis( x_units, TICK_INTRVL=tick_intrvl )
; if a tick interval value applies to the units type, then copy and undefine
; (via TEMPORARY call) the value returned from function
IF N_ELEMENTS(tick_intrvl) NE 0 THEN xtickinterval=TEMPORARY(tick_intrvl)

yAx = configure_axis( y_units, TICK_INTRVL=tick_intrvl )
IF N_ELEMENTS(tick_intrvl) NE 0 THEN ytickinterval=TEMPORARY(tick_intrvl)

IF ( N_PARAMS() GT 5 ) THEN BEGIN

   ; --- Define symbol as filled circle
   A = FINDGEN(17) * (!PI*2/16.)
   USERSYM, COS(A), SIN(A), /FILL

   plot, POSITION=pos, xdata[0:ndata-1], ydata[0:ndata-1], $
         xticklen=+0.04, yticklen=0.04, /noerase, $
         xrange=xAx.range, yrange=yAx.range, $
         XLOG=xAx.logScale, YLOG=yAx.logScale, $
         xticks=xAx.ticks, yticks=yAx.ticks, $
         xminor=xAx.minor, yminor=yAx.minor, $
         xtickinterval=xtickinterval, ytickinterval=ytickinterval, $
         title=sub_title, ytitle=y_title, xtitle=x_title, $
         color=ncolor,charsize=charsz, psym=1, symsize=0.5

;   oplot, xAx.range, yAx.range, color=ncolor

   IF ndata GT 4 THEN BEGIN
      correlation = correlate(xdata[0:ndata-1],ydata[0:ndata-1])

      xyouts,pos[0]+0.03, pos[3]-0.025, "Correlation = "+string(correlation, $
            format='(f4.2)')+"", $
            charsize=charsz,color=ncolor,alignment=0,/normal

      standard_error, xdata[0:ndata-1],ydata[0:ndata-1], STD_ERROR=std_error

      xyouts,pos[0]+0.03, pos[3]-0.038, "Std. error = "+string(std_error, $
            format='(f4.2)')+"", $
            charsize=charsz,color=ncolor,alignment=0,/normal

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
   plot, POSITION=pos, xAx.range, yAx.range, /nodata, $
         xticklen=+0.04, yticklen=0.04,/noerase, $
         xrange=xAx.range, yrange=yAx.range, $
         XLOG=xAx.logScale, YLOG=yAx.logScale, $
         xticks=xAx.ticks, yticks=yAx.ticks, $
         xminor=xAx.minor, yminor=yAx.minor, $
         xtickinterval=xtickinterval, $
         title=sub_title, ytitle=y_title, xtitle=x_title, $
         color=ncolor,charsize=charsz

   xyouts, pos[0]+0.05, pos[3]-0.15, "NO DATA POINTS IN CATEGORY", $
         charsize=charsz, color=ncolor, alignment=0, /normal

ENDELSE
end                     

;------------------------------------------------------------------------------


pro plot_scatter_rr_vs_tbb_by_raintype, title, siteID, prz_in, gvz_in, $
                              Tbb_in, raintype, winsiz, GV_UNITS=gv_units, $
                              Y_TITLE=y_title, X_TITLE=x_title

IF N_ELEMENTS(gv_units) EQ 1 THEN BEGIN
  ; set up to do whichever plot type pertains to gv_units parameter
   units=gv_units
ENDIF ELSE BEGIN
  ; set up to do default RR vs. Tbb plot type
   units='mm/h'
ENDELSE

; set up pointer arrays to hold addresses of input data arrays that define the
; x and y data arrays to be scattered
xdata_ptrs = PTRARR(2, /ALLOCATE_HEAP)
ydata_ptrs = PTRARR(2, /ALLOCATE_HEAP)

CASE units OF
    'mm/h' : BEGIN
              ; (DEFAULT) plotting scatter of GMI RR vs. Tbb (bottom row),
              ; and GR RR vs. Tbb (top row)
               *(ydata_ptrs[0]) = prz_in
               *(ydata_ptrs[1]) = gvz_in
               yvarIDs = [ 'GMI rainrate, '  ,  siteID+' rainrate, ' ]
               yUnitIDs =          [ 'mm/h'  ,  'mm/h' ]
               *(xdata_ptrs[0]) = Tbb_in
                 xdata_ptrs[1]  = xdata_ptrs[0]
               xvarIDs =      [ 'GMI Tbb, '  ,  'GMI Tbb, ' ]
               xUnitIDs =             [ 'K'  ,  'K' ]
             END
      'km' : BEGIN
              ; plotting scatter of GR EchoTop vs. GMI RR (bottom row),
              ; and GR EchoTop vs. Tbb (top row)
               *(ydata_ptrs[0]) = gvz_in
                 ydata_ptrs[1]  = ydata_ptrs[0]
               yvarIDs = [ siteID+' echo top, '  ,  siteID+' echo top, ' ]
               yUnitIDs =                [ 'km'  ,  'km' ]
               xvarIDs =          [ 'GMI Tbb, '  ,  'GMI rainrate, ' ]
               *(xdata_ptrs[0]) = Tbb_in 
               *(xdata_ptrs[1]) = prz_in
               xUnitIDs =                 [ 'K'  ,  'mm/h' ]
             END
      ELSE : message, "Invalid UNITS parameter, only mm/h or km allowed."
ENDCASE

orig_device = !D.NAME

; set proportions of WINDOW
xsize=9.75
ysize=6.5 ;9.75

; work from a default window size of 375 (PPI_SIZE keyword in parent procedure),
; set character size based on 0.75 for the default size, increment by 0.25
winfac = winsiz/5
charsz = 0.25*(winsiz/125)

; Set up color table
;
common colors, r_orig, g_orig, b_orig, r_curr, g_curr, b_curr ;load color table
loadct, 33, /SILENT
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

WINDOW, 5, TITLE=title, XSIZE=xsize*winfac, YSIZE=ysize*winfac, RETAIN=2

;bblevstr = ['  N/A ', 'Below BB', 'Within BB', 'Above BB']
SfcType_str = [' GMI ', siteID]
typestr = ['Any Type, ', 'Stratiform, ', 'Convective, ']

xs = 0.25  &  ys = xs * xsize / ysize
x0 = 0.075  &  y0 = x0 ;* xsize / ysize
x00 = 0.067  &  y00 = 0.09

pos = fltarr(4)

for i=0,1 do begin     ;row, count from bottom -- also, RR type

;   IF i eq 0 THEN BEGIN
;      plotunits='mm/h'
;      prz = prz_in
;      y_title = 'GMI rainrate ' + plotunits
;   ENDIF ELSE BEGIN
;      plotunits=units
;      prz = gvz_in
;      y_title = siteID + yvar_GR + plotunits
;   ENDELSE

   prz = TEMPORARY( *(ydata_ptrs[i]) )  ; copy and undefine pointed-to var
   y_title = yvarIDs[i] + yUnitIDs[i]
   gvz = TEMPORARY( *(xdata_ptrs[i]) )  ; copy and undefine pointed-to var
   x_title = xvarIDs[i] + xUnitIDs[i]

  for j=0,2 do begin   ;column, count from left; also, strat/conv raintype index
      raincat = j ;+1   ; 1=Stratiform, 2=Convective
      x1=x0+j*(xs+x00)
      y1=y0+i*(ys+y00)  
      x2=x1+xs
      y2=y1+ys          
      pos[*] = [x1,y1,x2,y2]
      subtitle = typestr[raincat] +SfcType_str[i]
      IF j EQ 0 THEN idxsub = WHERE( prz gt 0.0 and gvz GT 0.0, nfound ) $
      ELSE idxsub = WHERE( prz gt 0.0 AND raintype EQ raincat, nfound )
      IF ( nfound GT 0 ) THEN BEGIN
         prsub = prz[idxsub] & gvsub = gvz[idxsub]
         plot_rr_tbb_scat, pos, subtitle, siteID, ncolor, charsz, gvsub, prsub, $
                    nfound, X_UNITS=xUnitIDs[i], Y_UNITS=yUnitIDs[i], $
                    Y_TITLE=y_title, X_TITLE=x_title
      ENDIF ELSE BEGIN
         print, 'No Tbb/RR scatter points in category ', $
                typestr[raincat], SfcType_str[i]
         plot_rr_tbb_scat, pos, subtitle, siteID, ncolor, charsz, $
                    X_UNITS=xUnitIDs[i], Y_UNITS=yUnitIDs[i], $
                    Y_TITLE=y_title, X_TITLE=x_title
      ENDELSE
  endfor

   *(ydata_ptrs[i]) = TEMPORARY( prz )  ; copy back to pointed-to vars and undefine
   *(xdata_ptrs[i]) = TEMPORARY( gvz )
endfor

SET_PLOT, orig_device
end
