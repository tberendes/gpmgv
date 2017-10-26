;===============================================================================
;+
; Copyright © 2014, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; geo_match_z_comparisons_dpr.pro
; - Morris/SAIC/GPM_GV  April 2014
;
; HISTORY
; -------
; 04/29/14 Morris, GPM GV, SAIC
; - Created from geo_match_z_pdf_profile_ppi_bb_prox_sca.pro.  Modified to
;   not reject cases where no Mean Bright Band height can be determined.
;
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;===============================================================================
;
; MODULE 1:  geo_match_z_plots
;
; DESCRIPTION
; -----------
; Reads DPR and GR reflectivity and spatial fields from a user-selected geo_match
; netCDF file, builds index arrays of categories of range, rain type, bright
; band proximity (above, below, within), and an array of actual range. 
; Computes mean DPR-GR reflectivity differences for each of the 3 bright band
; proximity levels for points within 100 km of the ground radar and reports the
; results in a table to stdout.  Also produces graphs of the Probability
; Density Function of PR and GV reflectivity at each of these 3
; levels if data exists at that level, and vertical profiles of
; mean PR and GV reflectivity, for each of 3 rain type categories: Any,
; Stratiform, and Convective. Optionally produces a single frame or an
; animation loop of GV and equivalent DPR PPI images for N=elevs2show frames.
; DPR footprints in the PPIs are encoded by rain type by pattern: solid=Other,
; vertical=Convective, horizontal=Stratiform.
;
; If PS_DIR is specified then the output is to a Postscript file under ps_dir,
; otherwise all output is to the screen.  When outputting to Postscript, the
; PPI animation is still to the screen but the PDF and scatter plots go to the
; Postscript device, as well as a copy of the last frame of the PPI images in
; the animation loop.  The name of the Postscript file uses the station ID,
; datestamp, and orbit number taken from the geo_match netCDF data file.
; If b_w is set, then Postscript output will be black and white, otherwise it's
; in color.  If BATCH is also set with PS_DIR then the output file will be
; created without any graphics or user prompts and the program will proceed to
; the next case, as specified by the input parameters to the calling procedure,
; geo_match_z_pdf_profile_ppi_bb_prox_sca_ps().
;
; If s2ku binary parameter is set, then the Liao/Meneghini S-to-Ku band
; reflectivity adjustment will be made to the computed differences.

FUNCTION geo_match_z_plots, ncfilepr, looprate, elevs2show, startelev, PPIorient, $
                            windowsize, pctabvthresh, PPIbyThresh, gvconvective, $
                            gvstratiform, histo_Width, hideTotals, PS_DIR=ps_dir, $
                            B_W=b_w, BATCH=batch, S2KU=s2ku, BGWHITE=bgwhite

; "include" file for read_geo_match_netcdf() structs returned
@geo_match_nc_structs.inc

; "include" file for PR data constants
@pr_params.inc

; extract metadata fields from the geo-match filename based on naming convention
bname = file_basename( ncfilepr )
prlen = strlen( bname )
pctString = STRTRIM(STRING(FIX(pctabvthresh)),2)
parsed = STRSPLIT( bname, '.', /extract )
site = parsed[1]
yymmdd = parsed[2]
orbit = parsed[3]
version = parsed[4]   ; older files may not have this, do checking
swath=parsed[6]
instrument=parsed[5]
CASE version OF
     '6' : BREAK
     '7' : BREAK
    ELSE : version = '?'
ENDCASE

; set up pointers for each field to be returned from fprep_geo_match_profiles()
ptr_geometa=ptr_new(/allocate_heap)
ptr_sweepmeta=ptr_new(/allocate_heap)
ptr_sitemeta=ptr_new(/allocate_heap)
ptr_fieldflags=ptr_new(/allocate_heap)
ptr_gvz=ptr_new(/allocate_heap)
ptr_zcor=ptr_new(/allocate_heap)
ptr_zraw=ptr_new(/allocate_heap)
ptr_rain3=ptr_new(/allocate_heap)
ptr_top=ptr_new(/allocate_heap)
ptr_botm=ptr_new(/allocate_heap)
ptr_lat=ptr_new(/allocate_heap)
ptr_lon=ptr_new(/allocate_heap)
ptr_nearSurfRain=ptr_new(/allocate_heap)
ptr_nearSurfRain_2b31=ptr_new(/allocate_heap)
ptr_rnFlag=ptr_new(/allocate_heap)
ptr_rnType=ptr_new(/allocate_heap)
ptr_pr_index=ptr_new(/allocate_heap)
ptr_xCorner=ptr_new(/allocate_heap)
ptr_yCorner=ptr_new(/allocate_heap)
ptr_bbProx=ptr_new(/allocate_heap)
ptr_hgtcat=ptr_new(/allocate_heap)
ptr_dist=ptr_new(/allocate_heap)
ptr_pctgoodpr=ptr_new(/allocate_heap)
ptr_pctgoodgv=ptr_new(/allocate_heap)
ptr_pctgoodrain=ptr_new(/allocate_heap)

; structure to hold bright band variables
BBparms = {meanBB : -99.99, BB_HgtLo : -99, BB_HgtHi : -99}

; Define the list of fixed-height levels for the vertical profile statistics
heights = [1.5,3.0,4.5,6.0,7.5,9.0,10.5,12.0,13.5,15.0,16.5,18.0,19.5]
hgtinterval = 1.5
;heights = [1.0,2.0,3.0,4.0,5.0,6.0,7.0,8.0,9.0,10.0,11.0,12.0,13.0,14.0,15.0,16.0,17.0,18.0]
;hgtinterval = 1.0
print, 'pctAbvThresh = ', pctAbvThresh

; read the geometry-match variables and arrays from the file, and preprocess them
; to remove the 'bogus' PR ray positions.  Return a pointer to each variable read.

status = fprep_dpr_geo_match_profiles( ncfilepr, heights, $
    PCT_ABV_THRESH=pctAbvThresh, GV_CONVECTIVE=gvconvective, $
    GV_STRATIFORM=gvstratiform, S2KU=s2ku, PTRfieldflags=ptr_fieldflags, $
    PTRgeometa=ptr_geometa, PTRsweepmeta=ptr_sweepmeta, PTRsitemeta=ptr_sitemeta, $
    PTRGVZMEAN=ptr_gvz, PTRzcor=ptr_zcor, PTRzraw=ptr_zraw, PTRrain3d=ptr_rain3, $
    PTRtop=ptr_top, PTRbotm=ptr_botm, PTRlat=ptr_lat, PTRlon=ptr_lon, $
    PTRsfcrainpr=ptr_nearSurfRain, PTRsfcraincomb=ptr_nearSurfRain_2b31, $
    PTRrainflag_int=ptr_rnFlag, PTRraintype_int=ptr_rnType, PTRpridx_long=ptr_pr_index, $
    PTRxCorners=ptr_xCorner, PTRyCorners=ptr_yCorner, PTRbbProx=ptr_bbProx, $
    PTRhgtcat=ptr_hgtcat, PTRdist=ptr_dist, PTRpctgoodpr=ptr_pctgoodpr, $
    PTRpctgoodgv=ptr_pctgoodgv, PTRpctgoodrain=ptr_pctgoodrain, BBPARMS=BBparms )

IF (status EQ 1) THEN BEGIN
   ; free the pointers and set up to skip to the next file
    ptr_free,ptr_geometa
    ptr_free,ptr_sitemeta
    ptr_free,ptr_sweepmeta
    ptr_free,ptr_fieldflags
    ptr_free,ptr_gvz
    ptr_free,ptr_zraw
    ptr_free,ptr_zcor
    ptr_free,ptr_rain3
    ptr_free,ptr_top
    ptr_free,ptr_botm
    ptr_free,ptr_lat
    ptr_free,ptr_lon
    ptr_free,ptr_nearSurfRain
    ptr_free,ptr_nearSurfRain_2b31
    ptr_free,ptr_rnFlag
    ptr_free,ptr_rnType
    ptr_free,ptr_pr_index
    ptr_free,ptr_xCorner
    ptr_free,ptr_yCorner
    ptr_free,ptr_bbProx
    ptr_free,ptr_hgtcat
    ptr_free,ptr_dist
    ptr_free,ptr_pctgoodpr
    ptr_free,ptr_pctgoodgv
    ptr_free,ptr_pctgoodrain
    levsdata = 0
    something = ""
    haveWinZero = 0  ; Have we created WINDOW 0 ?
    GOTO, errorExit2
