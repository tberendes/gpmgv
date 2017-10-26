;+
; Copyright © 2008, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; read_1c21_ppi.pro -- Read 1C21 products and output dbz normal sample data.
;
; AUTHOR:
;       Liang Liao
;       Caelum Research Corp.
;       Code 975, NASA/GSFC
;       Greenbelt, MD 20771
;       Phone: 301-614-5718
;       E-mail: lliao@priam.gsfc.nasa.gov
; MODIFIED:
;       Jul 2008 - Bob Morris, GPM GV (SAIC)
;       - Made into FUNCTION, added HDF_OPEN tests a la load_2b31
;       Aug 2008 - Bob Morris, GPM GV (SAIC)
;       - Added vdata elements scan_time, frac_orbit_num, rayStart
;       Oct 2009 - Bob Morris, GPM GV (SAIC)
;       - Added capability to read Version 7 test data files from PPS
;       Jan 2010 - Bob Morris, GPM GV (SAIC)
;       - Added RAY_SIZE, ANGLE, and START_DIST keyword variables able to be
;         read from V6 files (in Vdata).
;       Sep 2010 - Bob Morris, GPM GV (SAIC)
;       - Added capability to read scan_time, rayStart, raySize, angle,
;         and startDist for V7
;       March 2012 - Bob Morris, GPM GV (SAIC)
;       - Added error catching to the hdf_sd_getdata() calls to gracefully fail
;         in the event of bad SD data in an otherwise valid HDF file.
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-

; start_sample:  scan number to start reading
; sample_range:  numbers of scans to be read
; num_range:     range number (to be 140 for 1C21)


function read_1c21_ppi, filename, DBZ=dbz_normalSample, GEOL=geolocation, $
                        OCEANFLAG=landOceanFlag, Bins=binS, $
                        SCAN_TIME=scan_time, FRACTIONAL=frac_orbit_num, $
                        RAY_START=rayStart, RAY_SIZE=raySize, ANGLE=angle, $
                        START_DIST=startDist

common sample, start_sample,sample_range,num_range,pw_min

if HDF_IsHDF (filename) then begin
    fileid=hdf_open(filename,/read)
    if ( fileid eq -1 ) then begin
       print, "In read_1c21_ppi.pro, error opening hdf file: ", filename
       flag = 'Bad HDF File!'
       return, flag
    endif
endif else begin
    print, "In read_1c21_ppi.pro, tried to open non-hdf file: ", filename
    flag = 'Not HDF File!'
    return, flag
endelse

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
         FSD='(A10,"  ",A8,"  ",I4,"  ",I4)'
         for i=0,nmfsds-1 do begin
          sds_id=HDF_SD_SELECT(sd_id,i)
          HDF_SD_GETINFO,sds_id,name=n,ndims=r,type=t,natts=nats,dims=dims,$
                         hdf_type=h,unit=u,format=fmt,label=label
          if r le 1 then FSD='(A10," ",A8," ",A12,3X,I4,3X,"[",I4,"] ",A)' $
                   else FSD='(A10," ",A8," ",A12,3X,I4,3X,"["'+$
                        STRING(r-1)+'(I5,","),I5,"] ",A)'
          
;          print,n,t,h,r,dims,u,FORMAT=FSD
;          if i eq 0 then nsample=dims(2)

         ; Determine whether the file is version 6 or 7 by dataset names
         ; used for lat/lon information.  Geolocation is a 3-D array holding
         ; both variables in v6.  Latitude and longitude are separate 2-D
         ; arrays in v7.
          if n EQ 'geolocation' then begin
             nsample=dims(2)
             trmmversion = 6
          endif
          if n EQ 'Latitude' then begin
             nsample=dims(1)
             trmmversion = 7
          endif

;          print 
;         help,n,r,t,nats,dims,u
;         help,fmt,label,range
          HDF_SD_ENDACCESS,sds_id
         endfor
      endif  else begin
         print, "In read_1c21_ppi.pro, SD error in hdf file: ", filename
	 flag = 'Bad HDF File, no SDs!'
	 return, flag
   endelse

; Read data
; Read Normal Sample
;
 
if (START_SAMPLE eq 0) and (SAMPLE_RANGE le 1) then SAMPLE_RANGE=nsample

