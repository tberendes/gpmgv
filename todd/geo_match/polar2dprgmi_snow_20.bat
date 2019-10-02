;+
; Copyright © 2014, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; polar2dprgmi_snow_20.bat
;
; DESCRIPTION
; -----------
; These are the modified polar2dprgmi configuration parameters using the new
; DPR_DBZ_MIN threshold of 12 dBZ, the non-default radius on influence defined
; in the code, and the GR blockage computation using blockage files.
;
; this is a special case for dual radar matchups
; using a 20 in 100 threshold for convective cases
; we need to use rainCases20in100kmAddNewEvents.sql in the main script
;
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-

PRO_DIR = getenv("IDL_PRO_DIR")
cd, PRO_DIR
cd , '..'
;DATESTAMP = GETENV("RUNDATE")

ITE_OR_OPERATIONAL = getenv("ITE_or_Operational")
; If environment variable has the value 'I' redirect to the emdata directory
; where test data files are located.  Otherwise, if value is unset or has the
; value 'V', leave GPM_ROOT pointed to the baseline gpmgv directory.

gpm_root='/data/gpmgv/orbit_subset'   ; for operational files
IF ITE_OR_OPERATIONAL EQ 'I' THEN gpm_root='/data/emdata/orbit_subset'
help, ITE_OR_OPERATIONAL, gpm_root

FILES4NC = GETENV("CONTROLFILE")
.compile polar2dprgmi_snow.pro
;restore, './polar2dprgmi_snow.sav'

polar2dprgmi_snow, FILES4NC, 100, GPM_ROOT=gpm_root, DIRCOMB='/.', $
   DIRGV='/data/gpmgv/gv_radar/finalQC_in', NC_DIR='/data/gpmgv/netcdf/geo_match', $
   DIR_BLOCK='/data/gpmgv/blockage', plot_ppis=0, DPR_DBZ_MIN=15.0, DBZ_MIN=15.0, $
   NC_NAME_ADD='15dBZ_20rainy_7km', use_dpr_roi=1

