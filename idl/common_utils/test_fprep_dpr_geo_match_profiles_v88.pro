PRO test_fprep_dpr_geo_match_profiles_v88, NCPATH=ncpath, SITE=sitefilter, $
                                       PCT_ABV_THRESH=pctAbvThresh,    $
                                       GV_CONVECTIVE=gvconvective,     $
                                       GV_STRATIFORM=gvstratiform, S2KU = s2ku, $
                                       BB_RELATIVE=bb_relative, BBWIDTH=bbwidth, $
                                       ALT_BB_HGT=alt_bb_hgt

IF ( N_ELEMENTS(ncpath) NE 1 ) THEN BEGIN
   print, "Defaulting to /data/gpmgv/netcdf/geo_match for file path."
   pathpr = '/data/gpmgv/netcdf/geo_match/GPM/2ADPR/NS/V05A/8_8'
ENDIF ELSE pathpr = ncpath

IF ( N_ELEMENTS(sitefilter) NE 1 ) THEN BEGIN
   print, "Defaulting to GRtoDPR* for file pattern."
   ncfilepatt = 'GRtoDPR*'
ENDIF ELSE ncfilepatt = '*'+sitefilter+'*'
ncfilepr = dialog_pickfile(path=pathpr, filter = ncfilepatt)

ptr_geometa=ptr_new(/allocate_heap)
ptr_sweepmeta=ptr_new(/allocate_heap)
ptr_sitemeta=ptr_new(/allocate_heap)
ptr_fieldflags=ptr_new(/allocate_heap)
ptr_filesmeta=ptr_new(/allocate_heap)

ptr_gvz=ptr_new(/allocate_heap)
ptr_gvzmax=ptr_new(/allocate_heap)
ptr_gvzstddev=ptr_new(/allocate_heap)

ptr_gvrc=ptr_new(/allocate_heap)
ptr_gvrcmax=ptr_new(/allocate_heap)
ptr_gvrcstddev=ptr_new(/allocate_heap)
ptr_gvrp=ptr_new(/allocate_heap)
ptr_gvrpmax=ptr_new(/allocate_heap)
ptr_gvrpstddev=ptr_new(/allocate_heap)
ptr_gvrr=ptr_new(/allocate_heap)
ptr_gvrrmax=ptr_new(/allocate_heap)
ptr_gvrrstddev=ptr_new(/allocate_heap)

ptr_GR_DP_HID=ptr_new(/allocate_heap)
ptr_mode_HID=ptr_new(/allocate_heap)
ptr_GR_DP_Dzero=ptr_new(/allocate_heap)
ptr_GR_DP_Dzeromax=ptr_new(/allocate_heap)
ptr_GR_DP_Dzerostddev=ptr_new(/allocate_heap)
ptr_GR_DP_Nw=ptr_new(/allocate_heap)
ptr_GR_DP_Nwmax=ptr_new(/allocate_heap)
ptr_GR_DP_Nwstddev=ptr_new(/allocate_heap)
ptr_GR_DP_Dm=ptr_new(/allocate_heap)
ptr_GR_DP_Dmmax=ptr_new(/allocate_heap)
ptr_GR_DP_Dmstddev=ptr_new(/allocate_heap)
ptr_GR_DP_N2=ptr_new(/allocate_heap)
ptr_GR_DP_N2max=ptr_new(/allocate_heap)
ptr_GR_DP_N2stddev=ptr_new(/allocate_heap)
ptr_GR_DP_Zdr=ptr_new(/allocate_heap)
ptr_GR_DP_Zdrmax=ptr_new(/allocate_heap)
ptr_GR_DP_Zdrstddev=ptr_new(/allocate_heap)
ptr_GR_DP_Kdp=ptr_new(/allocate_heap)
ptr_GR_DP_Kdpmax=ptr_new(/allocate_heap)
ptr_GR_DP_Kdpstddev=ptr_new(/allocate_heap)
ptr_GR_DP_RHOhv=ptr_new(/allocate_heap)
ptr_GR_DP_RHOhvmax=ptr_new(/allocate_heap)
ptr_GR_DP_RHOhvstddev=ptr_new(/allocate_heap)
ptr_GR_blockage=ptr_new(/allocate_heap)

