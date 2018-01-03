; Driver program to demonstrate the useage of fprep_geo_match_profiles.pro
; in reading and praparing data from a GR-PR geometry match netCDF file for
; subsequent analysis, display, etc.
;
; HISTORY
; -------
; 02/11/15  Morris/GPM GV/SAIC
; - Modified to read PIA, where present.

PRO test_fprep_geo_match_profiles, NCPATH=ncpath, SITE=sitefilter, $
                                   PCT_ABV_THRESH=pctAbvThresh,    $
                                   GV_CONVECTIVE=gvconvective,     $
                                   GV_STRATIFORM=gvstratiform, S2KU = s2ku

IF ( N_ELEMENTS(ncpath) NE 1 ) THEN BEGIN
   print, "Defaulting to /data/gpmgv/netcdf/geo_match for file path."
   pathpr = '/data/gpmgv/netcdf/geo_match'
ENDIF ELSE pathpr = ncpath

IF ( N_ELEMENTS(sitefilter) NE 1 ) THEN BEGIN
   print, "Defaulting to GRtoPR* for file pattern."
   ncfilepatt = 'GRtoPR.*'
ENDIF ELSE ncfilepatt = '*'+sitefilter+'*'
ncfilepr = dialog_pickfile(path=pathpr, filter = ncfilepatt)

; define unassigned pointers for all variables/structures we want to read from
; the netCDF file

ptr_geometa=ptr_new(/allocate_heap)
ptr_sweepmeta=ptr_new(/allocate_heap)
ptr_sitemeta=ptr_new(/allocate_heap)
ptr_fieldflags=ptr_new(/allocate_heap)
ptr_filesmeta=ptr_new(/allocate_heap)

ptr_gvz=ptr_new(/allocate_heap)
ptr_gvzmax=ptr_new(/allocate_heap)
ptr_gvzstddev=ptr_new(/allocate_heap)
ptr_gvrr=ptr_new(/allocate_heap)
ptr_gvrrmax=ptr_new(/allocate_heap)
ptr_gvrrstddev=ptr_new(/allocate_heap)
ptr_GR_DP_HID=ptr_new(/allocate_heap)
ptr_mode_HID=ptr_new(/allocate_heap)
ptr_GR_DP_Dzero=ptr_new(/allocate_heap)
ptr_GR_DP_DzeroMax=ptr_new(/allocate_heap)
ptr_GR_DP_DzeroStdDev=ptr_new(/allocate_heap)
ptr_GR_DP_Nw=ptr_new(/allocate_heap)
ptr_GR_DP_NwMax=ptr_new(/allocate_heap)
ptr_GR_DP_NwStdDev=ptr_new(/allocate_heap)
ptr_GR_DP_Zdr=ptr_new(/allocate_heap)
ptr_GR_DP_ZdrMax=ptr_new(/allocate_heap)
ptr_GR_DP_ZdrStdDev=ptr_new(/allocate_heap)
ptr_GR_DP_Kdp=ptr_new(/allocate_heap)
ptr_GR_DP_KdpMax=ptr_new(/allocate_heap)
ptr_GR_DP_KdpStdDev=ptr_new(/allocate_heap)
ptr_GR_DP_RHOhv=ptr_new(/allocate_heap)
ptr_GR_DP_RHOhvMax=ptr_new(/allocate_heap)
ptr_GR_DP_RHOhvStdDev=ptr_new(/allocate_heap)

ptr_zcor=ptr_new(/allocate_heap)
ptr_zraw=ptr_new(/allocate_heap)
ptr_rain3=ptr_new(/allocate_heap)
ptr_pr_lat=ptr_new(/allocate_heap)
ptr_pr_lon=ptr_new(/allocate_heap)
ptr_nearSurfRain=ptr_new(/allocate_heap)
ptr_nearSurfRain_2b31=ptr_new(/allocate_heap)
ptr_rnFlag=ptr_new(/allocate_heap)
ptr_rnType=ptr_new(/allocate_heap)
ptr_landOcean=ptr_new(/allocate_heap)
ptr_pr_index=ptr_new(/allocate_heap)
ptr_status_2a23=ptr_new(/allocate_heap)
ptr_bbstatus=ptr_new(/allocate_heap)
ptr_pia=ptr_new(/allocate_heap)

