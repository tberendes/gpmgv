;===============================================================================
;+
; Copyright © 2014, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; read_dprgmi_geo_match_netcdf_mrms.pro         Morris/SAIC/GPM_GV      August 2014
;
; DESCRIPTION
; -----------
; Reads science data and metadata from DPRGMI-GR matchup netCDF files. 
; Returns status value: 0 if successful read, 1 if unsuccessful or internal
; errors or inconsistencies occur.  File must be read-ready (unzipped/
; uncompressed) before calling this function.
;
; PARAMETERS
; ----------
; ncfile               STRING, Full file pathname to DPR netCDF grid file (Input)
;
; matchupmeta          Structure holding general and algorithmic parameters (I/O)
; sweepsmeta           Array of Structures holding sweep elevation angles,
;                      and sweep start times in unix ticks and ascii text (I/O)
; sitemeta             Structure holding GV site location parameters (I/O)
; fieldFlags           Structure holding "data exists" flags for DPR science
;                        data variables (I/O)
; filesmeta            Structure holding DPR and GR file names used in matchup (I/O)
;                      -- See file geo_match_nc_structs.inc for definition of
;                         the above structures.  These structures must be
;                         instantiated by the calling program and provided as 
;                         keyword parameters in the call to this routine.
;
; data_MS              Structure containing all the science data variables for
;                      the MS swath.  Structure is defined and created in this
;                      routine.
; data_NS              Structure containing all the science data variables for
;                      the NS swath.  Structure is defined and created in this
;                      routine.
;                      -- The data_MS and data_NS variables must be non-null
;                         in the call this this function if the filled
;                         data structures are to be returned.
;
; RETURNS
; -------
; status               INT - Status of call to function, 0=success, 1=failure
;
; HISTORY
; -------
; 08/29/14  Morris/SAIC/GPM-GV
; - Created from read_dpr_geo_match_netcdf.pro.
; 11/10/14 by Bob Morris, GPM GV (SAIC)
;  - Added reading of GR RC and RP rainrate fields for version 1.1 file, and
;    creation of "fill" fields for these variables if version < 1.1.
; 06/16/15 by Bob Morris, GPM GV (SAIC)
;  - Added zeroDegAltitude and zeroDegBin fields to substitute for bright band
;    height not available in the 2BDPRGMI.
; 12/23/15 by Bob Morris, GPM GV (SAIC)
;  - Added reading of GR_blockage variable and its presence flag for version
;    1.2 files.
; 04/19/16 by Bob Morris, GPM GV (SAIC)
;  - Added clutterStatus variables for both swaths/instruments for version 1.21
;    file.
; 7/13/16 by Bob Morris, GPM GV (SAIC)
;  - Added reading of GR variables Dm and N2, their n_rejected values, and their
;    presence flags for version 1.3 files.
;  - Added reading of GV_UF_DM_field and GV_UF_N2_field to populate into the
;    matchupmeta structure.
; 7/15/16 by Bob Morris, GPM GV (SAIC)
;  - Changed from reading both swaths by default to only reading swath for the
;    defined return parameter(s).  Replaced ARG_PRESENT(data_XS) parameter 
;    checks with calls to N_ELEMENTS(data_XS).
; 11/30/16 by Bob Morris, GPM GV (SAIC)
;  - Added reading of DPRGMI stormTopAltitude field for version 1.3 file.
;
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;===============================================================================

FUNCTION read_dprgmi_geo_match_netcdf_mrms, ncfile, matchupmeta=matchupmeta, $
    sweepsmeta=sweepsmeta, sitemeta=sitemeta, fieldflags=fieldFlags, $
    filesmeta=filesmeta, DATA_MS=data_MS, DATA_NS=data_NS


; "Include" file for DPR-product-specific parameters (i.e., RAYSPERSCAN):
@dpr_params.inc

status = 0

; first things first, see which data return parameters are defined, if any,
; and populate a STRING array 'swath' with their IDs
IF N_Elements(data_MS) NE 0 THEN BEGIN
  ; define the swath(s) to be read from the DPRGMI product, we need
  ; separate variables for each swath for the science variables
   swath = ['MS']
   IF N_Elements(data_NS) NE 0 THEN swath = [swath, 'NS']  ; append to array
