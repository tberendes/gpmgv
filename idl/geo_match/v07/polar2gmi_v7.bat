;+
; Copyright © 2011, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       https://pmm.nasa.gov/contact
;-

PRO_DIR = getenv("IDL_PRO_DIR")
cd, PRO_DIR

ITE_OR_OPERATIONAL = getenv("ITE_or_Operational")
; If environment variable has the value 'I' redirect to the emdata directory
; where test data files are located.  Otherwise, if value is unset or has the
; value 'V', leave GPM_ROOT pointed to the baseline gpmgv directory.

gpm_root='/data/gpmgv/orbit_subset'   ; for operational files
IF ITE_OR_OPERATIONAL EQ 'I' THEN gpm_root='/data/emdata/orbit_subset'
help, ITE_OR_OPERATIONAL, gpm_root
;exit    ; uncomment if only testing ITE_OR_OPERATIONAL, gpm_root assignments

;DATESTAMP = GETENV("RUNDATE")
FILES4NC = GETENV("CONTROLFILE")
;.compile polar2gmi_v7.pro
; TAB change this line......
restore, './polar2gmi_v7.sav'

polar2gmi_v7, FILES4NC, 125, GPM_ROOT=gpm_root, DIRGV='/data/gpmgv/gv_radar/finalQC_in', NC_DIR='/data/gpmgv/netcdf/geo_match', plot_ppi=0 , DIR_BLOCK='/data/gpmgv/blockage'

;resolve_all
;save, /routines, file='/home/gvoper/idl/geo_match/polar2gmi_v7.sav'
