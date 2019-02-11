;===============================================================================
;+
; Copyright © 2015, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; fprep_dprgmi_geo_match_profiles_mrms.pro
; - Morris/SAIC/GPM_GV  June 2015
;
; DESCRIPTION
; -----------
; Reads DPR and GR reflectivity, DPRGMI rain rate, and spatial fields for a
; specified swath type (MS or NS) from a selected DPRGMI combined geo_match
; netCDF file, builds index arrays of categories of range, rain type, bright
; band proximity (above, below, within), and an array of actual range. Single-
; level arrays (pr_index, rainType, etc.) are replicated to the same number of
; levels/dimensions as the sweep-level variables (DPR and GR reflectivity etc.).
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
; The ALT_BB_HGT keyword allows the caller to provide either a single numerical
; value specifying the mean bright band height to be used, or a file of
; precomputed freezing level heights to be searched to find the BB height for
; the current site and orbit, since the mean BB height cannot be determined
; with no BB field values present in the DPRGMI data.  If a BB height can be
; determined from the ALT_BB_HGT value, then the array index of the highest and
; lowest fixed-height level affected by the bright band will be computed, and
; if the BBPARMS keyword is set, these values will be returned in the 'bbparms'
; structure supplied as the formal parameter.  See the code for rules on how
; fixed-height layers affected by the bright band are determined.  It is
; up to the caller to properly create and initialize the bbparms structure to be
; passed as the BBPARMS keyword parameter, as in the following example:
;
; bbparms = {meanBB : -99.99, BB_HgtLo : -99, BB_HgtHi : -99}
;
;
; If the pctAbvThresh parameter is specified, then the function will also
; compute 4 arrays holding the percentage of raw bins included in the volume
; average whose physical values were at/above the fixed thresholds for:
;
; 1) DPR reflectivity (18 dBZ, or as defined in the geo_match netcdf file)
; 2) GR reflectivity (15 dBZ, or as defined in the geo_match netcdf file)
; 3) GR rainrate (0.01 mm/h, or as defined in the geo_match netcdf file).
;
; These 3 thresholds are available in the "mygeometa" variable, a structure
; of type "geo_match_meta" (see dpr_geo_match_nc_structs.inc), populated in
; the call to read_dpr_geo_match_netcdf(), in the structure variables
; DPR_dBZ_min, GR_dBZ_min, and rain_min, respectively.
;
; If s2ku binary parameter is set, then the Liao/Meneghini S-to-Ku band
; reflectivity adjustment will be made to the volume-matched ground radar
; reflectivity field, gvz.
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
;                to be of Stratiform Rain Type.  Default = 25.0 if not specified.
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
; bb_relative  - Binary parameter, controls whether or not to compute height
;                categories that are relative to the mean BB height (km above
;                or below) or relative to the earth surface (km above).
;                Default = no (Earth-surface-relative)
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
; forcebb      - Binary keyword.  If set, and if alt_bb_height is specified and a
;                valid value for the mean BB height is provided or can be located
;                in the file, then this BB height value will override any mean BB
;                height determined from the DPR data.
;
; ray_range    - A 2-element INTEGER array specifying a range of ray numbers to
;                clip the data arrays to.  If the first value is less than or
;                equal to the second value, then the ray numbers between these
;                two values will be returned.  If the first value is greater
;                than the second, then an "outer clip" will be done, with ray
;                numbers between 0 and the smaller ray_range value, and ray
;                numbers between the larger ray_range value out to the last ray
;                number in the swath type.
;
; (pointers)   - Optional keywords consisting of unassigned pointers created by
;                the calling routine.  These pointers are assigned to their
;                namesake DATA FIELDS at the end of the routine, as follows:
; 
; At the end of the procedure, the following data fields will be available
; to be returned to the caller.  If a pointer for the variable is provided
; in the parameter list, the pointer will be assigned to the variable.  Pointers
; passed as arguments should be unassigned pointers to an undefined variable,
; i.e., a heap pointer created as follows: thePointer=ptr_new(/allocate_heap).
; If no pointer is supplied for the keyword, then the corresponding data
; variable goes out of scope when this function returns to the caller, and the
; data field will be unavailable.
;
; mygeometa           structure holding dimension, version, and threshold
;                       information for the matchup data
; mysweeps            structure holding GR volume info - sweep elevations etc.
; mysite              structure holding GR location, station ID, etc.
; myflags             structure holding flags indicating whether data fields are
;                        good, or just fill values
; myfiles             structure holding the names of the input PR and GR files
;                        used in the matchup
;
; gvz                 subsetted array of volume-matched GR mean reflectivity
; gvzmax              subsetted array of volume-matched GR maximum reflectivity
; gvzstddev           subsetted array of volume-matched GR reflectivity standard
;                        deviation
;
; gvrc                subsetted array of volume-matched GR 3D mean RC rainrate
; gvrcmax             subsetted array of volume-matched GR 3D max. RC rainrate
; gvrcstddev          subsetted array of volume-matched GR 3D RC rainrate
;                        standard deviation
;
; gvrp                subsetted array of volume-matched GR 3D mean RP rainrate
; gvrpmax             subsetted array of volume-matched GR 3D max. RP rainrate
; gvrpstddev          subsetted array of volume-matched GR 3D RP rainrate
;                        standard deviation
;
; gvrr                subsetted array of volume-matched GR 3D mean RR rainrate
; gvrrmax             subsetted array of volume-matched GR 3D max. RR rainrate
; gvrrstddev          subsetted array of volume-matched GR 3D RR rainrate
;                        standard deviation
;
; GR_DP_Zdr           subsetted array of volume-matched GR mean Zdr
;                        (differential reflectivity)
; GR_DP_ZdrMax        As above, but sample maximum of Zdr
; GR_DP_ZdrStdDev     As above, but sample standard deviation of Zdr
;
; GR_DP_Kdp           subsetted array of volume-matched GR mean Kdp (specific
;                        differential phase)
; GR_DP_KdpMax        As above, but sample maximum of Kdp
; GR_DP_KdpStdDev     As above, but sample standard deviation of Kdp
;
; GR_DP_RHOhv         subsetted array of volume-matched GR mean RHOhv
;                        (co-polar correlation coefficient)
; GR_DP_RHOhvMax      As above, but sample maximum of RHOhv
; GR_DP_RHOhvStdDev   As above, but sample standard deviation of RHOhv
;
; GR_DP_HID           subsetted array of volume-matched GR Hydrometeor ID (HID)
;                         category (count of GR bins in each HID category)
; mode_HID           subsetted array of volume-matched GR Hydrometeor ID (HID)
;                         "best" category (HID category with the highest count
;                         of bins in the sample volume)
;
; GR_DP_Dzero         subsetted array of volume-matched GR mean D0 (Median
;                        volume diameter)
; GR_DP_DzeroMax      As above, but sample maximum of Dzero
; GR_DP_DzeroStdDev   As above, but sample standard deviation of Dzero
;
; GR_DP_Nw            subsetted array of volume-matched GR mean Nw (Normalized
;                        intercept parameter)
; GR_DP_NwMax         As above, but sample maximum of Nw
; GR_DP_NwStdDev      As above, but sample standard deviation of Nw
;
; zcor                subsetted array of volume-match DPR corrected reflectivity
; rain3               subsetted array of volume-match DPR 3D rainrate
; dprDm               subsetted array of volume-match DPR 3D Dm
; dprNw               subsetted array of volume-match DPR 3D Nw
; top                 subsetted array of volume-match sample top heights, km
; botm                subsetted array of volume-match sample bottom heights, km
; lat                 subsetted array of volume-match sample latitude
; lon                 subsetted array of volume-match sample longitude
; nearSurfRain        subsetted array of volume-match near-surface PR rainrate *
; pia                 subsetted array of DPR Path Integrated Attenuation *
; stmTopHgt           subsetted array of DPRGMI stormTopAltitude *
; pr_index            subsetted array of 1-D indices of the original (scan,ray)
;                        PR product coordinates *
; rnType              subsetted array of volume-match sample point rain type *,#
; XY_km               array of volume-match sample point X and Y coordinates,
;                        radar-centric, km *
; dist                array of volume-match sample point range from radar, km *
; hgtcat              array of volume-match sample point height layer indices,
;                        0-12, representing 1.5-19.5 km
; bbProx              array of volume-match sample point proximity to mean
;                        bright band:
;                     1 (below), 2 (within), 3 (above)
; pctgoodpr           array of volume-match sample point percent of original
;                        DPR dBZ bins above threshold
; pctgoodDprDm        array of volume-match sample point percent of original
;                        DPR Dm bins above threshold
; pctgoodDprNw        array of volume-match sample point percent of original
;                        DPR Nw bins above threshold
; pctgoodgv           array of volume-match sample point percent of original
;                        GR dBZ bins above threshold
; pctgoodrcgv         array of volume-match sample point percent of original
;                        GR RC rainrate bins above threshold
; pctgoodrpgv         array of volume-match sample point percent of original
;                        GR RP rainrate bins above threshold
; pctgoodrrgv         array of volume-match sample point percent of original
;                        GR RR rainrate bins above threshold
;
; The arrays should all be of the same size when done, with the exception of
; the xCorner and yCorner fields that have an additional dimension that
; needs to be dealt with.  Those marked by * are originally single-level fields
; like nearSurfRain that are replicated to the N sweep levels in the volume scan
; to match the multi-level fields before the data get subsetted. Subsetting
; involves paring off the "bogus" data points that enclose the area of the
; actual DPR/GR overlap data.
;
; # indicates that rain type is dumbed down to simple categories 1 (Stratiform),
; 2 (Convective), or 3 (Other), from the original DPR many-digit subcategories
;
;
; HISTORY
; -------
; 06/15/15 Morris, GPM GV, SAIC
; - Created from fprep_dpr_geo_match_profiles.pro
; 12/23/15 by Bob Morris, GPM GV (SAIC)
;  - Added reading of GR_blockage variable and its presence flag for version
;    1.2 files.
; 01/04/16 by Bob Morris, GPM GV (SAIC)
;  - Removed IF conditions on 2-D REFORM of various pctgood variables.  Must
;    REFORM defined arrays to 2-D whether or not actual percentages are able to
;    be computed.
;  - Lowered meanBB_MSL to 0.25 km below mean 0 deg. C height when using this
;    variable as the BB height source, according to theory and viewed cross
;    sections of Z at DPR resolution.
; 01/15/16 by Bob Morris, GPM GV (SAIC)
;  - Added FORCEBB parameter to override the DPR mean BB height with the value
;    provided by ALT_BB_HEIGHT.
;  - Added keyword parameter RAY_RANGE to specify DPR rays to clip to for the
;    returned data (i.e., inner swath band of data, or two outer swath bands).
;  - Moved BB calculations up to the front so that if we have to quit because of
;    a no-BB situation we do so right away.  Also, so that when clipping to a
;    range of ray numbers we process the unclipped data first to avoid missing
;    valid BB points from the lost regions.
; 04/20/16 by Bob Morris, GPM GV (SAIC)
;  - Activated reading and processing of clutterStatus now that it is present in
;    version 1.21 files.
; 04/26/16 by Bob Morris, GPM GV (SAIC)
;  - Added DPR Dm (precipTotPSDparamHigh) and Nw (precipTotPSDparamLow) and
;    their percent above threshold values to the output parameters.
; 05/31/16 by Bob Morris, GPM GV (SAIC)
;  - Added documentation of the DPR Dm and Nw variables and their percents
;    above threshold to the prologue.
; 06/02/16 by Bob Morris, GPM GV (SAIC)
;  - Added test for empty string for alt_bb_height since is_a_number() returns
;    'true' for this situation.
;  - Changed logic and messaging for when S2KU is set but no above/below BB
;    samples are present or meanBB is unable to be computed.
; 07/13/16 by Bob Morris, GPM GV (SAIC)
;  - Added GR Dm and N2 mean, max, StdDev, and their percents above threshold
;    as variables to be read from the version 1.3 matchup files.
;  - Changed logic to process all variables for all versions and deal with the
;    version-specific situations at the end where pointers are assigned, since
;    read_dprgmi_geo_match_netcdf() fills in these variables regardless of file
;    version.
; 09/28/16 by Bob Morris, GPM GV (SAIC)
;  - Fixed oversight of pr_index being computed as INTEGER instead of LONG,
;    resulting in overflow when original data is from full-orbit 2BDPRGMI files.
; 10/26/16 by Bob Morris, GPM GV (SAIC)
;  - Added logic to convert DPRGMI Nw to same definition as GR Nw and N2.
; 11/30/16 by Bob Morris, GPM GV (SAIC)
;  - Added reading of DPRGMI stormTopAltitude (ptr_stmTopHgt) field for version
;    1.3 file.
; 8/15/18 Todd Berendes, UAH 
;  - returned value for BBheight, previously not returned
;
;
; EMAIL QUESTIONS OR COMMENTS AT:
;       https://pmm.nasa.gov/contact
;-
;===============================================================================


