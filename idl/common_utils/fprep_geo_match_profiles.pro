;===============================================================================
;+
; Copyright © 2010, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; fprep_geo_match_profiles.pro
; - Morris/SAIC/GPM_GV  March 2010
;
;
; DESCRIPTION
; -----------
; Reads PR and GR reflectivity and spatial fields from a user-selected geo_match
; netCDF file, builds index arrays of categories of range, rain type, bright
; band proximity (above, below, within), and an array of actual range. Single-
; level arrays (pr_index, rainType, etc.) are replicated to the same number of
; levels/dimensions as the sweep-level variables (PR and GR reflectivity, etc.)
; for convenience so that every volume-match sample has a value for every
; variable, referenced by the same location in each array.
;
; "Bogus" border points that enclose the actual match-up data at each level are
; removed so that only the profiles with actual data are returned to the caller.
; All original/replicated spatial data fields are restored to the form of 2-D
; arrays of dimensions (number of PR rays, number of sweeps) to facilitate
; analysis as vertical profiles.
;
; For the array of heights passed, or for a default set of heights, the
; routine will compute an array of the dimensions of the sweep-level data
; that assigns each sample point in the sweep-level data to a fixed-height
; level based on the vertical midpoint of the sample.  The assigned values
; are the array index value of the corresponding height in the default/passed
; array of heights.
;
; The mean height of the bright band, and the array index of the highest and
; lowest fixed-height level affected by the bright band will be computed, and
; if the BBPARMS keyword is set, these values will be returned in the 'bbparms'
; structure supplied as the formal parameter.  See the code for rules on how
; fixed-height layers affected by the bright band are determined.  It is
; up to the caller to properly create and initialize the bbparms structure
; to be passed as the BBPARMS keyword parameter, as in the following example:
;
; bbparms = {meanBB : -99.99, BB_HgtLo : -99, BB_HgtHi : -99}
;
; The ALT_BB_HGT keyword allows the caller to provide either a single numerical
; value specifying the mean bright band height to be used, or a file of
; precomputed freezing level heights to be searched to find the BB height for
; the current site and orbit, when the mean BB height cannot be determined
; using BB field values in the DPR data.
;
; If the pctAbvThresh parameter is specified, then the function will also
; compute 10 arrays holding the percentage of raw bins included in the volume
; average whose physical values were at/above the fixed thresholds for:
;
; 1) PR reflectivity (18 dBZ, or as defined in the geo_match netcdf file)
; 2) GR reflectivity (15 dBZ, or as defined in the geo_match netcdf file)
; 3) PR rainrate (0.01 mm/h, or as defined in the geo_match netcdf file)
; 4) GR rainrate (uses same threshold as PR rainrate).
; 5) GR Hydromet ID Category (not a threshold, percent of HID-defined bins)
; 6) GR D0 (not a threshold; percent of non-missing values)
; 7) GR Nw (not a threshold; percent of non-missing values)
; 8) GR Zdr (not a threshold; percent of non-missing values)
; 9) GR Kdp (not a threshold; percent of non-missing values)
; 10) GR RHOhv (not a threshold; percent of non-missing values)
;
; The values that apply to the first 3 thresholds for the data file being
; processed are available in the "mygeometa" variable, a structure of type
; "geo_match_meta" (see geo_match_nc_structs.inc), populated in the call to
; read_geo_match_netcdf().  These are the structure variables PR_dBZ_min,
; GV_dBZ_min, and rain_min, respectively.
;
; If s2ku binary parameter is set, then the Liao/Meneghini S-to-Ku band
; reflectivity adjustment will be made to the volume-matched ground radar
; reflectivity field, gvz.
;
;
; PARAMETERS
; ----------
; ncfilepr     - fully qualified path/name of the geo_match netCDF file to read
;
; heights      - array of fixed height levels used to compute the height
;                categories assigned to the 3-D data samples.  If none is
;                provided, a default set of 13 levels from 1.5-19.5 km is used
;
; pctAbvThresh - compute arrays of the percent of bins in the geometric-matching
;                volume that were above their respective Z thresholds, specified
;                at the time the geo-match dataset was created.  Essentially a
;                measure of "beam-filling goodness".  100 percent = only those
;                matchup points where all the PR and GV bins in the volume
;                averages were above threshold (complete volume filled with
;                above threshold bin values).  0 percent = all matchup points
;                available, with no regard for thresholds
;
; gvconvective - GV reflectivity threshold at/above which GV data are considered
;                to be of Convective Rain Type.  Default = 35.0 if not specified.
;                If set to <= 0, then GV reflectivity is ignored in evaluating
;                whether PR-indicated Stratiform Rain Type matches GV type.
;
; gvstratiform - GV reflectivity threshold at/below which GV data are considered
;                to be of Stratiform Rain Type.  Default=25.0 if not specified.
;                If set to <= 0, then GV reflectivity is ignored in evaluating
;                whether PR-indicated Convective Rain Type matches GV type.
;
; s2ku         - Binary parameter, controls whether or not to apply the Liao/
;                Meneghini S-band to Ku-band adjustment to GV reflectivity.
;                Default = no
;
; bbparms      - structure to hold computed bright band variables: mean BB
;                height, and lowest and highest fixed-layer heights affected by
;                the bright band (see heights parameter and DESCRIPTION section)
;              - All heights are in relation to Above Ground Level starting with
;                version 1.1 netCDF data files.
;
; bbwidth      - Height (km) above/below the mean bright band height within
;                which a sample touching (above) [below] this layer is
;                considered to be within (above) [below] the BB. Default=0.750
;
; alt_bb_hgt   - Either a single numerical value specifying the mean bright band
;                height to be used, or a file of precomputed freezing level
;                heights that will be searched to find the BB height for the
;                current site and orbit, when the mean BB height cannot be
;                determined using BB field values in the DPR data.
;
; (pointers)   - Optional keywords consisting of unassigned pointers created by
;                the calling routine.  These pointers are assigned to their
;                namesake DATA FIELDS at the end of the routine, as follows:
; 
;     At the end of the procedure, the following data fields will be available
;     to be returned to the caller.  If a pointer for the variable is provided
;     in the parameter list, the pointer will be assigned to the variable. 
;     Pointer arguments should be unassigned pointers to an undefined variable,
;     i.e., a heap pointer created as follows: PTRxxx=ptr_new(/allocate_heap).
;     If no pointer is supplied for the keyword, then the corresponding data
;     variable listed below goes out of scope when this function returns to the
;     caller, and the data field will be unavailable.  The keyword for each
;     listed variable is the variable name prefixed by the characters "PTR",
;     for example, PTRgvz for the variable gvz.  The exceptions are the five
;     structure variables beginning with "my", such as mysite.  In this case the
;     "my" in the variable name is replaced by "PTR" to get the keyword, e.g.,
;     PTRsite for mysite.  If in doubt, refer to the function definition itself.
;
; mygeometa           structure holding dimension, version, and threshold
;                       information for the matchup data
;
; mysweeps            structure holding GR volume info - sweep elevations etc.
;
; mysite              structure holding GR location, station ID, etc.
;
; myflags             structure holding flags indicating whether data fields are
;                        good, or just fill values (i.e., bad or missing)
;
; myfiles             structure holding the names of the input PR and GR files
;                        used in the matchup
;
; gvz                 subsetted array of volume-matched GR mean reflectivity
; gvzmax              subsetted array of volume-matched GR maximum reflectivity
; gvzstddev           subsetted array of volume-matched GR reflectivity standard
;                        deviation
;
; gvrr                subsetted array of volume-matched GR 3D mean rainrate
; gvrrmax             subsetted array of volume-matched GR 3D maximum rainrate
; gvrrstddev          subsetted array of volume-matched GR 3D rainrate standard
;                        deviation
;
; GR_Zdr              subsetted array of volume-matched GR mean Zdr
;                        (differential reflectivity)
; GR_ZdrMax           As above, but sample maximum of Zdr
; GR_ZdrStdDev        As above, but sample standard deviation of Zdr
;
; GR_Kdp              subsetted array of volume-matched GR mean Kdp (specific
;                        differential phase)
; GR_KdpMax           As above, but sample maximum of Kdp
; GR_KdpStdDev        As above, but sample standard deviation of Kdp
;
; GR_RHOhv            subsetted array of volume-matched GR mean RHOhv
;                        (co-polar correlation coefficient)
; GR_RHOhvMax         As above, but sample maximum of RHOhv
; GR_RHOhvStdDev      As above, but sample standard deviation of RHOhv
;
; GR_HID              subsetted array of volume-matched GR Hydrometeor ID (HID)
;                         category (count of GR bins in each HID category)
; mode_HID            subsetted array of volume-matched GR Hydrometeor ID (HID)
;                         "best" category (HID category with the highest count
;                         of bins in the sample volume)
;
; GR_Dzero            subsetted array of volume-matched GR mean D0 (Median
;                        volume diameter)
; GR_DzeroMax         As above, but sample maximum of Dzero
; GR_DzeroStdDev      As above, but sample standard deviation of Dzero
;
; GR_Nw               subsetted array of volume-matched GR mean Nw (Normalized
;                        intercept parameter)
; GR_NwMax            As above, but sample maximum of Nw
; GR_NwStdDev         As above, but sample standard deviation of Nw
;
; zraw                subsetted array of volume-matched PR 1C21 reflectivity
; zcor                subsetted array of volume-matched PR 2A25 corrected
;                        reflectivity
;
; rain3               subsetted array of volume-matched PR 3D rainrate
;
; top                 subsetted array of volume-match sample top heights, km
; botm                subsetted array of volume-match sample bottom heights, km
;
; lat                 subsetted array of parallax-adjusted volume-match sample
;                        latitude for the 3-D Z and rainrate, on sweep surfaces
; lon                 subsetted array of parallax-adjusted volume-match sample
;                        longitude for the 3-D Z and rainrate, on sweep surfaces
;
; xCorner             subsetted array of volume-match sample "x" cartesian
;                        corner coordinates computed from lat and lon, used as
;                        plot bounds for displaying the 3-D volume-match Z and
;                        rainrate data on a map; GV radar-centric, in km
; yCorner             as above, but "y" coordinates
;
; pr_lat              subsetted array of volume-match sample latitude at the
;                        earth surface (from PR 2A-25 "Geolocation" variable)
; pr_lon              subsetted array of volume-match sample longitude at the
;                        earth surface (from PR 2A-25 "Geolocation" variable)
;
; nearSurfRain *        subsetted array of volume-match near-surface PR rainrate
; nearSurfRain_2b31 *   subsetted array of volume-matched 2B31 PR rainrate
;
; pia *               subsetted array of PR 2A25 Path Integrated Attenuation
;
; pr_index *          subsetted array of 1-D indices of the original (scan,ray)
;                        PR product coordinates
;
; rnFlag *            subsetted array of volume-match sample point yes/no rain
;                        flag value
;
; rnType  *,#         subsetted array of volume-match sample point rain type
;
; landOcean *         subsetted array of underlying surface type
;
; dist                internally-computed array of volume-match sample point
;                        range from radar, km
; hgtcat              internally-computed array of volume-match sample point
;                        height layer indices, 0-12, representing 1.5-19.5 km
;                        (default, if heights parameter is not provided) or
;                        the value heights[hgtcat] if the heights parameter
;                        is specified.  This represents the nearest fixed-
;                        height layer to which the sample's midpoint is located
; bbProx              internally-computed array of volume-match sample point
;                        proximity to mean bright band: 1 (below), 2 (within),
;                        3 (above)
;
; bbHeight *          array of PR 2A25 bright band height from RangeBinNums, m
;
; bbStatus *          array of PR 2A23 bright band status
;
; status_2a23 *       array of PR 2A23 status flag
;
; pctgoodpr %         internally-computed array of volume-match sample point
;                        percent of original PR dBZ bins above threshold
; pctgoodgv %         internally-computed array of volume-match sample point
;                        percent of original GR dBZ bins above threshold
; pctgoodrain %       internally-computed array of volume-match sample point
;                        percent of original PR rainrate bins above threshold
; pctgoodrrgv %       internally-computed array of volume-match sample point
;                        percent of original GR rainrate bins above threshold
; pctgoodzdrgv %      internally-computed array of volume-match sample point
;                        percent of non-missing original GR Zdr bins
; pctgoodkdpgv %      internally-computed array of volume-match sample point
;                        percent of non-missing original GR Kdp bins
; pctgoodRHOhvgv %    internally-computed array of volume-match sample point
;                        percent of non-missing original GR RHOhv bins
; pctgoodhidgv %      internally-computed array of volume-match sample point
;                        percent of original GR HID bins with assigned category
; pctgooddzerogv %    internally-computed array of volume-match sample point
;                        percent of non-missing original GR D0 bins
; pctgoodnwgv %       internally-computed array of volume-match sample point
;                        percent of non-missing original GR Nw bins
;
; The arrays should all be of the same size when done, with the exception of
; the xCorner, yCorner, and GR_HID fields that have an additional dimension
; to be dealt with.  Those marked by * are originally single-level fields
; like nearSurfRain that are replicated to the N sweep levels in the volume scan
; to match the multi-level fields before the data get subsetted. Subsetting
; consists of removing the optional "bogus" data points that enclose the area of
; the "actual" PR/GR overlap data.  The "bogus" points are indicated by negative
; values of pr_index.
;
; '#' indicates that rain type is truncated to simple categories 1 (Stratiform),
;   2 (Convective), or 3 (Other), from the original PR 3-digit subcategories
;
; '%' indicates fields that are computed only if the parameter pctAbvThresh is
;   specified.  Otherwise, any pointers supplied for these variables in the
;   list of function parameters will be left unassigned.
;
;
; HISTORY
; -------
; 03/03/10 Morris, GPM GV, SAIC
; - Created.
; 05/03/10 Morris, GPM GV, SAIC
; - Improved estimate of mean BB height by calling get_mean_bb_height().  Fix
;   logic of assigning upper and lower constant-height layers affected by the
;   bright band, removing hard-coded assumption of the traditional 13 layers.
; - Expanded the documentation in the prologue.
; 05/05/10 Morris, GPM GV, SAIC
; - Modified the depth-of-influence of the bright band to +/- 750m of mean BB
;   height for sample-by-sample assignment of proximity to bright band.
; - Added keywords/logic to adjust rain type based on convective and stratiform
;   reflectivity thresholds, gv_convective and gv_stratiform.  Otherwise, the
;   rain types used in computation of mean bright band height may be
;   inconsistent with those used in the calling procedure.
; 08/16/10 Morris, GPM GV, SAIC
; - Expanded the documentation in the prologue to define 'bbparms' parameter.
; 09/16/10 Morris, GPM GV, SAIC
; - Use site_elev to adjust mean BB height from MSL to AGL height in computation
;   of the BB proximity category (above, within, below) for sample volumes, and
;   for the mean BB height value 'meanbb' returned in the bbparms structure.
; 10/05/10 Morris, GPM GV, SAIC
; - Deleted duplicate lines in pointer dereferences at end of routine.
; 12/2010 Morris, GPM GV, SAIC
; - Now calls GET_GEO_MATCH_NC_STRUCT() to get properly initialized metadata
;   structures in place of "including" geo_match_nc_structs.inc file via IDL "@"
;   include mechanism.
; - Multiple changes to read variables from Version 2.0 geo-match netCDF file:
;   - add parameters to read/pass gvzmax, gvzstddev, bbHeight, bbstatus, 
;     status_2a23
;   - add logic to decide form of call to enhanced get_mean_bb_height()
;     function, based on availability of BBstatus field in netCDF file.
; 1/10/11  Morris/GPM GV/SAIC
; - Added BB_RELATIVE parameter to compute statistics grouped by heights
;   relative to the mean bright band height rather than height AGL.
; 03/28/11 by Bob Morris, GPM GV (SAIC)
;  - Add reading of PR/GR filename data from the version 2.1 matchup file and
;    populating of the filesmeta structure with these names.
; 11/04/11 by Bob Morris, GPM GV (SAIC)
;  - Add reading of landOceanFlag field previously overlooked.
; 03/01/12 by Bob Morris, GPM GV (SAIC)
;  - Changed back to calling get_mean_bb_height rather than get_mean_bb_height2
; 07/27/12 by Bob Morris, GPM GV (SAIC)
;  - Added BBWIDTH parameter to allow variable width of BB influence for
;    determining bbProx category.
; 08/29/12 by Bob Morris, GPM GV (SAIC)
;  - Added full value checking/override logic to input bbwidth parameter.
; 10/02/12 by Bob Morris, GPM GV (SAIC)
;  - Added PR_latitude and PR_longitude to the list of parameters able to be
;    read and returned.
; 07/24/13 by Bob Morris, GPM GV (SAIC)
;  - Added rrgvMean, rrgvMax, and rrgvStdDev to the list of parameters able to
;    be read and returned for Version 2.2 GRtoPR geo-match netCDF files.
;  - Added pctgoodrrgv to the parameters able to be computed and returned for
;    Version 2.2 GRtoPR geo-match netCDF files.
;  - Changed N_ELEMENTS() checks on I/O pointers to PTR_VALID() checks.
;  - Reformatted to fit within 80 columns.
; 07/26/13 by Bob Morris, GPM GV (SAIC)
;  - Added missing definition of gv_rr_rej data field array.
; 09/10/13 by Bob Morris, GPM GV (SAIC)
;  - Added missing definitions of xCorner, yCorner, pr_lat, pr_lon, landOcean,
;    and made other documentation enhancements in prologue.
; 01/28/14 by Bob Morris, GPM GV (SAIC)
;  - Added parameters for GR_DP_HID, GR_DP_Dzero, GR_DP_Nw, pctgoodhidgv, 
;    pctgooddzerogv, and pctgoodnwgv for version 2.3 matchup file.
;  - Added SWITCH statements to enforce version-specific content retrieval from
;    the matchup netCDF files.  Invalidated passed pointers for array data items
;    that do not pertain to the file version being read.
; 01/30/14 by Bob Morris, GPM GV (SAIC)
;  - Added computed parameter HIDmode, the dominant Hydrometeor Identifier
;    category in the sample.
; 2/13/14 by Bob Morris, GPM GV (SAIC)
;  - Added Max and StdDev for GR D0 and Nw data variables, and added Mean,
;    Max, StdDev, and Percent Above Threshold for new GR variables Zdr, Kdp,
;    and RHOhv.
;  - Appended "Mean" qualifier to keywords PTRGVDZERO and PTRGVNW.
; 06/06/14 by Bob Morris, GPM GV (SAIC)
;  - Changed handling of case where no stratiform points with defined BB heights
;    exist to not exit with failed status.
; 07/15/14 by Bob Morris, GPM GV (SAIC)
;  - Renamed all *GR_DP_* variables to *GR_*, removing the "DP_" designators.
; 02/10/15 by Bob Morris, GPM GV (SAIC)
;  - Added PIA as a variable to be read from the version 3.1 matchup files.
; 02/11/15 by Bob Morris, GPM GV (SAIC)
; - Added capability to specify a mean bright band height source to be used if
;   one cannot be extracted from the PR bright band field in the matchup files.
; 03/31/14 by Bob Morris, GPM GV (SAIC)
;  - Added capability to accept string representation of a numerical value for
;    alt_bb_hgt and convert it to numerical type.  Calls new utility function
;    is_a_number().
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;===============================================================================


