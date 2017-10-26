;+
; Copyright © 2012, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;
;-------------------------------------------------------------------------------
;
; gen_tmi_pr_orbit_match_netcdf.pro    Bob Morris, GPM GV (SAIC)    Nov. 2012
;
; DESCRIPTION:
; Using the "special values" and path parameters in the 'include' files
; pr_params.inc, tmi_params.inc,  grid_def.inc, and environs.inc, and supplied
; parameters for the fully qualified output netcdf file name, the number of TMI
; footprints in the matchup, the basenames of the TMI and PR data files used in
; the matchup, and the global variables for the TRMM product version, creates
; an empty TMI/PR matchup netCDF file in the directory pointed to in the
; supplied file path/name parameter 'geo_match_nc_file'.
;
; The input file name supplied is expected to be a complete file basename and
; to contain fields for YYMMDD, and the TRMM orbit number, as well as the '.nc'
; file extension.  No checking of the file name pre-existence, uniqueness, or
; conformance is performed in this module.  If the directory path to the output
; file does not yet exist, it will be created as permissions allow.
;
; If fewer than 3 positional parameters are supplied then the output file will
; not be created, but if the keyword parameter GEO_MATCH_VERS is defined, the
; current matchup file version defined for the output file will be returned as
; the new keyword parameter value.  This allows a calling program to obtain the
; current matchup file version without actually creating an output file.
;
; HISTORY:
; 11/29/2012 by Bob Morris, GPM GV (SAIC)
;  - Created from gen_tmi_geo_match_netcdf.pro.
;
;-------------------------------------------------------------------------------
;-

FUNCTION gen_tmi_pr_orbit_match_netcdf, geo_match_nc_file, nscans, nrays, $
                                        radius, centerLat, centerLon, $
                                        TRMM_vers, tmiprfiles, $
                                        GEO_MATCH_VERS=geo_match_vers

GEO_MATCH_NC_FILE_VERSION=1.0    ;ignore "Include" file definition now

IF ( N_ELEMENTS(geo_match_vers) NE 0 ) THEN BEGIN
   geo_match_vers = GEO_MATCH_NC_FILE_VERSION
ENDIF

IF ( N_PARAMS() LT 7 ) THEN GOTO, versionOnly

; "Include" file for DATA_PRESENT, NO_DATA_PRESENT
@grid_def.inc
; "Include" file for the type-specific fill values
@pr_params.inc  ; for the type-specific fill values

; Create the output directory for the netCDF file, if needed:
OUTDIR = FILE_DIRNAME(geo_match_nc_file)
spawn, 'mkdir -p ' + OUTDIR

cdfid = ncdf_create(geo_match_nc_file, /CLOBBER)

; global variables
ncdf_attput, cdfid, 'TRMM_Version', TRMM_vers, /short, /global
ncdf_attput, cdfid, 'Map_Projection', 'Mercator', /global

; extract the input file names (if given) to be written out as global attributes
; or define placeholder values to write

IF ( N_PARAMS() EQ 8 ) THEN BEGIN
   idxfiles = lonarr( N_ELEMENTS(tmiprfiles) )
   idx12 = WHERE(STRPOS(tmiprfiles,'2A12') GE 0, count12)
   if count12 EQ 1 THEN BEGIN
      origFile12Name = STRJOIN(STRTRIM(tmiprfiles[idx12],2))
      idxfiles[idx12] = 1
   endif ELSE origFile12Name='no_2A12_file'

   idx21 = WHERE(STRPOS(tmiprfiles,'1C21') GE 0, count21)
   if count21 EQ 1 THEN BEGIN
     ; got to strjoin to collapse the degenerate string array to simple string
      origFile21Name = ''+STRJOIN(STRTRIM(tmiprfiles[idx21],2))
      idxfiles[idx21] = 1
   endif ELSE origFile21Name='no_1C21_file'

   idx23 = WHERE(STRPOS(tmiprfiles,'2A23') GE 0, count23)
   if count23 EQ 1 THEN BEGIN
      origFile23Name = STRJOIN(STRTRIM(tmiprfiles[idx23],2))
      idxfiles[idx23] = 1
   endif  ELSE origFile23Name='no_2A23_file'

   idx25 = WHERE(STRPOS(tmiprfiles,'2A25') GE 0, count25)
   if count25 EQ 1 THEN BEGIN
      origFile25Name = STRJOIN(STRTRIM(tmiprfiles[idx25],2))
      idxfiles[idx25] = 1
   endif ELSE origFile25Name='no_2A25_file'

   idx31 = WHERE(STRPOS(tmiprfiles,'2B31') GE 0, count31)
   if count31 EQ 1 THEN BEGIN
      origFile31Name = STRJOIN(STRTRIM(tmiprfiles[idx31],2))
      idxfiles[idx31] = 1
   endif ELSE origFile31Name='no_2B31_file'

