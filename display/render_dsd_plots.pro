;===============================================================================
;+
; Copyright © 2015, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; render_dsd_plots.pro      Morris/SAIC/GPM_GV    May 2015
;
; DESCRIPTION
; -----------
; Computes mean PR-GR Z, D0, and Nw differences for fixed height levels and for
; points in the below-bright-band proximity level for points within 100 km (by
; default) of the ground radar and reports the results in tables to stdout. 
; If specified, max_range overrides the 100 km default range.   Also produces
; graphs of the Probability Density Function of PR and GR Z, D0, and Nw at the
; below-BB level if data exists at that level, and vertical profiles of
; mean PR and GR Z, D0, and Nw for each of 3 rain type categories: Any,
; Stratiform, and Convective. Produces scatter plots of DPR vs. GR for Z, D0,
; and Nw for the below-BB layer for convective and stratiform rain points. Also
; produces scatter plots of Nw vs. D0 by source (DPR and GR) and by rain type 
; (convective and stratiform) for the below-BB level in a separate window.
; Optionally, produces a single frame or an animation loop of GR and equivalent
; PR PPI images for N=elevs2show frames unless hidePPIs is set.  If Z_PPIs is
; set then only DPR and GR reflectivity PPIs are shown, otherwise DPR and GR Z,
; D0, and NW PPIs are shown along with GR Zdr (DR), Hydrometeor ID (FH), and
; Kdp (KD) PPIs. Unless hide_rntype is set the plotted matchup sample footprints
; in the PPIs are encoded by rain type by fill patterns: solid=Other,
; vertical=Convective, horizontal=Stratiform.
;
; If PS_DIR is specified then the output is to a Postscript file under ps_dir,
; otherwise all output is to the screen.  When outputting to Postscript, the
; PPI plotting is still sent to the screen (unless hidePPIs is set) but the PDF
; and scatter plots go only to the Postscript device along with a copy of each
; frame of the PPI images in the static image or the animation loop.  The name
; of the Postscript file uses the station ID, datestamp, and DPR orbit number,
; PPS version, Instrument (Ka or Ku) and swath type taken from the geo_match
; netCDF data file. If b_w is set, then Postscript output will be black and
; white for the profile/PDF plots, otherwise they are plotted in color.
;
; If s2ku binary parameter is set, then the Liao/Meneghini S-to-Ku band
; reflectivity adjustment will be made to the GR reflectivity used to compute
; the GR rainrate.  If dzerofac is set, then the GR Dzero field will be
; multiplied by this bias factor to make Dzero equivalent to the DPR Dm field.
;
; If gr_rr_field is set, then the GR rainrate field whose ID matches this value
; will be used if available.  Otherwise the 'RR' field (DROPS estimate) will be
; used by default if available, and if not, then a Z-R rainrate estimate will be
; computed and used. In all cases, if zr_force is set then a Z-R rainrate
; estimate will be computed and used, regardless of the value of gr_rr_field.
;
; This function is a child routine to the geo_match_3d_dsd_comparisons
; procedure.
;
; INTERNAL MODULES
; ----------------
; 1) render_dsd_plots - Main procedure called by user.
;
; NON-SYSTEM ROUTINES CALLED
; --------------------------
; 1) z_r_rainrate()
; 2) calc_geo_pr_gv_meandiffs_wght_idx
; 3) plot_dsd_scatter_by_raintype_ps (for postscript option) OR
; 4) plot_dsd_scatter_by_raintype
; 5) plot_scatter_d0_vs_nw_by_raintype_ps (for postscript option) OR
; 6) plot_scatter_d0_vs_nw_by_raintype
; 7) plot_geo_match_ppi_anim_ps
;
;
; HISTORY
; -------
; 05/01/15 Morris, GPM GV, SAIC
; - Created from code extracted from geo_match_dsd_comparisons.pro
; 05/08/15  Morris/GPM GV/SAIC
; - Filled in logic to fully implement BATCH option with Postscript output.
; 05/12/15  Morris/GPM GV/SAIC
; - Made status value changes to support multiple storm selection by caller
;   and to not force exit by caller when no valid data exist to process for
;   the current case.  Add orbit/GR time title to PPI plot window.
; 06/25/15  Morris/GPM GV/SAIC
; - Removed ncfilepr positional parameter from call sequence, its filename
;   metadata is now passed in the data structure.
; - Made changes to ppi_comn structure required for call to modified
;   plot_geo_match_ppi_anim_ps procedure.
; 07/17/15  Morris/GPM GV/SAIC
; - Added DECLUTTER parameter to support filtering of clutter-affected samples. 
; 09/24/15, Bob Morris/GPM GV (SAIC)
; - Changed data array variable name GR_DP_Nw to lower case to distinguish from
;   UF ID variables.
; - Changed passed value of GR_DM_D0 to specifically label scatter plots axes
;   as D0, adjusted D0, or Dm.  Add as a new parameter to pass to the various
;   plot_scatter routines.
; - Write the UF ID of the GR D0, Dm, NW, or N2 fields in use to screen and/or
;   Postscript file above their tablulated statistics.
; - Changed name convention of temptext and PSFILEpdf temporary/output files.
; 12/11/15 by Bob Morris, GPM GV (SAIC)
; - Removed unused ALT_BB_HEIGHT keyword parameter from call sequence.
; - Added MAX_BLOCKAGE optional parameter to limit samples included in the
;   statistics by maximum allowed GR beam blockage. Only applies to matchup file
;   version 1.21 or later with computed beam blockage.
; - Added Z_BLOCKAGE_THRESH optional parameter to limit samples included in the
;   comparisons by beam blockage, as implied by a Z dropoff between the second
;   and first sweeps that exceeds the value of this parameter. Is only used if
;   MAX_BLOCKAGE is unspecified, or where no blockage information is contained
;   in the matchup file.
; 06/06/16 by Bob Morris, GPM GV (SAIC)
; - Added IDX_USED parameter to return the 1-D array indices of the data samples
;   included in the statistics (scatter plots, etc.) after all data clipping and
;   filtering has been done.
; 12/06/16 by Bob Morris, GPM GV (SAIC)
; - Added ability to process DPRGMI matchup type.
; - Modified user messages in no-data cases, and prompt text in READ statement
;   for subset case.
; 01/26/17 by Bob Morris, GPM GV (SAIC)
; - Added a line to reset !P.MULTI when exiting early from data types plot loop
;   to prevent problems when no valid data samples are found.
; 03/24/17 Morris, GPM GV, SAIC
; - Added LAND_OCEAN=land_ocean keyword/value pair to filter analyzed samples by
;   underlying surface type.
; - Added FILTER_BLOCKED_BY=filter_blocked_by keyword/value pair to specify
;   method used to filter analyzed samples by GR blockage, either By (C)olumn or
;   by (S)ample.
; - Implemented a combination flag2filter array to cumulatively tag samples to
;   be filtered by multiple criteria evaluated in sequence.
; - Added thresholded Z PPIs to Z-only PPI plots when that option is active
;   and thresholding has been done.
; - Implemented blanking of filtered samples in plots of Z and RR PPIs whenever
;   filtering has occurred.
; 08/15/17 Morris, GPM GV, SAIC
; - Changed plot and histogramming ranges of Dm and Nw to 0.0-5.0.
;
;
; EMAIL QUESTIONS OR COMMENTS AT:
;       https://pmm.nasa.gov/contact
;-
;===============================================================================

; Module 1:  render_dsd_plots

function render_dsd_plots, looprate, elevs2show, startelev, $
                           PPIorient, windowsize, pctabvthresh, PPIbyThresh, $
                           Z_PPIs, gvconvective, gvstratiform, hideTotals, $
                           hide_rntype, hidePPIs, pr_or_dpr, data_struct, $
                           PS_DIR=ps_dir, B_W=b_w, S2KU=s2ku_in, ZR=zr_force, $
                           DZEROFAC=dzerofac, MAX_BLOCKAGE=max_blockage, $
                           Z_BLOCKAGE_THRESH=z_blockage_thresh, $
                           GR_RR_FIELD=gr_rr_field, BATCH=batch, $
                           MAX_RANGE=max_range, SUBSET_METHOD=submeth, $
                           MIN_FOR_SUBSET=subthresh, SAVE_DIR=save_dir, $
                           FILTER_BLOCKED_BY=filter_blocked_by, $
                           STEP_MANUAL=step_manual, DECLUTTER=declutter_in, $
                           LAND_OCEAN=land_ocean, IDX_USED=idx_used

; "include" file for PR data constants
@pr_params.inc

s2ku=KEYWORD_SET(s2ku_in)
declutter=KEYWORD_SET(declutter_in)

xxx = ''  ; hard code as empty for development, controls PctAbvThresh tests

pctString = STRTRIM(STRING(FIX(pctabvthresh)),2)

frequency = data_struct.KuKa        ; 'DPR', 'KA', or 'KU', from input GPM 2Axx file
site = data_struct.mysite.site_id
yymmdd = data_struct.DATESTAMP      ; in YYMMDD format
orbit = data_struct.orbit
version = data_struct.version
swath = data_struct.swath
; put the "Instrument" ID from the passed structure into its PPS designation
CASE STRUPCASE(frequency) OF
    'KA' : freqName='Ka'
    'KU' : freqName='Ku'
   'DPR' : freqName='DPR'
    ELSE : freqName=''
ENDCASE

;IF pr_or_dpr EQ 'DPR' THEN BEGIN
;   instrument='2A'+freqName
;ENDIF ELSE BEGIN
;   instrument='Ku'
;ENDELSE
CASE pr_or_dpr OF
       'DPR' : instrument='2A'+freqName
    'DPRGMI' : instrument='CMB'
        'PR' : instrument='Ku'
