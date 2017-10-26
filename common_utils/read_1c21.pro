;+
; Copyright © 2008, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; AUTHOR:
;       Liang Liao
;       Caelum Research Corp.
;       Code 975, NASA/GSFC
;       Greenbelt, MD 20771
;       Phone: 301-614-5718
;       E-mail: lliao@priam.gsfc.nasa.gov
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-

;
; -- Read 1C21 products and output dbz normal sample data.
;    
; start_sample:  scan number to start reading
; sample_range:  numbers of scans to be read
; num_range:     range number (to be 140 for 1C21)
;
pro read_1c21, filename, DBZ=dbz_normalSample, GEOL=geolocation, $
               OCEANFLAG=landOceanFlag, Bins=binS, SCAN_TIME=scan_time, $
	       RAY_START=rayStart, FRACTIONAL=frac_orbit_num

common sample, start_sample,sample_range,num_range,pw_min

sd_id=HDF_SD_START(filename,/read)
HDF_SD_FILEINFO, sd_id, nmfsds, attributes
 ;Display the number of SD type of files
;   print, "# of MFSD = ", nmfsds
   
   if nmfsds gt 0 then begin
;         print,"                    Information about MFHDF DataSets "
;         print, ' '
;         print,"            NAME     IDL_Type  HDF_Type       Rank   Dimensions"
;         print,"          ---------  -------- ----------      ----  ------------"
;         print,"                     ------------- Atrribute Info -------------"
;         print
       ; FSD='(A10,"  ",A8,"  ",I4,"  ",I4)'
         for i=0,nmfsds-1 do begin
          sds_id=HDF_SD_SELECT(sd_id,i)
          HDF_SD_GETINFO,sds_id,name=n,ndims=r,type=t,natts=nats,dims=dims,$
                         hdf_type=h,unit=u,format=fmt,label=label
;          if r le 1 then FSD='(A20," ",A8," ",A12,3X,I4,3X,"[",I4,"] ",A)' $
;                   else FSD='(A20," ",A8," ",A12,3X,I4,3X,"["'+$
;                        STRING(r-1)+'(I5,","),I5,"] ",A)'
          
;          print,n,t,h,r,dims,u,FORMAT=FSD
          if i eq 0 then nsample=dims(2)
;          print 
;         help,n,r,t,nats,dims,u
;         help,fmt,label,range
          HDF_SD_ENDACCESS,sds_id
         endfor
      endif 

; Read data
; Read Normal Sample
;
 
if (START_SAMPLE eq 0) and (SAMPLE_RANGE le 1) then SAMPLE_RANGE=nsample

IF N_ELEMENTS(dbz_normalSample) GT 0 THEN BEGIN

start = [start_sample,0,0]
count = [sample_range,49,num_range]
stride = [1,1,1]

sds_id=HDF_SD_SELECT(sd_id,hdf_sd_nametoindex(sd_id,'normalSample'))
HDF_SD_GETDATA, sds_id, dbz_normalSample, START=start, COUNT=count, $
                STRIDE=stride, /noreverse
                
ENDIF                
; ----------------------                
 
IF N_ELEMENTS(geolocation) GT 0 THEN BEGIN
             
start = [0,0,start_sample]
count = [2,49,sample_range]
stride = [1,1,1]

sds_id=HDF_SD_SELECT(sd_id,hdf_sd_nametoindex(sd_id,'geolocation'))
HDF_SD_GETDATA, sds_id, geolocation, START=start, COUNT=count, $
                STRIDE=stride
ENDIF                 
; -----------------------

IF N_ELEMENTS(landOceanFlag) GT 0 THEN BEGIN

start = [start_sample,0]
count = [sample_range,49]
stride = [1,1]

sds_id=HDF_SD_SELECT(sd_id,hdf_sd_nametoindex(sd_id,'landOceanFlag'))
HDF_SD_GETDATA, sds_id, landOceanFlag, START=start, COUNT=count, $
                STRIDE=stride, /noreverse

ENDIF                 
; ----------------------- 

IF N_ELEMENTS(binS) GT 0 THEN BEGIN

start = [start_sample,0]
count = [sample_range,49]
stride = [1,1]

;sds_id=HDF_SD_SELECT(sd_id,hdf_sd_nametoindex(sd_id,'binSurfPeak'))
sds_id=HDF_SD_SELECT(sd_id,hdf_sd_nametoindex(sd_id,'binEllipsoid'))
HDF_SD_GETDATA, sds_id, binS, START=start, COUNT=count, $
                STRIDE=stride , /noreverse

ENDIF
; -----------------------  

                            
HDF_SD_ENDACCESS,sds_id
HDF_SD_END,sd_id

