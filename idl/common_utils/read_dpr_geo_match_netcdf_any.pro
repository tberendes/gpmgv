;===============================================================================
;+
; Copyright © 2013, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; read_dpr_geo_match_netcdf_any.pro           Morris/SAIC/GPM_GV      July 2013
;
; DESCRIPTION
; -----------
; Reads caller-specified data and metadata from DPR-GR matchup netCDF files. 
; Returns status value: 0 if successful read, 1 if unsuccessful or internal
; errors or inconsistencies occur.  File must be read-ready (unzipped/
; uncompressed) before calling this function.  This version gets a list of
; variables in the file and does not attempt to read any undefined variables,
; rather than depending on the matchup version to define which variables are
; contained in the file.
;
; PARAMETERS
; ----------
; ncfile               STRING, Full file pathname to DPR netCDF grid file (Input)
;
; matchupmeta          Structure holding general and algorithmic parameters (I/O)
; sweepsmeta           Array of Structures holding sweep elevation angles,
;                      and sweep start times in unix ticks and ascii text (I/O)
; sitemeta             Structure holding GV site location parameters (I/O)
; fieldFlags           Structure holding "data exists" flags for DPR science
;                        data variables (I/O)
; filesmeta            Structure holding DPR and GR file names used in matchup (I/O)
;                      -- See file geo_match_nc_structs.inc for definition of
;                         the above structures.
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
; clutterStatus        INT array of DPR 'clutterStatus' flag, coded category (I/O)
; FlagPrecip           INT array of DPR rain/no-rain flag, category (I/O)
; TypePrecip           INT array of DPR derived raincloud type, category (I/O)
; rayIndex             LONG array of DPR product ray,scan IDL array index,
;                        relative to the full DPR/Ka/Ku products (I/O)
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
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;===============================================================================

; MODULE 2

FUNCTION sort_multi_d_array, orderidx, array2sort, sortdim

; re-sort a multi-dimensional array 'array2sort' along the dimension 'sortdim'
; in the order specified by 'orderidx'.  sortdim is 1-based, i.e., the first
; dimension is 1, 2nd is 2, ...

sz = SIZE(array2sort)
layers = N_ELEMENTS(orderidx)
IF ( layers EQ sz[sortdim] ) THEN BEGIN
   status=0

   CASE sz[0] OF
     2 : BEGIN
           temparr=array2sort
           FOR ndim = 0, layers-1 DO BEGIN
             CASE sortdim OF
                1 : array2sort[ndim,*]=temparr[orderidx[ndim],*]
                2 : array2sort[*,ndim]=temparr[*,orderidx[ndim]]
             ENDCASE
           ENDFOR
         END
     3 : BEGIN
           temparr=array2sort
           FOR ndim = 0, layers-1 DO BEGIN
             CASE sortdim OF
                1 : array2sort[ndim,*,*]=temparr[orderidx[ndim],*,*]
                2 : array2sort[*,ndim,*]=temparr[*,orderidx[ndim],*]
                3 : array2sort[*,*,ndim]=temparr[*,*,orderidx[ndim]]
             ENDCASE
           ENDFOR
         END
     ELSE : BEGIN
           print, 'ERROR from sort_multi_d_array() in read_dpr_geo_match_netcdf.pro:'
           print, 'Too many dimensions (', sz[0], ') in array to be sorted!'
           status=1
         END
   ENDCASE

ENDIF ELSE BEGIN
   print, 'ERROR from sort_multi_d_array() in read_dpr_geo_match_netcdf.pro:'
   print, 'Size of array dimension over which to sort does not match number of sort indices!'
   status=1
ENDELSE

return, status
end

;===============================================================================

; MODULE 1

FUNCTION read_dpr_geo_match_netcdf_any, ncfile,                               $
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

   ; DPR science values at earth surface level, or as ray summaries:
    sfcraindpr=PrecipRateSurface, sfcraincomb=SurfPrecipRate, bbhgt=BBheight, $
    sfctype_int=LandSurfaceType, rainflag_int=FlagPrecip,                     $
    raintype_int=TypePrecip, pridx_long=rayIndex, BBstatus_int=bbstatus,      $
    piaFinal=piaFinal, heightStormTop_int=heightStormTop,                     $
    clutterStatus_int=clutterStatus


; "Include" file for DPR-product-specific parameters (i.e., RAYSPERSCAN):
@dpr_params.inc

status = 0

ncid1 = NCDF_OPEN( ncfile )
IF ( N_Elements(ncid1) EQ 0 ) THEN BEGIN
   print, ''
   print, "ERROR from read_dpr_geo_match_netcdf:"
   print, "File copy ", ncfile, " is not a valid netCDF file!"
   print, ''
   status = 1
   goto, ErrorExit
ENDIF

; get the list of variables contained in the file
NCDF_LIST, ncfile, /VARIABLES, VNAME=ncfilevars, /QUIET

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
      goto, ErrorExit
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
NCDF_VARGET, ncid1, versid, ncversion

; figure out which swath we have, as it affects computation of pr_index
ncdf_attget, ncid1, 'DPR_ScanType', DPR_ScanType_byte, /global
DPR_ScanType = STRING(DPR_ScanType_byte)
CASE STRUPCASE(DPR_scantype) OF
   'HS' : BEGIN
             RAYSPERSCAN = RAYSPERSCAN_HS
;             GATE_SPACE = BIN_SPACE_HS
          END
   'MS' : BEGIN
             RAYSPERSCAN = RAYSPERSCAN_MS
;             GATE_SPACE = BIN_SPACE_NS_MS
         END
   'NS' : BEGIN
             RAYSPERSCAN = RAYSPERSCAN_NS
;             GATE_SPACE = BIN_SPACE_NS_MS
          END
   ELSE : message, "Illegal scan type '"+DPR_scantype+"'"
ENDCASE


