;+
; Copyright © 2010, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; get_mean_bb_height2.pro      Morris/SAIC/GPM_GV      April 2010
;
; DESCRIPTION
; -----------
; Computes a best estimate of the mean bright band height from an array of
; bright band heights from the 2A-25 RangeBinNums field, using a histogram
; analysis, finding the histogram peak corresponding to the bright band height.
; Optionally, plots the histogram of bright band height, tagged with the peak
; determined to be at the location of the bright band.
;
; If the 2A23 BBstatus array is provided as a second non-keyword parameter, then
; the histogram technique will be used as the fallback technique only if no
; points meeting the 'good' or 'fair' BB status are identified.  Otherwise, the
; mean BB height will be computed as the mean of the BB heights for the 'good'
; points (if any) or 'fair' points (if any, and if no 'good' points).
;
; PARAMETERS
; ----------
; bb2hist     - array of bright ban height for the PR rays in consideration.
; bbstatus    - array of 2A23 BBstatus values for the PR rays in consideration
;               (must match the bb2hist rays one-to-one).  If not present, the
;               technique will default to the histogram analysis method of
;               determining the mean BB height.
; bs          - the bin size (km) to using in generating the histogram of BB
;               height. Defaults to 0.2 km if not specified.
; hist_window - number of the IDL window in which to plot the histogram of
;               bright band height.  If not specified, then the histogram is
;               not plotted and detailed diagnostics are not printed.
;
; MODULES
; -------
; get_mean_bb_by_histo() - Legacy routine using only 2A25 BB heights to compute
;                          mean BB height via a histogram analysis.
; get_mean_bb_height()   - Computes mean BB heights using BB heights from 2A25,
;                          and matching BBstatus values from 2A23 (if provided,
;                          and if BBstatus of any points meet the 'good' or
;                          'fair' criteria).  Otherwise uses BB heights only and
;                          calls get_mean_bb_by_histo() as a fallback method.
; HISTORY
; -------
; 04/22/10 - Morris/NASA/GSFC (SAIC), GPM GV:  Created.
; 05/13/10 - Morris/NASA/GSFC (SAIC), GPM GV
; - Made all print statements conditional on hist_window parameter presence.
; 08/10/10 - Morris/NASA/GSFC (SAIC), GPM GV
; - Replaced calls to lclxtrem() with call to local_maxima().
; 11/16/10 - Morris/NASA/GSFC (SAIC), GPM GV
; - Added 'bbstatus' parameter and capability of using it to compute the mean
;   BB height using the 2A23 information, if available.  Moved old function to
;   new internal function "get_mean_bb_by_histo()".
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-

;===============================================================================

