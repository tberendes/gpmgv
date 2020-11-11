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
; gen_dprgmi_geo_match_netcdf_v6.pro    Bob Morris, GPM GV (SAIC)    May 2014
;
; DESCRIPTION:
; Using the "special values" parameters in the 'include' file dpr_params.inc,
; the path parameters in environs.inc, and supplied parameters for the filename,
; number of DPR footprints in the matchup for each swath (MS, NS), the array of
; elevation angles in the ground radar volume scan, the number of scans in the
; input 2B_DPRGMI subset file for each swath type, and global variables for the
; UF data field used for GR reflectivity and various dual-pol fields, and the
; DPR product version, creates an empty DPRGMI/GR matchup netCDF file.
;
; The netCDF file name supplied is expected to be a complete file basename and
; to contain fields for YYMMDD, the GPM orbit number, and the ID of the ground
; radar site, as well as the '.nc' file extension.  No checking of the file name
; pre-existence, uniqueness, or conformance is performed in this module.
;
; HISTORY:
; 05/05/2013 by Bob Morris, GPM GV (SAIC)
;  - Created from gen_dpr_geo_match_netcdf.pro.
; 10/13/2014 by Bob Morris, GPM GV (SAIC)
;  - Added have_swath_MS flag variable to indicate whether there is data for the
;    MS swath variables, and made sure to define at least one footprint for the
;    MS swath if numpts_MS is zero so that these variables are included in the
;    file.
; 11/10/14 by Bob Morris, GPM GV (SAIC)
;  - Added processing of GR RC and RP rainrate fields for version 1.1 file.
; 06/16/15 by Bob Morris, GPM GV (SAIC)
;  - Added zeroDegAltitude and zeroDegBin fields to substitute for bright band
;    height not available in the 2BDPRGMI.
; 12/22/15 by Bob Morris, GPM GV (SAIC)
;  - Added GR_blockage swath variables and existence flag for version 1.2 file.
; 04/19/16 by Bob Morris, GPM GV (SAIC)
;  - Added clutterStatus variables for both swaths/instruments for version 1.21
;    file.
; 07/11/16 by Bob Morris, GPM GV (SAIC)
;  - Added processing of GR Dm and N2 dual-pol fields for version 1.3 file.
; 11/19/16 by Bob Morris, GPM GV (SAIC)
;  - Added DPRGMI stormTopAltitude field for version 1.3 file.
; 10/26/20 by Todd Berendes (UAH)
;    Added new fields for: 
;		precipTotWaterContSigma
;		cloudLiqWaterCont
;		cloudIceWaterCont
;		simulatedBrightTemp 
;			tbSim_19v = 3rd nemiss index
;			tbSim_37v = 6th nemiss index
;			tbSim_89v = 8th nemiss index
;			tbSim_183_3v = 12th nemiss index
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;-------------------------------------------------------------------------------
;-

FUNCTION gen_dprgmi_geo_match_netcdf_v6, geo_match_nc_file, numpts_MS, numpts_NS, $
                                      elev_angles, numscans_MS, numscans_NS, $
                                      gv_UF_field, DPR_vers, siteID, $
                                      dprgrfiles, GEO_MATCH_VERS=geo_match_vers

; "Include" file for DATA_PRESENT, NO_DATA_PRESENT
@grid_def.inc
; "Include" files for constants, names, paths, etc.
@environs.inc   ; for file prefixes, netCDF file definition version
@dpr_params.inc  ; for the type-specific fill values

; TAB 2/4/19 incremented version for new snow fields
;GEO_MATCH_FILE_VERSION=1.31   ; hard code inside function now, not from "Include"
; TAB 11/10/20 changed version to 2.0 from 1.31 for additional GPM fields
GEO_MATCH_FILE_VERSION=2.0   ; hard code inside function now, not from "Include"

IF ( N_ELEMENTS(geo_match_vers) NE 0 ) THEN BEGIN
  ; assign optional keyword parameter value for "versionOnly" calling mode
   geo_match_vers = GEO_MATCH_FILE_VERSION
ENDIF

IF ( N_PARAMS() LT 9 ) THEN GOTO, versionOnly

; Create the output dir for the netCDF file, if needed:
OUTDIR = FILE_DIRNAME(geo_match_nc_file)
spawn, 'mkdir -p ' + OUTDIR

cdfid = ncdf_create(geo_match_nc_file, /CLOBBER)

; define the two swaths in the DPRGMI product, we need separate variables
; for each swath for the science variables
swath = ['MS','NS']

; global variables -- THE FIRST GLOBAL VARIABLE MUST BE 'DPR_Version'
ncdf_attput, cdfid, 'DPR_Version', DPR_vers, /global
;ncdf_attput, cdfid, 'DPR_ScanType', scanType, /global
;ncdf_attput, cdfid, 'GR_UF_Z_field', gr_UF_field, /global


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
ncdf_attput, cdfid, 'GV_UF_DM_field', dmuf, /global
ncdf_attput, cdfid, 'GV_UF_N2_field', n2uf, /global


