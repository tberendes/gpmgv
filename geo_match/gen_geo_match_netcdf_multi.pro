;+
; Copyright © 2010, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;
;-------------------------------------------------------------------------------
;
; gen_geo_match_netcdf_multi.pro    Bob Morris, GPM GV (SAIC)    September 2010
;
; DESCRIPTION:
; Using the "special values" parameters in the 'include' file pr_params.inc,
; the path parameters in environs.inc, and supplied parameters for the filename,
; number of PR footprints in the matchup, the array of elevation angles in the
; ground radar volume scan, and global variables for the UF data field used for
; GV reflectivity and the PR product version, creates an empty PR/GV matchup
; netCDF file in directory OUTDIR.
;
; The input file name supplied is expected to be a complete file basename and
; to contain fields for YYMMDD, the TRMM orbit number, and the ID of the ground
; radar site, as well as the '.nc' file extension.  No checking of the file name
; pre-existence, uniqueness, or conformance is performed in this module.
;
; HISTORY:
; 09/17/2007  Morris           Created.
; 06/15/2009  Morris           Pass in fully-qualified pathname to output netCDF
;                              files as geo_match_nc_file parameter.  Extract
;                              path from this pathname and create it if needed.
; 09/02/2010  Morris           Created from gen_geo_match_netcdf.pro.
; 9/10/2010 by Bob Morris, GPM GV (SAIC)
;  - Add variable 'site_elev' to hold 'siteElev' parameter read out from
;    polar2pr control file.
;  - Document in their long names that topHeight and bottomHeight are above
;    ground level (AGL) heights, and that BBheight is height above MSL.
;-------------------------------------------------------------------------------
;-

FUNCTION gen_geo_match_netcdf_multi, geo_match_nc_file, numpts, elev_angles, $
                                     nvols, gv_UF_field, PR_vers

; "Include" files for constants, names, paths, etc.
@environs.inc   ; for file prefixes, netCDF file definition version
@pr_params.inc  ; for the type-specific fill values

; Create the output dir for the netCDF file, if needed:
OUTDIR = FILE_DIRNAME(geo_match_nc_file)
spawn, 'mkdir -p ' + OUTDIR

cdfid = ncdf_create(geo_match_nc_file, /CLOBBER)

; global variables
ncdf_attput, cdfid, 'PR_Version', PR_vers, /short, /global
ncdf_attput, cdfid, 'GV_UF_Z_field', gv_UF_field, /global

; field dimensions

fpdimid = ncdf_dimdef(cdfid, 'fpdim', numpts)  ; # of PR footprints within range
eldimid = ncdf_dimdef(cdfid, 'elevationAngle', N_ELEMENTS(elev_angles))
voldimid = ncdf_dimdef(cdfid, 'voldim', nvols)  ; # of GR volume scans included
xydimid = ncdf_dimdef(cdfid, 'xydim', 4)  ; for 4 corners of a PR footprint

; Elevation Angles coordinate variable

elvarid = ncdf_vardef(cdfid, 'elevationAngle', [eldimid])
ncdf_attput, cdfid, elvarid, 'long_name', $
            'Radar Sweep Elevation Angles'
ncdf_attput, cdfid, elvarid, 'units', 'degrees'

; scalar fields

rngthreshid = ncdf_vardef(cdfid, 'rangeThreshold')
ncdf_attput, cdfid, rngthreshid, 'long_name', $
             'Dataset maximum range from radar site'
ncdf_attput, cdfid, rngthreshid, '_FillValue', FLOAT_RANGE_EDGE
ncdf_attput, cdfid, rngthreshid, 'units', 'km'

prdbzthreshid = ncdf_vardef(cdfid, 'PR_dBZ_min')
ncdf_attput, cdfid, prdbzthreshid, 'long_name', $
             'minimum PR bin dBZ required for a *complete* PR vertical average'
ncdf_attput, cdfid, prdbzthreshid, '_FillValue', FLOAT_RANGE_EDGE
ncdf_attput, cdfid, prdbzthreshid, 'units', 'dBZ'

gvdbzthreshid = ncdf_vardef(cdfid, 'GV_dBZ_min')
ncdf_attput, cdfid, gvdbzthreshid, 'long_name', $
             'minimum GV bin dBZ required for a *complete* GV horizontal average'
