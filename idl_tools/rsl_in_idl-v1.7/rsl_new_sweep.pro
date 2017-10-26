function rsl_new_sweep, nrays, nbins

;+
; Return a sweep structure.
;
; Syntax:
;     sweep = rsl_new_sweep(nrays, nbins)
;
; Inputs:
;     nrays:   The maximum number of rays in a sweep.
;     nbins:   The maximum number of bins or cells in a ray.
;- 

compile_opt hidden

ray = rsl_new_ray(nbins)

swphdr = {field_type:'', sweep_num:-99, fixed_angle:-99., elev:-99., $
    beam_width:0.0, vert_half_bw:0.0, horz_half_bw:0.0, nrays:0}

return, {h:swphdr, ray:replicate(ray,nrays)}
end
