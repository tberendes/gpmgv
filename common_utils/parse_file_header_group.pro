;+
; Copyright © 2013, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; DESCRIPTION
; Parses a PPS FileHeader Group in a single string into its individual metadata
; elements.  Takes either a FileHeader structure or the FileHeader attribute
; value (a formatted string) read from a PPS HDF5 file as input, parses it,
; and returns a separate structure containing the individual metadata element
; names as the structure tags, and the metadata values as the structure values,
; converted to appropriate IDL data types.  An example FileHeader metadata
; string is as follows, where the trailing ';' and newlines are part of the
; string, and the leading ';    ' is not:
;
;    DOI=Test_DOI;
;    AlgorithmID=1CGMI;
;    AlgorithmVersion=2014-N;
;    FileName=1C.GPM.GMI.XCAL2014-N.20110331-S003811-E021033.076171.V00B.HDF5;
;    SatelliteName=GPM;
;    InstrumentName=GMI;
;    GenerationDateTime=2013-04-23T15:46:01.000Z;
;    StartGranuleDateTime=2011-03-31T00:38:12.688Z;
;    StopGranuleDateTime=2011-03-31T02:10:33.882Z;
;    GranuleNumber=76171;
;    NumberOfSwaths=2;
;    NumberOfGrids=0;
;    GranuleStart=SOUTHERNMOST_LATITUDE;
;    TimeInterval=ORBIT;
;    ProcessingSystem=PPS;
;    ProductVersion=V00B;
;    EmptyGranule=NOT_EMPTY;
;    MissingData=0;
;
;
; HISTORY
; -------
; 05/29/13  Morris/GPM GV/SAIC
; - Created.
; 01/07/14  Morris/GPM GV/SAIC
; - Added DOI (Digital Object Identifier) metadata element.
; - Changed default values of numeric types to -1 instead of 0 to differentiate
;   undefined values from expected values.
; 11/24/15  Morris/GPM GV/SAIC
; - Added DOIauthority and DOIshortName metadata elements for V04x version.
; - Check for "LT 18" rather than "NE 18" since V03 and V04 have different
;   counts of elements in the group.
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-

FUNCTION parse_file_header_group, TKIOfileHeaderStruc

s=SIZE(TKIOfileHeaderStruc, /TYPE)
CASE s OF
       8 : InStruct = TKIOfileHeaderStruc._data
       7 : InStruct = TKIOfileHeaderStruc
    ELSE : message, "Passed argument type not a string or structure."
ENDCASE

; define a regular expression to split a string terminated by ';' with or
; without a trailing newline
new='[ ;*' + STRING(10b) + ' ]'

parsed=strsplit(InStruct, new, /REGEX, /EXTRACT)
IF N_ELEMENTS(parsed) LT 18 THEN BEGIN
   message, "Incorrect number of variables in file header.", /INFO
   print, "Dump of header data:"
   print, InStruct
ENDIF

; set up the return structure
fileHeaderStruc = { fileHeaderStruc,               $
                                DOI : "UNDEFINED", $
                       DOIauthority : "UNDEFINED", $
                       DOIshortName : "UNDEFINED", $
                        AlgorithmID : "UNDEFINED", $
                   AlgorithmVersion : "UNDEFINED", $
                           FileName : "UNDEFINED", $
                      SatelliteName : "UNDEFINED", $
                     InstrumentName : "UNDEFINED", $
                 GenerationDateTime : "UNDEFINED", $
               StartGranuleDateTime : "UNDEFINED", $
                StopGranuleDateTime : "UNDEFINED", $
                      GranuleNumber : -1L, $
                     NumberOfSwaths : -1, $
                      NumberOfGrids : -1, $
                       GranuleStart : "UNDEFINED", $
                       TimeInterval : "UNDEFINED", $
                   ProcessingSystem : "UNDEFINED", $
                     ProductVersion : "UNDEFINED", $
                       EmptyGranule : "UNDEFINED", $
                        MissingData : -1 }

for ivar = 0, N_ELEMENTS(parsed)-1 DO BEGIN
   varparse = STRSPLIT(parsed[ivar], '=', /EXTRACT)
   IF N_ELEMENTS(varparse) NE 2 THEN BEGIN
      message, "Missing name or value in FileHeader: "+parsed[ivar], /INFO
      continue
   ENDIF
   CASE varparse[0] OF
        'DOI' : fileHeaderStruc.DOI = varparse[1]
        'DOIauthority' : fileHeaderStruc.DOIauthority = varparse[1]
        'DOIshortName' : fileHeaderStruc.DOIshortName = varparse[1]
        'AlgorithmID' : $
            fileHeaderStruc.AlgorithmID = varparse[1]
        'AlgorithmVersion' : $
            fileHeaderStruc.AlgorithmVersion = varparse[1]
        'FileName' : $
            fileHeaderStruc.FileName = varparse[1]
        'SatelliteName' : $
            fileHeaderStruc.SatelliteName = varparse[1]
        'InstrumentName' : $
            fileHeaderStruc.InstrumentName = varparse[1]
        'GenerationDateTime' : $
            fileHeaderStruc.GenerationDateTime = varparse[1]
        'StartGranuleDateTime' : $
            fileHeaderStruc.StartGranuleDateTime = varparse[1]
        'StopGranuleDateTime' : $
            fileHeaderStruc.StopGranuleDateTime = varparse[1]
        'GranuleNumber' : $
            fileHeaderStruc.GranuleNumber = LONG(varparse[1])
        'NumberOfSwaths' : $
            fileHeaderStruc.NumberOfSwaths = FIX(varparse[1])
        'NumberOfGrids' : $
            fileHeaderStruc.NumberOfGrids = FIX(varparse[1])
        'GranuleStart' : $
            fileHeaderStruc.GranuleStart = varparse[1]
        'TimeInterval' : $
            fileHeaderStruc.TimeInterval = varparse[1]
        'ProcessingSystem' : $
            fileHeaderStruc.ProcessingSystem = varparse[1]
        'ProductVersion' : $
            fileHeaderStruc.ProductVersion = varparse[1]
        'EmptyGranule' : $
            fileHeaderStruc.EmptyGranule = varparse[1]
        'MissingData' : $
            fileHeaderStruc.MissingData = FIX(varparse[1])
        ELSE : message, "Unknown variable definition in metadata: "+parsed[ivar]
   ENDCASE
endfor

return, fileHeaderStruc
end
