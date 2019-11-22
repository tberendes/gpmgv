;+
; AUTHOR:
;       Liang Liao
;       Caelum Research Corp.
;       Code 975, NASA/GSFC
;       Greenbelt, MD 20771
;       Phone: 301-614-5718
;       E-mail: lliao@priam.gsfc.nasa.gov
;
; HISTORY:
;       12/2006 by Bob Morris, GPM GV (SAIC)
;       - Heavily modified/renamed from Liang's access1C21_2A25.pro.  Do all 13
;         height levels and write results to netCDF file.  Incorporate parallax
;         corrections for PR ray data at heights.  Do nearest-neighbor gridding
;         for categorical/discrete-valued data elements.  Improve performance
;         by precalculating trig values where possible, and prescreening rays
;         by gross lat/lon thresholds.  Eliminated hard-coded site information.
;         Do the reading of the HDF files in the calling routine and pass
;         required data fields via arguments, as this routine is now normally
;         invoked repeatedly in a loop over multiple sites.  Added documentation
;         of the tricky handling of gates/bins in the 1C21 and 2A25 products as
;         originally figured out by Liang.
;
;       08/2007 by Bob Morris, GPM GV (SAIC)
;       - Renamed to generate_pr_ncgrids from generate_1c21_2a25_ncgrids.  Added
;         2B-31 Combined Rain Rate to the analysis, and changed analysis of
;         2A-25 near-surface rain rate to nearest-neighbor.
;
;       11/2007 by Bob Morris, GPM GV (SAIC)
;       - Added PR ray index as a netCDF output grid variable, analyzed in the
;         nearest-neighbor method.  Rearranged some sections to put common
;         actions together, and edited some comments.
;
;       07/2008 by Bob Morris, GPM GV (SAIC)
;       - Changed analysis of 3-D rain rate to nearest-neighbor.  Set off-swath
;         data values to SRAIN_OFF_EDGE.  Solves problem with ground clutter
;         (-88.88) values getting 'smeared' by interpolative analysis.
;+

pro generate_pr_ncgrids, nAvgHeight=hh, ncfile, lons, lats,  $
                         dbz_2a25, rain_2a25, surfRain_2a25, $
                         COMBO_RAIN = surfRain_2b31, $
                         rangeBinNums, rainFlag, rainType, $
                         dbz_1c21, landOceanFlag, binS, rayStart

common sample,       start_sample,sample_range,num_range,dbz_min
common time,         event_time, volscantime, orbit
common sample_rain,  RAIN_MIN, RAIN_MAX
common groundSite,   event_num, siteID, siteLong, siteLat, nsites
common trig_precalc, cos_inc_angle, tan_inc_angle

; 'Include' file for grid dimensions, spacings
@grid_def.inc

; "Include" file for PR-product-specific values, parameters
@pr_params.inc


; The following test allows PR grid generation to proceed without the
; 2B-31 data file being available.  This is for the interim where the
; 2B-31's are not yet filled in back to the start of GPMGV TSDIS data.

do_2b31 = 1
if N_Elements(surfRain_2b31) eq 0 then do_2b31 = 0


; Compute necessary derived grid/PR parameters

dxdy2A55_km = FIX(DX_DY_2A55 / 1000.)   ; 2A55 grid spacing in km
dxdy_km = FIX(DX_DY / 1000.)            ; netCDF grid spacing in km
max_x = dxdy_km * NX / 2.          ; grid outer boundary in +x direction, km
max_y = dxdy_km * NY / 2.          ; grid outer boundary in +y direction, km
grid_max_x = max_x - dxdy_km/2.    ; x-coord (km) of gridpoint center at NX
dz_km = DZ / 1000.
gates_per_km = 1000. / GATE_SPACE
max_deg_lat = 2 * max_x / 111.1    ; coarse filter PR-site latitude difference
max_deg_lon = 2 * max_y * cos(3.1415926D*(siteLat)/180.) / 111.1  ; ditto, lon

print, 'Lat/lon coarse thresholds, degrees: ', max_deg_lat, max_deg_lon

; Since we still analyze dBZ and rainrate to the 2A55 resolution/size grid, we
; need the following to prepare analyzed output for REBINing to NX x NY grid.
; REBIN requires a grid whose dimensions are even multiples of NX and NY.

x_cut = (NX * REDUCFAC) - 1  ; upper x array index to extract from hi-res grid
                             ; prior to REBINning to NX x NY grid
y_cut = (NY * REDUCFAC) - 1  ; as for x_cut, but upper y array index


; Open the netcdf file for writing, and fill passed/common parameters

ncid = NCDF_OPEN( ncfile, /WRITE )
NCDF_VARPUT, ncid, 'site_ID', siteID
NCDF_VARPUT, ncid, 'site_lat', siteLat
NCDF_VARPUT, ncid, 'site_lon', siteLong
NCDF_VARPUT, ncid, 'timeNearestApproach', event_time

