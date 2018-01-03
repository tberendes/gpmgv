pro run_read2a23

file_2a23='/data/gpmgv/prsubsets/2A23/2A23.090904.67242.6.sub-GPMGV1.hdf.gz'                
common sample, start_sample, sample_range, num_range, RAYSPERSCAN
@pr_params.inc
   status=''
; Check status of file_2a23 before proceeding -  actual file
; name on disk may differ if file has been uncompressed already.
;
   readstatus = 0

   havefile = find_alt_filename( file_2a23, found2a23 )
   if ( havefile ) then begin
;     Get an uncompressed copy of the found file
      cpstatus = uncomp_file( found2a23, file23_2do )
      if(cpstatus eq 'OK') then begin
         SAMPLE_RANGE=0
         START_SAMPLE=0
         num_range = NUM_RANGE_2A25
         geolocation=fltarr(2,RAYSPERSCAN,sample_range>1)
         rainType=intarr(sample_range>1,RAYSPERSCAN)
         statusFlag=bytarr(sample_range>1,RAYSPERSCAN)
         BBstatus=bytarr(sample_range>1,RAYSPERSCAN)

         status = read_2a23_ppi( file23_2do, RAINTYPE=rainType,     $
                           GEOL=geolocation, STATUSFLAG=statusFlag, $
                           BBSTATUS=BBstatus )

         IF status NE 'OK' THEN readstatus = 1
;        Delete the temporary file copy
         print, "Remove 2A23 file copy:"
         command = 'rm ' + file23_2do
         print, command
         spawn, command
      endif else begin
         print, cpstatus
         readstatus = 1
      endelse
   endif else begin
      print, "Cannot find regular/compressed file " + file_2a23
      readstatus = 1
   endelse
   help
   print, status, readstatus
end