FUNCTION fprep_geo_match_profiles, ncfilepr, heights, $
    PCT_ABV_THRESH=pctAbvThresh, GV_CONVECTIVE=gvconvective, $
    GV_STRATIFORM=gvstratiform, S2KU=s2ku, PTRgeometa=ptr_geometa, $
    PTRsweepmeta=ptr_sweepmeta, PTRsitemeta=ptr_sitemeta, $
    PTRfieldflags=ptr_fieldflags, PTRfilesmeta=ptr_filesmeta, $

   ; ground radar variables
    PTRGVZMEAN=ptr_gvz, PTRGVMAX=ptr_gvzmax, PTRGVSTDDEV=ptr_gvzstddev, $
    PTRGVRRMEAN=ptr_gvrr, PTRGVRRMAX=ptr_gvrrmax, PTRGVRRSTDDEV=ptr_gvrrstddev, $
    PTRGVHID=ptr_GR_HID, PTRGVMODEHID=ptr_mode_HID, PTRGVDZEROMEAN=ptr_GR_Dzero, $
    PTRGVDZEROMAX=ptr_GR_Dzeromax, PTRGVDZEROSTDDEV=ptr_GR_Dzerostddev, $
    PTRGVNWMEAN=ptr_GR_Nw, PTRGVNWMAX=ptr_GR_Nwmax, $
    PTRGVNWSTDDEV=ptr_GR_Nwstddev, PTRGVZDRMEAN=ptr_GR_Zdr, $
    PTRGVZDRMAX=ptr_GR_Zdrmax, PTRGVZDRSTDDEV=ptr_GR_Zdrstddev, $
    PTRGVKDPMEAN=ptr_GR_Kdp, PTRGVKDPMAX=ptr_GR_Kdpmax, $
    PTRGVKDPSTDDEV=ptr_GR_Kdpstddev, PTRGVRHOHVMEAN=ptr_GR_RHOhv, $
    PTRGVRHOHVMAX=ptr_GR_RHOhvmax, PTRGVRHOHVSTDDEV=ptr_GR_RHOhvstddev, $

   ; space radar variables
    PTRzcor=ptr_zcor, PTRzraw=ptr_zraw, PTRrain3d=ptr_rain3, $
    PTRprlat=ptr_pr_lat, PTRprlon=ptr_pr_lon, PTRpia=ptr_pia, $
    PTRsfcrainpr=ptr_nearSurfRain, PTRsfcraincomb=ptr_nearSurfRain_2b31, $
    PTRrainflag_int=ptr_rnFlag, PTRraintype_int=ptr_rnType, $
    PTRlandOcean_int=ptr_landOcean, PTRpridx_long=ptr_pr_index, $
    PTRstatus2A23=ptr_status_2a23, PTRbbStatus=ptr_bbstatus, $

   ; derived/computed variables
    PTRtop=ptr_top, PTRbotm=ptr_botm, PTRlat=ptr_lat, PTRlon=ptr_lon, $
    PTRxCorners=ptr_xCorner, PTRyCorners=ptr_yCorner, PTRbbProx=ptr_bbProx, $
    PTRbbHgt=ptr_bbHeight, PTRhgtcat=ptr_hgtcat, PTRdist=ptr_dist, $

   ; percent above threshold parameters
    PTRpctgoodpr=ptr_pctgoodpr, PTRpctgoodrain=ptr_pctgoodrain, $
    PTRpctgoodgv=ptr_pctgoodgv, PTRpctgoodrrgv=ptr_pctgoodrrgv, $
    PTRpctgoodhidgv=ptr_pctgoodhidgv, PTRpctgooddzerogv=ptr_pctgooddzerogv, $
    PTRpctgoodnwgv=ptr_pctgoodnwgv, PTRpctgoodzdrgv=ptr_pctgoodzdrgv, $
    PTRpctgoodkdpgv=ptr_pctgoodkdpgv, PTRpctgoodrhohvgv=ptr_pctgoodrhohvgv, $

   ; Bright Band structure, control parameters
    BBPARMS=bbparms, BB_RELATIVE=bb_relative, BBWIDTH=bbwidth, $
    ALT_BB_HGT=alt_bb_hgt