; Convert the overpass time in unix ticks (event_time) to a datetime string
; via intermediate conversion to date/time components, and write to netCDF

unix2datetime, event_time, etyear, etmonth, etday, ethour, etminute, etsecond

;print, etyear, etmonth, etday, ethour, etminute, etsecond, FORMAT = $
; '("Event time by components: ", i0,"-",i02,"-",i02," ",i02,":",i02,":",i02)'

event_time_string = fmtdatetime(etyear, etmonth, etday, $
                                ethour, etminute, etsecond)
;print, "Event time string: ", event_time_string
NCDF_VARPUT, ncid, 'atimeNearestApproach', event_time_string


; In the array of 7 int values of rangeBinNum, bin number of the
; bright band is the fourth value (index = 3).  Cut it from the 3d array.

brightBand=rangeBinNums[*,*,3]


; Create the output 3-D grid arrays.  The 2-D grid arrays are created later as
; part of the analyses.

dbzraw_to_nc = fltarr(NX,NY,NZ)
dbzcor_to_nc = fltarr(NX,NY,NZ)
rain_to_nc = fltarr(NX,NY,NZ)


; Prepare the x,y,z arrays to hold the PR data to be analyzed:
; We need to determine an upper limit to how many PR footprints fall inside
; the grid analysis area, so that we can hold x, y, and various z values for
; each element to analyze.  We gave the PR a 4km resolution in the include
; file pr_params.inc, and use this nominal resolution to figure out how many
; of these are required to cover the grid area.

grid_area_km = 2*max_x * 2*max_y
max_pr_fp = grid_area_km / NOM_PR_RES_KM
;print, 'Computed max num PR footprints in grid = ', max_pr_fp

; First, x-y-z variables for bilinear interpolative analysis elements:

; Define the x-y arrays for 2-D, surface-level analyses
xdata = fltarr(max_pr_fp)
ydata = fltarr(max_pr_fp)
; A second pair of x-y arrays "_at_h" holds parallax-adjusted x-y
xdata_at_h = fltarr(max_pr_fp)
ydata_at_h = fltarr(max_pr_fp)
; A third pair of x-y arrays "_at_h" holds parallax-adjusted x-y for rain rate,
; plus swath-edge delimiter value for nearest neighbor analysis.  Added 07/2008
xdatarain_at_h = fltarr(max_pr_fp)
ydatarain_at_h = fltarr(max_pr_fp)

; Hold Bright Band, Rain Flag, Rain Type, RayIndex points in separate variables,
; for Nearest-Neighbor analysis. We add MISSING border points at scan edges
; for this type of analysis (which extrapolates outside the input points),
; so we need to keep these x-y lists separately.

; x,y locations for BB, offset for viewing parallax
xdataBB = fltarr(max_pr_fp) 
ydataBB = fltarr(max_pr_fp)

; x,y locations for Rain Flag/Type and RayIndex, no parallax offset
xdataRF = fltarr(max_pr_fp)
ydataRF = fltarr(max_pr_fp)

zdata_1c21 = fltarr(max_pr_fp)       ; from dbz_1c21
zdata_2a25 = fltarr(max_pr_fp)       ; from dbz_2a25
zdata_track = fltarr(max_pr_fp)
zdata_2a25_rain = fltarr(max_pr_fp)
zdata_2a25_srain = fltarr(max_pr_fp)
zdata_2b31_srain = fltarr(max_pr_fp)
zdata_BB_Hgt = fltarr(max_pr_fp)
zdata_rainflag = intarr(max_pr_fp)
zdata_raintype = intarr(max_pr_fp)
zdata_landocean = intarr(max_pr_fp)
zdata_rayindex = intarr(max_pr_fp)


; ****************  Proceed to the grid analyses ******************

FOR  LEVEL = 1, NZ  DO BEGIN
HEIGHT = ZLEVELS[LEVEL-1] / 1000.  ; convert ZLEVELS from m to km
;print, "****************"
;print, "HEIGHT = ", HEIGHT
;print, "****************"


; Determine the slant-range gate numbers at each of the ray heights we are going
; to average in the vertical for this grid HEIGHT level.  Store in a lookup
; array indexed to angle and h.  These values are relative to the surface gate
; number, which (for 1C-21, at least) must be computed for each ray.

ip = intarr(RAYSPERSCAN, 2*hh+1)
for h = -hh, hh do begin
 delta_h = h/gates_per_km
 for angle=0,RAYSPERSCAN-1  do begin
;  slant range to HEIGHT+delta_h, in gates, @ 4 gate/km:
   rip = gates_per_km*(HEIGHT+delta_h)/cos_inc_angle[angle] 
