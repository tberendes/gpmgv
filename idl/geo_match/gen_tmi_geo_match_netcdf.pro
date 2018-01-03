;+
; Copyright © 2011, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;
;-------------------------------------------------------------------------------
;
; gen_tmi_geo_match_netcdf.pro    Bob Morris, GPM GV (SAIC)    May 2011
;
; DESCRIPTION:
; Using the "special values" and path parameters in the 'include' files
; pr_params.inc, tmi_params.inc,  grid_def.inc, and environs.inc, and supplied
; parameters for the output netcdf file name, the number of TMI footprints
; in the matchup, the array of elevation angles in the ground radar volume scan,
; and global variables for the UF data field used for GR reflectivity and the
; TMI product version, creates an empty TMI/GV matchup netCDF file in directory
; OUTDIR.
;
; The input file name supplied is expected to be a complete file basename and
; to contain fields for YYMMDD, the TRMM orbit number, and the ID of the ground
; radar site, as well as the '.nc' file extension.  No checking of the file name
; pre-existence, uniqueness, or conformance is performed in this module.
;
; HISTORY:
; 05/09/2011 by Bob Morris, GPM GV (SAIC)
;  - Created.
; 05/18/2011 by Bob Morris, GPM GV (SAIC)
;  - Added second set of GR variables for samples along local vertical above
;    TMI surface footprint location (ignoring TMI viewing parallax).
;  - Added footprint-specific 2A-12 variables freezingHeight and Probability of
;    Precipitation (PoP).
; 11/15/11 by Bob Morris, GPM GV (SAIC)
;  - Added scalar variable for GR weighting function radius of influence.
; 01/20/12 by Bob Morris, GPM GV (SAIC)
;  - Added note that 'TMI_Version' must be the first GLOBAL variable defined in
;    the file.  We now check against this when reading netCDF files to make sure
;    it is the correct type of matchup file.
; 10/17/13 by Bob Morris, GPM GV (SAIC)
;  - Added GR RR variables for dual-pol rain rate, set GEO_MATCH_NC_FILE_VERSION
;    to 2.0 for major change to file format.
;-------------------------------------------------------------------------------
;-

FUNCTION gen_tmi_geo_match_netcdf, geo_match_nc_file, numpts, elev_angles, $
                                   gr_UF_field, TMI_vers, tmigrfiles,$
                                   GEO_MATCH_VERS=geo_match_vers

GEO_MATCH_NC_FILE_VERSION=2.0    ;ignore "Include" file definition now

IF ( N_ELEMENTS(geo_match_vers) NE 0 ) THEN BEGIN
   geo_match_vers = GEO_MATCH_NC_FILE_VERSION
ENDIF

IF ( N_PARAMS() LT 5 ) THEN GOTO, versionOnly

; "Include" file for DATA_PRESENT, NO_DATA_PRESENT
@grid_def.inc
; "Include" file for the type-specific fill values
@pr_params.inc  ; for the type-specific fill values

; Create the output directory for the netCDF file, if needed:
OUTDIR = FILE_DIRNAME(geo_match_nc_file)
spawn, 'mkdir -p ' + OUTDIR

cdfid = ncdf_create(geo_match_nc_file, /CLOBBER)

; global variables -- THE FIRST GLOBAL VARIABLE MUST BE 'TMI_Version'
ncdf_attput, cdfid, 'TMI_Version', TMI_vers, /short, /global
ncdf_attput, cdfid, 'GR_UF_Z_field', gr_UF_field, /global

; extract the input file names (if given) to be written out as global attributes
; or define placeholder values to write
IF ( N_PARAMS() EQ 6 ) THEN BEGIN

   idxfiles = lonarr( N_ELEMENTS(tmigrfiles) )
   idx12 = WHERE(STRPOS(tmigrfiles,'2A12') GE 0, count12)
   if count12 EQ 1 THEN BEGIN
      origFile12Name = STRJOIN(STRTRIM(tmigrfiles[idx12],2))
      idxfiles[idx12] = 1
   endif ELSE origFile12Name='no_2A12_file'

  ; this should never happen, but for completeness...
   idxgr = WHERE(idxfiles EQ 0, countgr)
   if countgr EQ 1 THEN BEGIN
      origGRFileName = STRJOIN(STRTRIM(tmigrfiles[idxgr],2))
      idxfiles[idxgr] = 1
   endif ELSE origGRFileName='no_1CUF_file'