; "include" file for structs returned from read_geo_match_netcdf()
; -- left here for reference only; instead, we now call the function
;    GET_GEO_MATCH_NC_STRUCT() to get only the structure type(s) needed
;@geo_match_nc_structs.inc

; "include" file for PR data constants
@pr_params.inc

s2ku = keyword_set( s2ku )

; if convective or stratiform reflectivity thresholds are not specified, disable
; rain type overrides by setting values to zero
IF ( N_ELEMENTS(gvconvective) NE 1 ) THEN gvconvective=0.0
IF ( N_ELEMENTS(gvstratiform) NE 1 ) THEN gvstratiform=0.0

; Get an uncompressed copy of the netCDF file - we never touch the original
cpstatus = uncomp_file( ncfilepr, ncfile1 )

status = 1   ; init return status to FAILED

if (cpstatus eq 'OK') then begin

 ; create <<initialized>> structures to hold the metadata variables
  mygeometa=GET_GEO_MATCH_NC_STRUCT('matchup')  ;{ geo_match_meta }
  mysweeps=GET_GEO_MATCH_NC_STRUCT('sweeps')    ;{ gv_sweep_meta }
  mysite=GET_GEO_MATCH_NC_STRUCT('site')        ;{ gv_site_meta }
  myflags=GET_GEO_MATCH_NC_STRUCT('fields')     ;{ pr_gv_field_flags }
  myfiles=GET_GEO_MATCH_NC_STRUCT( 'files' )

 ; read the file to populate only the structures
  status = read_geo_match_netcdf( ncfile1, matchupmeta=mygeometa, $
              sweepsmeta=mysweeps, sitemeta=mysite, fieldflags=myflags, $
              filesmeta=myfiles )
 ; remove the netCDF file copy and exit, if problems reading file
  IF (status EQ 1) THEN BEGIN
     command3 = "rm -v " + ncfile1
     spawn, command3
     GOTO, errorExit
  ENDIF

  site_lat = mysite.site_lat
  site_lon = mysite.site_lon
  siteID = string(mysite.site_id)
  site_elev = mysite.site_elev

 ; now create data field arrays of correct dimensions and read ALL data fields

  nfp = mygeometa.num_footprints  ; # of PR rays in dataset (real+bogus)
  nswp = mygeometa.num_sweeps     ; # of GR elevation sweeps in dataset
  nc_file_version = mygeometa.nc_file_version   ; geo-match file version

 ; don't try to read variables that don't exist in a given file version
  SWITCH nc_file_version OF
     3.1 : pia=fltarr(nfp)
     3.0 :
     2.3 : BEGIN
             gv_zdr_rej=intarr(nfp,nswp)
             gv_kdp_rej=intarr(nfp,nswp)
             gv_rhohv_rej=intarr(nfp,nswp)
             gv_hid_rej=intarr(nfp,nswp)
             gv_dzero_rej=intarr(nfp,nswp)
             gv_nw_rej=intarr(nfp,nswp)
            ; can't define GR_HID unless num_HID_categories is non-zero
             GR_HID=intarr(mygeometa.num_HID_categories,nfp,nswp)
             GR_Zdr=fltarr(nfp,nswp)
             GR_ZdrMax=fltarr(nfp,nswp)
             GR_ZdrStdDev=fltarr(nfp,nswp)
             GR_Kdp=fltarr(nfp,nswp)
             GR_KdpMax=fltarr(nfp,nswp)
             GR_KdpStdDev=fltarr(nfp,nswp)
             GR_RHOhv=fltarr(nfp,nswp)
             GR_RHOhvMax=fltarr(nfp,nswp)
             GR_RHOhvStdDev=fltarr(nfp,nswp)
             GR_Dzero=fltarr(nfp,nswp)
             GR_DzeroMax=fltarr(nfp,nswp)
             GR_DzeroStdDev=fltarr(nfp,nswp)
             GR_Nw=fltarr(nfp,nswp)
             GR_NwMax=fltarr(nfp,nswp)
             GR_NwStdDev=fltarr(nfp,nswp)
           END
     2.2 : BEGIN
             gv_rr_rej=intarr(nfp,nswp)
             gvrr=fltarr(nfp,nswp)
             gvrrMax=fltarr(nfp,nswp)
             gvrrStdDev=fltarr(nfp,nswp)
           END
     2.1 :
     2.0 : BEGIN
             gvzmax=fltarr(nfp,nswp)
             gvzstddev=fltarr(nfp,nswp)
             bbStatus=intarr(nfp)
             status_2a23=intarr(nfp)
           END
  ENDSWITCH

 ; everything else is in all versions of the matchup file, read them all
  gvexp=intarr(nfp,nswp)
  gvrej=intarr(nfp,nswp)
  prexp=intarr(nfp,nswp)
  zrawrej=intarr(nfp,nswp)
  zcorrej=intarr(nfp,nswp)
  rainrej=intarr(nfp,nswp)
  gvz=fltarr(nfp,nswp)
  zraw=fltarr(nfp,nswp)
  zcor=fltarr(nfp,nswp)
  rain3=fltarr(nfp,nswp)
  top=fltarr(nfp,nswp)
  botm=fltarr(nfp,nswp)
  xcorner=fltarr(4,nfp,nswp)
  ycorner=fltarr(4,nfp,nswp)
  lat=fltarr(nfp,nswp)
  lon=fltarr(nfp,nswp)
  pr_lat=fltarr(nfp)
  pr_lon=fltarr(nfp)
  nearSurfRain=fltarr(nfp)
  nearSurfRain_2b31=fltarr(nfp)
  bbHeight=fltarr(nfp)
  rnflag=intarr(nfp)
  rntype=intarr(nfp)
  landoceanflag=intarr(nfp)
  pr_index=lonarr(nfp)

 ; read the uncompressed geo-match netCDF file -- variables in the calling
 ; sequence are described and arranged by type

  status = read_geo_match_netcdf( ncfile1,                                   $

   ; expected/rejected bin counts for percent above threshold calculations:
    gvexpect_int=gvexp, gvreject_int=gvrej, prexpect_int=prexp,              $
    zrawreject_int=zrawrej, zcorreject_int=zcorrej, rainreject_int=rainrej,  $
    gv_rr_reject_int=gv_rr_rej, gv_hid_reject_int=gv_hid_rej,                $
    gv_dzero_reject_int=gv_dzero_rej, gv_nw_reject_int=gv_nw_rej,            $
    gv_zdr_reject_int=gv_zdr_rej, gv_kdp_reject_int=gv_kdp_rej,              $
    gv_RHOhv_reject_int=gv_RHOhv_rej,                                        $

   ; PR and GR reflectivity and rainrate and GR dual-polarization derived
   ; variables at sweep levels:
    dbzgv=gvz, gvStdDev=gvzStdDev, gvMax=gvzMax, dbzcor=zcor, dbzraw=zraw,   $
    rrgvMean=gvrr, rrgvMax=gvrrMax, rrgvStdDev=gvrrStdDev, rain3d=rain3,     $
    zdrgvMean=GR_Zdr, zdrgvMax=GR_ZdrMax, zdrgvStdDev=GR_ZdrStdDev, $
    kdpgvMean=GR_Kdp, kdpgvMax=GR_KdpMax, kdpgvStdDev=GR_KdpStdDev, $
    RHOHVgvMean=GR_RHOhv, RHOHVgvMax=GR_RHOhvMax,                      $
    RHOHVgvStdDev=GR_RHOhvStdDev, dzerogvMean=GR_Dzero,                $
    dzerogvMax=GR_DzeroMax, dzerogvStdDev=GR_DzeroStdDev,              $
    nwgvMean=GR_Nw, nwgvMax=GR_NwMax, nwgvStdDev=GR_NwStdDev,       $
    hidgv=GR_HID,                                                         $

   ; sample horizontal/vertical location variables:
    topHeight=top, bottomHeight=botm, xCorners=xCorner, yCorners=yCorner,    $
    latitude=lat, longitude=lon, PRlatitude=PR_lat, PRlongitude=PR_lon,      $

   ; surface-level PR rainrate variables and misc. footprint characteristics:
    sfcrainpr=nearSurfRain, sfcraincomb=nearSurfRain_2b31, bbhgt=BBHeight,   $
    rainflag_int=rnFlag, raintype_int=rnType, sfctype_int=landOceanFlag,     $
    status_2a23_int=status_2a23, BBstatus_int=bbStatus, PIA=pia,             $
    pridx_long=pr_index )


 ; remove the uncompressed file copy
  command3 = "rm -v " + ncfile1
  spawn, command3
  IF (status EQ 1) then GOTO, errorExit

