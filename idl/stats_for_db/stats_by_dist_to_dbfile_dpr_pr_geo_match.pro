;+
;  stats_by_dist_to_dbfile_dpr_pr_geo_match.pro
;    - Morris/SAIC/GPM_GV   September 2014
;
; DESCRIPTION
; -----------
; Reads PR, DPR, or DPRGMI and GV reflectivity (default) and spatial fields from
; GRtoPR/GRtoDPR/GRtoDPRGMI matchup files, builds index arrays of categories
; of range, rain type, bright band proximity (above, below, within), and height
; (13 categories, 1.5-19.5 km levels); and an array of actual range.  Computes
; max and mean satellite and GR reflectivity and mean reflectivity differences
; and standard deviation of the differences for each of the 13 height levels for
; points within 100 km of the ground radar.
;
; If an alternate field value of 'Zm' is specified in the ALTFIELD parameter,
; then Zmeasured field's statistics will be computed in place of the default
; attenuation-corrected reflectivity.  Does not apply to DPRGMI analysis.
;
; Statistical results are stratified by raincloud type (Convective, Stratiform)
; and vertical location w.r.t the bright band (above, within, below), and in
; total for all eligible points, for a total of 7 permutations.  These 7
; permutations are further stratified by the points' distance from the radar in
; 3 categories: 0-49km, 50-99km, and (if present) 100-150km, for a grand total
; of 21 raintype/location/range categories.  The results and their identifying
; metadata are written out to an ASCII, delimited text file in a format ready
; to be loaded into the table 'dbzdiff_stats_by_dist_geo' in the 'gpmgv'
; database.
;
; PARAMETERS
; ----------
; None.
;
; FILES
; -----
; /data/tmp/StatsByDistToDBbyGeo.unl   OUTPUT: Formatted ASCII text file holding
;                                              the computed, stratified PR-GV
;                                              reflectivity statistics and its
;                                              identifying metadata fields.
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
; matchup_type - Controls which type of matchup data to process: PR (TRMM data),
;                or DPR or DPRGMI (GPM data).  Determines default ncsitepath
;                such that the selected matchup_type's netCDF files are read. 
;                If matchup_type and ncsitepath are both specified and are at
;                odds, then errors will occur in reading the data.  Default=DPR
;
; KuKa         - designates which DPR instrument's data to analyze for the
;                DPRGMI matchup type, whose matchup netcdf files contain both
;                Ka- and Ku-band data.  Allowable values are 'Ku' and 'Ka'.  If
;                SCANTYPE=swath parameter is 'NS' then KuKa_cmb must be 'Ku'. 
;                If unspecified or if in conflict with swath then the value will
;                be assigned to 'Ku' by default.  Ignored if MATCHUP_TYPE is
;                'PR' or 'DPR'.
;
; swath        - designates which swath (scan type) to analyze for the DPRGMI
;                matchup type, whose geo-match netcdf files contain data for the
;                MS swath for both Ka- and Ku-band, and the NS swath for Ku-band
;                only.  Allowable values are 'MS' and 'NS' (default).  Ignored
;                if MATCHUP_TYPE is 'PR' or 'DPR'.
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
;                 defaults to 'GRto'+matchup_type+'*' (e.g., GRtoDPR*).  Results
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
; outpath       - Directory to which output data file will be written
;
; altfield      - Data field to be analyzed instead of default attenuation-
;                 corrected reflectivity.  Only allowable altfield name is 'Zm'.
;
; bb_relative   - If set, then organize data by distance above/below mean bright
;                 band height rather than by height above the surface
;
; do_stddev     - If set, then compute standard deviation of PR and GR field
;                 values in place of Maximum value
;
; profile_save  - Optional directory to which computed mean profile statistics
;                 variables will be saved as an IDL SAVE file.  Also determines
;                 whether optional mean reflectivity profile plots will be
;                 created.  If unset, no file save and no plots.
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
; first_orbit   - Optional parameter to define the first orbit to be processed.
;                 Value may be specified either as a scalar, indicating the
;                 starting orbit number to pass through, or a 2-element array
;                 indicating the starting and ending orbit numbers to pass
;                 through.
;
; scatterplot   - Optional binary parameter.  If set, then a scatter plot of the
;                 PR/DPR vs. GR reflectivity (by default) or 'altfield' variable
;                 will be created and displayed as an IDL IMAGE object.
;
; bins4scat     - Optional binary parameter.  If set, then overrides default
;                 value of the bin size used in computing histograms for
;                 reflectivity.
;
; plot_obj_array - Optional parameter. If the caller defines this variable (any
;                  type/value) and supplies it to this routine as the parameter,
;                  then it will be redefined as an array of references to IDL
;                  PLOT objects that refer to the optional profile and scatter
;                  plots, but only if the user selects not to have them closed
;                  before this procedure exits.  Only the "top level" PLOT and
;                  IMAGE object references are included, not those of the
;                  overplots, legends, colorbars, etc.  This permits the graphic
;                  objects to be interactively modified, saved, etc. after the
;                  end of program execution.
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
; VERSION2MATCH  - Optional parameter.  Specifies one or more different PPS
;                  version(s) for which the current matchup file must have at
;                  least one corresponding matchup file of these data versions
;                  for the given site and orbit.  That is, if the file for this
;                  site and orbit and PPS version does not exist in at least one
;                  of the versions specified by VERSION2MATCH, then the current
;                  file is excluded in processing the statistics.  The filenames
;                  must match in all other aspects, including the optional
;                  additions to the filenames specified in the NC_NAME_ADD
;                  parameter in effect at the time of matchup file creation by
;                  polar2pr, polar2dpr, or polar2dprgmi.
;
; convbelowscat  - Optional binary parameter.  If set, then scatter plots show
;                  data for convective rain below the bright band (BB) rather
;                  than the default stratiform, above-BB samples.
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
;                  if matchup_type value is not 'DPR', as only this matchup file
;                  type currently contains the stormTopHeight variable.
;
; CALLS
; -----
; stratify_diffs21dist_geo2   stratify_diffs_geo3    printf_stat_struct21dist3
; fprep_geo_match_profiles()   fprep_dpr_geo_match_profiles()
; accum_histograms_by_raintype   get_grouped_data_mean_stddev()
; fplot_mean_profiles()
;
; HISTORY
; -------
; 01/26/09 Morris, GPM GV, SAIC
; - Added GV rain type consistency check with PR rain type, based on GV dBZ
;   values: GV is convective if >=35 dBZ; GV is stratiform if <=25 dBZ.
; 01/27/09 Morris, GPM GV, SAIC
; - Added a threshold for the percent of expected bins above their cutoff values
;   as set at the time the matchups were generated.  We had been requiring 100%
;   complete (gvrej EQ 0 AND zcorrej EQ 0).  Now we set a threshold and write
;   this value in first column of the output data.
; 03/04/09 Morris, GPM GV, SAIC
; - Added gv_convective and gv_stratiform as optional parameters to replace
;   hard-coded values.
; 03/25/09 Morris, GPM GV, SAIC
; - Changed width of bright band influence to 500m above thru 750m below meanBB,
;   from original +/-250m of meanBB, based on what PR cross sections show.
; 06/10/09 Morris, GPM GV, SAIC
; - Added ability to call S-band to Ku-band adjustment function, and added
;   CORRECT_S_BAND binary keyword parameter that controls whether these
;   corrections are to be applied.
; Late2009 Morris, GPM GV, SAIC
; - Added checks for duplicate events (site.orbit combinations).
; 03/15/10 Morris, GPM GV, SAIC
; - Minor change to print statements for level by level vs BB information
; 04/23/10  Morris/GPM GV/SAIC
; - Modified computation of the mean bright band height to exclude points with
;   obvious overestimates of BB height in the 2A25 rangeBinNums.  Modified the
;   depth-of-influence of the bright band to +/- 750m of mean BB height.
; 05/25/10  Morris/GPM GV/SAIC
; - Created from stratified_by_dist_stats_to_dbfile_geo_match.pro.  Modified to
;   call fprep_geo_match_profiles() to read netCDF files and compute most of the
;   derived fields needed for this procedure, including mean bright band height
;   and proximity to bright band as in 4/23/10 changes.
; 11/10/10  Morris/GPM GV/SAIC
; - Modified filtering based on pctAbvThresh to at least filter out no-data
;   points when the percent threshold is zero (take all points).
; - Changed CORRECT_S_BAND binary keyword parameter name to S2KU
; - Added NAME_ADD parameter to distinguish output filenames for different runs,
;   and NCSITEPATH parameter to filter input geo_match netCDF file set.
; 11/30/10  Morris/GPM GV/SAIC
; - Drop geo_match variables not used: top, botm, lat, lon, xcorner, ycorner,
;   pr_index.
; - Add reading and processing of gvzmax and gvzstddev if Version 2 netcdf file.
; 12/6/10  Morris/GPM GV/SAIC
; - Modified to continue to next file in case of error status from
;   fprep_geo_match_profiles2().
; 1/10/11  Morris/GPM GV/SAIC
; - Added BB_RELATIVE parameter to compute statistics grouped by heights
;   relative to the mean bright band height rather than height AGL.
; 9/10/2014  Morris/GPM GV/SAIC
; - Created from stratified_by_dist_stats_to_dbfile_geo_match_ptr2.pro.
; - Modified not to output lines where num. samples in category is zero.
; 9/15/2014  Morris/GPM GV/SAIC
; - Added DO_STDDEV parameter to compute StdDev of PR and GR Z instead of max.
; - Added PROFILE_SAVE parameter to compute ensemble mean profiles of PR and GR
;   Z (or ALTFIELD) along with their N and Standard Deviation values, and save
;   the profile arrays to an IDL SAVE file with the name specified by this
;   parameter's value.
; 11/24/14  Morris/GPM GV/SAIC
; - Added SITELIST parameter to limit the site files processed to only those in
;   the supplied array of site IDs, so that a matched TRMM and GPM set of sites
;   can be run.
; 11/26/14 by Bob Morris, GPM GV (SAIC)
;  - Added parameter alt_bb_height to pass to fprep_dpr_geo_match_profiles().
;    Optional, specifies the pathname to a file to be searched to find an
;    alternate BB height value (see function get_ruc_bb.pro) when one cannot
;    be determined from the DPR BB fields.
; 05/07/15 by Bob Morris, GPM GV (SAIC)
;  - Added parameter first_orbit to define the start of the data to be processed
;    when not all data is to be included in the summaries for mean profiles.
; 07/06/15 by Bob Morris, GPM GV (SAIC)
;  - Added binary keyword parameter EXCLUDE to reverse the function of SITELIST
;    so that only sites NOT in the list are processed.
;  - Removed default assignment of NCSITEPATH if not specified, launch the File
;    Selector to specify the location in this case, starting from the default
;    location /data/gpmgv/netcdf/geo_match/SAT, where SAT is defined by the
;    value of matchup_type (SAT=GPM for DPR, SAT=TRMM for PR).
; 07/08/15 by Bob Morris, GPM GV (SAIC)
;  - Added keyword parameter FIRST_ORBIT to limit the set of filenames to
;    be processed to those after a given orbit.
; 07/31/15 by Bob Morris, GPM GV (SAIC)
;  - Produces a plot of mean profiles by echo top category as an IDL PLOT
;    object if PROFILE_SAVE is set.
;  - Added binary parameter SCATTERPLOT to specify option to output a scatter
;    plot of binned DPR and GR values for specified criteria.
;  - Added parameter PLOT_OBJ_ARRAY as an I/O variable to hold the references
;    to the optional profile PLOT and scatter IMAGE top-level objects so that
;    they can be accessed and manipulated after this procedure exits, if the
;    user chooses to not have them automatically closed at the end of a run.  
;    Otherwise the objects become orphans if left open at the end of the run.
;    References to the add-on objects (LEGEND, COLORBAR, etc.) are not
;    included in the returned array at this time.
; 09/04/15 by Bob Morris, GPM GV (SAIC)
;  - Added keyword parameter RAY_RANGE to specify rays to be included in the
;    statistical computations.
; 11/23/15 by Bob Morris, GPM GV (SAIC)
;  - Added keyword parameter MAX_BLOCKAGE to limit samples to be included in the
;    statistical computations to those with GR beam blockage less than specified
;    fraction or percentage.
; 11/29/15 by Bob Morris, GPM GV (SAIC)
;  - Added option for first_orbit to be either a scalar (lowest orbit number to
;    pass through) or a 2-element array (lowest and highest orbit number to pass
;    through).
; 12/15/15 by Bob Morris, GPM GV (SAIC)
;  - Added option to process DPRGMI statistics. Added KUKA and SCANTYPE keyword
;    parameters to support this mode.
;  - Added ability to filter by blockage to DPRGMI data type.
; 01/06/16 by Bob Morris, GPM GV (SAIC)
;  - Added optional parameter VERSION2MATCH to specify different PPS version(s)
;    for which the current matchup file must have a match for the given site and
;    orbit.
;  - Implemented BB_RELATIVE option for DPRGMI data type.
;  - Added Z_MEAS option to do statistics on Z measured instead of Z corrected.
; 02/15/16 by Bob Morris, GPM GV (SAIC)
;  - Added optional parameter CONVBELOWSCAT to specify that scatter plots show
;    data for convective rain below the BB rather than the default stratiform,
;    above-BB samples.
; 11/15/16 by Bob Morris, GPM GV (SAIC)
;  - Added optional parameters DPR_Z_ADJUST and GR_Z_ADJUST to apply bias
;    corrections to the DPR and GR reflectivities, respectively.
;  - Added ET_RANGE parameter to limit samples by a range of echo top heights
;    between two values.
;  - Removed obsolete Z_MEAS heyword parameter, ALTFIELD=Zm handles this now.
; 07/14/17 Morris, GPM GV, SAIC
;  - Limited values of ALTFIELD to Zm or Zc only.
;  - Restricted values included in the 1-D Histogram for mean bias to only
;    those within the histogram range for both GR and DPR data arrays.
;  - Changed the range of the convective histogram from 20-50 to 15-65 dBZ.
;  - Multiple changes to internal documentation.
;
;
; EMAIL QUESTIONS OR COMMENTS AT:
;       https://pmm.nasa.gov/contact
;-
;===============================================================================


