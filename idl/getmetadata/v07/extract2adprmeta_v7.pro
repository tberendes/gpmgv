;+
; Copyright © 2014, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; DESCRIPTION:
; ------------
; Reads rain type, bright band height and rain flag fields from FS swath
; type in GPM DPR product 2ADPR or 2AKu, resamples them to a set of 4x4 km
; grids centered on an overpassed ground radar, computes statistics
; of each field over (a) the entire 300x300 km grid, and (b) for those
; points within 100 km of the radar (i.e., the grid center).  Writes the
; individual statistic values and data and overpass event identifiers to a
; delimited text file for loading into the gpmgv database.  These
; identifiers are key values within the database and cannot be changed
; without making corresponding changes or additions to the database.
;
; HISTORY:
; --------
; Morris - Mar 31 2014 - Created from extract2A23meta.pro and
;                        extract2A25meta.pro.
; Berendes - June 15, 2020 - converted to GPM V7 format using FS scan type
;
; NOTES:
; ------
; 1) Information on the types of rain storm.
;  - typePrecip (4-byte integer, array size: nray x nscan):;    Precipitation type is expressed by an 8-digit number. The three major rain 
;    categories, stratiform, onvective, and other, can be obtained as follows:;    When typePrecip is greater than zero, major rain type = typePrecip/10000000;           1   stratiform;           2   convective;           3   other;       -1111   No rain value;       -9999   Missing value
;
; 2) Information on rain flag (flagPrecip).
;  - flagPrecip (4-byte integer, array size: nray x nscan):;    Precipitation or no precipitation.;           1   No precipitation;           2   Precipitation;       -9999   Missing value
;
; 3) Information on bbstatus (qualityBB):
;  - qualityBB (4-byte integer, array size: nray x nscan):;    Quality of the bright band.;           1   Good;           0   BB not detected in the case of rain;       -1111   No rain value;       -9999   Missing value
;
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;
;-

function extract2ADPRmeta_v7, file_2aDPR, Instrument, dist, unlout, RainType=rainType

; "Include" file for DPR-product-specific parameters (i.e., RAYSPERSCAN):
@dpr_params_v7.inc

common sample, start_sample_in, sample_range_in
common time, TRMM_TIME, hh_gv, mm_gv, ss_gv, year, month, day, orbit
common groundSite, event_num, siteID, siteLong, siteLat, nsites

print, ""
idx100 = where( dist LE 100.0, count100 )
if ( count100 EQ 0 ) then begin
   print, "ERROR in extract2aDPRmeta_v7(): can't find points <= 100km in dist array provided."
   status = 'extract2A23meta: ERROR IN DIST ARRAY'
   goto, errorExit
endif
;print, "In extract2ADPRmeta_v7.pro: siteID, siteLong, siteLat, orbit = ", $
;        siteID, siteLong, siteLat, orbit

;
; Read/extract 2aDPR/2AKu Rain Type, BB height, rain flag, lat, lon
;

   DPR_scantype = 'FS'
   RAYSPERSCAN = RAYSPERSCAN_FS
   GATE_SPACE = BIN_SPACE_FS
   print, '' & print, "Reading file: ", file_2adpr & print, ''
   CASE Instrument OF
   ;#######################################  Start here ###########################################
    'DPRX' : dpr_data = read_2adpr_hdf5_v7(file_2adpr, SCAN=DPR_scantype)
     'DPR' : dpr_data = read_2adpr_hdf5_v7(file_2adpr, SCAN=DPR_scantype)
     'KuX' : dpr_data = read_2akaku_hdf5_v7(file_2adpr, SCAN=DPR_scantype)
      'Ku' : dpr_data = read_2akaku_hdf5_v7(file_2adpr, SCAN=DPR_scantype)
      ELSE : message, "Illegal data source '"+Instrument+"', only DPR or Ku allowed."
   ENDCASE

   ; check dpr_data structure for read failures
   IF SIZE(dpr_data, /TYPE) NE 8 THEN $
     message, "Error reading data from: "+dpr_file_read ;$
