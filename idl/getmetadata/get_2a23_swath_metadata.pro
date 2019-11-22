;+
;-------------------------------------------------------------------------------
;
; Copyright © 2012, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; get_2a23_swath_metadata.pro    Bob Morris, GPM GV (SAIC)    December 2012
;
; DESCRIPTION
; -----------
; Reads data fields from a 2A23 file, extracts statistics on the number of
; "Rain Certain" PR footprints for combinations of underlying surface type
; (Ocean, Land, Coast) and Rain Type (Convective, Stratiform).  Returns a '|'
; delimited string containing these counts preceded by the orbit number, TRMM
; data version number (6 or 7), and the orbit subset ID.  In case of errors in
; data or processing, returns the string "Error".
;
; PARAMETERS
; ----------
; file_2a23           - Full pathname to the 2A-23 data file to be processed.
; verbose             - Optional binary keyword parameter.  If set, then output
;                       detailed diagnostic and status information.
;
; NON_SYSTEM CALLS
; ----------------
; valid_num()   find_alt_filename()   uncomp_file()   read_2a23_ppi()
;
; LIMITATIONS/RESTRICTIONS
; ------------------------
; Relies on having one of the known formats for the 2A23 file name, with the
; product ID (2A23), orbit number, TRMM version (6 or 7), and orbit subset ID
; in known locations in the file name, separated by '.' in most cases.  Sample
; valid filename structures include:
;
;      2A23.080322.58972.6.HDF.Z                  (version 6, full orbit file)
;      2A23.20120102.80487.7.HDF.Z                (version 7, full orbit file)
;      2A23.060831.50101.6.sub-GPMGV1.hdf.gz      (version 6, sub-GPMGV1 subset)
;      2A23.20100824.72763.7.sub-GPMGV1.hdf.gz    (version 7, sub-GPMGV1 subset)
;      2A23_GPM_KMA.100828.72833.6.HDF            (version 6, GPM_KMA subset)
;      2A23.20100824.72770.7.GPM_KMA.hdf.gz       (version 7, GPM_KMA subset)
;      2A23_CSI.980220.1334.MELB.6.HDF.Z          (version 6, MELB subset)
;
; etc.  The orbit number is always the 3rd field in the file name.
;
; HISTORY
; -------
; Morris  03-Dec-2012       - Created.
;
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;
;-------------------------------------------------------------------------------
;-