pro stats_by_dist_to_dbfile_dpr_pr_geo_match, matchup_type=matchup_type,     $
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
                                              DO_STDDEV=do_stddev,           $
                                              PROFILE_SAVE=profile_save,     $
                                              ALT_BB_FILE=alt_bb_file,       $
                                              FORCEBB=forcebb,               $
                                              FIRST_ORBIT=first_orbit,       $
                                              SCATTERPLOT=scatterplot,       $
                                              BINS4SCAT=bins4scat,           $
                                              PLOT_OBJ_ARRAY=plot_obj_array, $
                                              RAY_RANGE=ray_range,           $
                                              MAX_BLOCKAGE=max_blockage_in,  $
                                              VERSION2MATCH=version2match,   $
                                              CONVBELOWSCAT=convbelowscat,   $
                                              DPR_Z_ADJUST=dpr_z_adjust,     $
                                              GR_Z_ADJUST=gr_z_adjust,       $
                                              ET_RANGE=et_range

; "include" file for structs returned by read_geo_match_netcdf()
@geo_match_nc_structs.inc

; "include" file for PR data constants
@pr_params.inc

IF KEYWORD_SET(do_stddev) THEN $
   statsset = { event_stats, $
               AvgDif: -99.999, StdDev: -99.999, $
               PRstddevZ: -99.999, PRavgZ: -99.999, $
               GVstddevZ: -99.999, GVavgZ: -99.999, $
               GVabsmaxZ: -99.999, GVmaxstddevZ: -99.999, $
               N: 0L $
              } $
