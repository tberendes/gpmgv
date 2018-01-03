;===============================================================================
;+
; Copyright © 2014, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; test_read_gprof_geo_match_netcdf.pro      Morris/SAIC/GPM_GV      March 2014
;
; DESCRIPTION
; -----------
; Test driver for function read_gprof_geo_match_netcdf.pro
;
; HISTORY
; -------
; 11/06/14 by Bob Morris, GPM GV (SAIC)
;  - Added processing of GR RC and RP rainrate fields for version 1.1 file.
; 11/13/15 by Bob Morris, GPM GV (SAIC)
;  - Added processing of GR_blockage variables and their presence flags for
;    version 1.11 file.
; 07/07/16 by Bob Morris, GPM GV (SAIC)
;  - Added processing of Tc, Quality, and Tc_channel_names variables for file
;    version 1.2.
;
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;===============================================================================

pro test_read_gprof_geo_match_netcdf, mygeomatchfile

;mygeomatchfile='/tmp/geo_match3/GRtoGMI.KMKX.140311.190.6.1_0.nc.gz'
   if n_elements(mygeomatchfile) eq 0 then begin
      filters = ['GRtoGPROF*']
      mygeomatchfile=dialog_pickfile(FILTER=filters, $
          TITLE='Select GRtoGPROF file to read', $
          PATH='/data/gpmgv/netcdf/geo_match')
      IF (mygeomatchfile EQ '') THEN GOTO, userQuit
   endif

cpstatus = uncomp_file( mygeomatchfile, myfile )
if(cpstatus eq 'OK') then begin
  status = 1   ; init to FAILED
 ; create <<initialized>> structures to hold the metadata variables
  mygeometa=GET_GEO_MATCH_NC_STRUCT('matchup')      ;{ geo_match_meta }
  mysweeps=GET_GEO_MATCH_NC_STRUCT('sweeps')        ;{ gv_sweep_meta }
  mysite=GET_GEO_MATCH_NC_STRUCT('site')            ;{ gv_site_meta }
  myflags=GET_GEO_MATCH_NC_STRUCT('fields_gprof')   ;{ gprof_gv_field_flags }
  myfiles=GET_GEO_MATCH_NC_STRUCT( 'files' )

  status = read_gprof_geo_match_netcdf( myfile, matchupmeta=mygeometa, $
     sweepsmeta=mysweeps, sitemeta=mysite, fieldflags=myflags, filesmeta=myfiles )

  IF status NE 0 THEN BEGIN
     command3 = "rm -v " + myfile
     spawn, command3
     message, "Error reading file "+myfile
  ENDIF