;   ELSE PRINT, "Extracting data fields from structure."
;   print, ''

   ; get the group structures for the specified scantype, tags vary by swathname
   CASE STRUPCASE(DPR_scantype) OF
      'HS' : ptr_swath = dpr_data.HS
      'FS' : ptr_swath = dpr_data.FS
   ENDCASE
   
   ; get the number of scans in the dataset
   SAMPLE_RANGE = ptr_swath.SWATHHEADER.NUMBERSCANSBEFOREGRANULE $
                + ptr_swath.SWATHHEADER.NUMBERSCANSGRANULE $
                + ptr_swath.SWATHHEADER.NUMBERSCANSAFTERGRANULE

   ; extract DPR variables/arrays from struct pointers
   IF PTR_VALID(ptr_swath.PTR_DATASETS) THEN BEGIN
      lons = (*ptr_swath.PTR_DATASETS).LONGITUDE
      lats = (*ptr_swath.PTR_DATASETS).LATITUDE
      ptr_free, ptr_swath.PTR_DATASETS
   ENDIF ELSE message, "Invalid pointer to PTR_DATASETS."

   IF PTR_VALID(ptr_swath.PTR_CSF) THEN BEGIN
      brightBand = (*ptr_swath.PTR_CSF).HEIGHTBB
      bbstatus = (*ptr_swath.PTR_CSF).QUALITYBB          ; got to convert to TRMM?
      rainType_2aDPR = (*ptr_swath.PTR_CSF).TYPEPRECIP   ; got to convert to TRMM?
   ENDIF ELSE message, "Invalid pointer to PTR_CSF."

   ; When typePrecip is greater than zero, Major rain type = typePrecip/10000000
   ; -1111  No rain value. set to -88 for analysis   ; -9999  Missing value, set to -99 for analysis
   idxhavetype = WHERE( rainType_2aDPR GT 0, numhavetype)
   if numhavetype GT 0 THEN $
      rainType_2aDPR[idxhavetype] = rainType_2aDPR[idxhavetype]/10000000L    ; truncate to TRMM 3-digit type
   idxnegtype = WHERE( rainType_2aDPR EQ -9999, numnegtype)
   if numnegtype GT 0 THEN $
      rainType_2aDPR[idxnegtype] = -99L    ; handle -9999 values
   idxnegtype = WHERE( rainType_2aDPR EQ -1111, numnegtype)
   if numnegtype GT 0 THEN $
      rainType_2aDPR[idxnegtype] = -88L    ; handle -1111 values, set to -8 for now

   ; do the same for HEIGHTBB variable so that we can histogram the gridded values later
   ; -1111.1  No rain value. set to -11 for analysis   ; -9999.  Missing value, set to -22 for analysis
   idxhavetype = WHERE( brightBand GT 0, numhavetype)
   if numhavetype GT 0 THEN $
      brightBand[idxhavetype] = brightBand[idxhavetype]/1000.    ; convert to km
   idxnegtype = WHERE( brightBand LE -9999., numnegtype)
   if numnegtype GT 0 THEN $
      brightBand[idxnegtype] = -22.0    ; handle -9999. values, set to -22. for now
   idxnegtype = WHERE( brightBand EQ -1111.1, numnegtype)
   if numnegtype GT 0 THEN $
      brightBand[idxnegtype] = -11.0    ; handle -1111.1 values, set to -11. for now


;   IF PTR_VALID(ptr_swath.PTR_DSD) THEN BEGIN
;   ENDIF ELSE message, "Invalid pointer to PTR_DSD."

   IF PTR_VALID(ptr_swath.PTR_PRE) THEN BEGIN
      rainFlag = (*ptr_swath.PTR_PRE).FLAGPRECIP
      ptr_free, ptr_swath.PTR_PRE
   ENDIF ELSE message, "Invalid pointer to PTR_PRE."

   IF PTR_VALID(ptr_swath.PTR_SLV) THEN BEGIN
   ENDIF ELSE message, "Invalid pointer to PTR_SLV."

   IF PTR_VALID(ptr_swath.PTR_SRT) THEN BEGIN
   ENDIF ELSE message, "Invalid pointer to PTR_SRT."

   IF PTR_VALID(ptr_swath.PTR_VER) THEN BEGIN
   ENDIF ELSE message, "Invalid pointer to PTR_VER."

   ; free the remaining memory/pointers in data structure
   free_ptrs_in_struct, dpr_data ;, /ver