IF N_Elements(matchupmeta) NE 0 THEN BEGIN
     NCDF_VARGET, ncid1, 'timeNearestApproach', dtime
     matchupmeta.timeNearestApproach = dtime
     NCDF_VARGET, ncid1, 'atimeNearestApproach', txtdtimebyte
     matchupmeta.atimeNearestApproach = string(txtdtimebyte)
     zdimid = NCDF_DIMID(ncid1, 'elevationAngle')
     NCDF_DIMINQ, ncid1, zdimid, XDIMNAME, ncnz
     matchupmeta.num_sweeps = ncnz
     fpdimid = NCDF_DIMID(ncid1, 'fpdim')
     NCDF_DIMINQ, ncid1, fpdimid, FPDIMNAME, nprfp
     matchupmeta.num_footprints = nprfp
     NCDF_VARGET, ncid1, 'numScans', num_scans
     matchupmeta.num_scans = num_scans
     NCDF_VARGET, ncid1, 'numRays', num_rays
     matchupmeta.num_rays = num_rays
     hidimid = NCDF_DIMID(ncid1, 'hidim')
     NCDF_DIMINQ, ncid1, hidimid, HIDIMNAME, nhidcats
     matchupmeta.num_HID_categories = nhidcats
     IF ncversion GT 1.0 THEN BEGIN
        ncdf_attget, ncid1, 'GV_UF_RC_field', gv_UF_field_byte, /global
        matchupmeta.GV_UF_RC_field = STRING(gv_UF_field_byte)
        ncdf_attget, ncid1, 'GV_UF_RP_field', gv_UF_field_byte, /global
        matchupmeta.GV_UF_RP_field = STRING(gv_UF_field_byte)
     ENDIF
     ncdf_attget, ncid1, 'GV_UF_RR_field', gv_UF_field_byte, /global
     matchupmeta.GV_UF_RR_field = STRING(gv_UF_field_byte)
     ncdf_attget, ncid1, 'GV_UF_ZDR_field', gv_UF_field_byte, /global
     matchupmeta.GV_UF_ZDR_field = STRING(gv_UF_field_byte)
     ncdf_attget, ncid1, 'GV_UF_KDP_field', gv_UF_field_byte, /global
     matchupmeta.GV_UF_KDP_field = STRING(gv_UF_field_byte)
     ncdf_attget, ncid1, 'GV_UF_RHOHV_field', gv_UF_field_byte, /global
     matchupmeta.GV_UF_RHOHV_field = STRING(gv_UF_field_byte)
     ncdf_attget, ncid1, 'GV_UF_HID_field', gv_UF_field_byte, /global
     matchupmeta.GV_UF_HID_field = STRING(gv_UF_field_byte)
     ncdf_attget, ncid1, 'GV_UF_D0_field', gv_UF_field_byte, /global
     matchupmeta.GV_UF_D0_field = STRING(gv_UF_field_byte)
     ncdf_attget, ncid1, 'GV_UF_NW_field', gv_UF_field_byte, /global
     matchupmeta.GV_UF_NW_field = STRING(gv_UF_field_byte)
     IF ncversion GT 1.1 THEN BEGIN
        ncdf_attget, ncid1, 'GV_UF_DM_field', gv_UF_field_byte, /global
        matchupmeta.GV_UF_DM_field = STRING(gv_UF_field_byte)
        ncdf_attget, ncid1, 'GV_UF_N2_field', gv_UF_field_byte, /global
        matchupmeta.GV_UF_N2_field = STRING(gv_UF_field_byte)
     ENDIF
     NCDF_VARGET, ncid1, 'rangeThreshold', rngthresh
     matchupmeta.rangeThreshold = rngthresh
     NCDF_VARGET, ncid1, 'DPR_dBZ_min', dprzmin
     matchupmeta.DPR_dBZ_min = dprzmin
     NCDF_VARGET, ncid1, 'GR_dBZ_min', grzmin
     matchupmeta.GR_dBZ_min = grzmin
     NCDF_VARGET, ncid1, 'rain_min', rnmin
     matchupmeta.rain_min = rnmin
;     NCDF_VARGET, ncid1, versid, ncversion  ; already "got" this variable
     matchupmeta.nc_file_version = ncversion
;     ncdf_attget, ncid1, 'DPR_ScanType', DPR_ScanType_byte, /global; ; already "got" this variable
;     matchupmeta.DPR_ScanType = STRING(DPR_ScanType_byte)
     matchupmeta.DPR_ScanType = DPR_ScanType
     ncdf_attget, ncid1, 'DPR_Version', DPR_vers_byte, /global
     matchupmeta.DPR_Version = STRING(DPR_vers_byte)
     ncdf_attget, ncid1, 'GV_UF_Z_field', gr_UF_field_byte, /global
     matchupmeta.GV_UF_Z_field = STRING(gr_UF_field_byte)
ENDIF

IF N_Elements(sweepsmeta) NE 0 THEN BEGIN
     zdimid = NCDF_DIMID(ncid1, 'elevationAngle')
     NCDF_DIMINQ, ncid1, zdimid, XDIMNAME, ncnz  ; number of sweeps/elevs.
     NCDF_VARGET, ncid1, 'elevationAngle', nc_zlevels
     elevorder = SORT(nc_zlevels)
     ascorder = INDGEN(ncnz)
     sortflag=0
     IF TOTAL( ABS(elevorder-ascorder) ) NE 0 THEN BEGIN
        PRINT, 'read_dpr_geo_match_netcdf(): Elevation angles not in order! Resorting data.'
        sortflag=1
     ENDIF
     arr_structs = REPLICATE(sweepsmeta,ncnz)  ; need one struct per sweep/elev.
     arr_structs.elevationAngle = nc_zlevels[elevorder]
     NCDF_VARGET, ncid1, 'timeSweepStart', sweepticks
     arr_structs.timeSweepStart = sweepticks[elevorder]
     NCDF_VARGET, ncid1, 'atimeSweepStart', sweeptimetxtbyte
     arr_structs.atimeSweepStart = STRING(sweeptimetxtbyte[*,elevorder])
     sweepsmeta = arr_structs
ENDIF ELSE BEGIN
    ; always need to determine whether reordering of layers needs done
     zdimid = NCDF_DIMID(ncid1, 'elevationAngle')
     NCDF_DIMINQ, ncid1, zdimid, XDIMNAME, ncnz  ; number of sweeps/elevs.
     NCDF_VARGET, ncid1, 'elevationAngle', nc_zlevels
     elevorder = SORT(nc_zlevels)
     ascorder = INDGEN(ncnz)
     sortflag=0
     IF TOTAL( ABS(elevorder-ascorder) ) NE 0 THEN BEGIN
        PRINT, 'read_dpr_geo_match_netcdf(): Elevation angles not in order! Resorting data.'
        sortflag=1
     ENDIF
ENDELSE

IF N_Elements(sitemeta) NE 0 THEN BEGIN
     NCDF_VARGET, ncid1, 'site_lat', nclat
     sitemeta.site_lat = nclat
     NCDF_VARGET, ncid1, 'site_lon', nclon
     sitemeta.site_lon = nclon
     NCDF_VARGET, ncid1, 'site_ID', siteIDbyte
     sitemeta.site_id = string(siteIDbyte)
     NCDF_VARGET, ncid1, 'site_elev', ncsiteElev
     sitemeta.site_elev = ncsiteElev
ENDIF

IF N_Elements(fieldFlags) NE 0 THEN BEGIN
     NCDF_VARGET, ncid1, 'have_GR_Z', have_threeDreflect
     fieldFlags.have_threeDreflect = have_threeDreflect
     IF ncversion GT 1.0 THEN BEGIN
        NCDF_VARGET, ncid1, 'have_GR_RC_rainrate', have_GR_RC_rainrate
        fieldFlags.have_GR_RC_rainrate = have_GR_RC_rainrate
        NCDF_VARGET, ncid1, 'have_GR_RP_rainrate', have_GR_RP_rainrate
        fieldFlags.have_GR_RP_rainrate = have_GR_RP_rainrate
        NCDF_VARGET, ncid1, 'have_GR_RR_rainrate', have_GR_RR_rainrate
        fieldFlags.have_GR_RR_rainrate = have_GR_RR_rainrate
        NCDF_VARGET, ncid1, 'have_paramDSD', have_paramDSD
        fieldFlags.have_paramDSD = have_paramDSD
        NCDF_VARGET, ncid1, 'have_piaFinal', have_piaFinal
        fieldFlags.have_piaFinal = have_piaFinal
        NCDF_VARGET, ncid1, 'have_heightStormTop', have_heightStormTop
        fieldFlags.have_heightStormTop = have_heightStormTop
     ENDIF ELSE BEGIN
        NCDF_VARGET, ncid1, 'have_GR_rainrate', have_GR_RR_rainrate
        fieldFlags.have_GR_RR_rainrate = have_GR_RR_rainrate
     ENDELSE
     NCDF_VARGET, ncid1, 'have_GR_Zdr', have_GR_Zdr
     fieldFlags.have_GR_Zdr = have_GR_Zdr
     NCDF_VARGET, ncid1, 'have_GR_Kdp', have_GR_Kdp
     fieldFlags.have_GR_Kdp = have_GR_Kdp
     NCDF_VARGET, ncid1, 'have_GR_RHOhv', have_GR_RHOhv
     fieldFlags.have_GR_RHOhv = have_GR_RHOhv
     NCDF_VARGET, ncid1, 'have_GR_HID', have_GR_HID
     fieldFlags.have_GR_HID = have_GR_HID
     NCDF_VARGET, ncid1, 'have_GR_Dzero', have_GR_Dzero
     fieldFlags.have_GR_Dzero = have_GR_Dzero
     NCDF_VARGET, ncid1, 'have_GR_Nw', have_GR_Nw
     fieldFlags.have_GR_Nw = have_GR_Nw
     IF ncversion GT 1.1 THEN BEGIN
        NCDF_VARGET, ncid1, 'have_GR_Dm', have_GR_Dm
        fieldFlags.have_GR_Dm = have_GR_Dm
        NCDF_VARGET, ncid1, 'have_GR_N2', have_GR_N2
        fieldFlags.have_GR_N2 = have_GR_N2
     ENDIF




