;+
; Copyright © 2013, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; hdf_to_nc_2a23.pro -- Conversion function to read selected data fields from
;   a PR 2A-23 HDF file, and write the selected fields to a new netCDF file.
;   Handles finding, safe copy, and decompression of the 2a23 HDF file.
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

FUNCTION hdf_to_nc_2a23, hdfile, ncfile, GEOL=do_geolocation, $
                         RAINTYPE=do_rainType, RAINFLAG=do_rainFlag, $
                         STATUSFLAG=do_statusFlag, BBHEIGHT=do_BBheight, $
                         BBstatus=do_BBstatus, VERBOSE=do_verbose

common sample, start_sample, sample_range, num_range, RAYSPERSCAN

; "Include" files for constants, names, paths, etc.
@pr_params.inc  ; for the type-specific fill values, RAYSPERSCAN, NUM_RANGE_2A25

; sanity-check the keyword parameters: if none set, then why were we called?
n2do = KEYWORD_SET(do_geolocation) + KEYWORD_SET(do_rainFlag) + $
       KEYWORD_SET(do_rainType) + KEYWORD_SET(do_statusFlag) + $
       KEYWORD_SET(do_BBheight) + KEYWORD_SET(do_BBstatus)

;print, 'n2do: ', n2do
IF n2do EQ 0 THEN message, "No HDF variables specified for copy to netCDF!"

parsed = STRSPLIT( FILE_BASENAME(hdfile), '.', /extract )
yymmdd = parsed[1]
orbit = parsed[2]
PR_vers = FIX(parsed[3])

; Read 2a23 elements and (shared) geolocation

; Check status of hdfile before proceeding -  check if compressed (.Z, .gz,)
; or not.  We start with filename as listed in database, not actual file
; name on disk which may differ if file has been uncompressed already.
;
   readstatus = 0

   havefile = find_alt_filename( hdfile, found2a23 )
   if ( havefile ) then begin
;     Get an uncompressed copy of the found file
      cpstatus = uncomp_file( found2a23, file23_2do )
      if(cpstatus eq 'OK') then begin
;
;        reinitialize the common variables
;
         SAMPLE_RANGE=0
         START_SAMPLE=0
         num_range = NUM_RANGE_2A25
;
;        Read 2a23 fields from HDF file
;
;        Initialize variables for 2a23 use
;
         IF KEYWORD_SET( do_geolocation ) THEN $
            geolocation=fltarr(2,RAYSPERSCAN,sample_range>1)
         IF KEYWORD_SET( do_rainFlag ) THEN $
            rainFlag=intarr(sample_range>1,RAYSPERSCAN)
         IF KEYWORD_SET( do_rainType ) THEN $
            rainType=intarr(sample_range>1,RAYSPERSCAN)
         IF KEYWORD_SET( do_statusFlag ) THEN $
            statusFlag=INTARR(sample_range>1,RAYSPERSCAN)
         IF KEYWORD_SET( do_BBheight ) THEN $
            BBheight=INTARR(sample_range>1,RAYSPERSCAN)
         IF KEYWORD_SET( do_BBstatus ) THEN $
            BBstatus=INTARR(sample_range>1,RAYSPERSCAN)

         status = read_2a23_ppi( file23_2do, GEOL=geolocation, $
                                 RAINTYPE=rainType, RAINFLAG=rainFlag, $
                                 STATUSFLAG=statusFlag, BBHEIGHT=BBheight, $
                                 BBstatus=BBstatus, VERBOSE=verbose )

         IF status NE 'OK' THEN BEGIN
            message, "Error from read_2a23_ppi, status = "+STRING(status), /info
            readstatus = 1
         ENDIF
