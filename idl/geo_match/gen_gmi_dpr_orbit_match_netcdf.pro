;+
; Copyright © 2014, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;
;-------------------------------------------------------------------------------
;
; gen_gmi_dpr_orbit_match_netcdf.pro    Bob Morris, GPM GV (SAIC)    Sep. 2014
;
; DESCRIPTION:
; Using the "special values" and path parameters in the 'include' files
; dpr_params.inc, gmi_params.inc,  grid_def.inc, and environs.inc, and supplied
; parameters for the fully qualified output netcdf file name, the number of GMI
; footprints in the matchup, the basenames of the GMI and DPR data files used in
; the matchup, and the global variables for the TRMM product version, creates
; an empty GMI/DPR matchup netCDF file in the directory pointed to in the
; supplied file path/name parameter 'geo_match_nc_file'.
;
; The input file name supplied is expected to be a complete file basename and
; to contain fields for YYMMDD, and the TRMM orbit number, as well as the '.nc'
; file extension.  No checking of the file name pre-existence, uniqueness, or
; conformance is performed in this module.  If the directory path to the output
; file does not yet exist, it will be created as permissions allow.
;
; If fewer than 8 positional parameters are supplied then the output file will
; not be created, but if the keyword parameter GEO_MATCH_VERS is defined, the
; current matchup file version defined for the output file will be returned as
; the new keyword parameter value.  This allows a calling program to obtain the
; current matchup file version without actually creating an output file.
;
; HISTORY:
; 09/23/2014 by Bob Morris, GPM GV (SAIC)
;  - Created from gen_tmi_pr_orbit_match_netcdf.pro.
;
;-------------------------------------------------------------------------------
;-

FUNCTION gen_gmi_dpr_orbit_match_netcdf, geo_match_nc_file, nscans, nrays, $
                                         radius, centerLat, centerLon, $
                                         PPS_vers, swath, gmidprfiles, $
                                         GEO_MATCH_VERS=geo_match_vers

GEO_MATCH_NC_FILE_VERSION=1.0    ;ignore "Include" file definition now
print, geo_match_nc_file, nscans, nrays, $
                                         radius, centerLat, centerLon, $
                                         PPS_vers, swath, gmidprfiles
IF ( N_ELEMENTS(geo_match_vers) NE 0 ) THEN BEGIN
   geo_match_vers = GEO_MATCH_NC_FILE_VERSION
ENDIF

IF ( N_PARAMS() LT 8 ) THEN GOTO, versionOnly

; "Include" file for DATA_PRESENT, NO_DATA_PRESENT
@grid_def.inc
; "Include" file for the type-specific fill values
@pr_params.inc  ; for the type-specific fill values

; Create the output directory for the netCDF file, if needed:
OUTDIR = FILE_DIRNAME(geo_match_nc_file)
spawn, 'mkdir -p ' + OUTDIR

cdfid = ncdf_create(geo_match_nc_file, /CLOBBER)

; global variables
ncdf_attput, cdfid, 'PPS_version', PPS_vers, /global
ncdf_attput, cdfid, 'Map_Projection', 'Mercator', /global

; extract the input file names (if given) to be written out as global attributes
; or define placeholder values to write

IF ( N_PARAMS() EQ 9 ) THEN BEGIN
   idxfiles = lonarr( N_ELEMENTS(gmidprfiles) )
   idx12 = WHERE(STRPOS(gmidprfiles,'GPROF') GE 0, count12)
   if count12 EQ 1 THEN BEGIN
      origFile12Name = STRJOIN(STRTRIM(gmidprfiles[idx12],2))
      idxfiles[idx12] = 1
   endif ELSE origFile12Name='no_2AGPROF_file'

   idx25 = WHERE(STRMATCH(gmidprfiles,'*[DK][Pau][R.][!G]*') EQ 1, count25)
   if count25 EQ 1 THEN BEGIN
      origFile25Name = STRJOIN(STRTRIM(gmidprfiles[idx25],2))
      idxfiles[idx25] = 1
   endif ELSE origFile25Name='no_2ADPR/Ka/Ku_file'

   idx31 = WHERE(STRPOS(gmidprfiles,'DPRGMI') GE 0, count31)
   if count31 EQ 1 THEN BEGIN
      origFile31Name = STRJOIN(STRTRIM(gmidprfiles[idx31],2))
      idxfiles[idx31] = 1
   endif ELSE origFile31Name='no_2BDPRGMI_file'

