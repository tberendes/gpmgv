;+
; Copyright © 2011, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; plot_mean_z_bias_profiles.pro
;
; DESCRIPTION
; This procedure plots vertical profiles of dataset-mean reflectivity and
; reflectivity bias.  Mean and bias of reflectivity are plotted in different
; panels.  Only unadjusted GR mean reflectivity is plotted.  Both unadjusted
; and Ku-adjusted GR reflectivity profiles are plotted for the bias plot.
;
; DATABASE
; The 'gpmgv' PostgreSQL database is queried to obtain the vertical profile
; data to plot.  The 'dbzdiff_stats_merged' VIEW must exist in the database,
; and the three tables 'dbzdiff_stats_default', 'dbzdiff_stats_s2ku' and
; 'dbzdiff_stats_prrawcor' must exist and be populated with data.
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-

pro plot_mean_z_bias_profiles

quote="'"
c_clause = quote + 'C_above' + quote + ',' + quote + 'C_below' + quote
s_clause = quote + 'S_above' + quote + ',' + quote + 'S_below' + quote
t_clause = quote + 'Total' + quote

commandpre = 'echo "\t \a \\\select height, round((sum(meandiff*numpts)/sum(numpts))*100)/100 as zdifcororg, round((sum(meandiffku*numpts)/sum(numpts))*100)/100 as zdifcoradj, round((sum(prmean*numpts)/sum(numpts))*100)/100 as zcor, round((sum(gvmean*numpts)/sum(numpts))*100)/100 as zorg, round((sum(gvmeanku*numpts)/sum(numpts))*100)/100 as zadj, sum(numpts) as n from dbzdiff_stats_merged where rangecat<2 and numpts>5 and regime in ('

commandpost = ') and radar_id NOT IN (' + quote + 'KGRK' + quote + ',' + quote + 'KWAJ' + quote + ',' + quote + 'RGSN' + quote + ',' + quote + 'RMOR' + quote + ') and orbit<64708 group by 1 order by 1;" | psql -q -d gpmgv'

c_command = commandpre + c_clause + commandpost
s_command = commandpre + s_clause + commandpost
t_command = commandpre + t_clause + commandpost

SPAWN, t_command, t_dbresult, COUNT=t_events
SPAWN, c_command, c_dbresult, COUNT=c_events
SPAWN, s_command, s_dbresult, COUNT=s_events

IF ( t_events LT 2 ) THEN BEGIN
   message, "In plot_mean_z_bias_profiles, no/too few *Total* rows returned from DB query: ", t_events
ENDIF ELSE BEGIN
  ; load the Total row data into arrays
   num_events = t_events
   PRINT, 'total number of Total levels = ', num_events
   hgtarr = FLTARR(num_events)
   tzdifcororg = FLTARR(num_events) & tzdifcoradj = tzdifcororg
   czdifcororg = tzdifcororg & szdifcororg = czdifcororg & czdifcoradj = czdifcororg & szdifcoradj = czdifcororg
   prmnarr = FLTARR(num_events) & cprmnarr = prmnarr & sprmnarr = prmnarr
   grmnarr = FLTARR(num_events) & cgrmnarr = grmnarr & sgrmnarr = grmnarr
   gradjmnarr = FLTARR(num_events) & cgradjmnarr = grmnarr & sgradjmnarr = grmnarr
   samples = LONARR(num_events) & csamples = samples & ssamples = samples
   x_range = FLTARR(2) ; index0 is min index1 is max
   y_range = FLTARR (2) ; index0 is min index1 is max
   x_range_dif = FLTARR(2) ; index0 is min index1 is max
   y_range_dif = FLTARR (2) ; index0 is min index1 is max

  ; load the Total row data into arrays
   FOR i=0, num_events-1  DO BEGIN
       parsed = strsplit( t_dbresult[i], '|', /extract )
       hgtarr[i] = float(parsed[0])
       tzdifcororg[i] = float(parsed[1])
       tzdifcoradj[i] = float( parsed[2] )
       prmnarr[i] = float( parsed[3] )
       grmnarr[i] = float( parsed[4] )
       samples[i] =  long( parsed[6] )
       print, "Height = ", hgtarr[i]
   ENDFOR
ENDELSE

IF ( c_events LT 2 ) THEN BEGIN
   message, "In plot_mean_z_bias_profiles, no/too few Convective rows returned from DB query: ", c_events
