;+
; Copyright © 2014, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; get_ruc_bb.pro    Bob Morris, GPM GV (SAIC)    November 2014
;
; DESCRIPTION:
; Extracts and returns the precomputed Bright Band height from the text file
; alt_bb_file, given strings for the site ID and orbit number of the event.  If
; a match to the site and orbit is not found, returns -99.99 as the BB height
; by default unless the optional MISSING parameter is specified to override
; this default value.  
;
; The text file of precomputed Bright Band height is created externally by the
; bash script get_RUC_BB_heights.sh, which is run on hector.gsfc.nasa.gov and 
; is located under /gvraid/ftp/gpm-validation/scripts.
;
; For alt_bb_file, see files rain_event_bb.txt and rain_event_bb_km.txt in
; the /gvraid/ftp/gpm-validation directory on hector, and on ds1-gpmgv under
; /data/tmp, see files GPM_rain_event_bb.txt and GPM_rain_event_bb_km.txt.
;
; It is up to the calling routine to verify that alt_bb_file exists and is
; readable.  No checks of the file existence, access permissions, or format is
; performed in this function.
;
; HISTORY:
; 11/26/14  Morris, GPM GV, SAIC
;  - Created.
; 08/11/16  Morris, GPM GV, SAIC
;  - Added check for duplicate values returned from grep command, and take only
;    first value in returned scalar/array.
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;
;-------------------------------------------------------------------------------

FUNCTION get_ruc_bb, alt_bb_file, siteID, orbit, MISSING=miss, VERBOSE=verbose

   ; initialize return value
   IF N_ELEMENTS(miss) EQ 1 THEN bbhgt = miss ELSE bbhgt = -99.99

   site_orbit_pattern = '"'+siteID+"|"+orbit+"|"+'"'
   IF KEYWORD_SET(verbose) THEN BEGIN
      print, "In get_ruc_bb(): alt_bb_file: ", alt_bb_file
      print, "In get_ruc_bb(): site_orbit_pattern: ", site_orbit_pattern
   ENDIF
   command = "grep " + site_orbit_pattern +" "+ alt_bb_file
   spawn, command, result

   IF N_ELEMENTS(result) GT 1 THEN message, "Duplicate site/orbit entry in " $
      + alt_bb_file + ": " + result[0], /info

   IF result[0] NE '' THEN BEGIN
      parsed = STRSPLIT(result[0], '|', /extract)
      bbhgt = FLOAT(parsed[2])
      IF KEYWORD_SET(verbose) THEN BEGIN
         print, "In get_ruc_bb(): Line match: ", result[0]
         print, "In get_ruc_bb(): BB hgt: ", bbhgt
      ENDIF
   ENDIF ELSE BEGIN
      IF KEYWORD_SET(verbose) THEN BEGIN
         print, "In get_ruc_bb(): No line match or no unique match!"
         print, "In get_ruc_bb(): BB hgt: ", bbhgt
      ENDIF
   ENDELSE

   return, bbhgt
END