ENDIF ELSE BEGIN
   IF N_Elements(data_NS) NE 0 THEN BEGIN
      swath = ['NS']
   ENDIF ELSE BEGIN
      message, "No DATA_MS or DATA_NS parameter specified.", /INFO
      status = 1
      goto, ErrorExit2
   ENDELSE
ENDELSE

ncid1 = NCDF_OPEN( ncfile )
IF ( N_Elements(ncid1) EQ 0 ) THEN BEGIN
   print, ''
   print, "ERROR from read_dprgmi_geo_match_netcdf:"
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
      print, "ERROR from read_dprgmi_geo_match_netcdf:"
      print, "File copy ", ncfile, " is not a DPRGMI-GR matchup file!"
      print, ''
      status = 1
      goto, ErrorExit
   ENDIF
ENDIF ELSE BEGIN
   print, ''
   print, "ERROR from read_dprgmi_geo_match_netcdf:"
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
   print, "ERROR from read_dprgmi_geo_match_netcdf:"
   print, "File ", ncfile, " is not a valid geo_match netCDF file!"
   status = 1
   goto, ErrorExit
ENDIF
NCDF_VARGET, ncid1, versid, ncversion

; Get the DPRGMI and GR filenames in the matchup file.  Read them and
; override the 'UNKNOWN' initial values in the structure
IF N_Elements(filesmeta) NE 0 THEN BEGIN
   ncdf_attget, ncid1, 'DPR_2BCMB_file', DPR_2BCMB_file_byte, /global
   filesmeta.file_2bcomb = STRING(DPR_2BCMB_file_byte)
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
     fpdimid = NCDF_DIMID(ncid1, 'fpdim_MS')
     NCDF_DIMINQ, ncid1, fpdimid, FPDIMNAME, nprfp_MS
     matchupmeta.num_footprints_MS = nprfp_MS
     fpdimid = NCDF_DIMID(ncid1, 'fpdim_NS')
     NCDF_DIMINQ, ncid1, fpdimid, FPDIMNAME, nprfp_NS
     matchupmeta.num_footprints_NS = nprfp_NS
     NCDF_VARGET, ncid1, 'startScan_MS', scan_s
     matchupmeta.startScan_MS = scan_s
     NCDF_VARGET, ncid1, 'startScan_NS', scan_s
     matchupmeta.startScan_NS = scan_s
     NCDF_VARGET, ncid1, 'endScan_MS', scan_e
     matchupmeta.endScan_MS = scan_e
     NCDF_VARGET, ncid1, 'endScan_NS', scan_e
     matchupmeta.endScan_NS = scan_e
     NCDF_VARGET, ncid1, 'numRays_MS', num_rays
     matchupmeta.num_rays_MS = num_rays
     NCDF_VARGET, ncid1, 'numRays_NS', num_rays
     matchupmeta.num_rays_NS = num_rays
     NCDF_VARGET, ncid1, 'have_swath_MS', have_swath_MS
     matchupmeta.have_swath_MS = have_swath_MS
     ncdf_attget, ncid1, 'GV_UF_Z_field', gr_UF_field_byte, /global
     matchupmeta.GV_UF_Z_field = STRING(gr_UF_field_byte)
     hidimid = NCDF_DIMID(ncid1, 'hidim')
     NCDF_DIMINQ, ncid1, hidimid, HIDIMNAME, nhidcats
     matchupmeta.num_HID_categories = nhidcats
     IF ncversion GT 1.0 THEN BEGIN
        ncdf_attget, ncid1, 'GV_UF_RC_field', gv_UF_field_byte, /global
        matchupmeta.GV_UF_RC_field = STRING(gv_UF_field_byte)
        ncdf_attget, ncid1, 'GV_UF_RP_field', gv_UF_field_byte, /global
        matchupmeta.GV_UF_RP_field = STRING(gv_UF_field_byte)
     ENDIF
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
     IF ncversion GE 1.3 THEN BEGIN
        ncdf_attget, ncid1, 'GV_UF_DM_field', gv_UF_field_byte, /global
        matchupmeta.GV_UF_DM_field = STRING(gv_UF_field_byte)
        ncdf_attget, ncid1, 'GV_UF_N2_field', gv_UF_field_byte, /global
        matchupmeta.GV_UF_N2_field = STRING(gv_UF_field_byte)
     ENDIF
     NCDF_VARGET, ncid1, 'rangeThreshold', rngthresh
     matchupmeta.rangeThreshold = rngthresh
     NCDF_VARGET, ncid1, 'DPR_dBZ_min', dprzmin
     matchupmeta.DPR_dBZ_min = dprzmin
     NCDF_VARGET, ncid1, 'GR_dBZ_min', grzmin
     matchupmeta.GR_dBZ_min = grzmin
     NCDF_VARGET, ncid1, 'rain_min', rnmin
     matchupmeta.rain_min = rnmin
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
     sortflag=0
     IF TOTAL( ABS(elevorder-ascorder) ) NE 0 THEN BEGIN
        PRINT, 'read_dprgmi_geo_match_netcdf(): Elevation angles not in order! Resorting data.'
        sortflag=1
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
     sortflag=0
     IF TOTAL( ABS(elevorder-ascorder) ) NE 0 THEN BEGIN
        PRINT, 'read_dprgmi_geo_match_netcdf(): Elevation angles not in order! Resorting data.'
        sortflag=1
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
     IF ncversion GT 1.0 THEN BEGIN
        NCDF_VARGET, ncid1, 'have_GR_RC_rainrate', have_GR_RC_rainrate
        fieldFlags.have_GR_RC_rainrate = have_GR_RC_rainrate
        NCDF_VARGET, ncid1, 'have_GR_RP_rainrate', have_GR_RP_rainrate
        fieldFlags.have_GR_RP_rainrate = have_GR_RP_rainrate
        NCDF_VARGET, ncid1, 'have_GR_RR_rainrate', have_GR_RR_rainrate
        fieldFlags.have_GR_RR_rainrate = have_GR_RR_rainrate
     ENDIF ELSE BEGIN
        NCDF_VARGET, ncid1, 'have_GR_rainrate', have_GR_RR_rainrate
        fieldFlags.have_GR_RR_rainrate = have_GR_RR_rainrate
     ENDELSE
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
     IF ncversion GE 1.3 THEN BEGIN
        NCDF_VARGET, ncid1, 'have_GR_Dm', have_GR_Dm
        fieldFlags.have_GR_Dm = have_GR_Dm
        NCDF_VARGET, ncid1, 'have_GR_N2', have_GR_N2
        fieldFlags.have_GR_N2 = have_GR_N2
     ENDIF
     IF ncversion GE 1.31 THEN BEGIN
     
  	    ; check for variable, but reset netcdf error if it is not found
        CATCH, error
        Result = NCDF_VARID(ncid1, 'have_mrms')
        Catch, /Cancel
     	print, 'result = ',Result
     	if Result ge 0 then begin
        	NCDF_VARGET, ncid1, 'have_mrms', have_mrms
        	fieldFlags.have_mrms = have_mrms
        	print,'have_mrms = 1'
	    	NCDF_ATTGET, ncid1, 'MRMS_Mask_categories', mrmshid, /global
	      	MRMS_dimid = NCDF_DIMID(ncid1, 'mrms_mask')
	      	if MRMS_dimid ge 0 then begin
	     		NCDF_DIMINQ, ncid1, MRMS_dimid, MRMSDIMNAME, mrmscats
	     		matchupmeta.num_MRMS_categories = mrmscats
	      	endif else begin
	       		print,'No MRMS categories in data file'
	        	matchupmeta.num_MRMS_categories = 0;
	     		matchupmeta.num_MRMS_categories = ''
	     	endelse
        endif else begin
        	fieldFlags.have_mrms = 0
       	    print,'have_mrms = 0'
     		matchupmeta.num_MRMS_categories = ''
     		matchupmeta.num_MRMS_categories = 0
        endelse
        CATCH, error
     	Result = NCDF_VARID(ncid1, 'have_GR_SWE')
        Catch, /Cancel
     	if Result ge 0 then begin
        	NCDF_VARGET, ncid1, 'have_GR_SWE', have_GR_SWE
        	fieldFlags.have_GR_SWE = have_GR_SWE
        endif else begin
        	fieldFlags.have_GR_SWE = 0
        endelse
     ENDIF
     IF ncversion GT 1.1 THEN BEGIN
        NCDF_VARGET, ncid1, 'have_GR_blockage', have_blockage
        fieldFlags.have_GR_blockage = have_blockage
     ENDIF
