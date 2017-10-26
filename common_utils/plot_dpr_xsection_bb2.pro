;===============================================================================
;+
; Copyright � 2010, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; plot_dpr_xsection_bb.pro    Morris/SAIC/GPM_GV    April 2010
;
; DESCRIPTION
; -----------
; Takes a full array of TRMM 2A-25 3-D reflectivity, parameters specifying the
; scan line and beginning and ending rays in the product for which a cross
; section of data is to be plotted, and bright band mean height and an optional
; plot title, and generates a pair of vertical cross sections of full-resolution
; PR reflectivity.  The top plot uses the coarse color table of the PPI plots
; with a 3 dBZ color binning, and the lower plot uses a 'smooth' IDL color table
; showing 1 dBZ color separation.  A parallax correction for the scan angle of
; the PR is applied to the height of each 250-m PR gate.
;
; The plots use a default value of 320 pixels in height for each of the two
; cross section plots, to match the dimensions of the plots of geometry-matched
; PR and GV data generated by the 'plot_geo_match_xsection' procedure.  The
; width of the cross-section plots, and of each plotted ray, varies according
; to the number of rays to be plotted.
;
; PARAMETERS
; ----------
; scanNumpr  - PR-product-relative number of the PR scan whose data are to be
;              plotted as a vertical cross section.  Zero-based array index.
; raystartpr - Starting ray of the scan to plot in the cross section.  Zero-
;              based array index into the full data array.
; rayendpr   - As above, but ending ray to plot in the cross section.
; z_data     - Full array of (assumed) 2A-25 3-D corrected reflectivity data.
; meanbb     - Mean height of the bright band, in km.
; scale      - Scale factor to be applied to convert z_data to dBZ units.
; caseTitle  - (Optional) title to be written into the cross section images.
; altWindow  - Optional override for IDL window number to open and plot to.
;
; HISTORY
; -------
; 07/2009  Morris/GPM GV/SAIC  
; - Changed coarse color steps to 3 dBZ to match the PPI color scale.  Fixed
;   labeling of same.
; 08/04/09  Morris/GPM GV/SAIC
; - Fixed the color assignments and color bar.
; 08/06/09  Morris/GPM GV/SAIC
; - Changed color bar logic to eliminate confusion.
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;===============================================================================

pro plot_dpr_xsection_bb2, scanNumpr, raystartpr, rayendpr, z_data, meanbb, $
                          scale, TITLE=caseTitle, ALTWINDOW=altWindow, $
                          SURFBIN=surfbin, CLUTTERFREEBIN=clutterfreebin


; "Include" file for PR-product-specific parameters (i.e., RAYSPERSCAN):
@pr_params.inc

IF ( N_ELEMENTS(altWindow) NE 1 ) THEN winnum=3 ELSE winnum=altWindow

; compute the ray angle trig variables for parallax (only cos() used here):
; -- for now, use the fixed angles rather than the ray-specific DPR zeniths
cos_inc_angle = DBLARR(RAYSPERSCAN)
tan_inc_angle = DBLARR(RAYSPERSCAN)
cos_and_tan_of_pr_angle, cos_inc_angle, tan_inc_angle

;xsect2d = z_data[scanNumpr, raystartpr:rayendpr, *]
xsect2d = z_data[*, raystartpr:rayendpr, scanNumpr]  ;DPR is ordered bin,ray,scan
idxclutter = WHERE( xsect2d LT 0.0, nclutr )
IF ( nclutr GT 0 ) THEN xsect2d[idxclutter] = 0.0

xsect2d = xsect2d/scale  ; unscale PR dbz
; get rid of 3rd dimension of size 1
xsect2d = REFORM( xsect2d )
arsize = SIZE( xsect2d )
print, 'arsize: ', arsize
nrays = arsize[2] & nbins = arsize[1]

