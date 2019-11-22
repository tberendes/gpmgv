;+
; Copyright © 2008, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; DESCRIPTION:
;      Reads rain type field from TRMM PR product 2A23, resamples it to a 
;      4x4 km grid centered on an overpassed ground radar, computes statistics
;      of rain types over (a) the entire 300x300 km grid, and (b) for those
;      points within 100 km of the radar (i.e., the grid center).  Writes the
;      individual statistic values and data and overpass event identifiers to a
;      delimited text file for loading into the gpmgv database.  These
;      identifiers are key values within the database and cannot be changed
;      without making corresponding changes or additions to the database.
;
; HISTORY:
;      Morris/GPM   Sept. 2006  
;      - Changed gridding method to Nearest Neighbor, new to IDL 6.x.  This
;        method extrapolates outside the "triangles" defined by the swath
;        lat/lons, so a border of MISSING was added adjacent to the borders of
;        the scan so that any extrapolated values would be MISSINGs.
;      - Modified how v6 rainType values are reduced to single-digit to
;        preserve the difference between No Rain and Missing.
;      - Added the capability to plot image of the gridded raintype and output
;        as a PostScript file. (October change??)
;
;      Morris/GPM   Oct. 2006  
;      - major changes to generate raintype metadata for each site overpassed
;        in the orbit for a given 2A23 GPM subset file.  Changed elements in
;        'groundSite' common to arrays and added siteID (array) and nsites
;        (scalar) elements.  Added 'orbit' to 'time' common.  Added two file
;        name arguments to procedure.  Added a block of code to generate a 
;        histogram of rainType values in the analyzed grid for each site, and
;        write the site/orbit/raintype metadata information out to the file
;       'UNLOUT' in delimited form so it can be loaded into a PostGRESQL
;        database table.
;
;      Morris/GPM   Nov. 2006  
;      - set the edge-of-PR boundary values to -77, to be distinct from data
;        values defined in 2A23.  This makes computation of (non)coincident
;        area possible just from RainType histogram values stored in database.
;
;      Morris/GPM   Jul. 9, 2008
;      - Made into IDL function, along with read_2a23_ppi.  Deal with return
;        status from read_2a23_ppi.
;
;      Morris/GPM   Jul. 10, 2008
;      - Created from access2A23.pro.  Add metadata values for within 100km.
;        Changed most formal parameters to non-keyword.
;
;      Morris/GPM   Apr. 16, 2012
;      - Added PRINT statement at top of, and after, site/event loop, as in
;        extract2A25meta.
;
; Notes:
;     The scale factor to the "rainType" is changed from 10 (v5 or less) to
;     100 (v6)  [2 places]
;
; --- Information on the types of rain storm.
;
; RainType =  1   (Stratiform)
; RainType =  2   (Convective)
; RainType =  3   (Others)
; RainType = -7   (Gridpoint not coincident with PR - not a 2A23 value)
; RainType = -8   (No rain)
; RainType = -9   (Missing data)
;
; rainType[ , ]     size:  75x75  with a pixel representing 4(km)x4(km)
; rainType_hi[ , ]  size: 151x151 with a pixel representing 2(km)x2(km)
;
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;
;-

function extract2A23meta, file_2a23, dist, unlout, $
                          RainType=rainType, StormType=rainType_hi


common sample, start_sample_in, sample_range_in
common time, TRMM_TIME, hh_gv, mm_gv, ss_gv, year, month, day, orbit
common groundSite, event_num, siteID, siteLong, siteLat, nsites

print, ""
idx100 = where( dist LE 100.0, count100 )
if ( count100 EQ 0 ) then begin
   print, "ERROR in extract2a23meta(): can't find points <= 100km in dist array provided."
   status = 'extract2A23meta: ERROR IN DIST ARRAY'
   goto, errorExit
endif
;print, "In access2a23.pro: siteID, siteLong, siteLat, orbit = ", $
;        siteID, siteLong, siteLat, orbit

