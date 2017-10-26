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
; pr_and_geo_match_x_sections() (by default) or the DPR/DPRGMI merged procedure
; dpr_and_geo_match_x_sections().  Parses the file to get values for the
; parameters specified in the file, and runs the user-selected or default
; procedure with the parameters specified, and with default values for those
; parameters not specified.  The value of the keyword parameter MATCHUP_TYPE
; determines which of the procedures will be run and which type of matchup data
; will be analyzed:
;
;      "PR"  =>  pr_and_geo_match_x_sections()    (analyze GRtoPR matchup data)
;     "DPR"  =>  dpr_and_geo_match_x_sections()   (analyze GRtoDPR matchup data)
;  "DPRGMI"  =>  dpr_and_geo_match_x_sections()   (" GRtoDPRGMI ")
;
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
; See pr_and_geo_match_x_sections.pro and dpr_and_geo_match_x_sections.pro
; for a detailed description of each keyword parameter.
;
;-------------------- this line not included in control file -----------------
;  ELEV2SHOW=3
;  SITE=*
;  NO_PROMPT=0
;  NCPATH=/data/gpmgv/netcdf/geo_match/TRMM/PR/V07/3_1
;  SWATH_CMB='NS'            ; dpr_and_geo_match_x_sections, DPRGMI only
;  KUKA_CMB='Ku'             ; dpr_and_geo_match_x_sections, DPRGMI only
;  PRPATH=/data/gpmgv/prsubsets
;  UFPATH='/data/gpmgv/gv_radar/finalQC_in'
;  FLATPATH=''
;  SHOW_ORIG=0
;  PCT_ABV_THRESH=0
;  DPR_Z_ADJUST=0.0         ; dpr_and_geo_match_x_sections only
;  GR_Z_ADJUST=''           ; dpr_and_geo_match_x_sections only
;  BBBYRAY=1
;  PLOTBBSEP=0
;  BBWIDTH=0.75
;  ALT_BB_HGT=''
;  HIDE_RNTYPE=0
;  CREF=0
;  PAUSE=1.0
;  ZOOMH=2
;  LABEL_BY_RAYNUM=0
;  RHI_MODE=0
;  RAY_MODE=0               ; dpr_and_geo_match_x_sections only
;  CAPPI_ANIM=0             ; dpr_and_geo_match_x_sections only
;  VERBOSE=0
;  RECALL_NCPATH=0
;  GIF_PATH=''
;  MATCHUP_TYPE='PR'
;  DECLUTTER=0           ; dpr_cmb_and_geo_match_x_sections, DPR only, for now
;-------------------- this line not included in control file -----------------
;
; Here's the summary of the pr_and_geo_match_x_sections calling sequence:
;
;   pr_and_geo_match_x_sections, ELEV2SHOW=elev2show, SITE=sitefilter, $
;                                NO_PROMPT=no_prompt, NCPATH=ncpath,   $
;                                PRPATH=prpath, UFPATH=ufpath, $
;                                SHOW_ORIG=show_orig, PCT_ABV_THRESH=pctAbvThresh, $
;                                BBBYRAY=BBbyRay, PLOTBBSEP=plotBBsep, $
;                                BBWIDTH=bbwidth, ALT_BB_HGT=alt_bb_hgt, $
;                                HIDE_RNTYPE=hide_rntype, CREF=cref, PAUSE=pause, $
;                                ZOOMH=zoomh, LABEL_BY_RAYNUM=label_by_raynum, $
;                                RHI_MODE=rhi_mode, VERBOSE=verbose, $
;                                GIF_PATH=gif_path, RECALL_NCPATH=recall_ncpath
;
; Here's the summary of the dpr_and_geo_match_x_sections calling sequence:
; 
;   dpr_and_geo_match_x_sections, ELEV2SHOW=elev2show, SITE=sitefilter, $
;                                 MATCHUP_TYPE=matchup_type, $
;                                 SWATH_CMB=swath_cmb, $
;                                 KUKA_CMB=KuKa_cmb, $
;                                 NO_PROMPT=no_prompt, NCPATH=ncpath, $
;                                 PRPATH=prpath, UFPATH=ufpath, FLATPATH=flatpath, $
;                                 SHOW_ORIG=show_orig, PCT_ABV_THRESH=pctAbvThresh, $
;                                 DPR_Z_ADJUST=dpr_z_adjust, GR_Z_ADJUST=gr_z_adjust, $
;                                 BBBYRAY=BBbyRay, PLOTBBSEP=plotBBsep, $
;                                 BBWIDTH=bbwidth, ALT_BB_HGT=alt_bb_hgt, $
;                                 HIDE_RNTYPE=hide_rntype, CREF=cref, PAUSE=pause, $
;                                 ZOOMH=zoomh, LABEL_BY_RAYNUM=label_by_raynum, $
;                                 RHI_MODE=rhi_mode, RAY_MODE=ray_mode_in, $
;                                 CAPPI_ANIM=cappi_anim, GIF_PATH=gif_path, $
;                                 DECLUTTER=declutter, VERBOSE=verbose, $
;                                 RECALL_NCPATH=recall_ncpath
;
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
; 01/21/11  Morris/GPM GV/SAIC
; - Add BBBYRAY keyword option to enable/disable plot of ray-specific BB height,
;   and VERSION_PR option to search for specific PR file patterns according to
;   the version of PR products used in the PR-GR matchup files being displayed.
; 01/20/12  Morris/GPM GV/SAIC
; - Remove VERSION_PR parameter from call sequences, as we use the PR-GR matchup
;   file metadata to obtain the version of PR products used.
; 02/07/12  Morris/GPM GV/SAIC
; - Added VERBOSE keyword to control cursor location selection information to be
;   printed or suppressed (default).
; 07/30/12  Morris/GPM GV/SAIC
; - Added PLOTBBSEP keyword to control plotting of delimiters of bright band
;   upper/lower bounds.
; - Added BBWIDTH keyword to override default half-width of the bright band
;   area of influence.
; 08/01/12  Morris/GPM GV/SAIC
; - Added HIDE_RNTYPE parameter to inhibit encoding of rain type (hash patterns)
;   in the PPI plots, and rain type color bars in the volume-match x-sections.
; 08/30/12  Morris/GPM GV/SAIC
; - Added PAUSE parameter to control dwell time between steps when automatically
;   displaying a sequence of cross sections for all scans in the matchup set.
; - Added CREF parameter to plot PPIs of Composite Reflectivity (highest
;   reflectivity in the vertical column) rather than for a fixed sweep elevation.
; 09/04/12  Morris/GPM GV/SAIC
; - Added ZOOMH parameter to explicitly control the width and location of how
;   the rays are plotted in the cross section window.  Valid values are 0, 1, 2.
; 09/07/12  Morris/GPM GV/SAIC
; - Added LABEL_BY_RAYNUM parameter to explicitly control the type of label
;   plotted at the endpoints of the cross section.
; - Added a PRINT message to the terminal asking user to select a control file.
; 09/13/12  Morris/GPM GV/SAIC
; - Changed keyword NO_2A25 to SKIP_2A25, still support NO_2A25 specification
;   in control files.
; 07/17/13  Morris/GPM GV/SAIC
; - Added DPR_OR_PR parameter to determine which top-level cross section program
;   to call.  Made it both a control file parameter and a positional parameter
;   so that it can be specified on the control line when not running the saved
;   version of cross_sections_driver().
; 02/23/15  Morris/GPM GV/SAIC
; - Modified default paths to start at /data/gpmgv rather than /data.
; 03/16/15  Morris/GPM GV/SAIC
; - Actually implemented the logic to apply DPR_OR_PR parameter to specify which
;   cross section routine to call.
; - Replaced keywords SKIP_2A25 and NO_2A25 with SHOW_ORIG to bring this routine
;   in line with dpr_and_geo_match_x_sections.pro and similarly modified version
;   of pr_and_geo_match_x_sections.pro.
; 04/01/15  Morris/GPM GV/SAIC
; - Added ALT_BB_HGT, RHI_MODE, GIF_PATH, and RECALL_NCPATH parameters to
;   support these new modes in the (d)pr_and_geo_match_x_sections procedures.
; 07/10/15  Morris/GPM GV/SAIC
; - Added option to call dprgmi_and_geo_match_x_sections procedure.  Added two
;   control parameters for this procedure: SWATH_CMB and KUKA_CMB.
; 07/16/15  Morris/GPM GV/SAIC
; - Added DECLUTTER parameter to support this new mode in the 
;   dpr_and_geo_match_x_sections procedure.
; 02/22/16  Morris/GPM GV/SAIC
; - Fixed PCT_ABV_THRESH argument in call to DPRGMI cross section procedure.
; 04/12/16  Morris/GPM GV/SAIC
; - Added RAY_MODE parameters to support this new mode in the
;   dpr[gmi]_and_geo_match_x_sections procedures.
; 05/27/16  Morris/GPM GV/SAIC
; - Added CAPPI_ANIM parameter to support this new mode in the animation loop
;   function.
; - Replaced call to dprgmi_and_geo_match_x_sections with call to modified
;   dpr_and_geo_match_x_sections procedure with DPRGMI capabilities merged in.
; 06/21/16  Morris/GPM GV/SAIC
; - Renamed DPR_OR_PR keyword, value, and related internal variables to
;   MATCHUP_TYPE for consistency with lower level routines.
; - Assigned same default value for BBWIDTH parameter as defined in utility
;   routines fprep_dpr_geo_match_profiles and fprep_dprgmi_geo_match_profiles.
; - Removed USE_DB parameter from all processing.
; - Removed MATCHUP_TYPE parameter from call to pr_and_geo_match_x_sections.
; 09/28/16 Morris, GPM GV, SAIC
; - Added FLATPATH=flatpath keyword/value pair to override parsing of the 2B
;   file basename to get version/subset/yyyy/mm/dd subdirectories, and instead
;   just use flatpath value in place of these subdirectory components. 
; 11/22/16 Morris, GPM GV, SAIC
; - Added DPR_Z_ADJUST=dpr_z_adjust and GR_Z_ADJUST=gr_z_adjust keyword/value
;   pairs to support DPR and site-specific GR bias adjustments.
; 9/28/17 Morris, GPM GV, SAIC
; - Added test to handle commented-out keyword/value lines in control files.
;
;
; EMAIL QUESTIONS OR COMMENTS AT:
;       https://pmm.nasa.gov/contact
;-
;===============================================================================


