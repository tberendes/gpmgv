;===============================================================================
;+
; Copyright © 2008, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; geo_match_nc_structs.inc          Morris/SAIC/GPM_GV      September 2008
;
; DESCRIPTION
; -----------
; Defines structures to hold GV site names and locations, data and algorithm
; parameters, and flags indicating whether data variables are actual data or
; fill values, as read from the PR-GV matchup netCDF data files.
;
; HISTORY:
; 09/7/2010  Morris, GPM GV (SAIC)
;  - Added num_volumes to geo_match_meta structure to accomodate geo-match
;    netCDF files with multiple ground radar volume scans.
; 09/16/2010  Morris, GPM GV (SAIC)
;  - Added site_elev variable to gv_site_meta structure to support version 1.1
;    PR-GV matchup netCDF data files.
; 11/15/2010  Morris, GPM GV (SAIC)
;  - Add variables 'have_threeDreflectStdDev', 'have_threeDreflectMax',
;    have_BBstatus, and have_status_2a23 to the field_flags structure to
;    support version 2.0 geo-match netCDF file
; 3/25/2011  Morris, GPM GV (SAIC)
;  - Added 'files_meta' structure to hold names of the PR and GR files used in
;    the matchup processing to support version 2.1 geo-match netCDF file and
;    future TMI 2A12 product matchups.
; 6/1/2011  Morris, GPM GV (SAIC)
;  - Added elements for TMI-GR matchups to matchup_meta, and defined new
;    structure tmi_field_flags since many variables are new or renamed for TMI.
; 7/14/11  Morris, GPM GV (SAIC)
;  - Added have_freezingHeight and have_PoP to tmi_field_flags structure.
; 12/11/12  Morris, GPM GV (SAIC)
;  - Added swath_match_meta and field_flags_swath structures for PR-TMI along-
;    swath matchup netCDF files.
; 07/23/2013  Morris, GPM GV (SAIC)
;  - Add variables 'have_GR_DP_rainrateStdDev', 'have_GR_DP_rainrateMax', and
;    'have_GR_DP_rainrate' to the field_flags structure to support version 2.2
;    geo-match netCDF file.
; 10/17/2013  Morris, GPM GV (SAIC)
;  - Add "have_GR_RR_" variables to tmi_gv_field_flags structure for Version 2.0
;    GRtoTMI netCDF files.
; 01/27/2014  Morris, GPM GV (SAIC)
;  - Add variables 'have_GR_DP_HID', 'have_GR_DP_Dzero', and 'have_GR_DP_Nw'
;    to the field_flags structure to support version 2.3 geo-match netCDF file.
; 01/27/2014  Morris, GPM GV (SAIC)
;  - Added num_HID_categories to matchup_meta structure for version 2.3.
; 2/12/14 by Bob Morris, GPM GV (SAIC)
;  - Added Max and StdDev for GR D0 and Nw "have" variables, and added Mean,
;    Max, and StdDev GR "have" variables for Zdr, Kdp, and RHOhv fields in
;    field_flags structure.
;  - Added UF field ID tag/value pairs for RR, ZDR, KDP, RHOHV, HID, D0, and NW
;    to the matchup_meta structure.
; 3/23/14 by Bob Morris, GPM GV (SAIC)
;  - Added PPS_Version string variable to matchup_meta structure for product
;    versions in 'VnnX' character format in GPM-era PPS product files.
;  - Added file_2agprof, file_2aku, file_2aka, file_2adpr, and file_2adprgmi
;    to the files_meta structure.
;  - Added field_flags_gprof structure for GRtoGPROF matchup file variables,
;    leaving out the various have_StdDev and have_Max flag variables, which
;    are redundant and no longer in the matchup file of this flavor.
; 4/22/14 by Bob Morris, GPM GV (SAIC)
;  - Removing all the have_XXXMAX and have_XXXStdDev variables from the
;    field_flags structure.  Removed them from the version 3.0 matchup netCDF
;    file definition.
; 6/9/14 by Bob Morris, GPM GV (SAIC)
;  - Renamed have_GR_DP_XXX tags to have_GR_XXX for compatibility with DPR
;    field_flags named structure "dpr_gr_field_flags".  See "include" file
;    dpr_geo_match_nc_structs.inc.
; 9/25/14 by Bob Morris, GPM GV (SAIC)
;  - Added dpr_gmi_field_flags structure for DPRtoGMI orbit matchup file
;    variables.
; 11/06/14 by Bob Morris, GPM GV (SAIC)
;  - Added items to geo_match_meta and gprof_gv_field_flags structures for GR
;    RC and RP rainrate fields for version 1.1 GRtoGPROF file.
; 04/16/15 by Bob Morris, GPM GV (SAIC)
;  - Added tag/value pairs for PIA to pr_gv_field_flags structure.
; 11/13/15 by Bob Morris, GPM GV (SAIC)
;  - Added have_GR_blockage_slantPath and have_GR_blockage_VPR tag/value pairs
;    to gprof_gv_field_flags structure.
; 07/07/16 by Bob Morris, GPM GV (SAIC)
;  - Added have_Tc to gprof_gv_field_flags structure and added file_1crxcal to
;    input_files structure.
; 06/20/18 by Bob Morris, GPM GV (SAIC)
;  - Added file_2apr and file_2bprgmi to the files_meta structure.
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;===============================================================================