ENDIF ELSE BEGIN
   origFile12Name='Unspecified'
   origGRFileName='Unspecified'
ENDELSE

ncdf_attput, cdfid, 'TMI_2A12_file', origFile12Name, /global
ncdf_attput, cdfid, 'GR_file', origGRFileName, /global


; field dimensions

fpdimid = ncdf_dimdef(cdfid, 'fpdim', numpts)  ; # TMI footprints within range
eldimid = ncdf_dimdef(cdfid, 'elevationAngle', N_ELEMENTS(elev_angles))
xydimid = ncdf_dimdef(cdfid, 'xydim', 4)       ; 4 corners of a TMI footprint

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

gvdbzthreshid = ncdf_vardef(cdfid, 'GR_dBZ_min')
ncdf_attput, cdfid, gvdbzthreshid, 'long_name', $
             'minimum GR bin dBZ required for a *complete* GR horizontal average'
ncdf_attput, cdfid, gvdbzthreshid, '_FillValue', FLOAT_RANGE_EDGE
ncdf_attput, cdfid, gvdbzthreshid, 'units', 'dBZ'

rainthreshid = ncdf_vardef(cdfid, 'tmi_rain_min')
ncdf_attput, cdfid, rainthreshid, 'long_name', $
             'minimum TMI rainrate required'
ncdf_attput, cdfid, rainthreshid, '_FillValue', FLOAT_RANGE_EDGE
ncdf_attput, cdfid, rainthreshid, 'units', 'mm/h'

rngthreshid = ncdf_vardef(cdfid, 'radiusOfInfluence')
ncdf_attput, cdfid, rngthreshid, 'long_name', $
             'Radius of influence for distance weighting of GR bins'
ncdf_attput, cdfid, rngthreshid, '_FillValue', FLOAT_RANGE_EDGE
ncdf_attput, cdfid, rngthreshid, 'units', 'km'

; Data existence (non-fill) flags for science fields

havedbzgvvarid = ncdf_vardef(cdfid, 'have_GR_Z_along_TMI', /short)
ncdf_attput, cdfid, havedbzgvvarid, 'long_name', $
             'data exists flag for GR_Z_along_TMI'
ncdf_attput, cdfid, havedbzgvvarid, '_FillValue', NO_DATA_PRESENT

havestddevgvvarid = ncdf_vardef(cdfid, 'have_GR_Z_StdDev_along_TMI', /short)
ncdf_attput, cdfid, havestddevgvvarid, 'long_name', $
             'data exists flag for GR_Z_StdDev_along_TMI'
ncdf_attput, cdfid, havestddevgvvarid, '_FillValue', NO_DATA_PRESENT

havegvmaxvarid = ncdf_vardef(cdfid, 'have_GR_Z_Max_along_TMI', /short)
ncdf_attput, cdfid, havegvmaxvarid, 'long_name', $
             'data exists flag for GR_Z_Max_along_TMI'
ncdf_attput, cdfid, havegvmaxvarid, '_FillValue', NO_DATA_PRESENT

havegvrrvarid = ncdf_vardef(cdfid, 'have_GR_RR_along_TMI', /short)
ncdf_attput, cdfid, havegvrrvarid, 'long_name', $
             'data exists flag for GR_RR_along_TMI'
ncdf_attput, cdfid, havegvrrvarid, '_FillValue', NO_DATA_PRESENT

havestddevgvrrvarid = ncdf_vardef(cdfid, 'have_GR_RR_StdDev_along_TMI', /short)
ncdf_attput, cdfid, havestddevgvrrvarid, 'long_name', $
             'data exists flag for GR_RR_StdDev_along_TMI'
ncdf_attput, cdfid, havestddevgvrrvarid, '_FillValue', NO_DATA_PRESENT

havegvrrmaxvarid = ncdf_vardef(cdfid, 'have_GR_RR_Max_along_TMI', /short)
ncdf_attput, cdfid, havegvrrmaxvarid, 'long_name', $
             'data exists flag for GR_RR_Max_along_TMI'
ncdf_attput, cdfid, havegvrrmaxvarid, '_FillValue', NO_DATA_PRESENT

havedbzgvvarid_vpr = ncdf_vardef(cdfid, 'have_GR_Z_VPR', /short)
ncdf_attput, cdfid, havedbzgvvarid_vpr, 'long_name', $
             'data exists flag for GR_Z_VPR'
