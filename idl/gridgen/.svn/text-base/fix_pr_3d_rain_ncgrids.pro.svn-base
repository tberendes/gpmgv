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

pro fix_pr_3d_rain_ncgrids, nAvgHeight=hh, ncfile, lons, lats,  $
                         rain_2a25, $
                         rangeBinNums, $
                         binS, rayStart

common sample,       start_sample,sample_range,num_range,dbz_min
common time,         event_time, volscantime, orbit
common sample_rain,  RAIN_MIN, RAIN_MAX
common groundSite,   event_num, siteID, siteLong, siteLat, nsites
common trig_precalc, cos_inc_angle, tan_inc_angle

; 'Include' file for grid dimensions, spacings
@grid_def.inc

; "Include" file for PR-product-specific values, parameters
@pr_params.inc


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

; Create the output 3-D grid arrays.

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

; A pair of x-y arrays "_at_h" holds parallax-adjusted x-y for rain rate,
; plus swath-edge delimiter value for nearest neighbor analysis.  Added 07/2008
xdatarain_at_h = fltarr(max_pr_fp)
ydatarain_at_h = fltarr(max_pr_fp)

; x,y locations for Rain Flag/Type and RayIndex, no parallax offset
zdata_2a25_rain = fltarr(max_pr_fp)


; ****************  Proceed to the grid analyses ******************

FOR  LEVEL = 1, NZ  DO BEGIN
HEIGHT = ZLEVELS[LEVEL-1] / 1000.  ; convert ZLEVELS from m to km

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
countBB = 0L
xdatarain_at_h[*]=0.0
ydatarain_at_h[*]=0.0
zdata_2a25_rain[*]=0.0

; -- Find x,y, and element (i.e., z) data in our grid bounding box, i.e.,
;    within +/- 150km of ground radar.  Will be at random (x,y) points
;    relative to the fixed-location GV radar grid of the 2A-55 product.

do_print = 0                        ; init to False, 1 if print wanted

for scan=0,SAMPLE_RANGE-1 do begin

did_slope = 0        ; init to FALSE
did_edges = 0        ; init to FALSE - has edge-of-scan been marked for this scan?
do_edges = 0         ; init to FALSE - must edge-of-scan be marked for this scan?
min_angle =  RAYSPERSCAN   ; angle index of first scan point falling within grid
max_angle = -1             ; angle index of last scan point falling within grid

for angle = 0,RAYSPERSCAN-1  do begin

 ; coarse filter to PR beams within our calculated thresholds (deg.) lat/lon
 IF (ABS(lons[angle,scan]-siteLong) lt max_deg_lon) and $
     (ABS(lats[angle,scan]-siteLat) lt max_deg_lat) then begin

  coordinate_b_to_a, siteLong, siteLat, lons[angle,scan], $
                  lats[angle,scan], XX, YY
  
; Fine filter, save only points falling within the grid bounds
  if (abs(XX) le max_x) and (abs(YY) le max_y) then begin
    do_edges = 1
    if (angle LT min_angle ) then min_angle = angle
    if (angle GT max_angle ) then max_angle = angle
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
;   and add the point coordinates to the x,y arrays
    
    xdatarain_at_h[countBB] = XX + dX
    ydatarain_at_h[countBB] = YY + dY

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
    if nh_rain_2a25 eq 0 then begin
;     No values in layer met criteria, grab the middle one to represent
;     the layer average value and deal with it after analysis.
      gateN = 0 > (80 - ip[angle,hh])
      zdata_2a25_rain[countBB] = rain_2a25[scan,angle,gateN]/RAINSCALE2A25
    endif else begin
      zdata_2a25_rain[countBB] = sum_rain_2a25/nh_rain_2a25
    endelse

    countBB = countBB + 1

;   Add edge-of-swath delimiter points for nearest-neighbor, if on edge

    if (angle eq 0) OR (angle eq RAYSPERSCAN-1) then begin 
      ; Extrapolate the footprint's X and Y off-edge
       scan_edge_x_and_y, scan, angle, RAYSPERSCAN, siteLong, siteLat, $
                          lons, lats, XX, YY
      ; if within the grid, add a MISSING point to the x-y-z data arrays
       ;if (abs(XX) le max_x) and (abs(YY) le max_y) then begin
          xdatarain_at_h[countBB] = XX
          ydatarain_at_h[countBB] = YY
          zdata_2a25_rain[countBB] = SRAIN_OFF_EDGE
          countBB = countBB + 1
          did_edges = 1
       ;endif
    endif

  endif    ; within grid, ABS( XX and YY ) <= max_[x and y]
 ENDIF     ; rough proximity check, ABS(lat, lon diffs) < 3 deg.

