;===============================================================================
;+
; Copyright © 2014, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; geo_match_3d_rr_or_z_comparisons.pro
; - Morris/SAIC/GPM_GV  June 2014
;
; DESCRIPTION
; -----------
; Performs a case-by-case statistical analysis of geometry-matched (D)PR and GR
; reflectivity or rain rate from data contained in a geo-match netCDF file. 
; The MATCHUP_TYPE parameter controls which field is analyzed. Rain rate for GR
; is taken from the geo-match file if this field is flagged as available,
; otherwise it is derived from the volume-averaged GR reflectivity using a Z-R 
; relationship.  (D)PR rainrate is the volume-averaged rain rate stored in the
; netCDF file and previously derived from the 3-D rainrate in the 2A product.
;
; INTERNAL MODULES
; ----------------
; 1) geo_match_3d_rr_or_z_comparisons - Main procedure called by user.  Checks
;                                        input parameters and sets defaults.
;
; 2) geo_match_xxx_plots - Workhorse procedure to read data, compute statistics,
;                          create vertical profiles, histogram, scatter plots, 
;                          and tabulations of (D)PR-GR rainrate or reflectivity
;                          differences, and display (D)PR and GR reflectivity and
;                          rainrate and GR dual-pol field PPI plots in an
;                          animation sequence.
;
;
; NON-SYSTEM ROUTINES CALLED
; --------------------------
; 1) fprep_geo_match_profiles() or fprep_dpr_geo_match_profiles()
; 2) select_geomatch_subarea()
; 3) render_rr_or_z_plots()
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
;
; 06/23/14 Morris, GPM GV, SAIC
; - Created from geo_match_z_comparisons_dpr.pro.  Added capability to specify
;   a mean bright band height to be used if one cannot be extracted from the
;   DPR bright band field in the matchup files.
; 12/02/14 Morris, GPM GV, SAIC
; - Restored definition of bs and maxz4hist variables needed for histogram
;   consistency when analyzing Z field.
; 01/20/15, Morris/GPM GV (SAIC)
; - Added capability to color-code scatter points by height of samples in
;   Postscript/PDF output.
; - Changed text in titles to eliminate the DPR.DPR strings in the annotations.
; 01/23/15, Morris/GPM GV (SAIC)
; - Realigned DPR-GR text in table titles.
; - Fixed label myflags.have_GR_rainrate for current PR structure definition.
; - Added GR_RR_FIELD parameter to select which GR rain rate estimate to use for
;   DPR matchups: RC (Cifelli), RP (PolZR), or RR (DROPS).  Default=RR (DROPS).
; 01/28/15  Morris/GPM GV/SAIC
; - Added BATCH keyword option to run through all the cases defined by SITE and
;   NCPATH when PS_DIR and NO_PROMPT are also specified, to produce the
;   Postscript/PDF output without outputting any graphics or animations and
;   without requiring user interaction to continue from case to case.
; - Added MAX_RANGE parameter to control maximum allowable range of data samples
;   to include in the analysis.
; 03/13/15  Morris/GPM GV/SAIC
; - Added logic to reset path in dialog_pickfile to the last selected filepath
;   now that we have a complicated directory structure for matchup files.
; - Added RECALL_NCPATH keyword and logic to define a user-defined system
;   variable to remember and use the last-selected file path to override the
;   NCPATH and/or the default netCDF file path on startup of the procedure, if
;   the RECALL_NCPATH keyword is set and user system variable is defined in the
;   IDL session.
; 04/09/15  Morris/GPM GV/SAIC
; - MAJOR REWRITE FOR INTERACTIVE SELECTION OF ANALYSIS SUB-AREAS.
; - Extracted internal function plot_sweep_2_zbuf_4xsec from this file into a
;   stand alone function module common_utils/plot_sweep_2_zbuf_4xsec.pro.
; - Extracted major blocks of code and the internal function print_table_headers
;   that do the statistics, plots, and PDF file output into a new stand alone
;   function module display/render_rr_or_z_plots.pro.
; - Calls new function select_geomatch_subarea() to clip the data arrays to be
;   analyzed to the area around a user selected point.
; 04/28/15  Morris/GPM GV/SAIC
; - Fixed oversights in reading and processing RC and RP fields from DPR files.
; - Added structure element rr_field_used to indicate which GR rain rate field
;   is being processed.
; - Added tests for existence of SAVE_DIR directory before passing it along from
;   main routine to geo_match_xxx_plots.
; - Handle empty string for SUBSET_METHOD keyword parameter.
; 05/06/15  Morris/GPM GV/SAIC
; - Added HIDE_PPIS keyword parameter to suppress PPI plotting to screen.
; 05/12/15  Morris/GPM GV/SAIC
; - Made changes to logic and status value checks to support multiple storm
;   subset selections for a single case and to not quit unless user explicitly
;   selects that option.
; 06/24/15  Morris/GPM GV/SAIC
; - Added capability to process GRtoDPRGMI matchup data.
; - Added tag/value pairs for DATESTAMP, orbit, version, KuKa, and swath to the
;   passed data structure.
; - Changed INSTRUMENT/instrument KEYWORD/variable to MATCHUP_TYPE/matchup_type.
; 07/16/15 Morris, GPM GV, SAIC
; - Added DECLUTTER keyword option to filter out samples identified as ground
;   clutter affected.
; 12/9/2015 Morris, GPM GV, SAIC
; - Added FORCEBB parameter to override the DPR mean BB height with the value
;   provided by ALT_BB_HEIGHT.
; - Added MAX_BLOCKAGE optional parameter to limit samples included in the
;   statistics by maximum allowed GR beam blockage.
; - Added GR_blockage and have_GR_blockage tag/value pairs to passed structures.
; - Added Z_BLOCKAGE_THRESH optional parameter to limit samples included in the
;   comparisons by beam blockage, as implied by a Z dropoff between the second
;   and first sweeps. Is ignored in the presence of valid MAX_BLOCKAGE value and
;   presence of GR_blockage data.
; 01/07/2016 Morris, GPM GV, SAIC
; - Added logic to check for situation of no MS swath data present in Combined
;   (DPRGMI) matchup dataset and bail out if true.
; 05/18/16 Morris, GPM GV, SAIC
; - Reading the individual have_xxx flags in myflags structure to determine
;   whether a data field is populated with real data, rather than relying on
;   the validity of pointers from fprep_dpr_geo_match_profiles, which returns a
;   valid pointer to a fill-value data array even when there are no valid data.
; 06/02/16 Morris, GPM GV, SAIC
; - Overriding s2ku ON value if no valid meanBB height was found or supplied.
; 11/22/16 Morris, GPM GV, SAIC
; - Added DPR_Z_ADJUST=dpr_z_adjust and GR_Z_ADJUST=gr_z_adjust keyword/value
;   pairs to support DPR and site-specific GR bias adjustments.
; 12/1/16 Morris, GPM GV, SAIC
; - Added SAVE_BY_RAY option to save variables of interest to the 2BDPRGMI
;   developers for a single ray when saving variables at a user-selected point.
; - Added DPR Dm and Nw and GR Nw (N2) variables to those read from the netCDF
;   matchup files and included in the dataStruc structure passed to the
;   select_geomatch_subarea() function by geo_match_xxx_plots().
; 01/13/17 Morris, GPM GV, SAIC
; - Disabled execution of this procedure and added message to the effect that it
;   has been superseded by geo_match_3d_comparisons.pro.
;
;
; EMAIL QUESTIONS OR COMMENTS AT:
;       https://pmm.nasa.gov/contact
;-
;===============================================================================
;
; MODULE 2:  geo_match_xxx_plots
;
; DESCRIPTION
; -----------
; Reads PR and GR rainrate, Z, and spatial fields from a user-selected geo_match
; netCDF file, builds index arrays of categories of range, rain type, bright
; band proximity (above, below, within), and an array of actual range. Depending
; on the value of XXX, computes either mean PR-GR rainrate or Z differences for
; each of the 3 bright band proximity levels for points within 100 km of the
; ground radar and reports the results in a table to stdout.  Also produces
; graphs of the Probability Density Function of PR and GR rainrate or Z at each
; of these 3 levels if data exists at that level, and vertical profiles of
; mean PR and GR rainrate or Z, for each of 3 rain type categories: Any,
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
; in color.  If BATCH is also set with PS_DIR then the output file will be
; created without any graphics or user prompts and the program will proceed to
; the next case, as specified by the input parameters.
;
; If s2ku binary parameter is set, then the Liao/Meneghini S-to-Ku band
; reflectivity adjustment will be made to the GR reflectivity used to compute
; the GR rainrate if the mean BB height is available.
;
; If gr_rr_field is set, then the GR rainrate field whose ID matches this value
; will be used if available.  Otherwise the 'RR' field (DROPS estimate) will be
; used by default if available, and if not, then a Z-R rainrate estimate will be
; computed and used. In all cases, if zr_force is set then a Z-R rainrate
; estimate will be computed and used, regardless of the value of gr_rr_field.

