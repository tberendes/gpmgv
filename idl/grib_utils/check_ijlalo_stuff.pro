;===============================================================================
;+
; Copyright © 2012, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; check_ijlalo_stuff.pro -- Morris/SAIC/GPM_GV  May 2012
;
; DESCRIPTION
; -----------
; JUST A TEST PROGRAM TO CHECK GRID GEOMETRY CALCULATIONS. Reads grid definition
; from a user-selected North American Mesoscale Analysis (NAMANL) model analysis
; GRIB format data file, computes gridpoint latitude and longitude arrays that
; can then be stored into a binary IDL "SAVE" file.  Has leftover code blocks
; from extract_site_soundings_from_grib.pro that can be ignored.
;
; Requires IDL Version 8.1 or greater, with built-in GRIB read/write utilities.
;
; PARAMETERS
; ----------
; gribfiles - string array, holding fully qualified path/names of the NAM/NAMANL
;             GRIB files to read.  First file is the soundings data, 2nd file is
;             the 6h precip accumulation forecast from 6 hours prior to the
;             soundings analysis, and 3rd file is the 3h precip forecast from 6
;             hours prior to the soundings analysis.  The 0-3h forecast is only
;             needed when the 6h forecast is from the 06Z or 18Z cycle, which
;             only gives a 3-6h precipitation accumulation forecast.  The 6h
;             forecast from the 00Z and 12Z cycles gives the full 0-6h precip.
; site_arr  - array of strings holding the IDs of the sites where soundings are
;             to be computed
; lat_arr   - array of latitudes for the sites in site_arr, decimal degrees N
; lon_arr   - array of longitudes for the sites in site_arr, decimal degrees E
; savefile  - pathname to file containing the gridpoint latitude, longitude, and
;             wind rotation angle variables (IDL "SAVE" file)
; verbose   - binary parameter, enables the output of diagnostic information
;             when set
;
; NON-SYSTEM ROUTINES CALLED
; --------------------------
; - find_alt_filename()
; - get_6h_precip()
; - grib_get_record()   (from Mark Piper's IDL GRIB webinar example code)
; - uncomp_file()
;
; HISTORY
; -------
; 05/23/12 - Morris, GPM GV, SAIC
; - Created.
;
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;===============================================================================

function check_ijlalo_stuff, gribfiles, site_arr, lat_arr, lon_arr, $
                             SAVEFILE=savefile, VERBOSE=verbose

printem = KEYWORD_SET(verbose)

; first grab the previous 6 hours' precip accumulation field from the NAM
; forecast GRIB files
precip_miss = 9999.0   ; initial guess
period = 0             ; accumulation period length, hours
;precip = get_6h_precip(gribfiles, precip_miss, period, VERBOSE=verbose)

; i,j offsets for computing 4 points around radar site i,j's
offsets=FLTARR(2,4)
offsets[*,0]=[-0.5,-0.5]
offsets[*,1]=[-0.5, 0.5]
offsets[*,2]=[ 0.5, -0.5]
offsets[*,3]=[ 0.5, 0.5]

nsites = N_ELEMENTS(site_arr)

havefile = find_alt_filename( gribfiles[0], gribfile )
if ( havefile ) then begin
;  Get an uncompressed copy of the found file
   cpstatus = uncomp_file( gribfile, file_2do )
   if (cpstatus eq 'OK') then begin
;      parmlist = grib_print_parameternames( file_2do )
;      print, parmlist
     ; read one grib message in file into a structure, and get grid definition parms
     ; -- for now, assume we only have/are interested in NCEP Lambert Conformal parms.
      ptr_gribrec = ptr_new(/allocate_heap)
      *ptr_gribrec = grib_get_record( file_2do, 1, /structure )
      if *ptr_gribrec eq !null then message, "Error reading GRIB file: "+gribfile
      GridDefNum = (*ptr_gribrec).GRIDDEFINITION
         IF (printem) THEN print, "GridDefNum: ",GridDefNum
      map_proj = (*ptr_gribrec).GRIDTYPE
         IF (printem) THEN print, "map_proj: ",map_proj
      EarthRad_m = (*ptr_gribrec).RADIUS
         IF (printem) THEN print, "EarthRad_m: ",EarthRad_m
      alignLon = (*ptr_gribrec).LOVINDEGREES
         IF (printem) THEN print, "alignLon: ",alignLon
      LatInDeg1 = (*ptr_gribrec).LATIN1INDEGREES
         IF (printem) THEN print, "LatInDeg1: ",LatInDeg1
      LatInDeg2 = (*ptr_gribrec).LATIN2INDEGREES
         IF (printem) THEN print, "LatInDeg2: ",LatInDeg2
      NX = (*ptr_gribrec).NX
         IF (printem) THEN print, "NX: ",NX
      NY = (*ptr_gribrec).NY
         IF (printem) THEN print, "NY: ",NY
      DX_m = (*ptr_gribrec).DXINMETRES
         IF (printem) THEN print, "DX_m: ",DX_m
      DY_m = (*ptr_gribrec).DYINMETRES
         IF (printem) THEN print, "DY_m: ",DY_m
      LatTrue = (*ptr_gribrec).LaDInDegrees
         IF (printem) THEN print, "LatTrue: ",LatTrue
      Lat_1_1Deg = (*ptr_gribrec).LATITUDEOFFIRSTGRIDPOINTINDEGREES
         IF (printem) THEN print, "Lat_1_1Deg: ",Lat_1_1Deg
      Lon_1_1Deg = (*ptr_gribrec).LONGITUDEOFFIRSTGRIDPOINTINDEGREES
         IF (printem) THEN print, "Lon_1_1Deg: ",Lon_1_1Deg
      ptr_free, ptr_gribrec

gridlat = fltarr(NX, NY)
gridlon = gridlat
gridx = fltarr(NX, NY)
gridy = gridx
status = CALC_LAT_LONG_LAM( Lat_1_1Deg, Lon_1_1Deg, LatInDeg1, alignLon, $
                            'EAST', DX_m, gridlat, gridlon, NX, NY )
status = CALC_IJ_LAM( gridlat, gridlon, Lat_1_1Deg, Lon_1_1Deg, LatInDeg1, $
                      alignLon, 'EAST', DX_m, gridx, gridy, NX, NY )
stop
      map_proj_grib2idl = HASH()   ; To Do -- define all these in an include file
      map_proj_grib2idl['lambert'] = 'Lambert Conic'

     ; set up the IDL map transformation
      mymap = map_proj_init( map_proj_grib2idl[map_proj], $
                             sphere_radius = EarthRad_m,  $
                             center_latitude = LatTrue,   $
                             center_longitude = alignLon, $
                             STANDARD_PAR1 = LatInDeg1,   $
                             STANDARD_PAR2 = LatInDeg2 )

     ; get x and y of first (lower left) gridpoint [(1,1) in GRIB-speak]
      xy_1_1 = map_proj_forward(map=mymap, Lon_1_1Deg, Lat_1_1Deg)

     ; get the x and y map coordinate values of the radar sites
      xy_arr = map_proj_forward(map=mymap, lon_arr, lat_arr)

     ; get the grid (i,j) coordinates of each site, where (0,0) is the first
     ; gridpoint in IDL array world
      ij_arr = xy_arr                    ; size it the same as xy
      ij_arr[*,*] = 0.0                  ; init to zeroes, just because
      for isite = 0, nsites-1 do begin
         ij_arr[*,isite] = (xy_arr[*,isite]-xy_1_1)/DX_m  ;dx=dy for NAM 218, etc.
      endfor


      nsites = N_ELEMENTS( site_arr )
     ; container for the 1-D indexes of each site's gridpoints to average
      siteptsidx_all = LONARR(4, nsites)
      ngoodpts = INTARR(nsites)

     ; compute the site geometries and write site data to structures
     ; TODO: find gridpoints within "X" km of site for averaging of precipitation,
     ;       rather than just averaging 4 surrounding gridpoints. X is TBD.
      for isite = 0, nsites-1 do begin
         IF (printem) THEN print, "site: ",site_arr[isite]

        ; determine the 4 gridpoints around the site, in IDL 2-D array coords.
         sitepts2d=LONARR(2,4)
         siteptsidx = LONARR(4)  ; container for the 1-D indexes of sitepts2d
         siteptsidx[*] = -1L
         goodpts = INTARR(4)     ; track whether gridpoints are within grid boundaries
         ngoodpts[isite] = 0
         for corner=0,3 do begin
             tempsitepts=FLOAT(ij_arr[*,isite])+offsets[*,corner]
            ; is corner within the grid domain?
             IF tempsitepts[0] GE 0.0 && tempsitepts[0] LE (NX-1) $
             && tempsitepts[1] GE 0.0 && tempsitepts[1] LE (NY-1) THEN BEGIN
                goodpts[corner] = 1
                sitepts2d[*,corner] = LONG(tempsitepts)
                siteptsidx[corner] = sitepts2d[1,corner]*NX + sitepts2d[0,corner]
                ngoodpts[isite]++
             ENDIF ELSE sitepts2d[*,corner] = [-1L, -1L]
         endfor
         siteptsidx_all[*,isite] = siteptsidx
         IF (printem) THEN BEGIN
            print, ''
            print, 'Site i,j coordinates (0-based):'
            print, ij_arr[*,isite]
            ixsite = REFORM(FIX(ij_arr[0,isite]+0.5))
            jysite = REFORM(FIX(ij_arr[1,isite]+0.5))
            print, 'lat/lon from CALC_LAT_LONG_LAM: ', $
                    gridlat[ixsite,jysite], ',', gridlon[ixsite,jysite]-360.
            print, 'Surrounding gridpoint i,j values:'
            print, sitepts2d
;            print, 'Surrounding gridpoint array indices:'
;            print, siteptsidx
            print, ''
         ENDIF
      endfor
; -------------------------------------------------------------------

      errorExit:
      
     ; Remove the temporary file copy
      command = "rm -v " + file_2do
      spawn,command

     ; if we hit a fatal error, report it and return error indicator to caller
      IF N_ELEMENTS(msg) NE 0 THEN BEGIN
         message, msg, /INFORMATIONAL
         return, -1
      ENDIF

   endif else begin
      print, cpstatus
      return, -1
   endelse
endif else begin
   print, "Cannot find regular/compressed file " + gribfile
   return, -1
endelse

return, 0
end
