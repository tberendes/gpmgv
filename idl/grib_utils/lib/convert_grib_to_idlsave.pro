; docformat = 'rst'
;+
; Makes a compressed IDL SAVE file from a GRIB1/2 file. Handy if you
; need to work with data from a GRIB file in IDL on Windows.
; 
; A typical GRIB1 NLDAS Mosaic file is 5 MB. The compressed IDL SAVE file 
; that holds the same data is 25 MB!
; 
; :params:
;  grib_file: in, required, type=string
;     The path to a GRIB1/2 file.
;
; :examples:
;  Convert a GRIB file to an IDL SAVE file with::
;     IDL> f = '/path/to/file.grb'
;     IDL> convert_grib_to_idlsave, f
;     
; :uses:
;  READ_GRIB
;  
; :requires:
;  IDL 8.1
;
; :author:
;	Mark Piper, VIS, 2012
;	
; :version:
;  $Id: convert_grib_to_idlsave.pro 505 2012-02-10 19:25:34Z mpiper $
;-
pro convert_grib_to_idlsave, grib_file
   compile_opt idl2
   
   all = read_grib(grib_file)
   save, all, /compress, filename=file_basename(grib_file, '.grb') + '.sav'
end
