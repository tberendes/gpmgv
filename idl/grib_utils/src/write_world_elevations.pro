; docformat = 'rst'
;+
; Makes a new GRIB2 file that holds one record, using for data the world
; elevations in the file 'worldelv.dat' in the IDL examples/data directory.
;
; Compare this with the Python example 'samples.py' here::
;  http://www.ecmwf.int/publications/manuals/grib_api/samples_8py-example.html
;  
; :requires:
;  IDL 8.1
;
; :pre:
;  GRIB is currently supported only on Mac & Linux.
;
; :author:
;	Mark Piper, VIS, 2012
;-
pro write_world_elevations
   compile_opt idl2
   
   ; The data to be stored in the GRIB2 file.
   infile = file_which('worldelv.dat')
   elev = read_binary(infile, data_dims=[360,360])
   
   ; Interpolate the data to 2.5-deg resolution.
   n_lon = 144
   n_lat = 72
   elev_interp = congrid(elev, n_lon, n_lat, /interp)
   
   ; Make a new record with the template 'GRIB2.tmpl'. For a list of available
   ; templates shipped with IDL, see $IDL_DIR/resource/grib/share/samples.
   h = grib_new_from_samples('GRIB2')
   
   ; Load the interpolated elevation data into the record.
   grib_set_values, h, elev_interp
   
   ; The new record is autopopulated with keys. Selectively override the values
   ; with user-defined data. Use a hash because GRIB keys are case-sensitive.
   ; Many GRIB keys are computed. I found these to be the smallest set of keys
   ; that could be used to define a lat-lon grid.
   keys = hash()
   today = bin_date()
   keys[['year', 'month', 'day']] = today[0:2]
   keys['Ni'] = n_lon
   keys['Nj'] = n_lat
   keys['iDirectionIncrementInDegrees'] = 2.5
   keys['jDirectionIncrementInDegrees'] = 2.5
   keys['latitudeOfFirstGridPointInDegrees'] = 89.5 ; N->S
   keys['latitudeOfLastGridPointInDegrees'] = -88.0 ; N->S
   keys['longitudeOfFirstGridPointInDegrees'] = 0.0
   keys['longitudeOfLastGridPointInDegrees'] = 357.5
   
   ; ECMWF Section 4, Template 0 information.
   ; http://www.ecmwf.int/publications/manuals/d/gribapi/fm92/grib2/detail/templates/4/0/
   keys['parameterCategory'] = 3    ; mass
   keys['parameterNumber'] = 6      ; geometric height
   
   ; Loop over the keys to fill in their values.
   foreach value, keys, key do begin
      if isa(key, /array) then $
         grib_set_array, h, key, value $
      else $
         grib_set, h, key, value
   endforeach
   
   ; Write the record to a new file & release the handle.
   outfile = file_basename(infile, '.dat') + '.grb'
   grib_write_message, outfile, h
   grib_release, h
   
   print, 'File "' + outfile + '" created in current directory.'
end
