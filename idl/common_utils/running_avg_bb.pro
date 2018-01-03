;===============================================================================
;+
; Copyright © 2013, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; running_avg_bb.pro          Morris/SAIC/GPM_GV      January 2013
;
; DESCRIPTION
; -----------
; Computes a running average of PR bright band height along the orbit path.
; Data are first averaged across the scan, then a running average is computed
; for a group of adjacent scans whose number is defined by the SPAN parameter.
; If the 2A-23 BBSTATUS field is provided, then the "best" BB values are
; included in the running average, otherwise all non-missing BB values are
; included.
;
; MODULES
; -------
; 1) running_avg_bb  - Parent function called by the user, specifically for the
;                      purpose of computing running average of bright band height.
; 2) running_avg     - Child function called by running_avg_bb to do the work of
;                      computing the running averages from either a 1-D or 2-D
;                      input array.  If 2-D, it can compute the running average
;                      along either the 1st or 2nd dimension, as controlled by
;                      the internal parameter 'run_dimension'.
;
; HISTORY
; -------
; 1/30/2013 by Bob Morris, GPM GV (SAIC)
;  - Created.
; 2/1/2013 by Bob Morris, GPM GV (SAIC)
;  - Fixed bug in running_avg logic comparing SPAN to run_dimension size.
; 3/4/2015 by Bob Morris, GPM GV (SAIC)
;  - Added logic to detect and use GPM qualityBB field in place of TRMM 2A-23
;    BBstatus.
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;===============================================================================

; MODULE 2 of 2: FUNCTION running_avg
;
; DESCRIPTION
; -----------
; Computes a running average of data values along a specified dimension (if 2-D
; array) or along a vector.  If 2-D, then data are first averaged across the
; dimension orthogonal to the "run" dimension to get a vector of values. Then
; an identically sized vector of running average values is computed element by
; element for each position in the vector by averaging N adjacent values
; centered on the position, where N is defined by the SPAN parameter.
;
; If the INDICES parameter is specified, then only those array positions in the
; input data array whose positions are defined by idx2do are included in the
; computation of the running average.  Depending on the values of 'idx2do' and
; 'span', there may be positions in the running average vector that have no
; qualifying data samples to compute the running average.  Values within the
; running average vector for these positions are set to -99.0.
;
; If the input data array is 2-D, then the running average values can be
; returned either as a simple vector (1-D array along the run_dimension), or
; an array of the same size and dimensions (i.e., 2) as the input array.
; This behavior is controlled by the DIMS_BACK keyword parameter, which
; specifies the number of dimensions of the running average array returned
; from the function.  If a 2-D array is to be returned, then the values of
; the running average vector are duplicated in the orthogonal dimension
; (the dimension opposite the run_dimension).
;
; PARAMETERS
; ----------
; in_arr        - Array of data values whose running average along a
;                 specified dimension will be computed.
;
; run_dimension - Array dimension along which the running average will
;                 be computed and returned.
;
; span          - Optional keyword parameter to specify the number of
;                 sequential points to be included in the computation
;                 of a running average value.
;
; idx2do        - Optional keyword parameter, vector of array indices
;                 into the in_arr array limiting the input data values
;                 included in the computation of the running average.
;
; bbdims        - Number of dimensions for the returned array holding
;                 the running average.  If not specified, then defaults
;                 to the same number of dimension as in_arr.
;
; max_gap       - The greatest distance along run_dimension of consecutive
;                 points with no data available for computing the running
;                 average.  Only makes sense if 'idx2do' is specified.
;
; verbose       - Optional binary keyword parameter to toggle the
;                 printing of diagnostic messages.


