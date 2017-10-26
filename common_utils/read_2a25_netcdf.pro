;+
; Copyright © 2013, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; read_2a25_netcdf.pro
;
; DESCRIPTION
; -----------
; Reads selected data fields from a PR 2A-25 netCDF file previously created by
; subsetting a 2A-25 HDF file by variable.  Handles finding, safe copy, and
; decompression of the 2A25 netCDF file.
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

function read_2a25_netcdf, infile, DBZ=correctZfactor, GEOL=geolocation,    $
                           RAIN=rainrate, SURFACE_RAIN=surfaceRain,         $
                           TYPE=rainType, RN_FLAG=rainFlag,                 $
                           SCAN_TIME=scan_time, FRACTIONAL=frac_orbit_num,  $
                           RANGE_BIN=rangeBinNums, PIA=pia, VERBOSE=verbose

verbose = KEYWORD_SET(verbose)

status = 0

; Check status of infile before proceeding -  check if compressed (.Z, .gz,)
; or not.  We start with filename as given, not actual file name on disk
; which may differ if file has been uncompressed already.  If we find the file,
; make a copy and uncompress it as needed.

havefile = find_alt_filename( infile, found2a25 )
if ( havefile ) then begin
; Get an uncompressed copy of the found file
   cpstatus = uncomp_file( found2a25, ncfile )
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
   IF ( att2name NE 'HDF_2A25_file' ) THEN BEGIN
      print, ''
      message, "File copy "+ncfile+" is not a 2A25 netCDF data file!", /info
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

IF N_ELEMENTS(correctZFactor) GT 0 THEN BEGIN
   IF (NCDF_VARID(ncid1, 'correctZFactor') NE -1) THEN $
      NCDF_VARGET, ncid1, 'correctZFactor', correctZfactor $
   ELSE message, "Variable correctZFactor not in netCDF file.", /INFO
ENDIF

; ---------------------- 

IF N_ELEMENTS(rainrate) GT 0 THEN BEGIN
   IF (NCDF_VARID(ncid1, 'rain') NE -1) THEN $
     NCDF_VARGET, ncid1, 'rain', rainrate $
   ELSE message, "Variable rain not in netCDF file.", /INFO          
ENDIF

; ----------------------

IF N_ELEMENTS(surfaceRain) GT 0 THEN BEGIN
   IF (NCDF_VARID(ncid1, 'nearSurfRain') NE -1) THEN $
     NCDF_VARGET, ncid1, 'nearSurfRain', surfaceRain $
   ELSE message, "Variable nearSurfRain not in netCDF file.", /INFO 
              
ENDIF

; -----------------------

IF N_ELEMENTS(rainType) GT 0 THEN BEGIN
   IF (NCDF_VARID(ncid1, 'rainType') NE -1) THEN $
     NCDF_VARGET, ncid1, 'rainType', rainType $
   ELSE message, "Variable rainType not in netCDF file.", /INFO
          
ENDIF

; ----------------------                

IF N_ELEMENTS(rangeBinNums) GT 0 THEN BEGIN
   IF (NCDF_VARID(ncid1, 'rangeBinNum') NE -1) THEN $
      NCDF_VARGET, ncid1, 'rangeBinNum', rangeBinNums  $
   ELSE message, "Variable rangeBinNum not in netCDF file.", /INFO 
                
ENDIF

; -----------------------
 
IF N_ELEMENTS(rainFlag) GT 0 THEN BEGIN
   IF (NCDF_VARID(ncid1, 'rainFlag') NE -1) THEN $
      NCDF_VARGET, ncid1, 'rainFlag', rainFlag $
   ELSE message, "Variable rainFlag not in netCDF file.", /INFO           
                
ENDIF

; -----------------------

IF N_ELEMENTS(geolocation) GT 0 THEN BEGIN
   IF (NCDF_VARID(ncid1, 'geolocation') NE -1) THEN $
      NCDF_VARGET, ncid1, 'geolocation', geolocation $
   ELSE message, "Variable geolocation not in netCDF file.", /INFO
ENDIF

; -----------------------

IF N_ELEMENTS(pia) GT 0 THEN BEGIN
   IF (NCDF_VARID(ncid1, 'pia') NE -1) THEN $
      NCDF_VARGET, ncid1, 'pia', pia $
   ELSE message, "Variable pia not in netCDF file.", /INFO
ENDIF

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
IF verbose THEN print, "Remove 2A25 netCDF file copy:"
command = 'rm -fv ' + ncfile
spawn, command, results
print, results

RETURN, status
END
