;+
;  z_rain_dsd_profile_scatter_v2.pro     Morris/SAIC/GPM_GV   July 2016
;
; DESCRIPTION
; -----------
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
;    'HID': Hydrometeor ID histogram
;'MRMSDSR': MRMS surface RR vs. DPR near sfc RR (x vs y)
;'GRRMRMS': GR sfc RR (lowest level) vs MRMS surface RR 
;'GRCMRMS': GR sfc RC (lowest level) vs MRMS surface RR 
;'GRPMRMS': GR sfc RP (lowest level) vs MRMS surface RR 
; 'GRRDSR': GR sfc RR (lowest level) vs DPR near sfc RR 
; 'GRCDSR': GR sfc RC (lowest level) vs DPR near sfc RR 
; 'GRPDSR': GR sfc RP (lowest level) vs DPR near sfc RR 
; 'GRZSH' : GR Z standard deviation histogram (above & below BB)
;'GRDMSH' : GR Dm standard deviation histogram (below BB)
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
;                 reflectivity.  Does not affect histograms for other
;                 variables.
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
; Z_FILTER_STRAT - Optional parameters.  Specifies [min max]  of Zm or Zc
; Z_FILTER_CONV    to use as a filtered range.  All samples with Z values outside
;                  the range are filtered out.  If only one of these is specified,
;                  the other defaults to specified range.
; Z_FILTER_TYPE  - Optional parameter.  Specifies the type of Z filtering
;                  'ZC' (DPR Zcor), 'ZM' (DPR Zraw), or 'GVZ'.  Defaults to 'ZC'
;                  if either Z_FILTER_STRAT or Z_FILTER_CONV are specified, otherwise
;                  defaults to 'none'
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
;    regardless of rain type.  Defined a variable satprodtype for labeling in
;    this plot.
;  - Changed threshold of small histogram percents to be blanked from 5 to 0.1
;    and activated blanking to clean up plots.
; 03/02/17 Morris, GPM GV, SAIC
;  - Added checks for existence of in-range X and Y data in accum_scat_data to
;    prevent anomalous results from HIST_2D and/or HISTOGRAM from contaminating
;    the statistics when X or Y have no values between their binmin and binmax.
;  - Modified rain rate accumulations and plots to make convective RR the same
;    as stratiform in terms of ranges, bins, etc.
;  - Cleaned out unused code lines/blocks.
; 03/07/17 Morris, GPM GV, SAIC
;  - Added plots of DPR PIA vs. Dm.  Fixed new bug related to not clipping PIA
;    after reading it from matchup file.
; 03/08/17 Morris, GPM GV, SAIC
;  - Added option to subset data to rays where DPR Dm below-BB and at/below 3 km
;    meets or exceeds a threshold specified as DPR_DM_THRESH.
;  - Changed titles of plots to indicate specific product type (e.g. 2AKu)
;    rather than generic DPR or DPRGMI labeling.
; 03/14/17 Morris, GPM GV, SAIC
;  - Activated ray_range option for DPR and DPRGMI types.  Before this the
;    keyword/value were just a do-nothing.
;  - Implemented a combination flag2filter array to cumulatively tag samples to
;    be filtered by multiple criteria evaluated in sequence.
; 04/04/17 Morris, GPM GV, SAIC
;  - FIXED dumb mistake in checks for existence of in-range X and Y data in
;    accum_scat_data that sometimes rejected valid cases.
;  - Expanded the range and bin size for convective rain rate histograms and
;    plots to capture the observed data ranges (reversed unwise 3/2/17 change).
;  - Added a variable 'trim' to control the amount of noise smoothing in the
;    scatter plots and show more outliers in the convective RR.
; 04/07/17 Morris, GPM GV, SAIC
;  - Added Any/All rain type scatter plots for every element.  Below-BB for all
;    elements except Z, which is any/all above-BB.  Removed now-redundant DMANY
;    plot type.
;  - Added computation and annotation of normalized rain rate bias for RR plots.
; 07/14/17 Morris, GPM GV, SAIC
;  - Restricted values included in the 1-D Histogram in accum_scat_data to only
;    those within the histogram range for both X and Y input data arrays.
; 07/25/17 Berendes, GPM GV, UAH
;  - Added Z_FILTER_MIN and Z_FILTER_MAX parameters to provide filtering using
;    Zm or Zc ranges. 
; 03/02/18 Berendes, GPM GV, UAH
;  - Merged compatibility for additional MRMS fields
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
                     plotIndex, raintypeBBidx, rr_log_x, rr_log_y, log_bins

; position indices/definitions of the 3 flags in the arrays in the structure
; - must be as initially defined in z_rain_dsd_profile_scatter_all.pro
haveVar = 0   ; do we have data for the variable
have1D  = 1   ; does the accumulating 2-D histogram for the variable exist yet?
have2D  = 2   ; does the accumulating 1-D histogram for the variable exist yet?

; apply log10 scaling if requested
;			  if rr_log_x then begin
;				;    print, 'X log scale'
;					idx_zero = where(scat_X le 0, num_zero)
;					idx_not_zero = where(scat_X gt 0, num_not_zero)
;					; put zeros in max bin which is filtered out later
;					if num_zero gt 0 then scat_X[idx_zero] = binmax1
;					if num_not_zero gt 0 then scat_X[idx_not_zero] = ALOG10(scat_X[idx_not_zero])
					
;			  endif
;			  if rr_log_y then begin
;				;    print, 'Y log scale'
;					idx_zero = where(scat_Y le 0, num_zero)
;;					idx_not_zero = where(scat_Y gt 0, num_not_zero)
;					; put zeros in max bin which is filtered out later
;					if num_zero gt 0 then scat_Y[idx_zero] = binmax2
;					if num_not_zero gt 0 then scat_Y[idx_not_zero] = ALOG10(scat_Y[idx_not_zero])
;			  endif 

; get a short version of the array pointer being worked
aptr = (ptrData_array)[plotIndex,raintypeBBidx]

;         PRINT, '******************************************************'
;         print, "Getting "+plotTypes[plotIndex]+' SAMPLES FOR HISTOGRAM.'
;         PRINT, '******************************************************'

  ; Check whether the arrays to be histogrammed both have in-range values,
  ; otherwise just skip trying to histogram out-of-range data
   idx_XY = WHERE(scat_X GE binmin1 AND scat_X LE binmax1 $
              AND scat_Y GE binmin2 AND scat_Y LE binmax2, count_XY)
   IF (count_XY GT 0) THEN BEGIN


; this sets up for constant log scale bins
;***************
;		  if rr_log_x or rr_log_y then begin
;			  scat_logX = scat_X[idx_XY]
;			  binmin1log=binmin1
;			  binmax1log=binmax1
;			  binspan1log = binspan1
;			  scat_logY = scat_Y[idx_XY]
;			  binmin2log=binmin2
;			  binmax2log=binmax2
;			  binspan2log = binspan2
;			  if rr_log_x then begin
				;    print, 'X log scale'
;					scat_logX = ALOG10(scat_X[idx_XY])
;					binmin1log=ALOG10(binmin1)
;					binmax1log=ALOG10(binmax1)
;					; use 100 bins for 2d histogram, may want to pass as parameter
;					; instead of binspan
;					binspan1log = (binmax1log - binmin1log) / 100.0
;					
;			  endif
;			  if rr_log_y then begin
				;    print, 'Y log scale'
;					scat_logY = ALOG10(scat_Y[idx_XY])
;					binmin2log=ALOG10(binmin2)
;					binmax2log=ALOG10(binmax2)
;					; use 100 bins for 2d histogram, may want to pass as parameter
;					; instead of binspan
;					binspan2log = (binmax2log - binmin2log) / 100.0
;			  endif 
;		      zhist2d = HIST_2D( scat_logX, scat_logY, MIN1=binmin1log, $
;		                      MIN2=binmin2log, MAX1=binmax1log, MAX2=binmax2log, $
;		                      BIN1=BINSPAN1log, BIN2=BINSPAN2log )
;          endif else begin 
;		      zhist2d = HIST_2D( scat_X, scat_Y, MIN1=binmin1, $
;		                      MIN2=binmin2, MAX1=binmax1, MAX2=binmax2, $
;		                      BIN1=BINSPAN1, BIN2=BINSPAN2 )
;          
;          endelse

; ************
; this sets up for constant linear scale bins which are used in contour for log scale plotting
		  if rr_log_x or rr_log_y then begin
			  scat_logX = scat_X[idx_XY]
			  binmin1log=binmin1
			  binmax1log=binmax1
			  binspan1log = binspan1
			  scat_logY = scat_Y[idx_XY]
			  binmin2log=binmin2
			  binmax2log=binmax2
			  binspan2log = binspan2
			  if rr_log_x then begin
				;    print, 'X log scale'
					if log_bins then begin
						scat_logX = ALOG10(scat_X[idx_XY])
						binmin1log=ALOG10(binmin1)
						binmax1log=ALOG10(binmax1)
					endif
					
					; use 100 bins for 2d histogram, may want to pass as parameter
					; instead of binspan
					binspan1log = (binmax1log - binmin1log) / 200.0
					
			  endif
			  if rr_log_y then begin
					if log_bins then begin
						scat_logY = ALOG10(scat_Y[idx_XY])
						binmin2log=ALOG10(binmin2)
						binmax2log=ALOG10(binmax2)
					endif
				;    print, 'Y log scale'
					; use 100 bins for 2d histogram, may want to pass as parameter
					; instead of binspan
					binspan2log = (binmax2log - binmin2log) / 200.0
			  endif 
		      zhist2d = HIST_2D( scat_logX, scat_logY, MIN1=binmin1log, $
		                      MIN2=binmin2log, MAX1=binmax1log, MAX2=binmax2log, $
		                      BIN1=BINSPAN1log, BIN2=BINSPAN2log )
          endif else begin 
		      zhist2d = HIST_2D( scat_X, scat_Y, MIN1=binmin1, $
		                      MIN2=binmin2, MAX1=binmax1, MAX2=binmax2, $
		                      BIN1=BINSPAN1, BIN2=BINSPAN2 )
          endelse


                            
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

           if rr_log_x or rr_log_y then begin 
               iostruct2 = { zhist2d:zhist2d, minprz:minprz, numpts:numpts, $
               binmin1:binmin1log, binmin2:binmin2log, binmax1:binmax1log, binmax2:binmax2log, $
               binspan1:binspan1log, binspan2:binspan2log, $
               xlog:rr_log_x, ylog:rr_log_y}                    
           endif else begin
               iostruct2 = { zhist2d:zhist2d, minprz:minprz, numpts:numpts, $
               binmin1:binmin1, binmin2:binmin2, binmax1:binmax1, binmax2:binmax2, $
               binspan1:binspan1, binspan2:binspan2, $
               xlog:rr_log_x, ylog:rr_log_y}          
           endelse
         ENDELSE
        ; compute the mean X (gv) for the samples in each Y (pr) histogram bin
        ; -- restrict the samples to those where both scat_X and scat_Y are within
        ;    the histogram bounds or else we can get some bad scat_X values included
        ;    in the gvzmeanByBin calculations, as we learned the hard way.
         y2do = scat_Y[idx_XY]
         x2do = scat_X[idx_XY]
         zhist1dpr=HISTOGRAM(y2do, MIN=binmin2, MAX=binmax2, BINSIZE=BINSPAN2, $
                             LOCATIONS=Zstarts, REVERSE_INDICES=RIdpr)
         ndprbins=N_ELEMENTS(Zstarts)
         gvzmeanByBin=FLTARR(ndprbins)
         przmeanByBin = gvzmeanByBin
         MAEbyBin = gvzmeanByBin
         nbybin = lonarr(ndprbins)
         for ibin = 0, ndprbins-1 do begin
            IF RIdpr[ibin] NE RIdpr[ibin+1] THEN BEGIN
               gvzmeanByBin[ibin] = MEAN( x2do[ RIdpr[RIdpr[ibin] : RIdpr[ibin+1]-1] ] )
               przmeanByBin[ibin] = MEAN( y2do[ RIdpr[RIdpr[ibin] : RIdpr[ibin+1]-1] ] )
               MAEbyBin[ibin] = ABS(gvzmeanByBin[ibin]-przmeanByBin[ibin])
               nbybin[ibin] = RIdpr[ibin+1]-RIdpr[ibin]
            ENDIF
         endfor
;IF plotTypes[plotIndex] EQ 'RR' THEN BEGIN
;         print, "locations: ", Zstarts
;         print, "gvzmeanByBin: ", gvzmeanByBin
;         print, "przmeanByBin: ", przmeanByBin
;stop
;ENDIF
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

FUNCTION log_ticks
;===============================================================================
; 
;===============================================================================

   xticknames=['0.01','0.1','1','10','100']
   return, xticknames
end
   

FUNCTION log_label, num_pts, scale
;===============================================================================
; 
;===============================================================================

	indices=FINDGEN(num_pts)*scale

;	indices(0)=0.01
;	indices=FINDGEN(num_pts)*scale
;	l_idx=where(indices gt 0)
;	indices[l_idx]=ALOG10(indices[l_idx])
	xticknames=STRING(indices, FORMAT='(F0.2)')
	return, xticknames

END


;===============================================================================
; MODULE 1 (Main Module)
;===============================================================================

FUNCTION RR_DM_funct, X, A
; First, define a return function for LMFIT:
   ; function is A[0]*X^A[1]
   RETURN,[ A[0]*X^A[1], X^A[1], alog(X)*A[0]*X^A[1] ]
END

PRO z_rain_dsd_profile_scatter_v2, INSTRUMENT=instrument,         $
                                    KUKA=KuKa, SCANTYPE=swath,     $
                                    PCT_ABV_THRESH=pctAbvThresh,   $
                                    GV_CONVECTIVE=gv_convective,   $
                                    GV_STRATIFORM=gv_stratiform,   $
                                    S2KU=s2ku,                     $
                                    NAME_ADD=name_add,             $
                                    NCSITEPATH=ncsitepath,         $
                                    FILEPATTERN=filepattern,       $
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
                                    DPR_DM_THRESH=dpr_dm_thresh_in,$
                                    DPR_DM_RANGE=dpr_dm_range_in,$
                                    VERSION2MATCH=version2match,   $
                                    BATCH_SAVE=batch_save,         $
                                    DPR_Z_ADJUST=dpr_z_adjust,     $
                                    GR_Z_ADJUST=gr_z_adjust,       $
                                    Z_FILTER_STRAT=zfilterstrat,       $
                                    Z_FILTER_CONV=zfilterconv,       $
                                    Z_FILTER_TYPE=zfilterinput,       $
                                    ET_RANGE=et_range, $
                                    RR_LOG=rr_log

; "include" file for structs returned by read_geo_match_netcdf()
@geo_match_nc_structs.inc
; "include" file for PR data constants
@pr_params.inc

IF FLOAT(!version.release) lt 8.1 THEN message, "Requires IDL 8.1 or later."
; TAB 12/4/17 make this a parameter if we want to be permanent
do_RR_DM_curve_fit = 0
; 0= st below bb, 1=conv below bb, 2=all below bb 
RR_DM_curve_fit_bb_type = 0
dump_hist_csv=1
log_bins=0

if do_RR_DM_curve_fit eq 1 then begin

    rr_dm_x = []
    rr_dm_y = []
endif

; this is really just a QC step right now on the altfield value, except for
; setting use_zraw flag for ZM case
IF N_ELEMENTS(altfield) EQ 1 THEN BEGIN
   CASE STRUPCASE(altfield) OF
       'ZM' : z2do = 'Zm'
       'ZC' : z2do = 'Zc'
       'D0' : z2do = 'D0'
       'DM' : z2do = 'Dm'
;     'DMANY': z2do = 'DmAny'
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
       'HID': z2do = 'HID'
       ELSE : message, "Invalid ALTFIELD value, must be one of: " + $
              "ZC, ZM, D0, DM, NW, N2, RR, RC, RP, ZCNWG, NWDMG, ZCNWP" + $
              ", NWDMP, DMRRG, RRNWG, DMRRP, RRNWP, NWGZMXP, EPSI, HID"
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

; TAB 7/25/17
; defaults for Z filtering
zfilter_type='none'
filteraddstring=''
filtertitlestring=''
IF N_ELEMENTS(zfilterinput) EQ 1 THEN BEGIN
   CASE STRUPCASE(zfilterinput) OF
      'ZC': zfilter_type = 'ZC'
      'ZM': zfilter_type = 'ZM'
      'GVZ': zfilter_type = 'GVZ'
       ELSE : message, "Invalid Z_FILTER_TYPE " + zfilterinput + " must be ZC, ZM, or GVZ"
   ENDCASE
   print, 'Filtering by ' + zfilter_type
ENDIF 
;  if Z_FILTER_TYPE is set but neither Z_FILTER_STRAT or Z_FILTER_CONV is set, exit with error
;  if Z_FILTER_STRAT or Z_FILTER_CONV is set, but not both, set them both to the same specified values 
IF N_ELEMENTS(zfilterstrat) GT 0 THEN BEGIN
   if N_ELEMENTS(zfilterstrat) NE 2 THEN message,"Error:  Z_FILTER_STRAT must be 2 element array"
   IF zfilter_type eq 'none' THEN zfilter_tpye = 'ZC'
   IF N_ELEMENTS(zfilterconv) EQ 0 THEN zfilterconv=zfilterstrat  
ENDIF 
IF N_ELEMENTS(zfilterconv) GT 0 THEN BEGIN
   if N_ELEMENTS(zfilterconv) NE 2 THEN message,"Error:  Z_FILTER_CONV must be 2 element array"
   IF zfilter_type eq 'none' THEN zfilter_tpye = 'ZC'
   IF N_ELEMENTS(zfilterstrat) EQ 0 THEN zfilterstrat=zfilterconv  
ENDIF 
; must specify at least one of conv or strat filter thresholds to use filtering
IF N_ELEMENTS(zfilterstrat) EQ 0 AND N_ELEMENTS(zfilterconv) EQ 0 THEN zfilter_type='none'
;IF KEYWORD_SET(Z_FILTER_CONV) THEN BEGIN
;   if N_ELEMENTS(Z_FILTER_CONV) NE 2 THEN message,"Error:  Z_FILTER_CONV must be 2 element array"
;   IF ~KEYWORD_SET(Z_FILTER_TYPE) THEN zfilter_tpye = 'ZC'
;   IF ~KEYWORD_SET(Z_FILTER_STRAT) THEN zfilterstrat=zfilterconv  
;ENDIF 
IF zfilter_type NE 'none' THEN BEGIN
   cvfilterstring=STRING(zfilterconv[0],zfilterconv[1],format='(I0,"-",I0)')	
   stfilterstring=STRING(zfilterstrat[0],zfilterstrat[1],format='(I0,"-",I0)')	
;   stfilterstring=STRING(zfilterstrat[0]) + '-' + STRING(zfilterstrat[1])	
   filteraddstring = '_' + zfilter_type + '_C' +  cvfilterstring + '_S' + stfilterstring
   filtertitlestring = zfilter_type + ' C ' +  cvfilterstring + ', S ' + stfilterstring
ENDIF
; check for ray_range restrictions and add to titles and filenames
IF N_ELEMENTS(ray_range) EQ 2 THEN BEGIN
   IF ray_range[0] LT ray_range[1] THEN BEGIN
      filteraddstring = filteraddstring + '_Inner_' + STRING(ray_range[0],ray_range[1],format='(I0,"-",I0)')
      filtertitlestring = filtertitlestring + 'Inner ' + STRING(ray_range[0],ray_range[1],format='(I0,"-",I0)')
   ENDIF ELSE BEGIN
      filteraddstring = filteraddstring + '_Outer_' + STRING(ray_range[1],ray_range[0],format='(I0,"-",I0)')
      filtertitlestring = filtertitlestring + 'Outer ' + STRING(ray_range[1],ray_range[0],format='(I0,"-",I0)')
   ENDELSE
ENDIF

; TAB 11/14/17 added accumulator for HID
; indexed by raintypeBBidx and 11 categories 
;  HID_categories = [ 'MIS','DZ','RN','CR','DS','WS','VI','LDG','HDG','HA','BD','HR' ]
;  HID_categories = [ 'MIS','DZ','RN','CR','DS','WS','VI','LDG','HDG','HA','BD','HR' ]
  HID_categories = [ 'MIS','DZ','RN','CR','DS','WS','VI','LDG','HDG','HA','BD','HR','AHA' ]
;  HID_histogram = INTARR(4,15)
;  HID_histogram1 = LONARR(4,12)
  HID_histogram1 = LONARR(4,13)
  HID_histogram2= LONARR(4,13)
  
; accumulators for:
; 'GRZSH' : GR Z standard deviation histogram (above & below BB)
;'GRDMSH' : GR Dm standard deviation histogram (below BB)

GRZSH_above_3 = []
GRZSH_above_4 = []
GRZSH_below_c = []
GRZSH_below_s = []
GRDMSH_below_c = []
GRDMSH_below_s = []

;TAB 8/12/17
; LUN for writing anomaly info to file
openw, anom_LUN, outpath + '/anomaly.txt', /GET_LUN
openw, hail_LUN, outpath + '/hail.txt', /GET_LUN

; determine whether to display the scatter plot objects or just create them
; in a buffer for saving in batch mode
IF KEYWORD_SET(batch_save) THEN buffer=1 ELSE buffer=0

; set up plot-specific flags for presence of data and 1-D and 2-D Histograms
; of the data.  First triplet of values are for stratiform/aboveBB, 2nd triplet
; is convective/belowBB, 3rd is Any/All
; TAB 11/13/17 added fourth dimension for above BB convective
have_Hist = { GRZSH : [[0,0,0],[0,0,0],[0,0,0],[0,0,0]], $
			 GRDMSH : [[0,0,0],[0,0,0],[0,0,0],[0,0,0]], $
				HID : [[0,0,0],[0,0,0],[0,0,0],[0,0,0]], $
            MRMSDSR : [[0,0,0],[0,0,0],[0,0,0],[0,0,0]], $
            GRRMRMS : [[0,0,0],[0,0,0],[0,0,0],[0,0,0]], $
            GRCMRMS : [[0,0,0],[0,0,0],[0,0,0],[0,0,0]], $
            GRPMRMS : [[0,0,0],[0,0,0],[0,0,0],[0,0,0]], $
             GRRDSR : [[0,0,0],[0,0,0],[0,0,0],[0,0,0]], $
             GRCDSR : [[0,0,0],[0,0,0],[0,0,0],[0,0,0]], $
             GRPDSR : [[0,0,0],[0,0,0],[0,0,0],[0,0,0]], $
                 ZM : [[0,0,0],[0,0,0],[0,0,0],[0,0,0]], $
              DMRRG : [[0,0,0],[0,0,0],[0,0,0],[0,0,0]], $
                 ZC : [[0,0,0],[0,0,0],[0,0,0],[0,0,0]], $
                 D0 : [[0,0,0],[0,0,0],[0,0,0],[0,0,0]], $
                 DM : [[0,0,0],[0,0,0],[0,0,0],[0,0,0]], $
;              DMANY : [[0,0,0],[0,0,0],[0,0,0],[0,0,0]], $
                 NW : [[0,0,0],[0,0,0],[0,0,0],[0,0,0]], $
                 N2 : [[0,0,0],[0,0,0],[0,0,0],[0,0,0]], $
                 RR : [[0,0,0],[0,0,0],[0,0,0],[0,0,0]], $
                 RC : [[0,0,0],[0,0,0],[0,0,0],[0,0,0]], $
                 RP : [[0,0,0],[0,0,0],[0,0,0],[0,0,0]], $
              ZCNWG : [[0,0,0],[0,0,0],[0,0,0],[0,0,0]], $
              NWDMG : [[0,0,0],[0,0,0],[0,0,0],[0,0,0]], $
              ZCNWP : [[0,0,0],[0,0,0],[0,0,0],[0,0,0]], $
              NWDMP : [[0,0,0],[0,0,0],[0,0,0],[0,0,0]], $
              RRNWG : [[0,0,0],[0,0,0],[0,0,0],[0,0,0]], $
              DMRRP : [[0,0,0],[0,0,0],[0,0,0],[0,0,0]], $
              RRNWP : [[0,0,0],[0,0,0],[0,0,0],[0,0,0]], $
            NWGZMXP : [[0,0,0],[0,0,0],[0,0,0],[0,0,0]], $
             PIADMP : [[0,0,0],[0,0,0],[0,0,0],[0,0,0]], $
               EPSI : [[0,0,0],[0,0,0],[0,0,0],[0,0,0]] }
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
;rntypeLabels = ['Stratiform', 'Convective', 'AllTypes']
rntypeLabels = ['Stratiform', 'Convective', 'AllTypes', 'Convective']

