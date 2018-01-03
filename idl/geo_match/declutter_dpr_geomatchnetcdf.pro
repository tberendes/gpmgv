;===============================================================================
;+
; Copyright © 2015, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; declutter_dpr_geomatchnetcdf.pro           Morris/SAIC/GPM_GV      June 2015
;
; DESCRIPTION
; -----------
; Program to test method to remove clutter bins from 3-D bin-averaged variables 
; in an existing GRtoDPR netcdf file using a custom clutter filter module.  A
; copy is made of the original netCDF file with a ".declutter" field added to
; the file name, and new clutter-filtered results are written to the file copy
; in the same directory as the original file.
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;===============================================================================

; MODULE #3

; extract the needed path instrument/product/version/subset/year/month/day from
; a 2A GPM filename, e.g., compose path = '/CONUS/2014/04/19' from
; 2A-CS-CONUS.TRMM.PR.2A25.20140419-S113024-E114401.093556.7.HDF.gz

  FUNCTION parse_2a_filename, origFileName

  parsed = STRSPLIT(origFileName, '.', /EXTRACT)
  parsed2 = STRSPLIT(parsed[0], '-', /EXTRACT)
  subset = parsed2[2]
  instrument=parsed[2]
  product='2A'+instrument
  version = parsed[6]
  yyyymmdd = STRMID(parsed[4],0,4)+'/'+STRMID(parsed[4],4,2)+'/'+STRMID(parsed[4],6,2)
  path = instrument+'/'+product+'/'+version+'/'+subset+'/'+yyyymmdd

  return, path

  end

;===============================================================================

pro declutter_dpr_z, mygeomatchfile, PLOT_PPIs=plot_PPIs_in, VERBOSE=verbose

@dpr_geo_match_nc_structs.inc

; "Include" file for DATA_PRESENT, NO_DATA_PRESENT
@grid_def.inc
; "Include" files for constants, names, paths, etc.
@environs.inc   ; for file prefixes, netCDF file definition version
@dpr_params.inc  ; for the type-specific fill values

plot_PPIs=KEYWORD_SET(plot_PPIs_in)
verbose=KEYWORD_SET(verbose)

idxncvers=STRPOS(mygeomatchfile, '1_1')
IF idxncvers EQ -1 THEN message, "File "+mygeomatchfile+" not named version 1_1."

idxncvers=STRPOS(mygeomatchfile, '.nc')
IF idxncvers EQ -1 THEN message, "File "+mygeomatchfile+" not type .nc"
outfile = STRMID(mygeomatchfile,0,idxncvers)+'.declutter.nc'
;print, '' & print, "Infile: ", mygeomatchfile
print, '' & print, "Outfile: ", outfile

;IF FILE_TEST(outfile+'.gz', /NOEXPAND_PATH) EQ 1 THEN BEGIN
;   print, "Outfile already exists: ", outfile & print, ''
;   GOTO, regularExit
;ENDIF

   ; tally number of reflectivity bins below this dBZ value in DPR Z averages
    IF N_ELEMENTS(dpr_dbz_min) NE 1 THEN BEGIN
       dpr_dbz_min = 18.0
       PRINT, "Assigning default value of 18 dBZ to DPR_DBZ_MIN."
    ENDIF
   ; tally number of rain rate bins (mm/h) below this value in DPR rr averages
    IF N_ELEMENTS(dpr_rain_min) NE 1 THEN BEGIN
       DPR_RAIN_MIN = 0.01
       PRINT, "Assigning default value of 0.01 mm/h to DPR_RAIN_MIN."
    ENDIF

   DO_RAIN_CORR = 1   ; set flag to do 3-D rain_corr processing by default

; open the original netCDF file and read the metadata and pr_index field
cpstatus = uncomp_file( mygeomatchfile, myfile )
if(cpstatus eq 'OK') then begin
   status = 1   ; init to FAILED
   mygeometa={ dpr_geo_match_meta }
   mysweeps={ gr_sweep_meta }
   mysite={ gr_site_meta }
   myflags={ dpr_gr_field_flags }
   myfiles={ dpr_gr_input_files }

   CATCH, error
   IF error EQ 0 THEN BEGIN
      status = read_dpr_geo_match_netcdf( myfile, matchupmeta=mygeometa, $
         sweepsmeta=mysweeps, sitemeta=mysite, fieldflags=myflags, $
         filesmeta=myfiles )
   ENDIF ELSE BEGIN
      help,!error_state,/st
      Catch, /Cancel
      message, 'err='+STRING(error)+", "+!error_state.msg, /INFO
      status=1   ;return, -1
   ENDELSE
   Catch, /Cancel

   if ( status NE 0 ) THEN BEGIN
      print, "Stopping, will skip this file, enter .CONTINUE to proceed."
