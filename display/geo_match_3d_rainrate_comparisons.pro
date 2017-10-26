;===============================================================================
;+
; Copyright © 2010, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; geo_match_3d_rainrate_comparisons.pro
; - Morris/SAIC/GPM_GV  March 2010
;
; DESCRIPTION
; -----------
; Performs a case-by-case statistical analysis of geometry-matched PR and GR
; rain rate from data contained in a geo-match netCDF file.  Rain rate for GR
; is taken from the geo-match file if this field is flagged as available,
; otherwise it is derived from the volume-averaged GR reflectivity using a Z-R 
; relationship.  PR rainrate is the volume-averaged rain rate stored in the
; netCDF file and previously derived from the 3-D rainrate in the 2A-25 product.
;
; INTERNAL MODULES
; ----------------
; 1) geo_match_3d_rainrate_comparisons - Main procedure called by user.  Checks
;                                        input parameters and sets defaults.
;
; 2) geo_match_rr_plots - Workhorse procedure to read data, compute statistics,
;                         create vertical profile, histogram, scatter plots, and
;                         tables of PR-GR rainrate differences, and display PR
;                         and GR reflectivity PPI plots in an animation sequence.
;
; 3) print_table_headers - Does what it says.
;
;
; NON-SYSTEM ROUTINES CALLED
; --------------------------
; 1) fprep_geo_match_profiles()
; 2) z_r_rainrate()
; 3) calc_geo_pr_gv_meandiffs_wght_idx
; 4) plot_scatter_by_bb_prox_ps
; 5) plot_scatter_by_bb_prox
; 6) plot_geo_match_ppi_anim_ps
;
;
; HISTORY
; -------
; 03/05/10 Morris, GPM GV, SAIC
; - Created from geo_match_z_pdf_profile_ppi_bb_prox_sca_ps_ptr.pro, now
;   modified to compute rain rate differences
; 07/22/13 Morris, GPM GV, SAIC
; - Added siteID to parameter lists in calls to plot_scatter_by_bb_prox and
;   plot_scatter_by_bb_prox_ps.
; 07/26/13 Morris, GPM GV, SAIC
; - Added capability to use GR rain rate field from matchup netcdf file if
;   available, otherwise compute GR rain rate with Z-R relationship.
; - Added PPI_IS_RR to calling parameters with logic to control whether Z or
;   rain rate is shown in the second set of PPIs when SHOW_THRESH_PPI is set.
; 08/14/13 Morris, GPM GV, SAIC
; - Modified the log scale bin categories for histogram plots to match the
;   practical range of rain rates.  Defined fixed labels for the PDF x-axes.
; 08/15/13 Morris, GPM GV, SAIC
; - Removed unused 'histo_Width' parameter and 'bs' variable from internal
;   modules and external call to calc_geo_pr_gv_meandiffs_wght_idx.
; 09/13/13 Morris, GPM GV, SAIC
; - Added print_table_headers() module.
; 02/05/14 Morris, GPM GV, SAIC
; - Added HIDE_RNTYPE and USE_ZR keyword parameters to control output content.
; - Added display of HID and D0 dual-polarization PPIs for version 2.3 matchups.
; - Moved code to plot PPI images/animation to external utility function
;   plot_geo_match_ppi_anim_ps().  Placed variables needed by this function into
;   a structure, or created a pointer to them for large data arrays.
; 02/05/14 Morris, GPM GV, SAIC
; - Added error catching to the WDELETE statement calls to prevent crashing
;   when user closes static windows manually.
; - Added prologue section NON-SYSTEM ROUTINES CALLED.
; 02/17/14 Morris, GPM GV, SAIC
; - Added display of RHOhv, Zdr and Kdp dual-polarization PPIs for version 2.3
;   files.
; 04/30/14 Morris, GPM GV, SAIC
; - Added ptr_valid checks to version 2.3 variables to eliminate errors reading
;   older netCDF matchup file versions.
; 06/10/14 Morris, GPM GV, SAIC
; - Added ability to display both PR and DPR matchup products, and handle cases
;   where the Bright Band height is undetermined.
; 06/11/14 Morris, GPM GV, SAIC
; - Took out hard-coding of rain3 and gvrr variables in preparation for making
;   this into a more generic procedure able to display Z difference stats, etc.
; 03/13/15  Morris/GPM GV/SAIC
; - Added show_ppis parameter and logic to disable PPI plots if configured for
;   batch runs (future capability).
; - Added logic to deal with different have_XX_rainrate tags between PR and DPR
;   in myflags structure.
; - Added logic to reset path in dialog_pickfile to the last selected filepath
;   now that we have a complicated directory structure for matchup files.
; - Added RECALL_NCPATH keyword and logic to define a user-defined system
;   variable to remember and use the last-selected file path to override the
;   NCPATH and/or the default netCDF file path on startup of the procedure, if
;   the RECALL_NCPATH keyword is set and user system variable is defined in the
;   IDL session.
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;===============================================================================
;
; MODULE 3:  print_table_headers
;

pro print_table_headers, var1, var2, BB_LAYERS=bb_layers, PS_UNIT=tempunit

IF N_ELEMENTS(tempunit) EQ 1 THEN do_ps=1 ELSE do_ps=0

; set up spacing based on lengths of var1 and var2
CASE (STRLEN(var1)*10+STRLEN(var2)) OF
   22 : BEGIN
           diffvar = ' '+var1+'-'+var2
           maxvars = ' '+ var1 + 'MaxRR   '+ var2 +'MaxRR'
        END
   23 : BEGIN
           diffvar = var1+'-'+var2
           maxvars = ' '+ var1 + 'MaxRR  '+ var2 +'MaxRR'
        END
   32 : BEGIN
           diffvar = var1+'-'+var2
           maxvars = var1 + 'MaxRR   '+ var2 +'MaxRR'
        END
   ELSE : message, 'illegal string lengths for var1 and var2, must sum to 4 or 5'
ENDCASE

IF N_ELEMENTS(bb_layers) EQ 0 THEN BEGIN
   ; print the header for stats broken out by CAPPI levels and rain type
   print, '' & IF (do_ps EQ 1) THEN printf, tempunit, ''
   textout = 'Statistics grouped by fixed height levels (km):'
   print, textout & IF (do_ps EQ 1) THEN printf, tempunit, textout
   print, '' & IF (do_ps EQ 1) THEN printf, tempunit, ''
   textout = ' Vert. |   Any Rain Type  |    Stratiform    |' $
             +'    Convective     |     Dataset Statistics      |'
   print, textout & IF (do_ps EQ 1) THEN printf, tempunit, textout
   textout = ' Layer | '+diffvar+'    NumPts | '+diffvar+'    NumPts |' $
             +' '+diffvar+'    NumPts  | AvgDist  '+maxvars+' |'
   print, textout & IF (do_ps EQ 1) THEN printf, tempunit, textout
   textout = ' ----- | -------   ------ | -------   ------ |' $
             +' -------   ------  | -------  --------  -------- |'
   print, textout & IF (do_ps EQ 1) THEN printf, tempunit, textout

ENDIF ELSE BEGIN
   ; print the header for stats broken out by BB proximity
   print, '' & IF (do_ps EQ 1) THEN printf, tempunit, ''
   print, '' & IF (do_ps EQ 1) THEN printf, tempunit, ''
   textout = 'Statistics grouped by proximity to Bright Band:'
   print, textout & IF (do_ps EQ 1) THEN printf, tempunit, textout
   print, '' & IF (do_ps EQ 1) THEN printf, tempunit, ''
   textout = 'Surface|   Any Rain Type  |    Stratiform    |' $
             +'    Convective     |     Dataset Statistics      |'
   print, textout & IF (do_ps EQ 1) THEN printf, tempunit, textout
   textout = ' type  | '+diffvar+'    NumPts | '+diffvar+'    NumPts |' $
             +' '+diffvar+'    NumPts  | AvgDist  '+maxvars+' |'
   print, textout & IF (do_ps EQ 1) THEN printf, tempunit, textout
   textout = ' ----- | -------   ------ | -------   ------ |' $
             +' -------   ------  | -------  --------  -------- |'
   print, textout & IF (do_ps EQ 1) THEN printf, tempunit, textout

ENDELSE

end

