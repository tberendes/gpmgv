;+
; Copyright © 2017, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; rhi2dpr_2.bat   15 February 2017
;
; DESCRIPTION
; -----------
; These are the modified rhi2dpr configuration parameters using the new
; DPR_DBZ_MIN threshold of 15 dBZ, and the recently reprocessed ground radar
; files.  These two items are indicated in the output netCDF filenames by
; configuring NC_NAME_ADD (NC_NAME_ADD='15dbzGRDPR_newDm').
; This file corresponds to a value of 2 for the PARAMETER_SET variable
; in the matchup scripts do_DPR_GeoMatchNPOL_MD_rules.sh and
; do_DPR_GeoMatchNPOLrules.sh.
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-

PRO_DIR = getenv("IDL_PRO_DIR")
cd, PRO_DIR
;cd , '..'

ITE_OR_OPERATIONAL = getenv("ITE_or_Operational")
; If environment variable has the value 'I' redirect to the emdata directory
; where test data files are located.  Otherwise, if value is unset or has the
; value 'V', leave GPM_ROOT pointed to the baseline gpmgv directory.

gpm_root='/data/gpmgv/orbit_subset'   ; for operational files
IF ITE_OR_OPERATIONAL EQ 'I' THEN gpm_root='/data/emdata/orbit_subset'
help, ITE_OR_OPERATIONAL, gpm_root

FILES4NC = GETENV("CONTROLFILE")
restore, './rhi2dpr.sav'
;.compile rhi2dpr.pro
rhi2dpr, FILES4NC, 100, SCORES=0, GPM_ROOT=gpm_root, DIRDPR='/.', $
   DIRKU='/.', DIRKA='/.', DIRGV='/data/gpmgv/gv_radar/finalQC_in', $
   DIRCOMB='/.', PLOT_RHIS=0 , NC_DIR='/data/gpmgv/netcdf/geo_match', $
   DBZ_MIN=15.0,  DPR_DBZ_MIN=15.0, DPR_RAIN_MIN=0.01, $
   NC_NAME_ADD='15dbzGRDPR_newDm_00_20'

;resolve_all
;save, /routines, file='./rhi2dpr.sav'
