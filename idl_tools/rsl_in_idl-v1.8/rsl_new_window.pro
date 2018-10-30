pro rsl_new_window, xsize=xsize, ysize=ysize, _extra=extra

;+
; Open a new Direct Graphics window using the next available window index.
;
; Syntax
;     rsl_new_window [, xsize=xsize] [, ysize=ysize] [WINDOW keywords]
;
; Arguments
;     None
;
; Keywords
;     XSIZE: Window width in pixels.
;     YSIZE: Window height in pixels.
;     (See IDL Online Help for additional WINDOW procedure keywords.)
;
; Written by:  Bart Kelley, SSAI, May, 2012
;-

on_error, 2

; Check that device supports windows.

if (!d.flags and 256) eq 0 then begin
    message, "Can't use WINDOW procedure with this device.", /informational
    return
endif

; Find first available window index using the boolean array returned by
; DEVICE, WINDOW_STATE=array.  Array subscripts correspond to window indices.

device, window_state=windows
; Elements with value 0 indicate unused window indices.
unused = where(windows eq 0, count)
if count gt 0 then window, unused[0], xsize=xsize, ysize=ysize, _extra=extra

end