;     IF ncversion GT 1.2 THEN BEGIN
IF TOTAL(STRMATCH(ncfilevars, 'have_GR_blockage')) EQ 1 $
AND TOTAL(STRMATCH(ncfilevars, 'have_Epsilon')) EQ 1 THEN BEGIN
        NCDF_VARGET, ncid1, 'have_GR_blockage', have_GR_blockage
        fieldFlags.have_GR_blockage = have_GR_blockage
        NCDF_VARGET, ncid1, 'have_Epsilon', have_Epsilon
        fieldFlags.have_Epsilon = have_Epsilon
     ENDIF ELSE PRINT, "Missing have_GR_blockage or have_Epsilon."




     NCDF_VARGET, ncid1, 'have_BBstatus', have_BBstatus
     fieldFlags.have_BBstatus = have_BBstatus
     NCDF_VARGET, ncid1, 'have_clutterStatus', have_clutterStatus
     fieldFlags.have_clutterStatus = have_clutterStatus
     NCDF_VARGET, ncid1, 'have_ZFactorMeasured', have_ZFactorMeasured
     fieldFlags.have_ZFactorMeasured = have_ZFactorMeasured
     NCDF_VARGET, ncid1, 'have_ZFactorCorrected', have_ZFactorCorrected
     fieldFlags.have_ZFactorCorrected = have_ZFactorCorrected
     IF ncversion EQ 1.3 THEN BEGIN
        NCDF_VARGET, ncid1, 'have_ZFactorMeasured250m', have_ZFactorMeasured250m
        fieldFlags.have_ZFactorMeasured250m = have_ZFactorMeasured250m
        NCDF_VARGET, ncid1, 'have_ZFactorCorrected250m', have_ZFactorCorrected250m
        fieldFlags.have_ZFactorCorrected250m = have_ZFactorCorrected250m
     ENDIF
     NCDF_VARGET, ncid1, 'have_PrecipRate', have_PrecipRate
     fieldFlags.have_PrecipRate = have_PrecipRate
     NCDF_VARGET, ncid1, 'have_paramDSD', have_paramDSD
     fieldFlags.have_paramDSD = have_paramDSD
     NCDF_VARGET, ncid1, 'have_LandSurfaceType', have_LandSurfaceType
     fieldFlags.have_LandSurfaceType = have_LandSurfaceType
     NCDF_VARGET, ncid1, 'have_PrecipRateSurface', have_PrecipRateSurface
     fieldFlags.have_PrecipRateSurface = have_PrecipRateSurface
     NCDF_VARGET, ncid1, 'have_SurfPrecipTotRate', have_SurfPrecipRate
     fieldFlags.have_SurfPrecipRate = have_SurfPrecipRate
     NCDF_VARGET, ncid1, 'have_BBheight', have_BBheight
     fieldFlags.have_BBheight = have_BBheight
     NCDF_VARGET, ncid1, 'have_FlagPrecip', have_FlagPrecip
     fieldFlags.have_FlagPrecip = have_FlagPrecip
     NCDF_VARGET, ncid1, 'have_TypePrecip', have_TypePrecip
     fieldFlags.have_TypePrecip = have_TypePrecip
ENDIF

; Get the DPR and GR filenames in the matchup file.  Read them and
; override the 'UNKNOWN' initial values in the structure
IF N_Elements(filesmeta) NE 0 THEN BEGIN
   ncdf_attget, ncid1, 'DPR_2ADPR_file', DPR_2ADPR_file_byte, /global
   filesmeta.file_2adpr = STRING(DPR_2ADPR_file_byte)
   ncdf_attget, ncid1, 'DPR_2AKA_file', DPR_2AKA_file_byte, /global
   filesmeta.file_2aka = STRING(DPR_2AKA_file_byte)
   ncdf_attget, ncid1, 'DPR_2AKU_file', DPR_2AKU_file_byte, /global
   filesmeta.file_2aku = STRING(DPR_2AKU_file_byte)
   ncdf_attget, ncid1, 'DPR_2BCMB_file', DPR_2BCMB_file_byte, /global
   filesmeta.file_2bcomb = STRING(DPR_2BCMB_file_byte)
   ncdf_attget, ncid1, 'GR_file', GR_file_byte, /global
   filesmeta.file_1CUF = STRING(GR_file_byte)
ENDIF

IF N_Elements(gvexpect) NE 0 THEN BEGIN
     NCDF_VARGET, ncid1, 'n_gr_expected', gvexpect
     IF ( sortflag EQ 1 ) THEN BEGIN
        sort_status = sort_multi_d_array( elevorder, gvexpect, 2 )
        IF (sort_status EQ 1) THEN BEGIN
          status = sort_status
          goto, ErrorExit
        ENDIF
     ENDIF
ENDIF

IF N_Elements(gvreject) NE 0 THEN BEGIN
     NCDF_VARGET, ncid1, 'n_gr_z_rejected', gvreject
     IF ( sortflag EQ 1 ) THEN BEGIN
        sort_status = sort_multi_d_array( elevorder, gvreject, 2 )
        IF (sort_status EQ 1) THEN BEGIN
          status = sort_status
          goto, ErrorExit
        ENDIF
     ENDIF
ENDIF

IF ncversion GT 1.0 THEN BEGIN
   IF N_Elements(gv_rc_reject) NE 0 THEN BEGIN
      NCDF_VARGET, ncid1, 'n_gr_rc_rejected', gv_rc_reject
      IF ( sortflag EQ 1 ) THEN BEGIN
         sort_status = sort_multi_d_array( elevorder, gv_rc_reject, 2 )
         IF (sort_status EQ 1) THEN BEGIN
           status = sort_status
           goto, ErrorExit
         ENDIF
      ENDIF
   ENDIF

   IF N_Elements(gv_rp_reject) NE 0 THEN BEGIN
      NCDF_VARGET, ncid1, 'n_gr_rp_rejected', gv_rp_reject
      IF ( sortflag EQ 1 ) THEN BEGIN
         sort_status = sort_multi_d_array( elevorder, gv_rp_reject, 2 )
         IF (sort_status EQ 1) THEN BEGIN
           status = sort_status
           goto, ErrorExit
         ENDIF
      ENDIF
   ENDIF
