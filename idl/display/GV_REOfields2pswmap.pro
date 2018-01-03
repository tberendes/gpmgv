;+
; Copyright © 2008, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; GV_REOfields2pswmap.pro
;
; Produces reflectivity images with map overlays from REORDER netCDF
; grid files.  Output is either to the display, or to a postscript file.
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-

pro GV_REOfields2pswmap

do_ps = 0   ; set to 1 if postcript desired

;pathpr='/data/netcdf/PR'
pathgv='/data/netcdf/NEXRAD_REO/allYMD'
;pathgv='/data/tmp/reorder'
ncfilegz = dialog_pickfile(path=pathgv)
while ncfilegz ne '' do begin
;ncfilegz = '/data/netcdf/PR/PRgrids.KJAX.060831.50097.nc.gz'
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
idxneg = where(dbzraw eq -9999.0, countnoz)
if (countnoz gt 0) then dbzraw[idxneg] = 0.0
idxneg = where(dbzraw lt -1, countbelowmin)
if (countbelowmin gt 0) then dbzraw[idxneg] = 5.0

; set up for plots
pi=3.14159
deglatperkm=1/111.1
deglonperkm=deglatperkm/cos(siteLat*(pi/180.))
lathi = siteLat + 300 * deglatperkm
latlo = siteLat
lonhi = siteLong + 300 * deglonperkm
lonlo = siteLong

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
  Window, xsize=500, ysize=500, XPOS = 0, YPOS = 0, TITLE=file_basename(ncfile) + ' Reflectivity'
  device, decomposed = 0, retain = 1
endelse
LOADCT, 33
;tvlct, 255b,255b,255b,230
tvlct,0b,0b,0b,230
tvlct,150b,150b,150b,0
if (do_ps eq 1) then device, /portrait, filename=ps_fname, /color, BITS=8
;map_set, 32.5367, -85.7897, /azimuthal, limit=[31.19, -87.39, 33.89,-84.19], /isotropic
map_set, siteLat, siteLong, /azimuthal, limit=[latlo, lonlo, lathi, lonhi], /isotropic
image = map_image(dbzraw[*,*,0],x0,y0,xsize,ysize,latmin=latlo,lonmin=lonlo,$
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

ncfilegz = dialog_pickfile(path=pathgv)
endwhile

if (do_ps ne 1) then WDELETE, 0
;WDELETE, 1,2

print, 'Done!'
errorExit:
end
