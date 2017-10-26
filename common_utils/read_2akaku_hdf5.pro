;+
; Copyright © 2013, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; read_2akaku_hdf5.pro         Bob Morris, GPM GV/SAIC   June 2013
;
; DESCRIPTION
; -----------
; Given the full pathname to a 2AKa or 2AKu HDF5 file, reads and parses the
; FileHeader metadata attributes and all of the data groups and their included
; datasets.
; Assembles and returns a structure mimicking the HDF file organization,
; containing all the data read and/or parsed.  Sub-structures for large-array
; datasets and HDF groups containing large-array datasets (e.g., 'MS/DSD'
; group) are defined as pointer references-to-structures in the output
; structure 'outstruc'.  Those datasets directly below the swath levels
; (Latitude, Longitude) are bundled into a structure called "DATASETS" within
; the HS, MS and NS structures.
;
; Returns -1 in case of errors.
;
; PARAMETERS
; ----------
; file      -- Full pathname of the HDF5 file to be read
; debug     -- Binary keyword parameter, controls output of diagnostic messages.
;              Default = suppress messages.
; read_all  -- Binary parameter.  If set, then read and return all datasets in
;              the groups.  Otherwise, just read the datasets needed for basic
;              display and processing (subjective list).
; scan2read -- Limits the swath groups (scan types) read to only the group
;              specified by the keyword value.  Keyword is ignored if read_all
;              is set.
;
; HISTORY
; -------
; 06/04/13  Morris/GPM GV/SAIC
; - Created.
; 06/13/13  Morris/GPM GV/SAIC
; - Added READ_ALL option to pare down the datasets read by default.
; 06/18/13  Morris/GPM GV/SAIC
; - Added SCAN keyword option to limit the swath groups read to only one swath.
; 01/08/14  Morris/GPM GV/SAIC
; - Added source labeling parameter to call to parse_swath_header_group().
; - Added call to get_dpr_scanstatus_group to read scanStatus data and added
;   data structure for it in the returned structure.
; - Added calls to get_dpr_navigation_group and get_dpr_experimental_group, and
;   added structures containing these groups' data to the returned structure.
; 10/04/17  Morris/GPM GV/SAIC
; - Added capability to read TRMM 2APR (version 8) product.
;
; EMAIL QUESTIONS OR COMMENTS AT:
;       https://pmm.nasa.gov/contact
;-