;===============================================================================
;
; MODULE 2:  geo_match_rr_plots
;
; DESCRIPTION
; -----------
; Reads PR and GR rainrate, Z, and spatial fields from a user-selected geo_match
; netCDF file, builds index arrays of categories of range, rain type, bright
; band proximity (above, below, within), and an array of actual range. 
; Computes mean PR-GR rainrate differences for each of the 3 bright band
; proximity levels for points within 100 km of the ground radar and reports the
; results in a table to stdout.  Also produces graphs of the Probability
; Density Function of PR and GR rainrate at each of these 3
; levels if data exists at that level, and vertical profiles of
; mean PR and GR rainrate, for each of 3 rain type categories: Any,
; Stratiform, and Convective. Optionally produces a single frame or an
; animation loop of GR and equivalent PR PPI images for N=elevs2show frames.
; PR footprints in the PPIs are encoded by rain type by pattern: solid=Other,
; vertical=Convective, horizontal=Stratiform.
;
; If PS_DIR is specified then the output is to a Postscript file under ps_dir,
; otherwise all output is to the screen.  When outputting to Postscript, the
; PPI animation is still to the screen but the PDF and scatter plots go to the
; Postscript device, as well as a copy of the last frame of the PPI images in
; the animation loop.  The name of the Postscript file uses the station ID,
; datestamp, and orbit number taken from the geo_match netCDF data file.
; If b_w is set, then Postscript output will be black and white, otherwise it's
; in color.
;
; If s2ku binary parameter is set, then the Liao/Meneghini S-to-Ku band
; reflectivity adjustment will be made to the GR reflectivity used to compute
; the GR rainrate.

FUNCTION geo_match_rr_plots, ncfilepr, looprate, elevs2show, startelev, $
                             PPIorient, windowsize, pctabvthresh, PPIbyThresh, $
                             gvconvective, gvstratiform, hideTotals, $
                             hide_rntype, pr_or_dpr, PS_DIR=ps_dir, B_W=b_w, $
                             S2KU=s2ku, ZR=zr_force

; "include" file for read_geo_match_netcdf() structs returned
@geo_match_nc_structs.inc

; "include" file for PR data constants
@pr_params.inc

bname = file_basename( ncfilepr )
prlen = strlen( bname )
pctString = STRTRIM(STRING(FIX(pctabvthresh)),2)
parsed = STRSPLIT( bname, '.', /extract )
site = parsed[1]
yymmdd = parsed[2]
orbit = parsed[3]
version = parsed[4]
IF pr_or_dpr EQ 'DPR' THEN BEGIN
   swath=parsed[6]
   instrument=parsed[5]
ENDIF ELSE BEGIN
   swath='NS'
   instrument='Ku'
  ; leave this here for now, expect PR V08x version labels soon, though
   CASE version OF
        '6' : BREAK
        '7' : BREAK
       ELSE : version = '?'
   ENDCASE
ENDELSE

; set up pointers for each field to be returned from fprep_geo_match_profiles()
ptr_geometa=ptr_new(/allocate_heap)
ptr_sweepmeta=ptr_new(/allocate_heap)
ptr_sitemeta=ptr_new(/allocate_heap)
ptr_fieldflags=ptr_new(/allocate_heap)
ptr_gvz=ptr_new(/allocate_heap)
ptr_gvrr=ptr_new(/allocate_heap)     ; new for Version 2.2 matchup file
ptr_BestHID=ptr_new(/allocate_heap)       ; new for Version 2.3 matchup file
ptr_GR_DP_Dzero=ptr_new(/allocate_heap)   ; new for Version 2.3 matchup file
ptr_GR_DP_Zdr=ptr_new(/allocate_heap)     ; new for Version 2.3 matchup file
ptr_GR_DP_Kdp=ptr_new(/allocate_heap)     ; new for Version 2.3 matchup file
ptr_GR_DP_RHOhv=ptr_new(/allocate_heap)   ; new for Version 2.3 matchup file
ptr_zcor=ptr_new(/allocate_heap)
ptr_zraw=ptr_new(/allocate_heap)
ptr_rain3=ptr_new(/allocate_heap)
ptr_top=ptr_new(/allocate_heap)
ptr_botm=ptr_new(/allocate_heap)
ptr_lat=ptr_new(/allocate_heap)
ptr_lon=ptr_new(/allocate_heap)
ptr_nearSurfRain=ptr_new(/allocate_heap)
ptr_nearSurfRain_Comb=ptr_new(/allocate_heap)
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
ptr_pctgoodrrgv=ptr_new(/allocate_heap)   ; new for Version 2.2 matchup file

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

CASE pr_or_dpr OF
  'PR' : BEGIN
    PRINT, "INSTRUMENT: ", pr_or_dpr
    status = fprep_geo_match_profiles( ncfilepr, heights, $
    PCT_ABV_THRESH=pctAbvThresh, S2KU=s2ku, PTRfieldflags=ptr_fieldflags, $
    PTRgeometa=ptr_geometa, PTRsweepmeta=ptr_sweepmeta, PTRsitemeta=ptr_sitemeta, $
    PTRGVZMEAN=ptr_gvz, PTRzcor=ptr_zcor, PTRzraw=ptr_zraw, PTRrain3d=ptr_rain3, $
    PTRGVRRMEAN=ptr_gvrr, PTRGVMODEHID=ptr_BestHID, PTRGVDZEROMEAN=ptr_GR_DP_Dzero, $
    PTRGVZDRMEAN=ptr_GR_DP_Zdr, PTRGVKDPMEAN=ptr_GR_DP_Kdp, PTRGVRHOHVMEAN=ptr_GR_DP_RHOhv, $
    PTRtop=ptr_top, PTRbotm=ptr_botm, PTRlat=ptr_lat, PTRlon=ptr_lon, $
    PTRsfcrainpr=ptr_nearSurfRain, PTRsfcraincomb=ptr_nearSurfRain_Comb, $
    PTRrainflag_int=ptr_rnFlag, PTRraintype_int=ptr_rnType, $
    PTRxCorners=ptr_xCorner, PTRyCorners=ptr_yCorner, PTRbbProx=ptr_bbProx, $
    PTRhgtcat=ptr_hgtcat, PTRdist=ptr_dist, PTRpridx_long=ptr_pr_index, $
    PTRpctgoodpr=ptr_pctgoodpr, PTRpctgoodgv=ptr_pctgoodgv, $
    PTRpctgoodrain=ptr_pctgoodrain, PTRpctgoodrrgv=ptr_pctgoodrrgv, BBPARMS=BBparms )
 END
  'DPR' : BEGIN
    PRINT, "INSTRUMENT: ", pr_or_dpr
    status = fprep_dpr_geo_match_profiles( ncfilepr, heights, $
    PCT_ABV_THRESH=pctAbvThresh, S2KU=s2ku, PTRfieldflags=ptr_fieldflags, $
    PTRgeometa=ptr_geometa, PTRsweepmeta=ptr_sweepmeta, PTRsitemeta=ptr_sitemeta, $
    PTRGVZMEAN=ptr_gvz, PTRzcor=ptr_zcor, PTRzraw=ptr_zraw, PTRrain3d=ptr_rain3, $
    PTRGVRRMEAN=ptr_gvrr, PTRGVMODEHID=ptr_BestHID, PTRGVDZEROMEAN=ptr_GR_DP_Dzero, $
    PTRGVZDRMEAN=ptr_GR_DP_Zdr, PTRGVKDPMEAN=ptr_GR_DP_Kdp, PTRGVRHOHVMEAN=ptr_GR_DP_RHOhv, $
    PTRtop=ptr_top, PTRbotm=ptr_botm, PTRlat=ptr_lat, PTRlon=ptr_lon, $
    PTRsfcrainpr=ptr_nearSurfRain, PTRsfcraincomb=ptr_nearSurfRain_Comb, $
    PTRrainflag_int=ptr_rnFlag, PTRraintype_int=ptr_rnType, $
    PTRxCorners=ptr_xCorner, PTRyCorners=ptr_yCorner, PTRbbProx=ptr_bbProx, $
    PTRhgtcat=ptr_hgtcat, PTRdist=ptr_dist, PTRpridx_long=ptr_pr_index, $
    PTRpctgoodpr=ptr_pctgoodpr, PTRpctgoodgv=ptr_pctgoodgv, $
    PTRpctgoodrain=ptr_pctgoodrain, PTRpctgoodrrgv=ptr_pctgoodrrgv, BBPARMS=BBparms )
 END
ENDCASE