ENDCASE

; pull copies of all the data variables and flags out of the passed structure
have_gvrr = data_struct.haveFlags.have_gvrr
haveHID = data_struct.haveFlags.haveHID
haveDm = data_struct.haveFlags.haveDm
haveD0 = data_struct.haveFlags.haveD0
haveNw = data_struct.haveFlags.haveNw
haveGR_Nw = data_struct.haveFlags.haveGR_Nw
haveZdr = data_struct.haveFlags.haveZdr
haveKdp = data_struct.haveFlags.haveKdp
haveRHOhv = data_struct.haveFlags.haveRHOhv
; and set flag to try to filter by GR blockage if blockage data are present
do_GR_blockage = data_struct.haveFlags.have_GR_blockage
 
; reset do_GR_blockage flag if set but no MAX_BLOCKAGE value is given
IF do_GR_blockage EQ 1 AND N_ELEMENTS(max_blockage) NE 1 $
   THEN do_GR_blockage = 0

; if do_GR_blockage flag is not set, account for the presence of the
; Z_BLOCKAGE_THRESH value and set it to the alternate method if indicated
;z_blockage_thresh=3  ; uncomment for testing
IF do_GR_blockage EQ 0 AND N_ELEMENTS(z_blockage_thresh) EQ 1 $
   THEN do_GR_blockage = 2

blockfilter = 'C'    ; initialize blockage filter to "by Column" for DSD
IF do_GR_blockage NE 0 AND N_ELEMENTS(filter_blocked_by) NE 0 THEN BEGIN
  ; set blockage filter to caller's requested type, if valid
   CASE STRUPCASE(filter_blocked_by) OF
       'S' : blockfilter = 'S'
       'C' : blockfilter = 'C'
      ELSE : BEGIN
               message, "Unknown FILTER_BLOCKED_BY value, defaulting to C(olumn).", /INFO
               blockfilter = 'C'
             END
   ENDCASE
ENDIF

gvz = data_struct.gvz
gvz_in = gvz                   ; for plotting as PPI
zraw = data_struct.zraw
zraw_in = zraw                 ; for plotting as PPI
zcor = data_struct.zcor
zcor_in = zcor                 ; for plotting as PPI
rain3 = data_struct.rain3
rain3_in = rain3               ; for plotting as PPI
dpr_dm = data_struct.dpr_Dm
dpr_dm_in = dpr_Dm
dpr_nw = data_struct.dpr_nw
dpr_nw_in = dpr_nw
gvrr = data_struct.gvrr
gvrr_in = gvrr                 ; for plotting as PPI
HIDcat = data_struct.HIDcat
Dzero = data_struct.Dzero
Dzero_in = Dzero
GR_DM_D0 = data_struct.GR_DM_D0   ; for labeling scatter plot axes, may change from input
GR_DM_D0_PPI = GR_DM_D0           ; for plotting PPIs, remains unchanged
gr_dp_nw = data_struct.gr_dp_nw
gr_dp_nw_in = gr_dp_nw
GR_NW_N2 = data_struct.GR_NW_N2
Zdr = data_struct.Zdr
Kdp = data_struct.Kdp
RHOhv = data_struct.RHOhv
IF do_GR_blockage EQ 1 THEN GR_blockage = data_struct.GR_blockage
top = data_struct.top
botm = data_struct.botm
lat = data_struct.lat
lon = data_struct.lon
;pia = data_struct.pia          ; not used -- yet
rnflag = data_struct.rnflag
rntype = data_struct.rntype
landOcean = data_struct.landOcean
pr_index = data_struct.pr_index
xcorner = data_struct.xcorner
ycorner = data_struct.ycorner
bbProx = data_struct.bbProx
dist = data_struct.dist
hgtcat = data_struct.hgtcat
pctgoodpr = data_struct.pctgoodpr
pctgoodgv = data_struct.pctgoodgv
pctgoodrain = data_struct.pctgoodrain
pctgoodrrgv = data_struct.pctgoodrrgv
clutterStatus = data_struct.clutterStatus
BBparms = data_struct.BBparms
heights = data_struct.heights
hgtinterval = data_struct.hgtinterval

show_ppis=1   ; initialize to ON, override if PS and BATCH both are set
status = 1    ; init to failure in case we hit errors early


; open a file to hold output stats to be appended to the Postscript file,
; if Postscript output is indicated
IF KEYWORD_SET( ps_dir ) THEN BEGIN
   do_ps = 1
   IF KEYWORD_SET( batch ) THEN show_ppis=0     ; don't display PPIs/animation
   temptext = ps_dir + '/dsd_stats_temp.txt'
   OPENW, tempunit, temptext, /GET_LUN
ENDIF ELSE do_ps = 0

; unilaterally override show_ppis to 0 if hidePPIs is true
IF hidePPIs THEN show_ppis=0

IF pr_or_dpr EQ 'DPRGMI' THEN BEGIN
   CASE data_struct.swath OF
     'MS' : nfp = data_struct.mygeometa.num_footprints_MS
     'NS' : nfp = data_struct.mygeometa.num_footprints_NS
     ELSE : message, "Invalid swath/scanType: "+data_struct.swath
   ENDCASE
ENDIF ELSE nfp = data_struct.mygeometa.num_footprints
nswp = data_struct.mygeometa.num_sweeps
site_lat = data_struct.mysite.site_lat
site_lon = data_struct.mysite.site_lon
siteID = string(data_struct.mysite.site_id)

; override flag if forcing Z-R usage
IF KEYWORD_SET(zr_force) THEN have_gvrr = 0
print, ''
IF (have_gvrr) THEN BEGIN
   gvrr_txt = "Using GR "+data_struct.rr_field_used+" field."
   var2='RR'
ENDIF ELSE BEGIN
   gvrr_txt = "Using GR RR from Z-R."
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

;-------------------------------------------------
 
; Define and/or reset filter flag variables if doing blockage, clutter, or 
; surface type filtering
IF do_GR_blockage NE 0 OR KEYWORD_SET(declutter) $
   OR N_ELEMENTS( land_ocean ) EQ 1 THEN BEGIN
      flag2filter = INTARR( SIZE(gvz, /DIMENSIONS) )
      filterText=''
ENDIF ;ELSE filterText='N/A'

; identify and filter out GR-beam-blocked samples if a method is active

IF do_GR_blockage NE 0 THEN BEGIN
   idxchk = WHERE(gvz[*,0] GT 0.0 and gvz[*,1] GT 0.0, countchk)
   if countchk gt 0 then begin
      CASE do_GR_blockage OF
         1 : BEGIN
             print, '' & print, "FILTERING BY ACTUAL BLOCKAGE"
             CASE blockfilter OF
               'S' : BEGIN
                      ; find blockage exceeding threshold at any valid sample
                       idxblok = WHERE(GR_blockage GT max_blockage $
                                       AND gvz GT 0.0, countblok)
                       print, 'Samples excluded based on blockage: ', $
                              countblok
                     END
               'C' : BEGIN
                      ; find any blockage at lowest sweep and tag entire column above it
                       idxcol = WHERE(GR_blockage[idxchk,0] GT max_blockage, countblok)
                       IF countblok GT 0 THEN BEGIN
                          idxall = LINDGEN(SIZE(gvz, /DIMENSIONS))
                          idxblok = idxall[idxchk[idxcol],*]
                       ENDIF
                       print, 'Columns excluded based on blockage: ', $
                              countblok, ' of ', countchk
                     END
             ENDCASE
             END
         2 : BEGIN
             ; check the difference between the two lowest sweep Z values for
             ; a drop-off in the lowest sweep that indicates beam blockage
             print, ''
             print, "FILTERING BY BLOCKAGE FROM Z DROPOFF >", z_blockage_thresh
             idxcol = WHERE(gvz[idxchk,1]-gvz[idxchk,0] GT z_blockage_thresh, $
                            countblok)
             print, 'Columns excluded based on blockage: ', countblok, ' of ', countchk
             IF countblok GT 0 THEN BEGIN
               ; define an array of indices for all points
                idxall = LINDGEN(SIZE(gvz, /DIMENSIONS))
                IF blockfilter EQ 'C' THEN BEGIN
                  ; tag the entire column above the blockage if by-column is specified
                   idxblok = idxall[idxchk[idxcol],*]
                ENDIF ELSE BEGIN
                  ; just tag the lowest level with blockages
                   idxblok = idxall[idxchk[idxcol],0]
                ENDELSE
             ENDIF
             END
         ELSE : message, "Undefined or illegal do_GR_blockage value."
      ENDCASE
     ; define flag for the samples to be excluded if we found any blockage
      IF N_ELEMENTS(countblok) NE 0 THEN BEGIN
;         flag2filter = INTARR( SIZE(gvz, /DIMENSIONS) )
;         filterText=''
         IF countblok GT 0 THEN BEGIN
            flag2filter[idxblok] = 1
            filterText=filterText+' GR_blockage'
         ENDIF
      ENDIF      
   endif
ENDIF ELSE BEGIN
   print, ''
   print, 'No filtering by GR blockage.'
ENDELSE

;-------------------------------------------------

; identify samples not meeting the clutter threshold, if option is active

IF KEYWORD_SET(declutter) THEN BEGIN
   print, 'Clipping by clutter criterion.'
  ; define index array that flags clutter-affected samples - automatically
  ; flags entire columns since clutter value is replicated over all levels
   idxcluttered = WHERE(clutterStatus GE 10, countCluttered)
  ; set any additional position flags in flag2filter to exclude by clutter criterion
   IF N_ELEMENTS(countCluttered) NE 0 THEN BEGIN
      IF ( countCluttered GT 0 ) THEN BEGIN
         flag2filter[idxcluttered] = 1
         filterText=filterText+' Clutter'
      ENDIF
   ENDIF