ptr_top=ptr_new(/allocate_heap)
ptr_botm=ptr_new(/allocate_heap)
ptr_lat=ptr_new(/allocate_heap)
ptr_lon=ptr_new(/allocate_heap)
ptr_xCorner=ptr_new(/allocate_heap)
ptr_yCorner=ptr_new(/allocate_heap)
ptr_bbProx=ptr_new(/allocate_heap)
ptr_bbHeight=ptr_new(/allocate_heap)
ptr_hgtcat=ptr_new(/allocate_heap)
ptr_dist=ptr_new(/allocate_heap)
IF ( N_ELEMENTS(pctAbvThresh) EQ 1 ) THEN BEGIN
   ptr_pctgoodpr=ptr_new(/allocate_heap)
   ptr_pctgoodgv=ptr_new(/allocate_heap)
   ptr_pctgoodrain=ptr_new(/allocate_heap)
   ptr_pctgoodrrgv=ptr_new(/allocate_heap)
   ptr_pctgoodhidgv=ptr_new(/allocate_heap)
   ptr_pctgooddzerogv=ptr_new(/allocate_heap)
   ptr_pctgoodnwgv=ptr_new(/allocate_heap)
   ptr_pctgoodZdrgv=ptr_new(/allocate_heap)
   ptr_pctgoodKdpgv=ptr_new(/allocate_heap)
   ptr_pctgoodRHOhvgv=ptr_new(/allocate_heap)
ENDIF

; define the "empty" BBparms structure, the only parameter not passed/returned
; as a pointer
BBparms = {meanBB : -99.99, BB_HgtLo : -99, BB_HgtHi : -99}

; define the array of fixed heights that we want the samples to be associated
; to for things like plotting mean vertical profiles
; -- Does NOT group samples into height levels, just assigns the index of the
;    nearest fixed height level to each sample so that CALLER can group the data
;    using the values returned in ptr_hgtcat
heights = [1.5,3.0,4.5,6.0,7.5,9.0,10.5,12.0,13.5,15.0,16.5,18.0,19.5]

