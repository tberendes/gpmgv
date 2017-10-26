;===============================================================================
;+
; Copyright © 2012, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; pr2tmi_rr_comparisons_driver.pro
;
; DESCRIPTION
; -----------
; Reads a file containing a set of parameters to be used to run the procedure
; pr2tmi_rainrate_comparisons, parses the keyword options specified in
; the control file, and runs the procedure with the parameters specified, and
; with default values for the parameters not specified in the control file.
; Listed below are the allowed contents of the control file, with the default
; values if the parameter(s) are not specified in the control file.  The leading
; semicolons (;) are not present in the control file.  Quotes are optional in
; the control file for keywords that take string values (e.g. PS_DIR),
; except in the case where the empty string is being specified as the value
; (e.g., PS_DIR='').  Leading and trailing spaces, and spaces either side of
; the assignment operator (=) are optional and ignored.
;
; See pr2tmi_rainrate_comparisons.pro for a detailed description
; of each keyword parameter.
;
;-------------------- this line not included in control file -----------------
;  SPEED=3
;  NCPATH= (internally computed default, host-specific)
;  FILEFILTER='PRtoTMI*'
;  NO_PROMPT=0
;  WIN_SIZE=375
;  HIDE_TOTALS=1
;  POP_THRESHOLD=50
;  RR_CUT=0.1
;  BLANK_REJECTS=0
;  PS_DIR=''
;  B_W=0
;  ANIMATE=0 (see pr2tmi_rainrate_comparisons.pro prologue)
;-------------------- this line not included in control file -----------------
;
; here's the pr2tmi_rainrate_comparisons calling sequence:
;
; pr2tmi_rainrate_comparisons, SPEED=looprate, $
;                              NCPATH=ncpath, $
;                              FILEFILTER=filefilter, $
;                              NO_PROMPT=no_prompt, $
;                              WIN_SIZE=win_size, $
;                              HIDE_TOTALS=hide_totals, $
;                              POP_THRESHOLD=pop_threshold, $
;                              RR_CUT=RRcut, $
;                              BLANK_REJECTS=blank_rejects, $
;                              PS_DIR=ps_dir, $
;                              B_W=b_w, $
;                              ANIMATE=animate
;
; INTERNAL MODULES
; ----------------
; 1) pr2tmi_rr_comparisons_driver - Main driver procedure called by user
; 2) parse_parms - Parses the control file to get keyword parameters
;
; HISTORY
; -------
; 12/17/12 Morris, GPM GV, SAIC
; - Created from file rr_comparisons_driver.pro
; 04/04/13 Morris, GPM GV, SAIC
; - Added BLANK_REJECTS binary keyword and logic to parse and pass it.
; - Fixed and updated pr2tmi_rainrate_comparisons calling sequence description.
; 08/15/13 Morris, GPM GV, SAIC
; - Removed unused 'histo_Width' parameter from internal modules and external
;   call to pr2tmi_rainrate_comparisons.
;
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;===============================================================================

; Module 2: parse_parms

FUNCTION parse_parms, ctlstr, looprate, ncpath, filefilter, no_prompt, $
                      pop_threshold, RRcut, blank_rejects, win_size, $
                      hide_totals, ps_dir, b_w, animate

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
          'NCPATH' : ncpath=val
      'FILEFILTER' : filefilter=val
       'NO_PROMPT' : no_prompt=FIX(val)
        'WIN_SIZE' : win_size=FIX(val)
     'HIDE_TOTALS' : hide_totals=FIX(val)
   'POP_THRESHOLD' : pop_threshold=FLOAT(val)
          'RR_CUT' : RRcut=FLOAT(val)
   'BLANK_REJECTS' : blank_rejects=FIX(val)
          'PS_DIR' : ps_dir=val
             'B_W' : b_w=FIX(val)
         'ANIMATE' : animate=FIX(val)
             ELSE  : status = 1
ENDCASE

badKeyVal:

return, status
end

;===============================================================================
   
; Module 1: pr2tmi_rr_comparisons_driver

pro pr2tmi_rr_comparisons_driver, CONTROL_FILE=ctlfile

; assign default values to keyword parameters
CASE GETENV('HOSTNAME') OF
   'ds1-gpmgv.gsfc.nasa.gov' : datadirroot = '/data/gpmgv'
   'ws1-gpmgv.gsfc.nasa.gov' : datadirroot = '/data'
   ELSE : BEGIN
          print, "Unknown system ID, setting 'datadirroot' to user's home directory"
          datadirroot = '~/data'
          END
ENDCASE
NCPATH=datadirroot+'/geo_match'
NO_PROMPT=0
FILEFILTER='PRtoTMI*'
WIN_SIZE=375
HIDE_TOTALS=0
POP_THRESHOLD=50.0
RRcut=0.1
BLANK_REJECTS=0
PS_DIR=""
B_W=0
ANIMATE=0

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
  status = parse_parms( ctlstr, looprate, ncpath, filefilter, no_prompt, $
                        pop_threshold, RRcut, blank_rejects, win_size, $
                        hide_totals, ps_dir, b_w, animate )

  if status NE 0 THEN BEGIN
     runhelp=1
     print, ''
     print, 'Illegal parameter specification: "', ctlstr, '" in ', ctlfile
     print, 'Unassigned parameter(s) will be set to default values.'
  endif
endwhile

IF (runhelp EQ 1) THEN BEGIN
   print, ''
   print, 'Dumping variables from pr2tmi_rr_comparisons_driver procedure:'
   print, ''
   help, NAMES='*' & print, ''
ENDIF

; restrict ourselves to PRtoTMI matchup files, if not already specified in 'filefilter'
IF STRMATCH( filefilter, 'PRtoTMI*' ) NE 1 THEN filefilter='PRtoTMI*'+filefilter

pr2tmi_rainrate_comparisons, SPEED=looprate, $
                             NCPATH=ncpath, $
                             FILEFILTER=filefilter, $
                             NO_PROMPT=no_prompt, $
                             POP_THRESHOLD=pop_threshold, $
                             RR_CUT=rrcut, $
                             BLANK_REJECTS=blank_rejects, $
                             WIN_SIZE=win_size, $
                             HIDE_TOTALS=hide_totals, $
                             PS_DIR=ps_dir, $
                             B_W=b_w, $
                             ANIMATE=animate

GOTO, skipMsg
userQuit:
print, "No control file selected, quitting program.  Bye!"
print, ''
skipMsg:
end