ENDIF

IF N_Elements(gv_rr_reject) NE 0 THEN BEGIN
   NCDF_VARGET, ncid1, 'n_gr_rr_rejected', gv_rr_reject
   IF ( sortflag EQ 1 ) THEN BEGIN
      sort_status = sort_multi_d_array( elevorder, gv_rr_reject, 2 )
      IF (sort_status EQ 1) THEN BEGIN
        status = sort_status
        goto, ErrorExit
      ENDIF
   ENDIF
ENDIF

IF N_Elements(gv_zdr_reject) NE 0 THEN BEGIN
      NCDF_VARGET, ncid1, 'n_gr_zdr_rejected', gv_zdr_reject
      IF ( sortflag EQ 1 ) THEN BEGIN
         sort_status = sort_multi_d_array( elevorder, gv_zdr_reject, 2 )
         IF (sort_status EQ 1) THEN BEGIN
           status = sort_status
           goto, ErrorExit
         ENDIF
      ENDIF
ENDIF

IF N_Elements(gv_kdp_reject) NE 0 THEN BEGIN
      NCDF_VARGET, ncid1, 'n_gr_kdp_rejected', gv_kdp_reject
      IF ( sortflag EQ 1 ) THEN BEGIN
         sort_status = sort_multi_d_array( elevorder, gv_kdp_reject, 2 )
         IF (sort_status EQ 1) THEN BEGIN
           status = sort_status
           goto, ErrorExit
         ENDIF
      ENDIF
ENDIF

IF N_Elements(gv_RHOhv_reject) NE 0 THEN BEGIN
      NCDF_VARGET, ncid1, 'n_gr_rhohv_rejected', gv_RHOhv_reject
      IF ( sortflag EQ 1 ) THEN BEGIN
         sort_status = sort_multi_d_array( elevorder, gv_RHOhv_reject, 2 )
         IF (sort_status EQ 1) THEN BEGIN
           status = sort_status
           goto, ErrorExit
         ENDIF
      ENDIF
ENDIF

IF N_Elements(gv_hid_reject) NE 0 THEN BEGIN
      NCDF_VARGET, ncid1, 'n_gr_hid_rejected', gv_hid_reject
      IF ( sortflag EQ 1 ) THEN BEGIN
         sort_status = sort_multi_d_array( elevorder, gv_hid_reject, 2 )
         IF (sort_status EQ 1) THEN BEGIN
           status = sort_status
           goto, ErrorExit
         ENDIF
      ENDIF
ENDIF

IF N_Elements(gv_dzero_reject) NE 0 THEN BEGIN
      NCDF_VARGET, ncid1, 'n_gr_dzero_rejected', gv_dzero_reject
      IF ( sortflag EQ 1 ) THEN BEGIN
         sort_status = sort_multi_d_array( elevorder, gv_dzero_reject, 2 )
         IF (sort_status EQ 1) THEN BEGIN
           status = sort_status
           goto, ErrorExit
         ENDIF
      ENDIF
ENDIF

IF N_Elements(gv_nw_reject) NE 0 THEN BEGIN
      NCDF_VARGET, ncid1, 'n_gr_nw_rejected', gv_nw_reject
      IF ( sortflag EQ 1 ) THEN BEGIN
         sort_status = sort_multi_d_array( elevorder, gv_nw_reject, 2 )
         IF (sort_status EQ 1) THEN BEGIN
           status = sort_status
           goto, ErrorExit
         ENDIF
      ENDIF
ENDIF

IF ncversion GT 1.1 THEN BEGIN
   IF N_Elements(gv_dm_reject) NE 0 THEN BEGIN
      NCDF_VARGET, ncid1, 'n_gr_dm_rejected', gv_dm_reject
      IF ( sortflag EQ 1 ) THEN BEGIN
         sort_status = sort_multi_d_array( elevorder, gv_dm_reject, 2 )
         IF (sort_status EQ 1) THEN BEGIN
           status = sort_status
           goto, ErrorExit
         ENDIF
      ENDIF
   ENDIF

   IF N_Elements(gv_n2_reject) NE 0 THEN BEGIN
      NCDF_VARGET, ncid1, 'n_gr_n2_rejected', gv_n2_reject
      IF ( sortflag EQ 1 ) THEN BEGIN
         sort_status = sort_multi_d_array( elevorder, gv_n2_reject, 2 )
         IF (sort_status EQ 1) THEN BEGIN
           status = sort_status
           goto, ErrorExit
         ENDIF
      ENDIF
   ENDIF
ENDIF


IF N_Elements(dprexpect) NE 0 THEN BEGIN
     NCDF_VARGET, ncid1, 'n_dpr_expected', dprexpect
     IF ( sortflag EQ 1 ) THEN BEGIN
        sort_status = sort_multi_d_array( elevorder, dprexpect, 2 )
        IF (sort_status EQ 1) THEN BEGIN
          status = sort_status
          goto, ErrorExit
        ENDIF
     ENDIF
ENDIF

IF N_Elements(zrawreject) NE 0 THEN BEGIN
     NCDF_VARGET, ncid1, 'n_dpr_meas_z_rejected', zrawreject
     IF ( sortflag EQ 1 ) THEN BEGIN
        sort_status = sort_multi_d_array( elevorder, zrawreject, 2 )
        IF (sort_status EQ 1) THEN BEGIN
          status = sort_status
          goto, ErrorExit
        ENDIF
     ENDIF
ENDIF

IF N_Elements(zcorreject) NE 0 THEN BEGIN
     NCDF_VARGET, ncid1, 'n_dpr_corr_z_rejected', zcorreject
     IF ( sortflag EQ 1 ) THEN BEGIN
        sort_status = sort_multi_d_array( elevorder, zcorreject, 2 )
        IF (sort_status EQ 1) THEN BEGIN
          status = sort_status
          goto, ErrorExit
        ENDIF
     ENDIF
ENDIF

IF ncversion GT 1.2 THEN BEGIN
  IF N_Elements(epsilonreject) NE 0 THEN BEGIN
     NCDF_VARGET, ncid1, 'n_dpr_epsilon_rejected', epsilonreject
     IF ( sortflag EQ 1 ) THEN BEGIN
        sort_status = sort_multi_d_array( elevorder, epsilonreject, 2 )
        IF (sort_status EQ 1) THEN BEGIN
          status = sort_status
          goto, ErrorExit
        ENDIF
     ENDIF
  ENDIF
ENDIF

; let's make 1.3 a "reserved" version for the files with the 250-m-based
; DPR matchup variables made to match the DPRGMI reflectivity bins
IF ncversion EQ 1.3 THEN BEGIN
   IF N_Elements(dpr250expect) NE 0 THEN BEGIN
      NCDF_VARGET, ncid1, 'n_dpr_expected250m', dpr250expect
      IF ( sortflag EQ 1 ) THEN BEGIN
         sort_status = sort_multi_d_array( elevorder, dpr250expect, 2 )
         IF (sort_status EQ 1) THEN BEGIN
           status = sort_status
           goto, ErrorExit
         ENDIF
      ENDIF
   ENDIF

   IF N_Elements(zraw250reject) NE 0 THEN BEGIN
      NCDF_VARGET, ncid1, 'n_dpr_meas_z_rejected250m', zraw250reject
      IF ( sortflag EQ 1 ) THEN BEGIN
         sort_status = sort_multi_d_array( elevorder, zraw250reject, 2 )
         IF (sort_status EQ 1) THEN BEGIN
           status = sort_status
           goto, ErrorExit
         ENDIF
      ENDIF
   ENDIF

   IF N_Elements(zcor250reject) NE 0 THEN BEGIN
      NCDF_VARGET, ncid1, 'n_dpr_corr_z_rejected250m', zcor250reject
      IF ( sortflag EQ 1 ) THEN BEGIN
         sort_status = sort_multi_d_array( elevorder, zcor250reject, 2 )
         IF (sort_status EQ 1) THEN BEGIN
           status = sort_status
           goto, ErrorExit
         ENDIF
      ENDIF
   ENDIF
