;===============================================================================
;+
; Copyright © 2013, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; read_dpr_geo_match_netcdf_v7.pro           Morris/SAIC/GPM_GV      July 2013
;
; DESCRIPTION
; -----------
; Reads caller-specified data and metadata from DPR-GR matchup netCDF files. 
; Returns status value: 0 if successful read, 1 if unsuccessful or internal
; errors or inconsistencies occur.  File must be read-ready (unzipped/
; uncompressed) before calling this function.  If DIMS_ONLY is set, then only
; the matchup file version and the dimensions for the number of footprints,
; the number of sweep levels, and the number of HID categories in the matchup
; file are read and returned in the 'matchupmeta' structure, which must also be
; provided as an I/O parameter.
;
; All global attributes and all regular variables defined for all DPR-GR matchup
; versions must be defined in the relevant CASE statements in this module,
; whether or not the variable is returned in an I/O parameter, or an error will
; result.  It is no longer necessary to indicate which netCDF variables apply to
; a given matchup file version, as long as this module recognizes any netCDF
; variable or attribute present in any version.
;
; This function is intended to be called twice in a row in normal usage.  The
; first call is with the DIMS_ONLY keyword set and the matchupmeta keyword and
; value (a structure of type dpr_geo_match_meta) provided.  The dimensions of
; the array variables are returned in the matchupmeta structure and are used
; to pre-dimension the variables to be read from the netCDF file in the second
; call to read_dpr_geo_match_netcdf(), where the elements needed from the file
; are requested by passing their keyword/value parameter.  Any variable not
; correctly dimensioned will be redimensioned when the associated variable is
; read from the netCDF file and assigned as its I/O parameter value, so the
; predimensioning is not critical, but the predimensioning can help avoid any
; IDL problems with large numbers of I/O parameters being resized.  See the
; function in fprep_dpr_geo_match_profiles.pro for an example of how this
; function is intended to be called.
;
;
; PARAMETERS
; ----------
; ncfile               STRING, Full file pathname to DPR netCDF grid file (Input)
;
; dims_only            Optional binary parameter, see DESCRIPTION.  If set to
;                        ON, then the matchupmeta parameter must be provided,
;                        and all other keyword parameters are ignored.  (Input)
;
; matchupmeta          Structure holding general and algorithmic parameters, of
;                        type dpr_geo_match_meta defined in IDL "Include" file
;                        dpr_geo_match_nc_structs.inc (I/O)
; sweepsmeta           Array of Structures holding sweep elevation angles,
;                        and sweep start times in unix ticks and ascii text, of
;                        type gr_sweep_meta defined in IDL "Include" file
;                        dpr_geo_match_nc_structs.inc (I/O)
; sitemeta             Structure holding GV site location parameters, of
;                        type gr_site_meta defined in IDL "Include" file
;                        dpr_geo_match_nc_structs.inc (I/O)
; fieldFlags           Structure holding "data exists" flags for DPR science
;                        data variables, of type dpr_gr_field_flags defined in
;                        IDL "Include" file dpr_geo_match_nc_structs.inc (I/O)
; filesmeta            Structure holding DPR and GR file names used in matchup,
;                        of type dpr_gr_input_files defined in IDL "Include"
;                        file dpr_geo_match_nc_structs.inc (I/O)
;
; threeDreflect        FLOAT 2-D array of horizontally-averaged, QC'd GV
;                        reflectivity, dBZ (I/O)
; threeDreflectMax     FLOAT 2-D array, Maximum value of GV reflectivity
;                      bins included in threeDreflect, dBZ (I/O)
; threeDreflectStdDev  FLOAT 2-D array, Standard Deviation of GV reflectivity
;                      bins included in threeDreflect, dBZ (I/O)
; GR_RC_rainrate       FLOAT 2-D array of horizontally-averaged, QC'd GV RC
;                      rain rate, mm/h (I/O)
; GR_RC_rainrate_Max    FLOAT 2-D array, Maximum value of GV RC rain rate
;                      bins included in GR_RC_rainrate, mm/h (I/O)
; GR_RC_rainrate_StdDev FLOAT 2-D array, Standard Deviation of GV RC rain rate
;                      bins included in GR_RC_rainrate, mm/h (I/O)
; GR_RP_rainrate       FLOAT 2-D array of horizontally-averaged, QC'd GV RP
;                      rain rate, mm/h (I/O)
; GR_RP_rainrate_Max    FLOAT 2-D array, Maximum value of GV RP rain rate
;                      bins included in GR_RP_rainrate, mm/h (I/O)
; GR_RP_rainrate_StdDev FLOAT 2-D array, Standard Deviation of GV RP rain rate
;                      bins included in GR_RP_rainrate, mm/h (I/O)
; GR_RR_rainrate       FLOAT 2-D array of horizontally-averaged, QC'd GV RR
;                      rain rate, mm/h (I/O)
; GR_RR_rainrate_Max    FLOAT 2-D array, Maximum value of GV RR rain rate
;                      bins included in GR_RR_rainrate, mm/h (I/O)
; GR_RR_rainrate_StdDev FLOAT 2-D array, Standard Deviation of GV RR rain rate
;                      bins included in GR_RR_rainrate, mm/h (I/O)
; GR_Zdr            FLOAT 2-D array of volume-matched GR mean Zdr
;                        (differential reflectivity)
; GR_Zdr_Max         As above, but sample maximum of Zdr
; GR_Zdr_StdDev      As above, but sample standard deviation of Zdr
; GR_Kdp            FLOAT 2-D array of volume-matched GR mean Kdp (specific
;                        differential phase)
; GR_Kdp_Max         As above, but sample maximum of Kdp
; GR_Kdp_StdDev      As above, but sample standard deviation of Kdp
; GR_RHOhv          FLOAT 2-D array of volume-matched GR mean RHOhv
;                        (co-polar correlation coefficient)
; GR_RHOhv_Max       As above, but sample maximum of RHOhv
; GR_RHOhv_StdDev    As above, but sample standard deviation of RHOhv
; GR_HID            FLOAT 2-D array of volume-matched GR Hydrometeor ID (HID)
;                         category (count of GR bins in each HID category)
; GR_Dzero          FLOAT 2-D array of volume-matched GR mean D0 (Median
;                        volume diameter)
; GR_Dzero_Max       As above, but sample maximum of Dzero
; GR_Dzero_StdDev    As above, but sample standard deviation of Dzero
; GR_Nw             FLOAT 2-D array of volume-matched GR mean Nw (Normalized
;                        intercept parameter)
; GR_Nw_Max          As above, but sample maximum of Nw
; GR_Nw_StdDev       As above, but sample standard deviation of Nw
; GR_Dm             FLOAT 2-D array of volume-matched GR mean Dm (Retrieved
;                        Median diameter)
; GR_Dm_Max          As above, but sample maximum of Dm
; GR_Dm_StdDev       As above, but sample standard deviation of Dm
; GR_N2             FLOAT 2-D array of volume-matched GR mean N2 (Normalized
;                        intercept parameter, Tokay algorithm)
; GR_N2_Max          As above, but sample maximum of N2
; GR_N2_StdDev       As above, but sample standard deviation of N2
; GR_blockage       FLOAT 2-D array of volume-matched GR mean beam blockage
;
; gvexpect             INT number of GV radar bins averaged for the above (I/O)
; gvreject             INT number of bins below GV dBZ cutoff in threeDreflect
;                        set of variables (I/O)
; gv_rc_reject         INT number of bins below rainrate cutoff in
;                        GR_RC_rainrate set of variables (I/O)
; gv_rp_reject         INT number of bins below rainrate cutoff in
;                        GR_RP_rainrate set of variables (I/O)
; gv_rr_reject         INT number of bins below rainrate cutoff in
;                        GR_RR_rainrate set of variables (I/O)
; gv_zdr_reject        INT number of missing-data bins in GR_Zdr
;                        set of variables (I/O)
; gv_kdp_reject        INT number of missing-data bins in GR_Kdp
;                        set of variables (I/O)
; gv_RHOhv_reject      INT number of missing-data bins in GR_RHOhv
;                        set of variables (I/O)
; gv_hid_reject        INT number of missing-data bins in GR_HID
;                        set of variables (I/O)
; gv_Dzero_reject      INT number of missing-data bins in GR_Dzero
;                        set of variables (I/O)
; gv_Nw_reject         INT number of missing-data bins in GR_Nw
;                        set of variables (I/O)
; gv_Dm_reject         INT number of missing-data bins in GR_Dm
;                        set of variables (I/O)
; gv_N2_reject         INT number of missing-data bins in GR_N2
;                        set of variables (I/O)
;
; dprexpect            INT number of DPR radar bins averaged for ZFactorMeasured,
;                        correctZfactor, and rain (I/O)
; ZFactorMeasured      FLOAT 2-D array of vertically-averaged raw calibrated DPR
;                        reflectivity, dBZ (I/O)
; zrawreject           INT number of DPR bins below dBZ cutoff in above (I/O)
; correctZfactor       FLOAT 2-D array of vertically-averaged, attenuation-
;                        corrected DPR reflectivity, dBZ (I/O)
; zcorreject           INT number of DPR bins below dBZ cutoff in above (I/O)
; piaFinal             FLOAT array of DPR 2A piaFinal estimate, dBZ (I/O)
; rain                 FLOAT 2-D array of vertically-averaged DPR estimated rain
;                        rate, mm/h (I/O)
; rainreject           INT number of DPR bins below rainrate cutoff in above (I/O)
; dpr_dm               FLOAT 2-D array of vertically-averaged DPR mean drop
;                        diameter, mm (I/O)
; dprdmreject          INT number of DPR bins with MISSING values in above (I/O)
; dpr_nw               FLOAT 2-D array of vertically-averaged DPR mean Nw
;                        (Normalized intercept parameter) (I/O)
; dprnwreject          INT number of DPR bins with MISSING values in above (I/O)
; epsilon              FLOAT 2-D array of vertically-averaged DPR epsilon (I/O)
; epsilonreject        INT number of DPR bins below 0.0 in above (I/O)
;
; topHeight            FLOAT 2-D array of mean GV beam top over DPR footprint
;                        (I/O)
; bottomHeight         FLOAT 2-D array of mean GV beam bottoms over DPR footprint
;                        (I/O)
; xCorners             FLOAT 3-D array of parallax-adjusted DPR footprint corner
;                        X-coordinates in km, 4 per footprint.(I/O)
; yCorners             FLOAT 3-D array of parallax-adjusted DPR footprint corner
;                        Y-coordinates in km, 4 per footprint.(I/O)
; latitude             FLOAT 2-D array of parallax-adjusted DPR footprint center
;                        latitude, degrees (I/O)
; longitude            FLOAT 2-D array of parallax-adjusted DPR footprint center
;                        longitude, degrees (I/O)
; latitude             FLOAT array of parallax-adjusted DPR footprint center
;                        latitude, degrees North (I/O)
; longitude            FLOAT array of parallax-adjusted DPR footprint center
;                        longitude, degrees East (I/O)
; DPRlatitude          FLOAT array of surface intersection DPR footprint center
;                        latitude, degrees (I/O)
; DPRlongitude         FLOAT array of surface intersection DPR footprint center
;                        longitude, degrees (I/O)
; LandSurfaceType      INT array of underlying surface type, category (I/O)
; PrecipRateSurface    FLOAT array of DPR estimated rain rate at surface,
;                         mm/h (I/O)
; SurfPrecipRate       As above, but from combined DPR/GMI 2B-COMB algorithm
; BBheight             INT array of DPR estimated bright band height,
;                         meters (I/O)
; BBstatus             INT array of DPR bright band estimation status, coded
;                         category (I/O)
; qualityData          LONG array of DPR algorithm retrieval quality flags,
;                         with meanings defined for each bit (I/O).  Refer to
;                         the current "File Specification For GPM Products" PPS
;                         document for details of the bit meanings
; clutterStatus        INT array of DPR 'clutterStatus' flag, coded category (I/O)
; FlagPrecip           INT array of DPR rain/no-rain flag, category (I/O)
; TypePrecip           INT array of DPR derived raincloud type, category (I/O)
; rayIndex             LONG array of DPR product ray,scan IDL array index,
;                        relative to the original DPR/Ka/Ku product file (I/O)
;
; RETURNS
; -------
; status               INT - Status of call to function, 0=success, 1=failure
;
; HISTORY
; -------
; 07/12/13  Morris/SAIC/GPM-GV
; - Created from read_geo_match_netcdf.pro.
; 7/24/13 by Bob Morris, GPM GV (SAIC)
;  - Added GR rainrate Mean/StdDev/Max data variables and presence flags and
;    gv_rr_reject variable.
; 4/28/14 by Bob Morris, GPM GV (SAIC)
;  - Removed GR StdDev/Max data presence flag variables.  Renamed numerous
;    netCDF variable names to line up with first operational GRtoDPR matchup
;    file definition.  Changed reading of DPR_Version global from int to char
;    type.
; 5/1/14 by Bob Morris, GPM GV (SAIC)
;  - Took scan type (NS,MS,HS) into account in computing rayIndex.
; 6/5/14 by Bob Morris, GPM GV (SAIC)
;  - Added reading of new GR variables HID, D0, Nw, Zdr, Kdp, and RHOhv Mean,
;    Max, StdDev, and "n_rejected". Added reading of their matching IDs in
;    global variables "GV_UF_xxx_field". Brought keywords and parameters in line
;    with those in read_geo_match_netcdf.pro.
; 6/27/14 by Bob Morris, GPM GV (SAIC)
;  - Added reading of new DPR variables Dm, Nw, and their n_rejected values, and
;    their associated have_paramDSD flag.
; 11/04/14 by Bob Morris, GPM GV (SAIC)
;  - Added processing of GR RC and RP rainrate fields for version 1.1 file, and
;    renamed GR_rainrate* variables to GR_RR_rainrate*.
; 12/04/14 by Bob Morris, GPM GV (SAIC)
;  - Added reading of have_paramDSD flag and writing to fieldFlags structure.
; 4/13/15 by Bob Morris, GPM GV (SAIC)
;  - Added reading of DPR variables piaFinal and heightStormTop and their
;    presence flags.
; 8/21/15 by Bob Morris, GPM GV (SAIC)
;  - Added reading of GR variables Dm and N2, their n_rejected values, and their
;    presence flags for version 1.2 files.
; 11/11/15 by Bob Morris, GPM GV (SAIC)
;  - Added reading of GR_blockage variable and its presence flag for version
;    1.21 files.
; 02/04/16 by Bob Morris, GPM GV (SAIC)
;  - Added reading of DPR zcor and zraw variables computed from range gates
;    averaged down from 125m to 250m resolution to match Z in 2B-DPRGMI.
; 02/29/16 by Bob Morris, GPM GV (SAIC)
;  - Added reading of GV_UF_DM_field and GV_UF_N2_field to populate into the
;    matchupmeta structure.
; 07/28/16 by Bob Morris, GPM GV (SAIC)
;  - Added reading of DPR have_Epsilon, Epsilon and n_dpr_epsilon_rejected
;    variables for modified version 1.21.
;  - Disabled processing of 250-m averaged-down variables for 1.3.
; 11/15/16 by Bob Morris, GPM GV (SAIC)
;  - Restored processing of 250-m averaged-down variables for 1.3.  Added notes
;    to indicate that version 1.3 is to be reserved for matchups containing
;    these variables.
;  - Added reading of MaxZFactorMeasured250m variable for 1.3.
;
; 12/12/16 by Bob Morris, GPM GV (SAIC)
;  - Major rewrite to:
;    1) eliminate code duplication for each array variable read from the file
;       by moving duplicated code to a new function prepare_ncvar().  Also
;       moved included function sort_multi_d_array() from this code module to
;       prepare_ncvar.pro.
;    2) determine the variables and attributes actually present in the file
;       regardless of matchup version, and assign them to their associated I/O
;       variable.  Exit with an error if a variable/attribute in the file is
;       not recognized and handled
;    3) add the DIMS_ONLY option to just read and return the number of sweeps
;       and footprints in the matchup data arrays and the matchup file version,
;       skipping the reading of other netCDF file attributes/variables
;    4) test that the correct structure types are provided for the metadata
;       structure parameters
;    5) added reading and I/O assignment of previously overlooked netCDF
;       variables: qualityData, have_qualityData, and DPR_decluttered.
;
; 01/17/17 by Bob Morris, GPM GV (SAIC)
;  - Added check of IDL Version to determine whether the NCDF_LIST utility is
;    available (8.4.1 or later).  If earlier, use older NCDF utilities to build
;    the lists of global attributes and regular variables.
; 01/19/17 by Bob Morris, GPM GV (SAIC)
;  - Replaced assignment of structure typename using syntax var.TYPENAME, not
;    valid until IDL 8.4, with an explicit call to the TYPENAME(var) function
;    available in IDL 8.0 and later.
;  - Added MESSAGE command to exit with error if attempting to run under IDL
;    versions before 8.0.
; 06/20/18 by Bob Morris, GPM GV (SAIC)
;  - Added reading of new global variables PR_2APR_file and PR_2BPRTMI_File
;    and output to filesmeta struct to support PR version 8 processing.
; 09/04/18 Berendes, UAH
;  - Added mods for SWE variables
; 06/25/20  Berendes/UAH
; - changes for V07 files, FS and HS scans only
;
;
; EMAIL QUESTIONS OR COMMENTS AT:
;       https://pmm.nasa.gov/contact
;-
;===============================================================================

