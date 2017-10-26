;+
; Copyright © 2017, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; polar2dpr_2.bat   15 February 2017
;
; DESCRIPTION
; -----------
; These are the modified polar2dpr configuration parameters using the new
; DPR_DBZ_MIN threshold of 15 dBZ, the recently reprocessed ground radar
; files, and the GR blockage computation using blockage files.  Since this
; configuration is considered "baseline" now, there is no addition of an
; NC_NAME_ADD parameter value.
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
exit

FILES4NC = GETENV("CONTROLFILE")
restore, '/home/morris/swdev/idl/dev/geo_match/polar2dpr.sav'
;.compile polar2dpr.pro
polar2dpr, FILES4NC, 100, SCORES=0, GPM_ROOT=gpm_root, $
           DIRGV='/data/gpmgv/gv_radar/finalQC_in', PLOT_PPIS=0, $
           DBZ_MIN=15.0,  DPR_DBZ_MIN=15.0, DPR_RAIN_MIN=0.01, $
           NC_DIR='/data/gpmgv/netcdf/geo_match', DECLUTTER=1, $
           DIRDPR='/.', DIRKU='/.', DIRKA='/.', DIRCOMB='/.', DIR_BLOCK='/data/gpmgv/blockage'

;resolve_all
;save, /routines, file='/home/morris/swdev/idl/dev/geo_match/polar2dpr.sav'
