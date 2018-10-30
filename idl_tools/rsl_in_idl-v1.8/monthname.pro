function monthname, monthnumber

; Return month name given month number (1 to 12).
; Written by:  Bart Kelley, GMU, April 2002

moname=['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']
return, moname[monthnumber-1]
end