IF N_ELEMENTS(dbz_normalSample) GT 0 THEN BEGIN
   start = [start_sample,0,0]
   count = [sample_range,49,num_range]
   stride = [1,1,1]

   Catch, err_sts
   IF err_sts EQ 0 THEN BEGIN
      sds_id=HDF_SD_SELECT(sd_id,hdf_sd_nametoindex(sd_id,'normalSample'))
      HDF_SD_GETDATA, sds_id, dbz_normalSample, START=start, COUNT=count, $
                STRIDE=stride, /noreverse
   ENDIF ELSE BEGIN
      help,!error_state,/st
      Catch, /Cancel
      print, 'hdf_sd_getdata(): err=',err_sts
      HDF_Close, fileid
      print, "In read_1c21_ppi.pro, SD error in hdf file: ", filename
      flag = 'Bad SD: normalSample'
      return, flag
   ENDELSE
ENDIF

; ----------------------                
 
IF N_ELEMENTS(geolocation) GT 0 THEN BEGIN
   print, 'PR 1C21 version: ', trmmversion
   CASE trmmversion OF
     6: begin
          start = [0,0,start_sample]
          count = [2,49,sample_range]
          stride = [1,1,1]

          Catch, err_sts
          IF err_sts EQ 0 THEN BEGIN
             sds_id=HDF_SD_SELECT(sd_id,hdf_sd_nametoindex(sd_id,'geolocation'))
             HDF_SD_GETDATA, sds_id, geolocation, START=start, COUNT=count, $
                   STRIDE=stride
          ENDIF ELSE BEGIN
             help,!error_state,/st
             Catch, /Cancel
             print, 'hdf_sd_getdata(): err=',err_sts
             HDF_Close, fileid
             print, "In read_1c21_ppi.pro, SD error in hdf file: ", filename
             flag = 'Bad SD: geolocation'
             return, flag
          ENDELSE
        end
     7: begin
          start = [0,start_sample]
          count = [49,sample_range]
          stride = [1,1]

         ; get latitude and longitude and pack into a 3-D 'geolocation' array
         ; to match the v6 lat/lon data format
          Catch, err_sts
          IF err_sts EQ 0 THEN BEGIN
             sds_id=HDF_SD_SELECT(sd_id,hdf_sd_nametoindex(sd_id,'Latitude'))
             HDF_SD_GETDATA, sds_id, latitude, START=start, COUNT=count, $
                   STRIDE=stride
          ENDIF ELSE BEGIN
             help,!error_state,/st
             Catch, /Cancel
             print, 'hdf_sd_getdata(): err=',err_sts
             HDF_Close, fileid
             print, "In read_1c21_ppi.pro, SD error in hdf file: ", filename
             flag = 'Bad SD: Latitude'
             return, flag
          ENDELSE
          Catch, err_sts
          IF err_sts EQ 0 THEN BEGIN
             sds_id=HDF_SD_SELECT(sd_id,hdf_sd_nametoindex(sd_id,'Longitude'))
             HDF_SD_GETDATA, sds_id, longitude, START=start, COUNT=count, $
                   STRIDE=stride
          ENDIF ELSE BEGIN
             help,!error_state,/st
             Catch, /Cancel
             print, 'hdf_sd_getdata(): err=',err_sts
             HDF_Close, fileid
             print, "In read_1c21_ppi.pro, SD error in hdf file: ", filename
             flag = 'Bad SD: Longitude'
             return, flag
          ENDELSE

          lldims = SIZE(latitude)
          geolocation = FLTARR(2,lldims[1],lldims[2])
          help, lldims, latitude, geolocation
          geolocation[0,*,*] = latitude
          geolocation[1,*,*] = longitude
        end
   ENDCASE             
ENDIF

; -----------------------

IF N_ELEMENTS(landOceanFlag) GT 0 THEN BEGIN
   start = [start_sample,0]
   count = [sample_range,49]
   stride = [1,1]

   Catch, err_sts
   IF err_sts EQ 0 THEN BEGIN
      sds_id=HDF_SD_SELECT(sd_id,hdf_sd_nametoindex(sd_id,'landOceanFlag'))
      HDF_SD_GETDATA, sds_id, landOceanFlag, START=start, COUNT=count, $
                STRIDE=stride, /noreverse
   ENDIF ELSE BEGIN
      help,!error_state,/st
      Catch, /Cancel
      print, 'hdf_sd_getdata(): err=',err_sts
      HDF_Close, fileid
      print, "In read_2a25_ppi.pro, SD error in hdf file: ", filename
      flag = 'Bad SD: landOceanFlag'
      return, flag
   ENDELSE
ENDIF

; ----------------------- 