ENDIF ELSE BEGIN
   PRINT, 'total number of Convective levels = ', c_events
  ; load the convective row data into arrays
   FOR i=0, c_events-1  DO BEGIN
       parsed = strsplit( c_dbresult[i], '|', /extract )
      ; hgtarr[i] = float(parsed[0])  -- already did in Totals
       czdifcororg[i] = float(parsed[1])
       czdifcoradj[i] = float( parsed[2] )
       cprmnarr[i] = float( parsed[3] )
       cgrmnarr[i] = float( parsed[4] )
       csamples[i] =  long( parsed[6] )
   ENDFOR
ENDELSE

IF ( s_events LT 2 ) THEN BEGIN
   message, "In plot_mean_z_bias_profiles, no/too few Stratiform rows returned from DB query: ", s_events
ENDIF ELSE BEGIN
   PRINT, 'total number of Stratiform levels = ', s_events
  ; load the Stratiform row data into arrays
   FOR i=0, s_events-1  DO BEGIN
       parsed = strsplit( s_dbresult[i], '|', /extract )
      ; hgtarr[i] = float(parsed[0])  -- already did in Totals
       szdifcororg[i] = float(parsed[1])
       szdifcoradj[i] = float( parsed[2] )
       sprmnarr[i] = float( parsed[3] )
       sgrmnarr[i] = float( parsed[4] )
       ssamples[i] =  long( parsed[6] )
   ENDFOR
ENDELSE


FOR i=0, num_events-1  DO BEGIN
   thismaxz = MAX( [cprmnarr[i],cgrmnarr[i],sprmnarr[i],sgrmnarr[i],prmnarr[i],grmnarr[i]] )
   thisminz = MIN( [cprmnarr[i],cgrmnarr[i],sprmnarr[i],sgrmnarr[i],prmnarr[i],grmnarr[i]] )
   thismaxzdif = MAX( [tzdifcororg[i],czdifcororg[i],szdifcororg[i],tzdifcoradj[i],czdifcoradj[i],szdifcoradj[i]] )
   thisminzdif = MIN( [tzdifcororg[i],czdifcororg[i],szdifcororg[i],tzdifcoradj[i],czdifcoradj[i],szdifcoradj[i]] )
   IF (i EQ 0) THEN BEGIN ; find the bounds for the plot axes
      x_range[1] = thismaxz
      x_range[0] = thisminz
      x_range_dif[1] = thismaxzdif
      x_range_dif[0] = thisminzdif
   ENDIF ELSE BEGIN
      x_range[1] = x_range[1] > thismaxz
      x_range[0] = x_range[0] < thisminz
      x_range_dif[1] = x_range_dif[1] > thismaxzdif
      x_range_dif[0] = x_range_dif[0] < thisminzdif
   ENDELSE
ENDFOR
signby2 = (x_range_dif/ABS(x_range_dif))*2.0
x_range_dif = (FIX(x_range_dif+signby2)/2)*2
; # # # # # # # # # # # # # # # # # # # # # # # # # # # #

; Build the mean Z profile plot panel
device, decomposed = 0
LOADCT, 2

Window, xsize=700, ysize=700, TITLE = "Dataset mean vertical profiles"
h2plot = hgtarr[0:num_events-1]
ytickstep = hgtarr[1] - hgtarr[0]

; figure out the y-axis range.  Use the lesser of hgtarr[num_events-1]*2.0
; and 20 km if result>20.
prop_max_y = hgtarr[num_events-1]*2.0
plot, [15,50], [0,20 < prop_max_y], /NODATA, COLOR = 255, $
      XSTYLE=1, YSTYLE=1, YTICKINTERVAL=ytickstep, YMINOR=1, thick=1, $
      XTITLE='Level Mean Reflectivity, dBZ', YTITLE='Height Level, km', $
      CHARSIZE=1, BACKGROUND=0
