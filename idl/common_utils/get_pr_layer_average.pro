FUNCTION get_pr_layer_average, gateStart, gateEnd, scan, angle, pr_field, $
                               scale_fac, min_val, num_in_avg, LOGAVG=logAvg

   IF ( N_ELEMENTS(logAvg) EQ 0 ) THEN logAvg = 0

   sum_val = 0.0D
   num2avg = 0

   FOR gateN = gateStart, gateEnd DO BEGIN
      prval = pr_field[scan,angle,gateN]/scale_fac     ; unscale values
      IF prval GE min_val THEN BEGIN
         num2avg = num2avg+1
         IF ( logAvg EQ 0 ) THEN BEGIN
            sum_val = prval+sum_val
         ENDIF ELSE BEGIN
            sum_val = 10.^(0.1*prval)+sum_val  ; convert from dB, and sum
         ENDELSE
      ENDIF
   ENDFOR

;   Compute the layer average

   IF ( num2avg EQ 0 ) THEN BEGIN
;     No values in layer met criteria, grab the middle one to represent
;     the layer average value and deal with it after analysis.
      gateN = (gateStart + gateEnd)/2
      pr_avg = pr_field[scan,angle,gateN]/scale_fac
   ENDIF ELSE BEGIN
      IF ( logAvg EQ 0 ) THEN BEGIN
         pr_avg = sum_val/num2avg
      ENDIF ELSE BEGIN
         pr_avg = 10.*ALOG10(sum_val/num2avg)  ; average, and convert to dB
      ENDELSE
   ENDELSE

num_in_avg = num2avg
RETURN, FLOAT(pr_avg)
END
