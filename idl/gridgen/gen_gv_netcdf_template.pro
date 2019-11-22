;+
; Copyright © 2008, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;
;-------------------------------------------------------------------------------
;
; gen_gv_netcdf_template.pro    Bob Morris, GPM GV (SAIC)    March 2007
;
; DESCRIPTION
; -------------
; Using the grid definition parameters in the 'include' file grid_def.inc,
; and file/path parameters in environs.inc, creates an empty GV grid netCDF
; "template" file in directory TMP_DIR.
;
; 06/20/2007  Morris           Added "have_xxx" flag variables to indicate
;                              whether data for grid field "xxx" is present.
; 02/28/2008  Morris           Changed variable name 'grids_version' to
;                              'version' to match PR netCDF files.
; 11/17/2010  Morris           Changed default value for have_xxx variables from
;                              1 to NO_DATA_PRESENT as defined in grid_def.inc
;
;-------------------------------------------------------------------------------
;-

pro gen_gv_netcdf_template, template_file

; "Include" files for constants, names, paths, etc.
@environs.inc
@grid_def.inc
@pr_params.inc  ; for RAINTYPE_MISSING

; Assign/derive from include variables:
TEMPLATE_GV = GV_NCGRIDTEMPLATE  ; Pathname to template file, from environs.inc
;NX=75  &  NY=75  &  NZ=13  ; 2/3-D grid dimensions
z = ZLEVELS                 ; grid height levels in meters, 1.5-19.5 km
DX = DX_DY  &  DY = DX_DY   ; grid spacings in meters, DY=DX
;FLOATGRIDFILL = -99.99
;LATLONFILL = -999.0

; Create the tmp dir for the template file, if needed:
spawn, 'mkdir -p ' + TMP_DIR

; Initialize the template file name to NULL
template_file = ''

cdfid = ncdf_create(TEMPLATE_GV, /CLOBBER)

; grid dimensions

xdimid = ncdf_dimdef(cdfid, 'xdim', NX)
ydimid = ncdf_dimdef(cdfid, 'ydim', NY)
zdimid = ncdf_dimdef(cdfid, 'Height', NZ)

; Height levels

zvarid = ncdf_vardef(cdfid, 'Height', [zdimid], /short)
ncdf_attput, cdfid, zvarid, 'long_name', 'CAPPI Height Levels in 3-D Cartesian grid'
ncdf_attput, cdfid, zvarid, 'units', 'meters'

; Grid spacings

dxvarid = ncdf_vardef(cdfid, 'dx')
ncdf_attput, cdfid, dxvarid, 'long_name', 'Cartesian grid spacing in x-direction'
ncdf_attput, cdfid, dxvarid, 'units', 'meters'
dyvarid = ncdf_vardef(cdfid, 'dy')
ncdf_attput, cdfid, dyvarid, 'long_name', 'Cartesian grid spacing in y-direction'
ncdf_attput, cdfid, dyvarid, 'units', 'meters'

; Data existence (non-fill) flags for grid fields

havedbzgvvarid = ncdf_vardef(cdfid, 'have_threeDreflect', /short)
ncdf_attput, cdfid, havedbzgvvarid, 'long_name', $
             'data exists flag for threeDreflect'
ncdf_attput, cdfid, havedbzgvvarid, '_FillValue', NO_DATA_PRESENT

havesfrainvarid = ncdf_vardef(cdfid, 'have_rainRate', /short)
ncdf_attput, cdfid, havesfrainvarid, 'long_name', $
             'data exists flag for rainRate'
ncdf_attput, cdfid, havesfrainvarid, '_FillValue', NO_DATA_PRESENT

haveraintypevarid = ncdf_vardef(cdfid, 'have_convStratFlag', /short)
ncdf_attput, cdfid, haveraintypevarid, 'long_name', $
             'data exists flag for convStratFlag'
ncdf_attput, cdfid, haveraintypevarid, '_FillValue', NO_DATA_PRESENT

