;===============================================================================
;+
; Copyright © 2015, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; test_fprep_dprgmi_geomatch_netcdf.pro     Morris/SAIC/GPM_GV      June 2015
;
; DESCRIPTION
; -----------
; Test driver for function fprep_dprgmi_geo_match_netcdf.pro
;
; HISTORY
; -------
; 12/23/15 by Bob Morris, GPM GV (SAIC)
;  - Added reading of GR_blockage variable for version 1.2 files.
; 01/15/16 by Bob Morris, GPM GV (SAIC)
;  - Added alt_bb_hgt and forcebb parameters to test these options.
;  - Removed call to UNCOMP_FILE, it is duplicated in the fprep routine.
;  - Added RAY_RANGE parameter to test the new option.
; 04/26/16 by Bob Morris, GPM GV (SAIC)
;  - Added DPR Dm (precipTotPSDparamHigh) and Nw (precipTotPSDparamLow) and
;    their percent above threshold values to the parameters read.
; 07/13/16 by Bob Morris, GPM GV (SAIC)
;  - Added GR Dm and Nw and their percent above threshold values to the
;    parameters read.
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;===============================================================================

pro test_fprep_dprgmi_geomatch_netcdf, SCANTYPE=scanTypeIn, KUKA=kuka, $
                                       PCT_ABV_THRESH=pctAbvThresh, $
                                       ALT_BB_HGT=alt_bb_hgt, FORCEBB=forcebb, $
                                       RAY_RANGE=ray_range

@dprgmi_geo_match_nc_structs.inc

IF N_ELEMENTS(scanTypeIn) NE 1 THEN BEGIN
   message, "Reading scanType=NS from DPRGMI matchup file by default.", /INFO
   scanType = 'NS'
ENDIF ELSE BEGIN
   CASE scanTypeIn OF
      'MS' : BEGIN
               scanType = scanTypeIn
               data_ms = 1    ; INITIALIZE AS ANYTHING, WILL BE REDEFINED IN READ
               RAYSPERSCAN = RAYSPERSCAN_MS
             END
      'NS' : BEGIN
               scanType = scanTypeIn
               data_ns = 1    ; INITIALIZE AS ANYTHING, WILL BE REDEFINED IN READ
               RAYSPERSCAN = RAYSPERSCAN_NS
             END
     ELSE : message, "Illegal SCANTYPE parameter, only MS or NS allowed."
   ENDCASE
ENDELSE

if n_elements(mygeomatchfile) eq 0 then begin
   filters = ['GRtoDPRGMI.*']
   mygeomatchfile=dialog_pickfile(FILTER=filters, $
       TITLE='Select GRtoDPRGMI file to read', $
       PATH='/data/gpmgv/netcdf/geo_match/GPM/2BDPRGMI/V04A/1_21/2014')
   IF (mygeomatchfile EQ '') THEN GOTO, errorExit
endif

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
ptr_rain3=ptr_new(/allocate_heap)
ptr_dprDm=ptr_new(/allocate_heap)
ptr_dprNw=ptr_new(/allocate_heap)
ptr_top=ptr_new(/allocate_heap)
ptr_botm=ptr_new(/allocate_heap)
ptr_lat=ptr_new(/allocate_heap)
ptr_lon=ptr_new(/allocate_heap)
ptr_dpr_lat=ptr_new(/allocate_heap)
ptr_dpr_lon=ptr_new(/allocate_heap)
ptr_nearSurfRain=ptr_new(/allocate_heap)
ptr_rnType=ptr_new(/allocate_heap)
ptr_landOcean=ptr_new(/allocate_heap)
ptr_pr_index=ptr_new(/allocate_heap)
ptr_xCorner=ptr_new(/allocate_heap)
ptr_yCorner=ptr_new(/allocate_heap)
ptr_bbProx=ptr_new(/allocate_heap)
ptr_clutterStatus=ptr_new(/allocate_heap)
ptr_hgtcat=ptr_new(/allocate_heap)
ptr_dist=ptr_new(/allocate_heap)
IF ( N_ELEMENTS(pctAbvThresh) EQ 1 ) THEN BEGIN
   ptr_pctgoodpr=ptr_new(/allocate_heap)
   ptr_pctgoodgv=ptr_new(/allocate_heap)
   ptr_pctgoodrain=ptr_new(/allocate_heap)
   ptr_pctgoodDprDm=ptr_new(/allocate_heap)
   ptr_pctgoodDprNw=ptr_new(/allocate_heap)
   ptr_pctgoodrcgv=ptr_new(/allocate_heap)
   ptr_pctgoodrpgv=ptr_new(/allocate_heap)
   ptr_pctgoodrrgv=ptr_new(/allocate_heap)
   ptr_pctgoodhidgv=ptr_new(/allocate_heap)
   ptr_pctgooddzerogv=ptr_new(/allocate_heap)
   ptr_pctgoodnwgv=ptr_new(/allocate_heap)
   ptr_pctgoodDmgv=ptr_new(/allocate_heap)
   ptr_pctgoodN2gv=ptr_new(/allocate_heap)
   ptr_pctgoodzdrgv=ptr_new(/allocate_heap)
   ptr_pctgoodkdpgv=ptr_new(/allocate_heap)
   ptr_pctgoodrhohvgv=ptr_new(/allocate_heap)
