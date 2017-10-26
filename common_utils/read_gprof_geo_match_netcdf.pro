;===============================================================================
;+
; Copyright © 2011, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; read_gprof_geo_match_netcdf.pro           Morris/SAIC/GPM_GV      March 2014
;
; DESCRIPTION
; -----------
; Reads caller-specified data and metadata from GRtoGPROF matchup netCDF files. 
; Returns status value: 0 if successful read, 1 if unsuccessful or internal
; errors or inconsistencies occur.  File must be read-ready (unzipped/
; uncompressed) before calling this function.  The designation "XMI" stands for
; any satellite Microwave Imager used as input to the 2A-GPROF algorithm.

;
; PARAMETERS
; ----------
; ncfile               STRING, Full file pathname to netCDF matchup file (Input)
; matchupmeta          Structure holding general and algorithmic parameters (I/O)
; sweepsmeta           Array of Structures holding sweep elevation angles,
;                      and sweep start times in unix ticks and ascii text (I/O)
; sitemeta             Structure holding GR site location parameters (I/O)
; fieldFlags           Structure holding "data exists" flags for science 
;                        data variables (I/O)
; filesmeta            Structure holding GPROF and GR file names used in matchup (I/O)
;                      -- See file geo_match_nc_structs.inc for definition of
;                         the above structures.
;
; n_gr_expected              INT number of GR radar bins geometrically mapped to
;                             matchup sample volume for all GR_xxx_slantPath (I/O)
; GR_Z_slantPath             FLOAT 2-D array of horizontally-averaged, QC'd GR
;                             reflectivity along XMI field of view (with parallax
;                             adjustments), dBZ (I/O)
; GR_Z_Max_slantPath         FLOAT 2-D array, Maximum value of GR reflectivity
;                             bins included in GR_Z_slantPath, dBZ (I/O)
; GR_Z_StdDev_slantPath      FLOAT 2-D array, Standard Deviation of GR reflectivity
;                             bins included in GR_Z_slantPath, dBZ (I/O)
; n_gr_z_rejected            INT number of bins below GR dBZ cutoff in above (I/O)
; GR_RC_rainrate_slantPath   FLOAT 2-D array of horizontally-averaged, QC'd GR
;                             Cifelli rain rate along XMI field of view (with
;                             parallax adjustments), mm/h (I/O)
; GR_RC_rainrate_Max_slantPath  FLOAT 2-D array, Maximum value of GR Cifelli rain rate
;                               bins included in GR_RC_rainrate_slantPath, mm/h (I/O)
; GR_RC_rainrate_StdDev_slantPath  FLOAT 2-D array, Standard Deviation of GR Cifelli rain rate
;                                  bins included in GR_RC_rainrate_slantPath, mm/h (I/O)
; n_gr_rc_rejected           INT number of bins below GR rainrate cutoff in above (I/O)
; GR_RP_rainrate_slantPath   FLOAT 2-D array of horizontally-averaged, QC'd GR
;                             PolZR rain rate along XMI field of view (with
;                             parallax adjustments), mm/h (I/O)
; GR_RP_rainrate_Max_slantPath  FLOAT 2-D array, Maximum value of GR PolZR rain rate
;                               bins included in GR_RP_rainrate_slantPath, mm/h (I/O)
; GR_RP_rainrate_StdDev_slantPath  FLOAT 2-D array, Standard Deviation of GR PolZR rain rate
;                                  bins included in GR_RP_rainrate_slantPath, mm/h (I/O)
; n_gr_rp_rejected           INT number of bins below GR rainrate cutoff in above (I/O)
; GR_RR_rainrate_slantPath   FLOAT 2-D array of horizontally-averaged, QC'd GR
;                             DROPS rain rate along XMI field of view (with
;                             parallax adjustments), mm/h (I/O)
; GR_RR_rainrate_Max_slantPath  FLOAT 2-D array, Maximum value of GR DROPS rain rate
;                               bins included in GR_RR_rainrate_slantPath, mm/h (I/O)
; GR_RR_rainrate_StdDev_slantPath  FLOAT 2-D array, Standard Deviation of GR DROPS rain rate
;                                  bins included in GR_RR_rainrate_slantPath, mm/h (I/O)
; n_gr_rr_rejected           INT number of bins below GR rainrate cutoff in above (I/O)
; GR_Zdr_slantPath           FLOAT 2-D array of volume-matched GR mean Zdr
;                              (differential reflectivity)
; GR_Zdr_Max_slantPath       As above, but sample maximum of Zdr
; GR_Zdr_StdDev_slantPath    As above, but sample standard deviation of Zdr
; n_gr_zdr_rejected          INT number of missing-data bins in GR_Zdr_slantPath
;                            set of variables (I/O)
; GR_Kdp_slantPath           FLOAT 2-D array of volume-matched GR mean Kdp
;                              (specific differential phase)
; GR_Kdp_Max_slantPath       As above, but sample maximum of Kdp
; GR_Kdp_StdDev_slantPath    As above, but sample standard deviation of Kdp
; n_gr_kdp_rejected          INT number of missing-data bins in GR_Kdp_slantPath
;                              set of variables (I/O)
; GR_RHOhv_slantPath         FLOAT 2-D array of volume-matched GR mean RHOhv
;                             (co-polar correlation coefficient)
; GR_RHOhv_Max_slantPath     As above, but sample maximum of RHOhv
; GR_RHOhv_StdDev_slantPath  As above, but sample standard deviation of RHOhv
; n_gr_RHOhv_rejected        INT number of missing-data bins in
;                              GR_RHOhv_slantPath set of variables (I/O)
; GR_HID_slantPath           FLOAT 2-D array of volume-matched GR Hydrometeor ID
;                              category (count of GR bins in each HID category)
; mode_HID_slantPath         FLOAT 2-D array of volume-matched GR Hydrometeor ID
;                              (HID) "best" category (HID category with the
;                              highest count of bins in the sample volume)
; n_gr_hid_rejected          INT number of missing-data bins in GR_HID_slantPath
;                              set of variables (I/O)
; GR_Dzero_slantPath         FLOAT 2-D array of volume-matched GR mean D0
;                              (Median volume diameter)
; GR_Dzero_Max_slantPath     As above, but sample maximum of Dzero
; GR_Dzero_StdDev_slantPath  As above, but sample standard deviation of Dzero
; n_gr_Dzero_rejected        INT number of missing-data bins in
;                              GR_Dzero_slantPath set of variables (I/O)
; GR_Nw_slantPath            FLOAT 2-D array of volume-matched GR mean Nw
;                              (Normalized intercept parameter)
; GR_Nw_Max_slantPath        As above, but sample maximum of Nw
; GR_Nw_StdDev_slantPath     As above, but sample standard deviation of Nw
; n_gr_Nw_rejected           INT number of missing-data bins in GR_Nw_slantPath
;                              set of variables (I/O)
; GR_blockage_slantPath      FLOAT 2-D array of volume-matched GR mean beam
;                              blockage fraction
;
; n_gr_vpr_expected          INT number of GR radar bins geometrically mapped to
;                              matchup sample volume for GR_Z_VPR (I/O)
; GR_Z_VPR                   FLOAT 2-D array of horizontally-averaged, QC'd GR
;                              reflectivity along local vertical above XMI
;                              footprint, dBZ (I/O)
; GR_Z_Max_VPR               FLOAT 2-D array, Maximum value of GR reflectivity
;                              bins included in GR_Z_VPR, dBZ (I/O)
; GR_Z_StdDev_VPR            FLOAT 2-D array, Standard Deviation of GR reflectivity
;                              bins included in GR_Z_VPR, dBZ (I/O)
; n_gr_z_vpr_rejected          INT number of bins below GR dBZ cutoff in above (I/O)
; GR_RC_rainrate_VPR            FLOAT 2-D array of horizontally-averaged, QC'd GR
;                              Cifelli rain rate along local vertical, mm/h (I/O)
; GR_RC_rainrate_Max_VPR        FLOAT 2-D array, Maximum value of GR Cifelli rain rate
;                              bins included in GR_RC_rainrate_VPR, mm/h (I/O)
; GR_RC_rainrate_StdDev_VPR     FLOAT 2-D array, Standard Deviation of GR Cifelli rain rate
;                              bins included in GR_RC_rainrate_VPR, mm/h (I/O)
; n_gr_rc_vpr_rejected       INT number of bins below GR rainrate cutoff in above (I/O)
; GR_RP_rainrate_VPR            FLOAT 2-D array of horizontally-averaged, QC'd GR
;                              PolZR rain rate along local vertical, mm/h (I/O)
; GR_RP_rainrate_Max_VPR        FLOAT 2-D array, Maximum value of GR PolZR rain rate
;                              bins included in GR_RP_rainrate_VPR, mm/h (I/O)
; GR_RP_rainrate_StdDev_VPR     FLOAT 2-D array, Standard Deviation of GR PolZR rain rate
;                              bins included in GR_RP_rainrate_VPR, mm/h (I/O)
; n_gr_rp_vpr_rejected       INT number of bins below GR rainrate cutoff in above (I/O)
; GR_RR_rainrate_VPR            FLOAT 2-D array of horizontally-averaged, QC'd GR
;                              DROPS rain rate along local vertical, mm/h (I/O)
; GR_RR_rainrate_Max_VPR        FLOAT 2-D array, Maximum value of GR DROPS rain rate
;                              bins included in GR_RR_rainrate_VPR, mm/h (I/O)
; GR_RR_rainrate_StdDev_VPR     FLOAT 2-D array, Standard Deviation of GR DROPS rain rate
;                              bins included in GR_RR_rainrate_VPR, mm/h (I/O)
; n_gr_rr_vpr_rejected       INT number of bins below GR rainrate cutoff in above (I/O)
; GR_Zdr_VPR                 FLOAT 2-D array of volume-matched GR mean Zdr
;                              (differential reflectivity)
; GR_Zdr_Max_VPR             As above, but sample maximum of Zdr
; GR_Zdr_StdDev_VPR          As above, but sample standard deviation of Zdr
; n_gr_zdr_vpr_rejected      INT number of missing-data bins in GR_Zdr_VPR
;                              set of variables (I/O)
; GR_Kdp_VPR                 FLOAT 2-D array of volume-matched GR mean Kdp
;                              (specific differential phase)
; GR_Kdp_Max_VPR             As above, but sample maximum of Kdp
; GR_Kdp_StdDev_VPR          As above, but sample standard deviation of Kdp
; n_gr_kdp_vpr_rejected      INT number of missing-data bins in GR_Kdp_VPR
;                              set of variables (I/O)
; GR_RHOhv_VPR               FLOAT 2-D array of volume-matched GR mean RHOhv
;                             (co-polar correlation coefficient)
; GR_RHOhv_Max_VPR           As above, but sample maximum of RHOhv
; GR_RHOhv_StdDev_VPR        As above, but sample standard deviation of RHOhv
; n_gr_RHOhv_vpr_rejected    INT number of missing-data bins in
;                              GR_RHOhv_VPR set of variables (I/O)
; GR_HID_VPR                 FLOAT 3-D array of volume-matched GR Hydrometeor ID
;                              category (count of GR bins in each HID category)
; mode_HID_VPR               FLOAT 2-D array of volume-matched GR Hydrometeor ID
;                              (HID) "best" category (HID category with the
;                              highest count of bins in the sample volume)
; n_gr_hid_vpr_rejected      INT number of missing-data bins in GR_HID_VPR
;                              set of variables (I/O)
; GR_Dzero_VPR               FLOAT 2-D array of volume-matched GR mean D0
;                              (Median volume diameter)
; GR_Dzero_Max_VPR           As above, but sample maximum of Dzero
; GR_Dzero_StdDev_VPR        As above, but sample standard deviation of Dzero
; n_gr_Dzero_vpr_rejected    INT number of missing-data bins in
;                              GR_Dzero_VPR set of variables (I/O)
; GR_Nw_VPR                  FLOAT 2-D array of volume-matched GR mean Nw
;                              (Normalized intercept parameter)
; GR_Nw_Max_VPR              As above, but sample maximum of Nw
; GR_Nw_StdDev_VPR           As above, but sample standard deviation of Nw
; n_gr_Nw_vpr_rejected       INT number of missing-data bins in GR_Nw_VPR
;                              set of variables (I/O)
; GR_blockage_VPR            FLOAT 2-D array of volume-matched GR mean beam
;                              blockage fraction
; topHeight            FLOAT 2-D array of mean GR beam top along XMI field
;                        of view (with parallax adjustments) (I/O)
; bottomHeight         FLOAT 2-D array of mean GR beam bottoms along XMI field
;                        of view (with parallax adjustments) (I/O)
; topHeight_vpr        FLOAT 2-D array of mean GR beam top along local vertical
;                        above XMI footprint (I/O)
; bottomHeight_vpr     FLOAT 2-D array of mean GR beam bottoms along local vertical
;                        above XMI footprint (I/O)
; xCorners             FLOAT 3-D array of parallax-adjusted XMI footprint corner
;                        X-coordinates in km, 4 per footprint.(I/O)
; yCorners             FLOAT 3-D array of parallax-adjusted XMI footprint corner
;                        Y-coordinates in km, 4 per footprint.(I/O)
; latitude             FLOAT 2-D array of parallax-adjusted XMI footprint center
;                        latitude, degrees (I/O)
; longitude            FLOAT 2-D array of parallax-adjusted XMI footprint center
;                        longitude, degrees (I/O)
; XMIlatitude          FLOAT array of surface intersection XMI footprint center
;                        latitude, degrees (I/O)
; XMIlongitude         FLOAT array of surface intersection XMI footprint center
;                        longitude, degrees (I/O)
; surfacePrecipitation FLOAT array of GPROF estimated rain rate at surface, mm/h (I/O)
; surfaceTypeIndex     INT array of GPROF 'surfaceTypeIndex' flag, coded category (I/O)
; rainFlag             INT array of XMI rain/no-rain flag, category (I/O)
; pixelStatus             INT array of XMI pixelStatus values, category (I/O)
; PoP                  INT array of XMI Probability of Precipitation values,
;                        percent (I/O)
; Tc                   FLOAT 2-D array of 1C-R-XCAL microwave imager calibrated
;                        brightness values for each instrument channel
; Tc_channel_names     STRING array of Tc channel names (frequency/polarization)
; Quality              INT 2-D array of Quality flag values for Tc as defined in
;                        the 1C-R-XCAL product
; freezingHeight       INT array of XMI 2A12 freezing height values, meters (I/O)
; rayIndex             INT array of XMI product ray,scan IDL array index,
;                        relative to the full 2A12 products (I/O)
;
; RETURNS
; -------
; status               INT - Status of call to function, 0=success, 1=failure
;
; HISTORY
; -------
; 06/01/11 by Bob Morris, GPM GV (SAIC)
;  - Created from read_tmi_geo_match_netcdf.pro
; 06/02/14 by Bob Morris, GPM GV (SAIC)
;  - Renamed read-in variables GR_RR_* to GR_rainrate_* to match defined I/O
;    parameter names.  We are still not totally consistent in the use of rr/RR
;    and rainrate/RAINRATE in variable and flag names and structure tags.
; 11/06/14 by Bob Morris, GPM GV (SAIC)
;  - Added processing of GR RC and RP rainrate fields for version 1.1 file.
;    Involved renaming of GR_Rainrate* variables to GR_RR_Rainrate*, and added
;    logic to skip over the RC and RP variables if matchup file version is 1.0.
; 11/13/15 by Bob Morris, GPM GV (SAIC)
;  - Added processing of GR_blockage variables and their presence flags for
;    version 1.11 file.
; 07/07/16 by Bob Morris, GPM GV (SAIC)
;  - Added processing of Tc, Quality, and Tc_channel_names variables and
;    file_1crxcal global attribute for version 1.2 file.
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
           print, 'ERROR from sort_multi_d_array() in read_gprof_geo_match_netcdf.pro:'
           print, 'Too many dimensions (', sz[0], ') in array to be sorted!'
           status=1
         END
   ENDCASE

