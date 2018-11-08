;=============================================================================
;+
; Copyright © 2008, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; get_site_specific_z_volume.pro      Morris/SAIC/GPM_GV      August 2008
;
; DESCRIPTION
; -----------
; Retrieves the "volume" number of the quality-controlled reflectivity or other
; field for a specified radar, from a caller-provided 'radar' structure of the
; TRMM Radar Software Library.  The default "field_type" is for reflectivity,
; and is radar-site-specific.  Selection of the field is coded as CASE statement
; where the site ID is the case switch.  If the site ID is not found in the CASE
; switch, the default "field_type" is assumed to be 'CZ' (the case for all
; WSR-88D site IDs).
;
; If the default or caller-specified field is not found in the radar structure,
; a value of -1 is returned for the volume number and z_field is set to the
; empty string.
;
; PARAMETERS
; ----------
; siteID   - The assigned call letters of the radar whose data are being
;            processed.
; radar    - The 'radar' structure read from the radar data file by the RSL.
; z_field  - The field type associated with the volume number found for the
;            default reflectivity field, or simply a copy of uf_field if its
;            volume is found.
; uf_field - Optional keyword parameter to specify a non-default UF data field
;            whose volume number is to be found.
;
; HISTORY
; -------
; 8/21/08 - Morris/NASA/GSFC (SAIC), GPM GV:  Created.
; 9/17/08 - Morris/NASA/GSFC (SAIC), GPM GV:  Added z_field to I/O parameters.
; 11/3/09 - Morris/NASA/GSFC (SAIC), GPM GV:  Added radars CP2 and NCU to CASE
; 11/27/09 - Morris/NASA/GSFC (SAIC), GPM GV:  Added capability to retrieve a
;            specified UF field ID, UF_FIELD, rather than the default Z field
; 7/18/13 - Morris/NASA/GSFC (SAIC), GPM GV:  Added check for empty uf_field
;            and changed error messaging output.  Added PARAMETERS definitions.
; 7/17/14 - Morris/NASA/GSFC (SAIC), GPM GV:  Added CHILL radar to CASE
; 3/5/15  - Morris/NASA/GSFC (SAIC), GPM GV:  Changed DARW default Z ID from UZ
;            to CZ, added CPOL site ID as DARW alias.
; 5/21/15 - Morris/NASA/GSFC (SAIC), GPM GV:  Changed CP2 default Z ID from ZH
;            to ZC.  Added CP2 to the radars whose UF IDs are translated to
;            those used at DARW/CPOL.
; 5/10/16 - Morris/NASA/GSFC (SAIC), GPM GV:  Added Argentina radar IDs (INTA_*
;            and their actual names) to Z field CASE switch.
;
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;=============================================================================

FUNCTION get_site_specific_z_volume, siteID, radar, z_field, UF_FIELD=uf_field

IF ( N_ELEMENTS(uf_field) EQ 0 ) THEN BEGIN
   ; get the volume for the site-specific Z field by default
    CASE siteID of
       'CPOL' : BEGIN
       			  field1 = 'CZ' 
                END
       'DARW' : BEGIN
                  field1 = 'CZ' 
                END
       'RMOR' : BEGIN
                  field1 = 'CZ' & mnem1 = 'PROPOG_COR'
                  field2 = 'DZ' & mnem2 = 'NO_PROPOG_COR'
                END
       'RGSN' : BEGIN
                  field1 = 'CZ'
                END
        'NCU' : BEGIN
                  field1 = 'ZH'
                END
        'CP2' : BEGIN
                  field1 = 'ZC'
                END
      'CHILL' : BEGIN
                  field1 = 'DZ'
                END
        'Anguil' :  field1 = 'DZ'
   'INTA_Anguil' :  BEGIN
                      field1 = 'DZ'
                    END
     'Bariloche' :  field1 = 'DZ'
'INTA_Bariloche' :  field1 = 'DZ'
       'Cordoba' :  field1 = 'DZ'
  'INTA_Cordoba' :  field1 = 'DZ'
        'Parana' :  field1 = 'DZ'
   'INTA_Parana' :  field1 = 'DZ'
     'Pergamino' :  field1 = 'DZ'
'INTA_Pergamino' :  field1 = 'DZ'
            ELSE : BEGIN
                      field1 = 'CZ'
                    END
    ENDCASE
ENDIF ELSE BEGIN
   ; get the volume for the caller-specified field
    IF ( N_ELEMENTS(uf_field) EQ 1 AND uf_field NE '' ) THEN BEGIN
      ; translate to the alternate UF IDs for DARW/CPOL and CP2
;       IF siteID EQ 'DARW' OR siteID EQ 'CPOL' OR siteID EQ 'CP2' THEN BEGIN
       IF siteID EQ 'CPOL' OR siteID EQ 'CP2' THEN BEGIN
          CASE uf_field OF
             'FH' : field1 = 'HC'
             'DR' : field1 = 'ZD'
             'D0' : field1 = 'DO'
             'RP' : field1 = 'RR'         ; CPOL/CP2 RR maps to RP in matchups
             'RR' : field1 = 'RR_is_RP'   ; disable RR retrieval, CPOL RR is RP
             ELSE : field1 = uf_field
          ENDCASE
       ENDIF ELSE IF siteID EQ 'DARW' THEN BEGIN
           CASE uf_field OF
             'RP' : field1 = 'RR'         ; CPOL/CP2 RR maps to RP in matchups
             'RR' : field1 = 'RR_is_RP'   ; disable RR retrieval, CPOL RR is RP       
             ELSE : field1 = uf_field
           ENDCASE
       ENDIF ELSE field1 = uf_field
    ENDIF ELSE BEGIN
       message, 'UF_FIELD must be single, non-empty value!', /INFO
       print, "UF_FIELD as requested: '", uf_field, "'"
       print, ""
       RETURN, -1
    ENDELSE
ENDELSE

fields = radar.volume.h.field_type
volnum = WHERE( fields EQ field1, countvols )
IF ( countvols EQ 1 ) THEN BEGIN
   z_field = field1
   RETURN, volnum
ENDIF ELSE BEGIN
   print, ""
   message, "Valid volume not found for site ID '" +siteID+ "', field '" $
            +field1+ "'", /INFO
   print, "Available fields: ", fields
   print, ""
   RETURN, -1
ENDELSE

END
