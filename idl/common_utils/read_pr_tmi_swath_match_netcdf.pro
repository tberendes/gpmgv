;===============================================================================
;+
; Copyright © 2012, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; read_pr_tmi_swath_match_netcdf.pro           Morris/SAIC/GPM_GV      Dec. 2012
;
; DESCRIPTION
; -----------
; Reads caller-specified data from PR/TMI along-swath matchup netCDF files. 
; Returns status value: 0 if successful read, 1 if unsuccessful or internal
; errors or inconsistencies occur.  File must be read-ready (unzipped/
; uncompressed) before calling this function.
;
; PARAMETERS
; ----------
; ncfile               STRING, Full file pathname to netCDF matchup file (Input)
; matchupmeta          Structure holding general and algorithmic parameters (I/O)
; fieldFlags           Structure holding "data exists" flags for gridded TMI
;                        data variables (I/O)
; filesmeta            Structure holding TMI and PR file names used in matchup (I/O)
; xCorners             FLOAT 3-D array of parallax-adjusted TMI footprint corner
;                        X-coordinates in km, 4 per footprint.(I/O)
; yCorners             FLOAT 3-D array of parallax-adjusted TMI footprint corner
;                        Y-coordinates in km, 4 per footprint.(I/O)
; TMIlatitude          FLOAT array of surface intersection TMI footprint center
;                        latitude, degrees (I/O)
; TMIlongitude         FLOAT array of surface intersection TMI footprint center
;                        longitude, degrees (I/O)
; surfaceRain          FLOAT array of TMI estimated rain rate at surface, mm/h (I/O)
; surfaceType          INT array of TMI 2A12 'surfaceType' flag, coded category (I/O)
; rainFlag             INT array of TMI rain/no-rain flag, category (I/O)
; dataFlag             INT array of TMI dataFlag values, category (I/O)
; PoP                  INT array of TMI Probability of Precipitation values,
;                        percent (I/O)
; freezingHeight       INT array of TMI 2A12 freezing height values, meters (I/O)
; rayIndex             INT array of TMI product ray,scan IDL array index,
;                        relative to the full 2A12 products (I/O)
; nearSurfRain         FLOAT array of PR estimated rain rate at surface, 
;                      averaged within RADIUS km of TMI footprint, mm/h (I/O)
; nearSurfRain_2b31    As above, but from combined PR/TMI algorithm of 2B-31
; BBheight             As above, but PR estimated bright band height, meters (I/O)
; numPRinRadius        INT array, count of number of PR footprints geometrically within
;                      within distance<=RADIUS from TMI footprint center
; numPRsfcRain         INT array, count of number of PR footprints in numPRinRadius
;                      with non-zero PR rain rate
; numPRsfcRainCom      INT array, count of number of PR footprints in numPRinRadius
;                      with non-zero Combined PR/TMI (2B-31) rain rate
; numConvectiveType    INT array, count of number of PR footprints in numPRinRadius
;                      having PR rain type "Convective"
;
; RETURNS
; -------
; status               INT - Status of call to function, 0=success, 1=failure
;
; HISTORY
; -------
; 12/11/12 by Bob Morris, GPM GV (SAIC)
;  - Created from read_tmi_geo_match_netcdf.pro.
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;===============================================================================

FUNCTION read_pr_tmi_swath_match_netcdf, ncfile,                              $
   ; metadata structures/parameters
    matchupmeta=matchupmeta, fieldflags=fieldFlags, filesmeta=filesmeta,      $

   ; data completeness parameters for averaged values:
    numPRinRadius_int=numPRinRadius, numPRsfcRain_int=numPRsfcRain,           $
    numPRsfcRainCom_int=numPRsfcRainCom,                                      $

   ; averaged/summed PR values at TMI footprint locations:
    nearSurfRain_pr=nearSurfRain, nearSurfRain_2b31=nearSurfRain_2b31,        $
    numConvectiveType=numConvectiveType,                                      $

   ; spatial parameters for TMI and PR values:
    xCorners=xCorners, yCorners=yCorners,                                     $
    TMIlatitude=TMIlatitude, TMIlongitude=TMIlongitude,                       $

   ; TMI science values at earth surface level, or as ray summaries:
    surfaceRain=surfaceRain, sfctype_int=surfaceType, rainflag_int=rainFlag,  $
    dataflag_int=dataFlag, PoP_int=PoP, freezingHeight_int=freezingHeight,    $
    BBheight=BBheight, tmi_idx_long=rayIndex

status = 0

