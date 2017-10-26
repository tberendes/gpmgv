pro rsl_get_gr_slantr_h, ray, ibin, gr, slantr, h

; Given ray and bin index, return ground range, slant range, and height.
;
; Inputs
;   ray     a ray structure
;   ibin    index of the range bin, where 0 is the first
; Outputs
;   gr      ground range (km)
;   slantr  slant range (km)
;   h       height (km)

slantr = (ray.h.range_bin1 + ibin * float(ray.h.gate_size)) / 1000. ; m to km
elev = ray.h.elev
rsl_get_groundr_and_h, slantr, elev, gr, h
end
