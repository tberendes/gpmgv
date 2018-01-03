;===============================================================================
;+
; Copyright © 2008, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; read_geo_match_netcdf_csu.pro       Morris/SAIC/GPM_GV      January 2009
;
; DESCRIPTION
; -----------
; Reads caller-specified data and metadata from PR-GV matchup netCDF files. 
; Returns status value: 0 if successful read, 1 if unsuccessful or internal
; errors or inconsistencies occur.  File must be read-ready (unzipped/
; uncompressed) before calling this function.
;
; PARAMETERS
; ----------
; ncfile               STRING, Full file pathname to PR netCDF grid file (Input)
; matchupmeta          Structure holding general and algorithmic parameters (I/O)
; sweepsmeta           Array of Structures holding sweep elevation angles,
;                      and sweep start times in unix ticks and ascii text (I/O)
; sitemeta             Structure holding GV site location parameters (I/O)
; fieldFlags           Structure holding "data exists" flags for gridded PR
;                        data variables (I/O)
;                      -- See file grid_nc_structs.inc for definition of
;                         the above structures.
; threeDreflect        FLOAT 2-D array of horizontally-averaged, QC'd GV
;                        reflectivity, dBZ (I/O)
; gvexpect             INT number of GV radar bins averaged for the above (I/O)
; gvreject             INT number of bins below GV dBZ cutoff in above (I/O)
; prexpect             INT number of PR radar bins averaged for dBZnormalSample,
;                      correctZfactor, and rain (I/O)
; dBZnormalSample      FLOAT 2-D array of vertically-averaged raw PR
;                        reflectivity, dBZ (I/O)
; zrawreject           INT number of PR bins below dBZ cutoff in above (I/O)
; correctZfactor       FLOAT 2-D array of vertically-averaged, attenuation-
;                        corrected PR reflectivity, dBZ (I/O)
; zcorreject           INT number of PR bins below dBZ cutoff in above (I/O)
; rain                 FLOAT 2-D array of vertically-averaged PR estimated rain
;                        rate, mm/h (I/O)
; rainreject           INT number of PR bins below rainrate cutoff in above (I/O)
; topHeight            FLOAT 2-D array of mean GV beam top over PR footprint
;                        (I/O)
; bottomHeight         FLOAT 2-D array of mean GV beam bottoms over PR footprint
;                        (I/O)
; xCorners             FLOAT 3-D array of parallax-adjusted PR footprint corner
;                        X-coordinates in km, 4 per footprint.(I/O)
; yCorners             FLOAT 3-D array of parallax-adjusted PR footprint corner
;                        Y-coordinates in km, 4 per footprint.(I/O)
; latitude             FLOAT 2-D array of parallax-adjusted PR footprint center
;                        latitude, degrees (I/O)
; longitude            FLOAT 2-D array of parallax-adjusted PR footprint center
;                        longitude, degrees (I/O)
; latitude             FLOAT array of parallax-adjusted PR footprint center
;                        latitude, degrees North (I/O)
; longitude            FLOAT array of parallax-adjusted PR footprint center
;                        longitude, degrees East (I/O)
; PRlatitude           FLOAT array of surface intersection PR footprint center
;                        latitude, degrees (I/O)
; PRlongitude          FLOAT array of surface intersection PR footprint center
;                        longitude, degrees (I/O)
; landOceanFlag        INT array of underlying surface type, category (I/O)
; nearSurfRain         FLOAT array of PR estimated rain rate at surface,
;                         mm/h (I/O)
; nearSurfRain_2b31    As above, but from combined PR/TMI algorithm of 2B-31
; BBheight             INT array of PR estimated bright band height,
;                         meters (I/O)
; rainFlag             INT array of PR rain/no-rain flag, category (I/O)
; rainType             INT array of PR derived raincloud type, category (I/O)
; rayIndex             INT array of PR product ray,scan IDL array index,
;                        relative to the full 1C21/2A25/2B31 products (I/O)
;
; RETURNS
; -------
; status               INT - Status of call to function, 0=success, 1=failure
;
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;===============================================================================