ENDIF

; create local data field arrays/structures needed here, and free pointers we no longer need
; to free the memory held by these pointer variables
  mygeometa=*ptr_geometa
    ptr_free,ptr_geometa
  mysite=*ptr_sitemeta
    ptr_free,ptr_sitemeta
  mysweeps=*ptr_sweepmeta
    ptr_free,ptr_sweepmeta
  myflags=*ptr_fieldflags
    ptr_free,ptr_fieldflags
  gvz=*ptr_gvz
  gvz_in = gvz     ; for plotting as PPI
    ptr_free,ptr_gvz
  zraw=*ptr_zraw
  zraw_in = zraw   ; for plotting as PPI
    ptr_free,ptr_zraw
  zcor=*ptr_zcor
  zcor_in = zcor   ; for plotting as PPI
    ptr_free,ptr_zcor
  rain3=*ptr_rain3
  rain3_in = rain3 ; for plotting as PPI
    ptr_free,ptr_rain3
  top=*ptr_top
  botm=*ptr_botm
  lat=*ptr_lat
  lon=*ptr_lon
  rnflag=*ptr_rnFlag
  rntype=*ptr_rnType
  pr_index=*ptr_pr_index
  xcorner=*ptr_xCorner
  ycorner=*ptr_yCorner
  bbProx=*ptr_bbProx
  dist=*ptr_dist
  hgtcat=*ptr_hgtcat
  pctgoodpr=*ptr_pctgoodpr
  pctgoodgv=*ptr_pctgoodgv
  pctgoodrain=*ptr_pctgoodrain
    ptr_free,ptr_top
    ptr_free,ptr_botm
    ptr_free,ptr_lat
    ptr_free,ptr_lon
    ptr_free,ptr_nearSurfRain
    ptr_free,ptr_nearSurfRain_2b31
    ptr_free,ptr_rnFlag
    ptr_free,ptr_rnType
    ptr_free,ptr_pr_index
    ptr_free,ptr_xCorner
    ptr_free,ptr_yCorner
    ptr_free,ptr_bbProx
    ptr_free,ptr_hgtcat
    ptr_free,ptr_dist
    ptr_free,ptr_pctgoodpr
    ptr_free,ptr_pctgoodgv
    ptr_free,ptr_pctgoodrain

show_ppis=1   ; initialize to ON, override if PS and BATCH both are set

; open a file to hold output stats to be appended to the Postscript file,
; if Postscript output is indicated
IF KEYWORD_SET( ps_dir ) THEN BEGIN
   do_ps = 1
   temptext = ps_dir + '/dbzdiffstats_temp.txt'
   OPENW, tempunit, temptext, /GET_LUN
  ; figure out whether to plot PPIs and prompt, or just write Postscript and 
  ; wrap up
   IF KEYWORD_SET( batch ) THEN show_ppis=0     ; don't display PPIs/animation
ENDIF ELSE do_ps = 0

nfp = mygeometa.num_footprints
nswp = mygeometa.num_sweeps
site_lat = mysite.site_lat
site_lon = mysite.site_lon
siteID = string(mysite.site_id)
nsweeps = mygeometa.num_sweeps

; try to get the TRMM version from file metadata, if not extracted from filename
IF ( version EQ '?' ) THEN BEGIN
   version = mygeometa.DPR_Version
;   CASE version OF
;        '6' : BREAK
;        '7' : BREAK
;       ELSE : BEGIN
;                 PRINT, "Could not determine TRMM Version from filename: ", bname
;                 PRINT, "Invalid TRMM Version from file metadata: ", version
;                 version = '?'
;              END
;    ENDCASE
ENDIF
print, '' & print, "Version: ", version & print, ''

; make a copy of the adjusted rain type field for use in PPI plots
rntype4ppi = REFORM( rnType[*,0] )

; - - - - - - - - - - - - - - - - - - - - - - - -

; optional data clipping based on percent completeness of the volume averages:
; Decide which PR and GV points to include, based on percent of expected points
; in bin-averaged results that were above dBZ thresholds set when the matchups
; were done.  If unspecified or set to zero, include all points regardless of
; 'completeness' of the volume averages.


IF ( pctAbvThresh GT 0.0 ) THEN BEGIN
    ; clip to the 'good' points, where 'pctAbvThresh' fraction of bins in average
    ; were above threshold
   idxgoodenuff = WHERE( pctgoodpr GE pctAbvThresh $
                    AND  pctgoodgv GE pctAbvThresh, countgoodpct )
   IF ( countgoodpct GT 0 ) THEN BEGIN
       gvz = gvz[idxgoodenuff]
       zraw = zraw[idxgoodenuff]
       zcor = zcor[idxgoodenuff]
       rain3 = rain3[idxgoodenuff]
       top = top[idxgoodenuff]
       botm = botm[idxgoodenuff]
       lat = lat[idxgoodenuff]
       lon = lon[idxgoodenuff]
       rnFlag = rnFlag[idxgoodenuff]
       rnType = rnType[idxgoodenuff]
       dist = dist[idxgoodenuff]
       bbProx = bbProx[idxgoodenuff]
       hgtcat = hgtcat[idxgoodenuff]
;       pr_index = pr_index[idxgoodenuff] : NO! must be full array for PPIs
       IF ( PPIbyThresh ) THEN BEGIN
           idx2plot=idxgoodenuff  ;idxpractual2d[idxgoodenuff]
           n2plot=countgoodpct
       ENDIF
   ENDIF ELSE BEGIN
       print, "No complete-volume points, quitting case."
       goto, errorExit
   ENDELSE
ENDIF ELSE BEGIN
  ; pctAbvThresh is 0, take/plot ALL non-bogus points
   IF ( PPIbyThresh ) THEN BEGIN
      idx2plot=WHERE( pctgoodpr GE 0.0 AND  pctgoodgv GE 0.0, countactual2d )
      n2plot=countactual2d
   ENDIF
ENDELSE

; as above, but optional data *blanking* based on percent completeness of the
; volume averages for PPI plots, operating on the full arrays of gvz and zcor:

IF ( PPIbyThresh ) THEN BEGIN
  ; we only use unclipped arrays for PPIs, so we work with copies of the z arrays
   idx3d = LONG( gvz_in )   ; make a copy
  ; re-set this for our later use in PPI plotting
   idx3d[*,*] = 0L       ; initialize all points to 0
   idx3d[idx2plot] = 2L  ; tag the points to be plotted in post-threshold PPI
   idx2blank = WHERE( idx3d EQ 0L, count2blank )
   gvz_in2 = gvz_in
   zcor_in2 = zcor_in
   IF ( count2blank GT 0 ) THEN BEGIN
     gvz_in2[idx2blank] = 0.0
     zcor_in2[idx2blank] = 0.0
   ENDIF
  ; determine the non-missing points-in-common between PR and GV, data value-wise,
  ; to make sure the same points are plotted on PR and GV post-threshold PPIs
   idx2blank2 = WHERE( (gvz_in2 LT 0.0) OR (zcor_in2 LE 0.0), count2blank2 )
   IF ( count2blank2 GT 0 ) THEN BEGIN
     gvz_in2[idx2blank2] = 0.0
     zcor_in2[idx2blank2] = 0.0
   ENDIF
ENDIF

; - - - - - - - - - - - - - - - - - - - - - - - -

; build an array of range categories from the GV radar, using ranges previously
; computed from lat and lon by fprep_geo_match_profiles():
; - range categories: 0 for 0<=r<50, 1 for 50<=r<100, 2 for r>=100, etc.
; (not actually used in this or the called procedures, but retaining it for now)
distInterval = 50
distcat = ( FIX(dist) / distInterval )

