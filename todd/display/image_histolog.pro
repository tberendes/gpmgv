pro image_histolog,array1,array2,MIN_VALUE=min_value,PLOT_GRID=plot_grid,$
	AXIS_RANGE=axis_range,CONTOUR=contour,RES=res,SMOOTHER=smoother,PERCENTILES=percentiles,$
	_EXTRA=keywords
;===============================================================
;Program to compute the 2-D histogram of given arrays and plot it in log coordiantes
;
;INPUT:
;	array1=1-d array to compare with array2
;	array2=1-d array to compare with array1
;OPTIONAL KEYWORDS:
;	AXIS_RANGE = [minimum,maximum] value to plot (default [1e-2,2e2])
;	RES = factor to increase resolution of image (default = 4)
;	/SMOOTHER - set this keyword to produce a much smoother image using IDL SMOOTH FUNCTION
;	/CONTOUR - set this keyword to produce a contour plot (default is image)
;	/PERCENTILES - set this keyword to overplot percentiles
;	/PLOT_GRID - set this keyword to overplot gridlines
;DEPENDENCIES:
;	Coyote IDL graphics package (http://www.idlcoyote.com)
;	tick_labels_exponent.pro (custom function to annotate log axis)
;	spectral_ctable_74.sav (R,G,B values of IDL spectral color table 74)	
;EXAMPLE SYNTAX:
;	image_histolog,arr1,arr2
;HISTORY:
;	Aug 2018-P.Gatlin(NASA/MSFC)
;===============================================================

if(n_elements(array1) eq 0 or n_elements(array2) eq 0) then begin
 print,'Array 1 and Array2 must have more than 1 element' 
 return
endif

min_value=min(10d^[floor(alog10(min(array1))),floor(alog10(min(array2)))])
max_value=max(10d^[ceil(alog10(max(array1))),ceil(alog10(max(array2)))])

if(n_elements(axis_range) eq 0) then begin
 axis_range=[min_value,max_value]
endif else begin ;ensure values are extended to multples of 5 for binning
 if(min(axis_range) lt min_value) then min_value=10d^floor(alog10(min(axis_range)))
 if(max(axis_range) gt max_value) then max_value=10d^ceil(alog10(max(axis_range)))
endelse 

bin_res=0.05d

;-->compute the 2d histogram and its bins locations
hist=hist_2d(alog10(array1),alog10(array2),bin1=bin_res,bin2=bin_res,min1=alog10(min_value),min2=alog10(min_value),$
	max1=alog10(max_value),max2=alog10(max_value))
bins=10^(findgen((alog10(max_value)-alog10(min_value))/(bin_res))*(bin_res)+alog10(min_value))
x=where(bins ge min(axis_range) and bins lt max(axis_range),xcount)
if(abs(max(axis_range)/max(bins[x])-1d) lt 1e-2) then x=x[0:n_elements(x)-2] ;account for binning precision
bins_x=bins[x] & bins_y=bins[x]
hist=hist[min(x):max(x),min(x):max(x)]
nbins=n_elements(hist[0,*])

;interpolate the histogram to make a smoother image
if(n_elements(res) eq 0) then res=4
if keyword_set(smoother) then begin
 hist_interp=long(smooth(hist,res,/edge_truncate))
 sbins_x=smooth(bins_x,res,/edge_truncate)
 sbins_y=smooth(bins_y,res,/edge_truncate)
endif else hist_interp=hist

;assign colors
cgloadct,10 ;green-pink (set bottom color=10, max_color=230+bottom_color)
tvlct,r,g,b,/get
restore,filename='spectral_ctable_74.sav'
r=reverse(r) & g=reverse(g) & b=reverse(b)
r[0]=255 & g[0]=255 & b[0]=255 ;make lowest color white
tvlct,r,g,b
bottom_color = 1 ;index of lowest color
max_color=250+bottom_color ;index of maximum color
ncolors=max_color-bottom_color

max_counts=10*floor(max(hist_interp)/10d)	
colors=bytscl(hist_interp,min=1,max=max_counts,top=max_color-bottom_color)+bottom_color 	

x=where(hist_interp gt max_counts,xcount)
if(xcount gt 0) then colors[x]=max_color+4 ;set exceedance values to 4 indices past max_counts color

x=where(hist_interp eq 0,xcount)
if(xcount gt 0) then colors[x]=0 ;set 0 values to white

!P.POSITION=[0.15,0.15,0.85,0.9]
!P.CHARSIZE=cgdefcharsize()

cgplot,indgen(10),indgen(10),/nodata,xrange=axis_range,yrange=axis_range,/xlog,/ylog,$
 xminor=9,yminor=9,xstyle=1,ystyle=1,charsize=cgdefcharsize()*1.2,$
 xtickformat='(G0.3)',ytickformat='(G0.3)',_EXTRA=keywords


;-->plot image
if keyword_set(contour) then begin
 cgcontour,hist,bins_x,bins_y,levels=lindgen(ncolors)*(max(hist)-min(hist))*1d/ncolors+1,/overplot,$
     xrange=axis_range,yrange=axis_range,xstyle=5,ystyle=5,/xlog,/ylog,/fill,min_value=1,missingvalue=0,$
     palette=[[r[bottom_color:max_color]],[g[bottom_color:max_color]],[b[bottom_color:max_color]]]
endif else begin
 cgimage,colors,/overplot,/fit_inside
endelse

if keyword_set(percentiles) then begin ;plot percentile contours
 if not keyword_set(smoother) then begin
  bins=10^(findgen((alog10(max(axis_range))-alog10(min(axis_range)))/(bin_res*1d/res))*(bin_res*1d/res)+alog10(min(axis_range)))
  x=where(ceil(bins) lt max(axis_range),xcount)
  bins_x=bins[x] & bins_y=bins[x]
 endif
 x=where(hist_interp eq 0,xcount,complement=y)  ;get percentiles
 per=cgpercentiles(hist_interp[y],percentiles=[0.10,0.25,0.5,0.75,0.95])
 cgContour, hist_interp, bins_x,bins_y,LEVELS=[per],charsize=cgdefcharsize()*0.8,/overplot, $
    xrange=axis_range,yrange=axis_range,xstyle=5,ystyle=5,/xlog,/ylog,missingvalue=0,$
     C_Colors=['Light Gray','Medium Gray','Gray','Dark Gray','Charcoal'], C_Annotation=['P10','P25', 'P50','P75','P95']  ;percent of data
endif

;-->plot 1:1 line
cgplots,axis_range,axis_range,linestyle=0,thick=5

;-->redraw axes (image covered up portions of original)
cgplot,indgen(10),indgen(10),/nodata,xrange=axis_range,yrange=axis_range,/xlog,/ylog,/noerase,$
 xminor=9,yminor=9,xstyle=1,ystyle=1,charsize=cgdefcharsize()*1.2,$
  xtickformat='(G0.3)',ytickformat='(G0.3)',_EXTRA=keywords

if keyword_set(plot_grid) then begin
 ;populate bins
 max_exp=ceil(alog10(max(axis_range)))
 min_exp=floor(alog10(min(axis_range)))
 n_minor=9
 bins=dblarr((max_exp-min_exp)*n_minor+1)
 for i=0,max_exp-min_exp-1 do bins[i*n_minor:(i+1)*n_minor-1]=indgen(n_minor)*10.^(i+min_exp)+10.^(i+min_exp)
 bins[i*n_minor]=0*10.^(i+min_exp)+10.^(i+min_exp)  ;last bin must be populated to serve as upper bound 
 x=where(bins le max(axis_range))
 bins_x=bins[x] & bins_y=bins[x]
 for i=0,n_elements(bins_x)-1 do cgplots,bins_x[i],[min(bins_y),max(bins_y)],color='black',linestyle=1,noclip=0
 for i=0,n_elements(bins_y)-1 do cgplots,[min(bins_x),max(bins_x)],bins_y[i],color='black',linestyle=1,noclip=0
endif 


;plot colorbar on the right
cgcolorbar,range=[0,max_counts],ncolors=max(colors)-min(colors),bottom=min(colors),oob_high=max(colors),$
	/vertical,charsize=cgdefcharsize()*0.8,title='Number of Samples',/right,$
	position=[(1.+!X.WINDOW[1])/2.-(1.-!X.WINDOW[1])/4d,!Y.WINDOW[0],(1.+!X.WINDOW[1])/2.+(1.-!X.WINDOW[1])/32d,!Y.WINDOW[1]]

END