IF (status EQ 1) THEN GOTO, errorExit

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

  haveGVRR = 0                             ; not used, see have_gvrr
  IF ptr_valid(ptr_gvrr) THEN BEGIN
     gvrr=*ptr_gvrr
     gvrr_in = gvrr ; for plotting as PPI
     haveGVRR = 1                          ; not used, see have_gvrr
     ptr_free,ptr_gvrr
  ENDIF

  haveHID = 0                          ; first check myflags values for all these?
  IF ptr_valid(ptr_BestHID) THEN BEGIN
     HIDcat=*ptr_BestHID
     haveHID = 1
     ptr_free,ptr_BestHID
  ENDIF

  haveD0 = 0
  IF ptr_valid(ptr_GR_DP_Dzero) THEN BEGIN
     Dzero=*ptr_GR_DP_Dzero
     haveD0 = 1
     ptr_free,ptr_GR_DP_Dzero
  ENDIF

  haveZdr = 0
  IF ptr_valid(ptr_GR_DP_Zdr) THEN BEGIN
     Zdr=*ptr_GR_DP_Zdr
     haveZdr = 1
     ptr_free,ptr_GR_DP_Zdr
  ENDIF

  haveKdp = 0
  IF ptr_valid(ptr_GR_DP_Kdp) THEN BEGIN
     Kdp=*ptr_GR_DP_Kdp
     haveKdp = 1
     ptr_free,ptr_GR_DP_Kdp
  ENDIF

  haveRHOhv = 0
  IF ptr_valid(ptr_GR_DP_RHOhv) THEN BEGIN
     RHOhv=*ptr_GR_DP_RHOhv
     haveRHOhv = 1
     ptr_free,ptr_GR_DP_RHOhv
  ENDIF

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
    ptr_free,ptr_nearSurfRain_Comb
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
  IF ptr_valid(ptr_pctgoodrrgv) THEN BEGIN
     pctgoodrrgv=*ptr_pctgoodrrgv
     ptr_free,ptr_pctgoodrrgv
  ENDIF

show_ppis=1   ; initialize to ON, override if PS and (TBD) BATCH both are set

 ; open a file to hold output stats to be appended to the Postscript file,
 ; if Postscript output is indicated
  IF KEYWORD_SET( ps_dir ) THEN BEGIN
     do_ps = 1
     IF KEYWORD_SET( batch ) THEN show_ppis=0     ; don't display PPIs/animation
     temptext = ps_dir + '/dbzdiffstats_temp.txt'
     OPENW, tempunit, temptext, /GET_LUN
  ENDIF ELSE do_ps = 0

nfp = mygeometa.num_footprints
nswp = mygeometa.num_sweeps
site_lat = mysite.site_lat
site_lon = mysite.site_lon
siteID = string(mysite.site_id)
nsweeps = mygeometa.num_sweeps

 ; initialize flag as to source of GR rain rate to use
 ; -for now, we just default to looking for the "RR" rain rate field until we
 ; add the necessary parameter to look at an alternate GR source in the files
  have_gvrr = 0

  IF pr_or_dpr EQ 'DPR' THEN BEGIN
;     CASE gr_rr_field OF
;        'RC' : IF ptr_valid(ptr_gvrc) THEN BEGIN
;                 gvrr=*ptr_gvrc
;                 gvrr_in = gvrr
;                 ptr_free,ptr_gvrc
;                 have_gvrr=myflags.have_GR_RC_rainrate
;               ENDIF
;        'RP' : IF ptr_valid(ptr_gvrp) THEN BEGIN
;                 gvrr=*ptr_gvrp
;                 gvrr_in = gvrr
;                 ptr_free,ptr_gvrp
;                 have_gvrr=myflags.have_GR_RP_rainrate
;              ENDIF
;        ELSE : IF ptr_valid(ptr_gvrr) THEN BEGIN
;                 gvrr=*ptr_gvrr
;                 gvrr_in = gvrr
;                 ptr_free,ptr_gvrr
                 have_gvrr=myflags.have_GR_RR_rainrate
;               ENDIF
;     ENDCASE
  ENDIF ELSE BEGIN
;    IF ptr_valid(ptr_gvrr) THEN BEGIN
;       gvrr=*ptr_gvrr
;       gvrr_in = gvrr ; for plotting as PPI
;       ptr_free,ptr_gvrr
       have_gvrr=myflags.have_GR_rainrate   ; should just be 0 for version<2.2
;    ENDIF
  ENDELSE
; override flag if forcing Z-R usage
IF KEYWORD_SET(zr_force) THEN have_gvrr = 0
print, ''
IF (have_gvrr) THEN BEGIN
   print, "Using GR RR field."
   var2='RR'
ENDIF ELSE BEGIN
   print, "Using GR RR from Z-R."
   var2='ZR'
ENDELSE
print, ''

; For each 'column' of data, find the maximum GR reflectivity value for the
;  footprint, and use this value to define a GR match to the PR-indicated rain type.
;  Using Default GR dBZ thresholds of >=35 for "GV Convective" and <=25 for 
;  "GV Stratiform", or other GR dBZ thresholds provided as user parameters,
;  set PR rain type to "other" (3) where: PR type is Convective and GR is not, or
;  PR is Stratiform and GR indicates Convective.  For GR reflectivities between
;  'gvstratiform' and 'gvconvective' thresholds, leave the PR rain type as-is.

print, ''
max_gvz_per_fp = MAX( gvz, DIMENSION=2)
IF ( gvstratiform GT 0.0 ) THEN BEGIN
   idx2other = WHERE( rnType[*,0] EQ 2 AND max_gvz_per_fp LE gvstratiform, count2other )
   IF ( count2other GT 0 ) THEN rnType[idx2other,*] = 3
   fmtstrng='("No. of footprints switched from Convective to Other = ",I0,",' $
            +' based on Stratiform dBZ threshold = ",F0.1)'
   print, FORMAT=fmtstrng, count2other, gvstratiform
ENDIF ELSE BEGIN
   print, "Leaving PR Convective Rain Type assignments unchanged."
ENDELSE
IF ( gvconvective GT 0.0 ) THEN BEGIN
   idx2other = WHERE( rnType[*,0] EQ 1 AND max_gvz_per_fp GE gvconvective, count2other )
   IF ( count2other GT 0 ) THEN rnType[idx2other,*] = 3
   fmtstrng='("No. of footprints switched from Stratiform to Other = ",I0,",' $
            +' based on Convective dBZ threshold = ",F0.1)'
   print, FORMAT=fmtstrng, count2other, gvconvective
ENDIF ELSE BEGIN
   print, "Leaving PR Stratiform Rain Type assignments unchanged."
ENDELSE

; make a copy of the adjusted rain type field for use in PPI plots
rntype4ppi = REFORM( rnType[*,0] )
; if rain type "hiding" is on, set all samples to "Other" rain type
hide_rntype = KEYWORD_SET( hide_rntype )
IF hide_rntype THEN rnType4ppi[*] = 3

; - - - - - - - - - - - - - - - - - - - - - - - -

; optional data *clipping* based on percent completeness of the volume averages:
; Decide which PR and GR points to include, based on percent of expected points
; in bin-averaged results that were above dBZ thresholds set when the matchups
; were done.  If unspecified or set to zero, include all points regardless of
; 'completeness' of the volume averages.


IF ( pctAbvThresh GT 0.0 ) THEN BEGIN
    ; clip to the 'good' points, where 'pctAbvThresh' fraction of bins in average
    ; were above threshold
   if have_gvrr then begin
      thresh_msg = "Thresholding by rain rate cutoff."
      idxgoodenuff = WHERE( pctgoodrrgv GE pctAbvThresh $
                       AND  pctgoodrain GE pctAbvThresh, countgoodpct )
   endif else begin
      thresh_msg = "Thresholding by reflectivity cutoffs."
      idxgoodenuff = WHERE( pctgoodpr GE pctAbvThresh $
                       AND  pctgoodgv GE pctAbvThresh, countgoodpct )
   endelse
   IF ( countgoodpct GT 0 ) THEN BEGIN
       IF have_gvrr EQ 0 THEN gvrr = z_r_rainrate(gvz[idxgoodenuff]) $  ; override empty field
          ELSE gvrr=gvrr[idxgoodenuff]   ; using scaled GR rainrate from matchup file
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
;       pr_index = pr_index[idxgoodenuff] : NO! don't clip - must be full array for PPIs
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
   IF have_gvrr EQ 0 THEN gvrr = z_r_rainrate(gvz) $    ; override empty field
      ELSE gvrr=gvrr   ; using scaled GR rainrate from matchup file
   IF ( PPIbyThresh ) THEN BEGIN
      idx2plot=WHERE( pctgoodpr GE 0.0 AND  pctgoodgv GE 0.0, countactual2d )
      n2plot=countactual2d
   ENDIF
