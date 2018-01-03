;===============================================================================
;+
; Copyright © 2015, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; rr_or_z_comparisons.pro
;
; DESCRIPTION
; -----------
; Upgraded replacement for z_comparisons_driver.pro procedure, which was a
; replacement for the ugly named wrapf_geo_m_z_pdf_profi_bbprox_sca_ps.pro.
;
; Reads a file containing a set of parameters to be used to run the procedure
; geo_match_3d_rr_or_z_comparisons, parses the options specified in
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
; See geo_match_3d_rr_or_z_comparisons.pro for a detailed description
; of each keyword parameter.
;
;-------------------- this line not included in control file -----------------
;  RR_OR_Z='Z'
;  MATCHUP_TYPE='DPR'
;  SWATH_CMB='NS'
;  KUKA_CMB='Ku'
;  SPEED=3
;  ELEVS2SHOW=3.1
;  NCPATH=/data/gpmgv/netcdf/geo_match/TRMM/PR/V07/3_1
;  SITE=*
;  NO_PROMPT=0
;  PPI_VERTICAL=0
;  PPI_SIZE=375
;  PCT_ABV_THRESH=95
;  DPR_Z_ADJUST=0.0
;  GR_Z_ADJUST=''
;  MAX_RANGE=100
;  MAX_BLOCKAGE=1.0
;  SHOW_THRESH_PPI=1
;  GV_CONVECTIVE=0
;  GV_STRATIFORM=0
;  ALT_BB_HGT=''
;  FORCEBB=0
;  HIDE_TOTALS=1
;  HIDE_RNTYPE=0
;  HIDE_PPIS=0
;  PS_DIR=''
;  B_W=0
;  BATCH=0
;  S2KU=0
;  USE_ZR=0
;  GR_RR_FIELD='RR'
;  RECALL_NCPATH=0
;  SUBSET_METHOD=''
;  MIN_FOR_SUBSET=  (depends on SUBSET_METHOD and RR_OR_Z)
;  SAVE_DIR=''
;  SAVE_BY_RAY=0
;  STEP_MANUAL=0
;  DECLUTTER=0
;-------------------- this line not included in control file -----------------
;
; here's the geo_match_3d_rr_or_z_comparisons calling sequence:
;
; geo_match_3d_rr_or_z_comparisons, RR_OR_Z=rr_or_z, $
;                                   MATCHUP_TYPE=matchup_type, $
;                                   SWATH_CMB=swath_CMB, $
;                                   KUKA_CMB=KuKa_CMB, $
;                                   SPEED=looprate, $
;                                   ELEVS2SHOW=elevs2show, $
;                                   NCPATH=ncpath, $
;                                   SITE=sitefilter, $
;                                   NO_PROMPT=no_prompt, $
;                                   PPI_VERTICAL=ppi_vertical, $
;                                   PPI_SIZE=ppi_size, $
;                                   PCT_ABV_THRESH=pctAbvThresh, $
;                                   DPR_Z_ADJUST=dpr_z_adjust, $
;                                   GR_Z_ADJUST=gr_z_adjust, $
;                                   MAX_RANGE=max_range, $
;                                   MAX_BLOCKAGE=max_blockage_in, $
;                                   Z_BLOCKAGE_THRESH=z_blockage_thresh_in, $
;                                   SHOW_THRESH_PPI=show_thresh_ppi, $
;                                   GV_CONVECTIVE=gv_convective, $
;                                   GV_STRATIFORM=gv_stratiform, $
;                                   ALT_BB_HGT=alt_bb_hgt, $
;                                   FORCEBB=forcebb, $
;                                   HIDE_TOTALS=hide_totals, $
;                                   HIDE_RNTYPE=hide_rntype, $
;                                   HIDE_PPIS=hide_ppis, $
;                                   PS_DIR=ps_dir, $
;                                   B_W=b_w, $
;                                   BATCH=batch, $
;                                   S2KU = s2ku, $
;                                   USE_ZR = use_zr, $
;                                   GR_RR_FIELD=gr_rr_field, $
;                                   RECALL_NCPATH=recall_ncpath, $
;                                   SUBSET_METHOD=subset_method, $
;                                   MIN_FOR_SUBSET=min_for_subset, $
;                                   SAVE_DIR=save_dir, $
;                                   SAVE_BY_RAY=save_by_ray, $
;                                   STEP_MANUAL=step_manual, $
;                                   DECLUTTER=declutter
;
; INTERNAL MODULES
; ----------------
; 1) rr_or_z_comparisons - Main driver procedure called by user
; 2) parse_rr_or_z_parms - Parses the control file to get keyword parameters
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
; 04/22/15 Morris, GPM GV, SAIC
; - Created from z_comparisons_driver to call geo_match_3d_rr_or_z_comparisons.
; 06/24/15  Morris/GPM GV/SAIC
; - Changed INSTRUMENT/instrument KEYWORD/variable to MATCHUP_TYPE/matchup_type.
; - Added keyword variables SWATH_CMB and KUKA_CMB to support analysis of DPRGMI
;   matchup datasets.
; 07/17/15  Morris/GPM GV/SAIC
; - Added DECLUTTER parameter to support this new mode in the
;   geo_match_3d_dsd_comparisons procedure.
; - Renamed internal function parse_pdf_sca_parms to parse_rr_or_z_parms
; 12/9/15 by Bob Morris, GPM GV (SAIC)
; - Added HIDE_PPIS, FORCEBB, MAX_BLOCKAGE, and Z_BLOCKAGE_THRESH keyword
;   parameters to the set.
; - Added ability to recognize and ignore commented-out lines in control files.
; 11/22/16 Morris, GPM GV, SAIC
; - Added DPR_Z_ADJUST=dpr_z_adjust and GR_Z_ADJUST=gr_z_adjust keyword/value
;   pairs to support DPR and site-specific GR bias adjustments.
; 12/07/16 Morris, GPM GV, SAIC
; - Added keyword variable SAVE_BY_RAY to support specialized analysis of 
;   DPRGMI matchup datasets.
; 01/13/17 Morris, GPM GV, SAIC
; - Disabled execution of this procedure and added message to the effect that it
;   has been superseded by z_rr_dsd_event_statistics.pro.
;
;
; EMAIL QUESTIONS OR COMMENTS AT:
;       https://pmm.nasa.gov/contact
;-
;===============================================================================


