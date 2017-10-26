;ncfile1='/tmp/GRtoPR.KMLB.090714.66444.nc'
;ncfile1='/tmp/GRtoPR.KMLB.070101.52023.AllSwpTimes1.nc'

@geo_match_nc_structs.inc
  mygeometa={ geo_match_meta }
  mysweeps={ gv_sweep_meta }
  mysite={ gv_site_meta }
  myflags={ pr_gv_field_flags }
  status = read_geo_match_netcdf_multi( ncfile1, matchupmeta=mygeometa, $
     sweepsmeta=mysweeps, sitemeta=mysite, fieldflags=myflags )
  nfp = mygeometa.num_footprints  ; # of PR rays in dataset (real+bogus)
  nswp = mygeometa.num_sweeps     ; # of GR elevation sweeps in dataset

  gvexp=intarr(nfp,nswp)
  gvrej=intarr(nfp,nswp)
  prexp=intarr(nfp,nswp)
  zrawrej=intarr(nfp,nswp)
  zcorrej=intarr(nfp,nswp)
  rainrej=intarr(nfp,nswp)
  gvz=intarr(nfp,nswp)
  zraw=fltarr(nfp,nswp)
  zcor=fltarr(nfp,nswp)
  rain3=fltarr(nfp,nswp)
  top=fltarr(nfp,nswp)
  botm=fltarr(nfp,nswp)
  lat=fltarr(nfp,nswp)
  lon=fltarr(nfp,nswp)
  bb=fltarr(nfp)
  nearSurfRain=fltarr(nfp)
  nearSurfRain_2b31=fltarr(nfp)
  rnflag=intarr(nfp)
  rntype=intarr(nfp)
  pr_index=lonarr(nfp)
  xcorner=fltarr(4,nfp,nswp)
  ycorner=fltarr(4,nfp,nswp)

  status = read_geo_match_netcdf_multi( ncfile1,  $
    gvexpect_int=gvexp, gvreject_int=gvrej, prexpect_int=prexp, $
    zrawreject_int=zrawrej, zcorreject_int=zcorrej, rainreject_int=rainrej, $
    dbzgv=gvz, dbzcor=zcor, dbzraw=zraw, rain3d=rain3, topHeight=top, $
    bottomHeight=botm, latitude=lat, longitude=lon, bbhgt=BB, $
    sfcrainpr=nearSurfRain, sfcraincomb=nearSurfRain_2b31, $
    rainflag_int=rnFlag, raintype_int=rnType, pridx_long=pr_index, $
    xCorners=xCorner, yCorners=yCorner )