ENDELSE

; we only use unclipped arrays for PPIs, so we make full copies of these arrays
gvz_in2 = gvz_in
zcor_in2 = zcor_in
rain3_in2 = rain3_in
IF have_gvrr EQ 0 THEN BEGIN
   gvrr_in2 = z_r_rainrate(gvz_in)
   gvrr_in2 = REFORM( gvrr_in2, nfp, nswp)
ENDIF ELSE gvrr_in2 = gvrr_in

; optional data *blanking* based on percent completeness of the volume averages
; for PPI plots, operating on the full arrays of gvz and zcor

IF ( PPIbyThresh ) THEN BEGIN
   idx3d = LONG( gvz_in )   ; make a copy
  ; re-set this for our later use in PPI plotting
   idx3d[*,*] = 0L       ; initialize all points to 0
   idx3d[idx2plot] = 2L  ; tag the points to be plotted in post-threshold PPI
   idx2blank = WHERE( idx3d EQ 0L, count2blank )
   IF ( count2blank GT 0 ) THEN BEGIN
     gvz_in2[idx2blank] = 0.0
     zcor_in2[idx2blank] = 0.0
     rain3_in2[idx2blank] = 0.0
     gvrr_in2[idx2blank] = 0.0
   ENDIF
ENDIF

; determine the non-missing points-in-common between PR and GR, data value-wise,
; to make sure the same points are plotted on PR and GR full/post-threshold PPIs
idx2blank2 = WHERE( (gvz_in2 LT 0.0) OR (zcor_in2 LE 0.0) $
                    OR (rain3_in2 LT 0.0) OR (gvrr_in2 LT 0.0), count2blank2 )
IF ( count2blank2 GT 0 ) THEN BEGIN
   gvz_in2[idx2blank2] = 0.0
   zcor_in2[idx2blank2] = 0.0
   rain3_in2[idx2blank2] = 0.0
   gvrr_in2[idx2blank2] = 0.0
ENDIF

; - - - - - - - - - - - - - - - - - - - - - - - -

; build an array of range categories from the GV radar, using ranges previously
; computed from lat and lon by fprep_geo_match_profiles():
; - range categories: 0 for 0<=r<50, 1 for 50<=r<100, 2 for r>=100, etc.
;   (for now we only have points roughly inside 100km, so limit to 2 categs.)
distcat = ( FIX(dist) / 50 ) < 1

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

;minz4hist = 18.  ; not used, replaced with dbzcut
maxz4hist = 55.
dbzcut = 0.1 ;10.      ; absolute PR/GR dBZ cutoff of points to use in mean diff. calcs.
rangecut = 100.

; define a structure to hold difference statistics computed within and returned
; by the called function calc_geo_pr_gv_meandiffs_wght_idx()
the_struc = { diffsset, $
              meandiff: -99.999, meandist: -99.999, fullcount: 0L,  $
              maxpr: -99.999, maxgv: -99.999, $
              meandiffc: -99.999, countc: 0L, $
              meandiffs: -99.999, counts: 0L, $
              AvgDifByHist: -99.999 $
            }

print, ''
CASE pr_or_dpr OF
  'PR' : textout = pr_or_dpr + '-GR Rain Rate difference statistics (mm/h) - GR Site: ' + $
          siteID + '   Orbit: ' + orbit + '   V'+version
  'DPR' : BEGIN
          textout = Instrument+'-GR Reflectivity difference statistics (dBZ) - GR Site: '+siteID
          print, textout & IF (do_ps EQ 1) THEN printf, tempunit, textout
          textout = 'Orbit: '+orbit+'  Version: '+version+'  Swath Type: '+swath
          END
ENDCASE
print, textout & IF (do_ps EQ 1) THEN printf, tempunit, textout
textout = pr_or_dpr + ' time = ' + mygeometa.atimeNearestApproach + $
          '   GR start time = ' + mysweeps[0].atimeSweepStart
print, textout & IF (do_ps EQ 1) THEN printf, tempunit, textout
textout = 'Required percent of above-threshold ' + pr_or_dpr + $
          ' and GR bins in matched volumes >= '+pctString+"%"
print, textout & IF (do_ps EQ 1) THEN printf, tempunit, textout
IF ( pctAbvThresh GT 0.0 ) THEN BEGIN
   print, thresh_msg & IF (do_ps EQ 1) THEN printf, tempunit, thresh_msg
ENDIF
IF ( s2ku ) THEN BEGIN
   textout = 'GR reflectivity has S-to-Ku frequency adjustments applied.'
   print, textout & IF (do_ps EQ 1) THEN printf, tempunit, textout
ENDIF
;print, '' & IF (do_ps EQ 1) THEN printf, tempunit, ''

mnprarr = fltarr(3,nhgtcats)  ; each level, for raintype all, stratiform, convective
mngvarr = fltarr(3,nhgtcats)  ; each level, for raintype all, stratiform, convective
levhasdata = intarr(nhgtcats) & levhasdata[*] = 0
levsdata = 0
max_hgt_w_data = 0.0

; - - - - - - - - - - - - - - - - - - - - - - - -

sources = [['PR','RR'],['PR','ZR']]
; Figure out which of the 2nd sources is the one matching var2, the source to
; plot vs. PR in the PDF/profile and scatter plots.  Won't need in the loop
; over levels, but will need it later in the loop over surface types
idx4pdfprof=where(sources[1,*] EQ var2)
isources = idx4pdfprof
rntype2use = rnType

src1 = sources[0,isources]
src2 = sources[1,isources]
; we set up the CASE for all possibilities, though src1 is always PR here
CASE src1 OF
    'PR' : BEGIN
              yvar = rain3
              rntype2use = rnType
           END
    'RR' : yvar = gvrr
    'ZR' : yvar = gvrr
ENDCASE
CASE src2 OF
    'PR' : BEGIN
              xvar = rain3
              rntype2use = rnType
           END
    'RR' : xvar = gvrr
    'ZR' : xvar = gvrr
ENDCASE

; use 'PR' or 'DPR' in place of src1 in table headers
;print_table_headers, src1, src2, PS_UNIT=tempunit
print_table_headers, pr_or_dpr, src2, PS_UNIT=tempunit

; Compute a mean rainrate difference at each level

for lev2get = 0, nhgtcats-1 do begin
   havematch = 0
   thishgt = (lev2get+1)*hgtinterval
   IF ( num_in_hgt_cat[lev2get] GT 0 ) THEN BEGIN
      flag = ''
      idx4hist = lonarr(num_in_hgt_cat[lev2get])  ; array indices used for point-to-point mean diffs
      idx4hist[*] = -1L
      if (lev2get eq BBparms.BB_HgtLo OR lev2get eq BBparms.BB_HgtHi) then flag = ' @ BB'
      diffstruc = the_struc
      calc_geo_pr_gv_meandiffs_wght_idx, yvar, xvar, rnType, dist, distcat, $
                                         hgtcat, lev2get, dbzcut, rangecut, $
                                         mnprarr, mngvarr, havematch, $
                                         diffstruc, idx4hist, voldepth
      if(havematch eq 1) then begin
         levsdata = levsdata + 1
         levhasdata[lev2get] = 1
         max_hgt_w_data = thishgt
        ; format level's stats for table output
         FMT55 = '(3("    ",f7.3,"    ",i4),"  ",3("   ",f7.3))'
         stats55 = STRING(diffstruc.meandiff, diffstruc.fullcount, $
                          diffstruc.meandiffs, diffstruc.counts, $
                          diffstruc.meandiffc, diffstruc.countc, $
                          diffstruc.meandist, diffstruc.maxpr, diffstruc.maxgv, $
                          FORMAT = FMT55 )
        ; extract/format level's stats for graphic plots output
         mndifhstr = string(diffstruc.AvgDifByHist, FORMAT='(f0.3)')
         mndifstr = string(diffstruc.meandiff, diffstruc.fullcount, FORMAT='(f0.3," (",i0,")")')
         mndifstrc = string(diffstruc.meandiffc, diffstruc.countc, FORMAT='(f0.3," (",i0,")")')
         mndifstrs = string(diffstruc.meandiffs, diffstruc.counts, FORMAT='(f0.3," (",i0,")")')
         idx4hist[*] = -1L
         textout = STRING(heights[lev2get], stats55, flag, FORMAT='(" ",f4.1,a0," ",a0)')
         print, textout & IF (do_ps EQ 1) THEN printf, tempunit, textout
      endif else begin
         textout = "No above-threshold points at height " + $
                   STRING(heights[lev2get], FORMAT='(f0.3)')
         print, textout & IF (do_ps EQ 1) THEN printf, tempunit, textout
      endelse
   ENDIF ELSE BEGIN
      print, "No points at height " + string(heights[lev2get], FORMAT='(f0.3)')
   ENDELSE

