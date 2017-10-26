;===============================================================================
;+
; Copyright © 2008, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; gpm_orbit_match_nc_structs.inc          Morris/SAIC/GPM_GV      October 2014
;
; DESCRIPTION
; -----------
; Defines structures to hold GV site names and locations, data and algorithm
; parameters, and flags indicating whether data variables are actual data or
; fill values, as read from the DPR-GMI orbit matchup netCDF data files.
;
; HISTORY:
; 10/16/2014  Morris, GPM GV (SAIC)
;  - Created.
; 05/18/16  Morris, GPM GV (SAIC)
;  - Added have_typePrecip and have_flagPrecip tag/value pairs to
;    dpr_gmi_field_flags structure.
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;===============================================================================

; "Include" files for constants, names, paths, etc.
@grid_def.inc   ; for NO_DATA_PRESENT
@dpr_params.inc  ; for the type-specific fill values (FLOAT_RANGE_EDGE)

swath_match_meta = { dpr_gmi_match_meta,                           $
                     num_scans:             0,                     $
                     num_rays:              0,                     $
                     gmi_rain_min:          FLOAT_RANGE_EDGE,      $
                     averaging_radius:      0.0,                   $
                     Map_Projection:       'Undefined',            $
                     centerLat:             FLOAT_RANGE_EDGE,      $
                     centerLon:             FLOAT_RANGE_EDGE,      $
                     PPS_Version:          'Undefined',            $
                     nc_file_version:       0.0                    $
                   }

field_flags_swath_gpm =  { dpr_gmi_field_flags,                          $
                           have_surfaceType:            NO_DATA_PRESENT, $
                           have_surfacePrecipitation:   NO_DATA_PRESENT, $
                           have_pixelStatus:            NO_DATA_PRESENT, $
                           have_PoP:                    NO_DATA_PRESENT, $
                           have_precipRateSurface:      NO_DATA_PRESENT, $
                           have_surfRain_2BDPRGMI:      NO_DATA_PRESENT, $
                           have_BBheight:               NO_DATA_PRESENT, $
                           have_numPRrainy:             NO_DATA_PRESENT, $
                           have_numConvectiveType:      NO_DATA_PRESENT, $
                           have_typePrecip:             NO_DATA_PRESENT, $
                           have_flagPrecip:             NO_DATA_PRESENT  $
                         }

files_meta_swath_gpm  =  { input_files_swath_gpm,      $
                           file_2agprof:  'UNDEFINED', $
                           file_dpr_2a:   'UNDEFINED', $
                           file_2adprgmi: 'UNDEFINED'  $
                         }