ENDIF ELSE BEGIN
   print, 'ERROR from sort_multi_d_array() in read_gprof_geo_match_netcdf.pro:'
   print, 'Size of array dimension over which to sort does not match number of sort indices!'
   status=1
ENDELSE

return, status
end

;===============================================================================

; MODULE 3

FUNCTION get_and_sort_array_var, ncid, varName, vararr, sortflag, sortorder, $
                                 sortdim

status = 0  ; set to success
NCDF_VARGET, ncid, varName, vararr
IF ( sortflag EQ 1 ) THEN $
   status = sort_multi_d_array( sortorder, vararr, sortdim )

return, status
end

;===============================================================================

; MODULE 1

FUNCTION read_gprof_geo_match_netcdf, ncfile,                                 $
   ; metadata structures/parameters
    matchupmeta=matchupmeta, sweepsmeta=sweepsmeta, sitemeta=sitemeta,        $
    fieldflags=fieldFlags, filesmeta=filesmeta,                               $

   ; threshold/data completeness parameters for vert/horiz averaged values
   ; along XMI slant path (sp) and local vertical (vpr):
    grexpect_sp=n_gr_expected, z_reject_sp=n_gr_z_rejected,                 $
    rc_reject_sp=n_gr_rc_rejected, rp_reject_sp=n_gr_rp_rejected,           $
    rr_reject_sp=n_gr_rr_rejected, zdr_reject_sp=n_gr_zdr_rejected,         $
    kdp_reject_sp=n_gr_kdp_rejected, rhohv_reject_sp=n_gr_rhohv_rejected,   $
    hid_reject_sp=n_gr_hid_rejected, dzero_reject_sp=n_gr_dzero_rejected,   $
    nw_reject_sp=n_gr_nw_rejected,                                       $
    grexpect_vpr=n_gr_vpr_expected, z_reject_vpr=n_gr_z_vpr_rejected,               $
    rc_reject_vpr=n_gr_rc_vpr_rejected, rp_reject_vpr=n_gr_rp_vpr_rejected,         $
    rr_reject_vpr=n_gr_rr_vpr_rejected, zdr_reject_vpr=n_gr_zdr_vpr_rejected,       $
    kdp_reject_vpr=n_gr_kdp_vpr_rejected, rhohv_reject_vpr=n_gr_rhohv_vpr_rejected, $
    hid_reject_vpr=n_gr_hid_vpr_rejected, dzero_reject_vpr=n_gr_dzero_vpr_rejected, $
    nw_reject_vpr=n_gr_nw_vpr_rejected,                                             $

   ; horizontally averaged GR values on sweeps, along XMI slant path and
   ; local vertical:
    Z_SP = GR_Z_slantPath, Z_vpr = GR_Z_VPR,                             $
    Z_StdDev_SP = GR_Z_StdDev_slantPath, Z_StdDev_vpr = GR_Z_StdDev_VPR, $
    Z_Max_SP = GR_Z_Max_slantPath, Z_Max_vpr = GR_Z_Max_VPR,             $
    RC_SP = GR_RC_rainrate_slantPath, RC_vpr = GR_RC_rainrate_VPR,                             $
    RC_StdDev_SP = GR_RC_rainrate_StdDev_slantPath, RC_StdDev_vpr = GR_RC_rainrate_StdDev_VPR, $
    RC_Max_SP = GR_RC_rainrate_Max_slantPath, RC_Max_vpr = GR_RC_rainrate_Max_VPR,             $
    RP_SP = GR_RP_rainrate_slantPath, RP_vpr = GR_RP_rainrate_VPR,                             $
    RP_StdDev_SP = GR_RP_rainrate_StdDev_slantPath, RP_StdDev_vpr = GR_RP_rainrate_StdDev_VPR, $
    RP_Max_SP = GR_RP_rainrate_Max_slantPath, RP_Max_vpr = GR_RP_rainrate_Max_VPR,             $
    RR_SP = GR_RR_rainrate_slantPath, RR_vpr = GR_RR_rainrate_VPR,                             $
    RR_StdDev_SP = GR_RR_rainrate_StdDev_slantPath, RR_StdDev_vpr = GR_RR_rainrate_StdDev_VPR, $
    RR_Max_SP = GR_RR_rainrate_Max_slantPath, RR_Max_vpr = GR_RR_rainrate_Max_VPR,             $
    ZDR_SP = GR_Zdr_slantPath, ZDR_VPR = GR_Zdr_VPR,                             $
    ZDR_STDDEV_SP = GR_Zdr_StdDev_slantPath, ZDR_StdDev_VPR = GR_Zdr_StdDev_VPR, $
    ZDR_MAX_SP = GR_Zdr_Max_slantPath, ZDR_Max_VPR = GR_Zdr_Max_VPR,             $
    KDP_SP = GR_Kdp_slantPath, KDP_VPR = GR_Kdp_VPR,                             $
    KDP_STDDEV_SP = GR_Kdp_StdDev_slantPath, KDP_StdDev_VPR = GR_Kdp_StdDev_VPR, $
    KDP_MAX_SP = GR_Kdp_Max_slantPath, KDP_Max_VPR = GR_Kdp_Max_VPR,             $
    RHOHV_SP = GR_RHOhv_slantPath, RHOHV_VPR = GR_RHOhv_VPR,                             $
    RHOHV_STDDEV_SP = GR_RHOhv_StdDev_slantPath, RHOHV_StdDev_VPR = GR_RHOhv_StdDev_VPR, $
    RHOHV_MAX_SP = GR_RHOhv_Max_slantPath, RHOHV_Max_VPR = GR_RHOhv_Max_VPR,             $
    HID_SP = GR_HID_slantPath, HID_VPR = GR_HID_VPR, $
    DZERO_SP = GR_Dzero_slantPath, DZERO_VPR = GR_Dzero_VPR,                             $
    DZERO_STDDEV_SP = GR_Dzero_StdDev_slantPath, DZERO_StdDev_VPR = GR_Dzero_StdDev_VPR, $
    DZERO_MAX_SP = GR_Dzero_Max_slantPath, DZERO_Max_VPR = GR_Dzero_Max_VPR,             $
    NW_SP = GR_Nw_slantPath, NW_VPR = GR_Nw_VPR,                             $
    NW_STDDEV_SP = GR_Nw_StdDev_slantPath, NW_StdDev_VPR = GR_Nw_StdDev_VPR, $
    NW_MAX_SP = GR_Nw_Max_slantPath, NW_Max_VPR = GR_Nw_Max_VPR,             $
    BLOCKAGE_SP = GR_blockage_slantPath, BLOCKAGE_VPR = GR_blockage_VPR,     $

   ; spatial parameters for XMI and GR values at sweep elevations:
    topHeight_SP=topHeight, bottomHeight_SP=bottomHeight,           $
    xCorners=xCorners, yCorners=yCorners,                           $
    latitude=latitude, longitude=longitude,                         $
    topHeight_vpr=topHeight_vpr, bottomHeight_vpr=bottomHeight_vpr, $

   ; spatial parameters for XMI at earth surface level:
    XMIlatitude=XMIlatitude, XMIlongitude=XMIlongitude, $

   ; XMI science values at earth surface level, or as ray summaries:
    surfacePrecipitation=surfacePrecipitation, sfctype=surfaceTypeIndex, $
    pixelStatus=pixelStatus, PoP=PoP, TC_VALUES=Tc, QUALITY=Quality, $
    tmi_idx_long=rayIndex, $
   ; XMI Tc channel names:
    TC_CHANNEL_NAMES = Tc_channel_names

