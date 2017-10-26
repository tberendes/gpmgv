;===============================================================================
;+
; Copyright © 2014, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; dpr2gmi_rainrate_comparisons.pro     Morris/SAIC/GPM_GV    Oct. 2014
;
; DESCRIPTION
; -----------
; Performs a case-by-case statistical analysis of orbit-match GMI and DPR
; rain rate from data contained in a geo-match netCDF file. 
; GMI rainrate is the near-surface rain rate stored in the netCDF file and
; originates within the 2A-GPROF product.
;
; INTERNAL MODULES
; ----------------
; 1) dpr2gmi_rainrate_comparisons - Main procedure called by user.  Checks
;                                  input parameters and sets defaults.
;
; 2) dpr2gmi_rr_plots - Workhorse procedure to read data, compute statistics,
;                      create vertical profile, histogram, scatter plots, and
;                      tables of DPR-GMI rainrate differences, and display DPR
;                      and GMI rain rate PPI plots in an animation sequence.
;
; HISTORY
; -------
; 10/16/14 Morris, GPM GV, SAIC
; - Created from pr2tmi_rainrate_comparisons.pro
;
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;===============================================================================
;
; MODULE 1:  dpr2gmi_rr_plots
;
; DESCRIPTION
; -----------
; Reads GMI and DPR rainrate, and spatial fields from a user-selected DPR2GMI
; matchup netCDF file, builds index arrays of categories rain type. 
; Computes mean GMI-DPR rainrate differences for each of the 3 underlying
; surface type categories and reports the results in a table to stdout.
; Also produces graphs of the Probability Density Function and scatter plots
; of GMI and DPR rainrate for each of these 3 surface types where data exists
; for that type, for each of 3 rain type categories: Any, Stratiform, and
; Convective. 
;
; Also produces a single image of GMI rainrate plotted on a map background,
; or an animation loop of GMI, DPR, and Combined GMI/DPR rainrate images either
; on a map or in a simple ray vs. scan plot.
;
; If PS_DIR is specified then the output is to a Postscript file under ps_dir,
; otherwise all output is to the screen.  When outputting to Postscript, the
; animation is still to the screen but the PDF and scatter plots go only to the
; Postscript device, as well as a copy of each image displayed in the static
; plot or the the animation loop. If b_w is set, then the PDF plots in the
; Postscript output will be black and white, otherwise they are in color.
;

FUNCTION dpr2gmi_rr_plots, mygeomatchfile, looprate, windowsize, $
                          POP_THRESHOLD=pop_threshold, RR_CUT=RRcut, $
                          hideTotals, BLANK_REJECTS=blank_rejects, $
                          PS_DIR=ps_dir, B_W=b_w, ANIMATE=animate

; "include" file for read_geo_match_netcdf() structs returned
@geo_match_nc_structs.inc

; "include" file for DPR data constants
@pr_params.inc

bname = file_basename( mygeomatchfile )
prlen = strlen( bname )
parsed = STRSPLIT( bname, '.', /extract )
yymmdd = parsed[1]
orbit = STRING(LONG(parsed[2]), FORMAT='(I0)')
version = parsed[3]

bbparms = {meanBB : 4.0, BB_HgtLo : -99, BB_HgtHi : -99}
IF N_ELEMENTS(RRcut) NE 1 THEN BEGIN
   RRcut = 0.1 ;10.      ; GMI/GV rainrate lower cutoff of points to use in mean diff. calcs.
   print, "Setting default rainrate cutoff to ", STRING(RRcut,FORMAT="(F0.2)"), " mm/h"
ENDIF
rangecut = 100.

; read the DPR-GMI matchup data from netCDF file into a structure
the_data=READ_DPR2GMI_MATCHUP(mygeomatchfile)
; check that a structure (IDL data type 8) is returned, not -1 as in read errors
szback = SIZE(the_data, /TYPE)
IF szback NE 8 THEN BEGIN
   print, "No data for case, skipping."
   GOTO, nextFile
ENDIF

 ; open a file to hold output stats to be appended to the Postscript file,
 ; if Postscript output is indicated
  IF KEYWORD_SET( ps_dir ) THEN BEGIN
     do_ps = 1
     temptext = ps_dir + '/pr_tmi_RR_stats_temp.txt'
     OPENW, tempunit, temptext, /GET_LUN
  ENDIF ELSE do_ps = 0

nscans = the_data.matchupmeta.num_scans
nrays = the_data.matchupmeta.num_rays
center_lat = the_data.matchupmeta.centerLat
center_lon = the_data.matchupmeta.centerLon
mapp = the_data.matchupmeta.Map_Projection

;-------------------------------------------------

; compute a rain type from the DPR convective fraction

rntype = the_data.numprrn & rntype[*,*] = -1      ; Initialize a 2-D rainType array to 'missing'
idxposrn = WHERE(the_data.numprrn GT 0, countnonzero)  ; prevent division by zero
IF countnonzero GT 0 THEN BEGIN
   convFrac = FLOAT(the_data.numprconv[idxposrn])/the_data.numprrn[idxposrn]
   idxthistype = WHERE(convFrac LE 0.3, countthistype)
   if countthistype GT 0 THEN rntype[idxposrn[idxthistype]] = 1     ; stratiform
   idxthistype = WHERE(convFrac GT 0.3 AND convFrac LE 0.7, countthistype)
   if countthistype GT 0 THEN rntype[idxposrn[idxthistype]] = 3     ; other/mixed
   idxthistype = WHERE(convFrac GT 0.7)
   if countthistype GT 0 THEN rntype[idxposrn[idxthistype]] = 2     ; convective
