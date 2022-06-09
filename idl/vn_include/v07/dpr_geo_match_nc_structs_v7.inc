;===============================================================================
;+
; Copyright © 2013, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; dpr_geo_match_nc_structs.inc          Morris/SAIC/GPM_GV      July 2013
;
; DESCRIPTION
; -----------
; Defines structures to hold GV site names and locations, data and algorithm
; parameters, and flags indicating whether data variables are actual data or
; fill values, as read from the DPR-GR matchup netCDF data files.
;
; HISTORY:
; 7/11/13  Morris, GPM GV (SAIC)
;  - Created from geo_match_nc_structs.inc.
; 07/24/2013  Morris, GPM GV (SAIC)
;  - Add variables 'have_GR_rainrateStdDev', 'have_GR_rainrateMax', and
;    'have_GR_rainrate' to the field_flags structure to support GR rain rate.
; 4/22/14 by Bob Morris, GPM GV (SAIC)
;  - Removing all the have_XXXMAX and have_XXXStdDev variables from the
;    field_flags structure.  Removed them from the version 1.0 matchup netCDF
;    file definition.
;  - Added have_GR_xxx tag/value pairs to the field_flags structure for Zdr,
;    Kdp, RHOhv, HID, Dzero, and Nw.
; 4/28/14 by Bob Morris, GPM GV (SAIC)
;  - Changed value type to STRING from INT for DPR_Version and GMI_Version in
;    matchup_meta structure.
; 6/9/14 by Bob Morris, GPM GV (SAIC)
;  - Renamed have_GR_DP_XXX tags to have_GR_XXX in dpr_gr_field_flags structure.
;  - Added GV_UF_xxx_field tag/value pairs to "dpr_geo_match_meta", for xxx
;    types RR, XDR, KDP, RHOHV, HID, D0, and NW. Renamed GR_UF_Z_field tag to
;    GV_UF_Z_field for compatibility with PR-specific structure.
; 6/27/14 by Bob Morris, GPM GV (SAIC)
;  - Added have_paramDSD tag/value pairs to dpr_gr_field_flags structure.
; 11/04/14 by Bob Morris, GPM GV (SAIC)
;  - Added processing of GR RC and RP rainrate fields for version 1.1 file.
; 04/13/15 by Bob Morris, GPM GV (SAIC)
;  - Added tag/value pairs for piaFinal and heightStormTop to dpr_gr_field_flags
;    structure for version 1.1 file.
; 08/21/15 by Bob Morris, GPM GV (SAIC)
;  - Added tag/value pairs for GR Dm and N2 fields to dpr_geo_match_meta and
;    dpr_gr_field_flags structures for version 1.2 file.
; 11/05/15 by Bob Morris, GPM GV (SAIC)
;  - Added tag/value pairs for GR_blockage variable to dpr_gr_field_flags
;    structure for version 1.21 file.
; 02/04/16 by Bob Morris, GPM GV (SAIC)
;  - Added tag/value pairs for DPR Z fields computed from 250m range gates to 
;    dpr_gr_field_flags structures for version 1.3 file.
; 02/29/2016 by Bob Morris, GPM GV (SAIC)
;  - Added tag/value pairs for num_footprints, startScan, endScan, and num_rays
;    for HS/MS/NS swaths and for have_swath_HS and have_swath_HS to
;    dpr_geo_match_meta structure to support GR-only matchup file reading.
; 03/08/16 by Bob Morris, GPM GV (SAIC)
;  - Added tag/value pairs for GR_ROI_km to dpr_geo_match_meta structure.
; 08/03/16 by Bob Morris, GPM GV (SAIC)
;  - Added tag/value pair for have_Epsilon to dpr_gr_field_flags structure
;    for modified version 1.21 file.
; 12/12/16 by Bob Morris, GPM GV (SAIC)
;  - Added tag/value pair for have_qualityData to dpr_gr_field_flags structure.
;  - Added tag/value pair for DPR_decluttered to dpr_geo_match_meta structure.
; 10/18/17 by Bob Morris, GPM GV (SAIC)
;  - Added tag/value pairs for file_2apr and file_2bprtmi to dpr_gr_input_files
;    structure to support TRMM PR version 8 matchups.
; 08/30/18 by Todd Berendes (UAH)
;  - Added mods for optional mrms fields added by external program (java)
;  - Added tag/value pairs for SWERR1 (snow water equivalent RR)
;    computed as part of the matchup process
; 9/05/18 by Todd Berendes
;  - changed SWERR1 to SWEDP (Snow water equivalent dual pol GR)
;  - added SWE25, SWE50, SWE75 for snow PQPE relation (Pierre Kirstetter)
; 06/15/20 by Todd Berendes, UAH
;  - Modified from dpr_params.inc to use GPM Version 7 format for 06X and beyond
;  - Removed NS and MS swaths from DPR, added FS swath, HS swath dimensions are unchanged
; 
;
; EMAIL QUESTIONS OR COMMENTS AT:
;       https://pmm.nasa.gov/contact
;-
;===============================================================================

