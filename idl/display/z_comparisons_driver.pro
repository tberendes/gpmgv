;===============================================================================
;+
; Copyright © 2009, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; z_comparisons_driver.pro
;
; DESCRIPTION
; -----------
; Reads a file containing a set of parameters to be used to run the procedure
; geo_match_z_pdf_profile_ppi_bb_prox_sca_ps, parses the options specified in
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
; See geo_match_z_pdf_profile_ppi_bb_prox_sca_ps.pro for a detailed description
; of each keyword parameter.
;
;-------------------- this line not included in control file -----------------
;  SPEED=3
;  ELEVS2SHOW=3.1
;  NCPATH=/data/gpmgv/netcdf/geo_match/TRMM/PR/V07/3_1
;  SITE=*
;  NO_PROMPT=0
;  PPI_VERTICAL=0
;  PPI_SIZE=375
;  PCT_ABV_THRESH=95
;  SHOW_THRESH_PPI=1
;  GV_CONVECTIVE=0
;  GV_STRATIFORM=0
;  HISTO_WIDTH=2
;  HIDE_TOTALS=1
;  HIDE_RNTYPE=0
;  PS_DIR=''
;  B_W=0
;  BATCH=0
;  S2KU=0
;  BGWHITE=0
;  RECALL_NCPATH=0
;-------------------- this line not included in control file -----------------
;
; here's the geo_match_z_pdf_profile_ppi_bb_prox_sca_ps calling sequence:
;
; geo_match_z_pdf_profile_ppi_bb_prox_sca_ps, SPEED=looprate, $
;                                             ELEVS2SHOW=elevs2show, $
;                                             NCPATH=ncpath, $
;                                             SITE=sitefilter, $
;                                             NO_PROMPT=no_prompt, $
;                                             PPI_VERTICAL=ppi_vertical, $
;                                             PPI_SIZE=ppi_size, $
;                                             PCT_ABV_THRESH=pctAbvThresh, $
;                                             SHOW_THRESH_PPI=show_thresh_ppi, $
;                                             GV_CONVECTIVE=gv_convective, $
;                                             GV_STRATIFORM=gv_stratiform, $
;                                             HISTO_WIDTH=histo_Width, $
;                                             HIDE_TOTALS=hide_totals, $
;                                             HIDE_RNTYPE=hide_rntype, $
;                                             PS_DIR=ps_dir, $
;                                             B_W=b_w, $
;                                             BATCH=batch, $
;                                             S2KU = s2ku, $
;                                             BGWHITE = bgwhite, $
;                                             RECALL_NCPATH=recall_ncpath
;
; INTERNAL MODULES
; ----------------
; 1) z_comparisons_driver - Main driver procedure called by user
; 2) parse_pdf_sca_parms - Parses the control file to get keyword parameters
;
; HISTORY
; -------
; 11/12/09 Morris, GPM GV, SAIC
; - Created CM version from file wrapf_geo_m_z_pdf_profi_bbprox_sca_ps.pro
; 03/31/11 Morris, GPM GV, SAIC
; - Added BATCH keyword option to the control file.
; - Added CONTROL_FILE keyword argument to z_comparisons_driver to allow it to
;   be run in full batch mode from regular IDL (not the Virtual Machine).
; 07/31/12  Morris/GPM GV/SAIC
; - Added BGWHITE parameter to provide an option to plot PDF/Profile and PPI
;   graphics with a white background rather than the default black background.
; 02/23/15  Morris/GPM GV/SAIC
; - Added HIDE_RNTYPE parameter to control presence of rain type hatching on PPI
;   plots.  Modified default NCPATH to reflect reorganized geo_match directory.
; 03/13/15  Morris/GPM GV/SAIC
; - Added RECALL_NCPATH keyword and logic to define a user-defined system
;   variable to remember and use the last-selected file path to override the
;   NCPATH and/or the default netCDF file path on startup of the procedure.
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;===============================================================================


