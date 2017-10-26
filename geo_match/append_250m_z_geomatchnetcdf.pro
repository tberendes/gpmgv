;===============================================================================
;+
; Copyright © 2015, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; append_250m_z_geomatchnetcdf.pro           Morris/SAIC/GPM_GV      Feb 2016
;
; DESCRIPTION
; -----------
; Program to add new volume-match DPR Zcor and Zraw variables, computed from
; 125m-resolution data reduced to 250m-resolution using the 2B-DPRGMI averaging
; method, to an existing GRtoDPR netcdf file.
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
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

pro append_250m_z, mygeomatchfile, DIR_BLOCK=dir_block, DIR_2A=dir_2a, $
                   DECLUTTER=declutter_in

@dpr_geo_match_nc_structs.inc
; "Include" file for DATA_PRESENT, NO_DATA_PRESENT
@grid_def.inc
; "Include" files for constants, names, paths, etc.
@environs.inc   ; for file prefixes, netCDF file definition version
@dpr_params.inc  ; for the type-specific fill values

VERBOSE=1
declutter=KEYWORD_SET(declutter_in)

; replace /1_21/ in path with /1_3/
len=STRLEN(mygeomatchfile)
idxverdir=STRPOS(mygeomatchfile, '/1_21/')
file13=STRMID(mygeomatchfile,0,idxverdir) + '/1_3/' $
      + STRMID(mygeomatchfile,idxverdir+6, len-(idxverdir+6))
; make sure this new directory exists
IF FILE_TEST( FILE_DIRNAME(file13), /DIRECTORY ) EQ 0 THEN $
   spawn, 'mkdir -p ' + FILE_DIRNAME(file13)

; replace .1_21. in basename with .1_3., accounting for any NC_NAME_ADD additions
; to the file basename between the matchup file version and the .nc extension
len=STRLEN(file13)
idxncvers=STRPOS(file13, '.1_21.')
IF idxncvers EQ -1 THEN message, "File "+mygeomatchfile+" not named version 1_21."
outfile = STRMID(file13,0,idxncvers) + '.1_3.' + STRMID(file13,idxncvers+6, len-(idxncvers+6))
; strip the '.gz' exension off the end of 'outfile' if it is there
IF STRPOS(outfile, '.gz') EQ (STRLEN(outfile)-3) THEN $
   outfile = STRMID(outfile, 0, STRPOS(outfile, '.gz'))
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
   print, "**** Have 250m_z data, computing/adding to existing file content. ****"
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
                    'HS' : message, "HS not a valid scan type for operation."
                    'MS' : 
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
                           END
                    ELSE : message,"Illegal scan type '"+DPR_scantype+"' for KU"
                  ENDCASE            
              END
      'DPR' : BEGIN
                 ; 2ADPR has all 3 scan/swath types
                 CASE STRUPCASE(DPR_scantype) OF
                    'HS' : message, "HS not a valid scan type for operation."
                    'MS' : BEGIN
                              RAYSPERSCAN = RAYSPERSCAN_MS
                              GATE_SPACE = BIN_SPACE_NS_MS
                              ELLIPSOID_BIN_DPR = ELLIPSOID_BIN_NS_MS
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

   ; get the group structures for the specified scantype, tags vary by swathname
   CASE STRUPCASE(DPR_scantype) OF
      'HS' : message, "HS not a valid scan type for operation."
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
      ptr_free, ptr_swath.PTR_SLV
   ENDIF ELSE message, "Invalid pointer to PTR_SLV."

endif else begin
   goto, errorExit                            ; copy error
endelse

; NOTE THAT THE TRMM ARRAYS ARE IN (SCAN,RAY) COORDINATES, WHILE ALL GPM
; ARRAYS ARE IN (RAY,SCAN) COORDINATE ORDER.  NEED TO ACCOUNT FOR THIS WHEN
; ADDRESSING DATASETS BY ARRAY INDICES.

dpr_index_all = LINDGEN(SIZE(binClutterFreeBottom, /DIMENSIONS))
ind2d = ARRAY_INDICES(binClutterFreeBottom, dpr_index_all)
raydpr = REFORM(ind2d[0,*])
scandpr = REFORM(ind2d[1,*])

; precompute the reuseable ray angle trig variables for parallax -- in GPM,
; we have the local zenith angle for every ray/scan (i.e., footprint)
cos_inc_angle = COS( 3.1415926D * localZenithAngle / 180. )
tan_inc_angle = TAN( 3.1415926D * localZenithAngle / 180. )

; adjust top and botm to height above MSL (the ellipsoid)
top = top+siteElev
botm = botm+siteElev

; initialize arrays of mean and stddev of corrected and raw Z, expected 250m
; gates, and below threshold corrected and raw DPR 250m gates, having the
; dimension of the sweep-level data arrays in the netCDF file

