;+
; Copyright © 2008, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; GVfields2pswmap3x1.pro
;
; Displays mapped images of GV netCDF grid data fields: reflectivity,
; rain rate, and rain type, from the 2A-5x based GV data.  Output is
; either to the display, or to a postscript file.
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-

pro GVfields2pswmap3x1

do_ps = 0   ; set to 1 if postcript desired

pathpr='/data/netcdf/PR'
pathgv='/data/netcdf/NEXRAD'
ncfilegz = dialog_pickfile(path=pathgv)
while ncfilegz ne '' do begin
;ncfilegz = '/data/netcdf/PR/PRgrids.KJAX.060831.50097.nc.gz'
dotgz = STRPOS( ncfilegz, ".gz" )
ncfile = STRMID( ncfilegz, 0, dotgz)
command1 = "gunzip " + ncfilegz
spawn, command1

ncid = NCDF_OPEN( ncfile )

siteID = ""
NCDF_VARGET, ncid, 'site_ID', siteIDbyte
NCDF_VARGET, ncid, 'site_lat', siteLat
NCDF_VARGET, ncid, 'site_lon', siteLong
NCDF_VARGET, ncid, 'beginTimeOfVolumeScan', event_time
siteID = string(siteIDbyte)
print, siteID, siteLat, siteLong, event_time

NCDF_VARGET, ncid, 'threeDreflect', dbzraw
NCDF_VARGET, ncid, 'rainRate', rainRate
NCDF_VARGET, ncid, 'convStratFlag', raintype
NCDF_CLOSE, ncid
command2 = "gzip " + ncfile
spawn, command2

; handle the -9999.0 values
idxneg = where(dbzraw eq -9999.0, countnoz)
if (countnoz gt 0) then dbzraw[idxneg] = 0.0
idxneg = where(dbzraw lt -1, countbelowmin)
if (countbelowmin gt 0) then dbzraw[idxneg] = 5.0

; handle the 157 values in raintype
idx157 = WHERE( raintype gt 2, count157)
if (count157 gt 0) then raintype[idx157] = 3
raintype= raintype*50

; handle the negative values in rainrate
idxnegrr = where(rainrate lt 0.0, countnorr)
if (countnorr gt 0) then rainrate[idxnegrr] = 0.0

; set up for plots
pi=3.14159
deglatperkm=1/111.1
deglonperkm=deglatperkm/cos(siteLat*(pi/180.))
lathi = siteLat + 150 * deglatperkm
latlo = siteLat - 150 * deglatperkm
lonhi = siteLong + 150 * deglonperkm
lonlo = siteLong - 150 * deglonperkm

orig_device = !d.name
if (do_ps eq 1) then begin
;  Generate a ps file name based on the input file name, replacing '.nc' w.
;  '.dbzraw.ps', and setting path to /data/tmp
  ncpos = STRPOS( FILE_BASENAME( ncfile ), ".nc" )
  ps_fname = "/data/tmp/"+STRMID( FILE_BASENAME( ncfile ), 0, ncpos ) $
  +".dbzraw.ps"
  print, ps_fname
  set_plot, 'ps'
endif else begin
  Window, xsize=1500, ysize=500, XPOS = 0, YPOS = 0, TITLE=file_basename(ncfile) + ' Reflectivity'
  device, decomposed = 0, retain = 1
endelse
LOADCT, 33
;tvlct, 255b,255b,255b,230
tvlct,0b,0b,0b,230
tvlct,150b,150b,150b,0

!P.MULTI=[1,3,1]

if (do_ps eq 1) then device, /portrait, filename=ps_fname, /color, BITS=8
;map_set, 32.5367, -85.7897, /azimuthal, limit=[31.19, -87.39, 33.89,-84.19], /isotropic
map_set, siteLat, siteLong, /azimuthal, limit=[latlo, lonlo, lathi, lonhi], /isotropic
image = map_image(dbzraw[*,*,3],x0,y0,xsize,ysize,latmin=latlo,lonmin=lonlo,$
latmax=lathi,lonmax=lonhi,compress=1)
tvscl,image,x0,y0,xsize=xsize,ysize=ysize,top=200
map_grid, color=230, label = 1, thick = 3
map_continents, /hires, /usa, color=230, thick = 3

if (do_ps eq 1) then erase
;   set_plot, 'X'
;   device, decomposed = 0, retain = 1
;endif
if (do_ps ne 1) then begin

!P.MULTI=[2,3,1]

endif
;Window, 1, xsize=500, ysize=500, XPOS = 600, YPOS = 0, TITLE = '2A-54 Rain Type'
image = map_image(raintype,x0,y0,xsize,ysize,latmin=latlo,lonmin=lonlo,$
latmax=lathi,lonmax=lonhi,compress=1)
tvscl,image,x0,y0,xsize=xsize,ysize=ysize,top=200
map_grid, color=230, label = 1, thick = 2
map_continents, /hires, /usa, color=230, thick = 2
if (do_ps eq 1) then erase

if (do_ps ne 1) then begin ;Window, 2, xsize=500, ysize=500, XPOS = 1200, YPOS = 0, TITLE = '2A-53 Rain Rate'

!P.MULTI=[3,3,1]

endif
image = map_image(rainrate,x0,y0,xsize,ysize,latmin=latlo,lonmin=lonlo,$
latmax=lathi,lonmax=lonhi,compress=1)
tvscl,image,x0,y0,xsize=xsize,ysize=ysize,top=200
map_grid, color=230, label = 1, thick = 2
map_continents, /hires, /usa, color=230, thick = 2

if (do_ps eq 1) then device, /close_file
set_plot, orig_device

ncfilegz = dialog_pickfile(path=pathgv)
endwhile

if (do_ps ne 1) then WDELETE, 0 ;, 1, 2
;WDELETE, 1,2

print, 'Done!'
end
