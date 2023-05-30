;+
; Copyright © 2013, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;
;-------------------------------------------------------------------------------
;
; gen_dpr_geo_match_netcdf_v7.pro    Bob Morris, GPM GV (SAIC)    June 2013
;
; DESCRIPTION:
; Using the "special values" parameters in the 'include' file dpr_params_v7.inc,
; the path parameters in environs_v7.inc, and supplied parameters for the filename,
; number of DPR footprints in the matchup, the array of elevation angles in the
; ground radar volume scan, and global variables for the UF data field used for
; GR reflectivity, the DPR scan type (HS, FS) and the DPR product version,
; creates an empty DPR/GR matchup netCDF file in directory OUTDIR.
;
; The input file name supplied is expected to be a complete file basename and
; to contain fields for YYMMDD, the GPM orbit number, and the ID of the ground
; radar site, as well as the '.nc' file extension.  No checking of the file name
; pre-existence, uniqueness, or conformance is performed in this module.
;
; HISTORY:
; 06/25/2013 by Bob Morris, GPM GV (SAIC)
;  - Created from gen_geo_match_netcdf.pro.
; 07/11/2013 by Bob Morris, GPM GV (SAIC)
;  - Fixed logic in identifying origXXXFileName so that UF file name would not
;    be missed if one/more of the DPR file names was set as "no_XXX_file".
; 7/18/13 by Bob Morris, GPM GV (SAIC)
;  - Added GR rainrate Mean/StdDev/Max variables and presence flags.
; 1/21/14 by Bob Morris, GPM GV (SAIC)
;  - Changed data type of 'DPR_Version' from Short to Character to match version
;    specification for GPM (e.g., "V01A").
; 4/4/14 by Bob Morris, GPM GV (SAIC)
;  - Added GR Dual-pol Zdr, Kdp, RHOhv, HID, Dzero, and Nw Mean/StdDev/Max
;    variables, along with their presence flags and UF IDs.
;  - Added capability to pass UF field IDs for GR Z and dual-pol. fields
;    in a structure in the gv_UF_field parameter for writing out as individual
;    global variables, while retaining the legacy bahavior of passing only the
;    UF ID for the Z field as a STRING in gv_UF_field.
;  - Dropping the have_XXX flag variables for all Max and StdDev fields.
;  - Added siteID string as a mandatory parameter since we allow other than
;    4-character GR site IDs now.
;  - Replaced single variable rayIndex with separate scanNum and rayNum.
;  - Renamed n_gv_rejected to n_gr_z_rejected; renamed all other
;    n_gv_XXX_rejected to n_gr_XXX_rejected; renamed n_meas_z_rejected to
;    n_dpr_meas_z_rejected; n_corr_z_rejected to n_dpr_corr_z_rejected;
;    n_corr_r_rejected to n_dpr_corr_r_rejected.  Renamed GR_DP_XXX variables
;    to GR_XXX, dropping the '_DP', and added '_' between XXX and StdDev and
;    between XXX and Max for all XXXStdDev and XXXMax variable names, i.e.,
;    GR_DP_XXXMax renamed to GR_XXX_Max.
;  - Modified the filename checks to use STRMATCH on expected patterns and to
;    report errors in case of messed up dprgrfiles parameter values.
; 6/24/14 by Bob Morris, GPM GV (SAIC)
;  - Added set of have_xxx, xxx, and n_dpr_xxx_rejected variables for DPR Dm
;    and Nw fields taken from the paramDSD variable in the DPR data files.
; 11/04/14 by Bob Morris, GPM GV (SAIC)
;  - Added processing of GR RC and RP rainrate fields for version 1.1 file.
; 12/26/14 by Bob Morris, GPM GV (SAIC)
;  - Added NON_PPS_FILES binary keyword parameter to ignore expected PPS
;    filename convention for GPM product filenames in dprgrfiles array when set.
; 02/27/15 by Bob Morris, GPM GV (SAIC)
;  - Added DPR heightStormTop and piaFinal fields to version 1.1 file.
; 03/23/15 by Bob Morris, GPM GV (SAIC)
;  - Changed data type of scanNum to DOUBLE to handle large scan numbers from
;    full-orbit data files.
; 08/20/15 by Bob Morris, GPM GV (SAIC)
;  - Added processing of GR Dm and N2 dual-pol fields and DPR_decluttered flag
;    variable for version 1.2 file.
; 11/05/15 by Bob Morris, GPM GV (SAIC)
;  - Added GR_blockage variable and its presence flag for version 1.21 file.
; 07/29/16 by Bob Morris, GPM GV (SAIC)
;  - Added DPR epsilon and n_dpr_epsilon_rejected variables and its presence
;    flag for updated version 1.21.
; 12/12/16 by Bob Morris, GPM GV (SAIC)
;  - Changed netCDF type of qualityData from short to long, it is 4 bytes.
; 10/18/17 by Bob Morris, GPM GV (SAIC)
;  - Added the ability to accept filenames for TRMM version 8 2APR and 2BPRTMI
;    files in the dprgrfiles parameter and write them to new global variables
;    PR_2APR_file and PR_2BPRTMI_File.  Left GEO_MATCH_FILE_VERSION at 1.21 for
;    now.
; 8/30/18 by Todd Berendes (UAH)
;    Added new snow equivalent RR fields, changed version to 1.22
; 9/28/20 by Todd Berendes (UAH)
;    Added new GPM integrated PW fields for liquid and solid
;    Modified for GPM V7
; 4/20/22 by Todd Berendes UAH/ITSC
;  - Added new GR liquid and frozen water content fields
; 7/6/22 Todd Berendes UAH/ITSC
;  - Changed zFactorCorrected to zFactorFinal in output netCDF file to match V7 variable name
; 8/15/22 Todd Berendes UAH/ITSC
;  - New V07 variables in DPR, Ku, Ka
;       precipWater, The amount of precipitable water, g/m3
;       flagInversion, Inversion flag
;  - New V07 variables only available for DPR FS scan
;       flagGraupelHail, Graupel or Hail flag
;       flagHail, 0 Hail not detected 1 Hail detected
;       flagHeavyIcePrecip, Flag for heavyIcePrecip
;       mixedPhaseTop, DPR detected top of mixed phase, meters
; 1/4/23 Todd Berendes UAH/ITSC
;  -  Added measuredDFR, finalDFR, nHeavyIcePrecip
;  -  Added airTemperature to all types
;  -  Changed to version 2.3
; 4/11/23 Todd Berendes UAH/ITSC
;  - removed Ground Radar DZERO and N2
;  - added n_gr_precip fields for Nw,Dm,RC,RR,RP,Mw,Mi
; 5/18/23 Todd Berendes UAH/ITSC
;  - added GR_sigmaDm variables

; EMAIL QUESTIONS OR COMMENTS AT:
;       https://pmm.nasa.gov/contact
;
;-------------------------------------------------------------------------------
;-

FUNCTION gen_dpr_geo_match_netcdf_v7, geo_match_nc_file, numpts, elev_angles, $
                                   gv_UF_field, scanType, DPR_vers, siteID, $
                                   dprgrfiles, DECLUTTERED=decluttered, $
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

; 8/30/18 TAB updated version to 1.22 from 1.21
;GEO_MATCH_FILE_VERSION=1.22
; TAB 11/10/20 changed version to 2.0 from 1.22 for additional GPM fields pwatIntegrated_liquid, pwatIntegrated_ice
;GEO_MATCH_FILE_VERSION=2.1
; TAB 6/8/22 changed version to 2.2 from 2.1 for additional freezing level variable
GEO_MATCH_FILE_VERSION=2.2
; TAB 6/8/22 changed version to 2.3 from 2.2 for additional version 7 and DFR variables
;GEO_MATCH_FILE_VERSION=2.3
; TAB 4/5/23 changed version to 2.4 from 2.3 for reprocessed GR files 
GEO_MATCH_FILE_VERSION=2.4

; TAB 6/7/22 
freezing_level_height=-9999. ; defaults to missing height
IF ( N_ELEMENTS(freezing_level) NE 0 ) THEN BEGIN
	freezing_level_height=freezing_level
endif

IF ( N_ELEMENTS(geo_match_vers) NE 0 ) THEN BEGIN
   geo_match_vers = GEO_MATCH_FILE_VERSION
ENDIF

IF ( N_PARAMS() LT 7 ) THEN GOTO, versionOnly

; Create the output dir for the netCDF file, if needed:
OUTDIR = FILE_DIRNAME(geo_match_nc_file)
spawn, 'mkdir -p ' + OUTDIR

cdfid = ncdf_create(geo_match_nc_file, /CLOBBER)

; global variables -- THE FIRST GLOBAL VARIABLE MUST BE 'DPR_Version'
ncdf_attput, cdfid, 'DPR_Version', DPR_vers, /global
ncdf_attput, cdfid, 'DPR_ScanType', scanType, /global
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
nwuf = 'Unspecified'
mwuf = 'Unspecified'
miuf = 'Unspecified'
dmuf = 'Unspecified'

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
                 'NW_ID'  : nwuf = gv_UF_field.NW_ID
                 'MW_ID'  : mwuf = gv_UF_field.MW_ID
                 'MI_ID'  : miuf = gv_UF_field.MI_ID
                 'DM_ID'  : dmuf = gv_UF_field.DM_ID
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
ncdf_attput, cdfid, 'GV_UF_NW_field', nwuf, /global
ncdf_attput, cdfid, 'GV_UF_MW_field', mwuf, /global
ncdf_attput, cdfid, 'GV_UF_MI_field', miuf, /global
ncdf_attput, cdfid, 'GV_UF_DM_field', dmuf, /global

; identify the input file names for their global attributes.  We could just rely
; on each file type being in a fixed order in the array, but let's make things
; complicated and search for patterns

