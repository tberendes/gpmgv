; docformat = 'rst'
;+
; Given a NLDAS GRIB file, a parameter identifier and a lat-lon location, 
; this function finds the four lat-lon points, and the parameter value at 
; those points, bracketing the desired location, using GRIB_FIND_NEAREST.
;
; :params:
;  file: in, required, type=string
;     The path to an NLDAS GRIB file.
;  parameter_id: in, required, type=integer
;     A parameter identifier in an NLDAS file.
;  lon: in, required, type=numeric
;     The longitude of the desired point.
;  lat: in, required, type=numeric
;     The latitude of the desired point.
;
; :requires:
;  IDL 8.1
;
; :uses:
;  GRIB_GET_PARAMETERNAMES
;  
; :author:
;	Mark Piper, ITT VIS, 2011
;-
function nldas_find_nearest, nldas_file, parameter_id, lon, lat
   compile_opt idl2
   
   all_ids = grib_get_parameternames(nldas_file)
   
   irec = where(all_ids eq parameter_id, nrec, /null)
   if nrec eq 0 then begin
      msg = 'Parameter ' + strtrim(parameter_id,2) + ' not found. Returning.'
      message, msg, /informational
      return, !null
   endif
   
   ; FIXME: Use only the first record with the given parameter id.
   irec = irec[0]

   n_records = grib_count(nldas_file)
   h_record = lonarr(n_records)
   
   fid = grib_open(nldas_file)
   for i=0, n_records-1 do h_record[i] = grib_new_from_file(fid)
   
   grib_find_nearest, h_record[irec], lon, lat, $
      latitudes=glats, $
      longitudes=glons, $
      values=gvals
      
   foreach h, h_record do grib_release, h
   grib_close, fid
   
   return, {lat:glats, lon:glons, val:gvals}
end
