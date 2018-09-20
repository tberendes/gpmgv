;===============================================================================
;+
; Copyright © 2018, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; append_dsd_phase_geomatchnetcdf.pro           Morris/SAIC/GPM_GV      Jun 2018
;
; DESCRIPTION
; -----------
; Program to add new volume-match DPR DSD phase analysis variables to an
; existing GRtoDPR netcdf file to support Ali Tokay's work.  The phase variable
; is NOT present in the 2ADPR MS scan type, so an error will result if this
; type of matchup netCDF file is attempted.
;
; Phase in this context is the single value per DPR ray at the position of the
; lowest clutter-free bin, extracted from the DSD group 'phase' variable.  The
; height of this DPR range gate above the surface will also be included.  We
; will also read the 2-D variable 'phaseNearSurface' from the SLV group and add
; it to the netCDF file.
;
; EMAIL QUESTIONS OR COMMENTS AT:
;       https://pmm.nasa.gov/contact
;-
;===============================================================================

; extract the needed path instrument/product/version/subset/year/month/day from
; a 2A GPM filename, e.g., compose path = '/CONUS/2014/04/19' from
; 2A-CS-CONUS.TRMM.PR.2A25.20140419-S113024-E114401.093556.7.HDF.gz

  FUNCTION parse_2a_filename, origFileName, PRODUCT=product2a

  parsed = STRSPLIT(origFileName, '.', /EXTRACT)
  parsed2 = STRSPLIT(parsed[0], '-', /EXTRACT)
  subset = parsed2[2]
  instrument=parsed[2]
  product='2A'+instrument
  version = parsed[6]
IF version EQ 'ITE049' THEN version = 'V4ITE'
  yyyymmdd = STRMID(parsed[4],0,4)+'/'+STRMID(parsed[4],4,2)+'/'+STRMID(parsed[4],6,2)
  path = instrument+'/'+product+'/'+version+'/'+subset+'/'+yyyymmdd

  IF N_ELEMENTS(product2a) NE 0 THEN product2a = STRUPCASE(product)
  return, path

  end

;===============================================================================

;===============================================================================

pro append_dsd_phase, mygeomatchfile, DIR_BLOCK=dir_block, NAME_ADD=name_add, $
                    DIR_2A=dir_2a

@dpr_geo_match_nc_structs.inc
; "Include" file for DATA_PRESENT, NO_DATA_PRESENT
@grid_def.inc
; "Include" files for constants, names, paths, etc.
@environs.inc   ; for file prefixes, netCDF file definition version
@dpr_params.inc  ; for the type-specific fill values

VERBOSE=1

; replace /1_21/ in path with /8_8/
len=STRLEN(mygeomatchfile)
idxverdir=STRPOS(mygeomatchfile, '/1_21/')
file13=STRMID(mygeomatchfile,0,idxverdir) + '/8_8/' $
      + STRMID(mygeomatchfile,idxverdir+6, len-(idxverdir+6))
; make sure this new directory exists
IF FILE_TEST( FILE_DIRNAME(file13), /DIRECTORY ) EQ 0 THEN $
   spawn, 'mkdir -p ' + FILE_DIRNAME(file13)
IF N_ELEMENTS(name_add) EQ 1 THEN BEGIN
  ; replace "1_21."+name_add in basename with "8_8."+name_add
   idxncvers=STRPOS(file13, '1_21.')
   IF idxncvers EQ -1 THEN message, "File "+mygeomatchfile+" not named version 1_21."+name_add
   outfile = STRMID(file13,0,idxncvers) + '8_8.' + name_add + '.nc'
ENDIF ELSE BEGIN 
  ; replace "1_21." in basename with "8_8."
   idxncvers=STRPOS(file13, '1_21.')
   IF idxncvers EQ -1 THEN message, "File "+mygeomatchfile+" not named version 1_21."
   outfile = STRMID(file13,0,idxncvers)+'8_8.nc'
ENDELSE
;outfile = file13
print, '' & print, "Infile: ", mygeomatchfile

IF FILE_TEST(outfile+'.gz', /NOEXPAND_PATH) EQ 1 THEN BEGIN
   print, "Outfile already exists: ", outfile & print, ''
   GOTO, regularExit
ENDIF
print, "Outfile: ", outfile & print, ''

