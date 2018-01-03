;===============================================================================
;+
; Copyright © 2014, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; geo_match_3d_dsd_comparisons.pro
; - Morris/SAIC/GPM_GV  June 2014
;
; DESCRIPTION
; -----------
; Performs a case-by-case statistical analysis of geometry-matched DPR and GR Z,
; D0, and Nw variables from data contained in a GRtoDPR geo-match netCDF file.
; Only data from the below-bright-band layer is analyzed for D0 and Nw.
;
; INTERNAL MODULES
; ----------------
; 1) geo_match_3d_dsd_comparisons - Main procedure called by user.  Checks
;                                   input parameters and sets defaults.
;
; 2) geo_match_dsd_plots - Workhorse procedure to read data, compute statistics,
;                          create vertical profiles, histogram, scatter plots, 
;                          and tabulations of DPR-GR Dzero and Nw
;                          differences, and display DPR and GR reflectivity,
;                          rainrate, Dm, and Nw, and GR dual-pol field PPI plots
;                          in an animation sequence.
;
;
; NON-SYSTEM ROUTINES CALLED
; --------------------------
; 1) fprep_geo_match_profiles() or fprep_dpr_geo_match_profiles()
; 2) render_dsd_plots
;
;
; HISTORY
; -------
; 06/30/14 Morris, GPM GV, SAIC
; - Created from geo_match_3d_rr_or_z_comparisons.pro
; 10/12/14 Morris, GPM GV, SAIC
; - Added DZERO_ADJ parameter to apply a conversion from D0 to Dm for GR field,
;   and made related plot labeling changes.
; 11/05/14 Morris, GPM GV, SAIC
; - Added GR_RR_FIELD parameter to select which GR rain rate estimate to use:
;   RC (Cifelli), RP (PolZR), or RR (DROPS).  Default=RR (DROPS).
; 01/15/15 Morris/GPM GV, SAIC
; - Made changes to support capability to color-code scatter plot points by
;   height of samples.
; - Changed text in titles to eliminate the DPR.DPR strings in the annotations.
; - Modified titles and text to indicate whether GR is using D0 or Dm adjusted.
; - Configured the x-axis range in profile plots according to the data range to
;   prevent profile clipping at the upper end of the dBZ range.
; - Made the text indicating Ku-adjusted to be Z-plot-specific.
; - Fixed labeling of FH and D0/Dm PPI plots for pctAbvThresh GT 0, fields not
;   thresholded.
; - Temporarly disabled PR option for data file source.
; 03/13/15  Morris/GPM GV/SAIC
; - Added logic to disable satellite Dm and Nw for PR, to control whether PPIs
;   are plotted, to enforce DPR use (no PR), and properly label plots based on
;   pctAbvThresh and PPIbythresh settings.
; - Added logic to reset path in dialog_pickfile to the last selected filepath
;   now that we have a complicated directory structure for matchup files.
; - Added RECALL_NCPATH keyword and logic to define a user-defined system
;   variable to remember and use the last-selected file path to override the
;   NCPATH and/or the default netCDF file path on startup of the procedure, if
;   the RECALL_NCPATH keyword is set and user system variable is defined in the
;   IDL session.
; 04/16/15 Morris, GPM GV, SAIC
; - Added STEP_MANUAL keyword parameter to do a manual step-through animation
;   rather than using XINTERANIMATE utility in plot_geo_match_ppi_anim_ps(), to
;   allow a cleaner screen capture.
; 04/29/15  Morris/GPM GV/SAIC
; - Fixed oversights in reading and processing RC and RP fields from DPR files.
; - Added future structure element rr_field_used to indicate which GR rain rate
;   field is being processed.
; 04/30/15  Morris/GPM GV/SAIC
; - MAJOR REWRITE FOR INTERACTIVE SELECTION OF ANALYSIS SUB-AREAS.
; - Extracted major blocks of code and the internal function print_table_headers
;   that do the statistics, plots, and PDF file output into a new stand alone
;   function module display/render_dsd_plots.pro.
; - Calls new function select_geomatch_subarea() to clip the data arrays to be
;   analyzed to the area around a user selected point.
; 05/08/15  Morris/GPM GV/SAIC
; - Filled in logic to fully implement BATCH option with Postscript output.
; 06/25/15  Morris/GPM GV/SAIC
; - Made changes to logic and status value checks to support multiple storm
;   subset selections for a single case and to not quit unless user explicitly
;   selects that option.
; - Changes to bring this code in line with select_geomatch_subarea() function
;   modified to support DPRGMI matchups.
; 07/16/15 Morris, GPM GV, SAIC
; - Added DECLUTTER keyword option to filter out samples identified as ground
;   clutter affected.
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;===============================================================================
;
; MODULE 2:  geo_match_dsd_plots
;
; DESCRIPTION
; -----------
; Reads PR and GR Z, D0, Nw, and spatial fields from a user-selected geo_match
; netCDF file, builds index arrays of categories of range, rain type, bright
; band proximity (above, below, within), and an array of actual range. Calls
; render_dsd_plots() to compute statistics and produce profiles, histograms,
; scatter plots, and PPI displays of the data. Optionally calls the function
; select_geomatch_subarea() to allow the user to define a "storm subset" of
; the data to display and analyze.  If analyzing a subset of data and a value
; is given for the SAVE_DIR parameter, then the user will be prompted whether to
; save the subset data and other mandatory parameters to render_dsd_plots() in
; an IDL binary SAVE file.

FUNCTION geo_match_dsd_plots, ncfilepr, xxx, looprate, elevs2show, startelev, $
                              PPIorient, windowsize, pctabvthresh, PPIbyThresh, $
                              Z_PPIs, gvconvective, gvstratiform, hideTotals, $
                              hide_rntype, hidePPIs, pr_or_dpr, PS_DIR=ps_dir, $
                              B_W=b_w, S2KU=s2ku, ZR=zr_force, $
                              ALT_BB_HGT=alt_bb_hgt, DZEROFAC=dzerofac, $
                              GR_RR_FIELD=gr_rr_field, GR_DM_FIELD=gr_dm_field, $
                              GR_NW_FIELD=gr_nw_field, BATCH=batch, $
                              MAX_RANGE=max_range, SUBSET_METHOD=submeth, $
                              MIN_FOR_SUBSET=subthresh, SAVE_DIR=save_dir, $
                              STEP_MANUAL=step_manual, DECLUTTER=declutter_in