FUNCTION geo_match_xxx_plots, ncfilepr, xxx, looprate, elevs2show, startelev, $
                              PPIorient, windowsize, pctabvthresh, PPIbyThresh, $
                              gvconvective, gvstratiform, hideTotals, $
                              hide_rntype, hidePPIs, pr_or_dpr, PS_DIR=ps_dir, $
                              B_W=b_w, S2KU=s2ku_in, ZR=zr_force, BATCH=batch, $
                              ALT_BB_HGT=alt_bb_hgt, GR_RR_FIELD=gr_rr_field, $
                              MAX_RANGE=max_range, MAX_BLOCKAGE=max_blockage, $
                              Z_BLOCKAGE_THRESH=z_blockage_thresh, $
                              DPR_Z_ADJUST=dpr_z_adjust, SITEBIASHASH=siteBiasHash, $
                              SUBSET_METHOD=submeth, MIN_FOR_SUBSET=subthresh, $
                              SAVE_DIR=save_dir, SAVE_BY_RAY=save_by_ray_in, $
                              STEP_MANUAL=step_manual, SWATH=swath_in, KUKA=KuKa_in, $
                              DECLUTTER=declutter_in, FORCEBB=forcebb_in

; "include" file for read_geo_match_netcdf() structs returned
@geo_match_nc_structs.inc

; "include" file for PR data constants
@pr_params.inc

declutter=KEYWORD_SET(declutter_in)
IF (pr_or_dpr NE 'DPR') THEN declutter=0     ; override unless processing DPR
forcebb=KEYWORD_SET(forcebb_in)
s2ku = keyword_set(s2ku_in)
IF N_ELEMENTS( siteBiasHash ) GT 0 THEN adjust_grz = 1 ELSE adjust_grz = 0
IF N_ELEMENTS( dpr_z_adjust ) EQ 1 THEN adjust_dprz = 1 ELSE adjust_dprz = 0
save_by_ray = 0  ; only override this if analyzing DPRGMI and SAVE_BY_RAY is set

bname = file_basename( ncfilepr )
pctString = STRTRIM(STRING(FIX(pctabvthresh)),2)
parsed = STRSPLIT( bname, '.', /extract )
site = parsed[1]
yymmdd = parsed[2]
orbit = parsed[3]
version = parsed[4]
CASE pr_or_dpr OF
     'DPR' : BEGIN
               swath=parsed[6]
               KuKa=parsed[5]
               instrument='_2A'+KuKa    ; label used in SAVE file names
             END
      'PR' : BEGIN
               swath='NS'
               instrument='_'
               KuKa='Ku'
              ; leave this here for now, expect PR V08x version labels soon, though
               CASE version OF
                    '6' : version = 'V6'
                    '7' : version = 'V7'
                   ELSE : print, "Using PR version = ", version
               ENDCASE
             END
  'DPRGMI' : BEGIN
               swath=swath_in
               KuKa=KuKa_in
               instrument='_'+KuKa
               save_by_ray = KEYWORD_SET(save_by_ray_in)
             END
ENDCASE

; set up pointers for each field to be returned from fprep_geo_match_profiles()
ptr_geometa=ptr_new(/allocate_heap)
ptr_sweepmeta=ptr_new(/allocate_heap)
ptr_sitemeta=ptr_new(/allocate_heap)
ptr_fieldflags=ptr_new(/allocate_heap)
ptr_gvz=ptr_new(/allocate_heap)

; define pointer for GR rain rate only if not using Z-R rainrate
IF KEYWORD_SET(zr_force) EQ 0 THEN BEGIN
   IF pr_or_dpr NE 'PR' THEN BEGIN
      ; only define the pointers specific to the rain rate field to be used
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
      ptr_gvrr=ptr_new(/allocate_heap)          ; new for Version 2.2 PR matchup
      ptr_pctgoodrrgv=ptr_new(/allocate_heap)
   ENDELSE
ENDIF

ptr_BestHID=ptr_new(/allocate_heap)       ; new for Version 2.3 matchup file
ptr_GR_DP_Dzero=ptr_new(/allocate_heap)   ; new for Version 2.3 matchup file
ptr_GR_DP_Nw=ptr_new(/allocate_heap)      ; new for Version 2.3 matchup file
ptr_GR_DP_Zdr=ptr_new(/allocate_heap)     ; new for Version 2.3 matchup file
ptr_GR_DP_Kdp=ptr_new(/allocate_heap)     ; new for Version 2.3 matchup file
ptr_GR_DP_RHOhv=ptr_new(/allocate_heap)   ; new for Version 2.3 matchup file
ptr_zcor=ptr_new(/allocate_heap)
ptr_rain3=ptr_new(/allocate_heap)
ptr_pia=ptr_new(/allocate_heap)
IF pr_or_dpr NE 'DPRGMI' THEN BEGIN
   ptr_zraw=ptr_new(/allocate_heap)
;   ptr_rain3=ptr_new(/allocate_heap)
;   ptr_pctgoodrain=ptr_new(/allocate_heap)
   ptr_nearSurfRain_Comb=ptr_new(/allocate_heap)
   ptr_rnFlag=ptr_new(/allocate_heap)
;   ptr_pia=ptr_new(/allocate_heap)
ENDIF
IF ( pr_or_dpr NE 'PR' ) THEN BEGIN
  ; only DPR or DPRGMI matchups provide Dm and Nw for satellite radar
   ptr_dprdm=ptr_new(/allocate_heap)
   ptr_dprnw=ptr_new(/allocate_heap)
  ; define the pointers for, and try to read, the 2nd GR Dm and Nw fields
  ; and GR blockage fraction
   ptr_GR_DP_Dm=ptr_new(/allocate_heap)      ; new for Version 1.2 GRtoDPR matchup file
   ptr_GR_DP_N2=ptr_new(/allocate_heap)      ; ditto
   ptr_GR_blockage=ptr_new(/allocate_heap)
ENDIF

ptr_top=ptr_new(/allocate_heap)
ptr_botm=ptr_new(/allocate_heap)
ptr_lat=ptr_new(/allocate_heap)
ptr_lon=ptr_new(/allocate_heap)
ptr_nearSurfRain=ptr_new(/allocate_heap)
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
heights = [1.5,3.0,4.5,6.0,7.5,9.0,10.5,12.0,13.5,15.0,16.5,18.0,19.5]
hgtinterval = 1.5
heights = [1.0,2.0,3.0,4.0,5.0,6.0,7.0,8.0,9.0,10.0,11.0,12.0,13.0,14.0,15.0,16.0,17.0,18.0]
hgtinterval = 1.0
print, 'pctAbvThresh = ', pctAbvThresh

; read the geometry-match variables and arrays from the file, and preprocess them
; to remove the 'bogus' PR ray positions.  Return a pointer to each variable read.