ptr_zcor=ptr_new(/allocate_heap)
ptr_zraw=ptr_new(/allocate_heap)
ptr_250zcor=ptr_new(/allocate_heap)
ptr_250zraw=ptr_new(/allocate_heap)
ptr_250maxzraw=ptr_new(/allocate_heap)
ptr_rain3=ptr_new(/allocate_heap)
ptr_dprdm=ptr_new(/allocate_heap)
ptr_dprnw=ptr_new(/allocate_heap)
ptr_dprepsilon=ptr_new(/allocate_heap)
ptr_top=ptr_new(/allocate_heap)
ptr_botm=ptr_new(/allocate_heap)
ptr_lat=ptr_new(/allocate_heap)
ptr_lon=ptr_new(/allocate_heap)
ptr_dpr_lat=ptr_new(/allocate_heap)
ptr_dpr_lon=ptr_new(/allocate_heap)
ptr_nearSurfRain=ptr_new(/allocate_heap)
ptr_nearSurfRain_Comb=ptr_new(/allocate_heap)   ; obsolete variable
ptr_rnFlag=ptr_new(/allocate_heap)
ptr_rnType=ptr_new(/allocate_heap)
ptr_landOcean=ptr_new(/allocate_heap)
ptr_pr_index=ptr_new(/allocate_heap)
ptr_xCorner=ptr_new(/allocate_heap)
ptr_yCorner=ptr_new(/allocate_heap)
ptr_bbProx=ptr_new(/allocate_heap)
ptr_bbHeight=ptr_new(/allocate_heap)
ptr_bbstatus=ptr_new(/allocate_heap)
ptr_pia=ptr_new(/allocate_heap)
ptr_qualityData=ptr_new(/allocate_heap)
ptr_clutterStatus=ptr_new(/allocate_heap)
ptr_hgtcat=ptr_new(/allocate_heap)
ptr_dist=ptr_new(/allocate_heap)

ptr_phase=ptr_new(/allocate_heap)
ptr_phaseNearSurface=ptr_new(/allocate_heap)
ptr_phaseHeightAGL=ptr_new(/allocate_heap)

IF ( N_ELEMENTS(pctAbvThresh) EQ 1 ) THEN BEGIN
   ptr_pctgoodpr=ptr_new(/allocate_heap)
   ptr_pctgood250pr=ptr_new(/allocate_heap)
   ptr_pctgood250rawpr=ptr_new(/allocate_heap)
   ptr_pctgoodgv=ptr_new(/allocate_heap)
   ptr_pctgoodrain=ptr_new(/allocate_heap)
   ptr_pctgoodDprDm=ptr_new(/allocate_heap)
   ptr_pctgoodDprNw=ptr_new(/allocate_heap)
   ptr_pctgoodDprEpsilon=ptr_new(/allocate_heap)
   ptr_pctgoodrcgv=ptr_new(/allocate_heap)
   ptr_pctgoodrpgv=ptr_new(/allocate_heap)
   ptr_pctgoodrrgv=ptr_new(/allocate_heap)
   ptr_pctgoodhidgv=ptr_new(/allocate_heap)
   ptr_pctgooddzerogv=ptr_new(/allocate_heap)
   ptr_pctgoodnwgv=ptr_new(/allocate_heap)
   ptr_pctgooddmgv=ptr_new(/allocate_heap)
   ptr_pctgoodn2gv=ptr_new(/allocate_heap)
   ptr_pctgoodzdrgv=ptr_new(/allocate_heap)
   ptr_pctgoodkdpgv=ptr_new(/allocate_heap)
   ptr_pctgoodrhohvgv=ptr_new(/allocate_heap)
