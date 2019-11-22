;+
; AUTHOR:
;       Liang Liao
;       Caelum Research Corp.
;       Code 975, NASA/GSFC
;       Greenbelt, MD 20771
;       Phone: 301-614-5718
;       E-mail: lliao@priam.gsfc.nasa.gov
;+

pro access2A25grids, file=file_2a25, unlout=UNLOUT, Height=height, nAvgHeight=hh, $
                dbz2A25=dbz_new_2a25, Track=track_map_hi, SURF_RAIN=surfRain, $
                RAIN=rain_out_2a25, RANGE_BIN_BB=BB_Hgt, FLAG_RAIN=rainFlagMap

common sample, start_sample,sample_range,num_range,dbz_min
common time, TRMM_TIME, hh_gv, mm_gv, ss_gv, year, month, day, orbit
common sample_rain, RAIN_MIN, RAIN_MAX
common groundSite, event_num, siteID, siteLong, siteLat, nsites
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
dbz_2a25=fltarr(sample_range>1,1,num_range)
dbz_avg_2a25 = fltarr(75,75,5)

rain_2a25 = fltarr(sample_range>1,1,num_range)
rain_avg_2a25 = fltarr(75,75,5)

surfRain_2a25=fltarr(sample_range>1,49)

geolocation=fltarr(2,49,sample_range>1)

rangeBinNums=intarr(sample_range>1,49,7)

rainFlag=intarr(sample_range>1,49)


read_2a25_ppi, file_2a25, DBZ=dbz_2a25, RAIN=rain_2a25, $
               SURFACE_RAIN=surfRain_2a25, GEOL=geolocation, $
               RANGE_BIN=rangeBinNums, RN_FLAG=rainFlag


; In the array of 7 int values of rangeBinNum, bin number of the
; bright band is the fourth value (index = 3).  Cut it from the 3d array.
brightBand=rangeBinNums[*,*,3]

;3rd dimension '3' only valid if hh=1 ??  See following 'for' loop.  jeez..
;dbz_ppi_2a25 = fltarr(sample_range>1,49,3)  
;rain_ppi_2a25 = fltarr(sample_range>1,49,3)

lons = fltarr(49,sample_range>1)
lats = fltarr(49,sample_range>1)
lons[*,*] = geolocation[1,*,*]
lats[*,*] = geolocation[0,*,*]

; added second dimension to zdata_2a25 and zdata_2a25_rain to hold multiple
; heights to be analyzed and averaged (put loops over h only to where needed)
; Also added second pair of x-y arrays "_at_h" to hold parallax-adjusted x-y

xdata = fltarr(90000)
ydata = fltarr(90000)
xdata_at_h = fltarr(90000)
ydata_at_h = fltarr(90000)
zdata_2a25 = fltarr(90000, 2*hh+1)
zdata_track = fltarr(90000)
zdata_2a25_rain = fltarr(90000, 2*hh+1)
zdata_2a25_srain = fltarr(90000)

; Keep Bright Band points in separate variables, for Nearest-Neighbor analysis.
; We add MISSING border points at scan edges for this type of analysis, which
; extrapolates outside the input points, so we need to keep them separately.

xdataBB = fltarr(90000)
ydataBB = fltarr(90000)
zdata_BB_Hgt = fltarr(90000)
zdata_rainflag = intarr(90000)

; eliminate repetitive trig calculations by storing precomputed results
cos_inc_angle = fltarr(49)
tan_inc_angle = fltarr(49)
for angle=0,48 do begin 
  ;rays at approx. 0.71 deg. increments - removed abs(), no difference for cos()
  inc_angle = 0.71*3.1415926*(angle+1-25)/180. 
  cos_inc_angle[angle] = cos(inc_angle)  ;precomputed for gateN, below
  tan_inc_angle[angle] = tan(inc_angle)  ;precomputed for dR calculations below
endfor

FOR LEVEL = 1, 13 DO BEGIN
; Determine the slant-range bin numbers at each of the heights we are going
; to average in the vertical.  Store in a lookup array indexed to angle and h.
; For now, it only averages to one height level (2-D gridding, not 3-D
; gridding).
HEIGHT = 1.5 * LEVEL
print, "****************"
print, "HEIGHT = ", HEIGHT
print, "****************"