ENDIF

meanBBgr = -99.99


; - - - - - - - - - - - - - - - - - - - - - - - -

; build an array of sample point ranges from the map center
; via map projection x,y coordinates computed from lat and lon:

; initialize a gv-centered map projection for the ll<->xy transformations:
sMap = MAP_PROJ_INIT( mapp, center_latitude=center_lat, $
                      center_longitude=center_lon )
XY_km = map_proj_forward( the_data.GMIlongitude, the_data.GMIlatitude, map_structure=smap ) / 1000.
; dist is only needed for call to calc_geo_pr_gv_meandiffs_wght_idx,
; we'll reset values later down in the code
dist = SQRT( XY_km[0,*]^2 + XY_km[1,*]^2 )

; - - - - - - - - - - - - - - - - - - - - - - - -


; reassign surface type values (10,20,30) to (1,2,3).
sfcCat = the_data.gmisfcType
; get info from array of surface type
num_over_SfcType = LONARR(4)
idxmix = WHERE( sfcCat GE 13, countmix )  ; Coast
num_over_SfcType[3] = countmix
idxsea = WHERE( sfcCat EQ 1, countsea )  ; Ocean
num_over_SfcType[1] = countsea
idxland = WHERE( sfcCat GT 2 AND sfcCat LT 13, countland )    ; Land
num_over_SfcType[2] = countland

; define a structure to hold difference statistics computed within and returned
; by the called function calc_geo_pr_gv_meandiffs_wght_idx()
the_struc = { diffsset, $
              meandiff: -99.999, meandist: -99.999, fullcount: 0L,  $
              maxpr: -99.999, maxgv: -99.999, $
              meandiffc: -99.999, countc: 0L, $
              meandiffs: -99.999, counts: 0L, $
              AvgDifByHist: -99.999 $
            }

; - - - - - - - - - - - - - - - - - - - - - - - -

; Build the mean Z profile plot panel

orig_device = !D.NAME
orig_width = !D.X_CH_SIZE    ; save start-up character definitions for reset at end
orig_height = !D.Y_CH_SIZE
PDFTITLE = STRMID(yymmdd,0,4)+'-'+STRMID(yymmdd,4,2)+'-'+STRMID(yymmdd,6,2) $
           +', Orbit '+orbit+", "+version

IF ( do_ps EQ 1 ) THEN BEGIN
  ; set up postscript plot params. and file path/name
   cd, ps_dir
   b_w = keyword_set(b_w)
   add2nm = ''

   PSTITLE = 'GMIvsDPR.'+yymmdd+"."+orbit+"."+version
   PSFILEpdf = ps_dir+'/'+PSTITLE+'_PDF.ps'
   print, "Output sent to ", PSFILEpdf
   set_plot,/copy,'ps'
   device,filename=PSFILEpdf,/color,bits=8,/inches,xoffset=0.25,yoffset=2.55, $
          xsize=8.,ysize=8.

   ; Set up color table
   ;
   common colors, r_orig, g_orig, b_orig, r_curr, g_curr, b_curr ;load color table
   IF ( b_w EQ 0) THEN  LOADCT, 6, /SILENT  ELSE  LOADCT, 33, /SILENT
   ncolor=255
   red=bytarr(256) & green=bytarr(256) & blue=bytarr(256)
   red=r_curr & green=g_curr & blue=b_curr
   red(0)=255 & green(0)=255 & blue(0)=255
   red(1)=115 & green(1)=115 & blue(1)=115  ; gray for GV
   red(ncolor)=0 & green(ncolor)=0 & blue(ncolor)=0 
   tvlct,red,green,blue
   !P.COLOR=0 ; make the title and axis annotation black
   !X.THICK=2 ; make the ticks and borders thicker
   !Y.THICK=2 ; ditto
   !P.FONT=0 ; use the device fonts supplied by postscript

   IF ( b_w EQ 0) THEN BEGIN
     PR_COLR=200
     GV_COLR=60
     ST_LINE=1    ; dotted for stratiform
     CO_LINE=2    ; dashed for convective
   ENDIF ELSE BEGIN
     PR_COLR=ncolor
     GV_COLR=ncolor
     ST_LINE=0    ; solid for stratiform
     CO_LINE=1    ; dotted for convective
   ENDELSE

   CHARadj=0.75
   THIKadjPR=1.5
   THIKadjGV=0.5
   ST_THK=1
   CO_THK=1
ENDIF ELSE BEGIN
  ; set up x-window plot params.
   device, decomposed = 0
   LOADCT, 2, /SILENT
   Window, 0, xsize=700, ysize=700, TITLE = PDFTITLE, RETAIN=2
   PR_COLR=30
   GV_COLR=70
   ST_LINE=1    ; dotted for stratiform
   CO_LINE=2    ; dashed for convective
   CHARadj=1.0
   THIKadjPR=1.0
   THIKadjGV=1.0
   ST_THK=3
   CO_THK=2
ENDELSE


!P.Multi=[0,2,2,0,0]

; - - - - - - - - - - - - - - - - - - - - - - - -

; Compute a mean rainrate difference over each surface type and plot PDFs

