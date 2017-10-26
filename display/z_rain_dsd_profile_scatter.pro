;+
;  z_rain_dsd_profile_scatter.pro     Morris/SAIC/GPM_GV   July 2016
;
; DESCRIPTION
; -----------
; Reads PR (or DPR) and GV reflectivity (default) and spatial fields from
; PRtoDPR or DPRtoGR geo_match netCDF files, builds index arrays of categories
; of range, rain type, bright band proximity (above, below, within), and height
; (13 categories, 1.5-19.5 km levels); and an array of actual range.  Produces
; scatter plots and/or vertical profile plots of PR/DPR vs. GR values, either
; for reflectivity (default) or another variable specified by the "altfield"
; parameter.
;
; If an alternate field is specified in the ALTFIELD parameter, then this field
; will be read and its statistics will be computed in place of reflectivity.
; Possible ALTFIELD values are 'RR' (rain rate), 'D0' (mean drop diameter), and
; 'NW' (normalized intercept parameter).  If D0 or NW are specified, then
; results are computed only for the below-bright-band category.
;
; Statistical results are stratified by raincloud type (Convective, Stratiform)
; and vertical location w.r.t the bright band (above, within, below).
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
; instrument   - Controls which type of matchup data to process: PR (TRMM data)
;                or DPR (GPM data).  Determines default ncsitepath such that the
;                selected instrument's matchup files are read.  If instrument
;                and ncsitepath are both specified and are at odds, then errors
;                will occur in reading the data.  Default=DPR
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
; outpath       - Directory to which output data file will be written
;
; altfield      - Data field to be analyzed instead of default reflectivity.
;                 See prologue for allowable altfield names.
;
; bb_relative   - If set, then organize data by distance above/below mean bright
;                 band height rather than by height above the surface
;
; do_stddev     - If set, then compute standard deviation of PR and GR field
;                 values in place of Maximum value
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
; first_orbit   - Optional parameter to define the first orbit to be processed
;
; scatterplot   - Optional binary parameter.  If set, then a scatter plot of the
;                 PR/DPR vs. GR reflectivity will be created and displayed as an
;                 IDL IMAGE object.
;
; plot_obj_array - Optional parameter.  If the caller defines a variable (any
;                  type/value) and supplies it to this routine as the parameter,
;                  then it will be redefined as an array of references to IDL
;                  PLOT objects that refer to the optional profile and scatter
;                  plots, but only if the user selects not to have them closed
;                  before this procedure exits.  Only the "top level" PLOT and
;                  IMAGE object references are included, not those of the
;                  overplots, legends, colorbars, etc.
;
; VERSION2MATCH  - Optional parameter.  Specifies one or more different PPS
;                  version(s) for which the current matchup file must have at
;                  least one corresponding matchup file of these data versions
;                  for the given site and orbit.  That is, if the file for this
;                  site and orbit and PPS version does not exist in at least one
;                  of the versions specified by VERSION2MATCH, then the current
;                  file is excluded in processing the statistics.
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
;
; ------------------------------------------------------------------------------
;
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
;
; ------------------------------------------------------------------------------
;
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
;    value of INSTRUMENT (SAT=GPM for DPR, SAT=TRMM for PR).
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
; 04/26/16 by Bob Morris, GPM GV (SAIC)
;  - Added ability to process DSD (Dm, Nw) statistics for DPRGMI matchups.
; 07/12/16 by Bob Morris, GPM GV (SAIC)
;  - Changed the version matching logic to ignore the NC_NAME_ADD part of the
;    filenames and just match on the site, event, and version fields.
; 07/18/16 by Bob Morris, GPM GV (SAIC)
;  - Added ability to plot Nw/N2 scatter.  Added NW_SCALE parameter definition
;    to handle different Nw units between 2ADPR/Ka/Ku and 2BDPRGMI.
;
; ------------------------------------------------------------------------------
;
; 07/19/16 by Bob Morris, GPM GV (SAIC)
;  - Created from stats_z_rain_dsd_to_db_profile_scatter, eliminating the file
;    output for the database and just producing the scatter plots and profiles.
;
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;===============================================================================


        PRO z_rain_dsd_profile_scatter, INSTRUMENT=instrument,         $
                                              KUKA=KuKa, SCANTYPE=swath,     $
                                              PCT_ABV_THRESH=pctAbvThresh,   $
                                              GV_CONVECTIVE=gv_convective,   $
                                              GV_STRATIFORM=gv_stratiform,   $
                                              S2KU=s2ku,                     $
                                              Z_MEAS=z_meas,                 $
                                              NAME_ADD=name_add,             $
                                              NCSITEPATH=ncsitepath,         $
                                              FILEPATTERN=filepattern,       $
                                              SITELIST=sitelist,             $
                                              EXCLUDE=exclude,               $
                                              OUTPATH=outpath,               $
                                              ALTFIELD=altfield,             $
                                              BB_RELATIVE=bb_relative,       $
