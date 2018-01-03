;+
; Copyright © 2008, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
;------------------------------------------------------------------------------
; Procedure to remove path from file name
; Taken from OrbitViewer by Owen Kelley
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-       
   pro remove_path, file, file_no_path
;------------------------------------
;
;------------------------------------
        file_no_path    = file

        while( strpos( file_no_path , '/' ) ne -1 ) do $
          file_no_path = strmid( file_no_path , $
            strpos( file_no_path , '/' ) + 1, 1000 )

   end