; Here is a summary of the metadata values we compute and store in the gpmgv
; database, in terms of the variables distributed between the TRMM 2A23 and
; 2A25 products:

; 2A23_N_Stratiform = 230001L
; 2A23_N_Convective = 230002L
; 2A23_N_Other = 230003L
; 2A23_N_NoEcho = 230008L
; 2A23_N_Missing = 230009L
; 2A23_N_Overlap = 230999L (not used)
; AS ABOVE, BUT FOR METADATA FOR WITHIN 100 KM OF THE RADAR (CENTER OF GRID):
; 2A23_N_Stratiform_inside100km = 230101L
; 2A23_N_Convective_inside100km = 230102L
; 2A23_N_Other_inside100km = 230103L
; 2A23_N_NoEcho_inside100km = 230108L
; 2A23_N_Missing_inside100km = 230109L
; 2A23_N_Overlap = 230999L (not used)
; ABOVE IDENTIFIERS ARE DEFINED IN THE GPMGV DATABASE AS KEY VALUES --
; THEY ARE ONE-TO-ONE WITH THE HISTOGRAM CATEGORIES: 1,2,3,8,9; PLUS
; THE METADATA_ID FOR TOTAL OVERLAP GRIDPOINTS
; - CAN'T CHANGE OR REDEFINE THEM HERE WITHOUT MATCHING DATABASE MODS.

;  2A25_AvgBBHgtAny = 251001L
;  2A25_NumBBHgtAny = 251002L
;  2A25_AvgBBHgtExists = 251003L
;  2A25_NumBBHgtExists = 251004L
;  2A25_NumRainCertain = 251005L
;  2A25_NumPROverlapGrdpts = 250999L
;  2A25_NumRainCertainInside100km = 251105L
;  2A25_NumPROverlapGrdptsInside100km = 250199L
;  ABOVE IDENTIFIERS ARE DEFINED IN THE GPMGV DATABASE AS KEY VALUES --
;  - CAN'T CHANGE OR REDEFINE THEM HERE WITHOUT MATCHING DATABASE MODS.

; set up to do the rain type metadata, as in the TRMM 2A23 product
metaID     = [230001L, 230002L, 230003L, 230008L, 230009L, 230999L]
metaID_100 = [230101L, 230102L, 230103L, 230108L, 230109L, 230999L]
nummeta = 6  ; WE'LL HAVE 5 DISCRETE (CATEGORIES OF) RAIN TYPE
             ; VALUES, PLUS THE NON_COINCIDENT VALUE (-7).  This value
             ; must match the dimensions of metaID and metaID_100, above,
             ; and idxhist, defined/used below.

; set up to to do the BB height and rain flag metadata, as in TRMM 2A25
metaID25 = [251001L, 251002L, 251003L, 251004L, 251005L, 250999L, 251105L, 250199L]
nummeta25 = 8
; -- metaID25's metadata values will go in this array, initialize to "missing":
metavalue = fltarr(nummeta25)
metavalue[*] = -999.0

; define arrays sufficient to hold data for the maximum possible number of DPR
; footprints within our analysis region
xdata = fltarr(90000)
ydata = fltarr(90000)
zdata_rainType = fltarr(90000)
zdata_BB_Hgt = fltarr(90000)
zdata_rainflag = intarr(90000)
zdata_bbstatus = intarr(90000)

;******************************************************************************
; Here is where we now start looping over the list of sites overpassed in
; this orbit. Need to reinitialize variables first (as a good practice).
;******************************************************************************

for siteN = 0, nsites - 1 do begin

   print, format='("Processing 2A-",a0," precip. metadata for ",a0,", event_num ",i0)', $
          Instrument, siteID[siteN], event_num[siteN]

   start_sample = start_sample_in