ENDIF

;-------------------------------------------------

; identify samples not matching the surface type criterion, if option is active

IF N_ELEMENTS( land_ocean ) EQ 1 THEN BEGIN
   print, 'Clipping by surface type criterion.'
  ; define index array that flags samples not in requested category
  ; - flags entire columns since surface type value is replicated over all levels
   idxNotMyType = WHERE( landOcean NE land_ocean, countNotMyType)
  ; set any additional position flags in flag2filter to exclude by clutter criterion
   IF N_ELEMENTS(countNotMyType) NE 0 THEN BEGIN
      IF ( countNotMyType GT 0 ) THEN BEGIN
         flag2filter[idxNotMyType] = 1
         filterText=filterText+' Land/Ocean Category'
      ENDIF
   ENDIF
ENDIF

;-------------------------------------------------

IF ( N_ELEMENTS(flag2filter) NE 0) THEN BEGIN
  ; define an array that flags samples that passed filtering tests
   unfiltered = pctgoodpr < pctgoodgv ;minpctcombined
  ; set filter-flagged samples to a negative value to exclude them in clipping
   idxfiltered = WHERE(flag2filter EQ 1, countfiltered)
   totalpts = N_ELEMENTS(unfiltered)
   print, "Filtered ",countfiltered," of ",totalpts, " based on"+filterText
   ;stop
   IF countfiltered GT 0 THEN BEGIN
     ; set samples excluded by filter criteria to a negative value and set
     ; flag to indicate filtering is needed
      unfiltered[idxfiltered] = -66.6
      altfilters = 1
   ENDIF ELSE altfilters = 0
ENDIF ELSE altfilters = 0

; - - - - - - - - - - - - - - - - - - - - - - - -

; optional data *clipping* based on percent completeness of the volume averages:
; Decide which PR and GR points to include, based on percent of expected points
; in bin-averaged results that were above dBZ thresholds set when the matchups
; were done.  If unspecified or set to zero, include all points regardless of
; 'completeness' of the volume averages.

clipem=0
minpctcombined = pctgoodpr < pctgoodgv

IF ( pctAbvThresh GT 0.0 ) THEN BEGIN
    ; clip to the 'good' points, where 'pctAbvThresh' fraction of bins in average
    ; were above threshold
   IF altfilters EQ 1 THEN BEGIN
     ; also clip to unfiltered samples
      if have_gvrr AND xxx EQ 'RR' then begin
         thresh_msg = "Thresholding by rain rate cutoff and by"+filterText+".  " + gvrr_txt
         idxgoodenuff = WHERE( pctgoodrrgv GE pctAbvThresh $
                          AND  pctgoodrain GE pctAbvThresh $
                          AND  unfiltered GE 0.0, countgoodpct )
      endif else begin
         thresh_msg = "Thresholding by reflectivity cutoffs and by"+filterText+"."
         idxgoodenuff = WHERE( pctgoodpr GE pctAbvThresh $
                          AND  pctgoodgv GE pctAbvThresh $
                          AND  unfiltered GE 0.0, countgoodpct )
      endelse
   ENDIF ELSE BEGIN
      if have_gvrr AND xxx EQ 'RR' then begin
         thresh_msg = "Thresholding by rain rate cutoff only.  " + gvrr_txt
         idxgoodenuff = WHERE( pctgoodrrgv GE pctAbvThresh $
                          AND  pctgoodrain GE pctAbvThresh, countgoodpct )
      endif else begin
         thresh_msg = "Thresholding by reflectivity cutoffs only."
         idxgoodenuff = WHERE( pctgoodpr GE pctAbvThresh $
                          AND  pctgoodgv GE pctAbvThresh, countgoodpct )
      endelse
   ENDELSE
   IF ( countgoodpct GT 0 ) THEN BEGIN
      clipem = 1
   ENDIF ELSE BEGIN
       print, "No complete-volume points based on ",xxx," Percent Above Threshold."
       goto, errorExit
   ENDELSE
ENDIF ELSE BEGIN
  ; clip to where reflectivity is for unfiltered samples only, if indicated
   IF altfilters EQ 1 THEN BEGIN
      if have_gvrr AND xxx EQ 'RR' then $
         idxgoodenuff = WHERE( pctgoodrrgv GE 0.0 $
                          AND  pctgoodrain GE 0.0 $
                          AND  unfiltered GE 0.0, countgoodpct ) $
      else idxgoodenuff = WHERE( pctgoodpr GE 0.0 $
                            AND  pctgoodgv GE 0.0 $
                            AND  unfiltered GE 0.0, countgoodpct )
      IF ( countgoodpct GT 0 ) THEN BEGIN
         clipem = 1
         thresh_msg = "Filtering by"+filterText+" criteria."
      ENDIF ELSE BEGIN
         print, "No points meeting both ",xxx," Percent Above Threshold and filtering criteria."
         goto, errorExit
      ENDELSE
   ENDIF ELSE BEGIN
     ; pctAbvThresh is 0 and altfilters flag is unset, take/plot ALL non-bogus points
      thresh_msg = "Taking all valid samples."
     ; create needed fields
      IF have_gvrr EQ 0 THEN gvrr = z_r_rainrate(gvz) $    ; override empty field
         ELSE gvrr=gvrr   ; using scaled GR rainrate from matchup file
      IF ( PPIbyThresh ) THEN BEGIN
         idx2plot=WHERE( pctgoodpr GE 0.0 AND pctgoodgv GE 0.0, countactual2d )
      ENDIF
     ; define idxgoodenuff in case we need it for IDX_USED evaluation
      idxgoodenuff = WHERE( pctgoodpr GE 0.0 $
                       AND  pctgoodgv GE 0.0, countgoodpct )
   ENDELSE
ENDELSE

IF (clipem) THEN BEGIN
   nclipped = STRING( N_ELEMENTS(gvz) - countgoodpct, FORMAT='(I0)' )
   PRINT, nclipped, " samples filtered in total."
   print, ''
   IF have_gvrr EQ 0 THEN gvrr = z_r_rainrate(gvz[idxgoodenuff]) $  ; override empty field
      ELSE gvrr=gvrr[idxgoodenuff]   ; using scaled GR rainrate from matchup file
   gvz = gvz[idxgoodenuff]
   gr_dp_nw = gr_dp_nw[idxgoodenuff]
   Dzero = Dzero[idxgoodenuff]
   zraw = zraw[idxgoodenuff]
   zcor = zcor[idxgoodenuff]
   rain3 = rain3[idxgoodenuff]
   dpr_dm = dpr_dm[idxgoodenuff]
   dpr_nw = dpr_nw[idxgoodenuff]
   top = top[idxgoodenuff]
   botm = botm[idxgoodenuff]
   lat = lat[idxgoodenuff]
   lon = lon[idxgoodenuff]
   rnFlag = rnFlag[idxgoodenuff]
   rnType = rnType[idxgoodenuff]
   dist = dist[idxgoodenuff]
   bbProx = bbProx[idxgoodenuff]
   hgtcat = hgtcat[idxgoodenuff]
;   pr_index = pr_index[idxgoodenuff] : NO! don't clip - must be full array for PPIs
   IF ( PPIbyThresh ) THEN BEGIN
      idx2plot=idxgoodenuff  ;idxpractual2d[idxgoodenuff]
      n2plot=countgoodpct
   ENDIF
ENDIF


; we only use unclipped arrays for PPIs, so we make copies of original arrays
gvz_in2 = gvz_in
zcor_in2 = zcor_in
rain3_in2 = rain3_in
gr_dp_nw_in2 = gr_dp_nw_in
Dzero_in2 = Dzero_in
dpr_dm_in2 = dpr_dm_in
dpr_nw_in2 = dpr_nw_in
IF have_gvrr EQ 0 THEN BEGIN
   gvrr_in2 = z_r_rainrate(gvz_in)
   gvrr_in2 = REFORM( gvrr_in2, nfp, nswp)
ENDIF ELSE gvrr_in2 = gvrr_in

; optional data *blanking* based on filtering and/or percent completeness of the
; volume averages for PPI plots, operating on the full arrays of gvz and zcor

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
     gr_dp_nw_in2[idx2blank] = 0.0
     Dzero_in2[idx2blank] = 0.0
     dpr_dm_in2[idx2blank] = 0.0
     dpr_nw_in2[idx2blank] = 0.0
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
   gr_dp_nw_in2[idx2blank2] = 0.0
   Dzero_in2[idx2blank2] = 0.0
   dpr_dm_in2[idx2blank2] = 0.0
   dpr_nw_in2[idx2blank2] = 0.0
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

IF countblo EQ 0 THEN BEGIN
   print, ''
   print, 'No samples in the below-bright-band layer, cannot run DSD statistics.'
   goto, errorExit
ENDIF

; set Nw and Dm to missing for samples within/above BB
IF countabv GT 0 THEN BEGIN
   dpr_dm[idxabv] = Z_MISSING
   dpr_nw[idxabv] = Z_MISSING
   Dzero[idxabv] = Z_MISSING
   gr_dp_nw[idxabv] = Z_MISSING
ENDIF
IF countin GT 0 THEN BEGIN
   dpr_dm[idxin] = Z_MISSING
   dpr_nw[idxin] = Z_MISSING
   Dzero[idxin] = Z_MISSING
   gr_dp_nw[idxin] = Z_MISSING
ENDIF

; build an array of sample volume depth for weighting of the layer averages and
; mean differences
voldepth = (top-botm) > 0.0

bs = 2.0
print, "Using Z histogram bin size = ", bs
;minz4hist = 18.  ; not used, replaced with dbzcut
maxz4hist = 55.
dbzcut = 10.      ; absolute DPR/GR dBZ cutoff of points to use in mean diff. calcs.

