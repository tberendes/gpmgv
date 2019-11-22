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
; gen_pr_netcdf_template.pro    Bob Morris, GPM GV (SAIC)    March 2007
;
; DESCRIPTION
; -------------
; Using the grid definition parameters in the 'include' file grid_def.inc,
; and file/path parameters in environs.inc, creates an empty PR grid netCDF
; "template" file in directory TMP_DIR.
;
; 06/20/2007  Morris           Added 2-D grid for 2B-31 rain rate
;                              Added "have_xxx" flag variables to indicate
;                              whether data for grid field "xxx" is present.
; 11/16/2007  Morris           Added 2-D grid and flag vars. for Ray Index
;                              (PR scan angle). Set fill value as BB_MISSING.
; 11/17/2010  Morris           Changed default value for have_xxx variables from
;                              1 to NO_DATA_PRESENT as defined in grid_def.inc
;-------------------------------------------------------------------------------
;-

pro gen_pr_netcdf_template, template_file

; "Include" files for constants, names, paths, etc.
@environs.inc
@grid_def.inc
@pr_params.inc  ; for BB_MISSING used as BB fill value

; Assign/derive from include variables:
TEMPLATE_PR = PR_NCGRIDTEMPLATE  ; Pathname to template file, from environs.inc
;NX=75  &  NY=75  &  NZ=13  ; 2/3-D grid dimensions from grid_def.inc
z = ZLEVELS                 ; grid height levels in meters, 1.5-19.5 km
DX = DX_DY  &  DY = DX_DY   ; grid spacings in meters, DY=DX
;FLOATGRIDFILL = -99.99
;RAINFLAGFILL = 2048        ; setting a "Not Used" bit only
;LATLONFILL = -999.0

; Create the tmp dir for the template file, if needed:
spawn, 'mkdir -p ' + TMP_DIR

; Initialize the template file name to NULL
template_file = ''

cdfid = ncdf_create(TEMPLATE_PR, /CLOBBER)

; grid dimensions

xdimid = ncdf_dimdef(cdfid, 'xdim', NX)
ydimid = ncdf_dimdef(cdfid, 'ydim', NY)
zdimid = ncdf_dimdef(cdfid, 'Height', NZ)

; Height levels

zvarid = ncdf_vardef(cdfid, 'Height', [zdimid], /short)
ncdf_attput, cdfid, zvarid, 'long_name', $
            'CAPPI Height Levels in 3-D Cartesian grid'
ncdf_attput, cdfid, zvarid, 'units', 'meters'

; Grid spacings

dxvarid = ncdf_vardef(cdfid, 'dx')
ncdf_attput, cdfid, dxvarid, 'long_name', $
            'Cartesian grid spacing in x-direction'
ncdf_attput, cdfid, dxvarid, 'units', 'meters'

dyvarid = ncdf_vardef(cdfid, 'dy')
ncdf_attput, cdfid, dyvarid, 'long_name', $
            'Cartesian grid spacing in y-direction'
ncdf_attput, cdfid, dyvarid, 'units', 'meters'

; Data existence (non-fill) flags for grid fields

havedbzrawvarid = ncdf_vardef(cdfid, 'have_dBZnormalSample', /short)
ncdf_attput, cdfid, havedbzrawvarid, 'long_name', $
             'data exists flag for dBZnormalSample'
ncdf_attput, cdfid, havedbzrawvarid, '_FillValue', NO_DATA_PRESENT

havedbzvarid = ncdf_vardef(cdfid, 'have_correctZFactor', /short)
ncdf_attput, cdfid, havedbzvarid, 'long_name', $
             'data exists flag for correctZFactor'
ncdf_attput, cdfid, havedbzvarid, '_FillValue', NO_DATA_PRESENT

haverainvarid = ncdf_vardef(cdfid, 'have_rain', /short)
ncdf_attput, cdfid, haverainvarid, 'long_name', $
             'data exists flag for rain'