FUNCTION read_geo_match_netcdf_csu, ncfile, matchupmeta=matchupmeta,          $
    sweepsmeta=sweepsmeta, sitemeta=sitemeta, fieldflags=fieldFlags,          $
   ; threshold/data completeness parameters for vert/horiz averaged values:
    gvexpect_int=gvexpect, gvreject_int=gvreject, prexpect_int=prexpect,      $
    zrawreject_int=zrawreject, zcorreject_int=zcorreject,                     $
    rainreject_int=rainreject,                                                $
   ; horizontally (GV) and vertically (PR Z, rain) averaged values at elevs.:
    dbzgv=threeDreflect, grAtten=GR_attenuation, grMaxAtten=max_GR_attenuation, $
    dbzraw=dBZnormalSample, dbzcor=correctZfactor, rain3d=rain,               $
   ; spatial parameters for PR and GV values at sweep elevations:
    topHeight=topHeight, bottomHeight=bottomHeight, xCorners=xCorners,        $
    yCorners=yCorners, latitude=latitude, longitude=longitude,                $
   ; spatial parameters for PR at earth surface level:
    PRlatitude=PRlatitude, PRlongitude=PRlongitude,                           $
   ; PR science values at earth surface level, or as ray summaries:
    sfcrainpr=nearSurfRain, sfcraincomb=nearSurfRain_2b31, bbhgt=BBheight,    $
    sfctype_int=landOceanFlag, rainflag_int=rainFlag, raintype_int=rainType,  $
    pridx_long=rayIndex

status = 0

ncid1 = NCDF_OPEN( ncfile )
IF ( N_Elements(ncid1) EQ 0 ) THEN BEGIN
   print, "ERROR from read_geo_match_netcdf:"
   print, "File ", ncfile, " is not a valid netCDF file!"
   status = 1
   goto, ErrorExit
ENDIF

versid = NCDF_VARID(ncid1, 'version')
NCDF_ATTGET, ncid1, versid, 'long_name', vers_def_byte
vers_def = string(vers_def_byte)
IF ( vers_def ne 'Geo Match File Version' ) THEN BEGIN
   print, "ERROR from read_geo_match_netcdf:"
   print, "File ", ncfile, " is not a valid geo_match netCDF file!"
   status = 1
   goto, ErrorExit
ENDIF

IF N_Elements(matchupmeta) NE 0 THEN BEGIN
     NCDF_VARGET, ncid1, 'timeNearestApproach', dtime
     matchupmeta.timeNearestApproach = dtime
     NCDF_VARGET, ncid1, 'atimeNearestApproach', txtdtimebyte
     matchupmeta.atimeNearestApproach = string(txtdtimebyte)
     zdimid = NCDF_DIMID(ncid1, 'elevationAngle')
     NCDF_DIMINQ, ncid1, zdimid, XDIMNAME, ncnz
     matchupmeta.num_sweeps = ncnz
     fpdimid = NCDF_DIMID(ncid1, 'fpdim')
     NCDF_DIMINQ, ncid1, fpdimid, FPDIMNAME, nprfp
     matchupmeta.num_footprints = nprfp
     NCDF_VARGET, ncid1, 'rangeThreshold', rngthresh
     matchupmeta.rangeThreshold = rngthresh
     NCDF_VARGET, ncid1, 'PR_dBZ_min', przmin
     matchupmeta.PR_dBZ_min = przmin
     NCDF_VARGET, ncid1, 'GV_dBZ_min', gvzmin
     matchupmeta.GV_dBZ_min = gvzmin
     NCDF_VARGET, ncid1, 'rain_min', rnmin
     matchupmeta.rain_min = rnmin
     NCDF_VARGET, ncid1, versid, ncversion
     matchupmeta.nc_file_version = ncversion
     ncdf_attget, ncid1, 'PR_Version', PR_vers, /global
     matchupmeta.PR_Version = PR_vers
     ncdf_attget, ncid1, 'GV_UF_Z_field', gv_UF_field_byte, /global
     matchupmeta.GV_UF_Z_field = STRING(gv_UF_field_byte)
