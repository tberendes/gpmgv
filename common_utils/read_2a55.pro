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

pro read_2a55, filename, DBZ=threeDreflect, VPROF=vertProfile, CFA=cfadData, $
    hour, minute, second, scalefacDBZ
 
sd_id=HDF_SD_START(filename,/read)
HDF_SD_FILEINFO, sd_id, nmfsds, attributes
 ;Display the number of SD type of files
;   print, "# of MFSD = ", nmfsds
   
   if nmfsds gt 0 then begin
;         print,"          Information about MFHDF DataSets "
;         print, ' '
;         print,"  NAME     IDL_Type  HDF_Type       Rank   Dimensions"
;         print,"---------  -------- ----------      ----  ------------"
;         print,"           ------------- Atrribute Info -------------"
;         print
         FSD='(A13,"  ",A8,"  ",I4,"  ",I4)'
         for i=0,nmfsds-1 do begin
          sds_id=HDF_SD_SELECT(sd_id,i)
          HDF_SD_GETINFO,sds_id,name=n,ndims=r,type=t,natts=nats,dims=dims,$
                         hdf_type=h,unit=u,format=fmt,label=label
          if r le 1 then FSD='(A13," ",A8," ",A12,3X,I4,3X,"[",I4,"] ",A)' $
                   else FSD='(A13," ",A8," ",A12,3X,I4,3X,"["'+$
                        STRING(r-1)+'(I5,","),I5,"] ",A)'
          
;          print,n,t,h,r,dims,u,FORMAT=FSD
;         help,n,r,t,nats,dims,u
;         help,fmt,label,range
          HDF_SD_ENDACCESS,sds_id

          if n eq "threeDreflect" then begin
            if dims[3] eq 0  then begin
              print, "Quitting file read, empty Z array in product!"
              HDF_SD_END,sd_id
              hour = -99 & minute = -99 & second = -99
              return
            endif
          endif

         endfor
      endif 

; Read data
;
 
IF keyword_set(threeDreflect) THEN BEGIN
 
;start = [0,0,0,0]
;count = [151,151,13,11]
;stride = [1,1,1,1]

sds_id=HDF_SD_SELECT(sd_id,hdf_sd_nametoindex(sd_id,'threeDreflect'))
HDF_SD_GETDATA, sds_id, threeDreflect
                ;START=start, COUNT=count,STRIDE=stride 
                
ENDIF                
; ----------------------                
 
IF keyword_set(vertProfile) THEN BEGIN
             
start = [0,0,0]
count = [12,13,11]
stride = [1,1,1]

sds_id=HDF_SD_SELECT(sd_id,hdf_sd_nametoindex(sd_id,'vertProfile'))
HDF_SD_GETDATA, sds_id, vertProfile, START=start, COUNT=count, $
                STRIDE=stride
ENDIF                 
; -----------------------

IF keyword_set(cfadData) THEN BEGIN

start = [0,0,0,0]
count = [12,86,13,11]
stride = [1,1,1,1]

sds_id=HDF_SD_SELECT(sd_id,hdf_sd_nametoindex(sd_id,'cfadData'))
HDF_SD_GETDATA, sds_id, cfadData, START=start, COUNT=count, $
                STRIDE=stride
ENDIF                 
; ----------------------- 
                              
HDF_SD_ENDACCESS,sds_id
HDF_SD_END,sd_id

;:::::::::: Display and Read Vdata :::::::::::::::

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

; Find the VOS time Vdata
    vdata_ID = hdf_vd_find(file_handle,'Time')
;    print, 'Time ID = ', vdata_ID

; Attach to this Vdata
    vdata_H = hdf_vd_attach(file_handle,vdata_ID)
; Get the Vdata stats
    hdf_vd_get,vdata_H,name=name,fields=raw_field
;    print, 'name: ', name

; Separate the fields
    fields = strsplit( raw_field, ',', /extract )
;    print, 'fields: ', fields
; Read the Vdata, returns the number of records
; The data for all records is returned in a BYTE ARRAY of (record_size,nscans)
; IDL will issue a warning to remind you there are mixed data types in
; the array
    nvol = hdf_vd_read(vdata_h,data)
;   help, data

; Make up an array for hour of time
    hour = intarr(nvol)
    minute = intarr(nvol)
    second = intarr(nvol)

; Loop over the records and pull out the VOS start time fields   
    for i = 0,nvol-1 do begin

      hour[i] = data[0,i]
      minute[i] = data[1,i]
      second[i] = data[2,i]
    endfor

; Detach from the Vdata
    hdf_vd_detach, Vdata_H

; Find the reflectivity scale_factor Vdata.  It is the first of multiple vdatas
; with the name "scale_factor", so we just take the one returned by the call as
; we don't need the others at this time.
    vdata_IDsf = hdf_vd_find(file_handle,'scale_factor')
;    print, 'scale_factor ID = ', vdata_IDsf
; Attach to this Vdata
    vdata_H2 = hdf_vd_attach(file_handle,vdata_IDsf)
; Get the Vdata stats
    hdf_vd_get,vdata_H2,name=name2,fields=raw_field2

; Separate the fields
    fields2 = strsplit( raw_field2, ',', /extract )
;    print, 'fields2: ', fields2
;    HDF_VD_GETINFO, vdata_H2, fields2[0], ORDER=order2,SIZE=size2,TYPE=type2
;    print, 'name2: ',name2,'  fields2: ', fields2,'  order: ',order2, $
;           '  size: ',size2, '  type: ',type2
; Read the Vdata, returns the number of records
    nvol2 = hdf_vd_read(vdata_h2,data2)
;    help, data2
; Only need one value for scale_factor, shouldn't change from one VOS to another
    scalefacDBZ = data2[0,0]
;print, 'scalefacDBZ: ', scalefacDBZ

   hdf_vd_detach, Vdata_H2


; Close the hdf file
    hdf_close,file_handle   
 
end