CASE pr_or_dpr OF
  'PR' : BEGIN
    PRINT, "READING MATCHUP FILE TYPE: ", pr_or_dpr
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
    PRINT, "READING MATCHUP FILE TYPE: ", pr_or_dpr
    status = fprep_dpr_geo_match_profiles( ncfilepr, heights, $
    PCT_ABV_THRESH=pctAbvThresh, S2KU=s2ku, PTRfieldflags=ptr_fieldflags, $
    PTRgeometa=ptr_geometa, PTRsweepmeta=ptr_sweepmeta, PTRsitemeta=ptr_sitemeta, $
    PTRGVZMEAN=ptr_gvz, PTRzcor=ptr_zcor, PTRzraw=ptr_zraw, PTRrain3d=ptr_rain3, $
    PTRdprdm=ptr_dprDm, PTRdprnw=ptr_dprNw, PTRGVNWMEAN=ptr_GR_DP_Nw, $
    PTRGVRCMEAN=ptr_gvrc, PTRGVRPMEAN=ptr_gvrp, PTRGVRRMEAN=ptr_gvrr, $
    PTRGVMODEHID=ptr_BestHID, PTRGVDZEROMEAN=ptr_GR_DP_Dzero, $
    PTRGVDMMEAN=ptr_GR_DP_Dm, PTRGVN2MEAN=ptr_GR_DP_N2, $
    PTRGVZDRMEAN=ptr_GR_DP_Zdr, PTRGVKDPMEAN=ptr_GR_DP_Kdp, PTRGVRHOHVMEAN=ptr_GR_DP_RHOhv, $
    PTRGVBLOCKAGE=ptr_GR_blockage, $
    PTRtop=ptr_top, PTRbotm=ptr_botm, PTRlat=ptr_lat, PTRlon=ptr_lon, PTRpia=ptr_pia, $
    PTRsfcrainpr=ptr_nearSurfRain, PTRsfcraincomb=ptr_nearSurfRain_Comb, $
    PTRrainflag_int=ptr_rnFlag, PTRraintype_int=ptr_rnType, $
    PTRxCorners=ptr_xCorner, PTRyCorners=ptr_yCorner, PTRbbProx=ptr_bbProx, $
    PTRhgtcat=ptr_hgtcat, PTRdist=ptr_dist, PTRpridx_long=ptr_pr_index, $
    PTRpctgoodpr=ptr_pctgoodpr, PTRpctgoodgv=ptr_pctgoodgv, $
    PTRpctgoodrain=ptr_pctgoodrain, PTRpctgoodrcgv=ptr_pctgoodrcgv, $
    PTRpctgoodrpgv=ptr_pctgoodrpgv, PTRpctgoodrrgv=ptr_pctgoodrrgv, $
    PTRpctgoodDprDm=ptr_pctgoodDprDm, PTRpctgoodDprNw=ptr_pctgoodDprNw, $
    PTRclutterStatus=ptr_clutterStatus, BBPARMS=BBparms, $
    ALT_BB_HGT=alt_bb_hgt, FORCEBB=forcebb )
   END
  'DPRGMI' : BEGIN
    PRINT, "READING MATCHUP FILE TYPE: ", pr_or_dpr
    status = fprep_dprgmi_geo_match_profiles( ncfilepr, heights, $
    KUKA=KuKa, SCANTYPE=swath, PCT_ABV_THRESH=pctAbvThresh, S2KU=s2ku, $
    PTRfieldflags=ptr_fieldflags, PTRgeometa=ptr_geometa, $
    PTRsweepmeta=ptr_sweepmeta, PTRsitemeta=ptr_sitemeta, $
    PTRGVZMEAN=ptr_gvz, PTRzcor=ptr_zcor, PTRrain3d=ptr_rain3, $
    PTRdprdm=ptr_dprDm, PTRdprnw=ptr_dprNw, PTRGVNWMEAN=ptr_GR_DP_Nw, $
    PTRGVRCMEAN=ptr_gvrc, PTRGVRPMEAN=ptr_gvrp, PTRGVRRMEAN=ptr_gvrr, $
    PTRGVMODEHID=ptr_BestHID, PTRGVDZEROMEAN=ptr_GR_DP_Dzero, $
    PTRGVDMMEAN=ptr_GR_DP_Dm, PTRGVN2MEAN=ptr_GR_DP_N2, $
    PTRGVZDRMEAN=ptr_GR_DP_Zdr, PTRGVKDPMEAN=ptr_GR_DP_Kdp, PTRGVRHOHVMEAN=ptr_GR_DP_RHOhv, $
    PTRGVBLOCKAGE=ptr_GR_blockage, $
    PTRtop=ptr_top, PTRbotm=ptr_botm, PTRlat=ptr_lat, PTRlon=ptr_lon, PTRpia=ptr_pia, $
    PTRsfcrainpr=ptr_nearSurfRain, PTRraintype_int=ptr_rnType, $
    PTRxCorners=ptr_xCorner, PTRyCorners=ptr_yCorner, PTRbbProx=ptr_bbProx, $
    PTRhgtcat=ptr_hgtcat, PTRdist=ptr_dist, PTRpridx_long=ptr_pr_index, $
    PTRpctgoodpr=ptr_pctgoodpr, PTRpctgoodgv=ptr_pctgoodgv, $
    PTRpctgoodrain=ptr_pctgoodrain, PTRpctgoodrcgv=ptr_pctgoodrcgv, $
    PTRpctgoodrpgv=ptr_pctgoodrpgv, PTRpctgoodrrgv=ptr_pctgoodrrgv, $
    PTRpctgoodDprDm=ptr_pctgoodDprDm, PTRpctgoodDprNw=ptr_pctgoodDprNw, $
    BBPARMS=BBparms, ALT_BB_HGT=alt_bb_hgt )
   END
ENDCASE

IF (status EQ 1) THEN BEGIN
  ; figure out if we had big problems or just didn't find a valid meanBB height.
  ; -- if *ptr_fieldflags points to NULL, then we had big problems
   IF (N_ELEMENTS(*ptr_fieldflags) NE 0) THEN BEGIN
     ; if Combined/MS and no swath data are present, bail out
      IF pr_or_dpr EQ 'DPRGMI' AND swath EQ 'MS' AND $
         (*ptr_geometa).have_swath_MS EQ 0 THEN GOTO, errorExit
     ; if not MS/Combined move along if doing Z
      status=0
      IF xxx NE 'Z' THEN GOTO, errorExit  ; skip stats for RR or DSD if no BB
   ENDIF ELSE GOTO, errorExit             ; bail out if other file/data errors
ENDIF

; create local data field arrays/structures needed here, and free pointers we
; no longer need to free the memory held by these pointer variables
; - Yes, we blindly assume most of these pointers and their data are defined
;   and valid, unless there is logic to test them (variables added in later
;   matchup file versions).

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
    ptr_free,ptr_gvz
  zcor=*ptr_zcor
    ptr_free,ptr_zcor
  rain3=*ptr_rain3
    ptr_free,ptr_rain3
  IF pr_or_dpr NE 'DPRGMI' THEN BEGIN
     zraw=*ptr_zraw
       ptr_free,ptr_zraw
;     rain3=*ptr_rain3
;       ptr_free,ptr_rain3
     rnflag=*ptr_rnFlag
       ptr_free,ptr_rnFlag
;     pctgoodrain=*ptr_pctgoodrain
;       ptr_free,ptr_pctgoodrain
       ptr_free,ptr_nearSurfRain_Comb
  ENDIF ELSE BEGIN
     zraw=-1.
;     rain3=*ptr_nearSurfRain
     rnflag=-1
;     pctgoodrain=-1.
  ENDELSE
  have_pia=0
  IF ptr_valid(ptr_pia) THEN BEGIN
     pia=*ptr_pia
     ptr_free,ptr_pia
     IF pr_or_dpr EQ 'DPR' THEN have_pia=myflags.have_piaFinal $
     ELSE have_pia=myflags.have_pia
  ENDIF ELSE pia = -1

  dpr_dm = -1 & dpr_dm_in=dpr_dm   ; define them as something so they exist
  haveDm = 0
  IF ptr_valid(ptr_dprDm) THEN BEGIN
     dpr_dm=*ptr_dprDm
     dpr_dm_in=dpr_dm         ; 2nd copy, left untrimmed for PPI plots
     haveDm = 1
     ptr_free,ptr_dprDm
  ENDIF ELSE message, "No Dm field for DPR in netCDF file.", /INFO

  dpr_nw = -1 & dpr_nw_in=dpr_nw   ; define them as something so they exist
  haveNw = 0
  IF ptr_valid(ptr_dprNw) THEN BEGIN
     IF pr_or_dpr NE 'DPRGMI' THEN BEGIN
       ; Convert DPR Nw from dBNw to log10(Nw).
        dpr_nw=*ptr_dprNw/10.    ; dBNw -> log10(Nw)
     ENDIF ELSE BEGIN
       ; DPRGMI Nw was already converted in fprep_dprgmi_geo_match_profiles()
       ; to GR Nw units of log10(Nw), with Nw in 1/m^3-mm, so use as-is
        dpr_nw=*ptr_dprNw
     ENDELSE
     dpr_nw_in=dpr_nw         ; 2nd copy, left untrimmed for PPI plots
     haveNw = 1
     ptr_free,ptr_dprNw
  ENDIF ELSE message, "No Nw field for DPR in netCDF file.", /INFO

 ; override any s2ku 'ON' value if no valid meanBB height was found
  IF bbparms.meanBB LE 0.0 THEN s2ku = 0

