function rsl_get_ray_from_sweep, sweep, azimuth, index=index

;*****************************************************************************
; This function returns the ray closest to the given azimuth, or the first
; ray of sweep if azimuth is omitted.  If closest ray is not found, function
; returns -1.  
; 
; Syntax:
;     ray = rsl_get_ray_from_sweep(sweep [, azimuth] [, index=index])
; 
; Arguments:
;    sweep:    A sweep structure.
;    azimuth:  The ray having azimuth closest to this value is returned.  If
;              omitted, the first ray of the sweep is returned.
; Keywords:
;    index:    If variable is given, the index of ray with closest azimuth is
;              returned, or -1 if not found.
;*****************************************************************************

on_error, 2 ; Return to caller on error.

index = 0
if n_elements(azimuth) eq 0 then goto, finished

azm = sweep.ray[0:sweep.h.nrays-1].h.azimuth

; Sort azimuths if necessary.  If first azimuth is between 0., and 1.,
; shouldn't need to sort.
if azm[0] ge 0. and azm[0] lt 1. then begin
    azsort = azm
endif else begin
    sorti = sort(azm)
    azsort = azm[sorti]
endelse

lt_az = where(azsort lt azimuth)
ge_az = where(azsort ge azimuth)

n = n_elements(lt_az)
if lt_az[0] gt -1 and ge_az[0] gt -1 then begin
    ; Find index of closest.
    diff1 = azimuth - azsort[lt_az[n-1]]
    diff2 = azsort[ge_az[0]] - azimuth
    if diff2 lt diff1 then index = ge_az[0] else index = lt_az[n-1]
endif else begin
    ; The one that is not -1 has closest index.
    if lt_az[0] eq -1 then index = ge_az[0] else index = lt_az[n-1]
endelse

; If sorting was necessary, we use this index with sorted index.
if n_elements(sorti) gt 0 then index = sorti[index]

finished:
if index gt -1 then return, sweep.ray[index]
return, index ; when index is -1.
end