endif else begin

  print, 'Cannot copy/unzip netCDF file: ', ncfilepr
  print, cpstatus
  command3 = "rm -v " + ncfile1
  spawn, command3
  goto, errorExit

endelse

; get array indices of the non-bogus (i.e., "actual") PR footprints
; -- pr_index is defined for one slice (sweep level), while most fields are
;    multiple-level (have another dimension: nswp).  Deal with this later on.
idxpractual = where(pr_index GE 0L, countactual)
if (countactual EQ 0) then begin
   print, "No non-bogus data points, quitting case."
   status = 1
   goto, errorExit
endif
; get the subset of pr_index values for actual PR rays in the matchup
pr_idx_actual = pr_index[idxpractual]

; re-set the number of footprints in the geo_match_meta structure to the
; subsetted value
mygeometa.num_footprints = countactual

; Reclassify rain types down to simple categories 1 (Stratiform), 2 (Convective),
;  or 3 (Other), where defined
idxrnpos = where(rntype ge 0, countrntype)
if (countrntype GT 0 ) then rntype[idxrnpos] = rntype[idxrnpos]/100

; - - - - - - - - - - - - - - - - - - - - - - - -

; clip the data fields down to the actual footprint points.  Deal with the
; single-level vs. multi-level fields first by replicating the single-level
; fields 'nswp' times (pr_index, rnType, rnFlag, nearSurfRain, nearSurfRain_2b31).

; Clip single-level fields we will use for mean BB calculations:
BB = BBHeight[idxpractual]
bbStatusCode = bbStatus[idxpractual]

; Now do the sweep-level arrays - have to build an array index of actual
; points, replicated over all the sweep levels
idx3d=long(gvexp)           ; copy one of the 2D arrays, make it LONG type
idx3d[*,*] = 0L             ; re-set all point values to 0
idx3d[idxpractual,0] = 1L   ; set first-sweep-level values to 1 where non-bogus

; now copy the first sweep values to the other levels, and while in the same
; loop, make the single-level arrays for categorical fields the same dimensions
; as the sweep-level by array concatenation
IF ( nswp GT 1 ) THEN BEGIN
   pr_latApp = pr_lat
   pr_lonApp = pr_lon  
   rnFlagApp = rnFlag
   rnTypeApp = rnType
   nearSurfRainApp = nearSurfRain
   nearSurfRain_2b31App = nearSurfRain_2b31
   IF nc_file_version GE 3.1 THEN BEGIN
      piaApp = pia
   ENDIF
   pr_indexApp = pr_index
   IF nc_file_version GE 2.0 THEN BEGIN
      bbStatusApp=bbStatus
      status_2a23App=status_2a23
   ENDIF
   BBHeightApp=BBHeight
   landOceanFlagApp=landOceanFlag

   FOR iswp=1, nswp-1 DO BEGIN
      idx3d[*,iswp] = idx3d[*,0]    ; copy first level values to iswp'th level
      ; concatenate another level's worth for PR Lat:
      pr_lat = [pr_lat, pr_latApp]
      pr_lon = [pr_lon, pr_lonApp]  ; ditto for PR lon
      rnFlag = [rnFlag, rnFlagApp]  ; ditto for rain flag
      rnType = [rnType, rnTypeApp]  ; ditto for rain type
      nearSurfRain = [nearSurfRain, nearSurfRainApp]  ; ditto for sfc rain
      ; ditto for PR/TMI combined sfc rain:
      nearSurfRain_2b31 = [nearSurfRain_2b31, nearSurfRain_2b31App]
      IF nc_file_version GE 3.1 THEN BEGIN
         pia = [pia, piaApp]
      ENDIF
      pr_index = [pr_index, pr_indexApp]           ; ditto for pr_index
      IF nc_file_version GE 2.0 THEN BEGIN
         bbStatus = [bbStatus, bbStatusApp]           ; ditto for bbStatus
         status_2a23 = [status_2a23, status_2a23App]  ; ditto for status_2a23
      ENDIF
      BBHeight = [BBHeight, BBHeightApp]           ; ditto for BBHeight
      landOceanFlag = [landOceanFlag, landOceanFlagApp]  ; "" landOceanFlag
   ENDFOR
ENDIF

; get the indices of all the non-bogus points in the 2D sweep-level arrays
idxpractual2d = where( idx3d EQ 1L, countactual2d )
if (countactual2d EQ 0) then begin
  ; this shouldn't be able to happen
   print, "No non-bogus 2D data points, quitting case."
   status = 1   ; set to FAILED
   goto, errorExit
endif