ENDIF ELSE BEGIN

   origFile12Name='Unspecified'
   origFile21Name='Unspecified'
   origFile23Name='Unspecified'
   origFile25Name='Unspecified'
   origFile31Name='Unspecified'

ENDELSE

ncdf_attput, cdfid, 'TMI_2A12_file', origFile12Name, /global
ncdf_attput, cdfid,  'PR_1C21_file', origFile21Name, /global
ncdf_attput, cdfid,  'PR_2A23_file', origFile23Name, /global
ncdf_attput, cdfid,  'PR_2A25_file', origFile25Name, /global
ncdf_attput, cdfid,  'PR_2B31_file', origFile31Name, /global


; field dimensions

scandimid = ncdf_dimdef(cdfid, 'scandim', nscans)  ; # TMI scan lines in dataset
raydimid = ncdf_dimdef(cdfid, 'raydim', nrays)     ; # TMI rays per scan
xydimid = ncdf_dimdef(cdfid, 'xydim', 4)       ; 4 corners of a TMI footprint


; scalar fields

rainthreshid = ncdf_vardef(cdfid, 'tmi_rain_min')
ncdf_attput, cdfid, rainthreshid, 'long_name', $
             'minimum TMI rainrate required'
ncdf_attput, cdfid, rainthreshid, '_FillValue', FLOAT_RANGE_EDGE
ncdf_attput, cdfid, rainthreshid, 'units', 'mm/h'

radiusid = ncdf_vardef(cdfid, 'averaging_radius')
ncdf_attput, cdfid, rainthreshid, 'long_name', $
             'effective TMI footprint radius'
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


; Data existence (non-fill) flags for science fields

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

haveprsfrainvarid = ncdf_vardef(cdfid, 'have_nearSurfRain', /short)
ncdf_attput, cdfid, haveprsfrainvarid, 'long_name', $
             'data exists flag for nearSurfRain'
ncdf_attput, cdfid, haveprsfrainvarid, '_FillValue', NO_DATA_PRESENT

havesfrain_2b31_varid = ncdf_vardef(cdfid, 'have_nearSurfRain_2b31', /short)
ncdf_attput, cdfid, havesfrain_2b31_varid, 'long_name', $
             'data exists flag for nearSurfRain_2b31'
ncdf_attput, cdfid, havesfrain_2b31_varid, '_FillValue', NO_DATA_PRESENT

havebbvarid = ncdf_vardef(cdfid, 'have_BBheight', /short)
ncdf_attput, cdfid, havebbvarid, 'long_name', 'data exists flag for BBheight'
ncdf_attput, cdfid, havebbvarid, '_FillValue', NO_DATA_PRESENT

haveprrainflagvarid = ncdf_vardef(cdfid, 'have_prrainFlag', /short)
ncdf_attput, cdfid, haveprrainflagvarid, 'long_name', $
             'data exists flag for PR rainFlag'
ncdf_attput, cdfid, haveprrainflagvarid, '_FillValue', NO_DATA_PRESENT

haveraintypevarid = ncdf_vardef(cdfid, 'have_rainType', /short)
ncdf_attput, cdfid, haveraintypevarid, 'long_name', $
             'data exists flag for rainType'
ncdf_attput, cdfid, haveraintypevarid, '_FillValue', NO_DATA_PRESENT

; Data fields

xvarid = ncdf_vardef(cdfid, 'xCorners', [xydimid,scandimid,raydimid])
ncdf_attput, cdfid, xvarid, 'long_name', 'data sample x corner coords.'
ncdf_attput, cdfid, xvarid, 'units', 'km'
ncdf_attput, cdfid, xvarid, '_FillValue', FLOAT_RANGE_EDGE