FUNCTION read_dpr_geo_match_netcdf_v7, ncfile, DIMS_ONLY=dims_only,          $
   ; metadata structures/parameters
    matchupmeta=matchupmeta, sweepsmeta=sweepsmeta, sitemeta=sitemeta,        $
    fieldflags=fieldFlags, filesmeta=filesmeta,                               $

   ; threshold/data completeness parameters for vert/horiz averaged values:
    gvexpect_int=gvexpect, gvreject_int=gvreject, dprexpect_int=dprexpect,    $
    zrawreject_int=zrawreject, zcorreject_int=zcorreject,                     $
    dpr250expect_int=dpr250expect, zraw250reject_int=zraw250reject,           $
    zcor250reject_int=zcor250reject, rainreject_int=rainreject,               $
    epsilonreject_int=epsilonreject, dpr_dm_reject_int=dpr_dm_reject,         $
    dpr_nw_reject_int=dpr_nw_reject, gv_rc_reject_int=gv_rc_reject,           $
    gv_rp_reject_int=gv_rp_reject, gv_rr_reject_int=gv_rr_reject,             $
    gv_hid_reject_int=gv_hid_reject, gv_dzero_reject_int=gv_dzero_reject,     $
    gv_nw_reject_int=gv_nw_reject, gv_dm_reject_int=gv_dm_reject,             $
    gv_n2_reject_int=gv_n2_reject, gv_zdr_reject_int=gv_zdr_reject,           $
    gv_kdp_reject_int=gv_kdp_reject, gv_RHOhv_reject_int=gv_RHOhv_reject,     $
    gv_swedp_reject_int=gv_swedp_reject, $
    gv_swe25_reject_int=gv_swe25_reject, $
    gv_swe50_reject_int=gv_swe50_reject, $
    gv_swe75_reject_int=gv_swe75_reject, $
    gv_swemqt_reject_int=gv_swemqt_reject, $
    gv_swemrms_reject_int=gv_swemrms_reject, $
    
   ; horizontally (GV) and vertically (DPR Z, rain) averaged values at elevs.:
    dbzgv=threeDreflect, dbzraw=ZFactorMeasured, dbzcor=ZFactorCorrected,     $
    dbz250raw=ZFactorMeasured250m, dbz250cor=ZFactorCorrected250m,            $
    max_dbz250raw=maxZFactorMeasured250m,                                     $
    rain3d=PrecipRate, DmDPRmean = DPR_Dm, NwDPRmean = DPR_Nw,                $
    epsilon3d=epsilon,                                                        $
    gvStdDev=threeDreflectStdDev, gvMax=threeDreflectMax,                     $
    rcgvMean=GR_RC_rainrate, rcgvMax=GR_RC_rainrate_Max,                      $
    rcgvStdDev=GR_RC_rainrate_StdDev, rpgvMean=GR_RP_rainrate,                $
    rpgvMax=GR_RP_rainrate_Max, rpgvStdDev=GR_RP_rainrate_StdDev,             $
    rrgvMean=GR_RR_rainrate, rrgvMax=GR_RR_rainrate_Max,                      $
    rrgvStdDev=GR_RR_rainrate_StdDev, dzerogvMean=GR_Dzero,                   $
    dzerogvMax=GR_Dzero_Max, dzerogvStdDev=GR_Dzero_StdDev,                   $
    nwgvMean=GR_Nw, nwgvMax=GR_Nw_Max, nwgvStdDev=GR_Nw_StdDev,               $
    dmgvMean=GR_Dm, dmgvMax=GR_Dm_Max, dmgvStdDev=GR_Dm_StdDev,               $
    n2gvMean=GR_N2, n2gvMax=GR_N2_Max, n2gvStdDev=GR_N2_StdDev,               $
    zdrgvMean=GR_Zdr, zdrgvMax=GR_Zdr_Max, zdrgvStdDev=GR_Zdr_StdDev,         $
    kdpgvMean=GR_Kdp, kdpgvMax=GR_Kdp_Max, kdpgvStdDev=GR_Kdp_StdDev,         $
    rhohvgvMean=GR_RHOhv, rhohvgvMax=GR_RHOhv_Max,                            $
    rhohvgvStdDev=GR_RHOhv_StdDev, GR_blockage=GR_blockage,                   $

   ; horizontally summarized GR Hydromet Identifier category at elevs.:
    hidgv=GR_HID,                                                             $

   ; spatial parameters for DPR and GV values at sweep elevations:
    topHeight=topHeight, bottomHeight=bottomHeight, xCorners=xCorners,        $
    yCorners=yCorners, latitude=latitude, longitude=longitude,                $

   ; spatial parameters for DPR at earth surface level:
    DPRlatitude=DPRlatitude, DPRlongitude=DPRlongitude,                       $

   ; MRMS RR variables
    mrmsrrlow=mrmsrrlow, $
    mrmsrrmed=mrmsrrmed, $
    mrmsrrhigh=mrmsrrhigh, $
    mrmsrrveryhigh=mrmsrrveryhigh, $
   ; MRMS guage ratio variables
    mrmsgrlow=mrmsgrlow, $
    mrmsgrmed=mrmsgrmed, $
    mrmsgrhigh=mrmsgrhigh, $
    mrmsgrveryhigh=mrmsgrveryhigh, $
   ; MRMS precip type histogram variables
    mrmsptlow=mrmsptlow, $
    mrmsptmed=mrmsptmed, $
    mrmspthigh=mrmspthigh, $
    mrmsptveryhigh=mrmsptveryhigh, $
   ; MRMS RQI percent variables
    mrmsrqiplow=mrmsrqiplow, $
    mrmsrqipmed=mrmsrqipmed, $
    mrmsrqiphigh=mrmsrqiphigh, $
    mrmsrqipveryhigh=mrmsrqipveryhigh, $
    
    ; snow variables
    swedp=swedp, $
