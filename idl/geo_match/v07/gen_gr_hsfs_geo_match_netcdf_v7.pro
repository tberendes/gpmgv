;+
; Copyright © 2016, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;
;-------------------------------------------------------------------------------
;
; gen_gr_hsfs_geo_match_netcdf_v7.pro    Todd Berendes, UAH   July 1, 2020
; adapted from gen_gr_hsmsns_geo_match_netcdf.pro for GPM V7
;
; DESCRIPTION:
; Using the "special values" parameters in the 'include' file dpr_params_v7.inc,
; the path parameters in environs_v7.inc, and supplied parameters for the filename,
; number of DPR footprints in the matchup for each "swath" (HS,FS), the array
; of elevation angles in the ground radar volume scan, the number of scans in
; the input 2A-DPR subset file for each swath type, and global variables for the
; UF data field used for GR reflectivity and various dual-pol fields, and the
; DPR product version, creates an empty matchup netCDF file holding the volume-
; matched GR variables ONLY, for each swath's DPR footprints.
;
; The netCDF file name supplied is expected to be a complete file basename and
; to contain fields for YYMMDD, the GPM orbit number, and the ID of the ground
; radar site, as well as the '.nc' file extension.  No checking of the file name
; pre-existence, uniqueness, or conformance is performed in this module.
;
; HISTORY:
; 02/26/2016 by Bob Morris, GPM GV (SAIC)
;  - Created from features within gen_dpr_geo_match_netcdf.pro
;    and gen_dprgmi_geo_match_netcdf.pro
; 03/06/16 by Bob Morris, GPM GV (SAIC)
;  - Added swath-invariant global variable GR_ROI_km.
; 8/27/18 by Todd Berendes, UAH
;    added new variables for snowfall water equivalent rate in the VN data using one of 
;    the new polarimetric relationships suggested by Bukocvic et al (2017)
;    call them SWERR1
; 4/6/22 by Todd Berendes UAH/ITSC
;  - Added new GR liquid and frozen water content fields
;
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;-------------------------------------------------------------------------------
;-

FUNCTION gen_gr_hsfs_geo_match_netcdf_v7, geo_match_nc_file, numpts_HS, numpts_FS, $
                                         elev_angles, numscans_HS, $
                                         numscans_FS, gv_UF_field, $
                                         DPR_vers, siteID, dprgrfiles, $
                                         GEO_MATCH_VERS=geo_match_vers, $
                                         FREEZING_LEVEL=freezing_level, $
                                         NON_PPS_FILES=non_pps_files

; "Include" file for DATA_PRESENT, NO_DATA_PRESENT
@grid_def.inc
; "Include" files for constants, names, paths, etc.
@environs_v7.inc   ; for file prefixes, netCDF file definition version
@dpr_params_v7.inc  ; for the type-specific fill values

; for debugging
;!EXCEPT=2

; TAB 8/27/18 changed version to 1.1 from 1.0 for new snow water equivalent field
;GEO_MATCH_FILE_VERSION=1.1   ; hard code inside function now, not from "Include"
; TAB 11/10/20 changed version to 2.0 from 1.1

; TAB 6/7/22 version 2.2 added freezing_level_height variable
GEO_MATCH_FILE_VERSION=2.2

; TAB 6/7/22 
freezing_level_height=-9999. ; defaults to missing height
IF ( N_ELEMENTS(freezing_level) NE 0 ) THEN BEGIN
	freezing_level_height=freezing_level
endif

IF ( N_ELEMENTS(geo_match_vers) NE 0 ) THEN BEGIN
  ; assign optional keyword parameter value for "versionOnly" calling mode
   geo_match_vers = GEO_MATCH_FILE_VERSION
ENDIF

;IF ( N_PARAMS() LT 12 ) THEN GOTO, versionOnly
IF ( N_PARAMS() LT 10 ) THEN GOTO, versionOnly

; Create the output dir for the netCDF file, if needed:
OUTDIR = FILE_DIRNAME(geo_match_nc_file)
spawn, 'mkdir -p ' + OUTDIR

cdfid = ncdf_create(geo_match_nc_file, /CLOBBER)

; define the 3 scan types (swaths) in the DPR product
; - we need separate variables for each swath for the science variables
swath = ['HS','FS_Ku','FS_Ka']

; global variables -- THE FIRST GLOBAL VARIABLE MUST BE 'DPR_Version'
ncdf_attput, cdfid, 'DPR_Version', DPR_vers, /global

; determine whether gv_UF_field is a scalar character or a structure, and write
; global values for UF field IDs accordingly

; - first, intialize field IDs as Unspecified
zuf = 'Unspecified'
zdruf = 'Unspecified'
kdpuf = 'Unspecified'
rhohvuf = 'Unspecified'
rcuf = 'Unspecified'
rpuf = 'Unspecified'
rruf = 'Unspecified'
hiduf = 'Unspecified'
dzerouf = 'Unspecified'
nwuf = 'Unspecified'
mwuf = 'Unspecified'
miuf = 'Unspecified'
dmuf = 'Unspecified'
n2uf = 'Unspecified'

s = SIZE(gv_UF_field, /TYPE)
CASE s OF
    7 : BEGIN
          ; we were passed a STRING, it must be for the Z field.  If more than
          ; one element (array instead of scalar), take the first one
           IF N_ELEMENTS(gv_UF_field) NE 1 THEN BEGIN
              zuf = gv_UF_field[0]
              message, "Multiple values passed as string in gv_UF_field, " $
                 +"assigning the first one to global variable GV_UF_Z_field: '" $
                 +zuf+"'.  Fix calling parameters if ID is incorrect.", /INFO
           ENDIF ELSE zuf = gv_UF_field
        END
    8 : BEGIN
          ; we were passed a structure, it must be for multiple UF fields
           FOREACH ufid, TAG_NAMES(gv_UF_field) DO BEGIN
              CASE ufid OF
                 'CZ_ID'  : zuf = gv_UF_field.CZ_ID
                 'ZDR_ID' : zdruf = gv_UF_field.ZDR_ID
                 'KDP_ID'  : kdpuf = gv_UF_field.KDP_ID
                 'RHOHV_ID'  : rhohvuf = gv_UF_field.RHOHV_ID
                 'RC_ID'  : rcuf = gv_UF_field.RC_ID
                 'RP_ID'  : rpuf = gv_UF_field.RP_ID
                 'RR_ID'  : rruf = gv_UF_field.RR_ID
                 'HID_ID' : hiduf = gv_UF_field.HID_ID
                 'D0_ID'  : dzerouf = gv_UF_field.D0_ID
                 'NW_ID'  : nwuf = gv_UF_field.NW_ID
                 'MW_ID'  : mwuf = gv_UF_field.MW_ID
                 'MI_ID'  : miuf = gv_UF_field.MI_ID
                 'DM_ID'  : dmuf = gv_UF_field.DM_ID
                 'N2_ID'  : n2uf = gv_UF_field.N2_ID
                  ELSE    : message, "Unknown UF field tagname '"+ufid $
                               +"' in gv_UF_field structure, ignoring", /INFO
              ENDCASE
           ENDFOREACH
        END
    ELSE : message, "Illegal data type passed for gv_UF_field parameter."
ENDCASE
ncdf_attput, cdfid, 'GV_UF_Z_field', zuf, /global
ncdf_attput, cdfid, 'GV_UF_ZDR_field', zdruf, /global
ncdf_attput, cdfid, 'GV_UF_KDP_field', kdpuf, /global
ncdf_attput, cdfid, 'GV_UF_RHOHV_field', rhohvuf, /global
ncdf_attput, cdfid, 'GV_UF_RC_field', rcuf, /global
ncdf_attput, cdfid, 'GV_UF_RP_field', rpuf, /global
ncdf_attput, cdfid, 'GV_UF_RR_field', rruf, /global
ncdf_attput, cdfid, 'GV_UF_HID_field', hiduf, /global
ncdf_attput, cdfid, 'GV_UF_D0_field', dzerouf, /global
ncdf_attput, cdfid, 'GV_UF_NW_field', nwuf, /global
ncdf_attput, cdfid, 'GV_UF_MW_field', mwuf, /global
ncdf_attput, cdfid, 'GV_UF_MI_field', miuf, /global
ncdf_attput, cdfid, 'GV_UF_DM_field', dmuf, /global
ncdf_attput, cdfid, 'GV_UF_N2_field', n2uf, /global


; identify the input file names for their global attributes.  We could just rely
; on each file type being in a fixed order in the array, but let's make things
; complicated and search for patterns

