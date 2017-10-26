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

pro testappendgeomatchnetcdf, DIR_2A25=dir2a25

COMMON sample, start_sample, sample_range, num_range, RAYSPERSCAN

@geo_match_nc_structs.inc

; "Include" file for DATA_PRESENT, NO_DATA_PRESENT
@grid_def.inc
; "Include" files for constants, names, paths, etc.
@environs.inc   ; for file prefixes, netCDF file definition version
@pr_params.inc  ; for the type-specific fill values

mygeomatchfile='/data/gpmgv/netcdf/geo_match/GRtoPR.KAMX.140131.92335.7.3_0.nc.gz'
;mygeomatchfile='/tmp/GRtoPR.KAMX.140131.92335.7.3_0.nc.gz'
idxncvers=STRPOS(mygeomatchfile, '3_0')
IF idxncvers EQ -1 THEN message, "File "+mygeomatchfile+" not named version 3_0."
len=STRLEN(mygeomatchfile)
outfile = STRMID(mygeomatchfile,0,idxncvers)+'3_1.nc'
print, '' & print, "Infile: ", mygeomatchfile
print, "Outfile: ", outfile & print, ''
;mygeomatchfile='/tmp/file.nc'

IF N_ELEMENTS( dir2a25 ) EQ 0 THEN dir2a25='/data/gpmgv/prsubsets/2A25'

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

help, myfiles
help, pr_index

; read PIA field from the original 2A25 file named in the matchup file metadata
SAMPLE_RANGE=0
START_SAMPLE=0
num_range = NUM_RANGE_2A25
if myfiles.file_2a25 EQ 'UNDEFINED' $
   then message, "No 2A-25 file name in matchup netCDF file "+myfile
file_2a25 = dir2a25+'/'+myfiles.file_2a25
status = read_pr_2a25_fields( file_2a25, PIA=pia )
if ( status NE 0 ) THEN GOTO, errorExit    ; open/read error

; extract the "final adjusted PIA estimate" subarray from the full 2A25 dataset
pia_total = REFORM( pia[0,*,*] )
help, pia, pia_total

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
help, pia_tocdf

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
;
; field dimension
;fpdimid = ncdf_dimdef(cdfid, 'fpdim', mygeometa.num_footprints)  ; # of PR footprints within range
fpdimid = NCDF_DIMID(cdfid, 'fpdim')

sfrainvarid = ncdf_vardef(cdfid, 'PIA', [fpdimid])
ncdf_attput, cdfid, sfrainvarid, 'long_name', $
             '2A-25 Path Integrated Attenuation'
ncdf_attput, cdfid, sfrainvarid, 'units', 'dBZ'
ncdf_attput, cdfid, sfrainvarid, '_FillValue', FLOAT_RANGE_EDGE

; take the netCDF file out of Define mode and back into Write mode
ncdf_control, cdfid, /endef

; update the matchup file version and write the PIA data to the file variable
versid = NCDF_VARID(cdfid, 'version')
ncdf_varput, cdfid, versid, 3.1
NCDF_VARPUT, cdfid, 'PIA', pia_tocdf

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
  command3 = "rm  " + myfile
  spawn, command3
regularExit:
END
