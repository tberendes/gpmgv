;+
; Copyright © 2008, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; FUNCTION FMTDATETIME(year, month, day, hour, minute, second, TZONE=tzone)
;
; DESCRIPTION
; -----------
; Returns a datetime string in the format "YYYY-MM-DD hh:mm:ss" given the
; individual components of the date and time.  Optionally appends the timezone
; specification ("+zz" or "-zz") to the datetime string for use in creating a
; database-compatible, fully-qualified datetime string, e.g.:
;
;   "2007-12-25 14:33:01+05"
;
; The hour of day must lie between 0 and 23, i.e., using a 24-hour clock.
; The tzone parameter is the number of hours to be added to the datetime to
; convert it to UTC.  For example, for a time in CST, tzone is 6, since UTC is
; 6 hours ahead of Central Standard Time.
;
; FORMATTING RULES FOR CENTURY according to 'year' parameter are as follows:
;
;   - if a 4-digit year is provided, it is used as-is
;   - if a 2-digit year is 70 or greater, 20th Century is assumed (e.g., 1978)
;   - if year is less than 70, 21st Century is assumed (e.g., 2023)
;   - if a >4-digit, 3-digit, or negative year is provided, ugliness ensues
;
; VALIDITY CHECKING is not done -- the input parameters are assumed to be
; valid date and time and time zone values.  ALL POSITIONAL PARAMETERS ARE
; REQUIRED AS INPUT (year through second).  Time Zone is the only optional
; parameter.
;
; HISTORY
; -------
; 3/21/11 - Morris/NASA/GSFC (SAIC), GPM GV
;  - Fixed bug in formatting when a 2-digit time zone is specified.  Also,
;    simplified the formatting for leading-zero cases by using the proper
;    FORMAT specification (e.g., '(i02)') rather than IF-ELSE tree.
;
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-

function fmtdatetime, year, month, day, hour, minute, second, TZONE=tzone

    dtimestring = ''
    if N_Params() NE 6 then GOTO, ErrorExit

   ; format the 4-digit year
    twenty = '20'
    nineteen = '19'
    if year gt 999 then begin
       yyyy = string(year,format='(i4)')
    endif else begin
       if year ge 70 then begin
          yyyy = nineteen+string(year,format='(i2)')
       endif else begin
          yyyy = twenty+string(year,format='(i02)')
       endelse
    endelse

;    print, "mo day hour min sec: ", mm, dd, hour, minute, second
    mm = string(month,format='(i02)')
    dd = string(day,format='(i02)')
    hh = string( hour,format='(i02)')
    mins = string( minute,format='(i02)')
    ss = string( second,format='(i02)')
    dtimestring = yyyy+"-"+mm+"-"+dd+" "+hh+":"+mins+":"+ss

   ; add the time zone specification, if called for
    if N_Elements(tzone) EQ 1 then begin
       if tzone lt 0 then begin
          tzstr = string(tzone,format='(i03)')
       endif else begin
          tzstr = '+'+string(tzone,format='(i02)')
       endelse
       dtimestring = dtimestring+tzstr
    endif

   ; do a minimal check on the datetime string contents
    IF STRPOS( dtimestring, '*' ) NE -1 THEN BEGIN
       print, "In fmtdatetime, error in datetime format result: ", dtimestring
       dtimestring = 'Input Error'
    ENDIF

ErrorExit:
return, dtimestring

end