endfor         ; lev2get = 0, nhgtcats-1

; - - - - - - - - - - - - - - - - - - - - - - - -

; Build the mean RR profile plot panel

orig_device = !D.NAME

IF ( do_ps EQ 1 ) THEN BEGIN
  ; set up postscript plot params. and file path/name
   cd, ps_dir
   b_w = keyword_set(b_w)
   IF ( s2ku ) THEN add2nm = '_S2Ku' ELSE add2nm = ''
   PSFILEpdf = ps_dir+'/'+site+'.'+yymmdd+'.'+orbit+"."+version+'.'+pr_or_dpr+'.' $
               +instrument+'.'+swath+'.Pct'+pctString+add2nm+'_RR_PDF_SCATR.ps'
   print, "Output sent to ", PSFILEpdf
   set_plot,/copy,'ps'
   device,filename=PSFILEpdf,/color,bits=8,/inches,xoffset=0.25,yoffset=2.55, $
          xsize=8.,ysize=8.

   ; Set up color table
   ;
   common colors, r_orig, g_orig, b_orig, r_curr, g_curr, b_curr ;load color table
   IF ( b_w EQ 0) THEN  LOADCT, 6  ELSE  LOADCT, 33
   ncolor=255
   red=bytarr(256) & green=bytarr(256) & blue=bytarr(256)
   red=r_curr & green=g_curr & blue=b_curr
   red(0)=255 & green(0)=255 & blue(0)=255
   red(1)=115 & green(1)=115 & blue(1)=115  ; gray for GR
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
   THIKadjGV=1.5
   ST_THK=1
   CO_THK=1
ENDIF ELSE BEGIN
  ; set up x-window plot params.
   device, decomposed = 0
   LOADCT, 2

   IF ( pctAbvThresh GT 0.0 ) THEN BEGIN
      IF ( pctAbvThresh EQ 100.0 ) THEN gt_ge = '= ' ELSE gt_ge = '>= '
      wintxt = "With % of averaged bins above dBZ thresholds "+gt_ge+pctString+"%"
   ENDIF ELSE BEGIN
      wintxt = "With all non-missing "+pr_or_dpr+"/GR matched samples"
   ENDELSE

   Window, xsize=700, ysize=700, TITLE = site+' vs. '+instrument+'.'+swath+"."+version+ $
           "  --  "+wintxt, RETAIN=2
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

if (levsdata eq 0) then begin
   print, "No valid data levels found!"
   nframes = 0
   goto, nextFile
endif

idxlev2plot = WHERE( levhasdata EQ 1 )
h2plot = heights[idxlev2plot]

; figure out the y-axis range.  Use the greater of max_hgt_w_data*2.0
; and meanbb*2 as the proposed range.  Cut off at 20 km if result>20.
prop_max_y = max_hgt_w_data*2.0 > (FIX((BBparms.meanbb*2)/1.5) + 1) *1.5
plot, [0.1,150], [0,20 < prop_max_y], /NODATA, COLOR=255, $
      XSTYLE=1, YSTYLE=1, YTICKINTERVAL=hgtinterval, YMINOR=1, thick=1, $
      XTITLE='Level Mean Rain Rate, mm/h', YTITLE='Height Level, km', $
      CHARSIZE=1*CHARadj, BACKGROUND=0, /xlog

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

xvals = [0.1,150]
xvalsleg1 = [37,39] & yvalsleg1 = 18

yvalsbb = [BBparms.meanbb, BBparms.meanbb]
plots, xvals, yvalsbb, COLOR=255, LINESTYLE=2;, THICK=3*THIKadjGV
yvalsleg2 = 14
plots, [0.29,0.33], [0.805,0.805], COLOR=255, /NORMAL, LINESTYLE=2
XYOutS, 0.34, 0.8, 'Mean BB Hgt', COLOR=255, CHARSIZE=1*CHARadj, /NORMAL

; - - - - - - - - - - - - - - - - - - - - - - - -

; Compute a mean rainrate difference at each BB proximity layer and plot PDFs

mnprarrbb = fltarr(3,4)  ; each BB-relative level, for raintype all, stratiform, convective
mngvarrbb = fltarr(3,4)  ; each BB-relative level, for raintype all, stratiform, convective
levhasdatabb = intarr(4) & levhasdatabb[*] = 0
levsdatabb = 0
bblevstr = ['Unknown', ' Below', 'Within', ' Above']
xoff = [0.0, 0.0, -0.5, 0.0 ]  ; for positioning legend in PDFs
yoff = [0.0, 0.0, -0.5, -0.5 ]

;print_table_headers, src1, src2, /BB, PS_UNIT=tempunit
print_table_headers, pr_or_dpr, src2, /BB, PS_UNIT=tempunit

; define a 2D array to capture array indices of values used for point-to-point
; mean diffs, for each of the 3 bbProx levels, for plotting these points in the
; scatter plots
numZpts = N_ELEMENTS(yvar)
idx4hist3 = lonarr(3,numZpts)
idx4hist3[*,*] = -1L
num4hist3 = lonarr(3)  ; track number of points used in each bbProx layer
idx4hist = idx4hist3[0,*]  ; a 1-D array for passing to function in the layer loop

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
      calc_geo_pr_gv_meandiffs_wght_idx, yvar, xvar, rnType, dist, distcat, $
                                         bbProx, bblev2get, dbzcut, rangecut, $
                                         mnprarrbb, mngvarrbb, havematch, $
                                         diffstruc, idx4hist, voldepth
      if(havematch eq 1) then begin
         levsdatabb = levsdatabb + 1
         levhasdatabb[bblev2get] = 1
        ; format level's stats for table output
         FMT55='("  ",f7.3,"    ",i4,2("    ",f7.3,"    ",i4),"  ",3("   ",f7.3))'
         stats55 = STRING(diffstruc.meandiff, diffstruc.fullcount, $
                       diffstruc.meandiffs, diffstruc.counts, $
                       diffstruc.meandiffc, diffstruc.countc, $
                       diffstruc.meandist, diffstruc.maxpr, diffstruc.maxgv, $
                       FORMAT = FMT55 )
        ; capture points used, and format level's stats for graphic plots output
         num4hist3[bblev2get-bblevBeg] = diffstruc.fullcount
         idx4hist3[bblev2get-bblevBeg,*] = idx4hist
         rr_pr2 = yvar[idx4hist[0:diffstruc.fullcount-1]]
         rr_gv2 = xvar[idx4hist[0:diffstruc.fullcount-1]]
         type2 = rnType[idx4hist[0:diffstruc.fullcount-1]]
         bbProx2 = bbProx[idx4hist[0:diffstruc.fullcount-1]]
         mndifhstr = string(diffstruc.AvgDifByHist, FORMAT='(f0.3)')
         mndifstr = string(diffstruc.meandiff, diffstruc.fullcount, $
                           FORMAT='(f0.3," (",i0,")")')
         IF diffstruc.countc EQ 0 THEN mndifstrc = 'None' $
         ELSE mndifstrc = string(diffstruc.meandiffc, diffstruc.countc, $
                                 FORMAT='(f0.3," (",i0,")")')
         IF diffstruc.counts EQ 0 THEN mndifstrs = 'None' $
         ELSE mndifstrs = string(diffstruc.meandiffs, diffstruc.counts, $
                                 FORMAT='(f0.3," (",i0,")")')
         idx4hist[*] = -1
         textout = STRING(bblevstr[bblev2get], stats55, flag, $
                          FORMAT='(a0," ",a0," ",a0)')
         print, textout & IF (do_ps EQ 1) THEN printf, tempunit, textout

        ; Plot the PDF graph for this level
         hgtline = 'Layer = ' + bblevstr[bblev2get] + " BB"

        ; DO ANY/ALL RAINTYPE PDFS FIRST
        ; define a set of "nlogcats" log-spaced interval boundaries
        ; - yields nlogcats+1 rainrate categories
         nlogcats = 16
         logbins = 10^(findgen(nlogcats)/5.-1)
