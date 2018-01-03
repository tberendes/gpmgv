;===============================================================================
;+
; Copyright © 2015, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; append_blockage_geomatchnetcdf.pro           Morris/SAIC/GPM_GV      Oct 2015
;
; DESCRIPTION
; -----------
; Program to add ground radar beam blockage variables to an existing GRtoDPR
; netcdf file.
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;===============================================================================

FUNCTION compute_blockage, iswp, idxpractual, avg_blockage, thisfile, $
                           site_lat, site_lon, latitude, longitude, $
                           ZERO_FILL=zero_fill

status = 0    ; initialize to SUCCESS

; Computes range and azimuth from a radar site at (site_lat,site_lon) to a
; subset of DPR footprints at (lat[idxpractual],lon[idxpractual]) on a sweep
; level index defined by iswp, computes the mean beam blockage from the blockage
; values given by range and azimuth in the sweep-specific file 'thisfile', and
; assigns the mean blockages to the 'idxpractual' positions in the 'iswp' level
; of the blockage data array 'avg_blockage'.  If the ZERO_FILL parameter is set,
; then the blockage file, lat/lon information, and range/azimuth are all ignored
; and the positions in the avg_blockage array defined by iswp and idxpractual
; are just set to 0.0 to indicate no blockage.

max_sep = 3.79601    ; use fixed radius of influence from a real case
max_sep_SQR = max_sep^2

; we need at least the first 3 parameters if doing zero fill, or all 8
; parameters if not doing zero fill
IF ( N_PARAMS() LT 3 ) $
   OR ( N_PARAMS() GE 3 AND N_PARAMS() LT 8 AND KEYWORD_SET(zero_fill) NE 1 ) $
   THEN message, "Incomplete parameters supplied."

IF KEYWORD_SET(zero_fill) THEN BEGIN
   print, "In the ZERO_FILL situation as directed."
   avg_blockage[idxpractual,iswp] = 0.0   ; and we're done!