ncdf_attput, cdfid, gvdbzthreshid, '_FillValue', FLOAT_RANGE_EDGE
ncdf_attput, cdfid, gvdbzthreshid, 'units', 'dBZ'

rainthreshid = ncdf_vardef(cdfid, 'rain_min')
ncdf_attput, cdfid, rainthreshid, 'long_name', $
             'minimum PR rainrate required for a *complete* PR vertical average'
ncdf_attput, cdfid, rainthreshid, '_FillValue', FLOAT_RANGE_EDGE
ncdf_attput, cdfid, rainthreshid, 'units', 'mm/h'

; Data existence (non-fill) flags for science fields

havedbzgvvarid = ncdf_vardef(cdfid, 'have_threeDreflect', /short)
ncdf_attput, cdfid, havedbzgvvarid, 'long_name', $
             'data exists flag for threeDreflect'
ncdf_attput, cdfid, havedbzgvvarid, '_FillValue', 1

havedbzrawvarid = ncdf_vardef(cdfid, 'have_dBZnormalSample', /short)
ncdf_attput, cdfid, havedbzrawvarid, 'long_name', $
             'data exists flag for dBZnormalSample'
ncdf_attput, cdfid, havedbzrawvarid, '_FillValue', 1

havedbzvarid = ncdf_vardef(cdfid, 'have_correctZFactor', /short)
ncdf_attput, cdfid, havedbzvarid, 'long_name', $
             'data exists flag for correctZFactor'
ncdf_attput, cdfid, havedbzvarid, '_FillValue', 1

haverainvarid = ncdf_vardef(cdfid, 'have_rain', /short)
ncdf_attput, cdfid, haverainvarid, 'long_name', $
             'data exists flag for rain'
ncdf_attput, cdfid, haverainvarid, '_FillValue', 1

havelandoceanvarid = ncdf_vardef(cdfid, 'have_landOceanFlag', /short)
ncdf_attput, cdfid, havelandoceanvarid, 'long_name', $
             'data exists flag for landOceanFlag'
ncdf_attput, cdfid, havelandoceanvarid, '_FillValue', 1

havesfrainvarid = ncdf_vardef(cdfid, 'have_nearSurfRain', /short)
ncdf_attput, cdfid, havesfrainvarid, 'long_name', $
             'data exists flag for nearSurfRain'
ncdf_attput, cdfid, havesfrainvarid, '_FillValue', 1

havesfrain_2b31_varid = ncdf_vardef(cdfid, 'have_nearSurfRain_2b31', /short)
ncdf_attput, cdfid, havesfrain_2b31_varid, 'long_name', $
             'data exists flag for nearSurfRain_2b31'
ncdf_attput, cdfid, havesfrain_2b31_varid, '_FillValue', 1

havebbvarid = ncdf_vardef(cdfid, 'have_BBheight', /short)
ncdf_attput, cdfid, havebbvarid, 'long_name', 'data exists flag for BBheight'
ncdf_attput, cdfid, havebbvarid, '_FillValue', 1

haverainflagvarid = ncdf_vardef(cdfid, 'have_rainFlag', /short)
ncdf_attput, cdfid, haverainflagvarid, 'long_name', $
             'data exists flag for rainFlag'
ncdf_attput, cdfid, haverainflagvarid, '_FillValue', 1

haveraintypevarid = ncdf_vardef(cdfid, 'have_rainType', /short)
ncdf_attput, cdfid, haveraintypevarid, 'long_name', $
             'data exists flag for rainType'
ncdf_attput, cdfid, haveraintypevarid, '_FillValue', 1

;haverayidxvarid = ncdf_vardef(cdfid, 'have_rayIndex', /short)
;ncdf_attput, cdfid, haverayidxvarid, 'long_name', $
;             'data exists flag for rayIndex'
;ncdf_attput, cdfid, haverayidxvarid, '_FillValue', 1

; sweep-level fields

latvarid = ncdf_vardef(cdfid, 'latitude', [fpdimid,eldimid])
ncdf_attput, cdfid, latvarid, 'long_name', 'Latitude of data sample'
ncdf_attput, cdfid, latvarid, 'units', 'degrees North'
ncdf_attput, cdfid, latvarid, '_FillValue', FLOAT_RANGE_EDGE