; identify the input file names for their global attributes.  We could just rely
; on each file type being in a fixed order in the array, but let's make things
; complicated and search for patterns

IF ( N_PARAMS() EQ 10 ) THEN BEGIN
   idxfiles = lonarr( N_ELEMENTS(dprgrfiles) )

   idxCOMB = WHERE(STRMATCH(dprgrfiles,'2B*.GPM.DPRGMI*', /FOLD_CASE) EQ 1, countCOMB)
   if countCOMB EQ 1 THEN BEGIN
      origCOMBFileName = STRJOIN(STRTRIM(dprgrfiles[idxCOMB],2))
      idxfiles[idxCOMB] = 1
   endif else begin
      idxCOMB = WHERE(STRPOS(dprgrfiles,'no_2BCMB_file') GE 0, countCOMB)
      if countCOMB EQ 1 THEN BEGIN
         origCOMBFileName = STRJOIN(STRTRIM(dprgrfiles[idxCOMB],2))
         idxfiles[idxCOMB] = 1
      endif ELSE origCOMBFileName='no_2BCMB_file'
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
   origCOMBFileName='Unspecified'
   origGRFileName='Unspecified'
ENDELSE

ncdf_attput, cdfid, 'DPR_2BCMB_file', origCOMBFileName, /global
ncdf_attput, cdfid, 'GR_file', origGRFileName, /global


; field dimensions.  See dpr_params.inc for fixed values like nPSDlo, nKuKa, etc.

fpdimid_MS = ncdf_dimdef(cdfid, 'fpdim_MS', numpts_MS>1)  ; # of MS footprints in range
fpdimid_NS = ncdf_dimdef(cdfid, 'fpdim_NS', numpts_NS)  ; # of NS footprints in range
fpdimid = [ fpdimid_MS, fpdimid_NS ]                    ; match to "swath" array, above
eldimid = ncdf_dimdef(cdfid, 'elevationAngle', N_ELEMENTS(elev_angles))
xydimid = ncdf_dimdef(cdfid, 'xydim', 4)        ; for 4 corners of a DPR footprint
hidimid = ncdf_dimdef(cdfid, 'hidim', 15)       ; for Hydromet ID Categories
nPSDlo_dimid = ncdf_dimdef(cdfid, 'nPSDlo', nPSDlo)  ; no. of low-res PSD parms.
nBnPSDlo_dimid = ncdf_dimdef(cdfid, 'nBnPSDlo', nBnPSDlo)  ; no. of bins of low-res PSD parms.
nKuKa_dimid = ncdf_dimdef(cdfid, 'nKuKa', nKuKa)    ; no. of Ku and Ka for some MS swath vars.
nPhsBnN_dimid = ncdf_dimdef(cdfid, 'nPhsBnN', nPhsBnN)  ; no. of phase bin nodes
timedimid_MS = ncdf_dimdef(cdfid, 'timedimid_MS', numscans_MS>1)  ; # of MS scans in range
timedimid_NS = ncdf_dimdef(cdfid, 'timedimid_NS', numscans_NS)  ; # of NS scans in range
timedimid = [ timedimid_MS, timedimid_NS ]                      ; match to "swath" array, above


; Elevation Angles coordinate variable

elvarid = ncdf_vardef(cdfid, 'elevationAngle', [eldimid])
ncdf_attput, cdfid, elvarid, 'long_name', $
            'Radar Sweep Elevation Angles'
ncdf_attput, cdfid, elvarid, 'units', 'degrees'

; are there any MS scan points in the GR range limit?

haveswathvarid = ncdf_vardef(cdfid, 'have_swath_MS', /short)
ncdf_attput, cdfid, haveswathvarid, 'long_name', $
             'data exists flag for MS swath'
ncdf_attput, cdfid, haveswathvarid, '_FillValue', NO_DATA_PRESENT

; scanTime components, one datetime per scan, swath-specific

for iswa=0,1 do begin
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

for iswa=0,1 do begin
   sscansid = ncdf_vardef(cdfid, 'startScan_'+swath[iswa], /long)
   ncdf_attput, cdfid, sscansid, 'long_name', $
                'Starting DPR '+swath[iswa]+' overlap scan in original dataset, zero-based'
   ncdf_attput, cdfid, sscansid, '_FillValue', LONG(INT_RANGE_EDGE)

   escansid = ncdf_vardef(cdfid, 'endScan_'+swath[iswa], /long)
   ncdf_attput, cdfid, escansid, 'long_name', $
                'Ending DPR '+swath[iswa]+' overlap scan in original dataset, zero-based'
   ncdf_attput, cdfid, escansid, '_FillValue', LONG(INT_RANGE_EDGE)

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

prdbzthreshid = ncdf_vardef(cdfid, 'DPR_dBZ_min')
ncdf_attput, cdfid, prdbzthreshid, 'long_name', $
             'minimum DPR bin dBZ required for a *complete* DPR vertical average'