ENDIF ELSE BEGIN
  ; Restore the blockage variables for the level and check to see if any of the
  ; gate blockages are fractional ( 0.0 < value <= 1.0 ).  If yes, then compute
  ; the mean blockages, otherwise just set the mean blockages to 0 as in the
  ; ZERO_FILL case.
   RESTORE, FILE=thisfile
   ;HELP, site, elev, azimuths, ranges_out, blockage_out
   idxFractional = WHERE(blockage_out GT 0.0 AND blockage_out LE 1.0, nblock)

   IF nblock EQ 0 THEN BEGIN
      print, "In the ZERO_FILL situation by blockage values."
      ;print, "MAX(blockage_out): ", MAX(blockage_out)
      avg_blockage[idxpractual,iswp] = 0.0

   ENDIF ELSE BEGIN
      print, "Computing mean blockage for footprints."

     ; Preprocess the blockage values and replace the values of 1.0 (where the
     ; blocking object exists) with the value of the blocked fraction at the
     ; further ranges along the radial. If that blocked fraction can't be found,
     ; then just set the blocking object gates to zero.  In no case do we want
     ; to include flag values of 1.0 in the mean blocking calculations.
      blokdims = SIZE(blockage_out,/DIMENSIONS)  ; dims are [nranges, nradials]
      nrays = blokdims[1]
      ngates = blokdims[0]
      for irad = 0, nrays-1 do begin
         idxOnes = WHERE(blockage_out[*,irad] EQ 1.0, nOnes)
        ; check whether there are blockage object gates within the radial, with
        ; blockage fractional values at ranges beyond the object
         IF nOnes GT 0 AND MAX(idxOnes) LT (ngates-1) THEN BEGIN
           ; find the blockage fraction beyond the blocking object, and assign
           ; this fractional blockage to the blocking object flagged gates,
           ; assuming there is only one contiguous region of blocking object
           ; gates along the radial
            blockage_out[idxOnes,irad] = blockage_out[(MAX(idxOnes)+1),irad]
            ;print, "Az: ", azimuths[irad], ", setting ",nOnes, $
            ;    " middle gates of 1.0 to ",blockage_out[(MAX(idxOnes)+1),irad]
         ENDIF ELSE BEGIN
           ; if blocking object extends to the last gate in the blockage array,
           ; then just set the blocking object gates to 0.0 (no blockage)
            blockage_out[idxOnes,irad] = 0.0
           ;print, "Az: ", azimuths[irad], ", setting ",nOnes, $
           ;   " trailing gates of 1.0 to 0.0"
         ENDELSE
      endfor

     ; initialize a gv-centered map projection for the ll<->xy transformations:
      sMap = MAP_PROJ_INIT( 'Azimuthal Equidistant', center_latitude=site_lat, $
                            center_longitude=site_lon )

     ; Populate arrays holding 'exact' X and Y and range values for this level
     ; for the subset of DPR footprints.
      XY_km = map_proj_forward( longitude[idxpractual,iswp], $
                                latitude[idxpractual,iswp], $
                                map_structure=smap ) / 1000.
      dpr_x = XY_km[0,*]
      dpr_y = XY_km[1,*]

     ; compute sin and cos of the set of angles from 0 to 359 degrees for the
     ; rays in the blockage files
      sinBlokAz = SIN(azimuths*!DTOR)
      cosBlokAz = COS(azimuths*!DTOR)
     ; initalize x and y of the blockage bins as 1 to 230 km for every angle
      blok_x = FLOAT( LINDGEN(blokdims) MOD 230 ) + 1.0
      blok_y = blok_x
     ; multiply these 'unit vectors' by sin and cos of the angles 0-359 to get
     ; their x and y coordinates with the origin at the radar location.
     ; - Ignore the sweep elevation angle as we don't know whether the blockage
     ;   is computed in slant range or ground range
      for ibin = 0, 229 do begin
         blok_x[ibin,*] = sinBlokAz * blok_x[ibin,*]
         blok_y[ibin,*] = cosBlokAz * blok_y[ibin,*]
      endfor

     ; now loop through the footprints, find the blockage bins within a cutoff
     ; distance of the footprint center, and compute a distance-weighted mean
     ; blockage value
      for ifoot = 0, N_ELEMENTS(dpr_x)-1 do begin
         irough = WHERE( ABS(blok_x - dpr_x[ifoot]) LT max_sep AND $
                         ABS(blok_y - dpr_y[ifoot]) LT max_sep, nrough )
         IF nrough GT 0 THEN BEGIN
           ; check for an all-zeroes status in the blockage file within the
           ; rough distance box.  If all zeroes, then skip the distance-
           ; weighted mean calculations
            idxNotZero = WHERE(blockage_out[irough] GT 0.0, nNotZero)
            IF nNotZero EQ 0 THEN BEGIN
               avg_blockage[idxpractual[ifoot],iswp] = 0.0
            ENDIF ELSE BEGIN
               ;print, "Non-zero blockage for ifoot ", ifoot
              ; compute square of true distance from footprint center
               distsqr = (blok_x[irough] - dpr_x[ifoot])^2 $
                        +(blok_y[irough] - dpr_y[ifoot])^2
               closebyidx = WHERE(distsqr le max_sep_SQR, countclose )
              ; compute the weights for the near-enough blockage bins
               weighting = EXP( - (distsqr[closebyidx]/max_sep_SQR) )
              ; compute the distance-weighted mean
                avg_blockage[idxpractual[ifoot],iswp] = $
                   TOTAL(blockage_out[irough[closebyidx]] * weighting) / $
                   TOTAL(weighting)
                ;print, TOTAL(blockage_out[irough[closebyidx]] * weighting) / $
                ;       TOTAL(weighting)
            ENDELSE
         ENDIF ELSE BEGIN
            message, "No blockage x,y within 3.8 km? !!", /INFO
            print, "Footprint Lat/Lon: ", latitude[idxpractual[ifoot],iswp], $
                   longitude[idxpractual[ifoot],iswp]
            status = 1
            print, "Enter .CONTINUE to proceed with blockage set to Fill Values."
            stop
            break
         ENDELSE
      endfor

   ENDELSE
ENDELSE

return, status
end

;===============================================================================

pro append_blockage, mygeomatchfile, DIR_BLOCK=dir_block, NO_DATA=no_data

@dprgmi_geo_match_nc_structs.inc
; "Include" file for DATA_PRESENT, NO_DATA_PRESENT
@grid_def.inc
; "Include" files for constants, names, paths, etc.
@environs.inc   ; for file prefixes, netCDF file definition version
@dpr_params.inc  ; for the type-specific fill values

VERBOSE=1