ncdf_attput, cdfid, havedbzgvvarid_vpr, '_FillValue', NO_DATA_PRESENT

havestddevgvvarid_vpr = ncdf_vardef(cdfid, 'have_GR_Z_StdDev_VPR', /short)
ncdf_attput, cdfid, havestddevgvvarid_vpr, 'long_name', $
             'data exists flag for GR_Z_StdDev_VPR'
ncdf_attput, cdfid, havestddevgvvarid_vpr, '_FillValue', NO_DATA_PRESENT

havegvmaxvarid_vpr = ncdf_vardef(cdfid, 'have_GR_Z_Max_VPR', /short)
ncdf_attput, cdfid, havegvmaxvarid_vpr, 'long_name', $
             'data exists flag for GR_Z_Max_VPR'
ncdf_attput, cdfid, havegvmaxvarid_vpr, '_FillValue', NO_DATA_PRESENT

havegvrrvarid_vpr = ncdf_vardef(cdfid, 'have_GR_RR_VPR', /short)
ncdf_attput, cdfid, havegvrrvarid_vpr, 'long_name', $
             'data exists flag for GR_RR_VPR'
ncdf_attput, cdfid, havegvrrvarid_vpr, '_FillValue', NO_DATA_PRESENT

havestddevgvrrvarid_vpr = ncdf_vardef(cdfid, 'have_GR_RR_StdDev_VPR', /short)
ncdf_attput, cdfid, havestddevgvrrvarid_vpr, 'long_name', $
             'data exists flag for GR_RR_StdDev_VPR'
ncdf_attput, cdfid, havestddevgvrrvarid_vpr, '_FillValue', NO_DATA_PRESENT

havegvrrmaxvarid_vpr = ncdf_vardef(cdfid, 'have_GR_RR_Max_VPR', /short)
ncdf_attput, cdfid, havegvrrmaxvarid_vpr, 'long_name', $
             'data exists flag for GR_RR_Max_VPR'
ncdf_attput, cdfid, havegvrrmaxvarid_vpr, '_FillValue', NO_DATA_PRESENT

havesurfaceTypevarid = ncdf_vardef(cdfid, 'have_surfaceType', /short)
ncdf_attput, cdfid, havesurfaceTypevarid, 'long_name', $
             'data exists flag for surfaceType'
ncdf_attput, cdfid, havesurfaceTypevarid, '_FillValue', NO_DATA_PRESENT

havesfrainvarid = ncdf_vardef(cdfid, 'have_surfaceRain', /short)
ncdf_attput, cdfid, havesfrainvarid, 'long_name', $
             'data exists flag for surfaceRain'
ncdf_attput, cdfid, havesfrainvarid, '_FillValue', NO_DATA_PRESENT

haverainflagvarid = ncdf_vardef(cdfid, 'have_rainFlag', /short)
ncdf_attput, cdfid, haverainflagvarid, 'long_name', $
             'data exists flag for rainFlag'
ncdf_attput, cdfid, haverainflagvarid, '_FillValue', NO_DATA_PRESENT

havedataFlagvarid = ncdf_vardef(cdfid, 'have_dataFlag', /short)
ncdf_attput, cdfid, havedataFlagvarid, 'long_name', $
             'data exists flag for dataFlag'
ncdf_attput, cdfid, havedataFlagvarid, '_FillValue', NO_DATA_PRESENT

havePoPvarid = ncdf_vardef(cdfid, 'have_PoP', /short)
ncdf_attput, cdfid, havePoPvarid, 'long_name', $
             'data exists flag for PoP'
ncdf_attput, cdfid, havePoPvarid, '_FillValue', NO_DATA_PRESENT

havefreezingHeightvarid = ncdf_vardef(cdfid, 'have_freezingHeight', /short)
ncdf_attput, cdfid, havefreezingHeightvarid, 'long_name', $
             'data exists flag for freezingHeight'
ncdf_attput, cdfid, havefreezingHeightvarid, '_FillValue', NO_DATA_PRESENT

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

topvarid_vpr = ncdf_vardef(cdfid, 'topHeight_vpr', [fpdimid,eldimid])
ncdf_attput, cdfid, topvarid_vpr, 'long_name', 'data sample top height AGL along local vertical'
ncdf_attput, cdfid, topvarid_vpr, 'units', 'km'
ncdf_attput, cdfid, topvarid_vpr, '_FillValue', FLOAT_RANGE_EDGE