FUNCTION fprep_dprgmi_geo_match_profiles_mrms, ncfilepr, heights_in, KUKA=KuKaIn, $
    SCANTYPE=scanTypeIn, PCT_ABV_THRESH=pctAbvThresh, GV_CONVECTIVE=gvconvective, $
    GV_STRATIFORM=gvstratiform, S2KU=s2ku, PTRgeometa=ptr_geometa, $
    PTRsweepmeta=ptr_sweepmeta, PTRsitemeta=ptr_sitemeta, $
    PTRfieldflags=ptr_fieldflags, PTRfilesmeta=ptr_filesmeta, $

   ; ground radar variables
    PTRGVZMEAN=ptr_gvz, PTRGVMAX=ptr_gvzmax, PTRGVSTDDEV=ptr_gvzstddev, $
    PTRGVRCMEAN=ptr_gvrc, PTRGVRCMAX=ptr_gvrcmax, PTRGVRCSTDDEV=ptr_gvrcstddev,$
    PTRGVRPMEAN=ptr_gvrp, PTRGVRPMAX=ptr_gvrpmax, PTRGVRPSTDDEV=ptr_gvrpstddev,$
    PTRGVRRMEAN=ptr_gvrr, PTRGVRRMAX=ptr_gvrrmax, PTRGVRRSTDDEV=ptr_gvrrstddev,$
    PTRGVHID=ptr_GR_DP_HID, PTRGVMODEHID=ptr_mode_HID, PTRGVDZEROMEAN=ptr_GR_DP_Dzero, $
    PTRGVDZEROMAX=ptr_GR_DP_Dzeromax, PTRGVDZEROSTDDEV=ptr_GR_DP_Dzerostddev, $
    PTRGVNWMEAN=ptr_GR_DP_Nw, PTRGVNWMAX=ptr_GR_DP_Nwmax, $
    PTRGVNWSTDDEV=ptr_GR_DP_Nwstddev, PTRGVDMMEAN=ptr_GR_DP_Dm, $
    PTRGVDMMAX=ptr_GR_DP_Dmmax, PTRGVDMSTDDEV=ptr_GR_DP_Dmstddev, $
    PTRGVN2MEAN=ptr_GR_DP_N2, PTRGVN2MAX=ptr_GR_DP_N2max, $
    PTRGVN2STDDEV=ptr_GR_DP_N2stddev, PTRGVZDRMEAN=ptr_GR_DP_Zdr, $
    PTRGVZDRMAX=ptr_GR_DP_Zdrmax, PTRGVZDRSTDDEV=ptr_GR_DP_Zdrstddev, $
    PTRGVKDPMEAN=ptr_GR_DP_Kdp, PTRGVKDPMAX=ptr_GR_DP_Kdpmax, $
    PTRGVKDPSTDDEV=ptr_GR_DP_Kdpstddev, PTRGVRHOHVMEAN=ptr_GR_DP_RHOhv, $
    PTRGVRHOHVMAX=ptr_GR_DP_RHOhvmax, PTRGVRHOHVSTDDEV=ptr_GR_DP_RHOhvstddev, $
    PTRGVBLOCKAGE=ptr_GR_blockage, $

   ; space radar variables
    PTRzcor=ptr_zcor, PTRrain3d=ptr_rain3, PTRprlat=ptr_dpr_lat, PTRprlon=ptr_dpr_lon, $
    PTRdprdm=ptr_dprDm, PTRdprnw=ptr_dprNw, $
    PTRpia=ptr_pia, PTRsfcrainpr=ptr_nearSurfRain, $
    PTRraintype_int=ptr_rnType, PTRbbHgt=ptr_bbHeight, $
    PTRlandOcean_int=ptr_landOcean, PTRpridx_long=ptr_pr_index, $
    PTRstmTopHgt=ptr_stmTopHgt, $

   ; MRMS RR variables
    PTRmrmsrrlow=ptr_mrmsrrlow, $
    PTRmrmsrrmed=ptr_mrmsrrmed, $
    PTRmrmsrrhigh=ptr_mrmsrrhigh, $
    PTRmrmsrrveryhigh=ptr_mrmsrrveryhigh, $
   ; MRMS guage ratio variables
    PTRmrmsgrlow=ptr_mrmsgrlow, $
    PTRmrmsgrmed=ptr_mrmsgrmed, $
    PTRmrmsgrhigh=ptr_mrmsgrhigh, $
    PTRmrmsgrveryhigh=ptr_mrmsgrveryhigh, $
   ; MRMS precip type histogram variables
    PTRmrmsptlow=ptr_mrmsptlow, $
    PTRmrmsptmed=ptr_mrmsptmed, $
    PTRmrmspthigh=ptr_mrmspthigh, $
    PTRmrmsptveryhigh=ptr_mrmsptveryhigh, $
   ; MRMS RQI percent variables
    PTRmrmsrqiplow=ptr_mrmsrqiplow, $
    PTRmrmsrqipmed=ptr_mrmsrqipmed, $
    PTRmrmsrqiphigh=ptr_mrmsrqiphigh, $
    PTRmrmsrqipveryhigh=ptr_mrmsrqipveryhigh, $
    
	; TAB 2/6/19 SWE variables
    PTRswedp=ptr_swedp, $
    PTRswe25=ptr_swe25, $
    PTRswe50=ptr_swe50, $
    PTRswe75=ptr_swe75, $
;    PTRswedp=ptr_swedp, PTRswedpstddev=ptr_swedpstddev, PTRswedpmax=ptr_swedpmax, $

    PTRMRMSHID=ptr_MRMS_HID, $

   ; derived/computed variables
    PTRtop=ptr_top, PTRbotm=ptr_botm, PTRlat=ptr_lat, PTRlon=ptr_lon, $
    PTRxCorners=ptr_xCorner, PTRyCorners=ptr_yCorner, PTRbbProx=ptr_bbProx, $
    PTRclutterStatus=ptr_clutterStatus, $
    PTRhgtcat=ptr_hgtcat, PTRdist=ptr_dist, $

   ; percent above threshold parameters
    PTRpctgoodpr=ptr_pctgoodpr, PTRpctgoodrain=ptr_pctgoodrain, $
    PTRpctgoodDprDm=ptr_pctgoodDprDm, PTRpctgoodDprNw=ptr_pctgoodDprNw, $
    PTRpctgoodgv=ptr_pctgoodgv, PTRpctgoodrcgv=ptr_pctgoodrcgv, $
    PTRpctgoodrpgv=ptr_pctgoodrpgv, PTRpctgoodrrgv=ptr_pctgoodrrgv, $
    PTRpctgoodhidgv=ptr_pctgoodhidgv, PTRpctgooddzerogv=ptr_pctgooddzerogv, $
    PTRpctgoodnwgv=ptr_pctgoodnwgv, PTRpctgooddmgv=ptr_pctgooddmgv, $
    PTRpctgoodn2gv=ptr_pctgoodn2gv, PTRpctgoodzdrgv=ptr_pctgoodzdrgv, $
    PTRpctgoodkdpgv=ptr_pctgoodkdpgv, PTRpctgoodrhohvgv=ptr_pctgoodrhohvgv, $

   ; Bright Band structure, control parameters
    BBPARMS=bbparms, BB_RELATIVE=bb_relative, BBWIDTH=bbwidth, $
    ALT_BB_HGT=alt_bb_hgt, FORCEBB=forcebb, $

   ; ray number range limits parameter (2 element int array)
    RAY_RANGE=ray_range



; "include" file for PR data constants
@dpr_params.inc

