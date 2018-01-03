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
; gen_geo_match_netcdf.pro    Bob Morris, GPM GV (SAIC)    September 2008
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
; 09/17/2007 by Bob Morris, GPM GV (SAIC)
;  - Created.
; 06/15/2009 by Bob Morris, GPM GV (SAIC)
;  - Pass in fully-qualified pathname to output netCDF file as geo_match_nc_file
;    parameter.  Extract path from this pathname and create it if needed.
; 09/10/2010 by Bob Morris, GPM GV (SAIC)
;  - Add variable 'site_elev' to hold 'siteElev' parameter read out from
;    polar2pr control file.
;  - Document in their long names that topHeight and bottomHeight are above
;    ground level (AGL) heights, and that BBheight is height above MSL.
;  - Changing file definition version to 1.1 to reflect these changes.
; 09/16/2010 by Bob Morris, GPM GV (SAIC)
;  - Corrected 'units' attribute from 'km' to 'm' for BBheight variable.
; 11/11/10 by Bob Morris, GPM GV (SAIC)
;  - Add variables 'threeDreflectStdDev' and 'threeDreflectMax' for GR reflectivity,
;    and 'BBstatus' and 'status' for variables extracted from 2A-23 product.
;  - Hard-code file definition version (now 2.0) within this routine rather than
;    taking value of GEO_MATCH_NC_FILE_VERS from environs.inc
; 11/17/10 by Bob Morris, GPM GV (SAIC)
;  - Referencing "include" file grid_def.inc for DATA_PRESENT, NO_DATA_PRESENT
;    values to initialize have_xxx variables
; 3/18/11 by Bob Morris, GPM GV (SAIC)
;  - Added "function overloading" to query the routine for the matchup netCDF
;    file version (formerly GEO_MATCH_NC_FILE_VERS).
;  - Added prgrfiles parameter and netCDF global attributes to pass an array of
;    the input PR and GR file names and write as global attributes.  Define
;    this new file format as Version 2.1.
; 01/20/12 by Bob Morris, GPM GV (SAIC)
;  - Added note that 'PR_Version' must be the first GLOBAL variable defined in
;    the file.  We now check against this when reading netCDF files to make sure
;    it is the correct type of matchup file.
; 7/18/13 by Bob Morris, GPM GV (SAIC)
;  - Added GR rainrate Mean/StdDev/Max variables and presence flags, and set
;    file version to 2.2.
; 1/27/14 by Bob Morris, GPM GV (SAIC)
;  - Added GR Dual-pol HID, Dzero, and Nw variables and presence flags, and set
;    file version to 2.3.
; 2/7/14 by Bob Morris, GPM GV (SAIC)
;  - Added Max and StdDev variables and presence flags for Dzero and Nw fields.
;  - Added capability to pass UF field IDs for GR Z, rainrate, HID, D0, and Nw
;    in a structure in the gv_UF_field parameter for writing out as individual
;    global variables, while retaining the legacy bahavior of passing only the
;    UF ID for the Z field as a STRING in gv_UF_field.
; 1/27/14 by Bob Morris, GPM GV (SAIC)
;  - Added mean, maximum, and StdDev of Dual-pol variables Zdr, Kdp, and RHOhv,
;    along with their presence flags and UF IDs, for file version 2.3.
; 04/21/2014 by Bob Morris, GPM GV (SAIC)
;  - Set file version to 3.0 for mandatory input parameter and output netCDF
;    file data type changes (documented below).
;  - Added siteID string as a mandatory parameter for file Version 3.0,  since
;    we allow other than 4-character GR site IDs now.
;  - This function now accepts either a short integer or a string value for
;    PR_vers, e.g., 'V07' or integer 7.  If passed a numerical value, it is
;    used as-is as the global variable value.  If given a string value, the
;    matching integer value is determined and written as the PR_vers variable.
;  - Added optional PPS_VERSION parameter to accept a string value with the
;    PPS_Version for GPM-era data products, e.g., 'V06', 'V07'.  If none is
;    given then a value is formatted from the PR_vers_in parameter.
; 04/21/2014 by Bob Morris, GPM GV (SAIC)
;  - Removed the redundant have_XXX_Max and have_XXX_StdDev variables.
;  - Fixed bug in the N_PARAMS count comparison for prgrfiles presence.
; 07/15/2014 by Bob Morris, GPM GV (SAIC)
;  - Renamed all *GR_DP_* variables to *GR_*, removing the "DP_" designators.
; 01/23/2015 by Bob Morris, GPM GV (SAIC)
;  - Added logic to accept string values 6, 7, and 8 as valid PR_vers_in values.
; 02/03/2015 by Bob Morris, GPM GV (SAIC)
;  - Added 2A25 PIA and its presence flag for new version 3.1 matchup file.
;
;-------------------------------------------------------------------------------
;-

