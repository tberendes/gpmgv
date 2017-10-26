pro plot_geo_match_xsections2, gvz, zcor, top, botm, meanbb, nsweeps, $
                              idxscan, idxmin, idxmax, img_sweep_sep, $
                              TITLE=caseTitle

; set up the image size and the width of each ray in pixels
nrays = ABS(idxmax-idxmin)+1
ysize = 320   ; for now -- should be input parm.
xraywidth = ysize/nrays
xsize = xraywidth*nrays
;print, 'xsize, ysize: ', xsize, ysize

xwinsize = xsize + 50
ywinsize = ysize*2
image2render = BYTARR(xwinsize,ysize)  ; hold x-sect image plus color bar

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

imagepr = BYTARR(xsize,ysize)
imagepr[*,*] = 128B
imagegv = imagepr
img_sweep_sep = imagepr  ; will use this to demarcate the between-sweep bounds
ascend = 1
if (idxmax LT idxmin) THEN ascend = 0
WINDOW, 5, xsize=xwinsize, ysize=ywinsize

gvmax = 0.0 & prmax = 0.0

for iframe = 0, nsweeps-1  do begin
  ; get this sweep's subarrays
   gvsweep = gvz[*,iframe]
   prsweep = zcor[*,iframe]
   topsweep = top[*,iframe]
   botmsweep = botm[*,iframe]
   IF ( iframe GT 0 ) THEN oversweep = top[*,iframe-1]

  ; find the max values for points along the scan, prior to clipping dBZs
   gvmax = MAX(gvsweep[idxscan])>gvmax
   prmax = MAX(prsweep[idxscan])>prmax

  ; prep the scan values to load into the image arrays: clip hi/low values
   prsweep = prsweep > 0.0  ; get rid of negative values
   gvsweep = gvsweep > 0.0
   prsweep = prsweep < 63.0  ; allow for scaling to dBZ*2, within half byte
   gvsweep = gvsweep < 63.0

  ; get our PR scan's points from the sweep
   gvscan = BYTE( gvsweep[idxscan]*2+128.0 )  ; convert to byte and scale up
   prscan = BYTE( prsweep[idxscan]*2+128.0 )  ; convert to byte and scale up
   topscan = topsweep[idxscan]
   botmscan = botmsweep[idxscan]
  ; take the midpoint if the current scan overlaps prior scan
   IF ( iframe GT 0 ) THEN BEGIN
      overscan = oversweep[idxscan]
      idxoverlap = WHERE( botmscan LT overscan, numovrlap )
      IF ( numovrlap GT 0 ) THEN botmscan[idxoverlap] = $
          (botmscan[idxoverlap]+overscan[idxoverlap])/2.0
   ENDIF
      

  ; compute image y-locations of sample volume's top and bottom,
  ;   based on 4 pixels per .25 km (80 rays in 320 image pixels)
   kmperpix = 0.25/4.0
   topscan = FIX(topscan/kmperpix)
   botmscan = FIX(botmscan/kmperpix)

  ; fill the image array with dbz values based on pixel bounds of each volume
   nraysgeo = N_ELEMENTS(gvscan)
   IF ( nrays NE nraysgeo ) THEN BEGIN
      print, 'Oh, *%&^$!, do not have matching number of rays in geo_match!'
      goto, errorExit
   ENDIF

  ; plot left-to-right in ascending ray number order; used idxmin and idxmax to
  ; determine whether points are in ascending or descending ray order.  For now
  ; we'll assume that the data we extract for the scan are in sequential ray
  ; order, either ascending or descending, and don't need sorting.

   IF ( ascend EQ 1 ) THEN BEGIN
      istart=0  &  iend=nraysgeo-1  &  istep=1
   ENDIF ELSE BEGIN
      istart=nraysgeo-1  &  iend=0  &  istep=-1
   ENDELSE

   xleft = 0
   for iray = istart, iend, istep  do begin
      xright = xleft+xraywidth-1
      IF ( botmscan[iray] GE 0 AND topscan[iray] GT 0 ) THEN BEGIN
         IF topscan[iray] GE ysize THEN BEGIN
            topscan[iray] = ysize-1  ; TALL echoes happen!
            PRINT, 'Adjusted echo top height of: ', topsweep[idxscan[iray]]
            PRINT, 'PR, GV dBZs:', prsweep[idxscan[iray]], gvsweep[idxscan[iray]]
         ENDIF
         IF botmscan[iray] GE ysize THEN BEGIN  ; not THIS tall, I hope!
            PRINT, 'Bottom of echo volume at excessive height: ', $
                   botmsweep[idxscan[iray]]
            PRINT, 'Skipping volume.'
            CONTINUE
         ENDIF
         imagepr[xleft:xright,botmscan[iray]:topscan[iray]] = prscan[iray]
         imagegv[xleft:xright,botmscan[iray]:topscan[iray]] = gvscan[iray]
        ; set up a delimiter for embedding, if volume is deep enough
         IF ( iframe LT 2 ) THEN BEGIN
         FOR kpix = xleft, xright DO BEGIN
            IF kpix MOD 3 EQ 0 THEN img_sweep_sep[kpix,topscan[iray]] = 100B
            img_sweep_sep[kpix,botmscan[iray]] = 100B
         ENDFOR
         ENDIF
      ENDIF
      xleft = xright+1
   endfor

