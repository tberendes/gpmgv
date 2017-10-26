;+
; Copyright © 2008, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; cwanimate_Match_w_stats.pro
;
; Demonstrates IDL's capability to do multiple animations in separate windows.
; Also, a playpen for doing gridded PR-GV reflectivity image alignment.
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-

pro animat_ehandler, ev
widget_control, /destroy, ev.top
end

pro cwanimate_Match_w_stats

;##################################
sectors=5
;###############
height = 6.0
;##################################
prin = 2*FIX((height-1.5)/1.5)     ;even numbers: 0,2,4,6,...24
;print, 'prin = ', prin

pathpr='/data/netcdf/PR'
pathgv='/data/netcdf/NEXRAD/GV'

ncfilepr = dialog_pickfile(path=pathpr)

while ncfilepr ne '' do begin

bname = file_basename( ncfilepr )
prlen = strlen( bname )
gvpost = strmid( bname, 2, prlen)
ncfilegv = pathgv + gvpost

print, ncfilegv

; Get uncompressed copy of the found files
cpstatus = uncomp_file( ncfilepr, ncfile1 )
if(cpstatus eq 'OK') then begin
  cpstatus2 = uncomp_file( ncfilegv, ncfile2 )
  if(cpstatus2 eq 'OK') then begin
     ncid1 = NCDF_OPEN( ncfile1 )
     ncid2 = NCDF_OPEN( ncfile2 )

     siteID = ""
     NCDF_VARGET, ncid1, 'site_ID', siteIDbyte
     NCDF_VARGET, ncid1, 'site_lat', siteLat
     NCDF_VARGET, ncid1, 'site_lon', siteLong
     NCDF_VARGET, ncid1, 'timeNearestApproach', event_time
     NCDF_VARGET, ncid2, 'beginTimeOfVolumeScan', event_time2
     siteID = string(siteIDbyte)
     print, siteID, siteLat, siteLong, event_time, event_time2

     NCDF_VARGET, ncid1, 'correctZFactor', dbzcor
     NCDF_VARGET, ncid2, 'threeDreflect', dbznex

     NCDF_CLOSE, ncid1
     command3 = "rm -v " + ncfile1
     spawn, command3

     NCDF_CLOSE, ncid2
     command4 = "rm -v " + ncfile2
     spawn, command4
  endif else begin
     print, 'Cannot find GV netCDF file: ', ncfilegv
     print, cpstatus2
  endelse
endif else begin
  print, 'Cannot copy/unzip PR netCDF file: ', ncfilepr
  print, cpstatus
  command3 = "rm -v " + ncfile1
  spawn, command3
  goto, errorExit
endelse

idxneg = where(dbzcor eq -9999.0, countnoz)
if (countnoz gt 0) then dbzcor[idxneg] = 0.0
if (countnoz gt 0) then dbznex[idxneg] = 0.0
idxneg = where(dbzcor eq -100.0, countbelowmin)
if (countbelowmin gt 0) then dbzcor[idxneg] = 0.0
if (countbelowmin gt 0) then dbznex[idxneg] = 0.0
idxneg = where(dbznex lt 0.0, countnoz)
if (countnoz gt 0) then dbznex[idxneg] = 0.0
if (countnoz gt 0) then dbzcor[idxneg] = 0.0

; Compute a mean dBZ difference at each level
ourlev = prin/2
print, ''
print, 'DISPLAYED LEVEL: ', (ourlev+1)*1.5
print, ''
for lev2get = 0, 12 do begin
   dbzcor2diff = dbzcor[*,*,lev2get]
   dbznex2diff = dbznex[*,*,lev2get]
   idxpos1 = where(dbzcor2diff ge 18.0, countpos1)
   if (countpos1 gt 0) then begin
      dbzpr1 = dbzcor2diff[idxpos1]
      dbznx1 = dbznex2diff[idxpos1]
      idxpos2 = where(dbznx1 gt 18.0, countpos2)
      if (countpos2 gt 0) then begin
         dbzpr2 = dbzpr1[idxpos2]
         dbznx2 = dbznx1[idxpos2]
         meandiff = mean(dbzpr2-dbznx2)
         print, 'LEVEL: ', (lev2get+1)*1.5, $
              '  MEAN PR-NEXRAD DIFFERENCE:  ', meandiff
      endif
   endif
endfor
print, ''

dbzimgc = byte(dbzcor)
dbzimgn = byte(dbznex)
dbzimg = bytarr(75,75,26)
for level = 0, 12 do begin
  dbzimg[*,*,level*2] = dbzimgc[*,*,level]
  dbzimg[*,*,level*2+1] = dbzimgn[*,*,level]
endfor