IF N_ELEMENTS(max_range) NE 1 THEN rangecut = 100. ELSE rangecut = max_range
fields2do = ['Z','D0','NW']
; fields2do = ['RR','D0','NW']

orig_device = !D.NAME
CASE xxx OF
   'RR' : IF (have_gvrr) THEN gr_rr_zr = ' DP RR' ELSE gr_rr_zr = ' Z-R RR'
    'Z' : gr_rr_zr = ' Zc'
   ELSE : gr_rr_zr = ' DSD'
ENDCASE

IF ( do_ps EQ 1 ) THEN BEGIN
  ; set up postscript plot params. and file path/name
   cd, ps_dir
   b_w = keyword_set(b_w)
   IF ( s2ku ) THEN add2nm = '_S2Ku' ELSE add2nm = ''
   IF data_struct.is_subset THEN BEGIN
     ; format the storm lat/lon position into a string to be added to the PS name
      IF data_struct.storm_lat LT 0.0 THEN hemi='S' ELSE hemi='N'
      IF data_struct.storm_lon LT 0.0 THEN ew='W' ELSE ew='E'
      addpos='_'+STRING(ABS(data_struct.storm_lat),FORMAT='(f0.2)')+hemi+'_'+ $
             STRING(ABS(data_struct.storm_lon),FORMAT='(f0.2)')+ew
      add2nm = add2nm+addpos
   ENDIF
   PSFILEpdf = ps_dir+'/'+site+'.'+yymmdd+'.'+orbit+"."+version+'.'+pr_or_dpr+"_" $
               +instrument+"_"+swath+'.Pct'+pctString+add2nm+'_DSD_Analysis.ps'
   print, "Output sent to ", PSFILEpdf
   set_plot,/copy,'ps'
   device,filename=PSFILEpdf,/color,bits=8,/inches,xoffset=0.75,yoffset=1.2, $
          xsize=7.,ysize=9.5

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

   CHARadj=1.0
   THIKadjPR=1.5
   THIKadjGV=1.5
   ST_THK=1
   CO_THK=1
ENDIF ELSE BEGIN
  ; set up x-window plot params.
   device, decomposed = 0
   LOADCT, 2

   IF ( pctAbvThresh GT 0.0 ) THEN BEGIN
      IF ( pctAbvThresh EQ 100.0 ) THEN gt_ge = ' ' ELSE gt_ge = ' >='
      CASE xxx OF
         'Z' : wintxt = "With" + gt_ge + pctString + $
                        "% of averaged bins above dBZ thresholds"  
        'RR' : wintxt = "With" + gt_ge + pctString + $
                        "% of averaged bins above rainrate threshold"
        ELSE : wintxt = "With" + gt_ge + pctString + $
                        "% of averaged bins above dBZ thresholds"  
      ENDCASE
   ENDIF ELSE BEGIN
      wintxt = "With all non-missing "+pr_or_dpr+"/GR matched samples"
   ENDELSE

   Window, xsize=1050, ysize=700, TITLE = site+gr_rr_zr+' vs. '+instrument+'.'+ $
           swath+"."+version+"  --  "+wintxt, RETAIN=2
   PR_COLR=30
   GV_COLR=70
   ST_LINE=1    ; dotted for stratiform
   CO_LINE=2    ; dashed for convective
   CHARadj=2.0
   THIKadjPR=1.0
   THIKadjGV=1.0
   ST_THK=3
   CO_THK=2
ENDELSE

; arrange vertically for postscript, horizontally for on-screen
IF do_ps THEN !P.Multi=[0,2,3,0,0] ELSE !P.Multi=[0,3,2,0,1]

; ##############################################################################

for field = 0,2 do begin   ; DO A BIG LOOP OVER Z, D0, NW FIELDS

xxx = fields2do[field]
IF field GT 0 THEN $
   IF do_ps THEN !P.Multi=[6-field*2,2,3,0,0] ELSE !P.Multi=[6-field*2,3,2,0,1]
;IF do_ps THEN IF field GT 0 THEN !P.Multi=[6-field*2,2,3,0,0]$
;ELSE IF field GT 0 THEN !P.Multi=[6-field*2,3,2,0,1]
IF do_ps THEN BEGIN
   dxLgd = 0.0                         ; x-offset of legend by field #
   dyLgd = (-1./3.)*field              ; y-offset of legend by field #
   LgdLineX = [0.33,0.36]              ; x-endpoints of line segments in legends
   LgdTxtX = 0.38                      ; x-start of text for above
   ScrTxtX = 0.84                      ; x-start of Bias Score text in PDF legends
ENDIF ELSE BEGIN
   dxLgd = (1./3.)*field                ; x-offset of legend by field #
   dyLgd = 0.0                          ; y-offset of legend by field #
   LgdLineX = [0.20+dxLgd,0.23+dxLgd]   ; x-endpoints of line segments in legends
   LgdTxtX = 0.24+dxLgd                 ; x-start of text for above
   ScrTxtX = 0.19+dxLgd                 ; x-start of Bias Score text in PDF legends
ENDELSE

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

IF pr_or_dpr EQ 'DPRGMI' THEN src1='CMB' ELSE src1 = pr_or_dpr
CASE xxx OF
   'RR' : BEGIN
          difftext='-GR Rain Rate difference statistics (mm/h) - GR Site: '
          cutoff = 0.1     ; cutoff RR value to include in mean diff. calcs.
          yvar = rain3
          xvar = gvrr
;          src1 = pr_or_dpr
          src2 = 'GR'
          END
    'Z' : BEGIN
          difftext='-GR Reflectivity difference statistics (dBZ) - GR Site: '
          cutoff = 10.     ; cutoff dBZ value to include in mean diff. calcs.
;          src1 = pr_or_dpr
          src2 = 'GR'
          yvar = zcor
          xvar = gvz
          END
   'D0' : BEGIN
          IF ( GR_DM_D0 EQ 'D0' ) THEN BEGIN
             IF N_ELEMENTS( dzerofac ) EQ 1 THEN BEGIN
                textout = 'Adjusted GR Dzero field by factor of ' + $
                        STRING(dzerofac, FORMAT='(F0.2)') + ' to match DPR Dm.'
               ; define GR D0 data label, indicating adjustment factor, e.g., "D0*1.05"
                GR_DM_D0 = GR_DM_D0 + "*" + STRING(dzerofac, FORMAT='(F0.2)')
             ENDIF ELSE BEGIN
                textout = 'Unadjusted GR Dzero field is being compared to DPR Dm.'
             ENDELSE
          ENDIF ELSE textout = 'GR Dm field is being directly compared to DPR Dm.'
          print, '' & print, '' & print, textout
          IF (do_ps EQ 1) THEN printf, tempunit, textout
          difftext=' Dm-GR '+GR_DM_D0+' difference statistics (mm) - GR Site: '
          cutoff = 0.1     ; cutoff value to include in mean diff. calcs.
          yvar = dpr_dm
          xvar = Dzero
;          src1 = pr_or_dpr
          src2 = 'GR'
          END
   'NW' : BEGIN
          textout = 'GR '+GR_NW_N2+' field is being directly compared to DPR Nw.'
          print, '' & print, '' & print, textout
          IF (do_ps EQ 1) THEN BEGIN
             printf, tempunit, ''
             printf, tempunit, ''
             printf, tempunit, textout
          ENDIF
          difftext='-GR Nw difference statistics (log10(Nw)) - GR Site: '
          cutoff = 0.1     ; cutoff value to include in mean diff. calcs.
          yvar = dpr_nw
          xvar = gr_dp_nw
;          src1 = pr_or_dpr
          src2 = 'GR'
          END
ENDCASE

IF field EQ 0 THEN BEGIN
   CASE pr_or_dpr OF
     'PR' : textout = pr_or_dpr + difftext + siteID + '   Orbit: ' + orbit + $
                   '  Version: '+version
     ELSE : BEGIN
             textout = pr_or_dpr + " " + Instrument + difftext + siteID
             print, textout & IF (do_ps EQ 1) THEN printf, tempunit, textout
             textout = 'Orbit: '+orbit+'  Version: '+version+'  Swath Type: '+swath
             END
   ENDCASE
   print, textout & IF (do_ps EQ 1) THEN printf, tempunit, textout

   textout = pr_or_dpr + ' time = ' + data_struct.mygeometa.atimeNearestApproach + $
          '   GR start time = ' + data_struct.mysweeps[0].atimeSweepStart
   print, textout & IF (do_ps EQ 1) THEN printf, tempunit, textout
   textout = 'Required percent of above-threshold ' + pr_or_dpr + $
          ' and GR bins in matched volumes >= '+pctString+"%"
   print, textout & IF (do_ps EQ 1) THEN printf, tempunit, textout
   IF ( pctAbvThresh GT 0.0 OR altfilters EQ 1 ) THEN BEGIN
      print, thresh_msg & IF (do_ps EQ 1) THEN printf, tempunit, thresh_msg
   ENDIF
   IF ( s2ku ) THEN BEGIN
      textout = 'GR reflectivity has S-to-Ku frequency adjustments applied.'
      print, textout & IF (do_ps EQ 1) THEN printf, tempunit, textout
   ENDIF
;   IF N_ELEMENTS( dzerofac ) EQ 1 THEN BEGIN
;      textout = 'Adjusted GR Dzero field by factor of ' + STRING(dzerofac, $
;                 FORMAT='(F0.0)') + ' to match DPR DM.'
;      print, textout & IF (do_ps EQ 1) THEN printf, tempunit, textout
;   ENDIF
ENDIF