FUNCTION gen_geo_match_netcdf, geo_match_nc_file, numpts, elev_angles, $
                               gv_UF_field, PR_vers_in, siteID, prgrfiles, $
                               PPS_VERSION=PPS_Vers_in, $
                               GEO_MATCH_VERS=geo_match_vers

; "Include" file for DATA_PRESENT, NO_DATA_PRESENT
@grid_def.inc
; "Include" files for constants, names, paths, etc.
@environs.inc   ; for file prefixes, netCDF file definition version
@pr_params.inc  ; for the type-specific fill values

GEO_MATCH_FILE_VERSION=3.1

IF ( N_ELEMENTS(geo_match_vers) NE 0 ) THEN BEGIN
   geo_match_vers = GEO_MATCH_FILE_VERSION
ENDIF

IF ( N_PARAMS() LT 5 ) THEN GOTO, versionOnly

; Create the output dir for the netCDF file, if needed:
OUTDIR = FILE_DIRNAME(geo_match_nc_file)
spawn, 'mkdir -p ' + OUTDIR

cdfid = ncdf_create(geo_match_nc_file, /CLOBBER)

; global variables -- THE FIRST GLOBAL VARIABLE MUST BE 'PR_Version'
; -- if given a string for , convert it to a string
s = SIZE(PR_vers_in, /TYPE)

SWITCH s OF
     7 : BEGIN
           IF STRMID(PR_vers_in,0,1) EQ 'V' THEN BEGIN
              CASE STRMID(PR_vers_in,1,2) OF   ; given a STRING, find the matching int
                '06' : PR_vers = 6
                '07' : PR_vers = 7
                '08' : PR_vers = 8
                ELSE : message, PR_vers_in+"Not a recognized TRMM version string, expect V06, V07 or V08"
              ENDCASE
           ENDIF ELSE BEGIN
              CASE PR_vers_in OF   ; given a STRING CHAR, find the matching int
                '6' : PR_vers = 6
                '7' : PR_vers = 7
                '8' : PR_vers = 8
                ELSE : message, PR_vers_in+"Not a recognized TRMM version string, expect 6, 7 or 8"
              ENDCASE
           ENDELSE
           break
         END
     1 :
     2 :
     3 :
     4 :
     5 : 
    12 :
    13 :
    14 :
    15 : begin
           ; handle the integer/floating point types
            PR_vers = PR_vers_in
            break
         end
  ELSE : message, "Illegal type for PR_vers parameter."
ENDSWITCH
    
ncdf_attput, cdfid, 'PR_Version', PR_vers, /global

