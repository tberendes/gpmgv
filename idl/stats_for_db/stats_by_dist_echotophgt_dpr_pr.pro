;+
;  stats_by_dist_echotop_dpr_pr.pro
;    - Morris/SAIC/GPM_GV   July 2015
;
; DESCRIPTION
; -----------
; Reads PR (or DPR) and GV reflectivity (default) and spatial fields from
; PRtoDPR or DPRtoGR geo_match netCDF files, builds index arrays of categories
; of range, echo top, bright band proximity (above, below, within), and height
; (13 categories, 1.5-19.5 km levels); and an array of actual range.  Computes
; max and mean PR and GV reflectivity and mean (D)PR-GV reflectivity differences
; and standard deviation of the differences for each of the 13 height levels for
; points within 100 km of the ground radar.
;
; If an alternate field is specified in the ALTFIELD parameter, then this field
; will be read and its statistics will be computed in place of reflectivity.
; Possible ALTFIELD values are 'RR' (rain rate), 'D0' (mean drop diameter), and
; 'NW' (normalized intercept parameter).  If D0 or NW are specified, then
; results are computed only for the below-bright-band category.
;
; Statistical results are stratified by DPR Echo Top categories <3, 3-6, >6 km,
; and vertical location w.r.t the bright band (above, within, below), and in
; total for all eligible points, for a total of 7 permutations.  These 7
; permutations are further stratified by the points' distance from the radar in
; 3 categories: 0-49km, 50-99km, and (if present) 100-150km, for a grand total
; of 21 echotop/location/range categories.  The results and their identifying
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
; /data/netcdf/geo_match/*              INPUT: The set of site/orbit specific
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
; name_add      - String to be added to output filename to identify run results
;
; ncsitepath    - Directory for the set of netCDF files to be read and processed.
;                 If not provided, then a File Selector interface will be
;                 launched for the user to select the data directory.  All files
;                 in all subdirectories under the selected 'ncsitepath' that match
;                 the file pattern defined by 'filepattern' will be searched for.
;
; filepattern   - File basename pattern to be matched for those files to be
;                 included in the processing.  Default='GRtoXYZ.*', where XYZ
;                 is defined by the value of the INSTRUMENT parameter.
;
; sitelist      - Optional array of radar site IDs limiting the set of matchup
;                 files to be included in the processing.  Only matchup files
;                 for sites included in sitelist will be processed.
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
;                 variables will be saved as an IDL SAVE file.  Also will create
;                 and display the PR/DPR and GR profiles in an IDL PLOT object.
;
; alt_bb_file   - Optional file holding computed RUC BB heights for site/orbit
;                 combinations to be used in place of PR/DPR BB heights when the
;                 latter cannot be determined from the data in the matchup file.
;                 Current pathname, try /data/tmp/rain_event_nominal.YYMMDD.txt
;                 where YYMMDD is the latest date available.
;
; first_orbit   - Optional integer value, only matchup files with orbit numbers
;                 at/above this value will be included in the processing.
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
; CALLS
; -----
; stratify_diffs21dist_geo2   stratify_diffs_geo3    printf_stat_struct21dist3
; fprep_geo_match_profiles()   fprep_dpr_geo_match_profiles()
; accum_histograms_by_echotop   get_grouped_data_mean_stddev()
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
; 07-31-15 by Bob Morris, GPM GV (SAIC)
;  - Created from routine stats_by_dist_to_dbfile_dpr_pr_geo_match.pro, modified
;    here to instead do stats broken out by echo top height categories:
;    ET<3, 3<ET<6, ET>6 km.
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
;
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;===============================================================================


pro stats_by_dist_echotophgt_dpr_pr, INSTRUMENT=instrument,         $
                                     PCT_ABV_THRESH=pctAbvThresh,   $
                                     GV_CONVECTIVE=gv_convective,   $
                                     GV_STRATIFORM=gv_stratiform,   $
                                     S2KU=s2ku,                     $
                                     NAME_ADD=name_add,             $
                                     NCSITEPATH=ncsitepath,         $
                                     FILEPATTERN=filepattern,       $
                                     SITELIST=sitelist,             $
                                     OUTPATH=outpath,               $
                                     ALTFIELD=altfield,             $
                                     BB_RELATIVE=bb_relative,       $
                                     DO_STDDEV=do_stddev,           $
                                     PROFILE_SAVE=profile_save,     $
                                     ALT_BB_FILE=alt_bb_file,       $
                                     FIRST_ORBIT=first_orbit,       $
                                     SCATTERPLOT=scatterplot,       $
                                     PLOT_OBJ_ARRAY=plot_obj_array

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


IF KEYWORD_SET(scatterplot) THEN BEGIN
   do_scatr=1
   zHist_ptr = ptr_new(/allocate_heap)
ENDIF ELSE do_scatr=0
have2dhist = 0

IF ( N_ELEMENTS(instrument) NE 1 ) THEN BEGIN
   print, "Defaulting to DPR for instrument type."
   pr_or_dpr = 'DPR'
ENDIF ELSE BEGIN
   CASE STRUPCASE(instrument) OF
;      'PR' : pr_or_dpr = 'PR'
     'DPR' : BEGIN
               pr_or_dpr = 'DPR'
               SATDIR = 'GPM'
             END
;  'DPRGMI' : pr_or_dpr = 'DPRGMI'
      ELSE : message, "Only allowed value for INSTRUMENT: DPR"
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

IF N_ELEMENTS(name_add) EQ 1 THEN $
   addme = '_'+STRTRIM(STRING(name_add),2) $
ELSE addme = ''
IF keyword_set(bb_relative) THEN addme = addme+'_BBrel'
IF N_ELEMENTS(alt_bb_file) EQ 1 THEN addme = addme+'_AltBB'

IF KEYWORD_SET(do_stddev) THEN addme = '_StdDevMode' + addme

s2ku = KEYWORD_SET( s2ku )

IF N_ELEMENTS(outpath) NE 1 THEN BEGIN
   outpath='/data/tmp'
   PRINT, "Assigning default output file path: ", outpath
ENDIF

IF ( s2ku ) THEN dbfile = outpath+'/StatsByDist_'+pr_or_dpr+'_GR_Pct'+ $
                          strtrim(string(pctAbvThresh),2)+addme+'_S2Ku.unl' $
ELSE dbfile = outpath+'/StatsByDist_'+pr_or_dpr+'_GR_Pct'+ $
              strtrim(string(pctAbvThresh),2)+addme+'_DefaultS.unl'

PRINT, "Write output to: ", dbfile
OPENW, DBunit, dbfile, /GET_LUN

; Set up for the PR-GV rain type matching based on GV reflectivity

IF ( N_ELEMENTS(gv_Convective) NE 1 ) THEN BEGIN
   print, "Defaulting to 0.0 dBZ (Disabled) for GV Convective floor threshold."
   gvConvective = 0.0
ENDIF ELSE BEGIN
   gvConvective = FLOAT(gv_Convective)
ENDELSE

IF ( N_ELEMENTS(gv_Stratiform) NE 1 ) THEN BEGIN
   print, "Defaulting to 0.0 dBZ (Disabled) for GV Stratiform ceiling threshold."
   gvStratiform = 0.0
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

prfiles = file_search(pathpr, filepat, COUNT=nf)
IF (nf LE 0) THEN BEGIN
   print, "" 
   print, "No files found for pattern = ", pathpr
   print, " -- Exiting."
   GOTO, errorExit
ENDIF

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
ptr_top=ptr_new(/allocate_heap)
ptr_botm=ptr_new(/allocate_heap)
ptr_rnFlag=ptr_new(/allocate_heap)
ptr_rnType=ptr_new(/allocate_heap)
ptr_bbProx=ptr_new(/allocate_heap)
ptr_hgtcat=ptr_new(/allocate_heap)
ptr_dist=ptr_new(/allocate_heap)
ptr_pctgoodpr=ptr_new(/allocate_heap)
ptr_pctgoodgv=ptr_new(/allocate_heap)
ptr_pctgoodrain=ptr_new(/allocate_heap)
ptr_stmTopHgt=ptr_new(/allocate_heap)

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

; if minimum orbit number is specified, process newer orbits only
IF N_ELEMENTS(first_orbit) EQ 1 THEN BEGIN
   IF orbitnum LT first_orbit THEN BEGIN
      print, "Skip GeoMatch netCDF file: ", ncfilepr, " by orbit threshold."
      CONTINUE
   ENDIF ;ELSE print, "GeoMatch netCDF file: ", ncfilepr
ENDIF

; skip duplicate orbit for given site
   IF ( site EQ lastsite AND orbitnum EQ lastorbitnum ) THEN BEGIN
      print, ""
      print, "Skipping duplicate site/orbit file ", bname, ", last file done was ", lastncfile
      CONTINUE
   ENDIF

; skip sites not in sitelist array, if supplied
   IF (N_ELEMENTS(sitelist) NE 0) THEN BEGIN
      IF WHERE( STRPOS(sitelist, site) NE -1 ) EQ -1 THEN BEGIN
         print, "Skipping unmatched site file ", bname
         CONTINUE
      ENDIF
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
       PTRtop=ptr_top, PTRbotm=ptr_botm, $
       PTRsfcrainpr=ptr_nearSurfRain, PTRsfcraincomb=ptr_nearSurfRain_2b31, $
       PTRrainflag_int=ptr_rnFlag, PTRraintype_int=ptr_rnType, PTRbbProx=ptr_bbProx, $
       PTRhgtcat=ptr_hgtcat, PTRdist=ptr_dist, PTRpctgoodpr=ptr_pctgoodpr, $
       PTRpctgoodgv=ptr_pctgoodgv, PTRpctgoodrain=ptr_pctgoodrain, BBPARMS=BBparms, $
       BB_RELATIVE=bb_relative )
 END
  'DPR' : BEGIN
    PRINT, "INSTRUMENT: ", pr_or_dpr
    status = fprep_dpr_geo_match_profiles( ncfilepr, heights, $
       PCT_ABV_THRESH=pctAbvThresh, S2KU=s2ku, PTRfieldflags=ptr_fieldflags, $
       PTRgeometa=ptr_geometa, PTRsweepmeta=ptr_sweepmeta, PTRsitemeta=ptr_sitemeta, $
       PTRGVZMEAN=ptr_gvz, PTRGVMAX=ptr_gvzmax, PTRGVSTDDEV=ptr_gvzstddev, $
       PTRzcor=ptr_zcor, PTRzraw=ptr_zraw, PTRrain3d=ptr_rain3, $
       PTRtop=ptr_top, PTRbotm=ptr_botm, PTRstmTopHgt=ptr_stmTopHgt, $
       PTRsfcrainpr=ptr_nearSurfRain, PTRsfcraincomb=ptr_nearSurfRain_2b31, $
       PTRrainflag_int=ptr_rnFlag, PTRraintype_int=ptr_rnType, PTRbbProx=ptr_bbProx, $
       PTRhgtcat=ptr_hgtcat, PTRdist=ptr_dist,  PTRpctgoodpr=ptr_pctgoodpr, $
       PTRpctgoodgv=ptr_pctgoodgv, PTRpctgoodrain=ptr_pctgoodrain, BBPARMS=BBparms, $
       BB_RELATIVE=bb_relative, ALT_BB_HGT=alt_bb_file )
 END
  'DPRGMI' : BEGIN
    PRINT, "INSTRUMENT: ", pr_or_dpr
    status = fprep_dprgmi_geo_match_profiles( ncfilepr, heights, $
       KUKA=KuKa, SCANTYPE=swath, PCT_ABV_THRESH=pctAbvThresh, S2KU=s2ku, $
       PTRfieldflags=ptr_fieldflags, PTRgeometa=ptr_geometa, $
       PTRsweepmeta=ptr_sweepmeta, PTRsitemeta=ptr_sitemeta, $
       PTRGVZMEAN=ptr_gvz, PTRGVMAX=ptr_gvzmax, PTRGVSTDDEV=ptr_gvzstddev, $
       PTRzcor=ptr_zcor, PTRrain3d=ptr_rain3, $
       PTRGVRCMEAN=ptr_gvrc, PTRGVRPMEAN=ptr_gvrp, PTRGVRRMEAN=ptr_gvrr, $
       PTRtop=ptr_top, PTRbotm=ptr_botm, $
       PTRsfcrainpr=ptr_nearSurfRain, PTRraintype_int=ptr_rnType, $
       PTRxCorners=ptr_xCorner, PTRyCorners=ptr_yCorner, PTRbbProx=ptr_bbProx, $
       PTRhgtcat=ptr_hgtcat, PTRdist=ptr_dist, PTRpridx_long=ptr_pr_index, $
       PTRpctgoodpr=ptr_pctgoodpr, PTRpctgoodgv=ptr_pctgoodgv, $
       PTRpctgoodrain=ptr_pctgoodrain, PTRpctgoodrcgv=ptr_pctgoodrcgv, $
       PTRpctgoodrpgv=ptr_pctgoodrpgv, PTRpctgoodrrgv=ptr_pctgoodrrgv, $
       BBPARMS=BBparms, ALT_BB_HGT=alt_bb_file )
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
   zraw=temporary(*ptr_zraw)
   zcor=temporary(*ptr_zcor)
   rain3=temporary(*ptr_rain3)
   nearSurfRain=temporary(*ptr_nearSurfRain)
   nearSurfRain_2b31=temporary(*ptr_nearSurfRain_2b31)
   top=temporary(*ptr_top)
   botm=temporary(*ptr_botm)
   rnflag=temporary(*ptr_rnFlag)
   rntype=temporary(*ptr_rnType)
   bbProx=temporary(*ptr_bbProx)
   hgtcat=temporary(*ptr_hgtcat)
   dist=temporary(*ptr_dist)
   pctgoodpr=temporary(*ptr_pctgoodpr)
   pctgoodgv=temporary(*ptr_pctgoodgv)
   pctgoodrain=temporary(*ptr_pctgoodrain)
   stmTopHgt=temporary(*ptr_stmTopHgt)

; extract some needed values from the metadata structures
   site_lat = mysite.site_lat
   site_lon = mysite.site_lon
   siteID = string(mysite.site_id)
   nsweeps = mygeometa.num_sweeps

if pr_or_dpr EQ 'DPRGMI' then zraw=zcor    ; don't have zraw in DPRGMI

;=========================================================================

; Optional data clipping based on percent completeness of the volume averages:

; Decide which PR and GV points to include, based on percent of expected points
; in bin-averaged results that were above dBZ thresholds set when the matchups
; were done.  If unspecified or set to zero, include all points regardless of
; 'completeness' of the volume averages, as long as there was at least one valid
; gate value in the sample average.


   IF ( pctAbvThreshF GT 0.0 ) THEN BEGIN
       ; clip to the 'good' points, where 'pctAbvThreshF' fraction of bins in average
       ; were above threshold
      idxgoodenuff = WHERE( pctgoodpr GE pctAbvThreshF $
                       AND  pctgoodgv GE pctAbvThreshF $
                       AND  stmTopHgt GT 0, countgoodpct )
   ENDIF ELSE BEGIN
      idxgoodenuff = WHERE( pctgoodpr GT 0.0 AND pctgoodgv GT 0.0 $
                       AND  stmTopHgt GT 0, countgoodpct )
   ENDELSE

      IF ( countgoodpct GT 0 ) THEN BEGIN
          gvz = gvz[idxgoodenuff]
          zraw = zraw[idxgoodenuff]
          zcor = zcor[idxgoodenuff]
          rain3 = rain3[idxgoodenuff]
          gvzmax = gvzmax[idxgoodenuff]
          gvzstddev = gvzstddev[idxgoodenuff]
;          rnFlag = rnFlag[idxgoodenuff]
          rnType = rnType[idxgoodenuff]
          dist = dist[idxgoodenuff]
          bbProx = bbProx[idxgoodenuff]
          hgtcat = hgtcat[idxgoodenuff]
          stmTopHgt = stmTopHgt[idxgoodenuff]
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


; build an array of range categories from the GV radar, using ranges previously
; computed from lat and lon by fprep_geo_match_profiles():
; - range categories: 0 for 0<=r<50, 1 for 50<=r<100, 2 for r>=100, etc.
;   (for now we only have points roughly inside 100km, so limit to 2 categs.)
;   distcat = ( FIX(dist) / 50 ) < 1
; SUBSTITUTE ECHO TOP HEIGHT CATEGORIES 0<HGT<3000, 3000<HGT<6000, HGT>6000
   distcat = ( stmTopHgt/3000 ) < 2


; get info from array of height category for the fixed-height levels, for profiles
   num_in_hgt_cat = LONARR( nhgtcats )
   FOR i=0, nhgtcats-1 DO BEGIN
      hgtstr =  string(heights[i], FORMAT='(f0.1)')
      idxhgt = where(hgtcat EQ i, counthgts)
      num_in_hgt_cat[i] = counthgts
      if ( counthgts GT 0 ) THEN $
         print, "HEIGHT = "+hgtstr+" km: npts = ", counthgts
   ENDFOR

  ; Compute dBZ statistics at each level
   for lev2get = 0, nhgtcats-1 do begin
      IF ( num_in_hgt_cat[lev2get] GT 0 ) THEN BEGIN
        ; grab the subset of points at this height level
         idxathgt = WHERE( hgtcat EQ lev2get, countathgt )
         dbzcorlev = zcor[idxathgt]
         dbznexlev = gvz[idxathgt]
         raintypelev = rntype[idxathgt]
         distcatlev = distcat[idxathgt]
         BBproxlev = BBprox[idxathgt]
         gvzmaxlev = gvzmax[idxathgt]
         gvzstddevlev = gvzstddev[idxathgt]

        ; Compute stratified dBZ statistics at this level
         this_statsbydist = {stats21ways}
         stratify_diffs21dist_geo2, dbzcorlev, dbznexlev, raintypelev, $
                                    BBproxlev, distcatlev, gvzmaxlev, $
                                    gvzstddevlev, this_statsbydist, $
                                    DO_STDDEV=do_stddev
        ; Write Delimited Output for database
         printf_stat_struct21dist3, this_statsbydist, pctAbvThresh, 'GeoM', $
                                    siteID, orbit, lev2get, heights, DBunit, $
                                    /SUPRESS_ZERO, DO_STDDEV=do_stddev

         IF N_ELEMENTS(profile_save) NE 0 THEN $
            ; accumulate PR and GR dBZ histograms by echo top category at this level
            accum_histograms_by_echotop, dbzcorlev, dbznexlev, distcatlev, $
                                         accum_ptrs, lev2get, bindbz
      ENDIF
   endfor

  ;# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

   IF do_scatr THEN BEGIN
     ; accumulate 2-D histogram of stratiform, above-BB reflectivity
      idxabv = WHERE( BBprox EQ 2 AND rntype EQ RainType_stratiform, countabv )
      IF countabv GT 0 THEN BEGIN
         IF have2dhist THEN BEGIN
            zhist2d = zhist2d + HIST_2D( gvz[idxabv], zcor[idxabv], MIN1=15.0, $
                                         MIN2=15.0, MAX1=45.0, MAX2=45.0, BIN1=0.2, $
                                         BIN2=0.2 )
            minprz = MIN(zcor[idxabv]) < minprz
         ENDIF ELSE BEGIN
            zhist2d = HIST_2D( gvz[idxabv], zcor[idxabv], MIN1=15.0, $
                               MIN2=15.0, MAX1=45.0, MAX2=45.0, BIN1=0.2, $
                               BIN2=0.2 )
            minprz = MIN(zcor[idxabv])
            have2dhist = 1
         ENDELSE
      ENDIF
   ENDIF

  ;# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

   nextFile:
   lastorbitnum=orbitnum
   lastncfile=bname
   lastsite=site

ENDFOR    ; end of loop over fnum = 0, nf-1

PRINT, '' & PRINT, "Min PR Z: ", minprz & PRINT, ''

IF have2dhist EQ 1 THEN BEGIN
  ; CREATE THE SCATTER PLOT OBJECT FROM THE BINNED DATA
;   device, decomposed=0
;   common colors, r_orig, g_orig, b_orig, r_curr, g_curr, b_curr ;load color table
;   loadct,6
;   red=bytarr(256) & green=bytarr(256) & blue=bytarr(256)
;   red=r_curr & green=g_curr & blue=b_curr
;   red(0)=255 & green(0)=255 & blue(0)=255
;   tvlct,red,green,blue
  ; SCALE THE HISTOGRAM COUNTS TO 0-255 IMAGE BYTE VALUES
   histImg = BYTSCL(zhist2D)
   winsiz = SIZE( histImg, /DIMENSIONS )
   histImg = CONGRID(histImg, winsiz[0]*4, winsiz[1]*4)
   winsiz = SIZE( histImg, /DIMENSIONS )
;   window,  xsize=winsiz[0], ysize=winsiz[1]
;   tvscl, histImg
;   plots, [0,winsiz[0]-1], [0,winsiz[1]-1], color=100, THICK=3, /device
   rgb=COLORTABLE(33)
   rgb[0,*]=255   ; set zero count color to White background
   im=image(histImg, axis_style=2, xmajor=7, ymajor=7, xminor=4, yminor=4, RGB_TABLE=rgb, $
            TITLE = pr_or_dpr+" vs. GR Reflectivity Scatter, Above Bright Band" )
   im.xtickname=['15','20','25','30','35','40','45']
   im.ytickname=['15','20','25','30','35','40','45']
   IF ( s2ku ) THEN xtitleadd = ', Ku-adjusted' ELSE xtitleadd = ''
   im.xtitle= 'GR Reflectivity (dBZ)' + xtitleadd
   im.ytitle= pr_or_dpr + ' Reflectivity (dBZ)'
  ; add the 1:1 line to the plot
   line1_1 = PLOT( /OVERPLOT, [0,winsiz[0]-1], [0,winsiz[1]-1], color='black' )
  ; define the parameters for a color bar with 9 tick levels labeled
   ticnms = STRARR(256)
   ticlocs = INDGEN(9)*256/8
   ticInterval = MAX(zhist2d)/8.0
   ticnames = STRING( FIX(indgen(9)*ticInterval), FORMAT='(I0)' )
   ticnms[ticlocs] = ticnames
   cbar=colorbar(target=im, ori=1, pos=[0.95, 0.2, 0.98, 0.75], $
                 TICKVALUES=ticlocs, TICKNAME=ticnms, TITLE="# samples")
ENDIF

IF N_ELEMENTS(profile_save) NE 0 THEN BEGIN
   ; Compute ensemble mean and StdDev of dBZ at each level from grouped data
   ; and save to variables used in plot_mean_profiles.pro.
   bindbz = DOUBLE(bindbz)
   bindbzsq = bindbz^2
   sourcetext = ['PR (< 3)  : ', 'PR (3 - 6): ', 'PR (> 6) : ', $
                 'GR (< 3)  : ', 'GR (3 - 6): ', 'GR (> 6) : ']
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
   IF ( s2ku ) THEN savfile = outpath+'/StatsProfiles_'+pr_or_dpr+'_GR_Pct'+ $
                          strtrim(string(pctAbvThresh),2)+addme+'_S2Ku.sav' $
   ELSE savfile = outpath+'/StatsProfiles_'+pr_or_dpr+'_GR_Pct'+ $
              strtrim(string(pctAbvThresh),2)+addme+'_DefaultS.sav'
   PRINT, ''
   PRINT, "Saved ensemble profile variables to: ", savfile
   PRINT, ''
   hgtarr = TEMPORARY(heights)
   SAVE, cprmnarr, cgrmnarr, cprsdarr, cgrsdarr, csamples,  $
         sprmnarr, sgrmnarr, sprsdarr, sgrsdarr, ssamples,  $
          prmnarr,  grmnarr,  prsdarr,  grsdarr,  samples,  $
         hgtarr, FILE = savfile
   thePlot = fplot_mean_profiles( savfile, FILE_BASENAME(savfile), $
                INSTRUMENT=pr_or_dpr, CAT_NAMES=['ET<3 km','3<ET<6','ET>6 km'] )
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
*ptr_top=temporary(top)
*ptr_botm=temporary(botm)
*ptr_rnflag=temporary(rnFlag)
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
if (ptr_valid(ptr_top) eq 1) then ptr_free,ptr_top
if (ptr_valid(ptr_botm) eq 1) then ptr_free,ptr_botm
if (ptr_valid(ptr_rnFlag) eq 1) then ptr_free,ptr_rnFlag
if (ptr_valid(ptr_rnType) eq 1) then ptr_free,ptr_rnType
if (ptr_valid(ptr_bbProx) eq 1) then ptr_free,ptr_bbProx
if (ptr_valid(ptr_hgtcat) eq 1) then ptr_free,ptr_hgtcat
if (ptr_valid(ptr_dist) eq 1) then ptr_free,ptr_dist
if (ptr_valid(ptr_pctgoodpr) eq 1) then ptr_free,ptr_pctgoodpr
if (ptr_valid(ptr_pctgoodgv) eq 1) then ptr_free,ptr_pctgoodgv
if (ptr_valid(ptr_pctgoodrain) eq 1) then ptr_free,ptr_pctgoodrain
if (ptr_valid(zHist_ptr) eq 1) then ptr_free, zHist_ptr
; help, /memory

print, ''
print, 'Done!'

errorExit:

FREE_LUN, DBunit
print, ''
print, 'Output stratified statistics file status:'
command = 'ls -al ' + dbfile
spawn, command
print, ''

IF N_ELEMENTS(thePlot) NE 0 THEN BEGIN
   IF SIZE(thePlot, /TYPE) EQ 11 THEN BEGIN
      doodah = ""
      READ, doodah, PROMPT="Enter C to Close plot(s) and exit, " + $
            "or any other key to exit with plot(s) remaining: "
      IF STRUPCASE(doodah) EQ "C" THEN BEGIN
         thePlot.close
         IF have2dhist EQ 1 THEN im.close   ;WDELETE
      ENDIF ELSE BEGIN
        ; see whether the caller has given us a variable to return the PLOT
        ; and IMAGE object references in
         IF N_ELEMENTS(plot_obj_array) NE 0 THEN BEGIN
            IF have2dhist EQ 1 THEN BEGIN
               plot_obj_array = OBJARR(2)
               plot_obj_array[0] = thePlot
               plot_obj_array[1] = im
            ENDIF ELSE BEGIN
               plot_obj_array = OBJARR[1]
               plot_obj_array[0] = thePlot
            ENDELSE
         ENDIF
      ENDELSE
   ENDIF
ENDIF
end