;                                              DO_STDDEV=do_stddev,           $
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
                                              CONVBELOWSCAT=convbelowscat

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
       'ZC' : z2do = 'Zc'
       'D0' : z2do = 'D0'
       'DM' : z2do = 'Dm'
       'NW' : z2do = 'Nw'
       'N2' : z2do = 'N2'
       'RR' : z2do = 'RR'
       'RC' : z2do = 'RC'
       'RP' : z2do = 'RP'
     'ZCNWG': z2do = 'ZcNwG'
     'DMNWG': z2do = 'DmNwG'
     'ZCNWP': z2do = 'ZcNwP'
     'DMNWP': z2do = 'DmNwP'
       ELSE : message, "Invalid ALTFIELD value, must be one of: " + $
                       "ZC, ZM, D0, DM, NW, N2, RR, RC, RP, ZCNW, DMNW"
   ENDCASE
ENDIF ELSE z2do = 'zcor'

IF z2do EQ 'Zm' THEN use_zraw = 1 ELSE use_zraw = 0
;use_zraw = KEYWORD_SET(z_meas)

IF KEYWORD_SET(scatterplot) THEN BEGIN
   do_scatr=1
   zHist_ptr = ptr_new(/allocate_heap)
   biasAccum = 0.0D    ; to accumulate event-weighted bias
   nbiasAccum = 0L     ; to accumulate event weights (# samples)
ENDIF ELSE do_scatr=0
have2dhist = 0
have1dhist = 0

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
               IF (z2do EQ 'Zm' AND use_zraw EQ 1) THEN BEGIN
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
ptr_bbProx=ptr_new(/allocate_heap)
ptr_hgtcat=ptr_new(/allocate_heap)
ptr_dist=ptr_new(/allocate_heap)
ptr_pctgoodpr=ptr_new(/allocate_heap)
ptr_pctgoodgv=ptr_new(/allocate_heap)
ptr_pctgoodrain=ptr_new(/allocate_heap)

; allocate pointers for alternate fields, as needed
GRlabelAdd = ''
;CASE z2do OF
;    'D0' : BEGIN
              ptr_GR_DP_Dzero=ptr_new(/allocate_heap)
;              ptr_GR_DP_Dzeromax=ptr_new(/allocate_heap)
;              ptr_GR_DP_Dzerostddev=ptr_new(/allocate_heap)
              ptr_DprDm=ptr_new(/allocate_heap)
              ptr_pctgooddzerogv=ptr_new(/allocate_heap)
              ptr_pctgoodDprDm=ptr_new(/allocate_heap)
              IF z2do EQ 'D0' THEN GRlabelAdd = '*1.05'
;           END
;    'Dm' : BEGIN
              ptr_GR_DP_Dm=ptr_new(/allocate_heap)
;              ptr_GR_DP_Dmmax=ptr_new(/allocate_heap)
;              ptr_GR_DP_Dmstddev=ptr_new(/allocate_heap)
              ptr_DprDm=ptr_new(/allocate_heap)
              ptr_pctgooddmgv=ptr_new(/allocate_heap)
              ptr_pctgoodDprDm=ptr_new(/allocate_heap)
;           END
;    'Nw' : BEGIN
              ptr_GR_DP_Nw=ptr_new(/allocate_heap)
;              ptr_GR_DP_Nwmax=ptr_new(/allocate_heap)
;              ptr_GR_DP_Nwstddev=ptr_new(/allocate_heap)
              ptr_DprNw=ptr_new(/allocate_heap)
              ptr_pctgoodnwgv=ptr_new(/allocate_heap)
              ptr_pctgoodDprNw =ptr_new(/allocate_heap)
;           END
;    'N2' : BEGIN
              ptr_GR_DP_N2=ptr_new(/allocate_heap)
;              ptr_GR_DP_N2max=ptr_new(/allocate_heap)
;              ptr_GR_DP_N2stddev=ptr_new(/allocate_heap)
              ptr_DprNw=ptr_new(/allocate_heap)
              ptr_pctgoodn2gv=ptr_new(/allocate_heap)
              ptr_pctgoodDprNw =ptr_new(/allocate_heap)
;           END
;    'RR' : BEGIN
              ptr_gvrr=ptr_new(/allocate_heap)
;              ptr_gvrrmax=ptr_new(/allocate_heap)
;              ptr_gvrrstddev=ptr_new(/allocate_heap)
              ptr_pctgoodrrgv=ptr_new(/allocate_heap)
;           END
;    'RC' : BEGIN
              ptr_gvrc=ptr_new(/allocate_heap)
;              ptr_gvrcmax=ptr_new(/allocate_heap)
;              ptr_gvrcstddev=ptr_new(/allocate_heap)
              ptr_pctgoodrcgv=ptr_new(/allocate_heap)
;           END
;    'RP' : BEGIN
              ptr_gvrp=ptr_new(/allocate_heap)
;              ptr_gvrpmax=ptr_new(/allocate_heap)
;              ptr_gvrpstddev=ptr_new(/allocate_heap)
              ptr_pctgoodrpgv=ptr_new(/allocate_heap)
;           END
;    ELSE : BREAK
;ENDCASE

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
       PTRzcor=ptr_zcor, PTRzraw=ptr_zraw, PTRrain3d=ptr_rain3, $
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
       PTRzcor=ptr_zcor, PTRzraw=ptr_zraw, PTRrain3d=ptr_rain3, $
       PTRdprdm=ptr_dprDm, PTRdprnw=ptr_dprNw, $
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
       PTRGVBLOCKAGE=ptr_GR_blockage, $
       PTRsfcrainpr=ptr_nearSurfRain, PTRsfcraincomb=ptr_nearSurfRain_2b31, $
       PTRrainflag_int=ptr_rnFlag, PTRraintype_int=ptr_rnType, PTRbbProx=ptr_bbProx, $
       PTRhgtcat=ptr_hgtcat, PTRdist=ptr_dist,  $
       PTRpctgoodpr=ptr_pctgoodpr, PTRpctgoodrain=ptr_pctgoodrain, $
       PTRpctgood250pr=ptr_pctgood250pr, PTRpctgood250rawpr=ptr_pctgood250rawpr, $
       PTRpctgoodDprDm=ptr_pctgoodDprDm, PTRpctgoodDprNw=ptr_pctgoodDprNw, $
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
       PTRzcor=ptr_zcor, PTRrain3d=ptr_rain3, $
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
   nearSurfRain=temporary(*ptr_nearSurfRain)
   nearSurfRain_2b31=temporary(*ptr_nearSurfRain_2b31)
;   rnflag=temporary(*ptr_rnFlag)
   rntype=temporary(*ptr_rnType)
   bbProx=temporary(*ptr_bbProx)
   hgtcat=temporary(*ptr_hgtcat)
   dist=temporary(*ptr_dist)
   pctgoodpr=temporary(*ptr_pctgoodpr)
   pctgoodgv=temporary(*ptr_pctgoodgv)

; dereference pointers for fields into common-named variables
have_altfield=1   ; initialize as if we have an alternate field to process
;    ELSE : have_altfield=0   ; only doing boring old Z

IF have_SAT_DSD EQ 1 THEN BEGIN
              DPR_Dm=temporary(*ptr_DprDm)
              pctgoodDPR_Dm=temporary(*ptr_pctgoodDprDm)
              DPR_Nw=temporary(*ptr_DprNw/NW_SCALE)      ; dBNw -> log10(Nw)
              pctgoodDPR_NW=temporary(*ptr_pctgoodDprNw )
ENDIF

IF myflags.have_GR_Dzero EQ 1 and have_SAT_DSD EQ 1 THEN BEGIN
              have_D0 = 1
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
              GR_Dm=temporary(*ptr_GR_DP_Dm)
;              GR_Dmmax=temporary(*ptr_GR_DP_Dmmax)
;              GR_Dmstddev=temporary(*ptr_GR_DP_Dmstddev)
              pctgoodGR_Dm=temporary(*ptr_pctgooddmgv)
ENDIF ELSE have_Dm = 0

IF myflags.have_GR_Nw EQ 1 and have_SAT_DSD EQ 1 THEN BEGIN
              have_Nw = 1
              GR_Nw=temporary(*ptr_GR_DP_Nw)
;              GR_Nwmax=temporary(*ptr_GR_DP_Nwmax)
;              GR_Nwstddev=temporary(*ptr_GR_DP_Nwstddev)
              pctgoodGR_Nw=temporary(*ptr_pctgoodnwgv)
ENDIF ELSE have_Nw = 0

IF myflags.have_GR_N2 EQ 1 and have_SAT_DSD EQ 1 THEN BEGIN
              have_N2 = 1
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
              GR_RR=temporary(*ptr_gvrr)
;              GR_RRmax=temporary(*ptr_gvrrmax)
;              GR_RRstddev=temporary(*ptr_gvrrstddev)
              pctgoodGR_RR=temporary(*ptr_pctgoodrrgv)
ENDIF ELSE have_RR = 0

IF myflags.have_GR_RC_rainrate EQ 1 THEN BEGIN
              have_RC = 1
              GR_RC=temporary(*ptr_gvrc)
;              GR_RCmax=temporary(*ptr_gvrcmax)
;              GR_RCstddev=temporary(*ptr_gvrcstddev)
              DPR_RC=DPR_RR
              pctgoodGR_RC=temporary(*ptr_pctgoodrcgv)
              pctgoodDPR_RC=pctgoodDPR_RR
ENDIF ELSE have_RC = 0

IF myflags.have_GR_RP_rainrate EQ 1 THEN BEGIN
              have_RP = 1
              GR_RP=temporary(*ptr_gvrp)
;              GR_RPmax=temporary(*ptr_gvrpmax)
;              GR_RPstddev=temporary(*ptr_gvrpstddev)
              DPR_RP=DPR_RR
              pctgoodGR_RP=temporary(*ptr_pctgoodrpgv)
              pctgoodDPR_RP=pctgoodDPR_RR
ENDIF ELSE have_RP = 0


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

   IF ( do_GR_blockage ) THEN BEGIN
      print, 'also clipping by blockages'
     ; define an array that flags samples that exceed the max blockage threshold
      unblocked = pctgoodpr < pctgoodgv
      idxBlocked = WHERE( GR_blockage GT max_blockage, countblock)
     ; set blocked sample to a negative value to exclude them in clipping
      IF countblock GT 0 THEN unblocked[idxBlocked] = -66.6
      IF ( pctAbvThreshF GT 0.0 ) THEN BEGIN
          ; clip to the 'good' points, where 'pctAbvThreshF' fraction of bins in average
          ; were above threshold AND blockage is below max allowed
         idxgoodenuff = WHERE( minpctcombined GE pctAbvThreshF $
                          AND  unblocked GT 0.0, countgoodpct )
      ENDIF ELSE BEGIN
         idxgoodenuff = WHERE( minpctcombined GT 0.0 $
                          AND  unblocked GT 0.0, countgoodpct )
      ENDELSE
   ENDIF ELSE BEGIN
      IF ( pctAbvThreshF GT 0.0 ) THEN BEGIN
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
          gvzmax = gvzmax[idxgoodenuff]
          gvzstddev = gvzstddev[idxgoodenuff]
;          rnFlag = rnFlag[idxgoodenuff]
          rnType = rnType[idxgoodenuff]
          dist = dist[idxgoodenuff]
          bbProx = bbProx[idxgoodenuff]
          hgtcat = hgtcat[idxgoodenuff]
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
      ENDIF ELSE BEGIN
          print, "No complete-volume points, quitting case."
          goto, nextFile
      ENDELSE

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

        ; Compute stratified dBZ statistics at this level
;         this_statsbydist = {stats21ways}
;         stratify_diffs21dist_geo2, dbzDPRlev, dbznexlev, raintypelev, $
;                                    BBproxlev, distcatlev, gvzmaxlev, $
;                                    gvzstddevlev, this_statsbydist, $
;                                    DO_STDDEV=do_stddev

         IF N_ELEMENTS(profile_save) NE 0 THEN $
            ; accumulate PR and GR dBZ histograms by rain type at this level
            accum_histograms_by_raintype, dbzDPRlev, dbznexlev, raintypelev, $
                                          accum_ptrs, lev2get, bindbz
      ENDIF
   endfor

  ;# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

   IF do_scatr EQ 1 THEN BEGIN
     ; set up the indices of the samples to include in the scatter plots
      SWITCH z2do OF
       'D0' : 
       'Dm' : 
       'N2' :
       'Nw' : 
    'ZcNwG' :
    'DmNwG' :
    'ZcNwP' :
    'DmNwP' :
       'RC' : 
       'RP' : 
       'RR' : BEGIN
                ; accumulate 2-D histogram of stratiform, below-BB Dm/D0/Nw/N2/Rx
                ; at/below 3 km, unless 'convbelowscat' is set, then do convective
                ; below BB
                 IF KEYWORD_SET(convbelowscat) THEN BEGIN
                    idxabv = WHERE( BBprox EQ 0 AND rntype EQ RainType_convective $
                                    AND hgtcat LE 1, countabv )
                 ENDIF ELSE BEGIN
                    idxabv = WHERE( BBprox EQ 0 AND rntype EQ RainType_stratiform $
                                    AND hgtcat LE 1, countabv )
                 ENDELSE
                 BREAK
              END
       ELSE : BEGIN
                ; accumulate 2-D histogram of stratiform, above-BB reflectivity,
                ; unless 'convbelowscat' is set, then do convective below BB
                 IF KEYWORD_SET(convbelowscat) THEN BEGIN
                    idxabv = WHERE( BBprox EQ 0 AND rntype EQ RainType_convective, countabv )
                 ENDIF ELSE BEGIN
                    idxabv = WHERE( BBprox EQ 2 AND rntype EQ RainType_stratiform, countabv )
                 ENDELSE
              END
      ENDSWITCH

     ; extract the samples to include in the scatter plots, if variable is
     ; available and there are qualifying points from above
      CASE z2do OF
       'D0' : BEGIN
                 IF countabv GT 0 AND have_D0 THEN BEGIN
                    scat_X = GR_D0[idxabv]
                    scat_Y = DPR_D0[idxabv]
                 ENDIF ELSE countabv=0
                 binmin1 = 0.0 & binmax1 = 4.0 & BINSPAN1 = 0.1
                 binmin2 = 0.0 & binmax2 = 4.0 & BINSPAN2 = 0.1
              END
       'Dm' : BEGIN
                 IF countabv GT 0 AND have_Dm THEN BEGIN
                    scat_X = GR_Dm[idxabv]
                    scat_Y = DPR_Dm[idxabv]
                 ENDIF ELSE countabv=0
                 binmin1 = 0.0 & binmax1 = 4.0 & BINSPAN1 = 0.1
                 binmin2 = 0.0 & binmax2 = 4.0 & BINSPAN2 = 0.1
              END
       'N2' : BEGIN
                 IF countabv GT 0 AND have_N2 THEN BEGIN
                    scat_X = GR_N2[idxabv]
                    scat_Y = DPR_N2[idxabv]
                 ENDIF ELSE countabv=0
                 binmin1 = 2.0 & binmax1 = 6.0 & BINSPAN1 = 0.1
                 binmin2 = 2.0 & binmax2 = 6.0 & BINSPAN2 = 0.1
              END
       'Nw' : BEGIN
                 IF countabv GT 0 AND have_Nw THEN BEGIN
                    scat_X = GR_Nw[idxabv]
                    scat_Y = DPR_Nw[idxabv]
                 ENDIF ELSE countabv=0
                 binmin1 = 2.0 & binmax1 = 6.0 & BINSPAN1 = 0.1
                 binmin2 = 2.0 & binmax2 = 6.0 & BINSPAN2 = 0.1
              END
       'RC' : BEGIN
                 print, "RC not configured"
                 countabv=0
              END
       'RP' : BEGIN
                 print, "RP not configured"
                 countabv=0
             END
       'RR' : BEGIN
                 IF countabv GT 0 AND have_Nw THEN BEGIN
                    scat_X = GR_RR[idxabv]
                    scat_Y = DPR_RR[idxabv]
                 ENDIF ELSE countabv=0
                 IF KEYWORD_SET(convbelowscat) THEN BEGIN
                    binmin1 = 0.0  & binmin2 = 0.0
                    binmax1 = 75.0 & binmax2 = 75.0
                 ENDIF ELSE BEGIN
                    binmin1 = 0.0  & binmin2 = 0.0
                    binmax1 = 15.0 & binmax2 = 15.0
                 ENDELSE
                 IF N_ELEMENTS(bins4scat) EQ 1 THEN BEGIN
                    BINSPAN1 = bins4scat
                    BINSPAN2 = bins4scat
                 ENDIF ELSE BEGIN
                    BINSPAN1 = 0.25
                    BINSPAN2 = 0.25
                 ENDELSE
              END
    'ZcNwP' : BEGIN
                ; accumulate 2-D histogram of reflectivity vs. Nw
                 IF KEYWORD_SET(convbelowscat) THEN BEGIN
                    binmin1 = 2.0 & binmin2 = 20.0
                    binmax1 = 6.0 & binmax2 = 60.0
                 ENDIF ELSE BEGIN
                    binmin1 = 2.0 & binmin2 = 15.0
                    binmax1 = 6.0 & binmax2 = 55.0
                 ENDELSE
                 BINSPAN1 = 0.1
                 BINSPAN2 = 1.0
                 IF countabv GT 0 AND have_Nw THEN BEGIN
                    ;scat_Y_GR = gvz[idxabv]
                    scat_Y = zcor[idxabv]
                    ;scat_X_GR = GR_Nw[idxabv]
                    scat_X = DPR_Nw[idxabv]
                 ENDIF ELSE countabv=0
              END
    'ZcNwG' : BEGIN
                ; accumulate 2-D histogram of reflectivity vs. Nw
                 IF KEYWORD_SET(convbelowscat) THEN BEGIN
                    binmin1 = 2.0 & binmin2 = 20.0
                    binmax1 = 6.0 & binmax2 = 60.0
                 ENDIF ELSE BEGIN
                    binmin1 = 2.0 & binmin2 = 15.0
                    binmax1 = 6.0 & binmax2 = 55.0
                 ENDELSE
                 BINSPAN1 = 0.1
                 BINSPAN2 = 1.0
                 IF countabv GT 0 AND have_Nw THEN BEGIN
                    scat_Y = gvz[idxabv]
                    ;scat_Y_DPR = zcor[idxabv]
                    scat_X = GR_Nw[idxabv]
                    ;scat_X_DPR = DPR_Nw[idxabv]
                 ENDIF ELSE countabv=0
              END
    'DmNwP' : BEGIN
                ; accumulate 2-D histogram of Dm vs. Nw
                 binmin1 = 2.0 & binmin2 = 0.0
                 binmax1 = 6.0 & binmax2 = 4.0
                 BINSPAN1 = 0.1 & BINSPAN2 = 0.1
                 IF countabv GT 0 AND have_Nw AND have_Dm THEN BEGIN
                    ;scat_Y_GR = GR_Dm[idxabv]
                    scat_Y = DPR_Dm[idxabv]
                    ;scat_X_GR = GR_Nw[idxabv]
                    scat_X = DPR_Nw[idxabv]
                 ENDIF ELSE countabv=0
              END
    'DmNwG' : BEGIN
                ; accumulate 2-D histogram of Dm vs. Nw
                 binmin1 = 2.0 & binmin2 = 0.0
                 binmax1 = 6.0 & binmax2 = 4.0
                 BINSPAN1 = 0.1 & BINSPAN2 = 0.1
                 IF countabv GT 0 AND have_Nw AND have_Dm THEN BEGIN
                    scat_Y = GR_Dm[idxabv]
                    ;scat_Y_DPR = DPR_Dm[idxabv]
                    scat_X = GR_Nw[idxabv]
                    ;scat_X_DPR = DPR_Nw[idxabv]
                 ENDIF ELSE countabv=0
              END
       ELSE : BEGIN
                ; accumulate 2-D histogram of reflectivity
                 IF KEYWORD_SET(convbelowscat) THEN BEGIN
                    binmin1 = 20.0 & binmin2 = 20.0
                    binmax1 = 50.0 & binmax2 = 50.0
                 ENDIF ELSE BEGIN
                    binmin1 = 15.0 & binmin2 = 15.0
                    binmax1 = 45.0 & binmax2 = 45.0
                 ENDELSE
                ; IF N_ELEMENTS(bins4scat) EQ 1 THEN BEGIN
                ;    BINSPAN1 = bins4scat
                ;;   BINSPAN2 = bins4scat
                ; ENDIF ELSE BEGIN
                    BINSPAN1 = 0.1
                    BINSPAN2 = 2.0
                ; ENDELSE
                 IF countabv GT 0 THEN BEGIN
                    scat_X = gvz[idxabv]
                    IF (use_zraw) THEN BEGIN
                       scat_Y = zraw[idxabv]
                       DPRtxt = ' Zmeas '
                    ENDIF ELSE BEGIN
                       scat_Y = zcor[idxabv]
                       DPRtxt = ' Zcor '
                    ENDELSE
                 ENDIF
              END
      ENDCASE

      IF countabv GT 0 THEN BEGIN
         PRINT, '******************************************************'
         print, countabv, ' QUALIFYING '+z2do+' SAMPLES FOR HISTOGRAM.'
         PRINT, '******************************************************'
         IF have2dhist THEN BEGIN
            zhist2d = zhist2d + HIST_2D( scat_X, scat_Y, MIN1=binmin1, $
                                         MIN2=binmin2, MAX1=binmax1, MAX2=binmax2, $
                                         BIN1=BINSPAN1, BIN2=BINSPAN2 )
            minprz = MIN(scat_Y) < minprz
         ENDIF ELSE BEGIN
            zhist2d = HIST_2D( scat_X, scat_Y, MIN1=binmin1, $
                               MIN2=binmin2, MAX1=binmax1, MAX2=binmax2, $
                               BIN1=BINSPAN1, BIN2=BINSPAN2 )
            minprz = MIN(scat_Y)
            have2dhist = 1
         ENDELSE
        ; compute the mean GR Z for the samples in each DPR histogram bin
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
;         print, "locations, gvzmeanByBin, przmeanByBin: ", Zstarts, gvzmeanByBin, przmeanByBin
         IF have1dhist THEN BEGIN
            gvzmeanaccum = gvzmeanaccum + gvzmeanByBin*nbybin
            przmeanaccum = przmeanaccum + przmeanByBin*nbybin
            MAEaccum = MAEaccum + MAEbyBin*nbybin
            nbybinaccum = nbybinaccum + nbybin
         ENDIF ELSE BEGIN
            gvzmeanaccum = gvzmeanByBin*nbybin
            przmeanaccum = przmeanByBin*nbybin
            MAEaccum = MAEbyBin*nbybin
            nbybinaccum = nbybin
            have1dhist = 1
         ENDELSE
      ENDIF ELSE BEGIN
         PRINT, '******************************************************'
         print, 'NO QUALIFYING '+z2do+' SAMPLES FOR HISTOGRAM.'
         PRINT, '******************************************************'
      ENDELSE
   ENDIF

  ;# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

   nextFile:
   lastorbitnum=orbitnum
   lastncfile=bname
   lastsite=site

ENDFOR    ; end of loop over fnum = 0, nf-1

IF have2dhist EQ 1 THEN BEGIN
  ; CREATE THE SCATTER PLOT OBJECT FROM THE BINNED DATA
   do_MAE_1_1 = 1    ; flag to include/suppress MAE and the 1:1 line on plots
   IF N_ELEMENTS(swath) EQ 1 THEN prodStr=pr_or_dpr+'/'+swath ELSE prodStr=pr_or_dpr
   SWITCH z2do OF
    'D0' : 
    'Dm' : BEGIN
              IF KEYWORD_SET(convbelowscat) THEN BEGIN
                 SCAT_DATA = "Convective Samples, Below Bright Band and <= 3 km AGL"
                 ticknames=['0.0','0.5','1.0','1.5','2.0','2.5','3.0','3.5','4.0']
              ENDIF ELSE BEGIN
                 SCAT_DATA = "Stratiform Samples, Below Bright Band and <= 3 km AGL"
                 ticknames=['0.0','0.5','1.0','1.5','2.0','2.5','3.0','3.5','4.0']
              ENDELSE
              ;BINSPAN = 0.1
              xmajor=N_ELEMENTS(ticknames) & ymajor=xmajor
              titleLine1 = prodStr+' '+version+" Dm vs. GR "+z2do+" Scatter, Mean GR-DPR Bias: "
              units='mm'
              xtitle= 'GR '+z2do+GRlabelAdd+' ('+units+')'
              ytitle= pr_or_dpr + ' Dm ('+units+')'
              BREAK
           END
    'N2' :
    'Nw' : BEGIN
              IF KEYWORD_SET(convbelowscat) THEN BEGIN
                 SCAT_DATA = "Convective Samples, Below Bright Band and <= 3 km AGL"
                 ticknames=['2.0','2.5','3.0','3.5','4.0','4.5','5.0','5.5','6.0']
              ENDIF ELSE BEGIN
                 SCAT_DATA = "Stratiform Samples, Below Bright Band and <= 3 km AGL"
                 ticknames=['2.0','2.5','3.0','3.5','4.0','4.5','5.0','5.5','6.0']
              ENDELSE
              ;BINSPAN = 0.1
              xmajor=N_ELEMENTS(ticknames) & ymajor=xmajor
              titleLine1 = prodStr+' '+version+" Nw vs. GR "+z2do+" Scatter, Mean GR-DPR Bias: "
              units='log(Nw)'
              xtitle= 'GR '+units
              ytitle= pr_or_dpr +' '+ units
              BREAK
           END
 'ZcNwP' : BEGIN
              do_MAE_1_1 = 0
              IF KEYWORD_SET(convbelowscat) THEN BEGIN
                 SCAT_DATA = "Convective Samples, Below Bright Band and <= 3 km AGL"
                 yticknames=['20','25','30','35','40','45','50','55','60']
              ENDIF ELSE BEGIN
                 SCAT_DATA = "Stratiform Samples, Below Bright Band and <= 3 km AGL"
                 yticknames=['15','20','25','30','35','40','45','50','55']
              ENDELSE
              xticknames=['2.0','2.5','3.0','3.5','4.0','4.5','5.0','5.5','6.0']
              xmajor=N_ELEMENTS(xticknames) & ymajor=N_ELEMENTS(yticknames)
              titleLine1 = prodStr+' '+version+" Zc vs. Nw Scatter"
              xunits='log(Nw)'
              yunits='dBZ'
              xtitle= pr_or_dpr +' '+ xunits
              ytitle= pr_or_dpr + ' Zc (' + yunits + ')'
              BREAK
           END
 'ZcNwG' : BEGIN
              do_MAE_1_1 = 0
              IF KEYWORD_SET(convbelowscat) THEN BEGIN
                 SCAT_DATA = "Convective Samples, Below Bright Band and <= 3 km AGL"
                 yticknames=['20','25','30','35','40','45','50','55','60']
              ENDIF ELSE BEGIN
                 SCAT_DATA = "Stratiform Samples, Below Bright Band and <= 3 km AGL"
                 yticknames=['15','20','25','30','35','40','45','50','55']
              ENDELSE
              xticknames=['2.0','2.5','3.0','3.5','4.0','4.5','5.0','5.5','6.0']
              xmajor=N_ELEMENTS(xticknames) & ymajor=N_ELEMENTS(yticknames)
              titleLine1 = "GR Zc vs. Nw Scatter for " + pr_or_dpr+' '+version
              xunits='log(Nw)'
              yunits='dBZ'
              xtitle= 'GR '+ xunits
              ytitle= 'GR Zc (' + yunits + ')'
              BREAK
              END
 'DmNwP' : BEGIN
              do_MAE_1_1 = 0
              IF KEYWORD_SET(convbelowscat) THEN $
                 SCAT_DATA = "Convective Samples, Below Bright Band and <= 3 km AGL" $
              ELSE SCAT_DATA = "Stratiform Samples, Below Bright Band and <= 3 km AGL"
              xticknames=['2.0','2.5','3.0','3.5','4.0','4.5','5.0','5.5','6.0']
              yticknames=['0.0','0.5','1.0','1.5','2.0','2.5','3.0','3.5','4.0']
              xmajor=N_ELEMENTS(xticknames) & ymajor=N_ELEMENTS(yticknames)
              titleLine1 = prodStr+' '+version+" Dm vs. Nw Scatter"
              xunits='log(Nw)'
              yunits='mm'
              xtitle= pr_or_dpr +' '+ xunits
              ytitle= pr_or_dpr + ' Dm (' + yunits + ')'
              BREAK
           END
 'DmNwG' : BEGIN
              do_MAE_1_1 = 0
              IF KEYWORD_SET(convbelowscat) THEN $
                 SCAT_DATA = "Convective Samples, Below Bright Band and <= 3 km AGL" $
              ELSE SCAT_DATA = "Stratiform Samples, Below Bright Band and <= 3 km AGL"
              xticknames=['2.0','2.5','3.0','3.5','4.0','4.5','5.0','5.5','6.0']
              yticknames=['0.0','0.5','1.0','1.5','2.0','2.5','3.0','3.5','4.0']
              xmajor=N_ELEMENTS(xticknames) & ymajor=N_ELEMENTS(yticknames)
              titleLine1 = "GR Dm vs. Nw Scatter"
              xunits='log(Nw)'
              yunits='mm'
              xtitle= 'GR '+ xunits
              ytitle= 'GR Dm ('+yunits+')'
              BREAK
           END
    'RC' : BREAK
    'RP' : BREAK
    'RR' : BEGIN
              IF KEYWORD_SET(convbelowscat) THEN BEGIN
                 SCAT_DATA = "Convective Samples, Below Bright Band and <= 3 km AGL"
                 ticknames=STRING(INDGEN(11)*7.5, FORMAT='(F0.1)')
              ENDIF ELSE BEGIN
                 SCAT_DATA = "Stratiform Samples, Below Bright Band and <= 3 km AGL"
                 ticknames=STRING(INDGEN(16), FORMAT='(I0)')
              ENDELSE
              ;BINSPAN = 0.1
              xmajor=N_ELEMENTS(ticknames) & ymajor=xmajor
              titleLine1 = prodStr+' '+version+" RR vs. GR "+z2do+" Scatter, Mean GR-DPR Bias: "
              units='(mm/h)'
              xtitle= 'GR '+units
              ytitle= pr_or_dpr +' '+ units
              BREAK
           END
    ELSE : BEGIN
              IF KEYWORD_SET(convbelowscat) THEN BEGIN
                 SCAT_DATA = "Convective Samples, Below Bright Band"
                 ticknames=['20','25','30','35','40','45','50']
              ENDIF ELSE BEGIN
                 SCAT_DATA = "Stratiform Samples, Above Bright Band"
                 ticknames=['15','20','25','30','35','40','45']
              ENDELSE
              ;IF N_ELEMENTS(bins4scat) EQ 1 THEN BINSPAN = bins4scat ELSE BINSPAN = 2.0
              xmajor=N_ELEMENTS(ticknames) & ymajor=xmajor
              titleLine1 = prodStr+' '+version+DPRtxt+" vs. GR Z Scatter, Mean GR-DPR Bias: "
              IF ( s2ku ) THEN xtitleadd = ', Ku-adjusted' ELSE xtitleadd = ''
              units='dBZ'
              xtitle= 'GR Reflectivity ('+units+')' + xtitleadd
              ytitle= pr_or_dpr + ' Reflectivity ('+units+')'
           END
      ENDSWITCH

   PRINT, '' & PRINT, "Min PR Z: ", minprz & PRINT, ''
   PRINT, ''
   PRINT, "locations: ", Zstarts+BINSPAN2/2
   PRINT, "gvzmeanByBin: ", gvzmeanaccum/nbybinaccum
   PRINT, "przmeanByBin: ", przmeanaccum/nbybinaccum
   PRINT, ''
   idxzdef = WHERE(gvzmeanaccum GE 0.0 and przmeanaccum GE 0.0)
   nSamp = TOTAL(nbybinaccum[idxzdef])
   n_str = ", N="+STRING(nSamp, FORMAT='(I0)')
   gvzmean = TOTAL(gvzmeanaccum[idxzdef])/nSamp
   przmean = TOTAL(przmeanaccum[idxzdef])/nSamp
   MAE = TOTAL(MAEaccum[idxzdef])/nSamp
   biasgrpr = gvzmean-przmean
   bias_str = STRING(biasgrpr, FORMAT='(F0.1)')
   MAE_str = STRING(MAE, FORMAT='(F0.1)')

   print, ''
   IF do_MAE_1_1 THEN print, "MAE, bias: ", MAE_str+"  "+bias_str
   print, ''

   sh = SIZE(zhist2d, /DIMENSIONS)
  ; last bin in 2-d histogram only contains values = MAX, cut these
  ; out of the array
   zhist2d = zhist2d[0:sh[0]-2,0:sh[1]-2]

  ; convert counts to percent of total if show_pct is set
   show_pct=1
   IF KEYWORD_SET(show_pct) THEN BEGIN
     ; convert counts to percent of total
      zhist2d = (zhist2d/DOUBLE(nSamp))*100.0D
     ; set values below 5% to 0%
      histLE5 = WHERE(zhist2d LT 5.0, countLT5)
;      IF countLT5 GT 0 THEN zhist2d[histLE5] = 0.0D
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
   IF MAX(sh) LT 125 THEN BEGIN
      scale = 150/MAX(sh) + 1
      sh2 = sh*scale
      histImg = REBIN(histImg, sh2[0], sh2[1], /SAMPLE)
   ENDIF
   winsiz = SIZE( histImg, /DIMENSIONS )
   histImg = CONGRID(histImg, winsiz[0]*4, winsiz[1]*4)
   winsiz = SIZE( histImg, /DIMENSIONS )
print, 'winsiz: ', winsiz
   rgb=COLORTABLE(33)
   rgb[0,*]=255   ; set zero count color to White background
   IF do_MAE_1_1 THEN BEGIN
            imTITLE = titleLine1+bias_str+" "+units+n_str+"!C"+SCAT_DATA+", "+ $
            pctabvstr+" Above Thresh."
   ENDIF ELSE BEGIN
            imTITLE = titleLine1+n_str+"!C"+SCAT_DATA+", "+ $
            pctabvstr+" Above Thresh."
   ENDELSE
   im=image(histImg, axis_style=2, xmajor=xmajor, ymajor=ymajor, $
            xminor=4, yminor=4, RGB_TABLE=rgb, $
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
               /DATA,/FILL_Background,FILL_COLOR='white',TRANSP=25)
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
   cbar=colorbar(target=im, ori=1, pos=[0.95, 0.2, 0.98, 0.75], $
                 TICKVALUES=ticlocs, TICKNAME=ticnms, TITLE=ticID)

  ; overplot the mean DPR and GR bin-range values, and label by count
  ; if the binsize is sufficently large
   plotscale=winsiz[0]/(binmax2-binmin2)    ; pixels per dBZ, noting that the origin is at (15.,15.)
;   bplot = PLOT((gvzmeanaccum/nbybinaccum-binmin2)*plotscale < (winsiz[0]-1), $
;                (przmeanaccum/nbybinaccum-binmin2)*plotscale, '-r4+', /OVERPLOT)
   IF (binmax2-binmin2)/BINSPAN2 LE 20.0 THEN BEGIN
     ; overplot the sample counts
      idxzdef = WHERE(gvzmeanaccum GE 0.0 and przmeanaccum GE 0.0)
      xtxt=(gvzmeanaccum[idxzdef]/nbybinaccum[idxzdef]-binmin2)*plotscale
      ytxt=(przmeanaccum[idxzdef]/nbybinaccum[idxzdef]-binmin2)*plotscale
      txttxt=STRING(nbybinaccum[idxzdef],FORMAT='(I0)')
;      txtarr=TEXT(xtxt,ytxt,txttxt,/DATA,/FILL_Background,FILL_COLOR='white',TRANSP=25)
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
    plot_mean_profiles, savfile, FILE_BASENAME(savfile), INSTRUMENT=pr_or_dpr
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
*ptr_rain3=temporary(DPR_RR)
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


IF N_ELEMENTS(profile_save) NE 0 THEN BEGIN
   print, ''
   print, 'SAVE file status:'
   command = 'ls -al ' + savfile
   spawn, command
   print, ''
ENDIF

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

end
