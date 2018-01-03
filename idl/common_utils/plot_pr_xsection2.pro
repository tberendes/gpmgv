pro plot_pr_xsection2, scanNumpr, raystartpr, rayendpr, z_data, meanbb, scale, $
                      img_sweep_sep, TITLE=caseTitle

; "Include" file for PR-product-specific parameters (i.e., RAYSPERSCAN):
@pr_params.inc

; precompute the reuseable ray angle trig variables for parallax:
cos_inc_angle = DBLARR(RAYSPERSCAN)
tan_inc_angle = DBLARR(RAYSPERSCAN)
cos_and_tan_of_pr_angle, cos_inc_angle, tan_inc_angle

xsect2d = z_data[scanNumpr, raystartpr:rayendpr, *]
idxclutter = WHERE( xsect2d LT 0.0, nclutr )
IF ( nclutr GT 0 ) THEN xsect2d[idxclutter] = 0.0
xsect2d = xsect2d/scale  ; unscale PR dbz
; get rid of 3rd dimension of size 1, and flip vertically to account for
; bin order (surface bin = 80)
xsect2d = REVERSE( REFORM( xsect2d ), 2 )
arsize = SIZE( xsect2d )
;print, arsize
nrays = arsize[1] & nbins = arsize[2]
ysize = (320/nbins)*nbins & xsize = (ysize/nrays)*nrays
raywidth = xsize/nrays
xwinsize = xsize + 50
ywinsize = ysize*2
image2render = BYTARR(xwinsize,ysize)  ; hold x-sect image plus color bar
print, 'xsize, ysize: ', xsize, ysize

; set up the 16-level color table from the PPI as the bottom half of color table
; -- set values 122-127 as white, for labels and such
tvlct, rr,gg,bb,/get
rr[122:127] = 255
gg[122:127] = 255
bb[122:127] = 255
tvlct, rr,gg,bb

dbzstep = 5  ; from one 'base' color to next -- 'split' each base color into
             ; this many shades
incolors = 17    ; number of 'base' colors in LUT
nsteps = 17 ;*dbzstep  ; number of colors for our image
ystep = ysize/nsteps
ybarsize = ystep * nsteps
colorbar = BYTARR(15,ybarsize)
colorbar_y = (ysize-ybarsize)/2  ; y position of bottom of colorbar in image
; fill color bar values
FOR i = 0, nsteps-1 DO BEGIN
   colorbar[*,ystep*i:ystep*(i+1)-1] = i
ENDFOR

; put a white boundary around color bar
colorbar[*,0]=122 & colorbar[*,ybarsize-1]=122
colorbar[0,*]=122 & colorbar[14,*]=122

; burn color bar into image
image2render[xsize+10:xsize+10+15-1,colorbar_y:colorbar_y+ybarsize-1] = colorbar

; build the x-section as an image array --
; see geo_match/loadcolortable.pro for the dbz mapping to colors used below
maxprval = MAX(xsect2d)
maxprstr = STRING( maxprval, FORMAT='(f0.1)' )
xsectimg = BYTE( REBIN( xsect2d, xsize, ysize, /SAMPLE )/5 +2 )
; blank out a line of pixels at the between-sweep volume sample bounds
ixdswpsep = WHERE( img_sweep_sep EQ 100B, countsep )
IF ( countsep GT 0 ) THEN BEGIN
help, xsectimg
help, img_sweep_sep
print, 'burning in sweep top delimiter'
   xsectimg[ixdswpsep] = 0B
ENDIF
WINDOW, 3, xsize=xwinsize, ysize=ywinsize
image2render[0,0] = xsectimg
; plot the PPI-colored x section in the top half of the window
TV, image2render, 0
;TV, xsectimg

; label the color bar
labels = ['<0','0','5','10','15','20','25','30','35','40','45','50','55','60','65','70']
FOR i = 0, nsteps-1 DO BEGIN
   IF i LT nsteps-1 THEN BEGIN
      XYOUTS, xsize+30, ysize+colorbar_y+ystep*(i+1)-4, labels[i], COLOR=122, /DEVICE
   ENDIF
ENDFOR

; get bright band level
bb_y = FIX(meanbb * 16.0)  ; assumes 4 pixels/gate, gate is 0.25 km deep
bb_y_upr = FIX( (meanbb+0.250) *16.0 )
bb_y_lwr = FIX( (meanbb-0.250) * 16.0 )
bbstr = STRING(meanbb, FORMAT='(f0.1)')

; plot bright band lines: middle, upper bound, lower bound
PLOTS, [0,xsize-1], [bb_y+ysize,bb_y+ysize], /DEVICE, COLOR=0, THICK=2, LINESTYLE=2
PLOTS, [0,xsize-1], [bb_y_upr+ysize,bb_y_upr+ysize], /DEVICE, COLOR=0, LINESTYLE=1
PLOTS, [0,xsize-1], [bb_y_lwr+ysize,bb_y_lwr+ysize], /DEVICE, COLOR=0, LINESTYLE=1

