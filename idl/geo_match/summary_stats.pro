FUNCTION SUMMARY_STATS,data_linear,data_uncensored,weights=weights,log_in=log_in,scale=scale
;compute statistics of censored data
;data_linear=sample data (uncensored+imputed) in linear units
;data_uncensored=uncensored sample data in original units (used for getting max)
;weights=weights for each data_linear to apply
;returns mean,stdev,max
  n=size(data_linear,/n_elements)
  IF not keyword_set(log_in) then log_in=0B
  IF not keyword_set(scale) then scale=1.0
  IF(n lt 3) THEN return,{mean:-999.,std:-999.,max:-999.} ;need at least 3 points to compute stats 
  IF not keyword_set(weights) THEN BEGIN ;check array existance
      weights=make_array(n,/float)+1.0 ;create array of weights=1.0    
  ENDIF
  ind=where(weights gt 0,cnt)
  if (cnt GT 0) then begin
  	 data_linear=data_linear[ind]
  	 weights=weights[ind]
  endif else begin
     max_uncensored=max(data_uncensored) 
     IF(log_in) THEN BEGIN
       max_uncensored=1.0/scale*alog10(max_uncensored)
     endif 
     return,{mean:-999.,std:-999.,max:max_uncensored}
  endelse
  
  avg=total(data_linear*weights)*1.0/total(weights)   
  ;sample variance (1-degree of freedom)         
  var=(total(weights*(data_linear-avg)^2))/total(weights)*1.0*n/(n-1)
  ;Only known values can be used as estimators of individual data points
  max_uncensored=max(data_uncensored)   
  IF(log_in) THEN BEGIN
      var=1.0/scale*alog10(1+var/(avg^2)) ;estimate of stddev (Quan & Zhang, 2003, doi: 10.1002/sim.1525)
      avg=1.0/scale*alog10(avg)-var*1.0/2
      max_uncensored=1.0/scale*alog10(max_uncensored)
  ENDIF  
  return,{mean:avg,std:sqrt(var),max:max_uncensored}
END