; 3-D grids

dbzgvvarid = ncdf_vardef(cdfid, 'threeDreflect', [xdimid,ydimid,zdimid])
ncdf_attput, cdfid, dbzgvvarid, 'long_name', '2A-55 GV radar Reflectivity'
ncdf_attput, cdfid, dbzgvvarid, 'units', 'dBZ'
ncdf_attput, cdfid, dbzgvvarid, '_FillValue', FLOATGRIDFILL

; 2-D grids

sfrainvarid = ncdf_vardef(cdfid, 'rainRate', [xdimid,ydimid])
ncdf_attput, cdfid, sfrainvarid, 'long_name', $
            '2A-53 Near-Surface Estimated Rain Rate'
ncdf_attput, cdfid, sfrainvarid, 'units', 'mm/h'
ncdf_attput, cdfid, sfrainvarid, '_FillValue', FLOATGRIDFILL

; Using RAINTYPE_MISSING file value as defined for PR 2A-23 product
raintypevarid = ncdf_vardef(cdfid, 'convStratFlag', [xdimid,ydimid], /short)
ncdf_attput, cdfid, raintypevarid, 'long_name', $
            '2A-54 Rain Type (stratiform/convective/other)'
ncdf_attput, cdfid, raintypevarid, 'units', 'Categorical'
ncdf_attput, cdfid, raintypevarid, '_FillValue', RAINTYPE_MISSING

; Data time/location variables

timevarid = ncdf_vardef(cdfid, 'beginTimeOfVolumeScan', /double)
ncdf_attput, cdfid, timevarid, 'units', 'seconds'
ncdf_attput, cdfid, timevarid, 'long_name', $
            'Seconds since 01-01-1970 00:00:00 UTC'
ncdf_attput, cdfid, timevarid, '_FillValue', 0.0D+0

atimedimid = ncdf_dimdef(cdfid, 'len_atime_ID', STRLEN('01-01-1970 00:00:00'))
atimevarid = ncdf_vardef(cdfid, 'abeginTimeOfVolumeScan', [atimedimid], /char)
ncdf_attput, cdfid, atimevarid, 'long_name', $
            'text version of beginTimeOfVolumeScan, UTC'

sitedimid = ncdf_dimdef(cdfid, 'len_site_ID', STRLEN('KXXX'))
sitevarid = ncdf_vardef(cdfid, 'site_ID', [sitedimid], /char)
ncdf_attput, cdfid, sitevarid, 'long_name', 'ICAO ID of WSR-88D Site'

sitelatvarid = ncdf_vardef(cdfid, 'site_lat')
ncdf_attput, cdfid, sitelatvarid, 'long_name', 'Latitude of Ground Radar Site'
ncdf_attput, cdfid, sitelatvarid, 'units', 'degrees North'
ncdf_attput, cdfid, sitelatvarid, '_FillValue', LATLONFILL

sitelonvarid = ncdf_vardef(cdfid, 'site_lon')
ncdf_attput, cdfid, sitelonvarid, 'long_name', 'Longitude of Ground Radar Site'
ncdf_attput, cdfid, sitelonvarid, 'units', 'degrees East'
ncdf_attput, cdfid, sitelonvarid, '_FillValue', LATLONFILL

vnversvarid = ncdf_vardef(cdfid, 'version')
ncdf_attput, cdfid, vnversvarid, 'long_name', 'GV Grids Version'
;
ncdf_control, cdfid, /endef
;
ncdf_varput, cdfid, zvarid, z
ncdf_varput, cdfid, dxvarid, DX
ncdf_varput, cdfid, dyvarid, DY
ncdf_varput, cdfid, sitevarid, '----'
ncdf_varput, cdfid, atimevarid, '01-01-1970 00:00:00'
ncdf_varput, cdfid, vnversvarid, GV_NC_FILE_VERS
;
ncdf_close, cdfid

template_file = TEMPLATE_GV

end
