function rsl_open_radar_file, radarfile, error=error, _EXTRA=keywords

; Open radar file, uncompressing if necessary.  Function returns logical unit
; number.

on_error, 2

error = 0
iunit = -3 ; Initialize with a nonvalid unit. (-1 is stdout, -2 is stderr.)

if n_elements(radarfile) eq 0 then begin
    message, 'File name argument required.', /informational
    error = 1
    return, iunit
endif

if not file_test(radarfile) then begin
    message, 'No such file: "' + radarfile + '"', /informational
    error = 1
    return, iunit
endif

if is_compressed(radarfile, error=error) then begin
    if not error then tmp_file = rsl_uncompress(radarfile, error=error)
    if not error then openr, iunit, tmp_file, /get_lun, /delete, _EXTRA=keywords
endif else if not error then openr, iunit, radarfile, /get_lun, _EXTRA=keywords

return, iunit
end