; "Include" files for constants, names, paths, etc.
@grid_def.inc   ; for NO_DATA_PRESENT
@dpr_params_v7.inc  ; for the type-specific fill values (FLOAT_RANGE_EDGE)

matchup_meta = { dpr_geo_match_meta,                           $
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
                 GV_UF_MW_field:        '',                    $
                 GV_UF_MI_field:        '',                    $
                 GV_UF_DM_field:        '',                    $
                 GV_UF_N2_field:        '',                    $
                 DPR_ScanType:          '',                    $
                 num_volumes:           0,                     $
                 num_sweeps:            0,                     $
                 num_footprints:        0,                     $
                 num_HID_categories:    0,                     $
                 num_scans:             0,                     $
                 num_rays:              0,                     $
                 num_footprints_HS:     0,                     $
                 num_footprints_FS_Ku:     0,                     $
                 num_footprints_FS_Ka:     0,                     $
                 startScan_HS:          0,                     $
                 endScan_HS:            0,                     $
                 num_rays_HS:           0,                     $
                 startScan_FS_Ku:          0,                     $
                 startScan_FS_Ka:          0,                     $
                 endScan_FS_Ku:            0,                     $
                 endScan_FS_Ka:            0,                     $
                 num_rays_FS_Ku:           0,                     $
                 num_rays_FS_Ka:           0,                     $
                 have_swath_HS:         NO_DATA_PRESENT,       $
                 rangeThreshold:        FLOAT_RANGE_EDGE,      $
                 GR_dBZ_min:            FLOAT_RANGE_EDGE,      $
                 DPR_dBZ_min:           FLOAT_RANGE_EDGE,      $
                 rain_min:              FLOAT_RANGE_EDGE,      $
                 gmi_rain_min:          FLOAT_RANGE_EDGE,      $
                 GR2GMI_dBZ_min:        FLOAT_RANGE_EDGE,      $
                 GR_ROI_km:             0.0,                   $
                 DPR_decluttered:       0,                     $
                 DPR_Version:           '',                    $
                 GMI_Version:           '',                    $
                 nc_file_version:       0.0,                   $
                 freezing_level_height:       -9999.,                    $
                 num_MRMS_categories:    0,                     $
                 MRMS_Mask_categories:       '',                    $
                 numDPRScans: 0   $
               }

;swath_match_meta = { dpr_gmi_match_meta,                           $
;                     timeNearestApproach:   0.0D,                  $
;                     atimeNearestApproach: '01-01-1970 00:00:00',  $
;                     num_scans:             0,                     $
;                     num_rays:              0,                     $
;                     gmi_rain_min:          FLOAT_RANGE_EDGE,      $
;                     averaging_radius:      0.0,                   $
;                     Map_Projection:       'Undefined',            $
;                     centerLat:             FLOAT_RANGE_EDGE,      $
;                     centerLon:             FLOAT_RANGE_EDGE,      $
;                     GPM_Version:           0,                     $
;                     nc_file_version:       0.0                    $
;                   }

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

