;===============================================================================
;+
; Copyright © 2011, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; plot_pct_abv_thresh_pdfs.pro
; - Morris/SAIC/GPM_GV  June 2011
;
; DESCRIPTION
; -----------
; Plots histograms (regular and cumulative) of ground radar bin percent above
; threshold for samples stratified either by rain type category or by underlying
; surface type category.  Histogram is binned in steps of 5 percent.
;
; HISTORY
; -------
; 06/14/11 Morris, GPM GV, SAIC
; - Created.
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;===============================================================================

pro plot_pct_abv_thresh_pdfs, pctgood, cat_array, cat_type

CASE cat_type OF
   'RainType' : BEGIN
       Type_str = [' N/A ', 'Stratiform', 'Convective', 'Other']
       Type_name = 'Rain Type'
     END
   'SurfaceType' : BEGIN
       Type_str = [' N/A ', 'Ocean', ' Land', 'Coast']
       Type_name = 'Surface Type'
     END
   ELSE : BEGIN
     message, "Illegal category type, must be 'RainType' or 'SurfaceType'"
     END
ENDCASE
 
xoff = [0.0, 0.0, 0.33, 0.66 ]  ; for positioning legend in PDFs
yoff = [0.0, 0.0, 0.33, 0.66 ]
Window, 4, xsize=350, ysize=700, TITLE = "Percent of GR bins above dBZ thresholds", $
        RETAIN=2
for category = 1, 3 do begin
   havematch = 0
   !P.Multi=[4-category, 1, 3, 0, 0]
   idxtype = WHERE( cat_array EQ category, counttype )
   IF ( counttype GT 2 ) THEN BEGIN
      hist = histogram(pctgood[idxtype], min=0, max=100, binsize = 5, $
                            locations = histstart)
     ; build a cumulative histogram
      nhist = N_ELEMENTS(hist)
      cumulative = hist
      FOR i = 0, nhist-2 DO cumulative[i]=cumulative[i]+TOTAL(cumulative[i+1:nhist-1])
;      plot, [0,MAX(histstart)], [0,MAX(hist)*1.1], $
;print, "MAX(hist), counttype", MAX(hist)*1.1, counttype*1.1
      plot, [0,MAX(histstart)], [0,counttype*1.1], $
                  /NODATA, COLOR=255, CHARSIZE=2, $
                  XTITLE=Type_str[category] + " percent of GR bins above threshold", $
                  YTITLE='Number of TMI Footprints', $
;                  YRANGE=[ 0, FIX(MAX(hist)*1.1) + 1 ], $
                  YRANGE=[ 0, FIX(counttype*1.1) + 1 ], $
                  BACKGROUND=0
      oplot, histstart, hist, COLOR=200
      oplot, histstart, cumulative, COLOR=60
   ENDIF ELSE BEGIN
      print, "No points for ", Type_str[category] + " " + Type_name
      xyouts, 0.2+xoff[category],0.75, Type_str[category] + " " + Type_name + $
              ": NO POINTS", COLOR=255, /NORMAL, CHARSIZE=1
   ENDELSE
endfor
      xyouts, 0.4, 0.95, "Cumulative # footprints, at/above percent", COLOR=60, CHARSIZE=0.75, /NORMAL
      xyouts, 0.4, 0.925, "# footprints at percent level (5% steps)", COLOR=200, CHARSIZE=0.75, /NORMAL

end