; blank out the clutter bins, if information provided
IF (N_ELEMENTS(clutterfreebin) GT 0) THEN BEGIN
   clutterbinnum = clutterfreebin[raystartpr:rayendpr, scanNumpr]
   for k = 0, nrays-1 DO BEGIN
      IF (clutterbinnum[k]) LE (nbins-1) THEN BEGIN
         xsect2d[clutterbinnum[k]:nbins-1,k] = 0.0
      ENDIF
   endfor
ENDIF

; flip Z array vertically to put bins in ascending height order
xsect2d = REVERSE( xsect2d, 1 )

IF (N_ELEMENTS(surfBin) GT 0) THEN BEGIN
  ; compute surface gate number based on gate 0 at top
   sfcbinnum = surfbin[raystartpr:rayendpr, scanNumpr]
  ; adjust surface gate number for flipped Z array
   sfcbinnum = (nbins-sfcbinnum)>0
ENDIF

;IF (N_ELEMENTS(clutterfreebin) GT 0) THEN BEGIN
;  ; compute surface gate number based on gate 0 at top
;   clutterbinnum = clutterfreebin[raystartpr:rayendpr, scanNumpr]
;  ; adjust surface gate number for flipped Z array
;   clutterbinnum = (nbins-clutterbinnum)>0
;ENDIF

   BB_hgt = FLOAT(surfbin)
   BB_hgt[*] = BB_MISSING
   have_bb=0

nbins2plot = nbins<176
ysize = 320 & xsize = (ysize/nrays)*nrays
raywidth = xsize/nrays
bindepth = 2 ;ysize/nbins2plot
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

nsteps = 17      ; number of colors for our image
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

xsectimg = BYTARR(xsize, ysize)
xsectimg[*,*] = 0b ;2B

for k = 0, nrays-1 DO BEGIN
   ; first, start at the at-surface bin, if available
   IF (N_ELEMENTS(surfBin) GT 0) THEN binstart=sfcbinnum[k] ELSE binstart=0
   ; blank out the clutter bins, if information provided
;   IF (N_ELEMENTS(clutterfreebin) GT 0) THEN xsect2d[0:clutterbinnum[k],k]=0.0
   for l = 0, ((nbins2plot - 1)<175) DO BEGIN
     ; correct gate top/bottom height for beam parallax and fill image pixels
      xstart=k*raywidth & xend = xstart + raywidth -1
      ystart = FIX( l*bindepth*cos_inc_angle[raystartpr+k] ) < (ysize-1)
      yend = FIX( (l+1)*bindepth*cos_inc_angle[raystartpr+k] ) < (ysize-1)
if xend LE xstart OR yend LE ystart then break
      IF (l+binstart LT nbins ) THEN $
         xsectimg[xstart:xend,ystart:yend] = $
             BYTE( ( (xsect2d[l+binstart,k]-12.0 > 0)/3 +1)  < 128. )
   endfor
endfor

WINDOW, winnum, xsize=xwinsize, ysize=ywinsize, ypos=50, RETAIN=2
image2render[0,0] = xsectimg
; plot the PPI-colored x section in the top half of the window
TV, image2render, 0

; label the color bar
labels = ['BT','15','18','21','24','27','30','33','36','39','42','45','48','51','54','57']
FOR i = 0, nsteps-1 DO BEGIN
   IF i LT nsteps-1 THEN BEGIN
      XYOUTS, xsize+30, ysize+colorbar_y+ystep*(i+1)-4, labels[i], COLOR=122, /DEVICE
   ENDIF
ENDFOR

; get bright band level
bb_y = FIX(meanbb * 16.0)  ; assumes 4 pixels/gate, gate is 0.25 km deep
; assume BB is from +500m to -750m of meanbb, and compute upper/lower y-bounds
bb_y_upr = FIX( (meanbb+0.750) * 16.0 )
bb_y_lwr = FIX( (meanbb-0.750) * 16.0 )
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
        'Original DPR gates, using PPI color scale', /DEVICE
