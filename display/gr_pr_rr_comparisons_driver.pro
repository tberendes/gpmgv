;===============================================================================
;+
; Copyright © 2011, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; rr_comparisons_driver.pro
;
; DESCRIPTION
; -----------
; Reads a file containing a set of parameters to be used to run the procedure
; geo_match_3d_rainrate_comparisons, parses the keyword options specified in
; the control file, and runs the procedure with the parameters specified, and
; with default values for the parameters not specified in the control file.
; Listed below are the allowed contents of the control file, with the default
; values if the parameter(s) are not specified in the control file.  The leading
; semicolons (;) are not present in the control file.  Quotes are optional in
; the control file for keywords that take string values (e.g. SITE or PS_DIR),
; except in the case where the empty string is being specified as the value
; (e.g., PS_DIR='').  Leading and trailing spaces, and spaces either side of
; the assignment operator (=) are optional and ignored.
;
; See geo_match_3d_rainrate_comparisons.pro for a detailed description
; of each keyword parameter.
;
;-------------------- this line not included in control file -----------------
;  SPEED=3
;  ELEVS2SHOW=3.1
;  NCPATH=/data/netcdf/geo_match
;  SITE=*
;  NO_PROMPT=0
;  PPI_VERTICAL=0
;  PPI_SIZE=375
;  PPI_IS_RR=0
;  PCT_ABV_THRESH=95
;  SHOW_THRESH_PPI=1
;  GV_CONVECTIVE=0
;  GV_STRATIFORM=0
;  HIDE_TOTALS=1
;  HIDE_RNTYPE=0
;  PS_DIR=''
;  B_W=0
;  S2KU=0
;  USE_ZR=0
;-------------------- this line not included in control file -----------------
;
; here's the geo_match_3d_rainrate_comparisons calling sequence:
;
;    geo_match_3d_rainrate_comparisons,   SPEED=looprate, $
;                                         ELEVS2SHOW=elevs2show, $
;                                         NCPATH=ncpath, $
;                                         SITE=sitefilter, $
;                                         NO_PROMPT=no_prompt, $
;                                         PPI_VERTICAL=ppi_vertical, $
;                                         PPI_SIZE=ppi_size, $
;                                         PPI_IS_RR=ppi_is_rr, $
;                                         PCT_ABV_THRESH=pctAbvThresh, $
;                                         SHOW_THRESH_PPI=show_thresh_ppi, $
;                                         GV_CONVECTIVE=gv_convective, $
;                                         GV_STRATIFORM=gv_stratiform, $
;                                         HIDE_TOTALS=hide_totals, $
;                                         HIDE_RNTYPE=hide_rntype, $
;                                         PS_DIR=ps_dir, $
;                                         B_W=b_w, $
;                                         S2KU = s2ku, $
;                                         USE_ZR = use_zr
;
; INTERNAL MODULES
; ----------------
; 1) gr_pr_rr_comparisons_driver - Main driver procedure called by user
; 2) parse_pdf_sca_parms - Parses the control file to get keyword parameters
;
; HISTORY
; -------
; 1/30/14 Morris, GPM GV, SAIC
; - Created from file rr_comparisons_driver.pro
;
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;===============================================================================


FUNCTION parse_pdf_sca_parms, ctlstr, looprate, elevs2show, ncpath, sitefilter, $
                              no_prompt, ppi_vertical, ppi_size, ppi_is_rr, $
                              pctAbvThresh, show_thresh_ppi, gv_convective, $
                              gv_stratiform, hide_totals, hide_rntype, ps_dir, $
                              b_w, s2ku, use_zr

status = 0
; trim leading/trailing whitespace and split the line in two at '='
parsed = STRSPLIT(STRTRIM(ctlstr,2), '=', /extract )

IF ( N_ELEMENTS(parsed) NE 2 ) THEN BEGIN
;   print, '******************************************************************'
;   print, 'Bad keyword/value specification "', ctlstr, '" in control file.'
;   print, 'Cannot process, ignoring line.'
;   print, '******************************************************************'
   status = 1
   GOTO, badKeyVal
ENDIF

key = STRUPCASE(STRTRIM(parsed[0],2))  ; make keyword UPPERCASE, trim whitespace
val = STRTRIM(parsed[1],2)             ; trim leading/trailing whitespace

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
           'SPEED' : looprate=FIX(val)
      'ELEVS2SHOW' : elevs2show=FLOAT(val)
          'NCPATH' : ncpath=val
            'SITE' : sitefilter=val
       'NO_PROMPT' : no_prompt=FIX(val)
    'PPI_VERTICAL' : ppi_vertical=FIX(val)
        'PPI_SIZE' : ppi_size=FIX(val)
       'PPI_IS_RR' : ppi_is_rr=FIX(val)
  'PCT_ABV_THRESH' : pctAbvThresh=FLOAT(val)
 'SHOW_THRESH_PPI' : show_thresh_ppi=FIX(val)
   'GV_CONVECTIVE' : gv_convective=FIX(val)
   'GV_STRATIFORM' : gv_stratiform=FIX(val)
     'HIDE_TOTALS' : hide_totals=FIX(val)
     'HIDE_RNTYPE' : hide_rntype=FIX(val)
          'PS_DIR' : ps_dir=val
             'B_W' : b_w=FIX(val)
            'S2KU' : s2ku=FIX(val)
          'USE_ZR' : use_zr=FIX(val)
             ELSE  : status = 1