;   sample_range = sample_range_in
   count = 0L
   xdata[*] = 0.0
   ydata[*] = 0.0
   zdata_rainType[*] = 0.0
   zdata_BB_Hgt[*] = 0.0
   zdata_rainflag[*] = 0
   zdata_bbstatus[*] = 0
   metavalue[*] = -999.0

   ; -- Convert lat/lon for each DPR beam sample to ground-radar-centric
   ;    x and y cartesian coordinates, in km.  Store location and element
   ;    data for samples within 150 km in arrays for interpolation to GV grid.
   ;
   for scan=0,SAMPLE_RANGE-1 do begin
     for angle = 0, 48 do begin
       ; coarse filter to PR beams within +/- 3 degrees of site lat/lon
        IF (ABS(lons[angle,scan]-siteLong[siteN]) lt 3.) and $
           (ABS(lats[angle,scan]-siteLat[siteN]) lt 3.) then begin
 
           coordinate_b_to_a, siteLong[siteN], siteLat[siteN], lons[angle,scan], $
                        lats[angle,scan], XX, YY

           ; fine filter, save only points falling within the 300x300km grid bounds
           if (abs(XX) le 150.) and (abs(YY) le 150.) then begin  
            ; POPULATE THE ARRAYS OF POINTS TO BE ANALYZED
             xdata[count] = XX
             ydata[count] = YY
;             if rainType_2aDPR[angle,scan] eq 30 then rainType_2aDPR[angle,scan]=0 ;REVISIT THIS COMMAND!
             zdata_rainType[count] = rainType_2aDPR[angle,scan]
             zdata_BB_Hgt[count] = brightBand[angle,scan]
             zdata_rainflag[count] = rainFlag[angle,scan]
             zdata_bbstatus[count] = bbstatus[angle,scan]
             count = count + 1
