;+
; Copyright © 2008, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; DESCRIPTION
; *** Returns hour,minute and second from second of the day.
; *** Can be array or scalar.
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
    function get_time_from_sotd,sotd,hh,mm,ss
    
    hh = fix(sotd/3600L)
    mm = fix(long(sotd) - hh*3600L)/60
;    ss = fix(60*(sotd - long(sotd)))
    ss = fix(sotd-hh*3600.-mm*60.+0.5)
    hh = strtrim(string(hh),2)
    mm = strtrim(string(mm),2)
    ss = strtrim(string(ss),2)

    a = where(hh lt 10,c)
    if(c gt 0) then hh(a) = '0' + hh(a)

    a = where(mm lt 10,c)
    if(c gt 0) then mm(a) = '0' + mm(a)

    a = where(ss lt 10,c)
    if(c gt 0) then ss(a) = '0' + ss(a)

    flag = 'OK'
    return,flag

    end

