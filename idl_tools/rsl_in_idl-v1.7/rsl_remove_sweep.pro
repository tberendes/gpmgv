pro rsl_remove_sweep, radar, remove_list, nremove

;+
; This procedure removes the sweeps at specified indices from all volumes in
; the radar structure.
;
; Note that this procedure modifies the radar structure argument.
;
; Syntax
;     rsl_remove_sweep, radar, remove_list, [nremove]
;
; Arguments
;    radar:       Radar structure.  It is modified by this procedure.
;    remove_list: An array of indices specifying sweeps to be removed. This may
;                 be a scalar if only one sweep is to be removed.
;    nremove:     Optional parameter specifying number of sweeps to be removed.
;                 If omitted, the array size is used.
;
; Written by:  Bart Kelley, SSAI, July, 2014.
; Original was designed to remove a single sweep specified by sweep index.
; Rewritten to remove multiple sweeps. June 15, 2015. BLK
;-

if n_elements(nremove) eq 0 then nremove = n_elements(remove_list)
if nremove eq 0 then return

; Check REMOVE_LIST for negative values, indicating initialized values.
if total(remove_list,/integer) lt 0 then begin
    print, 'rsl_remove_sweep: no valid sweep indices given (indices lt 0).'
    return
endif

; Make new radar structure sized to lesser number of sweeps.
nsweeps = radar.volume[0].h.nsweeps
nsweeps_new = nsweeps - nremove
dims = size(radar.volume.sweep.ray.range)
nvols = dims[4]
nrays = dims[2]
nbins = dims[1]
newradar = rsl_new_radar(nvols,nsweeps_new,nrays,nbins)

; Remove specified sweeps.
iremove = 0
to = 0
for from = 0, nsweeps-1 do begin
    if iremove lt nremove && from eq remove_list[iremove] then begin
        iremove = iremove + 1
        continue
    endif
    newradar.volume.sweep[to] = radar.volume.sweep[from]
    to = to + 1
endfor

newradar.volume.h = radar.volume.h
newradar.volume.h.nsweeps = nsweeps_new
radar = newradar
newradar = 0 ; Free the memory used by newradar.

end