ENDIF

IF N_Elements(rainreject) NE 0 THEN BEGIN
     NCDF_VARGET, ncid1, 'n_dpr_corr_r_rejected', rainreject
     IF ( sortflag EQ 1 ) THEN BEGIN
        sort_status = sort_multi_d_array( elevorder, rainreject, 2 )
        IF (sort_status EQ 1) THEN BEGIN
          status = sort_status
          goto, ErrorExit
        ENDIF
     ENDIF
ENDIF

IF N_Elements(dpr_dm_reject) NE 0 THEN BEGIN
     NCDF_VARGET, ncid1, 'n_dpr_dm_rejected', dpr_dm_reject
     IF ( sortflag EQ 1 ) THEN BEGIN
        sort_status = sort_multi_d_array( elevorder, dpr_dm_reject, 2 )
        IF (sort_status EQ 1) THEN BEGIN
          status = sort_status
          goto, ErrorExit
        ENDIF
     ENDIF
ENDIF

IF N_Elements(dpr_nw_reject) NE 0 THEN BEGIN
     NCDF_VARGET, ncid1, 'n_dpr_nw_rejected', dpr_nw_reject
     IF ( sortflag EQ 1 ) THEN BEGIN
        sort_status = sort_multi_d_array( elevorder, dpr_nw_reject, 2 )
        IF (sort_status EQ 1) THEN BEGIN
          status = sort_status
          goto, ErrorExit
        ENDIF
     ENDIF
ENDIF

IF N_Elements(threeDreflect) NE 0 THEN BEGIN
     NCDF_VARGET, ncid1, 'GR_Z', threeDreflect
     IF ( sortflag EQ 1 ) THEN BEGIN
        sort_status = sort_multi_d_array( elevorder, threeDreflect, 2 )
        IF (sort_status EQ 1) THEN BEGIN
          status = sort_status
          goto, ErrorExit
        ENDIF
     ENDIF
ENDIF

IF N_Elements(threeDreflectMax) NE 0 THEN BEGIN
   NCDF_VARGET, ncid1, 'GR_Z_Max', threeDreflectMax
   IF ( sortflag EQ 1 ) THEN BEGIN
      sort_status = sort_multi_d_array( elevorder, threeDreflectMax, 2 )
      IF (sort_status EQ 1) THEN BEGIN
        status = sort_status
        goto, ErrorExit
      ENDIF
   ENDIF
ENDIF

IF N_Elements(threeDreflectStdDev) NE 0 THEN BEGIN
   NCDF_VARGET, ncid1, 'GR_Z_StdDev', threeDreflectStdDev
   IF ( sortflag EQ 1 ) THEN BEGIN
      sort_status = sort_multi_d_array( elevorder, threeDreflectStdDev, 2 )
      IF (sort_status EQ 1) THEN BEGIN
        status = sort_status
        goto, ErrorExit
      ENDIF
   ENDIF
ENDIF

IF N_Elements(GR_Zdr) NE 0 THEN BEGIN
      NCDF_VARGET, ncid1, 'GR_Zdr', GR_Zdr
      IF ( sortflag EQ 1 ) THEN BEGIN
         sort_status = sort_multi_d_array( elevorder, GR_Zdr, 2 )
         IF (sort_status EQ 1) THEN BEGIN
           status = sort_status
           goto, ErrorExit
         ENDIF
      ENDIF
ENDIF

IF N_Elements(GR_Zdr_Max) NE 0 THEN BEGIN
      NCDF_VARGET, ncid1, 'GR_Zdr_Max', GR_Zdr_Max
      IF ( sortflag EQ 1 ) THEN BEGIN
         sort_status = sort_multi_d_array( elevorder, GR_Zdr_Max, 2 )
         IF (sort_status EQ 1) THEN BEGIN
           status = sort_status
           goto, ErrorExit
         ENDIF
      ENDIF
ENDIF

IF N_Elements(GR_Zdr_StdDev) NE 0 THEN BEGIN
      NCDF_VARGET, ncid1, 'GR_Zdr_StdDev', GR_Zdr_StdDev
      IF ( sortflag EQ 1 ) THEN BEGIN
         sort_status = sort_multi_d_array( elevorder, GR_Zdr_StdDev, 2 )
         IF (sort_status EQ 1) THEN BEGIN
           status = sort_status
           goto, ErrorExit
         ENDIF
      ENDIF
ENDIF

IF N_Elements(GR_Kdp) NE 0 THEN BEGIN
      NCDF_VARGET, ncid1, 'GR_Kdp', GR_Kdp
      IF ( sortflag EQ 1 ) THEN BEGIN
         sort_status = sort_multi_d_array( elevorder, GR_Kdp, 2 )
         IF (sort_status EQ 1) THEN BEGIN
           status = sort_status
           goto, ErrorExit
         ENDIF
      ENDIF
ENDIF

IF N_Elements(GR_Kdp_Max) NE 0 THEN BEGIN
      NCDF_VARGET, ncid1, 'GR_Kdp_Max', GR_Kdp_Max
      IF ( sortflag EQ 1 ) THEN BEGIN
         sort_status = sort_multi_d_array( elevorder, GR_Kdp_Max, 2 )
         IF (sort_status EQ 1) THEN BEGIN
           status = sort_status
           goto, ErrorExit
         ENDIF
      ENDIF
ENDIF

IF N_Elements(GR_Kdp_StdDev) NE 0 THEN BEGIN
      NCDF_VARGET, ncid1, 'GR_Kdp_StdDev', GR_Kdp_StdDev
      IF ( sortflag EQ 1 ) THEN BEGIN
         sort_status = sort_multi_d_array( elevorder, GR_Kdp_StdDev, 2 )
         IF (sort_status EQ 1) THEN BEGIN
           status = sort_status
           goto, ErrorExit
         ENDIF
      ENDIF
ENDIF

IF N_Elements(GR_RHOhv) NE 0 THEN BEGIN
      NCDF_VARGET, ncid1, 'GR_RHOhv', GR_RHOhv
      IF ( sortflag EQ 1 ) THEN BEGIN
         sort_status = sort_multi_d_array( elevorder, GR_RHOhv, 2 )
         IF (sort_status EQ 1) THEN BEGIN
           status = sort_status
           goto, ErrorExit
         ENDIF
      ENDIF
ENDIF

IF N_Elements(GR_RHOhv_Max) NE 0 THEN BEGIN
      NCDF_VARGET, ncid1, 'GR_RHOhv_Max', GR_RHOhv_Max
      IF ( sortflag EQ 1 ) THEN BEGIN
         sort_status = sort_multi_d_array( elevorder, GR_RHOhv_Max, 2 )
         IF (sort_status EQ 1) THEN BEGIN
           status = sort_status
           goto, ErrorExit
         ENDIF
      ENDIF