FUNCTION running_avg, in_arr, run_dimension, SPAN=span, INDICES=idx2do, $
                      DIMS_BACK=bbdims, MAX_GAP=max_gap, VERBOSE=verbose

   verbose = KEYWORD_SET(verbose)
   size_in = SIZE(in_arr)

   ; we only handle 1-D or 2-D data arrays at this time
   IF (run_dimension GT 1) OR (size_in[0] GT 2) THEN $
      message, "Too many input dimensions, limit is 2."

   ; check self-consistency of inputs
   IF N_ELEMENTS(bbdims) NE 0 THEN BEGIN
      IF bbdims GT size_in[0] THEN BEGIN
         message, "More dimensions requested than are available!", /INFO
         message, "Returning same size array as input, by default.", /INFO
         bbdims = size_in[0]
      ENDIF
   ENDIF ELSE BEGIN
      message, "Returning same size array as input, by default.", /INFO
      bbdims = size_in[0]
   ENDELSE
   IF (run_dimension+1) GT size_in[0] THEN $
      message, "Run dimension greater than available dimensions!"
   IF size_in[run_dimension+1] LT 2 THEN message, "Run dimension size < 2, can't average."
   IF N_ELEMENTS(span) EQ 1 THEN BEGIN
      IF span GE size_in[run_dimension+1] THEN BEGIN
         text = "Setting excessive span value: "+STRTRIM(STRING(span),2) $
                +" to run dimension size: "+STRTRIM(STRING(size_in[run_dimension]),2)
         message, text, /INFO
         span = size_in[run_dimension+1]
     ENDIF
   ENDIF ELSE BEGIN
      span = 25 < size_in[run_dimension+1]
      text = "Setting default value for span: "+STRTRIM(STRING(span),2)
      message, text, /INFO
   ENDELSE

   n_along = size_in[run_dimension+1]    ; no. points in run dimension
   IF (size_in[0] GT 1) THEN n_across = size_in[size_in[0]-run_dimension] $
      ELSE n_across = 1
   cross_avg = FLTARR(n_along)
   avg_along = cross_avg

   IF N_ELEMENTS(idx2do) EQ 0 THEN BEGIN
      ; average all elements of in_arr, no subset of indices provided

      IF N_ELEMENTS(max_gap) NE 0 THEN max_gap=0   ; i.e., does not apply in this situation
      ; average all elements along orthogonal to run_dimension, if 2-D
      IF (size_in[0] GT 1) THEN BEGIN
         FOR i_along = 0, n_along-1 DO BEGIN
            CASE run_dimension OF
                 0 : cross_avg[i_along] = MEAN(in_arr[i_along,*] )
                 1 : cross_avg[i_along] = MEAN(in_arr[*,i_along] )
              ELSE : message, "Illegal value for run_dimension. Huh?"
            ENDCASE
         ENDFOR
      ENDIF ELSE cross_avg = in_arr       ; or just take the array, if 1-D

      ; compute the 1-D running averages from the cross-scan averages
      FOR i_along = 0, n_along-1 DO BEGIN
          ; compute average of 'span' sequential values, centered on current index
          ; -- averages are one-sided and offset at beginning/end of sequence
          IF i_along LT (span/2) THEN BEGIN
             idxstart = (i_along-(span/2)) > 0
             idxend = (idxstart+span-1) < (n_along-1)
          ENDIF ELSE BEGIN
             idxend = (i_along+(span/2)) < (n_along-1)
             idxstart = (idxend-span+1) > 0
          ENDELSE
          if verbose then print, 'i_along, idxstart, idxend, N: ', $
                                 i_along, idxstart, idxend, idxend-idxstart+1
          avg_along[i_along] = MEAN(cross_avg[idxstart:idxend])
      ENDFOR

   ENDIF ELSE BEGIN    ; ELSE for N_ELEMENTS(idx2do) EQ 0
      ; average only those elements whose indices are specified

      ; First, find out which of the run_dimension indices have elements to average
      flag_arr = LONG(in_arr)  ; tracks the above indices, mainly for 2D case
      CASE size_in[0] OF
           1 : BEGIN
                 ; trivial case, use values at 'idx2do'
                 flag_arr[*] = 0L
                 flag_arr[idx2do] = 1L
                 idx_along = idx2do
                 cross_avg = in_arr[idx2do]
               END
           2 : BEGIN
                 flag_arr[*,*] = 0L
                 ; set the flag_arr values along the averaging direction to the
                 ; array index along the run_direction
                 CASE run_dimension OF
                      0 : FOR i_along = 0L, n_along-1 DO flag_arr[i_along,*]=i_along
                      1 : FOR i_along = 0L, n_along-1 DO flag_arr[*,i_along]=i_along
                   ELSE : message, "Illegal value for run_dimension. Huh?"
                 ENDCASE
                 ; get the unique values of run_direction index that have been
                 ; flagged by 'idx2do' as data to be used; i.e., which scans have
                 ; one or more flagged values
                 sortUniq = flag_arr[idx2do]
                 idx_along = sortUniq[ UNIQ( sortUniq, SORT(sortUniq) ) ]
                 ; unfortunately, we don't know which 'BBstatus' level we're getting
                 flag_arr[*,*] = 0L      ; reset for other use
                 flag_arr[idx2do] = 1L   ; tag locations to be used for mean BB
                 ; step through the "scans" with BB data, and average

                 for iscan2do = 0L, N_ELEMENTS(idx_along)-1 do begin
                    CASE run_dimension OF
                         0 : BEGIN
                               idx2avg=WHERE(flag_arr[idx_along[iscan2do],*] EQ 1, count2avg)
                               temparr = in_arr[idx_along[iscan2do],*]
                               cross_avg[idx_along[iscan2do]] = MEAN(temparr[idx2avg])
                               if verbose then print, 'idx_along, meanBB, nsamples: ', $
                                  idx_along[iscan2do], MEAN(temparr[idx2avg]), count2avg
                             END
                         1 : BEGIN
                               idx2avg=WHERE(flag_arr[*,idx_along[iscan2do]] EQ 1, count2avg)
                               temparr = in_arr[*,idx_along[iscan2do]]
                               cross_avg[idx_along[iscan2do]] = MEAN(temparr[idx2avg])
                               if verbose then print, 'idx_along, meanBB, nsamples: ', $
                                  idx_along[iscan2do], MEAN(temparr[idx2avg]), count2avg
                             END
                      ELSE : message, "Illegal value for run_dimension. Huh?"
                    ENDCASE
                 endfor
               END   ; size_in[0] is 2-D
        ELSE : message, "Illegal value for input array dimension. Huh?"
      ENDCASE        ; size_in[0] cases of 1-D and 2-D

      ; compute the 1-D running averages from the cross-scan averages
      FOR i_along = 0, n_along-1 DO BEGIN
          ; compute average of 'span' sequential values, centered on current index
          ; -- averages are one-sided and offset at beginning/end of sequence
          ; -- depending on the array indices of the elements we were limited to,
          ;    there may not be any values to "running average".
          ; -- First, find the range of sequential values we'd like to run-average:
          IF i_along LT (span/2) THEN BEGIN
             idxstart = (i_along-(span/2)) > 0
             idxend = (idxstart+span-1) < (n_along-1)
          ENDIF ELSE BEGIN
             idxend = (i_along+(span/2)) < (n_along-1)
             idxstart = (idxend-span+1) > 0
          ENDELSE
