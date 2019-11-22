;+
; Copyright © 2008, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; DESCRIPTION
;       Reads 3-D reflectivity grids from a 2A-55 GV radar file, resamples the
;       2 km resolution grid to 4 km, and writes the 4km grid to the supplied
;       GV netCDF file.  Also computes textual and unix ticks version of the
;       radar volume scan time start, and writes these and the GV site ID and
;       lat/lon location to the netCDF file.
;
; AUTHOR:
;       Liang Liao
;       Caelum Research Corp.
;       Code 975, NASA/GSFC
;       Greenbelt, MD 20771
;       Phone: 301-614-5718
;       E-mail: lliao@priam.gsfc.nasa.gov
;
; HISTORY:
;       12/2006 by Bob Morris, GPM GV (SAIC)
;       - Heavily modified/renamed from Liang's access_2A55.pro.  Reduce grid
;         resolution to 4km and write results to netCDF file.  Compute/convert
;         NEXRAD volume scan time as unix ticks and write to netCDF file.
;       12/2009 by Bob Morris, GPM GV (SAIC)
;       - Modified parsing of file name to accommodate prefix prepended onto the
;         2A55 file copy.
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-

pro generate_2a55_ncgrids, file_2A55, ncgvfile

common groundSite, event_num, siteID, siteLong, siteLat
common time,       event_time, volscantime, orbit

; 'Include' file for grid dimensions, spacings
@grid_def.inc

; We need the following to prepare analyzed output for REBINing to NX x NY grid.
; Must have a grid whose dimensions are even multiples of NX and NY.
x_cut = (NX * REDUCFAC) - 1  ; upper x array index to extract from hi-res grid
                             ; prior to REBINning to NX x NY grid
y_cut = (NY * REDUCFAC) - 1  ; as for x_cut, but upper y array index


;
; Open the netcdf file for writing, and fill passed/common parameters
;
ncid = NCDF_OPEN( ncgvfile, /WRITE )
NCDF_VARPUT, ncid, 'site_ID', siteID
NCDF_VARPUT, ncid, 'site_lat', siteLat
NCDF_VARPUT, ncid, 'site_lon', siteLong

threeDreflect=intarr(151,151,13,20)  ; just define with any value and dimension 
;
; Read 2a55 three dimensional reflectivity (dBZ) and volume scan times
; and parse date information from input 2a55 file name
;
read_2a55, file_2a55, DBZ=threeDreflect, hour, minute, second, scalefacDBZ

; Unscale the reflectivity values, use float(scale_factor), don't want double
; precision result grid
threeDreflect=threeDreflect/FLOAT(scalefacDBZ)
;help, threeDreflect

; -- Averaging 2a55 to 4x4 km^2 for all levels - only one time in our 2A55 files
; -- Extract an even number of horizontal points (150) for REBINning to 75x75

; CURRENT GPM GV VALIDATION NETWORK 2A55 FILE IS LIMITED TO ONE VOLUME.
; OTHERWISE, WE WOULD HAVE TO WORK THRU THE VOLUME SCAN TIMES HERE TO FIND THE
; ONE COINCIDENT WITH THE PR OVERPASS TIME, WHICH WOULD HAVE TO BE PASSED INTO
; THIS ROUTINE. OTHER POSSIBILITIES ARE TO OBTAIN THE COINCIDENT VOLUME FROM
; THE 2A-52 PRODUCT, OR FROM MATCHING THE VOS TIME METADATA IN THE gpmgv
; DATABASE TO THE SITE OVERPASS TIME AND INCLUDING THE CORRESPONDING VOLUME
; NUMBER IN THE CONTROL FILE INFORMATION

nvol = 0

threeDreflect_new = threeDreflect[0:x_cut,0:y_cut,*,nvol]
threeDreflect_new = 10.^(0.1*threeDreflect_new)
threeDreflect_new = REBIN(threeDreflect_new, NX, NY, NZ)
threeDreflect_new = 10.*ALOG10(threeDreflect_new) 

NCDF_VARPUT, ncid, 'threeDreflect', threeDreflect_new  ; grid data
NCDF_VARPUT, ncid, 'have_threeDreflect', DATA_PRESENT  ; data presence flag

; -- get the yr (yy), mon, day of the volscan from the filename
file_only_2a55 =  file_basename(file_2a55)
len_file_only_2a55 = STRLEN(file_only_2a55)
startpos = strpos(file_only_2a55,'2A55.')+6
file_fields2get = STRMID(file_only_2a55,startpos,len_file_only_2a55-startpos)

void = ' '
site = ' '
year = ' '  
month = 0  & day = 0

reads, file_fields2get, year, month, day, site, $
       format='(i2,i2,i2,3x,a4)'

; -- get the hr, min, and sec fields of our volume scan = nvol
hrs = hour[nvol]
min = minute[nvol]
sec = second[nvol]

  if hrs ne -99 then begin
    dtimestring = fmtdatetime(year, month, day, hrs, min, sec)
    print, file_only_2a55,"|",dtimestring,"+00"
  endif else begin
    dtimestring = '1970-01-01 00:00:00'
    print, file_only_2a55,"|",dtimestring,"+00"
  endelse

dateparts = strsplit(dtimestring, '-', /extract)
yyyy = dateparts[0]
;print, "yr mo day hrs min sec: ", yyyy, month, day, hrs, min, sec

voltimeticks = unixtime(long(yyyy), long(month), long(day), hrs, min, sec)
volscantime = voltimeticks
;print, "UNIX time ticks at volscan begin = ", voltimeticks
NCDF_VARPUT, ncid, 'beginTimeOfVolumeScan', voltimeticks
NCDF_VARPUT, ncid, 'abeginTimeOfVolumeScan', dtimestring

NCDF_CLOSE, ncid

end

@read_2a55.pro
@unixtime.pro
