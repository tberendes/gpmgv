;+
; Copyright © 2013, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; get_dpr_pre_group.pro         Bob Morris, GPM GV/SAIC   May 2013
;
; DESCRIPTION
; Given the HDF5 ID of its parent group, gets each data element for the DPR,
; Ka, or Ku PRE Group and returns a structure containing the individual 
; element names as the structure tags, and the PRE element data arrays
; as the structure values.  Returns -1 in case of errors.
;
; PARAMETERS
; ----------
; group_id  -- HDF5 ID of the parent group of the PRE group
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
; 06/18/13  Morris/GPM GV/SAIC
; - Added binClutterFreeBottom, binRealSurface, and localZenithAngle to the
;   "Basic" datasets.
; 09/05/14  Morris/GPM GV/SAIC
; - Added flagSigmaZeroSaturation to the list of variables to be read in
;   READ_ALL case.
; - Changed logic to not fail if there are new variables in the file that are
;   not yet defined in the CASE statement.
; 02/27/15  Morris/GPM GV/SAIC
; - Moved heightStormTop into the "Basic" dataset.
; 01/11/17  Morris/GPM GV/SAIC
; - Added reading and output of adjustFactor and snowIceCover variables for
;   V05x file in READ_ALL case.
;
; EMAIL QUESTIONS OR COMMENTS AT:
;       https://pmm.nasa.gov/contact
;-

FUNCTION get_dpr_pre_group, group_id, prodgroup, READ_ALL=read_all

   all = KEYWORD_SET(read_all)

   gname = 'PRE'
   label = prodgroup+'/'+gname      ; label info for data structure

   ; get the ID of PRE group
   ; -- check that this group contains a PRE group
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
   ; extract the 12 expected date/time field values one by one
   IF nmbrs GE 12 THEN BEGIN
      dtnames=STRARR(nmbrs)
      for immbr = 0, nmbrs-1 do begin
         dtnames[immbr] = h5g_get_member_name(group_id, gname, immbr)
;         print, dtnames[immbr]
         dtID = h5d_open(ss_group_id, dtnames[immbr])
         CASE dtnames[immbr] OF
                    'adjustFactor' : IF all THEN adjustFactor = h5d_read(dtID)
            'binClutterFreeBottom' : binClutterFreeBottom = h5d_read(dtID)
                  'binRealSurface' : binRealSurface = h5d_read(dtID)
                     'binStormTop' : IF all THEN binStormTop = h5d_read(dtID)
                       'elevation' : elevation = h5d_read(dtID)
              'ellipsoidBinOffset' : IF all THEN ellipsoidBinOffset = $
                                     h5d_read(dtID)
                      'flagPrecip' : flagPrecip = h5d_read(dtID)
         'flagSigmaZeroSaturation' : IF all THEN flagSigmaZeroSaturation = $
                                     h5d_read(dtID)
                  'heightStormTop' : heightStormTop = h5d_read(dtID)
                 'landSurfaceType' : landSurfaceType = h5d_read(dtID)
                'localZenithAngle' : localZenithAngle = h5d_read(dtID)
               'sigmaZeroMeasured' : IF all THEN sigmaZeroMeasured = $
                                     h5d_read(dtID)
                    'snowIceCover' : IF all THEN snowIceCover = h5d_read(dtID)
            'snRatioAtRealSurface' : IF all THEN snRatioAtRealSurface = $
                                     h5d_read(dtID)
                 'zFactorMeasured' : zFactorMeasured = h5d_read(dtID)
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
      message, STRING(nmbrs, FORMAT='(I0)')+" not >= 12 members in group '" $
               +gname+"'", /INFO
      return, -1
   ENDELSE

   h5g_close, ss_group_id

   ; have to use anonymous structures since variable dimensions change!
   IF all THEN BEGIN
      ; define something for flagSigmaZeroSaturation for pre-release file reads
      ; so that we don't fail
      IF N_ELEMENTS(flagSigmaZeroSaturation) EQ 0 $
      THEN flagSigmaZeroSaturation='N/A'

      PRE_struc = { source : label, $
                    binClutterFreeBottom : binClutterFreeBottom, $
                    binRealSurface : binRealSurface, $
                    binStormTop : binStormTop, $
                    elevation : elevation, $
                    ellipsoidBinOffset : ellipsoidBinOffset, $
                    flagPrecip : flagPrecip, $
                    flagSigmaZeroSaturation : flagSigmaZeroSaturation, $
                    heightStormTop : heightStormTop, $
                    landSurfaceType : landSurfaceType, $
                    localZenithAngle : localZenithAngle, $
                    sigmaZeroMeasured : sigmaZeroMeasured, $
                    snRatioAtRealSurface : snRatioAtRealSurface, $
                    zFactorMeasured : zFactorMeasured }
     ; append extra V05 variables, as available
      IF N_ELEMENTS(adjustFactor) NE 0 THEN $
         PRE_struc = CREATE_STRUCT(PRE_struc, 'adjustFactor', adjustFactor)
      IF N_ELEMENTS(snowIceCover) NE 0 THEN $
         PRE_struc = CREATE_STRUCT(PRE_struc, 'snowIceCover', snowIceCover)
   ENDIF ELSE BEGIN
      PRE_struc = { source : label, $
                    binClutterFreeBottom : binClutterFreeBottom, $
                    binRealSurface : binRealSurface, $
                    elevation : elevation, $
                    flagPrecip : flagPrecip, $
                    heightStormTop : heightStormTop, $
                    landSurfaceType : landSurfaceType, $
                    localZenithAngle : localZenithAngle, $
                    zFactorMeasured : zFactorMeasured }
   ENDELSE

return, PRE_struc
end
