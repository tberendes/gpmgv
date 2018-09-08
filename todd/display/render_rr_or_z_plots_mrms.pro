;===============================================================================
;+
; Copyright © 2015, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; render_rr_or_z_plots_mrms.pro       - Morris/SAIC/GPM_GV     April 2015
;
; DESCRIPTION
; -----------
; Performs a statistical analysis of geometry-matched (D)PR and GR reflectivity
; or rain rate from data extracted by the caller from a geo-match netCDF file,
; optionally subset by storm outline or a fixed area, and bundled in a structure
; passed to this routine.  If analyzing rain rate, then the rain rate for the GR
; is taken from the geo-match data if this field is flagged as available,
; otherwise it is derived from the volume-averaged GR reflectivity using a Z-R 
; relationship.  (D)PR rainrate is the volume-averaged rain rate stored in the
; netCDF file and previously derived from the 3-D rainrate in the 2A product.
;
; Depending on XXX, computes either mean PR-GR rainrate or Z differences for
; each of the 3 bright band proximity levels for points within 100 km (by
; default) of the ground radar and reports the results in a table to stdout.
; If specified, max_range overrides the 100 km default range.  Also produces
; graphs of the Probability Density Function of PR and GR rainrate or Z at each
; of these 3 levels if data exists at that level, and vertical profiles of
; mean PR and GR rainrate or Z, for each of 3 rain type categories: Any,
; Stratiform, and Convective. Optionally produces a single frame or an
; animation loop of GR and equivalent PR PPI images for N=elevs2show frames
; unless hidePPIs is set. Unless hide_rntype is set to 1 (On), then PR and GR
; footprints in the PPIs will be encoded by rain type by pattern: solid=Other,
; vertical=Convective, horizontal=Stratiform.
;
; If PS_DIR is specified then the output is to a Postscript file under ps_dir,
; otherwise all output is to the screen.  When outputting to Postscript, the
; PPI animation is still to the screen (unless hidePPIs is set) but the PDF and
; scatter plots go to Postscript, as well as a copy of the last frame of the PPI
; images in the animation loop. The name of the Postscript file uses the station
; ID, datestamp, and orbit number taken from the geo_match netCDF data file.
; If b_w is set, then Postscript output will be black and white, otherwise it's
; in color.  If BATCH is also set with PS_DIR then the output file will be
; created without any graphics or user prompts and the program will proceed to
; the next case, as specified by the input parameters.
;
; If s2ku binary parameter is set, then the Liao/Meneghini S-to-Ku band
; reflectivity adjustment will be made to the GR reflectivity used to compute
; reflectivity statistics and/or any GR rainrate derived via a Z-R relationship.
; In all cases, if zr_force is set then a Z-R rainrate estimate will be computed
; and used for the GR, regardless of the availability of a gr_rr field.
;
; This function is a child routine to the geo_match_3d_rr_or_z_comparisons
; procedure.
;
; INTERNAL MODULES
; ----------------
; 1) render_rr_or_z_plots_mrms - Main procedure called by user.  Compute statistics,
;                           create vertical profiles, histogram, scatter plots, 
;                           and tablulations of (D)PR-GR rainrate or reflectivity
;                           differences, and display (D)PR and GR reflectivity
;                           and rainrate and GR dual-pol field PPI plots in an
;                           animation sequence.
;
; NON-SYSTEM ROUTINES CALLED
; --------------------------
; 1) z_r_rainrate()
; 2) calc_geo_pr_gv_meandiffs_wght_idx
; 3) plot_scatter_by_bb_prox_ps
; 4) plot_scatter_by_bb_prox
; 5) plot_geo_match_ppi_anim_ps
; 6) plot_geo_match_ppi_rr_mrms_ps (TAB 10/3/17)
;
; HISTORY
; -------
; 04/09/15  Morris/GPM GV/SAIC
; - Created by extracting a large block of existing code from the procedure
;   in geo_match_3d_rr_or_z_comparisons.pro that did the statistics and
;   created the graphical and optional Postscript/PDF output.
; 04/17/15  Morris/GPM GV/SAIC
; - Moved print_table_headers procedure into the top of this file so that
;   render_rr_or_z_plots() is callable as a stand-alone function from outside
;   of geo_match_3d_rr_or_z_comparisons.
; - Moved pertinent prologue content here from geo_match_3d_rr_or_z_comparisons.
; - Define and set value of s2ku at beginning of function to eliminate undefined
;   variable error when parameter is unspecified.
; - Make PPI copies of gvz, zraw, zcor, rain3, and gvrr here instead of passing
;   them in through the structure.  All blanking and thresholding by percent for
;   plotting and statistics happens within this function.
; 04/28/15  Morris/GPM GV/SAIC
; - Use new rr_field_used structure element to more properly indicate source of
;   GR rain rate being evaluated.
; 05/05/15  Morris/GPM GV/SAIC
; - Pulled print_table_headers out as a separate source code file.  Merged the
;   capabilities as defined in geo_match_3d_dsd_comparisons.pro with those in
;   geo_match_3d_rr_or_z_comparisons.pro from when print_table_headers was
;   contained in each of them.
; 05/06/15  Morris/GPM GV/SAIC
; - Added hidePPIs parameter to suppress PPI plotting to screen.
; 05/08/15  Morris/GPM GV/SAIC
; - Filled in logic to fully implement BATCH option with Postscript output.
; 05/12/15  Morris/GPM GV/SAIC
; - Made status value changes to support multiple storm selection by caller
;   and to not force exit by caller when no valid data exist to process for
;   the current case.
; 06/24/15  Morris/GPM GV/SAIC
; - Added support for plotting and analyzing Combined DPRGMI matchup data.
; - Removed ncfilepr positional parameter from call sequence, its filename
;   metadata is now passed in the data structure.
; 07/16/15  Morris/GPM GV/SAIC
; - Added DECLUTTER parameter to support filtering of clutter-affected samples. 
; 10/13/15  Morris/GPM GV/SAIC
; - Minor tweak for labeling of Z-R rainrate type on PPI plot.
; 12/9/2015 Morris, GPM GV, SAIC
; - Added MAX_BLOCKAGE optional parameter to limit samples included in the
;   statistics by maximum allowed GR beam blockage. Only applies to matchup file
;   version 1.21 or later with computed beam blockage.
; - Added Z_BLOCKAGE_THRESH optional parameter to limit samples included in the
;   comparisons by beam blockage, as implied by a Z dropoff between the second
;   and first sweeps that exceeds the value of this parameter. Is only used if
;   MAX_BLOCKAGE is unspecified, or where no blockage information is contained
;   in the matchup file.
; 05/31/16 Morris, GPM GV, SAIC
; - Added a user prompt in the Postscript/non-batch mode to ask whether to save
;   or delete the Postscript/PDF file for the case after viewing the PPIs.
; - Added FILTER_BLOCKED_BY parameter to select method used to reject blockage
;   region data when actual beam blockage data are included in the dataset: by
;   individual samples exceeding blockage thresholds ("S"), or for the entire
;   column above a blocked sample ("C").  Default="S".
; 12/07/16 by Bob Morris, GPM GV (SAIC)
; - Modified user messages in no-data cases, and prompt text in READ statement
;   for subset case.
; 01/24/17 by Bob Morris, GPM GV (SAIC)
; - Commented out diagnostic messages in computing blockage by Z_BLOCKAGE_THRESH
;   and disabled setting of blocked Z values for PPI plots to 59.99 dBZ.
; 01/26/17 by Bob Morris, GPM GV (SAIC)
; - Moved some code blocks and added a check of whether the postscript file has
;   been opened to prevent problems when no valid data samples are found.
; 03/24/17 Morris, GPM GV, SAIC
; - Added LAND_OCEAN=land_ocean keyword/value pair to filter analyzed samples by
;   underlying surface type.  No logic added to implement this capability yet.
; - Replaced rain rate PPIs in animation with thresholded/filtered Z PPIs, when
;   analyzing Z.  Added thresholded Z PPIs to Z-only PPI plots when that option
;   is active and thresholding has been done.
; - Added exception for blanking plotted samples based on DPR rain rate when
;   analyzing the MS scan which has no DPR RR field.
;
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;===============================================================================
;