yvarid = ncdf_vardef(cdfid, 'yCorners', [xydimid,scandimid,raydimid])
ncdf_attput, cdfid, yvarid, 'long_name', 'data sample y corner coords.'
ncdf_attput, cdfid, yvarid, 'units', 'km'
ncdf_attput, cdfid, yvarid, '_FillValue', FLOAT_RANGE_EDGE

sfclatvarid = ncdf_vardef(cdfid, 'TMIlatitude', [scandimid,raydimid])
ncdf_attput, cdfid, sfclatvarid, 'long_name', 'Latitude of TMI surface bin'
ncdf_attput, cdfid, sfclatvarid, 'units', 'degrees North'
ncdf_attput, cdfid, sfclatvarid, '_FillValue', FLOAT_RANGE_EDGE

sfclonvarid = ncdf_vardef(cdfid, 'TMIlongitude', [scandimid,raydimid])
ncdf_attput, cdfid, sfclonvarid, 'long_name', 'Longitude of TMI surface bin'
ncdf_attput, cdfid, sfclonvarid, 'units', 'degrees East'
ncdf_attput, cdfid, sfclonvarid, '_FillValue', FLOAT_RANGE_EDGE

surfaceTypevarid = ncdf_vardef(cdfid, 'surfaceType', [scandimid,raydimid], /short)
ncdf_attput, cdfid, surfaceTypevarid, 'long_name', '2A-12 Land/Ocean Flag'
ncdf_attput, cdfid, surfaceTypevarid, 'units', 'Categorical'
ncdf_attput, cdfid, surfaceTypevarid, '_FillValue', INT_RANGE_EDGE

sfrainvarid = ncdf_vardef(cdfid, 'surfaceRain', [scandimid,raydimid])
ncdf_attput, cdfid, sfrainvarid, 'long_name', $
             '2A-12 Estimated Surface Rain Rate'
ncdf_attput, cdfid, sfrainvarid, 'units', 'mm/h'
ncdf_attput, cdfid, sfrainvarid, '_FillValue', FLOAT_RANGE_EDGE

rainflagvarid = ncdf_vardef(cdfid, 'rainFlag', [scandimid,raydimid], /short)
ncdf_attput, cdfid, rainflagvarid, 'long_name', '2A-12 Rain Flag (V6 only)'
ncdf_attput, cdfid, rainflagvarid, 'units', 'Categorical'
ncdf_attput, cdfid, rainflagvarid, '_FillValue', INT_RANGE_EDGE

dataFlagvarid = ncdf_vardef(cdfid, 'dataFlag', [scandimid,raydimid], /short)
ncdf_attput, cdfid, dataFlagvarid, 'long_name', $
            '2A-12 Data Flag (V7) or PixelStatus (V6)'
ncdf_attput, cdfid, dataFlagvarid, 'units', 'Categorical'
ncdf_attput, cdfid, dataFlagvarid, '_FillValue', INT_RANGE_EDGE

PoPvarid = ncdf_vardef(cdfid, 'PoP', [scandimid,raydimid], /short)
ncdf_attput, cdfid, PoPvarid, 'long_name', $
            '2A-12 Probability of Precipitation'
ncdf_attput, cdfid, PoPvarid, 'units', 'percent'
ncdf_attput, cdfid, PoPvarid, '_FillValue', INT_RANGE_EDGE

freezingHeightvarid = ncdf_vardef(cdfid, 'freezingHeight', [scandimid,raydimid], /short)
ncdf_attput, cdfid, freezingHeightvarid, 'long_name', $
            '2A-12 Freezing Height'
ncdf_attput, cdfid, freezingHeightvarid, 'units', 'meters'
ncdf_attput, cdfid, freezingHeightvarid, '_FillValue', INT_RANGE_EDGE

rayidxvarid = ncdf_vardef(cdfid, 'TMIrayIndex', [scandimid,raydimid], /long)
ncdf_attput, cdfid, rayidxvarid, 'long_name', $
            'TMI product-relative scan,ray IDL 1-D array index'
ncdf_attput, cdfid, rayidxvarid, '_FillValue', LONG_RANGE_EDGE

sfrainvarid = ncdf_vardef(cdfid, 'nearSurfRain', [scandimid,raydimid])
ncdf_attput, cdfid, sfrainvarid, 'long_name', $
             'TMI-scaled 2A-25 Near-Surface Estimated Rain Rate'