; "include" file for read_geo_match_netcdf() structs returned
@geo_match_nc_structs.inc

; "include" file for PR data constants
@pr_params.inc

declutter=KEYWORD_SET(declutter_in)
IF (pr_or_dpr NE 'DPR') THEN declutter=0     ; override unless processing DPR

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
   KuKa=parsed[5]
   instrument='2A'+KuKa    ; label used in SAVE file names
   matchup_ver_str=parsed[7]
ENDIF ELSE BEGIN
   swath='NS'
   instrument='Ku'
   KuKa='Ku'
   matchup_ver_str=parsed[5]
  ; leave this here for now, expect PR V08x version labels soon, though
   CASE version OF
        '6' : version = 'V6'
        '7' : version = 'V7'
       ELSE : version = 'V??'
   ENDCASE
ENDELSE

; convert matchup_ver_str in the form N_n into floating N.n
parsedver = STRSPLIT( matchup_ver_str, '_', /extract )
IF N_ELEMENTS(parsedver) EQ 2 THEN BEGIN
   matchup_ver = FLOAT(parsedver[0]+'.'+parsedver[1])
ENDIF ELSE BEGIN
   matchup_ver = 0.0
   message, "Can't format matchup version from filename field " $
            + matchup_ver_str + ', filename ' + bname, /INFO
ENDELSE

; set up pointers for each field to be returned from fprep_geo_match_profiles()
ptr_geometa=ptr_new(/allocate_heap)
ptr_sweepmeta=ptr_new(/allocate_heap)
ptr_sitemeta=ptr_new(/allocate_heap)
ptr_fieldflags=ptr_new(/allocate_heap)
ptr_gvz=ptr_new(/allocate_heap)

; define pointer for GR rain rate only if not using Z-R rainrate
IF KEYWORD_SET(zr_force) EQ 0 THEN BEGIN
   IF pr_or_dpr EQ 'DPR' THEN BEGIN
      ; only define the pointer specific to the rain rate field to be used
      CASE gr_rr_field OF
         'RC' : BEGIN
                   ptr_gvrc=ptr_new(/allocate_heap)
                   ptr_pctgoodrcgv=ptr_new(/allocate_heap)
                END
         'RP' : BEGIN
                   ptr_gvrp=ptr_new(/allocate_heap)
                   ptr_pctgoodrpgv=ptr_new(/allocate_heap)
                END
         'RR' : BEGIN
                   ptr_gvrr=ptr_new(/allocate_heap)
                   ptr_pctgoodrrgv=ptr_new(/allocate_heap)
                END
         ELSE : BEGIN
                   ptr_gvrr=ptr_new(/allocate_heap)
                   ptr_pctgoodrrgv=ptr_new(/allocate_heap)
                END
      ENDCASE
   ENDIF ELSE BEGIN
      ptr_gvrr=ptr_new(/allocate_heap)     ; new for Version 2.2 PR matchup
      ptr_pctgoodrrgv=ptr_new(/allocate_heap)
   ENDELSE
ENDIF

ptr_BestHID=ptr_new(/allocate_heap)       ; new for Version 2.3 matchup file
ptr_GR_DP_Dzero=ptr_new(/allocate_heap)   ; new for Version 2.3 matchup file
ptr_GR_DP_Zdr=ptr_new(/allocate_heap)     ; new for Version 2.3 matchup file
ptr_GR_DP_Kdp=ptr_new(/allocate_heap)     ; new for Version 2.3 matchup file
ptr_GR_DP_RHOhv=ptr_new(/allocate_heap)   ; new for Version 2.3 matchup file
ptr_GR_DP_Nw=ptr_new(/allocate_heap)      ; new for Version 2.3 matchup file
ptr_zcor=ptr_new(/allocate_heap)
ptr_zraw=ptr_new(/allocate_heap)
ptr_rain3=ptr_new(/allocate_heap)
IF ( pr_or_dpr EQ 'DPR' ) THEN BEGIN
  ; currently only DPR matchups provide Dm and Nw for satellite radar
   ptr_dprdm=ptr_new(/allocate_heap)
   ptr_dprnw=ptr_new(/allocate_heap)
;   IF matchup_ver GT 1.1 THEN BEGIN
      ptr_GR_DP_Dm=ptr_new(/allocate_heap)      ; new for Version 1.2 GRtoDPR matchup file
      ptr_GR_DP_N2=ptr_new(/allocate_heap)      ; ditto
;   ENDIF
ENDIF
ptr_top=ptr_new(/allocate_heap)
ptr_botm=ptr_new(/allocate_heap)
ptr_lat=ptr_new(/allocate_heap)
ptr_lon=ptr_new(/allocate_heap)
ptr_pia=ptr_new(/allocate_heap)
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
ptr_pctgoodDprDm=ptr_new(/allocate_heap)
ptr_pctgoodDprNw=ptr_new(/allocate_heap)
IF KEYWORD_SET(declutter) THEN ptr_clutterStatus=ptr_new(/allocate_heap)

; structure to hold bright band variables
BBparms = {meanBB : -99.99, BB_HgtLo : -99, BB_HgtHi : -99}