field_flags =  { dpr_gr_field_flags,                        $
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
                 have_GR_liquidWaterContent: NO_DATA_PRESENT, $
                 have_GR_frozenWaterContent: NO_DATA_PRESENT, $
                 have_GR_Dm:               NO_DATA_PRESENT, $
                 have_GR_N2:               NO_DATA_PRESENT, $
                 have_GR_blockage:         NO_DATA_PRESENT, $
                 have_ZFactorMeasured:     NO_DATA_PRESENT, $
                 have_ZFactorCorrected:    NO_DATA_PRESENT, $
                 have_ZFactorMeasured250m:     NO_DATA_PRESENT, $
                 have_ZFactorCorrected250m:    NO_DATA_PRESENT, $
                 have_piaFinal:            NO_DATA_PRESENT, $
                 have_PrecipRate:          NO_DATA_PRESENT, $
                 have_Epsilon:             NO_DATA_PRESENT, $
                 have_paramDSD:            NO_DATA_PRESENT, $
                 have_LandSurfaceType:     NO_DATA_PRESENT, $
                 have_PrecipRateSurface:   NO_DATA_PRESENT, $
                 have_SurfPrecipRate:      NO_DATA_PRESENT, $
                 have_heightStormTop:      NO_DATA_PRESENT, $
                 have_BBheight:            NO_DATA_PRESENT, $
                 have_FlagPrecip:          NO_DATA_PRESENT, $
                 have_TypePrecip:          NO_DATA_PRESENT, $
                 have_BBstatus:            NO_DATA_PRESENT, $
                 have_qualityData:         NO_DATA_PRESENT, $
                 have_clutterStatus:       NO_DATA_PRESENT,  $
                 have_mrms:       		NO_DATA_PRESENT,  $
                 have_GR_SWE:       	NO_DATA_PRESENT,  $
                 have_pwatIntegrated:       	NO_DATA_PRESENT  $
               }

;field_flags_gmi =  { gmi_gr_field_flags,                           $
;                     have_GR_Z_along_TMI:         NO_DATA_PRESENT, $
;                     have_GR_Z_Max_along_TMI:     NO_DATA_PRESENT, $
;                     have_GR_Z_StdDev_along_TMI:  NO_DATA_PRESENT, $
;                     have_GR_Z_VPR:               NO_DATA_PRESENT, $
;                     have_GR_Z_Max_VPR:           NO_DATA_PRESENT, $
;                     have_GR_Z_StdDev_VPR:        NO_DATA_PRESENT, $
;                     have_surfaceType:            NO_DATA_PRESENT, $
;                     have_surfaceRain:            NO_DATA_PRESENT, $
;                     have_rainFlag:               NO_DATA_PRESENT, $
;                     have_dataFlag:               NO_DATA_PRESENT, $
;                     have_PoP:                    NO_DATA_PRESENT, $
;                     have_freezingHeight:         NO_DATA_PRESENT  $
;                   }

;field_flags_swath =  { dpr_gmi_field_flags,                          $
;                       have_surfaceType:            NO_DATA_PRESENT, $
;                       have_surfaceRain:            NO_DATA_PRESENT, $
;                       have_rainFlag:               NO_DATA_PRESENT, $
;                       have_dataFlag:               NO_DATA_PRESENT, $
;                       have_PoP:                    NO_DATA_PRESENT, $
;                       have_freezingHeight:         NO_DATA_PRESENT, $
;                       have_nearSurfRain:           NO_DATA_PRESENT, $
;                       have_nearSurfRain_2b31:      NO_DATA_PRESENT, $
;                       have_BBheight:               NO_DATA_PRESENT, $
;                       have_prrainFlag:             NO_DATA_PRESENT, $
;                       have_rainType:               NO_DATA_PRESENT  $
;                   }

files_meta  =  { dpr_gr_input_files,        $
                 file_2adpr:   'UNDEFINED', $
                 file_2aka:    'UNDEFINED', $
                 file_2aku:    'UNDEFINED', $
                 file_2bcomb:  'UNDEFINED', $
                 file_1cuf:    'UNDEFINED', $
                 file_2apr:    'UNDEFINED', $
                 file_2bprtmi: 'UNDEFINED'  $
               }
