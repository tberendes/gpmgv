;+
; Copyright © 2014, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; DESCRIPTION
; -----------
; Opens and reads caller-specified data fields from a TRMM PR 3B-42 HDF data
; file.  Data file must be read-ready (uncompressed).  The fully-qualified
; file pathname must be provided as the 'filename' mandatory parameter.
;
; Version 7 3B-42 file format is supported.  V6 not tested.
;
; HISTORY
; -------
; 01/02/14 - Bob Morris, GPM GV (SAIC)
; - Created from read_2b31_file.pro
;
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-

function read_3b42_file, filename, $
                         FileHeaderStruc=FileHeader, $
                         GridHeaderStruc=GridHeader, $
                         NLON=nlon, NLAT=nlat, $
                         precipitation=precipitation, $
                         relativeError=relativeError, $
                         satPrecipitationSource=satPrecipitationSource, $
                         HQprecipitation=HQprecipitation, $
                         IRprecipitation=IRprecipitation, $
                         satObservationTime=satObservationTime, $
                         VERBOSE=verbose

    verbose = KEYWORD_SET(verbose)

    if HDF_IsHDF (filename) then begin
	fileid=hdf_open(filename,/read)
        if ( fileid eq -1 ) then begin
           print, "In read_3b42_file.pro, error opening hdf file: ", filename
	   flag = 'Bad HDF File!'
	   return, flag
        endif
    endif else begin
        print, "In read_3b42_file.pro, tried to open non-hdf file: ", filename
	flag = 'Not HDF File!'
	return, flag
    endelse

    sd_id=HDF_SD_START(filename,/read)
    HDF_SD_FILEINFO, sd_id, nmfsds, attributes

;   Display the number of SD type of files
   IF VERBOSE THEN print, "# of MFSD = ", nmfsds
   
   if nmfsds gt 0 then begin
      IF VERBOSE THEN BEGIN
         print,"          Information about MFHDF DataSets "
         print, ' '
         print,"       NAME          IDL_Type  HDF_Type       Rank   Dimensions"
         print,"-------------------  -------- ----------      ----  ------------"
         print,"                     ------------- Atrribute Info -------------"
         print
      ENDIF
      FSD='(A20,"  ",A8,"  ",I4,"  ",I4)'

      for i=0,nmfsds-1 do begin
         sds_id=HDF_SD_SELECT(sd_id,i)
         HDF_SD_GETINFO,sds_id,name=n,ndims=r,type=t,natts=nats,dims=dims,$
                        hdf_type=h,unit=u,format=fmt,label=label
         if r le 1 then FSD='(A20," ",A8," ",A12,3X,I4,3X,"[",I4,"] ",A)' $
                   else FSD='(A20," ",A8," ",A12,3X,I4,3X,"["'+$
                        STRING(r-1)+'(I5,","),I5,"] ",A)'
          
         IF VERBOSE THEN BEGIN
            print
            print,n,t,h,r,dims,u,FORMAT=FSD
         ENDIF

         trmmversion = 7

         IF VERBOSE THEN BEGIN
            print 
            help,n,r,t,nats,dims,u
            help,fmt,label,range
         ENDIF

         HDF_SD_ENDACCESS,sds_id
      endfor

   endif  else begin
      print, "In read_3b42_file.pro, SD error in hdf file: ", filename
      flag = 'Bad HDF File, no SDs!'
      return, flag
   endelse

   IF VERBOSE THEN print, 'PR 3B42 version: ', trmmversion

; Read grid data
; -----------------------

IF N_ELEMENTS(precipitation) GT 0 THEN BEGIN
  ; get the precipitation data
   Catch, err_sts
   IF err_sts EQ 0 THEN BEGIN
      sds_id=HDF_SD_SELECT(sd_id,hdf_sd_nametoindex(sd_id,'precipitation'))
      HDF_SD_GETDATA, sds_id, precipitation
   ENDIF ELSE BEGIN
      help,!error_state,/st
      Catch, /Cancel
      print, 'hdf_sd_getdata(): err=',err_sts
      HDF_Close, fileid
      print, "In read_3b42_file.pro, SD error in hdf file: ", filename
      flag = 'Bad SD: precipitation'
      return, flag
   ENDELSE
ENDIF

IF N_ELEMENTS(relativeError) GT 0 THEN BEGIN
  ; get the relativeError data
   Catch, err_sts
   IF err_sts EQ 0 THEN BEGIN
      sds_id=HDF_SD_SELECT(sd_id,hdf_sd_nametoindex(sd_id,'relativeError'))
      HDF_SD_GETDATA, sds_id, relativeError
   ENDIF ELSE BEGIN
      help,!error_state,/st
      Catch, /Cancel
      print, 'hdf_sd_getdata(): err=',err_sts
      HDF_Close, fileid
      print, "In read_3b42_file.pro, SD error in hdf file: ", filename
      flag = 'Bad SD: relativeError'
      return, flag
   ENDELSE