ELSE $
   statsset = { event_stats, $
               AvgDif: -99.999, StdDev: -99.999, $
               PRmaxZ: -99.999, PRavgZ: -99.999, $
               GVmaxZ: -99.999, GVavgZ: -99.999, $
               GVabsmaxZ: -99.999, GVmaxstddevZ: -99.999, $
               N: 0L $
              }


allstats = { stats7ways, $
            stats_total:       {event_stats}, $
            stats_convbelow:   {event_stats}, $
            stats_convin:      {event_stats}, $
            stats_convabove:   {event_stats}, $
            stats_stratbelow:  {event_stats}, $
            stats_stratin:     {event_stats}, $
            stats_stratabove:  {event_stats}  $
           }

; We will make a copy of this structure variable for each level and GV type
; we process so that everything is re-initialized.
statsbydist = { stats21ways, $
              km_le_50:    {stats7ways}, $
              km_50_100:     {stats7ways}, $
              km_gt_100:   {stats7ways}, $
              pts_le_50:  0L, $
              pts_50_100:   0L, $
              pts_gt_100: 0L  $
             }

IF N_ELEMENTS(altfield) EQ 1 THEN BEGIN
   CASE STRUPCASE(altfield) OF
       'ZM' : z2do = 'Zm'
       'ZC' : z2do = 'Zc'    ; (default)
       ELSE : message, "Invalid ALTFIELD value, must be ZC or ZM"
   ENDCASE
ENDIF ELSE z2do = 'zcor'

IF z2do EQ 'Zm' THEN use_zraw = 1 ELSE use_zraw = 0

