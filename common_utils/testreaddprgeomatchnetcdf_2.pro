;===============================================================================
;+
; Copyright © 2013, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; testreaddprgeomatchnetcdf_2.pro           Morris/SAIC/GPM_GV      July 2013
;
; DESCRIPTION
; -----------
; Test driver for function read_dpr_geo_match_netcdf.pro
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;===============================================================================

pro testreaddprgeomatchnetcdf_2, mygeomatchfile, DATASTRUCT=datastruct

@dpr_geo_match_nc_structs.inc

if n_elements(mygeomatchfile) eq 0 then begin
   filters = ['GRtoDPR.*']
   mygeomatchfile=dialog_pickfile(FILTER=filters, $
       TITLE='Select GRtoDPR file to read', $
       PATH='/data/gpmgv/netcdf/geo_match')
   IF (mygeomatchfile EQ '') THEN GOTO, userQuit
endif

cpstatus = uncomp_file( mygeomatchfile, myfile )
if(cpstatus eq 'OK') then begin
  status = 1   ; init to FAILED
  mygeometa={ dpr_geo_match_meta }
  mysweeps={ gr_sweep_meta }
  mysite={ gr_site_meta }
  myflags={ dpr_gr_field_flags }
  status = read_dpr_geo_match_netcdf( myfile, matchupmeta=mygeometa, $
     sweepsmeta=mysweeps, sitemeta=mysite, fieldflags=myflags )

 ; create data field arrays of correct dimensions and read data fields
  nfp = mygeometa.num_footprints
  nswp = mygeometa.num_sweeps
  n_gr_expected = intarr(nfp,nswp)
  n_gr_z_rejected = intarr(nfp,nswp)
  n_dpr_expected = intarr(nfp,nswp)
  n_dpr_zm_rejected = intarr(nfp,nswp)
  n_dpr_zc_rejected = intarr(nfp,nswp)
  dpr250expect = intarr(nfp,nswp)
  zraw250reject = intarr(nfp,nswp)
  zcor250reject = intarr(nfp,nswp)
  n_dpr_rain_rejected = intarr(nfp,nswp)
  n_dpr_dm_rejected = intarr(nfp,nswp)
  n_dpr_nw_rejected = intarr(nfp,nswp)
  n_gr_rc_rejected = intarr(nfp,nswp)
  n_gr_rp_rejected = intarr(nfp,nswp)
  n_gr_rr_rejected = intarr(nfp,nswp)
  n_gr_hid_rejected = intarr(nfp,nswp)
  n_gr_dzero_rejected = intarr(nfp,nswp)
  n_gr_nw_rejected = intarr(nfp,nswp)
  n_gr_dm_rejected = intarr(nfp,nswp)
  n_gr_n2_rejected = intarr(nfp,nswp)
  n_gr_zdr_rejected = intarr(nfp,nswp)
  n_gr_kdp_rejected = intarr(nfp,nswp)
  n_gr_rhohv_rejected = intarr(nfp,nswp)

  GR_Z = intarr(nfp,nswp)
  ZFactorMeasured = fltarr(nfp,nswp)
  ZFactorCorrected = fltarr(nfp,nswp)
  ZFactorMeasured250m = fltarr(nfp,nswp)
  ZFactorCorrected250m = fltarr(nfp,nswp)
  PrecipRate = fltarr(nfp,nswp)
  dpr_dm = fltarr(nfp,nswp)
  dpr_nw = fltarr(nfp,nswp)
  GR_Z_StdDev = fltarr(nfp,nswp)
  GR_Z_Max = fltarr(nfp,nswp)
  GR_RC_rainrate = fltarr(nfp,nswp)
  GR_RC_rainrate_Max = fltarr(nfp,nswp)
  GR_RC_rainrate_StdDev = fltarr(nfp,nswp)
  GR_RP_rainrate = fltarr(nfp,nswp)
  GR_RP_rainrate_Max = fltarr(nfp,nswp)
  GR_RP_rainrate_StdDev = fltarr(nfp,nswp)
  GR_RR_rainrate = fltarr(nfp,nswp)
  GR_RR_rainrate_Max = fltarr(nfp,nswp)
  GR_RR_rainrate_StdDev = fltarr(nfp,nswp)
  GR_Dzero = fltarr(nfp,nswp)
  GR_Dzero_Max = fltarr(nfp,nswp)
  GR_Dzero_StdDev = fltarr(nfp,nswp)
  GR_Nw = fltarr(nfp,nswp)
  GR_Nw_Max = fltarr(nfp,nswp)
  GR_Nw_StdDev = fltarr(nfp,nswp)
  GR_Dm = fltarr(nfp,nswp)
  GR_Dm_Max = fltarr(nfp,nswp)
  GR_Dm_StdDev = fltarr(nfp,nswp)
  GR_N2 = fltarr(nfp,nswp)
  GR_N2_Max = fltarr(nfp,nswp)
  GR_N2_StdDev = fltarr(nfp,nswp)
  GR_Zdr = fltarr(nfp,nswp)
  GR_Zdr_Max = fltarr(nfp,nswp)
  GR_Zdr_StdDev = fltarr(nfp,nswp)
  GR_Kdp = fltarr(nfp,nswp)
  GR_Kdp_Max = fltarr(nfp,nswp)
  GR_Kdp_StdDev = fltarr(nfp,nswp)
  GR_RHOhv = fltarr(nfp,nswp)
  GR_RHOhv_Max = fltarr(nfp,nswp)
  GR_RHOhv_StdDev = fltarr(nfp,nswp)
  GR_blockage = fltarr(nfp,nswp)
  GR_HID = intarr(15,nfp,nswp)

  topHeight = fltarr(nfp,nswp)
  bottomHeight = fltarr(nfp,nswp)
  xcorners = fltarr(4,nfp,nswp)
  ycorners = fltarr(4,nfp,nswp)
  latitude = fltarr(nfp,nswp)
  longitude = fltarr(nfp,nswp)
  DPRlatitude = fltarr(nfp)
  DPRlongitude = fltarr(nfp)
  PrecipRateSurface = fltarr(nfp)
  SurfPrecipRate = fltarr(nfp)
  BBheight = fltarr(nfp)
  LandSurfaceType = intarr(nfp)
  FlagPrecip = intarr(nfp)
  TypePrecip = intarr(nfp)
  rayIndex = lonarr(nfp)
  bbstatus = intarr(nfp)
  piaFinal = fltarr(nfp)
  heightStormTop = intarr(nfp)
  clutterStatus = intarr(nfp)

  status = read_dpr_geo_match_netcdf( myfile, $
   ; threshold/data completeness parameters for vert/horiz averaged values:
    gvexpect_int=n_gr_expected, gvreject_int=n_gr_z_rejected, dprexpect_int=n_dpr_expected,    $
    zrawreject_int=n_dpr_zm_rejected, zcorreject_int=n_dpr_zc_rejected,                     $
    dpr250expect_int=dpr250expect, zraw250reject_int=zraw250reject,           $
    zcor250reject_int=zcor250reject,                                          $
    rainreject_int=n_dpr_rain_rejected, dpr_dm_reject_int=n_dpr_dm_rejected,               $
    dpr_nw_reject_int=n_dpr_nw_rejected, gv_rc_reject_int=n_gr_rc_rejected,           $
    gv_rp_reject_int=n_gr_rp_rejected, gv_rr_reject_int=n_gr_rr_rejected,             $
    gv_hid_reject_int=n_gr_hid_rejected, gv_dzero_reject_int=n_gr_dzero_rejected,     $
    gv_nw_reject_int=n_gr_nw_rejected, gv_dm_reject_int=n_gr_dm_rejected,             $
    gv_n2_reject_int=n_gr_n2_rejected, gv_zdr_reject_int=n_gr_zdr_rejected,           $
    gv_kdp_reject_int=n_gr_kdp_rejected, gv_RHOhv_reject_int=n_gr_rhohv_rejected,     $
   ; horizontally (GV) and vertically (DPR Z, rain) averaged values at elevs.:
    dbzgv=GR_Z, dbzraw=ZFactorMeasured, dbzcor=ZFactorCorrected,     $
    dbz250raw=ZFactorMeasured250m, dbz250cor=ZFactorCorrected250m,            $
    rain3d=PrecipRate, DmDPRmean = DPR_Dm, NwDPRmean = DPR_Nw,                $
    gvStdDev=GR_Z_StdDev, gvMax=GR_Z_Max,                     $
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
    clutterStatus_int=clutterStatus )

  command3 = "rm  " + myfile
  spawn, command3