; "Include" files for constants, names, paths, etc.
@grid_def.inc   ; for NO_DATA_PRESENT
@pr_params.inc  ; for the type-specific fill values (FLOAT_RANGE_EDGE)

matchup_meta = { geo_match_meta,                               $
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
                 num_volumes:           0,                     $
                 num_sweeps:            0,                     $
                 num_footprints:        0,                     $
                 num_HID_categories:    0,                     $
                 rangeThreshold:        FLOAT_RANGE_EDGE,      $
                 GV_dBZ_min:            FLOAT_RANGE_EDGE,      $
                 PR_dBZ_min:            FLOAT_RANGE_EDGE,      $
                 rain_min:              FLOAT_RANGE_EDGE,      $
                 tmi_rain_min:          FLOAT_RANGE_EDGE,      $
                 GV2TMI_dBZ_min:        FLOAT_RANGE_EDGE,      $
                 PR_Version:            0,                     $
                 TMI_Version:           0,                     $
                 PPS_Version:           '',                    $
                 nc_file_version:       0.0                    $
               }

swath_match_meta = { pr_tmi_match_meta,                            $
                     timeNearestApproach:   0.0D,                  $
                     atimeNearestApproach: '01-01-1970 00:00:00',  $
                     num_scans:             0,                     $
                     num_rays:              0,                     $
                     tmi_rain_min:          FLOAT_RANGE_EDGE,      $
                     averaging_radius:      0.0,                   $
                     Map_Projection:       'Undefined',            $
                     centerLat:             FLOAT_RANGE_EDGE,      $
                     centerLon:             FLOAT_RANGE_EDGE,      $
                     TRMM_Version:          0,                     $
                     nc_file_version:       0.0                    $
                   }

sweeps_meta =  { gv_sweep_meta,                           $
                 elevationAngle:   FLOAT_RANGE_EDGE,      $
                 timeSweepStart:   0.0D,                  $
                 atimeSweepStart: '01-01-1970 00:00:00'   $
               }

site_meta =    { gv_site_meta,    $
                 site_lat:  0.0,  $
                 site_lon:  0.0,  $
                 site_id:    '',  $
                 site_elev: 0.0   $
               }

field_flags =  { pr_gv_field_flags,                          $
                 have_threeDreflect:        NO_DATA_PRESENT, $
                 have_GR_Zdr:               NO_DATA_PRESENT, $
                 have_GR_Kdp:               NO_DATA_PRESENT, $
                 have_GR_RHOhv:             NO_DATA_PRESENT, $
                 have_GR_rainrate:          NO_DATA_PRESENT, $
                 have_GR_HID:               NO_DATA_PRESENT, $
                 have_GR_Dzero:             NO_DATA_PRESENT, $
                 have_GR_Nw:                NO_DATA_PRESENT, $
                 have_dBZnormalSample:      NO_DATA_PRESENT, $
                 have_correctZFactor:       NO_DATA_PRESENT, $
                 have_PIA:                  NO_DATA_PRESENT, $
                 have_rain:                 NO_DATA_PRESENT, $
                 have_landOceanFlag:        NO_DATA_PRESENT, $
                 have_nearSurfRain:         NO_DATA_PRESENT, $
                 have_nearSurfRain_2b31:    NO_DATA_PRESENT, $
                 have_BBheight:             NO_DATA_PRESENT, $
                 have_rainFlag:             NO_DATA_PRESENT, $
                 have_rainType:             NO_DATA_PRESENT, $
                 have_BBstatus:             NO_DATA_PRESENT, $
                 have_status_2a23:          NO_DATA_PRESENT  $
               }