;         logbins = 10^(findgen(18)/5.-1)
        ; figure out index of interval where each point falls:
        ; -- ranges from -1 (below lowest bound) to nlogcats-1 (above highest bound)
         bin4pr = VALUE_LOCATE( logbins, rr_pr2 )
         bin4gr = VALUE_LOCATE( logbins, rr_gv2 )  ; ditto for GR rainrate
        ; compute histogram of log range category, ignoring the lowest (below 0.1 mm/h)
         prhist = histogram( bin4pr, min=0, max=nlogcats-1,locations = prhiststart )
         nxhist = histogram( bin4gr, min=0, max=nlogcats-1,locations = prhiststart )
;         labelbins=[STRING(10^(findgen(9)*2./5.-1),FORMAT='(F6.2)'),'>250.0']
;         print, labelbins
        ; will label every other interval start value on plot, no room for all
         labelbins=['0.10','0.25','0.63','1.58','3.98','10.0','25.1','63','158']
         plot, [0,MAX(prhiststart)],[0,FIX((MAX(prhist)>MAX(nxhist))*1.1)], $
                  /NODATA, COLOR=255, CHARSIZE=1*CHARadj, $
                  XTITLE=bblevstr[bblev2get]+' BB Rain Rate, mm/h', $
                  YTITLE='Number of PR Footprints', $
                  YRANGE=[ 0, FIX((MAX(prhist)>MAX(nxhist))*1.1) + 1 ], $
                  BACKGROUND=0, xtickname=labelbins , $
                  xtickinterval=2,xminor=2

         IF ( ~ hideTotals ) THEN BEGIN
            oplot, prhiststart, prhist, COLOR=PR_COLR
            oplot, prhiststart, nxhist, COLOR=GV_COLR
            xyouts, 0.34, 0.95, pr_or_dpr+' (all)', COLOR=PR_COLR, /NORMAL, $
                    CHARSIZE=1*CHARadj
            plots, [0.29,0.33], [0.955,0.955], COLOR=PR_COLR, /NORMAL
            xyouts, 0.34, 0.925, siteID+' (all)', COLOR=GV_COLR, /NORMAL, $
                    CHARSIZE=1*CHARadj
            plots, [0.29,0.33], [0.93,0.93], COLOR=GV_COLR, /NORMAL
         ENDIF

         headline = pr_or_dpr+'-'+siteID+' Biases:'
         xyouts, 0.775+xoff[bblev2get],0.925+yoff[bblev2get], headline, $
                 COLOR=255, /NORMAL, CHARSIZE=1*CHARadj

         mndifline = 'Any/All: ' + mndifstr
         mndiflinec = 'Convective: ' + mndifstrc
         mndiflines = 'Stratiform: ' + mndifstrs
         mndifhline = 'By Area Mean: ' + mndifhstr
         xyouts, 0.775+xoff[bblev2get],0.9+yoff[bblev2get], mndifline, $
                 COLOR=255, /NORMAL, CHARSIZE=1*CHARadj
         xyouts, 0.775+xoff[bblev2get],0.875+yoff[bblev2get], mndiflinec, $
                 COLOR=255, /NORMAL, CHARSIZE=1*CHARadj
         xyouts, 0.775+xoff[bblev2get],0.85+yoff[bblev2get], mndiflines, $
                 COLOR=255, /NORMAL, CHARSIZE=1*CHARadj

        ; OVERLAY CONVECTIVE RAINTYPE PDFS, IF ANY POINTS
         idxconvhist= WHERE( type2 EQ RainType_convective, nconv )
         IF ( nconv GT 0 ) THEN BEGIN
           bin4pr = VALUE_LOCATE( logbins, rr_pr2[idxconvhist] )  ; see Any/All logic above
           bin4gr = VALUE_LOCATE( logbins, rr_gv2[idxconvhist] )
           prhist = histogram( bin4pr, min=0, max=18,locations = prhiststart )
           nxhist = histogram( bin4gr, min=0, max=18,locations = prhiststart )
           oplot, prhiststart, prhist, COLOR=PR_COLR, LINESTYLE=CO_LINE, $
                  thick=3*THIKadjPR
           oplot, prhiststart, nxhist, COLOR=GV_COLR, LINESTYLE=CO_LINE, $
                  thick=3*THIKadjGV
           xyouts, 0.34, 0.85, pr_or_dpr+' (Conv)', COLOR=PR_COLR, /NORMAL, $
                   CHARSIZE=1*CHARadj
           xyouts, 0.34, 0.825, siteID+' (Conv)', COLOR=GV_COLR, /NORMAL, $
                   CHARSIZE=1*CHARadj
           plots, [0.29,0.33], [0.855,0.855], COLOR=PR_COLR, /NORMAL, $
                  LINESTYLE=CO_LINE, thick=3*THIKadjPR
           plots, [0.29,0.33], [0.83,0.83], COLOR=GV_COLR, /NORMAL, $
                  LINESTYLE=CO_LINE, thick=3*THIKadjGV
         ENDIF

        ; OVERLAY STRATIFORM RAINTYPE PDFS, IF ANY POINTS
         idxstrathist= WHERE( type2 EQ RainType_stratiform, nstrat )
         IF ( nstrat GT 0 ) THEN BEGIN
           bin4pr = VALUE_LOCATE( logbins, rr_pr2[idxstrathist] )  ; see Any/All logic above
           bin4gr = VALUE_LOCATE( logbins, rr_gv2[idxstrathist] )
           prhist = histogram( bin4pr, min=0, max=18,locations = prhiststart )
           nxhist = histogram( bin4gr, min=0, max=18,locations = prhiststart )
           oplot, prhiststart, prhist, COLOR=PR_COLR, LINESTYLE=ST_LINE, $
                  thick=3*THIKadjPR
           oplot, prhiststart, nxhist, COLOR=GV_COLR, LINESTYLE=ST_LINE, $
                  thick=3*THIKadjGV
           xyouts, 0.34, 0.9, pr_or_dpr+' (Strat)', COLOR=PR_COLR, /NORMAL, $
                   CHARSIZE=1*CHARadj
           xyouts, 0.34, 0.875, siteID+' (Strat)', COLOR=GV_COLR, /NORMAL, $
                   CHARSIZE=1*CHARadj
           plots, [0.29,0.33], [0.905,0.905], COLOR=PR_COLR, /NORMAL, $
                  LINESTYLE=ST_LINE, thick=3*THIKadjPR
           plots, [0.29,0.33], [0.88,0.88], COLOR=GV_COLR, /NORMAL, $
                  LINESTYLE=ST_LINE, thick=3*THIKadjGV
         ENDIF
 
      endif else begin
         print, "No above-threshold points ", bblevstr[bblev2get], " Bright Band"
      endelse
   ENDIF ELSE BEGIN
      print, "No points at proximity = ", bblevstr[bblev2get], " Bright Band"
      xyouts, 0.6+xoff[bblev2get],0.75+yoff[bblev2get], bblevstr[bblev2get] + $
              " BB: NO POINTS", COLOR=255, /NORMAL, CHARSIZE=1.5
   ENDELSE

endfor         ; bblev2get = 1,3

IF ( s2ku ) THEN xyouts, 0.29, 0.775, '('+siteID+' Ku-adjusted)', COLOR=GV_COLR, $
                 /NORMAL, CHARSIZE=1*CHARadj

; Write a data identification line at the bottom of the page below the PDF
; plots for Postscript output.  This line also goes at the top of the scatter
; plots, hence the name.

IF (have_gvrr) THEN gr_rr_zr = ' DP RR' ELSE gr_rr_zr = ' Z-R RR'
IF ( pctAbvThresh GT 0.0 ) THEN BEGIN
   IF ( pctAbvThresh EQ 100.0 ) THEN gt_ge = "     " ELSE gt_ge = "    >="
   SCATITLE = site+gr_rr_zr+' vs. '+pr_or_dpr+'.'+instrument+'.'+swath+"." $
              +version+gt_ge+pctString+"% bins above threshold"
ENDIF ELSE BEGIN
   SCATITLE = site+gr_rr_zr+' vs. '+pr_or_dpr+'.'+instrument+'.'+swath+"."+version $
              +" -- All non-missing pairs"
