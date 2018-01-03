;===============================================================================
;+
; Copyright © 2009, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; cross_sections_driver.pro
;
; DESCRIPTION
; -----------
; Reads a file containing a set of parameters to be used to run the procedure
; pr_and_geo_match_x_sections(), parses the file to get values for the
; parameters specified in the file, runs the procedure with the parameters 
; specified, and with default values for those parameters not specified.
; Listed below are the allowed contents of the control file, with the default
; values that would be used if the parameter(s) were not specified in the
; control file (except for ELEV2SHOW, where the default will be computed).
;
; The leading semicolons (;) shown below are not present in the control file.
; Quotes are optional in the control file for keywords that take string values
; (e.g. SITE or NCPATH), except in the case where the empty string is being
; specified as the value (e.g., UFPATH='').  Leading and trailing spaces, and
; spaces either side of the assignment operator (=) are optional and ignored.
;
; See pr_and_geo_match_x_sections.pro for a detailed description of each
; keyword parameter.
;
;-------------------- this line not included in control file -----------------
;  ELEV2SHOW=3
;  SITE=*
;  NO_PROMPT=1
;  NCPATH=/data/netcdf/geo_match
;  PRPATH=/data/prsubsets
;  UFPATH='/data/gv_radar/finalQC_in'
;  USE_DB=0
;  NO_2A25=1
;  PCT_ABV_THRESH=0
;-------------------- this line not included in control file -----------------
;
; here's the summary of the pr_and_geo_match_x_sections calling sequence:
;
;   pr_and_geo_match_x_sections, ELEV2SHOW=elev2show, SITE=sitefilter, $
;                                NO_PROMPT=no_prompt, NCPATH=ncpath,   $
;                                PRPATH=prpath, UFPATH=ufpath, USE_DB=use_db, $
;                                NO_2A25=no_2a25, PCT_ABV_THRESH=pctAbvThresh
;
;
; INTERNAL MODULES
; ----------------
; 1) cross_sections_driver - Main driver procedure called by user
; 2) parse_xsect_parms - Parses the control file to get keyword parameters
;
; HISTORY
; -------
; 11/11/09 Morris, GPM GV, SAIC
; - Created CM version from file wrapf_pr_and_geo_match_x_sections.pro
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;===============================================================================


FUNCTION parse_xsect_parms, ctlstr, elev2show, sitefilter, no_prompt, ncpath, $
                            prpath, ufpath, use_db, no_2a25, pctAbvThresh

status = 0
parsed = STRSPLIT(STRTRIM(ctlstr,2), '=', /extract )

IF ( N_ELEMENTS(parsed) NE 2 ) THEN BEGIN
;   print, '******************************************************************'
;   print, 'Bad keyword/value specification "', ctlstr, '" in control file.'
;   print, 'Cannot process, ignoring line.'
;   print, '******************************************************************'
   status = 1
   GOTO, badKeyVal
ENDIF

key = STRUPCASE(STRTRIM(parsed[0],2))
val = STRTRIM(parsed[1],2)

IF (STRPOS(val,'"') EQ -1) AND (STRPOS(val,"'") EQ -1) THEN GOTO, skipquotes

; strip leading/trailing ' or " characters from the control file keyword values
; (they are already in the form of strings due to parsing by STRSPLIT)
IF ( STRLEN(val) GT 2 ) THEN BEGIN
   char1 = STRMID( val, 0, 1 )
   charN = STRMID( val, 0, 1, /REVERSE_OFFSET )
   IF ((char1 EQ '"') OR (char1 EQ "'")) $
   OR ((charN EQ '"') OR (charN EQ "'")) THEN BEGIN
      IF (char1 EQ charN) THEN val = STRMID( val, 1, STRLEN(val)-2 ) $
      ELSE BEGIN
         print, '**********************************************'
         print, 'Error in specifying parameter: ', ctlstr
         print, 'Setting ', key, ' to default.'
         print, '**********************************************'
         val=''
         GOTO, badKeyVal
      ENDELSE
   ENDIF
ENDIF ELSE BEGIN
   IF ( val EQ "''" ) OR ( val EQ '""' ) THEN val='' $ ; set to true empty string
   ELSE BEGIN
      print, '**********************************************'
      print, 'Error in specifying parameter: ', ctlstr
      print, 'Setting ', key, ' to default.'
      print, '**********************************************'
      val=''
      GOTO, badKeyVal
   ENDELSE
ENDELSE

skipquotes:

CASE key OF
       'ELEV2SHOW' : elev2show=FIX(val)
            'SITE' : sitefilter=val
       'NO_PROMPT' : no_prompt=FIX(val)
          'NCPATH' : ncpath=val
          'PRPATH' : prpath=val
          'UFPATH' : ufpath=val
          'USE_DB' : use_db=FIX(val)
         'NO_2A25' : no_2a25=FIX(val)
  'PCT_ABV_THRESH' : pctAbvThresh=FIX(val)
             ELSE  : status = 1
ENDCASE

badKeyVal:

return, status
end

;===============================================================================
   
pro cross_sections_driver_csu

; assign default values except for ELEV2SHOW parameter, which will be computed
; by pr_and_geo_match_x_sections() if unset.

ncpath='/data/netcdf/geo_match'
prpath='/data/prsubsets'
ufpath='/data/gv_radar/finalQC_in'
no_prompt=0
site=''
use_db=0
no_2a25=1
pct_Abv_Thresh=0

; let the user select the desired control file

cd, CURRENT=cur_dir
filters = ['*.ctl']
ctlfile = dialog_pickfile(FILTER=filters, TITLE='Select control file to read', PATH='~')
;ctlfile = '~/xsections.ctl'

IF (ctlfile EQ '') THEN GOTO, userQuit

OPENR, ctlunit, ctlfile, /GET_LUN, ERROR = err
if ( err ne 0 ) then message, 'Unable to open control file: ' + ctlfile

; parse the control file line-by-line to get user's parameter values, and giddyup-go

ctlstr = ''
fmt='(a0)'
runhelp=0  ; whether or not to run 'help' command to output defined variables

; read keyword parameter values one at a time from control file
while (eof(ctlunit) ne 1) DO BEGIN
  readf, ctlunit, ctlstr, format=fmt
  status = parse_xsect_parms( ctlstr, elev2show, sitefilter, no_prompt, ncpath, $
                              prpath, ufpath, use_db, no_2a25, pct_Abv_Thresh)

  if status NE 0 THEN BEGIN
     runhelp=1
     print, ''
     print, 'Illegal parameter specification: "', ctlstr, '" in ', ctlfile
     print, 'Unassigned parameter(s) will be set to default values.'
  endif
endwhile

IF (runhelp EQ 1) THEN BEGIN
   print, ''
   print, 'Dumping variables from cross_sections_driver procedure:'
   print, ''
   help, NAMES='*' & print, ''
ENDIF

pr_and_geo_match_x_sections_csu, ELEV2SHOW=elev2show, SITE=sitefilter, $
                             NO_PROMPT=no_prompt, NCPATH=ncpath,   $
                             PRPATH=prpath, UFPATH=ufpath, USE_DB=use_db, $
                             NO_2A25=no_2a25, PCT_ABV_THRESH=pct_Abv_Thresh

GOTO, skipMsg
userQuit:
print, "No control file selected, quitting program.  Bye!"
print, ''
skipMsg:
end