FUNCTION parse_pdf_sca_parms, ctlstr, looprate, elevs2show, ncpath, sitefilter, $
                              no_prompt, ppi_vertical, ppi_size, pctAbvThresh,  $
                              show_thresh_ppi, gv_convective, gv_stratiform,    $
                              histo_Width, hide_totals, hide_rntype, ps_dir,    $
                              b_w, batch, s2ku, bgwhite, recall_ncpath

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
  'PCT_ABV_THRESH' : pctAbvThresh=FLOAT(val)
 'SHOW_THRESH_PPI' : show_thresh_ppi=FIX(val)
   'GV_CONVECTIVE' : gv_convective=FIX(val)
   'GV_STRATIFORM' : gv_stratiform=FIX(val)
     'HISTO_WIDTH' : histo_Width=FIX(val)
     'HIDE_TOTALS' : hide_totals=FIX(val)
     'HIDE_RNTYPE' : hide_rntype=FIX(val)
          'PS_DIR' : ps_dir=val
             'B_W' : b_w=FIX(val)
            'S2KU' : s2ku=FIX(val)
           'BATCH' : batch=FIX(val)
         'BGWHITE' : bgwhite=FIX(val)
   'RECALL_NCPATH' : recall_ncpath=FIX(val)
             ELSE  : status = 1
ENDCASE

badKeyVal:

return, status
end

;===============================================================================
   
pro z_comparisons_driver, CONTROL_FILE=ctlfile

; assign default values to keyword parameters
NCPATH='/data/gpmgv/netcdf/geo_match/TRMM/PR/V07/3_1'
NO_PROMPT=0
SITE='*'
ELEVS2SHOW=3.1
PPI_VERTICAL=0
PPI_SIZE=375
PCT_ABV_THRESH=95
SHOW_THRESH_PPI=1
GV_CONVECTIVE=0
GV_STRATIFORM=0
HISTO_WIDTH=2
HIDE_TOTALS=1
HIDE_RNTYPE=0
PS_DIR=""
B_W=0
BATCH=0
S2KU=0
BGWHITE=0
RECALL_NCPATH=0

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
                                no_prompt, ppi_vertical, ppi_size, pctAbvThresh,  $
                                show_thresh_ppi, gv_convective, gv_stratiform,    $
                                histo_Width, hide_totals, hide_rntype, ps_dir,    $
                                b_w, batch, s2ku, bgwhite, recall_ncpath )

  if status NE 0 THEN BEGIN
     runhelp=1
     print, ''
     print, 'Illegal parameter specification: "', ctlstr, '" in ', ctlfile
     print, 'Unassigned parameter(s) will be set to default values.'
  endif
endwhile

IF (runhelp EQ 1) THEN BEGIN
   print, ''
   print, 'Dumping variables from z_comparisons_driver procedure:'
   print, ''
   help, NAMES='*' & print, ''
ENDIF

geo_match_z_pdf_profile_ppi_bb_prox_sca_ps, SPEED=looprate, $
                                            ELEVS2SHOW=elevs2show, $
                                            NCPATH=ncpath, $
                                            SITE=sitefilter, $
                                            NO_PROMPT=no_prompt, $
                                            PPI_VERTICAL=ppi_vertical, $
                                            PPI_SIZE=ppi_size, $
                                            PCT_ABV_THRESH=pctAbvThresh, $
                                            SHOW_THRESH_PPI=show_thresh_ppi, $
                                            GV_CONVECTIVE=gv_convective, $
                                            GV_STRATIFORM=gv_stratiform, $
                                            HISTO_WIDTH=histo_Width, $
                                            HIDE_TOTALS=hide_totals, $
                                            HIDE_RNTYPE=hide_rntype, $
                                            PS_DIR=ps_dir, $
                                            B_W=b_w, $
                                            BATCH=batch, $
                                            S2KU = s2ku, $
                                            BGWHITE = bgwhite, $
                                            RECALL_NCPATH=recall_ncpath

GOTO, skipMsg
userQuit:
print, "No control file selected, quitting program.  Bye!"
print, ''
skipMsg:
end