ENDIF ELSE BEGIN

   origFile12Name='Unspecified'
   origFile25Name='Unspecified'
   origFile31Name='Unspecified'

ENDELSE

ncdf_attput, cdfid, 'GMI_GPROF_file', origFile12Name, /global
ncdf_attput, cdfid,    'DPR_2A_file', origFile25Name, /global
ncdf_attput, cdfid,    'DPRGMI_file', origFile31Name, /global

; field dimensions

scandimid = ncdf_dimdef(cdfid, 'scandim', nscans)  ; # GMI scan lines in dataset
raydimid = ncdf_dimdef(cdfid, 'raydim', nrays)     ; # GMI rays per scan
xydimid = ncdf_dimdef(cdfid, 'xydim', 4)       ; 4 corners of a GMI footprint


; scalar fields

;rainthreshid = ncdf_vardef(cdfid, 'gmi_rain_min')
;ncdf_attput, cdfid, rainthreshid, 'long_name', $
;             'minimum GMI rainrate required'
;ncdf_attput, cdfid, rainthreshid, '_FillValue', FLOAT_RANGE_EDGE
;ncdf_attput, cdfid, rainthreshid, 'units', 'mm/h'

radiusid = ncdf_vardef(cdfid, 'averaging_radius')
ncdf_attput, cdfid, radiusid, 'long_name', $
             'effective GMI footprint radius'
ncdf_attput, cdfid, radiusid, '_FillValue', FLOAT_RANGE_EDGE
ncdf_attput, cdfid, radiusid, 'units', 'km'

centerLonid = ncdf_vardef(cdfid, 'map_center_longitude')
ncdf_attput, cdfid, centerLonid, 'long_name', $
             'longitude of map origin for x-y coordinates, degrees East positive'
ncdf_attput, cdfid, centerLonid, '_FillValue', FLOAT_RANGE_EDGE
ncdf_attput, cdfid, centerLonid, 'units', 'degrees'

centerLatid = ncdf_vardef(cdfid, 'map_center_latitude')
ncdf_attput, cdfid, centerLatid, 'long_name', $
             'latitude of map origin for x-y coordinates, degrees North positive'
ncdf_attput, cdfid, centerLatid, '_FillValue', FLOAT_RANGE_EDGE
ncdf_attput, cdfid, centerLatid, 'units', 'degrees'

swathdimid = ncdf_dimdef(cdfid, 'len_swath_ID', 2L)
swathid = ncdf_vardef(cdfid, 'DPR_scan_type', [swathdimid], /char)
ncdf_attput, cdfid, swathid, 'long_name', 'DPR swath used in matchup: NS, MS, or HS'


; Data existence (non-fill) flags for science fields

havesurfaceTypevarid = ncdf_vardef(cdfid, 'have_surfaceType', /short)
ncdf_attput, cdfid, havesurfaceTypevarid, 'long_name', $
             'data exists flag for surfaceType'
ncdf_attput, cdfid, havesurfaceTypevarid, '_FillValue', NO_DATA_PRESENT

havesfrainvarid = ncdf_vardef(cdfid, 'have_surfacePrecipitation', /short)
ncdf_attput, cdfid, havesfrainvarid, 'long_name', $
             'data exists flag for surfacePrecipitation'
ncdf_attput, cdfid, havesfrainvarid, '_FillValue', NO_DATA_PRESENT

haverainflagvarid = ncdf_vardef(cdfid, 'have_numPRrainy', /short)
ncdf_attput, cdfid, haverainflagvarid, 'long_name', $
             'data exists flag for numPRrainy'
ncdf_attput, cdfid, haverainflagvarid, '_FillValue', NO_DATA_PRESENT

havepixelStatusvarid = ncdf_vardef(cdfid, 'have_pixelStatus', /short)
ncdf_attput, cdfid, havepixelStatusvarid, 'long_name', $
             'data exists flag for pixelStatus'
ncdf_attput, cdfid, havepixelStatusvarid, '_FillValue', NO_DATA_PRESENT

havePoPvarid = ncdf_vardef(cdfid, 'have_PoP', /short)
ncdf_attput, cdfid, havePoPvarid, 'long_name', $
             'data exists flag for PoP'
ncdf_attput, cdfid, havePoPvarid, '_FillValue', NO_DATA_PRESENT

haveprsfrainvarid = ncdf_vardef(cdfid, 'have_precipRateSurface', /short)
ncdf_attput, cdfid, haveprsfrainvarid, 'long_name', $
             'data exists flag for precipRateSurface'
