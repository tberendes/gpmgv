FUNCTION dtime_fields_from_UF_filename, filename, DTIMESTR=ufdtimestr, $
                                        TICKS=ufdtimeticks

   IF N_PARAMS() NE 1 THEN BEGIN
      PRINT, "Expected one parameter in dtime_fields_from_UF_filename(), got ", N_PARAMS()
      return, "Error"
   ENDIF

   parsed = STRSPLIT( filename, '.', COUNT=nparsed, /EXTRACT)
   IF nparsed LT 6  THEN BEGIN
      PRINT, "Expected at least 6 filename parts in dtime_fields_from_UF_filename(), got ", nparsed
      PRINT, "Filename provided: ", filename
      return, "Error"
   ENDIF

   yymmdd = parsed[0]
   hhmm = parsed[4]
   numtest1 = DOUBLE(yymmdd)
   IF numtest1 EQ 0d THEN BEGIN
      PRINT, "Illegal YYMMDD in first subfield of file name: ", filename
      return, "Error"
   ENDIF
   numtest2 = DOUBLE(hhmm)
   IF (numtest2 EQ 0d AND hhmm NE '0000') OR numtest2 GE 2400d THEN BEGIN
      PRINT, "Illegal HHMM in fifth subfield of file name: ", filename
      return, "Error"
   ENDIF

   century = '20'
   IF numtest1 GT 900000d THEN century = '19'

   IF N_ELEMENTS(ufdtimestr) EQ 1 THEN BEGIN
     ufdtimestr=century+STRMID(yymmdd,0,2)+'-'+STRMID(yymmdd,2,2)+'-' $
         +STRMID(yymmdd,4,2)+' '+STRMID(hhmm,0,2)+':'+STRMID(hhmm,2,2)+':00+00'
   ENDIF

   IF N_ELEMENTS(ufdtimeticks) EQ 1 THEN BEGIN
     year=FIX(century+STRMID(yymmdd,0,2))
     month=FIX(STRMID(yymmdd,2,2))
     day=FIX(STRMID(yymmdd,4,2))
     hour=FIX(STRMID(hhmm,0,2))
     mins=FIX(STRMID(hhmm,2,2))
     secs=0
     ufdtimeticks = unixtime( year, month, day, hour, mins, secs )
   ENDIF

return, yymmdd+"_"+hhmm
END
