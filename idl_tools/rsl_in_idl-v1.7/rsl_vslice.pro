function rsl_vslice, radar, azimuth, field=field, volume_index=volume_index

;******************************************************************************
; Retrieve an RHI-like vertical slice of volume scan at the given azimuth.
; The slice is returned as a radar structure containing a single sweep, which
; contains one ray for each elevation at that azimuth.
;
; Syntax:
;    result = rsl_vslice(radar, azimuth [, field=string] [, volume_index=value])
;
; Arguments:
;    radar:    radar structure.
;    azimuth:  azimuth at which vertical slice will be taken.
;
; Keywords:
;    FIELD:        A string identifying the radar field to select, for example,
;                  'DZ'.
;    VOLUME_INDEX: The index number of volume (0 to nvols-1) to select.
;                  Default is index 0.  This is an alternative to specifying
;                  FIELD.
;
; Return value:
;    A radar structure containing one sweep consisting of the rays that make
;    up the vertical slice. Ray index 0 is the first elevation of the volume
;    scan.
;
; Written by:  Bart Kelley, GMU, May 2007
;******************************************************************************


if n_params() lt 2 then begin
    message,'Not enough arguments.',/continue
    print,'Usage:' + $
    '  sweep = rsl_vslice(radar, azimuth, field=string, volume_index=value)'
    return, -1
endif

ivol = 0
if n_elements(field) gt 0 then vol = rsl_get_volume(radar,field) $
else begin
    if n_elements(volume_index) gt 0 then ivol = volume_index
    vol = radar.volume[ivol]
endelse

nsweeps = vol.h.nsweeps
nrays = nsweeps

raysize = n_elements(vol.sweep[0].ray[0].range)

sweep = rsl_new_sweep(nrays, raysize)
iray = 0

for iswp = 0,nsweeps-1 do begin
    ray = rsl_get_ray_from_sweep(vol.sweep[iswp], azimuth)
    sweep.ray[iray] = ray
    sweep.h.elev = vol.sweep[iswp].h.elev
    iray = iray + 1
endfor

; Update sweep header.
sweep.h.field_type = vol.h.field_type
sweep.h.sweep_num = 1
sweep.h.beam_width = vol.sweep[0].h.beam_width 
sweep.h.vert_half_bw = vol.sweep[0].h.vert_half_bw 
sweep.h.horz_half_bw = vol.sweep[0].h.horz_half_bw 
sweep.h.nrays = nrays

radarvslice = rsl_new_radar(1, 1, nrays, raysize)
;radarvslice.h = radar.h
; Note: Commented-out the above line, which caused structure conflict on 64-bit
; machines.  Replaced it with the following line.
for i=0,n_tags(radar.h)-1 do radarvslice.h.(i) = radar.h.(i)

radarvslice.h.scan_mode = 'RHI' 
radarvslice.volume.sweep = sweep
radarvslice.volume.h = vol.h
radarvslice.volume.h.nsweeps = 1

return, radarvslice
end
