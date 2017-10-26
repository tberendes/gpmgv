;===============================================================================
;+
; Copyright © 2008, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; pr_params.inc          Morris/SAIC/GPM_GV      March 2007
;
; DESCRIPTION
; -----------
; Defines parameters, product attributes, instrument attributes, and special
; values for data variables in PR grid analysis and interpretation.
;
; HISTORY
; -------
; 9/2008 by Bob Morris, GPM GV (SAIC)
;  - Added type-specific constants xxx_OFF_EDGE and xxx_RANGE_EDGE to be shared
;    by all PR elements of a given data type 'xxx' (INT, FLOAT, or LONG)
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;===============================================================================

; general PR parameters
RAYSPERSCAN = 49
NUM_RANGE_1C21 = 140   ; number of bins in 1C21 Normal Sample
NUM_RANGE_2A25 = 80    ; ncell1 in TRMM Products Level 2/3 ICD
GATE_SPACE = 250       ; gate spacing in meters
BIN_SPACE = 125        ; bin spacing in meters
DBZSCALE2A25 = 100.    ; 2A25 reflectivity scale factor
DBZSCALE1C21 = 100.    ; 1C21 reflectivity scale factor
RAINSCALE2A25 = 100.   ; 2A25 rain rate scale factor
; and one GV orphan
DBZSCALE2A55 = 100.    ; 2A55 reflectivity scale factor
NOM_PR_RES_KM = 4.     ; nominal PR resolution in km, low-fudged

; program-specific Special Values for netCDF grid output
BB_MISSING = -1
BBHGT_UNDEFINED = 0.0
RAINTYPE_OFF_EDGE = -77  ;assigned to border points for GRIDDATA nearest neighbor
LANDOCEAN_MISSING = -1
Z_MISSING = -9999.
Z_BELOW_THRESH = -100.
RAINFLAGFILL = 2048        ; setting RainFlag "Not Used" bit 11 only
SRAIN_BELOW_THRESH = -88.88  ; near-surface rain < RAIN_MIN
SRAIN_OFF_EDGE = -999.  ;assigned to border points for GRIDDATA nearest neighbor

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

; Information on the types of rain storm.  We reduce to 1-digit category for
; analysis and output to netCDF grid.
RainType_stratiform =  1   ;(Stratiform)    (values 100-170 in 2A23/2A25)
RainType_convective =  2   ;(Convective)    (values 200-291 in 2A23/2A25)
RainType_other      =  3   ;(Others)        (values 300-313 in 2A23/2A25)
RainType_no_data    = -7   ;(Grdpt not coincident with PR - not a 2A23/25 value)
RainType_no_rain    = -8   ;(No rain)       (value = -88 in 2A23/2A25)
RainType_missing    = -9   ;(Missing data)  (value = -99 in 2A23/2A25)

; Information on 1C21 Land/Ocean Flag:
; -1 = (Gridpoint not coincident with PR - not a 1C21 value)
;  0 = water
;  1 = land
;  2 = coast
;  3 = water, with large attenuation
;  4 = land/coast, with large attenuation
;
; BinStart is now a variable read from 1C-21 product Vdata as rayStart:
; binStart = [121,111,101,92,83,74,66, $
;             59,52,45,39,33,29,23,    $
;             19,15,11,9,7,5,3,        $
;             1,1,1,1,1,1,1,           $
;             3,5,7,9,11,15,19,        $
;             23,29,33,39,45,52,59,    $
;             66,74,83,92,101,111,121]
