;===============================================================================
;+
; Copyright © 2008, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; uniq_sweeps.pro          Morris/SAIC/GPM_GV      October 2008
;
; DESCRIPTION
; -----------
; A more forgiving version of the IDL function UNIQ.  Given an array 'sweeplist'
; of radar elevation angles, determines the array indices and values of the
; non-duplicate elevations within sweeplist, based on an angular difference
; threshold rather than identifying and eliminating absolutely identical values.
; Returns the index array as the function return value, and returns the list of
; unique elevation angles in the supplied parameter 'uniqlist'.
;
; HISTORY
; -------
; 10/2008 by Bob Morris, GPM GV (SAIC)
;  - Created.
;
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;===============================================================================
FUNCTION uniq_sweeps, sweeplist, uniqlist

nsweeps = N_ELEMENTS(sweeplist)

; to hold array indices of unique elevations in sweeplist:
tempidx = INTARR(nsweeps)
tempidx[*] = 0

; to hold values of unique elevations in sweeplist:
templist = sweeplist

num_uniq = 1
FOR i = 1, nsweeps-1 DO BEGIN
   IF ( ABS(sweeplist[i]-sweeplist[i-1]) GT 0.05 ) THEN BEGIN
      templist[num_uniq] = sweeplist[i]
      tempidx[num_uniq] = i
      num_uniq = num_uniq + 1
   ENDIF
ENDFOR

uniqlist = templist[0:num_uniq-1]
idxuniq = tempidx[0:num_uniq-1]

RETURN, idxuniq
END
