FUNCTION get_site_specific_z_volume, siteID, radar, z_field, UF_FIELD=uf_field

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
; Retrieves the "volume" number of the quality-controlled reflectivity field
; for a specified radar, from a caller-provided 'radar' structure of the TRMM
; Radar Software Library.  The desired reflectivity "field_type" is
; radar-site-specific.  Selection of the field is coded as CASE statement,
; where the site ID is the case switch.  If the site ID is not found, the
; "field_type" is assumed to be 'CZ' by default (the case for WSR-88D site IDs).
;
; HISTORY
; -------
; 8/21/08 - Morris/NASA/GSFC (SAIC), GPM GV:  Created.
; 9/17/08 - Morris/NASA/GSFC (SAIC), GPM GV:  Added z_field to I/O parameters.
; 11/3/09 - Morris/NASA/GSFC (SAIC), GPM GV:  Added radars CP2 and NCU to CASE
; 11/27/09 - Morris/NASA/GSFC (SAIC), GPM GV:  Added capability to retrieve a
;            specified UF field ID, UF_FIELD, rather than the default Z field
;
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;=============================================================================

IF ( N_ELEMENTS(uf_field) EQ 0 ) THEN BEGIN
   ; get the volume for the site-specific Z field by default
    CASE siteID of
       'DARW' : BEGIN
                   field1 = 'UZ'
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
                  field1 = 'ZH'
                END
         ELSE : BEGIN
                  field1 = 'CZ'
                END
    ENDCASE
ENDIF ELSE BEGIN
   ; get the volume for the caller-specified field
    IF ( N_ELEMENTS(uf_field) EQ 1 ) THEN BEGIN
       field1 = uf_field
    ENDIF ELSE BEGIN
       print, 'In get_site_specific_z_volume(), UF_FIELD must be single value!'
       print, 'UF_FIELD as requested: ', uf_field
       field1=''
    ENDELSE
ENDELSE


    fields = radar.volume.h.field_type
    volnum = WHERE( fields EQ field1, countvols )
    IF ( countvols EQ 1 ) THEN BEGIN
       z_field = field1
       RETURN, volnum
    ENDIF ELSE BEGIN
       print, ""
       print, "ERROR in get_site_specific_z_volume(), valid volnum not found"
       print, "for site ID = ", siteID, ".  Available fields = ", fields
       print, ""
       RETURN, -1
    ENDELSE
END