botmvarid_vpr = ncdf_vardef(cdfid, 'bottomHeight_vpr', [fpdimid,eldimid])
ncdf_attput, cdfid, botmvarid_vpr, 'long_name', 'data sample bottom height AGL along local vertical'
ncdf_attput, cdfid, botmvarid_vpr, 'units', 'km'
ncdf_attput, cdfid, botmvarid_vpr, '_FillValue', FLOAT_RANGE_EDGE

dbzgvvarid = ncdf_vardef(cdfid, 'GR_Z_along_TMI', [fpdimid,eldimid])
ncdf_attput, cdfid, dbzgvvarid, 'long_name', 'GV radar QC Reflectivity'
ncdf_attput, cdfid, dbzgvvarid, 'units', 'dBZ'
ncdf_attput, cdfid, dbzgvvarid, '_FillValue', FLOAT_RANGE_EDGE

stddevgvvarid = ncdf_vardef(cdfid, 'GR_Z_StdDev_along_TMI', [fpdimid,eldimid])
ncdf_attput, cdfid, stddevgvvarid, 'long_name', 'Standard Deviation of GV radar QC Reflectivity'
ncdf_attput, cdfid, stddevgvvarid, 'units', 'dBZ'
ncdf_attput, cdfid, stddevgvvarid, '_FillValue', FLOAT_RANGE_EDGE

gvmaxvarid = ncdf_vardef(cdfid, 'GR_Z_Max_along_TMI', [fpdimid,eldimid])
ncdf_attput, cdfid, gvmaxvarid, 'long_name', 'Sample Maximum GV radar QC Reflectivity'
ncdf_attput, cdfid, gvmaxvarid, 'units', 'dBZ'
ncdf_attput, cdfid, gvmaxvarid, '_FillValue', FLOAT_RANGE_EDGE

gvrrvarid = ncdf_vardef(cdfid, 'GR_RR_along_TMI', [fpdimid,eldimid])
ncdf_attput, cdfid, gvrrvarid, 'long_name', 'GV radar QC Rain Rate'
ncdf_attput, cdfid, gvrrvarid, 'units', 'dBZ'
ncdf_attput, cdfid, gvrrvarid, '_FillValue', FLOAT_RANGE_EDGE

stddevgvrrvarid = ncdf_vardef(cdfid, 'GR_RR_StdDev_along_TMI', [fpdimid,eldimid])
ncdf_attput, cdfid, stddevgvrrvarid, 'long_name', 'Standard Deviation of GV radar QC Rain Rate'
ncdf_attput, cdfid, stddevgvrrvarid, 'units', 'dBZ'
ncdf_attput, cdfid, stddevgvrrvarid, '_FillValue', FLOAT_RANGE_EDGE

gvrrmaxvarid = ncdf_vardef(cdfid, 'GR_RR_Max_along_TMI', [fpdimid,eldimid])
ncdf_attput, cdfid, gvrrmaxvarid, 'long_name', 'Sample Maximum GV radar QC Rain Rate'
ncdf_attput, cdfid, gvrrmaxvarid, 'units', 'dBZ'
ncdf_attput, cdfid, gvrrmaxvarid, '_FillValue', FLOAT_RANGE_EDGE

gvrejvarid = ncdf_vardef(cdfid, 'n_gr_rejected', [fpdimid,eldimid], /short)
ncdf_attput, cdfid, gvrejvarid, 'long_name', $
             'number of bins below GR_dBZ_min in GR_Z_along_TMI average'
ncdf_attput, cdfid, gvrejvarid, '_FillValue', INT_RANGE_EDGE

gvrrrejvarid = ncdf_vardef(cdfid, 'n_gr_rr_rejected', [fpdimid,eldimid], /short)
ncdf_attput, cdfid, gvrrrejvarid, 'long_name', $
             'number of bins below tmi_rain_min in GR_RR_along_TMI average'
ncdf_attput, cdfid, gvrrrejvarid, '_FillValue', INT_RANGE_EDGE

gvexpvarid = ncdf_vardef(cdfid, 'n_gr_expected', [fpdimid,eldimid], /short)
ncdf_attput, cdfid, gvexpvarid, 'long_name', $
             'number of bins in GR_Z_along_TMI, GR_RR_along_TMI averages'
ncdf_attput, cdfid, gvexpvarid, '_FillValue', INT_RANGE_EDGE