mnprarrbb = fltarr(3,4)  ; each BB-relative level, for raintype all, stratiform, convective
mngvarrbb = fltarr(3,4)  ; each BB-relative level, for raintype all, stratiform, convective
levhasdatabb = intarr(4) & levhasdatabb[*] = 0
levsdatabb = 0
SfcType_str = [' N/A ', 'Ocean', ' Land', 'Coast']
xoff = [0.0, 0.0, -0.5, 0.0 ]  ; for positioning legend in PDFs
yoff = [0.0, 0.0, -0.5, -0.5 ]

   sfcRain = the_data.gmiRain
   gvrr = the_data.prRain
   ; set dist array to fixed value for call to calc_geo_pr_gv_meandiffs_wght_idx
   dist[*,*] = 1.0
   distcat = FIX(dist)  ; every point is in dist category = 1
   voldepth = sfcRain
   ; nobody gets preferential treatment, weight-wise
   voldepth[*,*] = 1.0
   ; reassign surface type values (10,20,30) to (1,2,3).
   ; get info from array of surface type
;   num_over_SfcType = LONARR(4)
   idxmix = WHERE( sfcCat EQ 3, countmix )  ; Coast
   num_over_SfcType[3] = countmix
   idxsea = WHERE( sfcCat EQ 1, countsea )  ; Ocean
   num_over_SfcType[1] = countsea
   idxland = WHERE( sfcCat EQ 2, countland )    ; Land
   num_over_SfcType[2] = countland
   idxrrabvthresh = WHERE( sfcRain GE RRcut AND gvrr GE RRcut, num_rr_abv_thresh )

   ; blank out GMI over-ocean rainrate where PoP is below threshold
      idxrainyPoPbloThresh = WHERE( sfcRain[idxsea] GT 0.0 $
                               AND the_data.pop[idxsea] lt pop_threshold, countpop2blank )
      IF countpop2blank GT 0 THEN sfcRain[idxsea[idxrainyPoPbloThresh]] = 0.0

print, ''
print, '******************************************************************************************'
print, '*'
IF (do_ps EQ 1) THEN BEGIN
   printf, tempunit, ''
   printf, tempunit, '******************************************************************************************'
   printf, tempunit, '*'
ENDIF
textout = '* GMI-DPR Rain Rate difference statistics (mm/h) - ' $
          +'   Orbit: '+orbit+'   '+version
print, textout & IF (do_ps EQ 1) THEN printf, tempunit, textout
print, '*' & IF (do_ps EQ 1) THEN printf, tempunit, '*'

PRINT, "* Number of GMI/ocean rainy points with POP < ", $
       STRING(pop_threshold,FORMAT='(f0.1)'),": ", STRING(countpop2blank,FORMAT='(I0)')
;print, '*' & IF (do_ps EQ 1) THEN printf, tempunit, '*'
print, num_rr_abv_thresh, N_ELEMENTS(sfcRain), $
       FORMAT='("* Number of matched rainy points: ", I0, " of ", I0, " total")'
IF (do_ps EQ 1) THEN printf, tempunit,num_rr_abv_thresh, N_ELEMENTS(sfcRain), $
       FORMAT='("* Number of matched rainy points: ", I0, " of ", I0, " total")'

; some fixed legend stuff for PDF plots
headline = 'GMI-DPR Mean Diffs:'

print, '*' & IF (do_ps EQ 1) THEN printf, tempunit, '*'
IF (do_ps EQ 1) THEN printf, tempunit, '*'
textout = '* Statistics grouped by underlying surface type:'
print, textout & IF (do_ps EQ 1) THEN printf, tempunit, textout
print, '*' & IF (do_ps EQ 1) THEN printf, tempunit, '*'
textout = '* Surface|   Any Rain Type  |    Stratiform    |    Convective     |  Dataset Statistics '
print, textout & IF (do_ps EQ 1) THEN printf, tempunit, textout
textout = '*  type  | GMI-DPR   NumPts | GMI-DPR   NumPts | GMI-DPR   NumPts  |  GMIMaxRR  DPR MaxRR'
print, textout & IF (do_ps EQ 1) THEN printf, tempunit, textout
textout = '*  ----- | -------   ------ | -------   ------ | -------   ------  |  --------  -------- '
print, textout & IF (do_ps EQ 1) THEN printf, tempunit, textout