ENDIF

IF N_Elements(GR_RHOhv_StdDev) NE 0 THEN BEGIN
      NCDF_VARGET, ncid1, 'GR_RHOhv_StdDev', GR_RHOhv_StdDev
      IF ( sortflag EQ 1 ) THEN BEGIN
         sort_status = sort_multi_d_array( elevorder, GR_RHOhv_StdDev, 2 )
         IF (sort_status EQ 1) THEN BEGIN
           status = sort_status
           goto, ErrorExit
         ENDIF
      ENDIF
ENDIF

IF ncversion GT 1.0 THEN BEGIN
   IF N_Elements(GR_RC_rainrate) NE 0 THEN BEGIN
      NCDF_VARGET, ncid1, 'GR_RC_rainrate', GR_RC_rainrate
      IF ( sortflag EQ 1 ) THEN BEGIN
         sort_status = sort_multi_d_array( elevorder, GR_RC_rainrate, 2 )
         IF (sort_status EQ 1) THEN BEGIN
           status = sort_status
           goto, ErrorExit
         ENDIF
      ENDIF
   ENDIF

   IF N_Elements(GR_RC_rainrate_Max) NE 0 THEN BEGIN
      NCDF_VARGET, ncid1, 'GR_RC_rainrate_Max', GR_RC_rainrate_Max
      IF ( sortflag EQ 1 ) THEN BEGIN
         sort_status = sort_multi_d_array( elevorder, GR_RC_rainrate_Max, 2 )
         IF (sort_status EQ 1) THEN BEGIN
           status = sort_status
           goto, ErrorExit
         ENDIF
      ENDIF
   ENDIF

   IF N_Elements(GR_RC_rainrate_StdDev) NE 0 THEN BEGIN
      NCDF_VARGET, ncid1, 'GR_RC_rainrate_StdDev', GR_RC_rainrate_StdDev
      IF ( sortflag EQ 1 ) THEN BEGIN
         sort_status = sort_multi_d_array( elevorder, GR_RC_rainrate_StdDev, 2 )
         IF (sort_status EQ 1) THEN BEGIN
           status = sort_status
           goto, ErrorExit
         ENDIF
      ENDIF
   ENDIF

   IF N_Elements(GR_RP_rainrate) NE 0 THEN BEGIN
      NCDF_VARGET, ncid1, 'GR_RP_rainrate', GR_RP_rainrate
      IF ( sortflag EQ 1 ) THEN BEGIN
         sort_status = sort_multi_d_array( elevorder, GR_RP_rainrate, 2 )
         IF (sort_status EQ 1) THEN BEGIN
           status = sort_status
           goto, ErrorExit
         ENDIF
      ENDIF
   ENDIF

   IF N_Elements(GR_RP_rainrate_Max) NE 0 THEN BEGIN
      NCDF_VARGET, ncid1, 'GR_RP_rainrate_Max', GR_RP_rainrate_Max
      IF ( sortflag EQ 1 ) THEN BEGIN
         sort_status = sort_multi_d_array( elevorder, GR_RP_rainrate_Max, 2 )
         IF (sort_status EQ 1) THEN BEGIN
           status = sort_status
           goto, ErrorExit
         ENDIF
      ENDIF
   ENDIF

   IF N_Elements(GR_RP_rainrate_StdDev) NE 0 THEN BEGIN
      NCDF_VARGET, ncid1, 'GR_RP_rainrate_StdDev', GR_RP_rainrate_StdDev
      IF ( sortflag EQ 1 ) THEN BEGIN
         sort_status = sort_multi_d_array( elevorder, GR_RP_rainrate_StdDev, 2 )
         IF (sort_status EQ 1) THEN BEGIN
           status = sort_status
           goto, ErrorExit
         ENDIF
      ENDIF
   ENDIF
ENDIF

IF N_Elements(GR_RR_rainrate) NE 0 THEN BEGIN
   IF ncversion EQ 1.0 THEN NCDF_VARGET, ncid1, 'GR_rainrate', GR_RR_rainrate $
   ELSE NCDF_VARGET, ncid1, 'GR_RR_rainrate', GR_RR_rainrate
   IF ( sortflag EQ 1 ) THEN BEGIN
      sort_status = sort_multi_d_array( elevorder, GR_RR_rainrate, 2 )
      IF (sort_status EQ 1) THEN BEGIN
        status = sort_status
        goto, ErrorExit
      ENDIF
   ENDIF
ENDIF

IF N_Elements(GR_RR_rainrate_Max) NE 0 THEN BEGIN
   IF ncversion EQ 1.0 THEN $
        NCDF_VARGET, ncid1, 'GR_rainrate_Max', GR_RR_rainrate_Max $
   ELSE NCDF_VARGET, ncid1, 'GR_RR_rainrate_Max', GR_RR_rainrate_Max
   IF ( sortflag EQ 1 ) THEN BEGIN
      sort_status = sort_multi_d_array( elevorder, GR_RR_rainrate_Max, 2 )
      IF (sort_status EQ 1) THEN BEGIN
        status = sort_status
        goto, ErrorExit
      ENDIF
   ENDIF
ENDIF

IF N_Elements(GR_RR_rainrate_StdDev) NE 0 THEN BEGIN
   IF ncversion EQ 1.0 THEN $
        NCDF_VARGET, ncid1, 'GR_rainrate_StdDev', GR_RR_rainrate_StdDev $
   ELSE NCDF_VARGET, ncid1, 'GR_RR_rainrate_StdDev', GR_RR_rainrate_StdDev
   IF ( sortflag EQ 1 ) THEN BEGIN
      sort_status = sort_multi_d_array( elevorder, GR_RR_rainrate_StdDev, 2 )
      IF (sort_status EQ 1) THEN BEGIN
        status = sort_status
        goto, ErrorExit
      ENDIF
   ENDIF
ENDIF

IF N_Elements(GR_HID) NE 0 THEN BEGIN
      NCDF_VARGET, ncid1, 'GR_HID', GR_HID
      IF ( sortflag EQ 1 ) THEN BEGIN
         sort_status = sort_multi_d_array( elevorder, GR_HID, 3 )
         IF (sort_status EQ 1) THEN BEGIN
           status = sort_status
           goto, ErrorExit
         ENDIF
      ENDIF
ENDIF

IF N_Elements(GR_Dzero) NE 0 THEN BEGIN
      NCDF_VARGET, ncid1, 'GR_Dzero', GR_Dzero
      IF ( sortflag EQ 1 ) THEN BEGIN
         sort_status = sort_multi_d_array( elevorder, GR_Dzero, 2 )
         IF (sort_status EQ 1) THEN BEGIN
           status = sort_status
           goto, ErrorExit
         ENDIF
      ENDIF
ENDIF

IF N_Elements(GR_Dzero_Max) NE 0 THEN BEGIN
      NCDF_VARGET, ncid1, 'GR_Dzero_Max', GR_Dzero_Max
      IF ( sortflag EQ 1 ) THEN BEGIN
         sort_status = sort_multi_d_array( elevorder, GR_Dzero_Max, 2 )
         IF (sort_status EQ 1) THEN BEGIN
           status = sort_status
           goto, ErrorExit
         ENDIF
      ENDIF
ENDIF