;            print, scan, angle, XX, YY, zdata_rainType[count-1]

            ; Paint a band of NON_COINCIDENT off either edge of the scan to
            ; force the nearest-neighbor interpolation to set the value to
            ; NON_COINCIDENT when extrapolating gridpoints outside PR scan
            ; limits
             if (angle eq 0) then begin 
                ; Get the next footprint's X and Y
                coordinate_b_to_a, siteLong[siteN], siteLat[siteN], lons[angle+1,scan], $
                                   lats[angle+1,scan], XX2, YY2
                ; extrapolate X and Y to where (angle = -1) would be
                XX2 = XX - (XX2 - XX)
                YY2 = YY - (YY2 - YY)
                ; add a NON_COINCIDENT point to the data arrays
                xdata[count] = XX2
                ydata[count] = YY2
                zdata_rainType[count] = -77
                zdata_BB_Hgt[count] = -77.
                zdata_rainflag[count] = -77
                zdata_bbstatus[count] = -77
                count = count + 1
             endif
             if (angle eq 48) then begin
                ; Get the prior footprint's X and Y
                coordinate_b_to_a, siteLong[siteN], siteLat[siteN], lons[angle-1,scan], $
                                   lats[angle-1,scan], XX2, YY2
                ; extrapolate X and Y to where (angle = 49) would be
                XX2 = XX + (XX - XX2)
                YY2 = YY + (YY - YY2)
                ; add a NON_COINCIDENT point to the data arrays
                xdata[count] = XX2
                ydata[count] = YY2
                zdata_rainType[count] = -77
                zdata_BB_Hgt[count] = -77.
                zdata_rainflag[count] = -77
                zdata_bbstatus[count] = -77
                count = count + 1
             endif
   
           endif  ;fine x,y filter
        ENDIF     ;coarse lat/lon filter
     endfor       ; angles
   endfor         ; scans

   if (count eq 0L) then begin
      print, "WARNING:  No grids/metadata able to be computed for event!"
     ; write missing data for the 2A23-type metadata values for this event
      missinghist = intarr(nummeta-1)
      missinghist[*] = -999
      for m=0, nummeta-2 do begin
         printf, UNLOUT, format = '(2(i0,"|"),i0)', $
            event_num[siteN], metaID[m], missinghist[m]
         printf, UNLOUT, format = '(2(i0,"|"),i0)', $
            event_num[siteN], metaID_100[m], missinghist[m]
      endfor
     ; write missing data for the 2A25-type metadata values for this event
      for m=0, nummeta25-1 do begin
         printf, UNLOUT, format = '(2(i0,"|"),f0.5)', $
                 event_num[siteN], metaID25[m], metavalue[m]
      endfor
   endif else begin
     ; cut out the arrays of assigned footprint x,y, and data field values
      x = xdata[0:count-1]
      y = ydata[0:count-1]
      z_rainType = zdata_rainType[0:count-1]
      z_BB_Hgt=zdata_BB_Hgt[0:count-1]
      z_rainflag=zdata_rainflag[0:count-1]
      z_bbstatus=zdata_bbstatus[0:count-1]

     ; compute the Delauney triangulation of the x,y coordinates
      TRIANGULATE, x, y, tr
     ; define the Cartesian grid coordinates
      xpos4 = indgen(75)
      xpos4 = xpos4 * 4 - 148
      ypos4 = xpos4

     ; =========================================================================

     ; do the nearest-neighbor gridding of rain type
      rainType_new = GRIDDATA(x, y, z_rainType, /NEAREST_NEIGHBOR, $
                              TRIANGLES=tr, /GRID, XOUT=xpos4, YOUT=ypos4)

      ; handle -77/-88/-99 properly -> -7/-8/-9
      ; GRIDDATA output is FLOAT, cast to INT when rescaling
      rainType = FIX(rainType_new)
      idx123 = WHERE( rainType lt 0, count123 )
      if ( count123 gt 0 ) then rainType[idx123] = rainType[idx123]/10

      ;  This should never be needed now that we use nearest-neighbor interpolation
      idxfixme = WHERE((rainType ne 1) and (rainType ne 2) and (rainType ne 3) $
                and (rainType ne -7) and (rainType ne -8) and (rainType ne -9), count )
      if ( count gt 0 ) then begin
        print, $
        format='("Warning:  Have ",I0, " unknown RainType values in analyzed grid!")',$
           count
      ;  print, rainType[idxfixme]

        rainType[idxfixme]=-8
      endif

      ; Generate RainType histogram for 4km grid and write metadata to file

      ; Convert negative values to their ABS for histogramming
      histo = HISTOGRAM( ABS(RAINTYPE), MIN=0, MAX=9 )
      idxhist = [1,2,3,8,9,7]  ; must have exactly "nummeta" values
      histout = histo[idxhist]
      ; set last array value to the total # of coincident gridpoints
      ; (i.e., exclude those with the NON_COINCIDENT value = -7)
      histout[5] = TOTAL(histout[0:4], /INTEGER)

      ; skip # of Coincident Gridpoints=histout[5] (id=230999) in output,
      ; can derive from others
      for m=0, nummeta-2 do begin
         printf, UNLOUT, format = '(2(i0,"|"),i0)', $
                 event_num[siteN], metaID[m], histo[idxhist[m]]
      endfor

      ; Repeat above for points within 100km of radar
      histo100 = HISTOGRAM( ABS(RAINTYPE[idx100]), MIN=0, MAX=9 )
      for m=0, nummeta-2 do begin
         printf, UNLOUT, format = '(2(i0,"|"),i0)', $
                 event_num[siteN], metaID_100[m], histo100[idxhist[m]]
      endfor

     ; =========================================================================

     ; analyze grids and compute and write metadata for BB height and rain flag

      BB_Hgt = GRIDDATA(x, y, z_BB_Hgt, /NEAREST_NEIGHBOR, TRIANGLES=tr, $
                        /GRID, XOUT=xpos4, YOUT=ypos4)
      ; handle -11./-22./-77. properly -> -1./-2./-7. for histogram
      idx123 = WHERE( BB_Hgt lt 0., count123 )
      if ( count123 gt 0 ) then BB_Hgt[idx123] = BB_Hgt[idx123]/10.

      rainFlagMapF = GRIDDATA(x, y, z_rainflag, /NEAREST_NEIGHBOR, $
                              TRIANGLES=tr, /GRID, XOUT=xpos4, YOUT=ypos4)
    ; GRIDDATA does interp in double precision, returns float; we need back in INT
      rainFlagMap = FIX(rainFlagMapF + 0.0001)

      bbstatusMapF = GRIDDATA(x, y, z_bbstatus, /NEAREST_NEIGHBOR, $
                              TRIANGLES=tr, /GRID, XOUT=xpos4, YOUT=ypos4)
    ; GRIDDATA does interp in double precision, returns float; we need back in INT
      bbstatusMap = FIX(bbstatusMapF + 0.0001)

    ; Generate BB Height histogram for 4km grid and compute BB metrics
      histo = HISTOGRAM( BB_Hgt, LOCATIONS=idxhistBB )
      idxCoincBB=where(idxhistBB gt -6.0, count0)  ; everything but -7 (non-coincident)
      idxgt0=where(idxhistBB gt 0.0, countgt0)

      if (count0 gt 0) then begin
        nbb0 = total(histo[idxCoincBB])
      endif else begin
        nbb0 = 0
      endelse
