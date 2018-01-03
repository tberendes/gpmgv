;+
; Copyright © 2013, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; get_dpr_scanstatus_group.pro         Bob Morris, GPM GV/SAIC   May 2013
;
; DESCRIPTION
; Given the HDF5 ID of its parent group, gets each data element for the DPR,
; Ka, or Ku scanStatus Group and returns a structure containing the individual 
; element names as the structure tags, and the scanStatus element data arrays
; as the structure values.  Returns -1 in case of errors.
;
; PARAMETERS
; ----------
; group_id  -- HDF5 ID of the parent group of the scanStatus group
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
; 06/13/13  Morris/GPM GV/SAIC
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

FUNCTION get_dpr_scanstatus_group, group_id, prodgroup, READ_ALL=read_all

   all = KEYWORD_SET(read_all)

   gname = 'scanStatus'
   label = prodgroup+'/'+gname      ; label info for data structure

   ; get the ID of scanStatus group
   ; -- check that this group contains a scanStatus group
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
   ; extract the 13 expected date/time field values one by one
   IF nmbrs GE 13 THEN BEGIN
      dtnames=STRARR(nmbrs)
      for immbr = 0, nmbrs-1 do begin
         dtnames[immbr] = h5g_get_member_name(group_id, gname, immbr)
;         print, dtnames[immbr]
         dtID = h5d_open(ss_group_id, dtnames[immbr])
         CASE dtnames[immbr] OF
            'FractionalGranuleNumber' : FractionalGranuleNumber = h5d_read(dtID)
                      'SCorientation' : IF all THEN SCorientation = $
                                        h5d_read(dtID)
                     'acsModeMidScan' : IF all THEN acsModeMidScan = $
                                        h5d_read(dtID)
                        'dataQuality' : dataQuality = h5d_read(dtID)
                        'dataWarning' : IF all THEN dataWarning = h5d_read(dtID)
                           'geoError' : IF all THEN geoError = h5d_read(dtID)
                         'geoWarning' : IF all THEN geoWarning = h5d_read(dtID)
                     'limitErrorFlag' : IF all THEN limitErrorFlag = $
                                        h5d_read(dtID)
                            'missing' : IF all THEN missing = h5d_read(dtID)
                         'modeStatus' : IF all THEN modeStatus = h5d_read(dtID)
                    'operationalMode' : IF all THEN operationalMode = $
                                        h5d_read(dtID)
                     'pointingStatus' : IF all THEN pointingStatus = $
                                        h5d_read(dtID)
             'targetSelectionMidScan' : IF all THEN targetSelectionMidScan = $
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
      message, STRING(nmbrs, FORMAT='(I0)')+" not 13 members in group '" $
               +gname+"'", /INFO
      return, -1
   ENDELSE

   h5g_close, ss_group_id

   IF all THEN BEGIN
   scanStatus_struc = { source : label, $
                        FractionalGranuleNumber : FractionalGranuleNumber, $
                        SCorientation : SCorientation, $
                        acsModeMidScan : acsModeMidScan, $
                        dataQuality : dataQuality, $
                        dataWarning : dataWarning, $
                        geoError : geoError, $
                        geoWarning : geoWarning, $
                        limitErrorFlag : limitErrorFlag, $
                        missing : missing, $
                        modeStatus : modeStatus, $
                        operationalMode : operationalMode, $
                        pointingStatus : pointingStatus, $
                        targetSelectionMidScan : targetSelectionMidScan }
   ENDIF ELSE BEGIN
   scanStatus_struc = { source : label, $
                        FractionalGranuleNumber : FractionalGranuleNumber, $
                        dataQuality : dataQuality }
   ENDELSE

return, scanStatus_struc
end
