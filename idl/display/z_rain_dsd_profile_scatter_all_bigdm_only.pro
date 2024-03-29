;+
;  z_rain_dsd_profile_scatter_all_bigdm_only.pro   Morris/SAIC/GPM_GV  Mar 2017
;
; DESCRIPTION
; -----------
; This is a modified version of z_rain_dsd_profile_scatter_all that only
; includes data from profiles where the DPR Dm somewhere along the column is
; 2.5 mm or greater.
;
; Reads PR (or DPR) and GV reflectivity (default) and spatial fields from
; PRtoDPR or DPRtoGR geo_match netCDF files, builds index arrays of categories
; of range, rain type, bright band proximity (above, below, within), and height
; (13 categories, 1.5-19.5 km levels); and an array of actual range.  Produces
; separate scatter plots for stratiform and convective rain types for of each
; of the following data fields:
;
;    'ZM' : DPR measured Z vs. GR Z
;    'ZC' : DPR corrected Z vs. GR Z
;    'D0' : DPR Dm vs. GR D0 (adjusted to Dm)
;    'DM' : DPR Dm vs. GR Dm
;    'NW' : DPR Nw vs. GR Nw
;    'N2' : DPR Nw vs. GR N2
;    'RR' : DPR 3-D rainrate vs. GR RR (DROPS2.0) rainrate
;    'RC' : DPR 3-D rainrate vs. GR RC (Cifelli) rainrate
;    'RP' : DPR 3-D rainrate vs. GR RP (Polarimetric Z-R) rainrate
;  'ZCNWG': GR Zc vs. GR Nw
;  'NWDMG': GR Nw vs. GR Dm
;  'ZCNWP': DPR Zc vs. DPR Nw
;  'NWDMP': DPR Nw vs. DPR Dm
;  'DMRRG': GR Dm vs. GR RR
;  'RRNWG': GR RR vs. GR Nw
;  'DMRRP': DPR Dm vs. DPR RR
;  'RRNWP': DPR RR vs. DPR Nw
;'NWGZMXP': GR Nw vs. DPR Max(measured Z)  (DPR column max Zm)
;   'EPSI': DPR (original 2A product values if available, derived if not)
;           epsilon vs. GR derived epsilon
;
; If an alternate field is specified in the ALTFIELD parameter (values as
; defined by the IDs in quotes, above), then scatter plots will be created for
; this field only.  Except for the plot types ZC and ZM, the scatter plots
; include only for samples in below-bright-band category AND below 3 km.  For ZC
; and ZM the stratiform scatter plots include only/all samples ABOVE the bright
; band, and the convective plots include only/all samples BELOW the bright band.
;
; Optionally, if PROFILE_SAVE is defined and gives the name of a directory or
; the full pathname of an IDL SAVE file to write vertical profiles variables
; to, also produces vertical profile plots of PR/DPR corrected (default) or
; measured (ALTFIELD='ZM') reflectivity vs. GR reflectivity, and saves the
; profile variable arrays in the SAVE file.  If a full pathname is given, the
; variables are saved to this file; otherwise a default file name is composed
; and the variables are saved to this file in the directory given by the value
; of the PROFILE_SAVE parameter.
;
;
; PARAMETERS
; ----------
; None.
;
; FILES
; -----
; /data/gpmgv/netcdf/geo_match/*        INPUT: The set of site/orbit specific
;                                              netCDF grid files for which
;                                              stats are to be computed.  The
;                                              files used are controlled in code
;                                              by the file pattern specified for
;                                              the 'pathpr' internal variable.
;
; PARAMETERS
; ----------
;
; instrument   - Controls which type of matchup data to process: PR (TRMM data),
;                or DPR or DPRGMI (GPM data).  Determines default ncsitepath
;                such that the selected instrument's matchup files are read. 
;                If instrument and ncsitepath are both specified and are at
;                odds, then errors will occur in reading the data.  Default=DPR
;
; KuKa         - designates which DPR instrument's data to analyze for the
;                DPRGMI matchup type.  Allowable values are 'Ku' and 'Ka'.  If
;                SCANTYPE=swath parameter is 'NS' then KuKa_cmb must be 'Ku'. 
;                If unspecified or if in conflict with swath then the value will
;                be assigned to 'Ku' by default.
;
; swath        - designates which swath (scan type) to analyze for the DPRGMI
;                matchup type.  Allowable values are 'MS' and 'NS' (default).
;
; pctAbvThresh - constraint on the percent of bins in the geometric-matching
;                volume that were above their respective thresholds, specified
;                at the time the geo-match dataset was created.  Essentially a
;                measure of "beam-filling goodness".  100 means use only those
;                matchup points where all the PR and GV bins in the volume
;                averages were above threshold (complete volume filled with
;                above threshold bin values).  0 means use all matchup points
;                available, with no regard for thresholds.  Default=100
;
; gv_convective - GV reflectivity threshold at/above which GV data are considered
;                 to be of Convective Rain Type.  Default = 35.0 if not specified.
;                 If set to <= 0, then GV reflectivity is ignored in evaluating
;                 whether PR-indicated Stratiform Rain Type matches GV type.
;
; gv_stratiform - GV reflectivity threshold at/below which GV data are considered
;                 to be of Stratiform Rain Type.  Default = 25.0 if not specified.
;                 If set to <= 0, then GV reflectivity is ignored in evaluating
;                 whether PR-indicated Convective Rain Type matches GV type.
;
; s2ku          - If set, apply S-to-Ku adjustment to GR reflectivity
;
; name_add      - String to be added to output filename to identify run results
;
; ncsitepath    - Top-level directory under which to recursively search for
;                 matchup netCDF files to be read and processed.  If not
;                 specified, then a File Selector will be displayed with which
;                 the user can select the starting path.
;
; filepattern   - Filename pattern to be used in recursive search for matching
;                 filenames under ncsitepath directory.  If not specified,
;                 defaults to 'GRto'+instrument+'*' (e.g., GRtoDPR*).  Results
;                 may be filtered further according to the 'sitelist' and
;                 'exclude' parameter values.
;
; sitelist      - Optional array of radar site IDs limiting the set of matchup
;                 files to be included in the processing.  Only matchup files
;                 for sites included in sitelist will be processed.
;
; exclude       - Binary keyword, reverses the default functionality of sitelist
;                 such that only files in sitelist are EXCLUDED from processing.
;
; outpath       - Directory to which output data files will be written
;
; altfield      - Data field to be analyzed instead of default reflectivity.
;                 See prologue for allowable altfield names.
;
; bb_relative   - If set, then organize data by distance above/below mean bright
;                 band height rather than by height above the surface
;
; profile_save  - Optional filename to which computed mean profile statistics
;                 variables will be saved as an IDL SAVE file
;
; alt_bb_file   - Optional file holding computed RUC BB heights for site/orbit
;                 combinations to be used in place of PR/DPR BB heights when the
;                 latter cannot be determined from the data in the matchup file.
;                 Current pathname, try /data/tmp/rain_event_nominal.YYMMDD.txt
;                 where YYMMDD is the latest date available.
;
; forcebb       - Binary keyword.  If set, and if alt_bb_file is specified and
;                 a valid value for the mean BB height can be located in the
;                 file, then this BB height value will override any mean BB
;                 height determined from the DPR data.  Ignored if alt_bb_file
;                 is not specified.
;
; first_orbit   - Optional parameter to define the first orbit, and optionally,
;                 the last orbit to be processed.  If only one value is given it
;                 is interpreted as the first orbit (lowest orbit number) to be
;                 processed.  If two values are specified in an INT array, the
;                 first (second) value specifies the first (last) orbit to be
;                 included in the processing.
;
; scatterplot   - Optional binary parameter.  If set, then scatter plots of
;                 predefined data fields listed in the prologue for stratiform
;                 and convective rain type will be created and displayed as a
;                 series of IDL IMAGE objects which may be saved to PNG files.
;
; bins4scat     - Optional binary parameter.  If set, then overrides default
;                 value of the bin size used in computing histograms for
;                 rain rate and reflectivity.  Does not affect histograms for
;                 other variables.
;
; plot_obj_array - Optional parameter.  If the caller defines a variable (any
;                  type/value) and supplies it to this routine as the parameter,
;                  then it will be redefined as an array of references to IDL
;                  PLOT objects that refer to the optional profile plot, but
;                  only if the user selects not to have it closed before
;                  this procedure exits.  Only the "top level" PLOT object
;                  reference is included, not those of the overplots,
;                  legends, colorbars, etc.
;
; ray_range     - INTARR(2), specifies the first and last ray numbers to be
;                 included in the computations.  1-based, ranges from 1 to the
;                 number of rays in the swath (RAYSPERSCAN_xx).  If the first
;                 number is less than the second number, then the ray numbers
;                 to process are those BETWEEN the two values, inclusive (e.g.,
;                 the center of the swath).  If the first value is greater than
;                 the second value, then the ray numbers to include are from 0
;                 to ray_range[1], and from ray_range[0] to RAYSPERSCAN_xx,
;                 where xx is the scan type (i.e., the two sides of the swath).
;
; max_blockage   - Optional parameter.  Specifies the maximum fraction of GR
;                  beam blockage allowed for samples included in the statistics,
;                  when blockage is present in the matchup dataset.  Value may
;                  be specified as a percent from 1 to 100, or as a fraction
;                  between 0.0 and 1.0.  Ignored if GR blockage is not present
;                  in the matchup data (only CONUS WSR-88D sites have this).
;
; z_blockage_thresh_in - optional parameter to limit samples included in the
;                        comparisons by beam blockage, as implied by a Z dropoff
;                        between the second and first sweeps.  Is ignored in the
;                        presence of valid MAX_BLOCKAGE value and presence of
;                        GR_blockage data.
;
; VERSION2MATCH  - Optional parameter.  Specifies one or more different PPS
;                  version(s) for which the current matchup file must have at
;                  least one corresponding matchup file of these data versions
;                  for the given site and orbit.  That is, if the file for this
;                  site and orbit and PPS version does not exist in at least one
;                  of the versions specified by VERSION2MATCH, then the current
;                  file is excluded in processing the statistics.
;
; batch_save     - Optional parameter. IF set, then the scatter plots will be
;                  created in  a buffer in memory rather than on-screen, and the
;                  plots will automatically be saved to PNG files with no user
;                  prompting or interaction.  This is useful when running IDL
;                  over a remote connection where the plotting of IDL object
;                  graphics is very slow.
;
; DPR_Z_ADJUST   - Optional parameter.  Bias offset to be applied (added to) the
;                  DPR reflectivity values to account for the calibration offset
;                  between the DPR and ground radars in a global sense (same for
;                  all GR sites).  Positive (negative) value raises (lowers) the
;                  non-missing DPR reflectivity values.
;
; GR_Z_ADJUST    - Optional parameter.  Pathname to a "|"-delimited text file
;                  containing the bias offset to be applied (added to) each
;                  ground radar site's reflectivity to correct the calibration
;                  offset between the DPR and ground radars in a site-specific
;                  sense.  Each line of the text file lists one site identifier
;                  and its bias offset value separated by the delimiter, e.g.:
;
;                  KMLB|2.89
;
;                  If no matching site entry is found in the file for a radar,
;                  then its reflectivity is not changed from the value in the
;                  matchup netCDF file.  The bias adjustment is applied AFTER
;                  the frequency adjustment if the S2KU parameter is set.
;
; et_range       - Optional parameter.  Specifies a range of echo (storm) top
;                  heights that the stormTopHeight for the DPR ray must lie
;                  between for samples along that ray to be included in the
;                  statistics.  Must be a 2-element numerical array with values
;                  given in units of either km or m.  If km, the values will be
;                  internally converted to integer meters.  Bounds are
;                  inclusive, i.e., et_range[0] <= ET <= et_range[1].  Ignored
;                  if INSTRUMENT value is not 'DPR', as only this matchup file
;                  type currently contains the stormTopHeight variable.
;
; CALLS
; -----
; fprep_geo_match_profiles()          fprep_dpr_geo_match_profiles()
; fprep_dprgmi_geo_match_profiles()   site_bias_hash_from_file()
; accum_histograms_by_raintype        get_grouped_data_mean_stddev()
; fplot_mean_profiles()               plot_mean_profiles()
;
; HISTORY
; -------
; 07/19/16 by Bob Morris, GPM GV (SAIC)
;  - Created from stats_z_rain_dsd_to_db_profile_scatter, eliminating the file
;    output for the database and just producing the scatter plots and profiles.
;  - Moved the scatter plot data accumulation to a separate procedure named
;    accum_scat_data(), included in this file.
;  - Now processes scatter plot data subsets for every plot type, for both
;    stratiform and convective rain type, saves variables to a structure, and
;    assigns each to an array pointer.  Steps through the each plot type, grabs
;    the data from the plot's data structure by its associated pointer, and
;    creates the scatter plot display object.  ALTFIELD overrides the plotting
;    sequence to just display the one plot type given by altfield, for both
;    stratiform and convective rain type.
;  - Added BATCH_SAVE parameter to automatically save configured scatter and
;    profile plots to data-named PNG files without user prompts.  If not set,
;    then the user will be prompted whether to save the plot to a PNG file as
;    each plot is created.
; 11/8/14 by Bob Morris, GPM GV (SAIC)
;  - Reversed the Dm and Nw axes in the Dm vs. Nw plots for both DPR and GR
;    for Bill Olson request.
;  - Added Dm vs. RR and RR vs. Nw plots for both DPR and GR for Bill Olson.
;  - Added SWATH to the product descriptions when SCANTYPE parameter is
;    specified.  Defined prodStr variable to apply this to titles and names.
;  - Added (Q)uit option for when stepping through plots in non-batch mode.
; 11/16/16 by Bob Morris, GPM GV (SAIC)
;  - Added ET_RANGE parameter to limit samples by a range of echo top heights
;    between two values.
;  - Added plot of GR Nw vs. DPR Max(Zmeas) in version 1.3 matchup files.
;  - Added logic to properly deal with situation where no data were available
;    for the histograms for a plot.
; 11/22/16 Morris, GPM GV, SAIC
;  - Added DPR_Z_ADJUST=dpr_z_adjust and GR_Z_ADJUST=gr_z_adjust keyword/value
;    pairs to support DPR and site-specific GR bias adjustments.
;  - Modified BATCH mode to create IMAGE objects in a buffer rather than in a
;    displayed window.
;  - Added new and missing parameter definitions to prologue.
; 01/19/17 Morris, GPM GV, SAIC
;  - Added Z_BLOCKAGE_THRESH optional parameter to limit samples included in the
;    comparisons by beam blockage, as implied by a Z dropoff between the second
;    and first sweeps that exceeds the value of this parameter. Is only used if
;    MAX_BLOCKAGE is unspecified, or where no blockage information is contained
;    in the matchup file.
;  - Modified calls to HASH, TEXT, and COLORBAR, and replaced call to COLORTABLE
;    with calls to LOADCT to allow the procedure to run in old version IDL 8.1.
;  - Added a plot type DMANY that includes all Dm samples below the bright band
;    ragardless of rain type.
 ; 03/07/17 Morris, GPM GV, SAIC
 ;  - Added plots of DPR PIA vs. Dm.
;
;
; EMAIL QUESTIONS OR COMMENTS AT:
;       https://pmm.nasa.gov/contact
;-
;===============================================================================
; MODULE 2
;===============================================================================
;
; accum_scat_data        Morris/GPM GV/SAIC        July 2016
;
; Given two matching data arrays and the max and min values and bin sizes for
; each to use in computing a 2-D histogram of data value occurrences, creates
; and/or accumulates new values to the 2-D histogram count array specific to a
; scatter plot data type and a rain type.  Also computes a 1-D histogram of
; the mean X- and Y-array values, total number of samples, and Mean Absolute
; Error between X and Y for each Y-array bin.  Places new/updated computed
; histogram data into a structure and assigns the structure to a pointer for
; the plot data type and a rain type: *ptrData_array[plotIndex,raintypeBBidx].
;

PRO accum_scat_data, scat_X, scat_Y, binmin1, binmin2, binmax1, binmax2, $
                     BINSPAN1, BINSPAN2, ptrData_array, have_Hist, plotTypes, $
                     plotIndex, raintypeBBidx

; position indices/definitions of the 3 flags in the arrays in the structure
; - must be as initially defined in z_rain_dsd_profile_scatter_all.pro
haveVar = 0   ; do we have data for the variable
have1D  = 1   ; does the accumulating 2-D histogram for the variable exist yet?
have2D  = 2   ; does the accumulating 1-D histogram for the variable exist yet?

; get a short version of the array pointer being worked
aptr = (ptrData_array)[plotIndex,raintypeBBidx]

;         PRINT, '******************************************************'
;         print, "Getting "+plotTypes[plotIndex]+' SAMPLES FOR HISTOGRAM.'
;         PRINT, '******************************************************'

  ; Check whether the arrays to be histogrammed both have in-range values,
  ; otherwise just skip trying to histogram out-of-range data
   min__X = MIN(scat_X, MAX=max__X)
   min__Y = MIN(scat_Y, MAX=max__Y)
   IF (min__X GE binmin1 AND max__X LE binmax1 AND min__Y GE binmin2 AND $
       max__Y LE binmax2) THEN BEGIN

         zhist2d = HIST_2D( scat_X, scat_Y, MIN1=binmin1, $
                            MIN2=binmin2, MAX1=binmax1, MAX2=binmax2, $
                            BIN1=BINSPAN1, BIN2=BINSPAN2 )
         minprz = MIN(scat_Y)
         numpts = TOTAL(zhist2d)
         IF have_hist.(plotIndex)[have2d,raintypeBBidx] EQ 1 THEN BEGIN
           ; add to existing 2D hist arrays
            (*aptr).zhist2d = (*aptr).zhist2d + zhist2d
            (*aptr).minprz = MIN(scat_Y) < (*aptr).minprz
            (*aptr).numpts = (*aptr).numpts + numpts
         ENDIF ELSE BEGIN
            have_hist.(plotIndex)[have2d,raintypeBBidx] = 1
           ; create this part of the I/O structure to assign to the pointer
            iostruct2 = { zhist2d:zhist2d, minprz:minprz, numpts:numpts }
         ENDELSE
        ; compute the mean X (gv) for the samples in each Y (pr) histogram bin
         zhist1dpr=HISTOGRAM(scat_Y, MIN=binmin2, MAX=binmax2, BINSIZE=BINSPAN2, $
                             LOCATIONS=Zstarts, REVERSE_INDICES=RIdpr)
         ndprbins=N_ELEMENTS(Zstarts)
         gvzmeanByBin=FLTARR(ndprbins)
         przmeanByBin = gvzmeanByBin
         MAEbyBin = gvzmeanByBin
         nbybin = lonarr(ndprbins)
         for ibin = 0, ndprbins-1 do begin
            IF RIdpr[ibin] NE RIdpr[ibin+1] THEN BEGIN
               gvzmeanByBin[ibin] = MEAN( scat_X[ RIdpr[RIdpr[ibin] : RIdpr[ibin+1]-1] ] )
               przmeanByBin[ibin] = MEAN( scat_Y[ RIdpr[RIdpr[ibin] : RIdpr[ibin+1]-1] ] )
               MAEbyBin[ibin] = ABS(gvzmeanByBin[ibin]-przmeanByBin[ibin])
               nbybin[ibin] = RIdpr[ibin+1]-RIdpr[ibin]
            ENDIF
         endfor
 ;        print, "locations: ", Zstarts
 ;        print, "gvzmeanByBin: ", gvzmeanByBin
 ;        print, "przmeanByBin: ", przmeanByBin
         IF have_hist.(plotIndex)[have1d,raintypeBBidx] EQ 1 THEN BEGIN
            (*aptr).gvzmeanaccum = (*aptr).gvzmeanaccum + gvzmeanByBin*nbybin
            (*aptr).przmeanaccum = (*aptr).przmeanaccum + przmeanByBin*nbybin
            (*aptr).MAEaccum = (*aptr).MAEaccum + MAEbyBin*nbybin
            (*aptr).nbybinaccum = (*aptr).nbybinaccum + nbybin
         ENDIF ELSE BEGIN
            gvzmeanaccum = gvzmeanByBin*nbybin
            przmeanaccum = przmeanByBin*nbybin
            MAEaccum = MAEbyBin*nbybin
            nbybinaccum = nbybin
            have_hist.(plotIndex)[have1d,raintypeBBidx] = 1
           ; append this part of the I/O structure and assign to the pointer
            iostruct = CREATE_STRUCT( iostruct2, $
                                      'gvzmeanaccum', gvzmeanaccum, $
                                      'przmeanaccum', przmeanaccum, $
                                      'MAEaccum', MAEaccum, $
                                      'nbybinaccum', nbybinaccum, $
                                      'Zstarts', Zstarts )
            *ptrData_array[plotIndex,raintypeBBidx] = iostruct
         ENDELSE
   ENDIF
end

;===============================================================================
; MODULE 1 (Main Module)
;===============================================================================

PRO z_rain_dsd_profile_scatter_all_bigdm_only, $
                                    INSTRUMENT=instrument,         $
                                    KUKA=KuKa, SCANTYPE=swath,     $
                                    PCT_ABV_THRESH=pctAbvThresh,   $
                                    GV_CONVECTIVE=gv_convective,   $
                                    GV_STRATIFORM=gv_stratiform,   $
                                    S2KU=s2ku,                     $
                                    NAME_ADD=name_add,             $
                                    NCSITEPATH=ncsitepath,         $
                                    FILEPATTERN=filepattern,       $
                              NCFILELIST=ncfilelist,        $
                                    SITELIST=sitelist,             $
                                    EXCLUDE=exclude,               $
                                    OUTPATH=outpath,               $
                                    ALTFIELD=altfield,             $
                                    BB_RELATIVE=bb_relative,       $
                                    PROFILE_SAVE=profile_save,     $
                                    ALT_BB_FILE=alt_bb_file,       $
                                    FORCEBB=forcebb,               $
                                    FIRST_ORBIT=first_orbit,       $
                                    SCATTERPLOT=scatterplot,       $
                                    BINS4SCAT=bins4scat,           $
                                    PLOT_OBJ_ARRAY=plot_obj_array, $
                                    RAY_RANGE=ray_range,           $
                                    MAX_BLOCKAGE=max_blockage_in,  $
                                    Z_BLOCKAGE_THRESH=z_blockage_thresh_in, $
                                    VERSION2MATCH=version2match,   $
                                    BATCH_SAVE=batch_save,         $
                                    DPR_Z_ADJUST=dpr_z_adjust,     $
                                    GR_Z_ADJUST=gr_z_adjust,       $
                                    ET_RANGE=et_range

; "include" file for structs returned by read_geo_match_netcdf()
@geo_match_nc_structs.inc
; "include" file for PR data constants
@pr_params.inc

IF FLOAT(!version.release) lt 8.1 THEN message, "Requires IDL 8.1 or later."

OPENW, Unit, '/tmp/BigDmFiles.txt', /GET_LUN

; this is really just a QC step right now on the altfield value, except for
; setting use_zraw flag for ZM case
IF N_ELEMENTS(altfield) EQ 1 THEN BEGIN
   CASE STRUPCASE(altfield) OF
       'ZM' : z2do = 'Zm'
       'ZC' : z2do = 'Zc'
       'D0' : z2do = 'D0'
       'DM' : z2do = 'Dm'
     'DMANY': z2do = 'DmAny'
       'NW' : z2do = 'Nw'
       'N2' : z2do = 'N2'
       'RR' : z2do = 'RR'
       'RC' : z2do = 'RC'
       'RP' : z2do = 'RP'
     'ZCNWG': z2do = 'ZcNwG'
     'NWDMG': z2do = 'NwDmG'
     'ZCNWP': z2do = 'ZcNwP'
     'NWDMP': z2do = 'NwDmP'
     'DMRRG': z2do = 'DmRRG'
     'RRNWG': z2do = 'RRNwG'
     'DMRRP': z2do = 'DmRRP'
     'RRNWP': z2do = 'RRNwP'
   'NWGZMXP': z2do = 'NwGZmxP'    ; GR Nw vs. DPR ZmMax
    'PIADMP': z2do = 'PIADmP'
      'EPSI': z2do = 'EPSI'
       ELSE : message, "Invalid ALTFIELD value, must be one of: " + $
              "ZC, ZM, D0, DM, NW, N2, RR, RC, RP, ZCNWG, NWDMG, ZCNWP" + $
              ", NWDMP, DMRRG, RRNWG, DMRRP, RRNWP, NWGZMXP, EPSI"
   ENDCASE
ENDIF ELSE z2do = 'Zc'

IF z2do EQ 'Zm' THEN use_zraw = 1 ELSE use_zraw = 0

IF KEYWORD_SET(scatterplot) THEN BEGIN
   do_scatr=1
   zHist_ptr = ptr_new(/allocate_heap)
   biasAccum = 0.0D    ; to accumulate event-weighted bias
   nbiasAccum = 0L     ; to accumulate event weights (# samples)
ENDIF ELSE do_scatr=0
have2dhist = 0
have1dhist = 0

; determine whether to display the scatter plot objects or just create them
; in a buffer for saving in batch mode
IF KEYWORD_SET(batch_save) THEN buffer=1 ELSE buffer=0

; set up plot-specific flags for presence of data and 1-D and 2-D Histograms
; of the data.  First triplet of values are for stratiform/aboveBB, 2nd triplet
; is convective/belowBB
have_Hist = {    ZM : [[0,0,0],[0,0,0]], $
                 ZC : [[0,0,0],[0,0,0]], $
                 D0 : [[0,0,0],[0,0,0]], $
                 DM : [[0,0,0],[0,0,0]], $
              DMANY : [[0,0,0],[0,0,0]], $
                 NW : [[0,0,0],[0,0,0]], $
                 N2 : [[0,0,0],[0,0,0]], $
                 RR : [[0,0,0],[0,0,0]], $
                 RC : [[0,0,0],[0,0,0]], $
                 RP : [[0,0,0],[0,0,0]], $
              ZCNWG : [[0,0,0],[0,0,0]], $
              NWDMG : [[0,0,0],[0,0,0]], $
              ZCNWP : [[0,0,0],[0,0,0]], $
              NWDMP : [[0,0,0],[0,0,0]], $
              DMRRG : [[0,0,0],[0,0,0]], $
              RRNWG : [[0,0,0],[0,0,0]], $
              DMRRP : [[0,0,0],[0,0,0]], $
              RRNWP : [[0,0,0],[0,0,0]], $
            NWGZMXP : [[0,0,0],[0,0,0]], $
             PIADMP : [[0,0,0],[0,0,0]], $
               EPSI : [[0,0,0],[0,0,0]] }

; position indices/definitions of the 3 flags in the array triplets in the structure
; - must be identically defined in accum_scat_data.pro
haveVar = 0   ; do we have data for the variable
have1D  = 1   ; does the accumulating 2-D histogram for the variable exist yet?
have2D  = 2   ; does the accumulating 1-D histogram for the variable exist yet?

; get array of tag names for the above for finding matching struct value
; for plot type = z2do, addressed by structure index number
; -- THESE WILL BE IN ALL-CAPITAL LETTERS REGARDLESS OF CASE USED TO
;    DEFINE THE STRUCTURE TAGS!
PlotTypes = TAG_NAMES(have_Hist)  ; 'DM', 'NW', 'ZCNWG', etc.
nPlots = N_ELEMENTS(PlotTypes)
; HASH to access structure element index by a case-sensitive PlotType string
; -- FOLD_CASE is an IDL 8.4 or later option, remove for now
PlotHash = HASH(PlotTypes, INDGEN(nPlots))  ;, /FOLD_CASE)

; define strings to indicate rain type in saved file names
rntypeLabels = ['Stratiform', 'Convective']

; define a 2-D array of pointers to data accumulations, histograms, etc., in a
; structure created in call to accum_scat_data().  2nd dimension is data subset
; being accumulated (0 = ConvectiveAboveBB, 1 = StratiformBelowBB)
plotDataPtrs = PTRARR(nPlots, 2, /ALLOCATE_HEAP)

IF ( N_ELEMENTS(instrument) NE 1 ) THEN BEGIN
   print, "Defaulting to DPR for instrument type."
   pr_or_dpr = 'DPR'
   SATDIR = 'GPM'
ENDIF ELSE BEGIN
   CASE STRUPCASE(instrument) OF
      'PR' : BEGIN
               pr_or_dpr = 'PR'
               SATDIR = 'TRMM'
               NW_SCALE = 1.0    ; already have log(Nw)??
             END
     'DPR' : BEGIN
               pr_or_dpr = 'DPR'
               SATDIR = 'GPM'
               NW_SCALE = 10.0    ; divide by this to convert dBNw to log(Nw)
             END
  'DPRGMI' : BEGIN
               pr_or_dpr = 'DPRGMI'
               SATDIR = 'GPM'
               NW_SCALE = 1.0    ; already have log(Nw)
               IF (z2do EQ 'ZM' AND use_zraw EQ 1) THEN BEGIN
                  PRINT, "No Zmeas field in DPRGMI matchups, using Zcor."
                  use_zraw = 0
               ENDIF
             END
      ELSE : message, "Allowable values for INSTRUMENT are PR, DPR, or DPRGMI"
   ENDCASE
ENDELSE

; Decide which PR and GV points to include, based on percent of expected points
; in bin-averaged results that were above dBZ thresholds set when the matchups
; were done.  If unspecified, set to 100% of bins required (as before this code
; change).  If set to zero, include all points regardless of 'completeness' of
; the volume averages.

IF ( N_ELEMENTS(pctAbvThresh) NE 1 ) THEN BEGIN
   print, "Defaulting to 100 for PERCENT BINS ABOVE THRESHOLD."
   pctAbvThresh = 100
   pctAbvThreshF = FLOAT(pctAbvThresh)
ENDIF ELSE BEGIN
   pctAbvThreshF = FLOAT(pctAbvThresh)
   IF ( pctAbvThreshF LT 0.0 OR pctAbvThreshF GT 100.0 ) THEN BEGIN
      print, "Invalid value for PCT_ABV_THRESH: ", pctAbvThresh, $
             ", must be between 0 and 100."
      print, "Defaulting to 100 for PERCENT BINS ABOVE THRESHOLD."
      pctAbvThreshF = 100.0
   ENDIF
END      

pctabvstr=STRING(FIX(pctAbvThreshF), FORMAT='(I0)')+'%'

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

; Set up for any filtering based on echo top height. Only the GRtoDPR files
; currently have the echo top variable, so ignore the et_range parameter
; otherwise.

IF N_ELEMENTS( et_range ) EQ 2 AND pr_or_dpr EQ 'DPR' THEN BEGIN
   IF is_a_number(et_range[0]) EQ 0 OR is_a_number(et_range[1]) EQ 0 THEN $
      message, 'Parameter value for ET_RANGE is not a 2-element numerical array.'
   IF (et_range[0] GE et_range[1]) THEN $
      message, 'Parameter values for ET_RANGE not valid.'
  ; check whether we have been given m or km for the range.  Need m to do the
  ; thresholding against the stormTopHeight variable
   IF MAX(et_range) LT 20 THEN BEGIN
      print, "Converting et_range from km to m."
      et_range_m = FIX(et_range*1000.)
   ENDIF ELSE BEGIN
      IF MAX(et_range) LT 1000 THEN $
         message, 'Parameter values for ET_RANGE not in range.' $
      ELSE et_range_m = FIX(et_range)
   ENDELSE
ENDIF ELSE BEGIN
   IF N_ELEMENTS( et_range ) GT 0 THEN BEGIN
      IF pr_or_dpr EQ 'DPR' THEN $
         message, 'Parameter value for ET_RANGE is not a 2-element numerical array.' $
      ELSE $
         message, 'Parameter ET_RANGE is not valid for INSTRUMENT = '+pr_or_dpr
   ENDIF
ENDELSE

; configure bias adjustment for GR and/or DPR

adjust_grz = 0  ; set flag to NOT try to adjust GR Z biases
IF N_ELEMENTS( gr_z_adjust ) EQ 1 THEN BEGIN
   IF FILE_TEST( gr_z_adjust ) THEN BEGIN
     ; read the site bias file and store site IDs and biases in a HASH variable
      siteBiasHash = site_bias_hash_from_file( gr_z_adjust )
      IF TYPENAME(siteBiasHash) EQ 'HASH' THEN BEGIN
         adjust_grz = 1  ; set flag to try to adjust GR Z biases
      ENDIF ELSE BEGIN
         print, "Problems with GR_Z_ADJUST file: ", gr_z_adjust
         entry = ''
         WHILE STRUPCASE(entry) NE 'C' AND STRUPCASE(entry) NE 'Q' DO BEGIN
            read, entry, PROMPT="Enter C to continue without GR site bias adjustment " $
                   + "or Q to exit here: "
            CASE STRUPCASE(entry) OF
                'C' : BEGIN
                        adjust_grz = 0  ; set flag to NOT try to adjust GR Z biases
                        break
                      END
                'Q' : GOTO, errorExit2
               ELSE : print, "Invalid response, enter C or Q."
            ENDCASE
         ENDWHILE  
      ENDELSE       
   ENDIF ELSE message, "File '"+gr_z_adjust+"' for GR_Z_ADJUST not found."
ENDIF

adjust_dprz = 0  ; set flag to NOT try to adjust DPR Z biases
IF N_ELEMENTS( dpr_z_adjust ) EQ 1 THEN BEGIN
   IF is_a_number( dpr_z_adjust ) THEN BEGIN
      dpr_z_adjust = FLOAT( dpr_z_adjust )  ; in case of STRING entry
      IF dpr_z_adjust GE -3.0 AND dpr_z_adjust LE 3.0 THEN BEGIN
         adjust_dprz = 1  ; set flag to try to adjust GR Z biases
       ENDIF ELSE BEGIN
         message, "DPR_Z_ADJUST value must be between -3.0 and 3.0 (dBZ)"
      ENDELSE
   ENDIF ELSE message, "DPR_Z_ADJUST value is not a number."
ENDIF


IF N_ELEMENTS(name_add) EQ 1 THEN $
   addme = '_'+STRTRIM(STRING(name_add),2) $
ELSE addme = ''
;IF keyword_set(use_zraw) THEN addme = addme+'_Zmeas'
IF keyword_set(bb_relative) THEN addme = addme+'_BBrel'
IF N_ELEMENTS(alt_bb_file) EQ 1 THEN addme = addme+'_AltBB'

s2ku = KEYWORD_SET( s2ku )

IF N_ELEMENTS(outpath) NE 1 THEN BEGIN
   outpath='/data/tmp'
   PRINT, "Assigning default output file path: ", outpath
ENDIF

outpath_sav = outpath  ; default path for any SAVE files to be written

; Set up for the PR-GV rain type matching based on GV reflectivity

IF ( N_ELEMENTS(gv_Convective) NE 1 ) THEN BEGIN
   print, "Defaulting to 35.0 dBZ for GV Convective floor threshold."
   gvConvective = 35.0
ENDIF ELSE BEGIN
   gvConvective = FLOAT(gv_Convective)
ENDELSE

IF ( N_ELEMENTS(gv_Stratiform) NE 1 ) THEN BEGIN
   print, "Defaulting to 25.0 dBZ for GV Stratiform ceiling threshold."
   gvStratiform = 25.0
ENDIF ELSE BEGIN
   gvStratiform = FLOAT(gv_Stratiform)
ENDELSE

;  - No more default assignment of NCSITEPATH if not specified, launch the File
;    Selector to specify the location in this case, starting from the default
;    location /data/gpmgv/netcdf/geo_match/SAT, where SAT is defined by the
;    value of INSTRUMENT (SAT=GPM for DPR, SAT=TRMM for PR).
;
IF N_ELEMENTS(ncsitepath) EQ 0 THEN ncsitepath = $
   DIALOG_PICKFILE( PATH='/data/gpmgv/netcdf/geo_match/'+SATDIR, /DIRECTORY )
pathpr = ncsitepath[0]

; If provided, use the keyword parameter FILEPATTERN to specify specific set of
; filenames to be recursively searched for under the top level path NCSITEPATH.
; If not provided, then define a default pattern
IF N_ELEMENTS(filepattern) EQ 0 THEN filepat='GRto'+pr_or_dpr+'.*.nc*' $
ELSE filepat='*'+filepattern+'*'

lastsite='NA'
lastorbitnum=0
lastncfile='NA'
;help, pathpr, filepat
IF N_ELEMENTS(ncfilelist) EQ 1 THEN BEGIN
  ; find out how many files are listed in the file 'ncfilelist'
   command = 'wc -l ' + ncfilelist
   spawn, command, result
   nf = LONG(result[0])
   IF (nf LE 0) THEN BEGIN
      print, "" 
      print, "No files listed in ", ncfilelist
      print, " -- Exiting."
      GOTO, errorExit
   ENDIF
;   IF N_ELEMENTS(ncsitepath) EQ 1 THEN ncpre=ncsitepath+'/' ELSE ncpre=''
   ncpre=''
   prfiles = STRARR(nf)
   OPENR, ncunit, ncfilelist, ERROR=err, /GET_LUN
   ; initialize the variables into which file records are read as strings
   dataPR = ''
   ncnum=0
   WHILE NOT (EOF(ncunit)) DO BEGIN 
     ; get GRtoPR filename
      READF, ncunit, dataPR
      ncfull = ncpre + STRTRIM(dataPR,2)
      IF FILE_TEST(ncfull, /REGULAR) THEN BEGIN
         prfiles[ncnum] = ncfull
         ncnum++
      ENDIF ELSE message, "File "+ncfull+" does not exist!", /INFO
   ENDWHILE  ; each matchup file to process in control file
   CLOSE, ncunit
   nf = ncnum
   IF (nf LE 0) THEN BEGIN
      print, "" 
      message, "No files listed in "+ncfilelist+" were found.", /INFO
      print, " -- Exiting."
      GOTO, errorExit
   ENDIF
;   IF STREGEX(prfiles[0], '.6.') EQ -1 THEN verstr='_v7' ELSE verstr='_v6'
ENDIF ELSE BEGIN
   prfiles = file_search(pathpr, filepat, COUNT=nf)
   IF (nf LE 0) THEN BEGIN
      print, "" 
      print, "No files found for pattern = ", pathpr
      print, " -- Exiting."
      GOTO, errorExit
   ENDIF
ENDELSE
;help, nf, prfiles

; set up pointers for each field to be returned from fprep_geo_match_profiles()
ptr_geometa=ptr_new(/allocate_heap)
ptr_sweepmeta=ptr_new(/allocate_heap)
ptr_sitemeta=ptr_new(/allocate_heap)
ptr_fieldflags=ptr_new(/allocate_heap)
ptr_gvz=ptr_new(/allocate_heap)
 ; new in Version 2 geo-match files
  ptr_gvzmax=ptr_new(/allocate_heap)
  ptr_gvzstddev=ptr_new(/allocate_heap)
ptr_zcor=ptr_new(/allocate_heap)
ptr_zraw=ptr_new(/allocate_heap)
ptr_rain3=ptr_new(/allocate_heap)
ptr_nearSurfRain=ptr_new(/allocate_heap)
ptr_nearSurfRain_2b31=ptr_new(/allocate_heap)
ptr_pia=ptr_new(/allocate_heap)
;ptr_rnFlag=ptr_new(/allocate_heap)
ptr_rnType=ptr_new(/allocate_heap)
IF pr_or_dpr EQ 'DPR' THEN ptr_stmTopHgt=ptr_new(/allocate_heap)
ptr_bbProx=ptr_new(/allocate_heap)
ptr_hgtcat=ptr_new(/allocate_heap)
ptr_dist=ptr_new(/allocate_heap)
ptr_pctgoodpr=ptr_new(/allocate_heap)
ptr_pctgoodgv=ptr_new(/allocate_heap)
ptr_pctgoodrain=ptr_new(/allocate_heap)

; allocate pointers for DSD and GR rainrate fields
IF z2do EQ 'D0' THEN GRlabelAdd = '*1.05' ELSE GRlabelAdd = ''

ptr_GR_DP_Dzero=ptr_new(/allocate_heap)
; ptr_GR_DP_Dzeromax=ptr_new(/allocate_heap)
; ptr_GR_DP_Dzerostddev=ptr_new(/allocate_heap)
ptr_DprDm=ptr_new(/allocate_heap)
ptr_pctgooddzerogv=ptr_new(/allocate_heap)
ptr_pctgoodDprDm=ptr_new(/allocate_heap)

ptr_GR_DP_Dm=ptr_new(/allocate_heap)
; ptr_GR_DP_Dmmax=ptr_new(/allocate_heap)
; ptr_GR_DP_Dmstddev=ptr_new(/allocate_heap)
ptr_DprDm=ptr_new(/allocate_heap)
ptr_pctgooddmgv=ptr_new(/allocate_heap)
ptr_pctgoodDprDm=ptr_new(/allocate_heap)

ptr_GR_DP_Nw=ptr_new(/allocate_heap)
; ptr_GR_DP_Nwmax=ptr_new(/allocate_heap)
; ptr_GR_DP_Nwstddev=ptr_new(/allocate_heap)
ptr_DprNw=ptr_new(/allocate_heap)
ptr_pctgoodnwgv=ptr_new(/allocate_heap)
ptr_pctgoodDprNw =ptr_new(/allocate_heap)

ptr_GR_DP_N2=ptr_new(/allocate_heap)
; ptr_GR_DP_N2max=ptr_new(/allocate_heap)
; ptr_GR_DP_N2stddev=ptr_new(/allocate_heap)
ptr_DprNw=ptr_new(/allocate_heap)
ptr_pctgoodn2gv=ptr_new(/allocate_heap)
ptr_pctgoodDprNw =ptr_new(/allocate_heap)

; new for version 1.3 DPR file
IF pr_or_dpr EQ 'DPR' THEN BEGIN
   ptr_dprepsilon=ptr_new(/allocate_heap)
   ptr_pctgoodDprEpsilon =ptr_new(/allocate_heap)
   ptr_250maxzraw=ptr_new(/allocate_heap)
ENDIF

ptr_gvrr=ptr_new(/allocate_heap)
; ptr_gvrrmax=ptr_new(/allocate_heap)
; ptr_gvrrstddev=ptr_new(/allocate_heap)
ptr_pctgoodrrgv=ptr_new(/allocate_heap)

ptr_gvrc=ptr_new(/allocate_heap)
; ptr_gvrcmax=ptr_new(/allocate_heap)
; ptr_gvrcstddev=ptr_new(/allocate_heap)
ptr_pctgoodrcgv=ptr_new(/allocate_heap)

ptr_gvrp=ptr_new(/allocate_heap)
; ptr_gvrpmax=ptr_new(/allocate_heap)
; ptr_gvrpstddev=ptr_new(/allocate_heap)
ptr_pctgoodrpgv=ptr_new(/allocate_heap)

IF pr_or_dpr NE 'PR' THEN ptr_GR_blockage=ptr_new(/allocate_heap)

; structure to hold bright band variables
BBparms = {meanBB : -99.99, BB_HgtLo : -99, BB_HgtHi : -99}

; Define the list of fixed-height levels for the vertical profile statistics
heights = [1.5,3.0,4.5,6.0,7.5,9.0,10.5,12.0,13.5,15.0,16.5,18.0,19.5]
hgtinterval = 1.5
;heights = [1.0,2.0,3.0,4.0,5.0,6.0,7.0,8.0,9.0,10.0,11.0,12.0,13.0,14.0,15.0,16.0,17.0,18.0]
;hgtinterval = 1.0
nhgtcats = N_ELEMENTS(heights)

; set up to do BB-relative heights
IF keyword_set(bb_relative) THEN heights = heights-6.0

IF N_ELEMENTS(profile_save) NE 0 THEN BEGIN
   ; set up the array of pointers to the accumulated histograms.  6 permutations
   ; (3 rain type categories, for PR and GR) for N height levels.
   ; Order is PR any, PR Stratiform, PR Convective, GR Any, GR Stratiform, GR Convective
   accum_ptrs = PTRARR(6, nhgtcats, /allocate_heap)
   bindbz=1  ; Will be overwritten later with histogram LOCATIONS values
ENDIF

print, 'pctAbvThresh = ', pctAbvThresh

FOR fnum = 0, nf-1 DO BEGIN

   ncfilepr = prfiles(fnum)
   bname = file_basename( ncfilepr )
   dirname = file_dirname( ncfilepr )
   prlen = strlen( bname )
   print, "GeoMatch netCDF file: ", ncfilepr

   parsed = strsplit(bname, '.', /EXTRACT)
   site = parsed[1]
   orbit = parsed[3]
   orbitnum=LONG(orbit)
   version=parsed[4]

  ; get the satellite product type from the default file pattern
   IF parsed[0] EQ 'GRtoDPRGMI' THEN satprodtype = '2BDPRGMI' ELSE BEGIN
      type2A = parsed[5]
      CASE STRUPCASE(type2A) OF
        'DPR' :  satprodtype = '2ADPR'
         'KA' :  satprodtype = '2AKa'
         'KU' :  satprodtype = '2AKu'
         ELSE :  BEGIN
                   message, "Cannot figure out satellite product type.", /INFO
                   satprodtype = ''
                 END
      ENDCASE
   ENDELSE

; if minimum orbit number is specified, process newer orbits only
IF N_ELEMENTS(first_orbit) EQ 1 THEN BEGIN
   IF orbitnum LT first_orbit THEN BEGIN
      print, "Skip GeoMatch netCDF file: ", ncfilepr, " by orbit threshold."
      CONTINUE
   ENDIF ;ELSE print, "GeoMatch netCDF file: ", ncfilepr
ENDIF

; if both a min and a max orbit number are provided in an array, check that we are
; between the two values
IF N_ELEMENTS(first_orbit) EQ 2 THEN BEGIN
   IF orbitnum LT first_orbit[0] OR orbitnum GT first_orbit[1] THEN BEGIN
      print, "Skip GeoMatch netCDF file: ", ncfilepr, " by orbit threshold."
      CONTINUE
   ENDIF ;ELSE print, "GeoMatch netCDF file: ", ncfilepr
ENDIF

; also check that this file exists in the other version(s), if version2match is
; specified and differs from current version.  Ignore the "NAME_ADD" and '.gz' parts
; of the filenames to match and just match on site/date/orbit/version/version2match
nvers2match = N_ELEMENTS(version2match)
IF nvers2match NE 0 THEN BEGIN
   nmatch = 0
   ncpatt2match = parsed[0]+'.'+site+'.'+parsed[2]+'.'+orbit+'.'
   for ivers=0,nvers2match-1 do begin
      IF version NE version2match[ivers] THEN BEGIN
         command = 'echo '+dirname+" | sed 's/"+version+"/"+version2match[ivers]+"/g'"
         SPAWN, command, dir2match
         file2match = dir2match+'/'+ncpatt2match+version2match+'.*.nc*'
print, 'file2match: ', file2match 
         matches = FILE_SEARCH(file2match)
print, 'matches: ', matches 
         IF matches[0] NE '' THEN nmatch = nmatch + N_ELEMENTS(matches)
      ENDIF
   endfor
   IF nmatch EQ 0 THEN BEGIN
      print, "Skip ", version2match, " unmatched GeoMatch netCDF file: ", ncfilepr
      CONTINUE
   ENDIF
ENDIF

; skip duplicate orbit for given site
   IF ( site EQ lastsite AND orbitnum EQ lastorbitnum ) THEN BEGIN
      print, ""
      print, "Skipping duplicate site/orbit file ", bname, ", last file done was ", lastncfile
      CONTINUE
   ENDIF

; skip sites not in sitelist array, if supplied
   IF (N_ELEMENTS(sitelist) NE 0) THEN BEGIN
      IF KEYWORD_SET(exclude) THEN BEGIN
         IF WHERE( STRPOS(sitelist, site) NE -1 ) EQ -1 THEN BEGIN
            print, "Processing unexcluded site file ", bname
         ENDIF ELSE CONTINUE
      ENDIF ELSE BEGIN
         IF WHERE( STRPOS(sitelist, site) NE -1 ) EQ -1 THEN BEGIN
            print, "Skipping unmatched site file ", bname
            CONTINUE
         ENDIF
      ENDELSE
   ENDIF

; read the geometry-match variables and arrays from the file, and preprocess them
; to remove the 'bogus' PR ray positions.  Return a pointer to each variable read.

CASE pr_or_dpr OF
  'PR' : BEGIN
    PRINT, "INSTRUMENT: ", pr_or_dpr
    status = fprep_geo_match_profiles( ncfilepr, heights, $
       PCT_ABV_THRESH=pctAbvThresh, GV_CONVECTIVE=gvconvective, $
       GV_STRATIFORM=gvstratiform, S2KU=s2ku, PTRfieldflags=ptr_fieldflags, $
       PTRgeometa=ptr_geometa, PTRsweepmeta=ptr_sweepmeta, PTRsitemeta=ptr_sitemeta, $
       PTRGVZMEAN=ptr_gvz, PTRGVMAX=ptr_gvzmax, PTRGVSTDDEV=ptr_gvzstddev, $
       PTRzcor=ptr_zcor, PTRzraw=ptr_zraw, PTRrain3d=ptr_rain3, PTRpia=ptr_pia, $
       PTRsfcrainpr=ptr_nearSurfRain, PTRsfcraincomb=ptr_nearSurfRain_2b31, $
       PTRrainflag_int=ptr_rnFlag, PTRraintype_int=ptr_rnType, PTRbbProx=ptr_bbProx, $
       PTRhgtcat=ptr_hgtcat, PTRdist=ptr_dist, PTRpctgoodpr=ptr_pctgoodpr, $
       PTRpctgoodgv=ptr_pctgoodgv, PTRpctgoodrain=ptr_pctgoodrain, BBPARMS=BBparms, $
       BB_RELATIVE=bb_relative )
       have_SAT_DSD = 0   ; we don't have PR DSD parameters available
 END
  'DPR' : BEGIN
    PRINT, "INSTRUMENT: ", pr_or_dpr
    status = fprep_dpr_geo_match_profiles( ncfilepr, heights, $
       PCT_ABV_THRESH=pctAbvThresh, S2KU=s2ku, PTRfieldflags=ptr_fieldflags, $
       PTRgeometa=ptr_geometa, PTRsweepmeta=ptr_sweepmeta, PTRsitemeta=ptr_sitemeta, $
       PTRzcor=ptr_zcor, PTRzraw=ptr_zraw, PTRrain3d=ptr_rain3, PTRpia=ptr_pia, $
       PTRdprdm=ptr_dprDm, PTRdprnw=ptr_dprNw, PTRdprEpsilon=ptr_dprEpsilon, $
       PTRGVZMEAN=ptr_gvz, PTRGVMAX=ptr_gvzmax, PTRGVSTDDEV=ptr_gvzstddev, $
       PTRGVDZEROMEAN=ptr_GR_DP_Dzero, PTRGVDZEROMAX=ptr_GR_DP_Dzeromax, $
       PTRGVDZEROSTDDEV=ptr_GR_DP_Dzerostddev, $
       PTRGVDMMEAN=ptr_GR_DP_Dm, PTRGVDMMAX=ptr_GR_DP_Dmmax, $
       PTRGVDMSTDDEV=ptr_GR_DP_Dmstddev, $
       PTRGVNWMEAN=ptr_GR_DP_Nw, PTRGVNWMAX=ptr_GR_DP_Nwmax, $
       PTRGVNWSTDDEV=ptr_GR_DP_Nwstddev, $
       PTRGVN2MEAN=ptr_GR_DP_N2, PTRGVN2MAX=ptr_GR_DP_N2max, $
       PTRGVN2STDDEV=ptr_GR_DP_N2stddev, $
       PTRGVRRMEAN=ptr_gvrr, PTRGVRRMAX=ptr_gvrrmax, PTRGVRRSTDDEV=ptr_gvrrstddev,$
       PTRGVRCMEAN=ptr_gvrc, PTRGVRCMAX=ptr_gvrcmax, PTRGVRCSTDDEV=ptr_gvrcstddev, $
       PTRGVRPMEAN=ptr_gvrp, PTRGVRPMAX=ptr_gvrpmax, PTRGVRPSTDDEV=ptr_gvrpstddev, $
       PTRGVMODEHID=ptr_BestHID, $
       PTRGVZDRMEAN=ptr_GR_DP_Zdr, PTRGVZDRMAX=ptr_GR_DP_Zdrmax,$
       PTRGVZDRSTDDEV=ptr_GR_DP_Zdrstddev, $
       PTRGVKDPMEAN=ptr_GR_DP_Kdp, PTRGVKDPMAX=ptr_GR_DP_Kdpmax, $
       PTRGVKDPSTDDEV=ptr_GR_DP_Kdpstddev, $
       PTRGVRHOHVMEAN=ptr_GR_DP_RHOhv, PTRGVRHOHVMAX=ptr_GR_DP_RHOhvmax, $
       PTRGVRHOHVSTDDEV=ptr_GR_DP_RHOhvstddev, $
       PTRstmTopHgt=ptr_stmTopHgt, PTRGVBLOCKAGE=ptr_GR_blockage, $
       PTRsfcrainpr=ptr_nearSurfRain, PTRsfcraincomb=ptr_nearSurfRain_2b31, $
       PTRrainflag_int=ptr_rnFlag, PTRraintype_int=ptr_rnType, PTRbbProx=ptr_bbProx, $
       PTRhgtcat=ptr_hgtcat, PTRdist=ptr_dist,  $
       PTRpctgoodpr=ptr_pctgoodpr, PTRpctgoodrain=ptr_pctgoodrain, $
       PTRpctgood250pr=ptr_pctgood250pr, PTRpctgood250rawpr=ptr_pctgood250rawpr, $
       PTRpctgoodDprDm=ptr_pctgoodDprDm, PTRpctgoodDprNw=ptr_pctgoodDprNw, $
       PTRpctgoodDprEpsilon=ptr_pctgoodDprEpsilon, PTR250maxzraw=ptr_250maxzraw, $
       PTRpctgoodgv=ptr_pctgoodgv, PTRpctgoodrcgv=ptr_pctgoodrcgv, $
       PTRpctgoodrpgv=ptr_pctgoodrpgv, PTRpctgoodrrgv=ptr_pctgoodrrgv, $
       PTRpctgooddzerogv=ptr_pctgooddzerogv, PTRpctgooddmgv=ptr_pctgooddmgv, $
       PTRpctgoodnwgv=ptr_pctgoodnwgv, PTRpctgoodn2gv=ptr_pctgoodn2gv, $
       PTRpctgoodzdrgv=ptr_pctgoodzdrgv, PTRpctgoodkdpgv=ptr_pctgoodkdpgv, $
       PTRpctgoodrhohvgv=ptr_pctgoodrhohvgv, BBPARMS=BBparms, $
       BB_RELATIVE=bb_relative, ALT_BB_HGT=alt_bb_file, FORCEBB=forcebb)

       IF (status NE 1) THEN have_SAT_DSD = (*ptr_fieldflags).have_paramDSD   ; have DPR DSD parameters?
 END
  'DPRGMI' : BEGIN
    PRINT, "INSTRUMENT: ", pr_or_dpr
    status = fprep_dprgmi_geo_match_profiles( ncfilepr, heights, $
       KUKA=KuKa, SCANTYPE=swath, PCT_ABV_THRESH=pctAbvThresh, S2KU=s2ku, $
       PTRfieldflags=ptr_fieldflags, PTRgeometa=ptr_geometa, $
       PTRsweepmeta=ptr_sweepmeta, PTRsitemeta=ptr_sitemeta, $
       PTRzcor=ptr_zcor, PTRrain3d=ptr_rain3, PTRpia=ptr_pia, $
       PTRdprdm=ptr_dprDm, PTRdprnw=ptr_dprNw, $
       PTRGVZMEAN=ptr_gvz, PTRGVMAX=ptr_gvzmax, PTRGVSTDDEV=ptr_gvzstddev, $
       PTRGVDZEROMEAN=ptr_GR_DP_Dzero, PTRGVNWMEAN=ptr_GR_DP_Nw, $
       PTRGVDZEROMAX=ptr_GR_DP_Dzeromax, PTRGVDZEROSTDDEV=ptr_GR_DP_Dzerostddev, $
       PTRGVNWMAX=ptr_GR_DP_Nwmax, PTRGVNWSTDDEV=ptr_GR_DP_Nwstddev, $
       PTRGVDMMEAN=ptr_GR_DP_Dm, PTRGVDMMAX=ptr_GR_DP_Dmmax, $
       PTRGVDMSTDDEV=ptr_GR_DP_Dmstddev, PTRGVN2MEAN=ptr_GR_DP_N2, $
       PTRGVN2MAX=ptr_GR_DP_N2max, PTRGVN2STDDEV=ptr_GR_DP_N2stddev, $
       PTRGVRRMEAN=ptr_gvrr, PTRGVRRMAX=ptr_gvrrmax, PTRGVRRSTDDEV=ptr_gvrrstddev,$
       PTRGVRCMEAN=ptr_gvrc, PTRGVRCMAX=ptr_gvrcmax, PTRGVRCSTDDEV=ptr_gvrcstddev, $
       PTRGVRPMEAN=ptr_gvrp, PTRGVRPMAX=ptr_gvrpmax, PTRGVRPSTDDEV=ptr_gvrpstddev, $
       PTRGVBLOCKAGE=ptr_GR_blockage, $
       PTRtop=ptr_top, PTRbotm=ptr_botm, $
       PTRsfcrainpr=ptr_nearSurfRain, PTRraintype_int=ptr_rnType, $
       PTRxCorners=ptr_xCorner, PTRyCorners=ptr_yCorner, PTRbbProx=ptr_bbProx, $
       PTRhgtcat=ptr_hgtcat, PTRdist=ptr_dist, PTRpridx_long=ptr_pr_index, $
       PTRpctgoodpr=ptr_pctgoodpr, PTRpctgoodgv=ptr_pctgoodgv, $
       PTRpctgoodrain=ptr_pctgoodrain, PTRpctgoodrcgv=ptr_pctgoodrcgv, $
       PTRpctgoodrpgv=ptr_pctgoodrpgv, PTRpctgoodrrgv=ptr_pctgoodrrgv, $
       PTRpctgoodDprDm=ptr_pctgoodDprDm, PTRpctgoodDprNw=ptr_pctgoodDprNw, $
       PTRpctgooddzerogv=ptr_pctgooddzerogv, PTRpctgoodnwgv=ptr_pctgoodnwgv, $
       PTRpctgooddmgv=ptr_pctgooddmgv, PTRpctgoodn2gv=ptr_pctgoodn2gv, $
       BBPARMS=BBparms, BB_RELATIVE=bb_relative, ALT_BB_HGT=alt_bb_file, FORCEBB=forcebb )

       have_SAT_DSD = 1   ; we always have DPRGMI DSD parameters
 END
ENDCASE

print, ''
IF (status EQ 1) THEN GOTO, nextFile
IF ( s2ku ) THEN BEGIN
   IF BBparms.meanbb LT 0.0 THEN BEGIN
      print, 'S2Ku set but no BB defined, skipping case for ', ncfilepr
      GOTO, nextFile
   ENDIF
ENDIF

; memory-pass pointer variables to "normal-named" data field arrays/structures
; -- this is so we can use existing code without the need to use pointer
;    dereferencing syntax
   mygeometa=temporary(*ptr_geometa)
   mysite=temporary(*ptr_sitemeta)
   mysweeps=temporary(*ptr_sweepmeta)
   myflags=temporary(*ptr_fieldflags)
   gvz=temporary(*ptr_gvz)
   gvzmax=*ptr_gvzmax
   gvzstddev=*ptr_gvzstddev
  ; DPRGMI does not have Zmeasured (zraw), so just copy Zcorrected to define it
   IF pr_or_dpr EQ 'DPRGMI' THEN zraw=*ptr_zcor ELSE zraw=temporary(*ptr_zraw)
   zcor=temporary(*ptr_zcor)
   IF pr_or_dpr EQ 'DPR' THEN echoTops=temporary(*ptr_stmTopHgt)
   PIA=temporary(*ptr_pia)
   nearSurfRain=temporary(*ptr_nearSurfRain)
   nearSurfRain_2b31=temporary(*ptr_nearSurfRain_2b31)
;   rnflag=temporary(*ptr_rnFlag)
   rntype=temporary(*ptr_rnType)
   bbProx=temporary(*ptr_bbProx)
   hgtcat=temporary(*ptr_hgtcat)
   dist=temporary(*ptr_dist)
   pctgoodpr=temporary(*ptr_pctgoodpr)
   pctgoodgv=temporary(*ptr_pctgoodgv)

  ; here's an example of how to address a "data presence" flag value in the
  ; 'have_hist' structure when the z2do value is a STRING (MUST BE IN ALL CAPS)
   have_hist.(WHERE(STRMATCH(PlotTypes, 'ZM') Eq 1))[haveVar,*] = 1
  ; here's an example of how to address a "data presence" flag value in the
  ; 'have_hist' structure using the PlotHash object (defined case-sensitive)
   have_hist.(PlotHash('ZC'))[haveVar,*] = 1
  ; here is the simple way when you already know the structure tag
  ; have_hist.Zc[haveVar,*] = 1

; dereference pointers for fields into common-named variables
have_altfield=1   ; initialize as if we have an alternate field to process
;    ELSE : have_altfield=0   ; only doing boring old Z

IF have_SAT_DSD EQ 1 THEN BEGIN
              DPR_Dm=temporary(*ptr_DprDm)
              pctgoodDPR_Dm=temporary(*ptr_pctgoodDprDm)
              DPR_Nw=temporary(*ptr_DprNw/NW_SCALE)      ; dBNw -> log10(Nw)
              pctgoodDPR_NW=temporary(*ptr_pctgoodDprNw )
ENDIF

IF ptr_valid(ptr_dprEpsilon) AND ptr_valid(ptr_pctgooddprEpsilon) THEN BEGIN
   dprEpsilon=temporary(*ptr_dprEpsilon)
   pctgoodDPR_Epsilon=temporary(*ptr_pctgoodDprEpsilon )
   have_DprEpsilon = 1
ENDIF ELSE have_DprEpsilon = 0

; the fprep routine will free ptr_250maxzraw if this variable is not available
; in the matchup file version being processed, so it won't be valid in that case
IF ptr_valid(ptr_250maxzraw) THEN BEGIN
   maxraw250=temporary(*ptr_250maxzraw)
   have_maxraw250 = 1
ENDIF ELSE BEGIN
   have_maxraw250 = 0
  ; if we are only plotting the GR Nw vs. DPR ZmMax, then we're out of luck
   IF z2do EQ 'NwGZmxP' THEN BEGIN
     message, "Cannot process ALTFIELD '" + altfield + $
              "', no ZmMax250 field present.", /INFO
     GOTO, cleanUp   ; free the pointers before quitting
   ENDIF
ENDELSE

IF myflags.have_GR_Dzero EQ 1 and have_SAT_DSD EQ 1 THEN BEGIN
              have_D0 = 1
              have_hist.D0[haveVar,*] = 1
              GR_D0=temporary(*ptr_GR_DP_Dzero)
;              GR_D0max=temporary(*ptr_GR_DP_Dzeromax)
;              GR_D0stddev=temporary(*ptr_GR_DP_Dzerostddev)
              DPR_D0=Dpr_Dm
              pctgoodGR_D0=temporary(*ptr_pctgooddzerogv)
              pctgoodDPR_D0=pctgoodDPR_Dm
             ; adjust GR D0 to Dm for comparison to DPR Dm
              idxD0pos = WHERE( GR_D0 GT 0.0, countD0pos )
              if countD0pos gt 0 then begin
;                 print, '' 
;                 print, "Adjusting GR Dzero to Dm by factor of 1.05."
;                 print, '' 
                 GR_D0[idxD0pos] = GR_D0[idxD0pos]*1.05
;                 GR_D0max[idxD0pos] = GR_D0max[idxD0pos]*1.05
              endif
ENDIF ELSE have_D0 = 0

IF myflags.have_GR_Dm EQ 1 and have_SAT_DSD EQ 1 THEN BEGIN
              have_Dm = 1
              have_hist.Dm[haveVar,*] = 1
              have_hist.DmAny[haveVar,*] = 1
              GR_Dm=temporary(*ptr_GR_DP_Dm)
;              GR_Dmmax=temporary(*ptr_GR_DP_Dmmax)
;              GR_Dmstddev=temporary(*ptr_GR_DP_Dmstddev)
              pctgoodGR_Dm=temporary(*ptr_pctgooddmgv)
ENDIF ELSE have_Dm = 0

IF myflags.have_GR_Nw EQ 1 and have_SAT_DSD EQ 1 THEN BEGIN
              have_Nw = 1
              have_hist.Nw[haveVar,*] = 1
              GR_Nw=temporary(*ptr_GR_DP_Nw)
;              GR_Nwmax=temporary(*ptr_GR_DP_Nwmax)
;              GR_Nwstddev=temporary(*ptr_GR_DP_Nwstddev)
              pctgoodGR_Nw=temporary(*ptr_pctgoodnwgv)
ENDIF ELSE have_Nw = 0

IF myflags.have_GR_N2 EQ 1 and have_SAT_DSD EQ 1 THEN BEGIN
              have_N2 = 1
              have_hist.N2[haveVar,*] = 1
              GR_N2=temporary(*ptr_GR_DP_N2)
;              GR_N2max=temporary(*ptr_GR_DP_N2max)
;              GR_N2stddev=temporary(*ptr_GR_DP_N2stddev)
              DPR_N2=Dpr_Nw
              pctgoodGR_N2=temporary(*ptr_pctgoodn2gv)
              pctgoodDPR_N2=pctgoodDPR_NW
ENDIF ELSE have_N2 = 0

DPR_RR=temporary(*ptr_rain3)
pctgoodDPR_RR=temporary(*ptr_pctgoodrain)

IF myflags.have_GR_RR_rainrate EQ 1 THEN BEGIN
              have_RR = 1
              have_hist.RR[haveVar,*] = 1
              GR_RR=temporary(*ptr_gvrr)
;              GR_RRmax=temporary(*ptr_gvrrmax)
;              GR_RRstddev=temporary(*ptr_gvrrstddev)
              pctgoodGR_RR=temporary(*ptr_pctgoodrrgv)
ENDIF ELSE have_RR = 0

IF myflags.have_GR_RC_rainrate EQ 1 THEN BEGIN
              have_RC = 1
              have_hist.RC[haveVar,*] = 1
              GR_RC=temporary(*ptr_gvrc)
;              GR_RCmax=temporary(*ptr_gvrcmax)
;              GR_RCstddev=temporary(*ptr_gvrcstddev)
              DPR_RC=DPR_RR
              pctgoodGR_RC=temporary(*ptr_pctgoodrcgv)
              pctgoodDPR_RC=pctgoodDPR_RR
ENDIF ELSE have_RC = 0

IF myflags.have_GR_RP_rainrate EQ 1 THEN BEGIN
              have_RP = 1
              have_hist.RP[haveVar,*] = 1
              GR_RP=temporary(*ptr_gvrp)
;              GR_RPmax=temporary(*ptr_gvrpmax)
;              GR_RPstddev=temporary(*ptr_gvrpstddev)
              DPR_RP=DPR_RR
              pctgoodGR_RP=temporary(*ptr_pctgoodrpgv)
              pctgoodDPR_RP=pctgoodDPR_RR
ENDIF ELSE have_RP = 0

; set up the data presence flags for the two-parameter plots
IF have_NW THEN BEGIN
  have_hist.ZcNwG[haveVar,*] = 1
  IF have_DM THEN have_hist.NwDmG[haveVar,*] = 1
  IF have_RR THEN have_hist.RRNwG[haveVar,*] = 1
ENDIF

IF have_RR AND have_DM THEN BEGIN
   have_hist.EPSI[haveVar,*] = 1
   have_hist.DmRRG[haveVar,*] = 1
ENDIF

IF have_SAT_DSD EQ 1 THEN BEGIN
  have_hist.ZcNwP[haveVar,*] = 1
  have_hist.NwDmP[haveVar,*] = 1
  have_hist.DmRRP[haveVar,*] = 1
  have_hist.RRNwP[haveVar,*] = 1
  have_hist.PIADMP[haveVar,*] = 1
ENDIF

IF have_NW AND have_maxraw250 THEN BEGIN
  have_hist.NWGZMXP[haveVar,*] = 1
ENDIF

  do_GR_blockage = 0
  IF pr_or_dpr NE 'PR' AND ptr_valid(ptr_GR_blockage) THEN BEGIN
     do_GR_blockage=myflags.have_GR_blockage   ; should just be 0 for version<1.21
     GR_blockage=temporary(*ptr_GR_blockage)
  ENDIF ELSE GR_blockage = -1

 ; reset do_GR_blockage flag if set but no MAX_BLOCKAGE value is given
  IF do_GR_blockage EQ 1 AND N_ELEMENTS(max_blockage) NE 1 $
     THEN do_GR_blockage = 0
  ;help, GR_blockage, do_GR_blockage

; if do_GR_blockage flag is not set, account for the presence of the
; Z_BLOCKAGE_THRESH value and set it to the alternate method if indicated
;z_blockage_thresh=3  ; uncomment for testing
IF do_GR_blockage EQ 0 AND N_ELEMENTS(z_blockage_thresh) EQ 1 $
   THEN do_GR_blockage = 2

; don't have a keyword parameter for this yet, just set a default
blockfilter = 'C'    ; initialize blockage filter to "by Column"

; extract some needed values from the metadata structures
   site_lat = mysite.site_lat
   site_lon = mysite.site_lon
   siteID = string(mysite.site_id)
   nsweeps = mygeometa.num_sweeps

;=========================================================================

; Optional data clipping based on percent completeness of the volume averages:

; Decide which PR and GV points to include, based on percent of expected points
; in bin-averaged results that were above dBZ thresholds set when the matchups
; were done.  If unspecified or set to zero, include all points regardless of
; 'completeness' of the volume averages, as long as there was at least one valid
; gate value in the sample average.  If a max_blockage was specified and the data
; have blockage values, then only include those samples that meet both the
; blockage and percent criteria.

  ; find the least pct abv thresh from among all variables involved in processing
  ; -- always include GR and DPR Z
;   IF ( have_altfield EQ 1 ) THEN BEGIN
;      minpctcombined = ( ((pctgoodpr<pctgoodgv) < altpctgoodGR) < altpctgoodDPR )
;   ENDIF ELSE BEGIN
      minpctcombined = pctgoodpr < pctgoodgv
;   ENDELSE

;-------------------------------------------------

; identify GR-beam-blocked samples if a method is active

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
   endif
ENDIF ELSE BEGIN
   print, ''
   print, 'No filtering by GR blockage.'
ENDELSE

;-------------------------------------------------

   ; also skip over any profiles that don't have DPR Dm values at/above 2.5 mm

   idxDmBig = INTARR( SIZE(DPR_Dm, /DIMENSIONS) )   ; flag array for profiles
   ; find all samples with DPR Dm GE 2.5
   idxdmdprgt25= WHERE(DPR_Dm GE 2.5, ndmdprgt25)
   ; set flag array to 1 for these samples
   idxDmBig[idxdmdprgt25] = 1
   ; flag whether or not each **profile** has a value of DPR Dm GE 2.5
   dmProfilesGE25 = MAX(idxDmBig, DIMENSION=2)    ; max along column, either 1 or 0
   ; tag all samples along profile with this flag
   for iswplev=0,nsweeps-1 do begin
       idxDmBig[*,iswplev] = dmProfilesGE25
   endfor

   IF ( do_GR_blockage NE 0) THEN BEGIN
     ; define an array that flags samples that exceed the max blockage threshold
      unblocked = pctgoodpr < pctgoodgv
;      idxBlocked = idxblok
      countblock = countblok
     ; set blocked sample to a negative value to exclude them in clipping
      IF countblock GT 0 THEN BEGIN
         idxBlocked = idxblok
         unblocked[idxBlocked] = -66.6
      ENDIF
      IF ( pctAbvThreshF GT 0.0 ) THEN BEGIN
         print, 'Clipping by PercentAboveThreshold, DPR_Dm GE 2.5, and blockages.'
        ; clip to the 'good' points, where 'pctAbvThreshF' fraction of bins in average
        ; were above threshold AND blockage is below max allowed
         idxgoodenuff = WHERE( minpctcombined GE pctAbvThreshF $
                          AND  idxDmBig EQ 1 and unblocked GT 0.0, countgoodpct )
      ENDIF ELSE BEGIN
         print, 'Clipping by idxDmBig EQ 1 and blockages.'
         idxgoodenuff = WHERE( minpctcombined GT 0.0 $
                          AND  idxDmBig EQ 1 and unblocked GT 0.0, countgoodpct )
      ENDELSE
   ENDIF ELSE BEGIN
      IF ( pctAbvThreshF GT 0.0 ) THEN BEGIN
         print, 'Clipping by PercentAboveThreshold and DPR_Dm GE 2.5.'
        ; clip to the 'good' points, where 'pctAbvThreshF' fraction of bins in average
        ; were above threshold
         idxgoodenuff = WHERE( minpctcombined GE pctAbvThreshF $
                          AND  idxDmBig EQ 1, countgoodpct )
      ENDIF ELSE BEGIN
         idxgoodenuff = WHERE( minpctcombined GT 0.0 $
                          AND  idxDmBig EQ 1, countgoodpct )
      ENDELSE
   ENDELSE

      IF ( countgoodpct GT 0 ) THEN BEGIN
          gvz = gvz[idxgoodenuff]
          zraw = zraw[idxgoodenuff]
          zcor = zcor[idxgoodenuff]
;          rain3 = rain3[idxgoodenuff]
          PIA = PIA[idxgoodenuff]
          gvzmax = gvzmax[idxgoodenuff]
          gvzstddev = gvzstddev[idxgoodenuff]
;          rnFlag = rnFlag[idxgoodenuff]
          rnType = rnType[idxgoodenuff]
          dist = dist[idxgoodenuff]
          bbProx = bbProx[idxgoodenuff]
          hgtcat = hgtcat[idxgoodenuff]
          IF have_DprEpsilon EQ 1 THEN BEGIN
             dprEpsilon = dprEpsilon[idxgoodenuff]
             pctgoodDPR_Epsilon = pctgoodDPR_Epsilon[idxgoodenuff]
          ENDIF
          IF have_D0 EQ 1 THEN BEGIN
              GR_D0=GR_D0[idxgoodenuff]
;              GR_D0max=GR_D0max[idxgoodenuff]
;              GR_D0stddev=GR_D0stddev[idxgoodenuff]
              DPR_D0=DPR_D0[idxgoodenuff]
              pctgoodGR_D0=pctgoodGR_D0[idxgoodenuff]
              pctgoodDPR_D0=pctgoodDPR_D0[idxgoodenuff]
          ENDIF
          IF have_Dm EQ 1 THEN BEGIN
              GR_Dm=GR_Dm[idxgoodenuff]
;              GR_Dmmax=GR_Dmmax[idxgoodenuff]
;              GR_Dmstddev=GR_Dmstddev[idxgoodenuff]
              pctgoodGR_Dm=pctgoodGR_Dm[idxgoodenuff]
              DPR_Dm=DPR_Dm[idxgoodenuff]
              pctgoodDPR_Dm=pctgoodDPR_Dm[idxgoodenuff]
          ENDIF
          IF have_Nw EQ 1 THEN BEGIN
              GR_Nw=GR_Nw[idxgoodenuff]
;              GR_Nwmax=GR_Nwmax[idxgoodenuff]
;              GR_Nwstddev=GR_Nwstddev[idxgoodenuff]
              pctgoodGR_Nw=pctgoodGR_Nw[idxgoodenuff]
              DPR_Nw=DPR_Nw[idxgoodenuff]
              pctgoodDPR_Nw=pctgoodDPR_Nw[idxgoodenuff]
          ENDIF
          IF have_N2 EQ 1 THEN BEGIN
              GR_N2=GR_N2[idxgoodenuff]
;              GR_N2max=GR_N2max[idxgoodenuff]
;              GR_N2stddev=GR_N2stddev[idxgoodenuff]
              DPR_N2=DPR_N2[idxgoodenuff]
              pctgoodGR_N2=pctgoodGR_N2[idxgoodenuff]
              pctgoodDPR_N2=pctgoodDPR_N2[idxgoodenuff]
          ENDIF
          IF have_RR EQ 1 THEN BEGIN
              GR_RR=GR_RR[idxgoodenuff]
;              GR_RRmax=GR_RRmax[idxgoodenuff]
;              GR_RRstddev=GR_RRstddev[idxgoodenuff]
              pctgoodGR_RR=pctgoodGR_RR[idxgoodenuff]
              DPR_RR=DPR_RR[idxgoodenuff]
              pctgoodDPR_RR=pctgoodDPR_RR[idxgoodenuff]
          ENDIF
          IF have_RC EQ 1 THEN BEGIN
              GR_RC=GR_RC[idxgoodenuff]
;              GR_RCmax=GR_RCmax[idxgoodenuff]
;              GR_RCstddev=GR_RCstddev[idxgoodenuff]
              DPR_RC=DPR_RC[idxgoodenuff]
              pctgoodGR_RC=pctgoodGR_RC[idxgoodenuff]
              pctgoodDPR_RC=pctgoodDPR_RC[idxgoodenuff]
          ENDIF
          IF have_RP EQ 1 THEN BEGIN
              GR_RP=GR_RP[idxgoodenuff]
;              GR_RPmax=GR_RPmax[idxgoodenuff]
;              GR_RPstddev=GR_RPstddev[idxgoodenuff]
              DPR_RP=DPR_RP[idxgoodenuff]
              pctgoodGR_RP=pctgoodGR_RP[idxgoodenuff]
              pctgoodDPR_RP=pctgoodDPR_RP[idxgoodenuff]
          ENDIF
          IF have_maxraw250 EQ 1 THEN maxraw250=maxraw250[idxgoodenuff]
      ENDIF ELSE BEGIN
          print, "No complete-volume points, quitting case."
          goto, nextFile
      ENDELSE

;-------------------------------------------------------------

; Optional data clipping based on echo top height (stormTopHeight) range:
; Limit which PR and GV points to include, based on ET height
   IF N_ELEMENTS( et_range_m ) EQ 2 THEN BEGIN
      print, 'Clipping by echo top height.'
     ; define index array that flags samples within the ET range
      idxgoodenuff = WHERE(echoTops GE et_range_m[0] $
                       AND echoTops LE et_range_m[1], countET)
      IF (countET GT 0) THEN BEGIN
          gvz = gvz[idxgoodenuff]
          zraw = zraw[idxgoodenuff]
          zcor = zcor[idxgoodenuff]
;          rain3 = rain3[idxgoodenuff]
          PIA = PIA[idxgoodenuff]
          gvzmax = gvzmax[idxgoodenuff]
          gvzstddev = gvzstddev[idxgoodenuff]
;          rnFlag = rnFlag[idxgoodenuff]
          rnType = rnType[idxgoodenuff]
          dist = dist[idxgoodenuff]
          bbProx = bbProx[idxgoodenuff]
          hgtcat = hgtcat[idxgoodenuff]
          IF have_DprEpsilon EQ 1 THEN BEGIN
             dprEpsilon = dprEpsilon[idxgoodenuff]
             pctgoodDPR_Epsilon = pctgoodDPR_Epsilon[idxgoodenuff]
          ENDIF
          IF have_D0 EQ 1 THEN BEGIN
              GR_D0=GR_D0[idxgoodenuff]
;              GR_D0max=GR_D0max[idxgoodenuff]
;              GR_D0stddev=GR_D0stddev[idxgoodenuff]
              DPR_D0=DPR_D0[idxgoodenuff]
              pctgoodGR_D0=pctgoodGR_D0[idxgoodenuff]
              pctgoodDPR_D0=pctgoodDPR_D0[idxgoodenuff]
          ENDIF
          IF have_Dm EQ 1 THEN BEGIN
              GR_Dm=GR_Dm[idxgoodenuff]
;              GR_Dmmax=GR_Dmmax[idxgoodenuff]
;              GR_Dmstddev=GR_Dmstddev[idxgoodenuff]
              pctgoodGR_Dm=pctgoodGR_Dm[idxgoodenuff]
              DPR_Dm=DPR_Dm[idxgoodenuff]
              pctgoodDPR_Dm=pctgoodDPR_Dm[idxgoodenuff]
          ENDIF
          IF have_Nw EQ 1 THEN BEGIN
              GR_Nw=GR_Nw[idxgoodenuff]
;              GR_Nwmax=GR_Nwmax[idxgoodenuff]
;              GR_Nwstddev=GR_Nwstddev[idxgoodenuff]
              pctgoodGR_Nw=pctgoodGR_Nw[idxgoodenuff]
              DPR_Nw=DPR_Nw[idxgoodenuff]
              pctgoodDPR_Nw=pctgoodDPR_Nw[idxgoodenuff]
          ENDIF
          IF have_N2 EQ 1 THEN BEGIN
              GR_N2=GR_N2[idxgoodenuff]
;              GR_N2max=GR_N2max[idxgoodenuff]
;              GR_N2stddev=GR_N2stddev[idxgoodenuff]
              DPR_N2=DPR_N2[idxgoodenuff]
              pctgoodGR_N2=pctgoodGR_N2[idxgoodenuff]
              pctgoodDPR_N2=pctgoodDPR_N2[idxgoodenuff]
          ENDIF
          IF have_RR EQ 1 THEN BEGIN
              GR_RR=GR_RR[idxgoodenuff]
;              GR_RRmax=GR_RRmax[idxgoodenuff]
;              GR_RRstddev=GR_RRstddev[idxgoodenuff]
              pctgoodGR_RR=pctgoodGR_RR[idxgoodenuff]
              DPR_RR=DPR_RR[idxgoodenuff]
              pctgoodDPR_RR=pctgoodDPR_RR[idxgoodenuff]
          ENDIF
          IF have_RC EQ 1 THEN BEGIN
              GR_RC=GR_RC[idxgoodenuff]
;              GR_RCmax=GR_RCmax[idxgoodenuff]
;              GR_RCstddev=GR_RCstddev[idxgoodenuff]
              DPR_RC=DPR_RC[idxgoodenuff]
              pctgoodGR_RC=pctgoodGR_RC[idxgoodenuff]
              pctgoodDPR_RC=pctgoodDPR_RC[idxgoodenuff]
          ENDIF
          IF have_RP EQ 1 THEN BEGIN
              GR_RP=GR_RP[idxgoodenuff]
;              GR_RPmax=GR_RPmax[idxgoodenuff]
;              GR_RPstddev=GR_RPstddev[idxgoodenuff]
              DPR_RP=DPR_RP[idxgoodenuff]
              pctgoodGR_RP=pctgoodGR_RP[idxgoodenuff]
              pctgoodDPR_RP=pctgoodDPR_RP[idxgoodenuff]
          ENDIF
          IF have_maxraw250 EQ 1 THEN maxraw250=maxraw250[idxgoodenuff]
      ENDIF ELSE BEGIN
          print, "No points within echo top range, skipping case."
          print, ''
          goto, nextFile
      ENDELSE
   ENDIF

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
              ; also adjust gvzmax field
               idx_z2adj=WHERE(gvzmax GT absbias, count2adj)
               IF count2adj GT 0 THEN gvzmax[idx_z2adj] = gvzmax[idx_z2adj]+grbias
               idx_z2adj=WHERE(gvzmax GT 0.0 AND gvzmax LE absbias, count2adj)
               IF count2adj GT 0 THEN gvzmax[idx_z2adj] = 0.0
            ENDIF ELSE BEGIN
              ; upward-adjust GR Z values that are above 0.0 dBZ only
               idx_z2adj=WHERE(gvz GT 0.0, count2adj)
               IF count2adj GT 0 THEN gvz[idx_z2adj] = gvz[idx_z2adj]+grbias
              ; also adjust gvzmax field
               idx_z2adj=WHERE(gvzmax GT 0.0, count2adj)
               IF count2adj GT 0 THEN gvzmax[idx_z2adj] = gvzmax[idx_z2adj]+grbias
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
           ; also adjust Zmeas field
            idx_z2adj=WHERE(zraw GT absbias, count2adj)
            IF count2adj GT 0 THEN zraw[idx_z2adj] = zraw[idx_z2adj]+dpr_z_adjust
            idx_z2adj=WHERE(zraw GT 0.0 AND zraw LE absbias, count2adj)
            IF count2adj GT 0 THEN zraw[idx_z2adj] = 0.0
         ENDIF ELSE BEGIN
           ; upward-adjust Zc values that are above 0.0 dBZ only
            idx_z2adj=WHERE(zcor GT 0.0, count2adj)
            IF count2adj GT 0 THEN zcor[idx_z2adj] = zcor[idx_z2adj]+dpr_z_adjust
           ; also adjust Zmeas field
            idx_z2adj=WHERE(zraw GT 0.0, count2adj)
            IF count2adj GT 0 THEN zraw[idx_z2adj] = zraw[idx_z2adj]+dpr_z_adjust
         ENDELSE
      ENDIF ELSE print, "Ignoring negligible DPR Z bias value."
   ENDIF

;-------------------------------------------------------------

; build an array of BB proximity: 0 if below, 1 if within, 2 if above
;#######################################################################################
; NOTE THESE CATEGORY NUMBERS ARE ONE LOWER THAN THOSE IN FPREP_GEO_MATCH_PROFILES() !!
;#######################################################################################
   BBprox = BBprox - 1

;-------------------------------------------------------------

  ; compute mean bias stratiform/aboveBB weighted by # samples
   IF do_scatr THEN BEGIN
      idx4bias = WHERE(BBprox EQ 2 AND rnType EQ RainType_stratiform, countbias)
      IF countbias GT 0 THEN BEGIN
         biasAccum = biasAccum + MEAN(gvz[idx4bias]-zcor[idx4bias]) * countbias
         nbiasAccum = nbiasAccum + countbias
      ENDIF
   ENDIF

; build an array of range categories from the GV radar, using ranges previously
; computed from lat and lon by fprep_geo_match_profiles():
; - range categories: 0 for 0<=r<50, 1 for 50<=r<100, 2 for r>=100, etc.
;   (for now we only have points roughly inside 100km, so limit to 2 categs.)
   distcat = ( FIX(dist) / 50 ) < 1

  ; Compute selected field statistics at each level
   for lev2get = 0, nhgtcats-1 do begin
      hgtstr =  string(heights[lev2get], FORMAT='(f0.1)')
      idxathgt = where(hgtcat EQ lev2get, counthgts)
      if ( counthgts GT 0 ) THEN BEGIN
         print, "HEIGHT = "+hgtstr+" km: npts = ", counthgts
        ; grab the subset of points at this height level
;         IF ( have_altfield EQ 1 ) THEN BEGIN
;            dbznexlev = altGR[idxathgt]
;            gvzmaxlev = altGRmax[idxathgt]
;            gvzstddevlev = altGRstddev[idxathgt]
;            dbzDPRlev = altDPR[idxathgt]
;         ENDIF ELSE BEGIN
            IF (use_zraw) THEN dbzDPRlev = zraw[idxathgt] $
               ELSE dbzDPRlev = zcor[idxathgt]
            dbznexlev = gvz[idxathgt]
            gvzmaxlev = gvzmax[idxathgt]
            gvzstddevlev = gvzstddev[idxathgt]
;         ENDELSE

         raintypelev = rntype[idxathgt]
         distcatlev = distcat[idxathgt]
         BBproxlev = BBprox[idxathgt]

         IF N_ELEMENTS(profile_save) NE 0 THEN $
            ; accumulate PR and GR dBZ histograms by rain type at this level
            accum_histograms_by_raintype, dbzDPRlev, dbznexlev, raintypelev, $
                                          accum_ptrs, lev2get, bindbz
      ENDIF
   endfor

  ;# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

   IF do_scatr EQ 1 THEN BEGIN
   FOR iplot = 0, nPlots-1 DO BEGIN
   for raintypeBBidx = 0, 1 do begin
     ; set up the indices of the samples to include in the scatter plots
      SWITCH PlotTypes(iplot) OF
       'ZM' : 
       'ZC' : BEGIN
                ; accumulate 2-D histogram of stratiform, above-BB reflectivity,
                ; unless 'raintypeBBidx' is 1, then do convective below BB
                 IF raintypeBBidx EQ 1 THEN BEGIN
                    idxabv = WHERE( BBprox EQ 0 AND rntype EQ RainType_convective, countabv )
                    raintypeBBidx = 1
                 ENDIF ELSE BEGIN
                    idxabv = WHERE( BBprox EQ 2 AND rntype EQ RainType_stratiform, countabv )
                    raintypeBBidx = 0
                 ENDELSE
                 BREAK
              END
     'DMANY': BEGIN
                ; accumulate 2-D histogram of below-BB Dm
                 IF raintypeBBidx EQ 1 THEN BEGIN
                    idxabv = WHERE( BBprox EQ 0 AND hgtcat LE 1, countabv )
                    raintypeBBidx = 1
                 ENDIF ELSE BEGIN
                    idxabv = WHERE( BBprox EQ 0 AND hgtcat LE 1, countabv )
                    raintypeBBidx = 0
                 ENDELSE
                 BREAK
              END
       ELSE : BEGIN
                ; accumulate 2-D histogram of stratiform, below-BB Dm/D0/Nw/N2/Rx
                ; at/below 3 km, unless 'raintypeBBidx' is 1, then do convective
                ; below BB
                 IF raintypeBBidx EQ 1 THEN BEGIN
                    idxabv = WHERE( BBprox EQ 0 AND rntype EQ RainType_convective $
                                    AND hgtcat LE 1, countabv )
                    raintypeBBidx = 1
                 ENDIF ELSE BEGIN
                    idxabv = WHERE( BBprox EQ 0 AND rntype EQ RainType_stratiform $
                                    AND hgtcat LE 1, countabv )
                    raintypeBBidx = 0
                 ENDELSE
              END
      ENDSWITCH

     ; set up histogram parameters by plot type
      SWITCH PlotTypes(iplot) OF
       'DMANY' :
       'D0' : 
       'DM' : BEGIN
                 binmin1 = 0.0 & binmax1 = 4.0 & BINSPAN1 = 0.1
                 binmin2 = 0.0 & binmax2 = 4.0 & BINSPAN2 = 0.1
                 BREAK
               END
       'N2' : 
       'NW' : BEGIN
                binmin1 = 2.0 & binmax1 = 6.0 & BINSPAN1 = 0.1
                binmin2 = 2.0 & binmax2 = 6.0 & BINSPAN2 = 0.1
                BREAK
              END
       'RC' : 
       'RP' : 
       'RR' : BEGIN
                 binmin1 = 0.0  & binmin2 = 0.0
                 binmax1 = 15.0 & binmax2 = 15.0
                 BINSPAN1 = 0.25
                 BINSPAN2 = 0.25
                 BREAK
              END
    'ZCNWP' : 
    'ZCNWG' : BEGIN
                ; accumulate 2-D histogram of reflectivity vs. Nw
                 IF raintypeBBidx EQ 1 THEN BEGIN
                    binmin1 = 2.0 & binmin2 = 20.0
                    binmax1 = 6.0 & binmax2 = 60.0
                 ENDIF ELSE BEGIN
                    binmin1 = 2.0 & binmin2 = 15.0
                    binmax1 = 6.0 & binmax2 = 55.0
                 ENDELSE
                 BINSPAN1 = 0.1
                 BINSPAN2 = 1.0
                 BREAK
              END
    'NWDMP' : 
    'NWDMG' : BEGIN
                ; accumulate 2-D histogram of GR Nw vs. Dm
                 binmin1 = 0.0 & binmin2 = 2.0
                 binmax1 = 4.0 & binmax2 = 6.0
                 BINSPAN1 = 0.1 & BINSPAN2 = 0.1
                 BREAK
              END
    'DMRRG' : 
    'DMRRP' : BEGIN
                ; accumulate 2-D histogram of DPR Dm vs. RR
                ; - Need to have about the same # bins in both RR and Dm
                ;   i.e., (binmax-binmin)/BINSPAN

                ; RR histo parms
                 binmin1 = 0.0 & binmax1 = 15.0
                 BINSPAN1 = 0.3

                ; Dm histo parms
                 binmin2 = 0.0 & binmax2 = 4.0 & BINSPAN2 = 0.1
                 BREAK
              END
    'RRNWG' : 
    'RRNWP' : BEGIN
                ; - Need to have about the same # bins in both RR and Nw
                ;   i.e., (binmax-binmin)/BINSPAN

                ; Nw histo parms
                 binmin1 = 2.0 & binmax1 = 6.0 & BINSPAN1 = 0.1

                ; RR histo parms
                 binmin2 = 0.0 & binmax2 = 15.0
                 BINSPAN2 = 0.3
                 BREAK
              END
  'NWGZMXP' : BEGIN
                ; accumulate 2-D histogram of GR Nw vs. Max DPR Zmeasured
                 IF raintypeBBidx EQ 1 THEN BEGIN
                    binmin2 = 2.0 & binmin1 = 20.0
                    binmax2 = 6.0 & binmax1 = 60.0
                 ENDIF ELSE BEGIN
                    binmin2 = 2.0 & binmin1 = 15.0
                    binmax2 = 6.0 & binmax1 = 55.0
                 ENDELSE
                 BINSPAN2 = 0.1
                 BINSPAN1 = 1.0
                 BREAK
              END
    'PIADMP' : BEGIN
                 ; accumulate 2-D histogram of DPR PIA vs. Dm
                  binmin1 = 0.0 & binmin2 = 0.0
                  binmax1 = 4.0 & binmax2 = 10.0
                  BINSPAN1 = 0.1 & BINSPAN2 = 0.25
                  BREAK
               END
     'EPSI' : BEGIN
                 IF raintypeBBidx EQ 1 THEN BEGIN
                    rrcoeff = 0.235 & dmcoeff = 1.273
                 ENDIF ELSE BEGIN
                    rrcoeff = 0.2151 & dmcoeff = 1.319
                 ENDELSE
                 binmin1 = 0.0 & binmin2 = 0.0
                 binmax1 = 2.5 & binmax2 = 2.5
                 BINSPAN1 = 0.1 & BINSPAN2 = 0.1
                 BREAK
              END
       'ZC' : 
       'ZM' : BEGIN
                ; accumulate 2-D histogram of reflectivity
                 IF raintypeBBidx EQ 1 THEN BEGIN
                    binmin1 = 20.0 & binmin2 = 20.0
                    binmax1 = 65.0 & binmax2 = 65.0
                 ENDIF ELSE BEGIN
                    binmin1 = 15.0 & binmin2 = 15.0
                    binmax1 = 45.0 & binmax2 = 45.0
                 ENDELSE
                 IF N_ELEMENTS(bins4scat) EQ 1 THEN BEGIN
                    BINSPAN1 = bins4scat
                    BINSPAN2 = bins4scat
                 ENDIF ELSE BEGIN
                    BINSPAN1 = 2.0
                    BINSPAN2 = 2.0
                 ENDELSE
                 BREAK
              END
      ENDSWITCH

     ; extract the samples to include in the scatter plots, if variable is
     ; available and there are qualifying points from above
      CASE PlotTypes(iplot) OF
       'D0' : BEGIN
                 IF countabv GT 0 AND have_D0 THEN BEGIN
                    scat_X = GR_D0[idxabv]
                    scat_Y = DPR_D0[idxabv]
                    accum_scat_data, scat_X, scat_Y, binmin1, binmin2, $
                                     binmax1, binmax2, BINSPAN1, BINSPAN2, $
                                     plotDataPtrs, have_Hist, PlotTypes, $
                                     iPlot, raintypeBBidx
;                    print, PlotTypes[iPlot]+" MAEaccum: ", $
;                           (*plotDataPtrs[iPlot, raintypeBBidx]).maeACCUM
                 ENDIF ELSE countabv=0
              END
       'DM' : BEGIN
                 IF countabv GT 0 AND have_Dm THEN BEGIN
                    scat_X = GR_Dm[idxabv]
                    scat_Y = DPR_Dm[idxabv]
                    accum_scat_data, scat_X, scat_Y, binmin1, binmin2, $
                                     binmax1, binmax2, BINSPAN1, BINSPAN2, $
                                     plotDataPtrs, have_Hist, PlotTypes, $
                                     iPlot, raintypeBBidx
;                    print, PlotTypes[iPlot]+" MAEaccum: ", $
;                           (*plotDataPtrs[iPlot, raintypeBBidx]).maeACCUM
                 ENDIF ELSE countabv=0
              END
    'DMANY' : BEGIN
                 IF countabv GT 0 AND have_Dm THEN BEGIN
                    scat_X = GR_Dm[idxabv]
                    scat_Y = DPR_Dm[idxabv]
                    accum_scat_data, scat_X, scat_Y, binmin1, binmin2, $
                                     binmax1, binmax2, BINSPAN1, BINSPAN2, $
                                     plotDataPtrs, have_Hist, PlotTypes, $
                                     iPlot, raintypeBBidx
;                    print, PlotTypes[iPlot]+" MAEaccum: ", $
;                           (*plotDataPtrs[iPlot, raintypeBBidx]).maeACCUM
                 ENDIF ELSE countabv=0
              END
       'N2' : BEGIN
                 IF countabv GT 0 AND have_N2 THEN BEGIN
                    scat_X = GR_N2[idxabv]
                    scat_Y = DPR_N2[idxabv]
                    accum_scat_data, scat_X, scat_Y, binmin1, binmin2, $
                                     binmax1, binmax2, BINSPAN1, BINSPAN2, $
                                     plotDataPtrs, have_Hist, PlotTypes, $
                                     iPlot, raintypeBBidx
;                    print, PlotTypes[iPlot]+" MAEaccum: ", $
;                           (*plotDataPtrs[iPlot, raintypeBBidx]).maeACCUM
                 ENDIF ELSE countabv=0
              END
       'NW' : BEGIN
                IF countabv GT 0 AND have_Nw THEN BEGIN
                    scat_X = GR_Nw[idxabv]
                    scat_Y = DPR_Nw[idxabv]
                    accum_scat_data, scat_X, scat_Y, binmin1, binmin2, $
                                     binmax1, binmax2, BINSPAN1, BINSPAN2, $
                                     plotDataPtrs, have_Hist, PlotTypes, $
                                     iPlot, raintypeBBidx
;                    print, PlotTypes[iPlot]+" MAEaccum: ", $
;                           (*plotDataPtrs[iPlot, raintypeBBidx]).maeACCUM
                 ENDIF ELSE countabv=0
              END
       'RC' : BEGIN
                 IF countabv GT 0 AND have_RC THEN BEGIN
                    scat_X = GR_RC[idxabv]
                    scat_Y = DPR_RC[idxabv]
                    accum_scat_data, scat_X, scat_Y, binmin1, binmin2, $
                                     binmax1, binmax2, BINSPAN1, BINSPAN2, $
                                     plotDataPtrs, have_Hist, PlotTypes, $
                                     iPlot, raintypeBBidx
;                    print, PlotTypes[iPlot]+" MAEaccum: ", $
;                           (*plotDataPtrs[iPlot, raintypeBBidx]).maeACCUM
                 ENDIF ELSE countabv=0
              END
       'RP' : BEGIN
                 IF countabv GT 0 AND have_RP THEN BEGIN
                    scat_X = GR_RP[idxabv]
                    scat_Y = DPR_RP[idxabv]
                    accum_scat_data, scat_X, scat_Y, binmin1, binmin2, $
                                     binmax1, binmax2, BINSPAN1, BINSPAN2, $
                                     plotDataPtrs, have_Hist, PlotTypes, $
                                     iPlot, raintypeBBidx
;                    print, PlotTypes[iPlot]+" MAEaccum: ", $
;                           (*plotDataPtrs[iPlot, raintypeBBidx]).maeACCUM
                 ENDIF ELSE countabv=0
              END
       'RR' : BEGIN
                 IF countabv GT 0 AND have_RR THEN BEGIN
                    scat_X = GR_RR[idxabv]
                    scat_Y = DPR_RR[idxabv]
                    accum_scat_data, scat_X, scat_Y, binmin1, binmin2, $
                                     binmax1, binmax2, BINSPAN1, BINSPAN2, $
                                     plotDataPtrs, have_Hist, PlotTypes, $
                                     iPlot, raintypeBBidx
;                    print, PlotTypes[iPlot]+" MAEaccum: ", $
;                           (*plotDataPtrs[iPlot, raintypeBBidx]).maeACCUM
                 ENDIF ELSE countabv=0
              END
    'ZCNWP' : BEGIN
                 IF countabv GT 0 AND have_Nw THEN BEGIN
                    scat_Y = zcor[idxabv]
                    scat_X = DPR_Nw[idxabv]
                    accum_scat_data, scat_X, scat_Y, binmin1, binmin2, $
                                     binmax1, binmax2, BINSPAN1, BINSPAN2, $
                                     plotDataPtrs, have_Hist, PlotTypes, $
                                     iPlot, raintypeBBidx
;                    print, PlotTypes[iPlot]+" MAEaccum: ", $
;                           (*plotDataPtrs[iPlot, raintypeBBidx]).maeACCUM
                 ENDIF ELSE countabv=0
              END
    'ZCNWG' : BEGIN
                ; accumulate 2-D histogram of reflectivity vs. Nw
                 IF countabv GT 0 AND have_Nw THEN BEGIN
                    scat_Y = gvz[idxabv]
                    scat_X = GR_Nw[idxabv]
                    accum_scat_data, scat_X, scat_Y, binmin1, binmin2, $
                                     binmax1, binmax2, BINSPAN1, BINSPAN2, $
                                     plotDataPtrs, have_Hist, PlotTypes, $
                                     iPlot, raintypeBBidx
;                    print, PlotTypes[iPlot]+" MAEaccum: ", $
;                           (*plotDataPtrs[iPlot, raintypeBBidx]).maeACCUM
                 ENDIF ELSE countabv=0
              END
    'DMRRG' : BEGIN
                ; accumulate 2-D histogram of Dm vs. RR
                 IF countabv GT 0 AND have_Nw AND have_Dm THEN BEGIN
                    scat_Y = GR_Dm[idxabv]
                    scat_X = GR_RR[idxabv]
                    accum_scat_data, scat_X, scat_Y, binmin1, binmin2, $
                                     binmax1, binmax2, BINSPAN1, BINSPAN2, $
                                     plotDataPtrs, have_Hist, PlotTypes, $
                                     iPlot, raintypeBBidx
;                    print, PlotTypes[iPlot]+" MAEaccum: ", $
;                           (*plotDataPtrs[iPlot, raintypeBBidx]).maeACCUM
                 ENDIF ELSE countabv=0
              END

    'RRNWG' : BEGIN
                ; accumulate 2-D histogram of Dm vs. Nw
                 IF countabv GT 0 AND have_Nw AND have_RR THEN BEGIN
                    scat_Y = GR_RR[idxabv]
                    scat_X = GR_Nw[idxabv]
                    accum_scat_data, scat_X, scat_Y, binmin1, binmin2, $
                                     binmax1, binmax2, BINSPAN1, BINSPAN2, $
                                     plotDataPtrs, have_Hist, PlotTypes, $
                                     iPlot, raintypeBBidx
;                    print, PlotTypes[iPlot]+" MAEaccum: ", $
;                           (*plotDataPtrs[iPlot, raintypeBBidx]).maeACCUM
                 ENDIF ELSE countabv=0
              END

    'NWDMP' : BEGIN
                ; accumulate 2-D histogram of Dm vs. Nw
                 IF countabv GT 0 AND have_Nw AND have_Dm THEN BEGIN
                    scat_Y = DPR_Nw[idxabv]
                    scat_X = DPR_Dm[idxabv]
                    accum_scat_data, scat_X, scat_Y, binmin1, binmin2, $
                                     binmax1, binmax2, BINSPAN1, BINSPAN2, $
                                     plotDataPtrs, have_Hist, PlotTypes, $
                                     iPlot, raintypeBBidx
;                    print, PlotTypes[iPlot]+" MAEaccum: ", $
;                           (*plotDataPtrs[iPlot, raintypeBBidx]).maeACCUM
                 ENDIF ELSE countabv=0
              END
    'NWDMG' : BEGIN
                ; accumulate 2-D histogram of Dm vs. Nw
                 IF countabv GT 0 AND have_Nw AND have_Dm THEN BEGIN
                    scat_Y = GR_Nw[idxabv]
                    scat_X = GR_Dm[idxabv]
                    accum_scat_data, scat_X, scat_Y, binmin1, binmin2, $
                                     binmax1, binmax2, BINSPAN1, BINSPAN2, $
                                     plotDataPtrs, have_Hist, PlotTypes, $
                                     iPlot, raintypeBBidx
;                    print, PlotTypes[iPlot]+" MAEaccum: ", $
;                           (*plotDataPtrs[iPlot, raintypeBBidx]).maeACCUM
                 ENDIF ELSE countabv=0
              END
    'DMRRP' : BEGIN
                ; accumulate 2-D histogram of DPR-only Dm vs. RR
                 IF countabv GT 0 AND have_RR AND have_Dm THEN BEGIN
                    scat_Y = DPR_Dm[idxabv]
                    scat_X = DPR_RR[idxabv]
                    accum_scat_data, scat_X, scat_Y, binmin1, binmin2, $
                                     binmax1, binmax2, BINSPAN1, BINSPAN2, $
                                     plotDataPtrs, have_Hist, PlotTypes, $
                                     iPlot, raintypeBBidx
;                    print, PlotTypes[iPlot]+" MAEaccum: ", $
;                           (*plotDataPtrs[iPlot, raintypeBBidx]).maeACCUM
                 ENDIF ELSE countabv=0
              END
    'RRNWP' : BEGIN
                ; accumulate 2-D histogram of DPR-only RR vs. Nw
                 IF countabv GT 0 AND have_Nw AND have_RR THEN BEGIN
                    scat_Y = DPR_RR[idxabv]
                    scat_X = DPR_Nw[idxabv]
                    accum_scat_data, scat_X, scat_Y, binmin1, binmin2, $
                                     binmax1, binmax2, BINSPAN1, BINSPAN2, $
                                     plotDataPtrs, have_Hist, PlotTypes, $
                                     iPlot, raintypeBBidx
;                    print, PlotTypes[iPlot]+" MAEaccum: ", $
;                           (*plotDataPtrs[iPlot, raintypeBBidx]).maeACCUM
                 ENDIF ELSE countabv=0
              END
  'NWGZMXP' : BEGIN
                 IF countabv GT 0 AND have_Nw AND have_maxraw250 THEN BEGIN
                    scat_Y = GR_Nw[idxabv]
                    scat_X = maxraw250[idxabv]
                    accum_scat_data, scat_X, scat_Y, binmin1, binmin2, $
                                     binmax1, binmax2, BINSPAN1, BINSPAN2, $
                                     plotDataPtrs, have_Hist, PlotTypes, $
                                     iPlot, raintypeBBidx
;                    print, PlotTypes[iPlot]+" MAEaccum: ", $
;                           (*plotDataPtrs[iPlot, raintypeBBidx]).maeACCUM
                 ENDIF ELSE countabv=0
              END
    'PIADMP' : BEGIN
                 ; accumulate 2-D histogram of DPR PIA vs. Dm
                  IF countabv GT 0 AND have_Dm THEN BEGIN
                     scat_Y = PIA[idxabv]
                     scat_X = DPR_Dm[idxabv]
                     accum_scat_data, scat_X, scat_Y, binmin1, binmin2, $
                                      binmax1, binmax2, BINSPAN1, BINSPAN2, $
                                      plotDataPtrs, have_Hist, PlotTypes, $
                                      iPlot, raintypeBBidx
 ;                    print, PlotTypes[iPlot]+" MAEaccum: ", $
 ;                           (*plotDataPtrs[iPlot, raintypeBBidx]).maeACCUM
                  ENDIF ELSE countabv=0
               END
     'EPSI' : BEGIN
                 IF countabv GT 0 AND have_RR AND have_Dm THEN BEGIN
                   ; limit ourselves to where RR and Dm are defined
                    IF have_DprEpsilon EQ 1 THEN BEGIN
                       idxnonzero=WHERE(GR_RR[idxabv] GT 0.0 and GR_Dm[idxabv] GT 0.0 AND $
                                        dprEpsilon[idxabv] GT 0.0, countnonzero)
print, "" & print, "Using DPR Epsilon." & print, ""
                    ENDIF ELSE BEGIN
                       idxnonzero=WHERE(GR_RR[idxabv] GT 0.0 and GR_Dm[idxabv] GT 0.0 AND $
                                        DPR_RR[idxabv] GT 0.0 and DPR_Dm[idxabv] GT 0.0, $
                                        countnonzero)
                    ENDELSE
                    if countnonzero GT 0 then begin
                       countabv=countnonzero
                       idx2do = idxabv[idxnonzero]
                       scat_X = GR_RR[idx2do]^rrcoeff / GR_Dm[idx2do]^dmcoeff
                       IF have_DprEpsilon EQ 1 THEN $
                          scat_Y = dprEpsilon[idx2do] $
                       ELSE $
                          scat_Y = DPR_RR[idx2do]^rrcoeff / DPR_Dm[idx2do]^dmcoeff
                       accum_scat_data, scat_X, scat_Y, binmin1, binmin2, $
                                        binmax1, binmax2, BINSPAN1, BINSPAN2, $
                                        plotDataPtrs, have_Hist, PlotTypes, $
                                        iPlot, raintypeBBidx
;                       print, PlotTypes[iPlot]+" MAEaccum: ", $
;                              (*plotDataPtrs[iPlot, raintypeBBidx]).maeACCUM
                    endif else countabv=0
                 ENDIF ELSE countabv=0
              END
       'ZC' : BEGIN
                ; accumulate 2-D histogram of corrected reflectivity
                 IF countabv GT 0 THEN BEGIN
                    scat_X = gvz[idxabv]
                    scat_Y = zcor[idxabv]
                    DPRtxt = ' Zcor '
                    accum_scat_data, scat_X, scat_Y, binmin1, binmin2, $
                                     binmax1, binmax2, BINSPAN1, BINSPAN2, $
                                     plotDataPtrs, have_Hist, PlotTypes, $
                                     iPlot, raintypeBBidx
;                    print, PlotTypes[iPlot]+" MAEaccum: ", $
;                           (*plotDataPtrs[iPlot, raintypeBBidx]).maeACCUM
                 ENDIF
              END
       'ZM' : BEGIN
                ; accumulate 2-D histogram of measured reflectivity
                 IF countabv GT 0 THEN BEGIN
                    scat_X = gvz[idxabv]
                    scat_Y = zraw[idxabv]
                    DPRtxt = ' Zmeas '
                    accum_scat_data, scat_X, scat_Y, binmin1, binmin2, $
                                     binmax1, binmax2, BINSPAN1, BINSPAN2, $
                                     plotDataPtrs, have_Hist, PlotTypes, $
                                     iPlot, raintypeBBidx
;                    print, PlotTypes[iPlot]+" NUMPTS, MAEaccum: ", $
;                           (*plotDataPtrs[iPlot, raintypeBBidx]).NUMPTS, $
;                           (*plotDataPtrs[iPlot, raintypeBBidx]).maeACCUM
                 ENDIF
              END
      ENDCASE
   endfor
   ENDFOR
   ENDIF

  ;# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

   nextFile:
   lastorbitnum=orbitnum
   lastncfile=bname
   lastsite=site
;stop
ENDFOR    ; end of loop over fnum = 0, nf-1

bustOut=0   ; define this for later check if skipping scatter plots
IF do_scatr NE 1 THEN GOTO, noScatterPlots     ; skip all the scatter plots

; set up for plot title data source label
IF N_ELEMENTS(swath) EQ 1 THEN prodStr=pr_or_dpr+'/'+swath ELSE prodStr=pr_or_dpr

for idx2do=0,nPlots-1 do begin

; limit ourselves to one field if altfield is specified
IF N_ELEMENTS(altfield) EQ 1 THEN BEGIN
   IF idx2do NE PlotHash(altfield) THEN BEGIN
      print, "Skipping " + PlotTypes(idx2do) + " plots."
      CONTINUE
   ENDIF ELSE print, "Doing " + PlotTypes(idx2do) + " plots."
ENDIF

FOR raintypeBBidx = 0, 1 do begin

ptr2do = plotDataPtrs[idx2do, raintypeBBidx]
BB_string = '_BelowBB'
; Have to check both that data were read for the variable(s), and that
; histogram data were accumulated for this instance before attempting the plot
IF have_hist.(idx2do)[haveVar, raintypeBBidx] EQ 1 AND (*ptr2do[0]) NE !NULL THEN BEGIN
  ; CREATE THE SCATTER PLOT OBJECT FROM THE BINNED DATA
   do_MAE_1_1 = 1    ; flag to include/suppress MAE and the 1:1 line on plots
   bustOut=0

   SWITCH PlotTypes(idx2do) OF
    'D0' : 
    'DM' : BEGIN
              IF raintypeBBidx EQ 1 THEN BEGIN
                 SCAT_DATA = "Convective Samples, Below Bright Band and <= 3 km AGL"
                 xticknames=['0.0','0.5','1.0','1.5','2.0','2.5','3.0','3.5','4.0']
              ENDIF ELSE BEGIN
                 SCAT_DATA = "Stratiform Samples, Below Bright Band and <= 3 km AGL"
                 xticknames=['0.0','0.5','1.0','1.5','2.0','2.5','3.0','3.5','4.0']
              ENDELSE
              yticknames=xticknames
              xmajor=N_ELEMENTS(xticknames) & ymajor=xmajor
              titleLine1 = prodStr+' '+version+" Dm vs. GR "+PlotTypes(idx2do)+ $
                           " Scatter, Mean GR-DPR Bias: "
              pngpre=pr_or_dpr+'_'+version+"_Dm_vs_GR_"+PlotTypes(idx2do)+"_Scatter"
              units='mm'
              xtitle= 'GR '+PlotTypes(idx2do)+GRlabelAdd+' ('+units+')'
              ytitle= pr_or_dpr + ' Dm ('+units+')'
              BREAK
           END
    'DMANY' : BEGIN
              IF raintypeBBidx EQ 1 THEN BEGIN
                 SCAT_DATA = "All Samples Below Bright Band and <= 3 km AGL"
                 xticknames=['0.0','0.5','1.0','1.5','2.0','2.5','3.0','3.5','4.0']
              ENDIF ELSE BEGIN
                 SCAT_DATA = "All Samples Below Bright Band and <= 3 km AGL"
                 xticknames=['0.0','0.5','1.0','1.5','2.0','2.5','3.0','3.5','4.0']
              ENDELSE
              yticknames=xticknames
              xmajor=N_ELEMENTS(xticknames) & ymajor=xmajor
              titleLine1 = prodStr+' '+version+" Dm vs. GR Dm"+ $
                           " Scatter, Mean GR-DPR Bias: "
              pngpre=pr_or_dpr+'_'+version+"_Dm_vs_GR_"+PlotTypes(idx2do)+"_Scatter"
              units='mm'
              xtitle= 'GR Dm '+GRlabelAdd+' ('+units+')'
              ytitle= pr_or_dpr + ' Dm ('+units+')'
              BREAK
           END
    'N2' :
    'NW' : BEGIN
              IF raintypeBBidx EQ 1 THEN BEGIN
                 SCAT_DATA = "Convective Samples, Below Bright Band and <= 3 km AGL"
                 xticknames=['2.0','2.5','3.0','3.5','4.0','4.5','5.0','5.5','6.0']
              ENDIF ELSE BEGIN
                 SCAT_DATA = "Stratiform Samples, Below Bright Band and <= 3 km AGL"
                 xticknames=['2.0','2.5','3.0','3.5','4.0','4.5','5.0','5.5','6.0']
              ENDELSE
              yticknames=xticknames
              ;BINSPAN = 0.1
              xmajor=N_ELEMENTS(xticknames) & ymajor=xmajor
              titleLine1 = prodStr+' '+version+" Nw vs. GR "+PlotTypes(idx2do)+ $
                           " Scatter, Mean GR-DPR Bias: "
              pngpre=pr_or_dpr+'_'+version+"_Nw_vs_GR_"+PlotTypes(idx2do)+"_Scatter"
              units='log(Nw)'
              xtitle= 'GR '+units
              ytitle= pr_or_dpr +' '+ units
              BREAK
           END
 'ZCNWP' : BEGIN
              do_MAE_1_1 = 0
              IF raintypeBBidx EQ 1 THEN BEGIN
                 SCAT_DATA = "Convective Samples, Below Bright Band and <= 3 km AGL"
                 yticknames=['20','25','30','35','40','45','50','55','60']
              ENDIF ELSE BEGIN
                 SCAT_DATA = "Stratiform Samples, Below Bright Band and <= 3 km AGL"
                 yticknames=['15','20','25','30','35','40','45','50','55']
              ENDELSE
              xticknames=['2.0','2.5','3.0','3.5','4.0','4.5','5.0','5.5','6.0']
              xmajor=N_ELEMENTS(xticknames) & ymajor=N_ELEMENTS(yticknames)
              titleLine1 = prodStr+' '+version+" Zc vs. Nw Scatter"
              pngpre=pr_or_dpr+'_'+version+"_Zc_vs_Nw_Scatter"
              xunits='log(Nw)'
              yunits='dBZ'
              xtitle= pr_or_dpr +' '+ xunits
              ytitle= pr_or_dpr + ' Zc (' + yunits + ')'
              BREAK
           END
 'ZCNWG' : BEGIN
              do_MAE_1_1 = 0
              IF raintypeBBidx EQ 1 THEN BEGIN
                 SCAT_DATA = "Convective Samples, Below Bright Band and <= 3 km AGL"
                 yticknames=['20','25','30','35','40','45','50','55','60']
              ENDIF ELSE BEGIN
                 SCAT_DATA = "Stratiform Samples, Below Bright Band and <= 3 km AGL"
                 yticknames=['15','20','25','30','35','40','45','50','55']
              ENDELSE
              xticknames=['2.0','2.5','3.0','3.5','4.0','4.5','5.0','5.5','6.0']
              xmajor=N_ELEMENTS(xticknames) & ymajor=N_ELEMENTS(yticknames)
              titleLine1 = "GR Zc vs. Nw Scatter for " + pr_or_dpr+' '+version
              pngpre="GR_Zc_vs_Nw_Scatter_for_" + pr_or_dpr+'_'+version
              xunits='log(Nw)'
              yunits='dBZ'
              xtitle= 'GR '+ xunits
              ytitle= 'GR Zc (' + yunits + ')'
              BREAK
              END
 'NWDMP' : BEGIN
              do_MAE_1_1 = 0
              IF raintypeBBidx EQ 1 THEN $
                 SCAT_DATA = "Convective Samples, Below Bright Band and <= 3 km AGL" $
              ELSE SCAT_DATA = "Stratiform Samples, Below Bright Band and <= 3 km AGL"
              xticknames=['0.0','0.5','1.0','1.5','2.0','2.5','3.0','3.5','4.0']
              yticknames=['2.0','2.5','3.0','3.5','4.0','4.5','5.0','5.5','6.0']
              xmajor=N_ELEMENTS(xticknames) & ymajor=N_ELEMENTS(yticknames)
              titleLine1 = prodStr+' '+version+" Nw vs. Dm Scatter"
              pngpre=pr_or_dpr+'_'+version+"_Nw_vs_Dm_Scatter"
              xunits='(mm)'
              yunits='log(Nw)'
              xtitle= pr_or_dpr +' Dm '+ xunits
              ytitle= pr_or_dpr + ' ' + yunits
              BREAK
           END
 'NWDMG' : BEGIN
              do_MAE_1_1 = 0
              IF raintypeBBidx EQ 1 THEN $
                 SCAT_DATA = "Convective Samples, Below Bright Band and <= 3 km AGL" $
              ELSE SCAT_DATA = "Stratiform Samples, Below Bright Band and <= 3 km AGL"
              yticknames=['2.0','2.5','3.0','3.5','4.0','4.5','5.0','5.5','6.0']
              xticknames=['0.0','0.5','1.0','1.5','2.0','2.5','3.0','3.5','4.0']
              xmajor=N_ELEMENTS(xticknames) & ymajor=N_ELEMENTS(yticknames)
              titleLine1 = "GR Nw vs. Dm Scatter"
              pngpre="GR_Nw_vs_Dm_Scatter"
              yunits='log(Nw)'
              xunits='mm'
              ytitle= 'GR '+ yunits
              xtitle= 'GR Dm (' + xunits + ')'
              BREAK
           END
 'DMRRG' : BEGIN
              do_MAE_1_1 = 0
              IF raintypeBBidx EQ 1 THEN BEGIN
                 SCAT_DATA = "Convective Samples, Below Bright Band and <= 3 km AGL"
              ENDIF ELSE BEGIN
                 SCAT_DATA = "Stratiform Samples, Below Bright Band and <= 3 km AGL"
              ENDELSE
              xticknames=STRING(INDGEN(16), FORMAT='(I0)')
              yticknames=['0.0','0.5','1.0','1.5','2.0','2.5','3.0','3.5','4.0']
              xmajor=N_ELEMENTS(xticknames) & ymajor=N_ELEMENTS(yticknames)
              titleLine1 = "GR Dm vs. RR Scatter"
              pngpre="GR_Dm_vs_RR_Scatter"
              xunits='(mm/h)'
              yunits='mm'
              xtitle=  'GR RR '+ xunits
              ytitle=  'GR Dm (' + yunits + ')'
              BREAK
           END
 'RRNWG' : BEGIN
              do_MAE_1_1 = 0
              IF raintypeBBidx EQ 1 THEN BEGIN
                 SCAT_DATA = "Convective Samples, Below Bright Band and <= 3 km AGL"
              ENDIF ELSE BEGIN
                 SCAT_DATA = "Stratiform Samples, Below Bright Band and <= 3 km AGL"
              ENDELSE
              yticknames=STRING(INDGEN(16), FORMAT='(I0)')
              xticknames=['2.0','2.5','3.0','3.5','4.0','4.5','5.0','5.5','6.0']
              xmajor=N_ELEMENTS(xticknames) & ymajor=N_ELEMENTS(yticknames)
              titleLine1 = "GR RR vs. Nw Scatter"
              pngpre="GR_RR_vs_Nw_Scatter"
              xunits='log(Nw)'
              yunits='mm/h'
              xtitle= 'GR '+ xunits
              ytitle= 'GR RR (' + yunits + ')'
              BREAK
           END
 'DMRRP' : BEGIN
              do_MAE_1_1 = 0
              IF raintypeBBidx EQ 1 THEN BEGIN
                 SCAT_DATA = "Convective Samples, Below Bright Band and <= 3 km AGL"
              ENDIF ELSE BEGIN
                 SCAT_DATA = "Stratiform Samples, Below Bright Band and <= 3 km AGL"
              ENDELSE
              xticknames=STRING(INDGEN(16), FORMAT='(I0)')
              yticknames=['0.0','0.5','1.0','1.5','2.0','2.5','3.0','3.5','4.0']
              xmajor=N_ELEMENTS(xticknames) & ymajor=N_ELEMENTS(yticknames)
              titleLine1 = prodStr+' '+version+" Dm vs. RR Scatter"
              pngpre=pr_or_dpr+'_'+version+"_Dm_vs_RR_Scatter"
              xunits='(mm/h)'
              yunits='mm'
              xtitle= pr_or_dpr + ' RR'+ xunits
              ytitle= pr_or_dpr + ' Dm (' + yunits + ')'
              BREAK
           END
 'RRNWP' : BEGIN
              do_MAE_1_1 = 0
              IF raintypeBBidx EQ 1 THEN BEGIN
                 SCAT_DATA = "Convective Samples, Below Bright Band and <= 3 km AGL"
              ENDIF ELSE BEGIN
                 SCAT_DATA = "Stratiform Samples, Below Bright Band and <= 3 km AGL"
              ENDELSE
              yticknames=STRING(INDGEN(16), FORMAT='(I0)')
              xticknames=['2.0','2.5','3.0','3.5','4.0','4.5','5.0','5.5','6.0']
              xmajor=N_ELEMENTS(xticknames) & ymajor=N_ELEMENTS(yticknames)
              titleLine1 = prodStr+' '+version+" RR vs. Nw Scatter"
              pngpre=pr_or_dpr+'_'+version+"_RR_vs_Nw_Scatter"
              xunits='log(Nw)'
              yunits='mm/h'
              xtitle= pr_or_dpr +' '+ xunits
              ytitle= pr_or_dpr + ' RR (' + yunits + ')'
              BREAK
           END
    'RC' : 
    'RP' : 
    'RR' : BEGIN
              IF raintypeBBidx EQ 1 THEN BEGIN
                 SCAT_DATA = "Convective Samples, Below Bright Band and <= 3 km AGL"
              ENDIF ELSE BEGIN
                 SCAT_DATA = "Stratiform Samples, Below Bright Band and <= 3 km AGL"
              ENDELSE
              xticknames=STRING(INDGEN(16), FORMAT='(I0)')
              yticknames=xticknames
              xmajor=N_ELEMENTS(xticknames) & ymajor=xmajor
              titleLine1 = prodStr+' '+version+" RR vs. GR "+PlotTypes(idx2do)+ $
                           " Scatter, Mean GR-DPR Bias: "
              pngpre=pr_or_dpr+'_'+version+"_RR_vs_GR_"+PlotTypes(idx2do)+"_Scatter"
              units='(mm/h)'
              xtitle= 'GR '+units
              ytitle= pr_or_dpr +' '+ units
              BREAK
           END
  'NWGZMXP' : BEGIN
                 do_MAE_1_1 = 0
                 IF raintypeBBidx EQ 1 THEN BEGIN
                    SCAT_DATA = "Convective Samples, Below Bright Band and <= 3 km AGL"
                    xticknames=['20','25','30','35','40','45','50','55','60']
                 ENDIF ELSE BEGIN
                    SCAT_DATA = "Stratiform Samples, Below Bright Band and <= 3 km AGL"
                    xticknames=['15','20','25','30','35','40','45','50','55']
                 ENDELSE
                 yticknames=['2.0','2.5','3.0','3.5','4.0','4.5','5.0','5.5','6.0']
                 xmajor=N_ELEMENTS(xticknames) & ymajor=N_ELEMENTS(yticknames)
                 titleLine1 = "GR Nw vs. "+prodStr+" Zm(max) Scatter for " $
                              + pr_or_dpr+' '+version
                 pngpre="GR_Nw_vs_KuZmMax_Scatter_for_" + pr_or_dpr+'_'+version
                 yunits='log(Nw)'
                 xunits='dBZ'
                 ytitle= 'GR '+ yunits
                 xtitle= pr_or_dpr +' ZmMax (' + xunits + ')'
                 BREAK
              END
    'PIADMP' : BEGIN
                  do_MAE_1_1 = 0
                  IF raintypeBBidx EQ 1 THEN $
                     SCAT_DATA = "Convective Samples, Below Bright Band and <= 3 km AGL" $
                  ELSE SCAT_DATA = "Stratiform Samples, Below Bright Band and <= 3 km AGL"
                  xticknames=['0.0','0.5','1.0','1.5','2.0','2.5','3.0','3.5','4.0']
                  yticknames=STRING(INDGEN(11), FORMAT='(I0)')
                  xmajor=N_ELEMENTS(xticknames) & ymajor=N_ELEMENTS(yticknames)
                  titleLine1 = prodStr+' '+version+" PIA vs. Dm Scatter"
                  pngpre=pr_or_dpr+'_'+version+"_PIA_vs_Dm_Scatter"
                  xunits='(mm)'
                  yunits='(dBZ)'
                  xtitle= pr_or_dpr +' Dm '+ xunits
                  ytitle= pr_or_dpr + ' PIA ' + yunits
                  BREAK
               END
  'EPSI' : BEGIN
              IF raintypeBBidx EQ 1 THEN BEGIN
                 SCAT_DATA = "Convective Samples, Below Bright Band and <= 3 km AGL"
              ENDIF ELSE BEGIN
                 SCAT_DATA = "Stratiform Samples, Below Bright Band and <= 3 km AGL"
              ENDELSE
              xticknames=STRING(INDGEN(6)*0.5, FORMAT='(F0.1)')
              yticknames=xticknames
              ;BINSPAN = 0.1
              xmajor=N_ELEMENTS(xticknames) & ymajor=xmajor
              IF have_DprEpsilon EQ 1 THEN BEGIN
                 titleLine1 = prodStr+' '+version+" Internal vs. GR "+ $
                              " Epsilon Scatter, Mean GR-DPR Bias: "
                 pngpre=pr_or_dpr+'_'+version+"_Internal_vs_GR_Epsilon_Scatter"
              ENDIF ELSE BEGIN
                 titleLine1 = prodStr+' '+version+" Derived vs. GR "+ $
                              " Epsilon Scatter, Mean GR-DPR Bias: "
                 pngpre=pr_or_dpr+'_'+version+"_Derived_vs_GR_Epsilon_Scatter"
              ENDELSE
              units='$\epsilon$'
              xtitle= 'GR $\epsilon$'
              ytitle= pr_or_dpr +' $\epsilon$'
              BREAK
           END
    ELSE : BEGIN
              IF raintypeBBidx EQ 1 THEN BEGIN
                 SCAT_DATA = "Convective Samples, Below Bright Band"
                 xticknames=['20','25','30','35','40','45','50','55','60','65']
              ENDIF ELSE BEGIN
                 SCAT_DATA = "Stratiform Samples, Above Bright Band"
                 xticknames=['15','20','25','30','35','40','45']
                 BB_string = '_AboveBB'
              ENDELSE
              IF PlotTypes(idx2do) EQ 'ZM' THEN DPRtxt=' Zmeas ' ELSE DPRtxt=' Zcor '
              yticknames=xticknames
              ;IF N_ELEMENTS(bins4scat) EQ 1 THEN BINSPAN = bins4scat ELSE BINSPAN = 2.0
              xmajor=N_ELEMENTS(xticknames) & ymajor=xmajor
              titleLine1 = prodStr+' '+version+DPRtxt+" vs. GR Z Scatter, Mean GR-DPR Bias: "
              pngpre=pr_or_dpr+'_'+version+'_'+PlotTypes(idx2do)+"_vs_GR_Z_Scatter"
              IF ( s2ku ) THEN BEGIN
                 xtitleadd = ', Ku-adjusted'
                 pngpre = pngpre + '_S2Ku'
              ENDIF ELSE BEGIN
                 xtitleadd = ''
                 pngpre = pngpre + '_DefaultS'
              ENDELSE
              units='dBZ'
              xtitle= 'GR Reflectivity ('+units+')' + xtitleadd
              ytitle= pr_or_dpr + ' Reflectivity ('+units+')'
           END
      ENDSWITCH

   PRINT, ''
   PRINT, '' 
   PRINT, "PLOTTING: ", PlotTypes(idx2do)+ '_'+ rntypeLabels[raintypeBBidx]+BB_string
   PRINT, '' 
;   PRINT, "Min PR value: ", (*ptr2do[0]).minprz
;   PRINT, ''
;   PRINT, "locations: ", (*ptr2do[0]).Zstarts+BINSPAN2/2
;   PRINT, "gvzmeanByBin: ", (*ptr2do[0]).gvzmeanaccum/(*ptr2do[0]).nbybinaccum
;   PRINT, "przmeanByBin: ", (*ptr2do[0]).przmeanaccum/(*ptr2do[0]).nbybinaccum
;   PRINT, ''

   idxzdef = WHERE((*ptr2do[0]).gvzmeanaccum GE 0.0 and (*ptr2do[0]).przmeanaccum GE 0.0)
   nSamp = TOTAL((*ptr2do[0]).nbybinaccum[idxzdef])
   n_str = ", N="+STRING(nSamp, FORMAT='(I0)')
   gvzmean = TOTAL((*ptr2do[0]).gvzmeanaccum[idxzdef])/nSamp
   przmean = TOTAL((*ptr2do[0]).przmeanaccum[idxzdef])/nSamp
   MAE = TOTAL((*ptr2do[0]).MAEaccum[idxzdef])/nSamp
   biasgrpr = gvzmean-przmean
   bias_str = STRING(biasgrpr, FORMAT='(F0.1)')
   MAE_str = STRING(MAE, FORMAT='(F0.1)')

;   print, ''
   IF do_MAE_1_1 THEN print, "MAE, bias: ", MAE_str+"  "+bias_str
;   print, ''

   sh = SIZE((*ptr2do[0]).zhist2d, /DIMENSIONS)
;PRINT, "sh: ", SH
  ; last bin in 2-d histogram only contains values = MAX, cut these
  ; out of the array
   zhist2d = (*ptr2do[0]).zhist2d[0:sh[0]-2,0:sh[1]-2]

  ; convert counts to percent of total if show_pct is set
   show_pct=1
   IF KEYWORD_SET(show_pct) THEN BEGIN
     ; convert counts to percent of total
      zhist2d = (zhist2d/DOUBLE(nSamp))*100.0D
     ; set values below 0.1% to 0%
      histLE5 = WHERE(zhist2d LT 0.1, countLT5)
      IF countLT5 GT 0 THEN zhist2d[histLE5] = 0.0D
     ; SCALE THE HISTOGRAM COUNTS TO 0-255 IMAGE BYTE VALUES
      histImg = BYTSCL(zhist2D)
   ENDIF ELSE BEGIN
     ; SCALE THE HISTOGRAM COUNTS TO 0-255 IMAGE BYTE VALUES
      histImg = BYTSCL(zhist2D)
     ; set non-zero Histo bins that are bytescaled to 0 to a small non-zero value
      idxnotzero = WHERE(histImg EQ 0b AND zhist2D GT 0, nnotzero)
      IF nnotzero GT 0 THEN histImg[idxnotzero] = 1b
   ENDELSE
  ; resize the image array to something like 150 pixels if it is small
   sh = SIZE(histImg, /DIMENSIONS)
;PRINT, "sh: ", SH
   IF MAX(sh) LT 125 THEN BEGIN
      scale = 150/MAX(sh) + 1
      sh2 = sh*scale
;PRINT, "sh2: ", SH2
      histImg = REBIN(histImg, sh2[0], sh2[1], /SAMPLE)
   ENDIF
   winsiz = SIZE( histImg, /DIMENSIONS )
   histImg = CONGRID(histImg, winsiz[0]*4, winsiz[1]*4)
   winsiz = SIZE( histImg, /DIMENSIONS )
;print, 'winsiz: ', winsiz
;   rgb=COLORTABLE(33)     ; not available for IDL 8.1, use LOADCT calls
   LOADCT, 33, RGB=rgb, /SILENT   ; gets the values w/o loading the color table
   LOADCT, 33, /SILENT            ; - so call again to load the color table
   rgb[0,*]=255   ; set zero count color to White background
   IF do_MAE_1_1 THEN BEGIN
            imTITLE = titleLine1+bias_str+" "+units+n_str+"!C"+SCAT_DATA+", "+ $
            pctabvstr+" Above Thresh."
   ENDIF ELSE BEGIN
            imTITLE = titleLine1+n_str+"!C"+SCAT_DATA+", "+ $
            pctabvstr+" Above Thresh."
   ENDELSE
   im=image(histImg, axis_style=2, xmajor=xmajor, ymajor=ymajor, $
            xminor=4, yminor=4, RGB_TABLE=rgb, BUFFER=buffer, $
            TITLE = imTITLE )
   im.xtickname=xticknames
   im.ytickname=yticknames
   im.xtitle= xtitle
   im.ytitle= ytitle

   IF do_MAE_1_1 THEN BEGIN
  ; add the 1:1 line to the plot, with white blanking above/below to stand out
   line1_1 = PLOT( /OVERPLOT, [0,winsiz[0]-1], [0,winsiz[1]-1], color='black' )
   lineblo = PLOT( /OVERPLOT, [2,winsiz[0]-1], [0,winsiz[1]-3], color='white' )
   lineabv = PLOT( /OVERPLOT, [0,winsiz[0]-3], [2,winsiz[1]-1], color='white' )

  ; write the MAE value in the image area
   txtmae=TEXT(winsiz[0]*0.2, winsiz[0]*0.85, "MAE: "+MAE_str+" "+units, $
               /DATA,/FILL_Background,FILL_COLOR='white',TRANSPARENCY=25)
   ENDIF

  ; define the parameters for a color bar with 9 tick levels labeled
   ticnms = STRARR(256)
   ticlocs = INDGEN(9)*256/8
   ticInterval = MAX(zhist2d)/8.0
   IF KEYWORD_SET(show_pct) THEN BEGIN
      ticnames = STRING(indgen(9)*ticInterval, FORMAT='(F0.1)' )
      ticID = "% of samples"
   ENDIF ELSE BEGIN
      ticnames = STRING( FIX(indgen(9)*ticInterval), FORMAT='(I0)' )
      ticID = "# samples"
   ENDELSE
   ticnms[ticlocs] = ticnames
   cbar=colorbar(target=im, orientation=1, position=[0.95, 0.2, 0.98, 0.75], $
                 TICKVALUES=ticlocs, TICKNAME=ticnms, TITLE=ticID)

   pngfile = outpath_sav + '/' + pngpre + '_'+ rntypeLabels[raintypeBBidx] + $
             BB_string + '_Pct'+ strtrim(string(pctAbvThresh),2) + $
             addme + '.png'

   IF KEYWORD_SET(batch_save) THEN BEGIN
      print, '' & print, "PNGFILE: ",pngfile & print, ""
      im.save, pngfile, RESOLUTION=300
      im.close
   ENDIF ELSE BEGIN
      doodah = ""
      bustOut=0
      READ, doodah, PROMPT="Enter S to Save plot and continue, " + $
            "SQ to Save plot and Quit, Q to Quit, or any other key to display next plot type(s): "
      CASE STRUPCASE(doodah) OF
        "SQ" : BEGIN
                 print, '' & print, "PNGFILE: ",pngfile & print, ""
                 bustOut=1
                 im.save, pngfile, RESOLUTION=300
                 im.close
               END
         "S" : BEGIN
                 print, '' & print, "PNGFILE: ",pngfile & print, ""
                 im.save, pngfile, RESOLUTION=300
                 im.close
               END
         "Q" : BEGIN
                 bustOut=1
                 im.close
               END
        ELSE : IF have_hist.(idx2do)[haveVar, raintypeBBidx] EQ 1 THEN im.close
     ENDCASE
     if bustOut then BREAK
   ENDELSE

ENDIF ELSE print, "No data for " + PlotTypes(idx2do)+ '_'+ rntypeLabels[raintypeBBidx]+BB_string

ENDFOR
if bustOut then BREAK
endfor

noScatterPlots:

IF N_ELEMENTS(profile_save) NE 0 AND bustOut NE 1 THEN BEGIN
   ; Compute ensemble mean and StdDev of dBZ at each level from grouped data
   ; and save to variables used in plot_mean_profiles.pro.
   bindbz = DOUBLE(bindbz)
   bindbzsq = bindbz^2
   sourcetext = ['PR (All)  : ', 'PR (Strat): ', 'PR (Conv) : ', $
                 'GR (All)  : ', 'GR (Strat): ', 'GR (Conv) : ']
   prmnarr = FLTARR(nhgtcats) & cprmnarr = prmnarr & sprmnarr = prmnarr
   grmnarr = FLTARR(nhgtcats) & cgrmnarr = grmnarr & sgrmnarr = grmnarr
   samples = LONARR(nhgtcats) & csamples = samples & ssamples = samples
   cprsdarr = prmnarr & sprsdarr = prmnarr & prsdarr = prmnarr
   cgrsdarr = grmnarr & sgrsdarr = grmnarr & grsdarr = prmnarr

   for lev2get = 0, nhgtcats-1 do begin
      hgtstr =  string(heights[lev2get], FORMAT='(f0.1)')
      for sourcetype = 0,5 do begin
         ; initialize stats to no data situation
         numz = 0L
         meanz = -99.99D
         stddevz = -99.99D
         ; check whether pointer has been assigned, and if so, compute stats
         IF *accum_ptrs[sourcetype,lev2get] NE !NULL THEN BEGIN
            stddevz = get_grouped_data_mean_stddev(*accum_ptrs[sourcetype,lev2get], $
                                                   bindbz, bindbzsq, meanz, numz)
            ptr_free, accum_ptrs[sourcetype,lev2get]
         ENDIF
         PRINT, hgtstr, "  ", sourcetext[sourcetype], meanz, stddevz, numz
         CASE sourcetype OF
           0 : BEGIN
               prmnarr[lev2get]=meanz & prsdarr[lev2get]=stddevz & samples[lev2get]=numz
               END
           1 : BEGIN
               sprmnarr[lev2get]=meanz & sprsdarr[lev2get]=stddevz & ssamples[lev2get]=numz
               END
           2 : BEGIN
               cprmnarr[lev2get]=meanz & cprsdarr[lev2get]=stddevz & csamples[lev2get]=numz
               END
           3 : BEGIN
               grmnarr[lev2get]=meanz & grsdarr[lev2get]=stddevz
               END
           4 : BEGIN
               sgrmnarr[lev2get]=meanz & sgrsdarr[lev2get]=stddevz
               END
           5 : BEGIN
               cgrmnarr[lev2get]=meanz & cgrsdarr[lev2get]=stddevz
               END
         ENDCASE
      endfor
   endfor

  ; check the status of profile_save.  If it's a directory and it exists, format
  ; a filename to be used for the save file and save it under profile_save.  If
  ; it's a file pathname and the directory exists, just use what is provided as
  ; the save file name.  Otherwise use outpath as the save file location and
  ; format a name for the file.
   make_savname = 0
   fileStruct = FILE_INFO(profile_save)
   IF fileStruct.DIRECTORY EQ 1 THEN BEGIN
      outpath_sav = profile_save
      make_savname = 1
   ENDIF ELSE BEGIN
      fileStruct = FILE_INFO( FILE_DIRNAME(profile_save) )
      IF fileStruct.DIRECTORY EQ 1 THEN BEGIN
         make_savname = 0
         savfile = profile_save
      ENDIF ELSE BEGIN
         print, "Directory ", FILE_DIRNAME(profile_save), " does not exist."
         print, "Formatting a SAVE file name under path: ", outpath_sav
         make_savname = 1
      ENDELSE
   ENDELSE
   IF make_savname THEN BEGIN
      IF ( s2ku ) THEN savfile = outpath_sav+'/StatsProfiles_'+pr_or_dpr+'_GR_Pct'+ $
                          strtrim(string(pctAbvThresh),2)+addme+'_S2Ku.sav' $
      ELSE savfile = outpath_sav+'/StatsProfiles_'+pr_or_dpr+'_GR_Pct'+ $
              strtrim(string(pctAbvThresh),2)+addme+'_DefaultS.sav'
   ENDIF

   PRINT, "Save ensemble profile variables to: ", savfile
   hgtarr = TEMPORARY(heights)
   SAVE, cprmnarr, cgrmnarr, cprsdarr, cgrsdarr, csamples,  $
         sprmnarr, sgrmnarr, sprsdarr, sgrsdarr, ssamples,  $
          prmnarr,  grmnarr,  prsdarr,  grsdarr,  samples,  $
         hgtarr, FILE = savfile
    plot_mean_profiles, savfile, FILE_BASENAME(savfile), INSTRUMENT=pr_or_dpr
   thePlot = fplot_mean_profiles( savfile, FILE_BASENAME(savfile), $
                                  INSTRUMENT=pr_or_dpr, LEGEND_XY=[0.9,0.83] )
ENDIF

FOR iplot = 0, nPlots-1 DO BEGIN
  for irntypebb = 0,1 do begin
     ;print, "Freeing plotDataPtrs[", iPlot, irntypebb, "]"
     ptr_free, plotDataPtrs[iPlot, irntypebb]
  endfor
ENDFOR

cleanUp:

; pass memory of local-named data field array/structure names back to pointer variables
*ptr_geometa=temporary(mygeometa)
*ptr_sitemeta=temporary(mysite)
*ptr_sweepmeta=temporary(mysweeps)
*ptr_fieldflags=temporary(myflags)
*ptr_gvz=temporary(gvz)
*ptr_zraw=temporary(zraw)
*ptr_zcor=temporary(zcor)
*ptr_pia=temporary(PIA)
IF have_maxraw250 THEN *ptr_250maxzraw=temporary(maxraw250)
*ptr_rain3=temporary(DPR_RR)
 *ptr_gvzmax=temporary(gvzmax)
 *ptr_gvzstddev=temporary(gvzstddev)
*ptr_nearSurfRain=temporary(nearSurfRain)
*ptr_nearSurfRain_2b31=temporary(nearSurfRain_2b31)
; *ptr_rnflag=temporary(rnFlag)
*ptr_rntype=temporary(rnType)
IF pr_or_dpr EQ 'DPR' THEN *ptr_stmTopHgt = temporary(echoTops)
*ptr_bbProx=temporary(bbProx)
*ptr_hgtcat=temporary(hgtcat)
*ptr_dist=temporary(dist)
*ptr_pctgoodpr=temporary(pctgoodpr)
*ptr_pctgoodgv=temporary(pctgoodgv)
*ptr_pctgoodrain=temporary(pctgoodrain)

;  free the memory held by the pointer variables
if (ptr_valid(ptr_geometa) eq 1) then ptr_free,ptr_geometa
if (ptr_valid(ptr_sitemeta) eq 1) then ptr_free,ptr_sitemeta
if (ptr_valid(ptr_sweepmeta) eq 1) then ptr_free,ptr_sweepmeta
if (ptr_valid(ptr_fieldflags) eq 1) then ptr_free,ptr_fieldflags
if (ptr_valid(ptr_gvz) eq 1) then ptr_free,ptr_gvz
if (ptr_valid(ptr_zraw) eq 1) then ptr_free,ptr_zraw
if (ptr_valid(ptr_zcor) eq 1) then ptr_free,ptr_zcor
if (ptr_valid(ptr_pia) eq 1) then ptr_free,ptr_pia
if (ptr_valid(ptr_250maxzraw) eq 1) then ptr_free,ptr_250maxzraw
if (ptr_valid(ptr_rain3) eq 1) then ptr_free,ptr_rain3
 if (ptr_valid(ptr_gvzmax) eq 1) then ptr_free,ptr_gvzmax
 if (ptr_valid(ptr_gvzstddev) eq 1) then ptr_free,ptr_gvzstddev
if (ptr_valid(ptr_nearSurfRain) eq 1) then ptr_free,ptr_nearSurfRain
if (ptr_valid(ptr_nearSurfRain_2b31) eq 1) then ptr_free,ptr_nearSurfRain_2b31
;if (ptr_valid(ptr_rnFlag) eq 1) then ptr_free,ptr_rnFlag
if (ptr_valid(ptr_rnType) eq 1) then ptr_free,ptr_rnType
IF pr_or_dpr EQ 'DPR' THEN if (ptr_valid(ptr_stmTopHgt) eq 1) then ptr_free,ptr_stmTopHgt
if (ptr_valid(ptr_bbProx) eq 1) then ptr_free,ptr_bbProx
if (ptr_valid(ptr_hgtcat) eq 1) then ptr_free,ptr_hgtcat
if (ptr_valid(ptr_dist) eq 1) then ptr_free,ptr_dist
if (ptr_valid(ptr_pctgoodpr) eq 1) then ptr_free,ptr_pctgoodpr
if (ptr_valid(ptr_pctgoodgv) eq 1) then ptr_free,ptr_pctgoodgv
if (ptr_valid(ptr_pctgoodrain) eq 1) then ptr_free,ptr_pctgoodrain
if (ptr_valid(ptr_GR_blockage) eq 1) then ptr_free, ptr_GR_blockage
; help, /memory

print, ''
print, 'Done!'

errorExit:


IF N_ELEMENTS(profile_save) NE 0 THEN BEGIN
   print, ''
   print, 'SAVE file status:'
   command = 'ls -al ' + savfile
   spawn, command
   print, ''
ENDIF

; determine whether user wants to leave profile plot up with a reference to it
; returned in optional plot_obj_array, or just close it

IF N_ELEMENTS(thePlot) NE 0 THEN BEGIN
   IF SIZE(thePlot, /TYPE) EQ 11 THEN BEGIN
      doodah = ""
      READ, doodah, PROMPT="Enter C to Close plot(s) and exit, " + $
            "or any other key to exit with plot(s) remaining: "
      IF STRUPCASE(doodah) EQ "C" THEN BEGIN
         thePlot.close
      ENDIF ELSE BEGIN
        ; see whether the caller has given us a variable to return the PLOT
        ; and IMAGE object references in
         IF N_ELEMENTS(plot_obj_array) NE 0 THEN BEGIN
            plot_obj_array = OBJARR(1)
            plot_obj_array[0] = thePlot   ; mean profile plot object only
         ENDIF
      ENDELSE
   ENDIF
ENDIF

errorExit2:
CLOSE, Unit
end
