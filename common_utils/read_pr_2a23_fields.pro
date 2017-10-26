;+
; Copyright © 2010, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; read_pr_2a23_fields.pro -- Wrapper function to read selected data fields
;   from PR 2A-23 products.  Handles finding, safe copy, and decompression of
;   the 2A23 file.
;
; AUTHOR:
;       Bob Morris, SAIC
;
; MODIFIED:
;       Apr 2010 - Bob Morris, GPM GV (SAIC)
;       - Created.
;       Jun 2010 - Bob Morris, GPM GV (SAIC)
;       - Added '-f' option to 'rm' command to eliminate unix prompts.
;       Jan 2013- Bob Morris, GPM GV (SAIC)
;       - Added RainFlag and Bright Band Height as variables able to be read.
;       - Added VERBOSE option to pass along to read_2a23_ppi() to print
;         file SD variables.
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-

FUNCTION read_pr_2a23_fields, file_2a23, GEOL=geolocation, RAINTYPE=rainType, $
                              RAINFLAG=rainFlag, STATUSFLAG=statusFlag, $
                              BBHEIGHT=BBheight, BBstatus=bbstatus, $
                              VERBOSE=verbose


;file_2a23='/Users/krmorri1/2A23.090904.67242.6.sub-GPMGV1.hdf.gz'                
common sample, start_sample, sample_range, num_range, RAYSPERSCAN
@pr_params.inc
   status=''
; Check status of file_2a23 before proceeding -  actual file
; name on disk may differ if file has been uncompressed already.
;
   readstatus = 0

   havefile = find_alt_filename( file_2a23, found2a23 )
   if ( havefile ) then begin
;     Get an uncompressed copy of the found file
      cpstatus = uncomp_file( found2a23, file23_2do )
      if(cpstatus eq 'OK') then begin
         SAMPLE_RANGE=0
         START_SAMPLE=0
         num_range = NUM_RANGE_2A25
         geolocation=fltarr(2,RAYSPERSCAN,sample_range>1)
         rainType=intarr(sample_range>1,RAYSPERSCAN)
         rainFlag=bytarr(sample_range>1,RAYSPERSCAN)
         statusFlag=bytarr(sample_range>1,RAYSPERSCAN)
         BBheight=intarr(sample_range>1,RAYSPERSCAN)
         BBstatus=bytarr(sample_range>1,RAYSPERSCAN)

         status = read_2a23_ppi( file23_2do, GEOL=geolocation, $
                                 RAINTYPE=rainType, RAINFLAG=rainFlag, $
                                 STATUSFLAG=statusFlag, BBHEIGHT=BBheight, $
                                 BBSTATUS=BBstatus, VERBOSE=verbose )
         IF status NE 'OK' THEN readstatus = 1

;        Delete the temporary file copy
         IF verbose THEN print, "Remove 2A23 file copy:"
         command = 'rm -fv ' + file23_2do
         spawn, command, results
         print, results
      endif else begin
         print, cpstatus
         readstatus = 1
      endelse
   endif else begin
      print, "Cannot find regular/compressed file " + file_2a23
      readstatus = 1
   endelse
;   help
;   print, status, readstatus
   RETURN, readstatus
end
