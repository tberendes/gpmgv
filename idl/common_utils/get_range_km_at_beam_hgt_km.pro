FUNCTION get_range_km_at_beam_hgt_km, elev_angle_deg, height_km

;=============================================================================
;+
; Copyright © 2008, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; get_range_km_at_beam_hgt_km.pro      Morris/SAIC/GPM_GV      August 2008
;
; DESCRIPTION
; -----------
; Computes range at which a radar beam pointing at a given elevation angle
; (elev_angle_deg) is centered at the given height (height_km), assuming
; standard refraction.  Given the equation for beam height H at a slant range
; SR and elevation angle PHI:
;
;    H = SR*sin PHI + (SR*SR)/(2*IR*RE), where IR = 1.21
;
; we solve for SR via the quadratic formula:
;
;    SR=( -sin(PHI)*2.42*RE +/- SQRT((sin(PHI)*2.42*RE)^2 -4(-2.42*RE*H)) )/2
;
; and taking the positive result.
;
; HISTORY
; -------
; 8/14/07 - Morris/NASA/GSFC (SAIC), GPM GV:  Created.
;
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;=============================================================================


RE = 6371.0D         ; radius of spherical earth, km
TWOIR = 2.42D        ; 2 times the refractive index, 1.21

sinPHI = SIN( 3.1415926D*(elev_angle_deg)/180. )
RFAC = RE * TWOIR

SR = (-sinPHI*RFAC + SQRT( (sinPHI*RFAC)^2 + 4.0*RFAC*height_km ) ) / 2.

return, SR

end
