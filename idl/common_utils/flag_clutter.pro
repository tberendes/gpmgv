;+
; Copyright © 2015, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
;  flag_clutter.pro   Morris/SAIC/GPM_GV      June 2015
;
;  SYNOPSIS:
;  flag_clutter, scanNumpr, raynumpr, gvprofileIn, flagCltr, clutterFreeBin, $
;                VERBOSE=verbose
;
;  DESCRIPTION:
;  Takes arrays of DPR 3-D reflectivity, DPR clutter flag, and lowest
;  clutter-free bin, and for a specified set of DPR rays and scans, identifies
;  and flags DPR range gates along those rays and above the lowest clutter-free
;  bin that appear to be clutter affected.  Overwrites the existing value for
;  these range gates to the value 80 in the DPR clutter flag array, flagCltr.
;
; HISTORY
; -------
; 06/10/15  Morris/GPM GV/SAIC
; - Created.
;
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-

pro flag_clutter, scanNumpr, raynumpr, gvprofileIn, flagCltr, clutterFreeBin, $
                  VERBOSE=verbose_in

verbose=KEYWORD_SET(verbose_in)

s=SIZE(flagCltr,/DIMENSIONS)
nbins = s[0]
nfooties = N_ELEMENTS(scanNumpr)

for ifoot = 0, nfooties-1 DO BEGIN
  ; grab our ray's data for the specified ray,scan from the Z profile
  ; and clutterFreeBin arrays.  DPR order is bin,ray,scan
   startbin = clutterFreeBin[rayNumpr[ifoot], scanNumpr[ifoot]]

  ; check for NO DATA situation
   IF startbin EQ -9999 THEN BEGIN
      IF (verbose) THEN message, "Missing data for ray, scan = " $
                                 +STRING(rayNumpr[ifoot], FORMAT='(I0)') +',' $
                                 +STRING(scanNumpr[ifoot], FORMAT='(I0)')
      CONTINUE   ; skip this ray leaving its flagClutr values as-is
   ENDIF

   gvzprofiles = REFORM( gvprofileIn[*, rayNumpr[ifoot], scanNumpr[ifoot]] )

   haveplot=0
   IF verbose GT 0 THEN $
      print, "===================== RAY ", STRING(ifoot+1, FORMAT='(I0)'), " ====================="

; "blank" out the clutter bins, if information provided
  gvzprofiles[ (startbin+1)<(nbins-1) : nbins-1 ] = 9.0

  ; grab the individual profile at the footprint above the lowest clutter-free bin.
