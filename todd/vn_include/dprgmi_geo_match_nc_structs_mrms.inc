;===============================================================================
;+
; Copyright © 2014, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; dprgmi_geo_match_nc_structs.inc          Morris/SAIC/GPM_GV      August 2014
;
; DESCRIPTION
; -----------
; Defines structures to hold GV site names and locations, data and algorithm
; parameters, and flags indicating whether data variables are actual data or
; fill values, as read from the DPRGMI-GR matchup netCDF data files.
;
; HISTORY:
; 8/29/14  Morris, GPM GV (SAIC)
;  - Created from dpr_geo_match_nc_structs.inc.
; 11/12/14  Morris, GPM GV (SAIC)
;  - Added GV_UF_RC_field, GV_UF_RP_field, have_GR_RC_rainrate, and
;    have_GR_RP_rainrate to structures, and renamed have_GR_rainrate to
;    have_GR_RR_rainrate.
; 6/16/15  Morris, GPM GV (SAIC)
;  - Renamed dpr_gr_field_flags to dprgmi_gr_field_flags to avoid conflicting
;    definitions. Remove non-applicable have_xxx flags for ZFactorMeasured,
;    paramDSD, and BBstatus from this structure, and added flag have_pia.
;  - Added have_swath_MS tag/value to dprgmi_geo_match_meta structure.
; 12/23/15  Morris, GPM GV (SAIC)
;  - Added have_GR_blockage tag/value to dprgmi_gr_field_flags structure.
; 07/13/16  Morris, GPM GV (SAIC)
;  - Added GV_UF_DM_FIELD and GV_UF_N2_FIELD tag/values to dprgmi_gr_field_flags
;    structure, and added have_GR_Dm and have_GR_N2 tag/values to
;    dprgmi_gr_field_flags structure, for version 1.3 files.
; 02/04/19 by Todd Berendes
;  - added have_GR_SWE
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;===============================================================================

; "Include" files for constants, names, paths, etc.
@grid_def.inc   ; for NO_DATA_PRESENT
@dpr_params.inc  ; for the type-specific fill values (FLOAT_RANGE_EDGE)

matchup_meta = { dprgmi_geo_match_meta,                        $
                 timeNearestApproach:   0.0D,                  $
                 atimeNearestApproach: '01-01-1970 00:00:00',  $
                 GV_UF_Z_field:         '',                    $
                 GV_UF_RC_field:        '',                    $
                 GV_UF_RP_field:        '',                    $
                 GV_UF_RR_field:        '',                    $
                 GV_UF_ZDR_field:       '',                    $
                 GV_UF_KDP_field:       '',                    $
                 GV_UF_RHOHV_field:     '',                    $
                 GV_UF_HID_field:       '',                    $
                 GV_UF_D0_field:        '',                    $
                 GV_UF_NW_field:        '',                    $
                 GV_UF_DM_field:        '',                    $
                 GV_UF_N2_field:        '',                    $
                 DPR_ScanType:          '',                    $
                 num_volumes:           0,                     $
                 num_sweeps:            0,                     $
                 num_footprints_MS:     0,                     $
                 num_footprints_NS:     0,                     $
                 num_HID_categories:    0,                     $
                 startScan_MS:          0,                     $
                 endScan_MS:            0,                     $
                 num_rays_MS:           0,                     $
                 startScan_NS:          0,                     $
                 endScan_NS:            0,                     $
                 num_rays_NS:           0,                     $
                 have_swath_MS:         NO_DATA_PRESENT,       $
                 rangeThreshold:        FLOAT_RANGE_EDGE,      $
                 GR_dBZ_min:            FLOAT_RANGE_EDGE,      $
                 DPR_dBZ_min:           FLOAT_RANGE_EDGE,      $
                 rain_min:              FLOAT_RANGE_EDGE,      $
                 gmi_rain_min:          FLOAT_RANGE_EDGE,      $
;                 GR2GMI_dBZ_min:        FLOAT_RANGE_EDGE,      $
                 DPR_Version:           '',                    $
;                 GMI_Version:           '',                    $
                 nc_file_version:       0.0                    $
               }

sweeps_meta =  { gr_sweep_meta,                           $
                 elevationAngle:   FLOAT_RANGE_EDGE,      $
                 timeSweepStart:   0.0D,                  $
                 atimeSweepStart: '01-01-1970 00:00:00'   $
               }

site_meta =    { gr_site_meta,    $
                 site_lat:  0.0,  $
                 site_lon:  0.0,  $
                 site_id:    '',  $
                 site_elev: 0.0   $
               }

field_flags =  { dprgmi_gr_field_flags,                        $
                 have_threeDreflect:       NO_DATA_PRESENT, $
                 have_GR_Zdr:              NO_DATA_PRESENT, $
                 have_GR_Kdp:              NO_DATA_PRESENT, $
                 have_GR_RHOhv:            NO_DATA_PRESENT, $
                 have_GR_RC_rainrate:      NO_DATA_PRESENT, $
                 have_GR_RP_rainrate:      NO_DATA_PRESENT, $
                 have_GR_RR_rainrate:      NO_DATA_PRESENT, $
                 have_GR_HID:              NO_DATA_PRESENT, $
                 have_GR_Dzero:            NO_DATA_PRESENT, $
                 have_GR_Nw:               NO_DATA_PRESENT, $
                 have_GR_Dm:               NO_DATA_PRESENT, $
                 have_GR_N2:               NO_DATA_PRESENT, $
                 have_GR_blockage:         NO_DATA_PRESENT, $
                 have_ZFactorCorrected:    NO_DATA_PRESENT, $
                 have_PrecipRate:          NO_DATA_PRESENT, $
                 have_pia:                 NO_DATA_PRESENT, $
                 have_LandSurfaceType:     NO_DATA_PRESENT, $
                 have_PrecipRateSurface:   NO_DATA_PRESENT, $
                 have_SurfPrecipRate:      NO_DATA_PRESENT, $
                 have_BBheight:            NO_DATA_PRESENT, $
                 have_TypePrecip:          NO_DATA_PRESENT, $
                 have_FlagPrecip:          NO_DATA_PRESENT, $
                 have_clutterStatus:       NO_DATA_PRESENT,  $
                 have_GR_SWE:       	NO_DATA_PRESENT  $
               }

files_meta  =  { dprgmi_gr_input_files,    $
                 file_2bcomb: 'UNDEFINED', $
                 file_1cuf:   'UNDEFINED'  $
               }