PPS_NAMED = 1 - KEYWORD_SET(non_pps_files)
IF ( PPS_NAMED EQ 1 ) THEN BEGIN
   idxfiles = lonarr( N_ELEMENTS(dprgrfiles) )

   idxDPR = WHERE(STRMATCH(dprgrfiles, '2A*.GPM.DPR*', /FOLD_CASE) EQ 1, countDPR)
   if countDPR EQ 1 THEN BEGIN
     ; got to strjoin to collapse the degenerate string array to simple string
      origDPRFileName = ''+STRJOIN(STRTRIM(dprgrfiles[idxDPR],2))
      idxfiles[idxDPR] = 1
   endif else begin
      idxDPR = WHERE(STRPOS(dprgrfiles,'no_2ADPR_file') GE 0, countDPR)
      if countDPR EQ 1 THEN BEGIN
         origDPRFileName = ''+STRJOIN(STRTRIM(dprgrfiles[idxDPR],2))
         idxfiles[idxDPR] = 1
      endif ELSE origDPRFileName='no_2ADPR_file'
   endelse

   idxgr = WHERE(idxfiles EQ 0, countgr)
   if countgr EQ 1 THEN BEGIN
      origGRFileName = STRJOIN(STRTRIM(dprgrfiles[idxgr],2))
      idxfiles[idxgr] = 1
   endif else begin
      origGRFileName='no_1CUF_file'
      message, "Unable to parse dprgrfiles array to find DPR/GR file names."
   endelse

ENDIF ELSE BEGIN
  ; rely on positions to set file names
   origDPRFileName  = ''+STRJOIN(STRTRIM(dprgrfiles[0],2))
   origGRFileName   = ''+STRJOIN(STRTRIM(dprgrfiles[1],2))
ENDELSE

ncdf_attput, cdfid, 'DPR_2ADPR_file', origDPRFileName, /global
ncdf_attput, cdfid, 'GR_file', origGRFileName, /global


; field dimensions

fpdimid_HS = ncdf_dimdef(cdfid, 'fpdim_HS', numpts_HS>1)  ; # of HS footprints in range
fpdimid_FS_Ku = ncdf_dimdef(cdfid, 'fpdim_FS_Ku', numpts_FS>1)  ; # of FS footprints in range
fpdimid_FS_Ka = ncdf_dimdef(cdfid, 'fpdim_FS_Ka', numpts_FS>1)  ; # of FS footprints in range
fpdimid = [ fpdimid_HS, fpdimid_FS_Ku, fpdimid_FS_Ka]            ; match to "swath" array, above
eldimid = ncdf_dimdef(cdfid, 'elevationAngle', N_ELEMENTS(elev_angles))
xydimid = ncdf_dimdef(cdfid, 'xydim', 4)        ; for 4 corners of a DPR footprint
hidimid = ncdf_dimdef(cdfid, 'hidim', 15)       ; for Hydromet ID Categories
timedimid_HS = ncdf_dimdef(cdfid, 'timedimid_HS', numscans_HS>1)  ; # of HS scans in range
timedimid_FS_Ku = ncdf_dimdef(cdfid, 'timedimid_FS_Ku', numscans_FS>1)  ; # of FS scans in range
timedimid_FS_Ka = ncdf_dimdef(cdfid, 'timedimid_FS_Ka', numscans_FS>1)  ; # of FS scans in range
timedimid = [ timedimid_HS, timedimid_FS_Ku, timedimid_FS_Ka ]        ; match to "swath" array, above


; Elevation Angles coordinate variable

elvarid = ncdf_vardef(cdfid, 'elevationAngle', [eldimid])
ncdf_attput, cdfid, elvarid, 'long_name', $
            'Radar Sweep Elevation Angles'
ncdf_attput, cdfid, elvarid, 'units', 'degrees'

; are there any HS and/or FS scan points in the GR range limit?

haveswathvarid = ncdf_vardef(cdfid, 'have_swath_HS', /short)
ncdf_attput, cdfid, haveswathvarid, 'long_name', $
             'data exists flag for HS swath'
ncdf_attput, cdfid, haveswathvarid, '_FillValue', NO_DATA_PRESENT

haveswathvarid = ncdf_vardef(cdfid, 'have_swath_FS_Ku', /short)
ncdf_attput, cdfid, haveswathvarid, 'long_name', $
             'data exists flag for FS_Ku swath'
ncdf_attput, cdfid, haveswathvarid, '_FillValue', NO_DATA_PRESENT

haveswathvarid = ncdf_vardef(cdfid, 'have_swath_FS_Ka', /short)
ncdf_attput, cdfid, haveswathvarid, 'long_name', $
             'data exists flag for FS_Ka swath'
ncdf_attput, cdfid, haveswathvarid, '_FillValue', NO_DATA_PRESENT

; scanTime components, one datetime per scan, swath-specific

for iswa=0,N_ELEMENTS(swath)-1 do begin
   tvarid = ncdf_vardef(cdfid, 'Year_'+swath[iswa], timedimid[iswa], /short)
   ncdf_attput, cdfid, tvarid, 'long_name', 'Year of DPR '+swath[iswa]+' scan'
   ncdf_attput, cdfid, tvarid, '_FillValue', INT_RANGE_EDGE

   tvarid = ncdf_vardef(cdfid, 'Month_'+swath[iswa], timedimid[iswa], /byte)
   ncdf_attput, cdfid, tvarid, 'long_name', 'Month of DPR '+swath[iswa]+' scan'
   ncdf_attput, cdfid, tvarid, '_FillValue', -88b

   tvarid = ncdf_vardef(cdfid, 'DayOfMonth_'+swath[iswa], timedimid[iswa], /byte)
   ncdf_attput, cdfid, tvarid, 'long_name', 'DayOfMonth of DPR '+swath[iswa]+' scan'
   ncdf_attput, cdfid, tvarid, '_FillValue', -88b

   tvarid = ncdf_vardef(cdfid, 'Hour_'+swath[iswa], timedimid[iswa], /byte)
   ncdf_attput, cdfid, tvarid, 'long_name', 'Hour of DPR '+swath[iswa]+' scan'
   ncdf_attput, cdfid, tvarid, '_FillValue', -88b

   tvarid = ncdf_vardef(cdfid, 'Minute_'+swath[iswa], timedimid[iswa], /byte)
   ncdf_attput, cdfid, tvarid, 'long_name', 'Minute of DPR '+swath[iswa]+' scan'
   ncdf_attput, cdfid, tvarid, '_FillValue', -88b

   tvarid = ncdf_vardef(cdfid, 'Second_'+swath[iswa], timedimid[iswa], /byte)
   ncdf_attput, cdfid, tvarid, 'long_name', 'Second of DPR '+swath[iswa]+' scan'
   ncdf_attput, cdfid, tvarid, '_FillValue', -88b

   tvarid = ncdf_vardef(cdfid, 'Millisecond_'+swath[iswa], timedimid[iswa], /short)
   ncdf_attput, cdfid, tvarid, 'long_name', 'Millisecond of DPR '+swath[iswa]+' scan'
   ncdf_attput, cdfid, tvarid, '_FillValue', INT_RANGE_EDGE
endfor


; scalar fields

; swath-varying first:

for iswa=0,N_ELEMENTS(swath)-1 do begin
   sscansid = ncdf_vardef(cdfid, 'startScan_'+swath[iswa], /long)
   ncdf_attput, cdfid, sscansid, 'long_name', $
                'Starting DPR '+swath[iswa]+' overlap scan in original dataset, zero-based'
   ncdf_attput, cdfid, sscansid, '_FillValue', LONG(INT_RANGE_EDGE)

   escansid = ncdf_vardef(cdfid, 'endScan_'+swath[iswa], /long)
   ncdf_attput, cdfid, escansid, 'long_name', $
                'Ending DPR '+swath[iswa]+' overlap scan in original dataset, zero-based'
   ncdf_attput, cdfid, escansid, '_FillValue', LONG(INT_RANGE_EDGE)

  ; note that these values are redundant with fpdim_HS, fpdim_MS, fpdim_NS
   nraysid = ncdf_vardef(cdfid, 'numRays_'+swath[iswa], /short)
   ncdf_attput, cdfid, nraysid, 'long_name', $
                'Number of DPR '+swath[iswa]+' rays per scan in original datasets'
   ncdf_attput, cdfid, nraysid, '_FillValue', INT_RANGE_EDGE
endfor

; swath-invariant next:

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

ROIid = ncdf_vardef(cdfid, 'GR_ROI_km')
ncdf_attput, cdfid, ROIid, 'long_name', $
             'Radius of Influence (km) used for GR horizontal averaging'
