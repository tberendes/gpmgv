;+
; Copyright © 2014, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; read_2agprof_hdf5.pro         Bob Morris, GPM GV/SAIC   October 2014
;
; DESCRIPTION
; Given the full pathname to a 2AGPROF HDF5 file, reads and parses FileHeader
; metadata attributes and all of the data groups and their included datasets. 
; Assembles and returns a structure mimicking the HDF file organization,
; containing all the data read and/or parsed.  Sub-structures for large-array
; datasets and HDF groups containing large-array datasets (e.g., 'S1/SCstatus'
; group) are defined as pointer references-to-structures in the output
; structure 'outstruc'.  Those datasets directly below the swath level S1 
; (i.e., not in another lower group; e.g., Latitude, etc.) are bundled
; into a structure called "DATASETS" within the S1 structure.
;
; Returns -1 in case of errors.
;
; PARAMETERS
; ----------
; file      -- Full pathname of the 2AGPROF HDF5 file to be read
; debug     -- Binary keyword parameter, controls output of diagnostic messages.
;              Default = suppress messages.
; read_all  -- Binary parameter.  If set, then read and return all datasets in
;              the groups.  Otherwise, just read the datasets needed for basic
;              display and processing (subjective list).
;
; HISTORY
; -------
; 10/09/14  Morris/GPM GV/SAIC
; - Created from read_2agprofgmi_hdf5.pro as a generic reader of the 2AGPROF
;   file format for GMI and/or the constellation 2A-GPROF files.
; 01/04/17  Morris/GPM GV/SAIC
; - Changed behavior to ignore unknown members in the group rather than failing.
;
; EMAIL QUESTIONS OR COMMENTS AT:
;       https://pmm.nasa.gov/contact
;-

FUNCTION read_2agprof_hdf5, file, DEBUG=debug, READ_ALL=read_all

   outstruc = -1

   all = KEYWORD_SET(read_all)
   verbose1 = KEYWORD_SET(debug)

   if n_elements(file) eq 0 then begin
      filters = ['*GPROF*.HDF5*']
      file = dialog_pickfile( FILTER=filters, $
                TITLE='Select 2AGPROF file to read', $
                PATH='/data/gpmgv/orbit_subset' )
      IF (file EQ '') THEN GOTO, userQuit
   endif

   if (not H5F_IS_HDF5(file)) then $
       MESSAGE, '"'+file+'" is not a valid HDF5 file.'
  
   ; Open file
   file_id = h5f_open(file)
   group_id=h5g_open(file_id, '/')

   ; get value for the FileHeader attribute, located at the top level
   fileHeaderID = h5a_open_name(group_id, 'FileHeader')
   ppsFileHeaderStruc = h5a_read(fileHeaderID)
   ; extract the individual file header values from the formatted string
   filestruc=parse_file_header_group(ppsFileHeaderStruc)
   h5a_close, fileHeaderID
   IF (verbose1) THEN HELP, filestruc
   prodname=filestruc.ALGORITHMID

   IF STRPOS(prodname,'2AGPROF') EQ -1 THEN BEGIN
      h5g_close, group_id
      h5f_close, file_id
      message, "Illegal product type '" + prodname + "', must be like '2AGPROF*'"
   ENDIF

   ; get the GprofDHeadr group for this product
   gname = 'GprofDHeadr'
   prodgroup=prodname+'__'          ; label info for data structure
   label = prodgroup+'/'+gname      ; label info for data structure
   ; get the ID of GprofDHeadr group
   ; -- check that this group contains a GprofDHeadr group
   CATCH, error
   IF error EQ 0 THEN BEGIN
      dh_group_id = h5g_open(group_id, gname)
   ENDIF ELSE BEGIN
      help,!error_state,/st
      Catch, /Cancel
      message, 'err='+STRING(error)+", "+!error_state.msg, /INFO
      return, -1
   ENDELSE
   Catch, /Cancel

   nmbrs = h5g_get_nmembers(group_id, gname)
;   print, "No. Members = ", nmbrs
   ; extract the four expected field values one by one
   IF nmbrs GE 4 THEN BEGIN
      dtnames=STRARR(nmbrs)
      for immbr = 0, nmbrs-1 do begin
         dtnames[immbr] = h5g_get_member_name(group_id, gname, immbr)