mnprarr = fltarr(3,nhgtcats)  ; each level, for raintype all, stratiform, convective
mngvarr = fltarr(3,nhgtcats)  ; each level, for raintype all, stratiform, convective
levhasdata = intarr(nhgtcats) & levhasdata[*] = 0
levsdata = 0
max_hgt_w_data = 0.0

; - - - - - - - - - - - - - - - - - - - - - - - -

print_table_headers, src1, src2, xxx, PS_UNIT=tempunit

; - - - - - - - - - - - - - - - - - - - - - - - -

; Compute a mean DPR-GR difference at each level for xxx field

for lev2get = 0, nhgtcats-1 do begin
   havematch = 0
   thishgt = heights[lev2get]
   IF ( num_in_hgt_cat[lev2get] GT 0 ) THEN BEGIN
      flag = ''
      idx4hist = lonarr(num_in_hgt_cat[lev2get])  ; array indices used for point-to-point mean diffs
      idx4hist[*] = -1L
      if (lev2get eq BBparms.BB_HgtLo OR lev2get eq BBparms.BB_HgtHi) then flag = ' @ BB'
      diffstruc = the_struc
      calc_geo_pr_gv_meandiffs_wght_idx, yvar, xvar, rnType, dist, distcat, $
                                         hgtcat, lev2get, cutoff, rangecut, $
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
;         BREAK
      endelse
   ENDIF ELSE BEGIN
      print, "No points at height " + string(heights[lev2get], FORMAT='(f0.3)')
;      BREAK
   ENDELSE

endfor         ; lev2get = 0, nhgtcats-1

; - - - - - - - - - - - - - - - - - - - - - - - -

; Build the mean profile plot panel
if (levsdata eq 0) then begin
   print, "No valid data levels found!"
   nframes = 0
   if ( do_ps NE 1 ) THEN WDELETE, 0
   !P.MULTI=[0,1,1]
   goto, nextFile
endif

idxlev2plot = WHERE( levhasdata EQ 1, nlevs2plot )
h2plot = heights[idxlev2plot]

; figure out the y-axis range.  Use the greater of max_hgt_w_data*2.0
; and meanbb*2 as the proposed range.  Cut off at 20 km if result>20.
IF field EQ 0 THEN prop_max_y = $
   (max_hgt_w_data+2.0 > (FIX((BBparms.meanbb*2)/1.5) + 1) *1.5)<max(heights)

CASE xxx OF
   'Z' : BEGIN
          ; configure x-axis to cover the high end of the Z profiles,
          ; but no less than 50 dBZ
           zmax = MAX(mnprarr) > MAX(mngvarr)
           xmaxplot = FIX( (zmax+5.0)/5.0 ) * 5
           xmaxplot = xmaxplot > 50
;           plot, [15,50], [0,20 < prop_max_y], /NODATA, COLOR=255, $
           plot, [15,xmaxplot], [0,20 < prop_max_y], /NODATA, COLOR=255, $
             XSTYLE=1, YSTYLE=1, YTICKINTERVAL=hgtinterval, YMINOR=1, thick=1, $
             XTITLE='Level Mean Reflectivity, dBZ', YTITLE='Height Level, km', $
             CHARSIZE=1*CHARadj, BACKGROUND=0
;           xvals = [15,50]   ; x-endpoints of BB line, dBZ scale
           xvals = [15,xmaxplot]   ; x-endpoints of BB line, dBZ scale
         END
  'RR' : BEGIN
           plot, [0.1,150], [0,20 < prop_max_y], /NODATA, COLOR=255, $
             XSTYLE=1, YSTYLE=1, YTICKINTERVAL=hgtinterval, YMINOR=1, thick=1, $
             XTITLE='Level Mean Rain Rate, mm/h', YTITLE='Height Level, km', $
             CHARSIZE=1*CHARadj, BACKGROUND=0, /xlog
           xvals = [0.1,150]   ; x-endpoints of BB line, RR scale
         END
  'D0' : BEGIN
           plot, [0.0,5.0], [0,20 < prop_max_y], /NODATA, COLOR=255, $
             XSTYLE=1, YSTYLE=1, YTICKINTERVAL=hgtinterval, YMINOR=1, thick=1, $
             XTITLE='Level Mean Drop Diameter, mm', YTITLE='Height Level, km', $
             XMINOR=5, CHARSIZE=1*CHARadj, BACKGROUND=0
           xvals = [0.0,5.0]   ; x-endpoints of BB line, D0 scale
         END
  'NW' : BEGIN
           plot, [0.0,5.0], [0,20 < prop_max_y], /NODATA, COLOR=255, $
             XSTYLE=1, YSTYLE=1, YTICKINTERVAL=hgtinterval, YMINOR=1, thick=1, $
             XTITLE='Level Mean Log10(Nw)', YTITLE='Height Level, km', $
             XMINOR=5, CHARSIZE=1*CHARadj, BACKGROUND=0
           xvals = [0.0,5.0]   ; x-endpoints of BB line, Nw scale
         END
ENDCASE

IF (~ hideTotals) THEN BEGIN
  ; plot the profile for all points regardless of rain type
   prmnz2plot = mnprarr[0,*]
   prmnz2plot = prmnz2plot[idxlev2plot]
   gvmnz2plot = mngvarr[0,*]
   gvmnz2plot = gvmnz2plot[idxlev2plot]
   IF nlevs2plot GT 1 THEN BEGIN
     ; plot the profile lines
      oplot, prmnz2plot, h2plot, COLOR=PR_COLR, thick=1*THIKadjPR
      oplot, gvmnz2plot, h2plot, COLOR=GV_COLR, thick=1*THIKadjGV
   ENDIF ELSE BEGIN
     ; plot a symbol at the data point
      oplot, prmnz2plot, h2plot, COLOR=PR_COLR, psym=1, symsize=2
      oplot, gvmnz2plot, h2plot, COLOR=GV_COLR, psym=1, symsize=2
   ENDELSE
ENDIF

; plot the profile for stratiform rain type points
prmnz2plot = mnprarr[1,*]
prmnz2plot = prmnz2plot[idxlev2plot]
gvmnz2plot = mngvarr[1,*]
gvmnz2plot = gvmnz2plot[idxlev2plot]
idxhavezs = WHERE( prmnz2plot GT 0.0 and gvmnz2plot GT 0.0, counthavezs )
IF ( counthavezs GT 1 ) THEN BEGIN
  ; plot the profile lines
   oplot, prmnz2plot[idxhavezs], h2plot[idxhavezs], COLOR=PR_COLR, $
          LINESTYLE=ST_LINE, thick=3*THIKadjPR
   oplot, gvmnz2plot[idxhavezs], h2plot[idxhavezs], COLOR=GV_COLR, $
          LINESTYLE=ST_LINE, thick=3*THIKadjGV
ENDIF ELSE BEGIN
   IF ( counthavezs EQ 1 ) THEN BEGIN
     ; plot a symbol at the data point
      oplot, prmnz2plot[idxhavezs], h2plot[idxhavezs], COLOR=PR_COLR, $
             psym=6, symsize=1
      oplot, gvmnz2plot[idxhavezs], h2plot[idxhavezs], COLOR=GV_COLR, $
             psym=6, symsize=1
   ENDIF
ENDELSE

; plot the profile for convective rain type points
prmnz2plot = mnprarr[2,*]
prmnz2plot = prmnz2plot[idxlev2plot]
gvmnz2plot = mngvarr[2,*]
gvmnz2plot = gvmnz2plot[idxlev2plot]
idxhavezc = WHERE( prmnz2plot GT 0.0 and gvmnz2plot GT 0.0, counthavezc )
IF ( counthavezc GT 1 ) THEN BEGIN
   oplot, prmnz2plot[idxhavezc], h2plot[idxhavezc], COLOR=PR_COLR, $
          LINESTYLE=CO_LINE, thick=3*THIKadjPR
   oplot, gvmnz2plot[idxhavezc], h2plot[idxhavezc], COLOR=GV_COLR, $
          LINESTYLE=CO_LINE, thick=3*THIKadjGV
ENDIF ELSE BEGIN
   IF ( counthavezc EQ 1 ) THEN BEGIN
     ; plot a symbol at the data point
      oplot, prmnz2plot[idxhavezc], h2plot[idxhavezc], COLOR=PR_COLR, $
             psym=4, symsize=1
      oplot, gvmnz2plot[idxhavezc], h2plot[idxhavezc], COLOR=GV_COLR, $
             psym=4, symsize=1
   ENDIF
ENDELSE

; plot the mean BB indicator line and its legend info.
yvalsbb = [BBparms.meanbb, BBparms.meanbb]
plots, xvals, yvalsbb, COLOR=255, LINESTYLE=2;, THICK=3*THIKadjGV
IF do_ps THEN BEGIN
   dyRow = -0.333             ; y offset increment of these panels' legends
   dxCol = 0.0                ; x offset increment of these panels' legends
   baseY = 0.85+(dyRow*field) ; y-location of legend text following line segment samples
   lineDY = 0.003             ; offset between legend text and its line segment sample
   GR_dy = -0.017   ; offset between GR and matching DPR legend lines (N/A for BB line)
ENDIF ELSE BEGIN
   dyRow = 0.0
   dxCol = 0.333 
   baseY = 0.8+(dyRow*field)
   lineDY = 0.005
   GR_dy = -0.025
ENDELSE
plots, LgdLineX, [baseY+lineDY,baseY+lineDY], COLOR=255, /NORMAL, LINESTYLE=2
xyouts, LgdTxtX, baseY, 'Mean BB Hgt', COLOR=255, CHARSIZE=0.5*CHARadj, /NORMAL

; - - - - - - - - - - - - - - - - - - - - - - - -

; Compute a mean rainrate difference at each BB proximity layer and plot PDFs