endif else begin
  print, 'Cannot copy/unzip geo_match netCDF file: ', mygeomatchfile
  print, cpstatus
  command3 = "rm  " + myfile
  spawn, command3
  goto, errorExit
endelse

if ( status NE 0 ) THEN GOTO, errorExit

print, mygeometa
help, mysweeps
print, mysweeps
print, mysite
print, myflags
;STOP

help, n_gr_expected
help, n_gr_z_rejected
help, n_dpr_expected
help, n_dpr_zm_rejected
help, n_dpr_zc_rejected
help, n_dpr_rain_rejected
;STOP

help, GR_Z
help, ZFactorMeasured
;print, ZFactorMeasured[*,mygrid.ny/2,0]
help, ZFactorCorrected
;STOP
;print, ZFactorCorrected[*,mygrid.ny/2,0]
;STOP
help, PrecipRate
;STOP
;print, PrecipRate[*,mygrid.ny/2,0]
;STOP
help, topHeight
help, bottomHeight
help, xcorners
help, ycorners
help, latitude
help, longitude
;STOP

help, DPRlatitude
help, DPRlongitude
help, LandSurfaceType
;STOP
;print, sfctyp[*,mygrid.ny/2]
;STOP
help, PrecipRateSurface
;STOP
;print, sfcrain[*,mygrid.ny/2]
;STOP
help, SurfPrecipRate
;STOP
;print, sfcraincomb[*,mygrid.ny/2]
;STOP
help, bbheight
;STOP
;print, bb[*,mygrid.ny/2]
;STOP
help, FlagPrecip
;STOP
;print, rnflag[*,mygrid.ny/2]
;STOP
help, TypePrecip
;STOP
;print, rntype[*,mygrid.ny/2]
;STOP
help, rayIndex
;STOP
;print, pr_index[*]

