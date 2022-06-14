;+
; Copyright © 2013, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; get_2agprofgmi_datasets_v7.pro         Bob Morris, GPM GV/SAIC   June 2013
;
; DESCRIPTION
; Given the HDF5 ID of its 2AGPROFGMI swath group, gets each dataset element 
; for the group and returns a structure containing the individual element names
; as the structure tags, and the full dataset arrays as the structure values.  
; Returns -1 in case of errors.
;
; PARAMETERS
; ----------
; group_id  -- HDF5 ID of the swath group
; label     -- String with the AlgorithmID and parent Swath name together,
;              separated by '__', e.g., '2AGPROFGMI__S1'
; read_all  -- Binary parameter.  If set, then read and return all datasets in
;              the groups.  Otherwise, just read the datasets needed for basic
;              display and processing (subjective list).
;
; HISTORY
; -------
; 06/07/13  Morris/GPM GV/SAIC
; - Created.
; 06/12/13  Morris/GPM GV/SAIC
; - Revamped the list of datasets in CASE and output structure to match
;   baseline product specification rather than early test product content.
; - Added READ_ALL option to pare down the datasets read by default.
; 01/07/14  Morris/GPM GV/SAIC
; - Changed dataset ID from 'totalColumnWaterIndex' group to
;   'totalColumnWaterVaporIndex' and added dataset 'totalColumnWaterVapor' as
;   a "basic" dataset to read, to match current file definition.
; 01/04/17  Morris/GPM GV/SAIC
; - Changed behavior to ignore unknown members in the group rather than failing.
; - Define something for members present in one version but not another so that
;   returned structure can be populated without error.
; - Added tag/value pairs to return structure for new V05x DATASET members CAPE,
;   convectivePrecipitation, frozenPrecipitation, L1CqualityFlag,
;   profileTemp2mIndex, and spare2, as determined by read_all setting.
; 01/05/22 Berendes UAH/ITSC
; - added new V07 variables airmassLiftIndex, precipitationYesNoFlag, sunLocalTime
; - made iceWaterPath and cloudWaterPath included in return struct by default
;   (without READ_ALL set)
;
; EMAIL QUESTIONS OR COMMENTS AT:
;       https://pmm.nasa.gov/contact
;-


