;===============================================================================
;+
; Copyright © 2014, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; test_read_dprgmi_geomatch_netcdf.pro     Morris/SAIC/GPM_GV      August 2014
;
; DESCRIPTION
; -----------
; Test driver for function read_dprgmi_geo_match_netcdf.pro
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;===============================================================================

pro test_read_dprgmi_geomatch_netcdf, mygeomatchfile

@dprgmi_geo_match_nc_structs.inc

if n_elements(mygeomatchfile) eq 0 then begin
   filters = ['GRtoDPRGMI.*']
   mygeomatchfile=dialog_pickfile(FILTER=filters, $
       TITLE='Select GRtoDPRGMI file to read', $
       PATH='/data/gpmgv/netcdf/geo_match/GPM/2BDPRGMI')
   IF (mygeomatchfile EQ '') THEN GOTO, errorExit
endif

cpstatus = uncomp_file( mygeomatchfile, myfile )
if(cpstatus eq 'OK') then begin
  status = 1   ; init to FAILED
  mygeometa={ dprgmi_geo_match_meta }
  mysweeps={ gr_sweep_meta }
  mysite={ gr_site_meta }
  myflags={ dprgmi_gr_field_flags }
  myfiles={ dprgmi_gr_input_files }
  data_ms = 1    ; INITIALIZE AS ANYTHING, WILL BE REDEFINED IN READ CALL
  data_ns = 1    ; DITTO

  status = read_dprgmi_geo_match_netcdf( myfile, matchupmeta=mygeometa, $
     sweepsmeta=mysweeps, sitemeta=mysite, fieldflags=myflags, $
     DATA_MS=data_MS, DATA_NS=data_NS )

  command3 = "rm  " + myfile
  spawn, command3
  if ( status NE 0 ) THEN BEGIN
     help, status
     GOTO, errorExit
  ENDIF
endif else begin
  print, 'Cannot copy/unzip geo_match netCDF file: ', mygeomatchfile
  print, cpstatus
  command3 = "rm  " + myfile
  spawn, command3
  goto, errorExit
endelse

print, ''
help, mygeometa, /struct
print, ''
help, mysweeps
print, ''
print, mysweeps
print, ''
print, mysite
print, ''
print, myflags
print, ''
print, myfiles
STOP

help, data_MS, /struct
STOP

help, data_NS, /struct
STOP

PRINT, "" & PRINT, "Done."
errorExit:
END
