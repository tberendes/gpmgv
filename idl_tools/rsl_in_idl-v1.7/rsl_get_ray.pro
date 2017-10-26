function rsl_get_ray, vol_or_sweep, elevation, azimuth

; This function takes either a volume or sweep as input and returns the ray
; closest to the given azimuth, or the first ray of sweep if azimuth is
; omitted.  If volume is given instead of sweep, the elevation may also be
; specified to select a sweep.  Otherwise, the base scan is used.  If ray is
; not found, function returns -1.
;
; Syntax:
;     ray = rsl_get_ray(volume [, elevation] [, azimuth])
;     ray = rsl_get_ray(sweep [, azimuth])
; 
; Inputs:
;    volume:	a volume structure.
;    sweep:	a sweep structure.
;    elevation: elevation angle of sweep to be used (default is lowest elev.).
;    azimuth:	azimuth of ray to be returned (default is first ray).
;

members = tag_names(vol_or_sweep)
if members[1] ne 'RAY' then begin
    ray = rsl_get_ray_from_sweep(rsl_get_sweep(vol_or_sweep,elevation), azimuth)
endif else begin
    sweep = vol_or_sweep
    if n_elements(elevation) ne 0 then azim = elevation
    ray = rsl_get_ray_from_sweep(sweep, azim) 
endelse

return, ray
end