FUNCTION get_2agprofgmi_datasets_v7, group_id, label, READ_ALL=read_all

   all = KEYWORD_SET(read_all)

   nmbrs = h5g_get_num_objs(group_id)
   ;print, "No. Objects = ", nmbrs
   ; identify and extract the datasets one by one
   dtnames=STRARR(nmbrs)
   for immbr = 0, nmbrs-1 do begin
      ; get the object's information
      dtnames[immbr]=H5G_GET_OBJ_NAME_BY_IDX(group_id,immbr)
      info=H5G_GET_OBJINFO(group_id, dtnames[immbr])
      ;print, dtnames[immbr], ": ", info.type
      IF info.type EQ 'DATASET' THEN BEGIN
         dtID = h5d_open(group_id, dtnames[immbr])
         CASE dtnames[immbr] OF
                           'Latitude' : Latitude = h5d_read(dtID)
                          'Longitude' : Longitude = h5d_read(dtID)
                               'CAPE' : IF all THEN CAPE = h5d_read(dtID)
                     'cloudWaterPath' : cloudWaterPath = h5d_read(dtID)
              'convectPrecipFraction' : convectPrecipFraction = h5d_read(dtID)
            'convectivePrecipitation' : convectivePrecipitation = h5d_read(dtID)
             'databaseExpansionIndex' : IF all THEN databaseExpansionIndex = $
                                        h5d_read(dtID)
                'frozenPrecipitation' : frozenPrecipitation = h5d_read(dtID)
                       'iceWaterPath' : iceWaterPath = h5d_read(dtID)
                     'L1CqualityFlag' : IF all THEN L1CqualityFlag = $
                                        h5d_read(dtID)
               'liquidPrecipFraction' : liquidPrecipFraction = h5d_read(dtID)
                     'mixedWaterPath' : IF all THEN mixedWaterPath = $
                                        h5d_read(dtID)
            'mostLikelyPrecipitation' : IF all THEN mostLikelyPrecipitation = $
                                        h5d_read(dtID)
               'numOfSignificantProf' : IF all THEN numOfSignificantProf = $
                                        h5d_read(dtID)
                'orographicLiftIndex' : IF all THEN orographicLiftIndex = $
                                        h5d_read(dtID)
                        'pixelStatus' : pixelStatus = h5d_read(dtID)
                   'precip1stTertial' : IF all THEN precip1stTertial = $
                                        h5d_read(dtID)
                   'precip2ndTertial' : IF all THEN precip2ndTertial = $
                                        h5d_read(dtID)
                'probabilityOfPrecip' : probabilityOfPrecip = h5d_read(dtID)
                      'profileNumber' : IF all THEN profileNumber = $
                                        h5d_read(dtID)
                       'profileScale' : IF all THEN profileScale = $
                                        h5d_read(dtID)
                 'profileTemp2mIndex' : IF all THEN profileTemp2mIndex = $
                                        h5d_read(dtID)
                        'qualityFlag' : qualityFlag = h5d_read(dtID)
                      'rainWaterPath' : rainWaterPath = h5d_read(dtID)
                      'retrievalType' : IF all THEN retrievalType = $
                                        h5d_read(dtID)
                     'snowCoverIndex' : IF all THEN snowCoverIndex = $
                                        h5d_read(dtID)
                              'spare' : IF all THEN spare = h5d_read(dtID)
                             'spare2' : IF all THEN spare2 = h5d_read(dtID)
                         'spareIndex' : IF all THEN spareIndex = h5d_read(dtID)
                      'sunGlintAngle' : sunGlintAngle = h5d_read(dtID)
               'surfacePrecipitation' : surfacePrecipitation = h5d_read(dtID)
               'surfaceSkinTempIndex' : IF all THEN surfaceSkinTempIndex = $
                                        h5d_read(dtID)
                   'surfaceTypeIndex' : surfaceTypeIndex = h5d_read(dtID)
                        'temp2mIndex' : IF all THEN temp2mIndex = h5d_read(dtID)
              'totalColumnWaterVapor' : totalColumnWaterVapor = h5d_read(dtID)
                       'sunLocalTime' : sunLocalTime = h5d_read(dtID)
                   'airmassLiftIndex' : airmassLiftIndex = h5d_read(dtID)
             'precipitationYesNoFlag' : precipitationYesNoFlag = h5d_read(dtID)
         'totalColumnWaterVaporIndex' : IF all THEN totalColumnWaterVaporIndex = $
                                        h5d_read(dtID)
            ELSE : BEGIN
;                      h5d_close, dtID
                      message, "Unknown DATASET group member: "+dtnames[immbr], /INFO
;                      return, -1
                   END
         ENDCASE