ENDIF

IF N_ELEMENTS(satPrecipitationSource) GT 0 THEN BEGIN
  ; get the satPrecipitationSource data
   Catch, err_sts
   IF err_sts EQ 0 THEN BEGIN
      sds_id=HDF_SD_SELECT(sd_id,hdf_sd_nametoindex(sd_id,'satPrecipitationSource'))
      HDF_SD_GETDATA, sds_id, satPrecipitationSource
   ENDIF ELSE BEGIN
      help,!error_state,/st
      Catch, /Cancel
      print, 'hdf_sd_getdata(): err=',err_sts
      HDF_Close, fileid
      print, "In read_3b42_file.pro, SD error in hdf file: ", filename
      flag = 'Bad SD: satPrecipitationSource'
      return, flag
   ENDELSE
ENDIF

IF N_ELEMENTS(HQprecipitation) GT 0 THEN BEGIN
  ; get the HQprecipitation data
   Catch, err_sts
   IF err_sts EQ 0 THEN BEGIN
      sds_id=HDF_SD_SELECT(sd_id,hdf_sd_nametoindex(sd_id,'HQprecipitation'))
      HDF_SD_GETDATA, sds_id, HQprecipitation
   ENDIF ELSE BEGIN
      help,!error_state,/st
      Catch, /Cancel
      print, 'hdf_sd_getdata(): err=',err_sts
      HDF_Close, fileid
      print, "In read_3b42_file.pro, SD error in hdf file: ", filename
      flag = 'Bad SD: HQprecipitation'
      return, flag
   ENDELSE
ENDIF

IF N_ELEMENTS(IRprecipitation) GT 0 THEN BEGIN
  ; get the IRprecipitation data
   Catch, err_sts
   IF err_sts EQ 0 THEN BEGIN
      sds_id=HDF_SD_SELECT(sd_id,hdf_sd_nametoindex(sd_id,'IRprecipitation'))
      HDF_SD_GETDATA, sds_id, IRprecipitation
   ENDIF ELSE BEGIN
      help,!error_state,/st
      Catch, /Cancel
      print, 'hdf_sd_getdata(): err=',err_sts
      HDF_Close, fileid
      print, "In read_3b42_file.pro, SD error in hdf file: ", filename
      flag = 'Bad SD: IRprecipitation'
      return, flag
   ENDELSE
ENDIF

IF N_ELEMENTS(satObservationTime) GT 0 THEN BEGIN
  ; get the satObservationTime data
   Catch, err_sts
   IF err_sts EQ 0 THEN BEGIN
      sds_id=HDF_SD_SELECT(sd_id,hdf_sd_nametoindex(sd_id,'satObservationTime'))
      HDF_SD_GETDATA, sds_id, satObservationTime
   ENDIF ELSE BEGIN
      help,!error_state,/st
      Catch, /Cancel
      print, 'hdf_sd_getdata(): err=',err_sts
      HDF_Close, fileid
      print, "In read_3b42_file.pro, SD error in hdf file: ", filename
      flag = 'Bad SD: satObservationTime'
      return, flag
   ENDELSE
ENDIF

IF N_ELEMENTS(FileHeader) GT 0 THEN BEGIN
  ; get the FileHeader data
   fh_index = HDF_SD_ATTRFIND(sd_id, 'FileHeader')
   HDF_SD_ATTRINFO, SD_id, fh_index, NAME=name, TYPE=type, COUNT=count, $
                    DATA=fh_data
  ; load the fileheader variables into the predefined structure
   FileHeader = parse_file_header_group(fh_data)
ENDIF

HDF_SD_ENDACCESS,sds_id
HDF_SD_END,sd_id

GOTO, skipVGroupStuff
; -----------------------
; -- Access VGroup
; Open the file for read and initialize the VGroup interface

    file_handle = hdf_open(filename,/read)
    
; Get the ID of the first VGroup in the file 

    vgroup_ID = hdf_vg_getid(  file_handle, -1 )
    is_NOT_fakeDim = 1
    num_vgroup = 0 
    
; Loop over VGroup 
    while (vgroup_ID ne -1) and (is_NOT_fakeDim) do begin

; Attach to the vgroup 
	vgroup_H = hdf_vg_attach(file_handle,vgroup_ID)

; Get vgroup info
	hdf_vg_getinfo, vgroup_H, class=class, name=name, nentries=nentries, ref=ref
         