ncdf_attput, cdfid, haveprsfrainvarid, '_FillValue', NO_DATA_PRESENT

havesfrain_2b31_varid = ncdf_vardef(cdfid, 'have_surfRain_2BDPRGMI', /short)
ncdf_attput, cdfid, havesfrain_2b31_varid, 'long_name', $
             'data exists flag for surfRain_2BDPRGMI'
ncdf_attput, cdfid, havesfrain_2b31_varid, '_FillValue', NO_DATA_PRESENT

havebbvarid = ncdf_vardef(cdfid, 'have_BBheight', /short)
ncdf_attput, cdfid, havebbvarid, 'long_name', 'data exists flag for BBheight'
ncdf_attput, cdfid, havebbvarid, '_FillValue', NO_DATA_PRESENT

haveraintypevarid = ncdf_vardef(cdfid, 'have_numConvectiveType', /short)
ncdf_attput, cdfid, haveraintypevarid, 'long_name', $
             'data exists flag for numConvectiveType'
ncdf_attput, cdfid, haveraintypevarid, '_FillValue', NO_DATA_PRESENT

; Data fields

xvarid = ncdf_vardef(cdfid, 'xCorners', [xydimid,raydimid,scandimid])
ncdf_attput, cdfid, xvarid, 'long_name', 'data sample x corner coords.'
ncdf_attput, cdfid, xvarid, 'units', 'km'
ncdf_attput, cdfid, xvarid, '_FillValue', FLOAT_RANGE_EDGE

yvarid = ncdf_vardef(cdfid, 'yCorners', [xydimid,raydimid,scandimid])
ncdf_attput, cdfid, yvarid, 'long_name', 'data sample y corner coords.'
ncdf_attput, cdfid, yvarid, 'units', 'km'
ncdf_attput, cdfid, yvarid, '_FillValue', FLOAT_RANGE_EDGE

sfclatvarid = ncdf_vardef(cdfid, 'GMIlatitude', [raydimid,scandimid])
ncdf_attput, cdfid, sfclatvarid, 'long_name', 'Latitude of GMI surface bin'
ncdf_attput, cdfid, sfclatvarid, 'units', 'degrees North'
ncdf_attput, cdfid, sfclatvarid, '_FillValue', FLOAT_RANGE_EDGE

sfclonvarid = ncdf_vardef(cdfid, 'GMIlongitude', [raydimid,scandimid])
ncdf_attput, cdfid, sfclonvarid, 'long_name', 'Longitude of GMI surface bin'
ncdf_attput, cdfid, sfclonvarid, 'units', 'degrees East'
ncdf_attput, cdfid, sfclonvarid, '_FillValue', FLOAT_RANGE_EDGE

surfaceTypevarid = ncdf_vardef(cdfid, 'surfaceType', [raydimid,scandimid], /short)
ncdf_attput, cdfid, surfaceTypevarid, 'long_name', '2A-GPROF surfaceTypeIndex'
ncdf_attput, cdfid, surfaceTypevarid, 'units', 'Categorical'
ncdf_attput, cdfid, surfaceTypevarid, '_FillValue', INT_RANGE_EDGE

sfrainvarid = ncdf_vardef(cdfid, 'surfacePrecipitation', [raydimid,scandimid])
ncdf_attput, cdfid, sfrainvarid, 'long_name', $
             '2A-GPROF Estimated Surface Rain Rate'
ncdf_attput, cdfid, sfrainvarid, 'units', 'mm/h'
ncdf_attput, cdfid, sfrainvarid, '_FillValue', FLOAT_RANGE_EDGE

pixelStatusvarid = ncdf_vardef(cdfid, 'pixelStatus', [raydimid,scandimid], /short)
ncdf_attput, cdfid, pixelStatusvarid, 'long_name', $
            '2A-GPROF PixelStatus'
ncdf_attput, cdfid, pixelStatusvarid, 'units', 'Categorical'
ncdf_attput, cdfid, pixelStatusvarid, '_FillValue', INT_RANGE_EDGE

PoPvarid = ncdf_vardef(cdfid, 'PoP', [raydimid,scandimid], /short)
ncdf_attput, cdfid, PoPvarid, 'long_name', $
            '2A-GPROF Probability of Precipitation'
ncdf_attput, cdfid, PoPvarid, 'units', 'percent'
ncdf_attput, cdfid, PoPvarid, '_FillValue', INT_RANGE_EDGE

