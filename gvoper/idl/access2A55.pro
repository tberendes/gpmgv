;+
; AUTHOR:
;       Liang Liao
;       Caelum Research Corp.
;       Code 975, NASA/GSFC
;       Greenbelt, MD 20771
;       Phone: 301-614-5718
;       E-mail: lliao@priam.gsfc.nasa.gov
;+

pro access2A55, file=file_2a55, unlout=UNLOUT, VOL=nvol, nHeight=zlevel, Avg=avg_flag, $
                dbz2A55=threeDreflect_new, Hour=hrs, Min=min, Sec=sec, $
                Year=year, Month=mm, Day=dd

;
; Read 2a55 three dimensional reflectivity (dBZ) and volume scan times
; and parse date information from input 2a55 file name
;

;threeDreflect=intarr(151,151,13,20)   ;just define it with any value and dimension. 

read_2a55, file_2a55, hour, minute, second
;threeDreflect=threeDreflect/100.

;IF keyword_set(avg_flag) THEN BEGIN

; -- Averaging 2a55 to 4x4 km^2 for our level = zlevel, and scan volume = nvol

;  threeDreflect_new = threeDreflect[0:149,0:149,zlevel,nvol]
;  threeDreflect_new = 10.^(0.1*threeDreflect_new)
;  threeDreflect_new = REBIN(threeDreflect_new,75,75)
;  threeDreflect_new = 10.*ALOG10(threeDreflect_new) 
;

;ENDIF ELSE BEGIN

;  threeDreflect_new = threeDreflect[0:150,0:150,zlevel,nvol] 
  
;ENDELSE

; -- get the yr (yy), mon, day of the volscan from the filename
remove_path, file_2a55, file_only_2a55

void = ' '
site = ' '
year = ' '  
month = 0  & day = 0

reads, file_only_2a55, void, year, month, day, site, $
       format='(a5,i2,i2,i2,3x,a4)'
       
zero=""+string(0,format='(i1)')+""
twenty=""+string(20,format='(i2)')+""

if year lt 10 then yyyy = twenty+zero+""+string(year,format='(i1)')+""
if year ge 10 then yyyy = twenty+""+string(year,format='(i2)')+""

if month lt 10 then mm = zero+""+string(month,format='(i1)')+""
if month ge 10 then mm = ""+string(month,format='(i2)')+""

if day lt 10 then dd = zero+""+string(day,format='(i1)')+""
if day ge 10 then dd = ""+string(day,format='(i2)')+""

; -- get the hr, min, and sec fields of our volume scan = nvol
hrs = hour[nvol]
min = minute[nvol]
sec = second[nvol]

for i=0, N_ELEMENTS( hour ) - 1 do begin
  print, "mo day hrs min sec: ", mm, dd, hour[i], minute[i], second[i]
  if hour[i] ne -99 then begin
    if hour[i] lt 10 then hh = zero+""+string( hour[i],format='(i1)')+""
    if hour[i] ge 10 then hh = ""+string( hour[i],format='(i2)')+""
    if minute[i] lt 10 then mins = zero+""+string( minute[i],format='(i1)')+""
    if minute[i] ge 10 then mins = ""+string( minute[i],format='(i2)')+""
    if second[i] lt 10 then ss = zero+""+string( second[i],format='(i1)')+""
    if second[i] ge 10 then ss = ""+string( second[i],format='(i2)')+""
    printf, UNLOUT, file_only_2a55,"|",yyyy,"-",mm,"-",dd," ",hh,":",mins,":",ss,"+00"
    print, file_only_2a55,"|",yyyy,"-",mm,"-",dd," ",hh,":",mins,":",ss,"+00"
  endif else begin
    printf, UNLOUT, file_only_2a55,"|1970-01-01 00:00:00+00"
    print, file_only_2a55,"|1970-01-01 00:00:00+00"
  endelse
endfor

end

@read_2a55.pro
@remove_path.pro
