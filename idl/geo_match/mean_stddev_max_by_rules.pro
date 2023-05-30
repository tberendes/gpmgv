FUNCTION mean_stddev_max_by_rules, data, field, goodthresh, badthresh, $
                                   no_data_value, WEIGHTS=weights, $
                                   LOG_AVG=log_avg, BAD_TO_ZERO=badToZero, $
                                   WITH_ZEROS=withZeros,dependent=dependent_data
;Wrapper for ros_stats 
;May 2023-PG/MSFC

    log_in=0B
    scale=1
    limits=[0]
    ;Check for weights and make sure they are all >0
    if keyword_set(weights) then begin
        good_wts=where(weights ge 0,count,ncomplement=ncount,complement=bad_wts) ;make sure weights > 0        
            if(count gt 0) then begin
                weights=weights[good_wts]
                data=data[good_wts]                
            endif else begin
                struct=ros_stats(data,limits=limits,log_in=log_in,scale=scale)
                return,struct
            endelse
    endif else $
        weights=make_array(n_elements(data))+1.0

   ;Assign censoring limits for each field to pass into ros_stats function       
 
    SWITCH field OF
         'Z' : BEGIN
                 limits=[15] & log_in=1B & scale=0.1             
                 break
               END
       'ZDR' : BEGIN
                 limits=[-20] & log_in=1B
                 break
               END
       'KDP' : limits=[-20]
     'RHOHV' : limits=[0]
        'MW' : limits=[0] ;?
        'MI' : limits=[0] ;?
        'RR' : limits=[0,300]     ;?
        'DM' : limits=[0,0.5,4.0] ;Tokay et al. 2020 (doi: 10.1175/JTECH-D-18-0071.1)                        
        'NW' : BEGIN
                limits=[0,0.5,6.0]  & log_in=1B ;Tokay et al. 2020 (doi: 10.1175/JTECH-D-18-0071.1)
                break
               END
   'SIGMADM' : BEGIN  
                limits=[0] ;?
                  good_ind=where(data ge 0,count,ncomplement=rejects)
                  dm_stats=summary_stats(dependent_data,dependent_data,weights=weights)
                  if(count gt 0) then begin
                      data=data[good_ind]
                      dependent_data=data[good_ind]
                      n=count*1.0
                      temp=where(data gt 0,n_detects)                      
                      mean=total((data+dependent_data^2)*weights)*1.0/total(weights)-dm_stats.mean^2
                      ;sample standard deviation (1-degree of freedom)         
                      std=sqrt((total(weights*(data-mean)^2))/total(weights)*1.0*n/(n-1))
                      max=max(data)  
                      RETURN,{rejects:rejects,n_GR_precip:n_detects,mean:mean,stddev:std,max:max} 
                  endif else begin
                      RETURN,{rejects:rejects,n_GR_precip:0,mean:-999,stddev:-999,max:-999}
                  endelse
               END
        ELSE : message, "Unknown field identifier: "+field
    ENDSWITCH   
    

   ;Need to find limits if not known
    good_data=where(data GT -888.,count) ;-888. is the highest bad value in the GR files
    IF(count GT 0) THEN BEGIN       
       ind_unkown=where(data[good_data] LT 0,ucount) ;unknown values are between -888 and 0.
       IF(ucount GT 0) THEN BEGIN
           unknown_data=ABS(data[good_data[ind_unknown]]) ;convert to positive values
           binsize=0.5 ;resolution of limits
           nbins=ceil((max(unknown_data)-min(unknown_data))/binsize)+1
           hist=histogram(unknown_data,nbins=nbins,locations=binvals)
           limits=[0,binvals[where(abs(hist[1:*]-hist[0:-2]) gt 0)+1]]
       ENDIF
    ENDIF         

    struct=ros_stats(data,limits=limits,log_in=log_in,scale=scale,weights=weights)                                   
    return,struct
END