FUNCTION parse_xsect_parms, ctlstr, elev2show, sitefilter, no_prompt, ncpath, $
                            prpath, ufpath, flatpath, show_orig, pctAbvThresh, $
                            dpr_z_adjust, gr_z_adjust, $
                            BBbyray, plotBBsep, bbwidth, alt_bb_hgt, $
                            hide_rntype, cref, pause, zoomh, label_by_raynum, $
                            verbose, matchup_type, rhi_mode, ray_mode, cappi_anim, $
                            recall_ncpath, gif_path, swath_cmb, kuka_cmb, $
                            declutter

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
       'ELEV2SHOW' : elev2show=FIX(val)
            'SITE' : sitefilter=val
       'NO_PROMPT' : no_prompt=FIX(val)
          'NCPATH' : ncpath=val
          'PRPATH' : prpath=val
          'UFPATH' : ufpath=val
        'FLATPATH' : flatpath=val
       'SKIP_2A25' : message, LEVEL=-1, NOPREFIX=1, $
                    "SKIP_2A25 keyword no longer supported, please use SHOW_ORIG instead."
         'NO_2A25' : message, LEVEL=-1, NOPREFIX=1, $
                    "NO_2A25 keyword no longer supported, please use SHOW_ORIG instead."
       'SHOW_ORIG' : show_orig=FIX(val)    ; support GPM keyword in control file
  'PCT_ABV_THRESH' : pctAbvThresh=FIX(val)
    'DPR_Z_ADJUST' : dpr_z_adjust=FLOAT(val)
     'GR_Z_ADJUST' : gr_z_adjust=val
         'BBBYRAY' : BBbyRay=FIX(val)
       'PLOTBBSEP' : plotBBsep=FIX(val)
         'BBWIDTH' : bbwidth=FLOAT(val)
      'ALT_BB_HGT' : alt_bb_hgt=val        ; don't know the supplied type, leave as-is
     'HIDE_RNTYPE' : hide_rntype=FIX(val)
            'CREF' : cref=FIX(val)
           'PAUSE' : pause=FLOAT(val)
           'ZOOMH' : zoomh=FIX(val)
 'LABEL_BY_RAYNUM' : label_by_raynum=FIX(val)
         'VERBOSE' : verbose=FIX(val)
    'MATCHUP_TYPE' : matchup_type=val
        'RHI_MODE' : rhi_mode=FIX(val)
        'RAY_MODE' : ray_mode=FIX(val)
      'CAPPI_ANIM' : cappi_anim=FIX(val)
   'RECALL_NCPATH' : recall_ncpath=FIX(val)
        'GIF_PATH' : gif_path=val
       'SWATH_CMB' : swath_cmb=val
        'KUKA_CMB' : KuKa_cmb=val
       'DECLUTTER' : declutter=FIX(val)
     'IS_DISABLED' : print, "Ignoring disabled control file parameter: ", $
                            STRTRIM(ctlstr,2)
             ELSE  : status = 1
