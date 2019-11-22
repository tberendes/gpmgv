; docformat = 'rst'
;+
; Reads the metadata and values for a specified parameter in an NLDAS-2 
; GRIB 1 file.
;
; Info on NLDAS::
;  http://ldas.gsfc.nasa.gov
;
; README for info on NLDAS GRIB parameters::
;  ftp://hydro1.sci.gsfc.nasa.gov/data/s4pa/NLDAS/README.NLDAS2.pdf
;
; :params:
;  nldas_file: in, required, type=string
;     The path to an NLDAS GRIB file.
;  parameter_id: in, required, type=integer or string
;     The parameter identifier for the record to read from the NLDAS GRIB file.
;
; :returns:
;  A structure variable (or, if multiple parameters are matched, an array of
;  structures) containing the parameter's metadata & values.
;
; :requires:
;  IDL 8.1
;
; :uses:
;  GRIB_GET_PARAMETERNAMES, GRIB_GET_RECORD
;
; :pre:
;  GRIB is currently supported only on Mac & Linux.
;
; :author:
;	Mark Piper, VIS, 2012
;-
function read_nldas, nldas_file, parameter_id
   compile_opt idl2
   
   all_ids = grib_get_parameternames(nldas_file)
   
   irec = where(all_ids eq parameter_id, nrec, /null)
   if nrec eq 0 then begin
      msg = 'Parameter ' + strtrim(parameter_id,2) + ' not found. Returning.'
      message, msg, /informational
      return, !null
   endif

   irec++ ; GRIB_GET_RECORD uses 1-based record numbers   
   d = {} ; slow, but simple
   foreach id, irec do $
      d = [d, grib_get_record(nldas_file, id, /structure)]

   return, d
end

; Example.
f = file_which('NLDAS_MOS0125_H.A20120129.0000.002.grb')
snowdepth_id = 66 ; from NLDAS README
snowdepth = read_nldas(f, snowdepth_id)
help, snowdepth
end
