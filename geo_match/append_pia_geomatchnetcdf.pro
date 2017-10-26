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

; extract the needed path version/subset/year/month/day from
; a 2A GPM filename, e.g., compose path = 'V07/CONUS/2014/04/19' from
; 2A-CS-CONUS.TRMM.PR.2A25.20140419-S113024-E114401.093556.7.HDF.gz

  FUNCTION parse_2a_filename, origFileName

  parsed = STRSPLIT(origFileName, '.', /EXTRACT)
  parsed2 = STRSPLIT(parsed[0], '-', /EXTRACT)
  subset = parsed2[2]
  version = parsed[6]
  yyyymmdd = STRMID(parsed[4],0,4)+'/'+STRMID(parsed[4],4,2)+'/'+STRMID(parsed[4],6,2)
  path = 'V0'+version+'/'+subset+'/'+yyyymmdd
  return, path

  end

;===============================================================================

pro append_pia, mygeomatchfile, DIR_2A25=dir2a25

COMMON sample, start_sample, sample_range, num_range, RAYSPERSCAN

@geo_match_nc_structs.inc

; "Include" file for DATA_PRESENT, NO_DATA_PRESENT
@grid_def.inc
; "Include" files for constants, names, paths, etc.
@environs.inc   ; for file prefixes, netCDF file definition version
@pr_params.inc  ; for the type-specific fill values

idxncvers=STRPOS(mygeomatchfile, '3_0')
IF idxncvers EQ -1 THEN message, "File "+mygeomatchfile+" not named version 3_0."
len=STRLEN(mygeomatchfile)
outfile = STRMID(mygeomatchfile,0,idxncvers)+'3_1.nc'
print, '' & print, "Infile: ", mygeomatchfile

IF FILE_TEST(outfile+'.gz', /NOEXPAND_PATH) EQ 1 THEN BEGIN
   print, "Outfile already exists: ", outfile & print, ''
   GOTO, regularExit
ENDIF
print, "Outfile: ", outfile & print, ''
stop

;IF N_ELEMENTS( dir2a25 ) EQ 0 THEN dir2a25='/data/gpmgv/prsubsets/2A25'

; open the original netCDF file and read the metadata and pr_index field
cpstatus = uncomp_file( mygeomatchfile, myfile )
if(cpstatus eq 'OK') then begin
   status = 1   ; init to FAILED
   mygeometa={ geo_match_meta }
   myfiles={ input_files }
   status = read_geo_match_netcdf( myfile, matchupmeta=mygeometa, $
      sweepsmeta=mysweeps, sitemeta=mysite, fieldflags=myflags, $
      filesmeta=myfiles )
  ; create data field arrays of correct dimensions and read data fields
   nfp = mygeometa.num_footprints
   nswp = mygeometa.num_sweeps
   pr_index=lonarr(nfp)
   status = read_geo_match_netcdf( myfile, pridx_long=pr_index )
   if ( status NE 0 ) THEN GOTO, errorExit    ; open/read error
endif else begin
   goto, errorExit                            ; copy error
endelse

;help, myfiles
;help, pr_index

; read PIA field from the original 2A25 file named in the matchup file metadata
SAMPLE_RANGE=0
START_SAMPLE=0
num_range = NUM_RANGE_2A25
if myfiles.file_2a25 EQ 'UNDEFINED' $
   then message, "No 2A-25 file name in matchup netCDF file "+myfile

  ; figure out if we have a matchup based on the old static PR product paths
  ; or the new variable GPM-era 2A25 paths
   IF strpos(myfiles.file_2a25, 'TRMM.PR') EQ -1 THEN BEGIN
     ; it is old-style fixed path, just use default/input dir2A25
      file_2a25 = dir2a25+'/'+myfiles.file_2a25
   ENDIF ELSE BEGIN
     ; it is a GPM-era filename, get the varying path components and prepend
     ; the non-varying parts of the full path
      path_tail = parse_2a_filename( myfiles.file_2a25 )
      file_2A25='/data/gpmgv/orbit_subset/TRMM/PR/2A25/'+path_tail+'/'+myfiles.file_2a25
   ENDELSE

print, "Reading 2A25 file: ", file_2A25
status = read_pr_2a25_fields( file_2a25, PIA=pia )
if ( status NE 0 ) THEN GOTO, errorExit    ; open/read error

; extract the "final adjusted PIA estimate" subarray from the full 2A25 dataset
pia_total = REFORM( pia[0,*,*] )
;help, pia, pia_total

; make an array of PIA having the dimension of the single-level data arrays in
; the netCDF file
pia_tocdf = MAKE_ARRAY(mygeometa.num_footprints, /float, VALUE=FLOAT_RANGE_EDGE)

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

; cut out the 2A25 PIA values for the actual PR footprints in the matchup, and
; assign to the locations of the actual PR footprints in the netCDF PIA array
pia_tocdf[idxpractual] = pia_total[pr_idx_actual]
;help, pia_tocdf

; re-open the netCDF file copy in define mode and create a new 1-D PIA variable

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

havePIAvarid = ncdf_vardef(cdfid, 'have_PIA', /short)
ncdf_attput, cdfid, havePIAvarid, 'long_name', $
             'data exists flag for 2A-25 Path Integrated Attenuation'
ncdf_attput, cdfid, havePIAvarid, '_FillValue', NO_DATA_PRESENT

; field dimension
fpdimid = NCDF_DIMID(cdfid, 'fpdim')

PIAvarid = ncdf_vardef(cdfid, 'PIA', [fpdimid])
ncdf_attput, cdfid, PIAvarid, 'long_name', $
             '2A-25 Path Integrated Attenuation'
ncdf_attput, cdfid, PIAvarid, 'units', 'dBZ'
ncdf_attput, cdfid, PIAvarid, '_FillValue', FLOAT_RANGE_EDGE

; take the netCDF file out of Define mode and back into Write mode
ncdf_control, cdfid, /endef

; update the matchup file version and write the PIA data to the file variable
versid = NCDF_VARID(cdfid, 'version')
ncdf_varput, cdfid, versid, 3.1
NCDF_VARPUT, cdfid, 'PIA', pia_tocdf
NCDF_VARPUT, cdfid, 'have_PIA', DATA_PRESENT
print, "MAX PIA: ", max(pia_tocdf)
;
ncdf_close, cdfid

command = "mv -v "+myfile+' '+outfile
spawn, command
command2 = 'gzip '+outfile
spawn, command2

GOTO, regularExit
errorExit:
  print, 'Cannot copy/unzip geo_match netCDF file: ', mygeomatchfile
  print, cpstatus
  command3 = "rm -v " + myfile
  spawn, command3
  stop
regularExit:
END

pro append_pia_geomatchnetcdf, ncsitepath, DIR_2A25=dir2a25

IF N_ELEMENTS(ncsitepath) EQ 1 THEN pathpr=ncsitepath+'*' $
ELSE pathpr = '/data/gpmgv/netcdf/geo_match/GRtoPR.*.7.3_0.nc*'

IF N_ELEMENTS(dir2a25) NE 1 THEN dir2a25='/data/gpmgv/prsubsets/2A25'

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
   print, "GeoMatch netCDF file: ", ncfilepr

   append_pia, ncfilepr, DIR_2A25=dir2a25

endfor


errorExit:
end