;-------------------------------------------------------------

  ; Optional bias/offset adjustment of GR Z and DPR Z:
   IF adjust_grz THEN BEGIN
      IF siteBiasHash.HasKey( site ) THEN BEGIN
        ; adjust GR Z values based on supplied bias file
         grbias = siteBiasHash[ site ]
         absbias = ABS( grbias )
         IF absbias GE 0.1 THEN BEGIN
            IF grbias LT 0.0 THEN BEGIN
              ; downward-adjust Zc values above ABS(grbias) separately from
              ; those below to avoid setting positive values to below 0.0
               idx_z2adj=WHERE(gvz GT absbias, count2adj)
               IF count2adj GT 0 THEN gvz[idx_z2adj] = gvz[idx_z2adj]+grbias
               idx_z2adj=WHERE(gvz GT 0.0 AND gvz LE absbias, count2adj)
               IF count2adj GT 0 THEN gvz[idx_z2adj] = 0.0
            ENDIF ELSE BEGIN
              ; upward-adjust GR Z values that are above 0.0 dBZ only
               idx_z2adj=WHERE(gvz GT 0.0, count2adj)
               IF count2adj GT 0 THEN gvz[idx_z2adj] = gvz[idx_z2adj]+grbias
            ENDELSE
         ENDIF ELSE print, "Ignoring negligible GR site Z bias value for "+site
      ENDIF ELSE print, "Site bias value not found for "+site+", leaving GR Z unchanged."
   ENDIF

   IF adjust_dprz THEN BEGIN
      absbias = ABS( dpr_z_adjust )
      IF absbias GE 0.1 THEN BEGIN
         IF dpr_z_adjust LT 0.0 THEN BEGIN
           ; downward-adjust Zc values above ABS(grbias) separately from
           ; those below to avoid setting positive values to below 0.0
            idx_z2adj=WHERE(zcor GT absbias, count2adj)
            IF count2adj GT 0 THEN zcor[idx_z2adj] = zcor[idx_z2adj]+dpr_z_adjust
            idx_z2adj=WHERE(zcor GT 0.0 AND zcor LE absbias, count2adj)
            IF count2adj GT 0 THEN zcor[idx_z2adj] = 0.0
            IF pr_or_dpr NE 'DPRGMI' THEN BEGIN
              ; also adjust Zmeas field
               idx_z2adj=WHERE(zraw GT absbias, count2adj)
               IF count2adj GT 0 THEN zraw[idx_z2adj] = zraw[idx_z2adj]+dpr_z_adjust
               idx_z2adj=WHERE(zraw GT 0.0 AND zraw LE absbias, count2adj)
               IF count2adj GT 0 THEN zraw[idx_z2adj] = 0.0
            ENDIF
         ENDIF ELSE BEGIN
           ; upward-adjust Zc values that are above 0.0 dBZ only
            idx_z2adj=WHERE(zcor GT 0.0, count2adj)
            IF count2adj GT 0 THEN zcor[idx_z2adj] = zcor[idx_z2adj]+dpr_z_adjust
            IF pr_or_dpr NE 'DPRGMI' THEN BEGIN
              ; also adjust Zmeas field
               idx_z2adj=WHERE(zraw GT 0.0, count2adj)
               IF count2adj GT 0 THEN zraw[idx_z2adj] = zraw[idx_z2adj]+dpr_z_adjust
            ENDIF
         ENDELSE
      ENDIF ELSE print, "Ignoring negligible DPR Z bias value."
   ENDIF

;-------------------------------------------------------------

 ; initialize flag as to source of GR rain rate to use to "compute Z-R"
  have_gvrr = 0
  gvrr = -1
  pctgoodrrgv = -1
  rr_field_used = 'Z-R'

  IF pr_or_dpr NE 'PR' THEN BEGIN
     CASE gr_rr_field OF
        'RC' : IF ptr_valid(ptr_gvrc) THEN BEGIN
                 gvrr=*ptr_gvrc
                 ptr_free,ptr_gvrc
                 have_gvrr=myflags.have_GR_RC_rainrate
                 IF ptr_valid(ptr_pctgoodrcgv) THEN  BEGIN
                    pctgoodrrgv=*ptr_pctgoodrcgv
                    ptr_free,ptr_pctgoodrcgv
                 ENDIF
                 rr_field_used = 'RC'
               ENDIF
        'RP' : IF ptr_valid(ptr_gvrp) THEN BEGIN
                 gvrr=*ptr_gvrp
                 ptr_free,ptr_gvrp
                 have_gvrr=myflags.have_GR_RP_rainrate
                 IF ptr_valid(ptr_pctgoodrpgv) THEN  BEGIN
                    pctgoodrrgv=*ptr_pctgoodrpgv
                    ptr_free,ptr_pctgoodrpgv
                 ENDIF
                 rr_field_used = 'RP'
               ENDIF
        ELSE : IF ptr_valid(ptr_gvrr) THEN BEGIN
                 gvrr=*ptr_gvrr
                 ptr_free,ptr_gvrr
                 have_gvrr=myflags.have_GR_RR_rainrate
                 IF ptr_valid(ptr_pctgoodrrgv) THEN BEGIN
                    pctgoodrrgv=*ptr_pctgoodrrgv
                    ptr_free,ptr_pctgoodrrgv
                 ENDIF
                 rr_field_used = 'RR'
               ENDIF
     ENDCASE
  ENDIF ELSE BEGIN
     IF ptr_valid(ptr_gvrr) THEN BEGIN
        gvrr=*ptr_gvrr
        ptr_free,ptr_gvrr
        have_gvrr=myflags.have_GR_rainrate   ; should just be 0 for version<2.2
        IF ptr_valid(ptr_pctgoodrrgv) THEN BEGIN
           pctgoodrrgv=*ptr_pctgoodrrgv
           ptr_free,ptr_pctgoodrrgv
        ENDIF
        rr_field_used = 'RR'
     ENDIF
  ENDELSE

 ; first check myflags values for all these -- the fprep routine returns valid
 ; data arrays even if the data is not present.  Gotta fix that?

  haveHID = 0
  IF ptr_valid(ptr_BestHID) THEN BEGIN
     HIDcat=*ptr_BestHID
     haveHID = myflags.HAVE_GR_HID
     ptr_free,ptr_BestHID
  ENDIF ELSE HIDcat=-1

