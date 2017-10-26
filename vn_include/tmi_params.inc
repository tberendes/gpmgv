;===============================================================================
;+
; Copyright © 2011, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; tmi_params.inc          Morris/SAIC/GPM_GV      April 2011
;
; DESCRIPTION
; -----------
; Defines parameters, product attributes, instrument attributes, and special
; values for data variables in TMI analysis and interpretation.
;
; HISTORY
; -------
; 4/2011 by Bob Morris, GPM GV (SAIC)
;  - Created.
; 2/2013 by Bob Morris, GPM GV (SAIC)
;  - Added constant NSPECIES.
; 10/07/14  Morris/GPM GV/SAIC
; - Renamed NSPECIES to NSPECIES_TMI.
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;===============================================================================

; General TMI parameters
NPIXEL_TMI=208
NLAYER_TMI=14
NSPECIES_TMI = 6  ; constant for clusterNumber, etc. dimension
ICE_WATER_SCALE_2A12=1000.      ; DIVIDE BY THIS TO GET PHYSICAL VALUE.  V6 ONLY.
LATENT_HEAT_SCALE=10.           ; DIVIDE BY THIS TO GET PHYSICAL VALUE.  V6 ONLY.
NOM_TMI_RES_KM = 14.            ; nominal TMI resolution in km, low-fudged
TMI_INCIDENT_ANGLE_DEG = 52.8   ; angle measured from local vertical
TAN_TMI_INCIDENT_ANGLE = TAN( TMI_INCIDENT_ANGLE_DEG * !DTOR )

; Information on 2A-12 Surface Type, V7 only:
;   10 = ocean
;   11 = sea ice
;   12 = partial sea ice
;   20 = land
;   30 = coast
;  -99 = MISSING

; Information on 2A-12 Surface Flag, V6 only
; (these values mapped to V7 values in read_2a12_file.pro, as shown below)
;    0 = ocean -> 10
;    1 = land -> 20
;    2 = coast -> 30
;    3 = other -> -99

; Information on 2A-12 pixelStatus, V7 only:
;    0 = Valid pixel
;    1 = Boundary error in landmask
;    2 = Boundary error in sea-ice check
;    3 = Boundary error in sea surface temperature
;    4 = Invalid time
;    5 = Invalid latitude/longitude
;    6 = Invalid brightness temperature
;    7 = Invalid sea surface temperature
;    8 = No retrieval due to sea-ice over water
;    9 = No retrieval due to sea-ice over coast
;   10 = Land/coast screens not able to be applied
;   11 = Failure in ocean rain - no match with database profile Tbs
;  -99 = Missing value
