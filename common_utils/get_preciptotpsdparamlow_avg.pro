;+
; Copyright © 2013, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; get_precipTotPSDparamLow_avg.pro         Bob Morris, GPM GV/SAIC   June 2014
;
; DESCRIPTION
; -----------
; Given the starting and ending gate numbers along a DPR ray, the ray number
; and scan number of the ray, the DPRGMI precipTotPSDparamLow data field, and 
; the PSDparamLowNode data field, computes vertical average of the data between
; specified gates.  Only those gates with values above 'min_val' are included
; in the average.  For a given scan and ray, PSDparamLowNode[0] is the gate #
; of the top of the storm, and PSDparamLowNode[8] is the gate # of the lowest
; clutter-free bin, where each "node" of PSDparamLowNode has a matching value of
; precipTotPSDparamLow at each of those 9 gates.  Values of precipTotPSDparamLow
; at intermediate gates between gateStart and gateEnd are linearly interpolated
; to each gate and averaged to produce the volume average sample.  Each node of 
; precipTotPSDparamLow has two values to be interpolated and averaged
; separately: one for Nw, and one for mu.
;
; Only those gates at or above the lowest clutter-free gate are included in the
; average.  If all the specified gates are below the lowest clutter-free gate or
; above the storm top gate then the average is left as MISSING (-9999.9).  If
; the clutterStatus parameter is provided, then the status of the clutter
; filtering for the volume average is assigned to this parameter's value, as
; follows:
;
;    0 : all gates within PSDparamLowNode bounds, no substitution or truncation
;    1 : one or more gates below lowest clutter-free gate or above storm top
;        gate, average truncated
;    2 : all gates below lowest clutter-free gate, average not computed
;    3 : all gates above storm top, average not computed
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
; precipTotPSDparamLow -- DPR precipTotPSDparamLow data field of values at nodes
;                         4-D dimensions = (type,node,ray,scan)
;
; PSDparamLowNode      -- 3-D (node,ray,scan) field of gate numbers where values
;                         of precipTotPSDparamLow are defined/located, given in
;                         terms of the full arrays of 250-m-resolution DPR gates
;                         along the ray. Node index [0] is the gate # at the top
;                         of the 'storm', and index [8] is the lowest-altitude
;                         uncluttered gate number.
;
; scale_fac            -- Factor to divide precipTotPSDparamLow by to get
;                         unscaled physical Nw and mu PSD values.  array(2)
;
; min_val              -- Minimum unscaled values to be included in the returned
;                         layer averages for Nw and mu.  array(2)
;
; num_in_avg           -- Numbers of uncluttered, above-min_val-threshold gates
;                         included in the returned layer averages for Nw and mu.
;                         array(2)
;
; clutterStatus        -- Optional scalar parameter, returns the status of check
;                         of gateStart and gateEnd proximity to clutter region.
;                         Possible status values are defined under DESCRIPTION.
;                         
;
; HISTORY
; -------
; 06/01/14  Morris/GPM GV/SAIC
; - Created from get_dpr_layer_average.pro.
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-


FUNCTION get_precipTotPSDparamLow_avg, gateStart, gateEnd, scan, ray, $
                                       precipTotPSDparamLow, PSDparamLowNode, $
                                       scale_fac, min_val, clutterStatus

params_avg = [-9999.90,-9999.90]  ; initialize returned averages to No Data
num_in_avg = [0,0]                ; ditto, number of "good" gates in averages

IF N_ELEMENTS(clutterStatus) EQ 1 THEN clutterStatus=0  ; init to "full overlap"

; grab the node gate values for our ray and scan
ourNodes = REFORM(PSDparamLowNode[*,ray,scan])

; check whether we have any overlap between node range and gateStart-gateEnd
; range.  If none, then return No Data values
base = (gateEnd GT gateStart) ? gateStart : gateEnd
geo_gates = indgen(ABS(gateStart-gateEnd)+1) + base         ; gates to average
psd_gates = indgen(ourNodes[8]-ourNodes[0]+1) + ourNodes[0] ; gates with PSDlow
idxtop = WHERE(psd_gates EQ gateStart, counttop)
idxbotm = WHERE(psd_gates EQ gateEnd, countbotm)

IF ( (counttop+countbotm) GT 0 ) THEN BEGIN
  ; Overlap exists between PSDparams and geometry match gate ranges, proceed.

  ; - grab the node PSD values for our ray and scan
   ourNwPSD = REFORM(precipTotPSDparamLow[0,*,ray,scan])
   ourMuPSD = REFORM(precipTotPSDparamLow[1,*,ray,scan])

  ; determine which gates to average based on overlap region, and reset
  ; clutterStatus based on overlap status if partial overlap
   IF counttop GT 0 THEN idxstart=idxtop ELSE BEGIN
      idxstart=0
      IF N_ELEMENTS(clutterStatus) EQ 1 THEN clutterStatus=1
   ENDELSE
   IF countbotm GT 0 THEN idxend=idxbotm ELSE BEGIN
      idxend=N_ELEMENTS(psd_gates)-1
      IF N_ELEMENTS(clutterStatus) EQ 1 THEN clutterStatus=1
   ENDELSE

  ; interpolate PSD values to overlap gates between nodes
   allNwPSD = INTERPOL(ourNwPSD,ourNodes,psd_gates[idxstart:idxend])
   allMuPSD = INTERPOL(ourMuPSD,ourNodes,psd_gates[idxstart:idxend])

  ; average the above-threshold PSD gates for Nw and Mu.  UNTIL WE GET ACTUAL
  ; min_val THRESHOLDS JUST USE -9999.0 AS THE CUTOFF

   idx2avg = WHERE(allNwPSD GT -9999.0, count2avg)
   IF count2avg GT 0 THEN params_avg[0] = MEAN(allNwPSD[idx2avg])/scale_fac[0]
   num_in_avg[0] = count2avg
   idx2avg = WHERE(allMuPSD GT -9999.0, count2avg)
   IF count2avg GT 0 THEN params_avg[1] = MEAN(allMuPSD[idx2avg])/scale_fac[1]
   num_in_avg[1] = count2avg
ENDIF ELSE BEGIN
   IF N_ELEMENTS(clutterStatus) EQ 1 THEN BEGIN
     ; sample bottom above storm top?
      IF gate_end LT ourNodes[0] THEN clutterStatus=3
     ; sample top below clutter-free bottom?
      IF gate_start GT ourNodes[8] THEN clutterStatus=2 
   ENDIF
ENDELSE

results = { params_avg : params_avg, num_in_avg : num_in_avg }
return, results
END