; Detach vgroup
	hdf_vg_detach, vgroup_H
       
; Check to see if this is a dummy
; Can't really explain why this happens but sometimes a dummy dimension
; gets returned as a VGroup name depending on the HDF file.  
	is_NOT_fakeDim = strpos(name,'fakeDim') eq -1

; Build up the list of VGroup names,sizes and number of fields 
	if (num_vgroup eq 0) then begin
	    VGroup_name = name 
	    VGroup_class = class
	    VGroup_nentries = nentries
	    VGroup_ref = ref
	    num_vgroup = 1
	endif else if is_NOT_fakeDim then begin
	    VGroup_name = [VGroup_name,name]
            VGroup_class = [VGroup_class,class]
            VGroup_nentries = [VGroup_nentries,nentries]
            VGroup_ref = [VGroup_ref,ref]
	    num_vgroup = num_vgroup + 1
	endif
       
; Get ID of next VGroup
	vgroup_ID = hdf_vg_getid( file_handle, vgroup_ID )

    endwhile 

; Print out the list of names   
    IF VERBOSE THEN BEGIN
       print,''   
       print, 'List of VGroup names    VGroup Class   Num. Entries'
       print, '-------------------------------------------------'
       for i = 0,num_vgroup-1  do begin
   	print, VGroup_name(i),VGroup_class(i),VGroup_nentries(i),$
   	       format='(A18,A10,I14)'
       endfor
       print, '-------------------------------------------------'
    ENDIF
; -----------------------

skipVGroupStuff:

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
    IF VERBOSE THEN BEGIN
       print,''   
       print, 'List of Vdata names    Size (bytes)   Num. Fields'
       print, '-------------------------------------------------'
       for i = 0,num_vdata-1  do begin
   	print, Vdata_name(i),Vdata_size(i),Vdata_nfields(i),$
   	       format='(A18,I10,I14)'
       endfor
       print, '-------------------------------------------------'
    ENDIF

    IF N_ELEMENTS(GridHeader) GT 0 THEN BEGIN

; Find the Scan status Vdata
      vdata_ID = hdf_vd_find(file_handle,'GridHeader')

      if ( vdata_ID EQ 0 ) then begin  ;  status checking
        print, ""
        print, "Can't find vdata for GridHeader."
        print, ""
      endif else begin
;    print, ""
;    print, "Getting GridHeader vdata."
;    print, ""
       ; Attach to this Vdata
        vdata_H = hdf_vd_attach(file_handle,vdata_ID)

       ; Get the Vdata stats
        hdf_vd_get,vdata_H,name=name,fields=raw_field

       ; Separate the fields
        fields = str_sep(raw_field,',')

       ; Read the Vdata, returns the number of records
       ; The data for all records is returned in a BYTE ARRAY of (record_size,nscans)

        nscan = hdf_vd_read(vdata_h,data)
        GridHeaderString = STRING(data)
       ; load the gridheader variables into the predefined structure
        GridHeader = parse_grid_header_group(GridHeaderString)

        hdf_vd_detach, Vdata_H   ; Detach from the Vdata
      endelse
    ENDIF

; get the nlon and nlat vdata

    IF N_ELEMENTS(nlon) GT 0 THEN BEGIN
       vdata_ID = hdf_vd_find(file_handle,'nlon')
       if ( vdata_ID EQ 0 ) then begin  ;  status checking
         print, ""
         print, "Can't find nlon vdata."
         print, ""
       endif else begin
;         print, ""
;         print, "Getting nlon vdata."
;         print, ""
         vdata_H = hdf_vd_attach(file_handle,vdata_ID)
         nscan = hdf_vd_read(vdata_H, nlon)
         hdf_vd_detach, Vdata_H   ; Detach from the Vdata
         IF VERBOSE THEN help, nlon
       endelse
    ENDIF

    IF N_ELEMENTS(nlon) GT 0 THEN BEGIN
       vdata_ID = hdf_vd_find(file_handle,'nlat')
       if ( vdata_ID EQ 0 ) then begin  ;  status checking
         print, ""
         print, "Can't find nlat vdata."
         print, ""
       endif else begin
;         print, ""
;         print, "Getting nlat vdata."
;         print, ""
         vdata_H = hdf_vd_attach(file_handle,vdata_ID)
         nscan = hdf_vd_read(vdata_H, nlat)
         hdf_vd_detach, Vdata_H   ; Detach from the Vdata
         IF VERBOSE THEN help, nlat
       endelse
    ENDIF

; -----------------------

hdf_close, fileid
flag = 'OK'
return, flag

end
