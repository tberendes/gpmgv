function rsl_get_radar_latlon, radar

;+
; Return radar site coordinates in decimal degrees.
;
; Syntax:
;     latlon = rsl_radar_site_lat_lon(radar)
;
; Return value:
;     The return value is a 2-element floating point array.  The first element
;     of the array is latitude, the second is longitude.
;
; Written by Bart Kelley, November 8, 2007
;-

; Convert latitude degrees-minutes-seconds to decimal degrees.

latlon = fltarr(2)
deg = radar.h.latd
min = radar.h.latm
sec = radar.h.lats

sign = 1
if deg lt 0. then sign = -1

fdeg = abs(deg) + abs(min)/60. + abs(sec)/3600.
fdeg = sign * fdeg
latlon[0] = fdeg

; Convert longitude degrees-minutes-seconds to decimal degrees.

deg = radar.h.lond
min = radar.h.lonm
sec = radar.h.lons

sign = 1
if deg lt 0. then sign = -1

fdeg = abs(deg) + abs(min)/60. + abs(sec)/3600.

fdeg = sign * fdeg
latlon[1] = fdeg
return, latlon
end