; define a 2D array to capture array indices of values used for point-to-point
; mean diffs, for each of the 3 sfcCat levels, for plotting these points in the
; scatter plots
numZpts = N_ELEMENTS(sfcRain)
idx4hist3 = lonarr(3,numZpts)
idx4hist3[*,*] = -1L
num4hist3 = lonarr(3)  ; track number of points used in each sfcCat layer
idx4hist = idx4hist3[0,*]  ; a 1-D array for passing to function in the layer loop
for SfcType_2get = 1, 3 do begin
   havematch = 0
   !P.Multi=[4-SfcType_2get,2,2,0,0]
   IF ( num_over_SfcType[SfcType_2get] GT 0 ) THEN BEGIN
      flag = ''
      if (SfcType_2get eq 2) then flag = ' @ BB'
      diffstruc = the_struc
      calc_geo_pr_gv_meandiffs_wght_idx, sfcRain, gvrr, rnType, dist, distcat, sfcCat, $
                             SfcType_2get, RRcut, rangecut, mnprarrbb, mngvarrbb, $
                             havematch, diffstruc, idx4hist, voldepth
      if(havematch eq 1) then begin
         levsdatabb = levsdatabb + 1
         levhasdatabb[SfcType_2get] = 1
        ; format level's stats for table output
         stats55 = STRING(diffstruc.meandiff, diffstruc.fullcount, $
                       diffstruc.meandiffs, diffstruc.counts, $
                       diffstruc.meandiffc, diffstruc.countc, $
                       diffstruc.maxpr, diffstruc.maxgv, $
                       FORMAT='("  ",f7.3,"    ",i4,2("    ",f7.3,"    ",i4),"   ",2("   ",f7.3))' )
        ; capture points used, and format level's stats for graphic plots output
         num4hist3[SfcType_2get-1] = diffstruc.fullcount
         idx4hist3[SfcType_2get-1,*] = idx4hist
         rr_pr2 = sfcRain[idx4hist[0:diffstruc.fullcount-1]]
         rr_gv2 = gvrr[idx4hist[0:diffstruc.fullcount-1]]
         type2 = rnType[idx4hist[0:diffstruc.fullcount-1]]
         sfcCat2 = sfcCat[idx4hist[0:diffstruc.fullcount-1]]
         mndifhstr = string(diffstruc.AvgDifByHist, FORMAT='(f0.3)')
         mndifstr = string(diffstruc.meandiff, diffstruc.fullcount, FORMAT='(f0.3," (",i0,")")')
         IF diffstruc.countc EQ 0 THEN mndifstrc = 'None' $
         ELSE mndifstrc = string(diffstruc.meandiffc, diffstruc.countc, FORMAT='(f0.3," (",i0,")")')
         IF diffstruc.counts EQ 0 THEN mndifstrs = 'None' $
         ELSE mndifstrs = string(diffstruc.meandiffs, diffstruc.counts, FORMAT='(f0.3," (",i0,")")')
         idx4hist[*] = -1
         textout = "* " + SfcType_str[SfcType_2get] + " " + stats55
         print, textout & IF (do_ps EQ 1) THEN printf, tempunit, textout

        ; Plot the PDF graph for this level
         hgtline = 'Layer = ' + SfcType_str[SfcType_2get]

        ; DO ANY/ALL RAINTYPE PDFS FIRST
        ; define a set of 18 log-spaced range boundaries - yields 19 rainrate categories
         logbins = 10^(findgen(18)/5.-1)
        ; figure out where each point falls in the log ranges: from -1 (below lowest bound)
        ; to 18 (above highest bound)
         bin4pr = VALUE_LOCATE( logbins, rr_pr2 )
         bin4gr = VALUE_LOCATE( logbins, rr_gv2 )  ; ditto for GR rainrate
        ; compute histogram of log range category, ignoring the lowest (below 0.1 mm/h)
         prhist = histogram( bin4pr, min=0, max=18,locations = prhiststart )
         nxhist = histogram( bin4gr, min=0, max=18,locations = prhiststart )
         labelbins=[STRING(10^(findgen(5)*4./5.-1),FORMAT='(F6.2)'),'>250.0']
         plot, [0,MAX(prhiststart)],[0,FIX((MAX(prhist)>MAX(nxhist))*1.1)], $
                  /NODATA, COLOR=255, CHARSIZE=1*CHARadj, $
                  XTITLE=SfcType_str[SfcType_2get]+' Rain Rate, mm/h', $
                  YTITLE='Number of GMI Footprints', $
                  YRANGE=[ 0, FIX((MAX(prhist)>MAX(nxhist))*1.1) + 1 ], $
                  BACKGROUND=0, xtickname=labelbins,xtickinterval=4,xminor=4

         IF ( ~ hideTotals ) THEN BEGIN
            oplot, prhiststart, prhist, COLOR=PR_COLR
            oplot, prhiststart, nxhist, COLOR=GV_COLR
            xyouts, 0.34, 0.95, 'GMI (all)', COLOR=PR_COLR, /NORMAL, $
                    CHARSIZE=1*CHARadj
            plots, [0.29,0.33], [0.955,0.955], COLOR=PR_COLR, /NORMAL
            xyouts, 0.34, 0.925, 'DPR (all)', COLOR=GV_COLR, /NORMAL, $
                    CHARSIZE=1*CHARadj
            plots, [0.29,0.33], [0.93,0.93], COLOR=GV_COLR, /NORMAL
         ENDIF

         xyouts, 0.775+xoff[SfcType_2get],0.9+yoff[SfcType_2get], headline, $
                 COLOR=255, /NORMAL, CHARSIZE=1*CHARadj

         mndifline = 'Any/All: ' + mndifstr
         mndiflinec = 'Convective: ' + mndifstrc
         mndiflines = 'Stratiform: ' + mndifstrs
         mndifhline = 'GMI/DPR Vol. Bias: ' + mndifhstr
         xyouts, 0.775+xoff[SfcType_2get],0.875+yoff[SfcType_2get], mndifline, $
                 COLOR=255, /NORMAL, CHARSIZE=1*CHARadj
         xyouts, 0.775+xoff[SfcType_2get],0.85+yoff[SfcType_2get], mndiflinec, $
                 COLOR=255, /NORMAL, CHARSIZE=1*CHARadj
         xyouts, 0.775+xoff[SfcType_2get],0.825+yoff[SfcType_2get], mndiflines, $
                 COLOR=255, /NORMAL, CHARSIZE=1*CHARadj
         xyouts, 0.775+xoff[SfcType_2get],0.93+yoff[SfcType_2get], mndifhline, $
                 COLOR=255, /NORMAL, CHARSIZE=1*CHARadj

        ; OVERLAY CONVECTIVE RAINTYPE PDFS, IF ANY POINTS
         idxconvhist= WHERE( type2 EQ RainType_convective, nconv )
         IF ( nconv GT 0 ) THEN BEGIN
           bin4pr = VALUE_LOCATE( logbins, rr_pr2[idxconvhist] )  ; see Any/All logic above
           bin4gr = VALUE_LOCATE( logbins, rr_gv2[idxconvhist] )
           prhist = histogram( bin4pr, min=0, max=18,locations = prhiststart )
           nxhist = histogram( bin4gr, min=0, max=18,locations = prhiststart )
           oplot, prhiststart, prhist, COLOR=PR_COLR, LINESTYLE=CO_LINE, thick=3*THIKadjPR
           oplot, prhiststart, nxhist, COLOR=GV_COLR, LINESTYLE=CO_LINE, thick=3*THIKadjGV
           xyouts, 0.34, 0.85, 'GMI (Conv)', COLOR=PR_COLR, /NORMAL, CHARSIZE=1*CHARadj
           xyouts, 0.34, 0.825, 'DPR (Conv)', COLOR=GV_COLR, /NORMAL, CHARSIZE=1*CHARadj
           plots, [0.29,0.33], [0.855,0.855], COLOR=PR_COLR, /NORMAL, LINESTYLE=CO_LINE, thick=3*THIKadjPR
           plots, [0.29,0.33], [0.83,0.83], COLOR=GV_COLR, /NORMAL, LINESTYLE=CO_LINE, thick=3*THIKadjGV
         ENDIF

        ; OVERLAY STRATIFORM RAINTYPE PDFS, IF ANY POINTS
         idxstrathist= WHERE( type2 EQ RainType_stratiform, nstrat )
         IF ( nstrat GT 0 ) THEN BEGIN
           bin4pr = VALUE_LOCATE( logbins, rr_pr2[idxstrathist] )  ; see Any/All logic above
           bin4gr = VALUE_LOCATE( logbins, rr_gv2[idxstrathist] )
           prhist = histogram( bin4pr, min=0, max=18,locations = prhiststart )
           nxhist = histogram( bin4gr, min=0, max=18,locations = prhiststart )
           oplot, prhiststart, prhist, COLOR=PR_COLR, LINESTYLE=ST_LINE, thick=3*THIKadjPR
           oplot, prhiststart, nxhist, COLOR=GV_COLR, LINESTYLE=ST_LINE, thick=3*THIKadjGV
           xyouts, 0.34, 0.9, 'GMI (Strat)', COLOR=PR_COLR, /NORMAL, CHARSIZE=1*CHARadj
           xyouts, 0.34, 0.875, 'DPR (Strat)', COLOR=GV_COLR, /NORMAL, CHARSIZE=1*CHARadj
           plots, [0.29,0.33], [0.905,0.905], COLOR=PR_COLR, /NORMAL, LINESTYLE=ST_LINE, thick=3*THIKadjPR
           plots, [0.29,0.33], [0.88,0.88], COLOR=GV_COLR, /NORMAL, LINESTYLE=ST_LINE, thick=3*THIKadjGV
         ENDIF
 
      endif else begin
         print, "*  No above-threshold points for ", SfcType_str[SfcType_2get]
         xyouts, 0.6+xoff[SfcType_2get],0.75+yoff[SfcType_2get], SfcType_str[SfcType_2get] + $
                 ": NO POINTS", COLOR=255, /NORMAL, CHARSIZE=1.5
      endelse
   ENDIF ELSE BEGIN
      print, "No points over ", SfcType_str[SfcType_2get]
      xyouts, 0.6+xoff[SfcType_2get],0.75+yoff[SfcType_2get], SfcType_str[SfcType_2get] + $
              ": NO POINTS", COLOR=255, /NORMAL, CHARSIZE=1.5
   ENDELSE
