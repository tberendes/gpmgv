pro rsl_fix_time, radar, isweep, iray

; Fixes seconds overflow in ray time.

compile_opt hidden

; Convert hours-minutes-seconds to seconds of day.
hour  = long(radar.volume[0].sweep[isweep].ray[iray].h.hour)
minute = long(radar.volume[0].sweep[isweep].ray[iray].h.minute)
seconds = radar.volume[0].sweep[isweep].ray[iray].h.sec

sec = hour*3600L + minute*60L + seconds
secondsinday = 3600L * 24L  ; Number of seconds in 24 hours.
if sec gt secondsinday then begin
    year  = radar.volume[0].sweep[isweep].ray[iray].h.year
    month = radar.volume[0].sweep[isweep].ray[iray].h.month
    day   = radar.volume[0].sweep[isweep].ray[iray].h.day
    ; Convert year-month-day to day-of-year and add overflow day.
    daysinmonth = [0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334]
    leap = (year mod 4 eq 0 and year mod 100 ne 0) or year mod 400 eq 0
    if leap then daysinmonth = [daysinmonth[0:1], daysinmonth[2:*]+1]
    day = daysinmonth[month-1] + day
    day = day + fix(sec / secondsinday) 
    ; If day gt days in year, adjust year.
    daysinyear = 365 + leap
    if day gt daysinyear then begin
        year = year + 1
	day = day - daysinyear
    endif
    ymd = ymd(day, year)
    radar.volume.sweep[isweep].ray[iray].h.month = ymd.month
    radar.volume.sweep[isweep].ray[iray].h.day   = ymd.day
    radar.volume.sweep[isweep].ray[iray].h.year  = ymd.year
    sec = sec - secondsinday
endif
; Convert seconds of day back to hours-minutes-seconds.
hour = fix(sec/3600.)
minute = fix((sec - hour*3600.)/60.)
seconds = sec - (hour*3600. + minute*60.)
radar.volume.sweep[isweep].ray[iray].h.hour  = hour
radar.volume.sweep[isweep].ray[iray].h.minute = minute
radar.volume.sweep[isweep].ray[iray].h.sec = seconds
end
