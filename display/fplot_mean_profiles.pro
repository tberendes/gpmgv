function fplot_mean_profiles, file, plotlabel, INSTRUMENT=instrument, $
                              CAT_NAMES=cat_names, LEGEND_XY=leg_xy_in

; HISTORY
; -------
; 07/28/15 - Morris, GPM GV (SAIC)
; - Created from plot_mean_profiles.pro.  Modified IDL graphic calls to use
;   newer PLOT, TEXT, and LEGEND functions.
; - Added CAT_NAMES parameter to allow non-default values for the 3 category
;   definitions to be specified.
; - Added LEGEND_XY parameter to allow non-default positioning of the legend.
; - Made into a FUNCTION, returns the reference to the PLOTted object if one is
;   able to be created, otherwise returns -1.
; 12/03/15 - Morris, GPM GV (SAIC)
; - Added sampThresh to specify where there are too few samples to plot
; 03/06/17 - Morris, GPM GV (SAIC)
; - Added checks for existence of plot types to eliminate errors in creation of
;   legend entries when associated plot type is not present.

basep = -1  ; initialize return value for failed
sampThresh = 5  ; must exceed this minimum number of samples to plot the level

IF N_ELEMENTS(instrument) EQ 1 THEN prDpr = instrument ELSE prDpr = 'DPR'

if N_PARAMS() EQ 1 THEN plotlabeladd = '' ELSE plotlabeladd = ': ' +plotlabel
x_range = FLTARR(2)     ; index0 is min index1 is max
y_range = FLTARR (2)    ; index0 is min index1 is max
missing_hgt_zero = 0    ; flag to indicate when data at height=0.0 is missing

IF N_ELEMENTS(cat_names) EQ 0 THEN catnames = ['All','Strat.','Conv.'] $
ELSE IF N_ELEMENTS(cat_names) EQ 3 THEN catnames = cat_names $
     ELSE message, "Expecting exactly 3 values in CAT_NAMES parameter."

IF N_ELEMENTS(leg_xy_in) EQ 0 THEN leg_xy = [0.43,0.83] $
ELSE IF N_ELEMENTS(leg_xy_in) EQ 2 THEN leg_xy = leg_xy_in $
     ELSE message, "Expecting exactly 2 values in LEGEND_XY parameter."

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