;      STOP
      GOTO, errorExit    ; open/read error
   endif

  ; create data field arrays of correct dimensions and read data fields
   nfp = mygeometa.num_footprints
   nswp = mygeometa.num_sweeps
   DPR_scantype = mygeometa.DPR_scantype
   siteElev = mysite.site_elev
print, "siteElev: ", siteelev

  ; read the fields needed to recreate clutter-filtered DPR 3-D fields
   prexp=intarr(nfp,nswp)
   zrawrej=intarr(nfp,nswp)
   zcorrej=intarr(nfp,nswp)
   rainrej=intarr(nfp,nswp)
   dpr_dm_rej=intarr(nfp,nswp)
   dpr_nw_rej=intarr(nfp,nswp)
   zraw=fltarr(nfp,nswp)           ; DPR variables
   zcor=fltarr(nfp,nswp)
   rain3=fltarr(nfp,nswp)
   dpr_Dm=fltarr(nfp,nswp)
   dpr_Nw=fltarr(nfp,nswp)
   clutterStatus=intarr(nfp)       ; derived variables
   top=fltarr(nfp,nswp)
   botm=fltarr(nfp,nswp)
   xcorners=fltarr(4,nfp,nswp)
   ycorners=fltarr(4,nfp,nswp)
   pr_index=lonarr(nfp)

   CATCH, error
   IF error EQ 0 THEN BEGIN
     status = read_dpr_geo_match_netcdf( myfile, pridx_long=pr_index, $
               zrawreject_int=zrawrej, zcorreject_int=zcorrej, $
               rainreject_int=rainrej, dpr_dm_reject_int=dpr_dm_rej, $
               dpr_nw_reject_int=dpr_nw_rej, dprexpect_int=prexp, $
               dbzraw=zraw, dbzcor=ZCor, rain3d=rain3, $
               DmDPRmean = DPR_Dm, NwDPRmean = DPR_Nw, $
               topHeight=top, bottomHeight=botm, xCorners=xCorners, $
               yCorners=yCorners, clutterStatus_int=clutterStatus)
   ENDIF ELSE BEGIN
      help,!error_state,/st
      Catch, /Cancel
      message, 'err='+STRING(error)+", "+!error_state.msg, /INFO
      status=1   ;return, -1
   ENDELSE
   Catch, /Cancel

   if ( status NE 0 ) THEN BEGIN
      print, "Stopping, will skip this file, enter .CONTINUE to proceed."
;      STOP
      GOTO, errorExit    ; open/read error
   endif

  ; make copies of the clutter-affected DPR 3D variables
  ; in polar2dpr name convention
   tocdf_meas_dbz = zraw
   tocdf_corr_dbz = zcor
   tocdf_corr_rain = rain3
   tocdf_dm = dpr_Dm
   tocdf_nw = dpr_Nw
   tocdf_meas_z_rejected = zrawrej
   tocdf_corr_z_rejected = zcorrej
   tocdf_corr_r_rejected = rainrej
;   IF ( myflags.have_paramdsd ) THEN BEGIN
      tocdf_dpr_dm_rejected = dpr_dm_rej
      tocdf_dpr_nw_rejected = dpr_nw_rej