ENDELSE

TITLE2 = "Orbit:  "+orbit+"  --  GR Start Time:  "+mysweeps[0].atimeSweepStart

IF ( do_ps EQ 1 ) THEN BEGIN
   xyouts, 0.5, -0.07, SCATITLE, alignment=0.5, color=255, /normal, $
           charsize=1., Charthick=1.5
   xyouts, 0.5, -0.10, TITLE2, alignment=0.5, color=255, /normal, $
           charsize=1., Charthick=1.5
ENDIF

xlblstr=STRJOIN([STRING(logbins[0:nlogcats-2],FORMAT='(F0.2)'), $
                 '>'+STRING(logbins[nlogcats-1],FORMAT='(F5.1)')], ', ', /single)
print, '' & print, 'Histogram bin lower bounds (mm/h):' & print, xlblstr & print, ''

IF ( do_ps EQ 1 ) THEN BEGIN
   ; write the array of histogram intervals at the bottom of the PDF plot page
   xyouts, 0.05, -0.15, '!11'+'Histogram bin lower bounds (mm/h):'+'!X', $
           /NORMAL, COLOR=255, CHARSIZE=0.667, Charthick=1.5
   xyouts, 0.05, -0.17, '!11'+xlblstr+'!X', /NORMAL, COLOR=255, CHARSIZE=0.667

   erase                 ; start a new page in the PS file for the stat tables
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

; Build the Scatter Plots

IF pr_or_dpr EQ 'PR' THEN sat_instr = pr_or_dpr $
ELSE sat_instr = pr_or_dpr+'/'+instrument+'/'+swath
IF bbparms.meanBB EQ -99.99 THEN skipBB=1 ELSE skipBB=0

;SCATITLE = strmid( bname, 7, 17)+"  --  "+"Percent of bins above thresholds " $
;           +'>= '+pctString+"%"

IF ( do_ps EQ 1 ) THEN BEGIN
   erase
   device,/inches,xoffset=0.25,yoffset=0.55,xsize=8.,ysize=10.,/portrait
   plot_scatter_by_bb_prox_ps, PSFILEpdf, SCATITLE, siteID, yvar, xvar, $
                            rnType, bbProx, num4hist3, idx4hist3, S2KU=s2ku, $
                            MIN_XY=0.5, MAX_XY=150.0, UNITS='mm/h', $
                            SAT_INSTR=sat_instr, SKIP_BB=skipBB
ENDIF ELSE BEGIN
   plot_scatter_by_bb_prox, SCATITLE, siteID, yvar, xvar, rnType, bbProx, $
                            num4hist3, idx4hist3, windowsize, S2KU=s2ku, $
                            MIN_XY=0.5, MAX_XY=150.0, UNITS='mm/h', $
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
        print, "Number of sweeps present = ", mygeometa.num_sweeps
        print, "First, Last sweep requested = ", startelev+1, ',', startelev+elevs2show
        print, "Number of sweeps to show (adjusted): ", nframes
   ENDELSE
ENDIF ELSE BEGIN
     elevs2show = 1
     nframes = 1
     startelev = mygeometa.num_sweeps - 1
     print, "Number of sweeps present = ", mygeometa.num_sweeps
     print, "First, Last sweep requested = ", startelev+1, ',', startelev+elevs2show
     print, "Showing only sweep number: ", startelev+1
ENDELSE

IF ( elevs2show EQ 0 ) THEN GOTO, nextFile
do_pixmap=0
IF ( elevs2show GT 1 ) THEN BEGIN
   do_pixmap=1
   retain = 0
ENDIF ELSE retain = 2

!P.MULTI=[0,1,1]
IF ( N_ELEMENTS(windowsize) NE 1 ) THEN windowsize = 375
xsize = windowsize[0]
ysize = xsize
windownum = 2
title = ""

ppi_comn = { winSize : windowsize, $
             winNum : windownum, $
             winTitle : title, $
             nframes : nframes, $
             startelev : startelev, $
             looprate : looprate, $
             mysweeps : mysweeps, $
             PPIorient : PPIorient, $
             PPIbyThresh : PPIbyThresh, $
             pctString : pctString, $
             site_Lat : mysite.site_lat, $
             site_Lon : mysite.site_lon, $
             site_ID : siteID, $
             xCorner : xCorner, $
             yCorner : yCorner, $
             pr_index : pr_index, $
             mygeometa : mygeometa, $
             rntype4ppi : rntype4ppi }

IF (have_gvrr) THEN gr_rr_zr = ' DP' ELSE gr_rr_zr = ' Z-R'

IF (haveKdp and haveZdr and haveHID) THEN BEGIN
   fieldIDs = [ ['CZ','CZ','DR'], $
                ['RR','RR','FH'], $
                ['KD','D0','RH'] ]
   sources = [ [pr_or_dpr+'/'+instrument, siteID, siteID], $
               [pr_or_dpr+'/'+instrument, siteID+gr_rr_zr, siteID], $
               [siteID,siteID,siteID] ]
   thresholded = [ [0,0,0], $
                   [pctAbvThresh GT 0.0, pctAbvThresh GT 0.0, 0], $
                   [0,0,0] ]
   fieldData = ptrarr(3,3, /allocate_heap)
   *fieldData[0] = zcor_in
   *fieldData[1] = gvz_in
   *fieldData[2] = Zdr
   *fieldData[3] = rain3_in2
   *fieldData[4] = gvrr_in2
   *fieldData[5] = HIDcat
   *fieldData[6] = Kdp
   *fieldData[7] = Dzero
   *fieldData[8] = RHOhv
ENDIF ELSE BEGIN
   fieldIDs = [['CZ','CZ'],['RR','RR']]
   sources = [['PR',siteID],['PR',siteID+gr_rr_zr]]
   thresholded = [[0,0],[pctAbvThresh GT 0.0, pctAbvThresh GT 0.0]]
   fieldData = ptrarr(2,2, /allocate_heap)
   *fieldData[0] = zcor_in
   *fieldData[1] = gvz_in
   *fieldData[2] = rain3_in2
   *fieldData[3] = gvrr_in2
ENDELSE

plot_geo_match_ppi_anim_ps, fieldIDs, sources, fieldData, thresholded, $
                            ppi_comn, SHOW_PPIS=show_ppis, DO_PS=do_ps

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

; - - - - - - - - - - - - - - - - - - - - - - -


something = ""
IF nframes LT 2 AND show_ppis THEN BEGIN
   print, ''
   READ, something, PROMPT='Hit Return to proceed to next case, Q to Quit: '
ENDIF

catch, wdel_err
IF wdel_err EQ 0 THEN BEGIN
   IF ( elevs2show GT 0 AND nframes GT 0 AND show_ppis ) THEN WDELETE, 2
ENDIF ELSE BEGIN
   print, ""
   print, !error_state.MSG
   catch, /CANCEL
   print, "Please do not close non-animating images window manually!  Continue..."
ENDELSE

errorExit2:

if ( levsdata NE 0 ) THEN BEGIN
   catch, wdel_err
   IF wdel_err EQ 0 THEN BEGIN
      if ( do_ps EQ 0 ) THEN WDELETE, 0
   ENDIF ELSE BEGIN
      print, ""
      print, !error_state.MSG
      catch, /CANCEL
      print, "Please do not close profile/PDF window manually!  Continue..."
   ENDELSE
   catch, wdel_err
   IF wdel_err EQ 0 THEN BEGIN
      if ( do_ps EQ 0 ) THEN WDELETE, 3
   ENDIF ELSE BEGIN
      print, ""
      print, !error_state.MSG
      catch, /CANCEL
      print, "Please do not close scatter plot window manually!  Continue..."
   ENDELSE
endif

status = 0
IF something EQ 'Q' OR something EQ 'q' THEN status = 1

errorExit:

return, status
end

