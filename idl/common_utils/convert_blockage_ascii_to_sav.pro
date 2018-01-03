;===============================================================================
;+
; Copyright © 2015, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; convert_blockage_ascii_to_sav.pro    Morris/SAIC/GPM_GV    Oct 2015
;
; DESCRIPTION
; -----------
; Reads an ascii file of radar beam blockage for a given radar site and
; elevation angle, and builds arrays of ray azimuths, gate ranges, and
; fractional beam blockage for each radial and range gate.  Saves the
; resulting data arrays and site ID and elevation angle variables to an IDL
; binary "SAVE" file whose pathname is given as the file_sav parameter.
; Optionally, returns the same data variables in a structure overwriting the
; input "data_struct" keyword value if DATA_STRUCT is set to a valid variable
; (a throwaway variable of any type) by the calling routine.
;
; The format of the ASCII data file is a header line followed by N records of
; space-delimited blockage values.  Each record contains blockage values for
; all 360 azimuth angles ( 0.0 to 359.0, at 1-deg steps) for a fixed range.
; Each subsequent record is for increasing range from the radar (gate number),
; from 1 to 460 km at 1 km increments.  A blockage value of 0 indicates no
; beam blockage.  A value of 1 indicates a range gate where the beam blocking
; object is present in the radar beam.  Fractional values indicate the amount
; of beam blockage at that range gate, where 0 < value < 1.
;
; HISTORY
; -------
; 10/2015 by Bob Morris, GPM GV (SAIC)
;  - Created.
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;===============================================================================


pro convert_blockage_ascii_to_sav, file_asc, file_sav, $
                                   DATA_STRUCT=data_struct, REPORT=report

IF FILE_TEST(file_asc, /READ, /REGULAR) NE 1 THEN $
   message, "File "+file_asc+" not found or is not readable."

OPENR, lun, file_asc, /get_lun, ERROR = err

IF (err NE 0) THEN BEGIN
   PRINTF, -2, !ERROR_STATE.MSG
   GOTO, errorExit
ENDIF

; parse the file name to get the elevation angle
elev = FLOAT(STRMID(FILE_BASENAME(file_asc), 18, 5))

; parse the first line of the file to get the dimension data
metaline = ''
READF, lun, metaline
parsed = STRSPLIT(metaline, ' ', /EXTRACT)
site = parsed[0]
latitude = FLOAT(parsed[1])   ; not used
longitude = FLOAT(parsed[2])  ; not used
height = FLOAT(parsed[3])     ; not used
dAz = FIX(parsed[4])          ; not used
nAz = FIX(parsed[5])          ; assumed to be 360 (azimuths)
begAz = FIX(parsed[6])        ; not used
dRng = FIX(parsed[7])         ; not used
nRng = FIX(parsed[8])         ; assumed to be 460 (range gates per radial)
begRng = FIX(parsed[9])       ; not used
RngStep_m = FIX(parsed[10])   ; not used

; define the azimuth values in the records, same for all records, 0-359.
azimuths = FINDGEN(nAz)

; define the ranges, each record is at the next range step from the radar
ranges = INDGEN(nRng) + 1   ; i.e., 1-460

; dimension the full array of polar coordinate blockage values
blockage = FLTARR(nRng,nAz)

; dimension the array of azimuthal blockage values in each file record,
; defines how the read values will be converted/formatted (460 FLOATs)
blockageRec = FLTARR(nAz)

nread = 0
; read the remaining records in the file, and fill blockage array
WHILE NOT (EOF(lun)) DO BEGIN 
   READF, lun, blockageRec
   IF (nread LT nRng) THEN BEGIN
      blockage[nread,*] = blockageRec
   ENDIF ELSE BEGIN
      FREE_LUN, lun
      message, "Too many records in file: "+file_asc
   ENDELSE
   nread++
ENDWHILE
FREE_LUN, lun

IF (nread NE nRng) THEN BEGIN
   help, nread, nRng
   message, "Too few records read from file: "+file_asc
ENDIF

; cut the blockage file down to just 230 km worth of data
blockage_out = blockage[0:229,*]
ranges_out = ranges[0:229]

IF N_PARAMS() EQ 2 THEN SAVE, site, elev, azimuths, ranges_out, blockage_out, $
                              FILE=file_sav

IF N_ELEMENTS(data_struct) NE 0 THEN $
   data_struct = { site : site, $
                   elev : elev, $
                   azimuths : azimuths, $
                   ranges : ranges_out, $
                   blockage : blockage_out }

IF KEYWORD_SET(report) THEN BEGIN
   idxblock = WHERE(blockage_out GT 0.0 AND blockage_out LT 1.0, countblock)
   print, '' & print, "Number of blockage gates: ", countblock
   command = 'ls -al ' + file_sav
   spawn, command
ENDIF

errorExit:
end

