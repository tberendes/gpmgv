pro rsl_get_slantr_and_h, gr, elev, slantr, h

; Return slant range and height from ground range and elevation.
;
; Inputs
;   gr        ground range (km)
;   elev      elevation in degrees
; Outputs
;   slant_r   slant range (km)
;   h   height (km)
;
; This routine is adapted from the Radar Software Library routine
; RSL_get_slantr_and_h, written by John Merritt, and located in file range.c.

if gr eq 0 then begin
    slantr = 0
    h = 0
    return
endif

Re = 4./3. * 6374d  ; Effective earth radius in km.

ALPHA = (elev + 90.)*!DPI/180.0;    /* Elev angle + 90 */
GAMMA = gr/Re;
BETA = !DPI - (ALPHA + GAMMA);  /* Angle made by Re+h and slant */
slantr = Re*(sin(GAMMA)/sin(BETA));
A = Re*sin(ALPHA)/sin(BETA);
h = A - Re
end