ncdf_attput, cdfid, prdbzthreshid, '_FillValue', FLOAT_RANGE_EDGE
ncdf_attput, cdfid, prdbzthreshid, 'units', 'dBZ'

gvdbzthreshid = ncdf_vardef(cdfid, 'GR_dBZ_min')
ncdf_attput, cdfid, gvdbzthreshid, 'long_name', $
             'minimum GR bin dBZ required for a *complete* GR horizontal average'
ncdf_attput, cdfid, gvdbzthreshid, '_FillValue', FLOAT_RANGE_EDGE
ncdf_attput, cdfid, gvdbzthreshid, 'units', 'dBZ'

rainthreshid = ncdf_vardef(cdfid, 'rain_min')
ncdf_attput, cdfid, rainthreshid, 'long_name', $
             'minimum DPR rainrate required for a *complete* DPR vertical average'
ncdf_attput, cdfid, rainthreshid, '_FillValue', FLOAT_RANGE_EDGE
ncdf_attput, cdfid, rainthreshid, 'units', 'mm/h'


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
; the new polarimetric relationships suggested by Bukocvic et al (2017)
haveSWEvarid = ncdf_vardef(cdfid, 'have_GR_SWE', /short)
ncdf_attput, cdfid, haveSWEvarid, 'long_name', $
             'data exists flag for ground radar snowfall water equivalent rate'
ncdf_attput, cdfid, haveSWEvarid, '_FillValue', NO_DATA_PRESENT


for iswa=0,1 do begin

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
   ncdf_attput, cdfid, gvN2varid, 'long_name', 'Tokay Normalized Intercept Parameter'
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

   gv_dm_rejvarid = ncdf_vardef(cdfid, 'n_gr_dm_rejected_'+swath[iswa], [fpdimid,eldimid], /short)
   ncdf_attput, cdfid, gv_dm_rejvarid, 'long_name', $
                'number of bins with missing Dm in GR_Dm average'
   ncdf_attput, cdfid, gv_dm_rejvarid, '_FillValue', INT_RANGE_EDGE

   gv_n2_rejvarid = ncdf_vardef(cdfid, 'n_gr_n2_rejected_'+swath[iswa], [fpdimid,eldimid], /short)
   ncdf_attput, cdfid, gv_n2_rejvarid, 'long_name', $
                'number of bins with missing N2 in GR_N2 average'
   ncdf_attput, cdfid, gv_n2_rejvarid, '_FillValue', INT_RANGE_EDGE

   gvexpvarid = ncdf_vardef(cdfid, 'n_gr_expected_'+swath[iswa], [fpdimid[iswa],eldimid], /short)
   ncdf_attput, cdfid, gvexpvarid, 'long_name', $
             'number of bins in GR_Z average'
   ncdf_attput, cdfid, gvexpvarid, '_FillValue', INT_RANGE_EDGE
   
   ; TAB 8/27/18 added new variables for snowfall water equivalent rate in the VN data using one of 
; the new polarimetric relationships suggested by Bukocvic et al (2017)

;***********  
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
   
   gv_swedp_rejvarid = ncdf_vardef(cdfid, 'n_gr_swedp_rejected_'+swath[iswa], [fpdimid[iswa],eldimid], /short)
   ncdf_attput, cdfid, gv_swedp_rejvarid, 'long_name', $
             'number of bins below rain_min in GR_SWEDP average'
   ncdf_attput, cdfid, gv_swedp_rejvarid, '_FillValue', INT_RANGE_EDGE
   
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
             'Sample Maximum GV snowfall water equivalent rate, PQPE conditional quantiles 25%'
   ncdf_attput, cdfid, gvmaxSWE25varid, 'units', 'mm/h'
   ncdf_attput, cdfid, gvmaxSWE25varid, '_FillValue', FLOAT_RANGE_EDGE
   
   gv_SWE25_rejvarid = ncdf_vardef(cdfid, 'n_gr_swe25_rejected_'+swath[iswa], [fpdimid[iswa],eldimid], /short)
   ncdf_attput, cdfid, gv_SWE25_rejvarid, 'long_name', $
             'number of bins below rain_min in GR_SWE25 average'
   ncdf_attput, cdfid, gv_SWE25_rejvarid, '_FillValue', INT_RANGE_EDGE

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
             'Sample Maximum GV snowfall water equivalent rate, PQPE conditional quantiles 50%'
   ncdf_attput, cdfid, gvmaxSWE50varid, 'units', 'mm/h'
   ncdf_attput, cdfid, gvmaxSWE50varid, '_FillValue', FLOAT_RANGE_EDGE
   
   gv_SWE50_rejvarid = ncdf_vardef(cdfid, 'n_gr_swe50_rejected_'+swath[iswa], [fpdimid[iswa],eldimid], /short)
   ncdf_attput, cdfid, gv_SWE50_rejvarid, 'long_name', $
             'number of bins below rain_min in GR_SWE50 average'
   ncdf_attput, cdfid, gv_SWE50_rejvarid, '_FillValue', INT_RANGE_EDGE

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
             'Sample Maximum GV snowfall water equivalent rate, PQPE conditional quantiles 75%'
   ncdf_attput, cdfid, gvmaxSWE75varid, 'units', 'mm/h'
   ncdf_attput, cdfid, gvmaxSWE75varid, '_FillValue', FLOAT_RANGE_EDGE
   
   gv_SWE75_rejvarid = ncdf_vardef(cdfid, 'n_gr_swe75_rejected_'+swath[iswa], [fpdimid[iswa],eldimid], /short)
   ncdf_attput, cdfid, gv_SWE75_rejvarid, 'long_name', $
             'number of bins below rain_min in GR_SWE75 average'
   ncdf_attput, cdfid, gv_SWE75_rejvarid, '_FillValue', INT_RANGE_EDGE

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

   gv_swemqt_rejvarid = ncdf_vardef(cdfid, 'n_gr_swemqt_rejected_'+swath[iswa], [fpdimid[iswa],eldimid], /short)
   ncdf_attput, cdfid, gv_swemqt_rejvarid, 'long_name', $
             'number of bins below rain_min in GR_SWEMQT_rainrate average'
   ncdf_attput, cdfid, gv_swemqt_rejvarid, '_FillValue', INT_RANGE_EDGE

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

   gv_swemrms_rejvarid = ncdf_vardef(cdfid, 'n_gr_swemrms_rejected_'+swath[iswa], [fpdimid[iswa],eldimid], /short)
   ncdf_attput, cdfid, gv_swemrms_rejvarid, 'long_name', $
             'number of bins below rain_min in GR_SWEMRMS_rainrate average'
   ncdf_attput, cdfid, gv_swemrms_rejvarid, '_FillValue', INT_RANGE_EDGE