gateN = intarr(49, 2*hh+1)
for h = -hh, hh do begin
 delta_h = 0.25*h
 for angle=0,48 do begin 
  ip = 4*(HEIGHT+delta_h)/cos_inc_angle[angle] ;slant range (gates) @ 4 gate/km
  ip = fix(ip+0.5)  ;slant range to height+delta_h in whole gates, from surface
  ; gate 80 is surface gate for corrected dbz and rainrate, and gate# decreases
  ; with increasing height.  Compute product-relative gate # at our height:
  gateN[angle,h+hh] = 0 > (80 - ip)
 endfor
endfor

;******************************************************************************
; Here is where we now start looping over the list of sites overpassed in
; this orbit. Need to reinitialize variables first (as a good practice).
;******************************************************************************

FOR siteN = 0, nsites - 1 DO BEGIN

count = 0L
xdata[*]=0.0
ydata[*]=0.0
xdata_at_h[*]=0.0
ydata_at_h[*]=0.0
zdata_2a25[*,*]=0.0
zdata_track[*]=0.0
zdata_2a25_rain[*,*]=0.0
zdata_2a25_srain[*]=0.0

countBB = 0L
xdata[*]=0.0
ydata[*]=0.0
zdata_BB_Hgt[*]=0.0
zdata_rainflag[*]=0

; -- Find x,y, and element (i.e., z) data in our bounding box
;    within +/- 150km of ground radar.  Will be at random (x,y) points
;    relative to the GV radar grid of 2A55

do_print = 1                        ; init to TRUE
for scan=0,SAMPLE_RANGE-1 do begin
did_slope = 0                       ; init to FALSE
for angle = 0, 48 do begin
 ; coarse filter to PR beams within +/- 3 degrees of site lat/lon
 IF (ABS(lons[angle,scan]-siteLong[siteN]) lt 3.) and $
     (ABS(lats[angle,scan]-siteLat[siteN]) lt 3.) then begin

  ; compute X and Y offsets with height (once per scan when within range)
  if ( did_slope eq 0 ) then begin
    did_slope = 1
    ; get X and Y endpoints of scan
    coordinateBtoA, siteLong[siteN], siteLat[siteN], lons[0,scan], $
                    lats[0,scan], XX0, YY0
    coordinateBtoA, siteLong[siteN], siteLat[siteN], lons[48,scan], $
                    lats[48,scan], XX48, YY48
    ; Compute the slope of the scan line in y,x space to avoid divide by zero
    ; when XX0 eq XX48 (top or bottom of orbit).  Always have finite dY.
    ; Thus, dx = mscan * dy
    mscan = ( XX48 - XX0 )/( YY48 - YY0 )
    ; need to know whether we are scanning in the +y or -y direction:
    dysign = ( YY48 - YY0 )/ABS( YY48 - YY0 )  ; if +, y increasing along sweep
    if (do_print eq 1 ) then begin
      print, "XX0, XX48, YY0, YY48, m, dysign, angle = ", $
             XX0, XX48, YY0, YY48, mscan, dysign, angle
    endif
  endif
  
  ; compute dR = total offset towards nadir point, for given height and angle
  ;inc_angle = 0.71*3.1415926*(angle+1-25)/180. ;rays at 0.71 deg. increments
  dR = HEIGHT * tan_inc_angle[angle]
  sign_dRdH = 1  ; positive if dR is in along-sweep direction as h increases
  if ( angle gt 25 ) then sign_dRdH = -1
  ; Use dR^2 = dX^2 + dY^2, dX = mscan*dY, and solve for dY.  Account for signs.
  dY = SQRT( dR^2/(mscan^2 +1) ) * dysign * sign_dRdH
  dX = mscan * dY
  
  coordinateBtoA, siteLong[siteN], siteLat[siteN], lons[angle,scan], $
                  lats[angle,scan], XX, YY
  
  if (do_print eq 1 ) then begin
      do_print = 0
      print, "dR,sign_dR,dY,dX = ", dR,sign_dRdH,dY,dX
  endif

  ; fine filter, save only points falling within the 300x300km grid bounds
  if (abs(XX) le 150.) and (abs(YY) le 150.) then begin
    xdata_at_h[count] = XX + dX
    ydata_at_h[count] = YY + dY

