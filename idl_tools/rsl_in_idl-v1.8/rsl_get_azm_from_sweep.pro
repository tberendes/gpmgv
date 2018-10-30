function rsl_get_azm_from_sweep, sweep

; Returns a floating point array containing the azimuths from the rays of
; the sweep given as argument.  If ray count for the sweep is zero, function
; returns -1.

on_error, 2

nrays = sweep.h.nrays
if nrays gt 0 then azm = sweep.ray[0:nrays-1].h.azimuth else azm = -1

return, azm
end