IF KEYWORD_SET(scatterplot) THEN BEGIN
   do_scatr=1
   zHist_ptr = ptr_new(/allocate_heap)
   biasAccum = 0.0D    ; to accumulate event-weighted bias
   nbiasAccum = 0L     ; to accumulate event weights (# samples)
ENDIF ELSE do_scatr=0
have2dhist = 0
have1dhist = 0

IF ( N_ELEMENTS(matchup_type) NE 1 ) THEN BEGIN
   print, "Defaulting to DPR for matchup_type type."
   pr_or_dpr = 'DPR'
   SATDIR = 'GPM'
ENDIF ELSE BEGIN
   CASE STRUPCASE(matchup_type) OF
      'PR' : BEGIN
               pr_or_dpr = 'PR'
               SATDIR = 'TRMM'
             END
     'DPR' : BEGIN
               pr_or_dpr = 'DPR'
               SATDIR = 'GPM'
             END
  'DPRGMI' : BEGIN
               pr_or_dpr = 'DPRGMI'
               SATDIR = 'GPM'
               IF (use_zraw) THEN BEGIN
                  PRINT, "No Zmeas field in DPRGMI matchups, using Zcor."
                  use_zraw = 0
               ENDIF
             END
      ELSE : message, "Only allowed values for MATCHUP_TYPE are PR, DPR, DPRGMI"
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
         message, 'Parameter ET_RANGE is not valid for MATCHUP_TYPE = '+pr_or_dpr
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
IF keyword_set(use_zraw) THEN addme = addme+'_Zmeas'
IF keyword_set(bb_relative) THEN addme = addme+'_BBrel'
IF N_ELEMENTS(alt_bb_file) EQ 1 THEN addme = addme+'_AltBB'

IF KEYWORD_SET(do_stddev) THEN addme = '_StdDevMode' + addme

s2ku = KEYWORD_SET( s2ku )

IF N_ELEMENTS(outpath) NE 1 THEN BEGIN
   outpath='/data/tmp'
   PRINT, "Assigning default output file path: ", outpath
ENDIF

outpath_sav = outpath  ; default path for any SAVE files to be written

IF ( s2ku ) THEN dbfile = outpath+'/StatsByDist_'+pr_or_dpr+'_GR_Pct'+ $
                          strtrim(string(pctAbvThresh),2)+addme+'_S2Ku.unl' $
ELSE dbfile = outpath+'/StatsByDist_'+pr_or_dpr+'_GR_Pct'+ $
              strtrim(string(pctAbvThresh),2)+addme+'_DefaultS.unl'

PRINT, "Write output to: ", dbfile
OPENW, DBunit, dbfile, /GET_LUN

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
;    value of MATCHUP_TYPE (SAT=GPM for DPR, SAT=TRMM for PR).
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
;ptr_rnFlag=ptr_new(/allocate_heap)
ptr_rnType=ptr_new(/allocate_heap)
IF pr_or_dpr EQ 'DPR' THEN ptr_stmTopHgt=ptr_new(/allocate_heap)
ptr_bbProx=ptr_new(/allocate_heap)
ptr_hgtcat=ptr_new(/allocate_heap)
ptr_dist=ptr_new(/allocate_heap)
ptr_pctgoodpr=ptr_new(/allocate_heap)
ptr_pctgoodgv=ptr_new(/allocate_heap)
ptr_pctgoodrain=ptr_new(/allocate_heap)

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
   prlen = strlen( bname )
   print, "GeoMatch netCDF file: ", ncfilepr

   parsed = strsplit(bname, '.', /EXTRACT)
   site = parsed[1]
   orbit = parsed[3]
   orbitnum=LONG(orbit)
   version=parsed[4]

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
; specified and differs from current version
nvers2match = N_ELEMENTS(version2match)
IF nvers2match NE 0 THEN BEGIN
   nmatch = 0
   for ivers=0,nvers2match-1 do begin
      IF version NE version2match[ivers] THEN BEGIN
         command = 'echo '+ncfilepr+" | sed 's/"+version+"/"+version2match[ivers]+"/g'"
         SPAWN, command, file2match
         nmatch = nmatch +  FILE_TEST(file2match)
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
    PRINT, "matchup_type: ", pr_or_dpr
    status = fprep_geo_match_profiles( ncfilepr, heights, $
       PCT_ABV_THRESH=pctAbvThresh, GV_CONVECTIVE=gvconvective, $
       GV_STRATIFORM=gvstratiform, S2KU=s2ku, PTRfieldflags=ptr_fieldflags, $
       PTRgeometa=ptr_geometa, PTRsweepmeta=ptr_sweepmeta, PTRsitemeta=ptr_sitemeta, $
       PTRGVZMEAN=ptr_gvz, PTRGVMAX=ptr_gvzmax, PTRGVSTDDEV=ptr_gvzstddev, $
       PTRzcor=ptr_zcor, PTRzraw=ptr_zraw, PTRrain3d=ptr_rain3, $
       PTRsfcrainpr=ptr_nearSurfRain, PTRsfcraincomb=ptr_nearSurfRain_2b31, $
       PTRrainflag_int=ptr_rnFlag, PTRraintype_int=ptr_rnType, PTRbbProx=ptr_bbProx, $
       PTRhgtcat=ptr_hgtcat, PTRdist=ptr_dist, PTRpctgoodpr=ptr_pctgoodpr, $
       PTRpctgoodgv=ptr_pctgoodgv, PTRpctgoodrain=ptr_pctgoodrain, BBPARMS=BBparms, $
       BB_RELATIVE=bb_relative )
 END
  'DPR' : BEGIN
    PRINT, "matchup_type: ", pr_or_dpr
    status = fprep_dpr_geo_match_profiles( ncfilepr, heights, $
       PCT_ABV_THRESH=pctAbvThresh, S2KU=s2ku, PTRfieldflags=ptr_fieldflags, $
       PTRgeometa=ptr_geometa, PTRsweepmeta=ptr_sweepmeta, PTRsitemeta=ptr_sitemeta, $
       PTRGVZMEAN=ptr_gvz, PTRGVMAX=ptr_gvzmax, PTRGVSTDDEV=ptr_gvzstddev, $
       PTRzcor=ptr_zcor, PTRzraw=ptr_zraw, PTRrain3d=ptr_rain3, $
       PTRstmTopHgt=ptr_stmTopHgt, PTRGVBLOCKAGE=ptr_GR_blockage, $
       PTRsfcrainpr=ptr_nearSurfRain, PTRsfcraincomb=ptr_nearSurfRain_2b31, $
       PTRrainflag_int=ptr_rnFlag, PTRraintype_int=ptr_rnType, PTRbbProx=ptr_bbProx, $
       PTRhgtcat=ptr_hgtcat, PTRdist=ptr_dist,  PTRpctgoodpr=ptr_pctgoodpr, $
       PTRpctgoodgv=ptr_pctgoodgv, PTRpctgoodrain=ptr_pctgoodrain, BBPARMS=BBparms, $
       BB_RELATIVE=bb_relative, ALT_BB_HGT=alt_bb_file, FORCEBB=forcebb) ;, RAY_RANGE=ray_range )
 END
  'DPRGMI' : BEGIN
    PRINT, "matchup_type: ", pr_or_dpr
    status = fprep_dprgmi_geo_match_profiles( ncfilepr, heights, $
       KUKA=KuKa, SCANTYPE=swath, PCT_ABV_THRESH=pctAbvThresh, S2KU=s2ku, $
       PTRfieldflags=ptr_fieldflags, PTRgeometa=ptr_geometa, $
       PTRsweepmeta=ptr_sweepmeta, PTRsitemeta=ptr_sitemeta, $
       PTRGVZMEAN=ptr_gvz, PTRGVMAX=ptr_gvzmax, PTRGVSTDDEV=ptr_gvzstddev, $
       PTRzcor=ptr_zcor, PTRrain3d=ptr_rain3, $
       PTRGVRCMEAN=ptr_gvrc, PTRGVRPMEAN=ptr_gvrp, PTRGVRRMEAN=ptr_gvrr, $
       PTRGVBLOCKAGE=ptr_GR_blockage, $
       PTRtop=ptr_top, PTRbotm=ptr_botm, $
       PTRsfcrainpr=ptr_nearSurfRain, PTRraintype_int=ptr_rnType, $
       PTRxCorners=ptr_xCorner, PTRyCorners=ptr_yCorner, PTRbbProx=ptr_bbProx, $
       PTRhgtcat=ptr_hgtcat, PTRdist=ptr_dist, PTRpridx_long=ptr_pr_index, $
       PTRpctgoodpr=ptr_pctgoodpr, PTRpctgoodgv=ptr_pctgoodgv, $
       PTRpctgoodrain=ptr_pctgoodrain, PTRpctgoodrcgv=ptr_pctgoodrcgv, $
       PTRpctgoodrpgv=ptr_pctgoodrpgv, PTRpctgoodrrgv=ptr_pctgoodrrgv, $
       BBPARMS=BBparms, BB_RELATIVE=bb_relative, ALT_BB_HGT=alt_bb_file, FORCEBB=forcebb )
 END