; optional parameter global variable -- 'PPS_Version'
IF N_ELEMENTS( PPS_vers_in ) EQ 1 THEN BEGIN
   ; -- if given a number, convert it to a string
   s = SIZE(PPS_vers_in, /TYPE)
   SWITCH s OF
        7 : BEGIN
              PPS_vers = PPS_vers_in   ; we were passed a STRING, leave it be
              break
            END
        1 :
        2 :
        3 :
       12 :
       13 :
       14 :
       15 : begin
              ; handle the integer types
               PPS_vers = STRING(PPS_vers_in, FORMAT='(I0)')
               break
            end
        4 :
        5 : begin
              ; handle the floating point types
               PPS_vers = STRING(PPS_vers_in, FORMAT='(F0.1)')
               break
            end
     ELSE : message, "Illegal type for PPS_version parameter."
   ENDSWITCH
ENDIF ELSE PPS_vers="V"+STRING(PR_vers, FORMAT='(I2.2)')
    
ncdf_attput, cdfid, 'PPS_Version', PPS_vers, /global

; determine whether gv_UF_field is a scalar character or a structure, and write
; global values for UF field IDs accordingly

; - first, intialize field IDs as Unspecified
zuf = 'Unspecified'
zdruf = 'Unspecified'
kdpuf = 'Unspecified'
rhohvuf = 'Unspecified'
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
ncdf_attput, cdfid, 'GV_UF_RR_field', rruf, /global
ncdf_attput, cdfid, 'GV_UF_HID_field', hiduf, /global
ncdf_attput, cdfid, 'GV_UF_D0_field', dzerouf, /global
ncdf_attput, cdfid, 'GV_UF_NW_field', nwuf, /global

; identify the input file names for their global attributes
IF ( N_PARAMS() EQ 7 ) THEN BEGIN
   idxfiles = lonarr( N_ELEMENTS(prgrfiles) )
   idx21 = WHERE(STRPOS(prgrfiles,'1C21') GE 0, count21)
   if count21 EQ 1 THEN BEGIN
     ; got to strjoin to collapse the degenerate string array to simple string
      origFile21Name = ''+STRJOIN(STRTRIM(prgrfiles[idx21],2))
      idxfiles[idx21] = 1
   endif ELSE origFile21Name='no_1C21_file'

   idx23 = WHERE(STRPOS(prgrfiles,'2A23') GE 0, count23)
   if count23 EQ 1 THEN BEGIN
      origFile23Name = STRJOIN(STRTRIM(prgrfiles[idx23],2))
      idxfiles[idx23] = 1
   endif  ELSE origFile23Name='no_2A23_file'

   idx25 = WHERE(STRPOS(prgrfiles,'2A25') GE 0, count25)
   if count25 EQ 1 THEN BEGIN
      origFile25Name = STRJOIN(STRTRIM(prgrfiles[idx25],2))
      idxfiles[idx25] = 1
   endif ELSE origFile25Name='no_2A25_file'

   idx31 = WHERE(STRPOS(prgrfiles,'2B31') GE 0, count31)
   if count31 EQ 1 THEN BEGIN
      origFile31Name = STRJOIN(STRTRIM(prgrfiles[idx31],2))
      idxfiles[idx31] = 1
   endif ELSE origFile31Name='no_2B31_file'

  ; this should never happen, but for completeness...
   idxgr = WHERE(idxfiles EQ 0, countgr)
   if countgr EQ 1 THEN BEGIN
      origGRFileName = STRJOIN(STRTRIM(prgrfiles[idxgr],2))
      idxfiles[idxgr] = 1
   endif ELSE origGRFileName='no_1CUF_file'
ENDIF ELSE BEGIN
   origFile21Name='Unspecified'
   origFile23Name='Unspecified'
   origFile25Name='Unspecified'
   origFile31Name='Unspecified'
   origGRFileName='Unspecified'
ENDELSE
ncdf_attput, cdfid, 'PR_1C21_file', origFile21Name, /global
ncdf_attput, cdfid, 'PR_2A23_file', origFile23Name, /global
ncdf_attput, cdfid, 'PR_2A25_file', origFile25Name, /global
ncdf_attput, cdfid, 'PR_2B31_file', origFile31Name, /global
ncdf_attput, cdfid, 'GR_file', origGRFileName, /global

