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
;       Nov 2006 - Bob Morris, GPM GV (SAIC)
;       - Renamed from read_2a25_ppi.pro
;       - Dropped Epsilons, added rainType, rangeBinNums, rainFlag; no printing
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-

pro read_2a25, filename, DBZ=correctZfactor, GEOL=geolocation, $
               RAIN=rainrate, SURFACE_RAIN=surfaceRain, TYPE=rainType, $
               RANGE_BIN=rangeBinNums, RN_FLAG=rainFlag

common sample, start_sample,sample_range,num_range,pw_min

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
;         FSD='(A10,"  ",A8,"  ",I4,"  ",I4)'
         for i=0,nmfsds-1 do begin
          sds_id=HDF_SD_SELECT(sd_id,i)
          HDF_SD_GETINFO,sds_id,name=n,ndims=r,type=t,natts=nats,dims=dims,$
                         hdf_type=h,unit=u,format=fmt,label=label
;          if r le 1 then FSD='(A10," ",A8," ",A12,3X,I4,3X,"[",I4,"] ",A)' $
;                   else FSD='(A10," ",A8," ",A12,3X,I4,3X,"["'+$
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
; Read Correct Radar Reflectivity (dBZ)
;
 
if (START_SAMPLE eq 0) and (SAMPLE_RANGE le 1) then SAMPLE_RANGE=nsample

IF keyword_set(correctZFactor) THEN BEGIN

start = [start_sample,0,0]
count = [sample_range,49,80]
stride = [1,1,1]

sds_id=HDF_SD_SELECT(sd_id,hdf_sd_nametoindex(sd_id,'correctZFactor'))
HDF_SD_GETDATA, sds_id, correctZFactor, START=start, COUNT=count, $
                STRIDE=stride, /noreverse
                
ENDIF                
; ---------------------- 

IF keyword_set(rainrate) THEN BEGIN

start = [start_sample,0,0]
count = [sample_range,49,80]
stride = [1,1,1]

sds_id=HDF_SD_SELECT(sd_id,hdf_sd_nametoindex(sd_id,'rain'))
HDF_SD_GETDATA, sds_id, rainrate, START=start, COUNT=count, $
                STRIDE=stride, /noreverse
                
ENDIF                
; ----------------------

IF keyword_set(surfaceRain) THEN BEGIN

start = [start_sample,0]
count = [sample_range,49]
stride = [1,1]

sds_id=HDF_SD_SELECT(sd_id,hdf_sd_nametoindex(sd_id,'nearSurfRain'))
HDF_SD_GETDATA, sds_id, surfaceRain, START=start, COUNT=count, $
                STRIDE=stride, /noreverse
                
ENDIF                
; ----------------------                

IF keyword_set(rangeBinNums) THEN BEGIN
             
start = [start_sample,0,0]
count = [sample_range,49,7]
stride = [1,1,1]

sds_id=HDF_SD_SELECT(sd_id,hdf_sd_nametoindex(sd_id,'rangeBinNum'))
HDF_SD_GETDATA, sds_id, rangeBinNums, START=start, COUNT=count, $
                STRIDE=stride, /noreverse
                
ENDIF                 
; -----------------------
 
IF keyword_set(rainFlag) THEN BEGIN
             
start = [start_sample,0]
count = [sample_range,49]
stride = [1,1]

sds_id=HDF_SD_SELECT(sd_id,hdf_sd_nametoindex(sd_id,'rainFlag'))
HDF_SD_GETDATA, sds_id, rainFlag, START=start, COUNT=count, $
                STRIDE=stride, /noreverse
                
ENDIF                 
; -----------------------

IF keyword_set(rainType) THEN BEGIN

start = [start_sample,0]
count = [sample_range,49]
stride = [1,1]

sds_id=HDF_SD_SELECT(sd_id,hdf_sd_nametoindex(sd_id,'rainType'))
HDF_SD_GETDATA, sds_id, rainType, START=start, COUNT=count, $
                STRIDE=stride, /noreverse
                
ENDIF                
; ----------------------                
 
IF keyword_set(geolocation) THEN BEGIN
             
start = [0,0,start_sample]
count = [2,49,sample_range]
stride = [1,1,1]

sds_id=HDF_SD_SELECT(sd_id,hdf_sd_nametoindex(sd_id,'geolocation'))
HDF_SD_GETDATA, sds_id, geolocation, START=start, COUNT=count, $
                STRIDE=stride
ENDIF                 
; -----------------------

HDF_SD_ENDACCESS,sds_id
HDF_SD_END,sd_id

end