; Define the list of fixed-height levels for the vertical profile statistics
;heights = [1.5,3.0,4.5,6.0,7.5,9.0,10.5,12.0,13.5,15.0,16.5,18.0,19.5]
;hgtinterval = 1.5
;heights = [1.0,1.5,2.0,2.5,3.0,3.5,4.0,4.5,5.0,5.5,6.0,6.5,7.0,7.5]
;hgtinterval = 0.5
heights = [1.,2.,3.,4.,5.,6.,7.,8.]
hgtinterval = 1.0

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
    PTRtop=ptr_top, PTRbotm=ptr_botm, PTRlat=ptr_lat, PTRlon=ptr_lon, PTRpia=ptr_pia, $
    PTRsfcrainpr=ptr_nearSurfRain, PTRsfcraincomb=ptr_nearSurfRain_Comb, $
    PTRrainflag_int=ptr_rnFlag, PTRraintype_int=ptr_rnType, $
    PTRxCorners=ptr_xCorner, PTRyCorners=ptr_yCorner, PTRbbProx=ptr_bbProx, $
    PTRhgtcat=ptr_hgtcat, PTRdist=ptr_dist, PTRpridx_long=ptr_pr_index, $
    PTRpctgoodpr=ptr_pctgoodpr, PTRpctgoodgv=ptr_pctgoodgv, $
    PTRpctgoodrain=ptr_pctgoodrain, PTRpctgoodrrgv=ptr_pctgoodrrgv, BBPARMS=BBparms, $
    ALT_BB_HGT=alt_bb_hgt )
 END
  'DPR' : BEGIN
    PRINT, "INSTRUMENT: ", pr_or_dpr
    status = fprep_dpr_geo_match_profiles( ncfilepr, heights, $
    PCT_ABV_THRESH=pctAbvThresh, S2KU=s2ku, PTRfieldflags=ptr_fieldflags, $
    PTRgeometa=ptr_geometa, PTRsweepmeta=ptr_sweepmeta, PTRsitemeta=ptr_sitemeta, $
    PTRGVZMEAN=ptr_gvz, PTRzcor=ptr_zcor, PTRzraw=ptr_zraw, PTRrain3d=ptr_rain3, $
    PTRdprdm=ptr_dprDm, PTRdprnw=ptr_dprNw, PTRGVNWMEAN=ptr_GR_DP_Nw, $
    PTRGVRRMEAN=ptr_gvrr, PTRGVRCMEAN=ptr_gvrc, PTRGVRPMEAN=ptr_gvrp, $
    PTRGVMODEHID=ptr_BestHID, PTRGVDZEROMEAN=ptr_GR_DP_Dzero, $
    PTRGVDMMEAN=ptr_GR_DP_Dm, PTRGVN2MEAN=ptr_GR_DP_N2, $
    PTRGVZDRMEAN=ptr_GR_DP_Zdr, PTRGVKDPMEAN=ptr_GR_DP_Kdp, PTRGVRHOHVMEAN=ptr_GR_DP_RHOhv, $
    PTRtop=ptr_top, PTRbotm=ptr_botm, PTRlat=ptr_lat, PTRlon=ptr_lon, PTRpia=ptr_pia, $
    PTRsfcrainpr=ptr_nearSurfRain, PTRsfcraincomb=ptr_nearSurfRain_Comb, $
    PTRrainflag_int=ptr_rnFlag, PTRraintype_int=ptr_rnType, $
    PTRxCorners=ptr_xCorner, PTRyCorners=ptr_yCorner, PTRbbProx=ptr_bbProx, $
    PTRhgtcat=ptr_hgtcat, PTRdist=ptr_dist, PTRpridx_long=ptr_pr_index, $
    PTRpctgoodpr=ptr_pctgoodpr, PTRpctgoodgv=ptr_pctgoodgv, $
    PTRpctgoodrain=ptr_pctgoodrain, PTRpctgoodrcgv=ptr_pctgoodrcgv, $
    PTRpctgoodrpgv=ptr_pctgoodrpgv, PTRpctgoodrrgv=ptr_pctgoodrrgv, $
    PTRpctgoodDprDm=ptr_pctgoodDprDm, PTRpctgoodDprNw=ptr_pctgoodDprNw, $
    PTRclutterStatus=ptr_clutterStatus, BBPARMS=BBparms, ALT_BB_HGT=alt_bb_hgt )
 END
ENDCASE

IF (status EQ 1) THEN BEGIN
   status=0          ; set up to do another case rather than exiting
   GOTO, errorExit
ENDIF

; create local data field arrays/structures needed here, and free pointers we no longer need
; to free the memory held by these pointer variables
  mygeometa=*ptr_geometa
    ptr_free,ptr_geometa
;HELP, MYGEOMETA, /struct
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
  have_pia=0
  IF ptr_valid(ptr_pia) THEN BEGIN
     pia=*ptr_pia
     ptr_free,ptr_pia
     IF pr_or_dpr EQ 'DPR' THEN have_pia=myflags.have_piaFinal $
     ELSE have_pia=myflags.have_pia
  ENDIF ELSE pia = -1

  haveDm = 0
  IF ptr_valid(ptr_dprDm) THEN BEGIN
     dpr_dm=*ptr_dprDm
     dpr_dm_in=dpr_dm         ; 2nd copy, left untrimmed for PPI plots
     haveDm = 1
     ptr_free,ptr_dprDm
  ENDIF ELSE message, "No Dm field for DPR in netCDF file.", /INFO
  haveNw = 0
  IF ptr_valid(ptr_dprNw) THEN BEGIN
     dpr_nw=*ptr_dprNw/10.    ; dBNw -> log10(Nw)
     dpr_nw_in=dpr_nw         ; 2nd copy, left untrimmed for PPI plots
     haveNw = 1
     ptr_free,ptr_dprNw
  ENDIF ELSE message, "No Nw field for DPR in netCDF file.", /INFO

   ; initialize flag as to source of GR rain rate to use to "compute Z-R"
   have_gvrr = 0
   gvrr = -1
   pctgoodrrgv = -1
   rr_field_used = 'Z-R'

   IF pr_or_dpr EQ 'DPR' THEN BEGIN
      CASE gr_rr_field OF
         'RC' : IF ptr_valid(ptr_gvrc) THEN BEGIN
                  gvrr=*ptr_gvrc
                  gvrr_in = gvrr
                  ptr_free,ptr_gvrc
                  have_gvrr=myflags.have_GR_RC_rainrate
                  IF ptr_valid(ptr_pctgoodrcgv) THEN pctgoodrrgv=*ptr_pctgoodrcgv
                  rr_field_used = 'RC'
                ENDIF
         'RP' : IF ptr_valid(ptr_gvrp) THEN BEGIN
                  gvrr=*ptr_gvrp
                  gvrr_in = gvrr
                  ptr_free,ptr_gvrp
                  have_gvrr=myflags.have_GR_RP_rainrate
                  IF ptr_valid(ptr_pctgoodrpgv) THEN pctgoodrrgv=*ptr_pctgoodrpgv
                  rr_field_used = 'RP'
               ENDIF
         ELSE : IF ptr_valid(ptr_gvrr) THEN BEGIN
                  gvrr=*ptr_gvrr
                  gvrr_in = gvrr
                  ptr_free,ptr_gvrr
                  have_gvrr=myflags.have_GR_RR_rainrate
                  IF ptr_valid(ptr_pctgoodrrgv) THEN pctgoodrrgv=*ptr_pctgoodrrgv
                  rr_field_used = 'RR'
                ENDIF
      ENDCASE
   ENDIF ELSE BEGIN
     IF ptr_valid(ptr_gvrr) THEN BEGIN
        gvrr=*ptr_gvrr
        gvrr_in = gvrr ; for plotting as PPI
        ptr_free,ptr_gvrr
        have_gvrr=myflags.have_GR_rainrate   ; should just be 0 for version<2.2
        IF ptr_valid(ptr_pctgoodrrgv) THEN pctgoodrrgv=*ptr_pctgoodrrgv
        rr_field_used = 'RR'
     ENDIF
   ENDELSE

  haveHID = 0                          ; first check myflags values for all these?
  IF ptr_valid(ptr_BestHID) THEN BEGIN
     HIDcat=*ptr_BestHID
     haveHID = 1
     ptr_free,ptr_BestHID
  ENDIF

  haveD0 = 0
  ; use Dm/D0 field specified by gr_dm_field parameter, as available
  ; -- calling program has made sure gr_dm_field parameter is defined
  IF (*ptr_GR_DP_DM NE !NULL) THEN BEGIN
    GR_DP_Dm=*ptr_GR_DP_Dm
    GR_DP_Dm_in=*ptr_GR_DP_Dm  ; 2nd copy, left untrimmed for PPI plots
    haveDm = 1
    GR_DM_D0 = 'Dm'
  ENDIF
    ptr_free,ptr_GR_DP_Dm

    IF ptr_valid(ptr_GR_DP_Dzero) THEN BEGIN
       Dzero=*ptr_GR_DP_Dzero
       Dzero_in=*ptr_GR_DP_Dzero  ; 2nd copy, left untrimmed for PPI plots
       haveD0 = 1
       ptr_free,ptr_GR_DP_Dzero
       IF N_ELEMENTS( dzerofac ) EQ 1 THEN BEGIN
