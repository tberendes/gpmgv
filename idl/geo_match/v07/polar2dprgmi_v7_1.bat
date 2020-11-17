;+
; Copyright © 2014, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; polar2dprgmi_v7_1.bat
;
; DESCRIPTION
; -----------
; These are the modified polar2dprgmi configuration parameters using the new
; DPR_DBZ_MIN threshold of 15 dBZ, the non-default radius on influence defined
; in the code, and the GR blockage computation using blockage files.
;
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-


ITE_OR_OPERATIONAL = getenv("ITE_or_Operational")
; If environment variable has the value 'I' redirect to the emdata directory
; where test data files are located.  Otherwise, if value is unset or has the
; value 'V', leave GPM_ROOT pointed to the baseline gpmgv directory.

gpm_root='/data/gpmgv/orbit_subset'   ; for operational files
IF ITE_OR_OPERATIONAL EQ 'I' THEN gpm_root='/data/emdata/orbit_subset'
help, ITE_OR_OPERATIONAL, gpm_root

; nc_name_add = '15dBZ_7km'
FILES4NC = GETENV("CONTROLFILE")
;.compile polar2dprgmi_v6.pro
PRO_DIR = getenv("IDL_PRO_DIR")
cd, PRO_DIR
restore, './polar2dprgmi_v7.sav'

polar2dprgmi_v7, FILES4NC, 100, GPM_ROOT=gpm_root, DIRCOMB='/.', $
   DIRGV='/data/gpmgv/gv_radar/finalQC_in', NC_DIR='/data/gpmgv/netcdf/geo_match', $
   DIR_BLOCK='/data/gpmgv/blockage', plot_ppis=0, DPR_DBZ_MIN=15.0, DBZ_MIN=15.0, $
   NC_NAME_ADD=nc_name_add, use_dpr_roi=1

