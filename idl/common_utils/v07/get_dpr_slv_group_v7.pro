;+
; Copyright © 2013, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; get_dpr_slv_group_v7.pro         Bob Morris, GPM GV/SAIC   May 2013
;
; DESCRIPTION
; Given the HDF5 ID of its parent group, gets each data element for the DPR,
; Ka, or Ku SLV Group and returns a structure containing the individual 
; element names as the structure tags, and the SLV element data arrays
; as the structure values.  Returns -1 in case of errors.
;
; PARAMETERS
; ----------
; group_id  -- HDF5 ID of the parent group of the SLV group
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
; 06/24/14  Morris/GPM GV/SAIC
; - Added paramDSD to the list of variables to be read by default.
; 09/05/14  Morris/GPM GV/SAIC
; - Added qualitySLV to the list of variables to be read in READ_ALL case.
; - Changed logic to not fail if there are new variables in the file that are
;   not yet defined in the CASE statement.
; 11/25/15  Morris/GPM GV/SAIC
; - Added reading and output of paramNUBF variable for V04x files for READ_ALL.
; 07/27/16  Morris/GPM GV/SAIC
; - Added epsilon to the list of variables to be read by default.
; 06/25/20  Berendes/UAH
; - changes for V07 files
; 10/26/20  Berendes/UAH
; - Added precipWaterIntegrated to the list of variables to be read by default.
; 7/6/22  Berendes/UAH
; - Added new GPM V7 Variable precipWater to the list of variables to be read by default.
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-

FUNCTION get_dpr_slv_group_v7, group_id, prodgroup, READ_ALL=read_all

   all = KEYWORD_SET(read_all)

   gname = 'SLV'
   label = prodgroup+'/'+gname      ; label info for data structure
   ; pull the swath name out of prodgroup string, it follows '__'
   parsed = STRSPLIT(prodgroup, '__', /REGEX, /EXTRACT)
   swathname = parsed[1]
   product = parsed[0]

   ; get the ID of SLV group
   ; -- check that this group contains a SLV group
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
   ; the minimum number of members expected varies depending on the swath ID
   ; - these are V03x counts, expect one more in V04x
   CASE swathname OF
      'HS' : n_expect = 15
      'FS' : n_expect = 15
      ELSE : message, "Unknown swath type given in prodgroup: "+swathname
   ENDCASE

   ; extract the expected date/time field values one by one
   IF nmbrs GE n_expect THEN BEGIN
      dtnames=STRARR(nmbrs)
      for immbr = 0, nmbrs-1 do begin
         dtnames[immbr] = h5g_get_member_name(group_id, gname, immbr)
;         print, dtnames[immbr]
         dtID = h5d_open(ss_group_id, dtnames[immbr])
         CASE dtnames[immbr] OF
                             'binEchoBottom' : IF all THEN binEchoBottom = $
                                               h5d_read(dtID)
                                   'epsilon' : epsilon = h5d_read(dtID)
                                   'flagSLV' : IF all THEN flagSLV = $
                                               h5d_read(dtID)
                                  'paramDSD' : paramDSD = h5d_read(dtID)
                                 'paramNUBF' : IF all THEN paramNUBF = h5d_read(dtID)
                          'phaseNearSurface' : IF all THEN phaseNearSurface = $
                                               h5d_read(dtID)
                                  'piaFinal' : piaFinal = h5d_read(dtID)
                                'precipRate' : precipRate = h5d_read(dtID)
                           'precipRateAve24' : IF all THEN precipRateAve24 = $
                                               h5d_read(dtID)
                        'precipRateESurface' : $
                              precipRateESurface = h5d_read(dtID)
                     'precipRateNearSurface' : $
                           precipRateNearSurface = h5d_read(dtID)
                     'precipWaterIntegrated' : $
                           precipWaterIntegrated = h5d_read(dtID)
                                'qualitySLV' : IF all THEN qualitySLV = $
                                               h5d_read(dtID)
                        'sigmaZeroCorrected' : IF all THEN $
                              sigmaZeroCorrected = h5d_read(dtID)
                          'zFactorCorrected' : zFactorCorrected = h5d_read(dtID)
                  'zFactorCorrectedESurface' : IF all THEN $
                        zFactorCorrectedESurface = h5d_read(dtID)
               'zFactorCorrectedNearSurface' : IF all THEN $
                     zFactorCorrectedNearSurface = h5d_read(dtID)
