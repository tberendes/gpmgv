pro jul2cal, julianr,month,day,year

; Translated from FORTRAN subroutine jul2cal.f into IDL.

;   Convert NEXRAD julian date (relative to 1/1/1970) to calendar date (m/d/y).
;   Uses the equations in the NEXRAD subroutines T41193 and A3CM38
; 
;   Input:
;      julianr - Julian date (relative to 1/1/1970)
; 
;   Output:
;      month - month (1-12)
;      day - day (1-31)
;      year - year (YYYY, e.g., 1999)
; 
      
      julian=0L & iyear=0L & jmonth=0L & kday=0L & l=0L & n=0L & baseyr=0L

      baseyr=2440587L

      julian = julianr

      julian = baseyr + julian
      l = julian + 68569
      n = 4*l/146097
      l = l - (146097*n + 3)/4
      iyear = 4000*(l+1)/1461001
      l = l - 1461*iyear/4 + 31
      jmonth = 80*l/2447
      kday = l -2447*jmonth/80
      l = jmonth/11
      jmonth = jmonth + 2 - 12*l
      iyear = 100*(n-49) + iyear + l    

      month = jmonth
      day = kday
      year = iyear

      end
