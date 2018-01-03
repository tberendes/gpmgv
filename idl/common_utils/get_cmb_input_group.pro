;+
; Copyright © 2013, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; get_cmb_input_group.pro         Bob Morris, GPM GV/SAIC   May 2013
;
; DESCRIPTION
; Given the HDF5 ID of its parent group, gets each data element for the COMB
; 'Input' Group and returns a structure containing the individual data
; element names as the structure tags, and the 'Input' element data arrays
; as the structure values.  Returns -1 in case of errors.
;
; PARAMETERS
; ----------
; group_id  -- HDF5 ID of the parent group of the Input group
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
; 01/07/14  Morris/GPM GV/SAIC
; - Added new baseline datasets 'zeroDegAltitude' and 'zeroDegBin' as datasets
;   to be read and returned in the output structure if READ_ALL is set.
; - Added ellipsoidBinOffset, lowestClutterFreeBin, and surfaceRangeBin to the
;   set of datasets to return in the output structure by default (READ_ALL=0).
; 01/07/14  Morris/GPM GV/SAIC
; - Fixed bugs where ellipsoidBinOffset, lowestClutterFreeBin, and
;   surfaceRangeBin were not read in CASE switch unless READ_ALL was set.
; 05/06/14  Morris/GPM GV/SAIC
; - Included additional datasets to be read by default: surfaceElevation,
;   localZenithAngle.
; - Put missing conditional clause on 'zeroDegAltitude' and 'zeroDegBin' so
;   that they won't be read from the file unless READ_ALL is set.
; 02/27/15  Morris/GPM GV/SAIC
; - Moved stormTopAltitude into the "Basic" dataset.
; 06/16/15  Morris/GPM GV/SAIC
; - Moved zeroDegAltitude and zeroDegBin into the "Basic" dataset.
; 09/26/16  Morris/GPM GV/SAIC
; - Removed the logic of testing for a specific number of members, just check
;   for a minimum number of variables.  In cases of new/unknown variables in
;   group return valid structure instead of -1 flag.
; 01/20/17  Morris/GPM GV/SAIC
; - Added V05 dataset sigmaZeroMeasured.
;
;
; EMAIL QUESTIONS OR COMMENTS AT:
;       https://pmm.nasa.gov/contact
;-

FUNCTION get_cmb_input_group, group_id, prodgroup, READ_ALL=read_all

   all = KEYWORD_SET(read_all)

   gname = 'Input'
   label = prodgroup+'/'+gname      ; label info for data structure

   ; get the ID of Input group
   ; -- check that this group contains a Input group
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
   ; extract the 16 expected datasets one by one
   IF nmbrs GE 16 THEN BEGIN
      dtnames=STRARR(nmbrs)
      for immbr = 0, nmbrs-1 do begin
         dtnames[immbr] = h5g_get_member_name(group_id, gname, immbr)
;         print, dtnames[immbr]
         dtID = h5d_open(ss_group_id, dtnames[immbr])
         CASE dtnames[immbr] OF
                'ellipsoidBinOffset' : ellipsoidBinOffset = h5d_read(dtID)
                  'localZenithAngle' : localZenithAngle = h5d_read(dtID)
              'lowestClutterFreeBin' : lowestClutterFreeBin = h5d_read(dtID)
                      'piaEffective' : IF all THEN piaEffective = h5d_read(dtID)
            'piaEffectiveReliabFlag' : IF all THEN piaEffectiveReliabFlag = $
                                       h5d_read(dtID)
                 'piaEffectiveSigma' : IF all THEN piaEffectiveSigma = $
                                       h5d_read(dtID)
             'precipTypeQualityFlag' : IF all THEN precipTypeQualityFlag = $
                                       h5d_read(dtID)
                 'precipitationFlag' : precipitationFlag = h5d_read(dtID)
                 'precipitationType' : precipitationType = h5d_read(dtID)
                 'sigmaZeroMeasured' : IF all THEN sigmaZeroMeasured = $
                                       h5d_read(dtID)
                  'stormTopAltitude' : stormTopAltitude = h5d_read(dtID)
                       'stormTopBin' : IF all THEN stormTopBin = h5d_read(dtID)
                  'surfaceElevation' : surfaceElevation = h5d_read(dtID)
                   'surfaceRangeBin' : surfaceRangeBin = h5d_read(dtID)
                       'surfaceType' : surfaceType = h5d_read(dtID)
                   'zeroDegAltitude' : zeroDegAltitude = h5d_read(dtID)
                        'zeroDegBin' : zeroDegBin = h5d_read(dtID)
            ELSE : BEGIN
                      message, "Unknown group member: "+dtnames[immbr], /INFO
                      print, "No. Members = ", STRING(nmbrs, FORMAT='(I0)')
                   END
         ENDCASE
;         dtval = h5d_read(dtID)
;         print, dtval[0]
         h5d_close, dtID
      endfor
   ENDIF ELSE BEGIN
      h5g_close, ss_group_id
      message, STRING(nmbrs, FORMAT='(I0)')+", not 16 or more, members in group '" $
               +gname+"'", /INFO
   ENDELSE

   h5g_close, ss_group_id

   ; have to use anonymous structures since variable dimensions change!
   IF all THEN BEGIN
      Input_struc = { source : label, $
                      ellipsoidBinOffset : ellipsoidBinOffset, $
                      localZenithAngle : localZenithAngle, $
                      lowestClutterFreeBin : lowestClutterFreeBin, $
                      piaEffective : piaEffective, $
                      piaEffectiveReliabFlag : piaEffectiveReliabFlag, $
                      piaEffectiveSigma : piaEffectiveSigma, $
                      precipTypeQualityFlag : precipTypeQualityFlag, $
                      precipitationFlag : precipitationFlag, $
                      precipitationType : precipitationType, $
                      stormTopAltitude : stormTopAltitude, $
                      stormTopBin : stormTopBin, $
                      surfaceElevation : surfaceElevation, $
                      surfaceRangeBin : surfaceRangeBin, $
                      surfaceType : surfaceType, $
                      zeroDegAltitude : zeroDegAltitude, $
                      zeroDegBin : zeroDegBin }
     ; append extra V05 variable, as available
      IF N_ELEMENTS(sigmaZeroMeasured) NE 0 THEN $
         Input_struc = CREATE_STRUCT( Input_struc, 'sigmaZeroMeasured', $
                                         sigmaZeroMeasured )
   ENDIF ELSE BEGIN
      Input_struc = { source : label, $
                      ellipsoidBinOffset : ellipsoidBinOffset, $
                      localZenithAngle : localZenithAngle, $
                      lowestClutterFreeBin : lowestClutterFreeBin, $
                      precipitationFlag : precipitationFlag, $
                      precipitationType : precipitationType, $
                      stormTopAltitude : stormTopAltitude, $
                      surfaceElevation : surfaceElevation, $
                      surfaceRangeBin : surfaceRangeBin, $
                      surfaceType : surfaceType, $
                      zeroDegAltitude : zeroDegAltitude, $
                      zeroDegBin : zeroDegBin }
   ENDELSE

return, Input_struc
end
