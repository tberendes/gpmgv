;+
; Copyright © 2013, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; get_cmb_datasets_v7.pro         Bob Morris, GPM GV/SAIC   June 2013
;
; DESCRIPTION
; Given the HDF5 ID of its CMB swath group, gets each dataset element for the 
; group and returns a structure containing the individual  element names as
; the structure tags, and the full dataset arrays as the structure values.  
; Returns -1 in case of errors.
;
; PARAMETERS
; ----------
; group_id  -- HDF5 ID of the swath group
; label     -- String with the AlgorithmID and parent Swath name together,
;              separated by '__', e.g., '2AKu__NS'
; read_all  -- Binary parameter.  If set, then read and return all datasets in
;              the groups.  Otherwise, just read the datasets needed for basic
;              display and processing (subjective list).
;
; HISTORY
; -------
; 06/04/13  Morris/GPM GV/SAIC
; - Created.
; 06/13/13  Morris/GPM GV/SAIC
; - Added READ_ALL option to pare down the datasets read by default.
; 01/07/14  Morris/GPM GV/SAIC
; - Modified dataset names to match new baseline file definition.  Removed
;   'iceDensity' from the list of datasets.
; 01/22/14  Morris/GPM GV/SAIC
; - Fixed name of precipTotRate in default return structure.
; 05/06/14  Morris/GPM GV/SAIC
; - Included additional datasets to be read by default: precipTotPSDparamHigh,
;   precipTotPSDparamLow, PSDparamLowNode, precipTotWaterCont, phaseBinNodes.
; 09/26/16  Morris/GPM GV/SAIC
; - In cases of new/unknown variables in group, return valid structure with the
;   known variables instead of -1 failure flag.
; 01/20/17  Morris/GPM GV/SAIC
; - Added V05 datasets columnCloudLiqSigma, columnVaporSigma, errorOfDataFit,
;   multiScatSurface, skinTempSigma, subFootVariability, surfEmissSigma, and
;   tenMeterWindSigma.
; 10/26/20 by Todd Berendes (UAH)
;    added the following to default variables returned: 
;		precipTotWaterContSigma
;		cloudLiqWaterCont
;		cloudIceWaterCont
;		simulatedBrightTemp 
; 08/24/21 by Todd Berendes (UAH)
;   mods for V7 variable name changes
;   removed precipTotPSDparamLow (Nw), PSDparamLowNode, precipTotPSDparamHigh(Dm)
;   added precipTotDm, precipTotLogNw, precipTotMu
;
; EMAIL QUESTIONS OR COMMENTS AT:
;       https://pmm.nasa.gov/contact
;-

FUNCTION get_cmb_datasets_v7, group_id, label, READ_ALL=read_all

   all = KEYWORD_SET(read_all)

   nmbrs = h5g_get_num_objs(group_id)
;   print, "No. Objects = ", nmbrs
   ; identify and extract the datasets one by one
   dtnames=STRARR(nmbrs)
   for immbr = 0, nmbrs-1 do begin
      ; get the object's information
      dtnames[immbr]=H5G_GET_OBJ_NAME_BY_IDX(group_id,immbr)
      info=H5G_GET_OBJINFO(group_id, dtnames[immbr])
;      print, dtnames[immbr], ": ", info.type
      IF info.type EQ 'DATASET' THEN BEGIN
         dtID = h5d_open(group_id, dtnames[immbr])
         CASE dtnames[immbr] OF
                           'Latitude' : Latitude = h5d_read(dtID)
                          'Longitude' : Longitude = h5d_read(dtID)
                    'PSDparamLowNode' : PSDparamLowNode = h5d_read(dtID)
                        'airPressure' : IF all THEN airPressure = h5d_read(dtID)
                     'airTemperature' : IF all THEN airTemperature = $
                                        h5d_read(dtID)
                  'cloudIceWaterCont' : cloudIceWaterCont = h5d_read(dtID)
                  'cloudLiqWaterCont' : cloudLiqWaterCont = h5d_read(dtID)
                'columnCloudLiqSigma' : IF all THEN columnCloudLiqSigma = $
                                        h5d_read(dtID)
                   'columnVaporSigma' : IF all THEN columnVaporSigma = $
                                        h5d_read(dtID)
             'correctedReflectFactor' : correctedReflectFactor = h5d_read(dtID)
                       'envParamNode' : IF all THEN envParamNode = $
                                        h5d_read(dtID)
                     'errorOfDataFit' : IF all THEN errorOfDataFit = $
                                        h5d_read(dtID)
                   'liqMassFracTrans' : IF all THEN liqMassFracTrans = $
                                        h5d_read(dtID)
                   'liqRateFracTrans' : IF all THEN liqRateFracTrans = $
                                        h5d_read(dtID)
                   'multiScatSurface' : IF all THEN multiScatSurface = $
                                        h5d_read(dtID)
                      'phaseBinNodes' : phaseBinNodes = h5d_read(dtID)
                                'pia' : pia = h5d_read(dtID)
                 'precipTotWaterCont' : precipTotWaterCont = h5d_read(dtID)
            'precipTotWaterContSigma' : precipTotWaterContSigma = h5d_read(dtID)
            