ENDCASE

badKeyVal:

return, status
end

;===============================================================================
   
pro cross_sections_driver, matchup_type_option

; assign default values except for ELEV2SHOW parameter, which will be computed
; by [pr|dpr]_and_geo_match_x_sections() if unset.

ncpath='/data/gpmgv/netcdf/geo_match/TRMM/PR/V07/3_1'
prpath='/data/gpmgv/prsubsets'
ufpath='/data/gpmgv/gv_radar/finalQC_in'
;flatpath=''          ; initialize as undefined
no_prompt=0
site=''
show_orig=0
pct_Abv_Thresh=0
;dpr_z_adjust=0.0     ; initialize as undefined
;gr_z_adjust=''       ; initialize as undefined
BBbyRay=0
plotBBsep=0
bbwidth=0.750         ; default as defined in fprep_dpr[gmi]_geo_match_profiles
;alt_bb_hgt=''        ; initialize as undefined
hide_rntype=0
cref=0
pause=1.0  ; seconds
zoomh=2    ; legacy behavior, full horizontal zoom each plotted scan
label_by_raynum=0    ; legacy behavior, mark endpoints with A and B
matchup_type_ctl='PR'
rhi_mode=0
ray_mode=0            ; not for pr_and_geo_match_x_sections
cappi_anim=0          ; not for pr_and_geo_match_x_sections
verbose=0
recall_ncpath=0
;gif_path=''          ; initialize as undefined
swath_cmb='NS'        ; dpr_and_geo_match_x_sections, DPRGMI case only
KuKa_cmb='Ku'         ; dpr_and_geo_match_x_sections, DPRGMI case only
declutter=0           ; dpr_and_geo_match_x_sections, DPR case only

