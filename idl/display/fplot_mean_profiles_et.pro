pro fplot_mean_profiles_et, file, plotlabel, INSTRUMENT=instrument

; HISTORY
; -------
; 09/15/2014 - Morris, GPM GV (SAIC)
; - Added capability to read an input file with additional fields containing PR
;   and GR Standard Deviation of reflectivity and plot a data spread based on
;   these "Error Bar" values.
; - Offset plotted sample counts for Stratiform and Convective slightly in the
;   vertical to eliminate overlap where profiles are close together.
; 09/17/2014 - Morris, GPM GV (SAIC)
; - Added capability to read saved profile variables from an IDL SAVE file
; 11/24/2014 - Morris, GPM GV (SAIC)
; - Added INSTRUMENT keyword to override default legend label of 'DPR'
; 07/24/15 - Morris, GPM GV (SAIC)
; - Created from plot_mean_profiles.pro to plot 3 categories of echo top hgt.
; 07/24/15 - Morris, GPM GV (SAIC)
; - Changed to use newer PLOT function instead of PLOT procedure.

IF N_ELEMENTS(instrument) EQ 1 THEN prDpr = instrument ELSE prDpr = 'DPR'

if N_PARAMS() EQ 1 THEN plotlabeladd = '' ELSE plotlabeladd = ': ' +plotlabel
x_range = FLTARR(2)     ; index0 is min index1 is max
y_range = FLTARR (2)    ; index0 is min index1 is max
missing_hgt_zero = 0    ; flag to indicate when data at height=0.0 is missing

have_save = STRMATCH(file, '*.sav')

IF have_save THEN BEGIN     ;==========================================

RESTORE, file
have_errbars = 1
; find the first and last heights with non-missing data, since the SAVE file
; variables contain all levels, not just those with non-missing statistics
samplemaxByLev = (samples > ssamples) > csamples
idxnotmiss = WHERE(samplemaxByLev GT 0, countnotmiss)
IF countnotmiss EQ 0 THEN BEGIN
   message, "No valid levels in profile.", /INFO
   GOTO, noPlot
ENDIF ELSE BEGIN
   idxstart = MIN(idxnotmiss, MAX=idxend)
   ; trim our arrays down to those between the first and last non-missing levels
   hgtarr = hgtarr[idxstart:idxend]
   cprmnarr = cprmnarr[idxstart:idxend]
   cgrmnarr = cgrmnarr[idxstart:idxend]
   cprsdarr = cprsdarr[idxstart:idxend]
   cgrsdarr = cgrsdarr[idxstart:idxend]
   csamples = csamples[idxstart:idxend]
   sprmnarr = sprmnarr[idxstart:idxend]
   sgrmnarr = sgrmnarr[idxstart:idxend]
   sprsdarr = sprsdarr[idxstart:idxend]
   sgrsdarr = sgrsdarr[idxstart:idxend]
   ssamples = ssamples[idxstart:idxend]
   prmnarr = prmnarr[idxstart:idxend]
   grmnarr = grmnarr[idxstart:idxend]
   prsdarr = prsdarr[idxstart:idxend]
   grsdarr = grsdarr[idxstart:idxend]
   samples = samples[idxstart:idxend]
ENDELSE

num_events = N_ELEMENTS(hgtarr)
x_range[0] = 50.0 & x_range[1] = 0.0  ; initialize min > max
FOR i=0, num_events-1  DO BEGIN
   IF i GT 0 and hgtarr[i]+hgtarr[i-1] EQ 0.0 THEN BEGIN
      missing_hgt_zero = 1
      ibreak = i
   ENDIF
   allz = [cprmnarr[i],cgrmnarr[i],sprmnarr[i],sgrmnarr[i],prmnarr[i],grmnarr[i]]
   idxnonzero = WHERE(allz GT 0.0, countnonzero)
   IF countnonzero GT 0 THEN BEGIN
      thisminz = MIN( allz[idxnonzero], MAX=thismaxz )
      x_range[1] = x_range[1] > thismaxz
      x_range[0] = x_range[0] < thisminz
   ENDIF