ENDIF
;meanBB = -99.99
BBparms = {meanBB : -99.99, BB_HgtLo : -99, BB_HgtHi : -99}
heights = [1.5,3.0,4.5,6.0,7.5,9.0,10.5,12.0,13.5,15.0,16.5,18.0,19.5]

status = fprep_dpr_geo_match_profiles_v88( ncfilepr, heights, $
    PCT_ABV_THRESH=pctAbvThresh, GV_CONVECTIVE=gvconvective, $
    GV_STRATIFORM=gvstratiform, S2KU=s2ku, PTRgeometa=ptr_geometa, $
    PTRsweepmeta=ptr_sweepmeta, PTRsitemeta=ptr_sitemeta, $
    PTRfieldflags=ptr_fieldflags, PTRfilesmeta=ptr_filesmeta, $

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

    PTRzcor=ptr_zcor, PTRzraw=ptr_zraw, PTRrain3d=ptr_rain3, $
    PTR250zcor=ptr_250zcor, PTR250zraw=ptr_250zraw, PTR250maxzraw=ptr_250maxzraw, $
    PTRdprdm=ptr_dprDm, PTRdprnw=ptr_dprNw, PTRdprEpsilon=ptr_dprEpsilon, $
    PTRprlat=ptr_dpr_lat, PTRprlon=ptr_dpr_lon, PTRpia=ptr_pia, $
    PTRsfcrainpr=ptr_nearSurfRain, PTRsfcraincomb=ptr_nearSurfRain_Comb, $
    PTRrainflag_int=ptr_rnFlag, PTRraintype_int=ptr_rnType, $
    PTRlandOcean_int=ptr_landOcean, PTRpridx_long=ptr_pr_index,  $
    PTRbbHgt=ptr_bbHeight, PTRbbStatus=ptr_bbstatus, $
    PTRqualityData=ptr_qualityData, $

    PTRtop=ptr_top, PTRbotm=ptr_botm, PTRlat=ptr_lat, PTRlon=ptr_lon, $
    PTRxCorners=ptr_xCorner, PTRyCorners=ptr_yCorner, PTRbbProx=ptr_bbProx, $
    PTRclutterStatus=ptr_clutterStatus, PTRhgtcat=ptr_hgtcat, PTRdist=ptr_dist, $

    PTRpctgoodpr=ptr_pctgoodpr, PTRpctgoodrain=ptr_pctgoodrain, $
    PTRpctgood250pr=ptr_pctgood250pr, PTRpctgood250rawpr=ptr_pctgood250rawpr, $
    PTRpctgoodDprDm=ptr_pctgoodDprDm, PTRpctgoodDprNw=ptr_pctgoodDprNw, $
    PTRpctgoodDprEpsilon=ptr_pctgoodDprEpsilon, $
    PTRpctgoodgv=ptr_pctgoodgv, PTRpctgoodrcgv=ptr_pctgoodrcgv, $
    PTRpctgoodrpgv=ptr_pctgoodrpgv, PTRpctgoodrrgv=ptr_pctgoodrrgv, $
    PTRpctgoodhidgv=ptr_pctgoodhidgv, PTRpctgooddzerogv=ptr_pctgooddzerogv, $
    PTRpctgoodnwgv=ptr_pctgoodnwgv, PTRpctgooddmgv=ptr_pctgooddmgv, $
    PTRpctgoodn2gv=ptr_pctgoodn2gv, PTRpctgoodzdrgv=ptr_pctgoodzdrgv, $
    PTRpctgoodkdpgv=ptr_pctgoodkdpgv, PTRpctgoodrhohvgv=ptr_pctgoodrhohvgv, $

    BBPARMS=BBparms, BB_RELATIVE=bb_relative, BBWIDTH=bbwidth, $
    ALT_BB_HGT=alt_bb_hgt, $

   ; appended variables in version 88 matchup file for Ali's phase study
     PTRphase=ptr_phase, PTRAGLphaseHgt=ptr_phaseHeightAGL, $
     PTRNS_phase=ptr_phaseNearSurface )

