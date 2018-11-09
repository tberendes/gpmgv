;===============================================================================
;+
; Copyright © 2014, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; mean_stddev_max_by_rules.pro          Morris/SAIC/GPM_GV      March 2014
;
; DESCRIPTION
; -----------
; Computes mean, standard deviation, and maximum of an array of radar 'data'
; bin values according to rules specific to each 'field', as well as the count
; of below-threshold bin values.  Returns computed values in a structure.  If
; LOG_AVG is set, converts input values from dBZ to Z before averaging, then
; converts mean value back to dBZ for returned value.  If a weights array is
; provided then the bin values are weighted according to these values.  If
; BAD_TO_ZERO is set, then values below 'badthresh' are set to zero and included
; in the average rather than being excluded from the average.  BAD_TO_ZERO
; setting does not affect computation of n_gv_points_rejected value, which is
; based solely on the number of 'data' values below 'badthresh'.  In no 'data'
; bin values meet the 'goodthresh' criterion for the 'field', then the returned
; mean, standard deviation, and maximum elements in the returned structure are
; set to the 'no_data_value' parameter's value.
;
; HISTORY
; -------
; 05/30/14 Morris, GPM GV, SAIC
; - Fixed initialization and handling of weights array.
; 09/24/14 Morris, GPM GV, SAIC
; - Added BAD_TO_ZERO parameter to explicitly control how below-badthresh values
;   are handled in the averaging, and replaced exception specific to Z field
;   with a check of this parameter's setting.
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;===============================================================================

FUNCTION mean_stddev_max_by_rules, data, field, goodthresh, badthresh, $
                                   no_data_value, WEIGHTS=weights, $
                                   LOG_AVG=log_avg, BAD_TO_ZERO=badToZero

   doLog = KEYWORD_SET(log_avg)
   doZero = KEYWORD_SET(badToZero)

   IF N_ELEMENTS(weights) EQ 0 THEN $
      weights = MAKE_ARRAY(N_ELEMENTS(data), /FLOAT, VALUE=1.0) $
   ELSE IF N_ELEMENTS(weights) NE N_ELEMENTS(data) THEN message, $
           "Mismatched data and weights array sizes."

   SWITCH field OF
         'Z' :
       'ZDR' :
       'KDP' :
        'RR' : BEGIN
                 good_idx = WHERE( data GE goodthresh, countGVgood )
                 bad_idx = WHERE( data LT badthresh, countGVbad )
                 break
               END
     'RHOHV' : BEGIN
                 good_idx = WHERE( data GT goodthresh, countGVgood )
                 bad_idx = WHERE( data LE badthresh, countGVbad )
                 break
               END
     'DZERO' : 
        'NW' : BEGIN
        		 ; added sanity check to filter out very large values
        		 ; 9.9e36 and Inf found in DARW CPOL data files
                 good_idx = WHERE( data GT goodthresh and data LT 32000, countGVgood )
                 bad_idx = WHERE( data LE badthresh or data GE 32000, countGVbad )
                 break
               END
        ELSE : message, "Unknown field identifier: "+field
   ENDSWITCH

   n_gv_points_rejected = N_ELEMENTS(data) - countGVgood

   IF ( countGVgood GT 0 ) THEN BEGIN
      IF ( countGVbad GT 0 and doZero ) THEN BEGIN
        ; set "bad" dBZ, etc. values to 0.0 for averaging and include them all
         data2avg=data
         data2avg[bad_idx] = 0.0
         wgts2avg = weights
      ENDIF ELSE BEGIN
        ; include only "good" values for averaging
         data2avg=data[good_idx]
         wgts2avg = weights[good_idx]
      ENDELSE

      IF doLog THEN BEGIN
        ; compute volume-weighted GV reflectivity average in Z space,
        ;   then convert back to dBZ
         z_avg_gv = TOTAL(10.^(0.1*data2avg) * wgts2avg) / TOTAL(wgts2avg)
         avg_gv = 10.*ALOG10(z_avg_gv)
      ENDIF ELSE BEGIN
; Disable automatic printing of subsequent math errors:
!EXCEPT=0

        ; compute volume-weighted average in data space
         avg_gv = TOTAL(data2avg * wgts2avg) / TOTAL(wgts2avg)
		IF CHECK_MATH() NE 0 THEN BEGIN
			PRINT, 'Math error mean_stddev_max_by_rules'
			print, 'field ', field, ' goodthresh ', goodthresh, ' badthresh ', badthresh, $
                                   ' no_data_value ', no_data_value
            print, ' TOTAL(data2avg * wgts2avg) ', TOTAL(data2avg * wgts2avg)
            print, ' TOTAL(wgts2avg) ', TOTAL(wgts2avg)

; Enable automatic printing of subsequent math errors:
!EXCEPT=2
		ENDIF
      ENDELSE
     ; compute max and standard deviation of good GR gates in data space
      max_gv = MAX(data2avg)
      IF N_ELEMENTS(data2avg) LT 2 THEN stddev_gv = 0.0 $
      ELSE stddev_gv = STDDEV(data2avg)
;      print, "avg_gv = ", avg_gv
;      print, "GV dBZs:"
;      print, data[good_idx]
;      print, weights[good_idx]
   ENDIF ELSE BEGIN
     ; handle where no field values meet criteria
      avg_gv = no_data_value
      stddev_gv = no_data_value
      max_gv = no_data_value
   ENDELSE

   struct = { rejects : n_gv_points_rejected, $
                 mean : avg_gv, $
               stddev : stddev_gv, $
                  max : max_gv }

return, struct
end