status = 0

ncid1 = NCDF_OPEN( ncfile )
IF ( N_Elements(ncid1) EQ 0 ) THEN BEGIN
   print, "ERROR from read_gprof_geo_match_netcdf:"
   print, "File copy ", ncfile, " is not a valid netCDF file!"
   status = 1
   goto, ErrorExit2
ENDIF

; determine the number of global attributes and check the name of the first one
; to verify that we have the correct type of file
attstruc=ncdf_inquire(ncid1)
IF ( attstruc.ngatts GT 0 ) THEN BEGIN
   typeversion = ncdf_attname(ncid1, 0, /global)
   IF ( typeversion NE 'PPS_Version' ) THEN BEGIN
      print, ''
      print, "ERROR from read_geo_match_netcdf:"
      print, "File copy ", ncfile, " is not a GPROF-GR matchup file!"
      print, "Global variable 1: ",typeversion, ", expecting 'PPS_Version'"
      print, ''
      status = 1
      goto, ErrorExit2
   ENDIF
ENDIF ELSE BEGIN
   print, ''
   print, "ERROR from read_geo_match_netcdf:"
   print, "File copy ", ncfile, " has no global attributes!"
   print, ''
   status = 1
   goto, ErrorExit2
ENDELSE

; always determine the version of the matchup netCDF file first -- determines
; which variables can be retrieved
versid = NCDF_VARID(ncid1, 'version')
NCDF_ATTGET, ncid1, versid, 'long_name', vers_def_byte
vers_def = string(vers_def_byte)
IF ( vers_def ne 'Geo Match File Version' ) THEN BEGIN
   print, "ERROR from read_gprof_geo_match_netcdf:"
   print, "File copy ", ncfile, " is not a valid geo_match netCDF file!"
   status = 1
   goto, ErrorExit2
ENDIF
NCDF_VARGET, ncid1, versid, ncversion

IF N_Elements(matchupmeta) NE 0 THEN BEGIN
     NCDF_VARGET, ncid1, 'timeNearestApproach', dtime
     matchupmeta.timeNearestApproach = dtime
     NCDF_VARGET, ncid1, 'atimeNearestApproach', txtdtimebyte
     matchupmeta.atimeNearestApproach = string(txtdtimebyte)
     matchupmeta.num_volumes = 1  ; only holds data for one GR volume scan
     zdimid = NCDF_DIMID(ncid1, 'elevationAngle')
     NCDF_DIMINQ, ncid1, zdimid, XDIMNAME, ncnz
     matchupmeta.num_sweeps = ncnz
     fpdimid = NCDF_DIMID(ncid1, 'fpdim')
     NCDF_DIMINQ, ncid1, fpdimid, FPDIMNAME, nprfp
     matchupmeta.num_footprints = nprfp
     NCDF_VARGET, ncid1, 'rangeThreshold', rngthresh
     matchupmeta.rangeThreshold = rngthresh
     NCDF_VARGET, ncid1, 'GR_dBZ_min', gvzmin
     matchupmeta.GV2TMI_dBZ_min = gvzmin
    ; use tmi_rain_min slot in structure for gprof_rain_min
     NCDF_VARGET, ncid1, 'gprof_rain_min', rnmin
     matchupmeta.tmi_rain_min = rnmin
