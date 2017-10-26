PRO gate_num_for_height, height_agl, pr_gate_space, cos_inc_angle,  $
                         ray_num, scan_num, binS, rayStart,         $
                         GATE1C21=gate_1c21, GATE2A25=gate_2a25

;+
; Copyright © 2008, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; gate_num_for_height.pro      Morris/SAIC/GPM_GV      September 2008
;
; DESCRIPTION:
; Computes product-specific gate number(s) at a given height above the earth's
; surface, for a given PR product scan and ray number, for either/both the
; TRMM PR 1C-21 product or the 2A-25 product.
;
; HISTORY
; 9/3/07 - Morris/NASA/GSFC (SAIC), GPM GV:  Created.
; 6/9/10 - Morris/NASA/GSFC (SAIC), GPM GV:  Fixed 1-gate offset of 1C21.
;
; INPUTS:
;   height_agl (Required) - height above earth sfc for which to compute gate #s
;   pr_gate_space (Required) - PR gate spacing in meters (usual case) or km
;   cos_inc_angle (Required) - array of cosines of angle between nadir and the
;                              PR ray, for each ray angle
;   ray_num (Required) - PR ray number for which gate numbers are being computed
;   scan_num (Required for 1C21) - PR-product-relative scan number for variables
;                                  in (scan,ray) coordinates
;   binS (Required for 1C21) - The 2-D array of PR at-surface bin number for the
;                              1C21 product, in (scan,ray) coordinates
;   rayStart (Required for 1C21) - See below in body of procedure.
;
; INPUT/OUTPUTS:
;   gate_1c21 (Required for 1C21) - 1C21 Gate number at height=height_agl, for
;                                   the given scan and ray number.
;   gate_2a25 (Required for 2A25) - 2A25 Gate number at height=height_agl, for
;                                   the given ray number.
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-


IF ( pr_gate_space GT 10 ) THEN BEGIN
   gates_per_km = 1000. / pr_gate_space   ; meters assumed for pr_gate_space
ENDIF ELSE BEGIN
   gates_per_km = 1. / pr_gate_space      ; km assumed for pr_gate_space
ENDELSE

;  slant range to HEIGHT_AGL, in gates, for computed gates_per_km:
   rip = ( gates_per_km * height_agl ) / cos_inc_angle[ray_num]
;  slant range to height_agl in whole gates, from surface:
   ip = fix(rip+0.5)  

;------------------------------------------------------------------------------
; rayStart description, for 1C-21 data:
; Location, in 1/8km bins, of start of data (1/4km Gate 1 location at TOA) for 
; a given angle index (0-48).  Bin1 is always defined to be at a fixed distance
; from satellite.  Needed to relate binS (bin # of surface ellipsoid) to
; distance-from-surface-in-gates of a dBZ sample at a given height.
; That is, Bin 1 is at a fixed distance from the satellite; Gate 1 is at an
; approximately fixed altitude (23km) above earth; Gate1 and Bin1 line up at
; nadir scan, and for other scan angles, Gate1 moves down along the beam in a
; fixed manner to the Bin position defined by rayStart.  The bin number where
; the ray intersects the earth's surface (binS, Bin Ellipsoid in 1C-21) varies
; for each ray.  Thus, for a ray at product location [scan, angle], the gate
; number at the surface, gateS, is given by the relation:
;
;     gateS[scan, angle] = 1 + ( binS[scan, angle] - rayStart[angle] ) / 2
;
; For 2A-25, the surface gate #, gateN, is fixed at gate 80.
;
; The ZERO-BASED surface gate numbers for the IDL array convention are 1 less
; than these numbers.
;------------------------------------------------------------------------------

IF ( N_ELEMENTS(gate_2a25) GT 0 ) THEN BEGIN
;     2A25 gate #80 is surface gate for corrected dbz and rainrate, and gate#
;     decreases with increasing height.  Compute product-relative gate # at
;     our height, guarding against negative gate index numbers.  Note that
;     gate 80 has the zero-based array index value of 79:
      gate_2a25 = 0 > (79 - ip)
ENDIF


IF ( N_ELEMENTS(gate_1c21) GT 0 ) THEN BEGIN
;     1C21 gate number at surface is dependent on ray-specific bin ellipsoid
;     value, binS[].  Compute ZERO-BASED (IDL) product-relative gate # at our
;     height for 1C21, guarding against negative gate index numbers:
      gate_1c21 = 0 > ( (binS[scan_num,ray_num]-rayStart[ray_num])/2 - ip )
ENDIF

END
