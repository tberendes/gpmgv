;===============================================================================
;+
; Copyright © 2013, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; get_dpr_geo_match_nc_struct_mrms.pro        Morris/SAIC/GPM_GV    July 2013
;
; DESCRIPTION
; -----------
; Returns an initialized structure of the type requested, from those structures
; defined in 'geo_match_nc_structs.inc', to hold data values to be read from a
; geometry-match netCDF file.  Data values are initialized to default values
; defined in 'dpr_geo_match_nc_structs.inc', rather than just set to 0 or empty
; strings as would be the case if just creating the structure variable from the
; template in the .inc file.
;
; HISTORY
; -------
; 07/12/13 - Morris/NASA/GSFC (SAIC), GPM GV
;  - Created from get_geo_match_nc_struct.pro
;
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;===============================================================================

FUNCTION get_dpr_geo_match_nc_struct_mrms, typename

; "include" file for structure definitions
  @dpr_geo_match_nc_structs_mrms.inc

  IF N_PARAMS() EQ 1 THEN BEGIN
     CASE typename OF
        'matchup'      : the_struc = matchup_meta
;        'swathmatch'   : the_struc = swath_match_meta    ; deferred
        'sweeps'       : the_struc = sweeps_meta
        'site'         : the_struc = site_meta
        'fields'       : the_struc = field_flags
        'files'        : the_struc = files_meta
;        'fields_gmi'   : the_struc = field_flags_gmi     ; deferred
;        'fields_swath' : the_struc = field_flags_swath   ; deferred
        ELSE : BEGIN
               print, 'Illegal type requested in get_dpr_geo_match_nc_struct(): ', typename
               print, "Allowable type values include only one of the following: "
               print, "matchup sweeps site fields files"
               the_struc = -1
               END
     ENDCASE
  ENDIF ELSE BEGIN
     print, 'Incorrect number of parameters in get_dpr_geo_match_nc_struct(), one expected.'
     the_struc = -1
  ENDELSE

return, the_struc
end
