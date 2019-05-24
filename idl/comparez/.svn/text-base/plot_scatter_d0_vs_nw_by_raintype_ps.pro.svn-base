;+
; Copyright © 2014, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; DESCRIPTION:
;       Contains two modules used to produce a multiplot with scatter plots of
;       Dm vs. Nw for PR and GV data, one for each breakout of the data by rain
;       type and surface type.  Output is to a Postscript file whose name is
;       supplied as the 'file' parameter.
;
;       Primary Module: plot_scatter_d0_vs_nw_by_raintype_ps, file, title, siteID, $
;                            prdm_in, gvdm_in, prnw_in, gvnw_in, $
;                            raintype_in, bbprox_in, npts, idxByBB, $
;                            SAT_INSTR=sat_instr, HEIGHTS=heights_in, $
;                            GR_DM_D0=GR_DM_D0
;
;       Internal Module: plot_d0_nw_scat_ps, pos, sub_title, sourceID, $
;                            xdata, ydata, ndata, HEIGHTS=hgtStruc, DM_D0=DM_D0
;
; HISTORY:
;       Bob Morris/GPM GV (SAIC), July, 2014
;       - Created from plot_dsd_scatter_by_raintype_ps.pro.
;       Bob Morris/GPM GV (SAIC), September, 2014
;       - Made plotted symbols blue and of varying size according to the number
;         of plotted points, in plot_d0_nw_scat_ps.
;       Bob Morris/GPM GV (SAIC), 01/15/15
;       - Added capability to color-code scatter points by height of samples.
;       - Added optional GR_DM_D0 parameter to control labeling of GR Dm or D0.
;       Bob Morris/GPM GV (SAIC), 01/20/15
;       - Fixed issue of HEIGHTS array in structure not being updated in loop.
;       08/18/15, Bob Morris/GPM GV (SAIC)
;       - Changed legend for color-coded heights to just use black text with a
;         symbol sample in color.
;       - Modified to plot color-code labels even when the target panel for the
;         labeling has no data points present.
;       09/24/15, Bob Morris/GPM GV (SAIC)
;       - Changed Nw plot range to 2-8 from 0-6.
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;------------------------------------------------------------------------------

pro plot_d0_nw_scat_ps, pos, sub_title, sourceID, xdata, ydata, ndata, $
                        HEIGHTS=hgtStruc, DM_D0=DM_D0

ncolor=255
bgcolor=ncolor-1
IF (N_PARAMS() EQ 6) THEN symsize=(0.65/( alog10(ndata) > 0.1 ) > 0.25) < 1.0 $
ELSE symsize=0.5

IF N_ELEMENTS(DM_D0) EQ 0 THEN x_title = sourceID + ' Dm, mm' $
ELSE x_title = sourceID + ' '+DM_D0+', mm'
y_title = sourceID + ' log10(Nw)'
minX=0.0 & maxX=5.0
minY=2.0 & maxY=8.0

IF ( N_PARAMS() GT 3 ) THEN BEGIN

   ; --- Define symbol as filled circle
   A = FINDGEN(17) * (!PI*2/16.)
   USERSYM, COS(A), SIN(A), /FILL

   plot,POSITION=pos, [minX,maxX], [minY,maxY], /NODATA, $ ;xdata[0:ndata-1],ydata[0:ndata-1],$
       xticklen=+0.04, yticklen=0.04,/noerase, $
       xticks=5,xrange=[minX,maxX],yrange=[minY,maxY], $
       yticks=6, xminor=5,yminor=5, $
       title=sub_title, $
       ytitle=y_title, $
       xtitle=x_title, $
       color=ncolor,charsize=1.5

  ; now add the data points to the plot
   IF N_ELEMENTS(hgtStruc) EQ 0 THEN BEGIN
       oplot,xdata[0:ndata-1],ydata[0:ndata-1], psym=8, symsize=symsize, color=30 ;220
   ENDIF ELSE BEGIN
     ; first plot the points' backgrounds in gray with a larger diameter to
     ; allow light color points to be seen in the white plot area
      oplot, xdata[0:ndata-1], ydata[0:ndata-1], psym=8, $
             symsize=symsize*1.5, color=bgcolor
     ; run a histogram of sample heights to bin them into 0.25 km layers
      hgthist = HISTOGRAM(hgtStruc.HEIGHTS, BINSIZE=0.25, MIN=0.0, MAX=20.0, $
                          REVERSE_INDICES=hgtbinidx, locations=hgtofbin)
     ; identify indices of histo bins with samples at those height values
      idxhistnotzero = WHERE(hgthist GT 0, countbinsok)
     ;print, "Height: ", (hgtStruc.LABELS)[idxhistnotzero]
     ;print, "N in bin: ", hgthist[idxhistnotzero]
     ;print, "bincolors: ", (hgtStruc.bincolor)[idxhistnotzero]
     ; extract xdata and ydata values for each bin and plot its points in
     ; the assigned color
      for ibin=0,countbinsok-1 do begin
         xbin = xdata[ hgtbinidx[hgtbinidx[idxhistnotzero[ibin]] : $
                       hgtbinidx[idxhistnotzero[ibin]+1]-1]]
         ybin = ydata[ hgtbinidx[hgtbinidx[idxhistnotzero[ibin]] : $
                       hgtbinidx[idxhistnotzero[ibin]+1]-1]]
        ; now plot the point in its assigned height color
         oplot, xbin, ybin, psym=8, symsize=symsize, $
                color=(hgtStruc.bincolor)[idxhistnotzero[ibin]]
      endfor
      IF (hgtStruc.PLOTLAB NE -1) THEN BEGIN
         for ibin = hgtStruc.PLOTLAB, N_ELEMENTS(hgtStruc.LABELS)-1 do begin
           ; plot height/color values in a stack on the right of the two
           ; sets of scatter panel pairs.  First plot text in black, then the
           ; symbol samples in color to their left, outlined in black
            posStart = pos[3] - (pos[3]-pos[1])/4.0  ; start 3/4 way up lower panel
            xyouts, pos[2]+0.04, posStart+0.0125*ibin, $
                    STRING((hgtStruc.LABELS)[ibin],FORMAT='(F5.2)')+" km", $
                    charsize=0.75, color=ncolor, alignment=0, /normal
            plots, pos[2]+0.03, posStart+0.005+0.0125*ibin, COLOR=ncolor, $
                   PSYM=8, SYMSIZE=1.2, /normal ;, /noerase
            plots, pos[2]+0.03, posStart+0.005+0.0125*ibin, COLOR=(hgtStruc.bincolor)[ibin], $
                   PSYM=8, SYMSIZE=1.1, /normal ;, /noerase
         endfor
      ENDIF
   ENDELSE
 
