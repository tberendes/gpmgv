function rsl_new_radar, nvolumes, nsweeps, nrays, nbins

; Returns a radar structure.  The values of the input arguments are used to
; determine the size of the structure.
;
; Syntax:
;     radar = rsl_new_radar(nvolumes, nsweeps, nrays, nbins)
;
; Inputs:
;     nvolumes: The number of radar fields.
;     nsweeps:  The maximum number of sweeps in a volume scan.
;     nrays:    The maximum number of rays in a sweep.
;     nbins:    The maximum number of bins in a ray.
; 
; Output:
;     Function returns a Radar structure.
;
; Written by:  Bart Kelley, GMU, July 2002
;

compile_opt hidden

volume = rsl_new_volume(nsweeps, nrays, nbins)

radarhdr = {month:0, day:0, year:0, hour:0, minute:0, sec:0.0,  $
    radar_type:'',  nvolumes:0, number:0L, name:'', radar_name:'', $
    project:'', city:'', state:'', country:'', latd:0, latm:0, lats:0, $
    lond:0, lonm:0, lons:0, height:0L, spulse:0L, lpulse:0L, scan_mode:'', $
    vcp:0, sched_sweeps:0}

radarhdr.nvolumes = nvolumes

return, {h:radarhdr, volume:replicate(volume, nvolumes)}
end
