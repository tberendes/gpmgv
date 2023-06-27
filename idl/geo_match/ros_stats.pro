FUNCTION ROS_STATS,x_data,limits=limits,max_bad_data=max_bad_data,scale=scale,$
        no_precip_value=no_precip_value,log_in=log_in,weights=weights
    ;Inputs:
    ; -x_data is input array of data
    ; -limits is boundaries of the censoring (e.g.,[0,left,[right]]), right is optional,default=[0]    
    ; -max_bad_data is the greatest value of known bad data (e.g., censoring cannot be determined)
    ; -scale is the factor to multiply the data when transforming log-linear (default=1.0)
    ; -no_precip_value is the fill value used to indicate zero for log data (default=-32767.0)
    ; -log_in is the boolean switch for indicating input data are in log units (e.g., decibels) (default=0B)
    ; -weights is an array of weights to apply to each x_data (default=1.0)
    ;Outputs:
    ; returns a dictionary containing the mean,stddev,max,rejects,n_GR_precip
    ; -rejects is the number of data not included in summary stats
    ; -n_GR_precip is the number of detections (i.e., no zero) included in the summary stats
    ;History:
    ; May 2023-PG/MSFC
    
    min_stat_count = 5 ;minimum number of good data points required to compute statistics
    
    IF not keyword_set(no_precip_value) THEN no_precip_value=-32767.
    IF not keyword_set(scale) THEN scale=1.0
    IF not keyword_set(max_bad_data) THEN max_bad_data=-888.
    IF not keyword_set(log_in) THEN log_in=0B   
    IF not keyword_set(limits) THEN limits=[0]    
    IF not keyword_set(weights) THEN weights=make_array(n_elements(x_data))+1 ;default=1        
    
    ;Prep the input data
    y_all=make_array(n_elements(x_data),/float)        
    y_all[*]=x_data[sort(x_data)] ;copy input data and sort  
    weights[*]=weights[sort(x_data)] ;need to keep same indexing as y_all
    negzeros=where(abs(y_all) EQ 0,count)
    if(count GT 0) THEN y_all[negzeros]=0.0 ;handle any floating point instances where 0. is -0.    
    if(log_in) THEN BEGIN
        noprecip=where(y_all EQ no_precip_value,count) ;log values have no precip flagged (linear=0)
        IF(count GT 0) THEN y_all[noprecip]=abs(y_all[noprecip]*0)
    ENDIF
    IF(n_elements(y_all) eq 0) then begin
        RETURN,{rejects:0,n_GR_precip:0,mean:-999,stddev:-999,max:-999}
    ENDIF
    good_ind=where(y_all GT max_bad_data,count,ncomplement=rejects) ;good values and count of values excluded from statistics     
    if(count GE min_stat_count) THEN BEGIN
        y_all=y_all[good_ind] ;limit to good data values       
        weights=weights[good_ind]         
    ENDIF ELSE $ ;no good data values
        RETURN,{rejects:rejects+count,n_GR_precip:0,mean:-999,stddev:-999,max:-999}
    iunknown=where(y_all LT 0,count)    
    if(count GT 0) THEN y_all[iunknown]=-1.0*y_all[iunknown] ;handle unknown values (assume flagged as negative)
    ;-->now y_all contains values used for statistics
    idetects=where(abs(y_all) GT 0,n_detects) ;number of non-zero values included in statistics
    
    if(log_in) THEN BEGIN ;convert data to linear
        y_all[idetects]=10^(y_all[idetects]*scale)
    ENDIF
      
    IF not keyword_set(limits) THEN BEGIN     ;no censoring limits passed so just compute stats and return   
        stats_struct=summary_stats(y_all,y_all,weights=weights,log_in=log_in,scale=scale)
        RETURN,{rejects:rejects,n_GR_precip:n_detects,$
                mean:stats_struct.mean,stddev:stats_struct.std,max:stats_struct.max}           
    ENDIF ELSE BEGIN
        thres=limits ;local var to hold limits      
        if(log_in) THEN BEGIN ;convert thres data to linear
            ithres=where(thres GT 0,count)
            IF(count GT 0) THEN thres[ithres]=10^(thres[ithres]*scale)    
        ENDIF
    ENDELSE  
    
    ;Determine Uncensored and Censored data
    y_uncensored = []
    weights_uncensored = []
    y_censored=[]
    weights_censored=[]    
    uncensored_ind=where((y_all EQ 0) OR (y_all GE thres[0]),count,complement=censored_ind,ncomplement=ncount) ;all values GE lower limit
    IF(count GT min_stat_count) THEN BEGIN
        y_uncensored=y_all[uncensored_ind] ;known data values (i.e., uncensored)
        weights_uncensored=weights[uncensored_ind]
    ENDIF ELSE RETURN,{rejects:rejects+count,n_GR_precip:0,mean:-999,stddev:-999,max:-999}    
    IF(n_elements(thres) GT 1) THEN BEGIN ;left-censored data if thres is two element censoring b/w thres[0] and thres[1]
        uncensored_ind=where((y_all EQ 0) OR (y_all GE thres[1]),count,complement=censored_ind,ncomplement=ncount)        
        IF(count GT 0) THEN BEGIN
            y_uncensored=y_all[uncensored_ind] ;known data values (i.e., uncensored)
            weights_uncensored=weights[uncensored_ind]
        ENDIF
        IF(ncount GT 0) THEN BEGIN
            y_censored=y_all[censored_ind] ;unknown data values
            weights_censored=weights[censored_ind]
        ENDIF
        IF(n_elements(thres) GT 2) THEN BEGIN ;right-censored data if thres is 3 elements
            uncensored_ind=where((y_uncensored LE thres[-1]),count,complement=censored_ind,ncomplement=ncount)    
            IF(ncount GT 0) THEN BEGIN            
                y_censored=[y_censored,y_uncensored[censored_ind]] ;unknown data values
                weights_censored=[weights_censored,weights_uncensored[censored_ind]]
            ENDIF                        
            IF(count GT 0) THEN BEGIN
                y_uncensored=y_uncensored[uncensored_ind] ;known data values (i.e., uncensored)
                weights_uncensored=weights_uncensored[uncensored_ind]
            ENDIF            
        ENDIF      
    ENDIF ELSE BEGIN ;assume if only 1 thres given then truncate linear values b/w 0-thres to zero (i.e., non-detects)           
        IF(ncount gt 0) THEN BEGIN ;censored data exists        
            y_uncensored=[y_all[censored_ind]*0,y_uncensored] ;truncate to zero (i.e., non-detect)
            weights_uncensored=[weights[censored_ind],weights_uncensored]
        ENDIF        
        stats_struct=summary_stats(y_uncensored,y_uncensored,weights=weights_uncensored,log_in=log_in,scale=scale)
        RETURN,{rejects:rejects,n_GR_precip:n_detects,$
                mean:stats_struct.mean,stddev:stats_struct.std,max:stats_struct.max}       
    ENDELSE    
    
    ;Check for presence of uncensored or censored data
    IF (n_elements(y_uncensored) EQ 0) THEN BEGIN
        RETURN,{rejects:rejects+count,n_GR_precip:0,mean:-999,stddev:-999,max:-999}
    ENDIF
    IF(n_elements(y_censored) EQ 0) THEN BEGIN  ;no censored values-->so compute stats on input data and return
        stats_struct=summary_stats(y_uncensored,y_uncensored,weights=weights_uncensored,log_in=log_in,scale=scale)                    
        RETURN,{rejects:rejects,n_GR_precip:n_detects,$
                mean:stats_struct.mean,stddev:stats_struct.std,max:stats_struct.max}
    ENDIF        
    ind=where(y_uncensored GT 0,cnt)
    if (cnt EQ 0) then begin
	    if(log_in) THEN BEGIN
	        RETURN,{rejects:rejects+count,n_GR_precip:0,mean:-999.,stddev:-999.,max:-999.}
	    endif else $
    		RETURN,{rejects:rejects+count,n_GR_precip:0,mean:0,stddev:0,max:0}
    endif
    
        
    ;Probability Plotting: Hirsch and Stedinger (1987, doi: 10.1029/WR023i004p00715)
    ;Transformation bias avoided by imputing values for censored data 
    
    ;Compute survival function and plotting positions
    k=size(thres,/n_elements)
    prob=make_array(k,/double) ;account for probability of exceeding positive/negative infinity
    prob[0]=1  ;probability of exceeding negative infinity
    plot_pos_uncensored=make_array(size(y_uncensored,/n_elements))
    plot_pos_censored=make_array(size(y_censored,/n_elements)) 
    alpha=3.0/8 ;factor used to eliminate bias in plotting position (use Blom per Helsel & Cohn, 1988, doi:10.1029/WR024i012p01997)
    
    if(k GT 2) THEN BEGIN ;Data is right-censored...calcualte survival function and plotting positions of right-censored data
        ind_censored_j=where(y_censored GT thres[-1],C)     ;count censored data above highest threshold           
        prob[-1]=0+C*1.0/(size(y_all,/n_elements))*(1.0-0) ;probability of data value exceeding highest threshold                
        IF(C GT 0) THEN BEGIN        
            ranked_censored=reverse(ranks(y_censored[ind_censored_j])) ;rank censored data in descending order
            plot_pos_censored[ind_censored_j]=1-(prob[-1]*(ranked_censored-alpha)/(C+1-2*alpha)) ;plotting position of right-censored data    
        ENDIF
    ENDIF ELSE BEGIN ;plotting positions for data that is left-censored only
        Bc_ind=where(y_censored LT thres[-1],Bc) ;censored below highest thres
        Bu_ind=where(y_uncensored LT thres[-1],Bu) ;uncensored below highest thres        
        B=Bc+Bu ;censored+uncensored below highest threshold
        ind_uncensored_j=where(y_uncensored GE thres[-1],A) ;count uncensored above highest threshold        
        prob[-1]=0+(A*1.0/(A+B))*(1-0) ;probability of exceeding highest threshold                          
        IF(A GT 0) THEN BEGIN ;plotting position for uncensored observations        
            ranked_uncensored=ranks(y_uncensored[ind_uncensored_j]) ;rank uncensored data in ascending order                   
            plot_pos_uncensored[ind_uncensored_j]=(1-prob[-1])+(ranked_uncensored-alpha)/(A+1-2*alpha)*(prob[-1]-0) 
        ENDIF
        ind_censored_j=where(y_censored LT thres[-1],C) ;count censored below highest threshold
        IF(C GT 0) THEN BEGIN
            ranked_censored=ranks(y_censored[ind_censored_j])                
            plot_pos_censored[ind_censored_j]=(ranked_censored-alpha)*1.0/(C+1-2*alpha)*(1-prob[-1]) ;plotting pos for left-censored data 
        ENDIF
    ENDELSE
    
    ;Plotting positions for data that is interval-censored  (Helsel & Cohn, 1988, doi:10.1029/WR024i012p01997)
    FOR j=k-2,1,-1 DO BEGIN   ;loop in reverse since that's how survival function works prob[0]=1-->prob[k]=0        
        Bc_ind=where(y_censored LT thres[j],Bc) ;censored below jth thres
        Bu_ind=where(y_uncensored LT thres[j],Bu) ;uncensored below jth thres  
        B=Bu+Bc ;number of all data (censored+uncensored) below jth threshold
        ind_uncensored_j=where((y_uncensored GE thres[j]) AND (y_uncensored LT thres[j+1]),A) ;known values between jth and jth+1 threshold
        IF((A+B) GT 0) THEN $
            prob[j]=prob[j+1]+A*1.0/(A+B)*(1-prob[j+1]) ;posterior probability that data is between the jth and jth+1 threshold 
        IF(A GT 0) THEN BEGIN
            ranked_uncensored=ranks(y_uncensored[ind_uncensored_j])            
            plot_pos_uncensored[ind_uncensored_j]=(1-prob[j])+(ranked_uncensored-alpha)/(A+1-2*alpha)*(prob[j]-prob[j+1]) ;plotting pos. for uncensored observations within interval
        ENDIF
        ind_censored_j=where(y_censored LT thres[j],C) ;censored data below jth threshold
        IF(C GT 0) THEN BEGIN
            ranked_censored=ranks(y_censored[ind_censored_j])
            plot_pos_censored[ind_censored_j]=(ranked_censored-alpha)*1.0/(C+1-2*alpha)*(1-prob[j]) ;plotting pos for left-censored data
        ENDIF
    ENDFOR

    ;Compute normal z-scores (inverse cdf) for uncensored and censored data 
    ;have to loop b/c gauss_cvf only takes scalar as input
    zscore_uncensored=make_array(n_elements(plot_pos_uncensored))
    FOREACH element,plot_pos_uncensored,i DO zscore_uncensored[i]=gauss_cvf(element) 
    zscore_censored=make_array(n_elements(plot_pos_censored))
    FOREACH element,plot_pos_censored,i DO zscore_censored[i]=gauss_cvf(element)
  
    ;Fit line to uncensored data assuming normal distribution of y (i.e., LLSQ regression)      
    y=alog10(y_uncensored[where(y_uncensored GT 0)])  
    x=zscore_uncensored[where(y_uncensored GT 0,count)] ;zscore is sorted
    IF(count lt min_stat_count) THEN BEGIN ;make sure there are enough uncensored points to fit line
        stats_struct=summary_stats(y_uncensored,y_uncensored,weights=weights_uncensored,log_in=log_in,scale=scale)                    
        RETURN,{rejects:rejects,n_GR_precip:n_detects,$
                mean:stats_struct.mean,stddev:stats_struct.std,max:stats_struct.max}
    ENDIF
    n=count
    denom = n*total(x^2)-total(x)^2
    if (denom eq 0.0) then begin
        stats_struct=summary_stats(y_uncensored,y_uncensored,weights=weights_uncensored,log_in=log_in,scale=scale)  
		RETURN,{rejects:rejects,n_GR_precip:n_detects,$
                mean:stats_struct.mean,stddev:stats_struct.std,max:stats_struct.max}    
    endif
    m=(n*total(x*y)-total(x)*total(y))/denom ;slope of y=mx+b
    b=(total(y)-m*total(x))/n ;intercept of y=mx+b

    ;Estimate values of censored data using fitted line to extrapolate at plotting positions (i.e., impute values)
    y_imputed=(m*zscore_censored+b)  ;log scale    
    
    ind=where(y_imputed gt 0,cnt)
    if (cnt gt 0) then begin
    	y_imputed=y_imputed[ind]
    endif else y_imputed=[]
    
    y_new=10^[y,y_imputed] ;y is uncensored non-zero and both are log scale since fit was done in log scale
    ind_zeros=where(y_uncensored EQ 0,count) ;check for zeros
    IF(count GT 0) THEN BEGIN
        y_linear=[y_uncensored[ind_zeros],y_new] ;include zeros for calculating statistics
    ENDIF ELSE $
        y_linear=y_new    
    stats_struct=summary_stats(y_linear,y_uncensored,weights=[weights_uncensored,weights_censored],log_in=log_in,scale=scale)  
    RETURN,{rejects:rejects,n_GR_precip:n_detects,$
        mean:stats_struct.mean,stddev:stats_struct.std,max:stats_struct.max}
END