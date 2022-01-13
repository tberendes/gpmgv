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
; gen_gprof_geo_match_netcdf_v7.pro    Bob Morris, GPM GV (SAIC)    March 2014
;
; DESCRIPTION:
; Using the "special values" and path parameters in the 'include' files
; pr_params.inc, tmi_params.inc,  grid_def.inc, and environs.inc, and supplied
; parameters for the output netcdf file name, the number of XMI footprints
; in the matchup, the array of elevation angles in the ground radar volume scan,
; and global variables for the UF data field used for GR reflectivity and the
; XMI product version, creates an empty XMI/GV matchup netCDF file in directory
; OUTDIR.  The designation "XMI" stands for any satellite Microwave Imager used
; as input to the 2A-GPROF algorithm.
;
; The input file name supplied is expected to be a complete file basename and
; to contain fields for YYMMDD, the satellite orbit number, and the ID of the
; ground radar site, as well as the '.nc' file extension.  No checking of the
; file name pre-existence, uniqueness, or conformance is performed in this
; module.
;
; HISTORY:
; 03/17/2014 by Bob Morris, GPM GV (SAIC)
;  - Created from gen_tmi_geo_match_netcdf.pro and gen_geo_match_netcdf.pro,
;    with the following notable differences:
;      - This function requires the siteID string as a mandatory parameter, 
;        since we allow other than 4-character site IDs now.
;      - This function expects a string value for PPS_vers rather than a short
;        integer, e.g., 'V07' rather than 7.  If passed a numerical value, it
;        is converted to a string before writing out as a global variable
; 11/06/14 by Bob Morris, GPM GV (SAIC)
;  - Added processing of GR RC and RP rainrate fields for version 1.1 file.
; 11/13/15 by Bob Morris, GPM GV (SAIC)
;  - Added GR_blockage variables and their presence flags for version 1.11 file.
; 06/30/16 by Bob Morris, GPM GV (SAIC)
;  - Added tbb_channels parameter and related Tbb variables and quality flags
;    from 1C-R-XCAL file for version 1.2 file.
;  - Extracting 1C-R-XCAL filename from the gprofgrfiles array and writing it to
;    the 1CRXCAL global variable when its value is present.
;
;-------------------------------------------------------------------------------
;-

FUNCTION gen_gprof_geo_match_netcdf_v7, geo_match_nc_file, numpts, elev_angles, $
                                     gv_UF_field, PPS_vers, siteID, $
                                     gprofgrfiles, tbb_channels, $
                                     GEO_MATCH_VERS=geo_match_vers

GEO_MATCH_NC_FILE_VERSION=2.0    ;ignore "Include" file definition now

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

; global variables -- THE FIRST GLOBAL VARIABLE MUST BE 'PPS_Version'
; -- if given a number, convert it to a string
s = SIZE(PPS_vers, /TYPE)
SWITCH s OF
     7 : break   ; we were passed a STRING, leave it be
     1 :
     2 :
     3 :
    12 :
    13 :
    14 :
    15 : begin
           ; handle the integer types
            PPS_vers = STRING(PPS_vers, FORMAT='(I0)')
            break
         end
     4 :
     5 : begin
           ; handle the floating point types
            PPS_vers = STRING(PPS_vers, FORMAT='(F0.1)')
            break
         end
  ELSE : message, "Illegal type for PPS_vers parameter."
ENDSWITCH
    
ncdf_attput, cdfid, 'PPS_Version', PPS_vers, /global

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


; extract the input file names (if given) to be written out as global attributes
; or define placeholder values to write
IF ( N_PARAMS() EQ 7 ) THEN BEGIN

   idxfiles = lonarr( N_ELEMENTS(gprofgrfiles) )
   idx1C = WHERE(STRPOS(gprofgrfiles,'XCAL') GE 0, count1C)
   if count1C EQ 1 THEN BEGIN
      origFile1CName = STRJOIN(STRTRIM(gprofgrfiles[idx1C],2))
      idxfiles[idx1C] = 1
   endif ELSE origFile1CName='no_1CRXCAL_file'

   idxfiles = lonarr( N_ELEMENTS(gprofgrfiles) )
   idx2A = WHERE(STRPOS(gprofgrfiles,'GPROF') GE 0, count2A)
   if count2A EQ 1 THEN BEGIN
      origFile2AName = STRJOIN(STRTRIM(gprofgrfiles[idx2A],2))
      idxfiles[idx2A] = 1
   endif ELSE origFile2AName='no_2AGPROF_file'

  ; this should never happen, but for completeness...
   idxgr = WHERE(idxfiles EQ 0, countgr)
   if countgr EQ 1 THEN BEGIN
      origGRFileName = STRJOIN(STRTRIM(gprofgrfiles[idxgr],2))
      idxfiles[idxgr] = 1
   endif ELSE origGRFileName='no_1CUF_file'

ENDIF ELSE BEGIN
   origFile1CName='Unspecified'
   origFile2AName='Unspecified'
   origGRFileName='Unspecified'
ENDELSE

ncdf_attput, cdfid, '1CRXCAL_file', origFile1CName, /global
ncdf_attput, cdfid, '2AGPROF_file', origFile2AName, /global
ncdf_attput, cdfid, 'GR_file', origGRFileName, /global


; field dimensions

fpdimid = ncdf_dimdef(cdfid, 'fpdim', numpts)  ; # XMI footprints within range
eldimid = ncdf_dimdef(cdfid, 'elevationAngle', N_ELEMENTS(elev_angles))
xydimid = ncdf_dimdef(cdfid, 'xydim', 4)       ; 4 corners of a XMI footprint
hidimid = ncdf_dimdef(cdfid, 'hidim', 15) ; for Hydromet ID Categories
n_Tbb = N_ELEMENTS(tbb_channels)
IF n_Tbb GT 0 THEN BEGIN
   Tbdimid = ncdf_dimdef(cdfid, 'Tbdim', n_Tbb)  ; number of Tbb channel names
  ; maximum length of a Tbb channel name
   Tblenid = ncdf_dimdef( cdfid, 'Tblen', Max(STRLEN(tbb_channels)) )
   tcfpdimid = fpdimid
   Tc_channel_names = tbb_channels
ENDIF ELSE BEGIN
  ; define one missing Tbb channel name and one Tbb footprint
   Tbdimid = ncdf_dimdef(cdfid, 'Tbdim', 1)
   Tblenid = ncdf_dimdef( cdfid, 'Tblen', STRLEN('No_Tbb_data') )
   tcfpdimid = 1
   Tc_channel_names = 'No_Tbb_data'
ENDELSE

; define the channel names array variable
TbNamesid = ncdf_vardef(cdfid, 'Tc_channel_names', [Tblenid, Tbdimid], /CHAR)
ncdf_attput, cdfid, TbNamesid, 'long_name', 'Tc channel frequency/polarization names'

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

rainthreshid = ncdf_vardef(cdfid, 'gprof_rain_min')
ncdf_attput, cdfid, rainthreshid, 'long_name', $
             'minimum XMI rainrate required'
ncdf_attput, cdfid, rainthreshid, '_FillValue', FLOAT_RANGE_EDGE
ncdf_attput, cdfid, rainthreshid, 'units', 'mm/h'

rngthreshid = ncdf_vardef(cdfid, 'radiusOfInfluence')
ncdf_attput, cdfid, rngthreshid, 'long_name', $
             'Radius of influence for distance weighting of GR bins'
ncdf_attput, cdfid, rngthreshid, '_FillValue', FLOAT_RANGE_EDGE
ncdf_attput, cdfid, rngthreshid, 'units', 'km'

