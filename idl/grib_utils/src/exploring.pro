f = file_which('NLDAS_MOS0125_H.A20120129.1200.002.grb')
p = grib_get_parameternames(f)
print, p

;snowdepth_id = 66                         ; by inspection of table on webpage
;irec = where(p eq snowdepth_id, /null)
;irec++                                    ; GRIB uses 1-based record number
;snowdepth = grib_get_record(f, irec, /structure)
;help

; print, snowdepth.gribeditionnumber ; GRIB 1

snowdepth_id = 66 ; from NLDAS README
;snowdepth = read_nldas(f, snowdepth_id)
;help, snowdepth

; Region of interest -- snow event in WI.
;roi = [42.0, -93.0, 48.0, -87.0]
msn = [43.1, -89.4] ; from Wikipedia

dir = '/home/mpiper/projects/GRIB-webinar/data'
files = file_search(dir, '*.grb', count=nfiles)

;foreach f, files do begin
;   snowdepth = read_nldas(f, snowdepth_id)
;   print, snowdepth.datadate
;   display_nldas_mosaic_snowdepth, snowdepth, /save
;endforeach

foreach f, files do begin
   ;print, file_basename(f)
   msn_snowdepth = nldas_find_nearest(f, snowdepth_id, msn[1], msn[0])
   print, mean(msn_snowdepth.val), stddev(msn_snowdepth.val)
endforeach

;msn_snowdepth = nldas_find_nearest(f, snowdepth_id, msn[1], msn[0])
;help, msn_snowdepth
;print, msn_snowdepth.lat
;print, msn_snowdepth.lon
;print, msn_snowdepth.val

end
