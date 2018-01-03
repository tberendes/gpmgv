;===============================================================================
;+
; Copyright © 2008, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; testreadgvreonetcdf.pro           Morris/SAIC/GPM_GV      February 2008
;
; DESCRIPTION
; -----------
; Test driver for function read_gv_reo_netcdf.pro
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;===============================================================================

pro testreadgvreonetcdf

@grid_nc_structs.inc

mygvfile='/data/tmp/GVgridsREO.DARW.051227.46247.test.nc.gz'
cpstatus = uncomp_file( mygvfile, myfile )
if(cpstatus eq 'OK') then begin
  status = 1   ; init to FAILED
  mytime=0L
  mygrid=grid_meta
  mysite=site_meta
  myflags=field_flagsGV
  zcor=fltarr(2)

  status = read_gv_reo_netcdf( myfile, dtime=mytime, $
    gridmeta=mygrid, sitemeta=mysite, fieldflagsGV=myflags, $
    dbz3d=zcor )

  command3 = "rm  " + myfile
  spawn, command3
endif else begin
  print, 'Cannot copy/unzip GV REO netCDF file: ', mygvfile
  print, cpstatus
  command3 = "rm  " + myfile
  spawn, command3
  goto, errorExit
endelse

if ( status NE 0 ) THEN GOTO, errorExit

STOP
print, mytime
STOP
print, mygrid
STOP
print, mysite
STOP
print, myflags
STOP
help, zcor
STOP
print, zcor[*,mygrid.ny/2,0]

errorExit:
END