;     NCDF_VARGET, ncid1, versid, ncversion  ; already "got" this variable
     matchupmeta.nc_file_version = ncversion
     ncdf_attget, ncid1, 'PPS_Version', PPS_vers_byte, /global
     matchupmeta.PPS_Version = STRING(PPS_vers_byte)
     ncdf_attget, ncid1, 'GV_UF_Z_field', gr_UF_field_byte, /global
     matchupmeta.GV_UF_Z_field = STRING(gr_UF_field_byte)
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
ENDIF

IF N_Elements(sweepsmeta) NE 0 THEN BEGIN
     zdimid = NCDF_DIMID(ncid1, 'elevationAngle')
     NCDF_DIMINQ, ncid1, zdimid, XDIMNAME, ncnz  ; number of sweeps/elevs.
     NCDF_VARGET, ncid1, 'elevationAngle', nc_zlevels
     elevorder = SORT(nc_zlevels)
     ascorder = INDGEN(ncnz)
     sortflag=0
     IF TOTAL( ABS(elevorder-ascorder) ) NE 0 THEN BEGIN
        PRINT, 'read_gprof_geo_match_netcdf(): Elevation angles not in order! Resorting data.'
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
        PRINT, 'read_gprof_geo_match_netcdf(): Elevation angles not in order! Resorting data.'
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
     NCDF_VARGET, ncid1, 'have_GR_Z_slantPath', have_GR_Z_slantPath
     fieldFlags.have_GR_Z_slantPath = have_GR_Z_slantPath
     NCDF_VARGET, ncid1, 'have_GR_Z_VPR', have_GR_Z_VPR
     fieldFlags.have_GR_Z_VPR = have_GR_Z_VPR
     IF ncversion GT 1.0 THEN BEGIN
        NCDF_VARGET, ncid1, 'have_GR_RC_rainrate_slantPath', have_GR_RC_slantPath
        fieldFlags.have_GR_RC_slantPath = have_GR_RC_slantPath
        NCDF_VARGET, ncid1, 'have_GR_RC_rainrate_VPR', have_GR_RC_VPR
        fieldFlags.have_GR_RC_VPR = have_GR_RC_VPR
        NCDF_VARGET, ncid1, 'have_GR_RP_rainrate_slantPath', have_GR_RP_slantPath
        fieldFlags.have_GR_RP_slantPath = have_GR_RP_slantPath
        NCDF_VARGET, ncid1, 'have_GR_RP_rainrate_VPR', have_GR_RP_VPR
        fieldFlags.have_GR_RP_VPR = have_GR_RP_VPR
        NCDF_VARGET, ncid1, 'have_GR_RR_rainrate_slantPath', have_GR_RR_slantPath
        fieldFlags.have_GR_RR_slantPath = have_GR_RR_slantPath
        NCDF_VARGET, ncid1, 'have_GR_RR_rainrate_VPR', have_GR_RR_VPR
        fieldFlags.have_GR_RR_VPR = have_GR_RR_VPR
     ENDIF ELSE BEGIN
        NCDF_VARGET, ncid1, 'have_GR_rainrate_slantPath', have_GR_RR_slantPath
        fieldFlags.have_GR_RR_slantPath = have_GR_RR_slantPath
        NCDF_VARGET, ncid1, 'have_GR_rainrate_VPR', have_GR_RR_VPR
        fieldFlags.have_GR_RR_VPR = have_GR_RR_VPR
     ENDELSE
     NCDF_VARGET, ncid1, 'have_GR_Zdr_slantPath', have_GR_Zdr_slantPath
     fieldFlags.have_GR_Zdr_slantPath = have_GR_Zdr_slantPath
     NCDF_VARGET, ncid1, 'have_GR_Zdr_VPR', have_GR_Zdr_VPR
     fieldFlags.have_GR_Zdr_VPR = have_GR_Zdr_VPR
     NCDF_VARGET, ncid1, 'have_GR_Kdp_slantPath', have_GR_Kdp_slantPath
     fieldFlags.have_GR_Kdp_slantPath = have_GR_Kdp_slantPath
     NCDF_VARGET, ncid1, 'have_GR_Kdp_VPR', have_GR_Kdp_VPR
     fieldFlags.have_GR_Kdp_VPR = have_GR_Kdp_VPR
     NCDF_VARGET, ncid1, 'have_GR_RHOhv_slantPath', have_GR_RHOhv_slantPath
     fieldFlags.have_GR_RHOhv_slantPath = have_GR_RHOhv_slantPath
     NCDF_VARGET, ncid1, 'have_GR_RHOhv_VPR', have_GR_RHOhv_VPR
     fieldFlags.have_GR_RHOhv_VPR = have_GR_RHOhv_VPR
     NCDF_VARGET, ncid1, 'have_GR_HID_slantPath', have_GR_HID_slantPath
     fieldFlags.have_GR_HID_slantPath = have_GR_HID_slantPath
     NCDF_VARGET, ncid1, 'have_GR_HID_VPR', have_GR_HID_VPR
     fieldFlags.have_GR_HID_VPR = have_GR_HID_VPR
     NCDF_VARGET, ncid1, 'have_GR_Dzero_slantPath', have_GR_Dzero_slantPath
     fieldFlags.have_GR_Dzero_slantPath = have_GR_Dzero_slantPath
     NCDF_VARGET, ncid1, 'have_GR_Dzero_VPR', have_GR_Dzero_VPR
     fieldFlags.have_GR_Dzero_VPR = have_GR_Dzero_VPR
     NCDF_VARGET, ncid1, 'have_GR_Nw_slantPath', have_GR_Nw_slantPath
     fieldFlags.have_GR_Nw_slantPath = have_GR_Nw_slantPath
     NCDF_VARGET, ncid1, 'have_GR_Nw_VPR', have_GR_Nw_VPR
     fieldFlags.have_GR_Nw_VPR = have_GR_Nw_VPR
     IF ncversion GT 1.1 THEN BEGIN
        NCDF_VARGET, ncid1, 'have_GR_blockage_slantPath', have_GR_blockage_slantPath
        fieldFlags.have_GR_blockage_slantPath = have_GR_blockage_slantPath
        NCDF_VARGET, ncid1, 'have_GR_blockage_VPR', have_GR_blockage_VPR
        fieldFlags.have_GR_blockage_VPR = have_GR_blockage_VPR
     ENDIF
     NCDF_VARGET, ncid1, 'have_surfaceTypeIndex', have_surfaceTypeIndex
     fieldFlags.have_surfaceTypeIndex = have_surfaceTypeIndex
     NCDF_VARGET, ncid1, 'have_surfacePrecipitation', have_surfacePrecipitation
     fieldFlags.have_surfacePrecipitation = have_surfacePrecipitation
     NCDF_VARGET, ncid1, 'have_pixelStatus', have_pixelStatus
     fieldFlags.have_pixelStatus = have_pixelStatus
     NCDF_VARGET, ncid1, 'have_PoP', have_PoP
     fieldFlags.have_PoP = have_PoP
     IF ncversion GE 1.2 THEN BEGIN
        NCDF_VARGET, ncid1, 'have_Tc', have_Tc
        fieldFlags.have_Tc = have_Tc
     ENDIF
ENDIF

; Read GPROF and GR filenames and override the 'UNKNOWN' initial values in the structure
IF N_Elements(filesmeta) NE 0 THEN BEGIN
      ncdf_attget, ncid1, '2AGPROF_file', _xxx_file_byte, /global
      filesmeta.file_2agprof = STRING(_xxx_file_byte)
      IF ncversion GE 1.2 THEN BEGIN
         ncdf_attget, ncid1, '1CRXCAL_file', _xxx_file_byte, /global
         filesmeta.file_1crxcal = STRING(_xxx_file_byte)
      ENDIF
      ncdf_attget, ncid1, 'GR_file', _xxx_file_byte, /global
      filesmeta.file_1CUF = STRING(_xxx_file_byte)
ENDIF

IF N_Elements(n_gr_expected) NE 0 THEN BEGIN
   sort_status=get_and_sort_array_var( ncid1, 'n_gr_expected', n_gr_expected, $
                                       sortflag, elevorder, 2 )
   IF (sort_status EQ 1) THEN goto, ErrorExit
ENDIF

IF N_Elements(n_gr_vpr_expected) NE 0 THEN BEGIN
   sort_status=get_and_sort_array_var( ncid1, 'n_gr_vpr_expected', $
                                       n_gr_vpr_expected, $
                                       sortflag, elevorder, 2 )
   IF (sort_status EQ 1) THEN goto, ErrorExit