IF N_Elements(GR_Dzero_StdDev) NE 0 THEN BEGIN
      NCDF_VARGET, ncid1, 'GR_Dzero_StdDev', GR_Dzero_StdDev
      IF ( sortflag EQ 1 ) THEN BEGIN
         sort_status = sort_multi_d_array( elevorder, GR_Dzero_StdDev, 2 )
         IF (sort_status EQ 1) THEN BEGIN
           status = sort_status
           goto, ErrorExit
         ENDIF
      ENDIF
ENDIF

IF N_Elements(GR_Nw) NE 0 THEN BEGIN
      NCDF_VARGET, ncid1, 'GR_Nw', GR_Nw
      IF ( sortflag EQ 1 ) THEN BEGIN
         sort_status = sort_multi_d_array( elevorder, GR_Nw, 2 )
         IF (sort_status EQ 1) THEN BEGIN
           status = sort_status
           goto, ErrorExit
         ENDIF
      ENDIF
ENDIF

IF N_Elements(GR_Nw_Max) NE 0 THEN BEGIN
      NCDF_VARGET, ncid1, 'GR_Nw_Max', GR_Nw_Max
      IF ( sortflag EQ 1 ) THEN BEGIN
         sort_status = sort_multi_d_array( elevorder, GR_Nw_Max, 2 )
         IF (sort_status EQ 1) THEN BEGIN
           status = sort_status
           goto, ErrorExit
         ENDIF
      ENDIF
ENDIF

IF N_Elements(GR_Nw_StdDev) NE 0 THEN BEGIN
      NCDF_VARGET, ncid1, 'GR_Nw_StdDev', GR_Nw_StdDev
      IF ( sortflag EQ 1 ) THEN BEGIN
         sort_status = sort_multi_d_array( elevorder, GR_Nw_StdDev, 2 )
         IF (sort_status EQ 1) THEN BEGIN
           status = sort_status
           goto, ErrorExit
         ENDIF
      ENDIF
ENDIF

IF ncversion GT 1.1 THEN BEGIN
   IF N_Elements(GR_Dm) NE 0 THEN BEGIN
            NCDF_VARGET, ncid1, 'GR_Dm', GR_Dm
         IF ( sortflag EQ 1 ) THEN BEGIN
            sort_status = sort_multi_d_array( elevorder, GR_Dm, 2 )
            IF (sort_status EQ 1) THEN BEGIN
              status = sort_status
              goto, ErrorExit
            ENDIF
         ENDIF
   ENDIF
   
   IF N_Elements(GR_Dm_Max) NE 0 THEN BEGIN
         NCDF_VARGET, ncid1, 'GR_Dm_Max', GR_Dm_Max
         IF ( sortflag EQ 1 ) THEN BEGIN
            sort_status = sort_multi_d_array( elevorder, GR_Dm_Max, 2 )
            IF (sort_status EQ 1) THEN BEGIN
              status = sort_status
              goto, ErrorExit
            ENDIF
         ENDIF
   ENDIF
   
   IF N_Elements(GR_Dm_StdDev) NE 0 THEN BEGIN
         NCDF_VARGET, ncid1, 'GR_Dm_StdDev', GR_Dm_StdDev
         IF ( sortflag EQ 1 ) THEN BEGIN
            sort_status = sort_multi_d_array( elevorder, GR_Dm_StdDev, 2 )
            IF (sort_status EQ 1) THEN BEGIN
              status = sort_status
              goto, ErrorExit
            ENDIF
         ENDIF
   ENDIF
   
   IF N_Elements(GR_N2) NE 0 THEN BEGIN
         NCDF_VARGET, ncid1, 'GR_N2', GR_N2
         IF ( sortflag EQ 1 ) THEN BEGIN
            sort_status = sort_multi_d_array( elevorder, GR_N2, 2 )
            IF (sort_status EQ 1) THEN BEGIN
              status = sort_status
              goto, ErrorExit
            ENDIF
         ENDIF
   ENDIF
   
   IF N_Elements(GR_N2_Max) NE 0 THEN BEGIN
         NCDF_VARGET, ncid1, 'GR_N2_Max', GR_N2_Max
         IF ( sortflag EQ 1 ) THEN BEGIN
            sort_status = sort_multi_d_array( elevorder, GR_N2_Max, 2 )
            IF (sort_status EQ 1) THEN BEGIN
              status = sort_status
              goto, ErrorExit
            ENDIF
         ENDIF
   ENDIF
   
   IF N_Elements(GR_N2_StdDev) NE 0 THEN BEGIN
         NCDF_VARGET, ncid1, 'GR_N2_StdDev', GR_N2_StdDev
         IF ( sortflag EQ 1 ) THEN BEGIN
            sort_status = sort_multi_d_array( elevorder, GR_N2_StdDev, 2 )
            IF (sort_status EQ 1) THEN BEGIN
              status = sort_status
              goto, ErrorExit
            ENDIF
         ENDIF
   ENDIF
ENDIF
   
IF ncversion GT 1.2 THEN BEGIN
   IF N_Elements(GR_blockage) NE 0 THEN BEGIN
         NCDF_VARGET, ncid1, 'GR_blockage', GR_blockage
         IF ( sortflag EQ 1 ) THEN BEGIN
            sort_status = sort_multi_d_array( elevorder, GR_blockage, 2 )
            IF (sort_status EQ 1) THEN BEGIN
              status = sort_status
              goto, ErrorExit
            ENDIF
         ENDIF
   ENDIF
ENDIF

IF N_Elements(ZFactorMeasured) NE 0 THEN BEGIN
     NCDF_VARGET, ncid1, 'ZFactorMeasured', ZFactorMeasured
     IF ( sortflag EQ 1 ) THEN BEGIN
        sort_status = sort_multi_d_array( elevorder, ZFactorMeasured, 2 )
        IF (sort_status EQ 1) THEN BEGIN
          status = sort_status
          goto, ErrorExit
        ENDIF
     ENDIF
ENDIF

IF N_Elements(ZFactorCorrected) NE 0 THEN BEGIN
     NCDF_VARGET, ncid1, 'ZFactorCorrected', ZFactorCorrected
     IF ( sortflag EQ 1 ) THEN BEGIN
        sort_status = sort_multi_d_array( elevorder, ZFactorCorrected, 2 )
        IF (sort_status EQ 1) THEN BEGIN
          status = sort_status
          goto, ErrorExit
        ENDIF
     ENDIF
ENDIF

IF ncversion GT 1.2 THEN BEGIN
   IF N_Elements(epsilon) NE 0 THEN BEGIN
     NCDF_VARGET, ncid1, 'Epsilon', epsilon
     IF ( sortflag EQ 1 ) THEN BEGIN
        sort_status = sort_multi_d_array( elevorder, epsilon, 2 )
        IF (sort_status EQ 1) THEN BEGIN
          status = sort_status
          goto, ErrorExit
        ENDIF
     ENDIF
   ENDIF
ENDIF