function render_rr_or_z_plots_mrms, xxx, looprate, elevs2show, startelev, $
                               PPIorient, windowsize, pctabvthresh, PPIbyThresh, $
                               gvconvective, gvstratiform, hideTotals, hide_rntype, $
                               hidePPIs, pr_or_dpr, data_struct, PS_DIR=ps_dir, $
                               B_W=b_w, S2KU=s2ku_in, ZR=zr_force, BATCH=batch, $
                               MAX_RANGE=max_range, MAX_BLOCKAGE=max_blockage, $
                               Z_BLOCKAGE_THRESH=z_blockage_thresh, $
                               FILTER_BLOCKED_BY=filter_blocked_by, $
                               STEP_MANUAL=step_manual, DECLUTTER=declutter_in, $
                               LAND_OCEAN=land_ocean


; "include" file for PR data constants
@pr_params.inc

s2ku=KEYWORD_SET(s2ku_in)
declutter=KEYWORD_SET(declutter_in)

pctString = STRTRIM(STRING(FIX(pctabvthresh)),2)

frequency = data_struct.KuKa        ; 'DPR', 'KA', or 'KU', from input GPM 2Axxx file
site = data_struct.mysite.site_id
yymmdd = data_struct.DATESTAMP      ; in YYMMDD format
orbit = data_struct.orbit
version = data_struct.version
; put the "Instrument" ID from the passed structure into its PPS designation
CASE STRUPCASE(frequency) OF
    'KA' : freqName='Ka'
    'KU' : freqName='Ku'
   'DPR' : freqName='DPR'
    ELSE : freqName=''
ENDCASE

CASE pr_or_dpr OF
       'DPR' : instrument='2A'+freqName
    'DPRGMI' : instrument='CMB'
        'PR' : instrument='Ku'
ENDCASE

; pull copies of all the data variables and flags out of the passed structure
have_gvrr = data_struct.haveFlags.have_gvrr
haveHID = data_struct.haveFlags.haveHID
haveD0 = data_struct.haveFlags.haveD0
haveZdr = data_struct.haveFlags.haveZdr
haveKdp = data_struct.haveFlags.haveKdp
haveRHOhv = data_struct.haveFlags.haveRHOhv
havemrms = data_struct.haveFlags.have_mrms
haveswe = data_struct.haveFlags.have_swe

