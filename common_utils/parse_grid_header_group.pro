;+
; Copyright © 2013, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; DESCRIPTION
; -----------
; Parses a PPS GridHeader Group in a single string into its individual metadata
; elements.  Takes either a GridHeader structure or the GridHeader attribute
; value (a formatted string) read from a PPS HDF5 file as input, parses it,
; and returns a separate structure containing the individual metadata element
; names as the structure tags, and the metadata values as the structure values,
; converted to appropriate IDL data types.  An example GridHeader metadata
; string is as follows, where the trailing ';' and newlines are part of the
; string, and the leading ';    ' is not:
;
;    BinMethod=ARITHMETIC_MEAN;
;    Registration=CENTER;
;    LatitudeResolution=0.1;
;    LongitudeResolution=0.1;
;    NorthBoundingCoordinate=90;
;    SouthBoundingCoordinate=-90;
;    EastBoundingCoordinate=180;
;    WestBoundingCoordinate=-180;
;    Origin=SOUTHWEST;
;
;
; HISTORY
; -------
; 12/24/13  Morris/GPM GV/SAIC
; - Created from parse_swath_header_group.pro
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-

FUNCTION parse_grid_header_group, TKIOgridHeaderStruc

s=SIZE(TKIOgridHeaderStruc, /TYPE)
CASE s OF
       8 : InStruct = TKIOgridHeaderStruc._data
       7 : InStruct = TKIOgridHeaderStruc
    ELSE : message, "Passed argument type not a string or structure."
ENDCASE

; define a regular expression to split a string terminated by ';' with or
; without a trailing newline
new='[ ;*' + STRING(10b) + ' ]'

parsed=strsplit(InStruct, new, /REGEX, /EXTRACT)
IF N_ELEMENTS(parsed) NE 9 THEN BEGIN
   message, "Incorrect number of variables in grid header.", /INFO
   print, "Dump of header data:"
   print, InStruct
ENDIF

; set up the return structure
gridHeaderStruc = { gridHeaderStruc, $
                          BinMethod  : "UNDEFINED", $
                        Registration : "UNDEFINED", $
                  LatitudeResolution : 0, $
                 LongitudeResolution : 0L, $
             NorthBoundingCoordinate : 0, $
              SouthBoundingCoordinate: 0L, $
              EastBoundingCoordinate : 0, $
              WestBoundingCoordinate : 0, $
                              Origin : "UNDEFINED" }

for ivar = 0, N_ELEMENTS(parsed)-1 DO BEGIN
   varparse = STRSPLIT(parsed[ivar], '=', /EXTRACT)
   CASE varparse[0] OF
        'BinMethod' : $
            gridHeaderStruc.BinMethod = varparse[1]
        'Registration' : $
            gridHeaderStruc.Registration = varparse[1]
        'LatitudeResolution' : $
            gridHeaderStruc.LatitudeResolution = FLOAT(varparse[1])
        'LongitudeResolution' : $
            gridHeaderStruc.LongitudeResolution = FLOAT(varparse[1])
        'NorthBoundingCoordinate' : $
            gridHeaderStruc.NorthBoundingCoordinate = FLOAT(varparse[1])
        'SouthBoundingCoordinate' : $
            gridHeaderStruc.SouthBoundingCoordinate = FLOAT(varparse[1])
        'EastBoundingCoordinate' : $
            gridHeaderStruc.EastBoundingCoordinate = FLOAT(varparse[1])
        'WestBoundingCoordinate' : $
            gridHeaderStruc.WestBoundingCoordinate = FLOAT(varparse[1])
        'Origin' : $
            gridHeaderStruc.Origin = varparse[1]
        ELSE : message, "Unknown variable definition in metadata: "+parsed[ivar]
   ENDCASE
endfor

return, gridHeaderStruc
end