ENDCASE


   IF (status EQ 1) THEN GOTO, nextFile
   IF ( s2ku ) THEN $
      IF BBparms.meanbb LT 0.0 THEN BEGIN
         print, 'S2Ku set but no BB defined, skipping case for ', ncfilepr
         GOTO, nextFile
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
   IF pr_or_dpr EQ 'DPRGMI' THEN zraw=*ptr_zcor ELSE zraw=temporary(*ptr_zraw)
   zcor=temporary(*ptr_zcor)
   rain3=temporary(*ptr_rain3)
   ; TAB 2/22/18 added
   IF pr_or_dpr EQ 'DPR' THEN echoTops=temporary(*ptr_stmTopHgt)
   nearSurfRain=temporary(*ptr_nearSurfRain)
   nearSurfRain_2b31=temporary(*ptr_nearSurfRain_2b31)
;   rnflag=temporary(*ptr_rnFlag)
   rntype=temporary(*ptr_rnType)
   bbProx=temporary(*ptr_bbProx)
   hgtcat=temporary(*ptr_hgtcat)
   dist=temporary(*ptr_dist)
   pctgoodpr=temporary(*ptr_pctgoodpr)
   pctgoodgv=temporary(*ptr_pctgoodgv)
   pctgoodrain=temporary(*ptr_pctgoodrain)

  do_GR_blockage = 0
  IF pr_or_dpr NE 'PR' AND ptr_valid(ptr_GR_blockage) THEN BEGIN
     do_GR_blockage=myflags.have_GR_blockage   ; should just be 0 for version<1.21
     GR_blockage=temporary(*ptr_GR_blockage)
  ENDIF ELSE GR_blockage = -1

 ; reset do_GR_blockage flag if set but no MAX_BLOCKAGE value is given
  IF do_GR_blockage EQ 1 AND N_ELEMENTS(max_blockage) NE 1 $
     THEN do_GR_blockage = 0
  ;help, GR_blockage, do_GR_blockage

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
; gate value in the sample average.

   IF ( do_GR_blockage ) THEN BEGIN
      print, 'clipping by blockages'
     ; define an array that flags samples that exceed the max blockage threshold
      unblocked = pctgoodpr < pctgoodgv
      idxBlocked = WHERE( GR_blockage GT max_blockage, countblock)
     ; set blocked sample to a negative value to exclude them in clipping
      IF countblock GT 0 THEN unblocked[idxBlocked] = -66.6
      IF ( pctAbvThreshF GT 0.0 ) THEN BEGIN
          ; clip to the 'good' points, where 'pctAbvThreshF' fraction of bins in average
          ; were above threshold AND blockage is below max allowed
         idxgoodenuff = WHERE( pctgoodpr GE pctAbvThreshF $
                          AND  pctgoodgv GE pctAbvThreshF $
                          AND  unblocked GT 0.0, countgoodpct )
      ENDIF ELSE BEGIN
         idxgoodenuff = WHERE( pctgoodpr GT 0.0 AND pctgoodgv GT 0.0 $
                          AND  unblocked GT 0.0, countgoodpct )
      ENDELSE
   ENDIF ELSE BEGIN
      IF ( pctAbvThreshF GT 0.0 ) THEN BEGIN
          ; clip to the 'good' points, where 'pctAbvThreshF' fraction of bins in average
          ; were above threshold
         idxgoodenuff = WHERE( pctgoodpr GE pctAbvThreshF $
                          AND  pctgoodgv GE pctAbvThreshF, countgoodpct )
      ENDIF ELSE BEGIN
         idxgoodenuff = WHERE( pctgoodpr GT 0.0 AND pctgoodgv GT 0.0, countgoodpct )
      ENDELSE
   ENDELSE

      IF ( countgoodpct GT 0 ) THEN BEGIN
          gvz = gvz[idxgoodenuff]
          zraw = zraw[idxgoodenuff]
          zcor = zcor[idxgoodenuff]
          rain3 = rain3[idxgoodenuff]
          gvzmax = gvzmax[idxgoodenuff]
          gvzstddev = gvzstddev[idxgoodenuff]
;          rnFlag = rnFlag[idxgoodenuff]
          echoTops = echoTops[idxgoodenuff]
          rnType = rnType[idxgoodenuff]
          dist = dist[idxgoodenuff]
          bbProx = bbProx[idxgoodenuff]
          hgtcat = hgtcat[idxgoodenuff]
      ENDIF ELSE BEGIN
          print, ''
          print, "No complete-volume points, skipping case."
          print, ''
          goto, nextFile
      ENDELSE