avg_250m_zc = MAKE_ARRAY(nfp, nswp, /float, VALUE=FLOAT_RANGE_EDGE)
avg_250m_zm = MAKE_ARRAY(nfp, nswp, /float, VALUE=FLOAT_RANGE_EDGE)
;stddev_250m_zc = MAKE_ARRAY(nfp, nswp, /float, VALUE=FLOAT_RANGE_EDGE)
;stddev_250m_zm = MAKE_ARRAY(nfp, nswp, /float, VALUE=FLOAT_RANGE_EDGE)
n_250m_expect = INTARR(nfp, nswp)
n_250m_zc_reject = INTARR(nfp, nswp)
n_250m_zm_reject = INTARR(nfp, nswp)

; initialize 1-D array of max measured 250m Z in the columns
max_250m_zm = MAKE_ARRAY(nfp, /float, VALUE=FLOAT_RANGE_EDGE)

; get array indices of the non-bogus (i.e., "actual") PR footprints to cover the
; possibility that the matchup was performed with "MARK_EDGES" turned on.
idxpractual = where(pr_index GE 0L, countactual)
if (countactual EQ 0) then begin
   print, "No non-bogus data points, quitting case."
   status = 1
   goto, errorExit
endif

; get the subset of pr_index values and their ray and scan numbers
; for actual DPR rays in the matchup
pr_idx_actual = pr_index[idxpractual]
theseRays = raydpr[pr_idx_actual]
theseScans = scandpr[pr_idx_actual]
; grab subset array of max_250m_zm at actual footprints to pass as I/O parameter
; to dpr_125m_to_250m()
maxZmeas250 = max_250m_zm[idxpractual]

  ; ============================================================================
  ; If the DECLUTTER keyword was set, then compute a clutter flag for the DPR
  ; corrected reflectivity in  the matchup area using a custom technique in
  ; flag_clutter.pro, and use it to blank out clutter gates in the measured and
  ; corrected Z arrays

   IF declutter THEN BEGIN
      PRINT, "" & PRINT, "Computing clutter gates in DPR Zcor"
     ; define an array to flag clutter gates and call flag_clutter to assign
     ; values for the locations of "actual" DPR footprints
      clutterFlag = BYTARR(SIZE(dbz_corr, /DIMENSIONS))
      flag_clutter, theseScans, theseRays, dbz_corr, clutterFlag, $
                    binClutterFreeBottom, VERBOSE=verbose
      idxclutter=where(CLUTTERFLAG EQ 80b, nclutr)
      ;HELP, clutterFlag, theseScans, theseRays, nclutr
      PRINT, STRING(nclutr, FORMAT='(I0)'), " clutter gates found in ", $
             STRING(countactual, FORMAT='(I0)'), " rays."
      PRINT, ""

      IF nclutr GT 0 THEN BEGIN
        ; set the DBZ_corr and dbz_meas gates to a negative value where they
        ; are tagged as clutter
         dbz_corr[idxclutter] = -1.0
         dbz_meas[idxclutter] = -1.0
      ENDIF
   ENDIF
  ; ============================================================================