;   ENDIF
   tocdf_dpr_expected = prexp
   tocdf_clutterStatus = clutterStatus

   tocdf_meas_dbz[*,*] = Z_MISSING
   tocdf_corr_dbz[*,*] = Z_MISSING
   tocdf_corr_rain[*,*] = Z_MISSING
   tocdf_dm[*,*] = Z_MISSING
   tocdf_nw[*,*] = Z_MISSING

  ; for plotting PPIs only, don't get changed
   tocdf_x_poly = TEMPORARY(xCorners)
   tocdf_y_poly = TEMPORARY(yCorners)

   ; put the file names in the filesmeta struct into a searchable array
   dprFileMatch=[myfiles.FILE_2ADPR, myfiles.FILE_2AKA, myfiles.FILE_2AKU ]

  ; find the matchup input filename with the expected non-missing pattern
  ; and, for now, set a default instrumentID and scan type
   nfoundDPR=0
   idxDPR = WHERE(STRMATCH(dprFileMatch,'2A*.GPM.DPR.*') EQ 1, countDPR)
   if countDPR EQ 1 THEN BEGIN
      origFileDPRName = dprFileMatch[idxDPR]
      Instrument_ID='DPR'
      nfoundDPR++
   ENDIF ELSE origFileDPRName='no_2ADPR_file'

   idxKU = WHERE(STRMATCH(dprFileMatch,'2A*.GPM.Ku.*') EQ 1, countKU)
   if countKU EQ 1 THEN BEGIN
       origFileKuName = dprFileMatch[idxKU]
      Instrument_ID='Ku'
      nfoundDPR++
   ENDIF ELSE origFileKuName='no_2AKU_file'

   idxKA = WHERE(STRMATCH(dprFileMatch,'2A*.GPM.Ka.*') EQ 1, countKA)
   if countKA EQ 1 THEN BEGIN
       origFileKaName = dprFileMatch[idxKA]
       Instrument_ID='Ka'
      nfoundDPR++
   ENDIF ELSE origFileKaName='no_2AKA_file'

   IF ( origFileKaName EQ 'no_2AKA_file' AND $
        origFileKuName EQ 'no_2AKU_file' AND $
        origFileDPRName EQ 'no_2ADPR_file' ) THEN BEGIN
      PRINT, ""
      message, "ERROR finding a 2A-DPR, 2A-KA , or 2A-KU file name",/INFO
      PRINT, "Looked at: ", dprFileMatch
      goto, errorExit
   ENDIF

   IF nfoundDPR NE 1 THEN BEGIN
      show_orig=0
      PRINT, ""
;      message, "ERROR finding just one 2A-DPR, 2A-KA , or 2A-KU file name"
   ENDIF

   ; it is a GPM-era filename, get the varying path components and prepend
   ; the non-varying parts of the full path

   CASE Instrument_ID OF
      'DPR' : BEGIN
                 path_tail = parse_2a_filename( origFileDPRName )
                 file_2adpr = GPMDATA_ROOT+"/"+path_tail+'/'+origFileDPRName
                 IF FILE_TEST(file_2adpr) THEN print, "Reading DPR from ",file_2adpr $
                 ELSE BEGIN
                    print, "Did not find DPR file: ", file_2adpr
                    goto, errorExit
                 ENDELSE
              END
       'Ku' : BEGIN
                 path_tail = parse_2a_filename( origFileKuName )
                 file_2aku = GPMDATA_ROOT+"/"+path_tail+"/"+origFileKuName
                 IF FILE_TEST(file_2aku) THEN print, "Reading DPR from ",file_2aku $
                 ELSE BEGIN
                    print, "Did not find DPR file: ", file_2aku
                    goto, errorExit
                 ENDELSE
              END
       'Ka' : BEGIN
                 path_tail = parse_2a_filename( origFileKaName )
                 file_2aka = GPMDATA_ROOT+"/"+path_tail+"/"+origFileKaName
                 IF FILE_TEST(file_2aka) THEN print, "Reading DPR from ",file_2aka $
                 ELSE BEGIN
                    print, "Did not find DPR file: ", file_2aka
                    goto, errorExit
                 ENDELSE
              END
   ENDCASE

   ; check Instrument_ID and DPR_scantype consistency and read data if OK
   CASE STRUPCASE(Instrument_ID) OF
       'KA' : BEGIN
                 ; 2AKA has only HS and MS scan/swath types
                 CASE STRUPCASE(DPR_scantype) OF
                    'HS' : BEGIN
                              RAYSPERSCAN = RAYSPERSCAN_HS
                              GATE_SPACE = BIN_SPACE_HS
                              ELLIPSOID_BIN_DPR = ELLIPSOID_BIN_HS
                           END
                    'MS' : BEGIN
                              RAYSPERSCAN = RAYSPERSCAN_MS
                              GATE_SPACE = BIN_SPACE_NS_MS
                              ELLIPSOID_BIN_DPR = ELLIPSOID_BIN_NS_MS
                           END
                    ELSE : message,"Illegal scan type '"+DPR_scantype+"' for KA"
                 ENDCASE
                 dpr_data = read_2akaku_hdf5(file_2aka, SCAN=DPR_scantype)
                 dpr_file_read = origFileKaName
              END
       'KU' : BEGIN
                 ; 2AKU has only NS scan/swath type
                 CASE STRUPCASE(DPR_scantype) OF
                    'NS' : BEGIN
                              dpr_data = read_2akaku_hdf5(file_2aku, $
                                         SCAN=DPR_scantype)
                              dpr_file_read = origFileKuName
                              RAYSPERSCAN = RAYSPERSCAN_NS
                              GATE_SPACE = BIN_SPACE_NS_MS
                              ELLIPSOID_BIN_DPR = ELLIPSOID_BIN_NS_MS
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
                              ELLIPSOID_BIN_DPR = ELLIPSOID_BIN_HS
                           END
                    'MS' : BEGIN
                              RAYSPERSCAN = RAYSPERSCAN_MS
                              GATE_SPACE = BIN_SPACE_NS_MS
                              ELLIPSOID_BIN_DPR = ELLIPSOID_BIN_NS_MS
                              DO_RAIN_CORR = 0   ; set flag to skip 3-D rainrate
                           END
                    'NS' : BEGIN
                              RAYSPERSCAN = RAYSPERSCAN_NS
                              GATE_SPACE = BIN_SPACE_NS_MS
                              ELLIPSOID_BIN_DPR = ELLIPSOID_BIN_NS_MS
                           END
                    ELSE : message, "Illegal scan type '"+DPR_scantype+"'"
                 ENDCASE
                 dpr_data = read_2adpr_hdf5(file_2adpr, SCAN=DPR_scantype)
                 dpr_file_read = origFileDPRName
              END
   ENDCASE

   ; check dpr_data structure for read failures
   IF SIZE(dpr_data, /TYPE) NE 8 THEN $
     message, "Error reading data from: "+dpr_file_read