FUNCTION parse_rr_or_z_parms, ctlstr, rr_or_z, matchup_type, looprate, $
                              elevs2show, ncpath, sitefilter, no_prompt, $
                              ppi_vertical, ppi_size, pctAbvThresh, $
                              dpr_z_adjust, gr_z_adjust, $
                              max_range, show_thresh_ppi, gv_convective, $
                              gv_stratiform, alt_bb_hgt, hide_totals, $
                              hide_rntype, ps_dir, b_w, batch, s2ku, use_zr, $
                              gr_rr_field, recall_ncpath, subset_method, $
                              min_for_subset, save_dir, save_by_ray, step_manual, $
                              swath_cmb, kuka_cmb, declutter, max_blockage, $
                              z_blockage_thresh, hide_ppis, forcebb

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

; check whether parameter is commented out of control file, and if so, set key
; to a special value that won't return a keyword error status
IF ( STRMID( key, 0, 1 ) EQ ';' ) THEN key = 'IS_DISABLED'

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
         'RR_OR_Z' : rr_or_z=val
    'MATCHUP_TYPE' : matchup_type=val
           'SPEED' : looprate=FIX(val)
      'ELEVS2SHOW' : elevs2show=FLOAT(val)
          'NCPATH' : ncpath=val
            'SITE' : sitefilter=val
       'NO_PROMPT' : no_prompt=FIX(val)
    'PPI_VERTICAL' : ppi_vertical=FIX(val)
        'PPI_SIZE' : ppi_size=FIX(val)
  'PCT_ABV_THRESH' : pctAbvThresh=FLOAT(val)
    'DPR_Z_ADJUST' : dpr_z_adjust=FLOAT(val)
     'GR_Z_ADJUST' : gr_z_adjust=val
       'MAX_RANGE' : max_range=FLOAT(val)
    'MAX_BLOCKAGE' : max_blockage=FLOAT(val)
'Z_BLOCKAGE_THRESH' : z_blockage_thresh=FLOAT(val)
 'SHOW_THRESH_PPI' : show_thresh_ppi=FIX(val)
   'GV_CONVECTIVE' : gv_convective=FIX(val)
   'GV_STRATIFORM' : gv_stratiform=FIX(val)
      'ALT_BB_HGT' : alt_bb_hgt=val
         'FORCEBB' : forcebb=FIX(val)
     'HIDE_TOTALS' : hide_totals=FIX(val)
     'HIDE_RNTYPE' : hide_rntype=FIX(val)
       'HIDE_PPIS' : hide_ppis=FIX(val)
          'PS_DIR' : ps_dir=val
             'B_W' : b_w=FIX(val)
            'S2KU' : s2ku=FIX(val)
           'BATCH' : batch=FIX(val)
          'USE_ZR' : bgwhite=FIX(val)
     'GR_RR_FIELD' : gr_rr_field=val
   'RECALL_NCPATH' : recall_ncpath=FIX(val)
   'SUBSET_METHOD' : subset_method=val
  'MIN_FOR_SUBSET' : min_for_subset=FLOAT(val)
        'SAVE_DIR' : save_dir=val
     'SAVE_BY_RAY' : save_by_ray=FIX(val)
     'STEP_MANUAL' : step_manual=FIX(val)
       'SWATH_CMB' : swath_CMB=val
        'KUKA_CMB' : KuKa_CMB=val
       'DECLUTTER' : declutter=FIX(val)
     'IS_DISABLED' : print, "Ignoring disabled control file parameter: ", $
                            STRTRIM(ctlstr,2)
             ELSE  : status = 1
ENDCASE

badKeyVal:

return, status
end

;===============================================================================
   
pro rr_or_z_comparisons, CONTROL_FILE=ctlfile

print, "" & print, "NOTE:"
PRINT, "This procedure has been superseded by z_rr_dsd_event_statistics.pro, ", $
       "a merger of rr_or_z_comparisons.pro and dsd_comparisons.pro.  Exiting."