field_flags_tmi =  { tmi_gv_field_flags,                           $
                     have_GR_Z_along_TMI:         NO_DATA_PRESENT, $
                     have_GR_Z_Max_along_TMI:     NO_DATA_PRESENT, $
                     have_GR_Z_StdDev_along_TMI:  NO_DATA_PRESENT, $
                     have_GR_Z_VPR:               NO_DATA_PRESENT, $
                     have_GR_Z_Max_VPR:           NO_DATA_PRESENT, $
                     have_GR_Z_StdDev_VPR:        NO_DATA_PRESENT, $
                     have_GR_RR_along_TMI:        NO_DATA_PRESENT, $
                     have_GR_RR_Max_along_TMI:    NO_DATA_PRESENT, $
                     have_GR_RR_StdDev_along_TMI: NO_DATA_PRESENT, $
                     have_GR_RR_VPR:              NO_DATA_PRESENT, $
                     have_GR_RR_Max_VPR:          NO_DATA_PRESENT, $
                     have_GR_RR_StdDev_VPR:       NO_DATA_PRESENT, $
                     have_surfaceType:            NO_DATA_PRESENT, $
                     have_surfaceRain:            NO_DATA_PRESENT, $
                     have_rainFlag:               NO_DATA_PRESENT, $
                     have_dataFlag:               NO_DATA_PRESENT, $
                     have_PoP:                    NO_DATA_PRESENT, $
                     have_freezingHeight:         NO_DATA_PRESENT  $
                   }

field_flags_gprof =  { gprof_gv_field_flags,                         $
                       have_GR_Z_slantPath:         NO_DATA_PRESENT, $
                       have_GR_Z_VPR:               NO_DATA_PRESENT, $
                       have_GR_RC_slantPath:        NO_DATA_PRESENT, $
                       have_GR_RC_VPR:              NO_DATA_PRESENT, $
                       have_GR_RP_slantPath:        NO_DATA_PRESENT, $
                       have_GR_RP_VPR:              NO_DATA_PRESENT, $
                       have_GR_RR_slantPath:        NO_DATA_PRESENT, $
                       have_GR_RR_VPR:              NO_DATA_PRESENT, $
                       have_GR_ZDR_slantPath:       NO_DATA_PRESENT, $
                       have_GR_ZDR_VPR:             NO_DATA_PRESENT, $
                       have_GR_KDP_slantPath:       NO_DATA_PRESENT, $
                       have_GR_KDP_VPR:             NO_DATA_PRESENT, $
                       have_GR_RHOHV_slantPath:     NO_DATA_PRESENT, $
                       have_GR_RHOHV_VPR:           NO_DATA_PRESENT, $
                       have_GR_HID_slantPath:       NO_DATA_PRESENT, $
                       have_GR_HID_VPR:             NO_DATA_PRESENT, $
                       have_GR_DZERO_slantPath:     NO_DATA_PRESENT, $
                       have_GR_DZERO_VPR:           NO_DATA_PRESENT, $
                       have_GR_NW_slantPath:        NO_DATA_PRESENT, $
                       have_GR_NW_VPR:              NO_DATA_PRESENT, $
                       have_GR_blockage_slantPath:  NO_DATA_PRESENT, $
                       have_GR_blockage_VPR:        NO_DATA_PRESENT, $
                       have_surfaceTypeIndex:       NO_DATA_PRESENT, $
                       have_surfacePrecipitation:   NO_DATA_PRESENT, $
                       have_pixelStatus:            NO_DATA_PRESENT, $
                       have_PoP:                    NO_DATA_PRESENT, $
                       have_Tc:                     NO_DATA_PRESENT  $
                     }

field_flags_swath =  { pr_tmi_field_flags,                           $
                       have_surfaceType:            NO_DATA_PRESENT, $
                       have_surfaceRain:            NO_DATA_PRESENT, $
                       have_rainFlag:               NO_DATA_PRESENT, $
                       have_dataFlag:               NO_DATA_PRESENT, $
                       have_PoP:                    NO_DATA_PRESENT, $
                       have_freezingHeight:         NO_DATA_PRESENT, $
                       have_nearSurfRain:           NO_DATA_PRESENT, $
                       have_nearSurfRain_2b31:      NO_DATA_PRESENT, $
                       have_BBheight:               NO_DATA_PRESENT, $
                       have_prrainFlag:             NO_DATA_PRESENT, $
                       have_rainType:               NO_DATA_PRESENT  $
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

files_meta  =  { input_files,                $
                 file_1c21:     'UNDEFINED', $
                 file_1crxcal:  'UNDEFINED', $
                 file_2a12:     'UNDEFINED', $
                 file_2a23:     'UNDEFINED', $
                 file_2a25:     'UNDEFINED', $
                 file_2b31:     'UNDEFINED', $
                 file_2agprof:  'UNDEFINED', $
                 file_2adpr:    'UNDEFINED', $
                 file_2Aku:     'UNDEFINED', $
                 file_2Aka:     'UNDEFINED', $
                 file_2adprgmi: 'UNDEFINED', $
                 file_2apr:     'UNDEFINED', $
                 file_2bprgmi:  'UNDEFINED', $
                 file_1cuf:     'UNDEFINED'  $
               }
