;===============================================================================
;+
; Copyright © 2008, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; grid_def.inc          Morris/SAIC/GPM_GV      March 2007
;
; DESCRIPTION
; -----------
; Defines parameters for PR/GV cartesian analysis grid.
;
; HISTORY
; -------
; 11/2010 by Bob Morris, GPM GV (SAIC)
;  - Reversed values of DATA_PRESENT and NO_DATA_PRESENT to align with C and
;    IDL True/False interpretation of values 1 and 0
;
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;===============================================================================

; TAB 6/14/22, this common statement causes syntax error now
COMMON grid_def, NX, NY, NZ, DX_DY, DZ, Z_BASE, ZLEVELS, GRID_ID

; 2A-55 grid parameters:

DX_DY_2A55 = 2000   ; horizontal grid spacing of 2A55 GV product, DY=DX
NX_2A55 = 151  &  NY_2A55 = 151  &  NZ = 13   ; 2/3-D grid dimensions
DZ = 1500  ; vertical grid spacings in meters
Z_BASE = 1500               ; height of lowest grid level, in meters
ztempa = indgen(NZ)
ZLEVELS = Z_BASE + (ztempa * DZ)   ; grid height levels in meters

; Validation Network netCDF grid parameters:

REDUCFAC = 2    ; reduction of output netCDF grid relative to 2A55 grid
NX = NX_2A55/REDUCFAC  &  NY = NY_2A55/REDUCFAC  ; netCDF 2D grid dimensions
DX_DY = DX_DY_2A55 * REDUCFAC  ;  netCDF 2D grid spacing, DY=DX
FLOATGRIDFILL = -99.99
LATLONFILL = -999.0

GRID_ID = 'default'

; Values for "have_somegridfield" flags:

DATA_PRESENT = 1
NO_DATA_PRESENT = 0  ; default fill value, defined for gen_pr_netcdf_template(),
                     ; gen_gv_netcdf_template(), gen_geo_match_netcdf()
