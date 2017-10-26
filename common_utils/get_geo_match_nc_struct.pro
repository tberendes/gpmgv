;===============================================================================
;+
; Copyright © 2010, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; get_geo_match_nc_struct.pro        Morris/SAIC/GPM_GV    Nov. 2010
;
; DESCRIPTION
; -----------
; Returns an initialized structure of the type requested, from those structures
; defined in 'geo_match_nc_structs.inc', to hold data values to be read from a
; geometry-match netCDF file.  Data values are initialized to default values
; defined in 'geo_match_nc_structs.inc', rather than just set to 0 or empty
; strings as would be the case if just creating the structure variable from the
; template in the .inc file.
;
; HISTORY
; -------
; 11/16/10 - Morris/NASA/GSFC (SAIC), GPM GV
;  - Created.
; 3/28/11  - Morris/NASA/GSFC (SAIC), GPM GV
;  - Added 'files' option to retrieve PR and GR filenames from v2.1 matchup file
; 6/1/11   - Morris/NASA/GSFC (SAIC), GPM GV
;  - Added structure field_flags_tmi for TMI-GR matchup netCDF files.
; 12/11/12 - Morris/NASA/GSFC (SAIC), GPM GV
;  - Added structures swath_match_meta and field_flags_swath for PR-TMI matchup
;    files.
; 03/24/14 - Morris/NASA/GSFC (SAIC), GPM GV
;  - Added structure field_flags_gprof for GRtoGPROF matchup netCDF files.
; 9/25/14  - Morris/NASA/GSFC (SAIC), GPM GV
;  - Added structure field_flags_swath_gpm for DPR-GMI orbit matchups.
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;===============================================================================

FUNCTION get_geo_match_nc_struct, typename

; "include" file for structure definitions
  @geo_match_nc_structs.inc

  IF N_PARAMS() EQ 1 THEN BEGIN
     CASE typename OF
        'matchup'          : the_struc = matchup_meta
        'swathmatch'       : the_struc = swath_match_meta
        'sweeps'           : the_struc = sweeps_meta
        'site'             : the_struc = site_meta
        'fields'           : the_struc = field_flags
        'files'            : the_struc = files_meta
        'fields_tmi'       : the_struc = field_flags_tmi
        'fields_gprof'     : the_struc = field_flags_gprof
        'fields_swath'     : the_struc = field_flags_swath
        'fields_swath_gpm' : the_struc = field_flags_swath_gpm
        ELSE : BEGIN
               print, 'Illegal type requested in get_geo_match_nc_struct(): ', typename
               print, "Allowable type values include only one of the following: "
               print, "matchup swathmatch sweeps site fields files fields_tmi fields_gprof fields_swath"
               the_struc = -1
               END
     ENDCASE
  ENDIF ELSE BEGIN
     print, 'Incorrect number of parameters in get_geo_match_nc_struct(), one expected.'
     the_struc = -1
  ENDELSE

return, the_struc
end
