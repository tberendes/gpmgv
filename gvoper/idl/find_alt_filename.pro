function find_alt_filename, orig_file, alt_file

;===============================================================================
;  DESCRIPTION
;  Given a fully-qualified file name, determines whether the file is present, or
;  if not, whether an uncompressed version of the file is present if the given
;  filename indicates the file is/was compressed.  Returns 0 if the original or
;  uncompressed version is not found or if the given filename pattern matches 
;  more than one file.  If original filename is found, returns 1, and provides
;  the found filename in the caller-supplied argument 'alt_file'.  If an
;  uncompressed or alternately-compressed version of the file is found, returns
;  3, and provides the found alternate filename in the caller-supplied argument
;  'alt_file'.
;===============================================================================

;    orig_file =  '/data/prsubsets/1C21/1C21.061231.52004.6.sub-GPMGV1.hdf.gz'
    if ( n_params() ne 2 ) then begin
       message, 'Usage: status = find_alt_filename(File2Find, AltFilename)'
       return, 0
    endif

    if ( n_elements(orig_file) eq 0 ) then begin
       message, 'orig_file is undefined!'
       return, 0
    endif

    alt_file = ""
    infile = file_search(orig_file,COUNT=nf)
    if(nf eq 0) then begin
;      parse the file name to determine the suffix or type (.gz or .Z)
       a = strsplit(orig_file, '.', /extract)
       suffix = a(n_elements(a)-1)
       if(suffix eq 'gz' or suffix eq 'Z') then begin
;         Filename is for compressed file, remove extension and check existence
;         of uncompressed file or alternately-compressed file
          nmlen = strlen(orig_file)
          if(suffix eq 'gz') then begin
             file2find = STRMID( orig_file, 0, nmlen - 3)
             file2find2 = file2find + '.Z'
          endif else begin
             file2find = STRMID( orig_file, 0, nmlen - 2)
             file2find2 = file2find + '.gz'
          endelse
          infile = file_search(file2find,COUNT=nf)
          if(nf ne 1) then begin
             infile2 = file_search(file2find2,COUNT=nf2)
             if(nf2 ne 1) then begin
                print,'File not found/not unique: ' + file2find
                return, 0
             endif else begin
                alt_file = file2find2
                print, "Alt-compressed file " + file2find2 + ' found.'
                return, 3
             endelse
          endif else begin
             alt_file = file2find
             print, file2find + ' found.'
             return, 3
          endelse
       endif else begin
          print,'File not found: ' + orig_file
          return, 0
       endelse
    endif else begin
       if (nf eq 1) then begin
          alt_file = orig_file
          print, orig_file + ' exists as-is.'
          return, 1
       endif else begin
          print, 'File not found/not unique: ' + orig_file
          return, 0
       endelse
    endelse

end