; define a 2-D array of pointers to data accumulations, histograms, etc., in a
; structure created in call to accum_scat_data().  2nd dimension is data subset
; being accumulated (0 = ConvectiveAboveBB, 1 = StratiformBelowBB, 2 = Any/All)
;plotDataPtrs = PTRARR(nPlots, 3, /ALLOCATE_HEAP)
; TAB 11/13/17 changed this to add new fourth category, convective above BB
; being accumulated (0 = ConvectiveBelowBB, 1 = StratiformBelowBB, 2 = Any/All, 3=ConvectiveAboveBB)
plotDataPtrs = PTRARR(nPlots, 4, /ALLOCATE_HEAP)

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

; set some conservative allowed range for dpr_dm_thresh, if specified
do_dm_thresh = 0
IF N_ELEMENTS(dpr_dm_thresh_in) EQ 1 THEN BEGIN
   IF is_a_number(dpr_dm_thresh_in) THEN BEGIN
      dpr_dm_f = FLOAT(dpr_dm_thresh_in)
      IF dpr_dm_f LT 0.5 OR dpr_dm_f GT 5.0 THEN BEGIN
         help, dpr_dm_thresh_in
         message, "Out of range dpr_dm_thresh value, " + $
                  "must be between 0.5 and 5.0 (mm)"
      ENDIF ELSE BEGIN
         dpr_dm_thresh = dpr_dm_f
         do_dm_thresh = 1
      ENDELSE
   ENDIF ELSE BEGIN
      help, dpr_dm_thresh_in
      message, "Illegal dpr_dm_thresh type, " + $
               "must be a number between 0.5 and 5.0"
   ENDELSE
ENDIF

; set some conservative allowed range for dpr_dm_range, if specified
do_dm_range = 0
IF N_ELEMENTS(dpr_dm_range_in) EQ 2 THEN BEGIN
   IF is_a_number(dpr_dm_range_in[0]) AND is_a_number(dpr_dm_range_in[1]) THEN BEGIN
      dpr_dm_range_min = FLOAT(min(dpr_dm_range_in))
      dpr_dm_range_max = FLOAT(max(dpr_dm_range_in))
      IF dpr_dm_range_min LT 0.5 OR dpr_dm_range_max GT 5.0 THEN BEGIN
         help, dpr_dm_range_in
         message, "Out of range dpr_dm_range value, " + $
                  "must be between 0.5 and 5.0 (mm)"
      ENDIF ELSE BEGIN
;         dpr_dm_range = dpr_dm_range_f
         do_dm_range = 1
      ENDELSE
   ENDIF ELSE BEGIN
      help, dpr_dm_range_in
      message, "Illegal dpr_dm_range type, " + $
               "must be a number between 0.5 and 5.0"
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
; Can't really do this until we know DPR_Dm is available
IF do_dm_thresh EQ 1 THEN addme = addme+'_Dm_GE_'+ $
                                  STRING(dpr_dm_thresh, FORMAT='(F3.1)')

;IF do_dm_range EQ 1 THEN addme = addme+'_Dm_LE_'+ $
;                                  STRING(dpr_dm_range, FORMAT='(F3.1)')
IF do_dm_range EQ 1 THEN addme = addme+'_Dm_'+ $
                                  STRING(dpr_dm_range_min, dpr_dm_range_max, FORMAT='("GE_",F3.1,"LE_",f3.1)')
                                  
IF do_dm_range EQ 1 AND do_dm_thresh EQ 1 THEN BEGIN
   message, "Error:  cannot do both dpr_dm_thresh and dpr_dm_range filtering." $
            +"  Quitting.", /INFO
   GOTO, cleanUp
ENDIF
s2ku = KEYWORD_SET( s2ku )
rr_log = KEYWORD_SET( rr_log )

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
;s2ku = KEYWORD_SET( s2ku )

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
prfiles = file_search(pathpr, filepat, COUNT=nf)
IF (nf LE 0) THEN BEGIN
   print, "" 
   print, "No files found for pattern = ", pathpr
   print, " -- Exiting."
   GOTO, errorExit
ENDIF
;help, nf, prfiles

; set up pointers for each field to be returned from fprep_geo_match_profiles()
ptr_BestHID=ptr_new(/allocate_heap)
ptr_HID=ptr_new(/allocate_heap)
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
; TAB 10/3/17
ptr_mrmsrrlow=ptr_new(/allocate_heap)
ptr_mrmsrrmed=ptr_new(/allocate_heap)
ptr_mrmsrrhigh=ptr_new(/allocate_heap)
ptr_mrmsrrveryhigh=ptr_new(/allocate_heap)

ptr_mrmsrqiplow=ptr_new(/allocate_heap)
ptr_mrmsrqipmed=ptr_new(/allocate_heap)
ptr_mrmsrqiphigh=ptr_new(/allocate_heap)
ptr_mrmsrqipveryhigh=ptr_new(/allocate_heap)

ptr_MRMS_HID=ptr_new(/allocate_heap)

;ptr_rnFlag=ptr_new(/allocate_heap)
ptr_rnType=ptr_new(/allocate_heap)
IF pr_or_dpr EQ 'DPR' THEN ptr_stmTopHgt=ptr_new(/allocate_heap)
ptr_pia=ptr_new(/allocate_heap)
ptr_bbProx=ptr_new(/allocate_heap)
ptr_bbHeight=ptr_new(/allocate_heap)
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
ptr_GR_DP_Dmstddev=ptr_new(/allocate_heap)
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
   IF parsed[0] EQ 'GRtoDPRGMI' THEN BEGIN
      satprodtype = '2BCMB'   ; use shorter ID than the "true" 2BDPRGMI
      IF N_ELEMENTS(swath) EQ 0 THEN swath='NS'
   ENDIF ELSE BEGIN
      type2A = parsed[5]
      CASE STRUPCASE(type2A) OF
        'DPR' : BEGIN
                  satprodtype = '2ADPR'
                  IF N_ELEMENTS(swath) EQ 0 THEN swath='NS'
                END
         'KA' :  BEGIN
                  satprodtype = '2AKa'
                  IF N_ELEMENTS(swath) EQ 0 THEN swath='MS'
                END
         'KU' :  BEGIN
                  satprodtype = '2AKu'
                  IF N_ELEMENTS(swath) EQ 0 THEN swath='NS'
                END
         ELSE :  BEGIN
                   message, "Cannot figure out satellite product type.", /INFO
                   satprodtype = ''
                 END
      ENDCASE
   ENDELSE
  ; merge the product type with the swath ID
   satprodtype = satprodtype + '/' + swath

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
    ; TAB 10/2/17
    status = fprep_dpr_geo_match_profiles_mrms( ncfilepr, heights, $
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
       PTRGVMODEHID=ptr_BestHID, PTRGVHID=ptr_HID, $
       PTRGVZDRMEAN=ptr_GR_DP_Zdr, PTRGVZDRMAX=ptr_GR_DP_Zdrmax,$
       PTRGVZDRSTDDEV=ptr_GR_DP_Zdrstddev, $
       PTRGVKDPMEAN=ptr_GR_DP_Kdp, PTRGVKDPMAX=ptr_GR_DP_Kdpmax, $
       PTRGVKDPSTDDEV=ptr_GR_DP_Kdpstddev, $
       PTRGVRHOHVMEAN=ptr_GR_DP_RHOhv, PTRGVRHOHVMAX=ptr_GR_DP_RHOhvmax, $
       PTRGVRHOHVSTDDEV=ptr_GR_DP_RHOhvstddev, $
       PTRstmTopHgt=ptr_stmTopHgt, PTRGVBLOCKAGE=ptr_GR_blockage, $
       PTRsfcrainpr=ptr_nearSurfRain, PTRsfcraincomb=ptr_nearSurfRain_2b31, $
       ; TAB 10/2/17
       ; MRMS radar variables
       PTRmrmsrrlow=ptr_mrmsrrlow, $
       PTRmrmsrrmed=ptr_mrmsrrmed, $
       PTRmrmsrrhigh=ptr_mrmsrrhigh, $
       PTRmrmsrrveryhigh=ptr_mrmsrrveryhigh, $

       PTRmrmsrqiplow=ptr_mrmsrqiplow, $
       PTRmrmsrqipmed=ptr_mrmsrqipmed, $
       PTRmrmsrqiphigh=ptr_mrmsrqiphigh, $
       PTRmrmsrqipveryhigh=ptr_mrmsrqipveryhigh, $
       PTRMRMSHID=ptr_MRMS_HID, $

       PTRrainflag_int=ptr_rnFlag, PTRraintype_int=ptr_rnType, PTRbbProx=ptr_bbProx, $
       PTRhgtcat=ptr_hgtcat, PTRdist=ptr_dist,PTRbbHgt=ptr_bbHeight,  $
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
       BB_RELATIVE=bb_relative, ALT_BB_HGT=alt_bb_file, FORCEBB=forcebb, $
       RAY_RANGE=ray_range)

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
       PTRtop=ptr_top, PTRbotm=ptr_botm, PTRbbHgt=ptr_bbHeight, $
       PTRsfcrainpr=ptr_nearSurfRain, PTRraintype_int=ptr_rnType, $
       PTRxCorners=ptr_xCorner, PTRyCorners=ptr_yCorner, PTRbbProx=ptr_bbProx, $
       PTRhgtcat=ptr_hgtcat, PTRdist=ptr_dist, PTRpridx_long=ptr_pr_index, $
       PTRpctgoodpr=ptr_pctgoodpr, PTRpctgoodgv=ptr_pctgoodgv, $
       PTRpctgoodrain=ptr_pctgoodrain, PTRpctgoodrcgv=ptr_pctgoodrcgv, $
       PTRpctgoodrpgv=ptr_pctgoodrpgv, PTRpctgoodrrgv=ptr_pctgoodrrgv, $
       PTRpctgoodDprDm=ptr_pctgoodDprDm, PTRpctgoodDprNw=ptr_pctgoodDprNw, $
       PTRpctgooddzerogv=ptr_pctgooddzerogv, PTRpctgoodnwgv=ptr_pctgoodnwgv, $
       PTRpctgooddmgv=ptr_pctgooddmgv, PTRpctgoodn2gv=ptr_pctgoodn2gv, $
       BBPARMS=BBparms, BB_RELATIVE=bb_relative, ALT_BB_HGT=alt_bb_file, $
       PTRGVMODEHID=ptr_BestHID, PTRGVHID=ptr_HID, $
       FORCEBB=forcebb, RAY_RANGE=ray_range )

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
   besthid=temporary(*ptr_BestHID)
   hid=temporary(*ptr_HID)
   mygeometa=temporary(*ptr_geometa)
   mysite=temporary(*ptr_sitemeta)
   mysweeps=temporary(*ptr_sweepmeta)
   myflags=temporary(*ptr_fieldflags)
   gvz=temporary(*ptr_gvz)
   ; TAB changed to use temporary like rest of the variables
   ;gvzmax=*ptr_gvzmax
   ;gvzstddev=*ptr_gvzstddev
   gvzmax=temporary(*ptr_gvzmax)
   gvzstddev=temporary(*ptr_gvzstddev)
  ; DPRGMI does not have Zmeasured (zraw), so just copy Zcorrected to define it
   IF pr_or_dpr EQ 'DPRGMI' THEN zraw=*ptr_zcor ELSE zraw=temporary(*ptr_zraw)
   zcor=temporary(*ptr_zcor)
   IF pr_or_dpr EQ 'DPR' THEN echoTops=temporary(*ptr_stmTopHgt)
   PIA=temporary(*ptr_pia)
   nearSurfRain=temporary(*ptr_nearSurfRain)
   ; MRMS radar variables
   mrmsrrlow=temporary(*ptr_mrmsrrlow)
   mrmsrrmed=temporary(*ptr_mrmsrrmed)
   mrmsrrhigh=temporary(*ptr_mrmsrrhigh)
   mrmsrrveryhigh=temporary(*ptr_mrmsrrveryhigh)

   mrmsrqiplow=temporary(*ptr_mrmsrqiplow)
   mrmsrqipmed=temporary(*ptr_mrmsrqipmed)
   mrmsrqiphigh=temporary(*ptr_mrmsrqiphigh)
   mrmsrqipveryhigh=temporary(*ptr_mrmsrqipveryhigh)

   mrmshid=temporary(*ptr_MRMS_HID)

   nearSurfRain_2b31=temporary(*ptr_nearSurfRain_2b31)
;   rnflag=temporary(*ptr_rnFlag)
   rntype=temporary(*ptr_rnType)
   bbProx=temporary(*ptr_bbProx)
   bbHeight=temporary(*ptr_bbHeight)
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

; TAB moved from later in the program so we can apply BBprox filtering for Dm
; build an array of BB proximity: 0 if below, 1 if within, 2 if above
;#######################################################################################
; NOTE THESE CATEGORY NUMBERS ARE ONE LOWER THAN THOSE IN FPREP_GEO_MATCH_PROFILES() !!
;#######################################################################################
   BBprox = BBprox - 1

IF have_SAT_DSD EQ 1 THEN BEGIN
   DPR_Dm=temporary(*ptr_DprDm)
   pctgoodDPR_Dm=temporary(*ptr_pctgoodDprDm)
   DPR_Nw=temporary(*ptr_DprNw/NW_SCALE)      ; dBNw -> log10(Nw)
   pctgoodDPR_NW=temporary(*ptr_pctgoodDprNw )
ENDIF ELSE BEGIN
   IF do_dm_thresh EQ 1 THEN BEGIN
      message, "No DPR Dm present, but dpr_dm_thresh filtering requested." $
               +"  Quitting.", /INFO
      GOTO, cleanUp
   ENDIF
   IF do_dm_range EQ 1 THEN BEGIN
      message, "No DPR Dm present, but dpr_dm_range filtering requested." $
               +"  Quitting.", /INFO
      GOTO, cleanUp
   ENDIF

ENDELSE

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
;              have_hist.DmAny[haveVar,*] = 1
              GR_Dm=temporary(*ptr_GR_DP_Dm)
;              GR_Dmmax=temporary(*ptr_GR_DP_Dmmax)
;              GR_Dmstddev=temporary(*ptr_GR_DP_Dmstddev)
              pctgoodGR_Dm=temporary(*ptr_pctgooddmgv)
ENDIF ELSE have_Dm = 0

; TAB add this in for GR Dm histograms, always want GR_Dmstddev even when we don't have satellite Dm
IF myflags.have_GR_Dm EQ 1 THEN BEGIN
             GR_Dmstddev=temporary(*ptr_GR_DP_Dmstddev)
ENDIF

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
;              GR_RR_orig=GR_RR
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

IF myflags.have_mrms EQ 1 THEN have_mrms = 1 ELSE have_mrms = 0


; TAB 9/29/17  Hardcode for now, check presence later
;******************^^^^^^^^^^^^^^^***************&^^^^^^^^^^^^^^^*^*^
IF have_mrms EQ 1 THEN BEGIN
	have_hist.MRMSDSR[haveVar,*] = 1
	have_hist.GRRMRMS[haveVar,*] = 1
	have_hist.GRPMRMS[haveVar,*] = 1
	have_hist.GRCMRMS[haveVar,*] = 1
	have_hist.GRRDSR[haveVar,*] = 1
	have_hist.GRCDSR[haveVar,*] = 1
	have_hist.GRPDSR[haveVar,*] = 1
ENDIF

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
; TAB 7/27/17 added Z thresholding check
; Define and/or reset filter flag variables if doing blockage, Dm, Z, or ET thresholding
IF do_GR_blockage NE 0 OR do_dm_thresh EQ 1 OR do_dm_range EQ 1  $
   OR N_ELEMENTS( et_range_m ) EQ 2 OR zfilter_type NE 'none' THEN BEGIN
      flag2filter = INTARR( SIZE(gvz, /DIMENSIONS) )
      filterText=''
ENDIF

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
; TAB 8/7/17
; experimented on logic of this section to operate on samples
; not over columns as original
;-------------------------------------------------
;dmTitleText=''
;IF do_dm_thresh EQ 1 THEN BEGIN
;; accumulate any/all rain types below the BB at/below 3 km
;   idxDmBig = INTARR( SIZE(DPR_Dm, /DIMENSIONS) )   ; flag array for profiles
;   idxdmabovethresh= WHERE(DPR_Dm GE dpr_dm_thresh, ndmdabovethresh)
;;   idxdmdprgt25= WHERE(DPR_Dm GE dpr_dm_thresh AND BBprox EQ 0 $
;;                   AND hgtcat LE 1, ndmdabovethresh)
;   idxDmBig[idxdmabovethresh]=1
;   idxDmTooLow = WHERE( TEMPORARY(idxDmBig) EQ 0, nDmTooLow )
;
;   IF ndmTooLow GT 0 THEN BEGIN 
;      flag2filter[idxDmTooLow] = 1
;      filterText=filterText+' DPR_Dm ge ' + STRING(dpr_dm_thresh, FORMAT='(F3.1)') 
;      dmTitleText=' DPR Dm ge ' + STRING(dpr_dm_thresh, FORMAT='(F3.1)') 
;   ENDIF
;ENDIF

;********* original code ************

dmTitleText=''
; identify columns not meeting the DPR Dm threshold, if option is active
IF do_dm_thresh EQ 1 THEN BEGIN
   idxDmBig = INTARR( SIZE(DPR_Dm, /DIMENSIONS) )   ; flag array for profiles
   ; find all samples with maximum DPR Dm >= dpr_dm_thresh in the below-BB
   ; layer at/under 3.0 km
; TAB try this, originally commented out...
    idxdmdprgt25= WHERE(DPR_Dm GE dpr_dm_thresh AND BBprox EQ 0 $
                   AND hgtcat LE 1, ndmdprgt25)
;   idxdmdprgt25= WHERE(DPR_Dm GE dpr_dm_thresh , ndmdprgt25)

help, dpr_dm_thresh, ndmdprgt25
;stop
   ; set flag array to 1 for these samples
   IF ndmdprgt25 GT 0 THEN idxDmBig[idxdmdprgt25] = 1
   ; flag entire **profiles** having a value of DPR Dm GE dpr_dm_thresh in layer
   dmProfilesGE25 = MAX(idxDmBig, DIMENSION=2)    ; max flag along column, either 1 or 0
   ; tag all samples along profile with this flag
   for iswplev=0,nsweeps-1 do begin
       idxDmBig[*,iswplev] = dmProfilesGE25
   endfor
   ; identify array indices of all samples in all columns not meeting Dm criterion
   idxDmTooLow = WHERE( TEMPORARY(idxDmBig) EQ 0, nDmTooLow )

;   IF N_ELEMENTS(flag2filter) EQ 0 THEN BEGIN
;     ; define flag for the samples to be excluded if any Dm don't meet criterion
;      IF N_ELEMENTS(nDmTooLow) NE 0 THEN BEGIN
;         flag2filter = INTARR( SIZE(gvz, /DIMENSIONS) )
;         filterText=''
;         IF nDmTooLow GT 0 THEN BEGIN
;            flag2filter[idxDmTooLow] = 1
;            filterText=filterText+' DPR_Dm'
;         ENDIF
;      ENDIF      
;   ENDIF ELSE BEGIN
     ; set any additional position flags in flag2filter to exclude by Dm criterion
      IF N_ELEMENTS(nDmTooLow) NE 0 THEN BEGIN
         IF ( nDmTooLow GT 0 ) THEN BEGIN
            flag2filter[idxDmTooLow] = 1
;            filterText=filterText+' DPR_Dm'
            filterText=filterText+' DPR_Dm ge ' + STRING(dpr_dm_thresh, FORMAT='(F3.1)') 
            dmTitleText=' DPR Dm GE ' + STRING(dpr_dm_thresh, FORMAT='(F3.1)') 
         ENDIF
      ENDIF
;   ENDELSE
ENDIF
;********* end original code ************

IF do_dm_range EQ 1 THEN BEGIN
   ; find all samples with DPR Dm outside of dpr_dm_range
;   idxdmTooHigh= WHERE(DPR_Dm GT dpr_dm_range , ndmdprgtrange)
   idxdmTooHigh= WHERE(DPR_Dm GT dpr_dm_range_max OR DPR_Dm LT dpr_dm_range_min , ndmdprgtrange)
help, dpr_dm_range_min, dpr_dm_range_max, ndmdprgtrange 
   IF N_ELEMENTS(idxdmTooHigh) NE 0 THEN BEGIN
       flag2filter[idxDmTooHigh] = 1
;            filterText=filterText+' DPR_Dm le ' + STRING(dpr_dm_range, FORMAT='(F3.1)')
;            dmTitleText=' DPR Dm le ' + STRING(dpr_dm_range, FORMAT='(F3.1)')
            filterText=filterText+' DPR_Dm ' + $
            	STRING(dpr_dm_range_min, dpr_dm_range_max, FORMAT='("GE ",F3.1," LE ",f3.1)')
            dmTitleText=' DPR Dm ' + $
            	STRING(dpr_dm_range_min, dpr_dm_range_max, FORMAT='("GE ",F3.1," LE ",f3.1)')
   ENDIF
ENDIF

;-------------------------------------------------

; Optional data clipping based on echo top height (stormTopHeight) range:
; Limit which PR and GV points to include, based on ET height
IF N_ELEMENTS( et_range_m ) EQ 2 THEN BEGIN
   print, 'Clipping by echo top height.'
  ; define index array that flags samples outside the ET range - automatically
  ; flags entire columns since ET value is replicated over all levels
   idxEToutside = WHERE(echoTops LT et_range_m[0] $
                     OR echoTops GT et_range_m[1], countET)

