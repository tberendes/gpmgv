FUNCTION SUMMARY_STATS,data_linear,data_uncensored,weights=weights,log_in=log_in,scale=scale
;compute statistics of censored data
;data_linear=sample data (uncensored+imputed) in linear units
;data_uncensored=uncensored sample data in original units (used for getting max)
;weights=weights for each data_linear to apply
;log_in=keyword to set for returning data in log10 units (assume lognormal distribution for mean,sdev)
;scale=scaling factor used for log variables (e.g., dBz)
;returns mean,stdev,max  

ON_ERROR,1

  n=size(data_linear,/n_elements)
  IF not keyword_set(log_in) then log_in=0B
  IF not keyword_set(scale) then scale=1.0
  max_uncensored=max(data_uncensored) ;compute max first
  IF(log_in) and (max_uncensored gt 0.0) THEN BEGIN
    max_uncensored=1.0/scale*alog10(max_uncensored)
  endif else max_uncensored=-999.  
  IF(n lt 3) THEN return,{mean:-999.,std:-999.,max:max_uncensored} ;need at least 3 points to compute stats  
  IF not keyword_set(weights) THEN BEGIN ;check array existance
      weights=make_array(n,/float)+1.0 ;create array of weights=1.0    
  ENDIF
  gind=where(finite(weights),gcount,ncomplement=bcount) ;limit weights to finite values
  if(bcount gt 0) then begin
      weights=weights[gind]
      data_linear=data_linear[gind]
      n=gcount      
      IF(n lt 3) THEN return,{mean:-999.,std:-999.,max:max_uncensored} ;need at least 3 points to compute stats
  endif  
  if (total(weights) lt 0.001) then return,{mean:-999.,std:-999.,max:max_uncensored}  
  avg=total(data_linear*weights)*1.0/total(weights)   
  if ( avg eq 0.0 ) then begin
     IF(log_in) then begin
       return,{mean:-999.,std:-999.,max:-999.}
     endif else return,{mean:avg,std:0.0,max:0.0}
  endif  
  ;sample variance (1-degree of freedom)         
  var=(total(weights*(data_linear-avg)^2))/total(weights)*(n*1.0)/(n-1.0)

   CATCH, Error_status
 
   ;This statement begins the error handler:
   IF Error_status NE 0 THEN BEGIN
      PRINT, 'Error index: ', Error_status
      PRINT, 'Error message: ', !ERROR_STATE.MSG
      print,'n ',n
      print, 'avg ', avg
      print, 'total(weights) ', total(weights)
      print, 'data_linear ', data(linear)

   ENDIF


  ;Only known values can be used as estimators of individual data points
  max_uncensored=max(data_uncensored)   
  IF(log_in) THEN BEGIN
      max_uncensored=1/scale*alog10(max_uncensored)
    ;assume log-normal distribution 
    ;pind=where(data_linear gt 0,gcount,complement=zind,ncomplement=zcount)
    ;data_log=alog(data_linear[pind])     
    ;if(zcount gt 0) then data_log=[data_linear[zind],data_log]
    ;mu=total(data_log*weights)*1.0/total(weights) 
    ;sigma2=total(weights*((data_log-mu)^2))/total(weights)*(n*1.0)/(n-1.0)
    ;avg2=1.0/scale*alog10(exp(mu+0.5*sigma2))
    ;var2=1.0/scale*alog10((exp(sigma2)-1)*exp(2*mu+sigma2))         
    ;var=(1/scale*alog10(1+sqrt(var)/avg))^2 ;from Rinehart Radar Meteorology book Appendix B eqtn B.24
    var=(1/(scale*alog(10))*sqrt(var)/avg)^2 ;from Rinehart Radar Meteorology book Appendix B eqtn B.26 (uncertainty propgation approach)   
    avg=1/scale*alog10(avg)    
  ENDIF    
  return,{mean:avg,std:sqrt(var),max:max_uncensored}
END
