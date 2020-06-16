;+
; Copyright © 2013, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; read_2adpr_env_hdf5.pro         Bob Morris, GPM GV/SAIC   June 2013
;
; DESCRIPTION
; Given the full pathname to a 2AKuENV, 2AKaENV, or 2ADPRENV HDF5 file, reads
; and parses the FileHeader metadata attributes and all of the data groups and
; their included datasets.
; Assembles and returns a structure mimicking the HDF file organization,
; containing all the data read and/or parsed.  Sub-structures for large-array
; datasets and HDF groups containing large-array datasets (e.g., 'MS/VERENV'
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
;              display and processing (subjective list).  THIS PARAMETER IS A
;              DO-NOTHING FOR THIS FUNCTION AND IS ONLY IMPLEMENTED TO BE
;              COMPATIBLE WITH THE OTHER read_XXXX_hdf5.pro FUNCTIONS.
;
; HISTORY
; -------
; 06/04/13  Morris/GPM GV/SAIC
; - Created.
; 06/12/13  Morris/GPM GV/SAIC
; - Added READ_ALL option to pare down the datasets read by default.
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-

FUNCTION read_2adpr_env_hdf5, file, DEBUG=debug, READ_ALL=read_all

   outstruc = -1

   placeholder = KEYWORD_SET(read_all)
   verbose1 = KEYWORD_SET(debug)
   IF verbose1 AND placeholder THEN $
      message, "READ_ALL parameter not implemented, ignoring.", /INFO

   if n_elements(file) eq 0 then begin
      filters = ['2A_ENV*K*.HDF5*;2A_ENV*DPR*.HDF5*']
      file=dialog_pickfile(FILTER=filters, $
          TITLE='Select 2A_ENV_K* file to read', $
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
      '2ADPRENV' : snames=['HS', 'NS']   ; prefixes used in 2Axxx products
       '2AKaENV' : snames=['HS', 'MS']
       '2AKuENV' : snames=['NS']
       ELSE  : BEGIN
                 h5g_close, group_id
                 h5f_close, file_id
                 message, "Illegal product type '" + prodname + $
                    "', must be '2ADPRENV', '2AKaENV' or '2AKuENV'"
               END
   ENDCASE

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
      print, "" & print, "Swath ",sname,":"
      prodgroup=prodname+'__'+sname      ; label info for data structures
      ; get the group ID for this swath
      sw_group_id = h5g_open(group_id, sname)

      ; get the SwathHeader for this swath
      CASE prodname OF
         '2AKuENV' : swathHeaderID = h5a_open_name(sw_group_id, 'SwathHeader')
              ELSE : swathHeaderID = h5a_open_name(sw_group_id, $
                                                   sname+'_SwathHeader')
      ENDCASE
      ppsSwathHeader = h5a_read(swathHeaderID)
      ; extract the individual swath header values from the formatted string
      swathstruc = parse_swath_header_group(ppsSwathHeader)
      h5a_close, swathHeaderID
      IF (verbose1) THEN help, swathstruc

      ; get the ScanTime structure for this swath
      ptr_scantimes = ptr_new(/allocate_heap)
      *ptr_scantimes = get_scantime_group(sw_group_id, prodgroup)
      IF (verbose1) THEN help, *ptr_scantimes

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

      ; get the VERENV structure for this swath
      ptr_ver = ptr_new(/allocate_heap)
      *ptr_ver = get_dpr_verenv_group(sw_group_id, prodgroup)
      IF (verbose1) THEN help, *ptr_ver

      h5g_close, sw_group_id

      CASE sname OF
         'HS' : BEGIN
                  HS = { Swath : sname, $
                         SwathHeader : swathstruc, $
                         ptr_ScanTime : ptr_scantimes, $
                         ptr_ver : ptr_ver, $
                         ptr_datasets : ptr_datasets }
                END
         'MS' : BEGIN
                  MS = { Swath : sname, $
                         SwathHeader : swathstruc, $
                         ptr_ScanTime : ptr_scantimes, $
                         ptr_ver : ptr_ver, $
                         ptr_datasets : ptr_datasets }
                END
         'NS' : BEGIN
                  NS = { Swath : sname, $
                         SwathHeader : swathstruc, $
                         ptr_ScanTime : ptr_scantimes, $
                         ptr_ver : ptr_ver, $
                         ptr_datasets : ptr_datasets }
                END
         ELSE : message, 'What the?!!'
       ENDCASE

   endfor

   h5g_close, group_id
   h5f_close, file_id
   CASE prodname OF
      '2ADPRENV' : outStruc = { FileHeader:filestruc, HS:HS, NS:NS }
       '2AKaENV' : outStruc = { FileHeader:filestruc, HS:HS, MS:MS }
       '2AKuENV' : outStruc = { FileHeader:filestruc, NS:NS }
       ELSE  : message, "Illegal product '" + prodname + $
                        "', must be '2ADPRENV', '2AKaENV' or '2AKuENV'"
   ENDCASE

userQuit:
return, outstruc
end