PPS_NAMED = 1 - KEYWORD_SET(non_pps_files)
IF ( N_PARAMS() EQ 8 AND PPS_NAMED EQ 1 ) THEN BEGIN
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

   idxKU = WHERE(STRMATCH(dprgrfiles,'2A*.GPM.Ku*', /FOLD_CASE) EQ 1, countKU)
   if countKU EQ 1 THEN BEGIN
      origKUFileName = STRJOIN(STRTRIM(dprgrfiles[idxKU],2))
      idxfiles[idxKU] = 1
   endif else begin
      idxKU = WHERE(STRPOS(dprgrfiles,'no_2AKU_file') GE 0, countKU)
      if countKU EQ 1 THEN BEGIN
         origKUFileName = ''+STRJOIN(STRTRIM(dprgrfiles[idxKU],2))
         idxfiles[idxKU] = 1
      endif ELSE origKUFileName='no_2AKU_file'
   endelse

   idxKA = WHERE(STRMATCH(dprgrfiles,'2A*.GPM.Ka*', /FOLD_CASE) EQ 1, countKA)
   if countKA EQ 1 THEN BEGIN
      origKAFileName = STRJOIN(STRTRIM(dprgrfiles[idxKA],2))
      idxfiles[idxKA] = 1
   endif else begin
      idxKA = WHERE(STRPOS(dprgrfiles,'no_2AKA_file') GE 0, countKA)
      if countKA EQ 1 THEN BEGIN
         origKAFileName = ''+STRJOIN(STRTRIM(dprgrfiles[idxKA],2))
         idxfiles[idxKA] = 1
      endif ELSE origKAFileName='no_2AKA_file'
   endelse

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

   idxPR = WHERE(STRMATCH(dprgrfiles, '2A*.TRMM.PR*', /FOLD_CASE) EQ 1, countPR)
   if countPR EQ 1 THEN BEGIN
     ; got to strjoin to collapse the degenerate string array to simple string
      origPRFileName = ''+STRJOIN(STRTRIM(dprgrfiles[idxPR],2))
      idxfiles[idxPR] = 1
   endif else begin
      idxPR = WHERE(STRPOS(dprgrfiles,'no_2APR_file') GE 0, countPR)
      if countPR EQ 1 THEN BEGIN
         origPRFileName = ''+STRJOIN(STRTRIM(dprgrfiles[idxPR],2))
         idxfiles[idxPR] = 1
      endif ELSE origPRFileName='no_2APR_file'
   endelse

   idxPRTMI = WHERE(STRMATCH(dprgrfiles, '2B*.TRMM.PRTMI*', /FOLD_CASE) EQ 1, countPRTMI)
   if countPRTMI EQ 1 THEN BEGIN
     ; got to strjoin to collapse the degenerate string array to simple string
      orig2BPRTMIFileName = ''+STRJOIN(STRTRIM(dprgrfiles[idxPRTMI],2))
      idxfiles[idxPRTMI] = 1
   endif else begin
      idxPRTMI = WHERE(STRPOS(dprgrfiles,'no_2BPRTMI_file') GE 0, countPRTMI)
      if countPRTMI EQ 1 THEN BEGIN
         orig2BPRTMIFileName = ''+STRJOIN(STRTRIM(dprgrfiles[idxPRTMI],2))
         idxfiles[idxPRTMI] = 1
      endif ELSE orig2BPRTMIFileName='no_2BPRTMI_file'
   endelse

   idxgr = WHERE(idxfiles EQ 0, countgr)
   if countgr EQ 1 THEN BEGIN
      origGRFileName = STRJOIN(STRTRIM(dprgrfiles[idxgr],2))
      idxfiles[idxgr] = 1
   endif else begin
      origGRFileName='no_1CUF_file'
      message, "Unable to parse dprgrfiles array to find PR/DPR/GR file names."
   endelse

ENDIF ELSE BEGIN
   IF ( PPS_NAMED EQ 1 ) THEN BEGIN
      origDPRFileName='Unspecified'
      origKUFileName='Unspecified'
      origKAFileName='Unspecified'
      origCOMBFileName='Unspecified'
      origGRFileName='Unspecified'
      origPRFileName='Unspecified'
      orig2BPRTMIFileName='Unspecified'
   ENDIF ELSE BEGIN
      ; rely on positions to set file names
      origDPRFileName  = ''+STRJOIN(STRTRIM(dprgrfiles[0],2))
      origKUFileName   = ''+STRJOIN(STRTRIM(dprgrfiles[1],2))
      origKAFileName   = ''+STRJOIN(STRTRIM(dprgrfiles[2],2))
      origCOMBFileName = ''+STRJOIN(STRTRIM(dprgrfiles[3],2))
      origGRFileName   = ''+STRJOIN(STRTRIM(dprgrfiles[4],2))
      origPRFileName   = 'Unspecified'
      orig2BPRTMIFileName = 'Unspecified'
; TAB 12/4/19 This may be a bug in the original, this is a hack for using non-subsetted GPM files with different naming convention
; these filenames are only specified in the old TRMM files
;      origPRFileName   = ''+STRJOIN(STRTRIM(dprgrfiles[5],2))
;      orig2BPRTMIFileName = ''+STRJOIN(STRTRIM(dprgrfiles[6],2))
   ENDELSE
ENDELSE

ncdf_attput, cdfid, 'DPR_2ADPR_file', origDPRFileName, /global
ncdf_attput, cdfid, 'DPR_2AKU_file', origKUFileName, /global
ncdf_attput, cdfid, 'DPR_2AKA_file', origKAFileName, /global
ncdf_attput, cdfid, 'DPR_2BCMB_file', origCOMBFileName, /global
ncdf_attput, cdfid, 'GR_file', origGRFileName, /global
ncdf_attput, cdfid, 'PR_2APR_file', origPRFileName, /global
ncdf_attput, cdfid, 'PR_2BPRTMI_File', orig2BPRTMIFileName, /global

; field dimensions

fpdimid = ncdf_dimdef(cdfid, 'fpdim', numpts)  ; # of DPR footprints within range
eldimid = ncdf_dimdef(cdfid, 'elevationAngle', N_ELEMENTS(elev_angles))
xydimid = ncdf_dimdef(cdfid, 'xydim', 4)  ; for 4 corners of a DPR footprint
hidimid = ncdf_dimdef(cdfid, 'hidim', 15) ; for Hydromet ID Categories

; Elevation Angles coordinate variable

elvarid = ncdf_vardef(cdfid, 'elevationAngle', [eldimid])
ncdf_attput, cdfid, elvarid, 'long_name', $
            'Radar Sweep Elevation Angles'
ncdf_attput, cdfid, elvarid, 'units', 'degrees'

; scalar fields

nscansid = ncdf_vardef(cdfid, 'numScans', /long)
ncdf_attput, cdfid, nscansid, 'long_name', $
             'Number of DPR scans in original datasets'
ncdf_attput, cdfid, nscansid, '_FillValue', LONG(INT_RANGE_EDGE)

nraysid = ncdf_vardef(cdfid, 'numRays', /short)
ncdf_attput, cdfid, nraysid, 'long_name', $
             'Number of DPR rays per scan in original datasets'
ncdf_attput, cdfid, nraysid, '_FillValue', INT_RANGE_EDGE

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

declutteredid = ncdf_vardef(cdfid, 'DPR_decluttered', /short)
ncdf_attput, cdfid, declutteredid, 'long_name', $
             'decluttered flag for DPR volume average data fields'
ncdf_attput, cdfid, declutteredid, '_FillValue', NO_DATA_PRESENT

; Data existence (non-fill) flags for science fields

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

havegvRRvarid = ncdf_vardef(cdfid, 'have_GR_RC_rainrate', /short)
ncdf_attput, cdfid, havegvRRvarid, 'long_name', $
             'data exists flag for GR_RC_rainrate'
ncdf_attput, cdfid, havegvRRvarid, '_FillValue', NO_DATA_PRESENT

havegvRRvarid = ncdf_vardef(cdfid, 'have_GR_RP_rainrate', /short)
ncdf_attput, cdfid, havegvRRvarid, 'long_name', $
             'data exists flag for GR_RP_rainrate'
ncdf_attput, cdfid, havegvRRvarid, '_FillValue', NO_DATA_PRESENT

havegvRRvarid = ncdf_vardef(cdfid, 'have_GR_RR_rainrate', /short)
ncdf_attput, cdfid, havegvRRvarid, 'long_name', $
             'data exists flag for GR_RR_rainrate'
ncdf_attput, cdfid, havegvRRvarid, '_FillValue', NO_DATA_PRESENT

havegvHIDvarid = ncdf_vardef(cdfid, 'have_GR_HID', /short)
ncdf_attput, cdfid, havegvHIDvarid, 'long_name', $
             'data exists flag for GR_HID'
ncdf_attput, cdfid, havegvHIDvarid, '_FillValue', NO_DATA_PRESENT

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

havegvsigmaDMvarid = ncdf_vardef(cdfid, 'have_GR_sigmaDm', /short)
ncdf_attput, cdfid, havegvsigmaDMvarid, 'long_name', $
             'data exists flag for GR_sigmaDm'
ncdf_attput, cdfid, havegvsigmaDMvarid, '_FillValue', NO_DATA_PRESENT

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

havepwatIntegratedvarid = ncdf_vardef(cdfid, 'have_pwatIntegrated', /short)
ncdf_attput, cdfid, havepwatIntegratedvarid, 'long_name', $
             'data exists flag for GPM integrated pw, liquid and ice'
ncdf_attput, cdfid, havepwatIntegratedvarid, '_FillValue', NO_DATA_PRESENT

havedbzrawvarid = ncdf_vardef(cdfid, 'have_ZFactorMeasured', /short)
ncdf_attput, cdfid, havedbzrawvarid, 'long_name', $
             'data exists flag for ZFactorMeasured'
ncdf_attput, cdfid, havedbzrawvarid, '_FillValue', NO_DATA_PRESENT

havedbzvarid = ncdf_vardef(cdfid, 'have_ZFactorFinal', /short)
ncdf_attput, cdfid, havedbzvarid, 'long_name', $
             'data exists flag for ZFactorFinal'
ncdf_attput, cdfid, havedbzvarid, '_FillValue', NO_DATA_PRESENT

haveairtempvarid = ncdf_vardef(cdfid, 'have_airTemperature', /short)
ncdf_attput, cdfid, haveairtempvarid, 'long_name', $
             'data exists flag for airTemperature'
ncdf_attput, cdfid, haveairtempvarid, '_FillValue', NO_DATA_PRESENT

; V07 new variables
have_precipWater_varid = ncdf_vardef(cdfid, 'have_precipWater', /short)
ncdf_attput, cdfid, have_precipWater_varid, 'long_name', $
             'data exists flag for precipWater'
ncdf_attput, cdfid, have_precipWater_varid, '_FillValue', NO_DATA_PRESENT

have_flagInversion_varid = ncdf_vardef(cdfid, 'have_flagInversion', /short)
ncdf_attput, cdfid, have_flagInversion_varid, 'long_name', $
             'data exists flag for flagInversion'
ncdf_attput, cdfid, have_flagInversion_varid, '_FillValue', NO_DATA_PRESENT

; only available for DPR FS scan
have_flagGraupelHail_varid = ncdf_vardef(cdfid, 'have_flagGraupelHail', /short)
ncdf_attput, cdfid, have_flagGraupelHail_varid, 'long_name', $
             'data exists flag for flagGraupelHail'
ncdf_attput, cdfid, have_flagGraupelHail_varid, '_FillValue', NO_DATA_PRESENT

; only available for DPR FS scan
have_flagHail_varid = ncdf_vardef(cdfid, 'have_flagHail', /short)
ncdf_attput, cdfid, have_flagHail_varid, 'long_name', $
             'data exists flag for flagHail'
