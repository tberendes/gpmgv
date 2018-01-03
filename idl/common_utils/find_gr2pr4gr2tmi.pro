;+
; Copyright © 2012, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; find_gr2pr4gr2tmi.pro 
; - Morris/SAIC/GPM_GV   September 2012
;
; DESCRIPTION
; -----------
; Given the directory path and file basename of a GRtoTMI geometry-match file,
; searches for the corresponding (by site, date, orbit, TRMM version) GRtoPR
; file in the same directory.  If the file isn't found by the logic, then a file
; selector dialog is displayed to allow the user to manually select the matching
; file.  Returns the name of the GRtoPR file if found, or empty string if not.
;
; PARAMETERS
; ----------
; pathpr          - Directory where the GRtoTMI file 'mygeomatchfile' is present
;                   and which will be searched for the matching GRtoPR file.
; mygeomatchfile  - File basename of the GRtoTMI volume-match netCDF file whose
;                   matching GRtoPR file is to be found.
;
; HISTORY
; -------
; 09/20/12  Morris/GPM GV/SAIC
; - Created.
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;===============================================================================


FUNCTION find_gr2pr4gr2tmi, pathpr, mygeomatchfile

; first try a simple substitution in the file name: change GRtoTMI* to GRtoPR*
IF STRPOS(mygeomatchfile, 'GRtoTMI') EQ 0 THEN BEGIN
  ; get site, date, orbit, version from GRtoTMI file, and build and search for
  ; matching GRtoPR file pattern
   parsed = STRSPLIT(mygeomatchfile, '.', /EXTRACT)
   gr2prfilepatt = 'GRtoPR.' + parsed[1]+'.'+parsed[2]+'.'+parsed[3]+'.'+parsed[4]+'.*'
   gr2prfiles = file_search(pathpr+'/'+gr2prfilepatt,COUNT=nf)
   if nf eq 1 then begin
      gr2prfile = gr2prfiles[0]
   endif else begin
      print, ''
      print, 'No or multiple netCDF files matching file pattern: '
      print, '   ', pathpr+'/'+gr2prfilepatt
      print, "Select matching GRtoPR file from File Selector:"
      print, ''
      gr2prfile = dialog_pickfile(path=pathpr, filter = 'GRtoPR.'+parsed[1]+'.'+parsed[2]+'.*')
   endelse
ENDIF ELSE BEGIN
   print, ''
   print, "ERROR in find_gr2pr4gr2tmi(), file to match is not a GRtoTMI file: "
   print, mygeomatchfile
   print, ''
   gr2prfile = ''
ENDELSE

return, gr2prfile
end
