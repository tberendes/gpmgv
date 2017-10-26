;===============================================================================
;+
; Copyright © 2013, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; testreaddprgeomatchnetcdf.pro           Morris/SAIC/GPM_GV      July 2013
;
; DESCRIPTION
; -----------
; Test driver for function read_dpr_geo_match_netcdf_any.pro
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;===============================================================================

pro testreaddprgeomatchnetcdf_any, mygeomatchfile

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

; this time through just read the number of rays and sweeps and write them
; into the dpr_geo_match_meta structure
  status = read_dpr_geo_match_netcdf_new2( myfile, matchupmeta=mygeometa, $
     DIMS_ONLY=1 )

 ; create data field arrays of correct dimensions and read data fields
  nfp = mygeometa.num_footprints
  nswp = mygeometa.num_sweeps
  gvexpect = intarr(nfp,nswp)
  gvreject = intarr(nfp,nswp)
  dprexpect = intarr(nfp,nswp)
  zrawreject = intarr(nfp,nswp)
  zcorreject = intarr(nfp,nswp)
  dpr250expect = intarr(nfp,nswp)
  zraw250reject = intarr(nfp,nswp)
  zcor250reject = intarr(nfp,nswp)
  rainreject = intarr(nfp,nswp)
  dpr_dm_reject = intarr(nfp,nswp)
  dpr_nw_reject = intarr(nfp,nswp)
  gv_rc_reject = intarr(nfp,nswp)
  gv_rp_reject = intarr(nfp,nswp)
  gv_rr_reject = intarr(nfp,nswp)
  gv_hid_reject = intarr(nfp,nswp)
  gv_dzero_reject = intarr(nfp,nswp)
  gv_nw_reject = intarr(nfp,nswp)
  gv_dm_reject = intarr(nfp,nswp)
  gv_n2_reject = intarr(nfp,nswp)
  gv_zdr_reject = intarr(nfp,nswp)
  gv_kdp_reject = intarr(nfp,nswp)
  gv_RHOhv_reject = intarr(nfp,nswp)

  threeDreflect = intarr(nfp,nswp)
  ZFactorMeasured = fltarr(nfp,nswp)
  ZFactorCorrected = fltarr(nfp,nswp)
  ZFactorMeasured250m = fltarr(nfp,nswp)
  ZFactorCorrected250m = fltarr(nfp,nswp)
  maxZFactorMeasured250m = fltarr(nfp,nswp)
  PrecipRate = fltarr(nfp,nswp)
  dpr_dm = fltarr(nfp,nswp)
  dpr_nw = fltarr(nfp,nswp)
  threeDreflectStdDev = fltarr(nfp,nswp)
  threeDreflectMax = fltarr(nfp,nswp)
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
  qualityData = lonarr(nfp)
  clutterStatus = intarr(nfp)

; this time fill in all the structures and read all the data variables
  status = read_dpr_geo_match_netcdf_new2( myfile, matchupmeta=mygeometa, $
     sweepsmeta=mysweeps, sitemeta=mysite, fieldflags=myflags, $
   ; threshold/data completeness parameters for vert/horiz averaged values:
    gvexpect_int=gvexpect, gvreject_int=gvreject, dprexpect_int=dprexpect,    $
    zrawreject_int=zrawreject, zcorreject_int=zcorreject,                     $
    dpr250expect_int=dpr250expect, zraw250reject_int=zraw250reject,           $
    zcor250reject_int=zcor250reject,                                          $
    rainreject_int=rainreject, dpr_dm_reject_int=dpr_dm_reject,               $
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
    qualityData_long=qualityData, clutterStatus_int=clutterStatus )

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
STOP

help, gvexpect
help, gvreject
help, dprexpect
help, zrawreject
help, zcorreject
help, rainreject
STOP

help, threeDreflect
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
STOP

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

userQuit:
errorExit:
END