ENDIF



; get the science/geometry/time data for each swath type to be read

for iswa=0,N_ELEMENTS(swath)-1 do begin
   message, "Reading swath "+swath[iswa], /INFO
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
   if ncversion gt 1.0 then begin
      NCDF_VARGET, ncid1, 'GR_RC_rainrate_'+swath[iswa], GR_RC_rainrate
      NCDF_VARGET, ncid1, 'GR_RC_rainrate_StdDev_'+swath[iswa], GR_RC_rainrate_StdDev
      NCDF_VARGET, ncid1, 'GR_RC_rainrate_Max_'+swath[iswa], GR_RC_rainrate_Max
      NCDF_VARGET, ncid1, 'GR_RP_rainrate_'+swath[iswa], GR_RP_rainrate
      NCDF_VARGET, ncid1, 'GR_RP_rainrate_StdDev_'+swath[iswa], GR_RP_rainrate_StdDev
      NCDF_VARGET, ncid1, 'GR_RP_rainrate_Max_'+swath[iswa], GR_RP_rainrate_Max
      NCDF_VARGET, ncid1, 'GR_RR_rainrate_'+swath[iswa], GR_RR_rainrate
      NCDF_VARGET, ncid1, 'GR_RR_rainrate_StdDev_'+swath[iswa], GR_RR_rainrate_StdDev
      NCDF_VARGET, ncid1, 'GR_RR_rainrate_Max_'+swath[iswa], GR_RR_rainrate_Max
   endif else begin
      NCDF_VARGET, ncid1, 'GR_rainrate_'+swath[iswa], GR_RR_rainrate
      NCDF_VARGET, ncid1, 'GR_rainrate_StdDev_'+swath[iswa], GR_RR_rainrate_StdDev
      NCDF_VARGET, ncid1, 'GR_rainrate_Max_'+swath[iswa], GR_RR_rainrate_Max
      temp_rainrate = GR_RR_rainrate
      temp_rainrate[*,*] = Z_MISSING
      GR_RC_rainrate = temp_rainrate
      GR_RC_rainrate_StdDev = temp_rainrate
      GR_RC_rainrate_Max = temp_rainrate
      GR_RP_rainrate = temp_rainrate
      GR_RP_rainrate_StdDev = temp_rainrate
      GR_RP_rainrate_Max = TEMPORARY( temp_rainrate )
   endelse
   NCDF_VARGET, ncid1, 'GR_HID_'+swath[iswa], GR_HID
   NCDF_VARGET, ncid1, 'GR_Dzero_'+swath[iswa], GR_Dzero
   NCDF_VARGET, ncid1, 'GR_Dzero_StdDev_'+swath[iswa], GR_Dzero_StdDev
   NCDF_VARGET, ncid1, 'GR_Dzero_Max_'+swath[iswa], GR_Dzero_Max
   NCDF_VARGET, ncid1, 'GR_Nw_'+swath[iswa], GR_Nw
   NCDF_VARGET, ncid1, 'GR_Nw_StdDev_'+swath[iswa], GR_Nw_StdDev
   NCDF_VARGET, ncid1, 'GR_Nw_Max_'+swath[iswa], GR_Nw_Max
   IF ncversion GE 1.3 THEN BEGIN
      NCDF_VARGET, ncid1, 'GR_Dm_'+swath[iswa], GR_Dm
      NCDF_VARGET, ncid1, 'GR_Dm_StdDev_'+swath[iswa], GR_Dm_StdDev
      NCDF_VARGET, ncid1, 'GR_Dm_Max_'+swath[iswa], GR_Dm_Max
      NCDF_VARGET, ncid1, 'GR_N2_'+swath[iswa], GR_N2
      NCDF_VARGET, ncid1, 'GR_N2_StdDev_'+swath[iswa], GR_N2_StdDev
      NCDF_VARGET, ncid1, 'GR_N2_Max_'+swath[iswa], GR_N2_Max
   ENDIF ELSE BEGIN
      temp_dsd = GR_Dzero
      temp_dsd[*,*] = Z_MISSING
      GR_Dm = temp_dsd
      GR_Dm_StdDev = temp_dsd
      GR_Dm_Max = temp_dsd
      GR_N2 = temp_dsd
      GR_N2_StdDev = temp_dsd
      GR_N2_Max = TEMPORARY( temp_dsd )
   ENDELSE
   if ncversion gt 1.1 then begin
      NCDF_VARGET, ncid1, 'GR_blockage_'+swath[iswa], GR_blockage
   endif else begin
      temp_blockage = GR_RR_rainrate
      temp_blockage[*,*] = Z_MISSING
      GR_blockage = TEMPORARY( temp_blockage )
   endelse
   NCDF_VARGET, ncid1, 'n_gr_expected_'+swath[iswa], n_gr_expected
   NCDF_VARGET, ncid1, 'n_gr_z_rejected_'+swath[iswa], n_gr_z_rejected
   NCDF_VARGET, ncid1, 'n_gr_zdr_rejected_'+swath[iswa], n_gr_zdr_rejected
   NCDF_VARGET, ncid1, 'n_gr_kdp_rejected_'+swath[iswa], n_gr_kdp_rejected
   NCDF_VARGET, ncid1, 'n_gr_rhohv_rejected_'+swath[iswa], n_gr_rhohv_rejected
   if ncversion gt 1.0 then begin
      NCDF_VARGET, ncid1, 'n_gr_rc_rejected_'+swath[iswa], n_gr_rc_rejected
      NCDF_VARGET, ncid1, 'n_gr_rp_rejected_'+swath[iswa], n_gr_rp_rejected
   endif else begin
      n_gr_rc_rejected = n_gr_expected  ; set all bins as rejected
      n_gr_rp_rejected = n_gr_expected  ; set all bins as rejected
   endelse
   NCDF_VARGET, ncid1, 'n_gr_rr_rejected_'+swath[iswa], n_gr_rr_rejected
   NCDF_VARGET, ncid1, 'n_gr_hid_rejected_'+swath[iswa], n_gr_hid_rejected
   NCDF_VARGET, ncid1, 'n_gr_dzero_rejected_'+swath[iswa], n_gr_dzero_rejected
   NCDF_VARGET, ncid1, 'n_gr_nw_rejected_'+swath[iswa], n_gr_nw_rejected
   IF ncversion GE 1.3 THEN BEGIN
      NCDF_VARGET, ncid1, 'n_gr_dm_rejected_'+swath[iswa], n_gr_dm_rejected
      NCDF_VARGET, ncid1, 'n_gr_n2_rejected_'+swath[iswa], n_gr_n2_rejected
   ENDIF ELSE BEGIN
      n_gr_dm_rejected = n_gr_expected  ; set all bins as rejected
      n_gr_n2_rejected = n_gr_expected  ; set all bins as rejected
   ENDELSE
   NCDF_VARGET, ncid1, 'precipTotPSDparamHigh_'+swath[iswa], precipTotPSDparamHigh
   NCDF_VARGET, ncid1, 'precipTotPSDparamLow_'+swath[iswa], precipTotPSDparamLow
   NCDF_VARGET, ncid1, 'precipTotRate_'+swath[iswa], precipTotRate
   NCDF_VARGET, ncid1, 'precipTotWaterCont_'+swath[iswa], precipTotWaterCont
   NCDF_VARGET, ncid1, 'n_precipTotPSDparamHigh_rejected_'+swath[iswa], n_precipTotPSDparamHigh_rejected
   NCDF_VARGET, ncid1, 'n_precipTotPSDparamLow_rejected_'+swath[iswa], n_precipTotPSDparamLow_rejected
   NCDF_VARGET, ncid1, 'n_precipTotRate_rejected_'+swath[iswa], n_precipTotRate_rejected
   NCDF_VARGET, ncid1, 'n_precipTotWaterCont_rejected_'+swath[iswa], n_precipTotWaterCont_rejected
   NCDF_VARGET, ncid1, 'precipitationType_'+swath[iswa],  precipitationType
   NCDF_VARGET, ncid1, 'surfPrecipTotRate_'+swath[iswa], surfPrecipTotRate
   NCDF_VARGET, ncid1, 'surfaceElevation_'+swath[iswa], surfaceElevation
   NCDF_VARGET, ncid1, 'zeroDegAltitude_'+swath[iswa], zeroDegAltitude
   NCDF_VARGET, ncid1, 'zeroDegBin_'+swath[iswa], zeroDegBin
   NCDF_VARGET, ncid1, 'surfaceType_'+swath[iswa],  surfaceType
   NCDF_VARGET, ncid1, 'phaseBinNodes_'+swath[iswa], phaseBinNodes
   NCDF_VARGET, ncid1, 'DPRlatitude_'+swath[iswa], DPRlatitude
   NCDF_VARGET, ncid1, 'DPRlongitude_'+swath[iswa], DPRlongitude
   NCDF_VARGET, ncid1, 'scanNum_'+swath[iswa], scanNum
   NCDF_VARGET, ncid1, 'rayNum_'+swath[iswa], rayNum
   NCDF_VARGET, ncid1, 'ellipsoidBinOffset_'+swath[iswa], ellipsoidBinOffset
   NCDF_VARGET, ncid1, 'lowestClutterFreeBin_'+swath[iswa], lowestClutterFreeBin
   NCDF_VARGET, ncid1, 'precipitationFlag_'+swath[iswa], precipitationFlag
   NCDF_VARGET, ncid1, 'surfaceRangeBin_'+swath[iswa], surfaceRangeBin
   NCDF_VARGET, ncid1, 'correctedReflectFactor_'+swath[iswa], correctedReflectFactor
   NCDF_VARGET, ncid1, 'pia_'+swath[iswa], pia
   NCDF_VARGET, ncid1, 'n_correctedReflectFactor_rejected_'+swath[iswa], n_correctedReflectFactor_rejected
   NCDF_VARGET, ncid1, 'n_dpr_expected_'+swath[iswa], n_dpr_expected
   if ncversion gt 1.2 then begin
      NCDF_VARGET, ncid1, 'clutterStatus_'+swath[iswa], clutterStatus
   endif else begin
      temp_clutterStatus = n_dpr_expected
      temp_clutterStatus[*] = INT_RANGE_EDGE
      clutterStatus = TEMPORARY( temp_clutterStatus )
   endelse
   IF ncversion GE 1.3 THEN BEGIN
      NCDF_VARGET, ncid1, 'stormTopAltitude_'+swath[iswa], stormTopAltitude
   ENDIF ELSE BEGIN
      temp_stormTopAltitude = pia
      IF swath[iswa] EQ 'MS' THEN temp_stormTopAltitude[*,*,*] = FLOAT_RANGE_EDGE $
      ELSE temp_stormTopAltitude[*,*] = FLOAT_RANGE_EDGE
      stormTopAltitude = TEMPORARY( temp_stormTopAltitude )
   ENDELSE