havenearsurfrain = data_struct.haveFlags.have_nearsurfrain
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

blockfilter = 'S'    ; initialize blockage filter to "by Sample"
IF do_GR_blockage NE 0 AND N_ELEMENTS(filter_blocked_by) NE 0 THEN BEGIN
  ; set blockage filter to caller's requested type, if valid
   CASE STRUPCASE(filter_blocked_by) OF
       'S' : blockfilter = 'S'
       'C' : blockfilter = 'C'
      ELSE : BEGIN
               message, "Unknown FILTER_BLOCKED_BY value, defaulting to S(ample).", /INFO
               blockfilter = 'S'
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
gvrr = data_struct.gvrr
gvrr_in = gvrr                 ; for plotting as PPI
HIDcat = data_struct.HIDcat
Dzero = data_struct.Dzero
Zdr = data_struct.Zdr
Kdp = data_struct.Kdp
RHOhv = data_struct.RHOhv
mrmsrr = data_struct.mrmsrr
nearsurfrain = data_struct.nearsurfrain
swedp = data_struct.swedp
swe25 = data_struct.swe25
swe50 = data_struct.swe50
swe75 = data_struct.swe75
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
     temptext = ps_dir + '/dbzdiffstats_temp.txt'
     OPENW, tempunit, temptext, /GET_LUN
    ; figure out whether to plot PPIs and prompt, or just write Postscript and 
    ; wrap up
     IF KEYWORD_SET( batch ) THEN show_ppis=0     ; don't display PPIs/animation
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
siteID = string(data_struct.mysite.site_id)
swath=data_struct.swath

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
             IF countblok GT 0 THEN BEGIN
               ; set the z samples and GR percentgood values to "MISSING" for all
               ; samples that exceed allowed blockage, and set the plottable Z
               ; values to 59.99 dBZ so they stand out
                gvz[idxblok] = -11.
                zcor[idxblok] = -11.
                gvz_in[idxblok] = 59.99
                zcor_in[idxblok] = 59.99
                if have_gvrr AND xxx EQ 'RR' then begin
                   pctgoodrrgv[idxblok] = -11.
                endif else begin
                   pctgoodgv[idxblok] = -11.
                endelse
             ENDIF
             END
         2 : BEGIN
             ; check the difference between the two lowest sweep Z values for
             ; a drop-off in the lowest sweep that indicates beam blockage
             print, ''
             print, "FILTERING BY BLOCKAGE FROM Z DROPOFF >", z_blockage_thresh
             idxblok = WHERE(gvz[idxchk,1]-gvz[idxchk,0] GT z_blockage_thresh, $
                             countblok)
             IF countblok GT 0 THEN BEGIN
              ; compute the sample ranges and azimuths and report on blockages found
              ; (DIAGNOSTIC ONLY, COMMENTING OUT FOR BASELINE)
;                xcenter=MEAN(xCorner, DIM=1)
;                ycenter=MEAN(yCorner, DIM=1)
;                rangectr = SQRT(xcenter*xcenter+ycenter*ycenter)
;                azctr = (atan(ycenter, xcenter)/!DTOR+360.) mod 360.
;                print, "Ranges: ", rangectr[idxchk[idxblok],0]
;                print, "Azimuths: ", azctr[idxchk[idxblok],0]
;                print, "Diffs 2-1: ", gvz[idxchk[idxblok],1]-gvz[idxchk[idxblok],0]
               ; - Set the z columns and GR percentgood values to "MISSING" for all
               ;   columns where lowest sweep shows blockage
               ; - Set the plottable Z values to 59.99 dBZ so they stand out (disabled)
                gvz[idxchk[idxblok],*] = -11.
                zcor[idxchk[idxblok],*] = -11.
;                gvz_in[idxchk[idxblok],*] = 59.99   ; disable in baseline
;                zcor_in[idxchk[idxblok],*] = 59.99  ; disable in baseline
                if have_gvrr AND xxx EQ 'RR' then begin
                   pctgoodrrgv[idxchk[idxblok],*] = -11.
                endif else begin
                   pctgoodgv[idxchk[idxblok],*] = -11.
                endelse
;                print, "Diffs 3-2: ", gvz[idxchk[idxblok],2]-gvz[idxchk[idxblok],1]
;                gvz[idxchk[idxblok],0] = 59.99
             ENDIF
             print, 'Columns excluded based on blockage: ', countblok, ' of ', countchk
             END
         ELSE : message, "Undefined or illegal do_GR_blockage value."
      ENDCASE
   endif
ENDIF ELSE BEGIN
   print, ''
   print, 'No filtering by GR blockage.'
ENDELSE
;-------------------------------------------------

; optional data *clipping* based on percent completeness of the volume averages:
; Decide which PR and GR points to include, based on percent of expected points
; in bin-averaged results that were above dBZ thresholds set when the matchups
; were done.  If unspecified or set to zero, include all points regardless of
; 'completeness' of the volume averages.