; Data existence (non-fill) flags for science fields

havedbzgvvarid = ncdf_vardef(cdfid, 'have_GR_Z_slantPath', /short)
ncdf_attput, cdfid, havedbzgvvarid, 'long_name', $
             'data exists flag for GR_Z_slantPath'
ncdf_attput, cdfid, havedbzgvvarid, '_FillValue', NO_DATA_PRESENT

havegvrrvarid = ncdf_vardef(cdfid, 'have_GR_RC_rainrate_slantPath', /short)
ncdf_attput, cdfid, havegvrrvarid, 'long_name', $
             'data exists flag for GR_RC_rainrate_slantPath'
ncdf_attput, cdfid, havegvrrvarid, '_FillValue', NO_DATA_PRESENT

havegvrrvarid = ncdf_vardef(cdfid, 'have_GR_RP_rainrate_slantPath', /short)
ncdf_attput, cdfid, havegvrrvarid, 'long_name', $
             'data exists flag for GR_RP_rainrate_slantPath'
ncdf_attput, cdfid, havegvrrvarid, '_FillValue', NO_DATA_PRESENT

havegvrrvarid = ncdf_vardef(cdfid, 'have_GR_RR_rainrate_slantPath', /short)
ncdf_attput, cdfid, havegvrrvarid, 'long_name', $
             'data exists flag for GR_RR_rainrate_slantPath'
ncdf_attput, cdfid, havegvrrvarid, '_FillValue', NO_DATA_PRESENT

havegvZDRvarid = ncdf_vardef(cdfid, 'have_GR_Zdr_slantPath', /short)
ncdf_attput, cdfid, havegvZDRvarid, 'long_name', $
             'data exists flag for GR_Zdr_slantPath'
ncdf_attput, cdfid, havegvZDRvarid, '_FillValue', NO_DATA_PRESENT

havegvKdpvarid = ncdf_vardef(cdfid, 'have_GR_Kdp_slantPath', /short)
ncdf_attput, cdfid, havegvKdpvarid, 'long_name', $
             'data exists flag for GR_Kdp_slantPath'
ncdf_attput, cdfid, havegvKdpvarid, '_FillValue', NO_DATA_PRESENT

havegvRHOHVvarid = ncdf_vardef(cdfid, 'have_GR_RHOhv_slantPath', /short)
ncdf_attput, cdfid, havegvRHOHVvarid, 'long_name', $
             'data exists flag for GR_RHOhv_slantPath'
ncdf_attput, cdfid, havegvRHOHVvarid, '_FillValue', NO_DATA_PRESENT

havegvHIDvarid = ncdf_vardef(cdfid, 'have_GR_HID_slantPath', /short)
ncdf_attput, cdfid, havegvHIDvarid, 'long_name', $
             'data exists flag for GR_HID_slantPath'
ncdf_attput, cdfid, havegvHIDvarid, '_FillValue', NO_DATA_PRESENT

havegvDzerovarid = ncdf_vardef(cdfid, 'have_GR_Dzero_slantPath', /short)
ncdf_attput, cdfid, havegvDzerovarid, 'long_name', $
             'data exists flag for GR_Dzero_slantPath'
ncdf_attput, cdfid, havegvDzerovarid, '_FillValue', NO_DATA_PRESENT

havegvNWvarid = ncdf_vardef(cdfid, 'have_GR_Nw_slantPath', /short)
ncdf_attput, cdfid, havegvNWvarid, 'long_name', $
             'data exists flag for GR_Nw_slantPath'
ncdf_attput, cdfid, havegvNWvarid, '_FillValue', NO_DATA_PRESENT

haveBLKvarid = ncdf_vardef(cdfid, 'have_GR_blockage_slantPath', /short)
ncdf_attput, cdfid, haveBLKvarid, 'long_name', $
             'data exists flag for GR_blockage_slantPath'
ncdf_attput, cdfid, haveBLKvarid, '_FillValue', NO_DATA_PRESENT

havedbzgvvarid_vpr = ncdf_vardef(cdfid, 'have_GR_Z_VPR', /short)
ncdf_attput, cdfid, havedbzgvvarid_vpr, 'long_name', $
             'data exists flag for GR_Z_VPR'
ncdf_attput, cdfid, havedbzgvvarid_vpr, '_FillValue', NO_DATA_PRESENT

havegvrrvarid_vpr = ncdf_vardef(cdfid, 'have_GR_RC_rainrate_VPR', /short)
ncdf_attput, cdfid, havegvrrvarid_vpr, 'long_name', $
             'data exists flag for GR_RC_rainrate_VPR'
ncdf_attput, cdfid, havegvrrvarid_vpr, '_FillValue', NO_DATA_PRESENT

havegvrrvarid_vpr = ncdf_vardef(cdfid, 'have_GR_RP_rainrate_VPR', /short)
ncdf_attput, cdfid, havegvrrvarid_vpr, 'long_name', $
             'data exists flag for GR_RP_rainrate_VPR'
ncdf_attput, cdfid, havegvrrvarid_vpr, '_FillValue', NO_DATA_PRESENT

havegvrrvarid_vpr = ncdf_vardef(cdfid, 'have_GR_RR_rainrate_VPR', /short)
ncdf_attput, cdfid, havegvrrvarid_vpr, 'long_name', $
             'data exists flag for GR_RR_rainrate_VPR'
ncdf_attput, cdfid, havegvrrvarid_vpr, '_FillValue', NO_DATA_PRESENT

havegvZDRvarid_vpr = ncdf_vardef(cdfid, 'have_GR_Zdr_VPR', /short)
ncdf_attput, cdfid, havegvZDRvarid_vpr, 'long_name', $
             'data exists flag for GR_Zdr_VPR'
ncdf_attput, cdfid, havegvZDRvarid_vpr, '_FillValue', NO_DATA_PRESENT

havegvKdpvarid_vpr = ncdf_vardef(cdfid, 'have_GR_Kdp_VPR', /short)
ncdf_attput, cdfid, havegvKdpvarid_vpr, 'long_name', $
             'data exists flag for GR_Kdp_VPR'
ncdf_attput, cdfid, havegvKdpvarid_vpr, '_FillValue', NO_DATA_PRESENT

havegvRHOHVvarid_vpr = ncdf_vardef(cdfid, 'have_GR_RHOhv_VPR', /short)
ncdf_attput, cdfid, havegvRHOHVvarid_vpr, 'long_name', $
             'data exists flag for GR_RHOhv_VPR'
ncdf_attput, cdfid, havegvRHOHVvarid_vpr, '_FillValue', NO_DATA_PRESENT

havegvHIDvarid_vpr = ncdf_vardef(cdfid, 'have_GR_HID_VPR', /short)
ncdf_attput, cdfid, havegvHIDvarid_vpr, 'long_name', $
             'data exists flag for GR_HID_VPR'
ncdf_attput, cdfid, havegvHIDvarid_vpr, '_FillValue', NO_DATA_PRESENT

havegvDzerovarid_vpr = ncdf_vardef(cdfid, 'have_GR_Dzero_VPR', /short)
ncdf_attput, cdfid, havegvDzerovarid_vpr, 'long_name', $
             'data exists flag for GR_Dzero_VPR'
ncdf_attput, cdfid, havegvDzerovarid_vpr, '_FillValue', NO_DATA_PRESENT

havegvNWvarid_vpr = ncdf_vardef(cdfid, 'have_GR_Nw_VPR', /short)
ncdf_attput, cdfid, havegvNWvarid_vpr, 'long_name', $
             'data exists flag for GR_Nw_VPR'