; include file for DPRGMI structure definitions
@dprgmi_geo_match_nc_structs_mrms.inc

status = 1   ; init return status to FAILED

idxKuKa = 0    ; set up to extract Ku subarray from MS swath by default
IF N_ELEMENTS(scanTypeIn) NE 1 THEN BEGIN
   message, "Reading scanType=NS from DPRGMI matchup file by default.", /INFO
   scanType = 'NS'
   KuKa = 'Ku'
   data_ns = 1    ; INITIALIZE AS ANYTHING, WILL BE REDEFINED IN READ
   RAYSPERSCAN = RAYSPERSCAN_NS
ENDIF ELSE BEGIN
   CASE scanTypeIn OF
      'MS' : BEGIN
               scanType = scanTypeIn
               data_ms = 1    ; INITIALIZE AS ANYTHING, WILL BE REDEFINED IN READ
               RAYSPERSCAN = RAYSPERSCAN_MS
               IF N_ELEMENTS(KuKaIn) NE 1 THEN BEGIN
                  message, "Reading Ku/MS from DPRGMI matchup file by default.", /INFO
                  KuKa = 'Ku'
               ENDIF ELSE BEGIN
                  CASE STRUPCASE(KuKaIn) OF
                    'KA' : BEGIN
                             KuKa = 'Ka'
                             idxKuKa = 1   ; extract Ka subarray for MS
                           END
                    'KU' : KuKa = 'Ku'
                    ELSE : BEGIN
                             message, "Illegal KUKA value: "+KuKaIn+". "+ $
                                "Reading Ku/MS from DPRGMI matchup file by default.", /INFO
                             KuKa = 'Ku'
                           END
                  ENDCASE
               ENDELSE
             END
      'NS' : BEGIN
               scanType = scanTypeIn
               data_ns = 1    ; INITIALIZE AS ANYTHING, WILL BE REDEFINED IN READ
               RAYSPERSCAN = RAYSPERSCAN_NS
               KuKa = 'Ku'
             END
     ELSE : message, "Illegal SCANTYPE parameter, only MS or NS allowed."
   ENDCASE
ENDELSE

s2ku = keyword_set( s2ku )

nrayrange = N_ELEMENTS(ray_range)
CASE nrayrange OF
      0 : clipByRay = 0
      2 : BEGIN
            ; check RAYSPERSCAN against ray_range values, if clipping to
            ; a range of rays
             IF MAX(ray_range) GT RAYSPERSCAN THEN BEGIN
                PRINT, ''
                PRINT, "RAYSPERSCAN in " + scantype + " scans: ", RAYSPERSCAN
                PRINT, "Requested ray range: ", ray_range
                message, "Requested ray_range exceeds number of rays in product."
             ENDIF
            ; if ray_range is OK, set up clipping type
             clipByRay = 1
             IF ray_range[0] GT ray_range[1] THEN BEGIN
               ; clip to two bands: 0->ray_range[1] and ray_range[0]->NRAYSPERSCAN
                inside_clip = 0
             ENDIF ELSE BEGIN
               ; clip to inner band: ray_range[0] -> ray_range[1]
                inside_clip = 1
             ENDELSE
          END
   ELSE : BEGIN
             message, "Illegal RAY_RANGE specification, expect INTARR(2)"
          END
ENDCASE

; if convective or stratiform reflectivity thresholds are not specified, disable
; rain type overrides by setting values to zero
IF ( N_ELEMENTS(gvconvective) NE 1 ) THEN gvconvective=0.0
IF ( N_ELEMENTS(gvstratiform) NE 1 ) THEN gvstratiform=0.0

IF ( N_ELEMENTS(heights_in) EQ 0 ) THEN BEGIN
   print, "In fprep_dprgmi_geo_match_profiles(): assigning 13 default height ", $
          "levels, 1.5-19.5km"
   heights = [1.5,3.0,4.5,6.0,7.5,9.0,10.5,12.0,13.5,15.0,16.5,18.0,19.5]
   halfdepth=(heights[1]-heights[0])/2.0
ENDIF ELSE BEGIN
  ; we expect an array of equally-spaced heights, where the first height is
  ; equal to the step between heights
   heights=heights_in
   depth=(heights[1]-heights[0])
;TEMPORARY OVERRIDE TO GET THIS TO RUN FOR BB_REL SITUATION
halfdepth=depth/2.0
;   hgtcheck = (INDGEN(N_ELEMENTS(heights))+1)*depth
;   IF ARRAY_EQUAL(heights,hgtcheck) THEN halfdepth=depth/2.0 $
;   ELSE BEGIN
;      PRINT, "Supplied heights array values not monospaced or first value ", $
;             "not equal to height step."
;      PRINT, "Supplied heights: ", heights_in
;      PRINT, "Expected heights: ", hgtcheck
;      GOTO, errorExit
;   ENDELSE
ENDELSE

; Get an uncompressed copy of the netCDF file - we never touch the original
cpstatus = uncomp_file( ncfilepr, ncfile1 )

if (cpstatus eq 'OK') then begin

 ; create <<initialized>> structures to hold the metadata variables
;  mygeometa=GET_DPR_GEO_MATCH_NC_STRUCT('matchup')  ;{ dpr_geo_match_meta }
;  mysweeps=GET_DPR_GEO_MATCH_NC_STRUCT('sweeps')    ;{ gr_sweep_meta }
;  mysite=GET_DPR_GEO_MATCH_NC_STRUCT('site')        ;{ gr_site_meta }
;  myflags=GET_DPR_GEO_MATCH_NC_STRUCT('fields')     ;{ dpr_gr_field_flags }
;  myfiles=GET_DPR_GEO_MATCH_NC_STRUCT( 'files' )
  mygeometa={ dprgmi_geo_match_meta }
  mysweeps={ gr_sweep_meta }
  mysite={ gr_site_meta }
  myflags={ dprgmi_gr_field_flags }
  myfiles={ dprgmi_gr_input_files }

 ; read the file
   CATCH, error
   IF error EQ 0 THEN BEGIN
      status = read_dprgmi_geo_match_netcdf_mrms( ncfile1, matchupmeta=mygeometa, $
        sweepsmeta=mysweeps, sitemeta=mysite, fieldflags=myflags, $
        filesmeta=myfiles, DATA_MS=data_MS, DATA_NS=data_NS )
   ENDIF ELSE BEGIN
      help,!error_state,/st
      Catch, /Cancel
      message, 'err='+STRING(error)+", "+!error_state.msg, /INFO
      status=1   ;return, -1
   ENDELSE
   Catch, /Cancel

 ; remove the uncompressed file copy
  command3 = "rm -v " + ncfile1
  spawn, command3
  IF (status EQ 1) then GOTO, errorExit

 ; determine whether there are any MS data points
  IF scanType EQ 'MS' AND mygeometa.have_swath_MS EQ 0 THEN BEGIN
     message, "No in-range MS scan samples.", /INFO
     status = 1
     GOTO, noMSdata
  ENDIF

  site_lat = mysite.site_lat
  site_lon = mysite.site_lon
  siteID = string(mysite.site_id)
  site_elev = mysite.site_elev

  nswp = mygeometa.num_sweeps     ; # of GR elevation sweeps in dataset
  nc_file_version = mygeometa.nc_file_version   ; geo-match file version

 ; rename the data structure for the selected swath to a common name, and get
 ; the scan-type-specific metadata values
  CASE scanType OF
      'MS' : BEGIN
                dataCmb = TEMPORARY(data_ms)
                nfp = mygeometa.num_footprints_ms  ; # of PR rays in dataset
             END
      'NS' : BEGIN
                dataCmb = TEMPORARY(data_ns)
                nfp = mygeometa.num_footprints_ns  ; # of PR rays in dataset
             END
      ELSE : message, "Illegal SCANTYPE parameter, only MS or NS allowed."
  ENDCASE

 ; now extract data field arrays from structure and assign to
 ; input parameter data fields

  gvexp = dataCmb.n_gr_expected          ; Expected/Rejected Bin Count variables
  gvrej = dataCmb.n_gr_z_rejected
  gvrcrej = dataCmb.n_gr_rc_rejected
  gvrprej = dataCmb.n_gr_rp_rejected
  gvrrrej = dataCmb.n_gr_rr_rejected
  gv_zdr_rej = dataCmb.n_gr_zdr_rejected
  gv_kdp_rej = dataCmb.n_gr_kdp_rejected
  gv_rhohv_rej = dataCmb.n_gr_rhohv_rejected
  gv_hid_rej = dataCmb.n_gr_hid_rejected
  gv_dzero_rej = dataCmb.n_gr_dzero_rejected
  gv_nw_rej = dataCmb.n_gr_nw_rejected
  gv_dm_rej = dataCmb.n_gr_dm_rejected
  gv_n2_rej = dataCmb.n_gr_n2_rejected
  prexp = dataCmb.n_dpr_expected
  zcorrej = dataCmb.n_correctedReflectFactor_rejected
  rainrej = dataCmb.n_precipTotRate_rejected
  dpr_dm_rej=dataCmb.n_precipTotPSDparamHigh_rejected
 ; Nw values are the 0 index of the first (extra) dimension in the PSDparamLow
 ; family of variables, so grab those and redimension to the same as other variables
  dpr_nw_rej=REFORM(dataCmb.n_precipTotPSDparamLow_rejected[0,*,*])

  gvz = dataCmb.GR_Z            ; Ground Radar variables
  gvzmax = dataCmb.GR_Z_Max
  gvzstddev = dataCmb.GR_Z_StdDev
  gvrc = dataCmb.GR_RC_rainrate
  gvrcMax = dataCmb.GR_RC_rainrate_Max
  gvrcStdDev = dataCmb.GR_RC_rainrate_StdDev
  gvrp = dataCmb.GR_RP_rainrate
  gvrpMax = dataCmb.GR_RP_rainrate_Max
  gvrpStdDev = dataCmb.GR_RP_rainrate_StdDev
  gvrr = dataCmb.GR_RR_rainrate
  gvrrMax = dataCmb.GR_RR_rainrate_Max
  gvrrStdDev = dataCmb.GR_RR_rainrate_StdDev
  GR_DP_HID = dataCmb.GR_HID
  GR_DP_Zdr = dataCmb.GR_Zdr
  GR_DP_ZdrMax = dataCmb.GR_Zdr_Max
  GR_DP_ZdrStdDev = dataCmb.GR_Zdr_StdDev
  GR_DP_Kdp = dataCmb.GR_Kdp
  GR_DP_KdpMax = dataCmb.GR_Kdp_Max
  GR_DP_KdpStdDev = dataCmb.GR_Kdp_StdDev
  GR_DP_RHOhv = dataCmb.GR_RHOhv
  GR_DP_RHOhvMax = dataCmb.GR_RHOhv_Max
  GR_DP_RHOhvStdDev = dataCmb.GR_RHOhv_StdDev
  GR_DP_Dzero = dataCmb.GR_Dzero
  GR_DP_DzeroMax = dataCmb.GR_Dzero_Max
  GR_DP_DzeroStdDev = dataCmb.GR_Dzero_StdDev
  GR_DP_Nw = dataCmb.GR_Nw
  GR_DP_NwMax = dataCmb.GR_Nw_Max
  GR_DP_NwStdDev = dataCmb.GR_Nw_StdDev