; Version 7 changed variable names to 'Final', map to 'Corrected' for consistency in previous version VN files
                          'zFactorFinal' 	 : zFactorCorrected = h5d_read(dtID)
                  'zFactorFinalESurface' : IF all THEN $
                        zFactorCorrectedESurface = h5d_read(dtID)
               'zFactorFinalNearSurface' : IF all THEN $
                     zFactorCorrectedNearSurface = h5d_read(dtID)
                               'precipWater' : precipWater = h5d_read(dtID)
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
      message, STRING(nmbrs, FORMAT='(I0)')+" not "+ $
               STRING(n_expect, FORMAT='(I0)')+" members in group '" $
               +prodgroup+'/'+gname+"'", /INFO
      return, -1
   ENDELSE

   h5g_close, ss_group_id

   ; handle the undefined variables for the MS swath of 2ADPR by defining a
   ; filler value for them, rather than leaving them out of the output structure
   IF product EQ '2ADPR' AND swathname EQ 'MS' THEN BEGIN
      IF N_ELEMENTS(flagSLV) EQ 0 THEN flagSLV = "UNDEFINED" $
         ELSE message, "Unexpected variable 'flagSLV' in 'MS' group."
      IF N_ELEMENTS(paramDSD) EQ 0 THEN paramDSD = "UNDEFINED" $
         ELSE message, "Unexpected variable 'paramDSD' in 'MS' group."
      IF N_ELEMENTS(precipRate) EQ 0 THEN precipRate = "UNDEFINED" $
         ELSE message, "Unexpected variable 'precipRate' in 'MS' group."
   ENDIF

   ; have to use anonymous structures since variable dimensions change!
   IF all THEN BEGIN
      ; define something for qualitySLV for pre-release file reads
      ; so that we don't fail
      IF N_ELEMENTS(qualitySLV) EQ 0 THEN qualitySLV='UNDEFINED'

      SLV_struc = { source : label, $
                    binEchoBottom : binEchoBottom, $
                    epsilon : epsilon, $
                    flagSLV : flagSLV, $
                    paramDSD : paramDSD, $
                    phaseNearSurface : phaseNearSurface, $
                    piaFinal : piaFinal, $
                    precipRate : precipRate, $
                    precipRateAve24 : precipRateAve24, $
                    precipRateESurface : precipRateESurface, $
                    precipRateNearSurface : precipRateNearSurface, $
                    precipWaterIntegrated : precipWaterIntegrated, $
                    qualitySLV : qualitySLV, $
                    sigmaZeroCorrected : sigmaZeroCorrected, $
                    zFactorCorrected : zFactorCorrected, $
                    zFactorCorrectedESurface : zFactorCorrectedESurface, $
                    zFactorCorrectedNearSurface : zFactorCorrectedNearSurface }
     ; append extra V04 variables, as available
      IF N_ELEMENTS(paramNUBF) NE 0 THEN $
         SLV_struc = CREATE_STRUCT(SLV_struc, 'paramNUBF', paramNUBF)
   ENDIF ELSE BEGIN
      SLV_struc = { source : label, $
                    epsilon : epsilon, $
                    paramDSD : paramDSD, $
                    piaFinal : piaFinal, $
                    precipRate : precipRate, $
                    precipRateESurface : precipRateESurface, $
                    precipRateNearSurface : precipRateNearSurface, $
                    precipWaterIntegrated : precipWaterIntegrated, $
                    zFactorCorrected : zFactorCorrected }
   ENDELSE
  ; append extra V07 variable
   IF N_ELEMENTS(precipWater) NE 0 THEN SLV_struc = $
      CREATE_STRUCT(SLV_struc, 'precipWater', precipWater)

return, SLV_struc
end
