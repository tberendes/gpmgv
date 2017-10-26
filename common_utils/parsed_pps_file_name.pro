;+
; Copyright © 2013, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; parsed_pps_file_name.pro         Bob Morris, GPM GV/SAIC   July 2013
;
;
; DESCRIPTION
; -----------
; Given a PPS-compliant file basename of fully-qualified file name, splits the
; file name into its major components and sub-components and returns these
; components in a structure holding all possible components.  If a component is
; not present in the input filename, its value is assigned as an empty string
; ("") in the structure.
;
; File structure is based on the "PPS File Naming Convention for Precipitation
; Products for the Global Precipitation Measurement (GPM) Mission" document, 
; December 2012 version.  One exception is the coding of a Coincident Subset
; (CS) option with '_' delimiters in the DataType component.  Its actual rules
; are still TBD, but for now it is assumed that the CS option will not occur in
; combination with Accumulation or Latency subcomponents.
;
;
; PARAMETERS
; ----------
; pps_file   -- input file name to be parsed
;
;
; HISTORY
; -------
; 07/03/13  Morris/GPM GV/SAIC
; - Created.
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-

FUNCTION parsed_pps_file_name, pps_file

   ; arrays holding all "legal" values for datalevel, accumulation type, and
   ; file extension
   definedLevels = ['1A','1B','1C','2A','2B','3A','3B','4']
   definedAccums = ['HR','HHR','DAY','PENT','7DAY','MO']
   definedExts = ['HDF4','HDF5','NCDF','BIN','TXT']

   file_base = FILE_BASENAME( pps_file )
   parsedot = STRSPLIT( file_base, '.', /EXTRACT )
   IF N_ELEMENTS( parsedot ) NE 8 THEN message, "Input PPS file '"+file_base+ $
      "' does not have the 8 expected '.'-delimited fields, or not a PPS file."

   ; see whether data type in 1st field has subtype(s) present
   IF STREGEX( parsedot[0], '(-|_)' ) NE -1 THEN BEGIN
      ; found a '-' or '_' in the data type field, parse subtypes
      ; -- TEMPORARY RULE: 'CS' subtype value indicates Coincidence Subsets
      ;    (orbit subsets), otherwise accumulation subfield(s) type assumed
      ;                    
      parsedash = STRSPLIT( parsedot[0], '(-|\_)', /EXTRACT, /REGEX  )
      CASE N_ELEMENTS( parsedash ) OF
         2 : BEGIN
                  level = parsedash[0]
                  accum = parsedash[1]
                latency = ''
                 subset = 'FullOrbit'
             END
         3 : BEGIN
                  level = parsedash[0]
                IF parsedash[1] EQ 'CS' THEN BEGIN
                    accum = ''
                  latency = ''
                   subset = parsedash[2]
                ENDIF ELSE BEGIN
                    accum = parsedash[1]
                  latency = parsedash[2]
                   subset = 'FullOrbit'
                ENDELSE
             END
         ELSE : message, "Error parsing dataType field: "+parsedot[0]
      ENDCASE
   ENDIF ELSE BEGIN
      ; no subtypes included, just set level and default subset for now and
      ; check for missing accumulation subfields below
        level = parsedot[0]
        accum = ''
      latency = ''
       subset = 'FullOrbit'
   ENDELSE

   idxlevel = WHERE( definedLevels EQ level, countlevels )
   IF countlevels NE 1 THEN message, "Illegal data level '"+level+"'"

   ; check for missing/illegal accumulation subfields, and set definition of
   ; 'sequence' field based on data level
   SWITCH STRMID( level, 0, 1 ) OF
       '1' : 
       '2' : BEGIN
               IF accum NE '' THEN message, "Illegal accumulation subfield in" $
                                            +" dataType field '"+parsedot[0]+"'"
               seqType = 'ORBIT'
               break
             END
       '3' : BEGIN
               IF accum EQ '' THEN message, "Missing accumulation subfield in" $
                                            +" dataType field '"+parsedot[0]+"'"
               idxaccum = WHERE( definedAccums EQ accum, countaccum )
               IF countaccum NE 1 THEN message,  "Illegal accumulation '"+accum+"'"
               seqType = 'PERIOD'
               break
             END
       '4' : BEGIN
               seqType = 'TBD'
               break
             END
      ELSE : message, "Illegal data level: "+level
   ENDSWITCH

   satellite = parsedot[1]
   instrument = parsedot[2]
   algorithm = parsedot[3]

   ; split out the start date, start time, and end time subfields
   ; -- first define the regular expression for the complete datetime field
   ; -- this expression is not totally rigorous as to allowable dates/times
   dtExpr = '(19|20)[0-9]{2}[0-1][0-9][0-3][0-9]-S[0-2][0-9]{5}-E[0-2][0-9]{5}'
   IF STREGEX( parsedot[4], dtExpr ) EQ 0 THEN BEGIN
      parseS = STRSPLIT( parsedot[4], '-S', /EXTRACT, /REGEX )
      yyyymmdd = parseS[0]
      parseE = STRSPLIT( parseS[1], '-E', /EXTRACT, /REGEX )
      startTime = parseE[0]
      endTime = parseE[1]
   ENDIF ELSE message, "Illegal date/time specification '"+parsedot[4] $
                       + "', must be 'yyyymmdd-Shhmmss-Ehhmmss' format."

   sequence = parsedot[5]

   versexpr = 'V[0-9][0-9][A-Z]'
   version = parsedot[6]
   IF STREGEX( version, versexpr ) NE 0 THEN $
      message, "Illegal version field '"+version+"'"
 
   extension = parsedot[7]
   extidx = WHERE( definedExts EQ extension, countexts )
   IF countexts NE 1 THEN message, "Illegal file extension '"+extension+"'"

   components = { level : level, $
                  accumulation : accum, $
                  latency : latency, $
                  subset : subset, $
                  satellite : satellite, $
                  instrument : instrument, $
                  algorithm : algorithm, $
                  yyyymmdd : yyyymmdd, $
                  startTime : startTime, $
                  endTime : endTime, $
                  sequence : sequence, $
                  seq_Type : seqType, $
                  version : version, $
                  extension : extension }

return, components
end
