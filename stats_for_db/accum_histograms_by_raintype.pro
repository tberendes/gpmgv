;+
; Copyright © 2014, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
;  accum_histograms_by_raintype.pro   Morris/SAIC/GPM_GV      September 2014
;
;  SYNOPSIS:
;  accum_histograms_by_raintype, dbz_pr, dbz_gr, raintype, accum_ptrs, $
;                                lev2get, binz
;
;  DESCRIPTION
;  -----------
;  Takes pre-filtered 1-D arrays of PR and GV reflectivity (dBZ), Rain Type,
;  a 6xN array of pointers, a height level index 'lev2get', and a scalar-
;  initialized variable 'binz' as input, where N is the number of height levels
;  of reflectivity data (known only to the calling routine)
;.
;  Computes cumulative histograms of the PR and GR reflectivity (dBZ) values,
;  for all 6 permutations of rain type (any, convective, and stratiform) and
;  data source (PR and GR).  Assigns or accumulates the pointer variable for
;  the permutation and height level index with the histogram result.  Overwrites
;  binz with the "LOCATIONS" of the histogram bins the first time a histogram is
;  successfully run (valid PR or GR data) in a series of calls to this routine.
;
; HISTORY
; -------
; 09/16/2014  Morris/GPM GV/SAIC
; - Created.
;
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-

PRO accum_histograms_by_raintype, dbz_pr, dbz_gr, raintype, $
                                  accum_ptrs, lev2get, binz

; "include" file for PR data constants
@pr_params.inc

; run the histograms of PR and GR for each rain type.  Add to histogram
; accumulations if they exist, or initialize histogram accumulations if they
; do not yet exist

; Order is PR any, PR Stratiform, PR Convective, GR Any, GR Stratiform,
; GR Convective for the first dimension of the accum_ptrs array

idxconv = where(raintype eq RainType_convective, countconv)
idxstrat = where(raintype eq RainType_stratiform, countstrat)

; Compute histogram of PR dBZ without regard for rain type
; -- compute HISTOGRAM LOCATIONS values and overwrite binz if it hasn't been
;    assigned yet (i.e., if it's still just a scalar variable)
IF N_ELEMENTS(binz) EQ 1 $
THEN hist = HISTOGRAM(dbz_pr, MIN=5.0, MAX=75.0, BINS=0.5, /L64, LOCATIONS=binz) $
ELSE hist = HISTOGRAM(dbz_pr, MIN=5.0, MAX=75.0, BINS=0.5, /L64)

; assign or accumulate array to pointer for the PR/Any rain type combination
IF *accum_ptrs[0,lev2get] EQ !NULL THEN $
   ; assign the histogram array as the pointed-to variable
   *accum_ptrs[0,lev2get] = TEMPORARY(hist) $
ELSE $
   ; add this histogram to the existing pointed-to array
   *accum_ptrs[0,lev2get] = *accum_ptrs[0,lev2get] + TEMPORARY(hist)

; ditto for PR/Stratiform
IF countstrat GT 0 THEN BEGIN
   hist = HISTOGRAM(dbz_pr[idxstrat], MIN=5.0, MAX=75.0, BINS=0.5, /L64)
   IF *accum_ptrs[1,lev2get] EQ !NULL THEN $
      *accum_ptrs[1,lev2get] = TEMPORARY(hist) $
   ELSE $
      *accum_ptrs[1,lev2get] = *accum_ptrs[1,lev2get] + TEMPORARY(hist)
ENDIF

; ditto for PR/Convective
IF countconv GT 0 THEN BEGIN
   hist = HISTOGRAM(dbz_pr[idxconv], MIN=5.0, MAX=75.0, BINS=0.5, /L64)
   IF *accum_ptrs[2,lev2get] EQ !NULL THEN $
      *accum_ptrs[2,lev2get] = TEMPORARY(hist) $
   ELSE $
      *accum_ptrs[2,lev2get] = *accum_ptrs[2,lev2get] + TEMPORARY(hist)
ENDIF

; ditto for GR/Any
hist = HISTOGRAM(dbz_gr, MIN=5.0, MAX=75.0, BINS=0.5, /L64)
IF *accum_ptrs[3,lev2get] EQ !NULL THEN $
   *accum_ptrs[3,lev2get] = TEMPORARY(hist) $
ELSE $
   *accum_ptrs[3,lev2get] = *accum_ptrs[3,lev2get] + TEMPORARY(hist)

; ditto for GR/Stratiform
IF countstrat GT 0 THEN BEGIN
   hist = HISTOGRAM(dbz_gr[idxstrat], MIN=5.0, MAX=75.0, BINS=0.5, /L64)
   IF *accum_ptrs[4,lev2get] EQ !NULL THEN $
      *accum_ptrs[4,lev2get] = TEMPORARY(hist) $
   ELSE $
      *accum_ptrs[4,lev2get] = *accum_ptrs[4,lev2get] + TEMPORARY(hist)
ENDIF

; ditto for GR/Convective
IF countconv GT 0 THEN BEGIN
   hist = HISTOGRAM(dbz_gr[idxconv], MIN=5.0, MAX=75.0, BINS=0.5, /L64)
   IF *accum_ptrs[5,lev2get] EQ !NULL THEN $
      *accum_ptrs[5,lev2get] = TEMPORARY(hist) $
   ELSE $
      *accum_ptrs[5,lev2get] = *accum_ptrs[5,lev2get] + TEMPORARY(hist)
ENDIF

END
