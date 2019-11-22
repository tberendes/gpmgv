; docformat = 'rst'
;+
; Gets the value of the key 'parameterName' for each record in a GRIB1/2 file.
; Typically this value is an index. Match this value with the parameter table 
; given by the originating data center for the file; e.g., for data from 
; NCEP, see::
;  http://www.nco.ncep.noaa.gov/pmb/docs/on388/table2.html
;  
; Examples of a few parameter values, abbreviations & names::
; 
;  index    abbreviation   parameter name
;  -----    ------------   --------------
;  157      CAPE           convective available potential energy
;  193      POP            probability of precipitation
;  121      LHTFL          latent heat net flux
;  71       TCDC           total cloud cover
; 
; Note: some GRIB files use not only the key 'parameterName', but also 
; 'inidicatorOfParameter', which may be a better key to match.
; 
; Use GRIB_GET_RECORD to read the data for a particular record (by index) 
; in a GRIB file.
; 
; :params:
;  grib_file: in, required, type=string
;   The path to a GRIB1/2 file.
;
; :returns:
;  An array of parameter values, as strings, in the order in which the
;  record is positioned in the GRIB file.
;
; :examples:
;  Get all the parameter names/indices from a GRIB file::
;     IDL> f = '/path/to/file.grb'
;     IDL> p = grib_get_parameternames(f)
;     
; :requires:
;  IDL 8.1
;
; :pre:
;  GRIB is currently supported only on Mac & Linux.
;  
; :author:
;	Mark Piper, ITT VIS, 2011
;	
; :version:
;  $Id: grib_get_parameternames.pro 505 2012-02-10 19:25:34Z mpiper $
;-
function grib_get_parameternames, grib_file
   compile_opt idl2
   
   if grib_file eq !null then return, !null
   
   file_id = grib_open(grib_file)
   n_records = grib_count(grib_file)
   i_record = 0
   parameter_index = list()
      
   ; Loop over records in file.
   while (i_record lt n_records) do begin
   
      h = grib_new_from_file(file_id)
      iter = grib_keys_iterator_new(h, /all)
      
      ; Loop over keys in record, looking for the parameter key. (See also 
      ; note above.)
      while grib_keys_iterator_next(iter) do begin
         key = grib_keys_iterator_get_name(iter)
         if strlowcase(key) eq 'parametername' then begin
            parameter_index.add, grib_get(h, key)
            break
         endif
      endwhile ; loop over keys in record
      grib_keys_iterator_delete, iter
      
      grib_release, h
      i_record++
      
   endwhile ; loop over records in file
   
   grib_close, file_id
   
   return, parameter_index.toarray()
end

