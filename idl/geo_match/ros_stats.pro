FUNCTION ROS_STATS,x_data,limits=limits,max_bad_data=max_bad_data,scale=scale,$
        no_precip_value=no_precip_value,log_in=log_in,weights=weights,max_value=max_value
    ;Inputs:
    ; -x_data is input array of data
    ; -limits is boundaries of the censoring (e.g.,[0,left,[right]]), right is optional,default=[0]    
    ; -max_bad_data is the greatest value of known bad data (e.g., censoring cannot be determined)
    ; -scale is the factor to multiply the data when transforming log-linear (default=1.0)
    ; -no_precip_value is the fill value used to indicate zero for log data (default=-32767.0 for log, 0.0 for linear)
    ; -log_in is the boolean switch for indicating input data are in log units (e.g., decibels) (default=0B)
    ; -weights is an array of weights to apply to each x_data (default=1.0)
    ; -max_value is maximum expected valid value of input data (default=1e3)   
    ;Outputs:
    ; returns a dictionary containing the mean,stddev,max,rejects,n_GR_precip
    ; -rejects is the number of data not included in summary stats
    ; -n_GR_precip is the number of detections (i.e., no zero) included in the summary stats
    ;History:
    ; May 2023-PG/MSFC
    
    min_stat_count = 5 ;minimum number of good data points required to compute statistics
    
    IF not keyword_set(scale) THEN scale=1.0
    IF not keyword_set(max_bad_data) THEN max_bad_data=-888.
    IF not keyword_set(log_in) THEN log_in=0B   
    IF not keyword_set(limits) THEN limits=[0]    
    IF not keyword_set(weights) THEN weights=make_array(n_elements(x_data))+1 ;default=1  
    IF not keyword_set(max_value) THEN max_value=1e3    
    IF (n_elements(no_precip_value) EQ 0) THEN BEGIN
     no_precip_value=0.0
     if(log_in) then no_precip_value=-32767.
    ENDIF    
   ;Prep the input data
    y_all=make_array(n_elements(x_data),/float)        
    y_all[*]=x_data[sort(x_data)] ;copy input data and sort  
    weights[*]=weights[sort(x_data)] ;need to keep same indexing as y_all
    negzeros=where(abs(y_all) EQ 0,count)
    IF(count GT 0) THEN y_all[negzeros]=0.0 ;handle any floating point instances where 0. is -0. 
    ;--identify no precip and handle if all zeros
    noprecip=where(y_all EQ no_precip_value,nop_count,complement=pind,ncomplement=pcount) ;identify where flagged as no precip
    IF(nop_count EQ n_elements(y_all)) THEN BEGIN ;all values are zero
        RETURN,{rejects:0,n_GR_precip:0,mean:no_precip_value,stddev:0.0,max:no_precip_value}        
    ENDIF    
    ;--remove any bad values
    good_ind=where(y_all[pind] GT max_bad_data,gcount,ncomplement=nrejects) ;non-zero values used for stats
    IF(gcount GE min_stat_count) THEN BEGIN
        y_all=[y_all[noprecip],y_all[pind[good_ind]]] ;zeros and non-zero values for stats
        weights=[weights[noprecip],weights[pind[good_ind]]]         
    ENDIF ELSE BEGIN ;not enough good data values-->return        
        IF(log_in) THEN BEGIN
            RETURN,{rejects:nrejects,n_GR_precip:gcount,mean:-999.,stddev:-999.,max:max(y_all)}
        ENDIF ELSE RETURN,{rejects:nrejects,n_GR_precip:gcount,mean:-999.,stddev:-999.,max:max(y_all)}
    ENDELSE               
    ;--handle unknown values (assume flagged as negative) 
    maxval=max(y_all) ;store max value of data not flagged as unknown
    pind=lindgen(n_elements(y_all)) ;first need array to exclude no-precip indices since haven't converted to linear yet
    IF(log_in) THEN BEGIN 
        pind=where(y_all NE no_precip_value)
    ENDIF    
    iunknown=where(y_all[pind] LT 0,count)  ;any precip indices flagged as negative are unknown      
    if(count GT 0) THEN y_all[pind[iunknown]]=abs(y_all[pind[iunknown]]) ;convert to positive
    ;--handle unrealistic values
    igood=where(y_all LT max_value,count)
    if(count GT 0) THEN y_all=y_all[igood]     
    ;-->now y_all contains values used for statistics
    
    ;--Get precip and non-precip indices and counts
    idetects=where(y_all NE no_precip_value,n_detects,complement=inull,ncomplement=null_count)    
    if(log_in) THEN BEGIN ;convert data to linear
        y_all[idetects]=10^(y_all[idetects]*scale)
        if(null_count gt 0) then y_all[inull]=0.0 ;convert log no-precip to linear zero       
    ENDIF
    
   ;Done preparing input data-->all data in y_all is linear units
   
   ;Begin Computing Statistics
    IF not keyword_set(limits) THEN BEGIN     ;no censoring limits passed so just compute stats and return   
        stats_struct=summary_stats(y_all,y_all,weights=weights,log_in=log_in,scale=scale)
        RETURN,{rejects:nrejects,n_GR_precip:n_detects,$
                mean:stats_struct.mean,stddev:stats_struct.std,max:stats_struct.max}           
    ENDIF ELSE BEGIN
        thres=limits ;local var to hold limits      
        if(log_in) THEN BEGIN ;convert thres data to linear
            ithres=where(thres GT 0,count)
            IF(count GT 0) THEN thres[ithres]=10^(thres[ithres]*scale)    
        ENDIF
    ENDELSE      
    
    ;-Determine Uncensored and Censored data
    y_uncensored = []
    weights_uncensored = []
    y_censored=[]
    weights_censored=[]    
    uncensored_ind=where((y_all EQ 0) OR (y_all GE thres[0]),count,complement=censored_ind,ncomplement=ncount) ;all values GE lower limit
    IF(count GE min_stat_count) THEN BEGIN
        y_uncensored=y_all[uncensored_ind] ;known data values (i.e., uncensored)
        weights_uncensored=weights[uncensored_ind]
    ENDIF ELSE RETURN,{rejects:nrejects+count,n_GR_precip:n_detects,mean:-999.,stddev:-999.,max:maxval}
    ;--Assign uncensored/censored based on number of left/right censoring
    IF(n_elements(thres) GT 1) THEN BEGIN ;left-censored data if thres is two element censoring b/w thres[0] and thres[1]        
        censored_ind=where((y_all LT thres[0]) OR (y_all GE thres[1]),ncount,complement=uncensored_ind,ncomplement=count)        
        IF(count GT 0) THEN BEGIN
            y_uncensored=y_all[uncensored_ind] ;known data values (i.e., uncensored)
            weights_uncensored=weights[uncensored_ind]
        ENDIF
        IF(ncount GT 0) THEN BEGIN
            y_censored=y_all[censored_ind] ;unknown data values
            weights_censored=weights[censored_ind]            
        ENDIF             
        IF(n_elements(thres) GT 2) THEN BEGIN ;right-censored data if thres is 3 elements
            uncensored_ind=where((y_censored LE thres[-1]),count,complement=censored_ind,ncomplement=ncount)
            ytemp=y_censored
            wtemp=weights_censored
            zeros=where((y_uncensored EQ 0.0),zcount,complement=nozeros,ncomplement=nzcount)
            if(nzcount GT 0) THEN BEGIN
                y_nozeros=y_uncensored[nozeros]
                weights_nozeros=weights_uncensored[nozeros]
            endif else begin
                y_nozeros=[]
                weights_nozeros=[]
            endelse
            if(zcount GT 0) THEN BEGIN
                y_zeros=y_uncensored[zeros]
                weights_zeros=weights_uncensored[zeros]
            endif else begin
                y_zeros=[]
                weights_zeros=[]
            endelse
            IF(ncount GT 0) THEN BEGIN                            
                y_censored=[y_nozeros,y_censored[censored_ind]] ;unknown data values
                weights_censored=[weights_nozeros,weights_censored[censored_ind]]
            ENDIF                        
            IF(count GT 0) THEN BEGIN
                y_uncensored=[y_zeros,ytemp[uncensored_ind]] ;known data values (i.e., uncensored)
                weights_uncensored=[weights_zeros,wtemp[uncensored_ind]]
            ENDIF              
        ENDIF      
    ENDIF ELSE BEGIN ;assume if only 1 thres given then truncate linear values b/w 0-thres to zero (i.e., non-detects)        
        IF(ncount gt 0) THEN BEGIN ;censored data exists        
            y_uncensored=[y_all[censored_ind]*0,y_uncensored] ;truncate to zero (i.e., non-detect)
            weights_uncensored=[weights[censored_ind],weights_uncensored]
        ENDIF        
        stats_struct=summary_stats(y_uncensored,y_uncensored,weights=weights_uncensored,log_in=log_in,scale=scale)        
        RETURN,{rejects:nrejects,n_GR_precip:n_detects,$
                mean:stats_struct.mean,stddev:stats_struct.std,max:stats_struct.max}       
    ENDELSE    
    
    ;--Check for presence of uncensored or censored data
    IF (n_elements(y_uncensored) EQ 0) THEN BEGIN
        if(log_in) then begin
            RETURN,{rejects:nrejects+n_elements(y_censored),n_GR_precip:n_detects,mean:no_precip_value,stddev:0.0,max:no_precip_value}
	    endif else $
    		RETURN,{rejects:nrejects+n_elements(y_censored),n_GR_precip:n_detects,mean:0.,stddev:0.,max:0.}
    ENDIF
    IF(n_elements(y_censored) EQ 0) THEN BEGIN  ;no censored values-->so compute stats on input data and return
        stats_struct=summary_stats(y_uncensored,y_uncensored,weights=weights_uncensored,log_in=log_in,scale=scale)                    
        RETURN,{rejects:nrejects,n_GR_precip:n_detects,$
                mean:stats_struct.mean,stddev:stats_struct.std,max:maxval}
    ENDIF        
    ind=where(y_uncensored GT 0,cnt) 
    if (cnt EQ 0) then begin ;only zero values
	    if(log_in) THEN BEGIN	        
            RETURN,{rejects:nrejects+n_elements(y_censored),n_GR_precip:n_detects,mean:no_precip_value,stddev:0.0,max:no_precip_value}
	    endif else $
    		RETURN,{rejects:nrejects+n_elements(y_censored),n_GR_precip:n_detects,mean:0.,stddev:0.,max:0.}
    endif    
    
    ;Don't impute censored data if those outnumber the uncensored points by 5%
    ratio=n_elements(y_censored)*1.0/n_elements(y_uncensored)
    if(ratio gt 0.05) then begin
        stats_struct=summary_stats(y_uncensored,y_uncensored,weights=weights_uncensored,log_in=log_in,scale=scale)         
        RETURN,{rejects:nrejects+n_elements(y_censored),n_GR_precip:n_detects,$
                mean:stats_struct.mean,stddev:stats_struct.std,max:maxval}
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
    yuind=where(y_uncensored GT 0,county)
    if(county ge min_stat_count) then begin ;make sure there are enough uncensored points to fit line
        y=alog10(y_uncensored[yuind])*1/scale  
        x=zscore_uncensored[yuind] ;zscore is sorted
    ENDIF ELSE BEGIN 
        stats_struct=summary_stats(y_uncensored,y_uncensored,weights=weights_uncensored,log_in=log_in,scale=scale)                    
        RETURN,{rejects:nrejects,n_GR_precip:n_detects,$
                mean:stats_struct.mean,stddev:stats_struct.std,max:maxval}
    ENDELSE
    n=count
    denom = n*total(x^2)-total(x)^2
    if (denom eq 0.0) then begin
        stats_struct=summary_stats(y_uncensored,y_uncensored,weights=weights_uncensored,log_in=log_in,scale=scale)  
		RETURN,{rejects:nrejects,n_GR_precip:n_detects,$
                mean:stats_struct.mean,stddev:stats_struct.std,max:maxval}    
    endif
    m=(n*total(x*y)-total(x)*total(y))/denom ;slope of y=mx+b
    b=(total(y)-m*total(x))/n ;intercept of y=mx+b

    ;Estimate values of censored data using fitted line to extrapolate at plotting positions (i.e., impute values)
    y_imputed=(m*zscore_censored+b)  ;log scale    
    
    ind=where(abs(y_imputed) lt max_value,cnt,ncomplement=cnt_exceed)
    if (cnt gt 0) then begin
    	y_imputed=y_imputed[ind]*scale
    endif else y_imputed=[]
    
    y_new=10d^[y,y_imputed] ;y is uncensored non-zero and both are log scale since fit was done in log scale    
    ind_zeros=where(y_uncensored EQ 0,count) ;check for zeros
    IF(count GT 0) THEN BEGIN
        y_linear=[y_uncensored[ind_zeros],y_new] ;include zeros for calculating statistics        
    ENDIF ELSE $
        y_linear=y_new        

    stats_struct=summary_stats(y_linear,y_uncensored,weights=[weights_uncensored,weights_censored],log_in=log_in,scale=scale)  
    RETURN,{rejects:nrejects+cnt_exceed,n_GR_precip:n_detects,$
        mean:stats_struct.mean,stddev:stats_struct.std,max:maxval}
END