;-------------------------------------------------------------

  ; Optional data clipping based on echo top height (stormTopHeight) range:
  ; Limit which PR and GV points to include, based on ET height
   IF N_ELEMENTS( et_range_m ) EQ 2 THEN BEGIN
      print, '' & print, 'clipping by echo top height'
     ; define index array that flags samples within the ET range
      idxgoodenuff = WHERE(echoTops GE et_range_m[0] $
                       AND echoTops LE et_range_m[1], countET)
      IF (countET GT 0) THEN BEGIN
          gvz = gvz[idxgoodenuff]
          zraw = zraw[idxgoodenuff]
          zcor = zcor[idxgoodenuff]
          rain3 = rain3[idxgoodenuff]
          gvzmax = gvzmax[idxgoodenuff]
          gvzstddev = gvzstddev[idxgoodenuff]
;          rnFlag = rnFlag[idxgoodenuff]
          echoTops = echoTops[idxgoodenuff]
          rnType = rnType[idxgoodenuff]
          dist = dist[idxgoodenuff]
          bbProx = bbProx[idxgoodenuff]
          hgtcat = hgtcat[idxgoodenuff]
      ENDIF ELSE BEGIN
          print, ''
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

  ; Compute dBZ statistics at each level
   for lev2get = 0, nhgtcats-1 do begin
      hgtstr =  string(heights[lev2get], FORMAT='(f0.1)')
      idxathgt = where(hgtcat EQ lev2get, counthgts)
      if ( counthgts GT 0 ) THEN BEGIN
         print, "HEIGHT = "+hgtstr+" km: npts = ", counthgts
        ; grab the subset of points at this height level
         IF (use_zraw) THEN dbzDPRlev = zraw[idxathgt] $
            ELSE dbzDPRlev = zcor[idxathgt]
         dbznexlev = gvz[idxathgt]
         raintypelev = rntype[idxathgt]
         distcatlev = distcat[idxathgt]
         BBproxlev = BBprox[idxathgt]
         gvzmaxlev = gvzmax[idxathgt]
         gvzstddevlev = gvzstddev[idxathgt]

        ; Compute stratified dBZ statistics at this level
         this_statsbydist = {stats21ways}
         stratify_diffs21dist_geo2, dbzDPRlev, dbznexlev, raintypelev, $
                                    BBproxlev, distcatlev, gvzmaxlev, $
                                    gvzstddevlev, this_statsbydist, $
                                    DO_STDDEV=do_stddev
        ; Write Delimited Output for database
         printf_stat_struct21dist3, this_statsbydist, pctAbvThresh, 'GeoM', $
                                    siteID, orbit, lev2get, heights, DBunit, $
                                    /SUPRESS_ZERO, DO_STDDEV=do_stddev

         IF N_ELEMENTS(profile_save) NE 0 THEN $
            ; accumulate PR and GR dBZ histograms by rain type at this level
            accum_histograms_by_raintype, dbzDPRlev, dbznexlev, raintypelev, $
                                          accum_ptrs, lev2get, bindbz
      ENDIF
   endfor

  ;# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

   IF do_scatr THEN BEGIN
     ; accumulate 2-D histogram of stratiform, above-BB reflectivity, unless
     ; 'convbelowscat' is set, then do convective below BB
      IF KEYWORD_SET(convbelowscat) THEN BEGIN
         idxabv = WHERE( BBprox EQ 0 AND rntype EQ RainType_convective, countabv )
         SCAT_DATA = "Convective Samples, Below Bright Band"
         binmin = 15.0 & binmax=65.0
         ticknames=['15','20','25','30','35','40','45','50','55','60','65']
      ENDIF ELSE BEGIN
         idxabv = WHERE( BBprox EQ 2 AND rntype EQ RainType_stratiform, countabv )
         SCAT_DATA = "Stratiform Samples, Above Bright Band"
         binmin = 15.0 & binmax=45.0
         ticknames=['15','20','25','30','35','40','45']
      ENDELSE
      IF N_ELEMENTS(bins4scat) EQ 1 THEN BINSPAN = bins4scat ELSE BINSPAN = 2.0
      IF (use_zraw) THEN dbzDPRscat = zraw[idxabv] $
         ELSE dbzDPRscat = zcor[idxabv]
      dbzGRscat = gvz[idxabv]

      IF countabv GT 0 THEN BEGIN
        ; Check whether the arrays to be histogrammed both have in-range values,
        ; otherwise just skip trying to histogram out-of-range data
         idx_XY = WHERE(dbzGRscat GE binmin AND dbzGRscat LE binmax $
                    AND dbzDPRscat GE binmin AND dbzDPRscat LE binmax, count_XY)
         dbzGRscat  = dbzGRscat[idx_XY]
         dbzDPRscat = dbzDPRscat[idx_XY]
      ENDIF ELSE count_XY = 0

      IF count_XY GT 0 THEN BEGIN
        ; accumulate the PR and GR bin values in the category, for 2nd
        ; computation of bias (temporary code to test against histogram method)
;         IF N_ELEMENTS(pr_bins_in_category) NE 0 THEN BEGIN
;            pr_bins_in_category = [pr_bins_in_category,dbzDPRscat]
;            gr_bins_in_category = [gr_bins_in_category,dbzGRscat]
;         ENDIF ELSE BEGIN
;            pr_bins_in_category = dbzDPRscat
;            gr_bins_in_category = dbzGRscat
;         ENDELSE

         IF have2dhist THEN BEGIN
            zhist2d = zhist2d + HIST_2D( dbzGRscat, dbzDPRscat, MIN1=binmin, $
                                         MIN2=binmin, MAX1=binmax, MAX2=binmax, $
                                         BIN1=BINSPAN, BIN2=BINSPAN )
;                                         BIN1=0.2, BIN2=0.2 )
            minprz = MIN(dbzDPRscat) < minprz
         ENDIF ELSE BEGIN
            zhist2d = HIST_2D( dbzGRscat, dbzDPRscat, MIN1=binmin, $
                               MIN2=binmin, MAX1=binmax, MAX2=binmax, $
                               BIN1=BINSPAN, BIN2=BINSPAN )