ncdf_attput, cdfid, have_flagHail_varid, '_FillValue', NO_DATA_PRESENT

; only available for DPR FS scan
have_flagHeavyIcePrecip_varid = ncdf_vardef(cdfid, 'have_flagHeavyIcePrecip', /short)
ncdf_attput, cdfid, have_flagHeavyIcePrecip_varid, 'long_name', $
             'data exists flag for flagHeavyIcePrecip'
ncdf_attput, cdfid, have_flagHeavyIcePrecip_varid, '_FillValue', NO_DATA_PRESENT

; only available for DPR FS scan
have_nHeavyIcePrecip_varid = ncdf_vardef(cdfid, 'have_nHeavyIcePrecip', /short)
ncdf_attput, cdfid, have_nHeavyIcePrecip_varid, 'long_name', $
             'data exists flag for nHeavyIcePrecip'
ncdf_attput, cdfid, have_nHeavyIcePrecip_varid, '_FillValue', NO_DATA_PRESENT

; only available for DPR FS scan
have_mixedPhaseTop_varid = ncdf_vardef(cdfid, 'have_mixedPhaseTop', /short)
ncdf_attput, cdfid, have_mixedPhaseTop_varid, 'long_name', $
             'data exists flag for mixedPhaseTop'
ncdf_attput, cdfid, have_mixedPhaseTop_varid, '_FillValue', NO_DATA_PRESENT

; only available for DPR FS scan
have_measuredDFR_varid = ncdf_vardef(cdfid, 'have_measuredDFR', /short)
ncdf_attput, cdfid, have_measuredDFR_varid, 'long_name', $
             'data exists flag for measuredDFR'
ncdf_attput, cdfid, have_measuredDFR_varid, '_FillValue', NO_DATA_PRESENT

; only available for DPR FS scan
have_finalDFR_varid = ncdf_vardef(cdfid, 'have_finalDFR', /short)
ncdf_attput, cdfid, have_finalDFR_varid, 'long_name', $
             'data exists flag for finalDFR'
ncdf_attput, cdfid, have_finalDFR_varid, '_FillValue', NO_DATA_PRESENT

havepiavarid = ncdf_vardef(cdfid, 'have_piaFinal', /short)
ncdf_attput, cdfid, havepiavarid, 'long_name', $
             'data exists flag for piaFinal'
ncdf_attput, cdfid, havepiavarid, '_FillValue', NO_DATA_PRESENT

havedsdvarid = ncdf_vardef(cdfid, 'have_paramDSD', /short)
ncdf_attput, cdfid, havedsdvarid, 'long_name', $
             'data exists flag for paramDSD variables (Dm and Nw)'
ncdf_attput, cdfid, havedsdvarid, '_FillValue', NO_DATA_PRESENT

haverainvarid = ncdf_vardef(cdfid, 'have_PrecipRate', /short)
ncdf_attput, cdfid, haverainvarid, 'long_name', $
             'data exists flag for PrecipRate'
ncdf_attput, cdfid, haverainvarid, '_FillValue', NO_DATA_PRESENT

haveEpsvarid = ncdf_vardef(cdfid, 'have_Epsilon', /short)
ncdf_attput, cdfid, haveEpsvarid, 'long_name', $
             'data exists flag for DPR Epsilon variable'
ncdf_attput, cdfid, haveEpsvarid, '_FillValue', NO_DATA_PRESENT

havelandoceanvarid = ncdf_vardef(cdfid, 'have_LandSurfaceType', /short)
ncdf_attput, cdfid, havelandoceanvarid, 'long_name', $
             'data exists flag for LandSurfaceType'
ncdf_attput, cdfid, havelandoceanvarid, '_FillValue', NO_DATA_PRESENT

havesfrainvarid = ncdf_vardef(cdfid, 'have_PrecipRateSurface', /short)
ncdf_attput, cdfid, havesfrainvarid, 'long_name', $
             'data exists flag for PrecipRateSurface'
ncdf_attput, cdfid, havesfrainvarid, '_FillValue', NO_DATA_PRESENT

havesfrain_comb_varid = ncdf_vardef(cdfid, 'have_SurfPrecipTotRate', /short)
ncdf_attput, cdfid, havesfrain_comb_varid, 'long_name', $
             'data exists flag for SurfPrecipTotRate'
ncdf_attput, cdfid, havesfrain_comb_varid, '_FillValue', NO_DATA_PRESENT

havestmtopvarid = ncdf_vardef(cdfid, 'have_heightStormTop', /short)
ncdf_attput, cdfid, havestmtopvarid, 'long_name', $
             'data exists flag for heightStormTop'
ncdf_attput, cdfid, havestmtopvarid, '_FillValue', NO_DATA_PRESENT

haveheightZeroDegvarid = ncdf_vardef(cdfid, 'have_heightZeroDeg', /short)
ncdf_attput, cdfid, haveheightZeroDegvarid, 'long_name', $
             'data exists flag for heightZeroDeg'
ncdf_attput, cdfid, haveheightZeroDegvarid, '_FillValue', NO_DATA_PRESENT

havebbvarid = ncdf_vardef(cdfid, 'have_BBheight', /short)
ncdf_attput, cdfid, havebbvarid, 'long_name', 'data exists flag for BBheight'
ncdf_attput, cdfid, havebbvarid, '_FillValue', NO_DATA_PRESENT

havebbsvarid = ncdf_vardef(cdfid, 'have_BBstatus', /short)
ncdf_attput, cdfid, havebbsvarid, 'long_name', 'data exists flag for BBstatus'
ncdf_attput, cdfid, havebbsvarid, '_FillValue', NO_DATA_PRESENT

haveprsvarid = ncdf_vardef(cdfid, 'have_qualityData', /short)
ncdf_attput, cdfid, haveprsvarid, 'long_name', 'data exists flag for qualityData'
ncdf_attput, cdfid, haveprsvarid, '_FillValue', NO_DATA_PRESENT

haverainflagvarid = ncdf_vardef(cdfid, 'have_FlagPrecip', /short)
ncdf_attput, cdfid, haverainflagvarid, 'long_name', $
             'data exists flag for FlagPrecip'
ncdf_attput, cdfid, haverainflagvarid, '_FillValue', NO_DATA_PRESENT

haveraintypevarid = ncdf_vardef(cdfid, 'have_TypePrecip', /short)
ncdf_attput, cdfid, haveraintypevarid, 'long_name', $
             'data exists flag for TypePrecip'
ncdf_attput, cdfid, haveraintypevarid, '_FillValue', NO_DATA_PRESENT

havecltrvarid = ncdf_vardef(cdfid, 'have_clutterStatus', /short)
ncdf_attput, cdfid, havecltrvarid, 'long_name', $
             'data exists flag for clutterStatus'
ncdf_attput, cdfid, havecltrvarid, '_FillValue', NO_DATA_PRESENT


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

dbzgvvarid = ncdf_vardef(cdfid, 'GR_Z', [fpdimid,eldimid])
ncdf_attput, cdfid, dbzgvvarid, 'long_name', 'GV radar QC Reflectivity'
ncdf_attput, cdfid, dbzgvvarid, 'units', 'dBZ'
ncdf_attput, cdfid, dbzgvvarid, '_FillValue', FLOAT_RANGE_EDGE

stddevgvvarid = ncdf_vardef(cdfid, 'GR_Z_StdDev', [fpdimid,eldimid])
ncdf_attput, cdfid, stddevgvvarid, 'long_name', $
             'Standard Deviation of GV radar QC Reflectivity'
ncdf_attput, cdfid, stddevgvvarid, 'units', 'dBZ'
ncdf_attput, cdfid, stddevgvvarid, '_FillValue', FLOAT_RANGE_EDGE

gvmaxvarid = ncdf_vardef(cdfid, 'GR_Z_Max', [fpdimid,eldimid])
ncdf_attput, cdfid, gvmaxvarid, 'long_name', $
             'Sample Maximum GV radar QC Reflectivity'
ncdf_attput, cdfid, gvmaxvarid, 'units', 'dBZ'
ncdf_attput, cdfid, gvmaxvarid, '_FillValue', FLOAT_RANGE_EDGE

gvZDRvarid = ncdf_vardef(cdfid, 'GR_Zdr', [fpdimid,eldimid])
ncdf_attput, cdfid, gvZDRvarid, 'long_name', 'DP Differential Reflectivity'
ncdf_attput, cdfid, gvZDRvarid, 'units', 'dB'
ncdf_attput, cdfid, gvZDRvarid, '_FillValue', FLOAT_RANGE_EDGE

gvZDRstddevvarid = ncdf_vardef(cdfid, 'GR_Zdr_StdDev', [fpdimid,eldimid])
ncdf_attput, cdfid, gvZDRstddevvarid, 'long_name', $
             'Standard Deviation of DP Differential Reflectivity'
ncdf_attput, cdfid, gvZDRstddevvarid, 'units', 'dB'
ncdf_attput, cdfid, gvZDRstddevvarid, '_FillValue', FLOAT_RANGE_EDGE

gvZDRmaxvarid = ncdf_vardef(cdfid, 'GR_Zdr_Max', [fpdimid,eldimid])
ncdf_attput, cdfid, gvZDRmaxvarid, 'long_name', $
             'Sample Maximum DP Differential Reflectivity'
ncdf_attput, cdfid, gvZDRmaxvarid, 'units', 'dB'
ncdf_attput, cdfid, gvZDRmaxvarid, '_FillValue', FLOAT_RANGE_EDGE

gvKdpvarid = ncdf_vardef(cdfid, 'GR_Kdp', [fpdimid,eldimid])
ncdf_attput, cdfid, gvKdpvarid, 'long_name', 'DP Specific Differential Phase'
ncdf_attput, cdfid, gvKdpvarid, 'units', 'deg/km'
ncdf_attput, cdfid, gvKdpvarid, '_FillValue', FLOAT_RANGE_EDGE

gvKdpstddevvarid = ncdf_vardef(cdfid, 'GR_Kdp_StdDev', [fpdimid,eldimid])
ncdf_attput, cdfid, gvKdpstddevvarid, 'long_name', $
             'Standard Deviation of DP Specific Differential Phase'
ncdf_attput, cdfid, gvKdpstddevvarid, 'units', 'deg/km'
ncdf_attput, cdfid, gvKdpstddevvarid, '_FillValue', FLOAT_RANGE_EDGE

gvKdpmaxvarid = ncdf_vardef(cdfid, 'GR_Kdp_Max', [fpdimid,eldimid])
ncdf_attput, cdfid, gvKdpmaxvarid, 'long_name', $
             'Sample Maximum DP Specific Differential Phase'
ncdf_attput, cdfid, gvKdpmaxvarid, 'units', 'deg/km'
ncdf_attput, cdfid, gvKdpmaxvarid, '_FillValue', FLOAT_RANGE_EDGE

