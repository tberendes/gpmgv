      print, '' & print, "Reading file: ", file_2bcmb & print, ''
     ; read both swaths, but only default variables
      data_COMB = read_2bcmb_hdf5( file_2bcmb )
      IF SIZE(data_COMB, /TYPE) NE 8 THEN BEGIN
         PRINT, ""
         PRINT, "ERROR reading fields from ", file_2bcmb
         PRINT, "Skipping 2BCMB processing for orbit = ", orbit
         PRINT, ""
         havefile2bcmb = 0
      ENDIF
  ;-----------------------------------------------------------------------------

; READ THE SWATH OF INTEREST IN EACH ITERATION, EXTRACT DPRGMI VARIABLES.
  ; Begin loop over swath/source types: MS/Ku, MS/Ka, NS/Ku

   swathIDs = ['MS','MS','NS']
   instruments = ['Ku','Ka','Ku']
  ; indices for finding correct subarray in MS swath for variables
  ; with the nKuKa dimension:
   idxKuKa = [0,1,0]

  ; holds number of in-range footprints for each swath/source combo, for setting
  ; dimensions in the matchup netCDF file
   num_fp_by_source = INTARR(3)

  ; ditto, but holds number of in-range scans for each swath/source for
  ; dimensioning date/time variables:
   nscansBySwath = INTARR(3)

  ; get the numbers of in-range footprints for each combo

   for swathID = 0, N_ELEMENTS(swathIDs)-1 do begin
     ; get the group structure for the specified scantype, tags vary by swath
      DPR_scantype = swathIDs[swathID]
      instrumentID = instruments[swathID]
      print, ''
      PRINT, "Extracting ", instrumentID+' '+DPR_scantype+" data fields from structure."
      print, ''

      CASE STRUPCASE(DPR_scantype) OF
         'MS' : BEGIN
                   RAYSPERSCAN = RAYSPERSCAN_MS
                   GATE_SPACE = BIN_SPACE_DPRGMI
                   ptr_swath = data_COMB.MS
                END
         'NS' : BEGIN
                   RAYSPERSCAN = RAYSPERSCAN_NS
                   GATE_SPACE = BIN_SPACE_DPRGMI
                   ptr_swath = data_COMB.NS
                END
         ELSE : message, "Illegal scan type '"+DPR_scantype+"'"
      ENDCASE
      ; get the number of scans in the dataset
      SAMPLE_RANGE = ptr_swath.SWATHHEADER.NUMBERSCANSBEFOREGRANULE $
                   + ptr_swath.SWATHHEADER.NUMBERSCANSGRANULE $
                   + ptr_swath.SWATHHEADER.NUMBERSCANSAFTERGRANULE

      ; extract DPR variables/arrays from struct pointers
      IF PTR_VALID(ptr_swath.PTR_DATASETS) THEN BEGIN
         prlons = (*ptr_swath.PTR_DATASETS).LONGITUDE
         prlats = (*ptr_swath.PTR_DATASETS).LATITUDE
      ENDIF ELSE message, "Invalid pointer to PTR_DATASETS."

      ; get the number of scans in the dataset
      SAMPLE_RANGE = ptr_swath.SWATHHEADER.NUMBERSCANSBEFOREGRANULE $
                   + ptr_swath.SWATHHEADER.NUMBERSCANSGRANULE $
                   + ptr_swath.SWATHHEADER.NUMBERSCANSAFTERGRANULE

      ; extract DPR variables/arrays from struct pointers
      IF PTR_VALID(ptr_swath.PTR_SCANTIME) THEN BEGIN
         Year = (*ptr_swath.PTR_SCANTIME).Year
         Month = (*ptr_swath.PTR_SCANTIME).Month
         DayOfMonth = (*ptr_swath.PTR_SCANTIME).DayOfMonth
         Hour = (*ptr_swath.PTR_SCANTIME).Hour
         Minute = (*ptr_swath.PTR_SCANTIME).Minute
         Second = (*ptr_swath.PTR_SCANTIME).Second
         Millisecond = (*ptr_swath.PTR_SCANTIME).MilliSecond
      ENDIF ELSE message, "Invalid pointer to PTR_SCANTIME."

      IF PTR_VALID(ptr_swath.PTR_DATASETS) THEN BEGIN
         prlons = (*ptr_swath.PTR_DATASETS).LONGITUDE
         prlats = (*ptr_swath.PTR_DATASETS).LATITUDE
         PSDparamLowNode = (*ptr_swath.PTR_DATASETS).PSDparamLowNode
         correctedReflectFactor = $
                (*ptr_swath.PTR_DATASETS).correctedReflectFactor  ;nKuKa
         phaseBinNodes = (*ptr_swath.PTR_DATASETS).phaseBinNodes
         pia = (*ptr_swath.PTR_DATASETS).pia                      ;nKuKa
         precipTotWaterCont = (*ptr_swath.PTR_DATASETS).precipTotWaterCont
         precipTotPSDparamHigh = (*ptr_swath.PTR_DATASETS).precipTotPSDparamHigh
         precipTotPSDparamLow = (*ptr_swath.PTR_DATASETS).precipTotPSDparamLow
         precipTotRate = (*ptr_swath.PTR_DATASETS).precipTotRate
         surfPrecipTotRate = (*ptr_swath.PTR_DATASETS).surfPrecipTotRate
;         ptr_free, ptr_swath.PTR_DATASETS
      ENDIF ELSE message, "Invalid pointer to PTR_DATASETS."

      IF PTR_VALID(ptr_swath.PTR_Input) THEN BEGIN
         ellipsoidBinOffset = (*ptr_swath.PTR_Input).ellipsoidBinOffset      ;nKuKa
         localZenithAngle = (*ptr_swath.PTR_Input).localZenithAngle
         lowestClutterFreeBin = (*ptr_swath.PTR_Input).lowestClutterFreeBin  ;nKuKa
         precipitationFlag = (*ptr_swath.PTR_Input).precipitationFlag        ;nKuKa
         precipitationType = (*ptr_swath.PTR_Input).precipitationType
         surfaceElevation = (*ptr_swath.PTR_Input).surfaceElevation
         surfaceRangeBin = (*ptr_swath.PTR_Input).surfaceRangeBin            ;nKuKa
         surfaceType = (*ptr_swath.PTR_Input).surfaceType
;         ptr_free, ptr_swath.PTR_Input
      ENDIF ELSE message, "Invalid pointer to PTR_Input."

      ; deal with the nKuKa dimension in MS swath.  Get either the Ku or Ka
      ; subarray depending on where we are in the inner (swathID) loop
       IF ( DPR_scantype EQ 'MS' ) THEN BEGIN
          KKidx = idxKuKa[swathID]
          correctedReflectFactor = REFORM(correctedReflectFactor[KKidx,*,*,*])
          pia = REFORM(pia[KKidx,*,*])
          ellipsoidBinOffset = REFORM(ellipsoidBinOffset[KKidx,*,*])
          lowestClutterFreeBin = REFORM(lowestClutterFreeBin[KKidx,*,*])
          precipitationFlag = REFORM(precipitationFlag[KKidx,*,*])
          surfaceRangeBin = REFORM(surfaceRangeBin[KKidx,*,*])
       ENDIF
   endfor   ; swathID, loop through swath/source combos

