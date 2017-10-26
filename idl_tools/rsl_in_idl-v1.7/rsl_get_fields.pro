function rsl_get_fields, radar

; This function returns a string array containing the field type for each
; volume in the radar structure.  The array subscript for each field type
; matches the corresponding subscript in the volume array.
; Field types are in uppercase.
;
; Example: Get the volume for reflectivity.
;
;    fields = rsl_get_fields(radar)
;    idz = where(fields eq 'DZ')
;    if idz gt -1 then v = radar.volume[idz]

return, radar.volume.h.field_type
end