ncdf_attput, cdfid, sfrainvarid, 'units', 'mm/h'
ncdf_attput, cdfid, sfrainvarid, '_FillValue', FLOAT_RANGE_EDGE

sfrain_2b31_varid = ncdf_vardef(cdfid, 'nearSurfRain_2b31', [scandimid,raydimid])
ncdf_attput, cdfid, sfrain_2b31_varid, 'long_name', $
            'TMI-scale 2B-31 Near-Surface Estimated Rain Rate'
ncdf_attput, cdfid, sfrain_2b31_varid, 'units', 'mm/h'
ncdf_attput, cdfid, sfrain_2b31_varid, '_FillValue', FLOAT_RANGE_EDGE

bbvarid = ncdf_vardef(cdfid, 'BBheight', [scandimid,raydimid])
ncdf_attput, cdfid, bbvarid, 'long_name', $
            'Running average PR 2A23 Bright Band Height above MSL'
ncdf_attput, cdfid, bbvarid, 'units', 'm'
ncdf_attput, cdfid, bbvarid, '_FillValue', FLOAT_RANGE_EDGE

bbsvarid = ncdf_vardef(cdfid, 'numPRinRadius', [scandimid,raydimid], /short)
ncdf_attput, cdfid, bbsvarid, 'long_name', $
            'Number of PR footprints within radius of TMI in averages'
;ncdf_attput, cdfid, bbsvarid, 'units', 'Categorical'
ncdf_attput, cdfid, bbsvarid, '_FillValue', INT_RANGE_EDGE

prsvarid = ncdf_vardef(cdfid, 'numPRsfcRain', [scandimid,raydimid], /short)
ncdf_attput, cdfid, prsvarid, 'long_name', 'Number of non-zero samples in nearSurfRain average'
ncdf_attput, cdfid, prsvarid, 'units', 'Categorical'
ncdf_attput, cdfid, prsvarid, '_FillValue', INT_RANGE_EDGE

rainflagvarid = ncdf_vardef(cdfid, 'numPRsfcRainCom', [scandimid,raydimid], /short)
ncdf_attput, cdfid, rainflagvarid, 'long_name', 'Number of non-zero samples in nearSurfRain_2b31 average'
;ncdf_attput, cdfid, rainflagvarid, 'units', 'Categorical'
ncdf_attput, cdfid, rainflagvarid, '_FillValue', INT_RANGE_EDGE

raintypevarid = ncdf_vardef(cdfid, 'numConvectiveType', [scandimid,raydimid], /short)
ncdf_attput, cdfid, raintypevarid, 'long_name', $
            'Number of PR samples of Rain Type convective within average'
;ncdf_attput, cdfid, raintypevarid, 'units', 'Categorical'
ncdf_attput, cdfid, raintypevarid, '_FillValue', INT_RANGE_EDGE

; Data time/location variables

timevarid = ncdf_vardef(cdfid, 'timeNearestApproach', /double)
ncdf_attput, cdfid, timevarid, 'units', 'seconds'
ncdf_attput, cdfid, timevarid, 'long_name', 'Seconds since 01-01-1970 00:00:00'
ncdf_attput, cdfid, timevarid, '_FillValue', 0.0D+0

atimedimid = ncdf_dimdef(cdfid, 'len_atime_ID', STRLEN('01-01-1970 00:00:00'))

atimevarid = ncdf_vardef(cdfid, 'atimeNearestApproach', [atimedimid], /char)
ncdf_attput, cdfid, atimevarid, 'long_name', $
            'text version of timeNearestApproach, UTC'

vnversvarid = ncdf_vardef(cdfid, 'version')
ncdf_attput, cdfid, vnversvarid, 'long_name', 'Geo Match File Version'
;
ncdf_control, cdfid, /endef
;

ncdf_varput, cdfid, vnversvarid, GEO_MATCH_NC_FILE_VERSION
ncdf_varput, cdfid, centerLonid, centerLon
ncdf_varput, cdfid, centerLatid, centerLat
ncdf_varput, cdfid, radiusid, radius

ncdf_close, cdfid

GOTO, normalExit

versionOnly:
return, "NoGeoMatchFile"

normalExit:
return, geo_match_nc_file

end