;          message,  'Adjusting GR Dzero field by factor of '+STRING(dzerofac, $
;                    FORMAT='(F0.0)'), /INFO
          GR_DM_D0 = 'Dm'
          idx2adj = WHERE(Dzero GT 0.0, count2adj)
          IF count2adj GT 0 THEN BEGIN
             adjdzero = Dzero[idx2adj] * dzerofac
             Dzero[idx2adj] = adjdzero
             Dzero_in[idx2adj] = adjdzero
          ENDIF
       ENDIF ELSE BEGIN
          message,  'Leaving GR Dzero field as-is.', /INFO
          GR_DM_D0 = 'D0'
       ENDELSE
    ENDIF ELSE message, "No Dzero field for GR in netCDF file.", /INFO

  haveGR_Nw = 0
  ; use NW/N2 field specified by gr_nw_field parameter, as available
  ; -- calling program has made sure gr_nw_field parameter is defined
  IF (*ptr_GR_DP_N2 NE !NULL) THEN BEGIN
    GR_DP_N2=*ptr_GR_DP_N2
    GR_DP_N2_in=*ptr_GR_DP_N2  ; 2nd copy, left untrimmed for PPI plots
    haveGR_N2 = 1
    GR_NW_N2 = 'N2'
  ENDIF
    ptr_free,ptr_GR_DP_N2

    IF ptr_valid(ptr_GR_DP_Nw) THEN BEGIN
       GR_DP_Nw=*ptr_GR_DP_Nw
       GR_DP_Nw_in=*ptr_GR_DP_Nw  ; 2nd copy, left untrimmed for PPI plots
       haveGR_Nw = 1
       GR_NW_N2 = 'NW'
       ptr_free,ptr_GR_DP_Nw
    ENDIF ELSE message, "No Nw field for GR in netCDF file.", /INFO

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
  pctgoodDprDm=*ptr_pctgoodDprDm
  pctgoodDprNw=*ptr_pctgoodDprNw
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
    ptr_free,ptr_pctgoodDprDm
    ptr_free,ptr_pctgoodDprNw
  IF pr_or_dpr EQ 'DPR' AND KEYWORD_SET(declutter) THEN BEGIN
     clutterStatus=*ptr_clutterStatus
     ptr_free,ptr_clutterStatus
  ENDIF ELSE clutterStatus=0      ; just assign anything so it is defined
;  IF ptr_valid(ptr_pctgoodrrgv) THEN BEGIN
;     pctgoodrrgv=*ptr_pctgoodrrgv
;     ptr_free,ptr_pctgoodrrgv
;  ENDIF

; now that the pointers are freed, make sure we have all our Dm and Nw fields

IF (haveDm+haveNw+haveD0+haveGR_Nw) NE 4 THEN $
   message, "Missing a mandatory Dm, D0, or Nw field, quitting."

; stuff the flags, structs, and data arrays into structures to pass along
; - at this point, they will all be copies of the originals and we can
;   butcher them as we please

haveIt = { have_gvrr : have_gvrr, $
           haveHID : haveHID, $
           haveDm : haveDm, $
           haveNw : haveNw, $
           haveD0 : haveD0, $
           haveGR_Nw : haveGR_Nw, $
           haveZdr : haveZdr, $
           haveKdp : haveKdp, $
           haveRHOhv : haveRHOhv, $
           have_pia : have_pia }