ENDFOR
x_range[1] = x_range[1] > 40.0  ; boost x-axis bound to 50 if less than that

ENDIF ELSE BEGIN            ;==========================================

; didn't supply an IDL SAVE file type, so instead just read the
; supplied text file to get the profiles

OPENR, r_lun, file, /GET_LUN, ERROR=err
PRINT, 'error code', err

PRINT, ' '
PRINT, 'reading from file:', file

a_line = ' '
height   = ' '
num_events = 0
event_data = ''
have_errbars = 0

WHILE (EOF(r_lun) NE 1) DO BEGIN  ; *****loop through all records*****
  READF, r_lun, event_data
  num_events = num_events+1
  parsed = strsplit( event_data, '|', /extract )
  height = parsed[0]
  print, "Height = ", height
  IF num_events EQ 1 THEN $
     IF N_ELEMENTS(parsed) GT 10 THEN have_errbars = 1
ENDWHILE
PRINT, 'total number of levels = ', num_events

FREE_LUN, r_lun

hgtarr = FLTARR(num_events)
prmnarr = FLTARR(num_events) & cprmnarr = prmnarr & sprmnarr = prmnarr
grmnarr = FLTARR(num_events) & cgrmnarr = grmnarr & sgrmnarr = grmnarr
samples = LONARR(num_events) & csamples = samples & ssamples = samples
IF have_errbars EQ 1 THEN BEGIN
   cprsdarr = prmnarr & sprsdarr = prmnarr & prsdarr = prmnarr
   cgrsdarr = grmnarr & sgrsdarr = grmnarr & grsdarr = prmnarr
ENDIF

OPENR, r_lun, file, /GET_LUN, ERROR=err

FOR i=0, num_events-1  DO BEGIN
   READF, r_lun, event_data
   parsed = strsplit( event_data, '|', /extract )
   hgtarr[i] = float(parsed[0])
   IF i GT 0 and hgtarr[i]+hgtarr[i-1] EQ 0.0 THEN BEGIN
      missing_hgt_zero = 1
      ibreak = i
   ENDIF

   IF have_errbars EQ 0 THEN BEGIN
      cprmnarr[i] = float( parsed[1] )
      cgrmnarr[i] = float( parsed[2] )
      csamples[i] =  long( parsed[3] )

      sprmnarr[i] = float( parsed[4] )
      sgrmnarr[i] = float( parsed[5] )
      ssamples[i] =  long( parsed[6] )

      prmnarr[i] = float( parsed[7] )
      grmnarr[i] = float( parsed[8] )
      samples[i] =  long( parsed[9] )
   ENDIF ELSE BEGIN
      cprmnarr[i] = float( parsed[1] )
      cgrmnarr[i] = float( parsed[2] )
      cprsdarr[i] = float( parsed[3] )
      cgrsdarr[i] = float( parsed[4] )
      csamples[i] =  long( parsed[5] )

      sprmnarr[i] = float( parsed[6] )
      sgrmnarr[i] = float( parsed[7] )
      sprsdarr[i] = float( parsed[8] )
      sgrsdarr[i] = float( parsed[9] )
      ssamples[i] =  long( parsed[10] )

      prmnarr[i] = float( parsed[11] )
      grmnarr[i] = float( parsed[12] )
      prsdarr[i] = float( parsed[13] )
      grsdarr[i] = float( parsed[14] )
      samples[i] =  long( parsed[15] )
   ENDELSE

   thismaxz = MAX( [cprmnarr[i],cgrmnarr[i],sprmnarr[i],sgrmnarr[i],prmnarr[i],grmnarr[i]] )
   allminz = [cprmnarr[i],cgrmnarr[i],sprmnarr[i],sgrmnarr[i],prmnarr[i],grmnarr[i]]
   idxnonzero = WHERE(allminz GT 0.0)
   thisminz = MIN( allminz[idxnonzero] )
   IF (i EQ 0) THEN BEGIN ; find the bounds for the plot axes
      x_range[1] = thismaxz
      x_range[0] = thisminz
   ENDIF ELSE BEGIN
      x_range[1] = x_range[1] > thismaxz
      x_range[0] = x_range[0] < thisminz
   ENDELSE
