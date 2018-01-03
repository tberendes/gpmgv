;===============================================================================
;+
; Copyright © 2016, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; site_bias_hash_from_file.pro
;
; DESCRIPTION
; -----------
; Reads a "|"-delimited text file containing the bias offset to be applied
; (added to) each ground radar site's reflectivity to correct the calibration
; offset between the DPR and ground radars in a site-specific sense.  Each line
; of the text file lists one site identifier and its bias offset value separated
; by the delimiter, e.g.:
;
;   KMLB|2.89
;   NPOL_MD|-0.2
;
; where the comment character ';' at the beginning is not present in the file.
;
; The site ID and bias values are parsed from each line with a valid format and
; an IDL HASH object is created from the valid siteID/biasValue pairs, where the
; site ID is the HASH key value and the bias is the looked-up value.  If one or
; more valid key/value pairs is read from the file, then the HASH object is the
; returned value from this function, otherwise the value -1 is returned.  Empty
; lines in the site bias file are ignored, but lines with illegal format cause
; a fatal error/message.  The site ID values are not checked for validity as
; known Validation Network radar IDs.  The bias values are only checked to
; assure they are numbers, but their values are not checked or constrained.
;
; Any extra whitespace in the file lines is ignored, so lines like the following
; (without the ';') are also valid:
;
;   KMLB    |  2.89
;   NPOL_MD | -0.2
;
; The order of the entries in the site bias file is not important.  If more than
; one line having the same site ID is present, then only the last occurrence's
; key/value pair will be present in the returned HASH object (IDL rules).  Site
; ID values are case-sensitive, and must match the site ID values present in the
; matchup netCDF filenames whose data are to be adjusted.
;
; HISTORY
; -------
; 11/2016  Morris, GPM GV, SAIC
; - Created.
;
;
; EMAIL QUESTIONS OR COMMENTS AT:
;       https://pmm.nasa.gov/contact
;-
;===============================================================================

FUNCTION site_bias_hash_from_file, biasFile

fileInfo = FILE_INFO( biasFile )
IF fileInfo.REGULAR THEN BEGIN
  ; get a count of lines in the file
   nsites = FILE_LINES( biasFile )
   IF nsites GT 0 THEN BEGIN
     ; create key and value arrays for our hash
      siteArr = STRARR(nsites)
      biasArr = FLTARR(nsites)
     ; read and check that each line is in the proper format
      OPENR, unit, biasFile, /GET_LUN
      str = ''
      count = 0
      WHILE ~ EOF(unit) DO BEGIN
         READF, unit, str
        ; ignore empty string that you would get with a blank line or if
        ; the last line terminates with a newline character
         IF str NE '' THEN BEGIN
            parsed = STRSPLIT(str, '|', /EXTRACT)
            IF N_ELEMENTS(parsed) NE 2 THEN $
               message, "File '"+biasFile+"' not correct format."
            IF is_a_number(parsed[1]) THEN BEGIN
               siteArr[count] = STRTRIM(parsed[0],2)  ; remove any whitespace
               biasArr[count] = FLOAT(parsed[1])
               count = count + 1
            ENDIF ELSE message, "Site bias value not a number, line = "+str
         ENDIF ELSE message, "Ignoring empty line in file "+biasFile, /INFO
      ENDWHILE
      FREE_LUN, unit
      IF count GT 0 THEN return, HASH(siteArr[0:count-1], biasArr[0:count-1]) $
      ELSE BEGIN
         message, "No valid entries in site bias file '"+biasFile+"'", /INFO
         return, -1
      ENDELSE
   ENDIF ELSE BEGIN
      message, "Site bias file '"+biasFile+"' is empty.", /INFO
      return, -1
   ENDELSE
ENDIF ELSE BEGIN
   message, "Site bias file '"+biasFile+"' not found or not a file.", /INFO
   return, -1
ENDELSE

end
