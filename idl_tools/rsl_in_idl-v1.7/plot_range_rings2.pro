	pro plot_range_rings2, range, radar_lon, radar_lat, _extra=extra
; ****************************************************************
; * This program plots range rings on an existing map projection *
; ****************************************************************
; * Program written by: David B. Wolff (SSAI)                    *
; ****************************************************************
; * Version last modified: Tuesday, February 20 , 2001           *
; * Modified July 5, 2007 by Bart Kelley (SSAI):                 *
; *   Added COLOR keyword.                                       *
; * Modified August 15, 2013 by Bart Kelley (SSAI):              *
; *   Replaced COLOR keyword with _EXTRA.                        *
; ****************************************************************

	div = 1080
	R=6370.
	radarrange = range
;	print, range,radar_lon,radar_lat
	for xxx=0,div do begin
		dx=radarrange*cos(2.0*!pi*xxx/div)
		dy=radarrange*sin(2.0*!pi*xxx/div)
		dlon=dx/(R*cos(radar_lat*!pi/180.0)*!pi/180.0)
		dlat=dy/(R*!pi/180.0)
		plots,radar_lon+dlon,radar_lat+dlat,psym=3,symsize=0.75, $
		    _extra=extra
	endfor
	return
	end
