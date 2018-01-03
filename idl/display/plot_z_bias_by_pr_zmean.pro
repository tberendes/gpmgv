;+
; Copyright © 2011, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; plot_z_bias_by_pr_zmean.pro
;
; DESCRIPTION
; -----------
; This procedure plots bar graph of PR-GR mean reflectivity bias categorized
; by mean PR reflectivity.  Biases based on either unadjusted or Ku-adjusted
; GR reflectivity may be plotted.
;
; PARAMETERS
; ----------
; raintype - The rain type of the samples to be shown.  Values include 'T'
;            for Total (i.e., Any/All Types), 'C' for Convective, and 'S' for
;            Stratiform.  Value must be in quotes, e.g.: RAINTYPE='T'
; layers   - For Stratiform or Convective only, specifies which layers (relative
;            to the Bright Band) are to be included in the results.  One, two,
;            or three characters may be specified: A for Above, B for Below,
;            I for Within.  Value(s) must be in quotes with no space between,
;            e.g.: LAYERS='AB' for samples  either Above or Below bright band.
; s2ku     - Binary keyword.  If unset, use original, unadjusted ground radar
;            statistics.  If set, use differences based on Ku-adjusted GR.
;
; MODULES
; -------
;  1)  function build_regime_clause (INTERNAL)
;  2)  procedure plot_z_bias_by_pr_zmean (MAIN ROUTINE)
;
; DATABASE
; --------
; The 'gpmgv' PostgreSQL database is queried to obtain the categorized Z
; data to plot.  The tables 'dbzdiff_stats_default' and 'dbzdiff_stats_s2ku'
; must exist and be populated with data.
;
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;
;===============================================================================

; Module #1

function build_regime_clause, raintype, layers, TITLEADD=titleadd

quote="'"
comma=""

CASE raintype OF
  'T' : BEGIN
          regime_clause = quote+'Total'+quote
          IF N_PARAMS() GT 1 THEN print, $
             "Ignoring LAYERS parameter for 'Total' rain type"
          IF N_ELEMENTS( titleadd ) NE 0 THEN BEGIN
             titleadd = titleadd+'Any Rain Type, All Layers'
          ENDIF
          return, regime_clause
        END
  'C' : BEGIN
          regime_clause = ''
          IF N_ELEMENTS( titleadd ) NE 0 THEN titleadd = titleadd+'Convective Rain'
          prefix = 'C_'
        END
  'S' : BEGIN
          regime_clause = ''
          IF N_ELEMENTS( titleadd ) NE 0 THEN titleadd = titleadd+'Stratiform Rain'
          prefix = 'S_'
        END
 ELSE : BEGIN
          regime_clause=quote+'Total'+quote
          print, "Unknown RAINTYPE parameter, defaulting to 'Total' for rain type."
          IF N_PARAMS() GT 1 THEN print, $
             "Ignoring LAYERS parameter for 'Total' rain type"
          IF N_ELEMENTS( titleadd ) NE 0 THEN BEGIN
             titleadd = titleadd+'Any Rain Type, All Layers'
          ENDIF
          return, regime_clause
        END
ENDCASE

nlyr = STRLEN(layers)
lyrarr = strarr(nlyr)

for ilyr = 0, nlyr-1 do begin
   lyrarr[ilyr] = strmid( layers, ilyr, 1 )
endfor

lyrarr = STRUPCASE( lyrarr[UNIQ(lyrarr, SORT(lyrarr))] )
nlyr = N_ELEMENTS(lyrarr)