;          if verbose then print, 'i_along, idxstart, idxend, N: ', i_along, $
;                                 idxstart, idxend, idxend-idxstart+1
          ; Next, find out if any of our cross-averages are within this range of scans
          idx_run = WHERE( idx_along GE idxstart AND idx_along LE idxend, countrun )
          IF countrun GT 0 THEN $
             avg_along[i_along] = MEAN(cross_avg[idx_along[idx_run]]) $
          ELSE avg_along[i_along] = -99.0
          if verbose then print, 'i_along, avg_along, count: ', $
                                 i_along, avg_along[i_along], countrun
      ENDFOR
   ENDELSE           ; ENDELSE for where N_ELEMENTS(idx2do) NE 0

   ; assign the running average values to the 1- or 2-D array to be returned
   CASE bbdims OF
        1 : data = avg_along
        2 : BEGIN
               data = FLOAT(in_arr)
               data[*,*] = 0.0
               CASE run_dimension OF
                    0 : FOR i_along = 0L, n_along-1L DO data[i_along,*]=avg_along[i_along]
                    1 : FOR i_along = 0L, n_along-1L DO data[*,i_along]=avg_along[i_along]
                 ELSE : message, "Illegal value for run_dimension. Huh?"
               ENDCASE
            END
     ELSE : message, "Can't figure out dimensions of returned array."
   ENDCASE

   return, data