; let the user select the desired control file

cd, CURRENT=cur_dir
filters = ['*.ctl']
print, ''
print, 'Select a cross-section control file from the file selector.'
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
                              prpath, ufpath, flatpath, show_orig, pct_Abv_Thresh, $
                              dpr_z_adjust, gr_z_adjust, $
                              BBbyray, plotBBsep, bbwidth, alt_bb_hgt, hide_rntype, $
                              cref, pause, zoomh, label_by_raynum, verbose, $
                              matchup_type_ctl, rhi_mode, ray_mode, cappi_anim, $
                              recall_ncpath, gif_path, swath_cmb, KuKa_cmb, $
                              declutter )

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
   help, NAMES='*'
   print, ''
ENDIF

; check value of matchup_type_ctl before proceeding
IF WHERE( ['PR','DPR','DPRGMI','CMB'] EQ STRUPCASE(matchup_type_ctl) ) EQ -1 THEN BEGIN
   message, "Illegal MATCHUP_TYPE assignment '"+STRUPCASE(matchup_type_ctl)+ $
            "' in control file, setting default value to 'PR'", /INFO
   matchup_type_ctl='PR'
ENDIF ELSE BEGIN
   matchup_type_ctl=STRUPCASE(matchup_type_ctl)
   IF matchup_type_ctl EQ 'CMB' THEN matchup_type_ctl='DPRGMI'  ; override CMB option
ENDELSE

; assign (1st) control file value, or (2nd) default matchup_type_option parameter
; value if value is not given on command line.  If given and if legal, command
; line value overrides control file and/or internal default value.
IF N_ELEMENTS( matchup_type_option ) EQ 0 THEN matchup_type=matchup_type_ctl ELSE BEGIN
   CASE STRUPCASE(matchup_type_option) OF
      'PR' : matchup_type = STRUPCASE(matchup_type_option)
     'DPR' : matchup_type = STRUPCASE(matchup_type_option)
  'DPRGMI' : matchup_type = STRUPCASE(matchup_type_option)
     'CMB' : matchup_type = 'DPRGMI'  ; override CMB option
      ELSE : BEGIN
                message, "Invalid matchup_type command line option: '" $
                         +matchup_type_option+"', setting to '" $
                         +matchup_type_ctl+"'", /INFO
                matchup_type = matchup_type_ctl
             END
    ENDCASE