; read the variables in the file, compute the requested derived parameters, and
; return pointers to the data read/computed
status = fprep_geo_match_profiles( ncfilepr, heights, $
    PCT_ABV_THRESH=pctAbvThresh, GV_CONVECTIVE=gvconvective, $
    GV_STRATIFORM=gvstratiform, S2KU=s2ku, PTRgeometa=ptr_geometa, $
    PTRsweepmeta=ptr_sweepmeta, PTRsitemeta=ptr_sitemeta, $
    PTRfieldflags=ptr_fieldflags, PTRfilesmeta=ptr_filesmeta, $

    PTRGVZMEAN=ptr_gvz, PTRGVMAX=ptr_gvzmax, PTRGVSTDDEV=ptr_gvzstddev, $
    PTRGVRRMEAN=ptr_gvrr, PTRGVRRMAX=ptr_gvrrmax, PTRGVRRSTDDEV=ptr_gvrrstddev, $
    PTRGVHID=ptr_GR_DP_HID, PTRGVDZEROMEAN=ptr_GR_DP_Dzero, $
    PTRGVDZEROMAX=ptr_GR_DP_Dzeromax, PTRGVDZEROSTDDEV=ptr_GR_DP_Dzerostddev, $
    PTRGVNWMEAN=ptr_GR_DP_Nw, PTRGVNWMAX=ptr_GR_DP_Nwmax, $
    PTRGVNWSTDDEV=ptr_GR_DP_Nwstddev, PTRGVZDRMEAN=ptr_GR_DP_Zdr, $
    PTRGVZDRMAX=ptr_GR_DP_Zdrmax, PTRGVZDRSTDDEV=ptr_GR_DP_Zdrstddev, $
    PTRGVKDPMEAN=ptr_GR_DP_Kdp, PTRGVKDPMAX=ptr_GR_DP_Kdpmax, $
    PTRGVKDPSTDDEV=ptr_GR_DP_Kdpstddev, PTRGVRHOHVMEAN=ptr_GR_DP_RHOhv, $
    PTRGVRHOHVMAX=ptr_GR_DP_RHOhvmax, PTRGVRHOHVSTDDEV=ptr_GR_DP_RHOhvstddev, $
    PTRGVMODEHID=ptr_mode_HID, $

    PTRzcor=ptr_zcor, PTRzraw=ptr_zraw, PTRrain3d=ptr_rain3, $
    PTRprlat=ptr_pr_lat, PTRprlon=ptr_pr_lon, PTRpia=ptr_pia, $
    PTRsfcrainpr=ptr_nearSurfRain, PTRsfcraincomb=ptr_nearSurfRain_2b31, $
    PTRrainflag_int=ptr_rnFlag, PTRraintype_int=ptr_rnType, $
    PTRlandOcean_int=ptr_landOcean, PTRpridx_long=ptr_pr_index, $
    PTRstatus2A23=ptr_status_2a23, PTRbbStatus=ptr_bbstatus, $

    PTRtop=ptr_top, PTRbotm=ptr_botm, PTRlat=ptr_lat, PTRlon=ptr_lon, $
    PTRxCorners=ptr_xCorner, PTRyCorners=ptr_yCorner, PTRbbProx=ptr_bbProx, $
    PTRbbHgt=ptr_bbHeight, PTRhgtcat=ptr_hgtcat, PTRdist=ptr_dist, $

    PTRpctgoodpr=ptr_pctgoodpr, PTRpctgoodrain=ptr_pctgoodrain, $
    PTRpctgoodgv=ptr_pctgoodgv, PTRpctgoodrrgv=ptr_pctgoodrrgv, $
    PTRpctgoodhidgv=ptr_pctgoodhidgv, PTRpctgooddzerogv=ptr_pctgooddzerogv, $
    PTRpctgoodnwgv=ptr_pctgoodnwgv, PTRpctgoodzdrgv=ptr_pctgoodzdrgv, $
    PTRpctgoodkdpgv=ptr_pctgoodkdpgv, PTRpctgoodrhohvgv=ptr_pctgoodrhohvgv, $
    BBPARMS=BBparms )

print, ""
print, ""
print, "Dumping the values of all the structure variables to the screen:"
print, *ptr_geometa
print, *ptr_sweepmeta
print, *ptr_sitemeta
print, *ptr_fieldflags
print, *ptr_filesmeta
print, BBparms
print, ""

; here is an example of how to read a top-level structure element from a
; pointer-to-struct, note the parentheses:
print, ""
print, "Reading/writing out the values of specific structure variables:"
print, "Time of nearest approach: ", (*ptr_geometa).atimeNearestApproach

; contrast that with reading a structure variable from a regular (non-pointer)
; structure variable:
print, "Mean BB height (km): ", BBparms.meanBB
print, ""