ncdf_attput, cdfid, ROIid, '_FillValue', FLOAT_RANGE_EDGE
ncdf_attput, cdfid, ROIid, 'units', 'km'


; Data existence (non-fill) flags for GR fields.  Not swath-specific.

havedbzgvvarid = ncdf_vardef(cdfid, 'have_GR_Z', /short)
ncdf_attput, cdfid, havedbzgvvarid, 'long_name', $
             'data exists flag for GR_Z'
ncdf_attput, cdfid, havedbzgvvarid, '_FillValue', NO_DATA_PRESENT

havegvZDRvarid = ncdf_vardef(cdfid, 'have_GR_Zdr', /short)
ncdf_attput, cdfid, havegvZDRvarid, 'long_name', $
             'data exists flag for GR_Zdr'
ncdf_attput, cdfid, havegvZDRvarid, '_FillValue', NO_DATA_PRESENT

havegvKdpvarid = ncdf_vardef(cdfid, 'have_GR_Kdp', /short)
ncdf_attput, cdfid, havegvKdpvarid, 'long_name', $
             'data exists flag for GR_Kdp'
ncdf_attput, cdfid, havegvKdpvarid, '_FillValue', NO_DATA_PRESENT

havegvRHOHVvarid = ncdf_vardef(cdfid, 'have_GR_RHOhv', /short)
ncdf_attput, cdfid, havegvRHOHVvarid, 'long_name', $
             'data exists flag for GR_RHOhv'
ncdf_attput, cdfid, havegvRHOHVvarid, '_FillValue', NO_DATA_PRESENT

havegvRCvarid = ncdf_vardef(cdfid, 'have_GR_RC_rainrate', /short)
ncdf_attput, cdfid, havegvRCvarid, 'long_name', $
             'data exists flag for GR_RC_rainrate'
ncdf_attput, cdfid, havegvRCvarid, '_FillValue', NO_DATA_PRESENT

havegvRPvarid = ncdf_vardef(cdfid, 'have_GR_RP_rainrate', /short)
ncdf_attput, cdfid, havegvRPvarid, 'long_name', $
             'data exists flag for GR_RP_rainrate'
ncdf_attput, cdfid, havegvRPvarid, '_FillValue', NO_DATA_PRESENT

havegvRRvarid = ncdf_vardef(cdfid, 'have_GR_RR_rainrate', /short)
ncdf_attput, cdfid, havegvRRvarid, 'long_name', $
             'data exists flag for GR_RR_rainrate'
ncdf_attput, cdfid, havegvRRvarid, '_FillValue', NO_DATA_PRESENT

havegvHIDvarid = ncdf_vardef(cdfid, 'have_GR_HID', /short)
ncdf_attput, cdfid, havegvHIDvarid, 'long_name', $
             'data exists flag for GR_HID'
ncdf_attput, cdfid, havegvHIDvarid, '_FillValue', NO_DATA_PRESENT

havegvDzerovarid = ncdf_vardef(cdfid, 'have_GR_Dzero', /short)
ncdf_attput, cdfid, havegvDzerovarid, 'long_name', $
             'data exists flag for GR_Dzero'
ncdf_attput, cdfid, havegvDzerovarid, '_FillValue', NO_DATA_PRESENT

havegvNWvarid = ncdf_vardef(cdfid, 'have_GR_Nw', /short)
ncdf_attput, cdfid, havegvNWvarid, 'long_name', $
             'data exists flag for GR_Nw'
ncdf_attput, cdfid, havegvNWvarid, '_FillValue', NO_DATA_PRESENT

havegvMWvarid = ncdf_vardef(cdfid, 'have_GR_liquidWaterContent', /short)
ncdf_attput, cdfid, havegvMWvarid, 'long_name', $
             'data exists flag for GR_liquidWaterContent'
ncdf_attput, cdfid, havegvMWvarid, '_FillValue', NO_DATA_PRESENT

havegvMIvarid = ncdf_vardef(cdfid, 'have_GR_frozenWaterContent', /short)
ncdf_attput, cdfid, havegvMIvarid, 'long_name', $
             'data exists flag for GR_frozenWaterContent'
ncdf_attput, cdfid, havegvMIvarid, '_FillValue', NO_DATA_PRESENT

havegvDMvarid = ncdf_vardef(cdfid, 'have_GR_Dm', /short)
ncdf_attput, cdfid, havegvDMvarid, 'long_name', $
             'data exists flag for GR_Dm'
ncdf_attput, cdfid, havegvDMvarid, '_FillValue', NO_DATA_PRESENT

havegvN2varid = ncdf_vardef(cdfid, 'have_GR_N2', /short)
ncdf_attput, cdfid, havegvN2varid, 'long_name', $
             'data exists flag for GR_N2'
ncdf_attput, cdfid, havegvN2varid, '_FillValue', NO_DATA_PRESENT

haveBLKvarid = ncdf_vardef(cdfid, 'have_GR_blockage', /short)
ncdf_attput, cdfid, haveBLKvarid, 'long_name', $
             'data exists flag for ground radar blockage fraction'
ncdf_attput, cdfid, haveBLKvarid, '_FillValue', NO_DATA_PRESENT

; TAB 8/27/18 added new variables for snowfall water equivalent rate in the VN data using one of 
; the new polarimetric relationships suggested by Bukocvic et al (2017) and Pierre Kirstetter
haveSWEvarid = ncdf_vardef(cdfid, 'have_GR_SWE', /short)
ncdf_attput, cdfid, haveSWEvarid, 'long_name', $
             'data exists flag for ground radar snowfall water equivalent rate'
ncdf_attput, cdfid, haveSWEvarid, '_FillValue', NO_DATA_PRESENT

numDPRScansid = ncdf_vardef(cdfid, 'numDPRScans', /short)
ncdf_attput, cdfid, numDPRScansid, 'long_name', $
             'Number of DPR scans in gr_match file'
ncdf_attput, cdfid, numDPRScansid, '_FillValue', NO_DATA_PRESENT