lonvarid = ncdf_vardef(cdfid, 'longitude', [fpdimid,eldimid])
ncdf_attput, cdfid, lonvarid, 'long_name', 'Longitude of data sample'
ncdf_attput, cdfid, lonvarid, 'units', 'degrees East'
ncdf_attput, cdfid, lonvarid, '_FillValue', FLOAT_RANGE_EDGE

xvarid = ncdf_vardef(cdfid, 'xCorners', [xydimid,fpdimid,eldimid])
ncdf_attput, cdfid, xvarid, 'long_name', 'data sample x corner coords.'
ncdf_attput, cdfid, xvarid, 'units', 'km'
ncdf_attput, cdfid, xvarid, '_FillValue', FLOAT_RANGE_EDGE

yvarid = ncdf_vardef(cdfid, 'yCorners', [xydimid,fpdimid,eldimid])
ncdf_attput, cdfid, yvarid, 'long_name', 'data sample y corner coords.'
ncdf_attput, cdfid, yvarid, 'units', 'km'
ncdf_attput, cdfid, yvarid, '_FillValue', FLOAT_RANGE_EDGE

topvarid = ncdf_vardef(cdfid, 'topHeight', [fpdimid,eldimid])
ncdf_attput, cdfid, topvarid, 'long_name', 'data sample top height AGL'
ncdf_attput, cdfid, topvarid, 'units', 'km'
ncdf_attput, cdfid, topvarid, '_FillValue', FLOAT_RANGE_EDGE

botmvarid = ncdf_vardef(cdfid, 'bottomHeight', [fpdimid,eldimid])
ncdf_attput, cdfid, botmvarid, 'long_name', 'data sample bottom height AGL'
ncdf_attput, cdfid, botmvarid, 'units', 'km'
ncdf_attput, cdfid, botmvarid, '_FillValue', FLOAT_RANGE_EDGE

dbzgvvarid = ncdf_vardef(cdfid, 'threeDreflect', [fpdimid,eldimid,voldimid])
ncdf_attput, cdfid, dbzgvvarid, 'long_name', 'GV radar QC Reflectivity'
ncdf_attput, cdfid, dbzgvvarid, 'units', 'dBZ'
ncdf_attput, cdfid, dbzgvvarid, '_FillValue', FLOAT_RANGE_EDGE

dbzrawvarid = ncdf_vardef(cdfid, 'dBZnormalSample', [fpdimid,eldimid])
ncdf_attput, cdfid, dbzrawvarid, 'long_name', '1C-21 Uncorrected Reflectivity'
ncdf_attput, cdfid, dbzrawvarid, 'units', 'dBZ'
ncdf_attput, cdfid, dbzrawvarid, '_FillValue', FLOAT_RANGE_EDGE

dbzvarid = ncdf_vardef(cdfid, 'correctZFactor', [fpdimid,eldimid])
ncdf_attput, cdfid, dbzvarid, 'long_name', $
            '2A-25 Attenuation-corrected Reflectivity'
ncdf_attput, cdfid, dbzvarid, 'units', 'dBZ'
ncdf_attput, cdfid, dbzvarid, '_FillValue', FLOAT_RANGE_EDGE

rainvarid = ncdf_vardef(cdfid, 'rain', [fpdimid,eldimid])
ncdf_attput, cdfid, rainvarid, 'long_name', '2A-25 Estimated Rain Rate'
ncdf_attput, cdfid, rainvarid, 'units', 'mm/h'
ncdf_attput, cdfid, rainvarid, '_FillValue', FLOAT_RANGE_EDGE

gvrejvarid = ncdf_vardef(cdfid, 'n_gv_rejected', [fpdimid,eldimid,voldimid], /short)
ncdf_attput, cdfid, gvrejvarid, 'long_name', $
             'number of bins below GV_dBZ_min in threeDreflect average'
ncdf_attput, cdfid, gvrejvarid, '_FillValue', INT_RANGE_EDGE

gvexpvarid = ncdf_vardef(cdfid, 'n_gv_expected', [fpdimid,eldimid,voldimid], /short)
ncdf_attput, cdfid, gvexpvarid, 'long_name', $
             'number of bins in GV threeDreflect average'
ncdf_attput, cdfid, gvexpvarid, '_FillValue', INT_RANGE_EDGE

rawZrejvarid = ncdf_vardef(cdfid, 'n_1c21_z_rejected', [fpdimid,eldimid], /short)
ncdf_attput, cdfid, rawZrejvarid, 'long_name', $
             'number of bins below PR_dBZ_min in dBZnormalSample average'