; 2A23_N_Stratiform = 230001L
; 2A23_N_Convective = 230002L
; 2A23_N_Other = 230003L
; 2A23_N_NoEcho = 230008L
; 2A23_N_Missing = 230009L
; 2A23_N_Overlap = 230999L (not used)
; ABOVE IDENTIFIERS ARE DEFINED IN THE GPMGV DATABASE AS KEY VALUES --
; THEY ARE ONE-TO-ONE WITH THE HISTOGRAM CATEGORIES: 1,2,3,8,9; PLUS
; THE METADATA_ID FOR TOTAL OVERLAP GRIDPOINTS
; - CAN'T CHANGE OR REDEFINE THEM HERE WITHOUT MATCHING DATABASE MODS.

metaID = [230001L, 230002L, 230003L, 230008L, 230009L, 230999L]
nummeta = 6  ;WE'LL HAVE 5 DISCRETE (CATEGORIES OF) RAIN TYPE
             ;VALUES, PLUS THE NON_COINCIDENT VALUE (-7).  This value
             ;must match the dimension of metaID, above, and idxhist,
             ;far below.

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

metaID_100 = [230101L, 230102L, 230103L, 230108L, 230109L, 230999L]

;
; Read 2a23 Rain Type
;

rainType_2a23=intarr(sample_range_in>1,49)
geolocation=fltarr(2,49,sample_range_in>1)
lons = fltarr(49,sample_range_in>1)
lats = fltarr(49,sample_range_in>1)

status = read_2a23_ppi( file_2a23, RAINTYPE=rainType_2a23, GEOL=geolocation )

if ( status NE 'OK' ) then begin
   print, "*****************************************************"
   print, "In extract2A23meta, read_2a23_ppi status = ", status
   print, "-- 2A23 file = ", file_2a23
   print, "EXIT WITH ERROR"
   print, "*****************************************************"
   goto, errorExit
end

lons = fltarr(49,n_elements(geolocation[0,0,*]))
lats = fltarr(49,n_elements(geolocation[0,0,*]))

lons[*,*] = geolocation[1,*,*]
lats[*,*] = geolocation[0,*,*]

xdata = fltarr(90000)
ydata = fltarr(90000)
zdata = fltarr(90000)

;******************************************************************************
; Here is where we now start looping over the list of sites overpassed in
; this orbit. Need to reinitialize variables first (as a good practice).
;******************************************************************************

for siteN = 0, nsites - 1 do begin

print, format='("Processing 2A23 metadata for ",a0,", event_num ",i0)', $
       siteID[siteN], event_num[siteN]

start_sample = start_sample_in
sample_range = sample_range_in
count = 0L
xdata[*] = 0.0
ydata[*] = 0.0
zdata[*] = 0.0

; -- Convert lat/lon for each PR beam sample to ground-radar-centric
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
                      
    xdata[count] = XX
    ydata[count] = YY
    if rainType_2a23[scan,angle] eq 30 then begin
      rainType_2a23[scan,angle]=0 
    endif
    zdata[count] = rainType_2a23[scan,angle]
    count = count + 1
;   print, scan, angle, XX, YY, zdata[count-1]

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
       ; if within the grid, add a NON_COINCIDENT point to the data arrays
;       if (abs(XX2) le 150.) and (abs(YY2) le 150.) then begin
          xdata[count] = XX2
          ydata[count] = YY2
          zdata[count] = -77
          count = count + 1
;       endif
    endif

    if (angle eq 48) then begin
       ; Get the prior footprint's X and Y
       coordinate_b_to_a, siteLong[siteN], siteLat[siteN], lons[angle-1,scan], $
                       lats[angle-1,scan], XX2, YY2
       ; extrapolate X and Y to where (angle = 49) would be
       XX2 = XX + (XX - XX2)
       YY2 = YY + (YY - YY2)
       ; if within the grid, add a NON_COINCIDENT point to the data arrays
;       if (abs(XX2) le 150.) and (abs(YY2) le 150.) then begin
          xdata[count] = XX2
          ydata[count] = YY2
          zdata[count] = -77
          count = count + 1
;       endif
    endif
   
  endif  ;fine x,y filter

 ENDIF   ;coarse lat/lon filter

endfor
endfor