; not using max, stddev at the moment
;    swedp_max=swedp_max, $
;    swedp_stddev=swedp_stddev, $
    swe25=swe25, $
    swe50=swe50, $
    swe75=swe75, $
    swemqt=swemqt, $
    swemrms=swemrms, $
    
   ; horizontally summarized GR Hydromet Identifier category at elevs.:
    hidmrms=mrmshid,                                                             $

   ; DPR science values at earth surface level, or as ray summaries:
    sfcraindpr=PrecipRateSurface, sfcraincomb=SurfPrecipRate, bbhgt=BBheight, $
    sfctype_int=LandSurfaceType, rainflag_int=FlagPrecip,                     $
    raintype_int=TypePrecip, pridx_long=rayIndex, BBstatus_int=bbstatus,      $
    piaFinal=piaFinal, heightStormTop_int=heightStormTop,                     $
    qualityData_long=qualityData, clutterStatus_int=clutterStatus


; "Include" file for DPR-product-specific parameters (i.e., RAYSPERSCAN):
@dpr_params_v7.inc

status = 0

IF FLOAT(!version.release) lt 8.0 THEN message, "Requires IDL 8.0 or later."

IF KEYWORD_SET(dims_only) THEN BEGIN
   IF N_ELEMENTS(matchupmeta) EQ 0 THEN BEGIN
      message, "DIMS_ONLY requested but no matchupmeta structure supplied.", 'INFO
      status=1
      goto, ErrorExit2    ; file not open yet
   ENDIF ELSE BEGIN
      IF STRUPCASE(TYPENAME(matchupmeta)) NE 'DPR_GEO_MATCH_META' THEN BEGIN
         message, "Incorrect matchupmeta structure type supplied.", 'INFO
         status=1
         goto, ErrorExit2
      ENDIF
   ENDELSE
ENDIF ELSE BEGIN
  ; check the type of any structures to be populated
   IF N_ELEMENTS(matchupmeta) NE 0 THEN BEGIN
      IF STRUPCASE(TYPENAME(matchupmeta)) NE 'DPR_GEO_MATCH_META' THEN BEGIN
         message, "Incorrect matchupmeta structure type supplied.", 'INFO
         status=1
         goto, ErrorExit2
      ENDIF
   ENDIF
   IF N_ELEMENTS(sweepsmeta) NE 0 THEN BEGIN
      IF STRUPCASE(TYPENAME(sweepsmeta)) NE 'GR_SWEEP_META' THEN BEGIN
         message, "Incorrect sweepsmeta structure type supplied.", 'INFO
         status=1
         goto, ErrorExit2
      ENDIF
   ENDIF
   IF N_ELEMENTS(sitemeta) NE 0 THEN BEGIN
      IF STRUPCASE(TYPENAME(sitemeta)) NE 'GR_SITE_META' THEN BEGIN
         message, "Incorrect sitemeta structure type supplied.", 'INFO
         status=1
         goto, ErrorExit2
      ENDIF
   ENDIF
   IF N_ELEMENTS(fieldFlags) NE 0 THEN BEGIN
      IF STRUPCASE(TYPENAME(fieldflags)) NE 'DPR_GR_FIELD_FLAGS' THEN BEGIN
         message, "Incorrect fieldFlags structure type supplied.", 'INFO
         status=1
         goto, ErrorExit2
      ENDIF
   ENDIF
   IF N_ELEMENTS(filesmeta) NE 0 THEN BEGIN
      IF STRUPCASE(TYPENAME(filesmeta)) NE 'DPR_GR_INPUT_FILES' THEN BEGIN
         message, "Incorrect filesmeta structure type supplied.", 'INFO
         status=1
         goto, ErrorExit2
      ENDIF
   ENDIF
ENDELSE

ncid1 = NCDF_OPEN( ncfile )
IF ( N_Elements(ncid1) EQ 0 ) THEN BEGIN
   print, ''
   print, "ERROR from read_dpr_geo_match_netcdf:"
   print, "File copy ", ncfile, " is not a valid netCDF file!"
   print, ''
   status = 1
   goto, ErrorExit
ENDIF

; determine the number of global attributes and check the name of the first one
; to verify that we have the correct type of file
attstruc=ncdf_inquire(ncid1)
IF ( attstruc.ngatts GT 0 ) THEN BEGIN
   typeversion = ncdf_attname(ncid1, 0, /global)
   IF ( typeversion NE 'DPR_Version' ) THEN BEGIN
      print, ''
      print, "ERROR from read_dpr_geo_match_netcdf:"
      print, "File copy ", ncfile, " is not a DPR-GR matchup file!"
      print, ''
      status = 1
      goto, ErrorExit    ; file is open, must close before returning
   ENDIF