dbzgvvarid_vpr = ncdf_vardef(cdfid, 'GR_Z_VPR', [fpdimid,eldimid])
ncdf_attput, cdfid, dbzgvvarid_vpr, 'long_name', 'GV radar QC Reflectivity along local vertical'
ncdf_attput, cdfid, dbzgvvarid_vpr, 'units', 'dBZ'
ncdf_attput, cdfid, dbzgvvarid_vpr, '_FillValue', FLOAT_RANGE_EDGE

stddevgvvarid_vpr = ncdf_vardef(cdfid, 'GR_Z_StdDev_VPR', [fpdimid,eldimid])
ncdf_attput, cdfid, stddevgvvarid_vpr, 'long_name', $
   'Standard Deviation of GV radar QC Reflectivity along local vertical'
ncdf_attput, cdfid, stddevgvvarid_vpr, 'units', 'dBZ'
ncdf_attput, cdfid, stddevgvvarid_vpr, '_FillValue', FLOAT_RANGE_EDGE

gvmaxvarid_vpr = ncdf_vardef(cdfid, 'GR_Z_Max_VPR', [fpdimid,eldimid])
ncdf_attput, cdfid, gvmaxvarid_vpr, 'long_name', $
   'Sample Maximum GV radar QC Reflectivity along local vertical'
ncdf_attput, cdfid, gvmaxvarid_vpr, 'units', 'dBZ'
ncdf_attput, cdfid, gvmaxvarid_vpr, '_FillValue', FLOAT_RANGE_EDGE

gvrrvarid_vpr = ncdf_vardef(cdfid, 'GR_RR_VPR', [fpdimid,eldimid])
ncdf_attput, cdfid, gvrrvarid_vpr, 'long_name', 'GV radar QC Rain Rate along local vertical'
ncdf_attput, cdfid, gvrrvarid_vpr, 'units', 'dBZ'
ncdf_attput, cdfid, gvrrvarid_vpr, '_FillValue', FLOAT_RANGE_EDGE

stddevgvrrvarid_vpr = ncdf_vardef(cdfid, 'GR_RR_StdDev_VPR', [fpdimid,eldimid])
ncdf_attput, cdfid, stddevgvrrvarid_vpr, 'long_name', $
   'Standard Deviation of GV radar QC Rain Rate along local vertical'
ncdf_attput, cdfid, stddevgvrrvarid_vpr, 'units', 'dBZ'
ncdf_attput, cdfid, stddevgvrrvarid_vpr, '_FillValue', FLOAT_RANGE_EDGE

gvrrmaxvarid_vpr = ncdf_vardef(cdfid, 'GR_RR_Max_VPR', [fpdimid,eldimid])
ncdf_attput, cdfid, gvrrmaxvarid_vpr, 'long_name', $
   'Sample Maximum GV radar QC Rain Rate along local vertical'
ncdf_attput, cdfid, gvrrmaxvarid_vpr, 'units', 'dBZ'
ncdf_attput, cdfid, gvrrmaxvarid_vpr, '_FillValue', FLOAT_RANGE_EDGE

gvrejvarid_vpr = ncdf_vardef(cdfid, 'n_gr_vpr_rejected', [fpdimid,eldimid], /short)
ncdf_attput, cdfid, gvrejvarid_vpr, 'long_name', $
             'number of bins below GR_dBZ_min in GR_Z_VPR average'
ncdf_attput, cdfid, gvrejvarid_vpr, '_FillValue', INT_RANGE_EDGE

gvrrrejvarid_vpr = ncdf_vardef(cdfid, 'n_gr_rr_vpr_rejected', [fpdimid,eldimid], /short)
ncdf_attput, cdfid, gvrrrejvarid_vpr, 'long_name', $
             'number of bins below tmi_rain_min in GR_RR_VPR average'
ncdf_attput, cdfid, gvrrrejvarid_vpr, '_FillValue', INT_RANGE_EDGE

gvexpvarid_vpr = ncdf_vardef(cdfid, 'n_gr_vpr_expected', [fpdimid,eldimid], /short)
ncdf_attput, cdfid, gvexpvarid_vpr, 'long_name', $
             'number of bins in GR_Z_VPR, GR_RR_VPR averages'
ncdf_attput, cdfid, gvexpvarid_vpr, '_FillValue', INT_RANGE_EDGE

; single-level fields

