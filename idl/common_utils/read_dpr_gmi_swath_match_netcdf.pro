;===============================================================================
;+
; Copyright © 2012, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; read_dpr_gmi_swath_match_netcdf.pro         Morris/SAIC/GPM_GV      Oct. 2014
;
; DESCRIPTION
; -----------
; Reads caller-specified data from DPR/GMI along-swath matchup netCDF files. 
; Returns status value: 0 if successful read, 1 if unsuccessful or internal
; errors or inconsistencies occur.  File must be read-ready (unzipped/
; uncompressed) before calling this function.
;
; PARAMETERS
; ----------
; ncfile               STRING, Full file pathname to netCDF matchup file (Input)
; matchupmeta          Structure holding general and algorithmic parameters (I/O)
; fieldFlags           Structure holding "data exists" flags for GMI
;                        data variables (I/O)
; filesmeta            Structure holding GMI and DPR file names used in matchup (I/O)
; xCorners             FLOAT 3-D array of parallax-adjusted GMI footprint corner
;                        X-coordinates in km, 4 per footprint.(I/O)
; yCorners             FLOAT 3-D array of parallax-adjusted GMI footprint corner
;                        Y-coordinates in km, 4 per footprint.(I/O)
; GMIlatitude          FLOAT array of surface intersection GMI footprint center
;                        latitude, degrees (I/O)
; GMIlongitude         FLOAT array of surface intersection GMI footprint center
;                        longitude, degrees (I/O)
; surfacePrecipitation FLOAT array of GMI estimated rain rate at surface, mm/h (I/O)
; surfaceType          INT array of GMI 2AGPROF 'surfaceType' flag, coded category (I/O)
; numPRrainy           INT array of GMI rain/no-rain flag, category (I/O)
; pixelStatus          INT array of GMI pixelStatus values, category (I/O)
; PoP                  INT array of GMI Probability of Precipitation values,
;                        percent (I/O)
; rayIndex             INT array of GMI product ray,scan IDL array index,
;                        relative to the full 2AGPROF products (I/O)
; precipRateSurface    FLOAT array of DPR estimated rain rate at surface, 
;                        averaged within RADIUS km of GMI footprint, mm/h (I/O)
; surfRain_2BDPRGMI    As above, but from combined DPR/GMI algorithm of 2B-DPRGMI
; BBheight             As above, but DPR estimated bright band height, meters (I/O)
; numPRinRadius        INT array, count of number of DPR footprints geometrically within
;                        within distance<=RADIUS from GMI footprint center
; numPRsfcRain         INT array, count of number of DPR footprints in numPRinRadius
;                        with non-zero DPR rain rate
; numDPRGMIsfcRain     INT array, count of number of DPR footprints in numPRinRadius
;                        with non-zero Combined DPR/GMI (2B-DPRGMI) rain rate
; numConvectiveType    INT array, count of number of DPR footprints in numPRinRadius
;                        having DPR rain type "Convective"
;
; RETURNS
; -------
; status               INT - Status of call to function, 0=success, 1=failure
;
; HISTORY
; -------
; 10/16/14 by Bob Morris, GPM GV (SAIC)
;  - Created from read_pr_tmi_swath_match_netcdf.pro
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;===============================================================================

FUNCTION read_dpr_gmi_swath_match_netcdf, ncfile,                             $
   ; metadata structures/parameters
    matchupmeta=matchupmeta, fieldflags=fieldFlags, filesmeta=filesmeta,      $

   ; data completeness parameters for averaged values:
    numPRinRadius_int=numPRinRadius, numPRsfcRain_int=numPRsfcRain,           $
    numDPRGMIsfcRain_int=numDPRGMIsfcRain,                                    $

   ; averaged/summed DPR values at GMI footprint locations:
    precipRateSurface_pr=precipRateSurface,                                   $
    surfRain_2BDPRGMI=surfRain_2BDPRGMI,                                      $
    numConvectiveType_int=numConvectiveType, numPRrainy_int=numPRrainy,       $
    xCorners=xCorners, yCorners=yCorners,                                     $
    GMIlatitude=GMIlatitude, GMIlongitude=GMIlongitude,                       $

   ; GMI science values at earth surface level, or as ray summaries:
    surfacePrecipitation=surfacePrecipitation, sfctype_int=surfaceType,       $
    pixelStatus_int=pixelStatus, PoP_int=PoP, BBheight=BBheight,              $
    gmi_idx_long=rayIndex