; TAB 2/6/19 New SWE and MRMS stuff
   if have_mrms eq 1 then begin
      NCDF_VARGET, ncid1, 'PrecipMeanLow_'+swath[iswa], mrmsrrlow 
      NCDF_VARGET, ncid1, 'PrecipMeanMed_'+swath[iswa],mrmsrrmed 
      NCDF_VARGET, ncid1, 'PrecipMeanHigh_'+swath[iswa], mrmsrrhigh 
      NCDF_VARGET, ncid1, 'PrecipMeanVeryHigh_'+swath[iswa], mrmsrrveryhigh 
      NCDF_VARGET, ncid1, 'GuageRatioMeanLow_'+swath[iswa], mrmsgrlow 
      NCDF_VARGET, ncid1, 'GuageRatioMeanMed_'+swath[iswa], mrmsgrmed 
      NCDF_VARGET, ncid1, 'GuageRatioMeanHigh_'+swath[iswa], mrmsgrhigh 
      NCDF_VARGET, ncid1, 'GuageRatioMeanVeryHigh_'+swath[iswa], mrmsgrveryhigh 
      NCDF_VARGET, ncid1, 'MaskLow_'+swath[iswa], mrmsptlow 
      NCDF_VARGET, ncid1, 'MaskMed_'+swath[iswa], mrmsptmed 
      NCDF_VARGET, ncid1, 'MaskHigh_'+swath[iswa], mrmspthigh 
      NCDF_VARGET, ncid1, 'MaskVeryHigh_'+swath[iswa], mrmsptveryhigh 
      NCDF_VARGET, ncid1, 'RqiPercentLow_'+swath[iswa], mrmsrqiplow 
      NCDF_VARGET, ncid1, 'RqiPercentMed_'+swath[iswa], mrmsrqipmed 
      NCDF_VARGET, ncid1, 'RqiPercentHigh_'+swath[iswa], mrmsrqiphigh 
      NCDF_VARGET, ncid1, 'RqiPercentVeryHigh_'+swath[iswa], mrmsrqipveryhigh 
      ;NCDF_VARGET, ncid1, 'MRMS_HID_'+swath[iswa], mrmshid   	  
   endif
   
   if have_GR_SWE eq 1 then begin
   
       NCDF_VARGET, ncid1, 'GR_SWEDP_'+swath[iswa], swedp 
       NCDF_VARGET, ncid1, 'GR_SWEDP_Max_'+swath[iswa], swedp_max
       NCDF_VARGET, ncid1, 'GR_SWEDP_StdDev_'+swath[iswa], swedp_stddev
       NCDF_VARGET, ncid1, 'GR_SWE25_'+swath[iswa], swe25 
       NCDF_VARGET, ncid1, 'GR_SWE25_Max_'+swath[iswa], swe25_max
       NCDF_VARGET, ncid1, 'GR_SWE25_StdDev_'+swath[iswa], swe25_stddev
       NCDF_VARGET, ncid1, 'GR_SWE50_'+swath[iswa], swe50 
       NCDF_VARGET, ncid1, 'GR_SWE50_Max_'+swath[iswa], swe50_max
       NCDF_VARGET, ncid1, 'GR_SWE50_StdDev_'+swath[iswa], swe50_stddev
       NCDF_VARGET, ncid1, 'GR_SWE75_'+swath[iswa], swe75 
       NCDF_VARGET, ncid1, 'GR_SWE75_Max_'+swath[iswa], swe75_max
       NCDF_VARGET, ncid1, 'GR_SWE75_StdDev_'+swath[iswa], swe75_stddev
   
   endif

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
                 GR_HID : TEMPORARY(GR_HID), $
                 GR_Dzero : TEMPORARY(GR_Dzero), $
                 GR_Dzero_StdDev : TEMPORARY(GR_Dzero_StdDev), $
                 GR_Dzero_Max : TEMPORARY(GR_Dzero_Max), $
                 GR_Nw : TEMPORARY(GR_Nw), $
                 GR_Nw_StdDev : TEMPORARY(GR_Nw_StdDev), $
                 GR_Nw_Max : TEMPORARY(GR_Nw_Max), $
                 GR_Dm : TEMPORARY( GR_Dm ), $
                 GR_Dm_StdDev : TEMPORARY( GR_Dm_StdDev ), $
                 GR_Dm_Max : TEMPORARY( GR_Dm_Max ), $
                 GR_N2 : TEMPORARY( GR_N2 ), $
                 GR_N2_StdDev : TEMPORARY( GR_N2_StdDev ), $
                 GR_N2_Max : TEMPORARY( GR_N2_Max ), $
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
                 precipTotPSDparamHigh : TEMPORARY(precipTotPSDparamHigh), $
                 precipTotPSDparamLow : TEMPORARY(precipTotPSDparamLow), $
                 precipTotRate : TEMPORARY(precipTotRate), $
                 precipTotWaterCont : TEMPORARY(precipTotWaterCont), $
                 n_precipTotPSDparamHigh_rejected : $
                    TEMPORARY(n_precipTotPSDparamHigh_rejected), $
                 n_precipTotPSDparamLow_rejected : $
                    TEMPORARY(n_precipTotPSDparamLow_rejected), $
                 n_precipTotRate_rejected : $
                    TEMPORARY(n_precipTotRate_rejected), $
                 n_precipTotWaterCont_rejected : $
                    TEMPORARY(n_precipTotWaterCont_rejected), $
                 precipitationType : TEMPORARY( precipitationType), $
                 surfPrecipTotRate : TEMPORARY(surfPrecipTotRate), $
                 surfaceElevation : TEMPORARY(surfaceElevation), $
                 zeroDegAltitude : TEMPORARY(zeroDegAltitude), $
                 zeroDegBin : TEMPORARY(zeroDegBin), $
                 surfaceType : TEMPORARY(surfaceType), $
                 phaseBinNodes : TEMPORARY(phaseBinNodes), $
                 DPRlatitude : TEMPORARY(DPRlatitude), $
                 DPRlongitude : TEMPORARY(DPRlongitude), $
                 scanNum : TEMPORARY(scanNum), $
                 rayNum : TEMPORARY(rayNum), $
                 ellipsoidBinOffset : TEMPORARY(ellipsoidBinOffset), $
                 lowestClutterFreeBin : TEMPORARY(lowestClutterFreeBin), $
                 clutterStatus : TEMPORARY( clutterStatus ), $
                 precipitationFlag : TEMPORARY(precipitationFlag), $
                 surfaceRangeBin : TEMPORARY(surfaceRangeBin), $
                 pia : TEMPORARY(pia), $
                 stormTopAltitude : TEMPORARY(stormTopAltitude), $
                 correctedReflectFactor : TEMPORARY(correctedReflectFactor), $
                 n_correctedReflectFactor_rejected : $
                    TEMPORARY(n_correctedReflectFactor_rejected), $
                 n_dpr_expected : TEMPORARY(n_dpr_expected) }
                 
   if have_mrms eq 1 then begin
   	  tempstruc = { tempstruc, $
   	  mrmsrrlow : TEMPORARY(mrmsrrlow), $
      mrmsrrmed : TEMPORARY(mrmsrrmed), $
      mrmsrrhigh : TEMPORARY(mrmsrrhigh), $
      mrmsrrveryhigh : TEMPORARY(mrmsrrveryhigh), $
      mrmsgrlow : TEMPORARY(mrmsgrlow), $
      mrmsgrmed : TEMPORARY(mrmsgrmed), $
      mrmsgrhigh : TEMPORARY(mrmsgrhigh), $
      mrmsgrveryhigh : TEMPORARY(mrmsgrveryhigh), $
      mrmsptlow : TEMPORARY(mrmsptlow), $
      mrmsptmed : TEMPORARY(mrmsptmed), $
      mrmspthigh : TEMPORARY(mrmspthigh), $
      mrmsptveryhigh : TEMPORARY(mrmsptveryhigh), $
      mrmsrqiplow : TEMPORARY(mrmsrqiplow), $
      mrmsrqipmed : TEMPORARY(mrmsrqipmed), $
      mrmsrqiphigh : TEMPORARY(mrmsrqiphigh), $
      mrmsrqipveryhigh : TEMPORARY(mrmsrqipveryhigh), $
      mrmshid: TEMPORARY(mrmshid)}
