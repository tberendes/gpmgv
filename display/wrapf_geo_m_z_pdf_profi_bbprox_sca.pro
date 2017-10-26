; wrapf_pr_and_geo_match_x_sections.pro
;
; DESCRIPTION
; -----------
; Reads a file containing a set of parameters needed to run the procedure
; geo_match_z_pdf_profile_ppi_bb_prox_sca, parses the options specified in
; the control file, and runs the procedure with the parameters specified, and
; with default values for the parameters not specified in the control file.
; Listed below are the allowed contents of the control file, and
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
; here's the geo_match_z_pdf_profile_ppi_bb_prox_sca calling sequence:
;
; geo_match_z_pdf_profile_ppi_bb_prox_sca, SPEED=looprate, $
;                                          ELEVS2SHOW=elevs2show, $
;                                          NCPATH=ncpath, $
;                                          SITE=sitefilter, $
;                                          NO_PROMPT=no_prompt, $
;                                          PPI_VERTICAL=ppi_vertical, $
;                                          PPI_SIZE=ppi_size, $
;                                          PCT_ABV_THRESH=pctAbvThresh, $
;                                          SHOW_THRESH_PPI=show_thresh_ppi, $
;                                          GV_CONVECTIVE=gv_convective, $
;                                          GV_STRATIFORM=gv_stratiform, $
;                                          HISTO_WIDTH=histo_Width, $
;                                          HIDE_TOTALS=hide_totals, $
;                                          PS_DIR=ps_dir


FUNCTION parse_pdf_sca_parms, ctlstr, looprate, elevs2show, ncpath, sitefilter, $
                              no_prompt, ppi_vertical, ppi_size, pctAbvThresh,  $
                              show_thresh_ppi, gv_convective, gv_stratiform,    $
                              histo_Width, hide_totals, ps_dir

status = 0
parsed = STRSPLIT(ctlstr, '=', /extract )
key = STRUPCASE(STRTRIM(parsed[0],2))
val = STRTRIM(parsed[1],2)
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
          'PS_DIR' : ps_dir=val
             ELSE  : status = 1
ENDCASE

return, status
end

;===============================================================================
   
pro wrapf_geo_m_z_pdf_profi_bbprox_sca

NCPATH='/data/netcdf/geo_match'
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

cd, CURRENT=cur_dir
filters = ['*.ctl']
ctlfile = dialog_pickfile(FILTER=filters, TITLE='Select control file to read', PATH='~')
OPENR, ctlunit, ctlfile, /GET_LUN, ERROR = err
if ( err ne 0 ) then message, 'Unable to open control file: ' + ctlfile

comma = ', '
optionstr = 'pr_and_geo_match_x_sections'
ctlstr = ''
fmt='(a0)'
while (eof(ctlunit) ne 1) DO BEGIN
  readf, ctlunit, ctlstr, format=fmt
  status = parse_pdf_sca_parms( ctlstr, looprate, elevs2show, ncpath, sitefilter, $
                                no_prompt, ppi_vertical, ppi_size, pctAbvThresh,  $
                                show_thresh_ppi, gv_convective, gv_stratiform,    $
                                histo_Width, hide_totals, ps_dir )

  if status NE 0 THEN print, 'Illegal parameter specification: ', ctlstr
endwhile

geo_match_z_pdf_profile_ppi_bb_prox_sca, SPEED=looprate, $
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
                                         PS_DIR=ps_dir
end