gvRHOHVvarid = ncdf_vardef(cdfid, 'GR_RHOhv', [fpdimid,eldimid])
ncdf_attput, cdfid, gvRHOHVvarid, 'long_name', 'DP Co-Polar Correlation Coefficient'
ncdf_attput, cdfid, gvRHOHVvarid, 'units', 'Dimensionless'
ncdf_attput, cdfid, gvRHOHVvarid, '_FillValue', FLOAT_RANGE_EDGE

gvRHOHVstddevvarid = ncdf_vardef(cdfid, 'GR_RHOhv_StdDev', [fpdimid,eldimid])
ncdf_attput, cdfid, gvRHOHVstddevvarid, 'long_name', $
             'Standard Deviation of DP Co-Polar Correlation Coefficient'
ncdf_attput, cdfid, gvRHOHVstddevvarid, 'units', 'Dimensionless'
ncdf_attput, cdfid, gvRHOHVstddevvarid, '_FillValue', FLOAT_RANGE_EDGE

gvRHOHVmaxvarid = ncdf_vardef(cdfid, 'GR_RHOhv_Max', [fpdimid,eldimid])
ncdf_attput, cdfid, gvRHOHVmaxvarid, 'long_name', $
             'Sample Maximum DP Co-Polar Correlation Coefficient'
ncdf_attput, cdfid, gvRHOHVmaxvarid, 'units', 'Dimensionless'
ncdf_attput, cdfid, gvRHOHVmaxvarid, '_FillValue', FLOAT_RANGE_EDGE

gvRCvarid = ncdf_vardef(cdfid, 'GR_RC_rainrate', [fpdimid,eldimid])
ncdf_attput, cdfid, gvRCvarid, 'long_name', 'GV radar Cifelli algorithm Rainrate'
ncdf_attput, cdfid, gvRCvarid, 'units', 'mm/h'
ncdf_attput, cdfid, gvRCvarid, '_FillValue', FLOAT_RANGE_EDGE

stddevgvRCvarid = ncdf_vardef(cdfid, 'GR_RC_rainrate_StdDev', [fpdimid,eldimid])
ncdf_attput, cdfid, stddevgvRCvarid, 'long_name', $
             'Standard Deviation of GV radar Cifelli algorithm Rainrate'
ncdf_attput, cdfid, stddevgvRCvarid, 'units', 'mm/h'
ncdf_attput, cdfid, stddevgvRCvarid, '_FillValue', FLOAT_RANGE_EDGE

gvmaxRCvarid = ncdf_vardef(cdfid, 'GR_RC_rainrate_Max', [fpdimid,eldimid])
ncdf_attput, cdfid, gvmaxRCvarid, 'long_name', $
             'Sample Maximum GV radar Cifelli algorithm Rainrate'
ncdf_attput, cdfid, gvmaxRCvarid, 'units', 'mm/h'
ncdf_attput, cdfid, gvmaxRCvarid, '_FillValue', FLOAT_RANGE_EDGE

gvRPvarid = ncdf_vardef(cdfid, 'GR_RP_rainrate', [fpdimid,eldimid])
ncdf_attput, cdfid, gvRPvarid, 'long_name', 'GV radar Pol Z-R Rainrate'
ncdf_attput, cdfid, gvRPvarid, 'units', 'mm/h'
ncdf_attput, cdfid, gvRPvarid, '_FillValue', FLOAT_RANGE_EDGE

stddevgvRPvarid = ncdf_vardef(cdfid, 'GR_RP_rainrate_StdDev', [fpdimid,eldimid])
ncdf_attput, cdfid, stddevgvRPvarid, 'long_name', $
             'Standard Deviation of GV radar Pol Z-R Rainrate'
ncdf_attput, cdfid, stddevgvRPvarid, 'units', 'mm/h'
ncdf_attput, cdfid, stddevgvRPvarid, '_FillValue', FLOAT_RANGE_EDGE

gvmaxRPvarid = ncdf_vardef(cdfid, 'GR_RP_rainrate_Max', [fpdimid,eldimid])
ncdf_attput, cdfid, gvmaxRPvarid, 'long_name', $
             'Sample Maximum GV radar Pol Z-R Rainrate'
ncdf_attput, cdfid, gvmaxRPvarid, 'units', 'mm/h'
ncdf_attput, cdfid, gvmaxRPvarid, '_FillValue', FLOAT_RANGE_EDGE

gvRRvarid = ncdf_vardef(cdfid, 'GR_RR_rainrate', [fpdimid,eldimid])
ncdf_attput, cdfid, gvRRvarid, 'long_name', 'GV radar DROPS Rainrate'
ncdf_attput, cdfid, gvRRvarid, 'units', 'mm/h'
ncdf_attput, cdfid, gvRRvarid, '_FillValue', FLOAT_RANGE_EDGE

stddevgvRRvarid = ncdf_vardef(cdfid, 'GR_RR_rainrate_StdDev', [fpdimid,eldimid])
ncdf_attput, cdfid, stddevgvRRvarid, 'long_name', $
             'Standard Deviation of GV radar DROPS Rainrate'
ncdf_attput, cdfid, stddevgvRRvarid, 'units', 'mm/h'
ncdf_attput, cdfid, stddevgvRRvarid, '_FillValue', FLOAT_RANGE_EDGE

gvmaxRRvarid = ncdf_vardef(cdfid, 'GR_RR_rainrate_Max', [fpdimid,eldimid])
ncdf_attput, cdfid, gvmaxRRvarid, 'long_name', $
             'Sample Maximum GV radar DROPS Rainrate'
ncdf_attput, cdfid, gvmaxRRvarid, 'units', 'mm/h'
ncdf_attput, cdfid, gvmaxRRvarid, '_FillValue', FLOAT_RANGE_EDGE

gvHIDvarid = ncdf_vardef(cdfid, 'GR_HID', [hidimid,fpdimid,eldimid], /short)
ncdf_attput, cdfid, gvHIDvarid, 'long_name', 'DP Hydrometeor Identification'
ncdf_attput, cdfid, gvHIDvarid, 'units', 'Categorical'
ncdf_attput, cdfid, gvHIDvarid, '_FillValue', INT_RANGE_EDGE

gvNWvarid = ncdf_vardef(cdfid, 'GR_Nw', [fpdimid,eldimid])
ncdf_attput, cdfid, gvNWvarid, 'long_name', 'DP Normalized Intercept Parameter'
ncdf_attput, cdfid, gvNWvarid, 'units', '1/(mm*m^3)'
ncdf_attput, cdfid, gvNWvarid, '_FillValue', FLOAT_RANGE_EDGE

gvNWstddevvarid = ncdf_vardef(cdfid, 'GR_Nw_StdDev', [fpdimid,eldimid])
ncdf_attput, cdfid, gvNWstddevvarid, 'long_name', $
             'Standard Deviation of DP Normalized Intercept Parameter'
ncdf_attput, cdfid, gvNWstddevvarid, 'units', '1/(mm*m^3)'
ncdf_attput, cdfid, gvNWstddevvarid, '_FillValue', FLOAT_RANGE_EDGE

gvNWmaxvarid = ncdf_vardef(cdfid, 'GR_Nw_Max', [fpdimid,eldimid])
ncdf_attput, cdfid, gvNWmaxvarid, 'long_name', $
             'Sample Maximum DP Normalized Intercept Parameter'
ncdf_attput, cdfid, gvNWmaxvarid, 'units', '1/(mm*m^3)'
ncdf_attput, cdfid, gvNWmaxvarid, '_FillValue', FLOAT_RANGE_EDGE

gvMWvarid = ncdf_vardef(cdfid, 'GR_liquidWaterContent', [fpdimid,eldimid])
ncdf_attput, cdfid, gvMWvarid, 'long_name', 'liquid water mass'
ncdf_attput, cdfid, gvMWvarid, 'units', 'kg/m^3'
ncdf_attput, cdfid, gvMWvarid, '_FillValue', FLOAT_RANGE_EDGE

gvMWstddevvarid = ncdf_vardef(cdfid, 'GR_liquidWaterContent_StdDev', [fpdimid,eldimid])
ncdf_attput, cdfid, gvMWstddevvarid, 'long_name', 'Standard Deviation of liquid water mass'
ncdf_attput, cdfid, gvMWstddevvarid, 'units', 'kg/m^3'
ncdf_attput, cdfid, gvMWstddevvarid, '_FillValue', FLOAT_RANGE_EDGE

gvMWmaxvarid = ncdf_vardef(cdfid, 'GR_liquidWaterContent_Max', [fpdimid,eldimid])
ncdf_attput, cdfid, gvMWmaxvarid, 'long_name', 'Sample Maximum of liquid water mass'
ncdf_attput, cdfid, gvMWmaxvarid, 'units', 'kg/m^3'
ncdf_attput, cdfid, gvMWmaxvarid, '_FillValue', FLOAT_RANGE_EDGE

gvMIvarid = ncdf_vardef(cdfid, 'GR_frozenWaterContent', [fpdimid,eldimid])
ncdf_attput, cdfid, gvMIvarid, 'long_name', 'frozen water mass'
ncdf_attput, cdfid, gvMIvarid, 'units', 'kg/m^3'
ncdf_attput, cdfid, gvMIvarid, '_FillValue', FLOAT_RANGE_EDGE

gvMIstddevvarid = ncdf_vardef(cdfid, 'GR_frozenWaterContent_StdDev', [fpdimid,eldimid])
ncdf_attput, cdfid, gvMIstddevvarid, 'long_name', 'Standard Deviation of frozen water mass'
ncdf_attput, cdfid, gvMIstddevvarid, 'units', 'kg/m^3'
ncdf_attput, cdfid, gvMIstddevvarid, '_FillValue', FLOAT_RANGE_EDGE

gvMImaxvarid = ncdf_vardef(cdfid, 'GR_frozenWaterContent_Max', [fpdimid,eldimid])
ncdf_attput, cdfid, gvMImaxvarid, 'long_name', 'Sample Maximum of frozen water mass'
ncdf_attput, cdfid, gvMImaxvarid, 'units', 'kg/m^3'
ncdf_attput, cdfid, gvMImaxvarid, '_FillValue', FLOAT_RANGE_EDGE

gvDMvarid = ncdf_vardef(cdfid, 'GR_Dm', [fpdimid,eldimid])
ncdf_attput, cdfid, gvDMvarid, 'long_name', 'DP Retrieved Median Diameter'
ncdf_attput, cdfid, gvDMvarid, 'units', 'mm'
ncdf_attput, cdfid, gvDMvarid, '_FillValue', FLOAT_RANGE_EDGE

