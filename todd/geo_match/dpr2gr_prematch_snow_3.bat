;+
; Copyright © 2016, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; dpr2gr_prematch_snow_3.bat   15 February 2017
;
; DESCRIPTION
; -----------
; These are the modified dpr2gr_prematch configuration parameters using the
; DPR_DBZ_MIN threshold of 15 dBZ and the recently reprocessed ground radar
; files.  These two items are indicated in the output netCDF filenames by
; configuring NC_NAME_ADD (NC_NAME_ADD='15dbzGRDPR_newDm').  This file
; corresponds to a value of 2 for the PARAMETER_SET variable in the matchup
; script do_DPR2GR_GeoMatch.sh.
;
; 6/28/17 TAB: removed NC_NAME_ADD='15dbzGRDPR_newDm', this is now the default
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
;VERSION2MATCH='ITE109'
;VERSION2MATCH='V04A'
;VERSION2MATCH='V05A'
VERSION2MATCH='V06A'
VERSION2MATCH='V03B'
 gr_nc_version = '1_1'
 plot_PPIs = 0
 scores = 0
; nc_dir = ''
 flat_ncpath = 0
 nc_name_add = '15dbzGRDPR'
 dpr_dbz_min = 15.0
 dpr_rain_min = 0.01
 non_pps_files = 0
; non_pps_files = 1
 declutter = 1

.compile dpr2gr_prematch.pro
;restore, file='/home/tberendes/git/gpmgv/todd/geo_match/dpr2gr_prematch.sav'

dpr2gr_prematch_snow, control_file, GPM_ROOT=gpm_root, DIRDPR=dirdpr, $
   DIRKU=dirku, DIRKA=dirka, DIR_GV_NC=dir_gv_nc, $
   GR_NC_VERSION=gr_nc_version, VERSION2MATCH=version2match, $
   PLOT_PPIS=plot_PPIs, SCORES=scores, NC_DIR=nc_dir, FLAT_NCPATH=flat_ncpath, $
   NC_NAME_ADD=nc_name_add, DPR_DBZ_MIN=dpr_dbz_min, DPR_RAIN_MIN=dpr_rain_min, $
   NON_PPS_FILES=non_pps_files, DECLUTTER=declutter

;resolve_all
;save, /routines, file='/home/tberendes/git/gpmgv/todd/geo_match/dpr2gr_prematch.sav'