;        Delete the temporary file copy
         IF verbose THEN print, "Remove 2a23 file copy:"
         command = 'rm -fv ' + file23_2do
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
   ncdf_attput, cdfid, 'HDF_2A23_file', FILE_BASENAME(hdFile), /global

   ; field dimensions
   raydimid = ncdf_dimdef(cdfid, 'raydim', RAYSPERSCAN)  ; # of PR rays in scans
   scandimid = ncdf_dimdef(cdfid, 'scandim', sample_range)
   lldimid = ncdf_dimdef(cdfid, 'lldim', 2)    ; 3rd dim. for geolocation

   IF KEYWORD_SET( do_geolocation ) THEN BEGIN
      geovarid = ncdf_vardef(cdfid, 'geolocation', [lldimid,raydimid,scandimid])
      ncdf_attput, cdfid, geovarid, 'long_name', 'Latitude/Longitude of data sample'
      ncdf_attput, cdfid, geovarid, 'units', 'degrees North/East'
      ncdf_attput, cdfid, geovarid, '_FillValue', FLOAT_RANGE_EDGE
   ENDIF
   IF KEYWORD_SET( do_rainFlag ) THEN BEGIN
      rainflagvarid = ncdf_vardef(cdfid, 'rainFlag', [scandimid,raydimid], /short)
      ncdf_attput, cdfid, rainflagvarid, 'long_name', '2A-23 Rain Flag (bitmap)'
      ncdf_attput, cdfid, rainflagvarid, 'units', 'Categorical'
      ncdf_attput, cdfid, rainflagvarid, '_FillValue', INT_RANGE_EDGE
   ENDIF
   IF KEYWORD_SET( do_rainType ) THEN BEGIN
      raintypevarid = ncdf_vardef(cdfid, 'rainType', [scandimid,raydimid], /short)
      ncdf_attput, cdfid, raintypevarid, 'long_name', $
                  '2A-23 Rain Type (stratiform/convective/other)'
      ncdf_attput, cdfid, raintypevarid, 'units', 'Categorical'
      ncdf_attput, cdfid, raintypevarid, '_FillValue', INT_RANGE_EDGE
   ENDIF
   IF KEYWORD_SET( do_statusFlag ) THEN BEGIN
      statusFlagvarid = ncdf_vardef(cdfid, 'status', [scandimid,raydimid], /short)
      ncdf_attput, cdfid, statusFlagvarid, 'long_name', $
                  '2A-23 Status Flag'
      ncdf_attput, cdfid, statusFlagvarid, '_FillValue', INT_RANGE_EDGE
   ENDIF
   IF KEYWORD_SET( do_BBheight ) THEN BEGIN
      BBHvarid = ncdf_vardef(cdfid, 'HBB', [scandimid,raydimid], /short)
      ncdf_attput, cdfid, BBHvarid, 'long_name', $
                  '2A-23 BB height'
      ncdf_attput, cdfid, BBHvarid, 'units', 'm'
      ncdf_attput, cdfid, BBHvarid, '_FillValue', INT_RANGE_EDGE
   ENDIF
   IF KEYWORD_SET( do_BBstatus ) THEN BEGIN
      BBSvarid = ncdf_vardef(cdfid, 'BBstatus', [scandimid,raydimid], /short)
      ncdf_attput, cdfid, BBSvarid, 'long_name', $
                  '2A-23 BB status'
      ncdf_attput, cdfid, BBSvarid, '_FillValue', INT_RANGE_EDGE
   ENDIF

   ncdf_control, cdfid, /endef

   IF KEYWORD_SET( do_geolocation ) THEN $
      NCDF_VARPUT, cdfid, 'geolocation', geolocation
   IF KEYWORD_SET( do_rainFlag ) THEN $
      NCDF_VARPUT, cdfid, 'rainFlag', rainFlag
   IF KEYWORD_SET( do_rainType ) THEN $
      NCDF_VARPUT, cdfid, 'rainType', rainType
   IF KEYWORD_SET( do_statusFlag ) THEN $
      NCDF_VARPUT, cdfid, 'status', statusFlag
   IF KEYWORD_SET( do_BBheight ) THEN $
      NCDF_VARPUT, cdfid, 'HBB', BBheight
   IF KEYWORD_SET( do_BBstatus ) THEN $
      NCDF_VARPUT, cdfid, 'BBstatus', BBstatus

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