ncdf_attput, cdfid, havegvNWvarid_vpr, '_FillValue', NO_DATA_PRESENT

haveBLKvarid_vpr = ncdf_vardef(cdfid, 'have_GR_blockage_VPR', /short)
ncdf_attput, cdfid, haveBLKvarid_vpr, 'long_name', $
             'data exists flag for GR_blockage_VPR'
ncdf_attput, cdfid, haveBLKvarid_vpr, '_FillValue', NO_DATA_PRESENT

havesurfaceTypevarid = ncdf_vardef(cdfid, 'have_surfaceTypeIndex', /short)
ncdf_attput, cdfid, havesurfaceTypevarid, 'long_name', $
             'data exists flag for surfaceTypeIndex'
ncdf_attput, cdfid, havesurfaceTypevarid, '_FillValue', NO_DATA_PRESENT

havesfrainvarid = ncdf_vardef(cdfid, 'have_surfacePrecipitation', /short)
ncdf_attput, cdfid, havesfrainvarid, 'long_name', $
             'data exists flag for surfacePrecipitation'
ncdf_attput, cdfid, havesfrainvarid, '_FillValue', NO_DATA_PRESENT

havepixelStatusvarid = ncdf_vardef(cdfid, 'have_pixelStatus', /short)
ncdf_attput, cdfid, havepixelStatusvarid, 'long_name', $
             'data exists flag for pixelStatus'
ncdf_attput, cdfid, havepixelStatusvarid, '_FillValue', NO_DATA_PRESENT

havePoPvarid = ncdf_vardef(cdfid, 'have_PoP', /short)
ncdf_attput, cdfid, havePoPvarid, 'long_name', $
             'data exists flag for PoP'
ncdf_attput, cdfid, havePoPvarid, '_FillValue', NO_DATA_PRESENT

havefreezingHeightvarid = ncdf_vardef(cdfid, 'have_freezingHeight', /short)
ncdf_attput, cdfid, havefreezingHeightvarid, 'long_name', $
             'data exists flag for freezingHeight'
ncdf_attput, cdfid, havefreezingHeightvarid, '_FillValue', NO_DATA_PRESENT

haveTcvarid = ncdf_vardef(cdfid, 'have_Tc', /short)
ncdf_attput, cdfid, haveTcvarid, 'long_name', $
             'data exists flag for Tc'
ncdf_attput, cdfid, haveTcvarid, '_FillValue', NO_DATA_PRESENT

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
ncdf_attput, cdfid, topvarid_vpr, 'long_name', $
   'data sample top height AGL along local vertical'
ncdf_attput, cdfid, topvarid_vpr, 'units', 'km'
ncdf_attput, cdfid, topvarid_vpr, '_FillValue', FLOAT_RANGE_EDGE

botmvarid_vpr = ncdf_vardef(cdfid, 'bottomHeight_vpr', [fpdimid,eldimid])
ncdf_attput, cdfid, botmvarid_vpr, 'long_name', $
   'data sample bottom height AGL along local vertical'
ncdf_attput, cdfid, botmvarid_vpr, 'units', 'km'
ncdf_attput, cdfid, botmvarid_vpr, '_FillValue', FLOAT_RANGE_EDGE

dbzgvvarid = ncdf_vardef(cdfid, 'GR_Z_slantPath', [fpdimid,eldimid])
ncdf_attput, cdfid, dbzgvvarid, 'long_name', 'GV radar QC Reflectivity'
ncdf_attput, cdfid, dbzgvvarid, 'units', 'dBZ'
ncdf_attput, cdfid, dbzgvvarid, '_FillValue', FLOAT_RANGE_EDGE

stddevgvvarid = ncdf_vardef(cdfid, 'GR_Z_StdDev_slantPath', [fpdimid,eldimid])
ncdf_attput, cdfid, stddevgvvarid, 'long_name', $
   'Standard Deviation of GV radar QC Reflectivity'
ncdf_attput, cdfid, stddevgvvarid, 'units', 'dBZ'
ncdf_attput, cdfid, stddevgvvarid, '_FillValue', FLOAT_RANGE_EDGE

gvmaxvarid = ncdf_vardef(cdfid, 'GR_Z_Max_slantPath', [fpdimid,eldimid])
ncdf_attput, cdfid, gvmaxvarid, 'long_name', $
   'Sample Maximum GV radar QC Reflectivity'
ncdf_attput, cdfid, gvmaxvarid, 'units', 'dBZ'
ncdf_attput, cdfid, gvmaxvarid, '_FillValue', FLOAT_RANGE_EDGE

gvrrvarid = ncdf_vardef(cdfid, 'GR_RC_rainrate_slantPath', [fpdimid,eldimid])
ncdf_attput, cdfid, gvrrvarid, 'long_name', 'GV radar Cifelli Rain Rate'
ncdf_attput, cdfid, gvrrvarid, 'units', 'dBZ'
ncdf_attput, cdfid, gvrrvarid, '_FillValue', FLOAT_RANGE_EDGE

stddevgvrrvarid = ncdf_vardef(cdfid, 'GR_RC_rainrate_StdDev_slantPath', [fpdimid,eldimid])
ncdf_attput, cdfid, stddevgvrrvarid, 'long_name', $
   'Standard Deviation of GV radar Cifelli Rain Rate'
ncdf_attput, cdfid, stddevgvrrvarid, 'units', 'dBZ'
ncdf_attput, cdfid, stddevgvrrvarid, '_FillValue', FLOAT_RANGE_EDGE

gvrrmaxvarid = ncdf_vardef(cdfid, 'GR_RC_rainrate_Max_slantPath', [fpdimid,eldimid])
ncdf_attput, cdfid, gvrrmaxvarid, 'long_name', $
   'Sample Maximum GV radar Cifelli Rain Rate'
ncdf_attput, cdfid, gvrrmaxvarid, 'units', 'dBZ'
ncdf_attput, cdfid, gvrrmaxvarid, '_FillValue', FLOAT_RANGE_EDGE

gvrrvarid = ncdf_vardef(cdfid, 'GR_RP_rainrate_slantPath', [fpdimid,eldimid])
ncdf_attput, cdfid, gvrrvarid, 'long_name', 'GV radar PolZR Rain Rate'
ncdf_attput, cdfid, gvrrvarid, 'units', 'dBZ'
ncdf_attput, cdfid, gvrrvarid, '_FillValue', FLOAT_RANGE_EDGE

stddevgvrrvarid = ncdf_vardef(cdfid, 'GR_RP_rainrate_StdDev_slantPath', [fpdimid,eldimid])
ncdf_attput, cdfid, stddevgvrrvarid, 'long_name', $
   'Standard Deviation of GV radar PolZR Rain Rate'
ncdf_attput, cdfid, stddevgvrrvarid, 'units', 'dBZ'
ncdf_attput, cdfid, stddevgvrrvarid, '_FillValue', FLOAT_RANGE_EDGE

gvrrmaxvarid = ncdf_vardef(cdfid, 'GR_RP_rainrate_Max_slantPath', [fpdimid,eldimid])
ncdf_attput, cdfid, gvrrmaxvarid, 'long_name', $
   'Sample Maximum GV radar PolZR Rain Rate'
ncdf_attput, cdfid, gvrrmaxvarid, 'units', 'dBZ'
ncdf_attput, cdfid, gvrrmaxvarid, '_FillValue', FLOAT_RANGE_EDGE

