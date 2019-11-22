;===============================================================================
;+
; Copyright © 2012, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; get_6h_precip.pro -- Morris/SAIC/GPM_GV  May 2012
;
; DESCRIPTION
; -----------
; Reads 0-6h precip accumulation, or 3-6h and 0-3h precip accumulation, from one 
; or a pair of North American Mesoscale Analysis (NAM) model forecast GRIB files.
; Returns the 0-6h precip accumulation field, or NULL if no field can be computed.
;
; Requires IDL Version 8.1 or greater, with built-in GRIB read/write utilities.
;
; PARAMETERS
; ----------
; gribfiles - string array, holding fully qualified path/names of the NAM/NAMANL
;             GRIB files to read.  First file is the soundings data, 2nd file is
;             the 6h precip accumulation forecast from 6 hours prior to the
;             soundings analysis, and 3rd file is the 3h precip forecast from 6
;             hours prior to the soundings analysis.  The 0-3h forecast is only
;             needed when the 6h forecast is from the 06Z or 18Z cycle, which
;             only gives a 3-6h precipitation accumulation forecast.  The 6h
;             forecast from the 00Z and 12Z cycles gives the full 0-6h precip.
; precip_miss - value used in GRIB file for MISSING values of precipitation
; period    - text string indicating the forecast period of the precipitation
;             accumulation in hours, e.g. '0-6'
; verbose   - binary parameter, enables the output of diagnostic information
;             when set
;
; MODULES
; -------
; - get_precip_grid()   - INTERNAL
; - get_6h_precip()     - TOP-LEVEL FUNCTION
;
; NON-SYSTEM ROUTINES CALLED
; --------------------------
; - find_alt_filename()
; - grib_get_record()   (from Mark Piper's IDL GRIB webinar example code)
; - uncomp_file()
;
; HISTORY
; -------
; 05/23/12 - Morris, GPM GV, SAIC
; - Created.
;
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;===============================================================================

FUNCTION get_precip_grid, gribfile_in, acc_period, precip_miss, VERBOSE=verbose

printem = KEYWORD_SET(verbose)

IF (printem) THEN begin
   print, ''
   print, "Getting ", acc_period, "h precip from ", gribfile_in
ENDIF

havefile = find_alt_filename( gribfile_in, gribfile )
if ( havefile ) then begin
;  Get an uncompressed copy of the found file
   cpstatus = uncomp_file( gribfile, file_2do )
   if (cpstatus eq 'OK') then begin
;      parmlist = grib_print_parameternames( file_2do )
;      print, parmlist
      file_id = grib_open( file_2do )
      n_records = grib_count( file_2do )
      if n_records lt 1 then begin
         msg = 'No GRIB messages found in file: '+gribfile
         message, msg, /informational
         return, !null
      endif
     ; Container for handle of each record in the file. Note this array is zero-based.
      h_record = lonarr(n_records)
      i_record = 0
      parameter_index = list()
      parm_indicator = list()
      p1 = list()
      p2 = list()
      stepRange = list()
      
      ; Loop over records in file.
      while (i_record lt n_records) do begin
   
         h = grib_new_from_file(file_id)
         h_record[i_record] = h  ; store handle in array for later
         iter = grib_keys_iterator_new(h, /all)
      
         ; Loop over keys in record, looking for the parameter key. (See also 
         ; note above.)
         while grib_keys_iterator_next(iter) do begin
            key = grib_keys_iterator_get_name(iter)
            CASE key OF
               'parameterName' : parameter_index.add, grib_get(h, key)
               'indicatorOfParameter' : parm_indicator.add, grib_get(h, key)
               'P1' : p1.add, grib_get(h, key)
               'P2' : p2.add, grib_get(h, key)
               'stepRange' : steprange.add, grib_get(h, key)
               ELSE : break
            ENDCASE
         endwhile ; loop over keys in record

         grib_keys_iterator_delete, iter
         ;grib_release, h
         i_record++
      
      endwhile ; loop over records in file
      IF (printem) THEN BEGIN
         print, ''
         print, "parameter_index: " & print, parameter_index
         print, "parm_indicator:" & print, parm_indicator
         print, "p1:" & print, p1
         print, "p2:" & print, p2
         print, "steprange:" & print, steprange & print, ''
      ENDIF

     ; find the records with precip accumulation data
      precip_idx=where(parm_indicator EQ 61, countprecip)
      if countprecip eq 0 then begin
         msg = 'No precip accumulation GRIB messages found in file: '+gribfile
         GOTO, errorExit
      endif

     ; find the records with 0-6h, 0-3h, or 3-6h precip accumulation,
     ;   depending on cycle/projection
      precip6_idx=WHERE(steprange[precip_idx] EQ acc_period, countprecip6)
      if countprecip6 eq 0 then begin
         msg = 'No '+acc_period+'h precip accumulation GRIB messages found in file: '+gribfile
         GOTO, errorExit
      endif
      precip6_msgs = h_record[precip_idx[precip6_idx]]
      precip_miss_long = grib_get(precip6_msgs[0], 'missingValue')
      precip_miss = DOUBLE(precip_miss_long)
     ; get the gridded data itself
      precip6_grid = grib_get_values(precip6_msgs[0])
   endif else begin
      print, "In get_6h_precip():"
      print, cpstatus
      return, !null
   endelse
endif else begin
   print, "In get_6h_precip(), cannot find regular/compressed file " + gribfile
   return, !null
endelse

; -------------------------------------------------------------------

errorExit:

; Release all the handles and close the file.
foreach h, h_record do grib_release, h
grib_close, file_id

; Remove the temporary file copy
command = "rm -v " + file_2do
spawn,command

return, precip6_grid
end

; -------------------------------------------------------------------
; -------------------------------------------------------------------

FUNCTION get_6h_precip, gribfiles, precip_miss, period, VERBOSE=verbose

printem = KEYWORD_SET(verbose)

need3h = 0
have3h = 0
period = 'missing'
file_6h = FILE_BASENAME(gribfiles[1])
IF file_6h EQ 'No6hForecast' THEN BEGIN
   print, "get_6h_precip(): no 6h forecast GRIB file, returning empty-handed."
   return, !null
ENDIF ELSE BEGIN
  ; figure out which cycle we're in to see if 3-h forecast is needed
   parsed = STRSPLIT( file_6h, '_', /extract )
   IF parsed[3] EQ '0600' || parsed[3] EQ '1800' THEN BEGIN
;      IF (printem) THEN print, "Processing 0-3h precip, forecast cycle = "+parsed[3]
      need3h = 1
      file_3h = FILE_BASENAME(gribfiles[2])
      IF file_3h EQ 'No3hForecast' THEN BEGIN
         print, 'Missing 3-h projection file for cycle ', parsed[3]
      ENDIF ELSE have3h = 1
   ENDIF
ENDELSE

; get the necessary precip accumulation grid from the 6-h forecast file
if need3h then begin
   acc_period = '3-6'
   precip0_6 = !null
   precip3_6 = get_precip_grid( gribfiles[1], acc_period, precip_miss, VERBOSE=verbose )
   if precip3_6 NE !null then begin
      period = acc_period
      precip0_6 = precip3_6
      IF (printem) THEN BEGIN
         idx2print=WHERE(precip3_6 LT DOUBLE(precip_miss-0.0001), count2print)
         IF count2print GT 0 THEN print, "Max precip, 3-6h: ", max(precip3_6[idx2print]) $
         ELSE print, "Empty 3-6h precip. grid!"
         print, ''
      ENDIF
   endif else print, "get_6h_precip(): missing the 3-6 h accumulation"
   if have3h then begin
      acc_period = '0-3'
      precip0_3 = get_precip_grid( gribfiles[2], acc_period, precip_miss, VERBOSE=verbose )
      if precip0_3 NE !null then begin
         IF (printem) THEN BEGIN
            idx2print=WHERE(precip0_3 LT DOUBLE(precip_miss-0.0001), count2print)
            IF count2print GT 0 THEN print, "Max precip, 0-3h: ", max(precip0_3[idx2print]) $
            ELSE print, "Empty 0-3h precip. grid!"
            print, ''
         ENDIF
         if precip3_6 NE !null then begin
           ; sum the two 3-h periods where non-missing in common
            period = '0-6'
            misscheck = precip_miss - 0.0001
            idx2sum1 = where( precip0_3 LT misscheck )
            idx2sum2 = where( precip3_6[idx2sum1] LT misscheck )
            precip0_6 = precip3_6
            precip0_6[*,*] = precip_miss
            precip0_6[idx2sum1[idx2sum2]] = precip3_6[idx2sum1[idx2sum2]] + precip0_3[idx2sum1[idx2sum2]]
         endif else begin
            print, "get_6h_precip(): only have the 0-3 h accumulation"
            period = acc_period
            precip0_6 = precip3_6
         endelse
      endif else print, "get_6h_precip(): missing the 0-3 h accumulation"
   endif  ; need3h
endif else begin
   acc_period = '0-6'
   precip0_6 = get_precip_grid( gribfiles[1], acc_period, precip_miss, VERBOSE=verbose )
   if precip0_6 NE !null then period = acc_period $
   else print, "get_6h_precip(): missing the 0-6 h accumulation"
endelse

return, precip0_6
end