IF N_ELEMENTS(binS) GT 0 THEN BEGIN

   start = [start_sample,0]
   count = [sample_range,49]
   stride = [1,1]

   Catch, err_sts
   IF err_sts EQ 0 THEN BEGIN
      ;sds_id=HDF_SD_SELECT(sd_id,hdf_sd_nametoindex(sd_id,'binSurfPeak'))
      sds_id=HDF_SD_SELECT(sd_id,hdf_sd_nametoindex(sd_id,'binEllipsoid'))
      HDF_SD_GETDATA, sds_id, binS, START=start, COUNT=count, $
                STRIDE=stride , /noreverse
   ENDIF ELSE BEGIN
      help,!error_state,/st
      Catch, /Cancel
      print, 'hdf_sd_getdata(): err=',err_sts
      HDF_Close, fileid
      print, "In read_1c21_ppi.pro, SD error in hdf file: ", filename
      flag = 'Bad SD: binEllipsoid'
      return, flag
   ENDELSE
ENDIF

; -----------------------

IF ( trmmversion EQ 7 ) THEN BEGIN
  ; these were in Vdata in V6, now are their own variables in V7
  ; - we will keep the old variable names if V7 HDF ID differs from V6

   IF N_ELEMENTS(frac_orbit_num) GT 0 THEN BEGIN
     ; get the FractionalGranuleNumber data (frac_orbit_num in V6)
      start = [start_sample]
      count = [sample_range]
      stride = [1]
      Catch, err_sts
      IF err_sts EQ 0 THEN BEGIN
         sds_id=HDF_SD_SELECT(sd_id,hdf_sd_nametoindex(sd_id,'FractionalGranuleNumber'))
         HDF_SD_GETDATA, sds_id, frac_orbit_num, START=start, COUNT=count, STRIDE=stride
      ENDIF ELSE BEGIN
         help,!error_state,/st
         Catch, /Cancel
         print, 'hdf_sd_getdata(): err=',err_sts
         HDF_Close, fileid
         print, "In read_1c21_ppi.pro, SD error in hdf file: ", filename
         flag = 'Bad SD: FractionalGranuleNumber'
         return, flag
      ENDELSE
   ENDIF

   IF N_ELEMENTS(scan_time) GT 0 THEN BEGIN
     ; get the scanTime_sec data (scan_time in V6)
      start = [start_sample]
      count = [sample_range]
      stride = [1]
      Catch, err_sts
      IF err_sts EQ 0 THEN BEGIN
         sds_id=HDF_SD_SELECT(sd_id,hdf_sd_nametoindex(sd_id,'scanTime_sec'))
         HDF_SD_GETDATA, sds_id, scan_time, START=start, COUNT=count, STRIDE=stride
      ENDIF ELSE BEGIN
         help,!error_state,/st
         Catch, /Cancel
         print, 'hdf_sd_getdata(): err=',err_sts
         HDF_Close, fileid
         print, "In read_1c21_ppi.pro, SD error in hdf file: ", filename
         flag = 'Bad SD: scanTime_sec'
         return, flag
      ENDELSE
   ENDIF

   IF N_ELEMENTS(rayStart) GT 0 THEN BEGIN
     ; get the rayStart data
      start = [start_sample]
      count = [49]
      stride = [1]
      Catch, err_sts
      IF err_sts EQ 0 THEN BEGIN
         sds_id=HDF_SD_SELECT(sd_id,hdf_sd_nametoindex(sd_id,'rayStart'))
         HDF_SD_GETDATA, sds_id, rayStart, START=start, COUNT=count, STRIDE=stride
      ENDIF ELSE BEGIN
         help,!error_state,/st
         Catch, /Cancel
         print, 'hdf_sd_getdata(): err=',err_sts
         HDF_Close, fileid
         print, "In read_1c21_ppi.pro, SD error in hdf file: ", filename
         flag = 'Bad SD: rayStart'
         return, flag
      ENDELSE
   ENDIF

   IF N_ELEMENTS(raySize) GT 0 THEN BEGIN
     ; get the raySize data
      start = [start_sample]
      count = [49]
      stride = [1]
      Catch, err_sts
      IF err_sts EQ 0 THEN BEGIN
         sds_id=HDF_SD_SELECT(sd_id,hdf_sd_nametoindex(sd_id,'raySize'))
         HDF_SD_GETDATA, sds_id, raySize, START=start, COUNT=count, STRIDE=stride
      ENDIF ELSE BEGIN
         help,!error_state,/st
         Catch, /Cancel
         print, 'hdf_sd_getdata(): err=',err_sts
         HDF_Close, fileid
         print, "In read_1c21_ppi.pro, SD error in hdf file: ", filename
         flag = 'Bad SD: raySize'
         return, flag
      ENDELSE
   ENDIF

   IF N_ELEMENTS(angle) GT 0 THEN BEGIN
     ; get the angle data
      start = [start_sample]
      count = [49]
      stride = [1]
      Catch, err_sts
      IF err_sts EQ 0 THEN BEGIN
         sds_id=HDF_SD_SELECT(sd_id,hdf_sd_nametoindex(sd_id,'angle'))
         HDF_SD_GETDATA, sds_id, angle, START=start, COUNT=count, STRIDE=stride
      ENDIF ELSE BEGIN
         help,!error_state,/st
         Catch, /Cancel
         print, 'hdf_sd_getdata(): err=',err_sts
         HDF_Close, fileid
         print, "In read_1c21_ppi.pro, SD error in hdf file: ", filename
         flag = 'Bad SD: angle'
         return, flag
      ENDELSE
   ENDIF

   IF N_ELEMENTS(startDist) GT 0 THEN BEGIN
     ; get the startDist data
      start = [start_sample]
      count = [49]
      stride = [1]
      Catch, err_sts
      IF err_sts EQ 0 THEN BEGIN
         sds_id=HDF_SD_SELECT(sd_id,hdf_sd_nametoindex(sd_id,'startBinDist'))
         HDF_SD_GETDATA, sds_id, startDist, START=start, COUNT=count, STRIDE=stride
      ENDIF ELSE BEGIN
         help,!error_state,/st
         Catch, /Cancel
         print, 'hdf_sd_getdata(): err=',err_sts
         HDF_Close, fileid
         print, "In read_1c21_ppi.pro, SD error in hdf file: ", filename
         flag = 'Bad SD: startBinDist'
         return, flag
      ENDELSE
   ENDIF
