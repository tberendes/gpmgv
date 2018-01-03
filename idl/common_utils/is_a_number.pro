;===============================================================================
;+
; is_a_number.pro      Morris/SAIC/GPM_GV     March 2015
;
; DESCRIPTION
; -----------
; Takes an argument of unknown type and determines whether its value(s) can be
; converted to numerical type.  Returns 1 if value(s) can be converted, 0 if
; otherwise.  Unfortunately, will return 1 if the argument is empty string(s).
;
; HISTORY
; -------
; 03/31/15 Morris, GPM GV, SAIC
; - Created (i.e., googled).
;-
;===============================================================================

FUNCTION is_a_number, testValue
   ON_IOERROR, FALSE
   test = DOUBLE(testValue)
   return, 1
   FALSE: return, 0
end

