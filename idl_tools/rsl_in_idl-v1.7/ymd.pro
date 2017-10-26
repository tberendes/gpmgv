	function ymd, jday, year, VERBOSE=verbose
; ***********************************************************************
; *                  Julian to Calendar day                             *
; ***********************************************************************
; * Program written by: David B. Wolff                                  *
; ***********************************************************************
	verbose = 0
	if(KEYWORD_SET(verbose)) then verbose=1

	daytab = intarr(2,13)
	daytab(0,*) = [0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334, 365]
	daytab(1,*) = [0, 31, 60, 91, 121, 152, 182, 213, 244, 274, 305, 335, 366]
	leap = 0
	if(((year mod 4) eq 0) and ((year mod 100) ne 0) $
		or ((year mod 400) eq 0)) then leap=1
	month = where(jday le daytab(leap,*))
	month = month(0) 
	day = jday - daytab(leap,month-1)
	date = {year: year, month: month, day: day, julday: jday}
	if(verbose eq 1) then print,'Date= ',month, day, year
	return,date
	end

