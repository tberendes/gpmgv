;===============================================================================
;+
; Copyright © 2014, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; dpr2gmi.pro          Morris/SAIC/GPM_GV      September 2014
;
; DESCRIPTION
; -----------
; Performs a resampling of GMI and DPR data to common volumes, defined by the
; GMI footprint sizes and locations.  The matchup is performed on the swath
; data in the area in common between the GMI and DPR scans.  A matched set of
; DPR and GMI orbit subset products (orbit/subset, PPS version) is input to
; the routine.  Returns a structure containing:
;
;   - GMI rain rate from the 2A-GPROFGMI file (all GMI footprints in file)
;   - Count of DPR footprints mapped to each of the above, based on 'radius'
;   - Mean DPR near-surface rain rate matched to the GMI footprints
;   - Count of non-zero DPR rain rates in above average
;   - Mean 2B-DPRGMI combined rain rate matched to the GMI footprints
;   - Count of non-zero 2B-DPRGMI rain rates in above average
;   - Count of DPR footprints matched to the GMI footprint that have rain type
;     value of Convective
;   - Count of DPR footprints matched to the GMI footprint that have flagPrecip
;     value indicating precipitation exists
;
;
; MODULES
; -------
; 1)  dpr2gmi:               Main function to matchup DPR rainfall to GMI,
;                            given a matching set of 2A-GPROFGMI, 2A-DPR/Ka/Ku,
;                            and (optional) 2BDPRGMI filenames as input.
; 2)  compute_averages:      Computes averages of array data, with options to:
;                              a) set negative values to 0 in averaging, or to:
;                              b) exclude them from the average.
;
; HISTORY
; -------
; 9/22/2014 by Bob Morris, GPM GV (SAIC)
;  - Created from pr2tmi.pro.
;
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;===============================================================================

; MODULE 2:  compute_average_and_n

FUNCTION compute_average_and_n, values, n_non_zero, NEGSTOZERO=negsToZero

; Compute average of array elements included in "values" array, and the number
; of non-zero values ("n_non_zero") contained in the average.  If keyword
; NEGSTOZERO is set, then set all negative values to 0.0, and average over all
; values.  If not set, then only average the non-negative values (if any), or
; just return the first element of "values" array as the average.

negsToZero = KEYWORD_SET(negsToZero)
IF negsToZero THEN BEGIN
   idxNegs = WHERE( values LT 0.0, countnegs)
   IF countnegs GT 0 THEN values[idxNegs] = 0.0
   meanval = MEAN(values)
ENDIF ELSE BEGIN
   idx2do = WHERE( values GE 0.0, count2do)
   IF count2do GT 0 THEN meanval = MEAN(values[idx2do]) ELSE meanval = values[0]
ENDELSE

idx_gt_zero = WHERE( values GT 0.0, n_non_zero)

return, meanval
end

;===============================================================================

; MODULE 1:  FUNCTION dpr2gmi

; DESCRIPTION
; -----------
; Top-level function called by the user or external calling routine.  See the
; prologue at the top of this file for the detailed description.
;
;
; PARAMETERS
; ----------
; gprofgmifile  - Full pathname of a GMI 2A-GPROF product file.
;
; dprfile       - Full pathname of a 2A-DPR, 2A-Ka, or 2A-Ku product file.
;
; dprgmifile    - Full pathname of a 2B-DPRGMI product file. Optional parameter.
;
; radius        - Non-default radius to use for identifying DPR footprints to be
;                 included in the DPR data average surrounding each GMI surface
;                 footprint location.  Default=7.0 (km); min=5.0, max=50.0.
;
; ncfile_out    - Binary option.  If set, then the GMI-DPR matchup data will
;                 be written to a netCDF file which will include additional
;                 scalar variables and data arrays not contained in the data
;                 structure returned by this function.
;
; path_out      - Override to the default path for the output netCDF files.  If
;                 not specified, then the path will default to the directory
;                 given by the combination of NCGRIDS_ROOT+DPR_GMI_MATCH_NCDIR
;                 as defined in the "include" file, environs.inc.
;
;
; HISTORY
; -------
; 09/22/14  Morris/GPM GV/SAIC
; - Created from pr2tmi.pro
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;===============================================================================

FUNCTION dpr2gmi, gprofgmifile, dprfile, DPR_scantype, dprgmifile_in, $
                  RADIUS=radius, NCFILE_OUT=ncfile_out, PATH_OUT=path_out


