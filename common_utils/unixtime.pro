;+
; Copyright © 2008, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; FUNCTION UNIXTIME(year, month, day, hour, minute, second)
;
; Converts a datetime specification into unix ticks, which are seconds
; elapsed since 1-1-1970 00:00:00.  Returns DOUBLE value, as driven by
; arguments passed to JULDAY.
;
; Input datetime is assumed to be in UTC.
;
; HISTORY
; -------
; 9/12/08 - Morris/NASA/GSFC (SAIC), GPM GV:  Changed secperday to type double.
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-

function unixtime, year, month, day, hour, minute, second

jdayepoch = julday(1,1,1970,0,0,0)  ; fractional julian day at unix epoch
secperday = 24.0D * 60.0D * 60.0D
jsecepoch = jdayepoch * secperday   ; julian seconds at unix epoch
jday_in = julday(month,day,year,hour,minute,second)
jsecs_in = jday_in * secperday      ; julian seconds at specified datetime
return, jsecs_in - jsecepoch        ; unix ticks, secs since 1-1-1970 00:00:00

end
