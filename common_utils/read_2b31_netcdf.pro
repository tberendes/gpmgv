;+
; Copyright © 2013, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; read_2b31_netcdf.pro
;
; DESCRIPTION
; -----------
; Reads selected data fields from a PR 2B-31 netCDF file previously created by
; subsetting a 2B-31 HDF file by variable.  Handles finding, safe copy, and
; decompression of the 2B31 netCDF file.
;
; AUTHOR:
;       Bob Morris, SAIC
;
; MODIFIED:
;       Mar 2013 - Bob Morris, GPM GV (SAIC)
;       - Created.
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-

function read_2b31_netcdf, infile, SURFACE_RAIN_2B31=surfRain_2b31, $
                           SCAN_TIME=scan_time, FRACTIONAL=frac_orbit_num, $
                           VERBOSE=verbose

verbose = KEYWORD_SET(verbose)

status = 0

; Check status of infile before proceeding -  check if compressed (.Z, .gz,)
; or not.  We start with filename as given, not actual file name on disk
; which may differ if file has been uncompressed already.  If we find the file,
; make a copy and uncompress it as needed.

havefile = find_alt_filename( infile, found2b31 )
if ( havefile ) then begin
; Get an uncompressed copy of the found file
   cpstatus = uncomp_file( found2b31, ncfile )
   if(cpstatus ne 'OK') then begin
      message, "File copy error, cpstatus: "+cpstatus, /info
      status = 1
      RETURN, status
   endif
endif else begin
   message, "Cannot find regular/compressed file "+infile, /info
   status = 1
   RETURN, status
endelse

ncid1 = NCDF_OPEN( ncfile )
IF ( N_Elements(ncid1) EQ 0 ) THEN BEGIN
   print, ''
   message, "File copy "+ncfile+" is not a valid netCDF file!", /info
   print, ''
   status = 1
   goto, ErrorExit
ENDIF

; determine the number of global attributes and check the name of the 2nd one
; to verify that we have the correct type of file
attstruc=ncdf_inquire(ncid1)
IF ( attstruc.ngatts GT 1 ) THEN BEGIN
   att2name = ncdf_attname(ncid1, 1, /global)
   IF ( att2name NE 'HDF_2B31_file' ) THEN BEGIN
      print, ''
      message, "File copy "+ncfile+" is not a 2B31 netCDF data file!", /info
      print, ''
      status = 1
      goto, ErrorExit2
   ENDIF
ENDIF ELSE BEGIN
   print, ''
   message, "File copy "+ncfile+" has too few global attributes!", /info
   print, ''
   status = 1
   goto, ErrorExit2
ENDELSE

; ----------------------

IF N_ELEMENTS(surfRain_2b31) GT 0 THEN BEGIN
   IF (NCDF_VARID(ncid1, 'rrSurf') NE -1) THEN $
     NCDF_VARGET, ncid1, 'rrSurf', surfRain_2b31 $
   ELSE message, "Variable nearSurfRain not in netCDF file.", /INFO 
              
ENDIF

; -----------------------

;IF N_ELEMENTS(geolocation) GT 0 THEN BEGIN
;   IF (NCDF_VARID(ncid1, 'geolocation') NE -1) THEN $
;      NCDF_VARGET, ncid1, 'geolocation', geolocation $
;   ELSE message, "Variable geolocation not in netCDF file.", /INFO
;ENDIF

; -----------------------

IF N_ELEMENTS(frac_orbit_num) GT 0 THEN BEGIN
; get the FractionalGranuleNumber data
   IF (NCDF_VARID(ncid1, 'FractionalGranuleNumber') NE -1) THEN $
      NCDF_VARGET, ncid1, 'FractionalGranuleNumber', frac_orbit_num $
   ELSE message, "Variable FractionalGranuleNumber not in netCDF file.", /INFO
ENDIF

; -----------------------

IF N_ELEMENTS(scan_time) GT 0 THEN BEGIN
; get the scanTime_sec data
   IF (NCDF_VARID(ncid1, 'scanTime_sec') NE -1) THEN $
      NCDF_VARGET, ncid1, 'scanTime_sec', scan_time $
   ELSE message, "Variable scanTime_sec not in netCDF file.", /INFO
ENDIF

; -----------------------

ErrorExit2:   ; jump here if successful opening netCDF file, but it's wrong type

NCDF_CLOSE, ncid1

ErrorExit:    ; jump here if unsuccessful opening netCDF file

;  Delete the temporary file copy
IF verbose THEN print, "Remove 2B31 netCDF file copy:"
command = 'rm -fv ' + ncfile
spawn, command, results
print, results

RETURN, status
END