IF N_ELEMENTS(datastruct) NE 0 THEN BEGIN
  ; copy the swath-specific data variables into anonymous structure, use
  ; TEMPORARY to avoid making a copy of the variable when loading to struct
print, "HERE!"
  datastruct = { latitude : TEMPORARY(latitude), $
                 longitude : TEMPORARY(longitude), $
                 xCorners : TEMPORARY(xCorners), $
                 yCorners : TEMPORARY(yCorners), $
                 topHeight : TEMPORARY(topHeight), $
                 bottomHeight : TEMPORARY(bottomHeight), $
                 ZFactorMeasured  : TEMPORARY(ZFactorMeasured), $
                 ZFactorCorrected : TEMPORARY(ZFactorCorrected), $
                 PrecipRate : TEMPORARY(PrecipRate), $
                 PrecipRateSurface : TEMPORARY(PrecipRateSurface), $
                 FlagPrecip : TEMPORARY(FlagPrecip), $
                 TypePrecip : TEMPORARY(TypePrecip), $
                 BBheight : TEMPORARY(BBheight), $
                 LandSurfaceType : TEMPORARY(LandSurfaceType), $
                 piaFinal : TEMPORARY(piaFinal), $
                 heightStormTop : TEMPORARY(heightStormTop), $
                 GR_Z : TEMPORARY(GR_Z), $
                 GR_Z_StdDev : TEMPORARY(GR_Z_StdDev), $
                 GR_Z_Max : TEMPORARY(GR_Z_Max), $
                 GR_Zdr : TEMPORARY(GR_Zdr), $
                 GR_Zdr_StdDev : TEMPORARY(GR_Zdr_StdDev), $
                 GR_Zdr_Max : TEMPORARY(GR_Zdr_Max), $
                 GR_Kdp : TEMPORARY(GR_Kdp), $
                 GR_Kdp_StdDev : TEMPORARY(GR_Kdp_StdDev), $
                 GR_Kdp_Max : TEMPORARY(GR_Kdp_Max), $
                 GR_RHOhv : TEMPORARY(GR_RHOhv), $
                 GR_RHOhv_StdDev : TEMPORARY(GR_RHOhv_StdDev), $
                 GR_RHOhv_Max : TEMPORARY(GR_RHOhv_Max), $
                 GR_RC_rainrate : TEMPORARY(GR_RC_rainrate), $
                 GR_RC_rainrate_StdDev : TEMPORARY(GR_RC_rainrate_StdDev), $
                 GR_RC_rainrate_Max : TEMPORARY(GR_RC_rainrate_Max), $
                 GR_RP_rainrate : TEMPORARY(GR_RP_rainrate), $
                 GR_RP_rainrate_StdDev : TEMPORARY(GR_RP_rainrate_StdDev), $
                 GR_RP_rainrate_Max : TEMPORARY(GR_RP_rainrate_Max), $
                 GR_RR_rainrate : TEMPORARY(GR_RR_rainrate), $
                 GR_RR_rainrate_StdDev : TEMPORARY(GR_RR_rainrate_StdDev), $
                 GR_RR_rainrate_Max : TEMPORARY(GR_RR_rainrate_Max), $
                 GR_HID : TEMPORARY(GR_HID), $
                 GR_Dzero : TEMPORARY(GR_Dzero), $
                 GR_Dzero_StdDev : TEMPORARY(GR_Dzero_StdDev), $
                 GR_Dzero_Max : TEMPORARY(GR_Dzero_Max), $
                 GR_Nw : TEMPORARY(GR_Nw), $
                 GR_Nw_StdDev : TEMPORARY(GR_Nw_StdDev), $
                 GR_Nw_Max : TEMPORARY(GR_Nw_Max), $
                 GR_Dm : TEMPORARY(GR_Dm), $
                 GR_Dm_StdDev : TEMPORARY(GR_Dm_StdDev), $
                 GR_Dm_Max : TEMPORARY(GR_Dm_Max), $
                 GR_N2 : TEMPORARY(GR_N2), $
                 GR_N2_StdDev : TEMPORARY(GR_N2_StdDev), $
                 GR_N2_Max : TEMPORARY(GR_N2_Max), $
                 GR_blockage : TEMPORARY(GR_blockage), $
                 n_gr_z_rejected : TEMPORARY(n_gr_z_rejected), $
                 n_gr_zdr_rejected : TEMPORARY(n_gr_zdr_rejected), $
                 n_gr_kdp_rejected : TEMPORARY(n_gr_kdp_rejected), $
                 n_gr_rhohv_rejected : TEMPORARY(n_gr_rhohv_rejected), $
                 n_gr_rc_rejected : TEMPORARY(n_gr_rc_rejected), $
                 n_gr_rp_rejected : TEMPORARY(n_gr_rp_rejected), $
                 n_gr_rr_rejected : TEMPORARY(n_gr_rr_rejected), $
                 n_gr_hid_rejected : TEMPORARY(n_gr_hid_rejected), $
                 n_gr_dzero_rejected : TEMPORARY(n_gr_dzero_rejected), $
                 n_gr_nw_rejected : TEMPORARY(n_gr_nw_rejected), $
                 n_gr_dm_rejected : TEMPORARY(n_gr_dm_rejected), $
                 n_gr_n2_rejected : TEMPORARY(n_gr_n2_rejected), $
                 n_gr_expected : TEMPORARY(n_gr_expected), $
                 n_dpr_expected : TEMPORARY(n_dpr_expected), $
                 n_dpr_zm_rejected : TEMPORARY(n_dpr_zm_rejected), $
                 n_dpr_zc_rejected : TEMPORARY(n_dpr_zc_rejected), $
                 n_dpr_rain_rejected : TEMPORARY(n_dpr_rain_rejected), $
                 DPRlatitude : TEMPORARY(DPRlatitude), $
                 DPRlongitude : TEMPORARY(DPRlongitude), $
                 rayIndex : TEMPORARY(rayIndex) }
ENDIF

userQuit:
errorExit:
END

