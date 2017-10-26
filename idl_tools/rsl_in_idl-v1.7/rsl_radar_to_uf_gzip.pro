pro rsl_radar_to_uf_gzip, radar, uf_file, fields=fields, $
        force_owrite=force_owrite, error=error
;+
;***********************************************************************
; Write the data from a Radar structure to a file in Universal Format and
; compress the file using gzip.
;
; Syntax:
;     rsl_radar_to_uf_gzip, radar, uf_file [, FIELDS=string_array]
;         [, ERROR=variable] [, /FORCE_OWRITE]
;
; Inputs:
;     radar:    a Radar structure.
;     uf_file:  a string expression containing name of the output UF file
;               to be created. There's no need to include the '.gz' extension;
;               it will be added by gzip.
; Keywords:
;     ERROR:    Set this keyword to a variable to return the error status.
;               A value of 1 is returned for error, 0 otherwise.
;
;     FIELDS:   A string array (or scalar) containing the fields to be written
;               to the output file.  Default is all fields.  Fields are in the
;               form of the 2-character field names used by RSL, such as
;               'DZ', 'VR', etc.
;
;     FORCE_OWRITE: Set this keyword to overwrite an existing file regardless of
;                file permissions.  If not set, the file is overwritten only if
;                permitted.
;
; Requirements:
;     gzip must be installed on your system. If you don't have gzip, it is
;     available at http://www.gnu.org.
;**************************************************************************
;-

; Error handler.
catch, errcode
if errcode ne 0 then begin
    catch, /cancel
    print,!error_state.msg_prefix+!error_state.msg
    if !error_state.sys_msg ne '' then print, '  '+!error_state.sys_msg
    error = 1
    return
endif ; End of error handler

error = 0
outfile = uf_file

; If filename contains '.gz', remove it.  Suffix is added by gzip.

if strmid(uf_file,strlen(uf_file)-3) eq '.gz' then $
    outfile = strmid(uf_file,0,strlen(uf_file)-3)

; Write the UF file.
rsl_radar_to_uf, radar, outfile, fields=fields, force_owrite=force_owrite, $
    error=error

if error then begin
    print,"rsl_radar_to_uf_gzip: rsl_radar_to_uf returned error."
    print,"Skipping file compression."
    return
endif

; If UF file exists and is not writable, and FORCE_OWRITE keyword is not set,
; print message and exit.

gzfile = outfile + '.gz'
if file_test(gzfile) then begin
    if not file_test(gzfile,/write) and not keyword_set(force_owrite) then begin
	print, 'Error: rsl_radar_to_uf_gzip: File ' + gzfile + ' exists but'
	print, 'write permission is denied.'
	print, 'If you own the file, you can set keyword FORCE_OWRITE to overwrite.'
	print, 'Example:'
	print, '    rsl_radar_to_uf_gzip, radar, uffile, /force_owrite'
	error = 1
	return
    endif
endif

; TODO: Add error checking for gzip.
spawn, 'gzip -f ' + outfile, exit_status=exitstat ; gzip the file.
if exitstat ne 0 then error = 1
end
