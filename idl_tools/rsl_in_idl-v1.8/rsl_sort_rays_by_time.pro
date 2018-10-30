pro rsl_sort_rays_by_time, radar 

;+
; Sort rays by time.
;
; Syntax
;    rsl_sort_rays_by_time, radar
;
; Arguments
;    radar: a radar structure.
;
; Written by Bart Kelley, SSAI, March 25, 2013
;-

; For each sweep, we only need to sort for one radar field.  The sorted indices
; for that sweep are then used for all fields.

for iswp = 0, radar.volume[0].h.nsweeps-1 do begin
    sweep=radar.volume[0].sweep[iswp]
    nrays = sweep.h.nrays
    ; Convert ray times to Julian time.
    jtime = julday( $
        sweep.ray[0:nrays-1].h.month, $
        sweep.ray[0:nrays-1].h.day,   $
        sweep.ray[0:nrays-1].h.year,  $
        sweep.ray[0:nrays-1].h.hour,  $
        sweep.ray[0:nrays-1].h.minute,$
        sweep.ray[0:nrays-1].h.sec    $
        )
    ts = sort(jtime) ; sort times and return array of indices.
    ; If first sweep is in correct order, exit loop.
    if iswp eq 0 and array_equal(jtime, jtime[ts]) then break
    ; Apply the indices from sort on current sweep for all fields.
    radar.volume.sweep[iswp].ray = radar.volume.sweep[iswp].ray[ts]
endfor
end