endif else begin
   goto, errorExit                            ; copy error
endelse

   ; get the group structures for the specified scantype, tags vary by swathname
   CASE STRUPCASE(DPR_scantype) OF
      'HS' : ptr_swath = dpr_data.HS
      'MS' : ptr_swath = dpr_data.MS
      'NS' : ptr_swath = dpr_data.NS
   ENDCASE

   IF PTR_VALID(ptr_swath.PTR_PRE) THEN BEGIN
      dbz_meas = (*ptr_swath.PTR_PRE).ZFACTORMEASURED
      binRealSurface = (*ptr_swath.PTR_PRE).BINREALSURFACE
      binClutterFreeBottom = (*ptr_swath.PTR_PRE).binClutterFreeBottom
      localZenithAngle = (*ptr_swath.PTR_PRE).localZenithAngle
      ptr_free, ptr_swath.PTR_PRE
   ENDIF ELSE message, "Invalid pointer to PTR_PRE."

   IF PTR_VALID(ptr_swath.PTR_SLV) THEN BEGIN
      dbz_corr = (*ptr_swath.PTR_SLV).ZFACTORCORRECTED
      rain_corr = (*ptr_swath.PTR_SLV).PRECIPRATE
      ; MS swath in 2A-DPR product does not have paramDSD, deal with it here
      ; - if there is no paramDSD its structure element is the string "UNDEFINED"
      type_paramdsd = SIZE( (*ptr_swath.PTR_SLV).PARAMDSD, /TYPE )
      IF type_paramdsd EQ 7 THEN BEGIN
         have_paramdsd = 0
      ENDIF ELSE BEGIN
         have_paramdsd = 1
         dpr_Nw = REFORM( (*ptr_swath.PTR_SLV).PARAMDSD[0,*,*,*] )
         dpr_Dm = REFORM( (*ptr_swath.PTR_SLV).PARAMDSD[1,*,*,*] )
      ENDELSE
      ptr_free, ptr_swath.PTR_SLV
   ENDIF ELSE message, "Invalid pointer to PTR_SLV."

   ; free the remaining memory/pointers in data structure
   free_ptrs_in_struct, dpr_data ;, /ver

   ; precompute the reuseable ray angle trig variables for parallax -- in GPM,
   ; we have the local zenith angle for every ray/scan (i.e., footprint)
   cos_inc_angle = COS( 3.1415926D * localZenithAngle / 180. )