gvDMstddevvarid = ncdf_vardef(cdfid, 'GR_Dm_StdDev', [fpdimid,eldimid])
ncdf_attput, cdfid, gvDMstddevvarid, 'long_name', $
             'Standard Deviation of DP Retrieved Median Diameter'
ncdf_attput, cdfid, gvDMstddevvarid, 'units', 'mm'
ncdf_attput, cdfid, gvDMstddevvarid, '_FillValue', FLOAT_RANGE_EDGE

gvDMmaxvarid = ncdf_vardef(cdfid, 'GR_Dm_Max', [fpdimid,eldimid])
ncdf_attput, cdfid, gvDMmaxvarid, 'long_name', $
             'Sample Maximum DP Retrieved Median Diameter'
ncdf_attput, cdfid, gvDMmaxvarid, 'units', 'mm'
ncdf_attput, cdfid, gvDMmaxvarid, '_FillValue', FLOAT_RANGE_EDGE

; TAB 5/18/23 added GR_sigmaDm variables
gvsigmaDMvarid = ncdf_vardef(cdfid, 'GR_sigmaDm', [fpdimid,eldimid])
ncdf_attput, cdfid, gvsigmaDMvarid, 'long_name', 'GR-based DSD mass spectrum standard deviation (Protat et al. 2019)'
ncdf_attput, cdfid, gvsigmaDMvarid, 'units', 'mm'
ncdf_attput, cdfid, gvsigmaDMvarid, '_FillValue', FLOAT_RANGE_EDGE

gvDMstddevvarid = ncdf_vardef(cdfid, 'GR_sigmaDm_StdDev', [fpdimid,eldimid])
ncdf_attput, cdfid, gvsigmaDMstddevvarid, 'long_name', $
             'Standard Deviation of GR-based DSD mass spectrum standard deviation (Protat et al. 2019)'
ncdf_attput, cdfid, gvsigmaDMstddevvarid, 'units', 'mm'
ncdf_attput, cdfid, gvsigmaDMstddevvarid, '_FillValue', FLOAT_RANGE_EDGE

gvDMmaxvarid = ncdf_vardef(cdfid, 'GR_sigmaDm_Max', [fpdimid,eldimid])
ncdf_attput, cdfid, gvsigmaDMmaxvarid, 'long_name', $
             'Sample Maximum of GR-based DSD mass spectrum standard deviation (Protat et al. 2019)'
ncdf_attput, cdfid, gvsigmaDMmaxvarid, 'units', 'mm'
ncdf_attput, cdfid, gvsigmaDMmaxvarid, '_FillValue', FLOAT_RANGE_EDGE

BLKvarid = ncdf_vardef(cdfid, 'GR_blockage', [fpdimid,eldimid])
ncdf_attput, cdfid, BLKvarid, 'long_name', $
             'ground radar blockage fraction'
ncdf_attput, cdfid, BLKvarid, '_FillValue', FLOAT_RANGE_EDGE


; TAB 8/27/18 added new variables for snowfall water equivalent rate in the VN data using one of 
; the new polarimetric relationships suggested by Bukocvic et al (2017)

;***********  
   SWEDPvarid = ncdf_vardef(cdfid, 'GR_SWEDP', [fpdimid,eldimid])
   ncdf_attput, cdfid, SWEDPvarid, 'long_name', 'GV snowfall water equivalent rate, Bukocvic et al (2017)'
   ncdf_attput, cdfid, SWEDPvarid, 'units', 'mm/h'
   ncdf_attput, cdfid, SWEDPvarid, '_FillValue', FLOAT_RANGE_EDGE

   stddevgvSWEDPvarid = ncdf_vardef(cdfid, 'GR_SWEDP_StdDev', [fpdimid,eldimid])
   ncdf_attput, cdfid, stddevgvSWEDPvarid, 'long_name', $
             'Standard Deviation of GV snowfall water equivalent rate, Bukocvic et al (2017)'
   ncdf_attput, cdfid, stddevgvSWEDPvarid, 'units', 'mm/h'
   ncdf_attput, cdfid, stddevgvSWEDPvarid, '_FillValue', FLOAT_RANGE_EDGE

   gvmaxSWEDPvarid = ncdf_vardef(cdfid, 'GR_SWEDP_Max', [fpdimid,eldimid])
   ncdf_attput, cdfid, gvmaxSWEDPvarid, 'long_name', $
             'Sample Maximum GV snowfall water equivalent rate, Bukocvic et al (2017)'
   ncdf_attput, cdfid, gvmaxSWEDPvarid, 'units', 'mm/h'
   ncdf_attput, cdfid, gvmaxSWEDPvarid, '_FillValue', FLOAT_RANGE_EDGE
   
   gv_swedp_rejvarid = ncdf_vardef(cdfid, 'n_gr_swedp_rejected', [fpdimid,eldimid], /short)
   ncdf_attput, cdfid, gv_swedp_rejvarid, 'long_name', $
             'number of bins below rain_min in GR_SWEDP average'
   ncdf_attput, cdfid, gv_swedp_rejvarid, '_FillValue', INT_RANGE_EDGE
   
   SWE25varid = ncdf_vardef(cdfid, 'GR_SWE25', [fpdimid,eldimid])
   ncdf_attput, cdfid, SWE25varid, 'long_name', 'GV snowfall water equivalent rate, PQPE conditional quantiles 25%'
   ncdf_attput, cdfid, SWE25varid, 'units', 'mm/h'
   ncdf_attput, cdfid, SWE25varid, '_FillValue', FLOAT_RANGE_EDGE

   stddevgvSWE25varid = ncdf_vardef(cdfid, 'GR_SWE25_StdDev', [fpdimid,eldimid])
   ncdf_attput, cdfid, stddevgvSWE25varid, 'long_name', $
             'Standard Deviation of GV snowfall water equivalent rate, PQPE conditional quantiles 25%'
   ncdf_attput, cdfid, stddevgvSWE25varid, 'units', 'mm/h'
   ncdf_attput, cdfid, stddevgvSWE25varid, '_FillValue', FLOAT_RANGE_EDGE

   gvmaxSWE25varid = ncdf_vardef(cdfid, 'GR_SWE25_Max', [fpdimid,eldimid])
   ncdf_attput, cdfid, gvmaxSWE25varid, 'long_name', $
             'Sample Maximum GV snowfall water equivalent rate, PQPE conditional quantiles 25%'
   ncdf_attput, cdfid, gvmaxSWE25varid, 'units', 'mm/h'
   ncdf_attput, cdfid, gvmaxSWE25varid, '_FillValue', FLOAT_RANGE_EDGE
   
   gv_SWE25_rejvarid = ncdf_vardef(cdfid, 'n_gr_swe25_rejected', [fpdimid,eldimid], /short)
   ncdf_attput, cdfid, gv_SWE25_rejvarid, 'long_name', $
             'number of bins below rain_min in GR_SWE25 average'
   ncdf_attput, cdfid, gv_SWE25_rejvarid, '_FillValue', INT_RANGE_EDGE

   SWE50varid = ncdf_vardef(cdfid, 'GR_SWE50', [fpdimid,eldimid])
   ncdf_attput, cdfid, SWE50varid, 'long_name', 'GV snowfall water equivalent rate, PQPE conditional quantiles 50%'
   ncdf_attput, cdfid, SWE50varid, 'units', 'mm/h'
   ncdf_attput, cdfid, SWE50varid, '_FillValue', FLOAT_RANGE_EDGE

   stddevgvSWE50varid = ncdf_vardef(cdfid, 'GR_SWE50_StdDev', [fpdimid,eldimid])
   ncdf_attput, cdfid, stddevgvSWE50varid, 'long_name', $
             'Standard Deviation of GV snowfall water equivalent rate, PQPE conditional quantiles 50%'
   ncdf_attput, cdfid, stddevgvSWE50varid, 'units', 'mm/h'
   ncdf_attput, cdfid, stddevgvSWE50varid, '_FillValue', FLOAT_RANGE_EDGE

   gvmaxSWE50varid = ncdf_vardef(cdfid, 'GR_SWE50_Max', [fpdimid,eldimid])
   ncdf_attput, cdfid, gvmaxSWE50varid, 'long_name', $
             'Sample Maximum GV snowfall water equivalent rate, PQPE conditional quantiles 50%'
   ncdf_attput, cdfid, gvmaxSWE50varid, 'units', 'mm/h'
   ncdf_attput, cdfid, gvmaxSWE50varid, '_FillValue', FLOAT_RANGE_EDGE
   
   gv_SWE50_rejvarid = ncdf_vardef(cdfid, 'n_gr_swe50_rejected', [fpdimid,eldimid], /short)
   ncdf_attput, cdfid, gv_SWE50_rejvarid, 'long_name', $
             'number of bins below rain_min in GR_SWE50 average'
   ncdf_attput, cdfid, gv_SWE50_rejvarid, '_FillValue', INT_RANGE_EDGE

   SWE75varid = ncdf_vardef(cdfid, 'GR_SWE75', [fpdimid,eldimid])
   ncdf_attput, cdfid, SWE75varid, 'long_name', 'GV snowfall water equivalent rate, PQPE conditional quantiles 75%'
   ncdf_attput, cdfid, SWE75varid, 'units', 'mm/h'
   ncdf_attput, cdfid, SWE75varid, '_FillValue', FLOAT_RANGE_EDGE

   stddevgvSWE75varid = ncdf_vardef(cdfid, 'GR_SWE75_StdDev', [fpdimid,eldimid])
   ncdf_attput, cdfid, stddevgvSWE75varid, 'long_name', $
             'Standard Deviation of GV snowfall water equivalent rate, PQPE conditional quantiles 75%'
   ncdf_attput, cdfid, stddevgvSWE75varid, 'units', 'mm/h'
   ncdf_attput, cdfid, stddevgvSWE75varid, '_FillValue', FLOAT_RANGE_EDGE

   gvmaxSWE75varid = ncdf_vardef(cdfid, 'GR_SWE75_Max', [fpdimid,eldimid])
   ncdf_attput, cdfid, gvmaxSWE75varid, 'long_name', $
             'Sample Maximum GV snowfall water equivalent rate, PQPE conditional quantiles 75%'
   ncdf_attput, cdfid, gvmaxSWE75varid, 'units', 'mm/h'
   ncdf_attput, cdfid, gvmaxSWE75varid, '_FillValue', FLOAT_RANGE_EDGE
   
   gv_SWE75_rejvarid = ncdf_vardef(cdfid, 'n_gr_swe75_rejected', [fpdimid,eldimid], /short)
   ncdf_attput, cdfid, gv_SWE75_rejvarid, 'long_name', $
             'number of bins below rain_min in GR_SWE75 average'
   ncdf_attput, cdfid, gv_SWE75_rejvarid, '_FillValue', INT_RANGE_EDGE

   SWEMQTvarid = ncdf_vardef(cdfid, 'GR_SWEMQT', [fpdimid,eldimid])
   ncdf_attput, cdfid, SWEMQTvarid, 'long_name', 'GV snowfall water equivalent rate, Marquette relationship'
   ncdf_attput, cdfid, SWEMQTvarid, 'units', 'mm/h'
   ncdf_attput, cdfid, SWEMQTvarid, '_FillValue', FLOAT_RANGE_EDGE

   stddevgvSWEMQTvarid = ncdf_vardef(cdfid, 'GR_SWEMQT_StdDev', [fpdimid,eldimid])
   ncdf_attput, cdfid, stddevgvSWEMQTvarid, 'long_name', $
             'Standard Deviation of GV snowfall water equivalent rate, Marquette relationship'
   ncdf_attput, cdfid, stddevgvSWEMQTvarid, 'units', 'mm/h'
   ncdf_attput, cdfid, stddevgvSWEMQTvarid, '_FillValue', FLOAT_RANGE_EDGE

   gvmaxSWEMQTvarid = ncdf_vardef(cdfid, 'GR_SWEMQT_Max', [fpdimid,eldimid])
   ncdf_attput, cdfid, gvmaxSWEMQTvarid, 'long_name', $
             'Sample Maximum GV snowfall water equivalent rate, Marquette relationship'
   ncdf_attput, cdfid, gvmaxSWEMQTvarid, 'units', 'mm/h'
   ncdf_attput, cdfid, gvmaxSWEMQTvarid, '_FillValue', FLOAT_RANGE_EDGE
   
   gv_SWEMQT_rejvarid = ncdf_vardef(cdfid, 'n_gr_swemqt_rejected', [fpdimid,eldimid], /short)
   ncdf_attput, cdfid, gv_SWEMQT_rejvarid, 'long_name', $
             'number of bins below rain_min in GR_SWEMQT average'
   ncdf_attput, cdfid, gv_SWEMQT_rejvarid, '_FillValue', INT_RANGE_EDGE

   SWEMRMSvarid = ncdf_vardef(cdfid, 'GR_SWEMRMS', [fpdimid,eldimid])
   ncdf_attput, cdfid, SWEMRMSvarid, 'long_name', 'GV snowfall water equivalent rate, MRMS relationship'
   ncdf_attput, cdfid, SWEMRMSvarid, 'units', 'mm/h'
   ncdf_attput, cdfid, SWEMRMSvarid, '_FillValue', FLOAT_RANGE_EDGE

   stddevgvSWEMRMSvarid = ncdf_vardef(cdfid, 'GR_SWEMRMS_StdDev', [fpdimid,eldimid])
   ncdf_attput, cdfid, stddevgvSWEMRMSvarid, 'long_name', $
             'Standard Deviation of GV snowfall water equivalent rate, MRMS relationship'
   ncdf_attput, cdfid, stddevgvSWEMRMSvarid, 'units', 'mm/h'
   ncdf_attput, cdfid, stddevgvSWEMRMSvarid, '_FillValue', FLOAT_RANGE_EDGE

   gvmaxSWEMRMSvarid = ncdf_vardef(cdfid, 'GR_SWEMRMS_Max', [fpdimid,eldimid])
   ncdf_attput, cdfid, gvmaxSWEMRMSvarid, 'long_name', $
             'Sample Maximum GV snowfall water equivalent rate, MRMS relationship'
   ncdf_attput, cdfid, gvmaxSWEMRMSvarid, 'units', 'mm/h'
   ncdf_attput, cdfid, gvmaxSWEMRMSvarid, '_FillValue', FLOAT_RANGE_EDGE
   
   gv_SWEMRMS_rejvarid = ncdf_vardef(cdfid, 'n_gr_swemrms_rejected', [fpdimid,eldimid], /short)
   ncdf_attput, cdfid, gv_SWEMRMS_rejvarid, 'long_name', $
             'number of bins below rain_min in GR_SWEMRMS average'
   ncdf_attput, cdfid, gv_SWEMRMS_rejvarid, '_FillValue', INT_RANGE_EDGE