; go ahead and use these arrays, even if filled with MISSING for earlier versions
  GR_DP_Dm = dataCmb.GR_Dm
  GR_DP_DmMax = dataCmb.GR_Dm_Max
  GR_DP_DmStdDev = dataCmb.GR_Dm_StdDev
  GR_DP_N2 = dataCmb.GR_N2
  GR_DP_N2Max = dataCmb.GR_N2_Max
  GR_DP_N2StdDev = dataCmb.GR_N2_StdDev
  GR_blockage=dataCmb.GR_blockage

  zcor = dataCmb.correctedReflectFactor
  rain3 = dataCmb.precipTotRate
  dpr_Dm = dataCmb.precipTotPSDparamHigh
 ; Nw values are the 0 index of the first (extra) dimension in the PSDparamLow
 ; family of variables, so grab those and redimension to the same as other variables
  dpr_Nw_mu = REFORM(dataCmb.precipTotPSDparamLow[0,*,*])
  dpr_Nw = dpr_Nw_mu
 ; now have to convert Nw in log10(Nw) with Nw in 1/m^4 to log10(Nw) with Nw in 1/m^3-mm
  idxNw2fix = WHERE(dpr_Nw_mu GT 0.0, n2fix)
  IF n2fix GT 0 THEN dpr_Nw[idxNw2fix] = dpr_Nw_mu[idxNw2fix] - 3.

  dpr_lat = dataCmb.DPRlatitude
  dpr_lon = dataCmb.DPRlongitude
  pia=dataCmb.pia
  stmTopHgt=dataCmb.stormTopAltitude
  bbHeight=dataCmb.zeroDegAltitude
  nearSurfRain=dataCmb.surfPrecipTotRate
;  rnflag=dataCmb.
  rntype=dataCmb.precipitationType
  landoceanflag=dataCmb.surfaceType

  clutterStatus = dataCmb.clutterStatus      ; derived variables
  top=dataCmb.topHeight
  botm=dataCmb.bottomHeight
  lat=dataCmb.latitude
  lon=dataCmb.longitude
;  pr_index=dataCmb.
  scanNum=dataCmb.scanNum
  rayNum=dataCmb.rayNum
  xcorner=dataCmb.xCorners
  ycorner=dataCmb.yCorners
  
  ; TAB 2/6/19 new stuff for mrms and snow
  
  if myflags.have_mrms eq 1 then begin
    mrmsrrlow=dataCmb.mrmsrrlow
    mrmsrrmed=dataCmb.mrmsrrmed
    mrmsrrhigh=dataCmb.mrmsrrhigh
    mrmsrrveryhigh=dataCmb.mrmsrrveryhigh
    mrmsgrlow=dataCmb.mrmsgrlow
    mrmsgrmed=dataCmb.mrmsgrmed
    mrmsgrhigh=dataCmb.mrmsgrhigh
    mrmsgrveryhigh=dataCmb.mrmsgrveryhigh
    mrmsptlow=dataCmb.mrmsptlow
    mrmsptmed=dataCmb.mrmsptmed
    mrmspthigh=dataCmb.mrmspthigh
    mrmsptveryhigh=dataCmb.mrmsptveryhigh
    mrmsrqiplow=dataCmb.mrmsrqiplow
    mrmsrqipmed=dataCmb.mrmsrqipmed
    mrmsrqiphigh=dataCmb.mrmsrqiphigh
    mrmsrqipveryhigh=dataCmb.mrmsrqipveryhigh
    MRMS_HID=dataCmb.MRMS_HID
    
  endif
  
  if myflags.have_GR_SWE eq 1 then begin
	; TAB 2/6/19 SWE variables
    swedp=dataCmb.swedp
    swe25=dataCmb.swe25
    swe50=dataCmb.swe50
    swe75=dataCmb.swe75
;    PTRswedp=ptr_swedp, PTRswedpstddev=ptr_swedpstddev, PTRswedpmax=ptr_swedpmax, $
  endif 

 ; deal with the nKuKa dimension in MS swath.  Extract either the Ku or Ka
 ; subarray depending on idxKuKa
  IF ( scanType EQ 'MS' ) THEN BEGIN
     zcor = REFORM(zcor[idxKuKa,*,*])
     prexp = REFORM(prexp[idxKuKa,*,*])
     zcorrej = REFORM(zcorrej[idxKuKa,*,*])
     pia = REFORM(pia[idxKuKa,*])
     stmTopHgt = REFORM(stmTopHgt[idxKuKa,*])
     clutterStatus = REFORM(clutterStatus[idxKuKa,*,*])
; PLACEHOLDERS:
;     ellipsoidBinOffset = REFORM(ellipsoidBinOffset[idxKuKa,*])
;     lowestClutterFreeBin = REFORM(lowestClutterFreeBin[idxKuKa,*])
;     rainFlag = REFORM(rainFlag[idxKuKa,*])
;     surfaceRangeBin = REFORM(surfaceRangeBin[idxKuKa,*])
  ENDIF

endif else begin

  print, 'Cannot copy/unzip netCDF file: ', ncfilepr
  print, cpstatus
  command3 = "rm -v " + ncfile1
  spawn, command3
  goto, errorExit

endelse

; compute the 1-D pr_index values from the scanNum and rayNum values
; - all values are 0 or greater, so no issues of "bogus" values
pr_index = LONG(scanNum)*RAYSPERSCAN + rayNum

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

; Clip single-level fields we will use for mean BB calculations:
BB = BBHeight[idxpractual]
;bbStatusCode = bbStatus[idxpractual]

; if we are clipping the data to a range of rays, then find the
; corresponding array index values
IF clipByRay THEN BEGIN
   raypr = rayNum[idxpractual]+1   ; 1-based ray numbers
   IF inside_clip THEN idxclipped = WHERE( raypr GE ray_range[0] $
          AND raypr LE ray_range[1], countclipped ) $
   ELSE idxclipped = WHERE( raypr GE ray_range[0] $
          OR raypr LE ray_range[1], countclipped )
   IF countclipped GT 0 THEN BEGIN
      idxpractualCopy = idxpractual
      idxpractual = idxpractualCopy[idxclipped]
      countactual = countclipped
   ENDIF ELSE BEGIN
      print, "No data points in ray range limits, quitting case."
      status = 1
      goto, errorExit
   ENDELSE
ENDIF

; re-set the number of footprints in the geo_match_meta structure to the
; subsetted value
CASE scanType OF
    'MS' : mygeometa.num_footprints_ms = countactual
    'NS' : mygeometa.num_footprints_ns = countactual
    ELSE : message, "Illegal SCANTYPE parameter, only MS or NS allowed."
ENDCASE

; Reclassify rain types down to simple categories 1 (Stratiform), 2 (Convective),
;  or 3 (Other), where defined
idxrnpos = where(rntype ge 0, countrntype)
if (countrntype GT 0 ) then rntype[idxrnpos] = rntype[idxrnpos]/10000000L

; - - - - - - - - - - - - - - - - - - - - - - - -

; convert bright band heights from m to km, where defined, and get mean BB hgt.
; - first, find the indices of stratiform rays with BB defined

idxbbdef = where(bb GT 0.0, countBB)    ;AND rnType[*,0] EQ 1, countBB)
IF ( countBB GT 0 ) THEN BEGIN
  ; grab the subset of BB values for defined/stratiform
   bb2hist = bb[idxbbdef]/1000.  ; with conversion to km

   bs=0.2  ; bin width, in km, for HISTOGRAM in get_mean_bb_height()
;   hist_window = 9  ; uncomment to plot BB histogram and print diagnostics
  ; use histogram analysis of BB heights to get mean height -- we don't need the
  ; /GPM binary parameter to be set since we don't have a BB quality flag in the
  ; DPRGMI product to contend with, so we end up defaulting to the histogram
  ; method either way
   meanbb_MSL = get_mean_bb_height( bb2hist, BS=bs, HIST_WINDOW=hist_window )
  ; place BB 1/4km below 0degC height, but above 0.0 km
   meanbb_MSL = (meanbb_MSL-0.25) > 0.001
ENDIF

IF ( countBB LE 0 AND N_ELEMENTS(alt_bb_hgt) EQ 1 ) $
OR ( N_ELEMENTS(alt_bb_hgt) EQ 1 AND KEYWORD_SET(forcebb) ) THEN BEGIN
  ; i.e., if we have the alt_bb_height option, and either we didn't find a
  ; DPR-based BB height or are forcing the use of alt_bb_height
   meanbb_MSL = -99.99
   meanbb = -99.99
   sz_alt_bb = FIX( SIZE(alt_bb_hgt, /TYPE) )
   SWITCH sz_alt_bb OF
         1 :
         2 :
         3 :
         4 :
         5 : BEGIN
                message, "Using ALT_BB_HGT value to assign mean BB height.", /info
                meanbb_MSL = FLOAT(alt_bb_hgt)
                BREAK
             END
         7 : BEGIN
                IF STRLEN(alt_bb_hgt[0]) EQ 0 THEN BEGIN
                   message, "Empty ALT_BB_HGT string supplied, ignoring.", /INFO
                   BREAK
                ENDIF ELSE BEGIN
                   message, "Using ALT_BB_HGT value to assign mean BB height.", /info
                ENDELSE
                IF FILE_TEST( alt_bb_hgt, /READ ) EQ 1 THEN BEGIN
                   parsed = STRSPLIT(FILE_BASENAME(ncfilepr), '.', /extract )
                   orbit = parsed[3]
                   ; try to get the mean BB for this case from the alt_bb_hgt
                   ; file, using input value of meanbb in bbparms structure as
                   ; the default missing value if it fails to find a match
                   meanbb_MSL = get_ruc_bb( alt_bb_hgt, siteID, orbit, $
                                            MISSING=-99.99, /VERBOSE )
                ENDIF ELSE BEGIN
                   ; check whether we were suppied a number in a non-empty string, 
                   ; and if so, convert it to float and use the value
                   IF is_a_number(alt_bb_hgt[0]) THEN BEGIN
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
ENDIF ELSE BEGIN
  ; if we didn't find a DPR-based BB height and have no alt_bb_height option
   IF countBB LE 0 THEN BEGIN
      meanbb_MSL = -99.99
      meanbb = -99.99
      message, "No valid bright band heights for case, "+ $
               "unable to populate bbparms structure.", /INFO
   ENDIF
