function rsl_which_struct, struct

;******************************************************************************
; Returns the name of the rsl structure given as argument.
; If argument isn't an rsl structure, an empty string is returned.
;
; Syntax:
;     struct_name = rsl_which_struct(structure)
;
; Return value is one of the following strings:
;    'RADAR' 
;    'VOLUME'
;    'SWEEP'
;    'RAY'
;    '' (Empty string)
;
; Example:
; Get a sweep from variable volume_or_sweep.  How the sweep is obtained depends
; on the structure in volume_or_sweep, which is returned by rsl_which_structure.
; 
; struct_name = rsl_which_struct(volume_or_sweep)
; if struct_name eq 'VOLUME' then begin
;    sweep = volume_or_sweep.sweep[i]
;     . . .
; endif else if struct_name eq 'SWEEP' then begin
;     sweep = volume_or_sweep
;     . . .
; endif else print, 'Wrong structure.'
;
; Written by: Bart Kelley, GMU, May 2007
;******************************************************************************

; Check if it's a structure.
typecode = size(struct,/type)
if typecode ne 8 then begin
    message, 'Argument must be a structure.',/continue
    return,''
end

names = tag_names(struct)
case names[1] of
    'VOLUME': struct_name = 'RADAR' 
    'SWEEP': struct_name = 'VOLUME'
    'RAY': struct_name = 'SWEEP'
    'RANGE': struct_name = 'RAY'
    else: begin
              struct_name = ''
	      message,'Unknown structure name: ' + names[1],/continue
          end
endcase

return, struct_name
end
