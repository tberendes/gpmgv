;+
; Copyright © 2013, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; dpr_gate_num_for_height.pro      Morris/SAIC/GPM_GV      June 2013
;
; DESCRIPTION:
; Computes product-specific gate number(s) at a given height above the earth's
; ellipsoid, for a given DPR product scan and ray number, for the given scan
; type (HS, MS, NS).
;
; HISTORY
; 6/21/13 - Morris/NASA/GSFC (SAIC), GPM GV
;  - Created from gate_num_for_height.pro.
; 01/04/16 - Morris/NASA/GSFC (SAIC), GPM GV
;  - Now indexing cos_inc_angle by both ray_num and scan_num, rather than just
;    by ray_num, since GPM gives localZenithAngle values for each ray in every
;    scan, and cos_inc_angle is derived from localZenithAngle.  Before this we
;    had been applying the first scan cos_inc_angle values to every scan in the
;    matchup area.  Probably (hopefully) no practical difference in the results.
;
; INPUTS:
;   height_msl     - height above earth ellipsoid for which to compute gate
;                    number.
;   dpr_gate_space - DPR gate spacing in meters (usual case) or km
;   cos_inc_angle  - 2-D array of cosines of angle between nadir and the
;                    DPR ray, for each ray angle in each scan
;   ray_num        - DPR ray number for which gate numbers are being computed
;   scan_num       - DPR-product-relative scan number for which gate numbers
;                    for specified height are being computed
;   binRealSurface - The 2-D array of DPR at-surface bin number for the
;                    DPR, Ka, or Ku product, in (ray,scan) coordinates.  Value
;                    decreases with increasing height above surface.
;
; OUTPUTS:
;   gate_num - Gate number at height=height_msl, for the given dpr_gate_space, 
;              scan number, and ray number.
;
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-


FUNCTION dpr_gate_num_for_height, height_msl, dpr_gate_space, cos_inc_angle,  $
                                  ray_num, scan_num, binRealSurface

IF ( dpr_gate_space GT 10 ) THEN BEGIN
   gates_per_km = 1000. / dpr_gate_space   ; meters assumed for dpr_gate_space
ENDIF ELSE BEGIN
   gates_per_km = 1. / dpr_gate_space      ; km assumed for dpr_gate_space
ENDELSE

;  slant range to HEIGHT_MSL, in gates, for computed gates_per_km:
   rip = ( gates_per_km * height_msl ) / cos_inc_angle[ray_num,scan_num]
;  slant range to height_msl in whole gates, from surface:
   ip = fix(rip+0.5)  

;  binRealSurface is surface gate for 3-D dbz and rainrate, and gate#
;  decreases with increasing height.  Compute product-relative gate # at
;  our height, guarding against negative gate index numbers.  Note that
;  binRealSurface is 1-based index, where we want the IDL zero-based array
;  index value

      gate_num = 0 > (binRealSurface[ray_num,scan_num] -1 - ip)

return, gate_num
END