endfor  ; iframe loop

gvmaxstr = STRING(gvmax, FORMAT='(f0.1)')  ; for annotations: GV max dBZ
prmaxstr = STRING(prmax, FORMAT='(f0.1)')  ; ditto, PR

; prep for bright band plotting, labeling
bb_y = FIX(meanbb / kmperpix)
; assume BB is 500m thick, centered on meanbb, and compute upper/lower y-bounds
bb_y_upr = FIX( (meanbb+0.250) / kmperpix )
bb_y_lwr = FIX( (meanbb-0.250) / kmperpix )
bbstr = STRING(meanbb, FORMAT='(f0.1)')

; blank out a line of pixels at the between-sweep volume sample bounds
ixdswpsep = WHERE( img_sweep_sep EQ 100B, countsep )
IF ( countsep GT 0 ) THEN BEGIN
   imagepr[ixdswpsep] = 0B
   imagegv[ixdswpsep] = 0B
ENDIF

; load compressed color table 33 into LUT values 128-255
tvlct, rr, gg, bb, /get
loadct, 33
tvlct, rrhi, gghi, bbhi, /get
FOR j = 1,127 DO BEGIN
   rr[j+128] = rrhi[j*2]
   gg[j+128] = gghi[j*2]
   bb[j+128] = bbhi[j*2]
   rr[122:127] = 255
   gg[122:127] = 255
   bb[122:127] = 255
ENDFOR
tvlct, rr,gg,bb

; PLOT THE IMAGES
image2render[0,0] = imagepr
TV, image2render, 0
image2render[0,0] = imagegv
; insert a separator at the top of the lower image
image2render[*,ysize-2:ysize-1] = 122B
TV, image2render, 1

; ADD THE ANNOTATIONS, SCALES, ETC.
yoff = 0
IF N_ELEMENTS( caseTitle ) EQ 1 THEN BEGIN
   XYOUTS, 15, ysize-20, COLOR=122, caseTitle, /DEVICE
   yoff = 15
ENDIF
XYOUTS, 15, ysize/2, COLOR=122, 'A', /DEVICE, CHARSIZE=1.5 ;, CHARTHICK=2
XYOUTS, xsize-23, ysize/2, COLOR=122, 'B', /DEVICE, CHARSIZE=1.5 ;, CHARTHICK=2
XYOUTS, 15, (ysize-20)-yoff, COLOR=122, $
    'Volume-matching GV samples, 1 dBZ resolution', $
    /DEVICE ;, CHARSIZE=1.5, CHARTHICK=2
XYOUTS, 15, (ysize-35)-yoff, COLOR=122, $
   'Max = '+gvmaxstr+' dBZ,  Mean Bright Band = '+bbstr+' km', /DEVICE
; plot bright band lines: middle, upper bound, lower bound
PLOTS, [0,xsize-1], [bb_y,bb_y], /DEVICE, COLOR=0, THICK=2, LINESTYLE=2
PLOTS, [0,xsize-1], [bb_y_upr,bb_y_upr], /DEVICE, COLOR=0, LINESTYLE=1
PLOTS, [0,xsize-1], [bb_y_lwr,bb_y_lwr], /DEVICE, COLOR=0, LINESTYLE=1

IF N_ELEMENTS( caseTitle ) EQ 1 THEN $
   XYOUTS, 15, ysize*2-20, COLOR=122, caseTitle, /DEVICE
XYOUTS, 15, (3*ysize)/2, COLOR=122, 'A', /DEVICE, CHARSIZE=1.5 ;, CHARTHICK=2
XYOUTS, xsize-23, (3*ysize)/2, COLOR=122, 'B', /DEVICE, CHARSIZE=1.5 ;, CHARTHICK=2
XYOUTS, 15, (ysize*2-20)-yoff, COLOR=122, $
    'Volume-matching PR samples, 1 dBZ resolution', $
    /DEVICE ;, CHARSIZE=1.5, CHARTHICK=2
XYOUTS, 15, (ysize*2-35)-yoff, COLOR=122, $
   'Max = '+prmaxstr+' dBZ,  Mean Bright Band = '+bbstr+' km', /DEVICE
; plot bright band lines: middle, upper bound, lower bound
PLOTS, [0,xsize-1], [bb_y+ysize,bb_y+ysize], /DEVICE, COLOR=0, THICK=2, LINESTYLE=2
PLOTS, [0,xsize-1], [bb_y_upr+ysize,bb_y_upr+ysize], /DEVICE, COLOR=0, LINESTYLE=1
PLOTS, [0,xsize-1], [bb_y_lwr+ysize,bb_y_lwr+ysize], /DEVICE, COLOR=0, LINESTYLE=1

; label the color bar
labels = ['<0','0','5','10','15','20','25','30','35','40','45','50','55','60','65','70']
FOR i = 0, nlabels2do-1 DO BEGIN
   XYOUTS, xsize+30, colorbar_y + 20*i - 4, labels[i+1], COLOR=122, /DEVICE
   XYOUTS, xsize+30, colorbar_y+20*i-4+ysize, labels[i+1], COLOR=122, /DEVICE
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

errorExit:
END

