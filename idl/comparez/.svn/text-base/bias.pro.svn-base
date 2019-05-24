;+
; Copyright © 2008, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; AUTHOR:
;       Liang Liao
;       Caelum Research Corp.
;       Code 975, NASA/GSFC
;       Greenbelt, MD 20771
;       Phone: 301-614-5718
;       E-mail: lliao@priam.gsfc.nasa.gov
; 
; -- Compute Bias of 2 measured quantities, such as Z(PR) and 
;    Z(GV), which is defined as 
;         Bias=1/N*SUM(Zi(PR)-Zi(GV))
;
;  Input:
;     xdata   one dimentional array
;     ydata   one dimentional array
;
;  Output:
;     bias   real 
;
;  Optional:
;     if range_min defined, proceed the standard error for the
;     subrange specified by range_min (low end) and range_max (high end).
;     Output will be bias_set.
;
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-

pro bias, xdata, ydata, BIAS=bias, $
          MIN=range_min, MAX=range_max, STD_SET=bias_set, nPoint_SET=nCount

sizeOf_x = SIZE(xdata,/dimension)
sizeOf_xdata = sizeOf_x[0]

bias = -999.
nCount = 0L
IF keyword_set(range_min) THEN BEGIN

  sizeOf_range0 = SIZE(range_min,/dimension)
  sizeOf_range = sizeOf_range0[0]
  
  bias_set = fltarr(sizeOf_range)
  bias_set[*]=-999.
  
ENDIF

IF sizeOf_xdata eq 0 THEN RETURN

bias = 1./sizeOf_xdata*TOTAL(ydata-xdata)

IF keyword_set(range_min) THEN BEGIN

 sizeOf_range0 = SIZE(range_min,/dimension)
 sizeOf_range = sizeOf_range0[0]
 
 xdata_set = fltarr(sizeOf_range, sizeOf_xdata)
 ydata_set = fltarr(sizeOf_range, sizeOf_xdata)
 
 count = lonarr(sizeOf_range)  &  count[*]=-1L
 nCount = count
 
 for n=0L, sizeOf_xdata-1 do begin
   for m=0L, sizeOf_range-1 do begin
     if (xdata[n] ge range_min[m]) and (xdata[n] lt range_max[m]) then begin
        count[m]=count[m]+1L
        xdata_set[m,count[m]]=xdata[n]
        ydata_set[m,count[m]]=ydata[n]
        goto, EXIT
     endif
   endfor
   EXIT:
 endfor
 
 nCount = count+1L
 
 diff_set = fltarr(sizeOf_range, sizeOf_xdata)
 diff_set = ydata_set - xdata_set
 
 for m=0L, sizeOf_range-1L do begin
   if (count[m]+1L) gt 0 then begin
     bias_set[m] = 1./(count[m]+1.)*TOTAL(diff_set[m,0:count[m]]) 
   endif
 endfor
 
ENDIF                   

end