;      tempstruc = {tempstruc, mrmsstruc}
   endif
   
   if have_GR_SWE eq 1 then begin
   
      tempstruc = {tempstruc, $
      swedp : TEMPORARY(swedp), $
      swedp_max : TEMPORARY(swedp_max), $
      swedp_stddev : TEMPORARY(swedp_stddev), $
      swe25 : TEMPORARY(swe25), $
      swe25_max : TEMPORARY(swe25_max), $
      swe25_stddev : TEMPORARY(swe25_stddev), $
      swe50 : TEMPORARY(swe50), $
      swe50_max : TEMPORARY(swe50_max), $
      swe50_stddev : TEMPORARY(swe50_stddev), $
      swe75 : TEMPORARY(swe75), $
      swe75_max : TEMPORARY(swe75_max), $
      swe75_stddev : TEMPORARY(swe75_stddev)}
 ;     tempstruc = {tempstruc, swestruc}
   
   endif



  ; copy the structure to a unique-named variable if user defined the matching
  ; keyword variable, using TEMPORARY to avoid making a copy of the structure
  ; in memory

   CASE swath[iswa] OF
      'MS' : IF N_ELEMENTS(data_MS) NE 0 THEN data_MS = TEMPORARY(tempstruc)
      'NS' : IF N_ELEMENTS(data_NS) NE 0 THEN data_NS = TEMPORARY(tempstruc)
   ENDCASE

endfor

ErrorExit:
NCDF_CLOSE, ncid1

ErrorExit2:
RETURN, status

end