ncid1 = NCDF_OPEN( ncfile )
IF ( N_Elements(ncid1) EQ 0 ) THEN BEGIN
   print, "ERROR from read_pr_tmi_swath_match_netcdf:"
   print, "File copy ", ncfile, " is not a valid netCDF file!"
   status = 1
   goto, ErrorExit
ENDIF

; determine the number of global attributes and check the name of the first one
; to verify that we have the correct type of file
attstruc=ncdf_inquire(ncid1)
IF ( attstruc.ngatts GT 0 ) THEN BEGIN
   typeversion = ncdf_attname(ncid1, 0, /global)
   IF ( typeversion NE 'TRMM_Version' ) THEN BEGIN
      print, ''
      print, "ERROR from read_pr_tmi_swath_match_netcdf:"
      print, "File copy ", ncfile, " is not a PR-TMI matchup file!"
      print, ''
      status = 1
      goto, ErrorExit
   ENDIF
ENDIF ELSE BEGIN
   print, ''
   print, "ERROR from read_pr_tmi_swath_match_netcdf:"
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
   print, "ERROR from read_tmi_geo_match_netcdf:"
   print, "File copy ", ncfile, " is not a valid geo_match netCDF file!"
   status = 1
   goto, ErrorExit
ENDIF
NCDF_VARGET, ncid1, versid, ncversion

IF N_Elements(matchupmeta) NE 0 THEN BEGIN
     NCDF_VARGET, ncid1, 'timeNearestApproach', dtime
     matchupmeta.timeNearestApproach = dtime
     NCDF_VARGET, ncid1, 'atimeNearestApproach', txtdtimebyte
     matchupmeta.atimeNearestApproach = string(txtdtimebyte)
     scandimid = NCDF_DIMID(ncid1, 'scandim')
     NCDF_DIMINQ, ncid1, scandimid, scandimNAME, nscans
     matchupmeta.num_scans = nscans
     raydimid = NCDF_DIMID(ncid1, 'raydim')
     NCDF_DIMINQ, ncid1, raydimid, raydimNAME, nrays
     matchupmeta.num_rays = nrays
     NCDF_VARGET, ncid1, 'tmi_rain_min', rnmin
     matchupmeta.tmi_rain_min = rnmin
     NCDF_VARGET, ncid1, 'averaging_radius', radius
     matchupmeta.averaging_radius = radius
;     NCDF_VARGET, ncid1, versid, ncversion  ; already "got" this variable
     matchupmeta.nc_file_version = ncversion
     ncdf_attget, ncid1, 'TRMM_Version', TRMM_vers, /global
     matchupmeta.TRMM_Version = TRMM_vers
     ncdf_attget, ncid1, 'Map_Projection', Map_Projection_byte, /global
     matchupmeta.Map_Projection = STRING(Map_Projection_byte)
     NCDF_VARGET, ncid1, 'map_center_latitude', centerLat
     matchupmeta.centerLat = centerLat
     NCDF_VARGET, ncid1, 'map_center_longitude', centerLon
     matchupmeta.centerLon = centerLon
ENDIF

IF N_Elements(fieldFlags) NE 0 THEN BEGIN
     ; read TMI field flags
     NCDF_VARGET, ncid1, 'have_surfaceType', have_surfaceType
     fieldFlags.have_surfaceType = have_surfaceType
     NCDF_VARGET, ncid1, 'have_surfaceRain', have_surfaceRain
     fieldFlags.have_surfaceRain = have_surfaceRain
     NCDF_VARGET, ncid1, 'have_rainFlag', have_rainFlag
     fieldFlags.have_rainFlag = have_rainFlag
     NCDF_VARGET, ncid1, 'have_dataFlag', have_dataFlag
     fieldFlags.have_dataFlag = have_dataFlag
     NCDF_VARGET, ncid1, 'have_PoP', have_PoP
     fieldFlags.have_PoP = have_PoP
     NCDF_VARGET, ncid1, 'have_freezingHeight', have_freezingHeight
     fieldFlags.have_freezingHeight = have_freezingHeight
     ; read PR/COM field flags
     NCDF_VARGET, ncid1, 'have_nearSurfRain', have_nearSurfRain
     fieldFlags.have_nearSurfRain = have_nearSurfRain
     NCDF_VARGET, ncid1, 'have_nearSurfRain_2b31', have_nearSurfRain_2b31
     fieldFlags.have_nearSurfRain_2b31 = have_nearSurfRain_2b31
     NCDF_VARGET, ncid1, 'have_BBheight', have_BBheight
     fieldFlags.have_BBheight = have_BBheight
     NCDF_VARGET, ncid1, 'have_prrainFlag', have_prrainFlag
     fieldFlags.have_prrainFlag = have_prrainFlag
     NCDF_VARGET, ncid1, 'have_rainType', have_rainType
     fieldFlags.have_rainType = have_rainType
