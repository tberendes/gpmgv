pro rsl_latlon_to_radarhdr, radar, radarlat, radarlon

;+
; Put radar site latitude and longitude into radar header as
; degrees-minutes-seconds.
;
; Syntax
;     rsl_latlon_to_radarhdr, radar, radarlat, radarlon
;
; Arguments
;    radar:    Radar structure.  It is modified by this procedure.
;    radarlat: Latitude of radar site in degrees.
;    radarlon: Longitude of radar site in degrees.
;
; Written by:  Bart Kelley, SSAI, July, 2013
;-

lat = abs(radarlat)
if radarlat ge 0. then sign = 1 else sign = -1
latd = fix(lat)
latm = fix((lat - latd) * 60.)
lats= round(((lat - latd) * 60. - latm) * 60.)
radar.h.latd = sign * latd
radar.h.latm = sign * latm
radar.h.lats = sign * lats

lon = abs(radarlon)
if radarlon ge 0. then sign = 1 else sign = -1
lond = fix(lon)
lonm = fix((lon - lond) * 60.)
lons= round(((lon - lond) * 60. - lonm) * 60.)
radar.h.lond = sign * lond
radar.h.lonm = sign * lonm
radar.h.lons = sign * lons

end