; field dimensions

fpdimid = ncdf_dimdef(cdfid, 'fpdim', numpts)  ; # of PR footprints within range
eldimid = ncdf_dimdef(cdfid, 'elevationAngle', N_ELEMENTS(elev_angles))
xydimid = ncdf_dimdef(cdfid, 'xydim', 4)  ; for 4 corners of a PR footprint
hidimid = ncdf_dimdef(cdfid, 'hidim', 15) ; for Hydromet ID Categories
sitedimid = ncdf_dimdef(cdfid, 'len_site_ID', STRLEN(siteID))

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
             'data exists flag for GR threeDreflect'
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

havegvRRvarid = ncdf_vardef(cdfid, 'have_GR_rainrate', /short)
ncdf_attput, cdfid, havegvRRvarid, 'long_name', $
             'data exists flag for GR_rainrate'
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

havedbzrawvarid = ncdf_vardef(cdfid, 'have_dBZnormalSample', /short)
ncdf_attput, cdfid, havedbzrawvarid, 'long_name', $
             'data exists flag for dBZnormalSample'
ncdf_attput, cdfid, havedbzrawvarid, '_FillValue', NO_DATA_PRESENT

havedbzvarid = ncdf_vardef(cdfid, 'have_correctZFactor', /short)
ncdf_attput, cdfid, havedbzvarid, 'long_name', $
             'data exists flag for correctZFactor'
ncdf_attput, cdfid, havedbzvarid, '_FillValue', NO_DATA_PRESENT

havePIAvarid = ncdf_vardef(cdfid, 'have_PIA', /short)
ncdf_attput, cdfid, havePIAvarid, 'long_name', $
             'data exists flag for 2A-25 Path Integrated Attenuation'
ncdf_attput, cdfid, havePIAvarid, '_FillValue', NO_DATA_PRESENT

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

havebbsvarid = ncdf_vardef(cdfid, 'have_BBstatus', /short)
ncdf_attput, cdfid, havebbsvarid, 'long_name', 'data exists flag for BBstatus'
ncdf_attput, cdfid, havebbsvarid, '_FillValue', NO_DATA_PRESENT

haveprsvarid = ncdf_vardef(cdfid, 'have_status', /short)
ncdf_attput, cdfid, haveprsvarid, 'long_name', 'data exists flag for 2A23 status'
ncdf_attput, cdfid, haveprsvarid, '_FillValue', NO_DATA_PRESENT

haverainflagvarid = ncdf_vardef(cdfid, 'have_rainFlag', /short)
ncdf_attput, cdfid, haverainflagvarid, 'long_name', $
             'data exists flag for rainFlag'
ncdf_attput, cdfid, haverainflagvarid, '_FillValue', NO_DATA_PRESENT

haveraintypevarid = ncdf_vardef(cdfid, 'have_rainType', /short)
ncdf_attput, cdfid, haveraintypevarid, 'long_name', $
             'data exists flag for rainType'
ncdf_attput, cdfid, haveraintypevarid, '_FillValue', NO_DATA_PRESENT

;haverayidxvarid = ncdf_vardef(cdfid, 'have_rayIndex', /short)
;ncdf_attput, cdfid, haverayidxvarid, 'long_name', $
;             'data exists flag for rayIndex'
;ncdf_attput, cdfid, haverayidxvarid, '_FillValue', NO_DATA_PRESENT

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

dbzgvvarid = ncdf_vardef(cdfid, 'threeDreflect', [fpdimid,eldimid])
ncdf_attput, cdfid, dbzgvvarid, 'long_name', 'GV radar QC Reflectivity'
ncdf_attput, cdfid, dbzgvvarid, 'units', 'dBZ'
ncdf_attput, cdfid, dbzgvvarid, '_FillValue', FLOAT_RANGE_EDGE

