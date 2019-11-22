; docformat = 'rst'
;+
; Visualizes the world elevation data in the GRIB2 file written by 
; WRITE_WORLD_ELEVATIONS. 
;
; :keywords:
;  use_save_file: in, optional, type=boolean
;     Set this keyword to use the example data stored in an IDL SAVE file.
;     This is the default on Windows.
;  save: in, optional, type=boolean
;     Set this keyword to save the plot to a PNG file.
;
; :requires:
;  IDL 8.1
;   
; :pre:
;  The GRIB2 file 'worldelv.grb' or the IDL 8.1 SAVE file 'worldelv.sav'.
;  
; :author:
;	Mark Piper, VIS, 2012
;-
pro display_world_elevations, use_save_file=use_save_file, save=to_png
   compile_opt idl2

   ; Read/restore data. Use data from a SAVE file if on Windows.
   if keyword_set(use_save_file) || !version.os_family eq 'Windows' then $
      restore, file_which('worldelv.sav', /include), /verbose $
   else begin
      file = file_which('worldelv.grb', /include)
      worldelv = grib_get_record(f, 1, /structure)
   endelse
   
   ; Get projection parameters from the file & visualize the data as an image.
   minlat = min(worldelv.distinctlatitudes, max=maxlat)
   minlon = min(worldelv.distinctlongitudes, max=maxlon)
   limits = [minlat, minlon, maxlat, maxlon]
   m = map('Robinson', limit=limits, color='light blue')
   g = image(worldelv.values, worldelv.distinctlongitudes, worldelv.distinctlatitudes, $
      /overplot, $
      /interpolate, $
      grid_units='degrees', $
      title='World Elevation')
   
   if keyword_set(to_png) then $
      m.save, 'worldelv.png', resolution=150
end

; Example
display_world_elevations, use_save_file=1, save=0
end
