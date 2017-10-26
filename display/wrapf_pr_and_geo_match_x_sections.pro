; wrapf_pr_and_geo_match_x_sections.pro
;
; DESCRIPTION
; -----------
; Reads a file containing a set of parameters needed to run the procedure
; pr_and_geo_match_x_sections(), builds a string containing the name of the
; routine and its options as it would be specified on the IDL command line, and
; calls EXECUTE() to run the command (i.e., the pr_and_geo_match_x_sections
; procedure).  Listed below are the allowed contents of the control file, and
; the default values if the parameter(s) are not specified in the control file.
; The leading semicolons (;) are not present in the control file.
;
;-------------------- this line not included in control file -----------------
;  NCPATH=/data/netcdf/geo_match
;  PRPATH=/data/prsubsets
;  NO_PROMPT=1
;  SITE=KWAJ
;  USE_DB=0
;-------------------- this line not included in control file -----------------
;
; here's the summary of the pr_and_geo_match_x_sections calling sequence:
;
;   pr_and_geo_match_x_sections, ELEV2SHOW=elev2show, SITE=sitefilter, $
;                                NO_PROMPT=no_prompt, NCPATH=ncpath,   $
;                                PRPATH=prpath, UFPATH=ufpath, USE_DB=use_db, $
;                                NO_2A25=no_2a25, PCT_ABV_THRESH=pctAbvThresh
;


FUNCTION parse_xsect_parms, ctlstr, elev2show, sitefilter, no_prompt, ncpath, $
                            prpath, ufpath, use_db, no_2a25, pctAbvThresh

status = 0
parsed = STRSPLIT(ctlstr, '=', /extract )
key = STRUPCASE(STRTRIM(parsed[0],2))
val = STRTRIM(parsed[1],2)
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

return, status
end

;===============================================================================
   
pro wrapf_pr_and_geo_match_x_sections

NCPATH='/data/netcdf/geo_match'
PRPATH='/data/prsubsets'
UFPATH='/data/gv_radar/finalQC_in'
NO_PROMPT=0
SITE=''
USE_DB=0
NO_2A25=1
PCT_ABV_THRESH=0

cd, CURRENT=cur_dir
filters = ['*.ctl']
ctlfile = dialog_pickfile(FILTER=filters, TITLE='Select control file to read', PATH='~')
;ctlfile = '~/xsections.ctl'
OPENR, ctlunit, ctlfile, /GET_LUN, ERROR = err
if ( err ne 0 ) then message, 'Unable to open control file: ' + ctlfile

comma = ', '
optionstr = 'pr_and_geo_match_x_sections'
ctlstr = ''
fmt='(a0)'
while (eof(ctlunit) ne 1) DO BEGIN
  readf, ctlunit, ctlstr, format=fmt
  status = parse_xsect_parms( ctlstr, elev2show, sitefilter, no_prompt, ncpath, $
                              prpath, ufpath, use_db, no_2a25, pct_Abv_Thresh)
  if status NE 0 THEN print, 'Illegal parameter specification: ', ctlstr
endwhile
print, 'Options: ', optionstr

pr_and_geo_match_x_sections, ELEV2SHOW=elev2show, SITE=sitefilter, $
                             NO_PROMPT=no_prompt, NCPATH=ncpath,   $
                             PRPATH=prpath, UFPATH=ufpath, USE_DB=use_db, $
                             NO_2A25=no_2a25, PCT_ABV_THRESH=pct_Abv_Thresh
end