ENDELSE

IF keyword_set(bb_relative) AND meanbb_MSL LE -99.9 THEN BEGIN
   message, "BB_RELATIVE option requested but cannot compute "+ $
            "BB-relative heights, quitting.", /INFO
   status = 1   ; set to FAILED
   goto, errorExit
ENDIF

IF meanbb_MSL GT 0.0 THEN BEGIN
  ; BB height in netCDF file is height above MSL -- must adjust mean BB to
  ; height above ground level for comparison to "heights", but don't let it go
  ; to or below below 0.0 km
   meanbb = (meanbb_MSL - site_elev) > 0.001

   IF keyword_set(bb_relative) THEN BEGIN
     ; level affected by BB is simply the zero-height BB-relative layer
      idxBB_HgtHi = WHERE( heights EQ 0.0, nbbzero)
      IF nbbzero EQ 1 THEN BEGIN
         BB_HgtHi = idxBB_HgtHi
         BB_HgtLo = BB_HgtHi
      ENDIF ELSE BEGIN
         print, "ERROR assigning BB-affected layer number."
         status = 1   ; set to FAILED
         goto, errorExit
      ENDELSE
   ENDIF ELSE BEGIN
     ; Level below BB is affected if layer top is 500m (0.5 km) or less
     ; below BB_Hgt, so BB_HgtLo is index of lowest fixed-height layer
     ; considered to be within the BB(see 'heights' array and halfdepth, above)
      idxbelowbb = WHERE( (heights+halfdepth) LT (meanbb-0.5), countbelowbb )
      if (countbelowbb GT 0) then $
           BB_HgtLo = (MAX(idxbelowbb) + 1) < (N_ELEMENTS(heights)-1) $
      else BB_HgtLo = 0
     ; Level above BB is affected if BB_Hgt is 500m or less below layer bottom,
     ; so BB_HgtHi is highest fixed-height layer considered to be within the BB
      idxabvbb = WHERE( (heights-halfdepth) GT (meanbb+0.5), countabvbb )
      if (countabvbb GT 0) THEN BB_HgtHi = (MIN(idxabvbb) - 1) > 0 $
      else if (meanbb GE (heights(N_ELEMENTS(heights)-1)-halfdepth) ) then $
      BB_HgtHi = (N_ELEMENTS(heights)-1) else BB_HgtHi = 0
   ENDELSE

   IF (N_ELEMENTS(bbparms) EQ 1) THEN BEGIN
      bbparms.meanbb = meanbb
      bbparms.BB_HgtLo = BB_HgtLo < BB_HgtHi
      bbparms.BB_HgtHi = BB_HgtHi > BB_HgtLo
      print, 'Mean BB (km AGL), bblo, bbhi = ', meanbb, $
             heights[0]+halfdepth*2*bbparms.BB_HgtLo, $
             heights[0]+halfdepth*2*bbparms.BB_HgtHi
   ENDIF
ENDIF

; - - - - - - - - - - - - - - - - - - - - - - - -

; clip the data fields down to the actual footprint points.  Deal with the
; single-level vs. multi-level fields by replicating the single-level
; fields 'nswp' times

; build an array index of actual points, replicated over all the sweep levels
idx3d=long(gvexp)           ; take one of the 2D arrays, make it LONG type
idx3d[*,*] = 0L             ; re-set all point values to 0
idx3d[idxpractual,0] = 1L   ; set first-sweep-level values to 1 where non-bogus

; now copy the first sweep values to the other levels, and while in the same
; loop, make the single-level arrays for categorical fields the same dimension
; as the sweep-level by array concatenation
IF ( nswp GT 1 ) THEN BEGIN
   dpr_latApp = dpr_lat
   dpr_lonApp = dpr_lon  
   rnTypeApp = rnType
   nearSurfRainApp = nearSurfRain
   pr_indexApp = pr_index
   BBHeightApp=BBHeight
   landOceanFlagApp=landOceanFlag
   piaAPP=pia
   stmTopHgtAPP=stmTopHgt

   FOR iswp=1, nswp-1 DO BEGIN
      idx3d[*,iswp] = idx3d[*,0]    ; copy first level values to iswp'th level
      ; concatenate another level's worth for PR Lat:
      dpr_lat = [dpr_lat, dpr_latApp]
      dpr_lon = [dpr_lon, dpr_lonApp]  ; ditto for PR lon
      rnType = [rnType, rnTypeApp]  ; ditto for rain type
      nearSurfRain = [nearSurfRain, nearSurfRainApp]  ; ditto for sfc rain
      pr_index = [pr_index, pr_indexApp]                 ; ditto for pr_index
      BBHeight = [BBHeight, BBHeightApp]                 ; ditto for BBHeight
      landOceanFlag = [landOceanFlag, landOceanFlagApp]  ; "" landOceanFlag
      pia = [pia, piaApp]                             ; "" piaFinal
      stmTopHgt = [stmTopHgt, stmTopHgtApp]
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
gvexp = gvexp[idxpractual2d]
gvrej = gvrej[idxpractual2d]
prexp = prexp[idxpractual2d]
zcorrej = zcorrej[idxpractual2d]
rainrej = rainrej[idxpractual2d]
dpr_dm_rej = dpr_dm_rej[idxpractual2d]
dpr_nw_rej = dpr_nw_rej[idxpractual2d]
gvz = gvz[idxpractual2d]
gvzmax = gvzmax[idxpractual2d]
gvzstddev = gvzstddev[idxpractual2d]
gvrc = gvrc[idxpractual2d]
gvrcMax = gvrcMax[idxpractual2d]
gvrcStdDev = gvrcStdDev[idxpractual2d]
gvrp = gvrp[idxpractual2d]
gvrpMax = gvrpMax[idxpractual2d]
gvrpStdDev = gvrpStdDev[idxpractual2d]
gvrr = gvrr[idxpractual2d]
gvrrMax = gvrrMax[idxpractual2d]
gvrrStdDev = gvrrStdDev[idxpractual2d]
gv_zdr_rej = gv_zdr_rej[idxpractual2d]
gv_kdp_rej = gv_kdp_rej[idxpractual2d]
gv_rhohv_rej = gv_rhohv_rej[idxpractual2d]
gv_hid_rej = gv_hid_rej[idxpractual2d]
gv_dzero_rej = gv_dzero_rej[idxpractual2d]
gv_nw_rej = gv_nw_rej[idxpractual2d]
GR_DP_Zdr = GR_DP_Zdr[idxpractual2d]
GR_DP_Kdp = GR_DP_Kdp[idxpractual2d]
GR_DP_RHOhv = GR_DP_RHOhv[idxpractual2d]
GR_DP_Dzero = GR_DP_Dzero[idxpractual2d]
GR_DP_Nw = GR_DP_Nw[idxpractual2d]
GR_DP_ZdrMax = GR_DP_ZdrMax[idxpractual2d]
GR_DP_KdpMax = GR_DP_KdpMax[idxpractual2d]
GR_DP_RHOhvMax = GR_DP_RHOhvMax[idxpractual2d]
GR_DP_DzeroMax = GR_DP_DzeroMax[idxpractual2d]
GR_DP_NwMax = GR_DP_NwMax[idxpractual2d]
GR_DP_ZdrStdDev = GR_DP_ZdrStdDev[idxpractual2d]
GR_DP_KdpStdDev = GR_DP_KdpStdDev[idxpractual2d]
GR_DP_RHOhvStdDev = GR_DP_RHOhvStdDev[idxpractual2d]
GR_DP_DzeroStdDev = GR_DP_DzeroStdDev[idxpractual2d]
GR_DP_NwStdDev = GR_DP_NwStdDev[idxpractual2d]
gv_Dm_rej = gv_Dm_rej[idxpractual2d]
gv_N2_rej = gv_N2_rej[idxpractual2d]
GR_DP_Dm = GR_DP_Dm[idxpractual2d]
GR_DP_N2 = GR_DP_N2[idxpractual2d]
GR_DP_DmMax = GR_DP_DmMax[idxpractual2d]
GR_DP_N2Max = GR_DP_N2Max[idxpractual2d]
GR_DP_DmStdDev = GR_DP_DmStdDev[idxpractual2d]
GR_DP_N2StdDev = GR_DP_N2StdDev[idxpractual2d]
GR_blockage = GR_blockage[idxpractual2d]

; deal with the GR_DP_HID array with the extra dimension, and while we
; are here, compute HID mode at each footprint
GR_DP_HIDnew = intarr(mygeometa.num_HID_categories, countactual, nswp)
mode_HID = intarr(countactual, nswp)  ; initializes to 0 (==MISSING)
FOR hicat = 0,mygeometa.num_HID_categories-1 DO BEGIN
   GR_DP_HIDnew[hicat,*,*] = GR_DP_HID[hicat,idxpractual,*]
ENDFOR
; if I could get IDL's MAX to work correctly, wouldn't need to do this
FOR ifp=0,countactual-1 DO BEGIN
  FOR iswp=0, nswp-1 DO BEGIN
    ; grab the HID histogram for one footprint, minus the MISSING category
     hidhistfp=REFORM( GR_DP_HIDnew[1:14,ifp,iswp] )
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