clipem=0
IF ( pctAbvThresh GT 0.0 ) THEN BEGIN
    ; clip to the 'good' points, where 'pctAbvThresh' fraction of bins in average
    ; were above threshold
   IF KEYWORD_SET(declutter) THEN BEGIN
     ; also clip to uncluttered samples
      if have_gvrr AND xxx EQ 'RR' then begin
         thresh_msg = "Thresholding by rain rate cutoff and uncluttered Z.  " + gvrr_txt
         idxgoodenuff = WHERE( pctgoodrrgv GE pctAbvThresh $
                          AND  pctgoodrain GE pctAbvThresh $
                          AND  clutterStatus LT 10, countgoodpct )
      endif else begin
         IF xxx EQ 'Z' THEN thresh_msg = "Thresholding by reflectivity cutoffs and uncluttered Z." $
         ELSE thresh_msg = "Thresholding by reflectivity cutoffs and uncluttered Z.  " + gvrr_txt
         idxgoodenuff = WHERE( pctgoodpr GE pctAbvThresh $
                          AND  pctgoodgv GE pctAbvThresh $
                          AND  clutterStatus LT 10, countgoodpct )
      endelse
   ENDIF ELSE BEGIN
      if have_gvrr AND xxx EQ 'RR' then begin
         thresh_msg = "Thresholding by rain rate cutoff.  " + gvrr_txt
         idxgoodenuff = WHERE( pctgoodrrgv GE pctAbvThresh $
                          AND  pctgoodrain GE pctAbvThresh, countgoodpct )
      endif else begin
         IF xxx EQ 'Z' THEN thresh_msg = "Thresholding by reflectivity cutoffs." $
         ELSE thresh_msg = "Thresholding by reflectivity cutoffs.  " + gvrr_txt
         idxgoodenuff = WHERE( pctgoodpr GE pctAbvThresh $
                          AND  pctgoodgv GE pctAbvThresh, countgoodpct )
      endelse
   ENDELSE
   IF ( countgoodpct GT 0 ) THEN BEGIN
      clipem = 1
      idx2plot=idxgoodenuff
   ENDIF ELSE BEGIN
       IF KEYWORD_SET(declutter) THEN $
          print, "No points meeting both ",xxx, $
                 " Percent Above Threshold and uncluttered criteria." $
       ELSE $
          print, "No complete-volume points based on ",xxx," Percent Above Threshold."
       goto, errorExit
   ENDELSE
ENDIF ELSE BEGIN
  ; clip to where reflectivity is for uncluttered samples only, if indicated
   IF KEYWORD_SET(declutter) THEN BEGIN
      idxgoodenuff = WHERE( clutterStatus LT 10, countgoodpct )
      IF ( countgoodpct GT 0 ) THEN BEGIN
         clipem = 1
         idx2plot=idxgoodenuff
      ENDIF ELSE BEGIN
         print, "No complete-volume uncluttered points."
         goto, errorExit
      ENDELSE
   ENDIF ELSE BEGIN
     ; pctAbvThresh is 0 and declutter flag is unset, take/plot ALL non-bogus points
      IF have_gvrr EQ 0 THEN gvrr = z_r_rainrate(gvz) $    ; override empty field
         ELSE gvrr=gvrr   ; using scaled GR rainrate from matchup file
      IF ( PPIbyThresh ) THEN BEGIN
         idx2plot=WHERE( pctgoodpr GE 0.0 AND  pctgoodgv GE 0.0, countactual2d )
      ENDIF
   ENDELSE
ENDELSE

if (clipem) THEN BEGIN
   nclipped = N_ELEMENTS(gvz) - countgoodpct
PRINT, nclipped, " samples filtered by percent above threshold and/or clutter."
   IF have_gvrr EQ 0 THEN gvrr = z_r_rainrate(gvz[idxgoodenuff]) $  ; override empty field
      ELSE gvrr=gvrr[idxgoodenuff]   ; using scaled GR rainrate from matchup file
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
;   pr_index = pr_index[idxgoodenuff] : NO! don't clip - must be full array for PPIs
   IF ( PPIbyThresh ) THEN BEGIN
      idx2plot=idxgoodenuff
   ENDIF
ENDIF


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
IF freqName EQ 'DPR' and swath EQ 'MS' THEN BEGIN
  ; no rain3 data in 2ADPR/MS
   idx2blank2 = WHERE( (gvz_in2 LT 0.0) OR (zcor_in2 LE 0.0) $
                    OR (gvrr_in2 LT 0.0), count2blank2 )
ENDIF ELSE BEGIN 
   idx2blank2 = WHERE( (gvz_in2 LT 0.0) OR (zcor_in2 LE 0.0) $
                    OR (rain3_in2 LT 0.0) OR (gvrr_in2 LT 0.0), count2blank2 )
ENDELSE
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

;minz4hist = 18.  ; not used, replaced with cutoff
maxz4hist = 55.   ; used only for Z
IF N_ELEMENTS(max_range) NE 1 THEN rangecut = 100. ELSE rangecut = max_range

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
;          field = var2
          END
    'Z' : BEGIN
          difftext='-GR Reflectivity difference statistics (dBZ) - GR Site: '
          cutoff = 10.     ; cutoff dBZ value to include in mean diff. calcs.
          bs = 2.0         ; fixed histogram bin size, else bins by 1.0, messy
