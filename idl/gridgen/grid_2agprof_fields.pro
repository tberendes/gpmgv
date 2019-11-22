;+
; Copyright © 2016, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; grid_2agprof_fields.pro        Morris/GPM GV/SAIC      May 2016
;
; DESCRIPTION:
; ------------
; Reads latitude, longitude, and rain rate fields from a 2AGPROF data file,
; resamples rain rate to a 2-D grid centered on an overpassed ground radar,
; applies a rain rate threshold to flag rainy points, and computes a rain
; type from convective rain fields in the GPROF file.  Saves computed array
; variables to an IDL Save file whose pathname(s) is/are given in the saveFile
; parameter.  The resolution and x-y dimension of the output grid are given
; by the res and GridN parameters.  If NEAREST_NEIGHBOR is set, then this
; method of gridding will be used for rain rate, otherwise the interpolation
; method will be RADIAL_BASIS_FUNCTION with a natural spline fit.  If FIND_RAIN
; is set, then the grid file will be saved only if at least 10 percent of grid
; points within 150 km range of the ground radar indicate rain rates above a
; 0.1 mm/h threshold.
;
; HISTORY:
; --------
; 02/24/2014 - Morris        - Created.
; 03/09/2017 - Morris        - Added FIND_RAIN parameter option and logic.
;                            - Changed threshold for rain flag from 0.25 to 0.1
;                              mm/h to support FIND_RAIN capability.
;
; NOTES:
; ------
;
; 1) Information on rain flag (flagPrecip).
;  - flagPrecip (4-byte integer, array size: nray x nscan):;    Precipitation or no precipitation.;           1   No precipitation;           2   Precipitation;       -9999   Missing value
;
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;
;-

function grid_2agprof_fields, file_2aGPROF, saveFile, INSTRUMENT, $
                              res, GridN, siteID, siteLong, siteLat, nsites, $
                              NEAREST_NEIGHBOR=nearest_neighbor, $
                              FIND_RAIN=find_rain

; Information on the types of rain storm.  From dpr_params.inc include file.
RainType_stratiform =  1   ;(Stratiform)
RainType_convective =  2   ;(Convective)
RainType_other      =  3   ;(Others)
RainType_no_data    = -7   ;(Grdpt not coincident)
RainType_no_rain    = -8   ;(No rain)
RainType_missing    = -9   ;(Missing data)
FLAGPRECIP_PRECIPITATION = 1

;
; Read/extract 2aGPROF Rain Rate, lat, lon
;
   status = read_2agprof_hdf5( file_2AGPROF, /READ_ALL )

   s=SIZE(status, /TYPE)
   CASE s OF
      8 :         ; expected structure to be returned, just proceed
      2 : BEGIN
          IF ( status EQ -1 ) THEN BEGIN
            PRINT, ""
            message, "ERROR reading fields from ", file_2AGPROF
          ENDIF ELSE message, "Unknown type returned from read_2agprof_hdf5."
          END
       ELSE : message, "Passed argument type not an integer or a structure."
   ENDCASE


; extract pointer data fields into Lats and Lons arrays
   Lons = (*status.S1.ptr_datasets).Longitude
   Lats = (*status.S1.ptr_datasets).Latitude

; NOTE THAT THE ARRAYS ARE IN (RAY,SCAN) COORDINATES.  NEED TO ACCOUNT FOR THIS
; WHEN ASSIGNING "gmi_master_idx" ARRAY INDICES.