gvrrvarid = ncdf_vardef(cdfid, 'GR_RR_rainrate_slantPath', [fpdimid,eldimid])
ncdf_attput, cdfid, gvrrvarid, 'long_name', 'GV radar DROPS Rain Rate'
ncdf_attput, cdfid, gvrrvarid, 'units', 'dBZ'
ncdf_attput, cdfid, gvrrvarid, '_FillValue', FLOAT_RANGE_EDGE

stddevgvrrvarid = ncdf_vardef(cdfid, 'GR_RR_rainrate_StdDev_slantPath', [fpdimid,eldimid])
ncdf_attput, cdfid, stddevgvrrvarid, 'long_name', $
   'Standard Deviation of GV radar DROPS Rain Rate'
ncdf_attput, cdfid, stddevgvrrvarid, 'units', 'dBZ'
ncdf_attput, cdfid, stddevgvrrvarid, '_FillValue', FLOAT_RANGE_EDGE

gvrrmaxvarid = ncdf_vardef(cdfid, 'GR_RR_rainrate_Max_slantPath', [fpdimid,eldimid])
ncdf_attput, cdfid, gvrrmaxvarid, 'long_name', $
   'Sample Maximum GV radar DROPS Rain Rate'
ncdf_attput, cdfid, gvrrmaxvarid, 'units', 'dBZ'
ncdf_attput, cdfid, gvrrmaxvarid, '_FillValue', FLOAT_RANGE_EDGE

gvZDRvarid = ncdf_vardef(cdfid, 'GR_Zdr_slantPath', [fpdimid,eldimid])
ncdf_attput, cdfid, gvZDRvarid, 'long_name', 'DP Differential Reflectivity'
ncdf_attput, cdfid, gvZDRvarid, 'units', 'dB'
ncdf_attput, cdfid, gvZDRvarid, '_FillValue', FLOAT_RANGE_EDGE

gvZDRStdDevvarid = ncdf_vardef(cdfid, 'GR_Zdr_StdDev_slantPath', [fpdimid,eldimid])
ncdf_attput, cdfid, gvZDRStdDevvarid, 'long_name', $
   'Standard Deviation of DP Differential Reflectivity'
ncdf_attput, cdfid, gvZDRStdDevvarid, 'units', 'dB'
ncdf_attput, cdfid, gvZDRStdDevvarid, '_FillValue', FLOAT_RANGE_EDGE

gvZDRMaxvarid = ncdf_vardef(cdfid, 'GR_Zdr_Max_slantPath', [fpdimid,eldimid])
ncdf_attput, cdfid, gvZDRMaxvarid, 'long_name', $
   'Sample Maximum DP Differential Reflectivity'
ncdf_attput, cdfid, gvZDRMaxvarid, 'units', 'dB'
ncdf_attput, cdfid, gvZDRMaxvarid, '_FillValue', FLOAT_RANGE_EDGE

gvKdpvarid = ncdf_vardef(cdfid, 'GR_Kdp_slantPath', [fpdimid,eldimid])
ncdf_attput, cdfid, gvKdpvarid, 'long_name', 'DP Specific Differential Phase'
ncdf_attput, cdfid, gvKdpvarid, 'units', 'deg/km'
ncdf_attput, cdfid, gvKdpvarid, '_FillValue', FLOAT_RANGE_EDGE

gvKdpStdDevvarid = ncdf_vardef(cdfid, 'GR_Kdp_StdDev_slantPath', [fpdimid,eldimid])
ncdf_attput, cdfid, gvKdpStdDevvarid, 'long_name', $
   'Standard Deviation of DP Specific Differential Phase'
ncdf_attput, cdfid, gvKdpStdDevvarid, 'units', 'deg/km'
ncdf_attput, cdfid, gvKdpStdDevvarid, '_FillValue', FLOAT_RANGE_EDGE

gvKdpMaxvarid = ncdf_vardef(cdfid, 'GR_Kdp_Max_slantPath', [fpdimid,eldimid])
ncdf_attput, cdfid, gvKdpMaxvarid, 'long_name', $
   'Sample Maximum DP Specific Differential Phase'
ncdf_attput, cdfid, gvKdpMaxvarid, 'units', 'deg/km'
ncdf_attput, cdfid, gvKdpMaxvarid, '_FillValue', FLOAT_RANGE_EDGE

gvRHOHVvarid = ncdf_vardef(cdfid, 'GR_RHOhv_slantPath', [fpdimid,eldimid])
ncdf_attput, cdfid, gvRHOHVvarid, 'long_name', 'DP Co-Polar Correlation Coefficient'
ncdf_attput, cdfid, gvRHOHVvarid, 'units', 'Dimensionless'
ncdf_attput, cdfid, gvRHOHVvarid, '_FillValue', FLOAT_RANGE_EDGE

gvRHOHVStdDevvarid = ncdf_vardef(cdfid, 'GR_RHOhv_StdDev_slantPath', [fpdimid,eldimid])
ncdf_attput, cdfid, gvRHOHVStdDevvarid, 'long_name', $
   'Standard Deviation of DP Co-Polar Correlation Coefficient'
ncdf_attput, cdfid, gvRHOHVStdDevvarid, 'units', 'Dimensionless'
ncdf_attput, cdfid, gvRHOHVStdDevvarid, '_FillValue', FLOAT_RANGE_EDGE

gvRHOHVMaxvarid = ncdf_vardef(cdfid, 'GR_RHOhv_Max_slantPath', [fpdimid,eldimid])
ncdf_attput, cdfid, gvRHOHVMaxvarid, 'long_name', $
   'Sample Maximum DP Co-Polar Correlation Coefficient'
ncdf_attput, cdfid, gvRHOHVMaxvarid, 'units', 'Dimensionless'
ncdf_attput, cdfid, gvRHOHVMaxvarid, '_FillValue', FLOAT_RANGE_EDGE

gvHIDvarid = ncdf_vardef(cdfid, 'GR_HID_slantPath', [hidimid,fpdimid,eldimid], /short)
ncdf_attput, cdfid, gvHIDvarid, 'long_name', 'DP Hydrometeor Identification'
ncdf_attput, cdfid, gvHIDvarid, 'units', 'Categorical'
ncdf_attput, cdfid, gvHIDvarid, '_FillValue', INT_RANGE_EDGE

gvDzerovarid = ncdf_vardef(cdfid, 'GR_Dzero_slantPath', [fpdimid,eldimid])
ncdf_attput, cdfid, gvDzerovarid, 'long_name', 'DP Median Volume Diameter'
ncdf_attput, cdfid, gvDzerovarid, 'units', 'mm'
ncdf_attput, cdfid, gvDzerovarid, '_FillValue', FLOAT_RANGE_EDGE

gvDzeroStdDevvarid = ncdf_vardef(cdfid, 'GR_Dzero_StdDev_slantPath', [fpdimid,eldimid])
ncdf_attput, cdfid, gvDzeroStdDevvarid, 'long_name', $
   'Standard Deviation of DP Median Volume Diameter'
ncdf_attput, cdfid, gvDzeroStdDevvarid, 'units', 'mm'
ncdf_attput, cdfid, gvDzeroStdDevvarid, '_FillValue', FLOAT_RANGE_EDGE

gvDzeroMaxvarid = ncdf_vardef(cdfid, 'GR_Dzero_Max_slantPath', [fpdimid,eldimid])
ncdf_attput, cdfid, gvDzeroMaxvarid, 'long_name', $
   'Sample Maximum DP Median Volume Diameter'
ncdf_attput, cdfid, gvDzeroMaxvarid, 'units', 'mm'
ncdf_attput, cdfid, gvDzeroMaxvarid, '_FillValue', FLOAT_RANGE_EDGE

