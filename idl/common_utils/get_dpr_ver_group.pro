;+
; Copyright © 2013, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; get_dpr_ver_group.pro         Bob Morris, GPM GV/SAIC   May 2013
;
; DESCRIPTION
; Given the HDF5 ID of its parent group, gets each data element for the DPR,
; KA, or Ku VER Group and returns a structure containing the individual data
; element names as the structure tags, and the VER element data arrays
; as the structure values.  Returns -1 in case of errors.
;
; PARAMETERS
; ----------
; group_id  -- HDF5 ID of the parent group of the VER group
; prodgroup -- String with the AlgorithmID and parent Swath name together,
;              separated by '__', e.g., '2AKu__NS'
; read_all  -- Binary parameter.  If set, then read and return all datasets in
;              the groups.  Otherwise, just read the datasets needed for basic
;              display and processing (subjective list).
;
; HISTORY
; -------
; 05/31/13  Morris/GPM GV/SAIC
; - Created from get_scstatus_group.pro.
; 06/12/13  Morris/GPM GV/SAIC
; - Added READ_ALL option to pare down the datasets read by default.
; 11/25/15  Morris/GPM GV/SAIC
; - Removed the logic of testing for a specific number of members, just check
;   for a minimum number of variables.  In cases of new/unknown variables in
;   group return valid structure instead of -1 flag.
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-

FUNCTION get_dpr_ver_group, group_id, prodgroup, READ_ALL=read_all

   all = KEYWORD_SET(read_all)

   gname = 'VER'
   label = prodgroup+'/'+gname      ; label info for data structure

   ; get the ID of VER group
   ; -- check that this group contains a VER group
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
   print, "VER group No. Members = ", nmbrs
   ; extract the 5 expected date/time field values one by one
   IF nmbrs GE 5 THEN BEGIN
      dtnames=STRARR(nmbrs)
      for immbr = 0, nmbrs-1 do begin
         dtnames[immbr] = h5g_get_member_name(group_id, gname, immbr)
        print, dtnames[immbr]
         dtID = h5d_open(ss_group_id, dtnames[immbr])
         CASE dtnames[immbr] OF
                   'attenuationNP' : IF all THEN attenuationNP = h5d_read(dtID)
                      'binZeroDeg' : IF all THEN binZeroDeg = h5d_read(dtID)
                   'heightZeroDeg' : IF all THEN heightZeroDeg = h5d_read(dtID)
                           'piaNP' : piaNP = h5d_read(dtID)
            'sigmaZeroNPCorrected' : IF all THEN sigmaZeroNPCorrected = $
                                     h5d_read(dtID)
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
      message, STRING(nmbrs, FORMAT='(I0)')+" not 5 members in group '" $
               +gname+"'", /INFO
      return, -1
   ENDELSE

   h5g_close, ss_group_id

   ; have to use anonymous structures since variable dimensions change!
   IF all THEN BEGIN
      VER_struc = { source : label, $
                    attenuationNP : attenuationNP, $
                    binZeroDeg : binZeroDeg, $
                    heightZeroDeg : heightZeroDeg, $
                    piaNP : piaNP, $
                    sigmaZeroNPCorrected : sigmaZeroNPCorrected }
   ENDIF ELSE BEGIN
      VER_struc = { source : label, $
                     piaNP : piaNP }
   ENDELSE

return, VER_struc
end