; - get dimensions (#footprints, #scans) from Lons array
   s = SIZE(Lons, /DIMENSIONS)
   IF N_ELEMENTS(s) EQ 2 THEN BEGIN
      IF s[0] EQ status.s1.SWATHHEADER.NUMBERPIXELS THEN NPIXEL_GMI = s[0] $
        ELSE message, 'Mismatch in data array dimension NUMBERPIXELS.'
;      IF s[1] EQ status.s1.SWATHHEADER.MAXIMUMNUMBERSCANSTOTAL $
;        THEN NSCANS_GMI = s[1] $
;        ELSE message, 'Mismatch in data array dimension NUMBERSCANS.', /INFO
      NSCANS_GMI = s[1]
   ENDIF ELSE message, "Don't have a 2-D array for Longitude, quitting."

; extract pointer data fields into instrument data arrays
;   pixelStatus = (*status.S1.ptr_datasets).pixelStatus
   qualityFlag = (*status.S1.ptr_datasets).qualityFlag
   convectPrecipFraction = (*status.S1.ptr_datasets).convectPrecipFraction
   convectivePrecipitation = (*status.S1.ptr_datasets).convectivePrecipitation
   surfacePrecipitation = (*status.S1.ptr_datasets).surfacePrecipitation
;   PoP = (*status.S1.ptr_datasets).probabilityOfPrecip

; set a binary rain flag value based on rain rate at/exceeeding 0.1 mm/h
   rainFlag = FIX(surfacePrecipitation GE 0.1)

; define rain type categories based on convectPrecipFraction (V04 and earlier)
; or convectivePrecipitation/surfacePrecipitation (V05 and later).  If V04 or
; earlier, then convectivePrecipitation will be returned as the string 'N/A'.
; If V05 or later, obsolete convectPrecipFraction variable will be returned as
; the string 'N/A'.

   IF SIZE(convectivePrecipitation, /TYPE) EQ 7 THEN BEGIN
      ; If convectivePrecipitation is STRING (type code 7) then it is <=V04A,
      ; and we use convectPrecipFraction in rain type determination
      rainType = convectPrecipFraction     ; create same-size variable
      ; initialize all points to stratiform
      rainType[*,*] = RainType_stratiform
      ; set below-zero values to missing rain type
      idxrrmiss = WHERE(convectPrecipFraction LT 0.0, countrrmiss)
      IF countrrmiss GT 0 THEN rainType[idxrrmiss] = RainType_missing
      ; set points with fraction>0.5 to convective
      idxrrconv = WHERE(convectPrecipFraction GT 0.5, countrrconv)
      IF countrrconv GT 0 THEN rainType[idxrrconv] = RainType_convective
   ENDIF ELSE BEGIN
      ; V05 or later, we use convectivePrecipitation in rain type determination
      rainType = convectivePrecipitation     ; create same-size variable
      ; initialize all points to stratiform
      rainType[*,*] = RainType_stratiform
      ; set below-zero values to missing rain type
      idxrrmiss = WHERE(convectivePrecipitation LT 0.0 $
                     OR surfacePrecipitation LT 0.0, countrrmiss)
      IF countrrmiss GT 0 THEN rainType[idxrrmiss] = RainType_missing
      idxrrgood = WHERE(convectivePrecipitation GE 0.0 $
                    AND surfacePrecipitation GT 0.001, countrrgood)
      idxrrconv = WHERE(convectivePrecipitation[idxrrgood]/surfacePrecipitation[idxrrgood] $
                        GT 0.5, countrrconv)
      IF countrrconv GT 0 THEN rainType[idxrrgood[idxrrconv]] = RainType_convective
   ENDELSE
   help, countrrconv, countrrgood

; free the remaining memory/pointers in data structure
   free_ptrs_in_struct, status

; define arrays sufficient to hold data for the maximum possible number of GPROF
; footprints within our analysis region
xdata = fltarr(9000)
ydata = fltarr(9000)
zdata_rainType = fltarr(9000)
zdata_rainflag = intarr(9000)
zdata_sfcRainRate = fltarr(9000)

;******************************************************************************
; Here is where we now start looping over the list of sites overpassed in
; this orbit. Need to reinitialize variables first (as a good practice).
;******************************************************************************

for siteN = 0, nsites - 1 do begin

   print, format='("Processing 2A-",a0," precip. metadata for ",a0)', $
          Instrument, siteID[siteN]

   count = 0L
   countQCbad = 0L
   countINrange = 0L
   xdata[*] = 0.0
   ydata[*] = 0.0
   zdata_rainType[*] = 0.0
   zdata_rainflag[*] = 0
   zdata_sfcRainRate[*] = 0.0

  ; initialize a gv-centered map projection for the ll<->xy transformations:
   sMap = MAP_PROJ_INIT( 'Azimuthal Equidistant', center_latitude=siteLat[siteN], $
                         center_longitude=siteLong[siteN] )

   ; -- Convert lat/lon for each GPROF beam sample to ground-radar-centric
   ;    x and y cartesian coordinates, in km.  Store location and element
   ;    data for samples within 200 km in arrays for interpolation to GV grid.
   ;
   for scan=0, NSCANS_GMI-1 do begin
     for angle = 0, NPIXEL_GMI-1 do begin
       ; coarse filter to beams within +/- 3 degrees of site lat/lon
        IF (ABS(lons[angle,scan]-siteLong[siteN]) lt 3.) and $
           (ABS(lats[angle,scan]-siteLat[siteN]) lt 3.) then begin
 
           XY_km = map_proj_forward( lons[angle,scan], $
                                     lats[angle,scan], $
                                     map_structure=smap ) / 1000.
           XX = XY_km[0]
           YY = XY_km[1]

           ; fine filter, save only points falling within/around the
           ; 300x300km grid bounds
           if (abs(XX) le 200.) and (abs(YY) le 200.) then begin  
              countInRange = countInRange + 1
             ; POPULATE THE ARRAYS OF POINTS TO BE ANALYZED
             ; - EXCLUDE SAMPLES NOT MEETING QUALITY CRITERION
              IF qualityFlag[angle,scan] LT 2 THEN BEGIN
                 xdata[count] = XX
                 ydata[count] = YY
                 zdata_rainType[count] = rainType[angle,scan]
                 zdata_rainflag[count] = rainFlag[angle,scan]
                 zdata_sfcRainRate[count] = surfacePrecipitation[angle,scan]
                 count = count + 1
;                 print, scan, angle, XX, YY, zdata_rainType[count-1]
              ENDIF ELSE BEGIN
                 ;print, "Rejecting qualityFlag value: ", qualityFlag[angle,scan]
                 countQCbad = countQCbad + 1
              ENDELSE
           endif  ;fine x,y filter
        ENDIF     ;coarse lat/lon filter
     endfor       ; angles
   endfor         ; scans

print, ''
print, "Rejected ", countQCbad, " of ", countInRange, " based on QualityFlag."
print, ''

   if (count eq 0L) then begin
      print, "countQCbad: ", countQCbad
      message, "No grids able to be computed for event!"
   endif else begin
     ; cut out the arrays of assigned footprint x,y, and data field values
      x = xdata[0:count-1]
      y = ydata[0:count-1]
      z_rainType = zdata_rainType[0:count-1]
      z_rainflag=zdata_rainflag[0:count-1]
      zdata_sfcRainRate=zdata_sfcRainRate[0:count-1]

     ; compute the Delauney triangulation of the x,y coordinates
      TRIANGULATE, x, y, tr

     ; define the output Cartesian grid dimensions and coordinates, 1-D arrays
     ; required for GRIDDATA() inputs
      xout = findgen(GridN)
      xout = xout * res - res*(GridN/2)
      yout = xout

     ; compute the gridpoint lat/lon arrays from 2-D x- and y-positions
     ; converted to meters
      xdist = findgen(GridN, GridN)
      xdist = ((xdist mod GridN) - (GridN/2)) * res
      ydist = TRANSPOSE(xdist)
      lon_lat = MAP_PROJ_INVERSE( xdist*1000., ydist*1000., MAP_STRUCTURE=smap )
      gridLon = REFORM(FLOAT(lon_lat[0,*]), GridN, GridN)
      gridLat = REFORM(FLOAT(lon_lat[1,*]), GridN, GridN)

     ; Compute a radial distance array for a 'res'-km-resolution 2-D grid of
     ; dimensions GridN x GridN points, where x- and y-distance at center point
     ; is 0.0 km.
      dist = SQRT(xdist*xdist + ydist*ydist)

     ; =========================================================================

     ; do the nearest-neighbor gridding of rain type
      rainType_new = GRIDDATA(x, y, z_rainType, /NEAREST_NEIGHBOR, $
                              TRIANGLES=tr, /GRID, XOUT=xout, YOUT=yout)

      ; handle -77/-88/-99 properly -> -7/-8/-9
      ; GRIDDATA output is FLOAT, cast to INT when rescaling
      rainType = FIX(rainType_new)
;      idx123 = WHERE( rainType lt 0, count123 )
;      if ( count123 gt 0 ) then rainType[idx123] = rainType[idx123]/10

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

     ; =========================================================================

     ; analyze grid for rain flag

      rainFlagMapF = GRIDDATA(x, y, z_rainflag, /NEAREST_NEIGHBOR, $
                              TRIANGLES=tr, /GRID, XOUT=xout, YOUT=yout)
    ; GRIDDATA does interp in double precision, returns float; we need back in INT
      rainFlagMap = FIX(rainFlagMapF + 0.0001)

     ; pull metrics out of the RainFlag element for inside 150 km range
      idx150 = WHERE(dist LE 150., count150)
      idxRain = WHERE((rainFlagMap[idx150] AND FLAGPRECIP_PRECIPITATION) NE 0, $
                      numRainPts)
      print, "Num Gridpoints inside 150 km with Rain Certain flag: ", numRainPts
      fractionRain = FLOAT(numRainPts)/count150
      print, "Fraction of Gridpoints inside 150 km with Rain: ", fractionRain

     ; if FIND_RAIN is set, analyze rain rate grid and save file only if
     ; fractionRain is 0.1 or greater.  If not set, then always do rain rate
     ; grid and save file.

      GRID_AND_SAVE = 1
      IF KEYWORD_SET(FIND_RAIN) AND fractionRain LT 0.1 THEN GRID_AND_SAVE = 0

     ; =========================================================================

      IF GRID_AND_SAVE THEN BEGIN
        ; do the nearest-neighbor or radial basis/natural spline gridding of
        ; surface rain rate

         IF KEYWORD_SET(NEAREST_NEIGHBOR) THEN BEGIN
            rainrate = GRIDDATA(x, y, zdata_sfcRainRate, /NEAREST_NEIGHBOR, $
                                 TRIANGLES=tr, /GRID, XOUT=xout, YOUT=yout)
         ENDIF ELSE BEGIN
            rainrate = GRIDDATA(x, y, zdata_sfcRainRate, /RADIAL_BASIS_FUNCTION, $
                                 TRIANGLES=tr, FUNCTION_TYPE=3, /GRID, $
                                 XOUT=xout, YOUT=yout)
            idxNegRR = WHERE(rainrate LT 0.0, countNeg)
            IF countNeg GT 0 THEN rainrate[idxNegRR] = 0.0
         ENDELSE

        ; =========================================================================

        ; save the gridded arrays to the IDL Save file

         SAVE, file=saveFile[siteN], rainrate, rainFlagMap, rainType, dist, $
               gridLat, gridLon

        ; =========================================================================
      ENDIF ELSE BEGIN
         print, "Skip gridfile creation, insufficient rain area fraction."
      ENDELSE

   endelse  ; (count eq 0L)

endfor      ;(nsites loop)
status = 'OK'

errorExit:

return, status

end
