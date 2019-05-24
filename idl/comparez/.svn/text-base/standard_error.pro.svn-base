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
; DESCRIPTION: 
; -- Compute standard error, defined in book entitled "Probability and
;    Statistics for Engineers" by Irwin Miller and John E. Freund.
;
;  Input:
;     xdata   one dimentional array
;     ydata   one dimentional array
;
;  Output:
;     std_error   real (standard error)
;
;  Optional:
;     if range_min defined, proceed the standard error for the
;     subrange specified by range_min (low end) and range_max (high end).
;     Output will be std_error_set.
;
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-


pro standard_error, xdata, ydata, STD_ERROR=std_error, $
                    MIN=range_min, MAX=range_max, STD_SET=std_error_set

sizeOf_x = SIZE(xdata,/dimension)
sizeOf_xdata = sizeOf_x[0]

IF keyword_set(range_min) THEN BEGIN

  sizeOf_range0 = SIZE(range_min,/dimension)
  sizeOf_range = sizeOf_range0[0]

  std_error_set = fltarr(sizeOf_range)
  std_error_set[*]=-1.

ENDIF
 
if sizeOf_xdata le 2 then begin
  std_error=-1.
  return
endif

x=fltarr(1,sizeOf_xdata)

x[0,*]=xdata[*]
y=ydata
weights=replicate(1.,sizeOf_xdata)

result=REGRESS(x, y, weights, yfit, const, /RELATIVE_WEIGHT)

Y_diff2 = (y-yfit)^2
std_error = SQRT(1./(sizeOf_xdata-2.)*TOTAL(Y_diff2))

IF keyword_set(range_min) THEN BEGIN
 
 xdata_set = fltarr(sizeOf_range, sizeOf_xdata)
 ydata_set = fltarr(sizeOf_range, sizeOf_xdata)
 yfit_set = fltarr(sizeOf_range, sizeOf_xdata)
 
 count = lonarr(sizeOf_range)  &  count[*]=-1L
 
 for n=0L, sizeOf_xdata-1 do begin
   for m=0L, sizeOf_range-1 do begin
     if (xdata[n] ge range_min[m]) and (xdata[n] lt range_max[m]) then begin
        count[m]=count[m]+1L
        xdata_set[m,count[m]]=xdata[n]
        ydata_set[m,count[m]]=ydata[n]
        yfit_set[m,count[m]]=yfit[n]
        goto, EXIT
     endif
   endfor
   EXIT:
 endfor
 
 Y_diff2_set = fltarr(sizeOf_range, sizeOf_xdata)
 
 for m=0L, sizeOf_range-1 do begin
   if (count[m]+1L) gt 2L then begin
     Y_diff2_set[m,0:count[m]] = $
             (ydata_set[m,0:count[m]]-yfit_set[m,0:count[m]])^2
     std_error_set[m] = $
             SQRT(1./((count[m]+1.)-2.)*TOTAL(Y_diff2_set[m,0:count[m]])) 
   endif
 endfor
 
ENDIF                   

end