sfclatvarid = ncdf_vardef(cdfid, 'TMIlatitude', [fpdimid])
ncdf_attput, cdfid, sfclatvarid, 'long_name', 'Latitude of TMI surface bin'
ncdf_attput, cdfid, sfclatvarid, 'units', 'degrees North'
ncdf_attput, cdfid, sfclatvarid, '_FillValue', FLOAT_RANGE_EDGE

sfclonvarid = ncdf_vardef(cdfid, 'TMIlongitude', [fpdimid])
ncdf_attput, cdfid, sfclonvarid, 'long_name', 'Longitude of TMI surface bin'
ncdf_attput, cdfid, sfclonvarid, 'units', 'degrees East'
ncdf_attput, cdfid, sfclonvarid, '_FillValue', FLOAT_RANGE_EDGE

surfaceTypevarid = ncdf_vardef(cdfid, 'surfaceType', [fpdimid], /short)
ncdf_attput, cdfid, surfaceTypevarid, 'long_name', '2A-12 Land/Ocean Flag'
ncdf_attput, cdfid, surfaceTypevarid, 'units', 'Categorical'
ncdf_attput, cdfid, surfaceTypevarid, '_FillValue', INT_RANGE_EDGE

sfrainvarid = ncdf_vardef(cdfid, 'surfaceRain', [fpdimid])
ncdf_attput, cdfid, sfrainvarid, 'long_name', $
             '2A-12 Estimated Surface Rain Rate'
ncdf_attput, cdfid, sfrainvarid, 'units', 'mm/h'
ncdf_attput, cdfid, sfrainvarid, '_FillValue', FLOAT_RANGE_EDGE

rainflagvarid = ncdf_vardef(cdfid, 'rainFlag', [fpdimid], /short)
ncdf_attput, cdfid, rainflagvarid, 'long_name', '2A-12 Rain Flag (V6 only)'
ncdf_attput, cdfid, rainflagvarid, 'units', 'Categorical'
ncdf_attput, cdfid, rainflagvarid, '_FillValue', INT_RANGE_EDGE

dataFlagvarid = ncdf_vardef(cdfid, 'dataFlag', [fpdimid], /short)
ncdf_attput, cdfid, dataFlagvarid, 'long_name', $
            '2A-12 Data Flag (V7) or PixelStatus (V6)'
ncdf_attput, cdfid, dataFlagvarid, 'units', 'Categorical'
ncdf_attput, cdfid, dataFlagvarid, '_FillValue', INT_RANGE_EDGE

PoPvarid = ncdf_vardef(cdfid, 'PoP', [fpdimid], /short)
ncdf_attput, cdfid, PoPvarid, 'long_name', $
            '2A-12 Probability of Precipitation'
ncdf_attput, cdfid, PoPvarid, 'units', 'percent'
ncdf_attput, cdfid, PoPvarid, '_FillValue', INT_RANGE_EDGE

freezingHeightvarid = ncdf_vardef(cdfid, 'freezingHeight', [fpdimid], /short)
ncdf_attput, cdfid, freezingHeightvarid, 'long_name', $
            '2A-12 Freezing Height'
ncdf_attput, cdfid, freezingHeightvarid, 'units', 'meters'
ncdf_attput, cdfid, freezingHeightvarid, '_FillValue', INT_RANGE_EDGE

rayidxvarid = ncdf_vardef(cdfid, 'rayIndex', [fpdimid], /long)
ncdf_attput, cdfid, rayidxvarid, 'long_name', $
            'TMI product-relative ray,scan IDL 1-D array index'
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

gvtimevarid = ncdf_vardef(cdfid, 'timeSweepStart', [eldimid], /double)
ncdf_attput, cdfid, gvtimevarid, 'units', 'seconds'
ncdf_attput, cdfid, gvtimevarid, 'long_name', $
             'Seconds since 01-01-1970 00:00:00'
ncdf_attput, cdfid, gvtimevarid, '_FillValue', 0.0D+0

agvtimevarid = ncdf_vardef(cdfid, 'atimeSweepStart', $
                         [atimedimid,eldimid], /char)
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
FOR iel = 0,N_ELEMENTS(elev_angles)-1 DO BEGIN
   ncdf_varput, cdfid, agvtimevarid, '01-01-1970 00:00:00', OFFSET=[0,iel]
ENDFOR

ncdf_varput, cdfid, vnversvarid, GEO_MATCH_NC_FILE_VERSION
ncdf_close, cdfid

GOTO, normalExit

versionOnly:
return, "NoGeoMatchFile"

normalExit:
return, geo_match_nc_file

end
