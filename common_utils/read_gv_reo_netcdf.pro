;===============================================================================
;+
; Copyright © 2008, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; read_gv_reo_netcdf.pro           Morris/SAIC/GPM_GV      February 2008
;
; DESCRIPTION
; -----------
; Reads caller-specified data and metadata from GV netCDF grid files created
; by a run of REORDER.  Returns status value: 0 if successful read, 1 if
; unsuccessful or internal errors or inconsistencies occur.  File must be
; read-ready (unzipped/uncompressed) before calling this function.
;
; PARAMETERS
; ----------
; ncfile               STRING, Full file pathname to GV netCDF grid file (Input)
; dtime                LONG INT, begin time of volume scan, unix ticks (I/O)
; timeoffset           FLOAT, offset from dtime?? (I/O)
; gridmeta             Structure holding grid definition parameters (I/O)
; sitemeta             Structure holding GV site location parameters (I/O)
; fieldFlagsGV         Structure holding "data exists" flags for gridded GV
;                        data variables (I/O)
;                      -- See file grid_nc_structs.inc for definition of
;                         the above structures.
; threeDreflect        FLOAT 3-D grid of GV radar reflectivity, dBZ (I/O)
; status               INT Status of call to function (Output, Return Value)
;
; NOTES
; -----
; 1) Only the reflectivity field labeled either 'CZ' or 'UZ' is searched for
;    when the parameter 'threeDreflect' is requested.
; 2) Z levels are computed assuming that the lowest level's base is at the
;    height given by 'alt' variable in netCDF file, and it is centered at
;    alt+(z_spacing/2).  This may or may not be the proper way of computing
;    the grid vertical levels.
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;===============================================================================

FUNCTION read_gv_reo_netcdf, ncfile, dtime_int=dtime, timeoffset=timeoffset, $
     gridmeta=gridmeta, sitemeta=sitemeta, fieldflagsGV=fieldFlagsGV, $
     dbz3d=threeDreflect

@grid_def.inc  ; for definition of DATA_PRESENT

status = 0

ncid1 = NCDF_OPEN( ncfile )
IF ( N_Elements(ncid1) EQ 0 ) THEN BEGIN
   print, "ERROR from read_gv_reo_netcdf:"
   print, "File ", ncfile, " is not a valid netCDF file!"
   status = 1
   goto, ErrorExit
ENDIF

IF N_Elements(dtime) NE 0 THEN $
     NCDF_VARGET, ncid1, 'base_time', dtime

IF N_Elements(timeoffset) NE 0 THEN BEGIN
     NCDF_VARGET, ncid1, 'time_offset', timeoffset
ENDIF

IF N_Elements(gridmeta) NE 0 THEN BEGIN
     xdimid = NCDF_DIMID(ncid1, 'x')
     ydimid = NCDF_DIMID(ncid1, 'y')
     zdimid = NCDF_DIMID(ncid1, 'z')
     NCDF_DIMINQ, ncid1, xdimid, XDIMNAME, ncnx
     gridmeta.nx = ncnx
     NCDF_DIMINQ, ncid1, ydimid, YDIMNAME, ncny
     gridmeta.ny = ncny
     NCDF_DIMINQ, ncid1, zdimid, XDIMNAME, ncnz
     gridmeta.nz = ncnz
     NCDF_VARGET, ncid1, 'x_spacing', ncdx
     gridmeta.dx = FLOAT(ncdx)
     NCDF_VARGET, ncid1, 'y_spacing', ncdy
     gridmeta.dy = FLOAT(ncdy)
     NCDF_VARGET, ncid1, 'z_spacing', ncdz
     gridmeta.dz = FLOAT(ncdz)
     NCDF_VARGET, ncid1, 'alt', alt
     IF ( N_Elements(gridmeta.zlevels) EQ ncnz ) THEN BEGIN
         ztemp = findgen(ncnz)
         gridmeta.zlevels = ztemp*ncdz + alt + ncdz/2.0
     ENDIF ELSE BEGIN
        print, "ERROR from read_gv_reo_netcdf, file = ", ncfile
	print, "NZ dimension in netCDF does not match grid_def_meta struct."
        status = 1
	goto, ErrorExit
     ENDELSE
ENDIF

IF N_Elements(sitemeta) NE 0 THEN BEGIN
     NCDF_VARGET, ncid1, 'lat', nclat
     sitemeta.site_lat = nclat
     NCDF_VARGET, ncid1, 'lon', nclon
     sitemeta.site_lon = nclon
;     NCDF_VARGET, ncid1, 'site_ID', siteIDbyte
;     sitemeta.site_id = string(siteIDbyte)
ENDIF

IF N_Elements(threeDreflect) NE 0 THEN BEGIN
     if (NCDF_VARID(ncid1, 'CZ') ne -1) then begin
        NCDF_VARGET, ncid1, 'CZ', threeDreflect
        print, ""
        print, "Reading CZ reflectivity field from GV-REO netCDF."
        print, ""
     endif else begin
        if (NCDF_VARID(ncid1, 'UZ') ne -1) then begin
           NCDF_VARGET, ncid1, 'UZ', threeDreflect
           print, ""
           print, "Reading UZ reflectivity field from GV-REO netCDF."
           print, ""
        endif else begin
           print, "ERROR from read_gv_reo_netcdf, file = ", ncfile
	   print, "Neither CZ nor UZ reflectivity field found in netCDF file."
           status = 1
	   goto, ErrorExit
        endelse
     endelse
     IF N_Elements(fieldFlagsGV) NE 0 THEN $
          fieldFlagsGV.have_threeDreflect = DATA_PRESENT
ENDIF

ErrorExit:
NCDF_CLOSE, ncid1

RETURN, status
END
