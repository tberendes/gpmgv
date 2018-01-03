FUNCTION get_rsl_radar, file_gvrad, radar

;=============================================================================
;+
; Copyright © 2008, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; get_rsl_radar.pro      Morris/SAIC/GPM_GV      August 2008
;
; DESCRIPTION
; -----------
; Retrieves a 'radar' structure of the TRMM Radar Software Library (RSL) from
; a caller-specified radar data file.  Handles finding, safe copy, and any
; required decompression of the data file.  Returns the RSL radar structure
; in the 'radar' parameter.
;
; HISTORY
; -------
; 8/21/07 - Morris/NASA/GSFC (SAIC), GPM GV:  Created.
;
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;=============================================================================

   havefile = find_alt_filename( file_gvrad, found_gvrad )
   if ( havefile ) then begin
;     Get an uncompressed copy of the found file
      cpstatus = uncomp_file( found_gvrad, file_2do )
      if ( cpstatus eq 'OK' ) then begin
         radar = rsl_anyformat_to_radar( file_2do, ERROR=readstatus )
;        Delete the temporary file copy
         print, "Remove 1CUF file copy:"
         command = 'rm ' + file_2do
         print, command
         spawn, command
      endif else begin
         print, cpstatus
         readstatus = 1
      endelse
   endif else begin
      print, "Cannot find regular/compressed file " + file_gvrad
      readstatus = 1
   endelse
   RETURN, readstatus
END
