;+
; Copyright © 2013, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; DESCRIPTION
; Parses a PPS SwathHeader Group in a single string into its individual metadata
; elements.  Takes either a SwathHeader structure or the SwathHeader attribute
; value (a formatted string) read from a PPS HDF5 file as input, parses it,
; and returns a separate structure containing the individual metadata element
; names as the structure tags, and the metadata values as the structure values,
; converted to appropriate IDL data types.  An example SwathHeader metadata
; string is as follows, where the trailing ';' and newlines are part of the
; string, and the leading ';    ' is not:
;
;    NumberScansInSet=1;
;    MaximumNumberScansTotal=3100;
;    NumberScansBeforeGranule=0;
;    NumberScansGranule=2919;
;    NumberScansAfterGranule=0;
;    NumberPixels=221;
;    ScanType=CONICAL;
;
;
; HISTORY
; -------
; 05/29/13  Morris/GPM GV/SAIC
; - Created.
; 01/07/14  Morris/GPM GV/SAIC
; - Added source labeling optional parameter 'label' to call sequence and
;   output structure, since SwathHeader group is swath-specific and more than
;   one may be present in product.  Brings this group in line with SCStatus etc.
;
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-

FUNCTION parse_swath_header_group, TKIOswathHeaderStruc, label

IF N_PARAMS() LT 2 THEN label = 'UNDEFINED'

s=SIZE(TKIOswathHeaderStruc, /TYPE)
CASE s OF
       8 : InStruct = TKIOswathHeaderStruc._data
       7 : InStruct = TKIOswathHeaderStruc
    ELSE : message, "Passed argument type not a string or structure."
ENDCASE

; define a regular expression to split a string terminated by ';' with or
; without a trailing newline
new='[ ;*' + STRING(10b) + ' ]'

parsed=strsplit(InStruct, new, /REGEX, /EXTRACT)
IF N_ELEMENTS(parsed) NE 7 THEN BEGIN
   message, "Incorrect number of variables in swath header.", /INFO
   print, "Dump of header data:"
   print, InStruct
ENDIF

; set up the return structure
swathHeaderStruc = { swathHeaderStruc, $
                               source : label, $
                     NumberScansInSet : 0, $
              MaximumNumberScansTotal : 0L, $
             NumberScansBeforeGranule : 0, $
                   NumberScansGranule : 0L, $
              NumberScansAfterGranule : 0, $
                         NumberPixels : 0, $
                             ScanType : "UNDEFINED" }

for ivar = 0, N_ELEMENTS(parsed)-1 DO BEGIN
   varparse = STRSPLIT(parsed[ivar], '=', /EXTRACT)
   CASE varparse[0] OF
        'NumberScansInSet' : $
            swathHeaderStruc.NumberScansInSet = FIX(varparse[1])
        'MaximumNumberScansTotal' : $
            swathHeaderStruc.MaximumNumberScansTotal = LONG(varparse[1])
        'NumberScansBeforeGranule' : $
            swathHeaderStruc.NumberScansBeforeGranule = FIX(varparse[1])
        'NumberScansGranule' : $
            swathHeaderStruc.NumberScansGranule = LONG(varparse[1])
        'NumberScansAfterGranule' : $
            swathHeaderStruc.NumberScansAfterGranule = FIX(varparse[1])
        'NumberPixels' : $
            swathHeaderStruc.NumberPixels = FIX(varparse[1])
        'ScanType' : $
            swathHeaderStruc.ScanType = varparse[1]
        ELSE : message, "Unknown variable definition in metadata: "+parsed[ivar]
   ENDCASE
endfor

return, swathHeaderStruc
end