;              'precipTotPSDparamHigh' : precipTotPSDparamHigh = h5d_read(dtID)
; removed low res params in v7
;               'precipTotPSDparamLow' : precipTotPSDparamLow = h5d_read(dtID)
              			'precipTotDm' : precipTotDm = h5d_read(dtID)
              		 'precipTotLogNw' : precipTotLogNw = h5d_read(dtID)
              		    'precipTotMu' : precipTotMu = h5d_read(dtID)              		 
                      'precipTotRate' : precipTotRate = h5d_read(dtID)
                 'precipTotRateSigma' : IF all THEN precipTotRateSigma = $
                                        h5d_read(dtID)
                'simulatedBrightTemp' : simulatedBrightTemp = h5d_read(dtID)
                    'skinTemperature' : IF all THEN skinTemperature = $
                                        h5d_read(dtID)
                      'skinTempSigma' : IF all THEN skinTempSigma = $
                                        h5d_read(dtID)
                 'subFootVariability' : IF all THEN subFootVariability = $
                                        h5d_read(dtID)
                     'surfEmissivity' : IF all THEN surfEmissivity = $
                                        h5d_read(dtID)
                     'surfEmissSigma' : IF all THEN surfEmissSigma = $
                                        h5d_read(dtID)
                    'surfLiqRateFrac' : IF all THEN surfLiqRateFrac = $
                                        h5d_read(dtID)
                  'surfPrecipTotRate' : surfPrecipTotRate = h5d_read(dtID)
              'nearSurfPrecipTotRate' : surfPrecipTotRate = h5d_read(dtID)
             'surfPrecipTotRateSigma' : IF all THEN surfPrecipTotRateSigma = $
                                        h5d_read(dtID)
                 'surfaceAirPressure' : IF all THEN surfaceAirPressure = $
                                        h5d_read(dtID)
              'surfaceAirTemperature' : IF all THEN surfaceAirTemperature = $
                                        h5d_read(dtID)
                'surfaceVaporDensity' : IF all THEN surfaceVaporDensity = $
                                        h5d_read(dtID)
                  'tenMeterWindSigma' : IF all THEN tenMeterWindSigma = $
                                        h5d_read(dtID)
                  'tenMeterWindSpeed' : IF all THEN tenMeterWindSpeed = $
                                        h5d_read(dtID)
                       'vaporDensity' : IF all THEN vaporDensity = $
                                        h5d_read(dtID)
            ELSE : BEGIN
;                      message, "Unknown group member: "+dtnames[immbr], /INFO
                   END
         ENDCASE