; open the original netCDF file and read the metadata and lat and lon fields
cpstatus = uncomp_file( mygeomatchfile, myfile )
if(cpstatus eq 'OK') then begin
   print, "**** Have DPR data file, computing/adding to existing file content. ****"
   print, ''
   status = 1   ; init to FAILED
   mygeometa={ dpr_geo_match_meta }
   myfiles={ dpr_gr_input_files }
   mysweeps={ gr_sweep_meta }
   mysite={ gr_site_meta }
   status = read_dpr_geo_match_netcdf( myfile, matchupmeta=mygeometa, $
      sweepsmeta=mysweeps, sitemeta=mysite, fieldflags=myflags, $
      filesmeta=myfiles )
  ; create data field arrays of correct dimensions and read data fields
   nfp = mygeometa.num_footprints
   nswp = mygeometa.num_sweeps
   DPR_scantype = mygeometa.DPR_ScanType
   site_ID = mysite.site_ID
   siteElev = mysite.site_elev
   pr_index=lonarr(nfp)
   top = FLTARR(nfp,nswp)
   botm = FLTARR(nfp,nswp)
   status = read_dpr_geo_match_netcdf( myfile, topHeight=top, $
               bottomHeight=botm, pridx_long=pr_index )
   if ( status NE 0 ) THEN GOTO, errorExit    ; open/read error

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
;      goto, errorExit
   ENDIF

   IF nfoundDPR NE 1 THEN BEGIN
      show_orig=0
      PRINT, ""
;      message, "ERROR finding just one 2A-DPR, 2A-KA , or 2A-KU file name"
   ENDIF

   ; it is a GPM-era filename, get the varying path components and prepend
   ; the non-varying parts of the full path
   product=''
;   path_tail = parse_2a_filename( myfiles.file_2Axxx, PRODUCT=product )

   CASE Instrument_ID OF
      'DPR' : BEGIN
                 path_tail = parse_2a_filename( origFileDPRName )
                 file_2adpr = dir_2a+"/"+path_tail+'/'+origFileDPRName
                 print, "Reading DPR from ",file_2adpr
              END
       'Ku' : BEGIN
                 path_tail = parse_2a_filename( origFileKuName )
                 file_2aku = dir_2a+"/"+path_tail+"/"+origFileKuName
                 print, "Reading DPR from ",file_2aku
              END
       'Ka' : BEGIN
                 path_tail = parse_2a_filename( origFileKaName )
                 file_2aka = dir_2a+"/"+path_tail+"/"+origFileKaName
                 print, "Reading DPR from ",file_2aka
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
                 dpr_data = read_2akaku_hdf5(file_2aka, SCAN=DPR_scantype, /READ_ALL)
                 dpr_file_read = origFileKaName
              END
       'KU' : BEGIN
                 ; 2AKU has only NS scan/swath type
                 CASE STRUPCASE(DPR_scantype) OF
                    'NS' : BEGIN
                              RAYSPERSCAN = RAYSPERSCAN_NS
                              GATE_SPACE = BIN_SPACE_NS_MS
                              ELLIPSOID_BIN_DPR = ELLIPSOID_BIN_NS_MS
                              dpr_data = read_2akaku_hdf5(file_2aku, $
                                         SCAN=DPR_scantype, /READ_ALL)
                              dpr_file_read = origFileKuName
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
                              message, "No phase variable in the DSD group for 2ADPR MS"
                              ;RAYSPERSCAN = RAYSPERSCAN_MS
                              ;GATE_SPACE = BIN_SPACE_NS_MS
                              ;ELLIPSOID_BIN_DPR = ELLIPSOID_BIN_NS_MS
                           END
                    'NS' : BEGIN
                              RAYSPERSCAN = RAYSPERSCAN_NS
                              GATE_SPACE = BIN_SPACE_NS_MS
                              ELLIPSOID_BIN_DPR = ELLIPSOID_BIN_NS_MS
                           END
                    ELSE : message, "Illegal scan type '"+DPR_scantype+"'"
                 ENDCASE
                 dpr_data = read_2adpr_hdf5(file_2adpr, SCAN=DPR_scantype, /READ_ALL)
                 dpr_file_read = origFileDPRName
              END
   ENDCASE

   ; check dpr_data structure for read failures
   IF SIZE(dpr_data, /TYPE) NE 8 THEN $
     message, "Error reading data from: "+dpr_file_read

   ; get the group structures for the specified scantype, tags vary by swathname
   CASE STRUPCASE(DPR_scantype) OF
      'HS' : ptr_swath = dpr_data.HS
      'MS' : ptr_swath = dpr_data.MS
      'NS' : ptr_swath = dpr_data.NS
   ENDCASE

   IF PTR_VALID(ptr_swath.PTR_PRE) THEN BEGIN
      binRealSurface = (*ptr_swath.PTR_PRE).BINREALSURFACE
      binClutterFreeBottom = (*ptr_swath.PTR_PRE).binClutterFreeBottom
      localZenithAngle = (*ptr_swath.PTR_PRE).localZenithAngle
   ENDIF ELSE message, "Invalid pointer to PTR_PRE."

   IF PTR_VALID(ptr_swath.PTR_SLV) THEN BEGIN
      phaseNearSurface = (*ptr_swath.PTR_SLV).phaseNearSurface
      ptr_free, ptr_swath.PTR_SLV
   ENDIF ELSE message, "Invalid pointer to PTR_SLV."

   IF PTR_VALID(ptr_swath.PTR_DSD) THEN BEGIN
      phase = (*ptr_swath.PTR_DSD).phase
   ENDIF ELSE message, "Invalid pointer to PTR_DSD."

   free_ptrs_in_struct, dpr_data

