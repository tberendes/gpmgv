;===============================================================================
;+
; Copyright © 2016, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; z_rr_or_dsd_comparisons.pro
;
; DESCRIPTION
; -----------
; Reads a file containing a set of parameters to be used to run the procedure
; geo_match_3d_comparisons_all, parses the options specified in
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
; See geo_match_3d_comparisons_all.pro for a detailed description of each
; keyword parameter and its default value.
;
;-------------------- this line not included in control file -----------------
;  ANALYSIS_TYPE='Z'
;  MATCHUP_TYPE='DPR'
;  SWATH_CMB='NS'
;  KUKA_CMB='Ku'
;  SPEED=3
;  ELEVS2SHOW=3.1
;  NCPATH=/data/gpmgv/netcdf/geo_match
;  SITE=*
;  NO_PROMPT=0
;  PPI_VERTICAL=0
;  PPI_SIZE=375
;  PCT_ABV_THRESH=95
;  DPR_Z_ADJUST=0.0
;  GR_Z_ADJUST=''
;  MAX_RANGE=100
;  SHOW_THRESH_PPI=1
;  GV_CONVECTIVE=0
;  GV_STRATIFORM=0
;  ALT_BB_HGT=''
;  HIDE_TOTALS=1
;  HIDE_RNTYPE=0
;  HIDE_PPIS=
;  PS_DIR=''
;  B_W=0
;  BATCH=0
;  S2KU=0
;  USE_ZR=0
;  DZERO_ADJ=1.05
;  RECALL_NCPATH=0
;  SUBSET_METHOD=''
;  MIN_FOR_SUBSET=30.     (default value depends on subset_method)
;  SAVE_BY_RAY=0
;  SAVE_DIR=''
;  STEP_MANUAL=0
;  DECLUTTER=0
;-------------------- this line not included in control file -----------------
;
; here's the geo_match_3d_comparisons_all calling sequence:
;
;     geo_match_3d_comparisons_all, ANALYSIS_TYPE=analysis_type, $
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
;                                   Z_ONLY_PPI=z_only_ppi, $
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
;                                   GR_DM_FIELD=gr_dm_field, $
;                                   GR_NW_FIELD=gr_nw_field, $
;                                   RECALL_NCPATH=recall_ncpath, $
;                                   SUBSET_METHOD=subset_method, $
;                                   MIN_FOR_SUBSET=min_for_subset, $
;                                   SAVE_BY_RAY=save_by_ray, $
;                                   SAVE_DIR=save_dir, $
;                                   STEP_MANUAL=step_manual, $
;                                   DECLUTTER=declutter
;
; INTERNAL MODULES
; ----------------
; 1) z_rr_or_dsd_comparisons - Main driver procedure called by user
; 2) parse_dsd_parms - Parses the control file to get keyword parameters
;
; HISTORY
; -------
; 12/30/16 Morris, GPM GV, SAIC
; - Created from merging of rr_or_z_comparisons.pro and dsd_comparisons.pro.
;   See their histories for the earlier sequence of changes.
;   Calls new merged display/analysis procedure geo_match_3d_comparisons_all.
;
;
; EMAIL QUESTIONS OR COMMENTS AT:
;       https://pmm.nasa.gov/contact
;-
;===============================================================================


FUNCTION parse_dsd_parms, ctlstr, analysis_type, matchup_type, $
                          swath_cmb, kuka_cmb, looprate, $
                          elevs2show, ncpath, sitefilter, no_prompt, $
                          ppi_vertical, ppi_size, pctAbvThresh, $
                          dpr_z_adjust, gr_z_adjust, $
                          max_range, show_thresh_ppi, z_only_ppi, $
                          gv_convective, gv_stratiform, alt_bb_hgt, $
                          max_blockage, z_blockage_thresh, forcebb, $
                          hide_totals, hide_rntype, hide_ppis, ps_dir, $
                          b_w, batch, s2ku, use_zr, dzero_adj, $
                          gr_rr_field, gr_dm_field, gr_nw_field, $
                          recall_ncpath, subset_method, min_for_subset, $
                          save_by_ray, save_dir, step_manual, declutter

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
      'ANALYSIS_TYPE' : analysis_type=val
       'MATCHUP_TYPE' : matchup_type=val
          'SWATH_CMB' : swath_CMB=val
           'KUKA_CMB' : KuKa_CMB=val
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
         'Z_ONLY_PPI' : z_only_ppi=FIX(val)
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
          'DZERO_ADJ' : dzero_adj=FLOAT(val)
        'GR_RR_FIELD' : gr_rr_field=val
        'GR_DM_FIELD' : gr_dm_field=val
        'GR_NW_FIELD' : gr_nw_field=val
      'RECALL_NCPATH' : recall_ncpath=FIX(val)
      'SUBSET_METHOD' : subset_method=val
     'MIN_FOR_SUBSET' : min_for_subset=FLOAT(val)
           'SAVE_DIR' : save_dir=val
        'SAVE_BY_RAY' : save_by_ray=FIX(val)
        'STEP_MANUAL' : step_manual=FIX(val)
          'DECLUTTER' : declutter=FIX(val)
        'IS_DISABLED' : print, "Ignoring disabled control file parameter: ", $
                               STRTRIM(ctlstr,2)
                ELSE  : status = 1
