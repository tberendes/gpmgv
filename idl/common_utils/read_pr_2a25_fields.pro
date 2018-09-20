;+
; Copyright © 2008, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; read_pr_2a25_fields.pro -- Wrapper function to read selected data fields
;   from PR 2A-25 products.  Handles finding, safe copy, and decompression of
;   the 2A25 file.
;
; AUTHOR:
;       Bob Morris, SAIC
;
; MODIFIED:
;       Aug 2008 - Bob Morris, GPM GV (SAIC)
;       - Created.
;       Mar 2009 - Bob Morris, GPM GV (SAIC)
;       - Added '-f' flag to unix 'rm' command to eliminate user prompts
;       Nov 2009 - Bob Morris, GPM GV (SAIC)
;       - Added PIA as a field to be read, per Bringi requirement
;       Mar 2012 - Bob Morris, GPM GV (SAIC)
;       - Added response to error status returned from read_2a25_ppi().
;       Feb 2013- Bob Morris, GPM GV (SAIC)
;       - Added VERBOSE option to pass along to read_2a25_ppi() to print
;         file SD variables.
;       March 2018 - Bob Morris, GPM GV (SAIC)
;       - Added ST_STRUCT parameter to return a structure of arrays containing
;         the individual scan_time components, as requested by David Marks.
;
; EMAIL QUESTIONS OR COMMENTS AT:
;       https://pmm.nasa.gov/contact
;-

FUNCTION read_pr_2a25_fields, file_2a25, DBZ=dbz_2a25, RAIN=rain_2a25,   $
                              TYPE=rainType, SURFACE_RAIN=surfRain_2a25, $
                              GEOL=geolocation, RANGE_BIN=rangeBinNums,  $
                              RN_FLAG=rainFlag, SCAN_TIME=scan_time,     $
                              FRACTIONAL=frac_orbit_num, PIA=pia,        $
                              ST_STRUCT=st_struct, VERBOSE=verbose

  common sample, start_sample, sample_range, num_range, RAYSPERSCAN

; Read 2a25 elements and (shared) geolocation

; Check status of file_2a25 before proceeding -  check if compressed (.Z, .gz,)
; or not.  We start with filename as listed in database, not actual file
; name on disk which may differ if file has been uncompressed already.
;
   readstatus = 0

   havefile = find_alt_filename( file_2a25, found2a25 )
   if ( havefile ) then begin
;     Get an uncompressed copy of the found file
      cpstatus = uncomp_file( found2a25, file25_2do )
      if(cpstatus eq 'OK') then begin
;
;        reinitialize the common variables
;
         SAMPLE_RANGE=0
         START_SAMPLE=0
        ; END_SAMPLE=0
        ; RAIN_MIN = 0.01
        ; RAIN_MAX = 60.
;
;        Read 2a25 Correct dBZ (and friends) from HDF file
;
;        Initialize variables for 2A25 use
;
        ; num_range = NUM_RANGE_2A25
         dbz_2a25=fltarr(sample_range>1,1,num_range)
         rain_2a25 = fltarr(sample_range>1,1,num_range)
         surfRain_2a25=fltarr(sample_range>1,RAYSPERSCAN)
         geolocation=fltarr(2,RAYSPERSCAN,sample_range>1)
         rangeBinNums=intarr(sample_range>1,RAYSPERSCAN,7)
         rainFlag=intarr(sample_range>1,RAYSPERSCAN)
         rainType=intarr(sample_range>1,RAYSPERSCAN)
         pia=FLTARR(3,RAYSPERSCAN,sample_range>1)
         scan_time=DBLARR(sample_range>1)
         st_struct = "scan_time structure"   ; just define anything
	 frac_orbit_num=FLTARR(sample_range>1)

         status = read_2a25_ppi( file25_2do, DBZ=dbz_2a25, RAIN=rain_2a25,       $
	                         TYPE=rainType, SURFACE_RAIN=surfRain_2a25,      $
                                 GEOL=geolocation, RANGE_BIN=rangeBinNums,       $
                                 RN_FLAG=rainFlag, PIA=pia, SCAN_TIME=scan_time, $
				 FRACTIONAL=frac_orbit_num,                      $
				 ST_STRUCT=st_struct, VERBOSE=verbose )

         IF status NE 'OK' THEN BEGIN
            print, "In read_pr_2a25_fields, error from read_2a25_ppi: ", status
            readstatus = 1
         ENDIF
;        Delete the temporary file copy
         IF verbose THEN print, "Remove 2A25 file copy:"
         command = 'rm -fv ' + file25_2do
         spawn, command, results
         print, results
      endif else begin
         print, "In read_pr_2a25_fields, cpstatus: ", cpstatus
         readstatus = 1
      endelse
   endif else begin
      print, "In read_pr_2a25_fields, cannot find regular/compressed file " + file_2a25
      readstatus = 1
   endelse
   RETURN, readstatus
END
