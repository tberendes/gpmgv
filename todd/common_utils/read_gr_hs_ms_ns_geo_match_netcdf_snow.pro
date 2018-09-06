;===============================================================================
;+
; Copyright © 2016, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; read_gr_hs_ms_ns_geo_match_netcdf_snow.pro        Morris/SAIC/GPM_GV      Feb 2016
;
; DESCRIPTION
; -----------
; Reads science data and metadata from GR->DPR matchup netCDF files. 
; Returns status value: 0 if successful read, 1 if unsuccessful or internal
; errors or inconsistencies occur.  File must be read-ready (unzipped/
; uncompressed) before calling this function.
;
; Data are expected to be in ascending order in the elevation angle dimension,
; and are not resorted.  If not in order, then a fatal error message is sent.
;
; PARAMETERS
; ----------
; ncfile               STRING, Full file pathname to the netCDF file (Input)
;
; matchupmeta          Structure holding general and algorithmic parameters (I/O)
; sweepsmeta           Array of Structures holding sweep elevation angles,
;                      and sweep start times in unix ticks and ascii text (I/O)
; sitemeta             Structure holding GV site location parameters (I/O)
; fieldFlags           Structure holding "data exists" flags for GR science
;                        data variables (I/O)
; filesmeta            Structure holding DPR and GR file names used in matchup (I/O)
;                      -- See file geo_match_nc_structs.inc for definition of
;                         the above structures.  These structures must be
;                         instantiated by the calling program and provided as 
;                         keyword parameters in the call to this routine.
;
; data_HS              Structure containing all the DPR-matched GR data variables
;                      for the HS swath.  Structure is defined and created in this
;                      routine, replacing the input parameter value.
; data_MS              Structure containing all the DPR-matched GR data variables
;                      for the MS swath.  Structure is defined and created in this
;                      routine, replacing the input parameter value.
; data_NS              Structure containing all the DPR-matched GR data variables
;                      for the NS swath.  Structure is defined and created in this
;                      routine, replacing the input parameter value.
;                      -- The parameter values data_HS, data_MS, and data_NS
;                         must be non-null in the call this this function if
;                         their corresponding data structure is to be returned,
;                         otherwise data for the swath are read and discarded.
;
; RETURNS
; -------
; status               INT - Status of call to function, 0=success, 1=failure
;
; HISTORY
; -------
; 02/29/2016  Morris/SAIC/GPM-GV
; - Created from read_dprgmi_geo_match_netcdf.pro.
;
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;===============================================================================

FUNCTION read_gr_hs_ms_ns_geo_match_netcdf_snow, ncfile, matchupmeta=matchupmeta, $
    sweepsmeta=sweepsmeta, sitemeta=sitemeta, fieldflags=fieldFlags, $
    filesmeta=filesmeta, DATA_HS=data_HS, DATA_MS=data_MS, DATA_NS=data_NS

; "Include" file for DPR-product-specific parameters (i.e., RAYSPERSCAN):
@dpr_params.inc

status = 0

ncid1 = NCDF_OPEN( ncfile )
IF ( N_Elements(ncid1) EQ 0 ) THEN BEGIN
   print, ''
   print, "ERROR from read_gr_hs_ms_ns_geo_match_netcdf:"
   print, "File copy ", ncfile, " is not a valid netCDF file!"
   print, ''
   status = 1
   goto, ErrorExit
ENDIF

; determine the number of global attributes and check the name of the first one
; to verify that we have the correct type of file
attstruc=ncdf_inquire(ncid1)
IF ( attstruc.ngatts GT 0 ) THEN BEGIN
   typeversion = ncdf_attname(ncid1, 0, /global)
   IF ( typeversion NE 'DPR_Version' ) THEN BEGIN
      print, ''
      print, "ERROR from read_gr_hs_ms_ns_geo_match_netcdf:"
      print, "File copy ", ncfile, " is not a GR-DPR matchup file!"
      print, ''
      status = 1
      goto, ErrorExit
   ENDIF