status = 0

ncid1 = NCDF_OPEN( ncfile )
IF ( N_Elements(ncid1) EQ 0 ) THEN BEGIN
   print, "ERROR from read_dpr_gmi_swath_match_netcdf:"
   print, "File copy ", ncfile, " is not a valid netCDF file!"
   status = 1
   goto, ErrorExit
ENDIF

; determine the number of global attributes and check the name of the first one
; to verify that we have the correct type of file
attstruc=ncdf_inquire(ncid1)
IF ( attstruc.ngatts GT 1 ) THEN BEGIN
   typeversion = ncdf_attname(ncid1, 1, /global)
   IF ( typeversion NE 'Map_Projection' ) THEN BEGIN
      print, ''
      print, "ERROR from read_dpr_gmi_swath_match_netcdf:"
      print, "File copy ", ncfile, " is not a DPR-GMI matchup file!"
      print, ''
      status = 1
      goto, ErrorExit
   ENDIF
ENDIF ELSE BEGIN
   print, ''
   print, "ERROR from read_dpr_gmi_swath_match_netcdf:"
   print, "File copy ", ncfile, " has too few global attributes!"
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
   print, "ERROR from read_dpr_gmi_swath_match_netcdf:"
   print, "File copy ", ncfile, " is not a valid geo_match netCDF file!"
   status = 1
   goto, ErrorExit
ENDIF
NCDF_VARGET, ncid1, versid, ncversion

IF N_Elements(matchupmeta) NE 0 THEN BEGIN
     scandimid = NCDF_DIMID(ncid1, 'scandim')
     NCDF_DIMINQ, ncid1, scandimid, scandimNAME, nscans
     matchupmeta.num_scans = nscans
     raydimid = NCDF_DIMID(ncid1, 'raydim')
     NCDF_DIMINQ, ncid1, raydimid, raydimNAME, nrays
     matchupmeta.num_rays = nrays
;     NCDF_VARGET, ncid1, 'gmi_rain_min', rnmin
;     matchupmeta.gmi_rain_min = rnmin
     NCDF_VARGET, ncid1, 'averaging_radius', radius
     matchupmeta.averaging_radius = radius
;     NCDF_VARGET, ncid1, versid, ncversion  ; already "got" this variable
     matchupmeta.nc_file_version = ncversion
     ncdf_attget, ncid1, 'PPS_version', PPS_vers_byte, /global
     matchupmeta.PPS_Version = STRING(PPS_vers_byte)
     ncdf_attget, ncid1, 'Map_Projection', Map_Projection_byte, /global
     matchupmeta.Map_Projection = STRING(Map_Projection_byte)
     NCDF_VARGET, ncid1, 'map_center_latitude', centerLat
     matchupmeta.centerLat = centerLat
     NCDF_VARGET, ncid1, 'map_center_longitude', centerLon
     matchupmeta.centerLon = centerLon
ENDIF

IF N_Elements(fieldFlags) NE 0 THEN BEGIN
     ; read GMI field flags
     NCDF_VARGET, ncid1, 'have_surfaceType', have_surfaceType
     fieldFlags.have_surfaceType = have_surfaceType
     NCDF_VARGET, ncid1, 'have_surfacePrecipitation', have_surfacePrecipitation
     fieldFlags.have_surfacePrecipitation = have_surfacePrecipitation
     NCDF_VARGET, ncid1, 'have_numPRrainy', have_numPRrainy
     fieldFlags.have_numPRrainy = have_numPRrainy
     NCDF_VARGET, ncid1, 'have_pixelStatus', have_pixelStatus
     fieldFlags.have_pixelStatus = have_pixelStatus
     NCDF_VARGET, ncid1, 'have_PoP', have_PoP
     fieldFlags.have_PoP = have_PoP
     ; read DPR/COM field flags
     NCDF_VARGET, ncid1, 'have_precipRateSurface', have_precipRateSurface
     fieldFlags.have_precipRateSurface = have_precipRateSurface
     NCDF_VARGET, ncid1, 'have_surfRain_2BDPRGMI', have_surfRain_2BDPRGMI
     fieldFlags.have_surfRain_2BDPRGMI = have_surfRain_2BDPRGMI
     NCDF_VARGET, ncid1, 'have_BBheight', have_BBheight
     fieldFlags.have_BBheight = have_BBheight
     NCDF_VARGET, ncid1, 'have_numConvectiveType', have_numConvectiveType
     fieldFlags.have_numConvectiveType = have_numConvectiveType