ENDIF
;meanBB = -99.99
BBparms = {meanBB : -99.99, BB_HgtLo : -99, BB_HgtHi : -99}
heights = [1.5,3.0,4.5,6.0,7.5,9.0,10.5,12.0,13.5,15.0,16.5,18.0,19.5]

  status = 1   ; init to FAILED

  status = fprep_dprgmi_geo_match_profiles( mygeomatchfile, heights, KUKA=kuka, $
    SCANTYPE=scanType, PCT_ABV_THRESH=pctAbvThresh, GV_CONVECTIVE=gvconvective, $
    GV_STRATIFORM=gvstratiform, S2KU=s2ku, PTRgeometa=ptr_geometa, $
    PTRsweepmeta=ptr_sweepmeta, PTRsitemeta=ptr_sitemeta, $
    PTRfieldflags=ptr_fieldflags, PTRfilesmeta=ptr_filesmeta,  $
     
   ; ground radar variables
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

   ; space radar variables
    PTRzcor=ptr_zcor, PTRprlat=ptr_dpr_lat, PTRprlon=ptr_dpr_lon, $
    PTRdprdm=ptr_dprDm, PTRdprnw=ptr_dprNw, $
    PTRpia=ptr_pia, PTRrain3d=ptr_rain3, PTRsfcrainpr=ptr_nearSurfRain, $
    PTRraintype_int=ptr_rnType, $
    PTRlandOcean_int=ptr_landOcean, PTRpridx_long=ptr_pr_index, $

   ; derived/computed variables
    PTRtop=ptr_top, PTRbotm=ptr_botm, PTRlat=ptr_lat, PTRlon=ptr_lon, $
    PTRxCorners=ptr_xCorner, PTRyCorners=ptr_yCorner, PTRbbProx=ptr_bbProx, $
;    PTRclutterStatus=ptr_clutterStatus,
    PTRhgtcat=ptr_hgtcat, PTRdist=ptr_dist, $

   ; percent above threshold parameters
    PTRpctgoodpr=ptr_pctgoodpr, PTRpctgoodrain=ptr_pctgoodrain, $
    PTRpctgoodDprDm=ptr_pctgoodDprDm, PTRpctgoodDprNw=ptr_pctgoodDprNw, $
    PTRpctgoodgv=ptr_pctgoodgv, PTRpctgoodrcgv=ptr_pctgoodrcgv, $
    PTRpctgoodrpgv=ptr_pctgoodrpgv, PTRpctgoodrrgv=ptr_pctgoodrrgv, $
    PTRpctgoodhidgv=ptr_pctgoodhidgv, PTRpctgooddzerogv=ptr_pctgooddzerogv, $
    PTRpctgoodnwgv=ptr_pctgoodnwgv, PTRpctgooddmgv=ptr_pctgooddmgv, $
    PTRpctgoodn2gv=ptr_pctgoodn2gv, PTRpctgoodzdrgv=ptr_pctgoodzdrgv, $
    PTRpctgoodkdpgv=ptr_pctgoodkdpgv, PTRpctgoodrhohvgv=ptr_pctgoodrhohvgv, $

   ; Bright Band structure, control parameters
    BBPARMS=bbparms, BB_RELATIVE=bb_relative, BBWIDTH=bbwidth, $
    ALT_BB_HGT=alt_bb_hgt, FORCEBB=forcebb, RAY_RANGE=ray_range )

if ( status NE 0 ) THEN GOTO, errorExit

print, ''
help, *ptr_geometa, /struct
print, ''