rayidxvarid = ncdf_vardef(cdfid, 'GMIrayIndex', [raydimid,scandimid], /long)
ncdf_attput, cdfid, rayidxvarid, 'long_name', $
            'GMI product-relative scan,ray IDL 1-D array index'
ncdf_attput, cdfid, rayidxvarid, '_FillValue', LONG_RANGE_EDGE

sfrainvarid = ncdf_vardef(cdfid, 'precipRateSurface', [raydimid,scandimid])
ncdf_attput, cdfid, sfrainvarid, 'long_name', $
             'GMI-scaled DPR 2A Near-Surface Estimated Rain Rate'
ncdf_attput, cdfid, sfrainvarid, 'units', 'mm/h'
ncdf_attput, cdfid, sfrainvarid, '_FillValue', FLOAT_RANGE_EDGE

sfrain_2b31_varid = ncdf_vardef(cdfid, 'surfRain_2BDPRGMI', [raydimid,scandimid])
ncdf_attput, cdfid, sfrain_2b31_varid, 'long_name', $
            'GMI-scale 2B-DPRGMI Near-Surface Estimated Rain Rate'
ncdf_attput, cdfid, sfrain_2b31_varid, 'units', 'mm/h'
ncdf_attput, cdfid, sfrain_2b31_varid, '_FillValue', FLOAT_RANGE_EDGE

bbvarid = ncdf_vardef(cdfid, 'BBheight', [raydimid,scandimid])
ncdf_attput, cdfid, bbvarid, 'long_name', $
            'Running average DPR Bright Band Height above MSL'
ncdf_attput, cdfid, bbvarid, 'units', 'm'
ncdf_attput, cdfid, bbvarid, '_FillValue', FLOAT_RANGE_EDGE

bbsvarid = ncdf_vardef(cdfid, 'numPRinRadius', [raydimid,scandimid], /short)
ncdf_attput, cdfid, bbsvarid, 'long_name', $
            'Number of DPR footprints within radius of GMI in averages'
;ncdf_attput, cdfid, bbsvarid, 'units', 'Categorical'
ncdf_attput, cdfid, bbsvarid, '_FillValue', INT_RANGE_EDGE

prsvarid = ncdf_vardef(cdfid, 'numPRsfcRain', [raydimid,scandimid], /short)
ncdf_attput, cdfid, prsvarid, 'long_name', 'Number of non-zero samples in precipRateSurface average'
ncdf_attput, cdfid, prsvarid, 'units', 'Categorical'
ncdf_attput, cdfid, prsvarid, '_FillValue', INT_RANGE_EDGE

numComvarid = ncdf_vardef(cdfid, 'numPRsfcRainCom', [raydimid,scandimid], /short)
ncdf_attput, cdfid, numComvarid, 'long_name', 'Number of non-zero samples in surfRain_2BDPRGMI average'
;ncdf_attput, cdfid, numComvarid, 'units', 'Categorical'
ncdf_attput, cdfid, numComvarid, '_FillValue', INT_RANGE_EDGE

raintypevarid = ncdf_vardef(cdfid, 'numConvectiveType', [raydimid,scandimid], /short)
ncdf_attput, cdfid, raintypevarid, 'long_name', $
            'Number of DPR samples of Rain Type convective within average'
ncdf_attput, cdfid, raintypevarid, '_FillValue', INT_RANGE_EDGE

rainflagvarid = ncdf_vardef(cdfid, 'numPRrainy', [raydimid,scandimid], /short)
ncdf_attput, cdfid, rainflagvarid, 'long_name', $
            'Number of DPR samples within average with flagPrecip indicating rain'
ncdf_attput, cdfid, rainflagvarid, '_FillValue', INT_RANGE_EDGE


vnversvarid = ncdf_vardef(cdfid, 'version')
ncdf_attput, cdfid, vnversvarid, 'long_name', 'Geo Match File Version'
;
ncdf_control, cdfid, /endef
;

ncdf_varput, cdfid, vnversvarid, GEO_MATCH_NC_FILE_VERSION
ncdf_varput, cdfid, centerLonid, centerLon
ncdf_varput, cdfid, centerLatid, centerLat
ncdf_varput, cdfid, radiusid, radius
ncdf_varput, cdfid, swathid, swath

ncdf_close, cdfid

GOTO, normalExit

versionOnly:
return, "NoGeoMatchFile"

normalExit:
return, geo_match_nc_file

end