zcor = zcor[idxpractual2d]
rain3 = rain3[idxpractual2d]
DPR_Dm = DPR_Dm[idxpractual2d]
DPR_Nw = DPR_Nw[idxpractual2d]
top = top[idxpractual2d]
botm = botm[idxpractual2d]
lat = lat[idxpractual2d]
lon = lon[idxpractual2d]
dpr_lat = dpr_lat[idxpractual2d]
dpr_lon = dpr_lon[idxpractual2d]
rnType = rnType[idxpractual2d]
landOceanFlag = landOceanFlag[idxpractual2d]
nearSurfRain = nearSurfRain[idxpractual2d]
if myflags.have_mrms eq 1 then begin
	mrmsrrlow = mrmsrrlow[idxpractual2d]
	mrmsrrmed = mrmsrrmed[idxpractual2d]
	mrmsrrhigh = mrmsrrhigh[idxpractual2d]
	mrmsrrveryhigh = mrmsrrveryhigh[idxpractual2d]
	mrmsgrlow = mrmsgrlow[idxpractual2d]
	mrmsgrmed = mrmsgrmed[idxpractual2d]
	mrmsgrhigh = mrmsgrhigh[idxpractual2d]
	mrmsgrveryhigh = mrmsgrveryhigh[idxpractual2d]
	mrmsptlow = mrmsptlow[idxpractual2d]
	mrmsptmed = mrmsptmed[idxpractual2d]
	mrmspthigh = mrmspthigh[idxpractual2d]
	mrmsptveryhigh = mrmsptveryhigh[idxpractual2d]
	mrmsrqiplow = mrmsrqiplow[idxpractual2d]
	mrmsrqipmed = mrmsrqipmed[idxpractual2d]
	mrmsrqiphigh = mrmsrqiphigh[idxpractual2d]
	mrmsrqipveryhigh = mrmsrqipveryhigh[idxpractual2d]
endif
if myflags.have_GR_SWE eq 1 then begin
	swedp = swedp[idxpractual2d]
	swe25 = swe25[idxpractual2d]
	swe50 = swe50[idxpractual2d]
	swe75 = swe75[idxpractual2d]
endif
clutterStatus = clutterStatus[idxpractual2d]
BBHeight = BBHeight[idxpractual2d]
pr_index = pr_index[idxpractual2d]
pia = pia[idxpractual2d]
stmTopHgt = stmTopHgt[idxpractual2d]

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
   print, "Computing Percent Above Threshold for DPR", $
          " and GR Reflectivity and Rainrate."
   print, "======================================", $
          "======================================="
   pctgoodpr = fltarr( N_ELEMENTS(prexp) )
   pctgoodgv =  fltarr( N_ELEMENTS(prexp) )
   pctgoodrain = fltarr( N_ELEMENTS(prexp) )
   pctgoodDprDm = fltarr( N_ELEMENTS(prexp) )
   pctgoodDprNw = fltarr( N_ELEMENTS(prexp) )
   pctgoodrcgv =  fltarr( N_ELEMENTS(prexp) )
   pctgoodrpgv =  fltarr( N_ELEMENTS(prexp) )
   pctgoodrrgv =  fltarr( N_ELEMENTS(prexp) )
   pctgoodzdrgv = fltarr( N_ELEMENTS(prexp) )
   pctgoodkdpgv = fltarr( N_ELEMENTS(prexp) )
   pctgoodRHOhvgv = fltarr( N_ELEMENTS(prexp) )
   pctgoodhidgv = fltarr( N_ELEMENTS(prexp) )
   pctgooddzerogv = fltarr( N_ELEMENTS(prexp) )
   pctgoodnwgv = fltarr( N_ELEMENTS(prexp) )
   pctgoodDmgv =  fltarr( N_ELEMENTS(prexp) )
   pctgoodN2gv =  fltarr( N_ELEMENTS(prexp) )
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
      pctgoodDprDm[idxexpgt0] = $
        100.0 * FLOAT( prexp[idxexpgt0]-dpr_dm_rej[idxexpgt0] ) / prexp[idxexpgt0]
      pctgoodDprNw[idxexpgt0] = $
        100.0 * FLOAT( prexp[idxexpgt0]-dpr_nw_rej[idxexpgt0] ) / prexp[idxexpgt0]
      IF myflags.HAVE_GR_RC_RAINRATE EQ 1 THEN pctgoodrcgv[idxexpgt0] = $
         100.0 * FLOAT( gvexp[idxexpgt0]-gvrcrej[idxexpgt0] ) / gvexp[idxexpgt0]
      IF myflags.HAVE_GR_RP_RAINRATE EQ 1 THEN pctgoodrpgv[idxexpgt0] = $
         100.0 * FLOAT( gvexp[idxexpgt0]-gvrprej[idxexpgt0] ) / gvexp[idxexpgt0]
      IF myflags.HAVE_GR_RR_RAINRATE EQ 1 THEN pctgoodrrgv[idxexpgt0] = $
         100.0 * FLOAT( gvexp[idxexpgt0]-gvrrrej[idxexpgt0] ) / gvexp[idxexpgt0]
      IF myflags.HAVE_GR_ZDR EQ 1 THEN pctgoodzdrgv[idxexpgt0] = $
         100.0 * FLOAT( gvexp[idxexpgt0] - gv_zdr_rej[idxexpgt0] ) / gvexp[idxexpgt0]
      IF myflags.HAVE_GR_KDP EQ 1 THEN pctgoodkdpgv[idxexpgt0] = $
         100.0 * FLOAT( gvexp[idxexpgt0] - gv_kdp_rej[idxexpgt0] ) / gvexp[idxexpgt0]
      IF myflags.HAVE_GR_RHOHV EQ 1 THEN pctgoodRHOhvgv[idxexpgt0] = $
         100.0 * FLOAT( gvexp[idxexpgt0] - gv_RHOhv_rej[idxexpgt0] ) / gvexp[idxexpgt0]
      IF myflags.HAVE_GR_HID EQ 1 THEN pctgoodhidgv[idxexpgt0] = $
         100.0 * FLOAT( gvexp[idxexpgt0] - gv_hid_rej[idxexpgt0] ) / gvexp[idxexpgt0]
      IF myflags.HAVE_GR_DZERO EQ 1 THEN pctgooddzerogv[idxexpgt0] = $
         100.0 * FLOAT( gvexp[idxexpgt0] - gv_dzero_rej[idxexpgt0] ) / gvexp[idxexpgt0]
      IF myflags.HAVE_GR_NW EQ 1 THEN pctgoodnwgv[idxexpgt0] = $
         100.0 * FLOAT( gvexp[idxexpgt0] - gv_nw_rej[idxexpgt0] ) / gvexp[idxexpgt0]
      IF myflags.HAVE_GR_DM EQ 1 THEN pctgoodDmgv[idxexpgt0] = $
         100.0 * FLOAT( gvexp[idxexpgt0] - gv_dm_rej[idxexpgt0] ) / gvexp[idxexpgt0]
      IF myflags.HAVE_GR_N2 EQ 1 THEN pctgoodN2gv[idxexpgt0] = $
         100.0 * FLOAT( gvexp[idxexpgt0] - gv_N2_rej[idxexpgt0] ) / gvexp[idxexpgt0]
   ENDELSE
ENDIF

; - - - - - - - - - - - - - - - - - - - - - - - -

; restore the subsetted arrays to two dimensions of (PRfootprints, GRsweeps)
gvz = REFORM( gvz, countactual, nswp )
gvzmax = REFORM( gvzmax, countactual, nswp )
gvzstddev = REFORM( gvzstddev, countactual, nswp )
gvrc = REFORM( gvrc, countactual, nswp )
gvrcmax = REFORM( gvrcmax, countactual, nswp )
gvrcstddev = REFORM( gvrcstddev, countactual, nswp )
gvrp = REFORM( gvrp, countactual, nswp )
gvrpmax = REFORM( gvrpmax, countactual, nswp )
gvrpstddev = REFORM( gvrpstddev, countactual, nswp )
gvrr = REFORM( gvrr, countactual, nswp )
gvrrmax = REFORM( gvrrmax, countactual, nswp )
gvrrstddev = REFORM( gvrrstddev, countactual, nswp )
GR_DP_Zdr = REFORM( GR_DP_Zdr, countactual, nswp )
GR_DP_Kdp = REFORM( GR_DP_Kdp, countactual, nswp )
GR_DP_RHOhv = REFORM( GR_DP_RHOhv, countactual, nswp )
GR_DP_Dzero = REFORM( GR_DP_Dzero, countactual, nswp )
GR_DP_Nw = REFORM( GR_DP_Nw, countactual, nswp )
GR_DP_ZdrMax = REFORM( GR_DP_ZdrMax, countactual, nswp )
GR_DP_KdpMax = REFORM( GR_DP_KdpMax, countactual, nswp )
GR_DP_RHOhvMax = REFORM( GR_DP_RHOhvMax, countactual, nswp )
GR_DP_DzeroMax = REFORM( GR_DP_DzeroMax, countactual, nswp )
GR_DP_NwMax = REFORM( GR_DP_NwMax, countactual, nswp )
GR_DP_ZdrStdDev = REFORM( GR_DP_ZdrStdDev, countactual, nswp )
GR_DP_KdpStdDev = REFORM( GR_DP_KdpStdDev, countactual, nswp )
GR_DP_RHOhvStdDev = REFORM( GR_DP_RHOhvStdDev, countactual, nswp )
GR_DP_DzeroStdDev = REFORM( GR_DP_DzeroStdDev, countactual, nswp )
GR_DP_NwStdDev = REFORM( GR_DP_NwStdDev, countactual, nswp )
GR_DP_Dm = REFORM( GR_DP_Dm, countactual, nswp )
GR_DP_N2 = REFORM( GR_DP_N2, countactual, nswp )
GR_DP_DmMax = REFORM( GR_DP_DmMax, countactual, nswp )
GR_DP_N2Max = REFORM( GR_DP_N2Max, countactual, nswp )
GR_DP_DmStdDev = REFORM( GR_DP_DmStdDev, countactual, nswp )
GR_DP_N2StdDev = REFORM( GR_DP_N2StdDev, countactual, nswp )
GR_blockage=REFORM(GR_blockage, countactual, nswp )