; here we just dereference the full arrays for the data-array pointer variables, 
; i.e., we make a simple variable out of them.  This doubles the amount of
; storage needed for the variable until we "free" the pointer at the end of this
; test routine, but it shows you how to use the pointer data returned from the
; fprep_geo_match_profiles() function with existing code that expects simple
; variables throughout

  gvz=*ptr_gvz
  IF PTR_VALID(ptr_gvzmax) THEN gvzmax=*ptr_gvzmax $
     ELSE print, "gvzmax not available in version ", (*ptr_geometa).nc_file_version
  IF PTR_VALID(ptr_gvzstddev) THEN gvzstddev=*ptr_gvzstddev $
     ELSE print, "gvzstddev not available in version ", (*ptr_geometa).nc_file_version
  IF PTR_VALID(ptr_gvrr) THEN gvrr=*ptr_gvrr $
     ELSE print, "gvrr not available in version ", (*ptr_geometa).nc_file_version
  IF PTR_VALID(ptr_gvrrmax) THEN gvrrmax=*ptr_gvrrmax $
     ELSE print, "gvrrmax not available in version ", (*ptr_geometa).nc_file_version
  IF PTR_VALID(ptr_gvrrstddev) THEN gvrrstddev=*ptr_gvrrstddev $
     ELSE print, "gvrrstddev not available in version ", (*ptr_geometa).nc_file_version
  IF PTR_VALID(ptr_GR_DP_HID) THEN GR_DP_HID=*ptr_GR_DP_HID $
     ELSE print, "GR_DP_HID not available in version ", (*ptr_geometa).nc_file_version
  IF PTR_VALID(ptr_mode_HID) THEN mode_HID=*ptr_mode_HID $
     ELSE print, "mode_HID not available in version ", (*ptr_geometa).nc_file_version
  IF PTR_VALID(ptr_GR_DP_Dzero) THEN GR_DP_Dzero=*ptr_GR_DP_Dzero $
     ELSE print, "GR_DP_Dzero not available in version ", (*ptr_geometa).nc_file_version
  IF PTR_VALID(ptr_GR_DP_DzeroMax) THEN GR_DP_DzeroMax=*ptr_GR_DP_DzeroMax $
     ELSE print, "GR_DP_DzeroMax not available in version ", (*ptr_geometa).nc_file_version
  IF PTR_VALID(ptr_GR_DP_DzeroStdDev) THEN GR_DP_DzeroStdDev=*ptr_GR_DP_DzeroStdDev $
     ELSE print, "GR_DP_DzeroStdDev not available in version ", (*ptr_geometa).nc_file_version
  IF PTR_VALID(ptr_GR_DP_Nw) THEN GR_DP_Nw=*ptr_GR_DP_Nw $
     ELSE print, "GR_DP_Nw not available in version ", (*ptr_geometa).nc_file_version
  IF PTR_VALID(ptr_GR_DP_NwMax) THEN GR_DP_NwMax=*ptr_GR_DP_NwMax $
     ELSE print, "GR_DP_NwMax not available in version ", (*ptr_geometa).nc_file_version
  IF PTR_VALID(ptr_GR_DP_NwStdDev) THEN GR_DP_NwStdDev=*ptr_GR_DP_NwStdDev $
     ELSE print, "GR_DP_NwStdDev not available in version ", (*ptr_geometa).nc_file_version
  IF PTR_VALID(ptr_GR_DP_Zdr) THEN GR_DP_Zdr=*ptr_GR_DP_Zdr $
     ELSE print, "GR_DP_Zdr not available in version ", (*ptr_geometa).nc_file_version
  IF PTR_VALID(ptr_GR_DP_ZdrMax) THEN GR_DP_ZdrMax=*ptr_GR_DP_ZdrMax $
     ELSE print, "GR_DP_ZdrMax not available in version ", (*ptr_geometa).nc_file_version
  IF PTR_VALID(ptr_GR_DP_ZdrStdDev) THEN GR_DP_ZdrStdDev=*ptr_GR_DP_ZdrStdDev $
     ELSE print, "GR_DP_ZdrStdDev not available in version ", (*ptr_geometa).nc_file_version
  IF PTR_VALID(ptr_GR_DP_Kdp) THEN GR_DP_Kdp=*ptr_GR_DP_Kdp $
     ELSE print, "GR_DP_Kdp not available in version ", (*ptr_geometa).nc_file_version
  IF PTR_VALID(ptr_GR_DP_KdpMax) THEN GR_DP_KdpMax=*ptr_GR_DP_KdpMax $
     ELSE print, "GR_DP_KdpMax not available in version ", (*ptr_geometa).nc_file_version
  IF PTR_VALID(ptr_GR_DP_KdpStdDev) THEN GR_DP_KdpStdDev=*ptr_GR_DP_KdpStdDev $
     ELSE print, "GR_DP_KdpStdDev not available in version ", (*ptr_geometa).nc_file_version
  IF PTR_VALID(ptr_GR_DP_RHOhv) THEN GR_DP_RHOhv=*ptr_GR_DP_RHOhv $
     ELSE print, "GR_DP_RHOhv not available in version ", (*ptr_geometa).nc_file_version
  IF PTR_VALID(ptr_GR_DP_RHOhvMax) THEN GR_DP_RHOhvMax=*ptr_GR_DP_RHOhvMax $
     ELSE print, "GR_DP_RHOhvMax not available in version ", (*ptr_geometa).nc_file_version
  IF PTR_VALID(ptr_GR_DP_RHOhvStdDev) THEN GR_DP_RHOhvStdDev=*ptr_GR_DP_RHOhvStdDev $
     ELSE print, "GR_DP_RHOhvStdDev not available in version ", (*ptr_geometa).nc_file_version
  IF PTR_VALID(ptr_pia) THEN pia=*ptr_pia $
     ELSE print, "PIA not available in version ", (*ptr_geometa).nc_file_version

  zcor=*ptr_zcor
  zraw=*ptr_zraw
  rain3=*ptr_rain3
  pr_lat=*ptr_pr_lat
  pr_lon=*ptr_pr_lon
  nearSurfRain=*ptr_nearSurfRain
  nearSurfRain_2b31=*ptr_nearSurfRain_2b31
  rnflag=*ptr_rnFlag
  rntype=*ptr_rnType
  landOcean=*ptr_landOcean
  pr_index=*ptr_pr_index
  status_2a23=*ptr_status_2a23
  bbstatus=*ptr_bbstatus

  top=*ptr_top
  botm=*ptr_botm
  lat=*ptr_lat
  lon=*ptr_lon
  xcorner=*ptr_xCorner
  ycorner=*ptr_yCorner
  bbProx=*ptr_bbProx
  bbHeight=*ptr_bbHeight
  hgtcat=*ptr_hgtcat
  dist=*ptr_dist

  IF ( N_ELEMENTS(pctAbvThresh) EQ 1 ) THEN BEGIN
     pctgoodpr=*ptr_pctgoodpr
     pctgoodgv=*ptr_pctgoodgv
     pctgoodrain=*ptr_pctgoodrain
     IF PTR_VALID(ptr_pctgoodrrgv) THEN pctgoodrrgv=*ptr_pctgoodrrgv $
     ELSE print, "pctgoodrrgv not available in version ", (*ptr_geometa).nc_file_version
     IF PTR_VALID(ptr_pctgoodhidgv) THEN pctgoodhidgv=*ptr_pctgoodhidgv $
     ELSE print, "pctgoodhidgv not available in version ", (*ptr_geometa).nc_file_version
     IF PTR_VALID(ptr_pctgooddzerogv) THEN pctgooddzerogv=*ptr_pctgooddzerogv $
     ELSE print, "pctgooddzerogv not available in version ", (*ptr_geometa).nc_file_version
     IF PTR_VALID(ptr_pctgoodnwgv) THEN pctgoodnwgv=*ptr_pctgoodnwgv $
     ELSE print, "pctgoodnwgv not available in version ", (*ptr_geometa).nc_file_version
     IF PTR_VALID(ptr_pctgoodzdrgv) THEN pctgoodzdrgv=*ptr_pctgoodzdrgv $
     ELSE print, "pctgoodzdrgv not available in version ", (*ptr_geometa).nc_file_version
     IF PTR_VALID(ptr_pctgoodkdpgv) THEN pctgoodkdpgv=*ptr_pctgoodkdpgv $
     ELSE print, "pctgoodkdpgv not available in version ", (*ptr_geometa).nc_file_version
     IF PTR_VALID(ptr_pctgoodRHOhvgv) THEN pctgoodRHOhvgv=*ptr_pctgoodRHOhvgv $
     ELSE print, "pctgoodRHOhvgv not available in version ", (*ptr_geometa).nc_file_version
  ENDIF