dataStruc = { haveFlags : haveIt, $
              mygeometa : mygeometa, $
              mysite : mysite, $
              mysweeps : mysweeps, $
              gvz : gvz, $
              zraw : zraw, $
              zcor : zcor, $
              rain3 : rain3, $
              dpr_dm : GR_DP_DM, $ ; dpr_Dm, $
              dpr_nw : GR_DP_N2, $ ; dpr_nw, $
              gvrr : gvrr, $
              rr_field_used : rr_field_used, $
              Dzero : Dzero, $
              GR_DM_D0 : GR_DM_D0, $
              GR_DP_Nw : GR_DP_Nw, $
              HIDcat : HIDcat, $
              Zdr : Zdr, $
              Kdp : Kdp, $
              RHOhv : RHOhv, $
              top : top, $
              botm : botm, $
              lat : lat, $
              lon : lon, $
              pia : pia, $
              rnflag : rnflag, $
              rntype : rntype, $
              pr_index : pr_index, $
              xcorner : xcorner, $
              ycorner : ycorner, $
              bbProx : bbProx, $
              dist : dist, $
              hgtcat : hgtcat, $
              pctgoodpr : pctgoodpr, $
              pctgoodgv : pctgoodgv, $
              pctgoodrain : pctgoodrain, $
              pctgoodrrgv : pctgoodrrgv, $
              pctgoodDprDm : pctgoodDprDm, $
              pctgoodDprNw : pctgoodDprNw, $
              clutterStatus : clutterStatus, $
              BBparms : BBparms, $
              heights : heights, $
              hgtinterval : hgtinterval, $
              is_subset : 0, $
              DATESTAMP : yymmdd, $
              orbit : orbit, $
              version : version, $
              KuKa : KuKa, $
              swath : swath }

; - - - - - - - - - - - - - - - - - - - - - - -

IF N_ELEMENTS(submeth) EQ 1 THEN BEGIN
   more_cowbell = 'M'
   WHILE STRTRIM(STRUPCASE(more_cowbell),2) EQ 'M' DO BEGIN
     ; bring up the PPI location selector and cut out the area of interest
      dataStrucCopy = dataStruc  ; don't know why original gets hosed below
      dataStrucTrimmed = select_geomatch_subarea( hide_rntype, pr_or_dpr, $
                                                  startelev, dataStrucCopy, $
                                                  SUBSET_METHOD=submeth, $
                                                  RR_OR_Z=xxx, $
                                                  RANGE_MAX=subthresh )

      IF size(dataStrucTrimmed, /TYPE) NE 8 THEN BEGIN
        ; set up to go to another case rather than to automatically quit, as
        ; user may just have right-clicked to skip storm selection
         status = 0
         message, "Unable to run statistics for storm area, skipping case.",/info
      ENDIF ELSE BEGIN
         status = render_dsd_plots(looprate, elevs2show, startelev, $
                                PPIorient, windowsize, pctabvthresh, PPIbyThresh, $
                                Z_PPIs, gvconvective, gvstratiform, hideTotals, $
                                hide_rntype, hidePPIs, pr_or_dpr, dataStrucTrimmed, $
                                PS_DIR=ps_dir, B_W=b_w, S2KU=s2ku, ZR=zr_force, $
                                ALT_BB_HGT=alt_bb_hgt, DZEROFAC=dzerofac, $
                                GR_RR_FIELD=gr_rr_field, BATCH=batch, $
                                MAX_RANGE=max_range, SUBSET_METHOD=submeth, $
                                MIN_FOR_SUBSET=subthresh, SAVE_DIR=save_dir, $
                                STEP_MANUAL=step_manual, DECLUTTER=declutter )
         wdelete, 1
         saveIt=0
         IF ( N_ELEMENTS(save_dir) EQ 1 ) THEN BEGIN
            doodah = ""
            PRINT, STRING(7B)  ; ring the terminal bell
            WHILE (doodah NE 'Y' AND doodah NE 'N') DO BEGIN
               READ, doodah, PROMPT='Save subset variables to file?  Enter Y or N : '
               doodah = STRTRIM(STRUPCASE(doodah),2)
               CASE doodah OF
                 'Y' : saveIt=1
                 'N' : saveIt=0
                ELSE : BEGIN
                         PRINT, STRING(7B)
                         PRINT, "Illegal response, enter Y or N."
                       END
               ENDCASE
            ENDWHILE
         ENDIF
         IF ( saveIt ) THEN BEGIN
           ; set up IDL SAVE file path/name
            IF ( s2ku ) THEN add2nm = '_S2Ku' ELSE add2nm = ''
            IF datastrucTrimmed.is_subset THEN BEGIN
              ; format the storm lat/lon position into a string to be added to the PS name
               IF datastrucTrimmed.storm_lat LT 0.0 THEN hemi='S' ELSE hemi='N'
               IF datastrucTrimmed.storm_lon LT 0.0 THEN ew='W' ELSE ew='E'
               addpos='_'+STRING(ABS(datastrucTrimmed.storm_lat),FORMAT='(f0.2)')+hemi+'_'+ $
                      STRING(ABS(datastrucTrimmed.storm_lon),FORMAT='(f0.2)')+ew
               add2nm = add2nm+addpos
            ENDIF
            SAVFILE = save_dir+'/'+site+'.'+yymmdd+'.'+orbit+"."+version+'.'+pr_or_dpr+'_' $
                        +instrument+'_'+swath+'.Pct'+pctString+add2nm+'_DSD_'+xxx+'.sav'
            SAVE, ncfilepr, xxx, looprate, elevs2show, startelev, PPIorient, windowsize, $
                  pctabvthresh, PPIbyThresh, Z_PPIs, gvconvective, gvstratiform, hideTotals, $
                  hide_rntype, hidePPIs, pr_or_dpr, datastrucTrimmed, FILE=SAVFILE
            print, "Data saved to ", SAVFILE
         ENDIF
      ENDELSE
      IF status EQ 0 THEN BEGIN
         PRINT, ''
         READ, more_cowbell, $
         PROMPT='Hit Return to advance to next case, or ' + $
                'M to do More storm subsets for this case: '
      ENDIF ELSE more_cowbell = 'q'
   ENDWHILE
ENDIF ELSE BEGIN
   ; call the routine to produce the graphics and output, just doing entire area
   status = render_dsd_plots( looprate, elevs2show, startelev, $
                              PPIorient, windowsize, pctabvthresh, PPIbyThresh, $
                              Z_PPIs, gvconvective, gvstratiform, hideTotals, $
                              hide_rntype, hidePPIs, pr_or_dpr, dataStruc, $
                              PS_DIR=ps_dir, B_W=b_w, S2KU=s2ku, ZR=zr_force, $
                              ALT_BB_HGT=alt_bb_hgt, DZEROFAC=dzerofac, $
                              GR_RR_FIELD=gr_rr_field, BATCH=batch, $
                              MAX_RANGE=max_range, SUBSET_METHOD=submeth, $
                              MIN_FOR_SUBSET=subthresh, SAVE_DIR=save_dir, $
                              STEP_MANUAL=step_manual, DECLUTTER=declutter )