ENDIF ELSE BEGIN
   print, ''
   print, "ERROR from read_dpr_geo_match_netcdf:"
   print, "File copy ", ncfile, " has no global attributes!"
   print, ''
   status = 1
   goto, ErrorExit
ENDELSE

; always determine the version of the matchup netCDF file first -- determines
; which variables can be retrieved
versid = NCDF_VARID(ncid1, 'version')
NCDF_ATTGET, ncid1, versid, 'long_name', vers_def_byte
vers_def = string(vers_def_byte)
IF ( vers_def ne 'Geo Match File Version' ) THEN BEGIN
   print, "ERROR from read_dpr_geo_match_netcdf:"
   print, "File ", ncfile, " is not a valid geo_match netCDF file!"
   status = 1
   goto, ErrorExit
ENDIF


; HANDLE THE VERSION AND DIMENSION-RELATED VALUES THAT ARE NEEDED
; FOR STRUCTURE matchupmeta
IF N_Elements(matchupmeta) NE 0 THEN BEGIN
     zdimid = NCDF_DIMID(ncid1, 'elevationAngle')  ; ALREADY HAVE THIS
     NCDF_DIMINQ, ncid1, zdimid, XDIMNAME, ncnz
     matchupmeta.num_sweeps = ncnz
     fpdimid = NCDF_DIMID(ncid1, 'fpdim')
     NCDF_DIMINQ, ncid1, fpdimid, FPDIMNAME, nprfp
     matchupmeta.num_footprints = nprfp
     hidimid = NCDF_DIMID(ncid1, 'hidim')
     NCDF_DIMINQ, ncid1, hidimid, HIDIMNAME, nhidcats
     matchupmeta.num_HID_categories = nhidcats
     NCDF_VARGET, ncid1, versid, ncversion  ; get/assign this variable again later
     matchupmeta.nc_file_version = ncversion
     ; MRMS categories
     MRMS_dimid = NCDF_DIMID(ncid1, 'mrms_mask')
;     if MRMS_dimid ne -1 then begin
     if MRMS_dimid ge 0 then begin
     	NCDF_DIMINQ, ncid1, MRMS_dimid, MRMSDIMNAME, mrmscats
     	matchupmeta.num_MRMS_categories = mrmscats
     endif else begin
        print,'No MRMS categories in data file'
        matchupmeta.num_MRMS_categories = 0;
     endelse

ENDIF

; skip the rest of the variable/attribute reading and assignment if caller only
; wanted the matchup variable dimensions (num_footprints,num_sweeps)
IF KEYWORD_SET(dims_only) THEN GOTO, EarlyExit    ; file is open, must close


; HANDLE THE ELEVATION ANGLE VARIABLE/DIMENSION, DETERMINE IF RESORTING IS NEEDED,
; AND CREATE ARRAY OF sweepsmeta STRUCTURES OVER EACH ELEVATION.  ALL OF THE
; I/O PROCESSING FOR THE sweepsmeta STRUCTURE IS HANDLED IN THIS BLOCK OF CODE,
; SO WE WILL IGNORE THIS SET OF VARIABLES LATER ON IN THE CODE

IF N_Elements(sweepsmeta) NE 0 THEN BEGIN
     zdimid = NCDF_DIMID(ncid1, 'elevationAngle')
     NCDF_DIMINQ, ncid1, zdimid, XDIMNAME, ncnz  ; number of sweeps/elevs.
     NCDF_VARGET, ncid1, 'elevationAngle', nc_zlevels
     elevorder = SORT(nc_zlevels)
     ascorder = INDGEN(ncnz)
     sortflag=0
     IF TOTAL( ABS(elevorder-ascorder) ) NE 0 THEN BEGIN
        PRINT, 'read_dpr_geo_match_netcdf(): ', $
               'Elevation angles not in order! Resorting data.'
        sortflag=1
     ENDIF
    ; write elevation-specific variables to structure in sorted order
     arr_structs = REPLICATE(sweepsmeta,ncnz)  ; need one struct per sweep/elev.
     arr_structs.elevationAngle = nc_zlevels[elevorder]
     NCDF_VARGET, ncid1, 'timeSweepStart', sweepticks
     arr_structs.timeSweepStart = sweepticks[elevorder]
     NCDF_VARGET, ncid1, 'atimeSweepStart', sweeptimetxtbyte
     arr_structs.atimeSweepStart = STRING(sweeptimetxtbyte[*,elevorder])
     sweepsmeta = arr_structs   ; reassign I/O structure to array of structures
ENDIF ELSE BEGIN
    ; always need to determine whether reordering of layers needs done, whether
    ; or not caller requests sweepsmeta parameter
     zdimid = NCDF_DIMID(ncid1, 'elevationAngle')
     NCDF_DIMINQ, ncid1, zdimid, XDIMNAME, ncnz  ; number of sweeps/elevs.
     NCDF_VARGET, ncid1, 'elevationAngle', nc_zlevels
     elevorder = SORT(nc_zlevels)
     ascorder = INDGEN(ncnz)
     sortflag=0
     IF TOTAL( ABS(elevorder-ascorder) ) NE 0 THEN BEGIN
        PRINT, 'read_dpr_geo_match_netcdf(): ', $
               'Elevation angles not in order! Resorting data.'
        sortflag=1
     ENDIF
ENDELSE

; define idxsort parameter passed to PREPARE_NCVAR() if variables on sweep levels
; need to be re-sorted after reading from file, otherwise leave it undefined to
; skip reordering and save processing time
IF (sortflag) THEN idxsort = TEMPORARY(elevorder)  ; don't need elevorder anymore


;============= PROCESS THE GLOBAL ATTRIBUTES FOUND IN THE FILE ==================

; Get the names of the global attributes in the file.  NCDF_LIST output has
; several lines of information preceding the list of global attributes when
; using the /GATT option, and the attributes list itself has to be parsed to
; separate the names from the attribute number and values.  Here are a couple of
; example attribute lines:
;           0  DPR_Version: V04A
;           1  DPR_ScanType: NS

; We will leave the calls to NCDF_LIST in the code for IDL 8.4.1 and later even
; though it is now redundant with the logic to use NCDF_ATTNAME and NCDF_VARINQ,
; in case the latter become unsupported in the future.

IF FLOAT(!version.release) gt 8.4 THEN BEGIN
   NCDF_LIST, ncfile, /GATT, out=alloutput, /QUIET
  ; we know how many global attributes are in the file, and we know that they are
  ; listed at the end of the NCDF_LIST output, so grab these lines:
   nout = N_ELEMENTS(alloutput)
   attsRaw = alloutput[(nout-attstruc.ngatts) : (nout-1)]
ENDIF ELSE BEGIN
  ; NCDF_LIST is not available before IDL 8.4.1, so we have to do things
  ; the old way if it is an older IDL version, while emulating NCDF_LIST
   attsraw = STRARR(attstruc.ngatts)
   FOR igat = 0,attstruc.ngatts-1 DO BEGIN
     ; get each attribute name one at a time and add to attsraw STRING array,
     ; formatted like NCDF_LIST does, except with the placeholder 'Foo' for the
     ; attribute value, e.g., " 0 DPR_Version : Foo" for " 0 DPR_Version : V04A"
      attsraw[igat] = STRING(igat) + ' ' + NCDF_ATTNAME(ncid1, /GLOBAL, igat) $
                      + " : Foo"
   ENDFOR
ENDELSE

; now do some string magic to split the 3 parts of the line apart on one or
; spaces, with or without a preceding ':' character.  We end up with an IDL LIST,
; with as many elements as there are attributes, each list element containing a
; 3-element STRING with the netcdf attribute name as the 2nd element, and all of
; the spaces and ':' characters removed
parsed=strsplit(attsraw, ':*  *',/REGEX,/EXTRACT)

