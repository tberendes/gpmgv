pro grib_model_sounding, gribfilepath

if n_elements( gribfilepath ) ne 1 then $
   gribfilepath = '/data/GRIB/NAMANL/namanl_218_20100601_0600_000.grb'

file_2do = gribfilepath

site_arr = ['KBMX','KCLX']
lat_arr = [33.1722, 32.6556]
lon_arr = [-86.7697, -81.0422]

      file_id = grib_open( file_2do )
      n_records = grib_count( file_2do )
      if n_records lt 1 then begin
         msg = 'No GRIB messages found in file: '+gribfile
         message, msg
      endif
     ; Container for handle of each record in the file. Note this array is zero-based.
      h_record = lonarr(n_records)
      i_record = 0
      parameter_index = list()
      parm_indicator = list()
      leveltype_ind = list()
      leveltype = list()
      levelvalue = list()
      
      ; Loop over records in file.
      while (i_record lt n_records) do begin
   
         h = grib_new_from_file(file_id)
         h_record[i_record] = h  ; store handle in array for later
         iter = grib_keys_iterator_new(h, /all)
      
         ; Loop over keys in record, looking for the parameter key. (See also 
         ; note above.)
         while grib_keys_iterator_next(iter) do begin
            key = grib_keys_iterator_get_name(iter)
            CASE key OF
               'parameterName' : parameter_index.add, grib_get(h, key)
               'indicatorOfParameter' : parm_indicator.add, grib_get(h, key)
               'indicatorOfTypeOfLevel' : leveltype_ind.add, grib_get(h, key)
               'typeOfLevel' : leveltype.add, grib_get(h, key)
               'level' : levelvalue.add, grib_get(h, key)
               'levels' : levelvalue.add, grib_get(h, key)
               ELSE : break
            ENDCASE
         endwhile ; loop over keys in record

         grib_keys_iterator_delete, iter
         ;grib_release, h
         i_record++
      
      endwhile ; loop over records in file

     ; find the records with data on isobaric surfaces
      isobar_lev_idx=where(LEVELTYPE_IND EQ 'pl', countisolevs)
      if countisolevs eq 0 then begin
         msg = 'No isobaric level GRIB messages found in file: '+gribfile
         GOTO, errorExit
      endif

     ; find the records with isobaric Temperature, RH, u, and v

      iso_temp_idx=WHERE(PARM_INDICATOR[isobar_lev_idx] EQ 11, countisotemp)
      if countisotemp eq 0 then begin
         msg = 'No isobaric level temperature GRIB messages found in file: '+gribfile
         GOTO, errorExit
      endif
      iso_temp_msgs = h_record[isobar_lev_idx[iso_temp_idx]]
      temp_miss = grib_get(iso_temp_msgs[0], 'missingValue')

      iso_rh_idx=WHERE(PARM_INDICATOR[isobar_lev_idx] EQ 52, countisorh)
      if countisorh eq 0 then begin
         msg = 'No isobaric level Relative Humidity GRIB messages found in file: '+gribfile
         GOTO, errorExit
      endif
      if countisorh ne countisotemp then begin
         msg = 'Different number of isobaric Temperature and RH levels in file: '+gribfile
         GOTO, errorExit
      endif
      iso_rh_msgs = h_record[isobar_lev_idx[iso_rh_idx]]
      rh_miss = grib_get(iso_rh_msgs[0], 'missingValue')

      iso_uwind_idx=WHERE(PARM_INDICATOR[isobar_lev_idx] EQ 33, countisouwind)
      if countisouwind eq 0 then begin
         msg = 'No isobaric level U-wind GRIB messages found in file: '+gribfile
         GOTO, errorExit
      endif
      if countisouwind ne countisotemp then begin
         msg = 'Different number of isobaric Temperature and U-wind levels in file: '+gribfile
         GOTO, errorExit
      endif
      iso_uwind_msgs = h_record[isobar_lev_idx[iso_uwind_idx]]
      uwind_miss = grib_get(iso_uwind_msgs[0], 'missingValue')

      iso_vwind_idx=WHERE(PARM_INDICATOR[isobar_lev_idx] EQ 34, countisovwind)
      if countisovwind eq 0 then begin
         msg = 'No isobaric level V-wind GRIB messages found in file: '+gribfile
         GOTO, errorExit
      endif
      if countisovwind ne countisotemp then begin
         msg = 'Different number of isobaric Temperature and V-wind levels in file: '+gribfile
         GOTO, errorExit
      endif
      iso_vwind_msgs = h_record[isobar_lev_idx[iso_vwind_idx]]
      vwind_miss = grib_get(iso_vwind_msgs[0], 'missingValue')

; -------------------------------------------------------------------

     ; set up structures to hold the site soundings, loop through
     ; the site/lat/lon arrays, and extract site soundings

      tempsnd = make_array(countisotemp, /FLOAT, VALUE=temp_miss)
      rhsnd = make_array(countisotemp, /FLOAT, VALUE=rh_miss)
      uwindsnd = make_array(countisotemp, /FLOAT, VALUE=uwind_miss)
      vwindsnd = make_array(countisotemp, /FLOAT, VALUE=vwind_miss)
      sndlevel = make_array(countisotemp, /FLOAT, VALUE=9999.)

      site_snd = { site_sounding, $
                   site : 'UNDEFINED', $
                   latitude : -999., $
                   longitude : -999., $
                   n_levels : countisotemp, $
                   levels : sndlevel, $
                   temperatures : tempsnd, $
                   RH : rhsnd, $
                   uwind : uwindsnd, $
                   vwind : vwindsnd }

      site_snd_list = list()

      nsites = N_ELEMENTS( site_arr )
      for isite = 0, nsites-1 do begin
         this_snd = site_snd
         this_snd.site = site_arr[isite]
         this_snd.latitude = lat_arr[isite]
         this_snd.longitude = lon_arr[isite]

        ; get the temperature values near the site, and the isolevel values

         levelidx=0
         foreach h, iso_temp_msgs do begin
            if levelidx GT (this_snd.n_levels-1) then begin
               msg = "Too many temperature messages for structure allocation."
               print, "levelidx, this_snd.n_levels-1: ",levelidx, this_snd.n_levels-1
               GOTO, errorExit
            endif
            this_snd.levels[levelidx]=FLOAT(grib_get(h, 'level'))
            GRIB_FIND_NEAREST, h, this_snd.longitude, this_snd.latitude, VALUES=temp_near
            idx2avg = where( temp_near ne temp_miss, count2avg )
            if count2avg gt 0 then this_snd.temperatures[levelidx]=mean(temp_near[idx2avg])
            levelidx++
         endforeach

      endfor

; -------------------------------------------------------------------

      errorExit:

     ; Release all the handles and close the file.
      foreach h, h_record do grib_release, h
      grib_close, file_id


stop
end