ENDELSE

; - - - - - - - - - - - - - - - - - - - - - - -

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
; z_only_ppi    - Binary parameter, if set then only reflectivity PPIs are shown
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
; alt_bb_hgt    - Manually-specified Bright Band Height (km) to be used if the
;                 bright band height cannot be determined from the DPR data.
;
; hide_totals   - Binary parameter, controls whether to show (default) or hide
;                 the PDF and profile plots for rain type = "Any".
;
; hide_rntype   - (Optional) binary parameter, indicates whether to suppress
;                 hatching in the PPI plots indicating the PR rain type
;                 identified for the given ray.  Default=show hatching
;
; hide_ppis     - Binary parameter, controls whether to show (default) or hide
;                 the PPI plots/animations.
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
;                 Meneghini S-band to Ku-band adjustment to GR reflectivity.
;                 Default = no
;
; use_zr        - Binary parameter, controls whether or not to override the gvrr
;                 (GR rain rate) field in the geo-match netCDF file with a Z-R
;                 derived rain rate
;
; dzero_adj     - Bias adjustment to apply to the GR Dzero field to match it to
;                 the DPR Dm field.  Suggested value is 1.05
;
; gr_rr_field_in - UF field ID of the GR rain rate estimate source to be used:
;                  RC (Cifelli), RP (PolZR), or RR (DROPS, default)
;
;
; recall_ncpath - Binary parameter.  If set, assigns the last file path used to
;                 select a file in dialog_pickfile() to a user-defined system
;                 variable that stays in effect for the IDL session.  Also, if
;                 set and if the user variable exists from a previous selection,
;                 then the user variable will override the NCPATH parameter
;                 value on program startup.
;
; subset_method - Method to use to select subset areas from the matchup data:
;                 'D' = select an area within a cutoff distance (defined by the
;                       'min_for_subset' parameter) from a user-selected point.
;                 'V' = select an area of contiguous data values around the
;                       user-selected start location that are at/above the
;                       'min_for_subset' value.  The data value to be
;                       thresholded is defined by the 'rr_or_z' parameter,
;                       and the threshold applies to the highest data value
;                       in the vertical column along the PR/DPR ray (e.g., to
;                       the composite reflectivity).  If either the PR/DPR or
;                       the matching ground radar value exceeds the threshold,
;                       then the data for that ray will be included in the
;                       subset area.
;                  If subset_method is unspecified then the analysis will be
;                  performed over the entire domain of the matchup dataset.
;
; min_for_subset - Threshold value to be used to define points to be included
;                  in a user-selected subset area.  If subset_method is 'D',
;                  then min_for_subset is a distance in km.  If subset_method
;                  is 'V', then the parameter units are defined by the rr_or_z
;                  parameter value.  This parameter is ignored if no value is
;                  specified for subset_method.
;
; save_dir       - Optional directory specification to which the subsetted
;                  variables in a structure will be saved in an IDL SAVE file if
;                  the user chooses to save them.
;
; step_manual   - Flag and Rate value to toggle and control the alternative
;                 method of animation of PPI images.  If unset, animation is
;                 automated in an XINTERANIMATE window (default, legacy
;                 behavior).  If set to a non-zero value, then the PPI images
;                 will be stepped through under user control: either one at a
;                 time in forward or reverse, or in an automatic forward
;                 sequence where the pause, in seconds, between frames is
;                 defined by the step_manual value.  The automated sequence
;                 will only play one time in the latter mode, starting from
;                 the currently-displayed frame.
;
; declutter     - (Optional) binary parameter, if set to ON, then read and use
;                 the clutterStatus variable to filter out clutter-flagged
;                 volume match samples, regardless of pctAbvThresh status.

pro geo_match_3d_dsd_comparisons_gr2gr, INSTRUMENT=instrument, $
                                  SPEED=looprate, $
                                  ELEVS2SHOW=elevs2show, $
                                  NCPATH=ncpath, $
                                  SITE=sitefilter, $
                                  NO_PROMPT=no_prompt, $
                                  PPI_VERTICAL=ppi_vertical, $
                                  PPI_SIZE=ppi_size, $
                                  PCT_ABV_THRESH=pctAbvThresh, $
                                  MAX_RANGE=max_range_in, $
                                  SHOW_THRESH_PPI=show_thresh_ppi, $
                                  Z_ONLY_PPI=z_only_ppi, $
                                  GV_CONVECTIVE=gv_convective, $
                                  GV_STRATIFORM=gv_stratiform, $
                                  ALT_BB_HGT=alt_bb_hgt, $
                                  HIDE_TOTALS=hide_totals, $
                                  HIDE_RNTYPE=hide_rntype, $
                                  HIDE_PPIS=hide_ppis, $
                                  PS_DIR=ps_dir, $
                                  B_W=b_w, $
                                  BATCH=batch, $
                                  S2KU = s2ku, $
                                  USE_ZR = use_zr, $
                                  DZERO_ADJ = dzero_adj, $
                                  GR_RR_FIELD=gr_rr_field_in, $
                                  GR_DM_FIELD=gr_dm_field_in, $
                                  GR_NW_FIELD=gr_nw_field_in, $
                                  RECALL_NCPATH=recall_ncpath, $
                                  SUBSET_METHOD=subset_method, $
                                  MIN_FOR_SUBSET=min_for_subset, $
                                  SAVE_DIR=save_dir, $
                                  STEP_MANUAL=step_manual, $
                                  DECLUTTER=declutter


IF ( N_ELEMENTS(instrument) NE 1 ) THEN BEGIN
   print, "Defaulting to DPR for instrument type."
   pr_or_dpr = 'DPR'
