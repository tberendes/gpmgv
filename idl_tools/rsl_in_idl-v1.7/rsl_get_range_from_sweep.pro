function rsl_get_range_from_sweep, sweep

; Returns a floating point array containing the range values corresponding
; to the bins of the first ray in the sweep given as argument.

on_error, 2

ray = sweep.ray(0)
gate_size = ray.h.gate_size
range_bin1 = ray.h.range_bin1
nbins = ray.h.nbins
range = (range_bin1 + findgen(nbins)*gate_size)/1000.
return, range
end