help, *ptr_geometa, /struct
help, *ptr_sweepmeta, /struct
help, *ptr_sitemeta, /struct
help, *ptr_fieldflags, /struct
help, BBparms, /struct

phase=*ptr_phase
phaseHeightAGL=*ptr_phaseHeightAGL
phaseNearSurface=*ptr_phaseNearSurface

  gvz=*ptr_gvz
  gvzmax=*ptr_gvzmax
  gvzstddev=*ptr_gvzstddev
  gvrr=*ptr_gvrr
  gvrrmax=*ptr_gvrrmax
  gvrrstddev=*ptr_gvrrstddev
  zcor=*ptr_zcor
  zraw=*ptr_zraw
  IF ptr_valid(ptr_dprepsilon) THEN epsilon = *ptr_dprepsilon
  IF ptr_valid(ptr_250zcor) THEN zcor250=*ptr_250zcor
  IF ptr_valid(ptr_250zraw) THEN zraw250=*ptr_250zraw
  IF ptr_valid(ptr_250maxzraw) THEN maxzraw250=*ptr_250maxzraw
  rain3=*ptr_rain3
  pia=*ptr_pia
  dpr_dm=*ptr_dprDm
  dpr_nw=*ptr_dprNw
  top=*ptr_top
  botm=*ptr_botm
  lat=*ptr_lat
  lon=*ptr_lon
  nearSurfRain=*ptr_nearSurfRain
  IF ptr_valid(ptr_nearSurfRain_comb) THEN nearSurfRain_Comb=*ptr_nearSurfRain_Comb
  rnflag=*ptr_rnFlag
  rntype=*ptr_rnType
  landOceanFlag=*ptr_landOcean
  bbStatus=*ptr_bbStatus
  clutterStatus=*ptr_clutterStatus
  bbHeight=*ptr_bbHeight
  pr_index=*ptr_pr_index
  xcorner=*ptr_xCorner
  ycorner=*ptr_yCorner
  bbProx=*ptr_bbProx
  hgtcat=*ptr_hgtcat
  dist=*ptr_dist
  IF ( N_ELEMENTS(pctAbvThresh) EQ 1 ) THEN BEGIN
     pctgoodpr=*ptr_pctgoodpr
     pctgoodgv=*ptr_pctgoodgv
     pctgoodrain=*ptr_pctgoodrain
     pctgoodDprDm=*ptr_pctgoodDprDm
     pctgoodDprNw=*ptr_pctgoodDprNw
     pctgoodrcgv=*ptr_pctgoodrcgv
     pctgoodrpgv=*ptr_pctgoodrpgv
     pctgoodrrgv=*ptr_pctgoodrrgv
     IF ptr_valid(ptr_pctgooddprepsilon) THEN pctgoodepsilon = *ptr_pctgooddprepsilon
     IF ptr_valid(ptr_pctgood250pr) THEN pctgood250pr=*ptr_pctgood250pr
     IF ptr_valid(ptr_pctgood250rawpr) THEN pctgood250rawpr=*ptr_pctgood250rawpr
  ENDIF

help
stop