ENDIF

IF N_Elements(n_gr_z_rejected) NE 0 THEN BEGIN
   sort_status=get_and_sort_array_var( ncid1, 'n_gr_z_rejected', $
                                       n_gr_z_rejected, $
                                       sortflag, elevorder, 2 )
   IF (sort_status EQ 1) THEN goto, ErrorExit
ENDIF

IF N_Elements(n_gr_z_vpr_rejected) NE 0 THEN BEGIN
   sort_status=get_and_sort_array_var( ncid1, 'n_gr_z_vpr_rejected', $
                                       n_gr_z_vpr_rejected, $
                                       sortflag, elevorder, 2 )
   IF (sort_status EQ 1) THEN goto, ErrorExit
ENDIF

IF N_Elements(GR_Z_slantPath) NE 0 THEN BEGIN
   sort_status=get_and_sort_array_var( ncid1, 'GR_Z_slantPath', $
                                       GR_Z_slantPath, $
                                       sortflag, elevorder, 2 )
   IF (sort_status EQ 1) THEN goto, ErrorExit
ENDIF

IF N_Elements(GR_Z_Max_slantPath) NE 0 THEN BEGIN
   sort_status=get_and_sort_array_var( ncid1, 'GR_Z_Max_slantPath', $
                                       GR_Z_Max_slantPath, $
                                       sortflag, elevorder, 2 )
      IF (sort_status EQ 1) THEN goto, ErrorExit
ENDIF

IF N_Elements(GR_Z_StdDev_slantPath) NE 0 THEN BEGIN
   sort_status=get_and_sort_array_var( ncid1, 'GR_Z_StdDev_slantPath', $
                                       GR_Z_StdDev_slantPath, $
                                       sortflag, elevorder, 2 )
      IF (sort_status EQ 1) THEN goto, ErrorExit
ENDIF

IF N_Elements(GR_Z_VPR) NE 0 THEN BEGIN
   sort_status=get_and_sort_array_var( ncid1, 'GR_Z_VPR', GR_Z_VPR, $
                                       sortflag, elevorder, 2 )
   IF (sort_status EQ 1) THEN goto, ErrorExit
ENDIF

IF N_Elements(GR_Z_Max_VPR) NE 0 THEN BEGIN
   sort_status=get_and_sort_array_var( ncid1, 'GR_Z_Max_VPR', GR_Z_Max_VPR, $
                                       sortflag, elevorder, 2 )
      IF (sort_status EQ 1) THEN goto, ErrorExit
ENDIF

IF N_Elements(GR_Z_StdDev_VPR) NE 0 THEN BEGIN
   sort_status=get_and_sort_array_var( ncid1, 'GR_Z_StdDev_VPR', $
                                       GR_Z_StdDev_VPR, $
                                       sortflag, elevorder, 2 )
      IF (sort_status EQ 1) THEN goto, ErrorExit
ENDIF

IF ncversion GT 1.0 THEN BEGIN
   IF N_Elements(n_gr_rc_rejected) NE 0 THEN BEGIN
      sort_status=get_and_sort_array_var( ncid1, 'n_gr_rc_rejected', $
                                          n_gr_rc_rejected, $
                                          sortflag, elevorder, 2 )
      IF (sort_status EQ 1) THEN goto, ErrorExit
   ENDIF

   IF N_Elements(n_gr_rc_vpr_rejected) NE 0 THEN BEGIN
      sort_status=get_and_sort_array_var( ncid1, 'n_gr_rc_vpr_rejected', $
                                          n_gr_rc_vpr_rejected, $
                                          sortflag, elevorder, 2 )
      IF (sort_status EQ 1) THEN goto, ErrorExit
   ENDIF

   IF N_Elements(n_gr_rp_rejected) NE 0 THEN BEGIN
      sort_status=get_and_sort_array_var( ncid1, 'n_gr_rp_rejected', $
                                          n_gr_rp_rejected, $
                                          sortflag, elevorder, 2 )
      IF (sort_status EQ 1) THEN goto, ErrorExit
   ENDIF

   IF N_Elements(n_gr_rp_vpr_rejected) NE 0 THEN BEGIN
      sort_status=get_and_sort_array_var( ncid1, 'n_gr_rp_vpr_rejected', $
                                          n_gr_rp_vpr_rejected, $
                                          sortflag, elevorder, 2 )
      IF (sort_status EQ 1) THEN goto, ErrorExit
   ENDIF
ENDIF

IF N_Elements(n_gr_rr_rejected) NE 0 THEN BEGIN
   sort_status=get_and_sort_array_var( ncid1, 'n_gr_rr_rejected', $
                                       n_gr_rr_rejected, $
                                       sortflag, elevorder, 2 )
   IF (sort_status EQ 1) THEN goto, ErrorExit
ENDIF

IF N_Elements(n_gr_rr_vpr_rejected) NE 0 THEN BEGIN
   sort_status=get_and_sort_array_var( ncid1, 'n_gr_rr_vpr_rejected', $
                                       n_gr_rr_vpr_rejected, $
                                       sortflag, elevorder, 2 )
   IF (sort_status EQ 1) THEN goto, ErrorExit
ENDIF

IF ncversion GT 1.0 THEN BEGIN
   IF N_Elements(GR_RC_rainrate_slantPath) NE 0 THEN BEGIN
      sort_status=get_and_sort_array_var( ncid1, 'GR_RC_rainrate_slantPath',  $
                                          GR_RC_rainrate_slantPath, $
                                          sortflag, elevorder, 2 )
      IF (sort_status EQ 1) THEN goto, ErrorExit
   ENDIF

   IF N_Elements(GR_RC_rainrate_Max_slantPath) NE 0 THEN BEGIN
      sort_status=get_and_sort_array_var( ncid1, 'GR_RC_rainrate_Max_slantPath',  $
                                          GR_RC_rainrate_Max_slantPath, $
                                          sortflag, elevorder, 2 )
      IF (sort_status EQ 1) THEN goto, ErrorExit
   ENDIF

   IF N_Elements(GR_RC_rainrate_StdDev_slantPath) NE 0 THEN BEGIN
      sort_status=get_and_sort_array_var( ncid1, 'GR_RC_rainrate_StdDev_slantPath',  $
                                          GR_RC_rainrate_StdDev_slantPath, $
                                          sortflag, elevorder, 2 )
      IF (sort_status EQ 1) THEN goto, ErrorExit
   ENDIF

   IF N_Elements(GR_RC_rainrate_VPR) NE 0 THEN BEGIN
      sort_status=get_and_sort_array_var( ncid1, 'GR_RC_rainrate_VPR',  $
                                          GR_RC_rainrate_VPR, $
                                          sortflag, elevorder, 2 )
      IF (sort_status EQ 1) THEN goto, ErrorExit
   ENDIF

   IF N_Elements(GR_RC_rainrate_Max_VPR) NE 0 THEN BEGIN
      sort_status=get_and_sort_array_var( ncid1, 'GR_RC_rainrate_Max_VPR',  $
                                          GR_RC_rainrate_Max_VPR, $
                                          sortflag, elevorder, 2 )
      IF (sort_status EQ 1) THEN goto, ErrorExit
   ENDIF

   IF N_Elements(GR_RC_rainrate_StdDev_VPR) NE 0 THEN BEGIN
      sort_status=get_and_sort_array_var( ncid1, 'GR_RC_rainrate_StdDev_VPR',  $
                                          GR_RC_rainrate_StdDev_VPR, $
                                          sortflag, elevorder, 2 )
      IF (sort_status EQ 1) THEN goto, ErrorExit
   ENDIF

   IF N_Elements(GR_RP_rainrate_slantPath) NE 0 THEN BEGIN
      sort_status=get_and_sort_array_var( ncid1, 'GR_RP_rainrate_slantPath',  $
                                          GR_RP_rainrate_slantPath, $
                                          sortflag, elevorder, 2 )
      IF (sort_status EQ 1) THEN goto, ErrorExit
   ENDIF

   IF N_Elements(GR_RP_rainrate_Max_slantPath) NE 0 THEN BEGIN
      sort_status=get_and_sort_array_var( ncid1, 'GR_RP_rainrate_Max_slantPath',  $
                                          GR_RP_rainrate_Max_slantPath, $
                                          sortflag, elevorder, 2 )
      IF (sort_status EQ 1) THEN goto, ErrorExit
   ENDIF

   IF N_Elements(GR_RP_rainrate_StdDev_slantPath) NE 0 THEN BEGIN
      sort_status=get_and_sort_array_var( ncid1, 'GR_RP_rainrate_StdDev_slantPath', $
                                          GR_RP_rainrate_StdDev_slantPath, $
                                          sortflag, elevorder, 2 )
      IF (sort_status EQ 1) THEN goto, ErrorExit
   ENDIF

   IF N_Elements(GR_RP_rainrate_VPR) NE 0 THEN BEGIN
      sort_status=get_and_sort_array_var( ncid1, 'GR_RP_rainrate_VPR', $
                                          GR_RP_rainrate_VPR, $
                                          sortflag, elevorder, 2 )
      IF (sort_status EQ 1) THEN goto, ErrorExit
   ENDIF

   IF N_Elements(GR_RP_rainrate_Max_VPR) NE 0 THEN BEGIN
      sort_status=get_and_sort_array_var( ncid1, 'GR_RP_rainrate_Max_VPR', $
                                          GR_RP_rainrate_Max_VPR, $
                                          sortflag, elevorder, 2 )
      IF (sort_status EQ 1) THEN goto, ErrorExit
   ENDIF

   IF N_Elements(GR_RP_rainrate_StdDev_VPR) NE 0 THEN BEGIN
      sort_status=get_and_sort_array_var( ncid1, 'GR_RP_rainrate_StdDev_VPR', $
                                          GR_RP_rainrate_StdDev_VPR, $
                                          sortflag, elevorder, 2 )
      IF (sort_status EQ 1) THEN goto, ErrorExit
   ENDIF

   IF N_Elements(GR_RR_rainrate_slantPath) NE 0 THEN BEGIN
      sort_status=get_and_sort_array_var( ncid1, 'GR_RR_rainrate_slantPath', $
                                          GR_RR_rainrate_slantPath, $
                                          sortflag, elevorder, 2 )
      IF (sort_status EQ 1) THEN goto, ErrorExit
   ENDIF

   IF N_Elements(GR_RR_rainrate_Max_slantPath) NE 0 THEN BEGIN
      sort_status=get_and_sort_array_var( ncid1, 'GR_RR_rainrate_Max_slantPath', $
                                          GR_RR_rainrate_Max_slantPath, $
                                          sortflag, elevorder, 2 )
      IF (sort_status EQ 1) THEN goto, ErrorExit
   ENDIF

   IF N_Elements(GR_RR_rainrate_StdDev_slantPath) NE 0 THEN BEGIN
      sort_status=get_and_sort_array_var( ncid1, $
                                         'GR_RR_rainrate_StdDev_slantPath', $
                                          GR_RR_rainrate_StdDev_slantPath, $
                                          sortflag, elevorder, 2 )
      IF (sort_status EQ 1) THEN goto, ErrorExit
   ENDIF

   IF N_Elements(GR_RR_rainrate_VPR) NE 0 THEN BEGIN
      sort_status=get_and_sort_array_var( ncid1, 'GR_RR_rainrate_VPR', $
                                          GR_RR_rainrate_VPR, $
                                          sortflag, elevorder, 2 )
      IF (sort_status EQ 1) THEN goto, ErrorExit
   ENDIF

   IF N_Elements(GR_RR_rainrate_Max_VPR) NE 0 THEN BEGIN
      sort_status=get_and_sort_array_var( ncid1, 'GR_RR_rainrate_Max_VPR', $
                                          GR_RR_rainrate_Max_VPR, $
                                          sortflag, elevorder, 2 )
      IF (sort_status EQ 1) THEN goto, ErrorExit
   ENDIF

   IF N_Elements(GR_RR_rainrate_StdDev_VPR) NE 0 THEN BEGIN
      sort_status=get_and_sort_array_var( ncid1, 'GR_RR_rainrate_StdDev_VPR', $
                                          GR_RR_rainrate_StdDev_VPR, $
                                          sortflag, elevorder, 2 )
      IF (sort_status EQ 1) THEN goto, ErrorExit
   ENDIF
