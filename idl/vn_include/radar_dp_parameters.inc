;===============================================================================
;+
; Copyright © 2014, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; radar_dp_parameters.pro          Morris/SAIC/GPM_GV      January 2014
;
; DESCRIPTION
; -----------
; Defines structures to hold ground radar dual-polarization field definition
; parameters, as written to/read from the PR-GR matchup netCDF data files.
;
; HISTORY
; -------
; 01/27/2014  Morris, GPM GV (SAIC)
; - Created.
;
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;===============================================================================

FUNCTION radar_dp_parameters

   N_HID_CATEGORIES = 15   ; number of Hydromet Identifier Categories, including
                           ; SPARE slots not yet defined

   HID_CAT_STRUCTS = REPLICATE({value:0, ID:'MM', description:'Missing data'}, $
                               N_HID_CATEGORIES)
   hcsValues = [0,1,2,3,4,5,6,7,8,9,10,11,12,13,14]
   hcsIDs = ['MM','DZ','RN','CR','DS','WS','VI','LDG','HDG','HA','BD', $
             'S1','S2','S3','S4']
   hcsDescrip=['Missing data', 'Drizzle', 'Rain', 'Ice Crystals', $
               'Aggregates', 'Wet Snow', 'Vertical Ice', $
               'Low Density Graupel', 'High Density Graupel', 'Hail', $
               'Big Drops', 'Spare1', 'Spare2', 'Spare3', 'Spare4']
   FOR hcat = 0, N_HID_CATEGORIES-1 DO BEGIN
      HID_CAT_STRUCTS[hcat].value = hcsValues[hcat]
      HID_CAT_STRUCTS[hcat].ID = hcsIDs[hcat]
      HID_CAT_STRUCTS[hcat].description = hcsDescrip[hcat]
   ENDFOR

   radar_dp_parm_struct = { n_hid_cats : N_HID_CATEGORIES, $
                            hid_cat_defs : HID_CAT_STRUCTS }

   return, radar_dp_parm_struct
END
