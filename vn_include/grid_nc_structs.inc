;===============================================================================
;+
; Copyright © 2008, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; grid_nc_structs.inc          Morris/SAIC/GPM_GV      February 2008
;
; DESCRIPTION
; -----------
; Defines structures to hold grid definitions, GV site names and locations,
; and flags indicating whether data variables are actual data or fill values,
; as read from the PR and GV netCDF grid data files.  Flag structures differ
; between PR and GV.  Grid and site structures are in common for PR and GV.
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;===============================================================================

; "Include" files for constants, names, paths, etc.
@grid_def.inc   ; for NO_DATA_PRESENT
@pr_params.inc  ; for NZ

grid_meta = { grid_def_meta, $
             nx: 0,   ny: 0,   nz: 0,   $
             dx: 0.0, dy: 0.0, dz: 0.0, $
             zlevels: fltarr(NZ),       $
             version: 0.0               $
            }

site_meta = { gv_site_meta, $
              site_lat: 0.0, site_lon: 0.0, site_id: '' $
            }

field_flagsPR = { pr_field_flags, $
                  have_dBZnormalSample:   NO_DATA_PRESENT, $
                  have_correctZFactor:    NO_DATA_PRESENT, $
                  have_rain:              NO_DATA_PRESENT, $
                  have_landOceanFlag:     NO_DATA_PRESENT, $
                  have_nearSurfRain:      NO_DATA_PRESENT, $
                  have_nearSurfRain_2b31: NO_DATA_PRESENT, $
                  have_BBheight:          NO_DATA_PRESENT, $
                  have_rainFlag:          NO_DATA_PRESENT, $
                  have_rainType:          NO_DATA_PRESENT, $
                  have_rayIndex:          NO_DATA_PRESENT  $
                }

field_flagsGV = { gv_field_flags, $
                  have_threeDreflect: NO_DATA_PRESENT, $
                  have_rainRate:      NO_DATA_PRESENT, $
                  have_convStratFlag: NO_DATA_PRESENT  $
              }