;   IF N_ELEMENTS(flag2filter) EQ 0 THEN BEGIN
;     ; define flag for the samples to be excluded if any ET don't meet criterion
;      IF N_ELEMENTS(countET) NE 0 THEN BEGIN
;         flag2filter = INTARR( SIZE(gvz, /DIMENSIONS) )
;         filterText=''
;         IF countET GT 0 THEN BEGIN
;            flag2filter[idxEToutside] = 1
;            filterText=filterText+' EchoTops'
;         ENDIF
;      ENDIF      
;   ENDIF ELSE BEGIN
     ; set any additional position flags in flag2filter to exclude by ET criterion
      IF N_ELEMENTS(countET) NE 0 THEN BEGIN
         IF ( countET GT 0 ) THEN BEGIN
            flag2filter[idxEToutside] = 1
            filterText=filterText+' EchoTops'
         ENDIF
      ENDIF
;   ENDELSE
ENDIF

; TAB 7/25/17
; add filtering based on Zm, Zc, and GVZ 
IF zfilter_type NE 'none' THEN BEGIN
   CASE STRUPCASE(zfilter_type) OF
      'ZC' : zval = zcor
      'ZM' : zval = zraw
     'GVZ' : zval = gvz
      ELSE : message, "Error:  illegal value for zfilter_type"
   ENDCASE
   tmpIndex = where (rntype GT 0)
   tmprain = rntype[tmpIndex]
   print, " type = ", tmprain[0]
   idxZconvout = WHERE( rntype EQ RainType_convective $
      AND (zval LT zfilterconv[0] OR zval GT zfilterconv[1]), countZconvout )
