;===============================================================================
;+
; Copyright © 2012, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; zr_coeff_kma.inc          Morris/SAIC/GPM_GV      August 2012
;
; DESCRIPTION
; -----------
; Defines A and B coefficients for the Z=A*R^B relationships for 3 rain types
; in an array of structures.  Values for A and B are as used in the joint
; KMA/GSFC GPM GV draft journal paper.
;
; HISTORY
; -------
; 8/22/2012 by Bob Morris, GPM GV (SAIC)
;  - Created.
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;===============================================================================

; "include" file for PR data constants (rain type categories)
@pr_params.inc

zrabdef = {zrabstruc, rtype:1, a:200.0, b:1.6}
zrabs3=REPLICATE( {zrabstruc}, 3 )
zrabs3[0].rtype = RainType_stratiform & zrabs3[0].a = 200.0 & zrabs3[0].b = 1.6
zrabs3[1].rtype = RainType_convective & zrabs3[1].a = 300.0 & zrabs3[1].b = 1.4
zrabs3[2].rtype = RainType_other      & zrabs3[2].a = 200.0 & zrabs3[2].b = 1.6