XYOUTS, 15, ysize+(ysize-35)-yoff, COLOR=122, '(3 dBZ steps)', /DEVICE
XYOUTS, 15, ysize+(ysize-50)-yoff, COLOR=122, $
   'Max = '+maxprstr+' dBZ,  Mean Bright Band = '+bbstr+' km', /DEVICE

; do another x-section, using more colors and more resolution of dBZ values
; -- render in image values 128-255, using another color table
image2render[*,*] = 0B

; build a 1-dbz-resolution color bar
; 1. we do plot the first label (BT)
; 2. we label the bottom of each segment, starting with labels[0] at bottom
;    of bar and ending with last label at bottom of last segment
; 3. we will have this many "segments" in color bar:

       nbarsegs = N_ELEMENTS(labels)

; 4. dbz range of colorbar goes beyond value of last label by one label step (3dBZ):

       zperseg = (FIX(labels[nbarsegs-1])-FIX(labels[nbarsegs-2]))
       zmaxonbar = FIX(labels[nbarsegs-1]) + zperseg
       zminonbar = FIX(labels[1])
       zrange = zmaxonbar-zminonbar

;    we extend the dbz range by one segment to account for the 'below threshold'
;    segment and see how many dbz values we need to show in the total bar length
 
       zrangeext = zrange+zperseg

; 5. we fill the lowest segment with fixed color value for BT (below threshold, < 15dBZ)
; 6. the remaining nbarsegs-1 segments have 127 colors available to be assigned
; 7. increment over the 127 color table colors in (near) equal jumps, when color is
;    associated to next whole dBZ, using the full color range from 129-255

       colorStepPerdbz = 127.0/zrange

