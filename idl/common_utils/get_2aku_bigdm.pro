pro get_2aku_bigdm

   ncfilelist='/tmp/BigDmFiles.lis'
  ; find out how many files are listed in the file 'ncfilelist'
   command = 'wc -l ' + ncfilelist
   spawn, command, result
   nf = LONG(result[0])
   IF (nf LE 0) THEN BEGIN
      print, "" 
      print, "No files listed in ", ncfilelist
      print, " -- Exiting."
      GOTO, earlyExit
   ENDIF
;   IF N_ELEMENTS(ncsitepath) EQ 1 THEN ncpre=ncsitepath+'/' ELSE ncpre=''
   ncpre=''
   prfiles = STRARR(nf)
   OPENR, ncunit, ncfilelist, ERROR=err, /GET_LUN
   ; initialize the variables into which file records are read as strings
   dataPR = ''
   ncnum=0
   WHILE NOT (EOF(ncunit)) DO BEGIN 
     ; get GRtoPR filename
      READF, ncunit, dataPR
      ncfull = ncpre + STRTRIM(dataPR,2)
      IF FILE_TEST(ncfull, /REGULAR) THEN BEGIN
         prfiles[ncnum] = ncfull
         ncnum++
      ENDIF ELSE message, "File "+ncfull+" does not exist!", /INFO
   ENDWHILE  ; each matchup file to process in control file
   CLOSE, ncunit
   nf = ncnum
   IF (nf LE 0) THEN BEGIN
      print, "" 
      message, "No files listed in "+ncfilelist+" were found.", /INFO
      print, " -- Exiting."
      GOTO, earlyExit
   ENDIF

   for fnum = 0, nf-1 do begin
      ncfilepr = prfiles(fnum)
      bname = file_basename( ncfilepr )
      parsed = STRSPLIT( bname, '.', /extract )
      orbit = parsed[3]
      orbfilter= ['2A*K*'+orbit+'*.HDF5*']
      file=dialog_pickfile(FILTER=orbfilter, $
          TITLE=bname, $
          PATH='/data/emdata/orbit_subset/GPM/Ku/2AKu/ITE109/CONUS/')
      if file EQ '' then goto, earlyExit
      data = read_2akaku_hdf5_bigdm( file, DEBUG=debug, READ_ALL=read_all, SCAN=scan2read )
      free_ptrs_in_struct, data
   endfor

earlyExit:
end
