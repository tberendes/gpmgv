;+
; AUTHOR:
;       Liang Liao
;       Caelum Research Corp.
;       Code 975, NASA/GSFC
;       Greenbelt, MD 20771
;       Phone: 301-614-5718
;       E-mail: lliao@priam.gsfc.nasa.gov
;+

pro plot_scaPoint_pr_gv

Height = 1.5

set_plot,/copy,'ps'
device,filename='test.ps',/color,bits=8, /landscape,  $
/inches,xoffset=0.25,yoffset=11,xsize=10.,ysize=8.

 !P.FONT=1
 ;DEVICE, SET_FONT='Times', /TT_FONT Helvetica
 DEVICE, SET_FONT='Helvetica', /TT_FONT

; Set up color table
;
common colors, r_orig, g_orig, b_orig, r_curr, g_curr, b_curr ;load color table
loadct,33
ncolor=!d.table_size-1
ncolor=255
red=bytarr(256) & green=bytarr(256) & blue=bytarr(256)
red=r_curr & green=g_curr & blue=b_curr
red(0)=255 & green(0)=255 & blue(0)=255
red(1)=215 & green(1)=215 & blue(1)=215  ;gray background
red(ncolor)=0 & green(ncolor)=0 & blue(ncolor)=0 
tvlct,red,green,blue

xyouts, 0.46, 9.3/10., $
"TRMM PR vs. WSR-88D in Melbourne", alignment=0.5, color=ncolor, $
/normal, charsize=1.5, Charthick=4

xyouts, 0.46, 9.0/10., $
"at Height of "+string(height,$
format='(f3.1)')+" (km)", alignment=0.5, color=ncolor, $
/normal, charsize=1.5, Charthick=4
 

ys = 3.7/8.  &  xs = 3.7/10.
y0 = 1.9/8.  & x0 = 0.7/10.
y00 = 0.0/8.  &  x00 = 0.3/10.

pos = fltarr(4,1,2)

for i=0,0 do begin     ;row, count from bottom
  for j=0,1 do begin   ;column, count from left
    x1=x0+j*(xs+x00)
    y1=y0+i*(ys+y00)  
    x2=x1+xs
    y2=y1+ys          
    pos[*,i,j] = [x1,y1,x2,y2]
  endfor
endfor

OPENR, lun,'../result/v5-v5/pr_gv_h1.5_98.dat', ERROR=err, /GET_LUN

mean_pr0 = fltarr(45)
mean_pr = fltarr(45)
mean_gv = fltarr(45)
nPoint = lonarr(45)

nfile=-1

While not (EOF(lun)) Do Begin 

   nfile=nfile+1

   READF, lun, m_pr0, m_pr, m_gv, s_pr0, s_pr, s_gv, cor_pr0, cor_pr, num
   mean_pr0[nfile] = m_pr0
   mean_pr[nfile] = m_pr
   mean_gv[nfile] = m_gv
   nPoint[nfile] = num

EndWhile

CLOSE, lun  &   FREE_LUN, lun

plot_pt, pos[*,0,0], mean_gv[0:nfile], mean_pr0[0:nfile], nPoint[0:nfile], Y_TITLE='TRMM PR (measured), dBZ'
plot_pt, pos[*,0,1], mean_gv[0:nfile], mean_pr[0:nfile], nPoint[0:nfile], X_TITLE='WSR-88D, dBZ',$
                     Y_TITLE='TRMM PR (attenuation corrected), dBZ'

plot_scale, pos[2,0,0]+0.07, 0.5*(pos[1,0,0]+pos[3,1,0])

device,/close
end


pro plot_pt, pos, xdata, ydata, ndata, X_TITLE=x_title, Y_TITLE=y_title 
ncolor=255

; --- Define symbol as filled circle

   A = FINDGEN(17) * (!PI*2/16.)
   USERSYM, COS(A), SIN(A), /FILL
;

!X.Thick = 3
!Y.Thick = 3

range=[20,40]

IF KEYWORD_SET(x_title) THEN BEGIN
  plot,POSITION=pos,[0,1,0,1],$
    xticklen=+0.04, yticklen=0.04,/nodata,/noerase,$
    xticks=4,xrange=range,yrange=range,$
    xstyle=1, ystyle=1,$
    yticks=4, xminor=5,yminor=5, $ytickname=['10','20','30','40','50','60'], $
    title=sub_title, $
   ;title="h = "+string(height[n],format='(f4.1)')+" (km)",$
    ytitle=y_title, $
    xtitle='WSR-88D, dBZ', $
    color=ncolor,charsize=1.5, charthick=3
ENDIF ELSE BEGIN  
  plot,POSITION=pos,[0,1,0,1],$
    xticklen=+0.03, yticklen=0.03,/nodata,/noerase,$
    xticks=4,xrange=range,yrange=range,$
    xstyle=1, ystyle=1,$
    yticks=4, xminor=5,yminor=5, $
    xtickname=[' ',' ',' ',' ',' '], $
    title=sub_title, $
   ;title="h = "+string(height[n],format='(f4.1)')+" (km)",$
    ytitle=y_title, $
    color=ncolor,charsize=1.5, charthick=1
ENDELSE

oplot, range, range, color=ncolor, thick = 3
 
for i=0,43 do begin
  plots,xdata[i],ydata[i],psym=8, symsize=2.5*ndata[i]/2000.+0.5, color=ncolor
endfor

correlation = correlate(xdata[0:23],ydata[0:23])

xyouts,pos[0]+0.03, pos[3]-0.033, "Correlation = "+string(correlation, $
      format='(f4.2)')+"", $
      charsize=1.2,charthick=3,color=ncolor,alignment=0,/normal
      
standard_error, xdata[0:23],ydata[0:23], STD_ERROR=std_error

xyouts,pos[0]+0.03, pos[3]-0.057, "Std. error = "+string(std_error, $
      format='(f4.2)')+"", $
      charsize=1.2,charthick=3,color=ncolor,alignment=0,/normal
      
plots, xdata[44],ydata[44], psym=8, symsize=2.5*1200./2000.+0.5, color=0.6*ncolor
plots, xdata[44],ydata[44], psym=2, symsize=1.5, color=ncolor

      
end                     


pro plot_scale, x,y
ncolor=255

plot,POSITION=[x,y-0.2,x+0.2,y+0.2],[0,1,0,1],$
    /nodata,/noerase,xrange=[x,x+0.2], yrange=[y-0.2,y+0.2], $
    xstyle=4+1, ystyle=4+1, $
    color=ncolor
    
ndata = indgen(11)*200   &   ndata[0] = 20

    
for i = 0, 10 do begin

   plots,x,y-0.2+0.04*i,psym=8, symsize=2.5*ndata[i]/2000.+0.5, color=ncolor
   xyouts,x+0.02,y-0.2+0.04*i, ""+string(ndata[i], format='(i4)')+"", $
          charsize=1,charthick=2.5,color=ncolor,alignment=0,/normal
          
endfor
   
end