;  haveD0 = 0
;  IF ptr_valid(ptr_GR_DP_Dzero) THEN BEGIN
;     Dzero=*ptr_GR_DP_Dzero
;     haveD0 = myflags.HAVE_GR_DZERO
;     ptr_free,ptr_GR_DP_Dzero
;  ENDIF ELSE Dzero=-1
  haveD0 = 0
  Dzero = -1 & Dzero_in = -1    ; define something
  gr_dm_field = 'DM'   ; set up to try to get Dm by default
  GR_DM_D0 = 'N/A'
  ; use Dm/D0 field specified by gr_dm_field parameter
  ; -- if GR DM field is not available, then ptr_GR_DP_DM will be invalid
  IF (gr_dm_field EQ 'DM') AND ptr_valid(ptr_GR_DP_DM) THEN BEGIN
    Dzero=*ptr_GR_DP_Dm     ; assign to Dzero variable, even if it's Dm
    Dzero_in=*ptr_GR_DP_Dm  ; 2nd copy, left untrimmed for PPI plots
    haveD0 = 1
    GR_DM_D0 = 'Dm'
    ptr_free,ptr_GR_DP_Dm
    IF ptr_valid(ptr_GR_DP_Dzero) THEN ptr_free,ptr_GR_DP_Dzero  ; not using field
  ENDIF ELSE BEGIN
    IF ptr_valid(ptr_GR_DP_Dzero) THEN BEGIN
       IF (gr_dm_field EQ 'DM') THEN $
          message, "Substituting D0 for unavailable DM field.", /INFO
       Dzero=*ptr_GR_DP_Dzero
       Dzero_in=*ptr_GR_DP_Dzero  ; 2nd copy, left untrimmed for PPI plots
       haveD0 = 1
       ptr_free,ptr_GR_DP_Dzero
       dzerofac=1.05    ; just hard-code it, it's not a passed parameter
       IF N_ELEMENTS( dzerofac ) EQ 1 THEN BEGIN
          message,  'Adjusting GR Dzero field by factor of '+STRING(dzerofac, $
                    FORMAT='(F0.0)'), /INFO
          GR_DM_D0 = 'D0'
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
    IF ptr_valid(ptr_GR_DP_Dm) THEN ptr_free,ptr_GR_DP_Dm  ; not using field
  ENDELSE

  haveGR_Nw = 0
  gr_dp_nw = -1 & gr_dp_nw_in = -1
  gr_nw_field = 'N2'   ; set up to try to get N2 by default
  GR_NW_N2 = 'N/A'
  ; use NW/N2 field specified by gr_nw_field parameter
  ; -- if GR N2 field is not available, then ptr_GR_DP_N2 will be invalid
  IF (gr_nw_field EQ 'N2') AND ptr_valid(ptr_GR_DP_N2) THEN BEGIN
    gr_dp_nw=*ptr_GR_DP_N2
    gr_dp_nw_in=*ptr_GR_DP_N2  ; 2nd copy, left untrimmed for PPI plots
    haveGR_Nw = 1
    GR_NW_N2 = 'N2'
    ptr_free,ptr_GR_DP_N2
    IF ptr_valid(ptr_GR_DP_Nw) THEN ptr_free,ptr_GR_DP_Nw  ; not using field
  ENDIF ELSE BEGIN
    IF ptr_valid(ptr_GR_DP_Nw) THEN BEGIN
       gr_dp_nw=*ptr_GR_DP_Nw
       gr_dp_nw_in=*ptr_GR_DP_Nw  ; 2nd copy, left untrimmed for PPI plots
       haveGR_Nw = 1
       GR_NW_N2 = 'NW'
       ptr_free,ptr_GR_DP_Nw
    ENDIF ELSE message, "No Nw field for GR in netCDF file.", /INFO
    IF ptr_valid(ptr_GR_DP_N2) THEN ptr_free,ptr_GR_DP_N2  ; not using field
  ENDELSE

  haveZdr = 0
  IF ptr_valid(ptr_GR_DP_Zdr) THEN BEGIN
     Zdr=*ptr_GR_DP_Zdr
     haveZdr = myflags.HAVE_GR_ZDR
     ptr_free,ptr_GR_DP_Zdr
  ENDIF ELSE Zdr=-1

  haveKdp = 0
  IF ptr_valid(ptr_GR_DP_Kdp) THEN BEGIN
     Kdp=*ptr_GR_DP_Kdp
     haveKdp = myflags.HAVE_GR_KDP
     ptr_free,ptr_GR_DP_Kdp
  ENDIF ELSE Kdp=-1

  haveRHOhv = 0
  IF ptr_valid(ptr_GR_DP_RHOhv) THEN BEGIN
     RHOhv=*ptr_GR_DP_RHOhv
     haveRHOhv = myflags.HAVE_GR_RHOHV
     ptr_free,ptr_GR_DP_RHOhv
  ENDIF ELSE RHOhv=-1

  have_GR_blockage = 0
  IF pr_or_dpr EQ 'DPR' AND ptr_valid(ptr_GR_blockage) THEN BEGIN
     have_GR_blockage=myflags.have_GR_blockage   ; should just be 0 for version<1.21
     GR_blockage=*ptr_GR_blockage
     ptr_free, ptr_GR_blockage
  ENDIF ELSE GR_blockage = -1

  top=*ptr_top
  botm=*ptr_botm
  lat=*ptr_lat
  lon=*ptr_lon
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
  IF pr_or_dpr EQ 'DPR' AND KEYWORD_SET(declutter) THEN BEGIN
     clutterStatus=*ptr_clutterStatus
     ptr_free,ptr_clutterStatus
  ENDIF ELSE clutterStatus=0      ; just assign anything so it is defined
;  IF ptr_valid(ptr_pctgoodrrgv) THEN BEGIN
;     pctgoodrrgv=*ptr_pctgoodrrgv
;     ptr_free,ptr_pctgoodrrgv
;  ENDIF ELSE pctgoodrrgv=-1

; stuff the flags, structs, and data arrays into structures to pass along
; - at this point, they will all be copies of the originals and we can
;   butcher them as we please

haveIt = { have_gvrr : have_gvrr, $
           haveHID : haveHID, $

           haveDm : haveDm, $
           haveNw : haveNw, $
           haveGR_Nw : haveGR_Nw, $

           haveD0 : haveD0, $
           haveZdr : haveZdr, $
           haveKdp : haveKdp, $
           haveRHOhv : haveRHOhv, $
           have_pia : have_pia, $
           have_GR_blockage : have_GR_blockage }

