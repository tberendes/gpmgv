;===============================================================================
;+
; Copyright © 2008, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; testappendgeomatchnetcdf.pro           Morris/SAIC/GPM_GV      Feb 2015
;
; DESCRIPTION
; -----------
; Program to test method to add new variables to an existing GRtoPR netcdf file.
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

  FUNCTION parse_2a_filename, origFileName, PRODUCT=product2a

  parsed = STRSPLIT(origFileName, '.', /EXTRACT)
  parsed2 = STRSPLIT(parsed[0], '-', /EXTRACT)
  subset = parsed2[2]
  instrument=parsed[2]
  product='2A'+instrument
  version = parsed[6]
  yyyymmdd = STRMID(parsed[4],0,4)+'/'+STRMID(parsed[4],4,2)+'/'+STRMID(parsed[4],6,2)
  path = instrument+'/'+product+'/'+version+'/'+subset+'/'+yyyymmdd

  IF N_ELEMENTS(product2a) NE 0 THEN product2a = STRUPCASE(product)
  return, path

  end

;===============================================================================

pro append_pia, mygeomatchfile, DIR_2A=dir_2a

@dpr_geo_match_nc_structs.inc

; "Include" file for DATA_PRESENT, NO_DATA_PRESENT
@grid_def.inc
; "Include" files for constants, names, paths, etc.
@environs.inc   ; for file prefixes, netCDF file definition version
@dpr_params.inc  ; for the type-specific fill values

idxncvers=STRPOS(mygeomatchfile, '1_1')
IF idxncvers EQ -1 THEN message, "File "+mygeomatchfile+" not named version 1_1."

idxncvers=STRPOS(mygeomatchfile, '.nc')
IF idxncvers EQ -1 THEN message, "File "+mygeomatchfile+" not type .nc"
outfile = STRMID(mygeomatchfile,0,idxncvers)+'.nc'
;print, '' & print, "Infile: ", mygeomatchfile
print, '' & print, "Outfile: ", outfile

;IF FILE_TEST(outfile+'.gz', /NOEXPAND_PATH) EQ 1 THEN BEGIN
;   print, "Outfile already exists: ", outfile & print, ''
;   GOTO, regularExit
;ENDIF

; open the original netCDF file and read the metadata and pr_index field
cpstatus = uncomp_file( mygeomatchfile, myfile )
if(cpstatus eq 'OK') then begin
   status = 1   ; init to FAILED
   mygeometa={ dpr_geo_match_meta }
   myfiles={ dpr_gr_input_files }
   status = read_dpr_geo_match_netcdf( myfile, matchupmeta=mygeometa, $
      sweepsmeta=mysweeps, sitemeta=mysite, fieldflags=myflags, $
      filesmeta=myfiles )
  ; create data field arrays of correct dimensions and read data fields
   nfp = mygeometa.num_footprints
   nswp = mygeometa.num_sweeps
   DPR_scantype = mygeometa.DPR_scantype
   pr_index=lonarr(nfp)
   status = read_dpr_geo_match_netcdf( myfile, pridx_long=pr_index )
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



;instrument_id = 'Ku'
;file_2aku = '/data/emdata/orbit_subset/GPM/Ku/2AKu/V03B/CONUS/2014/05/23/'+myfiles.FILE_2AKU
;help, file_2aku
;stop
;goto, EORC


   CASE Instrument_ID OF
      'DPR' : BEGIN
                 path_tail = parse_2a_filename( origFileDPRName )
                 file_2adpr = GPMDATA_ROOT+"/"+path_tail+'/'+origFileDPRName
print, "Reading DPR from ",file_2adpr
              END
       'Ku' : BEGIN
                 path_tail = parse_2a_filename( origFileKuName )
                 file_2aku = GPMDATA_ROOT+"/"+path_tail+"/"+origFileKuName
print, "Reading DPR from ",file_2aku
              END
       'Ka' : BEGIN
                 path_tail = parse_2a_filename( origFileKaName )
                 file_2aka = GPMDATA_ROOT+"/"+path_tail+"/"+origFileKaName
print, "Reading DPR from ",file_2aka
              END
   ENDCASE


EORC:


   ; check Instrument_ID and DPR_scantype consistency and read data if OK
   CASE STRUPCASE(Instrument_ID) OF
       'KA' : BEGIN
                 ; 2AKA has only HS and MS scan/swath types
                 CASE STRUPCASE(DPR_scantype) OF
                    'HS' : 
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
                    'HS' : 
                    'MS' : 
                    'NS' : 
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
      heightStormTop = (*ptr_swath.PTR_PRE).heightStormTop
      ptr_free, ptr_swath.PTR_PRE
   ENDIF ELSE message, "Invalid pointer to PTR_PRE."

   IF PTR_VALID(ptr_swath.PTR_SLV) THEN BEGIN
      piaFinal = (*ptr_swath.PTR_SLV).piaFinal
      ptr_free, ptr_swath.PTR_SLV
   ENDIF ELSE message, "Invalid pointer to PTR_SLV."