; get array indices of the non-bogus (i.e., "actual") PR footprints to cover the
; possibility that the matchup was performed with "MARK_EDGES" turned on.
idxpractual = where(pr_index GE 0L, countactual)
if (countactual EQ 0) then begin
   print, "No non-bogus data points, quitting case."
   status = 1
   goto, errorExit
endif

; get the subset of pr_index values for actual PR rays in the matchup
pr_idx_actual = pr_index[idxpractual]

; expand these DPR master indices into their scan,ray coordinates
rayscan = ARRAY_INDICES( binRealSurface, pr_idx_actual )
raydpr = REFORM(rayscan[0,*]) & scandpr = REFORM(rayscan[1,*])

; define an array to flag clutter gates and call flag_clutter to assign values
clutterFlag = BYTARR(SIZE(dbz_corr, /DIMENSIONS))
flag_clutter, scandpr, raydpr, dbz_corr, clutterFlag, binClutterFreeBottom, $
              VERBOSE=verbose

; re-open the netCDF file copy in read/write mode

cdfid = NCDF_OPEN( myfile, /WRITE )
IF ( N_Elements(cdfid) EQ 0 ) THEN BEGIN
   print, ''
   print, "ERROR, file copy ", myfile, " is not a valid netCDF file!"
   print, ''
   status = 1
   goto, errorExit
ENDIF

; precompute cos(elev) for later repeated use
cos_elev_angle = COS( (mysweeps[*]).ELEVATIONANGLE * !DTOR )

FOR ielev = 0, nswp - 1 DO BEGIN
   print, ""
   print, "Elevation: ", (mysweeps[ielev]).ELEVATIONANGLE

      FOR jpr=0, countactual-1 DO BEGIN
        ; init output variables defined/set in loop/if
         writeMISSING = 1
         countGRpts = 0UL              ; # GR bins mapped to this DPR footprint
         dpr_gates_expected = 0UL      ; # DPR gates within the sweep vert. bounds
         n_meas_zgates_rejected = 0UL  ; # of above that are below DPR dBZ cutoff
         n_corr_zgates_rejected = 0UL  ; ditto, for corrected DPR Z
         n_corr_rgates_rejected = 0UL  ; # gates below DPR rainrate cutoff
         n_dpr_dm_gates_rejected = 0UL  ; # gates with missing Dm
         n_dpr_nw_gates_rejected = 0UL  ; # gates with missing Nw
         clutterStatus = 0UL           ; result of clutter proximity for volume

         dpr_index = pr_idx_actual[jpr]
        ; expand this DPR master index into its scan coordinates.  Use
        ;   BB_Hgt as the subscripted data array
         rayscan = ARRAY_INDICES( binRealSurface, dpr_index )
         raydpr = rayscan[0] & scandpr = rayscan[1]
dpr_echoes=0B
IF top[idxpractual[jpr],ielev] GT 0.0 THEN BEGIN
        ; determine whether the DPR ray has any bins above the dBZ threshold
        ; - look at corrected Z between 0.75 and 19.25 km, and
        ;   use the above-threshold bin counting in get_dpr_layer_average()
         topMeasGate = 0 & botmMeasGate = 0
         topCorrGate = 0 & botmCorrGate = 0
         topCorrGate = dpr_gate_num_for_height( 19.25, GATE_SPACE,  $
                          cos_inc_angle, raydpr, scandpr, binRealSurface )
         botmCorrGate = dpr_gate_num_for_height( 0.75, GATE_SPACE,  $
                           cos_inc_angle, raydpr, scandpr, binRealSurface )
         ;PRINT, "GATES AT 0.75 and 19.25 KM, and GATE_SPACE: ", $
         ;        botmCorrGate, topCorrGate, GATE_SPACE
         dbz_ray_avg = get_dpr_layer_average(topCorrGate, botmCorrGate,   $
                          scandpr, raydpr, dbz_corr, DBZSCALECORR, $
                          DPR_DBZ_MIN, numDPRgates )
         IF ( numDPRgates GT 0 ) THEN dpr_echoes=1B
