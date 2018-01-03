;===============================================================================
;+
; Copyright © 2015, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; get_in_range_footprints.pro
; - Morris/SAIC/GPM_GV  April 2015
;
; DESCRIPTION
; -----------
; Given arrays of latitude and longitude, the array index of the center point,
; and a range cutoff in km, computes and returns  the array indices of
; surrounding points in the lat/lon arrays within the range cutoff distance
; from the center point.  Returns -1 if no such samples are found.  The cutoff
; distance is specified by the RANGE_CUTOFF keyword parameter.  If RANGE_CUTOFF
; is not specified, a default value of 20.0 km is used.  If a value is defined
; for the optional keyword RANGES, then the subarray of computed ranges at the
; in-range locations is returned in this variable.
;
; Uses a great circle distance calculation to compute the point-to-point
; ranges, assuming a spherical earth with a radius of 6378 km.
;
; HISTORY
; -------
; 04/08/15 Morris, GPM GV, SAIC
; - Created.
;
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;===============================================================================

FUNCTION get_in_range_footprints, the_idx, lat, lon, RANGE_MAX=range_max, $
                                  RANGES=ranges

IF N_ELEMENTS(range_max) NE 1 THEN range_max = 20.

; replicate center lat/lon over all input array locations
the_lat = FLTARR(N_ELEMENTS(lat))
the_lon = the_lat
the_lat[*] = lat[the_idx]
the_lon[*] = lon[the_idx]

; compute footprint ranges from the center footprint at "the_idx"
   earthRadiusKm = 6378.
   deg2rad=3.1415926D / 180.
   cosLat1 = COS( deg2rad * the_lat )
   cosLat2 = COS( deg2rad * lat )
   sinLat1 = SIN( deg2rad * the_lat )
   sinLat2 = SIN( deg2rad * lat )
   dLon = (the_lon - lon)
   cosdLon = COS( deg2rad * dLon )
   GC_dist = earthRadiusKm * ACOS(cosLat1*cosLat2*cosdLon+sinLat1*sinLat2)

; find points within range
   idxInRange = WHERE(GC_dist LE range_max, countInRange)
   if countInRange GT 0 then begin
      IF N_ELEMENTS(ranges) NE 0 THEN ranges=GC_dist[idxInRange]
      return, idxInRange
   endif else return, -1L

end
