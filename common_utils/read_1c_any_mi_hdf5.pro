;+
; Copyright © 2014, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; read_1c_any_mi_hdf5.pro         Bob Morris, GPM GV/SAIC   Jan 2014
;
; DESCRIPTION
; Given the full pathname to a 1C-XXX HDF5 file, reads and parses FileHeader
; metadata attributes and all of the data groups and their included datasets. 
; Assembles and returns a structure mimicking the HDF file organization,
; containing all the data read and/or parsed.  Sub-structures for large-array
; datasets and HDF groups containing large-array datasets (e.g., 'S1/ScanTime'
; group) are defined as pointer references-to-structures in the output
; structure 'outstruc'.  Those datasets directly below the swath levels 
; (Latitude, Longitude, Quality, etc.) are bundled into a structure called
; "DATASETS" contained within their parent swath structures.
;
; The list of 'XXX' Microwave Imagers able to be read by this function includes:
; GMI, TMI, SSMI, SSMIS, AMSRE, AMSR2, WIND, MHS, MADRAS, SAPHIR, ATMS.
;
; Returns -1 in case of errors.
;
; PARAMETERS
; ----------
; file   -- Full pathname of the 1C-GMI HDF5 file to be read
; debug  -- Binary keyword parameter, controls output of diagnostic messages.
;           Default = suppress messages.
;
; HISTORY
; -------
; 01/09/14  Morris/GPM GV/SAIC
; - Created from read_1cgmi_hdf5.pro.
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-

FUNCTION read_1c_any_mi_hdf5, file, DEBUG=debug

   outstruc = -1

   verbose1 = KEYWORD_SET(debug)

   if n_elements(file) eq 0 then begin
      filters = ['1C*.HDF5*']
      file = dialog_pickfile(FILTER=filters, $
          TITLE='Select 1C-GMI file to read', $
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
   IF (verbose1) THEN HELP, filestruc
   h5a_close, fileHeaderID
   prodname=filestruc.ALGORITHMID

   ; define swath names used in 1C-xxx products
   CASE prodname OF
     '1CGMI'    : snames=['S1', 'S2']
     '1CTMI'    : snames=['S1', 'S2']
     '1CSSMI'   : snames=['S1', 'S2']
     '1CSSMIS'  : snames=['S1', 'S2', 'S3', 'S4']
     '1CAMSRE'  : snames=['S1', 'S2', 'S3', 'S4', 'S5', 'S6']
     '1CAMSR2'  : snames=['S1', 'S2', 'S3', 'S4', 'S5', 'S6']
     '1CWIND'   : snames=['S1']
     '1CMHS'    : snames=['S1']
     '1CMADRAS' : snames=['S1', 'S2', 'S3']
     '1CSAPHIR' : snames=['S1']
     '1CATMS'   : snames=['S1', 'S2', 'S3', 'S4', 'S5']
   ELSE : BEGIN
        h5g_close, group_id
        h5f_close, file_id
        print, ''
        message, "Valid products: 1CGMI 1CTMI 1CSSMI 1CSSMIS 1CAMSRE 1CAMSR2"+ $
                 " 1CWIND 1CMHS 1CMADRAS 1CSAPHIR 1CATMS", /INFO
        message, "Illegal/unknown product type '" + prodname + "'"
      END
   ENDCASE

   ; get the data variables for the swath groups

   IF filestruc.NUMBEROFSWATHS NE N_ELEMENTS(snames) THEN BEGIN
      h5g_close, group_id
      h5f_close, file_id
      message, "Expect "+STRING(N_ELEMENTS(snames), FORMAT='(I0)') + $
               " swaths in product "+prodname+", have " + $
               STRING(filestruc.NUMBEROFSWATHS, FORMAT='(I0)')
   ENDIF

   for isw = 0, filestruc.NUMBEROFSWATHS-1 do begin
      sname=snames[isw]
      print, "" & print, "Swath ",sname,":"
      prodgroup=prodname+'__'+sname      ; label info for data structures
      ; get the group ID for this swath
      sw_group_id = h5g_open(group_id, sname)

      ; get the SwathHeader for this swath
      swathHeaderID = h5a_open_name(sw_group_id, sname+'_SwathHeader')
      ppsSwathHeader = h5a_read(swathHeaderID)
      ; extract the individual swath header values from the formatted string
      swathstruc = parse_swath_header_group(ppsSwathHeader)
      h5a_close, swathHeaderID

      ; get the ScanTime structure for this swath
      ptr_scantimes = ptr_new(/allocate_heap)
      *ptr_scantimes = get_scantime_group(sw_group_id, prodgroup)
      IF (verbose1) THEN help, *ptr_scantimes

      ; get the SCstatus structure for this swath
      ptr_scstatus = ptr_new(/allocate_heap)
      *ptr_scstatus = get_scstatus_group(sw_group_id, prodgroup)
      IF (verbose1) THEN help, *ptr_scstatus

      ; get the swath-group-level datasets, put into a structure
      latvarid = h5d_open(sw_group_id, 'Latitude')
      lonvarid = h5d_open(sw_group_id, 'Longitude')
      sunvarid = h5d_open(sw_group_id, 'sunGlintAngle')
      qvarid = h5d_open(sw_group_id, 'Quality')
      iavarid = h5d_open(sw_group_id, 'incidenceAngle')
      iaivarid = h5d_open(sw_group_id, 'incidenceAngleIndex')
      tcvarid  = h5d_open(sw_group_id, 'Tc')
      ; get the Tc LongName attribute with the channel-to-dimension assignments
      tcattid = h5a_open_name( tcvarid, 'LongName' )

      ptr_datasets = ptr_new(/allocate_heap)

      *ptr_datasets = { source              : prodgroup,          $
                        latitude            : h5d_read(latvarid), $
                        longitude           : h5d_read(lonvarid), $
                        Quality             : h5d_read(qvarid),   $
                        incidenceAngle      : h5d_read(iavarid),  $
                        sunGlintAngle       : h5d_read(sunvarid), $
                        incidenceAngleIndex : h5d_read(iaivarid), $
                        Tc                  : h5d_read(tcvarid),  $
                        Tc_LongName         : h5a_read(tcattid) }

      h5d_close, latvarid
      h5d_close, lonvarid
      h5d_close, sunvarid
      h5d_close, qvarid
      h5d_close, iavarid
      h5d_close, iaivarid
      h5a_close, tcattid
      h5d_close, tcvarid
      IF (verbose1) THEN help, *ptr_datasets

      h5g_close, sw_group_id

      ; create structure to hold the swath data components
      temp = { Swath : sname, $
               SwathHeader : swathstruc, $
               ptr_ScanTime : ptr_scantimes, $
               ptr_scstatus : ptr_scstatus, $
               ptr_datasets : ptr_datasets }

      ; create (or append to) the returned output structure holding
      ; data for all swaths
      IF (isw EQ 0) THEN outStruc = $
         CREATE_STRUCT('FileHeader', filestruc, 'Swaths', snames, $
                        snames[isw], temp) $
      ELSE outStruc = CREATE_STRUCT(outStruc, snames[isw], temp)

   endfor

   h5g_close, group_id
   h5f_close, file_id

userQuit:
return, outstruc
end
