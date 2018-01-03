;===============================================================================
;+
; Copyright © 2016, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; get_2aku_matching_footprint.pro
; - Morris/SAIC/GPM_GV  December 2016
;
; DESCRIPTION
; -----------
; Extracts a fixed set of variables taken from a user-selected 2A-Ku data file,
; subsetted along a single DPR ray at the location specified by the latitude and
; longitude parameter values.  The input parameters yymmdd, orbit, version, and
; startdir provide guidance to the user as to the date, time, orbit, and PPS
; version of the 2A-Ku file to be selected to match the case currently being
; analyzed.  Returns the subsetted/extracted variables in an anonymous
; structure, or returns -1 in case of errors or if the user bails out without
; selecting a 2AKu file.
;
; The 125-m resolution measured reflectivity profile from the 2AKu file is
; processed to produce a second profile with 250-m vertical resolution gates
; to match the 2BDPRGMI reflectivity profiles.  Both the 250-m and original
; 125-m measured reflectivity profiles are returned in the structure.
;
;
; PARAMETERS
; ----------
; latitude  - latitude of the DPR ray footprint to be extracted and processed
; longitude - longitude of the DPR ray footprint to be extracted and processed
; yymmdd    - year, month, and day of the 2AKu file to be selected for the case
; orbit     - orbit number of the 2AKu file to be selected for the case
; version   - PPS version of the 2AKu file to be selected for the case
; startdir  - starting directory under which to search for matching 2AKu files
;
;
; MODULES
; -------
; 1) get_2aku_matching_footprint - Module called by the external routine.
;                                  Provides user interface to use for 2AKu file
;                                  selection.
;
; 2) extract_2aku_profile - Internal function to read and extract subsetted
;                           variables from the selected 2AKu file at the DPR ray
;                           located nearest the input latitude and longitude and
;                           write them to the structure to be returned.
;
;
; HISTORY
; -------
; 12/16/16 Morris, GPM GV, SAIC
; - Created.
;
; EMAIL QUESTIONS OR COMMENTS AT:
;       https://pmm.nasa.gov/contact
;-
;===============================================================================


;===============================================================================
; module #2  extract_2aku_profile()
;===============================================================================

FUNCTION extract_2aku_profile, file_2aku, latitude, longitude

; "Include" file for DPR-product-specific parameters (i.e., RAYSPERSCAN):
@dpr_params.inc

; check for file existence
IF FILE_TEST(file_2aku) NE 1 THEN message, "FATAL: 2AKu file not found: "+file_2aku

; is it a 2A-Ku file?
idxKU = WHERE(STRMATCH(file_2aku,'*2A*.GPM.Ku*', /FOLD_CASE) EQ 1, countKU)
if countKU NE 1 THEN message, "File "+file_2aku+'not a 2AKU file.'

; set up contants
RAYSPERSCAN = RAYSPERSCAN_NS
GATE_SPACE = BIN_SPACE_NS_MS
ELLIPSOID_BIN_DPR = ELLIPSOID_BIN_NS_MS

; read the file and get the NS swath structure

dpr_data = read_2akaku_hdf5(file_2aku, SCAN='NS')
ptr_swath = dpr_data.NS

; grab the footprint latitude and longitude fields
IF PTR_VALID(ptr_swath.PTR_DATASETS) THEN BEGIN
   dprlons = (*ptr_swath.PTR_DATASETS).LONGITUDE
   dprlats = (*ptr_swath.PTR_DATASETS).LATITUDE
   ptr_free, ptr_swath.PTR_DATASETS
ENDIF ELSE message, "Invalid pointer to PTR_DATASETS."

; find the nearest footprint to input latitude and longitude
; and check that its distance is within 1 km, otherwise consider the
; situation is a mismatch between products.
minLLdiff = MIN( (ABS(dprlats-latitude) + ABS(dprlons-longitude)), idxmin )
; rough distance calculation based on 111.1 km/deg
latDist = 111.1 * (dprlats[idxmin]-latitude)
lonDist = 111.1 * COS(latitude * !DTOR) * (dprlons[idxmin]-longitude)
dDist = SQRT(latDist^2 + lonDist^2)
IF dDist GT 3.0 THEN message, "Footprint distance from lat/lon too far: " $
                             + STRING(dDist,FORMAT='(F0.1)')

