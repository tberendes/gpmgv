;===============================================================================
;+
; Copyright © 2008, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; testreadgeomatchnetcdf.pro           Morris/SAIC/GPM_GV      September 2008
;
; DESCRIPTION
; -----------
; Test driver for function read_geo_match_netcdf.pro
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;===============================================================================

pro testreadgeomatchnetcdf

@geo_match_nc_structs.inc

mygeomatchfile='/data/gpmgv/netcdf/geo_match/GRtoPR.KAMX.140131.92335.7.2_3.nc.gz'
;mygeomatchfile='/tmp/GRtoPR.KFWS.130816.89723.7.2_3.nc'
mygeomatchfile='/tmp/tEmP_FiLe.GRtoPR.KAMX.140131.92335.7.3_0.nc'
mygeomatchfile='/tmp/GRtoPR.KWAJ.110106.74873.7.3_1.nc.gz'

cpstatus = uncomp_file( mygeomatchfile, myfile )
if(cpstatus eq 'OK') then begin
  status = 1   ; init to FAILED
  mygeometa={ geo_match_meta }
  mysweeps={ gv_sweep_meta }
  mysite={ gv_site_meta }
  myflags={ pr_gv_field_flags }
  myfiles={ input_files }
  status = read_geo_match_netcdf( myfile, matchupmeta=mygeometa, $
     sweepsmeta=mysweeps, sitemeta=mysite, fieldflags=myflags, $
     filesmeta=myfiles )

 ; create data field arrays of correct dimensions and read data fields
  nfp = mygeometa.num_footprints
  nswp = mygeometa.num_sweeps
  gvexp=intarr(nfp,nswp)
  gvrej=intarr(nfp,nswp)
  gvrrrej=intarr(nfp,nswp)
  gv_hid_rej=intarr(nfp,nswp)
  gv_dzero_rej=intarr(nfp,nswp)
  gv_nw_rej=intarr(nfp,nswp)
  prexp=intarr(nfp,nswp)
  zrawrej=intarr(nfp,nswp)
  zcorrej=intarr(nfp,nswp)
  rainrej=intarr(nfp,nswp)
  gvz=fltarr(nfp,nswp)
  gvzMax=fltarr(nfp,nswp)
  gvzStdDev=fltarr(nfp,nswp)
  gvrr=fltarr(nfp,nswp)
  gvrrMax=fltarr(nfp,nswp)
  gvrrStdDev=fltarr(nfp,nswp)
  GR_DP_HID=intarr(15,nfp,nswp)
  GR_DP_Dzero=fltarr(nfp,nswp)
  GR_DP_DzeroMax=fltarr(nfp,nswp)
  GR_DP_DzeroStdDev=fltarr(nfp,nswp)
  GR_DP_Nw=fltarr(nfp,nswp)
  GR_DP_NwMax=fltarr(nfp,nswp)
  GR_DP_NwStdDev=fltarr(nfp,nswp)
  GR_DP_Zdr=fltarr(nfp,nswp)
  GR_DP_ZdrMax=fltarr(nfp,nswp)
  GR_DP_ZdrStdDev=fltarr(nfp,nswp)
  GR_DP_Kdp=fltarr(nfp,nswp)
  GR_DP_KdpMax=fltarr(nfp,nswp)
  GR_DP_KdpStdDev=fltarr(nfp,nswp)
  GR_DP_RHOhv=fltarr(nfp,nswp)
  GR_DP_RHOhvMax=fltarr(nfp,nswp)
  GR_DP_RHOhvStdDev=fltarr(nfp,nswp)
  zraw=fltarr(nfp,nswp)
  zcor=fltarr(nfp,nswp)
  rain3=fltarr(nfp,nswp)
  top=fltarr(nfp,nswp)
  botm=fltarr(nfp,nswp)
  xcorner=fltarr(4,nfp,nswp)
  ycorner=fltarr(4,nfp,nswp)
  lat=fltarr(nfp,nswp)
  lon=fltarr(nfp,nswp)
  sfclat=fltarr(nfp)
  sfclon=fltarr(nfp)
  sfctyp=intarr(nfp)
  sfcrain=fltarr(nfp)
  sfcraincomb=fltarr(nfp)
  bb=fltarr(nfp)
  rnflag=intarr(nfp)
  rntype=intarr(nfp)
  pia=fltarr(nfp)
  pr_index=lonarr(nfp)

  status = read_geo_match_netcdf( myfile, $

    gvexpect_int=gvexp, gvreject_int=gvrej, prexpect_int=prexp, $
    zrawreject_int=zrawrej, zcorreject_int=zcorrej, rainreject_int=rainrej, $
    gv_rr_reject_int=gvrrrej, gv_hid_reject_int=gv_hid_rej, $
    gv_dzero_reject_int=gv_dzero_rej, gv_nw_reject_int=gv_nw_rej, $

    dbzgv=gvz, gvStdDev=gvzStdDev, gvMax=gvzMax, dbzcor=zcor, dbzraw=zraw, $
    rrgvMean=gvrr, rrgvMax=gvrrMax, rrgvStdDev=gvrrStdDev, rain3d=rain3,      $
    dzerogvMean=GR_DP_Dzero, dzerogvMax=GR_DP_DzeroMax,                       $
    dzerogvStdDev=GR_DP_DzeroStdDev,                                          $
    nwgvMean=GR_DP_Nw, nwgvMax=GR_DP_NwMax, nwgvStdDev=GR_DP_NwStdDev,        $
    zdrgvMean=GR_DP_Zdr, zdrgvMax=GR_DP_ZdrMax, zdrgvStdDev=GR_DP_ZdrStdDev,  $
    kdpgvMean=GR_DP_Kdp, kdpgvMax=GR_DP_KdpMax, kdpgvStdDev=GR_DP_KdpStdDev,  $
    rhohvgvMean=GR_DP_RHOhv, rhohvgvMax=GR_DP_RHOhvMax,                       $
    rhohvgvStdDev=GR_DP_RHOhvStdDev, hidgv=GR_DP_HID,                         $

    topHeight=top, bottomHeight=botm, xCorners=xCorner, yCorners=yCorner, $
    latitude=lat, longitude=lon, PRlatitude=sfclat, PRlongitude=sfclon, $
    sfctype_int=sfctyp, sfcrainpr=sfcrain, sfcraincomb=sfcraincomb, bbhgt=BB, $
    rainflag_int=rnFlag, raintype_int=rnType, PIA=pia,  pridx_long=pr_index )

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

help, gvexp
help, gvrej
help, prexp
help, zrawrej
help, zcorrej
help, rainrej
STOP

help, gvz
help, zraw
;print, zraw[*,mygrid.ny/2,0]
help, zcor
;STOP
;print, zcor[*,mygrid.ny/2,0]
;STOP
help, rain3
;STOP
;print, rain3[*,mygrid.ny/2,0]
;STOP
help, top
help, botm
help, xcorner
help, ycorner
help, lat
help, lon
STOP

help, sfclat
help, sfclon
help, sfctyp
;STOP
;print, sfctyp[*,mygrid.ny/2]
;STOP
help, sfcrain
;STOP
;print, sfcrain[*,mygrid.ny/2]
;STOP
help, sfcraincomb
;STOP
;print, sfcraincomb[*,mygrid.ny/2]
;STOP
help, bb
;STOP
;print, bb[*,mygrid.ny/2]
;STOP
help, rnflag
;STOP
;print, rnflag[*,mygrid.ny/2]
;STOP
help, rntype
;STOP
;print, rntype[*,mygrid.ny/2]
;STOP
help, pr_index
;STOP
;print, pr_index[*]

errorExit:
END
