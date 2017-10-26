;===============================================================================
;+
; Copyright © 2010, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; local_maxima.pro    Morris/SAIC/GPM_GV    Aug. 2010
;
; DESCRIPTION
; -----------
; Takes a vector (one dimensional array) of data values and identifies locations
; of local maxima in the data.  Returns array indices of such maxima, or -1 if
; none are found.  Considers the endpoints of the vector in evaluating the
; locations of maxima.
;
; PARAMETERS
; ----------
; datavec    - vector of points whose local maxima are to be identified (Input)
; nmaxes     - number of relative maxima found in datavec (I/O; optional)
; idxabsmax  - index of the largest (peak) maximum (I/O; optional)
;
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;===============================================================================

FUNCTION local_maxima, datavec, COUNT=nmaxes, IDXABSMAX=idxabsmax

vecsiz = SIZE(datavec)

IF vecsiz[0] NE 1 THEN BEGIN
   nmaxes = 0
   print, "In MYLCLXTREM: vector expected, input data has ", vecsiz[0], " dimensions."
   return, -1
ENDIF

nmaxes = 0
npts = vecsiz[1]
maxlocs = intarr(npts)  ; array to tally locations of relative maxes

CASE npts OF
   2 : BEGIN
        ; find the maximum value -- MAX gives first instance of it, if repeated
         vecmax = MAX(datavec, idxmax, SUBSCRIPT_MIN=idxmin)
        ; check whether any other points have a lesser value before calling it a max
         IF idxmax NE idxmin THEN maxlocs[idxmax] = 1
       END
   3 : BEGIN
         vecmax = MAX(datavec, idxmax, SUBSCRIPT_MIN=idxmin)
        ; check whether any other points have a lesser value before calling it a max
         IF idxmax NE idxmin THEN maxlocs[idxmax] = 1
        ; if the middle point is the min, see whether the remaining point
        ; is also a relative maximum
         IF idxmin EQ 1 THEN BEGIN
            IF idxmax EQ 0 THEN idxother = 2 ELSE idxother = 0
            IF datavec[idxother] GT datavec[idxmin] THEN maxlocs[idxother] = 1
         ENDIF
       END
   ELSE : BEGIN
         vecmax = MAX(datavec, idxmax, SUBSCRIPT_MIN=idxmin)
        ; check whether any other points have a lesser value before calling it a max
         IF idxmax NE idxmin THEN maxlocs[idxmax] = 1
        ; test the first and last points for maxness
         IF datavec[0] GT datavec[1] THEN BEGIN
            nmaxes = nmaxes + 1
            maxlocs[0] = 1
;            print, "first point is max"
         ENDIF ELSE BEGIN
            IF datavec[0] EQ datavec[1] THEN BEGIN
              ; walk along the flat area until something changes
               FOR j = 2, npts-1 DO BEGIN
                  IF datavec[0] GT datavec[j] THEN BEGIN
                     nmaxes = nmaxes + 1
                     maxlocs[0] = 1
;                     print, "first point is max"
                     BREAK
                  ENDIF ELSE IF datavec[0] LT datavec[j] THEN BREAK  ; curve rises, no max
               ENDFOR
            ENDIF
         ENDELSE
         IF datavec[npts-1] GT datavec[npts-2] THEN BEGIN
            nmaxes = nmaxes + 1
            maxlocs[npts-1] = 1
;            print, "last point is max"
         ENDIF ELSE BEGIN
            IF datavec[npts-1] EQ datavec[npts-2] THEN BEGIN
              ; walk along the flat area until something changes
               FOR j = npts-2, 2, -1 DO BEGIN
                  IF datavec[j] GT datavec[j-1] THEN BEGIN
                     nmaxes = nmaxes + 1
                     maxlocs[j] = 1
;                     print, "start of trailing flat points is max"
                     BREAK
                  ENDIF ELSE IF datavec[j] LT datavec[j-1] THEN BREAK  ; curve rises, no max
               ENDFOR
            ENDIF
         ENDELSE

        ; test the middle points for maxness
        ; - first, compute the slope of the datavec point series, normalized to
        ;   -1, 0, or 1 (down, flat, or up)
         slope = INTARR(npts-1)
         FOR i = 0, npts - 2 DO BEGIN
           IF datavec[i] EQ datavec[i+1] THEN slope[i] = 0 $
           ELSE slope[i] = FIX( (datavec[i+1]-datavec[i])/ABS(datavec[i+1]-datavec[i]) )
         ENDFOR
        ; squeeze out any "flat" sections
         idxunflat = WHERE( slope NE 0, countunflat )
         IF countunflat GT 1 THEN BEGIN 
           ; compute the 2nd derivative of the non-flat datavec series
            slope2 = slope[idxunflat[1:(countunflat-1)]] - $
                     slope[idxunflat[0:(countunflat-2)]]
           ; get the indices of any maxima in the 2nd derivative sections
            idxmaxby2nd = WHERE( slope2 EQ -2, countmaxby2nd )
            IF countmaxby2nd GT 0 THEN BEGIN
              ; figure out where these maxima lie, relative to slope array,
              ; then to datavec
               idx4slope = idxunflat[idxmaxby2nd]
               idx4datavec = idx4slope+1
               maxlocs[idx4datavec] = 1
            ENDIF
         ENDIF
      END
ENDCASE

idxmaxes = WHERE( maxlocs EQ 1, nmaxlocs)
;print, "input array: ", datavec
;print, "position(s) of maxima: ", idxmaxes
;print, "nmaxlocs = ", nmaxlocs, " values: ", datavec[idxmaxes]

IF ( N_ELEMENTS(nmaxes) EQ 1 ) THEN nmaxes = nmaxlocs

IF ( N_ELEMENTS(idxabsmax) EQ 1 AND nmaxlocs GT 0 ) THEN BEGIN
;   print, "getting absolute max", "  maxlocs = ", maxlocs
   absvecmax = MAX(datavec[idxmaxes], idxmax)
   idxabsmax = idxmaxes[idxmax]
;   print, "absolute max idx: ", idxabsmax, " value: ", datavec[idxabsmax]
ENDIF

return, idxmaxes

end
