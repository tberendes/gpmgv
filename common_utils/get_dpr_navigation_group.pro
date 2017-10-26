;+
; Copyright © 2014, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; get_dpr_navigation_group.pro         Bob Morris, GPM GV/SAIC   Jan 2014
;
; DESCRIPTION
; Given the HDF5 ID of its parent group, gets each data element for the DPR,
; Ka, or Ku navigation Group and returns a structure containing the individual 
; element names as the structure tags, and the navigation element data arrays
; as the structure values.  Returns -1 in case of errors.
;
; PARAMETERS
; ----------
; group_id  -- HDF5 ID of the parent group of the navigation group
; prodgroup -- String with the AlgorithmID and parent Swath name together,
;              separated by '__', e.g., '2AKu__NS'
; read_all  -- Binary parameter.  If set, then read and return all datasets in
;              the groups.  Otherwise, just read the datasets needed for basic
;              display and processing (subjective list).
;
; HISTORY
; -------
; 01/08/14  Morris/GPM GV/SAIC
; - Created from get_dpr_scanstatus_group.pro.
; 11/25/15  Morris/GPM GV/SAIC
; - Removed the logic of testing for a specific number of members, just check
;   for a minimum number of variables.  In cases of new/unknown variables in
;   group return valid structure instead of -1 flag.
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-

FUNCTION get_dpr_navigation_group, group_id, prodgroup, READ_ALL=read_all

   all = KEYWORD_SET(read_all)

   gname = 'navigation'
   label = prodgroup+'/'+gname      ; label info for data structure

   ; get the ID of navigation group
   ; -- check that this group contains a navigation group
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
   ; extract the 15 expected date/time field values one by one
   IF nmbrs GE 15 THEN BEGIN
      dtnames=STRARR(nmbrs)
      for immbr = 0, nmbrs-1 do begin
         dtnames[immbr] = h5g_get_member_name(group_id, gname, immbr)
;         print, dtnames[immbr]
         dtID = h5d_open(ss_group_id, dtnames[immbr])
         CASE dtnames[immbr] OF
                           'scPos' : IF all THEN scPos = h5d_read(dtID)
                           'scVel' : IF all THEN scVel = h5d_read(dtID)
                           'scLat' : scLat = h5d_read(dtID)
                           'scLon' : scLon = h5d_read(dtID)
                           'scAlt' : scAlt = h5d_read(dtID)
                          'dprAlt' : dprAlt = h5d_read(dtID)
                   'scAttRollGeoc' : IF all THEN scAttRollGeoc = h5d_read(dtID)
                  'scAttPitchGeoc' : IF all THEN scAttPitchGeoc = h5d_read(dtID)
                    'scAttYawGeoc' : IF all THEN scAttYawGeoc = h5d_read(dtID)
                   'scAttRollGeod' : IF all THEN scAttRollGeod = h5d_read(dtID)
                  'scAttPitchGeod' : IF all THEN scAttPitchGeod = h5d_read(dtID)
                    'scAttYawGeod' : IF all THEN scAttYawGeod = h5d_read(dtID)
                    'greenHourAng' : IF all THEN greenHourAng = h5d_read(dtID)
                     'timeMidScan' : timeMidScan = h5d_read(dtID)
               'timeMidScanOffset' : timeMidScanOffset = h5d_read(dtID)
            ELSE : BEGIN
                      message, "Unknown group member: "+dtnames[immbr], /INFO
;                      return, -1
                   END
         ENDCASE
;         dtval = h5d_read(dtID)
;         print, dtval[0]
         h5d_close, dtID
      endfor
   ENDIF ELSE BEGIN
      message, STRING(nmbrs, FORMAT='(I0)')+" not 15 members in group '" $
               +gname+"'", /INFO
      return, -1
   ENDELSE

   h5g_close, ss_group_id

   IF all THEN BEGIN
   navigation_struc = { source : label, $
                        scPos : scPos, $
                        scVel : scVel, $
                        scLat : scLat, $
                        scLon : scLon, $
                        scAlt : scAlt, $
                        dprAlt : dprAlt, $
                        scAttRollGeoc : scAttRollGeoc, $
                        scAttPitchGeoc : scAttPitchGeoc, $
                        scAttYawGeoc : scAttYawGeoc, $
                        scAttRollGeod : scAttRollGeod, $
                        scAttPitchGeod : scAttPitchGeod, $
                        scAttYawGeod : scAttYawGeod, $
                        greenHourAng : greenHourAng, $
                        timeMidScan : timeMidScan, $
                        timeMidScanOffset : timeMidScanOffset }
   ENDIF ELSE BEGIN
   navigation_struc = { source : label, $
                        scLat : scLat, $
                        scLon : scLon, $
                        scAlt : scAlt, $
                        dprAlt : dprAlt, $
                        timeMidScan : timeMidScan, $
                        timeMidScanOffset : timeMidScanOffset }
   ENDELSE

return, navigation_struc
end
