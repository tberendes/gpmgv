;+
; Copyright © 2017, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; polar2dpr_prV8_0.bat   18 October 2017
;
; DESCRIPTION
; -----------
; These are the TRMM v8 polar2dpr configuration parameters using the PR
; DPR_DBZ_MIN threshold of 18 dBZ, the recently reprocessed ground radar
; files, and the GR blockage computation using blockage files.  This file
; corresponds to a value of 0 for the PARAMETER_SET variable in the
; matchup script do_PRv8_GeoMatch.sh.  Since this configuration is considered
; "baseline", there is no addition of an NC_NAME_ADD parameter value.
;
; EMAIL QUESTIONS OR COMMENTS AT:  https://pmm.nasa.gov/contact
;-

PRO_DIR = getenv("IDL_PRO_DIR")
cd, PRO_DIR
;cd , '..'

ITE_OR_OPERATIONAL = getenv("ITE_or_Operational")
; If environment variable has the value 'I' redirect to the emdata directory
; where test data files are located.  Otherwise, if value is unset or has the
; value 'V', leave GPM_ROOT pointed to the baseline gpmgv directory.

gpm_root='/data/gpmgv/orbit_subset'   ; for operational files
trmm_root='/data/gpmgv/orbit_subset'   ; for operational files
IF ITE_OR_OPERATIONAL NE 'V' THEN BEGIN
   gpm_root='/data/emdata/orbit_subset'
   trmm_root='/data/emdata/orbit_subset'
ENDIF
help, ITE_OR_OPERATIONAL, gpm_root, trmm_root

FILES4NC = GETENV("CONTROLFILE")
;restore, '/home/morris/swdev/idl/dev/geo_match/polar2dpr.sav'
.compile polar2dpr.pro
polar2dpr, FILES4NC, 100, SCORES=0, TRMM_ROOT=trmm_root, $
           DIRGV='/data/gpmgv/gv_radar/finalQC_in', PLOT_PPIS=1, $
           DBZ_MIN=18.0,  DPR_DBZ_MIN=15.0, DPR_RAIN_MIN=0.01, $
           NC_DIR='/tmp', DECLUTTER=1, $
           DIRPR='/.', DIRCMBPRTMI='/.', DIR_BLOCK='/data/gpmgv/blockage'

;resolve_all
;save, /routines, file='/home/morris/swdev/idl/dev/geo_match/polar2dpr.sav'