for iswa=0,N_ELEMENTS(swath)-1 do begin

   ; sweep-level fields, all swath-specific, of same no. of dimensions for each swath

   latvarid = ncdf_vardef(cdfid, 'latitude_'+swath[iswa], [fpdimid[iswa],eldimid])
   ncdf_attput, cdfid, latvarid, 'long_name', 'Latitude of 3-D data sample'
   ncdf_attput, cdfid, latvarid, 'units', 'degrees North'
   ncdf_attput, cdfid, latvarid, '_FillValue', FLOAT_RANGE_EDGE

   lonvarid = ncdf_vardef(cdfid, 'longitude_'+swath[iswa], [fpdimid[iswa],eldimid])
   ncdf_attput, cdfid, lonvarid, 'long_name', 'Longitude of 3-D data sample'
   ncdf_attput, cdfid, lonvarid, 'units', 'degrees East'
   ncdf_attput, cdfid, lonvarid, '_FillValue', FLOAT_RANGE_EDGE

   xvarid = ncdf_vardef(cdfid, 'xCorners_'+swath[iswa], [xydimid,fpdimid[iswa],eldimid])
   ncdf_attput, cdfid, xvarid, 'long_name', 'data sample x corner coords.'
   ncdf_attput, cdfid, xvarid, 'units', 'km'
   ncdf_attput, cdfid, xvarid, '_FillValue', FLOAT_RANGE_EDGE

   yvarid = ncdf_vardef(cdfid, 'yCorners_'+swath[iswa], [xydimid,fpdimid[iswa],eldimid])
   ncdf_attput, cdfid, yvarid, 'long_name', 'data sample y corner coords.'
   ncdf_attput, cdfid, yvarid, 'units', 'km'
   ncdf_attput, cdfid, yvarid, '_FillValue', FLOAT_RANGE_EDGE

   topvarid = ncdf_vardef(cdfid, 'topHeight_'+swath[iswa], [fpdimid[iswa],eldimid])
   ncdf_attput, cdfid, topvarid, 'long_name', 'data sample top height AGL'
   ncdf_attput, cdfid, topvarid, 'units', 'km'
   ncdf_attput, cdfid, topvarid, '_FillValue', FLOAT_RANGE_EDGE

   botmvarid = ncdf_vardef(cdfid, 'bottomHeight_'+swath[iswa], [fpdimid[iswa],eldimid])
   ncdf_attput, cdfid, botmvarid, 'long_name', 'data sample bottom height AGL'
   ncdf_attput, cdfid, botmvarid, 'units', 'km'
   ncdf_attput, cdfid, botmvarid, '_FillValue', FLOAT_RANGE_EDGE

   dbzgvvarid = ncdf_vardef(cdfid, 'GR_Z_'+swath[iswa], [fpdimid[iswa],eldimid])
   ncdf_attput, cdfid, dbzgvvarid, 'long_name', 'GV radar QC Reflectivity'
   ncdf_attput, cdfid, dbzgvvarid, 'units', 'dBZ'
   ncdf_attput, cdfid, dbzgvvarid, '_FillValue', FLOAT_RANGE_EDGE

   stddevgvvarid = ncdf_vardef(cdfid, 'GR_Z_StdDev_'+swath[iswa], [fpdimid[iswa],eldimid])
   ncdf_attput, cdfid, stddevgvvarid, 'long_name', $
             'Standard Deviation of GV radar QC Reflectivity'
   ncdf_attput, cdfid, stddevgvvarid, 'units', 'dBZ'
   ncdf_attput, cdfid, stddevgvvarid, '_FillValue', FLOAT_RANGE_EDGE

   gvmaxvarid = ncdf_vardef(cdfid, 'GR_Z_Max_'+swath[iswa], [fpdimid[iswa],eldimid])
   ncdf_attput, cdfid, gvmaxvarid, 'long_name', $
             'Sample Maximum GV radar QC Reflectivity'
   ncdf_attput, cdfid, gvmaxvarid, 'units', 'dBZ'
   ncdf_attput, cdfid, gvmaxvarid, '_FillValue', FLOAT_RANGE_EDGE

   gvZDRvarid = ncdf_vardef(cdfid, 'GR_Zdr_'+swath[iswa], [fpdimid[iswa],eldimid])
   ncdf_attput, cdfid, gvZDRvarid, 'long_name', 'DP Differential Reflectivity'
   ncdf_attput, cdfid, gvZDRvarid, 'units', 'dB'
   ncdf_attput, cdfid, gvZDRvarid, '_FillValue', FLOAT_RANGE_EDGE

   gvZDRstddevvarid = ncdf_vardef(cdfid, 'GR_Zdr_StdDev_'+swath[iswa], [fpdimid[iswa],eldimid])
   ncdf_attput, cdfid, gvZDRstddevvarid, 'long_name', $
             'Standard Deviation of DP Differential Reflectivity'
   ncdf_attput, cdfid, gvZDRstddevvarid, 'units', 'dB'
   ncdf_attput, cdfid, gvZDRstddevvarid, '_FillValue', FLOAT_RANGE_EDGE

   gvZDRmaxvarid = ncdf_vardef(cdfid, 'GR_Zdr_Max_'+swath[iswa], [fpdimid[iswa],eldimid])
   ncdf_attput, cdfid, gvZDRmaxvarid, 'long_name', $
             'Sample Maximum DP Differential Reflectivity'
   ncdf_attput, cdfid, gvZDRmaxvarid, 'units', 'dB'
   ncdf_attput, cdfid, gvZDRmaxvarid, '_FillValue', FLOAT_RANGE_EDGE

   gvKdpvarid = ncdf_vardef(cdfid, 'GR_Kdp_'+swath[iswa], [fpdimid[iswa],eldimid])
   ncdf_attput, cdfid, gvKdpvarid, 'long_name', 'DP Specific Differential Phase'
   ncdf_attput, cdfid, gvKdpvarid, 'units', 'deg/km'
   ncdf_attput, cdfid, gvKdpvarid, '_FillValue', FLOAT_RANGE_EDGE

   gvKdpstddevvarid = ncdf_vardef(cdfid, 'GR_Kdp_StdDev_'+swath[iswa], [fpdimid[iswa],eldimid])
   ncdf_attput, cdfid, gvKdpstddevvarid, 'long_name', $
             'Standard Deviation of DP Specific Differential Phase'
   ncdf_attput, cdfid, gvKdpstddevvarid, 'units', 'deg/km'
   ncdf_attput, cdfid, gvKdpstddevvarid, '_FillValue', FLOAT_RANGE_EDGE

   gvKdpmaxvarid = ncdf_vardef(cdfid, 'GR_Kdp_Max_'+swath[iswa], [fpdimid[iswa],eldimid])
   ncdf_attput, cdfid, gvKdpmaxvarid, 'long_name', $
             'Sample Maximum DP Specific Differential Phase'
   ncdf_attput, cdfid, gvKdpmaxvarid, 'units', 'deg/km'
   ncdf_attput, cdfid, gvKdpmaxvarid, '_FillValue', FLOAT_RANGE_EDGE

   gvRHOHVvarid = ncdf_vardef(cdfid, 'GR_RHOhv_'+swath[iswa], [fpdimid[iswa],eldimid])
   ncdf_attput, cdfid, gvRHOHVvarid, 'long_name', 'DP Co-Polar Correlation Coefficient'
   ncdf_attput, cdfid, gvRHOHVvarid, 'units', 'Dimensionless'
   ncdf_attput, cdfid, gvRHOHVvarid, '_FillValue', FLOAT_RANGE_EDGE

   gvRHOHVstddevvarid = ncdf_vardef(cdfid, 'GR_RHOhv_StdDev_'+swath[iswa], [fpdimid[iswa],eldimid])
   ncdf_attput, cdfid, gvRHOHVstddevvarid, 'long_name', $
             'Standard Deviation of DP Co-Polar Correlation Coefficient'
   ncdf_attput, cdfid, gvRHOHVstddevvarid, 'units', 'Dimensionless'
   ncdf_attput, cdfid, gvRHOHVstddevvarid, '_FillValue', FLOAT_RANGE_EDGE

   gvRHOHVmaxvarid = ncdf_vardef(cdfid, 'GR_RHOhv_Max_'+swath[iswa], [fpdimid[iswa],eldimid])
   ncdf_attput, cdfid, gvRHOHVmaxvarid, 'long_name', $
             'Sample Maximum DP Co-Polar Correlation Coefficient'
   ncdf_attput, cdfid, gvRHOHVmaxvarid, 'units', 'Dimensionless'
   ncdf_attput, cdfid, gvRHOHVmaxvarid, '_FillValue', FLOAT_RANGE_EDGE

   gvRCvarid = ncdf_vardef(cdfid, 'GR_RC_rainrate_'+swath[iswa], [fpdimid[iswa],eldimid])
   ncdf_attput, cdfid, gvRCvarid, 'long_name', 'GV radar Cifelli Rainrate'
   ncdf_attput, cdfid, gvRCvarid, 'units', 'mm/h'
   ncdf_attput, cdfid, gvRCvarid, '_FillValue', FLOAT_RANGE_EDGE

   stddevgvRCvarid = ncdf_vardef(cdfid, 'GR_RC_rainrate_StdDev_'+swath[iswa], [fpdimid[iswa],eldimid])
   ncdf_attput, cdfid, stddevgvRCvarid, 'long_name', $
             'Standard Deviation of GV radar Cifelli Rainrate'
   ncdf_attput, cdfid, stddevgvRCvarid, 'units', 'mm/h'
   ncdf_attput, cdfid, stddevgvRCvarid, '_FillValue', FLOAT_RANGE_EDGE

   gvmaxRCvarid = ncdf_vardef(cdfid, 'GR_RC_rainrate_Max_'+swath[iswa], [fpdimid[iswa],eldimid])
   ncdf_attput, cdfid, gvmaxRCvarid, 'long_name', $
             'Sample Maximum GV radar Cifelli Rainrate'
   ncdf_attput, cdfid, gvmaxRCvarid, 'units', 'mm/h'
   ncdf_attput, cdfid, gvmaxRCvarid, '_FillValue', FLOAT_RANGE_EDGE

   gvRPvarid = ncdf_vardef(cdfid, 'GR_RP_rainrate_'+swath[iswa], [fpdimid[iswa],eldimid])
   ncdf_attput, cdfid, gvRPvarid, 'long_name', 'GV radar PolZR Rainrate'
   ncdf_attput, cdfid, gvRPvarid, 'units', 'mm/h'
   ncdf_attput, cdfid, gvRPvarid, '_FillValue', FLOAT_RANGE_EDGE

   stddevgvRPvarid = ncdf_vardef(cdfid, 'GR_RP_rainrate_StdDev_'+swath[iswa], [fpdimid[iswa],eldimid])
   ncdf_attput, cdfid, stddevgvRPvarid, 'long_name', $
             'Standard Deviation of GV radar PolZR Rainrate'
   ncdf_attput, cdfid, stddevgvRPvarid, 'units', 'mm/h'
   ncdf_attput, cdfid, stddevgvRPvarid, '_FillValue', FLOAT_RANGE_EDGE

   gvmaxRPvarid = ncdf_vardef(cdfid, 'GR_RP_rainrate_Max_'+swath[iswa], [fpdimid[iswa],eldimid])
   ncdf_attput, cdfid, gvmaxRPvarid, 'long_name', $
             'Sample Maximum GV radar PolZR Rainrate'
   ncdf_attput, cdfid, gvmaxRPvarid, 'units', 'mm/h'
   ncdf_attput, cdfid, gvmaxRPvarid, '_FillValue', FLOAT_RANGE_EDGE

   gvRRvarid = ncdf_vardef(cdfid, 'GR_RR_rainrate_'+swath[iswa], [fpdimid[iswa],eldimid])
   ncdf_attput, cdfid, gvRRvarid, 'long_name', 'GV radar DROPS Rainrate'
   ncdf_attput, cdfid, gvRRvarid, 'units', 'mm/h'
   ncdf_attput, cdfid, gvRRvarid, '_FillValue', FLOAT_RANGE_EDGE

   stddevgvRRvarid = ncdf_vardef(cdfid, 'GR_RR_rainrate_StdDev_'+swath[iswa], [fpdimid[iswa],eldimid])
   ncdf_attput, cdfid, stddevgvRRvarid, 'long_name', $
             'Standard Deviation of GV radar DROPS Rainrate'
   ncdf_attput, cdfid, stddevgvRRvarid, 'units', 'mm/h'
   ncdf_attput, cdfid, stddevgvRRvarid, '_FillValue', FLOAT_RANGE_EDGE

   gvmaxRRvarid = ncdf_vardef(cdfid, 'GR_RR_rainrate_Max_'+swath[iswa], [fpdimid[iswa],eldimid])
   ncdf_attput, cdfid, gvmaxRRvarid, 'long_name', $
             'Sample Maximum GV radar DROPS Rainrate'
   ncdf_attput, cdfid, gvmaxRRvarid, 'units', 'mm/h'
   ncdf_attput, cdfid, gvmaxRRvarid, '_FillValue', FLOAT_RANGE_EDGE

   gvHIDvarid = ncdf_vardef(cdfid, 'GR_HID_'+swath[iswa], [hidimid,fpdimid[iswa],eldimid], /short)
   ncdf_attput, cdfid, gvHIDvarid, 'long_name', 'DP Hydrometeor Identification'
   ncdf_attput, cdfid, gvHIDvarid, 'units', 'Categorical'
   ncdf_attput, cdfid, gvHIDvarid, '_FillValue', INT_RANGE_EDGE

   gvDzerovarid = ncdf_vardef(cdfid, 'GR_Dzero_'+swath[iswa], [fpdimid[iswa],eldimid])
   ncdf_attput, cdfid, gvDzerovarid, 'long_name', 'DP Median Volume Diameter'
   ncdf_attput, cdfid, gvDzerovarid, 'units', 'mm'
   ncdf_attput, cdfid, gvDzerovarid, '_FillValue', FLOAT_RANGE_EDGE

   gvDzerostddevvarid = ncdf_vardef(cdfid, 'GR_Dzero_StdDev_'+swath[iswa], [fpdimid[iswa],eldimid])
   ncdf_attput, cdfid, gvDzerostddevvarid, 'long_name', $
             'Standard Deviation of DP Median Volume Diameter'
   ncdf_attput, cdfid, gvDzerostddevvarid, 'units', 'mm'
   ncdf_attput, cdfid, gvDzerostddevvarid, '_FillValue', FLOAT_RANGE_EDGE

   gvDzeromaxvarid = ncdf_vardef(cdfid, 'GR_Dzero_Max_'+swath[iswa], [fpdimid[iswa],eldimid])
   ncdf_attput, cdfid, gvDzeromaxvarid, 'long_name', $
             'Sample Maximum DP Median Volume Diameter'
   ncdf_attput, cdfid, gvDzeromaxvarid, 'units', 'mm'
   ncdf_attput, cdfid, gvDzeromaxvarid, '_FillValue', FLOAT_RANGE_EDGE

   gvNWvarid = ncdf_vardef(cdfid, 'GR_Nw_'+swath[iswa], [fpdimid[iswa],eldimid])
   ncdf_attput, cdfid, gvNWvarid, 'long_name', 'DP Normalized Intercept Parameter'
   ncdf_attput, cdfid, gvNWvarid, 'units', '1/(mm*m^3)'
   ncdf_attput, cdfid, gvNWvarid, '_FillValue', FLOAT_RANGE_EDGE

   gvNWstddevvarid = ncdf_vardef(cdfid, 'GR_Nw_StdDev_'+swath[iswa], [fpdimid[iswa],eldimid])
   ncdf_attput, cdfid, gvNWstddevvarid, 'long_name', $
             'Standard Deviation of DP Normalized Intercept Parameter'
   ncdf_attput, cdfid, gvNWstddevvarid, 'units', '1/(mm*m^3)'
   ncdf_attput, cdfid, gvNWstddevvarid, '_FillValue', FLOAT_RANGE_EDGE

   gvNWmaxvarid = ncdf_vardef(cdfid, 'GR_Nw_Max_'+swath[iswa], [fpdimid[iswa],eldimid])
   ncdf_attput, cdfid, gvNWmaxvarid, 'long_name', $
             'Sample Maximum DP Normalized Intercept Parameter'
   ncdf_attput, cdfid, gvNWmaxvarid, 'units', '1/(mm*m^3)'
   ncdf_attput, cdfid, gvNWmaxvarid, '_FillValue', FLOAT_RANGE_EDGE

   gvMWvarid = ncdf_vardef(cdfid, 'GR_liquidWaterContent_'+swath[iswa], [fpdimid[iswa],eldimid])
   ncdf_attput, cdfid, gvMWvarid, 'long_name', 'liquid water mass'
   ncdf_attput, cdfid, gvMWvarid, 'units', 'kg/m^3'
   ncdf_attput, cdfid, gvMWvarid, '_FillValue', FLOAT_RANGE_EDGE

   gvMWstddevvarid = ncdf_vardef(cdfid, 'GR_liquidWaterContent_StdDev_'+swath[iswa], [fpdimid[iswa],eldimid])
   ncdf_attput, cdfid, gvMWstddevvarid, 'long_name', 'Standard Deviation of liquid water mass'
   ncdf_attput, cdfid, gvMWstddevvarid, 'units', 'kg/m^3'
   ncdf_attput, cdfid, gvMWstddevvarid, '_FillValue', FLOAT_RANGE_EDGE

   gvMWmaxvarid = ncdf_vardef(cdfid, 'GR_liquidWaterContent_Max_'+swath[iswa], [fpdimid[iswa],eldimid])
   ncdf_attput, cdfid, gvMWmaxvarid, 'long_name', 'Sample Maximum of liquid water mass'
   ncdf_attput, cdfid, gvMWmaxvarid, 'units', 'kg/m^3'
   ncdf_attput, cdfid, gvMWmaxvarid, '_FillValue', FLOAT_RANGE_EDGE

   gvMIvarid = ncdf_vardef(cdfid, 'GR_frozenWaterContent_'+swath[iswa], [fpdimid[iswa],eldimid])
   ncdf_attput, cdfid, gvMIvarid, 'long_name', 'frozen water mass'
   ncdf_attput, cdfid, gvMIvarid, 'units', 'kg/m^3'
   ncdf_attput, cdfid, gvMIvarid, '_FillValue', FLOAT_RANGE_EDGE

   gvMIstddevvarid = ncdf_vardef(cdfid, 'GR_frozenWaterContent_StdDev_'+swath[iswa], [fpdimid[iswa],eldimid])
   ncdf_attput, cdfid, gvMIstddevvarid, 'long_name', 'Standard Deviation of frozen water mass'
   ncdf_attput, cdfid, gvMIstddevvarid, 'units', 'kg/m^3'
   ncdf_attput, cdfid, gvMIstddevvarid, '_FillValue', FLOAT_RANGE_EDGE

   gvMImaxvarid = ncdf_vardef(cdfid, 'GR_frozenWaterContent_Max_'+swath[iswa], [fpdimid[iswa],eldimid])
   ncdf_attput, cdfid, gvMImaxvarid, 'long_name', 'Sample Maximum of frozen water mass'
   ncdf_attput, cdfid, gvMImaxvarid, 'units', 'kg/m^3'
   ncdf_attput, cdfid, gvMImaxvarid, '_FillValue', FLOAT_RANGE_EDGE

   gvDMvarid = ncdf_vardef(cdfid, 'GR_Dm_'+swath[iswa], [fpdimid[iswa],eldimid])
   ncdf_attput, cdfid, gvDMvarid, 'long_name', 'DP Retrieved Median Diameter'
   ncdf_attput, cdfid, gvDMvarid, 'units', 'mm'
   ncdf_attput, cdfid, gvDMvarid, '_FillValue', FLOAT_RANGE_EDGE

   gvDMstddevvarid = ncdf_vardef(cdfid, 'GR_Dm_StdDev_'+swath[iswa], [fpdimid[iswa],eldimid])
   ncdf_attput, cdfid, gvDMstddevvarid, 'long_name', $
                'Standard Deviation of DP Retrieved Median Diameter'
   ncdf_attput, cdfid, gvDMstddevvarid, 'units', 'mm'
   ncdf_attput, cdfid, gvDMstddevvarid, '_FillValue', FLOAT_RANGE_EDGE

   gvDMmaxvarid = ncdf_vardef(cdfid, 'GR_Dm_Max_'+swath[iswa], [fpdimid[iswa],eldimid])
   ncdf_attput, cdfid, gvDMmaxvarid, 'long_name', $
                'Sample Maximum DP Retrieved Median Diameter'
   ncdf_attput, cdfid, gvDMmaxvarid, 'units', 'mm'
   ncdf_attput, cdfid, gvDMmaxvarid, '_FillValue', FLOAT_RANGE_EDGE

   gvN2varid = ncdf_vardef(cdfid, 'GR_N2_'+swath[iswa], [fpdimid[iswa],eldimid])
   ncdf_attput, cdfid, gvN2varid, 'long_name', $
                'Tokay Normalized Intercept Parameter'
   ncdf_attput, cdfid, gvN2varid, 'units', '1/(mm*m^3)'
   ncdf_attput, cdfid, gvN2varid, '_FillValue', FLOAT_RANGE_EDGE

   gvN2stddevvarid = ncdf_vardef(cdfid, 'GR_N2_StdDev_'+swath[iswa], [fpdimid[iswa],eldimid])
   ncdf_attput, cdfid, gvN2stddevvarid, 'long_name', $
                'Standard Deviation of Tokay Normalized Intercept Parameter'
   ncdf_attput, cdfid, gvN2stddevvarid, 'units', '1/(mm*m^3)'
   ncdf_attput, cdfid, gvN2stddevvarid, '_FillValue', FLOAT_RANGE_EDGE

   gvN2maxvarid = ncdf_vardef(cdfid, 'GR_N2_Max_'+swath[iswa], [fpdimid[iswa],eldimid])
   ncdf_attput, cdfid, gvN2maxvarid, 'long_name', $
                'Sample Maximum Tokay Normalized Intercept Parameter'
   ncdf_attput, cdfid, gvN2maxvarid, 'units', '1/(mm*m^3)'
   ncdf_attput, cdfid, gvN2maxvarid, '_FillValue', FLOAT_RANGE_EDGE

   BLKvarid = ncdf_vardef(cdfid, 'GR_blockage_'+swath[iswa], [fpdimid[iswa],eldimid])
   ncdf_attput, cdfid, BLKvarid, 'long_name', 'ground radar blockage fraction'
   ncdf_attput, cdfid, BLKvarid, '_FillValue', FLOAT_RANGE_EDGE