;         dtval = h5d_read(dtID)
;         print, dtval[0]
         h5d_close, dtID
      ENDIF
   endfor

  ; Deal with the variables that go away after V04x and appear at V05x.  Define them
  ; as the string 'N/A' if they don't exist in a version so that the structures can
  ; be created without errors

  ; goes away after V04x:
   IF N_ELEMENTS(convectPrecipFraction) EQ 0 THEN convectPrecipFraction = 'N/A'
   IF N_ELEMENTS(databaseExpansionIndex) EQ 0 THEN databaseExpansionIndex = 'N/A'
   IF N_ELEMENTS(liquidPrecipFraction) EQ 0 THEN liquidPrecipFraction = 'N/A'
   IF N_ELEMENTS(mixedWaterPath) EQ 0 THEN mixedWaterPath = 'N/A'
   IF N_ELEMENTS(numOfSignificantProf) EQ 0 THEN numOfSignificantProf = 'N/A'
   IF N_ELEMENTS(orographicLiftIndex) EQ 0 THEN orographicLiftIndex = 'N/A'
   IF N_ELEMENTS(retrievalType) EQ 0 THEN retrievalType = 'N/A'
   IF N_ELEMENTS(snowCoverIndex) EQ 0 THEN snowCoverIndex = 'N/A'
   IF N_ELEMENTS(spare) EQ 0 THEN spare = 'N/A'
   IF N_ELEMENTS(spareIndex) EQ 0 THEN spareIndex = 'N/A'
   IF N_ELEMENTS(surfaceSkinTempIndex) EQ 0 THEN surfaceSkinTempIndex = 'N/A'
   IF N_ELEMENTS(totalColumnWaterVapor) EQ 0 THEN totalColumnWaterVapor = 'N/A'

  ; new for V05x:
   IF N_ELEMENTS(CAPE) EQ 0 THEN CAPE = 'N/A'
   IF N_ELEMENTS(convectivePrecipitation) EQ 0 THEN convectivePrecipitation = 'N/A'
   IF N_ELEMENTS(frozenPrecipitation) EQ 0 THEN frozenPrecipitation = 'N/A'
   IF N_ELEMENTS(L1CqualityFlag) EQ 0 THEN L1CqualityFlag = 'N/A'
   IF N_ELEMENTS(profileTemp2mIndex) EQ 0 THEN profileTemp2mIndex = 'N/A'
   IF N_ELEMENTS(spare2) EQ 0 THEN spare2 = 'N/A'

  ; new for V07x:
   IF N_ELEMENTS(sunLocalTime) EQ 0 THEN sunLocalTime = 'N/A'
   IF N_ELEMENTS(airmassLiftIndex) EQ 0 THEN airmassLiftIndex = 'N/A'
   IF N_ELEMENTS(precipitationYesNoFlag) EQ 0 THEN precipitationYesNoFlag = 'N/A'
  
   IF all THEN BEGIN
   datasets_struc = { source : label, $
                      Latitude : Latitude, $
                      Longitude : Longitude, $
                      CAPE : CAPE, $
                      cloudWaterPath : cloudWaterPath, $
                      convectPrecipFraction : convectPrecipFraction, $
                      convectivePrecipitation : convectivePrecipitation, $
                      databaseExpansionIndex : databaseExpansionIndex, $
                      frozenPrecipitation : frozenPrecipitation, $
                      iceWaterPath : iceWaterPath, $
                      L1CqualityFlag : L1CqualityFlag, $
                      liquidPrecipFraction : liquidPrecipFraction, $
                      mixedWaterPath : mixedWaterPath, $
                      mostLikelyPrecipitation : mostLikelyPrecipitation, $
                      numOfSignificantProf : numOfSignificantProf, $
                      orographicLiftIndex : orographicLiftIndex, $
                      pixelStatus : pixelStatus, $
                      precip1stTertial : precip1stTertial, $
                      precip2ndTertial : precip2ndTertial, $
                      probabilityOfPrecip : probabilityOfPrecip, $
                      profileNumber : profileNumber, $
                      profileScale : profileScale, $
                      profileTemp2mIndex : profileTemp2mIndex, $
                      qualityFlag : qualityFlag, $
                      rainWaterPath : rainWaterPath, $
                      retrievalType : retrievalType, $
                      snowCoverIndex : snowCoverIndex, $
                      spare : spare, $
                      spare2 : spare2, $
                      spareIndex : spareIndex, $
                      sunGlintAngle : sunGlintAngle, $
                      surfacePrecipitation : surfacePrecipitation, $
                      surfaceSkinTempIndex : surfaceSkinTempIndex, $
                      surfaceTypeIndex : surfaceTypeIndex, $
                      temp2mIndex : temp2mIndex, $
                      sunLocalTime : sunLocalTime, $
                      airmassLiftIndex : airmassLiftIndex, $
                      precipitationYesNoFlag : precipitationYesNoFlag, $
                      totalColumnWaterVapor : totalColumnWaterVapor, $
                      totalColumnWaterVaporIndex : totalColumnWaterVaporIndex }
   ENDIF ELSE BEGIN
   datasets_struc = { source : label, $
                      Latitude : Latitude, $
                      Longitude : Longitude, $
                      convectPrecipFraction : convectPrecipFraction, $
                      convectivePrecipitation : convectivePrecipitation, $
                      frozenPrecipitation : frozenPrecipitation, $
                      liquidPrecipFraction : liquidPrecipFraction, $
                      pixelStatus : pixelStatus, $
                      probabilityOfPrecip : probabilityOfPrecip, $
                      qualityFlag : qualityFlag, $
                      rainWaterPath : rainWaterPath, $
                      sunGlintAngle : sunGlintAngle, $
                      surfacePrecipitation : surfacePrecipitation, $
                      surfaceTypeIndex : surfaceTypeIndex, $
                      sunLocalTime : sunLocalTime, $
                      airmassLiftIndex : airmassLiftIndex, $
                      precipitationYesNoFlag : precipitationYesNoFlag, $
                      cloudWaterPath : cloudWaterPath, $
                      iceWaterPath : iceWaterPath, $
                      totalColumnWaterVapor : totalColumnWaterVapor }
   ENDELSE

return, datasets_struc
end
