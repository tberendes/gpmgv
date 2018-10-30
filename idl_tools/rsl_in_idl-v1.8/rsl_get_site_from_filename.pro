function rsl_get_site_from_filename, filename

; This function returns a string containing the radar site name as found in the
; file name.  The search pattern for the site name is an uppercase string of 4
; alphabetic characters. If site name is not found, an empty string is returned.
;
; Written by Bart Kelley, GMU, August 2004
; Modified July 24, 2014 by BLK: Replaced call to rsl_basename with IDL's
; file_basename.
;            
site = ''
fname = file_basename(filename) ; remove path.
site=stregex(fname,'[A-Z]{3,4}',/extract)
return, site
end
