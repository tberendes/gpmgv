PRO get_tmi_parallax_dx_dy, height, siteElev, scan, ray, smap, elev_angle, $
                            tmiLats, tmiLons, scLats, scLons, dx, dy, $
                            DO_PRINT = do_print

;=============================================================================
;+
; Copyright © 2011, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; get_tmi_parallax_dx_dy.pro      Morris/SAIC/GPM_GV      May 2011
;
; DESCRIPTION
; -----------
; Compute parallax offset for a TMI ray at a given height and fixed incident
; angle, as a dX and dY value pair in a N-S aligned Cartesian coordinate system.
; Makes a 2nd pass through the calculations, 1st using the GR beam height at the
; range of the TMI footprint surface intersection, then the height at the range
; of the first parallax-adjusted TMI/GR intersection.
;
; HISTORY
; -------
; 5/5/2011 - Morris/NASA/GSFC (SAIC), GPM GV:  Created.
;
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;=============================================================================

;   "Include" file for TMI-product-specific parameters (TAN_TMI_INCIDENT_ANGLE):
    @tmi_params.inc

    IF N_ELEMENTS( do_print ) EQ 0 THEN do_print = 0  ; default to no print

;   Compute dR = total offset towards nadir point, for given height and the
;   fixed TMI incident angle
    dR = (height + siteElev) * TAN_TMI_INCIDENT_ANGLE

;   Compute x and y of TMI footprint and TRMM subpoint
    xy_tmi = [0.0d,0.0d] & xy_trmm = xy_tmi
    xy_tmi = map_proj_forward( tmiLons[ray,scan], $
                               tmiLats[ray,scan], $
                               map_structure=smap ) / 1000.
    xy_trmm = map_proj_forward( scLons[scan], $
                                scLats[scan], $
                                map_structure=smap ) / 1000.
    tmi_x = XY_tmi[0]
    tmi_y = XY_tmi[1]
    trmm_x = xy_trmm[0]
    trmm_y = xy_trmm[1]
;   compute angle of the footprint-subpoint line (i.e., of dR displacement):
    az_fp2sp = ATAN( trmm_y-tmi_y, trmm_x-tmi_x )
;   compute TMI footprint dx and dy offsets and new precise range to
;   footprint subpoint, given current GR beam height
    dX = COS(az_fp2sp)*dR
    dY = SIN(az_fp2sp)*dR

    if (do_print eq 1 ) then begin
        print, ""
        print, "In get_tmi_parallax_dx_dy():"
        print, FORMAT='("  First height, dR, dX, dY, angle = ", 4(F0.4,", "), F0.4)', $
               height+siteElev, dR, dX, dY, az_fp2sp/!DTOR
    endif

;   Iterate once using new GR height/range at adjusted TMI footprint location

;   compute new range at parallax-adjusted footprint subpoint
    precise_range = SQRT( (tmi_x+dX)^2 + (tmi_y+dY)^2 )
;   get new GR beam height at parallax-corrected footprint range, and new dR
    slant_range=0.0 ; don't need/use it, but declare it
    rsl_get_slantr_and_h, precise_range, elev_angle, slant_range, height
    dR = (height + siteElev) * TAN_TMI_INCIDENT_ANGLE
;   compute new TMI footprint dx and dy offsets - angle doesn't change
    dX = COS(az_fp2sp)*dR
    dY = SIN(az_fp2sp)*dR

    if (do_print eq 1 ) then begin
        print, FORMAT='("  Final precise_range = ", F0.4)', precise_range
        print, FORMAT='("  Final height, dR, dX, dY, angle = ", 4(F0.4,", "), F0.4)', $
               height+siteElev, dR, dX, dY, az_fp2sp/!DTOR
        print, ""
    endif

end