mnprarrbb = fltarr(3,4)  ; each BB-relative level, for raintype all, stratiform, convective
mngvarrbb = fltarr(3,4)  ; each BB-relative level, for raintype all, stratiform, convective
levhasdatabb = intarr(4) & levhasdatabb[*] = 0
levsdatabb = 0
bblevstr = ['Unknown', ' Below', 'Within', ' Above']
xoff = [0.0, -0.5 ]  ; for positioning legend in PDFs
yoff = [0.0, -0.5 ]

;print_table_headers, src1, src2, field, /BB, PS_UNIT=tempunit
print_table_headers, src1, src2, xxx, /BB, PS_UNIT=tempunit

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
  ; set up to do below-BB layer only
   bblevBeg = 1
   bblevEnd = 1
   pmultifac = 2
   pmultirows = 2
ENDIF ELSE BEGIN
   bblevBeg = 0
   bblevEnd = 0
   pmultifac = 1
   pmultirows = 2
ENDELSE

for bblev2get = bblevBeg, bblevEnd do begin
   havematch = 0
   IF do_ps THEN !P.Multi=[6-field*2-1,2,3,0,0] ELSE !P.Multi=[6-field*2-1,3,2,0,1]
   IF ( num_in_BB_cat[bblev2get] GT 0 ) THEN BEGIN
      flag = ''
      if (bblev2get eq 2) then flag = ' @ BB'
      diffstruc = the_struc
      calc_geo_pr_gv_meandiffs_wght_idx, yvar, xvar, rnType, dist, distcat, $
                                         bbProx, bblev2get, cutoff, rangecut, $
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
         CASE xxx OF
         'RR' : BEGIN
               ; define a set of "nlogcats" log-spaced interval boundaries
               ; - yields nlogcats+1 rainrate categories
                nlogcats = 16
                logbins = 10^(findgen(nlogcats)/5.-1)
               ; figure out index of interval where each point falls:
               ; -- ranges from -1 (below lowest bound) to nlogcats-1 (above highest bound)
                bin4pr = VALUE_LOCATE( logbins, rr_pr2 )
                bin4gr = VALUE_LOCATE( logbins, rr_gv2 )  ; ditto for GR rainrate
               ; compute histogram of log range category, ignoring the lowest (below 0.1 mm/h)
                prhist = histogram( bin4pr, min=0, max=nlogcats-1,locations = prhiststart )
                nxhist = histogram( bin4gr, min=0, max=nlogcats-1,locations = prhiststart )
               ; will label every other interval start value on plot, no room for all
                labelbins=['0.10','0.25','0.63','1.58','3.98','10.0','25.1','63','158']
                plot, [0,MAX(prhiststart)],[0,FIX((MAX(prhist)>MAX(nxhist))*1.1)], $
                      /NODATA, COLOR=255, CHARSIZE=1*CHARadj, $
                      XTITLE=bblevstr[bblev2get]+' BB Rain Rate, mm/h', $
                      YTITLE='Number of PR Footprints', $
                      YRANGE=[ 0, FIX((MAX(prhist)>MAX(nxhist))*1.1) + 1 ], $
                      BACKGROUND=0, xtickname=labelbins , $
                      xtickinterval=2,xminor=2
                END
          'Z' : BEGIN
                prhist = histogram(rr_pr2, min=dbzcut, max=maxz4hist, binsize = bs, $
                                   locations = prhiststart)
                nxhist = histogram(rr_gv2, min=dbzcut, max=maxz4hist, binsize = bs)
                plot, [15,MAX(prhiststart)],[0,FIX((MAX(prhist)>MAX(nxhist))*1.1)], $
                      /NODATA, COLOR=255, CHARSIZE=1*CHARadj, $
                      XTITLE=bblevstr[bblev2get]+' BB Reflectivity, dBZ', $
                      YTITLE='Number of DPR Footprints', $
                      YRANGE=[ 0, FIX((MAX(prhist)>MAX(nxhist))*1.1) + 1 ], $
                      BACKGROUND=0
                END
         'D0' : BEGIN
                prhist = histogram(rr_pr2, min=0.0, max=5.0, binsize = 0.2, $
                                   locations = prhiststart)
                nxhist = histogram(rr_gv2, min=0.0, max=5.0, binsize = 0.2)
                plot, [0.0,5.0], [0,FIX((MAX(prhist)>MAX(nxhist))*1.1)], $
                      /NODATA, COLOR=255, CHARSIZE=1*CHARadj, XSTYLE=1, $
                      XTITLE=bblevstr[bblev2get]+' BB Mean Drop Diameter, mm', $
                      YTITLE='Number of DPR Footprints', $
                      YRANGE=[ 0, FIX((MAX(prhist)>MAX(nxhist))*1.1) + 1 ], $
                      XMINOR=5, BACKGROUND=0
                xvals = [0.0,5.0]   ; x-endpoints of BB line, D0 scale
                END
         'NW' : BEGIN
                prhist = histogram(rr_pr2, min=0.0, max=5.0, binsize = 0.2, $
                                   locations = prhiststart)
                nxhist = histogram(rr_gv2, min=0.0, max=5.0, binsize = 0.2)
                plot, [0.0,5.0], [0,FIX((MAX(prhist)>MAX(nxhist))*1.1)], $
                      /NODATA, COLOR=255, CHARSIZE=1*CHARadj, $
                      XTITLE=bblevstr[bblev2get]+' BB Mean Log10(Nw)', $
                      YTITLE='Number of DPR Footprints', $
                      YRANGE=[ 0, FIX((MAX(prhist)>MAX(nxhist))*1.1) + 1 ], $
                      XMINOR=5, BACKGROUND=0
                xvals = [0.0,5.0]   ; x-endpoints of BB line, Nw scale
                END
         ENDCASE
         IF ( ~ hideTotals ) THEN BEGIN
            oplot, prhiststart, prhist, COLOR=PR_COLR
            oplot, prhiststart, nxhist, COLOR=GV_COLR
            IF do_ps THEN baseY = 0.95+(dyRow*field) ELSE baseY = 0.95+(dyRow*field)
            xyouts, LgdTxtX, baseY, pr_or_dpr+' (all)', COLOR=PR_COLR, /NORMAL, $
                    CHARSIZE=0.5*CHARadj
            xyouts, LgdTxtX, baseY+GR_dy, siteID+' (all)', COLOR=GV_COLR, /NORMAL, $
                    CHARSIZE=0.5*CHARadj
            IF nlevs2plot NE 1 THEN BEGIN
               ; plot sample line segments in legend
               plots, LgdLineX, [baseY+lineDY,baseY+lineDY], COLOR=PR_COLR, /NORMAL
               plots, LgdLineX, [baseY+lineDY,baseY+lineDY]+GR_dy, COLOR=GV_COLR, /NORMAL
            ENDIF ELSE BEGIN
               ; plot sample symbols in legend
               plots, LgdLineX[1], baseY+lineDY, COLOR=PR_COLR, /NORMAL, $
                      psym=1, symsize=1
               plots, LgdLineX[1], baseY+lineDY+GR_dy, COLOR=GV_COLR, /NORMAL, $
                      psym=1, symsize=1
            ENDELSE
         ENDIF

         headline = pr_or_dpr+'-'+siteID+' Biases:'
         IF do_ps THEN baseY = 0.95+(dyRow*field) ELSE baseY = 0.425
         xyouts, ScrTxtX,baseY, headline, $
                 COLOR=255, /NORMAL, CHARSIZE=0.5*CHARadj

         mndifline = 'Any/All: ' + mndifstr
         mndiflinec = 'Convective: ' + mndifstrc
         mndiflines = 'Stratiform: ' + mndifstrs
         mndifhline = 'By Area Mean: ' + mndifhstr
         xyouts, ScrTxtX,baseY+GR_dy, mndifline, $
                 COLOR=255, /NORMAL, CHARSIZE=0.5*CHARadj
         xyouts, ScrTxtX,baseY+GR_dy*2, mndiflinec, $
                 COLOR=255, /NORMAL, CHARSIZE=0.5*CHARadj
         xyouts, ScrTxtX,baseY+GR_dy*3, mndiflines, $
                 COLOR=255, /NORMAL, CHARSIZE=0.5*CHARadj

        ; OVERLAY CONVECTIVE RAINTYPE PDFS, IF ANY POINTS
         idxconvhist= WHERE( type2 EQ RainType_convective, nconv )
         IF ( nconv GT 0 ) THEN BEGIN
           CASE xxx OF
           'RR' : BEGIN
                  bin4pr = VALUE_LOCATE( logbins, rr_pr2[idxconvhist] )
                  bin4gr = VALUE_LOCATE( logbins, rr_gv2[idxconvhist] )
                  prhist = histogram( bin4pr, min=0, max=18,locations = prhiststart )
                  nxhist = histogram( bin4gr, min=0, max=18,locations = prhiststart )
                  END
            'Z' : BEGIN
                  prhist = histogram(rr_pr2[idxconvhist], min=dbzcut, max=maxz4hist, $
                                     binsize = bs, locations = prhiststart)
                  nxhist = histogram(rr_gv2[idxconvhist], min=dbzcut, max=maxz4hist, $
                                     binsize = bs)
                  END
           'D0' : BEGIN
                  prhist = histogram(rr_pr2[idxconvhist], min=0.0, max=5.0, $
                                     binsize = 0.2, locations = prhiststart)
                  nxhist = histogram(rr_gv2[idxconvhist], min=0.0, max=5.0, $
                                     binsize = 0.2)
                  END
           'NW' : BEGIN
                  prhist = histogram(rr_pr2[idxconvhist], min=0.0, max=5.0, $
                                     binsize = 0.2, locations = prhiststart)
                  nxhist = histogram(rr_gv2[idxconvhist], min=0.0, max=5.0, $
                                     binsize = 0.2)
                  END
           ENDCASE
           oplot, prhiststart, prhist, COLOR=PR_COLR, LINESTYLE=CO_LINE, $
                  thick=3*THIKadjPR
           oplot, prhiststart, nxhist, COLOR=GV_COLR, LINESTYLE=CO_LINE, $
                  thick=3*THIKadjGV
           IF do_ps THEN baseY = 0.884+(dyRow*field) ELSE baseY = 0.85+(dyRow*field)
           xyouts, LgdTxtX, baseY, pr_or_dpr+' (Conv)', COLOR=PR_COLR, /NORMAL, $
                   CHARSIZE=0.5*CHARadj
           xyouts, LgdTxtX, baseY+GR_dy, siteID+' (Conv)', COLOR=GV_COLR, /NORMAL, $
                   CHARSIZE=0.5*CHARadj
           IF counthavezc NE 1 THEN BEGIN
              plots, LgdLineX, [baseY+lineDY,baseY+lineDY], COLOR=PR_COLR, $
                     /NORMAL, LINESTYLE=CO_LINE, thick=3*THIKadjPR
              plots, LgdLineX, [baseY+lineDY,baseY+lineDY]+GR_dy, COLOR=GV_COLR, $
                     /NORMAL, LINESTYLE=CO_LINE, thick=3*THIKadjGV
           ENDIF ELSE BEGIN
              plots, LgdLineX[1], baseY+lineDY, COLOR=PR_COLR, /NORMAL, $
                     psym=4, symsize=1
              plots, LgdLineX[1], baseY+lineDY+GR_dy, COLOR=GV_COLR, /NORMAL, $
                     psym=4, symsize=1
           ENDELSE
         ENDIF

        ; OVERLAY STRATIFORM RAINTYPE PDFS, IF ANY POINTS
         idxstrathist= WHERE( type2 EQ RainType_stratiform, nstrat )
         IF ( nstrat GT 0 ) THEN BEGIN
           CASE xxx OF
           'RR' : BEGIN
                  bin4pr = VALUE_LOCATE( logbins, rr_pr2[idxstrathist] )
                  bin4gr = VALUE_LOCATE( logbins, rr_gv2[idxstrathist] )
                  prhist = histogram( bin4pr, min=0, max=18,locations = prhiststart )
                  nxhist = histogram( bin4gr, min=0, max=18,locations = prhiststart )
                  END
            'Z' : BEGIN
                  prhist = histogram(rr_pr2[idxstrathist], min=dbzcut, max=maxz4hist, $
                                     binsize = bs, locations = prhiststart)
                  nxhist = histogram(rr_gv2[idxstrathist], min=dbzcut, max=maxz4hist, $
                                     binsize = bs)
                  END
           'D0' : BEGIN
                  prhist = histogram(rr_pr2[idxstrathist], min=0.0, max=5.0, $
                                     binsize = 0.2, locations = prhiststart)
                  nxhist = histogram(rr_gv2[idxstrathist], min=0.0, max=5.0, $
                                     binsize = 0.2)
                  END
           'NW' : BEGIN
                  prhist = histogram(rr_pr2[idxstrathist], min=0.0, max=5.0, $
                                     binsize = 0.2, locations = prhiststart)
                  nxhist = histogram(rr_gv2[idxstrathist], min=0.0, max=5.0, $
                                     binsize = 0.2)
                  END
           ENDCASE
           oplot, prhiststart, prhist, COLOR=PR_COLR, LINESTYLE=ST_LINE, $
                  thick=3*THIKadjPR
           oplot, prhiststart, nxhist, COLOR=GV_COLR, LINESTYLE=ST_LINE, $
                  thick=3*THIKadjGV
           IF do_ps THEN baseY = 0.917+(dyRow*field) ELSE baseY = 0.9+(dyRow*field)
           xyouts, LgdTxtX, baseY, pr_or_dpr+' (Strat)', COLOR=PR_COLR, /NORMAL, $
                   CHARSIZE=0.5*CHARadj
           xyouts, LgdTxtX, baseY+GR_dy, siteID+' (Strat)', COLOR=GV_COLR, /NORMAL, $
                   CHARSIZE=0.5*CHARadj
           IF counthavezs NE 1 THEN BEGIN
              plots, LgdLineX, [baseY+lineDY,baseY+lineDY], COLOR=PR_COLR, $
                     /NORMAL, LINESTYLE=ST_LINE, thick=3*THIKadjPR
              plots, LgdLineX, [baseY+lineDY,baseY+lineDY]+GR_dy, COLOR=GV_COLR, $
                     /NORMAL, LINESTYLE=ST_LINE, thick=3*THIKadjGV
           ENDIF ELSE BEGIN
              plots, LgdLineX[1], baseY+lineDY, COLOR=PR_COLR, /NORMAL, $
                     psym=6, symsize=1
              plots, LgdLineX[1], baseY+lineDY+GR_dy, COLOR=GV_COLR, /NORMAL, $
                     psym=6, symsize=1
           ENDELSE
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