;          src1 = pr_or_dpr
          src2 = 'GR'
          yvar = zcor
          xvar = gvz
;          field = xxx
          END
ENDCASE

IF pr_or_dpr EQ 'PR' THEN BEGIN
   textout = pr_or_dpr + difftext + siteID + '   Orbit: ' + orbit + $
             '  Version: '+version
ENDIF ELSE BEGIN
   textout = pr_or_dpr + ' ' + Instrument + difftext + siteID
   print, textout & IF (do_ps EQ 1) THEN printf, tempunit, textout
   textout = 'Orbit: '+orbit+'  Version: '+version+'  Swath Type: '+swath
ENDELSE
print, textout & IF (do_ps EQ 1) THEN printf, tempunit, textout

textout = pr_or_dpr + ' time = ' + data_struct.mygeometa.atimeNearestApproach + $
          '   GR start time = ' + data_struct.mysweeps[0].atimeSweepStart
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

mnprarr = fltarr(3,nhgtcats)  ; each level, for raintype all, stratiform, convective
mngvarr = fltarr(3,nhgtcats)  ; each level, for raintype all, stratiform, convective
levhasdata = intarr(nhgtcats) & levhasdata[*] = 0
levsdata = 0
max_hgt_w_data = 0.0

; - - - - - - - - - - - - - - - - - - - - - - - -

;print_table_headers, src1, src2, field, PS_UNIT=tempunit
print_table_headers, src1, src2, xxx, PS_UNIT=tempunit

; - - - - - - - - - - - - - - - - - - - - - - - -

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
      endelse
   ENDIF ELSE BEGIN
      print, "No points at height " + string(heights[lev2get], FORMAT='(f0.3)')
   ENDELSE

endfor         ; lev2get = 0, nhgtcats-1


havePSfile = 0   ; i.e., postscript file not opened yet

if (levsdata eq 0) then begin
   print, "No valid data levels found!"
   nframes = 0
   goto, nextFile
endif

; - - - - - - - - - - - - - - - - - - - - - - - -

; Build the mean RR profile plot panel

orig_device = !D.NAME
CASE xxx OF
   'RR' : IF (have_gvrr) THEN gr_rr_zr = ' DP '+data_struct.rr_field_used $
          ELSE gr_rr_zr = ' Z-R RR'
    'Z' : gr_rr_zr = ' Zc'
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
   PSFILEpdf = ps_dir+'/'+site+'.'+yymmdd+'.'+orbit+"."+version+'.'+pr_or_dpr+'_' $
               +instrument+'_'+swath+'.Pct'+pctString+add2nm+'_'+xxx+'_PDF_SCATR.ps'
   print, "Output sent to ", PSFILEpdf
   set_plot,/copy,'ps'
   device,filename=PSFILEpdf,/color,bits=8,/inches,xoffset=0.25,yoffset=2.55, $
          xsize=8.,ysize=8.
   havePSfile = 1

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
      IF ( pctAbvThresh EQ 100.0 ) THEN gt_ge = ' ' ELSE gt_ge = ' >='
      CASE xxx OF
         'Z' : wintxt = "With" + gt_ge + pctString + $
                        "% of averaged bins above dBZ thresholds"  
        'RR' : wintxt = "With" + gt_ge + pctString + $
                        "% of averaged bins above rainrate threshold"
      ENDCASE
   ENDIF ELSE BEGIN
      wintxt = "With all non-missing "+pr_or_dpr+"/GR matched samples"
   ENDELSE

   Window, xsize=700, ysize=700, TITLE = site+gr_rr_zr+' vs. '+instrument+'.'+ $
           swath+"."+version+"  --  "+wintxt, RETAIN=2
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

idxlev2plot = WHERE( levhasdata EQ 1 )
h2plot = heights[idxlev2plot]

; figure out the y-axis range.  Use the greater of max_hgt_w_data*2.0
; and meanbb*2 as the proposed range.  Cut off at 20 km if result>20.
prop_max_y = max_hgt_w_data*2.0 > (FIX((BBparms.meanbb*2)/1.5) + 1) *1.5

CASE xxx OF
   'Z' : BEGIN
           plot, [15,50], [0,20 < prop_max_y], /NODATA, COLOR=255, $
             XSTYLE=1, YSTYLE=1, YTICKINTERVAL=hgtinterval, YMINOR=1, thick=1, $
             XTITLE='Level Mean Reflectivity, dBZ', YTITLE='Height Level, km', $
             CHARSIZE=1*CHARadj, BACKGROUND=0
           xvals = [15,50]   ; x-endpoints of BB line, dBZ scale
         END
  'RR' : BEGIN
           plot, [0.1,150], [0,20 < prop_max_y], /NODATA, COLOR=255, $
             XSTYLE=1, YSTYLE=1, YTICKINTERVAL=hgtinterval, YMINOR=1, thick=1, $
             XTITLE='Level Mean Rain Rate, mm/h', YTITLE='Height Level, km', $
             CHARSIZE=1*CHARadj, BACKGROUND=0, /xlog
           xvals = [0.1,150]   ; x-endpoints of BB line, RR scale
         END
