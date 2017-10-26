FUNCTION get_sweep_elevs, z_vol_num, radar, elev_angle

;=============================================================================
;+
; Copyright © 2008, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; get_sweep_elevs.pro      Morris/SAIC/GPM_GV      August 2008
;
; DESCRIPTION
; -----------
; Retrieves the number of sweeps (elevation tilts) and their elevation
; angles from a 'radar' structure of the TRMM Radar Software Library.
; Returns the number of sweeps as the function return value, and returns
; the list of elevation angles in the elev_angle parameter.
;
; HISTORY
; -------
; 8/21/08 - Morris/NASA/GSFC (SAIC), GPM GV:  Created.
;
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;=============================================================================

nelevs = radar.volume[z_vol_num].h.nsweeps
all_elev = radar.volume[z_vol_num].sweep.h.elev
elev_angle = all_elev[0:nelevs-1]

RETURN, nelevs
END
