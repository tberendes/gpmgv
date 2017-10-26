function rsl_get_volume, radar, volume_id

;+
; This function returns the requested volume, or the first volume
; in radar structure if volume_id is omitted.  If volume is not found,
; the function returns -1.
;
; Syntax:
;     volume = rsl_get_volume(radar, volume_id)
;
; Inputs:
;     radar:     a radar structure.
;     volume_id: can be either a string containing the field type, for example,
;                'DZ', or the index number of the volume (0 to nvols-1).
;                If omitted, first volume in the radar structure is returned.
;-

on_error, 2

volid = 0
if n_elements(volume_id) eq 0 then goto, finished

volid = volume_id
id_part = ''
string_type = 7 ; IDL type code for string
; Volume ID given as string
if size(volid,/type) eq string_type then begin
    fields = rsl_get_fields(radar)
    volid = where(strcmp(fields, volid, /fold_case))
    volid = volid[0] ; make sure it's scalar.
    id_part = ' for ' + volume_id + '.'
endif

; If requested field is not found, check that it isn't simply a case of
; different field name for differential reflectivity (DR or ZD).  If that
; is the case, substitute the other field.

if volid lt 0 then begin
    if strupcase(volume_id) eq 'DR' then volid = where(fields eq 'ZD')
    if strupcase(volume_id) eq 'ZD' then volid = where(fields eq 'DR')
    if volid ge 0 then begin
       message, strupcase(volume_id) + ' not found, substituting ' + $
           fields(volid), /informational
    endif
endif

if volid lt 0 or volid gt radar.h.nvolumes-1 then begin
    message, 'Volume not found' + id_part, /continue
    if volid gt radar.h.nvolumes-1 then $
    print, strtrim(radar.h.nvolumes-1,1), format='("  Requested volume ' + $
        'index exceeds highest index (",a,").")'
    return, -1
endif

finished: return, radar.volume[volid]

end
