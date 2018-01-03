;+
; Copyright © 2008, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; read_pr_2b31_fields.pro -- Wrapper function to read selected data fields
;   from PR 2B-31 products.  Handles finding, safe copy, and decompression of
;   the 2B31 file.
;
; AUTHOR:
;       Bob Morris, SAIC
;
; MODIFIED:
;       Aug 2008 - Bob Morris, GPM GV (SAIC)
;       - Created.
;       Jun 2010 - Bob Morris, GPM GV (SAIC)
;       - Added '-f' option to 'rm' command to eliminate unix prompts.
;       Oct 2010 - Bob Morris, GPM GV (SAIC)
;       - Replaced call to load_2b31() with read_2b31_file(), which will handle
;         both v6 and v7 2B-31 file formats.
;       Feb 2013- Bob Morris, GPM GV (SAIC)
;       - Added VERBOSE option to pass along to read_2b31_file() to print
;         file SD variables.
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-

FUNCTION read_pr_2b31_fields, file_2b31, surfRain_2b31, SCAN_TIME=scan_time, $
                              FRACTIONAL=frac_orbit_num, VERBOSE=verbose

; Read 2B31 surface rain

      readstatus = 0

; Check status of file_2b31 before proceeding -  check if compressed 
; or not.  We start with filename as listed in database, not actual file
; name on disk which may differ if file has been uncompressed already.
;
      havefile2b31 = find_alt_filename( file_2b31, found2b31 )
      if ( havefile2b31 ) then begin
;        Get an uncompressed copy of the found file
         cpstatus = uncomp_file( found2b31, file31_2do )
         if (cpstatus eq 'OK') then begin

            status = read_2b31_file( file31_2do, SURFACE_RAIN_2B31=surfRain_2b31, $
                                     SCAN_TIME=scan_time, FRACTIONAL=frac_orbit_num, $
                                     VERBOSE=verbose )

;           Delete the temporary file copy
            IF verbose THEN print, "Remove 2b31 file copy:"
            command = 'rm -fv ' + file31_2do
            spawn, command, results
            print, results
         endif else begin
            print, cpstatus
            readstatus = 1
         endelse
      endif else begin
         print, "Cannot find regular/compressed file " + file_2b31
         readstatus = 1
     endelse
     RETURN, readstatus
END