ENDCASE

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

; plot the mean BB indicator line and its legend info.
yvalsbb = [BBparms.meanbb, BBparms.meanbb]
plots, xvals, yvalsbb, COLOR=255, LINESTYLE=2;, THICK=3*THIKadjGV
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
                prhist = histogram(rr_pr2, min=cutoff, max=maxz4hist, binsize = bs, $
                                   locations = prhiststart)
                nxhist = histogram(rr_gv2, min=cutoff, max=maxz4hist, binsize = bs)
                plot, [15,MAX(prhiststart)],[0,FIX((MAX(prhist)>MAX(nxhist))*1.1)], $
                      /NODATA, COLOR=255, $
                      XTITLE=bblevstr[bblev2get]+' BB Reflectivity, dBZ', $
                      YTITLE='Number of DPR Footprints', $
                      YRANGE=[ 0, FIX((MAX(prhist)>MAX(nxhist))*1.1) + 1 ], $
                      BACKGROUND=0
                END
         ENDCASE
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
           CASE xxx OF
           'RR' : BEGIN
                  bin4pr = VALUE_LOCATE( logbins, rr_pr2[idxconvhist] )
                  bin4gr = VALUE_LOCATE( logbins, rr_gv2[idxconvhist] )
                  prhist = histogram( bin4pr, min=0, max=18,locations = prhiststart )
                  nxhist = histogram( bin4gr, min=0, max=18,locations = prhiststart )
                  END
            'Z' : BEGIN
                  prhist = histogram(rr_pr2[idxconvhist], min=cutoff, max=maxz4hist, $
                                     binsize = bs, locations = prhiststart)
                  nxhist = histogram(rr_gv2[idxconvhist], min=cutoff, max=maxz4hist, $
                                     binsize = bs)
                  END
           ENDCASE
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
           CASE xxx OF
           'RR' : BEGIN
                  bin4pr = VALUE_LOCATE( logbins, rr_pr2[idxstrathist] )
                  bin4gr = VALUE_LOCATE( logbins, rr_gv2[idxstrathist] )
                  prhist = histogram( bin4pr, min=0, max=18,locations = prhiststart )
                  nxhist = histogram( bin4gr, min=0, max=18,locations = prhiststart )
                  END
            'Z' : BEGIN
                  prhist = histogram(rr_pr2[idxstrathist], min=cutoff, max=maxz4hist, $
                                     binsize = bs, locations = prhiststart)
                  nxhist = histogram(rr_gv2[idxstrathist], min=cutoff, max=maxz4hist, $
                                     binsize = bs)
                  END
           ENDCASE
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

IF ( s2ku ) THEN kutxt=' Ku-adjusted ' else kutxt=''
IF ( pctAbvThresh GT 0.0 ) THEN BEGIN
   IF ( pctAbvThresh EQ 100.0 ) THEN gt_ge = "     " ELSE gt_ge = "    >="
   SCATITLE = site+kutxt+gr_rr_zr+' vs. '+pr_or_dpr+' '+instrument+'/'+swath+"/" $
              +version+gt_ge+pctString+"% bins above threshold"
ENDIF ELSE BEGIN
   SCATITLE = site+kutxt+gr_rr_zr+' vs. '+pr_or_dpr+' '+instrument+'/'+swath+"/"+version $
              +" -- All non-missing pairs"
ENDELSE

TITLE2 = "Orbit:  "+orbit+"  --  GR Start Time:  "+data_struct.mysweeps[0].atimeSweepStart

IF ( do_ps EQ 1 ) THEN BEGIN
   xyouts, 0.5, -0.07, SCATITLE, alignment=0.5, color=255, /normal, $
           charsize=1., Charthick=1.5
   xyouts, 0.5, -0.10, TITLE2, alignment=0.5, color=255, /normal, $
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

IF ( do_ps EQ 1 ) THEN BEGIN
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
  ; close and delete the temp file
   FREE_LUN, tempunit2
   FILE_DELETE, temptext, VERBOSE=1
ENDIF
; - - - - - - - - - - - - - - - - - - - - - - - -

; Build the Scatter Plots

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
   plot_scatter_by_bb_prox_ps, PSFILEpdf, SCATITLE, siteID, yvar, xvar, $
                            rnType, bbProx, num4hist3, idx4hist3, S2KU=s2ku, $
                            MIN_XY=min_xy, MAX_XY=max_xy, UNITS=units, $
                            SAT_INSTR=sat_instr, SKIP_BB=skipBB, HEIGHTS=samphgt
ENDIF ELSE BEGIN
   scatwinsize = windowsize > 375  ; constrain size to be 375 pixels or greater
   plot_scatter_by_bb_prox, SCATITLE, siteID, yvar, xvar, rnType, bbProx, $
                            num4hist3, idx4hist3, scatwinsize, S2KU=s2ku, $
                            MIN_XY=min_xy, MAX_XY=max_xy, UNITS=units, $
                            SAT_INSTR=sat_instr, SKIP_BB=skipBB