;   oplot,[xymin,xymax],[xymin,xymax],color=ncolor

   if ndata ge 0 and ndata lt 10 then fmt='(i1)'
   if ndata ge 10 and ndata lt 100 then fmt='(i2)'
   if ndata ge 100 and ndata lt 1000 then fmt='(i3)'
   if ndata ge 1000 and ndata lt 10000 then fmt='(i4)'
   if ndata ge 10000 and ndata lt 100000 then fmt='(i5)'

   xyouts,pos[0]+0.018, pos[3]-0.02, "Points = "+string(ndata, $
      format=fmt)+"", charsize=0.65,color=ncolor,alignment=0,/normal
            
ENDIF ELSE BEGIN

   ;print, 'Plotting empty panel for ', sub_title
   plot,POSITION=pos,[minX,maxX],[minY,maxY], /nodata, $
       xticklen=+0.04, yticklen=0.04,/noerase, $
       xticks=3,xrange=[minX,maxX],yrange=[minY,maxY], $
       yticks=3, xminor=5,yminor=5, $
       title=sub_title, $
       ytitle=y_title, $
       xtitle=x_title, $
       color=ncolor,charsize=0.7
   xyouts,pos[0]+0.018, pos[3]-0.1, "NO DATA POINTS IN CATEGORY", $
      charsize=0.75,color=ncolor,alignment=0,/normal

ENDELSE
end                     

;------------------------------------------------------------------------------


pro plot_scatter_d0_vs_nw_by_raintype_ps, file, title, siteID, prdm_in, $
                             gvdm_in, prnw_in, gvnw_in, raintype_in, $
                             bbprox_in, npts, idxByBB, SAT_INSTR=sat_instr, $
                             HEIGHTS=heights_in, GR_DM_D0=GR_DM_D0

s2ku = KEYWORD_SET( s2ku_in )

; Set up color table
;
common colors, r_orig, g_orig, b_orig, r_curr, g_curr, b_curr ;load color table
loadct,33, /SILENT
ncolor=!d.table_size-1
ncolor=255
bgcolor=ncolor-1
red=bytarr(256) & green=bytarr(256) & blue=bytarr(256)
red=r_curr & green=g_curr & blue=b_curr
red(0)=255 & green(0)=255 & blue(0)=255
red(bgcolor)=150 & green(bgcolor)=150 & blue(bgcolor)=150  ;gray background
red(ncolor)=0 & green(ncolor)=0 & blue(ncolor)=0 
tvlct,red,green,blue

xyouts, 0.5, 9.6/10., title, alignment=0.5, color=ncolor, /normal, $
        charsize=1., Charthick=1.5
 
bblevstr = ['Unknown BB', 'Below BB', 'Within BB', 'Above BB']
typestr = ['Any Type ', 'Stratiform, ', 'Convective, ']

xs = 2.5/8.  &  ys = 2.5/10.        ; individual plot x,y size
x0 = 1.2/8.  &  y0 = 0.5/10.+ys     ; starting margins on page
x00 = 0.7/8.  &  y00 = 0.6/10.      ; between-plot spacing

pos = fltarr(4)
increment = 1    ; set up for legacy behavior
catend = 1