; make an array of PIA and storm height having the dimension of the single-level
; data arrays in the netCDF file
tocdf_piaFinal = MAKE_ARRAY(nfp, /float, VALUE=FLOAT_RANGE_EDGE)
tocdf_heightStormTop = MAKE_ARRAY(nfp, /int, VALUE=INT_RANGE_EDGE)

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

; cut out the 2Axxx values for the actual PR footprints in the matchup, and
; assign to the locations of the actual PR footprints in the netCDF arrays
tocdf_piaFinal[idxpractual] = piaFinal[pr_idx_actual]
tocdf_heightStormTop[idxpractual] = heightStormTop[pr_idx_actual]

; re-open the netCDF file copy in define mode and create new 1-D PIA
; and heightStormTop variables

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

havePIAvarid = ncdf_vardef(cdfid, 'have_piaFinal', /short)
ncdf_attput, cdfid, havePIAvarid, 'long_name', $
             'data exists flag for piaFinal'
ncdf_attput, cdfid, havePIAvarid, '_FillValue', NO_DATA_PRESENT

havestmtopvarid = ncdf_vardef(cdfid, 'have_heightStormTop', /short)
ncdf_attput, cdfid, havestmtopvarid, 'long_name', $
             'data exists flag for heightStormTop'
ncdf_attput, cdfid, havestmtopvarid, '_FillValue', NO_DATA_PRESENT

; field dimension
fpdimid = NCDF_DIMID(cdfid, 'fpdim')

PIAvarid = ncdf_vardef(cdfid, 'piaFinal', [fpdimid])
ncdf_attput, cdfid, PIAvarid, 'long_name', $
             'DPR path integrated attenuation'
ncdf_attput, cdfid, PIAvarid, 'units', 'dBZ'
ncdf_attput, cdfid, PIAvarid, '_FillValue', FLOAT_RANGE_EDGE

stmtopvarid = ncdf_vardef(cdfid, 'heightStormTop', [fpdimid], /short)
ncdf_attput, cdfid, stmtopvarid, 'long_name', $
             'DPR Estimated Storm Top Height (meters)'
ncdf_attput, cdfid, stmtopvarid, 'units', 'm'
ncdf_attput, cdfid, stmtopvarid, '_FillValue', INT_RANGE_EDGE

; take the netCDF file out of Define mode and back into Write mode
ncdf_control, cdfid, /endef

; update the matchup file version and write the piaFinal and heightStormTop
; data to the file variable
;versid = NCDF_VARID(cdfid, 'version')
;ncdf_varput, cdfid, versid, 3.1
NCDF_VARPUT, cdfid, 'piaFinal', tocdf_piaFinal
NCDF_VARPUT, cdfid, 'have_piaFinal', DATA_PRESENT
;print, "MAX piaFinal: ", max(tocdf_piaFinal)
NCDF_VARPUT, cdfid, 'heightStormTop', tocdf_heightStormTop
NCDF_VARPUT, cdfid, 'have_heightStormTop', DATA_PRESENT
;
ncdf_close, cdfid

command = "mv -v "+myfile+' '+outfile
spawn, command
command2 = 'gzip -fv '+outfile
spawn, command2
print, "Updated geo-match file: ", mygeomatchfile

GOTO, regularExit

errorExit:
  print, 'Cannot copy/unzip geo_match netCDF file: ', mygeomatchfile
  print, cpstatus
  command3 = "rm -v " + myfile
  spawn, command3
  stop

regularExit:
END

;===============================================================================

pro append_to_dpr_geomatchnetcdf, ncsitepath, DIR_2A=dir_2a

IF N_ELEMENTS(ncsitepath) EQ 1 THEN pathpr=ncsitepath+'*' $
ELSE message, "Must specify a complete path to the GRtoDPR files."

IF N_ELEMENTS(dir_2a) NE 1 THEN dir_2a='/data/gpmgv/orbit_subset/GPM'

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
   prlen = strlen( bname )
;   print, ''
   print, '--------------------------------------------------------------------'
;   print, ''
IF bname NE 'GRtoDPR.KTYX.140523.1327.V03B.KU.NS.1_1.nc.gz' and $
   bname NE 'GRtoDPR.KCAE.140523.1327.V03B.KU.NS.1_1.nc.gz' THEN BEGIN
   print, "Do GeoMatch netCDF file: ", bname
   append_pia, ncfilepr, DIR_2A=dir_2a
ENDIF ELSE print, "Skipping file: ", bname
endfor


errorExit:
end