endfor         ; SfcType_2get = 1,3
print, '*'
print, '******************************************************************************************'
print, ''

IF ( do_ps EQ 1 ) THEN BEGIN
   printf, tempunit, '*'
   printf, tempunit, '******************************************************************************************'
   erase                 ; start a new page in the PS file
;   device, /landscape   ; change page setup
   FREE_LUN, tempunit    ; close the temp file for writing
   OPENR, tempunit2, temptext, /GET_LUN  ; open the temp file for reading
   statstr = ''
   fmt='(a0)'
   xtext = 0.05 & ytext = 0.95
  ; write the stats tables out to the Postscript file
   while (eof(tempunit2) ne 1) DO BEGIN
     readf, tempunit2, statstr, format=fmt
     xyouts, xtext, ytext, '!11'+statstr+'!X', /NORMAL, COLOR=255, CHARSIZE=0.667
     ytext = ytext - 0.02
   endwhile
   FREE_LUN, tempunit2             ; close the temp file
ENDIF
; - - - - - - - - - - - - - - - - - - - - - - - -

; Build the Scatter Plots.  Substitute 'DPR' for SiteID in call.

IF ( do_ps EQ 1 ) THEN BEGIN
   erase
   device,/inches,xoffset=0.25,yoffset=0.55,xsize=8.,ysize=10.,/portrait
   plot_scatter_by_sfc_type3x3_ps, PSFILEpdf, PDFTITLE, 'DPR', sfcRain, gvrr, $
                            rnType, sfcCat, num4hist3, idx4hist3, $
                            y_title='GMI rainate, mm/h', MIN_XY=0.5, $
                            MAX_XY=150.0, UNITS='mm/h'