; version 1.3 reserved for matchup files with 250m-based DPR reflectivity to
; match 2BDPRGMI Z
IF ncversion EQ 1.3 THEN BEGIN
   IF N_Elements(ZFactorMeasured250m) NE 0 THEN BEGIN
      NCDF_VARGET, ncid1, 'ZFactorMeasured250m', ZFactorMeasured250m
      IF ( sortflag EQ 1 ) THEN BEGIN
         sort_status = sort_multi_d_array( elevorder, ZFactorMeasured250m, 2 )
         IF (sort_status EQ 1) THEN BEGIN
            status = sort_status
            goto, ErrorExit
         ENDIF
      ENDIF
   ENDIF

   IF N_Elements(ZFactorCorrected250m) NE 0 THEN BEGIN
      NCDF_VARGET, ncid1, 'ZFactorCorrected250m', ZFactorCorrected250m
      IF ( sortflag EQ 1 ) THEN BEGIN
         sort_status = sort_multi_d_array( elevorder, ZFactorCorrected250m, 2 )
         IF (sort_status EQ 1) THEN BEGIN
            status = sort_status
            goto, ErrorExit
         ENDIF
      ENDIF
   ENDIF

   IF N_Elements(maxZFactorMeasured250m) NE 0 THEN BEGIN
      NCDF_VARGET, ncid1, 'MaxZFactorMeasured250m', maxZFactorMeasured250m
      IF ( sortflag EQ 1 ) THEN BEGIN
         sort_status = sort_multi_d_array( elevorder, maxZFactorMeasured250m, 2 )
         IF (sort_status EQ 1) THEN BEGIN
            status = sort_status
            goto, ErrorExit
         ENDIF
      ENDIF
   ENDIF
ENDIF

IF N_Elements(PrecipRate) NE 0 THEN BEGIN
     NCDF_VARGET, ncid1, 'PrecipRate', PrecipRate
     IF ( sortflag EQ 1 ) THEN BEGIN
        sort_status = sort_multi_d_array( elevorder, PrecipRate, 2 )
        IF (sort_status EQ 1) THEN BEGIN
          status = sort_status
          goto, ErrorExit
        ENDIF
     ENDIF
ENDIF

IF N_Elements(DPR_Dm) NE 0 THEN BEGIN
      NCDF_VARGET, ncid1, 'Dm', DPR_Dm
      IF ( sortflag EQ 1 ) THEN BEGIN
         sort_status = sort_multi_d_array( elevorder, DPR_Dm, 2 )
         IF (sort_status EQ 1) THEN BEGIN
           status = sort_status
           goto, ErrorExit
         ENDIF
      ENDIF
ENDIF

IF N_Elements(DPR_Nw) NE 0 THEN BEGIN
      NCDF_VARGET, ncid1, 'Nw', DPR_Nw
      IF ( sortflag EQ 1 ) THEN BEGIN
         sort_status = sort_multi_d_array( elevorder, DPR_Nw, 2 )
         IF (sort_status EQ 1) THEN BEGIN
           status = sort_status
           goto, ErrorExit
         ENDIF
      ENDIF
ENDIF

IF N_Elements(topHeight) NE 0 THEN BEGIN
     NCDF_VARGET, ncid1, 'topHeight', topHeight
     IF ( sortflag EQ 1 ) THEN BEGIN
        sort_status = sort_multi_d_array( elevorder, topHeight, 2 )
        IF (sort_status EQ 1) THEN BEGIN
          status = sort_status
          goto, ErrorExit
        ENDIF
     ENDIF
ENDIF

IF N_Elements(bottomHeight) NE 0 THEN BEGIN
     NCDF_VARGET, ncid1, 'bottomHeight', bottomHeight
     IF ( sortflag EQ 1 ) THEN BEGIN
        sort_status = sort_multi_d_array( elevorder, bottomHeight, 2 )
        IF (sort_status EQ 1) THEN BEGIN
          status = sort_status
          goto, ErrorExit
        ENDIF
     ENDIF
ENDIF

IF N_Elements(xCorners) NE 0 THEN BEGIN
     NCDF_VARGET, ncid1, 'xCorners', xCorners
     IF ( sortflag EQ 1 ) THEN BEGIN
        sort_status = sort_multi_d_array( elevorder, xCorners, 3 )
        IF (sort_status EQ 1) THEN BEGIN
          status = sort_status
          goto, ErrorExit
        ENDIF
     ENDIF
ENDIF

IF N_Elements(yCorners) NE 0 THEN BEGIN
     NCDF_VARGET, ncid1, 'yCorners', yCorners
     IF ( sortflag EQ 1 ) THEN BEGIN
        sort_status = sort_multi_d_array( elevorder, yCorners, 3 )
        IF (sort_status EQ 1) THEN BEGIN
          status = sort_status
          goto, ErrorExit
        ENDIF
     ENDIF
ENDIF

IF N_Elements(latitude) NE 0 THEN BEGIN
     NCDF_VARGET, ncid1, 'latitude', latitude
     IF ( sortflag EQ 1 ) THEN BEGIN
        sort_status = sort_multi_d_array( elevorder, latitude, 2 )
        IF (sort_status EQ 1) THEN BEGIN
          status = sort_status
          goto, ErrorExit
        ENDIF
     ENDIF
ENDIF

IF N_Elements(longitude) NE 0 THEN BEGIN
     NCDF_VARGET, ncid1, 'longitude', longitude
     IF ( sortflag EQ 1 ) THEN BEGIN
        sort_status = sort_multi_d_array( elevorder, longitude, 2 )
        IF (sort_status EQ 1) THEN BEGIN
          status = sort_status
          goto, ErrorExit
        ENDIF
     ENDIF
ENDIF

IF N_Elements(DPRlatitude) NE 0 THEN $
     NCDF_VARGET, ncid1, 'DPRlatitude', DPRlatitude

IF N_Elements(DPRlongitude) NE 0 THEN $
     NCDF_VARGET, ncid1, 'DPRlongitude', DPRlongitude

IF N_Elements(PrecipRateSurface) NE 0 THEN $
     NCDF_VARGET, ncid1, 'PrecipRateSurface', PrecipRateSurface

IF ncversion GT 1.0 THEN BEGIN
   IF N_Elements(piaFinal) NE 0 THEN $
        NCDF_VARGET, ncid1, 'piaFinal', piaFinal
   IF N_Elements(heightStormTop) NE 0 THEN $
        NCDF_VARGET, ncid1, 'heightStormTop', heightStormTop
ENDIF

IF N_Elements(SurfPrecipRate) NE 0 THEN $
     NCDF_VARGET, ncid1, 'SurfPrecipTotRate', SurfPrecipRate

IF N_Elements(BBheight) NE 0 THEN $
     NCDF_VARGET, ncid1, 'BBheight', BBheight  ; now in meters! (if > 0)

IF N_Elements(LandSurfaceType) NE 0 THEN $
     NCDF_VARGET, ncid1, 'LandSurfaceType', LandSurfaceType

IF N_Elements(FlagPrecip) NE 0 THEN $
     NCDF_VARGET, ncid1, 'FlagPrecip', FlagPrecip

IF N_Elements(TypePrecip) NE 0 THEN $
     NCDF_VARGET, ncid1, 'TypePrecip', TypePrecip

IF N_Elements(rayIndex) NE 0 THEN BEGIN $
     NCDF_VARGET, ncid1, 'scanNum', scanNum
     NCDF_VARGET, ncid1, 'rayNum', rayNum
     rayIndex = scanNum*RAYSPERSCAN + rayNum
ENDIF

IF N_Elements(BBstatus) NE 0 THEN $
     NCDF_VARGET, ncid1, 'BBstatus', BBstatus

IF N_Elements(clutterStatus) NE 0 THEN $
     NCDF_VARGET, ncid1, 'clutterStatus', clutterStatus

ErrorExit:
NCDF_CLOSE, ncid1

RETURN, status
END