; clip the sweep-level arrays to the locations of actual PR footprints only
SWITCH nc_file_version OF
   3.1 : pia = pia[idxpractual2d]
   3.0 :
   2.3 : BEGIN
           gv_zdr_rej = gv_zdr_rej[idxpractual2d]
           gv_kdp_rej = gv_kdp_rej[idxpractual2d]
           gv_rhohv_rej = gv_rhohv_rej[idxpractual2d]
           gv_hid_rej = gv_hid_rej[idxpractual2d]
           gv_dzero_rej = gv_dzero_rej[idxpractual2d]
           gv_nw_rej = gv_nw_rej[idxpractual2d]
           GR_Zdr = GR_Zdr[idxpractual2d]
           GR_Kdp = GR_Kdp[idxpractual2d]
           GR_RHOhv = GR_RHOhv[idxpractual2d]
           GR_Dzero = GR_Dzero[idxpractual2d]
           GR_Nw = GR_Nw[idxpractual2d]
           GR_ZdrMax = GR_ZdrMax[idxpractual2d]
           GR_KdpMax = GR_KdpMax[idxpractual2d]
           GR_RHOhvMax = GR_RHOhvMax[idxpractual2d]
           GR_DzeroMax = GR_DzeroMax[idxpractual2d]
           GR_NwMax = GR_NwMax[idxpractual2d]
           GR_ZdrStdDev = GR_ZdrStdDev[idxpractual2d]
           GR_KdpStdDev = GR_KdpStdDev[idxpractual2d]
           GR_RHOhvStdDev = GR_RHOhvStdDev[idxpractual2d]
           GR_DzeroStdDev = GR_DzeroStdDev[idxpractual2d]
           GR_NwStdDev = GR_NwStdDev[idxpractual2d]

          ; deal with the GR_HID array with the extra dimension, and while we
          ; are here, compute HID mode at each footprint
           GR_HIDnew = intarr(mygeometa.num_HID_categories, countactual, nswp)
           mode_HID = intarr(countactual, nswp)  ; initializes to 0 (==MISSING)
           FOR hicat = 0,mygeometa.num_HID_categories-1 DO BEGIN
              GR_HIDnew[hicat,*,*] = GR_HID[hicat,idxpractual,*]
           ENDFOR
          ; if I could get IDL's MAX to work correctly, wouldn't need to do this
           FOR ifp=0,countactual-1 DO BEGIN
             FOR iswp=0, nswp-1 DO BEGIN
               ; grab the HID histogram for one footprint, minus the MISSING category
                hidhistfp=REFORM( GR_HIDnew[1:14,ifp,iswp] )
                maxhistfp=MAX(hidhistfp)  ; bin count of the most frequent category
               ; need at least one of the histogram categories to be non-zero, else
               ; this footprint is left as the Unclassified/Missing category (=0)
                IF maxhistfp GT 0 THEN BEGIN
                  ; hooray, we have an assignable hydromet category!
                   idxmodes=WHERE(hidhistfp EQ maxhistfp, modecount) ;index(es) of above
                  ; take the first category where the bin count is the same as the max,
                  ; ignoring ties between identical bin counts for other categories
                  ; - add 1 to WHERE index to get HID category number (1,2,...10)
                   IF modecount GT 0 THEN mode_HID[ifp,iswp] = idxmodes[0]+1
                ENDIF
             ENDFOR
           ENDFOR
         END
   2.2 : BEGIN
           gv_rr_rej = gv_rr_rej[idxpractual2d]
           gvrr = gvrr[idxpractual2d]
           gvrrMax = gvrrMax[idxpractual2d]
           gvrrStdDev = gvrrStdDev[idxpractual2d]
         END
   2.1 :
   2.0 : BEGIN
           gvzmax = gvzmax[idxpractual2d]
           gvzstddev = gvzstddev[idxpractual2d]
           bbStatus = bbStatus[idxpractual2d]
           status_2a23 = status_2a23[idxpractual2d]
         END
ENDSWITCH

gvexp = gvexp[idxpractual2d]
gvrej = gvrej[idxpractual2d]
prexp = prexp[idxpractual2d]
zrawrej = zrawrej[idxpractual2d]
zcorrej = zcorrej[idxpractual2d]
rainrej = rainrej[idxpractual2d]
gvz = gvz[idxpractual2d]
zraw = zraw[idxpractual2d]
zcor = zcor[idxpractual2d]
rain3 = rain3[idxpractual2d]
top = top[idxpractual2d]
botm = botm[idxpractual2d]
lat = lat[idxpractual2d]
lon = lon[idxpractual2d]
pr_lat = pr_lat[idxpractual2d]
pr_lon = pr_lon[idxpractual2d]
rnFlag = rnFlag[idxpractual2d]
rnType = rnType[idxpractual2d]
landOceanFlag = landOceanFlag[idxpractual2d]
nearSurfRain = nearSurfRain[idxpractual2d]
nearSurfRain_2b31 = nearSurfRain_2b31[idxpractual2d]
BBHeight = BBHeight[idxpractual2d]
pr_index = pr_index[idxpractual2d]

; deal with the x- and y-corner arrays with the extra dimension
xcornew = fltarr(4, countactual, nswp)
ycornew = fltarr(4, countactual, nswp)
FOR icorner = 0,3 DO BEGIN
   xcornew[icorner,*,*] = xCorner[icorner,idxpractual,*]
   ycornew[icorner,*,*] = yCorner[icorner,idxpractual,*]
ENDFOR

; - - - - - - - - - - - - - - - - - - - - - - - -

; compute percent completeness of the volume averages

IF ( N_ELEMENTS(pctAbvThresh) EQ 1 ) THEN BEGIN
   print, "======================================", $
          "======================================="
   print, "Computing Percent Above Threshold for PR", $
          " and GR Reflectivity and Rainrate."
   print, "======================================", $
          "======================================="
   pctgoodpr = fltarr( N_ELEMENTS(prexp) )
   pctgoodgv =  fltarr( N_ELEMENTS(prexp) )
   pctgoodrain = fltarr( N_ELEMENTS(prexp) )
   SWITCH nc_file_version OF
     3.1 :
     3.0 :
     2.3 : BEGIN
             pctgoodzdrgv = fltarr( N_ELEMENTS(prexp) )
             pctgoodkdpgv = fltarr( N_ELEMENTS(prexp) )
             pctgoodRHOhvgv = fltarr( N_ELEMENTS(prexp) )
             pctgoodhidgv = fltarr( N_ELEMENTS(prexp) )
             pctgooddzerogv = fltarr( N_ELEMENTS(prexp) )
             pctgoodnwgv = fltarr( N_ELEMENTS(prexp) )
           END
     2.2 : pctgoodrrgv = fltarr( N_ELEMENTS(prexp) )
   ENDSWITCH
   idxexpgt0 = WHERE( prexp GT 0 AND gvexp GT 0, countexpgt0 )
   IF ( countexpgt0 EQ 0 ) THEN BEGIN
      print, "No valid volume-average points, quitting case."
      status = 1
      goto, errorExit
   ENDIF ELSE BEGIN
      pctgoodpr[idxexpgt0] = $
         100.0 * FLOAT( prexp[idxexpgt0]-zcorrej[idxexpgt0] ) / prexp[idxexpgt0]
      pctgoodgv[idxexpgt0] = $
         100.0 * FLOAT( gvexp[idxexpgt0]-gvrej[idxexpgt0] ) / gvexp[idxexpgt0]
      pctgoodrain[idxexpgt0] = $
         100.0 * FLOAT( prexp[idxexpgt0]-rainrej[idxexpgt0] ) / prexp[idxexpgt0]
      SWITCH nc_file_version OF
        3.1 :
        3.0 :
        2.3 : BEGIN
                pctgoodzdrgv[idxexpgt0] = 100.0 * FLOAT( gvexp[idxexpgt0] $
                   - gv_zdr_rej[idxexpgt0] ) / gvexp[idxexpgt0]
                pctgoodkdpgv[idxexpgt0] = 100.0 * FLOAT( gvexp[idxexpgt0] $
                   - gv_kdp_rej[idxexpgt0] ) / gvexp[idxexpgt0]
                pctgoodRHOhvgv[idxexpgt0] = 100.0 * FLOAT( gvexp[idxexpgt0] $
                   - gv_RHOhv_rej[idxexpgt0] ) / gvexp[idxexpgt0]
                pctgoodhidgv[idxexpgt0] = 100.0 * FLOAT( gvexp[idxexpgt0] $
                   - gv_hid_rej[idxexpgt0] ) / gvexp[idxexpgt0]
                pctgooddzerogv[idxexpgt0] = 100.0 * FLOAT( gvexp[idxexpgt0] $
                   - gv_dzero_rej[idxexpgt0] ) / gvexp[idxexpgt0]
                pctgoodnwgv[idxexpgt0] = 100.0 * FLOAT( gvexp[idxexpgt0] $
                   - gv_nw_rej[idxexpgt0] ) / gvexp[idxexpgt0]
              END
        2.2 : pctgoodrrgv[idxexpgt0] = 100.0 * FLOAT( gvexp[idxexpgt0] $
                   - gv_rr_rej[idxexpgt0] ) / gvexp[idxexpgt0]
      ENDSWITCH
   ENDELSE
ENDIF

; - - - - - - - - - - - - - - - - - - - - - - - -

; restore the subsetted arrays to two dimensions of (PRfootprints, GRsweeps)
SWITCH nc_file_version OF
   3.1 : pia = REFORM( pia, countactual, nswp )
   3.0 :
   2.3 : BEGIN
           GR_Zdr = REFORM( GR_Zdr, countactual, nswp )
           GR_Kdp = REFORM( GR_Kdp, countactual, nswp )
           GR_RHOhv = REFORM( GR_RHOhv, countactual, nswp )
           GR_Dzero = REFORM( GR_Dzero, countactual, nswp )
           GR_Nw = REFORM( GR_Nw, countactual, nswp )
           GR_ZdrMax = REFORM( GR_ZdrMax, countactual, nswp )
           GR_KdpMax = REFORM( GR_KdpMax, countactual, nswp )
           GR_RHOhvMax = REFORM( GR_RHOhvMax, countactual, nswp )
           GR_DzeroMax = REFORM( GR_DzeroMax, countactual, nswp )
           GR_NwMax = REFORM( GR_NwMax, countactual, nswp )
           GR_ZdrStdDev = REFORM( GR_ZdrStdDev, countactual, nswp )
           GR_KdpStdDev = REFORM( GR_KdpStdDev, countactual, nswp )
           GR_RHOhvStdDev = REFORM( GR_RHOhvStdDev, countactual, nswp )
           GR_DzeroStdDev = REFORM( GR_DzeroStdDev, countactual, nswp )
           GR_NwStdDev = REFORM( GR_NwStdDev, countactual, nswp )
           IF ( N_ELEMENTS(pctAbvThresh) EQ 1 ) THEN BEGIN
              pctgoodzdrgv = REFORM( pctgoodzdrgv, countactual, nswp )
              pctgoodkdpgv = REFORM( pctgoodkdpgv, countactual, nswp )
              pctgoodRHOhvgv = REFORM( pctgoodRHOhvgv, countactual, nswp )
              pctgoodhidgv = REFORM( pctgoodhidgv, countactual, nswp )
              pctgooddzerogv = REFORM( pctgooddzerogv, countactual, nswp )
              pctgoodnwgv = REFORM( pctgoodnwgv, countactual, nswp )
           ENDIF
         END
   2.2 : BEGIN
           gvrr = REFORM( gvrr, countactual, nswp )
           gvrrMax = REFORM( gvrrmax, countactual, nswp )
           gvrrStdDev = REFORM( gvrrstddev, countactual, nswp )
           IF ( N_ELEMENTS(pctAbvThresh) EQ 1 ) THEN $
              pctgoodrrgv = REFORM( pctgoodrrgv, countactual, nswp )
         END
   2.1 :
   2.0 : BEGIN
           gvzmax = REFORM( gvzmax, countactual, nswp )
           gvzstddev = REFORM( gvzstddev, countactual, nswp )
           bbStatus = REFORM( bbStatus, countactual, nswp )
           status_2a23 = REFORM( status_2a23, countactual, nswp )
         END