stddevgvvarid = ncdf_vardef(cdfid, 'threeDreflectStdDev', [fpdimid,eldimid])
ncdf_attput, cdfid, stddevgvvarid, 'long_name', 'Standard Deviation of GV radar QC Reflectivity'
ncdf_attput, cdfid, stddevgvvarid, 'units', 'dBZ'
ncdf_attput, cdfid, stddevgvvarid, '_FillValue', FLOAT_RANGE_EDGE

gvmaxvarid = ncdf_vardef(cdfid, 'threeDreflectMax', [fpdimid,eldimid])
ncdf_attput, cdfid, gvmaxvarid, 'long_name', 'Sample Maximum GV radar QC Reflectivity'
ncdf_attput, cdfid, gvmaxvarid, 'units', 'dBZ'
ncdf_attput, cdfid, gvmaxvarid, '_FillValue', FLOAT_RANGE_EDGE

gvZDRvarid = ncdf_vardef(cdfid, 'GR_Zdr', [fpdimid,eldimid])
ncdf_attput, cdfid, gvZDRvarid, 'long_name', 'DP Differential Reflectivity'
ncdf_attput, cdfid, gvZDRvarid, 'units', 'dB'
ncdf_attput, cdfid, gvZDRvarid, '_FillValue', FLOAT_RANGE_EDGE

gvZDRStdDevvarid = ncdf_vardef(cdfid, 'GR_ZdrStdDev', [fpdimid,eldimid])
ncdf_attput, cdfid, gvZDRStdDevvarid, 'long_name', 'Standard Deviation of DP Differential Reflectivity'
ncdf_attput, cdfid, gvZDRStdDevvarid, 'units', 'dB'
ncdf_attput, cdfid, gvZDRStdDevvarid, '_FillValue', FLOAT_RANGE_EDGE

gvZDRMaxvarid = ncdf_vardef(cdfid, 'GR_ZdrMax', [fpdimid,eldimid])
ncdf_attput, cdfid, gvZDRMaxvarid, 'long_name', 'Sample Maximum DP Differential Reflectivity'
ncdf_attput, cdfid, gvZDRMaxvarid, 'units', 'dB'
ncdf_attput, cdfid, gvZDRMaxvarid, '_FillValue', FLOAT_RANGE_EDGE

gvKdpvarid = ncdf_vardef(cdfid, 'GR_Kdp', [fpdimid,eldimid])
ncdf_attput, cdfid, gvKdpvarid, 'long_name', 'DP Specific Differential Phase'
ncdf_attput, cdfid, gvKdpvarid, 'units', 'deg/km'
ncdf_attput, cdfid, gvKdpvarid, '_FillValue', FLOAT_RANGE_EDGE

gvKdpStdDevvarid = ncdf_vardef(cdfid, 'GR_KdpStdDev', [fpdimid,eldimid])
ncdf_attput, cdfid, gvKdpStdDevvarid, 'long_name', 'Standard Deviation of DP Specific Differential Phase'
ncdf_attput, cdfid, gvKdpStdDevvarid, 'units', 'deg/km'
ncdf_attput, cdfid, gvKdpStdDevvarid, '_FillValue', FLOAT_RANGE_EDGE

gvKdpMaxvarid = ncdf_vardef(cdfid, 'GR_KdpMax', [fpdimid,eldimid])
ncdf_attput, cdfid, gvKdpMaxvarid, 'long_name', 'Sample Maximum DP Specific Differential Phase'
ncdf_attput, cdfid, gvKdpMaxvarid, 'units', 'deg/km'
ncdf_attput, cdfid, gvKdpMaxvarid, '_FillValue', FLOAT_RANGE_EDGE

gvRHOHVvarid = ncdf_vardef(cdfid, 'GR_RHOhv', [fpdimid,eldimid])
ncdf_attput, cdfid, gvRHOHVvarid, 'long_name', 'DP Co-Polar Correlation Coefficient'
ncdf_attput, cdfid, gvRHOHVvarid, 'units', 'Dimensionless'
ncdf_attput, cdfid, gvRHOHVvarid, '_FillValue', FLOAT_RANGE_EDGE

