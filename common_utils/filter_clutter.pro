function filter_clutter, scanNumpr, raystartpr, rayendpr, gvprofileIn, $
                         flagEcho, clutterFreeBin

verbose=1

; grab our subset of rays for the specified scan from the Z profile,
; flagEcho, and clutterFreeBin arrays.  DPR order is bin,ray,scan
startbin = REFORM(clutterFreeBin[raystartpr:rayendpr, scanNumpr])  ; no bin dim.
gvzprofiles = REFORM(gvprofileIn[*, raystartpr:rayendpr, scanNumpr])
flagEchoes = REFORM(flagEcho[*, raystartpr:rayendpr, scanNumpr])
nfooties = rayendpr-raystartpr + 1
s=SIZE(flagEchoes,/DIMENSIONS)
nbins = s[0]
IF nbins GT 100 THEN binsperkm = 8 ELSE binsperkm = 4
flagEcho[*,raystartpr:rayendpr, scanNumpr]=0b

clutterBoundsIdx = INTARR(2,nfooties)   ; tally the clutter top, bottom gates

; compute nominal DPR bin heights based on 125m gates (1/8 km)
hgtprofiles = FLOAT( INDGEN(SIZE(flagEchoes,/DIMENSIONS)) MOD nbins ) / binsperkm

bbhgt = 0.0  ; 
for ifoot = 0, nfooties-1 DO BEGIN
   haveplot=0
   IF verbose GT 0 THEN $
      print, "===================== RAY ", STRING(ifoot+1, FORMAT='(I0)'), " ====================="

; "blank" out the clutter bins, if information provided
  gvzprofiles[ (startbin[ifoot]+1)<(nbins-1) : nbins-1, ifoot] = 9.0

  ; grab the individual profile at the footprint above the lowest clutter-free bin.
;;;   lastgoodbinidx=startbin[ifoot]-1
   lastgoodbinidx=startbin[ifoot]+2 < nbins-1  ; look below the clutter-free limit
   gvprofile_abv=REFORM(gvzprofiles[0:lastgoodbinidx,ifoot])
   hgtprofile_abv=REFORM(hgtprofiles[0:lastgoodbinidx,ifoot])
   flagEchoes_abv=REFORM(flagEchoes[0:lastgoodbinidx,ifoot])

  ; do we have any actual reflectivity values in this profile?  If so, grab just
  ; these samples for evaluation
   idxactual = WHERE(gvprofile_abv GT 0.0, countactual)
   IF (countactual EQ 0) THEN BEGIN
      IF verbose GT 0 THEN message, "No non-zero gvz values in ray, skipping.", /INFO
      gvprofile = [0.,0.,0.]
      ;CONTINUE   ; leave profile as No Rain, skip to next ray
   ENDIF ELSE BEGIN
     ; set negative/small values to 5.0
      idxneg = WHERE(gvprofile_abv LT 9.0, countneg)
      IF countneg GT 0 THEN gvprofile_abv[idxneg] = 9.0
     ; round Z values to nearest "gatethresh" dBZ
GATETHRESH=5
;      gvprofile = (FIX(gvprofile_abv)/gatethresh)*gatethresh
      hgtprofile = hgtprofile_abv[idxactual]
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
               print, "Found leading ",gatethresh," dBZ/gate dropoff: ", $
                  gvprofile_abv[ idxgatethresh[igrad] > 0 : idxgatethresh[igrad]+1 < lastgoodbinidx ]
flagEcho[idxgatethresh[igrad]+1 > 0 : idxgatethresh[igrad]+1 < lastgoodbinidx, raystartpr+ifoot, scanNumpr] = 80b
            endif else begin
              ; special rule if Z jumps up at last change
               if igrad EQ countbygatethresh-1 and slopes[idxgatethresh[igrad]] GT 0 THEN BEGIN
                  print, "Found tailing ",gatethresh," dBZ/gate jump: ", $
                     gvprofile_abv[ idxgatethresh[igrad] > 0 : idxgatethresh[igrad]+1 < lastgoodbinidx ]