function get_2a23_swath_metadata, file_2a23, VERBOSE=verbose

   ; define COMMON needed to call read_2a23_ppi()
   common sample, start_sample, sample_range, num_range, RAYSPERSCAN
   ; "include" file for PR constants like RAYSPERSCAN
   @pr_params.inc

   verbose = KEYWORD_SET(verbose)
   status=''
   ; extract identifying fields orbit, version, and subset from file name
   base_2a23 = FILE_BASENAME(file_2a23)
   parsed = STRSPLIT( base_2a23, '.', /EXTRACT)
   orbit = parsed[2]
   ; figure out whether TRMM version precedes or follows the subset ID
   temp1 = parsed[3]
   temp2 = parsed[4]
   IF valid_num(temp1) THEN BEGIN
      version = temp1
      subset = temp2
   ENDIF ELSE BEGIN
      version = temp2
      subset = temp1
   ENDELSE
   ; handle situation where subset is instead combined with the product type,
   ; as in the filename: 2A23_GPM_KMA.100828.72833.6.HDF
   IF subset EQ 'HDF' THEN BEGIN
      temp1 = parsed[0]
      IF temp1 EQ '2A23' THEN subset='FullOrbit' $
      ELSE BEGIN
         subset = STRMID( temp1, STRPOS( temp1, '_')+1 )
      ENDELSE
   ENDIF

   ; Check status of file_2a23 before proceeding -  actual file
   ; name on disk may differ if file has been uncompressed already.
   readstatus = 0

   havefile = find_alt_filename( file_2a23, found2a23 )
   if ( havefile ) then begin
      ; Get an uncompressed copy of the found file
      cpstatus = uncomp_file( found2a23, file23_2do )
      if(cpstatus eq 'OK') then begin
         SAMPLE_RANGE=0
         START_SAMPLE=0
         num_range = NUM_RANGE_2A25
         geolocation=fltarr(2,RAYSPERSCAN,sample_range>1)
         rainType=intarr(sample_range>1,RAYSPERSCAN)
         rainFlag=bytarr(sample_range>1,RAYSPERSCAN)
         statusFlag=bytarr(sample_range>1,RAYSPERSCAN)
         BBheight=intarr(sample_range>1,RAYSPERSCAN)
         BBstatus=bytarr(sample_range>1,RAYSPERSCAN)

         status = read_2a23_ppi( file23_2do, GEOL=geolocation, $
                                 RAINTYPE=rainType, RAINFLAG=rainFlag, $
                                 STATUSFLAG=statusFlag, BBHEIGHT=BBheight, $
                                 BBSTATUS=BBstatus, VERBOSE=verbose )

         IF status NE 'OK' THEN readstatus = 1
         ; Delete the temporary file copy
         IF VERBOSE THEN BEGIN
            print, "Remove 2A23 file copy:"
            command = 'rm -fv ' + file23_2do
         ENDIF ELSE command = 'rm -f ' + file23_2do
         spawn, command
      endif else begin
         print, cpstatus
         readstatus = 1
      endelse
   endif else begin
      print, "Cannot find regular/compressed file " + file_2a23
      readstatus = 1
   endelse
   IF VERBOSE THEN BEGIN
      help
      print, status, readstatus
   ENDIF

   IF readstatus EQ 1 THEN BEGIN
      print, ''
      print, "In get_2a23_swath_metadata(), error reading 2A23 data from file:"
      print, file_2a23
      print, "Exiting." & print, ''
      return, 'Error'
   ENDIF ELSE BEGIN
      ; process metadata fields.  RainType first.

      ; --- Information on the types of rain storm.
      ;     Note that positive rain type values are 3-digit, negative are 2-digit.
      ;     Reduce all to a 1-digit category
      RainTypeStratiform =  1   ; (Stratiform)
      RainTypeConvective =  2   ; (Convective)
      RainTypeOther =  3   ; (Others)
      RainTypeStr = ['','Stratiform','Convective','Other']
      ; RainType = -7   (Gridpoint not coincident with PR - not a 2A23 value)
      ; RainType = -8   (No rain)
      ; RainType = -9   (Missing data)
      ; ---

      raintype = raintype/10
      idx123 = WHERE( rainType gt 0, count123 )
      if ( count123 eq 0 ) then begin
         print, "No non-missing rain type values found!"
      endif else begin
         rainType[idx123] = rainType[idx123]/10
         ; Generate RainType histogram.  Convert negative values to their ABS for histogramming
         histo = HISTOGRAM( ABS(rainType), MIN=0, MAX=9 )
         idxhist = [1,2,3,8,9,7]  ; must have exactly "nummeta" values
         histoRainType = histo[idxhist]
         ; set last array value to the total # of footprints
         ; (i.e., exclude those with the undefined value = -7)
         histoRainType[5] = TOTAL(histoRainType[0:4], /INTEGER)
         IF VERBOSE THEN BEGIN
            print, "      Stratiform  Convective    Other      No rain      Missing    Total"
            print, histoRainType
         ENDIF
      endelse

      ; now rain flag (= rain certain), by surface type
      ; units digit of status flag is surface type (0=ocean, 1=land, 2=coast, 4=lakes, 9=unknown)
      ; negative BYTE values of statusFlag (-88[no rain], -99[missing]) wrap to 168b and 157b

      ; 2A23 Rain Flag indicators:
      NO_RAIN = 0b
      RAIN_POSSIBLE = [10b,11b,12b,13b]
      RAIN_PROBABLE = 15b
      RAIN_CERTAIN = 20b

      surface = statusFlag-((statusFlag/10b)*10b)
      idxlakes = WHERE(surface EQ 4, nlake)        ; find overland lake surfaces
      if (nlake GT 0) then surface[idxlakes]=1     ; reassign lakes to land
      goodStatus = statusFlag LT 50b

      ; define array to hold "count of" statistics
      countRntypeBySfc = LONARR(5,2)
      for itype = RainTypeStratiform, RainTypeConvective do begin
         IF VERBOSE THEN print, RainTypeStr[itype], ' Statistics:'
         rainBySfcIdx = WHERE( (rainFlag EQ RAIN_CERTAIN) AND (surface EQ 0) $
                               AND goodStatus AND rainType EQ itype, NrainOcean )
         countRntypeBySfc[0,itype-1] = NrainOcean
         IF VERBOSE THEN print, "Rainy footprints over ocean: ", NrainOcean
         rainBySfcIdx = WHERE( (rainFlag EQ RAIN_CERTAIN) AND (surface EQ 1 OR surface EQ 4) $
                               AND goodStatus AND rainType EQ itype, NrainLand )
         countRntypeBySfc[1,itype-1] = NrainLand
         IF VERBOSE THEN print, "Rainy footprints over land: ", NrainLand
         rainBySfcIdx = WHERE( (rainFlag EQ RAIN_CERTAIN) AND (surface EQ 2) $
                               AND goodStatus AND rainType EQ itype, NrainCoast )
         countRntypeBySfc[2,itype-1] = NrainCoast
         IF VERBOSE THEN print, "Rainy footprints over Coast: ", NrainCoast
         rainBySfcIdx = WHERE( (rainFlag EQ RAIN_CERTAIN) AND (surface EQ 9) $
                               AND goodStatus AND rainType EQ itype, NrainUnknownSfc )
         countRntypeBySfc[3,itype-1] = NrainUnknownSfc
         IF VERBOSE THEN print, "Rainy footprints over Unknown Surface: ", NrainUnknownSfc
         rainBySfcIdx = WHERE( rainFlag EQ RAIN_CERTAIN AND rainType EQ itype, NrainTotal )
         countRntypeBySfc[4,itype-1] = NrainTotal
         IF VERBOSE THEN print, "No. Rain Certain footprints: ", NrainTotal
         rainBySfcIdx = 0
      endfor

   ENDELSE    ; readstatus EQ 1

   line4db = STRING(orbit, version, subset, countRntypeBySfc[0:8], $
             countRntypeBySfc[9], format='(3(A0,"|"),9(I0,"|"),I0)' )

   IF VERBOSE THEN print, "line4db = ", line4db

   return, line4db

end