ENDIF ELSE BEGIN
  ; version 1.0 file variables do not have the extra "RR_" in their netCDF IDs
   IF N_Elements(GR_RR_rainrate_slantPath) NE 0 THEN BEGIN
      sort_status=get_and_sort_array_var( ncid1, 'GR_rainrate_slantPath', $
                                          GR_RR_rainrate_slantPath, $
                                          sortflag, elevorder, 2 )
      IF (sort_status EQ 1) THEN goto, ErrorExit
   ENDIF

   IF N_Elements(GR_RR_rainrate_Max_slantPath) NE 0 THEN BEGIN
      sort_status=get_and_sort_array_var( ncid1, 'GR_rainrate_Max_slantPath', $
                                          GR_RR_rainrate_Max_slantPath, $
                                          sortflag, elevorder, 2 )
      IF (sort_status EQ 1) THEN goto, ErrorExit
   ENDIF

   IF N_Elements(GR_RR_rainrate_StdDev_slantPath) NE 0 THEN BEGIN
      sort_status=get_and_sort_array_var( ncid1, $
                                         'GR_rainrate_StdDev_slantPath', $
                                          GR_RR_rainrate_StdDev_slantPath, $
                                          sortflag, elevorder, 2 )
      IF (sort_status EQ 1) THEN goto, ErrorExit
   ENDIF

   IF N_Elements(GR_RR_rainrate_VPR) NE 0 THEN BEGIN
      sort_status=get_and_sort_array_var( ncid1, 'GR_rainrate_VPR', $
                                          GR_RR_rainrate_VPR, $
                                          sortflag, elevorder, 2 )
      IF (sort_status EQ 1) THEN goto, ErrorExit
   ENDIF

   IF N_Elements(GR_RR_rainrate_Max_VPR) NE 0 THEN BEGIN
      sort_status=get_and_sort_array_var( ncid1, 'GR_rainrate_Max_VPR', $
                                          GR_RR_rainrate_Max_VPR, $
                                          sortflag, elevorder, 2 )
      IF (sort_status EQ 1) THEN goto, ErrorExit
   ENDIF

   IF N_Elements(GR_RR_rainrate_StdDev_VPR) NE 0 THEN BEGIN
      sort_status=get_and_sort_array_var( ncid1, 'GR_rainrate_StdDev_VPR', $
                                          GR_RR_rainrate_StdDev_VPR, $
                                          sortflag, elevorder, 2 )
      IF (sort_status EQ 1) THEN goto, ErrorExit
   ENDIF
ENDELSE

IF N_Elements(n_gr_zdr_rejected) NE 0 THEN BEGIN
   sort_status=get_and_sort_array_var( ncid1, 'n_gr_zdr_rejected', n_gr_zdr_rejected, $
                                       sortflag, elevorder, 2 )
   IF (sort_status EQ 1) THEN goto, ErrorExit
ENDIF

IF N_Elements(n_gr_zdr_vpr_rejected) NE 0 THEN BEGIN
   sort_status=get_and_sort_array_var( ncid1, 'n_gr_zdr_vpr_rejected', n_gr_zdr_vpr_rejected, $
                                       sortflag, elevorder, 2 )
   IF (sort_status EQ 1) THEN goto, ErrorExit
ENDIF

IF N_Elements(GR_Zdr_slantPath) NE 0 THEN BEGIN
   sort_status=get_and_sort_array_var( ncid1, 'GR_Zdr_slantPath', GR_Zdr_slantPath, $
                                       sortflag, elevorder, 2 )
   IF (sort_status EQ 1) THEN goto, ErrorExit
ENDIF

IF N_Elements(GR_Zdr_Max_slantPath) NE 0 THEN BEGIN
   sort_status=get_and_sort_array_var( ncid1, 'GR_Zdr_Max_slantPath', GR_Zdr_Max_slantPath, $
                                       sortflag, elevorder, 2 )
   IF (sort_status EQ 1) THEN goto, ErrorExit
ENDIF

IF N_Elements(GR_Zdr_StdDev_slantPath) NE 0 THEN BEGIN
   sort_status=get_and_sort_array_var( ncid1, 'GR_Zdr_StdDev_slantPath', GR_Zdr_StdDev_slantPath, $
                                       sortflag, elevorder, 2 )
   IF (sort_status EQ 1) THEN goto, ErrorExit
ENDIF

IF N_Elements(GR_Zdr_VPR) NE 0 THEN BEGIN
   sort_status=get_and_sort_array_var( ncid1, 'GR_Zdr_VPR', GR_Zdr_VPR, $
                                       sortflag, elevorder, 2 )
   IF (sort_status EQ 1) THEN goto, ErrorExit
ENDIF

IF N_Elements(GR_Zdr_Max_VPR) NE 0 THEN BEGIN
   sort_status=get_and_sort_array_var( ncid1, 'GR_Zdr_Max_VPR', GR_Zdr_Max_VPR, $
                                       sortflag, elevorder, 2 )
   IF (sort_status EQ 1) THEN goto, ErrorExit
ENDIF

IF N_Elements(GR_Zdr_StdDev_VPR) NE 0 THEN BEGIN
   sort_status=get_and_sort_array_var( ncid1, 'GR_Zdr_StdDev_VPR', GR_Zdr_StdDev_VPR, $
                                       sortflag, elevorder, 2 )
   IF (sort_status EQ 1) THEN goto, ErrorExit