gvRHOHVStdDevvarid = ncdf_vardef(cdfid, 'GR_RHOhvStdDev', [fpdimid,eldimid])
ncdf_attput, cdfid, gvRHOHVStdDevvarid, 'long_name', 'Standard Deviation of DP Co-Polar Correlation Coefficient'
ncdf_attput, cdfid, gvRHOHVStdDevvarid, 'units', 'Dimensionless'
ncdf_attput, cdfid, gvRHOHVStdDevvarid, '_FillValue', FLOAT_RANGE_EDGE

gvRHOHVMaxvarid = ncdf_vardef(cdfid, 'GR_RHOhvMax', [fpdimid,eldimid])
ncdf_attput, cdfid, gvRHOHVMaxvarid, 'long_name', 'Sample Maximum DP Co-Polar Correlation Coefficient'
ncdf_attput, cdfid, gvRHOHVMaxvarid, 'units', 'Dimensionless'
ncdf_attput, cdfid, gvRHOHVMaxvarid, '_FillValue', FLOAT_RANGE_EDGE

gvRRvarid = ncdf_vardef(cdfid, 'GR_rainrate', [fpdimid,eldimid])
ncdf_attput, cdfid, gvRRvarid, 'long_name', 'GV radar DP Rainrate'
ncdf_attput, cdfid, gvRRvarid, 'units', 'mm/h'
ncdf_attput, cdfid, gvRRvarid, '_FillValue', FLOAT_RANGE_EDGE

stddevgvRRvarid = ncdf_vardef(cdfid, 'GR_rainrateStdDev', [fpdimid,eldimid])
ncdf_attput, cdfid, stddevgvRRvarid, 'long_name', 'Standard Deviation of GV radar DP Rainrate'
ncdf_attput, cdfid, stddevgvRRvarid, 'units', 'mm/h'
ncdf_attput, cdfid, stddevgvRRvarid, '_FillValue', FLOAT_RANGE_EDGE

gvmaxRRvarid = ncdf_vardef(cdfid, 'GR_rainrateMax', [fpdimid,eldimid])
ncdf_attput, cdfid, gvmaxRRvarid, 'long_name', 'Sample Maximum GV radar DP Rainrate'
ncdf_attput, cdfid, gvmaxRRvarid, 'units', 'mm/h'
ncdf_attput, cdfid, gvmaxRRvarid, '_FillValue', FLOAT_RANGE_EDGE

gvHIDvarid = ncdf_vardef(cdfid, 'GR_HID', [hidimid,fpdimid,eldimid], /short)
ncdf_attput, cdfid, gvHIDvarid, 'long_name', 'DP Hydrometeor Identification'
ncdf_attput, cdfid, gvHIDvarid, 'units', 'Categorical'
ncdf_attput, cdfid, gvHIDvarid, '_FillValue', INT_RANGE_EDGE

gvDzerovarid = ncdf_vardef(cdfid, 'GR_Dzero', [fpdimid,eldimid])
ncdf_attput, cdfid, gvDzerovarid, 'long_name', 'DP Median Volume Diameter'
ncdf_attput, cdfid, gvDzerovarid, 'units', 'mm'
ncdf_attput, cdfid, gvDzerovarid, '_FillValue', FLOAT_RANGE_EDGE

gvDzeroStdDevvarid = ncdf_vardef(cdfid, 'GR_DzeroStdDev', [fpdimid,eldimid])
ncdf_attput, cdfid, gvDzeroStdDevvarid, 'long_name', 'Standard Deviation of DP Median Volume Diameter'
ncdf_attput, cdfid, gvDzeroStdDevvarid, 'units', 'mm'
ncdf_attput, cdfid, gvDzeroStdDevvarid, '_FillValue', FLOAT_RANGE_EDGE

