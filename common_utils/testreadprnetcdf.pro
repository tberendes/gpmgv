;===============================================================================
;+
; Copyright © 2008, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; testreadprnetcdf.pro           Morris/SAIC/GPM_GV      February 2008
;
; DESCRIPTION
; -----------
; Test driver for function read_pr_netcdf.pro
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;===============================================================================

pro testreadprnetcdf

@grid_nc_structs.inc

myprfile='/data/tmp/PRgrids.DARW.051227.46247.test.nc.gz'
cpstatus = uncomp_file( myprfile, myfile )
if(cpstatus eq 'OK') then begin
  status = 1   ; init to FAILED
  mytime=0.0D
  mytxttime=''
  mygrid=grid_meta
  mysite=site_meta
  myflags=field_flagsPR
  zraw=fltarr(2)
  zcor=fltarr(2)
  rain3=fltarr(2)
  sfctyp=intarr(2)
  sfcrain=fltarr(2)
  sfcraincomb=fltarr(2)
  bb=intarr(2)
  rnflag=intarr(2)
  rntype=intarr(2)
  angle=intarr(2)

  status = read_pr_netcdf( myfile, dtime=mytime, txtdtime=mytxttime, $
    gridmeta=mygrid, sitemeta=mysite, fieldflags=myflags, $
    dbz3d=zcor, dbzraw3d=zraw, rain3d=rain3, sfctype2d_int=sfctyp, $
    sfcrain2d=sfcrain, sfcraincomb2d=sfcraincomb, bbhgt2d_int=BB, $
    rainflag2d_int=rnFlag, raintype2d_int=rnType, angleidx2d_int=angle )

  command3 = "rm  " + myfile
  spawn, command3
endif else begin
  print, 'Cannot copy/unzip PR netCDF file: ', myprfile
  print, cpstatus
  command3 = "rm  " + myfile
  spawn, command3
  goto, errorExit
endelse

if ( status NE 0 ) THEN GOTO, errorExit

STOP
print, mytime
STOP
print, mytxttime
STOP
print, mygrid
STOP
print, mysite
STOP
print, myflags
STOP
help, zraw
STOP
print, zraw[*,mygrid.ny/2,0]
STOP
help, zcor
STOP
print, zcor[*,mygrid.ny/2,0]
STOP
help, rain3
STOP
print, rain3[*,mygrid.ny/2,0]
STOP
help, sfctyp
STOP
print, sfctyp[*,mygrid.ny/2]
STOP
help, sfcrain
STOP
print, sfcrain[*,mygrid.ny/2]
STOP
help, sfcraincomb
STOP
print, sfcraincomb[*,mygrid.ny/2]
STOP
help, bb
STOP
print, bb[*,mygrid.ny/2]
STOP
help, rnflag
STOP
print, rnflag[*,mygrid.ny/2]
STOP
help, rntype
STOP
print, rntype[*,mygrid.ny/2]
STOP
help, angle
STOP
print, angle[*,mygrid.ny/2]

errorExit:
END