ncdf_attput, cdfid, haverainvarid, '_FillValue', NO_DATA_PRESENT

havelandoceanvarid = ncdf_vardef(cdfid, 'have_landOceanFlag', /short)
ncdf_attput, cdfid, havelandoceanvarid, 'long_name', $
             'data exists flag for landOceanFlag'
ncdf_attput, cdfid, havelandoceanvarid, '_FillValue', NO_DATA_PRESENT

havesfrainvarid = ncdf_vardef(cdfid, 'have_nearSurfRain', /short)
ncdf_attput, cdfid, havesfrainvarid, 'long_name', $
             'data exists flag for nearSurfRain'
ncdf_attput, cdfid, havesfrainvarid, '_FillValue', NO_DATA_PRESENT

havesfrain_2b31_varid = ncdf_vardef(cdfid, 'have_nearSurfRain_2b31', /short)
ncdf_attput, cdfid, havesfrain_2b31_varid, 'long_name', $
             'data exists flag for nearSurfRain_2b31'
ncdf_attput, cdfid, havesfrain_2b31_varid, '_FillValue', NO_DATA_PRESENT

havebbvarid = ncdf_vardef(cdfid, 'have_BBheight', /short)
ncdf_attput, cdfid, havebbvarid, 'long_name', 'data exists flag for BBheight'
ncdf_attput, cdfid, havebbvarid, '_FillValue', NO_DATA_PRESENT

haverainflagvarid = ncdf_vardef(cdfid, 'have_rainFlag', /short)
ncdf_attput, cdfid, haverainflagvarid, 'long_name', $
             'data exists flag for rainFlag'
ncdf_attput, cdfid, haverainflagvarid, '_FillValue', NO_DATA_PRESENT

haveraintypevarid = ncdf_vardef(cdfid, 'have_rainType', /short)
ncdf_attput, cdfid, haveraintypevarid, 'long_name', $
             'data exists flag for rainType'
ncdf_attput, cdfid, haveraintypevarid, '_FillValue', NO_DATA_PRESENT

haverayidxvarid = ncdf_vardef(cdfid, 'have_rayIndex', /short)
ncdf_attput, cdfid, haverayidxvarid, 'long_name', $
             'data exists flag for rayIndex'
ncdf_attput, cdfid, haverayidxvarid, '_FillValue', NO_DATA_PRESENT

; 3-D grids

dbzrawvarid = ncdf_vardef(cdfid, 'dBZnormalSample', [xdimid,ydimid,zdimid])
ncdf_attput, cdfid, dbzrawvarid, 'long_name', '1C-21 Uncorrected Reflectivity'
ncdf_attput, cdfid, dbzrawvarid, 'units', 'dBZ'
ncdf_attput, cdfid, dbzrawvarid, '_FillValue', FLOATGRIDFILL

dbzvarid = ncdf_vardef(cdfid, 'correctZFactor', [xdimid,ydimid,zdimid])
ncdf_attput, cdfid, dbzvarid, 'long_name', $
            '2A-25 Attenuation-corrected Reflectivity'
ncdf_attput, cdfid, dbzvarid, 'units', 'dBZ'
ncdf_attput, cdfid, dbzvarid, '_FillValue', FLOATGRIDFILL

rainvarid = ncdf_vardef(cdfid, 'rain', [xdimid,ydimid,zdimid])
ncdf_attput, cdfid, rainvarid, 'long_name', '2A-25 Estimated Rain Rate'
ncdf_attput, cdfid, rainvarid, 'units', 'mm/h'
ncdf_attput, cdfid, rainvarid, '_FillValue', FLOATGRIDFILL

; 2-D grids

landoceanvarid = ncdf_vardef(cdfid, 'landOceanFlag', [xdimid,ydimid], /short)
ncdf_attput, cdfid, landoceanvarid, 'long_name', '1C-21 Land/Ocean Flag'
ncdf_attput, cdfid, landoceanvarid, 'units', 'Categorical'
ncdf_attput, cdfid, landoceanvarid, '_FillValue', LANDOCEAN_MISSING