; -- Access Vdata

; Open the file for read and initialize the Vdata interface

    file_handle = hdf_open(filename,/read)
    
; Get the ID of the first Vdata in the file 

    vdata_ID = hdf_vd_getid(  file_handle, -1 )
    is_NOT_fakeDim = 1
    num_vdata = 0 
    
; Loop over Vdata 
    while (vdata_ID ne -1) and (is_NOT_fakeDim) do begin

; Attach to the vdata 
	vdata_H = hdf_vd_attach(file_handle,vdata_ID)

; Get vdata name
	hdf_vd_get, vdata_H, name=name,size= size, nfields = nfields
         
; Detach vdata
	hdf_vd_detach, vdata_H
       
; Check to see if this is a dummy
; Can't really explain why this happens but sometimes a dummy dimension
; gets returned as a Vdata name depending on the HDF file.  
	is_NOT_fakeDim = strpos(name,'fakeDim') eq -1

; Build up the list of Vdata names,sizes and number of fields 
	if (num_vdata eq 0) then begin
	    Vdata_name = name 
	    Vdata_size = size
	    Vdata_nfields = nfields
	    num_vdata = 1
	endif else if is_NOT_fakeDim then begin
	    Vdata_name = [Vdata_name,name]
            Vdata_size = [Vdata_size,size]
            Vdata_nfields = [Vdata_nfields,nfields]
	    num_vdata = num_vdata + 1
	endif
       
; Get ID of next Vdata
	vdata_ID = hdf_vd_getid( file_handle, vdata_ID )

    endwhile 

; Print out the list of names   
;    print,''   
;    print, 'List of Vdata names    Size (bytes)   Num. Fields'
;    print, '-------------------------------------------------'
;    for i = 0,num_vdata-1  do begin
;	print, Vdata_name(i),Vdata_size(i),Vdata_nfields(i),$
;	       format='(A18,I10,I14)'
;    endfor
;    print, '-------------------------------------------------'


IF N_ELEMENTS(frac_orbit_num) GT 0 THEN BEGIN
  print, ""
  print, "Getting frac_orbit_num vdata."
  print, ""

; Find the Scan status Vdata
  vdata_ID = hdf_vd_find(file_handle,'pr_scan_status')

; Attach to this Vdata
  vdata_H = hdf_vd_attach(file_handle,vdata_ID)

; Get the Vdata stats
  hdf_vd_get,vdata_H,name=name,fields=raw_field

; Separate the fields
  fields = str_sep(raw_field,',')

; Read the Vdata, returns the number of records
; The data for all records is returned in a BYTE ARRAY of (record_size,nscans)
; IDL will issue a warning to remind you there are mixed data types in
; the array
  nscan = hdf_vd_read(vdata_h,data)
; Could have just read in the fractional orbit number with the
; fields keyword but this shows you how to extract the data from the 
; full record BYTE array.

; Make up an array for the fractional orbit number
  frac_orbit_num = fltarr(nscan)

; Loop over the records and pull out the fractional orbit number   
  for i = 0,nscan-1 do begin
; We know that the frac_orbit_number starts at position 11 in the byte array
    frac_orbit_num(i) = float(data(*,i),11)
  endfor
  
  hdf_vd_detach, Vdata_H   ; Detach from the Vdata

ENDIF

IF N_ELEMENTS(scan_time) GT 0 THEN BEGIN

; get the scantime vdata

  vdata_ID = hdf_vd_find(file_handle,'scan_time')
  vdata_H = hdf_vd_attach(file_handle,vdata_ID)
  nscan = hdf_vd_read(vdata_H, scan_time)
  hdf_vd_detach, Vdata_H   ; Detach from the Vdata
   
ENDIF

IF N_ELEMENTS(rayStart) GT 0 THEN BEGIN
; get the header vdata

  vdata_ID = hdf_vd_find(file_handle,'RAY_HEADER')
  vdata_H = hdf_vd_attach(file_handle,vdata_ID)
  hdf_vd_get,vdata_H,name=name,fields=raw_field
  fields = strsplit( raw_field, ',', /EXTRACT )
  nscan = hdf_vd_read(vdata_H, data)
;PRINT, 'NSCAN = ', nscan
  rayStart = intarr(nscan)
;  rayStart[*]=data[0,*]
  for raynum = 0, nscan-1 do begin
    rayStart[raynum]= fix(data[*,raynum],0)
  endfor
  hdf_vd_detach, Vdata_H   ; Detach from the Vdata
;help, data
;print, data[0,*]
;print, data[1,*]
;help, rayStart
;print, rayStart
ENDIF

hdf_close,file_handle    ; Close the hdf file 

end