ENDIF

IF N_Elements(n_gr_kdp_rejected) NE 0 THEN BEGIN
   sort_status=get_and_sort_array_var( ncid1, 'n_gr_kdp_rejected', n_gr_kdp_rejected, $
                                       sortflag, elevorder, 2 )
   IF (sort_status EQ 1) THEN goto, ErrorExit
ENDIF

IF N_Elements(n_gr_kdp_vpr_rejected) NE 0 THEN BEGIN
   sort_status=get_and_sort_array_var( ncid1, 'n_gr_kdp_vpr_rejected', n_gr_kdp_vpr_rejected, $
                                       sortflag, elevorder, 2 )
   IF (sort_status EQ 1) THEN goto, ErrorExit
ENDIF

IF N_Elements(GR_Kdp_slantPath) NE 0 THEN BEGIN
   sort_status=get_and_sort_array_var( ncid1, 'GR_Kdp_slantPath', GR_Kdp_slantPath, $
                                       sortflag, elevorder, 2 )
   IF (sort_status EQ 1) THEN goto, ErrorExit
ENDIF

IF N_Elements(GR_Kdp_Max_slantPath) NE 0 THEN BEGIN
   sort_status=get_and_sort_array_var( ncid1, 'GR_Kdp_Max_slantPath', GR_Kdp_Max_slantPath, $
                                       sortflag, elevorder, 2 )
   IF (sort_status EQ 1) THEN goto, ErrorExit
ENDIF

IF N_Elements(GR_Kdp_StdDev_slantPath) NE 0 THEN BEGIN
   sort_status=get_and_sort_array_var( ncid1, 'GR_Kdp_StdDev_slantPath', GR_Kdp_StdDev_slantPath, $
                                       sortflag, elevorder, 2 )
   IF (sort_status EQ 1) THEN goto, ErrorExit
ENDIF

IF N_Elements(GR_Kdp_VPR) NE 0 THEN BEGIN
   sort_status=get_and_sort_array_var( ncid1, 'GR_Kdp_VPR', GR_Kdp_VPR, $
                                       sortflag, elevorder, 2 )
   IF (sort_status EQ 1) THEN goto, ErrorExit
ENDIF

IF N_Elements(GR_Kdp_Max_VPR) NE 0 THEN BEGIN
   sort_status=get_and_sort_array_var( ncid1, 'GR_Kdp_Max_VPR', GR_Kdp_Max_VPR, $
                                       sortflag, elevorder, 2 )
   IF (sort_status EQ 1) THEN goto, ErrorExit
ENDIF

IF N_Elements(GR_Kdp_StdDev_VPR) NE 0 THEN BEGIN
   sort_status=get_and_sort_array_var( ncid1, 'GR_Kdp_StdDev_VPR', GR_Kdp_StdDev_VPR, $
                                       sortflag, elevorder, 2 )
   IF (sort_status EQ 1) THEN goto, ErrorExit
ENDIF

IF N_Elements(n_gr_rhohv_rejected) NE 0 THEN BEGIN
   sort_status=get_and_sort_array_var( ncid1, 'n_gr_rhohv_rejected', n_gr_rhohv_rejected, $
                                       sortflag, elevorder, 2 )
   IF (sort_status EQ 1) THEN goto, ErrorExit
ENDIF

IF N_Elements(n_gr_rhohv_vpr_rejected) NE 0 THEN BEGIN
   sort_status=get_and_sort_array_var( ncid1, 'n_gr_rhohv_vpr_rejected', n_gr_rhohv_vpr_rejected, $
                                       sortflag, elevorder, 2 )
   IF (sort_status EQ 1) THEN goto, ErrorExit
ENDIF

IF N_Elements(GR_RHOhv_slantPath) NE 0 THEN BEGIN
   sort_status=get_and_sort_array_var( ncid1, 'GR_RHOhv_slantPath', GR_RHOhv_slantPath, $
                                       sortflag, elevorder, 2 )
   IF (sort_status EQ 1) THEN goto, ErrorExit
ENDIF

IF N_Elements(GR_RHOhv_Max_slantPath) NE 0 THEN BEGIN
   sort_status=get_and_sort_array_var( ncid1, 'GR_RHOhv_Max_slantPath', GR_RHOhv_Max_slantPath, $
                                       sortflag, elevorder, 2 )
   IF (sort_status EQ 1) THEN goto, ErrorExit
ENDIF

IF N_Elements(GR_RHOhv_StdDev_slantPath) NE 0 THEN BEGIN
   sort_status=get_and_sort_array_var( ncid1, 'GR_RHOhv_StdDev_slantPath', GR_RHOhv_StdDev_slantPath, $
                                       sortflag, elevorder, 2 )
   IF (sort_status EQ 1) THEN goto, ErrorExit
ENDIF

IF N_Elements(GR_RHOhv_VPR) NE 0 THEN BEGIN
   sort_status=get_and_sort_array_var( ncid1, 'GR_RHOhv_VPR', GR_RHOhv_VPR, $
                                       sortflag, elevorder, 2 )
   IF (sort_status EQ 1) THEN goto, ErrorExit
ENDIF

IF N_Elements(GR_RHOhv_Max_VPR) NE 0 THEN BEGIN
   sort_status=get_and_sort_array_var( ncid1, 'GR_RHOhv_Max_VPR', GR_RHOhv_Max_VPR, $
                                       sortflag, elevorder, 2 )
   IF (sort_status EQ 1) THEN goto, ErrorExit
ENDIF

IF N_Elements(GR_RHOhv_StdDev_VPR) NE 0 THEN BEGIN
   sort_status=get_and_sort_array_var( ncid1, 'GR_RHOhv_StdDev_VPR', GR_RHOhv_StdDev_VPR, $
                                       sortflag, elevorder, 2 )
   IF (sort_status EQ 1) THEN goto, ErrorExit
ENDIF

IF N_Elements(n_gr_hid_rejected) NE 0 THEN BEGIN
   sort_status=get_and_sort_array_var( ncid1, 'n_gr_hid_rejected', n_gr_hid_rejected, $
                                       sortflag, elevorder, 2 )
   IF (sort_status EQ 1) THEN goto, ErrorExit
ENDIF

IF N_Elements(n_gr_hid_vpr_rejected) NE 0 THEN BEGIN
   sort_status=get_and_sort_array_var( ncid1, 'n_gr_hid_vpr_rejected', n_gr_hid_vpr_rejected, $
                                       sortflag, elevorder, 2 )
   IF (sort_status EQ 1) THEN goto, ErrorExit
ENDIF

IF N_Elements(GR_HID_slantPath) NE 0 THEN BEGIN
   sort_status=get_and_sort_array_var( ncid1, 'GR_HID_slantPath', GR_HID_slantPath, $
                                       sortflag, elevorder, 3 )
   IF (sort_status EQ 1) THEN goto, ErrorExit
ENDIF

IF N_Elements(GR_HID_VPR) NE 0 THEN BEGIN
   sort_status=get_and_sort_array_var( ncid1, 'GR_HID_VPR', GR_HID_VPR, $
                                       sortflag, elevorder, 3 )
   IF (sort_status EQ 1) THEN goto, ErrorExit
ENDIF

IF N_Elements(n_gr_dzero_rejected) NE 0 THEN BEGIN
   sort_status=get_and_sort_array_var( ncid1, 'n_gr_dzero_rejected', n_gr_dzero_rejected, $
                                       sortflag, elevorder, 2 )
   IF (sort_status EQ 1) THEN goto, ErrorExit
ENDIF

IF N_Elements(n_gr_dzero_vpr_rejected) NE 0 THEN BEGIN
   sort_status=get_and_sort_array_var( ncid1, 'n_gr_dzero_vpr_rejected', n_gr_dzero_vpr_rejected, $
                                       sortflag, elevorder, 2 )
   IF (sort_status EQ 1) THEN goto, ErrorExit
ENDIF

IF N_Elements(GR_Dzero_slantPath) NE 0 THEN BEGIN
   sort_status=get_and_sort_array_var( ncid1, 'GR_Dzero_slantPath', GR_Dzero_slantPath, $
                                       sortflag, elevorder, 2 )
   IF (sort_status EQ 1) THEN goto, ErrorExit
ENDIF

IF N_Elements(GR_Dzero_Max_slantPath) NE 0 THEN BEGIN
   sort_status=get_and_sort_array_var( ncid1, 'GR_Dzero_Max_slantPath', GR_Dzero_Max_slantPath, $
                                       sortflag, elevorder, 2 )
   IF (sort_status EQ 1) THEN goto, ErrorExit
ENDIF

IF N_Elements(GR_Dzero_StdDev_slantPath) NE 0 THEN BEGIN
   sort_status=get_and_sort_array_var( ncid1, 'GR_Dzero_StdDev_slantPath', GR_Dzero_StdDev_slantPath, $
                                       sortflag, elevorder, 2 )
   IF (sort_status EQ 1) THEN goto, ErrorExit
