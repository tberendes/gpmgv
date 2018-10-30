function rsl_get_date_from_filename, filename

; This function returns a string containing the date from the file name.
; If no date is found, an empty string is returned.
;
; Written by Bart Kelley, GMU, August 2004
; Modified July 24, 2014 by BLK: Replaced call to rsl_basename with IDL's
; file_basename.
;            

date = ''
fname = file_basename(filename) ; remove path.

; Try date of the form yyyymmdd.
pos = stregex(fname,'[0-9]{8}',length=len)
; Try yymmdd.
if pos eq -1 then pos = stregex(fname,'[0-9]{6}',length=len)
; Try yyyy_mmdd.
if pos eq -1 then pos = stregex(fname,'[0-9]{4}_[0-9]{4}', $
    length=len)
if pos gt -1 then date = strmid(fname,pos,len)
; Remove '_' from date.
pos = strpos(date,'_')
if pos gt -1 then date = strmid(date,0,pos)+strmid(date,pos+1)

return, date
end