endfor     ; angles in scan

;   Add edge-of-swath delimiter points for nearest-neighbor, if any inner points
;   in scan were in grid but neither the 1st or last points were.

    if (do_edges eq 1) AND (did_edges eq 0) then begin 
      ; which half of the scan was most within the grid?
       if ((min_angle+max_angle)/2 LT RAYSPERSCAN/2 ) then begin
          ; min_angle side is adjacent to marked edge-of-scan, mark point
          ; at preceding angle
          coordinate_b_to_a, siteLong, siteLat, lons[min_angle-1,scan], $
                       lats[min_angle-1,scan], XX, YY
       endif else begin
          ; max_angle side is adjacent to marked edge-of-scan, mark point at
          ; following angle
          coordinate_b_to_a, siteLong, siteLat, lons[max_angle+1,scan], $
                       lats[max_angle+1,scan], XX, YY
       endelse
       xdatarain_at_h[countBB] = XX
       ydatarain_at_h[countBB] = YY
       zdata_2a25_rain[countBB] = SRAIN_OFF_EDGE
       countBB = countBB + 1
    endif

endfor     ; scans in PR product


; -- Now analyze each field to a regular grid centered on ground radar

;  Generate the output grid's x,y locations, in km from ground radar, as
;  GRIDDATA() needs, and as in the coordinates of the PR samples to be analyzed.
;  -- analyze directly to output NX x NY grid of dxdy_km resolution.
   xpos4 = indgen(NX)
   xpos4 = FIX(xpos4 * dxdy_km - grid_max_x)   ; FIX these?
   ypos4 = xpos4



; Do the analyses for those fields averaged over multiple levels, with
; parallax-adjusted X and Y locations varying by HEIGHT.  Do TRIGRID()
; interpolative analyses for the dBZs, nearest-neighbor for rainrate.

;  Do the Nearest-Neighbor interpolation in GRIDDATA() for rain rate.
;  - set parallax-adjusted x-y for rainrate:
   x4 = xdatarain_at_h[0:countBB-1] & y4 = ydatarain_at_h[0:countBB-1] 
   TRIANGULATE, x4, y4, tr4

;  Generate the output grid's x,y locations, in km from ground radar, as
;  GRIDDATA() needs, and as in the coordinates of the PR samples to be analyzed.
;  -- analyze directly to output NX x NY grid of dxdy_km resolution.
;   xpos4 = indgen(NX)
;   xpos4 = FIX(xpos4 * dxdy_km - grid_max_x)   ; FIX these?
;   ypos4 = xpos4

;  set the z data values for rain rate, and call GRIDDATA to analyze

z_2a25_rain = zdata_2a25_rain[0:countBB-1]
rain_new_2a25 = GRIDDATA(x4, y4, z_2a25_rain, /NEAREST_NEIGHBOR, TRIANGLES=tr4, $
                     /GRID, XOUT=xpos4, YOUT=ypos4)


; Write this height's 2-D grids into the full 3-D grids for the elements

rain_to_nc[*,*,LEVEL-1] = rain_new_2a25

ENDFOR     ;( LEVELs loop)

; Write the completed 3-D grids to netcdf and close file

NCDF_VARPUT, ncid, 'rain', rain_to_nc                     ; grid data
 NCDF_VARPUT, ncid, 'have_rain', DATA_PRESENT             ; data presence flag
NCDF_CLOSE, ncid

end

;***********************************************************************************

 pro scan_edge_x_and_y, scan, angle, RAYSPERSCAN, $
                        siteLong, siteLat, lons, lats, XX2, YY2

;***********************************************************************************

    XX = XX2
    YY = YY2
    if ( angle LT RAYSPERSCAN/2 ) then begin 
       ; extrapolate X and Y to where (angle = angle-1) would be
       ; Get the next footprint's X and Y
       coordinate_b_to_a, siteLong, siteLat, lons[angle+1,scan], $
                       lats[angle+1,scan], XX2, YY2
       ; calculate dx and dy and apply
       XX2 = XX - (XX2 - XX)
       YY2 = YY - (YY2 - YY)
    endif else begin
       ; extrapolate X and Y to where (angle = angle+1) would be
       ; Get the preceding footprint's X and Y
       coordinate_b_to_a, siteLong, siteLat, lons[angle-1,scan], $
                       lats[angle-1,scan], XX2, YY2
       ; calculate dx and dy and apply
       XX2 = XX + (XX - XX2)
       YY2 = YY + (YY - YY2)
    endelse
 end
