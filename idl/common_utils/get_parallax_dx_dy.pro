PRO get_parallax_dx_dy, height, ray_num, RAYSPERSCAN, $
                        mscan, dysign, tan_inc_angle, dx, dy, $
                        DO_PRINT = do_print

;=============================================================================
;+
; Copyright © 2008, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; get_parallax_dx_dy.pro      Morris/SAIC/GPM_GV      August 2008
;
; DESCRIPTION
; -----------
; Compute parallax offset for a PR ray at a given height and scan angle, as
; a dX and dY value pair in a N-S aligned Cartesian coordinate system.
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

    IF N_ELEMENTS( do_print ) EQ 0 THEN do_print = 0  ; default to no print

;   Compute dR = total offset towards nadir point, for given height and angle
    dR = HEIGHT * tan_inc_angle[ray_num]
    sign_dRdH = 1  ; positive if dR is in along-sweep direction as h increases
    if ( ray_num gt (RAYSPERSCAN-1)/2 ) then sign_dRdH = -1

;   Use dR^2 = dX^2 + dY^2, dX = mscan*dY; solve for dY.  Account for signs.
    dY = SQRT( dR^2/(mscan^2 +1) ) * dysign * sign_dRdH
    dX = mscan * dY

    if (do_print eq 1 ) then begin
        do_print = 0
        print, "height,dR,sign_dR,dY,dX = ", height,dR,sign_dRdH,dY,dX
    endif

end