; ##############################################################################

IF ( s2ku AND xxx EQ 'Z' ) THEN xyouts, LgdLineX[0], 0.775, '('+siteID+' Ku-adjusted)', COLOR=GV_COLR, $
                 /NORMAL, CHARSIZE=0.5*CHARadj

; Write a data identification line at the bottom of the page below the PDF
; plots for Postscript output.  This line also goes at the top of the scatter
; plots, hence the name.

;CASE xxx OF
;   'RR' : IF (have_gvrr) THEN gr_rr_zr = ' DP RR' ELSE gr_rr_zr = ' Z-R RR'
;    'Z' : gr_rr_zr = ' Zc'
;ENDCASE
IF ( s2ku ) THEN kutxt=' Ku-adjusted ' else kutxt=''
IF ( pctAbvThresh GT 0.0 ) THEN BEGIN
   IF ( pctAbvThresh EQ 100.0 ) THEN gt_ge = "     " ELSE gt_ge = "    >="
   SCATITLE = site+kutxt+gr_rr_zr+' vs. '+pr_or_dpr+' '+instrument+'/'+swath+"/" $
              +version+gt_ge+pctString+"% bins above threshold"
   SCATITLE2 = 'Dm vs. log10(Nw) for '+pr_or_dpr+' '+instrument+'/'+swath+"/" $
              +version+' and '+site+gt_ge+pctString+"% bins above threshold"
ENDIF ELSE BEGIN
   SCATITLE = site+kutxt+gr_rr_zr+' vs. '+pr_or_dpr+' '+instrument+'/'+swath+"/"+version $
              +" -- All non-missing pairs"
   SCATITLE2 = 'Dm vs. log10(Nw) for '+pr_or_dpr+' '+instrument+'/'+swath+"/" $
              +version+' and '+site+" -- All non-missing pairs"
ENDELSE

TITLE2 = "Orbit:  "+orbit+"  --  GR Start Time:  "+data_struct.mysweeps[0].atimeSweepStart

IF ( do_ps EQ 1 and field EQ 2 ) THEN BEGIN
   xyouts, 0.5, -0.04, SCATITLE, alignment=0.5, color=255, /normal, $
           charsize=1., Charthick=1.5
   xyouts, 0.5, -0.07, TITLE2, alignment=0.5, color=255, /normal, $
           charsize=1., Charthick=1.5
ENDIF

IF xxx EQ 'RR' THEN BEGIN
   xlblstr=STRJOIN([STRING(logbins[0:nlogcats-2],FORMAT='(F0.2)'), $
                    '>'+STRING(logbins[nlogcats-1],FORMAT='(F5.1)')], ', ', /single)
   print, '' & print, 'Histogram bin lower bounds (mm/h):'
   print, xlblstr & print, ''
   IF ( do_ps EQ 1 ) THEN BEGIN
      ; write the array of histogram intervals at the bottom of the PDF plot page
      xyouts, 0.05, -0.15, '!11'+'Histogram bin lower bounds (mm/h):'+'!X', $
              /NORMAL, COLOR=255, CHARSIZE=0.667, Charthick=1.5
      xyouts, 0.05, -0.17, '!11'+xlblstr+'!X', /NORMAL, COLOR=255, CHARSIZE=0.667
   ENDIF
ENDIF


endfor   ; fields2do


IF ( do_ps EQ 1 ) THEN BEGIN
   erase                 ; start a new page in the PS file for the stat tables
   device,/inches,xoffset=0.25,yoffset=0.5, xsize=8.,ysize=10.
;   device, /landscape   ; change page setup
   FREE_LUN, tempunit    ; close the temp file for writing
   OPENR, tempunit2, temptext, /GET_LUN  ; open the temp file for reading
   statstr = ''
   fmt='(a0)'
   xtext = 0.05 & ytext = 0.95
   pagebreak = 1  ; set up to start new page at first D0 / Dm stats table
  ; write the stats tables out to the Postscript file
   while (eof(tempunit2) ne 1) DO BEGIN
     readf, tempunit2, statstr, format=fmt
     IF STRPOS(statstr, 'Dm') NE -1 AND pagebreak THEN BEGIN
        erase
        ytext = 0.95
        pagebreak = 0
     ENDIF
     xyouts, xtext, ytext, '!11'+statstr+'!X', /NORMAL, COLOR=255, CHARSIZE=0.667
     ytext = ytext - 0.02
   endwhile
   FREE_LUN, tempunit2             ; close the temp file
ENDIF
; - - - - - - - - - - - - - - - - - - - - - - - -

; Build the Scatter Plots
scatwinsize = 375

