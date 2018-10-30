pro rsl_get_slantr_and_elev, gr, h, slantr, elev

; Given ground range and height, return slant range and elevation.
;
; Inputs
;   gr  ground range (km)
;   h   height (km)
; Outputs
;   range     slant range
;   elev      elevation in degrees

; This routine is adapted from the Radar Software Library routine
; RSL_get_slantr_and_elev, written by John Merritt and Dennis Flanigan, and
; located in file range.c.

Re = 4./3. * 6374.d  ; Effective earth radius in km.
rh = h + Re
slantrsq = Re^2 + rh^2 - (2*Re*rh*cos(gr/Re))
slantr = sqrt(slantrsq)
elev = acos((Re^2 + slantrsq - rh^2)/(2*Re*slantr))
elev = elev * 180./!dpi
elev = elev - 90.
end