;   idxZstratout = WHERE( rntype EQ RainType_stratiform $
   idxZstratout = WHERE( rntype EQ RainType_stratiform OR rntype EQ RainType_other $
      AND (zval LT zfilterstrat[0] OR zval GT zfilterstrat[1]), countZstratout )
   IF ( countZconvout GT 0 ) THEN BEGIN
      flag2filter[idxZconvout] = 1
   ENDIF
   IF ( countZstratout GT 0 ) THEN BEGIN
      flag2filter[idxZstratout] = 1
   ENDIF
   filterText = filterText + filtertitlestring 
ENDIF
;; TAB 8/21/17
;; Find anomalous samples using unfiltered variables
;;anomaly = where ( DPR_RR GT 40 AND PIA > 3, num_anomalies)
;anomaly = where ( DPR_RR GT 40 AND DPR_Nw LT 3.5 , num_anomalies)
;if num_anomalies GT 0 then begin
;   printf, anom_LUN, "Anomaly (DPR_RR GT 40 AND DPR_Nw LT 3.5): ", ncfilepr
;   print, "Anomaly (DPR_RR GT 40 AND DPR_Nw LT 3.5): ", ncfilepr
;endif
;; accumulate convective rain type below the BB at/below 3 km
;;idxabv = WHERE( BBprox EQ 0 AND rntype EQ RainType_convective $
;;                AND hgtcat LE 1, countabv )
;
;anomaly = where ( zcor GT 54 AND BBprox EQ 0 AND rntype EQ RainType_convective $
;                 AND hgtcat LE 1, num_anomalies)
;if num_anomalies GT 0 then begin
;   printf, anom_LUN, "Anomaly (Zcor GT 54 AND convective below BB at/below 3 km) : ", ncfilepr
;   print, "Anomaly (Zcor GT 54 AND convective below BB at/below 3 km) : ", ncfilepr
;endif
;;anomaly = where ( DPR_Dm GE 3.0 AND DPR_Dm LE 3.1 AND DPR_RR GT 40 , num_anomalies)
;anomaly = where ( DPR_Dm GE 3.0 AND DPR_RR GT 40 , num_anomalies)
;if num_anomalies GT 0 then begin
;   printf, anom_LUN, "Anomaly (DPR_Dm GE 3.0 AND DPR_RR GT 40): ", ncfilepr
;   print, "Anomaly (DPR_Dm GE 3.0 AND DPR_RR GT 40): ", ncfilepr
;endif
;-------------------------------------------------

   IF ( N_ELEMENTS(flag2filter) NE 0) THEN BEGIN
     ; define an array that flags samples that passed filtering tests
      unfiltered = pctgoodpr < pctgoodgv ;minpctcombined
     ; set filter-flagged samples to a negative value to exclude them in clipping
      idxfiltered = WHERE(flag2filter EQ 1, countfiltered)
totalpts = N_ELEMENTS(minpctcombined)
print, "Filtered ",countfiltered," of ",totalpts, " based on "+filterText
print, ''
;stop
      IF countfiltered GT 0 THEN unfiltered[idxfiltered] = -66.6
      IF ( pctAbvThreshF GT 0.0 ) THEN BEGIN
         IF countfiltered GT 0 THEN filterText = ' and by ' + filterText
         print, 'Clipping by PercentAboveThreshold' + filterText
        ; clip to the 'good' points, where 'pctAbvThreshF' fraction of bins in average
        ; were above threshold AND filter flag is not set
         idxgoodenuff = WHERE( minpctcombined GE pctAbvThreshF $
                          AND  unfiltered GT 0.0, countgoodpct )
      ENDIF ELSE BEGIN
         print, 'Clipping by' + filterText
         idxgoodenuff = WHERE( minpctcombined GT 0.0 $
                          AND  unfiltered GT 0.0, countgoodpct )
      ENDELSE
   ENDIF ELSE BEGIN
      IF ( pctAbvThreshF GT 0.0 ) THEN BEGIN
         print, 'Clipping by PercentAboveThreshold.'
        ; clip to the 'good' points, where 'pctAbvThreshF' fraction of bins in average
        ; were above threshold
         idxgoodenuff = WHERE( minpctcombined GE pctAbvThreshF, countgoodpct )
      ENDIF ELSE BEGIN
         idxgoodenuff = WHERE( minpctcombined GT 0.0, countgoodpct )
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
          IF pr_or_dpr EQ 'DPR' THEN echoTops = echoTops[idxgoodenuff]
          dist = dist[idxgoodenuff]
          bbProx = bbProx[idxgoodenuff]
          hgtcat = hgtcat[idxgoodenuff]
; TAB 12/01/17 added HID variables, any new variables must be filtered here
 ;         hid = hid[*,idxgoodenuff]
 		  nearSurfRain = nearSurfRain[idxgoodenuff]
 		  
;  cant figure out how to reindex the Hid arrays, so for now just use besthid
;          sz = size(hid)
;         hid_new = lonarr(sz[1],N_ELEMENTS(idxgoodenuff))
;          print, 'size(hid) ',size(hid) 
;          print, 'size idxgoodenuff ', N_ELEMENTS(idxgoodenuff)
;          for i=0,sz[1]-1 do begin
;             for j=0,N_ELEMENTS(idxgoodenuff)-1 do begin
;                 hid_new[i,j] = hid[i,idxgoodenuff[j]]
;             endfor
;          endfor
;          hid = hid_new
          besthid = besthid[idxgoodenuff]
 
          IF have_DprEpsilon EQ 1 THEN BEGIN
             dprEpsilon = dprEpsilon[idxgoodenuff]
             pctgoodDPR_Epsilon = pctgoodDPR_Epsilon[idxgoodenuff]
          ENDIF
          if have_mrms eq 1 then begin
 			  mrmsrrlow=mrmsrrlow[idxgoodenuff]
			  mrmsrrmed=mrmsrrmed[idxgoodenuff]
			  mrmsrrhigh=mrmsrrhigh[idxgoodenuff]
			  mrmsrrveryhigh=mrmsrrveryhigh[idxgoodenuff]

			  mrmsrqiplow=mrmsrqiplow[idxgoodenuff]
			  mrmsrqipmed=mrmsrqipmed[idxgoodenuff]
			  mrmsrqiphigh=mrmsrqiphigh[idxgoodenuff]
			  mrmsrqipveryhigh=mrmsrqipveryhigh[idxgoodenuff]
          
          endif
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
              GR_Dmstddev=GR_Dmstddev[idxgoodenuff]
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
              ; TAB set up GR near sfc stacks
  			  varsize=SIZE(GR_RR)
  			  nswp = varsize[2]
			  sfc_layer = GR_RR[*,0] ; choose lowest scan above surface
			  near_sfc_gr_rr = sfc_layer
			  ; append sfc layer to all layers
			  FOR iswp=1, nswp-1 DO BEGIN
				near_sfc_gr_rr = [near_sfc_gr_rr, sfc_layer]
			  ENDFOR
			  near_sfc_gr_rr = near_sfc_gr_rr[idxgoodenuff]
          
              GR_RR=GR_RR[idxgoodenuff]
;              GR_RRmax=GR_RRmax[idxgoodenuff]
;              GR_RRstddev=GR_RRstddev[idxgoodenuff]
              pctgoodGR_RR=pctgoodGR_RR[idxgoodenuff]
              DPR_RR=DPR_RR[idxgoodenuff]
              pctgoodDPR_RR=pctgoodDPR_RR[idxgoodenuff]
          ENDIF
          IF have_RC EQ 1 THEN BEGIN
              ; TAB set up GR near sfc stacks
  			  varsize=SIZE(GR_RC)
  			  nswp = varsize[2]
			  sfc_layer = GR_RC[*,0] ; choose lowest scan above surface
			  near_sfc_gr_rc = sfc_layer
			  ; append sfc layer to all layers
			  FOR iswp=1, nswp-1 DO BEGIN
				near_sfc_gr_rc = [near_sfc_gr_rc, sfc_layer]
			  ENDFOR
			  near_sfc_gr_rc = near_sfc_gr_rc[idxgoodenuff]
              GR_RC=GR_RC[idxgoodenuff]
;              GR_RCmax=GR_RCmax[idxgoodenuff]
;              GR_RCstddev=GR_RCstddev[idxgoodenuff]
              DPR_RC=DPR_RC[idxgoodenuff]
              pctgoodGR_RC=pctgoodGR_RC[idxgoodenuff]
              pctgoodDPR_RC=pctgoodDPR_RC[idxgoodenuff]
          ENDIF
          IF have_RP EQ 1 THEN BEGIN
   			  varsize=SIZE(GR_RP)
  			  nswp = varsize[2]
              ; TAB set up GR near sfc stacks
			  sfc_layer = GR_RP[*,0] ; choose lowest scan above surface
			  near_sfc_gr_rp = sfc_layer
			  ; append sfc layer to all layers
			  FOR iswp=1, nswp-1 DO BEGIN
				near_sfc_gr_rp = [near_sfc_gr_rp, sfc_layer]
			  ENDFOR
			  near_sfc_gr_rp = near_sfc_gr_rp[idxgoodenuff]
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

; TAB 8/21/17
; Find anomalous samples using filtered variables 
;anomaly = where ( DPR_RR GT 40 AND PIA > 3, num_anomalies)
if have_Nw then begin
   anomaly = where ( DPR_RR GT 40 AND DPR_Nw LT 3.5 , num_anomalies)
   if num_anomalies GT 0 then begin
      printf, anom_LUN, "Anomaly (DPR_RR GT 40 AND DPR_Nw LT 3.5): ", ncfilepr
      print, "Anomaly (DPR_RR GT 40 AND DPR_Nw LT 3.5): ", ncfilepr
   endif
endif
; accumulate convective rain type below the BB at/below 3 km
;idxabv = WHERE( BBprox EQ 0 AND rntype EQ RainType_convective $
;                AND hgtcat LE 1, countabv )

anomaly = where ( zcor GT 54 AND BBprox EQ 0 AND rntype EQ RainType_convective $
                 AND hgtcat LE 1, num_anomalies)
if num_anomalies GT 0 then begin
   printf, anom_LUN, "Anomaly (Zcor GT 54 AND convective below BB at/below 3 km) : ", ncfilepr
   print, "Anomaly (Zcor GT 54 AND convective below BB at/below 3 km) : ", ncfilepr
endif
;anomaly = where ( DPR_Dm GE 3.0 AND DPR_Dm LE 3.1 AND DPR_RR GT 40 , num_anomalies)
if have_Dm then begin
   anomaly = where ( DPR_Dm GE 3.0 AND DPR_RR GT 40 , num_anomalies)
   if num_anomalies GT 0 then begin
      printf, anom_LUN, "Anomaly (DPR_Dm GE 3.0 AND DPR_RR GT 40): ", ncfilepr
      print, "Anomaly (DPR_Dm GE 3.0 AND DPR_RR GT 40): ", ncfilepr
   endif
endif
; TAB  11/28/17 Added for Patrick Gatlin
; output filename for possible hail samples
hail = where ( gvzmax GT 65 AND rntype EQ RainType_convective $
                 AND hgtcat GE 2, num_hail)
if num_hail GT 0 then begin
   printf, hail_LUN, num_hail,ncfilepr,format='(%"%d\,%s")'
;   printf, hail_LUN, num_hail, " possible hail samples in ", ncfilepr
   print, num_hail,ncfilepr,format='(%"%d possible hail samples in %s")'
endif

;-------------------------------------------------------------
; original location of this block:  needed to move up in program for Dm filtering
; this is now done earlier in this program
; build an array of BB proximity: 0 if below, 1 if within, 2 if above
;#######################################################################################
; NOTE THESE CATEGORY NUMBERS ARE ONE LOWER THAN THOSE IN FPREP_GEO_MATCH_PROFILES() !!
;#######################################################################################
;   BBprox = BBprox - 1


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
;   trim = 1   ; flag whether to suppress low percentage bins in plots
;   for raintypeBBidx = 0, 2 do begin
; TAB 11/10/17 added fourth raintypeBBidx for convective above BB within 3 height bins for Z plots only 
   for raintypeBBidx = 0, 3 do begin
     ; set up the indices of the samples to include in the scatter plots
      skip_plot = 0
      SWITCH PlotTypes(iplot) OF
     'GRDMSH' : BEGIN ; only do for all below BB
     		; GR_Dmstddev
			;GR Dm standard deviation histogram (below BB)
                CASE raintypeBBidx OF
                   0 : BEGIN
                      ; accumulate stratiform rain types below the BB at/below 3 km
                      idxabv = WHERE( GR_Dmstddev GE 0.0 AND BBprox EQ 0 AND hgtcat LE 1 $
                        AND rntype EQ RainType_stratiform, countabv )
                      END
                   1 : BEGIN
                      ; accumulate convective rain types below the BB at/below 3 km
                      idxabv = WHERE( GR_Dmstddev GE 0.0 AND BBprox EQ 0 AND hgtcat LE 1 $
                      	AND rntype EQ RainType_convective, countabv )
                      END
                ELSE: BEGIN
                      END
                  ENDCASE
               BREAK 
               END
       'GRZSH' : BEGIN ; do for convective above BB and all below BB
       		; gvzstddev
     		;GR Z standard deviation histogram (above & below BB)
                 CASE raintypeBBidx OF
                    0 : BEGIN
                      ; accumulate stratiform rain types below the BB at/below 3 km
                      idxabv = WHERE( gvzstddev GE 0.0 AND BBprox EQ 0 AND hgtcat LE 1 $
                        AND rntype EQ RainType_stratiform, countabv )
                      END
                    1 : BEGIN
                      ; accumulate convective rain types below the BB at/below 3 km
                      idxabv = WHERE( gvzstddev GE 0.0 AND BBprox EQ 0 AND hgtcat LE 1 $
                      	AND rntype EQ RainType_convective, countabv )
                      END
                    3 : BEGIN
                      ; use four layers above highest layer affected by BB
                      idxabv4 = WHERE( gvzstddev GE 0.0 AND hgtcat GT BBparms.BB_HgtHi AND hgtcat LE (BBparms.BB_HgtHi + 4) AND rntype EQ RainType_convective, countabv_4 )
                      ; use 3 layers above highest layer affected by BB starting at seconde layer above highest affected by BB
                      idxabv3 = WHERE( gvzstddev GE 0.0 AND hgtcat GT BBparms.BB_HgtHi+1 AND hgtcat LE (BBparms.BB_HgtHi + 4) AND rntype EQ RainType_convective, countabv_3 )
                      END
                ELSE: BEGIN
                      END
                  ENDCASE
               BREAK 
               END
       'HID' : BEGIN ; only do for convective above BB
                 CASE raintypeBBidx OF
                  3 : BEGIN
                      ; use four layers above highest layer affected by BB
                      idxabv4 = WHERE( hgtcat GT BBparms.BB_HgtHi AND hgtcat LE (BBparms.BB_HgtHi + 4) AND rntype EQ RainType_convective, countabv_4 )
                      ; use 3 layers above highest layer affected by BB starting at seconde layer above highest affected by BB
                      idxabv3 = WHERE( hgtcat GT BBparms.BB_HgtHi+1 AND hgtcat LE (BBparms.BB_HgtHi + 4) AND rntype EQ RainType_convective, countabv_3 )
                      END
                ELSE: BEGIN
                      END
                  ENDCASE
               BREAK 
               END
       'ZM' : 
       'ZC' : BEGIN
                 CASE raintypeBBidx OF
                  3 : BEGIN
                      ; TAB 11/10/17 accumulate convectve rain types above the BB within 3 height levels 
;BBparms = {meanBB : -99.99, BB_HgtLo : -99, BB_HgtHi : -99}
                     ; idxabv = WHERE( BBprox EQ 2 AND rntype EQ RainType_convective, countabv )
                      
; use three layers above highest layer affected by BB
                     ; idxabv = WHERE( hgtcat GT BBparms.BB_HgtHi AND hgtcat LE (BBparms.BB_HgtHi + 4) AND rntype EQ RainType_convective, countabv )
                      ;idxabv = WHERE( hgtcat GT BBparms.BB_HgtHi+1 AND hgtcat LE (BBparms.BB_HgtHi + 4) AND rntype EQ RainType_convective, countabv )
; use four layers above highest layer affected by BB
                      idxabv = WHERE( hgtcat GT BBparms.BB_HgtHi AND hgtcat LE (BBparms.BB_HgtHi + 4) AND rntype EQ RainType_convective, countabv )
                     ; go extra layer above BB
                     ; idxabv = WHERE( BBprox EQ 2 AND hgtcat GT (BBparms.BB_HgtHi+1) AND hgtcat LE (BBparms.BB_HgtHi + 4) $ 
                     ;                 AND rntype EQ RainType_convective, countabv )
                     ;idxabv = WHERE(  hgtcat GT (BBparms.BB_HgtHi+2) AND rntype EQ RainType_convective, countabv )
                     ; print,'layer hgtcat', hgtcat, ' hgthi ', BBparms.BB_HgtHi, ' hgtlo ', BBparms.BB_HgtLo, ' count ', countabv
                      END
                  2 : BEGIN
                      ; accumulate any/all rain types above the BB
                      idxabv = WHERE( BBprox EQ 2, countabv )
                      END
                  1 : BEGIN
                      ; accumulate convective rain type below the BB
                      idxabv = WHERE( BBprox EQ 0 AND rntype EQ RainType_convective, countabv )
                      END
                  0 : BEGIN
                      ; accumulate stratiform rain type above the BB
                      idxabv = WHERE( BBprox EQ 2 AND rntype EQ RainType_stratiform, countabv )
                      if countabv eq 0 then print, 'ZM Strat Above zero points **'
                      END
                 ENDCASE
                 BREAK
              END
;     'DMANY': BEGIN
;                ; accumulate 2-D histogram of below-BB Dm
;                 IF raintypeBBidx EQ 1 THEN BEGIN
;                    idxabv = WHERE( BBprox EQ 0 AND hgtcat LE 1, countabv )
;                    raintypeBBidx = 1
;                 ENDIF ELSE BEGIN
;                    idxabv = WHERE( BBprox EQ 0 AND hgtcat LE 1, countabv )
;                    raintypeBBidx = 0
;                 ENDELSE
;                 BREAK
;              END
       ELSE : BEGIN
                ; accumulate 2-D histograms of below-BB Dm/D0/Nw/N2/Rx at/below 3 km
                 CASE raintypeBBidx OF
                  3 : BEGIN
                      ; if plot type is 3 and not a Z plot, skip plot 
                      skip_plot = 1
                      END
                  2 : BEGIN
                      ; accumulate any/all rain types below the BB at/below 3 km
                      idxabv = WHERE( BBprox EQ 0 AND hgtcat LE 1, countabv )
                      END
                  1 : BEGIN
                      ; accumulate convective rain type below the BB at/below 3 km
                      idxabv = WHERE( BBprox EQ 0 AND rntype EQ RainType_convective $
                                      AND hgtcat LE 1, countabv )
                      END
                  0 : BEGIN
                      ; accumulate stratiform rain type below the BB at/below 3 km
                      idxabv = WHERE( BBprox EQ 0 AND rntype EQ RainType_stratiform $
                                      AND hgtcat LE 1, countabv )
                      END
                 ENDCASE
;                 IF raintypeBBidx EQ 1 THEN BEGIN
;                    idxabv = WHERE( BBprox EQ 0 AND rntype EQ RainType_convective $
;                                    AND hgtcat LE 1, countabv )
;                    raintypeBBidx = 1
;                 ENDIF ELSE BEGIN
;                    idxabv = WHERE( BBprox EQ 0 AND rntype EQ RainType_stratiform $
;                                    AND hgtcat LE 1, countabv )
;                    raintypeBBidx = 0
;                 ENDELSE
              END
      ENDSWITCH
      
; TAB start plot scaling here
     if skip_plot eq 1 then goto, plot_skipped
     ; set up histogram parameters by plot type
      SWITCH PlotTypes(iplot) OF
;       'DMANY' :
       'D0' : 
       'DM' : BEGIN
                 binmin1 = 0.0 & binmax1 = 4.0 & BINSPAN1 = 0.1
                 binmin2 = 0.0 & binmax2 = 4.0 & BINSPAN2 = 0.1
                 BREAK
               END
       'N2' : 
       'NW' : BEGIN
              ;  binmin1 = 2.0 & binmax1 = 6.0 & BINSPAN1 = 0.1
              ;  binmin2 = 2.0 & binmax2 = 6.0 & BINSPAN2 = 0.1
                binmin1 = 1.0 & binmax1 = 6.0 & BINSPAN1 = 0.1
                binmin2 = 1.0 & binmax2 = 6.0 & BINSPAN2 = 0.1
                BREAK
              END
       'RC' : 
       'RP' : 
       'RR' : BEGIN
                 IF raintypeBBidx GE 1 THEN BEGIN
                    if rr_log then begin
;	                    binmin1 = -2  & binmin2 = -2
;	                    binmax1 = 1.8 & binmax2 = 1.8
;	                    BINSPAN1 = 0.03
;	                    BINSPAN2 = 0.03
	                    binmin1 = 0.01  & binmin2 = 0.01
	                    binmax1 = 100.0 & binmax2 = 100.0
	                    BINSPAN1 = 1.0
	                    BINSPAN2 = 1.0                    
                    endif else begin
	                    binmin1 = 0.0  & binmin2 = 0.0
	                    binmax1 = 60.0 & binmax2 = 60.0
	                    BINSPAN1 = 1.0
	                    BINSPAN2 = 1.0                    
                    endelse
                 ENDIF ELSE BEGIN
                    if rr_log then begin
;	                    binmin1 = -2  & binmin2 = -2
;	                    binmax1 = 1.2 & binmax2 = 1.2
;	                    BINSPAN1 = 0.02
;	                    BINSPAN2 = 0.02
	                    binmin1 = 0.01  & binmin2 = 0.01
	                    binmax1 = 100.0 & binmax2 = 100.0
	                    BINSPAN1 = 0.25
	                    BINSPAN2 = 0.25
                    endif else begin
	                    binmin1 = 0.0  & binmin2 = 0.0
	                    binmax1 = 15.0 & binmax2 = 15.0
	                    BINSPAN1 = 0.25
	                    BINSPAN2 = 0.25
                    endelse
                 ENDELSE
                 BREAK
              END
    'ZCNWP' : 
    'ZCNWG' : BEGIN
                ; accumulate 2-D histogram of reflectivity vs. Nw
                 IF raintypeBBidx GE 1 THEN BEGIN
                 ;   binmin1 = 2.0 & binmin2 = 20.0
                    binmin1 = 1.0 & binmin2 = 20.0
                    binmax1 = 6.0 & binmax2 = 60.0
                 ENDIF ELSE BEGIN
                 ;   binmin1 = 2.0 & binmin2 = 15.0
                    binmin1 = 1.0 & binmin2 = 15.0
                    binmax1 = 6.0 & binmax2 = 55.0
                 ENDELSE
                 BINSPAN1 = 0.1
                 BINSPAN2 = 1.0
                 BREAK
              END
    'NWDMP' : 
    'NWDMG' : BEGIN
                ; accumulate 2-D histogram of GR and DPR Nw vs. Dm
              ;   binmin1 = 0.0 & binmin2 = 2.0
                 binmin1 = 0.0 & binmin2 = 1.0
                 binmax1 = 4.0 & binmax2 = 6.0
                 BINSPAN1 = 0.1 & BINSPAN2 = 0.1
                 BREAK
              END
    'DMRRG' : 
    'DMRRP' : BEGIN
                ; accumulate 2-D histogram of GR and DPR Dm vs. RR
                ; - Need to have about the same # bins in both RR and Dm
                ;   i.e., (binmax-binmin)/BINSPAN

                ; RR histo parms
                 IF raintypeBBidx GE 1 THEN BEGIN
;                    if rr_log then begin
;                    	binmin1 = 0.01 & binmax1 = 100.0
;                    	BINSPAN1 = 1.0
;                    endif else begin
                    	binmin1 = 0.0 & binmax1 = 60.0
                    	BINSPAN1 = 1.0
;                    endelse
                 ENDIF ELSE BEGIN
;                    if rr_log then begin
;	                    binmin1 = 0.01 & binmax1 = 100.0
;	                    BINSPAN1 = 0.25
;                    endif else begin
	                    binmin1 = 0.0 & binmax1 = 15.0
	                    BINSPAN1 = 0.25
;                    endelse
                 ENDELSE

                ; Dm histo parms
                 binmin2 = 0.0 & binmax2 = 4.0 & BINSPAN2 = 0.1
; TAB 8/8/17 
; Swapped RR and Dm axes for Walt
	  	 tempmin = binmin1 & tempmax = binmax1 & tempspan = BINSPAN1
		 binmin1 = binmin2 & binmax1 = binmax2 & BINSPAN1 = BINSPAN2
		 binmin2 = tempmin & binmax2 = tempmax & BINSPAN2 = tempspan
                 BREAK
              END
    'RRNWG' : 
    'RRNWP' : BEGIN
                ; - Need to have about the same # bins in both RR and Nw
                ;   i.e., (binmax-binmin)/BINSPAN

                ; Nw histo parms
                ; binmin1 = 2.0 & binmax1 = 6.0 & BINSPAN1 = 0.1
                 binmin1 = 1.0 & binmax1 = 6.0 & BINSPAN1 = 0.1

                ; RR histo parms
                 IF raintypeBBidx GE 1 THEN BEGIN
;                    if rr_log then begin
;	                    binmin2 = 0.01 & binmax2 = 100.0
;	                    BINSPAN2 = 1.0
;                    endif else begin
	                    binmin2 = 0.0 & binmax2 = 60.0
	                    BINSPAN2 = 1.0
;                    endelse
                 ENDIF ELSE BEGIN
;                    if rr_log then begin
;	                    binmin2 = 0.01 & binmax2 = 100.0
;	                    BINSPAN2 = 0.25
;                    endif else begin
	                    binmin2 = 0.0 & binmax2 = 15.0
	                    BINSPAN2 = 0.25
;                    endelse
                 ENDELSE
                 BREAK
              END
  'NWGZMXP' : BEGIN
                ; accumulate 2-D histogram of GR Nw vs. Max DPR Zmeasured
                 IF raintypeBBidx GE 1 THEN BEGIN
                 ;   binmin2 = 2.0 & binmin1 = 20.0
                    binmin2 = 1.0 & binmin1 = 20.0
                    binmax2 = 6.0 & binmax1 = 60.0
                 ENDIF ELSE BEGIN
                 ;   binmin2 = 2.0 & binmin1 = 15.0
                    binmin2 = 1.0 & binmin1 = 15.0
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
                 IF raintypeBBidx GE 1 THEN BEGIN
                    epsilonfactor = 0.929 & rrcoeff = 0.235 & dmcoeff = 1.273
                 ENDIF ELSE BEGIN
                    epsilonfactor = 1.217 & rrcoeff = 0.2151 & dmcoeff = 1.319
                 ENDELSE
                 binmin1 = 0.0 & binmin2 = 0.0
                 binmax1 = 2.5 & binmax2 = 2.5
                 BINSPAN1 = 0.1 & BINSPAN2 = 0.1
                 BREAK
              END
       'ZC' : 
       'ZM' : BEGIN
                ; accumulate 2-D histogram of reflectivity
                 IF raintypeBBidx GE 1 THEN BEGIN
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
  'GRRMRMS' :
  'GRCMRMS' :
  'GRPMRMS' :
  'GRRDSR' :
  'GRRDSC' :
  'GRRDSP' :
  'MRMSDSR' : BEGIN

                 IF raintypeBBidx GE 1 THEN BEGIN
                     if rr_log then begin
		                 binmin1 = 0.01  & binmin2 = 0.01
		                 binmax1 = 100.0 & binmax2 = 100.0
		                 BINSPAN1 = 1.0
		                 BINSPAN2 = 1.0
                     endif else begin
		                 binmin1 = 0.0  & binmin2 = 0.0
		                 binmax1 = 60.0 & binmax2 = 60.0
		                 BINSPAN1 = 1.0
		                 BINSPAN2 = 1.0
                     endelse
                 endif else begin
                     if rr_log then begin
		                 binmin1 = 0.01  & binmin2 = 0.01
		                 binmax1 = 100.0 & binmax2 = 100.0
		                 BINSPAN1 = 0.25
		                 BINSPAN2 = 0.25   
                     endif else begin
		                 binmin1 = 0.0  & binmin2 = 0.0
		                 binmax1 = 15.0 & binmax2 = 15.0
		                 BINSPAN1 = 0.25
		                 BINSPAN2 = 0.25   
	                 endelse              
                 endelse

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
                                     iPlot, raintypeBBidx, 0, 0, log_bins
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
                                     iPlot, raintypeBBidx, 0, 0, log_bins
;                    print, PlotTypes[iPlot]+" MAEaccum: ", $
;                           (*plotDataPtrs[iPlot, raintypeBBidx]).maeACCUM
                 ENDIF ELSE countabv=0
              END
;    'DMANY' : BEGIN
;                 IF countabv GT 0 AND have_Dm THEN BEGIN
;                    scat_X = GR_Dm[idxabv]
;                    scat_Y = DPR_Dm[idxabv]
;                    accum_scat_data, scat_X, scat_Y, binmin1, binmin2, $
;                                     binmax1, binmax2, BINSPAN1, BINSPAN2, $
;                                     plotDataPtrs, have_Hist, PlotTypes, $
;                                     iPlot, raintypeBBidx, 0, 0, log_bins
;                    print, PlotTypes[iPlot]+" MAEaccum: ", $
;                           (*plotDataPtrs[iPlot, raintypeBBidx]).maeACCUM
;                 ENDIF ELSE countabv=0
;              END
       'N2' : BEGIN
                 IF countabv GT 0 AND have_N2 THEN BEGIN
                    scat_X = GR_N2[idxabv]
                    scat_Y = DPR_N2[idxabv]
                    accum_scat_data, scat_X, scat_Y, binmin1, binmin2, $
                                     binmax1, binmax2, BINSPAN1, BINSPAN2, $
                                     plotDataPtrs, have_Hist, PlotTypes, $
                                     iPlot, raintypeBBidx, 0, 0, log_bins
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
                                     iPlot, raintypeBBidx, 0, 0, log_bins
;                    print, PlotTypes[iPlot]+" MAEaccum: ", $
;                           (*plotDataPtrs[iPlot, raintypeBBidx]).maeACCUM
                 ENDIF ELSE countabv=0
              END
       'RC' : BEGIN
                 IF countabv GT 0 AND have_RC THEN BEGIN
	                scat_X = GR_RC[idxabv]
	                scat_Y = DPR_RC[idxabv]
	                ; figure out what idx2do is in this scope and check if it's used right
	                
;	                axis_scale.(PlotHash(PlotTypes(iplot)))[0]=rr_log
;	                axis_scale.(PlotHash(PlotTypes(iplot)))[1]=rr_log
;	                rr_log_x=rr_log
;	                rr_log_y=rr_log
                    accum_scat_data, scat_X, scat_Y, binmin1, binmin2, $
                                     binmax1, binmax2, BINSPAN1, BINSPAN2, $
                                     plotDataPtrs, have_Hist, PlotTypes, $
                                     iPlot, raintypeBBidx, rr_log, rr_log, log_bins
;                    print, PlotTypes[iPlot]+" MAEaccum: ", $
;                           (*plotDataPtrs[iPlot, raintypeBBidx]).maeACCUM
                 ENDIF ELSE countabv=0
              END
       'RP' : BEGIN
                 IF countabv GT 0 AND have_RP THEN BEGIN
                    scat_X = GR_RP[idxabv]
                    scat_Y = DPR_RP[idxabv]
;	                axis_scale.(PlotHash(PlotTypes(iplot)))[0]=rr_log
;	                axis_scale.(PlotHash(PlotTypes(iplot)))[1]=rr_log
                    accum_scat_data, scat_X, scat_Y, binmin1, binmin2, $
                                     binmax1, binmax2, BINSPAN1, BINSPAN2, $
                                     plotDataPtrs, have_Hist, PlotTypes, $
                                     iPlot, raintypeBBidx, rr_log, rr_log, log_bins
;                    print, PlotTypes[iPlot]+" MAEaccum: ", $
;                           (*plotDataPtrs[iPlot, raintypeBBidx]).maeACCUM
                 ENDIF ELSE countabv=0
              END
       'RR' : BEGIN
                 IF countabv GT 0 AND have_RR THEN BEGIN
                    scat_X = GR_RR[idxabv]
                    scat_Y = DPR_RR[idxabv]
;	                axis_scale.(PlotHash(PlotTypes(iplot)))[0]=rr_log
;	                axis_scale.(PlotHash(PlotTypes(iplot)))[1]=rr_log
                    accum_scat_data, scat_X, scat_Y, binmin1, binmin2, $
                                     binmax1, binmax2, BINSPAN1, BINSPAN2, $
                                     plotDataPtrs, have_Hist, PlotTypes, $
                                     iPlot, raintypeBBidx, rr_log, rr_log, log_bins
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
                                     iPlot, raintypeBBidx, 0, 0, log_bins
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
                                     iPlot, raintypeBBidx, 0, 0, log_bins
;                    print, PlotTypes[iPlot]+" MAEaccum: ", $
;                           (*plotDataPtrs[iPlot, raintypeBBidx]).maeACCUM
                 ENDIF ELSE countabv=0
              END
    'DMRRG' : BEGIN
                ; accumulate 2-D histogram of Dm vs. RR
                 IF countabv GT 0 AND have_Nw AND have_Dm THEN BEGIN
; TAB 8/8/17 
                    ;scat_Y = GR_Dm[idxabv]
                    ;scat_X = GR_RR[idxabv]
                    scat_Y = GR_RR[idxabv]
                    scat_X = GR_Dm[idxabv]
		            if do_RR_DM_curve_fit eq 1 and RR_DM_curve_fit_bb_type eq raintypeBBidx then begin
                         idx_ok = where(GR_RR ge 0 and GR_Dm ge 0)
                         ; subset every 4 samples to accumulate fit function points
                         num_pts = N_ELEMENTS(idx_ok)
                         subset = idx_ok[0:num_pts-1:4]
                         ;subset = idxabv 
                         if num_pts GT 0 then begin
                            rr_dm_x = [ temporary(rr_dm_x), GR_Dm[subset] ]     
                            ;rr_dm_y = [ temporary(rr_dm_y),(10^(zcor[subset]/10))/GR_RR[subset] ]     
                            rr_dm_y = [ temporary(rr_dm_y), GR_RR[subset] ]     
                         endif
                    endif
;	                axis_scale.(PlotHash(PlotTypes(iplot)))[0]=0
;	                axis_scale.(PlotHash(PlotTypes(iplot)))[1]=rr_log
                    accum_scat_data, scat_X, scat_Y, binmin1, binmin2, $
                                     binmax1, binmax2, BINSPAN1, BINSPAN2, $
                                     plotDataPtrs, have_Hist, PlotTypes, $
                                     iPlot, raintypeBBidx, 0, 0, log_bins
;                                     iPlot, raintypeBBidx, 0, rr_log
;                    print, PlotTypes[iPlot]+" MAEaccum: ", $
;                           (*plotDataPtrs[iPlot, raintypeBBidx]).maeACCUM
                 ENDIF ELSE countabv=0
              END

    'RRNWG' : BEGIN
                ; accumulate 2-D histogram of Dm vs. Nw
                 IF countabv GT 0 AND have_Nw AND have_RR THEN BEGIN
                    scat_Y = GR_RR[idxabv]
                    scat_X = GR_Nw[idxabv]
;	                axis_scale.(PlotHash(PlotTypes(iplot)))[0]=0
;	                axis_scale.(PlotHash(PlotTypes(iplot)))[1]=rr_log
                    accum_scat_data, scat_X, scat_Y, binmin1, binmin2, $
                                     binmax1, binmax2, BINSPAN1, BINSPAN2, $
                                     plotDataPtrs, have_Hist, PlotTypes, $
                                     iPlot, raintypeBBidx, 0, 0, log_bins
;                                     iPlot, raintypeBBidx, 0, rr_log
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
                                     iPlot, raintypeBBidx, 0, 0, log_bins
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
                                     iPlot, raintypeBBidx, 0, 0, log_bins
;                    print, PlotTypes[iPlot]+" MAEaccum: ", $
;                           (*plotDataPtrs[iPlot, raintypeBBidx]).maeACCUM
                 ENDIF ELSE countabv=0
              END
    'DMRRP' : BEGIN
                ; accumulate 2-D histogram of DPR-only Dm vs. RR
                 IF countabv GT 0 AND have_RR AND have_Dm THEN BEGIN
; TAB 8/8/17 
                    ;scat_Y = DPR_Dm[idxabv]
                    ;scat_X = DPR_RR[idxabv]
                    scat_X = DPR_Dm[idxabv]
                    scat_Y = DPR_RR[idxabv]
;	                axis_scale.(PlotHash(PlotTypes(iplot)))[0]=0
;	                axis_scale.(PlotHash(PlotTypes(iplot)))[1]=rr_log
                    accum_scat_data, scat_X, scat_Y, binmin1, binmin2, $
                                     binmax1, binmax2, BINSPAN1, BINSPAN2, $
                                     plotDataPtrs, have_Hist, PlotTypes, $
                                     iPlot, raintypeBBidx, 0, 0, log_bins
;                                     iPlot, raintypeBBidx, 0, rr_log
;                    print, PlotTypes[iPlot]+" MAEaccum: ", $
;                           (*plotDataPtrs[iPlot, raintypeBBidx]).maeACCUM
                 ENDIF ELSE countabv=0
              END
    'RRNWP' : BEGIN
                ; accumulate 2-D histogram of DPR-only RR vs. Nw
                 IF countabv GT 0 AND have_Nw AND have_RR THEN BEGIN
                    scat_Y = DPR_RR[idxabv]
                    scat_X = DPR_Nw[idxabv]
;	                axis_scale.(PlotHash(PlotTypes(iplot)))[0]=0
;	                axis_scale.(PlotHash(PlotTypes(iplot)))[1]=rr_log
                    accum_scat_data, scat_X, scat_Y, binmin1, binmin2, $
                                     binmax1, binmax2, BINSPAN1, BINSPAN2, $
                                     plotDataPtrs, have_Hist, PlotTypes, $
                                     iPlot, raintypeBBidx, 0, 0, log_bins
;                                     iPlot, raintypeBBidx, 0, rr_log
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
                                     iPlot, raintypeBBidx, 0, 0, log_bins
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
                                     iPlot, raintypeBBidx, 0, 0, log_bins
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
;                       scat_X = GR_RR[idx2do]^rrcoeff / GR_Dm[idx2do]^dmcoeff
                       scat_X = epsilonfactor * (GR_RR[idx2do]^rrcoeff / GR_Dm[idx2do]^dmcoeff)
                       IF have_DprEpsilon EQ 1 THEN $
                          scat_Y = dprEpsilon[idx2do] $
                       ELSE $
                          scat_Y = epsilonfactor * (DPR_RR[idx2do]^rrcoeff / DPR_Dm[idx2do]^dmcoeff)
;                          scat_Y = DPR_RR[idx2do]^rrcoeff / DPR_Dm[idx2do]^dmcoeff
                       accum_scat_data, scat_X, scat_Y, binmin1, binmin2, $
                                        binmax1, binmax2, BINSPAN1, BINSPAN2, $
                                        plotDataPtrs, have_Hist, PlotTypes, $
                                        iPlot, raintypeBBidx, 0, 0, log_bins
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
                                     iPlot, raintypeBBidx, 0, 0, log_bins
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
                                     iPlot, raintypeBBidx, 0, 0, log_bins
;                    print, PlotTypes[iPlot]+" NUMPTS, MAEaccum: ", $
;                           (*plotDataPtrs[iPlot, raintypeBBidx]).NUMPTS, $
;                           (*plotDataPtrs[iPlot, raintypeBBidx]).maeACCUM
                 ENDIF
              END
      'GRDMSH' : BEGIN ; only do for all below BB
               CASE raintypeBBidx OF
                   0 : BEGIN
                      ; accumulate stratiform at/below 3 km
                      if countabv gt 0 then $
                      	  GRDMSH_below_s = [GRDMSH_below_s, GR_Dmstddev[idxabv]]
                      END
                   1 : BEGIN
                      ; accumulate convective at/below 3 km
                      if countabv gt 0 then $
                          GRDMSH_below_c = [GRDMSH_below_c, GR_Dmstddev[idxabv]]
                      END
                ELSE: BEGIN
                      END
                  ENDCASE
               END
       'GRZSH' : BEGIN ; do for convective above BB and all below BB
     		;GR Z standard deviation histogram (above & below BB)
                 CASE raintypeBBidx OF
                    0 : BEGIN
                      ; accumulate stratiform below the BB at/below 3 km
                      if countabv gt 0 then $
                          GRZSH_below_s = [GRZSH_below_s, gvzstddev[idxabv]]
                      END
                    1 : BEGIN
                      ; accumulate convective below the BB at/below 3 km
                      if countabv gt 0 then $
                          GRZSH_below_c = [GRZSH_below_c, gvzstddev[idxabv]]
                      END
                    3 : BEGIN
                      ; use four layers above highest layer affected by BB
                      if countabv_4 gt 0 then $
                      	  GRZSH_above_4 = [GRZSH_above_4, gvzstddev[idxabv4]]
                      ; use 3 layers above highest layer affected by BB starting at second layer above highest affected by BB
                      if countabv_3 gt 0 then $
                          GRZSH_above_3 = [GRZSH_above_3, gvzstddev[idxabv3]]
                      
                      END
                ELSE: BEGIN
                      END
                  ENDCASE
               END
      'HID' : BEGIN
                  if raintypeBBidx EQ 3 then begin
	; skip first array index (missing)  
					  if countabv_4 GT 0 then Begin
		                  hc1 = besthid[idxabv4] 
		              ;    print, 'HID ', hc1 
		                  nelem = N_ELEMENTS(hc1)
		              ;    print, 'nelem ', nelem
		                  for i=0, nelem-1 do begin
		                      if hc1[i] gt 0 then HID_histogram1[raintypeBBidx, hc1[i]]++
		  ;HID_categories = [ 'MIS','DZ','RN','CR','DS','WS','VI','LDG','HDG','HA','BD','HR','AHA' ]
		                      if hc1[i] eq 2 or hc1[i] eq 8 or hc1[i] eq 9 then HID_histogram1[raintypeBBidx, 12]++ 
		                  endfor 
					  endif 
					  
	 				  if countabv_3 GT 0 then Begin
		                  hc2 = besthid[idxabv3] 
		              ;    print, 'HID ', hc2 
		                  nelem = N_ELEMENTS(hc2)
		              ;    print, 'nelem ', nelem
		                  for i=0, nelem-1 do begin
		                      if hc2[i] gt 0 then HID_histogram2[raintypeBBidx, hc2[i]]++
		                      if hc2[i] eq 2 or hc2[i] eq 8 or hc2[i] eq 9 then HID_histogram2[raintypeBBidx, 12]++ 
		                  endfor 
	                  endif 
                  endif

; can't figure out how to correctly reindex hid histograms, so for now use besthid
;                  print, 'size hid ', size(hid)
;                  sz = size(hid)
;                  num_bins = sz[1]
;                  ;num_hist = N_ELEMENTS(hist_hid)
;;                  print, 'size hist_hid ', size(hist_hid)
;                  ;num_hist = sz[1]
;                  num_hist = N_ELEMENTS(hist_hid)
;                  if num_bins gt 0 then begin
;                       print, 'num_bins ', num_bins
;;                       for i=1, num_bins-1 do BEGIN ; histogram bins
;                       for i=1, 11 do BEGIN ; histogram bins
;                            sum = 0
;                            histcnts = hid[i,idxabv]
;                            n_gr_pts = N_ELEMENTS(histcnts)
;                            print, 'n_gr_pts ', n_gr_pts
;                            for j=0,n_gr_pts-1 do begin
;;                                 if hid[i,idxabv[j]] GT 0 then sum += hid[i,idxabv[j]]   
;                                 if histcnts[j] GT 0 then sum += histcnts[j]   
;                            endfor 
;                            print, 'sum ', sum
;                            HID_histogram[raintypeBBidx, i] += sum 
;                       ENDFOR
;                  endif
                  ;foreach hid, scat_x do BEGIN
                  ;    if hid gt 0 then HID_histogram[raintypeBBidx, hid]++
                  ;ENDFOREACH
              END
  'MRMSDSR' : BEGIN
  
  ; this section if from RR
 ;                  IF countabv GT 0 AND have_RR THEN BEGIN
 ;                   scat_X = GR_RR[idxabv]
 ;                   scat_Y = DPR_RR[idxabv]
 ;                   accum_scat_data, scat_X, scat_Y, binmin1, binmin2, $
 ;                                    binmax1, binmax2, BINSPAN1, BINSPAN2, $
 ;                                    plotDataPtrs, have_Hist, PlotTypes, $
 ;                                    iPlot, raintypeBBidx, rr_log, rr_log, log_bins
;                    print, PlotTypes[iPlot]+" MAEaccum: ", $
;                           (*plotDataPtrs[iPlot, raintypeBBidx]).maeACCUM
 ;                ENDIF ELSE countabv=0
  
  
;  				IF have_mrms EQ 1 THEN BEGIN
 ; 				    rqi = mrmsrqipveryhigh[*,0]
 ; 					ns_rr = nearSurfRain[*,0]
;  					mrms_rr = mrmsrrveryhigh[*,0]
;                    idxnonzero=WHERE(ns_rr GT 0.0 and mrms_rr GT 0.0 and rqi ge 95 ,count )

   				IF countabv GT 0 AND have_mrms EQ 1 THEN BEGIN
  				    rqi = mrmsrqipveryhigh[idxabv]
  					ns_rr = nearSurfRain[idxabv]
  					mrms_rr = mrmsrrveryhigh[idxabv]
                    idxnonzero=WHERE(ns_rr GE 0.0 and mrms_rr GE 0.0 and rqi ge 95 ,count )
                    if count gt 0 then begin 
;                       scat_X = nearSurfRain[idxnonzero]
;                       scat_Y = mrmsrrveryhigh[idxnonzero]
                       scat_X = mrms_rr[idxnonzero]
                       scat_Y = ns_rr[idxnonzero]
;	                   axis_scale.(PlotHash(PlotTypes(iplot)))[0]=rr_log
;	                   axis_scale.(PlotHash(PlotTypes(iplot)))[1]=rr_log
                       accum_scat_data, scat_X, scat_Y, binmin1, binmin2, $
                                     binmax1, binmax2, BINSPAN1, BINSPAN2, $
                                     plotDataPtrs, have_Hist, PlotTypes, $
                                     iPlot, raintypeBBidx, rr_log, rr_log, log_bins
                    endif
                 ENDIF
              END
  'GRRMRMS' : BEGIN
;   				IF have_mrms EQ 1 THEN BEGIN
;;   					near_sfc_gr_rr = GR_RR_orig[*,1] ; choose second scan above surface
;  				    rqi = mrmsrqipveryhigh[*,0]
;  					near_sfc_gr_rr = GR_RR_orig[*,0] ; choose lowest scan above surface
;  					mrms_rr = mrmsrrveryhigh[*,0]
;                    idxnonzero=WHERE(near_sfc_gr_rr GT 0.0 and mrms_rr GT 0.0 and rqi ge 95 ,count )

  				IF countabv GT 0 AND have_mrms EQ 1 THEN BEGIN
  					near_sfc_gr_rr = near_sfc_gr_rr[idxabv]
  					mrms_rr = mrmsrrveryhigh[idxabv]
                    idxnonzero=WHERE(near_sfc_gr_rr GE 0.0 and mrms_rr GE 0.0 and rqi ge 95 ,count )

                    if count gt 0 then begin 
                       scat_X = near_sfc_gr_rr[idxnonzero]
                       scat_Y = mrms_rr[idxnonzero]
 ;                      scat_Y = mrmsrrveryhigh[idxnonzero]
;	                   axis_scale.(PlotHash(PlotTypes(iplot)))[0]=rr_log
;	                   axis_scale.(PlotHash(PlotTypes(iplot)))[1]=rr_log
                       accum_scat_data, scat_X, scat_Y, binmin1, binmin2, $
                                     binmax1, binmax2, BINSPAN1, BINSPAN2, $
                                     plotDataPtrs, have_Hist, PlotTypes, $
                                     iPlot, raintypeBBidx, rr_log, rr_log, log_bins
                    endif
                 ENDIF
              END
  'GRCMRMS' : BEGIN

  				IF countabv GT 0 AND have_mrms EQ 1 THEN BEGIN
  					near_sfc_gr_rc = near_sfc_gr_rc[idxabv]
  					mrms_rr = mrmsrrveryhigh[idxabv]
                    idxnonzero=WHERE(near_sfc_gr_rc GE 0.0 and mrms_rr GE 0.0 and rqi ge 95 ,count )

                    if count gt 0 then begin 
                       scat_X = near_sfc_gr_rc[idxnonzero]
                       scat_Y = mrms_rr[idxnonzero]
                       accum_scat_data, scat_X, scat_Y, binmin1, binmin2, $
                                     binmax1, binmax2, BINSPAN1, BINSPAN2, $
                                     plotDataPtrs, have_Hist, PlotTypes, $
                                     iPlot, raintypeBBidx, rr_log, rr_log, log_bins
                    endif
                 ENDIF
              END
  'GRPMRMS' : BEGIN

  				IF countabv GT 0 AND have_mrms EQ 1 THEN BEGIN
  					near_sfc_gr_rp = near_sfc_gr_rp[idxabv]
  					mrms_rr = mrmsrrveryhigh[idxabv]
                    idxnonzero=WHERE(near_sfc_gr_rp GE 0.0 and mrms_rr GE 0.0 and rqi ge 95 ,count )

                    if count gt 0 then begin 
                       scat_X = near_sfc_gr_rp[idxnonzero]
                       scat_Y = mrms_rr[idxnonzero]
                       accum_scat_data, scat_X, scat_Y, binmin1, binmin2, $
                                     binmax1, binmax2, BINSPAN1, BINSPAN2, $
                                     plotDataPtrs, have_Hist, PlotTypes, $
                                     iPlot, raintypeBBidx, rr_log, rr_log, log_bins
                    endif
                 ENDIF
              END
  'GRRDSR' : BEGIN
;;   					near_sfc_gr_rr = GR_RR_orig[*,1] ; choose second scan above surface
;   					near_sfc_gr_rr = GR_RR_orig[*,0] ; choose lowest scan above surface
;  					ns_rr = nearSurfRain[*,0]
;                   idxnonzero=WHERE(near_sfc_gr_rr GT 0.0 and ns_rr GT 0.0,count )

  					near_sfc_gr_rr = near_sfc_gr_rr[idxabv]  					
  					ns_rr = nearSurfRain[idxabv]
                    idxnonzero=WHERE(near_sfc_gr_rr GE 0.0 and ns_rr GE 0.0,count )
                    if count gt 0 then begin 
                       scat_X = near_sfc_gr_rr[idxnonzero]
                       scat_Y = ns_rr[idxnonzero]
;                       scat_Y = nearSurfRain[idxnonzero]
;	                   axis_scale.(PlotHash(PlotTypes(iplot)))[0]=rr_log
;	                   axis_scale.(PlotHash(PlotTypes(iplot)))[1]=rr_log
                       accum_scat_data, scat_X, scat_Y, binmin1, binmin2, $
                                     binmax1, binmax2, BINSPAN1, BINSPAN2, $
                                     plotDataPtrs, have_Hist, PlotTypes, $
                                     iPlot, raintypeBBidx, rr_log, rr_log, log_bins
                    endif
              END
  'GRCDSR' : BEGIN

  					near_sfc_gr_rc = near_sfc_gr_rc[idxabv]  					
  					ns_rr = nearSurfRain[idxabv]
                    idxnonzero=WHERE(near_sfc_gr_rc GE 0.0 and ns_rr GE 0.0,count )
                    if count gt 0 then begin 
                       scat_X = near_sfc_gr_rc[idxnonzero]
                       scat_Y = ns_rr[idxnonzero]
;                       scat_Y = nearSurfRain[idxnonzero]
;	                   axis_scale.(PlotHash(PlotTypes(iplot)))[0]=rr_log
;	                   axis_scale.(PlotHash(PlotTypes(iplot)))[1]=rr_log
                       accum_scat_data, scat_X, scat_Y, binmin1, binmin2, $
                                     binmax1, binmax2, BINSPAN1, BINSPAN2, $
                                     plotDataPtrs, have_Hist, PlotTypes, $
                                     iPlot, raintypeBBidx, rr_log, rr_log, log_bins
                    endif
              END
  'GRPDSR' : BEGIN

  					near_sfc_gr_rp = near_sfc_gr_rp[idxabv]  					
  					ns_rr = nearSurfRain[idxabv]
                    idxnonzero=WHERE(near_sfc_gr_rp GE 0.0 and ns_rr GE 0.0,count )
                    if count gt 0 then begin 
                       scat_X = near_sfc_gr_rp[idxnonzero]
                       scat_Y = ns_rr[idxnonzero]
;                       scat_Y = nearSurfRain[idxnonzero]
;	                   axis_scale.(PlotHash(PlotTypes(iplot)))[0]=rr_log
;	                   axis_scale.(PlotHash(PlotTypes(iplot)))[1]=rr_log
                       accum_scat_data, scat_X, scat_Y, binmin1, binmin2, $
                                     binmax1, binmax2, BINSPAN1, BINSPAN2, $
                                     plotDataPtrs, have_Hist, PlotTypes, $
                                     iPlot, raintypeBBidx, rr_log, rr_log, log_bins
                    endif
              END
      ENDCASE
   endfor

   plot_skipped:

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

; TAB 11/10/17 added fourth raintype for convective above BB within 3 height bins for Z plots only 
;FOR raintypeBBidx = 0, 2 do begin
FOR raintypeBBidx = 0, 3 do begin
   if raintypeBBidx eq 3 then begin

      SWITCH PlotTypes(idx2do) OF
       'GRZSH' : BEGIN ; do for convective above BB and all below BB
       			print, 'creating GRZSH conv above BB'
       			break
                END
         'HID': BEGIN
                print, 'creating HID plot conv above BB'     
                break
                END
         'ZM' :
         'ZC' : BEGIN
                print, 'creating Z plot conv above BB'     
                break
                END
         ELSE : BEGIN
                print, 'skipping plot conv above BB'     
                goto, plot_skipped1      
                END
      ENDSWITCH
   endif
trim = 1   ; flag whether to suppress low percentage bins in plots
do_normBias = 0    ; flag whether to include normalized bias on plot

ptr2do = plotDataPtrs[idx2do, raintypeBBidx]
BB_string = '_BelowBB'
; Have to check both that data were read for the variable(s), and that
; histogram data were accumulated for this instance before attempting the plot
; TAB 11/14/17 changed conditon to allow the HID histogram without checking have_hist structure
;IF have_hist.(idx2do)[haveVar, raintypeBBidx] EQ 1 AND (*ptr2do[0]) NE !NULL THEN BEGIN
IF PlotTypes(idx2do) EQ 'HID' OR PlotTypes(idx2do) EQ 'GRZSH' OR PlotTypes(idx2do) EQ 'GRDMSH' OR  $
  (have_hist.(idx2do)[haveVar, raintypeBBidx] EQ 1 AND (*ptr2do[0]) NE !NULL) THEN BEGIN
  ; CREATE THE SCATTER PLOT OBJECT FROM THE BINNED DATA
   do_MAE_1_1 = 1    ; flag to include/suppress MAE and the 1:1 line on plots
   bustOut=0

   
   do_plot = 1
   SWITCH PlotTypes(idx2do) OF
    'D0' : 
    'DM' : BEGIN
              CASE raintypeBBidx OF
               2 : BEGIN
                   SCAT_DATA = "Any/All Samples, Below Bright Band and <= 3 km AGL"
                   xticknames=['0.0','0.5','1.0','1.5','2.0','2.5','3.0','3.5','4.0']
                   END
               1 : BEGIN
                   SCAT_DATA = "Convective Samples, Below Bright Band and <= 3 km AGL"
                   xticknames=['0.0','0.5','1.0','1.5','2.0','2.5','3.0','3.5','4.0']
                   END
               0 : BEGIN
                   SCAT_DATA = "Stratiform Samples, Below Bright Band and <= 3 km AGL"
                   xticknames=['0.0','0.5','1.0','1.5','2.0','2.5','3.0','3.5','4.0']
                   END
              ENDCASE
              yticknames=xticknames
              xmajor=N_ELEMENTS(xticknames) & ymajor=xmajor
              titleLine1 = satprodtype+' '+version+" Dm vs. GR "+PlotTypes(idx2do)+ $
                           " Scatter, Mean GR-DPR Bias: "
              pngpre=pr_or_dpr+'_'+version+"_Dm_vs_GR_"+PlotTypes(idx2do)+"_Scatter"
              units='mm'
              xtitle= 'GR '+PlotTypes(idx2do)+GRlabelAdd+' ('+units+')'
              ytitle= pr_or_dpr + ' Dm ('+units+')'
              BREAK
           END
;    'DMANY' : BEGIN
;              IF raintypeBBidx EQ 1 THEN BEGIN
;                 SCAT_DATA = "All Samples Below Bright Band and <= 3 km AGL"
;                 xticknames=['0.0','0.5','1.0','1.5','2.0','2.5','3.0','3.5','4.0']
;              ENDIF ELSE BEGIN
;                 SCAT_DATA = "All Samples Below Bright Band and <= 3 km AGL"
;                 xticknames=['0.0','0.5','1.0','1.5','2.0','2.5','3.0','3.5','4.0']
;              ENDELSE
;              yticknames=xticknames
;              xmajor=N_ELEMENTS(xticknames) & ymajor=xmajor
;              titleLine1 = satprodtype+' '+version+" Dm vs. GR Dm"+ $
;                           " Scatter, Mean GR-DPR Bias: "
;              pngpre=pr_or_dpr+'_'+version+"_Dm_vs_GR_"+PlotTypes(idx2do)+"_Scatter"
;              units='mm'
;              xtitle= 'GR Dm '+GRlabelAdd+' ('+units+')'
;              ytitle= pr_or_dpr + ' Dm ('+units+')'
;              BREAK
;           END
    'N2' :
    'NW' : BEGIN
              CASE raintypeBBidx OF
               2 : BEGIN
                   SCAT_DATA = "Any/All Samples, Below Bright Band and <= 3 km AGL"
              ;     xticknames=['2.0','2.5','3.0','3.5','4.0','4.5','5.0','5.5','6.0']
                   END
               1 : BEGIN
                   SCAT_DATA = "Convective Samples, Below Bright Band and <= 3 km AGL"
              ;     xticknames=['2.0','2.5','3.0','3.5','4.0','4.5','5.0','5.5','6.0']
                   END
               0 : BEGIN
                   SCAT_DATA = "Stratiform Samples, Below Bright Band and <= 3 km AGL"
              ;     xticknames=['2.0','2.5','3.0','3.5','4.0','4.5','5.0','5.5','6.0']
                   END
              ENDCASE
              xticknames=['1.0','1.5','2.0','2.5','3.0','3.5','4.0','4.5','5.0','5.5','6.0']
;              IF raintypeBBidx EQ 1 THEN BEGIN
;                 SCAT_DATA = "Convective Samples, Below Bright Band and <= 3 km AGL"
;                 xticknames=['2.0','2.5','3.0','3.5','4.0','4.5','5.0','5.5','6.0']
;              ENDIF ELSE BEGIN
;                 SCAT_DATA = "Stratiform Samples, Below Bright Band and <= 3 km AGL"
;                 xticknames=['2.0','2.5','3.0','3.5','4.0','4.5','5.0','5.5','6.0']
;              ENDELSE
              yticknames=xticknames
              ;BINSPAN = 0.1
              xmajor=N_ELEMENTS(xticknames) & ymajor=xmajor
              titleLine1 = satprodtype+' '+version+" Nw vs. GR "+PlotTypes(idx2do)+ $
                           " Scatter, Mean GR-DPR Bias: "
              pngpre=pr_or_dpr+'_'+version+"_Nw_vs_GR_"+PlotTypes(idx2do)+"_Scatter"
              units='log(Nw)'
              xtitle= 'GR '+units
              ytitle= pr_or_dpr +' '+ units
              BREAK
           END
 'ZCNWP' : BEGIN
              do_MAE_1_1 = 0
              CASE raintypeBBidx OF
               2 : BEGIN
                   SCAT_DATA = "Any/All Samples, Below Bright Band and <= 3 km AGL"
                   yticknames=['20','25','30','35','40','45','50','55','60']
                   END
               1 : BEGIN
                   SCAT_DATA = "Convective Samples, Below Bright Band and <= 3 km AGL"
                   yticknames=['20','25','30','35','40','45','50','55','60']
                   END
               0 : BEGIN
                   SCAT_DATA = "Stratiform Samples, Below Bright Band and <= 3 km AGL"
                   yticknames=['15','20','25','30','35','40','45','50','55']
                   END
              ENDCASE
;              IF raintypeBBidx EQ 1 THEN BEGIN
;                 SCAT_DATA = "Convective Samples, Below Bright Band and <= 3 km AGL"
;                 yticknames=['20','25','30','35','40','45','50','55','60']
;              ENDIF ELSE BEGIN
;                 SCAT_DATA = "Stratiform Samples, Below Bright Band and <= 3 km AGL"
;                 yticknames=['15','20','25','30','35','40','45','50','55']
;              ENDELSE
              xticknames=['1.0','1.5','2.0','2.5','3.0','3.5','4.0','4.5','5.0','5.5','6.0']
              ; xticknames=['2.0','2.5','3.0','3.5','4.0','4.5','5.0','5.5','6.0']
              xmajor=N_ELEMENTS(xticknames) & ymajor=N_ELEMENTS(yticknames)
              titleLine1 = satprodtype+' '+version+" Zc vs. Nw Scatter"
              pngpre=pr_or_dpr+'_'+version+"_Zc_vs_Nw_Scatter"
              xunits='log(Nw)'
              yunits='dBZ'
              xtitle= pr_or_dpr +' '+ xunits
              ytitle= pr_or_dpr + ' Zc (' + yunits + ')'
              BREAK
           END
 'ZCNWG' : BEGIN
              do_MAE_1_1 = 0
              CASE raintypeBBidx OF
               2 : BEGIN
                   SCAT_DATA = "Any/All Samples, Below Bright Band and <= 3 km AGL"
                   yticknames=['20','25','30','35','40','45','50','55','60']
                   END
               1 : BEGIN
                   SCAT_DATA = "Convective Samples, Below Bright Band and <= 3 km AGL"
                   yticknames=['20','25','30','35','40','45','50','55','60']
                   END
               0 : BEGIN
                   SCAT_DATA = "Stratiform Samples, Below Bright Band and <= 3 km AGL"
                   yticknames=['15','20','25','30','35','40','45','50','55']
                   END
              ENDCASE
;              IF raintypeBBidx EQ 1 THEN BEGIN
;                 SCAT_DATA = "Convective Samples, Below Bright Band and <= 3 km AGL"
;                 yticknames=['20','25','30','35','40','45','50','55','60']
;              ENDIF ELSE BEGIN
;                 SCAT_DATA = "Stratiform Samples, Below Bright Band and <= 3 km AGL"
;                 yticknames=['15','20','25','30','35','40','45','50','55']
;              ENDELSE
              ;  xticknames=['2.0','2.5','3.0','3.5','4.0','4.5','5.0','5.5','6.0']
              xticknames=['1.0','1.5','2.0','2.5','3.0','3.5','4.0','4.5','5.0','5.5','6.0']
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
              CASE raintypeBBidx OF
               2 : BEGIN
                   SCAT_DATA = "Any/All Samples, Below Bright Band and <= 3 km AGL"
                   END
               1 : BEGIN
                   SCAT_DATA = "Convective Samples, Below Bright Band and <= 3 km AGL"
                   END
               0 : BEGIN
                   SCAT_DATA = "Stratiform Samples, Below Bright Band and <= 3 km AGL"
                   END
              ENDCASE
;              IF raintypeBBidx EQ 1 THEN $
;                 SCAT_DATA = "Convective Samples, Below Bright Band and <= 3 km AGL" $
;              ELSE SCAT_DATA = "Stratiform Samples, Below Bright Band and <= 3 km AGL"
              xticknames=['0.0','0.5','1.0','1.5','2.0','2.5','3.0','3.5','4.0']
              yticknames=['1.0','1.5','2.0','2.5','3.0','3.5','4.0','4.5','5.0','5.5','6.0']
              ;yticknames=['2.0','2.5','3.0','3.5','4.0','4.5','5.0','5.5','6.0']
              xmajor=N_ELEMENTS(xticknames) & ymajor=N_ELEMENTS(yticknames)
              titleLine1 = satprodtype+' '+version+" Nw vs. Dm Scatter"
              pngpre=pr_or_dpr+'_'+version+"_Nw_vs_Dm_Scatter"
              xunits='(mm)'
              yunits='log(Nw)'
              xtitle= pr_or_dpr +' Dm '+ xunits
              ytitle= pr_or_dpr + ' ' + yunits
              BREAK
           END
 'NWDMG' : BEGIN
              do_MAE_1_1 = 0
              CASE raintypeBBidx OF
               2 : BEGIN
                   SCAT_DATA = "Any/All Samples, Below Bright Band and <= 3 km AGL"
                   END
               1 : BEGIN
                   SCAT_DATA = "Convective Samples, Below Bright Band and <= 3 km AGL"
                   END
               0 : BEGIN
                   SCAT_DATA = "Stratiform Samples, Below Bright Band and <= 3 km AGL"
                   END
              ENDCASE
;              IF raintypeBBidx EQ 1 THEN $
;                 SCAT_DATA = "Convective Samples, Below Bright Band and <= 3 km AGL" $
;              ELSE SCAT_DATA = "Stratiform Samples, Below Bright Band and <= 3 km AGL"
              ; yticknames=['2.0','2.5','3.0','3.5','4.0','4.5','5.0','5.5','6.0']
              yticknames=['1.0','1.5','2.0','2.5','3.0','3.5','4.0','4.5','5.0','5.5','6.0']
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
              CASE raintypeBBidx OF
               2 : BEGIN
                   SCAT_DATA = "Any/All Samples, Below Bright Band and <= 3 km AGL"
;                   if rr_log then begin
;                   		xticknames=log_ticks()
;                   endif else begin
                   		xticknames=STRING(INDGEN(16)*4, FORMAT='(I0)')
;                   endelse                    
                   trim = 0    ; show low-percentage outliers
                   END
               1 : BEGIN
                   SCAT_DATA = "Convective Samples, Below Bright Band and <= 3 km AGL"
;                   if rr_log then begin
;                   		xticknames=log_ticks()
;                   endif else begin
                   		xticknames=STRING(INDGEN(16)*4, FORMAT='(I0)')
;                   endelse                    
                   trim = 0    ; show low-percentage outliers
                   END
               0 : BEGIN
                   SCAT_DATA = "Stratiform Samples, Below Bright Band and <= 3 km AGL"
;                   if rr_log then begin
;                   		xticknames=log_ticks()
;                   endif else begin
;                   		xticknames=STRING(INDGEN(16), FORMAT='(I0)')
;                   endelse                    
                   xticknames=STRING(INDGEN(16), FORMAT='(I0)')
                   END
              ENDCASE
;              IF raintypeBBidx EQ 1 THEN BEGIN
;                 SCAT_DATA = "Convective Samples, Below Bright Band and <= 3 km AGL"
;                 xticknames=STRING(INDGEN(16)*4, FORMAT='(I0)')
;                 trim = 0    ; show low-percentage outliers
;              ENDIF ELSE BEGIN
;                 SCAT_DATA = "Stratiform Samples, Below Bright Band and <= 3 km AGL"
;                 xticknames=STRING(INDGEN(16), FORMAT='(I0)')
;              ENDELSE
              yticknames=['0.0','0.5','1.0','1.5','2.0','2.5','3.0','3.5','4.0']
; TAB 8/8/17 
; swap and y
	      temptick = xticknames
	      xticknames = yticknames
	      yticknames = temptick
              xmajor=N_ELEMENTS(xticknames) & ymajor=N_ELEMENTS(yticknames)
              titleLine1 = "GR RR vs. Dm Scatter"
              pngpre="GR_RR_vs_Dm_Scatter"
             ; titleLine1 = "GR Dm vs. RR Scatter"
             ; pngpre="GR_Dm_vs_RR_Scatter"
; TAB 8/8/17 
              ;xunits='(mm/h)'
              ;yunits='mm'
              ;xtitle=  'GR RR '+ xunits
              ;ytitle=  'GR Dm (' + yunits + ')'
              ;if rr_log then begin
              ;		yunits='(log mm/h)'
              ;endif else begin
              ;		yunits='(mm/h)'
              ;endelse                    
              yunits='(mm/h)'
              
              xunits='mm'
              ytitle=  'GR RR '+ yunits
              xtitle=  'GR Dm (' + xunits + ')'
              if do_RR_DM_curve_fit eq 1 and RR_DM_curve_fit_bb_type eq raintypeBBidx then begin
  ;                 measure_errors = 0.05 * rr_dm_y 
                   ; Provide an initial guess for the function's parameters:
                   ;A = [1, 5.0]
                   A = [500, 3.0]
                   fita = [1,1]
                 ;  print, 'rr_dm_x ', rr_dm_x
                 ;  print, 'rr_dm_y ', rr_dm_y
                   ;coefs = LMFIT(rr_dm_x, rr_dm_y, A, MEASURE_ERRORS=measure_errors, /DOUBLE, $
                   coefs = LMFIT(rr_dm_x, rr_dm_y, A, /DOUBLE, $
                       FITA = fita, FUNCTION_NAME = 'RR_DM_funct')
                   print, 'RR vs Dm LMFIT coeffients ', A 

              endif
              BREAK
           END

 'RRNWG' : BEGIN
              do_MAE_1_1 = 0
              CASE raintypeBBidx OF
               2 : BEGIN
                   SCAT_DATA = "Any/All Samples, Below Bright Band and <= 3 km AGL"
;                   if rr_log then begin
;                   		yticknames=log_ticks()
;                   endif else begin
;                   		yticknames=STRING(INDGEN(16)*4, FORMAT='(I0)')
;                   endelse                    
                   yticknames=STRING(INDGEN(16)*4, FORMAT='(I0)')
                   trim = 0    ; show low-percentage outliers
                   END
               1 : BEGIN
                   SCAT_DATA = "Convective Samples, Below Bright Band and <= 3 km AGL"
;                   if rr_log then begin
;                   		yticknames=log_ticks()
;                   endif else begin
;                   		yticknames=STRING(INDGEN(16)*4, FORMAT='(I0)')
;                   endelse                    
                   yticknames=STRING(INDGEN(16)*4, FORMAT='(I0)')
                   trim = 0    ; show low-percentage outliers
                   END
               0 : BEGIN
                   SCAT_DATA = "Stratiform Samples, Below Bright Band and <= 3 km AGL"
;                   if rr_log then begin
;                   		yticknames=log_ticks()
;                   endif else begin
;                   		yticknames=STRING(INDGEN(16), FORMAT='(I0)')
;                   endelse                    
                   yticknames=STRING(INDGEN(16), FORMAT='(I0)')
                   END
              ENDCASE
;              IF raintypeBBidx EQ 1 THEN BEGIN
;                 SCAT_DATA = "Convective Samples, Below Bright Band and <= 3 km AGL"
;                 yticknames=STRING(INDGEN(16)*4, FORMAT='(I0)')
;                 trim = 0    ; show low-percentage outliers
;              ENDIF ELSE BEGIN
;                 SCAT_DATA = "Stratiform Samples, Below Bright Band and <= 3 km AGL"
;                 yticknames=STRING(INDGEN(16), FORMAT='(I0)')
;              ENDELSE
             ; xticknames=['2.0','2.5','3.0','3.5','4.0','4.5','5.0','5.5','6.0']
              xticknames=['1.0','1.5','2.0','2.5','3.0','3.5','4.0','4.5','5.0','5.5','6.0']
              xmajor=N_ELEMENTS(xticknames) & ymajor=N_ELEMENTS(yticknames)
              titleLine1 = "GR RR vs. Nw Scatter"
              pngpre="GR_RR_vs_Nw_Scatter"
              xunits='log(Nw)'
              ;if rr_log then begin
              ;		yunits='(log mm/h)'
              ;endif else begin
              ;		yunits='(mm/h)'
              ;endelse                    
              
              yunits='(mm/h)'
              xtitle= 'GR '+ xunits
              ytitle= 'GR RR (' + yunits + ')'
              BREAK
           END
 'DMRRP' : BEGIN
              do_MAE_1_1 = 0
              CASE raintypeBBidx OF
               2 : BEGIN
                   SCAT_DATA = "Any/All Samples, Below Bright Band and <= 3 km AGL"
                   xticknames=STRING(INDGEN(16)*4, FORMAT='(I0)')
;                   if rr_log then begin
;                   		xticknames=log_ticks()
;                   endif else begin
;                   		xticknames=STRING(INDGEN(16)*4, FORMAT='(I0)')
;                   endelse                    
                   trim = 0    ; show low-percentage outliers
                   END
               1 : BEGIN
                   SCAT_DATA = "Convective Samples, Below Bright Band and <= 3 km AGL"
                   xticknames=STRING(INDGEN(16)*4, FORMAT='(I0)')
;                   if rr_log then begin
;                   		xticknames=log_ticks()
;                   endif else begin
;                   		xticknames=STRING(INDGEN(16)*4, FORMAT='(I0)')
;                   endelse                    
                   trim = 0    ; show low-percentage outliers
                   END
               0 : BEGIN
                   SCAT_DATA = "Stratiform Samples, Below Bright Band and <= 3 km AGL"
                   xticknames=STRING(INDGEN(16), FORMAT='(I0)')
;                   if rr_log then begin
;                   		xticknames=log_ticks()
;                   endif else begin
;                   		xticknames=STRING(INDGEN(16), FORMAT='(I0)')
;                   endelse                    
                   END
              ENDCASE
;              IF raintypeBBidx EQ 1 THEN BEGIN
;                 SCAT_DATA = "Convective Samples, Below Bright Band and <= 3 km AGL"
;                 xticknames=STRING(INDGEN(16)*4, FORMAT='(I0)')
;                 trim = 0    ; show low-percentage outliers
;              ENDIF ELSE BEGIN
;                 SCAT_DATA = "Stratiform Samples, Below Bright Band and <= 3 km AGL"
;                 xticknames=STRING(INDGEN(16), FORMAT='(I0)')
;              ENDELSE
              yticknames=['0.0','0.5','1.0','1.5','2.0','2.5','3.0','3.5','4.0']
; TAB 8/8/17 
; swap and y
	      temptick = xticknames
	      xticknames = yticknames
	      yticknames = temptick
              xmajor=N_ELEMENTS(xticknames) & ymajor=N_ELEMENTS(yticknames)
              titleLine1 = satprodtype+' '+version+" RR vs. Dm Scatter"
              pngpre=pr_or_dpr+'_'+version+"_RR_vs_Dm_Scatter"
;              titleLine1 = satprodtype+' '+version+" Dm vs. RR Scatter"
;              pngpre=pr_or_dpr+'_'+version+"_Dm_vs_RR_Scatter"
              ;yunits='(mm/h)'
              ;if rr_log then yunits='(log mm/h)' else yunits='(mm/h)'
              yunits='(mm/h)'
              xunits='mm'
              ytitle= pr_or_dpr + ' RR'+ yunits
              xtitle= pr_or_dpr + ' Dm (' + xunits + ')'
              ;xunits='(mm/h)'
              ;yunits='mm'
              ;xtitle= pr_or_dpr + ' RR'+ xunits
              ;ytitle= pr_or_dpr + ' Dm (' + yunits + ')'
              BREAK
           END
 'RRNWP' : BEGIN
              do_MAE_1_1 = 0
              CASE raintypeBBidx OF
               2 : BEGIN
                   SCAT_DATA = "Any/All Samples, Below Bright Band and <= 3 km AGL"
                   yticknames=STRING(INDGEN(16)*4, FORMAT='(I0)')
;                   if rr_log then begin
;                    	yticknames=log_ticks()
;                   endif else begin
;                   		yticknames=STRING(INDGEN(16)*4, FORMAT='(I0)')
;                   endelse                    
                   trim = 0    ; show low-percentage outliers
                   END
               1 : BEGIN
                   SCAT_DATA = "Convective Samples, Below Bright Band and <= 3 km AGL"
                   yticknames=STRING(INDGEN(16)*4, FORMAT='(I0)')
;                   if rr_log then begin
;                   		yticknames=log_ticks()
;                   endif else begin
;                   		yticknames=STRING(INDGEN(16)*4, FORMAT='(I0)')
;                   endelse                    
                   trim = 0    ; show low-percentage outliers
                   END
               0 : BEGIN
                   SCAT_DATA = "Stratiform Samples, Below Bright Band and <= 3 km AGL"
                   yticknames=STRING(INDGEN(16), FORMAT='(I0)')
;                   if rr_log then begin
;                   		yticknames=log_ticks()
;                   endif else begin
;                   		yticknames=STRING(INDGEN(16), FORMAT='(I0)')
;                   endelse                    
                   END
              ENDCASE
;              IF raintypeBBidx EQ 1 THEN BEGIN
;                 SCAT_DATA = "Convective Samples, Below Bright Band and <= 3 km AGL"
;                 yticknames=STRING(INDGEN(16)*4, FORMAT='(I0)')
;                 trim = 0    ; show low-percentage outliers
;              ENDIF ELSE BEGIN
;                 SCAT_DATA = "Stratiform Samples, Below Bright Band and <= 3 km AGL"
;                 yticknames=STRING(INDGEN(16), FORMAT='(I0)')
;              ENDELSE
            ;  xticknames=['2.0','2.5','3.0','3.5','4.0','4.5','5.0','5.5','6.0']
              xticknames=['1.0','1.5','2.0','2.5','3.0','3.5','4.0','4.5','5.0','5.5','6.0']
              xmajor=N_ELEMENTS(xticknames) & ymajor=N_ELEMENTS(yticknames)
              titleLine1 = satprodtype+' '+version+" RR vs. Nw Scatter"
              pngpre=pr_or_dpr+'_'+version+"_RR_vs_Nw_Scatter"
              xunits='log(Nw)'
              ;yunits='mm/h'
              ;if rr_log then yunits='(log mm/h)' else yunits='(mm/h)'
              yunits='(mm/h)'
              xtitle= pr_or_dpr +' '+ xunits
              ytitle= pr_or_dpr + ' RR (' + yunits + ')'
              BREAK
           END
    'RC' : 
    'RP' : 
    'RR' : BEGIN
              do_normBias = 1    ; reset flag to include normalized bias on plot
              CASE raintypeBBidx OF
               2 : BEGIN
                   SCAT_DATA = "Any/All Samples, Below Bright Band and <= 3 km AGL"
                   ;xticknames=STRING(INDGEN(16)*4, FORMAT='(I0)')
                   if rr_log then begin
                   		xticknames=log_ticks()
;                   		xticknames=log_label(8, 8)
                   endif else begin
                   		xticknames=STRING(INDGEN(16)*4, FORMAT='(I0)')
                   endelse                    
                   trim = 0    ; show low-percentage outliers
                   END
               1 : BEGIN
                   SCAT_DATA = "Convective Samples, Below Bright Band and <= 3 km AGL"
                   ;xticknames=STRING(INDGEN(16)*4, FORMAT='(I0)')
                   if rr_log then begin
;                   		xticknames=log_label(8, 8)
                   		xticknames=log_ticks()
                   endif else begin
                   		xticknames=STRING(INDGEN(16)*4, FORMAT='(I0)')
                   endelse                    
                   trim = 0    ; show low-percentage outliers
                   END
               0 : BEGIN
                   SCAT_DATA = "Stratiform Samples, Below Bright Band and <= 3 km AGL"
                   ;xticknames=STRING(INDGEN(16), FORMAT='(I0)')
                   if rr_log then begin
;                   		xticknames=log_label(8, 2)
                   		xticknames=log_ticks()
                   		trim = 0    ; show low-percentage outliers
                   endif else begin
                   		xticknames=STRING(INDGEN(16), FORMAT='(I0)')
                   endelse                    
                   END
              ENDCASE
;              IF raintypeBBidx EQ 1 THEN BEGIN
;                 SCAT_DATA = "Convective Samples, Below Bright Band and <= 3 km AGL"
;                 xticknames=STRING(INDGEN(16)*4, FORMAT='(I0)')
;                 trim = 0    ; show low-percentage outliers
;              ENDIF ELSE BEGIN
;                 SCAT_DATA = "Stratiform Samples, Below Bright Band and <= 3 km AGL"
;                 xticknames=STRING(INDGEN(16), FORMAT='(I0)')
;              ENDELSE
              yticknames=xticknames
              xmajor=N_ELEMENTS(xticknames) & ymajor=xmajor
              titleLine1 = satprodtype+' '+version+" RR vs. GR "+PlotTypes(idx2do)+ $
                           " Scatter, Mean GR-DPR Bias: "
              pngpre=pr_or_dpr+'_'+version+"_RR_vs_GR_"+PlotTypes(idx2do)+"_Scatter"
              ;units='(mm/h)'
             ; if rr_log then units='(log mm/h)' else units='(mm/h)'
              units='(mm/h)'
              xtitle= 'GR '+PlotTypes(idx2do)+' '+units
              ytitle= pr_or_dpr +' '+ units
              BREAK
           END
  'NWGZMXP' : BEGIN
                 do_MAE_1_1 = 0
                 CASE raintypeBBidx OF
                  2 : BEGIN
                      SCAT_DATA = "Any/All Samples, Below Bright Band and <= 3 km AGL"
                      xticknames=['20','25','30','35','40','45','50','55','60']
                      END
                  1 : BEGIN
                      SCAT_DATA = "Convective Samples, Below Bright Band and <= 3 km AGL"
                      xticknames=['20','25','30','35','40','45','50','55','60']
                      END
                  0 : BEGIN
                      SCAT_DATA = "Stratiform Samples, Below Bright Band and <= 3 km AGL"
                      xticknames=['15','20','25','30','35','40','45','50','55']
                      END
                 ENDCASE
;                 IF raintypeBBidx EQ 1 THEN BEGIN
;                    SCAT_DATA = "Convective Samples, Below Bright Band and <= 3 km AGL"
;                    xticknames=['20','25','30','35','40','45','50','55','60']
;                 ENDIF ELSE BEGIN
;                    SCAT_DATA = "Stratiform Samples, Below Bright Band and <= 3 km AGL"
;                    xticknames=['15','20','25','30','35','40','45','50','55']
;                 ENDELSE
               ;  yticknames=['2.0','2.5','3.0','3.5','4.0','4.5','5.0','5.5','6.0']
                 yticknames=['1.0','1.5','2.0','2.5','3.0','3.5','4.0','4.5','5.0','5.5','6.0']
                 xmajor=N_ELEMENTS(xticknames) & ymajor=N_ELEMENTS(yticknames)
                 titleLine1 = "GR Nw vs. "+satprodtype+" Zm(max) Scatter for " $
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
                 CASE raintypeBBidx OF
                  2 : BEGIN
                      SCAT_DATA = "Any/All Samples, Below Bright Band and <= 3 km AGL"
                      END
                  1 : BEGIN
                      SCAT_DATA = "Convective Samples, Below Bright Band and <= 3 km AGL"
                      END
                  0 : BEGIN
                      SCAT_DATA = "Stratiform Samples, Below Bright Band and <= 3 km AGL"
                      END
                 ENDCASE
;                 IF raintypeBBidx EQ 1 THEN $
;                    SCAT_DATA = "Convective Samples, Below Bright Band and <= 3 km AGL" $
;                 ELSE SCAT_DATA = "Stratiform Samples, Below Bright Band and <= 3 km AGL"
                 xticknames=['0.0','0.5','1.0','1.5','2.0','2.5','3.0','3.5','4.0']
                 yticknames=STRING(INDGEN(11), FORMAT='(I0)')
                 xmajor=N_ELEMENTS(xticknames) & ymajor=N_ELEMENTS(yticknames)
                 titleLine1 = satprodtype+' '+version+" PIA vs. Dm Scatter"
                 pngpre=pr_or_dpr+'_'+version+"_PIA_vs_Dm_Scatter"
                 xunits='(mm)'
                 yunits='(dBZ)'
                 xtitle= pr_or_dpr +' Dm '+ xunits
                 ytitle= pr_or_dpr + ' PIA ' + yunits
                 BREAK
              END
  'EPSI' : BEGIN
              CASE raintypeBBidx OF
               2 : BEGIN
                   SCAT_DATA = "Any/All Samples, Below Bright Band and <= 3 km AGL"
                   END
               1 : BEGIN
                   SCAT_DATA = "Convective Samples, Below Bright Band and <= 3 km AGL"
                   END
               0 : BEGIN
                   SCAT_DATA = "Stratiform Samples, Below Bright Band and <= 3 km AGL"
                   END
              ENDCASE
;              IF raintypeBBidx EQ 1 THEN BEGIN
;                 SCAT_DATA = "Convective Samples, Below Bright Band and <= 3 km AGL"
;              ENDIF ELSE BEGIN
;                 SCAT_DATA = "Stratiform Samples, Below Bright Band and <= 3 km AGL"
;              ENDELSE
              xticknames=STRING(INDGEN(6)*0.5, FORMAT='(F0.1)')
              yticknames=xticknames
              ;BINSPAN = 0.1
              xmajor=N_ELEMENTS(xticknames) & ymajor=xmajor
              IF have_DprEpsilon EQ 1 THEN BEGIN
                 titleLine1 = satprodtype+' '+version+" Internal vs. GR "+ $
                              " Epsilon Scatter, Mean GR-DPR Bias: "
                 pngpre=pr_or_dpr+'_'+version+"_Internal_vs_GR_Epsilon_Scatter"
              ENDIF ELSE BEGIN
                 titleLine1 = satprodtype+' '+version+" Derived vs. GR "+ $
                              " Epsilon Scatter, Mean GR-DPR Bias: "
                 pngpre=pr_or_dpr+'_'+version+"_Derived_vs_GR_Epsilon_Scatter"
              ENDELSE
              units='$\epsilon$'
              xtitle= 'GR $\epsilon$'
              ytitle= pr_or_dpr +' $\epsilon$'
              BREAK
           END
   'HID' : BEGIN
              do_MAE_1_1 = 0
              if raintypeBBidx eq 3 then BEGIN
                   SCAT_DATA = "Convective Samples, Above Bright Band (3 lyrs)"
                   BB_string = '_AboveBB_3lyrs'
                   print, 'HID rain type 3'
              ENDIF ELSE BEGIN
                   goto, plot_skipped1
              ENDELSE
              BREAK
           END
    'MRMSDSR' : BEGIN
    		  if have_mrms NE 1 then break
print, "mrms plot...."
              do_MAE_1_1 = 1
              CASE raintypeBBidx OF
;               2 : BEGIN
;                   SCAT_DATA = "Any/All Footprints"
;                   ;xticknames=STRING(INDGEN(16)*4, FORMAT='(I0)')
;                   ;xticknames=STRING(INDGEN(16), FORMAT='(I0)')
;                   if rr_log then begin
;                   		xticknames=log_label(8, 2)
;                   endif else begin
;                   		xticknames=STRING(INDGEN(16), FORMAT='(I0)')
;                   endelse                    
;                   END
;               ELSE : BEGIN
;                   do_plot = 0
;                   END

              2 : BEGIN
                   SCAT_DATA = "Any/All Samples, Below Bright Band and <= 3 km AGL"
                    if rr_log then begin
 ;                  		yticknames=log_label(8, 8)
                   		yticknames=log_ticks()
                   endif else begin
                   		yticknames=STRING(INDGEN(16)*4, FORMAT='(I0)')
                   endelse                    
                   trim = 0    ; show low-percentage outliers
                   END
               1 : BEGIN
                   SCAT_DATA = "Convective Samples, Below Bright Band and <= 3 km AGL"
                   if rr_log then begin
;                   		yticknames=log_label(8, 8)
                   		yticknames=log_ticks()
                   endif else begin
                   		yticknames=STRING(INDGEN(16)*4, FORMAT='(I0)')
                   endelse                    
                   trim = 0    ; show low-percentage outliers
                   END
               0 : BEGIN
                   SCAT_DATA = "Stratiform Samples, Below Bright Band and <= 3 km AGL"
                   if rr_log then begin
;                   		yticknames=log_label(8, 2)
                   		yticknames=log_ticks()
                   		trim = 0    ; show low-percentage outliers
                   endif else begin
                   		yticknames=STRING(INDGEN(16), FORMAT='(I0)')
                   endelse                    
                   END
              ENDCASE
              if do_plot NE 1 then break

              xticknames=yticknames
              xmajor=N_ELEMENTS(xticknames) & ymajor=xmajor
              titleLine1 = satprodtype+' '+version+" MRMS RR vs. DPR Sfc RR "+ $
                            " Scatter, Mean MRMS-DPR RR Bias: "
 ;                          " Scatter"
              pngpre=pr_or_dpr+'_'+version+"_MRMSRR_vs_DPRSRR_"+PlotTypes(idx2do)+"_Scatter"
              ;units='(mm/h)'
              ;if rr_log then units='(log mm/h)' else units='(mm/h)'
              units='(mm/h)'
              xtitle= 'MRMS '+ units
              ytitle= 'DPR '+units
              BREAK
           END
   'GRRMRMS' :BEGIN
print, "GRRMRMS plot...."

			  if have_mrms NE 1 then break
              do_MAE_1_1 = 1
              CASE raintypeBBidx OF
               2 : BEGIN
                   SCAT_DATA = "Any/All Samples, Below Bright Band and <= 3 km AGL"
                    if rr_log then begin
                   		yticknames=log_ticks()
                   		;yticknames=log_label(8, 8)
                   endif else begin
                   		yticknames=STRING(INDGEN(16)*4, FORMAT='(I0)')
                   endelse                    
                   trim = 0    ; show low-percentage outliers
                   END
               1 : BEGIN
                   SCAT_DATA = "Convective Samples, Below Bright Band and <= 3 km AGL"
                   if rr_log then begin
                   		;yticknames=log_label(8, 8)
                   		yticknames=log_ticks()
                   endif else begin
                   		yticknames=STRING(INDGEN(16)*4, FORMAT='(I0)')
                   endelse                    
                   trim = 0    ; show low-percentage outliers
                   END
               0 : BEGIN
                   SCAT_DATA = "Stratiform Samples, Below Bright Band and <= 3 km AGL"
                   if rr_log then begin
                   		;yticknames=log_label(8, 2)
                   		yticknames=log_ticks()
                   		trim = 0    ; show low-percentage outliers
                   endif else begin
                   		yticknames=STRING(INDGEN(16), FORMAT='(I0)')
                   endelse                    
                   END
              ENDCASE
              if do_plot NE 1 then break

              xticknames=yticknames
              xmajor=N_ELEMENTS(xticknames) & ymajor=xmajor
              titleLine1 = satprodtype+' '+version+" GR RR vs. MRMS RR "+ $
                           " Scatter, Mean GR-MRMS RR Bias: "
;                           " Scatter"
              pngpre=pr_or_dpr+'_'+version+"_GRSRR_vs_MRMSRR_"+PlotTypes(idx2do)+"_Scatter"
              ;units='(mm/h)'
              ;if rr_log then units='(log mm/h)' else units='(mm/h)'
              units='(mm/h)'
              xtitle= 'GR RR '+units
              ytitle= 'MRMS '+ units
              BREAK
           END
   'GRCMRMS' :BEGIN
print, "GRCMRMS plot...."

			  if have_mrms NE 1 then break
              do_MAE_1_1 = 1
              CASE raintypeBBidx OF
               2 : BEGIN
                   SCAT_DATA = "Any/All Samples, Below Bright Band and <= 3 km AGL"
                    if rr_log then begin
                   		;yticknames=log_label(8, 8)
                   		yticknames=log_ticks()
                   endif else begin
                   		yticknames=STRING(INDGEN(16)*4, FORMAT='(I0)')
                   endelse                    
                   trim = 0    ; show low-percentage outliers
                   END
               1 : BEGIN
                   SCAT_DATA = "Convective Samples, Below Bright Band and <= 3 km AGL"
                   if rr_log then begin
                   		;yticknames=log_label(8, 8)
                   		yticknames=log_ticks()
                   endif else begin
                   		yticknames=STRING(INDGEN(16)*4, FORMAT='(I0)')
                   endelse                    
                   trim = 0    ; show low-percentage outliers
                   END
               0 : BEGIN
                   SCAT_DATA = "Stratiform Samples, Below Bright Band and <= 3 km AGL"
                   if rr_log then begin
                   		;yticknames=log_label(8, 2)
                   		yticknames=log_ticks()
                   		trim = 0    ; show low-percentage outliers
                   endif else begin
                   		yticknames=STRING(INDGEN(16), FORMAT='(I0)')
                   endelse                    
                   END
              ENDCASE
              if do_plot NE 1 then break

              xticknames=yticknames
              xmajor=N_ELEMENTS(xticknames) & ymajor=xmajor
              titleLine1 = satprodtype+' '+version+" GR RC vs. MRMS RR "+ $
                           " Scatter, Mean GR-MRMS RR Bias: "
;                           " Scatter"
              pngpre=pr_or_dpr+'_'+version+"_GRSRC_vs_MRMSRR_"+PlotTypes(idx2do)+"_Scatter"
              ;units='(mm/h)'
              ;if rr_log then units='(log mm/h)' else units='(mm/h)'
              units='(mm/h)'
              xtitle= 'GR RC '+units
              ytitle= 'MRMS '+ units
              BREAK
           END
   'GRPMRMS' :BEGIN
print, "GRCMRMS plot...."

			  if have_mrms NE 1 then break
              do_MAE_1_1 = 1
              CASE raintypeBBidx OF
               2 : BEGIN
                   SCAT_DATA = "Any/All Samples, Below Bright Band and <= 3 km AGL"
                    if rr_log then begin
                   		;yticknames=log_label(8, 8)
                   		yticknames=log_ticks()
                   endif else begin
                   		yticknames=STRING(INDGEN(16)*4, FORMAT='(I0)')
                   endelse                    
                   trim = 0    ; show low-percentage outliers
                   END
               1 : BEGIN
                   SCAT_DATA = "Convective Samples, Below Bright Band and <= 3 km AGL"
                   if rr_log then begin
                   		yticknames=log_ticks()
                   		;yticknames=log_label(8, 8)
                   endif else begin
                   		yticknames=STRING(INDGEN(16)*4, FORMAT='(I0)')
                   endelse                    
                   trim = 0    ; show low-percentage outliers
                   END
               0 : BEGIN
                   SCAT_DATA = "Stratiform Samples, Below Bright Band and <= 3 km AGL"
                   if rr_log then begin
                   		;yticknames=log_label(8, 2)
                   		yticknames=log_ticks()
                   		trim = 0    ; show low-percentage outliers
                   endif else begin
                   		yticknames=STRING(INDGEN(16), FORMAT='(I0)')
                   endelse                    
                   END
              ENDCASE
              if do_plot NE 1 then break

              xticknames=yticknames
              xmajor=N_ELEMENTS(xticknames) & ymajor=xmajor
              titleLine1 = satprodtype+' '+version+" GR RP vs. MRMS RR "+ $
                           " Scatter, Mean GR-MRMS RR Bias: "
;                           " Scatter"
              pngpre=pr_or_dpr+'_'+version+"_GRSRP_vs_MRMSRR_"+PlotTypes(idx2do)+"_Scatter"
              ;units='(mm/h)'
              ;if rr_log then units='(log mm/h)' else units='(mm/h)'
              units='(mm/h)'
              xtitle= 'GR RP '+units
              ytitle= 'MRMS '+ units
              BREAK
           END
  'GRRDSR' :BEGIN
print, "GRRDSR plot...."

              do_MAE_1_1 = 1
              CASE raintypeBBidx OF
               2 : BEGIN
                   SCAT_DATA = "Any/All Samples, Below Bright Band and <= 3 km AGL"
                    if rr_log then begin
                   		;yticknames=log_label(8, 8)
                   		yticknames=log_ticks()
                   endif else begin
                   		yticknames=STRING(INDGEN(16)*4, FORMAT='(I0)')
                   endelse                    
                   trim = 0    ; show low-percentage outliers
                   END
               1 : BEGIN
                   SCAT_DATA = "Convective Samples, Below Bright Band and <= 3 km AGL"
                   if rr_log then begin
                   		;yticknames=log_label(8, 8)
                   		yticknames=log_ticks()
                   endif else begin
                   		yticknames=STRING(INDGEN(16)*4, FORMAT='(I0)')
                   endelse                    
                   trim = 0    ; show low-percentage outliers
                   END
               0 : BEGIN
                   SCAT_DATA = "Stratiform Samples, Below Bright Band and <= 3 km AGL"
                   if rr_log then begin
                   		;yticknames=log_label(8, 2)
                   		yticknames=log_ticks()
                   		trim = 0    ; show low-percentage outliers
                   endif else begin
                   		yticknames=STRING(INDGEN(16), FORMAT='(I0)')
                   endelse                    
                   END
              ENDCASE
              if do_plot NE 1 then break

              xticknames=yticknames
              xmajor=N_ELEMENTS(xticknames) & ymajor=xmajor
              titleLine1 = satprodtype+' '+version+" GR RR vs. DPR Sfc RR "+ $
                           " Scatter, Mean GR-DPR RR Bias: "
;                           " Scatter "
              pngpre=pr_or_dpr+'_'+version+"_GRSRR_vs_DPRSRR_"+PlotTypes(idx2do)+"_Scatter"
              ;units='(mm/h)'
              ;if rr_log then units='(log mm/h)' else units='(mm/h)'
              units='(mm/h)'
              xtitle= 'GR RR '+units
              ytitle= 'DPR '+ units
              BREAK
           END
  'GRCDSR' :BEGIN
print, "GRCDSR plot...."

              do_MAE_1_1 = 1
              CASE raintypeBBidx OF
               2 : BEGIN
                   SCAT_DATA = "Any/All Samples, Below Bright Band and <= 3 km AGL"
                    if rr_log then begin
                   		;yticknames=log_label(8, 8)
                   		yticknames=log_ticks()
                   endif else begin
                   		yticknames=STRING(INDGEN(16)*4, FORMAT='(I0)')
                   endelse                    
                   trim = 0    ; show low-percentage outliers
                   END
               1 : BEGIN
                   SCAT_DATA = "Convective Samples, Below Bright Band and <= 3 km AGL"
                   if rr_log then begin
                   		;yticknames=log_label(8, 8)
                   		yticknames=log_ticks()
                   endif else begin
                   		yticknames=STRING(INDGEN(16)*4, FORMAT='(I0)')
                   endelse                    
                   trim = 0    ; show low-percentage outliers
                   END
               0 : BEGIN
                   SCAT_DATA = "Stratiform Samples, Below Bright Band and <= 3 km AGL"
                   if rr_log then begin
                   		;yticknames=log_label(8, 2)
                   		yticknames=log_ticks()
                   		trim = 0    ; show low-percentage outliers
                   endif else begin
                   		yticknames=STRING(INDGEN(16), FORMAT='(I0)')
                   endelse                    
                   END
              ENDCASE
              if do_plot NE 1 then break

              xticknames=yticknames
              xmajor=N_ELEMENTS(xticknames) & ymajor=xmajor
              titleLine1 = satprodtype+' '+version+" GR RC vs. DPR Sfc RR "+ $
                           " Scatter, Mean GR-DPR RR Bias: "
;                           " Scatter "
              pngpre=pr_or_dpr+'_'+version+"_GRSRC_vs_DPRSRR_"+PlotTypes(idx2do)+"_Scatter"
              ;units='(mm/h)'
              ;if rr_log then units='(log mm/h)' else units='(mm/h)'
              units='(mm/h)'
              xtitle= 'GR RC '+units
              ytitle= 'DPR '+ units
              BREAK
           END
  'GRPDSR' :BEGIN
print, "GRPDSR plot...."

              do_MAE_1_1 = 1
              CASE raintypeBBidx OF
               2 : BEGIN
                   SCAT_DATA = "Any/All Samples, Below Bright Band and <= 3 km AGL"
                    if rr_log then begin
                   		;yticknames=log_label(8, 8)
                   		yticknames=log_ticks()
                   endif else begin
                   		yticknames=STRING(INDGEN(16)*4, FORMAT='(I0)')
                   endelse                    
                   trim = 0    ; show low-percentage outliers
                   END
               1 : BEGIN
                   SCAT_DATA = "Convective Samples, Below Bright Band and <= 3 km AGL"
                   if rr_log then begin
                   		yticknames=log_ticks()
                   		;yticknames=log_label(8, 8)
                   endif else begin
                   		yticknames=STRING(INDGEN(16)*4, FORMAT='(I0)')
                   endelse                    
                   trim = 0    ; show low-percentage outliers
                   END
               0 : BEGIN
                   SCAT_DATA = "Stratiform Samples, Below Bright Band and <= 3 km AGL"
                   if rr_log then begin
                   		;yticknames=log_label(8, 2)
                   		yticknames=log_ticks()
                    	trim = 0    ; show low-percentage outliers
                   endif else begin
                   		yticknames=STRING(INDGEN(16), FORMAT='(I0)')
                   endelse                    
                   END
              ENDCASE
              if do_plot NE 1 then break

              xticknames=yticknames
              xmajor=N_ELEMENTS(xticknames) & ymajor=xmajor
              titleLine1 = satprodtype+' '+version+" GR RP vs. DPR Sfc RR "+ $
                           " Scatter, Mean GR-DPR RR Bias: "
;                           " Scatter "
              pngpre=pr_or_dpr+'_'+version+"_GRSRP_vs_DPRSRR_"+PlotTypes(idx2do)+"_Scatter"
              ;units='(mm/h)'
              ;if rr_log then units='(log mm/h)' else units='(mm/h)'
              units='(mm/h)'
              xtitle= 'GR RP '+units
              ytitle= 'DPR '+ units
              BREAK
           END
    ; Z cases
    ELSE : BEGIN
              CASE raintypeBBidx OF
 ;  TAB 11/10/17 added convective samples above BB
               3 : BEGIN
                   SCAT_DATA = "Convective Samples, Above Bright Band (3 lyrs)"
                   xticknames=['20','25','30','35','40','45','50','55','60','65']
                   BB_string = '_AboveBB_3lyrs'
                   END
               2 : BEGIN
                   SCAT_DATA = "Any/All Samples, Above Bright Band"
                   xticknames=['20','25','30','35','40','45','50','55','60','65']
                   BB_string = '_AboveBB'
                   END
               1 : BEGIN
                   SCAT_DATA = "Convective Samples, Below Bright Band"
                   xticknames=['20','25','30','35','40','45','50','55','60','65']
                   END
               0 : BEGIN
                   SCAT_DATA = "Stratiform Samples, Above Bright Band"
                   xticknames=['15','20','25','30','35','40','45']
                   BB_string = '_AboveBB'
                   END
              ENDCASE
;              IF raintypeBBidx EQ 1 THEN BEGIN
;                 SCAT_DATA = "Convective Samples, Below Bright Band"
;                 xticknames=['20','25','30','35','40','45','50','55','60','65']
;              ENDIF ELSE BEGIN
;                 SCAT_DATA = "Stratiform Samples, Above Bright Band"
;                 xticknames=['15','20','25','30','35','40','45']
;                 BB_string = '_AboveBB'
;              ENDELSE
              IF PlotTypes(idx2do) EQ 'ZM' THEN DPRtxt=' Zmeas ' ELSE DPRtxt=' Zcor '
              yticknames=xticknames
              ;IF N_ELEMENTS(bins4scat) EQ 1 THEN BINSPAN = bins4scat ELSE BINSPAN = 2.0
              xmajor=N_ELEMENTS(xticknames) & ymajor=xmajor
              titleLine1 = satprodtype+' '+version+DPRtxt+" vs. GR Z Scatter, Mean GR-DPR Bias: "
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
      
      ; only do plot for MRMS raintypeBBidx 2
      if do_plot NE 1 then continue
      
      ; Plotting section.....................................................
    
    numBars=1
	CASE PlotTypes(idx2do) OF
	   'GRDMSH' : BEGIN
;    	    titleLine1 = "GR Dm Std Dev Histogram  "+satprodtype+" for " $
;               + pr_or_dpr+' '+version
    	    titleLine1 = satprodtype+' '+version+ " GR Dm Std Dev Histogram"
; fix these for easy comparison between runs
			minstddev=0.0
			maxstddev=0.8
   
			CASE raintypeBBidx OF
			   0 : BEGIN
			      if GRDMSH_below_s eq !NULL then begin
			      	  print, "GRDMSH histogram is empty, skipping plot..."
			      	  goto, plot_skipped1
			      endif
			      BB_string = '_BelowBB'			      
			      ; use stratiform types below the BB at/below 3 km
;				  minstddev=MIN(GRDMSH_below_s)
;				  maxstddev=MAX(GRDMSH_below_s)
				  print,"GRDMSH minstdev ", minstddev
				  print,"GRDMSH maxstdev ", maxstddev
				  hist1 = HISTOGRAM(GRDMSH_below_s, LOCATIONS=xvals1, min=minstddev, max=maxstddev, nbins=10)      
				  numPts = long(total(hist1,/INTEGER))
				  nstr = STRING(numPts, FORMAT='(I0)')
        		  imTITLE = titleLine1+ ", N="+nstr+"!C" + $
                      "Stratiform Samples, Below Bright Band and <= 3 km AGL, " +pctabvstr+" Above Thresh"
			      END
			   1 : BEGIN
			      if GRDMSH_below_c eq !NULL then begin
			      	  print, "GRDMSH histogram is empty, skipping plot..."
			      	  goto, plot_skipped1
			      endif
			      BB_string = '_BelowBB'			      
			      ; use convective rain types below the BB at/below 3 km
;				  minstddev=MIN(GRDMSH_below_c)
;				  maxstddev=MAX(GRDMSH_below_c)
				  print,"GRDMSH minstdev ", minstddev
				  print,"GRDMSH maxstdev ", maxstddev
				  hist1 = HISTOGRAM(GRDMSH_below_c, LOCATIONS=xvals1, min=minstddev, max=maxstddev, nbins=10)      
				  numPts = long(total(hist1,/INTEGER))
;        		  imTITLE = titleLine1+"!C" + $
;                      pctabvstr+" Above Thresh.  Convective Samples, Below Bright Band and <= 3 km AGL"
				  nstr = STRING(numPts, FORMAT='(I0)')
        		  imTITLE = titleLine1+ ", N="+nstr+"!C" + $
                      "Convective Samples, Below Bright Band and <= 3 km AGL, " +pctabvstr+" Above Thresh"
			      END
			ELSE: BEGIN
			         goto, plot_skipped1
			      END
			ENDCASE
	   	END
	   'GRZSH' : BEGIN
    	    titleLine1 = "GR Z Std Dev Histogram "+satprodtype+" for " $
               + pr_or_dpr+' '+version
; fix these for easy comparison between runs
			minstddev=0.0
			maxstddev=12.0
			CASE raintypeBBidx OF
			   0 : BEGIN
			      if GRZSH_below_s eq !NULL then begin
			      	  print, "GRZSH histogram is empty, skipping plot..."
			      	  goto, plot_skipped1
			      endif
 				  BB_string = '_BelowBB'
 ;       		  imTITLE = titleLine1+"!C" + $
 ;                     pctabvstr+" Above Thresh.  Stratiform Samples, Below Bright Band and <= 3 km AGL"
			      ; use any/all rain types below the BB at/below 3 km
;				  minstddev=MIN(GRZSH_below_s)
;				  maxstddev=MAX(GRZSH_below_s)
				  print,"GRZSH minstdev ", minstddev
				  print,"GRZSH maxstdev ", maxstddev
				  hist1 = HISTOGRAM(GRZSH_below_s, LOCATIONS=xvals1, min=minstddev, max=maxstddev, nbins=10)      
				  numPts = long(total(hist1,/INTEGER))
				  nstr = STRING(numPts, FORMAT='(I0)')
        		  imTITLE = titleLine1+ ", N="+nstr+"!C" + $
                      "Stratiform Samples, Below Bright Band and <= 3 km AGL, " +pctabvstr+" Above Thresh"
			      END
			   1 : BEGIN
			      if GRZSH_below_c eq !NULL then begin
			      	  print, "GRZSH histogram is empty, skipping plot..."
			      	  goto, plot_skipped1
			      endif
 				  BB_string = '_BelowBB'
;        		  imTITLE = titleLine1+"!C" + $
;                      pctabvstr+" Above Thresh.  Convective Samples, Below Bright Band and <= 3 km AGL"
			      ; use any/all rain types below the BB at/below 3 km
;				  minstddev=MIN(GRZSH_below_c)
;				  maxstddev=MAX(GRZSH_below_c)
				  print,"GRZSH minstdev ", minstddev
				  print,"GRZSH maxstdev ", maxstddev
				  hist1 = HISTOGRAM(GRZSH_below_c, LOCATIONS=xvals1, min=minstddev, max=maxstddev, nbins=10)      
				  numPts = long(total(hist1,/INTEGER))
				  nstr = STRING(numPts, FORMAT='(I0)')
        		  imTITLE = titleLine1+ ", N="+nstr+"!C" + $
                      "Convective Samples, Below Bright Band and <= 3 km AGL, " +pctabvstr+" Above Thresh"
			      END
			   3 : BEGIN
			      if GRZSH_above_3 eq !NULL or GRZSH_above_4 eq !NULL then begin
			      	  print, "GRZSH histogram is empty, skipping plot..."
			      	  goto, plot_skipped1
			      endif
  				  BB_string = '_AboveBB'
;         		  imTITLE = titleLine1+"!C" + $
;                   pctabvstr+" Above Thresh. convective above BB up to four 1.5km layers"
        		  imTITLE = titleLine1+ "!C" + $
                      "convective above BB up to four 1.5km layers, " +pctabvstr+" Above Thresh"
	              ; use four layers above highest layer affected by BB
;				  min1=MIN(GRZSH_above_4)
;				  min2=MIN(GRZSH_above_3)
;				  max1=MAX(GRZSH_above_4)
;				  max2=MAX(GRZSH_above_3)
;				  minstddev=MIN([min1,min2])
;				  maxstddev=MAX([max1,max2])
				  hist1 = HISTOGRAM(GRZSH_above_4, LOCATIONS=xvals1, min=minstddev, max=maxstddev, nbins=10)      
				  hist2 = HISTOGRAM(GRZSH_above_3, LOCATIONS=xvals2, min=minstddev, max=maxstddev, nbins=10)  
			      numBars=2
			      END
			ELSE: BEGIN
			         goto, plot_skipped1
			      END
			ENDCASE
	   	END
	   	ELSE: BEGIN
	   	END
	ENDCASE		   		


   if PlotTypes(idx2do) EQ 'GRDMSH' OR  PlotTypes(idx2do) EQ 'GRZSH' then begin
   
        PRINT, ''
        PRINT, '' 
        PRINT, "PLOTTING: Std Dev Histograms ", PlotTypes(idx2do)+ '_'+ rntypeLabels[raintypeBBidx]+BB_string
        PRINT, '' 

        IF do_dm_thresh EQ 1 OR do_dm_range EQ 1 THEN BEGIN
             imTITLE = imTITLE + " " + filtertitlestring + dmTitleText
        ENDIF ELSE BEGIN 
             imTITLE = imTITLE + " " + filtertitlestring
        ENDELSE
        hist1_total=total(hist1, /double)
        hist1=100.0 * (hist1/hist1_total)
        bar = barplot(xvals1,hist1,ytitle='% Samples', xtitle='Standard Deviation' $
                      , title=imTITLE, /BUFFER, INDEX=0, NBARS=numBars, FILL_COLOR='blue' $
                      , xrange=[minstddev,maxstddev], yrange=[0,100])
;        bar = barplot(xvals1,hist1,ytitle='Sample Count', xtitle='Standard Deviation' $
;                      , title=imTITLE, /BUFFER, INDEX=0, NBARS=numBars, FILL_COLOR='blue')
        if numBars eq 2 then begin
        	hist2_total=total(hist2, /double)
        	hist2=100.0 * (hist2/hist2_total)
        	bar = barplot(xvals2,hist2,ytitle='% Samples', $
                      /BUFFER, INDEX=1, NBARS=numBars, FILL_COLOR='green' $
                      , xrange=[minstddev,maxstddev], yrange=[0,100], /OVERPLOT)
			startx = minstddev + 0.45*(maxstddev-minstddev)
			histmax = max([hist1,hist2])
;			starty1 = 0.9*histmax
;			starty2 = 0.85*histmax
			starty1 = 90
			starty2 = 85
			
			nstr1 = STRING(long(hist1_total), FORMAT='(I0)')
			str1 = '4 levels above BB, N=' + nstr1
       		text1 = TEXT(startx,starty1, str1, /CURRENT, $ 
                COLOR='blue', /DATA)
			nstr2 = STRING(long(hist2_total), FORMAT='(I0)')
			str2 = + '3 levels above BB + 2, N=' + nstr2
        	text2 = TEXT(startx,starty2, str2, /CURRENT, $ 
                COLOR='green', /DATA)
        endif

        pngfile = outpath_sav + '/'+ PlotTypes(idx2do) + '_'+ rntypeLabels[raintypeBBidx] + $
             BB_string + '_Pct'+ strtrim(string(pctAbvThresh),2) + $
             addme + filteraddstring + '.png'
        print, "PNGFILE: ",pngfile
        bar.save, pngfile, RESOLUTION=300
        bar.close
   	  goto, plot_skipped1

   endif
      
;  TAB 11/14/17  only set this up for non-interactive for the time being
   if PlotTypes(idx2do) EQ 'HID' AND raintypeBBidx EQ 3 then begin
        PRINT, ''
        PRINT, '' 
        PRINT, "PLOTTING: ", PlotTypes(idx2do)+ '_'+ rntypeLabels[raintypeBBidx]+BB_string
        PRINT, '' 

;        titleLine1 = "Precip category counts "+satprodtype+" for " $
 ;                             + pr_or_dpr+' '+version
;        imTITLE = titleLine1+"!C" + $
 ;                  pctabvstr+" Above Thresh. convective above BB up to four 1.5km layers"

     	titleLine1 = satprodtype+' '+version+ " Precip category histogram"
        imTITLE = titleLine1+ "!C" + $
              "Convective above BB up to four 1.5km layers, " +pctabvstr+" Above Thresh"

        IF do_dm_thresh EQ 1 OR do_dm_range EQ 1 THEN BEGIN
             imTITLE = imTITLE + " " + filtertitlestring + dmTitleText
        ENDIF ELSE BEGIN 
             imTITLE = imTITLE + " " + filtertitlestring
        ENDELSE
        ;bar = barplot(HID_histogram[raintypeBBidx,*],ytitle='Count', xtitle='Precp category' $
        ;              , title=imTITLE, /BUFFER)

        hist1_total=total(HID_histogram1[raintypeBBidx,1:11], /double)
        hist2_total=total(HID_histogram2[raintypeBBidx,1:11], /double)
        hist1=100.0 * (HID_histogram1[raintypeBBidx,*]/hist1_total)
        hist2=100.0 * (HID_histogram2[raintypeBBidx,*]/hist2_total)
        print, 'hist1_total ', hist1_total
        print, 'hist2_total ', hist2_total
        print, 'hist1 ', hist1
        print, 'hist2 ', hist2
        m1 = max(hist1)
        m2 = max(hist2)
        y1 = max(m1, m2) / 10.0
;        y1 = MAX(HID_histogram1[raintypeBBidx,*])/10

;        bar = barplot(HID_histogram1[raintypeBBidx,*],ytitle='Count', xtitle='Precip category' $
;        bar = barplot(hist1,ytitle='% Samples', xtitle='Precip category', margin=[0.1, 0.3, 0.1, 0.1] $
        bar = barplot(hist1,ytitle='% Samples', xtitle='Precip category' $
                      , title=imTITLE, yrange=[0,100], /BUFFER, INDEX=0, NBARS=2, FILL_COLOR='blue')
;        bar = barplot(HID_histogram2[raintypeBBidx,*],ytitle='Count', xtitle='Precip category' $
        bar = barplot(hist2,ytitle='% Samples', xtitle='Precip category' $
                      , title=imTITLE, yrange=[0,100], /BUFFER, INDEX=1, NBARS=2, FILL_COLOR='green', /OVERPLOT)
;        text1 = TEXT(0, 9.5*y1, '4 levels above BB', /CURRENT, $ 

		nstr1 = STRING(long(hist1_total), FORMAT='(I0)')
		str1 = + '4 levels above BB, N=' + nstr1
 ;       text1 = TEXT(6, 9.5*y1, str1, /CURRENT, $ 
        text1 = TEXT(6, 90, str1, /CURRENT, $ 
                COLOR='blue', /DATA)
;        text2 = TEXT(0, 9*y1, '3 levels above BB + 2', /CURRENT, $ 
		nstr2 = STRING(long(hist2_total), FORMAT='(I0)')
		str2 = + '3 levels above BB + 2, N=' + nstr2
 ;       text2 = TEXT(6, 9*y1, str2, /CURRENT, $ 
        text2 = TEXT(6, 85, str2, /CURRENT, $ 
                COLOR='green', /DATA)

        ax = bar.AXES
        ax[0].HIDE = 1 
        width = 1.0 
      ;  increment=width/13.0
        increment=width/14.0
        pt=.02 + increment/2
        foreach cat, HID_categories do begin
            tx = TEXT(pt,-0.05,cat, target=bar, /relative)
            pt = pt + increment
        endforeach
        pngfile = outpath_sav + '/GR_precip_cat_'+ rntypeLabels[raintypeBBidx] + $
             BB_string + '_Pct'+ strtrim(string(pctAbvThresh),2) + $
             addme + filteraddstring + '.png'
        print, "PNGFILE: ",pngfile
        bar.save, pngfile, RESOLUTION=300
        bar.close

;        mydevice = !D.NAME
;        ; Set plotting to PostScript:
;        SET_PLOT, 'PS'
;        ; Use DEVICE to set some PostScript device options:
;        psfile = outpath_sav + '/precip_cat_'+ rntypeLabels[raintypeBBidx] + $
;             BB_string + '_Pct'+ strtrim(string(pctAbvThresh),2) + $
;             addme + filteraddstring + '.ps'
;        DEVICE, FILENAME=psfile,xsize=7, ysize=5,xoffset=0.5, yoffset=0.5, /inches, /color
;        bar_plot, HID_histogram[raintypeBBidx,*],barnames=HID_categories, ytitle='Count', xtitle='Precp category' $
;                      , title=imTITLE
;        ; Close the PostScript file:
;        DEVICE, /CLOSE
;        ; Return plotting to the original device:
;        SET_PLOT, mydevice

   	goto, plot_skipped1
   endif


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
   bias_str = STRING(biasgrpr, FORMAT='(F0.2)')
;   bias_str = STRING(biasgrpr, FORMAT='(F0.1)')
   MAE_str = STRING(MAE, FORMAT='(F0.2)')
;   MAE_str = STRING(MAE, FORMAT='(F0.1)')
  ; compute normalized bias, used for rain rate plots
   IF ABS(przmean) GT 0.1 THEN BEGIN
      biasNorm = biasgrpr/przmean
      biasNorm_str = STRING(biasNorm, FORMAT='(F0.2)')
;      biasNorm_str = STRING(biasNorm, FORMAT='(F0.1)')
   ENDIF ELSE biasNorm_str = "MISSING"

;   print, ''
   IF do_MAE_1_1 THEN print, "MAE, bias: ", MAE_str+"  "+bias_str
   IF do_normBias THEN print, "Normalized Bias: ", biasNorm_str
;   print, ''

   sh = SIZE((*ptr2do[0]).zhist2d, /DIMENSIONS)
;PRINT, "sh: ", SH

  ; last bin in 2-d histogram only contains values = MAX, cut these
  ; out of the array
  ; zhist2d = (*ptr2do[0]).zhist2d[0:sh[0]-2,0:sh[1]-2]

   ; change this to keep size of zhist2D same for proper number of bins
   ; just blank out the last row, col
   zhist2d = (*ptr2do[0]).zhist2d
   zhist2d[sh[0]-2:sh[0]-1,*] = 0
   zhist2d[*,sh[1]-2:sh[1]-1] = 0

  ; convert counts to percent of total if show_pct is set
   show_pct=1
   IF KEYWORD_SET(show_pct) THEN BEGIN
     ; convert counts to percent of total
      zhist2d = (zhist2d/DOUBLE(nSamp))*100.0D
   ;   IF trim EQ 1 THEN pct2blank = 0.1 ELSE pct2blank = 0.025
      IF trim EQ 1 THEN pct2blank = 0.05 ELSE pct2blank = 0.025
; TAB 4/12/17, set pct2blank to zero if you want to include all small values (requested by Bill Olson)
;  pct2blank = 0.0

	rr_log_x=(*ptr2do[0]).xlog
	rr_log_y=(*ptr2do[0]).ylog
	xmin = (*ptr2do[0]).binmin1
	ymin = (*ptr2do[0]).binmin2
	xmax = (*ptr2do[0]).binmax1
	ymax = (*ptr2do[0]).binmax2
	xbinwidth = (*ptr2do[0]).binspan1
	ybinwidth = (*ptr2do[0]).binspan2
;	hist_x_size = sh[0]-1
;	hist_y_size = sh[1]-1
	hist_x_size = sh[0]
	hist_y_size = sh[1]
	
	; for log-log plots set pct2blank to zero to show all small values
;   if rr_log_x and rr_log_y then begin
;   		pct2blank = 0.0
;   endif

     ; set values below pct2blank to 0%
      histLE5 = WHERE(zhist2d LT pct2blank, countLT5)
      IF countLT5 GT 0 THEN zhist2d[histLE5] = 0.0D
       
     ; SCALE THE HISTOGRAM COUNTS TO 0-255 IMAGE BYTE VALUES
      histImg = BYTSCL(zhist2D)
      logHistImg = histImg
   ENDIF ELSE BEGIN
     ; SCALE THE HISTOGRAM COUNTS TO 0-255 IMAGE BYTE VALUES
      histImg = BYTSCL(zhist2D)
      if not log_bins then begin
      		logHistImg = histImg     		
  	  endif
     ; set non-zero Histo bins that are bytescaled to 0 to a small non-zero value
      idxnotzero = WHERE(histImg EQ 0b AND zhist2D GT 0, nnotzero)
      IF nnotzero GT 0 THEN histImg[idxnotzero] = 1b
   ENDELSE
   
;   rgb=COLORTABLE(33)     ; not available for IDL 8.1, use LOADCT calls
   LOADCT, 33, RGB=rgb, /SILENT   ; gets the values w/o loading the color table
   LOADCT, 33, /SILENT            ; - so call again to load the color table
;  TAB 4/11/17
;  adjust color table gamma to shift to more variation at lower values
;  found this on Coyote's guide to IDL Programming   
; *******
;   gamma = 0.35
;   index = Findgen(256)
;   distribution = index^gamma > 1e-6
;   colorindex = Round(distribution*255 / (Max(distribution) > 1e-6))
;   redscl = rgb[colorindex,0]
;   greenscl = rgb[colorindex,1]
;   bluescl = rgb[colorindex,2]
;   rgb[*,0] = redscl
;   rgb[*,1] = greenscl
;   rgb[*,2] = bluescl
; *******
   rgb[0,*]=255   ; set zero count color to White background

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
   IF do_MAE_1_1 THEN BEGIN
            imTITLE = titleLine1+bias_str+" "+units+n_str+"!C"+SCAT_DATA+", "+ $
            pctabvstr+" Above Thresh."
   ENDIF ELSE BEGIN
            imTITLE = titleLine1+n_str+"!C"+SCAT_DATA+", "+ $
            pctabvstr+" Above Thresh."
   ENDELSE
;  TAB 7/26/17
   IF do_dm_thresh EQ 1 OR do_dm_range EQ 1 THEN BEGIN
      imTITLE = imTITLE + " " + filtertitlestring + dmTitleText
   ENDIF ELSE BEGIN 
      imTITLE = imTITLE + " " + filtertitlestring
   ENDELSE
	
   if rr_log_x or rr_log_y then begin
;   	   rr_log_x=axis_scale.(idx2do)[0]
;   	   rr_log_y=axis_scale.(idx2do)[1]

; test
;xticknames = ['.01', '03', '.05', '.07', '.1', '.3', '.5', '.7', '1', '3', '5', '7','10','30','60']
;xticknames = ['.01', '03', '.05', '.07', '.1', '.3', '.5', '.7', '1', '3', '4', '5', '7','8','10','30','60','100']
;yticknames = ['.01', '03', '.05', '.07', '.1', '.3', '.5', '.7', '1', '3', '4', '5', '7','8','10','30','60','100']

   	   ; log axis labels not working, causes arthmetic error
   	   xmajortick = N_ELEMENTS(xticknames)
   	   ymajortick = N_ELEMENTS(yticknames)
print, 'rr_log_x: ', rr_log_x
print, 'rr_log_y: ', rr_log_y
;print, 'xmajor: ', xmajor
;print, 'xmajortick: ', xmajortick
print, 'xticknames ',xticknames
print, 'yticknames ',yticknames
print, 'xmin ',xmin
print, 'xmax ',xmax
print, 'ymin ',ymin
print, 'ymax ',ymax
	  
	   xtickvalues = FLTARR(xmajortick)
	   for z = 0,xmajortick-1 do begin
	      xtickvalues(z) = float(xticknames(z))
	      if rr_log_x then begin
;	      	  xtickvalues(z) = (ALOG10(xtickvalues(z)) - xmin) * (winsiz[0]-1) / (xmax - xmin) 
	      endif else begin
	          xtickvalues(z) = (xtickvalues(z) - xmin) * (winsiz[0]-1) / (xmax - xmin) 
	      endelse
	   endfor
print, 'xtickvalues ',xtickvalues
print, 'xmajortick ',xmajortick
	   ytickvalues = FLTARR(ymajortick)
	   for z = 0,ymajortick-1 do begin
	      ytickvalues(z) = float(yticknames(z))
	      if rr_log_y then begin
;	          ytickvalues(z) = (ALOG10(ytickvalues(z)) - ymin) * (winsiz[1]-1) / (ymax - ymin) 
	      endif else begin
	          ytickvalues(z) = (ytickvalues(z) - ymin) * (winsiz[1]-1) / (ymax - ymin) 
	      endelse
	   endfor
print, 'ytickvalues ',ytickvalues
print, 'ymajortick ',ymajortick
	   
	   
  ; try contour plot for log plots
       x_cont = fltarr(hist_x_size)
       for ind1=0,hist_x_size-1 do begin
       	   x_cont(ind1) = xmin + float(ind1)*xbinwidth
;       	   x_cont(ind1) = ind1*xbinwidth + (xbinwidth/2.0)
       endfor
       y_cont = fltarr(hist_y_size)
       for ind1=0,hist_y_size-1 do begin
       	   y_cont(ind1) = ymin + float(ind1)*ybinwidth
;       	   y_cont(ind1) = ind1*ybinwidth + (ybinwidth/2.0)
       endfor
       if not log_bins then begin
       
	       print, 'img dim ', size(logHistImg)
	       print, ' x ', hist_x_size
	       print, ' y ', hist_y_size
	       im = contour(logHistImg,x_cont,y_cont,axis_style=2,  $
	; 	            xminor=9, yminor=9, RGB_TABLE=rgb, BUFFER=buffer, $
	 	            xminor=9, yminor=9, /xlog, /ylog, RGB_TABLE=rgb, BUFFER=buffer, $
		            TITLE = imTITLE, $
		            xmajor=xmajortick, ymajor=ymajortick,xtickname=xticknames, ytickname=yticknames, /FILL, $
		            xrange=[xmin,xmax],yrange=[ymin,ymax], N_LEVELS=64, xstyle=1, ystyle=1, $
		            XTICKVALUES=xtickvalues, YTICKVALUES=ytickvalues, min_value=1)   
	   endif else begin   
		   ; smooth image 
		   histImg=smooth(histImg,9)
		   im=image(histImg, axis_style=2, xmajor=xmajortick, ymajor=ymajortick, $
	;	            xminor=10, yminor=10, /xlog, /ylog, RGB_TABLE=rgb, BUFFER=buffer, $
		            xminor=0, yminor=0, RGB_TABLE=rgb, BUFFER=buffer, $
		            TITLE = imTITLE, XTICKVALUES=xtickvalues, YTICKVALUES=ytickvalues, $
		            xtickname=xticknames, ytickname=yticknames)
		endelse

   endif else begin
	   im=image(histImg, axis_style=2, xmajor=xmajor, ymajor=ymajor, $
	            xminor=4, yminor=4, RGB_TABLE=rgb, BUFFER=buffer, $
	            TITLE = imTITLE)
   		im.xtickname=xticknames
   		im.ytickname=yticknames
   endelse
   
   im.xtitle= xtitle
   im.ytitle= ytitle
   im.Title.Font_Size = 10
    
   ; TAB 12/08/17
   if PlotTypes(idx2do) eq 'DMRRG' then BEGIN
       if do_RR_DM_curve_fit eq 1 and RR_DM_curve_fit_bb_type eq raintypeBBidx then begin
           minx = MIN(rr_dm_x) 
           miny = MIN(rr_dm_y) 
           maxx = MAX(rr_dm_x) 
           maxy = MAX(rr_dm_y) 
           X = (rr_dm_x - minx) * (winsiz[0]-1) / (maxx-minx) 
           Y = (rr_dm_y - miny) * (winsiz[1]-1) / (maxy-miny) 
           line_fit = PLOT(X,Y, /OVERPLOT, color='black' )
           
       endif
   
   endif

   IF do_MAE_1_1 THEN BEGIN
     ; add the 1:1 line to the plot, with white blanking above/below to stand out
      line1_1 = PLOT( /OVERPLOT, [0,winsiz[0]-1], [0,winsiz[1]-1], color='black' )
      lineblo = PLOT( /OVERPLOT, [2,winsiz[0]-1], [0,winsiz[1]-3], color='white' )
      lineabv = PLOT( /OVERPLOT, [0,winsiz[0]-3], [2,winsiz[1]-1], color='white' )

     ; write the MAE value in the image area
      txtmae=TEXT(winsiz[0]*0.2, winsiz[0]*0.85, "MAE: "+MAE_str+" "+units, $
                  /DATA,/FILL_Background,FILL_COLOR='white',TRANSPARENCY=25)
   ENDIF

   IF do_normBias THEN BEGIN
     ; write the normalized bias value in the image area
      txtnrm=TEXT(winsiz[0]*0.2, winsiz[0]*0.9, "Norm. bias: "+biasNorm_str, $
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
   
   if not rr_log or log_bins then begin
   		 cbar=colorbar(target=im, orientation=1, position=[0.95, 0.2, 0.98, 0.75], $
                 TICKVALUES=ticlocs, TICKNAME=ticnms, TITLE=ticID)
   endif
   
   pngfile = outpath_sav + '/' + pngpre + '_'+ rntypeLabels[raintypeBBidx] + $
             BB_string + '_Pct'+ strtrim(string(pctAbvThresh),2) + $
             addme + filteraddstring + '.png'
    ; dump csv version of histogram
   if dump_hist_csv then begin
	   csvfile = outpath_sav + '/' + pngpre + '_'+ rntypeLabels[raintypeBBidx] + $
	             BB_string + '_Pct'+ strtrim(string(pctAbvThresh),2) + $
	             addme + filteraddstring + '.csv'
	   openw, csv_LUN, csvfile, /GET_LUN
	   ; dump histogram as csv
	  ; binmin1:binmin1, binmin2:binmin2, binmax1:binmax1, binmax2:binmax2, $
       ;        binspan1:binspan1, binspan2:binspan
	   
	   xmin = (*ptr2do[0]).binmin1
	   ymin = (*ptr2do[0]).binmin2
	   xmax = (*ptr2do[0]).binmax1
	   ymax = (*ptr2do[0]).binmax2
	   xspan = (*ptr2do[0]).binspan1
	   yspan = (*ptr2do[0]).binspan2
	   
	   histsize = size(zhist2d)
	   xsize = histsize[1]
	   ysize = histsize[2]
	   
	   printf, csv_LUN, xtitle,',', ytitle,',',ticID
	   for i = 0,xsize-1 do begin
	      for j=0, ysize-1 do begin
	      	  printf, csv_LUN, i*xspan+xmin, ',', j*yspan+ymin,',', zhist2d[i,j]
	      endfor 
	   endfor
	   
	   close, csv_LUN
	   FREE_LUN, csv_LUN
	   
   endif

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

plot_skipped1:

ENDFOR
if bustOut then BREAK
endfor

noScatterPlots:

close, anom_LUN
FREE_LUN, anom_LUN
close, hail_LUN
FREE_LUN, hail_LUN

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
  for irntypebb = 0,2 do begin
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
IF have_maxraw250 THEN *ptr_250maxzraw=temporary(maxraw250)
*ptr_rain3=temporary(DPR_RR)
*ptr_pia=temporary(PIA)
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
if (ptr_valid(ptr_250maxzraw) eq 1) then ptr_free,ptr_250maxzraw
if (ptr_valid(ptr_rain3) eq 1) then ptr_free,ptr_rain3
if (ptr_valid(ptr_pia) eq 1) then ptr_free,ptr_pia
 if (ptr_valid(ptr_gvzmax) eq 1) then ptr_free,ptr_gvzmax
 if (ptr_valid(ptr_gvzstddev) eq 1) then ptr_free,ptr_gvzstddev
 if (ptr_valid(ptr_GR_DP_Dmstddev) eq 1) then ptr_free,ptr_GR_DP_Dmstddev
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

if (ptr_valid(ptr_BestHID) eq 1) then ptr_free,ptr_BestHID
if (ptr_valid(ptr_HID) eq 1) then ptr_free,ptr_HID
if (ptr_valid(ptr_bbHeight) eq 1) then ptr_free,ptr_bbHeight

if (ptr_valid(ptr_mrmsrrlow) eq 1) then ptr_free,ptr_mrmsrrlow
if (ptr_valid(ptr_mrmsrrmed) eq 1) then ptr_free,ptr_mrmsrrmed
if (ptr_valid(ptr_mrmsrrhigh) eq 1) then ptr_free,ptr_mrmsrrhigh
if (ptr_valid(ptr_mrmsrrveryhigh) eq 1) then ptr_free,ptr_mrmsrrveryhigh

if (ptr_valid(ptr_mrmsrqiplow) eq 1) then ptr_free,ptr_mrmsrqiplow
if (ptr_valid(ptr_mrmsrqipmed) eq 1) then ptr_free,ptr_mrmsrqipmed
if (ptr_valid(ptr_mrmsrqiphigh) eq 1) then ptr_free,ptr_mrmsrqiphigh
if (ptr_valid(ptr_mrmsrqipveryhigh) eq 1) then ptr_free,ptr_mrmsrqipveryhigh

if (ptr_valid(ptr_MRMS_HID) eq 1) then ptr_free,ptr_MRMS_HID

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
end