ENDCASE

badKeyVal:

return, status
end

;===============================================================================
   
pro gr_pr_rr_comparisons_driver, CONTROL_FILE=ctlfile

; assign default values to keyword parameters
ELEVS2SHOW=3.1
NCPATH='/data/gpmgv/netcdf/geo_match'
SITEfilter='GRtoTMI*'
NO_PROMPT=0
PPI_VERTICAL=0
PPI_SIZE=375
PPI_IS_RR=0
PCT_ABV_THRESH=95
SHOW_THRESH_PPI=1
GV_CONVECTIVE=0
GV_STRATIFORM=0
HIDE_TOTALS=0
hide_rntype=0
PS_DIR=""
B_W=0
S2KU=0
USE_ZR=0

CASE N_ELEMENTS( ctlfile ) OF
     0 : BEGIN
          cd, CURRENT=cur_dir
          filters = ['*.ctl']
          ctlfile = dialog_pickfile(FILTER=filters, $
                     TITLE='Select control file to read', PATH='~')
         END
     1 : BEGIN
          finfo = FILE_INFO( ctlfile )
          IF NOT ( finfo.EXISTS AND finfo.REGULAR AND finfo.SIZE NE 0 ) THEN $
             message, "CONTROL_FILE "+ctlfile+" does not exist or is empty!  Exiting."
         END
  ELSE : message, "CONTROL_FILE must be a scalar value (file pathname)!  Exiting."
ENDCASE

IF (ctlfile EQ '') THEN GOTO, userQuit

OPENR, ctlunit, ctlfile, /GET_LUN, ERROR = err
if ( err ne 0 ) then message, 'Unable to open control file: ' + ctlfile

ctlstr = ''
fmt='(a0)'
runhelp=0  ; whether or not to run 'help' command to output defined variables

; read keyword parameter values one at a time from control file
while (eof(ctlunit) ne 1) DO BEGIN
  readf, ctlunit, ctlstr, format=fmt
  status = parse_pdf_sca_parms( ctlstr, looprate, elevs2show, ncpath, sitefilter, $
                                no_prompt, ppi_vertical, ppi_size, ppi_is_rr, $
                                pctAbvThresh, show_thresh_ppi, gv_convective, $
                                gv_stratiform, hide_totals, hide_rntype, ps_dir, $
                                b_w, s2ku, use_zr )

  if status NE 0 THEN BEGIN
     runhelp=1
     print, ''
     print, 'Illegal parameter specification: "', ctlstr, '" in ', ctlfile
     print, 'Unassigned parameter(s) will be set to default values.'
  endif
endwhile

IF (runhelp EQ 1) THEN BEGIN
   print, ''
   print, 'Dumping variables from gr_pr_rr_comparisons_driver procedure:'
   print, ''
   help, NAMES='*' & print, ''
ENDIF

; restrict ourselves to GRtoTMI matchup files, if not already specified in 'sitefilter'
IF STRMATCH( sitefilter, 'GRtoPR*' ) NE 1 THEN sitefilter='GRtoPR*'+sitefilter

geo_match_3d_rainrate_comparisons,   SPEED=looprate, $
                                     ELEVS2SHOW=elevs2show, $
                                     NCPATH=ncpath, $
                                     SITE=sitefilter, $
                                     NO_PROMPT=no_prompt, $
                                     PPI_VERTICAL=ppi_vertical, $
                                     PPI_SIZE=ppi_size, $
                                     PPI_IS_RR=ppi_is_rr, $
                                     PCT_ABV_THRESH=pctAbvThresh, $
                                     SHOW_THRESH_PPI=show_thresh_ppi, $
                                     GV_CONVECTIVE=gv_convective, $
                                     GV_STRATIFORM=gv_stratiform, $
                                     HIDE_TOTALS=hide_totals, $
                                     HIDE_RNTYPE=hide_rntype, $
                                     PS_DIR=ps_dir, $
                                     B_W=b_w, $
                                     S2KU = s2ku, $
                                     USE_ZR = use_zr

GOTO, skipMsg
userQuit:
print, "No control file selected, quitting program.  Bye!"
print, ''
skipMsg:
end