; walk through the attribute names, retrieve them from the file, and format and
; write them to their I/O variable or structure element
FOR ncattnum = 0, N_ELEMENTS(parsed)-1 DO BEGIN
   thisncatt=parsed[ncattnum,1]   ; pull the attribute name from the array
   CASE thisncatt OF
      'GV_UF_RC_field' : status=PREPARE_NCVAR( ncid1, thisncatt, gv_UF_field_byte, $
                                               STRUCT=matchupmeta, /GLOBAL_ATTRIBUTE, /BYTE )
      'GV_UF_RP_field' : status=PREPARE_NCVAR( ncid1, thisncatt, gv_UF_field_byte, $
                                               STRUCT=matchupmeta, /GLOBAL_ATTRIBUTE, /BYTE )
      'GV_UF_RR_field' : status=PREPARE_NCVAR( ncid1, thisncatt, gv_UF_field_byte, $
                                               STRUCT=matchupmeta, /GLOBAL_ATTRIBUTE, /BYTE )
      'GV_UF_ZDR_field' : status=PREPARE_NCVAR( ncid1, thisncatt, gv_UF_field_byte, $
                                                STRUCT=matchupmeta, /GLOBAL_ATTRIBUTE, /BYTE )
      'GV_UF_KDP_field' : status=PREPARE_NCVAR( ncid1, thisncatt, gv_UF_field_byte, $
                                                STRUCT=matchupmeta, /GLOBAL_ATTRIBUTE, /BYTE )
      'GV_UF_RHOHV_field' : status=PREPARE_NCVAR( ncid1, thisncatt, gv_UF_field_byte, $
                                                  STRUCT=matchupmeta, /GLOBAL_ATTRIBUTE, /BYTE )
      'GV_UF_HID_field' : status=PREPARE_NCVAR( ncid1, thisncatt, gv_UF_field_byte, $
                                                STRUCT=matchupmeta, /GLOBAL_ATTRIBUTE, /BYTE )
      'GV_UF_D0_field' : status=PREPARE_NCVAR( ncid1, thisncatt, gv_UF_field_byte, $
                                               STRUCT=matchupmeta, /GLOBAL_ATTRIBUTE, /BYTE )
      'GV_UF_NW_field' : status=PREPARE_NCVAR( ncid1, thisncatt, gv_UF_field_byte, $
                                               STRUCT=matchupmeta, /GLOBAL_ATTRIBUTE, /BYTE )
      'GV_UF_DM_field' : status=PREPARE_NCVAR( ncid1, thisncatt, gv_UF_field_byte, $
                                               STRUCT=matchupmeta, /GLOBAL_ATTRIBUTE, /BYTE )
      'GV_UF_N2_field' : status=PREPARE_NCVAR( ncid1, thisncatt, gv_UF_field_byte, $
                                               STRUCT=matchupmeta, /GLOBAL_ATTRIBUTE, /BYTE )
      'DPR_ScanType' : status=PREPARE_NCVAR( ncid1, thisncatt, DPR_ScanType, $
                                             STRUCT=matchupmeta, /GLOBAL_ATTRIBUTE, /BYTE )
      'DPR_Version' : status=PREPARE_NCVAR( ncid1, thisncatt, DPR_version, $
                                            STRUCT=matchupmeta, /GLOBAL_ATTRIBUTE, /BYTE )
      'GV_UF_Z_field' : status=PREPARE_NCVAR( ncid1, thisncatt, gr_UF_field_byte, $
                                              STRUCT=matchupmeta, /GLOBAL_ATTRIBUTE, /BYTE )
      'DPR_2ADPR_file' : status=PREPARE_NCVAR( ncid1, thisncatt, DPR_2ADPR_file_byte, $
                                               STRUCT=filesmeta, TAG='file_2adpr', $
                                               /GLOBAL_ATTRIBUTE, /BYTE )
      'DPR_2AKA_file' : status=PREPARE_NCVAR( ncid1, thisncatt, DPR_2AKA_file_byte, $
                                              STRUCT=filesmeta, TAG='file_2aka', $
                                              /GLOBAL_ATTRIBUTE, /BYTE )
      'DPR_2AKU_file' : status=PREPARE_NCVAR( ncid1, thisncatt, DPR_2AKU_file_byte, $
                                              STRUCT=filesmeta, TAG='file_2aku', $
                                              /GLOBAL_ATTRIBUTE, /BYTE )
      'DPR_2BCMB_file' : status=PREPARE_NCVAR( ncid1, thisncatt, DPR_2BCMB_file_byte, $
                                               STRUCT=filesmeta, TAG='file_2bcomb', $
                                               /GLOBAL_ATTRIBUTE, /BYTE )
      'PR_2APR_file' : status=PREPARE_NCVAR( ncid1, thisncatt, PR_2APR_file_byte, $
                                             STRUCT=filesmeta, TAG='file_2apr', $
                                             /GLOBAL_ATTRIBUTE, /BYTE )
      'PR_2BPRTMI_File' : status=PREPARE_NCVAR( ncid1, thisncatt, PR_2BPRTMI_file_byte, $
                                                STRUCT=filesmeta, TAG='file_2bprtmi', $
                                                /GLOBAL_ATTRIBUTE, /BYTE )
      'GR_file' : status=PREPARE_NCVAR( ncid1, thisncatt, GR_file_byte, $
                                        STRUCT=filesmeta, TAG='file_1CUF', $
                                        /GLOBAL_ATTRIBUTE, /BYTE )
; not currently using these, for now don't bother reading
; if we do decide to use, need to add in dpr_geo_match_nc_structs.inc and set up like the field variables 
; not the file variables
      'MRMS_Mask_categories' : status=PREPARE_NCVAR( ncid1, thisncatt, mrms_mask_categories, $
                                        STRUCT=matchupmeta, $
                                       /GLOBAL_ATTRIBUTE, /BYTE )
      ELSE : BEGIN
               message, "Unknown GRtoDPR netCDF global attribute '"+thisncatt+"'", /INFO
; TAB 9/20/17 figure out what to do about this, unused variables
;               status=1
             END
   ENDCASE
   IF status NE 0 THEN GOTO, ErrorExit
ENDFOR

;============= PROCESS THE REGULAR VARIABLES FOUND IN THE FILE ==================

; get the list of variables contained in the file
IF FLOAT(!version.release) gt 8.4 THEN BEGIN
   NCDF_LIST, ncfile, /VARIABLES, VNAME=ncfilevars, /QUIET
ENDIF ELSE BEGIN
  ; don't have NCDF_LIST until IDL 8.4.1, so we emulate it
   ncfilevars = STRARR(attstruc.nvars)
   FOR ivarnum = 0,attstruc.nvars-1 DO BEGIN
     ; get each variable name one at a time and add to ncfilevars array
      varstruct = NCDF_VARINQ(ncid1, ivarnum)
      ncfilevars[ivarnum] = varstruct.NAME
   ENDFOR
ENDELSE

