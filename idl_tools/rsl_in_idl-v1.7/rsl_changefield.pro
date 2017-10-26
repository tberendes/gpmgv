pro rsl_changefield, struct, fromfield, tofield, from=from, to=to, $
    error=error

;**************************************************************************
; rsl_changefield
;
; This program changes the field type string that identifies a volume.  The
; field type is changed in the volume header and in all sweep headers in that
; volume.
;
; Syntax:
;    rsl_changefield, radar, from_field, to_field 
;    rsl_changefield, radar, FROM=from_field, TO=to_field
;    rsl_changefield, volume, [TO=]to_field
;
; Arguments:
;    radar:      a radar structure, used in first two calling forms above.
;    from_field: string specifying the field to be changed.  This value may
;                also be given using the FROM keyword.
;    to_field:   the new field string.  This value may also be specified using
;                the TO keyword.
;    volume:     a volume structure, used in third calling form above.
;
; Keyword parameters:
;     FROM:  the field to be changed.
;     TO:    the new field string.
;
; Examples:
;    Change ZD to DR:
;    rsl_changefield, radar, 'zd', 'dr'
;
;    Do the same using keywords:
;    rsl_changefield, radar, from='zd', to='dr'
;**************************************************************************

error = 0

if n_elements(fromfield) ne 0 then oldfield = strupcase(fromfield)
if n_elements(tofield) ne 0 then newfield = strupcase(tofield)
if n_elements(from) ne 0 then oldfield = strupcase(from)
if n_elements(to) ne 0 then newfield = strupcase(to)

names = tag_names(struct)
if names[1] eq 'VOLUME' then structype = 'radar' $
else if names[1] eq 'SWEEP' then structype = 'volume' $
else begin
    message,'Structure must be either radar or volume.',/continue
    goto, errexit
endelse

if structype eq 'radar' and n_elements(oldfield) eq 0 then begin
    message,'Field to be changed was not specified.',/continue
    goto, errexit
endif
 
if structype eq 'radar' then begin
    ivol = where(struct.volume.h.field_type eq oldfield, count)
    if count eq 0 then begin
        message,'Field ' + oldfield + ' not found.',/continue
        goto, errexit
    endif
    ivol = ivol[0] ; Make sure ivol is scalar.
    nsweeps = struct.volume[ivol].h.nsweeps
    struct.volume[ivol].h.field_type = newfield
    struct.volume[ivol].sweep[0:nsweeps-1].h.field_type = newfield
endif else begin
    nsweeps = struct.h.nsweeps
    ; This next line is for call of the form, rsl_changefield, volume, newfield.
    if n_elements(newfield) eq 0 and n_elements(oldfield) eq 1 then $
        newfield = oldfield
    struct.h.field_type = newfield
    struct.sweep[0:nsweeps-1].h.field_type = newfield
endelse

return

errexit:
error = 1
return

end