;*******************

dbzrawvarid = ncdf_vardef(cdfid, 'ZFactorMeasured', [fpdimid,eldimid])
ncdf_attput, cdfid, dbzrawvarid, 'long_name', 'DPR Uncorrected Reflectivity'
ncdf_attput, cdfid, dbzrawvarid, 'units', 'dBZ'
ncdf_attput, cdfid, dbzrawvarid, '_FillValue', FLOAT_RANGE_EDGE

dbzvarid = ncdf_vardef(cdfid, 'ZFactorFinal', [fpdimid,eldimid])
ncdf_attput, cdfid, dbzvarid, 'long_name', $
             'DPR Attenuation-corrected Reflectivity'
ncdf_attput, cdfid, dbzvarid, 'units', 'dBZ'
ncdf_attput, cdfid, dbzvarid, '_FillValue', FLOAT_RANGE_EDGE

airtempvarid = ncdf_vardef(cdfid, 'airTemperature', [fpdimid,eldimid])
ncdf_attput, cdfid, airtempvarid, 'long_name', $
             'DPR Average Air Temperature'
ncdf_attput, cdfid, airtempvarid, 'units', 'K'
ncdf_attput, cdfid, airtempvarid, '_FillValue', FLOAT_RANGE_EDGE

; new V07 variables
precipWater_varid = ncdf_vardef(cdfid, 'precipWater', [fpdimid,eldimid], /float)
ncdf_attput, cdfid, precipWater_varid, 'long_name', $
             'The amount of precipitable water'
ncdf_attput, cdfid, precipWater_varid, 'units', 'g/m3'
ncdf_attput, cdfid, precipWater_varid, '_FillValue', FLOAT_RANGE_EDGE

flagInversion_varid = ncdf_vardef(cdfid, 'flagInversion', [fpdimid], /short)
ncdf_attput, cdfid, flagInversion_varid, 'long_name', $
             'TBD info for flagInversion'
ncdf_attput, cdfid, flagInversion_varid, '_FillValue', NO_DATA_PRESENT

; only available for DPR FS scan
flagGraupelHail_varid = ncdf_vardef(cdfid, 'flagGraupelHail', [fpdimid], /short)
ncdf_attput, cdfid, flagGraupelHail_varid, 'long_name', $
             'Graupel or Hail flag, only available for DPR FS scan'
ncdf_attput, cdfid, flagGraupelHail_varid, '_FillValue', NO_DATA_PRESENT

; only available for DPR FS scan
flagHail_varid = ncdf_vardef(cdfid, 'flagHail', [fpdimid], /short)
ncdf_attput, cdfid, flagHail_varid, 'long_name', $
             '0 Hail not detected 1 Hail detected, only available for DPR FS scan'
ncdf_attput, cdfid, flagHail_varid, '_FillValue', NO_DATA_PRESENT

; only available for DPR FS scan
flagHeavyIcePrecip_varid = ncdf_vardef(cdfid, 'flagHeavyIcePrecip', [fpdimid,eldimid], /short)
ncdf_attput, cdfid, flagHeavyIcePrecip_varid, 'long_name', $
             'Flag for heavyIcePrecip, only available for DPR FS scan'
ncdf_attput, cdfid, flagHeavyIcePrecip_varid, '_FillValue', NO_DATA_PRESENT

; only available for DPR FS scan
nHeavyIcePrecip_varid = ncdf_vardef(cdfid, 'nHeavyIcePrecip', [fpdimid], /short)
ncdf_attput, cdfid, nHeavyIcePrecip_varid, 'long_name', $
             'number of heavyIcePrecip bins, only available for DPR FS scan'
ncdf_attput, cdfid, nHeavyIcePrecip_varid, '_FillValue', NO_DATA_PRESENT

; only available for DPR FS scan
mixedPhaseTop_varid = ncdf_vardef(cdfid, 'mixedPhaseTop', [fpdimid], /float)
ncdf_attput, cdfid, mixedPhaseTop_varid, 'long_name', $
             'DPR detected top of mixed phase, only available for DPR FS scan (MSL)'
ncdf_attput, cdfid, mixedPhaseTop_varid, 'units', 'm'
ncdf_attput, cdfid, mixedPhaseTop_varid, '_FillValue', FLOAT_RANGE_EDGE

; only available for DPR FS scan
measuredDFR_varid = ncdf_vardef(cdfid, 'measuredDFR', [fpdimid,eldimid], /float)
ncdf_attput, cdfid, measuredDFR_varid, 'long_name', $
             'DPR Measured Dual Frequency Ratio (DFR), only available for DPR FS scan'
ncdf_attput, cdfid, measuredDFR_varid, 'units', 'db'
ncdf_attput, cdfid, measuredDFR_varid, '_FillValue', FLOAT_RANGE_EDGE

; only available for DPR FS scan
finalDFR_varid = ncdf_vardef(cdfid, 'finalDFR', [fpdimid,eldimid], /float)
ncdf_attput, cdfid, finalDFR_varid, 'long_name', $
             'DPR Final Dual Frequency Ratio (DFR), only available for DPR FS scan'
ncdf_attput, cdfid, finalDFR_varid, 'units', 'db'
ncdf_attput, cdfid, finalDFR_varid, '_FillValue', FLOAT_RANGE_EDGE

rainvarid = ncdf_vardef(cdfid, 'PrecipRate', [fpdimid,eldimid])
ncdf_attput, cdfid, rainvarid, 'long_name', 'DPR Estimated Rain Rate Profile'
ncdf_attput, cdfid, rainvarid, 'units', 'mm/h'
ncdf_attput, cdfid, rainvarid, '_FillValue', FLOAT_RANGE_EDGE

dmvarid = ncdf_vardef(cdfid, 'Dm', [fpdimid,eldimid])
ncdf_attput, cdfid, dmvarid, 'long_name', 'DPR Dm from paramDSD'
ncdf_attput, cdfid, dmvarid, 'units', 'mm'
ncdf_attput, cdfid, dmvarid, '_FillValue', FLOAT_RANGE_EDGE

nwvarid = ncdf_vardef(cdfid, 'Nw', [fpdimid,eldimid])
ncdf_attput, cdfid, nwvarid, 'long_name', 'DPR Nw from paramDSD'
ncdf_attput, cdfid, nwvarid, 'units', 'dB 1/(mm*m^3)'
ncdf_attput, cdfid, nwvarid, '_FillValue', FLOAT_RANGE_EDGE

epsilonvarid = ncdf_vardef(cdfid, 'Epsilon', [fpdimid,eldimid])
ncdf_attput, cdfid, epsilonvarid, 'long_name', $
            'DPR Epsilon'
ncdf_attput, cdfid, epsilonvarid, '_FillValue', FLOAT_RANGE_EDGE

clutrvarid = ncdf_vardef(cdfid, 'clutterStatus', [fpdimid,eldimid], /short)
ncdf_attput, cdfid, clutrvarid, 'long_name', $
             'Clutter region sample adjustment status'