;                               BIN1=0.2, BIN2=0.2 )
            minprz = MIN(dbzDPRscat)
            have2dhist = 1
         ENDELSE

        ; compute the mean GR Z for the samples in each DPR histogram bin
         zhist1dpr=HISTOGRAM(dbzDPRscat, MIN=binmin, MAX=binmax, BINSIZE=BINSPAN, $
                             LOCATIONS=Zstarts, REVERSE_INDICES=RIdpr)
         ndprbins=N_ELEMENTS(Zstarts)
         gvzmeanByBin=FLTARR(ndprbins)
         przmeanByBin = gvzmeanByBin
         nbybin = lonarr(ndprbins)
         for ibin = 0, ndprbins-1 do begin
            IF RIdpr[ibin] NE RIdpr[ibin+1] THEN BEGIN
               gvzmeanByBin[ibin] = MEAN( dbzGRscat[ RIdpr[RIdpr[ibin] : RIdpr[ibin+1]-1] ] )
               przmeanByBin[ibin] = MEAN( dbzDPRscat[ RIdpr[RIdpr[ibin] : RIdpr[ibin+1]-1] ] )
               nbybin[ibin] = RIdpr[ibin+1]-RIdpr[ibin]
            ENDIF
         endfor
         print, "locations, gvzmeanByBin: ", Zstarts, gvzmeanByBin, przmeanByBin
        ; accumulate the N-weighted means-by-bin and number of samples in the bin
        ; for later calculation of GR-DPR bias
         IF have1dhist THEN BEGIN
            gvzmeanaccum = gvzmeanaccum + gvzmeanByBin*nbybin
            przmeanaccum = przmeanaccum + przmeanByBin*nbybin
            nbybinaccum = nbybinaccum + nbybin
         ENDIF ELSE BEGIN
            gvzmeanaccum = gvzmeanByBin*nbybin
            przmeanaccum = przmeanByBin*nbybin
            nbybinaccum = nbybin
            have1dhist = 1
         ENDELSE
      ENDIF
   ENDIF

  ;# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

   nextFile:
   lastorbitnum=orbitnum
   lastncfile=bname
   lastsite=site

ENDFOR    ; end of loop over fnum = 0, nf-1

IF have2dhist EQ 1 THEN BEGIN
  ; CREATE THE SCATTER PLOT IMAGE OBJECT FROM THE BINNED DATA

   PRINT, '' & PRINT, "Min PR Z: ", minprz & PRINT, ''
   PRINT, ''
   PRINT, "locations: ", Zstarts+BINSPAN/2
   PRINT, "gvzmeanByBin: ", gvzmeanaccum/nbybinaccum
   PRINT, "przmeanByBin: ", przmeanaccum/nbybinaccum
   PRINT, ''
   idxzdef = WHERE(gvzmeanaccum GE 0.0 and przmeanaccum GE 0.0)
   gvzmean = TOTAL(gvzmeanaccum[idxzdef])/TOTAL(nbybinaccum[idxzdef])
   przmean = TOTAL(przmeanaccum[idxzdef])/TOTAL(nbybinaccum[idxzdef])
   biasgrpr = gvzmean-przmean
   bias_str = STRING(biasgrpr, FORMAT='(F0.2)')
;biasgrprByBins = MEAN(gr_bins_in_category - pr_bins_in_category)
;biasgrpr2 = (gvzmeanaccum[idxzdef]-przmeanaccum[idxzdef])/TOTAL(nbybinaccum[idxzdef])
;help, biasgrprByBins, biasgrpr, biasgrpr2
;help, bias_str
;   biasByAccum = biasAccum / nbiasAccum
;   bias_str2 = STRING(biasgrpr, FORMAT='(F0.1)')
;help, bias_str2, nbiasAccum
   sh = SIZE(zhist2d, /DIMENSIONS)
  ; last bin in 2-d histogram only contains values = MAX, cut these
  ; out of the array
   zhist2d = zhist2d[0:sh[0]-2,0:sh[1]-2]

  ; SCALE THE HISTOGRAM COUNTS TO 0-255 IMAGE BYTE VALUES
   histImg = BYTSCL(zhist2D)
  ; set non-zero Histo bins that are bytescaled to 0 to a small non-zero value
   idxnotzero = WHERE(histImg EQ 0b AND zhist2D GT 0, nnotzero)
   IF nnotzero GT 0 THEN histImg[idxnotzero] = 1b
  ; resize the image array to something like 150 pixels if it is small
   sh = SIZE(histImg, /DIMENSIONS)
   IF MAX(sh) LT 125 THEN BEGIN
      scale = 150/MAX(sh) + 1
      sh2 = sh*scale
      histImg = REBIN(histImg, sh2[0], sh2[1], /SAMPLE)
   ENDIF
   winsiz = SIZE( histImg, /DIMENSIONS )
   histImg = CONGRID(histImg, winsiz[0]*4, winsiz[1]*4)
   winsiz = SIZE( histImg, /DIMENSIONS )
print, 'winsiz: ', winsiz
;   window,  xsize=winsiz[0], ysize=winsiz[1]
;   tvscl, histImg
;   plots, [0,winsiz[0]-1], [0,winsiz[1]-1], color=100, THICK=3, /device
   rgb=COLORTABLE(33)
   rgb[0,*]=255   ; set zero count color to White background
   IF (use_zraw) THEN DPRtxt = ' Zmeas ' ELSE DPRtxt = ' Zcor '

  ; plot the scatter image using IDL Object Graphics
   im=image(histImg, axis_style=2, $
            xmajor=N_ELEMENTS(ticknames), ymajor=N_ELEMENTS(ticknames), $
            xminor=4, yminor=4, RGB_TABLE=rgb, $
            TITLE = pr_or_dpr+DPRtxt+" vs. GR Z Scatter, Mean GR-DPR Bias: "+bias_str $
                    +" dBZ!C"+SCAT_DATA+", "+pctabvstr+" Above Thresh." )

  ; modify and annotate the scatter image object "im"
