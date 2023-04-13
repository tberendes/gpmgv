;+
; Copyright © 2014, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; get_dpr_experimental_group_v7.pro         Bob Morris, GPM GV/SAIC   Jan 2014
;
; DESCRIPTION
; Given the HDF5 ID of its parent group, gets each data element for the DPR,
; Ka, or Ku experimental Group and returns a structure containing the individual 
; element names as the structure tags, and the experimental element data arrays
; as the structure values.  Returns -1 in case of errors.
;
; PARAMETERS
; ----------
; group_id  -- HDF5 ID of the parent group of the experimental group
; prodgroup -- String with the AlgorithmID and parent Swath name together,
;              separated by '__', e.g., '2AKu__NS'
; read_all  -- Binary parameter.  If set, then read and return all datasets in
;              the groups.  Otherwise, just read the datasets needed for basic
;              display and processing (subjective list).  FOR NOW, WE IGNORE
;              THIS PARM AND JUST READ AND RETURN ALL DATASETS IN THE GROUP.
;
; HISTORY
; -------
; 01/08/14  Morris/GPM GV/SAIC
; - Created from get_dpr_scanstatus_group.pro.
; 11/25/15  Morris/GPM GV/SAIC
; - Added reading and output of seaIceConcentration variable for V04x files.
; - Ignore new/unknown variables in group and still return valid structure
;   instead of -1 flag.
; 01/11/17  Morris/GPM GV/SAIC
; - Added reading and output of flagSurfaceSnowfall and surfaceSnowfallIndex
;   variables for V05x file.
; 06/25/20  Berendes/UAH
; - removed binDEML2 from structure, not present in V07 files
; 7/6/22 Berendes, UAH ITSC
; - Added new GPM V7 Variables flagGraupelHail, binMixedPhaseTop
;
;
; EMAIL QUESTIONS OR COMMENTS AT:
;       https://pmm.nasa.gov/contact
;-

FUNCTION get_dpr_experimental_group_v7, group_id, prodgroup, READ_ALL=read_all

   all = KEYWORD_SET(read_all)

   gname = 'Experimental'
   label = prodgroup+'/'+gname      ; label info for data structure

   ; get the ID of experimental group
   ; -- check that this group contains a experimental group
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
   ; extract the 4+ expected date/time field values one by one
   IF nmbrs GE 4 THEN BEGIN
      dtnames=STRARR(nmbrs)
      for immbr = 0, nmbrs-1 do begin
         dtnames[immbr] = h5g_get_member_name(group_id, gname, immbr)
;         print, dtnames[immbr]
         dtID = h5d_open(ss_group_id, dtnames[immbr])
         CASE dtnames[immbr] OF
;                               'binDEML2' : binDEML2 = h5d_read(dtID)
                    'flagSurfaceSnowfall' : flagSurfaceSnowfall = h5d_read(dtID)
                    'precipRateESurface2' : precipRateESurface2 = h5d_read(dtID)
              'precipRateESurface2Status' : precipRateESurface2Status = $
                                            h5d_read(dtID)
                    'seaIceConcentration' : seaIceConcentration = h5d_read(dtID)
                       'sigmaZeroProfile' : sigmaZeroProfile = h5d_read(dtID)
                   'surfaceSnowfallIndex' : surfaceSnowfallIndex=h5d_read(dtID)
         		       'binMixedPhaseTop' : binMixedPhaseTop=h5d_read(dtID)
                        'flagGraupelHail' : flagGraupelHail = h5d_read(dtID)
            ELSE : BEGIN
;                      message, "Unknown group member: "+dtnames[immbr], /INFO
;                      return, -1
                   END
         ENDCASE
;         dtval = h5d_read(dtID)
;         print, dtval[0]
         h5d_close, dtID
      endfor
   ENDIF ELSE BEGIN
      message, STRING(nmbrs, FORMAT='(I0)')+" not 4 members in group '" $
               +gname+"'", /INFO
      return, -1
   ENDELSE

   h5g_close, ss_group_id

   experimental_struc = { source : label, $
                        precipRateESurface2 : precipRateESurface2, $
                        precipRateESurface2Status : precipRateESurface2Status, $
                        sigmaZeroProfile : sigmaZeroProfile}
;                        binDEML2 : binDEML2 }
  ; append extra V04 variables, as available
   IF N_ELEMENTS(seaIceConcentration) NE 0 THEN experimental_struc = $
      CREATE_STRUCT(experimental_struc, 'seaIceConcentration', seaIceConcentration)
  ; append extra V05 variables, as available
   IF N_ELEMENTS(flagSurfaceSnowfall) NE 0 THEN experimental_struc = $
      CREATE_STRUCT(experimental_struc, 'flagSurfaceSnowfall', flagSurfaceSnowfall)
   IF N_ELEMENTS(surfaceSnowfallIndex) NE 0 THEN experimental_struc = $
      CREATE_STRUCT(experimental_struc, 'surfaceSnowfallIndex', surfaceSnowfallIndex)

  ; append extra V07 variables
   IF N_ELEMENTS(binMixedPhaseTop) NE 0 THEN experimental_struc = $
      CREATE_STRUCT(experimental_struc, 'binMixedPhaseTop', binMixedPhaseTop)
   IF N_ELEMENTS(flagGraupelHail) NE 0 THEN experimental_struc = $
      CREATE_STRUCT(experimental_struc, 'flagGraupelHail', flagGraupelHail)

return, experimental_struc
end