; get info from array of height category for the fixed-height levels, for profiles
nhgtcats = N_ELEMENTS(heights)
num_in_hgt_cat = LONARR( nhgtcats )
FOR i=0, nhgtcats-1 DO BEGIN
   hgtstr =  string(heights[i], FORMAT='(f0.1)')
   idxhgt = where(hgtcat EQ i, counthgts)
   num_in_hgt_cat[i] = counthgts
ENDFOR

; get info from array of BB proximity
num_in_BB_Cat = LONARR(4)
idxabv = WHERE( bbProx EQ 3, countabv )
num_in_BB_Cat[3] = countabv
idxblo = WHERE( bbProx EQ 1, countblo )
num_in_BB_Cat[1] = countblo
idxin = WHERE( bbProx EQ 2, countin )
num_in_BB_Cat[2] = countin
idxnobb = WHERE( bbProx EQ 0, countnobb )
num_in_BB_Cat[0] = countnobb

; build an array of sample volume depth for weighting of the layer averages and
; mean differences
voldepth = (top-botm) > 0.0

bs = histo_Width
print, "Using histogram bin size = ", bs
;minz4hist = 18.  ; not used, replaced with dbzcut
maxz4hist = 55.
dbzcut = 10.      ; absolute DPR/GR dBZ cutoff of points to use in mean diff. calcs.
rangecut = distInterval*2.0  ; make it a multiple of distInterval

; - - - - - - - - - - - - - - - - - - - - - - - -

; Print the data computation parameters above the tables of statistics

print, ''
textout = Instrument+'-GR Reflectivity difference statistics (dBZ) - GR Site: '+siteID
print, textout & IF (do_ps EQ 1) THEN printf, tempunit, textout
textout = 'Orbit: '+orbit+'  Version: '+version+'  Swath Type: '+swath
print, textout & IF (do_ps EQ 1) THEN printf, tempunit, textout
textout ='DPR time = '+mygeometa.atimeNearestApproach+'   GR start time = '+mysweeps[0].atimeSweepStart
print, textout & IF (do_ps EQ 1) THEN printf, tempunit, textout
CASE FIX(pctAbvThresh) OF
     100 : gt_ge = " = "
       0 : gt_ge = " > "
    ELSE : gt_ge = " >= "
ENDCASE
textout = 'Required percent of above-threshold DPR and GR bins in matched volumes'+gt_ge+pctString+"%"
print, textout & IF (do_ps EQ 1) THEN printf, tempunit, textout
IF ( s2ku ) THEN BEGIN
   textout = 'GR reflectivity has S-to-Ku frequency adjustments applied.'
   print, textout & IF (do_ps EQ 1) THEN printf, tempunit, textout
ENDIF

; Print the table header lines for the statistics by fixed height layers

print, '' & IF (do_ps EQ 1) THEN printf, tempunit, ''
print, '' & IF (do_ps EQ 1) THEN printf, tempunit, ''
textout = 'Statistics grouped by fixed height levels (km):'
print, textout & IF (do_ps EQ 1) THEN printf, tempunit, textout
print, '' & IF (do_ps EQ 1) THEN printf, tempunit, ''
textout =  ' Vert. |   Any Rain Type  |    Stratiform    |    Convective     |     Dataset Statistics      |     |'
print, textout & IF (do_ps EQ 1) THEN printf, tempunit, textout
textout = ' Layer |  DPR-GR   NumPts |  DPR-GR   NumPts |  DPR-GR   NumPts  | AvgDist   DPR MaxZ  GR MaxZ | BB? |'
print, textout & IF (do_ps EQ 1) THEN printf, tempunit, textout
textout = ' ----- | -------   ------ | -------   ------ | -------   ------  | -------   --------  ------- | --- |'
print, textout & IF (do_ps EQ 1) THEN printf, tempunit, textout

; - - - - - - - - - - - - - - - - - - - - - - - -

mnprarr = fltarr(3,nhgtcats)  ; each level, for raintype all, stratiform, convective
mngvarr = fltarr(3,nhgtcats)  ; each level, for raintype all, stratiform, convective
levhasdata = intarr(nhgtcats) & levhasdata[*] = 0
levsdata = 0
max_hgt_w_data = 0.0

; - - - - - - - - - - - - - - - - - - - - - - - -

; Compute a mean dBZ difference at each level

; define a structure to hold difference statistics computed within and returned
; by the called function calc_geo_pr_gv_meandiffs_wght_idx()
the_struc = { diffsset, $
              meandiff: -99.999, meandist: -99.999, fullcount: 0L,  $
              maxpr: -99.999, maxgv: -99.999, $
              meandiffc: -99.999, countc: 0L, $
              meandiffs: -99.999, counts: 0L, $
              AvgDifByHist: -99.999 $
            }

for lev2get = 0, nhgtcats-1 do begin
   havematch = 0
   thishgt = (lev2get+1)*hgtinterval
   IF ( num_in_hgt_cat[lev2get] GT 0 ) THEN BEGIN
      flag = ''
      idx4hist = lonarr(num_in_hgt_cat[lev2get])  ; array indices used for point-to-point mean diffs
      idx4hist[*] = -1L
      if (lev2get eq BBparms.BB_HgtLo OR lev2get eq BBparms.BB_HgtHi) then flag = ' @ BB'
      diffstruc = the_struc   ; use a copy, we need the original again later on
      calc_geo_pr_gv_meandiffs_wght_idx, zcor, gvz, rnType, dist, distcat, hgtcat, $
                             lev2get, dbzcut, rangecut, mnprarr, mngvarr, $
                             havematch, diffstruc, idx4hist, voldepth
      if(havematch eq 1) then begin
         levsdata = levsdata + 1
         levhasdata[lev2get] = 1
         max_hgt_w_data = thishgt
        ; format level's stats for table output
         stats55 = STRING(diffstruc.meandiff, diffstruc.fullcount, $
                       diffstruc.meandiffs, diffstruc.counts, $
                       diffstruc.meandiffc, diffstruc.countc, $
                       diffstruc.meandist, diffstruc.maxpr, diffstruc.maxgv, $
                       FORMAT='(3("    ",f7.3,"    ",i4),"  ",3("   ",f7.3))' )
        ; extract/format level's stats for graphic plots output
         dbzpr2 = zcor[idx4hist[0:diffstruc.fullcount-1]]
         dbzgv2 = gvz[idx4hist[0:diffstruc.fullcount-1]]
         mndifhstr = string(diffstruc.AvgDifByHist, FORMAT='(f0.3)')
         mndifstr = string(diffstruc.meandiff, diffstruc.fullcount, FORMAT='(f0.3," (",i0,")")')
         mndifstrc = string(diffstruc.meandiffc, diffstruc.countc, FORMAT='(f0.3," (",i0,")")')
         mndifstrs = string(diffstruc.meandiffs, diffstruc.counts, FORMAT='(f0.3," (",i0,")")')
         idx4hist[*] = -1L
         textout = STRING(heights[lev2get], stats55, flag, FORMAT='(" ",f4.1,a0," ",a0)')
         print, textout & IF (do_ps EQ 1) THEN printf, tempunit, textout
      endif else begin
         textout = "No above-threshold points at height " + STRING(heights[lev2get], FORMAT='(f0.3)')
         print, textout & IF (do_ps EQ 1) THEN printf, tempunit, textout
      endelse
   ENDIF ELSE BEGIN
      print, "No points at height " + string(heights[lev2get], FORMAT='(f0.3)')
   ENDELSE

endfor         ; lev2get = 0, nhgtcats-1

; - - - - - - - - - - - - - - - - - - - - - - - -

; Build the mean Z profile plot panel
haveWinZero = 0  ; Have we created WINDOW 0 ?
orig_device = !D.NAME

