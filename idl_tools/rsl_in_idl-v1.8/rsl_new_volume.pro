function rsl_new_volume, nsweeps, nrays, nbins

; Return a volume structure.
;
; Syntax:
;     volume = rsl_new_volume(nsweeps, nrays, nbins)
;
; Inputs:
;     nsweeps: The number of sweeps in a VOS.
;     nrays:   The maximum number of rays in a sweep.
;     nbins:   The maximum number of bins or cells in a ray.
; 

compile_opt hidden

sweep = rsl_new_sweep(nrays, nbins)

volume_header = {field_type:'', nsweeps:0, calibr_const:0.0, $
    no_data_flag:-32767.0 }

return, {h:volume_header, sweep:replicate(sweep,nsweeps)}
end