ENDIF ELSE BEGIN
   plot_scatter_by_sfc_type3x3, PDFTITLE, 'DPR', sfcRain, gvrr, rnType, sfcCat, $
                            num4hist3, idx4hist3, windowsize, $
                            y_title='GMI rainate, mm/h', MIN_XY=0.5, $
                            MAX_XY=150.0, UNITS='mm/h'
ENDELSE

SET_PLOT, orig_device

; - - - - - - - - - - - - - - - - - - - - - - - -

; Build the animation loop.

!P.Multi=[0,1,1,0,0]

IF N_ELEMENTS( animate ) NE 1 THEN BEGIN
   print, "Setting to default, no animation."
   animate = 0 & loopit = 0
ENDIF ELSE BEGIN
   CASE ABS(animate) OF
      0 : loopit = 0
      1 : loopit = 1
      2 : loopit = 2
      ELSE : BEGIN
               print, "Invalid value for ANIMATE parameter, 0, 1, and 2 allowed."
               print, '0=no animation; 1=animate map; 2=animate ray/scan'
               print, "Setting to default, no animation."
               animate = 0 & loopit = 0
             END
   ENDCASE
   IF KEYWORD_SET(blank_rejects) THEN BEGIN
      ; find points where any of DPR, GMI, or COM are non-zero
      idxrrnonzero = WHERE( the_data.gmiRain GT 0.0 $
                         OR the_data.prRain GT 0.0 $
                         OR the_data.comRain GT 0.0, num_rr_nonzero )
      IF num_rr_nonzero EQ 0 THEN message, "No non-zero rainrates?"
      ; find out where any/all of GMI, DPR, or COM rain rate is below RRcut
      idxrrbelowthresh = WHERE( the_data.gmiRain[idxrrnonzero] LT RRcut $
                             OR the_data.prRain[idxrrnonzero] LT RRcut $
                             OR the_data.comRain[idxrrnonzero] LT RRcut, $
                             num_rr_blo_thresh )
      IF num_rr_blo_thresh GT 0 THEN BEGIN
         ; grab the original values about to be blanked
         blankedGMI=the_data.gmiRain[idxrrnonzero[idxrrbelowthresh]]
         blankedPR=the_data.prRain[idxrrnonzero[idxrrbelowthresh]]
         blankedCom=the_data.comRain[idxrrnonzero[idxrrbelowthresh]]
         ; blank out the below-threshold values
         the_data.gmiRain[idxrrnonzero[idxrrbelowthresh]] = 0.0
         the_data.prRain[idxrrnonzero[idxrrbelowthresh]] = 0.0
         the_data.comRain[idxrrnonzero[idxrrbelowthresh]] = 0.0
         print, ""
         print, "Blanking out ",STRING(num_rr_blo_thresh,FORMAT='(I0)'), $
                " below-RR-threshold footprints in images."
      ENDIF
   ENDIF
ENDELSE

CASE loopit OF
  0 : plot_gpm_rainrate_swath, the_data, ANIMATE=loopit, /PRECUT, DO_PS=do_ps
  1 : plot_gpm_rainrate_swath, the_data, ANIMATE=loopit, /PRECUT, DO_PS=do_ps
  2 : animate_gpm_rainrate_bscan, the_data, /PRECUT
ENDCASE

IF KEYWORD_SET(blank_rejects) THEN BEGIN
   IF num_rr_blo_thresh GT 0 THEN BEGIN
      ; restore the blanked-out values
      the_data.gmiRain[idxrrnonzero[idxrrbelowthresh]] = blankedGMI
      the_data.prRain[idxrrnonzero[idxrrbelowthresh]] = blankedPR
      the_data.comRain[idxrrnonzero[idxrrbelowthresh]] = blankedCom
   ENDIF
ENDIF

IF animate LT 0 THEN BEGIN
   ; display only discarded rainrates below RRcut, just to see what happens
   IF KEYWORD_SET(blank_rejects) EQ 0 THEN BEGIN
      ; find points where any of DPR, GMI, or COM are non-zero
      idxrrnonzero = WHERE( the_data.gmiRain GT 0.0 $
                         OR the_data.prRain GT 0.0 $
                         OR the_data.comRain GT 0.0, num_rr_nonzero )
      IF num_rr_nonzero EQ 0 THEN message, "No non-zero rainrates?"
      ; find out where any/all of GMI, DPR, or COM rain rate is below RRcut
      idxrrbelowthresh = WHERE( the_data.gmiRain[idxrrnonzero] LT RRcut $
                                OR the_data.prRain[idxrrnonzero] LT RRcut $
                                OR the_data.comRain[idxrrnonzero] LT RRcut, $
                                num_rr_blo_thresh )
      IF num_rr_blo_thresh GT 0 THEN BEGIN
         ; grab the original values about to be blanked
         blankedGMI=the_data.gmiRain[idxrrnonzero[idxrrbelowthresh]]
         blankedPR=the_data.prRain[idxrrnonzero[idxrrbelowthresh]]
         blankedCom=the_data.comRain[idxrrnonzero[idxrrbelowthresh]]
      ENDIF
   ENDIF
   print, ''
   IF num_rr_blo_thresh GT 0 THEN BEGIN
      print, "Displaying ", STRING(num_rr_blo_thresh, FORMAT='(I0)'), $
             " discarded samples:"
      print, ''