gvDzeroMaxvarid = ncdf_vardef(cdfid, 'GR_DzeroMax', [fpdimid,eldimid])
ncdf_attput, cdfid, gvDzeroMaxvarid, 'long_name', 'Sample Maximum DP Median Volume Diameter'
ncdf_attput, cdfid, gvDzeroMaxvarid, 'units', 'mm'
ncdf_attput, cdfid, gvDzeroMaxvarid, '_FillValue', FLOAT_RANGE_EDGE

gvNWvarid = ncdf_vardef(cdfid, 'GR_Nw', [fpdimid,eldimid])
ncdf_attput, cdfid, gvNWvarid, 'long_name', 'DP Normalized Intercept Parameter'
ncdf_attput, cdfid, gvNWvarid, 'units', '1/(mm*m^3)'
ncdf_attput, cdfid, gvNWvarid, '_FillValue', FLOAT_RANGE_EDGE

gvNWStdDevvarid = ncdf_vardef(cdfid, 'GR_NwStdDev', [fpdimid,eldimid])
ncdf_attput, cdfid, gvNWStdDevvarid, 'long_name', 'Standard Deviation of DP Normalized Intercept Parameter'
ncdf_attput, cdfid, gvNWStdDevvarid, 'units', '1/(mm*m^3)'
ncdf_attput, cdfid, gvNWStdDevvarid, '_FillValue', FLOAT_RANGE_EDGE

gvNWMaxvarid = ncdf_vardef(cdfid, 'GR_NwMax', [fpdimid,eldimid])
ncdf_attput, cdfid, gvNWMaxvarid, 'long_name', 'Sample Maximum DP Normalized Intercept Parameter'
ncdf_attput, cdfid, gvNWMaxvarid, 'units', '1/(mm*m^3)'
ncdf_attput, cdfid, gvNWMaxvarid, '_FillValue', FLOAT_RANGE_EDGE

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

gvrejvarid = ncdf_vardef(cdfid, 'n_gv_rejected', [fpdimid,eldimid], /short)
ncdf_attput, cdfid, gvrejvarid, 'long_name', $
             'number of bins below GV_dBZ_min in threeDreflect average'
ncdf_attput, cdfid, gvrejvarid, '_FillValue', INT_RANGE_EDGE

gv_zdr_rejvarid = ncdf_vardef(cdfid, 'n_gv_zdr_rejected', [fpdimid,eldimid], /short)
ncdf_attput, cdfid, gv_zdr_rejvarid, 'long_name', $
             'number of bins with missing Zdr in GR_Zdr average'
ncdf_attput, cdfid, gv_zdr_rejvarid, '_FillValue', INT_RANGE_EDGE

gv_kdp_rejvarid = ncdf_vardef(cdfid, 'n_gv_kdp_rejected', [fpdimid,eldimid], /short)
ncdf_attput, cdfid, gv_kdp_rejvarid, 'long_name', $
             'number of bins with missing Kdp in GR_Kdp average'
ncdf_attput, cdfid, gv_kdp_rejvarid, '_FillValue', INT_RANGE_EDGE

gv_rhohv_rejvarid = ncdf_vardef(cdfid, 'n_gv_rhohv_rejected', [fpdimid,eldimid], /short)
ncdf_attput, cdfid, gv_rhohv_rejvarid, 'long_name', $
             'number of bins with missing RHOhv in GR_RHOhv average'
ncdf_attput, cdfid, gv_rhohv_rejvarid, '_FillValue', INT_RANGE_EDGE

gv_rr_rejvarid = ncdf_vardef(cdfid, 'n_gv_rr_rejected', [fpdimid,eldimid], /short)
ncdf_attput, cdfid, gv_rr_rejvarid, 'long_name', $
             'number of bins below rain_min in GR_rainrate average'