;  slant range to height+delta_h in whole gates, from surface:
   ip[angle,h+hh] = fix(rip+0.5)  
 endfor
endfor


; Initialize our x, y, and z PR sample arrays and counts for analysis input
count = 0L
xdata[*]=0.0
ydata[*]=0.0
xdata_at_h[*]=0.0
ydata_at_h[*]=0.0
zdata_1c21[*]=0.0
zdata_2a25[*]=0.0
zdata_track[*]=0.0
zdata_2a25_srain[*]=0.0
zdata_2b31_srain[*]=0.0

countRR = 0L
xdatarain_at_h[*]=0.0
ydatarain_at_h[*]=0.0
zdata_2a25_rain[*]=0.0

countBB = 0L
xdataBB[*]=0.0
ydataBB[*]=0.0
xdataRF[*]=0.0
ydataRF[*]=0.0
zdata_BB_Hgt[*]=0.0
zdata_rainflag[*]=0
zdata_raintype[*]=0
zdata_landocean[*]=0
zdata_rayindex[*]=0

; -- Find x,y, and element (i.e., z) data in our grid bounding box, i.e.,
;    within +/- 150km of ground radar.  Will be at random (x,y) points
;    relative to the fixed-location GV radar grid of the 2A-55 product.

do_print = 0                        ; init to False, 1 if print wanted
for scan=0,SAMPLE_RANGE-1 do begin

did_slope = 0                       ; init to FALSE
for angle = 0,RAYSPERSCAN-1  do begin

 ; coarse filter to PR beams within our calculated thresholds (deg.) lat/lon
 IF (ABS(lons[angle,scan]-siteLong) lt max_deg_lon) and $
     (ABS(lats[angle,scan]-siteLat) lt max_deg_lat) then begin

  coordinate_b_to_a, siteLong, siteLat, lons[angle,scan], $
                  lats[angle,scan], XX, YY
  
; Fine filter, save only points falling within the grid bounds
  if (abs(XX) le max_x) and (abs(YY) le max_y) then begin
;
;   Compute dX and dY offsets with height (once per scan when within range) to
;   correct ground-relative X and Y for parallax
;
    if ( did_slope eq 0 ) then begin
      did_slope = 1
;     Get X and Y at each endpoint of scan
      coordinate_b_to_a, siteLong, siteLat, lons[0,scan], $
                      lats[0,scan], XX0, YY0
      coordinate_b_to_a, siteLong, siteLat, lons[RAYSPERSCAN-1,scan], $
                      lats[RAYSPERSCAN-1,scan], XXEND, YYEND
;     Compute the slope of the scan line in y,x space to avoid divide by zero
;     when XX0 eq XXEND (top or bottom of orbit).  Always have finite dY.
;     Thus, dx = mscan * dy
      mscan = ( XXEND - XX0 )/( YYEND - YY0 )
;     Need to know whether we are scanning in the +y or -y direction:
      dysign = ( YYEND - YY0 )/ABS( YYEND - YY0 ) ;+ if y increasing along sweep
      if (do_print eq 1 ) then begin
        print, "XX0, XX48, YY0, YY48, m, dysign, angle = ", $
               XX0, XXEND, YY0, YYEND, mscan, dysign, angle
      endif
    endif

;   Compute dR = total offset towards nadir point, for given height and angle
    dR = HEIGHT * tan_inc_angle[angle]
    sign_dRdH = 1  ; positive if dR is in along-sweep direction as h increases
    if ( angle gt 25 ) then sign_dRdH = -1   ; PARAMETERIZE 25 VALUE
;   Use dR^2 = dX^2 + dY^2, dX = mscan*dY; solve for dY.  Account for signs.

    dY = SQRT( dR^2/(mscan^2 +1) ) * dysign * sign_dRdH
    dX = mscan * dY

    if (do_print eq 1 ) then begin
        do_print = 0
        print, "dR,sign_dR,dY,dX = ", dR,sign_dRdH,dY,dX
    endif

;   Apply dX and dY offsets to x's and y's input to analyses at height = HEIGHT
    xdata_at_h[count] = XX + dX
    ydata_at_h[count] = YY + dY
    xdatarain_at_h[countRR] = XX + dX
    ydatarain_at_h[countRR] = YY + dY