ENDFOR

FREE_LUN, r_lun
ENDELSE            ;==========================================

; # # # # # # # # # # # # # # # # # # # # # # # # # # # #

; Build the mean Z profile plot panel
device, decomposed = 0
LOADCT, 2
;!P.FONT=1
;device, set_font='Helvetica Bold', /TT_FONT

Window, xsize=800, ysize=700, TITLE = "Dataset mean vertical profiles"+plotlabeladd

;h2plot = (findgen(num_events) + 1) * 1.5
h2plot = hgtarr[0:num_events-1]

; figure out the height steps
hgtstep = MIN(hgtarr[1:num_events-1]-hgtarr[0:num_events-2])
print, "Height steps: ", hgtstep
; figure out the y-axis range.  Use the lesser of hgtarr[num_events-1]*2.0
; and 20 km if result>20.
prop_max_y = hgtarr[num_events-1]+hgtstep

; figure out whether we have height AGL or height above/below BB
IF hgtarr[0] GT 0.0 THEN ytitle = 'Height Level, km AGL' $
ELSE ytitle = 'Height Above BB, km'

; figure out x axis range from data min, max
xaxmin = FIX((x_range[0])/5.0) * 5
IF have_errbars EQ 1 THEN xaxmin=xaxmin-5  ; leave room for error bars
xaxmax = FIX((x_range[1]+5.0)/5.0) * 5 + 5.0  ; added 5 to leave legend room
print, "X axis min, max: ", xaxmin,xaxmax

basep = plot( XRANGE=[15,45], YRANGE=[hgtarr[0],20 < prop_max_y], /NODATA, $
              XCOLOR = 0, YCOLOR = 0, XSTYLE=1, YSTYLE=1, $
              YTICKINTERVAL=hgtstep, YMINOR=1, xthick=1, ythick=1, $
              XTITLE='Level Mean Reflectivity, dBZ', YTITLE=ytitle )