oplot, prmnarr, h2plot, COLOR = 30, thick=1
oplot, grmnarr, h2plot, COLOR = 70, thick=1
; plot the profile for stratiform rain type points
oplot, sprmnarr[0:s_events-1], h2plot[0:s_events-1], COLOR = 30, LINESTYLE=1, thick=3
oplot, sgrmnarr[0:s_events-1], h2plot[0:s_events-1], COLOR = 70, LINESTYLE=1, thick=3
; plot the profile for convective rain type points
oplot, cprmnarr[0:c_events-1], h2plot[0:c_events-1], COLOR = 30, LINESTYLE=2, thick=2
oplot, cgrmnarr[0:c_events-1], h2plot[0:c_events-1], COLOR = 70, LINESTYLE=2, thick=2

            xyouts, 0.84, 0.95, 'PR (all)', COLOR = 30, /NORMAL, CHARSIZE=1
            plots, [0.79,0.83], [0.955,0.955], COLOR = 30, /NORMAL
            xyouts, 0.84, 0.925, 'GR (all)', COLOR = 70, /NORMAL, CHARSIZE=1
            plots, [0.79,0.83], [0.93,0.93], COLOR = 70, /NORMAL
           xyouts, 0.84, 0.85, 'PR (Conv)', COLOR = 30, /NORMAL, CHARSIZE=1
           xyouts, 0.84, 0.825,'GR (Conv)', COLOR = 70, /NORMAL, CHARSIZE=1
           plots, [0.79,0.83], [0.855,0.855], COLOR = 30, /NORMAL, LINESTYLE=2, thick=3
           plots, [0.79,0.83], [0.83,0.83], COLOR = 70, /NORMAL, LINESTYLE=2, thick=3

           xyouts, 0.84, 0.9, 'PR (Strat)', COLOR = 30, /NORMAL, CHARSIZE=1
           xyouts, 0.84, 0.875, 'GR (Strat)', COLOR = 70, /NORMAL, CHARSIZE=1
           plots, [0.79,0.83], [0.905,0.905], COLOR = 30, /NORMAL, LINESTYLE=1, thick=3
           plots, [0.79,0.83], [0.88,0.88], COLOR = 70, /NORMAL, LINESTYLE=1, thick=3
; # # # # # # # # # # # # # # # # # # # # # # # # # # # #

; Build the mean Zdiff profile plot panel

Window, 1, xsize=700, ysize=700, TITLE = "Dataset mean difference vertical profiles, Bright Band excluded"
h2plot = (findgen(num_events) + 1) * 1.5

; figure out the y-axis range.  Use the lesser of hgtarr[num_events-1]*2.0
; and 20 km if result>20.
prop_max_y = hgtarr[num_events-1]*2.0
plot, x_range_dif, [0,20 < prop_max_y], /NODATA, COLOR = 255, $
      XSTYLE=1, YSTYLE=1, YTICKINTERVAL=1.5, YMINOR=1, thick=1, $
      XTITLE='Level Mean Reflectivity Difference, dBZ', YTITLE='Height Level, km', $
      CHARSIZE=1, BACKGROUND=0
oplot, tzdifcororg, h2plot, COLOR = 30, thick=1
oplot, tzdifcoradj, h2plot, COLOR = 70, thick=1
; plot the profile for stratiform rain type points
oplot, szdifcororg[0:s_events-1], h2plot[0:s_events-1], COLOR = 30, LINESTYLE=1, thick=3
oplot, szdifcoradj[0:s_events-1], h2plot[0:s_events-1], COLOR = 70, LINESTYLE=1, thick=3
; plot the profile for convective rain type points
oplot, czdifcororg[0:c_events-1], h2plot[0:c_events-1], COLOR = 30, LINESTYLE=2, thick=2
oplot, czdifcoradj[0:c_events-1], h2plot[0:c_events-1], COLOR = 70, LINESTYLE=2, thick=2

            xyouts, 0.8, 0.95, 'PR-GR (all)', COLOR = 30, /NORMAL, CHARSIZE=1
            plots, [0.75,0.79], [0.955,0.955], COLOR = 30, /NORMAL
            xyouts, 0.8, 0.925, 'PR-GRadj (all)', COLOR = 70, /NORMAL, CHARSIZE=1
            plots, [0.75,0.79], [0.93,0.93], COLOR = 70, /NORMAL
           xyouts, 0.8, 0.85, 'PR-GR (Conv)', COLOR = 30, /NORMAL, CHARSIZE=1
           xyouts, 0.8, 0.825,'PR-GRadj (Conv)', COLOR = 70, /NORMAL, CHARSIZE=1
           plots, [0.75,0.79], [0.855,0.855], COLOR = 30, /NORMAL, LINESTYLE=2, thick=3
           plots, [0.75,0.79], [0.83,0.83], COLOR = 70, /NORMAL, LINESTYLE=2, thick=3

           xyouts, 0.8, 0.9, 'PR-GR (Strat)', COLOR = 30, /NORMAL, CHARSIZE=1
           xyouts, 0.8, 0.875, 'PR-GRadj (Strat)', COLOR = 70, /NORMAL, CHARSIZE=1
           plots, [0.75,0.79], [0.905,0.905], COLOR = 30, /NORMAL, LINESTYLE=1, thick=3
           plots, [0.75,0.79], [0.88,0.88], COLOR = 70, /NORMAL, LINESTYLE=1, thick=3
plots, [0,0], [0,20 < prop_max_y], COLOR = 255, LINESTYLE=1

end