yoff = 0
IF N_ELEMENTS( caseTitle ) EQ 1 THEN BEGIN
   XYOUTS, 15, ysize+ysize-20, COLOR=122, caseTitle, /DEVICE
   yoff = 15
ENDIF
XYOUTS, 15, ysize+ysize/2, COLOR=122, 'A', /DEVICE, CHARSIZE=1.5
XYOUTS, xsize-23, ysize+ysize/2, COLOR=122, 'B', /DEVICE, CHARSIZE=1.5
XYOUTS, 15, ysize+(ysize-20)-yoff, COLOR=122, $
        'Original PR gates, using PPI color scale', /DEVICE
XYOUTS, 15, ysize+(ysize-35)-yoff, COLOR=122, '(5 dBZ steps)', /DEVICE
XYOUTS, 15, ysize+(ysize-50)-yoff, COLOR=122, $
   'Max = '+maxprstr+' dBZ,  Mean Bright Band = '+bbstr+' km', /DEVICE

; do another x-section, using more colors and more resolution of dBZ values
; -- render in image values 128-255, using another color table
image2render[*,*] = 0B

; build a 1-dbz-resolution color bar
ybarsize=249
colorbar = BYTARR(15,ybarsize)
colorbar_y = (ysize-ybarsize)/2  ; y position of bottom of colorbar in image
; fill color bar values
nlabels2do = 0
for i = 0, ybarsize-1 do begin
   colorbar[*,i] = i/2 + 128
   if ( i MOD 20 EQ 0 ) THEN BEGIN
      nlabels2do = nlabels2do+1
      colorbar[*,i] = 128  ; mark every 5 dBZ (10 counts)
   endif
endfor

; put a white boundary around color bar
colorbar[*,0]=122 & colorbar[*,ybarsize-1]=122
colorbar[0,*]=122 & colorbar[14,*]=122

; burn color bar into image
image2render[xsize+10:xsize+10+15-1,colorbar_y:colorbar_y+ybarsize-1] = colorbar

; load compressed color table 33 into LUT values 128-255
loadct, 33
tvlct, rrhi, gghi, bbhi, /get
FOR j = 1,127 DO BEGIN
   rr[j+128] = rrhi[j*2]
   gg[j+128] = gghi[j*2]
   bb[j+128] = bbhi[j*2]
ENDFOR
tvlct, rr,gg,bb

; load the image array with PR gate values
;xsectimghi = BYTE( REBIN((xsect2d*2+128.0)<256., xsize, ysize, /SAMPLE ) )
xsectimghi = BYTARR(xsize, ysize)
for k = 0, nrays-4 DO BEGIN
   for l = 0, nbins - 1 DO BEGIN
      xstart=k*raywidth & xend = xstart + raywidth -1
      ystart = FIX( l*4*cos_inc_angle[raystartpr+k] ) < 319
      yend = FIX( (l+1)*4*cos_inc_angle[raystartpr+k] ) < 319
      xsectimghi[xstart:xend,ystart:yend] = BYTE( (xsect2d[k,l]*2+128.0)<256. )
   endfor
endfor
; blank out a line of pixels at the between-sweep volume sample bounds
ixdswpsep = WHERE( img_sweep_sep EQ 100B, countsep )
IF ( countsep GT 0 ) THEN BEGIN
help, xsectimghi
help, img_sweep_sep
print, 'burning in sweep top delimiter'
   xsectimghi[ixdswpsep] = 0B
ENDIF
image2render[0,0] = xsectimghi
; insert a separator at the top of the lower image
image2render[*,ysize-2:ysize-1] = 122B
TV, image2render, 1

XYOUTS, 15, ysize/2, COLOR=122, 'A', /DEVICE, CHARSIZE=1.5
XYOUTS, xsize-23, ysize/2, COLOR=122, 'B', /DEVICE, CHARSIZE=1.5
IF N_ELEMENTS( caseTitle ) EQ 1 THEN $
   XYOUTS, 15, ysize-20, COLOR=122, caseTitle, /DEVICE
XYOUTS, 15, (ysize-20)-yoff, COLOR=122, 'Original PR gates, with 1 dBZ resolution', $
        /DEVICE ;, CHARSIZE=1.5, CHARTHICK=2
XYOUTS, 15, (ysize-35)-yoff, COLOR=122, $
   'Max = '+maxprstr+' dBZ,  Mean Bright Band = '+bbstr+' km', /DEVICE

; plot bright band lines: middle, upper bound, lower bound
PLOTS, [0,xsize-1], [bb_y,bb_y], /DEVICE, COLOR=0, THICK=2, LINESTYLE=2
PLOTS, [0,xsize-1], [bb_y_upr,bb_y_upr], /DEVICE, COLOR=0, LINESTYLE=1
PLOTS, [0,xsize-1], [bb_y_lwr,bb_y_lwr], /DEVICE, COLOR=0, LINESTYLE=1

; label color bar
FOR i = 0, nlabels2do-1 DO BEGIN
   XYOUTS, xsize+30, colorbar_y + 20*i - 4, labels[i+1], COLOR=122, /DEVICE
ENDFOR

; burn in a vertical scale on either side of the two x-sections
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

end