endif else begin
   goto, errorExit                            ; copy error
endelse

; NOTE THAT THE TRMM ARRAYS ARE IN (SCAN,RAY) COORDINATES, WHILE ALL GPM
; ARRAYS ARE IN (RAY,SCAN) COORDINATE ORDER.  NEED TO ACCOUNT FOR THIS WHEN
; ADDRESSING DATASETS BY ARRAY INDICES.

dpr_index_all = LINDGEN(SIZE(binClutterFreeBottom, /DIMENSIONS))
ind2d = ARRAY_INDICES(binClutterFreeBottom, dpr_index_all)
raynum = REFORM(ind2d[0,*])
scannum = REFORM(ind2d[1,*])

; precompute the reuseable ray angle trig variables for parallax -- in GPM,
; we have the local zenith angle for every ray/scan (i.e., footprint)
cos_inc_angle = COS( 3.1415926D * localZenithAngle / 180. )
tan_inc_angle = TAN( 3.1415926D * localZenithAngle / 180. )

; adjust top and botm to height above MSL (the ellipsoid)
top = top+siteElev
botm = botm+siteElev

; initialize array of phase, having the dimension of the
; sweep-level data arrays in the netCDF file

tocdf_phase = MAKE_ARRAY(nfp, /int, VALUE=INT_RANGE_EDGE)
tocdf_phaseHeightAGL = MAKE_ARRAY(nfp, /float, VALUE=FLOAT_RANGE_EDGE)
tocdf_phaseNearSurface = MAKE_ARRAY(nfp, /int, VALUE=INT_RANGE_EDGE)

; get array indices of the non-bogus (i.e., "actual") PR footprints to cover the
; possibility that the matchup was performed with "MARK_EDGES" turned on.
idxpractual = where(pr_index GE 0L, countactual)
if (countactual EQ 0) then begin
   print, "No non-bogus data points, quitting case."
   status = 1
   goto, errorExit
endif

; make a copy of binClutterFreeBottom and set all values to the fixed
; bin number at the ellipsoid for DPR setup.
binEllipsoid = binClutterFreeBottom
binEllipsoid[*,*] = ELLIPSOID_BIN_DPR

;  >>>>>>>>>>>>>> BEGINNING OF DPR-GR VOLUME MATCHING, ALL SWEEPS <<<<<<<<<<<<<<<

   FOR ielev = 0, 0 DO BEGIN   ; not doing sweeps, only do one pass
      print, ""
      FOR jpr=0, nfp-1 DO BEGIN
        ; init output variables defined/set in loop/if
         writeMISSING = 1
;         dpr_gates_expected = 0UL      ; # DPR gates within the sweep vert. bounds
         dpr_index = pr_index[jpr]
         IF botm[jpr,ielev] GT 0.0 AND top[jpr,ielev] GT botm[jpr,ielev] $
            THEN go_forth = 1 ELSE go_forth = 0

         IF ( dpr_index GE 0 AND go_forth ) THEN BEGIN
            raydpr = raynum[dpr_index]
            scandpr = scannum[dpr_index]
           ; determine if any DPR gates in the column are non-missing
            idxgood=WHERE(phase[*,raydpr,scandpr] GE 0.0, ngood)
            IF ( ngood GT 0 ) THEN BEGIN
               tocdf_phaseHeightAGL[jpr] = cos_inc_angle[raydpr,scandpr] * (GATE_SPACE/1000.) * $
                  (binRealSurface[raydpr,scandpr] - binClutterFreeBottom[raydpr,scandpr])
               tocdf_phase[jpr] = phase[binClutterFreeBottom[raydpr,scandpr]-1, raydpr,scandpr]
               tocdf_phaseNearSurface[jpr] = phaseNearSurface[raydpr,scandpr]
            ENDIF
         ENDIF ELSE BEGIN
            IF dpr_index EQ -2 THEN BEGIN
               tocdf_phase[jpr] = INT_OFF_EDGE
               tocdf_phaseHeightAGL[jpr] = FLOAT_OFF_EDGE
               tocdf_phaseNearSurface[jpr] = INT_OFF_EDGE
            ENDIF
         ENDELSE

      ENDFOR  ; each DPR subarray point: jpr=0, nfp-1

     ; END OF DPR-TO-GR RESAMPLING, THIS SWEEP

   ENDFOR     ; each elevation sweep: ielev = 0,0

