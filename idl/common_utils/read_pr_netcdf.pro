;===============================================================================
;+
; Copyright © 2008, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; read_pr_netcdf.pro           Morris/SAIC/GPM_GV      February 2008
;
; DESCRIPTION
; -----------
; Reads caller-specified data and metadata from PR netCDF grid files.  Returns
; status value: 0 if successful read, 1 if unsuccessful or internal errors or
; inconsistencies occur.  File must be read-ready (unzipped/uncompressed) before
; calling this function.
;
; PARAMETERS
; ----------
; ncfile               STRING, Full file pathname to PR netCDF grid file (Input)
; dtime                DOUBLE, time of PR overpass, unix ticks (I/O)
; txtdtime             STRING, human-readable representation of dtime (I/O)
; gridmeta             Structure holding grid definition parameters (I/O)
; sitemeta             Structure holding GV site location parameters (I/O)
; fieldFlags           Structure holding "data exists" flags for gridded PR
;                        data variables (I/O)
;                      -- See file grid_nc_structs.inc for definition of
;                         the above structures.
; dBZnormalSample      FLOAT 3-D grid of raw PR reflectivity, dBZ (I/O)
; correctZfactor       FLOAT 3-D grid of attenuation-corrected PR reflectivity,
;                         dBZ (I/O)
; rain                 FLOAT 3-D grid of PR estimated rain rate, mm/h (I/O)
; landOceanFlag        INT 2-D grid of underlying surface type, category (I/O)
; nearSurfRain         FLOAT 2-D grid of PR estimated rain rate at surface,
;                         mm/h (I/O)
; nearSurfRain_2b31    As above, but from combined PR/TMI algorithm of 2B-31
; BBheight             INT 2-D grid of PR estimated bright band height,
;                         meters (I/O)
; rainFlag             INT 2-D grid of PR rain/no-rain flag, category (I/O)
; rainType             INT 2-D grid of PR derived raincloud type, category (I/O)
; rayIndex             INT 2-D grid of PR viewing angle index, 0-49 (I/O)
; status               INT Status of call to function (Output, Return Value)
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;===============================================================================

FUNCTION read_pr_netcdf, ncfile, dtime=dtime, txtdtime=txtdtime, $
    gridmeta=gridmeta, sitemeta=sitemeta, fieldflags=fieldFlags, $
    dbzraw3d=dBZnormalSample, dbz3d=correctZfactor, rain3d=rain, $
    sfctype2d_int=landOceanFlag, sfcrain2d=nearSurfRain, $
    sfcraincomb2d=nearSurfRain_2b31, bbhgt2d_int=BBheight, $
    rainflag2d_int=rainFlag, raintype2d_int=rainType, angleidx2d_int=rayIndex

status = 0

ncid1 = NCDF_OPEN( ncfile )
IF ( N_Elements(ncid1) EQ 0 ) THEN BEGIN
   print, "ERROR from read_pr_netcdf:"
   print, "File ", ncfile, " is not a valid netCDF file!"
   status = 1
   goto, ErrorExit
ENDIF

versid = NCDF_VARID(ncid1, 'version')
NCDF_ATTGET, ncid1, versid, 'long_name', vers_def_byte
vers_def = string(vers_def_byte)
IF ( vers_def ne 'PR Grids Version' ) THEN BEGIN
   print, "ERROR from read_pr_netcdf:"
   print, "File ", ncfile, " is not a valid PR netCDF file!"
   status = 1
   goto, ErrorExit
ENDIF

IF N_Elements(dtime) NE 0 THEN $
     NCDF_VARGET, ncid1, 'timeNearestApproach', dtime

IF N_Elements(txtdtime) NE 0 THEN BEGIN
     NCDF_VARGET, ncid1, 'atimeNearestApproach', txtdtimebyte
     txtdtime = string(txtdtimebyte)
ENDIF

IF N_Elements(gridmeta) NE 0 THEN BEGIN
     xdimid = NCDF_DIMID(ncid1, 'xdim')
     ydimid = NCDF_DIMID(ncid1, 'ydim')
     zdimid = NCDF_DIMID(ncid1, 'Height')
     NCDF_DIMINQ, ncid1, xdimid, XDIMNAME, ncnx
     gridmeta.nx = ncnx
     NCDF_DIMINQ, ncid1, ydimid, YDIMNAME, ncny
     gridmeta.ny = ncny
     NCDF_DIMINQ, ncid1, zdimid, XDIMNAME, ncnz
     gridmeta.nz = ncnz
     NCDF_VARGET, ncid1, 'dx', ncdx
     gridmeta.dx = FLOAT(ncdx)
     NCDF_VARGET, ncid1, 'dy', ncdy
     gridmeta.dy = FLOAT(ncdy)
     NCDF_VARGET, ncid1, 'Height', nc_zlevels
     IF ( N_Elements(gridmeta.zlevels) EQ gridmeta.nz ) THEN BEGIN
        gridmeta.zlevels = FLOAT(nc_zlevels)
        gridmeta.dz = FLOAT(nc_zlevels[1]-nc_zlevels[0])
     ENDIF ELSE BEGIN
        print, "ERROR from read_pr_netcdf, file = ", ncfile
	print, "NZ dimension in netCDF does not match grid_def_meta struct."
        status = 1
	goto, ErrorExit
     ENDELSE
     NCDF_VARGET, ncid1, versid, ncversion
     gridmeta.version = ncversion
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
     NCDF_VARGET, ncid1, 'have_rayIndex', have_rayIndex
     fieldFlags.have_rayIndex = have_rayIndex
ENDIF

IF N_Elements(dBZnormalSample) NE 0 THEN $
     NCDF_VARGET, ncid1, 'dBZnormalSample', dBZnormalSample

IF N_Elements(correctZFactor) NE 0 THEN $
     NCDF_VARGET, ncid1, 'correctZFactor', correctZfactor

IF N_Elements(rain) NE 0 THEN $
     NCDF_VARGET, ncid1, 'rain', rain

IF N_Elements(landOceanFlag) NE 0 THEN $
     NCDF_VARGET, ncid1, 'landOceanFlag', landoceanFlag

IF N_Elements(nearSurfRain) NE 0 THEN $
     NCDF_VARGET, ncid1, 'nearSurfRain', nearSurfRain

IF N_Elements(nearSurfRain_2b31) NE 0 THEN $
     NCDF_VARGET, ncid1, 'nearSurfRain_2b31', nearSurfRain_2b31

IF N_Elements(BBheight) NE 0 THEN $
     NCDF_VARGET, ncid1, 'BBheight', BBheight  ; now in meters! (if > 0)

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