ncdf_attput, cdfid, rawZrejvarid, '_FillValue', INT_RANGE_EDGE

corZrejvarid = ncdf_vardef(cdfid, 'n_2a25_z_rejected', [fpdimid,eldimid], /short)
ncdf_attput, cdfid, corZrejvarid, 'long_name', $
             'number of bins below PR_dBZ_min in correctZFactor average'
ncdf_attput, cdfid, corZrejvarid, '_FillValue', INT_RANGE_EDGE

rainrejvarid = ncdf_vardef(cdfid, 'n_2a25_r_rejected', [fpdimid,eldimid], /short)
ncdf_attput, cdfid, rainrejvarid, 'long_name', $
             'number of bins below rain_min in rain average'
ncdf_attput, cdfid, rainrejvarid, '_FillValue', INT_RANGE_EDGE

prexpvarid = ncdf_vardef(cdfid, 'n_pr_expected', [fpdimid,eldimid], /short)
ncdf_attput, cdfid, prexpvarid, 'long_name', 'number of bins in PR averages'
ncdf_attput, cdfid, prexpvarid, '_FillValue', INT_RANGE_EDGE

; single-level fields

sfclatvarid = ncdf_vardef(cdfid, 'PRlatitude', [fpdimid])
ncdf_attput, cdfid, sfclatvarid, 'long_name', 'Latitude of PR surface bin'
ncdf_attput, cdfid, sfclatvarid, 'units', 'degrees North'
ncdf_attput, cdfid, sfclatvarid, '_FillValue', FLOAT_RANGE_EDGE

sfclonvarid = ncdf_vardef(cdfid, 'PRlongitude', [fpdimid])
ncdf_attput, cdfid, sfclonvarid, 'long_name', 'Longitude of PR surface bin'
ncdf_attput, cdfid, sfclonvarid, 'units', 'degrees East'
ncdf_attput, cdfid, sfclonvarid, '_FillValue', FLOAT_RANGE_EDGE

landoceanvarid = ncdf_vardef(cdfid, 'landOceanFlag', [fpdimid], /short)
ncdf_attput, cdfid, landoceanvarid, 'long_name', '1C-21 Land/Ocean Flag'
ncdf_attput, cdfid, landoceanvarid, 'units', 'Categorical'
ncdf_attput, cdfid, landoceanvarid, '_FillValue', INT_RANGE_EDGE

sfrainvarid = ncdf_vardef(cdfid, 'nearSurfRain', [fpdimid])
ncdf_attput, cdfid, sfrainvarid, 'long_name', $
             '2A-25 Near-Surface Estimated Rain Rate'
ncdf_attput, cdfid, sfrainvarid, 'units', 'mm/h'
ncdf_attput, cdfid, sfrainvarid, '_FillValue', FLOAT_RANGE_EDGE

sfrain_2b31_varid = ncdf_vardef(cdfid, 'nearSurfRain_2b31', [fpdimid])
ncdf_attput, cdfid, sfrain_2b31_varid, 'long_name', $
            '2B-31 Near-Surface Estimated Rain Rate'
ncdf_attput, cdfid, sfrain_2b31_varid, 'units', 'mm/h'
ncdf_attput, cdfid, sfrain_2b31_varid, '_FillValue', FLOAT_RANGE_EDGE

bbvarid = ncdf_vardef(cdfid, 'BBheight', [fpdimid])
ncdf_attput, cdfid, bbvarid, 'long_name', $
            '2A-25 Bright Band Height above MSL from Range Bin Numbers'
ncdf_attput, cdfid, bbvarid, 'units', 'km'
ncdf_attput, cdfid, bbvarid, '_FillValue', FLOAT_RANGE_EDGE

rainflagvarid = ncdf_vardef(cdfid, 'rainFlag', [fpdimid], /short)
ncdf_attput, cdfid, rainflagvarid, 'long_name', '2A-25 Rain Flag (bitmap)'
ncdf_attput, cdfid, rainflagvarid, 'units', 'Categorical'
ncdf_attput, cdfid, rainflagvarid, '_FillValue', INT_RANGE_EDGE

