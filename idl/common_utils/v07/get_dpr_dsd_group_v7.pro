;+
; Copyright © 2013, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; get_dpr_dsd_group_v7.pro         Bob Morris, GPM GV/SAIC   May 2013
;
; DESCRIPTION
; Given the HDF5 ID of its parent group, gets each data element for the DPR,
; Ka, or Ku DSD Group and returns a structure containing the individual 
; element names as the structure tags, and the DSD element data arrays
; as the structure values.  Returns -1 in case of errors.
;
; PARAMETERS
; ----------
; group_id  -- HDF5 ID of the parent group of the DSD group
; prodgroup -- String with the AlgorithmID and parent Swath name together,
;              separated by '__', e.g., '2AKu__NS'
; read_all  -- Binary parameter.  If set, then read and return all datasets in
;              the groups.  Otherwise, just read the datasets needed for basic
;              display and processing (subjective list).  In this group's case
;              no datasets are read, and the returned structure just has the
;              group label.
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
; 06/25/20  Berendes/UAH
; - changes for V07 files
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-

FUNCTION get_dpr_dsd_group_v7, group_id, prodgroup, READ_ALL=read_all

   all = KEYWORD_SET(read_all)

   gname = 'DSD'
   label = prodgroup+'/'+gname      ; label info for data structure
   ; pull the swath name out of prodgroup string, it follows '__'
   parsed = STRSPLIT(prodgroup, '__', /REGEX, /EXTRACT)
   swathname = parsed[1]
   product = parsed[0]

   ; get the ID of DSD group
   ; -- check that this group contains a DSD group
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
   ; the number of members expected varies depending on the swath ID
   CASE swathname OF
      'FS' : n_expect = 2
      'HS' : n_expect = 2
      ELSE : message, "Unknown swath type given in prodgroup: "+swathname
   ENDCASE

   ; extract the 1 or 2 expected date/time field values one by one
   have_phase = 0
   IF nmbrs GE n_expect THEN BEGIN
      dtnames=STRARR(nmbrs)
      for immbr = 0, nmbrs-1 do begin
         dtnames[immbr] = h5g_get_member_name(group_id, gname, immbr)
;        print, dtnames[immbr]
         dtID = h5d_open(ss_group_id, dtnames[immbr])
         CASE dtnames[immbr] OF
            'binNode' : IF all THEN binNode = h5d_read(dtID)
              'phase' : BEGIN
                        have_phase = 1
                        IF all THEN phase = h5d_read(dtID)
                        END
                 ELSE : BEGIN
                        message, "Unknown group member: "+dtnames[immbr], /INFO
;                        return, -1
                        END
         ENDCASE
;         dtval = h5d_read(dtID)
;         print, dtval[0]
         h5d_close, dtID
      endfor
   ENDIF ELSE BEGIN
      message, STRING(nmbrs, FORMAT='(I0)')+" not "+ $
               STRING(n_expect, FORMAT='(I0)')+" members in group '" $
               +prodgroup+'/'+gname+"'", /INFO
      return, -1
   ENDELSE

   h5g_close, ss_group_id

   ; handle differences between 2AKa, 2AKu, and 2ADPR w.r.t. phase presence,
   ; and case of READ_ALL being unset (return empty struct)
   IF N_ELEMENTS(phase) EQ 0 AND all THEN phase = "UNDEFINED"

   ; have to use anonymous structures since variable dimensions change!
   IF all THEN BEGIN
      DSD_struc = { source : label, $
                   binNode : binNode, $
                     phase : phase }
   ENDIF ELSE BEGIN
      DSD_struc = { source : label }
   ENDELSE

return, DSD_struc
end