ENDIF

; -----------------------  

HDF_SD_ENDACCESS,sds_id
HDF_SD_END,sd_id

; ------------------------------------------------------------------------------

IF ( trmmversion EQ 6 ) THEN BEGIN
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
;    for i = 0,num_vdata-1  do begin;
;	print, Vdata_name(i),Vdata_size(i),Vdata_nfields(i),$
;	       format='(A18,I10,I14)'
;    endfor
;    print, '-------------------------------------------------'


    IF N_ELEMENTS(frac_orbit_num) GT 0 THEN BEGIN
;  print, ""
;  print, "Getting frac_orbit_num vdata."
;  print, ""
     ; Find the Scan status Vdata
      vdata_ID = hdf_vd_find(fileID,'pr_scan_status')

      if ( vdata_ID EQ 0 ) then begin  ; new status checking for v7
        print, ""
        print, "Can't find pr_scan_status vdata for frac_orbit_num."
        print, ""
      endif else begin
        print, ""
        print, "Getting frac_orbit_num vdata."
        print, ""
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
  
      endelse
    ENDIF


    IF N_ELEMENTS(scan_time) GT 0 THEN BEGIN
      ; get the scantime vdata
      vdata_ID = hdf_vd_find(fileid,'scan_time')
      if ( vdata_ID EQ 0 ) then begin  ; new status checking for v7
        print, ""
        print, "Can't find scan_time vdata."
        print, ""
      endif else begin
        print, ""
        print, "Getting scan_time vdata."
        print, ""
        vdata_H = hdf_vd_attach(fileid,vdata_ID)
        nscan = hdf_vd_read(vdata_H, scan_time)
        hdf_vd_detach, Vdata_H   ; Detach from the Vdata
;        help, scan_time
      endelse
    ENDIF

    IF N_ELEMENTS(rayStart) GT 0 THEN BEGIN
      ; get the header vdata
      vdata_ID = hdf_vd_find(fileid,'RAY_HEADER')
      if ( vdata_ID EQ 0 ) then begin  ; new status checking for v7
        print, ""
        print, "Can't find RAY_HEADER vdata."
        print, ""
      endif else begin
        vdata_H = hdf_vd_attach(fileid,vdata_ID)
        hdf_vd_get,vdata_H,name=name,fields=raw_field
        fields = strsplit( raw_field, ',', /EXTRACT )
        nscan = hdf_vd_read(vdata_H, data)
        rayStart = intarr(nscan)
        raySize   = intarr(nscan)
        angle     = fltarr(nscan)
        startDist = fltarr(nscan)
        for raynum = 0, nscan-1 do begin
           rayStart[raynum]= fix(data[*,raynum],0)
           raySize[raynum]   = fix(data[*,raynum],2)
           angle[raynum]     = float(data[*,raynum],4)
           startDist[raynum] = float(data[*,raynum],8)
        endfor
        hdf_vd_detach, Vdata_H   ; Detach from the Vdata
      endelse 
;      print, rayStart, raySize, angle, startDist
    ENDIF

    hdf_close,fileid

ENDIF   ; trmmversion EQ 6

flag = 'OK'
return,flag

end
