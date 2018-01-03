;+
; Copyright © 2008, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; DESCRIPTION
; Given a fully-qualified PR netCDF file name and a GV file name
; derived from it as a best-guess, determines whether the best guess
; file exists, and if not, whether a GV file with the same orbit
; number as the PR but a different datestamp or extension exists.
;
; RETURNS the status of the search:
;   'OK' if matching GV file is found, else 'FAILURE'
;    -- If a match is found, the filename is assigned to gvfile
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-

function gv_orbit_match, prfile, gvfile

gvfiles = file_search( gvfile, COUNT=nf )

if nf EQ 1 then begin
   ; lucky for us, the gv file exists
   status = 'OK'
endif else begin
   ; find other gv file for the same orbit as indicated in the pr filename
   prparts = strsplit( file_basename( prfile ), '.', /extract )
   orbit = prparts[3]
   gvpath = file_dirname( gvfile, /MARK_DIRECTORY )
   gvparts = strsplit( file_basename( gvfile ), '.', /extract )
   gvpattern = gvpath+gvparts[0]+"."+gvparts[1]+".*."+orbit+".*"
   gvfiles = file_search( gvpattern, COUNT=nf )

   if nf GE 1 then begin
      gvfile = gvfiles[0]
      status = 'OK'
      print, "In gv_orbit_match() for orbit = ", orbit, " found alternate GV file:"
      print, gvfile
      ;goto, REPORT
   endif else begin
      if nf EQ 0 then begin
         print, "In gv_orbit_match(), no "+gvparts[0]+"."+gvparts[1]+".*."+orbit+".* file(s) for orbit ", orbit
         status = 'FAILURE'
      endif
   endelse
endelse

return, status
END