ncdf_attput, cdfid, clutrvarid, 'units', 'Categorical'
ncdf_attput, cdfid, clutrvarid, '_FillValue', INT_RANGE_EDGE

gvrejvarid = ncdf_vardef(cdfid, 'n_gr_z_rejected', [fpdimid,eldimid], /short)
ncdf_attput, cdfid, gvrejvarid, 'long_name', $
             'number of bins below GR_dBZ_min in GR_Z average'
ncdf_attput, cdfid, gvrejvarid, '_FillValue', INT_RANGE_EDGE

gv_zdr_rejvarid = ncdf_vardef(cdfid, 'n_gr_zdr_rejected', [fpdimid,eldimid], /short)
ncdf_attput, cdfid, gv_zdr_rejvarid, 'long_name', $
             'number of bins with missing Zdr in GR_Zdr average'
ncdf_attput, cdfid, gv_zdr_rejvarid, '_FillValue', INT_RANGE_EDGE

gv_kdp_rejvarid = ncdf_vardef(cdfid, 'n_gr_kdp_rejected', [fpdimid,eldimid], /short)
ncdf_attput, cdfid, gv_kdp_rejvarid, 'long_name', $
             'number of bins with missing Kdp in GR_Kdp average'
ncdf_attput, cdfid, gv_kdp_rejvarid, '_FillValue', INT_RANGE_EDGE

gv_rhohv_rejvarid = ncdf_vardef(cdfid, 'n_gr_rhohv_rejected', [fpdimid,eldimid], /short)
ncdf_attput, cdfid, gv_rhohv_rejvarid, 'long_name', $
             'number of bins with missing RHOhv in GR_RHOhv average'
ncdf_attput, cdfid, gv_rhohv_rejvarid, '_FillValue', INT_RANGE_EDGE

gv_rc_rejvarid = ncdf_vardef(cdfid, 'n_gr_rc_rejected', [fpdimid,eldimid], /short)
ncdf_attput, cdfid, gv_rc_rejvarid, 'long_name', $
             'number of bins below rain_min in GR_RC_rainrate average'
ncdf_attput, cdfid, gv_rc_rejvarid, '_FillValue', INT_RANGE_EDGE

gv_rp_rejvarid = ncdf_vardef(cdfid, 'n_gr_rp_rejected', [fpdimid,eldimid], /short)
ncdf_attput, cdfid, gv_rp_rejvarid, 'long_name', $
             'number of bins below rain_min in GR_RP_rainrate average'
ncdf_attput, cdfid, gv_rp_rejvarid, '_FillValue', INT_RANGE_EDGE

gv_rr_rejvarid = ncdf_vardef(cdfid, 'n_gr_rr_rejected', [fpdimid,eldimid], /short)
ncdf_attput, cdfid, gv_rr_rejvarid, 'long_name', $
             'number of bins below rain_min in GR_RR_rainrate average'
ncdf_attput, cdfid, gv_rr_rejvarid, '_FillValue', INT_RANGE_EDGE

gv_hid_rejvarid = ncdf_vardef(cdfid, 'n_gr_hid_rejected', [fpdimid,eldimid], /short)
ncdf_attput, cdfid, gv_hid_rejvarid, 'long_name', $
             'number of bins with undefined HID in GR_HID histogram'
ncdf_attput, cdfid, gv_hid_rejvarid, '_FillValue', INT_RANGE_EDGE

gv_nw_rejvarid = ncdf_vardef(cdfid, 'n_gr_nw_rejected', [fpdimid,eldimid], /short)
ncdf_attput, cdfid, gv_nw_rejvarid, 'long_name', $
             'number of bins with missing Nw in GR_Nw average'
ncdf_attput, cdfid, gv_nw_rejvarid, '_FillValue', INT_RANGE_EDGE

gv_mw_rejvarid = ncdf_vardef(cdfid, 'n_gr_liquidWaterContent_rejected', [fpdimid,eldimid], /short)
ncdf_attput, cdfid, gv_mw_rejvarid, 'long_name', $
             'number of bins with missing liquidWaterContent in GR_liquidWaterContent average'
ncdf_attput, cdfid, gv_mw_rejvarid, '_FillValue', INT_RANGE_EDGE

gv_mi_rejvarid = ncdf_vardef(cdfid, 'n_gr_frozenWaterContent_rejected', [fpdimid,eldimid], /short)
ncdf_attput, cdfid, gv_mi_rejvarid, 'long_name', $
             'number of bins with missing frozenWaterContent in GR_frozenWaterContent average'
ncdf_attput, cdfid, gv_mi_rejvarid, '_FillValue', INT_RANGE_EDGE

gv_dm_rejvarid = ncdf_vardef(cdfid, 'n_gr_dm_rejected', [fpdimid,eldimid], /short)
ncdf_attput, cdfid, gv_dm_rejvarid, 'long_name', $
             'number of bins with missing Dm in GR_Dm average'
ncdf_attput, cdfid, gv_dm_rejvarid, '_FillValue', INT_RANGE_EDGE

gv_sigmadm_rejvarid = ncdf_vardef(cdfid, 'n_gr_sigmadm_rejected', [fpdimid,eldimid], /short)
ncdf_attput, cdfid, gv_sigmadm_rejvarid, 'long_name', $
             'number of bins with missing Dm in GR_sigmaDm average'
ncdf_attput, cdfid, gv_sigmadm_rejvarid, '_FillValue', INT_RANGE_EDGE

gvexpvarid = ncdf_vardef(cdfid, 'n_gr_expected', [fpdimid,eldimid], /short)
ncdf_attput, cdfid, gvexpvarid, 'long_name', $
             'number of bins in GR_Z average'
ncdf_attput, cdfid, gvexpvarid, '_FillValue', INT_RANGE_EDGE

rawZrejvarid = ncdf_vardef(cdfid, 'n_dpr_meas_z_rejected', [fpdimid,eldimid], /short)
ncdf_attput, cdfid, rawZrejvarid, 'long_name', $
             'number of bins below DPR_dBZ_min in ZFactorMeasured average'
ncdf_attput, cdfid, rawZrejvarid, '_FillValue', INT_RANGE_EDGE

corZrejvarid = ncdf_vardef(cdfid, 'n_dpr_corr_z_rejected', [fpdimid,eldimid], /short)
ncdf_attput, cdfid, corZrejvarid, 'long_name', $
             'number of bins below DPR_dBZ_min in ZFactorFinal average'
ncdf_attput, cdfid, corZrejvarid, '_FillValue', INT_RANGE_EDGE

rainrejvarid = ncdf_vardef(cdfid, 'n_dpr_corr_r_rejected', [fpdimid,eldimid], /short)
ncdf_attput, cdfid, rainrejvarid, 'long_name', $
             'number of bins below rain_min in PrecipRate average'
ncdf_attput, cdfid, rainrejvarid, '_FillValue', INT_RANGE_EDGE

dm_rejvarid = ncdf_vardef(cdfid, 'n_dpr_dm_rejected', [fpdimid,eldimid], /short)
ncdf_attput, cdfid, dm_rejvarid, 'long_name', $
             'number of bins with missing Dm in DPR Dm average'
ncdf_attput, cdfid, dm_rejvarid, '_FillValue', INT_RANGE_EDGE

nw_rejvarid = ncdf_vardef(cdfid, 'n_dpr_nw_rejected', [fpdimid,eldimid], /short)
ncdf_attput, cdfid, nw_rejvarid, 'long_name', $
             'number of bins with missing Nw in DPR Nw average'
ncdf_attput, cdfid, nw_rejvarid, '_FillValue', INT_RANGE_EDGE

epsilonrejvarid = ncdf_vardef(cdfid, 'n_dpr_epsilon_rejected', $
                           [fpdimid,eldimid], /short)
ncdf_attput, cdfid, epsilonrejvarid, 'long_name', $
             'number of bins below 0.0 in Epsilon average'
ncdf_attput, cdfid, epsilonrejvarid, '_FillValue', INT_RANGE_EDGE

gv_nw_n_precip_varid = ncdf_vardef(cdfid, 'n_gr_nw_precip', [fpdimid,eldimid], /short)
ncdf_attput, cdfid, gv_nw_n_precip_varid, 'long_name', $
             'number of bins with precip, including unknown and zero, in GR_Nw average'
ncdf_attput, cdfid, gv_nw_n_precip_varid, '_FillValue', INT_RANGE_EDGE

gv_mw_n_precip_varid = ncdf_vardef(cdfid, 'n_gr_mw_precip', [fpdimid,eldimid], /short)
ncdf_attput, cdfid, gv_mw_n_precip_varid, 'long_name', $
             'number of bins with precip, including unknown and zero, in GR_Mw average'
ncdf_attput, cdfid, gv_mw_n_precip_varid, '_FillValue', INT_RANGE_EDGE

gv_mi_n_precip_varid = ncdf_vardef(cdfid, 'n_gr_mi_precip', [fpdimid,eldimid], /short)
ncdf_attput, cdfid, gv_mi_n_precip_varid, 'long_name', $
             'number of bins with precip, including unknown and zero, in GR_Mi average'
ncdf_attput, cdfid, gv_mi_n_precip_varid, '_FillValue', INT_RANGE_EDGE

gv_dm_n_precip_varid = ncdf_vardef(cdfid, 'n_gr_dm_precip', [fpdimid,eldimid], /short)
ncdf_attput, cdfid, gv_dm_n_precip_varid, 'long_name', $
             'number of bins with precip, including unknown and zero, in GR_Dm average'
ncdf_attput, cdfid, gv_dm_n_precip_varid, '_FillValue', INT_RANGE_EDGE

gv_sigmadm_n_precip_varid = ncdf_vardef(cdfid, 'n_gr_sigmadm_precip', [fpdimid,eldimid], /short)
ncdf_attput, cdfid, gv_sigmadm_n_precip_varid, 'long_name', $
             'number of bins with precip, including unknown and zero, in GR_sigmaDm average'
ncdf_attput, cdfid, gv_sigmadm_n_precip_varid, '_FillValue', INT_RANGE_EDGE

gv_rr_n_precip_varid = ncdf_vardef(cdfid, 'n_gr_rr_precip', [fpdimid,eldimid], /short)
ncdf_attput, cdfid, gv_rr_n_precip_varid, 'long_name', $
             'number of bins with precip, including unknown and zero, in GR_RR average'
ncdf_attput, cdfid, gv_rr_n_precip_varid, '_FillValue', INT_RANGE_EDGE

gv_rc_n_precip_varid = ncdf_vardef(cdfid, 'n_gr_rc_precip', [fpdimid,eldimid], /short)
ncdf_attput, cdfid, gv_rc_n_precip_varid, 'long_name', $
             'number of bins with precip, including unknown and zero, in GR_RC average'
