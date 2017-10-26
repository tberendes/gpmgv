;+
; Copyright © 2013, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; get_dpr_layer_average.pro         Bob Morris, GPM GV/SAIC   June 2013
;
; DESCRIPTION
; -----------
; Given the starting and ending gate numbers along a DPR ray, the ray number
; and scan number of the ray, the DPR 3-D data field and the data scale factor,
; computes the Z- or dBZ-space (simple) average of the unscaled data for the
; specified gates.  Only those gates with values above 'min_val' are included
; in the average.  If the binClutterFreeBottom data field is provided, then
; only those gates at or above the lowest clutter-free gate are included in the
; average.  If all the specified gates are below the lowest clutter-free gate,
; the the value at the lowest clutter-free gate is returned as the average.  If
; the clutterStatus parameter is provided IN ADDITION TO binClutterFreeBottom,
; then the status of the clutter filtering for the volume average is assigned
; to this parameter's value, as follows:
;
;    0 : all gates above clutter region, no substitution or truncation
;    1 : one or more gates below lowest clutter-free gate, average truncated
;    2 : all gates below lowest clutter-free gate, average set to value of
;        lowest clutter-free gate
;
; The optional clutterFlag parameter flags elevated gates above the lowest
; clutter-free gate that are affected by ground clutter (sidelobes, etc.).  If
; any of the gates to be averaged are flagged as elevated clutter, then they
; are excluded from the averaging and the clutterStatus parameter value is
; incremented by 10 to indicate that elevated clutter bins have been excluded.
;
; The total number of gates included in the volume average after threshold
; checking and clutter filtering is returned in the num_in_avg parameter value.
;
;
; PARAMETERS
; ----------
; gateStart            -- Starting gate # of gates to be averaged along ray
;
; gateEnd              -- Ending gate # of gates to be averaged along ray
;
; scan                 -- Scan number of ray whose values are to be averaged,
;                         0-based
;
; ray                  -- As above, but ray number
;
; dpr_field            -- 3-D (gate,ray,scan) DPR data field of gate values
;
; scale_fac            -- Factor to divide dpr_field by to get unscaled
;                         physical values
;
; min_val              -- Minimum unscaled value to be included in the average
;
; num_in_avg           -- Number of uncluttered, above-min-val-threshold gates
;                         included in the returned layer average
;
; binClutterFreeBottom -- 2-D (ray,scan) field of lowest uncluttered gate #s.
;                         Optional parameter, if not included then no checking
;                         of gateStart and gateEnd versus the clutter region is
;                         performed.  If clutterStatus parameter is included, 
;                         then binClutterFreeBottom parameter MUST be included
;                         and precede it in the argument list
;
; clutterStatus        -- Optional scalar parameter, returns the status of check
;                         of gateStart and gateEnd proximity to clutter region.
;                         Possible status values are defined under DESCRIPTION.
;                         If clutterStatus parameter is included, then
;                         binClutterFreeBottom parameter MUST be included
;                         
; logAvg               -- Binary keyword parameter.  If set, then convert dBZ
;                         values to Z before averaging, then convert Z-average
;                         back to dBZ.  If unset (default), then just perform
;                         simple arithmetic average.
;
; clutterFlag          -- Optional array parameter that indicates which gates in
;                         dpr_field have been identified as clutter, in addition
;                         to any flagged by binClutterFreeBottom.  Any such
;                         gates will be treated as below-threshold in the
;                         averaging and will be rejected from the average.  If
;                         any clutter bins are present in the layer to be
;                         averaged then this will be indicated by adding 10 to
;                         the clutterStatus value.
;
;
; HISTORY
; -------
; 06/26/13  Morris/GPM GV/SAIC
; - Created from get_pr_layer_average.pro.
; 06/10/15  Morris/GPM GV/SAIC
; - Added optional clutterFlag parameter and logic to find and reject clutter
;   gates in the layer average.
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-

FUNCTION get_dpr_layer_average, gateStart, gateEnd, scan, ray, dpr_field, $
                                scale_fac, min_val, num_in_avg, $
                                binClutterFreeBottom, clutterStatus, $
                                CLUTTERFLAG=clutterFlag, LOGAVG=logAvg_in

   logAvg = KEYWORD_SET(logAvg_in)
   IF N_ELEMENTS(clutterFlag) EQ 0 THEN checkClutter=0 ELSE checkClutter=1

   sum_val = 0.0D
   num2avg = 0
   have_clutter = 0

   IF N_ELEMENTS(binClutterFreeBottom) GT 1 THEN BEGIN
      maxgate = binClutterFreeBottom[ray,scan]-1 > 0   ; subtract 1 for 0-based
      IF gateStart GT maxgate THEN BEGIN
        ;print, "Entire layer in clutter region, take lowest clutter-free gate."
         gate1st = maxgate
         gatelast = maxgate
         IF N_ELEMENTS(clutterStatus) EQ 1 THEN clutterStatus=2
      ENDIF ELSE BEGIN
        ;print, "Part of layer in clutter region, take above lowest clutter-free gate."
         gate1st = gateStart
         gatelast =  gateEnd < maxgate
         IF N_ELEMENTS(clutterStatus) EQ 1 THEN $
            IF gateEnd GT maxgate THEN clutterStatus=1 ELSE clutterStatus=0
      ENDELSE
   ENDIF ELSE BEGIN
      ; no clutter region information, use gate values provided
      gate1st = gateStart
      gatelast = gateEnd
   ENDELSE

   FOR gateN = gate1st, gatelast DO BEGIN
      IF (checkClutter) THEN BEGIN
         IF clutterFlag[gateN,ray,scan] EQ 80b THEN BEGIN
            prval = min_val-1.0   ; set gate value to below threshold
            have_clutter = 1      
         ENDIF ELSE BEGIN
            prval = dpr_field[gateN,ray,scan]/scale_fac
         ENDELSE
      ENDIF ELSE BEGIN
         prval = dpr_field[gateN,ray,scan]/scale_fac     ; unscale values
      ENDELSE

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
      gateN = (gate1st + gatelast)/2
      pr_avg = dpr_field[gateN,ray,scan]/scale_fac
   ENDIF ELSE BEGIN
      IF ( logAvg EQ 0 ) THEN BEGIN
         pr_avg = sum_val/num2avg
      ENDIF ELSE BEGIN
         pr_avg = 10.*ALOG10(sum_val/num2avg)  ; average, and convert to dB
      ENDELSE
   ENDELSE

num_in_avg = num2avg
IF N_ELEMENTS(clutterStatus) EQ 1 AND have_clutter EQ 1 $
   THEN clutterStatus = clutterStatus+10   ; indicate clutter bins within layer

RETURN, FLOAT(pr_avg)
END