; dump a list of all defined variables to the screen
help

print, ""
;print, "Type .continue from the command line to run to the end of the routine"
;print, "and free the storage allocated for the pointer variables:"
print, ""

stop, "Pausing program mid-stream to let you mess with the variables."+ $
      "  Type .continue when done to finish the run."

ptr_free,ptr_geometa
ptr_free,ptr_sweepmeta
ptr_free,ptr_sitemeta
ptr_free,ptr_fieldflags
ptr_free,ptr_filesmeta

ptr_free,ptr_gvz
IF PTR_VALID(ptr_gvzmax) THEN ptr_free,ptr_gvzmax
IF PTR_VALID(ptr_gvzstddev) THEN ptr_free,ptr_gvzstddev
IF PTR_VALID(ptr_gvrr) THEN ptr_free,ptr_gvrr
IF PTR_VALID(ptr_gvrrmax) THEN ptr_free,ptr_gvrrmax
IF PTR_VALID(ptr_gvrrstddev) THEN ptr_free,ptr_gvrrstddev
IF PTR_VALID(ptr_GR_DP_HID) THEN ptr_free,ptr_GR_DP_HID
IF PTR_VALID(ptr_mode_HID) THEN ptr_free,ptr_mode_HID
IF PTR_VALID(ptr_GR_DP_Dzero) THEN ptr_free,ptr_GR_DP_Dzero
IF PTR_VALID(ptr_GR_DP_Dzeromax) THEN ptr_free,ptr_GR_DP_Dzeromax
IF PTR_VALID(ptr_GR_DP_Dzerostddev) THEN ptr_free,ptr_GR_DP_Dzerostddev
IF PTR_VALID(ptr_GR_DP_Nw) THEN ptr_free,ptr_GR_DP_Nw
IF PTR_VALID(ptr_GR_DP_Nwmax) THEN ptr_free,ptr_GR_DP_Nwmax
IF PTR_VALID(ptr_GR_DP_Nwstddev) THEN ptr_free,ptr_GR_DP_Nwstddev
IF PTR_VALID(ptr_GR_DP_Kdp) THEN ptr_free,ptr_GR_DP_Kdp
IF PTR_VALID(ptr_GR_DP_Kdpmax) THEN ptr_free,ptr_GR_DP_Kdpmax
IF PTR_VALID(ptr_GR_DP_Kdpstddev) THEN ptr_free,ptr_GR_DP_Kdpstddev
IF PTR_VALID(ptr_GR_DP_Zdr) THEN ptr_free,ptr_GR_DP_Zdr
IF PTR_VALID(ptr_GR_DP_Zdrmax) THEN ptr_free,ptr_GR_DP_Zdrmax
IF PTR_VALID(ptr_GR_DP_Zdrstddev) THEN ptr_free,ptr_GR_DP_Zdrstddev
IF PTR_VALID(ptr_GR_DP_RHOhv) THEN ptr_free,ptr_GR_DP_RHOhv
IF PTR_VALID(ptr_GR_DP_RHOhvmax) THEN ptr_free,ptr_GR_DP_RHOhvmax
IF PTR_VALID(ptr_GR_DP_RHOhvstddev) THEN ptr_free,ptr_GR_DP_RHOhvstddev
IF PTR_VALID(ptr_pia) THEN ptr_free,ptr_pia