; TAB 8/27/18 added new variables for snowfall water equivalent rate in the VN data using one of 
; the new polarimetric relationships suggested by Bukocvic et al (2017)
   SWEDPvarid = ncdf_vardef(cdfid, 'GR_SWEDP_'+swath[iswa], [fpdimid[iswa],eldimid])
   ncdf_attput, cdfid, SWEDPvarid, 'long_name', 'GV snowfall water equivalent rate, Bukocvic et al (2017)'
   ncdf_attput, cdfid, SWEDPvarid, 'units', 'mm/h'
   ncdf_attput, cdfid, SWEDPvarid, '_FillValue', FLOAT_RANGE_EDGE

   stddevgvSWEDPvarid = ncdf_vardef(cdfid, 'GR_SWEDP_StdDev_'+swath[iswa], [fpdimid[iswa],eldimid])
   ncdf_attput, cdfid, stddevgvSWEDPvarid, 'long_name', $
             'Standard Deviation of GV snowfall water equivalent rate, Bukocvic et al (2017)'
   ncdf_attput, cdfid, stddevgvSWEDPvarid, 'units', 'mm/h'
   ncdf_attput, cdfid, stddevgvSWEDPvarid, '_FillValue', FLOAT_RANGE_EDGE

   gvmaxSWEDPvarid = ncdf_vardef(cdfid, 'GR_SWEDP_Max_'+swath[iswa], [fpdimid[iswa],eldimid])
   ncdf_attput, cdfid, gvmaxSWEDPvarid, 'long_name', $
             'Sample Maximum GV snowfall water equivalent rate, Bukocvic et al (2017)'
   ncdf_attput, cdfid, gvmaxSWEDPvarid, 'units', 'mm/h'
   ncdf_attput, cdfid, gvmaxSWEDPvarid, '_FillValue', FLOAT_RANGE_EDGE
   
   ; Z only relationships
   SWE25varid = ncdf_vardef(cdfid, 'GR_SWE25_'+swath[iswa], [fpdimid[iswa],eldimid])
   ncdf_attput, cdfid, SWE25varid, 'long_name', 'GV snowfall water equivalent rate, PQPE conditional quantiles 25%'
   ncdf_attput, cdfid, SWE25varid, 'units', 'mm/h'
   ncdf_attput, cdfid, SWE25varid, '_FillValue', FLOAT_RANGE_EDGE

   stddevgvSWE25varid = ncdf_vardef(cdfid, 'GR_SWE25_StdDev_'+swath[iswa], [fpdimid[iswa],eldimid])
   ncdf_attput, cdfid, stddevgvSWE25varid, 'long_name', $
             'Standard Deviation of GV snowfall water equivalent rate, PQPE conditional quantiles 25%'
   ncdf_attput, cdfid, stddevgvSWE25varid, 'units', 'mm/h'
   ncdf_attput, cdfid, stddevgvSWE25varid, '_FillValue', FLOAT_RANGE_EDGE

   gvmaxSWE25varid = ncdf_vardef(cdfid, 'GR_SWE25_Max_'+swath[iswa], [fpdimid[iswa],eldimid])
   ncdf_attput, cdfid, gvmaxSWE25varid, 'long_name', $
             'Sample Maximum GV snowfall water equivalent rate,  PQPE conditional quantiles 25%'
   ncdf_attput, cdfid, gvmaxSWE25varid, 'units', 'mm/h'
   ncdf_attput, cdfid, gvmaxSWE25varid, '_FillValue', FLOAT_RANGE_EDGE
   
   SWE50varid = ncdf_vardef(cdfid, 'GR_SWE50_'+swath[iswa], [fpdimid[iswa],eldimid])
   ncdf_attput, cdfid, SWE50varid, 'long_name', 'GV snowfall water equivalent rate, PQPE conditional quantiles 50%'
   ncdf_attput, cdfid, SWE50varid, 'units', 'mm/h'
   ncdf_attput, cdfid, SWE50varid, '_FillValue', FLOAT_RANGE_EDGE

   stddevgvSWE50varid = ncdf_vardef(cdfid, 'GR_SWE50_StdDev_'+swath[iswa], [fpdimid[iswa],eldimid])
   ncdf_attput, cdfid, stddevgvSWE50varid, 'long_name', $
             'Standard Deviation of GV snowfall water equivalent rate, PQPE conditional quantiles 50%'
   ncdf_attput, cdfid, stddevgvSWE50varid, 'units', 'mm/h'
   ncdf_attput, cdfid, stddevgvSWE50varid, '_FillValue', FLOAT_RANGE_EDGE

   gvmaxSWE50varid = ncdf_vardef(cdfid, 'GR_SWE50_Max_'+swath[iswa], [fpdimid[iswa],eldimid])
   ncdf_attput, cdfid, gvmaxSWE50varid, 'long_name', $
             'Sample Maximum GV snowfall water equivalent rate,  PQPE conditional quantiles 50%'
   ncdf_attput, cdfid, gvmaxSWE50varid, 'units', 'mm/h'
   ncdf_attput, cdfid, gvmaxSWE50varid, '_FillValue', FLOAT_RANGE_EDGE
   
   SWE75varid = ncdf_vardef(cdfid, 'GR_SWE75_'+swath[iswa], [fpdimid[iswa],eldimid])
   ncdf_attput, cdfid, SWE75varid, 'long_name', 'GV snowfall water equivalent rate, PQPE conditional quantiles 75%'
   ncdf_attput, cdfid, SWE75varid, 'units', 'mm/h'
   ncdf_attput, cdfid, SWE75varid, '_FillValue', FLOAT_RANGE_EDGE

   stddevgvSWE75varid = ncdf_vardef(cdfid, 'GR_SWE75_StdDev_'+swath[iswa], [fpdimid[iswa],eldimid])
   ncdf_attput, cdfid, stddevgvSWE75varid, 'long_name', $
             'Standard Deviation of GV snowfall water equivalent rate, PQPE conditional quantiles 75%'
   ncdf_attput, cdfid, stddevgvSWE75varid, 'units', 'mm/h'
   ncdf_attput, cdfid, stddevgvSWE75varid, '_FillValue', FLOAT_RANGE_EDGE

   gvmaxSWE75varid = ncdf_vardef(cdfid, 'GR_SWE75_Max_'+swath[iswa], [fpdimid[iswa],eldimid])
   ncdf_attput, cdfid, gvmaxSWE75varid, 'long_name', $
             'Sample Maximum GV snowfall water equivalent rate,  PQPE conditional quantiles 75%'
   ncdf_attput, cdfid, gvmaxSWE75varid, 'units', 'mm/h'
   ncdf_attput, cdfid, gvmaxSWE75varid, '_FillValue', FLOAT_RANGE_EDGE

   SWEMQTvarid = ncdf_vardef(cdfid, 'GR_SWEMQT_'+swath[iswa], [fpdimid[iswa],eldimid])
   ncdf_attput, cdfid, SWEMQTvarid, 'long_name', 'GV snowfall water equivalent rate, Marquette relationship'
   ncdf_attput, cdfid, SWEMQTvarid, 'units', 'mm/h'
   ncdf_attput, cdfid, SWEMQTvarid, '_FillValue', FLOAT_RANGE_EDGE

   stddevgvSWEMQTvarid = ncdf_vardef(cdfid, 'GR_SWEMQT_StdDev_'+swath[iswa], [fpdimid[iswa],eldimid])
   ncdf_attput, cdfid, stddevgvSWEMQTvarid, 'long_name', $
             'Standard Deviation of GV snowfall water equivalent rate, Marquette relationship'
   ncdf_attput, cdfid, stddevgvSWEMQTvarid, 'units', 'mm/h'
   ncdf_attput, cdfid, stddevgvSWEMQTvarid, '_FillValue', FLOAT_RANGE_EDGE

   gvmaxSWEMQTvarid = ncdf_vardef(cdfid, 'GR_SWEMQT_Max_'+swath[iswa], [fpdimid[iswa],eldimid])
   ncdf_attput, cdfid, gvmaxSWEMQTvarid, 'long_name', $
             'Sample Maximum GV snowfall water equivalent rate,  Marquette relationship'
   ncdf_attput, cdfid, gvmaxSWEMQTvarid, 'units', 'mm/h'
   ncdf_attput, cdfid, gvmaxSWEMQTvarid, '_FillValue', FLOAT_RANGE_EDGE

   SWEMRMSvarid = ncdf_vardef(cdfid, 'GR_SWEMRMS_'+swath[iswa], [fpdimid[iswa],eldimid])
   ncdf_attput, cdfid, SWEMRMSvarid, 'long_name', 'GV snowfall water equivalent rate, MRMS relationship'
   ncdf_attput, cdfid, SWEMRMSvarid, 'units', 'mm/h'
   ncdf_attput, cdfid, SWEMRMSvarid, '_FillValue', FLOAT_RANGE_EDGE

   stddevgvSWEMRMSvarid = ncdf_vardef(cdfid, 'GR_SWEMRMS_StdDev_'+swath[iswa], [fpdimid[iswa],eldimid])
   ncdf_attput, cdfid, stddevgvSWEMRMSvarid, 'long_name', $
             'Standard Deviation of GV snowfall water equivalent rate, MRMS relationship'
   ncdf_attput, cdfid, stddevgvSWEMRMSvarid, 'units', 'mm/h'
   ncdf_attput, cdfid, stddevgvSWEMRMSvarid, '_FillValue', FLOAT_RANGE_EDGE

   gvmaxSWEMRMSvarid = ncdf_vardef(cdfid, 'GR_SWEMRMS_Max_'+swath[iswa], [fpdimid[iswa],eldimid])
   ncdf_attput, cdfid, gvmaxSWEMRMSvarid, 'long_name', $
             'Sample Maximum GV snowfall water equivalent rate, MRMS relationship'
   ncdf_attput, cdfid, gvmaxSWEMRMSvarid, 'units', 'mm/h'
   ncdf_attput, cdfid, gvmaxSWEMRMSvarid, '_FillValue', FLOAT_RANGE_EDGE
   

