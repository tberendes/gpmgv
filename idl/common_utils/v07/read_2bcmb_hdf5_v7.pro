;+
; Copyright © 2013, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; read_2bcmb_hdf5_v7.pro         Bob Morris, GPM GV/SAIC   June 2013
;
; DESCRIPTION
; -----------
; For a GPM 2BDPRGMI or TRMM 2BPRTMI HDF5 file, reads and parses FileHeader
; metadata attributes and all of the data groups and their included datasets. 
; Assembles and returns a structure mimicking the HDF file organization,
; containing all the data read and/or parsed.  Sub-structures for large-array
; datasets and HDF groups containing large-array datasets (e.g., 'MS/Input'
; group) are defined as pointer references-to-structures in the output
; structure 'outstruc'.  Those datasets directly below the swath levels MS and
; NS (i.e., not in another lower group; e.g., Latitude, pia, etc.) are bundled
; into a structure called "DATASETS" within the MS and NS structures.
;
; If only one scan type is to be read (scan2read parameter is set, or product
; type is 2BPRTMI), then the 'Swath' member of the ignored scan's structure has
; the string ': UNREAD' appended to the value, e.g., 'MS: UNREAD', and no other
; members of the structure are defined for that scan type.
;
; Returns -1 in case of errors.
;
; PARAMETERS
; ----------
; file      -- Full pathname of the 2B-[DPRGMI|PRTMI] file to be read.  If not
;              specified, then a file selection dialog will be presented to
;              allow selection of a 2B file from the file system.
; debug     -- Binary keyword parameter, controls output of diagnostic messages.
;              Default = suppress messages.
; read_all  -- Binary parameter.  If set, then read and return all datasets in
;              the groups.  Otherwise, just read the datasets needed for basic
;              display and processing (subjective list).
; scan2read -- Limits the swath groups (scan types) read to only the group
;              specified by the keyword value.  Keyword is ignored if read_all
;              is set.  Valid values are 'MS' and 'NS' (for 2BDPRGMI), or 'NS'
;              (for 2BPRTMI).
;
; HISTORY
; -------
; 06/04/13  Morris/GPM GV/SAIC
; - Created.
; 06/13/13  Morris/GPM GV/SAIC
; - Added READ_ALL option to pare down the datasets read by default.
; 06/18/13  Morris/GPM GV/SAIC
; - Added SCAN keyword option to limit the swath groups read to only one swath.
; 01/07/14  Morris/GPM GV/SAIC
; - Added source labeling parameter to call to parse_swath_header_group().
; 06/28/18  Morris/GPM GV/SAIC
; - Added capability to read TRMM Version 8 2BPRTMI files.
; 06/16/20  Berendes, UAH
; - Modified for GPM V7 format, removed TRMM 2BPRTMI
; - NOTE:  NOT TESTED YET!!!!!!!!!!!!!!!!!
;
;
; EMAIL QUESTIONS OR COMMENTS AT:
;       https://pmm.nasa.gov/contact
;-