zcor = REFORM( zcor, countactual, nswp )
rain3 = REFORM( rain3, countactual, nswp )
DPR_Dm = REFORM( DPR_Dm, countactual, nswp )
DPR_Nw = REFORM( DPR_Nw, countactual, nswp )
top = REFORM( top, countactual, nswp )
botm = REFORM( botm, countactual, nswp )
lat = REFORM( lat, countactual, nswp )
lon = REFORM( lon, countactual, nswp )
dpr_lat = REFORM( dpr_lat, countactual, nswp )
dpr_lon = REFORM( dpr_lon, countactual, nswp )
rnType = REFORM( rnType, countactual, nswp )
landOceanFlag = REFORM( landOceanFlag, countactual, nswp )
nearSurfRain = REFORM( nearSurfRain, countactual, nswp )
if myflags.have_mrms eq 1 then begin
	mrmsrrlow = REFORM( mrmsrrlow, countactual, nswp )
	mrmsrrmed = REFORM( mrmsrrmed, countactual, nswp )
	mrmsrrhigh = REFORM( mrmsrrhigh, countactual, nswp )
	mrmsrrveryhigh = REFORM( mrmsrrveryhigh, countactual, nswp )
	mrmsgrlow = REFORM( mrmsgrlow, countactual, nswp )
	mrmsgrmed = REFORM( mrmsgrmed, countactual, nswp )
	mrmsgrhigh = REFORM( mrmsgrhigh, countactual, nswp )
	mrmsgrveryhigh = REFORM( mrmsgrveryhigh, countactual, nswp )
	mrmsptlow = REFORM( mrmsptlow, countactual, nswp )
	mrmsptmed = REFORM( mrmsptmed, countactual, nswp )
	mrmspthigh = REFORM( mrmspthigh, countactual, nswp )
	mrmsptveryhigh = REFORM( mrmsptveryhigh, countactual, nswp )
	mrmsrqiplow = REFORM( mrmsrqiplow, countactual, nswp )
	mrmsrqipmed = REFORM( mrmsrqipmed, countactual, nswp )
	mrmsrqiphigh = REFORM( mrmsrqiphigh, countactual, nswp )
	mrmsrqipveryhigh = REFORM( mrmsrqipveryhigh, countactual, nswp )
endif
if myflags.have_GR_SWE eq 1 then begin
	swedp = REFORM(swedp, countactual, nswp )
	swe25 = REFORM(swe25, countactual, nswp )
	swe50 = REFORM(swe50, countactual, nswp )
	swe75 = REFORM(swe75, countactual, nswp )
endif
pr_index = REFORM( pr_index, countactual, nswp )
clutterStatus = REFORM( clutterStatus, countactual, nswp )
BBHeight = REFORM( BBHeight, countactual, nswp )
pia = REFORM( pia, countactual, nswp )
stmTopHgt = REFORM( stmTopHgt, countactual, nswp )
IF ( N_ELEMENTS(pctAbvThresh) EQ 1 ) THEN BEGIN
   pctgoodpr = REFORM( pctgoodpr, countactual, nswp )
   pctgoodgv =  REFORM( pctgoodgv, countactual, nswp )
   pctgoodrain = REFORM( pctgoodrain, countactual, nswp )
   pctgoodDprDm = REFORM( pctgoodDprDm, countactual, nswp )
   pctgoodDprNw = REFORM( pctgoodDprNw, countactual, nswp )
   pctgoodrcgv = REFORM( pctgoodrcgv, countactual, nswp )
   pctgoodrpgv = REFORM( pctgoodrpgv, countactual, nswp )
   pctgoodrrgv = REFORM( pctgoodrrgv, countactual, nswp )
   pctgoodzdrgv = REFORM(pctgoodzdrgv, countactual, nswp )
   pctgoodkdpgv = REFORM(pctgoodkdpgv, countactual, nswp )
   pctgoodRHOhvgv = REFORM(pctgoodRHOhvgv, countactual, nswp )
   pctgoodhidgv = REFORM(pctgoodhidgv, countactual, nswp )
   pctgooddzerogv = REFORM(pctgooddzerogv, countactual, nswp )
   pctgoodnwgv = REFORM(pctgoodnwgv, countactual, nswp )
   pctgoodDmgv = REFORM(pctgoodDmgv, countactual, nswp )
   pctgoodN2gv = REFORM(pctgoodN2gv, countactual, nswp )
ENDIF

; - - - - - - - - - - - - - - - - - - - - - - - -

; For each 'column' of data, find the maximum GR reflectivity value for the
;  footprint, and use this to define a GR match to the DPR-indicated rain type.
;  Using Default GR dBZ thresholds of >=35 for "GV Convective" and <=25 for 
;  "GV Stratiform", or other GR dBZ thresholds provided as user parameters,
;  set DPR rain type to "other" (3) where PR type is Convective and GR isn't, or
;  DPR is Stratiform and GR indicates Convective.  For GR reflectivities between
;  'gvstratiform' and 'gvconvective' thresholds, leave the DPR rain type as-is.

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
   print, "Leaving DPR Convective Rain Type assignments unchanged."
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
   print, "Leaving DPR Stratiform Rain Type assignments unchanged."
ENDELSE

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
idxhgtdef = where( botm GT 0.0 AND top GT 0.0, counthgtdef )
IF ( counthgtdef GT 0 ) THEN BEGIN
   IF keyword_set(bb_relative) THEN beamhgt[idxhgtdef] = $
        (top[idxhgtdef]+botm[idxhgtdef])/2 - meanbb + 6.0 $
   ELSE beamhgt[idxhgtdef] = (top[idxhgtdef]+botm[idxhgtdef])/2
   hgtcat[idxhgtdef] = FIX((beamhgt[idxhgtdef]-halfdepth)/(halfdepth*2.0))
  ; deal with points that are too low or too high with respect to the
  ; height layers that have been defined
   idx2low = where( beamhgt[idxhgtdef] LT halfdepth, n2low )
   if n2low GT 0 then hgtcat[idxhgtdef[idx2low]] = -1
   idx2high = where( beamhgt[idxhgtdef] GT (heights[nhgtcats-1]+halfdepth), n2high )
   if n2high GT 0 then hgtcat[idxhgtdef[idx2high]] = -2
ENDIF ELSE BEGIN
   message, "No valid beam heights, quitting case.", /INFO
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
      print, "In fprep_dpr_geo_match_profiles, assuming meters for bbwidth ", $
             "value provided: ", bbwidth, ", converting to km."
      bbwidth = bbwidth/1000.0
   ENDIF
   IF bbwidth GT 2.0 OR bbwidth LT 0.2 THEN BEGIN
      print, "In fprep_dpr_geo_match_profiles, overriding outlier bbwidth value:", $
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
   idxblo = WHERE( ( top GT 0.0 ) AND ( top LT (meanbb-bbwidth) ), countblo )
   num_in_BB_Cat[1] = countblo
   IF countblo GT 0 THEN bbProx[idxblo] = 1
   idxin = WHERE( (botm LE (meanbb+bbwidth)) AND (top GE (meanbb-bbwidth)), countin )
   num_in_BB_Cat[2] = countin
   IF countin GT 0 THEN bbProx[idxin] = 2
ENDIF
; - - - - - - - - - - - - - - - - - - - - - - - -

; apply the S-to-Ku band adjustment if parameter s2ku is set

IF ( s2ku ) THEN BEGIN
   IF (countabv+countblo) GT 0 THEN BEGIN
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
   ENDIF ELSE BEGIN
      print, "==========================================================="
      print, "No above- or below-BB points found for S-to-Ku adjustments."
      print, "==========================================================="
   ENDELSE
ENDIF

; - - - - - - - - - - - - - - - - - - - - - - - -

; assign science data pointer variables provided as optional keyword parameters

IF PTR_VALID(ptr_gvz) THEN *ptr_gvz = gvz
IF PTR_VALID(ptr_gvzmax) THEN *ptr_gvzmax = gvzmax
IF PTR_VALID(ptr_gvzstddev) THEN *ptr_gvzstddev = gvzstddev
IF PTR_VALID(ptr_gvrc) THEN *ptr_gvrc = gvrc
IF PTR_VALID(ptr_gvrcmax) THEN *ptr_gvrcmax = gvrcmax
IF PTR_VALID(ptr_gvrcstddev) THEN *ptr_gvrcstddev = gvrcstddev
IF PTR_VALID(ptr_gvrp) THEN *ptr_gvrp = gvrp
IF PTR_VALID(ptr_gvrpmax) THEN *ptr_gvrpmax = gvrpmax
IF PTR_VALID(ptr_gvrpstddev) THEN *ptr_gvrpstddev = gvrpstddev
IF PTR_VALID(ptr_gvrr) THEN *ptr_gvrr = gvrr
IF PTR_VALID(ptr_gvrrmax) THEN *ptr_gvrrmax = gvrrmax
IF PTR_VALID(ptr_gvrrstddev) THEN *ptr_gvrrstddev = gvrrstddev
IF PTR_VALID(ptr_GR_DP_Zdr) THEN *ptr_GR_DP_Zdr = GR_DP_Zdr
IF PTR_VALID(ptr_GR_DP_Kdp) THEN *ptr_GR_DP_Kdp = GR_DP_Kdp
IF PTR_VALID(ptr_GR_DP_RHOhv) THEN *ptr_GR_DP_RHOhv = GR_DP_RHOhv
IF PTR_VALID(ptr_GR_DP_Dzero) THEN *ptr_GR_DP_Dzero = GR_DP_Dzero
IF PTR_VALID(ptr_GR_DP_Nw) THEN *ptr_GR_DP_Nw = GR_DP_Nw
IF PTR_VALID(ptr_GR_DP_ZdrMax) THEN *ptr_GR_DP_ZdrMax = GR_DP_ZdrMax
IF PTR_VALID(ptr_GR_DP_KdpMax) THEN *ptr_GR_DP_KdpMax = GR_DP_KdpMax
IF PTR_VALID(ptr_GR_DP_RHOhvMax) THEN *ptr_GR_DP_RHOhvMax = GR_DP_RHOhvMax
IF PTR_VALID(ptr_GR_DP_DzeroMax) THEN *ptr_GR_DP_DzeroMax = GR_DP_DzeroMax
IF PTR_VALID(ptr_GR_DP_NwMax) THEN *ptr_GR_DP_NwMax = GR_DP_NwMax
IF PTR_VALID(ptr_GR_DP_ZdrStdDev) THEN *ptr_GR_DP_ZdrStdDev = GR_DP_ZdrStdDev
IF PTR_VALID(ptr_GR_DP_KdpStdDev) THEN *ptr_GR_DP_KdpStdDev = GR_DP_KdpStdDev
IF PTR_VALID(ptr_GR_DP_RHOhvStdDev) THEN *ptr_GR_DP_RHOhvStdDev = GR_DP_RHOhvStdDev
IF PTR_VALID(ptr_GR_DP_DzeroStdDev) THEN *ptr_GR_DP_DzeroStdDev = GR_DP_DzeroStdDev
IF PTR_VALID(ptr_GR_DP_NwStdDev) THEN *ptr_GR_DP_NwStdDev = GR_DP_NwStdDev
IF PTR_VALID(ptr_GR_DP_HID) THEN *ptr_GR_DP_HID = GR_DP_HIDnew
IF PTR_VALID(ptr_mode_HID) THEN *ptr_mode_HID = mode_HID
IF nc_file_version GE 1.3 THEN BEGIN
   IF PTR_VALID(ptr_GR_DP_Dm) THEN *ptr_GR_DP_Dm = GR_DP_Dm
   IF PTR_VALID(ptr_GR_DP_N2) THEN *ptr_GR_DP_N2 = GR_DP_N2
   IF PTR_VALID(ptr_GR_DP_DmMax) THEN *ptr_GR_DP_DmMax = GR_DP_DmMax
   IF PTR_VALID(ptr_GR_DP_N2Max) THEN *ptr_GR_DP_N2Max = GR_DP_N2Max
   IF PTR_VALID(ptr_GR_DP_DmStdDev) THEN *ptr_GR_DP_DmStdDev = GR_DP_DmStdDev
   IF PTR_VALID(ptr_GR_DP_N2StdDev) THEN *ptr_GR_DP_N2StdDev = GR_DP_N2StdDev