gvNWvarid = ncdf_vardef(cdfid, 'GR_Nw_slantPath', [fpdimid,eldimid])
ncdf_attput, cdfid, gvNWvarid, 'long_name', $
   'DP Normalized Intercept Parameter'
ncdf_attput, cdfid, gvNWvarid, 'units', '1/(mm*m^3)'
ncdf_attput, cdfid, gvNWvarid, '_FillValue', FLOAT_RANGE_EDGE

gvNWStdDevvarid = ncdf_vardef(cdfid, 'GR_Nw_StdDev_slantPath', [fpdimid,eldimid])
ncdf_attput, cdfid, gvNWStdDevvarid, 'long_name', $
   'Standard Deviation of DP Normalized Intercept Parameter'
ncdf_attput, cdfid, gvNWStdDevvarid, 'units', '1/(mm*m^3)'
ncdf_attput, cdfid, gvNWStdDevvarid, '_FillValue', FLOAT_RANGE_EDGE

gvNWMaxvarid = ncdf_vardef(cdfid, 'GR_Nw_Max_slantPath', [fpdimid,eldimid])
ncdf_attput, cdfid, gvNWMaxvarid, 'long_name', $
   'Sample Maximum DP Normalized Intercept Parameter'
ncdf_attput, cdfid, gvNWMaxvarid, 'units', '1/(mm*m^3)'
ncdf_attput, cdfid, gvNWMaxvarid, '_FillValue', FLOAT_RANGE_EDGE

BLKvarid = ncdf_vardef(cdfid, 'GR_blockage_slantPath', [fpdimid,eldimid])
ncdf_attput, cdfid, BLKvarid, 'long_name', $
             'ground radar blockage fraction'
ncdf_attput, cdfid, BLKvarid, '_FillValue', FLOAT_RANGE_EDGE

gvexpvarid = ncdf_vardef(cdfid, 'n_gr_expected', [fpdimid,eldimid], /short)
ncdf_attput, cdfid, gvexpvarid, 'long_name', $
             'number of bins in GR slantPath averages'
ncdf_attput, cdfid, gvexpvarid, '_FillValue', INT_RANGE_EDGE

gvrejvarid = ncdf_vardef(cdfid, 'n_gr_z_rejected', [fpdimid,eldimid], /short)
ncdf_attput, cdfid, gvrejvarid, 'long_name', $
             'number of bins below GR_dBZ_min in GR_Z_slantPath average'
ncdf_attput, cdfid, gvrejvarid, '_FillValue', INT_RANGE_EDGE

gvrrrejvarid = ncdf_vardef(cdfid, 'n_gr_rc_rejected', [fpdimid,eldimid], /short)
ncdf_attput, cdfid, gvrrrejvarid, 'long_name', $
             'number of bins below gprof_rain_min in GR_RC_rainrate_slantPath average'
ncdf_attput, cdfid, gvrrrejvarid, '_FillValue', INT_RANGE_EDGE

gvrrrejvarid = ncdf_vardef(cdfid, 'n_gr_rp_rejected', [fpdimid,eldimid], /short)
ncdf_attput, cdfid, gvrrrejvarid, 'long_name', $
             'number of bins below gprof_rain_min in GR_RP_rainrate_slantPath average'
ncdf_attput, cdfid, gvrrrejvarid, '_FillValue', INT_RANGE_EDGE

gvrrrejvarid = ncdf_vardef(cdfid, 'n_gr_rr_rejected', [fpdimid,eldimid], /short)
ncdf_attput, cdfid, gvrrrejvarid, 'long_name', $
             'number of bins below gprof_rain_min in GR_RR_rainrate_slantPath average'
ncdf_attput, cdfid, gvrrrejvarid, '_FillValue', INT_RANGE_EDGE

gv_zdr_rejvarid = ncdf_vardef(cdfid, 'n_gr_zdr_rejected', [fpdimid,eldimid], /short)
ncdf_attput, cdfid, gv_zdr_rejvarid, 'long_name', $
             'number of bins with missing Zdr in GR_Zdr_slantPath average'
ncdf_attput, cdfid, gv_zdr_rejvarid, '_FillValue', INT_RANGE_EDGE

gv_kdp_rejvarid = ncdf_vardef(cdfid, 'n_gr_kdp_rejected', [fpdimid,eldimid], /short)
ncdf_attput, cdfid, gv_kdp_rejvarid, 'long_name', $
             'number of bins with missing Kdp in GR_Kdp_slantPath average'
ncdf_attput, cdfid, gv_kdp_rejvarid, '_FillValue', INT_RANGE_EDGE

gv_rhohv_rejvarid = ncdf_vardef(cdfid, 'n_gr_rhohv_rejected', [fpdimid,eldimid], /short)
ncdf_attput, cdfid, gv_rhohv_rejvarid, 'long_name', $
             'number of bins with missing RHOhv in GR_RHOhv_slantPath average'
ncdf_attput, cdfid, gv_rhohv_rejvarid, '_FillValue', INT_RANGE_EDGE

gv_hid_rejvarid = ncdf_vardef(cdfid, 'n_gr_hid_rejected', [fpdimid,eldimid], /short)
ncdf_attput, cdfid, gv_hid_rejvarid, 'long_name', $
             'number of bins with undefined HID in GR_HID_slantPath histogram'
ncdf_attput, cdfid, gv_hid_rejvarid, '_FillValue', INT_RANGE_EDGE

gv_dzero_rejvarid = ncdf_vardef(cdfid, 'n_gr_dzero_rejected', [fpdimid,eldimid], /short)
ncdf_attput, cdfid, gv_dzero_rejvarid, 'long_name', $
             'number of bins with missing D0 in GR_Dzero_slantPath average'
ncdf_attput, cdfid, gv_dzero_rejvarid, '_FillValue', INT_RANGE_EDGE

gv_nw_rejvarid = ncdf_vardef(cdfid, 'n_gr_nw_rejected', [fpdimid,eldimid], /short)
ncdf_attput, cdfid, gv_nw_rejvarid, 'long_name', $
             'number of bins with missing Nw in GR_Nw_slantPath average'
ncdf_attput, cdfid, gv_nw_rejvarid, '_FillValue', INT_RANGE_EDGE

dbzgvvarid_vpr = ncdf_vardef(cdfid, 'GR_Z_VPR', [fpdimid,eldimid])
ncdf_attput, cdfid, dbzgvvarid_vpr, 'long_name', $
   'GV radar QC Reflectivity along local vertical'
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

gvrrvarid_vpr = ncdf_vardef(cdfid, 'GR_RC_rainrate_VPR', [fpdimid,eldimid])
ncdf_attput, cdfid, gvrrvarid_vpr, 'long_name', $
   'GV radar Cifelli Rain Rate along local vertical'
ncdf_attput, cdfid, gvrrvarid_vpr, 'units', 'dBZ'
ncdf_attput, cdfid, gvrrvarid_vpr, '_FillValue', FLOAT_RANGE_EDGE

stddevgvrrvarid_vpr = ncdf_vardef(cdfid, 'GR_RC_rainrate_StdDev_VPR', [fpdimid,eldimid])
ncdf_attput, cdfid, stddevgvrrvarid_vpr, 'long_name', $
   'Standard Deviation of GV radar Cifelli Rain Rate along local vertical'
ncdf_attput, cdfid, stddevgvrrvarid_vpr, 'units', 'dBZ'
ncdf_attput, cdfid, stddevgvrrvarid_vpr, '_FillValue', FLOAT_RANGE_EDGE

