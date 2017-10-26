;+
; Copyright © 2008, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; ***********************************************************************
; *                  Calendar to Julian day                             *
; ***********************************************************************
; * Program written by: David B. Wolff                                  *
; ***********************************************************************
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
	function get_julday, year, month, day, VERBOSE=verbose
	
	verbose = 0
	if(KEYWORD_SET(verbose)) then verbose=1
	daytab = intarr(2,13)
	daytab(0,*) = [0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334, 365]
	daytab(1,*) = [0, 31, 60, 91, 121, 152, 182, 213, 244, 274, 305, 335, 366]
	leap = 0
	if( ((year mod 4) eq 0) and ((year mod 100) ne 0) $
		or ((year mod 400) eq 0) ) then leap=1
	jday = day + daytab(leap,month-1)

	return,jday
	end
