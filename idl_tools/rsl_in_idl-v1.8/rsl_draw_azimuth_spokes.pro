pro rsl_draw_azimuth_spokes, radar_lon, radar_lat, spoke_interval, $
    maxrange=maxrange, _extra=extra

; Draw azimuth spokes on radar plot, separated by spoke_interval degrees.
 
if n_elements(maxrange) eq 0 then maxrange = 500. ; azimuths to edge of plot.

km_to_lat = 1. / 111.177
km_to_lon = 1. / (111.177 * cos(radar_lat * !dtor))

; Make sure we have reasonable spoke interval.
if n_elements(spoke_interval) eq 0 then spoke_interval = 30. $
else if spoke_interval lt 2. then spoke_interval = 30.

for i = 0, 360, spoke_interval do begin
    azimuth = 90. - i
    if azimuth lt 0. then azimuth = azimuth + 360.
    azimuth = azimuth * !DTOR ; convert to radians.
    lon_maxrange = radar_lon + cos(azimuth) * km_to_lon * maxrange
    lat_maxrange = radar_lat + sin(azimuth) * km_to_lat * maxrange
    plots, [radar_lon, lon_maxrange], [radar_lat, lat_maxrange], $
	_extra=extra
endfor
end