IF ( do_ps EQ 1 ) THEN BEGIN
  ; set up postscript plot params.
   cd, ps_dir
   b_w = keyword_set(b_w)
   IF ( s2ku ) THEN add2nm = '_S2Ku' ELSE add2nm = ''
   PSFILEpdf = ps_dir+'/'+site+'.'+yymmdd+'.'+orbit+"."+version+'.' $
               +instrument+'.'+swath+".Pct"+pctString+add2nm+'_PDF_SCATR.ps'
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
   fgcolor = 255  ; color for plot frames, axes, etc.

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
   prev_background = !p.background  ; used to reset bg color for scatter plots
   fgcolor = 255
   if keyword_set(bgwhite) then begin
       !p.background = 255   ; reverse color for white plot background
       fgcolor = 0           ; reverse color for dark plot frames, axes, etc.
      ; use the Postscript colors (red, blue) with the white background
       LOADCT, 6, /SILENT
       red=bytarr(256) & green=bytarr(256) & blue=bytarr(256)
       red=r_curr & green=g_curr & blue=b_curr
       red(0)=0 & green(0)=0 & blue(0)=0
       red(1)=115 & green(1)=115 & blue(1)=115  ; gray for GV
       red(255)=255 & green(255)=255 & blue(255)=255
       tvlct,red,green,blue
       PR_COLR=200
       GV_COLR=60
   endif else begin
      ; use red and green lines on the black background
       LOADCT, 2, /SILENT
       PR_COLR=30
       GV_COLR=70
   endelse

   IF ( pctAbvThresh GT 0.0 ) THEN BEGIN
      IF ( pctAbvThresh EQ 100.0 ) THEN gt_ge = '= ' ELSE gt_ge = '>= '
      wintxt = "With % of averaged bins above dBZ thresholds "+gt_ge+pctString+"%"
   ENDIF ELSE BEGIN
      wintxt = "With all non-missing DPR/GR matched samples"
   ENDELSE

   Window, xsize=700, ysize=700, TITLE = site+' vs. '+instrument+'.'+swath+"."+version+ $
           "  --  "+wintxt, RETAIN=2
   haveWinZero = 1  ; we now have created WINDOW 0
   ST_LINE=1        ; dotted for stratiform
   CO_LINE=2        ; dashed for convective
   CHARadj=1.0
   THIKadjPR=1.0
   THIKadjGV=1.0
   ST_THK=3
   CO_THK=2
ENDELSE


!P.Multi=[0,2,2,0,0]

if (levsdata eq 0) then begin
   errString = "No valid data levels found for reflectivity"
   print, errString+'!'
  ; set up to plot error message in pdf/profile plot panel
   nframes = 0
   xtext = 0.05 & ytext = 0.5
   IF ( do_ps EQ 1 ) THEN BEGIN
     ; write the error text out to the Postscript file
      xyouts, xtext, ytext, '!11'+errString+'!!', /NORMAL, COLOR=255, CHARSIZE=1.5
   ENDIF ELSE xyouts, xtext, ytext, errString+'!', /NORMAL, COLOR=fgcolor, CHARSIZE=2
   goto, nextFile
endif

idxlev2plot = WHERE( levhasdata EQ 1 )
h2plot = heights[idxlev2plot]

; figure out the y-axis range.  Use the greater of max_hgt_w_data*2.0
; and meanbb*2 as the proposed range.  Cut off at 20 km if result>20.
prop_max_y = max_hgt_w_data*2.0 > (FIX((BBparms.meanbb*2)/1.5) + 1) *1.5
plot, [15,50], [0,20 < prop_max_y], /NODATA, COLOR=fgcolor, $
      XSTYLE=1, YSTYLE=1, YTICKINTERVAL=hgtinterval, YMINOR=1, thick=1, $
      XTITLE='Level Mean Reflectivity, dBZ', YTITLE='Height Level, km', $
      CHARSIZE=1*CHARadj ;, BACKGROUND=0

IF (~ hideTotals) THEN BEGIN
  ; plot the profile for all points regardless of rain type
   prmnz2plot = mnprarr[0,*]
   prmnz2plot = prmnz2plot[idxlev2plot]
   gvmnz2plot = mngvarr[0,*]
   gvmnz2plot = gvmnz2plot[idxlev2plot]
   oplot, prmnz2plot, h2plot, COLOR=PR_COLR, thick=1*THIKadjPR
   oplot, gvmnz2plot, h2plot, COLOR=GV_COLR, thick=1*THIKadjGV
ENDIF

; plot the profile for stratiform rain type points
prmnz2plot = mnprarr[1,*]
prmnz2plot = prmnz2plot[idxlev2plot]
gvmnz2plot = mngvarr[1,*]
gvmnz2plot = gvmnz2plot[idxlev2plot]
idxhavezs = WHERE( prmnz2plot GT 0.0 and gvmnz2plot GT 0.0, counthavezs )
IF ( counthavezs GT 0 ) THEN BEGIN
   oplot, prmnz2plot[idxhavezs], h2plot[idxhavezs], COLOR=PR_COLR, LINESTYLE=ST_LINE, thick=3*THIKadjPR
   oplot, gvmnz2plot[idxhavezs], h2plot[idxhavezs], COLOR=GV_COLR, LINESTYLE=ST_LINE, thick=3*THIKadjGV
ENDIF

; plot the profile for convective rain type points
prmnz2plot = mnprarr[2,*]
prmnz2plot = prmnz2plot[idxlev2plot]
gvmnz2plot = mngvarr[2,*]
gvmnz2plot = gvmnz2plot[idxlev2plot]
idxhavezs = WHERE( prmnz2plot GT 0.0 and gvmnz2plot GT 0.0, counthavezs )
IF ( counthavezs GT 0 ) THEN BEGIN
   oplot, prmnz2plot[idxhavezs], h2plot[idxhavezs], COLOR=PR_COLR, LINESTYLE=CO_LINE, thick=3*THIKadjPR
   oplot, gvmnz2plot[idxhavezs], h2plot[idxhavezs], COLOR=GV_COLR, LINESTYLE=CO_LINE, thick=3*THIKadjGV
ENDIF

xvals = [15,50]
xvalsleg1 = [37,39] & yvalsleg1 = 18

IF BBparms.meanbb GT 0.0 THEN BEGIN
   yvalsbb = [BBparms.meanbb, BBparms.meanbb]
   plots, xvals, yvalsbb, COLOR=fgcolor, LINESTYLE=2;, THICK=3*THIKadjGV
   yvalsleg2 = 14
   plots, [0.29,0.33], [0.805,0.805], COLOR=fgcolor, /NORMAL, LINESTYLE=2
   XYOutS, 0.34, 0.8, 'Mean BB Hgt', COLOR=fgcolor, CHARSIZE=1*CHARadj, /NORMAL
ENDIF ELSE XYOutS, 0.29, 0.8, 'BB Hgt Unknown', COLOR=fgcolor, CHARSIZE=1*CHARadj, /NORMAL

; - - - - - - - - - - - - - - - - - - - - - - - -

; Compute a mean dBZ difference at each BB proximity layer and plot PDFs

mnprarrbb = fltarr(3,4)  ; each BB-relative level, for raintype all, stratiform, convective
mngvarrbb = fltarr(3,4)  ; each BB-relative level, for raintype all, stratiform, convective
levhasdatabb = intarr(4) & levhasdatabb[*] = 0
levsdatabb = 0
bblevstr = ['Unknown', ' Below', 'Within', ' Above']
xoff = [0.0, 0.0, -0.5, 0.0 ]  ; for positioning legend in PDFs
yoff = [0.0, 0.0, -0.5, -0.5 ]

print, '' & IF (do_ps EQ 1) THEN printf, tempunit, ''
print, '' & IF (do_ps EQ 1) THEN printf, tempunit, ''
textout = 'Statistics grouped by proximity to Bright Band:'
print, textout & IF (do_ps EQ 1) THEN printf, tempunit, textout
print, '' & IF (do_ps EQ 1) THEN printf, tempunit, ''
textout = 'Proxim.|   Any Rain Type  |    Stratiform    |    Convective     |     Dataset Statistics      |     |'
print, textout & IF (do_ps EQ 1) THEN printf, tempunit, textout
textout = ' to BB |  DPR-GR   NumPts |  DPR-GR   NumPts |  DPR-GR   NumPts  | AvgDist   DPR MaxZ  GR MaxZ | BB? |'
print, textout & IF (do_ps EQ 1) THEN printf, tempunit, textout
textout = ' ----- | -------   ------ | -------   ------ | -------   ------  | -------   --------  ------- | --- |'
print, textout & IF (do_ps EQ 1) THEN printf, tempunit, textout