ENDIF ELSE BEGIN
   IF PTR_VALID(ptr_GR_DP_Dm) THEN ptr_free, ptr_GR_DP_Dm
   IF PTR_VALID(ptr_GR_DP_N2) THEN ptr_free, ptr_GR_DP_N2
   IF PTR_VALID(ptr_GR_DP_DmMax) THEN ptr_free, ptr_GR_DP_DmMax
   IF PTR_VALID(ptr_GR_DP_N2Max) THEN ptr_free, ptr_GR_DP_N2Max
   IF PTR_VALID(ptr_GR_DP_DmStdDev) THEN ptr_free, ptr_GR_DP_DmStdDev
   IF PTR_VALID(ptr_GR_DP_N2StdDev) THEN ptr_free, ptr_GR_DP_N2StdDev
ENDELSE
IF nc_file_version GT 1.1 THEN BEGIN
   IF PTR_VALID(ptr_GR_blockage) THEN *ptr_GR_blockage = GR_blockage
ENDIF ELSE BEGIN
   IF ptr_valid(ptr_GR_blockage) THEN ptr_free, ptr_GR_blockage
ENDELSE

IF PTR_VALID(ptr_zcor) THEN *ptr_zcor = zcor
IF PTR_VALID(ptr_rain3) THEN *ptr_rain3 = rain3
IF PTR_VALID(ptr_dprDm) THEN *ptr_dprDm = DPR_Dm
IF PTR_VALID(ptr_dprNw) THEN *ptr_dprNw = DPR_Nw
IF PTR_VALID(ptr_top) THEN *ptr_top = top
IF PTR_VALID(ptr_botm) THEN *ptr_botm = botm
IF PTR_VALID(ptr_lat) THEN *ptr_lat = lat
IF PTR_VALID(ptr_lon) THEN *ptr_lon = lon
IF PTR_VALID(ptr_dpr_lat) THEN *ptr_dpr_lat = dpr_lat
IF PTR_VALID(ptr_dpr_lon) THEN *ptr_dpr_lon = dpr_lon
IF PTR_VALID(ptr_pia) THEN *ptr_pia = pia
IF PTR_VALID(ptr_stmTopHgt) THEN *ptr_stmTopHgt = stmTopHgt
IF PTR_VALID(ptr_nearSurfRain) THEN *ptr_nearSurfRain = nearSurfRain

if myflags.have_mrms eq 1 then begin

	IF PTR_VALID(ptr_mrmsrrlow) THEN *ptr_mrmsrrlow = mrmsrrlow
	IF PTR_VALID(ptr_mrmsrrmed) THEN *ptr_mrmsrrmed = mrmsrrmed
	IF PTR_VALID(ptr_mrmsrrhigh) THEN *ptr_mrmsrrhigh = mrmsrrhigh
	IF PTR_VALID(ptr_mrmsrrveryhigh) THEN *ptr_mrmsrrveryhigh = mrmsrrveryhigh
	IF PTR_VALID(ptr_mrmsgrlow) THEN *ptr_mrmsgrlow = mrmsgrlow
	IF PTR_VALID(ptr_mrmsgrmed) THEN *ptr_mrmsgrmed = mrmsgrmed
	IF PTR_VALID(ptr_mrmsgrhigh) THEN *ptr_mrmsgrhigh = mrmsgrhigh
	IF PTR_VALID(ptr_mrmsgrveryhigh) THEN *ptr_mrmsgrveryhigh = mrmsgrveryhigh
	IF PTR_VALID(ptr_mrmsptlow) THEN *ptr_mrmsptlow = mrmsptlow
	IF PTR_VALID(ptr_mrmsptmed) THEN *ptr_mrmsptmed = mrmsptmed
	IF PTR_VALID(ptr_mrmspthigh) THEN *ptr_mrmspthigh = mrmspthigh
	IF PTR_VALID(ptr_mrmsptveryhigh) THEN *ptr_mrmsptveryhigh = mrmsptveryhigh
	IF PTR_VALID(ptr_mrmsrqiplow) THEN *ptr_mrmsrqiplow = mrmsrqiplow
	IF PTR_VALID(ptr_mrmsrqipmed) THEN *ptr_mrmsrqipmed = mrmsrqipmed
	IF PTR_VALID(ptr_mrmsrqiphigh) THEN *ptr_mrmsrqiphigh = mrmsrqiphigh
	IF PTR_VALID(ptr_mrmsrqipveryhigh) THEN *ptr_mrmsrqipveryhigh = mrmsrqipveryhigh
	IF PTR_VALID(ptr_MRMS_HID) AND mygeometa.num_MRMS_categories GT 0 THEN $
	   *ptr_MRMS_HID = MRMS_HID
endif
  
if myflags.have_GR_SWE eq 1 then begin
	IF PTR_VALID(ptr_swedp) THEN *ptr_swedp = swedp
	IF PTR_VALID(ptr_swe25) THEN *ptr_swe25 = swe25
	IF PTR_VALID(ptr_swe50) THEN *ptr_swe50 = swe50
	IF PTR_VALID(ptr_swe75) THEN *ptr_swe75 = swe75
endif

IF PTR_VALID(ptr_rnType) THEN *ptr_rnType = rnType
IF PTR_VALID(ptr_landOcean) THEN *ptr_landOcean = landOceanFlag
IF PTR_VALID(ptr_clutterStatus) THEN *ptr_clutterStatus=clutterStatus
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
   IF PTR_VALID(ptr_pctgoodDprDm) THEN *ptr_pctgoodDprDm = pctgoodDprDm
   IF PTR_VALID(ptr_pctgoodDprNw) THEN *ptr_pctgoodDprNw = pctgoodDprNw
   IF PTR_VALID(ptr_pctgoodrcgv) THEN *ptr_pctgoodrcgv = pctgoodrcgv
   IF PTR_VALID(ptr_pctgoodrpgv) THEN *ptr_pctgoodrpgv = pctgoodrpgv
   IF PTR_VALID(ptr_pctgoodrrgv) THEN *ptr_pctgoodrrgv = pctgoodrrgv
   IF PTR_VALID(ptr_pctgoodzdrgv) THEN *ptr_pctgoodzdrgv = pctgoodzdrgv
   IF PTR_VALID(ptr_pctgoodkdpgv) THEN *ptr_pctgoodkdpgv = pctgoodkdpgv
   IF PTR_VALID(ptr_pctgoodRHOhvgv) THEN *ptr_pctgoodRHOhvgv = pctgoodRHOhvgv
   IF PTR_VALID(ptr_pctgoodhidgv) THEN *ptr_pctgoodhidgv = pctgoodhidgv
   IF PTR_VALID(ptr_pctgooddzerogv) THEN *ptr_pctgooddzerogv = pctgooddzerogv
   IF PTR_VALID(ptr_pctgoodnwgv) THEN *ptr_pctgoodnwgv = pctgoodnwgv
   IF nc_file_version GE 1.3 THEN BEGIN
      IF PTR_VALID(ptr_pctgoodDmgv) THEN *ptr_pctgoodDmgv = pctgoodDmgv
      IF PTR_VALID(ptr_pctgoodN2gv) THEN *ptr_pctgoodN2gv = pctgoodN2gv
   ENDIF ELSE BEGIN
      IF PTR_VALID(ptr_pctgoodDmgv) THEN ptr_free, ptr_pctgoodDmgv
      IF PTR_VALID(ptr_pctgoodN2gv) THEN ptr_free, ptr_pctgoodN2gv
   ENDELSE
ENDIF

status = 0   ; set to SUCCESS

; TAB 8/15/18 added 
IF PTR_VALID(ptr_bbHeight) THEN *ptr_bbHeight = BBHeight

noMSdata:   ; skip to here if no MS swath data exist

; assign metadata pointer variables provided as optional keyword parameters,
; even if no MS data samples exist in the greater GR/DPR overlap area

IF PTR_VALID(ptr_geometa) THEN *ptr_geometa = mygeometa
IF PTR_VALID(ptr_sweepmeta) THEN *ptr_sweepmeta = mysweeps
IF PTR_VALID(ptr_sitemeta) THEN *ptr_sitemeta = mysite
IF PTR_VALID(ptr_fieldflags) THEN *ptr_fieldflags = myflags
IF PTR_VALID(ptr_filesmeta) THEN *ptr_filesmeta = myfiles


errorExit:

return, status
END