end

;===============================================================================

; MODULE 1 of 2:  FUNCTION running_avg_bb
;
; DESCRIPTION
; -----------
; Computes a running average of PR bright band height along the orbit path.
; Data are first averaged across the scan, then a running average is computed
; for a group of adjacent scans whose number is defined by the SPAN parameter.
; If the 2A-23 BBSTATUS field is provided, then the "best" BB values are
; included in the running average, otherwise all non-missing BB values are
; included.
;
; PARAMETERS
; ----------
; BBheight - Array of bright band heights from the PR 2A-23 product
; BBstatus - Array of bright band status values from the PR 2A-23 product
;            or an array of qualityBB values from the 2A-DPR, 2A-Ka, or 2A-Ku.
; max_gap  - Optional keyword parameter.  Returns the largest gap between
;            valid bright band values along the running average dimension.


FUNCTION running_avg_bb, BBheight, bbstatus, MAX_GAP=max_gap, VERBOSE=verbose

   verbose = KEYWORD_SET(verbose)
   szBBh = SIZE(BBheight)
   bbdims = szBBh[0]
   IF bbdims NE 2 THEN message, "Can only handle 2-D BBheight array."
   run_dimension = 0

   IF N_PARAMS() EQ 2 THEN BEGIN
      szBBs = SIZE(BBstatus)
      bbdims = szBBs[0]
      IF bbdims NE 2 THEN message, "Can only handle 2-D BBstatus/qualityBB array."
      IF MAX(BBstatus) GT 3 THEN BEGIN
        ; we have the TRMM PR BBstatus field
         idxbbgood = WHERE( BBstatus/16 EQ 3, countbbgood )
         if (countbbgood EQ 0 ) then begin
            message, /INFORMATIONAL, "No points with BB detection status 'good' (=3)"
           ; try the "fair" BB detection points
            idxbbgood = WHERE( BBstatus/16 EQ 2, countbbgood )
            if (countbbgood EQ 0 ) then begin
               message, /INFORMATIONAL, "No points with BB detection status 'fair' (=2), fall back to any/all"
               idxbbgood = WHERE( BBheight GE 0, countbbgood )
               IF countbbgood EQ 0 THEN BEGIN
                  message, /INFORMATIONAL, "No valid BB height values!"
               ENDIF else if verbose then print, "Using BBstatus ANY, samples = ", countbbgood
            endif else if verbose then print, "Using BBstatus FAIR, samples = ", countbbgood
         endif else if verbose then print, "Using BBstatus GOOD, samples = ", countbbgood
      ENDIF ELSE BEGIN
        ; we have the GPM DPR qualityBB field
         run_dimension = 1
         idxbbgood = WHERE( BBstatus EQ 1, countbbgood )
         if (countbbgood EQ 0 ) then begin
            message, /INFORMATIONAL, "No points with BB detection status 'good' (=1), fall back to any/all"
            idxbbgood = WHERE( BBheight GE 0, countbbgood )
            IF countbbgood EQ 0 THEN BEGIN
               message, /INFORMATIONAL, "No valid BB height values!"
            ENDIF else if verbose then print, "Using qualityBB ANY, samples = ", countbbgood
         endif else if verbose then print, "Using qualityBB GOOD, samples = ", countbbgood
      ENDELSE
   ENDIF ELSE BEGIN
      message, /INFORMATIONAL, "BBstatus not provided, using any valid BBheight values."
      idxbbgood = WHERE( BBheight GE 0, countbbgood )
   ENDELSE

   IF countbbgood GT 0 THEN BEGIN
      running_mean = running_avg( BBheight, run_dimension, INDICES=idxbbgood, $
                                  SPAN=25, DIMS_BACK=bbdims, MAX_GAP=max_gap, $
                                  VERBOSE=verbose )
   ENDIF ELSE BEGIN
      message, /INFORMATIONAL, "No valid BB height values!"
      running_mean = -1
   ENDELSE

   return, running_mean

end
