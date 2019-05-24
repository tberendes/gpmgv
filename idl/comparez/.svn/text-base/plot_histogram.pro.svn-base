;+
; Copyright © 2008, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; DESCRIPTION:
;       Contains two modules used to produce a multiplot with histograms of
;       PR and GV data, one for each breakout of the data by rain type and
;       surface type.  Output is to a Postscript file whose name is supplied
;       as the 'file' parameter.
;
;       Module 1:  plot_histogram, file, siteID, Height=height
;       Module 2:  plot_h, pos, ydata1, ydata2, ndata, siteID, PLOT_TITLE=sub_title
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
;       Bob Morris/GPM GV (SAIC), 10/27/2008
;       - Added ymax parameter to fit the full range of y values on the plot.
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-


pro plot_histogram, file, siteID, Height=height

common cumulation, s_npt, c_npt, t_npt, o_npt, l_npt, m_npt, $
                   s_pr0_tot, s_pr_tot, s_gv_tot, c_pr0_tot, c_pr_tot, c_gv_tot, $
                   t_pr0_tot, t_pr_tot, t_gv_tot, o_pr0_tot, o_pr_tot, o_gv_tot, $
                   l_pr0_tot, l_pr_tot, l_gv_tot, m_pr0_tot, m_pr_tot, m_gv_tot
                   
set_plot,/copy,'ps'
device,filename=file,/color,bits=8,$
/inches,xoffset=0.25,yoffset=0.55,xsize=8.,ysize=10.

ymax = 0.2  ; starting point for y-axis upper range for plot

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

min=10.  &   max=60.

h_s_pr_tot = HISTOGRAM(s_pr_tot[0:s_npt-1], MIN=min, MAX=max, BINSIZE=2)
h_s_gv_tot = HISTOGRAM(s_gv_tot[0:s_npt-1], MIN=min, MAX=max, BINSIZE=2)
norFac1 = Total(h_s_pr_tot)   &   norFac2 = Total(h_s_gv_tot)
;norFac1 = max(h_s_pr_tot)   &   norFac2 = max(h_s_gv_tot)
;norFac = float(norFac1 > norFac2)
h_s_pr_tot = h_s_pr_tot/norFac1    &    h_s_gv_tot = h_s_gv_tot/norFac2
h_max = MAX( h_s_pr_tot ) > MAX( h_s_gv_tot )
if ( FINITE(h_max) ) THEN ymax = ymax > h_max

h_c_pr_tot = HISTOGRAM(c_pr_tot[0:c_npt-1], MIN=min, MAX=max, BINSIZE=2)
h_c_gv_tot = HISTOGRAM(c_gv_tot[0:c_npt-1], MIN=min, MAX=max, BINSIZE=2)
norFac1 = Total(h_c_pr_tot)   &   norFac2 = Total(h_c_gv_tot)
h_c_pr_tot = h_c_pr_tot/norFac1    &    h_c_gv_tot = h_c_gv_tot/norFac2
h_max = MAX( h_c_pr_tot ) > MAX( h_c_gv_tot )
if ( FINITE(h_max) ) THEN ymax = ymax > h_max

h_o_pr_tot = HISTOGRAM(o_pr_tot[0:o_npt-1], MIN=min, MAX=max, BINSIZE=2)
h_o_gv_tot = HISTOGRAM(o_gv_tot[0:o_npt-1], MIN=min, MAX=max, BINSIZE=2)
norFac1 = Total(h_o_pr_tot)   &   norFac2 = Total(h_o_gv_tot)
h_o_pr_tot = h_o_pr_tot/norFac1    &    h_o_gv_tot = h_o_gv_tot/norFac2
h_max = MAX( h_o_pr_tot ) > MAX( h_o_gv_tot )
if ( FINITE(h_max) ) THEN ymax = ymax > h_max

h_l_pr_tot = HISTOGRAM(l_pr_tot[0:l_npt-1], MIN=min, MAX=max, BINSIZE=2)
h_l_gv_tot = HISTOGRAM(l_gv_tot[0:l_npt-1], MIN=min, MAX=max, BINSIZE=2)
norFac1 = Total(h_l_pr_tot)   &   norFac2 = Total(h_l_gv_tot)
h_l_pr_tot = h_l_pr_tot/norFac1    &    h_l_gv_tot = h_l_gv_tot/norFac2
h_max = MAX( h_l_pr_tot ) > MAX( h_l_gv_tot )
if ( FINITE(h_max) ) THEN ymax = ymax > h_max

