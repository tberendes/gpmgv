;===============================================================================
;+
; Copyright © 2015, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; convert_blockage_ascii_driver.pro    Morris/SAIC/GPM_GV    Oct 2015
;
; DESCRIPTION
; -----------
; Driver program for convert_blockage_ascii_to_sav procedure.  Loops through a
; set of blockage files under the top level directory 'top_dir', checks for
; files of elevation angles where fractional blockage is detected by looking at
; the last line of the file, and calls convert_blockage_ascii_to_sav for those
; files/elevations with fractional blockage indicated.  At a minimum, the file
; for the first elevation is converted for each site, regardless of the presence
; of blockage at that elevation angle.  The '.dat' extension of the input file
; is converted to '.sav' to generate the output file pathname to which the
; binary blockage data variables will be written as an IDL "SAVE" file by the
; convert_blockage_ascii_to_sav procedure.
;
;
; HISTORY
; -------
; 10/2015 by Bob Morris, GPM GV (SAIC)
;  - Created.
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;===============================================================================


pro convert_blockage_ascii_driver, topdir, FILEPAT=filepat, REPORT=report

; check for the existence of the topdir directory
IF FILE_TEST(topdir, /DIRECTORY) NE 1 THEN $
   message, 'Directory '+topdir+' not found.'

; get the list of subdirectories (site IDs) under topdir
sitedirs = FILE_SEARCH(topdir, '*', /TEST_DIRECTORY, COUNT=nd)
if nd EQ 0 then message, 'Directory search error!'

; loop thru the sites and process files
for idir = 0, nd-1 do begin

  ; get the list of files under topdir/sitedir matching 'filepat' pattern if
  ; given, or matching the default pattern '*BeamBlockage*.dat' otherwise.
   IF N_ELEMENTS(filepat) EQ 0 THEN filepat = '*BeamBlockage*.dat'
   filelist = FILE_SEARCH(sitedirs[idir], filepat, COUNT=nf)
   if nf eq 0 then message, 'What the ?'

   ; do the first sweep's file always, reagrdless of blockage presence
   datpos = STRPOS(filelist[0], '.dat', /REVERSE_SEARCH)
   if datpos lt 0 then message, 'What the #2 ?'
   savfile = STRMID(filelist[0], 0, datpos)+'.sav'
   print, "Converting file ", filelist[0], ' to ', FILE_BASENAME(savfile)
   convert_blockage_ascii_to_sav, filelist[0], savfile, REPORT=report

   IF nf GT 1 THEN BEGIN
      for n = 1, nf-1 DO BEGIN
        ; set up a shell command to detect whether a decimal point appears
        ; in the last line of the file (i.e., at max range).  If yes (status=0),
        ; then file has fractional blockage values, process it. If no (status-1,
        ; skip it.
         command = "tail -1 " + filelist[n] + " | grep '\.' > /dev/null"
         spawn, command, EXIT_STATUS=status
         IF ( status EQ 1 ) THEN BEGIN
            print, "No blockage in file ", filelist[n], ", skipping conversion."
         ENDIF ELSE BEGIN
            datpos = STRPOS(filelist[n], '.dat', /REVERSE_SEARCH)
            savfile = STRMID(filelist[n], 0, datpos)+'.sav'
            print, "Converting file ", filelist[n], ' to ', FILE_BASENAME(savfile)
            convert_blockage_ascii_to_sav, filelist[n], savfile, REPORT=report
         ENDELSE
      endfor
   ENDIF

endfor  ; idir loop
end