ENDELSE

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
           print, "First, Last sweep requested = ", startelev+1, ',', $
                  startelev+elevs2show
           print, "Number of sweeps to show (adjusted): ", nframes
      ENDELSE
   ENDIF ELSE BEGIN
        elevs2show = 1
        nframes = 1
        startelev = nswp - 1
        print, "Number of sweeps present = ", nswp
        print, "First, Last sweep requested = ", startelev+1, ',', $
               startelev+elevs2show
        print, "Showing only sweep number: ", startelev+1
   ENDELSE

   IF ( elevs2show EQ 0 ) THEN GOTO, nextFile
   do_pixmap=0
   IF ( elevs2show GT 1 ) THEN BEGIN
      do_pixmap=1
      retain = 0
      print, ""
      print, "Please wait while PPI image animation is being prepared..."
      print, ""
   ENDIF ELSE retain = 2

   !P.MULTI=[0,1,1]
   IF ( N_ELEMENTS(windowsize) NE 1 ) THEN windowsize = 375
   xsize = windowsize[0]
   ysize = xsize
   windownum = 2
   title = ""

   ppi_comn = { winSize : windowsize, $
                winNum : windownum, $
                winTitle : TITLE2, $
                nframes : nframes, $
                startelev : startelev, $
                looprate : looprate, $
                mysweeps : data_struct.mysweeps, $
                PPIorient : PPIorient, $
                PPIbyThresh : PPIbyThresh, $
                pctString : pctString, $
                site_Lat : data_struct.mysite.site_lat, $
                site_Lon : data_struct.mysite.site_lon, $
                site_ID : siteID, $
                xCorner : xCorner, $
                yCorner : yCorner, $
                pr_index : pr_index, $
                num_footprints : nfp, $
                rangeThreshold : data_struct.mygeometa.rangeThreshold, $
                rntype4ppi : rntype4ppi }

  ; redefine gr_rr_zr for PPI plots.  Set to blank if plotting Z-R or else get
  ; redundant Z-R field in label
   IF (have_gvrr) THEN gr_rr_zr = ' DP' ELSE gr_rr_zr = ' '
   IF pctAbvThresh GT 0.0 AND PPIbythresh THEN sayPct = 1 ELSE sayPct = 0
   IF (haveKdp and haveZdr and haveHID) THEN BEGIN
      fieldData = ptrarr(3,3, /allocate_heap)
      IF xxx EQ 'Z' THEN BEGIN
         fieldIDs = [ ['CZ','CZ','DR'], $
                      ['CZ','CZ','FH'], $
                      ['KD','D0','RH'] ]
      ENDIF ELSE BEGIN
         fieldIDs = [ ['CZ','CZ','DR'], $
                      ['RR',data_struct.rr_field_used,'FH'], $
                      ['KD','D0','RH'] ]
      ENDELSE
      sources = [ [pr_or_dpr+'/'+instrument, siteID, siteID], $
                  [pr_or_dpr+'/'+instrument, siteID+gr_rr_zr, siteID], $
                  [siteID,siteID,siteID] ]
      thresholded = [ [0,0,0], $
                      [sayPct,sayPct,0], $
                      [0,0,0] ]
      *fieldData[0] = zcor_in
      *fieldData[1] = gvz_in
      *fieldData[2] = Zdr
      IF xxx EQ 'Z' THEN *fieldData[3] = zcor_in2 ELSE *fieldData[3] = rain3_in2
      IF xxx EQ 'Z' THEN *fieldData[4] = gvz_in2 ELSE *fieldData[4] = gvrr_in2
      *fieldData[5] = HIDcat
      *fieldData[6] = Kdp
      *fieldData[7] = Dzero
      *fieldData[8] = RHOhv
   ENDIF ELSE BEGIN
      fieldData = ptrarr(2,2, /allocate_heap)
      IF xxx EQ 'Z' THEN BEGIN
               fieldIDs = [['CZ','CZ'],['CZ','CZ']]
      ENDIF ELSE BEGIN
         fieldIDs = [ ['CZ','CZ'], ['RR',data_struct.rr_field_used] ]
      ENDELSE
      sources = [['PR',siteID],['PR',siteID+gr_rr_zr]]
      thresholded = [[0,0],[sayPct,sayPct]]
      *fieldData[0] = zcor_in
      *fieldData[1] = gvz_in
      IF xxx EQ 'Z' THEN *fieldData[2] = zcor_in2 ELSE *fieldData[2] = rain3_in2
; TAB 9/4/18:
;  I think this is a preexisting bug, changed index from 2 to 3
;      IF xxx EQ 'Z' THEN *fieldData[2] = gvz_in2 ELSE *fieldData[3] = gvrr_in2
      IF xxx EQ 'Z' THEN *fieldData[3] = gvz_in2 ELSE *fieldData[3] = gvrr_in2
   ENDELSE

   plot_geo_match_ppi_anim_ps, fieldIDs, sources, fieldData, thresholded, $
                               ppi_comn, DO_PS=do_ps, SHOW_PPIS=show_ppis, $
                               STEP_MANUAL=step_manual
   FOR nfieldptr = 0, N_ELEMENTS(fieldData)-1 DO ptr_free, fieldData[nfieldptr]

   if havemrms and xxx EQ 'RR' then begin