ptr_free,ptr_geometa
ptr_free,ptr_sweepmeta
ptr_free,ptr_sitemeta
ptr_free,ptr_fieldflags
ptr_free,ptr_gvz
ptr_free,ptr_gvzmax
ptr_free,ptr_gvzstddev
ptr_free,ptr_gvrc
ptr_free,ptr_gvrcmax
ptr_free,ptr_gvrcstddev
ptr_free,ptr_gvrp
ptr_free,ptr_gvrpmax
ptr_free,ptr_gvrpstddev
ptr_free,ptr_gvrr
ptr_free,ptr_gvrrmax
ptr_free,ptr_gvrrstddev
ptr_free,ptr_GR_DP_HID
ptr_free,ptr_mode_HID
ptr_free,ptr_GR_DP_Dzero
ptr_free,ptr_GR_DP_Dzeromax
ptr_free,ptr_GR_DP_Dzerostddev
ptr_free,ptr_GR_DP_Nw
ptr_free,ptr_GR_DP_Nwmax
ptr_free,ptr_GR_DP_Nwstddev
ptr_free,ptr_GR_DP_Dm
ptr_free,ptr_GR_DP_Dmmax
ptr_free,ptr_GR_DP_Dmstddev
ptr_free,ptr_GR_DP_N2
ptr_free,ptr_GR_DP_N2max
ptr_free,ptr_GR_DP_N2stddev
ptr_free,ptr_GR_DP_Zdr
ptr_free,ptr_GR_DP_Zdrmax
ptr_free,ptr_GR_DP_Zdrstddev
ptr_free,ptr_GR_DP_Kdp
ptr_free,ptr_GR_DP_Kdpmax
ptr_free,ptr_GR_DP_Kdpstddev
ptr_free,ptr_GR_DP_RHOhv
ptr_free,ptr_GR_DP_RHOhvmax
ptr_free,ptr_GR_DP_RHOhvstddev
ptr_free,ptr_zcor
ptr_free,ptr_zraw
IF ptr_valid(ptr_250zcor) THEN ptr_free,ptr_250zcor
IF ptr_valid(ptr_250zraw) THEN ptr_free,ptr_250zraw
ptr_free,ptr_rain3
ptr_free,ptr_dprDm
ptr_free,ptr_dprNw
ptr_free,ptr_top
ptr_free,ptr_botm
ptr_free,ptr_lat
ptr_free,ptr_lon
ptr_free,ptr_nearSurfRain
IF ptr_valid(ptr_nearSurfRain_comb) THEN ptr_free, ptr_nearSurfRain_Comb
ptr_free,ptr_rnFlag
ptr_free,ptr_rnType
ptr_free,ptr_landOcean
ptr_free,ptr_pr_index
ptr_free,ptr_xCorner
ptr_free,ptr_yCorner
ptr_free,ptr_bbProx
ptr_free,ptr_bbHeight
ptr_free,ptr_bbstatus
IF ptr_valid(ptr_pia) THEN ptr_free,ptr_pia
IF ptr_valid(ptr_qualityData) THEN ptr_free,ptr_qualityData
ptr_free,ptr_clutterStatus
ptr_free,ptr_hgtcat
ptr_free,ptr_dist
IF ( N_ELEMENTS(pctAbvThresh) EQ 1 ) THEN BEGIN
   ptr_free,ptr_pctgoodpr
   ptr_free,ptr_pctgoodgv
   ptr_free,ptr_pctgoodrain
   ptr_free,ptr_pctgoodDprDm
   ptr_free,ptr_pctgoodDprNw
   ptr_free,ptr_pctgoodrcgv
   ptr_free,ptr_pctgoodrpgv
   ptr_free,ptr_pctgoodrrgv
   ptr_free,ptr_pctgoodhidgv
   ptr_free,ptr_pctgooddzerogv
   ptr_free,ptr_pctgoodnwgv
   ptr_free,ptr_pctgooddmgv
   ptr_free,ptr_pctgoodn2gv
   ptr_free,ptr_pctgoodzdrgv
   ptr_free,ptr_pctgoodkdpgv
   ptr_free,ptr_pctgoodrhohvgv
   IF ptr_valid(ptr_pctgood250pr) THEN ptr_free,ptr_pctgood250pr
   IF ptr_valid(ptr_pctgood250rawpr) THEN ptr_free,ptr_pctgood250rawpr
ENDIF

print
print, 'Done!'

end
