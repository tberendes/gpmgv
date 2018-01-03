;===============================================================================
;+
; Copyright © 2010, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; z_r_rainrate.pro
; - Morris/SAIC/GPM_GV  March 2010
;
; DESCRIPTION
; -----------
; Computes rain rate from radar Reflectivity Factor in Z or dBZ, using
; either supplied coefficients a and b of the relation Z=aR^b, or a set of
; default coefficients (a=300.0, b=1.4) for the WSR-88D S-band radars.  Assumes
; the input reflectivity field 'zfield' is Reflectivity in dBZ, unless the
; keyword parameter IS_Z is set to indicate Reflectivity Factor (Z).  Only those
; positive, non-zero values of zfield are used to compute rain rate--all other
; values are set to a MISSING value.
;
; Returns an array of rain rate in mm/h, of the same size/dimension as zfield.
;
; PARAMETERS
; ----------
; zfield - array of reflectivity (factor) for which to compute rain rates
; zra    - parameter "a" in Z=aR^b, defaults to 300.0 if not specified
; zrb    - parameter "b" in Z=aR^b, defaults to 1.4 if not specified
; is_z   - binary parameter.  If set, do not convert zfield from dBZ to Z
;
; HISTORY
; -------
; 03/04/10 Morris, GPM GV, SAIC
; - Created.
; 04/09/14 Morris, GPM GV, SAIC
; - Fixed so that the number of dimensions of the returned array are the same
;   as those of the input zfield array.
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;===============================================================================

FUNCTION z_r_rainrate, zfield, ZRA=zra, ZRB=zrb, IS_Z=is_z

@pr_params.inc  ; for Z_MISSING

rainrate = Z_MISSING   ; initialize a return value in case we fail early

IF ( N_ELEMENTS(zra) GT 1 ) THEN BEGIN
   print, "In z_r_rainrate(): Error in ZRA parameter, should be a scalar float variable."
   help, zra
   goto, errorExit
ENDIF ELSE IF ( N_ELEMENTS(zra) EQ 0 ) THEN zra = 300.0

IF ( N_ELEMENTS(zrb) GT 1 ) THEN BEGIN
   print, "In z_r_rainrate(): Error in ZRB parameter, should be a scalar float variable."
   help, zrb
   goto, errorExit
ENDIF ELSE IF ( N_ELEMENTS(zrb) EQ 0 ) THEN zrb = 1.4

is_z = KEYWORD_SET( is_z )

; create an array for rain rate of the same size as zfield, initialized
; to MISSING (-9999.0)

rainrate = REPLICATE( rainrate, SIZE(zfield, /DIMENSIONS) )

; find the points that have valid reflectivity values, and compute rainrate at
; these points only by inverting Z=aR^b

idx2rain = WHERE( zfield GT 0.0, count2rain )
IF (count2rain GT 0) THEN BEGIN
   IF ( is_z ) THEN BEGIN
      rainrate[idx2rain] = (zfield[idx2rain]/zra)^(1/zrb)
   ENDIF ELSE BEGIN
      rainrate[idx2rain] =  ( (10.^(0.1*zfield[idx2rain])) / zra) ^ (1/zrb)
   ENDELSE
ENDIF

errorExit:
return,rainrate

end
