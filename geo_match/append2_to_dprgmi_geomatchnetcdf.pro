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
; a 2B GPM filename, e.g., compose path = '/CONUS/2014/04/19' from
; 2B-CS-CONUS.GPM.DPRGMI.CORRA2015.20140419-S220512-E220629.000797.V04A.HDF5

  FUNCTION parse_2b_filename, origFileName, PRODUCT=product2b

  parsed = STRSPLIT(origFileName, '.', /EXTRACT)
  parsed2 = STRSPLIT(parsed[0], '-', /EXTRACT)
  subset = parsed2[2]
  instrument=parsed[2]
  product='2B'+instrument
  version = parsed[6]
  yyyymmdd = STRMID(parsed[4],0,4)+'/'+STRMID(parsed[4],4,2)+'/'+STRMID(parsed[4],6,2)
  path = instrument+'/'+product+'/'+version+'/'+subset+'/'+yyyymmdd

  IF N_ELEMENTS(product2b) NE 0 THEN product2b = STRUPCASE(product)
  return, path

  end

;===============================================================================

pro append_stormTop, mygeomatchfile, DIR_2B=dir_2b

@dprgmi_geo_match_nc_structs.inc

; "Include" file for DATA_PRESENT, NO_DATA_PRESENT
@grid_def.inc
; "Include" files for constants, names, paths, etc.
@environs.inc   ; for file prefixes, netCDF file definition version
@dpr_params.inc  ; for the type-specific fill values

idxncvers=STRPOS(mygeomatchfile, '1_3')
IF idxncvers EQ -1 THEN message, "File "+mygeomatchfile+" not named version 1_3."

idxncvers=STRPOS(mygeomatchfile, '.nc')
IF idxncvers EQ -1 THEN message, "File "+mygeomatchfile+" not type .nc"
outfile = STRMID(mygeomatchfile,0,idxncvers)+'.nc'
;print, '' & print, "Infile: ", mygeomatchfile
print, '' & print, "Outfile: ", outfile

;IF FILE_TEST(outfile+'.gz', /NOEXPAND_PATH) EQ 1 THEN BEGIN
;   print, "Outfile already exists: ", outfile & print, ''
;   GOTO, regularExit
;ENDIF

; define the two swaths in the DPRGMI product, we need separate variables
; for each swath for the science variables
swath = ['MS','NS']

; open the original netCDF file and read the metadata and pr_index field
cpstatus = uncomp_file( mygeomatchfile, myfile, /NOCOPY )
if(cpstatus eq 'OK') then begin
   status = 1   ; init to FAILED
   mygeometa={ dprgmi_geo_match_meta }
   myfiles={ dprgmi_gr_input_files }
   mysweeps={ gr_sweep_meta }
   mysite={ gr_site_meta }
   data_ms = 1    ; INITIALIZE AS ANYTHING, WILL BE REDEFINED IN READ CALL
   data_ns = 1    ; DITTO

   status = read_dprgmi_geo_match_netcdf( myfile, matchupmeta=mygeometa, $
      sweepsmeta=mysweeps, sitemeta=mysite, fieldflags=myflags, $
      filesmeta=myfiles, DATA_MS=data_MS, DATA_NS=data_NS )
   if ( status NE 0 ) THEN GOTO, errorExit    ; open/read error

  ; create data field arrays of correct dimensions and read data fields
   nswp = mygeometa.num_sweeps

  ; find the matchup input filename and set instrumentID
   origFileDPRGMIName = myfiles.file_2bcomb
   Instrument_ID='DPRGMI'

   IF ( origFileDPRGMIName EQ 'no_2BCMB_file' ) THEN BEGIN
      PRINT, ""
      message, "ERROR finding a 2BDPRGMI file name",/INFO
      PRINT, "Looked at: ", dprFileMatch
;      goto, errorExit
   ENDIF

   ; it is a GPM-era filename, get the varying path components and prepend
   ; the non-varying parts of the full path
   path_tail = parse_2b_filename( origFileDPRGMIName )
   file_2bcmb = GPMDATA_ROOT+"/"+path_tail+'/'+origFileDPRGMIName
   IF FILE_TEST(file_2bcmb) EQ 0 THEN $
      message, "Cannot find 2B file: " + file_2bcmb

EORC:

      print, '' & print, "Reading file: ", file_2bcmb & print, ''
     ; read both swaths, but only default variables
      data_COMB = read_2bcmb_hdf5( file_2bcmb )
      IF SIZE(data_COMB, /TYPE) NE 8 THEN BEGIN
         PRINT, ""
         PRINT, "ERROR reading fields from ", file_2bcmb
         PRINT, "Skipping 2BCMB processing for orbit = ", orbit
         PRINT, ""
         goto, errorExit                      ; read error
      ENDIF

endif else begin
   goto, errorExit                            ; copy error
endelse

