;+
; Copyright © 2011, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; FUNCTION TICKS_FROM_DATETIME( datetimestring)
;
; Converts a datetime specification into unix ticks, which are seconds
; elapsed since 1970-01-01 00:00:00. Input datetime is assumed to be in UTC,
; and must be a string in the format "YYYY-MM-DD hh:mm:ss" (with the space
; between the date and time sections, with the '-' and ':' delimiters as shown,
; and without the quotes in the string itself).
;
; HISTORY
; -------
; 3/23/11 - Morris/NASA/GSFC (SAIC), GPM GV:  Created.
;
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-

function ticks_from_datetime, datetimestring

  ; define an extended regular expression for the allowable form/values of the
  ; input datetime string, and check against it.  Year range = 1900-2099
   dtime_regex='19|20[0-9][0-9]-[0-1][0-9]-[0-3][0-9] [0-2][0-9]:[0-5][0-9]:[0-5][0-9]'
   IF ( NOT STREGEX(datetimestring, dtime_regex, /BOOLEAN) ) THEN GOTO, badDateString

  ; check for "extra stuff" before/after regex match.  Extra leading/trailing spaces
  ; do not affect the parsing results, so ignore them
   IF STRLEN(STRTRIM(datetimestring,2)) NE 19 THEN GOTO, badDateString

   parse1 = STRSPLIT( datetimestring, ' ', count=nfields, /extract )
   IF nfields NE 2 THEN GOTO, badDate

  ; get the year, month, and day values
   parsedate = STRSPLIT( parse1[0], '-', count=ndatefields, /extract )
   IF ndatefields NE 3 THEN GOTO, badDate
   yyyy = DOUBLE(parsedate[0])
   IF yyyy EQ 0d THEN BEGIN
      PRINT, "ticks_from_datetime(): Illegal year in first subfield of datetime: ", parsedate[0]
      GOTO, badDate
   ENDIF
   IF yyyy LT 1970 OR yyyy GT 2037 THEN BEGIN
      PRINT, "ticks_from_datetime(): Illegal year: ", parsedate[0], $
             ".  Year must be between 1970 and 2037."
      GOTO, badDate
   ENDIF
   mon = DOUBLE(parsedate[1])
   IF mon LT 1 OR mon GT 12 THEN BEGIN
      PRINT, "ticks_from_datetime(): Illegal month in second subfield of datetime: ", parsedate[1]
      GOTO, badDate
   ENDIF
   day = DOUBLE(parsedate[2])
   IF day EQ 0d THEN BEGIN
      PRINT, "ticks_from_datetime(): Illegal day in third subfield of datetime: ", parsedate[2]
      GOTO, badDate
   ENDIF
   leap = 0
   if( ((yyyy mod 4) eq 0) and ((yyyy mod 100) ne 0) $
	or ((yyyy mod 400) eq 0) ) then leap=1
   daysinmonth=[[31,28,31,30,31,30,31,31,30,31,30,31],[31,29,31,30,31,30,31,31,30,31,30,31]]
   IF day LT 1 or day GT daysinmonth[mon-1,leap] THEN BEGIN
      PRINT, "ticks_from_datetime(): Illegal day: ", parsedate[2], " for month ", $
             parsedate[1], " and year ", parsedate[0]
      GOTO, badDate
   ENDIF

  ; get the hour, minute, and second values
   parsetime = STRSPLIT( parse1[1], ':', count=ntimefields, /extract )
   IF ntimefields NE 3 THEN GOTO, badDate
   hour = DOUBLE(parsetime[0])
   IF (hour EQ 0d AND parsetime[0] NE '00') OR (hour LT 0 OR hour GT 23) THEN BEGIN
      PRINT, "ticks_from_datetime(): Illegal hour in fourth subfield of datetime: ", parsetime[0]
      GOTO, badDate
   ENDIF
   mins = DOUBLE(parsetime[1])
   IF (mins EQ 0d AND parsetime[1] NE '00') OR (mins LT 0 OR mins GT 59) THEN BEGIN
      PRINT, "ticks_from_datetime(): Illegal minute in fifth subfield of datetime: ", parsetime[1]
      GOTO, badDate
   ENDIF
   secs = DOUBLE(parsetime[2])
   IF (secs EQ 0d AND parsetime[2] NE '00') OR (secs LT 0 OR secs GT 59) THEN BEGIN
      PRINT, "ticks_from_datetime(): Illegal seconds in sixth subfield of datetime: ", parsetime[2]
      GOTO, badDate
   ENDIF

  ; convert to ticks
   ticks = unixtime( yyyy, mon, day, hour, mins, secs)
   GOTO, normal

   badDateString:
     print, 'ticks_from_datetime(): Illegal datetime value, must be 19 characters ', $
            ' in the format "YYYY-MM-DD hh:mm:ss".  Year must be between 1970 and 2037.'
   badDate:
     print, 'Datetime value given is "', datetimestring, '"'
     return, "Bad Datetime"

   normal:
     return, ticks

end