; average the 125m Z data down to 250m data as done in 2B-CMB algorithm, for
; the actual footprints only, and also compute max Z in columns for Zmeas
;dbz_corr_2B = dpr_125m_to_250m(dbz_corr, theseRays, theseScans, $
dbz_corr_2B = dpr_125m_to_250m(dbz_corr, raydpr, scandpr, $
                               binClutterFreeBottom, ELLIPSOID_BIN_DPR)
dbz_meas_2B = dpr_125m_to_250m(dbz_meas, theseRays, theseScans, $
                               binClutterFreeBottom, ELLIPSOID_BIN_DPR, $
                               MAXZ250=maxZmeas250)

; assign max_250m_zm at actual footprints
max_250m_zm[idxpractual] = maxZmeas250

; make a copy of binClutterFreeBottom and set all values to the fixed
; bin number at the ellipsoid for DPRGMI setup.
binEllipsoid = binClutterFreeBottom
binEllipsoid[*,*] = ELLIPSOID_BIN_DPRGMI

; run the volume matching for Zc and Zm
resample_250m_z, dbz_corr_2B, avg_250m_zc, n_250m_zc_reject, top, botm, $
                 cos_inc_angle, raydpr, scandpr, pr_index, binEllipsoid, $
                 mygeometa.dpr_dbz_min, N_250m_EXPECT=n_250m_expect

resample_250m_z, dbz_meas_2B, avg_250m_zm, n_250m_zm_reject, top, botm, $
                 cos_inc_angle, raydpr, scandpr, pr_index, binEllipsoid, $
                 mygeometa.dpr_dbz_min

; re-open the netCDF file copy in define mode and create
; the new 2-D 250m_z variables

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

havedbzrawvarid = ncdf_vardef(cdfid, 'have_ZFactorMeasured250m', /short)
ncdf_attput, cdfid, havedbzrawvarid, 'long_name', $
             'data exists flag for ZFactorMeasured250m'
ncdf_attput, cdfid, havedbzrawvarid, '_FillValue', NO_DATA_PRESENT

havedbzvarid = ncdf_vardef(cdfid, 'have_ZFactorCorrected250m', /short)
ncdf_attput, cdfid, havedbzvarid, 'long_name', $
             'data exists flag for ZFactorCorrected250m'
ncdf_attput, cdfid, havedbzvarid, '_FillValue', NO_DATA_PRESENT

; field dimension
fpdimid = NCDF_DIMID(cdfid, 'fpdim')
eldimid = NCDF_DIMID(cdfid, 'elevationAngle')

rawZrejvarid = ncdf_vardef(cdfid, 'n_dpr_meas_z_rejected250m', $
                           [fpdimid,eldimid], /short)
ncdf_attput, cdfid, rawZrejvarid, 'long_name', $
             'number of bins below DPR_dBZ_min in ZFactorMeasured250m average'
ncdf_attput, cdfid, rawZrejvarid, '_FillValue', INT_RANGE_EDGE

corZrejvarid = ncdf_vardef(cdfid, 'n_dpr_corr_z_rejected250m', $
                           [fpdimid,eldimid], /short)
ncdf_attput, cdfid, corZrejvarid, 'long_name', $
             'number of bins below DPR_dBZ_min in ZFactorCorrected250m average'
ncdf_attput, cdfid, corZrejvarid, '_FillValue', INT_RANGE_EDGE

prexpvarid = ncdf_vardef(cdfid, 'n_dpr_expected250m', [fpdimid,eldimid], /short)
ncdf_attput, cdfid, prexpvarid, 'long_name', 'number of bins in DPR250m averages'
ncdf_attput, cdfid, prexpvarid, '_FillValue', INT_RANGE_EDGE

dbzrawvarid = ncdf_vardef(cdfid, 'ZFactorMeasured250m', [fpdimid,eldimid])
ncdf_attput, cdfid, dbzrawvarid, 'long_name', $
            'DPR Uncorrected Reflectivity from 250m gates'
ncdf_attput, cdfid, dbzrawvarid, 'units', 'dBZ'
ncdf_attput, cdfid, dbzrawvarid, '_FillValue', FLOAT_RANGE_EDGE

dbzvarid = ncdf_vardef(cdfid, 'ZFactorCorrected250m', [fpdimid,eldimid])
ncdf_attput, cdfid, dbzvarid, 'long_name', $
             'DPR Attenuation-corrected Reflectivity from 250m gates'
ncdf_attput, cdfid, dbzvarid, 'units', 'dBZ'
ncdf_attput, cdfid, dbzvarid, '_FillValue', FLOAT_RANGE_EDGE

maxdbzrawvarid = ncdf_vardef(cdfid, 'MaxZFactorMeasured250m', [fpdimid])
ncdf_attput, cdfid, maxdbzrawvarid, 'long_name', $
            'Maximum DPR Uncorrected Reflectivity along ray from 250m gates'
ncdf_attput, cdfid, maxdbzrawvarid, 'units', 'dBZ'
ncdf_attput, cdfid, maxdbzrawvarid, '_FillValue', FLOAT_RANGE_EDGE


; take the netCDF file out of Define mode and back into Write mode
ncdf_control, cdfid, /endef

; update the matchup file version and write the new data to the file variable
versid = NCDF_VARID(cdfid, 'version')
ncdf_varput, cdfid, versid, 1.3
NCDF_VARPUT, cdfid, 'ZFactorMeasured250m', avg_250m_zm
NCDF_VARPUT, cdfid, 'have_ZFactorMeasured250m', DATA_PRESENT
NCDF_VARPUT, cdfid, 'ZFactorCorrected250m', avg_250m_zc
NCDF_VARPUT, cdfid, 'have_ZFactorCorrected250m', DATA_PRESENT
NCDF_VARPUT, cdfid, 'n_dpr_meas_z_rejected250m', n_250m_zm_reject
NCDF_VARPUT, cdfid, 'n_dpr_corr_z_rejected250m', n_250m_zc_reject
NCDF_VARPUT, cdfid, 'n_dpr_expected250m', n_250m_expect
NCDF_VARPUT, cdfid, 'MaxZFactorMeasured250m', max_250m_zm

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

pro append_250m_z_geomatchnetcdf, ncsitepath, DIR_2A=dir_2a, VERBOSE=verbose

IF N_ELEMENTS(ncsitepath) EQ 1 THEN pathpr=ncsitepath+'*' $
ELSE pathpr = '/data/gpmgv/netcdf/geo_match/GPM/2AKu/NS/V04A/1_21/2014'

IF N_ELEMENTS(dir_2a) NE 1 THEN dir_2a='/data/gpmgv/orbit_subset/GPM'

   prfiles = file_search(pathpr+'/'+'GRtoDPR.K*.1_21.*', COUNT=nf)
   IF (nf LE 0) THEN BEGIN
      print, "" 
      print, "No files found for pattern = ", pathpr+'/*.1_21.*'
      print, " -- Skipping."
      goto, errorExit
   ENDIF

FOR fnum = 0, nf-1 DO BEGIN
;   FOR fnum = 0, 0 < (nf-1) DO BEGIN
   print, '--------------------------------------------------------------------'
   ncfilepr = prfiles(fnum)
   bname = file_basename( ncfilepr )
   print, "Do GeoMatch netCDF file: ", bname
   append_250m_z, ncfilepr, DIR_2A=dir_2a
endfor

errorExit:
end