;   im.xtickname=['15','20','25','30','35','40','45']
;   im.ytickname=['15','20','25','30','35','40','45']
   im.xtickname=ticknames
   im.ytickname=ticknames
   IF ( s2ku ) THEN xtitleadd = ', Ku-adjusted' ELSE xtitleadd = ''
   im.xtitle= 'GR Reflectivity (dBZ)' + xtitleadd
   im.ytitle= pr_or_dpr + ' Reflectivity (dBZ)'
  ; add the 1:1 line to the plot, with white blanking above/below to stand out
   line1_1 = PLOT( /OVERPLOT, [0,winsiz[0]-1], [0,winsiz[1]-1], color='black' )
   lineblo = PLOT( /OVERPLOT, [2,winsiz[0]-1], [0,winsiz[1]-3], color='white' )
   lineabv = PLOT( /OVERPLOT, [0,winsiz[0]-3], [2,winsiz[1]-1], color='white' )

  ; define the parameters for a color bar with 9 tick levels labeled
   ticnms = STRARR(256)
   ticlocs = INDGEN(9)*256/8
   ticInterval = MAX(zhist2d)/8.0
   ticnames = STRING( FIX(indgen(9)*ticInterval), FORMAT='(I0)' )
   ticnms[ticlocs] = ticnames
  ; add a colorbar to the scatter image to define the color ranges
   cbar=colorbar(target=im, ori=1, pos=[0.95, 0.2, 0.98, 0.75], $
                 TICKVALUES=ticlocs, TICKNAME=ticnms, TITLE="# samples")

  ; overplot the mean DPR and GR bin-range values if the binsize is sufficently large
   IF BINSPAN GE 1.0 THEN BEGIN
      plotscale=winsiz[0]/(binmax-binmin)    ; pixels per dBZ, noting that the origin is at (15.,15.)
      bplot = PLOT((gvzmeanaccum/nbybinaccum-binmin)*plotscale < (winsiz[0]-1), $
                   (przmeanaccum/nbybinaccum-binmin)*plotscale, '-r4+', /OVERPLOT)
     ; overplot the sample counts
      idxzdef = WHERE(gvzmeanaccum GE 0.0 and przmeanaccum GE 0.0)
      xtxt=(gvzmeanaccum[idxzdef]/nbybinaccum[idxzdef]-binmin)*plotscale
      ytxt=(przmeanaccum[idxzdef]/nbybinaccum[idxzdef]-binmin)*plotscale
      txttxt=STRING(nbybinaccum[idxzdef],FORMAT='(I0)')
      txtarr=TEXT(xtxt,ytxt,txttxt,/DATA,/FILL_Background,FILL_COLOR='white',TRANSP=25)
   ENDIF
ENDIF

IF N_ELEMENTS(profile_save) NE 0 THEN BEGIN
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

  ; plot the saved profile using IDL Direct Graphics (old style)
   plot_mean_profiles, savfile, FILE_BASENAME(savfile), INSTRUMENT=pr_or_dpr

  ; plot the saved profile using IDL Object Graphics
   thePlot = fplot_mean_profiles( savfile, FILE_BASENAME(savfile), $
                                  INSTRUMENT=pr_or_dpr, LEGEND_XY=[0.9,0.83] )
ENDIF

; pass memory of local-named data field array/structure names back to pointer variables
*ptr_geometa=temporary(mygeometa)
*ptr_sitemeta=temporary(mysite)
*ptr_sweepmeta=temporary(mysweeps)
*ptr_fieldflags=temporary(myflags)
*ptr_gvz=temporary(gvz)
*ptr_zraw=temporary(zraw)
*ptr_zcor=temporary(zcor)
*ptr_rain3=temporary(rain3)
 *ptr_gvzmax=temporary(gvzmax)
 *ptr_gvzstddev=temporary(gvzstddev)
*ptr_nearSurfRain=temporary(nearSurfRain)
*ptr_nearSurfRain_2b31=temporary(nearSurfRain_2b31)
; *ptr_rnflag=temporary(rnFlag)
*ptr_rntype=temporary(rnType)
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
if (ptr_valid(ptr_rain3) eq 1) then ptr_free,ptr_rain3
 if (ptr_valid(ptr_gvzmax) eq 1) then ptr_free,ptr_gvzmax
 if (ptr_valid(ptr_gvzstddev) eq 1) then ptr_free,ptr_gvzstddev
if (ptr_valid(ptr_nearSurfRain) eq 1) then ptr_free,ptr_nearSurfRain
if (ptr_valid(ptr_nearSurfRain_2b31) eq 1) then ptr_free,ptr_nearSurfRain_2b31
;if (ptr_valid(ptr_rnFlag) eq 1) then ptr_free,ptr_rnFlag
if (ptr_valid(ptr_rnType) eq 1) then ptr_free,ptr_rnType
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

FREE_LUN, DBunit
print, ''
print, 'Output file status:'
command = 'ls -al ' + dbfile
spawn, command
print, ''

; copy one or both of the references to the plot object to an array of PLOT
; objects if user defined the plot_obj_array parameter value, so that the
; plot objects are not orphaned when this program exits.  This logic could be
; better implemented!

IF N_ELEMENTS(thePlot) NE 0 THEN BEGIN
   IF SIZE(thePlot, /TYPE) EQ 11 THEN BEGIN
      doodah = ""
      READ, doodah, PROMPT="Enter C to Close plot(s) and exit, " + $
            "or any other key to exit with plot(s) remaining: "
      IF STRUPCASE(doodah) EQ "C" THEN BEGIN
         thePlot.close
         IF have2dhist EQ 1 THEN im.close
      ENDIF ELSE BEGIN
        ; see whether the caller has given us a variable to return the PLOT
        ; and IMAGE object references in
         IF N_ELEMENTS(plot_obj_array) NE 0 THEN BEGIN
            IF have2dhist EQ 1 THEN BEGIN
               plot_obj_array = OBJARR(2)
               plot_obj_array[0] = thePlot   ; mean profile plot object
               plot_obj_array[1] = im        ; scatter plot object
            ENDIF ELSE BEGIN
               plot_obj_array = OBJARR(1)
               plot_obj_array[0] = thePlot   ; mean profile plot object only
            ENDELSE
         ENDIF
      ENDELSE
   ENDIF
ENDIF ELSE BEGIN
   IF N_ELEMENTS(im) NE 0 THEN BEGIN
     ; do we have the scatter plot image/overplots only?
      IF SIZE(im, /TYPE) EQ 11 THEN BEGIN
         doodah = ""
         READ, doodah, PROMPT="Enter C to Close scatter plot and exit, " + $
               "or any other key to exit with plot remaining: "
         IF STRUPCASE(doodah) EQ "C" THEN BEGIN
            im.close
         ENDIF ELSE BEGIN
           ; see whether the caller has given us a variable to return the
           ; IMAGE object reference in
            IF N_ELEMENTS(plot_obj_array) NE 0 THEN BEGIN
               plot_obj_array = OBJARR(1)
               plot_obj_array[0] = im        ; scatter plot object only
            ENDIF
         ENDELSE
      ENDIF
   ENDIF
ENDELSE

errorExit2:

end
