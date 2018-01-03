pro plot_pr_zdiff_xsection, xsect2d, raystartpr, winnum


; "Include" file for PR-product-specific parameters (i.e., RAYSPERSCAN):
@pr_params.inc

;IF ( N_ELEMENTS(altWindow) NE 1 ) THEN winnum=3 ELSE winnum=altWindow

; compute the ray angle trig variables for parallax (only cos() used here):
cos_inc_angle = DBLARR(RAYSPERSCAN)
tan_inc_angle = DBLARR(RAYSPERSCAN)
cos_and_tan_of_pr_angle, cos_inc_angle, tan_inc_angle

arsize = SIZE( xsect2d )
print, 'plot_pr_diff_xsection(), arsize: ', arsize
nrays = arsize[1] & nbins = arsize[2]

nbins2plot = nbins<80
ysize = (320/nbins2plot)*nbins2plot & xsize = (ysize/nrays)*nrays
raywidth = xsize/nrays
bindepth = ysize/nbins2plot
xwinsize = xsize + 50
ywinsize = ysize
image2render = BYTARR(xwinsize,ysize)  ; hold x-sect image plus color bar
print, 'xsize, ysize: ', xsize, ysize

; build the x-section as an image array --
; see geo_match/loadcolortable.pro for the dbz mapping to colors used below
maxprval = MAX(xsect2d)
maxprstr = STRING( maxprval, FORMAT='(f0.1)' )

xsectimg = BYTARR(xsize, ysize)
xsectimg[*,*] = 0b ;2B

for k = 0, nrays-1 DO BEGIN
   for l = 0, ((nbins2plot - 1)<79) DO BEGIN
     ; correct gate top/bottom height for beam parallax and fill image pixels
      xstart=k*raywidth & xend = xstart + raywidth -1
      ystart = FIX( l*bindepth*cos_inc_angle[raystartpr+k] ) < (ysize-1)
      yend = FIX( (l+1)*bindepth*cos_inc_angle[raystartpr+k] ) < (ysize-1)
if xend LE xstart OR yend LE ystart then stop
      xsectimg[xstart:xend,ystart:yend] = xsect2d[k,l]
   endfor
endfor

WINDOW, winnum, xsize=xwinsize, ysize=ywinsize, ypos=50, RETAIN=2
image2render[0,0] = xsectimg

; build a colorbar for the difference image
ybarsizedif=254
colorbardif = BYTARR(15,ybarsizedif)
colorbar_ydif = (ysize-ybarsizedif)/2  ; y position of bottom of colorbar in image
nlabelsdif = 0
tvlct, rr,gg,bb,/get  ; colors' arrays

red = 0 & blue = 1
for i = 1, ybarsizedif-1 do begin
   colorbardif[*,i] = byte(i/12)+4
   if ( i MOD 12 EQ 0 ) THEN BEGIN
      nlabelsdif = nlabelsdif+1
      colorbardif[*,i] = 0b  ; mark every 1 dBZ (12 rows)
   endif
endfor

; put a white boundary around color bar
colorbardif[*,0]=255 & colorbardif[*,ybarsizedif-1]=255
colorbardif[0,*]=255 & colorbardif[14,*]=255
; burn color bar into image
image2render[xsize+5:xsize+5+15-1,colorbar_ydif:colorbar_ydif+ybarsizedif-1] = colorbardif

; plot the difference image

; set up discrete colors
rgb24=[ $
[90,90,90],$      ;black
[255,255,255],$   ;white
[105,105,105],$   ;dim gray
[211,211,211],$   ;light gray
[255,20,147],$    ;deep pink
[255,105,180],$   ;hot pink
[255,192,203],$   ;pink
[255,0,0],$       ;red
[255,160,122],$   ;light salmon
[205,92,92],$     ;indian red
[139,0,0],$       ;dark red
[255,140,0],$     ;dark orange
[255,205,0],$     ;gold
[255,255,0],$     ;yellow
[255,255,255],$   ;white
[173,255,47],$    ;SpringGreen
[128,128,0],$     ;olive
[0,80,0],$        ;green
[0,139,139],$     ;dark cyan
[0,255,255],$     ;cyan
[65,105,225],$    ;royal blue
[0,0,255], $      ;blue
[153,50,204],$    ;dark orchid
[128,0,128],$     ;purple
[255,0,255] $     ;magenta
]

rr[0:24]=rgb24[0,*]
gg[0:24]=rgb24[1,*]
bb[0:24]=rgb24[2,*]

; set up unassigned/missing areas as gray
rr[230:250] = 100b ;128b ; made darker to split gray from olive green
gg[230:250] = 100b ;128b
bb[230:250] = 100b ;128b
; set 255 to white and 0 to black
rr[255] = 255b
gg[255] = 255b
bb[255] = 255b
rr[0] = 0b
gg[0] = 0b
bb[0] = 0b
tvlct, rr,gg,bb
TV, image2render

; burn in a vertical scale on either side of the diff x-section
tickcolr = 0
FOR h = 1, 19 DO BEGIN
   xlen = 4
   IF h mod 5 EQ 0 THEN xlen = 7
   yh = h*16-1
   PLOTS, [xsize-xlen-1,xsize-1], [yh,yh], /DEVICE, COLOR=tickcolr
   PLOTS, [xsize-xlen-1,xsize-1], [yh+ysize,yh+ysize], /DEVICE, COLOR=tickcolr
   PLOTS, [0,xlen-1], [yh,yh], /DEVICE, COLOR=tickcolr
   PLOTS, [0,xlen-1], [yh+ysize,yh+ysize], /DEVICE, COLOR=tickcolr
ENDFOR

; label the color bar
labels = ['-10','-9','-8','-7','-6','-5','-4','-3','-2','-1',' 0', $
          ' 1',' 2',' 3',' 4',' 5', ' 6',' 7',' 8',' 9','10']
FOR i = 0, nlabelsdif-1 DO BEGIN
   XYOUTS, xsize+25, colorbar_ydif + 12*i + 3, labels[i], COLOR=122, /DEVICE
ENDFOR

END