ncdf_attput, cdfid, gv_rr_rejvarid, '_FillValue', INT_RANGE_EDGE

gv_hid_rejvarid = ncdf_vardef(cdfid, 'n_gv_hid_rejected', [fpdimid,eldimid], /short)
ncdf_attput, cdfid, gv_hid_rejvarid, 'long_name', $
             'number of bins with undefined HID in GR_HID histogram'
ncdf_attput, cdfid, gv_hid_rejvarid, '_FillValue', INT_RANGE_EDGE

gv_dzero_rejvarid = ncdf_vardef(cdfid, 'n_gv_dzero_rejected', [fpdimid,eldimid], /short)
ncdf_attput, cdfid, gv_dzero_rejvarid, 'long_name', $
             'number of bins with missing D0 in GR_Dzero average'
ncdf_attput, cdfid, gv_dzero_rejvarid, '_FillValue', INT_RANGE_EDGE

gv_nw_rejvarid = ncdf_vardef(cdfid, 'n_gv_nw_rejected', [fpdimid,eldimid], /short)
ncdf_attput, cdfid, gv_nw_rejvarid, 'long_name', $
             'number of bins with missing Nw in GR_Nw average'
ncdf_attput, cdfid, gv_nw_rejvarid, '_FillValue', INT_RANGE_EDGE

gvexpvarid = ncdf_vardef(cdfid, 'n_gv_expected', [fpdimid,eldimid], /short)
ncdf_attput, cdfid, gvexpvarid, 'long_name', $
             'number of bins in GV Z and RR averages'
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

PIAvarid = ncdf_vardef(cdfid, 'PIA', [fpdimid])
ncdf_attput, cdfid, PIAvarid, 'long_name', $
             '2A-25 Path Integrated Attenuation'
ncdf_attput, cdfid, PIAvarid, 'units', 'dBZ'
ncdf_attput, cdfid, PIAvarid, '_FillValue', FLOAT_RANGE_EDGE

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
ncdf_attput, cdfid, bbvarid, 'units', 'm'
ncdf_attput, cdfid, bbvarid, '_FillValue', FLOAT_RANGE_EDGE

bbsvarid = ncdf_vardef(cdfid, 'BBstatus', [fpdimid], /short)
ncdf_attput, cdfid, bbsvarid, 'long_name', $
            '2A-23 Bright Band Detection Status'
ncdf_attput, cdfid, bbsvarid, 'units', 'Categorical'
ncdf_attput, cdfid, bbsvarid, '_FillValue', INT_RANGE_EDGE

prsvarid = ncdf_vardef(cdfid, 'status', [fpdimid], /short)
ncdf_attput, cdfid, prsvarid, 'long_name', '2A-23 Status Flag'
ncdf_attput, cdfid, prsvarid, 'units', 'Categorical'
ncdf_attput, cdfid, prsvarid, '_FillValue', INT_RANGE_EDGE

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

gvtimevarid = ncdf_vardef(cdfid, 'timeSweepStart', [eldimid], /double)
ncdf_attput, cdfid, gvtimevarid, 'units', 'seconds'
ncdf_attput, cdfid, gvtimevarid, 'long_name', $
             'Seconds since 01-01-1970 00:00:00'
ncdf_attput, cdfid, gvtimevarid, '_FillValue', 0.0D+0

agvtimevarid = ncdf_vardef(cdfid, 'atimeSweepStart', $
                         [atimedimid,eldimid], /char)
ncdf_attput, cdfid, agvtimevarid, 'long_name', $
            'text version of timeSweepStart, UTC'

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
ncdf_varput, cdfid, vnversvarid, GEO_MATCH_FILE_VERSION ;GEO_MATCH_NC_FILE_VERS
;
ncdf_close, cdfid

GOTO, normalExit

versionOnly:
return, "NoGeoMatchFile"

normalExit:
return, geo_match_nc_file

end