gvrrmaxvarid_vpr = ncdf_vardef(cdfid, 'GR_RC_rainrate_Max_VPR', [fpdimid,eldimid])
ncdf_attput, cdfid, gvrrmaxvarid_vpr, 'long_name', $
   'Sample Maximum GV radar Cifelli Rain Rate along local vertical'
ncdf_attput, cdfid, gvrrmaxvarid_vpr, 'units', 'dBZ'
ncdf_attput, cdfid, gvrrmaxvarid_vpr, '_FillValue', FLOAT_RANGE_EDGE

gvrrvarid_vpr = ncdf_vardef(cdfid, 'GR_RP_rainrate_VPR', [fpdimid,eldimid])
ncdf_attput, cdfid, gvrrvarid_vpr, 'long_name', $
   'GV radar PolZR Rain Rate along local vertical'
ncdf_attput, cdfid, gvrrvarid_vpr, 'units', 'dBZ'
ncdf_attput, cdfid, gvrrvarid_vpr, '_FillValue', FLOAT_RANGE_EDGE

stddevgvrrvarid_vpr = ncdf_vardef(cdfid, 'GR_RP_rainrate_StdDev_VPR', [fpdimid,eldimid])
ncdf_attput, cdfid, stddevgvrrvarid_vpr, 'long_name', $
   'Standard Deviation of GV radar PolZR Rain Rate along local vertical'
ncdf_attput, cdfid, stddevgvrrvarid_vpr, 'units', 'dBZ'
ncdf_attput, cdfid, stddevgvrrvarid_vpr, '_FillValue', FLOAT_RANGE_EDGE

gvrrmaxvarid_vpr = ncdf_vardef(cdfid, 'GR_RP_rainrate_Max_VPR', [fpdimid,eldimid])
ncdf_attput, cdfid, gvrrmaxvarid_vpr, 'long_name', $
   'Sample Maximum GV radar PolZR Rain Rate along local vertical'
ncdf_attput, cdfid, gvrrmaxvarid_vpr, 'units', 'dBZ'
ncdf_attput, cdfid, gvrrmaxvarid_vpr, '_FillValue', FLOAT_RANGE_EDGE

gvrrvarid_vpr = ncdf_vardef(cdfid, 'GR_RR_rainrate_VPR', [fpdimid,eldimid])
ncdf_attput, cdfid, gvrrvarid_vpr, 'long_name', $
   'GV radar DROPS Rain Rate along local vertical'
ncdf_attput, cdfid, gvrrvarid_vpr, 'units', 'dBZ'
ncdf_attput, cdfid, gvrrvarid_vpr, '_FillValue', FLOAT_RANGE_EDGE

stddevgvrrvarid_vpr = ncdf_vardef(cdfid, 'GR_RR_rainrate_StdDev_VPR', [fpdimid,eldimid])
ncdf_attput, cdfid, stddevgvrrvarid_vpr, 'long_name', $
   'Standard Deviation of GV radar DROPS Rain Rate along local vertical'
ncdf_attput, cdfid, stddevgvrrvarid_vpr, 'units', 'dBZ'
ncdf_attput, cdfid, stddevgvrrvarid_vpr, '_FillValue', FLOAT_RANGE_EDGE

gvrrmaxvarid_vpr = ncdf_vardef(cdfid, 'GR_RR_rainrate_Max_VPR', [fpdimid,eldimid])
ncdf_attput, cdfid, gvrrmaxvarid_vpr, 'long_name', $
   'Sample Maximum GV radar DROPS Rain Rate along local vertical'
ncdf_attput, cdfid, gvrrmaxvarid_vpr, 'units', 'dBZ'
ncdf_attput, cdfid, gvrrmaxvarid_vpr, '_FillValue', FLOAT_RANGE_EDGE

gvZDRvarid_vpr = ncdf_vardef(cdfid, 'GR_Zdr_VPR', [fpdimid,eldimid])
ncdf_attput, cdfid, gvZDRvarid_vpr, 'long_name', $
   'DP Differential Reflectivity along local vertical'
ncdf_attput, cdfid, gvZDRvarid_vpr, 'units', 'dB'
ncdf_attput, cdfid, gvZDRvarid_vpr, '_FillValue', FLOAT_RANGE_EDGE

gvZDRStdDevvarid_vpr = ncdf_vardef(cdfid, 'GR_Zdr_StdDev_VPR', [fpdimid,eldimid])
ncdf_attput, cdfid, gvZDRStdDevvarid_vpr, 'long_name', $
   'Standard Deviation of DP Differential Reflectivity along local vertical'
ncdf_attput, cdfid, gvZDRStdDevvarid_vpr, 'units', 'dB'
ncdf_attput, cdfid, gvZDRStdDevvarid_vpr, '_FillValue', FLOAT_RANGE_EDGE

gvZDRMaxvarid_vpr = ncdf_vardef(cdfid, 'GR_Zdr_Max_VPR', [fpdimid,eldimid])
ncdf_attput, cdfid, gvZDRMaxvarid_vpr, 'long_name', $
   'Sample Maximum DP Differential Reflectivity along local vertical'
ncdf_attput, cdfid, gvZDRMaxvarid_vpr, 'units', 'dB'
ncdf_attput, cdfid, gvZDRMaxvarid_vpr, '_FillValue', FLOAT_RANGE_EDGE

gvKdpvarid_vpr = ncdf_vardef(cdfid, 'GR_Kdp_VPR', [fpdimid,eldimid])
ncdf_attput, cdfid, gvKdpvarid_vpr, 'long_name', $
   'DP Specific Differential Phase along local vertical'
ncdf_attput, cdfid, gvKdpvarid_vpr, 'units', 'deg/km'
ncdf_attput, cdfid, gvKdpvarid_vpr, '_FillValue', FLOAT_RANGE_EDGE

gvKdpStdDevvarid_vpr = ncdf_vardef(cdfid, 'GR_Kdp_StdDev_VPR', [fpdimid,eldimid])
ncdf_attput, cdfid, gvKdpStdDevvarid_vpr, 'long_name', $
   'Standard Deviation of DP Specific Differential Phase along local vertical'
ncdf_attput, cdfid, gvKdpStdDevvarid_vpr, 'units', 'deg/km'
ncdf_attput, cdfid, gvKdpStdDevvarid_vpr, '_FillValue', FLOAT_RANGE_EDGE

gvKdpMaxvarid_vpr = ncdf_vardef(cdfid, 'GR_Kdp_Max_VPR', [fpdimid,eldimid])
ncdf_attput, cdfid, gvKdpMaxvarid_vpr, 'long_name', $
   'Sample Maximum DP Specific Differential Phase along local vertical'
ncdf_attput, cdfid, gvKdpMaxvarid_vpr, 'units', 'deg/km'
ncdf_attput, cdfid, gvKdpMaxvarid_vpr, '_FillValue', FLOAT_RANGE_EDGE

gvRHOHVvarid_vpr = ncdf_vardef(cdfid, 'GR_RHOhv_VPR', [fpdimid,eldimid])
ncdf_attput, cdfid, gvRHOHVvarid_vpr, 'long_name', $
   'DP Co-Polar Correlation Coefficient along local vertical'
ncdf_attput, cdfid, gvRHOHVvarid_vpr, 'units', 'Dimensionless'
ncdf_attput, cdfid, gvRHOHVvarid_vpr, '_FillValue', FLOAT_RANGE_EDGE

