;+
; Copyright © 2009, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
;  s_band_to_ku_band.pro   Morris/SAIC/GPM_GV      June 2009
;
;  SYNOPSIS:
;  dbz_adjusted = s_band_to_ku_band( dbzarray, raintype_string )
;
;  DESCRIPTION:
;  Takes pre-filtered 1-D array of S-band GV reflectivity (dBZ), and a Rain Type
;  string, and returns the equivalent Ku-band reflectivity array using Liang
;  Liao's adjustment.
;  
;  The raintype_string parameter is case-insensitive, and must begin with either
;  'R' (for rain, i.e., below-bright-band), or 'S' (for snow, i.e., above bright
;  band).
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-

FUNCTION S_BAND_TO_KU_BAND, DBZ_S, TYPE

IF N_PARAMS() NE 2 THEN BEGIN
   PRINT, ""
   PRINT, "Incorrect number of parameters in S_BAND_TO_KU_BAND(), two required."
   PRINT, "Returning reflectivity field unmodified."
   PRINT, ""
   RETURN, DBZ_S
ENDIF

; strip leading whitespace, take the 1st character, and convert to upper case
type1 = STRMID( STRUPCASE( STRTRIM(type,1) ) , 0, 1)

CASE type1 OF

   'R'  : RETURN, -1.50393 + 1.07274 * DBZ_S + 0.000165393 * DBZ_S^2  ; rain

   'S'  : RETURN, 0.185074 + 1.01378 * DBZ_S - 0.00189212 * DBZ_S^2   ; snow

   ELSE : BEGIN
             PRINT, ""
             PRINT, "Invalid precip particle type in S_BAND_TO_KU_BAND(): ", type
             PRINT, "Returning reflectivity field unmodified."
             PRINT, ""
             RETURN, DBZ_S
          END

ENDCASE

END