help, mygeometa, /struct
help, myflags, /struct
stop
 ; create data field arrays of correct dimensions and read data fields
  nfp = mygeometa.num_footprints
  nswp = mygeometa.num_sweeps

  latitude = FLTARR(nfp,nswp)
  longitude = FLTARR(nfp,nswp)
  xCorners = FLTARR(4,nfp,nswp)
  yCorners = FLTARR(4,nfp,nswp)
  topHeight = FLTARR(nfp,nswp)
  bottomHeight = FLTARR(nfp,nswp)
  topHeight_vpr = FLTARR(nfp,nswp)
  bottomHeight_vpr = FLTARR(nfp,nswp)
  GR_Z_slantPath = FLTARR(nfp,nswp)
  GR_Z_StdDev_slantPath = FLTARR(nfp,nswp)
  GR_Z_Max_slantPath = FLTARR(nfp,nswp)
  GR_RC_rainrate_slantPath = FLTARR(nfp,nswp)
  GR_RC_rainrate_StdDev_slantPath = FLTARR(nfp,nswp)
  GR_RC_rainrate_Max_slantPath = FLTARR(nfp,nswp)
  GR_RP_rainrate_slantPath = FLTARR(nfp,nswp)
  GR_RP_rainrate_StdDev_slantPath = FLTARR(nfp,nswp)
  GR_RP_rainrate_Max_slantPath = FLTARR(nfp,nswp)
  GR_RR_rainrate_slantPath = FLTARR(nfp,nswp)
  GR_RR_rainrate_StdDev_slantPath = FLTARR(nfp,nswp)
  GR_RR_rainrate_Max_slantPath = FLTARR(nfp,nswp)
  GR_Zdr_slantPath = FLTARR(nfp,nswp)
  GR_Zdr_StdDev_slantPath = FLTARR(nfp,nswp)
  GR_Zdr_Max_slantPath = FLTARR(nfp,nswp)
  GR_Kdp_slantPath = FLTARR(nfp,nswp)
  GR_Kdp_StdDev_slantPath = FLTARR(nfp,nswp)
  GR_Kdp_Max_slantPath = FLTARR(nfp,nswp)
  GR_RHOhv_slantPath = FLTARR(nfp,nswp)
  GR_RHOhv_StdDev_slantPath = FLTARR(nfp,nswp)
  GR_RHOhv_Max_slantPath = FLTARR(nfp,nswp)
  GR_HID_slantPath = INTARR(15,nfp,nswp)
  GR_Dzero_slantPath = FLTARR(nfp,nswp)
  GR_Dzero_StdDev_slantPath = FLTARR(nfp,nswp)
  GR_Dzero_Max_slantPath = FLTARR(nfp,nswp)
  GR_Nw_slantPath = FLTARR(nfp,nswp)
  GR_Nw_StdDev_slantPath = FLTARR(nfp,nswp)
  GR_Nw_Max_slantPath = FLTARR(nfp,nswp)
  GR_Dzero_slantPath = FLTARR(nfp,nswp)
  GR_blockage_slantPath = FLTARR(nfp,nswp)
  n_gr_expected = -1
  n_gr_z_rejected = -1
  n_gr_rc_rejected = -1
  n_gr_rp_rejected = -1
  n_gr_rr_rejected = -1
  n_gr_zdr_rejected = -1
  n_gr_kdp_rejected = -1
  n_gr_rhohv_rejected = -1
  n_gr_hid_rejected = -1
  n_gr_dzero_rejected = -1
  n_gr_nw_rejected = -1
  GR_Z_VPR = FLTARR(nfp,nswp)
  GR_Z_StdDev_VPR = FLTARR(nfp,nswp)
  GR_Z_Max_VPR = FLTARR(nfp,nswp)
  GR_RC_rainrate_VPR = FLTARR(nfp,nswp)
  GR_RC_rainrate_StdDev_VPR = FLTARR(nfp,nswp)
  GR_RC_rainrate_Max_VPR = FLTARR(nfp,nswp)
  GR_RP_rainrate_VPR = FLTARR(nfp,nswp)
  GR_RP_rainrate_StdDev_VPR = FLTARR(nfp,nswp)
  GR_RP_rainrate_Max_VPR = FLTARR(nfp,nswp)
  GR_RR_rainrate_VPR = FLTARR(nfp,nswp)
  GR_RR_rainrate_StdDev_VPR = FLTARR(nfp,nswp)
  GR_RR_rainrate_Max_VPR = FLTARR(nfp,nswp)
  GR_Zdr_VPR = FLTARR(nfp,nswp)
  GR_Zdr_StdDev_VPR = FLTARR(nfp,nswp)
  GR_Zdr_Max_VPR = FLTARR(nfp,nswp)
  GR_Kdp_VPR = FLTARR(nfp,nswp)
  GR_Kdp_StdDev_VPR = FLTARR(nfp,nswp)
  GR_Kdp_Max_VPR = FLTARR(nfp,nswp)
  GR_RHOhv_VPR = FLTARR(nfp,nswp)
  GR_RHOhv_StdDev_VPR = FLTARR(nfp,nswp)
  GR_RHOhv_Max_VPR = FLTARR(nfp,nswp)
  GR_HID_VPR = INTARR(15,nfp,nswp)
  GR_Dzero_VPR = FLTARR(nfp,nswp)
  GR_Dzero_StdDev_VPR = FLTARR(nfp,nswp)
  GR_Dzero_Max_VPR = FLTARR(nfp,nswp)
  GR_Nw_VPR = FLTARR(nfp,nswp)
  GR_Nw_StdDev_VPR = FLTARR(nfp,nswp)
  GR_Nw_Max_VPR = FLTARR(nfp,nswp)
  GR_blockage_VPR = FLTARR(nfp,nswp)
  n_gr_vpr_expected = -1
  n_gr_z_vpr_rejected = -1
  n_gr_rc_vpr_rejected = -1
  n_gr_rp_vpr_rejected = -1
  n_gr_rr_vpr_rejected = -1
  n_gr_zdr_vpr_rejected = -1
  n_gr_kdp_vpr_rejected = -1
  n_gr_rhohv_vpr_rejected = -1
  n_gr_hid_vpr_rejected = -1
  n_gr_dzero_vpr_rejected = -1
  n_gr_nw_vpr_rejected = -1
  XMIlatitude = FLTARR(nfp)
  XMIlongitude = FLTARR(nfp)
  surfaceTypeIndex = INTARR(nfp)
  surfacePrecipitation = FLTARR(nfp)
  pixelStatus = INTARR(nfp)
  PoP = FLTARR(nfp)
  rayIndex = LONARR(nfp)
  IF mygeometa.nc_file_version GE 1.2 THEN BEGIN
     Tc = FLTARR(nfp)          ; ignoring n_channels dimension
     Quality = INTARR(nfp)     ; ignoring n_channels dimension
     Tc_channel_names = 'No_Tbb_data'  ; same as no-data situation
HELP, tc, quality, tc_names
  ENDIF

  status = read_gprof_geo_match_netcdf( myfile, $

   ; threshold/data completeness parameters for vert/horiz averaged values
   ; along XMI slant path (sp) and local vertical (vpr):
    grexpect_sp=n_gr_expected, z_reject_sp=n_gr_z_rejected,                 $
    rc_reject_vpr=n_gr_rc_vpr_rejected, rp_reject_vpr=n_gr_rp_vpr_rejected, $
    rr_reject_sp=n_gr_rr_rejected, zdr_reject_sp=n_gr_zdr_rejected,         $
    kdp_reject_sp=n_gr_kdp_rejected, rhohv_reject_sp=n_gr_rhohv_rejected,   $
    hid_reject_sp=n_gr_hid_rejected, dzero_reject_sp=n_gr_dzero_rejected,   $
    nw_reject_sp=n_gr_nw_rejected,                                          $
    grexpect_vpr=n_gr_vpr_expected, z_reject_vpr=n_gr_z_vpr_rejected,               $

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
    TC_CHANNEL_NAMES = Tc_channel_names )

endif   ; (cpstatus eq 'OK')

 ; remove the uncompressed file copy
command3 = "rm -v " + myfile
spawn, command3

help
stop
userQuit:
print, ""
print, "Done!"
end