FUNCTION read_2bcmb_hdf5_v7, file, DEBUG=debug, READ_ALL=read_all, SCAN=scan2read

   outstruc = -1

   all = KEYWORD_SET(read_all)
   verbose1 = KEYWORD_SET(debug)

   IF all NE 1b AND N_ELEMENTS(scan2read) EQ 1 THEN BEGIN
      SWITCH STRUPCASE(scan2read) OF
         'FS' :
         'NS' : BEGIN
                  onescan = STRUPCASE(scan2read)
                  break
                END
         ELSE : message, "Illegal value '" + scan2read + $
                         "' for SCAN keyword, must be 'FS' or 'NS'"
      ENDSWITCH
   ENDIF ELSE IF N_ELEMENTS(scan2read) GT 1 THEN $
      message, "Parameter value for SCAN keyword is not a scalar string."

   if n_elements(file) eq 0 then begin
      filters = ['2B*DPRGMI*.HDF5*']
      file = dialog_pickfile( FILTER=filters, $
                TITLE='Select 2B-DPRGMI file to read', $
                PATH='/data/gpmgv/orbit_subset/GPM/DPRGMI/2BDPRGMI' )
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

  ; the valid FileHeader ALGORITHMID identifiers are '2BCMB' (for 2BDPRGMI
  ; products) and '2BCMBX' (for 2BCMBX products)
   prodname=filestruc.ALGORITHMID
   IF prodname NE '2BCMB' AND prodname NE '2BCMBX' THEN BEGIN
      h5g_close, group_id
      h5f_close, file_id
      message, "Illegal product type '" + prodname + "', must be '2BCMB' or '2BCMBX'"
   ENDIF

   ; define the swath groups according to product type

   nscans=2

   IF filestruc.NUMBEROFSWATHS NE nscans THEN BEGIN
      h5g_close, group_id
      h5f_close, file_id
      message, "Expect 2 swaths in 2BDPRGMI product, have " + $
            STRING(filestruc.NUMBEROFSWATHS, FORMAT='(I0)')
   ENDIF

   IF N_ELEMENTS(onescan) NE 0 THEN BEGIN
        ; make sure onescan value is 'FS' or 'NS', if specified
      IF TOTAL( STRCMP(onescan,['FS','NS']) ) NE 1.0 THEN BEGIN
          message, "Requested Scan type " + onescan + $
               " not valid for 2BDPRGMI product - must be FS, NS or left unspecified."
      ENDIF
   ENDIF 
   ; get the data variables for the swath group(s)
   snames=['FS','NS']

   for isw = 0, N_ELEMENTS(snames)-1 do begin
      sname=snames[isw]

      IF N_ELEMENTS(onescan) NE 0  THEN BEGIN
         IF STRMATCH(onescan, sname) EQ 0b THEN BEGIN
            ; this isn't the scan to be read, so skip it and define empty struct
            message, "Skipping swath "+sname, /INFO
            CASE sname OF
               'FS' : FS = { Swath : sname+": UNREAD" }
               'NS' : NS = { Swath : sname+": UNREAD" }
            ENDCASE
            continue
         ENDIF
      ENDIF

      print, "" & print, "Swath ",sname,":"
      prodgroup=prodname+'__'+sname      ; label info for data structures
      ; get the group ID for this swath
            
      if prodname NE '2BCMBX' then begin ; changed swath group names in V07 from V06X
	      CASE sname OF
	         'FS' : gname = 'KuKaGMI'
	         'NS' : gname = 'KuGMI'
	      ENDCASE
      
      	  sw_group_id = h5g_open(group_id, gname)
      	  swathHeaderID = h5a_open_name(sw_group_id, gname+'_SwathHeader')
      endif else begin
      	  sw_group_id = h5g_open(group_id, sname)
		  swathHeaderID = h5a_open_name(sw_group_id, sname+'_SwathHeader')
      endelse

      ; get the SwathHeader for this swath
      swhead_label = prodgroup+'_SwathHeader'
      ;swathHeaderID = h5a_open_name(sw_group_id, sname+'_SwathHeader')
      ppsSwathHeader = h5a_read(swathHeaderID)
      ; extract the individual swath header values from the formatted string
      swathstruc = parse_swath_header_group(ppsSwathHeader, swhead_label)
      h5a_close, swathHeaderID
      IF (verbose1) THEN help, swathstruc

      ; get the ScanTime structure for this swath
      ptr_scantimes = ptr_new(/allocate_heap)
      *ptr_scantimes = get_scantime_group(sw_group_id, prodgroup)
      IF (verbose1) THEN help, *ptr_scantimes

      ; get the scanStatus structure for this swath
      ptr_scstatus = ptr_new(/allocate_heap)
      *ptr_scstatus = get_dpr_scanstatus_group(sw_group_id, prodgroup)
      IF (verbose1) THEN help, *ptr_scstatus

      ; get the Input structure for this swath
      ptr_input = ptr_new(/allocate_heap)
      *ptr_input = get_cmb_input_group(sw_group_id, prodgroup, READ_ALL=all)
      IF (verbose1) THEN help, *ptr_input

      ; get the structure with the swath-level datasets
      ptr_datasets = ptr_new(/allocate_heap)
      *ptr_datasets = get_cmb_datasets(sw_group_id, prodgroup, READ_ALL=all)
      IF (verbose1) THEN help, *ptr_datasets

      h5g_close, sw_group_id

      CASE sname OF
         'FS' : BEGIN
                  FS = { Swath : sname, $
                         SwathHeader : swathstruc, $
                         ptr_ScanTime : ptr_scantimes, $
                         ptr_scanStatus : ptr_scstatus, $
                         ptr_Input : ptr_input, $
                         ptr_datasets : ptr_datasets }
                END
         'NS' : BEGIN
                  NS = { Swath : sname, $
                         SwathHeader : swathstruc, $
                         ptr_ScanTime : ptr_scantimes, $
                         ptr_scanStatus : ptr_scstatus, $
                         ptr_Input : ptr_input, $
                         ptr_datasets : ptr_datasets }
                END
         ELSE : message, 'What the?!!'
       ENDCASE

   endfor

   h5g_close, group_id
   h5f_close, file_id
   outStruc = { FileHeader:filestruc, FS:FS, NS:NS }

userQuit:
return, outStruc
end