; array to capture indices of array values used for point-to-point mean diffs,
; for each of the 3 bbProx levels
numZpts = N_ELEMENTS(zcor)
idx4hist3 = lonarr(3,numZpts)
idx4hist3[*,*] = -1L
num4hist3 = lonarr(3)
idx4hist = idx4hist3[0,*]

; set up for known versus unknown BB proximity case
IF bbparms.meanBB NE -99.99 THEN BEGIN
   bblevBeg = 1
   bblevEnd = 3
   pmultifac = 4
   pmultirows = 2
ENDIF ELSE BEGIN
   bblevBeg = 0
   bblevEnd = 0
   pmultifac = 3
   pmultirows = 2
ENDELSE

for bblev2get = bblevBeg, bblevEnd do begin
   havematch = 0
   !P.Multi=[pmultifac-bblev2get,2,pmultirows,0,0]
   IF ( num_in_BB_cat[bblev2get] GT 0 ) THEN BEGIN
      flag = ''
      if (bblev2get eq 2) then flag = ' @ BB'
      diffstruc = the_struc
      calc_geo_pr_gv_meandiffs_wght_idx, zcor, gvz, rnType, dist, distcat, bbProx, $
                             bblev2get, dbzcut, rangecut, mnprarrbb, mngvarrbb, $
                             havematch, diffstruc, idx4hist, voldepth
      if(havematch eq 1) then begin
         levsdatabb = levsdatabb + 1
         levhasdatabb[bblev2get] = 1
        ; format level's stats for table output
         stats55 = STRING(diffstruc.meandiff, diffstruc.fullcount, $
                       diffstruc.meandiffs, diffstruc.counts, $
                       diffstruc.meandiffc, diffstruc.countc, $
                       diffstruc.meandist, diffstruc.maxpr, diffstruc.maxgv, $
                       FORMAT='("  ",f7.3,"    ",i4,2("    ",f7.3,"    ",i4),"  ",3("   ",f7.3))' )
        ; capture points used, and format level's stats for graphic plots output
         num4hist3[bblev2get-bblevBeg] = diffstruc.fullcount
         idx4hist3[bblev2get-bblevBeg,*] = idx4hist
         dbzpr2 = zcor[idx4hist[0:diffstruc.fullcount-1]]
         dbzgv2 = gvz[idx4hist[0:diffstruc.fullcount-1]]
         type2 = rnType[idx4hist[0:diffstruc.fullcount-1]]
         bbProx2 = bbProx[idx4hist[0:diffstruc.fullcount-1]]
         mndifhstr = string(diffstruc.AvgDifByHist, FORMAT='(f0.3)')
         mndifstr = string(diffstruc.meandiff, diffstruc.fullcount, FORMAT='(f0.3," (",i0,")")')
         IF diffstruc.countc EQ 0 THEN mndifstrc = 'None' $
         ELSE mndifstrc = string(diffstruc.meandiffc, diffstruc.countc, FORMAT='(f0.3," (",i0,")")')
         IF diffstruc.counts EQ 0 THEN mndifstrs = 'None' $
         ELSE mndifstrs = string(diffstruc.meandiffs, diffstruc.counts, FORMAT='(f0.3," (",i0,")")')
         idx4hist[*] = -1
         textout = STRING(bblevstr[bblev2get], stats55, flag, FORMAT='(a0," ",a0," ",a0)')
         print, textout & IF (do_ps EQ 1) THEN printf, tempunit, textout

        ; Plot the PDF graph for this level
        ; hgtline = 'Layer = ' + bblevstr[bblev2get] + " BB"

        ; DO ANY/ALL RAINTYPE PDFS FIRST
         prhist = histogram(dbzpr2, min=dbzcut, max=maxz4hist, binsize = bs, $
                            locations = prhiststart)
         nxhist = histogram(dbzgv2, min=dbzcut, max=maxz4hist, binsize = bs)
         plot, [15,MAX(prhiststart)],[0,FIX((MAX(prhist)>MAX(nxhist))*1.1)], $
                  /NODATA, COLOR=fgcolor, $
                  XTITLE=bblevstr[bblev2get]+' BB Reflectivity, dBZ', $
                  YTITLE='Number of DPR Footprints', $
                  YRANGE=[ 0, FIX((MAX(prhist)>MAX(nxhist))*1.1) + 1 ], $
                  BACKGROUND=0

         IF ( ~ hideTotals ) THEN BEGIN
            oplot, prhiststart, prhist, COLOR=PR_COLR
            oplot, prhiststart, nxhist, COLOR=GV_COLR
            xyouts, 0.34, 0.95, 'DPR (all)', COLOR=PR_COLR, /NORMAL, $
                    CHARSIZE=1*CHARadj
            plots, [0.29,0.33], [0.955,0.955], COLOR=PR_COLR, /NORMAL
            xyouts, 0.34, 0.925, siteID+' (all)', COLOR=GV_COLR, /NORMAL, $
                    CHARSIZE=1*CHARadj
            plots, [0.29,0.33], [0.93,0.93], COLOR=GV_COLR, /NORMAL
         ENDIF

         headline = 'DPR-'+siteID+' Biases:'
         xyouts, 0.775+xoff[bblev2get],0.925+yoff[bblev2get], headline, $
                 COLOR=fgcolor, /NORMAL, CHARSIZE=1*CHARadj

         mndifline = 'Any/All: ' + mndifstr
         mndiflinec = 'Convective: ' + mndifstrc
         mndiflines = 'Stratiform: ' + mndifstrs
         mndifhline = 'By Area Mean: ' + mndifhstr
         xyouts, 0.775+xoff[bblev2get],0.9+yoff[bblev2get], mndifline, $
                 COLOR=fgcolor, /NORMAL, CHARSIZE=1*CHARadj
         xyouts, 0.775+xoff[bblev2get],0.875+yoff[bblev2get], mndiflinec, $
                 COLOR=fgcolor, /NORMAL, CHARSIZE=1*CHARadj
         xyouts, 0.775+xoff[bblev2get],0.85+yoff[bblev2get], mndiflines, $
                 COLOR=fgcolor, /NORMAL, CHARSIZE=1*CHARadj