ENDIF ELSE BEGIN
   CASE STRUPCASE(instrument) OF
      ;'PR' : pr_or_dpr = 'PR'
     'DPR' : pr_or_dpr = 'DPR'
      ELSE : BEGIN
                print, ""
                print, "NOTE: Only currently allowed value for INSTRUMENT is DPR."
                doodah = ""
                READ, doodah, $
                PROMPT='Do you wish to override INSTRUMENT=",pr_or_dpr," to DPR? (y/n): '
                IF STRUPCASE(doodah) EQ 'Y' THEN BEGIN
                   print, "Resetting to INSTRUMENT to DPR"
                   pr_or_dpr = 'DPR'
                ENDIF ELSE BEGIN
                   IF STRUPCASE(doodah) EQ 'N' THEN goto, earlyExit $
                   ELSE BEGIN
                      print, 'Invalid response, quitting.'
                      goto, earlyExit
                   ENDELSE
                ENDELSE
             END
   ENDCASE
ENDELSE

xxx = 'Z'   ; set default Z threshold for now

IF N_ELEMENTS( subset_method ) EQ 1 THEN BEGIN
   CASE STRUPCASE(subset_method) OF
       'D' : BEGIN
               submeth = 'D'
               IF N_ELEMENTS(min_for_subset) NE 1 THEN BEGIN
                  print, "Setting a default subset area radius of 20km"
                  subthresh = 20.
               ENDIF ELSE subthresh = min_for_subset
             END
       'V' : BEGIN
               submeth = 'V'
               IF N_ELEMENTS(min_for_subset) NE 1 THEN BEGIN
                  CASE xxx OF
                    'Z' : BEGIN
                          print, "Setting a default subset threshold of 30 dBZ"
                          subthresh = 30.
                          END
                   'RR' : BEGIN
                          print, "Setting a default subset threshold of 1 mm/h"
                          subthresh = 1.
                          END
                  ENDCASE
               ENDIF ELSE subthresh = min_for_subset
             END
        '' : BREAK   ; silently ignore empty string
      ELSE : message, "Only allowed values for SUBSET_METHOD are D "+ $
                      "(distance) and V (value)"
   ENDCASE
ENDIF

IF N_ELEMENTS(submeth) EQ 1 AND N_ELEMENTS(save_dir) EQ 1 THEN BEGIN
  ; check for existence of save_dir, if not empty string
   IF save_dir NE '' THEN BEGIN
      IF FILE_TEST(save_dir, /DIRECTORY) THEN real_save_dir = save_dir $
      ELSE MESSAGE, "SAVE_DIR directory "+save_dir+ $
                     " does not exist, disabling SAVE files.", /INFO
   ENDIF
ENDIF

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

IF ( N_ELEMENTS(sitefilter) NE 1 ) THEN BEGIN
   print, "Defaulting to * for file pattern."
   ncfilepatt = '*'
ENDIF ELSE ncfilepatt = '*'+sitefilter+'*'

PPIorient = keyword_set(ppi_vertical)
PPIbyThresh = keyword_set(show_thresh_ppi)
Z_PPIs = keyword_set(z_only_ppi)
;RR_PPI = keyword_set(ppi_is_rr)
hideTotals = keyword_set(hide_totals)
hideRntype = keyword_set(hide_rntype)
hidePPIs = keyword_set(hide_ppis)
b_w = keyword_set(b_w)
do_batch = keyword_set(batch)
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
   print, "Disabling GR Convective floor threshold."
   gvConvective = 0.0
ENDIF ELSE BEGIN
   gvConvective = FLOAT(gv_Convective)
ENDELSE

IF ( N_ELEMENTS(gv_Stratiform) NE 1 ) THEN BEGIN
   print, "Disabling GR Stratiform ceiling threshold."
   gvStratiform = 0.0
ENDIF ELSE BEGIN
   gvStratiform = FLOAT(gv_Stratiform)
ENDELSE

; set up the Dzero adjustment, if valid factor is provided
IF ( N_ELEMENTS(dzero_adj) EQ 1 ) THEN BEGIN
   IF dzero_adj GE 0.9 AND dzero_adj LE 1.1 THEN BEGIN
      dzerofac = dzero_adj
   ENDIF ELSE BEGIN
      print, ""
      print, "Out of range value for dzero_adj: ", dzero_adj
      print, "Must lie between 0.9 and 1.1, leaving GR Dzero unmodified."
      print, ""
   ENDELSE
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

IF zr_force EQ 0 THEN BEGIN
   IF N_ELEMENTS( gr_rr_field_in ) EQ 1 THEN BEGIN
      CASE gr_rr_field_in OF
         'RC' : gr_rr_field = gr_rr_field_in
         'RP' : gr_rr_field = gr_rr_field_in
         'RR' : gr_rr_field = gr_rr_field_in
         ELSE : BEGIN
                print, "Illegal value for GR_RR_FIELD: ", gr_rr_field_in, $
                       ", allowed values are RC, RP, and RR only."
                print, " - Setting GR_RR_FIELD value to RR (for DROPS)."
                gr_rr_field = 'RR'
                END
      ENDCASE
      IF pr_or_dpr EQ 'PR' AND gr_rr_field NE 'RR' THEN BEGIN
         print, gr_rr_field + " rain rate field not supported for " + pr_or_dpr
         print, " - Setting GR_RR_FIELD value to RR (for DROPS)."
         gr_rr_field = 'RR'
      ENDIF
   ENDIF ELSE BEGIN
      print, "No value supplied for GR_RR_FIELD, and not using Z-R rainrate."
      print, "Setting GR_RR_FIELD value to RR (for DROPS)."
      gr_rr_field = 'RR'
   ENDELSE
ENDIF

; check D0/Dm and Nw/N2 parameter configurations against instrument
; -- let child process deal with selection vs. matchup version

