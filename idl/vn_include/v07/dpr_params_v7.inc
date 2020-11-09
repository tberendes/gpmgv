;===============================================================================
;+
; Copyright © 2013, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; dpr_params_v7.inc          Morris/SAIC/GPM_GV      June 2013
;
; DESCRIPTION
; -----------
; Defines parameters, product attributes, instrument attributes, and special
; values for data variables in DPR grid analysis and interpretation.
;
; HISTORY
; -------
; 6/2013 by Bob Morris, GPM GV (SAIC)
;  - Created from pr_params.inc
; 1/22/14 by Bob Morris, GPM GV (SAIC)
;  - Updated value definitions for DBZSCALECORR and DBZSCALEMEAS to match
;    current GPM file specification.
; 4/1/2014 by Bob Morris, GPM GV (SAIC)
;  - Added values FLAGPRECIP_PRECIPITATION, QUALITYBB_GOOD for DPR metadata
;    extraction.  Fixed copyright year.
; 4/16/2014 by Bob Morris, GPM GV (SAIC)
;  - Fixed value of FLAGPRECIP_PRECIPITATION based on latest GPM filespec.
; 5/20/14 by Bob Morris, GPM GV (SAIC)
;  - Added nPhsBnN, nPSDlo, nBnPSDlo, nKuKa for DPRGMI product variables.
; 6/9/14 by Bob Morris, GPM GV (SAIC)
;  - Fixed value of RAINSCALE.
; 11/11/14 by Bob Morris, GPM GV (SAIC)
;  - Added BIN_SPACE_DPRGMI for redefined gate spacings for MS and NS swaths
;    in 2B-DPRGMI products.
;  - Added ELLIPSOID_BIN_DPRGMI for 2B-DPRGMI ellipsoid gate position.
; 11/19/14 by Bob Morris, GPM GV (SAIC)
;  - Added ELLIPSOID_BIN_HS and ELLIPSOID_BIN_NS_MS for 2ADPR/2AKu/2AKa
;    ellipsoid gate positions.
; 6/15/15 by Bob Morris, GPM GV (SAIC)
;  - Fixed value of ELLIPSOID_BIN_DPRGMI, was 80, should be 88.
; 01/21/16 by Bob Morris, GPM GV (SAIC)
;  - Added DPR_ROI parameter as a fixed radius of influence (DPR beamwidth) to
;    use for GR averaging over DPR footprint.
; 06/15/20 by Todd Berendes, UAH
;  - Modified from dpr_params.inc to use GPM Version 7 format for 06X and beyond
;  - Removed NS and MS swaths, added FS swath, HS swath dimensions are unchanged
;    
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;===============================================================================

; general DPR parameters
RAYSPERSCAN_FS = 49
RAYSPERSCAN_HS = 24
NUM_RANGE_FS = 176   ; number of bins in Ku Normal and Ka Matched rays
NUM_RANGE_HS = 88       ; number of bins in Ka HS scan rays
BIN_SPACE_HS = 250      ; HS scan gate spacing in meters for 2AKa
BIN_SPACE_FS = 125   ; FS scan gate spacing in meters for 2ADPR/2AKu/2AKa
ELLIPSOID_BIN_HS = 88     ; 1-based bin number of earth ellipsoid in HS swath
                          ; in 2ADPR/2AKa
ELLIPSOID_BIN_FS = 176 ; 1-based bin number of earth ellipsoid in FS
                          ; swaths in 2ADPR/2AKu/2AKa
                          
; ######DPRGMI is not modified for V06X yet#####
BIN_SPACE_DPRGMI = 250  ; MS/NS scan gate spacing in meters for 2B-DPRGMI
ELLIPSOID_BIN_DPRGMI=88 ; 1-based bin number of earth ellipsoid in 2B-DPRGMI
DBZSCALECORR = 1.       ; corrected reflectivity scale factor
DBZSCALEMEAS = 1.       ; measured reflectivity scale factor
RAINSCALE = 1.          ; rain rate scale factor
NOM_DPR_RES_KM = 4.     ; nominal DPR resolution in km, low-fudged
nPhsBnN = 5             ; no. of DPRGMI phase bin nodes
nPSDlo = 2              ; no. of DPRGMI low-resolution PSD parameters
nBnPSDlo = 9            ; no. of bin indices of DPRGMI low-resolution PSD param.
nKuKa = 2               ; no. of DPRGMI Ku and Ka for some MS swath vars.
DPR_ROI = 7.3           ; radius of influence (km) for GR bins included in vol. avg.
nfreqDPR = 2 			; no. of DPR FS frequencies (Ku, Ka)

; program-specific Special Values for netCDF grid output
BB_MISSING = -1
BBHGT_UNDEFINED = 0.0
RAINTYPE_OFF_EDGE = -77      ; marks border points for GRIDDATA nearest neighbor
LANDOCEAN_MISSING = -1
Z_MISSING = -9999.
Z_BELOW_THRESH = -100.
RAINFLAGFILL = 2048          ; setting RainFlag "Not Used" bit 11 only
SRAIN_BELOW_THRESH = -88.88  ; near-surface rain < RAIN_MIN
SRAIN_OFF_EDGE = -999.       ; marks border points for GRIDDATA nearest neighbor

; Generic special values for geo-matching netCDF files.  (Define any new generic
; special values outside +/- of the working range of a GV radar, in km)
INT_OFF_EDGE = -777
LONG_OFF_EDGE = LONG(INT_OFF_EDGE)
FLOAT_OFF_EDGE = FLOAT(INT_OFF_EDGE)
INT_RANGE_EDGE = -888
LONG_RANGE_EDGE =LONG(INT_RANGE_EDGE)
FLOAT_RANGE_EDGE = FLOAT(INT_RANGE_EDGE)

; bit maps for selected 2A25 Rain Flag indicators:
RAIN_POSSIBLE = 1  ;bit 0
RAIN_CERTAIN = 2   ;bit 1
STRATIFORM = 16    ;bit 4
CONVECTIVE = 32    ;bit 5
BB_EXISTS = 64     ;bit 6  ( BB => Bright Band )
NOT_USED = 1024    ;bit 10

; comparison values for 2A-DPR (Ka|Ku) product:
FLAGPRECIP_PRECIPITATION = 1
QUALITYBB_GOOD = 1

; Information on the types of rain storm.  We reduce to 1-digit category for
; analysis and output to netCDF grid.
RainType_stratiform =  1   ;(Stratiform)    (values 100-170 in 2A23/2A25)
RainType_convective =  2   ;(Convective)    (values 200-291 in 2A23/2A25)
RainType_other      =  3   ;(Others)        (values 300-313 in 2A23/2A25)
RainType_no_data    = -7   ;(Grdpt not coincident with PR - not a 2A23/25 value)
RainType_no_rain    = -8   ;(No rain)       (value = -88 in 2A23/2A25)
RainType_missing    = -9   ;(Missing data)  (value = -99 in 2A23/2A25)

; Reference Information on Land/Ocean Flag:
; -1 = (Gridpoint not coincident with PR - not a 1C21 value)
;  0 = water
;  1 = land
;  2 = coast
;  3 = water, with large attenuation
;  4 = land/coast, with large attenuation