; don't show diff-by-area-mean for geo-match, doesn't make as much sense due to
; the PR/GV coverage mismatch at small ranges
;         xyouts, 0.775+xoff[bblev2get],0.825+yoff[bblev2get], mndifhline, $
;                 COLOR=255, /NORMAL, CHARSIZE=1*CHARadj

        ; OVERLAY CONVECTIVE RAINTYPE PDFS, IF ANY POINTS
         idxconvhist= WHERE( type2 EQ RainType_convective, nconv )
         IF ( nconv GT 0 ) THEN BEGIN
           prhist = histogram(dbzpr2[idxconvhist], min=dbzcut, max=maxz4hist, $
                           binsize = bs, locations = prhiststart)
           nxhist = histogram(dbzgv2[idxconvhist], min=dbzcut, max=maxz4hist, binsize = bs)
           oplot, prhiststart, prhist, COLOR=PR_COLR, LINESTYLE=CO_LINE, thick=3*THIKadjPR
           oplot, prhiststart, nxhist, COLOR=GV_COLR, LINESTYLE=CO_LINE, thick=3*THIKadjGV
           xyouts, 0.34, 0.85, 'DPR (Conv)', COLOR=PR_COLR, /NORMAL, CHARSIZE=1*CHARadj
           xyouts, 0.34, 0.825, siteID+' (Conv)', COLOR=GV_COLR, /NORMAL, CHARSIZE=1*CHARadj
           plots, [0.29,0.33], [0.855,0.855], COLOR=PR_COLR, /NORMAL, LINESTYLE=CO_LINE, thick=3*THIKadjPR
           plots, [0.29,0.33], [0.83,0.83], COLOR=GV_COLR, /NORMAL, LINESTYLE=CO_LINE, thick=3*THIKadjGV
         ENDIF

        ; OVERLAY STRATIFORM RAINTYPE PDFS, IF ANY POINTS
         idxstrathist= WHERE( type2 EQ RainType_stratiform, nstrat )
         IF ( nstrat GT 0 ) THEN BEGIN
           prhist = histogram(dbzpr2[idxstrathist], min=dbzcut, max=maxz4hist, $
                           binsize = bs, locations = prhiststart)
           nxhist = histogram(dbzgv2[idxstrathist], min=dbzcut, max=maxz4hist, binsize = bs)
           oplot, prhiststart, prhist, COLOR=PR_COLR, LINESTYLE=ST_LINE, thick=3*THIKadjPR
           oplot, prhiststart, nxhist, COLOR=GV_COLR, LINESTYLE=ST_LINE, thick=3*THIKadjGV
           xyouts, 0.34, 0.9, 'DPR (Strat)', COLOR=PR_COLR, /NORMAL, CHARSIZE=1*CHARadj
           xyouts, 0.34, 0.875, siteID+' (Strat)', COLOR=GV_COLR, /NORMAL, CHARSIZE=1*CHARadj
           plots, [0.29,0.33], [0.905,0.905], COLOR=PR_COLR, /NORMAL, LINESTYLE=ST_LINE, thick=3*THIKadjPR
           plots, [0.29,0.33], [0.88,0.88], COLOR=GV_COLR, /NORMAL, LINESTYLE=ST_LINE, thick=3*THIKadjGV
         ENDIF
 
      endif else begin
         print, "No above-threshold points ", bblevstr[bblev2get], " Bright Band"
      endelse
   ENDIF ELSE BEGIN
      print, "No points at proximity = ", bblevstr[bblev2get], " Bright Band"
      xyouts, 0.6+xoff[bblev2get],0.75+yoff[bblev2get], bblevstr[bblev2get] + $
              " BB: NO POINTS", COLOR=fgcolor, /NORMAL, CHARSIZE=1.5
   ENDELSE

endfor         ; bblev2get = 1,3

IF ( s2ku ) THEN xyouts, 0.29, 0.775, '('+siteID+' Ku-adjusted)', COLOR=GV_COLR, $
                 /NORMAL, CHARSIZE=1*CHARadj

; Write a data identification line at the bottom of the page below the PDF
; plots for Postscript output.  This line also goes at the top of the scatter
; plots, hence the name.

IF ( pctAbvThresh GT 0.0 ) THEN BEGIN
   IF ( pctAbvThresh EQ 100.0 ) THEN gt_ge = "     " ELSE gt_ge = "    >="
   SCATITLE = site+' vs. '+instrument+'.'+swath+"."+version+gt_ge $
              +pctString+"% bins above threshold"
ENDIF ELSE BEGIN
   SCATITLE = site+' vs. '+instrument+'.'+swath+"."+version $
              +" -- All non-missing pairs"
ENDELSE
IF ( do_ps EQ 1 ) THEN xyouts, 0.5, -0.05, scatitle, alignment=0.5, $
        color=fgcolor, /normal, charsize=1., Charthick=1.5


IF ( do_ps EQ 1 ) THEN BEGIN
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
     xyouts, xtext, ytext, '!11'+statstr+'!X', /NORMAL, COLOR=fgcolor, CHARSIZE=0.667
     ytext = ytext - 0.02
   endwhile
   FREE_LUN, tempunit2             ; close the temp file
ENDIF ELSE !p.background=prev_background
; - - - - - - - - - - - - - - - - - - - - - - - -

; Build the Scatter Plots

sat_instr = 'GPM '+instrument
IF bbparms.meanBB EQ -99.99 THEN skipBB=1 ELSE skipBB=0

IF ( do_ps EQ 1 ) THEN BEGIN
   erase
   device,/inches,xoffset=0.25,yoffset=0.55,xsize=8.,ysize=10.,/portrait
   plot_scatter_by_bb_prox_ps, PSFILEpdf, SCATITLE, siteID, zcor, gvz, $
                            rnType, bbProx, num4hist3, idx4hist3, S2KU=s2ku, $
                            SAT_INSTR=sat_instr, SKIP_BB=skipBB
ENDIF ELSE BEGIN
   plot_scatter_by_bb_prox, SCATITLE, siteID, zcor, gvz, rnType, bbProx, $
                            num4hist3, idx4hist3, windowsize, S2KU=s2ku, $
                            SAT_INSTR=sat_instr, SKIP_BB=skipBB
ENDELSE

SET_PLOT, orig_device

; - - - - - - - - - - - - - - - - - - - - - - - -

; Build the PPI animation loop.

; Check that we have as many sweeps as (startelev+elevs2show); if not, adjust
; elevs2show

IF (startelev LE mygeometa.num_sweeps ) THEN BEGIN
   IF (elevs2show+startelev) LE mygeometa.num_sweeps THEN BEGIN
        nframes = elevs2show
   ENDIF ELSE BEGIN
        nframes = mygeometa.num_sweeps - (startelev + 1)
        print, ""
        print, ""
        print, "Number of sweeps present = ", mygeometa.num_sweeps
        print, "First, Last sweep requested = ", startelev+1, ',', startelev+elevs2show
        print, "Number of sweeps to show (adjusted): ", nframes
   ENDELSE
ENDIF ELSE BEGIN
     elevs2show = 1
     nframes = 1
     startelev = mygeometa.num_sweeps - 1
     print, ""
     print, ""
     print, "Number of sweeps present = ", mygeometa.num_sweeps
     print, "First, Last sweep requested = ", startelev+1, ',', startelev+elevs2show
     print, "Showing only sweep number: ", startelev+1
ENDELSE

IF ( elevs2show EQ 0 ) THEN GOTO, nextFile

; plot to pixmap for animations, else display the window if one frame only
do_pixmap=0
IF ( elevs2show GT 1 ) THEN BEGIN
   do_pixmap=1
   retain = 0
   print, ""
   print, "Please wait while PPI image animation is being built..."
ENDIF ELSE retain = 2

!P.MULTI=[0,1,1]
IF ( N_ELEMENTS(windowsize) NE 1 ) THEN windowsize = 375
xsize = windowsize[0]
ysize = xsize

nppis=1
IF ( PPIbyThresh ) THEN nppis=2

; set up the orientation of the PPIs - side-by-side, or vertical
IF (PPIorient) THEN BEGIN
   nx = nppis
   ny = 2
ENDIF ELSE BEGIN
   nx = 2
   ny = nppis
ENDELSE

; only need this window if not in batch mode
IF ( show_ppis ) THEN window, 2, xsize=xsize*nx, ysize=ysize*ny, xpos = 75, $
        TITLE = title, PIXMAP=do_pixmap, RETAIN=retain

; instantiate animation widget, if multiple PPIs
IF nframes GT 1 AND show_ppis THEN $
   xinteranimate, set=[xsize*nx, ysize*ny, nframes], /TRACK

error = 0
loadcolortable, 'CZ', error
if error then begin
    print, ''
    print, "In geo_match_z_plots: error from loadcolortable"
    something = ""
    READ, something, PROMPT='Hit Return to proceed to next case, Q to Quit: '
    goto, errorExit2
endif