; set up the common plot axes, etc., no data plotted yet
basep = PLOT( prmnarr, h2plot, /NODATA, $
              XRANGE=[15,40], YRANGE=[hgtarr[0],20 < prop_max_y], $
              XCOLOR = 0, YCOLOR = 0, XSTYLE=1, YSTYLE=1, $
              YTICKINTERVAL=hgtstep, YMINOR=1, xthick=1, ythick=1, $
              XTITLE='Level Mean Reflectivity, dBZ', YTITLE=ytitle, $
              FONT_NAME='Helvetica', FONT_STYLE='Normal' )

  ; set a flag for which plot profiles exist: units place=Any/All,
  ; tens place=stratiform, hundreds place=convective
   plots4legend=0

  ; plot profiles for any/all
   idx2plot = WHERE(samples GT sampThresh, nlev2plot)
   IF nlev2plot GT 0 THEN plots4legend = plots4legend+1  ; yes, we have any/all
   IF nlev2plot GT 1 THEN BEGIN
      prplot0 = PLOT( /OVERPLOT, prmnarr[idx2plot], h2plot[idx2plot], 'g2', $
                      NAME = prDpr+' ('+catnames[0]+')' )
      grplot0 = PLOT( /OVERPLOT, grmnarr[idx2plot], h2plot[idx2plot], 'g3--', $
                      NAME = 'GR ('+catnames[0]+')' )
   ENDIF ELSE BEGIN
      IF nlev2plot EQ 1 THEN BEGIN
        ; move the first level's symbols up off the bottom x-axis
         IF idx2plot EQ 0 THEN offsetbar = 0.15 ELSE offsetbar = 0.0
        ; define a miniscule line segment at the single point's x,y location so that
        ; the line sample and plot name will be included in the legend.  Legend seems
        ; to require more than one point for inclusion of the plot's info.
         prx=[prmnarr[idx2plot],prmnarr[idx2plot]+0.0001]
         prgry = [h2plot[idx2plot],h2plot[idx2plot]] + offsetbar
         grx=[grmnarr[idx2plot],grmnarr[idx2plot]+0.0001]
         prplot0 = PLOT( /OVERPLOT, prx, prgry, $
                         'sg ', sym_size=1, sym_thick=2, sym_filled=0, $
                         NAME = '  '+prDpr+' ('+catnames[0]+')' )
         grplot0 = PLOT( /OVERPLOT, grx, prgry, $
                         'Dg ', sym_size=1, sym_thick=2, sym_filled=0, $
                         NAME = '  GR ('+catnames[0]+')' )
      ENDIF
   ENDELSE

  ; plot the number of points at each level just to the right of level's max
  ; Z value between PR and GR
   maxmnarrs = (prmnarr>grmnarr) ;- 2
   h2plot2 = h2plot
   h2plot2[0] = h2plot[0] + 0.2  ; offset the 1st number's location above x-axis
   t0 = TEXT( maxmnarrs[idx2plot], (h2plot2[idx2plot]-0.4) > h2plot2[idx2plot[0]], $
              '('+STRING(samples[idx2plot], FORMAT='(I0)')+')', /DATA, COLOR = 'green', $
              font_size=10, font_name='Helvetica' )


  ; plot the profiles for stratiform
   idx2plot = WHERE(ssamples GT sampThresh, nlev2plots)
   IF nlev2plots GT 0 THEN plots4legend = plots4legend+10  ; yes, we have strat.
   IF nlev2plots GT 1 THEN BEGIN
      prplot1 = PLOT( /OVERPLOT, sprmnarr[idx2plot], h2plot[idx2plot], 'b2', $
                      NAME = prDpr+' ('+catnames[1]+')' )
      grplot1 = PLOT( /OVERPLOT, sgrmnarr[idx2plot], h2plot[idx2plot], 'b--3', $
                      NAME = 'GR ('+catnames[1]+')' )
   ENDIF ELSE BEGIN
      IF nlev2plots EQ 1 THEN BEGIN
         IF idx2plot EQ 0 THEN offsetbar = 0.15 ELSE offsetbar = 0.0
         prx=[sprmnarr[idx2plot],sprmnarr[idx2plot]+0.0001]
         prgry = [h2plot[idx2plot],h2plot[idx2plot]] + offsetbar
         grx=[sgrmnarr[idx2plot],sgrmnarr[idx2plot]+0.0001]
         prplot1 = PLOT( /OVERPLOT, prx, prgry, 'sb ', sym_size=1, sym_thick=2, $
                        NAME = '  '+prDpr+' ('+catnames[1]+')' )
         grplot1 = PLOT( /OVERPLOT, grx, prgry, 'Db ', sym_size=1, sym_thick=2, $
                        NAME = '  GR ('+catnames[1]+')' )
      ENDIF
   ENDELSE
   maxmnarrs = sprmnarr>sgrmnarr  ;(sprmnarr+sgrmnarr)/2.0
   t1 = TEXT( maxmnarrs[idx2plot], (h2plot2[idx2plot]) > h2plot2[idx2plot[0]], $
              '('+STRING(ssamples[idx2plot], FORMAT='(I0)')+')', /DATA, COLOR = 'blue', $
              font_size=10, font_name='Helvetica' )


  ; plot the profile for Convective
   idx2plot = WHERE(csamples GT sampThresh, nlev2plotc)
   IF nlev2plotc GT 0 THEN plots4legend = plots4legend+100  ; yes, we have Conv.
   IF nlev2plotc GT 1 THEN BEGIN
      prplot2 = PLOT( /OVERPLOT, cprmnarr[idx2plot], h2plot[idx2plot], 'r2', $
                      NAME = prDpr+' ('+catnames[2]+')' )
      grplot2 = PLOT( /OVERPLOT, cgrmnarr[idx2plot], h2plot[idx2plot], 'r--3', $
                      NAME = 'GR ('+catnames[2]+')' )
   ENDIF ELSE BEGIN
      IF nlev2plotc EQ 1 THEN BEGIN
         IF idx2plot EQ 0 THEN offsetbar = 0.15 ELSE offsetbar = 0.0
         prx=[cprmnarr[idx2plot],cprmnarr[idx2plot]+0.0001]
         prgry = [h2plot[idx2plot],h2plot[idx2plot]] + offsetbar
         grx=[cgrmnarr[idx2plot],cgrmnarr[idx2plot]+0.0001]
         prplot2 = PLOT( /OVERPLOT, prx, prgry, 'sr ', sym_size=1, sym_thick=2, $
                         NAME = '  '+prDpr+' ('+catnames[2]+')' )
         grplot2 = PLOT( /OVERPLOT, grx, prgry, 'Dr ', sym_size=1, sym_thick=2, $
                         NAME = '  GR ('+catnames[2]+')' )
      ENDIF
   ENDELSE
   maxmnarrs = cprmnarr>cgrmnarr   ;(cprmnarr+cgrmnarr)/2.0
   t2 = TEXT( maxmnarrs[idx2plot], h2plot2[idx2plot]+0.2, $
              '('+STRING(csamples[idx2plot], FORMAT='(I0)')+')', /DATA, COLOR = 'red', $
              font_size=10, font_name='Helvetica' )


  ; plot the error bars for the under-3-km category, offsetting vertically between PR, GV