IF missing_hgt_zero EQ 0 THEN BEGIN
  ; plot profiles without a break at height 0.0
   idx2plot = WHERE(samples GT 0, nlev2plot)
   IF nlev2plot GT 1 THEN BEGIN
      prplot0 = PLOT( OVERPLOT, prmnarr[idx2plot], h2plot[idx2plot], 'r3' )
      grplot0 = PLOT( OVERPLOT, grmnarr[idx2plot], h2plot[idx2plot], 'g3' )
   ENDIF ELSE BEGIN
      IF nlev2plot EQ 1 THEN BEGIN
         IF idx2plot EQ 0 THEN offsetbar = 0.15 ELSE offsetbar = -0.15
         proff = offsetbar*2 
         groff = offsetbar
         prplot0 = PLOT( OVERPLOT, prmnarr[idx2plot], h2plot[idx2plot]+proff, COLOR = 20, $
             psym=6, symsize=1
         grplot0 = PLOT( OVERPLOT, grmnarr[idx2plot], h2plot[idx2plot]+groff, COLOR = 70, $
             psym=6, symsize=1
      ENDIF
   ENDELSE

  ; plot the number of points at each level just to the right of level's max
  ; Z value between PR and GR
   maxmnarrs = (prmnarr<grmnarr) - 2
   h2plot2 = h2plot
   h2plot2[0] = h2plot[0] + 0.2  ; offset the 1st number's location above x-axis
;   XYOUTS, maxmnarrs+0.5, h2plot2, COLOR = 20, $
;        '('+STRING(samples, FORMAT='(I0)')+')' ;, charsize=chsiz, font=fontset
   XYOUTS, maxmnarrs[idx2plot], (h2plot2[idx2plot]-0.2) > h2plot2[idx2plot[0]], $
           COLOR = 0, charsize=1.5, charthick=2, $
           '('+STRING(samples, FORMAT='(I0)')+')' ;, charsize=chsiz, font=fontset
  ; plot the profile for stratiform rain type points
   idx2plot = WHERE(ssamples GT 0, nlev2plots)
   IF nlev2plots GT 1 THEN BEGIN
      PLOT( OVERPLOT, sprmnarr[idx2plot], h2plot[idx2plot], COLOR = 20, LINESTYLE=4, thick=2
      PLOT( OVERPLOT, sgrmnarr[idx2plot], h2plot[idx2plot], COLOR = 70, LINESTYLE=4, thick=2
   ENDIF ELSE BEGIN
      IF nlev2plots EQ 1 THEN BEGIN
         IF idx2plot EQ 0 THEN offsetbar = 0.15 ELSE offsetbar = -0.15
         proff = offsetbar*2 
         groff = offsetbar
         PLOT( OVERPLOT, sprmnarr[idx2plot], h2plot[idx2plot]+proff, COLOR = 20, $
             psym=4, symsize=1
         PLOT( OVERPLOT, sgrmnarr[idx2plot], h2plot[idx2plot]+groff, COLOR = 70, $
             psym=4, symsize=1
      ENDIF
   ENDELSE
   maxmnarrs = sprmnarr<sgrmnarr  ;(sprmnarr+sgrmnarr)/2.0
   XYOUTS, maxmnarrs[idx2plot], (h2plot2[idx2plot]) > h2plot2[idx2plot[0]], $
           COLOR = 0, charsize=1.5, charthick=2, $
           '('+STRING(ssamples, FORMAT='(I0)')+')' ;, charsize=chsiz, font=fontset
  ; plot the profile for convective rain type points
   idx2plot = WHERE(csamples GT 0, nlev2plotc)
   IF nlev2plotc GT 1 THEN BEGIN
      PLOT( OVERPLOT, cprmnarr[idx2plot], h2plot[idx2plot], COLOR = 20, LINESTYLE=2, thick=2
      PLOT( OVERPLOT, cgrmnarr[idx2plot], h2plot[idx2plot], COLOR = 70, LINESTYLE=2, thick=2
   ENDIF ELSE BEGIN
      IF nlev2plotc EQ 1 THEN BEGIN
         IF idx2plot EQ 0 THEN offsetbar = 0.15 ELSE offsetbar = -0.15
         proff = offsetbar*2 
         groff = offsetbar
         PLOT( OVERPLOT, cprmnarr[idx2plot], h2plot[idx2plot]+proff, COLOR = 20, $
             psym=1, symsize=1
         PLOT( OVERPLOT, cgrmnarr[idx2plot], h2plot[idx2plot]+groff, COLOR = 70, $
             psym=1, symsize=1
      ENDIF
   ENDELSE
   maxmnarrs = cprmnarr>cgrmnarr   ;(cprmnarr+cgrmnarr)/2.0
   XYOUTS, maxmnarrs[idx2plot], h2plot2[idx2plot]+0.2, COLOR = 0, charsize=1.5, charthick=2, $
        '('+STRING(csamples, FORMAT='(I0)')+')' ;, charsize=chsiz, font=fontset
  ; plot the error bars for the 'any' category, offsetting vertically between PR, GV
   FOR ilev = 0,N_ELEMENTS(idx2plot)-1 DO BEGIN
      IF ilev EQ 0 THEN offsetbar = 0.15 ELSE offsetbar = -0.15
      proff = offsetbar*2 
      groff = offsetbar
      vertpospr=[h2plot[idx2plot[ilev]]+proff,h2plot[idx2plot[ilev]]+proff]
      horzpospr=[ prmnarr[idx2plot[ilev]]-prsdarr[idx2plot[ilev]], $
                  prmnarr[idx2plot[ilev]]+prsdarr[idx2plot[ilev]] ]
;      PLOT( OVERPLOT, horzpospr, vertpospr, COLOR = 20, thick=1
;      PLOT( OVERPLOT, [horzpospr[0]], [vertpospr[0]], PSYM=5, COLOR = 20
;      PLOT( OVERPLOT, [horzpospr[1]], [vertpospr[0]], PSYM=5, COLOR = 20
      vertposgr=[h2plot[idx2plot[ilev]]+groff,h2plot[idx2plot[ilev]]+groff]
      horzposgr=[ grmnarr[idx2plot[ilev]]-grsdarr[idx2plot[ilev]], $
                  grmnarr[idx2plot[ilev]]+grsdarr[idx2plot[ilev]] ]
;      PLOT( OVERPLOT, horzposgr, vertposgr, COLOR = 70, thick=1
;      PLOT( OVERPLOT, [horzposgr[0]], [vertposgr[0]], PSYM=5, COLOR = 70
;      PLOT( OVERPLOT, [horzposgr[1]], [vertposgr[0]], PSYM=5, COLOR = 70
   ENDFOR
ENDIF

xoffnorm=-0.1
xyouts, 0.84+xoffnorm, 0.85, prDpr+' (ET<3)', COLOR = 20, /NORMAL, CHARSIZE=1.5
xyouts, 0.84+xoffnorm, 0.825, 'GR (ET<3)', COLOR = 70, /NORMAL, CHARSIZE=1.5
IF nlev2plot EQ 1 THEN BEGIN
   plots, 0.81+xoffnorm, 0.855, COLOR = 20, /NORMAL, psym=6, symsize=1
   plots, 0.81+xoffnorm, 0.83, COLOR = 70, /NORMAL, psym=6, symsize=1
ENDIF ELSE BEGIN
   plots, [0.79+xoffnorm,0.83+xoffnorm], [0.855,0.855], COLOR = 20, /NORMAL, thick=3
   plots, [0.79+xoffnorm,0.83+xoffnorm], [0.83,0.83], COLOR = 70, /NORMAL, thick=3
ENDELSE

xyouts, 0.84+xoffnorm, 0.8, prDpr+' (3<ET<6)', COLOR = 20, /NORMAL, CHARSIZE=1.5
xyouts, 0.84+xoffnorm, 0.775, 'GR (3<ET<6)', COLOR = 70, /NORMAL, CHARSIZE=1.5
IF nlev2plots EQ 1 THEN BEGIN
   plots, 0.81+xoffnorm, 0.805, COLOR = 20, /NORMAL, psym=4, symsize=1
   plots, 0.81+xoffnorm, 0.78, COLOR = 70, /NORMAL, psym=4, symsize=1
ENDIF ELSE BEGIN
   plots, [0.79+xoffnorm,0.83+xoffnorm], [0.805,0.805], COLOR = 20, /NORMAL, LINESTYLE=4, thick=3
   plots, [0.79+xoffnorm,0.83+xoffnorm], [0.78,0.78], COLOR = 70, /NORMAL, LINESTYLE=4, thick=3
ENDELSE

xyouts, 0.84+xoffnorm, 0.75, prDpr+' (ET>6)', COLOR = 20, /NORMAL, CHARSIZE=1.5
xyouts, 0.84+xoffnorm, 0.725,'GR (ET>6)', COLOR = 70, /NORMAL, CHARSIZE=1.5
IF nlev2plotc EQ 1 THEN BEGIN
   plots, 0.81+xoffnorm, 0.755, COLOR = 20, /NORMAL, psym=1, symsize=1
   plots, 0.81+xoffnorm, 0.73, COLOR = 70, /NORMAL, psym=1, symsize=1
ENDIF ELSE BEGIN
   plots, [0.79+xoffnorm,0.83+xoffnorm], [0.755,0.755], COLOR = 20, /NORMAL, LINESTYLE=2, thick=3
   plots, [0.79+xoffnorm,0.83+xoffnorm], [0.73,0.73], COLOR = 70, /NORMAL, LINESTYLE=2, thick=3
ENDELSE

;xyouts, 0.6, 0.89, plotlabel, COLOR = 0, /NORMAL, CHARSIZE=2 ;, CHARTHICK=2

noPlot:
end