;      blankedGMI=the_data.gmiRain[idxrrnonzero[idxrrbelowthresh]]
;      blankedPR=the_data.prRain[idxrrnonzero[idxrrbelowthresh]]
;      blankedCom=the_data.comRain[idxrrnonzero[idxrrbelowthresh]]
      the_data.gmiRain[*,*] = 0.0
      the_data.gmiRain[idxrrnonzero[idxrrbelowthresh]] = blankedGMI
      the_data.prRain[*,*] = 0.0
      the_data.prRain[idxrrnonzero[idxrrbelowthresh]] = blankedPR
      the_data.comRain[*,*] = 0.0
      the_data.comRain[idxrrnonzero[idxrrbelowthresh]] = blankedCom
      CASE loopit OF
        0 : plot_rainrate_swath, the_data, ANIMATE=loopit, /PRECUT
        1 : plot_rainrate_swath, the_data, ANIMATE=loopit, /PRECUT
        2 : animate_gpm_rainrate_bscan, the_data, /PRECUT
      ENDCASE
   ENDIF ELSE BEGIN
      print, "No discarded sample points to plot, skipping." & print, ""
   ENDELSE
ENDIF

IF ( do_ps EQ 1 ) THEN BEGIN  ; wrap up the postscript file
   set_plot,/copy,'ps'
   device,/close
   SET_PLOT, orig_device
  ; try to convert it from PS to PDF, using ps2pdf utility
   if !version.OS_NAME eq 'Mac OS X' then ps_util_name = 'pstopdf' $
   else ps_util_name = 'ps2pdf'
   command1 = 'which '+ps_util_name
   spawn, command1, result, errout
   IF result NE '' THEN BEGIN
      print, 'Converting ', PSFILEpdf, ' to PDF format.'
      command2 = ps_util_name+ ' ' + PSFILEpdf
      spawn, command2, result, errout
      print, 'Removing Postscript version'
      command3 = 'rm -v '+PSFILEpdf
      spawn, command3, result, errout
   ENDIF
ENDIF

; - - - - - - - - - - - - - - - - - - - - - - -

nextFile:

; restore the character sizes in effect prior to calling plot_rainrate_swath
; or animate_rainrate_bscan
device, SET_CHARACTER_SIZE=[orig_width,orig_height]

something = ""
IF animate EQ 0 THEN BEGIN
   print, ''
   READ, something, PROMPT='Hit Return to proceed to next case, Q to Quit: '
ENDIF

errorExit2:

if ( do_ps EQ 0 ) THEN BEGIN
   WDELETE, 0
   WDELETE, 3
endif

IF animate EQ 0 THEN WDELETE, 1

status = 0
IF something EQ 'Q' OR something EQ 'q' THEN status = 1

errorExit:

return, status
end

;===============================================================================
;
; MODULE 2:  dpr2gmi_rainrate_comparisons
;
; DESCRIPTION
; -----------
; Driver for the dpr2gmi_rr_plots function (included).  Sets up user/default
; parameters defining the plots and animations, and the method by which the next
; case is selected: either prompt the user to select the file, or just take the
; next one in the sequence.
;
; PARAMETERS
; ----------
; looprate      - initial animation rate for the PPI animation loop on startup.
;                 Defaults to 3 if unspecified or outside of allowed 0-100 range
;
; ncpath        - local directory path to the geo_match netCDF files' location.
;                 Defaults to /data/gpmgv/netcdf/geo_match
;
; filefilter    - file pattern which acts as the filter limiting the set of input
;                 files showing up in the file selector or over which the program
;                 will iterate, depending on the select mode parameter.
;                 Default = 'DPRtoGMI*'
;
; no_prompt     - method by which the next file in the set of files defined by
;                 ncpath and filefilter is selected. Binary parameter. If unset,
;                 defaults to DialogPickfile()
;
; win_size      - size in pixels of each plot window.  Default=375
;
; pop_threshold - constraint on the percent Probability of Precipitation for V7
;                 data that defines a rain certain sample over ocean surfaces.
;                 Data below this threshold are excluded from consideration.
;                 Default = 50.0 (percent)
;
; RRcut         - minimum rain rate that defines a rain certain sample.
;                 Data below this threshold are excluded from consideration.
;                 Default = 0.1 (mm/h)
;
; blank_rejects - Binary parameter, controls whether to show (default) or hide
;                 the samples not meeting the PoP and/or RRcut thresholds in the
;                 image plots.  Default = 0 (show below-threshold points).
;
; hide_totals   - Binary parameter, controls whether to show (default) or hide
;                 the PDF plots for rain type = "Any".
;
; ps_dir        - Directory to which postscript output will be written.  If not
;                 specified, output is directed only to the screen.
;
; b_w           - Binary parameter, controls whether to plot PDFs in Postscript
;                 file in color (default) or in black-and-white.
;
; animate       - Determines the type of image display to render on-screen when
;                 not writing output to postscript/PDF file.  Allowed values
;                 and their affect on the displayed output include:
;
;                 0 - (default) display a static image of GMI rain rate on a map
;                     backgound
;                 1 - display an animation sequence of GMI, DPR, and GMI-DPR
;                     Combined rain rate images on a map background
;                 2 - as for (1), but in ray vs. scan coordinates rather than on
;                     a map.
;