;         print, dtnames[immbr]
         dtID = h5d_open(dh_group_id, dtnames[immbr])
         CASE dtnames[immbr] OF
                    'clusterProfiles' : clusterProfiles = h5d_read(dtID)
                        'hgtTopLayer' : hgtTopLayer = h5d_read(dtID)
            'temperatureDescriptions' : temperatureDescriptions = h5d_read(dtID)
                 'speciesDescription' : speciesDescription = h5d_read(dtID)
            ELSE : BEGIN
                      message, "Unknown GprofDHeadr group member: "+dtnames[immbr], /INFO
;                      return, -1
                   END
         ENDCASE
;         dtval = h5d_read(dtID)
;         print, dtval[0]
         h5d_close, dtID
      endfor
   ENDIF ELSE BEGIN
      message, STRING(nmbrs, FORMAT='(I0)')+" fewer than 4 members in GprofDHeadr group '" $
               +gname+"'", /INFO
      return, -1
   ENDELSE

   h5g_close, dh_group_id

   GprofDHeadr_struc = { source : label, $
                         clusterProfiles : clusterProfiles, $
                         hgtTopLayer : hgtTopLayer, $
                         temperatureDescriptions : temperatureDescriptions, $
                         speciesDescription : speciesDescription }

   IF (verbose1) THEN help, GprofDHeadr_struc

   ; define the swath groups according to product type
   snames=['S1']   ; swath prefix used in 2AGPROFGMI product
   IF filestruc.NUMBEROFSWATHS NE N_ELEMENTS(snames) THEN BEGIN
      h5g_close, group_id
      h5f_close, file_id
      message, "Expect 1 swath in product, have " + $
               STRING(filestruc.NUMBEROFSWATHS, FORMAT='(I0)')
   ENDIF

   ; get the data variables for the swath groups
   for isw = 0, filestruc.NUMBEROFSWATHS-1 do begin
      sname=snames[isw]
      print, "" & print, "Swath ",sname,":"
      prodgroup=prodname+'__'+sname      ; label info for data structures
      ; get the group ID for this swath
      sw_group_id = h5g_open(group_id, sname)

      ; get the SwathHeader for this swath
      swhead_label = prodgroup+'/'+'SwathHeader'

      ; get the ID of SwathHeader group
      ; -- first, check that this group contains a SwathHeader group
      CATCH, error
      IF error EQ 0 THEN BEGIN
         swathHeaderID = h5a_open_name(sw_group_id, 'SwathHeader')
         ppsSwathHeader = h5a_read(swathHeaderID)
         ; extract the individual swath header values from the formatted string
         swathstruc = parse_swath_header_group(ppsSwathHeader, swhead_label)
         h5a_close, swathHeaderID
      ENDIF ELSE BEGIN
         help,!error_state,/st
         Catch, /Cancel
         message, 'err='+STRING(error)+", "+!error_state.msg, /INFO
         swathstruc = -1
      ENDELSE
      Catch, /Cancel
      IF (verbose1) THEN help, swathstruc

      ; get the ScanTime structure for this swath
      ptr_scantimes = ptr_new(/allocate_heap)
      *ptr_scantimes = get_scantime_group(sw_group_id, prodgroup)
      IF (verbose1) THEN help, *ptr_scantimes

      ; get the scstatus structure for this swath
      ptr_scstatus = ptr_new(/allocate_heap)
      *ptr_scstatus = get_scstatus_group(sw_group_id, prodgroup)
      IF (verbose1) THEN help, *ptr_scstatus

      ; get the structure with the swath-level datasets
      ptr_datasets = ptr_new(/allocate_heap)
      *ptr_datasets = get_2agprofgmi_datasets(sw_group_id, prodgroup, $
                                              READ_ALL=all)
      IF (verbose1) THEN help, *ptr_datasets

      h5g_close, sw_group_id

      CASE sname OF
         'S1' : BEGIN
                  S1 = { Swath : sname, $
                         SwathHeader : swathstruc, $
                         ptr_ScanTime : ptr_scantimes, $
                         ptr_scStatus : ptr_scstatus, $
                         ptr_datasets : ptr_datasets }
                END
         ELSE : message, 'What the?!!'
       ENDCASE

   endfor

   h5g_close, group_id
   h5f_close, file_id
   outStruc = { FileHeader:filestruc, GprofDHeadr:GprofDHeadr_struc, S1:S1 }

userQuit:
return, outStruc
end