;*******************

   gvrejvarid = ncdf_vardef(cdfid, 'n_gr_z_rejected_'+swath[iswa], [fpdimid[iswa],eldimid], /short)
   ncdf_attput, cdfid, gvrejvarid, 'long_name', $
             'number of bins below GR_dBZ_min in GR_Z average'
   ncdf_attput, cdfid, gvrejvarid, '_FillValue', INT_RANGE_EDGE

   gv_zdr_rejvarid = ncdf_vardef(cdfid, 'n_gr_zdr_rejected_'+swath[iswa], [fpdimid[iswa],eldimid], /short)
   ncdf_attput, cdfid, gv_zdr_rejvarid, 'long_name', $
             'number of bins with missing Zdr in GR_Zdr average'
   ncdf_attput, cdfid, gv_zdr_rejvarid, '_FillValue', INT_RANGE_EDGE

   gv_kdp_rejvarid = ncdf_vardef(cdfid, 'n_gr_kdp_rejected_'+swath[iswa], [fpdimid[iswa],eldimid], /short)
   ncdf_attput, cdfid, gv_kdp_rejvarid, 'long_name', $
             'number of bins with missing Kdp in GR_Kdp average'
   ncdf_attput, cdfid, gv_kdp_rejvarid, '_FillValue', INT_RANGE_EDGE

   gv_rhohv_rejvarid = ncdf_vardef(cdfid, 'n_gr_rhohv_rejected_'+swath[iswa], [fpdimid[iswa],eldimid], /short)
   ncdf_attput, cdfid, gv_rhohv_rejvarid, 'long_name', $
             'number of bins with missing RHOhv in GR_RHOhv average'
   ncdf_attput, cdfid, gv_rhohv_rejvarid, '_FillValue', INT_RANGE_EDGE

   gv_rc_rejvarid = ncdf_vardef(cdfid, 'n_gr_rc_rejected_'+swath[iswa], [fpdimid[iswa],eldimid], /short)
   ncdf_attput, cdfid, gv_rc_rejvarid, 'long_name', $
             'number of bins below rain_min in GR_RC_rainrate average'
   ncdf_attput, cdfid, gv_rc_rejvarid, '_FillValue', INT_RANGE_EDGE

   gv_rp_rejvarid = ncdf_vardef(cdfid, 'n_gr_rp_rejected_'+swath[iswa], [fpdimid[iswa],eldimid], /short)
   ncdf_attput, cdfid, gv_rp_rejvarid, 'long_name', $
             'number of bins below rain_min in GR_RP_rainrate average'
   ncdf_attput, cdfid, gv_rp_rejvarid, '_FillValue', INT_RANGE_EDGE

   gv_rr_rejvarid = ncdf_vardef(cdfid, 'n_gr_rr_rejected_'+swath[iswa], [fpdimid[iswa],eldimid], /short)
   ncdf_attput, cdfid, gv_rr_rejvarid, 'long_name', $
             'number of bins below rain_min in GR_RR_rainrate average'
   ncdf_attput, cdfid, gv_rr_rejvarid, '_FillValue', INT_RANGE_EDGE

   gv_swedp_rejvarid = ncdf_vardef(cdfid, 'n_gr_swedp_rejected_'+swath[iswa], [fpdimid[iswa],eldimid], /short)
   ncdf_attput, cdfid, gv_swedp_rejvarid, 'long_name', $
             'number of bins below rain_min in GR_SWEDP_rainrate average'
   ncdf_attput, cdfid, gv_swedp_rejvarid, '_FillValue', INT_RANGE_EDGE

   gv_swe25_rejvarid = ncdf_vardef(cdfid, 'n_gr_swe25_rejected_'+swath[iswa], [fpdimid[iswa],eldimid], /short)
   ncdf_attput, cdfid, gv_swe25_rejvarid, 'long_name', $
             'number of bins below rain_min in GR_SWE25_rainrate average'
   ncdf_attput, cdfid, gv_swe25_rejvarid, '_FillValue', INT_RANGE_EDGE

   gv_swe50_rejvarid = ncdf_vardef(cdfid, 'n_gr_swe50_rejected_'+swath[iswa], [fpdimid[iswa],eldimid], /short)
   ncdf_attput, cdfid, gv_swe50_rejvarid, 'long_name', $
             'number of bins below rain_min in GR_SWE50_rainrate average'
   ncdf_attput, cdfid, gv_swe50_rejvarid, '_FillValue', INT_RANGE_EDGE

   gv_swe75_rejvarid = ncdf_vardef(cdfid, 'n_gr_swe75_rejected_'+swath[iswa], [fpdimid[iswa],eldimid], /short)
   ncdf_attput, cdfid, gv_swe75_rejvarid, 'long_name', $
             'number of bins below rain_min in GR_SWE75_rainrate average'
   ncdf_attput, cdfid, gv_swe75_rejvarid, '_FillValue', INT_RANGE_EDGE

   gv_swemqt_rejvarid = ncdf_vardef(cdfid, 'n_gr_swemqt_rejected_'+swath[iswa], [fpdimid[iswa],eldimid], /short)
   ncdf_attput, cdfid, gv_swemqt_rejvarid, 'long_name', $
             'number of bins below rain_min in GR_SWEMQT_rainrate average'
   ncdf_attput, cdfid, gv_swemqt_rejvarid, '_FillValue', INT_RANGE_EDGE

   gv_swemrms_rejvarid = ncdf_vardef(cdfid, 'n_gr_swemrms_rejected_'+swath[iswa], [fpdimid[iswa],eldimid], /short)
   ncdf_attput, cdfid, gv_swemrms_rejvarid, 'long_name', $
             'number of bins below rain_min in GR_SWEMRMS_rainrate average'
   ncdf_attput, cdfid, gv_swemrms_rejvarid, '_FillValue', INT_RANGE_EDGE

   gv_hid_rejvarid = ncdf_vardef(cdfid, 'n_gr_hid_rejected_'+swath[iswa], [fpdimid[iswa],eldimid], /short)
   ncdf_attput, cdfid, gv_hid_rejvarid, 'long_name', $
             'number of bins with undefined HID in GR_HID histogram'
   ncdf_attput, cdfid, gv_hid_rejvarid, '_FillValue', INT_RANGE_EDGE

   gv_dzero_rejvarid = ncdf_vardef(cdfid, 'n_gr_dzero_rejected_'+swath[iswa], [fpdimid[iswa],eldimid], /short)
   ncdf_attput, cdfid, gv_dzero_rejvarid, 'long_name', $
             'number of bins with missing D0 in GR_Dzero average'
   ncdf_attput, cdfid, gv_dzero_rejvarid, '_FillValue', INT_RANGE_EDGE

   gv_nw_rejvarid = ncdf_vardef(cdfid, 'n_gr_nw_rejected_'+swath[iswa], [fpdimid[iswa],eldimid], /short)
   ncdf_attput, cdfid, gv_nw_rejvarid, 'long_name', $
             'number of bins with missing Nw in GR_Nw average'
   ncdf_attput, cdfid, gv_nw_rejvarid, '_FillValue', INT_RANGE_EDGE

   gv_mw_rejvarid = ncdf_vardef(cdfid, 'n_gr_liquidWaterContent_rejected_'+swath[iswa], [fpdimid[iswa],eldimid], /short)
   ncdf_attput, cdfid, gv_mw_rejvarid, 'long_name', $
             'number of bins with missing liquidWaterContent in GR_liquidWaterContent average'
   ncdf_attput, cdfid, gv_mw_rejvarid, '_FillValue', INT_RANGE_EDGE

   gv_mi_rejvarid = ncdf_vardef(cdfid, 'n_gr_frozenWaterContent_rejected_'+swath[iswa], [fpdimid[iswa],eldimid], /short)
   ncdf_attput, cdfid, gv_mi_rejvarid, 'long_name', $
             'number of bins with missing frozenWaterContent in GR_frozenWaterContent average'
   ncdf_attput, cdfid, gv_mi_rejvarid, '_FillValue', INT_RANGE_EDGE

   gv_dm_rejvarid = ncdf_vardef(cdfid, 'n_gr_dm_rejected_'+swath[iswa], [fpdimid[iswa],eldimid], /short)
   ncdf_attput, cdfid, gv_dm_rejvarid, 'long_name', $
                'number of bins with missing Dm in GR_Dm average'
   ncdf_attput, cdfid, gv_dm_rejvarid, '_FillValue', INT_RANGE_EDGE

   gv_n2_rejvarid = ncdf_vardef(cdfid, 'n_gr_n2_rejected_'+swath[iswa], [fpdimid[iswa],eldimid], /short)
   ncdf_attput, cdfid, gv_n2_rejvarid, 'long_name', $
                'number of bins with missing N2 in GR_N2 average'
   ncdf_attput, cdfid, gv_n2_rejvarid, '_FillValue', INT_RANGE_EDGE

   gvexpvarid = ncdf_vardef(cdfid, 'n_gr_expected_'+swath[iswa], [fpdimid[iswa],eldimid], /short)
   ncdf_attput, cdfid, gvexpvarid, 'long_name', $
             'number of bins in GR_Z average'
   ncdf_attput, cdfid, gvexpvarid, '_FillValue', INT_RANGE_EDGE


   sfclatvarid = ncdf_vardef(cdfid, 'DPRlatitude_'+swath[iswa], [fpdimid[iswa]])
   ncdf_attput, cdfid, sfclatvarid, 'long_name', $
                'Latitude of DPR surface bin for '+swath[iswa]+' swath'
   ncdf_attput, cdfid, sfclatvarid, 'units', 'degrees North'
   ncdf_attput, cdfid, sfclatvarid, '_FillValue', FLOAT_RANGE_EDGE

   sfclonvarid = ncdf_vardef(cdfid, 'DPRlongitude_'+swath[iswa], [fpdimid[iswa]])
   ncdf_attput, cdfid, sfclonvarid, 'long_name', $
                'Longitude of DPR surface bin for '+swath[iswa]+' swath'
   ncdf_attput, cdfid, sfclonvarid, 'units', 'degrees East'
   ncdf_attput, cdfid, sfclonvarid, '_FillValue', FLOAT_RANGE_EDGE

   scanidxvarid = ncdf_vardef(cdfid, 'scanNum_'+swath[iswa], [fpdimid[iswa]], /short)
   ncdf_attput, cdfid, scanidxvarid, 'long_name', $
                'product-relative zero-based DPR scan number for '+swath[iswa]+' swath'
   ncdf_attput, cdfid, scanidxvarid, '_FillValue', INT_RANGE_EDGE

   rayidxvarid = ncdf_vardef(cdfid, 'rayNum_'+swath[iswa], [fpdimid[iswa]], /short)
   ncdf_attput, cdfid, rayidxvarid, 'long_name', $
                'product-relative zero-based DPR ray number for '+swath[iswa]+' swath'
   ncdf_attput, cdfid, rayidxvarid, '_FillValue', INT_RANGE_EDGE