ptr_free,ptr_zcor
ptr_free,ptr_zraw
ptr_free,ptr_rain3
ptr_free,ptr_nearSurfRain
ptr_free,ptr_nearSurfRain_2b31
ptr_free,ptr_rnFlag
ptr_free,ptr_rnType
ptr_free,ptr_landOcean
ptr_free,ptr_pr_index
ptr_free,ptr_status_2a23
ptr_free,ptr_bbstatus

ptr_free,ptr_top
ptr_free,ptr_botm
ptr_free,ptr_lat
ptr_free,ptr_lon
ptr_free,ptr_xCorner
ptr_free,ptr_yCorner
ptr_free,ptr_bbProx
ptr_free,ptr_bbHeight
ptr_free,ptr_hgtcat
ptr_free,ptr_dist

IF ( N_ELEMENTS(pctAbvThresh) EQ 1 ) THEN BEGIN
   ptr_free,ptr_pctgoodpr
   ptr_free,ptr_pctgoodgv
   ptr_free,ptr_pctgoodrain
   IF PTR_VALID(ptr_pctgoodrrgv) THEN ptr_free,ptr_pctgoodrrgv
   IF PTR_VALID(ptr_pctgoodhidgv) THEN ptr_free,ptr_pctgoodhidgv
   IF PTR_VALID(ptr_pctgooddzerogv) THEN ptr_free,ptr_pctgooddzerogv
   IF PTR_VALID(ptr_pctgoodnwgv) THEN ptr_free,ptr_pctgoodnwgv
ENDIF

print
print, 'Done!'

end