;      print, "Num pts coincident: ", nbb0

      if (countgt0 gt 0) then begin
        nbbgt0 = total(histo[idxgt0])
;        bbAvg = total(histo[idxgt0]*idxhistBB[idxgt0])/nbbgt0
        idxBBgt0 = WHERE(BB_Hgt gt 0.0)
        bbAvg = MEAN(BB_Hgt[idxBBgt0])
      endif else begin
        nbbgt0 = 0
        bbAvg = -999.
      endelse
;      print, "Avg. BB Height, where given: ", bbAvg
;      print, "Num. BB Heights given: ", nbbgt0

      pctBB = -999.
      if ( nbb0 gt 0 ) then pctBB = float(nbbgt0)/nbb0
;      print, "Percent coincident area with bright band height given: ", pctBB

     ; pull metrics out of the RainFlag, bbstatus elements
      idxRain = WHERE((rainFlagMap AND FLAGPRECIP_PRECIPITATION) NE 0, numRainPts)
;      print, "Num Gridpoints with Rain Certain flag: ", numRainPts
      idxBBExists = WHERE((bbstatusMap AND QUALITYBB_GOOD) NE 0, numBBXPts)
;      print, "Num Gridpoints with BB Exists flag: ", numBBXPts
      if (numBBXPts gt 0) then begin
        bbExistsAvg = MEAN(BB_Hgt[idxBBExists])
      endif else begin
        bbExistsAvg = -999.
      endelse

     ; compute the metrics for within 100km
      idxcoinc = where( BB_Hgt[idx100] GT -6.0, numCoinc100 )
      rainFlagMap100 = rainFlagMap[idx100]
      idxRain100 = where( (rainFlagMap100 AND FLAGPRECIP_PRECIPITATION) NE 0, numRainPts100)
;      idxcoinc = where( rainFlagMap100 GT 0, numCoinc100 )  ; # non-missing footprints

      metavalue[0] = bbAvg
      metavalue[1] = nbbgt0
      metavalue[2] = bbExistsAvg
      metavalue[3] = numBBXPts
      metavalue[4] = numRainPts
      metavalue[5] = nbb0
      metavalue[6] = numRainPts100
      metavalue[7] = numCoinc100

     ; write good "2A25" metadata to db load file
      for m=0, nummeta25-1 do begin
         SWITCH m OF
             0 :
             2 : BEGIN
                    printf, UNLOUT, format = '(2(i0,"|"),f0.5)', $
                       event_num[siteN], metaID25[m], metavalue[m]
                    break
                 END
             ELSE : printf, UNLOUT, format = '(2(i0,"|"),i0)', $
                       event_num[siteN], metaID25[m], metavalue[m]
          ENDSWITCH
      endfor

     ; =========================================================================

   endelse  ; (count eq 0L)

endfor      ;(nsites loop)
status = 'OK'

errorExit:

return, status

end
