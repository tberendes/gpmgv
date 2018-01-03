;+
; Copyright © 2016, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; dpr2gr_prematch.bat
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-

PRO_DIR = getenv("IDL_PRO_DIR")
cd, PRO_DIR

 control_file = GETENV("CONTROLFILE")

 ITE_OR_OPERATIONAL = getenv("ITE_or_Operational")
; If environment variable has the value 'I' redirect to the emdata directory
; where test data files are located.  Otherwise, if value is unset or has the
; value 'V', leave GPM_ROOT pointed to the baseline gpmgv directory.

 gpm_root='/data/gpmgv/orbit_subset'   ; for operational files
 IF ITE_OR_OPERATIONAL EQ 'I' THEN gpm_root='/data/emdata/orbit_subset'
 help, ITE_OR_OPERATIONAL, gpm_root

 dirdpr = '/.'
 dirku = '/.'
 dirka = '/.'
; dir_gv_nc = ''
 gr_nc_version = '1_0'
 plot_PPIs = 0
 scores = 0
; nc_dir = ''
 flat_ncpath = 0
 nc_name_add = '15dbzGRDPR_newDm'
 dpr_dbz_min = 15.0
 dpr_rain_min = 0.01
 non_pps_files = 0
 declutter = 1

;.compile dpr2gr_prematch.pro
restore, file='/home/morris/swdev/idl/dev/geo_match/dpr2gr_prematch.sav'

dpr2gr_prematch, control_file, GPM_ROOT=gpm_root, DIRDPR=dirdpr, $
   DIRKU=dirku, DIRKA=dirka, DIR_GV_NC=dir_gv_nc, GR_NC_VERSION=gr_nc_version, $
   PLOT_PPIS=plot_PPIs, SCORES=scores, NC_DIR=nc_dir, FLAT_NCPATH=flat_ncpath, $
   NC_NAME_ADD=nc_name_add, DPR_DBZ_MIN=dpr_dbz_min, DPR_RAIN_MIN=dpr_rain_min, $
   NON_PPS_FILES=non_pps_files, DECLUTTER=declutter

;resolve_all
;save, /routines, file='/home/morris/swdev/idl/dev/geo_match/dpr2gr_prematch.sav'