print, ''
GOTO, skipMsg

; assign default values to keyword parameters
RR_OR_Z='Z'
MATCHUP_TYPE='DPR'
; SWATH_CMB='NS'  ; leave undefined by default, only applies to DPRGMI type
; KUKA_CMB='Ku'   ; leave undefined by default, only applies to DPRGMI type
SPEED=3
ELEVS2SHOW=3.1
NCPATH='/data/gpmgv/netcdf/geo_match/GPM'
SITE='*'
NO_PROMPT=0
PPI_VERTICAL=0
PPI_SIZE=375
PCT_ABV_THRESH=0
;dpr_z_adjust=0.0     ; leave undefined by default
;gr_z_adjust=''       ; leave undefined by default
MAX_RANGE=100
; MAX_BLOCKAGE=1.0       ; leave undefined by default
; Z_BLOCKAGE_THRESH=3.0  ; leave undefined by default
SHOW_THRESH_PPI=1
GV_CONVECTIVE=0
GV_STRATIFORM=0
; ALT_BB_HGT=''          ; leave undefined by default
FORCEBB=0
HIDE_TOTALS=0
HIDE_RNTYPE=0
HIDE_PPIS=0
PS_DIR=""
B_W=0
BATCH=0
S2KU=0
USE_ZR=0
GR_RR_FIELD='RR'
RECALL_NCPATH=0
SUBSET_METHOD=""
MIN_FOR_SUBSET=20
SAVE_DIR=''
SAVE_BY_RAY=0
STEP_MANUAL=0
DECLUTTER=0

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
  status = parse_rr_or_z_parms( ctlstr, rr_or_z, matchup_type, looprate, $
                                elevs2show, ncpath, sitefilter, no_prompt, $
                                ppi_vertical, ppi_size, pctAbvThresh, $
                                dpr_z_adjust, gr_z_adjust, $
                                max_range, show_thresh_ppi, gv_convective, $
                                gv_stratiform, alt_bb_hgt, hide_totals, $
                                hide_rntype, ps_dir, b_w, batch, s2ku, use_zr, $
                                gr_rr_field, recall_ncpath, subset_method, $
                                min_for_subset, save_dir, save_by_ray, step_manual, $
                                swath_cmb, kuka_cmb, declutter, max_blockage, $
                                z_blockage_thresh, hide_ppis, forcebb )

  if status NE 0 THEN BEGIN
     runhelp=1
     print, ''
     print, 'Illegal parameter specification: "', ctlstr, '" in ', ctlfile
     print, 'Unassigned parameter(s) will be set to default values.'
  endif
endwhile

IF (runhelp EQ 1) THEN BEGIN
   print, ''
   print, 'Dumping variables from rr_or_z_comparisons procedure:'
   print, ''
   help, NAMES='*' & print, ''
ENDIF

geo_match_3d_rr_or_z_comparisons, RR_OR_Z=rr_or_z, $
                                  MATCHUP_TYPE=matchup_type, $
                                  SWATH_CMB=swath_CMB, $
                                  KUKA_CMB=KuKa_CMB, $
                                  SPEED=looprate, $
                                  ELEVS2SHOW=elevs2show, $
                                  NCPATH=ncpath, $
                                  SITE=sitefilter, $
                                  NO_PROMPT=no_prompt, $
                                  PPI_VERTICAL=ppi_vertical, $
                                  PPI_SIZE=ppi_size, $
                                  PCT_ABV_THRESH=pctAbvThresh, $
                                  DPR_Z_ADJUST=dpr_z_adjust, $
                                  GR_Z_ADJUST=gr_z_adjust, $
                                  MAX_RANGE=max_range, $
                                  MAX_BLOCKAGE=max_blockage, $
                                  Z_BLOCKAGE_THRESH=z_blockage_thresh, $
                                  SHOW_THRESH_PPI=show_thresh_ppi, $
                                  GV_CONVECTIVE=gv_convective, $
                                  GV_STRATIFORM=gv_stratiform, $
                                  ALT_BB_HGT=alt_bb_hgt, $
                                  FORCEBB=forcebb, $
                                  HIDE_TOTALS=hide_totals, $
                                  HIDE_RNTYPE=hide_rntype, $
                                  HIDE_PPIS=hide_ppis, $
                                  PS_DIR=ps_dir, $
                                  B_W=b_w, $
                                  BATCH=batch, $
                                  S2KU=s2ku, $
                                  USE_ZR=use_zr, $
                                  GR_RR_FIELD=gr_rr_field, $
                                  RECALL_NCPATH=recall_ncpath, $
                                  SUBSET_METHOD=subset_method, $
                                  MIN_FOR_SUBSET=min_for_subset, $
                                  SAVE_DIR=save_dir, $
                                  SAVE_BY_RAY=save_by_ray, $
                                  STEP_MANUAL=step_manual, $
                                  DECLUTTER=declutter

GOTO, skipMsg
userQuit:
print, "No control file selected, quitting program.  Bye!"
print, ''
skipMsg:
end
