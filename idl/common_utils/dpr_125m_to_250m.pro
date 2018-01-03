;===============================================================================
;+
; Copyright © 2016, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; dpr_125m_to_250m.pro       Morris/GPM GV/SAIC     February 2016
;
; DESCRIPTION
; Takes an array of 125-m-resolution 3-D DPR reflectivity data and computes a
; matching 250-m-resolution array using the 2B-DPRGMI averaging.  Returns
; a 2B-DPRGMI compatible array of reflectivity at the vertical gates covered by
; that product.  The parameters dbz_125m and binClutterFreeBottom are the full
; orbit subset product arrays read from the 2ADPR/Ka/Ku product.  The arrays
; Rays and Scans are only for those DPR footprints within the matchup overlap
; area between the DPR and GR, and give the coordinates of the ray columns
; where we will compute 250m resolution gate values, leaving the values at the
; other rays initialized to MISSING.
;
; HISTORY
; -------
; 11/15/16  Morris/SAIC/GPM-GV
; - Added parameters maxZ250, maxZ125 and logic to compute max Z along each ray
;   from computed 250-m and original 125-m gates.  125-m max Z I/O parameter and
;   logic are disabled pending a requirement for maxZ125.
;
; EMAIL QUESTIONS OR COMMENTS AT:
;       https://pmm.nasa.gov/contact
;-
;===============================================================================

FUNCTION dpr_125m_to_250m, dbz_125m, Rays, Scans, binClutterFreeBottom, $
                           ELLIPSOID_BIN_DPR, MAXZ250=maxZ250 ;, MAXZ125=maxZ125

@dpr_params.inc  ; for definition of ELLIPSOID_BIN_DPRGMI, etc.

; create a 2B-DPRGMI sized array of Z for the same number of rays and scans
; as the input DPR Z array but with only 88 (ELLIPSOID_BIN_DPRGMI) gates in the
; vertical, and initialized to the 2B-DPRGMI "MISSING" value
sz = SIZE(dbz_125m, /DIMENSIONS)
dbz_250m = MAKE_ARRAY(ELLIPSOID_BIN_DPRGMI, sz[1], sz[2], /float, VALUE=-9999.9)

IF N_ELEMENTS(maxZ250) NE 0 THEN BEGIN
  ; check dimensions of the passed-in one-level array to hold max 250-m Z in
  ; the full vertical column at each DPR footprint
   IF N_ELEMENTS(maxZ250) NE N_ELEMENTS(Rays) THEN message, $
      "MAXZ250 parameter variable is of incorrect dimensions."
ENDIF

IF N_ELEMENTS(maxZ125) NE 0 THEN BEGIN
  ; ditto, but for the unaveraged 125-m gates.
   IF N_ELEMENTS(maxZ125) NE N_ELEMENTS(Rays) THEN message, $
      "MAXZ125 parameter variable is of incorrect dimensions."
ENDIF

; determine the nearest-surface 250m clutter free bin for each ray
; - 125m DPR gate pairs to be averaged are only those above, and not including,
;   the lowest clutter-free gate as identified in the 125m data

; In the computation below, subtract 1 for 0-based, and 1 more for 1 gate above
; the 125-m clutter-free bottom gate.  Remember that gate numbers above
; binClutterFreeBottom are in the surface clutter region, while lower gate
; numbers are higher in the atmosphere, above the clutter zone.
maxgate250 = (binClutterFreeBottom-2)/2

nfeet2do = N_ELEMENTS(Rays)

for iray=0, nfeet2do-1 do begin
   IF N_ELEMENTS(maxZ125) NE 0 THEN BEGIN
     ; grab the 125-m column of Z above the clutter region and find its maximum
      thisClutterFreeBin = binClutterFreeBottom[ Rays[iray], Scans[iray] ] - 1
      thisMax125 = MAX( dbz_125m[0:thisClutterFree, Rays[iray], Scans[iray]] )
      IF thisMax125 GT 0.0 THEN maxZ125[iray] = thisMax125
   ENDIF

  ; grab the stopping gate along the 250-m ray of data
   lastgate = maxgate250[ Rays[iray], Scans[iray] ]

  ; Compute Z values for the 250-m gates above the clutter region.
  ; Note that we are working our way down from gate 0 the top of the atmosphere,
  ; stopping at 'lastgate' just above where clutter is detected, so gates in the
  ; clutter region are left as initialized (-9999.9)
   for gate250 = 0, lastgate do begin
       gates2avg = dbz_125m[ 2*gate250 : 2*gate250+1, Rays[iray], Scans[iray] ]
       idx2avg = WHERE(gates2avg GT 0.0, count2avg)
       IF count2avg EQ 2 THEN $
          dbz_250m[gate250, Rays[iray], Scans[iray]] = MEAN(gates2avg) $
       ELSE IF count2avg EQ 1 THEN $
          dbz_250m[gate250, Rays[iray], Scans[iray]] = gates2avg[idx2avg]
   endfor
   IF N_ELEMENTS(maxZ250) NE 0 THEN BEGIN
     ; grab the 250-m column of Z and find its maximum, if not missing (<=0.0)
      thisMax250 = MAX( dbz_250m[*, Rays[iray], Scans[iray]] )
      IF thisMax250 GT 0.0 THEN maxZ250[iray] = thisMax250
   ENDIF
endfor

return, dbz_250m
end