; "Include" file for DATA_PRESENT, NO_DATA_PRESENT
@grid_def.inc
; "Include" file for GMI-product-specific parameters (i.e., NPIXEL_GMI):
@gmi_params.inc
; "Include" file for names, paths, etc.:
@environs.inc
; "Include" file for special values in netCDF files: Z_BELOW_THRESH, etc.
@dpr_params.inc

IF N_ELEMENTS(dprgmifile_in) EQ 1 THEN $
   IF dprgmifile_in NE 'no_DPR_file' THEN dprgmifile = dprgmifile_in
;help, dprgmifile, dprgmifile_in
; set the default radius if one is not provided or is out-of-range
IF N_ELEMENTS(radius) EQ 0 THEN BEGIN
   print, "Setting default radius for GMI footprint to 7.0 km" & print, ""
   radius = 7.0
ENDIF ELSE BEGIN
   IF (radius LT 5.0) OR (radius GT 50.0) THEN BEGIN
      print, "Radius must be between 5.0 and 50.0 km, supplied value = ", radius
      print, "Setting default radius for GMI footprint to 7.0 km" & print, ""
      radius = 7.0
   ENDIF
ENDELSE
radiusStr = STRING(radius, FORMAT="(f0.1)")

NPIXEL_GMI_PR = NPIXEL_GMI   ; set common value to GMI's constant, for a start

; get individual fields of interest from GMI filename
parsed = STRSPLIT(FILE_BASENAME(gprofgmifile), '.', /EXTRACT)
   parseddtime=STRSPLIT(parsed[4], '-', /EXTRACT)
   yymmdd = parseddtime[0]
   orbitstr = parsed[5]
   orbit = STRING(LONG(orbitstr), FORMAT='(I0)')
   PPS_vers_str = parsed[6]
   parsedLevelSubset = STRSPLIT(parsed[0], '-', /EXTRACT)
   IF parsedLevelSubset[1] EQ 'CS' THEN subset = parsedLevelSubset[2] $
   ELSE subset = 'FullOrbit'
;TRMM_vers = FIX(parsed[3])

; get individual fields of interest from DPR filename
parsed = STRSPLIT(FILE_BASENAME(dprfile), '.', /EXTRACT)
Instrument_ID = parsed[2]        ; 2A algorithm/product: Ka, Ku, or DPR

; set up the output netCDF filename if we are writing one
;ncfile_out = KEYWORD_SET( ncfile_out )
IF N_ELEMENTS( ncfile_out ) EQ 1 THEN BEGIN
   do_nc = 1
;   ncfile_base = DPR_GMI_MATCH_PRE + yymmdd +'.'+ orbit +'.'+ PPS_vers_str $
;                 +'.'+ subset +'_'+ radiusStr + 'km.nc'
;   IF N_ELEMENTS(path_out) EQ 0 THEN $
;      ncfile_out = NCGRIDS_ROOT+DPR_GMI_MATCH_NCDIR+'/'+ncfile_base $
;   ELSE ncfile_out = path_out+'/'+ncfile_base
   print,"" & print, "Writing output to netCDF file: ", ncfile_out & print,""
ENDIF ELSE do_nc = 0

; read the GMI and DPR files

   status = read_2agprof_hdf5( gprofgmifile, /READ_ALL )

   s=SIZE(status, /TYPE)
   CASE s OF
      8 :         ; expected structure to be returned, just proceed
      2 : BEGIN
          IF ( status EQ -1 ) THEN BEGIN
            PRINT, ""
            PRINT, "dpr2gmi.pro:  ERROR reading fields from ", file_2AGPROF
            PRINT, "Exiting with error."
            return, 0
          ENDIF ELSE message, "Unknown type returned from read_2agprofgmi_hdf5."
          END
       ELSE : message, "Passed argument type not an integer or a structure."
   ENDCASE


; extract pointer data fields into gmiLats and gmiLons arrays
   gmiLons = (*status.S1.ptr_datasets).Longitude
   gmiLats = (*status.S1.ptr_datasets).Latitude

;  extract pointer data fields into scLats and scLons arrays
   scLons =  (*status.S1.ptr_scStatus).SClongitude
   scLats =  (*status.S1.ptr_scStatus).SClatitude

; NOTE THAT THE ARRAYS ARE IN (RAY,SCAN) COORDINATES.  NEED TO ACCOUNT FOR THIS
; WHEN ASSIGNING "gmi_master_idx" ARRAY INDICES.

