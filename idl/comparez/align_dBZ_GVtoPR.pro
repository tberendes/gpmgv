pro align_dBZ_GVtoPR, dbzcor_in, dbznex, sectors

dbzcor = dbzcor_in    ; don't alter the original PR field

xoff=0
yoff=0
imsiz=75     ; fixed for now, should be input parameter
;sectors=7    ; fixed for now, should be input parameter

step=imsiz/sectors
; control point arrays
; - now add extra points at boundaries of image array at end of each
;   row/column of control points, and corners of image, for warp_tri
xp=intarr(sectors*sectors + sectors*4)
yp=intarr(sectors*sectors + sectors*4)
xn=intarr(sectors*sectors + sectors*4)
yn=intarr(sectors*sectors + sectors*4)

idxstart = sectors*sectors

for ysect = 0, sectors-1 do begin
  for xsect = 0, sectors-1 do begin
    xstart=xsect*step        ; define start/end of image subsectors
    xend=(xsect+1)*step-1
    ystart=ysect*step
    yend=(ysect+1)*step-1
    primg = dbzcor[xstart:xend, ystart:yend]  ; cut out a sector subset image
    nximg = dbznex[xstart:xend, ystart:yend]
    idx=xsect+ysect*sectors
    xp[idx]=xstart+step/2  ; set control points in middle of image sectors,
    yp[idx]=ystart+step/2  ; but relative to full image coordinates
;    print, size(nximg)
;    print, size(primg)
;    print, xsect*step, (xsect+1)*step-1, ysect*step, (ysect+1)*step-1
    correl_optimize, primg, nximg, xoff, yoff
;    print, "ysect,xsect = ",ysect*sectors+xsect,"   XOFF = ",xoff,"   YOFF = ", yoff
    ; set control points for nexrad image based on offsets
    if ((xoff eq -4) and (yoff eq -4)) then begin
      xoff = 0  ; weirdness ensued, set offsets to zero
      yoff = 0
    endif
    xn[idx]=xp[idx]-xoff
    yn[idx]=yp[idx]-yoff
;    print, idx, xp[idx], yp[idx], xn[idx], yn[idx]

    if xsect eq 0 then begin
      xp[idxstart] = 0       ; set point at x edge of image
      yp[idxstart] = yp[idx]
      xn[idxstart] = xp[idxstart] - xoff
      yn[idxstart] = yn[idx]
      idxstart = idxstart +1
    endif
    if ysect eq 0 then begin
      yp[idxstart] = 0       ; set point at y edge of image
      xp[idxstart] = xp[idx]
      xn[idxstart] = xn[idx]
      yn[idxstart] = yp[idxstart] - yoff
      idxstart = idxstart +1
    endif
    if xsect eq sectors-1 then begin
      xp[idxstart] = 74       ; set point at x edge of image
      yp[idxstart] = yp[idx]
      xn[idxstart] = xp[idxstart] - xoff
      yn[idxstart] = yn[idx]
      idxstart = idxstart +1
    endif
    if ysect eq sectors-1 then begin
      yp[idxstart] = 74       ; set point at y edge of image
      xp[idxstart] = xp[idx]
      xn[idxstart] = xn[idx]
      yn[idxstart] = yp[idxstart] - yoff
      idxstart = idxstart +1
    endif

  endfor
endfor

; A PROBLEM WITH USING WARP_TRI IS THAT IT INTERPOLATES POINTS WHEN SHIFTING,
; SO THE DBZ VALUES GET SMOOTHED (AGAIN) -- MAXIMA ARE REDUCED, MINIMA ARE RAISED

; convert dBZ to Z for interpolation under WARP_TRI
;zcor = 10.^(0.1*dbzcor)
;znex = 10.^(0.1*dbznex)
znex = dbznex
;POLYWARP, xn,yn,xp,yp,1,p,q
;nximgwarp = POLY_2D(pairimg[*,*,1],p,q,0,300,300)
;nximgwarp = warp_tri(xp,yp,xn,yn,pairimg[*,*,1],OUTPUT_SIZE=[300,300],/EXTRAPOLATE)
nximgwarp = warp_tri(xp,yp,xn,yn,znex[*,*],OUTPUT_SIZE=[75,75],/EXTRAPOLATE,/TPS)

; convert Z back to dBZ
;dbznex = 10.*ALOG10(nximgwarp)
dbznex = nximgwarp
;if (countnozn gt 0) then dbznex[idxneg3] = -99.99

end