gvRHOHVStdDevvarid_vpr = ncdf_vardef(cdfid, 'GR_RHOhv_StdDev_VPR', [fpdimid,eldimid])
ncdf_attput, cdfid, gvRHOHVStdDevvarid_vpr, 'long_name', $
   'Standard Deviation of DP Co-Polar Correlation Coefficient along local vertical'
ncdf_attput, cdfid, gvRHOHVStdDevvarid_vpr, 'units', 'Dimensionless'
ncdf_attput, cdfid, gvRHOHVStdDevvarid_vpr, '_FillValue', FLOAT_RANGE_EDGE

gvRHOHVMaxvarid_vpr = ncdf_vardef(cdfid, 'GR_RHOhv_Max_VPR', [fpdimid,eldimid])
ncdf_attput, cdfid, gvRHOHVMaxvarid_vpr, 'long_name', $
   'Sample Maximum DP Co-Polar Correlation Coefficient along local vertical'
ncdf_attput, cdfid, gvRHOHVMaxvarid_vpr, 'units', 'Dimensionless'
ncdf_attput, cdfid, gvRHOHVMaxvarid_vpr, '_FillValue', FLOAT_RANGE_EDGE

gvHIDvarid_vpr = ncdf_vardef(cdfid, 'GR_HID_VPR', [hidimid,fpdimid,eldimid], /short)
ncdf_attput, cdfid, gvHIDvarid_vpr, 'long_name', $
   'DP Hydrometeor Identification along local vertical'
ncdf_attput, cdfid, gvHIDvarid_vpr, 'units', 'Categorical'
ncdf_attput, cdfid, gvHIDvarid_vpr, '_FillValue', INT_RANGE_EDGE

gvDzerovarid_vpr = ncdf_vardef(cdfid, 'GR_Dzero_VPR', [fpdimid,eldimid])
ncdf_attput, cdfid, gvDzerovarid_vpr, 'long_name', $
   'DP Median Volume Diameter along local vertical'
ncdf_attput, cdfid, gvDzerovarid_vpr, 'units', 'mm'
ncdf_attput, cdfid, gvDzerovarid_vpr, '_FillValue', FLOAT_RANGE_EDGE

gvDzeroStdDevvarid_vpr = ncdf_vardef(cdfid, 'GR_Dzero_StdDev_VPR', [fpdimid,eldimid])
ncdf_attput, cdfid, gvDzeroStdDevvarid_vpr, 'long_name', $
   'Standard Deviation of DP Median Volume Diameter along local vertical'
ncdf_attput, cdfid, gvDzeroStdDevvarid_vpr, 'units', 'mm'
ncdf_attput, cdfid, gvDzeroStdDevvarid_vpr, '_FillValue', FLOAT_RANGE_EDGE

gvDzeroMaxvarid_vpr = ncdf_vardef(cdfid, 'GR_Dzero_Max_VPR', [fpdimid,eldimid])
ncdf_attput, cdfid, gvDzeroMaxvarid_vpr, 'long_name', $
   'Sample Maximum DP Median Volume Diameter along local vertical'
ncdf_attput, cdfid, gvDzeroMaxvarid_vpr, 'units', 'mm'
ncdf_attput, cdfid, gvDzeroMaxvarid_vpr, '_FillValue', FLOAT_RANGE_EDGE

gvNWvarid_vpr = ncdf_vardef(cdfid, 'GR_Nw_VPR', [fpdimid,eldimid])
ncdf_attput, cdfid, gvNWvarid_vpr, 'long_name', $
   'DP Normalized Intercept Parameter along local vertical'
ncdf_attput, cdfid, gvNWvarid_vpr, 'units', '1/(mm*m^3)'
ncdf_attput, cdfid, gvNWvarid_vpr, '_FillValue', FLOAT_RANGE_EDGE

gvNWStdDevvarid_vpr = ncdf_vardef(cdfid, 'GR_Nw_StdDev_VPR', [fpdimid,eldimid])
ncdf_attput, cdfid, gvNWStdDevvarid_vpr, 'long_name', $
   'Standard Deviation of DP Normalized Intercept Parameter along local vertical'
ncdf_attput, cdfid, gvNWStdDevvarid_vpr, 'units', '1/(mm*m^3)'
ncdf_attput, cdfid, gvNWStdDevvarid_vpr, '_FillValue', FLOAT_RANGE_EDGE

gvNWMaxvarid_vpr = ncdf_vardef(cdfid, 'GR_Nw_Max_VPR', [fpdimid,eldimid])
ncdf_attput, cdfid, gvNWMaxvarid_vpr, 'long_name', $
   'Sample Maximum DP Normalized Intercept Parameter along local vertical'
ncdf_attput, cdfid, gvNWMaxvarid_vpr, 'units', '1/(mm*m^3)'
ncdf_attput, cdfid, gvNWMaxvarid_vpr, '_FillValue', FLOAT_RANGE_EDGE

BLKvarid_vpr = ncdf_vardef(cdfid, 'GR_blockage_VPR', [fpdimid,eldimid])
ncdf_attput, cdfid, BLKvarid_vpr, 'long_name', $
             'ground radar blockage fraction along local vertical'
ncdf_attput, cdfid, BLKvarid_vpr, '_FillValue', FLOAT_RANGE_EDGE

gvexpvarid_vpr = ncdf_vardef(cdfid, 'n_gr_vpr_expected', [fpdimid,eldimid], /short)
ncdf_attput, cdfid, gvexpvarid_vpr, 'long_name', $
             'number of bins in GR_Z_VPR, GR_rainrate_VPR averages'
ncdf_attput, cdfid, gvexpvarid_vpr, '_FillValue', INT_RANGE_EDGE

gvrejvarid_vpr = ncdf_vardef(cdfid, 'n_gr_z_vpr_rejected', [fpdimid,eldimid], /short)
ncdf_attput, cdfid, gvrejvarid_vpr, 'long_name', $
             'number of bins below GR_dBZ_min in GR_Z_VPR average'
ncdf_attput, cdfid, gvrejvarid_vpr, '_FillValue', INT_RANGE_EDGE

gvrrrejvarid_vpr = ncdf_vardef(cdfid, 'n_gr_rc_vpr_rejected', [fpdimid,eldimid], /short)
ncdf_attput, cdfid, gvrrrejvarid_vpr, 'long_name', $
             'number of bins below gprof_rain_min in GR_RC_rainrate_VPR average'
ncdf_attput, cdfid, gvrrrejvarid_vpr, '_FillValue', INT_RANGE_EDGE

gvrrrejvarid_vpr = ncdf_vardef(cdfid, 'n_gr_rp_vpr_rejected', [fpdimid,eldimid], /short)
ncdf_attput, cdfid, gvrrrejvarid_vpr, 'long_name', $
             'number of bins below gprof_rain_min in GR_RP_rainrate_VPR average'
ncdf_attput, cdfid, gvrrrejvarid_vpr, '_FillValue', INT_RANGE_EDGE

gvrrrejvarid_vpr = ncdf_vardef(cdfid, 'n_gr_rr_vpr_rejected', [fpdimid,eldimid], /short)
ncdf_attput, cdfid, gvrrrejvarid_vpr, 'long_name', $
             'number of bins below gprof_rain_min in GR_RR_rainrate_VPR average'
ncdf_attput, cdfid, gvrrrejvarid_vpr, '_FillValue', INT_RANGE_EDGE

gv_zdr_rejvarid_vpr = ncdf_vardef(cdfid, 'n_gr_zdr_vpr_rejected', [fpdimid,eldimid], /short)
ncdf_attput, cdfid, gv_zdr_rejvarid_vpr, 'long_name', $
             'number of bins with missing Zdr in GR_Zdr_VPR average'
