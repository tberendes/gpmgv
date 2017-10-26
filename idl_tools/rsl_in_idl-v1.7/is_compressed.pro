function is_compressed, filename, error=error

; This function returns value of true if file is compressed (based on file
; name extension) or false otherwise.
;
; Example:
;    if is_compressed(uffile) then tmpname = rsl_uncompress(uffile)
;

compile_opt hidden

on_error, 2
on_ioerror, ioerror

compressed = 0
if n_elements(error) eq 0 then error = 0

fnamextn = strmid(filename, strlen(filename)-3)
compressed = fnamextn eq '.gz' or strmid(fnamextn,1) eq '.z' or $
    strmid(fnamextn,1) eq '.Z'

; Also check for gzip magic number.
if not compressed then begin
    magic = bytarr(2)
    openr, iunit, filename, /get_lun
    readu, iunit, magic
    free_lun, iunit
    compressed = magic[0] eq '37'o and magic[1] eq '213'o
endif

return, compressed

ioerror:
if n_elements(iunit) ne 0 then free_lun, iunit
print, !error_state.msg
message,'I/O error occurred. Returning.',/informational
error = 1
return, compressed
end
