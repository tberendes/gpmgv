;+
; Copyright © 2008, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; pro UNIX2DATETIME, ticks, year, month, day, hour, minute, second
;
; AUTHOR: 
; Bob Morris, GPM GV (SAIC), January 2007
;
; DESCRIPTION:
; Converts a datetime specification in unix ticks, which are seconds
; elapsed since 1-1-1970 00:00:00 UTC, to components of date and time.
;
; HISTORY
; -------
; 9/12/08 - Morris/NASA/GSFC (SAIC), GPM GV:  Changed secperday to type double.
;
; CONSTRAINTS:
; Input datetime is assumed to be in UTC.
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-

pro unix2datetime, ticks, year, month, day, hour, minute, second

jdayepoch = julday(1,1,1970,0,0,0)  ; fractional julian day at unix epoch
secperday = 24.0D * 60.0D * 60.0D
jsecepoch = jdayepoch * secperday   ; julian seconds at unix epoch
jsecs = jsecepoch + ticks
jday = jsecs / secperday      ; julian day at specified unixtime
caldat, jday, month, day, year, hour, minute, fracsecond
second = round(fracsecond + 0.0001)
;print, year, month, day, hour, minute, second, $
;       FORMAT = '(i0,"-",i02,"-",i02," ",i02,":",i02,":",i02)'

end