IF pr_or_dpr EQ 'PR' THEN sat_instr = pr_or_dpr $
ELSE sat_instr = pr_or_dpr+'/'+instrument+'/'+swath
IF bbparms.meanBB EQ -99.99 THEN skipBB=1 ELSE skipBB=0
IF xxx EQ 'RR' THEN BEGIN
   min_xy=0.5
   max_xy=150.0
   units='mm/h'
ENDIF

IF ( do_ps EQ 1 ) THEN BEGIN
   erase
   device,/inches,xoffset=0.25,yoffset=0.55,xsize=8.,ysize=10.,/portrait
   samphgt = (top+botm)/2.0
   plot_dsd_scatter_by_raintype_ps, PSFILEpdf, SCATITLE, siteID, zcor, gvz, $
                            dpr_dm, Dzero, dpr_nw, gr_dp_nw, rnType, bbProx, $
                            num4hist3, idx4hist3, S2KU=s2ku, HEIGHTS=samphgt, $
                            MIN_XY=min_xy, MAX_XY=max_xy, SAT_INSTR=sat_instr, $
                            GR_DM_D0=GR_DM_D0
   erase
   plot_scatter_d0_vs_nw_by_raintype_ps, PSFILEpdf, SCATITLE2, siteID, dpr_dm, $
                            Dzero, dpr_nw, gr_dp_nw, rnType, bbProx, $
                            num4hist3, idx4hist3, SAT_INSTR=sat_instr, $
                            HEIGHTS=samphgt, GR_DM_D0=GR_DM_D0
ENDIF ELSE BEGIN
   plot_dsd_scatter_by_raintype, SCATITLE, siteID, zcor, gvz, dpr_dm, Dzero, $
                            dpr_nw, gr_dp_nw, rnType, bbProx, $
                            num4hist3, idx4hist3, scatwinsize, S2KU=s2ku, $
                            MIN_XY=min_xy, MAX_XY=max_xy, SAT_INSTR=sat_instr, $
                            GR_DM_D0=GR_DM_D0
   plot_scatter_d0_vs_nw_by_raintype, SCATITLE2, siteID, dpr_dm, Dzero, $
                            dpr_nw, gr_dp_nw, rnType, bbProx, $
                            num4hist3, idx4hist3, scatwinsize, $
                            SAT_INSTR=sat_instr, GR_DM_D0=GR_DM_D0
ENDELSE

; - - - - - - - - - - - - - - - - - - - - - - - -

; if IDX_USED is defined, then grab the indices of the samples included in the
; analysis (Below-BB samples meeting all the clipping/filtering criteria)
IF N_ELEMENTS(idx_used) NE 0 THEN BEGIN
   if ( num4hist3[0] GT 0 ) THEN BEGIN
      idx_used = idxgoodenuff[ idx4hist3[ 0, 0:num4hist3[0]-1 ] ]
   endif else idx_used = -1
ENDIF

; - - - - - - - - - - - - - - - - - - - - - - - -


SET_PLOT, orig_device

; - - - - - - - - - - - - - - - - - - - - - - - -

; Build the PPI animation loop, if indicated.

IF ( do_ps EQ 0 AND show_ppis EQ 0 ) THEN BEGIN
   nframes=0
   goto, nextFile   ; skip PPI setup/plotting
ENDIF

; Check that we have as many sweeps as (startelev+elevs2show); if not, adjust
; elevs2show

IF (startelev LE nswp ) THEN BEGIN
   IF (elevs2show+startelev) LE nswp THEN BEGIN
        nframes = elevs2show
   ENDIF ELSE BEGIN
        nframes = nswp - (startelev + 1)
        print, "Number of sweeps present = ", nswp
        print, "First, Last sweep requested = ", startelev+1, ',', startelev+elevs2show
        print, "Number of sweeps to show (adjusted): ", nframes
   ENDELSE
ENDIF ELSE BEGIN
     elevs2show = 1
     nframes = 1
     startelev = nswp - 1
     print, "Number of sweeps present = ", nswp
     print, "First, Last sweep requested = ", startelev+1, ',', startelev+elevs2show
     print, "Showing only sweep number: ", startelev+1
ENDELSE

IF ( elevs2show EQ 0 ) THEN GOTO, nextFile
do_pixmap=0
IF ( elevs2show GT 1 ) THEN BEGIN
   do_pixmap=1
   retain = 0
   PRINT, ''
   PRINT, "Please wait while PPI animations are being constructed..."
   PRINT, ''
ENDIF ELSE retain = 2

!P.MULTI=[0,1,1]
IF ( N_ELEMENTS(windowsize) NE 1 ) THEN windowsize = 375
xsize = windowsize[0]
ysize = xsize
windownum = 2
title = TITLE2

ppi_comn = { winSize : windowsize, $
             winNum : windownum, $
             winTitle : title, $
             nframes : nframes, $
             startelev : startelev, $
             looprate : looprate, $
             mysweeps : data_struct.mysweeps, $
             PPIorient : PPIorient, $
             PPIbyThresh : PPIbyThresh, $
             pctString : pctString, $
             site_Lat : site_lat, $
             site_Lon : site_lon, $
             site_ID : siteID, $
             xCorner : xCorner, $
             yCorner : yCorner, $
             pr_index : pr_index, $
             num_footprints : nfp, $
             rangeThreshold : data_struct.mygeometa.rangeThreshold, $
             rntype4ppi : rntype4ppi }

IF (have_gvrr) THEN gr_rr_zr = ' DP' ELSE gr_rr_zr = ' Z-R'
IF pctAbvThresh GT 0.0 AND PPIbythresh THEN sayPct = 1 ELSE sayPct = 0

IF Z_PPIs THEN BEGIN
   ; show only DPR and GR reflectivity PPIs
   IF (clipem) THEN BEGIN
     ; show both clipped and unclipped DPR and GR reflectivity PPIs
      fieldData = ptrarr(2,2, /allocate_heap)
      fieldIDs = [['CZ','CZ'],['CZ','CZ']]
      sources = [['PR',siteID],['PR',siteID]]
      thresholded = [[0,0],[sayPct,sayPct]]
      *fieldData[0] = zcor_in
      *fieldData[1] = gvz_in
      *fieldData[2] = zcor_in2
      *fieldData[3] = gvz_in2
   ENDIF ELSE BEGIN
     ; show only unclipped DPR and GR reflectivity PPIs
      fieldData = ptrarr(2, /allocate_heap)
      fieldIDs = ['CZ','CZ']
      sources = ['PR',siteID]
      thresholded = [0,0]
      *fieldData[0] = zcor_in
      *fieldData[1] = gvz_in
   ENDELSE
ENDIF ELSE BEGIN
   IF (haveKdp and haveZdr and haveHID) THEN BEGIN
      fieldData = ptrarr(3,3, /allocate_heap)
      fieldIDs = [ ['CZ','CZ','DR'], $
                   ['FH','Dm','NW'], $
                   ['KD',GR_DM_D0_PPI,'NW'] ]  ;'RH'] ]
      sources = [ [pr_or_dpr+'/'+instrument, siteID, siteID], $
                  [siteID, pr_or_dpr+'/'+instrument, pr_or_dpr+'/'+instrument], $
                  [siteID,siteID,siteID] ]
      thresholded = [ [sayPct,sayPct,0], $
                      [0,0,0], $
                      [0,0,0] ]
      *fieldData[0] = zcor_in2
      *fieldData[1] = gvz_in2
      *fieldData[2] = Zdr
      *fieldData[3] = HIDcat
      *fieldData[4] = dpr_dm_in
      *fieldData[5] = dpr_nw_in
      *fieldData[6] = Kdp
      *fieldData[7] = Dzero_in
      *fieldData[8] = GR_DP_NW_in  ;RHOhv
   ENDIF ELSE BEGIN
      fieldData = ptrarr(2,2, /allocate_heap)
      fieldIDs = [['CZ','CZ'],['RR',data_struct.rr_field_used]]
      sources = [['PR',siteID],['PR',siteID+gr_rr_zr]]
      thresholded = [[sayPct,sayPct],[sayPct,sayPct]]
      *fieldData[0] = zcor_in2
      *fieldData[1] = gvz_in2
      *fieldData[2] = rain3_in2
      *fieldData[3] = gvrr_in2
   ENDELSE
ENDELSE

plot_geo_match_ppi_anim_ps, fieldIDs, sources, fieldData, thresholded, $
                            ppi_comn, SHOW_PPIS=show_ppis, DO_PS=do_ps, $
                            STEP_MANUAL=step_manual

FOR nfieldptr = 0, N_ELEMENTS(fieldData)-1 DO ptr_free, fieldData[nfieldptr]

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
IF (do_ps AND batch) THEN GOTO, noPPIwindow    ; skip prompt, and no PPI window 2

IF (nframes LT 2 AND show_ppis) OR hidePPIs THEN BEGIN
   print, ''
   PRINT, STRING(7B)   ; ring the bell
   IF data_struct.is_subset THEN $
      READ, something, PROMPT='Hit Return to continue with subset processing, or Q to Quit: ' $
   ELSE READ, something, PROMPT='Hit Return to continue to next case, Q to Quit: '
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

noPPIwindow:

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
      print, "Please do not close Z/D0/Nw scatter plots window manually!  Continue..."
   ENDELSE
   catch, wdel_err
   IF wdel_err EQ 0 THEN BEGIN
      if ( do_ps EQ 0 ) THEN WDELETE, 4
   ENDIF ELSE BEGIN
      print, ""
      print, !error_state.MSG
      catch, /CANCEL
      print, "Please do not close D0 vs. Nw scatter plot window manually!  Continue..."
   ENDELSE
endif

status = 0
IF something EQ 'Q' OR something EQ 'q' THEN status = 2

errorExit:

return, status
end