semicomma = '; '
for ilyr = 0, nlyr-1 do begin
   CASE lyrarr[ilyr] OF
      'A' : BEGIN
              regime_clause=regime_clause+comma+quote+prefix+'above'+quote
              comma=', '
              IF N_ELEMENTS( titleadd ) NE 0 THEN BEGIN
                 titleadd = titleadd+semicomma+'Above'
                 semicomma = ', '
              ENDIF
           END
      'B' : BEGIN
              regime_clause=regime_clause+comma+quote+prefix+'below'+quote
              comma=', '
              IF N_ELEMENTS( titleadd ) NE 0 THEN BEGIN
                 titleadd = titleadd+semicomma+'Below'
                 semicomma = ', '
              ENDIF
            END
      'I' : BEGIN
              regime_clause=regime_clause+comma+quote+prefix+'in'+quote
              comma=', '
              IF N_ELEMENTS( titleadd ) NE 0 THEN titleadd = titleadd+semicomma+'Within'
            END
     ELSE : print, "Skipping unknown proximity type: ", lyrarr[ilyr]
   ENDCASE
endfor

IF N_ELEMENTS( titleadd ) NE 0 THEN BEGIN
   titleadd = titleadd + ' Bright Band'
;   print, "TITLEADD = ", titleadd
ENDIF

return, regime_clause
end

;===============================================================================

; Module #2

pro plot_z_bias_by_pr_zmean, RAINTYPE=raintype, LAYERS=layers, S2KU=s2ku

quote="'"

if keyword_set(s2ku) then begin
   table='dbzdiff_stats_s2kunewbb'
   plot_title = "PR-GR (Ku-adjusted) mean Z differences, by PR mean Z category; "
endif else begin
   table='dbzdiff_stats_defaultnewbb'
   plot_title = "PR-GR mean Z differences, by PR mean Z category; "
endelse

if n_elements( layers ) EQ 0 then begin
   print, "No layers specified, defaulting to ABI (Above, Below, In)"
   layers = 'ABI'
endif

if n_elements(raintype) EQ 1 THEN rainspec = strupcase(strmid(raintype, 0, 1)) $
else rainspec = 'X'

titlepost = ''
regimes = build_regime_clause( rainspec, layers, TITLEADD=plot_title )
;print, "regimes = ", regimes

command='echo "\t \a \\\select round( (prmean+1.0)/2.0 )*2 as prmean, ' $
+ 'round((sum(meandiff*numpts)/sum(numpts))*100)/100 as meandiffavg, ' $
+ 'sum(numpts) as total from ' +table+ ' where regime in (' +regimes+ ') ' $
+ 'and numpts>5 and gvtype=' +quote+ 'GeoM' +quote+ ' and radar_id !=' $
+ quote+ 'KGRK' +quote+ ' group by 1 order by 1;" | psql -q -d gpmgv'

spawn, command, dbresult, COUNT=nbins

IF nbins EQ 0 THEN MESSAGE, "No rows returned from query: "+command

przbins=intarr(nbins)
zdifbyz=fltarr(nbins)
numbins=lonarr(nbins)

for ibin = 0, nbins-1 do begin
   parsed = strsplit( dbresult[ibin], '|', /extract )
   przbins[ibin] = FIX(parsed[0])
   zdifbyz[ibin] = FLOAT(parsed[1])
   numbins[ibin] =parsed[2]
endfor

print, ''
print, "PR reflectivity categories (dBZ):"
print, przbins, FORMAT='(I0)'
print, ''
print, "PR-GR Mean Reflectivity Differences by Z categories:"
print, zdifbyz, FORMAT='(F0.2)'
print, ''
print, numbins
device, decomposed=0
loadct, 17
tvlct, rr,gg,bb,/get

; -- set values 254-255 as white, for labels and such
rr[254:255] = 255
gg[254:255] = 255
bb[254:255] = 255
tvlct, rr,gg,bb

;print, "TITLE: ", plot_title
bar_plot, zdifbyz, barnames=przbins, colors = (255/max(przbins))*przbins, $
          xtitle="PR mean reflectivity, dBZ", ytitle="PR-GR mean difference (dBZ)", $
          TITLE=plot_title

; label the bars with the number of points in each z category
xpos = (0.89/nbins)*(findgen(nbins)+0.5) + 0.01
;print, xpos
xyouts, xpos, 0.1+0.83*(zdifbyz-min(zdifbyz))/max(zdifbyz-min(zdifbyz)), numbins, /normal

end
