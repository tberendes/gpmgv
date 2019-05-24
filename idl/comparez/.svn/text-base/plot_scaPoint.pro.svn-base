;+
; Copyright © 2008, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; DESCRIPTION:
;       Contains two modules used to produce a multiplot with scatter plots of
;       PR and GV data, one for each breakout of the data by rain type and
;       surface type.  Output is to a Postscript file whose name is supplied
;       as the 'file' parameter.
;
;       Module 1:  plot_scaPoint, file, siteID, Height=height
;       Module 2:  plot_pt, pos, xdata, ydata, ndata, siteID, PLOT_TITLE=sub_title
;
; AUTHOR:
;       Liang Liao
;       Caelum Research Corp.
;       Code 975, NASA/GSFC
;       Greenbelt, MD 20771
;       Phone: 301-614-5718
;       E-mail: lliao@priam.gsfc.nasa.gov
;
; HISTORY:
;       Bob Morris/GPM GV (SAIC), dates various
;       - Added parameters and graphic titleing flexibility to allow any site to
;         be plotted with correct labeling.
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-


pro plot_scaPoint, file, siteID, Height = height

common cumulation, s_npt, c_npt, t_npt, o_npt, l_npt, m_npt, $
                   s_pr0_tot, s_pr_tot, s_gv_tot, c_pr0_tot, c_pr_tot, c_gv_tot, $
                   t_pr0_tot, t_pr_tot, t_gv_tot, o_pr0_tot, o_pr_tot, o_gv_tot, $
                   l_pr0_tot, l_pr_tot, l_gv_tot, m_pr0_tot, m_pr_tot, m_gv_tot
                   
set_plot,/copy,'ps'
device,filename=file, /color,bits=8,$
/inches,xoffset=0.25,yoffset=0.55,xsize=8.,ysize=10.

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

xyouts, 0.5, 9.3/10., $
;"TRMM PR vs. "+siteID+" WSR-88D at Height of "+string(height,$
"TRMM PR vs. "+siteID+" GV Radar at Height of "+string(height,$
format='(f3.1)')+" (km)", alignment=0.5, color=ncolor, /normal, charsize=1., $
Charthick=1.5
 

xs = 2.2/8.  &  ys = 2.2/10.
x0 = 1.6/8.  &  y0 = 1.1/10.
x00 = 0.7/8.  &  y00 = 0.6/10.

pos = fltarr(4,3,2)

for i=0,2 do begin     ;row, count from bottom
  for j=0,1 do begin   ;column, count from left
    x1=x0+j*(xs+x00)
    y1=y0+i*(ys+y00)  
    x2=x1+xs
    y2=y1+ys          
    pos[*,2-i,j] = [x1,y1,x2,y2]
  endfor
endfor

plot_pt, pos[*,0,0], s_gv_tot, s_pr_tot, s_npt, siteID, PLOT_TITLE='Stratiform Rain'
plot_pt, pos[*,0,1], c_gv_tot, c_pr_tot, c_npt, siteID, PLOT_TITLE='Convective Rain'
plot_pt, pos[*,1,0], o_gv_tot, o_pr_tot, o_npt, siteID, PLOT_TITLE='Over Ocean'
plot_pt, pos[*,1,1], l_gv_tot, l_pr_tot, l_npt, siteID, PLOT_TITLE='Over Land'
plot_pt, pos[*,2,0], m_gv_tot, m_pr_tot, m_npt, siteID, PLOT_TITLE='Mixed Water and Land'
plot_pt, pos[*,2,1], t_gv_tot, t_pr_tot, t_npt, siteID, PLOT_TITLE='All the Cases'

device,/close
end


;------------------------------------------------------------------------------


pro plot_pt, pos, xdata, ydata, ndata, siteID, PLOT_TITLE=sub_title 
ncolor=255

; --- Define symbol as filled circle

   A = FINDGEN(17) * (!PI*2/16.)
   USERSYM, COS(A), SIN(A), /FILL
;

plot,POSITION=pos,xdata[0:ndata-1],ydata[0:ndata-1],$
    xticklen=+0.04, yticklen=0.04,/noerase,$
    xticks=5,xrange=[10,60],yrange=[10,60],$
    xstyle=1, ystyle=1,$
    yticks=5, xminor=5,yminor=5, ytickname=['10','20','30','40','50','60'], $
    title=sub_title, $
   ;title="h = "+string(height[n],format='(f4.1)')+" (km)",$
    ytitle='TRMM PR (attenuation corrected), dBZ', $
    xtitle='GV Radar, dBZ', $
    color=ncolor,charsize=0.7, psym=8, symsize=0.1 
  
oplot,[10,60],[10,60],color=ncolor

correlation = correlate(xdata[0:ndata-1],ydata[0:ndata-1])

xyouts,pos[0]+0.018, pos[3]-0.02, "Correlation = "+string(correlation, $
      format='(f4.2)')+"", $
      charsize=0.6,color=ncolor,alignment=0,/normal

standard_error, xdata[0:ndata-1],ydata[0:ndata-1], STD_ERROR=std_error

xyouts,pos[0]+0.018, pos[3]-0.033, "Std. error = "+string(std_error, $
      format='(f4.2)')+"", $
      charsize=0.6,color=ncolor,alignment=0,/normal
      
if ndata ge 0 and ndata lt 10 then fmt='(i1)'
if ndata ge 10 and ndata lt 100 then fmt='(i2)'
if ndata ge 100 and ndata lt 1000 then fmt='(i3)'
if ndata ge 1000 and ndata lt 10000 then fmt='(i4)'
if ndata ge 10000 and ndata lt 100000 then fmt='(i5)'

xyouts,pos[0]+0.018, pos[3]-0.046, "Points = "+string(ndata, $
      format=fmt)+"", $
      charsize=0.6,color=ncolor,alignment=0,/normal
            
      
end                     