ENDELSE

CASE matchup_type OF
    'PR' : BEGIN
              print, ''
              print, "Running TRMM PR matchup cases."
              IF KEYWORD_SET(ray_mode) AND (KEYWORD_SET(rhi_mode) EQ 0) THEN BEGIN
                 print, "Ignoring RAY_MODE for PR cross sections, do along scans."
                 ray_mode=0
              ENDIF
              print, ''
              pr_and_geo_match_x_sections, ELEV2SHOW=elev2show, SITE=sitefilter, $
                             NO_PROMPT=no_prompt, NCPATH=ncpath, $
                             PRPATH=prpath, UFPATH=ufpath, $
                             SHOW_ORIG=show_orig, PCT_ABV_THRESH=pct_Abv_Thresh, $
                             BBBYRAY=BBbyRay, PLOTBBSEP=plotBBsep, $
                             BBWIDTH=bbwidth, ALT_BB_HGT=alt_bb_hgt, $
                             HIDE_RNTYPE=hide_rntype, CREF=cref, PAUSE=pause, $
                             ZOOMH=zoomh, LABEL_BY_RAYNUM=label_by_raynum, $
                             RHI_MODE=rhi_mode, VERBOSE=verbose, $
                             GIF_PATH=gif_path, RECALL_NCPATH=recall_ncpath
           END
   'DPR' : BEGIN
              print, ''
              print, "Running GPM DPR matchup cases."
              print, ''
              dpr_and_geo_match_x_sections, ELEV2SHOW=elev2show, SITE=sitefilter, $
                             MATCHUP_TYPE=matchup_type, NO_PROMPT=no_prompt, $
                             NCPATH=ncpath, PRPATH=prpath, UFPATH=ufpath, FLATPATH=flatpath, $
                             SHOW_ORIG=show_orig, PCT_ABV_THRESH=pct_Abv_Thresh, $
                             DPR_Z_ADJUST=dpr_z_adjust, GR_Z_ADJUST=gr_z_adjust, $
                             BBBYRAY=BBbyRay, PLOTBBSEP=plotBBsep, $
                             BBWIDTH=bbwidth, ALT_BB_HGT=alt_bb_hgt, $
                             HIDE_RNTYPE=hide_rntype, CREF=cref, PAUSE=pause, $
                             ZOOMH=zoomh, LABEL_BY_RAYNUM=label_by_raynum, $
                             RHI_MODE=rhi_mode, RAY_MODE=ray_mode, $
                             CAPPI_ANIM=cappi_anim, VERBOSE=verbose, $
                             GIF_PATH=gif_path, DECLUTTER=declutter, $
                             RECALL_NCPATH=recall_ncpath
           END
   'DPRGMI' : BEGIN
              print, ''
              print, "Running GPM DPRGMI (CMB) matchup cases."
              print, ''
              dpr_and_geo_match_x_sections, ELEV2SHOW=elev2show, SITE=sitefilter, $
                              MATCHUP_TYPE=matchup_type, NO_PROMPT=no_prompt, $
                              NCPATH=ncpath, SWATH_CMB=swath_cmb, KUKA_CMB=KuKa_cmb, $
                              PRPATH=prpath, UFPATH=ufpath, FLATPATH=flatpath, $
                              SHOW_ORIG=show_orig, PCT_ABV_THRESH=pct_Abv_Thresh, $
                              BBBYRAY=BBbyRay, PLOTBBSEP=plotBBsep, $
                              DPR_Z_ADJUST=dpr_z_adjust, GR_Z_ADJUST=gr_z_adjust, $
                              BBWIDTH=bbwidth, ALT_BB_HGT=alt_bb_hgt, $
                              HIDE_RNTYPE=hide_rntype, CREF=cref, PAUSE=pause, $
                              ZOOMH=zoomh, LABEL_BY_RAYNUM=label_by_raynum, $
                              RHI_MODE=rhi_mode, RAY_MODE=ray_mode, $
                              CAPPI_ANIM=cappi_anim, VERBOSE=verbose, $
                              GIF_PATH=gif_path, RECALL_NCPATH=recall_ncpath
           END
    ELSE : message, 'Internal parameter check failure, quitting.'
ENDCASE

GOTO, skipMsg
userQuit:
print, "No control file selected, quitting program.  Bye!"
print, ''
skipMsg:
end