;*******************
   

   ; DPRGMI swath-level fields of same no. of dimensions for each swath

   this_varid = ncdf_vardef(cdfid, 'precipTotPSDparamHigh_'+swath[iswa], [fpdimid[iswa],eldimid])
   ncdf_attput, cdfid, this_varid, 'long_name', $
               '2B-DPRGMI precipTotPSDparamHigh for '+swath[iswa]+' swath'
   ncdf_attput, cdfid, this_varid, 'units', 'mm_Dm'
   ncdf_attput, cdfid, this_varid, '_FillValue', FLOAT_RANGE_EDGE

   this_varid = ncdf_vardef(cdfid, 'precipTotPSDparamLow_'+swath[iswa], $
                            [nPSDlo_dimid, fpdimid[iswa],eldimid])
   ncdf_attput, cdfid, this_varid, 'long_name', $
               '2B-DPRGMI precipTotPSDparamLow for '+swath[iswa]+' swath'
   ncdf_attput, cdfid, this_varid, 'units', 'Nw_mu'
   ncdf_attput, cdfid, this_varid, '_FillValue', FLOAT_RANGE_EDGE

   this_varid = ncdf_vardef(cdfid, 'precipTotRate_'+swath[iswa], [fpdimid[iswa],eldimid])
   ncdf_attput, cdfid, this_varid, 'long_name', $
               '2B-DPRGMI precipTotRate for '+swath[iswa]+' swath'
   ncdf_attput, cdfid, this_varid, 'units', 'mm/h'
   ncdf_attput, cdfid, this_varid, '_FillValue', FLOAT_RANGE_EDGE

   this_varid = ncdf_vardef(cdfid, 'precipTotWaterCont_'+swath[iswa], [fpdimid[iswa],eldimid])
   ncdf_attput, cdfid, this_varid, 'long_name', $
                '2B-DPRGMI precipTotWaterCont for '+swath[iswa]+' swath'
   ncdf_attput, cdfid, this_varid, 'units', 'g/m^3'
   ncdf_attput, cdfid, this_varid, '_FillValue', FLOAT_RANGE_EDGE