ENDIF ELSE BEGIN
   print, ''
   print, "ERROR from read_gr_hs_ms_ns_geo_match_netcdf:"
   print, "File copy ", ncfile, " has no global attributes!"
   print, ''
   status = 1
   goto, ErrorExit
ENDELSE

; always determine the version of the matchup netCDF file first -- determines
; which variables can be retrieved
versid = NCDF_VARID(ncid1, 'version')
NCDF_ATTGET, ncid1, versid, 'long_name', vers_def_byte
vers_def = string(vers_def_byte)
IF ( vers_def ne 'Geo Match File Version' ) THEN BEGIN
   print, "ERROR from read_gr_hs_ms_ns_geo_match_netcdf:"
   print, "File ", ncfile, " is not a valid geo_match netCDF file!"
   status = 1
   goto, ErrorExit
ENDIF
NCDF_VARGET, ncid1, versid, ncversion

; Get the DPR and GR filenames in the matchup file.  Read them and
; override the 'UNKNOWN' initial values in the structure
IF N_Elements(filesmeta) NE 0 THEN BEGIN
   ncdf_attget, ncid1, 'DPR_2ADPR_file', DPR_2ADPR_file_byte, /global
   filesmeta.file_2bcomb = STRING(DPR_2ADPR_file_byte)
   ncdf_attget, ncid1, 'GR_file', GR_file_byte, /global
   filesmeta.file_1CUF = STRING(GR_file_byte)
ENDIF

ncdf_attget, ncid1, 'DPR_Version', DPR_vers_byte, /global

IF N_Elements(matchupmeta) NE 0 THEN BEGIN
     NCDF_VARGET, ncid1, 'timeNearestApproach', dtime
     matchupmeta.timeNearestApproach = dtime
     NCDF_VARGET, ncid1, 'atimeNearestApproach', txtdtimebyte
     matchupmeta.atimeNearestApproach = string(txtdtimebyte)
     zdimid = NCDF_DIMID(ncid1, 'elevationAngle')
     NCDF_DIMINQ, ncid1, zdimid, XDIMNAME, ncnz
     matchupmeta.num_sweeps = ncnz
     fpdimid = NCDF_DIMID(ncid1, 'fpdim_HS')
     NCDF_DIMINQ, ncid1, fpdimid, FPDIMNAME, nprfp_HS
     matchupmeta.num_footprints_HS = nprfp_HS         ; redundant with numRays_HS
     fpdimid = NCDF_DIMID(ncid1, 'fpdim_MS')
     NCDF_DIMINQ, ncid1, fpdimid, FPDIMNAME, nprfp_MS
     matchupmeta.num_footprints_MS = nprfp_MS         ; redundant with numRays_MS
     fpdimid = NCDF_DIMID(ncid1, 'fpdim_NS')
     NCDF_DIMINQ, ncid1, fpdimid, FPDIMNAME, nprfp_NS
     matchupmeta.num_footprints_NS = nprfp_NS         ; redundant with numRays_NS
     NCDF_VARGET, ncid1, 'startScan_HS', scan_s
     matchupmeta.startScan_HS = scan_s
     NCDF_VARGET, ncid1, 'startScan_MS', scan_s
     matchupmeta.startScan_MS = scan_s
     NCDF_VARGET, ncid1, 'startScan_NS', scan_s
     matchupmeta.startScan_NS = scan_s
     NCDF_VARGET, ncid1, 'endScan_HS', scan_e
     matchupmeta.endScan_HS = scan_e
     NCDF_VARGET, ncid1, 'endScan_MS', scan_e
     matchupmeta.endScan_MS = scan_e
     NCDF_VARGET, ncid1, 'endScan_NS', scan_e
     matchupmeta.endScan_NS = scan_e
     NCDF_VARGET, ncid1, 'numRays_HS', num_rays
     matchupmeta.num_rays_HS = num_rays         ; redundant with num_footprints_HS
     NCDF_VARGET, ncid1, 'numRays_MS', num_rays
     matchupmeta.num_rays_MS = num_rays         ; redundant with num_footprints_MS
     NCDF_VARGET, ncid1, 'numRays_NS', num_rays
     matchupmeta.num_rays_NS = num_rays         ; redundant with num_footprints_NS
     NCDF_VARGET, ncid1, 'have_swath_HS', have_swath_HS
     matchupmeta.have_swath_HS = have_swath_HS
     NCDF_VARGET, ncid1, 'have_swath_MS', have_swath_MS
     matchupmeta.have_swath_MS = have_swath_MS
     ncdf_attget, ncid1, 'GV_UF_Z_field', gr_UF_field_byte, /global
     matchupmeta.GV_UF_Z_field = STRING(gr_UF_field_byte)
     hidimid = NCDF_DIMID(ncid1, 'hidim')
     NCDF_DIMINQ, ncid1, hidimid, HIDIMNAME, nhidcats
     matchupmeta.num_HID_categories = nhidcats
     ncdf_attget, ncid1, 'GV_UF_RC_field', gv_UF_field_byte, /global
     matchupmeta.GV_UF_RC_field = STRING(gv_UF_field_byte)
     ncdf_attget, ncid1, 'GV_UF_RP_field', gv_UF_field_byte, /global
     matchupmeta.GV_UF_RP_field = STRING(gv_UF_field_byte)
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
     ncdf_attget, ncid1, 'GV_UF_DM_field', gv_UF_field_byte, /global
     matchupmeta.GV_UF_DM_field = STRING(gv_UF_field_byte)
     ncdf_attget, ncid1, 'GV_UF_N2_field', gv_UF_field_byte, /global
     matchupmeta.GV_UF_N2_field = STRING(gv_UF_field_byte)
     NCDF_VARGET, ncid1, 'rangeThreshold', rngthresh
     matchupmeta.rangeThreshold = rngthresh
     NCDF_VARGET, ncid1, 'GR_dBZ_min', grzmin
     matchupmeta.GR_dBZ_min = grzmin
     NCDF_VARGET, ncid1, 'GR_ROI_km', grROI
     matchupmeta.GR_ROI_km = grROI