;  >>>>>>>>>>>>>>>>> END OF DPR-GR VOLUME MATCHING, ALL SWEEPS <<<<<<<<<<<<<<<<<<

; re-open the netCDF file copy in define mode and create
; the new phase variable

cdfid = NCDF_OPEN( myfile, /WRITE )
IF ( N_Elements(cdfid) EQ 0 ) THEN BEGIN
   print, ''
   print, "ERROR, file copy ", myfile, " is not a valid netCDF file!"
   print, ''
   status = 1
   goto, errorExit
ENDIF

; take the netCDF file out of Write mode and into Define mode
ncdf_control, cdfid, /redef
;GOTO, skipitall

; field dimension
fpdimid = NCDF_DIMID(cdfid, 'fpdim')
eldimid = NCDF_DIMID(cdfid, 'elevationAngle')
help, INT_RANGE_EDGE, FLOAT_RANGE_EDGE

phasevarid = ncdf_vardef(cdfid, 'phase', fpdimid, /short)
ncdf_attput, cdfid, phasevarid, 'long_name', $
            'DPR phase'
ncdf_attput, cdfid, phasevarid, '_FillValue', INT_RANGE_EDGE

phaseHeightAGLvarid = ncdf_vardef(cdfid, 'phaseHeightAGL', fpdimid)
ncdf_attput, cdfid, phaseHeightAGLvarid, 'long_name', $
            'Height km AGL of DPR phase'
ncdf_attput, cdfid, phaseHeightAGLvarid, '_FillValue', FLOAT_RANGE_EDGE

phaseNearSurfacevarid = ncdf_vardef(cdfid, 'phaseNearSurface', fpdimid, /short)
ncdf_attput, cdfid, phaseNearSurfacevarid, 'long_name', $
            'DPR phaseNearSurface'
ncdf_attput, cdfid, phaseNearSurfacevarid, '_FillValue', INT_RANGE_EDGE

skipitall:
; take the netCDF file out of Define mode and back into Write mode
ncdf_control, cdfid, /endef

; update the matchup file version and write the new data to the file variable
versid = NCDF_VARID(cdfid, 'version')
ncdf_varput, cdfid, versid, 1.3
NCDF_VARPUT, cdfid, 'phase', tocdf_phase
NCDF_VARPUT, cdfid, 'phaseHeightAGL', tocdf_phaseHeightAGL
NCDF_VARPUT, cdfid, 'phaseNearSurface', tocdf_phaseNearSurface

ncdf_close, cdfid

command = "mv -v "+myfile+' '+outfile
spawn, command

command2 = 'gzip '+outfile
spawn, command2

GOTO, regularExit

errorExit:
  print, 'Cannot process geo_match netCDF file: ', mygeomatchfile
  print, cpstatus
  command3 = "rm -v " + myfile
  spawn, command3

regularExit:

END

;===============================================================================

pro append_dsd_phase_geomatchnetcdf, ncfilepr, DIR_2A=dir_2a, $
                                   VERBOSE=verbose

IF N_ELEMENTS(ncsitepath) EQ 1 THEN pathpr=ncsitepath+'*' $
ELSE pathpr = '/data/gpmgv/netcdf/geo_match/GPM/2AKu/NS/V04A/1_21'

NAME_ADD='withDSDphase'

IF N_ELEMENTS(dir_2a) NE 1 THEN dir_2a='/data/gpmgv/orbit_subset/GPM'

   prfiles = file_search(ncfilepr, COUNT=nf)
   IF (nf NE 1) THEN BEGIN
      print, "" 
      print, "No unique file found: ", ncfilepr
      print, " -- Skipping."
      goto, errorExit
   ENDIF

;FOR fnum = 0, nf-1 DO BEGIN
;   FOR fnum = 0, 0 < (nf-1) DO BEGIN
   print, '--------------------------------------------------------------------'
;   ncfilepr = prfiles(fnum)
   bname = file_basename( ncfilepr )
   print, "Do GeoMatch netCDF file: ", bname
   append_dsd_phase, ncfilepr, NAME_ADD=name_add, DIR_2A=dir_2a
;endfor

errorExit:
end