ncdf_attput, cdfid, gv_rc_n_precip_varid, '_FillValue', INT_RANGE_EDGE

gv_rp_n_precip_varid = ncdf_vardef(cdfid, 'n_gr_rp_precip', [fpdimid,eldimid], /short)
ncdf_attput, cdfid, gv_rp_n_precip_varid, 'long_name', $
             'number of bins with precip, including unknown and zero, in GR_RP average'
ncdf_attput, cdfid, gv_rp_n_precip_varid, '_FillValue', INT_RANGE_EDGE

; new V7 
precipWater_rejvarid = ncdf_vardef(cdfid, 'n_dpr_precipWater_rejected', [fpdimid,eldimid], /short)
ncdf_attput, cdfid, precipWater_rejvarid, 'long_name', $
             'number of bins with missing precipWater in DPR precipWater average'
ncdf_attput, cdfid, precipWater_rejvarid, '_FillValue', INT_RANGE_EDGE

airTemp_rejvarid = ncdf_vardef(cdfid, 'n_dpr_airTemperature_rejected', [fpdimid,eldimid], /short)
ncdf_attput, cdfid, airTemp_rejvarid, 'long_name', $
             'number of bins with missing airTemperature in DPR airTemperature average'
ncdf_attput, cdfid, airTemp_rejvarid, '_FillValue', INT_RANGE_EDGE

; only available for DPR FS scan

finalDFR_rejvarid = ncdf_vardef(cdfid, 'n_dpr_final_dfr_rejected', [fpdimid,eldimid], /short)
ncdf_attput, cdfid, finalDFR_rejvarid, 'long_name', $
             'number of bins with missing DPR Final Dual Frequency Ratio (DFR), only available for DPR FS scan'
ncdf_attput, cdfid, finalDFR_rejvarid, '_FillValue', INT_RANGE_EDGE

measDFR_rejvarid = ncdf_vardef(cdfid, 'n_dpr_meas_dfr_rejected', [fpdimid,eldimid], /short)
ncdf_attput, cdfid, measDFR_rejvarid, 'long_name', $
             'number of bins with missing DPR Measured Dual Frequency Ratio (DFR), only available for DPR FS scan'
ncdf_attput, cdfid, measDFR_rejvarid, '_FillValue', INT_RANGE_EDGE


prexpvarid = ncdf_vardef(cdfid, 'n_dpr_expected', [fpdimid,eldimid], /short)
ncdf_attput, cdfid, prexpvarid, 'long_name', 'number of bins in DPR averages'
ncdf_attput, cdfid, prexpvarid, '_FillValue', INT_RANGE_EDGE

; single-level fields

sfclatvarid = ncdf_vardef(cdfid, 'DPRlatitude', [fpdimid])
ncdf_attput, cdfid, sfclatvarid, 'long_name', 'Latitude of DPR surface bin'
ncdf_attput, cdfid, sfclatvarid, 'units', 'degrees North'
ncdf_attput, cdfid, sfclatvarid, '_FillValue', FLOAT_RANGE_EDGE

sfclonvarid = ncdf_vardef(cdfid, 'DPRlongitude', [fpdimid])
ncdf_attput, cdfid, sfclonvarid, 'long_name', 'Longitude of DPR surface bin'
ncdf_attput, cdfid, sfclonvarid, 'units', 'degrees East'
ncdf_attput, cdfid, sfclonvarid, '_FillValue', FLOAT_RANGE_EDGE

piavarid = ncdf_vardef(cdfid, 'piaFinal', [fpdimid])
ncdf_attput, cdfid, piavarid, 'long_name', $
             'DPR path integrated attenuation'
ncdf_attput, cdfid, piavarid, 'units', 'dBZ'
ncdf_attput, cdfid, piavarid, '_FillValue', FLOAT_RANGE_EDGE

landoceanvarid = ncdf_vardef(cdfid, 'LandSurfaceType', [fpdimid], /short)
ncdf_attput, cdfid, landoceanvarid, 'long_name', 'DPR LandSurfaceType'
ncdf_attput, cdfid, landoceanvarid, 'units', 'Categorical'
ncdf_attput, cdfid, landoceanvarid, '_FillValue', INT_RANGE_EDGE

sfrainvarid = ncdf_vardef(cdfid, 'PrecipRateSurface', [fpdimid])
ncdf_attput, cdfid, sfrainvarid, 'long_name', $
             'DPR Near-Surface Precipitation Rate'
ncdf_attput, cdfid, sfrainvarid, 'units', 'mm/h'
ncdf_attput, cdfid, sfrainvarid, '_FillValue', FLOAT_RANGE_EDGE

sfrain_comb_varid = ncdf_vardef(cdfid, 'SurfPrecipTotRate', [fpdimid])
ncdf_attput, cdfid, sfrain_comb_varid, 'long_name', $
            '2B-DPRGMI Near-Surface Estimated Rain Rate'
ncdf_attput, cdfid, sfrain_comb_varid, 'units', 'mm/h'
ncdf_attput, cdfid, sfrain_comb_varid, '_FillValue', FLOAT_RANGE_EDGE

stmtopvarid = ncdf_vardef(cdfid, 'heightStormTop', [fpdimid], /short)
ncdf_attput, cdfid, stmtopvarid, 'long_name', $
             'DPR Estimated Storm Top Height (meters)'
ncdf_attput, cdfid, stmtopvarid, 'units', 'm'
ncdf_attput, cdfid, stmtopvarid, '_FillValue', INT_RANGE_EDGE

bbvarid = ncdf_vardef(cdfid, 'BBheight', [fpdimid])
ncdf_attput, cdfid, bbvarid, 'long_name', $
            'DPR Bright Band Height above MSL'
ncdf_attput, cdfid, bbvarid, 'units', 'm'
ncdf_attput, cdfid, bbvarid, '_FillValue', FLOAT_RANGE_EDGE

bbsvarid = ncdf_vardef(cdfid, 'BBstatus', [fpdimid], /short)
ncdf_attput, cdfid, bbsvarid, 'long_name', $
            'Bright Band Quality'
ncdf_attput, cdfid, bbsvarid, 'units', 'Categorical'
ncdf_attput, cdfid, bbsvarid, '_FillValue', INT_RANGE_EDGE

prsvarid = ncdf_vardef(cdfid, 'qualityData', [fpdimid], /long)
ncdf_attput, cdfid, prsvarid, 'long_name', 'DPR FLG group qualityData'
ncdf_attput, cdfid, prsvarid, 'units', 'Categorical'
ncdf_attput, cdfid, prsvarid, '_FillValue', long(INT_RANGE_EDGE)

rainflagvarid = ncdf_vardef(cdfid, 'FlagPrecip', [fpdimid], /short)
ncdf_attput, cdfid, rainflagvarid, 'long_name', 'DPR FlagPrecip'
ncdf_attput, cdfid, rainflagvarid, 'units', 'Categorical'
ncdf_attput, cdfid, rainflagvarid, '_FillValue', INT_RANGE_EDGE

raintypevarid = ncdf_vardef(cdfid, 'TypePrecip', [fpdimid], /short)
ncdf_attput, cdfid, raintypevarid, 'long_name', $
            'DPR TypePrecip (stratiform/convective/other)'
ncdf_attput, cdfid, raintypevarid, 'units', 'Categorical'
ncdf_attput, cdfid, raintypevarid, '_FillValue', INT_RANGE_EDGE

scanidxvarid = ncdf_vardef(cdfid, 'scanNum', [fpdimid], /long)
ncdf_attput, cdfid, scanidxvarid, 'long_name', $
            'product-relative zero-based array index of DPR scan number'
ncdf_attput, cdfid, scanidxvarid, '_FillValue', LONG(INT_RANGE_EDGE)

rayidxvarid = ncdf_vardef(cdfid, 'rayNum', [fpdimid], /short)
ncdf_attput, cdfid, rayidxvarid, 'long_name', $
            'product-relative zero-based array index of DPR ray number'
ncdf_attput, cdfid, rayidxvarid, '_FillValue', INT_RANGE_EDGE

; TAB 9/28/20 Added new PW fields
;For the precipWaterIntegrated make it two variables in the VN (e.g., pwatIntegrated_liquid, pwatIntegrated_solid):

;    pwatIntegrated_liquid = 1st LS index
;    pwatIntegrated_solid = 2nd LS index
pwatIntegrated_liquidvarid = ncdf_vardef(cdfid, 'pwatIntegrated_liquid', [fpdimid])
ncdf_attput, cdfid, pwatIntegrated_liquidvarid, 'long_name', $
            'Precipitation water vertically integrated'
ncdf_attput, cdfid, pwatIntegrated_liquidvarid, '_FillValue', -9999.9

pwatIntegrated_solidvarid = ncdf_vardef(cdfid, 'pwatIntegrated_solid', [fpdimid])
ncdf_attput, cdfid, pwatIntegrated_solidvarid, 'long_name', $
            'Precipitation water vertically integrated'
ncdf_attput, cdfid, pwatIntegrated_solidvarid, '_FillValue', -9999.9

; TAB 2/16/21 added heightZeroDeg
heightZeroDegvarid = ncdf_vardef(cdfid, 'heightZeroDeg', [fpdimid])
ncdf_attput, cdfid, heightZeroDegvarid, 'long_name', $
            'Height of the level of 0 degree centigrade (msl)'
ncdf_attput, cdfid, heightZeroDegvarid, '_FillValue', -9999.9
ncdf_attput, cdfid, heightZeroDegvarid, 'units', 'meters'


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
ncdf_attput, cdfid, frzlvlvarid, 'long_name', 'Model-based freezing level height MSL'
ncdf_attput, cdfid, frzlvlvarid, 'units', 'km'
ncdf_attput, cdfid, frzlvlvarid, '_FillValue', -9999.
;
ncdf_control, cdfid, /endef
;
ncdf_varput, cdfid, elvarid, elev_angles
ncdf_varput, cdfid, sitevarid, siteID
ncdf_varput, cdfid, atimevarid, '01-01-1970 00:00:00'
DPR_decluttered = KEYWORD_SET(decluttered)
ncdf_varput, cdfid, declutteredid, DPR_decluttered

FOR iel = 0,N_ELEMENTS(elev_angles)-1 DO BEGIN
   ncdf_varput, cdfid, agvtimevarid, '01-01-1970 00:00:00', OFFSET=[0,iel]
ENDFOR
ncdf_varput, cdfid, vnversvarid, GEO_MATCH_FILE_VERSION
ncdf_varput, cdfid, frzlvlvarid, freezing_level_height

ncdf_close, cdfid

GOTO, normalExit

versionOnly:
return, "NoGeoMatchFile"

normalExit:
return, geo_match_nc_file

end
