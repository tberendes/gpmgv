;+
; Copyright © 2013, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; read_3imerg_hdf5.pro         Bob Morris, GPM GV/SAIC   December 2013
;
; DESCRIPTION
; Given the full pathname to a 3IMERG* HDF5 file, reads and parses FileHeader
; metadata attributes and all of the data groups and their included datasets. 
; Assembles and returns a structure mimicking the HDF file organization,
; containing all the data read and/or parsed.  Sub-structures for large-array
; datasets and HDF groups containing large-array datasets  are defined as
; pointer references-to-structures in the output structure 'outstruc'.
;
; Returns -1 in case of errors.
;
; PARAMETERS
; ----------
; file      -- Full pathname of the 3IMERGH/3IMERGM HDF5 file to be read
; debug     -- Binary keyword parameter, controls output of diagnostic messages.
;              Default = suppress messages.
; read_all  -- Binary parameter.  If set, then read and return all datasets in
;              the groups.  Otherwise, just read the datasets needed for basic
;              display and processing (subjective list).
;
; HISTORY
; -------
; 12/23/13  Morris/GPM GV/SAIC
; - Created from read_2agprofgmi_hdf5.pro.
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-

FUNCTION read_3imerg_hdf5, file, DEBUG=debug, READ_ALL=read_all

   outstruc = -1

   all = KEYWORD_SET(read_all)
   verbose1 = KEYWORD_SET(debug)

   if n_elements(file) eq 0 then begin
      filters = ['*3IMERG*.HDF5*']
      file = dialog_pickfile( FILTER=filters, $
                TITLE='Select 3IMERG file to read', $
                PATH='/data/gpmgv/GPMtest' )
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

   IF prodname NE '3IMERGH' AND prodname NE '3IMERGM' THEN BEGIN
      h5g_close, group_id
      h5f_close, file_id
      message, "Illegal product type '" + prodname + $
               "', must be '3IMERGH' or '3IMERGM'"
   ENDIF

   ; define the grid groups according to product type
   IF filestruc.NUMBEROFGRIDS NE 1 THEN BEGIN
      h5g_close, group_id
      h5f_close, file_id
      message, "Expect 1 grid in product, have " + $
               STRING(filestruc.NUMBEROFGRIDS, FORMAT='(I0)')
   ENDIF

   ; get the data variables for the grid groups
   for isw = 0, filestruc.NUMBEROFGRIDS-1 do begin
      prodgroup=prodname      ; label info for data structures
      ; get the group ID for this grid
      grid_group_id = h5g_open(group_id, 'Grid')

      ; get the GridHeader for this grid

      ; get the ID of GridHeader group
      ; -- first, check that this group contains a GridHeader group
      CATCH, error
      IF error EQ 0 THEN BEGIN
         gridHeaderID = h5a_open_name(grid_group_id, 'GridHeader')
         ppsGridHeader = h5a_read(gridHeaderID)
         ; extract the individual grid header values from the formatted string
         grid_struc = parse_grid_header_group(ppsGridHeader)
         h5a_close, gridHeaderID
      ENDIF ELSE BEGIN
         help,!error_state,/st
         Catch, /Cancel
         message, 'err='+STRING(error)+", "+!error_state.msg, /INFO
         grid_struc = -1
      ENDELSE
      Catch, /Cancel
      IF (verbose1) THEN help, grid_struc

      ; get the structure with the grid-level datasets
      ptr_datasets = ptr_new(/allocate_heap)
      *ptr_datasets = get_3imerg_datasets(grid_group_id, prodgroup, $
                                          READ_ALL=all)
      IF (verbose1) THEN help, *ptr_datasets

      h5g_close, grid_group_id

   endfor

   h5g_close, group_id
   h5f_close, file_id
   outStruc = { FileHeader:filestruc, GridHeader:grid_struc, GridData:ptr_datasets }

userQuit:
return, outStruc
end