; - get dimensions (#footprints, #scans) from gmiLons array
   s = SIZE(gmiLons, /DIMENSIONS)
   IF N_ELEMENTS(s) EQ 2 THEN BEGIN
      IF s[0] EQ status.s1.SWATHHEADER.NUMBERPIXELS THEN NPIXEL_GMI = s[0] $
        ELSE message, 'Mismatch in data array dimension NUMBERPIXELS.'
;      IF s[1] EQ status.s1.SWATHHEADER.MAXIMUMNUMBERSCANSTOTAL $
;        THEN NSCANS_GMI = s[1] $
;        ELSE message, 'Mismatch in data array dimension NUMBERSCANS.', /INFO
        NSCANS_GMI = s[1]
   ENDIF ELSE message, "Don't have a 2-D array for Longitude, quitting."

; extract pointer data fields into instrument data arrays
   pixelStatus = (*status.S1.ptr_datasets).pixelStatus
   surfaceType = (*status.S1.ptr_datasets).surfaceTypeIndex
   surfacePrecipitation = (*status.S1.ptr_datasets).surfacePrecipitation
   PoP = (*status.S1.ptr_datasets).probabilityOfPrecip

; figure out which fields we got from the GMI file and tabulate in structure
dataflags = get_geo_match_nc_struct( 'fields_swath_gpm' )
idxcheck = WHERE(pixelStatus GE 0)
if idxcheck[0] NE -1 THEN dataflags.have_pixelStatus = 1
idxcheck = WHERE(surfaceType GT 0)
if idxcheck[0] NE -1 THEN dataflags.have_surfaceType = 1
idxcheck = WHERE(surfacePrecipitation GT 0.0)
if idxcheck[0] NE -1 THEN dataflags.have_surfacePrecipitation = 1
idxcheck = WHERE(PoP GE 0)
if idxcheck[0] NE -1 THEN dataflags.have_PoP = 1
;help, dataflags, /struc

tmi_master_idx = LINDGEN(NPIXEL_GMI, NSCANS_GMI)  ; "actual" GMI footprints
n_tmi_feet = N_ELEMENTS(tmi_master_idx)           ; number of GMI footprints
; get arrays of GMI scan and ray number
rayscan = ARRAY_INDICES(surfaceType, tmi_master_idx)
rayscan = REFORM(rayscan, 2, NPIXEL_GMI, NSCANS_GMI)
scantmi = REFORM(rayscan[1,*,*])
raytmi = REFORM(rayscan[0,*,*])

; define arrays for GMI footprint "corners" for image plots
xCornersGMI = FLTARR(4, NPIXEL_GMI, NSCANS_GMI)
yCornersGMI = FLTARR(4, NPIXEL_GMI, NSCANS_GMI)

; holds info on how many PR footprints there are in each GMI ray position:
npertmiray = LONARR(NPIXEL_GMI)

; hold PR science values averaged down to GMI resolution defined by "radius"
; -- how many PR footprints "map" to the GMI footprint, by radius criterion
PRinRadius2GMI = MAKE_ARRAY(NPIXEL_GMI, NSCANS_GMI, /INT, VAL=0)
; --averages of DPR and 2BDPRGMI rain rate, and non-zero count, by GMI footprint
PRsfcRainByGMI = MAKE_ARRAY(NPIXEL_GMI, NSCANS_GMI, /FLOAT, VAL=-99.0)
PRcountSfcRainByGMI = MAKE_ARRAY(NPIXEL_GMI, NSCANS_GMI, /INT, VAL=0)
PRsfcRain2BDPRGMIByGMI = MAKE_ARRAY(NPIXEL_GMI, NSCANS_GMI, /FLOAT, VAL=-99.0)
PRcountSfc2BDPRGMIRainByGMI = MAKE_ARRAY(NPIXEL_GMI, NSCANS_GMI, /INT, VAL=0)
; -- number of PR footprints of rain type Convective
PRcountRainConv = MAKE_ARRAY(NPIXEL_GMI, NSCANS_GMI, /INT, VAL=0)
PRcountflagPrecipPrecipitation = MAKE_ARRAY(NPIXEL_GMI, NSCANS_GMI, /INT, VAL=0)

; figure out our domain bounds relative to GMI coverage
latmax = MAX(gmiLats, MIN=latmin)
lonmax = MAX(gmiLons, MIN=lonmin)

; set up a Mercator map projection and compute GMI footprint cartesian
; coordinates in km
centerLat = (latmax+latmin)/2.0
centerLon = (lonmax+lonmin)/2.0
mymap = MAP_PROJ_INIT('Mercator', CENTER_LON=centerLon, CENTER_LAT=centerLat)
tmi_xy = MAP_PROJ_FORWARD(gmiLons, gmiLats, MAP=mymap) / 1000.

; separate the x and y arrays for footprint corner calculations, later on
tmi_x0 = REFORM(tmi_xy[0,*], NPIXEL_GMI, NSCANS_GMI)
tmi_y0 = REFORM(tmi_xy[1,*], NPIXEL_GMI, NSCANS_GMI)

; compute the GMI footprint corners
for itmifoot = 0L, n_tmi_feet-1 do begin
   xy = footprint_corner_x_and_y( scantmi[itmifoot], raytmi[itmifoot], tmi_x0, $
                                  tmi_y0, NSCANS_GMI , NPIXEL_GMI )
   xCornersGMI[*, raytmi[itmifoot], scantmi[itmifoot]] = xy[0,*]
   yCornersGMI[*, raytmi[itmifoot], scantmi[itmifoot]] = xy[1,*]
endfor

   ; check Instrument_ID, filename, and DPR_scantype consistency
   CASE STRUPCASE(Instrument_ID) OF
       'KA' : BEGIN
                 ; 2AKA has only HS and MS scan/swath types
                 CASE STRUPCASE(DPR_scantype) OF
                    'HS' : BEGIN
                              RAYSPERSCAN = RAYSPERSCAN_HS
                              GATE_SPACE = BIN_SPACE_HS
                           END
                    'MS' : BEGIN
                              RAYSPERSCAN = RAYSPERSCAN_MS
                              GATE_SPACE = BIN_SPACE_NS_MS
                           END
                    ELSE : message,"Illegal scan type '"+DPR_scantype+"' for KA"
                 ENDCASE
                 print, '' & print, "Reading file: ", dprfile & print, ''
                 dpr_data = read_2akaku_hdf5(dprfile, SCAN=DPR_scantype)
                 dpr_file_read = dprfile
              END
       'KU' : BEGIN
                 ; 2AKU has only NS scan/swath type
                 CASE STRUPCASE(DPR_scantype) OF
                    'NS' : BEGIN
                              print, '' & print, "Reading file: ", dprfile
                              print, ''
                              dpr_data = read_2akaku_hdf5(dprfile, $
                                         SCAN=DPR_scantype)
                              dpr_file_read = dprfile
                              RAYSPERSCAN = RAYSPERSCAN_NS
                              GATE_SPACE = BIN_SPACE_NS_MS
                           END
                    ELSE : message,"Illegal scan type '"+DPR_scantype+"' for KU"
                  ENDCASE            
              END
      'DPR' : BEGIN
                 ; 2ADPR has all 3 scan/swath types
                 CASE STRUPCASE(DPR_scantype) OF
                    'HS' : BEGIN
                              RAYSPERSCAN = RAYSPERSCAN_HS
                              GATE_SPACE = BIN_SPACE_HS
                           END
                    'MS' : BEGIN
                              RAYSPERSCAN = RAYSPERSCAN_MS
                              GATE_SPACE = BIN_SPACE_NS_MS
                              DO_RAIN_CORR = 0   ; set flag to skip 3-D rainrate
                           END
                    'NS' : BEGIN
                              RAYSPERSCAN = RAYSPERSCAN_NS
                              GATE_SPACE = BIN_SPACE_NS_MS
                           END
                    ELSE : message, "Illegal scan type '"+DPR_scantype+"'"
                 ENDCASE
                 print, '' & print, "Reading file: ", dprfile & print, ''
                 dpr_data = read_2adpr_hdf5(dprfile, SCAN=DPR_scantype)
                 dpr_file_read = dprfile
              END
   ENDCASE

   ; check dpr_data structure for read failures
   IF SIZE(dpr_data, /TYPE) NE 8 THEN $
     message, "Error reading data from: "+dpr_file_read $
   ELSE PRINT, "Extracting ", instrument_ID, " data fields from structure."
   print, ''

   ; get the group structures for the specified scantype, tags vary by swathname
   CASE STRUPCASE(DPR_scantype) OF
      'HS' : ptr_swath = dpr_data.HS
      'MS' : ptr_swath = dpr_data.MS
      'NS' : ptr_swath = dpr_data.NS
   ENDCASE

   ; extract DPR variables/arrays from struct pointers
   IF PTR_VALID(ptr_swath.PTR_DATASETS) THEN BEGIN
      prlons = (*ptr_swath.PTR_DATASETS).LONGITUDE
      prlats = (*ptr_swath.PTR_DATASETS).LATITUDE
      ptr_free, ptr_swath.PTR_DATASETS
   ENDIF ELSE message, "Invalid pointer to PTR_DATASETS."

   IF PTR_VALID(ptr_swath.PTR_CSF) THEN BEGIN
;      BB_hgt = (*ptr_swath.PTR_CSF).HEIGHTBB
;      bbstatus = (*ptr_swath.PTR_CSF).QUALITYBB       ; got to convert to TRMM?
      typePrecip = (*ptr_swath.PTR_CSF).TYPEPRECIP    ; got to convert to TRMM?
   ENDIF ELSE message, "Invalid pointer to PTR_CSF."
   idxrntypedefined = WHERE(typePrecip GE 0, countrndef)
   IF countrndef GT 0 THEN typePrecip[idxrntypedefined] = $
      typePrecip[idxrntypedefined]/10000000L     ; truncate to TRMM 3-digit type

;   IF PTR_VALID(ptr_swath.PTR_DSD) THEN BEGIN
;   ENDIF ELSE message, "Invalid pointer to PTR_DSD."

   IF PTR_VALID(ptr_swath.PTR_FLG) THEN BEGIN
      dataQuality = (*ptr_swath.PTR_FLG).QUALITYDATA
   ENDIF ELSE message, "Invalid pointer to PTR_FLG."

   IF PTR_VALID(ptr_swath.PTR_PRE) THEN BEGIN
      dbz_meas = (*ptr_swath.PTR_PRE).ZFACTORMEASURED
;      binRealSurface = (*ptr_swath.PTR_PRE).BINREALSURFACE
;      binClutterFreeBottom = (*ptr_swath.PTR_PRE).binClutterFreeBottom
      landOceanFlag = (*ptr_swath.PTR_PRE).LANDSURFACETYPE
      flagPrecip = (*ptr_swath.PTR_PRE).FLAGPRECIP
;      localZenithAngle = (*ptr_swath.PTR_PRE).localZenithAngle
      ptr_free, ptr_swath.PTR_PRE
   ENDIF ELSE message, "Invalid pointer to PTR_PRE."

   IF PTR_VALID(ptr_swath.PTR_SLV) THEN BEGIN
;      dbz_corr = (*ptr_swath.PTR_SLV).ZFACTORCORRECTED
;      rain_corr = (*ptr_swath.PTR_SLV).PRECIPRATE
      precipRateSurface = (*ptr_swath.PTR_SLV).PRECIPRATEESURFACE
 ;     dpr_Nw = REFORM( (*ptr_swath.PTR_SLV).PARAMDSD[0,*,*,*] )
 ;     dpr_Dm = REFORM( (*ptr_swath.PTR_SLV).PARAMDSD[1,*,*,*] )
      ptr_free, ptr_swath.PTR_SLV
   ENDIF ELSE message, "Invalid pointer to PTR_SLV."

   IF PTR_VALID(ptr_swath.PTR_SRT) THEN BEGIN
   ENDIF ELSE message, "Invalid pointer to PTR_SRT."

   IF PTR_VALID(ptr_swath.PTR_VER) THEN BEGIN
   ENDIF ELSE message, "Invalid pointer to PTR_VER."

   ; free the remaining memory/pointers in data structure
   free_ptrs_in_struct, dpr_data ;, /ver


;   dataflags_pr = get_geo_match_nc_struct( 'fields' )
   idxcheck = WHERE(precipRateSurface GT 0.0)
   if idxcheck[0] NE -1 THEN dataflags.have_precipRateSurface = 1
   idxcheck = WHERE(typePrecip GT 0)
   if idxcheck[0] NE -1 THEN dataflags.have_typePrecip = 1
   idxcheck = WHERE(flagPrecip GE 0)
   if idxcheck[0] NE -1 THEN dataflags.have_flagPrecip = 1

   ; compute PR footprint cartesian coordinates, in km
   pr_xy = MAP_PROJ_FORWARD(prLons, prLats, MAP=mymap) / 1000.

; read 2BDPRGMI rainrate field
; The following test allows PR processing to proceed without the
; 2B-31 data file being available.

   havefile2BDPRGMI = 1
   IF N_ELEMENTS(dprgmifile) NE 1 OR STRUPCASE(DPR_scantype) EQ 'HS' THEN BEGIN
      PRINT, ""
      PRINT, "No 2BDPRGMI match, skipping 2BDPRGMI processing for orbit ", orbit
      PRINT, ""
      havefile2BDPRGMI = 0
   ENDIF ELSE BEGIN
      data_COMB = read_2bcmb_hdf5( dprgmifile, SCAN=DPR_scantype)
      IF SIZE(data_COMB, /TYPE) NE 8 THEN BEGIN
         PRINT, ""
         PRINT, "ERROR reading fields from ", file_2bcmb
         PRINT, "Skipping 2BCMB processing for orbit = ", orbit
         PRINT, ""
         havefile2BDPRGMI = 0
      ENDIF ELSE BEGIN
        ; get the group structure for the specified scantype, tags vary by swath
        CASE STRUPCASE(DPR_scantype) OF
          'HS' : message, "Logic error, how did we get here?"
          'MS' : ptr_swath_COMB = data_COMB.MS
          'NS' : ptr_swath_COMB = data_COMB.NS
        ENDCASE
         PRINT, "Extracting 2B-DPRGMI data fields from structure."
         print, ''
         IF PTR_VALID(ptr_swath_COMB.PTR_DATASETS) THEN BEGIN
            lat_COMB = (*ptr_swath_COMB.PTR_DATASETS).LATITUDE
;            rain_COMB = (*ptr_swath_COMB.PTR_DATASETS).PRECIPTOTRATE
            surfRain_2BDPRGMI = (*ptr_swath_COMB.PTR_DATASETS).SURFPRECIPTOTRATE
            ; free the memory/pointers in data structure
            free_ptrs_in_struct, data_COMB ;, /ver
         ENDIF ELSE message, "Invalid pointer to '"+DPR_scantype+"' group."
         
         ; verify that we are looking at the same subset of scans
         ; (size-wise, anyway) between the DPR and 2bcmb product
         IF N_ELEMENTS(prlats) NE N_ELEMENTS(lat_COMB) THEN BEGIN
            PRINT, ""
            PRINT, "Mismatch between #scans in ", dprgmifile, " and ", $
                   dpr_file_read
            PRINT, "Skipping 2BCMB processing for orbit = ", orbit
            PRINT, ""
            havefile2BDPRGMI = 0
         ENDIF ELSE BEGIN
           ; determine whether there are any rainy combined footprints and
           ; set data flag accordingly
            idxcheck = WHERE(surfRain_2BDPRGMI NE 0)
            if idxcheck[0] NE -1 THEN dataflags.have_surfRain_2BDPRGMI = 1
         ENDELSE
      ENDELSE
   ENDELSE

; find PR footprints in rough range of GMI footprints, based on lat/lon
; -- restrict ourselves to only those GMI rays covering the PR swath,
;    nominally rays between 76 and 130.  Give ourselves 2-3 footprints of slop
tmiIdx2do = tmi_master_idx[74:132,*]
n_tmi_feet2do = N_ELEMENTS(tmiIdx2do)

ntmimatchrough = 0L
ntmimatchtrue = 0L
maxPRinRadius = 0
roughlat = (radius*1.5)/111.1
roughlon = roughlat*1.3

for itmifoot2do = 0L, n_tmi_feet2do-1 do begin
   itmifoot = tmiIdx2do[itmifoot2do]
   tmifootlat = gmiLats[itmifoot]
   tmifootlon = gmiLons[itmifoot]
   tmifootxy = tmi_xy[*,itmifoot]
   n_non_zero = 0                   ; number of non-zero PR values in average

   ; do the rough distance check based on Delta lat and lon
   idxrough = WHERE( ( ABS(prLats-tmifootlat) LT roughlat ) $
                 AND ( ABS(prLons-tmifootlon) LT roughlon ), countpr )
   if countpr GT 0 then begin
      ntmimatchrough++
;      print, "GMI Lat, Lon: ", tmifootlat, tmifootlon
;      print, "PR, PR Lat, Lon: ", countpr, prLats[idxrough], prLons[idxrough]
      ; compute accurate PR-GMI footprint distances for these of PR footprints
      truedist = REFORM( SQRT( (tmifootxy[0]-pr_xy[0, idxrough])^2 + $
                               (tmifootxy[1]-pr_xy[1, idxrough])^2 ) )
;      print, "GMI-PR range: ", truedist
;      print, ''
      idxtruetmp = WHERE( truedist LE radius, counttrue )
      IF counttrue GT 0 THEN BEGIN
        ; increment count of GMI footprints with PR mapped to them
         ntmimatchtrue++
        ; PR indices mapped to this GMI footprint
         idxprtrue = idxrough[idxtruetmp]

         PRinRadius2GMI[itmifoot] = counttrue
        ; do averages of DPR and 2BDPRGMI rain rate and non-zero count
         PRsfcRainByGMI[itmifoot] = $
            compute_average_and_n( precipRateSurface[idxprtrue], $
                                   n_non_zero, /NEGSTOZERO )
         PRcountSfcRainByGMI[itmifoot] = n_non_zero

         IF havefile2BDPRGMI EQ 1 THEN BEGIN
            PRsfcRain2BDPRGMIByGMI[itmifoot] = $
               compute_average_and_n(surfRain_2BDPRGMI[idxprtrue], n_non_zero, $
                                     /NEGSTOZERO)
            PRcountSfc2BDPRGMIRainByGMI[itmifoot] = n_non_zero
         ENDIF

        ; number of PR footprints of rain type Convective
         idxPRconv = WHERE( typePrecip[idxprtrue] EQ 2, counttemp)
         PRcountRainConv[itmifoot] = counttemp

        ; number of PR footprints of flagPrecip = 1 (Precipitation indicated)
         idxPRrainy = WHERE( flagPrecip[idxprtrue] EQ 1, counttemp)
         PRcountflagPrecipPrecipitation[itmifoot] = counttemp

;         print, "GMI-PR range <= ", radiusStr, " km: ", counttrue, $
;                truedist[idxtruetmp]
;         print, ''
         IF counttrue GT maxPRinRadius THEN maxPRinRadius = counttrue
         IF counttrue GT npertmiray[raytmi[itmifoot]] $
         THEN npertmiray[raytmi[itmifoot]] = counttrue
;         print, "GMI Ray, counttrue: ", raytmi[itmifoot], counttrue
;         npertmiray[raytmi[itmifoot]] = npertmiray[raytmi[itmifoot]] + counttrue
      ENDIF
   endif
endfor

print, "Max. PR footprints in ", radiusStr, " km: ", maxPRinRadius
print, "PR footprints per GMI ray: ", npertmiray

idxwithpr=WHERE(npertmiray GT 0)
idxmaxpr=MAX(idxwithpr, min=idxminpr)
print, 'GMI start/end rays with PR coverage:', idxminpr, idxmaxpr

; determine whether we have any PR/GMI overlaps in dataset, only create netCDF
; if there is overlap data to write and netCDF output is specified

idxwithpr=WHERE(PRinRadius2GMI GT 0, countwithin)
IF countwithin GT 0 THEN BEGIN
   mintmi = MIN(scantmi[idxwithpr], MAX=maxtmi)
   print, 'GMI start/end scan with PR coverage:', mintmi, maxtmi
   IF do_nc THEN BEGIN
      ; determine the overlap begin/end in terms of GMI scans, already have
      ; first and last GMI rays in overlap region
      ncscans = (maxtmi-mintmi)+1
      ncrays = (idxmaxpr-idxminpr)+1

     ; set up the output array of GMI and DPR filenames for netCDF file
      gmidprfiles = [gprofgmifile, dprfile, dprgmifile]
      ; create a netCDF file to hold the overlappiing matchup data
      ncfile = gen_gmi_dpr_orbit_match_netcdf( ncfile_out, ncscans, ncrays, $
                                               radius, centerLat, centerLon, $
                                               PPS_vers_str, DPR_scantype, $
                                               gmidprfiles, $
                                               GEO_MATCH_VERS=geo_match_vers )
      IF ( ncfile EQ "NoGeoMatchFile" ) THEN $
         message, "Error in creating output netCDF file "+ncfile_out

      ; Open the netCDF file for writing
      ncid = NCDF_OPEN( ncfile, /WRITE )

      ; Write the scalar values to the netCDF file
;      NCDF_VARPUT, ncid, 'tmi_rain_min', 0.01

      ; write the overlap-subsetted geospatial arrays
      NCDF_VARPUT, ncid, 'xCorners', $
           xCornersGMI[*, idxminpr:idxmaxpr, mintmi:maxtmi]
      NCDF_VARPUT, ncid, 'yCorners', $
           yCornersGMI[*, idxminpr:idxmaxpr, mintmi:maxtmi]
      NCDF_VARPUT, ncid, 'GMIlatitude', $
           gmiLats[idxminpr:idxmaxpr, mintmi:maxtmi]
      NCDF_VARPUT, ncid, 'GMIlongitude', $
           gmiLons[idxminpr:idxmaxpr, mintmi:maxtmi]

      ; write the overlap-subsetted science and GMIrayIndex arrays,
      ; and data field existence flags

      NCDF_VARPUT, ncid, 'surfaceType', $
           surfaceType[idxminpr:idxmaxpr, mintmi:maxtmi]
      NCDF_VARPUT, ncid, 'have_surfaceType',  dataflags.have_surfaceType

      NCDF_VARPUT, ncid, 'surfacePrecipitation', $
           surfacePrecipitation[idxminpr:idxmaxpr, mintmi:maxtmi]
      NCDF_VARPUT, ncid, 'have_surfacePrecipitation',  $
           dataflags.have_surfacePrecipitation

      NCDF_VARPUT, ncid, 'pixelStatus', $
           pixelStatus[idxminpr:idxmaxpr, mintmi:maxtmi]
      NCDF_VARPUT, ncid, 'have_pixelStatus', dataflags.have_pixelStatus

      NCDF_VARPUT, ncid, 'PoP', PoP[idxminpr:idxmaxpr, mintmi:maxtmi]
      NCDF_VARPUT, ncid, 'have_PoP', dataflags.have_PoP

      NCDF_VARPUT, ncid, 'GMIrayIndex', $
           tmi_master_idx[idxminpr:idxmaxpr, mintmi:maxtmi]

      NCDF_VARPUT, ncid, 'precipRateSurface', $
           PRsfcRainByGMI[idxminpr:idxmaxpr, mintmi:maxtmi]
      NCDF_VARPUT, ncid, 'have_precipRateSurface', $
           dataflags.have_precipRateSurface

      NCDF_VARPUT, ncid, 'surfRain_2BDPRGMI', $
           PRsfcRain2BDPRGMIByGMI[idxminpr:idxmaxpr, mintmi:maxtmi]
      NCDF_VARPUT, ncid, 'have_surfRain_2BDPRGMI', $
           dataflags.have_surfRain_2BDPRGMI

      NCDF_VARPUT, ncid, 'numPRinRadius', $
           PRinRadius2GMI[idxminpr:idxmaxpr, mintmi:maxtmi]
      NCDF_VARPUT, ncid, 'numPRsfcRain', $
           PRcountSfcRainByGMI[idxminpr:idxmaxpr, mintmi:maxtmi]
      NCDF_VARPUT, ncid, 'numPRsfcRainCom', $
           PRcountSfc2BDPRGMIRainByGMI[idxminpr:idxmaxpr, mintmi:maxtmi]

      NCDF_VARPUT, ncid, 'numConvectiveType', $
           PRcountRainConv[idxminpr:idxmaxpr, mintmi:maxtmi]
      NCDF_VARPUT, ncid, 'have_numConvectiveType', dataflags.have_typePrecip

      NCDF_VARPUT, ncid, 'numPRrainy', $
           PRcountflagPrecipPrecipitation[idxminpr:idxmaxpr, mintmi:maxtmi]
      NCDF_VARPUT, ncid, 'have_numPRrainy', dataflags.have_flagPrecip

      NCDF_CLOSE, ncid

;      command = 'ls -al '+ncfile_out
;      spawn, command
      command = "gzip -v " + ncfile
      spawn, command
   ENDIF
ENDIF ELSE BEGIN
   mintmi = -1
   maxtmi = -1
   print, ''
   print, "****************************************"
   print, "* No GMI footprints are matched by PR! *"
   print, "****************************************"
   print, ''
ENDELSE

; define and populate data structure with the full matchup arrays, no subsetting
datastruc = {   orbit : orbit, $
              version : PPS_vers_str, $
               subset : subset, $
              tmirain : surfacePrecipitation, $
                numpr : PRinRadius2GMI, $
               prrain : PRsfcRainByGMI, $
              numprrn : PRcountSfcRainByGMI, $
              comrain : PRsfcRain2BDPRGMIByGMI, $
             numcomrn : PRcountSfc2BDPRGMIRainByGMI, $
            numprconv : PRcountRainConv, $
              min_ray : idxminpr, $
              max_ray : idxmaxpr, $
             min_scan : mintmi, $
             max_scan : maxtmi, $
           center_lat : centerLat, $
           center_lon : centerLon, $
             xcorners : xCornersGMI, $
             ycorners : yCornersGMI }

; return the structure to the caller
return, datastruc
end
