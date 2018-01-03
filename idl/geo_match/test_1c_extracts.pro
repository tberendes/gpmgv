pro test_1c_extracts, file_1CRXCAL

   have1c=1
  ; get the 1CRXCAL Tc and Quality variables if file is available
   IF have1c THEN BEGIN
      data1c = read_1c_any_mi_hdf5( file_1CRXCAL )
     ; get the number and names of the tags in the structure
      ntags1c = N_TAGS(data1c)
      datatags1c = TAG_NAMES(data1c)
     ; get the number of swaths in the data1c structure
      nsw1c = N_ELEMENTS(data1c.swaths)
     ; find the substructure for each swath name and get its Tc information
      nchannels = INTARR(nsw1c)
      for i=0,nsw1c-1 do begin
         idxsw = WHERE( STRMATCH(datatags1c, data1c.swaths[i]) EQ 1, nmatch)
         IF nmatch NE 1 THEN $
            message, "Error extracting swath data from 1C data structure."
        ; get the Tc array dimensions for each swath
         tcdims = SIZE( (*data1c.(idxsw).PTR_DATASETS).Tc )
         IF tcdims[0] NE 3 THEN message, "Wrong number of dimensions for Tc array!"
         nchannels[i] = tcdims[1]
         if i EQ 0 THEN BEGIN
            npixlast = tcdims[2]
            nscanslast = tcdims[3]
         endif else begin
            if ( npixlast NE tcdims[2] OR nscanslast NE tcdims[3] ) THEN $
               message, "Mismatched Tc ray,scan dimensions between swaths!"
         endelse
      endfor
     ; define an array sized to hold the Tc and Quality values for all swaths' channels
      Tc_all = FLTARR( TOTAL(nchannels), npixlast, nscanslast )
      Quality_all = INTARR( TOTAL(nchannels), npixlast, nscanslast )

     ; define arrays sized to hold the latitude and longitude values for all swaths
      Lat1c_all = FLTARR( nsw1c, npixlast, nscanslast )
      Lon1c_all = Lat1c_all

     ; define a STRING array to hold the names of all the channels
      Tc_Names = STRARR( TOTAL(nchannels) )

     ; step through the swaths' data and populate the combined data arrays
      idxchanstart = 0  ; first dimension's starting value for current swath's channel
      idxchanend = TOTAL(nchannels, /CUMULATIVE)  ; first dimension's next start

      for i=0,nsw1c-1 do begin
         idxsw = WHERE( STRMATCH(datatags1c, data1c.swaths[i]) EQ 1, nmatch)
        ; get and assign swath's lat/lon data into their merged arrays
         Lat1c_all[i,*,*] = (*data1c.(idxsw).PTR_DATASETS).LATITUDE
         Lon1c_all[i,*,*] = (*data1c.(idxsw).PTR_DATASETS).LONGITUDE
        ; get the Tc array and longnames string for this swath
         tc = (*data1c.(idxsw).PTR_DATASETS).Tc
         Qual = (*data1c.(idxsw).PTR_DATASETS).Quality
print, "max(qual), min(qual): ", max(qual), min(qual)
         tcNamesStr = (*data1c.(idxsw).PTR_DATASETS).TC_LONGNAME
        ; assign Tc channel-specific data into the merged array
         Tc_all[idxchanstart:idxchanend[i]-1, *, *] = Tc
        ; copy the in-common Quality values for the set of channels to each
        ; channel's slot in the merged array
         for ichan = idxchanstart, idxchanend[i]-1 do Quality_all[ichan, *, *] = FIX(qual)
        ; call extract_tc_channel_names to assign TcNames for this swath's channels
         tcNameStatus = extract_tc_channel_names(Tc_Names, tcNamesStr, $
                                                 idxchanstart, nchannels[i])
         idxchanstart = idxchanend[i]  ; reset start channel for next swath
      endfor

     ; convert the unsigned Quality values to signed
      idx2sign = WHERE(Quality_all GT 127, n2sign)
      if n2sign GT 0 then Quality_all[idx2sign] = Quality_all[idx2sign]-256

     ; find the point locations where lat and lon are non-missing for all swaths
      minlats = MIN(Lat1c_all, DIMENSION=1)
      minlons = MIN(Lon1c_all, DIMENSION=1)
      idxllgood=WHERE(minlats GT -90.0 and minlons GE -180.0)
      llidx = array_indices(minlons, IDXLLGOOD)
     ; grab the first good point and make sure its lat/lon are the same between
     ; the 2AGPROF and the 1CRXCAL product
      ray1 = llidx[0,0]
      scan1 = llidx[1,0]
      lat1c2chk = Lat1c_all[0,ray1,scan1]
      lon1c2chk = Lon1c_all[0,ray1,scan1]
print, Lat1c_all[*,ray1,scan1]
print, Lon1c_all[*,ray1,scan1]
   ENDIF
help, tcNameStatus
print, Tc_Names
print, file_1CRXCAL
  ; read the 2AGPROF data for the same satellite/orbit/subset/version
   status = read_2agprof_hdf5( )
   gmiLons = (*status.S1.ptr_datasets).Longitude
   gmiLats = (*status.S1.ptr_datasets).Latitude
   lat2a2chk = gmiLats[ray1,scan1]
   lon2a2chk = gmiLons[ray1,scan1]
   help, lat1c2chk, lat2a2chk
   help, lon1c2chk, lon2a2chk
stop
end
