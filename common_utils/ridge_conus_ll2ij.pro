;+
; Copyright © 2008, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; DESCRIPTION
; Given a National Weather Service full-resolution, continental U.S. "RIDGE"
; radar mosaic image, computes the X and Y pixel locations for a specified
; input latitude (deg. East) and longitude (deg. North).  Hard-coded values
; of the GIS "world" coordinates for the CONUS RIDGE mosaic were taken from
; the file provided on the NWS ftp site, and may change.
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-

pro RIDGE_CONUS_LL2IJ, lat, lon, x, y

; values from world coordinates file for latest.gif
dellat = 0.017971305190311D
dellon = -dellat
ul_lon = -127.620375523875420D
ul_lat = 50.406626367301044D

; gif image dimensions
nx = 3400
ny = 1600

; image array origin [0,0] is at lower left corner, compute this lat/lon:
lat0 = ul_lat - dellat * (ny-1)
lon0 = ul_lon

;lat = 36.0D
;lon = -100.0D

x = (lon0 - lon)/dellon
y = (lat - lat0)/dellat

print, "x = ", x, "   y = ", y
end