ncdf_attput, cdfid, gv_zdr_rejvarid_vpr, '_FillValue', INT_RANGE_EDGE

gv_kdp_rejvarid_vpr = ncdf_vardef(cdfid, 'n_gr_kdp_vpr_rejected', [fpdimid,eldimid], /short)
ncdf_attput, cdfid, gv_kdp_rejvarid_vpr, 'long_name', $
             'number of bins with missing Kdp in GR_Kdp_VPR average'
ncdf_attput, cdfid, gv_kdp_rejvarid_vpr, '_FillValue', INT_RANGE_EDGE

gv_rhohv_rejvarid_vpr = ncdf_vardef(cdfid, 'n_gr_rhohv_vpr_rejected', [fpdimid,eldimid], /short)
ncdf_attput, cdfid, gv_rhohv_rejvarid_vpr, 'long_name', $
             'number of bins with missing RHOhv in GR_RHOhv_VPR average'
ncdf_attput, cdfid, gv_rhohv_rejvarid_vpr, '_FillValue', INT_RANGE_EDGE

gv_hid_rejvarid_vpr = ncdf_vardef(cdfid, 'n_gr_hid_vpr_rejected', [fpdimid,eldimid], /short)
ncdf_attput, cdfid, gv_hid_rejvarid_vpr, 'long_name', $
             'number of bins with undefined HID in GR_HID_VPR histogram'
ncdf_attput, cdfid, gv_hid_rejvarid_vpr, '_FillValue', INT_RANGE_EDGE

gv_dzero_rejvarid_vpr = ncdf_vardef(cdfid, 'n_gr_dzero_vpr_rejected', [fpdimid,eldimid], /short)
ncdf_attput, cdfid, gv_dzero_rejvarid_vpr, 'long_name', $
             'number of bins with missing D0 in GR_Dzero_VPR average'
ncdf_attput, cdfid, gv_dzero_rejvarid_vpr, '_FillValue', INT_RANGE_EDGE

gv_nw_rejvarid_vpr = ncdf_vardef(cdfid, 'n_gr_nw_vpr_rejected', [fpdimid,eldimid], /short)
ncdf_attput, cdfid, gv_nw_rejvarid_vpr, 'long_name', $
             'number of bins with missing Nw in GR_Nw_VPR average'
ncdf_attput, cdfid, gv_nw_rejvarid_vpr, '_FillValue', INT_RANGE_EDGE

; single-level fields

sfclatvarid = ncdf_vardef(cdfid, 'XMIlatitude', [fpdimid])
ncdf_attput, cdfid, sfclatvarid, 'long_name', 'Latitude of XMI surface bin'
ncdf_attput, cdfid, sfclatvarid, 'units', 'degrees North'
ncdf_attput, cdfid, sfclatvarid, '_FillValue', FLOAT_RANGE_EDGE

sfclonvarid = ncdf_vardef(cdfid, 'XMIlongitude', [fpdimid])
ncdf_attput, cdfid, sfclonvarid, 'long_name', 'Longitude of XMI surface bin'
ncdf_attput, cdfid, sfclonvarid, 'units', 'degrees East'
ncdf_attput, cdfid, sfclonvarid, '_FillValue', FLOAT_RANGE_EDGE

surfaceTypevarid = ncdf_vardef(cdfid, 'surfaceTypeIndex', [fpdimid], /short)
ncdf_attput, cdfid, surfaceTypevarid, 'long_name', '2A-GPROF surfaceTypeIndex'
ncdf_attput, cdfid, surfaceTypevarid, 'units', 'Categorical'
ncdf_attput, cdfid, surfaceTypevarid, '_FillValue', INT_RANGE_EDGE

sfrainvarid = ncdf_vardef(cdfid, 'surfacePrecipitation', [fpdimid])
ncdf_attput, cdfid, sfrainvarid, 'long_name', $
             '2A-GPROF Estimated Surface Rain Rate'
ncdf_attput, cdfid, sfrainvarid, 'units', 'mm/h'
ncdf_attput, cdfid, sfrainvarid, '_FillValue', FLOAT_RANGE_EDGE

pixelStatusvarid = ncdf_vardef(cdfid, 'pixelStatus', [fpdimid], /short)
ncdf_attput, cdfid, pixelStatusvarid, 'long_name', $
            '2A-GPROF pixelStatus'
ncdf_attput, cdfid, pixelStatusvarid, 'units', 'Categorical'
ncdf_attput, cdfid, pixelStatusvarid, '_FillValue', INT_RANGE_EDGE

PoPvarid = ncdf_vardef(cdfid, 'PoP', [fpdimid], /short)
ncdf_attput, cdfid, PoPvarid, 'long_name', $
            '2A-GPROF probabilityOfPrecip'
ncdf_attput, cdfid, PoPvarid, 'units', 'percent'
ncdf_attput, cdfid, PoPvarid, '_FillValue', INT_RANGE_EDGE

freezingHeightvarid = ncdf_vardef(cdfid, 'freezingHeight', [fpdimid], /short)
ncdf_attput, cdfid, freezingHeightvarid, 'long_name', $
            'Freezing Height'
ncdf_attput, cdfid, freezingHeightvarid, 'units', 'meters'
ncdf_attput, cdfid, freezingHeightvarid, '_FillValue', INT_RANGE_EDGE

Qualityvarid = ncdf_vardef(cdfid, 'Quality', [Tbdimid,tcfpdimid], /short)
ncdf_attput, cdfid, Qualityvarid, 'long_name', $
             '1C-R-XCAL Common Calibrated Brightness Temperatures Quality'
ncdf_attput, cdfid, Qualityvarid, 'units', 'Categorical'
ncdf_attput, cdfid, Qualityvarid, '_FillValue', INT_RANGE_EDGE

Tcvarid = ncdf_vardef(cdfid, 'Tc', [Tbdimid,tcfpdimid])
ncdf_attput, cdfid, Tcvarid, 'long_name', $
             '1C-R-XCAL Common Calibrated Brightness Temperatures, Tc'
ncdf_attput, cdfid, Tcvarid, 'units', 'Kelvins'
ncdf_attput, cdfid, Tcvarid, '_FillValue', FLOAT_RANGE_EDGE

rayidxvarid = ncdf_vardef(cdfid, 'rayIndex', [fpdimid], /long)
ncdf_attput, cdfid, rayidxvarid, 'long_name', $
            'XMI product-relative ray,scan IDL 1-D array index'
ncdf_attput, cdfid, rayidxvarid, '_FillValue', LONG_RANGE_EDGE

; Tc channel names array variable

Tcnamevarid = ncdf_vardef(cdfid, 'Tc_names', [Tblenid,Tbdimid], /char)
ncdf_attput, cdfid, Tcnamevarid, 'long_name', 'Tc channel names'

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
ncdf_varput, cdfid, sitevarid, '----'
ncdf_varput, cdfid, atimevarid, '01-01-1970 00:00:00'
FOR iel = 0,N_ELEMENTS(elev_angles)-1 DO BEGIN
   ncdf_varput, cdfid, agvtimevarid, '01-01-1970 00:00:00', OFFSET=[0,iel]
ENDFOR
ncdf_varput, cdfid, vnversvarid, GEO_MATCH_NC_FILE_VERSION
ncdf_varput, cdfid, TbNamesid, Tc_channel_names
;
ncdf_close, cdfid
;
GOTO, normalExit

versionOnly:
return, "NoGeoMatchFile"

normalExit:
return, geo_match_nc_file

end
