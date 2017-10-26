; Copyright (C) 2014  NASA/TRMM Satellite Validation Office
;
; This program is free software; you can redistribute it and/or modify
; it under the terms of the GNU General Public License as published by
; the Free Software Foundation; either version 2 of the License, or
; (at your option) any later version.
;
; This program is distributed in the hope that it will be useful,
; but WITHOUT ANY WARRANTY; without even the implied warranty of
; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
; GNU General Public License for more details.
;
; You should have received a copy of the GNU General Public License
; along with this program; if not, write to the Free Software Foundation, Inc.,
; 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
;**************************************************************************

function rsl_azm_rng_to_latlon, radar, azimuth, range

;+
; Convert azimuth and range to latitude and longitude.
;
; Syntax:
;     result = rsl_azm_rng_to_latlon(radar, azimuth, range)
;
; Inputs:
;     radar:   radar structure
;     azimuth: radial azimuth in degrees.
;     range:   range in meters.
;
; Return value:
;     Function returns a structure containing the members lat and lon, which
;     store the latitude and longitude in degrees for the given range and
;     azimuth.
;        
; Written by Bart Kelley, SSAI, February 27, 2013
;-

if n_params() ne 3 then begin
    print,'Usage: latlon = rsl_azm_rng_to_latlon(radar, azimuth, range)'
    return, -1
endif

latlon = rsl_get_radar_latlon(radar)
radarlat = latlon[0]
radarlon = latlon[1]

meters_to_lat = 1. / 111177.d
meters_to_lon =  1. / (111177.d * cos(radarlat * !DTOR))

; Convert azimuth to polar angle (azimuth 0 = north, increases clockwise).
azimuth = 90. - azimuth
if azimuth lt 0. then azimuth = azimuth + 360.
azimuth = azimuth * !DTOR ; convert to radians.

x = range * cos(azimuth)
y = range * sin(azimuth)

; Convert coordinates to latitude and longitude.
lon = float(radarlon + meters_to_lon * x)
lat = float(radarlat + meters_to_lat * y)

return, {lat:lat, lon:lon}
end
