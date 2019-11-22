; docformat = 'rst'
;+
; An attempt at a generic GRIB reader. This function uses multiple calls to
; GRIB_GET_RECORD to read all the records in a GRIB1/2 file, returning a 
; single list with a structure for each record. This assumes the data in 
; the file can fit into memory in IDL. 
;
; :params:
;  grib_file : in, required, type=string
;   The path to a GRIB1/2 file.
;
; :returns:
;  A list containing a structure for each record in the GRIB file.
;
; :examples:
;  Read all the data from a GRIB file with::
;     IDL> f = '/path/to/file.grb'
;     IDL> d = read_grib(f)
;
; :requires:
;  IDL 8.1
;
; :uses:
;  GRIB_GET_RECORD
;  
; :pre:
;  GRIB is currently supported only on Mac & Linux.
;
; :author:
;	Mark Piper, VIS, 2011
;	
; :version:
;  $Id: read_grib.pro 503 2012-02-08 21:58:14Z mpiper $
;-
function read_grib, grib_file
   compile_opt idl2
   
   cond1 = strlowcase(!version.os_family) eq 'windows'
   cond2 = float(!version.release) lt 8.1
   if cond1 || cond2 then begin
      msg = 'IDL''s GRIB API requires 8.1; Mac OS X or Linux.'
      message, msg, /noname, /informational
      return, !null
   endif
   
   if grib_file eq !null then return, !null
     
   n_records = grib_count(grib_file)
   data = list()
   for i=1, n_records do $ ; use GRIB's 1-based indexing
      data.add, grib_get_record(grib_file, i, /structure)
   
   return, data
end

