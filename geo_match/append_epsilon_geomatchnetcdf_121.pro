;===============================================================================
;+
; Copyright © 2015, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; append_epsilon_geomatchnetcdf_121.pro       Morris/SAIC/GPM_GV      Feb 2016
;
; DESCRIPTION
; -----------
; Program to add new volume-match 'have_Epsilon' variable to version 1_3 DPR
; matchup files that were created by running append_epsilon_geomatchnetcdf
; to add Epsilon and n_dpr_epsilon_gates_reject to the version 1_21 GRtoDPR
; netcdf files.  This version adds the originally-missed have_Epsilon variable
; to a copy of the 1_3 file, and then writes/overwrites this modified 1_3 file
; back to the original version 1_21 filename, also resetting the internal
; 'version' value back to 1_21.
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

pro append_epsilon, mygeomatchfile, DIR_BLOCK=dir_block, NAME_ADD=name_add, $
                    DIR_2A=dir_2a

@dpr_geo_match_nc_structs.inc
; "Include" file for DATA_PRESENT, NO_DATA_PRESENT
@grid_def.inc
; "Include" files for constants, names, paths, etc.
@environs.inc   ; for file prefixes, netCDF file definition version
@dpr_params.inc  ; for the type-specific fill values

VERBOSE=1

; replace /1_3/ in path with /1_21/
len=STRLEN(mygeomatchfile)
idxverdir=STRPOS(mygeomatchfile, '/1_3/')
file13=STRMID(mygeomatchfile,0,idxverdir) + '/1_21/' $
      + STRMID(mygeomatchfile,idxverdir+5, len-(idxverdir+5))
; make sure this new directory exists
IF FILE_TEST( FILE_DIRNAME(file13), /DIRECTORY ) EQ 0 THEN $
   spawn, 'mkdir -p ' + FILE_DIRNAME(file13)
IF N_ELEMENTS(name_add) EQ 1 THEN BEGIN
  ; replace "1_3."+name_add in basename with "1_21."+name_add
   idxncvers=STRPOS(file13, '1_3.'+name_add)
   IF idxncvers EQ -1 THEN message, "File "+mygeomatchfile+" not named version 1_3."+name_add
   outfile = STRMID(file13,0,idxncvers) + '1_21.' + name_add + '.nc'
ENDIF ELSE BEGIN 
  ; replace "1_3." in basename with "1_21."
   idxncvers=STRPOS(file13, '1_3.')
   IF idxncvers EQ -1 THEN message, "File "+mygeomatchfile+" not named version 1_3."
   outfile = STRMID(file13,0,idxncvers)+'1_21.nc'
ENDELSE
;outfile = file13
print, '' & print, "Infile: ", mygeomatchfile

IF FILE_TEST(outfile+'.gz', /NOEXPAND_PATH) EQ 1 THEN BEGIN
   print, "Outfile already exists: ", outfile+'.gz' & print, ''
   ;GOTO, regularExit
ENDIF ELSE BEGIN
   print, "Outfile does not exist: ", outfile+'.gz' & print, ''
   stop
ENDELSE

; open the original netCDF file and read the metadata and lat and lon fields
cpstatus = uncomp_file( mygeomatchfile, myfile )
if(cpstatus eq 'OK') then begin

; open the netCDF file copy in define mode and create
; the new epsilon variable

cdfid = NCDF_OPEN( myfile, /WRITE )
IF ( N_Elements(cdfid) EQ 0 ) THEN BEGIN
   print, ''
   print, "ERROR, file copy ", myfile, " is not a valid netCDF file!"
   print, ''
   status = 1
   goto, errorExit
ENDIF

; get ID of variable we need to rename
renvarid = ncdf_varid(cdfid, 'n_dpr_epsilon_gates_rejected')

; take the netCDF file out of Write mode and into Define mode
ncdf_control, cdfid, /redef

; rename the variable "n_dpr_epsilon_gates_rejected" to "n_dpr_epsilon_rejected"
ncdf_varrename, cdfid, renvarid, 'n_dpr_epsilon_rejected'

haveEpsvarid = ncdf_vardef(cdfid, 'have_Epsilon', /short)
ncdf_attput, cdfid, haveEpsvarid, 'long_name', $
             'data exists flag for DPR Epsilon variable'
ncdf_attput, cdfid, haveEpsvarid, '_FillValue', NO_DATA_PRESENT

; take the netCDF file out of Define mode and back into Write mode
ncdf_control, cdfid, /endef

; update the matchup file version and write the new data to the file variable
versid = NCDF_VARID(cdfid, 'version')
ncdf_varput, cdfid, versid, 1.21
NCDF_VARPUT, cdfid, 'have_Epsilon', DATA_PRESENT

ncdf_close, cdfid

command = "mv -v "+myfile+' '+outfile
spawn, command
command2 = 'gzip -f '+outfile
spawn, command2

GOTO, regularExit

endif

errorExit:
  print, 'Cannot process geo_match netCDF file: ', mygeomatchfile
  print, cpstatus
  command3 = "rm -v " + myfile
  spawn, command3

regularExit:

END

;===============================================================================

pro append_epsilon_geomatchnetcdf_121, ncsitepath, DIR_2A=dir_2a, $
                                   NAME_ADD=name_add, VERBOSE=verbose

IF N_ELEMENTS(ncsitepath) EQ 1 THEN pathpr=ncsitepath+'*' $
ELSE pathpr = '/data/gpmgv/netcdf/geo_match/GPM/2ADPR/NS/V04A/1_3'

IF N_ELEMENTS(dir_2a) NE 1 THEN dir_2a='/data/gpmgv/orbit_subset/GPM'
IF N_ELEMENTS(name_add) EQ 1 THEN addme=name_add+'.nc' ELSE addme='nc'

   prfiles = file_search(pathpr, 'GRtoDPR.*.1_3.'+addme+'*', COUNT=nf)
   IF (nf LE 0) THEN BEGIN
      print, "" 
      print, "No files found for pattern = ", pathpr+'/*/GRtoDPR.*.1_3.'+addme+'*'
      print, " -- Skipping."
      goto, errorExit
   ENDIF

FOR fnum = 0, nf-1 DO BEGIN
;   FOR fnum = 0, 0 < (nf-1) DO BEGIN
   print, '--------------------------------------------------------------------'
   ncfilepr = prfiles(fnum)
   bname = file_basename( ncfilepr )
   print, "Do GeoMatch netCDF file: ", bname
   append_epsilon, ncfilepr, NAME_ADD=name_add, DIR_2A=dir_2a
endfor

errorExit:
end
