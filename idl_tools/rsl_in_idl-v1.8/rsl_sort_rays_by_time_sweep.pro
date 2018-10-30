function rsl_sort_rays_by_time_sweep, sweep, indices=indices

;+
; Sort rays in the sweep by time.  Function returns a sweep structure with rays
; ordered sequentially by time, or optionally, the sorted ray indices.
;
; Syntax:
;     Result = rsl_sort_rays_by_time_sweep(Sweep, /INDICES)
;
; Return value:
;     Function returns a sweep structure with rays ordered sequentially by time.
;     If the INDICES keyword is set, the function returns an array of sorted
;     indices instead of a sweep.
;     
; Arguments:
;     Sweep: A sweep structure.
;
; Keywords:
;     INDICES
;         Set this keyword to return an array of ray indices instead of a
;         sweep. The indices corresponding to the time-ordered ray sequence.
;-

; Convert ray dates and times to Julian dates.
nrays = sweep.h.nrays
jtime = julday( $
    sweep.ray[0:nrays-1].h.month, $
    sweep.ray[0:nrays-1].h.day,   $
    sweep.ray[0:nrays-1].h.year,  $
    sweep.ray[0:nrays-1].h.hour,  $
    sweep.ray[0:nrays-1].h.minute,$
    sweep.ray[0:nrays-1].h.sec    $
    )

; Sort Julian dates.
ts = sort(jtime)

if keyword_set(indices) then return, ts
sorted_sweep = sweep
sorted_sweep.ray = sweep.ray[ts]
return, sorted_sweep

end
