;===============================================================================
;+
; Copyright © 2014, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; gmi_params.inc          Morris/SAIC/GPM_GV      September 2014
;
; DESCRIPTION
; -----------
; Defines parameters, product attributes, instrument attributes, and special
; values for data variables in GMI analysis and interpretation.
;
; HISTORY
; -------
; 9/2014 by Bob Morris, GPM GV (SAIC)
;  - Created.
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;===============================================================================

; General GMI parameters
NPIXEL_GMI=221
NLYRS_GMI=28
NSPECIES_GMI = 5
SDDIM_GMI = 12    ; # characters in NSPECIES_GMI definitions
NTEMPS_GMI = 21
NPRF_GMI = 100
NOM_GMI_RES_KM = 14.            ; nominal GMI resolution in km, low-fudged
GMI_INCIDENT_ANGLE_DEG = 52.8   ; angle measured from local earth vertical
TAN_GMI_INCIDENT_ANGLE = TAN( GMI_INCIDENT_ANGLE_DEG * !DTOR )

; Information on surfaceTypeIndex
;   1 = ocean
;   1 = sea ice
;   2 = partial sea ice
;   3-12 = land
;   13 = coast (water/land boundary)
;   14 = Water/Ice boundary
;   15 = Land/Ice boundary
;  -99 = MISSING

; Information on pixelStatus
;    0 = Valid pixel
;    1 = Boundary error in landmask
;    2 = Boundary error in sea-ice check
;    3 = Boundary error in sea surface temperature
;    4 = Invalid time
;    5 = Invalid latitude/longitude
;    6 = Invalid brightness temperature
;    7 = Invalid sea surface temperature
;  -99 = Missing value
