;+
; Copyright © 2013, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; get_dpr_csf_group_v7.pro         Bob Morris, GPM GV/SAIC   May 2013
;
; DESCRIPTION
; Given the HDF5 ID of its parent group, gets each data element for the DPR,
; Ka, or Ku CSF Group and returns a structure containing the individual data
; element names as the structure tags, and the CSF element data arrays
; as the structure values.  Returns -1 in case of errors.
;
; PARAMETERS
; ----------
; group_id  -- HDF5 ID of the parent group of the CSF group
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
; 12/03/14  Morris/GPM GV/SAIC
; - Added logic to allow either 10 members or 12 members.  MS swath in 2A-DPR
;   has two additional fields that other products don't have in their CSF group.
; 11/25/15  Morris/GPM GV/SAIC
; - Added reading and output of MS swath binDFRmMLBottom variable for V04x file
;   for READ_ALL case.
; - Removed the logic of testing for a specific number of members, just check
;   for a minimum number of variables and append the extras to the basic output
;   structure. In cases of new/unknown variables in group return valid structure
;   instead of -1 flag.
; 01/11/17  Morris/GPM GV/SAIC
; - Added reading and output of flagAnvil and flagHeavyIcePrecip variables for
;   V05x file in READ_ALL case.
; 7/6/22 Berendes, UAH ITSC
; - Added new GPM V7 Variables flagHail, binHeavyIcePrecipTop, binHeavyIcePrecipBottom
; 1/4/23 Todd Berendes UAH/ITSC
;  -  Added nHeavyIcePrecip

;
; EMAIL QUESTIONS OR COMMENTS AT:
;       https://pmm.nasa.gov/contact
;-

FUNCTION get_dpr_csf_group_v7, group_id, prodgroup, READ_ALL=read_all

   all = KEYWORD_SET(read_all)

   gname = 'CSF'
   label = prodgroup+'/'+gname      ; label info for data structure

   ; get the ID of CSF group
   ; -- check that this group contains a CSF group
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
   ; extract the 10 or more expected date/time field values one by one
   IF nmbrs GE 10 THEN BEGIN
      dtnames=STRARR(nmbrs)
      for immbr = 0, nmbrs-1 do begin
         dtnames[immbr] = h5g_get_member_name(group_id, gname, immbr)
;         print, dtnames[immbr]
         dtID = h5d_open(ss_group_id, dtnames[immbr])
         CASE dtnames[immbr] OF
                  'binBBBottom' : IF all THEN binBBBottom = h5d_read(dtID)
                    'binBBPeak' : IF all THEN binBBPeak = h5d_read(dtID)
                     'binBBTop' : IF all THEN binBBTop = h5d_read(dtID)
              'binDFRmBBBottom' : IF all THEN binDFRmBBBottom = h5d_read(dtID)
                 'binDFRmBBTop' : IF all THEN binDFRmBBTop = h5d_read(dtID)
              'binDFRmMLBottom' : IF all THEN binDFRmMLBottom = h5d_read(dtID)
                 'binDFRmMLTop' : IF all THEN binDFRmMLTop = h5d_read(dtID)
                    'flagAnvil' : IF all THEN flagAnvil = h5d_read(dtID)
                       'flagBB' : flagBB = h5d_read(dtID)
           'flagHeavyIcePrecip' : IF all THEN flagHeavyIcePrecip=h5d_read(dtID)
              'flagShallowRain' : IF all THEN flagShallowRain = h5d_read(dtID)
                     'heightBB' : heightBB = h5d_read(dtID)
                    'qualityBB' : qualityBB = h5d_read(dtID)
            'qualityTypePrecip' : qualityTypePrecip = h5d_read(dtID)
                   'typePrecip' : typePrecip = h5d_read(dtID)
                      'widthBB' : IF all THEN widthBB = h5d_read(dtID)
           			 'flagHail' : flagHail=h5d_read(dtID)
         'binHeavyIcePrecipTop' : binHeavyIcePrecipTop=h5d_read(dtID)
      'binHeavyIcePrecipBottom' : binHeavyIcePrecipBottom=h5d_read(dtID)
              'nHeavyIcePrecip' : nHeavyIcePrecip=h5d_read(dtID)
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
     message, "Fewer than " + STRING(nmbrs, FORMAT='(I0)') $
               + " 10 members in group '" + gname + "'", /INFO
      return, -1
   ENDELSE

   h5g_close, ss_group_id

   ; have to use anonymous structures since variable dimensions change!
  IF all THEN BEGIN
     CSF_struc = { source : label, $
                   binBBBottom : binBBBottom, $
                   binBBPeak : binBBPeak, $
                   binBBTop : binBBTop, $
                   flagBB : flagBB, $
                   flagShallowRain : flagShallowRain, $
                   heightBB : heightBB, $
                   qualityBB : qualityBB, $
                   qualityTypePrecip : qualityTypePrecip, $
                   typePrecip : typePrecip, $
                   widthBB : widthBB }

    ; append extra MS and V04 variables, as available
     IF N_ELEMENTS(binDFRmBBBottom) NE 0 THEN $
        CSF_struc = CREATE_STRUCT(CSF_struc, 'binDFRmBBBottom', binDFRmBBBottom)
     IF N_ELEMENTS(binDFRmBBTop) NE 0 THEN $
        CSF_struc = CREATE_STRUCT(CSF_struc, 'binDFRmBBTop', binDFRmBBTop)
     IF N_ELEMENTS(binDFRmMLBottom) NE 0 THEN $
        CSF_struc = CREATE_STRUCT(CSF_struc, 'binDFRmMLBottom', binDFRmMLBottom)
     IF N_ELEMENTS(binDFRmMLTop) NE 0 THEN $
        CSF_struc = CREATE_STRUCT(CSF_struc, 'binDFRmMLTop', binDFRmMLTop)
    ; append extra V05 variables, as available
     IF N_ELEMENTS(flagAnvil) NE 0 THEN $
        CSF_struc = CREATE_STRUCT(CSF_struc, 'flagAnvil', flagAnvil)
     IF N_ELEMENTS(flagHeavyIcePrecip) NE 0 THEN $
        CSF_struc = CREATE_STRUCT(CSF_struc, 'flagHeavyIcePrecip', $
                                  flagHeavyIcePrecip)
  ENDIF ELSE BEGIN
     CSF_struc = { source : label, $
                   flagBB : flagBB, $
                   heightBB : heightBB, $
                   qualityBB : qualityBB, $
                   qualityTypePrecip : qualityTypePrecip, $
                   typePrecip : typePrecip }
  ENDELSE
    
  ; append new V7 variables
  IF N_ELEMENTS(flagHail) NE 0 THEN $
     CSF_struc = CREATE_STRUCT(CSF_struc, 'flagHail', $
                                  flagHail)
  IF N_ELEMENTS(binHeavyIcePrecipTop) NE 0 THEN $
     CSF_struc = CREATE_STRUCT(CSF_struc, 'binHeavyIcePrecipTop', $
                                  binHeavyIcePrecipTop)
  IF N_ELEMENTS(binHeavyIcePrecipBottom) NE 0 THEN $
     CSF_struc = CREATE_STRUCT(CSF_struc, 'binHeavyIcePrecipBottom', $
                                  binHeavyIcePrecipBottom)                                    
  IF N_ELEMENTS(nHeavyIcePrecip) NE 0 THEN $
     CSF_struc = CREATE_STRUCT(CSF_struc, 'nHeavyIcePrecip', $
                                  nHeavyIcePrecip)                                    
                                  
return, CSF_struc
end