h_m_pr_tot = HISTOGRAM(m_pr_tot[0:m_npt-1], MIN=min, MAX=max, BINSIZE=2)
h_m_gv_tot = HISTOGRAM(m_gv_tot[0:m_npt-1], MIN=min, MAX=max, BINSIZE=2)
norFac1 = Total(h_m_pr_tot)   &   norFac2 = Total(h_m_gv_tot)
h_m_pr_tot = h_m_pr_tot/norFac1    &    h_m_gv_tot = h_m_gv_tot/norFac2
h_max = MAX( h_m_pr_tot ) > MAX( h_m_gv_tot )
if ( FINITE(h_max) ) THEN ymax = ymax > h_max

h_t_pr_tot = HISTOGRAM(t_pr_tot[0:t_npt-1], MIN=min, MAX=max, BINSIZE=2)
h_t_gv_tot = HISTOGRAM(t_gv_tot[0:t_npt-1], MIN=min, MAX=max, BINSIZE=2)
norFac1 = Total(h_t_pr_tot)   &   norFac2 = Total(h_t_gv_tot)
h_t_pr_tot = h_t_pr_tot/norFac1    &    h_t_gv_tot = h_t_gv_tot/norFac2
h_max = MAX( h_t_pr_tot ) > MAX( h_t_gv_tot )
if ( FINITE(h_max) ) THEN ymax = ymax > h_max

ymaxrnd = (FIX(ymax*100.)/5)/20. + 0.05
ymax = ymaxrnd < 1.0
;print, "Plotted ymax = ", ymax
                            
plot_h, pos[*,0,0], h_s_pr_tot, h_s_gv_tot, s_npt, ymax, siteID, PLOT_TITLE='Stratiform Rain'
plot_h, pos[*,0,1], h_c_pr_tot, h_c_gv_tot, c_npt, ymax, siteID, PLOT_TITLE='Convective Rain'
plot_h, pos[*,1,0], h_o_pr_tot, h_o_gv_tot, o_npt, ymax, siteID, PLOT_TITLE='Over Ocean'
plot_h, pos[*,1,1], h_l_pr_tot, h_l_gv_tot, l_npt, ymax, siteID, PLOT_TITLE='Over Land'
plot_h, pos[*,2,0], h_m_pr_tot, h_m_gv_tot, m_npt, ymax, siteID, PLOT_TITLE='Mixed Water and Land'
plot_h, pos[*,2,1], h_t_pr_tot, h_t_gv_tot, t_npt, ymax, siteID, PLOT_TITLE='All the Cases'

device,/close
end


;pro plot_h, pos, ydata1, ydata2, ndata, PLOT_TITLE=sub_title 
pro plot_h, pos, ydata1, ydata2, ndata, ymax, siteID, PLOT_TITLE=sub_title
ncolor=255

xAxis = findgen(26)*2. + 10.
 
plot,POSITION=pos,xAxis, ydata1,$
    xticklen=+0.04, yticklen=0.04,/noerase,$
    xticks=5,xrange=[10,60],yrange=[0,ymax],$
    xstyle=1, ystyle=1,$
    ;yticks=5, $
    xminor=5, $
    ;yminor=4, $
    title=sub_title, $
   ;title="h = "+string(height[n],format='(f4.1)')+" (km)",$
    ytitle='Normalized Histogram', $
    xtitle='Radar Reflectivity, dBZ', $
    color=ncolor,charsize=0.7, linestyle=1 
  
oplot, xAxis, ydata2,color=ncolor, linestyle=0

plots,[pos[0]+0.015+0.15,pos[0]+0.045+0.15], $
     [pos[3]-0.02,pos[3]-0.02], $
     color=ncolor, linestyle=1, /normal
xyouts,pos[0]+0.050+0.15, pos[3]-0.0225, "TRMM PR", $
     charsize=0.6,color=ncolor,alignment=0,/normal

plots,[pos[0]+0.015+0.15,pos[0]+0.045+0.15], $
     [pos[3]-0.035,pos[3]-0.035], $
     color=ncolor, linestyle=0, /normal
;xyouts,pos[0]+0.050+0.15, pos[3]-0.035, "WSR-88D", $
xyouts,pos[0]+0.050+0.15, pos[3]-0.0375, siteID+" GV", $
     charsize=0.6,color=ncolor,alignment=0,/normal

end                     