;   Get data points of the elements to be vertically summed/averaged.
;   We're gonna vertically average dbz and rainrate over (2 * hh + 1) bins.
;   For Z and rain, grab a horizontal slab of beam data at constant altitude
;   by taking bin samples at the slant range (in gates) where the bin is at
;   HEIGHT+delta_h.  Height for each bin number is a function of ray angle --
;   use the gateN lookup array we precomputed, indexed to angle and h.
    for h = -hh, hh do begin
      zdata_2a25[count,hh+h] = dbz_2a25[scan,angle,gateN[angle,h+hh]]
    
      if rain_2a25[scan,angle,gateN[angle,h+hh]] gt rain_min then begin
         zdata_2a25_rain[count,hh+h] = rain_2a25[scan,angle,gateN[angle,h+hh]]
      endif else begin
         zdata_2a25_rain[count,hh+h] = -999.
      endelse
    endfor

    IF (LEVEL EQ 1) then begin
;     Get data points of the single-level elements

      xdata[count] = XX
      ydata[count] = YY
      zdata_track[count] = 1000.

      if surfRain_2a25[scan,angle] gt rain_min then begin
         zdata_2a25_srain[count] = surfRain_2a25[scan,angle]
      endif else begin
         zdata_2a25_srain[count] = -999.
      endelse

;     get the data points for nearest-neighbor interpolations
      xdataBB[countBB] = XX
      ydataBB[countBB] = YY
;     - convert range bin number to BBhgt, km (AGL? slant?)
      zdata_BB_Hgt[countBB] = $
         ( 79 - brightBand[scan,angle] ) * 0.25 * cos_inc_angle[angle]
      zdata_rainflag[countBB] = rainFlag[scan,angle]
      countBB = countBB + 1

;     Paint a band of MISSING bright band values off either edge of the scan to
;     force the nearest-neighbor interpolation to set the bright band values
;     to MISSING (-1) when extrapolating gridpoints outside PR scan limits
;     Using -1 for MISSING BB so that the BB histogram isn't too 'wide'.
;      Use NOT_USED (1024) for MISSING for rain flag.

      if (angle eq 0) then begin 
         ; Get the next footprint's X and Y
         coordinateBtoA, siteLong[siteN], siteLat[siteN], lons[angle+1,scan], $
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
         coordinateBtoA, siteLong[siteN], siteLat[siteN], lons[angle-1,scan], $
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
    
    ENDIF  ;LEVEL=1, prep for single-level elements just once
    
    count = count + 1

  endif  ; ABS( XX and YY ) <= 150 km
  
 ENDIF  ; ABS(lat, lon diffs) < 3 deg.

endfor  ; angles in scan
endfor  ; scans


IF (LEVEL EQ 1) then begin
; --- Process surface rain, other single-level elements of 2a25
;     Use non-parallax-adjusted X and Y beam locations
x = xdata[0:count-1] & y = ydata[0:count-1] 
TRIANGULATE, x, y, tr

z_2a25_srain = zdata_2a25_srain[0:count-1]
srain_map_2a25 = TRIGRID(x, y, z_2a25_srain, tr, [2,2], $
                         [-150.,-150.,150.,150.])
srain_new_2a25 = srain_map_2a25[0:149,0:149]
srain_new_2a25 = REBIN(srain_new_2a25,75,75)
  
z_2a25 = zdata_track[0:count-1]
track_map_hi = TRIGRID(x, y, z_2a25, tr, [2,2], [-150.,-150.,150.,150.])
track_map = track_map_hi[0:149,0:149]
track_map = REBIN(track_map,75,75)
  
; First do the Nearest-Neighbor interpolations in GRIDDATA()
; set x,y points for BB, rain flag nearest-neighbor interpolations
x2 = xdataBB[0:countBB-1] & y2 = ydataBB[0:countBB-1] 
TRIANGULATE, x2, y2, tr2