endfor   ; swaths

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

sitedimid = ncdf_dimdef(cdfid, 'len_site_ID', STRLEN(siteID))
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

frzlvlvarid = ncdf_vardef(cdfid, 'freezing_level_height')
ncdf_attput, cdfid, frzlvlvarid, 'long_name', 'Model-based freezing level height AGL'
ncdf_attput, cdfid, frzlvlvarid, 'units', 'km'
ncdf_attput, cdfid, frzlvlvarid, '_FillValue', -9999.

;
ncdf_control, cdfid, /endef
;
ncdf_varput, cdfid, elvarid, elev_angles
ncdf_varput, cdfid, sitevarid, siteID
ncdf_varput, cdfid, atimevarid, '01-01-1970 00:00:00'
FOR iel = 0,N_ELEMENTS(elev_angles)-1 DO BEGIN
   ncdf_varput, cdfid, agvtimevarid, '01-01-1970 00:00:00', OFFSET=[0,iel]
ENDFOR

ncdf_varput, cdfid, vnversvarid, GEO_MATCH_FILE_VERSION ;GEO_MATCH_NC_FILE_VERS
ncdf_varput, cdfid, frzlvlvarid, freezing_level_height

IF numpts_HS GT 0 THEN NCDF_VARPUT, cdfid, 'have_swath_HS', DATA_PRESENT
IF numpts_FS GT 0 THEN NCDF_VARPUT, cdfid, 'have_swath_FS_Ku', DATA_PRESENT
IF numpts_FS GT 0 THEN NCDF_VARPUT, cdfid, 'have_swath_FS_Ka', DATA_PRESENT

ncdf_close, cdfid

GOTO, normalExit

versionOnly:
return, "NoGeoMatchFile"

normalExit:
return, geo_match_nc_file

end