ENDIF

; Read TMI and GR filenames and override the 'UNKNOWN' initial values in the structure
IF N_Elements(filesmeta) NE 0 THEN BEGIN
      ncdf_attget, ncid1, 'TMI_2A12_file', TMI_2A12_file_byte, /global
      filesmeta.file_2a12 = STRING(TMI_2A12_file_byte)
      ncdf_attget, ncid1, 'PR_1C21_file', PR_1C21_file_byte, /global
      filesmeta.file_1c21 = STRING(PR_1C21_file_byte)
      ncdf_attget, ncid1, 'PR_2A23_file', PR_2A23_file_byte, /global
      filesmeta.file_2a23 = STRING(PR_2A23_file_byte)
      ncdf_attget, ncid1, 'PR_2A25_file', PR_2A25_file_byte, /global
      filesmeta.file_2a25 = STRING(PR_2A25_file_byte)
      ncdf_attget, ncid1, 'PR_2B31_file', PR_2B31_file_byte, /global
      filesmeta.file_2b31 = STRING(PR_2B31_file_byte)
ENDIF

sortflag=0

IF N_Elements(xCorners) NE 0 THEN BEGIN
     NCDF_VARGET, ncid1, 'xCorners', xCorners
     IF ( sortflag EQ 1 ) THEN BEGIN
        sort_status = sort_multi_d_array( elevorder, xCorners, 3 )
        IF (sort_status EQ 1) THEN BEGIN
          status = sort_status
          goto, ErrorExit
        ENDIF
     ENDIF
ENDIF

IF N_Elements(yCorners) NE 0 THEN BEGIN
     NCDF_VARGET, ncid1, 'yCorners', yCorners
     IF ( sortflag EQ 1 ) THEN BEGIN
        sort_status = sort_multi_d_array( elevorder, yCorners, 3 )
        IF (sort_status EQ 1) THEN BEGIN
          status = sort_status
          goto, ErrorExit
        ENDIF
     ENDIF
ENDIF

IF N_Elements(TMIlatitude) NE 0 THEN $
     NCDF_VARGET, ncid1, 'TMIlatitude', TMIlatitude

IF N_Elements(TMIlongitude) NE 0 THEN $
     NCDF_VARGET, ncid1, 'TMIlongitude', TMIlongitude

IF N_Elements(surfaceRain) NE 0 THEN $
     NCDF_VARGET, ncid1, 'surfaceRain', surfaceRain

IF N_Elements(surfaceType) NE 0 THEN $
     NCDF_VARGET, ncid1, 'surfaceType', surfaceType

IF N_Elements(rainFlag) NE 0 THEN $
     NCDF_VARGET, ncid1, 'rainFlag', rainFlag

IF N_Elements(dataFlag) NE 0 THEN $
     NCDF_VARGET, ncid1, 'dataFlag', dataFlag

IF N_Elements(PoP) NE 0 THEN $
     NCDF_VARGET, ncid1, 'PoP', PoP

IF N_Elements(freezingHeight) NE 0 THEN $
     NCDF_VARGET, ncid1, 'freezingHeight', freezingHeight

IF N_Elements(rayIndex) NE 0 THEN $
     NCDF_VARGET, ncid1, 'TMIrayIndex', rayIndex

IF N_Elements(nearSurfRain) NE 0 THEN $
     NCDF_VARGET, ncid1, 'nearSurfRain', nearSurfRain

IF N_Elements(nearSurfRain_2b31) NE 0 THEN $
     NCDF_VARGET, ncid1, 'nearSurfRain_2b31', nearSurfRain_2b31

IF N_Elements(BBheight) NE 0 THEN $
     NCDF_VARGET, ncid1, 'BBheight', BBheight

IF N_Elements(numPRinRadius) NE 0 THEN $
     NCDF_VARGET, ncid1, 'numPRinRadius', numPRinRadius

IF N_Elements(numPRsfcRain) NE 0 THEN $
     NCDF_VARGET, ncid1, 'numPRsfcRain', numPRsfcRain

IF N_Elements(numPRsfcRainCom) NE 0 THEN $
     NCDF_VARGET, ncid1, 'numPRsfcRainCom', numPRsfcRainCom

IF N_Elements(numConvectiveType) NE 0 THEN $
     NCDF_VARGET, ncid1, 'numConvectiveType', numConvectiveType

ErrorExit:
NCDF_CLOSE, ncid1

RETURN, status
END