;     NCDF_VARGET, ncid1, versid, ncversion  ; already "got" this variable
     matchupmeta.nc_file_version = ncversion
     ncdf_attget, ncid1, 'DPR_Version', DPR_vers_byte, /global
     matchupmeta.DPR_Version = STRING(DPR_vers_byte)
ENDIF



IF N_Elements(sweepsmeta) NE 0 THEN BEGIN
     zdimid = NCDF_DIMID(ncid1, 'elevationAngle')
     NCDF_DIMINQ, ncid1, zdimid, XDIMNAME, ncnz  ; number of sweeps/elevs.
     NCDF_VARGET, ncid1, 'elevationAngle', nc_zlevels
     elevorder = SORT(nc_zlevels)
     ascorder = INDGEN(ncnz)
     ;sortflag=0
     IF TOTAL( ABS(elevorder-ascorder) ) NE 0 THEN BEGIN
       ; we have not coded for the out-of-order situation, so bail out
        message, 'Elevation angles not in order!'
        ;PRINT, 'read_gr_hs_ms_ns_geo_match_netcdf(): Elevation angles not in order! Resorting data.'
        ;sortflag=1
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
     ;sortflag=0
     IF TOTAL( ABS(elevorder-ascorder) ) NE 0 THEN BEGIN
       ; we have not coded for the out-of-order situation, so bail out
        message, 'Elevation angles not in order!'
        ;PRINT, 'read_gr_hs_ms_ns_geo_match_netcdf(): Elevation angles not in order! Resorting data.'
        ;sortflag=1
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
     NCDF_VARGET, ncid1, 'have_GR_Z', have_threeDreflect
     fieldFlags.have_threeDreflect = have_threeDreflect
     NCDF_VARGET, ncid1, 'have_GR_RC_rainrate', have_GR_RC_rainrate
     fieldFlags.have_GR_RC_rainrate = have_GR_RC_rainrate
     NCDF_VARGET, ncid1, 'have_GR_RP_rainrate', have_GR_RP_rainrate
     fieldFlags.have_GR_RP_rainrate = have_GR_RP_rainrate
     NCDF_VARGET, ncid1, 'have_GR_RR_rainrate', have_GR_RR_rainrate
     fieldFlags.have_GR_RR_rainrate = have_GR_RR_rainrate
     NCDF_VARGET, ncid1, 'have_GR_Zdr', have_GR_Zdr
     fieldFlags.have_GR_Zdr = have_GR_Zdr
     NCDF_VARGET, ncid1, 'have_GR_Kdp', have_GR_Kdp
     fieldFlags.have_GR_Kdp = have_GR_Kdp
     NCDF_VARGET, ncid1, 'have_GR_RHOhv', have_GR_RHOhv
     fieldFlags.have_GR_RHOhv = have_GR_RHOhv
     NCDF_VARGET, ncid1, 'have_GR_HID', have_GR_HID
     fieldFlags.have_GR_HID = have_GR_HID
     NCDF_VARGET, ncid1, 'have_GR_Dzero', have_GR_Dzero
     fieldFlags.have_GR_Dzero = have_GR_Dzero
     NCDF_VARGET, ncid1, 'have_GR_Nw', have_GR_Nw
     fieldFlags.have_GR_Nw = have_GR_Nw
     NCDF_VARGET, ncid1, 'have_GR_Dm', have_GR_Dm
     fieldFlags.have_GR_Dm = have_GR_Dm
     NCDF_VARGET, ncid1, 'have_GR_N2', have_GR_N2
     fieldFlags.have_GR_N2 = have_GR_N2
     NCDF_VARGET, ncid1, 'have_GR_blockage', have_blockage
     fieldFlags.have_GR_blockage = have_blockage
     NCDF_VARGET, ncid1, 'have_SWE', have_GR_SWE
     fieldFlags.have_GR_SWE = have_GR_SWE