xoff=0
yoff=0
;###############
;sectors=5
;###############
imsiz=75
step=imsiz/sectors
dbzimgsec=bytarr(step, step, sectors*sectors*2)
; control point arrays
; - now add points at boundaries of image array at end of each
;   row/column of control points, and corners of image, for warp_tri
xp=intarr(sectors*sectors + sectors*4)
yp=intarr(sectors*sectors + sectors*4)
xn=intarr(sectors*sectors + sectors*4)
yn=intarr(sectors*sectors + sectors*4)

;input image selection - PR and NEXRAD alternate
nxin = prin + 1

idxstart = sectors*sectors

for ysect = 0, sectors-1 do begin
  for xsect = 0, sectors-1 do begin
    xstart=xsect*step        ; define start/end of image subsectors
    xend=(xsect+1)*step-1
    ystart=ysect*step
    yend=(ysect+1)*step-1
    nximg = dbzimg[xstart:xend,ystart:yend,nxin]  ; cut out a sector subset image
    primg = dbzimg[xstart:xend,ystart:yend,prin]
    idx=xsect+ysect*sectors
    xp[idx]=xstart+step/2  ; set control points in middle of image sectors,
    yp[idx]=ystart+step/2  ; but relative to full image coordinates
;    print, size(nximg)
;    print, size(primg)
;    print, xsect*step, (xsect+1)*step-1, ysect*step, (ysect+1)*step-1
    correl_optimize, primg, nximg, xoff, yoff
;    print, "ysect,xsect = ",ysect*sectors+xsect,"   XOFF = ",xoff,"   YOFF = ", yoff
    dbzimgsec[*,*,xsect*2+ysect*sectors*2] = primg
    dbzimgsec[*,*,xsect*2+1+ysect*sectors*2] = nximg
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

;pairimg=bytarr(300,300,4)
pairimg=bytarr(75,75,4)
pairimg[*,*,0:1] = dbzimg[*,*,prin:nxin]
pairimg[*,*,3] = dbzimg[*,*,prin]
;pairimg[*,*,4] = dbzimg[*,*,prin]
;POLYWARP, xn,yn,xp,yp,1,p,q
;nximgwarp = POLY_2D(pairimg[*,*,1],p,q,0,300,300)
;nximgwarp = warp_tri(xp,yp,xn,yn,pairimg[*,*,1],OUTPUT_SIZE=[300,300],/EXTRAPOLATE)
nximgwarp = warp_tri(xp,yp,xn,yn,pairimg[*,*,1],OUTPUT_SIZE=[75,75],/EXTRAPOLATE,/QUINTIC)
;pairimg[*,*,3] = nximgwarp
nximgwarp2 = warp_tri(xp,yp,xn,yn,pairimg[*,*,1],OUTPUT_SIZE=[75,75],/EXTRAPOLATE,/TPS)
pairimg[*,*,2] = nximgwarp2

   dbzcor2diff = float(pairimg[*,*,0])
   dbznex2diff = float(nximgwarp2)
   idxpos1 = where(dbzcor2diff ge 18.0, countpos1)
   if (countpos1 gt 0) then begin
      dbzpr1 = dbzcor2diff[idxpos1]
      dbznx1 = dbznex2diff[idxpos1]
      idxpos2 = where(dbznx1 gt 18.0, countpos2)
      if (countpos2 gt 0) then begin
         dbzpr2 = dbzpr1[idxpos2]
         dbznx2 = dbznx1[idxpos2]
         meandiff = mean(dbzpr2-dbznx2)
         print, '' & print, 'Post-alignment bias:
         print, 'LEVEL: ', height,'  MEAN PR-NEXRAD DIFFERENCE:  ', meandiff
      endif
   endif

bigpairimg = REBIN(pairimg,300,300,4,/SAMPLE)

device, decomposed = 0
LOADCT, 33

base = widget_base(title = 'Animation Widget')
animate = CW_ANIMATE(base, 300,300,4, /TRACK)
widget_control, /realize, base
for lev = 0,3 do CW_ANIMATE_LOAD, animate, FRAME=lev, IMAGE=bigpairimg[*,*,lev]*4
CW_ANIMATE_GETP, animate, pixmap_vect
CW_ANIMATE_RUN, animate, 5

base2 = widget_base(title = 'Animation Widget2')
animate2 = CW_ANIMATE(base2, 300,300,4, /TRACK)
widget_control, /realize, base2
for lev = 0,3 do CW_ANIMATE_LOAD, animate2, FRAME=lev, IMAGE=bigpairimg[*,*,lev]*3
CW_ANIMATE_GETP, animate2, pixmap_vect2
CW_ANIMATE_RUN, animate2, 5

XMANAGER, 'CW_ANIMATE Demo', base, EVENT_HANDLER = 'ANIMAT_EHANDLER'
XMANAGER, 'CW_ANIMATE Demo2', base2, EVENT_HANDLER = 'ANIMAT_EHANDLER' 

ncfilepr = dialog_pickfile(path=pathpr)
endwhile

errorExit:
end