;===============================================================================
;
; MODULE 1:  geo_match_3d_rainrate_comparisons
;
; DESCRIPTION
; -----------
; Driver for the geo_match_rr_plots function (included).  Sets up user/default
; parameters defining the plots and animations, and the method by which the next
; case is selected: either prompt the user to select the file, or just take the
; next one in the sequence.
;
; PARAMETERS
; ----------
; instrument   - indicates which satellite radar is to be the source of the
;                matchup data to be analyzed.  Allowable values are 'PR' and
;                'DPR'.  Default='DPR'.  If a mismatch occurs between INSTRUMENT
;                and the type of matchup file selected for processing then an
;                error occurs.  In the case of DPR, the matchup to GR can be for
;                any of the 2AKa, 2AKu, or 2ADPR products, for any swath type.
;
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
;                to horizontal (PR PPI to left of GR PPI).  If set, then PR PPI
;                is plotted above the GR PPI
;
; ppi_size     - size in pixels of each subpanel in PPI plot.  Default=375
;
; pctAbvThresh - constraint on the percent of bins in the geometric-matching
;                volume that were above their respective thresholds, specified
;                at the time the geo-match dataset was created.  Essentially a
;                measure of "beam-filling goodness".  100 means use only those
;                matchup points where all the PR and GR bins in the volume
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
; gv_convective - GR reflectivity threshold at/above which GR data are considered
;                 to be of Convective Rain Type.  Default = 35.0 if not specified.
;                 If set to <= 0, then GR reflectivity is ignored in evaluating
;                 whether PR-indicated Stratiform Rain Type matches GR type.
;
; gv_stratiform - GR reflectivity threshold at/below which GR data are considered
;                 to be of Stratiform Rain Type.  Default = 25.0 if not specified.
;                 If set to <= 0, then GR reflectivity is ignored in evaluating
;                 whether PR-indicated Convective Rain Type matches GR type.
;
; hide_totals   - Binary parameter, controls whether to show (default) or hide
;                 the PDF and profile plots for rain type = "Any".
;
; hide_rntype   - (Optional) binary parameter, indicates whether to use hatching
;                 in the PPI plots indicating the PR rain type identified for
;                 the given ray.
;
; ps_dir        - Directory to which postscript output will be written.  If not
;                 specified, output is directed only to the screen.
;
; b_w           - Binary parameter, controls whether to plot PDFs in Postscript
;                 file in color (default) or in black-and-white.
;
; s2ku          - Binary parameter, controls whether or not to apply the Liao/
;                 Meneghini S-band to Ku-band adjustment to GR reflectivity.
;                 Default = no
;
; use_zr        - Binary parameter, controls whether or not to override the gvrr
;                 (GR rain rate) field in the geo-match netCDF file with a Z-R
;                 derived rain rate
;
; recall_ncpath - Binary parameter.  If set, assigns the last file path used to
;                 select a file in dialog_pickfile() to a user-defined system
;                 variable that stays in effect for the IDL session.  Also, if
;                 set and if the user variable exists from a previous selection,
;                 then the user variable will override the NCPATH parameter
;                 value on program startup.

pro geo_match_3d_rainrate_comparisons, $
                                         INSTRUMENT=instrument, $
                                         SPEED=looprate, $
                                         ELEVS2SHOW=elevs2show, $
                                         NCPATH=ncpath, $
                                         SITE=sitefilter, $
                                         NO_PROMPT=no_prompt, $
                                         PPI_VERTICAL=ppi_vertical, $
                                         PPI_SIZE=ppi_size, $
;                                         PPI_IS_RR=ppi_is_rr, $
                                         PCT_ABV_THRESH=pctAbvThresh, $
                                         SHOW_THRESH_PPI=show_thresh_ppi, $
                                         GV_CONVECTIVE=gv_convective, $
                                         GV_STRATIFORM=gv_stratiform, $
                                         HIDE_TOTALS=hide_totals, $
                                         HIDE_RNTYPE=hide_rntype, $
                                         PS_DIR=ps_dir, $
                                         B_W=b_w, $
                                         S2KU = s2ku, $
                                         USE_ZR = use_zr, $
                                         RECALL_NCPATH=recall_ncpath


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

print, ""
DEFSYSV, '!LAST_NCPATH', EXISTS = haveUserVar
IF KEYWORD_SET(recall_ncpath) AND (haveUserVar EQ 1) THEN BEGIN
   print, "Defaulting to last selected directory for file path:"
   print, !LAST_NCPATH
   print, ""
   pathpr = !LAST_NCPATH
ENDIF ELSE BEGIN
   IF ( N_ELEMENTS(ncpath) NE 1 ) THEN BEGIN
      print, "Defaulting to /data/gpmgv/netcdf/geo_match for file path."
      pathpr = '/data/gpmgv/netcdf/geo_match'
   ENDIF ELSE pathpr = ncpath
ENDELSE

IF ( N_ELEMENTS(instrument) NE 1 ) THEN BEGIN
   print, "Defaulting to DPR for instrument type."
   pr_or_dpr = 'DPR'
ENDIF ELSE BEGIN
   CASE STRUPCASE(instrument) OF
      'PR' : pr_or_dpr = 'PR'
     'DPR' : pr_or_dpr = 'DPR'
      ELSE : message, "Only allowed values for INSTRUMENT are PR and DPR"
   ENDCASE
ENDELSE

IF ( N_ELEMENTS(sitefilter) NE 1 ) THEN BEGIN
   print, "Defaulting to * for file pattern."
   ncfilepatt = '*'
ENDIF ELSE ncfilepatt = '*'+sitefilter+'*'

PPIorient = keyword_set(ppi_vertical)
PPIbyThresh = keyword_set(show_thresh_ppi)
;RR_PPI = keyword_set(ppi_is_rr)
hideTotals = keyword_set(hide_totals)
hideRntype = keyword_set(hide_rntype)
b_w = keyword_set(b_w)
s2ku = keyword_set(s2ku)
zr_force = keyword_set(use_zr)

IF ( N_ELEMENTS(ppi_size) NE 1 ) THEN BEGIN
   print, "Defaulting to 375 for PPI size."
   ppi_size = 375
ENDIF

; Decide which PR and GR points to include, based on percent of expected points
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
   
; Set up for the PR-GR rain type matching based on GR reflectivity

IF ( N_ELEMENTS(gv_Convective) NE 1 ) THEN BEGIN
   print, "Defaulting to 35.0 dBZ for GR Convective floor threshold."
   gvConvective = 35.0
ENDIF ELSE BEGIN
   gvConvective = FLOAT(gv_Convective)
ENDELSE

IF ( N_ELEMENTS(gv_Stratiform) NE 1 ) THEN BEGIN
   print, "Defaulting to 25.0 dBZ for GR Stratiform ceiling threshold."
   gvStratiform = 25.0
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
        ; set up for bailout prompt every 5 cases if animating PPIs w/o file prompt
         doodah = ""
         IF ( ((fnum+1) MOD 5) EQ 0 AND elevs2show GT 1 AND no_prompt ) THEN BEGIN $
             READ, doodah, $
             PROMPT='Hit Return to do next 5 cases, Q to Quit, D to Disable this bail-out option: '
             IF doodah EQ 'Q' OR doodah EQ 'q' THEN break
             IF doodah EQ 'D' OR doodah EQ 'd' THEN no_prompt=0   ; never ask again
         ENDIF
        ;
         ncfilepr = prfiles(fnum)
         action = 0
         action = geo_match_rr_plots( ncfilepr, looprate, elevs2show, startelev, $
                                      PPIorient, ppi_size, pctAbvThresh, PPIbyThresh, $
                                      gvconvective, gvstratiform, hideTotals, $
                                      hideRntype, pr_or_dpr, $
                                      PS_DIR=ps_dir, B_W=b_w, S2KU=s2ku, ZR=zr_force )

         if (action) then break
      endfor
   endelse
ENDIF ELSE BEGIN
   ncfilepr = dialog_pickfile(path=pathpr, filter = ncfilepatt)
   while ncfilepr ne '' do begin
      action = 0
      action=geo_match_rr_plots( ncfilepr, looprate, elevs2show, startelev, $
                                 PPIorient, ppi_size, pctAbvThresh, PPIbyThresh, $
                                 gvconvective, gvstratiform, hideTotals, $
                                 hideRntype, pr_or_dpr, $
                                 PS_DIR=ps_dir, B_W=b_w, S2KU=s2ku, ZR=zr_force )
      if (action) then break
      newpathpr = FILE_DIRNAME(ncfilepr)  ; set the path to the last file's path
      IF KEYWORD_SET(recall_ncpath) THEN BEGIN
         ; define/assign new default path for session as user system variable
          IF (haveUserVar EQ 1) THEN !LAST_NCPATH = newpathpr $
          ELSE DEFSYSV, '!LAST_NCPATH', newpathpr
      ENDIF
      ncfilepr = dialog_pickfile(path=newpathpr, filter = ncfilepatt)
   endwhile
ENDELSE

print, "" & print, "Done!"
END