ENDIF

         IF ( dpr_echoes NE 0B ) THEN BEGIN

               writeMissing = 0
              ; compute height above ellipsoid for computing DPR gates that
              ; intersect the GR beam boundaries.  Assume ellipsoid and geoid
              ; (MSL surface) are the same
               meantopMSL = top[idxpractual[jpr],ielev] + siteElev
               meanbotmMSL = botm[idxpractual[jpr],ielev] + siteElev

              ; make a copy of binRealSurface and set all values to the fixed
              ; bin number at the ellipsoid for the swath being processed.
               binEllipsoid = binRealSurface
               binEllipsoid[*,*] = ELLIPSOID_BIN_DPR

              ; find DPR reflectivity gate #s bounding the top/bottom heights
               topMeasGate = 0 & botmMeasGate = 0
               topCorrGate = 0 & botmCorrGate = 0
               topCorrGate = dpr_gate_num_for_height(meantopMSL, GATE_SPACE,  $
                             cos_inc_angle, raydpr, scandpr, binEllipsoid)
               topMeasGate=topCorrGate
               botmCorrGate = dpr_gate_num_for_height(meanbotmMSL, GATE_SPACE, $
                              cos_inc_angle, raydpr, scandpr, binEllipsoid)
               botmMeasGate=botmCorrGate

              ; number of DPR gates to be averaged in the vertical:
               dpr_gates_expected = botmCorrGate - topCorrGate + 1

              ; do layer averaging for 3-D DPR fields
               numDPRgates = 0
               clutterStatus = 0  ; get once for all 3 fields, same value applies
               dbz_corr_avg = get_dpr_layer_average(           $
                                    topCorrGate, botmCorrGate, $
                                    scandpr, raydpr, dbz_corr, $
                                    DBZSCALECORR, dpr_dbz_min, $
                                    numDPRgates, binClutterFreeBottom, $
                                    CLUTTERFLAG=clutterFlag, clutterStatus, /LOGAVG )
               n_corr_zgates_rejected = dpr_gates_expected - numDPRgates

               IF verbose GT 0 AND clutterStatus GE 10 $
                  THEN print, "Clutter found at level,ray,scan ", ielev, raydpr, scandpr

               numDPRgates = 0
               dbz_meas_avg = get_dpr_layer_average(           $
                                    topMeasGate, botmMeasGate, $
                                    scandpr, raydpr, dbz_meas, $
                                    DBZSCALEMEAS, dpr_dbz_min, $
                                    numDPRgates, binClutterFreeBottom, /LOGAVG )
               n_meas_zgates_rejected = dpr_gates_expected - numDPRgates

               IF DO_RAIN_CORR THEN BEGIN
                  numDPRgates = 0
                  rain_corr_avg = get_dpr_layer_average(           $
                                    topCorrGate, botmCorrGate,  $
                                    scandpr, raydpr, rain_corr, $
                                    RAINSCALE, dpr_rain_min, $
                                    numDPRgates, binClutterFreeBottom )
                  n_corr_rgates_rejected = dpr_gates_expected - numDPRgates
               ENDIF ELSE BEGIN
                  ; we have no rain_corr field for this instrument/swath
                  rain_corr_avg = Z_MISSING
                  n_corr_rgates_rejected = dpr_gates_expected
               ENDELSE

               IF ( have_paramdsd ) THEN BEGIN
                  numDPRgates = 0
                  dpr_dm_avg = get_dpr_layer_average(                   $
                                     topMeasGate, botmMeasGate,         $
                                     scandpr, raydpr, dpr_Dm, 1.0, 0.1, $
                                     numDPRgates, binClutterFreeBottom )
                  n_dpr_dm_gates_rejected = dpr_gates_expected - numDPRgates

                  numDPRgates = 0
                  dpr_nw_avg = get_dpr_layer_average(                   $
                                     topMeasGate, botmMeasGate,         $
                                     scandpr, raydpr, dpr_Nw, 1.0, 1.0, $
                                     numDPRgates, binClutterFreeBottom )
                  n_dpr_nw_gates_rejected = dpr_gates_expected - numDPRgates
               ENDIF
         ENDIF ELSE BEGIN          ; dpr_index GE 0 AND dpr_echoes[jpr] NE 0B
           ; case where no corr DPR gates in the ray are above dBZ threshold,
           ;   set the averages to the BELOW_THRESH special values
            IF ( dpr_index GE 0 AND dpr_echoes EQ 0B ) THEN BEGIN
               writeMissing = 0
               dbz_meas_avg = Z_BELOW_THRESH
               dbz_corr_avg = Z_BELOW_THRESH
               rain_corr_avg = SRAIN_BELOW_THRESH
               IF ( have_paramdsd ) THEN BEGIN
                  dpr_dm_avg = Z_BELOW_THRESH
                  dpr_nw_avg = Z_BELOW_THRESH
               ENDIF
               meantop = 0.0    ; should calculate something for this
               meanbotm = 0.0   ; ditto
            ENDIF
         ENDELSE          ; ELSE for dpr_echoes NE 0B

     ; =========================================================================
     ; WRITE COMPUTED AVERAGES AND METADATA TO OUTPUT ARRAYS FOR NETCDF

         IF ( writeMissing EQ 0 )  THEN BEGIN
         ; normal rainy footprint, write computed science variables
                  tocdf_meas_dbz[idxpractual[jpr],ielev] = dbz_meas_avg
                  tocdf_corr_dbz[idxpractual[jpr],ielev] = dbz_corr_avg
                  tocdf_corr_rain[idxpractual[jpr],ielev] = rain_corr_avg
                  IF ( have_paramdsd ) THEN BEGIN
                     tocdf_dm[idxpractual[jpr],ielev] = dpr_dm_avg
                     tocdf_nw[idxpractual[jpr],ielev] = dpr_nw_avg
                  ENDIF
         ENDIF ELSE BEGIN
                  tocdf_meas_dbz[idxpractual[jpr],ielev] = Z_MISSING
                  tocdf_corr_dbz[idxpractual[jpr],ielev] = Z_MISSING
                  tocdf_corr_rain[idxpractual[jpr],ielev] = Z_MISSING
                  tocdf_dm[idxpractual[jpr],ielev] = Z_MISSING
                  tocdf_nw[idxpractual[jpr],ielev] = Z_MISSING
         ENDELSE
         tocdf_meas_z_rejected[idxpractual[jpr],ielev] = UINT(n_meas_zgates_rejected)
         tocdf_corr_z_rejected[idxpractual[jpr],ielev] = UINT(n_corr_zgates_rejected)
         tocdf_corr_r_rejected[idxpractual[jpr],ielev] = UINT(n_corr_rgates_rejected)
         IF ( have_paramdsd ) THEN BEGIN
            tocdf_dpr_dm_rejected[idxpractual[jpr],ielev] = UINT(n_dpr_dm_gates_rejected)
            tocdf_dpr_nw_rejected[idxpractual[jpr],ielev] = UINT(n_dpr_nw_gates_rejected)
         ENDIF
         tocdf_dpr_expected[idxpractual[jpr],ielev] = UINT(dpr_gates_expected)
         tocdf_clutterStatus[idxpractual[jpr],ielev] = UINT(clutterStatus)
      ENDFOR  ; each DPR subarray point

    ; *********** OPTIONAL PPI PLOTTING FOR SWEEP **********
      IF keyword_set(plot_PPIs) THEN BEGIN
         titlepr = 'Orig. DPR at ' + mygeometa.ATIMENEARESTAPPROACH + ' UTC'