;      fieldData = ptrarr(3,1, /allocate_heap)
;      fieldIDs = [['RR','RR','RR']]
;      sources = [['DPR','MRMS',siteID+gr_rr_zr]]
;      thresholded = [[0,0,sayPct]]
      fieldData = ptrarr(1,3, /allocate_heap)
      fieldIDs = [['RR'],['RR'],['RR']]
      sources = [['DPR'],[siteID+gr_rr_zr],['MRMS']]
;      thresholded = [[0],[sayPct],[0]]
      thresholded = [[saypct],[sayPct],[0]]

      *fieldData[0] = nearsurfrain
      *fieldData[1] = gvrr_in2
      *fieldData[2] = mrmsrr
       
 ;     IF xxx EQ 'Z' THEN *fieldData[2] = gvz_in2 ELSE *fieldData[2] = gvrr_in2

      plot_geo_match_ppi_rr_mrms_ps, fieldIDs, sources, fieldData, thresholded, $
                               ppi_comn, DO_PS=do_ps, SHOW_PPIS=show_ppis

      FOR nfieldptr = 0, N_ELEMENTS(fieldData)-1 DO ptr_free, fieldData[nfieldptr]
    endif
   if haveswe and  xxx EQ 'RR' then begin

      fieldData = ptrarr(2,3, /allocate_heap)
      fieldIDs = [['SE','SE'],['SE','SE'],['SE','SE']]
      sources = [['DPR','SWE25'],[siteID+gr_rr_zr,'SWE50'],['SWEDP','SWE75']]
      thresholded = [[sayPct,0],[sayPct,0],[0,0]]

      *fieldData[0] = nearsurfrain
      *fieldData[1] = swe25
      *fieldData[2] = gvrr_in2
      *fieldData[3] = swe50
      *fieldData[4] = swedp
      *fieldData[5] = swe75
;      IF xxx EQ 'Z' THEN *fieldData[2] = gvz_in2 ELSE *fieldData[2] = gvrr_in2

      plot_geo_match_ppi_rr_mrms_ps, fieldIDs, sources, fieldData, thresholded, $
                               ppi_comn, DO_PS=do_ps, SHOW_PPIS=show_ppis

      FOR nfieldptr = 0, N_ELEMENTS(fieldData)-1 DO ptr_free, fieldData[nfieldptr]
    endif

nextFile:

IF ( do_ps EQ 1 AND havePSfile EQ 1 ) THEN BEGIN  ; wrap up the postscript file
   set_plot,/copy,'ps'
   device,/close
   SET_PLOT, orig_device
  ; check whether we can convert it from PS to PDF, using ps2pdf utility
   if !version.OS_NAME eq 'Mac OS X' then ps_util_name = 'pstopdf' $
   else ps_util_name = 'ps2pdf'
   command1 = 'which '+ps_util_name
   spawn, command1, result, errout
   IF KEYWORD_SET( batch ) THEN BEGIN
     ; convert to PDF if possible, or just leave PS file as-is
      IF result NE '' THEN BEGIN
         print, 'Converting ', PSFILEpdf, ' to PDF format.'
         command2 = ps_util_name+ ' ' + PSFILEpdf
         spawn, command2, result, errout
         print, 'Removing Postscript version'
         command3 = 'rm -v '+PSFILEpdf
         spawn, command3, result, errout
      ENDIF
   ENDIF ELSE BEGIN
     ; prompt whether to save resulting postscript/PDF file or dump it
      reply = ""
      READ, reply, PROMPT='Hit Return to save PS/PDF file, or D to delete: '
      IF (STRUPCASE(reply) NE "D") AND (reply NE "") THEN BEGIN
         PRINT, "Unknown reply, saving Postscript/PDF file."
         reply = ""
      ENDIF
      IF STRUPCASE(reply) NE "D" THEN BEGIN
         IF result NE '' THEN BEGIN
           ; convert to PDF if possible, or just leave PS file as-is
            print, 'Converting ', PSFILEpdf, ' to PDF format.'
            command2 = ps_util_name+ ' ' + PSFILEpdf
            spawn, command2, result, errout
            print, 'Removing Postscript version'
            command3 = 'rm -v '+PSFILEpdf
            spawn, command3, result, errout
         ENDIF
      ENDIF ELSE BEGIN
         print, 'Removing Postscript file as directed:'
         command3 = 'rm -v '+PSFILEpdf
         spawn, command3, result, errout
      ENDELSE
   ENDELSE
ENDIF

something = ""
IF (do_ps AND batch) THEN GOTO, noPPIwindow    ; skip prompt, and no PPI window 2

IF (nframes LT 2 AND show_ppis) OR hidePPIs THEN BEGIN
   print, ''
   IF data_struct.is_subset THEN $
      READ, something, PROMPT='Hit Return to continue with subset processing, or Q to Quit: ' $
   ELSE READ, something, PROMPT='Hit Return to continue to next case, or Q to Quit: '
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
      print, "Please do not close scatter plot window manually!  Continue..."
   ENDELSE
endif

status = 0
IF something EQ 'Q' OR something EQ 'q' THEN status = 2

errorExit:

return, status
end
