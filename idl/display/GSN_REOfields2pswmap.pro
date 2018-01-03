;+
; Copyright © 2008, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; GSN_REOfields2pswmap.pro
;
; Produces reflectivity images with map overlays from REORDER netCDF
; grid files specific to the RGSN radar.  Output is either to the
; display, or to a postscript file.
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-

pro GSN_REOfields2pswmap

do_ps = 0   ; set to 1 if postcript desired

; Compute a radial distance array of 2-D netCDF grid dimensions
xdist = findgen(75,75)
xdist = ((xdist mod 75.) - 37.) * 4.
ydist = TRANSPOSE(xdist)
dist = SQRT(xdist*xdist + ydist*ydist)

; Set up for 100 km range ring burn-in to images
dist2 = dist
idxrr100 = where (dist le 100.)  ; set everything inside 100 km to 300
dist2[idxrr100] = 300.
idxrr100 = where( dist gt 104.)  ; set everything outside 104 km to 300
dist2[idxrr100] = 300.
idxrr100 = where ( dist2 lt 300. )  ; index of everything between >100 and 104 km

;pathpr='/data/netcdf/PR'
pathgv='/data/netcdf/NEXRAD_REO/allYMD'
;pathgv='/data/tmp/reorder'
ncfilegz = dialog_pickfile(path=pathgv, filter='*RGSN*')
while ncfilegz ne '' do begin
;ncfilegz = '/data/tmp/reorder/ddop.1070831.235032.cdf.gz'
dotgz = STRPOS( ncfilegz, ".gz" )
ncfile = STRMID( ncfilegz, 0, dotgz)
command1 = "gunzip " + ncfilegz
spawn, command1

ncid = NCDF_OPEN( ncfile )

siteID = ""
;NCDF_VARGET, ncid, 'site_ID', siteIDbyte
NCDF_VARGET, ncid, 'lat', siteLat
NCDF_VARGET, ncid, 'lon', siteLong
NCDF_VARGET, ncid, 'base_time', event_time
;siteID = string(siteIDbyte)
print, siteID, siteLat, siteLong, event_time

;NCDF_VARGET, ncid, 'UZ', dbzraw
     if (NCDF_VARID(ncid, 'CZ') ne -1) then begin
        NCDF_VARGET, ncid, 'CZ', dbzraw
     endif else begin
        if (NCDF_VARID(ncid, 'UZ') ne -1) then begin
           NCDF_VARGET, ncid, 'UZ', dbzraw
        endif else begin
           print, "ERROR from read_gv_netcdf, file = ", ncfile
	   print, "Neither CZ nor UZ reflectivity field found in netCDF file."
	   NCDF_CLOSE, ncid
	   command2 = "gzip " + ncfile
	   spawn, command2
	   goto, ErrorExit
        endelse
     endelse

;NCDF_VARGET, ncid, 'rainRate', rainRate
;NCDF_VARGET, ncid, 'convStratFlag', raintype
NCDF_CLOSE, ncid
command2 = "gzip " + ncfile
spawn, command2

; handle the -9999.0 values
;idxneg = where(dbzraw eq -9999.0, countnoz)
;if (countnoz gt 0) then dbzraw[idxneg] = 0.0
idxneg = where(dbzraw lt 18., countbelowmin)
if (countbelowmin gt 0) then dbzraw[idxneg] = 5.0

; set up for plots
; for REORDER, siteLat and siteLon are at the LL gridpoint!
; place the image/map boundaries at the outside of the 4km gridpoints
pi=3.14159
deglatperkm=1/111.1
deglonperkm=deglatperkm/cos(siteLat*(pi/180.))  ; at the bottom of the image
lathi = siteLat + 298 * deglatperkm
latlo = siteLat - 2 * deglatperkm
latmid = siteLat + 148 * deglatperkm
lonlo = siteLong - 2 * deglonperkm
lonmid = siteLong + 148 * deglonperkm
deglonperkm=deglatperkm/cos(lathi*(pi/180.))  ; at the top of the image
lonhi = lonmid + 150 * deglonperkm

orig_device = !d.name
if (do_ps eq 1) then begin
;  Generate a ps file name based on the input file name, replacing '.nc' w.
;  '.dbzraw.ps', and setting path to /data/tmp
  ncpos = STRPOS( FILE_BASENAME( ncfile ), ".cdf" )
  ps_fname = "/data/tmp/"+STRMID( FILE_BASENAME( ncfile ), 0, ncpos ) $
  +".dbzraw.ps"
  print, ps_fname
  set_plot, 'ps'
endif else begin
  Window, xsize=500, ysize=500, XPOS = 400, YPOS = 100, TITLE=file_basename(ncfile) + ' Reflectivity'
  device, decomposed = 0, retain = 1
endelse
LOADCT, 33
;tvlct, 255b,255b,255b,230
tvlct,0b,0b,0b,230
tvlct,150b,150b,150b,0
if (do_ps eq 1) then device, /portrait, filename=ps_fname, /color, BITS=8
;map_set, 32.5367, -85.7897, /azimuthal, limit=[31.19, -87.39, 33.89,-84.19], /isotropic
map_set, LatMid, LonMid, /azimuthal, limit=[latlo, lonlo, lathi, lonhi], /isotropic
     imgtemp = dbzraw[*,*,0]*4.0          ; copy image array
     imgtemp[idxrr100] = 255.             ; burn in 100km range ring

image = map_image(imgtemp,x0,y0,xsize,ysize,latmin=latlo,lonmin=lonlo,$
latmax=lathi,lonmax=lonhi,compress=1)
tvscl,image,x0,y0,xsize=xsize,ysize=ysize,top=200
map_grid, color=230, label = 1, thick = 3
map_continents, /hires, /coasts, color=230, thick = 3

if (do_ps eq 1) then erase
;   set_plot, 'X'
;   device, decomposed = 0, retain = 1
;endif

if (do_ps eq 1) then device, /close_file
set_plot, orig_device

ncfilegz = dialog_pickfile(path=pathgv, filter='*RGSN*')
endwhile
;stop
if (do_ps ne 1) then WDELETE, 0
;WDELETE, 1,2

print, 'Done!'
errorExit:
end