;         titlegv = siteID+', Elevation = ' + $
;                   STRING((mysweeps[ielev]).ELEVATIONANGLE,FORMAT='(f4.1)') $
;                +', '+ mysweeps[ielev]).ATIMESWEEPSTART
         titlegv = 'Declut. DPR at ' + mygeometa.ATIMENEARESTAPPROACH + ' UTC'
         titles = [titlepr, titlegv]

         plot_elevation_gv_to_pr_z, zcor, tocdf_corr_dbz, mysite.site_lat, $
            mysite.site_lon, tocdf_x_poly, tocdf_y_poly, nfp, ielev, TITLES=titles
         doodah=''
         PRINT, ''
         READ, doodah, PROMPT='Hit Return to do next level, Q to Quit PPI plots: '
         IF doodah EQ 'Q' OR doodah EQ 'q' THEN plot_ppis=0

       ; if restricting plot to the 'best' DPR and GR sample points
         ;plot_elevation_gv_to_pr_z, tocdf_corr_dbz*(tocdf_corr_z_rejected EQ 0), $
         ;   tocdf_gr_dbz*(tocdf_gr_dbz GE dpr_dbz_min)*(tocdf_gr_rejected EQ 0), $
         ;   sitelat, sitelon, tocdf_x_poly, tocdf_y_poly, numDPRrays, ielev, TITLES=titles

       ; to plot a full-res radar PPI for this elevation sweep:
         ;rsl_plotsweep_from_radar, radar, ELEVATION=elev_angle[ielev], $
         ;                          VOLUME_INDEX=z_vol_num, /NEW_WINDOW, MAXRANGE=200
         ;stop
      ENDIF

     ; =========================================================================

