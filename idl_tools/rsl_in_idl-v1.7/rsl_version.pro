pro rsl_version, version=version, quiet=quiet

;***********************************************************************
;+
; Print RSL-in-IDL version number.
;
; Syntax:
;     rsl_version [, VERSION=variable] [, /QUIET]
;
; Keyword parameters:
;     VERSION:
;         Set this keyword to a variable to have version number returned
;         as a string.
;     QUIET:
;         Set this keyword to suppress printing of version number.
;-
;***********************************************************************
;

catch, errcode
if errcode ne 0 then begin
    catch, /cancel
    print,!error_state.msg_prefix+!error_state.msg
    if !error_state.sys_msg ne '' then print, '  '+!error_state.sys_msg
    if n_elements(lunit) ne 0 then begin
        free_lun, lunit
        print, 'A problem occurred reading version file.'
    endif
    catch, /cancel
    return
endif

; Get the name of the file containing version number.
vfile = file_dirname(file_which('rsl_anyformat_to_radar.pro'),/mark_dir) + $
    'VERSION.txt'

version=''
if file_test(vfile) then begin
    openr, lunit, vfile, /get_lun
    readf, lunit, version 
    free_lun, lunit
endif else begin
    if not keyword_set(quiet) then message, 'No such file: ' + vfile, $
        /informational
endelse

if not keyword_set(quiet) then print, 'RSL in IDL Version ', $
    (version ne '') ? version : 'UNKNOWN'

end