ENDSWITCH
gvz = REFORM( gvz, countactual, nswp )
zraw = REFORM( zraw, countactual, nswp )
zcor = REFORM( zcor, countactual, nswp )
rain3 = REFORM( rain3, countactual, nswp )
top = REFORM( top, countactual, nswp )
botm = REFORM( botm, countactual, nswp )
lat = REFORM( lat, countactual, nswp )
lon = REFORM( lon, countactual, nswp )
pr_lat = REFORM( pr_lat, countactual, nswp )
pr_lon = REFORM( pr_lon, countactual, nswp )
rnFlag = REFORM( rnFlag, countactual, nswp )
rnType = REFORM( rnType, countactual, nswp )
landOceanFlag = REFORM( landOceanFlag, countactual, nswp )
nearSurfRain = REFORM( nearSurfRain, countactual, nswp )
nearSurfRain_2b31 = REFORM( nearSurfRain_2b31, countactual, nswp )
pr_index = REFORM( pr_index, countactual, nswp )
BBHeight = REFORM( BBHeight, countactual, nswp )
IF ( N_ELEMENTS(pctAbvThresh) EQ 1 ) THEN BEGIN
   pctgoodpr = REFORM( pctgoodpr, countactual, nswp )
   pctgoodgv =  REFORM( pctgoodgv, countactual, nswp )
   pctgoodrain = REFORM( pctgoodrain, countactual, nswp )
ENDIF

; - - - - - - - - - - - - - - - - - - - - - - - -

; For each 'column' of data, find the maximum GV reflectivity value for the
;  footprint, and use this to define a GV match to the PR-indicated rain type.
;  Using Default GV dBZ thresholds of >=35 for "GV Convective" and <=25 for 
;  "GV Stratiform", or other GV dBZ thresholds provided as user parameters,
;  set PR rain type to "other" (=3) where PR type is Convective and GV isn't, or
;  PR is Stratiform and GV indicates Convective.  For GV reflectivities between
;  'gvstratiform' and 'gvconvective' thresholds, leave the PR rain type as-is.

print, ''
max_gvz_per_fp = MAX( gvz, DIMENSION=2)
IF ( gvstratiform GT 0.0 ) THEN BEGIN
   idx2other = WHERE( rnType[*,0] EQ 2 AND max_gvz_per_fp LE gvstratiform, $
                      count2other )
   IF ( count2other GT 0 ) THEN BEGIN  ;rnType[idx2other,*] = 3
      FOR ilev=0, nswp-1 DO BEGIN
         rnType[idx2other,ilev] = 3
      ENDFOR
   ENDIF
   fmtstrng='("No. of footprints switched from Convective to Other = ",I0,",' $
            +' based on Stratiform dBZ threshold = ",F0.1)'
   print, FORMAT=fmtstrng, count2other, gvstratiform
ENDIF ELSE BEGIN
   print, "Leaving PR Convective Rain Type assignments unchanged."
ENDELSE
IF ( gvconvective GT 0.0 ) THEN BEGIN
   idx2other = WHERE( rnType[*,0] EQ 1 AND max_gvz_per_fp GE gvconvective, $
                      count2other )
   IF ( count2other GT 0 ) THEN BEGIN
      FOR ilev=0, nswp-1 DO BEGIN
         rnType[idx2other,ilev] = 3
      ENDFOR
   ENDIF
   fmtstrng='("No. of footprints switched from Stratiform to Other = ",I0,",' $
            +' based on Convective dBZ threshold = ",F0.1)'
   print, FORMAT=fmtstrng, count2other, gvconvective
ENDIF ELSE BEGIN
   print, "Leaving PR Stratiform Rain Type assignments unchanged."
ENDELSE

; - - - - - - - - - - - - - - - - - - - - - - - -

IF ( N_ELEMENTS(heights) EQ 0 ) THEN BEGIN
   print, "In fprep_geo_match_profiles(): assigning 13 default height ", $
          "levels, 1.5-19.5km"
   heights = [1.5,3.0,4.5,6.0,7.5,9.0,10.5,12.0,13.5,15.0,16.5,18.0,19.5]
ENDIF
halfdepth=(heights[1]-heights[0])/2.0

; convert bright band heights from m to km, where defined, and get mean BB hgt.
; - first, find the indices of stratiform rays with BB defined

idxbbdef = where(bb GT 0.0 AND rnType[*,0] EQ 1, countBB)
IF ( countBB GT 0 ) THEN BEGIN
  ; grab the subset of BB values for defined/stratiform
   bb2hist = bb[idxbbdef]/1000.  ; with conversion to km

   bs=0.2  ; bin width, in km, for HISTOGRAM in get_mean_bb_height()
;   hist_window = 9  ; uncomment to plot BB histogram and print diagnostics

  ; - now, do some sorcery to find the best mean BB height estimate, in km
;print, "myflags.have_BBstatus: ", myflags.have_BBstatus
   IF myflags.have_BBstatus EQ 1 THEN BEGIN
     ; try to get mean BB using BBstatus of 'good' or 'fair'
      bbstatusstrat = bbStatusCode[idxbbdef]
      meanbb_MSL = get_mean_bb_height( bb2hist, bbstatusstrat, BS=bs, $
                                       HIST_WINDOW=hist_window )
   ENDIF ELSE BEGIN
     ; use histogram analysis of BB heights to get mean height
      meanbb_MSL = get_mean_bb_height( bb2hist, BS=bs, HIST_WINDOW=hist_window )
   ENDELSE
ENDIF ELSE BEGIN
   meanbb_MSL = -99.99
   meanbb = -99.99
   IF N_ELEMENTS(alt_bb_hgt) NE 1 THEN BEGIN
      message, "No valid bright band heights for case, "+ $
               "unable to populate bbparms structure.", /INFO
      IF keyword_set(bb_relative) THEN BEGIN
         message, "BB_RELATIVE option requested but cannot compute "+ $
                  "BB-relative heights, quitting.", /INFO
         status = 1   ; set to FAILED
         goto, errorExit
      ENDIF
   ENDIF ELSE BEGIN
     ; see if we can assign meanBB via the alt_bb_hgt parameter
      message, "Using ALT_BB_HGT value to assign mean BB height.", /info
      sz_alt_bb = FIX( SIZE(alt_bb_hgt, /TYPE) )
      SWITCH sz_alt_bb OF
         1 :
         2 :
         3 :
         4 :
         5 : BEGIN
                meanbb_MSL = FLOAT(alt_bb_hgt)
                BREAK
             END
         7 : BEGIN
                IF FILE_TEST( alt_bb_hgt, /READ ) EQ 1 THEN BEGIN
                   parsed = STRSPLIT(FILE_BASENAME(ncfilepr), '.', /extract )
                   orbit = parsed[3]
                   ; try to get the mean BB for this case from the alt_bb_hgt
                   ; file, using input value of meanbb in bbparms structure as
                   ; the default missing value if it fails to find a match
                   meanbb_MSL = get_ruc_bb( alt_bb_hgt, siteID, orbit, $
                                            MISSING=-99.99, /VERBOSE )
                ENDIF ELSE BEGIN
                   ; check whether we were suppied a number as a string, 
                   ; and if so, convert it to float and use the value
                   IF is_a_number(alt_bb_hgt) THEN BEGIN
                      message, "Converting alt_bb_hgt string '" + alt_bb_hgt + $
                               "' to numerical value", /INFO
                      meanbb_MSL=FLOAT(alt_bb_hgt[0])   ; take first value if array
                   ENDIF ELSE BEGIN
                      print, ''
                      message, "Cannot find/read/convert alt_bb_hgt: "+alt_bb_hgt, /INFO
                      print, ''
                   ENDELSE
                ENDELSE
                BREAK
             END
         ELSE : BEGIN
                print, ''
                message, "Illegal type for alt_bb_hgt:", /INFO
                help, alt_bb_hgt
                print, ''
             END
      ENDSWITCH
      IF keyword_set(bb_relative) AND meanbb_MSL LE -99.9 THEN BEGIN
         message, "BB_RELATIVE option requested but cannot compute "+ $
                  "BB-relative heights, quitting.", /INFO
         status = 1   ; set to FAILED
         goto, errorExit
      ENDIF
   ENDELSE
ENDELSE

IF meanbb_MSL GT 0.0 THEN BEGIN
  ; BB height in netCDF file is height above MSL -- must adjust mean BB to
  ; height above ground level for comparison to "heights"
   meanbb = meanbb_MSL - site_elev

   IF keyword_set(bb_relative) THEN BEGIN
     ; level affected by BB is simply the zero-height BB-relative layer
      idxBB_HgtHi = WHERE( heights EQ 0.0, nbbzero)
      IF nbbzero EQ 1 THEN BEGIN
         BB_HgtHi = idxBB_HgtHi
         BB_HgtLo = BB_HgtHi
      ENDIF ELSE BEGIN
         message, "ERROR assigning BB-affected layer number.", /INFO