flagEcho[idxgatethresh[igrad]+1 > 0 : idxgatethresh[igrad]+1 < lastgoodbinidx, raystartpr+ifoot, scanNumpr] = 80b
               endif else begin
                 ; do normal check of jump/dropoff couplets
                  if slopes[idxgatethresh[igrad]] GT 0 THEN BEGIN  ; only care if we have a new peak

                     ; - how far away is the next dropoff?  If 1 km or more of gates, then ignore the span
                     ; look for other jumps before the first drop
                     for jgrad = igrad+1, countbygatethresh-1 do begin
                        IF slopes[idxgatethresh[jgrad]] LT 0 THEN BEGIN
                          IF (idxgatethresh[jgrad]-idxgatethresh[igrad]) LT binsperkm THEN BEGIN
                             ; look for other consecutive dropoffs within max clutter width
                             egrad=jgrad  ; grab dropoff we already found
                             if jgrad LT countbygatethresh-1 then begin
                                for kgrad = jgrad+1, countbygatethresh-1 do begin
                                   if slopes[idxgatethresh[kgrad]] LT 0 $
                                   and (idxgatethresh[kgrad]-idxgatethresh[igrad]) LT binsperkm $
                                   then jgrad=kgrad else break
                                endfor
                             endif
                             print, "Found in-ray clutter-by-threshold: ", $
                                    gvprofile_abv[ idxgatethresh[igrad] > 0 : $
                                                   idxgatethresh[egrad]+1 < lastgoodbinidx ]
flagEcho[idxgatethresh[igrad]+1 > 0 : idxgatethresh[jgrad] < lastgoodbinidx, raystartpr+ifoot, scanNumpr] = 80b
                          ENDIF ELSE BEGIN
                             print, "Too wide to be in-ray clutter-by-threshold: ", $
                                    gvprofile_abv[ idxgatethresh[igrad] > 0 : $
                                                   idxgatethresh[jgrad]+1 < lastgoodbinidx ]
                          ENDELSE
                          igrad=jgrad
                          break
                        ENDIF ELSE BEGIN
                          ; another jump. Unless it is as big as prior jump then ignore it.
                          ; If as big/bigger than prior jump, then make this our new start of the pair.
                          print, "jgrad, slope: ", jgrad, slopes[idxgatethresh[jgrad]]
                          IF slopes[idxgatethresh[jgrad]] GE slopes[idxgatethresh[igrad]] THEN BEGIN
                             igrad = jgrad
                          ENDIF
                        ENDELSE
                     endfor

                  endif else flagEcho[idxgatethresh[igrad]+1 > 0 : idxgatethresh[igrad]+1 < lastgoodbinidx, raystartpr+ifoot, scanNumpr] = 80b

;                  endif else print, "igrad, slope: ", igrad, slopes[idxgatethresh[igrad]]
               endelse
            endelse
         endfor
      ENDIF ELSE print, gvprofile_abv[lastgoodbinidx/2 : lastgoodbinidx]
   ENDELSE


;print, "Ray: ",raystartpr+ifoot, "  clutter bins: ", $
;       gvprofile_abv[idxactual[clutterBoundsIdx[0,ifoot]:clutterBoundsIdx[1,ifoot]]]
;print, "Profile: ", gvprofile_abv[idxactual]
;help, gvprofile
;IF countactual GT 2 THEN BEGIN
;   plot, gvprofile
;   haveplot=1
;ENDIF ELSE BEGIN
;   if haveplot then wdelete,0
;ENDELSE
; set up for bailout prompt
; doodah = ""
; PRINT, ''
; READ, doodah, $
; PROMPT='Hit Return to do next case, Q to Quit: '
; IF doodah EQ 'Q' OR doodah EQ 'q' THEN break

endfor

return, 1
END
