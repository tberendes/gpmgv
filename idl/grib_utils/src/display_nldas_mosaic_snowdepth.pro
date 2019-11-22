; docformat = 'rst'
;+
; Displays the data values in a single snowdepth record read from an NLDAS-2
; Mosaic LSM GRIB 1 file.
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
;  The GRIB1 file 'NLDAS_MOS0125_H.A20120129.1200.002.grb' or the IDL 8.1 SAVE 
;  file 'nldas_mosaic_snowdepth.sav'.
;  
; :examples:
;  Run the example main attached to this program with::
;     IDL> .r display_nldas_mosaic_snowdepth
;     
; :author:
;	Mark Piper, VIS, 2012
;-
pro display_nldas_mosaic_snowdepth, use_save_file=use_save_file, save=to_png
   compile_opt idl2
   
   ; Read/restore data. Use data from a SAVE file if on Windows.
   if keyword_set(use_save_file) || !version.os_family eq 'Windows' then begin
      f = file_which('nldas_mosaic_snowdepth.sav', /include)
      restore, f, /verbose
   endif else begin
      f = file_which('NLDAS_MOS0125_H.A20120129.1200.002.grb', /include)
      snowdepth_id = 66 ; from NLDAS README
      snowdepth = read_nldas(f, snowdepth_id)
   endelse
   
   data = snowdepth.values*snowdepth.scalevaluesby + snowdepth.offsetvaluesby
   
   tol = 0.1
   data[where(abs(data-snowdepth.missingvalue) lt tol, /null)] = !values.d_nan
   
   ; I'm choosing to limit the data such that any snow depths greater than
   ; 5 m are visualized as 5 m.
   ; XXX ; print, snowdepth.maxmimum ; = 92.7 m ?!
   data <= 5.0
   
   w = window(dimensions=[800,600], buffer=keyword_set(to_png))
   w.refresh, /disable
   
   minlat = min(snowdepth.distinctlatitudes, max=maxlat)
   minlon = min(snowdepth.distinctlongitudes, max=maxlon)
   geolimits = [minlat, minlon, maxlat, maxlon]
   m = map('Orthographic', $
      limit=geolimits, $
      center_longitude=mean(snowdepth.distinctlongitudes), $
      center_latitude=mean(snowdepth.distinctlatitudes), $
      title='NLDAS-2 Mosaic LSM : Snow Depth', $
      /current)
      
   g = image(data, snowdepth.distinctlongitudes, snowdepth.distinctlatitudes, $
      grid_units='degrees', $
      /interpolate, $
      /overplot, $
      rgb_table=27)
      
   c_continents = mapcontinents(color='gray')
   c_lakes = mapcontinents(color='gray', /lakes)
;   c_states = mapcontinents(/usa, /hide)
;   c_states['Wisconsin'].hide = 0
;   c_states['Wisconsin'].color = [164,0,29] ; cardinal
   
   msn = [43.1, -89.4]
   s_msn = symbol(msn[1], msn[0], 'star', $
      /sym_filled, $
      sym_color=[164,0,29], $ ; cardinal
      label_string='Madison', $
      label_font_size=10, $
      /data)
      
   cb = colorbar(target=g, $
      title='Snow Depth [m]', $
      minor=3, $
      position=[0.55, 0.125, 0.95, 0.15])
      
   timestamp = string(snowdepth.datadate, snowdepth.datatime, $
      format='(i8,1x,i4.4,1x,"UTC")')
   t1 = text(0.1, 0.1, timestamp)
   t1 = text(0.1, 0.05, 'http://ldas.gsfc.nasa.gov', $
      font_size=10)
      
   w.refresh
      
   if keyword_set(to_png) then $
      g.save, 'nldas-mosaic-snowdepth-' + strtrim(snowdepth.datadate,2) + '.png', $
         resolution=150
end

; Example.
display_nldas_mosaic_snowdepth, use_save_file=1, save=0
end