;         status = 1   ; set to FAILED
;         goto, errorExit
      ENDELSE
   ENDIF ELSE BEGIN
     ; Level below BB is affected if layer top is 500m (0.5 km) or less below
     ; BB_Hgt, so BB_HgtLo is index of lowest fixed-height layer considered to
     ; be within the BB (see 'heights' array and halfdepth, above)
      idxbelowbb = WHERE( (heights+halfdepth) LT (meanbb-0.5), countbelowbb )
      if (countbelowbb GT 0) then $
           BB_HgtLo = (MAX(idxbelowbb) + 1) < (N_ELEMENTS(heights)-1) $
      else BB_HgtLo = 0
     ; Level above BB is affected if BB_Hgt is 500m (0.5 km) or less below layer
     ; bottom, so BB_HgtHi is highest fixed-height layer considered to be within
     ; the BB
      idxabvbb = WHERE( (heights-halfdepth) GT (meanbb+0.5), countabvbb )
      if (countabvbb GT 0) THEN BB_HgtHi = (MIN(idxabvbb) - 1) > 0 $
      else if (meanbb GE (heights(N_ELEMENTS(heights)-1)-halfdepth) ) then $
      BB_HgtHi = (N_ELEMENTS(heights)-1) else BB_HgtHi = 0
   ENDELSE

   IF (N_ELEMENTS(bbparms) EQ 1) THEN BEGIN
      bbparms.meanbb = meanbb
      bbparms.BB_HgtLo = BB_HgtLo < BB_HgtHi
      bbparms.BB_HgtHi = BB_HgtHi > BB_HgtLo
      print, 'Mean BB (km AGL), bblo, bbhi = ', meanbb, heights[0]+halfdepth*2*bbparms.BB_HgtLo, $
             heights[0]+halfdepth*2*bbparms.BB_HgtHi
   ENDIF
ENDIF

; - - - - - - - - - - - - - - - - - - - - - - - -

; build an array of sample point ranges from the GV radar
; via map projection x,y coordinates computed from lat and lon:

; initialize a gv-centered map projection for the ll<->xy transformations:
sMap = MAP_PROJ_INIT( 'Azimuthal Equidistant', center_latitude=site_lat, $
                      center_longitude=site_lon )
XY_km = map_proj_forward( lon, lat, map_structure=smap ) / 1000.
dist = SQRT( XY_km[0,*]^2 + XY_km[1,*]^2 )
dist = REFORM( dist, countactual, nswp )

; - - - - - - - - - - - - - - - - - - - - - - - -

; build an array of height category for the fixed-height levels, for profiles

hgtcat = rnType   ; for a starter
hgtcat[*] = -99   ; re-initialize to -99
beamhgt = botm    ; for a starter, to build array of center of beam
nhgtcats = N_ELEMENTS(heights)
num_in_hgt_cat = LONARR( nhgtcats )
idxhgtdef = where( botm GT halfdepth AND top GT halfdepth, counthgtdef )
IF ( counthgtdef GT 0 ) THEN BEGIN
   IF keyword_set(bb_relative) THEN $
      beamhgt[idxhgtdef] = (top[idxhgtdef]+botm[idxhgtdef])/2 - meanbb + 6.0 $
   ELSE beamhgt[idxhgtdef] = (top[idxhgtdef]+botm[idxhgtdef])/2
   hgtcat[idxhgtdef] = FIX((beamhgt[idxhgtdef]-halfdepth)/(halfdepth*2.0))
  ; deal with points that are too low or too high with respect to the
  ; height layers that have been defined
   idx2low = where( beamhgt[idxhgtdef] LT halfdepth, n2low )
   if n2low GT 0 then hgtcat[idxhgtdef[idx2low]] = -1
   idx2high = where( beamhgt[idxhgtdef] GT (heights[nhgtcats-1]+halfdepth), $
                     n2high )
   if n2high GT 0 then hgtcat[idxhgtdef[idx2high]] = -1
ENDIF ELSE BEGIN
   print, "No valid beam heights, quitting case."
   status = 1   ; set to FAILED
   goto, errorExit
ENDELSE

;print, (top[idxhgtdef]+botm[idxhgtdef])/2 - meanbb, heights[hgtcat[idxhgtdef]]

; build an array of proximity to the bright band: above=3, within=2, below=1
; -- define above (below) BB as bottom (top) of beam at least 0.750 km above
;    (0.750 kmm below) mean BB height (by default), or "bbwidth" km above/below
;    if BBWIDTH is specified

IF ( N_ELEMENTS(bbwidth) NE 1 ) THEN BEGIN
   bbwidth=0.750
ENDIF ELSE BEGIN
   IF bbwidth GE 100.0 THEN BEGIN
      print, "In fprep_geo_match_profiles, assuming meters for bbwidth value", $
             " provided: ", bbwidth, ", converting to km."
      bbwidth = bbwidth/1000.0
   ENDIF
   IF bbwidth GT 2.0 OR bbwidth LT 0.2 THEN BEGIN
      print, "In fprep_geo_match_profiles, overriding outlier bbwidth value:", $
              bbwidth, " km to 0.750 km"
      bbwidth=0.750
   ENDIF
ENDELSE

bbProx = rnType   ; for a starter
bbProx[*] = 0  ; re-init to Not Defined, leave this way if meanBB is Unknown
countabv = 0   ; init to Not Defined
countblo = 0   ; ditto
countin = 0    ; ditto
IF ( meanBB GT 0.0 ) THEN BEGIN
   num_in_BB_Cat = LONARR(4)
   idxabv = WHERE( botm GT (meanbb+bbwidth), countabv )
   num_in_BB_Cat[3] = countabv
   IF countabv GT 0 THEN bbProx[idxabv] = 3
   idxblo = WHERE( top LT (meanbb-bbwidth), countblo )
   num_in_BB_Cat[1] = countblo
   IF countblo GT 0 THEN bbProx[idxblo] = 1
   idxin = WHERE( (botm LE (meanbb+bbwidth)) AND (top GE (meanbb-bbwidth)), countin )
   num_in_BB_Cat[2] = countin
   IF countin GT 0 THEN bbProx[idxin] = 2
ENDIF

; - - - - - - - - - - - - - - - - - - - - - - - -

; apply the S-to-Ku band adjustment if parameter s2ku is set

IF ( s2ku ) THEN BEGIN
   print, "=================================================================="
   print, "Applying rain/snow adjustments to S-band to match Ku reflectivity."
   print, "=================================================================="
   IF countabv GT 0 THEN BEGIN
     ; grab the above-bb points of the GV reflectivity
      gvz4snow = gvz[idxabv]
     ; find those points with non-missing reflectivity values
      idx2ku = WHERE( gvz4snow GT 0.0, count2ku )
      IF count2ku GT 0 THEN BEGIN
        ; perform the conversion and replace the original values
         gvz[idxabv[idx2ku]] = s_band_to_ku_band( gvz4snow[idx2ku], 'S' )
      ENDIF ELSE print, "No above-BB points for S-to-Ku snow correction"
   ENDIF
   IF countblo GT 0 THEN BEGIN
      gvz4rain = gvz[idxblo]
      idx2ku = WHERE( gvz4rain GT 0.0, count2ku )
      IF count2ku GT 0 THEN BEGIN
         gvz[idxblo[idx2ku]] = s_band_to_ku_band( gvz4rain[idx2ku], 'R' )
      ENDIF ELSE print, "No below-BB points for S-to-Ku rain correction"
   ENDIF
ENDIF

; - - - - - - - - - - - - - - - - - - - - - - - -

; assign pointer variables provided as optional keyword parameters, as provided
; - try to assign pointers only for variables present in a given matchup version

