FUNCTION SUMMARY_STATS,data_linear,data_uncensored,weights=weights
;compute statistics of censored data
;data_linear=sample data (uncensored+imputed) in linear units
;data_uncensored=uncensored sample data in original units (used for getting max)
;weights=weights for each data_linear to apply
;returns mean,stdev,max
  n=size(data_linear,/n_elements)
  IF not keyword_set(weights) THEN BEGIN ;check array existance
      weights=make_array(n,/float)+1.0 ;create array of weights=1.0    
  ENDIF
  mean=total(data_linear*weights)*1.0/total(weights)   
  ;sample standard deviation (1-degree of freedom)         
  std=sqrt((total(weights*(data_linear-mean)^2))/total(weights)*1.0*n/(n-1))
  ;Only known values can be used as estimators of individual data points
  max_uncensored=max(data_uncensored)   
  return,{mean:mean,std:std,max:max_uncensored}
END