ENDFOR

   NCDF_VARPUT, cdfid, 'ZFactorMeasured', tocdf_meas_dbz         ; data
   NCDF_VARPUT, cdfid, 'ZFactorCorrected', tocdf_corr_dbz        ; data
   IF DO_RAIN_CORR THEN NCDF_VARPUT, cdfid, 'PrecipRate', tocdf_corr_rain             ; data
   IF ( have_paramdsd ) THEN BEGIN
       NCDF_VARPUT, cdfid, 'Dm', tocdf_dm
       NCDF_VARPUT, cdfid, 'Nw', tocdf_nw
   ENDIF
   NCDF_VARPUT, cdfid, 'n_dpr_meas_z_rejected', tocdf_meas_z_rejected
   NCDF_VARPUT, cdfid, 'n_dpr_corr_z_rejected', tocdf_corr_z_rejected
   IF DO_RAIN_CORR THEN NCDF_VARPUT, cdfid, 'n_dpr_corr_r_rejected', tocdf_corr_r_rejected
   IF ( have_paramdsd ) THEN BEGIN
      NCDF_VARPUT, cdfid, 'n_dpr_dm_rejected', tocdf_dpr_dm_rejected
      NCDF_VARPUT, cdfid, 'n_dpr_nw_rejected', tocdf_dpr_nw_rejected
   ENDIF
   NCDF_VARPUT, cdfid, 'n_dpr_expected', tocdf_dpr_expected
   NCDF_VARPUT, cdfid, 'clutterStatus', tocdf_clutterStatus

ncdf_close, cdfid

command = "mv -v "+myfile+' '+outfile
;command = "rm -v "+myfile
spawn, command
command2 = 'gzip -fv '+outfile
spawn, command2
print, "Updated geo-match file: ", mygeomatchfile
command3 = 'ls -al '+outfile+'*'
spawn, command3

GOTO, regularExit

errorExit:
  print, 'Cannot copy/unzip/read geo_match netCDF file: ', mygeomatchfile
  print, cpstatus
  command3 = "rm -v " + myfile
  spawn, command3
  stop

regularExit:
END

;===============================================================================

pro declutter_dpr_geomatchnetcdf, ncsitepath, PLOT_PPIs=plot_PPIs, $
                                  FIRSTORBIT=firstOrbit, VERBOSE=verbose

IF N_ELEMENTS(ncsitepath) EQ 1 THEN pathpr=ncsitepath+'*' $
ELSE message, "Must specify a complete path to the GRtoDPR files."

lastsite='NA'
lastorbitnum=0
lastncfile='NA'

prfiles = file_search(pathpr,COUNT=nf)
IF (nf LE 0) THEN BEGIN
   print, "" 
   print, "No files found for pattern = ", pathpr
   print, " -- Exiting."
   GOTO, errorExit
ENDIF

FOR fnum = 0, nf-1 DO BEGIN

   ncfilepr = prfiles(fnum)
   bname = file_basename( ncfilepr )
;   print, ''
   print, '--------------------------------------------------------------------'
;   print, ''

   parsed = strsplit(bname, '.', /EXTRACT)
   site = parsed[1]
   orbit = parsed[3]
   orbitnum=LONG(orbit)

; if minimum orbit number is specified, process newer orbits only
   IF N_ELEMENTS(firstOrbit) EQ 1 THEN BEGIN
      IF orbitnum LT firstOrbit THEN BEGIN
         print, "Skipping ", bname, " by orbit threshold."
         CONTINUE
      ENDIF
   ENDIF

  ; exclude the matchup datasets with replacement JAXA 2A files, algorithm won't
  ; find/handle their matching 2A files
   IF bname NE 'GRtoDPR.KTYX.140523.1327.V03B.KU.NS.1_1.nc.gz' and $
      bname NE 'GRtoDPR.KCAE.140523.1327.V03B.KU.NS.1_1.nc.gz'  and $
      bname NE 'GRtoDPR.KGSP.140523.1327.V03B.KU.NS.1_1.nc.gz' THEN BEGIN
      print, "Do GeoMatch netCDF file: ", bname

      declutter_dpr_z, ncfilepr, PLOT_PPIs=plot_PPIs, VERBOSE=verbose

   ENDIF ELSE print, "Skipping file: ", bname

endfor

errorExit:
end