;   Add edge-of-swath delimiter points for nearest-neighbor if on edge
    if (angle eq 0) then begin 
       ; Get the next footprint's X and Y
       coordinate_b_to_a, siteLong, siteLat, lons[angle+1,scan], $
                       lats[angle+1,scan], XX2, YY2
       ; extrapolate X and Y to where (angle = -1) would be
       XX2 = XX - (XX2 - XX)
       YY2 = YY - (YY2 - YY)
       ; if within the grid, add a MISSING point to the x-y-z data arrays
       if (abs(XX2) le max_x) and (abs(YY2) le max_y) then begin
          xdatarain_at_h[countRR] = XX2
          ydatarain_at_h[countRR] = YY2
          zdata_2a25_rain[countRR] = SRAIN_OFF_EDGE
          countRR = countRR + 1
       endif
    endif
    if (angle eq RAYSPERSCAN-1) then begin
       ; Get the prior footprint's X and Y
       coordinate_b_to_a, siteLong, siteLat, lons[angle-1,scan], $
                       lats[angle-1,scan], XX2, YY2
       ; extrapolate X and Y to where (angle = RAYSPERSCAN) would be
       XX2 = XX + (XX - XX2)
       YY2 = YY + (YY - YY2)
       ; if within the grid, add a MISSING point to the x-y-z data arrays
       if (abs(XX2) le max_x) and (abs(YY2) le max_y) then begin
          xdatarain_at_h[countRR] = XX2
          ydatarain_at_h[countRR] = YY2
          zdata_2a25_rain[countRR] = SRAIN_OFF_EDGE
          countRR = countRR + 1
       endif
    endif


;   Get data points of the elements to be vertically summed/averaged.
;   We're gonna vertically average dbz and rainrate over (2 * hh + 1) gates.
;   For Z and rain, grab a horizontal slab of beam data at constant altitude
;   by taking samples at the slant range (in gates) where the gate is at
;   HEIGHT+delta_h.  Height for each gate number is a function of ray angle.  We
;   use the surface-relative IP lookup array we precomputed, indexed to angle
;   and h.