;;;   lastgoodbinidx=startbin-1
   lastgoodbinidx=startbin+2 < nbins-1  ; look below the clutter-free limit
   gvprofile_abv=REFORM(gvzprofiles[0:lastgoodbinidx])

  ; do we have any actual reflectivity values in this profile?  If so, grab just
  ; these samples for evaluation
   idxactual = WHERE(gvprofile_abv GT 0.0, countactual)
   IF (countactual EQ 0) THEN BEGIN
      IF verbose GT 0 THEN message, "No non-zero gvz values in ray, skipping.", /INFO
      gvprofile = [0.,0.,0.]
      ;CONTINUE   ; leave profile as No Rain, skip to next ray
   ENDIF ELSE BEGIN
     ; set negative/small values to 9.0 to flatten out the profile there
      idxneg = WHERE(gvprofile_abv LT 9.0, countneg)
      IF countneg GT 0 THEN gvprofile_abv[idxneg] = 9.0
     ; round Z values to nearest "gatethresh" dBZ
      GATETHRESH=5
     ; compute the gate-to-gate gradients of the rounded reflectivity profile
      slopes = gvprofile_abv[1:lastgoodbinidx]-gvprofile_abv[0:lastgoodbinidx-1]
      slopes = (FIX(slopes)/gatethresh)*gatethresh
     ; find any gate-to-gate change of gatethresh dBZ (anywhere slopes is not 0)
      idxgatethresh = WHERE( ABS(slopes) NE 0, countbygatethresh )
      IF countbygatethresh GT 0 THEN BEGIN
         ;print, gvprofile_abv
        ; walk through the changes and smooth over these regions
         for igrad = 0, countbygatethresh-1 do begin
           ; special rule if Z drops off at first change
            if igrad EQ 0 and slopes[idxgatethresh[igrad]] LT 0 THEN BEGIN
              ; don't actually do any flagging for this case right now
               IF verbose GT 0 THEN print, "Found leading ",gatethresh," dBZ/gate dropoff: ", $
                  gvprofile_abv[ idxgatethresh[igrad] > 0 : idxgatethresh[igrad]+1 < lastgoodbinidx ]
                  ;flagCltr[idxgatethresh[igrad]+1 > 0 : idxgatethresh[igrad]+1 < lastgoodbinidx, $
                  ;         rayNumpr[ifoot], scanNumpr[ifoot]] = 80b
            endif else begin
              ; special rule if Z jumps up at last change
               if igrad EQ countbygatethresh-1 and slopes[idxgatethresh[igrad]] GT 0 THEN BEGIN
                  IF (idxgatethresh[igrad]+1 < lastgoodbinidx)-idxgatethresh[igrad] LT 6 THEN BEGIN
                     IF verbose GT 0 THEN print, "Found tailing ",gatethresh," dBZ/gate jump: ", $
                       gvprofile_abv[ idxgatethresh[igrad] > 0 : idxgatethresh[igrad]+1 < lastgoodbinidx ]
                       flagCltr[idxgatethresh[igrad]+1 > 0 : idxgatethresh[igrad]+1 < lastgoodbinidx, $
                                rayNumpr[ifoot], scanNumpr[ifoot]] = 80b
                  ENDIF ELSE BEGIN
                       IF verbose GT 0 THEN print, "Too wide to be tailing clutter-by-threshold: ", $
                              gvprofile_abv[ idxgatethresh[igrad] > 0 : $
                                              idxgatethresh[igrad]+1 < lastgoodbinidx ]
                  ENDELSE
               endif else begin
                 ; do normal check of jump/dropoff couplets
                  if slopes[idxgatethresh[igrad]] GT 0 THEN BEGIN  ; only care if we have a new peak

                     ; - how far away is the next dropoff?  If more than 5 gates, then ignore the span
                     ; look for other jumps before the first drop
                     for jgrad = igrad+1, countbygatethresh-1 do begin
                        IF slopes[idxgatethresh[jgrad]] LT 0 THEN BEGIN
                          IF (idxgatethresh[jgrad]-idxgatethresh[igrad]) LT 6 THEN BEGIN
                             ; look for other consecutive dropoffs within max clutter width
                             egrad=jgrad  ; grab dropoff we already found
                             if jgrad LT countbygatethresh-1 then begin
                                for kgrad = jgrad+1, countbygatethresh-1 do begin
                                   if slopes[idxgatethresh[kgrad]] LT 0 $
                                   and (idxgatethresh[kgrad]-idxgatethresh[igrad]) LT 6 $
                                   then jgrad=kgrad else break
                                endfor
                             endif
                             IF verbose GT 0 THEN print, "Found in-ray clutter-by-threshold: ", $
                                    gvprofile_abv[ idxgatethresh[igrad] > 0 : $
                                                   idxgatethresh[egrad]+1 < lastgoodbinidx ]
                                    flagCltr[idxgatethresh[igrad]+1 > 0 : idxgatethresh[jgrad] < lastgoodbinidx, $
                                             rayNumpr[ifoot], scanNumpr[ifoot]] = 80b
                          ENDIF ELSE BEGIN
                             IF verbose GT 0 THEN print, "Too wide to be in-ray clutter-by-threshold: ", $
                                    gvprofile_abv[ idxgatethresh[igrad] > 0 : $
                                                   idxgatethresh[jgrad]+1 < lastgoodbinidx ]
                          ENDELSE
                          igrad=jgrad
                          break
                        ENDIF ELSE BEGIN
                          ; another jump. Unless it is as big as prior jump then ignore it.
                          ; If as big/bigger than prior jump, then make this our new start of the pair.
                          IF verbose GT 0 THEN print, "jgrad, slope: ", jgrad, slopes[idxgatethresh[jgrad]]
                          IF slopes[idxgatethresh[jgrad]] GE slopes[idxgatethresh[igrad]] THEN BEGIN
                             igrad = jgrad
                          ENDIF
                        ENDELSE
                     endfor

                  endif else flagCltr[idxgatethresh[igrad]+1 > 0 : idxgatethresh[igrad]+1 < lastgoodbinidx, $
                                       rayNumpr[ifoot], scanNumpr[ifoot]] = 80b

;                  endif else IF verbose GT 0 THEN print, "igrad, slope: ", igrad, slopes[idxgatethresh[igrad]]
               endelse
            endelse
         endfor
      ENDIF ELSE IF verbose GT 0 THEN print, gvprofile_abv[lastgoodbinidx/2 : lastgoodbinidx]
   ENDELSE

endfor

END
