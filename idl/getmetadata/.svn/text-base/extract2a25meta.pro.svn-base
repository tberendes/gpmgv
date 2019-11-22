;+
; Copyright © 2008, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; DESCRIPTION:
;      Reads bright band height and rain flag fields from TRMM PR product 2A25,
;      resamples them to a  4x4 km grid centered on an overpassed ground radar,
;      computes statistics of bright band existence/height and "rain certain"
;      state over (a) the entire 300x300 km grid, and (b) for those
;      points within 100 km of the radar (i.e., the grid center).  Writes the
;      individual statistic values and data and overpass event identifiers to a
;      delimited text file for loading into the gpmgv database.  These
;      identifiers are key values within the database and cannot be changed
;      without making corresponding changes or additions to the database.
;
; HISTORY:
;      Bob Morris, SAIC, GPM GV, Code 422, NASA/GSFC, kenneth.r.morris@nasa.gov
;      - Near-total rewrite to add error checks, compute/output metadata values,
;        speed up processing of scans, do nearest-neighbor analyses.
;
;      Morris/GPM   Jul. 9, 2008
;      - Made into IDL function, along with read_2a25_ppi.  Deal with return
;        status from read_2a25_ppi.
;
;      Morris/GPM   Jul. 10, 2008
;      - Renamed from access2A25.pro.  Add metadata values for within 100km.
;        Changed required formal parameters to non-keyword.  Dropped Height,
;        nAvgHeight, dbz2A25, Track, SURF_RAIN and RAIN keyword parameters, not used.
;
;      Morris/GPM   Apr. 16, 2012
;      - Modified PRINT statement at top of, and added PRINT statement after,
;        site/event loop
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-

function extract2A25meta, file_2a25, dist, unlout, $
                          RANGE_BIN_BB=BB_Hgt, FLAG_RAIN=rainFlagMap

common sample, start_sample,sample_range,num_range,dbz_min
common time, TRMM_TIME, hh_gv, mm_gv, ss_gv, year, month, day, orbit
common sample_rain, RAIN_MIN, RAIN_MAX
common groundSite, event_num, siteID, siteLong, siteLat, nsites

print, ""
idx100 = where( dist LE 100.0, count100 )
if ( count100 EQ 0 ) then begin
   print, "ERROR in extract2a25meta(): can't find points <= 100km in dist array provided."
   status = 'extract2A25meta: ERROR IN DIST ARRAY'
   goto, errorExit
endif
;
; Read 2a25 Correct dBZ (and friends)
;

; bit maps for selected 2A25 Rain Flag indicators:
RAIN_POSSIBLE = 1  ;bit 0
RAIN_CERTAIN = 2   ;bit 1
STRATIFORM = 16    ;bit 4
CONVECTIVE = 32    ;bit 5
BB_EXISTS = 64     ;bit 6 - BB = Bright Band
NOT_USED = 1024    ;bit 10

num_range = 80

surfRain_2a25=fltarr(sample_range>1,49)

geolocation=fltarr(2,49,sample_range>1)

rangeBinNums=intarr(sample_range>1,49,7)

rainFlag=intarr(sample_range>1,49)


status = read_2a25_ppi( file_2a25, SURFACE_RAIN=surfRain_2a25, $
                        GEOL=geolocation, RANGE_BIN=rangeBinNums, $
                        RN_FLAG=rainFlag)

if ( status NE 'OK' ) then begin
   print, "*****************************************************"
   print, "In extract2A25meta, read_2a25_ppi status = ", status
   print, "-- 2A25 file = ", file_2a25
   print, "EXIT WITH ERROR"
   print, "*****************************************************"
   goto, errorExit
end

; output metadata values will go in this array, initialize to "missing":
nummeta = 8
metavalue = fltarr(nummeta)
metavalue[*] = -999.0

; In the array of 7 int values of rangeBinNum, bin number of the
; bright band is the fourth value (index = 3).  Cut it from the 3d array.
brightBand=rangeBinNums[*,*,3]

lons = fltarr(49,sample_range>1)
lats = fltarr(49,sample_range>1)
lons[*,*] = geolocation[1,*,*]
lats[*,*] = geolocation[0,*,*]

;******************************************************************************
; Here is where we now start looping over the list of sites overpassed in
; this orbit. Need to reinitialize variables first (as a good practice).
;******************************************************************************

for siteN = 0, nsites - 1 do begin

print, format='("Processing 2A25 metadata for ",a0,", event_num ",i0)', $
       siteID[siteN], event_num[siteN]

; -- Now find x,y, and element (i.e., z) data in our bounding box
;    within +/- 150km of ground radar.  Will be at random (x,y) points
;    relative to the GV radar grid of 2A55

metavalue[*] = -999.0
count = 0L
xdata = fltarr(90000)             & xdata[*]=0.0
ydata = fltarr(90000)             & ydata[*]=0.0

zdata_2a25_srain = fltarr(90000) & zdata_2a25_srain[*]=0.0