ENDIF


; define the three swaths in the DPR product, we need separate variables
; for each swath for the GR science variables
swath = ['HS','MS','NS']

; get the science/geometry/time data for each swath type
for iswa=0,2 do begin

   NCDF_VARGET, ncid1, 'Year_'+swath[iswa], Year
   NCDF_VARGET, ncid1, 'Month_'+swath[iswa], Month
   NCDF_VARGET, ncid1, 'DayOfMonth_'+swath[iswa], DayOfMonth
   NCDF_VARGET, ncid1, 'Hour_'+swath[iswa], Hour
   NCDF_VARGET, ncid1, 'Minute_'+swath[iswa], Minute
   NCDF_VARGET, ncid1, 'Second_'+swath[iswa], Second
   NCDF_VARGET, ncid1, 'Millisecond_'+swath[iswa], Millisecond
   NCDF_VARGET, ncid1, 'startScan_'+swath[iswa], startScan
   NCDF_VARGET, ncid1, 'endScan_'+swath[iswa], endScan
   NCDF_VARGET, ncid1, 'numRays_'+swath[iswa], numRays
   NCDF_VARGET, ncid1, 'latitude_'+swath[iswa], latitude
   NCDF_VARGET, ncid1, 'longitude_'+swath[iswa], longitude
   NCDF_VARGET, ncid1, 'xCorners_'+swath[iswa], xCorners
   NCDF_VARGET, ncid1, 'yCorners_'+swath[iswa], yCorners
   NCDF_VARGET, ncid1, 'topHeight_'+swath[iswa], topHeight
   NCDF_VARGET, ncid1, 'bottomHeight_'+swath[iswa], bottomHeight
   NCDF_VARGET, ncid1, 'GR_Z_'+swath[iswa], GR_Z
   NCDF_VARGET, ncid1, 'GR_Z_StdDev_'+swath[iswa], GR_Z_StdDev
   NCDF_VARGET, ncid1, 'GR_Z_Max_'+swath[iswa], GR_Z_Max
   NCDF_VARGET, ncid1, 'GR_Zdr_'+swath[iswa], GR_Zdr
   NCDF_VARGET, ncid1, 'GR_Zdr_StdDev_'+swath[iswa], GR_Zdr_StdDev
   NCDF_VARGET, ncid1, 'GR_Zdr_Max_'+swath[iswa], GR_Zdr_Max
   NCDF_VARGET, ncid1, 'GR_Kdp_'+swath[iswa], GR_Kdp
   NCDF_VARGET, ncid1, 'GR_Kdp_StdDev_'+swath[iswa], GR_Kdp_StdDev
   NCDF_VARGET, ncid1, 'GR_Kdp_Max_'+swath[iswa], GR_Kdp_Max
   NCDF_VARGET, ncid1, 'GR_RHOhv_'+swath[iswa], GR_RHOhv
   NCDF_VARGET, ncid1, 'GR_RHOhv_StdDev_'+swath[iswa], GR_RHOhv_StdDev
   NCDF_VARGET, ncid1, 'GR_RHOhv_Max_'+swath[iswa], GR_RHOhv_Max
   NCDF_VARGET, ncid1, 'GR_RC_rainrate_'+swath[iswa], GR_RC_rainrate
   NCDF_VARGET, ncid1, 'GR_RC_rainrate_StdDev_'+swath[iswa], GR_RC_rainrate_StdDev
   NCDF_VARGET, ncid1, 'GR_RC_rainrate_Max_'+swath[iswa], GR_RC_rainrate_Max
   NCDF_VARGET, ncid1, 'GR_RP_rainrate_'+swath[iswa], GR_RP_rainrate
   NCDF_VARGET, ncid1, 'GR_RP_rainrate_StdDev_'+swath[iswa], GR_RP_rainrate_StdDev
   NCDF_VARGET, ncid1, 'GR_RP_rainrate_Max_'+swath[iswa], GR_RP_rainrate_Max
   NCDF_VARGET, ncid1, 'GR_RR_rainrate_'+swath[iswa], GR_RR_rainrate
   NCDF_VARGET, ncid1, 'GR_RR_rainrate_StdDev_'+swath[iswa], GR_RR_rainrate_StdDev
   NCDF_VARGET, ncid1, 'GR_RR_rainrate_Max_'+swath[iswa], GR_RR_rainrate_Max
   NCDF_VARGET, ncid1, 'GR_HID_'+swath[iswa], GR_HID
   NCDF_VARGET, ncid1, 'GR_Dzero_'+swath[iswa], GR_Dzero
   NCDF_VARGET, ncid1, 'GR_Dzero_StdDev_'+swath[iswa], GR_Dzero_StdDev
   NCDF_VARGET, ncid1, 'GR_Dzero_Max_'+swath[iswa], GR_Dzero_Max
   NCDF_VARGET, ncid1, 'GR_Nw_'+swath[iswa], GR_Nw
   NCDF_VARGET, ncid1, 'GR_Nw_StdDev_'+swath[iswa], GR_Nw_StdDev
   NCDF_VARGET, ncid1, 'GR_Nw_Max_'+swath[iswa], GR_Nw_Max
   NCDF_VARGET, ncid1, 'GR_Dm_'+swath[iswa], GR_Dm
   NCDF_VARGET, ncid1, 'GR_Dm_StdDev_'+swath[iswa], GR_Dm_StdDev
   NCDF_VARGET, ncid1, 'GR_Dm_Max_'+swath[iswa], GR_Dm_Max
   NCDF_VARGET, ncid1, 'GR_N2_'+swath[iswa], GR_N2
   NCDF_VARGET, ncid1, 'GR_N2_StdDev_'+swath[iswa], GR_N2_StdDev
   NCDF_VARGET, ncid1, 'GR_N2_Max_'+swath[iswa], GR_N2_Max
   NCDF_VARGET, ncid1, 'GR_blockage_'+swath[iswa], GR_blockage
   NCDF_VARGET, ncid1, 'n_gr_expected_'+swath[iswa], n_gr_expected
   NCDF_VARGET, ncid1, 'n_gr_z_rejected_'+swath[iswa], n_gr_z_rejected
   NCDF_VARGET, ncid1, 'n_gr_zdr_rejected_'+swath[iswa], n_gr_zdr_rejected
   NCDF_VARGET, ncid1, 'n_gr_kdp_rejected_'+swath[iswa], n_gr_kdp_rejected
   NCDF_VARGET, ncid1, 'n_gr_rhohv_rejected_'+swath[iswa], n_gr_rhohv_rejected
   NCDF_VARGET, ncid1, 'n_gr_rc_rejected_'+swath[iswa], n_gr_rc_rejected
   NCDF_VARGET, ncid1, 'n_gr_rp_rejected_'+swath[iswa], n_gr_rp_rejected
   NCDF_VARGET, ncid1, 'n_gr_rr_rejected_'+swath[iswa], n_gr_rr_rejected
   NCDF_VARGET, ncid1, 'n_gr_hid_rejected_'+swath[iswa], n_gr_hid_rejected
   NCDF_VARGET, ncid1, 'n_gr_dzero_rejected_'+swath[iswa], n_gr_dzero_rejected
   NCDF_VARGET, ncid1, 'n_gr_nw_rejected_'+swath[iswa], n_gr_nw_rejected
   NCDF_VARGET, ncid1, 'n_gr_dm_rejected_'+swath[iswa], n_gr_dm_rejected
   NCDF_VARGET, ncid1, 'n_gr_n2_rejected_'+swath[iswa], n_gr_n2_rejected
   NCDF_VARGET, ncid1, 'DPRlatitude_'+swath[iswa], DPRlatitude
   NCDF_VARGET, ncid1, 'DPRlongitude_'+swath[iswa], DPRlongitude
   NCDF_VARGET, ncid1, 'scanNum_'+swath[iswa], scanNum
   NCDF_VARGET, ncid1, 'rayNum_'+swath[iswa], rayNum
   NCDF_VARGET, ncid1, 'GR_SWEDP_'+swath[iswa], GR_SWEDP
   NCDF_VARGET, ncid1, 'GR_SWEDP_StdDev_'+swath[iswa], GR_SWEDP_StdDev
   NCDF_VARGET, ncid1, 'GR_SWEDP_Max_'+swath[iswa], GR_SWEDP_Max
   NCDF_VARGET, ncid1, 'n_gr_swedp_rejected_'+swath[iswa], n_gr_swedp_rejected
   NCDF_VARGET, ncid1, 'GR_SWE25_'+swath[iswa], GR_SWE25
   NCDF_VARGET, ncid1, 'GR_SWE25_StdDev_'+swath[iswa], GR_SWE25_StdDev
   NCDF_VARGET, ncid1, 'GR_SWE25_Max_'+swath[iswa], GR_SWE25_Max
   NCDF_VARGET, ncid1, 'n_gr_swe25_rejected_'+swath[iswa], n_gr_swe25_rejected
   NCDF_VARGET, ncid1, 'GR_SWE50_'+swath[iswa], GR_SWE50
   NCDF_VARGET, ncid1, 'GR_SWE50_StdDev_'+swath[iswa], GR_SWE50_StdDev
   NCDF_VARGET, ncid1, 'GR_SWE50_Max_'+swath[iswa], GR_SWE50_Max
   NCDF_VARGET, ncid1, 'n_gr_swe50_rejected_'+swath[iswa], n_gr_swe50_rejected
   NCDF_VARGET, ncid1, 'GR_SWE75_'+swath[iswa], GR_SWE75
   NCDF_VARGET, ncid1, 'GR_SWE75_StdDev_'+swath[iswa], GR_SWE75_StdDev
   NCDF_VARGET, ncid1, 'GR_SWE75_Max_'+swath[iswa], GR_SWE75_Max
   NCDF_VARGET, ncid1, 'n_gr_swe75_rejected_'+swath[iswa], n_gr_swe75_rejected

  ; copy the swath-specific data variables into anonymous structure, use
  ; TEMPORARY to avoid making a copy of the variable when loading to struct
   tempstruc = { Year : TEMPORARY(Year), $
                 Month : TEMPORARY(Month), $
                 DayOfMonth : TEMPORARY(DayOfMonth), $
                 Hour : TEMPORARY(Hour), $
                 Minute : TEMPORARY(Minute), $
                 Second : TEMPORARY(Second), $
                 Millisecond : TEMPORARY(Millisecond), $
                 startScan : TEMPORARY(startScan), $
                 endScan : TEMPORARY(endScan), $
                 numRays : TEMPORARY(numRays), $
                 latitude : TEMPORARY(latitude), $
                 longitude : TEMPORARY(longitude), $
                 xCorners : TEMPORARY(xCorners), $
                 yCorners : TEMPORARY(yCorners), $
                 topHeight : TEMPORARY(topHeight), $
                 bottomHeight : TEMPORARY(bottomHeight), $
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
                 GR_SWEDP : TEMPORARY(GR_SWEDP), $
                 GR_SWEDP_StdDev : TEMPORARY(GR_SWEDP_StdDev), $
                 GR_SWEDP_Max : TEMPORARY(GR_SWEDP_Max), $
                 GR_SWE25 : TEMPORARY(GR_SWE25), $
                 GR_SWE25_StdDev : TEMPORARY(GR_SWE25_StdDev), $
                 GR_SWE25_Max : TEMPORARY(GR_SWE25_Max), $
                 GR_SWE50 : TEMPORARY(GR_SWE50), $
                 GR_SWE50_StdDev : TEMPORARY(GR_SWE50_StdDev), $
                 GR_SWE50_Max : TEMPORARY(GR_SWE50_Max), $
                 GR_SWE75 : TEMPORARY(GR_SWE75), $
                 GR_SWE75_StdDev : TEMPORARY(GR_SWE75_StdDev), $
                 GR_SWE75_Max : TEMPORARY(GR_SWE75_Max), $
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
                 n_gr_swedp_rejected : TEMPORARY(n_gr_swedp_rejected), $
                 n_gr_swe25_rejected : TEMPORARY(n_gr_swe25_rejected), $
                 n_gr_swe50_rejected : TEMPORARY(n_gr_swe50_rejected), $
                 n_gr_swe75_rejected : TEMPORARY(n_gr_swe75_rejected), $
                 n_gr_expected : TEMPORARY(n_gr_expected), $
                 DPRlatitude : TEMPORARY(DPRlatitude), $
                 DPRlongitude : TEMPORARY(DPRlongitude), $
                 scanNum : TEMPORARY(scanNum), $
                 rayNum : TEMPORARY(rayNum) }

  ; copy the structure to a unique-named variable if user defined the matching
  ; keyword variable, using TEMPORARY to avoid making a copy of the structure
  ; in memory

   CASE swath[iswa] OF
      'HS' : IF ARG_PRESENT(data_HS) THEN data_HS = TEMPORARY(tempstruc)
      'MS' : IF ARG_PRESENT(data_MS) THEN data_MS = TEMPORARY(tempstruc)
      'NS' : IF ARG_PRESENT(data_NS) THEN data_NS = TEMPORARY(tempstruc)
   ENDCASE

endfor

ErrorExit:
NCDF_CLOSE, ncid1

RETURN, status

end