; replace /1_1/ in pathname with /1_2/
len=STRLEN(mygeomatchfile)
idxverdir=STRPOS(mygeomatchfile, '/1_1/')
file121=STRMID(mygeomatchfile,0,idxverdir) + '/1_2/' $
      + STRMID(mygeomatchfile,idxverdir+5, len-(idxverdir+5))
; make sure this new directory exists
IF FILE_TEST( FILE_DIRNAME(file121), /DIRECTORY ) EQ 0 THEN $
   spawn, 'mkdir -p ' + FILE_DIRNAME(file121)
idxncvers=STRPOS(file121, '1_1.nc')
IF idxncvers EQ -1 THEN message, "File "+mygeomatchfile+" not named version 1_1."
outfile = STRMID(file121,0,idxncvers)+'1_2.nc'
;outfile = file121
print, '' & print, "Infile: ", mygeomatchfile

IF FILE_TEST(outfile+'.gz', /NOEXPAND_PATH) EQ 1 THEN BEGIN
   print, "Outfile already exists: ", outfile & print, ''
   GOTO, regularExit
ENDIF
print, "Outfile: ", outfile & print, ''

; define the two swaths in the DPRGMI product, we need separate variables
; for each swath for the science variables
swath = ['MS','NS']

IF KEYWORD_SET(no_data) THEN BEGIN
  ; just add the new variables to a copy of the existing netCDF file,
  ; initialized to default FILL values
   print, "**** No blockage data, just updating existing file content. ****"
   print, ''
   cpstatus = uncomp_file( mygeomatchfile, myfile )
   if(cpstatus eq 'OK') then begin
     ; open the netCDF file copy in define mode and create
     ; a new 2-D blockage variable
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

      haveBLKvarid = ncdf_vardef(cdfid, 'have_GR_blockage', /short)
      ncdf_attput, cdfid, haveBLKvarid, 'long_name', $
                   'data exists flag for ground radar blockage fraction'
      ncdf_attput, cdfid, haveBLKvarid, '_FillValue', NO_DATA_PRESENT
     ; field dimensions
      fpdimid_MS = NCDF_DIMID(cdfid, 'fpdim_MS')
      fpdimid_NS = NCDF_DIMID(cdfid, 'fpdim_NS')
      fpdimid = [ fpdimid_MS, fpdimid_NS ]                    ; match to "swath" array, above
      eldimid = NCDF_DIMID(cdfid, 'elevationAngle')

      for iswa = 0,1 do begin
         BLKvarid = ncdf_vardef(cdfid, 'GR_blockage_'+swath[iswa], [fpdimid[iswa],eldimid])
         ncdf_attput, cdfid, BLKvarid, 'long_name', $
                      'ground radar blockage fraction, '+swath[iswa]+' swath'
         ncdf_attput, cdfid, BLKvarid, '_FillValue', FLOAT_RANGE_EDGE
      endfor

      ; take the netCDF file out of Define mode and close it up
      ncdf_control, cdfid, /endef
versid = NCDF_VARID(cdfid, 'version')
ncdf_varput, cdfid, versid, 1.2

      ncdf_close, cdfid

     ; overwrite the original file and gzip the result
      command = "mv -v "+myfile+' '+outfile
      spawn, command
      command2 = 'gzip '+outfile
      spawn, command2
      GOTO, regularExit
   endif else begin
      goto, errorExit                            ; copy error
   endelse
ENDIF

; open the original netCDF file and read the metadata and lat and lon fields
cpstatus = uncomp_file( mygeomatchfile, myfile )
if(cpstatus eq 'OK') then begin
   print, "**** Have blockage data, computing/adding to existing file content. ****"
   print, ''
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

   nswp = mygeometa.num_sweeps
   site_lat = mysite.site_lat
   site_lon = mysite.site_lon
   site_ID = mysite.site_ID
endif else begin
   goto, errorExit                            ; copy error
endelse

; determine whether we have any blockage files for this radar
IF FILE_TEST(dir_block+'/'+site_ID, /DIRECTORY) EQ 0 THEN BEGIN
   print, "No match under ", dir_block, " for ", site_ID
   goto, errorExit
ENDIF ELSE BEGIN
  ; get the list of available blockage files for this site
   blkfiles = FILE_SEARCH( dir_block+'/'+site_ID, $
                           site_ID+".BeamBlockage_*.sav", $
                           count=nf )
   IF nf EQ 0 THEN BEGIN
      print, "No .sav files found under ", dir_block+'/'+site_ID
      goto, errorExit
   ENDIF ELSE BEGIN
      IF (verbose) THEN print, "Blockage files: ", blkfiles
   ENDELSE