IF pr_or_dpr EQ 'DPR' THEN BEGIN
   IF N_ELEMENTS( gr_dm_field_in ) EQ 1 THEN BEGIN
      CASE STRUPCASE(gr_dm_field_in) OF
         'D0' : gr_dm_field = STRUPCASE(gr_dm_field_in)
         'DM' : gr_dm_field = STRUPCASE(gr_dm_field_in)
         ELSE : BEGIN
                print, "Illegal value for GR_DM_FIELD: ", gr_dm_field_in, $
                       ", allowed values are D0 and DM only."
                print, " - Setting GR_DM_FIELD value to DM."
                gr_dm_field = 'DM'
                END
      ENDCASE
   ENDIF ELSE BEGIN
      print, "No value supplied for GR_DM_FIELD, setting value to DM."
      gr_dm_field = 'DM'
   ENDELSE

   IF N_ELEMENTS( gr_nw_field_in ) EQ 1 THEN BEGIN
      CASE STRUPCASE(gr_nw_field_in) OF
         'NW' : gr_nw_field = STRUPCASE(gr_nw_field_in)
         'N2' : gr_nw_field = STRUPCASE(gr_nw_field_in)
         ELSE : BEGIN
                print, "Illegal value for GR_NW_FIELD: ", gr_nw_field_in, $
                       ", allowed values are NW and N2 only."
                print, " - Setting GR_NW_FIELD value to NW."
                gr_nw_field = 'NW'
                END
      ENDCASE
   ENDIF ELSE BEGIN
      print, "No value supplied for GR_NW_FIELD, setting value to NW."
      gr_nw_field = 'NW'
   ENDELSE
ENDIF ELSE BEGIN
   IF gr_dm_field NE 'D0' THEN BEGIN
      print, gr_dm_field + " D0/Dm field not supported for " + pr_or_dpr
      print, " - Setting GR_DM_FIELD value to D0."
   ENDIF
   gr_dm_field = 'D0'

   IF gr_nw_field NE 'NW' THEN BEGIN
      print, gr_nw_field + " Nw field not supported for " + pr_or_dpr
      print, " - Setting GR_NW_FIELD value to NW."
   ENDIF
   gr_nw_field = 'NW'
ENDELSE

; specify whether to skip graphical PPI output to screen in Postscript mode
IF ( PS_DIR NE '' AND KEYWORD_SET(batch) ) THEN do_batch=1 ELSE do_batch=0

; Figure out how the next file to process will be obtained.  If no_prompt is
; set, then we will automatically loop over the file sequence.  Otherwise we
; will prompt the user for the next file with dialog_pickfile() (DEFAULT).

no_prompt = keyword_set(no_prompt)
;help, s2ku

IF (no_prompt) THEN BEGIN

   prfiles = file_search(pathpr+'/'+ncfilepatt,COUNT=nf)

   if nf eq 0 then begin
      print, 'No netCDF files matching file pattern: ', pathpr+'/'+ncfilepatt
   endif else begin
      IF ( do_batch ) THEN BEGIN
         print, ''
         print, 'Processing all cases in Postscript batch mode.'
         print, ''
      ENDIF
      for fnum = 0, nf-1 do begin
         IF NOT ( do_batch ) THEN BEGIN
           ; set up for bailout prompt every 5 cases if no_prompt
            doodah = ""
            IF ( ((fnum+1) MOD 5) EQ 0 AND no_prompt ) THEN BEGIN $
                READ, doodah, $
                PROMPT='Hit Return to do next 5 cases, Q to Quit, D to Disable this bail-out option: '
                IF doodah EQ 'Q' OR doodah EQ 'q' THEN break
                IF doodah EQ 'D' OR doodah EQ 'd' THEN no_prompt=0   ; never ask again
            ENDIF
         ENDIF
        ;
         ncfilepr = prfiles(fnum)
         action = 0
         action = geo_match_dsd_plots( ncfilepr, xxx, looprate, elevs2show, startelev, $
                                       PPIorient, ppi_size, pctAbvThresh, PPIbyThresh, $
                                       Z_PPIs, gvconvective, gvstratiform, hideTotals, $
                                       hideRntype, hidePPIs, pr_or_dpr, ALT_BB_HGT=alt_bb_hgt, $
                                       PS_DIR=ps_dir, B_W=b_w, S2KU=s2ku, ZR=zr_force, $
                                       DZEROFAC=dzerofac, GR_RR_FIELD=gr_rr_field, $
                                       GR_DM_FIELD=gr_dm_field, GR_NW_FIELD=gr_nw_field, $
                                       BATCH=do_batch, MAX_RANGE=max_range_in, $
                                       SUBSET_METHOD=submeth, MIN_FOR_SUBSET=subthresh, $
                                       SAVE_DIR=real_save_dir, STEP_MANUAL=step_manual, $
                                       DECLUTTER=declutter )

         if (action EQ 2) then break
      endfor
   endelse
ENDIF ELSE BEGIN
   ncfilepr = dialog_pickfile(path=pathpr, filter = ncfilepatt)
   while ncfilepr ne '' do begin
      action = 0
      action=geo_match_dsd_plots( ncfilepr, xxx, looprate, elevs2show, startelev, $
                                  PPIorient, ppi_size, pctAbvThresh, PPIbyThresh, $
                                  Z_PPIs, gvconvective, gvstratiform, hideTotals, $
                                  hideRntype, hidePPIs, pr_or_dpr, ALT_BB_HGT=alt_bb_hgt, $
                                  PS_DIR=ps_dir, B_W=b_w, S2KU=s2ku, ZR=zr_force, $
                                  DZEROFAC=dzerofac, GR_RR_FIELD=gr_rr_field, $
                                  GR_DM_FIELD=gr_dm_field, GR_NW_FIELD=gr_nw_field, $
                                  BATCH=do_batch, MAX_RANGE=max_range_in, $
                                  SUBSET_METHOD=submeth, MIN_FOR_SUBSET=subthresh, $
                                  SAVE_DIR=real_save_dir, STEP_MANUAL=step_manual, $
                                  DECLUTTER=declutter )
      if (action EQ 2) then break
      newpathpr = FILE_DIRNAME(ncfilepr)  ; set the path to the last file's path
      IF KEYWORD_SET(recall_ncpath) THEN BEGIN
         ; define/assign new default path for session as user system variable
          IF (haveUserVar EQ 1) THEN !LAST_NCPATH = newpathpr $
          ELSE DEFSYSV, '!LAST_NCPATH', newpathpr
      ENDIF
      ncfilepr = dialog_pickfile(path=newpathpr, filter = ncfilepatt)
   endwhile
ENDELSE

earlyExit:
print, "" & print, "Done!"
END
