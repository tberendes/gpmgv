PRO cos_and_tan_of_pr_angle, cos_inc_angle, tan_inc_angle, $
                             ALT_NUM_STEPS=alt_num_steps, ALT_INCREMENT=deltaIn

;+
; Copyright © 2008, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; cos_and_tan_of_pr_angle.pro      Morris/SAIC/GPM_GV      August 2008
;
; DESCRIPTION
; Computes COS and TAN of PR viewing angle away from nadir.  Assumes
; center ray of the PR scan is nadir-pointing.  Returns cos and tan
; values and number of PR rays in scan in variables supplied as arguments.
;
; HISTORY
; 8/14/07 - Morris/NASA/GSFC (SAIC), GPM GV:
;  - Created.
; 7/15/13 - Morris/NASA/GSFC (SAIC), GPM GV:
;  - Changed num_angles to an input keyword parameter ALT_NUM_STEPS to
;    accommodate DPR Ku and Ka scan mode (Normal, Merged, High-resolution)
;    differences.
;
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-

; "Include" file for PR-product-specific parameters (i.e., RAYSPERSCAN)
@pr_params.inc

IF N_ELEMENTS( alt_num_steps ) EQ 1 THEN num_angles = alt_num_steps $
ELSE num_angles = RAYSPERSCAN  ; legacy behavior
; legacy definition puts rays at approx. 0.71 deg. fixed increments
IF N_ELEMENTS( deltaIn ) EQ 1 THEN delta = deltaIn ELSE delta = 0.71

cos_inc_angle = FLTARR( num_angles )
tan_inc_angle = FLTARR( num_angles )
angle = FINDGEN( num_angles ) - (num_angles-1)/2.0
angle = delta*3.1415926D*(angle)/180. 

cos_inc_angle = COS(angle)
tan_inc_angle = TAN(angle)

end