; 9. assign an equal number of y-pixels to each dbz (color) within the vertical
;    bounds of the window.  Leave some space above/below bar.

       pixPerColor = (ysize-20)/zrangeext  ; (don't use full image extent for bar)

;    preceding 2 variables are rounded ints, for sizing the bar in the window
;    - the following variables are actual sizes/increments

       ybarsize = pixPerColor * zrangeext + 2  ; (add 2 pixels for bar borders)

; 10. label position y-increment, and color bar "breakpoints":
       ystep = pixPerColor * zPerSeg

; 11. hold colors for all whole dbz from zminonbar to zmaxonbar, plus BT color value:

       color4dbz = BYTARR(zrange+1) 
       color4dbz[*] = 128

; 12. assign bar array and fill color bar values
       colorbar = BYTARR(15,ybarsize)
       colorbar_y = (ysize-ybarsize)/2  ; y position of bottom of colorbar in image

;     do the BT segment first, assign image count 128 to it. Skip the 0th y-pos.
       colorbar[*,1:ystep] = 128

;     do the color bar colors (also image counts) by 1 dBZ steps
       dbzlast = 0
       colorlast = 129
       color4dbz[dbzlast+1] = colorlast
       for i = ystep+1, ybarsize-2 do begin
          if ( (i-1) MOD ystep EQ 0 ) THEN BEGIN
             colorbar[*,i] = 128  ; mark every segment boundary (labeled dBZ location)
          endif else begin
            ; assign a new color if next whole dbz
             thisdbz = FIX( (i-1-ystep)/pixpercolor )
             IF ( thisdbz GT dbzlast ) THEN BEGIN
                dbzlast = thisdbz
                colorlast = FIX( 129 + thisdbz*colorStepPerdbz )
                color4dbz[dbzlast+1] = colorlast
             ENDIF
             colorbar[*,i] = colorlast
;print, 'i: ',i,', dbzlast: ',dbzlast,', colorlast: ',colorlast
         endelse
       endfor

;print, 'max i: ', i-1, ', assigned color: ', colorbar[0,i-1],', colorStepPerdBZ: ', colorStepPerdbz
;print, 'color4dbz: ', color4dbz

; put a white boundary around color bar
colorbar[*,0]=122 & colorbar[*,ybarsize-1]=122
colorbar[0,*]=122 & colorbar[14,*]=122

; burn color bar into image
image2render[xsize+10:xsize+10+15-1,colorbar_y:colorbar_y+ybarsize-1] = colorbar

; load compressed color table 33 into LUT values 129-255
loadct, 33
tvlct, rrhi, gghi, bbhi, /get
FOR j = 1,127 DO BEGIN
   rr[j+128] = rrhi[j*2]
   gg[j+128] = gghi[j*2]
   bb[j+128] = bbhi[j*2]
ENDFOR
; 128 is background color (gray 51) for Below Threshold
rr[128] = 51 & gg[128] = 51 & bb[128]=51
tvlct, rr,gg,bb

; load the image array with PR gate values

xsectimg[*,*] = 0b         ; re-init image array. now using upper half of byte
for k = 0, nrays-1 DO BEGIN
   IF (N_ELEMENTS(surfBin) GT 0) THEN binstart=sfcbinnum[k] ELSE binstart=0
   for l = 0, ((nbins2plot - 1)<175) DO BEGIN
     ; correct gate top/bottom height for beam parallax and fill image pixels
     xstart=k*raywidth & xend = xstart + raywidth -1
;      ystart = FIX( l*4*cos_inc_angle[raystartpr+k] ) < (ysize-1)
;      yend = FIX( (l+1)*4*cos_inc_angle[raystartpr+k] ) < (ysize-1)
      ystart = FIX( l*bindepth*cos_inc_angle[raystartpr+k] ) < (ysize-1)
      yend = FIX( (l+1)*bindepth*cos_inc_angle[raystartpr+k] ) < (ysize-1)
      if xend LT xstart OR yend LT ystart then break
      IF (l+binstart LT nbins ) THEN BEGIN
       ; -- every 1 dBZ in reflectivity increments by colorStepPerdbz image counts,
       ;    starting from a bottom cutoff of 15.0 dBZ at image count of 129
       ; round off the dbz value and look up the assigned image color for the dbz
        coloridx4gate = (FIX(xsect2d[l+binstart,k]-(zminonbar-1)) > 0) < zrange
        xsectimg[xstart:xend,ystart:yend] = color4dbz[coloridx4gate]
      ENDIF
   endfor
endfor
image2render[0,0] = xsectimg
; insert a separator at the top of the lower image
image2render[*,ysize-2:ysize-1] = 122B
TV, image2render, 1

XYOUTS, 15, ysize/2, COLOR=122, 'A', /DEVICE, CHARSIZE=1.5
XYOUTS, xsize-23, ysize/2, COLOR=122, 'B', /DEVICE, CHARSIZE=1.5
IF N_ELEMENTS( caseTitle ) EQ 1 THEN $
   XYOUTS, 15, ysize-20, COLOR=122, caseTitle, /DEVICE
XYOUTS, 15, (ysize-20)-yoff, COLOR=122, 'Original DPR gates, with 1 dBZ resolution', $
        /DEVICE ;, CHARSIZE=1.5, CHARTHICK=2
XYOUTS, 15, (ysize-35)-yoff, COLOR=122, $
   'Max = '+maxprstr+' dBZ,  Mean Bright Band = '+bbstr+' km', /DEVICE

; plot bright band lines: middle, upper bound, lower bound
PLOTS, [0,xsize-1], [bb_y,bb_y], /DEVICE, COLOR=0, THICK=2, LINESTYLE=2
PLOTS, [0,xsize-1], [bb_y_upr,bb_y_upr], /DEVICE, COLOR=0, LINESTYLE=1
PLOTS, [0,xsize-1], [bb_y_lwr,bb_y_lwr], /DEVICE, COLOR=0, LINESTYLE=1

; label lower image's color bar
FOR i = 0, nbarsegs-1 DO BEGIN
   XYOUTS, xsize+30, colorbar_y + ystep*i - 3, labels[i], COLOR=122, /DEVICE
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
