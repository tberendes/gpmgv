pro rsl_select_sweeps, radar, sweep_index

;******************************************************************************
; Return a radar structure containing only selected sweeps.
; The radar structure given as argument is modified.
;
; Syntax
;     rsl_select_sweeps, radar, sweep_index
;
; Arguments
;     radar:        radar structure.  It is modified by this procedure.
;     sweep_index:  Index number of sweep(s).  This can be a scalar or array.
;                   Index of first sweep is 0.
;
; Example
; Select sweeps 0, 2, and 6.  On return from the procedure, radar contains
; only those three sweeps.
;
;   rsl_select_sweeps, radar, [0,2,6]
;
; Written by:  Bart Kelley, SSAI, August 2007
;******************************************************************************

nsweeps = n_elements(sweep_index)

; Get array sizes from radar. 
dims = size(radar.volume.sweep.ray.range,/dimensions)
nbins = dims[0]
nrays = dims[1]
nvols = radar.h.nvolumes

newradar = rsl_new_radar(nvols, nsweeps, nrays, nbins)
newradar.h = radar.h
newradar.volume.h = radar.volume.h

; Copy selected sweeps.
j = 0
for i = 0,nsweeps-1 do begin
    isweep = sweep_index[i]
    newradar.volume.sweep[j] = radar.volume.sweep[isweep]
    j = j + 1
endfor
newradar.volume.h.nsweeps = j

radar = newradar

end
