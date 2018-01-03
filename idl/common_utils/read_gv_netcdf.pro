;===============================================================================
;+
; Copyright © 2008, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; read_gv_netcdf.pro           Morris/SAIC/GPM_GV      February 2008
;
; DESCRIPTION
; -----------
; Reads caller-specified data and metadata from GV netCDF grid files derived
; from 2A-53/54/55 products.  Returns status value: 0 if successful read, 1 if
; unsuccessful or internal errors or inconsistencies occur.  File must be
; read-ready (unzipped/uncompressed) before calling this function.
;
; PARAMETERS
; ----------
; ncfile               STRING, Full file pathname to GV netCDF grid file (Input)
; dtime                DOUBLE, begin time of volume scan, unix ticks (I/O)
; txtdtime             STRING, human-readable representation of dtime (I/O)
; gridmeta             Structure holding grid definition parameters (I/O)
; sitemeta             Structure holding GV site location parameters (I/O)
; fieldFlagsGV         Structure holding "data exists" flags for gridded GV
;                        data variables (I/O)
;                      -- See file grid_nc_structs.inc for definition of
;                         the above structures.
; threeDreflect        FLOAT 3-D grid of GV radar reflectivity, dBZ (I/O)
; rainRate             FLOAT 2-D grid of GV estimated rain rate at surface,
;                        mm/h (I/O)
; convStratFlag        INT 2-D grid of GV derived raincloud type, category (I/O)
; status               INT Status of call to function (Output, Return Value)
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;===============================================================================

FUNCTION read_gv_netcdf, ncfile, dtime=dtime, txtdtime=txtdtime, $
     gridmeta=gridmeta, sitemeta=sitemeta, fieldflagsGV=fieldFlagsGV, $
     dbz3d=threeDreflect, sfcrain2d=rainRate, raintype2d_int=convStratFlag

status = 0

ncid1 = NCDF_OPEN( ncfile )
IF ( N_Elements(ncid1) EQ 0 ) THEN BEGIN
   print, "ERROR from read_gv_netcdf:"
   print, "File ", ncfile, " is not a valid netCDF file!"
   status = 1
   goto, ErrorExit
ENDIF

if (NCDF_VARID(ncid1, 'version') ne -1) then begin
   versid = NCDF_VARID(ncid1, 'version')
endif else begin
   if (NCDF_VARID(ncid1, 'grids_version') ne -1) then begin
      versid = NCDF_VARID(ncid1, 'grids_version')
   endif else begin
      print, "ERROR from read_gv_netcdf:"
      print, "Cannot find version attribute in netCDF file: ", ncfile
      status = 1
      goto, ErrorExit
      endelse
endelse

NCDF_ATTGET, ncid1, versid, 'long_name', vers_def_byte
vers_def = string(vers_def_byte)
IF ( vers_def ne 'GV Grids Version' ) THEN BEGIN
   print, "ERROR from read_gv_netcdf:"
   print, "File ", ncfile, " is not a valid GV netCDF file!"
   status = 1
   goto, ErrorExit
ENDIF

IF N_Elements(dtime) NE 0 THEN $
     NCDF_VARGET, ncid1, 'beginTimeOfVolumeScan', dtime

IF N_Elements(txtdtime) NE 0 THEN BEGIN
     NCDF_VARGET, ncid1, 'abeginTimeOfVolumeScan', txtdtimebyte
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
        print, "ERROR from read_gv_netcdf, file = ", ncfile
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

IF N_Elements(fieldFlagsGV) NE 0 THEN BEGIN
     NCDF_VARGET, ncid1, 'have_threeDreflect', have_threeDreflect
     fieldFlagsGV.have_threeDreflect = have_threeDreflect
     NCDF_VARGET, ncid1, 'have_rainRate', have_rainRate
     fieldFlagsGV.have_rainRate = have_rainRate
     NCDF_VARGET, ncid1, 'have_convStratFlag', have_convStratFlag
     fieldFlagsGV.have_convStratFlag = have_convStratFlag
ENDIF

IF N_Elements(threeDreflect) NE 0 THEN $
     NCDF_VARGET, ncid1, 'threeDreflect', threeDreflect

IF N_Elements(rainRate) NE 0 THEN $
     NCDF_VARGET, ncid1, 'rainRate', rainRate

IF N_Elements(convStratFlag) NE 0 THEN $
     NCDF_VARGET, ncid1, 'convStratFlag', convStratFlag


ErrorExit:
NCDF_CLOSE, ncid1

RETURN, status
END