;   FOR ilev = 0,N_ELEMENTS(idx2plot)-1 DO BEGIN
;      IF ilev EQ 0 THEN offsetbar = 0.15 ELSE offsetbar = -0.15
;      proff = offsetbar*2 
;      groff = offsetbar
;      vertpospr=[h2plot[idx2plot[ilev]]+proff,h2plot[idx2plot[ilev]]+proff]
;      horzpospr=[ prmnarr[idx2plot[ilev]]-prsdarr[idx2plot[ilev]], $
;                  prmnarr[idx2plot[ilev]]+prsdarr[idx2plot[ilev]] ]
;      PLOT( /OVERPLOT, horzpospr, vertpospr, COLOR = 20, thick=1
;      PLOT( /OVERPLOT, [horzpospr[0]], [vertpospr[0]], PSYM=5, COLOR = 20
;      PLOT( /OVERPLOT, [horzpospr[1]], [vertpospr[0]], PSYM=5, COLOR = 20
;      vertposgr=[h2plot[idx2plot[ilev]]+groff,h2plot[idx2plot[ilev]]+groff]
;      horzposgr=[ grmnarr[idx2plot[ilev]]-grsdarr[idx2plot[ilev]], $
;                  grmnarr[idx2plot[ilev]]+grsdarr[idx2plot[ilev]] ]
;      PLOT( /OVERPLOT, horzposgr, vertposgr, COLOR = 70, thick=1
;      PLOT( /OVERPLOT, [horzposgr[0]], [vertposgr[0]], PSYM=5, COLOR = 70
;      PLOT( /OVERPLOT, [horzposgr[1]], [vertposgr[0]], PSYM=5, COLOR = 70
;   ENDFOR

; plot the Legend box, include the profiles that are present
CASE plots4legend OF
   111 : lgnd = LEGEND( TARGET=[prplot0,grplot0,prplot1,grplot1,prplot2,grplot2], $
                        position = leg_xy, /NORMAL, $
                        ;/AUTO_TEXT_COLOR, $
                        font_size=10, font_name='Helvetica' )
   110 : lgnd = LEGEND( TARGET=[prplot1,grplot1,prplot2,grplot2], $
                        position = leg_xy, /NORMAL, $
                        ;/AUTO_TEXT_COLOR, $
                        font_size=10, font_name='Helvetica' )
   101 : lgnd = LEGEND( TARGET=[prplot0,grplot0,prplot2,grplot2], $
                        position = leg_xy, /NORMAL, $
                        ;/AUTO_TEXT_COLOR, $
                        font_size=10, font_name='Helvetica' )
   100 : lgnd = LEGEND( TARGET=[prplot2,grplot2], $
                        position = leg_xy, /NORMAL, $
                        ;/AUTO_TEXT_COLOR, $
                        font_size=10, font_name='Helvetica' )
    11 : lgnd = LEGEND( TARGET=[prplot0,grplot0,prplot1,grplot1], $
                        position = leg_xy, /NORMAL, $
                        ;/AUTO_TEXT_COLOR, $
                        font_size=10, font_name='Helvetica' )
    10 : lgnd = LEGEND( TARGET=[prplot1,grplot1], $
                        position = leg_xy, /NORMAL, $
                        ;/AUTO_TEXT_COLOR, $
                        font_size=10, font_name='Helvetica' )
     1 : lgnd = LEGEND( TARGET=[prplot0,grplot0], $
                        position = leg_xy, /NORMAL, $
                        ;/AUTO_TEXT_COLOR, $
                        font_size=10, font_name='Helvetica' )
  ELSE : message, "No plots, therefore no legend.", /INFO
ENDCASE

noPlot:
return, basep
end
