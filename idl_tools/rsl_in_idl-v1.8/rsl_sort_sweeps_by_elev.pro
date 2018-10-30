pro rsl_sort_sweeps_by_elev, radar

;+
; Sort sweeps by elevation.
;
; Syntax
;    rsl_sort_sweeps_by_elev, radar
;
; Arguments
;    radar: a radar structure.
;
; Written by Bart Kelley, SSAI, April 30, 2013
;-

; Sort sweeps by elevation on one radar field, then use the sorted indices to
; sort for all fields.

nfields = (radar.h.nvolumes)[0] ; array element notation assures scalar value
nsweeps = radar.volume[0].h.nsweeps
elevind = sort(radar.volume[0].sweep[0:nsweeps-1].h.elev)
for i = 0,nfields-1 do begin
    radar.volume[i].sweep = radar.volume[i].sweep[elevind]
    radar.volume[i].sweep[0:nsweeps-1].h.sweep_num = indgen(nsweeps)+1 ;renumber
endfor
end