FUNCTION get_mean_bb_by_histo, bb2hist, BS=bs, HIST_WINDOW=hist_window

   IF N_ELEMENTS(bs) NE 1 THEN bs=0.2  ; HISTO bin size in km
   IF N_ELEMENTS(hist_window) EQ 1 THEN plot_hist=1 ELSE plot_hist=0

   bbhist = HISTOGRAM(bb2hist, binsize=bs, locations=bbhiststart, reverse_indices=R)
   IF plot_hist THEN BEGIN
      window,hist_window,xsize=400,ysize=400,retain=2
      plot, [0.0,MAX(bbhiststart)>6.0],[0,FIX(MAX(bbhist))], /NODATA, COLOR=255, $
            xtitle='2A-25 BB Height (km)', ytitle='Num. points in Height Bin'
      oplot, bbhiststart + bs/2.0, bbhist, COLOR = 255
   ENDIF

   nbbmaxes=0
   idxabsmax = -1
   IF N_ELEMENTS(bbhist) GT 2 THEN BEGIN
      idxbbmaxes = local_maxima( bbhist, COUNT=nbbmaxes, IDXABSMAX=idxabsmax )
      IF plot_hist THEN print, "Number of BB maxima in histogram: ", nbbmaxes
      IF plot_hist THEN print, "Values of maxima in BB histogram: ", bbhiststart[idxbbmaxes] + bs/2.
     ; compare each maximum in data order against the biggest maximum, in terms
     ; of the number of points in the two associated histogram bins.  Tag the
     ; first peak in data order that is bigger than 1/30th of the max peak as
     ; the location of the BB (for now) (could be the max peak itself)
      IF ( nbbmaxes GT 1 ) THEN BEGIN
         FOR imax = 0, nbbmaxes-1 DO BEGIN
            IF ( bbhist[idxabsmax] / bbhist[idxbbmaxes[imax]] LT 30. ) THEN BEGIN
              ; take the next peak in ascending height order as the mean BB height
               idxpeak4bb=imax  ; the maximum that is at the BB, for now
               i = idxbbmaxes[imax]  ; histo bin of qualifying maxima
               BBbin = bb2hist[ R[ R[i] : R[i+1]-1 ] ]
               IF plot_hist THEN print, "BB values in max bin ",imax+1,": ", BBbin
               meanbb = MEAN(BBbin)
               iBBfornow=i
               break
            ENDIF
         ENDFOR
        ; check any adjacent peaks for heights within .75 km above the tagged
        ; BB height.  If an adjacent peak is bigger, take it as the BB height
         IF ( idxpeak4bb LT nbbmaxes-1 ) THEN BEGIN
            BBhgtfornow=bbhiststart[iBBfornow]
            histpeakfornow=bbhist[iBBfornow]
            FOR imax = idxpeak4bb+1, nbbmaxes-1 DO BEGIN
                IF ( (bbhiststart[idxbbmaxes[imax]]-BBhgtfornow) LT .75 ) THEN BEGIN
                   IF ( bbhist[idxbbmaxes[imax]] GT histpeakfornow ) THEN BEGIN
                     ; take the next peak in ascending height order as the mean BB height
                      i = idxbbmaxes[imax]  ; histo bin of qualifying maxima
                      BBbin = bb2hist[ R[ R[i] : R[i+1]-1 ] ]
                      IF plot_hist THEN print, "BB values in max bin ",imax+1,": ", BBbin
                      meanbb = MEAN(BBbin)
                      histpeakfornow=bbhist[i]
                   ENDIF
                ENDIF ELSE break
            ENDFOR
         ENDIF
      ENDIF ELSE BEGIN
        ; only have one maximum, take it
         i = idxbbmaxes[0]
         BBbin = bb2hist[ R[ R[i] : R[i+1]-1 ] ]
         IF plot_hist THEN print, "BB values in lone max bin: ", BBbin
         meanbb = MEAN(BBbin)
      ENDELSE
      IF plot_hist THEN xyouts, meanbb, bbhist[i], '*', size=3
   ENDIF ELSE BEGIN
      IF plot_hist THEN print, "Too few points for Maxima routine: ", N_ELEMENTS(bbhist)
      meanbb = MEAN(bb2hist)
   ENDELSE
return, meanbb
end

;===============================================================================

FUNCTION get_mean_bb_height2, bb2hist, BBstatus, BS=bs, HIST_WINDOW=hist_window

   IF N_PARAMS() EQ 2 THEN BEGIN
      idxbbgood = WHERE( BBstatus/16 EQ 3, countbbgood )
      if (countbbgood GT 0 ) then begin
         meanbbgood = MEAN( bb2hist[idxbbgood])
         print, "Mean BB (km MSL) by 2A23 BBstatus 'good': ", meanbbgood
      endif else begin
         print, "No points with BB detection status 'good' (=3)"
        ; try the "fair" BB detection points
         idxbbgood = WHERE( BBstatus/16 EQ 2, countbbgood )
         if (countbbgood GT 0 ) then begin
            meanbbgood = MEAN( bb2hist[idxbbgood])
            print, "Mean BB (km MSL) by 2A23 BBstatus 'fair': ", meanbbgood
         endif else begin
            print, "No points with BB detection status 'fair' (=2), fall back to histogram"
            meanbbgood = get_mean_bb_by_histo( bb2hist, BS=bs, HIST_WINDOW=hist_window )
            print, "Mean BB (km MSL) by histogram analysis fallback: ", meanbbgood
         endelse
      endelse
   ENDIF ELSE BEGIN
      meanbbgood = get_mean_bb_by_histo( bb2hist, BS=bs, HIST_WINDOW=hist_window )
      print, "Mean BB (km MSL) by histogram analysis: ", meanbbgood
   ENDELSE

return, meanbbgood
end