; generate the grid x,y locations, in km, GRIDDATA() needs for output grid
xpos4 = indgen(75)
xpos4 = xpos4 * 4 - 148
ypos4 = xpos4

; set the z data and do the nearest-neighbor analyses
z_BB_Hgt = zdata_BB_Hgt[0:countBB-1]
BB_Hgt = GRIDDATA(x2, y2, z_BB_Hgt, /NEAREST_NEIGHBOR, TRIANGLES=tr2, $
                  /GRID, XOUT=xpos4, YOUT=ypos4)

z_rainflag = zdata_rainflag[0:countBB-1]
rainFlagMapF = GRIDDATA(x2, y2, z_rainflag, /NEAREST_NEIGHBOR, $
                          TRIANGLES=tr2, /GRID, XOUT=xpos4, YOUT=ypos4)

; GRIDDATA does interp in double precision, returns float; we need back in INT
rainFlagMap = FIX(rainFlagMapF)

; Generate BB Height histogram for 4km grid and write to file

histo = HISTOGRAM( BB_Hgt, LOCATIONS=idxhist )
;print, siteID[siteN], " Bright Band Histogram:"
;print, histo
;print, "Histogram height bin values:"
;print, idxhist
;print, ""

idxeq0=where(idxhist eq 0.0, count0)
idxgt0=where(idxhist gt 0.0, countgt0)

if (count0 gt 0) then begin
  nbb0 = histo[idxeq0]
endif else begin
  nbb0 = 0
endelse
;print, "Num pts no BB Height: ", nbb0

if (countgt0 gt 0) then begin
  nbbgt0 = total(histo[idxgt0])
;  bbAvg = total(histo[idxgt0]*idxhist[idxgt0])/nbbgt0
  idxBBgt0 = WHERE(BB_Hgt gt 0.0)
  bbAvg = MEAN(BB_Hgt[idxBBgt0])
endif else begin
  nbbgt0 = 0
  bbAvg = -999.
endelse
;print, "Avg. BB Height, where given: ", bbAvg
;print, "Num. BB Heights given: ", nbbgt0

pctBB = -999.
if ( (nbb0 + nbbgt0) gt 0 ) then pctBB = float(nbbgt0)/( nbb0 + nbbgt0 )
;print, "Percent coincident area with bright band height given: ", pctBB

; pull metrics out of the RainFlag elements
idxRain = WHERE((rainFlagMap AND RAIN_CERTAIN) NE 0, numRainPts)
;print, "Num Gridpoints with Rain Certain flag: ", numRainPts
idxBBExists = WHERE((rainFlagMap AND BB_EXISTS) NE 0, numBBXPts)
;print, "Num Gridpoints with BB Exists flag: ", numBBXPts
if (numBBXPts gt 0) then begin
  bbExistsAvg = MEAN(BB_Hgt[idxBBExists])
endif else begin
  bbExistsAvg = -999.
endelse
;print, "Avg. BB Height, where BB Exists Flag set: ", bbExistsAvg
;print, "============================================================"

;2A25_AvgBBHgtAny = 251001L
;2A25_NumBBHgtAny = 251002L
;2A25_AvgBBHgtExists = 251003L
;2A25_NumBBHgtExists = 251004L
;2A25_NumRainCertain = 251005L
;2A25_NumPROverlapGrdpts = 250999L

; ABOVE IDENTIFIERS ARE DEFINED IN THE GPMGV DATABASE AS KEY VALUES --
; - CAN'T CHANGE OR REDEFINE THEM HERE WITHOUT MATCHING DATABASE MODS.

nummeta = 6
metavalue = fltarr(nummeta)
metavalue[0] = bbAvg
metavalue[1] = nbbgt0
metavalue[2] = bbExistsAvg
metavalue[3] = numBBXPts
metavalue[4] = numRainPts
metavalue[5] = (nbbgt0 + nbb0)
metaID = [251001L, 251002L, 251003L, 251004L, 251005L, 250999L]

for m=0, nummeta-1 do begin
   printf, UNLOUT, format = '(2(i0,"|"),f0.5)', $
           event_num[siteN], metaID[m], metavalue[m]