;TAB 10/26/20 added new variables, need to check units
   this_varid = ncdf_vardef(cdfid, 'precipTotWaterContSigma_'+swath[iswa], [fpdimid[iswa],eldimid])
   ncdf_attput, cdfid, this_varid, 'long_name', $
                '2B-DPRGMI precipTotWaterContSigma for '+swath[iswa]+' swath'
   ncdf_attput, cdfid, this_varid, 'units', 'g/m^3'
   ncdf_attput, cdfid, this_varid, '_FillValue', FLOAT_RANGE_EDGE

   this_varid = ncdf_vardef(cdfid, 'cloudLiqWaterCont_'+swath[iswa], [fpdimid[iswa],eldimid])
   ncdf_attput, cdfid, this_varid, 'long_name', $
                '2B-DPRGMI cloudLiqWaterCont for '+swath[iswa]+' swath'
   ncdf_attput, cdfid, this_varid, 'units', 'g/m^3'
   ncdf_attput, cdfid, this_varid, '_FillValue', FLOAT_RANGE_EDGE

   this_varid = ncdf_vardef(cdfid, 'cloudIceWaterCont_'+swath[iswa], [fpdimid[iswa],eldimid])
   ncdf_attput, cdfid, this_varid, 'long_name', $
                '2B-DPRGMI cloudIceWaterCont for '+swath[iswa]+' swath'
   ncdf_attput, cdfid, this_varid, 'units', 'g/m^3'
   ncdf_attput, cdfid, this_varid, '_FillValue', FLOAT_RANGE_EDGE

   this_varid = ncdf_vardef(cdfid, 'tbSim_19v_'+swath[iswa], [fpdimid[iswa]])
   ncdf_attput, cdfid, this_varid, 'long_name', $
                '2B-DPRGMI simulatedBrightTemp 19v for '+swath[iswa]+' swath'
   ncdf_attput, cdfid, this_varid, 'units', 'K'
   ncdf_attput, cdfid, this_varid, '_FillValue', FLOAT_RANGE_EDGE

   this_varid = ncdf_vardef(cdfid, 'tbSim_37v_'+swath[iswa], [fpdimid[iswa]])
   ncdf_attput, cdfid, this_varid, 'long_name', $
                '2B-DPRGMI simulatedBrightTemp 37v for '+swath[iswa]+' swath'
   ncdf_attput, cdfid, this_varid, 'units', 'K'
   ncdf_attput, cdfid, this_varid, '_FillValue', FLOAT_RANGE_EDGE

   this_varid = ncdf_vardef(cdfid, 'tbSim_89v_'+swath[iswa], [fpdimid[iswa]])
   ncdf_attput, cdfid, this_varid, 'long_name', $
                '2B-DPRGMI simulatedBrightTemp 89v for '+swath[iswa]+' swath'
   ncdf_attput, cdfid, this_varid, 'units', 'K'
   ncdf_attput, cdfid, this_varid, '_FillValue', FLOAT_RANGE_EDGE

   this_varid = ncdf_vardef(cdfid, 'tbSim_183_3v_'+swath[iswa], [fpdimid[iswa]])
   ncdf_attput, cdfid, this_varid, 'long_name', $
                '2B-DPRGMI simulatedBrightTemp 183_3v for '+swath[iswa]+' swath'
   ncdf_attput, cdfid, this_varid, 'units', 'K'
   ncdf_attput, cdfid, this_varid, '_FillValue', FLOAT_RANGE_EDGE


   rainrejvarid = ncdf_vardef(cdfid, 'n_precipTotPSDparamHigh_rejected_'+swath[iswa], $
                              [fpdimid[iswa],eldimid], /short)
   ncdf_attput, cdfid, rainrejvarid, 'long_name', $
                'number of bins below rain_min in precipTotPSDparamHigh average for ' $
                +swath[iswa]+' swath'
   ncdf_attput, cdfid, rainrejvarid, '_FillValue', INT_RANGE_EDGE

   rainrejvarid = ncdf_vardef(cdfid, 'n_precipTotPSDparamLow_rejected_'+swath[iswa], $
                             [nPSDlo_dimid, fpdimid[iswa],eldimid], /short)
   ncdf_attput, cdfid, rainrejvarid, 'long_name', $
                'number of bins below rain_min in precipTotPSDparamLow average for ' $
                +swath[iswa]+' swath'
   ncdf_attput, cdfid, rainrejvarid, '_FillValue', INT_RANGE_EDGE

   rainrejvarid = ncdf_vardef(cdfid, 'n_precipTotRate_rejected_'+swath[iswa], $
                              [fpdimid[iswa],eldimid], /short)
   ncdf_attput, cdfid, rainrejvarid, 'long_name', $
                'number of bins below rain_min in precipTotRate average for '+swath[iswa]+' swath'
   ncdf_attput, cdfid, rainrejvarid, '_FillValue', INT_RANGE_EDGE

   rainrejvarid = ncdf_vardef(cdfid, 'n_precipTotWaterCont_rejected_'+swath[iswa], $
                              [fpdimid[iswa],eldimid], /short)
   ncdf_attput, cdfid, rainrejvarid, 'long_name', $
                'number of bins below rain_min in precipTotWaterCont average for ' $
                +swath[iswa]+' swath'
   ncdf_attput, cdfid, rainrejvarid, '_FillValue', INT_RANGE_EDGE

   rainrejvarid = ncdf_vardef(cdfid, 'n_precipTotWaterContSigma_rejected_'+swath[iswa], $
                              [fpdimid[iswa],eldimid], /short)
   ncdf_attput, cdfid, rainrejvarid, 'long_name', $
                'number of bins below rain_min in precipTotWaterContSigma average for ' $
                +swath[iswa]+' swath'
   ncdf_attput, cdfid, rainrejvarid, '_FillValue', INT_RANGE_EDGE

   rainrejvarid = ncdf_vardef(cdfid, 'n_cloudLiqWaterCont_rejected_'+swath[iswa], $
                              [fpdimid[iswa],eldimid], /short)
   ncdf_attput, cdfid, rainrejvarid, 'long_name', $
                'number of bins below rain_min in cloudLiqWaterCont average for ' $
                +swath[iswa]+' swath'
   ncdf_attput, cdfid, rainrejvarid, '_FillValue', INT_RANGE_EDGE

   rainrejvarid = ncdf_vardef(cdfid, 'n_cloudIceWaterCont_rejected_'+swath[iswa], $
                              [fpdimid[iswa],eldimid], /short)
   ncdf_attput, cdfid, rainrejvarid, 'long_name', $
                'number of bins below rain_min in cloudIceWaterCont average for ' $
                +swath[iswa]+' swath'
   ncdf_attput, cdfid, rainrejvarid, '_FillValue', INT_RANGE_EDGE

   ; DPRGMI single-level fields of same no. of dimensions for each swath

   this_varid = ncdf_vardef(cdfid, 'precipitationType_'+swath[iswa], [fpdimid[iswa]], /long)
   ncdf_attput, cdfid, this_varid, 'long_name', $
                '2B-DPRGMI precipitationType for '+swath[iswa]+' swath'
   ncdf_attput, cdfid, this_varid, 'units', 'Categorical'
   ncdf_attput, cdfid, this_varid, '_FillValue', LONG(INT_RANGE_EDGE)

   this_varid = ncdf_vardef(cdfid, 'surfPrecipTotRate_'+swath[iswa], [fpdimid[iswa]])
   ncdf_attput, cdfid, this_varid, 'long_name', $
               '2B-DPRGMI surfPrecipTotRate for '+swath[iswa]+' swath'
   ncdf_attput, cdfid, this_varid, 'units', 'mm/h'
   ncdf_attput, cdfid, this_varid, '_FillValue', FLOAT_RANGE_EDGE

   this_varid = ncdf_vardef(cdfid, 'surfaceElevation_'+swath[iswa], [fpdimid[iswa]])
   ncdf_attput, cdfid, this_varid, 'long_name', $
               '2B-DPRGMI surfaceElevation for '+swath[iswa]+' swath'
   ncdf_attput, cdfid, this_varid, 'units', 'm'
   ncdf_attput, cdfid, this_varid, '_FillValue', FLOAT_RANGE_EDGE

   this_varid = ncdf_vardef(cdfid, 'zeroDegAltitude_'+swath[iswa], [fpdimid[iswa]])
   ncdf_attput, cdfid, this_varid, 'long_name', $
               '2B-DPRGMI zeroDegAltitude for '+swath[iswa]+' swath'
   ncdf_attput, cdfid, this_varid, 'units', 'm'
   ncdf_attput, cdfid, this_varid, '_FillValue', FLOAT_RANGE_EDGE

   this_varid = ncdf_vardef(cdfid, 'zeroDegBin_'+swath[iswa], [fpdimid[iswa]], /short)
   ncdf_attput, cdfid, this_varid, 'long_name', $
               '2B-DPRGMI zeroDegBin for '+swath[iswa]+' swath'
   ncdf_attput, cdfid, this_varid, 'units', 'N/A'
   ncdf_attput, cdfid, this_varid, '_FillValue', INT_RANGE_EDGE

   this_varid = ncdf_vardef(cdfid, 'surfaceType_'+swath[iswa], [fpdimid[iswa]], /long)
   ncdf_attput, cdfid, this_varid, 'long_name', $
               '2B-DPRGMI surfaceType for '+swath[iswa]+' swath'
   ncdf_attput, cdfid, this_varid, 'units', 'Categorical'
   ncdf_attput, cdfid, this_varid, '_FillValue', LONG(INT_RANGE_EDGE)

   this_varid = ncdf_vardef(cdfid, 'phaseBinNodes_'+swath[iswa], [nPhsBnN_dimid, fpdimid[iswa]], /short)
   ncdf_attput, cdfid, this_varid, 'long_name', $
            '2B-DPRGMI phaseBinNodes for '+swath[iswa]+' swath'
   ncdf_attput, cdfid, this_varid, 'units', 'None'
   ncdf_attput, cdfid, this_varid, '_FillValue', INT_RANGE_EDGE

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

   ; DPRGMI fields where no. of dimensions varies for each swath

   IF ( swath[iswa] EQ 'MS' ) THEN BEGIN
     ; include the extra dimension "nKuKa" for MS swath

      this_varid = ncdf_vardef(cdfid, 'ellipsoidBinOffset_'+swath[iswa], $
                               [nKuKa_dimid, fpdimid[iswa]])
      ncdf_attput, cdfid, this_varid, 'long_name', $
                  '2B-DPRGMI Ku and Ka ellipsoidBinOffset for '+swath[iswa]+' swath'
      ncdf_attput, cdfid, this_varid, 'units', 'm'
      ncdf_attput, cdfid, this_varid, '_FillValue', FLOAT_RANGE_EDGE

      this_varid = ncdf_vardef(cdfid, 'lowestClutterFreeBin_'+swath[iswa], $
                               [nKuKa_dimid, fpdimid[iswa]], /short)
      ncdf_attput, cdfid, this_varid, 'long_name', $
                  '2B-DPRGMI Ku and Ka lowestClutterFreeBin for '+swath[iswa]+' swath'
      ncdf_attput, cdfid, this_varid, 'units', 'None'
      ncdf_attput, cdfid, this_varid, '_FillValue', INT_RANGE_EDGE

      this_varid = ncdf_vardef(cdfid, 'clutterStatus_'+swath[iswa], $
                               [nKuKa_dimid, fpdimid[iswa], eldimid], /short)
      ncdf_attput, cdfid, this_varid, 'long_name', $
                  'Matchup Ku and Ka clutterStatus for '+swath[iswa]+' swath'
      ncdf_attput, cdfid, this_varid, 'units', 'None'
      ncdf_attput, cdfid, this_varid, '_FillValue', INT_RANGE_EDGE

      this_varid = ncdf_vardef(cdfid, 'precipitationFlag_'+swath[iswa], $
                               [nKuKa_dimid, fpdimid[iswa]], /long)
      ncdf_attput, cdfid, this_varid, 'long_name', $
                  '2B-DPRGMI Ku and Ka precipitationFlag for '+swath[iswa]+' swath'
      ncdf_attput, cdfid, this_varid, 'units', 'Categorical'
      ncdf_attput, cdfid, this_varid, '_FillValue', LONG(INT_RANGE_EDGE)

      this_varid = ncdf_vardef(cdfid, 'surfaceRangeBin_'+swath[iswa], $
                               [nKuKa_dimid, fpdimid[iswa]], /short)
      ncdf_attput, cdfid, this_varid, 'long_name', $
                  '2B-DPRGMI Ku and Ka surfaceRangeBin for '+swath[iswa]+' swath'
      ncdf_attput, cdfid, this_varid, 'units', 'None'
      ncdf_attput, cdfid, this_varid, '_FillValue', INT_RANGE_EDGE

      this_varid = ncdf_vardef(cdfid, 'correctedReflectFactor_'+swath[iswa], $
                               [nKuKa_dimid, fpdimid[iswa],eldimid])
      ncdf_attput, cdfid, this_varid, 'long_name', $
                  '2B-DPRGMI Ku and Ka Corrected Reflectivity Factor for '+swath[iswa]+' swath'
      ncdf_attput, cdfid, this_varid, 'units', 'dBZ'
      ncdf_attput, cdfid, this_varid, '_FillValue', FLOAT_RANGE_EDGE

      this_varid = ncdf_vardef(cdfid, 'pia_'+swath[iswa], [nKuKa_dimid, fpdimid[iswa]])
      ncdf_attput, cdfid, this_varid, 'long_name', $
                  '2B-DPRGMI Ku and Ka Path Integrated Attenuation for '+swath[iswa]+' swath'
      ncdf_attput, cdfid, this_varid, 'units', 'dB'
      ncdf_attput, cdfid, this_varid, '_FillValue', FLOAT_RANGE_EDGE

      this_varid = ncdf_vardef(cdfid, 'stormTopAltitude_'+swath[iswa], $
                               [nKuKa_dimid, fpdimid[iswa]])
      ncdf_attput, cdfid, this_varid, 'long_name', $
                  '2B-DPRGMI Ku and Ka stormTopAltitude for '+swath[iswa]+' swath'
      ncdf_attput, cdfid, this_varid, 'units', 'm'
      ncdf_attput, cdfid, this_varid, '_FillValue', FLOAT_RANGE_EDGE

      corZrejvarid = ncdf_vardef(cdfid, 'n_correctedReflectFactor_rejected_'+swath[iswa], $
                                 [nKuKa_dimid, fpdimid[iswa],eldimid], /short)
      ncdf_attput, cdfid, corZrejvarid, 'long_name', $
                'numbers of Ku and Ka bins below DPR_dBZ_min in '+ $
                'correctedReflectFactor average for '+swath[iswa]+' swath'
      ncdf_attput, cdfid, corZrejvarid, '_FillValue', INT_RANGE_EDGE

      prexpvarid = ncdf_vardef(cdfid, 'n_dpr_expected_'+swath[iswa], $
                               [nKuKa_dimid, fpdimid[iswa],eldimid], /short)
      ncdf_attput, cdfid, prexpvarid, 'long_name', $
                   'numbers of expected Ku and Ka bins in DPR averages for '+ $
                   swath[iswa]+' swath'
      ncdf_attput, cdfid, prexpvarid, '_FillValue', INT_RANGE_EDGE

   ENDIF ELSE BEGIN
     ; define same variables for NS, but exclude the extra dimension "nKuKa"

      this_varid = ncdf_vardef(cdfid, 'ellipsoidBinOffset_'+swath[iswa], $
                               [fpdimid[iswa]])
      ncdf_attput, cdfid, this_varid, 'long_name', $
                  '2B-DPRGMI ellipsoidBinOffset for '+swath[iswa]+' swath'
      ncdf_attput, cdfid, this_varid, 'units', 'm'
      ncdf_attput, cdfid, this_varid, '_FillValue', FLOAT_RANGE_EDGE

      this_varid = ncdf_vardef(cdfid, 'lowestClutterFreeBin_'+swath[iswa], $
                               [fpdimid[iswa]], /short)
      ncdf_attput, cdfid, this_varid, 'long_name', $
                  '2B-DPRGMI lowestClutterFreeBin for '+swath[iswa]+' swath'
      ncdf_attput, cdfid, this_varid, 'units', 'None'
      ncdf_attput, cdfid, this_varid, '_FillValue', INT_RANGE_EDGE

      this_varid = ncdf_vardef(cdfid, 'clutterStatus_'+swath[iswa], $
                               [fpdimid[iswa], eldimid], /short)
      ncdf_attput, cdfid, this_varid, 'long_name', $
                  'Matchup clutterStatus for '+swath[iswa]+' swath'
      ncdf_attput, cdfid, this_varid, 'units', 'None'
      ncdf_attput, cdfid, this_varid, '_FillValue', INT_RANGE_EDGE

      this_varid = ncdf_vardef(cdfid, 'precipitationFlag_'+swath[iswa], $
                               [fpdimid[iswa]], /long)
      ncdf_attput, cdfid, this_varid, 'long_name', $
                  '2B-DPRGMI precipitationFlag for '+swath[iswa]+' swath'
      ncdf_attput, cdfid, this_varid, 'units', 'Categorical'
      ncdf_attput, cdfid, this_varid, '_FillValue', LONG(INT_RANGE_EDGE)

      this_varid = ncdf_vardef(cdfid, 'surfaceRangeBin_'+swath[iswa], $
                               [fpdimid[iswa]], /short)
      ncdf_attput, cdfid, this_varid, 'long_name', $
                  '2B-DPRGMI surfaceRangeBin for '+swath[iswa]+' swath'
      ncdf_attput, cdfid, this_varid, 'units', 'None'
      ncdf_attput, cdfid, this_varid, '_FillValue', INT_RANGE_EDGE

      this_varid = ncdf_vardef(cdfid, 'correctedReflectFactor_'+swath[iswa], $
                               [fpdimid[iswa],eldimid])
      ncdf_attput, cdfid, this_varid, 'long_name', $
                  '2B-DPRGMI Corrected Reflectivity Factor for '+swath[iswa]+' swath'
      ncdf_attput, cdfid, this_varid, 'units', 'dBZ'
      ncdf_attput, cdfid, this_varid, '_FillValue', FLOAT_RANGE_EDGE

      this_varid = ncdf_vardef(cdfid, 'pia_'+swath[iswa], [fpdimid[iswa]])
      ncdf_attput, cdfid, this_varid, 'long_name', $
                  '2B-DPRGMI Path Integrated Attenuation for '+swath[iswa]+' swath'
      ncdf_attput, cdfid, this_varid, 'units', 'dB'
      ncdf_attput, cdfid, this_varid, '_FillValue', FLOAT_RANGE_EDGE

      this_varid = ncdf_vardef(cdfid, 'stormTopAltitude_'+swath[iswa], [fpdimid[iswa]])
      ncdf_attput, cdfid, this_varid, 'long_name', $
                  '2B-DPRGMI stormTopAltitude for '+swath[iswa]+' swath'
      ncdf_attput, cdfid, this_varid, 'units', 'm'
      ncdf_attput, cdfid, this_varid, '_FillValue', FLOAT_RANGE_EDGE

      corZrejvarid = ncdf_vardef(cdfid, 'n_correctedReflectFactor_rejected_'+swath[iswa], $
                                 [fpdimid[iswa],eldimid], /short)
      ncdf_attput, cdfid, corZrejvarid, 'long_name', $
                   'number of bins below DPR_dBZ_min in correctedReflectFactor average'
      ncdf_attput, cdfid, corZrejvarid, '_FillValue', INT_RANGE_EDGE

      prexpvarid = ncdf_vardef(cdfid, 'n_dpr_expected_'+swath[iswa], $
                               [fpdimid[iswa],eldimid], /short)
      ncdf_attput, cdfid, prexpvarid, 'long_name', $
                   'number of expected bins in DPR averages for '+swath[iswa]+' swath'
      ncdf_attput, cdfid, prexpvarid, '_FillValue', INT_RANGE_EDGE
   ENDELSE
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
IF numpts_MS GT 0 THEN NCDF_VARPUT, cdfid, 'have_swath_MS', DATA_PRESENT

ncdf_close, cdfid

GOTO, normalExit

versionOnly:
return, "NoGeoMatchFile"

normalExit:
return, geo_match_nc_file

end
