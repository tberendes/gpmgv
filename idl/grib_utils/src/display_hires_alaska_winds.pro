; docformat = 'rst'
;+
; An example of setting up a projection and displaying georeferenced modeled
; winds read from a GRIB2 file.
; 
; The model data used in this example are from the 
; `NCEP HiResWindow system <http://nomads.ncep.noaa.gov/txt_descriptions/HIRES_doc.shtml>`
; and are downloaded from the NOAA Operational Model Archive and Distribution
; System, `http://nomads.ncep.noaa.gov <http://nomads.ncep.noaa.gov>`.
; 
; Translating the projection parameters from the GRIB file into what IDL needs
; was not trivial.
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
;  The GRIB2 file 'ak.t18z.pgrb.mean.f06.grib2' or the IDL 8.1 SAVE 
;  file 'hires_alaska_winds.sav'.
;
; :examples:
;  Run the example main attached to this program with::
;     IDL> .r display_hires_alaska_winds
;
; :author:
; 	Mark Piper, VIS, 2012
;-
pro display_hires_alaska_winds, use_save_file=use_save_file, save=to_png
   compile_opt idl2
   
   ; Read/restore data. Use data from a SAVE file if on Windows.
   if keyword_set(use_save_file) || !version.os_family eq 'Windows' then $
      restore, file_which('hires_alaska_winds.sav', /include), /verbose $
   else begin
      file = file_which('ak.t18z.pgrb.mean.f06.grib2', /include)
      r_u250 = grib_get_record(file, 4, /structure)
      r_v250 = grib_get_record(file, 6, /structure)
   endelse

   ; Calculate wind speed from the two GRIB records.
   s250 = sqrt(r_u250.values^2 + r_v250.values^2)

   w = window(dimensions=[768,640])
   w.refresh, /disable

   ; Set up the projection using parameters from the file.
   m = map('Polar Stereographic', $ ; see r_u250.gridtype
      /current, $
      limit=limit, $
      semimajor_axis=r_u250.radius, $
      semiminor_axis=r_u250.radius, $
      true_scale_latitude=r_u250.ladindegrees, $
      center_longitude=r_u250.orientationofthegridindegrees, $
      color='gray')

   ; Display continental outlines & country boundaries.
   c1 = mapcontinents(/countries, color='black')
   c2 = mapcontinents(/countries, /fill_background, fill_color='light gray')
      
   ; To display the data as an image, determine 1) the location of the first 
   ; grid point (lower left corner) in the projection in meters and 2) the 
   ; dimensions of the image.
   lon0 = r_u250.longitudeoffirstgridpointindegrees
   lat0 = r_u250.latitudeoffirstgridpointindegrees
   xy0 = m.mapforward(lon0, lat0)
   xsize = r_u250.nx * r_u250.dxinmetres ; note spelling
   ysize = r_u250.ny * r_u250.dyinmetres

   m.xrange = [xy0[0], xy0[0]+xsize]
   m.yrange = [xy0[1], xy0[1]+ysize]

   ; Display wind speed as a color-mapped image in the projection.
   i = image(s250, $
      overplot=m, $
      rgb_table=16, $
      grid_units='meters', $
      image_dimensions=[xsize,ysize], $
      image_location=xy0)
   
   ; Display a colorbar.
   cbar = colorbar(target=i, $
      position=[0.55, 0.10, 0.90, 0.125], $
      title='Wind Speed ($ms^{-1}$)')

   ; Display a title & a subtitle.
   title = text(0.5, 0.90, 'NCEP HiResWindow Modeled 250 mb Wind Speeds', $
      alignment='center', $
      /fill_background, $
      fill_color='white', $
      font_size=16)
   subtitle = text(0.30, 0.10, $
      'NCEP HiResWindow data from NOMADS!c(http://nomads.ncep.noaa.gov/)', $
      alignment='center', $
      /fill_background, $
      fill_color='white', $
      font_size=8)

   c1.order, /bring_to_front   
   w.refresh
   
   ; Optionally save result.
   if keyword_set(to_png) then $
      w.save, 'hires-alaska-winds-' + strtrim(r_u250.datadate,2) + '.png', $
         resolution=150
end


;+
; Example
;-
display_hires_alaska_winds, use_save_file=1, save=0
end