pro dpr2gmi_rainrate_comparisons, SPEED=looprate, $
                                 NCPATH=ncpath, $
                                 FILEFILTER=filefilter, $
                                 NO_PROMPT=no_prompt, $
                                 POP_THRESHOLD=pop_threshold, $
                                 RR_CUT=RRcut, $
                                 BLANK_REJECTS=blank_rejects, $
                                 WIN_SIZE=win_size, $
                                 HIDE_TOTALS=hide_totals, $
                                 PS_DIR=ps_dir, $
                                 B_W=b_w, $
                                 ANIMATE=animate


; set up the loop speed for xinteranimate, 0<= speed <= 100
IF ( N_ELEMENTS(looprate) EQ 1 ) THEN BEGIN
  IF ( looprate LT 0 OR looprate GT 100 ) THEN looprate = 3
ENDIF ELSE BEGIN
   looprate = 3
ENDELSE

IF N_ELEMENTS( animate ) NE 1 THEN BEGIN
   print, "Setting to default, no animation."
   animate = 0
ENDIF

IF ( N_ELEMENTS(ncpath) NE 1 ) THEN BEGIN
   print, "Defaulting to /data/gpmgv/netcdf/geo_match for file path."
   pathpr = '/data/gpmgv/netcdf/geo_match'
ENDIF ELSE pathpr = ncpath

IF ( N_ELEMENTS(filefilter) NE 1 ) THEN BEGIN
   print, "Defaulting to DPRtoGMI* for file pattern."
   ncfilepatt = 'DPRtoGMI*'
ENDIF ELSE ncfilepatt = '*'+filefilter+'*'

IF ( N_ELEMENTS(pop_threshold) EQ 1 ) THEN BEGIN
  IF ( pop_threshold LT 0. OR pop_threshold GT 100. ) THEN BEGIN
     print, "PoP_threshold must lie between 0 and 100, value is: ", pop_threshold
     print, "Defaulting to 50.0 for pop_threshold."
     pop_threshold = 50.
  ENDIF
ENDIF ELSE BEGIN
   pop_threshold = 50.
ENDELSE

blank_rejects = keyword_set(blank_rejects)
hideTotals = keyword_set(hide_totals)
b_w = keyword_set(b_w)

IF ( N_ELEMENTS(win_size) NE 1 ) THEN BEGIN
   print, "Defaulting to 375 for WINDOW size."
   win_size = 375
ENDIF
   
; set up for Postscript vs. On-Screen output
IF ( N_ELEMENTS( ps_dir ) NE 1 || ps_dir EQ "" ) THEN BEGIN
   print, "Defaulting to screen output for scatter plot."
   ps_dir = ''
ENDIF ELSE BEGIN
   mydirstruc = FILE_INFO(ps_dir )
   IF (mydirstruc.directory) THEN print, "Postscript files will be written to: ", ps_dir $
   ELSE BEGIN
      MESSAGE, "Directory "+ps_dir+" specified for PS_DIR does not exist, exiting."
   ENDELSE
ENDELSE

; Figure out how the next file to process will be obtained.  If no_prompt is
; set, then we will automatically loop over the file sequence.  Otherwise we
; will prompt the user for the next file with dialog_pickfile() (DEFAULT).

no_prompt = keyword_set(no_prompt)

IF (no_prompt) THEN BEGIN

   prfiles = file_search(pathpr+'/'+ncfilepatt,COUNT=nf)

   if nf eq 0 then begin
      print, 'No netCDF files matching file pattern: ', pathpr+'/'+ncfilepatt
   endif else begin
      for fnum = 0, nf-1 do begin
        ; set up for bailout prompt every 5 cases if w/o file prompt
         doodah = ""
         IF ( ((fnum+1) MOD 5) EQ 0 AND no_prompt ) THEN BEGIN $
             READ, doodah, $
             PROMPT='Hit Return to do next 5 cases, Q to Quit, D to Disable this bail-out option: '
             IF doodah EQ 'Q' OR doodah EQ 'q' THEN break
             IF doodah EQ 'D' OR doodah EQ 'd' THEN no_prompt=0   ; never ask again
         ENDIF
        ;
         mygeomatchfile = prfiles(fnum)
;         action = 0
         action = dpr2gmi_rr_plots( mygeomatchfile, looprate, win_size, $
                                   POP_THRESHOLD=pop_threshold, RR_CUT=RRcut, $
                                   BLANK_REJECTS=blank_rejects, hideTotals, $
                                   PS_DIR=ps_dir, B_W=b_w, ANIMATE=animate )

         if (action) then break
      endfor
   endelse
ENDIF ELSE BEGIN
   print, ''
   print, 'Select a DPRtoGMI file from the file selector, or Cancel to exit.'
   mygeomatchfile = dialog_pickfile(path=pathpr, filter = ncfilepatt, $
                                    TITLE='Select a DPRtoGMI file')
   while mygeomatchfile ne '' do begin
      action = dpr2gmi_rr_plots( mygeomatchfile, looprate, win_size, $
                                POP_THRESHOLD=pop_threshold, RR_CUT=RRcut, $
                                BLANK_REJECTS=blank_rejects, hideTotals, $
                                PS_DIR=ps_dir, B_W=b_w, ANIMATE=animate )
;      action = 0
      if (action) then break
      print, ''
      print, 'Select another DPRtoGMI file from the file selector, or Cancel to exit.'
      mygeomatchfile = dialog_pickfile(path=pathpr, filter = ncfilepatt, $
                                       TITLE='Select a DPRtoGMI file')
   endwhile
ENDELSE

print, "" & print, "Done!"

END