FUNCTION read_2akaku_hdf5, file, DEBUG=debug, READ_ALL=read_all, SCAN=scan2read

   outstruc = -1

   all = KEYWORD_SET(read_all)
   verbose1 = KEYWORD_SET(debug)

   IF all NE 1b AND N_ELEMENTS(scan2read) EQ 1 THEN BEGIN
      SWITCH STRUPCASE(scan2read) OF
         'HS' :
         'MS' :
         'NS' : BEGIN
                  onescan = STRUPCASE(scan2read)
                  break
                END
         ELSE : message, "Illegal value '" + scan2read + $
                         "' for SCAN keyword, must be 'HS', 'MS' or 'NS'"
      ENDSWITCH
   ENDIF ELSE IF N_ELEMENTS(scan2read) GT 1 THEN $
      message, "Parameter value for SCAN keyword is not a scalar string."

   if n_elements(file) eq 0 then begin
      filters = ['2A*K*.HDF5*']
      file=dialog_pickfile(FILTER=filters, $
          TITLE='Select 2A-Ka/Ku file to read', $
          PATH='/data/gpmgv/GPMtest')
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

   ; define the swath groups according to product type
   prodname=filestruc.ALGORITHMID
   CASE prodname OF
      '2AKa' : snames=['HS', 'MS']   ; prefixes used in 2A-Ka products
      '2AKu' : snames=['NS']         ; ditto, 2A-Ku DPR
      '2APR' : snames=['NS']         ; ditto, TRMM 2A-PR
       ELSE  : BEGIN
                 h5g_close, group_id
                 h5f_close, file_id
                 message, "Illegal product type '" + prodname + $
                        "', must be '2AKa', '2AKu', or '2APR'"
               END
   ENDCASE

   ; if we've been given a SCAN parameter value, make sure it appears in the
   ; set of valid swath groups for this product
   IF N_ELEMENTS(onescan) NE 0 THEN BEGIN
      IF TOTAL(STRMATCH(snames, onescan)) NE 1.0 THEN BEGIN
         h5g_close, group_id
         h5f_close, file_id
         message, "Illegal SCAN (swath) parameter value '"+onescan+"' for '" $
               +prodname+"'"
      ENDIF
   ENDIF

   IF filestruc.NUMBEROFSWATHS NE N_ELEMENTS(snames) THEN BEGIN
      h5g_close, group_id
      h5f_close, file_id
      message, "Expect "+STRING(N_ELEMENTS(snames), FORMAT='(I0)') + $
               " swaths in product "+prodname+", have " + $
               STRING(filestruc.NUMBEROFSWATHS, FORMAT='(I0)')
   ENDIF

   ; get the data variables for the swath groups
   for isw = 0, filestruc.NUMBEROFSWATHS-1 do begin
      sname=snames[isw]

      IF N_ELEMENTS(onescan) NE 0 THEN BEGIN
      IF STRMATCH(onescan, sname) EQ 0b THEN BEGIN
         ; this isn't the scan to be read, so we skip it and define empty struct
         print, "" & print, "Skipping swath ", sname
         CASE sname OF
            'HS' : HS = { Swath : sname+": UNREAD" }
            'MS' : MS = { Swath : sname+": UNREAD" }
            'NS' : NS = { Swath : sname+": UNREAD" }  ;case should never happen!
         ENDCASE
         continue
      ENDIF
      ENDIF

      print, "" & print, "Swath ",sname,":"
      prodgroup=prodname+'__'+sname      ; label info for data structures
      ; get the group ID for this swath
      sw_group_id = h5g_open(group_id, sname)

      ; get the SwathHeader for this swath
      CASE prodname OF
         '2AKa' : swathHeaderID = h5a_open_name(sw_group_id, $
                                                sname+'_SwathHeader')
         '2AKu' : swathHeaderID = h5a_open_name(sw_group_id, 'SwathHeader')
         '2APR' : swathHeaderID = h5a_open_name(sw_group_id, 'SwathHeader')
      ENDCASE
      ppsSwathHeader = h5a_read(swathHeaderID)
      ; extract the individual swath header values from the formatted string
      swathstruc = parse_swath_header_group(ppsSwathHeader, $
                                            prodgroup+'_SwathHeader' )
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

      ; get the swath-group-level datasets, put into a structure
      latvarid = h5d_open(sw_group_id, 'Latitude')
      lonvarid = h5d_open(sw_group_id, 'Longitude')
      ptr_datasets = ptr_new(/allocate_heap)

      *ptr_datasets = { source    : prodgroup, $
                        latitude  : h5d_read(latvarid), $
                        longitude : h5d_read(lonvarid) }

      h5d_close, latvarid
      h5d_close, lonvarid
      IF (verbose1) THEN help, *ptr_datasets

      ; get the navigation structure for this swath
      ptr_nav = ptr_new(/allocate_heap)
      *ptr_nav = get_dpr_navigation_group(sw_group_id, prodgroup, READ_ALL=all)
      IF (verbose1) THEN help, *ptr_nav

      ; get the Experimental structure for this swath
      ptr_exp = ptr_new(/allocate_heap)
      *ptr_exp = get_dpr_experimental_group(sw_group_id, prodgroup, READ_ALL=all)
      IF (verbose1) THEN help, *ptr_exp

      ; get the CSF structure for this swath
      ptr_csf = ptr_new(/allocate_heap)
      *ptr_csf = get_dpr_csf_group(sw_group_id, prodgroup, READ_ALL=all)
      IF (verbose1) THEN help, *ptr_csf

      ; get the DSD structure for this swath
      ptr_dsd = ptr_new(/allocate_heap)
      *ptr_dsd = get_dpr_dsd_group(sw_group_id, prodgroup, READ_ALL=all)
      IF (verbose1) THEN help, *ptr_dsd

      ; get the FLG structure for this swath
      ptr_flg = ptr_new(/allocate_heap)
      *ptr_flg = get_dpr_flg_group(sw_group_id, prodgroup, READ_ALL=all)
      IF (verbose1) THEN help, *ptr_flg

      ; get the PRE structure for this swath
      ptr_pre = ptr_new(/allocate_heap)
      *ptr_pre = get_dpr_pre_group(sw_group_id, prodgroup, READ_ALL=all)
      IF (verbose1) THEN help, *ptr_pre

      ; get the SLV structure for this swath
      ptr_slv = ptr_new(/allocate_heap)
      *ptr_slv = get_dpr_slv_group(sw_group_id, prodgroup, READ_ALL=all)
      IF (verbose1) THEN help, *ptr_slv

      ; get the SRT structure for this swath
      ptr_srt = ptr_new(/allocate_heap)
      *ptr_srt = get_dpr_srt_group(sw_group_id, prodgroup, READ_ALL=all)
      IF (verbose1) THEN help, *ptr_srt

      ; get the VER structure for this swath
      ptr_ver = ptr_new(/allocate_heap)
      *ptr_ver = get_dpr_ver_group(sw_group_id, prodgroup, READ_ALL=all)
      IF (verbose1) THEN help, *ptr_ver

      h5g_close, sw_group_id

      CASE sname OF
         'HS' : BEGIN
                  HS = { Swath : sname, $
                         SwathHeader : swathstruc, $
                         ptr_ScanTime : ptr_scantimes, $
                         ptr_scstatus : ptr_scstatus, $
                         ptr_navigation : ptr_nav, $
                         ptr_Experimental : ptr_exp, $
                         ptr_csf : ptr_csf, $
                         ptr_dsd : ptr_dsd, $
                         ptr_flg : ptr_flg, $
                         ptr_pre : ptr_pre, $
                         ptr_slv : ptr_slv, $
                         ptr_srt : ptr_srt, $
                         ptr_ver : ptr_ver, $
                         ptr_datasets : ptr_datasets }
                END
         'MS' : BEGIN
                  MS = { Swath : sname, $
                         SwathHeader : swathstruc, $
                         ptr_ScanTime : ptr_scantimes, $
                         ptr_scstatus : ptr_scstatus, $
                         ptr_navigation : ptr_nav, $
                         ptr_Experimental : ptr_exp, $
                         ptr_csf : ptr_csf, $
                         ptr_dsd : ptr_dsd, $
                         ptr_flg : ptr_flg, $
                         ptr_pre : ptr_pre, $
                         ptr_slv : ptr_slv, $
                         ptr_srt : ptr_srt, $
                         ptr_ver : ptr_ver, $
                         ptr_datasets : ptr_datasets }
                END
         'NS' : BEGIN
                  NS = { Swath : sname, $
                         SwathHeader : swathstruc, $
                         ptr_ScanTime : ptr_scantimes, $
                         ptr_scstatus : ptr_scstatus, $
                         ptr_navigation : ptr_nav, $
                         ptr_Experimental : ptr_exp, $
                         ptr_csf : ptr_csf, $
                         ptr_dsd : ptr_dsd, $
                         ptr_flg : ptr_flg, $
                         ptr_pre : ptr_pre, $
                         ptr_slv : ptr_slv, $
                         ptr_srt : ptr_srt, $
                         ptr_ver : ptr_ver, $
                         ptr_datasets : ptr_datasets }
                END
         ELSE : message, 'What the?!!'
       ENDCASE

   endfor

   h5g_close, group_id
   h5f_close, file_id
   CASE prodname OF
       '2AKa' : outStruc = { FileHeader:filestruc, HS:HS, MS:MS }
       '2AKu' : outStruc = { FileHeader:filestruc, NS:NS }
       '2APR' : outStruc = { FileHeader:filestruc, NS:NS }
        ELSE  : message, "Illegal product '" + prodname + $
                         "', must be '2AKa', '2AKu', or '2APR'"
   ENDCASE

userQuit:
return, outstruc
end