;     NCDF_VARGET, ncid1, 'have_numPRrainy', have_numPRrainy
;     fieldFlags.have_numPRrainy = have_numPRrainy
ENDIF

; Read GMI and GR filenames and override the 'UNKNOWN' initial values in the structure
IF N_Elements(filesmeta) NE 0 THEN BEGIN
      ncdf_attget, ncid1, 'GMI_GPROF_file', GMI_GPROF_file_byte, /global
      filesmeta.file_2AGPROF = STRING(GMI_GPROF_file_byte)
      ncdf_attget, ncid1, 'DPR_2A_file', DPR_2A_file_byte, /global
      filesmeta.file_dpr_2a = STRING(DPR_2A_file_byte)
      ncdf_attget, ncid1, 'DPRGMI_file', DPRGMI_file_byte, /global
      filesmeta.file_2adprgmi = STRING(DPRGMI_file_byte)
ENDIF

sortflag=0

IF N_Elements(xCorners) NE 0 THEN $
     NCDF_VARGET, ncid1, 'xCorners', xCorners

IF N_Elements(yCorners) NE 0 THEN $
     NCDF_VARGET, ncid1, 'yCorners', yCorners

IF N_Elements(GMIlatitude) NE 0 THEN $
     NCDF_VARGET, ncid1, 'GMIlatitude', GMIlatitude

IF N_Elements(GMIlongitude) NE 0 THEN $
     NCDF_VARGET, ncid1, 'GMIlongitude', GMIlongitude

IF N_Elements(surfacePrecipitation) NE 0 THEN $
     NCDF_VARGET, ncid1, 'surfacePrecipitation', surfacePrecipitation

IF N_Elements(surfaceType) NE 0 THEN $
     NCDF_VARGET, ncid1, 'surfaceType', surfaceType

IF N_Elements(pixelStatus) NE 0 THEN $
     NCDF_VARGET, ncid1, 'pixelStatus', pixelStatus

IF N_Elements(PoP) NE 0 THEN $
     NCDF_VARGET, ncid1, 'PoP', PoP

IF N_Elements(rayIndex) NE 0 THEN $
     NCDF_VARGET, ncid1, 'GMIrayIndex', rayIndex

IF N_Elements(precipRateSurface) NE 0 THEN $
     NCDF_VARGET, ncid1, 'precipRateSurface', precipRateSurface

IF N_Elements(surfRain_2BDPRGMI) NE 0 THEN $
     NCDF_VARGET, ncid1, 'surfRain_2BDPRGMI', surfRain_2BDPRGMI

IF N_Elements(BBheight) NE 0 THEN $
     NCDF_VARGET, ncid1, 'BBheight', BBheight

IF N_Elements(numPRinRadius) NE 0 THEN $
     NCDF_VARGET, ncid1, 'numPRinRadius', numPRinRadius

IF N_Elements(numPRsfcRain) NE 0 THEN $
     NCDF_VARGET, ncid1, 'numPRsfcRain', numPRsfcRain

IF N_Elements(numDPRGMIsfcRain) NE 0 THEN $
     NCDF_VARGET, ncid1, 'numPRsfcRainCom', numDPRGMIsfcRain

IF N_Elements(numConvectiveType) NE 0 THEN $
     NCDF_VARGET, ncid1, 'numConvectiveType', numConvectiveType

IF N_Elements(numPRrainy) NE 0 THEN $
     NCDF_VARGET, ncid1, 'numPRrainy', numPRrainy

ErrorExit:
NCDF_CLOSE, ncid1

RETURN, status
END