; walk through the variable names, retrieve them from the file, format or resort
; as needed, and write them to their I/O variable or structure element
FOR ncvarnum = 0, N_ELEMENTS(ncfilevars)-1 DO BEGIN
   thisncvar=ncfilevars[ncvarnum]
   CASE thisncvar OF
      'version' : status=PREPARE_NCVAR( ncid1, thisncvar, nc_file_version, $
                                        STRUCT=matchupmeta, TAG='nc_file_version' )
      'timeNearestApproach' : status=PREPARE_NCVAR( ncid1, thisncvar, dtime, $
                                                    STRUCT=matchupmeta )
      'atimeNearestApproach' : status=PREPARE_NCVAR( ncid1, thisncvar, txtdtimebyte, $
                                                     STRUCT=matchupmeta, /BYTE )
      'numScans' : status=PREPARE_NCVAR( ncid1, thisncvar, num_scans, $
                                         STRUCT=matchupmeta, TAG='num_scans' )
      'numRays' : status=PREPARE_NCVAR( ncid1, thisncvar, num_rays, $
                                        STRUCT=matchupmeta, TAG='num_rays' )
      'rangeThreshold' : status=PREPARE_NCVAR( ncid1, thisncvar, rngthresh, $
                                               STRUCT=matchupmeta )
      'DPR_dBZ_min' : status=PREPARE_NCVAR( ncid1, thisncvar, dprzmin, $
                                            STRUCT=matchupmeta )
      'GR_dBZ_min' : status=PREPARE_NCVAR( ncid1, thisncvar, grzmin, $
                                           STRUCT=matchupmeta )
      'rain_min' : status=PREPARE_NCVAR( ncid1, thisncvar, rnmin, $
                                         STRUCT=matchupmeta )
      'DPR_decluttered' : status=PREPARE_NCVAR( ncid1, thisncvar, DPR_decluttered, $
                                                STRUCT=matchupmeta )
      'elevationAngle' : BREAK    ; already processed for reordering determination
      'timeSweepStart' : BREAK    ; already processed if needed for sweepsmeta
      'atimeSweepStart' : BREAK   ; already processed if needed for sweepsmeta
      'site_lat' : status=PREPARE_NCVAR( ncid1, thisncvar, nclat, $
                                         STRUCT=sitemeta )
      'site_lon' : status=PREPARE_NCVAR( ncid1, thisncvar, nclon, $
                                         STRUCT=sitemeta )
      'site_ID' : status=PREPARE_NCVAR( ncid1, thisncvar, siteIDbyte, $
                                        STRUCT=sitemeta, /BYTE )
      'site_elev' : status=PREPARE_NCVAR( ncid1, thisncvar, ncsiteElev, $
                                          STRUCT=sitemeta )
      'have_GR_Z' : status=PREPARE_NCVAR( ncid1, thisncvar, have_threeDreflect, $
                                          STRUCT=fieldFlags, TAG='have_threeDreflect' )
      'have_GR_RC_rainrate' : status=PREPARE_NCVAR( ncid1, thisncvar, have_GR_RC_rainrate, $
                                                    STRUCT=fieldFlags )
      'have_GR_RP_rainrate' : status=PREPARE_NCVAR( ncid1, thisncvar, have_GR_RP_rainrate, $
                                                    STRUCT=fieldFlags )
      'have_GR_RR_rainrate' : status=PREPARE_NCVAR( ncid1, thisncvar, have_GR_RR_rainrate, $
                                                    STRUCT=fieldFlags )
      'have_GR_rainrate' : status=PREPARE_NCVAR( ncid1, thisncvar, have_GR_RR_rainrate, $
                                                 STRUCT=fieldFlags, TAG='have_GR_RR_rainrate' )
      'have_paramDSD' : status=PREPARE_NCVAR( ncid1, thisncvar, have_paramDSD, $
                                              STRUCT=fieldFlags )
      'have_piaFinal' : status=PREPARE_NCVAR( ncid1, thisncvar, have_piaFinal, $
                                              STRUCT=fieldFlags )
      'have_heightStormTop' : status=PREPARE_NCVAR( ncid1, thisncvar, have_heightStormTop, $
                                                    STRUCT=fieldFlags )
      'have_GR_Zdr' : status=PREPARE_NCVAR( ncid1, thisncvar, have_GR_Zdr, $
                                            STRUCT=fieldFlags )
      'have_GR_Kdp' : status=PREPARE_NCVAR( ncid1, thisncvar, have_GR_Kdp, $
                                            STRUCT=fieldFlags )
      'have_GR_RHOhv' : status=PREPARE_NCVAR( ncid1, thisncvar, have_GR_RHOhv, $
                                              STRUCT=fieldFlags )
      'have_GR_HID' : status=PREPARE_NCVAR( ncid1, thisncvar, have_GR_HID, $
                                            STRUCT=fieldFlags )
      'have_GR_Dzero' : status=PREPARE_NCVAR( ncid1, thisncvar, have_GR_Dzero, $
                                              STRUCT=fieldFlags )
      'have_GR_Nw' : status=PREPARE_NCVAR( ncid1, thisncvar, have_GR_Nw, $
                                           STRUCT=fieldFlags )
      'have_GR_Dm' : status=PREPARE_NCVAR( ncid1, thisncvar, have_GR_Dm, $
                                           STRUCT=fieldFlags )
      'have_GR_N2' : status=PREPARE_NCVAR( ncid1, thisncvar, have_GR_N2, $
                                           STRUCT=fieldFlags )
      'have_GR_blockage' : status=PREPARE_NCVAR( ncid1, thisncvar, have_GR_blockage, $
                                                 STRUCT=fieldFlags )
      'have_Epsilon' : status=PREPARE_NCVAR( ncid1, thisncvar, have_Epsilon, $
                                             STRUCT=fieldFlags )
      'have_BBstatus' : status=PREPARE_NCVAR( ncid1, thisncvar, have_BBstatus, $
                                              STRUCT=fieldFlags )
      'have_qualityData' : status=PREPARE_NCVAR( ncid1, thisncvar, have_qualityData, $
                                                 STRUCT=fieldFlags )
      'have_clutterStatus' : status=PREPARE_NCVAR( ncid1, thisncvar, have_clutterStatus, $
                                                   STRUCT=fieldFlags )
      'have_ZFactorMeasured' : status=PREPARE_NCVAR( ncid1, thisncvar, $
                                                     have_ZFactorMeasured, $
                                                     STRUCT=fieldFlags )
      'have_ZFactorCorrected' : status=PREPARE_NCVAR( ncid1, thisncvar, $
                                                      have_ZFactorCorrected, $
                                                      STRUCT=fieldFlags )
      'have_ZFactorMeasured250m' : status=PREPARE_NCVAR( ncid1, thisncvar, $
                                                         have_ZFactorMeasured250m, $
                                                         STRUCT=fieldFlags )
      'have_ZFactorCorrected250m' : status=PREPARE_NCVAR( ncid1, thisncvar, $
                                                          have_ZFactorCorrected250m, $
                                                          STRUCT=fieldFlags )
      'have_PrecipRate' : status=PREPARE_NCVAR( ncid1, thisncvar, have_PrecipRate, $
                                                STRUCT=fieldFlags )
      'have_paramDSD' : status=PREPARE_NCVAR( ncid1, thisncvar, have_paramDSD, $
                                              STRUCT=fieldFlags )
      'have_LandSurfaceType' : status=PREPARE_NCVAR( ncid1, thisncvar, have_LandSurfaceType, $
                                                     STRUCT=fieldFlags )
      'have_PrecipRateSurface' : status=PREPARE_NCVAR( ncid1, thisncvar, have_PrecipRateSurface, $
                                                       STRUCT=fieldFlags )
      'have_SurfPrecipTotRate' : status=PREPARE_NCVAR( ncid1, thisncvar, have_SurfPrecipRate, $
                                                       STRUCT=fieldFlags, TAG='have_SurfPrecipRate' )
      'have_BBheight' : status=PREPARE_NCVAR( ncid1, thisncvar, have_BBheight, $
                                              STRUCT=fieldFlags )
      'have_FlagPrecip' : status=PREPARE_NCVAR( ncid1, thisncvar, have_FlagPrecip, $
                                                STRUCT=fieldFlags )
      'have_TypePrecip' : status=PREPARE_NCVAR( ncid1, thisncvar, have_TypePrecip, $
                                                STRUCT=fieldFlags )
      'have_MRMS' : status=PREPARE_NCVAR( ncid1, thisncvar, have_mrms, $
                                              STRUCT=fieldFlags )
      'have_GR_SWE' : status=PREPARE_NCVAR( ncid1, thisncvar, have_swe, $
                                              STRUCT=fieldFlags )
      'n_gr_expected' : status=PREPARE_NCVAR( ncid1, thisncvar, gvexpect, $
                                              DIM2SORT=2, IDXSORT=idxsort )
      'n_gr_z_rejected' : status=PREPARE_NCVAR( ncid1, thisncvar, gvreject, $
                                                DIM2SORT=2, IDXSORT=idxsort )
      'n_gr_rc_rejected' : status=PREPARE_NCVAR( ncid1, thisncvar, gv_rc_reject, $
                                                 DIM2SORT=2, IDXSORT=idxsort )
      'n_gr_rp_rejected' : status=PREPARE_NCVAR( ncid1, thisncvar, gv_rp_reject, $
                                                 DIM2SORT=2, IDXSORT=idxsort )
      'n_gr_rr_rejected' : status=PREPARE_NCVAR( ncid1, thisncvar, gv_rr_reject, $
                                                 DIM2SORT=2, IDXSORT=idxsort )
      'n_gr_zdr_rejected' : status=PREPARE_NCVAR( ncid1, thisncvar, gv_zdr_reject, $
                                                  DIM2SORT=2, IDXSORT=idxsort )
      'n_gr_kdp_rejected' : status=PREPARE_NCVAR( ncid1, thisncvar, gv_kdp_reject, $
                                                  DIM2SORT=2, IDXSORT=idxsort )
      'n_gr_rhohv_rejected' : status=PREPARE_NCVAR( ncid1, thisncvar, gv_RHOhv_reject, $
                                                    DIM2SORT=2, IDXSORT=idxsort )
      'n_gr_hid_rejected' : status=PREPARE_NCVAR( ncid1, thisncvar, gv_hid_reject, $
                                                  DIM2SORT=2, IDXSORT=idxsort )
      'n_gr_dzero_rejected' : status=PREPARE_NCVAR( ncid1, thisncvar, gv_dzero_reject, $
                                                    DIM2SORT=2, IDXSORT=idxsort )
      'n_gr_nw_rejected' : status=PREPARE_NCVAR( ncid1, thisncvar, gv_nw_reject, $
                                                 DIM2SORT=2, IDXSORT=idxsort )
      'n_gr_dm_rejected' : status=PREPARE_NCVAR( ncid1, thisncvar, gv_dm_reject, $
                                                 DIM2SORT=2, IDXSORT=idxsort )
      'n_gr_n2_rejected' : status=PREPARE_NCVAR( ncid1, thisncvar, gv_n2_reject, $
                                                 DIM2SORT=2, IDXSORT=idxsort )
      'n_dpr_expected' : status=PREPARE_NCVAR( ncid1, thisncvar, dprexpect, $
                                               DIM2SORT=2, IDXSORT=idxsort )
      'n_dpr_meas_z_rejected' : status=PREPARE_NCVAR( ncid1, thisncvar, zrawreject, $
                                                      DIM2SORT=2, IDXSORT=idxsort )
      'n_dpr_corr_z_rejected' : status=PREPARE_NCVAR( ncid1, thisncvar, zcorreject, $
                                                      DIM2SORT=2, IDXSORT=idxsort )