ENDIF

IF N_Elements(GR_Dzero_VPR) NE 0 THEN BEGIN
   sort_status=get_and_sort_array_var( ncid1, 'GR_Dzero_VPR', GR_Dzero_VPR, $
                                       sortflag, elevorder, 2 )
   IF (sort_status EQ 1) THEN goto, ErrorExit
ENDIF

IF N_Elements(GR_Dzero_Max_VPR) NE 0 THEN BEGIN
   sort_status=get_and_sort_array_var( ncid1, 'GR_Dzero_Max_VPR', GR_Dzero_Max_VPR, $
                                       sortflag, elevorder, 2 )
   IF (sort_status EQ 1) THEN goto, ErrorExit
ENDIF

IF N_Elements(GR_Dzero_StdDev_VPR) NE 0 THEN BEGIN
   sort_status=get_and_sort_array_var( ncid1, 'GR_Dzero_StdDev_VPR', GR_Dzero_StdDev_VPR, $
                                       sortflag, elevorder, 2 )
   IF (sort_status EQ 1) THEN goto, ErrorExit
ENDIF

IF N_Elements(n_gr_nw_rejected) NE 0 THEN BEGIN
   sort_status=get_and_sort_array_var( ncid1, 'n_gr_nw_rejected', n_gr_nw_rejected, $
                                       sortflag, elevorder, 2 )
   IF (sort_status EQ 1) THEN goto, ErrorExit
ENDIF

IF N_Elements(n_gr_nw_vpr_rejected) NE 0 THEN BEGIN
   sort_status=get_and_sort_array_var( ncid1, 'n_gr_nw_vpr_rejected', n_gr_nw_vpr_rejected, $
                                       sortflag, elevorder, 2 )
   IF (sort_status EQ 1) THEN goto, ErrorExit
ENDIF

IF N_Elements(GR_Nw_slantPath) NE 0 THEN BEGIN
   sort_status=get_and_sort_array_var( ncid1, 'GR_Nw_slantPath', GR_Nw_slantPath, $
                                       sortflag, elevorder, 2 )
   IF (sort_status EQ 1) THEN goto, ErrorExit
ENDIF

IF N_Elements(GR_Nw_Max_slantPath) NE 0 THEN BEGIN
   sort_status=get_and_sort_array_var( ncid1, 'GR_Nw_Max_slantPath', GR_Nw_Max_slantPath, $
                                       sortflag, elevorder, 2 )
   IF (sort_status EQ 1) THEN goto, ErrorExit
ENDIF

IF N_Elements(GR_Nw_StdDev_slantPath) NE 0 THEN BEGIN
   sort_status=get_and_sort_array_var( ncid1, 'GR_Nw_StdDev_slantPath', GR_Nw_StdDev_slantPath, $
                                       sortflag, elevorder, 2 )
   IF (sort_status EQ 1) THEN goto, ErrorExit
ENDIF

IF N_Elements(GR_Nw_VPR) NE 0 THEN BEGIN
   sort_status=get_and_sort_array_var( ncid1, 'GR_Nw_VPR', GR_Nw_VPR, $
                                       sortflag, elevorder, 2 )
   IF (sort_status EQ 1) THEN goto, ErrorExit
ENDIF

IF N_Elements(GR_Nw_Max_VPR) NE 0 THEN BEGIN
   sort_status=get_and_sort_array_var( ncid1, 'GR_Nw_Max_VPR', GR_Nw_Max_VPR, $
                                       sortflag, elevorder, 2 )
   IF (sort_status EQ 1) THEN goto, ErrorExit
ENDIF

IF N_Elements(GR_Nw_StdDev_VPR) NE 0 THEN BEGIN
   sort_status=get_and_sort_array_var( ncid1, 'GR_Nw_StdDev_VPR', GR_Nw_StdDev_VPR, $
                                       sortflag, elevorder, 2 )
   IF (sort_status EQ 1) THEN goto, ErrorExit
ENDIF

IF ncversion GT 1.1 THEN BEGIN
   IF N_Elements(GR_blockage_slantPath) NE 0 THEN BEGIN
      sort_status=get_and_sort_array_var( ncid1, 'GR_blockage_slantPath',  $
                                          GR_blockage_slantPath, $
                                          sortflag, elevorder, 2 )
      IF (sort_status EQ 1) THEN goto, ErrorExit
   ENDIF

   IF N_Elements(GR_blockage_VPR) NE 0 THEN BEGIN
      sort_status=get_and_sort_array_var( ncid1, 'GR_blockage_VPR',  $
                                          GR_blockage_VPR, $
                                          sortflag, elevorder, 2 )
      IF (sort_status EQ 1) THEN goto, ErrorExit
   ENDIF
ENDIF

IF N_Elements(topHeight) NE 0 THEN BEGIN
   sort_status=get_and_sort_array_var( ncid1, 'topHeight', topHeight, $
                                       sortflag, elevorder, 2 )
   IF (sort_status EQ 1) THEN goto, ErrorExit
ENDIF

IF N_Elements(bottomHeight) NE 0 THEN BEGIN
   sort_status=get_and_sort_array_var( ncid1, 'bottomHeight', bottomHeight, $
                                       sortflag, elevorder, 2 )
   IF (sort_status EQ 1) THEN goto, ErrorExit
ENDIF

IF N_Elements(topHeight_vpr) NE 0 THEN BEGIN
   sort_status=get_and_sort_array_var( ncid1, 'topHeight_vpr', topHeight_vpr, $
                                       sortflag, elevorder, 2 )
   IF (sort_status EQ 1) THEN goto, ErrorExit
ENDIF

IF N_Elements(bottomHeight_vpr) NE 0 THEN BEGIN
   sort_status=get_and_sort_array_var( ncid1, 'bottomHeight_vpr', bottomHeight_vpr, $
                                       sortflag, elevorder, 2 )
   IF (sort_status EQ 1) THEN goto, ErrorExit
ENDIF

IF N_Elements(xCorners) NE 0 THEN BEGIN
   sort_status=get_and_sort_array_var( ncid1, 'xCorners', xCorners, $
                                       sortflag, elevorder, 3 )
   IF (sort_status EQ 1) THEN goto, ErrorExit
ENDIF

IF N_Elements(yCorners) NE 0 THEN BEGIN
   sort_status=get_and_sort_array_var( ncid1, 'yCorners', yCorners, $
                                       sortflag, elevorder, 3 )
   IF (sort_status EQ 1) THEN goto, ErrorExit
ENDIF

IF N_Elements(latitude) NE 0 THEN BEGIN
   sort_status=get_and_sort_array_var( ncid1, 'latitude', latitude, $
                                       sortflag, elevorder, 2 )
   IF (sort_status EQ 1) THEN goto, ErrorExit
ENDIF

IF N_Elements(longitude) NE 0 THEN BEGIN
   sort_status=get_and_sort_array_var( ncid1, 'longitude', longitude, $
                                       sortflag, elevorder, 2 )
   IF (sort_status EQ 1) THEN goto, ErrorExit
ENDIF

IF N_Elements(XMIlatitude) NE 0 THEN $
     NCDF_VARGET, ncid1, 'XMIlatitude', XMIlatitude

IF N_Elements(XMIlongitude) NE 0 THEN $
     NCDF_VARGET, ncid1, 'XMIlongitude', XMIlongitude

IF N_Elements(surfacePrecipitation) NE 0 THEN $
     NCDF_VARGET, ncid1, 'surfacePrecipitation', surfacePrecipitation

IF N_Elements(surfaceTypeIndex) NE 0 THEN $
     NCDF_VARGET, ncid1, 'surfaceTypeIndex', surfaceTypeIndex

IF N_Elements(pixelStatus) NE 0 THEN $
     NCDF_VARGET, ncid1, 'pixelStatus', pixelStatus

IF N_Elements(PoP) NE 0 THEN $
     NCDF_VARGET, ncid1, 'PoP', PoP

IF ncversion GE 1.2 THEN BEGIN
   IF N_Elements(Tc) NE 0 THEN $
        NCDF_VARGET, ncid1, 'Tc', Tc
   IF N_Elements(Quality) NE 0 THEN $
        NCDF_VARGET, ncid1, 'Quality', Quality
   IF N_Elements(Tc_channel_names) NE 0 THEN BEGIN
     NCDF_VARGET, ncid1, 'Tc_channel_names', Tc_channel_names_byte
     Tc_channel_names = STRING(Tc_channel_names_byte)
   ENDIF
ENDIF

IF N_Elements(rayIndex) NE 0 THEN $
     NCDF_VARGET, ncid1, 'rayIndex', rayIndex

goto, normalExit

ErrorExit:
status = sort_status

ErrorExit2:
normalExit:
NCDF_CLOSE, ncid1

RETURN, status
END
