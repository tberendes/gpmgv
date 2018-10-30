pro rsl_get_groundr_and_h, slant_r, elev, gr, h

; Given range and elevation, return ground range and height.
;
; Inputs
;   slant_r   slant range (km)
;   elev      elevation in degrees
; Outputs
;   gr  ground range (km)
;   h   height (km)
;
; This routine is adapted from the Radar Software Library routine
; RSL_get_groundr_and_h, written by John Merritt, and located in file range.c.

if slant_r eq 0.0 then begin
    h = 0.
    gr = 0.
    return
endif

Re = 4./3. * 6374.d  ; Effective earth radius in km.

h = sqrt( Re^2.0 + slant_r^2.0 - 2*Re*slant_r*cos((elev+90.)*!DPI/180.0))
if (h ne 0.0) then begin
    gr = Re * acos( ( Re^2.0 + h^2.0 - slant_r^2.0) / (2.0 * Re * h))
endif else begin
    gr = slant_r
    h = Re
endelse
h -= Re
end