for iswa=0,1 do begin
   scanType=swath[iswa]
 ; rename the geo-match and 2BDPRGMI data structures for the selected swath
 ; to a common name, and get the scan-type-specific metadata values
   CASE scanType OF
      'MS' : BEGIN
                dataCmb = TEMPORARY(data_ms)
                nfp = mygeometa.num_footprints_ms  ; # of PR rays in dataset
                ptr_swath = data_COMB.MS
             END
      'NS' : BEGIN
                dataCmb = TEMPORARY(data_ns)
                nfp = mygeometa.num_footprints_ns  ; # of PR rays in dataset
                ptr_swath = data_COMB.NS
             END
      ELSE : message, "Illegal SCANTYPE parameter, only MS or NS allowed."
   ENDCASE

   IF PTR_VALID(ptr_swath.PTR_Input) THEN BEGIN
      stormTopAltitude = (*ptr_swath.PTR_Input).stormTopAltitude
     ; if MS swath just grab the Ku values for storm top
      IF scanType EQ 'MS' THEN stormTopAltitude = REFORM(stormTopAltitude[0,*,*])
   ENDIF ELSE BEGIN
      free_ptrs_in_struct, data_COMB
      message, "Invalid pointer to PTR_Input."
   ENDELSE

   ; make an array of storm height having the dimension of the single-level
   ; data arrays in the netCDF file
   tocdf_stormTopAltitude = MAKE_ARRAY(nfp, VALUE=FLOAT_RANGE_EDGE)

  ; determine whether there are any in-range MS data points.  If none, then skip
  ; blockage computations for the swath
   IF scanType EQ 'MS' AND mygeometa.have_swath_MS EQ 0 THEN BEGIN
      message, "No in-range MS scan samples.", /INFO
;      status = 1
      GOTO, noMSdata
   ENDIF

   ; get array indices of the non-bogus (i.e., "actual") PR footprints to cover the
   ; possibility that the matchup was performed with "MARK_EDGES" turned on.
   idxpractual = where(dataCmb.scanNum GE 0L, countactual)
   if (countactual EQ 0) then begin
      print, "No non-bogus data points, quitting case."
      status = 1
      free_ptrs_in_struct, data_COMB
      goto, errorExit
   endif else begin
      ; cut out the 2Bxxx values for the actual PR footprints in the matchup, and
      ; assign to the locations of the actual PR footprints in the netCDF arrays
      for jfp = 0, countactual-1 do begin
         fileidx=[idxpractual[jfp]]
         tocdf_stormTopAltitude[fileidx] = $
            stormTopAltitude[ dataCmb.rayNum[fileidx], dataCmb.scanNum[fileidx] ]
      endfor
   endelse

noMSdata:

   ; re-open the netCDF file copy in define mode and create new 1-D
   ; swath-specific stormTopAltitude variable

   cdfid = NCDF_OPEN( myfile, /WRITE )
   IF ( N_Elements(cdfid) EQ 0 ) THEN BEGIN
      print, ''
      print, "ERROR, file copy ", myfile, " is not a valid netCDF file!"
      print, ''
      status = 1
      free_ptrs_in_struct, data_COMB
      goto, errorExit
   ENDIF

   ; take the netCDF file out of Write mode and into Define mode
   ncdf_control, cdfid, /redef

   ; field dimension
   fpdimid = NCDF_DIMID(cdfid, 'fpdim_'+swath[iswa])
   eldimid = NCDF_DIMID(cdfid, 'elevationAngle')

   this_varid = ncdf_vardef(cdfid, 'stormTopAltitude_'+swath[iswa], [fpdimid])
   ncdf_attput, cdfid, this_varid, 'long_name', $
               '2B-DPRGMI stormTopAltitude for '+swath[iswa]+' swath'
   ncdf_attput, cdfid, this_varid, 'units', 'm'
   ncdf_attput, cdfid, this_varid, '_FillValue', FLOAT_RANGE_EDGE

   ; take the netCDF file out of Define mode and back into Write mode
   ncdf_control, cdfid, /endef

   ; update the matchup file version and write the stormTopAltitude
   ; data to the file variable
   NCDF_VARPUT, cdfid, 'stormTopAltitude_'+swath[iswa], tocdf_stormTopAltitude

   ncdf_close, cdfid

endfor    ; 2nd swath loop

free_ptrs_in_struct, data_COMB

command2 = 'gzip -fv '+myfile
spawn, command2
print, "Updated geo-match file: ", mygeomatchfile

GOTO, regularExit

errorExit:
  print, 'Cannot copy/unzip geo_match netCDF file: ', mygeomatchfile
  print, cpstatus
  stop

regularExit:
END

;===============================================================================

pro append_to_dprgmi_geomatchnetcdf, ncsitepath, DIR_2B=dir_2b

IF N_ELEMENTS(ncsitepath) EQ 1 THEN pathpr=ncsitepath+'*' $
ELSE message, "Must specify a complete path to the GRtoDPRGMI files."

IF N_ELEMENTS(dir_2b) NE 1 THEN dir_2b='/data/gpmgv/orbit_subset/GPM'

lastsite='NA'
lastorbitnum=0
lastncfile='NA'

prfiles = file_search(pathpr+"/GRtoDPRGMI.*.1_3.*", COUNT=nf)
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
   print, '--------------------------------------------------------------------'
   print, "Do GeoMatch netCDF file: ", bname
   append_stormTop, ncfilepr, DIR_2B=dir_2b

endfor


errorExit:
end