ENDCASE

badKeyVal:

return, status
end

;===============================================================================
   
pro z_rr_or_dsd_comparisons, CONTROL_FILE=ctlfile

; assign default values to keyword parameters
ANALYSIS_TYPE='Z'
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
Z_ONLY_PPI=0
GV_CONVECTIVE=0
GV_STRATIFORM=0
; ALT_BB_HGT=''  ; leave undefined by default
FORCEBB=0
HIDE_TOTALS=0
HIDE_RNTYPE=0
HIDE_PPIS=0
PS_DIR=""
B_W=0
BATCH=0
S2KU=0
USE_ZR=0
DZERO_ADJ = 1.05
GR_RR_FIELD='RR'
;GR_DM_FIELD='DM'  ; leave undefined by default
;GR_NW_FIELD='NW'  ; leave undefined by default
RECALL_NCPATH=0
SUBSET_METHOD=""
MIN_FOR_SUBSET=20
SAVE_BY_RAY=0
SAVE_DIR=''
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
  status = parse_dsd_parms( ctlstr, analysis_type, matchup_type, $
                            swath_cmb, kuka_cmb, looprate, $
                            elevs2show, ncpath, sitefilter, no_prompt, $
                            ppi_vertical, ppi_size, pctAbvThresh, $
                            dpr_z_adjust, gr_z_adjust, $
                            max_range, show_thresh_ppi, z_only_ppi, $
                            gv_convective, gv_stratiform, alt_bb_hgt, $
                            max_blockage, z_blockage_thresh, forcebb , $
                            hide_totals, hide_rntype, hide_ppis, ps_dir, $
                            b_w, batch, s2ku, use_zr, dzero_adj, $
                            gr_rr_field, gr_dm_field, gr_nw_field, $
                            recall_ncpath, subset_method, min_for_subset, $
                            save_by_ray, save_dir, step_manual, declutter )

  if status NE 0 THEN BEGIN
     runhelp=1
     print, ''
     print, 'Illegal parameter specification: "', ctlstr, '" in ', ctlfile
     print, 'Unassigned parameter(s) will be set to default values.'
  endif
endwhile

IF (runhelp EQ 1) THEN BEGIN
   print, ''
   print, 'Dumping variables from dsd_comparisons procedure:'
   print, ''
   help, NAMES='*' & print, ''
ENDIF

geo_match_3d_comparisons_all, ANALYSIS_TYPE=analysis_type, $
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
                              MAX_BLOCKAGE=max_blockage_in, $
                              Z_BLOCKAGE_THRESH=z_blockage_thresh_in, $
                              SHOW_THRESH_PPI=show_thresh_ppi, $
                              Z_ONLY_PPI=z_only_ppi, $
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
                              S2KU = s2ku, $
                              USE_ZR = use_zr, $
                              DZERO_ADJ = dzero_adj, $
                              GR_RR_FIELD=gr_rr_field, $
                              GR_DM_FIELD=gr_dm_field, $
                              GR_NW_FIELD=gr_nw_field, $
                              RECALL_NCPATH=recall_ncpath, $
                              SUBSET_METHOD=subset_method, $
                              MIN_FOR_SUBSET=min_for_subset, $
                              SAVE_BY_RAY=save_by_ray, $
                              SAVE_DIR=save_dir, $
                              STEP_MANUAL=step_manual, $
                              DECLUTTER=declutter

GOTO, skipMsg
userQuit:
print, "No control file selected, quitting program.  Bye!"
print, ''
skipMsg:
end
