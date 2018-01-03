;+
; Copyright © 2013, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; get_dpr_verenv_group.pro         Bob Morris, GPM GV/SAIC   June 2013
;
; DESCRIPTION
; Given the HDF5 ID of its parent group, gets each data element for the DPR,
; Ka, or Ku VERENV Group and returns a structure containing the individual 
; element names as the structure tags, and the VERENV element data arrays
; as the structure values.  Returns -1 in case of errors.
;
; PARAMETERS
; ----------
; group_id  -- HDF5 ID of the parent group of the VERENV group
; prodgroup -- String with the AlgorithmID and parent Swath name together,
;              separated by '__', e.g., '2AKuENV__NS'
;
; HISTORY
; -------
; 06/03/13  Morris/GPM GV/SAIC
; - Created from get_dpr_ver_group.pro.
; 01/08/14  Morris/GPM GV/SAIC
; - Replaced groundTemperature with skinTemperature and surfaceTemperature to
;   match current baseline file specification.
; 11/25/15  Morris/GPM GV/SAIC
; - Removed the logic of testing for a specific number of members, just check
;   for a minimum number of variables.  In cases of new/unknown variables in
;   group return valid structure instead of -1 flag.
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-

FUNCTION get_dpr_verenv_group, group_id, prodgroup

   gname = 'VERENV'
   label = prodgroup+'/'+gname      ; label info for data structure

   ; get the ID of VERENV group
   ; -- check that this group contains a VERENV group
   CATCH, error
   IF error EQ 0 THEN BEGIN
      ss_group_id = h5g_open(group_id, gname)
   ENDIF ELSE BEGIN
      help,!error_state,/st
      Catch, /Cancel
      message, 'err='+STRING(error)+", "+!error_state.msg, /INFO
      return, -1
   ENDELSE
   Catch, /Cancel

   nmbrs = h5g_get_nmembers(group_id, gname)
;   print, "No. Members = ", nmbrs
   ; extract the 8 expected date/time field values one by one
   IF nmbrs GE 8 THEN BEGIN
      dtnames=STRARR(nmbrs)
      for immbr = 0, nmbrs-1 do begin
         dtnames[immbr] = h5g_get_member_name(group_id, gname, immbr)
;        print, dtnames[immbr]
         dtID = h5d_open(ss_group_id, dtnames[immbr])
         CASE dtnames[immbr] OF
                     'airPressure' : airPressure = h5d_read(dtID)
                  'airTemperature' : airTemperature = h5d_read(dtID)
                'cloudLiquidWater' : cloudLiquidWater = h5d_read(dtID)
                 'skinTemperature' : skinTemperature = h5d_read(dtID)
              'surfaceTemperature' : surfaceTemperature = h5d_read(dtID)
                 'surfacePressure' : surfacePressure = h5d_read(dtID)
                     'surfaceWind' : surfaceWind = h5d_read(dtID)
                      'waterVapor' : waterVapor = h5d_read(dtID)
            ELSE : BEGIN
                      message, "Unknown group member: "+dtnames[immbr], /INFO
;                      return, -1
                   END
         ENDCASE
         dtval = h5d_read(dtID)
;         print, dtval[0]
;         h5d_close, dtID
      endfor
   ENDIF ELSE BEGIN
      message, STRING(nmbrs, FORMAT='(I0)')+" not 8 members in group '" $
               +gname+"'", /INFO
      return, -1
   ENDELSE

   h5g_close, ss_group_id

   ; have to use anonymous structures since variable dimensions change!
   VERENV_struc = { source : label, $
                    airPressure : airPressure, $
                    airTemperature : airTemperature, $
                    cloudLiquidWater : cloudLiquidWater, $
                    skinTemperature : skinTemperature, $
                    surfaceTemperature : surfaceTemperature, $
                    surfacePressure : surfacePressure, $
                    surfaceWind : surfaceWind, $
                    waterVapor : waterVapor }

return, VERENV_struc
end