sfrainvarid = ncdf_vardef(cdfid, 'nearSurfRain', [xdimid,ydimid])
ncdf_attput, cdfid, sfrainvarid, 'long_name', $
             '2A-25 Near-Surface Estimated Rain Rate'
ncdf_attput, cdfid, sfrainvarid, 'units', 'mm/h'
ncdf_attput, cdfid, sfrainvarid, '_FillValue', FLOATGRIDFILL

sfrain_2b31_varid = ncdf_vardef(cdfid, 'nearSurfRain_2b31', [xdimid,ydimid])
ncdf_attput, cdfid, sfrain_2b31_varid, 'long_name', $
            '2B-31 Near-Surface Estimated Rain Rate'
ncdf_attput, cdfid, sfrain_2b31_varid, 'units', 'mm/h'
ncdf_attput, cdfid, sfrain_2b31_varid, '_FillValue', FLOATGRIDFILL

bbvarid = ncdf_vardef(cdfid, 'BBheight', [xdimid,ydimid], /short)
ncdf_attput, cdfid, bbvarid, 'long_name', $
            '2A-25 Bright Band Height from Range Bin Numbers'
ncdf_attput, cdfid, bbvarid, 'units', 'm'
ncdf_attput, cdfid, bbvarid, '_FillValue', BB_MISSING

rainflagvarid = ncdf_vardef(cdfid, 'rainFlag', [xdimid,ydimid], /short)
ncdf_attput, cdfid, rainflagvarid, 'long_name', '2A-25 Rain Flag (bitmap)'
ncdf_attput, cdfid, rainflagvarid, 'units', 'Categorical'
ncdf_attput, cdfid, rainflagvarid, '_FillValue', RAINFLAGFILL

raintypevarid = ncdf_vardef(cdfid, 'rainType', [xdimid,ydimid], /short)
ncdf_attput, cdfid, raintypevarid, 'long_name', $
            '2A-23 Rain Type (stratiform/convective/other)'
ncdf_attput, cdfid, raintypevarid, 'units', 'Categorical'
ncdf_attput, cdfid, raintypevarid, '_FillValue', RAINTYPE_MISSING

rayidxvarid = ncdf_vardef(cdfid, 'rayIndex', [xdimid,ydimid], /short)
ncdf_attput, cdfid, rayidxvarid, 'long_name', $
            'PR scan angle index, 0-48'
ncdf_attput, cdfid, rayidxvarid, '_FillValue', BB_MISSING

; Data time/location variables

timevarid = ncdf_vardef(cdfid, 'timeNearestApproach', /double)
ncdf_attput, cdfid, timevarid, 'units', 'seconds'
ncdf_attput, cdfid, timevarid, 'long_name', 'Seconds since 01-01-1970 00:00:00'
ncdf_attput, cdfid, timevarid, '_FillValue', 0.0D+0

atimedimid = ncdf_dimdef(cdfid, 'len_atime_ID', STRLEN('01-01-1970 00:00:00'))
atimevarid = ncdf_vardef(cdfid, 'atimeNearestApproach', [atimedimid], /char)
ncdf_attput, cdfid, atimevarid, 'long_name', $
            'text version of timeNearestApproach, UTC'

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
ncdf_attput, cdfid, vnversvarid, 'long_name', 'PR Grids Version'
;
ncdf_control, cdfid, /endef
;
ncdf_varput, cdfid, zvarid, z
ncdf_varput, cdfid, dxvarid, DX
ncdf_varput, cdfid, dyvarid, DY
ncdf_varput, cdfid, sitevarid, '----'
ncdf_varput, cdfid, atimevarid, '01-01-1970 00:00:00'
ncdf_varput, cdfid, vnversvarid, PR_NC_FILE_VERS
;
ncdf_close, cdfid

template_file = TEMPLATE_PR

end
