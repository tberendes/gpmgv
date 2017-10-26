;+
; Copyright © 2013, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; hdf_to_nc_2b31.pro -- Conversion function to read selected data fields from
;   a PR 2B-31 HDF file, and write the selected fields to a new netCDF file.
;   Handles finding, safe copy, and decompression of the 2B31 HDF file.
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

FUNCTION hdf_to_nc_2b31, hdfile, ncfile, SURFACE_RAIN_2B31=do_surfRain_2b31,   $
                         SCAN_TIME=do_scan_time, FRACTIONAL=do_frac_orbit_num, $
                         VERBOSE=do_verbose

common sample, start_sample, sample_range, num_range, RAYSPERSCAN

; "Include" files for constants, names, paths, etc.
@pr_params.inc  ; for the type-specific fill values, RAYSPERSCAN, NUM_RANGE_2A25

; sanity-check the keyword parameters: if none set, then why were we called?
n2do = KEYWORD_SET(do_surfRain_2b31) + KEYWORD_SET(do_scan_time) + $
       KEYWORD_SET(do_frac_orbit_num)

;print, 'n2do: ', n2do
IF n2do EQ 0 THEN message, "No HDF variables specified for copy to netCDF!"

parsed = STRSPLIT( FILE_BASENAME(hdfile), '.', /extract )
yymmdd = parsed[1]
orbit = parsed[2]
PR_vers = FIX(parsed[3])

; Read 2b31 elements and (shared) geolocation

; Check status of hdfile before proceeding -  check if compressed (.Z, .gz,)
; or not.  We start with filename as listed in database, not actual file
; name on disk which may differ if file has been uncompressed already.
;
   readstatus = 0

   havefile = find_alt_filename( hdfile, found2b31 )
   if ( havefile ) then begin
;     Get an uncompressed copy of the found file
      cpstatus = uncomp_file( found2b31, file31_2do )
      if(cpstatus eq 'OK') then begin
;
;        reinitialize the common variables
;
         SAMPLE_RANGE=0
         START_SAMPLE=0
         num_range = NUM_RANGE_2A25
;
;        Read 2b31 fields from HDF file
;
;        Initialize variables for 2B31 use
;
         IF KEYWORD_SET( do_surfRain_2b31 ) THEN $
            surfRain_2b31=fltarr(sample_range>1,RAYSPERSCAN)
         IF KEYWORD_SET( do_scan_time ) THEN $
            scan_time=DBLARR(sample_range>1)
         IF KEYWORD_SET( do_frac_orbit_num ) THEN $
            frac_orbit_num=FLTARR(sample_range>1)

         status = read_2b31_file( file31_2do, SURFACE_RAIN_2B31=surfRain_2b31, $
                                  SCAN_TIME=scan_time,                         $
				  FRACTIONAL=frac_orbit_num, VERBOSE=verbose )

         IF status NE 'OK' THEN BEGIN
            message, "Error from read_2b31_file(), status =  "+STRING(status), /info
            readstatus = 1
         ENDIF
;        Delete the temporary file copy
         IF verbose THEN print, "Remove 2B31 file copy:"
         command = 'rm -fv ' + file31_2do
         spawn, command, results
         print, results
      endif else begin
         message, "Error from uncomp_file(), cpstatus: "+cpstatus, /info
         readstatus = 1
      endelse
   endif else begin
      message, "Cannot find regular/compressed file "+hdfile, /info
      readstatus = 1
   endelse

   IF readstatus EQ 1 THEN return, 0

   ; Create the output dir for the netCDF file, if needed:
   OUTDIR = FILE_DIRNAME(ncfile)
   spawn, 'mkdir -p ' + OUTDIR

   cdfid = ncdf_create(ncfile, /CLOBBER)

   ; global variables -- THE FIRST GLOBAL VARIABLE MUST BE 'TRMM_Version'
   ncdf_attput, cdfid, 'TRMM_Version', PR_vers, /short, /global
   ncdf_attput, cdfid, 'HDF_2B31_file', FILE_BASENAME(hdFile), /global

   ; field dimensions
   raydimid = ncdf_dimdef(cdfid, 'raydim', RAYSPERSCAN)  ; # of PR rays in scans
   scandimid = ncdf_dimdef(cdfid, 'scandim', sample_range)
   gatedimid = ncdf_dimdef(cdfid, 'gatedim', num_range)
;   lldimid = ncdf_dimdef(cdfid, 'lldim', 2)    ; 3rd dim. for geolocation

   IF KEYWORD_SET( do_surfRain_2b31 ) THEN BEGIN
      sfrainvarid = ncdf_vardef(cdfid, 'rrSurf', [scandimid,raydimid])
      ncdf_attput, cdfid, sfrainvarid, 'long_name', $
                   '2B-31 Near-Surface Estimated Rain Rate'
      ncdf_attput, cdfid, sfrainvarid, 'units', 'mm/h'
      ncdf_attput, cdfid, sfrainvarid, '_FillValue', FLOAT_RANGE_EDGE
   ENDIF
;   IF KEYWORD_SET( do_geolocation ) THEN BEGIN
;      geovarid = ncdf_vardef(cdfid, 'geolocation', [lldimid,raydimid,scandimid])
;      ncdf_attput, cdfid, geovarid, 'long_name', 'Latitude/Longitude of data sample'
;      ncdf_attput, cdfid, geovarid, 'units', 'degrees North/East'
;      ncdf_attput, cdfid, geovarid, '_FillValue', FLOAT_RANGE_EDGE
;  ENDIF
   IF KEYWORD_SET( do_scan_time ) THEN BEGIN
      scanTimevarid = ncdf_vardef(cdfid, 'scanTime_sec', [scandimid], /double)
      ncdf_attput, cdfid, scanTimevarid, 'long_name', $
                  '2B-31 Scan Time seconds'
      ncdf_attput, cdfid, scanTimevarid, 'units', 'seconds'
      ncdf_attput, cdfid, scanTimevarid, '_FillValue', DOUBLE(FLOAT_RANGE_EDGE)
   ENDIF
   IF KEYWORD_SET( do_frac_orbit_num ) THEN BEGIN
      ; documentation says this is 4-byte float, HDF read returns 8-byte,
      ; store as 4-byte to save space
      fracvarid = ncdf_vardef(cdfid, 'FractionalGranuleNumber', [scandimid])
      ncdf_attput, cdfid, fracvarid, 'long_name', $
                  '2B-31 Fractional Granule Number'
      ncdf_attput, cdfid, fracvarid, '_FillValue', FLOAT_RANGE_EDGE
   ENDIF

   ncdf_control, cdfid, /endef

   IF KEYWORD_SET( do_surfRain_2b31 ) THEN $
      NCDF_VARPUT, cdfid, 'rrSurf', surfRain_2b31
;   IF KEYWORD_SET( do_geolocation ) THEN $
;      NCDF_VARPUT, cdfid, 'geolocation', geolocation
   IF KEYWORD_SET( do_scan_time ) THEN $
      NCDF_VARPUT, cdfid, 'scanTime_sec', scan_time
   IF KEYWORD_SET( do_frac_orbit_num ) THEN $
      NCDF_VARPUT, cdfid, 'FractionalGranuleNumber', frac_orbit_num

   ncdf_close, cdfid

  ; gzip the finished netCDF file
   PRINT
   PRINT, "Output netCDF file:"
   PRINT, ncfile
   PRINT, "is being compressed."
   PRINT
   command = "gzip -v " + ncfile
   spawn, command

return, 1
END