CASE FIX(pctAbvThresh) OF
     100 : post_title = ", for "+pctString+"% of DPR/GR bins above threshold"
       0 : post_title = ", all non-missing DPR/GR pairs"
    ELSE : post_title = ", for "+'!m'+STRING("142B)+pctString+"% of DPR/GR bins above threshold"
ENDCASE

FOR ifram=0,nframes-1 DO BEGIN
   elevstr =  string(mysweeps[ifram+startelev].elevationAngle, FORMAT='(f0.1)')
   prtitle = "DPR "+instrument+" "+swath+" "+version+" "+mygeometa.atimeNearestApproach $
             +" on GR PPI"
   myprbuf = plot_sweep_2_zbuf( zcor_in, mysite.site_lat, mysite.site_lon, xCorner, $
                             yCorner, pr_index, mygeometa.num_footprints, $
                             ifram+startelev, rntype4ppi, MAXRNGKM=mygeometa.rangeThreshold, $
                             WINSIZ=windowsize, TITLE=prtitle, BGWHITE=bgwhite )
   gvtitle = mysite.site_ID+" at "+elevstr+" degrees, "+mysweeps[ifram].atimeSweepStart
   mygvbuf = plot_sweep_2_zbuf( gvz_in, mysite.site_lat, mysite.site_lon, xCorner, $
                             yCorner, pr_index, mygeometa.num_footprints, $
                             ifram+startelev, rntype4ppi, MAXRNGKM=mygeometa.rangeThreshold, $
                             WINSIZ=windowsize, TITLE=gvtitle, BGWHITE=bgwhite )
   IF ( PPIbyThresh ) THEN BEGIN
      prtitle = "DPR "+version+post_title
      myprbuf2 = plot_sweep_2_zbuf( zcor_in2, mysite.site_lat, mysite.site_lon, xCorner, $
                                 yCorner, pr_index, mygeometa.num_footprints, $
                                 ifram+startelev, rntype4ppi, MAXRNGKM=mygeometa.rangeThreshold, $
                                 WINSIZ=windowsize, TITLE=prtitle, BGWHITE=bgwhite )
      gvtitle = mysite.site_ID+post_title
      mygvbuf2 = plot_sweep_2_zbuf( gvz_in2, mysite.site_lat, mysite.site_lon, xCorner, $
                                 yCorner, pr_index, mygeometa.num_footprints, $
                                 ifram+startelev, rntype4ppi, MAXRNGKM=mygeometa.rangeThreshold, $
                                 WINSIZ=windowsize, TITLE=gvtitle, BGWHITE=bgwhite )
   ENDIF

   IF ( show_ppis ) THEN BEGIN
      SET_PLOT, 'X'
      device, decomposed=0
      TV, myprbuf, 0
      TV, mygvbuf, 1
      IF ( PPIbyThresh ) THEN BEGIN
         TV, myprbuf2, 2
         TV, mygvbuf2, 3
      ENDIF
   ENDIF

   IF ( do_ps EQ 1 ) THEN BEGIN  ; plot the PPIs to the postscript file
      set_plot,/copy,'ps'
      erase
      TV, myprbuf, 0, /inches, xsize=4, ysize=4
      TV, mygvbuf, 1, /inches, xsize=4, ysize=4
      IF ( PPIbyThresh ) THEN BEGIN
         TV, myprbuf2, 2, /inches, xsize=4, ysize=4
         TV, mygvbuf2, 3, /inches, xsize=4, ysize=4
      ENDIF
      SET_PLOT, orig_device
   ENDIF

   IF nframes GT 1 AND show_ppis THEN xinteranimate, frame = ifram, window=2
ENDFOR

IF nframes GT 1 AND show_ppis THEN BEGIN
   print, ''
   print, 'Click END ANIMATION button or close Animation window to proceed to next case:
   xinteranimate, looprate, /BLOCK
ENDIF

; - - - - - - - - - - - - - - - - - - - - - - -

nextFile:

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

something = ""
IF nframes LT 2 AND show_ppis THEN BEGIN
   print, ''
   READ, something, PROMPT='Hit Return to proceed to next case, Q to Quit: '
ENDIF
IF ( elevs2show GT 0 AND nframes GT 0 AND show_ppis ) THEN WDELETE, 2

errorExit2:

if ( levsdata NE 0 ) THEN BEGIN
   if ( do_ps EQ 0 ) THEN WDELETE, 0
   if ( do_ps EQ 0 ) THEN WDELETE, 3
endif else begin
   if haveWinZero EQ 1 THEN WDELETE, 0  ;clear profile/pdf plot with error text only
endelse

status = 0
IF something EQ 'Q' OR something EQ 'q' THEN status = 1

errorExit:

return, status
end

;===============================================================================
;
; MODULE 2:  geo_match_z_pdf_profile_ppi_bb_prox_sca_ps
;
; DESCRIPTION
; -----------
; Driver for the geo_match_z_plots function (included).  Sets up user/default
; parameters defining the plots and animations, and the method by which the next
; case is selected: either prompt the user to select the file, or just take the
; next one in the sequence.
;
; PARAMETERS
; ----------
; looprate     - initial animation rate for the PPI animation loop on startup.
;                Defaults to 3 if unspecified or outside of allowed 0-100 range
;
; elevs2show   - number of PPIs to display in the PPI image animation, starting
;                at a specifed elevation angle in the volume, in the form 'N.s',
;                where N is the number of PPIs to show, and s is the starting
;                sweep (1-based, where 1 = first). Disables PPI plot if N <= 0,
;                static plot if N = 1. Defaults to N=7.1 if unspecified.  If s
;                is zero or if only N is specified, then s = 1.
;
; ncpath       - local directory path to the geo_match netCDF files' location.
;                Defaults to /data/netcdf/geo_match
;
; sitefilter   - file pattern which acts as the filter limiting the set of input
;                files showing up in the file selector or over which the program
;                will iterate, depending on the select mode parameter. Default=*
;
; no_prompt    - method by which the next file in the set of files defined by
;                ncpath and sitefilter is selected. Binary parameter. If unset,
;                defaults to DialogPickfile()
;
; ppi_vertical - controls orientation for PPI plot/animation subpanels. Binary 
;                parameter. If unset, or if SHOW_THRESH_PPI is On, then defaults
;                to horizontal (PR PPI to left of GV PPI).  If set, then PR PPI
;                is plotted above the GV PPI
;
; ppi_size     - size in pixels of each subpanel in PPI plot.  Default=375
;
; pctAbvThresh - constraint on the percent of bins in the geometric-matching
;                volume that were above their respective thresholds, specified
;                at the time the geo-match dataset was created.  Essentially a
;                measure of "beam-filling goodness".  100 means use only those
;                matchup points where all the PR and GV bins in the volume
;                averages were above threshold (complete volume filled with
;                above threshold bin values).  0 means use all matchup points
;                available, with no regard for thresholds (the default, if no
;                pctAbvThresh value is specified)
;
; show_thresh_ppi - Binary parameter, controls whether to create and display a
;                   2nd set of PPIs plotting only those PR and GR points meeting
;                   the pctAbvThresh constraint.  If set to On, then ppi_vertical
;                   defaults to horizontal (PR on left, GR on right)
;
; gv_convective - GV reflectivity threshold at/above which GV data are considered
;                 to be of Convective Rain Type.  Disabled (= 0.0) if unspecified.
;                 If set to <= 0, then GV reflectivity is ignored in evaluating
;                 whether PR-indicated Stratiform Rain Type matches GV type.
;
; gv_stratiform - GV reflectivity threshold at/below which GV data are considered
;                 to be of Stratiform Rain Type.  Disabled (= 0.0) if unspecified.
;                 If set to <= 0, then GV reflectivity is ignored in evaluating
;                 whether PR-indicated Convective Rain Type matches GV type.
;
; histo_Width   - Bin size to be used in generating histograms for the PDF plots.
;                 Default = 2.0 (dBZ)
;
; hide_totals   - Binary parameter, controls whether to show (default) or hide
;                 the PDF and profile plots for rain type = "Any".
;
; ps_dir        - Directory to which postscript output will be written.  If not
;                 specified, output is directed only to the screen.
;
; b_w           - Binary parameter, controls whether to plot PDFs in Postscript
;                 file in color (default) or in black-and-white.
;
; batch         - Binary parameter, controls whether to plot anything to display
;                 in Postscript mode.
;
; s2ku          - Binary parameter, controls whether or not to apply the Liao/
;                 Meneghini S-band to Ku-band adjustment GV reflectivity.
;                 Default = no
; bgwhite       - Binary parameter, controls whether to plot PDF/Profile and PPI
;                 plot backgrounds as black (default) or white (if set to ON).
;
;-------------------------------------------------------------------------------

pro geo_match_z_comparisons_dpr, SPEED=looprate, $
                                 ELEVS2SHOW=elevs2show, $
                                 NCPATH=ncpath, $
                                 SITE=sitefilter, $
                                 NO_PROMPT=no_prompt, $
                                 PPI_VERTICAL=ppi_vertical, $
                                 PPI_SIZE=ppi_size, $
                                 PCT_ABV_THRESH=pctAbvThresh, $
                                 SHOW_THRESH_PPI=show_thresh_ppi, $
                                 GV_CONVECTIVE=gv_convective, $
                                 GV_STRATIFORM=gv_stratiform, $
                                 HISTO_WIDTH=histo_Width, $
                                 HIDE_TOTALS=hide_totals, $
                                 PS_DIR=ps_dir, $
                                 B_W=b_w, $
                                 BATCH=batch, $
                                 S2KU = s2ku, $
                                 BGWHITE = bgwhite

;-------------------------------------------------------------------------------

print
print, "#################################################################"
print, "#           GEO_MATCH_Z_COMPARISONS_DPR: Version 1.0            #"
print, "#  Statistical Analysis Program for DPR-GR Geometry-Match data  #"
print, "#          NASA/GSFC/GPM Ground Validation, April 2014          #"
print, "#################################################################"
print

; set up the loop speed for xinteranimate, 0<= speed <= 100
IF ( N_ELEMENTS(looprate) EQ 1 ) THEN BEGIN
  IF ( looprate LT 0 OR looprate GT 100 ) THEN looprate = 3
ENDIF ELSE BEGIN
   looprate = 3
ENDELSE

; set up the starting and max # of sweeps to show in animation loop
IF ( N_ELEMENTS(elevs2show) NE 1 ) THEN BEGIN
   print, "Defaulting to 7 for the number of PPI levels to plot, ", $
          "starting with the first."
   elevs2show = 7
   startelev = 0
ENDIF ELSE BEGIN
   IF ( elevs2show LE 0 ) THEN BEGIN
      print, "Disabling PPI animation plot, ELEVS2SHOW <= 0"
      elevs2show = 0
      startelev = 0
   ENDIF ELSE BEGIN
     ; determine whether an INT or a FLOAT was specified
      e2sType = SIZE( elevs2show, /TYPE )
      CASE e2sType OF
        2 : startelev = 0          ; an integer elevs2show was input
        4 : BEGIN                  ; a FLOAT elevs2show was input
              etemp = elevs2show+.00001   ; make temp copy
              elevs2show = FIX( etemp )   ; extract the whole part as elevs2show
             ; extract the tenths part as the starting sweep number
              startelev = ( FIX( (etemp - elevs2show)*10.0 ) - 1 ) > 0
            END
      ENDCASE
      print, "PPIs to plot = ", elevs2show, ", Starting sweep = ", startelev + 1
   ENDELSE
ENDELSE

IF ( N_ELEMENTS(ncpath) NE 1 ) THEN BEGIN
   print, "Defaulting to /data/gpmgv/netcdf/geo_match for file path."
   pathpr = '/data/gpmgv/netcdf/geo_match'
ENDIF ELSE pathpr = ncpath

IF ( N_ELEMENTS(sitefilter) NE 1 ) THEN BEGIN
   print, "Defaulting to GRtoDPR* for file pattern."
   ncfilepatt = '*'
ENDIF ELSE ncfilepatt = '*'+sitefilter+'*'

PPIorient = keyword_set(ppi_vertical)
PPIbyThresh = keyword_set(show_thresh_ppi)
hideTotals = keyword_set(hide_totals)
b_w = keyword_set(b_w)
s2ku = keyword_set(s2ku)

IF ( N_ELEMENTS(ppi_size) NE 1 ) THEN BEGIN
   print, "Defaulting to 375 for PPI size."
   ppi_size = 375
ENDIF

IF ( N_ELEMENTS(histo_Width) NE 1 ) THEN BEGIN
   print, "Defaulting to 2.0 (dBZ) for PDF Histogram bins."
   histo_Width = 2.0
ENDIF

; Decide which PR and GV points to include, based on percent of expected points
; in bin-averaged results that were above dBZ thresholds set when the matchups
; were done.  If unspecified or set to zero, include all points regardless of
; 'completeness' of the volume averages.

IF ( N_ELEMENTS(pctAbvThresh) NE 1 ) THEN BEGIN
   print, "Defaulting to 0 for PERCENT BINS ABOVE THRESHOLD."
   pctAbvThresh = 0.0
ENDIF ELSE BEGIN
   pctAbvThresh = FLOAT(pctAbvThresh)
   IF ( pctAbvThresh LT 0.0 OR pctAbvThresh GT 100.0 ) THEN BEGIN
      print, "Invalid value for PCT_ABV_THRESH: ", pctAbvThresh, $
             ", must be between 0 and 100."
      print, "Defaulting to 0 for PERCENT BINS ABOVE THRESHOLD."
      pctAbvThresh = 0.0
   ENDIF
END      
   
; Set up for theDPR-GR rain type matching based on GV reflectivity

IF ( N_ELEMENTS(gv_Convective) NE 1 ) THEN BEGIN
   print, "Disabling GV Convective floor threshold."
   gvConvective = 0.0
ENDIF ELSE BEGIN
   gvConvective = FLOAT(gv_Convective)
ENDELSE

IF ( N_ELEMENTS(gv_Stratiform) NE 1 ) THEN BEGIN
   print, "Disabling to GV Stratiform ceiling threshold."
   gvStratiform = 0.0
ENDIF ELSE BEGIN
   gvStratiform = FLOAT(gv_Stratiform)
ENDELSE

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
         IF NOT ( N_ELEMENTS(PS_DIR) NE 0 AND KEYWORD_SET(batch) ) THEN BEGIN
           ; set up for bailout prompt every 5 cases if animating PPIs w/o file prompt
            doodah = ""
            IF ( ((fnum+1) MOD 5) EQ 0 AND elevs2show GT 1 AND no_prompt ) THEN BEGIN $
                READ, doodah, $
                PROMPT='Hit Return to do next 5 cases, Q to Quit, D to Disable this bail-out option: '
                IF doodah EQ 'Q' OR doodah EQ 'q' THEN break
                IF doodah EQ 'D' OR doodah EQ 'd' THEN no_prompt=0   ; never ask again
            ENDIF
         ENDIF ELSE BEGIN
            print, ''
            print, 'Processing all cases in Postscript batch mode.'
            print, ''
         ENDELSE
        ;
         ncfilepr = prfiles(fnum)
         action = 0
         action = geo_match_z_plots( ncfilepr, looprate, elevs2show, startelev, $
                                     PPIorient, ppi_size, pctAbvThresh, PPIbyThresh, $
                                     gvconvective, gvstratiform, histo_Width, $
                                     hideTotals, PS_DIR=ps_dir, B_W=b_w, BATCH=batch, $
                                     S2KU=s2ku, BGWHITE=bgwhite )

         if (action) then break
      endfor
   endelse
ENDIF ELSE BEGIN
   ncfilepr = dialog_pickfile(path=pathpr, filter = ncfilepatt)
   while ncfilepr ne '' do begin
      action = 0
      action=geo_match_z_plots( ncfilepr, looprate, elevs2show, startelev, $
                                PPIorient, ppi_size, pctAbvThresh, PPIbyThresh, $
                                gvconvective, gvstratiform, histo_Width, $
                                hideTotals, PS_DIR=ps_dir, B_W=b_w, BATCH=batch, $
                                S2KU=s2ku, BGWHITE=bgwhite )
      if (action) then break
      ncfilepr = dialog_pickfile(path=pathpr, filter = ncfilepatt)
   endwhile
ENDELSE

print, "" & print, "Done!"
END