SWITCH nc_file_version OF
   3.1 : IF PTR_VALID(ptr_pia) THEN *ptr_pia = pia
   3.0 :
   2.3 : BEGIN
           IF PTR_VALID(ptr_GR_Zdr) THEN *ptr_GR_Zdr = GR_Zdr
           IF PTR_VALID(ptr_GR_Kdp) THEN *ptr_GR_Kdp = GR_Kdp
           IF PTR_VALID(ptr_GR_RHOhv) THEN *ptr_GR_RHOhv = GR_RHOhv
           IF PTR_VALID(ptr_GR_Dzero) THEN *ptr_GR_Dzero = GR_Dzero
           IF PTR_VALID(ptr_GR_Nw) THEN *ptr_GR_Nw = GR_Nw
           IF PTR_VALID(ptr_GR_ZdrMax) THEN *ptr_GR_ZdrMax = GR_ZdrMax
           IF PTR_VALID(ptr_GR_KdpMax) THEN *ptr_GR_KdpMax = GR_KdpMax
           IF PTR_VALID(ptr_GR_RHOhvMax) THEN *ptr_GR_RHOhvMax = GR_RHOhvMax
           IF PTR_VALID(ptr_GR_DzeroMax) THEN *ptr_GR_DzeroMax = GR_DzeroMax
           IF PTR_VALID(ptr_GR_NwMax) THEN *ptr_GR_NwMax = GR_NwMax
           IF PTR_VALID(ptr_GR_ZdrStdDev) THEN *ptr_GR_ZdrStdDev = GR_ZdrStdDev
           IF PTR_VALID(ptr_GR_KdpStdDev) THEN *ptr_GR_KdpStdDev = GR_KdpStdDev
           IF PTR_VALID(ptr_GR_RHOhvStdDev) THEN *ptr_GR_RHOhvStdDev = GR_RHOhvStdDev
           IF PTR_VALID(ptr_GR_DzeroStdDev) THEN *ptr_GR_DzeroStdDev = GR_DzeroStdDev
           IF PTR_VALID(ptr_GR_NwStdDev) THEN *ptr_GR_NwStdDev = GR_NwStdDev
           IF PTR_VALID(ptr_GR_HID) THEN *ptr_GR_HID = GR_HIDnew
           IF PTR_VALID(ptr_mode_HID) THEN *ptr_mode_HID = mode_HID
           IF ( N_ELEMENTS(pctAbvThresh) EQ 1 ) THEN BEGIN
              IF PTR_VALID(ptr_pctgoodzdrgv) THEN *ptr_pctgoodzdrgv = pctgoodzdrgv
              IF PTR_VALID(ptr_pctgoodkdpgv) THEN *ptr_pctgoodkdpgv = pctgoodkdpgv
              IF PTR_VALID(ptr_pctgoodRHOhvgv) THEN *ptr_pctgoodRHOhvgv = pctgoodRHOhvgv
              IF PTR_VALID(ptr_pctgoodhidgv) THEN *ptr_pctgoodhidgv = pctgoodhidgv
              IF PTR_VALID(ptr_pctgooddzerogv) THEN *ptr_pctgooddzerogv = pctgooddzerogv
              IF PTR_VALID(ptr_pctgoodnwgv) THEN *ptr_pctgoodnwgv = pctgoodnwgv
           ENDIF
         END
   2.2 : BEGIN
           IF PTR_VALID(ptr_gvrr) THEN *ptr_gvrr = gvrr
           IF PTR_VALID(ptr_gvrrmax) THEN *ptr_gvrrmax = gvrrmax
           IF PTR_VALID(ptr_gvrrstddev) THEN *ptr_gvrrstddev = gvrrstddev
           IF ( N_ELEMENTS(pctAbvThresh) EQ 1 AND PTR_VALID(ptr_pctgoodrrgv ) ) $
              THEN *ptr_pctgoodrrgv = pctgoodrrgv
         END
   2.1 :
   2.0 : BEGIN
           IF PTR_VALID(ptr_bbstatus) THEN *ptr_bbstatus = bbStatus
           IF PTR_VALID(ptr_status_2a23) THEN *ptr_status_2a23 = status_2a23
           IF PTR_VALID(ptr_gvzmax) THEN *ptr_gvzmax = gvzmax
           IF PTR_VALID(ptr_gvzstddev) THEN *ptr_gvzstddev = gvzstddev
         END
ENDSWITCH

IF PTR_VALID(ptr_geometa) THEN *ptr_geometa = mygeometa
IF PTR_VALID(ptr_sweepmeta) THEN *ptr_sweepmeta = mysweeps
IF PTR_VALID(ptr_sitemeta) THEN *ptr_sitemeta = mysite
IF PTR_VALID(ptr_fieldflags) THEN *ptr_fieldflags = myflags
IF PTR_VALID(ptr_filesmeta) THEN *ptr_filesmeta = myfiles
IF PTR_VALID(ptr_gvz) THEN *ptr_gvz = gvz
IF PTR_VALID(ptr_zraw) THEN *ptr_zraw = zraw
IF PTR_VALID(ptr_zcor) THEN *ptr_zcor = zcor
IF PTR_VALID(ptr_rain3) THEN *ptr_rain3 = rain3
IF PTR_VALID(ptr_top) THEN *ptr_top = top
IF PTR_VALID(ptr_botm) THEN *ptr_botm = botm
IF PTR_VALID(ptr_lat) THEN *ptr_lat = lat
IF PTR_VALID(ptr_lon) THEN *ptr_lon = lon
IF PTR_VALID(ptr_pr_lat) THEN *ptr_pr_lat = pr_lat
IF PTR_VALID(ptr_pr_lon) THEN *ptr_pr_lon = pr_lon
IF PTR_VALID(ptr_nearSurfRain) THEN *ptr_nearSurfRain = nearSurfRain
IF PTR_VALID(ptr_nearSurfRain_2b31) THEN $
    *ptr_nearSurfRain_2b31 = nearSurfRain_2b31
IF PTR_VALID(ptr_rnFlag) THEN *ptr_rnFlag = rnFlag
IF PTR_VALID(ptr_rnType) THEN *ptr_rnType = rnType
IF PTR_VALID(ptr_landOcean) THEN *ptr_landOcean = landOceanFlag
IF PTR_VALID(ptr_bbHeight) THEN *ptr_bbHeight =bbHeight
IF PTR_VALID(ptr_pr_index) THEN *ptr_pr_index = pr_index
IF PTR_VALID(ptr_bbProx) THEN *ptr_bbProx = bbProx
IF PTR_VALID(ptr_hgtcat) THEN *ptr_hgtcat = hgtcat
IF PTR_VALID(ptr_dist) THEN *ptr_dist = dist
IF PTR_VALID(ptr_xCorner) THEN *ptr_xCorner = xcornew
IF PTR_VALID(ptr_yCorner) THEN *ptr_yCorner = ycornew

IF ( N_ELEMENTS(pctAbvThresh) EQ 1 ) THEN BEGIN
   IF PTR_VALID(ptr_pctgoodpr) THEN *ptr_pctgoodpr = pctgoodpr
   IF PTR_VALID(ptr_pctgoodgv) THEN *ptr_pctgoodgv = pctgoodgv
   IF PTR_VALID(ptr_pctgoodrain) THEN *ptr_pctgoodrain = pctgoodrain
ENDIF

; free any valid pointers for variables not defined in a given file version
; so that the caller knows that the requested data are not present by
; checking the passed pointer via ptr_valid()

SWITCH nc_file_version OF
   1.0 : BEGIN
           IF PTR_VALID(ptr_bbstatus) THEN ptr_free, ptr_bbstatus
           IF PTR_VALID(ptr_status_2a23) THEN ptr_free, ptr_status_2a23
           IF PTR_VALID(ptr_gvzmax) THEN ptr_free, ptr_gvzmax
           IF PTR_VALID(ptr_gvzstddev) THEN ptr_free, ptr_gvzstddev
         END
   2.0 :
   2.1 : BEGIN
           IF PTR_VALID(ptr_gvrr) THEN ptr_free, ptr_gvrr
           IF PTR_VALID(ptr_gvrrmax) THEN ptr_free, ptr_gvrrmax
           IF PTR_VALID(ptr_gvrrstddev) THEN ptr_free, ptr_gvrrstddev
           IF PTR_VALID(ptr_pctgoodrrgv) THEN ptr_free, ptr_pctgoodrrgv
         END
   2.2 : BEGIN
           IF PTR_VALID(ptr_GR_Zdr) THEN ptr_free, ptr_GR_Zdr
           IF PTR_VALID(ptr_GR_ZdrMax) THEN ptr_free, ptr_GR_ZdrMax
           IF PTR_VALID(ptr_GR_ZdrStdDev) THEN ptr_free, ptr_GR_ZdrStdDev
           IF PTR_VALID(ptr_GR_Kdp) THEN ptr_free, ptr_GR_Kdp
           IF PTR_VALID(ptr_GR_KdpMax) THEN ptr_free, ptr_GR_KdpMax
           IF PTR_VALID(ptr_GR_KdpStdDev) THEN ptr_free, ptr_GR_KdpStdDev
           IF PTR_VALID(ptr_GR_RHOhv) THEN ptr_free, ptr_GR_RHOhv
           IF PTR_VALID(ptr_GR_RHOhvMax) THEN ptr_free, ptr_GR_RHOhvMax
           IF PTR_VALID(ptr_GR_RHOhvStdDev) THEN ptr_free, ptr_GR_RHOhvStdDev
           IF PTR_VALID(ptr_GR_Dzero) THEN ptr_free, ptr_GR_Dzero
           IF PTR_VALID(ptr_GR_DzeroMax) THEN ptr_free, ptr_GR_DzeroMax
           IF PTR_VALID(ptr_GR_DzeroStdDev) THEN ptr_free, ptr_GR_DzeroStdDev
           IF PTR_VALID(ptr_GR_Nw) THEN ptr_free, ptr_GR_Nw
           IF PTR_VALID(ptr_GR_NwMax) THEN ptr_free, ptr_GR_NwMax
           IF PTR_VALID(ptr_GR_NwStdDev) THEN ptr_free, ptr_GR_NwStdDev
           IF PTR_VALID(ptr_GR_HID) THEN ptr_free, ptr_GR_HID
           IF PTR_VALID(ptr_pctgoodzdrgv) THEN ptr_free, ptr_pctgoodzdrgv
           IF PTR_VALID(ptr_pctgoodkdpgv) THEN ptr_free, ptr_pctgoodkdpgv
           IF PTR_VALID(ptr_pctgoodRHOhvgv) THEN ptr_free, ptr_pctgoodRHOhvgv
           IF PTR_VALID(ptr_mode_HID) THEN ptr_free, ptr_mode_HID
           IF PTR_VALID(ptr_pctgoodhidgv) THEN ptr_free, ptr_pctgoodhidgv
           IF PTR_VALID(ptr_pctgooddzerogv) THEN ptr_free, ptr_pctgooddzerogv
           IF PTR_VALID(ptr_pctgoodnwgv) THEN ptr_free, ptr_pctgoodnwgv
         END
   2.3 :
   3.0 : IF PTR_VALID(ptr_pia) THEN ptr_free, ptr_pia
ENDSWITCH

status = 0   ; set to SUCCESS

errorExit:

return, status
END