; Keep Bright Band points in separate variables, for Nearest-Neighbor analysis.
; We add MISSING border points at scan edges for this type of analysis, which
; extrapolates outside the input points, so we need to keep them separately.
countBB = 0L
xdataBB = fltarr(90000)             & xdata[*]=0.0
ydataBB = fltarr(90000)             & ydata[*]=0.0
zdata_BB_Hgt = fltarr(90000)         & zdata_BB_Hgt[*]=0.0
zdata_rainflag = intarr(90000)       & zdata_rainflag[*]=0

;closelat=-99.9 & closelon=-99.9 & closex=-999.9 & closey=-999.9
;coordinate_b_to_a, siteLong[siteN], siteLat[siteN], lons[0,0], $
;                lats[0,0], XX, YY
;closest=sqrt(xx * xx + yy * yy)

for scan=0,SAMPLE_RANGE-1 do begin
for angle = 0, 48 do begin
 ; coarse filter to PR beams within +/- 3 degrees of site lat/lon
 IF (ABS(lons[angle,scan]-siteLong[siteN]) lt 3.) and $
     (ABS(lats[angle,scan]-siteLat[siteN]) lt 3.) then begin
     
  coordinate_b_to_a, siteLong[siteN], siteLat[siteN], lons[angle,scan], $
                  lats[angle,scan], XX, YY

;  dist_to_rad  = sqrt(xx * xx + yy * yy)
;  if (dist_to_rad lt closest) then begin
;     closest = dist_to_rad
;     closelat = lats[angle,scan]
;     closelon = lons[angle,scan]
;     closex = xx
;     closey = yy
;  endif

  ; fine filter, save only points falling within the 300x300km grid bounds
  if (abs(XX) le 150.) and (abs(YY) le 150.) then begin
    xdata[count] = XX
    ydata[count] = YY
    xdataBB[countBB] = XX
    ydataBB[countBB] = YY

      if surfRain_2a25[scan,angle] gt rain_min then begin
         zdata_2a25_srain[count] = surfRain_2a25[scan,angle]
      endif else begin
         zdata_2a25_srain[count] = -999.
      endelse

;     get the data points for nearest-neighbor interpolations
;     - convert range bin number to BBhgt, km (AGL? slant?)
      zdata_BB_Hgt[countBB] = ( 79 - brightBand[scan,angle] ) * 0.25
      zdata_rainflag[countBB] = rainFlag[scan,angle]
      countBB = countBB + 1

;     Paint a band of MISSING bright band values off either edge of the scan to
;     force the nearest-neighbor interpolation to set the bright band values
;     to MISSING (-1) when extrapolating gridpoints outside PR scan limits
;     Using -1 for MISSING BB so that the BB histogram isn't too 'wide'.
;     Use NOT_USED (1024) for MISSING for rain flag.

      if (angle eq 0) then begin 
         ; Get the next footprint's X and Y
         coordinate_b_to_a, siteLong[siteN], siteLat[siteN], lons[angle+1,scan], $
                         lats[angle+1,scan], XX2, YY2
         ; extrapolate X and Y to where (angle = -1) would be
         XX2 = XX - (XX2 - XX)
         YY2 = YY - (YY2 - YY)
         ; if within the grid, add a MISSING point to the x-y-z data arrays
         if (abs(XX2) le 150.) and (abs(YY2) le 150.) then begin
            xdataBB[countBB] = XX2
            ydataBB[countBB] = YY2
            zdata_BB_Hgt[countBB] = -1.
            zdata_rainflag[countBB] = NOT_USED
            countBB = countBB + 1
         endif
      endif

      if (angle eq 48) then begin
         ; Get the prior footprint's X and Y
         coordinate_b_to_a, siteLong[siteN], siteLat[siteN], lons[angle-1,scan], $
                         lats[angle-1,scan], XX2, YY2
         ; extrapolate X and Y to where (angle = 49) would be
         XX2 = XX + (XX - XX2)
         YY2 = YY + (YY - YY2)
         ; if within the grid, add a MISSING point to the x-y-z data arrays
         if (abs(XX2) le 150.) and (abs(YY2) le 150.) then begin
            xdataBB[countBB] = XX2
            ydataBB[countBB] = YY2
            zdata_BB_Hgt[countBB] = -1.
            zdata_rainflag[countBB] = NOT_USED
            countBB = countBB + 1
         endif
      endif
    
    count = count + 1
   ;print, scan, angle, XX, YY, zdata[count-1]

  endif
  
 ENDIF

endfor
endfor

;print, siteLong[siteN], siteLat[siteN], closelon, closelat, closex, closey, closest

; -- Now analyze each field to a regular grid centered on ground radar
if (count gt 0) then begin
  x = xdata[0:count-1] & y = ydata[0:count-1] 
  TRIANGULATE, x, y, tr
  z_2a25_srain = zdata_2a25_srain[0:count-1]
  srain_map_2a25 = TRIGRID(x, y, z_2a25_srain, tr, [2,2], $
                           [-150.,-150.,150.,150.])
  srain_new_2a25 = srain_map_2a25[0:149,0:149]
  srain_new_2a25 = REBIN(srain_new_2a25,75,75)
  