ENDELSE

; get the array of elevation angles for the sweeps
elev_angles = (mysweeps[*]).ELEVATIONANGLE
IF N_ELEMENTS(elev_angles) NE nswp THEN message, "Mismatch in # sweeps!"

for iswa=0,1 do begin
  scanType=swath[iswa]
 ; rename the data structure for the selected swath to a common name, and get
 ; the scan-type-specific metadata values
  CASE scanType OF
      'MS' : BEGIN
                dataCmb = TEMPORARY(data_ms)
                nfp = mygeometa.num_footprints_ms  ; # of PR rays in dataset
             END
      'NS' : BEGIN
                dataCmb = TEMPORARY(data_ns)
                nfp = mygeometa.num_footprints_ns  ; # of PR rays in dataset
             END
      ELSE : message, "Illegal SCANTYPE parameter, only MS or NS allowed."
  ENDCASE

; initialize an array of mean fraction of beam blockage having the dimension
; of the sweep-level data arrays in the netCDF file.  If there is no MS swath
; data in range then nfp is just 1 and all data is just Fill Value
avg_blockage = MAKE_ARRAY(nfp, nswp, /float, VALUE=FLOAT_RANGE_EDGE)

 ; determine whether there are any in-range MS data points.  If none, then skip
 ; blockage computations for the swath
  IF scanType EQ 'MS' AND mygeometa.have_swath_MS EQ 0 THEN BEGIN
     message, "No in-range MS scan samples.", /INFO
;     status = 1
     GOTO, noMSdata
  ENDIF

; get array indices of the non-bogus (i.e., "actual") PR footprints to cover the
; possibility that the matchup was performed with "MARK_EDGES" turned on.
idxpractual = where(dataCmb.scanNum GE 0L, countactual)
if (countactual EQ 0) then begin
   print, "No non-bogus data points, quitting case."
   status = 1
   goto, errorExit
endif

; define the list of elevations that have blockage files available
; according to their fixed strings in filename convention
blockageElevs_str = [ '00.50', '00.90', '01.30', '01.45', '01.50', '01.80', $
                      '02.40', '02.50', '03.10', '03.35', '03.50', '04.00', $
                      '04.30', '04.50', '05.10', '05.25', '06.00', '06.20', $
                      '06.40', '07.50', '08.00', '08.70', '09.90', '10.00', $
                      '12.00', '12.50', '14.00', '14.60', '15.60', '16.70', $
                      '19.50' ]
; numerical version of the above elevations
blockageElevs=FLOAT(blockageElevs_str)

; work our way through the available blockage files and compute mean blockage
; for the "actual" footprints
have_GR_blockage = NO_DATA_PRESENT
for iswp = 0, nswp-1 do begin
 ; find the nearest fixed angle to this measured sweep elevation
  ; -- for now we assume it's close enough to be valid
   nearest = -1L   ; array index of the nearest fixed angle
   diffmin = MIN( ABS(blockageElevs - elev_angles[iswp]), nearest )
  ; sanity check
   thisdiff = ABS(blockageElevs[nearest] - elev_angles[iswp])
   if thisdiff GT 0.5 THEN BEGIN
      print, "Elevation angle difference too large: "+STRING(thisdiff)
      print, myfiles
      stop
      goto, errorExit
   endif

  ; find the blockage file for this sweep
   thisfile = dir_block+'/'+site_ID+'/'+site_ID+".BeamBlockage_" $
              +blockageElevs_str[nearest]+".sav"
   idxfile = WHERE( blkfiles EQ thisfile, nblkfil )
   IF nblkfil EQ 1 THEN BEGIN
      have_GR_blockage = DATA_PRESENT
      blkstatus = compute_blockage( iswp, idxpractual, avg_blockage, thisfile, $
                                    site_lat, site_lon, dataCmb.latitude, $
                                    dataCmb.longitude, ZERO_FILL=0 )
      IF blkstatus NE 0 THEN BEGIN
         have_GR_blockage = NO_DATA_PRESENT
         avg_blockage[*,*] = FLOAT_RANGE_EDGE
         BREAK
      ENDIF
   ENDIF ELSE BEGIN
     ; if we have already found a blockage file and have run out of them, then
     ; we are above the last blocked level and just need to set blockages to zero
      IF have_GR_blockage EQ DATA_PRESENT THEN BEGIN
         blkstatus = compute_blockage( iswp, idxpractual, avg_blockage, ZERO_FILL=1 )
      ENDIF ELSE BEGIN
         message, "Never found expected blockage file."
      ENDELSE
   ENDELSE 