raintypevarid = ncdf_vardef(cdfid, 'rainType', [fpdimid], /short)
ncdf_attput, cdfid, raintypevarid, 'long_name', $
            '2A-23 Rain Type (stratiform/convective/other)'
ncdf_attput, cdfid, raintypevarid, 'units', 'Categorical'
ncdf_attput, cdfid, raintypevarid, '_FillValue', INT_RANGE_EDGE

rayidxvarid = ncdf_vardef(cdfid, 'rayIndex', [fpdimid], /long)
ncdf_attput, cdfid, rayidxvarid, 'long_name', $
            'PR product-relative ray,scan IDL 1-D array index'
ncdf_attput, cdfid, rayidxvarid, '_FillValue', LONG_RANGE_EDGE

; Data time/location variables

timevarid = ncdf_vardef(cdfid, 'timeNearestApproach', /double)
ncdf_attput, cdfid, timevarid, 'units', 'seconds'
ncdf_attput, cdfid, timevarid, 'long_name', 'Seconds since 01-01-1970 00:00:00'
ncdf_attput, cdfid, timevarid, '_FillValue', 0.0D+0

atimedimid = ncdf_dimdef(cdfid, 'len_atime_ID', STRLEN('01-01-1970 00:00:00'))

atimevarid = ncdf_vardef(cdfid, 'atimeNearestApproach', [atimedimid], /char)
ncdf_attput, cdfid, atimevarid, 'long_name', $
            'text version of timeNearestApproach, UTC'

gvtimevarid = ncdf_vardef(cdfid, 'timeSweepStart', [eldimid,voldimid], /double)
ncdf_attput, cdfid, gvtimevarid, 'units', 'seconds'
ncdf_attput, cdfid, gvtimevarid, 'long_name', $
             'Seconds since 01-01-1970 00:00:00'
ncdf_attput, cdfid, gvtimevarid, '_FillValue', 0.0D+0

agvtimevarid = ncdf_vardef(cdfid, 'atimeSweepStart', $
                         [atimedimid,eldimid,voldimid], /char)
ncdf_attput, cdfid, agvtimevarid, 'long_name', $
            'text version of timeSweepStart, UTC'

sitedimid = ncdf_dimdef(cdfid, 'len_site_ID', STRLEN('KXXX'))
sitevarid = ncdf_vardef(cdfid, 'site_ID', [sitedimid], /char)
ncdf_attput, cdfid, sitevarid, 'long_name', 'ID of Ground Radar Site'

sitelatvarid = ncdf_vardef(cdfid, 'site_lat')
ncdf_attput, cdfid, sitelatvarid, 'long_name', 'Latitude of Ground Radar Site'
ncdf_attput, cdfid, sitelatvarid, 'units', 'degrees North'
ncdf_attput, cdfid, sitelatvarid, '_FillValue', FLOAT_RANGE_EDGE

sitelonvarid = ncdf_vardef(cdfid, 'site_lon')
ncdf_attput, cdfid, sitelonvarid, 'long_name', 'Longitude of Ground Radar Site'
ncdf_attput, cdfid, sitelonvarid, 'units', 'degrees East'
ncdf_attput, cdfid, sitelonvarid, '_FillValue', FLOAT_RANGE_EDGE

siteelevvarid = ncdf_vardef(cdfid, 'site_elev')
ncdf_attput, cdfid, siteelevvarid, 'long_name', 'Elevation of Ground Radar Site above MSL'
ncdf_attput, cdfid, siteelevvarid, 'units', 'km'

vnversvarid = ncdf_vardef(cdfid, 'version')
ncdf_attput, cdfid, vnversvarid, 'long_name', 'Geo Match File Version'
;
ncdf_control, cdfid, /endef
;
ncdf_varput, cdfid, elvarid, elev_angles
ncdf_varput, cdfid, sitevarid, '----'
ncdf_varput, cdfid, atimevarid, '01-01-1970 00:00:00'
FOR ivol = 0, nvols-1  DO BEGIN
   FOR iel = 0, N_ELEMENTS(elev_angles)-1  DO BEGIN
      ncdf_varput, cdfid, agvtimevarid, '01-01-1970 00:00:00', OFFSET=[0,iel,ivol]
   ENDFOR
ENDFOR
ncdf_varput, cdfid, vnversvarid, GEO_MATCH_NC_FILE_VERS
;
ncdf_close, cdfid

return, geo_match_nc_file

end