; set x,y points for BB, rain flag nearest-neighbor interpolations
  x2 = xdataBB[0:countBB-1] & y2 = ydataBB[0:countBB-1] 
  TRIANGULATE, x2, y2, tr2
; generate the grid x,y locations, in km, GRIDDATA() needs for the output grid
  xpos4 = indgen(75)
  xpos4 = xpos4 * 4 - 148
  ypos4 = xpos4
; set the z data and do the nearest-neighbor analysis
  z_BB_Hgt=zdata_BB_Hgt[0:countBB-1]
  BB_Hgt = GRIDDATA(x2, y2, z_BB_Hgt, /NEAREST_NEIGHBOR, TRIANGLES=tr2, $
                        /GRID, XOUT=xpos4, YOUT=ypos4)
  z_rainflag=zdata_rainflag[0:countBB-1]
  rainFlagMapF = GRIDDATA(x2, y2, z_rainflag, /NEAREST_NEIGHBOR, TRIANGLES=tr2, $
                        /GRID, XOUT=xpos4, YOUT=ypos4)
; GRIDDATA does interp in double precision, returns float; we need back in INT
  rainFlagMap = FIX(rainFlagMapF)


; Generate BB Height histogram for 4km grid and write to file

  histo = HISTOGRAM( BB_Hgt, LOCATIONS=idxhist )
;  print, siteID[siteN], " Bright Band Histogram:"
;  print, histo
;  print, "Histogram height bin values:"
;  print, idxhist
;  print, ""

  idxeq0=where(idxhist eq 0.0, count0)
  idxgt0=where(idxhist gt 0.0, countgt0)

  if (count0 gt 0) then begin
    nbb0 = histo[idxeq0]
  endif else begin
    nbb0 = 0
  endelse
;  print, "Num pts no BB Height: ", nbb0

  if (countgt0 gt 0) then begin
    nbbgt0 = total(histo[idxgt0])
;    bbAvg = total(histo[idxgt0]*idxhist[idxgt0])/nbbgt0
    idxBBgt0 = WHERE(BB_Hgt gt 0.0)
    bbAvg = MEAN(BB_Hgt[idxBBgt0])
  endif else begin
    nbbgt0 = 0
    bbAvg = -999.
  endelse
;  print, "Avg. BB Height, where given: ", bbAvg
;  print, "Num. BB Heights given: ", nbbgt0

  pctBB = -999.
  if ( (nbb0 + nbbgt0) gt 0 ) then pctBB = float(nbbgt0)/( nbb0 + nbbgt0 )
;  print, "Percent coincident area with bright band height given: ", pctBB

; pull metrics out of the RainFlag elements
  idxRain = WHERE((rainFlagMap AND RAIN_CERTAIN) NE 0, numRainPts)
;  print, "Num Gridpoints with Rain Certain flag: ", numRainPts
  idxBBExists = WHERE((rainFlagMap AND BB_EXISTS) NE 0, numBBXPts)
;  print, "Num Gridpoints with BB Exists flag: ", numBBXPts
  if (numBBXPts gt 0) then begin
    bbExistsAvg = MEAN(BB_Hgt[idxBBExists])
  endif else begin
    bbExistsAvg = -999.
  endelse

; compute the two metrics for within 100km

;idx100 = where( dist LE 100.0, count100 )
;if ( count100 GT 0 ) then begin
   idxcoinc = where( BB_Hgt[idx100] GE 0.0, numCoinc100 )
   rainFlagMap100 = rainFlagMap[idx100]
   idxRain100 = where( (rainFlagMap100 AND RAIN_CERTAIN) NE 0, numRainPts100)
;endif else begin
;   print, "ERROR in extract2a25meta(): can't find points <= 100km in dist array provided."
;endelse


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

  metavalue[0] = bbAvg
  metavalue[1] = nbbgt0
  metavalue[2] = bbExistsAvg
  metavalue[3] = numBBXPts
  metavalue[4] = numRainPts
  metavalue[5] = (nbbgt0 + nbb0)
  metavalue[6] = numRainPts100
  metavalue[7] = numCoinc100

endif else begin

  print, "WARNING:  No grids/metadata able to be computed for event!"

endelse  ; (count gt 0)

metaID = [251001L, 251002L, 251003L, 251004L, 251005L, 250999L, 251105L, 250199L]

for m=0, nummeta-1 do begin
   printf, UNLOUT, format = '(2(i0,"|"),f0.5)', $
           event_num[siteN], metaID[m], metavalue[m]
;   print, format = '(2(i0,"|"),f0.5)', $
;           event_num[siteN], metaID[m], metavalue[m]
endfor

endfor      ;(nsites loop)

errorExit:
print, ""
return, status

end

@read_2a25_ppi.pro