dataStruc = { haveFlags : haveIt, $
              mygeometa : mygeometa, $
              mysite : mysite, $
              mysweeps : mysweeps, $
              gvz : gvz, $
              zraw : zraw, $
              zcor : zcor, $
              rain3 : rain3, $

              dpr_dm : dpr_Dm, $
              dpr_nw : dpr_nw, $

              gvrr : gvrr, $
              rr_field_used : rr_field_used, $
              HIDcat : HIDcat, $
              Dzero : Dzero, $

              GR_DM_D0 : GR_DM_D0, $    ; UF ID of Dzero
              gr_dp_nw : gr_dp_nw, $    ; data variable
              GR_NW_N2 : GR_NW_N2, $    ; UF ID of gr_dp_nw

              Zdr : Zdr, $
              Kdp : Kdp, $
              RHOhv : RHOhv, $
              GR_blockage : GR_blockage, $
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
  ; check that we have the necessary DSD fields present before attempting to
  ; subset variables in the save_by_ray mode
   IF save_by_ray THEN BEGIN
      IF (haveD0+haveGR_Nw+haveDm+haveNw) NE 4 THEN BEGIN
         message, "Missing Dm and/or Nw for DPR and/or GR, "+ $
                  "cannot subset and save.", /INFO
         status=1
         GOTO, errorExit
      ENDIF
   ENDIF
  ; start a loop to allow one or more subset areas to be selected by user
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
        ; user may just have right-clicked to skip storm selection. In these
        ; situations select_geomatch_subarea() should already have closed the
        ; PPI location window
         status = 1
         message, "Unable to run statistics for storm area, skipping case.",/info
         more_cowbell = 'q'
         ;wdelete, 1         ; should have already been done
         have_window1 = 0
      ENDIF ELSE BEGIN
         have_window1 = 1
         status = render_rr_or_z_plots(xxx, looprate, elevs2show, startelev, $
                                       PPIorient, windowsize, pctabvthresh, PPIbyThresh, $
                                       gvconvective, gvstratiform, hideTotals, $
                                       hide_rntype, hidePPIs, pr_or_dpr, dataStrucTrimmed, $
                                       PS_DIR=ps_dir, B_W=b_w, S2KU=s2ku, ZR=zr_force, $
                                       BATCH=batch, MAX_RANGE=max_range, $
                                       MAX_BLOCKAGE=max_blockage, $
                                       Z_BLOCKAGE_THRESH=z_blockage_thresh, $
                                       STEP_MANUAL=step_manual, DECLUTTER=declutter )

         IF status EQ 0 THEN BEGIN
            wdelete, 1
            have_window1 = 0
            saveIt=0
            IF ( N_ELEMENTS(save_dir) EQ 1 ) THEN BEGIN
               doodah = ""
               PRINT, STRING(7B)  ; ring the terminal bell
               IF save_by_ray THEN BEGIN
                  usertxt = 'Get 2AKu profile and save variables to file?  Enter Y or N : '
               ENDIF ELSE BEGIN
                  usertxt = 'Save subset variables to file?  Enter Y or N : '
               ENDELSE
               WHILE (doodah NE 'Y' AND doodah NE 'N') DO BEGIN
                  READ, doodah, PROMPT=usertxt
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
               SAVFILE = save_dir+'/'+site+'.'+yymmdd+'.'+orbit+"."+version+'.'+pr_or_dpr $
                     +instrument+'_'+swath+'.Pct'+pctString+add2nm+'_'+xxx+'.sav'

              ; Decide which variables to save.  By default, save those for the subset
              ; area analysis as originally designed.  If SAVE_BY_RAY is set, then get
              ; and save those variables requested by the 2BDPRGMI algorithm team at
              ; the single ray selected by the user

               IF save_by_ray THEN BEGIN
                 ; let user find the matching 2A-Ku file for this case and extract
                 ; the 250-m averaged reflectivity profile and the storm top height
                  dataKu = get_2aku_matching_footprint( datastrucTrimmed.storm_lat, $
                                             datastrucTrimmed.storm_lon, yymmdd, $
                                             orbit, version, STARTDIR=startdir )
                 ; JUST SAVE RETURNED STRUCT FOR NOW (TESTING),
                 ; ADD OTHER VARIABLES NEEDED BY 2BCMB DEVELOPERS LATER
                  IF size(dataKu, /TYPE) NE 8 THEN BEGIN
                     print, "No 2AKu file processed, skip saving subset variables to file."
                  ENDIF ELSE BEGIN
                     save_special_2a2b, datastrucTrimmed, dataKu, SAVFILE
                  ENDELSE
               ENDIF ELSE BEGIN
                  SAVE, ncfilepr, xxx, looprate, elevs2show, startelev, PPIorient, windowsize, $
                     pctabvthresh, PPIbyThresh, gvconvective, gvstratiform, hideTotals, $
                     hide_rntype, pr_or_dpr, datastrucTrimmed, FILE=SAVFILE
               ENDELSE
               print, "Data saved to ", SAVFILE
            ENDIF

            PRINT, '' & PRINT, STRING(7B)   ; ring the bell
            READ, more_cowbell, $
            PROMPT='Hit Return to select a different case, or ' + $
                   'M to do More storm subsets for this case: '
         ENDIF ELSE BEGIN
           ; got non-zero status from render_dsd_plots(), set up to exit WHILE loop?
            IF status EQ 2 THEN BEGIN
              ; user selected "Q" to Quit in render_dsd_plots()
               more_cowbell = 'q'
            ENDIF ELSE BEGIN
               PRINT, '' & PRINT, STRING(7B)   ; ring the bell
               READ, more_cowbell, $
               PROMPT='Hit Return to select a different case, or ' + $
                      'M to do More storm subsets for this case: '
            ENDELSE
         ENDELSE
      ENDELSE  ; case of user clicked to do valid subset selection
   ENDWHILE
   IF have_window1 THEN wdelete, 1
ENDIF ELSE BEGIN
   ; call the routine to produce the graphics and output, just doing entire area
   status = render_rr_or_z_plots(xxx, looprate, elevs2show, startelev, $
                                 PPIorient, windowsize, pctabvthresh, PPIbyThresh, $
                                 gvconvective, gvstratiform, hideTotals, hide_rntype, $
                                 hidePPIs, pr_or_dpr, dataStruc, PS_DIR=ps_dir, $
                                 B_W=b_w, S2KU=s2ku, ZR=zr_force, BATCH=batch, $
                                 MAX_RANGE=max_range, MAX_BLOCKAGE=max_blockage, $
                                 Z_BLOCKAGE_THRESH=z_blockage_thresh, $
                                 STEP_MANUAL=step_manual, DECLUTTER=declutter )
ENDELSE

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
; matchup_type - indicates which satellite radar is to be the source of the
;                matchup data to be analyzed.  Allowable values are 'PR', 'DPR',
;                and 'DPRGMI' or 'CMB'.  Default='DPR'.  If a mismatch occurs
;                between MATCHUP_TYPE and the type of matchup file selected for
;                processing then an error occurs.  In the case of DPR, the
;                matchup to GR can be for any of the 2AKa, 2AKu, or 2ADPR
;                products, for any swath type.  'CMB' is an alias for 'DPRGMI'.
;
; swath_cmb    - designates which swath (scan type) to analyze for the DPRGMI
;                matchup type.  Allowable values are 'MS' and 'NS' (default).
;
; KuKa_cmb     - designates which DPR instrument's data to analyze for the
;                DPRGMI matchup type.  Allowable values are 'Ku' and 'Ka'  If
;                swath_cmb is 'NS' then KuKa_cmb must be 'Ku'.  If unspecified
;                or if in conflict with with swath_cmb then the value will be
;                assigned to 'Ku' by default.
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
; DPR_Z_ADJUST - Optional parameter.  Bias offset to be applied (added to) the
;                DPR reflectivity values to account for the calibration offset
;                between the DPR and ground radars in a global sense (same for
;                all GR sites).  Positive (negative) value raises (lowers) the
;                non-missing DPR reflectivity values.
;
; GR_Z_ADJUST  - Optional parameter.  Pathname to a "|"-delimited text file
;                containing the bias offset to be applied (added to) each
;                ground radar site's reflectivity to correct the calibration
;                offset between the DPR and ground radars in a site-specific
;                sense.  Each line of the text file lists one site identifier
;                and its bias offset value separated by the delimiter, e.g.:
;
;                  KMLB|2.89
;
;                If no matching site entry is found in the file for a radar,
;                then its reflectivity is not changed from the value in the
;                matchup netCDF file.  The bias adjustment is applied AFTER
;                the frequency adjustment if the S2KU parameter is set.
;
; max_range_in - Maximum range from the ground radar (in km) of samples to be
;                included in the mean difference calculations.  Defaults to 100
;                if not specified.
;
; max_blockage_in - Maximum fractional GR beam blockage to allow in samples to
;                   be included in the mean difference calculations.  If value
;                   is between 0.0 and 1.0 it is treated as the fraction of
;                   blockage.  If value is greater than 1 and <= 100, it is
;                   treated as percent blockage and is converted to a fractional
;                   amount.  Disables beam blockage checking if not specified,
;                   if resulting fractional amount is 1.0 (100%), or if matchup
;                   file does not contain the GR_blockage variable.
;
; z_blockage_thresh_in - optional parameter to limit samples included in the
;                        comparisons by beam blockage, as implied by a Z dropoff
;                        between the second and first sweeps.  Is ignored in the
;                        presence of valid MAX_BLOCKAGE value and presence of
;                        GR_blockage data.
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
; alt_bb_hgt    - Manually-specified Bright Band Height (km) to be used if the
;                 bright band height cannot be determined from the DPR data.
;
; forcebb       - Binary parameter, controls whether to override the bright band
;                 height from the satellite radar with the value supplied by the
;                 alt_bb_hgt parameter.
;
; hide_totals   - Binary parameter, controls whether to show (default) or hide
;                 the PDF and profile plots for rain type = "Any".
;
; hide_rntype   - (Optional) binary parameter, indicates whether to use hatching
;                 in the PPI plots indicating the PR rain type identified for
;                 the given ray.
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
; gr_rr_field_in - UF field ID of the GR rain rate estimate source to be used:
;                  RC (Cifelli), RP (PolZR), or RR (DROPS, default)
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
; save_by_ray    - Optional binary parameter.  If set, overrides or sets values
;                  of subset_method and min_for_subset such that the user is
;                  prompted to select a subset area, and a subset area of only
;                  one footprint (one DPR ray) is selected when the user clicks
;                  on a location.  Sets subset_method='D' and min_for_subset=3.
;                  KEYWORD ONLY APPLIES WHEN MATCHUP_TYPE='DPRGMI', IS IGNORED
;                  FOR OTHER MATCHUP_TYPE SETTINGS.
;
; save_dir       - Optional directory specification to which the subsetted
;                  variables in a structure will be saved in an IDL SAVE file if
;                  the user chooses to save them.
;
; step_manual    - Flag and Rate value to toggle and control the alternative
;                  method of animation of PPI images.  If unset, animation is
;                  automated in an XINTERANIMATE window (default, legacy
;                  behavior).  If set to a non-zero value, then the PPI images
;                  will be stepped through under user control: either one at a
;                  time in forward or reverse, or in an automatic forward
;                  sequence where the pause, in seconds, between frames is
;                  defined by the step_manual value.  The automated sequence
;                  will only play one time in the latter mode, starting from
;                  the currently-displayed frame.
;
; declutter      - (Optional) binary parameter, if set to ON, then read and use
;                  the clutterStatus variable to filter out clutter-flagged
;                  volume match samples, regardless of pctAbvThresh status.

pro geo_match_3d_rr_or_z_comparisons, RR_OR_Z=rr_or_z, $
                                      MATCHUP_TYPE=matchup_type, $
                                      SWATH_CMB=swath_cmb, $
                                      KUKA_CMB=KuKa_cmb, $
                                      SPEED=looprate, $
                                      ELEVS2SHOW=elevs2show, $
                                      NCPATH=ncpath, $
                                      SITE=sitefilter, $
                                      NO_PROMPT=no_prompt, $
                                      PPI_VERTICAL=ppi_vertical, $
                                      PPI_SIZE=ppi_size, $
                                      PCT_ABV_THRESH=pctAbvThresh, $
                                      DPR_Z_ADJUST=dpr_z_adjust_in, $
                                      GR_Z_ADJUST=gr_z_adjust, $
                                      MAX_RANGE=max_range_in, $
                                      MAX_BLOCKAGE=max_blockage_in, $
                                      Z_BLOCKAGE_THRESH=z_blockage_thresh_in, $
                                      SHOW_THRESH_PPI=show_thresh_ppi, $
                                      GV_CONVECTIVE=gv_convective, $
                                      GV_STRATIFORM=gv_stratiform, $
                                      ALT_BB_HGT=alt_bb_hgt, $
                                      FORCEBB=forcebb, $
                                      HIDE_TOTALS=hide_totals, $
                                      HIDE_RNTYPE=hide_rntype, $
                                      HIDE_PPIS=hide_ppis, $
                                      PS_DIR=ps_dir, $
                                      B_W=b_w, $
                                      BATCH=batch, $
                                      S2KU = s2ku, $
                                      USE_ZR = use_zr, $
                                      GR_RR_FIELD=gr_rr_field_in, $
                                      RECALL_NCPATH=recall_ncpath, $
                                      SUBSET_METHOD=subset_method, $
                                      MIN_FOR_SUBSET=min_for_subset, $
                                      SAVE_DIR=save_dir, $
                                      SAVE_BY_RAY=save_by_ray_in, $
                                      STEP_MANUAL=step_manual, $
                                      DECLUTTER=declutter

print, "" & print, "NOTE:"
PRINT, "This procedure has been superseded by geo_match_3d_comparisons.pro, ", $
       "a merger of geo_match_3d_rr_or_z_comparisons.pro and ", $
       "geo_match_3d_dsd_comparisons.pro.  Exiting."
GOTO, earlyExit

print
print, "#############################################################"
print, "#  GEO_MATCH_3D_RR_OR_Z_COMPARISONS: Version 1.1            #"
print, "#  (Statistical Analysis Program for Geometry-Match data)   #"
print, "#  NASA/GSFC/GPM Ground Validation, November 2016           #"
print, "#############################################################"
print


; determine whether to compute Z or Rainrate statistics
IF ( N_ELEMENTS(rr_or_z) NE 1 ) THEN BEGIN
   print, "Defaulting to Z for comparison element."
   xxx = 'Z'
ENDIF ELSE BEGIN
   CASE STRUPCASE(rr_or_z) OF
       'Z' : xxx = 'Z'
      'RR' : xxx = 'RR'
      ELSE : message, "Only allowed values for RR_OR_Z are Z and RR"
   ENDCASE
ENDELSE

IF ( N_ELEMENTS(matchup_type) NE 1 ) THEN BEGIN
   print, "Defaulting to DPR for matchup_type."
   pr_or_dpr = 'DPR'
ENDIF ELSE BEGIN
   CASE STRUPCASE(matchup_type) OF
      'PR' : pr_or_dpr = 'PR'
     'DPR' : pr_or_dpr = 'DPR'
     'CMB' : pr_or_dpr = 'DPRGMI'
  'DPRGMI' : pr_or_dpr = 'DPRGMI'
      ELSE : message, "Only allowed values for MATCHUP_TYPE are PR, DPR, and CMB or DPRGMI"
   ENDCASE
ENDELSE

save_by_ray = 0  ; only override this if analyzing DPRGMI and SAVE_BY_RAY is set
IF pr_or_dpr EQ 'DPRGMI' THEN BEGIN
   save_by_ray = KEYWORD_SET(save_by_ray_in)
   IF N_ELEMENTS(swath_cmb) NE 1 THEN BEGIN
      message, "No swath type specified for DPRGMI Combined, "+ $
               "defaulting to NS from Ku.", /INFO
      swath = 'NS'
      KUKA = 'Ku'
   ENDIF ELSE BEGIN
      CASE swath_cmb OF
        'MS' : BEGIN
                 swath = swath_cmb
                 IF N_ELEMENTS(KuKa_cmb) EQ 1 THEN BEGIN
                    CASE STRUPCASE(KuKa_cmb) OF
                      'KA' : KUKA = 'Ka'
                      'KU' : KUKA = 'Ku'
                      ELSE : BEGIN
                               message, "Only allowed values for KUKA_CMB are Ka or Ku.', /INFO
                               print, "Overriding KUKA_CMB value '", KuKa_cmb, $
                                      "' to Ku for MS swath."
                             END
                    ENDCASE
                 ENDIF ELSE BEGIN
                    print, "No KUKA_CMB value, using Ku data for MS swath by default."
                    KuKa = 'Ku'
                 ENDELSE
               END
        'NS' : BEGIN
                 swath = swath_cmb
                 IF N_ELEMENTS(KuKa_cmb) EQ 1 THEN BEGIN
                    IF STRUPCASE(KuKa_cmb) NE 'KU' THEN $
                       message, "Overriding KUKA_CMB to Ku for NS swath.", /INFO
                 ENDIF ELSE print, "Using Ku data for NS swath by default."
                 KuKa = 'Ku'
               END
        ELSE : message, "Illegal SWATH_CMB value for DPRGMI, only MS or NS allowed."
      ENDCASE
   ENDELSE
ENDIF ELSE BEGIN
   IF KEYWORD_SET(save_by_ray_in) THEN print, "Ignoring SAVE_BY_RAY setting for ", $
                                              pr_or_dpr, " matchup type."
ENDELSE

; 12/2016/Morris - disable save_by_ray for now, data structures do not have
;                  all the required DSD variables
;save_by_ray = 0  

; override or initialize assignments based on subset_method (submeth) and
; min_for_subset (subthresh) if SAVE_BY_RAY is set
IF save_by_ray THEN BEGIN
   submeth = 'D'
   subthresh = 3.0  ; try to grab just one footprint
ENDIF ELSE BEGIN
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
ENDELSE

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
   CASE STRUPCASE(pr_or_dpr) OF
      'PR' : ncfilepatt = 'GRtoPR.*'
     'DPR' : ncfilepatt = 'GRtoDPR.*'
  'DPRGMI' : ncfilepatt = 'GRtoDPRGMI.*'
   ENDCASE
   print, "Defaulting to "+ncfilepatt+" for file pattern."
ENDIF ELSE ncfilepatt = '*'+sitefilter+'*'

PPIorient = keyword_set(ppi_vertical)
PPIbyThresh = keyword_set(show_thresh_ppi)
;RR_PPI = keyword_set(ppi_is_rr)
hideTotals = keyword_set(hide_totals)
hideRntype = keyword_set(hide_rntype)
hidePPIs = keyword_set(hide_ppis)
b_w = keyword_set(b_w)
s2ku = keyword_set(s2ku)
zr_force = keyword_set(use_zr)

IF ( N_ELEMENTS(ppi_size) NE 1 ) THEN BEGIN
   print, "Defaulting to 350 for PPI size."
   ppi_size = 350
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

; configure bias adjustment for GR and/or DPR

IF N_ELEMENTS( gr_z_adjust ) EQ 1 THEN BEGIN
   IF FILE_TEST( gr_z_adjust ) THEN BEGIN
     ; read the site bias file and store site IDs and biases in a HASH variable
      site_bias_hash_status = site_bias_hash_from_file( gr_z_adjust )
      IF TYPENAME(site_bias_hash_status) EQ 'HASH' THEN BEGIN
        ; define passed parameter, undefine returned value
         siteBiasHash = TEMPORARY(site_bias_hash_status)
      ENDIF ELSE BEGIN
         print, "Problems with GR_Z_ADJUST file: ", gr_z_adjust
         entry = ''
         WHILE STRUPCASE(entry) NE 'C' AND STRUPCASE(entry) NE 'Q' DO BEGIN
            read, entry, PROMPT="Enter C to continue without GR site bias adjustment " $
                   + "or Q to exit here: "
            CASE STRUPCASE(entry) OF
                'C' : BEGIN
                        break
                      END
                'Q' : GOTO, earlyExit
               ELSE : print, "Invalid response, enter C or Q."
            ENDCASE
         ENDWHILE  
      ENDELSE       
   ENDIF ELSE message, "File '"+gr_z_adjust+"' for GR_Z_ADJUST not found."
ENDIF

IF N_ELEMENTS( dpr_z_adjust_in) EQ 1 THEN BEGIN
   IF is_a_number( dpr_z_adjust_in ) THEN BEGIN
      dpr_z_adjustF = FLOAT( dpr_z_adjust_in )  ; in case of STRING entry
      IF dpr_z_adjustF GE -3.0 AND dpr_z_adjustF LE 3.0 THEN BEGIN
         dpr_z_adjust = dpr_z_adjustF  ; define passed parameter
       ENDIF ELSE BEGIN
         message, "DPR_Z_ADJUST value must be between -3.0 and 3.0 (dBZ)"
      ENDELSE
   ENDIF ELSE message, "DPR_Z_ADJUST value is not a number."
ENDIF


IF N_ELEMENTS(max_blockage_in) EQ 1 THEN BEGIN
   IF is_a_number(max_blockage_in) THEN BEGIN
      IF max_blockage_in LT 0 OR max_blockage_in GT 100 THEN BEGIN
         message, "Illegal MAX_BLOCKAGE value, must be between 0 and 100."
      ENDIF ELSE BEGIN
         IF max_blockage_in GT 1 THEN BEGIN
            max_blockage = max_blockage_in/100.
            print, "Converted MAX_BLOCKAGE percent to fractional amount: ", $
                   STRING(max_blockage, FORMAT='(F0.2)')
         ENDIF ELSE max_blockage = FLOAT(max_blockage_in)
      ENDELSE
    ENDIF ELSE BEGIN
         message, "Illegal MAX_BLOCKAGE, must be a number between 0 and 100."
    ENDELSE
ENDIF

IF N_ELEMENTS(z_blockage_thresh_in) EQ 1 THEN BEGIN
   IF is_a_number(z_blockage_thresh_in) THEN BEGIN
      z_blockage_f = FLOAT(z_blockage_thresh_in)
      IF z_blockage_f LT 0.5 OR z_blockage_f GT 3.0 THEN BEGIN
         help, z_blockage_thresh_in
         message, "Out of range Z_BLOCKAGE_THRESH value, " + $
                  "must be between 0.5 and 3.0 (dBZ)"
      ENDIF ELSE z_blockage_thresh = z_blockage_f
   ENDIF ELSE BEGIN
      help, z_blockage_thresh_in
      message, "Illegal Z_BLOCKAGE_THRESH type, " + $
               "must be a number between 0.5 and 3.0"
   ENDELSE
ENDIF

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
ENDIF ELSE gr_rr_field = ''

; specify whether to skip graphical PPI output to screen in Postscript mode
IF ( PS_DIR NE '' AND KEYWORD_SET(batch) ) THEN do_batch=1 ELSE do_batch=0

; Figure out how the next file to process will be obtained.  If no_prompt is
; set, then we will automatically loop over the file sequence.  Otherwise we
; will prompt the user for the next file with dialog_pickfile() (DEFAULT).

no_prompt = keyword_set(no_prompt)

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
         IF NOT ( do_batch ) OR N_ELEMENTS(submeth) EQ 1 THEN BEGIN
           ; set up for bailout prompt every 5 cases if no_prompt and
           ; (1) not doing batch mode processing, or
           ; (2) in batch mode but doing storm subsets
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
         action = geo_match_xxx_plots( ncfilepr, xxx, looprate, elevs2show, startelev, $
                                      PPIorient, ppi_size, pctAbvThresh, PPIbyThresh, $
                                      gvconvective, gvstratiform, hideTotals, $
                                      hideRntype, hidePPIs, pr_or_dpr, ALT_BB_HGT=alt_bb_hgt, $
                                      PS_DIR=ps_dir, B_W=b_w, S2KU=s2ku, ZR=zr_force, $
                                      GR_RR_FIELD=gr_rr_field, BATCH=do_batch, $
                                      MAX_RANGE=max_range_in, MAX_BLOCKAGE=max_blockage, $
                                      Z_BLOCKAGE_THRESH=z_blockage_thresh, $
                                      DPR_Z_ADJUST=dpr_z_adjust, SITEBIASHASH=siteBiasHash, $
                                      SUBSET_METHOD=submeth, MIN_FOR_SUBSET=subthresh, $
                                      SAVE_DIR=real_save_dir, SAVE_BY_RAY=save_by_ray, $
                                      STEP_MANUAL=step_manual, SWATH=swath, KUKA=KuKa, $
                                      DECLUTTER=declutter, FORCEBB=forcebb )

         if (action EQ 2) then break    ; manual request to quit
      endfor
   endelse
ENDIF ELSE BEGIN
   ncfilepr = dialog_pickfile(path=pathpr, filter = ncfilepatt)
   while ncfilepr ne '' do begin
      action = 0
      action=geo_match_xxx_plots( ncfilepr, xxx, looprate, elevs2show, startelev, $
                                 PPIorient, ppi_size, pctAbvThresh, PPIbyThresh, $
                                 gvconvective, gvstratiform, hideTotals, $
                                 hideRntype, hidePPIs, pr_or_dpr, ALT_BB_HGT=alt_bb_hgt, $
                                 PS_DIR=ps_dir, B_W=b_w, S2KU=s2ku, ZR=zr_force, $
                                 GR_RR_FIELD=gr_rr_field, BATCH=do_batch, $
                                 MAX_RANGE=max_range_in, MAX_BLOCKAGE=max_blockage, $
                                 Z_BLOCKAGE_THRESH=z_blockage_thresh, $
                                 DPR_Z_ADJUST=dpr_z_adjust, SITEBIASHASH=siteBiasHash, $
                                 SUBSET_METHOD=submeth, MIN_FOR_SUBSET=subthresh, $
                                 SAVE_DIR=real_save_dir, SAVE_BY_RAY=save_by_ray, $
                                 STEP_MANUAL=step_manual, SWATH=swath, KUKA=KuKa, $
                                 DECLUTTER=declutter, FORCEBB=forcebb )

      if (action EQ 2) then break         ; manual request to quit

      newpathpr = FILE_DIRNAME(ncfilepr)  ; set the path to the last file's path
      IF KEYWORD_SET(recall_ncpath) THEN BEGIN
         ; define/assign new default path for session as user system variable
          IF (haveUserVar EQ 1) THEN !LAST_NCPATH = newpathpr $
          ELSE DEFSYSV, '!LAST_NCPATH', newpathpr
      ENDIF
      PRINT, "Select next file to process or close File Selector to quit."
      ncfilepr = dialog_pickfile(path=newpathpr, filter = ncfilepatt)
   endwhile
ENDELSE

earlyExit:
print, "" & print, "Done!"
END

