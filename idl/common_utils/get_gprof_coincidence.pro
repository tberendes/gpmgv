pro get_gprof_coincidence, latTarget_in, lonTarget_in, idTarget_in, sat_inst

; finds and counts the number of rainy GPROF footprints within a cutoff
; distance of a set of radar lat/lon locations for a given satellite. If
; the number of rainy (>=1.0mm/h) footprints exceeds a threshold then the
; scan time, radar ID, satellite ID and orbit number are added to the end of
; the text file "/tmp/constellationTimes.txt".

IF n_elements(sat_inst) EQ 0 then sat_inst='GPM/GMI'

filters = ['*GPROF*.HDF5*']
file = dialog_pickfile( FILTER=filters, $
          TITLE='Select 2AGPROF file to read', $
          PATH='/data/gpmgv/orbit_subset/'+sat_inst+'/2AGPROF/V03C/CONUS/2015/10' )
IF (file EQ '') THEN GOTO, errorExit

; open the text file for metadata output
OPENW, unit, '/tmp/constellationTimes.txt', /APPEND, /GET_LUN

WHILE file NE '' DO BEGIN

; parse the file name to get the satID and orbit number
;   parsedPath = STRSPLIT(file, '/', /extract )
;   satID = parsedPath[0]
   parsedName = STRSPLIT(FILE_BASENAME(file), '.', /extract)
   satID = parsedName[1]
   orbit = LONG(parsedName[5])

; read a gprof file
struc=read_2agprof_hdf5(file, /re)
; extract the scan times and latitude and longitude arrays
year=(*(struc.s1).PTR_SCANTIME).YEAR
day=(*(struc.s1).PTR_SCANTIME).DAYOFMONTH
month=(*(struc.s1).PTR_SCANTIME).MONTH
hour=(*(struc.s1).PTR_SCANTIME).HOUR
minute=(*(struc.s1).PTR_SCANTIME).MINUTE
second=(*(struc.s1).PTR_SCANTIME).SECOND
lat=(*(struc.s1).PTR_datasets).LATITUDE
lon=(*(struc.s1).PTR_datasets).LONGITUDE
rain=(*(struc.s1).PTR_datasets).SURFACEPRECIPITATION
flag=(*(struc.s1).PTR_datasets).pixelStatus
ptr_free, struc.s1.PTR_SCANTIME
ptr_free, struc.s1.PTR_datasets
ptr_free, struc.s1.PTR_SCstatus
raysperscan = struc.s1.SwathHeader.NumberPixels
HELP, rain, flag
for isite = 0, N_ELEMENTS(idTarget_in)-1 do begin
   latTarget = latTarget_in[isite]
   lonTarget = lonTarget_in[isite]
   idTarget = idTarget_in[isite]
   ; locate the points within a degree lat of the target lat/lon
   idxclose = WHERE(lat lt (latTarget+1) and lat gt (latTarget-1) and $
                 lon lt (lonTarget+1/cos(!DTOR*lonTarget)) and $
                 lon gt (lonTarget-1/cos(!DTOR*lonTarget)), npts)
   ; if any, then compute the closest point
   if npts gt 0 THEN BEGIN
      dist = SQRT( (lat(idxclose)-latTarget)^2 + $
                (cos(!DTOR*lonTarget)*(lon(idxclose)-lonTarget))^2 )
      idxmin=-1L
      mindist = MIN(dist, idxmin)
     ; get the scan and ray numbers for the lat/lon arrays at the nearest point
      rayscan = array_indices(lat, idxclose[idxmin])
      scanNum = rayscan[1]
      rayNum = rayscan[0]
     ; skip output if ray is too close to the edge of the swath or if not
     ; enough footprints are above a rain threshold of 1.0 mm/h
      print, ''
      print, idTarget,', ray = ', raynum+1, ' of ', raysperscan
      IF raynum LT raysperscan/10 OR raynum GT (raysperscan-raysperscan/10) THEN CONTINUE
      idx100 = WHERE(dist*111.1 le 100., n100)
      idxrainy = WHERE( rain[idxclose[idx100]] GE 1.0 $
                   AND  flag[idxclose[idx100]] EQ 0b,  nrain)
      print, 'nrain: ', nrain, ' of ', n100
      ;print, rain[idxclose[idx100[idxrainy]]]  ;, dist[idx100[idxrainy]]
      IF nrain LT 50 THEN BEGIN
         print, "Fewer than 50 rainy points, skipping." & CONTINUE
      ENDIF
     ; write metadata to screen and file if rainy event criteria met
      print, year[scanNum], month[scanNum], day[scanNum], hour[scanNum], $
          minute[scanNum], second[scanNum], idTarget, satId, orbit, $
          FORMAT='(I4,"-",I2.2,"-",I2.2," ",I2.2,":",I2.2,":",I2.2,"|",A,"|",A,"|",I0)'
      printf, unit, year[scanNum], month[scanNum], day[scanNum], hour[scanNum], $
          minute[scanNum], second[scanNum], idTarget, satId, orbit, $
          FORMAT='(I4,"-",I2.2,"-",I2.2," ",I2.2,":",I2.2,":",I2.2,"|",A,"|",A,"|",I0)'
   endif ELSE BEGIN
      print, "No points within 1.0 degrees of target ", idTarget
      ;goto, errorExit
   endelse
endfor

; get the next file selection
file = dialog_pickfile( FILTER=filters, $
          TITLE='Select 2AGPROF file to read', $
          PATH='/data/gpmgv/orbit_subset/'+sat_inst+'/2AGPROF/V03C/CONUS/2015/10' )

ENDWHILE

FREE_LUN, unit

errorExit:
end