if (count eq 0L) then begin
  print, "WARNING:  No grids/metadata able to be computed for event!"
  missinghist = intarr(nummeta-1)
  missinghist[*] = -999
  for m=0, nummeta-2 do begin
     printf, UNLOUT, format = '(2(i0,"|"),i0)', $
           event_num[siteN], metaID[m], missinghist[m]
     printf, UNLOUT, format = '(2(i0,"|"),i0)', $
           event_num[siteN], metaID_100[m], missinghist[m]
  endfor
endif else begin

x = xdata[0:count-1] & y = ydata[0:count-1] & z = zdata[0:count-1]

TRIANGULATE, x, y, tr

IF keyword_set(rainType_hi) THEN BEGIN
    xpos=indgen(151)
    xpos = xpos * 2 - 150
    ypos=xpos
    rainType_map = GRIDDATA(x, y, z, /NEAREST_NEIGHBOR, TRIANGLES=tr, $
                            /GRID, XOUT=xpos, YOUT=ypos)
ENDIF

xpos4 = indgen(75)
xpos4 = xpos4 * 4 - 148
ypos4 = xpos4
rainType_new = GRIDDATA(x, y, z, /NEAREST_NEIGHBOR, TRIANGLES=tr, $
                        /GRID, XOUT=xpos4, YOUT=ypos4)

; changed following line in Sept. 2006 to handle -77/-88/-99 properly.  Prior
; to this all missing and no-rain values were set to no-rain by 'else' in loop
; below - Morris

; GRIDDATA output is FLOAT, cast to INT when rescaling
rainType = FIX(rainType_new/10.)  ; scale factor is changed from 10 to 100 for
                                  ; v6 - deal with 3-digit (100-313) rainType
                                  ; values in loop below

; changed these to WHERE from i,j loop and if's - Nov. '06
idx123 = WHERE( rainType gt 0, count123 )
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

; Generate RainType histogram for 4km grid and write to file
; Convert negative values to their ABS for histogramming

histo = HISTOGRAM( ABS(RAINTYPE), MIN=0, MAX=9 )
idxhist = [1,2,3,8,9,7]  ; must have exactly "nummeta" values
histout = histo[idxhist]
; set last array value to the total # of coincident gridpoints
; (i.e., exclude those with the NON_COINCIDENT value = -7)
histout[5] = TOTAL(histout[0:4], /INTEGER)

; skip # of Coincident Gridpoints (id=230999) in output, can derive from others
; or use 2A55 metadata parameter 250999
for m=0, nummeta-2 do begin
   printf, UNLOUT, format = '(2(i0,"|"),i0)', $
           event_num[siteN], metaID[m], histo[idxhist[m]]
endfor

; Repeat for points within 100km of radar
;idx100 = where( dist LE 100.0, count100 )
;if ( count100 GT 0 ) then begin
   histo100 = HISTOGRAM( ABS(RAINTYPE[idx100]), MIN=0, MAX=9 )
   for m=0, nummeta-2 do begin
      printf, UNLOUT, format = '(2(i0,"|"),i0)', $
           event_num[siteN], metaID_100[m], histo100[idxhist[m]]
   endfor
;endif else begin
;   print, "ERROR in extract2a23meta(): can't find points <= 100km in dist array provided."
;endelse

;==============================================================================

IF keyword_set(rainType_hi) THEN BEGIN

  rainType_hi = FIX(rainType_map/10.)
  
  for i=0,150 do begin 
   for j=0,150 do begin
     ;scale factor for actual types is changed from 10 to 100 for v6
     if ( rainType_hi[j,i] gt 0 ) then begin
        rainType_hi[j,i] = rainType_hi[j,i]/10
     endif

     if (rainType_hi[j,i] eq 1) or (rainType_hi[j,i] eq 2) $
         or (rainType_hi[j,i] eq 3) or (rainType_hi[j,i] eq -8) $
         or (rainType_hi[j,i] eq -9) then begin
     endif else begin
        rainType_hi[j,i]=-8
     endelse
   
   endfor
  endfor
  
ENDIF

endelse  ; (count gt 0)

endfor      ;(nsites loop)

errorExit:
print, ""
return, status

end

@read_2a23_ppi.pro