; the following is for "appended' files that used a different name for 'n_dpr_epsilon_rejected'
      'n_dpr_epsilon_gates_rejected' : status=PREPARE_NCVAR( ncid1, thisncvar, epsilonreject, $
                                                       DIM2SORT=2, IDXSORT=idxsort )

      'n_dpr_epsilon_rejected' : status=PREPARE_NCVAR( ncid1, thisncvar, epsilonreject, $
                                                       DIM2SORT=2, IDXSORT=idxsort )
      'n_dpr_expected250m' : status=PREPARE_NCVAR( ncid1, thisncvar, dpr250expect, $
                                                   DIM2SORT=2, IDXSORT=idxsort )
      'n_dpr_meas_z_rejected250m' : status=PREPARE_NCVAR( ncid1, thisncvar, zraw250reject, $
                                                          DIM2SORT=2, IDXSORT=idxsort )
      'n_dpr_corr_z_rejected250m' : status=PREPARE_NCVAR( ncid1, thisncvar, zcor250reject, $
                                                          DIM2SORT=2, IDXSORT=idxsort )
      'n_dpr_corr_r_rejected' : status=PREPARE_NCVAR( ncid1, thisncvar, rainreject, $
                                                      DIM2SORT=2, IDXSORT=idxsort )
      'n_dpr_dm_rejected' : status=PREPARE_NCVAR( ncid1, thisncvar, dpr_dm_reject, $
                                                  DIM2SORT=2, IDXSORT=idxsort )
      'n_dpr_nw_rejected' : status=PREPARE_NCVAR( ncid1, thisncvar, dpr_nw_reject, $
                                                  DIM2SORT=2, IDXSORT=idxsort )
      'n_gr_swedp_rejected' : status=PREPARE_NCVAR( ncid1, thisncvar, gv_swedp_reject, $
                                                 DIM2SORT=2, IDXSORT=idxsort )
      'n_gr_swe25_rejected' : status=PREPARE_NCVAR( ncid1, thisncvar, gv_swe25_reject, $
                                                 DIM2SORT=2, IDXSORT=idxsort )
      'n_gr_swe50_rejected' : status=PREPARE_NCVAR( ncid1, thisncvar, gv_swe50_reject, $
                                                 DIM2SORT=2, IDXSORT=idxsort )
      'n_gr_swe75_rejected' : status=PREPARE_NCVAR( ncid1, thisncvar, gv_swe75_reject, $
                                                 DIM2SORT=2, IDXSORT=idxsort )
      'n_gr_swemqt_rejected' : status=PREPARE_NCVAR( ncid1, thisncvar, gv_swemqt_reject, $
                                                 DIM2SORT=2, IDXSORT=idxsort )
      'n_gr_swemrms_rejected' : status=PREPARE_NCVAR( ncid1, thisncvar, gv_swemrms_reject, $
                                                 DIM2SORT=2, IDXSORT=idxsort )
      'GR_Z' : status=PREPARE_NCVAR( ncid1, thisncvar, threeDreflect, $
                                     DIM2SORT=2, IDXSORT=idxsort )
      'GR_Z_Max' : status=PREPARE_NCVAR( ncid1, thisncvar, threeDreflectMax, $
                                         DIM2SORT=2, IDXSORT=idxsort )
      'GR_Z_StdDev' : status=PREPARE_NCVAR( ncid1, thisncvar, threeDreflectStdDev, $
                                            DIM2SORT=2, IDXSORT=idxsort )
      'GR_Zdr' : status=PREPARE_NCVAR( ncid1, thisncvar, GR_Zdr, $
                                       DIM2SORT=2, IDXSORT=idxsort )
      'GR_Zdr_Max' : status=PREPARE_NCVAR( ncid1, thisncvar, GR_Zdr_Max, $
                                           DIM2SORT=2, IDXSORT=idxsort )
      'GR_Zdr_StdDev' : status=PREPARE_NCVAR( ncid1, thisncvar, GR_Zdr_StdDev, $
                                              DIM2SORT=2, IDXSORT=idxsort )
      'GR_Kdp' : status=PREPARE_NCVAR( ncid1, thisncvar, GR_Kdp, $
                                       DIM2SORT=2, IDXSORT=idxsort )
      'GR_Kdp_Max' : status=PREPARE_NCVAR( ncid1, thisncvar, GR_Kdp_Max, $
                                           DIM2SORT=2, IDXSORT=idxsort )
      'GR_Kdp_StdDev' : status=PREPARE_NCVAR( ncid1, thisncvar, GR_Kdp_StdDev, $
                                              DIM2SORT=2, IDXSORT=idxsort )
      'GR_RHOhv' : status=PREPARE_NCVAR( ncid1, thisncvar, GR_RHOhv, $
                                         DIM2SORT=2, IDXSORT=idxsort )
      'GR_RHOhv_Max' : status=PREPARE_NCVAR( ncid1, thisncvar, GR_RHOhv_Max, $
                                             DIM2SORT=2, IDXSORT=idxsort )
      'GR_RHOhv_StdDev' : status=PREPARE_NCVAR( ncid1, thisncvar, GR_RHOhv_StdDev, $
                                                DIM2SORT=2, IDXSORT=idxsort )
      'GR_RC_rainrate' : status=PREPARE_NCVAR( ncid1, thisncvar, GR_RC_rainrate, $
                                               DIM2SORT=2, IDXSORT=idxsort )
      'GR_RC_rainrate_Max' : status=PREPARE_NCVAR( ncid1, thisncvar, GR_RC_rainrate_Max, $
                                                   DIM2SORT=2, IDXSORT=idxsort )
      'GR_RC_rainrate_StdDev' : status=PREPARE_NCVAR( ncid1, thisncvar, GR_RC_rainrate_StdDev, $
                                                      DIM2SORT=2, IDXSORT=idxsort )
      'GR_RP_rainrate' : status=PREPARE_NCVAR( ncid1, thisncvar, GR_RP_rainrate, $
                                               DIM2SORT=2, IDXSORT=idxsort )
      'GR_RP_rainrate_Max' : status=PREPARE_NCVAR( ncid1, thisncvar, GR_RP_rainrate_Max, $
                                                   DIM2SORT=2, IDXSORT=idxsort )
      'GR_RP_rainrate_StdDev' : status=PREPARE_NCVAR( ncid1, thisncvar, GR_RP_rainrate_StdDev, $
                                                      DIM2SORT=2, IDXSORT=idxsort )
      'GR_RR_rainrate' : status=PREPARE_NCVAR( ncid1, thisncvar, GR_RR_rainrate, $
                                               DIM2SORT=2, IDXSORT=idxsort )
      'GR_rainrate_Max' : status=PREPARE_NCVAR( ncid1, thisncvar, GR_RR_rainrate_Max, $
                                                DIM2SORT=2, IDXSORT=idxsort )
      'GR_RR_rainrate_Max' : status=PREPARE_NCVAR( ncid1, thisncvar, GR_RR_rainrate_Max, $
                                                   DIM2SORT=2, IDXSORT=idxsort )
      'GR_rainrate_StdDev' : status=PREPARE_NCVAR( ncid1, thisncvar, GR_RR_rainrate_StdDev, $
                                                   DIM2SORT=2, IDXSORT=idxsort )
      'GR_RR_rainrate_StdDev' : status=PREPARE_NCVAR( ncid1, thisncvar, GR_RR_rainrate_StdDev, $
                                                      DIM2SORT=2, IDXSORT=idxsort )
      'GR_HID' : status=PREPARE_NCVAR( ncid1, thisncvar, GR_HID, $
                                       DIM2SORT=3, IDXSORT=idxsort )
      'GR_Dzero' : status=PREPARE_NCVAR( ncid1, thisncvar, GR_Dzero, $
                                         DIM2SORT=2, IDXSORT=idxsort )
      'GR_Dzero_Max' : status=PREPARE_NCVAR( ncid1, thisncvar, GR_Dzero_Max, $
                                             DIM2SORT=2, IDXSORT=idxsort )
      'GR_Dzero_StdDev' : status=PREPARE_NCVAR( ncid1, thisncvar, GR_Dzero_StdDev, $
                                                DIM2SORT=2, IDXSORT=idxsort )
      'GR_Nw' : status=PREPARE_NCVAR( ncid1, thisncvar, GR_Nw, $
                                      DIM2SORT=2, IDXSORT=idxsort )
      'GR_Nw_Max' : status=PREPARE_NCVAR( ncid1, thisncvar, GR_Nw_Max, $
                                          DIM2SORT=2, IDXSORT=idxsort )
      'GR_Nw_StdDev' : status=PREPARE_NCVAR( ncid1, thisncvar, GR_Nw_StdDev, $
                                             DIM2SORT=2, IDXSORT=idxsort )
      'GR_Dm' : status=PREPARE_NCVAR( ncid1, thisncvar, GR_Dm, $
                                      DIM2SORT=2, IDXSORT=idxsort )
      'GR_Dm_Max' : status=PREPARE_NCVAR( ncid1, thisncvar, GR_Dm_Max, $
                                          DIM2SORT=2, IDXSORT=idxsort )
      'GR_Dm_StdDev' : status=PREPARE_NCVAR( ncid1, thisncvar, GR_Dm_StdDev, $
                                             DIM2SORT=2, IDXSORT=idxsort )
      'GR_N2' : status=PREPARE_NCVAR( ncid1, thisncvar, GR_N2, $
                                      DIM2SORT=2, IDXSORT=idxsort )
      'GR_N2_Max' : status=PREPARE_NCVAR( ncid1, thisncvar, GR_N2_Max, $
                                          DIM2SORT=2, IDXSORT=idxsort )
      'GR_N2_StdDev' : status=PREPARE_NCVAR( ncid1, thisncvar, GR_N2_StdDev, $
                                             DIM2SORT=2, IDXSORT=idxsort )
      'GR_blockage' : status=PREPARE_NCVAR( ncid1, thisncvar, GR_blockage, $
                                            DIM2SORT=2, IDXSORT=idxsort )
      'ZFactorMeasured' : status=PREPARE_NCVAR( ncid1, thisncvar, ZFactorMeasured, $
                                                DIM2SORT=2, IDXSORT=idxsort )
      'ZFactorCorrected' : status=PREPARE_NCVAR( ncid1, thisncvar, ZFactorCorrected, $
                                                 DIM2SORT=2, IDXSORT=idxsort )
      'Epsilon' : status=PREPARE_NCVAR( ncid1, thisncvar, epsilon, $
                                        DIM2SORT=2, IDXSORT=idxsort )
      'ZFactorMeasured250m' : status=PREPARE_NCVAR( ncid1, thisncvar, ZFactorMeasured250m, $
                                                    DIM2SORT=2, IDXSORT=idxsort )
      'ZFactorCorrected250m' : status=PREPARE_NCVAR( ncid1, thisncvar, ZFactorCorrected250m, $
                                                     DIM2SORT=2, IDXSORT=idxsort )
      'MaxZFactorMeasured250m' : status=PREPARE_NCVAR( ncid1, thisncvar, maxZFactorMeasured250m, $
                                                       DIM2SORT=2, IDXSORT=idxsort )
      'PrecipRate' : status=PREPARE_NCVAR( ncid1, thisncvar, PrecipRate, $
                                           DIM2SORT=2, IDXSORT=idxsort )
      'Dm' : status=PREPARE_NCVAR( ncid1, thisncvar, DPR_Dm, $
                                   DIM2SORT=2, IDXSORT=idxsort )
      'Nw' : status=PREPARE_NCVAR( ncid1, thisncvar, DPR_Nw, $
                                   DIM2SORT=2, IDXSORT=idxsort )
      'topHeight' : status=PREPARE_NCVAR( ncid1, thisncvar, topHeight, $
                                          DIM2SORT=2, IDXSORT=idxsort )
      'bottomHeight' : status=PREPARE_NCVAR( ncid1, thisncvar, bottomHeight, $
                                             DIM2SORT=2, IDXSORT=idxsort )
      'xCorners' : status=PREPARE_NCVAR( ncid1, thisncvar, xCorners, $
                                         DIM2SORT=3, IDXSORT=idxsort )
      'yCorners' : status=PREPARE_NCVAR( ncid1, thisncvar, yCorners, $
                                         DIM2SORT=3, IDXSORT=idxsort )
      'latitude' : status=PREPARE_NCVAR( ncid1, thisncvar, latitude, $
                                         DIM2SORT=2, IDXSORT=idxsort )
      'longitude' : status=PREPARE_NCVAR( ncid1, thisncvar, longitude, $
                                          DIM2SORT=2, IDXSORT=idxsort )
      'DPRlatitude' : status=PREPARE_NCVAR( ncid1, thisncvar, DPRlatitude )
      'DPRlongitude' : status=PREPARE_NCVAR( ncid1, thisncvar, DPRlongitude )
      'PrecipRateSurface' : status=PREPARE_NCVAR( ncid1, thisncvar, PrecipRateSurface )
      'piaFinal' : status=PREPARE_NCVAR( ncid1, thisncvar, piaFinal )
      'heightStormTop' : status=PREPARE_NCVAR( ncid1, thisncvar, heightStormTop )
      'SurfPrecipTotRate' : status=PREPARE_NCVAR( ncid1, thisncvar, SurfPrecipRate )
      'BBheight' : status=PREPARE_NCVAR( ncid1, thisncvar, BBheight )
      'LandSurfaceType' : status=PREPARE_NCVAR( ncid1, thisncvar, LandSurfaceType )
      'FlagPrecip' : status=PREPARE_NCVAR( ncid1, thisncvar, FlagPrecip )
      'TypePrecip' : status=PREPARE_NCVAR( ncid1, thisncvar, TypePrecip )
      'scanNum' : status=PREPARE_NCVAR( ncid1, thisncvar, scanNum )
      'rayNum' : status=PREPARE_NCVAR( ncid1, thisncvar, rayNum )
      'BBstatus' : status=PREPARE_NCVAR( ncid1, thisncvar, BBstatus )
      'qualityData' : status=PREPARE_NCVAR( ncid1, thisncvar, qualityData)
      'clutterStatus' : status=PREPARE_NCVAR( ncid1, thisncvar, clutterStatus )
      'PrecipMeanLow' : status=PREPARE_NCVAR( ncid1, thisncvar, mrmsrrlow )
      'PrecipMeanMed' : status=PREPARE_NCVAR( ncid1, thisncvar, mrmsrrmed )
      'PrecipMeanHigh' : status=PREPARE_NCVAR( ncid1, thisncvar, mrmsrrhigh )
      'PrecipMeanVeryHigh' : status=PREPARE_NCVAR( ncid1, thisncvar, mrmsrrveryhigh )
      'GuageRatioMeanLow' : status=PREPARE_NCVAR( ncid1, thisncvar, mrmsgrlow )
      'GuageRatioMeanMed' : status=PREPARE_NCVAR( ncid1, thisncvar, mrmsgrmed )
      'GuageRatioMeanHigh' : status=PREPARE_NCVAR( ncid1, thisncvar, mrmsgrhigh )
      'GuageRatioMeanVeryHigh' : status=PREPARE_NCVAR( ncid1, thisncvar, mrmsgrveryhigh )
      'MaskLow' : status=PREPARE_NCVAR( ncid1, thisncvar, mrmsptlow )
      'MaskMed' : status=PREPARE_NCVAR( ncid1, thisncvar, mrmsptmed )
      'MaskHigh' : status=PREPARE_NCVAR( ncid1, thisncvar, mrmspthigh )
      'MaskVeryHigh' : status=PREPARE_NCVAR( ncid1, thisncvar, mrmsptveryhigh )
      'RqiPercentLow' : status=PREPARE_NCVAR( ncid1, thisncvar, mrmsrqiplow )
      'RqiPercentMed' : status=PREPARE_NCVAR( ncid1, thisncvar, mrmsrqipmed )
      'RqiPercentHigh' : status=PREPARE_NCVAR( ncid1, thisncvar, mrmsrqiphigh )
      'RqiPercentVeryHigh' : status=PREPARE_NCVAR( ncid1, thisncvar, mrmsrqipveryhigh )
      'GR_SWEDP' : status=PREPARE_NCVAR( ncid1, thisncvar, swedp )
      'GR_SWEDP_Max' : status=PREPARE_NCVAR( ncid1, thisncvar, swedp_max)
      'GR_SWEDP_StdDev' : status=PREPARE_NCVAR( ncid1, thisncvar, swedp_stddev)
      'GR_SWE25' : status=PREPARE_NCVAR( ncid1, thisncvar, swe25 )
      'GR_SWE25_Max' : status=PREPARE_NCVAR( ncid1, thisncvar, swe25_max)
      'GR_SWE25_StdDev' : status=PREPARE_NCVAR( ncid1, thisncvar, swe25_stddev)
      'GR_SWE50' : status=PREPARE_NCVAR( ncid1, thisncvar, swe50 )
      'GR_SWE50_Max' : status=PREPARE_NCVAR( ncid1, thisncvar, swe50_max)
      'GR_SWE50_StdDev' : status=PREPARE_NCVAR( ncid1, thisncvar, swe50_stddev)
      'GR_SWE75' : status=PREPARE_NCVAR( ncid1, thisncvar, swe75 )
      'GR_SWE75_Max' : status=PREPARE_NCVAR( ncid1, thisncvar, swe75_max)
      'GR_SWE75_StdDev' : status=PREPARE_NCVAR( ncid1, thisncvar, swe75_stddev)
      'GR_SWEMQT' : status=PREPARE_NCVAR( ncid1, thisncvar, swemqt )
      'GR_SWEMQT_Max' : status=PREPARE_NCVAR( ncid1, thisncvar, swemqt_max)
      'GR_SWEMQT_StdDev' : status=PREPARE_NCVAR( ncid1, thisncvar, swemqt_stddev)
      'GR_SWEMRMS' : status=PREPARE_NCVAR( ncid1, thisncvar, swemrms )
      'GR_SWEMRMS_Max' : status=PREPARE_NCVAR( ncid1, thisncvar, swemrms_max)
      'GR_SWEMRMS_StdDev' : status=PREPARE_NCVAR( ncid1, thisncvar, swemrms_stddev)
      'MRMS_HID' : status=PREPARE_NCVAR( ncid1, thisncvar, mrmshid)

       ELSE : BEGIN
                 message, "Unknown GRtoDPR netCDF variable '"+thisncvar+"'", /INFO
; TAB 9/20/17 figure out what to do about this, unused variables
       ;          status=1
help, status
              END
   ENDCASE
   IF status NE 0 THEN GOTO, ErrorExit
ENDFOR


; HANDLE REQUESTS FOR ADDITIONAL VARIABLE(S) DERIVED FROM THOSE IN THE FILE
IF N_Elements(rayIndex) NE 0 THEN BEGIN
  ; figure out which swath we have, as it affects computation of ray_index
   CASE STRUPCASE(DPR_scantype) OF
      'HS' : RAYSPERSCAN = RAYSPERSCAN_HS
      'FS' : RAYSPERSCAN = RAYSPERSCAN_FS
      ELSE : BEGIN
                message, "Illegal scan type '"+DPR_scantype+"'", /INFO
                status = 1
                goto, ErrorExit
             END
   ENDCASE
   rayIndex = scanNum*RAYSPERSCAN + rayNum
ENDIF

EarlyExit:
ErrorExit:
NCDF_CLOSE, ncid1

ErrorExit2:

RETURN, status
END
