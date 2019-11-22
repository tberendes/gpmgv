function read_nam_netcdf, ncfile, ROT=rot, LAT=lat, LON=lon


status = 0

ncid1 = NCDF_OPEN( ncfile )
IF ( N_Elements(ncid1) EQ 0 ) THEN BEGIN
   print, ''
   print, "ERROR from read_geo_match_netcdf:"
   print, "File copy ", ncfile, " is not a valid netCDF file!"
   print, ''
   status = 1
   goto, ErrorExit
ENDIF

IF N_Elements(rot) NE 0 THEN NCDF_VARGET, ncid1, 'gridrot_218', rot
;         note2 :        apply formulas to derive u and v components relative to earth
;         note1 :        u and v components of vector quantities are resolved relative to grid
;         formula_v :    Vearth = cos(rot)*Vgrid - sin(rot)*Ugrid
;         formula_u :    Uearth = sin(rot)*Vgrid + cos(rot)*Ugrid
;         units :        radians
;         long_name :    vector rotation angle

IF N_Elements(lat) NE 0 THEN NCDF_VARGET, ncid1, 'gridlat_218', lat

IF N_Elements(lon) NE 0 THEN NCDF_VARGET, ncid1, 'gridlon_218', lon

ErrorExit:
NCDF_CLOSE, ncid1

return, status

end