ENDIF

IF N_Elements(sweepsmeta) NE 0 THEN BEGIN
     zdimid = NCDF_DIMID(ncid1, 'elevationAngle')
     NCDF_DIMINQ, ncid1, zdimid, XDIMNAME, ncnz  ; number of sweeps/elevs.
     NCDF_VARGET, ncid1, 'elevationAngle', nc_zlevels
;     IF ( N_Elements(nc_zlevels) EQ ncnz ) THEN BEGIN
     arr_structs = REPLICATE(sweepsmeta,ncnz)  ; need one struct per sweep/elev.
     arr_structs.elevationAngle = nc_zlevels
     NCDF_VARGET, ncid1, 'timeSweepStart', sweepticks
     arr_structs.timeSweepStart = sweepticks
     NCDF_VARGET, ncid1, 'atimeSweepStart', sweeptimetxtbyte
     arr_structs.atimeSweepStart = STRING(sweeptimetxtbyte)
     sweepsmeta = arr_structs
;     ENDIF ELSE BEGIN
;        print, "ERROR from read_geo_match_netcdf, file = ", ncfile
;	print, "elevationAngle dimension in netCDF does not match data array."
;        status = 1
;	goto, ErrorExit
;     ENDELSE
ENDIF

IF N_Elements(sitemeta) NE 0 THEN BEGIN
     NCDF_VARGET, ncid1, 'site_lat', nclat
     sitemeta.site_lat = nclat
     NCDF_VARGET, ncid1, 'site_lon', nclon
     sitemeta.site_lon = nclon
     NCDF_VARGET, ncid1, 'site_ID', siteIDbyte
     sitemeta.site_id = string(siteIDbyte)
ENDIF

IF N_Elements(fieldFlags) NE 0 THEN BEGIN
     NCDF_VARGET, ncid1, 'have_threeDreflect', have_threeDreflect
     fieldFlags.have_threeDreflect = have_threeDreflect
     NCDF_VARGET, ncid1, 'have_GR_attenuation', have_GR_attenuation
;     fieldFlags.have_GR_attenuation = have_GR_attenuation
     NCDF_VARGET, ncid1, 'have_max_GR_attenuation', have_max_GR_attenuation
;     fieldFlags.have_max_GR_attenuation = have_max_GR_attenuation
     NCDF_VARGET, ncid1, 'have_dBZnormalSample', have_dBZnormalSample
     fieldFlags.have_dBZnormalSample = have_dBZnormalSample
     NCDF_VARGET, ncid1, 'have_correctZFactor', have_correctZFactor
     fieldFlags.have_correctZFactor = have_correctZFactor
     NCDF_VARGET, ncid1, 'have_rain', have_rain
     fieldFlags.have_rain = have_rain
     NCDF_VARGET, ncid1, 'have_landOceanFlag', have_landOceanFlag
     fieldFlags.have_landOceanFlag = have_landOceanFlag
     NCDF_VARGET, ncid1, 'have_nearSurfRain', have_nearSurfRain
     fieldFlags.have_nearSurfRain = have_nearSurfRain
     NCDF_VARGET, ncid1, 'have_nearSurfRain_2b31', have_nearSurfRain_2b31
     fieldFlags.have_nearSurfRain_2b31 = have_nearSurfRain_2b31
     NCDF_VARGET, ncid1, 'have_BBheight', have_BBheight
     fieldFlags.have_BBheight = have_BBheight
     NCDF_VARGET, ncid1, 'have_rainFlag', have_rainFlag
     fieldFlags.have_rainFlag = have_rainFlag
     NCDF_VARGET, ncid1, 'have_rainType', have_rainType
     fieldFlags.have_rainType = have_rainType