;------------------------------------------------------------------------------
; rayStart description, for 1C-21 data:
; Location, in 1/8km bins, of start of data (1/4km Gate 1 location at TOA) for 
; a given angle index (0-48).  Bin1 is always defined to be at a fixed distance
; from satellite.  Needed to relate binS (bin # of surface ellipsoid) to
; distance-from-surface-in-gates of a dBZ sample at a given height.
; That is, Bin 1 is at a fixed distance from the satellite; Gate 1 is at an
; approximately fixed altitude (23km) above earth; Gate1 and Bin1 line up at
; nadir scan, and for other scan angles, Gate1 moves down along the beam in a
; fixed manner to the Bin position defined by rayStart.  The bin number where
; the ray intersects the earth's surface (binS, Bin Ellipsoid in 1C-21) varies
; for each ray.  Thus, for a ray at product location [scan, angle], the gate
; number at the surface, gateS, is given by the relation:
;
;     gateS[scan, angle] = 1 + ( binS[scan, angle] - rayStart[angle] ) / 2
;
; For 2A-25, the surface gate #, gateN, is fixed at gate 80.
;------------------------------------------------------------------------------

         sum_1c21 = 0.
          nh_1c21 = 0
         sum_2a25 = 0.
          nh_2a25 = 0
    sum_rain_2a25 = 0.
     nh_rain_2a25 = 0

    for h = -hh, hh do begin

;     2A25 gate #80 is surface gate for corrected dbz and rainrate, and gate#
;     decreases with increasing height.  Compute product-relative gate # at
;     our height, guarding against negative gate index numbers:
      gateN = 0 > (80 - ip[angle,h+hh])

;     1C21 gate number at surface is dependent on ray-specific bin ellipsoid
;     value, binS[].  Compute product-relative gate # (gateS) at our
;     height for 1C21, guarding against negative gate index numbers:
      gateS = 0 > ( (binS[scan,angle]-rayStart[angle])/2 + 1 - ip[angle,h+hh] )

      dbz = dbz_2a25[scan,angle,gateN]/DBZSCALE2A25     ;unscale 2A25 dBZ
      rawdbz = dbz_1c21[scan,angle,gateS]/DBZSCALE1C21  ;unscale 1C21 dBZ

      if dbz ge dbz_min then begin
        nh_2a25 = nh_2a25+1
        sum_2a25 = 10.^(0.1*dbz)+sum_2a25  ;convert to Z and sum
        nh_1c21 = nh_1c21+1
        sum_1c21 = 10.^(0.1*rawdbz)+sum_1c21  ;convert to Z and sum
      endif
    
      rain = rain_2a25[scan,angle,gateN]/RAINSCALE2A25  ;unscale 2A25 rate
      if rain ge rain_min then begin
        nh_rain_2a25 = nh_rain_2a25+1
        sum_rain_2a25 = rain+sum_rain_2a25
      endif
    endfor

;   Compute the layer average Z's and RainRate.  Shouldn't we really require
;   there to be (2*hh+1) "good" values in the layer to average?  Otherwise, we
;   could be high-biasing the averages since we ignore below-threshold values
;   in the layer.  Something to think about later...
;
    if nh_1c21 eq 0 then begin
;     No values in layer met criteria, grab the middle one to represent
;     the layer average value and deal with it after analysis.
      gateS = 0 > ((binS[scan,angle]-rayStart[angle])/2 + 1 - ip[angle,hh])
      zdata_1c21[count] = 10.^(0.1*(dbz_1c21[scan,angle,gateS]/DBZSCALE1C21))
    endif else begin
      zdata_1c21[count] = sum_1c21/nh_1c21
    endelse

    if nh_2a25 eq 0 then begin
;     No values in layer met criteria, grab the middle one to represent
;     the layer average value and deal with it after analysis.
      gateN = 0 > (80 - ip[angle,hh])
      zdata_2a25[count] = 10.^(0.1*(dbz_2a25[scan,angle,gateN]/DBZSCALE2A25))
    endif else begin
      zdata_2a25[count] = sum_2a25/nh_2a25
    endelse

    if nh_rain_2a25 eq 0 then begin
;     No values in layer met criteria, grab the middle one to represent
;     the layer average value and deal with it after analysis.
      gateN = 0 > (80 - ip[angle,hh])
      zdata_2a25_rain[countRR] = rain_2a25[scan,angle,gateN]/RAINSCALE2A25
    endif else begin
      zdata_2a25_rain[countRR] = sum_rain_2a25/nh_rain_2a25
    endelse

    IF (LEVEL EQ 1) then begin
;     Set x-y-z data points of the single-level elements just once within the
;     levels loop.

;     Data points for the TRIGRID bilinear interpolation:
      xdata[count] = XX
      ydata[count] = YY
      zdata_track[count] = 1000.    ; INCLUDE?

;     x-y points for nearest-neighbor interpolations: rain[flag/type/rate],
;     land/ocean flag, ray index.  Need to use separate x and y point lists
;     to accommodate the "MISSING" points to be painted on the scan borders:

      xdataRF[countBB] = XX
      ydataRF[countBB] = YY

;     x-y points for BB nearest-neighbor interpolation -- adjust X and Y for
;     parallax according to BB height, if it exists (bin le 79), and store in
;     yet another pair of x and y point locations (xdataBB and ydataBB)

      if ( zdata_BB_Hgt[countBB] lt 79 ) then begin
;       - convert range bin number to BBhgt, meters (AGL? slant?)
        zdata_BB_Hgt[countBB] = $
           (79 - brightBand[scan,angle]) * GATE_SPACE * cos_inc_angle[angle]
        dRbb = zdata_BB_Hgt[countBB] * tan_inc_angle[angle]
        dYbb = SQRT( dR^2/(mscan^2 +1) ) * dysign * sign_dRdH
        dXbb = mscan * dY
        xdataBB[countBB] = XX + dXbb
        ydataBB[countBB] = YY + dYbb
      endif else begin
        xdataBB[countBB] = XX
        ydataBB[countBB] = YY
        zdata_BB_Hgt[countBB] = BBHGT_UNDEFINED
      endelse

;     set the element data values (zdata) themselves:

      zdata_rainflag[countBB] = rainFlag[scan,angle]
      zdata_raintype[countBB] = rainType[scan,angle]
      zdata_landocean[countBB] = landOceanFlag[scan,angle]
      zdata_rayindex[countBB] = angle

;     zdata points for nearest neighbor interpolation of surface rain rates
;     -- values must meet threshold criteria.

      if surfRain_2a25[scan,angle] gt rain_min then begin
         zdata_2a25_srain[countBB] = surfRain_2a25[scan,angle]
      endif else begin
         zdata_2a25_srain[countBB] = SRAIN_BELOW_THRESH
      endelse

      IF do_2b31 then begin
        if surfRain_2b31[scan,angle] gt rain_min then begin
            zdata_2b31_srain[countBB] = surfRain_2b31[scan,angle]
         endif else begin
         zdata_2b31_srain[countBB] = SRAIN_BELOW_THRESH
        endelse
      ENDIF

      countBB = countBB + 1
 
;     If we are at either end of the scan, then add the x-y-z values needed to
;     paint bands of MISSING data values adjacent to each edge of the scan.
;     This forces the nearest-neighbor interpolation to set the element values
;     to MISSING when extrapolating gridpoints outside PR scan limits.  Ignore
;     parallax in these location assignments.
;     - Paint -1 for MISSING BB so that the BB histogram isn't too 'wide'.
;     - Paint NOT_USED (1024) to represent MISSING for rain flag; -77 for Rain
;       Type; -999. for near-surface rain rates; and -1 for Land/Ocean Flag and
;       Ray Index.

      if (angle eq 0) then begin 
         ; if within the grid, add a MISSING point to the x-y-z data arrays
         if (abs(XX2) le max_x) and (abs(YY2) le max_y) then begin
            xdataBB[countBB] = XX2
            ydataBB[countBB] = YY2
            xdataRF[countBB] = XX2
            ydataRF[countBB] = YY2
            zdata_BB_Hgt[countBB] = BB_MISSING
            zdata_rainflag[countBB] = NOT_USED
            zdata_raintype[countBB] = RAINTYPE_OFF_EDGE
            zdata_landocean[countBB] = LANDOCEAN_MISSING
            zdata_2a25_srain[countBB] = SRAIN_OFF_EDGE
            zdata_2b31_srain[countBB] = SRAIN_OFF_EDGE
            zdata_rayindex[countBB] = BB_MISSING
            countBB = countBB + 1
         endif
      endif

      if (angle eq RAYSPERSCAN-1) then begin
         ; if within the grid, add a MISSING point to the x-y-z data arrays
         if (abs(XX2) le max_x) and (abs(YY2) le max_y) then begin
            xdataBB[countBB] = XX2
            ydataBB[countBB] = YY2
            xdataRF[countBB] = XX2
            ydataRF[countBB] = YY2
            zdata_BB_Hgt[countBB] = BB_MISSING
            zdata_rainflag[countBB] = NOT_USED
            zdata_raintype[countBB] = RAINTYPE_OFF_EDGE
            zdata_landocean[countBB] = LANDOCEAN_MISSING
            zdata_2a25_srain[countBB] = SRAIN_OFF_EDGE
            zdata_2b31_srain[countBB] = SRAIN_OFF_EDGE
            zdata_rayindex[countBB] = BB_MISSING
            countBB = countBB + 1
         endif
      endif
    
    ENDIF  ; LEVEL=1, prep for single-level elements just once
    count = count + 1
    countRR = countRR + 1
  endif    ; within grid, ABS( XX and YY ) <= max_[x and y]
 ENDIF     ; rough proximity check, ABS(lat, lon diffs) < 3 deg.

endfor     ; angles in scan
endfor     ; scans in PR product


; -- Now analyze each field to a regular grid centered on ground radar

IF (LEVEL EQ 1) then begin

;  -- Process 2-D grids for surface rain, other single-level elements

;  First do those elements which use non-parallax-adjusted X and Y beam
;  locations, and bilinear interpolation.  Only the bogus "track map"
;  meets these criteria now that rain rates are done using nearest-neighbor.

   x = xdata[0:count-1] & y = ydata[0:count-1] 
   TRIANGULATE, x, y, tr
   z_2a25 = zdata_track[0:count-1]
;  analyze to 2A-55 grid definition
   track_map_hi = TRIGRID(x, y, z_2a25, tr, [dxdy2A55_km,dxdy2A55_km], $
                       [-max_x,-max_y,max_x,max_y])
;  resample to defined output grid
   track_map = track_map_hi[0:x_cut, 0:y_cut]
   track_map = REBIN(track_map,NX,NY)
  
;  Do the Nearest-Neighbor interpolations in GRIDDATA().

;  set x,y points for BB, rain flag nearest-neighbor interpolations:

;  - set parallax-adjusted x-y for BB:
   x2 = xdataBB[0:countBB-1] & y2 = ydataBB[0:countBB-1] 
   TRIANGULATE, x2, y2, tr2

;  - set surface x-y for RainFlag, Near-Sfc RainRates, Ray Index:
   x3 = xdataRF[0:countBB-1] & y3 = ydataRF[0:countBB-1] 
   TRIANGULATE, x3, y3, tr3

;  Generate the output grid's x,y locations, in km from ground radar, as
;  GRIDDATA() needs, and as in the coordinates of the PR samples to be analyzed.
;  -- analyze directly to output NX x NY grid of dxdy_km resolution.
   xpos4 = indgen(NX)
   xpos4 = FIX(xpos4 * dxdy_km - grid_max_x)   ; FIX these?
   ypos4 = xpos4

;  set the z data values for each element, and call GRIDDATA to analyze

   z_BB_Hgt = zdata_BB_Hgt[0:countBB-1]
   BB_HgtF = GRIDDATA(x2, y2, z_BB_Hgt, /NEAREST_NEIGHBOR, TRIANGLES=tr2, $
                     /GRID, XOUT=xpos4, YOUT=ypos4)

   z_rainflag = zdata_rainflag[0:countBB-1]
   rainFlagMapF = GRIDDATA(x3, y3, z_rainflag, /NEAREST_NEIGHBOR, $
                           TRIANGLES=tr3, /GRID, XOUT=xpos4, YOUT=ypos4)

   z_raintype = zdata_raintype[0:countBB-1]
   rainTypeMapF = GRIDDATA(x3, y3, z_raintype, /NEAREST_NEIGHBOR, $
                           TRIANGLES=tr3, /GRID, XOUT=xpos4, YOUT=ypos4)

   z_landocean = zdata_landocean[0:countBB-1]
   landoceanMapF = GRIDDATA(x3, y3, z_landocean, /NEAREST_NEIGHBOR, $
                           TRIANGLES=tr3, /GRID, XOUT=xpos4, YOUT=ypos4)

   z_rayindex = zdata_rayindex[0:countBB-1]
   rayIndexMapF = GRIDDATA(x3, y3, z_rayindex, /NEAREST_NEIGHBOR, $
                           TRIANGLES=tr3, /GRID, XOUT=xpos4, YOUT=ypos4)

   z_2a25_srain = zdata_2a25_srain[0:countBB-1]
   srain_new_2a25 = GRIDDATA(x3, y3, z_2a25_srain, /NEAREST_NEIGHBOR, $
                             TRIANGLES=tr3, /GRID, XOUT=xpos4, YOUT=ypos4)

   IF do_2b31 then begin
     z_2b31_srain = zdata_2b31_srain[0:countBB-1]
     srain_new_2b31 = GRIDDATA(x3, y3, z_2b31_srain, /NEAREST_NEIGHBOR, $
                               TRIANGLES=tr3, /GRID, XOUT=xpos4, YOUT=ypos4)
   ENDIF

;  GRIDDATA does its interp. in double precision, returns float; we need the
;  following fields converted back into INT type:

   BB_Hgt = ROUND(BB_HgtF)  ; ROUND returns LONG
   BB_Hgt = FIX(BB_Hgt)     ; FIX returns INT -- type for netCDF
   landoceanMap = ROUND(landoceanMapF)
   landoceanMap = FIX(landoceanMap)
   rainFlagMap = ROUND(rainFlagMapF)
   rainFlagMap = FIX(rainFlagMap)
   rayIndexMap = ROUND(rayIndexMapF)
   rayIndexMap = FIX(rayIndexMap)

;  Deal with the added idiosyncrasies of rain type values
   rainTypeMap = ROUND(rainTypeMapF)
   rainTypeMap = FIX(rainTypeMap/10)    ; changed rain type flags to 3 digits
                                        ; for v6, but left no_rain/missing as 
                                        ; two-digit codes - deal with 3-digit
                                        ; (100-313) rainType values below
   idx123 = WHERE( rainTypeMap gt 0, count123 )
   if ( count123 gt 0 ) then rainTypeMap[idx123] = rainTypeMap[idx123]/10

;  This should never be needed now that we use nearest-neighbor interpolation
   idxfixme = WHERE((rainTypeMap ne 1) and (rainTypeMap ne 2) $
                and (rainTypeMap ne 3) and (rainTypeMap ne -7) $
                and (rainTypeMap ne -8) and (rainTypeMap ne -9), countBad )

   if ( countBad gt 0 ) then begin
     print, $
   format='("Warning: Have ",I0, " unknown RainType values in grid!")', countBad
;   print, rainTypeMap[idxfixme]
     rainTypeMap[idxfixme]=-8
   endif


;  Write single-level 2-D result grids/flags to netcdf file

   NCDF_VARPUT, ncid, 'landOceanFlag', landoceanMap        ; grid data
    NCDF_VARPUT, ncid, 'have_landOceanFlag', DATA_PRESENT  ; data presence flag
   NCDF_VARPUT, ncid, 'nearSurfRain', srain_new_2a25       ; grid data
    NCDF_VARPUT, ncid, 'have_nearSurfRain', DATA_PRESENT   ; data presence flag

   IF do_2b31 THEN BEGIN
      NCDF_VARPUT, ncid, 'nearSurfRain_2b31', srain_new_2b31      ; grid data
       NCDF_VARPUT, ncid, 'have_nearSurfRain_2b31', DATA_PRESENT  ; dp flag
   ENDIF

   NCDF_VARPUT, ncid, 'BBheight', BB_Hgt              ; grid data
    NCDF_VARPUT, ncid, 'have_BBheight', DATA_PRESENT  ; data presence flag
   NCDF_VARPUT, ncid, 'rainFlag', rainFlagMap         ; grid data
    NCDF_VARPUT, ncid, 'have_rainFlag', DATA_PRESENT  ; data presence flag
   NCDF_VARPUT, ncid, 'rainType', rainTypeMap         ; grid data
    NCDF_VARPUT, ncid, 'have_rainType', DATA_PRESENT  ; data presence flag
   NCDF_VARPUT, ncid, 'rayIndex', rayIndexMap         ; grid data
    NCDF_VARPUT, ncid, 'have_rayIndex', DATA_PRESENT  ; data presence flag

ENDIF  ;LEVEL=1, grid & extract for single-level elements just once


; Do the analyses for those fields averaged over multiple levels, with
; parallax-adjusted X and Y locations varying by HEIGHT.  Do TRIGRID()
; interpolative analyses for the dBZs, nearest-neighbor for rainrate.

;  Do the Nearest-Neighbor interpolation in GRIDDATA() for rain rate.
;  - set parallax-adjusted x-y for rainrate:
   x4 = xdatarain_at_h[0:countRR-1] & y4 = ydatarain_at_h[0:countRR-1] 
   TRIANGULATE, x4, y4, tr4

;  Generate the output grid's x,y locations, in km from ground radar, as
;  GRIDDATA() needs, and as in the coordinates of the PR samples to be analyzed.
;  -- analyze directly to output NX x NY grid of dxdy_km resolution.
;   xpos4 = indgen(NX)
;   xpos4 = FIX(xpos4 * dxdy_km - grid_max_x)   ; FIX these?
;   ypos4 = xpos4

;  set the z data values for rain rate, and call GRIDDATA to analyze

z_2a25_rain = zdata_2a25_rain[0:countRR-1]
rain_new_2a25 = GRIDDATA(x4, y4, z_2a25_rain, /NEAREST_NEIGHBOR, TRIANGLES=tr4, $
                     /GRID, XOUT=xpos4, YOUT=ypos4)

; Do TRIGRID() interpolative analyses for the dBZs

x = xdata_at_h[0:count-1] & y = ydata_at_h[0:count-1] 
TRIANGULATE, x, y, tr

; WHY DO WE STILL DO THESE AS 2X2KM GRIDS??

z_1c21 = zdata_1c21[0:count-1]
dbz_map_1c21 = TRIGRID(x, y, z_1c21, tr, [dxdy2A55_km,dxdy2A55_km], $
                    [-max_x,-max_y,max_x,max_y])
;  Extract grids whose dimensions are even multiples of NX and NY for REBIN
dbz_new_1c21 = dbz_map_1c21[0:x_cut, 0:y_cut]
dbz_new_1c21 = REBIN(dbz_new_1c21,NX,NY)

idxtemp = where(dbz_new_1c21 gt 0.0, count2dbz)
if count2dbz gt 0  then begin
  dbz_new_1c21[idxtemp] = 10.*ALOG10(dbz_new_1c21[idxtemp])  ;Z to dBZ
endif

z_2a25 = zdata_2a25[0:count-1]
dbz_map_2a25 = TRIGRID(x, y, z_2a25, tr, [dxdy2A55_km,dxdy2A55_km], $
                    [-max_x,-max_y,max_x,max_y])
dbz_new_2a25 = dbz_map_2a25[0:x_cut, 0:y_cut]
dbz_new_2a25 = REBIN(dbz_new_2a25,NX,NY)

idxtemp = where(dbz_new_2a25 gt 0.0, count2dbz)
if count2dbz gt 0  then begin
  dbz_new_2a25[idxtemp] = 10.*ALOG10(dbz_new_2a25[idxtemp])  ;Z to dBZ
endif

; Here's some original stuff probably related to the TRIGRID smoothing - BM
; -- Poor-man's way of defining the edge of the PR swath?
for ix = 0, NX-1 do begin
  for iy = 0, NY-1 do begin
    if (dbz_new_1c21[ix,iy] lt dbz_min) then dbz_new_1c21[ix,iy] = Z_MISSING
    if (dbz_new_2a25[ix,iy] lt dbz_min) then dbz_new_2a25[ix,iy] = Z_MISSING

;   Adhere "flight track info" to the data (below Z threshold but in swath)
    if (dbz_new_1c21[ix,iy] lt dbz_min) and (track_map[ix,iy] ge 70.) then $
       dbz_new_1c21[ix,iy] = Z_BELOW_THRESH
    if (dbz_new_2a25[ix,iy] lt dbz_min) and (track_map[ix,iy] ge 70.) then $
       dbz_new_2a25[ix,iy] = Z_BELOW_THRESH
  endfor
endfor

; Write this height's 2-D grids into the full 3-D grids for the elements

dbzraw_to_nc[*,*,LEVEL-1] = dbz_new_1c21
dbzcor_to_nc[*,*,LEVEL-1] = dbz_new_2a25
rain_to_nc[*,*,LEVEL-1] = rain_new_2a25

ENDFOR     ;( LEVELs loop)

; Write the completed 3-D grids to netcdf and close file

NCDF_VARPUT, ncid, 'dBZnormalSample', dbzraw_to_nc        ; grid data
 NCDF_VARPUT, ncid, 'have_dBZnormalSample', DATA_PRESENT  ; data presence flag
NCDF_VARPUT, ncid, 'correctZFactor', dbzcor_to_nc         ; grid data
 NCDF_VARPUT, ncid, 'have_correctZFactor', DATA_PRESENT   ; data presence flag
NCDF_VARPUT, ncid, 'rain', rain_to_nc                     ; grid data
 NCDF_VARPUT, ncid, 'have_rain', DATA_PRESENT             ; data presence flag
NCDF_CLOSE, ncid

end