; get the scan and ray number of the location of the matching footprint
rayscan = ARRAY_INDICES( dprlats, idxmin )
rayDPR = rayscan[0]
scanDPR = rayscan[1]

; get other variables needed to compute the 250-m averaged-down Zm and the
; storm top height
IF PTR_VALID(ptr_swath.PTR_PRE) THEN BEGIN
   dbz_meas = (*ptr_swath.PTR_PRE).ZFACTORMEASURED
;   binRealSurface = (*ptr_swath.PTR_PRE).BINREALSURFACE
;   binRealSurface[*,*] = ELLIPSOID_BIN_DPR   ; reset to fixed bin of MSL surface
   binClutterFreeBottom = (*ptr_swath.PTR_PRE).binClutterFreeBottom
   localZenithAngle = (*ptr_swath.PTR_PRE).localZenithAngle
   heightStormTop = (*ptr_swath.PTR_PRE).heightStormTop
ENDIF ELSE message, "Invalid pointer to PTR_PRE."

; average the 125m Z data down to 250m data as done in 2B-CMB algorithm, for
; the single footprint only, and also compute max Z in columns for Zmeas
maxZmeas250 = FLOAT_RANGE_EDGE
dbz_meas_2B = dpr_125m_to_250m(dbz_meas, rayDPR, scanDPR, $
                               binClutterFreeBottom, ELLIPSOID_BIN_DPR, $
                               MAXZ250=maxZmeas250)

; dpr_125m_to_250m returns a 3-D array over ALL footprints, but only populates
; the column indicated by rayDPR and scanDPR, so extract this ray's data
dbz_meas_2B = REFORM( dbz_meas_2B[*, rayDPR, scanDPR] )
; grab the original profile for the heck of it
dbz_meas_2A = REFORM( dbz_meas[*, rayDPR, scanDPR] )

; compute the binClutterFreeBottom location of the 250-m profile
binClutterFree250 = (binClutterFreeBottom[rayDPR, scanDPR]-2)/2

; grab the heightStormTop and scan angle values for this footprint, 
; along with the 2AKu clutterFreeBottom gate
stormTop2AKu = heightStormTop[rayDPR, scanDPR]
scanAngle2AKu = localZenithAngle[rayDPR, scanDPR]
binClutterFree2AKu = binClutterFreeBottom[rayDPR, scanDPR]

; put return values in a structure
data250 = {          Zmeas250 : dbz_meas_2B, $
                  maxZmeas250 : maxZmeas250, $
            binClutterFree250 : binClutterFree250, $
                     Zmeas125 : dbz_meas_2A, $
           binClutterFree2AKu : binClutterFree2AKu, $
                 stormTop2AKu : stormTop2AKu, $
                     ray_2aku : rayDPR, $
                    scan_2aku : scanDPR, $
                latitude_2aku : dprlats[idxmin], $
               longitude_2aku : dprlons[idxmin], $
               scanAngle_2aku : scanAngle2AKu, $
                    file_2aku : file_2aku }

return, data250
end

;===============================================================================
; module #1  get_2aku_matching_footprint()
;===============================================================================

function get_2aku_matching_footprint, latitude, longitude, yymmdd, orbit, $
                                      version, STARTDIR=startdir

IF N_ELEMENTS(startdir) EQ 1 THEN dirpath=startdir ELSE dirpath='/data/gpmgv/orbit_subset/GPM/Ku/2AKu'

title = "Date: "+yymmdd+", Orbit: "+orbit+", Version: "+version

print, ""
print, title
print, "Select matching 2A-Ku file using file selector:"
PRINT, STRING(7B)   ; ring the bell

fileKu = DIALOG_PICKFILE(PATH=dirpath, TITLE=title)
IF fileKu EQ '' THEN return, -1 $
                ELSE dataKu = extract_2aku_profile( fileku, latitude, longitude )

return, dataKu

end
