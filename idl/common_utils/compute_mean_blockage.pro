;===============================================================================
;+
; Copyright © 2015, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; compute_mean_blockage.pro           Morris/SAIC/GPM_GV      Nov 2015
;
; DESCRIPTION
; -----------
; Program to compute mean ground radar beam blockage for GR-to-satellite
; volume-match samples on a given sweep.

; Computes mean ground radar beam blockage for a subset of DPR footprints at
; GR-relative cartesian coordinates (dpr_x[idxdpr,iswp],dpr_y[idxdpr,iswp]) on
; the iswp level array index, and assigns the mean blockages to the 'idxdpr'
; position(s) in the 'iswp' level of the blockage data array 'avg_blockage'.
; GR beam blockage values are contained in the polar data array 'blockage4swp',
; whose x- and y-coordinates (in km relative to the radar) are contained in the
; arrays blok_x and blok_y.  All x-y coordinates must be previously computed and
; provided by the caller.  The arrays dpr_x, dpr_y and avg_blockage include all
; sweep levels, where the second array index is the sweep level, iswp.  The
; arrays blockage4swp, blok_x, and blok_y are for the single sweep elevation
; angle corresponding to the iswp level.
;
; If the ZERO_FILL parameter is set, then the blockage4swp array, the four x/y
; coordinate parameters, and max_sep positional parameters are all optional and
; ignored, and the positions in the avg_blockage array defined by iswp and
; idxdpr are just set to 0.0 to indicate no blockage.
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;===============================================================================

pro compute_mean_blockage, iswp, idxdpr, avg_blockage, blockage4swp, max_sep, $
                           dpr_x, dpr_y, blok_x, blok_y, ZERO_FILL=zero_fill, $
                           VERBOSE=verbose

; we need at least the first 3 parameters if doing zero fill, or all 8
; parameters if not doing zero fill
IF ( N_PARAMS() LT 3 ) $
   OR ( N_PARAMS() GE 3 AND N_PARAMS() LT 9 AND KEYWORD_SET(zero_fill) NE 1 ) $
THEN message, "Incomplete parameters supplied."

IF KEYWORD_SET(zero_fill) THEN BEGIN

   IF KEYWORD_SET(verbose) THEN print, "In the ZERO_FILL situation as directed."
   avg_blockage[idxdpr,iswp] = 0.0   ; and we're done!

ENDIF ELSE BEGIN

   IF KEYWORD_SET(verbose) THEN print, "Computing mean blockage for footprints."
   max_sep_SQR = max_sep^2   ; use fixed radius of influence of 5 km

  ; loop through the footprints, find the blockage bins within a cutoff
  ; distance of the footprint center, and compute a distance-weighted mean
  ; blockage value
   for ifoot = 0, N_ELEMENTS(idxdpr)-1 do begin
      rufdistx = ABS( blok_x - dpr_x[idxdpr[ifoot],iswp] )
      rufdisty = ABS( blok_y - dpr_y[idxdpr[ifoot],iswp] )
      ruff_distance = rufdistx > rufdisty    ; ditto
      irough = WHERE( ruff_distance LT max_sep, nrough )
      IF nrough GT 0 THEN BEGIN
        ; check for an all-zeroes status in the blockage file within the
        ; rough distance box.  If all zeroes, then skip the distance-
        ; weighted mean calculations
         idxNotZero = WHERE(blockage4swp[irough] GT 0.0, nNotZero)
         IF nNotZero EQ 0 THEN BEGIN
            avg_blockage[idxdpr[ifoot],iswp] = 0.0
         ENDIF ELSE BEGIN
            ;print, "Non-zero blockage for ifoot ", ifoot
           ; compute square of true distance from footprint center
            distsqr = ( blok_x[irough] - dpr_x[idxdpr[ifoot],iswp] )^2 $
                     +( blok_y[irough] - dpr_y[idxdpr[ifoot],iswp] )^2
            closebyidx = WHERE(distsqr le max_sep_SQR, countclose )
           ; compute the weights for the near-enough blockage bins
            weighting = EXP( - (distsqr[closebyidx]/max_sep_SQR) )
           ; compute the distance-weighted mean
            avg_blockage[idxdpr[ifoot],iswp] = $
               TOTAL(blockage4swp[irough[closebyidx]] * weighting) / $
               TOTAL(weighting)
            ;print, TOTAL(blockage4swp[irough[closebyidx]] * weighting) / $
            ;       TOTAL(weighting)
         ENDELSE
      ENDIF ELSE message, "No blockage x,y within "+STRING(max_sep)+" km? !!"
   endfor

ENDELSE

end