ENDIF

IF N_Elements(gvexpect) NE 0 THEN $
     NCDF_VARGET, ncid1, 'n_gv_expected', gvexpect

IF N_Elements(gvreject) NE 0 THEN $
     NCDF_VARGET, ncid1, 'n_gv_rejected', gvreject

IF N_Elements(prexpect) NE 0 THEN $
     NCDF_VARGET, ncid1, 'n_pr_expected', prexpect

IF N_Elements(zrawreject) NE 0 THEN $
     NCDF_VARGET, ncid1, 'n_1c21_z_rejected', zrawreject

IF N_Elements(zcorreject) NE 0 THEN $
     NCDF_VARGET, ncid1, 'n_2a25_z_rejected', zcorreject

IF N_Elements(rainreject) NE 0 THEN $
     NCDF_VARGET, ncid1, 'n_2a25_r_rejected', rainreject

IF N_Elements(threeDreflect) NE 0 THEN $
     NCDF_VARGET, ncid1, 'threeDreflect', threeDreflect

IF N_Elements(GR_attenuation) NE 0 THEN $
     NCDF_VARGET, ncid1, 'GR_attenuation', GR_attenuation

IF N_Elements(max_GR_attenuation) NE 0 THEN $
     NCDF_VARGET, ncid1, 'max_GR_attenuation', max_GR_attenuation

IF N_Elements(dBZnormalSample) NE 0 THEN $
     NCDF_VARGET, ncid1, 'dBZnormalSample', dBZnormalSample

IF N_Elements(correctZFactor) NE 0 THEN $
     NCDF_VARGET, ncid1, 'correctZFactor', correctZfactor

IF N_Elements(rain) NE 0 THEN $
     NCDF_VARGET, ncid1, 'rain', rain

IF N_Elements(topHeight) NE 0 THEN $
     NCDF_VARGET, ncid1, 'topHeight', topHeight

IF N_Elements(bottomHeight) NE 0 THEN $
     NCDF_VARGET, ncid1, 'bottomHeight', bottomHeight

IF N_Elements(xCorners) NE 0 THEN $
     NCDF_VARGET, ncid1, 'xCorners', xCorners

IF N_Elements(yCorners) NE 0 THEN $
     NCDF_VARGET, ncid1, 'yCorners', yCorners

IF N_Elements(latitude) NE 0 THEN $
     NCDF_VARGET, ncid1, 'latitude', latitude

IF N_Elements(longitude) NE 0 THEN $
     NCDF_VARGET, ncid1, 'longitude', longitude

IF N_Elements(PRlatitude) NE 0 THEN $
     NCDF_VARGET, ncid1, 'PRlatitude', PRlatitude

IF N_Elements(PRlongitude) NE 0 THEN $
     NCDF_VARGET, ncid1, 'PRlongitude', PRlongitude

IF N_Elements(nearSurfRain) NE 0 THEN $
     NCDF_VARGET, ncid1, 'nearSurfRain', nearSurfRain

IF N_Elements(nearSurfRain_2b31) NE 0 THEN $
     NCDF_VARGET, ncid1, 'nearSurfRain_2b31', nearSurfRain_2b31

IF N_Elements(BBheight) NE 0 THEN $
     NCDF_VARGET, ncid1, 'BBheight', BBheight  ; now in meters! (if > 0)

IF N_Elements(landOceanFlag) NE 0 THEN $
     NCDF_VARGET, ncid1, 'landOceanFlag', landoceanFlag

IF N_Elements(rainFlag) NE 0 THEN $
     NCDF_VARGET, ncid1, 'rainFlag', rainFlag

IF N_Elements(rainType) NE 0 THEN $
     NCDF_VARGET, ncid1, 'rainType', rainType

IF N_Elements(rayIndex) NE 0 THEN $
     NCDF_VARGET, ncid1, 'rayIndex', rayIndex

ErrorExit:
NCDF_CLOSE, ncid1

RETURN, status
END