; extract the subarrays at the below-BB layer only
proxim = 1     ; 0= 'Unknown', 1=' Below', 2='Within', 3=' Above'
IF ( npts[0] GT 0 ) THEN BEGIN
   idxthislev = idxByBB[0,0:npts[0]-1]
   prdm=prdm_in[idxthislev]
   gvdm=gvdm_in[idxthislev]
   prnw=prnw_in[idxthislev]
   gvnw=gvnw_in[idxthislev]
   raintype = raintype_in[idxthislev]
   bbprox = bbprox_in[idxthislev]
   IF N_ELEMENTS(heights_in) NE 0 THEN heights = heights_in[idxthislev]
ENDIF

IF N_ELEMENTS(heights) NE 0 THEN BEGIN
  ; run a histogram of sample heights to bin them into 0.25 km layers
   hgthist = HISTOGRAM(heights, BINSIZE=0.25, MIN=0.0, MAX=20.0, $
                       REVERSE_INDICES=hgtbinidx, locations=hgtofbin)
  ; identify indices of histo bins with values and assign their colors
   idxhistnotzero = WHERE(hgthist GT 0, countbinsok)
   IF countbinsok GT 0 THEN BEGIN
      clrstep = 254/(MAX(idxhistnotzero)+1)  ; set step to use the full range of colors
      idxclrrange = INDGEN(MAX(idxhistnotzero)+1)  ; number of colors in range
      bincolor = idxclrrange*clrstep < 254; color index of each of the above
     ; height values for each color over range of data
      labels = hgtofbin[0:MAX(idxhistnotzero)]
     ; set plotlab to the height label of the first histo bin with data
     ; for panel(s) where we want to plot labels, or -1 if not labeling
      plotlab = -1
;print, "ALL LABELS: ",labels[MIN(idxhistnotzero):MAX(idxhistnotzero)]
   ENDIF ELSE MESSAGE, "Empty histogram of sample heights."
ENDIF

for i=0,catend do begin     ;row, count from bottom -- also, bbprox type

 ; don't indicate Ku-corrected for within-BB plots
  IF ( s2ku ) THEN BEGIN
     IF ( proxim EQ 2 ) THEN s2ku4sca = 0 ELSE s2ku4sca = s2ku
  ENDIF ELSE s2ku4sca = 0

  CASE i OF
     0 : BEGIN
            prvar=gvnw
            gvvar=gvdm
            ;minXY=0.0
            ;maxXY=3.0
            sourceID = siteID
            IF N_ELEMENTS(GR_DM_D0) NE 0 THEN dm_or_d0 = GR_DM_D0 $
            ELSE dm_or_d0 = 'D0'   ; default to D0 for GR, if not given
         END
     1 : BEGIN
            prvar=prnw
            gvvar=prdm
            ;maxX=3.0
            ;maxY=6.0
            sourceID = sat_instr
            dm_or_d0 = 'Dm'        ; default to Dm for DPR
         END
  ENDCASE

  for j=0,1 do begin   ;column, count from left -- also, strat/conv rain type index
    raincat = j+1   ; 1=Stratiform, 2=Convective
    x1=x0+j*(xs+x00)
    y1=y0+i*(ys+y00)  
    x2=x1+xs
    y2=y1+ys          
    pos[*] = [x1,y1,x2,y2]
    IF i EQ catend THEN subtitle = typestr[raincat]+bblevstr[proxim] $
                   ELSE subtitle = ''
    IF ( npts[0] GT 0 ) THEN BEGIN
      idxsub = WHERE( bbprox EQ proxim AND raintype EQ raincat, nfound )
      IF ( nfound GT 0 ) THEN BEGIN
         prsub = prvar[idxsub] & gvsub = gvvar[idxsub]
         IF N_ELEMENTS(heights) NE 0 THEN BEGIN
           ; set up to add height/color annotations if on convective/GR plot
            IF (i EQ 0) AND (j EQ 1) THEN plotlab = MIN(idxhistnotzero)
            hgtstruc = { HEIGHTS:heights[idxsub], $
                         BINCOLOR:bincolor,       $
                         LABELS:labels,           $
                         PLOTLAB:plotlab }
         ENDIF
         plot_d0_nw_scat_ps, pos, subtitle, sourceID, gvsub, prsub, nfound, $
                             HEIGHTS=hgtstruc, DM_D0=dm_or_d0
         IF N_ELEMENTS(heights) NE 0 THEN plotlab = -1
      ENDIF ELSE BEGIN
         print, 'No points in rain category ', typestr[raincat], bblevstr[proxim]
         plot_d0_nw_scat_ps, pos, subtitle, sourceID
      ENDELSE
    ENDIF ELSE BEGIN
     ; print, 'no points at BB proximity level ', bblevstr[proxim]
      plot_d0_nw_scat_ps, pos, subtitle, sourceID
    ENDELSE
  endfor

endfor

;device,/close
;SET_PLOT, orig_device
end