;         dtval = h5d_read(dtID)
;         print, dtval[0]
         h5d_close, dtID
      ENDIF
   endfor

   IF all THEN BEGIN
      datasets_struc = { source : label, $
                         Latitude : Latitude, $
                         Longitude : Longitude, $
;                         PSDparamLowNode : PSDparamLowNode, $
                         airPressure : airPressure, $
                         airTemperature : airTemperature, $
                         cloudIceWaterCont : cloudIceWaterCont, $
                         cloudLiqWaterCont : cloudLiqWaterCont, $
                         correctedReflectFactor : correctedReflectFactor, $
                         envParamNode : envParamNode, $
;                         iceDensity : iceDensity, $
                         liqMassFracTrans : liqMassFracTrans, $
                         liqRateFracTrans : liqRateFracTrans, $
                         phaseBinNodes : phaseBinNodes, $
                         pia : pia, $
                         precipTotWaterCont : precipTotWaterCont, $
                         precipTotWaterContSigma : precipTotWaterContSigma, $
;                         precipTotPSDparamHigh : precipTotPSDparamHigh, $
;                         precipTotPSDparamLow : precipTotPSDparamLow, $
                         precipTotDm : precipTotDm, $
                         precipTotLogNw : precipTotLogNw, $
                         precipTotMu : precipTotMu, $
                         precipTotRate : precipTotRate, $
                         precipTotRateSigma : precipTotRateSigma, $
                         simulatedBrightTemp : simulatedBrightTemp, $
                         skinTemperature : skinTemperature, $
                         surfEmissivity : surfEmissivity, $
                         surfLiqRateFrac : surfLiqRateFrac, $
                         surfPrecipTotRate : surfPrecipTotRate, $
                         surfPrecipTotRateSigma : surfPrecipTotRateSigma, $
                         surfaceAirPressure : surfaceAirPressure, $
                         surfaceAirTemperature : surfaceAirTemperature, $
                         surfaceVaporDensity : surfaceVaporDensity, $
                         tenMeterWindSpeed : tenMeterWindSpeed, $
                         vaporDensity : vaporDensity }
     ; append extra V05 variables, as available
      IF N_ELEMENTS(columnCloudLiqSigma) NE 0 THEN $
         datasets_struc = CREATE_STRUCT(datasets_struc, 'columnCloudLiqSigma', $
                                        columnCloudLiqSigma)
      IF N_ELEMENTS(columnVaporSigma) NE 0 THEN $
         datasets_struc = CREATE_STRUCT(datasets_struc, 'columnVaporSigma', $
                                        columnVaporSigma)
      IF N_ELEMENTS(errorOfDataFit) NE 0 THEN $
         datasets_struc = CREATE_STRUCT(datasets_struc, 'errorOfDataFit', $
                                        errorOfDataFit)
      IF N_ELEMENTS(multiScatSurface) NE 0 THEN $
         datasets_struc = CREATE_STRUCT(datasets_struc, 'multiScatSurface', $
                                        multiScatSurface)
      IF N_ELEMENTS(skinTempSigma) NE 0 THEN $
         datasets_struc = CREATE_STRUCT(datasets_struc, 'skinTempSigma', $
                                        skinTempSigma)
      IF N_ELEMENTS(subFootVariability) NE 0 THEN $
         datasets_struc = CREATE_STRUCT(datasets_struc, 'subFootVariability', $
                                        subFootVariability)
      IF N_ELEMENTS(surfEmissSigma) NE 0 THEN $
         datasets_struc = CREATE_STRUCT(datasets_struc, 'surfEmissSigma', $
                                        surfEmissSigma)
      IF N_ELEMENTS(tenMeterWindSigma) NE 0 THEN $
         datasets_struc = CREATE_STRUCT(datasets_struc, 'tenMeterWindSigma', $
                                        tenMeterWindSigma)
   ENDIF ELSE BEGIN
      datasets_struc = { source : label, $
                         Latitude : Latitude, $
                         Longitude : Longitude, $
;                         PSDparamLowNode : PSDparamLowNode, $
                         correctedReflectFactor : correctedReflectFactor, $
                         phaseBinNodes : phaseBinNodes, $
                         pia : pia, $
                         precipTotWaterCont : precipTotWaterCont, $
                         precipTotWaterContSigma : precipTotWaterContSigma, $
;                         precipTotPSDparamHigh : precipTotPSDparamHigh, $
                         cloudLiqWaterCont : cloudLiqWaterCont, $
                         cloudIceWaterCont : cloudIceWaterCont, $
                         simulatedBrightTemp : simulatedBrightTemp, $
;                         precipTotPSDparamLow : precipTotPSDparamLow, $
                         precipTotDm : precipTotDm, $
                         precipTotLogNw : precipTotLogNw, $
                         precipTotMu : precipTotMu, $
                         precipTotRate : precipTotRate, $
                         surfPrecipTotRate : surfPrecipTotRate }
   ENDELSE

return, datasets_struc
end
