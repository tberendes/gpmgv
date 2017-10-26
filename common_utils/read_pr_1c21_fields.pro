;+
; Copyright © 2008, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; read_pr_1c21_fields.pro -- Wrapper function to read selected data fields
;   from PR 1C21 products.  Handles finding, safe copy, and decompression of
;   the 1C21 file.
;
; AUTHOR:
;       Bob Morris, SAIC
;
; MODIFIED:
;       Aug 2008 - Bob Morris, GPM GV (SAIC)
;       - Created.
;       Jan 2010 - Bob Morris, GPM GV (SAIC)
;       - Added RAY_SIZE, ANGLE, and START_DIST keyword variables to be read.
;       Jun 2010 - Bob Morris, GPM GV (SAIC)
;       - Added '-f' option to 'rm' command to eliminate unix prompts.
;       Feb 2013- Bob Morris, GPM GV (SAIC)
;       - Added VERBOSE option to pass along to read_1c21_ppi() to print
;         file SD variables.  Add overlooked GEOL parameter.
;         Re-ordered parameters to match order in read_1c21_ppi()
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-

FUNCTION read_pr_1c21_fields, file_1c21, DBZ=dbz_1c21, GEOL=geolocation, $
                              OCEANFLAG=landOceanFlag, BinS=binS, $
                              SCAN_TIME=scan_time, FRACTIONAL=frac_orbit_num, $
			      RAY_START=rayStart, RAY_SIZE=raySize, $
                              ANGLE=angle, START_DIST=startDist, $
                              VERBOSE=verbose

  common sample, start_sample, sample_range, num_range, RAYSPERSCAN

; Read 1c21 Normal Sample and Land-Ocean flag
;
; Check status of file_1c21 before proceeding -  actual file
; name on disk may differ if file has been uncompressed already.
;
   readstatus = 0

   havefile = find_alt_filename( file_1c21, found1c21 )
   if ( havefile ) then begin
;     Get an uncompressed copy of the found file
      cpstatus = uncomp_file( found1c21, file21_2do )
      if(cpstatus eq 'OK') then begin
;        Initialize variables for 1C21 use
         SAMPLE_RANGE=0
         START_SAMPLE=0
         END_SAMPLE=0
        ; num_range = NUM_RANGE_1C21
         dbz_1c21=fltarr(sample_range>1,1,num_range)
         landOceanFlag=intarr(sample_range>1,RAYSPERSCAN)
         binS=intarr(sample_range>1,RAYSPERSCAN)
         scan_time=DBLARR(sample_range>1)
	 frac_orbit_num=FLTARR(sample_range>1)
         rayStart=intarr(RAYSPERSCAN)

;        Read the uncompressed 1C21 file copy
         status=read_1c21_ppi( file21_2do, DBZ=dbz_1c21, GEOL=geolocation, $
                               OCEANFLAG=landOceanFlag, BinS=binS, $
		               SCAN_TIME=scan_time, RAY_START=rayStart, $
                               RAY_SIZE=raySize, ANGLE=angle, $
                               START_DIST=startDist, $
                               FRACTIONAL=frac_orbit_num, $
                               VERBOSE=verbose )
         IF status NE 'OK' THEN readstatus = 1

;        Delete the temporary file copy
         IF verbose THEN print, "Remove 1C21 file copy:"
         command = 'rm -fv ' + file21_2do
         spawn, command, results
         print, results
      endif else begin
         print, cpstatus
         readstatus = 1
      endelse
   endif else begin
      print, "Cannot find regular/compressed file " + file_1c21
      readstatus = 1
   endelse
   RETURN, readstatus
END
