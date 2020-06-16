;+
; Copyright © 2008, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
;-------------------------------------------------------------------------------
;
; environs.inc    Bob Morris, GPM GV (SAIC)    March 2007
;
; DESCRIPTION
; -------------
; Defines file/path parameters for GPM GV Validation Network PR/GR data matchup
; and analysis routines in IDL.
;
; 11/16/2007  Morris           Changed PR grid version to 1.2 for addition of
;                              2-D grid for Ray Index (PR scan angle).  Added
;                              this file prologue.
; 09/17/2008  Morris           Added parameters GEO_MATCH_NCDIR, GEO_MATCH_PRE,
;                              and GEO_MATCH_NC_FILE_VERS for polar2pr program.
; 09/13/2010  Morris           Changed GEO_MATCH_NC_FILE_VERS value to 1.1 to
;                              reflect new netCDF file variable site_elev, and
;                              changes to some long_name descriptions.
; 11/11/2010  Morris           Added parameters DIR_2A23 and DIR_2A12
; 05/06/2011  Morris           Added parameter TMI_GEO_MATCH_PRE
; 11/27/2012  Morris           Added PR_TMI_MATCH_NCDIR, PR_TMI_MATCH_PRE
; 06/26/2013  Morris           Added DPR_GEO_MATCH_PRE, DPR_GMI_MATCH_PRE
; 01/15/2014  Morris         - Added GMI_GEO_MATCH_PRE
; 03/25/2014  Morris         - Modified GMI_GEO_MATCH_PRE value, modified
;                              absolute path values to reflect /data/gpmgv as
;                              the common data root directory as on ds1-gpmgv
;                            - Added SUBSETS_ROOT as the root dir for GPM-era
;                              orbit subset products
; 04/04/2014  Morris         - Added GPMDATA_ROOT, DIR_2AGPROF, DIR_2ADPR,
;                              DIR_2AKU, DIR_2AKA, DIR_COMB for GPM products
; 05/14/2014  Morris         - Added parameter COMB_GEO_MATCH_PRE
; 09/22/2014  Morris         - Added parameter DPR_GMI_MATCH_NCDIR
; 03/07/2016  Morris         - Added parameter GR_DPR_GEO_MATCH_PRE
; 03/24/2016  Morris         - Added parameter GR_DPR_GEO_MATCH_NCDIR
; 10/18/2017  Morris         - Added parameters TRMMDATA_ROOT, DIR_2APR, and
;                              DIR_2BPRTMI for TRMM Version 8 support
;
;-------------------------------------------------------------------------------
;
; EMAIL QUESTIONS OR COMMENTS AT:
;       https://pmm.nasa.gov/contact
;-


; project/user/host-specific data directory and file naming parameters

; input file definitions
TMP_DIR      = '/data/gpmgv/tmp'        ; I/O control & scratch files located here
NCGRIDS_ROOT = '/data/gpmgv/netcdf'     ; top level dir for output netCDF data files
PRDATA_ROOT  = '/data/gpmgv/prsubsets'  ; top level dir for PR data files
SUBSETS_ROOT = '/data/gpmgv/orbit_subset'  ; top level dir for GPM-era orbit subset products
GPMDATA_ROOT = SUBSETS_ROOT+'/GPM'      ; top level dir for GPM-specific subset products
TRMMDATA_ROOT = SUBSETS_ROOT+'/TRMM'    ; top level dir for version 8 TMMM subset products
DIR_1C21     = '/1C21'
DIR_2A12     = '/2A12'
DIR_2A23     = '/2A23'
DIR_2A25     = '/2A25'
DIR_2B31     = '/2B31'
DIR_2APR     = '/PR/2APR'
DIR_2BPRTMI  = '/PRTMI/2BPRTMI'
DIR_2AGPROF  = '/2AGPROF'  ; leave off instrument prefixes, which vary by satellite
DIR_2ADPR    = '/DPR/2ADPR'
DIR_2AKU     = '/Ku/2AKu'
DIR_2AKA     = '/Ka/2AKa'
DIR_COMB     = '/DPRGMI/2BDPRGMI'
GVDATA_ROOT  = '/data/gpmgv/gv_radar/finalQC_in'  ; top level dir for GV radar data
LOG_DIR      = '/data/gpmgv/logs'

; output file definitions
NC_FILE_EXT  = '.nc'         ; in-common file extension for netCDF files
PR_NCGRIDDIR = '/PR'         ; subdir for output PR netCDF grid files
PR_NCGRIDPRE = '/PRgrids.'   ; file prefix for PR netCDF grid files
GV_NCGRIDDIR = '/NEXRAD'     ; subdir for output GV radar netCDF grid files
GV_NCGRIDPRE = '/GVgrids.'   ; file prefix for GV radar netCDF grid files
GEO_MATCH_NCDIR = '/geo_match'  ; subdir for output polar2pr netCDF files
GEO_MATCH_PRE = 'GRtoPR.'
TMI_GEO_MATCH_PRE = 'GRtoTMI.'
GMI_GEO_MATCH_PRE = 'GRtoGPROF.'
PR_TMI_MATCH_NCDIR = '/pr_tmi_match'  ; subdir for output pr2tmi netCDF files
PR_TMI_MATCH_PRE = 'PRtoTMI.'
DPR_GEO_MATCH_PRE = 'GRtoDPR.'
DPR_GMI_MATCH_PRE = 'DPRtoGMI.'
DPR_GMI_MATCH_NCDIR = '/dpr_gmi_match'  ; subdir for output dpr2gmi netCDF files
COMB_GEO_MATCH_PRE = 'GRtoDPRGMI.'
GR_DPR_GEO_MATCH_PRE = 'GRtoDPR_HS_MS_NS.'
GR_DPR_GEO_MATCH_NCDIR = '/grmatch'  ; subdir for polar2dpr_hs_ms_ns netCDF files

; netCDF template files internal/temporary
PR_NCGRIDTEMPLATE = TMP_DIR + '/templatePRgrids' + NC_FILE_EXT
GV_NCGRIDTEMPLATE = TMP_DIR + '/templateGVgrids' + NC_FILE_EXT

; program/outfile version definitions
PR_NC_FILE_VERS = 1.2      ; version of output PR netCDF grid files
GV_NC_FILE_VERS = 1.1      ; version of output GV netCDF grid files
GEO_MATCH_NC_FILE_VERS = 1.1      ; version of output Geo_Match netCDF files
