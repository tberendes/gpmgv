;===============================================================================;+
; Copyright © 2011, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; read_grib_via_netcdf.pro           Morris/SAIC/GPM_GV      April 2011
;
; DESCRIPTION
; -----------
; For a specified NAM Reanalysis GRIB2 grid file, copies the GRIB file to the
; /tmp directory, uncompresses it with a call to gunzip, and calls the NCAR
; Command Language (NCL) utility "ncl_convert2nc" to convert the file to netCDF
; format.  Reads caller-specified data and metadata from the netCDF grid file
; derived from the GRIB2 file.  Returns status value: 0 if successful read, 1 if; unsuccessful or internal errors or inconsistencies occur.
;
; PARAMETERS
; ----------
; gribfile             STRING, Full file pathname to NAMANL GRIB file (Input)
; ncfile               STRING, Full file pathname to netCDF grid file (Output)
;
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;===============================================================================

FUNCTION read_grib_via_netcdf, gribfile, ncfile, LAT=lat, LON=lon, SFCTEMP=sfctemp

    status = 0

new_base_file = '/tmp/' + FILE_BASENAME( gribfile )
;
;   copy the GRIB file to /tmp
;
command = 'cp ' + gribfile + ' ' + new_base_file
spawn,command,exit_status=status
if(status ne 0) then begin
    flag = 'Unable to copy file to /tmp: ' + gribfile
    return,flag
endif
;
; *** Now parse the file name to determine the suffix or type (.gz or .Z)
;
a = strsplit(new_base_file,'.',/extract)
suffix = a(n_elements(a)-1)
;
; *** Deal with file
;
if(suffix ne 'gz' and suffix ne 'Z') then begin ; File is NOT compressed?
    new_file = new_base_file
    ; check for compression: if compressed, 'gzip -l' output goes to result,
    ; else output goes to errout
    command = "gzip -l " + new_file
    spawn, command, result, errout
    if ( n_elements(errout) eq 2 ) then begin
       if ( strpos(errout[1],'not in gzip') ne -1 ) then begin
	  print, file +" is not compressed."
       endif else begin
	  flag = "Can't determine compression state of " + gribfile
	  return, flag
       endelse
    endif else begin
      ; add the file suffix indicated by gzip result and try to uncompress it
       if ( n_elements(result) eq 2 ) then begin
          a = strsplit(result[1],' ',/extract)
          if ( a[1] ne -1 ) then begin
             print, gribfile +" IS gzip compressed, but not named as such!"
             zip_file = new_file + '.gz'
	  endif else begin
	     print, gribfile +" IS unix compressed (.Z), but not named as such!"
             zip_file = new_file + '.Z'
	  endelse
	  command = 'mv -v ' + new_file + ' ' + zip_file
          spawn,command,exit_status=status
          command = 'gzip -fd ' + zip_file
          spawn,command,exit_status=status
          if(status ne 0) then begin
              flag = 'Error decompressing file: ' + gribfile
              return,flag
          endif
       endif else begin
          flag = 'Unknown error decompressing file: ' + gribfile
          return,flag
       endelse
	endelse
endif else begin
   ; File extension indicates compressed file, uncompress it and get new
   ; name minus the extension
    command = 'gzip -fd ' + new_base_file
    spawn,command,exit_status=status
    if(status ne 0) then begin
        flag = 'Error decompressing file: ' + gribfile
        return,flag
    endif
    new_file = strjoin(a(0:n_elements(a)-2),'.')
;    print,new_file
endelse

a = strsplit(new_file,'.',/extract)
suffix = a(n_elements(a)-1)
if ( suffix ne 'grb' ) then begin
   flag = "Uncompressed file " + new_file + " does not have the .grb extension."
   return,flag
endif

; get the expected netCDF file name to result from conversion, and attempt
; conversion using ncl_convert2nc utiltiy
ncfile = strjoin(a(0:n_elements(a)-2),'.')+'.nc'
command = 'ncl_convert2nc '+new_file
spawn,command,exit_status=status
if ( FILE_TEST( ncfile ) NE 1 ) THEN BEGIN
   flag = "Error converting "+new_file+" to netCDF."
   return,flag
endif

ncid1 = NCDF_OPEN( ncfile )
IF ( N_Elements(ncid1) EQ 0 ) THEN BEGIN
   print, "ERROR from read_grib_via_netcdf:"
   flag = "File "+ ncfile +" is not a valid netCDF file!"
   print, flag
   return,flag
ENDIF

NCDF_VARGET, ncid1, 'gridlat_218', lat
print, lat[1,1:10]
print, lat[1:10,1]
NCDF_VARGET, ncid1, 'gridlon_218', lon
print, lon[1,1:10]
print, lon[1:10,1]

flag = 'OK'
FILE_DELETE, ncfile
return, flag
end
