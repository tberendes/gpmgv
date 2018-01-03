PRO test_read_tmi_geo_match_netcdf, gr2tmifile

; READ THE GRtoTMI MATCHUP FILE

cpstatus = uncomp_file( gr2tmifile, tmi_file )
if(cpstatus eq 'OK') then begin
  status = 1   ; init to FAILED
  tmi_geometa = get_geo_match_nc_struct( 'matchup' )
  tmi_sweeps = get_geo_match_nc_struct( 'sweeps' )
  tmi_site = get_geo_match_nc_struct( 'site' )
  tmi_flags = get_geo_match_nc_struct( 'fields_tmi' )
  tmi_files =  get_geo_match_nc_struct( 'files' )
  status = read_tmi_geo_match_netcdf( tmi_file, matchupmeta=tmi_geometa, $
     sweepsmeta=tmi_sweeps, sitemeta=tmi_site, fieldflags=tmi_flags, filesmeta=tmi_files )

 ; create data field arrays of correct dimensions and read data fields
  nfp = tmi_geometa.num_footprints
  nswp = tmi_geometa.num_sweeps

 ; define index array into the sweeps-level arrays
  tmi_data3_idx = indgen(nfp, nswp)

  tmi_gvexp=intarr(nfp, nswp)
  tmi_gvrej=intarr(nfp, nswp)
  tmi_gvexp_vpr=tmi_gvexp
  tmi_gvrej_vpr=tmi_gvrej
  tmi_gvz=fltarr(nfp, nswp)
  tmi_gvzmax=fltarr(nfp, nswp)
  tmi_gvzstddev=fltarr(nfp, nswp)
  tmi_gvz_vpr=fltarr(nfp, nswp)
  tmi_gvzmax_vpr=fltarr(nfp, nswp)
  tmi_gvzstddev_vpr=fltarr(nfp, nswp)
  tmi_gvrej_rr = intarr(nfp, nswp)
  tmi_gvrej_rr_vpr = tmi_gvrej_rr
  tmi_gv_rr = fltarr(nfp, nswp)
  tmi_gv_rr_max = fltarr(nfp, nswp)
  tmi_gv_rr_stddev = fltarr(nfp, nswp)
  tmi_gv_rr_vpr = fltarr(nfp, nswp)
  tmi_gv_rr_max_vpr = fltarr(nfp, nswp)
  tmi_gv_rr_stddev_vpr = fltarr(nfp, nswp)
  tmi_top=fltarr(nfp, nswp)
  tmi_botm=fltarr(nfp, nswp)
  tmi_top_vpr=tmi_top
  tmi_botm_vpr=tmi_botm
  tmi_xcorner=fltarr(4,nfp,nswp)
  tmi_ycorner=fltarr(4,nfp,nswp)
  tmi_lat=fltarr(nfp, nswp)
  tmi_lon=fltarr(nfp, nswp)
  tmi_sfclat=fltarr(nfp)
  tmi_sfclon=fltarr(nfp)
  tmi_sfctyp=intarr(nfp)
  tmi_sfcrain=fltarr(nfp)
  tmi_rnflag=intarr(nfp)
  tmi_dataflag=intarr(nfp)
  IF ( tmi_geometa.tmi_version EQ 7 ) THEN PoP=intarr(nfp)   ; only has data if V7
  tmi_index=lonarr(nfp)

  status = read_tmi_geo_match_netcdf( tmi_file, $
    grexpect_int=tmi_gvexp, grreject_int=tmi_gvrej, $
    grexpect_vpr_int=tmi_gvexp_vpr, grreject_vpr_int=tmi_gvrej_vpr, $
    dbzgv_viewed=tmi_gvz, dbzgv_vpr=tmi_gvz_vpr, $
    gvStdDev_viewed=tmi_gvzstddev, gvMax_viewed=tmi_gvzmax, $
    gvStdDev_vpr=tmi_gvzstddev_vpr, gvMax_vpr=tmi_gvzmax_vpr, $

    gr_rr_reject_int=tmi_gvrej_rr, gr_rr_reject_vpr_int=tmi_gvrej_rr_vpr, $
    rr_gv_viewed=tmi_gv_rr, rr_gv_vpr=tmi_gv_rr_vpr, $
    gvrrMax_viewed=tmi_gv_rr_max, gvrrStdDev_viewed=tmi_gv_rr_stddev, $
    gvrrMax_vpr=tmi_gv_rr_max_vpr, gvrrStdDev_vpr=tmi_gv_rr_stddev_vpr, $

    topHeight_viewed=tmi_top, bottomHeight_viewed=tmi_botm, $
    xCorners=tmi_xCorner, yCorners=tmi_yCorner, $
    latitude=tmi_lat, longitude=tmi_lon, $
    topHeight_vpr=tmi_top_vpr, bottomHeight_vpr=tmi_botm_vpr,           $
    TMIlatitude=tmi_sfclat, TMIlongitude=tmi_sfclon, $
    surfaceRain=tmi_sfcrain, sfctype_int=tmi_sfctyp, rainflag_int=tmi_rnFlag, $
    dataflag_int=tmi_dataFlag, PoP_int=PoP, tmi_idx_long=tmi_index )

  command3 = "rm  -v " + tmi_file
  spawn, command3
endif else begin
  print, 'Cannot copy/unzip TMI geo_match netCDF file: ', gr2tmifile
  print, cpstatus
  command3 = "rm  -v " + tmi_file
  spawn, command3
endelse

help
stop

end
