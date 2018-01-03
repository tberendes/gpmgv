;+
; Copyright © 2017, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; polar2dprAllPts_99.bat   15 February 2017
;
; DESCRIPTION
; -----------
; These are the configuration parameters for polar2dpr_all, the special version
; of polar2dpr that does matchups at all locations regardless of the presence
; of reflectivity above a threshold.  This setup uses a threshold of 5 dBZ for
; both DBZ_MIN and DPR_DBZ_MIN, the recently reprocessed ground radar
; files, and the GR blockage computation using blockage files.  The special
; setup is indicated in the output netCDF filenames by configuring NC_NAME_ADD
; (NC_NAME_ADD='AllRays').  All output netCDF files are written to a single
; directory location, /data/gpmgv/xfer/PAIH_Duncan_matchups.  This file
; corresponds to a value of 99 for the PARAMETER_SET variable in the matchup
; script do_DPR_GeoMatch_PAIH_AllPts.sh.
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
restore, '/home/morris/swdev/idl/dev/geo_match/polar2dpr_all.sav'
;.compile polar2dpr_all.pro
polar2dpr_all, FILES4NC, 100, SCORES=0, GPM_ROOT=gpm_root, $
           DIRGV='/data/gpmgv/gv_radar/finalQC_in', PLOT_PPIS=0, $
           DBZ_MIN=5.0,  DPR_DBZ_MIN=5.0, DPR_RAIN_MIN=0.01, NC_NAME_ADD='AllRays', $
           NC_DIR='/data/gpmgv/xfer/PAIH_Duncan_matchups', FLAT_NCPATH=1, DECLUTTER=1, $
           DIRDPR='/.', DIRKU='/.', DIRKA='/.', DIRCOMB='/.', DIR_BLOCK='/data/gpmgv/blockage'

;resolve_all
;save, /routines, file='/home/morris/swdev/idl/dev/geo_match/polar2dpr_all.sav'