;   print, format = '(2(i0,"|"),f0.5)', $
;           event_num[siteN], metaID[m], metavalue[m]
endfor

ENDIF  ;LEVEL=1, grid & extract for single-level elements just once

; Next do the TRIGRID() interpolative analyses of Z, Rain, Srain, Track
x = xdata_at_h[0:count-1] & y = ydata_at_h[0:count-1] 
TRIANGULATE, x, y, tr

; Do the analyses at multiple heights for those fields to be averaged
for h = -hh, hh do begin
; -- Now analyze each field to a regular grid centered on ground radar
  z_2a25 = zdata_2a25[0:count-1, hh+h]
  z_2a25_rain = zdata_2a25_rain[0:count-1, hh+h]

  dbz_map_2a25 = TRIGRID(x, y, z_2a25, tr, [2,2], [-150.,-150.,150.,150.])
  dbz_map_2a25 = dbz_map_2a25/100.   ;devide by 10 for ver.4 and 100 for ver.5
  dbz_new_2a25 = dbz_map_2a25[0:149,0:149]
  dbz_new_2a25 = 10.^(0.1*dbz_new_2a25)
  dbz_new_2a25 = REBIN(dbz_new_2a25,75,75)

  rain_map_2a25 = TRIGRID(x, y, z_2a25_rain, tr, [2,2], [-150.,-150.,150.,150.])
  rain_map_2a25 = rain_map_2a25/100.   ;divide by 10 for ver.4 and 100 for ver.5
  rain_new_2a25 = rain_map_2a25[0:149,0:149]
  rain_new_2a25 = REBIN(rain_new_2a25,75,75)
  ; -- Save the analyzed constant altitude data for averaging later
  dbz_avg_2a25[*,*,hh+h] = dbz_new_2a25[*,*]
  rain_avg_2a25[*,*,hh+h] = rain_new_2a25[*,*]
endfor  ;loop for h

; 
; --- Replace dbz_map with values averaged over several heights
;
h_rec_2a25=intarr(5)  &  h_rec_2a25[*]=0

for ix = 0, 74 do begin
for iy = 0, 74 do begin
  
  sum_2a25 = 0.
  nh_2a25  = 0
  
  sum_rain_2a25 = 0.
  nh_rain_2a25  = 0
  
  for h=0,2*hh do begin
    if dbz_avg_2a25[ix,iy,h] ge dbz_min then begin
      h_rec_2a25[h]=1   ;Record h that is used for average
      nh_2a25=nh_2a25+1
      sum_2a25 = dbz_avg_2a25[ix,iy,h]+sum_2a25
    endif
    
    if rain_avg_2a25[ix,iy,h] ge rain_min then begin
      h_rec_2a25[h]=1   ;Record h that is used for average
      nh_rain_2a25=nh_rain_2a25+1
      sum_rain_2a25 = rain_avg_2a25[ix,iy,h]+sum_rain_2a25
    endif
  endfor
  
  if nh_2a25 eq 0 then begin
    dbz_new_2a25[ix,iy]=10.*ALOG10(dbz_avg_2a25[ix,iy,2])
  endif else begin
    dbz_new_2a25[ix,iy] = 10.*ALOG10(sum_2a25/nh_2a25)
  endelse
  
  if nh_rain_2a25 eq 0 then begin
    rain_new_2a25[ix,iy]=rain_avg_2a25[ix,iy,2]
  endif else begin
    rain_new_2a25[ix,iy] = sum_rain_2a25/nh_rain_2a25
  endelse
  
  if (dbz_new_2a25[ix,iy] lt 15.) then dbz_new_2a25[ix,iy] = -9999.

; -- Adhere flight track info to the data (whatever that means! - BM)

  if (dbz_new_2a25[ix,iy] lt 15.) and (track_map[ix,iy] ge 70.) then $
     dbz_new_2a25[ix,iy] = -100.

endfor
endfor

rain_out_2a25 = rain_new_2a25
surfRain = srain_new_2a25

ENDFOR      ;(nsites loop)
ENDFOR     ;( LEVELs loop)
end

@read_2a25_ppi.pro
