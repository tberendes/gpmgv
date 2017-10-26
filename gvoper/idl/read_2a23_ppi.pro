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
; MODIFIED:
;       Jul 2008 - Bob Morris, GPM GV (SAIC)
;       - Made into FUNCTION, added HDF_OPEN tests a la load_2b31
;       Apr 2010 - Bob Morris, GPM GV (SAIC)
;       - Added capability to read Version 7 test data files from PPS
;       - Added statusFlag and bbstatus as optional variables to be read, and
;         removed landOceanFlag already read by read_1c21_ppi().
;       March 2012 - Bob Morris, GPM GV (SAIC)
;       - Added error catching to the hdf_sd_getdata() calls to gracefully fail
;         in the event of bad SD data in an otherwise valid HDF file.
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-

function read_2a23_ppi, filename, RAINTYPE=rainType, GEOL=geolocation, $
                        STATUSFLAG=statusFlag, BBstatus=bbstatus

common sample, start_sample,sample_range

    if HDF_IsHDF (filename) then begin
	fileid=hdf_open(filename,/read)
        if ( fileid eq -1 ) then begin
           print, "In read_2a23_ppi.pro, error opening hdf file: ", filename
	   flag = 'Bad HDF File!'
	   return, flag
        endif
    endif else begin
        print, "In read_2a23_ppi.pro, tried to open non-hdf file: ", filename
	flag = 'Not HDF File!'
	return, flag
    endelse
    sd_id=HDF_SD_START(filename,/read)
    HDF_SD_FILEINFO, sd_id, nmfsds, attributes

;   Display the number of SD type of files
;   print, "# of MFSD = ", nmfsds
   
   if nmfsds gt 0 then begin
;         print,"          Information about MFHDF DataSets "
;         print, ' '
;         print,"   NAME     IDL_Type  HDF_Type       Rank   Dimensions"
;         print,"----------  -------- ----------      ----  ------------"
;         print,"            ------------- Atrribute Info -------------"
        FSD='(A10,"  ",A8,"  ",I4,"  ",I4)'
         for i=0,nmfsds-1 do begin
          sds_id=HDF_SD_SELECT(sd_id,i)
          HDF_SD_GETINFO,sds_id,name=n,ndims=r,type=t,natts=natts,dims=dims,$
                         hdf_type=h,unit=u,format=fmt,label=label
          if r le 1 then FSD='(A10," ",A8," ",A12,3X,I4,3X,"[",I4,"] ",A)' $
                   else FSD='(A10," ",A8," ",A12,3X,I4,3X,"["'+$
                        STRING(r-1)+'(I5,","),I5,"] ",A)'

;          print
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
;          help,n,r,t,natts,dims,u
;          help,fmt,label,range
          HDF_SD_ENDACCESS,sds_id
         endfor
      endif  else begin
         print, "In read_2a23_ppi.pro, SD error in hdf file: ", filename
	 flag = 'Bad HDF File, no SDs!'
	 return, flag
   endelse


; Read data
; Read Normal Sample
;
 
if (START_SAMPLE eq 0) and (SAMPLE_RANGE le 1) then SAMPLE_RANGE=nsample

IF keyword_set(rainType) THEN BEGIN

start = [start_sample,0]
count = [sample_range,49]
stride = [1,1]

   Catch, err_sts
   IF err_sts EQ 0 THEN BEGIN
      sds_id=HDF_SD_SELECT(sd_id,hdf_sd_nametoindex(sd_id,'rainType'))
      HDF_SD_GETDATA, sds_id, rainType, START=start, COUNT=count, $
                STRIDE=stride, /noreverse
   ENDIF ELSE BEGIN
      help,!error_state,/st
      Catch, /Cancel
      print, 'hdf_sd_getdata(): err=',err_sts
      HDF_Close, fileid
      print, "In read_2a23_ppi.pro, SD error in hdf file: ", filename
      flag = 'Bad SD: rainType'
      return, flag
   ENDELSE
ENDIF                
; ----------------------                
 
IF N_ELEMENTS(geolocation) GT 0 THEN BEGIN
   print, 'PR 2A23 version: ', trmmversion
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
             print, "In read_2a23_ppi.pro, SD error in hdf file: ", filename
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
             print, "In read_2a23_ppi.pro, SD error in hdf file: ", filename
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
             print, "In read_2a23_ppi.pro, SD error in hdf file: ", filename
             flag = 'Bad SD: Longitude'
             return, flag
          ENDELSE
          lldims = SIZE(latitude)
          geolocation = FLTARR(2,lldims[1],lldims[2])
;          help, lldims, latitude, geolocation
          geolocation[0,*,*] = latitude
          geolocation[1,*,*] = longitude
        end
   ENDCASE
ENDIF
; -----------------------

IF keyword_set(statusFlag) THEN BEGIN

   start = [start_sample,0]
   count = [sample_range,49]
   stride = [1,1]

   Catch, err_sts
   IF err_sts EQ 0 THEN BEGIN
      sds_id=HDF_SD_SELECT(sd_id,hdf_sd_nametoindex(sd_id,'status'))
      HDF_SD_GETDATA, sds_id, statusFlag, START=start, COUNT=count, $
                STRIDE=stride, /noreverse
   ENDIF ELSE BEGIN
      help,!error_state,/st
      Catch, /Cancel
      print, 'hdf_sd_getdata(): err=',err_sts
      HDF_Close, fileid
      print, "In read_2a23_ppi.pro, SD error in hdf file: ", filename
      flag = 'Bad SD: status'
      return, flag
   ENDELSE
ENDIF                 
; -----------------------

IF keyword_set(bbstatus) THEN BEGIN

   start = [start_sample,0]
   count = [sample_range,49]
   stride = [1,1]

   Catch, err_sts
   IF err_sts EQ 0 THEN BEGIN
      sds_id=HDF_SD_SELECT(sd_id,hdf_sd_nametoindex(sd_id,'BBstatus'))
      HDF_SD_GETDATA, sds_id, bbstatus, START=start, COUNT=count, $
                STRIDE=stride, /noreverse
   ENDIF ELSE BEGIN
      help,!error_state,/st
      Catch, /Cancel
      print, 'hdf_sd_getdata(): err=',err_sts
      HDF_Close, fileid
      print, "In read_2a23_ppi.pro, SD error in hdf file: ", filename
      flag = 'Bad SD: BBstatus'
      return, flag
   ENDELSE
ENDIF                 
; ----------------------- 
                              
HDF_SD_ENDACCESS,sds_id
HDF_SD_END,sd_id
hdf_close,fileid

flag = 'OK'
return,flag
end
