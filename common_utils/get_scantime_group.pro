;+
; Copyright © 2013, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; get_scantime_group.pro         Bob Morris, GPM GV/SAIC   May 2013
;
; DESCRIPTION
; Given the HDF5 ID of its parent group, gets each data element for the 
; ScanTime Group and returns a structure containing the individual ScanTime
; element names as the structure tags, and the date/time element data arrays
; as the structure values.  Returns -1 in case of errors.
;
;
; HISTORY
; -------
; 05/30/13  Morris/GPM GV/SAIC
; - Created.
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-

FUNCTION get_scantime_group, group_id, prodgroup

   gname = 'ScanTime'
   label = prodgroup+'/'+gname      ; label info for data structure

   ; get the ID of ScanTime group
   ; -- check that this group contains a ScanTime group
   CATCH, error
   IF error EQ 0 THEN BEGIN
      st_group_id = h5g_open(group_id, gname)
   ENDIF ELSE BEGIN
      help,!error_state,/st
      Catch, /Cancel
      message, 'err='+STRING(error)+", "+!error_state.msg, /INFO
      return, -1
   ENDELSE
   Catch, /Cancel

   nmbrs = h5g_get_nmembers(group_id, gname)
;   print, "No. Members = ", nmbrs
   ; extract the nine expected date/time field values one by one
   IF nmbrs EQ 9 THEN BEGIN
      dtnames=STRARR(nmbrs)
      for immbr = 0, nmbrs-1 do begin
         dtnames[immbr] = h5g_get_member_name(group_id, gname, immbr)
;         print, dtnames[immbr]
         dtID = h5d_open(st_group_id, dtnames[immbr])
         CASE dtnames[immbr] OF
              'DayOfMonth' : DayOfMonth = h5d_read(dtID)
               'DayOfYear' : DayOfYear = h5d_read(dtID)
                    'Hour' : Hour = h5d_read(dtID)
             'MilliSecond' : MilliSecond = h5d_read(dtID)
                  'Minute' : Minute = h5d_read(dtID)
                   'Month' : Month = h5d_read(dtID)
                  'Second' : Second = h5d_read(dtID)
             'SecondOfDay' : SecondOfDay = h5d_read(dtID)
                    'Year' : Year = h5d_read(dtID)
            ELSE : BEGIN
                      message, "Unknown group member: "+dtnames[immbr], /INFO
                      return, -1
                   END
         ENDCASE
;         dtval = h5d_read(dtID)
;         print, dtval[0]
         h5d_close, dtID
      endfor
   ENDIF ELSE BEGIN
      message, STRING(nmbrs, FORMAT='(I0)')+" not 9 members in group '" $
               +gname+"'", /INFO
      return, -1
   ENDELSE

   h5g_close, st_group_id

   ; have to use anonymous structures since variable dimensions change!
   scantime_struc = { source : label, $
                      DayOfMonth : DayOfMonth, $
                      DayOfYear : DayOfYear, $
                      Hour : Hour, $
                      MilliSecond : MilliSecond, $
                      Minute : Minute, $
                      Month : Month, $
                      Second : Second, $
                      SecondOfDay : SecondOfDay, $
                      Year : Year }

return, scantime_struc
end