print, *ptr_geometa
print, *ptr_sweepmeta
print, *ptr_sitemeta
print, *ptr_fieldflags
print, *ptr_filesmeta
print, BBparms
STOP

  gvz=*ptr_gvz
  gvzmax=*ptr_gvzmax
  gvzstddev=*ptr_gvzstddev
  gvrr=*ptr_gvrr
  gvrrmax=*ptr_gvrrmax
  gvrrstddev=*ptr_gvrrstddev
  zcor=*ptr_zcor
  rain3=*ptr_rain3
  dprdm=*ptr_dprDm
  dprnw=*ptr_dprNw
  top=*ptr_top
  botm=*ptr_botm
  lat=*ptr_lat
  lon=*ptr_lon
  nearSurfRain=*ptr_nearSurfRain
  rntype=*ptr_rnType
  landOceanFlag=*ptr_landOcean
;  clutterStatus=*ptr_clutterStatus
  pr_index=*ptr_pr_index
  xcorner=*ptr_xCorner
  ycorner=*ptr_yCorner
  bbProx=*ptr_bbProx
  hgtcat=*ptr_hgtcat
  dist=*ptr_dist
  IF ( N_ELEMENTS(pctAbvThresh) EQ 1 ) THEN BEGIN
     pctgoodpr=*ptr_pctgoodpr
     pctgoodDprDm=*ptr_pctgoodDprDm
     pctgoodDprNw=*ptr_pctgoodDprNw
     pctgoodgv=*ptr_pctgoodgv
     pctgoodrain=*ptr_pctgoodrain
     pctgoodrcgv=*ptr_pctgoodrcgv
     pctgoodrpgv=*ptr_pctgoodrpgv
     pctgoodrrgv=*ptr_pctgoodrrgv
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
ptr_free,ptr_GR_DP_Zdr
ptr_free,ptr_GR_DP_Zdrmax
ptr_free,ptr_GR_DP_Zdrstddev
ptr_free,ptr_GR_DP_Kdp
ptr_free,ptr_GR_DP_Kdpmax
ptr_free,ptr_GR_DP_Kdpstddev
ptr_free,ptr_GR_DP_RHOhv
ptr_free,ptr_GR_DP_RHOhvmax
ptr_free,ptr_GR_DP_RHOhvstddev
; version-dependent pointers
if ptr_valid(ptr_GR_DP_Dm) then ptr_free,ptr_GR_DP_Dm
if ptr_valid(ptr_GR_DP_Dmmax) then ptr_free,ptr_GR_DP_Dmmax
if ptr_valid(ptr_GR_DP_Dmstddev) then ptr_free,ptr_GR_DP_Dmstddev
if ptr_valid(ptr_GR_DP_N2) then ptr_free,ptr_GR_DP_N2
if ptr_valid(ptr_GR_DP_N2max) then ptr_free,ptr_GR_DP_N2max
if ptr_valid(ptr_GR_DP_N2stddev) then ptr_free,ptr_GR_DP_N2stddev
if ptr_valid(ptr_GR_blockage) then ptr_free,ptr_GR_blockage
ptr_free,ptr_zcor
ptr_free,ptr_dprDm
ptr_free,ptr_dprNw
ptr_free,ptr_top
ptr_free,ptr_botm
ptr_free,ptr_lat
ptr_free,ptr_lon
ptr_free,ptr_nearSurfRain
ptr_free,ptr_rnType
ptr_free,ptr_landOcean
ptr_free,ptr_pr_index
ptr_free,ptr_xCorner
ptr_free,ptr_yCorner
ptr_free,ptr_bbProx
ptr_free,ptr_clutterStatus
ptr_free,ptr_hgtcat
ptr_free,ptr_dist
IF ( N_ELEMENTS(pctAbvThresh) EQ 1 ) THEN BEGIN
   ptr_free,ptr_pctgoodpr
   ptr_free,ptr_pctgoodDprDm
   ptr_free,ptr_pctgoodDprNw
   ptr_free,ptr_pctgoodgv
   ptr_free,ptr_pctgoodrcgv
   ptr_free,ptr_pctgoodrpgv
   ptr_free,ptr_pctgoodrrgv
   ptr_free,ptr_pctgoodhidgv
   ptr_free,ptr_pctgooddzerogv
   ptr_free,ptr_pctgoodnwgv
   ptr_free,ptr_pctgoodzdrgv
   ptr_free,ptr_pctgoodkdpgv
   ptr_free,ptr_pctgoodrhohvgv
  ; version-dependent pointers
   if ptr_valid(ptr_pctgooddmgv) then ptr_free,ptr_pctgooddmgv
   if ptr_valid(ptr_pctgoodn2gv) then ptr_free,ptr_pctgoodn2gv
ENDIF


errorExit:
END