endfor

noMSdata:

; re-open the netCDF file copy in define mode and create
; a new 2-D blockage variable

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

if iswa EQ 0 then begin    ; define swath-independent variables only once
   haveBLKvarid = ncdf_vardef(cdfid, 'have_GR_blockage', /short)
   ncdf_attput, cdfid, haveBLKvarid, 'long_name', $
                'data exists flag for ground radar blockage fraction'
   ncdf_attput, cdfid, haveBLKvarid, '_FillValue', NO_DATA_PRESENT
endif

; field dimension
fpdimid = NCDF_DIMID(cdfid, 'fpdim_'+swath[iswa])
eldimid = NCDF_DIMID(cdfid, 'elevationAngle')

BLKvarid = ncdf_vardef(cdfid, 'GR_blockage_'+swath[iswa], [fpdimid,eldimid])
ncdf_attput, cdfid, BLKvarid, 'long_name', $
             'ground radar blockage fraction, '+swath[iswa]+' swath'
ncdf_attput, cdfid, BLKvarid, '_FillValue', FLOAT_RANGE_EDGE

; take the netCDF file out of Define mode and back into Write mode
ncdf_control, cdfid, /endef

; update the matchup file version and write the new data to the file variable
if iswa EQ 1 then begin
  ; only write swath-independent values once. Do this in NS swath mode, in case
  ; no MS overlap situation exists and have_GR_blockage was not evaluated
   versid = NCDF_VARID(cdfid, 'version')
   ncdf_varput, cdfid, versid, 1.2
   NCDF_VARPUT, cdfid, 'have_GR_blockage', have_GR_blockage
endif
NCDF_VARPUT, cdfid, 'GR_blockage_'+swath[iswa], avg_blockage

ncdf_close, cdfid

endfor    ; 2nd swath loop

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

pro append_cmb_blockage_geomatchnetcdf, ncsitepath, DIR_BLOCK=dir_block, $
                                        VERBOSE=verbose

IF N_ELEMENTS(ncsitepath) EQ 1 THEN pathpr=ncsitepath+'*' $
ELSE pathpr = '/data/gpmgv/netcdf/geo_match/GPM/2BDPRGMI/V03D/1_1/2014'

IF N_ELEMENTS(dir_block) NE 1 THEN dir_block = '/data/gpmgv/blockage'

; get a list of radars that have any blockage files, i.e., the list of
; subdirectories under dir_block
sitepaths = FILE_SEARCH( dir_block, '*', /TEST_DIRECTORY, count=nd )
IF nd EQ 0 THEN message, "No subdirs found under ", dir_block $
ELSE BEGIN
   sites = file_basename(sitepaths)
   IF KEYWORD_SET(verbose) THEN print, "Blockage subdirs: ", sites
ENDELSE

;for isite=0, nd-1 do begin
   prfiles = file_search(pathpr+'/'+'*.1_1.*', COUNT=nf)
   IF (nf LE 0) THEN BEGIN
      print, "" 
      print, "No files found for pattern = ", pathpr+'/*'+sites[isite]+'*.1_1.*'
      print, " -- Skipping."
      goto, errorExit
   ENDIF

   FOR fnum = 0, nf-1 DO BEGIN
;   FOR fnum = 0, 5 < (nf-1) DO BEGIN
      ncfilepr = prfiles(fnum)
      bname = file_basename( ncfilepr )
      parsed=STRSPLIT(bname, '.', /EXTRACT)
      this_site = parsed[1]
      IF TOTAL( STRMATCH(sites, this_site) ) EQ 1 THEN no_data=0 $
         ELSE no_data=1
      print, "GeoMatch netCDF file: ", ncfilepr
      append_blockage, ncfilepr, DIR_BLOCK=dir_block, NO_DATA=no_data
;      print, 'append_blockage, ', ncfilepr,', DIR_BLOCK=', dir_block,', NO_DATA=', no_data
   endfor
;endfor


errorExit:
end
