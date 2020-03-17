PRO final_grid_orbit_MSandNS

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;This script reads in 2BDPRGMI data and grids it to CONUS as a function of orbit number.		;
;It initially lists all the orbit numbers per year, then sorts the orbit numbers and			;
;then reads in the original .nc files as a function of orbit number. For instance, 			;
;for 2014, orbit number 503 consisted of 2 original files, while orbit number 1917			;
;consisted of 10 original files. For sake of ease, I will use orbit number 503 (from 2014) 		;
;as an example. The script will automatically find the following two files for orbit number 503: 	;
;GRtoDPRGMI.KARX.140401.503.V06A.1_3.15dBZ_7km.nc.gz  and 						;
;GRtoDPRGMI.KMVX.140401.503.V06A.1_3.15dBZ_7km.nc.gz							;
;A "Large array" is then created to store ALL the data from BOTH files (this is to make the gridding	;
;easier later in the script). All the necessary variables from the original two files are then 		;
;read into the "Large" arrays. The information from the "Large" array are then gridded according to	;
;5 x 5 x 1 km (x, y, z) for the following domain: 							;
;Lat0=20.0 ;Bottom left corner of domain								;
;Lon0=-130.0 ;Bottom left corner of domain								;
;LatEnd=55.0 ;Top right corner of domain								;
;LonEnd=-60.0 ;Top right corner of domain								;
;IF an original file falls outside of these boundaries, then the files are NOT read in.			;
;The gridding of the data occurs in the following manner:						;
;Find ALL variables/values that fall within each 5 x 5 x 1 km grid point. For example, let's say	;
;there are 4 values for each variable. From the 4 values, the script finds the LOCATION of the		;
;median reflectivity value and saves this location. This location is then used as the location of	;
;all the other variables. I.e., if the reflectivity consisted of 4 values:				;
;Z_MS_0: 26.1531      21.8030      21.4294      19.3298							;
;The median value is 21.8030 and it's location in the arrays is [1] {on a 0-scale}			;
;Therefore, the value for the rest of the variables will be as follows:					;
;lat_MS_0: 43.2002      43.1634      43.2006      43.1638; lat_MS_0[1]=43.1634				;
;topH_MSL_MS_0: 2.93812      3.01954      3.97439      4.08328; topH_MSL_MS_0[1]=3.01954		;
;and so forth.												;
;It was decided to use the location of the median reflecitivty value so that the gridded variables	;
;are for the same location (this makes things far more consistent)					;
;Once the information is found for all the variables, they are saved in arrays and saved to the		;
;gridded .nc file as well as compressed: GRtoDPRGMI.gridded.CONUS.140401.503.V06A.1_3.15dBZ_comp.nc.gz	;
;Since the _MS and _NS variables have different array sizes, their calculations were done separately.	;
;Also, ALL variables have their own arrays to make it easier in future to either (1) add more arrays or ;
;(2) remove any arrays that are not necessary, BUT it makes the script very long (~4000 lines).		;
;													;
;Final version: 23 May 2019										;
;Creator: Retha M. Mecikalski										;
;IMPORTANT: It is best to run this script on MOSSELBAY, since I know everything works on this machine!	;
;Mosselbay is owned by UAH, so there should not be any problems getting access to the machine.		;
;													;
;To run the script: 											;
;IDL> .r final_grid_orbit_MSandNS_May2019.pro								;
;IDL> final_grid_orbit_MSandNS_May2019									;
;You will have to change the following:									;
;indir='/rstor/matthee/GPM-HID/DATA/gpmgv/netcdf/geo_match/GPM/2BDPRGMI/V06A/1_3/' => You will need 	;
;  to change the directory location to where your original data is located				;
;year=['2014','2015','2016','2017','2018'] => You can either run ALL years at once or choose one	;
;  year at a time (I suggest running one year at a time, since the script takes up a lot of memory) 	;
;for dd=0, n_elements(unique_orbitnr)-1 do begin => If you do not want to run all orbits for a 		;
;  specific year, then you can change the "dd" for loop to an actual number. 				;
;You HAVE TO create a "gridded_CONUS" directory in the same directory as your data:			;
;i.e.,: indir/gridded_CONUS/										;
;The gridded filename will be located here:								;
;   indir+'gridded_CONUS/'+strcompress(year[aa])+'/GRtoDPRGMI.gridded.CONUS.'+$				;
;    strcompress(filedate[0],/remove_all)+'.'+strcompress(grid_orbitnr,/remove_all)+'.V06A.1_3.15dBZ.nc';
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;Create the x- and y-grid dimensions for CONUS using the following lat/lon values:
;(1) Lat=20 N, Lon=130 W; xgrid=0 km, ygrid=0 km
;(2) Lat=55 N, Lon=130 W; xgrid=0 km, ygrid=3,875 km
;(3) Lat=55 N, Lon=60 W;  xgrid=7,325 km, ygrid=3,875 km
;(4) Lat=20 N, Lon=60 W;  xgrid=7,325 km, ygrid=0 km
xgrid=findgen(1466, start=0.0, increment=5.0) ;From 0 to 7,325 km in 5 km intervals for 1,466 grid boxes
ygrid=findgen(776, start=0.0, increment=5.0) ;From 0 to 3,875 km in 5 km intervals for 776 grid boxes
zgrid=[2.0,3.0,4.0,5.0,6.0,7.0,8.0,9.0,10.0,11.0,12.0,13.0,14.0,15.0,16.0,17.0,18.0] ;This is the altitude grid for 17 grid boxes

;These are needed to convert from Lat/lon to x/y and back to lat/lon:
R=6371.22 ;Km, Radius of Earth
Lat0=20.0 ;Center latitude (Actually the bottom left corner, but need to avoid negative values)
Lon0=-130.0 ;Center longitude (Actually the bottom left corner, but need to avoid negative values)
LatEnd=55.0 ;Top right corner of domain
LonEnd=-60.0 ;Top right corner of domain
Spacing_lat=5.0/(R*!pi/180.0) ;These are "regular" spacings between my grid points (ito degees)
Spacing_lon=5.0/(R*Cos(20.0*!DTOR))*(180.0/!pi) ;These are "regular" spacings between my grid points (ito degees)

;To create the index numbers for the x_grid and y_grid values:
x_index=findgen(1466, start=0.0, increment=1.0) 
y_index=findgen(1466, start=0.0, increment=1.0)

;This is to find the latitude and longitude values for my x_grid and y_grid values:
LatNew=Lat0+y_index*Spacing_lat
LonNew=Lon0+x_index*Spacing_lon
grid_latitude_main=LatNew[0:775] ;Since we're only dealing with Lat from 20.0 to 55.0
grid_longitude_main=LonNew[0:1465] ;Since we're dealing with Lon from -130.0 to -60.0

;This is where the original files are located that are used to create the gridded files:
;indir='/rstor/matthee/GPM-HID/DATA/gpmgv/netcdf/geo_match/GPM/2BDPRGMI/V06A/1_3/'

indir='/data/gpmgv/netcdf/gridded_vn/test/'
;year=['2014','2015','2016','2017','2018']
year=['2017'] ;You can either add ALL the years, or run the script per year

for aa = 0, n_elements(year)-1 do begin  ;for the years listed
  spawn, '/bin/ls '+indir+strcompress(year[aa]), inlist
  inlistsize=size(inlist, /dimensions)
  count=inlistsize

  print, ''
  print, 'Number of files = ', count
  print, ''

  filename=inlist

  ;We need to find the radar name and date before we can find the orbit numbers!
;  radar_sub=strmid(filename, 11, 6) ;Making the radar name 6 to avoid everything being -1
  radar_sub=strmid(filename, 11, 10) ;Making the radar name 8 to avoid everything being -1
  testradar=strpos(radar_sub[*], '.')
  radar_sub2=strarr(n_elements(filename))
  radarname=strarr(n_elements(filename))
  namelength=intarr(n_elements(filename))
  date=strarr(n_elements(filename))
  date2=string(date) ;so we can find the string lenght!
  orbitlength=intarr(n_elements(filename))
  orbitnr_sub2=strarr(n_elements(filename))
  orbitnr_sub=lonarr(n_elements(filename))
  testorbit=intarr(n_elements(filename))
  orbitnr=strarr(n_elements(filename))

  ;For the number of TOTAL files for each year:
  for bb=0, n_elements(filename)-1 do begin
    radar_sub2[bb]=strmid(radar_sub[bb], 0, testradar[bb])
    radarname[bb]=reform(radar_sub2[bb])

    namelength[bb]=strlen('GRtoDPRGMI.'+radarname[bb]+'.')  
    date[bb]=strmid(filename[bb], namelength[bb], 6)
    date2[bb]=string(date[bb])
    print ,"date[bb]: ",date[bb], " radarname[bb]: ", radarname[bb]
 
    orbitlength[bb]=strlen('GRtoDPRGMI.'+strcompress(radarname[bb])+'.'+strcompress(date2[bb]))
    orbitnr_sub2[bb]=strmid(filename[bb], orbitlength[bb]+1, 6) ;To account for varying orbit numbers
    testorbit[bb]=strpos(orbitnr_sub2[bb], '.')
    orbitnr_sub[bb]=strmid(orbitnr_sub2[bb], 0, testorbit[bb])
    orbitnr[bb]=reform(orbitnr_sub[bb])

  endfor ;bb to find the correct orbit numbers and dates and radar names

  print, 'radar name = ', radarname
  print, 'date_sub = ', date
  print, 'orbit number = ', orbitnr

  ;Now you have to sort and "count" the orbit numbers, especially those that repeat
  sortorbitnr=orbitnr[sort(orbitnr)]
  loc_sortorbitnr=sort(orbitnr)
  sortradar=radarname[loc_sortorbitnr]
  sortdate=date[loc_sortorbitnr]

  ;To find the "unique" orbit number, so you can remove all the duplicates from the loop:
  unique_orbitnr=sortorbitnr[uniq(sortorbitnr)]
  print, 'unique orbit numbers = ', unique_orbitnr ;This tells you how many loops there will be for each year
  orbitcount=intarr(n_elements(unique_orbitnr))

  for cc=0, n_elements(unique_orbitnr)-1 do begin
    whereorbitnr=orbitnr[where(unique_orbitnr[cc] eq orbitnr[*], count_eachorbit)]
    orbitcount[cc]=count_eachorbit
    ;print, 'Actual orbit number= ', unique_orbitnr[cc], '   Orbit repeat count = ',  orbitcount[cc]
  endfor ;cc number of unique orbits

  ;Now for the actual read-in of the files and analyses...
  print, '*********************************'
  print, '***It is reading in the files!***'
  print, '*********************************'

  ;For each unique orbit number do the actual analyses:
  ;NOTE: dd=0: Orbit=503, 2 files;  dd=16: Orbit=636, 5 files;  dd=187: Orbit=1917, 10 files
  for dd=0, n_elements(unique_orbitnr)-1 do begin
  ;for dd=0, 0 do begin ;Testing with one orbit only (2 files):
    spawn, '/bin/ls '+indir+strcompress(year[aa])+'/GRtoDPRGMI.*.*.'+strcompress(unique_orbitnr[dd], $
           /remove_all)+'.V06A.1_3.15dBZ_7km.nc.gz', inlist_new

    print, ''
    print, '*** NEW ORBIT NUMBER***'
    print, 'Unique orbit numbers in the orbit:', unique_orbitnr[dd]
    print, 'This is orbit number [dd] ', strcompress(dd), ' of ', $
	   strcompress(n_elements(unique_orbitnr)), ' loops'
    print, 'Radar files to read in (inlist_new):'
    print, inlist_new
    final_orbitnr=unique_orbitnr[dd]
           
    ;We need to find the radar name and date again (for only the files we are looking at)
    ;We are now also including the entire directory and not just the filename
    pathlen = strpos(inlist_new,'/',/REVERSE_SEARCH) +strlen('GRtoDPRGMI.')+1 ; add one for trailing dot 
    print, 'pathlen ', pathlen
    fileradar_sub=strmid(inlist_new, pathlen, 10) ; catch up to 10 char site names   
;    fileradar_sub=strmid(inlist_new, 89, 6) ;Making the radar name 6 to avoid everything being -1
    filetestradar=strpos(fileradar_sub[*], '.')
    fileradar_sub2=strarr(n_elements(inlist_new))
    fileradarname=strarr(n_elements(inlist_new))
    filenamelength=intarr(n_elements(inlist_new))
    filedate=strarr(n_elements(inlist_new))
;    filedate2=string(filedate) ;so we can find the string lenght again
    new_filename2=strarr(n_elements(inlist_new))
    sub_newfilename=new_filename2 ;To set the same string arrays
    sub_filename2=new_filename2
    new_filename=new_filename2
    ;The _NS domain is usually larger than the _MS domain:
    testminlat_NS=fltarr(n_elements(inlist_new))
    testmaxlat_NS=fltarr(n_elements(inlist_new))
    testminlon_NS=fltarr(n_elements(inlist_new))
    testmaxlon_NS=fltarr(n_elements(inlist_new))

    count_fpdim_MS=intarr(n_elements(inlist_new)) ;To get the number of lines in each file
    count_fpdim_NS=intarr(n_elements(inlist_new))
    count_elevationAngle=intarr(n_elements(inlist_new))
    count_timedimids_MS=intarr(n_elements(inlist_new))
    count_timedimids_NS=intarr(n_elements(inlist_new))
    nr_files=n_elements(inlist_new)
     
    for ee=0, n_elements(inlist_new)-1 do begin
      slashpos = strpos(inlist_new[ee],'/', /REVERSE_SEARCH)
      print,'slashpos: ',slashpos
      fileradar_sub2[ee]=strmid(fileradar_sub[ee], 0, filetestradar[ee]+1)
      fileradarname[ee]=reform(fileradar_sub2[ee])
      ;This is just to get the radar name and isn't the actual charachter length of the entire file name!
      print,'inlist_new[ee]: ',inlist_new[ee] 
;      filenamelength[ee]=strlen(indir+strcompress(year[aa])+'/GRtoDPRGMI.'+fileradarname[ee]+'.')

      print,'fileradarname[ee]: ',fileradarname[ee]
      filenamelength[ee]=slashpos+1+strlen('GRtoDPRGMI.') +strlen(fileradarname[ee]) + 1 ; add for dot and one past dot
      print,'filenamelength[ee]: ',filenamelength[ee]
      filedate[ee]=strmid(inlist_new[ee], filenamelength[ee]-1, 6)
      print,'filedate[ee]: ',filedate[ee]
;      filedate2[ee]=string(filedate[ee])
      new_filename2[ee]=strmid(inlist_new[ee], slashpos+1, 60) ;To ensure all orbit numbers are included
;      new_filename2[ee]=strmid(inlist_new[ee], 78, 60) ;To ensure all orbit numbers are included
      sub_newfilename[ee]=strlen(new_filename2[ee])-3 ;To get rid of the .gz
      sub_filename2[ee]=strmid(new_filename2[ee], 0, sub_newfilename[ee])
      new_filename[ee]=reform(sub_filename2[ee])
      print, 'Radar name and date for file[ee]: ', fileradarname[ee], ' ', filedate[ee]
      print, 'Unzipped file names[ee]: ', new_filename[ee]

      ;This is where all the files and the variables are read in 
      spawn, 'gunzip '+inlist_new[ee]

      fid=ncdf_open(indir+'/'+strcompress(year[aa])+'/'+new_filename[ee], /nowrite)

      ;To figure out if the lat and lon of the file falls within the CONUS grid domain:
      ncdf_varget, fid, 'latitude_NS', latitude_NS
      ncdf_varget, fid, 'longitude_NS', longitude_NS
      testminlat_NS[ee]=min(latitude_NS)
      testmaxlat_NS[ee]=max(latitude_NS)
      testminlon_NS[ee]=min(longitude_NS)
      testmaxlon_NS[ee]=max(longitude_NS)

      ;To test whether the file domain falls within the CONUS domain. If it is, then read in the file:
      testdomain=where(testminlat_NS ge Lat0 and testmaxlat_NS le LatEnd and testminlon_NS ge Lon0 and $
                 testmaxlon_NS le LonEnd, count_testdomain)

      print, 'count_testdomain', count_testdomain
      if count_testdomain eq 0 then count_fpdim_MS[ee]=0
      if count_testdomain eq 0 then count_fpdim_NS[ee]=0
      if count_testdomain eq 0 then print, 'The file domain is outside of the CONUS domain; Moving on to next file'
      if count_testdomain eq 0 then spawn, 'gzip '+indir+'/'+strcompress(year[aa])+'/'+new_filename[ee]

      if count_testdomain gt 0 then begin
        finq = NCDF_INQUIRE(fid)		

        dim_unlimited = finq.recdim		
          if (finq.ndims gt 0) then begin
 	     dimstr = ' '
	     dimsize = 0L
	     dim_name = strarr(finq.ndims)
	     dim_size = lonarr(finq.ndims)
	     for k=0,finq.ndims-1 do begin
		NCDF_DIMINQ, fid, k, dimstr, dimsize
		dim_name[k] = dimstr
		dim_size[k] = dimsize
                count_fpdim_MS[ee]=dim_size[0]
		count_fpdim_NS[ee]=dim_size[1]
		count_elevationAngle[ee]=dim_size[2]
		count_timedimids_MS[ee]=dim_size[9]
		count_timedimids_NS[ee]=dim_size[10]
	     endfor
          endif 

	NCDF_CLOSE, fid
	print, 'dim name = ', dim_name
	print, 'dim_size = ', dim_size

	print, 'count_fpdim_MS, count_fpdim_NS, count_timedimids_MS, count_timedimids_NS', 'count_elevationAngle'
	print, count_fpdim_MS, count_fpdim_NS, count_timedimids_MS, count_timedimids_NS, count_elevationAngle

      endif ;The test for the domain size (count_testdomain)

    endfor ;ee the files that are currently in the list

    ;Need these arrays to save the actual data into:
    total_fpdim_MS=total(count_fpdim_MS)
    total_fpdim_NS=total(count_fpdim_NS)

    ;Now to make sure that the arrays are only created for the files that fall within the CONUS domain:
    if total_fpdim_NS gt 0 and total_fpdim_MS gt 0 then begin

      ;Using the "complete set of fixed elevation angles (in degrees) on which the blockage data may be defined" $
      ;as the total number of elevation angles for the large file: 
      ;total_elevationAngle=[0.484375,0.875,1.3125,1.45312,1.79688,2.42188,2.5,3.125,3.39062,3.51562,$
      ;                      4.0,4.3125,4.48438,5.09375,5.3125,6.01562,6.20312,6.42188,7.51562,8.0,$
      ;                      8.70312,9.89062,10.0156,12.0,12.4844,14.0156,14.5938,15.5938,16.7031,19.5156]
      total_elevangle=17 ;Making it the same number of elevation angles as for the grid since there shouldn't be any elevation angles > 17
      max_timedimids_MS=max(count_timedimids_MS)  
      max_timedimids_NS=max(count_timedimids_NS)
      ;To set the number of elements in each array (for each named dimension):
      total_xydim=4 
      total_hidim=15
      total_nPSDlo=2
      total_nBnPSDlo=9
      total_nKuKa=2
      total_nPhsBnN=5
      total_len_atime_ID=19
      total_len_site_ID=10

      ;To create the arrays and set "no values" equal to -999
      mvi=-999 ;Integer
      mvf=-999.0 ;Float
      mvd=-999D ;Double
      ;And creating the LARGE arrays that include all radars for one orbit:
      ;Other variables:
      large_timeNearestApproach=dblarr(nr_files) & large_timeNearestApproach[*]=mvd
      large_atimeNearestApproach=intarr(nr_files,total_len_atime_ID) & large_atimeNearestApproach[*]=mvi
      large_timeSweepStart=dblarr(nr_files, total_elevangle) & large_timeSweepStart[*]=mvd
      large_atimeSweepStart=intarr(nr_files, total_len_atime_ID, total_elevangle) & large_atimeSweepStart[*]=mvi
      large_site_ID=bytarr(nr_files,total_len_site_ID) ;We may not need this
      large_site_lat=fltarr(nr_files) & large_site_lat[*]=mvf
      large_site_lon=fltarr(nr_files) & large_site_lon[*]=mvf
      large_site_elev=fltarr(nr_files) & large_site_elev[*]=mvf
      large_version=strarr(nr_files)
      large_elevationAngle=fltarr(nr_files,total_elevangle) & large_elevationAngle[*,*]=mvf
      large_rangeThreshold=fltarr(nr_files) & large_rangeThreshold[*]=mvf
      large_DPR_dBZ_min=fltarr(nr_files) & large_DPR_dBZ_min[*]=mvf
      large_GR_dBZ_min=fltarr(nr_files) & large_GR_dBZ_min[*]=mvf
      large_rain_min=fltarr(nr_files) & large_rain_min[*]=mvf
      ;Note: We are NOT including the "have_" variables, since these variables $
      ;are no longer applicable for the CONUS grid

      ;For the MS (matched scan) swaths:
      large_Year_MS=intarr(max_timedimids_MS, nr_files) & large_Year_MS[*,*]=mvi 
      large_Month_MS=intarr(max_timedimids_MS, nr_files) & large_Month_MS[*,*]=mvi
      large_DayOfMonth_MS=intarr(max_timedimids_MS, nr_files) & large_DayOfMonth_MS[*,*]=mvi
      large_Hour_MS=intarr(max_timedimids_MS, nr_files) & large_Hour_MS[*,*]=mvi
      large_Minute_MS=intarr(max_timedimids_MS, nr_files) & large_Minute_MS[*,*]=mvi
      large_Second_MS=intarr(max_timedimids_MS, nr_files) & large_Second_MS[*,*]=mvi
      large_Millisecond_MS=intarr(max_timedimids_MS, nr_files) & large_Millisecond_MS[*,*]=mvi
      large_startScan_MS=lonarr(nr_files) & large_startScan_MS[*]=mvi
      large_endScan_MS=lonarr(nr_files) & large_endScan_MS[*]=mvi
      large_numRays_MS=intarr(nr_files) & large_numRays_MS[*]=mvi
      large_latitude_MS=fltarr(total_fpdim_MS, total_elevangle) & large_latitude_MS[*,*]=mvf
      large_longitude_MS=fltarr(total_fpdim_MS, total_elevangle) & large_longitude_MS[*,*]=mvf
      large_xCorners_MS=fltarr(total_xydim, total_fpdim_MS, total_elevangle) & large_xCorners_MS[*,*,*]=mvf
      large_yCorners_MS=fltarr(total_xydim, total_fpdim_MS, total_elevangle) & large_yCorners_MS[*,*,*]=mvf
      large_topHeight_MS=fltarr(total_fpdim_MS, total_elevangle) & large_topHeight_MS[*,*]=mvf
      large_bottomHeight_MS=fltarr(total_fpdim_MS, total_elevangle) & large_bottomHeight_MS[*,*]=mvf
      large_topHeight_MS_MSL=fltarr(total_fpdim_MS, total_elevangle) & large_topHeight_MS_MSL[*,*]=mvf
      large_bottomHeight_MS_MSL=fltarr(total_fpdim_MS, total_elevangle) & large_bottomHeight_MS_MSL[*,*]=mvf
      large_GR_Z_MS=fltarr(total_fpdim_MS, total_elevangle) & large_GR_Z_MS[*,*]=mvf
      large_GR_Z_StdDev_MS=fltarr(total_fpdim_MS, total_elevangle) & large_GR_Z_StdDev_MS[*,*]=mvf
      large_GR_Z_Max_MS=fltarr(total_fpdim_MS, total_elevangle) & large_GR_Z_Max_MS[*,*]=mvf
      large_GR_Zdr_MS=fltarr(total_fpdim_MS, total_elevangle) & large_GR_Zdr_MS[*,*]=mvf
      large_GR_Zdr_StdDev_MS=fltarr(total_fpdim_MS, total_elevangle) & large_GR_Zdr_StdDev_MS[*,*]=mvf
      large_GR_Zdr_Max_MS=fltarr(total_fpdim_MS, total_elevangle) & large_GR_Zdr_Max_MS[*,*]=mvf
      large_GR_Kdp_MS=fltarr(total_fpdim_MS, total_elevangle) & large_GR_Kdp_MS[*,*]=mvf
      large_GR_Kdp_StdDev_MS=fltarr(total_fpdim_MS, total_elevangle) & large_GR_Kdp_StdDev_MS[*,*]=mvf
      large_GR_Kdp_Max_MS=fltarr(total_fpdim_MS, total_elevangle) & large_GR_Kdp_Max_MS[*,*]=mvf
      large_GR_RHOhv_MS=fltarr(total_fpdim_MS, total_elevangle) & large_GR_RHOhv_MS[*,*]=mvf
      large_GR_RHOhv_StdDev_MS=fltarr(total_fpdim_MS, total_elevangle) & large_GR_RHOhv_StdDev_MS[*,*]=mvf
      large_GR_RHOhv_Max_MS=fltarr(total_fpdim_MS, total_elevangle) & large_GR_RHOhv_Max_MS[*,*]=mvf
      large_GR_RC_rainrate_MS=fltarr(total_fpdim_MS, total_elevangle) & large_GR_RC_rainrate_MS[*,*]=mvf
      large_GR_RC_rainrate_StdDev_MS=fltarr(total_fpdim_MS, total_elevangle) & large_GR_RC_rainrate_StdDev_MS[*,*]=mvf
      large_GR_RC_rainrate_Max_MS=fltarr(total_fpdim_MS, total_elevangle) & large_GR_RC_rainrate_Max_MS[*,*]=mvf
      large_GR_RP_rainrate_MS=fltarr(total_fpdim_MS, total_elevangle) & large_GR_RP_rainrate_MS[*,*]=mvf
      large_GR_RP_rainrate_StdDev_MS=fltarr(total_fpdim_MS, total_elevangle) & large_GR_RP_rainrate_StdDev_MS[*,*]=mvf
      large_GR_RP_rainrate_Max_MS=fltarr(total_fpdim_MS, total_elevangle) & large_GR_RP_rainrate_Max_MS[*,*]=mvf
      large_GR_RR_rainrate_MS=fltarr(total_fpdim_MS, total_elevangle) & large_GR_RR_rainrate_MS[*,*]=mvf
      large_GR_RR_rainrate_StdDev_MS=fltarr(total_fpdim_MS, total_elevangle) & large_GR_RR_rainrate_StdDev_MS[*,*]=mvf
      large_GR_RR_rainrate_Max_MS=fltarr(total_fpdim_MS, total_elevangle) & large_GR_RR_rainrate_Max_MS[*,*]=mvf
      large_GR_HID_MS=intarr(total_hidim, total_fpdim_MS, total_elevangle) & large_GR_HID_MS[*,*,*]=mvi
      large_GR_Dzero_MS=fltarr(total_fpdim_MS, total_elevangle) & large_GR_Dzero_MS[*,*]=mvf
      large_GR_Dzero_StdDev_MS=fltarr(total_fpdim_MS, total_elevangle) & large_GR_Dzero_StdDev_MS[*,*]=mvf
      large_GR_Dzero_Max_MS=fltarr(total_fpdim_MS, total_elevangle) & large_GR_Dzero_Max_MS[*,*]=mvf
      large_GR_Nw_MS=fltarr(total_fpdim_MS, total_elevangle) & large_GR_Nw_MS[*,*]=mvf
      large_GR_Nw_StdDev_MS=fltarr(total_fpdim_MS, total_elevangle) & large_GR_Nw_StdDev_MS[*,*]=mvf
      large_GR_Nw_Max_MS=fltarr(total_fpdim_MS, total_elevangle) & large_GR_Nw_Max_MS[*,*]=mvf
      large_GR_Dm_MS=fltarr(total_fpdim_MS, total_elevangle) & large_GR_Dm_MS[*,*]=mvf
      large_GR_Dm_StdDev_MS=fltarr(total_fpdim_MS, total_elevangle) & large_GR_Dm_StdDev_MS[*,*]=mvf
      large_GR_Dm_Max_MS=fltarr(total_fpdim_MS, total_elevangle) & large_GR_Dm_Max_MS[*,*]=mvf
      large_GR_N2_MS=fltarr(total_fpdim_MS, total_elevangle) & large_GR_N2_MS[*,*]=mvf
      large_GR_N2_StdDev_MS=fltarr(total_fpdim_MS, total_elevangle) & large_GR_N2_StdDev_MS[*,*]=mvf
      large_GR_N2_Max_MS=fltarr(total_fpdim_MS, total_elevangle) & large_GR_N2_Max_MS[*,*]=mvf
      large_GR_blockage_MS=fltarr(total_fpdim_MS, total_elevangle) & large_GR_blockage_MS[*,*]=mvf
      large_n_gr_z_rejected_MS=intarr(total_fpdim_MS, total_elevangle) & large_n_gr_z_rejected_MS[*,*]=mvi
      large_n_gr_zdr_rejected_MS=intarr(total_fpdim_MS, total_elevangle) & large_n_gr_zdr_rejected_MS[*,*]=mvi
      large_n_gr_kdp_rejected_MS=intarr(total_fpdim_MS, total_elevangle) & large_n_gr_kdp_rejected_MS[*,*]=mvi
      large_n_gr_rhohv_rejected_MS=intarr(total_fpdim_MS, total_elevangle) & large_n_gr_rhohv_rejected_MS[*,*]=mvi
      large_n_gr_rc_rejected_MS=intarr(total_fpdim_MS, total_elevangle) & large_n_gr_rc_rejected_MS[*,*]=mvi
      large_n_gr_rp_rejected_MS=intarr(total_fpdim_MS, total_elevangle) & large_n_gr_rp_rejected_MS[*,*]=mvi
      large_n_gr_rr_rejected_MS=intarr(total_fpdim_MS, total_elevangle) & large_n_gr_rr_rejected_MS[*,*]=mvi
      large_n_gr_hid_rejected_MS=intarr(total_fpdim_MS, total_elevangle) & large_n_gr_hid_rejected_MS[*,*]=mvi
      large_n_gr_dzero_rejected_MS=intarr(total_fpdim_MS, total_elevangle) & large_n_gr_dzero_rejected_MS[*,*]=mvi
      large_n_gr_nw_rejected_MS=intarr(total_fpdim_MS, total_elevangle) & large_n_gr_nw_rejected_MS[*,*]=mvi
      large_n_gr_dm_rejected_MS=intarr(total_fpdim_MS, total_fpdim_NS, total_elevangle) & large_n_gr_dm_rejected_MS[*,*,*]=mvi
      large_n_gr_n2_rejected_MS=intarr(total_fpdim_MS, total_fpdim_NS, total_elevangle) & large_n_gr_n2_rejected_MS[*,*,*]=mvi
      large_n_gr_expected_MS=intarr(total_fpdim_MS, total_elevangle) & large_n_gr_expected_MS[*,*]=mvi
      large_precipTotPSDparamHigh_MS=fltarr(total_fpdim_MS, total_elevangle) & large_precipTotPSDparamHigh_MS[*,*]=mvf
      large_precipTotPSDparamLow_MS=fltarr(total_nPSDlo, total_fpdim_MS, total_elevangle) 
 			            large_precipTotPSDparamLow_MS[*,*,*]=mvf
      large_precipTotRate_MS=fltarr(total_fpdim_MS, total_elevangle) & large_precipTotRate_MS[*,*]=mvf
      large_precipTotWaterCont_MS=fltarr(total_fpdim_MS, total_elevangle) & large_precipTotWaterCont_MS[*,*]=mvf
      large_n_precipTotPSDparamHigh_rejected_MS=intarr(total_fpdim_MS, total_elevangle)
                                                large_n_precipTotPSDparamHigh_rejected_MS[*,*]=mvi
      large_n_precipTotPSDparamLow_rejected_MS=intarr(total_nPSDlo, total_fpdim_MS, total_elevangle)
                                               large_n_precipTotPSDparamLow_rejected_MS[*,*,*]=mvi
      large_n_precipTotRate_rejected_MS=intarr(total_fpdim_MS, total_elevangle)
                                        large_n_precipTotRate_rejected_MS[*,*]=mvi
      large_n_precipTotWaterCont_rejected_MS=intarr(total_fpdim_MS, total_elevangle)
                                             large_n_precipTotWaterCont_rejected_MS[*,*]=mvi
      large_precipitationType_MS=lonarr(total_fpdim_MS) & large_precipitationType_MS[*]=mvi
      large_surfPrecipTotRate_MS=fltarr(total_fpdim_MS) & large_surfPrecipTotRate_MS[*]=mvf
      large_surfaceElevation_MS=fltarr(total_fpdim_MS) & large_surfaceElevation_MS[*]=mvf
      large_zeroDegAltitude_MS=fltarr(total_fpdim_MS) & large_zeroDegAltitude_MS[*]=mvf
      large_zeroDegBin_MS=intarr(total_fpdim_MS) & large_zeroDegBin_MS[*]=mvi
      large_surfaceType_MS=lonarr(total_fpdim_MS) & large_surfaceType_MS[*]=mvi
      large_phaseBinNodes_MS=intarr(total_nPhsBnN, total_fpdim_MS) & large_phaseBinNodes_MS[*,*]=mvi
      large_DPRlatitude_MS=fltarr(total_fpdim_MS) & large_DPRlatitude_MS[*]=mvf
      large_DPRlongitude_MS=fltarr(total_fpdim_MS) & large_DPRlongitude_MS[*]=mvf
      large_scanNum_MS=intarr(total_fpdim_MS) & large_scanNum_MS[*]=mvi
      large_rayNum_MS=intarr(total_fpdim_MS) & large_rayNum_MS[*]=mvi
      large_ellipsoidBinOffset_MS=fltarr(total_nKuKa, total_fpdim_MS) & large_ellipsoidBinOffset_MS[*,*]=mvf
      large_lowestClutterFreeBin_MS=intarr(total_nKuKa, total_fpdim_MS) & large_lowestClutterFreeBin_MS[*,*]=mvi
      large_clutterStatus_MS=intarr(total_nKuKa, total_fpdim_MS, total_elevangle) & large_clutterStatus_MS[*,*,*]=mvi
      large_precipitationFlag_MS=lonarr(total_nKuKa, total_fpdim_MS) & large_precipitationFlag_MS[*,*]=mvi
      large_surfaceRangeBin_MS=intarr(total_nKuKa, total_fpdim_MS) & large_surfaceRangeBin_MS[*,*]=mvi
      large_correctedReflectFactor_MS=fltarr(total_nKuKa, total_fpdim_MS, total_elevangle)
                                      large_correctedReflectFactor_MS[*,*,*]=mvf
      large_pia_MS=fltarr(total_nKuKa, total_fpdim_MS) & large_pia_MS[*,*]=mvf
      large_stormTopAltitude_MS=fltarr(total_nKuKa, total_fpdim_MS) & large_stormTopAltitude_MS[*,*]=mvf
      large_n_correctedReflectFactor_rejected_MS=intarr(total_nKuKa, total_fpdim_MS, total_elevangle) 
 	 				         large_n_correctedReflectFactor_rejected_MS[*,*,*]=mvi
      large_n_dpr_expected_MS=intarr(total_nKuKa, total_fpdim_MS, total_elevangle) & large_n_dpr_expected_MS[*,*,*]=mvi

      ;Now for the NS (normal scan) swaths:
      large_Year_NS=intarr(max_timedimids_NS, nr_files) & large_Year_NS[*,*]=mvi
      large_Month_NS=intarr(max_timedimids_NS, nr_files) & large_Month_NS[*,*]=mvi
      large_DayOfMonth_NS=intarr(max_timedimids_NS, nr_files) & large_DayOfMonth_NS[*,*]=mvi
      large_Hour_NS=intarr(max_timedimids_NS, nr_files) & large_Hour_NS[*,*]=mvi
      large_Minute_NS=intarr(max_timedimids_NS, nr_files) & large_Minute_NS[*,*]=mvi
      large_Second_NS=intarr(max_timedimids_NS, nr_files) & large_Second_NS[*,*]=mvi
      large_Millisecond_NS=intarr(max_timedimids_NS, nr_files) & large_Millisecond_NS[*,*]=mvi
      large_startScan_NS=lonarr(nr_files) & large_startScan_NS[*]=mvi
      large_endScan_NS=lonarr(nr_files) & large_endScan_NS[*]=mvi
      large_numRays_NS=intarr(nr_files) & large_numRays_NS[*]=mvi
      large_latitude_NS=fltarr(total_fpdim_NS, total_elevangle) & large_latitude_NS[*,*]=mvf
      large_longitude_NS=fltarr(total_fpdim_NS, total_elevangle) & large_longitude_NS[*,*]=mvf
      large_xCorners_NS=fltarr(total_xydim, total_fpdim_NS, total_elevangle) & large_xCorners_NS[*,*,*]=mvf
      large_yCorners_NS=fltarr(total_xydim, total_fpdim_NS, total_elevangle) & large_yCorners_NS[*,*,*]=mvf
      large_topHeight_NS=fltarr(total_fpdim_NS, total_elevangle) & large_topHeight_NS[*,*]=mvf
      large_bottomHeight_NS=fltarr(total_fpdim_NS, total_elevangle) & large_bottomHeight_NS[*,*]=mvf
      large_topHeight_NS_MSL=fltarr(total_fpdim_NS, total_elevangle) & large_topHeight_NS_MSL[*,*]=mvf
      large_bottomHeight_NS_MSL=fltarr(total_fpdim_NS, total_elevangle) & large_bottomHeight_NS_MSL[*,*]=mvf
      large_GR_Z_NS=fltarr(total_fpdim_NS, total_elevangle) & large_GR_Z_NS[*,*]=mvf
      large_GR_Z_StdDev_NS=fltarr(total_fpdim_NS, total_elevangle) & large_GR_Z_StdDev_NS[*,*]=mvf
      large_GR_Z_Max_NS=fltarr(total_fpdim_NS, total_elevangle) & large_GR_Z_Max_NS[*,*]=mvf
      large_GR_Zdr_NS=fltarr(total_fpdim_NS, total_elevangle) & large_GR_Zdr_NS[*,*]=mvf
      large_GR_Zdr_StdDev_NS=fltarr(total_fpdim_NS, total_elevangle) & large_GR_Zdr_StdDev_NS[*,*]=mvf
      large_GR_Zdr_Max_NS=fltarr(total_fpdim_NS, total_elevangle) & large_GR_Zdr_Max_NS[*,*]=mvf
      large_GR_Kdp_NS=fltarr(total_fpdim_NS, total_elevangle) & large_GR_Kdp_NS[*,*]=mvf
      large_GR_Kdp_StdDev_NS=fltarr(total_fpdim_NS, total_elevangle) & large_GR_Kdp_StdDev_NS[*,*]=mvf
      large_GR_Kdp_Max_NS=fltarr(total_fpdim_NS, total_elevangle) & large_GR_Kdp_Max_NS[*,*]=mvf
      large_GR_RHOhv_NS=fltarr(total_fpdim_NS, total_elevangle) & large_GR_RHOhv_NS[*,*]=mvf
      large_GR_RHOhv_StdDev_NS=fltarr(total_fpdim_NS, total_elevangle) & large_GR_RHOhv_StdDev_NS[*,*]=mvf
      large_GR_RHOhv_Max_NS=fltarr(total_fpdim_NS, total_elevangle) & large_GR_RHOhv_Max_NS[*,*]=mvf
      large_GR_RC_rainrate_NS=fltarr(total_fpdim_NS, total_elevangle) & large_GR_RC_rainrate_NS[*,*]=mvf
      large_GR_RC_rainrate_StdDev_NS=fltarr(total_fpdim_NS, total_elevangle) & large_GR_RC_rainrate_StdDev_NS[*,*]=mvf
      large_GR_RC_rainrate_Max_NS=fltarr(total_fpdim_NS, total_elevangle) & large_GR_RC_rainrate_Max_NS[*,*]=mvf
      large_GR_RP_rainrate_NS=fltarr(total_fpdim_NS, total_elevangle) & large_GR_RP_rainrate_NS[*,*]=mvf
      large_GR_RP_rainrate_StdDev_NS=fltarr(total_fpdim_NS, total_elevangle) & large_GR_RP_rainrate_StdDev_NS[*,*]=mvf
      large_GR_RP_rainrate_Max_NS=fltarr(total_fpdim_NS, total_elevangle) & large_GR_RP_rainrate_Max_NS[*,*]=mvf
      large_GR_RR_rainrate_NS=fltarr(total_fpdim_NS, total_elevangle) & large_GR_RR_rainrate_NS[*,*]=mvf
      large_GR_RR_rainrate_StdDev_NS=fltarr(total_fpdim_NS, total_elevangle) & large_GR_RR_rainrate_StdDev_NS[*,*]=mvf
      large_GR_RR_rainrate_Max_NS=fltarr(total_fpdim_NS, total_elevangle) & large_GR_RR_rainrate_Max_NS[*,*]=mvf
      large_GR_HID_NS=intarr(total_hidim, total_fpdim_NS, total_elevangle) & large_GR_HID_NS[*,*,*]=mvi
      large_GR_Dzero_NS=fltarr(total_fpdim_NS, total_elevangle) & large_GR_Dzero_NS[*,*]=mvf
      large_GR_Dzero_StdDev_NS=fltarr(total_fpdim_NS, total_elevangle) & large_GR_Dzero_StdDev_NS[*,*]=mvf
      large_GR_Dzero_Max_NS=fltarr(total_fpdim_NS, total_elevangle) & large_GR_Dzero_Max_NS[*,*]=mvf
      large_GR_Nw_NS=fltarr(total_fpdim_NS, total_elevangle) & large_GR_Nw_NS[*,*]=mvf
      large_GR_Nw_StdDev_NS=fltarr(total_fpdim_NS, total_elevangle) & large_GR_Nw_StdDev_NS[*,*]=mvf
      large_GR_Nw_Max_NS=fltarr(total_fpdim_NS, total_elevangle) & large_GR_Nw_Max_NS[*,*]=mvf
      large_GR_Dm_NS=fltarr(total_fpdim_NS, total_elevangle) & large_GR_Dm_NS[*,*]=mvf
      large_GR_Dm_StdDev_NS=fltarr(total_fpdim_NS, total_elevangle) & large_GR_Dm_StdDev_NS[*,*]=mvf
      large_GR_Dm_Max_NS=fltarr(total_fpdim_NS, total_elevangle) & large_GR_Dm_Max_NS[*,*]=mvf
      large_GR_N2_NS=fltarr(total_fpdim_NS, total_elevangle) & large_GR_N2_NS[*,*]=mvf
      large_GR_N2_StdDev_NS=fltarr(total_fpdim_NS, total_elevangle) & large_GR_N2_StdDev_NS[*,*]=mvf
      large_GR_N2_Max_NS=fltarr(total_fpdim_NS, total_elevangle) & large_GR_N2_Max_NS[*,*]=mvf
      large_GR_blockage_NS=fltarr(total_fpdim_NS, total_elevangle) & large_GR_blockage_NS[*,*]=mvf
      large_n_gr_z_rejected_NS=intarr(total_fpdim_NS, total_elevangle) & large_n_gr_z_rejected_NS[*,*]=mvi
      large_n_gr_zdr_rejected_NS=intarr(total_fpdim_NS, total_elevangle) & large_n_gr_zdr_rejected_NS[*,*]=mvi
      large_n_gr_kdp_rejected_NS=intarr(total_fpdim_NS, total_elevangle) & large_n_gr_kdp_rejected_NS[*,*]=mvi
      large_n_gr_rhohv_rejected_NS=intarr(total_fpdim_NS, total_elevangle) & large_n_gr_rhohv_rejected_NS[*,*]=mvi
      large_n_gr_rc_rejected_NS=intarr(total_fpdim_NS, total_elevangle) & large_n_gr_rc_rejected_NS[*,*]=mvi
      large_n_gr_rp_rejected_NS=intarr(total_fpdim_NS, total_elevangle) & large_n_gr_rp_rejected_NS[*,*]=mvi
      large_n_gr_rr_rejected_NS=intarr(total_fpdim_NS, total_elevangle) & large_n_gr_rr_rejected_NS[*,*]=mvi
      large_n_gr_hid_rejected_NS=intarr(total_fpdim_NS, total_elevangle) & large_n_gr_hid_rejected_NS[*,*]=mvi
      large_n_gr_dzero_rejected_NS=intarr(total_fpdim_NS, total_elevangle) & large_n_gr_dzero_rejected_NS[*,*]=mvi
      large_n_gr_nw_rejected_NS=intarr(total_fpdim_NS, total_elevangle) & large_n_gr_nw_rejected_NS[*,*]=mvi
      large_n_gr_dm_rejected_NS=intarr(total_fpdim_MS, total_fpdim_NS, total_elevangle) & large_n_gr_dm_rejected_NS[*,*,*]=mvi
      large_n_gr_n2_rejected_NS=intarr(total_fpdim_MS, total_fpdim_NS, total_elevangle) & large_n_gr_n2_rejected_NS[*,*,*]=mvi
      large_n_gr_expected_NS=intarr(total_fpdim_NS, total_elevangle) & large_n_gr_expected_NS[*,*]=mvi
      large_precipTotPSDparamHigh_NS=fltarr(total_fpdim_NS, total_elevangle) & large_precipTotPSDparamHigh_NS[*,*]=mvf
      large_precipTotPSDparamLow_NS=fltarr(total_nPSDlo, total_fpdim_NS, total_elevangle)
                                    large_precipTotPSDparamLow_NS[*,*,*]=mvf
      large_precipTotRate_NS=fltarr(total_fpdim_NS, total_elevangle) & large_precipTotRate_NS[*,*]=mvf
      large_precipTotWaterCont_NS=fltarr(total_fpdim_NS, total_elevangle) & large_precipTotWaterCont_NS[*,*]=mvf
      large_n_precipTotPSDparamHigh_rejected_NS=intarr(total_fpdim_NS, total_elevangle)
                                                large_n_precipTotPSDparamHigh_rejected_NS[*,*]=mvi
      large_n_precipTotPSDparamLow_rejected_NS=intarr(total_nPSDlo, total_fpdim_NS, total_elevangle)
                                               large_n_precipTotPSDparamLow_rejected_NS[*,*,*]=mvi
      large_n_precipTotRate_rejected_NS=intarr(total_fpdim_NS, total_elevangle)
                                        large_n_precipTotRate_rejected_NS[*,*]=mvi
      large_n_precipTotWaterCont_rejected_NS=intarr(total_fpdim_NS, total_elevangle)
                                             large_n_precipTotWaterCont_rejected_NS[*,*]=mvi
      large_precipitationType_NS=lonarr(total_fpdim_NS) & large_precipitationType_NS[*]=mvi
      large_surfPrecipTotRate_NS=fltarr(total_fpdim_NS) & large_surfPrecipTotRate_NS[*]=mvf
      large_surfaceElevation_NS=fltarr(total_fpdim_NS) & large_surfaceElevation_NS[*]=mvf
      large_zeroDegAltitude_NS=fltarr(total_fpdim_NS) & large_zeroDegAltitude_NS[*]=mvf
      large_zeroDegBin_NS=intarr(total_fpdim_NS) & large_zeroDegBin_NS[*]=mvi
      large_surfaceType_NS=lonarr(total_fpdim_NS) & large_surfaceType_NS[*]=mvi
      large_phaseBinNodes_NS=intarr(total_nPhsBnN, total_fpdim_NS) & large_phaseBinNodes_NS[*,*]=mvi
      large_DPRlatitude_NS=fltarr(total_fpdim_NS) & large_DPRlatitude_NS[*]=mvf
      large_DPRlongitude_NS=fltarr(total_fpdim_NS) & large_DPRlongitude_NS[*]=mvf
      large_scanNum_NS=intarr(total_fpdim_NS) & large_scanNum_NS[*]=mvi
      large_rayNum_NS=intarr(total_fpdim_NS) & large_rayNum_NS[*]=mvi
      large_ellipsoidBinOffset_NS=fltarr(total_fpdim_NS) & large_ellipsoidBinOffset_NS[*]=mvf
      large_lowestClutterFreeBin_NS=intarr(total_fpdim_NS) & large_lowestClutterFreeBin_NS[*]=mvi
      large_clutterStatus_NS=intarr(total_fpdim_NS, total_elevangle) & large_clutterStatus_NS[*,*]=mvi
      large_precipitationFlag_NS=lonarr(total_fpdim_NS) & large_precipitationFlag_NS[*]=mvi
      large_surfaceRangeBin_NS=intarr(total_fpdim_NS) & large_surfaceRangeBin_NS[*]=mvi
      large_correctedReflectFactor_NS=fltarr(total_fpdim_NS, total_elevangle) 
                                      large_correctedReflectFactor_NS[*,*]=mvf
      large_pia_NS=fltarr(total_fpdim_NS) & large_pia_NS[*]=mvf
      large_stormTopAltitude_NS=fltarr(total_fpdim_NS) & large_stormTopAltitude_NS[*]=mvf
      large_n_correctedReflectFactor_rejected_NS=intarr(total_fpdim_NS, total_elevangle)
                                                 large_n_correctedReflectFactor_rejected_NS[*,*]=mvi
      large_n_dpr_expected_NS=intarr(total_fpdim_NS, total_elevangle) & large_n_dpr_expected_NS[*,*]=mvi

      ;Counter for the large matched file:
      counter_MS=0 ;This is the counter for the LARGE file for MS
      counter_NS=0 ;This is the counter for the LARGE file for NS

      for ff=0,  n_elements(inlist_new)-1 do begin

        ;This is where there the data is actually read in!
        ncid=ncdf_open(indir+'/'+strcompress(year[aa])+'/'+new_filename[ff])

        ;For "Other variables":
	ncdf_varget, ncid, 'timeNearestApproach', timeNearestApproach
        ncdf_varget, ncid, 'atimeNearestApproach', atimeNearestApproach
        ncdf_varget, ncid, 'timeSweepStart', timeSweepStart
        ncdf_varget, ncid, 'atimeSweepStart', atimeSweepStart
        ncdf_varget, ncid, 'site_ID', site_ID
        ncdf_varget, ncid, 'site_lat', site_lat
        ncdf_varget, ncid, 'site_lon', site_lon
        ncdf_varget, ncid, 'site_elev', site_elev
        ncdf_varget, ncid, 'version', version
	ncdf_varget, ncid, 'elevationAngle', elevationAngle
        ncdf_varget, ncid, 'rangeThreshold', rangeThreshold
        ncdf_varget, ncid, 'DPR_dBZ_min', DPR_dBZ_min
        ncdf_varget, ncid, 'GR_dBZ_min', GR_dBZ_min
        ncdf_varget, ncid, 'rain_min', rain_min

        ;For the MS (matched scan) swaths:
        ncdf_varget, ncid, 'Year_MS', Year_MS
        ncdf_varget, ncid, 'Month_MS', Month_MS
        ncdf_varget, ncid, 'DayOfMonth_MS', DayOfMonth_MS
        ncdf_varget, ncid, 'Hour_MS', Hour_MS
        ncdf_varget, ncid, 'Minute_MS', Minute_MS
        ncdf_varget, ncid, 'Second_MS', Second_MS
        ncdf_varget, ncid, 'Millisecond_MS', Millisecond_MS
        ncdf_varget, ncid, 'startScan_MS', startScan_MS
        ncdf_varget, ncid, 'endScan_MS', endScan_MS
        ncdf_varget, ncid, 'numRays_MS', numRays_MS
        ncdf_varget, ncid, 'latitude_MS', latitude_MS
        ncdf_varget, ncid, 'longitude_MS', longitude_MS
        ncdf_varget, ncid, 'xCorners_MS', xCorners_MS
        ncdf_varget, ncid, 'yCorners_MS', yCorners_MS
        ncdf_varget, ncid, 'topHeight_MS', topHeight_MS
        ncdf_varget, ncid, 'bottomHeight_MS', bottomHeight_MS
        ncdf_varget, ncid, 'GR_Z_MS', GR_Z_MS
        ncdf_varget, ncid, 'GR_Z_StdDev_MS', GR_Z_StdDev_MS
        ncdf_varget, ncid, 'GR_Z_Max_MS', GR_Z_Max_MS
        ncdf_varget, ncid, 'GR_Zdr_MS', GR_Zdr_MS
        ncdf_varget, ncid, 'GR_Zdr_StdDev_MS', GR_Zdr_StdDev_MS
        ncdf_varget, ncid, 'GR_Zdr_Max_MS', GR_Zdr_Max_MS
        ncdf_varget, ncid, 'GR_Kdp_MS', GR_Kdp_MS
        ncdf_varget, ncid, 'GR_Kdp_StdDev_MS', GR_Kdp_StdDev_MS
        ncdf_varget, ncid, 'GR_Kdp_Max_MS', GR_Kdp_Max_MS
        ncdf_varget, ncid, 'GR_RHOhv_MS', GR_RHOhv_MS
        ncdf_varget, ncid, 'GR_RHOhv_StdDev_MS', GR_RHOhv_StdDev_MS
        ncdf_varget, ncid, 'GR_RHOhv_Max_MS', GR_RHOhv_Max_MS
        ncdf_varget, ncid, 'GR_RC_rainrate_MS', GR_RC_rainrate_MS
        ncdf_varget, ncid, 'GR_RC_rainrate_StdDev_MS', GR_RC_rainrate_StdDev_MS
        ncdf_varget, ncid, 'GR_RC_rainrate_Max_MS', GR_RC_rainrate_Max_MS
        ncdf_varget, ncid, 'GR_RP_rainrate_MS', GR_RP_rainrate_MS
        ncdf_varget, ncid, 'GR_RP_rainrate_StdDev_MS', GR_RP_rainrate_StdDev_MS
        ncdf_varget, ncid, 'GR_RP_rainrate_Max_MS', GR_RP_rainrate_Max_MS
        ncdf_varget, ncid, 'GR_RR_rainrate_MS', GR_RR_rainrate_MS
        ncdf_varget, ncid, 'GR_RR_rainrate_StdDev_MS', GR_RR_rainrate_StdDev_MS
        ncdf_varget, ncid, 'GR_RR_rainrate_Max_MS', GR_RR_rainrate_Max_MS
        ncdf_varget, ncid, 'GR_HID_MS', GR_HID_MS
        ncdf_varget, ncid, 'GR_Dzero_MS', GR_Dzero_MS
        ncdf_varget, ncid, 'GR_Dzero_StdDev_MS', GR_Dzero_StdDev_MS
        ncdf_varget, ncid, 'GR_Dzero_Max_MS', GR_Dzero_Max_MS
        ncdf_varget, ncid, 'GR_Nw_MS', GR_Nw_MS
        ncdf_varget, ncid, 'GR_Nw_StdDev_MS', GR_Nw_StdDev_MS
        ncdf_varget, ncid, 'GR_Nw_Max_MS', GR_Nw_Max_MS
        ncdf_varget, ncid, 'GR_Dm_MS', GR_Dm_MS
        ncdf_varget, ncid, 'GR_Dm_StdDev_MS', GR_Dm_StdDev_MS
        ncdf_varget, ncid, 'GR_Dm_Max_MS', GR_Dm_Max_MS
        ncdf_varget, ncid, 'GR_N2_MS', GR_N2_MS
        ncdf_varget, ncid, 'GR_N2_StdDev_MS', GR_N2_StdDev_MS
        ncdf_varget, ncid, 'GR_N2_Max_MS', GR_N2_Max_MS
        ncdf_varget, ncid, 'GR_blockage_MS', GR_blockage_MS
        ncdf_varget, ncid, 'n_gr_z_rejected_MS', n_gr_z_rejected_MS
        ncdf_varget, ncid, 'n_gr_zdr_rejected_MS', n_gr_zdr_rejected_MS
        ncdf_varget, ncid, 'n_gr_kdp_rejected_MS', n_gr_kdp_rejected_MS
        ncdf_varget, ncid, 'n_gr_rhohv_rejected_MS', n_gr_rhohv_rejected_MS
        ncdf_varget, ncid, 'n_gr_rc_rejected_MS', n_gr_rc_rejected_MS
        ncdf_varget, ncid, 'n_gr_rp_rejected_MS', n_gr_rp_rejected_MS
        ncdf_varget, ncid, 'n_gr_rr_rejected_MS', n_gr_rr_rejected_MS
        ncdf_varget, ncid, 'n_gr_hid_rejected_MS', n_gr_hid_rejected_MS
        ncdf_varget, ncid, 'n_gr_dzero_rejected_MS', n_gr_dzero_rejected_MS
        ncdf_varget, ncid, 'n_gr_nw_rejected_MS', n_gr_nw_rejected_MS
        ncdf_varget, ncid, 'n_gr_dm_rejected_MS', n_gr_dm_rejected_MS
        ncdf_varget, ncid, 'n_gr_n2_rejected_MS', n_gr_n2_rejected_MS
        ncdf_varget, ncid, 'n_gr_expected_MS', n_gr_expected_MS
        ncdf_varget, ncid, 'precipTotPSDparamHigh_MS', precipTotPSDparamHigh_MS
        ncdf_varget, ncid, 'precipTotPSDparamLow_MS', precipTotPSDparamLow_MS
        ncdf_varget, ncid, 'precipTotRate_MS', precipTotRate_MS
        ncdf_varget, ncid, 'precipTotWaterCont_MS', precipTotWaterCont_MS
        ncdf_varget, ncid, 'n_precipTotPSDparamHigh_rejected_MS', n_precipTotPSDparamHigh_rejected_MS
        ncdf_varget, ncid, 'n_precipTotPSDparamLow_rejected_MS', n_precipTotPSDparamLow_rejected_MS
        ncdf_varget, ncid, 'n_precipTotRate_rejected_MS', n_precipTotRate_rejected_MS
        ncdf_varget, ncid, 'n_precipTotWaterCont_rejected_MS', n_precipTotWaterCont_rejected_MS
        ncdf_varget, ncid, 'precipitationType_MS', precipitationType_MS
        ncdf_varget, ncid, 'surfPrecipTotRate_MS', surfPrecipTotRate_MS
        ncdf_varget, ncid, 'surfaceElevation_MS', surfaceElevation_MS
        ncdf_varget, ncid, 'zeroDegAltitude_MS', zeroDegAltitude_MS
        ncdf_varget, ncid, 'zeroDegBin_MS', zeroDegBin_MS
        ncdf_varget, ncid, 'surfaceType_MS', surfaceType_MS
        ncdf_varget, ncid, 'phaseBinNodes_MS', phaseBinNodes_MS
        ncdf_varget, ncid, 'DPRlatitude_MS', DPRlatitude_MS
        ncdf_varget, ncid, 'DPRlongitude_MS', DPRlongitude_MS
        ncdf_varget, ncid, 'scanNum_MS', scanNum_MS
        ncdf_varget, ncid, 'rayNum_MS', rayNum_MS
        ncdf_varget, ncid, 'ellipsoidBinOffset_MS', ellipsoidBinOffset_MS
        ncdf_varget, ncid, 'lowestClutterFreeBin_MS', lowestClutterFreeBin_MS
        ncdf_varget, ncid, 'clutterStatus_MS', clutterStatus_MS
        ncdf_varget, ncid, 'precipitationFlag_MS', precipitationFlag_MS
        ncdf_varget, ncid, 'surfaceRangeBin_MS', surfaceRangeBin_MS
        ncdf_varget, ncid, 'correctedReflectFactor_MS', correctedReflectFactor_MS
        ncdf_varget, ncid, 'pia_MS', pia_MS
        ncdf_varget, ncid, 'stormTopAltitude_MS', stormTopAltitude_MS
        ncdf_varget, ncid, 'n_correctedReflectFactor_rejected_MS', n_correctedReflectFactor_rejected_MS
        ncdf_varget, ncid, 'n_dpr_expected_MS', n_dpr_expected_MS

        ;Now for the NS (normal scan) swaths:
        ncdf_varget, ncid, 'Year_NS', Year_NS
        ncdf_varget, ncid, 'Month_NS', Month_NS
        ncdf_varget, ncid, 'DayOfMonth_NS', DayOfMonth_NS
        ncdf_varget, ncid, 'Hour_NS', Hour_NS
        ncdf_varget, ncid, 'Minute_NS', Minute_NS
        ncdf_varget, ncid, 'Second_NS', Second_NS
        ncdf_varget, ncid, 'Millisecond_NS', Millisecond_NS
        ncdf_varget, ncid, 'startScan_NS', startScan_NS
        ncdf_varget, ncid, 'endScan_NS', endScan_NS
        ncdf_varget, ncid, 'numRays_NS', numRays_NS
        ncdf_varget, ncid, 'latitude_NS', latitude_NS
        ncdf_varget, ncid, 'longitude_NS', longitude_NS
        ncdf_varget, ncid, 'xCorners_NS', xCorners_NS
        ncdf_varget, ncid, 'yCorners_NS', yCorners_NS
        ncdf_varget, ncid, 'topHeight_NS', topHeight_NS
        ncdf_varget, ncid, 'bottomHeight_NS', bottomHeight_NS
        ncdf_varget, ncid, 'GR_Z_NS', GR_Z_NS
        ncdf_varget, ncid, 'GR_Z_StdDev_NS', GR_Z_StdDev_NS
        ncdf_varget, ncid, 'GR_Z_Max_NS', GR_Z_Max_NS
        ncdf_varget, ncid, 'GR_Zdr_NS', GR_Zdr_NS
        ncdf_varget, ncid, 'GR_Zdr_StdDev_NS', GR_Zdr_StdDev_NS
        ncdf_varget, ncid, 'GR_Zdr_Max_NS', GR_Zdr_Max_NS
        ncdf_varget, ncid, 'GR_Kdp_NS', GR_Kdp_NS
        ncdf_varget, ncid, 'GR_Kdp_StdDev_NS', GR_Kdp_StdDev_NS
        ncdf_varget, ncid, 'GR_Kdp_Max_NS', GR_Kdp_Max_NS
        ncdf_varget, ncid, 'GR_RHOhv_NS', GR_RHOhv_NS
        ncdf_varget, ncid, 'GR_RHOhv_StdDev_NS', GR_RHOhv_StdDev_NS
        ncdf_varget, ncid, 'GR_RHOhv_Max_NS', GR_RHOhv_Max_NS
        ncdf_varget, ncid, 'GR_RC_rainrate_NS', GR_RC_rainrate_NS
        ncdf_varget, ncid, 'GR_RC_rainrate_StdDev_NS', GR_RC_rainrate_StdDev_NS
        ncdf_varget, ncid, 'GR_RC_rainrate_Max_NS', GR_RC_rainrate_Max_NS
        ncdf_varget, ncid, 'GR_RP_rainrate_NS', GR_RP_rainrate_NS
        ncdf_varget, ncid, 'GR_RP_rainrate_StdDev_NS', GR_RP_rainrate_StdDev_NS
        ncdf_varget, ncid, 'GR_RP_rainrate_Max_NS', GR_RP_rainrate_Max_NS
        ncdf_varget, ncid, 'GR_RR_rainrate_NS', GR_RR_rainrate_NS
        ncdf_varget, ncid, 'GR_RR_rainrate_StdDev_NS', GR_RR_rainrate_StdDev_NS
        ncdf_varget, ncid, 'GR_RR_rainrate_Max_NS', GR_RR_rainrate_Max_NS
        ncdf_varget, ncid, 'GR_HID_NS', GR_HID_NS
        ncdf_varget, ncid, 'GR_Dzero_NS', GR_Dzero_NS
        ncdf_varget, ncid, 'GR_Dzero_StdDev_NS', GR_Dzero_StdDev_NS
        ncdf_varget, ncid, 'GR_Dzero_Max_NS', GR_Dzero_Max_NS
        ncdf_varget, ncid, 'GR_Nw_NS', GR_Nw_NS
        ncdf_varget, ncid, 'GR_Nw_StdDev_NS', GR_Nw_StdDev_NS
        ncdf_varget, ncid, 'GR_Nw_Max_NS', GR_Nw_Max_NS
        ncdf_varget, ncid, 'GR_Dm_NS', GR_Dm_NS
        ncdf_varget, ncid, 'GR_Dm_StdDev_NS', GR_Dm_StdDev_NS
        ncdf_varget, ncid, 'GR_Dm_Max_NS', GR_Dm_Max_NS
        ncdf_varget, ncid, 'GR_N2_NS', GR_N2_NS
        ncdf_varget, ncid, 'GR_N2_StdDev_NS', GR_N2_StdDev_NS
        ncdf_varget, ncid, 'GR_N2_Max_NS', GR_N2_Max_NS
        ncdf_varget, ncid, 'GR_blockage_NS', GR_blockage_NS
        ncdf_varget, ncid, 'n_gr_z_rejected_NS', n_gr_z_rejected_NS
        ncdf_varget, ncid, 'n_gr_zdr_rejected_NS', n_gr_zdr_rejected_NS
        ncdf_varget, ncid, 'n_gr_kdp_rejected_NS', n_gr_kdp_rejected_NS
        ncdf_varget, ncid, 'n_gr_rhohv_rejected_NS', n_gr_rhohv_rejected_NS
        ncdf_varget, ncid, 'n_gr_rc_rejected_NS', n_gr_rc_rejected_NS
        ncdf_varget, ncid, 'n_gr_rp_rejected_NS', n_gr_rp_rejected_NS
        ncdf_varget, ncid, 'n_gr_rr_rejected_NS', n_gr_rr_rejected_NS
        ncdf_varget, ncid, 'n_gr_hid_rejected_NS', n_gr_hid_rejected_NS
        ncdf_varget, ncid, 'n_gr_dzero_rejected_NS', n_gr_dzero_rejected_NS
        ncdf_varget, ncid, 'n_gr_nw_rejected_NS', n_gr_nw_rejected_NS
        ncdf_varget, ncid, 'n_gr_dm_rejected_NS', n_gr_dm_rejected_NS
        ncdf_varget, ncid, 'n_gr_n2_rejected_NS', n_gr_n2_rejected_NS
        ncdf_varget, ncid, 'n_gr_expected_NS', n_gr_expected_NS
        ncdf_varget, ncid, 'precipTotPSDparamHigh_NS', precipTotPSDparamHigh_NS
        ncdf_varget, ncid, 'precipTotPSDparamLow_NS', precipTotPSDparamLow_NS
        ncdf_varget, ncid, 'precipTotRate_NS', precipTotRate_NS
        ncdf_varget, ncid, 'precipTotWaterCont_NS', precipTotWaterCont_NS
        ncdf_varget, ncid, 'n_precipTotPSDparamHigh_rejected_NS', n_precipTotPSDparamHigh_rejected_NS
        ncdf_varget, ncid, 'n_precipTotPSDparamLow_rejected_NS', n_precipTotPSDparamLow_rejected_NS
        ncdf_varget, ncid, 'n_precipTotRate_rejected_NS', n_precipTotRate_rejected_NS
        ncdf_varget, ncid, 'n_precipTotWaterCont_rejected_NS', n_precipTotWaterCont_rejected_NS
        ncdf_varget, ncid, 'precipitationType_NS', precipitationType_NS
        ncdf_varget, ncid, 'surfPrecipTotRate_NS', surfPrecipTotRate_NS
        ncdf_varget, ncid, 'surfaceElevation_NS', surfaceElevation_NS
        ncdf_varget, ncid, 'zeroDegAltitude_NS', zeroDegAltitude_NS
        ncdf_varget, ncid, 'zeroDegBin_NS', zeroDegBin_NS
        ncdf_varget, ncid, 'surfaceType_NS', surfaceType_NS
        ncdf_varget, ncid, 'phaseBinNodes_NS', phaseBinNodes_NS
        ncdf_varget, ncid, 'DPRlatitude_NS', DPRlatitude_NS
        ncdf_varget, ncid, 'DPRlongitude_NS', DPRlongitude_NS
        ncdf_varget, ncid, 'scanNum_NS', scanNum_NS
        ncdf_varget, ncid, 'rayNum_NS', rayNum_NS
        ncdf_varget, ncid, 'ellipsoidBinOffset_NS', ellipsoidBinOffset_NS
        ncdf_varget, ncid, 'lowestClutterFreeBin_NS', lowestClutterFreeBin_NS
        ncdf_varget, ncid, 'clutterStatus_NS', clutterStatus_NS
        ncdf_varget, ncid, 'precipitationFlag_NS', precipitationFlag_NS
        ncdf_varget, ncid, 'surfaceRangeBin_NS', surfaceRangeBin_NS
        ncdf_varget, ncid, 'correctedReflectFactor_NS', correctedReflectFactor_NS
        ncdf_varget, ncid, 'pia_NS', pia_NS
        ncdf_varget, ncid, 'stormTopAltitude_NS', stormTopAltitude_NS
        ncdf_varget, ncid, 'n_correctedReflectFactor_rejected_NS', n_correctedReflectFactor_rejected_NS
        ncdf_varget, ncid, 'n_dpr_expected_NS', n_dpr_expected_NS

	ncdf_close, ncid

	;For the dimensions of the file:
        file_pix_MS=count_fpdim_MS[ff]
        file_pix_NS=count_fpdim_NS[ff]
        file_elev=count_elevationAngle[ff]
        nelev=total_elevangle

        ;The bottomHeight and topHeight is in AGL while site_elev is in MSL
        ;You need to convert the bottomHeight, topHeight to MSL everywhere by doing:
        ;bottomHeight_MS + site_elev = MSL
	;In order to do this, you need to do the following first:
	;To get rid of the -100.000 AND -9999.00
	bottomHeight_MS_MSL=bottomHeight_MS+site_elev
	bottomHeight_MS_MSL[where(bottomHeight_MS_MSL le site_elev)]=mvf
        topHeight_MS_MSL=topHeight_MS+site_elev
        topHeight_MS_MSL[where(topHeight_MS_MSL le site_elev)]=mvf
        bottomHeight_NS_MSL=bottomHeight_NS+site_elev
        bottomHeight_NS_MSL[where(bottomHeight_NS_MSL le site_elev)]=mvf
        topHeight_NS_MSL=topHeight_NS+site_elev
        topHeight_NS_MSL[where(topHeight_NS_MSL le site_elev)]=mvf

        print, 'File elvation angles:'
        print, elevationAngle
	print, ''
	print, 'It is reading in the variables:'
	print, 'count_fpdim_MS = ', count_fpdim_MS
	print, 'count_fpdim_NS = ', count_fpdim_NS
	print, 'This is the beginning of ff = file number = ', ff
	print, '************'
	print, ''

        ;For the variables that are not a function of MS or MS:
	large_timeNearestApproach[ff] = timeNearestApproach
	large_atimeNearestApproach[ff,0:18] = atimeNearestApproach[*]
	large_timeSweepStart[ff,0:file_elev-1] = timeSweepStart[*]
        large_atimeSweepStart[ff,0:18,0:file_elev-1] = atimeSweepStart[*,*]
;	large_site_ID[ff,0:3] = site_ID[*]
	large_site_ID[ff,*] = site_ID[*]
        large_site_lat[ff] = site_lat
        large_site_lon[ff] = site_lon
        large_site_elev[ff] = site_elev
	large_version[ff] = version
	large_elevationAngle[ff,0:file_elev-1] = elevationAngle[*]
	large_rangeThreshold[ff] = rangeThreshold
	large_DPR_dBZ_min[ff] = DPR_dBZ_min
	large_GR_dBZ_min[ff] = GR_dBZ_min
	large_rain_min[ff] = rain_min

	;For the variables that are a function of MS and NS, BUT are not a fx of file_pix_MS or file_pix_NS:
	large_Year_MS[0:n_elements(Year_MS)-1,ff] = Year_MS[*]
	large_Month_MS[0:n_elements(Year_MS)-1,ff] = Month_MS[*]
	large_DayOfMonth_MS[0:n_elements(Year_MS)-1,ff] = DayOfMonth_MS[*]
	large_Hour_MS[0:n_elements(Year_MS)-1,ff] = Hour_MS[*]
	large_Minute_MS[0:n_elements(Year_MS)-1,ff] = Minute_MS[*]
	large_Second_MS[0:n_elements(Year_MS)-1,ff] = Second_MS[*]
	large_Millisecond_MS[0:n_elements(Year_MS)-1,ff] = Millisecond_MS[*]
	large_startScan_MS[ff] = startScan_MS
	large_endScan_MS[ff] = endScan_MS
 	large_numRays_MS[ff] = numRays_MS ;This just gives the nr of lines PER file PER scan...

        large_Year_NS[0:n_elements(Year_NS)-1,ff] = Year_NS[*]
        large_Month_NS[0:n_elements(Year_NS)-1,ff] = Month_NS[*]
        large_DayOfMonth_NS[0:n_elements(Year_NS)-1,ff] = DayOfMonth_NS[*]
        large_Hour_NS[0:n_elements(Year_NS)-1,ff] = Hour_NS[*]
        large_Minute_NS[0:n_elements(Year_NS)-1,ff] = Minute_NS[*]
        large_Second_NS[0:n_elements(Year_NS)-1,ff] = Second_NS[*]
        large_Millisecond_NS[0:n_elements(Year_NS)-1,ff] = Millisecond_NS[*]
        large_startScan_NS[ff] = startScan_NS
        large_endScan_NS[ff] = endScan_NS
        large_numRays_NS[ff] = numRays_NS ;This just gives the nr of lines PER file PER scan...

	;This is where we save the original data into the "Large" array for each variable:
	;For the MS and non-NS variables:
        for gg=0, file_pix_MS-1 do begin   
          large_latitude_MS[counter_MS,0:file_elev-1] = latitude_MS[gg,0:file_elev-1]
          large_longitude_MS[counter_MS,0:file_elev-1] = longitude_MS[gg,0:file_elev-1]
          large_xCorners_MS[0:3,counter_MS,0:file_elev-1] = xCorners_MS[0:3,gg,0:file_elev-1]
          large_yCorners_MS[0:3,counter_MS,0:file_elev-1] = yCorners_MS[0:3,gg,0:file_elev-1]
          large_topHeight_MS[counter_MS,0:file_elev-1] = topHeight_MS[gg,0:file_elev-1]
          large_bottomHeight_MS[counter_MS,0:file_elev-1] = bottomHeight_MS[gg,0:file_elev-1]
          large_topHeight_MS_MSL[counter_MS,0:file_elev-1] = topHeight_MS_MSL[gg,0:file_elev-1]
          large_bottomHeight_MS_MSL[counter_MS,0:file_elev-1] = bottomHeight_MS_MSL[gg,0:file_elev-1]
          large_GR_Z_MS[counter_MS,0:file_elev-1] = GR_Z_MS[gg,0:file_elev-1]
          large_GR_Z_StdDev_MS[counter_MS,0:file_elev-1] = GR_Z_StdDev_MS[gg,0:file_elev-1]
          large_GR_Z_Max_MS[counter_MS,0:file_elev-1] = GR_Z_Max_MS[gg,0:file_elev-1]
          large_GR_Zdr_MS[counter_MS,0:file_elev-1] = GR_Zdr_MS[gg,0:file_elev-1]
          large_GR_Zdr_StdDev_MS[counter_MS,0:file_elev-1] = GR_Zdr_StdDev_MS[gg,0:file_elev-1]
          large_GR_Zdr_Max_MS[counter_MS,0:file_elev-1] = GR_Zdr_Max_MS[gg,0:file_elev-1]
          large_GR_Kdp_MS[counter_MS,0:file_elev-1] = GR_Kdp_MS[gg,0:file_elev-1]
          large_GR_Kdp_StdDev_MS[counter_MS,0:file_elev-1] = GR_Kdp_StdDev_MS[gg,0:file_elev-1]
          large_GR_Kdp_Max_MS[counter_MS,0:file_elev-1] = GR_Kdp_Max_MS[gg,0:file_elev-1]
          large_GR_RHOhv_MS[counter_MS,0:file_elev-1] = GR_RHOhv_MS[gg,0:file_elev-1]
          large_GR_RHOhv_StdDev_MS[counter_MS,0:file_elev-1] = GR_RHOhv_StdDev_MS[gg,0:file_elev-1]
          large_GR_RHOhv_Max_MS[counter_MS,0:file_elev-1] = GR_RHOhv_Max_MS[gg,0:file_elev-1]
          large_GR_RC_rainrate_MS[counter_MS,0:file_elev-1] = GR_RC_rainrate_MS[gg,0:file_elev-1]
          large_GR_RC_rainrate_StdDev_MS[counter_MS,0:file_elev-1] = GR_RC_rainrate_StdDev_MS[gg,0:file_elev-1]
          large_GR_RC_rainrate_Max_MS[counter_MS,0:file_elev-1] = GR_RC_rainrate_Max_MS[gg,0:file_elev-1]
          large_GR_RP_rainrate_MS[counter_MS,0:file_elev-1] = GR_RP_rainrate_MS[gg,0:file_elev-1]
          large_GR_RP_rainrate_StdDev_MS[counter_MS,0:file_elev-1] = GR_RP_rainrate_StdDev_MS[gg,0:file_elev-1]
          large_GR_RP_rainrate_Max_MS[counter_MS,0:file_elev-1] = GR_RP_rainrate_Max_MS[gg,0:file_elev-1]
          large_GR_RR_rainrate_MS[counter_MS,0:file_elev-1] = GR_RR_rainrate_MS[gg,0:file_elev-1]
          large_GR_RR_rainrate_StdDev_MS[counter_MS,0:file_elev-1] = GR_RR_rainrate_StdDev_MS[gg,0:file_elev-1]
          large_GR_RR_rainrate_Max_MS[counter_MS,0:file_elev-1] = GR_RR_rainrate_Max_MS[gg,0:file_elev-1]
          large_GR_HID_MS[0:14,counter_MS,0:file_elev-1] = GR_HID_MS[0:14,gg,0:file_elev-1]
          large_GR_Dzero_MS[counter_MS,0:file_elev-1] = GR_Dzero_MS[gg,0:file_elev-1]
          large_GR_Dzero_StdDev_MS[counter_MS,0:file_elev-1] = GR_Dzero_StdDev_MS[gg,0:file_elev-1]
          large_GR_Dzero_Max_MS[counter_MS,0:file_elev-1] = GR_Dzero_Max_MS[gg,0:file_elev-1]
          large_GR_Nw_MS[counter_MS,0:file_elev-1] = GR_Nw_MS[gg,0:file_elev-1]
          large_GR_Nw_StdDev_MS[counter_MS,0:file_elev-1] = GR_Nw_StdDev_MS[gg,0:file_elev-1]
          large_GR_Nw_Max_MS[counter_MS,0:file_elev-1] = GR_Nw_Max_MS[gg,0:file_elev-1]
          large_GR_Dm_MS[counter_MS,0:file_elev-1] = GR_Dm_MS[gg,0:file_elev-1]
          large_GR_Dm_StdDev_MS[counter_MS,0:file_elev-1] = GR_Dm_StdDev_MS[gg,0:file_elev-1]
          large_GR_Dm_Max_MS[counter_MS,0:file_elev-1] = GR_Dm_Max_MS[gg,0:file_elev-1]
          large_GR_N2_MS[counter_MS,0:file_elev-1] = GR_N2_MS[gg,0:file_elev-1]
          large_GR_N2_StdDev_MS[counter_MS,0:file_elev-1] = GR_N2_StdDev_MS[gg,0:file_elev-1]
          large_GR_N2_Max_MS[counter_MS,0:file_elev-1] = GR_N2_Max_MS[gg,0:file_elev-1]
          large_GR_blockage_MS[counter_MS,0:file_elev-1] = GR_blockage_MS[gg,0:file_elev-1] 
          large_n_gr_z_rejected_MS[counter_MS,0:file_elev-1] = n_gr_z_rejected_MS[gg,0:file_elev-1]
          large_n_gr_zdr_rejected_MS[counter_MS,0:file_elev-1] = n_gr_zdr_rejected_MS[gg,0:file_elev-1]
          large_n_gr_kdp_rejected_MS[counter_MS,0:file_elev-1] = n_gr_kdp_rejected_MS[gg,0:file_elev-1]
          large_n_gr_rhohv_rejected_MS[counter_MS,0:file_elev-1] = n_gr_rhohv_rejected_MS[gg,0:file_elev-1]
          large_n_gr_rc_rejected_MS[counter_MS,0:file_elev-1] = n_gr_rc_rejected_MS[gg,0:file_elev-1]
          large_n_gr_rp_rejected_MS[counter_MS,0:file_elev-1] = n_gr_rp_rejected_MS[gg,0:file_elev-1]
          large_n_gr_rr_rejected_MS[counter_MS,0:file_elev-1] = n_gr_rr_rejected_MS[gg,0:file_elev-1]
          large_n_gr_hid_rejected_MS[counter_MS,0:file_elev-1] = n_gr_hid_rejected_MS[gg,0:file_elev-1]
          large_n_gr_dzero_rejected_MS[counter_MS,0:file_elev-1] = n_gr_dzero_rejected_MS[gg,0:file_elev-1]
          large_n_gr_nw_rejected_MS[counter_MS,0:file_elev-1] = n_gr_nw_rejected_MS[gg,0:file_elev-1]
          large_n_gr_dm_rejected_MS[counter_MS,0:file_elev-1] = n_gr_dm_rejected_MS[gg,0:file_elev-1]
          true_large_n_gr_dm_rejected_MS=reform(large_n_gr_dm_rejected_MS[*,0,*]) ;Note the subset
          large_n_gr_n2_rejected_MS[counter_MS,0:file_elev-1] = n_gr_n2_rejected_MS[gg,0:file_elev-1]
          true_large_n_gr_n2_rejected_MS=reform(large_n_gr_n2_rejected_MS[*,0,*]) ;Note the subset
          large_n_gr_expected_MS[counter_MS,0:file_elev-1] = n_gr_expected_MS[gg,0:file_elev-1]
          large_precipTotPSDparamHigh_MS[counter_MS,0:file_elev-1] = precipTotPSDparamHigh_MS[gg,0:file_elev-1]
          large_precipTotPSDparamLow_MS[0:1,counter_MS,0:file_elev-1] = precipTotPSDparamLow_MS[0:1,gg,0:file_elev-1]
          large_precipTotRate_MS[counter_MS,0:file_elev-1] = precipTotRate_MS[gg,0:file_elev-1]
          large_precipTotWaterCont_MS[counter_MS,0:file_elev-1] = precipTotWaterCont_MS[gg,0:file_elev-1]
          large_n_precipTotPSDparamHigh_rejected_MS[counter_MS,0:file_elev-1] = $
		n_precipTotPSDparamHigh_rejected_MS[gg,0:file_elev-1]
          large_n_precipTotPSDparamLow_rejected_MS[0:1,counter_MS,0:file_elev-1] = $
		n_precipTotPSDparamLow_rejected_MS[0:1,gg,0:file_elev-1]
          large_n_precipTotRate_rejected_MS[counter_MS,0:file_elev-1] = n_precipTotRate_rejected_MS[gg,0:file_elev-1]
          large_n_precipTotWaterCont_rejected_MS[counter_MS,0:file_elev-1] = $
		n_precipTotWaterCont_rejected_MS[gg,0:file_elev-1]
          large_precipitationType_MS[counter_MS] = precipitationType_MS[gg]
          large_surfPrecipTotRate_MS[counter_MS] = surfPrecipTotRate_MS[gg]
          large_surfaceElevation_MS[counter_MS] = surfaceElevation_MS[gg]
          large_zeroDegAltitude_MS[counter_MS] = zeroDegAltitude_MS[gg]
          large_zeroDegBin_MS[counter_MS] = zeroDegBin_MS[gg]
          large_surfaceType_MS[counter_MS] = surfaceType_MS[gg]
          large_phaseBinNodes_MS[0:4,counter_MS] = phaseBinNodes_MS[0:4,gg]
          large_DPRlatitude_MS[counter_MS] = DPRlatitude_MS[gg]
          large_DPRlongitude_MS[counter_MS] = DPRlongitude_MS[gg]
          large_scanNum_MS[counter_MS] = scanNum_MS[gg]
          large_rayNum_MS[counter_MS] = rayNum_MS[gg]
          large_ellipsoidBinOffset_MS[0:1,counter_MS] = ellipsoidBinOffset_MS[0:1,gg]
          large_lowestClutterFreeBin_MS[0:1,counter_MS] = lowestClutterFreeBin_MS[0:1,gg]
          large_clutterStatus_MS[0:1,counter_MS,0:file_elev-1] = clutterStatus_MS[0:1,gg,0:file_elev-1]
          large_precipitationFlag_MS[0:1,counter_MS] = precipitationFlag_MS[0:1,gg]
          large_surfaceRangeBin_MS[0:1,counter_MS] = surfaceRangeBin_MS[0:1,gg]
          large_correctedReflectFactor_MS[0:1,counter_MS,0:file_elev-1] = $
		correctedReflectFactor_MS[0:1,gg,0:file_elev-1]
          large_pia_MS[0:1,counter_MS] = pia_MS[0:1,gg]
          large_stormTopAltitude_MS[0:1,counter_MS] = stormTopAltitude_MS[0:1,gg]
          large_n_correctedReflectFactor_rejected_MS[0:1,counter_MS,0:file_elev-1] = $
		n_correctedReflectFactor_rejected_MS[0:1,gg,0:file_elev-1]
          large_n_dpr_expected_MS[0:1,counter_MS,0:file_elev-1] = n_dpr_expected_MS[0:1,gg,0:file_elev-1]

          counter_MS = counter_MS+1 ;This is the counter for the LARGE file

        endfor ;gg for the MS and non-NS variables

        ;Need to reset the variables from the original .nc file in order to reduce memory usage:
        latitude_MS=0 & longitude_MS=0 & xCorners_MS=0 & yCorners_MS=0
        topHeight_MS=0 & bottomHeight_MS=0 & topHeight_MS_MSL=0 & bottomHeight_MS_MSL=0
        GR_Z_MS=0 & GR_Z_StdDev_MS=0 & GR_Z_Max_MS=0 & GR_Zdr_MS=0 & GR_Zdr_StdDev_MS=0 & GR_Zdr_Max_MS=0
        GR_Kdp_MS=0 & GR_Kdp_StdDev_MS=0 & GR_Kdp_Max_MS=0 & GR_RHOhv_MS=0 & GR_RHOhv_StdDev_MS=0 & GR_RHOhv_Max_MS=0
        GR_RC_rainrate_MS=0 & GR_RC_rainrate_StdDev_MS=0 & GR_RC_rainrate_Max_MS=0
        GR_RP_rainrate_MS=0 & GR_RP_rainrate_StdDev_MS=0 & GR_RP_rainrate_Max_MS=0
        GR_RR_rainrate_MS=0 & GR_RR_rainrate_StdDev_MS=0 & GR_RR_rainrate_Max_MS=0
        GR_HID_MS=0 & GR_Dzero_MS=0 & GR_Dzero_StdDev_MS=0 & GR_Dzero_Max_MS=0
        GR_Nw_MS=0 & GR_Nw_StdDev_MS=0 & GR_Nw_Max_MS=0 & GR_Dm_MS=0 & GR_Dm_StdDev_MS=0 & GR_Dm_Max_MS=0
        GR_N2_MS=0 & GR_N2_StdDev_MS=0 & GR_N2_Max_MS=0 & GR_blockage_MS=0 & n_gr_z_rejected_MS=0 & n_gr_zdr_rejected_MS=0
        n_gr_kdp_rejected_MS=0 & n_gr_rhohv_rejected_MS=0 & n_gr_rc_rejected_MS=0 & n_gr_rp_rejected_MS=0
        n_gr_rr_rejected_MS=0 & n_gr_hid_rejected_MS=0 & n_gr_dzero_rejected_MS=0 & n_gr_nw_rejected_MS=0
        n_gr_dm_rejected_MS=0 & n_gr_n2_rejected_MS=0 & n_gr_expected_MS=0 & precipTotPSDparamHigh_MS=0
        precipTotPSDparamLow_MS=0 & precipTotRate_MS=0 & precipTotWaterCont_MS=0 & n_precipTotPSDparamHigh_rejected_MS=0
        n_precipTotPSDparamLow_rejected_MS=0 & n_precipTotRate_rejected_MS=0 & n_precipTotWaterCont_rejected_MS=0
        precipitationType_MS=0 & surfPrecipTotRate_MS=0 & surfaceElevation_MS=0 & zeroDegAltitude_MS=0
        zeroDegBin_MS=0 & surfaceType_MS=0 & phaseBinNodes_MS=0 & DPRlatitude_MS=0 & DPRlongitude_MS=0
        scanNum_MS=0 & rayNum_MS=0 & ellipsoidBinOffset_MS=0 & lowestClutterFreeBin_MS=0
        clutterStatus_MS=0 & precipitationFlag_MS=0 & surfaceRangeBin_MS=0 & correctedReflectFactor_MS=0
        pia_MS=0 & stormTopAltitude_MS=0 & n_correctedReflectFactor_rejected_MS=0 & n_dpr_expected_MS=0

        ;For the NS variables:
	for hh=0, file_pix_NS-1 do begin
          large_latitude_NS[counter_NS,0:file_elev-1] = latitude_NS[hh,0:file_elev-1]
          large_longitude_NS[counter_NS,0:file_elev-1] = longitude_NS[hh,0:file_elev-1]
          large_xCorners_NS[0:3,counter_NS,0:file_elev-1] = xCorners_NS[0:3,hh,0:file_elev-1]
          large_yCorners_NS[0:3,counter_NS,0:file_elev-1] = yCorners_NS[0:3,hh,0:file_elev-1]
          large_topHeight_NS[counter_NS,0:file_elev-1] = topHeight_NS[hh,0:file_elev-1]
          large_bottomHeight_NS[counter_NS,0:file_elev-1] = bottomHeight_NS[hh,0:file_elev-1]
          large_topHeight_NS_MSL[counter_NS,0:file_elev-1] = topHeight_NS_MSL[hh,0:file_elev-1]
          large_bottomHeight_NS_MSL[counter_NS,0:file_elev-1] = bottomHeight_NS_MSL[hh,0:file_elev-1]
          large_GR_Z_NS[counter_NS,0:file_elev-1] = GR_Z_NS[hh,0:file_elev-1]
          large_GR_Z_StdDev_NS[counter_NS,0:file_elev-1] = GR_Z_StdDev_NS[hh,0:file_elev-1]
          large_GR_Z_Max_NS[counter_NS,0:file_elev-1] = GR_Z_Max_NS[hh,0:file_elev-1]
          large_GR_Zdr_NS[counter_NS,0:file_elev-1] = GR_Zdr_NS[hh,0:file_elev-1]
          large_GR_Zdr_StdDev_NS[counter_NS,0:file_elev-1] = GR_Zdr_StdDev_NS[hh,0:file_elev-1]
          large_GR_Zdr_Max_NS[counter_NS,0:file_elev-1] = GR_Zdr_Max_NS[hh,0:file_elev-1]
          large_GR_Kdp_NS[counter_NS,0:file_elev-1] = GR_Kdp_NS[hh,0:file_elev-1]
          large_GR_Kdp_StdDev_NS[counter_NS,0:file_elev-1] = GR_Kdp_StdDev_NS[hh,0:file_elev-1]
          large_GR_Kdp_Max_NS[counter_NS,0:file_elev-1] = GR_Kdp_Max_NS[hh,0:file_elev-1]
          large_GR_RHOhv_NS[counter_NS,0:file_elev-1] = GR_RHOhv_NS[hh,0:file_elev-1]
          large_GR_RHOhv_StdDev_NS[counter_NS,0:file_elev-1] = GR_RHOhv_StdDev_NS[hh,0:file_elev-1]
          large_GR_RHOhv_Max_NS[counter_NS,0:file_elev-1] = GR_RHOhv_Max_NS[hh,0:file_elev-1]
          large_GR_RC_rainrate_NS[counter_NS,0:file_elev-1] = GR_RC_rainrate_NS[hh,0:file_elev-1]
          large_GR_RC_rainrate_StdDev_NS[counter_NS,0:file_elev-1] = GR_RC_rainrate_StdDev_NS[hh,0:file_elev-1]
          large_GR_RC_rainrate_Max_NS[counter_NS,0:file_elev-1] = GR_RC_rainrate_Max_NS[hh,0:file_elev-1]
          large_GR_RP_rainrate_NS[counter_NS,0:file_elev-1] = GR_RP_rainrate_NS[hh,0:file_elev-1]
          large_GR_RP_rainrate_StdDev_NS[counter_NS,0:file_elev-1] = GR_RP_rainrate_StdDev_NS[hh,0:file_elev-1]
          large_GR_RP_rainrate_Max_NS[counter_NS,0:file_elev-1] = GR_RP_rainrate_Max_NS[hh,0:file_elev-1]
          large_GR_RR_rainrate_NS[counter_NS,0:file_elev-1] = GR_RR_rainrate_NS[hh,0:file_elev-1]
          large_GR_RR_rainrate_StdDev_NS[counter_NS,0:file_elev-1] = GR_RR_rainrate_StdDev_NS[hh,0:file_elev-1]
          large_GR_RR_rainrate_Max_NS[counter_NS,0:file_elev-1] = GR_RR_rainrate_Max_NS[hh,0:file_elev-1]
          large_GR_HID_NS[0:14,counter_NS,0:file_elev-1] = GR_HID_NS[0:14,hh,0:file_elev-1]
          large_GR_Dzero_NS[counter_NS,0:file_elev-1] = GR_Dzero_NS[hh,0:file_elev-1]
          large_GR_Dzero_StdDev_NS[counter_NS,0:file_elev-1] = GR_Dzero_StdDev_NS[hh,0:file_elev-1]
          large_GR_Dzero_Max_NS[counter_NS,0:file_elev-1] = GR_Dzero_Max_NS[hh,0:file_elev-1]
          large_GR_Nw_NS[counter_NS,0:file_elev-1] = GR_Nw_NS[hh,0:file_elev-1]
          large_GR_Nw_StdDev_NS[counter_NS,0:file_elev-1] = GR_Nw_StdDev_NS[hh,0:file_elev-1]
          large_GR_Nw_Max_NS[counter_NS,0:file_elev-1] = GR_Nw_Max_NS[hh,0:file_elev-1]
          large_GR_Dm_NS[counter_NS,0:file_elev-1] = GR_Dm_NS[hh,0:file_elev-1]
          large_GR_Dm_StdDev_NS[counter_NS,0:file_elev-1] = GR_Dm_StdDev_NS[hh,0:file_elev-1]
          large_GR_Dm_Max_NS[counter_NS,0:file_elev-1] = GR_Dm_Max_NS[hh,0:file_elev-1]
          large_GR_N2_NS[counter_NS,0:file_elev-1] = GR_N2_NS[hh,0:file_elev-1]
          large_GR_N2_StdDev_NS[counter_NS,0:file_elev-1] = GR_N2_StdDev_NS[hh,0:file_elev-1]
          large_GR_N2_Max_NS[counter_NS,0:file_elev-1] = GR_N2_Max_NS[hh,0:file_elev-1]
          large_GR_blockage_NS[counter_NS,0:file_elev-1] = GR_blockage_NS[hh,0:file_elev-1]
          large_n_gr_z_rejected_NS[counter_NS,0:file_elev-1] = n_gr_z_rejected_NS[hh,0:file_elev-1]
          large_n_gr_zdr_rejected_NS[counter_NS,0:file_elev-1] = n_gr_zdr_rejected_NS[hh,0:file_elev-1]
          large_n_gr_kdp_rejected_NS[counter_NS,0:file_elev-1] = n_gr_kdp_rejected_NS[hh,0:file_elev-1]
          large_n_gr_rhohv_rejected_NS[counter_NS,0:file_elev-1] = n_gr_rhohv_rejected_NS[hh,0:file_elev-1]
          large_n_gr_rc_rejected_NS[counter_NS,0:file_elev-1] = n_gr_rc_rejected_NS[hh,0:file_elev-1]
          large_n_gr_rp_rejected_NS[counter_NS,0:file_elev-1] = n_gr_rp_rejected_NS[hh,0:file_elev-1]
          large_n_gr_rr_rejected_NS[counter_NS,0:file_elev-1] = n_gr_rr_rejected_NS[hh,0:file_elev-1]
          large_n_gr_hid_rejected_NS[counter_NS,0:file_elev-1] = n_gr_hid_rejected_NS[hh,0:file_elev-1]
          large_n_gr_dzero_rejected_NS[counter_NS,0:file_elev-1] = n_gr_dzero_rejected_NS[hh,0:file_elev-1]
          large_n_gr_nw_rejected_NS[counter_NS,0:file_elev-1] = n_gr_nw_rejected_NS[hh,0:file_elev-1]
          large_n_gr_expected_NS[counter_NS,0:file_elev-1] = n_gr_expected_NS[hh,0:file_elev-1]
          large_precipTotPSDparamHigh_NS[counter_NS,0:file_elev-1] = precipTotPSDparamHigh_NS[hh,0:file_elev-1]
          large_precipTotPSDparamLow_NS[0:1,counter_NS,0:file_elev-1] = precipTotPSDparamLow_NS[0:1,hh,0:file_elev-1]
          large_precipTotRate_NS[counter_NS,0:file_elev-1] = precipTotRate_NS[hh,0:file_elev-1]
          large_precipTotWaterCont_NS[counter_NS,0:file_elev-1] = precipTotWaterCont_NS[hh,0:file_elev-1]
          large_n_precipTotPSDparamHigh_rejected_NS[counter_NS,0:file_elev-1] = $
                n_precipTotPSDparamHigh_rejected_NS[hh,0:file_elev-1]
          large_n_precipTotPSDparamLow_rejected_NS[0:1,counter_NS,0:file_elev-1] = $
                n_precipTotPSDparamLow_rejected_NS[0:1,hh,0:file_elev-1]
          large_n_precipTotRate_rejected_NS[counter_NS,0:file_elev-1] = n_precipTotRate_rejected_NS[hh,0:file_elev-1]
          large_n_precipTotWaterCont_rejected_NS[counter_NS,0:file_elev-1] = $
                n_precipTotWaterCont_rejected_NS[hh,0:file_elev-1]
          large_precipitationType_NS[counter_NS] = precipitationType_NS[hh]
          large_surfPrecipTotRate_NS[counter_NS] = surfPrecipTotRate_NS[hh]
          large_surfaceElevation_NS[counter_NS] = surfaceElevation_NS[hh]
          large_zeroDegAltitude_NS[counter_NS] = zeroDegAltitude_NS[hh]
          large_zeroDegBin_NS[counter_NS] = zeroDegBin_NS[hh]
          large_surfaceType_NS[counter_NS] = surfaceType_NS[hh]
          large_phaseBinNodes_NS[0:4,counter_NS] = phaseBinNodes_NS[0:4,hh]
          large_DPRlatitude_NS[counter_NS] = DPRlatitude_NS[hh]
          large_DPRlongitude_NS[counter_NS] = DPRlongitude_NS[hh]
          large_scanNum_NS[counter_NS] = scanNum_NS[hh]
          large_rayNum_NS[counter_NS] = rayNum_NS[hh]
          large_ellipsoidBinOffset_NS[counter_NS] = ellipsoidBinOffset_NS[hh]
          large_lowestClutterFreeBin_NS[counter_NS] = lowestClutterFreeBin_NS[hh]
          large_clutterStatus_NS[counter_NS,0:file_elev-1] = clutterStatus_NS[hh,0:file_elev-1]
          large_precipitationFlag_NS[counter_NS] = precipitationFlag_NS[hh]
          large_surfaceRangeBin_NS[counter_NS] = surfaceRangeBin_NS[hh]
          large_correctedReflectFactor_NS[counter_NS,0:file_elev-1] = $
                correctedReflectFactor_NS[hh,0:file_elev-1]
          large_pia_NS[counter_NS] = pia_NS[hh]
          large_stormTopAltitude_NS[counter_NS] = stormTopAltitude_NS[hh]
          large_n_correctedReflectFactor_rejected_NS[counter_NS,0:file_elev-1] = $
                n_correctedReflectFactor_rejected_NS[hh,0:file_elev-1]
          large_n_dpr_expected_NS[counter_NS,0:file_elev-1] = n_dpr_expected_NS[hh,0:file_elev-1]

          counter_NS = counter_NS+1 ;This is the counter for the LARGE file
        endfor ;hh for the NS variables (different dimensions)

	;We are using the MS variable to subset the NS variable, because the NS variable is ALWAYS missing values
	;and this is the only way to save the information to a grid. This is the correct way of doing things.
        true_large_n_gr_dm_rejected_NS=reform(large_n_gr_dm_rejected_MS[0,*,*]) 
        true_large_n_gr_n2_rejected_NS=reform(large_n_gr_n2_rejected_MS[0,*,*]) 

        spawn, 'gzip '+indir+'/'+strcompress(year[aa])+'/'+new_filename[ff]

     endfor ; ff Number of files being read in

     ;Need to reset the variables from the .nc file in order to reduce memory usage:
     latitude_NS=0 & longitude_NS=0 & xCorners_NS=0 & yCorners_NS=0 & topHeight_NS=0 & bottomHeight_NS=0
     topHeight_NS_MSL=0 & bottomHeight_NS_MSL=0 & GR_Z_NS=0 & GR_Z_StdDev_NS=0 & GR_Z_Max_NS=0
     GR_Zdr_NS=0 & GR_Zdr_StdDev_NS=0 & GR_Zdr_Max_NS=0 & GR_Kdp_NS=0 & GR_Kdp_StdDev_NS=0 & GR_Kdp_Max_NS=0
     GR_RHOhv_NS=0 & GR_RHOhv_StdDev_NS=0 & GR_RHOhv_Max_NS=0 & GR_RC_rainrate_NS=0 & GR_RC_rainrate_StdDev_NS=0
     GR_RC_rainrate_Max_NS=0 & GR_RP_rainrate_NS=0 & GR_RP_rainrate_StdDev_NS=0 & GR_RP_rainrate_Max_NS=0
     GR_RR_rainrate_NS=0 & GR_RR_rainrate_StdDev_NS=0 & GR_RR_rainrate_Max_NS=0 & GR_HID_NS=0
     GR_Dzero_NS=0 & GR_Dzero_StdDev_NS=0 & GR_Dzero_Max_NS=0 & GR_Nw_NS=0 & GR_Nw_StdDev_NS=0
     GR_Nw_Max_NS=0 & GR_Dm_NS=0 & GR_Dm_StdDev_NS=0 & GR_Dm_Max_NS=0 & GR_N2_NS=0 & GR_N2_StdDev_NS=0
     GR_N2_Max_NS=0 & GR_blockage_NS=0 & n_gr_z_rejected_NS=0 & n_gr_zdr_rejected_NS=0
     n_gr_kdp_rejected_NS=0 & n_gr_rhohv_rejected_NS=0 & n_gr_rc_rejected_NS=0 & n_gr_rp_rejected_NS=0
     n_gr_rr_rejected_NS=0 & n_gr_hid_rejected_NS=0 & n_gr_dzero_rejected_NS=0 & n_gr_nw_rejected_NS=0
     n_gr_dm_rejected_NS=0 & n_gr_n2_rejected_NS=0 & n_gr_expected_NS=0 & precipTotPSDparamHigh_NS=0
     precipTotPSDparamLow_NS=0 & precipTotRate_NS=0 & precipTotWaterCont_NS=0 & n_precipTotPSDparamHigh_rejected_NS=0
     n_precipTotPSDparamLow_rejected_NS=0 & n_precipTotRate_rejected_NS=0 & n_precipTotWaterCont_rejected_NS=0
     precipitationType_NS=0 & surfPrecipTotRate_NS=0 & surfaceElevation_NS=0 & zeroDegAltitude_NS=0
     zeroDegBin_NS=0 & surfaceType_NS=0 & phaseBinNodes_NS=0 & DPRlatitude_NS=0 & DPRlongitude_NS=0
     scanNum_NS=0 & rayNum_NS=0 & ellipsoidBinOffset_NS=0 & lowestClutterFreeBin_NS=0 & clutterStatus_NS=0
     precipitationFlag_NS=0 & surfaceRangeBin_NS=0 & correctedReflectFactor_NS=0 & pia_NS=0
     stormTopAltitude_NS=0 & n_correctedReflectFactor_rejected_NS=0 & n_dpr_expected_NS=0

     ;For the variables that do not require being saved according to x, y and z locations:
     ;i.e., the variables that are a function of MS and NS, BUT are not a fx of file_pix_MS or file_pix_NS
     ;Therefore they don't need to be in any of the following loops
     grid_orig_filename=new_filename  ;The original filenames used for the gridded files
     grid_orig_count_fpdim_MS=count_fpdim_MS ;The original counts for each file in the original filename list
     grid_orig_count_fpdim_NS=count_fpdim_NS
     grid_orig_radarname=fileradarname
     grid_timedimids_MS=count_timedimids_MS
     grid_timedimids_NS=count_timedimids_NS
     grid_orbitnr=final_orbitnr
     grid_nrfiles=n_elements(inlist_new)
     grid_xydim=4
     grid_hidim=15
     grid_nPSDlo=2
     grid_nBnPSDlo=9
     grid_nKuKa=2
     grid_nPhsBnN=5
     grid_len_atime_ID=19
     grid_len_site_ID=10
     grid_nr_xgrid=1466
     grid_nr_ygrid=776
     grid_nr_zgrid=17
     grid_xgrid=xgrid
     grid_ygrid=ygrid
     grid_zgrid=zgrid

     grid_timeNearestApproach=large_timeNearestApproach
     grid_atimeNearestApproach=large_atimeNearestApproach
     grid_timeSweepStart=large_timeSweepStart
     grid_atimeSweepStart=large_atimeSweepStart
     grid_site_ID=large_site_ID
     grid_site_lat=large_site_lat
     grid_site_lon=large_site_lon
     grid_site_elev=large_site_elev
     grid_version=large_version
     grid_elevationAngle=large_elevationAngle
     grid_rangeThreshold=large_rangeThreshold
     grid_DPR_dBZ_min=large_DPR_dBZ_min
     grid_GR_dBZ_min=large_GR_dBZ_min
     grid_rain_min=large_rain_min
     grid_Year_MS=large_Year_MS
     grid_Month_MS=large_Month_MS
     grid_DayOfMonth_MS=large_DayOfMonth_MS
     grid_Hour_MS=large_Hour_MS
     grid_Minute_MS=large_Minute_MS
     grid_Second_MS=large_Second_MS
     grid_Millisecond_MS=large_Millisecond_MS
     grid_startScan_MS=large_startScan_MS
     grid_endScan_MS=large_endScan_MS
     grid_numRays_MS=large_numRays_MS
     grid_Year_NS=large_Year_NS
     grid_Month_NS=large_Month_NS
     grid_DayOfMonth_NS=large_DayOfMonth_NS
     grid_Hour_NS=large_Hour_NS
     grid_Minute_NS=large_Minute_NS
     grid_Second_NS=large_Second_NS
     grid_Millisecond_NS=large_Millisecond_NS
     grid_startScan_NS=large_startScan_NS
     grid_endScan_NS=large_endScan_NS
     grid_numRays_NS=large_numRays_NS

     print, 'All the variables for all files with the same orbit number have successfully been read into the arrays.'
     print, 'Now the conversion from lat/lon/bottomHeight to x, y, and z starts'
     print, ''

     ;To test the conversion of latitude-longitude to x-y cartesian coordinates:
     ;Starting at the bottom left corner of domain to make all x,y values positive
     ;Cannot use elevationAngle here, since center_alt is as a function of km already...
     large_xgrid_MS=fltarr(total_fpdim_MS,total_elevangle)
     large_ygrid_MS=fltarr(total_fpdim_MS,total_elevangle)
     large_xgrid_NS=fltarr(total_fpdim_NS,total_elevangle)
     large_ygrid_NS=fltarr(total_fpdim_NS,total_elevangle)

     large_xindex_MS=fltarr(total_fpdim_MS,total_elevangle)
     large_yindex_MS=fltarr(total_fpdim_MS,total_elevangle)
     large_xindex_NS=fltarr(total_fpdim_NS,total_elevangle)
     large_yindex_NS=fltarr(total_fpdim_NS,total_elevangle)

     testlarge_latitude_MS=large_latitude_MS
     testlarge_latitude_NS=large_latitude_NS
     testlarge_longitude_MS=large_longitude_MS
     testlarge_longitude_NS=large_longitude_NS
     testlarge_DPRlatitude_MS=large_DPRlatitude_MS
     testlarge_DPRlatitude_NS=large_DPRlatitude_NS
     testlarge_DPRlongitude_MS=large_DPRlongitude_MS
     testlarge_DPRlongitude_NS=large_DPRlongitude_NS

     testlarge_latitude_MS[where(large_latitude_MS le -400.00)]=!Values.F_NAN
     testlarge_latitude_NS[where(large_latitude_NS le -400.00)]=!Values.F_NAN
     testlarge_longitude_MS[where(large_longitude_MS le -400.00)]=!Values.F_NAN
     testlarge_longitude_NS[where(large_longitude_NS le -400.00)]=!Values.F_NAN

     testlarge_DPRlatitude_MS[where(large_DPRlatitude_MS le -999.0)]=!Values.F_NAN
     testlarge_DPRlatitude_NS[where(large_DPRlatitude_NS le -999.0)]=!Values.F_NAN
     testlarge_DPRlongitude_MS[where(large_DPRlongitude_MS le -999.0)]=!Values.F_NAN
     testlarge_DPRlongitude_NS[where(large_DPRlongitude_NS le -999.0)]=!Values.F_NAN

     for kk=0, total_elevangle-1 do begin
       large_xindex_MS[*,kk]=fix((large_longitude_MS[*,kk]-Lon0)/Spacing_lon)
       large_yindex_MS[*,kk]=fix((large_latitude_MS[*,kk]-Lat0)/Spacing_lat)
       large_xgrid_MS[*,kk]=xgrid[large_xindex_MS[*,kk]]
       large_ygrid_MS[*,kk]=ygrid[large_yindex_MS[*,kk]]

       large_xindex_NS[*,kk]=fix((large_longitude_NS[*,kk]-Lon0)/Spacing_lon)
       large_yindex_NS[*,kk]=fix((large_latitude_NS[*,kk]-Lat0)/Spacing_lat)
       large_xgrid_NS[*,kk]=xgrid[large_xindex_NS[*,kk]]
       large_ygrid_NS[*,kk]=ygrid[large_yindex_NS[*,kk]]
     endfor ;kk the number of elevations

     ;To make sure the negative values for the grids are not included
     large_xgrid_MS[where(large_xgrid_MS lt 0.0)]=!Values.F_NAN;-999.9
     large_ygrid_MS[where(large_ygrid_MS lt 0.0)]=!Values.F_NAN;-999.9
     large_xgrid_NS[where(large_xgrid_NS lt 0.0)]=!Values.F_NAN;-999.9
     large_ygrid_NS[where(large_ygrid_NS lt 0.0)]=!Values.F_NAN;-999.9

     ;These don't need to be in a loop, since they are only a function of lat and lon
     ;Need to be careful of -999.9 values being converted to actual numbers (i.e., -841.57882)
     ;So setting all negative x and y values equal to -999.9 since we only need values >=0.0:
     large_DPR_xindex_MS=fix((large_DPRlongitude_MS-Lon0)/Spacing_lon)
     large_DPR_yindex_MS=fix((large_DPRlatitude_MS-Lat0)/Spacing_lat)
     large_DPR_xgrid_MS=xgrid[large_DPR_xindex_MS]
     large_DPR_ygrid_MS=ygrid[large_DPR_yindex_MS]
     large_DPR_xgrid_MS[where(large_DPR_xgrid_MS lt 0.0)]=!Values.F_NAN;-999.99999
     large_DPR_ygrid_MS[where(large_DPR_ygrid_MS lt 0.0)]=!Values.F_NAN;-999.99999

     large_DPR_xindex_NS=fix((large_DPRlongitude_NS-Lon0)/Spacing_lon)
     large_DPR_yindex_NS=fix((large_DPRlatitude_NS-Lat0)/Spacing_lat)
     large_DPR_xgrid_NS=xgrid[large_DPR_xindex_NS]
     large_DPR_ygrid_NS=ygrid[large_DPR_yindex_NS]
     large_DPR_xgrid_NS[where(large_DPR_xgrid_NS lt 0.0)]=!Values.F_NAN;-999.99999
     large_DPR_ygrid_NS[where(large_DPR_ygrid_NS lt 0.0)]=!Values.F_NAN;-999.99999

     help, large_xgrid_MS, large_ygrid_MS, large_xgrid_NS, large_xgrid_NS, large_DPR_xgrid_MS, large_DPR_ygrid_MS, $
	   large_DPR_xgrid_NS, large_DPR_ygrid_NS

     ;This was just to check whether we fall within the correct lat and lon bins
     print, 'min(testlarge_latitude_MS), max(testlarge_latitude_MS), min(testlarge_latitude_NS), max(testlarge_latitude_NS)'
     print, min(testlarge_latitude_MS,/NaN), max(testlarge_latitude_MS,/NaN), min(testlarge_latitude_NS,/NaN), $
     		max(testlarge_latitude_NS,/NaN)
     print, 'min(testlarge_longitude_MS), max(testlarge_longitude_MS), min(testlarge_longitude_NS), max(testlarge_longitude_NS)'
     print, min(testlarge_longitude_MS,/NaN), max(testlarge_longitude_MS,/NaN), min(testlarge_longitude_NS,/NaN), $
     		max(testlarge_longitude_NS,/NaN)

     print, 'min(testlarge_DPRlatitude_MS), max(testlarge_DPRlatitude_MS), min(testlarge_DPRlatitude_NS), max(testlarge_DPRlatitude_NS)'
     print, min(testlarge_DPRlatitude_MS,/NaN), max(testlarge_DPRlatitude_MS,/NaN), min(testlarge_DPRlatitude_NS,/NaN), $
		 max(testlarge_DPRlatitude_NS,/NaN)
     print, 'min(testlarge_DPRlongitude_MS), max(testlarge_DPRlongitude_MS), min(testlarg_DPRlongitude_NS), max(testlarg_DPRlongitude_NS)'
     print, min(testlarge_DPRlongitude_MS,/NaN), max(testlarge_DPRlongitude_MS,/NaN), min(testlarge_DPRlongitude_NS,/NaN), $
		 max(testlarge_DPRlongitude_NS,/NaN)

     print, 'The following grid values exist in this orbit:'
     print, 'min(large_xgrid_MS), max(large_xgrid_MS), min(large_xgrid_NS), max(large_xgrid_NS)'
     print, min(large_xgrid_MS,/NaN), max(large_xgrid_MS,/NaN), min(large_xgrid_NS,/NaN), max(large_xgrid_NS,/NaN)
     print, 'min(large_ygrid_MS), max(large_ygrid_MS), min(large_ygrid_NS), max(large_ygrid_NS)'
     print, min(large_ygrid_MS,/NaN), max(large_ygrid_MS,/NaN), min(large_ygrid_NS,/NaN), max(large_ygrid_NS,/NaN)
     print, 'min(large_DPR_xgrid_MS), max(large_DPR_xgrid_MS), min(large_DPR_xgrid_NS), max(large_DPR_xgrid_NS)'
     print, min(large_DPR_xgrid_MS,/NaN), max(large_DPR_xgrid_MS,/NaN), min(large_DPR_xgrid_NS,/NaN), max(large_DPR_xgrid_NS,/NaN)
     print, 'min(large_DPR_ygrid_MS), max(large_DPR_ygrid_MS), min(large_DPR_ygrid_NS), max(large_DPR_ygrid_NS)'
     print, min(large_DPR_ygrid_MS,/NaN), max(large_DPR_ygrid_MS,/NaN), min(large_DPR_ygrid_NS,/NaN), max(large_DPR_ygrid_NS,/NaN)

     ;Now you have to create the gridded arrays into which the "large_" variables will be saved based on x, y and z locations.
     print, ''
     print, 'The following part of the script is for the MS variables only:'
     test_CONUS_MS=where(min(large_xgrid_MS) ge 0.0 and max(large_xgrid_MS) lt 7325.0 and $
          min(large_ygrid_MS) ge 0.0 and max(large_ygrid_MS) lt 3875.0)

     print, '******'
     if (test_CONUS_MS lt 0) then print, 'The first IF statement was not passed: The orbit values fall outside the CONUS grid'
     print, ''
     ;This if statement is important since there is no need to carry on with the script otherwise:
     if (min(large_xgrid_MS) ge 0.0 or max(large_xgrid_MS) lt 7325.0 and $
	 min(large_ygrid_MS) ge 0.0 or max(large_ygrid_MS) lt 3875.0) then begin

       nr_xgrid=n_elements(xgrid)
       nr_ygrid=n_elements(ygrid)
       nr_zgrid=n_elements(zgrid)

       ;Creating the gridded arrays for the MS (matched scan) swaths:
       grid_latitude_MS=fltarr(nr_xgrid,nr_ygrid,nr_zgrid) & grid_latitude_MS[*,*,*]=mvf
       grid_longitude_MS=fltarr(nr_xgrid,nr_ygrid,nr_zgrid) & grid_longitude_MS[*,*,*]=mvf
       grid_topHeight_MS_MSL=fltarr(nr_xgrid,nr_ygrid,nr_zgrid) & grid_topHeight_MS_MSL[*,*,*]=mvf ;MSL
       grid_bottomHeight_MS_MSL=fltarr(nr_xgrid,nr_ygrid,nr_zgrid) & grid_bottomHeight_MS_MSL[*,*,*]=mvf ;MSL
       grid_topHeight_MS=fltarr(nr_xgrid,nr_ygrid,nr_zgrid) & grid_topHeight_MS[*,*,*]=mvf ;AGL
       grid_bottomHeight_MS=fltarr(nr_xgrid,nr_ygrid,nr_zgrid) & grid_bottomHeight_MS[*,*,*]=mvf ;AGL
       grid_GR_HID_MS=intarr(total_hidim,nr_xgrid,nr_ygrid,nr_zgrid) & grid_GR_HID_MS[*,*,*,*]=mvi
       grid_GR_Z_MS=fltarr(nr_xgrid,nr_ygrid,nr_zgrid) & grid_GR_Z_MS[*,*,*]=mvf
       grid_GR_Z_StdDev_MS=fltarr(nr_xgrid,nr_ygrid,nr_zgrid) & grid_GR_Z_StdDev_MS[*,*,*]=mvf
       grid_GR_Z_Max_MS=fltarr(nr_xgrid,nr_ygrid,nr_zgrid) & grid_GR_Z_Max_MS[*,*,*]=mvf
       grid_GR_Zdr_MS=fltarr(nr_xgrid,nr_ygrid,nr_zgrid) & grid_GR_Zdr_MS[*,*,*]=mvf
       grid_GR_Zdr_StdDev_MS=fltarr(nr_xgrid,nr_ygrid,nr_zgrid) & grid_GR_Zdr_StdDev_MS[*,*,*]=mvf
       grid_GR_Zdr_Max_MS=fltarr(nr_xgrid,nr_ygrid,nr_zgrid) & grid_GR_Zdr_Max_MS[*,*,*]=mvf
       grid_GR_Kdp_MS=fltarr(nr_xgrid,nr_ygrid,nr_zgrid) & grid_GR_Kdp_MS[*,*,*]=mvf
       grid_GR_Kdp_StdDev_MS=fltarr(nr_xgrid,nr_ygrid,nr_zgrid) & grid_GR_Kdp_StdDev_MS[*,*,*]=mvf
       grid_GR_Kdp_Max_MS=fltarr(nr_xgrid,nr_ygrid,nr_zgrid) & grid_GR_Kdp_Max_MS[*,*,*]=mvf
       grid_GR_RHOhv_MS=fltarr(nr_xgrid,nr_ygrid,nr_zgrid) & grid_GR_RHOhv_MS[*,*,*]=mvf
       grid_GR_RHOhv_StdDev_MS=fltarr(nr_xgrid,nr_ygrid,nr_zgrid) & grid_GR_RHOhv_StdDev_MS[*,*,*]=mvf
       grid_GR_RHOhv_Max_MS=fltarr(nr_xgrid,nr_ygrid,nr_zgrid) & grid_GR_RHOhv_Max_MS[*,*,*]=mvf
       grid_GR_RC_rainrate_MS=fltarr(nr_xgrid,nr_ygrid,nr_zgrid) & grid_GR_RC_rainrate_MS[*,*,*]=mvf
       grid_GR_RC_rainrate_StdDev_MS=fltarr(nr_xgrid,nr_ygrid,nr_zgrid) & grid_GR_RC_rainrate_StdDev_MS[*,*,*]=mvf
       grid_GR_RC_rainrate_Max_MS=fltarr(nr_xgrid,nr_ygrid,nr_zgrid) & grid_GR_RC_rainrate_Max_MS[*,*,*]=mvf
       grid_GR_RP_rainrate_MS=fltarr(nr_xgrid,nr_ygrid,nr_zgrid) & grid_GR_RP_rainrate_MS[*,*,*]=mvf
       grid_GR_RP_rainrate_StdDev_MS=fltarr(nr_xgrid,nr_ygrid,nr_zgrid) & grid_GR_RP_rainrate_StdDev_MS[*,*,*]=mvf
       grid_GR_RP_rainrate_Max_MS=fltarr(nr_xgrid,nr_ygrid,nr_zgrid) & grid_GR_RP_rainrate_Max_MS[*,*,*]=mvf
       grid_GR_RR_rainrate_MS=fltarr(nr_xgrid,nr_ygrid,nr_zgrid) & grid_GR_RR_rainrate_MS[*,*,*]=mvf
       grid_GR_RR_rainrate_StdDev_MS=fltarr(nr_xgrid,nr_ygrid,nr_zgrid) & grid_GR_RR_rainrate_StdDev_MS[*,*,*]=mvf
       grid_GR_RR_rainrate_Max_MS=fltarr(nr_xgrid,nr_ygrid,nr_zgrid) & grid_GR_RR_rainrate_Max_MS[*,*,*]=mvf
       grid_GR_Dzero_MS=fltarr(nr_xgrid,nr_ygrid,nr_zgrid) & grid_GR_Dzero_MS[*,*,*]=mvf
       grid_GR_Dzero_StdDev_MS=fltarr(nr_xgrid,nr_ygrid,nr_zgrid) & grid_GR_Dzero_StdDev_MS[*,*,*]=mvf
       grid_GR_Dzero_Max_MS=fltarr(nr_xgrid,nr_ygrid,nr_zgrid) & grid_GR_Dzero_Max_MS[*,*,*]=mvf
       grid_GR_Nw_MS=fltarr(nr_xgrid,nr_ygrid,nr_zgrid) & grid_GR_Nw_MS[*,*,*]=mvf
       grid_GR_Nw_StdDev_MS=fltarr(nr_xgrid,nr_ygrid,nr_zgrid) & grid_GR_Nw_StdDev_MS[*,*,*]=mvf
       grid_GR_Nw_Max_MS=fltarr(nr_xgrid,nr_ygrid,nr_zgrid) & grid_GR_Nw_Max_MS[*,*,*]=mvf
       grid_GR_Dm_MS=fltarr(nr_xgrid,nr_ygrid,nr_zgrid) & grid_GR_Dm_MS[*,*,*]=mvf
       grid_GR_Dm_StdDev_MS=fltarr(nr_xgrid,nr_ygrid,nr_zgrid) & grid_GR_Dm_StdDev_MS[*,*,*]=mvf
       grid_GR_Dm_Max_MS=fltarr(nr_xgrid,nr_ygrid,nr_zgrid) & grid_GR_Dm_Max_MS[*,*,*]=mvf
       grid_GR_N2_MS=fltarr(nr_xgrid,nr_ygrid,nr_zgrid) & grid_GR_N2_MS[*,*,*]=mvf
       grid_GR_N2_StdDev_MS=fltarr(nr_xgrid,nr_ygrid,nr_zgrid) & grid_GR_N2_StdDev_MS[*,*,*]=mvf
       grid_GR_N2_Max_MS=fltarr(nr_xgrid,nr_ygrid,nr_zgrid) & grid_GR_N2_Max_MS[*,*,*]=mvf
       grid_GR_blockage_MS=fltarr(nr_xgrid,nr_ygrid,nr_zgrid) & grid_GR_blockage_MS[*,*,*]=mvf
       grid_n_gr_z_rejected_MS=intarr(nr_xgrid,nr_ygrid,nr_zgrid) & grid_n_gr_z_rejected_MS[*,*,*]=mvi
       grid_n_gr_zdr_rejected_MS=intarr(nr_xgrid,nr_ygrid,nr_zgrid) & grid_n_gr_zdr_rejected_MS[*,*,*]=mvi
       grid_n_gr_kdp_rejected_MS=intarr(nr_xgrid,nr_ygrid,nr_zgrid) & grid_n_gr_kdp_rejected_MS[*,*,*]=mvi
       grid_n_gr_rhohv_rejected_MS=intarr(nr_xgrid,nr_ygrid,nr_zgrid) & grid_n_gr_rhohv_rejected_MS[*,*,*]=mvi
       grid_n_gr_rc_rejected_MS=intarr(nr_xgrid,nr_ygrid,nr_zgrid) & grid_n_gr_rc_rejected_MS[*,*,*]=mvi
       grid_n_gr_rp_rejected_MS=intarr(nr_xgrid,nr_ygrid,nr_zgrid) & grid_n_gr_rp_rejected_MS[*,*,*]=mvi
       grid_n_gr_rr_rejected_MS=intarr(nr_xgrid,nr_ygrid,nr_zgrid) & grid_n_gr_rr_rejected_MS[*,*,*]=mvi
       grid_n_gr_hid_rejected_MS=intarr(nr_xgrid,nr_ygrid,nr_zgrid) & grid_n_gr_hid_rejected_MS[*,*,*]=mvi
       grid_n_gr_dzero_rejected_MS=intarr(nr_xgrid,nr_ygrid,nr_zgrid) & grid_n_gr_dzero_rejected_MS[*,*,*]=mvi
       grid_n_gr_nw_rejected_MS=intarr(nr_xgrid,nr_ygrid,nr_zgrid) & grid_n_gr_nw_rejected_MS[*,*,*]=mvi
       grid_n_gr_expected_MS=intarr(nr_xgrid,nr_ygrid,nr_zgrid) & grid_n_gr_expected_MS[*,*,*]=mvi
       grid_precipTotPSDparamHigh_MS=fltarr(nr_xgrid,nr_ygrid,nr_zgrid) & grid_precipTotPSDparamHigh_MS[*,*,*]=mvf
       grid_precipTotRate_MS=fltarr(nr_xgrid,nr_ygrid,nr_zgrid) & grid_precipTotRate_MS[*,*,*]=mvf
       grid_precipTotWaterCont_MS=fltarr(nr_xgrid,nr_ygrid,nr_zgrid) & grid_precipTotWaterCont_MS[*,*,*]=mvf
       grid_n_precipTotPSDparamHigh_rejected_MS=intarr(nr_xgrid,nr_ygrid,nr_zgrid) & grid_n_precipTotPSDparamHigh_rejected_MS[*,*,*]=mvi
       grid_n_precipTotRate_rejected_MS=intarr(nr_xgrid,nr_ygrid,nr_zgrid) & grid_n_precipTotRate_rejected_MS[*,*,*]=mvi
       grid_n_precipTotWaterCont_rejected_MS=intarr(nr_xgrid,nr_ygrid,nr_zgrid) & grid_n_precipTotWaterCont_rejected_MS[*,*,*]=mvi
       grid_precipTotPSDparamLow_MS=fltarr(total_nPSDlo,nr_xgrid,nr_ygrid,nr_zgrid) & grid_precipTotPSDparamLow_MS[*,*,*,*]=mvf
       grid_n_precipTotPSDparamLow_rejected_MS=intarr(total_nPSDlo, nr_xgrid,nr_ygrid,nr_zgrid) 
          grid_n_precipTotPSDparamLow_rejected_MS[*,*,*,*]=mvi
       grid_clutterStatus_MS=intarr(total_nKuKa,nr_xgrid,nr_ygrid,nr_zgrid) & grid_clutterStatus_MS[*,*,*,*]=mvi
       grid_correctedReflectFactor_MS=fltarr(total_nKuKa,nr_xgrid,nr_ygrid,nr_zgrid) & grid_correctedReflectFactor_MS[*,*,*,*]=mvf
       grid_n_correctedReflectFactor_rejected_MS=intarr(total_nKuKa,nr_xgrid,nr_ygrid,nr_zgrid)
          grid_n_correctedReflectFactor_rejected_MS[*,*,*,*]=mvi
       grid_n_dpr_expected_MS=intarr(total_nKuKa,nr_xgrid,nr_ygrid,nr_zgrid) & grid_n_dpr_expected_MS[*,*,*,*]=mvi
       grid_phaseBinNodes_MS=intarr(total_nPhsBnN,nr_xgrid,nr_ygrid) & grid_phaseBinNodes_MS[*,*,*]=mvi 
       grid_ellipsoidBinOffset_MS=fltarr(total_nKuKa,nr_xgrid,nr_ygrid) & grid_ellipsoidBinOffset_MS[*,*,*]=mvf
       grid_lowestClutterFreeBin_MS=intarr(total_nKuKa,nr_xgrid,nr_ygrid) & grid_lowestClutterFreeBin_MS[*,*,*]=mvi
       grid_precipitationFlag_MS=intarr(total_nKuKa,nr_xgrid,nr_ygrid) & grid_precipitationFlag_MS[*,*,*]=mvi
       grid_surfaceRangeBin_MS=intarr(total_nKuKa,nr_xgrid,nr_ygrid) & grid_surfaceRangeBin_MS[*,*,*]=mvi
       grid_pia_MS=fltarr(total_nKuKa,nr_xgrid,nr_ygrid) & grid_pia_MS[*,*,*]=mvf
       grid_stormTopAltitude_MS=fltarr(total_nKuKa,nr_xgrid,nr_ygrid) & grid_stormTopAltitude_MS [*,*,*]=mvf
       grid_precipitationType_MS=lonarr(nr_xgrid,nr_ygrid) & grid_precipitationType_MS[*,*]=mvi 
       grid_surfPrecipTotRate_MS=fltarr(nr_xgrid,nr_ygrid) & grid_surfPrecipTotRate_MS[*,*]=mvf 
       grid_surfaceElevation_MS=fltarr(nr_xgrid,nr_ygrid) & grid_surfaceElevation_MS[*,*]=mvf 
       grid_zeroDegAltitude_MS=fltarr(nr_xgrid,nr_ygrid) & grid_zeroDegAltitude_MS[*,*]=mvf 
       grid_zeroDegBin_MS=intarr(nr_xgrid,nr_ygrid) & grid_zeroDegBin_MS[*,*]=mvi
       grid_surfaceType_MS=lonarr(nr_xgrid,nr_ygrid) & grid_surfaceType_MS[*,*]=mvi 
       grid_DPRlatitude_MS=fltarr(nr_xgrid,nr_ygrid) & grid_DPRlatitude_MS[*,*]=mvf 
       grid_DPRlongitude_MS=fltarr(nr_xgrid,nr_ygrid) & grid_DPRlongitude_MS[*,*]=mvf 
       grid_scanNum_MS=intarr(nr_xgrid,nr_ygrid) & grid_scanNum_MS[*,*]=mvi 
       grid_rayNum_MS=intarr(nr_xgrid,nr_ygrid) & grid_rayNum_MS[*,*]=mvi 
       grid_n_gr_dm_rejected_MS=intarr(nr_xgrid,nr_ygrid,nr_zgrid) & grid_n_gr_dm_rejected_MS[*,*,*]=mvi
       grid_n_gr_n2_rejected_MS=intarr(nr_xgrid,nr_ygrid,nr_zgrid) & grid_n_gr_n2_rejected_MS[*,*,*]=mvi

       ;This part is to try and reduce the loop sizes, since the loops are huge!
       ;You need to repeat this 17 (can't do it in a loop since the index, ncols and col and row 
       ;changes EVERY time...
       ;For the MS fields:
       ;For 2.0 to 3.0 km:
       index_0_MS=where(large_bottomHeight_MS_MSL ge 2.0 and large_bottomHeight_MS_MSL lt 3.0)
       s_0_MS=size(large_bottomHeight_MS_MSL) & ncol_0_MS=s_0_MS(1)
       col_0_MS=index_0_MS MOD ncol_0_MS  ;This gives array nr of total_fpdim_MS for where statement
       row_0_MS=index_0_MS/ncol_0_MS ;This gives the elevation angle for the where statement 
       countcol0_MS=n_elements(col_0_MS)
       ;For 3.0 to 4.0 km:
       index_1_MS=where(large_bottomHeight_MS_MSL ge 3.0 and large_bottomHeight_MS_MSL lt 4.0)
       s_1_MS=size(large_bottomHeight_MS_MSL) & ncol_1_MS=s_1_MS(1)
       col_1_MS=index_1_MS MOD ncol_1_MS & row_1_MS=index_1_MS/ncol_1_MS
       countcol1_MS=n_elements(col_1_MS)
       ;For 4.0 to 5.0 km:
       index_2_MS=where(large_bottomHeight_MS_MSL ge 4.0 and large_bottomHeight_MS_MSL lt 5.0)
       s_2_MS=size(large_bottomHeight_MS_MSL) & ncol_2_MS=s_2_MS(1)
       col_2_MS=index_2_MS MOD ncol_2_MS & row_2_MS=index_2_MS/ncol_2_MS
       countcol2_MS=n_elements(col_2_MS)
       ;For 5.0 to 6.0 km:
       index_3_MS=where(large_bottomHeight_MS_MSL ge 5.0 and large_bottomHeight_MS_MSL lt 6.0)
       s_3_MS=size(large_bottomHeight_MS_MSL) & ncol_3_MS=s_3_MS(1)
       col_3_MS=index_3_MS MOD ncol_3_MS & row_3_MS=index_3_MS/ncol_3_MS
       countcol3_MS=n_elements(col_3_MS)
       ;For 6.0 to 7.0 km:
       index_4_MS=where(large_bottomHeight_MS_MSL ge 6.0 and large_bottomHeight_MS_MSL lt 7.0)
       s_4_MS=size(large_bottomHeight_MS_MSL) & ncol_4_MS=s_4_MS(1)
       col_4_MS=index_4_MS MOD ncol_4_MS & row_4_MS=index_4_MS/ncol_4_MS
       countcol4_MS=n_elements(col_4_MS)
       ;For 7.0 to 8.0 km:
       index_5_MS=where(large_bottomHeight_MS_MSL ge 7.0 and large_bottomHeight_MS_MSL lt 8.0)
       s_5_MS=size(large_bottomHeight_MS_MSL) & ncol_5_MS=s_5_MS(1)
       col_5_MS=index_5_MS MOD ncol_5_MS & row_5_MS=index_5_MS/ncol_5_MS
       countcol5_MS=n_elements(col_5_MS)
       ;For 8.0 to 9.0 km:
       index_6_MS=where(large_bottomHeight_MS_MSL ge 8.0 and large_bottomHeight_MS_MSL lt 9.0)
       s_6_MS=size(large_bottomHeight_MS_MSL) & ncol_6_MS=s_6_MS(1)
       col_6_MS=index_6_MS MOD ncol_6_MS & row_6_MS=index_6_MS/ncol_6_MS
       countcol6_MS=n_elements(col_6_MS)
       ;For 9.0 to 10.0 km:
       index_7_MS=where(large_bottomHeight_MS_MSL ge 9.0 and large_bottomHeight_MS_MSL lt 10.0)
       s_7_MS=size(large_bottomHeight_MS_MSL) & ncol_7_MS=s_7_MS(1)
       col_7_MS=index_7_MS MOD ncol_7_MS & row_7_MS=index_7_MS/ncol_7_MS
       countcol7_MS=n_elements(col_7_MS)
       ;For 10.0 to 11.0 km:
       index_8_MS=where(large_bottomHeight_MS_MSL ge 10.0 and large_bottomHeight_MS_MSL lt 11.0)
       s_8_MS=size(large_bottomHeight_MS_MSL) & ncol_8_MS=s_8_MS(1)
       col_8_MS=index_8_MS MOD ncol_8_MS & row_8_MS=index_8_MS/ncol_8_MS
       countcol8_MS=n_elements(col_8_MS)
       ;For 11.0 to 12.0 km:
       index_9_MS=where(large_bottomHeight_MS_MSL ge 11.0 and large_bottomHeight_MS_MSL lt 12.0)
       s_9_MS=size(large_bottomHeight_MS_MSL) & ncol_9_MS=s_9_MS(1)
       col_9_MS=index_9_MS MOD ncol_9_MS & row_9_MS=index_9_MS/ncol_9_MS
       countcol9_MS=n_elements(col_9_MS)
       ;For 12.0 to 13.0 km:
       index_10_MS=where(large_bottomHeight_MS_MSL ge 12.0 and large_bottomHeight_MS_MSL lt 13.0)
       s_10_MS=size(large_bottomHeight_MS_MSL) & ncol_10_MS=s_10_MS(1)
       col_10_MS=index_10_MS MOD ncol_10_MS & row_10_MS=index_10_MS/ncol_10_MS
       countcol10_MS=n_elements(col_10_MS)
       ;For 13.0 to 14.0 km:
       index_11_MS=where(large_bottomHeight_MS_MSL ge 13.0 and large_bottomHeight_MS_MSL lt 14.0)
       s_11_MS=size(large_bottomHeight_MS_MSL) & ncol_11_MS=s_11_MS(1)
       col_11_MS=index_11_MS MOD ncol_11_MS & row_11_MS=index_11_MS/ncol_11_MS
       countcol11_MS=n_elements(col_11_MS)
       ;For 14.0 to 15.0 km:
       index_12_MS=where(large_bottomHeight_MS_MSL ge 14.0 and large_bottomHeight_MS_MSL lt 15.0)
       s_12_MS=size(large_bottomHeight_MS_MSL) & ncol_12_MS=s_12_MS(1)
       col_12_MS=index_12_MS MOD ncol_12_MS & row_12_MS=index_12_MS/ncol_12_MS
       countcol12_MS=n_elements(col_12_MS)
       ;For 15.0 to 16.0 km:
       index_13_MS=where(large_bottomHeight_MS_MSL ge 15.0 and large_bottomHeight_MS_MSL lt 16.0)
       s_13_MS=size(large_bottomHeight_MS_MSL) & ncol_13_MS=s_13_MS(1)
       col_13_MS=index_13_MS MOD ncol_13_MS & row_13_MS=index_13_MS/ncol_13_MS
       countcol13_MS=n_elements(col_13_MS)
       ;For 16.0 to 17.0 km:
       index_14_MS=where(large_bottomHeight_MS_MSL ge 16.0 and large_bottomHeight_MS_MSL lt 17.0)
       s_14_MS=size(large_bottomHeight_MS_MSL) & ncol_14_MS=s_14_MS(1)
       col_14_MS=index_14_MS MOD ncol_14_MS & row_14_MS=index_14_MS/ncol_14_MS
       countcol14_MS=n_elements(col_14_MS)
       ;For 17.0 to 18.0 km:
       index_15_MS=where(large_bottomHeight_MS_MSL ge 17.0 and large_bottomHeight_MS_MSL lt 18.0)
       s_15_MS=size(large_bottomHeight_MS_MSL) & ncol_15_MS=s_15_MS(1)
       col_15_MS=index_15_MS MOD ncol_15_MS & row_15_MS=index_15_MS/ncol_15_MS
       countcol15_MS=n_elements(col_15_MS)
       ;For 18.0 to 19 km
       index_16_MS=where(large_bottomHeight_MS_MSL ge 18.0 and large_bottomHeight_MS_MSL lt 19.0)
       s_16_MS=size(large_bottomHeight_MS_MSL) & ncol_16_MS=s_16_MS(1)
       col_16_MS=index_16_MS MOD ncol_16_MS & row_16_MS=index_16_MS/ncol_16_MS
       countcol16_MS=n_elements(col_16_MS)

       help, col_0_MS,col_1_MS,col_2_MS,col_3_MS,col_4_MS,col_5_MS,col_6_MS,col_7_MS,col_8_MS
       help, col_9_MS,col_10_MS,col_11_MS,col_12_MS,col_13_MS,col_14_MS,col_15_MS,col_16_MS
       test_max_MS=[countcol0_MS,countcol1_MS,countcol2_MS,countcol3_MS,countcol4_MS,countcol5_MS,countcol6_MS, $
		   countcol7_MS,countcol8_MS,countcol9_MS,countcol10_MS,countcol11_MS,countcol12_MS,countcol13_MS, $
		   countcol14_MS,countcol15_MS,countcol16_MS]
       max_row_MS=max(test_max_MS)
       print, 'max_row: ', max_row_MS

       ;Create an array for the col and row values (but use the max_row value, since the nr_elements vary!).
       col_MS=intarr(max_row_MS,17) & col_MS[*,*]=-1 ;Can't make it zero or NaN, because zero means something later...
       col_MS[0:test_max_MS[0]-1,0]=col_0_MS & col_MS[0:test_max_MS[1]-1,1]=col_1_MS & col_MS[0:test_max_MS[2]-1,2]=col_2_MS
       col_MS[0:test_max_MS[3]-1,3]=col_3_MS & col_MS[0:test_max_MS[4]-1,4]=col_4_MS & col_MS[0:test_max_MS[5]-1,5]=col_5_MS
       col_MS[0:test_max_MS[6]-1,6]=col_6_MS & col_MS[0:test_max_MS[7]-1,7]=col_7_MS & col_MS[0:test_max_MS[8]-1,8]=col_8_MS
       col_MS[0:test_max_MS[9]-1,9]=col_9_MS & col_MS[0:test_max_MS[10]-1,10]=col_10_MS & col_MS[0:test_max_MS[11]-1,11]=col_11_MS
       col_MS[0:test_max_MS[12]-1,12]=col_12_MS & col_MS[0:test_max_MS[13]-1,13]=col_13_MS & col_MS[0:test_max_MS[14]-1,14]=col_14_MS
       col_MS[0:test_max_MS[15]-1,15]=col_15_MS & col_MS[0:test_max_MS[16]-1,16]=col_16_MS 

       row_MS=intarr(max_row_MS,17) & row_MS[*,*]=-1 ;Can't make it zero or NaN, because zero means something later...
       row_MS[0:test_max_MS[0]-1,0]=row_0_MS & row_MS[0:test_max_MS[1]-1,1]=row_1_MS & row_MS[0:test_max_MS[2]-1,2]=row_2_MS
       row_MS[0:test_max_MS[3]-1,3]=row_3_MS & row_MS[0:test_max_MS[4]-1,4]=row_4_MS & row_MS[0:test_max_MS[5]-1,5]=row_5_MS
       row_MS[0:test_max_MS[6]-1,6]=row_6_MS & row_MS[0:test_max_MS[7]-1,7]=row_7_MS & row_MS[0:test_max_MS[8]-1,8]=row_8_MS
       row_MS[0:test_max_MS[9]-1,9]=row_9_MS & row_MS[0:test_max_MS[10]-1,10]=row_10_MS & row_MS[0:test_max_MS[11]-1,11]=row_11_MS
       row_MS[0:test_max_MS[12]-1,12]=row_12_MS & row_MS[0:test_max_MS[13]-1,13]=row_13_MS & row_MS[0:test_max_MS[14]-1,14]=row_14_MS
       row_MS[0:test_max_MS[15]-1,15]=row_15_MS & row_MS[0:test_max_MS[16]-1,16]=row_16_MS

       ;The next loops take the -1 and NaN "values" into account when obtaining the HIDs/whichever variables
       ;for a specific xgrid and ygrid value:
       for ll=0, nr_zgrid-1 do begin ;array(17)
         print, ''
         print, '****This is for the MS variables****:'
         print, 'The following is for altitude  ', zgrid[ll], '  km MSL and nr_zgrid (i.e., ll) : ', ll

	 ;Doing it this way to ensure we don't run the loop if there's no data other than "missing" values
	 if long(total(col_MS[*,ll])) lt 0 then print, 'There is no information at this altitude for this orbit'
           for mm=0, nr_ygrid-2 do begin ;array(776)
	     for nn=0, nr_xgrid-2 do begin ;array(1466)

	      ;Do the MS conversions here:
	      ;This is for the variables that are a function of elevationAngle (actually altitude). 
	      if long(total(col_MS[*,ll])) gt 0 then begin ;Again, to not run when there is no data... 
                 alt0_grid_MS=where(large_xgrid_MS[col_MS[*,ll],row_MS[*,ll]] ge xgrid[nn] and $
	         large_xgrid_MS[col_MS[*,ll],row_MS[*,ll]] lt xgrid[nn+1] and $
	         large_ygrid_MS[col_MS[*,ll],row_MS[*,ll]] ge ygrid[mm] and $
                 large_ygrid_MS[col_MS[*,ll],row_MS[*,ll]] lt ygrid[mm+1] and $
	         col_MS[*,ll] ge 0, count0_MS);NB: You need the "col_MS" statement too otherwise NaN values are used...

                 if count0_MS gt 0 then begin
 		    print, 'This is for altitude  ', zgrid[ll], '  km MSL and ll', ll
                    print, 'Count of alt0_grid (xgrid, ygrid, zgrid), count0 =    ', alt0_grid_MS, count0_MS
                    print, 'xgrid[nn], ygrid[mm] = ', xgrid[nn], ygrid[mm]

                    ;The following is for the conversions:
		    lat_MS_0=fltarr(count0_MS)
                    lon_MS_0=fltarr(count0_MS)
		    topH_MSL_MS_0=fltarr(count0_MS)
		    topH_MS_0=fltarr(count0_MS)
                    botH_MSL_MS_0=fltarr(count0_MS)
                    botH_MS_0=fltarr(count0_MS)

                    HID_MS_0=intarr(count0_MS,15)
                    Z_MS_0=fltarr(count0_MS)
                    Z_StdDev_MS_0=fltarr(count0_MS)
                    Z_Max_MS_0=fltarr(count0_MS)
                    Zdr_MS_0=fltarr(count0_MS)
                    Zdr_StdDev_MS_0=fltarr(count0_MS)
                    Zdr_Max_MS_0=fltarr(count0_MS)
                    Kdp_MS_0=fltarr(count0_MS)
                    Kdp_StdDev_MS_0=fltarr(count0_MS)
                    Kdp_Max_MS_0=fltarr(count0_MS)
                    RHOhv_MS_0=fltarr(count0_MS)
                    RHOhv_StdDev_MS_0=fltarr(count0_MS)
                    RHOhv_Max_MS_0=fltarr(count0_MS)
                    RC_rainrate_MS_0=fltarr(count0_MS)
                    RC_rainrate_StdDev_MS_0=fltarr(count0_MS)
                    RC_rainrate_Max_MS_0=fltarr(count0_MS)
                    RP_rainrate_MS_0=fltarr(count0_MS)
                    RP_rainrate_StdDev_MS_0=fltarr(count0_MS)
                    RP_rainrate_Max_MS_0=fltarr(count0_MS)
                    RR_rainrate_MS_0=fltarr(count0_MS)
                    RR_rainrate_StdDev_MS_0=fltarr(count0_MS)
                    RR_rainrate_Max_MS_0=fltarr(count0_MS)
                    Dzero_MS_0=fltarr(count0_MS)
                    Dzero_StdDev_MS_0=fltarr(count0_MS)
                    Dzero_Max_MS_0=fltarr(count0_MS)
                    Nw_MS_0=fltarr(count0_MS)
                    Nw_StdDev_MS_0=fltarr(count0_MS)
                    Nw_Max_MS_0=fltarr(count0_MS)
                    Dm_MS_0=fltarr(count0_MS)
                    Dm_StdDev_MS_0=fltarr(count0_MS)
                    Dm_Max_MS_0=fltarr(count0_MS)
                    N2_MS_0=fltarr(count0_MS)
                    N2_StdDev_MS_0=fltarr(count0_MS)
                    N2_Max_MS_0=fltarr(count0_MS)
                    blockage_MS_0=fltarr(count0_MS)
                    n_z_rejected_MS_0=intarr(count0_MS)
                    n_zdr_rejected_MS_0=intarr(count0_MS)
                    n_kdp_rejected_MS_0=intarr(count0_MS)
                    n_rhohv_rejected_MS_0=intarr(count0_MS)
                    n_rc_rejected_MS_0=intarr(count0_MS)
                    n_rp_rejected_MS_0=intarr(count0_MS)
                    n_rr_rejected_MS_0=intarr(count0_MS)
                    n_hid_rejected_MS_0=intarr(count0_MS)
                    n_dzero_rejected_MS_0=intarr(count0_MS)
                    n_nw_rejected_MS_0=intarr(count0_MS)
                    n_expected_MS_0=intarr(count0_MS)
                    precipTotPSDparamHigh_MS_0=fltarr(count0_MS)
                    precipTotRate_MS_0=fltarr(count0_MS)
                    precipTotWaterCont_MS_0=fltarr(count0_MS)
                    n_precipTotPSDparamHigh_rejected_MS_0=intarr(count0_MS)
                    n_precipTotRate_rejected_MS_0=intarr(count0_MS)
                    n_precipTotWaterCont_rejected_MS_0=intarr(count0_MS)
		    n_gr_dm_rejected_MS_0=intarr(count0_MS) 
                    n_gr_n2_rejected_MS_0=intarr(count0_MS)
                    
                    precipTotPSDparamLow_MS_0=fltarr(2, count0_MS) ;**Function of nPSDlo as well
		    n_precipTotPSDparamLow_rejected_MS_0=intarr(2,count0_MS) ;**Function of nPSDlo as well
		    clutterStatus_MS_0=intarr(2,count0_MS) ;**Function of nKuKa as well
		    correctedReflectFactor_MS_0=fltarr(2,count0_MS) ;**Function of nKuKa as well
		    n_correctedReflectFactor_rejected_MS_0=intarr(2,count0_MS) ;**Function of nKuKa as well
		    n_dpr_expected_MS_0=intarr(2,count0_MS) ;**Function of nKuKa as well

                    for ss=0, count0_MS-1 do begin

		    ;This prints out the actual x and y values of each pixel, so don't want to delete!
                    ;print, 'large_xgrid_MS[col_MS[ll][alt0_grid_MS]], large_ygrid_MS[col_MS[ll][alt0_grid_MS]]:'
                    ;print, large_xgrid_MS[col_MS[alt0_grid_MS[ss],ll]], large_ygrid_MS[col_MS[alt0_grid_MS[ss],ll]]
                    ;print, 'large_GR_HID_MS[*,col_MS[ll][alt0_grid_MS],row_MS[ll][alt0_grid_MS]]:'
                    ;print, large_GR_HID_MS[*,col_MS[alt0_grid_MS[ss],ll],row_MS[alt0_grid_MS[ss],ll]]

		    ;This is where we find all the values that occur in each grid box for each variable:
                    lat_MS_0[ss]=large_latitude_MS[col_MS[alt0_grid_MS[ss],ll],row_MS[alt0_grid_MS[ss],ll]]
                    lon_MS_0[ss]=large_longitude_MS[col_MS[alt0_grid_MS[ss],ll],row_MS[alt0_grid_MS[ss],ll]]
                    topH_MSL_MS_0[ss]=large_topHeight_MS_MSL[col_MS[alt0_grid_MS[ss],ll],row_MS[alt0_grid_MS[ss],ll]] ;MSL
                    topH_MS_0[ss]=large_topHeight_MS[col_MS[alt0_grid_MS[ss],ll],row_MS[alt0_grid_MS[ss],ll]] ;AGL
                    botH_MSL_MS_0[ss]=large_bottomHeight_MS_MSL[col_MS[alt0_grid_MS[ss],ll],row_MS[alt0_grid_MS[ss],ll]] ;MSL
                    botH_MS_0[ss]=large_bottomHeight_MS[col_MS[alt0_grid_MS[ss],ll],row_MS[alt0_grid_MS[ss],ll]] ;AGL

                    HID_MS_0[ss,*]=large_GR_HID_MS[*,col_MS[alt0_grid_MS[ss],ll],row_MS[alt0_grid_MS[ss],ll]]
                    Z_MS_0[ss]=large_GR_Z_MS[col_MS[alt0_grid_MS[ss],ll],row_MS[alt0_grid_MS[ss],ll]]

		    Z_StdDev_MS_0[ss]=large_GR_Z_StdDev_MS[col_MS[alt0_grid_MS[ss],ll],row_MS[alt0_grid_MS[ss],ll]]
                    Z_Max_MS_0[ss]=large_GR_Z_Max_MS[col_MS[alt0_grid_MS[ss],ll],row_MS[alt0_grid_MS[ss],ll]]
                    Zdr_MS_0[ss]=large_GR_Zdr_MS[col_MS[alt0_grid_MS[ss],ll],row_MS[alt0_grid_MS[ss],ll]]
                    Zdr_StdDev_MS_0[ss]=large_GR_Zdr_StdDev_MS[col_MS[alt0_grid_MS[ss],ll],row_MS[alt0_grid_MS[ss],ll]]
                    Zdr_Max_MS_0[ss]=large_GR_Zdr_Max_MS[col_MS[alt0_grid_MS[ss],ll],row_MS[alt0_grid_MS[ss],ll]]
                    Kdp_MS_0[ss]=large_GR_Kdp_MS[col_MS[alt0_grid_MS[ss],ll],row_MS[alt0_grid_MS[ss],ll]]
                    Kdp_StdDev_MS_0[ss]=large_GR_Kdp_StdDev_MS[col_MS[alt0_grid_MS[ss],ll],row_MS[alt0_grid_MS[ss],ll]]
                    Kdp_Max_MS_0[ss]=large_GR_Kdp_Max_MS[col_MS[alt0_grid_MS[ss],ll],row_MS[alt0_grid_MS[ss],ll]]
                    RHOhv_MS_0[ss]=large_GR_RHOhv_MS[col_MS[alt0_grid_MS[ss],ll],row_MS[alt0_grid_MS[ss],ll]]
                    RHOhv_StdDev_MS_0[ss]=large_GR_RHOhv_StdDev_MS[col_MS[alt0_grid_MS[ss],ll],row_MS[alt0_grid_MS[ss],ll]]
                    RHOhv_Max_MS_0[ss]=large_GR_RHOhv_Max_MS[col_MS[alt0_grid_MS[ss],ll],row_MS[alt0_grid_MS[ss],ll]]
                    RC_rainrate_MS_0[ss]=large_GR_RC_rainrate_MS[col_MS[alt0_grid_MS[ss],ll],row_MS[alt0_grid_MS[ss],ll]]
                    RC_rainrate_StdDev_MS_0[ss]=large_GR_RC_rainrate_StdDev_MS[col_MS[alt0_grid_MS[ss],ll],row_MS[alt0_grid_MS[ss],ll]]
                    RC_rainrate_Max_MS_0[ss]=large_GR_RC_rainrate_Max_MS[col_MS[alt0_grid_MS[ss],ll],row_MS[alt0_grid_MS[ss],ll]]
                    RP_rainrate_MS_0[ss]=large_GR_RP_rainrate_MS[col_MS[alt0_grid_MS[ss],ll],row_MS[alt0_grid_MS[ss],ll]]
                    RP_rainrate_StdDev_MS_0[ss]=large_GR_RP_rainrate_StdDev_MS[col_MS[alt0_grid_MS[ss],ll],row_MS[alt0_grid_MS[ss],ll]]
                    RP_rainrate_Max_MS_0[ss]=large_GR_RP_rainrate_Max_MS[col_MS[alt0_grid_MS[ss],ll],row_MS[alt0_grid_MS[ss],ll]]
                    RR_rainrate_MS_0[ss]=large_GR_RR_rainrate_MS[col_MS[alt0_grid_MS[ss],ll],row_MS[alt0_grid_MS[ss],ll]]
                    RR_rainrate_StdDev_MS_0[ss]=large_GR_RR_rainrate_StdDev_MS[col_MS[alt0_grid_MS[ss],ll],row_MS[alt0_grid_MS[ss],ll]]
                    RR_rainrate_Max_MS_0[ss]=large_GR_RR_rainrate_Max_MS[col_MS[alt0_grid_MS[ss],ll],row_MS[alt0_grid_MS[ss],ll]]
                    Dzero_MS_0[ss]=large_GR_Dzero_MS[col_MS[alt0_grid_MS[ss],ll],row_MS[alt0_grid_MS[ss],ll]]
                    Dzero_StdDev_MS_0[ss]=large_GR_Dzero_StdDev_MS[col_MS[alt0_grid_MS[ss],ll],row_MS[alt0_grid_MS[ss],ll]]
                    Dzero_Max_MS_0[ss]=large_GR_Dzero_Max_MS[col_MS[alt0_grid_MS[ss],ll],row_MS[alt0_grid_MS[ss],ll]]
                    Nw_MS_0[ss]=large_GR_Nw_MS[col_MS[alt0_grid_MS[ss],ll],row_MS[alt0_grid_MS[ss],ll]]
                    Nw_StdDev_MS_0[ss]=large_GR_Nw_StdDev_MS[col_MS[alt0_grid_MS[ss],ll],row_MS[alt0_grid_MS[ss],ll]]
                    Nw_Max_MS_0[ss]=large_GR_Nw_Max_MS[col_MS[alt0_grid_MS[ss],ll],row_MS[alt0_grid_MS[ss],ll]]
                    Dm_MS_0[ss]=large_GR_Dm_MS[col_MS[alt0_grid_MS[ss],ll],row_MS[alt0_grid_MS[ss],ll]]
                    Dm_StdDev_MS_0[ss]=large_GR_Dm_StdDev_MS[col_MS[alt0_grid_MS[ss],ll],row_MS[alt0_grid_MS[ss],ll]]
                    Dm_Max_MS_0[ss]=large_GR_Dm_Max_MS[col_MS[alt0_grid_MS[ss],ll],row_MS[alt0_grid_MS[ss],ll]]
                    N2_MS_0[ss]=large_GR_N2_MS[col_MS[alt0_grid_MS[ss],ll],row_MS[alt0_grid_MS[ss],ll]]
                    N2_StdDev_MS_0[ss]=large_GR_N2_StdDev_MS[col_MS[alt0_grid_MS[ss],ll],row_MS[alt0_grid_MS[ss],ll]]
                    N2_Max_MS_0[ss]=large_GR_N2_Max_MS[col_MS[alt0_grid_MS[ss],ll],row_MS[alt0_grid_MS[ss],ll]]
                    blockage_MS_0[ss]=large_GR_blockage_MS[col_MS[alt0_grid_MS[ss],ll],row_MS[alt0_grid_MS[ss],ll]]
                    n_z_rejected_MS_0[ss]= large_n_gr_z_rejected_MS[col_MS[alt0_grid_MS[ss],ll],row_MS[alt0_grid_MS[ss],ll]]
                    n_zdr_rejected_MS_0[ss]=large_n_gr_zdr_rejected_MS[col_MS[alt0_grid_MS[ss],ll],row_MS[alt0_grid_MS[ss],ll]]
                    n_kdp_rejected_MS_0[ss]=large_n_gr_kdp_rejected_MS[col_MS[alt0_grid_MS[ss],ll],row_MS[alt0_grid_MS[ss],ll]]
                    n_rhohv_rejected_MS_0[ss]=large_n_gr_rhohv_rejected_MS[col_MS[alt0_grid_MS[ss],ll],row_MS[alt0_grid_MS[ss],ll]]
                    n_rc_rejected_MS_0[ss]=large_n_gr_rc_rejected_MS[col_MS[alt0_grid_MS[ss],ll],row_MS[alt0_grid_MS[ss],ll]]
                    n_rp_rejected_MS_0[ss]=large_n_gr_rp_rejected_MS[col_MS[alt0_grid_MS[ss],ll],row_MS[alt0_grid_MS[ss],ll]]
                    n_rr_rejected_MS_0[ss]=large_n_gr_rr_rejected_MS[col_MS[alt0_grid_MS[ss],ll],row_MS[alt0_grid_MS[ss],ll]]
                    n_hid_rejected_MS_0[ss]=large_n_gr_hid_rejected_MS[col_MS[alt0_grid_MS[ss],ll],row_MS[alt0_grid_MS[ss],ll]]
                    n_dzero_rejected_MS_0[ss]=large_n_gr_dzero_rejected_MS[col_MS[alt0_grid_MS[ss],ll],row_MS[alt0_grid_MS[ss],ll]]
                    n_nw_rejected_MS_0[ss]=large_n_gr_nw_rejected_MS[col_MS[alt0_grid_MS[ss],ll],row_MS[alt0_grid_MS[ss],ll]]
                    n_expected_MS_0[ss]=large_n_gr_expected_MS[col_MS[alt0_grid_MS[ss],ll],row_MS[alt0_grid_MS[ss],ll]]
                    precipTotPSDparamHigh_MS_0[ss]=large_precipTotPSDparamHigh_MS[col_MS[alt0_grid_MS[ss],ll],row_MS[alt0_grid_MS[ss],ll]]
                    precipTotRate_MS_0[ss]=large_precipTotRate_MS[col_MS[alt0_grid_MS[ss],ll],row_MS[alt0_grid_MS[ss],ll]]
                    precipTotWaterCont_MS_0[ss]=large_precipTotWaterCont_MS[col_MS[alt0_grid_MS[ss],ll],row_MS[alt0_grid_MS[ss],ll]]
                    n_precipTotPSDparamHigh_rejected_MS_0[ss]=large_n_precipTotPSDparamHigh_rejected_MS[col_MS[alt0_grid_MS[ss],ll],row_MS[alt0_grid_MS[ss],ll]]
                    n_precipTotRate_rejected_MS_0[ss]=large_n_precipTotRate_rejected_MS[col_MS[alt0_grid_MS[ss],ll],row_MS[alt0_grid_MS[ss],ll]]
                    n_precipTotWaterCont_rejected_MS_0[ss]=large_n_precipTotWaterCont_rejected_MS[col_MS[alt0_grid_MS[ss],ll],row_MS[alt0_grid_MS[ss],ll]]
    	            n_gr_dm_rejected_MS_0[ss]=true_large_n_gr_dm_rejected_MS[col_MS[alt0_grid_MS[ss],ll],row_MS[alt0_grid_MS[ss],ll]]
                    n_gr_n2_rejected_MS_0[ss]=true_large_n_gr_n2_rejected_MS[col_MS[alt0_grid_MS[ss],ll],row_MS[alt0_grid_MS[ss],ll]]

   	            ;These variables are a function of nPSDlo and nKuKa as well:
                    precipTotPSDparamLow_MS_0[*,ss]=large_precipTotPSDparamLow_MS[*,col_MS[alt0_grid_MS[ss],ll],row_MS[alt0_grid_MS[ss],ll]]
	            n_precipTotPSDparamLow_rejected_MS_0[*,ss]=large_n_precipTotPSDparamLow_rejected_MS[*,col_MS[alt0_grid_MS[ss],ll],row_MS[alt0_grid_MS[ss],ll]]
	            clutterStatus_MS_0[*,ss]=large_clutterStatus_MS[*,col_MS[alt0_grid_MS[ss],ll],row_MS[alt0_grid_MS[ss],ll]]
	            correctedReflectFactor_MS_0[*,ss]=large_correctedReflectFactor_MS[*,col_MS[alt0_grid_MS[ss],ll],row_MS[alt0_grid_MS[ss],ll]]
	            n_correctedReflectFactor_rejected_MS_0[*,ss]=large_n_correctedReflectFactor_rejected_MS[*,col_MS[alt0_grid_MS[ss],ll],row_MS[alt0_grid_MS[ss],ll]]
	            n_dpr_expected_MS_0[*,ss]=large_n_dpr_expected_MS[*,col_MS[alt0_grid_MS[ss],ll],row_MS[alt0_grid_MS[ss],ll]]

                 endfor ;ss the nr of elements in the where statement

		 ;This is where we find the LOCATION of the MEDIAN Z value to use for all the rest of the _MS variables:		  
	         print, 'Z_MS_0: ', Z_MS_0
		 test_Z_MS=Z_MS_0[where(Z_MS_0 gt 0.0, count_Z_MS_0)]
		 if count_Z_MS_0 ge 1 then median_Z_MS=median(test_Z_MS)
		 if count_Z_MS_0 lt 1 then median_Z_MS=mvf
		 if count_Z_MS_0 lt 1 then print, '**There are no reflectivity values >= 0.0 dBZ; Moving on to next grid point**'

		 if count_Z_MS_0 ge 1 then begin ;If there are no reflectivities > 0.0, then don't run the rest of the script!
		 print, 'count_Z_MS_0, Median Z MS: ', count_Z_MS_0,'  ',  median_Z_MS
	         grid_GR_Z_MS[nn,mm,ll]=median_Z_MS
			    
	         ;Since we don't want to save the HID if there are no actual Z values, this block for HID was moved to after the Z calculation:
                 ;We need the following statement to find the location of the actual Z value that we saved:
                 testmedZ=where(Z_MS_0 eq median_Z_MS) ;Will use this location for most other variables:
                 ;This works so I will use the LOCATION of the median(test_Z_MS) for the rest of the values

                 total_HID_MS_conc=intarr(15)
	         total_HID_MS_conc[0:14]=HID_MS_0[testmedZ, *] ;Using the location of MEDIAN Z_MS!
                 grid_GR_HID_MS[0:14,nn,mm,ll]=total_HID_MS_conc[0:14] ;Since we only want the 15 HIDs at one elevation

                 print, 'lat_MS_0: ', lat_MS_0
	         median_lat_MS=lat_MS_0[testmedZ]
	         print, 'median_lat_MS : ',  median_lat_MS
	         grid_latitude_MS[nn,mm,ll]=median_lat_MS

                 print, 'lon_MS_0: ', lon_MS_0
			    median_lon_MS=lon_MS_0[testmedZ]
                 print, 'median_lon_MS : ',  median_lon_MS
                 grid_longitude_MS[nn,mm,ll]=median_lon_MS

                 print, 'topH_MSL_MS_0: ', topH_MSL_MS_0
		 median_topH_MSL_MS=topH_MSL_MS_0[testmedZ]
		 print, 'median_topH_MSL_MS: ', median_topH_MSL_MS
		 grid_topHeight_MS_MSL[nn,mm,ll]=median_topH_MSL_MS

		 ;There is no need to print the rest of the information to the screen, so only printing the following:
		 print, '******'
		 print, 'It is obtaining the values for each x, y, z gridded location' 
		 print, 'for each variable in the gridded domain'
		 print, '******'

		 median_topH_MS=topH_MS_0[testmedZ]
                 grid_topHeight_MS[nn,mm,ll]=median_topH_MS
		 median_botH_MSL_MS=botH_MSL_MS_0[testmedZ]
                 grid_bottomHeight_MS_MSL[nn,mm,ll]=median_botH_MSL_MS
		 median_botH_MS=botH_MS_0[testmedZ]
                 grid_bottomHeight_MS[nn,mm,ll]=median_botH_MS
		 median_Z_StdDev_MS=Z_StdDev_MS_0[testmedZ]
		 grid_GR_Z_StdDev_MS[nn,mm,ll]=median_Z_StdDev_MS
		 median_Z_Max_MS=Z_Max_MS_0[testmedZ]
		 grid_GR_Z_Max_MS[nn,mm,ll]=median_Z_Max_MS
		 median_Zdr_MS=Zdr_MS_0[testmedZ]
                 grid_GR_Zdr_MS[nn,mm,ll]=median_Zdr_MS
		 median_Zdr_StdDev_MS=Zdr_StdDev_MS_0[testmedZ]
                 grid_GR_Zdr_StdDev_MS[nn,mm,ll]=median_Zdr_StdDev_MS
		 median_Zdr_Max_MS=Zdr_Max_MS_0[testmedZ]
                 grid_GR_Zdr_Max_MS[nn,mm,ll]=median_Zdr_Max_MS
		 median_Kdp_MS=Kdp_MS_0[testmedZ]
                 grid_GR_Kdp_MS[nn,mm,ll]=median_Kdp_MS
		 median_Kdp_StdDev_MS=Kdp_StdDev_MS_0[testmedZ]
                 grid_GR_Kdp_StdDev_MS[nn,mm,ll]=median_Kdp_StdDev_MS
		 median_Kdp_Max_MS=Kdp_Max_MS_0[testmedZ]
                 grid_GR_Kdp_Max_MS[nn,mm,ll]=median_Kdp_Max_MS
		 median_RHOhv_MS=RHOhv_MS_0[testmedZ]
                 grid_GR_RHOhv_MS[nn,mm,ll]=median_RHOhv_MS
		 median_RHOhv_StdDev_MS=RHOhv_StdDev_MS_0[testmedZ]
                 grid_GR_RHOhv_StdDev_MS[nn,mm,ll]=median_RHOhv_StdDev_MS
		 median_RHOhv_Max_MS=RHOhv_Max_MS_0[testmedZ]
                 grid_GR_RHOhv_Max_MS[nn,mm,ll]=median_RHOhv_Max_MS
		 median_RC_rainrate_MS=RC_rainrate_MS_0[testmedZ]
                 grid_GR_RC_rainrate_MS[nn,mm,ll]=median_RC_rainrate_MS
		 median_RC_rainrate_StdDev_MS=RC_rainrate_StdDev_MS_0[testmedZ]
                 grid_GR_RC_rainrate_StdDev_MS[nn,mm,ll]=median_RC_rainrate_StdDev_MS
		 median_RC_rainrate_Max_MS=RC_rainrate_Max_MS_0[testmedZ]
                 grid_GR_RC_rainrate_Max_MS[nn,mm,ll]=median_RC_rainrate_Max_MS
		 median_RP_rainrate_MS=RP_rainrate_MS_0[testmedZ]
                 grid_GR_RP_rainrate_MS[nn,mm,ll]=median_RP_rainrate_MS
		 median_RP_rainrate_StdDev_MS=RP_rainrate_StdDev_MS_0[testmedZ]
                 grid_GR_RP_rainrate_StdDev_MS[nn,mm,ll]=median_RP_rainrate_StdDev_MS
		 median_RP_rainrate_Max_MS=RP_rainrate_Max_MS_0[testmedZ]
                 grid_GR_RP_rainrate_Max_MS[nn,mm,ll]=median_RP_rainrate_Max_MS
		 median_RR_rainrate_MS=RR_rainrate_MS_0[testmedZ]
		 if median_RR_rainrate_MS lt 0.0 then median_RR_rainrate_MS=mvf
		 grid_GR_RR_rainrate_MS[nn,mm,ll]=median_RR_rainrate_MS
		 median_RR_rainrate_StdDev_MS=RR_rainrate_StdDev_MS_0[testmedZ]
		 if median_RR_rainrate_StdDev_MS lt 0.0 then median_RR_rainrate_StdDev_MS=mvf
		 grid_GR_RR_rainrate_StdDev_MS[nn,mm,ll]=median_RR_rainrate_StdDev_MS
		 median_RR_rainrate_Max_MS=RR_rainrate_Max_MS_0[testmedZ]
		 if median_RR_rainrate_Max_MS lt 0.0 then median_RR_rainrate_Max_MS=mvf
		 grid_GR_RR_rainrate_Max_MS[nn,mm,ll]=median_RR_rainrate_Max_MS
		 median_Dzero_MS=Dzero_MS_0[testmedZ]
                 grid_GR_Dzero_MS[nn,mm,ll]=median_Dzero_MS
		 median_Dzero_StdDev_MS=Dzero_StdDev_MS_0[testmedZ]
                 grid_GR_Dzero_StdDev_MS[nn,mm,ll]=median_Dzero_StdDev_MS
		 median_Dzero_Max_MS=Dzero_Max_MS_0[testmedZ]
                 grid_GR_Dzero_Max_MS[nn,mm,ll]=median_Dzero_Max_MS
		 median_Nw_MS=Nw_MS_0[testmedZ]
                 grid_GR_Nw_MS[nn,mm,ll]=median_Nw_MS
		 median_Nw_StdDev_MS=Nw_StdDev_MS_0[testmedZ]
                 grid_GR_Nw_StdDev_MS[nn,mm,ll]=median_Nw_StdDev_MS
		 median_Nw_Max_MS=Nw_Max_MS_0[testmedZ]
                 grid_GR_Nw_Max_MS[nn,mm,ll]=median_Nw_Max_MS
		 median_Dm_MS=Dm_MS_0[testmedZ]
                 grid_GR_Dm_MS[nn,mm,ll]=median_Dm_MS
		 median_Dm_StdDev_MS=Dm_StdDev_MS_0[testmedZ]
                 grid_GR_Dm_StdDev_MS[nn,mm,ll]=median_Dm_StdDev_MS
		 median_Dm_Max_MS=Dm_Max_MS_0[testmedZ]
                 grid_GR_Dm_Max_MS[nn,mm,ll]=median_Dm_Max_MS
		 median_N2_MS=N2_MS_0[testmedZ]
                 grid_GR_N2_MS[nn,mm,ll]=median_N2_MS
		 median_N2_StdDev_MS=N2_StdDev_MS_0[testmedZ]
                 grid_GR_N2_StdDev_MS[nn,mm,ll]=median_N2_StdDev_MS
	         median_N2_Max_MS=N2_Max_MS_0[testmedZ]
                 grid_GR_N2_Max_MS[nn,mm,ll]=median_N2_Max_MS
	         median_blockage_MS=blockage_MS_0[testmedZ]
                 grid_GR_blockage_MS[nn,mm,ll]=median_blockage_MS
	         median_n_z_rejected_MS=n_z_rejected_MS_0[testmedZ]
                 grid_n_gr_z_rejected_MS[nn,mm,ll]=median_n_z_rejected_MS
	         median_n_zdr_rejected_MS=n_zdr_rejected_MS_0[testmedZ]
                 grid_n_gr_zdr_rejected_MS[nn,mm,ll]=median_n_zdr_rejected_MS
	         median_n_kdp_rejected_MS=n_kdp_rejected_MS_0[testmedZ]
                 grid_n_gr_kdp_rejected_MS[nn,mm,ll]=median_n_kdp_rejected_MS
	         median_n_rhohv_rejected_MS=n_rhohv_rejected_MS_0[testmedZ]
                 grid_n_gr_rhohv_rejected_MS[nn,mm,ll]=median_n_rhohv_rejected_MS
	         median_n_rc_rejected_MS=n_rc_rejected_MS_0[testmedZ]
                 grid_n_gr_rc_rejected_MS[nn,mm,ll]=median_n_rc_rejected_MS
	         median_n_rp_rejected_MS=n_rp_rejected_MS_0[testmedZ]
                 grid_n_gr_rp_rejected_MS[nn,mm,ll]=median_n_rp_rejected_MS
	         median_n_rr_rejected_MS=n_rr_rejected_MS_0[testmedZ]
                 grid_n_gr_rr_rejected_MS[nn,mm,ll]=median_n_rr_rejected_MS
	         median_n_hid_rejected_MS=n_hid_rejected_MS_0[testmedZ]
                 grid_n_gr_hid_rejected_MS[nn,mm,ll]=median_n_hid_rejected_MS
	         median_n_dzero_rejected_MS=n_dzero_rejected_MS_0[testmedZ]
                 grid_n_gr_dzero_rejected_MS[nn,mm,ll]=median_n_dzero_rejected_MS
	         median_n_nw_rejected_MS=n_nw_rejected_MS_0[testmedZ]
                 grid_n_gr_nw_rejected_MS[nn,mm,ll]=median_n_nw_rejected_MS
	         median_n_expected_MS=n_expected_MS_0[testmedZ]
                 grid_n_gr_expected_MS[nn,mm,ll]=median_n_expected_MS
	         median_precipTotPSDparamHigh_MS=precipTotPSDparamHigh_MS_0[testmedZ]
                 grid_precipTotPSDparamHigh_MS[nn,mm,ll]=median_precipTotPSDparamHigh_MS
	         median_precipTotRate_MS=precipTotRate_MS_0[testmedZ]
                 grid_precipTotRate_MS[nn,mm,ll]=median_precipTotRate_MS
	         median_precipTotWaterCont_MS=precipTotWaterCont_MS_0[testmedZ]
                 grid_precipTotWaterCont_MS[nn,mm,ll]=median_precipTotWaterCont_MS
	         median_n_precipTotPSDparamHigh_rejected_MS=n_precipTotPSDparamHigh_rejected_MS_0[testmedZ]
                 grid_n_precipTotPSDparamHigh_rejected_MS[nn,mm,ll]=median_n_precipTotPSDparamHigh_rejected_MS
	         median_n_precipTotRate_rejected_MS=n_precipTotRate_rejected_MS_0[testmedZ]
                 grid_n_precipTotRate_rejected_MS[nn,mm,ll]=median_n_precipTotRate_rejected_MS
	         median_n_precipTotWaterCont_rejected_MS=n_precipTotWaterCont_rejected_MS_0[testmedZ]
                 grid_n_precipTotWaterCont_rejected_MS[nn,mm,ll]=median_n_precipTotWaterCont_rejected_MS
                 median_n_gr_dm_rejected_MS=n_gr_dm_rejected_MS_0[testmedZ]
                 grid_n_gr_dm_rejected_MS[nn,mm,ll]=median_n_gr_dm_rejected_MS
                 median_n_gr_n2_rejected_MS=n_gr_n2_rejected_MS_0[testmedZ]
                 grid_n_gr_n2_rejected_MS[nn,mm,ll]=median_n_gr_n2_rejected_MS

	        ;For the nKuKa and nPSDlow variables that are from 0 to 1 (2 elements):
	        for pp=0, 1 do begin
	          precipTotPSDparamLow_MS_1=precipTotPSDparamLow_MS_0[pp,*]
	          test_precipTotPSDparamLow_MS=precipTotPSDparamLow_MS_1[where(precipTotPSDparamLow_MS_1 gt -99.0, $
	    	    count_precipTotPSDparamLow_MS_0)]
	          median_precipTotPSDparamLow_MS=test_precipTotPSDparamLow_MS[testmedZ]
                  grid_precipTotPSDparamLow_MS[pp,nn,mm,ll]=median_precipTotPSDparamLow_MS

		  n_precipTotPSDparamLow_rejected_MS_1=n_precipTotPSDparamLow_rejected_MS_0[pp,*]
		  test_n_precipTotPSDparamLow_rejected_MS=n_precipTotPSDparamLow_rejected_MS_1[where(n_precipTotPSDparamLow_rejected_MS_1 gt $
		    -99.0, count_n_precipTotPSDparamLow_rejected_MS_0)]
		  median_n_precipTotPSDparamLow_rejected_MS=test_n_precipTotPSDparamLow_rejected_MS[testmedZ]
                  grid_n_precipTotPSDparamLow_rejected_MS[pp,nn,mm,ll]=median_n_precipTotPSDparamLow_rejected_MS

		  clutterStatus_MS_1=clutterStatus_MS_0[pp,*]
		  test_clutterStatus_MS=clutterStatus_MS_1[where(clutterStatus_MS_1 gt -99.0, count_clutterStatus_MS_0)]
		  median_clutterStatus_MS=test_clutterStatus_MS[testmedZ]
		  grid_clutterStatus_MS[pp,nn,mm,ll]=median_clutterStatus_MS

		  correctedReflectFactor_MS_1=correctedReflectFactor_MS_0[pp,*]
		  test_correctedReflectFactor_MS=correctedReflectFactor_MS_1[where(correctedReflectFactor_MS_1 gt -99.0, $
		    count_correctedReflectFactor_MS_0)]
		  median_correctedReflectFactor_MS=test_correctedReflectFactor_MS[testmedZ]
		  grid_correctedReflectFactor_MS[pp,nn,mm,ll]=median_correctedReflectFactor_MS

		  n_correctedReflectFactor_rejected_MS_1=n_correctedReflectFactor_rejected_MS_0[pp,*]
		  test_n_correctedReflectFactor_rejected_MS=n_correctedReflectFactor_rejected_MS_1[where(n_correctedReflectFactor_rejected_MS_1 gt $
		    -99.0, count_n_correctedReflectFactor_rejected_MS_0)]
		  median_n_correctedReflectFactor_rejected_MS=test_n_correctedReflectFactor_rejected_MS[testmedZ]
		  grid_n_correctedReflectFactor_rejected_MS[pp,nn,mm,ll]=median_n_correctedReflectFactor_rejected_MS

		  n_dpr_expected_MS_1=n_dpr_expected_MS_0[pp,*]
		  test_n_dpr_expected_MS=n_dpr_expected_MS_1[where(n_dpr_expected_MS_1 gt -99.0, count_n_dpr_expected_MS_0)]
		  median_n_dpr_expected_MS=test_n_dpr_expected_MS[testmedZ]
                  if median_n_dpr_expected_MS lt 0 then median_n_dpr_expected_MS=mvi
		  grid_n_dpr_expected_MS[pp,nn,mm,ll]=median_n_dpr_expected_MS
                endfor ;pp the nKuKa and nPSDlow variables that are from 0 to 1 (2 elements)

                ;Now to save the variables that are NOT a function of elevationAngle to the grid:
	        ;Note that even though the variables below are NOT a function of elevationAngle/Altitude, I decided to use the EXACT
	        ;same location as for the "testmedZ", which is location of the median reflectivity to keep everything consistent!

	        if ll eq 0 then begin ;This is so that ONLY the lowest zgrid (alt0_grid_MS) values are used:
 	          grid_phaseBinNodes_MS[*,nn,mm]=large_phaseBinNodes_MS[*,alt0_grid_MS[testmedZ]]
	          grid_ellipsoidBinOffset_MS[*,nn,mm]=large_ellipsoidBinOffset_MS[*,alt0_grid_MS[testmedZ]]
          	  grid_lowestClutterFreeBin_MS[*,nn,mm]=large_lowestClutterFreeBin_MS[*,alt0_grid_MS[testmedZ]]
	          grid_precipitationFlag_MS[*,nn,mm]=large_precipitationFlag_MS[*,alt0_grid_MS[testmedZ]]
	          grid_surfaceRangeBin_MS[*,nn,mm]=large_surfaceRangeBin_MS[*,alt0_grid_MS[testmedZ]]
	          if (large_pia_MS[0,alt0_grid_MS[testmedZ]] lt -99.0) then large_pia_MS[0,alt0_grid_MS[testmedZ]]=mvf
	          if (large_pia_MS[1,alt0_grid_MS[testmedZ]] lt -99.0) then large_pia_MS[1,alt0_grid_MS[testmedZ]]=mvf			     
	          grid_pia_MS[*,nn,mm]=large_pia_MS[*,alt0_grid_MS[testmedZ]]
	          if (large_stormTopAltitude_MS[0,alt0_grid_MS[testmedZ]] lt -99.0) then large_stormTopAltitude_MS[0,alt0_grid_MS[testmedZ]]=mvf
                  if (large_stormTopAltitude_MS[1,alt0_grid_MS[testmedZ]] lt -99.0) then large_stormTopAltitude_MS[1,alt0_grid_MS[testmedZ]]=mvf
	          grid_stormTopAltitude_MS[*,nn,mm]=large_stormTopAltitude_MS[*,alt0_grid_MS[testmedZ]]
	          grid_precipitationType_MS[nn,mm]=large_precipitationType_MS[alt0_grid_MS[testmedZ]]
	          ;IMPORTANT NOTE: PrecipitationType CAN be -1111, which means "No rain"
	          grid_surfPrecipTotRate_MS[nn,mm]=large_surfPrecipTotRate_MS[alt0_grid_MS[testmedZ]]
     	          grid_surfaceElevation_MS[nn,mm]=large_surfaceElevation_MS[alt0_grid_MS[testmedZ]]
	          grid_zeroDegAltitude_MS[nn,mm]=large_zeroDegAltitude_MS[alt0_grid_MS[testmedZ]]
	          grid_zeroDegBin_MS[nn,mm]=large_zeroDegBin_MS[alt0_grid_MS[testmedZ]]
	          grid_surfaceType_MS[nn,mm]=large_surfaceType_MS[alt0_grid_MS[testmedZ]]
	          grid_DPRlatitude_MS[nn,mm]=large_DPRlatitude_MS[alt0_grid_MS[testmedZ]]
	          grid_DPRlongitude_MS[nn,mm]=large_DPRlongitude_MS[alt0_grid_MS[testmedZ]]
	          grid_scanNum_MS[nn,mm]=large_scanNum_MS[alt0_grid_MS[testmedZ]]
	          grid_rayNum_MS[nn,mm]=large_rayNum_MS[alt0_grid_MS[testmedZ]]
	        endif ;ll = 0 for non-elevationAngle variables
		; if count0_MS gt 3 then stop  ;This is for testing purposes
     	        endif ;count_Z_MS_0 ge 1 If there's no real values for the median reflectivity
              endif ;count0_MS
            endif ;if total(col_MS[*,ll]) gt 0 then begin
          endfor ;nn nr_xgrid
        endfor ;mm nr_ygrid
      endfor ;ll nr_zgrid
     endif ;To test whether there are actually any values that fall within xgrid and ygrid!!

     grid_GR_minZref_MS=min(grid_GR_Z_MS[where(grid_GR_Z_MS ge 0.0)]) ;This is the MIN reflectivity for entire grid
     grid_GR_maxZref_MS=max(grid_GR_Z_MS[where(grid_GR_Z_MS ge 0.0)]) ;This is the MAX reflectivity for entire grid

     ;We need to reset the large_*_MS variables to reduce the memory:
     print, 'This is where the large_*MS variables are reset to zero!'
     large_latitude_MS=0 & large_longitude_MS=0 & large_xCorners_MS=0 & large_yCorners_MS=0
     large_topHeight_MS=0 & large_bottomHeight_MS=0 & large_topHeight_MS_MSL=0 & large_bottomHeight_MS_MSL=0
     large_GR_Z_MS=0 & large_GR_Z_StdDev_MS=0 & large_GR_Z_Max_MS=0 & large_GR_Zdr_MS=0 & large_GR_Zdr_StdDev_MS=0
     large_GR_Zdr_Max_MS=0 & large_GR_Kdp_MS=0 & large_GR_Kdp_StdDev_MS=0 & large_GR_Kdp_Max_MS=0
     large_GR_RHOhv_MS=0 & large_GR_RHOhv_StdDev_MS=0 & large_GR_RHOhv_Max_MS=0 & large_GR_RC_rainrate_MS=0
     large_GR_RC_rainrate_StdDev_MS=0 & large_GR_RC_rainrate_Max_MS=0 & large_GR_RP_rainrate_MS=0
     large_GR_RP_rainrate_StdDev_MS=0 & large_GR_RP_rainrate_Max_MS=0 & large_GR_RR_rainrate_MS=0
     large_GR_RR_rainrate_StdDev_MS=0 & large_GR_RR_rainrate_Max_MS=0 & large_GR_HID_MS=0 & large_GR_Dzero_MS=0
     large_GR_Dzero_StdDev_MS=0 & large_GR_Dzero_Max_MS=0 & large_GR_Nw_MS=0 & large_GR_Nw_StdDev_MS=0
     large_GR_Nw_Max_MS=0 & large_GR_Dm_MS=0 & large_GR_Dm_StdDev_MS=0 & large_GR_Dm_Max_MS=0
     large_GR_N2_MS=0 & large_GR_N2_StdDev_MS=0 & large_GR_N2_Max_MS=0 & large_GR_blockage_MS=0
     large_n_gr_z_rejected_MS=0 & large_n_gr_zdr_rejected_MS=0 & large_n_gr_kdp_rejected_MS=0
     large_n_gr_rhohv_rejected_MS=0 & large_n_gr_rc_rejected_MS=0 & large_n_gr_rp_rejected_MS=0
     large_n_gr_rr_rejected_MS=0 & large_n_gr_hid_rejected_MS=0 & large_n_gr_dzero_rejected_MS=0
     large_n_gr_nw_rejected_MS=0 & large_n_gr_dm_rejected_MS=0 & true_large_n_gr_dm_rejected_MS=0
     large_n_gr_n2_rejected_MS=0 & true_large_n_gr_n2_rejected_MS=0 & large_n_gr_expected_MS=0
     large_precipTotPSDparamHigh_MS=0 & large_precipTotPSDparamLow_MS=0 & large_precipTotRate_MS=0
     large_precipTotWaterCont_MS=0 & large_n_precipTotPSDparamHigh_rejected_MS=0 & large_n_precipTotPSDparamLow_rejected_MS=0
     large_n_precipTotRate_rejected_MS=0 & large_n_precipTotWaterCont_rejected_MS=0 & large_precipitationType_MS=0
     large_surfPrecipTotRate_MS=0 & large_surfaceElevation_MS=0 & large_zeroDegAltitude_MS=0
     large_zeroDegBin_MS=0 & large_surfaceType_MS=0 & large_phaseBinNodes_MS=0 & large_DPRlatitude_MS=0
     large_DPRlongitude_MS=0 & large_scanNum_MS=0 & large_rayNum_MS=0 & large_ellipsoidBinOffset_MS=0
     large_lowestClutterFreeBin_MS=0 & large_clutterStatus_MS=0 & large_precipitationFlag_MS=0
     large_surfaceRangeBin_MS=0 & large_correctedReflectFactor_MS=0 & large_pia_MS=0 & large_stormTopAltitude_MS=0
     large_n_correctedReflectFactor_rejected_MS=0 & large_n_dpr_expected_MS=0

     ;**************************************************************************
     ;The following are all the statements above, but for the NS swath here! 
     ;These variables will have their own if, lll, mmm, nnn, if, if, sss, loops!
     ;**************************************************************************
     print, '******'
     print, 'The following part of the script is for the NS variables only:'

     ;Now you have to create the gridded arrays into which the "large_" variables will be saved based on x, y and z locations...
     test_CONUS_NS=where(min(large_xgrid_NS) ge 0.0 and max(large_xgrid_NS) lt 7325.0 and $
          min(large_ygrid_NS) ge 0.0 and max(large_ygrid_NS) lt 3875.0)

     if (test_CONUS_NS lt 0) then print, 'The first IF statement was not passed: The orbit values fall outside the CONUS grid'
     print, ''
     ;This if statement is NB since there is no need to carry on with the script otherwise...
     if (min(large_xgrid_NS) ge 0.0 or max(large_xgrid_NS) lt 7325.0 and $
         min(large_ygrid_NS) ge 0.0 or max(large_ygrid_NS) lt 3875.0) then begin

         print, 'The first "IF" statement was passed:'
         print, 'if (large_xgrid_NS ge 0.0 and large_xgrid_NS lt 7325.0 and large_ygrid_NS ge 0.0'
         print, 'and large_ygrid_NS lt lt 3875.0) then begin'

         ;For the MS (matched scan) swaths:
         grid_latitude_NS=fltarr(nr_xgrid,nr_ygrid,nr_zgrid) & grid_latitude_NS[*,*,*]=mvf
         grid_longitude_NS=fltarr(nr_xgrid,nr_ygrid,nr_zgrid) & grid_longitude_NS[*,*,*]=mvf
         grid_topHeight_NS_MSL=fltarr(nr_xgrid,nr_ygrid,nr_zgrid) & grid_topHeight_NS_MSL[*,*,*]=mvf ;MSL
         grid_bottomHeight_NS_MSL=fltarr(nr_xgrid,nr_ygrid,nr_zgrid) & grid_bottomHeight_NS_MSL[*,*,*]=mvf ;MSL
         grid_topHeight_NS=fltarr(nr_xgrid,nr_ygrid,nr_zgrid) & grid_topHeight_NS[*,*,*]=mvf ;AGL
         grid_bottomHeight_NS=fltarr(nr_xgrid,nr_ygrid,nr_zgrid) & grid_bottomHeight_NS[*,*,*]=mvf ;AGL
         grid_GR_HID_NS=intarr(total_hidim,nr_xgrid,nr_ygrid,nr_zgrid) & grid_GR_HID_NS[*,*,*,*]=mvi
         grid_GR_Z_NS=fltarr(nr_xgrid,nr_ygrid,nr_zgrid) & grid_GR_Z_NS[*,*,*]=mvf
         grid_GR_Z_StdDev_NS=fltarr(nr_xgrid,nr_ygrid,nr_zgrid) & grid_GR_Z_StdDev_NS[*,*,*]=mvf
         grid_GR_Z_Max_NS=fltarr(nr_xgrid,nr_ygrid,nr_zgrid) & grid_GR_Z_Max_NS[*,*,*]=mvf
         grid_GR_Zdr_NS=fltarr(nr_xgrid,nr_ygrid,nr_zgrid) & grid_GR_Zdr_NS[*,*,*]=mvf
         grid_GR_Zdr_StdDev_NS=fltarr(nr_xgrid,nr_ygrid,nr_zgrid) & grid_GR_Zdr_StdDev_NS[*,*,*]=mvf
         grid_GR_Zdr_Max_NS=fltarr(nr_xgrid,nr_ygrid,nr_zgrid) & grid_GR_Zdr_Max_NS[*,*,*]=mvf
         grid_GR_Kdp_NS=fltarr(nr_xgrid,nr_ygrid,nr_zgrid) & grid_GR_Kdp_NS[*,*,*]=mvf
         grid_GR_Kdp_StdDev_NS=fltarr(nr_xgrid,nr_ygrid,nr_zgrid) & grid_GR_Kdp_StdDev_NS[*,*,*]=mvf
         grid_GR_Kdp_Max_NS=fltarr(nr_xgrid,nr_ygrid,nr_zgrid) & grid_GR_Kdp_Max_NS[*,*,*]=mvf
         grid_GR_RHOhv_NS=fltarr(nr_xgrid,nr_ygrid,nr_zgrid) & grid_GR_RHOhv_NS[*,*,*]=mvf
         grid_GR_RHOhv_StdDev_NS=fltarr(nr_xgrid,nr_ygrid,nr_zgrid) & grid_GR_RHOhv_StdDev_NS[*,*,*]=mvf
         grid_GR_RHOhv_Max_NS=fltarr(nr_xgrid,nr_ygrid,nr_zgrid) & grid_GR_RHOhv_Max_NS[*,*,*]=mvf
         grid_GR_RC_rainrate_NS=fltarr(nr_xgrid,nr_ygrid,nr_zgrid) & grid_GR_RC_rainrate_NS[*,*,*]=mvf
         grid_GR_RC_rainrate_StdDev_NS=fltarr(nr_xgrid,nr_ygrid,nr_zgrid) & grid_GR_RC_rainrate_StdDev_NS[*,*,*]=mvf
         grid_GR_RC_rainrate_Max_NS=fltarr(nr_xgrid,nr_ygrid,nr_zgrid) & grid_GR_RC_rainrate_Max_NS[*,*,*]=mvf
         grid_GR_RP_rainrate_NS=fltarr(nr_xgrid,nr_ygrid,nr_zgrid) & grid_GR_RP_rainrate_NS[*,*,*]=mvf
         grid_GR_RP_rainrate_StdDev_NS=fltarr(nr_xgrid,nr_ygrid,nr_zgrid) & grid_GR_RP_rainrate_StdDev_NS[*,*,*]=mvf
         grid_GR_RP_rainrate_Max_NS=fltarr(nr_xgrid,nr_ygrid,nr_zgrid) & grid_GR_RP_rainrate_Max_NS[*,*,*]=mvf
         grid_GR_RR_rainrate_NS=fltarr(nr_xgrid,nr_ygrid,nr_zgrid) & grid_GR_RR_rainrate_NS[*,*,*]=mvf
         grid_GR_RR_rainrate_StdDev_NS=fltarr(nr_xgrid,nr_ygrid,nr_zgrid) & grid_GR_RR_rainrate_StdDev_NS[*,*,*]=mvf
         grid_GR_RR_rainrate_Max_NS=fltarr(nr_xgrid,nr_ygrid,nr_zgrid) & grid_GR_RR_rainrate_Max_NS[*,*,*]=mvf
         grid_GR_Dzero_NS=fltarr(nr_xgrid,nr_ygrid,nr_zgrid) & grid_GR_Dzero_NS[*,*,*]=mvf
         grid_GR_Dzero_StdDev_NS=fltarr(nr_xgrid,nr_ygrid,nr_zgrid) & grid_GR_Dzero_StdDev_NS[*,*,*]=mvf
         grid_GR_Dzero_Max_NS=fltarr(nr_xgrid,nr_ygrid,nr_zgrid) & grid_GR_Dzero_Max_NS[*,*,*]=mvf
         grid_GR_Nw_NS=fltarr(nr_xgrid,nr_ygrid,nr_zgrid) & grid_GR_Nw_NS[*,*,*]=mvf
         grid_GR_Nw_StdDev_NS=fltarr(nr_xgrid,nr_ygrid,nr_zgrid) & grid_GR_Nw_StdDev_NS[*,*,*]=mvf
         grid_GR_Nw_Max_NS=fltarr(nr_xgrid,nr_ygrid,nr_zgrid) & grid_GR_Nw_Max_NS[*,*,*]=mvf
         grid_GR_Dm_NS=fltarr(nr_xgrid,nr_ygrid,nr_zgrid) & grid_GR_Dm_NS[*,*,*]=mvf
         grid_GR_Dm_StdDev_NS=fltarr(nr_xgrid,nr_ygrid,nr_zgrid) & grid_GR_Dm_StdDev_NS[*,*,*]=mvf
         grid_GR_Dm_Max_NS=fltarr(nr_xgrid,nr_ygrid,nr_zgrid) & grid_GR_Dm_Max_NS[*,*,*]=mvf
         grid_GR_N2_NS=fltarr(nr_xgrid,nr_ygrid,nr_zgrid) & grid_GR_N2_NS[*,*,*]=mvf
         grid_GR_N2_StdDev_NS=fltarr(nr_xgrid,nr_ygrid,nr_zgrid) & grid_GR_N2_StdDev_NS[*,*,*]=mvf
         grid_GR_N2_Max_NS=fltarr(nr_xgrid,nr_ygrid,nr_zgrid) & grid_GR_N2_Max_NS[*,*,*]=mvf
         grid_GR_blockage_NS=fltarr(nr_xgrid,nr_ygrid,nr_zgrid) & grid_GR_blockage_NS[*,*,*]=mvf
         grid_n_gr_z_rejected_NS=intarr(nr_xgrid,nr_ygrid,nr_zgrid) & grid_n_gr_z_rejected_NS[*,*,*]=mvi
         grid_n_gr_zdr_rejected_NS=intarr(nr_xgrid,nr_ygrid,nr_zgrid) & grid_n_gr_zdr_rejected_NS[*,*,*]=mvi
         grid_n_gr_kdp_rejected_NS=intarr(nr_xgrid,nr_ygrid,nr_zgrid) & grid_n_gr_kdp_rejected_NS[*,*,*]=mvi
         grid_n_gr_rhohv_rejected_NS=intarr(nr_xgrid,nr_ygrid,nr_zgrid) & grid_n_gr_rhohv_rejected_NS[*,*,*]=mvi
         grid_n_gr_rc_rejected_NS=intarr(nr_xgrid,nr_ygrid,nr_zgrid) & grid_n_gr_rc_rejected_NS[*,*,*]=mvi
         grid_n_gr_rp_rejected_NS=intarr(nr_xgrid,nr_ygrid,nr_zgrid) & grid_n_gr_rp_rejected_NS[*,*,*]=mvi
         grid_n_gr_rr_rejected_NS=intarr(nr_xgrid,nr_ygrid,nr_zgrid) & grid_n_gr_rr_rejected_NS[*,*,*]=mvi
         grid_n_gr_hid_rejected_NS=intarr(nr_xgrid,nr_ygrid,nr_zgrid) & grid_n_gr_hid_rejected_NS[*,*,*]=mvi
         grid_n_gr_dzero_rejected_NS=intarr(nr_xgrid,nr_ygrid,nr_zgrid) & grid_n_gr_dzero_rejected_NS[*,*,*]=mvi
         grid_n_gr_nw_rejected_NS=intarr(nr_xgrid,nr_ygrid,nr_zgrid) & grid_n_gr_nw_rejected_NS[*,*,*]=mvi
         grid_n_gr_expected_NS=intarr(nr_xgrid,nr_ygrid,nr_zgrid) & grid_n_gr_expected_NS[*,*,*]=mvi
         grid_precipTotPSDparamHigh_NS=fltarr(nr_xgrid,nr_ygrid,nr_zgrid) & grid_precipTotPSDparamHigh_NS[*,*,*]=mvf
         grid_precipTotRate_NS=fltarr(nr_xgrid,nr_ygrid,nr_zgrid) & grid_precipTotRate_NS[*,*,*]=mvf
         grid_precipTotWaterCont_NS=fltarr(nr_xgrid,nr_ygrid,nr_zgrid) & grid_precipTotWaterCont_NS[*,*,*]=mvf
         grid_n_precipTotPSDparamHigh_rejected_NS=intarr(nr_xgrid,nr_ygrid,nr_zgrid) & grid_n_precipTotPSDparamHigh_rejected_NS[*,*,*]=mvi
         grid_n_precipTotRate_rejected_NS=intarr(nr_xgrid,nr_ygrid,nr_zgrid) & grid_n_precipTotRate_rejected_NS[*,*,*]=mvi
         grid_n_precipTotWaterCont_rejected_NS=intarr(nr_xgrid,nr_ygrid,nr_zgrid) & grid_n_precipTotWaterCont_rejected_NS[*,*,*]=mvi

         grid_precipTotPSDparamLow_NS=fltarr(total_nPSDlo,nr_xgrid,nr_ygrid,nr_zgrid) & grid_precipTotPSDparamLow_NS[*,*,*,*]=mvf
         grid_n_precipTotPSDparamLow_rejected_NS=intarr(total_nPSDlo, nr_xgrid,nr_ygrid,nr_zgrid)
                grid_n_precipTotPSDparamLow_rejected_NS[*,*,*,*]=mvi
         grid_clutterStatus_NS=intarr(nr_xgrid,nr_ygrid,nr_zgrid) & grid_clutterStatus_NS[*,*,*]=mvi
         grid_correctedReflectFactor_NS=fltarr(nr_xgrid,nr_ygrid,nr_zgrid) & grid_correctedReflectFactor_NS[*,*,*]=mvf
         grid_n_correctedReflectFactor_rejected_NS=intarr(nr_xgrid,nr_ygrid,nr_zgrid)
                grid_n_correctedReflectFactor_rejected_NS[*,*,*]=mvi
         grid_n_dpr_expected_NS=intarr(nr_xgrid,nr_ygrid,nr_zgrid) & grid_n_dpr_expected_NS[*,*,*]=mvi

         grid_phaseBinNodes_NS=intarr(total_nPhsBnN,nr_xgrid,nr_ygrid) & grid_phaseBinNodes_NS[*,*,*]=mvi
         grid_ellipsoidBinOffset_NS=fltarr(nr_xgrid,nr_ygrid) & grid_ellipsoidBinOffset_NS[*,*]=mvf
         grid_lowestClutterFreeBin_NS=intarr(nr_xgrid,nr_ygrid) & grid_lowestClutterFreeBin_NS[*,*]=mvi
         grid_precipitationFlag_NS=intarr(nr_xgrid,nr_ygrid) & grid_precipitationFlag_NS[*,*]=mvi
         grid_surfaceRangeBin_NS=intarr(nr_xgrid,nr_ygrid) & grid_surfaceRangeBin_NS[*,*]=mvi
         grid_pia_NS=fltarr(nr_xgrid,nr_ygrid) & grid_pia_NS[*,*]=mvf
         grid_stormTopAltitude_NS=fltarr(nr_xgrid,nr_ygrid) & grid_stormTopAltitude_NS [*,*]=mvf

         grid_precipitationType_NS=lonarr(nr_xgrid,nr_ygrid) & grid_precipitationType_NS[*,*]=mvi
         grid_surfPrecipTotRate_NS=fltarr(nr_xgrid,nr_ygrid) & grid_surfPrecipTotRate_NS[*,*]=mvf
         grid_surfaceElevation_NS=fltarr(nr_xgrid,nr_ygrid) & grid_surfaceElevation_NS[*,*]=mvf
         grid_zeroDegAltitude_NS=fltarr(nr_xgrid,nr_ygrid) & grid_zeroDegAltitude_NS[*,*]=mvf
         grid_zeroDegBin_NS=intarr(nr_xgrid,nr_ygrid) & grid_zeroDegBin_NS[*,*]=mvi
         grid_surfaceType_NS=lonarr(nr_xgrid,nr_ygrid) & grid_surfaceType_NS[*,*]=mvi
         grid_DPRlatitude_NS=fltarr(nr_xgrid,nr_ygrid) & grid_DPRlatitude_NS[*,*]=mvf
         grid_DPRlongitude_NS=fltarr(nr_xgrid,nr_ygrid) & grid_DPRlongitude_NS[*,*]=mvf
         grid_scanNum_NS=intarr(nr_xgrid,nr_ygrid) & grid_scanNum_NS[*,*]=mvi
         grid_rayNum_NS=intarr(nr_xgrid,nr_ygrid) & grid_rayNum_NS[*,*]=mvi

         grid_n_gr_dm_rejected_NS=intarr(nr_xgrid,nr_ygrid,nr_zgrid) & grid_n_gr_dm_rejected_NS[*,*,*]=mvi
         grid_n_gr_n2_rejected_NS=intarr(nr_xgrid,nr_ygrid,nr_zgrid) & grid_n_gr_n2_rejected_NS[*,*,*]=mvi

         ;For the NS fields:
         ;For 2.0 to 3.0 km:
         index_0_NS=where(large_bottomHeight_NS_MSL ge 2.0 and large_bottomHeight_NS_MSL lt 3.0)
         s_0_NS=size(large_bottomHeight_NS_MSL) & ncol_0_NS=s_0_NS(1)
         col_0_NS=index_0_NS MOD ncol_0_NS  ;This gives array nr of total_fpdim_NS for where statement
         row_0_NS=index_0_NS/ncol_0_NS ;This gives the elevation angle for the where statement
         countcol0_NS=n_elements(col_0_NS)
         ;For 3.0 to 4.0 km:
         index_1_NS=where(large_bottomHeight_NS_MSL ge 3.0 and large_bottomHeight_NS_MSL lt 4.0)
         s_1_NS=size(large_bottomHeight_NS_MSL) & ncol_1_NS=s_1_NS(1)
         col_1_NS=index_1_NS MOD ncol_1_NS & row_1_NS=index_1_NS/ncol_1_NS
         countcol1_NS=n_elements(col_1_NS)
         ;For 4.0 to 5.0 km:
         index_2_NS=where(large_bottomHeight_NS_MSL ge 4.0 and large_bottomHeight_NS_MSL lt 5.0)
         s_2_NS=size(large_bottomHeight_NS_MSL) & ncol_2_NS=s_2_NS(1)
         col_2_NS=index_2_NS MOD ncol_2_NS & row_2_NS=index_2_NS/ncol_2_NS
         countcol2_NS=n_elements(col_2_NS)
         ;For 5.0 to 6.0 km:
         index_3_NS=where(large_bottomHeight_NS_MSL ge 5.0 and large_bottomHeight_NS_MSL lt 6.0)
         s_3_NS=size(large_bottomHeight_NS_MSL) & ncol_3_NS=s_3_NS(1)
         col_3_NS=index_3_NS MOD ncol_3_NS & row_3_NS=index_3_NS/ncol_3_NS
         countcol3_NS=n_elements(col_3_NS)
         ;For 6.0 to 7.0 km:
         index_4_NS=where(large_bottomHeight_NS_MSL ge 6.0 and large_bottomHeight_NS_MSL lt 7.0)
         s_4_NS=size(large_bottomHeight_NS_MSL) & ncol_4_NS=s_4_NS(1)
         col_4_NS=index_4_NS MOD ncol_4_NS & row_4_NS=index_4_NS/ncol_4_NS
         countcol4_NS=n_elements(col_4_NS)
         ;For 7.0 to 8.0 km:
         index_5_NS=where(large_bottomHeight_NS_MSL ge 7.0 and large_bottomHeight_NS_MSL lt 8.0)
         s_5_NS=size(large_bottomHeight_NS_MSL) & ncol_5_NS=s_5_NS(1)
         col_5_NS=index_5_NS MOD ncol_5_NS & row_5_NS=index_5_NS/ncol_5_NS
         countcol5_NS=n_elements(col_5_NS)
         ;For 8.0 to 9.0 km:
         index_6_NS=where(large_bottomHeight_NS_MSL ge 8.0 and large_bottomHeight_NS_MSL lt 9.0)
         s_6_NS=size(large_bottomHeight_NS_MSL) & ncol_6_NS=s_6_NS(1)
         col_6_NS=index_6_NS MOD ncol_6_NS & row_6_NS=index_6_NS/ncol_6_NS
         countcol6_NS=n_elements(col_6_NS)
         ;For 9.0 to 10.0 km:
         index_7_NS=where(large_bottomHeight_NS_MSL ge 9.0 and large_bottomHeight_NS_MSL lt 10.0)
         s_7_NS=size(large_bottomHeight_NS_MSL) & ncol_7_NS=s_7_NS(1)
         col_7_NS=index_7_NS MOD ncol_7_NS & row_7_NS=index_7_NS/ncol_7_NS
         countcol7_NS=n_elements(col_7_NS)
         ;For 10.0 to 11.0 km:
         index_8_NS=where(large_bottomHeight_NS_MSL ge 10.0 and large_bottomHeight_NS_MSL lt 11.0)
         s_8_NS=size(large_bottomHeight_NS_MSL) & ncol_8_NS=s_8_NS(1)
         col_8_NS=index_8_NS MOD ncol_8_NS & row_8_NS=index_8_NS/ncol_8_NS
         countcol8_NS=n_elements(col_8_NS)
         ;For 11.0 to 12.0 km:
         index_9_NS=where(large_bottomHeight_NS_MSL ge 11.0 and large_bottomHeight_NS_MSL lt 12.0)
         s_9_NS=size(large_bottomHeight_NS_MSL) & ncol_9_NS=s_9_NS(1)
         col_9_NS=index_9_NS MOD ncol_9_NS & row_9_NS=index_9_NS/ncol_9_NS
         countcol9_NS=n_elements(col_9_NS)
         ;For 12.0 to 13.0 km:
         index_10_NS=where(large_bottomHeight_NS_MSL ge 12.0 and large_bottomHeight_NS_MSL lt 13.0)
         s_10_NS=size(large_bottomHeight_NS_MSL) & ncol_10_NS=s_10_NS(1)
         col_10_NS=index_10_NS MOD ncol_10_NS & row_10_NS=index_10_NS/ncol_10_NS
         countcol10_NS=n_elements(col_10_NS)
         ;For 13.0 to 14.0 km:
         index_11_NS=where(large_bottomHeight_NS_MSL ge 13.0 and large_bottomHeight_NS_MSL lt 14.0)
         s_11_NS=size(large_bottomHeight_NS_MSL) & ncol_11_NS=s_11_NS(1)
         col_11_NS=index_11_NS MOD ncol_11_NS & row_11_NS=index_11_NS/ncol_11_NS
         countcol11_NS=n_elements(col_11_NS)
         ;For 14.0 to 15.0 km:
         index_12_NS=where(large_bottomHeight_NS_MSL ge 14.0 and large_bottomHeight_NS_MSL lt 15.0)
         s_12_NS=size(large_bottomHeight_NS_MSL) & ncol_12_NS=s_12_NS(1)
         col_12_NS=index_12_NS MOD ncol_12_NS & row_12_NS=index_12_NS/ncol_12_NS
         countcol12_NS=n_elements(col_12_NS)
         ;For 15.0 to 16.0 km:
         index_13_NS=where(large_bottomHeight_NS_MSL ge 15.0 and large_bottomHeight_NS_MSL lt 16.0)
         s_13_NS=size(large_bottomHeight_NS_MSL) & ncol_13_NS=s_13_NS(1)
         col_13_NS=index_13_NS MOD ncol_13_NS & row_13_NS=index_13_NS/ncol_13_NS
         countcol13_NS=n_elements(col_13_NS)
         ;For 16.0 to 17.0 km:
         index_14_NS=where(large_bottomHeight_NS_MSL ge 16.0 and large_bottomHeight_NS_MSL lt 17.0)
         s_14_NS=size(large_bottomHeight_NS_MSL) & ncol_14_NS=s_14_NS(1)
         col_14_NS=index_14_NS MOD ncol_14_NS & row_14_NS=index_14_NS/ncol_14_NS
         countcol14_NS=n_elements(col_14_NS)
         ;For 17.0 to 18.0 km:
         index_15_NS=where(large_bottomHeight_NS_MSL ge 17.0 and large_bottomHeight_NS_MSL lt 18.0)
         s_15_NS=size(large_bottomHeight_NS_MSL) & ncol_15_NS=s_15_NS(1)
         col_15_NS=index_15_NS MOD ncol_15_NS & row_15_NS=index_15_NS/ncol_15_NS
         countcol15_NS=n_elements(col_15_NS)
         ;For 18.0 to 19 km
         index_16_NS=where(large_bottomHeight_NS_MSL ge 18.0 and large_bottomHeight_NS_MSL lt 19.0)
         s_16_NS=size(large_bottomHeight_NS_MSL) & ncol_16_NS=s_16_NS(1)
         col_16_NS=index_16_NS MOD ncol_16_NS & row_16_NS=index_16_NS/ncol_16_NS
         countcol16_NS=n_elements(col_16_NS)

         help, col_0_NS,col_1_NS,col_2_NS,col_3_NS,col_4_NS,col_5_NS,col_6_NS,col_7_NS,col_8_NS
         help, col_9_NS,col_10_NS,col_11_NS,col_12_NS,col_13_NS,col_14_NS,col_15_NS,col_16_NS
         test_max_NS=[countcol0_NS,countcol1_NS,countcol2_NS,countcol3_NS,countcol4_NS,countcol5_NS,countcol6_NS, $
                   countcol7_NS,countcol8_NS,countcol9_NS,countcol10_NS,countcol11_NS,countcol12_NS,countcol13_NS, $
                   countcol14_NS,countcol15_NS,countcol16_NS]
         max_row_NS=max(test_max_NS)
         print, 'max_row: ', max_row_NS

         ;Create an array for the col and row values (but use the max_row value, since the nr_elements vary!).
         col_NS=intarr(max_row_NS,17) & col_NS[*,*]=-1;!values.f_nan ;Can't make it zero either, because zero means something later...
         col_NS[0:test_max_NS[0]-1,0]=col_0_NS & col_NS[0:test_max_NS[1]-1,1]=col_1_NS & col_NS[0:test_max_NS[2]-1,2]=col_2_NS
         col_NS[0:test_max_NS[3]-1,3]=col_3_NS & col_NS[0:test_max_NS[4]-1,4]=col_4_NS & col_NS[0:test_max_NS[5]-1,5]=col_5_NS
         col_NS[0:test_max_NS[6]-1,6]=col_6_NS & col_NS[0:test_max_NS[7]-1,7]=col_7_NS & col_NS[0:test_max_NS[8]-1,8]=col_8_NS
         col_NS[0:test_max_NS[9]-1,9]=col_9_NS & col_NS[0:test_max_NS[10]-1,10]=col_10_NS & col_NS[0:test_max_NS[11]-1,11]=col_11_NS
         col_NS[0:test_max_NS[12]-1,12]=col_12_NS & col_NS[0:test_max_NS[13]-1,13]=col_13_NS & col_NS[0:test_max_NS[14]-1,14]=col_14_NS
         col_NS[0:test_max_NS[15]-1,15]=col_15_NS & col_NS[0:test_max_NS[16]-1,16]=col_16_NS

         row_NS=intarr(max_row_NS,17) & row_NS[*,*]=-1;!values.f_nan ;Can't make it zero either, because zero means something later...
         row_NS[0:test_max_NS[0]-1,0]=row_0_NS & row_NS[0:test_max_NS[1]-1,1]=row_1_NS & row_NS[0:test_max_NS[2]-1,2]=row_2_NS
         row_NS[0:test_max_NS[3]-1,3]=row_3_NS & row_NS[0:test_max_NS[4]-1,4]=row_4_NS & row_NS[0:test_max_NS[5]-1,5]=row_5_NS
         row_NS[0:test_max_NS[6]-1,6]=row_6_NS & row_NS[0:test_max_NS[7]-1,7]=row_7_NS & row_NS[0:test_max_NS[8]-1,8]=row_8_NS
         row_NS[0:test_max_NS[9]-1,9]=row_9_NS & row_NS[0:test_max_NS[10]-1,10]=row_10_NS & row_NS[0:test_max_NS[11]-1,11]=row_11_NS
         row_NS[0:test_max_NS[12]-1,12]=row_12_NS & row_NS[0:test_max_NS[13]-1,13]=row_13_NS & row_NS[0:test_max_NS[14]-1,14]=row_14_NS
         row_NS[0:test_max_NS[15]-1,15]=row_15_NS & row_NS[0:test_max_NS[16]-1,16]=row_16_NS

         ;The next loops take the -1 and NaN "values" into account when obtaining the HIDs/whichever variables
         ;for a specific xgrid and ygrid value:
         for lll=0, nr_zgrid-1 do begin ;array(17)
 	   print, ''
           print, '****This is for the NS variables:****'
           print, 'The following is for altitude  ', zgrid[lll], '  km MSL and nr_zgrid (i.e., lll) : ', lll

           ;Doing it this way to ensure we don't run the loop if there's no data other than "misssing" values
           if long(total(col_NS[*,lll])) lt 0 then print, 'There is no informtation at this altitude for this orbit'
             for mmm=0, nr_ygrid-2 do begin ;array(776)
                for nnn=0, nr_xgrid-2 do begin ;array(1466)

                ;Do the NS conversions here:
                ;This is for the variables that are a function of elevationAngle (actuallly altitude).
                if long(total(col_NS[*,lll])) gt 0 then begin ;Again, to not run when there is no data...
                   alt0_grid_NS=where(large_xgrid_NS[col_NS[*,lll],row_NS[*,lll]] ge xgrid[nnn] and $
                             large_xgrid_NS[col_NS[*,lll],row_NS[*,lll]] lt xgrid[nnn+1] and $
                             large_ygrid_NS[col_NS[*,lll],row_NS[*,lll]] ge ygrid[mmm] and $
                             large_ygrid_NS[col_NS[*,lll],row_NS[*,lll]] lt ygrid[mmm+1] and $
                             col_NS[*,lll] ge 0, count0_NS);NB: You need the "col_NS" statement too otherwise NaN values are used...

                   if count0_NS gt 0 then begin
                      print, 'This is for altitude  ', zgrid[lll], '  km MSL and lll', lll
                      print, 'Count of alt0_grid (xgrid, ygrid, zgrid), count0 =    ', alt0_grid_NS, count0_NS
                      print, 'xgrid[nnn], ygrid[mmm] = ', xgrid[nnn], ygrid[mmm]
                      ;The following is for the conversions:
                      lat_NS_0=fltarr(count0_NS)
                      lon_NS_0=fltarr(count0_NS)
                      topH_MSL_NS_0=fltarr(count0_NS)
                      topH_NS_0=fltarr(count0_NS)
                      botH_MSL_NS_0=fltarr(count0_NS)
                      botH_NS_0=fltarr(count0_NS)

                      HID_NS_0=intarr(count0_NS,15)
                      Z_NS_0=fltarr(count0_NS)
                      Z_StdDev_NS_0=fltarr(count0_NS)
                      Z_Max_NS_0=fltarr(count0_NS)
                      Zdr_NS_0=fltarr(count0_NS)
                      Zdr_StdDev_NS_0=fltarr(count0_NS)
                      Zdr_Max_NS_0=fltarr(count0_NS)
                      Kdp_NS_0=fltarr(count0_NS)
                      Kdp_StdDev_NS_0=fltarr(count0_NS)
                      Kdp_Max_NS_0=fltarr(count0_NS)
                      RHOhv_NS_0=fltarr(count0_NS)
                      RHOhv_StdDev_NS_0=fltarr(count0_NS)
                      RHOhv_Max_NS_0=fltarr(count0_NS)
                      RC_rainrate_NS_0=fltarr(count0_NS)
                      RC_rainrate_StdDev_NS_0=fltarr(count0_NS)
                      RC_rainrate_Max_NS_0=fltarr(count0_NS)
                      RP_rainrate_NS_0=fltarr(count0_NS)
                      RP_rainrate_StdDev_NS_0=fltarr(count0_NS)
                      RP_rainrate_Max_NS_0=fltarr(count0_NS)
                      RR_rainrate_NS_0=fltarr(count0_NS)
                      RR_rainrate_StdDev_NS_0=fltarr(count0_NS)
                      RR_rainrate_Max_NS_0=fltarr(count0_NS)
                      Dzero_NS_0=fltarr(count0_NS)
                      Dzero_StdDev_NS_0=fltarr(count0_NS)
                      Dzero_Max_NS_0=fltarr(count0_NS)
                      Nw_NS_0=fltarr(count0_NS)
                      Nw_StdDev_NS_0=fltarr(count0_NS)
                      Nw_Max_NS_0=fltarr(count0_NS)
                      Dm_NS_0=fltarr(count0_NS)
                      Dm_StdDev_NS_0=fltarr(count0_NS)
                      Dm_Max_NS_0=fltarr(count0_NS)
                      N2_NS_0=fltarr(count0_NS)
                      N2_StdDev_NS_0=fltarr(count0_NS)
                      N2_Max_NS_0=fltarr(count0_NS)
                      blockage_NS_0=fltarr(count0_NS)
                      n_z_rejected_NS_0=intarr(count0_NS)
                      n_zdr_rejected_NS_0=intarr(count0_NS)
                      n_kdp_rejected_NS_0=intarr(count0_NS)
                      n_rhohv_rejected_NS_0=intarr(count0_NS)
                      n_rc_rejected_NS_0=intarr(count0_NS)
                      n_rp_rejected_NS_0=intarr(count0_NS)
                      n_rr_rejected_NS_0=intarr(count0_NS)
                      n_hid_rejected_NS_0=intarr(count0_NS)
                      n_dzero_rejected_NS_0=intarr(count0_NS)
                      n_nw_rejected_NS_0=intarr(count0_NS)
                      n_expected_NS_0=intarr(count0_NS)
                      precipTotPSDparamHigh_NS_0=fltarr(count0_NS)
                      precipTotRate_NS_0=fltarr(count0_NS)
                      precipTotWaterCont_NS_0=fltarr(count0_NS)
                      n_precipTotPSDparamHigh_rejected_NS_0=intarr(count0_NS)
                      n_precipTotRate_rejected_NS_0=intarr(count0_NS)
                      n_precipTotWaterCont_rejected_NS_0=intarr(count0_NS)
                      n_gr_dm_rejected_NS_0=intarr(count0_NS)
                      n_gr_n2_rejected_NS_0=intarr(count0_NS)

                      precipTotPSDparamLow_NS_0=fltarr(2, count0_NS) ;**Function of nPSDlo as welll
                      n_precipTotPSDparamLow_rejected_NS_0=intarr(2,count0_NS) ;**Function of nPSDlo as welll
                      clutterStatus_NS_0=intarr(2,count0_NS) ;**Function of nKuKa as welll
                      correctedReflectFactor_NS_0=fltarr(2,count0_NS) ;**Function of nKuKa as welll
                       n_correctedReflectFactor_rejected_NS_0=intarr(2,count0_NS) ;**Function of nKuKa as welll
                       n_dpr_expected_NS_0=intarr(2,count0_NS) ;**Function of nKuKa as welll

                      for sss=0, count0_NS-1 do begin

                        ;This prints out the actual x and y values of each pixel, so don't want to delete!
                        ;print, 'large_xgrid_NS[col_NS[lll][alt0_grid_NS]], large_ygrid_NS[col_NS[lll][alt0_grid_NS]]:'
                        ;print, large_xgrid_NS[col_NS[alt0_grid_NS[sss],lll]], large_ygrid_NS[col_NS[alt0_grid_NS[sss],lll]]
                        ;print, 'large_GR_HID_NS[*,col_NS[lll][alt0_grid_NS],row_NS[lll][alt0_grid_NS]]:'
                        ;print, large_GR_HID_NS[*,col_NS[alt0_grid_NS[sss],lll],row_NS[alt0_grid_NS[sss],lll]]

                        lat_NS_0[sss]=large_latitude_NS[col_NS[alt0_grid_NS[sss],lll],row_NS[alt0_grid_NS[sss],lll]]
                        lon_NS_0[sss]=large_longitude_NS[col_NS[alt0_grid_NS[sss],lll],row_NS[alt0_grid_NS[sss],lll]]
                        topH_MSL_NS_0[sss]=large_topHeight_NS_MSL[col_NS[alt0_grid_NS[sss],lll],row_NS[alt0_grid_NS[sss],lll]] ;MSL
                        topH_NS_0[sss]=large_topHeight_NS[col_NS[alt0_grid_NS[sss],lll],row_NS[alt0_grid_NS[sss],lll]] ;AGL
                        botH_MSL_NS_0[sss]=large_bottomHeight_NS_MSL[col_NS[alt0_grid_NS[sss],lll],row_NS[alt0_grid_NS[sss],lll]] ;MSL
                        botH_NS_0[sss]=large_bottomHeight_NS[col_NS[alt0_grid_NS[sss],lll],row_NS[alt0_grid_NS[sss],lll]] ;AGL

                        HID_NS_0[sss,*]=large_GR_HID_NS[*,col_NS[alt0_grid_NS[sss],lll],row_NS[alt0_grid_NS[sss],lll]]
                        Z_NS_0[sss]=large_GR_Z_NS[col_NS[alt0_grid_NS[sss],lll],row_NS[alt0_grid_NS[sss],lll]]

                        ;Checking these first:
                        Z_StdDev_NS_0[sss]=large_GR_Z_StdDev_NS[col_NS[alt0_grid_NS[sss],lll],row_NS[alt0_grid_NS[sss],lll]]
                        Z_Max_NS_0[sss]=large_GR_Z_Max_NS[col_NS[alt0_grid_NS[sss],lll],row_NS[alt0_grid_NS[sss],lll]]
                        Zdr_NS_0[sss]=large_GR_Zdr_NS[col_NS[alt0_grid_NS[sss],lll],row_NS[alt0_grid_NS[sss],lll]]
                        Zdr_StdDev_NS_0[sss]=large_GR_Zdr_StdDev_NS[col_NS[alt0_grid_NS[sss],lll],row_NS[alt0_grid_NS[sss],lll]]
                        Zdr_Max_NS_0[sss]=large_GR_Zdr_Max_NS[col_NS[alt0_grid_NS[sss],lll],row_NS[alt0_grid_NS[sss],lll]]
                        Kdp_NS_0[sss]=large_GR_Kdp_NS[col_NS[alt0_grid_NS[sss],lll],row_NS[alt0_grid_NS[sss],lll]]
                        Kdp_StdDev_NS_0[sss]=large_GR_Kdp_StdDev_NS[col_NS[alt0_grid_NS[sss],lll],row_NS[alt0_grid_NS[sss],lll]]
                        Kdp_Max_NS_0[sss]=large_GR_Kdp_Max_NS[col_NS[alt0_grid_NS[sss],lll],row_NS[alt0_grid_NS[sss],lll]]
                        RHOhv_NS_0[sss]=large_GR_RHOhv_NS[col_NS[alt0_grid_NS[sss],lll],row_NS[alt0_grid_NS[sss],lll]]
                        RHOhv_StdDev_NS_0[sss]=large_GR_RHOhv_StdDev_NS[col_NS[alt0_grid_NS[sss],lll],row_NS[alt0_grid_NS[sss],lll]]
                        RHOhv_Max_NS_0[sss]=large_GR_RHOhv_Max_NS[col_NS[alt0_grid_NS[sss],lll],row_NS[alt0_grid_NS[sss],lll]]
                        RC_rainrate_NS_0[sss]=large_GR_RC_rainrate_NS[col_NS[alt0_grid_NS[sss],lll],row_NS[alt0_grid_NS[sss],lll]]
                        RC_rainrate_StdDev_NS_0[sss]=large_GR_RC_rainrate_StdDev_NS[col_NS[alt0_grid_NS[sss],lll],row_NS[alt0_grid_NS[sss],lll]]
                        RC_rainrate_Max_NS_0[sss]=large_GR_RC_rainrate_Max_NS[col_NS[alt0_grid_NS[sss],lll],row_NS[alt0_grid_NS[sss],lll]]
                        RP_rainrate_NS_0[sss]=large_GR_RP_rainrate_NS[col_NS[alt0_grid_NS[sss],lll],row_NS[alt0_grid_NS[sss],lll]]
                        RP_rainrate_StdDev_NS_0[sss]=large_GR_RP_rainrate_StdDev_NS[col_NS[alt0_grid_NS[sss],lll],row_NS[alt0_grid_NS[sss],lll]]
                        RP_rainrate_Max_NS_0[sss]=large_GR_RP_rainrate_Max_NS[col_NS[alt0_grid_NS[sss],lll],row_NS[alt0_grid_NS[sss],lll]]
                        RR_rainrate_NS_0[sss]=large_GR_RR_rainrate_NS[col_NS[alt0_grid_NS[sss],lll],row_NS[alt0_grid_NS[sss],lll]]
                        RR_rainrate_StdDev_NS_0[sss]=large_GR_RR_rainrate_StdDev_NS[col_NS[alt0_grid_NS[sss],lll],row_NS[alt0_grid_NS[sss],lll]]
                        RR_rainrate_Max_NS_0[sss]=large_GR_RR_rainrate_Max_NS[col_NS[alt0_grid_NS[sss],lll],row_NS[alt0_grid_NS[sss],lll]]
                        Dzero_NS_0[sss]=large_GR_Dzero_NS[col_NS[alt0_grid_NS[sss],lll],row_NS[alt0_grid_NS[sss],lll]]
                        Dzero_StdDev_NS_0[sss]=large_GR_Dzero_StdDev_NS[col_NS[alt0_grid_NS[sss],lll],row_NS[alt0_grid_NS[sss],lll]]
                        Dzero_Max_NS_0[sss]=large_GR_Dzero_Max_NS[col_NS[alt0_grid_NS[sss],lll],row_NS[alt0_grid_NS[sss],lll]]
                        Nw_NS_0[sss]=large_GR_Nw_NS[col_NS[alt0_grid_NS[sss],lll],row_NS[alt0_grid_NS[sss],lll]]
                        Nw_StdDev_NS_0[sss]=large_GR_Nw_StdDev_NS[col_NS[alt0_grid_NS[sss],lll],row_NS[alt0_grid_NS[sss],lll]]
                        Nw_Max_NS_0[sss]=large_GR_Nw_Max_NS[col_NS[alt0_grid_NS[sss],lll],row_NS[alt0_grid_NS[sss],lll]]
                        Dm_NS_0[sss]=large_GR_Dm_NS[col_NS[alt0_grid_NS[sss],lll],row_NS[alt0_grid_NS[sss],lll]]
                        Dm_StdDev_NS_0[sss]=large_GR_Dm_StdDev_NS[col_NS[alt0_grid_NS[sss],lll],row_NS[alt0_grid_NS[sss],lll]]
                        Dm_Max_NS_0[sss]=large_GR_Dm_Max_NS[col_NS[alt0_grid_NS[sss],lll],row_NS[alt0_grid_NS[sss],lll]]
                        N2_NS_0[sss]=large_GR_N2_NS[col_NS[alt0_grid_NS[sss],lll],row_NS[alt0_grid_NS[sss],lll]]
                        N2_StdDev_NS_0[sss]=large_GR_N2_StdDev_NS[col_NS[alt0_grid_NS[sss],lll],row_NS[alt0_grid_NS[sss],lll]]
                        N2_Max_NS_0[sss]=large_GR_N2_Max_NS[col_NS[alt0_grid_NS[sss],lll],row_NS[alt0_grid_NS[sss],lll]]
                        blockage_NS_0[sss]=large_GR_blockage_NS[col_NS[alt0_grid_NS[sss],lll],row_NS[alt0_grid_NS[sss],lll]]
                        n_z_rejected_NS_0[sss]= large_n_gr_z_rejected_NS[col_NS[alt0_grid_NS[sss],lll],row_NS[alt0_grid_NS[sss],lll]]
                        n_zdr_rejected_NS_0[sss]=large_n_gr_zdr_rejected_NS[col_NS[alt0_grid_NS[sss],lll],row_NS[alt0_grid_NS[sss],lll]]
                        n_kdp_rejected_NS_0[sss]=large_n_gr_kdp_rejected_NS[col_NS[alt0_grid_NS[sss],lll],row_NS[alt0_grid_NS[sss],lll]]
                        n_rhohv_rejected_NS_0[sss]=large_n_gr_rhohv_rejected_NS[col_NS[alt0_grid_NS[sss],lll],row_NS[alt0_grid_NS[sss],lll]]
                        n_rc_rejected_NS_0[sss]=large_n_gr_rc_rejected_NS[col_NS[alt0_grid_NS[sss],lll],row_NS[alt0_grid_NS[sss],lll]]
                        n_rp_rejected_NS_0[sss]=large_n_gr_rp_rejected_NS[col_NS[alt0_grid_NS[sss],lll],row_NS[alt0_grid_NS[sss],lll]]
                        n_rr_rejected_NS_0[sss]=large_n_gr_rr_rejected_NS[col_NS[alt0_grid_NS[sss],lll],row_NS[alt0_grid_NS[sss],lll]]
                        n_hid_rejected_NS_0[sss]=large_n_gr_hid_rejected_NS[col_NS[alt0_grid_NS[sss],lll],row_NS[alt0_grid_NS[sss],lll]]
                        n_dzero_rejected_NS_0[sss]=large_n_gr_dzero_rejected_NS[col_NS[alt0_grid_NS[sss],lll],row_NS[alt0_grid_NS[sss],lll]]
                        n_nw_rejected_NS_0[sss]=large_n_gr_nw_rejected_NS[col_NS[alt0_grid_NS[sss],lll],row_NS[alt0_grid_NS[sss],lll]]
                        n_expected_NS_0[sss]=large_n_gr_expected_NS[col_NS[alt0_grid_NS[sss],lll],row_NS[alt0_grid_NS[sss],lll]]
                        precipTotPSDparamHigh_NS_0[sss]=large_precipTotPSDparamHigh_NS[col_NS[alt0_grid_NS[sss],lll],row_NS[alt0_grid_NS[sss],lll]]
                        precipTotRate_NS_0[sss]=large_precipTotRate_NS[col_NS[alt0_grid_NS[sss],lll],row_NS[alt0_grid_NS[sss],lll]]
                        precipTotWaterCont_NS_0[sss]=large_precipTotWaterCont_NS[col_NS[alt0_grid_NS[sss],lll],row_NS[alt0_grid_NS[sss],lll]]
                        n_precipTotPSDparamHigh_rejected_NS_0[sss]=large_n_precipTotPSDparamHigh_rejected_NS[col_NS[alt0_grid_NS[sss],lll],row_NS[alt0_grid_NS[sss],lll]]
                        n_precipTotRate_rejected_NS_0[sss]=large_n_precipTotRate_rejected_NS[col_NS[alt0_grid_NS[sss],lll],row_NS[alt0_grid_NS[sss],lll]]
                        n_precipTotWaterCont_rejected_NS_0[sss]=large_n_precipTotWaterCont_rejected_NS[col_NS[alt0_grid_NS[sss],lll],row_NS[alt0_grid_NS[sss],lll]]
			n_gr_dm_rejected_NS_0[sss]=true_large_n_gr_dm_rejected_NS[col_NS[alt0_grid_NS[sss],lll],row_NS[alt0_grid_NS[sss],lll]]
                        n_gr_n2_rejected_NS_0[sss]=true_large_n_gr_n2_rejected_NS[col_NS[alt0_grid_NS[sss],lll],row_NS[alt0_grid_NS[sss],lll]]

                        ;These variables are a function of nPSDlo and nKuKa as welll:
                        precipTotPSDparamLow_NS_0[*,sss]=large_precipTotPSDparamLow_NS[*,col_NS[alt0_grid_NS[sss],lll],row_NS[alt0_grid_NS[sss],lll]]
                        n_precipTotPSDparamLow_rejected_NS_0[*,sss]=large_n_precipTotPSDparamLow_rejected_NS[*,col_NS[alt0_grid_NS[sss],lll],row_NS[alt0_grid_NS[sss],lll]]
                        clutterStatus_NS_0[sss]=large_clutterStatus_NS[col_NS[alt0_grid_NS[sss],lll],row_NS[alt0_grid_NS[sss],lll]]
                        correctedReflectFactor_NS_0[sss]=large_correctedReflectFactor_NS[col_NS[alt0_grid_NS[sss],lll],row_NS[alt0_grid_NS[sss],lll]]
                        n_correctedReflectFactor_rejected_NS_0[sss]=large_n_correctedReflectFactor_rejected_NS[col_NS[alt0_grid_NS[sss],lll],row_NS[alt0_grid_NS[sss],lll]]
                        n_dpr_expected_NS_0[sss]=large_n_dpr_expected_NS[col_NS[alt0_grid_NS[sss],lll],row_NS[alt0_grid_NS[sss],lll]]

                      endfor ;sss the nr of elements in the where statement

                      print, 'Z_NS_0: ', Z_NS_0
                      test_Z_NS=Z_NS_0[where(Z_NS_0 gt 0.0, count_Z_NS_0)]
                      if count_Z_NS_0 ge 1 then median_Z_NS=median(test_Z_NS)
                      if count_Z_NS_0 lt 1 then median_Z_NS=mvf
                      if count_Z_NS_0 lt 1 then print, '**There are no reflectivity values >= 0.0 dBZ; Moving on to next grid point**'

                      if count_Z_NS_0 ge 1 then begin ;If there are no reflectivities > 0.0, then don't run the rest of the script!
                         print, 'count_Z_NS_0, Median Z MS: ', count_Z_NS_0,'  ',  median_Z_NS
                         grid_GR_Z_NS[nnn,mmm,lll]=median_Z_NS

                         ;We need the following statement to find the location of the actual Z value that we saved:
                         testmedZ_NS=where(Z_NS_0 eq median_Z_NS) ;Will use this location for most other variables:

                         total_HID_NS_conc=intarr(15)
                         total_HID_NS_conc[0:14]=HID_NS_0[testmedZ_NS, *] ;Using the location of MEDIAN Z_MS!
                         grid_GR_HID_NS[0:14,nnn,mmm,lll]=total_HID_NS_conc[0:14] ;Since we only want the 15 HIDs at one elevation

                         print, 'lat_NS_0: ', lat_NS_0
                         median_lat_NS=lat_NS_0[testmedZ_NS]
                         print, 'median_lat_NS : ',  median_lat_NS
                         grid_latitude_NS[nnn,mmm,lll]=median_lat_NS
                         print, 'lon_NS_0: ', lon_NS_0
                         median_lon_NS=lon_NS_0[testmedZ_NS]
                         print, 'median_lon_NS : ',  median_lon_NS
                         grid_longitude_NS[nnn,mmm,lll]=median_lon_NS
                         median_topH_MSL_NS=topH_MSL_NS_0[testmedZ_NS]
                         print, 'median_topH_MSL_NS: ', median_topH_MSL_NS
                         grid_topHeight_NS_MSL[nnn,mmm,lll]=median_topH_MSL_NS
                         median_topH_NS=topH_NS_0[testmedZ_NS]
                         print, 'median_topH_NS: ',  median_topH_NS
                         grid_topHeight_NS[nnn,mmm,lll]=median_topH_NS
                         median_botH_MSL_NS=botH_MSL_NS_0[testmedZ_NS]
                         grid_bottomHeight_NS_MSL[nnn,mmm,lll]=median_botH_MSL_NS
                         median_botH_NS=botH_NS_0[testmedZ_NS]
                         grid_bottomHeight_NS[nnn,mmm,lll]=median_botH_NS
                         median_Z_StdDev_NS=Z_StdDev_NS_0[testmedZ_NS]
                         grid_GR_Z_StdDev_NS[nnn,mmm,lll]=median_Z_StdDev_NS
                         median_Z_Max_NS=Z_Max_NS_0[testmedZ_NS]
                         grid_GR_Z_Max_NS[nnn,mmm,lll]=median_Z_Max_NS
                         median_Zdr_NS=Zdr_NS_0[testmedZ_NS]
                         grid_GR_Zdr_NS[nnn,mmm,lll]=median_Zdr_NS
                         median_Zdr_StdDev_NS=Zdr_StdDev_NS_0[testmedZ_NS]
                         grid_GR_Zdr_StdDev_NS[nnn,mmm,lll]=median_Zdr_StdDev_NS
                         median_Zdr_Max_NS=Zdr_Max_NS_0[testmedZ_NS]
                         grid_GR_Zdr_Max_NS[nnn,mmm,lll]=median_Zdr_Max_NS
                         median_Kdp_NS=Kdp_NS_0[testmedZ_NS]
                         grid_GR_Kdp_NS[nnn,mmm,lll]=median_Kdp_NS
                         median_Kdp_StdDev_NS=Kdp_StdDev_NS_0[testmedZ_NS]
                         grid_GR_Kdp_StdDev_NS[nnn,mmm,lll]=median_Kdp_StdDev_NS
                         median_Kdp_Max_NS=Kdp_Max_NS_0[testmedZ_NS]
                         grid_GR_Kdp_Max_NS[nnn,mmm,lll]=median_Kdp_Max_NS
                         median_RHOhv_NS=RHOhv_NS_0[testmedZ_NS]
                         grid_GR_RHOhv_NS[nnn,mmm,lll]=median_RHOhv_NS
                         median_RHOhv_StdDev_NS=RHOhv_StdDev_NS_0[testmedZ_NS]
                         grid_GR_RHOhv_StdDev_NS[nnn,mmm,lll]=median_RHOhv_StdDev_NS
                         median_RHOhv_Max_NS=RHOhv_Max_NS_0[testmedZ_NS]
                         grid_GR_RHOhv_Max_NS[nnn,mmm,lll]=median_RHOhv_Max_NS
                         median_RC_rainrate_NS=RC_rainrate_NS_0[testmedZ_NS]
                         grid_GR_RC_rainrate_NS[nnn,mmm,lll]=median_RC_rainrate_NS
                         median_RC_rainrate_StdDev_NS=RC_rainrate_StdDev_NS_0[testmedZ_NS]
                         grid_GR_RC_rainrate_StdDev_NS[nnn,mmm,lll]=median_RC_rainrate_StdDev_NS
                         median_RC_rainrate_Max_NS=RC_rainrate_Max_NS_0[testmedZ_NS]
                         grid_GR_RC_rainrate_Max_NS[nnn,mmm,lll]=median_RC_rainrate_Max_NS
                         median_RP_rainrate_NS=RP_rainrate_NS_0[testmedZ_NS]
                         grid_GR_RP_rainrate_NS[nnn,mmm,lll]=median_RP_rainrate_NS
                         median_RP_rainrate_StdDev_NS=RP_rainrate_StdDev_NS_0[testmedZ_NS]
                         grid_GR_RP_rainrate_StdDev_NS[nnn,mmm,lll]=median_RP_rainrate_StdDev_NS
                         median_RP_rainrate_Max_NS=RP_rainrate_Max_NS_0[testmedZ_NS]
                         grid_GR_RP_rainrate_Max_NS[nnn,mmm,lll]=median_RP_rainrate_Max_NS
                         median_RR_rainrate_NS=RR_rainrate_NS_0[testmedZ_NS]
                         if median_RR_rainrate_NS lt 0.0 then median_RR_rainrate_NS=mvf
                         grid_GR_RR_rainrate_NS[nnn,mmm,lll]=median_RR_rainrate_NS
                         median_RR_rainrate_StdDev_NS=RR_rainrate_StdDev_NS_0[testmedZ_NS]
                         if median_RR_rainrate_StdDev_NS lt 0.0 then median_RR_rainrate_StdDev_NS=mvf
                         grid_GR_RR_rainrate_StdDev_NS[nnn,mmm,lll]=median_RR_rainrate_StdDev_NS
                         median_RR_rainrate_Max_NS=RR_rainrate_Max_NS_0[testmedZ_NS]
                         if median_RR_rainrate_Max_NS lt 0.0 then median_RR_rainrate_Max_NS=mvf
                         grid_GR_RR_rainrate_Max_NS[nnn,mmm,lll]=median_RR_rainrate_Max_NS
                         median_Dzero_NS=Dzero_NS_0[testmedZ_NS]
                         grid_GR_Dzero_NS[nnn,mmm,lll]=median_Dzero_NS
                         median_Dzero_StdDev_NS=Dzero_StdDev_NS_0[testmedZ_NS]
                         grid_GR_Dzero_StdDev_NS[nnn,mmm,lll]=median_Dzero_StdDev_NS
                         median_Dzero_Max_NS=Dzero_Max_NS_0[testmedZ_NS]
                         grid_GR_Dzero_Max_NS[nnn,mmm,lll]=median_Dzero_Max_NS
                         median_Nw_NS=Nw_NS_0[testmedZ_NS]
                         grid_GR_Nw_NS[nnn,mmm,lll]=median_Nw_NS
                         median_Nw_StdDev_NS=Nw_StdDev_NS_0[testmedZ_NS]
                         grid_GR_Nw_StdDev_NS[nnn,mmm,lll]=median_Nw_StdDev_NS
                         median_Nw_Max_NS=Nw_Max_NS_0[testmedZ_NS]
                         grid_GR_Nw_Max_NS[nnn,mmm,lll]=median_Nw_Max_NS
                         median_Dm_NS=Dm_NS_0[testmedZ_NS]
                         grid_GR_Dm_NS[nnn,mmm,lll]=median_Dm_NS
                         median_Dm_StdDev_NS=Dm_StdDev_NS_0[testmedZ_NS]
                         grid_GR_Dm_StdDev_NS[nnn,mmm,lll]=median_Dm_StdDev_NS
                         median_Dm_Max_NS=Dm_Max_NS_0[testmedZ_NS]
                         grid_GR_Dm_Max_NS[nnn,mmm,lll]=median_Dm_Max_NS
                         median_N2_NS=N2_NS_0[testmedZ_NS]
                         grid_GR_N2_NS[nnn,mmm,lll]=median_N2_NS
                         median_N2_StdDev_NS=N2_StdDev_NS_0[testmedZ_NS]
                         grid_GR_N2_StdDev_NS[nnn,mmm,lll]=median_N2_StdDev_NS
                         median_N2_Max_NS=N2_Max_NS_0[testmedZ_NS]
                         grid_GR_N2_Max_NS[nnn,mmm,lll]=median_N2_Max_NS
                         median_blockage_NS=blockage_NS_0[testmedZ_NS]
                         grid_GR_blockage_NS[nnn,mmm,lll]=median_blockage_NS
                         median_n_z_rejected_NS=n_z_rejected_NS_0[testmedZ_NS]
                         grid_n_gr_z_rejected_NS[nnn,mmm,lll]=median_n_z_rejected_NS
                         median_n_zdr_rejected_NS=n_zdr_rejected_NS_0[testmedZ_NS]
                         grid_n_gr_zdr_rejected_NS[nnn,mmm,lll]=median_n_zdr_rejected_NS
                         median_n_kdp_rejected_NS=n_kdp_rejected_NS_0[testmedZ_NS]
                         grid_n_gr_kdp_rejected_NS[nnn,mmm,lll]=median_n_kdp_rejected_NS
                         median_n_rhohv_rejected_NS=n_rhohv_rejected_NS_0[testmedZ_NS]
                         grid_n_gr_rhohv_rejected_NS[nnn,mmm,lll]=median_n_rhohv_rejected_NS
                         median_n_rc_rejected_NS=n_rc_rejected_NS_0[testmedZ_NS]
                         grid_n_gr_rc_rejected_NS[nnn,mmm,lll]=median_n_rc_rejected_NS
                         median_n_rp_rejected_NS=n_rp_rejected_NS_0[testmedZ_NS]
                         grid_n_gr_rp_rejected_NS[nnn,mmm,lll]=median_n_rp_rejected_NS
                         median_n_rr_rejected_NS=n_rr_rejected_NS_0[testmedZ_NS]
                         grid_n_gr_rr_rejected_NS[nnn,mmm,lll]=median_n_rr_rejected_NS
                         median_n_hid_rejected_NS=n_hid_rejected_NS_0[testmedZ_NS]
                         grid_n_gr_hid_rejected_NS[nnn,mmm,lll]=median_n_hid_rejected_NS
                         median_n_dzero_rejected_NS=n_dzero_rejected_NS_0[testmedZ_NS]
                         grid_n_gr_dzero_rejected_NS[nnn,mmm,lll]=median_n_dzero_rejected_NS
                         median_n_nw_rejected_NS=n_nw_rejected_NS_0[testmedZ_NS]
                         grid_n_gr_nw_rejected_NS[nnn,mmm,lll]=median_n_nw_rejected_NS
                         median_n_expected_NS=n_expected_NS_0[testmedZ_NS]
                         grid_n_gr_expected_NS[nnn,mmm,lll]=median_n_expected_NS
                         median_precipTotPSDparamHigh_NS=precipTotPSDparamHigh_NS_0[testmedZ_NS]
                         grid_precipTotPSDparamHigh_NS[nnn,mmm,lll]=median_precipTotPSDparamHigh_NS
                         median_precipTotRate_NS=precipTotRate_NS_0[testmedZ_NS]
                         grid_precipTotRate_NS[nnn,mmm,lll]=median_precipTotRate_NS
                         median_precipTotWaterCont_NS=precipTotWaterCont_NS_0[testmedZ_NS]
                         grid_precipTotWaterCont_NS[nnn,mmm,lll]=median_precipTotWaterCont_NS
                         median_n_precipTotPSDparamHigh_rejected_NS=n_precipTotPSDparamHigh_rejected_NS_0[testmedZ_NS]
                         grid_n_precipTotPSDparamHigh_rejected_NS[nnn,mmm,lll]=median_n_precipTotPSDparamHigh_rejected_NS
                         median_n_precipTotRate_rejected_NS=n_precipTotRate_rejected_NS_0[testmedZ_NS]
                         grid_n_precipTotRate_rejected_NS[nnn,mmm,lll]=median_n_precipTotRate_rejected_NS
                         median_n_precipTotWaterCont_rejected_NS=n_precipTotWaterCont_rejected_NS_0[testmedZ_NS]
                         grid_n_precipTotWaterCont_rejected_NS[nnn,mmm,lll]=median_n_precipTotWaterCont_rejected_NS
                         median_n_gr_dm_rejected_NS=n_gr_dm_rejected_NS_0[testmedZ_NS]
                         grid_n_gr_dm_rejected_NS[nnn,mmm,lll]=median_n_gr_dm_rejected_NS
                         median_n_gr_n2_rejected_NS=n_gr_n2_rejected_NS_0[testmedZ_NS]
                         grid_n_gr_n2_rejected_NS[nnn,mmm,lll]=median_n_gr_n2_rejected_NS

                         ;For the nKuKa and nPSDlow variables that are from 0 to 1 (2 elements):
                         for ppp=0, 1 do begin
                           precipTotPSDparamLow_NS_1=precipTotPSDparamLow_NS_0[ppp,*]
                           test_precipTotPSDparamLow_NS=precipTotPSDparamLow_NS_1[where(precipTotPSDparamLow_NS_1 gt -99.0, $
                              count_precipTotPSDparamLow_NS_0)]
                           median_precipTotPSDparamLow_NS=test_precipTotPSDparamLow_NS[testmedZ_NS]
                           grid_precipTotPSDparamLow_NS[ppp,nnn,mmm,lll]=median_precipTotPSDparamLow_NS

                           n_precipTotPSDparamLow_rejected_NS_1=n_precipTotPSDparamLow_rejected_NS_0[ppp,*]
                           test_n_precipTotPSDparamLow_rejected_NS=n_precipTotPSDparamLow_rejected_NS_1[where(n_precipTotPSDparamLow_rejected_NS_1 gt $
                              -99.0, count_n_precipTotPSDparamLow_rejected_NS_0)]
                           median_n_precipTotPSDparamLow_rejected_NS=test_n_precipTotPSDparamLow_rejected_NS[testmedZ_NS]
                           grid_n_precipTotPSDparamLow_rejected_NS[ppp,nnn,mmm,lll]=median_n_precipTotPSDparamLow_rejected_NS

			   ;NS clutterstatus not a fx of nKuKa or nPSDLow (as is the case for MS), but keeping the text here
                           clutterStatus_NS_1=clutterStatus_NS_0[*]
                           test_clutterStatus_NS=clutterStatus_NS_1[where(clutterStatus_NS_1 gt -99.0, count_clutterStatus_NS_0)]
                           median_clutterStatus_NS=test_clutterStatus_NS[testmedZ_NS]
                           grid_clutterStatus_NS[nnn,mmm,lll]=median_clutterStatus_NS

                           correctedReflectFactor_NS_1=correctedReflectFactor_NS_0[*]
                           test_correctedReflectFactor_NS=correctedReflectFactor_NS_1[where(correctedReflectFactor_NS_1 gt -99.0, $
                              count_correctedReflectFactor_NS_0)]
                           median_correctedReflectFactor_NS=test_correctedReflectFactor_NS[testmedZ_NS]
                           grid_correctedReflectFactor_NS[nnn,mmm,lll]=median_correctedReflectFactor_NS

                           n_correctedReflectFactor_rejected_NS_1=n_correctedReflectFactor_rejected_NS_0[*]
                           test_n_correctedReflectFactor_rejected_NS=n_correctedReflectFactor_rejected_NS_1[where(n_correctedReflectFactor_rejected_NS_1 gt $
                              -99.0, count_n_correctedReflectFactor_rejected_NS_0)]
                           median_n_correctedReflectFactor_rejected_NS=test_n_correctedReflectFactor_rejected_NS[testmedZ_NS]
                           grid_n_correctedReflectFactor_rejected_NS[nnn,mmm,lll]=median_n_correctedReflectFactor_rejected_NS

                           n_dpr_expected_NS_1=n_dpr_expected_NS_0[*]
                           test_n_dpr_expected_NS=n_dpr_expected_NS_1[where(n_dpr_expected_NS_1 gt -99.0, count_n_dpr_expected_NS_0)]
                           median_n_dpr_expected_NS=test_n_dpr_expected_NS[testmedZ_NS]
                           if median_n_dpr_expected_NS lt 0 then median_n_dpr_expected_NS=mvi
                           grid_n_dpr_expected_NS[nnn,mmm,lll]=median_n_dpr_expected_NS
                         endfor ;ppp the nKuKa and nPSDlow variables that are from 0 to 1 (2 elements)

                         ;Now to save the variables that are NOT a function of elevationAngle to the grid:
                         ;Note that even though the variables below are NOT a function of elevationAngle/Altitude, I decided to use the EXACT
                         ;same location as for the "testmedZ_NS", which is location of the median reflectivity to keep everything consistent!

                         if lll eq 0 then begin ;This is so that ONLY the lowest zgrid (alt0_grid_NS) values are used:
                            grid_phaseBinNodes_NS[*,nnn,mmm]=large_phaseBinNodes_NS[*,alt0_grid_NS[testmedZ_NS]]
                            grid_ellipsoidBinOffset_NS[nnn,mmm]=large_ellipsoidBinOffset_NS[alt0_grid_NS[testmedZ_NS]]
                            grid_lowestClutterFreeBin_NS[nnn,mmm]=large_lowestClutterFreeBin_NS[alt0_grid_NS[testmedZ_NS]]
                            grid_precipitationFlag_NS[nnn,mmm]=large_precipitationFlag_NS[alt0_grid_NS[testmedZ_NS]]
                            grid_surfaceRangeBin_NS[nnn,mmm]=large_surfaceRangeBin_NS[alt0_grid_NS[testmedZ_NS]]
                            grid_pia_NS[nnn,mmm]=large_pia_NS[alt0_grid_NS[testmedZ_NS]]
                            grid_stormTopAltitude_NS[nnn,mmm]=large_stormTopAltitude_NS[alt0_grid_NS[testmedZ_NS]]
                            grid_precipitationType_NS[nnn,mmm]=large_precipitationType_NS[alt0_grid_NS[testmedZ_NS]]
                            ;IMPORTANT NOTE: PrecipitationType CAN be -1111, which means "No rain"
                            grid_surfPrecipTotRate_NS[nnn,mmm]=large_surfPrecipTotRate_NS[alt0_grid_NS[testmedZ_NS]]
                            grid_surfaceElevation_NS[nnn,mmm]=large_surfaceElevation_NS[alt0_grid_NS[testmedZ_NS]]
                            grid_zeroDegAltitude_NS[nnn,mmm]=large_zeroDegAltitude_NS[alt0_grid_NS[testmedZ_NS]]
                            grid_zeroDegBin_NS[nnn,mmm]=large_zeroDegBin_NS[alt0_grid_NS[testmedZ_NS]]
                            grid_surfaceType_NS[nnn,mmm]=large_surfaceType_NS[alt0_grid_NS[testmedZ_NS]]
                            grid_DPRlatitude_NS[nnn,mmm]=large_DPRlatitude_NS[alt0_grid_NS[testmedZ_NS]]
                            grid_DPRlongitude_NS[nnn,mmm]=large_DPRlongitude_NS[alt0_grid_NS[testmedZ_NS]]
                            grid_scanNum_NS[nnn,mmm]=large_scanNum_NS[alt0_grid_NS[testmedZ_NS]]
                            grid_rayNum_NS[nnn,mmm]=large_rayNum_NS[alt0_grid_NS[testmedZ_NS]]
                           endif ;lll = 0 for non-elevationAngle variables
                           ;if count0_NS gt 3 then stop  ;Again, for testing purposes
                        endif ;count_Z_NS_0 ge 1 If there's no real values for the median reflectivity
                     endif ;count0_NS
                   endif ;if total(col_NS[*,lll]) gt 0 then begin
                endfor ;nnn nr_xgrid
             endfor ;mmm nr_ygrid
         endfor ;lll nr_zgrid
     endif ;To test whether there are actuallly any values that falll within xgrid and ygrid!!

     ;Need to reset the large_*NS variables to reduce the memory usage:
     large_latitude_NS=0 & large_longitude_NS=0 & large_xCorners_NS=0 & large_yCorners_NS=0
     large_topHeight_NS=0 & large_bottomHeight_NS=0 & large_topHeight_NS_MSL=0 & large_bottomHeight_NS_MSL=0
     large_GR_Z_NS=0 & large_GR_Z_StdDev_NS=0 & large_GR_Z_Max_NS=0 & large_GR_Zdr_NS=0 & large_GR_Zdr_StdDev_NS=0
     large_GR_Zdr_Max_NS=0 & large_GR_Kdp_NS=0 & large_GR_Kdp_StdDev_NS=0 & large_GR_Kdp_Max_NS=0
     large_GR_RHOhv_NS=0 & large_GR_RHOhv_StdDev_NS=0 & large_GR_RHOhv_Max_NS=0 & large_GR_RC_rainrate_NS=0
     large_GR_RC_rainrate_StdDev_NS=0 & large_GR_RC_rainrate_Max_NS=0 & large_GR_RP_rainrate_NS=0
     large_GR_RP_rainrate_StdDev_NS=0 & large_GR_RP_rainrate_Max_NS=0 & large_GR_RR_rainrate_NS=0 
     large_GR_RR_rainrate_StdDev_NS=0 & large_GR_RR_rainrate_Max_NS=0 & large_GR_HID_NS=0 & large_GR_Dzero_NS=0
     large_GR_Dzero_StdDev_NS=0 & large_GR_Dzero_Max_NS=0 & large_GR_Nw_NS=0 & large_GR_Nw_StdDev_NS=0
     large_GR_Nw_Max_NS=0 & large_GR_Dm_NS=0 & large_GR_Dm_StdDev_NS=0 & large_GR_Dm_Max_NS=0
     large_GR_N2_NS=0 & large_GR_N2_StdDev_NS=0 & large_GR_N2_Max_NS=0 & large_GR_blockage_NS=0
     large_n_gr_z_rejected_NS=0 & large_n_gr_zdr_rejected_NS=0 & large_n_gr_kdp_rejected_NS=0 
     large_n_gr_rhohv_rejected_NS=0 & large_n_gr_rc_rejected_NS=0 & large_n_gr_rp_rejected_NS=0
     large_n_gr_rr_rejected_NS=0 & large_n_gr_hid_rejected_NS=0 & large_n_gr_dzero_rejected_NS=0
     large_n_gr_nw_rejected_NS=0 & large_n_gr_dm_rejected_NS=0 & true_large_n_gr_dm_rejected_NS=0
     large_n_gr_n2_rejected_NS=0 & true_large_n_gr_n2_rejected_NS=0 & large_n_gr_expected_NS=0
     large_precipTotPSDparamHigh_NS=0 & large_precipTotPSDparamLow_NS=0 & large_precipTotRate_NS=0
     large_precipTotWaterCont_NS=0 & large_n_precipTotPSDparamHigh_rejected_NS=0 & large_n_precipTotPSDparamLow_rejected_NS=0
     large_n_precipTotRate_rejected_NS=0 & large_n_precipTotWaterCont_rejected_NS=0 & large_precipitationType_NS=0
     large_surfPrecipTotRate_NS=0 & large_surfaceElevation_NS=0 & large_zeroDegAltitude_NS=0 
     large_zeroDegBin_NS=0 & large_surfaceType_NS=0 & large_phaseBinNodes_NS=0 & large_DPRlatitude_NS=0
     large_DPRlongitude_NS=0 & large_scanNum_NS=0 & large_rayNum_NS=0 & large_ellipsoidBinOffset_NS=0
     large_lowestClutterFreeBin_NS=0 & large_clutterStatus_NS=0 & large_precipitationFlag_NS=0
     large_surfaceRangeBin_NS=0 & large_correctedReflectFactor_NS=0 & large_pia_NS=0
     large_stormTopAltitude_NS=0 & large_n_correctedReflectFactor_rejected_NS=0 & large_n_dpr_expected_NS=0

     grid_GR_minZref_NS=min(grid_GR_Z_NS[where(grid_GR_Z_NS ge 0.0)]) ;This is the MIN reflectivity for entire grid
     grid_GR_maxZref_NS=max(grid_GR_Z_NS[where(grid_GR_Z_NS ge 0.0)]) ;This is the MAX reflectivity for entire grid

     print, 'For this file, the following reflectivity values were obtained:'
     print, 'Min refl MS = ', grid_GR_minZref_MS
     print, 'Max refl MS = ', grid_GR_maxZref_MS
     print, 'Min refl NS = ', grid_GR_minZref_NS
     print, 'Max refl NS = ', grid_GR_maxZref_NS
     print, ''
     ;NOTE: There ARE times where the min and max _MS reflectivity will be -999, but there will be values for _NS

     ;Now to make sure all the weird -88.88, -100.0, -88, -99.0 values are removed and replaced with -999:
     grid_latitude_main=grid_latitude_main
     grid_longitude_main=grid_longitude_main
     grid_latitude_MS[where(grid_latitude_MS lt -50.0)]=mvf
     grid_longitude_MS[where(grid_longitude_MS lt -130.0)]=mvf
     grid_topHeight_MS_MSL[where(grid_topHeight_MS_MSL lt -50.0)]=mvf
     grid_topHeight_MS[where(grid_topHeight_MS lt -50.0)]=mvf
     grid_bottomHeight_MS_MSL[where(grid_bottomHeight_MS_MSL lt -50.0)]=mvf
     grid_bottomHeight_MS[where(grid_bottomHeight_MS lt -50.0)]=mvf
     grid_GR_Z_MS[where(grid_GR_Z_MS lt -50.0)]=mvf ;To fix the -100.0 values...
     grid_GR_Z_StdDev_MS[where(grid_GR_Z_StdDev_MS lt -50.0)]=mvf ;To fix the -100.0 values...
     grid_GR_Z_Max_MS[where(grid_GR_Z_Max_MS lt -50.0)]=mvf
     grid_GR_Zdr_MS[where(grid_GR_Zdr_MS lt -50.0)]=mvf
     grid_GR_Zdr_StdDev_MS[where(grid_GR_Zdr_StdDev_MS lt -50.0)]=mvf
     grid_GR_Zdr_Max_MS[where(grid_GR_Zdr_Max_MS lt -50.0)]=mvf
     grid_GR_Kdp_MS[where(grid_GR_Kdp_MS lt -50.0)]=mvf
     grid_GR_Kdp_StdDev_MS[where(grid_GR_Kdp_StdDev_MS lt -50.0)]=mvf
     grid_GR_Kdp_StdDev_MS[where(grid_GR_Kdp_StdDev_MS lt -50.0)]=mvf
     grid_GR_Kdp_Max_MS[where(grid_GR_Kdp_Max_MS lt -50.0)]=mvf
     grid_GR_RHOhv_MS[where(grid_GR_RHOhv_MS lt -50.0)]=mvf
     grid_GR_RHOhv_StdDev_MS[where(grid_GR_RHOhv_StdDev_MS lt -50.0)]=mvf
     grid_GR_RHOhv_Max_MS[where(grid_GR_RHOhv_Max_MS lt -50.0)]=mvf
     grid_GR_RC_rainrate_MS[where(grid_GR_RC_rainrate_MS lt -50.0)]=mvf
     grid_GR_RC_rainrate_StdDev_MS[where(grid_GR_RC_rainrate_StdDev_MS lt -50.0)]=mvf
     grid_GR_RC_rainrate_Max_MS[where(grid_GR_RC_rainrate_Max_MS lt -50.0)]=mvf
     grid_GR_RP_rainrate_MS[where(grid_GR_RP_rainrate_MS lt -50.0)]=mvf
     grid_GR_RP_rainrate_StdDev_MS[where(grid_GR_RP_rainrate_StdDev_MS lt -50.0)]=mvf
     grid_GR_RP_rainrate_Max_MS[where(grid_GR_RP_rainrate_Max_MS lt -50.0)]=mvf
     grid_GR_RR_rainrate_MS[where(grid_GR_RR_rainrate_MS lt -50.0)]=mvf
     grid_GR_RR_rainrate_StdDev_MS[where(grid_GR_RR_rainrate_StdDev_MS lt -50.0)]=mvf
     grid_GR_RR_rainrate_Max_MS[where(grid_GR_RR_rainrate_Max_MS lt -50.0)]=mvf
     grid_GR_Dzero_MS[where(grid_GR_Dzero_MS lt -50.0)]=mvf
     grid_GR_Dzero_StdDev_MS[where(grid_GR_Dzero_StdDev_MS lt -50.0)]=mvf
     grid_GR_Dzero_Max_MS[where(grid_GR_Dzero_Max_MS lt -50.0)]=mvf
     grid_GR_Nw_MS[where(grid_GR_Nw_MS lt -50.0)]=mvf
     grid_GR_Nw_StdDev_MS[where(grid_GR_Nw_StdDev_MS lt -50.0)]=mvf
     grid_GR_Nw_Max_MS[where(grid_GR_Nw_Max_MS lt -50.0)]=mvf
     grid_GR_Dm_MS[where(grid_GR_Dm_MS lt -50.0)]=mvf
     grid_GR_Dm_StdDev_MS[where(grid_GR_Dm_StdDev_MS lt -50.0)]=mvf
     grid_GR_Dm_Max_MS[where(grid_GR_Dm_Max_MS lt -50.0)]=mvf
     grid_GR_N2_MS[where(grid_GR_N2_MS lt -50.0)]=mvf
     grid_GR_N2_StdDev_MS[where(grid_GR_N2_StdDev_MS lt -50.0)]=mvf
     grid_GR_N2_Max_MS[where(grid_GR_N2_Max_MS lt -50.0)]=mvf
     grid_GR_blockage_MS[where(grid_GR_blockage_MS lt -50.0)]=mvf
     grid_n_gr_z_rejected_MS[where(grid_n_gr_z_rejected_MS lt -50)]=mvi
     grid_n_gr_zdr_rejected_MS[where(grid_n_gr_zdr_rejected_MS lt -50)]=mvi
     grid_n_gr_kdp_rejected_MS[where(grid_n_gr_kdp_rejected_MS lt -50)]=mvi
     grid_n_gr_rhohv_rejected_MS[where(grid_n_gr_rhohv_rejected_MS lt -50)]=mvi
     grid_n_gr_rc_rejected_MS[where(grid_n_gr_rc_rejected_MS lt -50)]=mvi
     grid_n_gr_rp_rejected_MS[where(grid_n_gr_rp_rejected_MS lt -50)]=mvi
     grid_n_gr_rr_rejected_MS[where(grid_n_gr_rr_rejected_MS lt -50)]=mvi
     grid_n_gr_hid_rejected_MS[where(grid_n_gr_hid_rejected_MS lt -50)]=mvi
     grid_n_gr_dzero_rejected_MS[where(grid_n_gr_dzero_rejected_MS lt -50)]=mvi
     grid_n_gr_nw_rejected_MS[where(grid_n_gr_nw_rejected_MS lt -50)]=mvi
     grid_n_gr_expected_MS[where(grid_n_gr_expected_MS lt -50)]=mvi
     grid_precipTotPSDparamHigh_MS[where(grid_precipTotPSDparamHigh_MS lt -50.0)]=mvf
     grid_precipTotRate_MS[where(grid_precipTotRate_MS lt -50.0)]=mvf
     grid_precipTotWaterCont_MS[where(grid_precipTotWaterCont_MS lt -50.0)]=mvf
     grid_n_precipTotPSDparamHigh_rejected_MS[where(grid_n_precipTotPSDparamHigh_rejected_MS lt -50)]=mvi
     grid_n_precipTotRate_rejected_MS[where(grid_n_precipTotRate_rejected_MS lt -50)]=mvi
     grid_n_precipTotWaterCont_rejected_MS[where(grid_n_precipTotWaterCont_rejected_MS lt -50)]=mvi
     grid_n_gr_dm_rejected_MS[where(grid_n_gr_dm_rejected_MS lt -50)]=mvi
     grid_n_gr_n2_rejected_MS[where(grid_n_gr_n2_rejected_MS lt -50)]=mvi
     grid_precipTotPSDparamLow_MS[where(grid_precipTotPSDparamLow_MS lt -50.0)]=mvf
     grid_n_precipTotPSDparamLow_rejected_MS[where(grid_n_precipTotPSDparamLow_rejected_MS lt -50)]=mvi
     grid_clutterStatus_MS[where(grid_clutterStatus_MS lt -50)]=mvi
     grid_correctedReflectFactor_MS[where(grid_correctedReflectFactor_MS lt -50.0)]=mvf
     grid_n_correctedReflectFactor_rejected_MS[where(grid_n_correctedReflectFactor_rejected_MS lt -50)]=mvi
     grid_n_dpr_expected_MS[where(grid_n_dpr_expected_MS lt -50)]=mvi
     grid_phaseBinNodes_MS[where(grid_phaseBinNodes_MS lt -50)]=mvi
     grid_ellipsoidBinOffset_MS[where(grid_ellipsoidBinOffset_MS lt -50.0)]=mvf
     grid_lowestClutterFreeBin_MS[where(grid_lowestClutterFreeBin_MS lt -50)]=mvi
     grid_precipitationFlag_MS[where(grid_precipitationFlag_MS lt -50)]=mvi
     grid_surfaceRangeBin_MS[where(grid_surfaceRangeBin_MS lt -50)]=mvi
     grid_pia_MS[where(grid_pia_MS lt -50.0)]=mvf
     grid_stormTopAltitude_MS[where(grid_stormTopAltitude_MS lt -50.0)]=mvf
     ;NB: The grid_precipitationType_MS CAN have -1111, which means "no precipitation!:
     grid_precipitationType_MS[where(grid_precipitationType_MS gt -1111 and grid_precipitationType_MS lt -50)]=mvi
     grid_surfPrecipTotRate_MS[where(grid_surfPrecipTotRate_MS lt -50.0)]=mvf
     grid_surfaceElevation_MS[where(grid_surfaceElevation_MS lt -50.0)]=mvf
     grid_zeroDegAltitude_MS[where(grid_zeroDegAltitude_MS lt -50.0)]=mvf
     grid_zeroDegBin_MS[where(grid_zeroDegBin_MS lt -50)]=mvi
     grid_surfaceType_MS[where(grid_surfaceType_MS lt -50)]=mvi
     grid_DPRlatitude_MS[where(grid_DPRlatitude_MS lt -50.0)]=mvf
     grid_DPRlongitude_MS[where(grid_DPRlongitude_MS lt -130.0)]=mvf
     grid_scanNum_MS[where(grid_scanNum_MS lt -50)]=mvi
     grid_rayNum_MS[where(grid_rayNum_MS lt -50)]=mvi

     ;And for NS variables:
     grid_latitude_NS[where(grid_latitude_NS lt -50.0)]=mvf
     grid_longitude_NS[where(grid_longitude_NS lt -130.0)]=mvf
     grid_topHeight_NS_MSL[where(grid_topHeight_NS_MSL lt -50.0)]=mvf
     grid_topHeight_NS[where(grid_topHeight_NS lt -50.0)]=mvf
     grid_bottomHeight_NS_MSL[where(grid_bottomHeight_NS_MSL lt -50.0)]=mvf
     grid_bottomHeight_NS[where(grid_bottomHeight_NS lt -50.0)]=mvf
     grid_GR_Z_NS[where(grid_GR_Z_NS lt -50.0)]=mvf ;To fix the -100.0 values...
     grid_GR_Z_StdDev_NS[where(grid_GR_Z_StdDev_NS lt -50.0)]=mvf ;To fix the -100.0 values...
     grid_GR_Z_Max_NS[where(grid_GR_Z_Max_NS lt -50.0)]=mvf
     grid_GR_Zdr_NS[where(grid_GR_Zdr_NS lt -50.0)]=mvf
     grid_GR_Zdr_StdDev_NS[where(grid_GR_Zdr_StdDev_NS lt -50.0)]=mvf
     grid_GR_Zdr_Max_NS[where(grid_GR_Zdr_Max_NS lt -50.0)]=mvf
     grid_GR_Kdp_NS[where(grid_GR_Kdp_NS lt -50.0)]=mvf
     grid_GR_Kdp_StdDev_NS[where(grid_GR_Kdp_StdDev_NS lt -50.0)]=mvf
     grid_GR_Kdp_StdDev_NS[where(grid_GR_Kdp_StdDev_NS lt -50.0)]=mvf
     grid_GR_Kdp_Max_NS[where(grid_GR_Kdp_Max_NS lt -50.0)]=mvf
     grid_GR_RHOhv_NS[where(grid_GR_RHOhv_NS lt -50.0)]=mvf
     grid_GR_RHOhv_StdDev_NS[where(grid_GR_RHOhv_StdDev_NS lt -50.0)]=mvf
     grid_GR_RHOhv_Max_NS[where(grid_GR_RHOhv_Max_NS lt -50.0)]=mvf
     grid_GR_RC_rainrate_NS[where(grid_GR_RC_rainrate_NS lt -50.0)]=mvf
     grid_GR_RC_rainrate_StdDev_NS[where(grid_GR_RC_rainrate_StdDev_NS lt -50.0)]=mvf
     grid_GR_RC_rainrate_Max_NS[where(grid_GR_RC_rainrate_Max_NS lt -50.0)]=mvf
     grid_GR_RP_rainrate_NS[where(grid_GR_RP_rainrate_NS lt -50.0)]=mvf
     grid_GR_RP_rainrate_StdDev_NS[where(grid_GR_RP_rainrate_StdDev_NS lt -50.0)]=mvf
     grid_GR_RP_rainrate_Max_NS[where(grid_GR_RP_rainrate_Max_NS lt -50.0)]=mvf
     grid_GR_RR_rainrate_NS[where(grid_GR_RR_rainrate_NS lt -50.0)]=mvf
     grid_GR_RR_rainrate_StdDev_NS[where(grid_GR_RR_rainrate_StdDev_NS lt -50.0)]=mvf
     grid_GR_RR_rainrate_Max_NS[where(grid_GR_RR_rainrate_Max_NS lt -50.0)]=mvf
     grid_GR_Dzero_NS[where(grid_GR_Dzero_NS lt -50.0)]=mvf
     grid_GR_Dzero_StdDev_NS[where(grid_GR_Dzero_StdDev_NS lt -50.0)]=mvf
     grid_GR_Dzero_Max_NS[where(grid_GR_Dzero_Max_NS lt -50.0)]=mvf
     grid_GR_Nw_NS[where(grid_GR_Nw_NS lt -50.0)]=mvf
     grid_GR_Nw_StdDev_NS[where(grid_GR_Nw_StdDev_NS lt -50.0)]=mvf
     grid_GR_Nw_Max_NS[where(grid_GR_Nw_Max_NS lt -50.0)]=mvf
     grid_GR_Dm_NS[where(grid_GR_Dm_NS lt -50.0)]=mvf
     grid_GR_Dm_StdDev_NS[where(grid_GR_Dm_StdDev_NS lt -50.0)]=mvf
     grid_GR_Dm_Max_NS[where(grid_GR_Dm_Max_NS lt -50.0)]=mvf
     grid_GR_N2_NS[where(grid_GR_N2_NS lt -50.0)]=mvf
     grid_GR_N2_StdDev_NS[where(grid_GR_N2_StdDev_NS lt -50.0)]=mvf
     grid_GR_N2_Max_NS[where(grid_GR_N2_Max_NS lt -50.0)]=mvf
     grid_GR_blockage_NS[where(grid_GR_blockage_NS lt -50.0)]=mvf
     grid_n_gr_z_rejected_NS[where(grid_n_gr_z_rejected_NS lt -50)]=mvi
     grid_n_gr_zdr_rejected_NS[where(grid_n_gr_zdr_rejected_NS lt -50)]=mvi
     grid_n_gr_kdp_rejected_NS[where(grid_n_gr_kdp_rejected_NS lt -50)]=mvi
     grid_n_gr_rhohv_rejected_NS[where(grid_n_gr_rhohv_rejected_NS lt -50)]=mvi
     grid_n_gr_rc_rejected_NS[where(grid_n_gr_rc_rejected_NS lt -50)]=mvi
     grid_n_gr_rp_rejected_NS[where(grid_n_gr_rp_rejected_NS lt -50)]=mvi
     grid_n_gr_rr_rejected_NS[where(grid_n_gr_rr_rejected_NS lt -50)]=mvi
     grid_n_gr_hid_rejected_NS[where(grid_n_gr_hid_rejected_NS lt -50)]=mvi
     grid_n_gr_dzero_rejected_NS[where(grid_n_gr_dzero_rejected_NS lt -50)]=mvi
     grid_n_gr_nw_rejected_NS[where(grid_n_gr_nw_rejected_NS lt -50)]=mvi
     grid_n_gr_expected_NS[where(grid_n_gr_expected_NS lt -50)]=mvi
     grid_precipTotPSDparamHigh_NS[where(grid_precipTotPSDparamHigh_NS lt -50.0)]=mvf
     grid_precipTotRate_NS[where(grid_precipTotRate_NS lt -50.0)]=mvf
     grid_precipTotWaterCont_NS[where(grid_precipTotWaterCont_NS lt -50.0)]=mvf
     grid_n_precipTotPSDparamHigh_rejected_NS[where(grid_n_precipTotPSDparamHigh_rejected_NS lt -50)]=mvi
     grid_n_precipTotRate_rejected_NS[where(grid_n_precipTotRate_rejected_NS lt -50)]=mvi
     grid_n_precipTotWaterCont_rejected_NS[where(grid_n_precipTotWaterCont_rejected_NS lt -50)]=mvi
     grid_n_gr_dm_rejected_NS[where(grid_n_gr_dm_rejected_NS lt -50)]=mvi
     grid_n_gr_n2_rejected_NS[where(grid_n_gr_n2_rejected_NS lt -50)]=mvi
     grid_precipTotPSDparamLow_NS[where(grid_precipTotPSDparamLow_NS lt -50.0)]=mvf
     grid_n_precipTotPSDparamLow_rejected_NS[where(grid_n_precipTotPSDparamLow_rejected_NS lt -50)]=mvi
     grid_clutterStatus_NS[where(grid_clutterStatus_NS lt -50)]=mvi
     grid_correctedReflectFactor_NS[where(grid_correctedReflectFactor_NS lt -50.0)]=mvf
     grid_n_correctedReflectFactor_rejected_NS[where(grid_n_correctedReflectFactor_rejected_NS lt -50)]=mvi
     grid_n_dpr_expected_NS[where(grid_n_dpr_expected_NS lt -50)]=mvi
     grid_phaseBinNodes_NS[where(grid_phaseBinNodes_NS lt -50)]=mvi
     grid_ellipsoidBinOffset_NS[where(grid_ellipsoidBinOffset_NS lt -50.0)]=mvf
     grid_lowestClutterFreeBin_NS[where(grid_lowestClutterFreeBin_NS lt -50)]=mvi
     grid_precipitationFlag_NS[where(grid_precipitationFlag_NS lt -50)]=mvi
     grid_surfaceRangeBin_NS[where(grid_surfaceRangeBin_NS lt -50)]=mvi
     grid_pia_NS[where(grid_pia_NS lt -50.0)]=mvf
     grid_stormTopAltitude_NS[where(grid_stormTopAltitude_NS lt -50.0)]=mvf
     ;NB: The grid_precipitationType_NS CAN have -1111, which means "no precipitation!:
     grid_precipitationType_NS[where(grid_precipitationType_NS gt -1111 and grid_precipitationType_NS lt -50)]=mvi
     grid_surfPrecipTotRate_NS[where(grid_surfPrecipTotRate_NS lt -50.0)]=mvf
     grid_surfaceElevation_NS[where(grid_surfaceElevation_NS lt -50.0)]=mvf
     grid_zeroDegAltitude_NS[where(grid_zeroDegAltitude_NS lt -50.0)]=mvf
     grid_zeroDegBin_NS[where(grid_zeroDegBin_NS lt -50)]=mvi
     grid_surfaceType_NS[where(grid_surfaceType_NS lt -50)]=mvi
     grid_DPRlatitude_NS[where(grid_DPRlatitude_NS lt -50.0)]=mvf
     grid_DPRlongitude_NS[where(grid_DPRlongitude_NS lt -130.0)]=mvf
     grid_scanNum_NS[where(grid_scanNum_NS lt -50)]=mvi
     grid_rayNum_NS[where(grid_rayNum_NS lt -50)]=mvi

     elevangle_nc=17
     nrdate_el=n_elements(grid_Year_MS[*,0])
     filelength=strlen(grid_orig_filename[0])
     radarlength=strlen(grid_orig_radarname[0])
     grid_missing_int=[-999,-999]
     grid_missing_flt=[-999.000,-999.000]

     print, '**** It is creating the netcdf file variables ****'
     print, ''

     ;Now to create the actual netcdf file:
     cdfid = ncdf_create(indir+'gridded_CONUS/'+strcompress(year[aa])+'/GRtoDPRGMI.gridded.CONUS.'+$
   	     strcompress(filedate[0],/remove_all)+$
	     '.'+strcompress(grid_orbitnr,/remove_all)+'.V06A.1_3.15dBZ.nc', /clobber, /netcdf4_format) ;clobber=to overwrite an existing file

     ;Set the dimensions:
     ;For dimdef, you can only have scalars and not actual arrays!
     xgridid=ncdf_dimdef(cdfid, 'grid_nr_xgrid', grid_nr_xgrid) ;Nr of xgrid elements = 1466
     ygridid=ncdf_dimdef(cdfid, 'grid_nr_ygrid', grid_nr_ygrid) ;Nr of ygrid elements = 776
     zgridid=ncdf_dimdef(cdfid, 'grid_nr_zgrid', grid_nr_zgrid) ;Nr of zgrid elements = 17
     xygridid= [xgridid, ygridid] ;1466x776
     latgridid=ncdf_dimdef(cdfid, 'grid_nr_lat', grid_nr_ygrid) ;Nr of latitude elements = 776
     longridid=ncdf_dimdef(cdfid, 'grid_nr_lon', grid_nr_xgrid) ;Nr of latitude elements = 1466
     latlongridid=[latgridid, longridid] ;776,1466
     hidimid=ncdf_dimdef(cdfid, 'grid_hidim', grid_hidim); 15
     nrfiles=ncdf_dimdef(cdfid,'grid_nrfiles', grid_nrfiles) ;Nr of files used in the creation of this gridded file (with same orbit number)
     nrdate_el=ncdf_dimdef(cdfid,'grid_date_elements', nrdate_el) ;This varies, for this file is 41
     nPSDlo=ncdf_dimdef(cdfid, 'grid_nPSDlo', grid_nPSDlo); 2
     nBnPSDlo=ncdf_dimdef(cdfid, 'grid_nBnPSDlo', grid_nBnPSDlo) ;9
     nKuKa=ncdf_dimdef(cdfid, 'grid_nKuKa', grid_nKuKa) ;2
     nPhsBnN=ncdf_dimdef(cdfid, 'grid_nPhsBnN', grid_nPhsBnN) ;5
     len_atime_ID=ncdf_dimdef(cdfid, 'grid_len_atime_ID', grid_len_atime_ID) ;19
     len_site_ID=ncdf_dimdef(cdfid, 'grid_len_site_ID', grid_len_site_ID) ;4
     elevangle=ncdf_dimdef(cdfid, 'ElevAngle', elevangle_nc)

     ;For the file name string:
     filenamelen=ncdf_dimdef(cdfid, 'filenamelength', filelength)
     radarnamelen=ncdf_dimdef(cdfid, 'radarnamelength', radarlength)

     ;Define the variables that need to be stored:
     missing_int=ncdf_vardef(cdfid, 'grid_missing_int', [nrfiles], /short)
       ncdf_attput, cdfid, missing_int, 'long_name', 'All missing values for integers are -999'

     missing_flt=ncdf_vardef(cdfid, 'grid_missing_flt', [nrfiles], /short)
       ncdf_attput, cdfid, missing_flt, 'long_name', 'All missing values for floats are -999.000'

     orig_filename=ncdf_vardef(cdfid, 'grid_orig_filename', [filenamelen,nrfiles], /char)  ;The original filenames used for the gridded files
       ncdf_attput, cdfid,orig_filename, 'long_name','The filenames of the original files used in the creation of this gridded file'

     orig_gridversion=ncdf_vardef(cdfid, 'grid_GeoMatchFileVersion', [nrfiles])
       ncdf_attput, cdfid,orig_gridversion, 'long_name', 'Geo Match File Version for the original files used to create this one'

     orig_count_fpdim_MS=ncdf_vardef(cdfid,'orig_count_fpdim_MS', [nrfiles])
       ncdf_attput, cdfid,orig_count_fpdim_MS, 'long_name',$
       'The fpdim_MS points for each of the original files used in the creation of this gridded file'

     orig_count_fpdim_NS=ncdf_vardef(cdfid,'orig_count_fpdim_NS', [nrfiles])
       ncdf_attput, cdfid,orig_count_fpdim_NS, 'long_name',$
       'The fpdim_NS points for each of the original files used in the creation of this gridded file'

     orig_radarname=ncdf_vardef(cdfid,'grid_orig_radarname', [radarlength,nrfiles], /char)
       ncdf_attput, cdfid,orig_radarname, 'long_name', $
       'The radar names for each of the original files used in the creation of this gridded file'

     orig_timedimids_MS=ncdf_vardef(cdfid,'orig_timedimids_MS', [nrfiles])
       ncdf_attput, cdfid,orig_timedimids_MS, 'long_name', $
       'The time dimensional array for each of the MS original files used in the creation of this gridded file'

     orig_timedimids_NS=ncdf_vardef(cdfid,'orig_timedimids_NS', [nrfiles])
       ncdf_attput, cdfid,orig_timedimids_NS, 'long_name', $
       'The time dimensional array for each of the NS original files used in the creation of this gridded file'

     xgrid_arr=ncdf_vardef(cdfid,'grid_xgrid_main', [xgridid])
       ncdf_attput, cdfid, xgrid_arr, 'long_name','Array of x-values (west to east) in km'
       ncdf_attput, cdfid, xgrid_arr, 'units','km'

     ygrid_arr=ncdf_vardef(cdfid,'grid_ygrid_main', [ygridid])
       ncdf_attput, cdfid, ygrid_arr, 'long_name','Array of y-values (south to north) in km'
       ncdf_attput, cdfid, ygrid_arr, 'units','km'

     zgrid_arr=ncdf_vardef(cdfid,'grid_zgrid_main', [zgridid])
       ncdf_attput, cdfid, zgrid_arr, 'long_name','Array of z-values (altitude from 2 to 18 km) as a function of Mean Sea Level (MSL)'
       ncdf_attput, cdfid, zgrid_arr, 'units','km'

     latgrid_arr=ncdf_vardef(cdfid,'grid_lat_main', [latgridid])
       ncdf_attput, cdfid, latgrid_arr, 'long_name', 'Array of Latitude values (North) for the entire grid. This matches the grid_ygrid with an Earth Radius of 6371.22 Km used to convert from y to Lat'
       ncdf_attput, cdfid, latgrid_arr, 'units', 'Degrees North'

     longrid_arr=ncdf_vardef(cdfid,'grid_lon_main', [longridid])
       ncdf_attput, cdfid, longrid_arr, 'long_name', 'Array of Longitude values (East) for the entire grid. This matched the grid_xgrid with an Earth Radius of 6371.22 Km used to convert from x to Lon'
       ncdf_attput, cdfid, longrid_arr, 'units', 'Degrees East'

     timeNearestApproach=ncdf_vardef(cdfid,'grid_timeNearestApproach', [nrfiles], /double)
       ncdf_attput, cdfid, timeNearestApproach, 'long_name', 'Seconds since 01-01-1970 00:00:00 for original files'
       ncdf_attput, cdfid, timeNearestApproach, 'units', 'seconds'

     atimeNearestApproach=ncdf_vardef(cdfid,'grid_atimeNearestApproach', [nrfiles,len_atime_ID], /short)
       ncdf_attput, cdfid, atimeNearestApproach, 'long_name', 'Text version of timeNearestApproach (UTC) for original files'
       ncdf_attput, cdfid, atimeNearestApproach, 'units', 'string'

     timeSweepStart=ncdf_vardef(cdfid,'grid_timeSweepStart', [nrfiles,elevangle], /double)
       ncdf_attput, cdfid, timeSweepStart, 'long_name', 'Seconds since 01-01-1970 00:00:00 for original files'
       ncdf_attput, cdfid, timeSweepStart, 'units', 'seconds'

     atimeSweepStart=ncdf_vardef(cdfid,'grid_atimeSweepStart', [nrfiles,len_atime_ID,elevangle], /short)
       ncdf_attput, cdfid, atimeSweepStart, 'long_name', 'Text version of timeSweepStart (UTC) for original files'
       ncdf_attput, cdfid, atimeSweepStart, 'units', 'string'

     site_ID=ncdf_vardef(cdfid,'grid_site_ID',[nrfiles,len_site_ID], /byte)
        ncdf_attput, cdfid, site_ID, 'long_name', 'ID of Ground Radar Site'

     site_lat=ncdf_vardef(cdfid,'grid_site_lat',[nrfiles])
       ncdf_attput, cdfid, site_lat, 'long_name', 'Latitude of Ground Radar Site for each of the radars used in this file'
       ncdf_attput, cdfid, site_lat, 'units', 'Degrees North'

     site_lon=ncdf_vardef(cdfid,'grid_site_lon',[nrfiles])
       ncdf_attput, cdfid, site_lon, 'long_name', 'Longitude of Ground Radar Site for each of the radars used in this file'
       ncdf_attput, cdfid, site_lon, 'units', 'Degrees East'

     site_elev=ncdf_vardef(cdfid,'grid_site_elev',[nrfiles])
       ncdf_attput, cdfid, site_elev, 'long_name',$
       'Elevation of Ground Radar Site above MSL in km for each of the radars used in this file'
       ncdf_attput, cdfid, site_elev, 'units', 'km'

     elevationAngle=ncdf_vardef(cdfid,'grid_elevationAngle',[nrfiles,elevangle])
       ncdf_attput, cdfid, elevationAngle, 'long_name', $
       'Radar Sweep Elevation Angles for each of the radars used in this file'
       ncdf_attput, cdfid, elevationAngle, 'units','degrees'

     rangeThreshold=ncdf_vardef(cdfid,'grid_rangeThreshold',[nrfiles])
       ncdf_attput, cdfid, rangeThreshold, 'long_name', $
       'Dataset maximum range from radar site for each of the radars used in this file'
       ncdf_attput, cdfid, rangeThreshold, 'units', 'km'

     DPR_dBZ_min=ncdf_vardef(cdfid,'grid_DPR_dBZ_min',[nrfiles])
       ncdf_attput, cdfid,DPR_dBZ_min, 'long_name', $
       'Minimum DPR bin dBZ required for a complete DPR vertical average for each of the radars used in this file'
       ncdf_attput, cdfid,DPR_dBZ_min, 'units', 'dBZ'

     GR_dBZ_min=ncdf_vardef(cdfid,'grid_GR_dBZ_min',[nrfiles])
       ncdf_attput, cdfid, GR_dBZ_min, 'long_name', $
       'Minimum GR bin dBZ required for a complete GR vertical average for each of the radars used in this file'
       ncdf_attput, cdfid,GR_dBZ_min, 'units', 'dBZ'

     rain_min=ncdf_vardef(cdfid,'grid_rain_min',[nrfiles])
       ncdf_attput, cdfid, rain_min, 'long_name', $
       'Minimum DPR rainrate required for a complete DPR vertical average for each of the radars used in this file'
       ncdf_attput, cdfid, rain_min, 'units', 'mm/hr'

     Year_MS=ncdf_vardef(cdfid,'grid_Year_MS',[nrdate_el,nrfiles], /short)
       ncdf_attput, cdfid, Year_MS, 'long_name', $
       'Year of DPR MS scan for each of the radars used in this file'

     Month_MS=ncdf_vardef(cdfid,'grid_Month_MS',[nrdate_el,nrfiles], /short)
       ncdf_attput, cdfid, Month_MS, 'long_name', $
       'Month of DPR MS scan for each of the radars used in this file'

     DayOfMonth_MS=ncdf_vardef(cdfid,'grid_DayOfMonth_MS',[nrdate_el,nrfiles], /short)
       ncdf_attput, cdfid, DayOfMonth_MS, 'long_name', $
       'Day Of Month of DPR MS scan for each of the radars used in this file'

     Hour_MS=ncdf_vardef(cdfid,'grid_Hour_MS',[nrdate_el,nrfiles], /short)
       ncdf_attput, cdfid, Hour_MS, 'long_name', $
       'Hour of DPR MS scan for each of the radars used in this file'

     Minute_MS=ncdf_vardef(cdfid,'grid_Minute_MS',[nrdate_el,nrfiles],/short)
       ncdf_attput, cdfid, Minute_MS, 'long_name', $
       'Minute of DPR MS scan for each of the radars used in this file'

     Second_MS=ncdf_vardef(cdfid,'grid_Second_MS',[nrdate_el,nrfiles],/short)
       ncdf_attput, cdfid, Second_MS, 'long_name', $
       'Second of DPR MS scan for each of the radars used in this file'

     Millisecond_MS=ncdf_vardef(cdfid,'grid_Millisecond_MS',[nrdate_el,nrfiles],/short)
       ncdf_attput, cdfid, Millisecond_MS, 'long_name', $
       'Millisecond of DPR MS scan for each of the radars used in this file'

     startScan_MS=ncdf_vardef(cdfid,'grid_startScan_MS',[nrfiles])
       ncdf_attput, cdfid, startScan_MS, 'long_name', $
       'Starting DPR MS overlap scan in original dataset for each of the radars used in this file; zero-based'

     endScan_MS=ncdf_vardef(cdfid,'grid_endScan_MS',[nrfiles])
       ncdf_attput, cdfid, endScan_MS, 'long_name', $
       'Ending DPR MS overlap scan in original dataset for each of the radars used in this file; zero-based'

     numRays_MS=ncdf_vardef(cdfid,'grid_numRays_MS',[nrfiles])
       ncdf_attput, cdfid, numRays_MS, 'long_name', $
       'Number of DPR MS rays per scan in original datasetfor each of the radars used in this file'

     Year_NS=ncdf_vardef(cdfid,'grid_Year_NS',[nrdate_el,nrfiles],/short)
       ncdf_attput, cdfid, Year_NS, 'long_name', $
       'Year of DPR NS scan for each of the radars used in this file'

     Month_NS=ncdf_vardef(cdfid,'grid_Month_NS',[nrdate_el,nrfiles],/short)
       ncdf_attput, cdfid, Month_NS, 'long_name', $
       'Month of DPR NS scan for each of the radars used in this file'

     DayOfMonth_NS=ncdf_vardef(cdfid,'grid_DayOfMonth_NS',[nrdate_el,nrfiles],/short)
       ncdf_attput, cdfid, DayOfMonth_NS, 'long_name', $
       'Day Of Month of DPR NS scan for each of the radars used in this file'

     Hour_NS=ncdf_vardef(cdfid,'grid_Hour_NS',[nrdate_el,nrfiles],/short)
       ncdf_attput, cdfid, Hour_NS, 'long_name', $
       'Hour of DPR NS scan for each of the radars used in this file'

     Minute_NS=ncdf_vardef(cdfid,'grid_Minute_NS',[nrdate_el,nrfiles],/short)
       ncdf_attput, cdfid, Minute_NS, 'long_name', $
       'Minute of DPR NS scan for each of the radars used in this file'

     Second_NS=ncdf_vardef(cdfid,'grid_Second_NS',[nrdate_el,nrfiles],/short)
       ncdf_attput, cdfid, Second_NS, 'long_name', $
       'Second of DPR NS scan for each of the radars used in this file'

     Millisecond_NS=ncdf_vardef(cdfid,'grid_Millisecond_NS',[nrdate_el,nrfiles],/short)
       ncdf_attput, cdfid, Millisecond_NS, 'long_name', $
       'Millisecond of DPR NS scan for each of the radars used in this file'

     startScan_NS=ncdf_vardef(cdfid,'grid_startScan_NS',[nrfiles])
       ncdf_attput, cdfid, startScan_NS, 'long_name', $
       'Starting DPR NS overlap scan in original dataset for each of the radars used in this file; zero-based'

     endScan_NS=ncdf_vardef(cdfid,'grid_endScan_NS',[nrfiles])
       ncdf_attput, cdfid, endScan_NS, 'long_name', $
       'Ending DPR NS overlap scan in original dataset for each of the radars used in this file; zero-based'

     numRays_NS=ncdf_vardef(cdfid,'grid_numRays_NS',[nrfiles])
       ncdf_attput, cdfid, numRays_NS, 'long_name', $
       'Number of DPR NS rays per scan in original datasetfor each of the radars used in this file'

     ;For the MS variables that are a function of the actual grid:
     latitude_MS=ncdf_vardef(cdfid,'grid_latitude_MS', [xgridid,ygridid,zgridid])
       ncdf_attput, cdfid, latitude_MS, 'long_name', $
       'Latitude of the original MS dataset for each of the radars used in this file'
       ncdf_attput, cdfid, latitude_MS, 'units', 'degrees North'

     longitude_MS=ncdf_vardef(cdfid,'grid_longitude_MS', [xgridid,ygridid,zgridid])
       ncdf_attput, cdfid, longitude_MS, 'long_name', $
       'Longitude of the original MS dataset of all MS points that occurred in each 5x5x1 km grid box'
       ncdf_attput, cdfid, longitude_MS, 'units', 'degrees East'

     topHeight_MS_MSL=ncdf_vardef(cdfid, 'grid_topHeight_MS_MSL', [xgridid,ygridid,zgridid])
       ncdf_attput, cdfid, topHeight_MS_MSL, 'long_name', $
       'Data sample top height in MSL of all MS points that occurred in each 5x5x1 km grid box'
       ncdf_attput, cdfid, topHeight_MS_MSL, 'units', 'km'

     topHeight_MS=ncdf_vardef(cdfid, 'grid_topHeight_MS', [xgridid,ygridid,zgridid])
       ncdf_attput, cdfid, topHeight_MS, 'long_name', $
       'Data sample top height in AGL of all MS points that occurred in each 5x5x1 km grid box'
       ncdf_attput, cdfid, topHeight_MS, 'units', 'km'

     bottomHeight_MS_MSL=ncdf_vardef(cdfid, 'grid_bottomHeight_MS_MSL', [xgridid,ygridid,zgridid])
       ncdf_attput, cdfid, bottomHeight_MS_MSL, 'long_name', $
       'Data sample bottom height in MSL of all MS points that occurred in each 5x5x1 km grid box'
       ncdf_attput, cdfid, bottomHeight_MS_MSL, 'units', 'km'

     bottomHeight_MS=ncdf_vardef(cdfid, 'grid_bottomHeight_MS', [xgridid,ygridid,zgridid])
       ncdf_attput, cdfid, bottomHeight_MS, 'long_name', $
       'Data sample bottom height in AGL of all MS points that occurred in each 5x5x1 km grid box'
       ncdf_attput, cdfid, bottomHeight_MS, 'units', 'km'

     GR_Z_MS=ncdf_vardef(cdfid,'grid_GR_Z_MS',[xgridid,ygridid,zgridid])
       ncdf_attput, cdfid, GR_Z_MS, 'long_name', $
       'Median reflectivity of all MS GV radar QC reflectivity that occurred in each 5x5x1 km grid box'
       ncdf_attput, cdfid, GR_Z_MS, 'units', 'dBZ'

     GR_Z_StdDev_MS=ncdf_vardef(cdfid,'grid_GR_Z_StdDev_MS',[xgridid,ygridid,zgridid])
       ncdf_attput, cdfid, GR_Z_StdDev_MS, 'long_name', $
       'Standard deviation of MS GV radar QC reflectivity that occurred at the same location as the Median reflectivity (grid_GR_Z_MS)'
       ncdf_attput, cdfid, GR_Z_StdDev_MS, 'units', 'dBZ'

     GR_Z_Max_MS=ncdf_vardef(cdfid,'grid_GR_Z_Max_MS',[xgridid,ygridid,zgridid])
       ncdf_attput, cdfid, GR_Z_Max_MS, 'long_name', $
       'Sample maximum of GV radar QC reflectivity that occurred at the same location as the Median reflectivity (grid_GR_Z_MS)'
       ncdf_attput, cdfid, GR_Z_Max_MS, 'units', 'dBZ'

     GR_Zdr_MS=ncdf_vardef(cdfid,'grid_GR_Zdr_MS',[xgridid,ygridid,zgridid])
       ncdf_attput, cdfid, GR_Zdr_MS, 'long_name', $
       'DP Differential reflectivity that occurred at the same location as the Median reflectivity (grid_GR_Z_MS)'
       ncdf_attput, cdfid, GR_Zdr_MS, 'units', 'dB'

     GR_Zdr_StdDev_MS=ncdf_vardef(cdfid,'grid_GR_Zdr_StdDev_MS',[xgridid,ygridid,zgridid])
       ncdf_attput, cdfid, GR_Zdr_StdDev_MS, 'long_name', $
       'Standard deviation of DP differential reflectivity that occurred at the same location as the Median reflectivity (grid_GR_Z_MS)'
       ncdf_attput, cdfid, GR_Zdr_StdDev_MS, 'units', 'dB'

     GR_Zdr_Max_MS=ncdf_vardef(cdfid,'grid_GR_Zdr_Max_MS',[xgridid,ygridid,zgridid])
       ncdf_attput, cdfid, GR_Zdr_Max_MS, 'long_name', $
       'Sample maximum of DP differential reflectivity that occurred at the same location as the Median reflectivity (grid_GR_Z_MS)'
       ncdf_attput, cdfid, GR_Zdr_Max_MS, 'units', 'dB'

     GR_Kdp_MS=ncdf_vardef(cdfid,'grid_GR_Kdp_MS',[xgridid,ygridid,zgridid])
       ncdf_attput, cdfid, GR_Kdp_MS, 'long_name', $
       'DP Specific Differential Phase that occurred at the same location as the Median reflectivity (grid_GR_Z_MS)'
       ncdf_attput, cdfid, GR_Kdp_MS, 'units', 'deg/km'

     GR_Kdp_StdDev_MS=ncdf_vardef(cdfid,'grid_GR_Kdp_StdDev_MS',[xgridid,ygridid,zgridid])
       ncdf_attput, cdfid, GR_Kdp_StdDev_MS, 'long_name', $
       'Standard deviation of DP Specific Differential Phase that occurred at the same location as the Median reflectivity (grid_GR_Z_MS)'
       ncdf_attput, cdfid, GR_Kdp_StdDev_MS, 'units', 'deg/km'

     GR_Kdp_Max_MS=ncdf_vardef(cdfid,'grid_GR_Kdp_Max_MS',[xgridid,ygridid,zgridid])
       ncdf_attput, cdfid, GR_Kdp_Max_MS, 'long_name', $
       'Sample maximum of DP Specific Differential Phase that occurred at the same location as the Median reflectivity (grid_GR_Z_MS)'
       ncdf_attput, cdfid, GR_Kdp_Max_MS, 'units', 'deg/km'

     GR_RHOhv_MS=ncdf_vardef(cdfid,'grid_GR_RHOhv_MS',[xgridid,ygridid,zgridid])
       ncdf_attput, cdfid, GR_RHOhv_MS, 'long_name', $
       'DP Co-Polar Correlation Coefficient that occurred at the same location as the Median reflectivity (grid_GR_Z_MS)'
       ncdf_attput, cdfid, GR_RHOhv_MS, 'units', 'unitless'

     GR_RHOhv_StdDev_MS=ncdf_vardef(cdfid,'grid_GR_RHOhv_StdDev_MS',[xgridid,ygridid,zgridid])
       ncdf_attput, cdfid, GR_RHOhv_StdDev_MS, 'long_name', $
       'Standard deviation of DP Co-Polar Correlation Coefficient that occurred at the same location as the Median reflectivity (grid_GR_Z_MS)'
       ncdf_attput, cdfid, GR_RHOhv_StdDev_MS, 'units', 'unitless'

     GR_RHOhv_Max_MS=ncdf_vardef(cdfid,'grid_GR_RHOhv_Max_MS',[xgridid,ygridid,zgridid])
       ncdf_attput, cdfid, GR_RHOhv_Max_MS, 'long_name', $
       'Sample maximum of DP Co-Polar Correlation Coefficient that occurred at the same location as the Median reflectivity (grid_GR_Z_MS)'
       ncdf_attput, cdfid, GR_RHOhv_Max_MS, 'units', 'unitless'

     GR_RC_rainrate_MS=ncdf_vardef(cdfid,'grid_GR_RC_rainrate_MS',[xgridid,ygridid,zgridid])
       ncdf_attput, cdfid, GR_RC_rainrate_MS, 'long_name', $
       'GV radar Cifelli Rainrate that occurred at the same location as the Median reflectivity (grid_GR_Z_MS)'
       ncdf_attput, cdfid, GR_RC_rainrate_MS, 'units', 'mm/hr'

     GR_RC_rainrate_StdDev_MS=ncdf_vardef(cdfid,'grid_GR_RC_rainrate_StdDev_MS',[xgridid,ygridid,zgridid])
       ncdf_attput, cdfid, GR_RC_rainrate_StdDev_MS, 'long_name', $
       'Standard deviation of GV radar Cifelli Rainrate that occurred at the same location as the Median reflectivity (grid_GR_Z_MS)'
       ncdf_attput, cdfid, GR_RC_rainrate_StdDev_MS, 'units', 'mm/hr'

     GR_RC_rainrate_Max_MS=ncdf_vardef(cdfid,'grid_GR_RC_rainrate_Max_MS',[xgridid,ygridid,zgridid])
       ncdf_attput, cdfid, GR_RC_rainrate_Max_MS, 'long_name', $
       'Sample maximum of GV radar Cifelli Rainrate that occurred at the same location as the Median reflectivity (grid_GR_Z_MS)'
       ncdf_attput, cdfid, GR_RC_rainrate_Max_MS, 'units', 'mm/hr'

     GR_RP_rainrate_MS=ncdf_vardef(cdfid,'grid_GR_RP_rainrate_MS',[xgridid,ygridid,zgridid])
       ncdf_attput, cdfid, GR_RP_rainrate_MS, 'long_name', $
       'GV radar PolZR Rainrate that occurred at the same location as the Median reflectivity (grid_GR_Z_MS)'
       ncdf_attput, cdfid, GR_RP_rainrate_MS, 'units', 'mm/hr'

     GR_RP_rainrate_StdDev_MS=ncdf_vardef(cdfid,'grid_GR_RP_rainrate_StdDev_MS',[xgridid,ygridid,zgridid])
       ncdf_attput, cdfid, GR_RP_rainrate_StdDev_MS, 'long_name', $
       'Standard deviation of GV radar PolZR Rainrate that occurred at the same location as the Median reflectivity (grid_GR_Z_MS)'
       ncdf_attput, cdfid, GR_RP_rainrate_StdDev_MS, 'units', 'mm/hr'

     GR_RP_rainrate_Max_MS=ncdf_vardef(cdfid,'grid_GR_RP_rainrate_Max_MS',[xgridid,ygridid,zgridid])
       ncdf_attput, cdfid, GR_RP_rainrate_Max_MS, 'long_name', $
       'Sample maximum of GV radar PolZR Rainrate that occurred at the same location as the Median reflectivity (grid_GR_Z_MS)'
       ncdf_attput, cdfid, GR_RP_rainrate_Max_MS, 'units', 'mm/hr'

     GR_RR_rainrate_MS=ncdf_vardef(cdfid,'grid_GR_RR_rainrate_MS',[xgridid,ygridid,zgridid])
       ncdf_attput, cdfid, GR_RR_rainrate_MS, 'long_name', $
       'GV radar DROPS Rainrate that occurred at the same location as the Median reflectivity (grid_GR_Z_MS)'
       ncdf_attput, cdfid, GR_RR_rainrate_MS, 'units', 'mm/hr'

     GR_RR_rainrate_StdDev_MS=ncdf_vardef(cdfid,'grid_GR_RR_rainrate_StdDev_MS',[xgridid,ygridid,zgridid])
       ncdf_attput, cdfid, GR_RR_rainrate_StdDev_MS, 'long_name', $
       'Standard deviation of GV radar DROPS Rainrate that occurred at the same location as the Median reflectivity (grid_GR_Z_MS)'
       ncdf_attput, cdfid, GR_RR_rainrate_StdDev_MS, 'units', 'mm/hr'

     GR_RR_rainrate_Max_MS=ncdf_vardef(cdfid,'grid_GR_RR_rainrate_Max_MS',[xgridid,ygridid,zgridid])
       ncdf_attput, cdfid, GR_RR_rainrate_Max_MS, 'long_name', $
       'Sample maximum of GV radar DROPS Rainrate that occurred at the same location as the Median reflectivity (grid_GR_Z_MS)'
       ncdf_attput, cdfid, GR_RR_rainrate_Max_MS, 'units', 'mm/hr'

     GR_HID_MS=ncdf_vardef(cdfid, 'grid_GR_HID_MS', [hidimid,xgridid,ygridid,zgridid],/short)
       ncdf_attput, cdfid, GR_HID_MS, 'long_name', $
       'DP Hydrometeor Identification concentration that occurred at the same location as the Median reflectivity (grid_GR_Z_MS)'
       ncdf_attput, cdfid, GR_HID_MS, 'units', 'categorical'

     GR_Dzero_MS=ncdf_vardef(cdfid,'grid_GR_Dzero_MS',[xgridid,ygridid,zgridid])
       ncdf_attput, cdfid, GR_Dzero_MS, 'long_name', $
       'DP Median Volume Diameter that occurred at the same location as the Median reflectivity (grid_GR_Z_MS)'
       ncdf_attput, cdfid, GR_Dzero_MS, 'units', 'mm'

     GR_Dzero_StdDev_MS=ncdf_vardef(cdfid,'grid_GR_Dzero_StdDev_MS',[xgridid,ygridid,zgridid])
       ncdf_attput, cdfid, GR_Dzero_StdDev_MS, 'long_name', $
       'Standard deviation of DP Median Volume Diameter that occurred at the same location as the Median reflectivity (grid_GR_Z_MS)'
       ncdf_attput, cdfid, GR_Dzero_StdDev_MS, 'units', 'mm'

     GR_Dzero_Max_MS=ncdf_vardef(cdfid,'grid_GR_Dzero_Max_MS',[xgridid,ygridid,zgridid])
       ncdf_attput, cdfid, GR_Dzero_Max_MS, 'long_name', $
       'Sample maximum of DP Median Volume Diameter that occurred at the same location as the Median reflectivity (grid_GR_Z_MS)'
       ncdf_attput, cdfid, GR_Dzero_Max_MS, 'units', 'mm'

     GR_Nw_MS=ncdf_vardef(cdfid,'grid_GR_Nw_MS',[xgridid,ygridid,zgridid])
       ncdf_attput, cdfid, GR_Nw_MS, 'long_name', $
       'DP Normalized Intercept Parameter that occurred at the same location as the Median reflectivity (grid_GR_Z_MS)'
       ncdf_attput, cdfid, GR_Nw_MS, 'units', '1/(mm*m^3)'

     GR_Nw_StdDev_MS=ncdf_vardef(cdfid,'grid_GR_Nw_StdDev_MS',[xgridid,ygridid,zgridid])
       ncdf_attput, cdfid, GR_Nw_StdDev_MS, 'long_name', $
       'Standard deviation of DP Normalized Intercept Parameter that occurred at the same location as the Median reflectivity (grid_GR_Z_MS)'
       ncdf_attput, cdfid, GR_Nw_StdDev_MS, 'units', '1/(mm*m^3)'

     GR_Nw_Max_MS=ncdf_vardef(cdfid,'grid_GR_Nw_Max_MS',[xgridid,ygridid,zgridid])
       ncdf_attput, cdfid, GR_Nw_Max_MS, 'long_name', $
       'Sample maximum of DP Normalized Intercept Parameter that occurred at the same location as the Median reflectivity (grid_GR_Z_MS)'
       ncdf_attput, cdfid, GR_Nw_Max_MS, 'units', '1/(mm*m^3)'

     GR_Dm_MS=ncdf_vardef(cdfid,'grid_GR_Dm_MS',[xgridid,ygridid,zgridid])
       ncdf_attput, cdfid, GR_Dm_MS, 'long_name', $
       'DP Retrieved Median Diameter that occurred at the same location as the Median reflectivity (grid_GR_Z_MS)'
       ncdf_attput, cdfid, GR_Dm_MS, 'units', 'mm'

     GR_Dm_StdDev_MS=ncdf_vardef(cdfid,'grid_GR_Dm_StdDev_MS',[xgridid,ygridid,zgridid])
       ncdf_attput, cdfid, GR_Dm_StdDev_MS, 'long_name', $
       'Standard deviation of DP Retrieved Median Diameter that occurred at the same location as the Median reflectivity (grid_GR_Z_MS)'
       ncdf_attput, cdfid, GR_Dm_StdDev_MS, 'units', 'mm'

     GR_Dm_Max_MS=ncdf_vardef(cdfid,'grid_GR_Dm_Max_MS',[xgridid,ygridid,zgridid])
       ncdf_attput, cdfid, GR_Dm_Max_MS, 'long_name', $
       'Sample maximum of DP Retrieved Median Diameter that occurred at the same location as the Median reflectivity (grid_GR_Z_MS)'
       ncdf_attput, cdfid, GR_Dm_Max_MS, 'units', 'mm'

     GR_N2_MS=ncdf_vardef(cdfid,'grid_GR_N2_MS',[xgridid,ygridid,zgridid])
       ncdf_attput, cdfid, GR_N2_MS, 'long_name', $
       'Tokay Normalized Intercept Parameter that occurred at the same location as the Median reflectivity (grid_GR_Z_MS)'
       ncdf_attput, cdfid, GR_N2_MS, 'units', '1/(mm*m^3)'

     GR_N2_StdDev_MS=ncdf_vardef(cdfid,'grid_GR_N2_StdDev_MS',[xgridid,ygridid,zgridid])
       ncdf_attput, cdfid, GR_N2_StdDev_MS, 'long_name', $
       'Standard deviation of Tokay Normalized Intercept Parameter that occurred at the same location as the Median reflectivity (grid_GR_Z_MS)'
       ncdf_attput, cdfid, GR_N2_StdDev_MS, 'units', '1/(mm*m^3)'

     GR_N2_Max_MS=ncdf_vardef(cdfid,'grid_GR_N2_Max_MS',[xgridid,ygridid,zgridid])
       ncdf_attput, cdfid, GR_N2_Max_MS, 'long_name', $
       'Sample maximum of Tokay Normalized Intercept Parameter that occurred at the same location as the Median reflectivity (grid_GR_Z_MS)'
       ncdf_attput, cdfid, GR_N2_Max_MS, 'units', '1/(mm*m^3)'

     GR_blockage_MS=ncdf_vardef(cdfid,'grid_GR_blockage_MS', [xgridid,ygridid,zgridid])
       ncdf_attput, cdfid, GR_blockage_MS, 'long_name', $
      'Ground Radar Blockage Fraction that occurred at the same location as the Median reflectivity (grid_GR_Z_MS)'

     n_gr_z_rejected_MS=ncdf_vardef(cdfid,'grid_n_gr_z_rejected_MS', [xgridid,ygridid,zgridid], /short)
       ncdf_attput, cdfid, n_gr_z_rejected_MS, 'long_name', $
       'Number of bins below GR_dBZ_min in GR_Z average at the same location as the Median reflectivity (grid_GR_Z_MS)'

     n_gr_zdr_rejected_MS=ncdf_vardef(cdfid,'grid_n_gr_zdr_rejected_MS', [xgridid,ygridid,zgridid], /short)
       ncdf_attput, cdfid, n_gr_zdr_rejected_MS, 'long_name', $
       'Number of bins with missing Zdr in GR_Zdr average at the same location as the Median reflectivity (grid_GR_Z_MS)'

     n_gr_kdp_rejected_MS=ncdf_vardef(cdfid,'grid_n_gr_kdp_rejected_MS', [xgridid,ygridid,zgridid], /short)
       ncdf_attput, cdfid, n_gr_kdp_rejected_MS, 'long_name', $
       'Number of bins with missing Kdp in GR_Kdp average at the same location as the Median reflectivity (grid_GR_Z_MS)'

     n_gr_rhohv_rejected_MS=ncdf_vardef(cdfid,'grid_n_gr_rhohv_rejected_MS', [xgridid,ygridid,zgridid], /short)
       ncdf_attput, cdfid, n_gr_rhohv_rejected_MS, 'long_name', $
       'Number of bins with missing RHOhv in GR_RHOhv average at the same location as the Median reflectivity (grid_GR_Z_MS)'

     n_gr_rc_rejected_MS=ncdf_vardef(cdfid,'grid_n_gr_rc_rejected_MS', [xgridid,ygridid,zgridid], /short)
       ncdf_attput, cdfid, n_gr_rc_rejected_MS, 'long_name', $
       'Number of bins below rain_min in GR_RC_rainrate average at the same location as the Median reflectivity (grid_GR_Z_MS)'

     n_gr_rp_rejected_MS=ncdf_vardef(cdfid,'grid_n_gr_rp_rejected_MS', [xgridid,ygridid,zgridid], /short)
       ncdf_attput, cdfid, n_gr_rp_rejected_MS, 'long_name', $
       'Number of bins below rain_min in GR_RP_rainrate average at the same location as the Median reflectivity (grid_GR_Z_MS)'

     n_gr_rr_rejected_MS=ncdf_vardef(cdfid,'grid_n_gr_rr_rejected_MS', [xgridid,ygridid,zgridid], /short)
       ncdf_attput, cdfid, n_gr_rr_rejected_MS, 'long_name', $
       'Number of bins below rain_min in GR_RR_rainrate average at the same location as the Median reflectivity (grid_GR_Z_MS)'

     n_gr_hid_rejected_MS=ncdf_vardef(cdfid,'grid_n_gr_hid_rejected_MS', [xgridid,ygridid,zgridid], /short)
       ncdf_attput, cdfid, n_gr_hid_rejected_MS, 'long_name', $
       'Number of bins with undefined HID in GR_HID histogram for the 5x5x1 grid'

     n_gr_dzero_rejected_MS=ncdf_vardef(cdfid,'grid_n_gr_dzero_rejected_MS', [xgridid,ygridid,zgridid], /short)
       ncdf_attput, cdfid, n_gr_dzero_rejected_MS, 'long_name', $
       'Number of bins with missing D0 in GR_Dzero average at the same location as the Median reflectivity (grid_GR_Z_MS)'

     n_gr_nw_rejected_MS=ncdf_vardef(cdfid,'grid_n_gr_nw_rejected_MS', [xgridid,ygridid,zgridid], /short)
       ncdf_attput, cdfid, n_gr_nw_rejected_MS, 'long_name', $
       'Number of bins with missing Nw in GR_Nw average at the same location as the Median reflectivity (grid_GR_Z_MS)'

     n_gr_dm_rejected_MS=ncdf_vardef(cdfid,'grid_n_gr_dm_rejected_MS', [xgridid,ygridid,zgridid], /short)
       ncdf_attput, cdfid, n_gr_dm_rejected_MS, 'long_name', $
       'Number of bins with missing Dm in GR_Dm average at the same location as the Median reflectivity (grid_GR_Z_MS)'

     n_gr_n2_rejected_MS=ncdf_vardef(cdfid,'grid_n_gr_n2_rejected_MS', [xgridid,ygridid,zgridid], /short)
       ncdf_attput, cdfid, n_gr_n2_rejected_MS, 'long_name', $
       'Number of bins with missing N2 in GR_N2 average at the same location as the Median reflectivity (grid_GR_Z_MS)'

     n_gr_expected_MS=ncdf_vardef(cdfid,'grid_n_gr_expected_MS', [xgridid,ygridid,zgridid], /short)
       ncdf_attput, cdfid, n_gr_expected_MS, 'long_name', $
       'Number of bins in GR_Z average at the same location as the Median reflectivity (grid_GR_Z_MS)'

     precipTotPSDparamHigh_MS=ncdf_vardef(cdfid,'grid_precipTotPSDparamHigh_MS', [xgridid,ygridid,zgridid])
       ncdf_attput, cdfid, precipTotPSDparamHigh_MS, 'long_name', $
       '2B-DPRGMI precipTotPSDparamHigh for MS swath at the same location as the Median reflectivity (grid_GR_Z_MS)'
       ncdf_attput, cdfid, precipTotPSDparamHigh_MS, 'units', 'mm_Dm'

     precipTotPSDparamLow_MS=ncdf_vardef(cdfid,'grid_precipTotPSDparamLow_MS', [nKuKa,xgridid,ygridid,zgridid])
       ncdf_attput, cdfid, precipTotPSDparamLow_MS, 'long_name', $
       '2B-DPRGMI precipTotPSDparamLow for MS swath at the same location as the Median reflectivity (grid_GR_Z_MS)'
       ncdf_attput, cdfid, precipTotPSDparamLow_MS, 'units', 'Nw_mu'

     precipTotRate_MS=ncdf_vardef(cdfid,'grid_precipTotRate_MS', [xgridid,ygridid,zgridid])
       ncdf_attput, cdfid, precipTotRate_MS, 'long_name', $
       '2B-DPRGMI precipTotRate for MS swath at the same location as the Median reflectivity (grid_GR_Z_MS)'
       ncdf_attput, cdfid, precipTotRate_MS, 'units', 'mm/hr'

     precipTotWaterCont_MS=ncdf_vardef(cdfid,'grid_precipTotWaterCont_MS', [xgridid,ygridid,zgridid])
       ncdf_attput, cdfid, precipTotWaterCont_MS, 'long_name', $
       '2B-DPRGMI precipTotWaterCont for MS swath  at the same location as the Median reflectivity (grid_GR_Z_MS)'
       ncdf_attput, cdfid, precipTotWaterCont_MS, 'units', 'g/m^3'

     n_precipTotPSDparamHigh_rejected_MS=ncdf_vardef(cdfid,'grid_n_precipTotPSDparamHigh_rejected_MS', [xgridid,ygridid,zgridid], /short)
       ncdf_attput, cdfid, n_precipTotPSDparamHigh_rejected_MS, 'long_name', $
       'Number of bins below rain_min in precipTotPSDparamHigh average for MS swath at the same location as the Median reflectivity (grid_GR_Z_MS)'

     n_precipTotPSDparamLow_rejected_MS=ncdf_vardef(cdfid,'grid_n_precipTotPSDparamLow_rejected_MS', [nKuKa,xgridid,ygridid,zgridid], /short)
       ncdf_attput, cdfid, n_precipTotPSDparamLow_rejected_MS, 'long_name', $
       'Number of bins below rain_min in precipTotPSDparamLow average for MS swath at the same location as the Median reflectivity (grid_GR_Z_MS)'

     n_precipTotRate_rejected_MS=ncdf_vardef(cdfid,'grid_n_precipTotRate_rejected_MS', [xgridid,ygridid,zgridid], /short)
       ncdf_attput, cdfid, n_precipTotRate_rejected_MS, 'long_name', $
       'Number of bins below rain_min in precipTotRate average for MS swath at the same location as the Median reflectivity (grid_GR_Z_MS)'

     n_precipTotWaterCont_rejected_MS=ncdf_vardef(cdfid,'grid_n_precipTotWaterCont_rejected_MS', [xgridid,ygridid,zgridid], /short)
       ncdf_attput, cdfid, n_precipTotWaterCont_rejected_MS, 'long_name', $
       'Number of bins below rain_min in precipTotWaterCont average for MS swath at the same location as the Median reflectivity (grid_GR_Z_MS)'

     precipitationType_MS=ncdf_vardef(cdfid,'grid_precipitationType_MS', [xgridid,ygridid], /short)
       ncdf_attput, cdfid, precipitationType_MS, 'long_name', $
       '2B-DPRGMI precipitationType for MS swath at the same location as the ground location of the Median reflectivity (grid_GR_Z_MS)'
       ncdf_attput, cdfid, precipitationType_MS, 'units', 'categorical'

     surfPrecipTotRate_MS=ncdf_vardef(cdfid,'grid_surfPrecipTotRate_MS', [xgridid,ygridid])
       ncdf_attput, cdfid, surfPrecipTotRate_MS, 'long_name', $
       '2B-DPRGMI surfPrecipTotRate for MS swath at the same location as the ground location of the Median reflectivity (grid_GR_Z_MS)'
       ncdf_attput, cdfid, surfPrecipTotRate_MS, 'units', 'mm/hr'

     surfaceElevation_MS=ncdf_vardef(cdfid,'grid_surfaceElevation_MS', [xgridid,ygridid])
       ncdf_attput, cdfid, surfaceElevation_MS, 'long_name', $
       '2B-DPRGMI surfaceElevation for MS swath at the same location as the ground location of the Median reflectivity (grid_GR_Z_MS)'
       ncdf_attput, cdfid, surfaceElevation_MS, 'units', 'm'

     zeroDegAltitude_MS=ncdf_vardef(cdfid,'grid_zeroDegAltitude_MS', [xgridid,ygridid])
       ncdf_attput, cdfid, zeroDegAltitude_MS, 'long_name', $
       '2B-DPRGMI zeroDegAltitude for MS swath at the same location as the ground location of the Median reflectivity (grid_GR_Z_MS)'
       ncdf_attput, cdfid, zeroDegAltitude_MS, 'units', 'm'

     zeroDegBin_MS=ncdf_vardef(cdfid,'grid_zeroDegBin_MS', [xgridid,ygridid], /short)
       ncdf_attput, cdfid, zeroDegBin_MS, 'long_name', $
       '2B-DPRGMI zeroDegBin for MS swath at the same location as the ground location of the Median reflectivity (grid_GR_Z_MS)'
       ncdf_attput, cdfid, zeroDegBin_MS, 'units', 'N/A'

     surfaceType_MS=ncdf_vardef(cdfid,'grid_surfaceType_MS', [xgridid,ygridid], /short)
       ncdf_attput, cdfid, surfaceType_MS, 'long_name', $
       '2B-DPRGMI surfaceType for MS swath at the same location as the ground location of the Median reflectivity (grid_GR_Z_MS)'
       ncdf_attput, cdfid, surfaceType_MS, 'units', 'categorical'

     phaseBinNodes_MS=ncdf_vardef(cdfid,'grid_phaseBinNodes_MS', [nPhsBnN,xgridid,ygridid], /short)
       ncdf_attput, cdfid, phaseBinNodes_MS, 'long_name', $
       '2B-DPRGMI phaseBinNodes for MS swath at the same location as the ground location of the Median reflectivity (grid_GR_Z_MS)'
       ncdf_attput, cdfid, phaseBinNodes_MS, 'units', 'N/A'

     DPRlatitude_MS=ncdf_vardef(cdfid,'grid_DPRlatitude_MS', [xgridid,ygridid])
       ncdf_attput, cdfid, DPRlatitude_MS, 'long_name', $
       'Latitude of DPR surface bin for MS swath at the same location as the ground location of the Median reflectivity (grid_GR_Z_MS)'
       ncdf_attput, cdfid, DPRlatitude_MS, 'units', 'degrees North'

     DPRlongitude_MS=ncdf_vardef(cdfid,'grid_DPRlongitude_MS', [xgridid,ygridid])
       ncdf_attput, cdfid, DPRlongitude_MS, 'long_name', $
       'Longitude of DPR surface bin for MS swath at the same location as the ground location of the Median reflectivity (grid_GR_Z_MS)'
       ncdf_attput, cdfid, DPRlongitude_MS, 'units', 'degrees East'

     scanNum_MS=ncdf_vardef(cdfid,'grid_scanNum_MS', [xgridid,ygridid], /short)
       ncdf_attput, cdfid, scanNum_MS, 'long_name', $
       'Product-relative zero-based DPR scan number for MS swath at the same location as the ground location of the Median reflectivity (grid_GR_Z_MS)'

     rayNum_MS=ncdf_vardef(cdfid,'grid_rayNum_MS', [xgridid,ygridid], /short)
       ncdf_attput, cdfid, rayNum_MS, 'long_name', $
       'Product-relative zero-based DPR ray number for MS swath at the same location as the ground location of the Median reflectivity (grid_GR_Z_MS)'

     ellipsoidBinOffset_MS=ncdf_vardef(cdfid,'grid_ellipsoidBinOffset_MS', [nKuKa,xgridid,ygridid])
       ncdf_attput, cdfid, ellipsoidBinOffset_MS, 'long_name', $
       '2B-DPRGMI Ku and Ka ellipsoidBinOffset for MS swath at the same location as the ground location of the Median reflectivity (grid_GR_Z_MS)'
       ncdf_attput, cdfid, ellipsoidBinOffset_MS, 'units', 'm'

     lowestClutterFreeBin_MS=ncdf_vardef(cdfid,'grid_lowestClutterFreeBin_MS', [nKuKa,xgridid,ygridid], /short)
       ncdf_attput, cdfid, lowestClutterFreeBin_MS, 'long_name', $
       '2B-DPRGMI Ku and Ka lowestClutterFreeBin for MS swath at the same location as the ground location of the Median reflectivity (grid_GR_Z_MS)'

     clutterStatus_MS=ncdf_vardef(cdfid,'grid_clutterStatus_MS', [nKuKa,xgridid,ygridid,zgridid], /short)
       ncdf_attput, cdfid, clutterStatus_MS, 'long_name', $
       'Matchup Ku and Ka clutterStatus for MS swath at the same location as the ground location of the Median reflectivity (grid_GR_Z_MS)'

     precipitationFlag_MS=ncdf_vardef(cdfid,'grid_precipitationFlag_MS', [nKuKa,xgridid,ygridid], /short)
       ncdf_attput, cdfid, precipitationFlag_MS, 'long_name', $
       '2B-DPRGMI Ku and Ka precipitationFlag for MS swath at the same location as the ground location of the Median reflectivity (grid_GR_Z_MS)'
       ncdf_attput, cdfid, precipitationFlag_MS, 'units', 'categorical'

     surfaceRangeBin_MS=ncdf_vardef(cdfid,'grid_surfaceRangeBin_MS', [nKuKa,xgridid,ygridid], /short)
       ncdf_attput, cdfid, surfaceRangeBin_MS, 'long_name', $
       '2B-DPRGMI Ku and Ka surfaceRangeBin for MS swath at the same location as the ground location of the Median reflectivity (grid_GR_Z_MS)'

     correctedReflectFactor_MS=ncdf_vardef(cdfid,'grid_correctedReflectFactor_MS', [nKuKa,xgridid,ygridid,zgridid])
       ncdf_attput, cdfid, correctedReflectFactor_MS, 'long_name', $
       '2B-DPRGMI Ku and Ka Corrected Reflectivity Factor for MS swath at the same location as the ground location of the Median reflectivity (grid_GR_Z_MS)'
       ncdf_attput, cdfid, correctedReflectFactor_MS, 'units', 'dBZ'

     pia_MS=ncdf_vardef(cdfid,'grid_pia_MS', [nKuKa,xgridid,ygridid])
       ncdf_attput, cdfid, pia_MS, 'long_name', $
       '2B-DPRGMI Ku and Ka Path Integrated Attenuation for MS swath at the same location as the ground location of the Median reflectivity (grid_GR_Z_MS)'
       ncdf_attput, cdfid, pia_MS, 'units', 'dB'

     stormTopAltitude_MS=ncdf_vardef(cdfid,'grid_stormTopAltitude_MS', [nKuKa,xgridid,ygridid])
       ncdf_attput, cdfid, stormTopAltitude_MS, 'long_name', $
       '2B-DPRGMI Ku and Ka stormTopAltitude for MS swath for MS swath at the same location as the ground location of the Median reflectivity (grid_GR_Z_MS)'
       ncdf_attput, cdfid, stormTopAltitude_MS, 'units', 'm'

     n_correctedReflectFactor_rejected_MS=ncdf_vardef(cdfid,'grid_n_correctedReflectFactor_rejected_MS', [nKuKa,xgridid,ygridid,zgridid], /short)
       ncdf_attput, cdfid, n_correctedReflectFactor_rejected_MS, 'long_name', $
       'Numbers of Ku and Ka bins below DPR_dBZ_min in correctedReflectFactor average for MS swath at the same location as the ground location of the Median reflectivity (grid_GR_Z_MS)'

     n_dpr_expected_MS=ncdf_vardef(cdfid,'grid_n_dpr_expected_MS', [nKuKa,xgridid,ygridid,zgridid], /short)
       ncdf_attput, cdfid, n_dpr_expected_MS, 'long_name', $
       'Numbers of expected Ku and Ka bins in DPR averages for MS swath at the same location as the ground location of the Median reflectivity (grid_GR_Z_MS)'

     ;Now for the NS swath that are a function of the actual grid:
     latitude_NS=ncdf_vardef(cdfid,'grid_latitude_NS', [xgridid,ygridid,zgridid])
       ncdf_attput, cdfid, latitude_NS, 'long_name', $
       'Latitude of the original NS datasetfor each of the radars used in this file'

     longitude_NS=ncdf_vardef(cdfid,'grid_longitude_NS', [xgridid,ygridid,zgridid])
       ncdf_attput, cdfid, longitude_NS, 'long_name', $
       'Longitude of the original NS dataset of all NS points that occurred in each 5x5x1 km grid box'

     topHeight_NS_MSL=ncdf_vardef(cdfid, 'grid_topHeight_NS_MSL', [xgridid,ygridid,zgridid])
       ncdf_attput, cdfid, topHeight_NS_MSL, 'long_name', $
       'Data sample top height in MSL of all NS points that occurred in each 5x5x1 km grid box'
       ncdf_attput, cdfid, topHeight_NS_MSL, 'units', 'km'

     topHeight_NS=ncdf_vardef(cdfid, 'grid_topHeight_NS', [xgridid,ygridid,zgridid])
       ncdf_attput, cdfid, topHeight_NS, 'long_name', $
       'Data sample top height in AGL of all NS points that occurred in each 5x5x1 km grid box'
       ncdf_attput, cdfid, topHeight_NS, 'units', 'km'

     bottomHeight_NS_MSL=ncdf_vardef(cdfid, 'grid_bottomHeight_NS_MSL', [xgridid,ygridid,zgridid])
       ncdf_attput, cdfid, bottomHeight_NS_MSL, 'long_name', $
       'Data sample bottom height in MSL of all NS points that occurred in each 5x5x1 km grid box'
       ncdf_attput, cdfid, bottomHeight_NS_MSL, 'units', 'km'

     bottomHeight_NS=ncdf_vardef(cdfid, 'grid_bottomHeight_NS', [xgridid,ygridid,zgridid])
       ncdf_attput, cdfid, bottomHeight_NS, 'long_name', $
       'Data sample bottom height in AGL of all NS points that occurred in each 5x5x1 km grid box'
       ncdf_attput, cdfid, bottomHeight_NS, 'units', 'km'

     GR_Z_NS=ncdf_vardef(cdfid,'grid_GR_Z_NS',[xgridid,ygridid,zgridid])
       ncdf_attput, cdfid, GR_Z_NS, 'long_name', $
       'Median reflectivity of all NS GV radar QC reflectivity that occurred in each 5x5x1 km grid box'
       ncdf_attput, cdfid, GR_Z_NS, 'units', 'dBZ'

     GR_Z_StdDev_NS=ncdf_vardef(cdfid,'grid_GR_Z_StdDev_NS',[xgridid,ygridid,zgridid])
       ncdf_attput, cdfid, GR_Z_StdDev_NS, 'long_name', $
       'Standard deviation of NS GV radar QC reflectivity that occurred at the same location as the Median reflectivity (grid_GR_Z_NS)'
       ncdf_attput, cdfid, GR_Z_StdDev_NS, 'units', 'dBZ'

     GR_Z_Max_NS=ncdf_vardef(cdfid,'grid_GR_Z_Max_NS',[xgridid,ygridid,zgridid])
       ncdf_attput, cdfid, GR_Z_Max_NS, 'long_name', $
       'Sample maximum of GV radar QC reflectivity that occurred at the same location as the Median reflectivity (grid_GR_Z_NS)'
       ncdf_attput, cdfid, GR_Z_Max_NS, 'units', 'dBZ'

     GR_Zdr_NS=ncdf_vardef(cdfid,'grid_GR_Zdr_NS',[xgridid,ygridid,zgridid])
       ncdf_attput, cdfid, GR_Zdr_NS, 'long_name', $
       'DP Differential reflectivity that occurred at the same location as the Median reflectivity (grid_GR_Z_NS)'
       ncdf_attput, cdfid, GR_Zdr_NS, 'units', 'dB'

     GR_Zdr_StdDev_NS=ncdf_vardef(cdfid,'grid_GR_Zdr_StdDev_NS',[xgridid,ygridid,zgridid])
       ncdf_attput, cdfid, GR_Zdr_StdDev_NS, 'long_name', $
       'Standard deviation of DP differential reflectivity that occurred at the same location as the Median reflectivity (grid_GR_Z_NS)'
       ncdf_attput, cdfid, GR_Zdr_StdDev_NS, 'units', 'dB'

     GR_Zdr_Max_NS=ncdf_vardef(cdfid,'grid_GR_Zdr_Max_NS',[xgridid,ygridid,zgridid])
       ncdf_attput, cdfid, GR_Zdr_Max_NS, 'long_name', $
       'Sample maximum of DP differential reflectivity that occurred at the same location as the Median reflectivity (grid_GR_Z_NS)'
       ncdf_attput, cdfid, GR_Zdr_Max_NS, 'units', 'dB'

     GR_Kdp_NS=ncdf_vardef(cdfid,'grid_GR_Kdp_NS',[xgridid,ygridid,zgridid])
       ncdf_attput, cdfid, GR_Kdp_NS, 'long_name', $
       'DP Specific Differential Phase that occurred at the same location as the Median reflectivity (grid_GR_Z_NS)'
       ncdf_attput, cdfid, GR_Kdp_NS, 'units', 'deg/km'

     GR_Kdp_StdDev_NS=ncdf_vardef(cdfid,'grid_GR_Kdp_StdDev_NS',[xgridid,ygridid,zgridid])
       ncdf_attput, cdfid, GR_Kdp_StdDev_NS, 'long_name', $
       'Standard deviation of DP Specific Differential Phase that occurred at the same location as the Median reflectivity (grid_GR_Z_NS)'
       ncdf_attput, cdfid, GR_Kdp_StdDev_NS, 'units', 'deg/km'

     GR_Kdp_Max_NS=ncdf_vardef(cdfid,'grid_GR_Kdp_Max_NS',[xgridid,ygridid,zgridid])
       ncdf_attput, cdfid, GR_Kdp_Max_NS, 'long_name', $
       'Sample maximum of DP Specific Differential Phase that occurred at the same location as the Median reflectivity (grid_GR_Z_NS)'
       ncdf_attput, cdfid, GR_Kdp_Max_NS, 'units', 'deg/km'

     GR_RHOhv_NS=ncdf_vardef(cdfid,'grid_GR_RHOhv_NS',[xgridid,ygridid,zgridid])
       ncdf_attput, cdfid, GR_RHOhv_NS, 'long_name', $
       'DP Co-Polar Correlation Coefficient that occurred at the same location as the Median reflectivity (grid_GR_Z_NS)'
       ncdf_attput, cdfid, GR_RHOhv_NS, 'units', 'unitless'

     GR_RHOhv_StdDev_NS=ncdf_vardef(cdfid,'grid_GR_RHOhv_StdDev_NS',[xgridid,ygridid,zgridid])
       ncdf_attput, cdfid, GR_RHOhv_StdDev_NS, 'long_name', $
       'Standard deviation of DP Co-Polar Correlation Coefficient that occurred at the same location as the Median reflectivity (grid_GR_Z_NS)'
       ncdf_attput, cdfid, GR_RHOhv_StdDev_NS, 'units', 'unitless'

     GR_RHOhv_Max_NS=ncdf_vardef(cdfid,'grid_GR_RHOhv_Max_NS',[xgridid,ygridid,zgridid])
       ncdf_attput, cdfid, GR_RHOhv_Max_NS, 'long_name', $
       'Sample maximum of DP Co-Polar Correlation Coefficient that occurred at the same location as the Median reflectivity (grid_GR_Z_NS)'
       ncdf_attput, cdfid, GR_RHOhv_Max_NS, 'units', 'unitless'

     GR_RC_rainrate_NS=ncdf_vardef(cdfid,'grid_GR_RC_rainrate_NS',[xgridid,ygridid,zgridid])
       ncdf_attput, cdfid, GR_RC_rainrate_NS, 'long_name', $
       'GV radar Cifelli Rainrate that occurred at the same location as the Median reflectivity (grid_GR_Z_NS)'
       ncdf_attput, cdfid, GR_RC_rainrate_NS, 'units', 'mm/hr'

     GR_RC_rainrate_StdDev_NS=ncdf_vardef(cdfid,'grid_GR_RC_rainrate_StdDev_NS',[xgridid,ygridid,zgridid])
       ncdf_attput, cdfid, GR_RC_rainrate_StdDev_NS, 'long_name', $
       'Standard deviation of GV radar Cifelli Rainrate that occurred at the same location as the Median reflectivity (grid_GR_Z_NS)'
       ncdf_attput, cdfid, GR_RC_rainrate_StdDev_NS, 'units', 'mm/hr'

     GR_RC_rainrate_Max_NS=ncdf_vardef(cdfid,'grid_GR_RC_rainrate_Max_NS',[xgridid,ygridid,zgridid])
       ncdf_attput, cdfid, GR_RC_rainrate_Max_NS, 'long_name', $
       'Sample maximum of GV radar Cifelli Rainrate that occurred at the same location as the Median reflectivity (grid_GR_Z_NS)'
       ncdf_attput, cdfid, GR_RC_rainrate_Max_NS, 'units', 'mm/hr'

     GR_RP_rainrate_NS=ncdf_vardef(cdfid,'grid_GR_RP_rainrate_NS',[xgridid,ygridid,zgridid])
       ncdf_attput, cdfid, GR_RP_rainrate_NS, 'long_name', $
       'GV radar PolZR Rainrate that occurred at the same location as the Median reflectivity (grid_GR_Z_NS)'
       ncdf_attput, cdfid, GR_RP_rainrate_NS, 'units', 'mm/hr'

     GR_RP_rainrate_StdDev_NS=ncdf_vardef(cdfid,'grid_GR_RP_rainrate_StdDev_NS',[xgridid,ygridid,zgridid])
       ncdf_attput, cdfid, GR_RP_rainrate_StdDev_NS, 'long_name', $
       'Standard deviation of GV radar PolZR Rainrate that occurred at the same location as the Median reflectivity (grid_GR_Z_NS)'
       ncdf_attput, cdfid, GR_RP_rainrate_StdDev_NS, 'units', 'mm/hr'

     GR_RP_rainrate_Max_NS=ncdf_vardef(cdfid,'grid_GR_RP_rainrate_Max_NS',[xgridid,ygridid,zgridid])
       ncdf_attput, cdfid, GR_RP_rainrate_Max_NS, 'long_name', $
       'Sample maximum of GV radar PolZR Rainrate that occurred at the same location as the Median reflectivity (grid_GR_Z_NS)'
       ncdf_attput, cdfid, GR_RP_rainrate_Max_NS, 'units', 'mm/hr'

     GR_RR_rainrate_NS=ncdf_vardef(cdfid,'grid_GR_RR_rainrate_NS',[xgridid,ygridid,zgridid])
       ncdf_attput, cdfid, GR_RR_rainrate_NS, 'long_name', $
       'GV radar DROPS Rainrate that occurred at the same location as the Median reflectivity (grid_GR_Z_NS)'
       ncdf_attput, cdfid, GR_RR_rainrate_NS, 'units', 'mm/hr'

     GR_RR_rainrate_StdDev_NS=ncdf_vardef(cdfid,'grid_GR_RR_rainrate_StdDev_NS',[xgridid,ygridid,zgridid])
       ncdf_attput, cdfid, GR_RR_rainrate_StdDev_NS, 'long_name', $
       'Standard deviation of GV radar DROPS Rainrate that occurred at the same location as the Median reflectivity (grid_GR_Z_NS)'
       ncdf_attput, cdfid, GR_RR_rainrate_StdDev_NS, 'units', 'mm/hr'

     GR_RR_rainrate_Max_NS=ncdf_vardef(cdfid,'grid_GR_RR_rainrate_Max_NS',[xgridid,ygridid,zgridid])
       ncdf_attput, cdfid, GR_RR_rainrate_Max_NS, 'long_name', $
       'Sample maximum of GV radar DROPS Rainrate that occurred at the same location as the Median reflectivity (grid_GR_Z_NS)'
       ncdf_attput, cdfid, GR_RR_rainrate_Max_NS, 'units', 'mm/hr'

     GR_HID_NS=ncdf_vardef(cdfid, 'grid_GR_HID_NS', [hidimid,xgridid,ygridid,zgridid], /short)
       ncdf_attput, cdfid, GR_HID_NS, 'long_name', $
       'DP Hydrometeor Identification concentration that occurred at the same location as the Median reflectivity (grid_GR_Z_MS)'
       ncdf_attput, cdfid, GR_HID_NS, 'units', 'categorical'

     GR_Dzero_NS=ncdf_vardef(cdfid,'grid_GR_Dzero_NS',[xgridid,ygridid,zgridid])
       ncdf_attput, cdfid, GR_Dzero_NS, 'long_name', $
       'DP Median Volume Diameter that occurred at the same location as the Median reflectivity (grid_GR_Z_NS)'
       ncdf_attput, cdfid, GR_Dzero_NS, 'units', 'mm'

     GR_Dzero_StdDev_NS=ncdf_vardef(cdfid,'grid_GR_Dzero_StdDev_NS',[xgridid,ygridid,zgridid])
       ncdf_attput, cdfid, GR_Dzero_StdDev_NS, 'long_name', $
       'Standard deviation of DP Median Volume Diameter that occurred at the same location as the Median reflectivity (grid_GR_Z_NS)'
       ncdf_attput, cdfid, GR_Dzero_StdDev_NS, 'units', 'mm'

     GR_Dzero_Max_NS=ncdf_vardef(cdfid,'grid_GR_Dzero_Max_NS',[xgridid,ygridid,zgridid])
       ncdf_attput, cdfid, GR_Dzero_Max_NS, 'long_name', $
       'Sample maximum of DP Median Volume Diameter that occurred at the same location as the Median reflectivity (grid_GR_Z_NS)'
       ncdf_attput, cdfid, GR_Dzero_Max_NS, 'units', 'mm'

     GR_Nw_NS=ncdf_vardef(cdfid,'grid_GR_Nw_NS',[xgridid,ygridid,zgridid])
       ncdf_attput, cdfid, GR_Nw_NS, 'long_name', $
       'DP Normalized Intercept Parameter that occurred at the same location as the Median reflectivity (grid_GR_Z_NS)'
       ncdf_attput, cdfid, GR_Nw_NS, 'units', '1/(mm*m^3)'

     GR_Nw_StdDev_NS=ncdf_vardef(cdfid,'grid_GR_Nw_StdDev_NS',[xgridid,ygridid,zgridid])
       ncdf_attput, cdfid, GR_Nw_StdDev_NS, 'long_name', $
       'Standard deviation of DP Normalized Intercept Parameter that occurred at the same location as the Median reflectivity (grid_GR_Z_NS)'
       ncdf_attput, cdfid, GR_Nw_StdDev_NS, 'units', '1/(mm*m^3)'

     GR_Nw_Max_NS=ncdf_vardef(cdfid,'grid_GR_Nw_Max_NS',[xgridid,ygridid,zgridid])
      ncdf_attput, cdfid, GR_Nw_Max_NS, 'long_name', $
      'Sample maximum of DP Normalized Intercept Parameter that occurred at the same location as the Median reflectivity (grid_GR_Z_NS)'
      ncdf_attput, cdfid, GR_Nw_Max_NS, 'units', '1/(mm*m^3)'

     GR_Dm_NS=ncdf_vardef(cdfid,'grid_GR_Dm_NS',[xgridid,ygridid,zgridid])
       ncdf_attput, cdfid, GR_Dm_NS, 'long_name', $
       'DP Retrieved Median Diameter that occurred at the same location as the Median reflectivity (grid_GR_Z_NS)'
       ncdf_attput, cdfid, GR_Dm_NS, 'units', 'mm'

     GR_Dm_StdDev_NS=ncdf_vardef(cdfid,'grid_GR_Dm_StdDev_NS',[xgridid,ygridid,zgridid])
       ncdf_attput, cdfid, GR_Dm_StdDev_NS, 'long_name', $
       'Standard deviation of DP Retrieved Median Diameter that occurred at the same location as the Median reflectivity (grid_GR_Z_NS)'
       ncdf_attput, cdfid, GR_Dm_StdDev_NS, 'units', 'mm'

     GR_Dm_Max_NS=ncdf_vardef(cdfid,'grid_GR_Dm_Max_NS',[xgridid,ygridid,zgridid])
       ncdf_attput, cdfid, GR_Dm_Max_NS, 'long_name', $
       'Sample maximum of DP Retrieved Median Diameter that occurred at the same location as the Median reflectivity (grid_GR_Z_NS)'
       ncdf_attput, cdfid, GR_Dm_Max_NS, 'units', 'mm'

     GR_N2_NS=ncdf_vardef(cdfid,'grid_GR_N2_NS',[xgridid,ygridid,zgridid])
       ncdf_attput, cdfid, GR_N2_NS, 'long_name', $
       'Tokay Normalized Intercept Parameter that occurred at the same location as the Median reflectivity (grid_GR_Z_NS)'
       ncdf_attput, cdfid, GR_N2_NS, 'units', '1/(mm*m^3)'

     GR_N2_StdDev_NS=ncdf_vardef(cdfid,'grid_GR_N2_StdDev_NS',[xgridid,ygridid,zgridid])
       ncdf_attput, cdfid, GR_N2_StdDev_NS, 'long_name', $
       'Standard deviation of Tokay Normalized Intercept Parameter that occurred at the same location as the Median reflectivity (grid_GR_Z_NS)'
       ncdf_attput, cdfid, GR_N2_StdDev_NS, 'units', '1/(mm*m^3)'

     GR_N2_Max_NS=ncdf_vardef(cdfid,'grid_GR_N2_Max_NS',[xgridid,ygridid,zgridid])
       ncdf_attput, cdfid, GR_N2_Max_NS, 'long_name', $
       'Sample maximum of Tokay Normalized Intercept Parameter that occurred at the same location as the Median reflectivity (grid_GR_Z_NS)'
       ncdf_attput, cdfid, GR_N2_Max_NS, 'units', '1/(mm*m^3)'

     GR_blockage_NS=ncdf_vardef(cdfid,'grid_GR_blockage_NS', [xgridid,ygridid,zgridid])
       ncdf_attput, cdfid, GR_blockage_NS, 'long_name', $
       'Ground Radar Blockage Fraction that occurred at the same location as the Median reflectivity (grid_GR_Z_NS)'

     n_gr_z_rejected_NS=ncdf_vardef(cdfid,'grid_n_gr_z_rejected_NS', [xgridid,ygridid,zgridid], /short)
       ncdf_attput, cdfid, n_gr_z_rejected_NS, 'long_name', $
       'Number of bins below GR_dBZ_min in GR_Z average at the same location as the Median reflectivity (grid_GR_Z_NS)'

     n_gr_zdr_rejected_NS=ncdf_vardef(cdfid,'grid_n_gr_zdr_rejected_NS', [xgridid,ygridid,zgridid], /short)
       ncdf_attput, cdfid, n_gr_zdr_rejected_NS, 'long_name', $
       'Number of bins with missing Zdr in GR_Zdr average at the same location as the Median reflectivity (grid_GR_Z_NS)'

     n_gr_kdp_rejected_NS=ncdf_vardef(cdfid,'grid_n_gr_kdp_rejected_NS', [xgridid,ygridid,zgridid], /short)
       ncdf_attput, cdfid, n_gr_kdp_rejected_NS, 'long_name', $
       'Number of bins with missing Kdp in GR_Kdp average at the same location as the Median reflectivity (grid_GR_Z_NS)'

     n_gr_rhohv_rejected_NS=ncdf_vardef(cdfid,'grid_n_gr_rhohv_rejected_NS', [xgridid,ygridid,zgridid], /short)
       ncdf_attput, cdfid, n_gr_rhohv_rejected_NS, 'long_name', $
       'Number of bins with missing RHOhv in GR_RHOhv average at the same location as the Median reflectivity (grid_GR_Z_NS)'

     n_gr_rc_rejected_NS=ncdf_vardef(cdfid,'grid_n_gr_rc_rejected_NS', [xgridid,ygridid,zgridid], /short)
       ncdf_attput, cdfid, n_gr_rc_rejected_NS, 'long_name', $
       'Number of bins below rain_min in GR_RC_rainrate average at the same location as the Median reflectivity (grid_GR_Z_NS)'

     n_gr_rp_rejected_NS=ncdf_vardef(cdfid,'grid_n_gr_rp_rejected_NS', [xgridid,ygridid,zgridid], /short)
       ncdf_attput, cdfid, n_gr_rp_rejected_NS, 'long_name', $
       'Number of bins below rain_min in GR_RP_rainrate average at the same location as the Median reflectivity (grid_GR_Z_NS)'

     n_gr_rr_rejected_NS=ncdf_vardef(cdfid,'grid_n_gr_rr_rejected_NS', [xgridid,ygridid,zgridid], /short)
       ncdf_attput, cdfid, n_gr_rr_rejected_NS, 'long_name', $
       'Number of bins below rain_min in GR_RR_rainrate average at the same location as the Median reflectivity (grid_GR_Z_NS)'

     n_gr_hid_rejected_NS=ncdf_vardef(cdfid,'grid_n_gr_hid_rejected_NS', [xgridid,ygridid,zgridid], /short)
       ncdf_attput, cdfid, n_gr_hid_rejected_NS, 'long_name', $
       'Number of bins with undefined HID in GR_HID histogram for the 5x5x1 grid'

     n_gr_dzero_rejected_NS=ncdf_vardef(cdfid,'grid_n_gr_dzero_rejected_NS', [xgridid,ygridid,zgridid], /short)
       ncdf_attput, cdfid, n_gr_dzero_rejected_NS, 'long_name', $
       'Number of bins with missing D0 in GR_Dzero average at the same location as the Median reflectivity (grid_GR_Z_NS)'

     n_gr_nw_rejected_NS=ncdf_vardef(cdfid,'grid_n_gr_nw_rejected_NS', [xgridid,ygridid,zgridid], /short)
       ncdf_attput, cdfid, n_gr_nw_rejected_NS, 'long_name', $
       'Number of bins with missing Nw in GR_Nw average at the same location as the Median reflectivity (grid_GR_Z_NS)'

     n_gr_dm_rejected_NS=ncdf_vardef(cdfid,'grid_n_gr_dm_rejected_NS', [xgridid,ygridid,zgridid], /short)
       ncdf_attput, cdfid, n_gr_dm_rejected_NS, 'long_name', $
       'Number of bins with missing Dm in GR_Dm average at the same location as the Median reflectivity (grid_GR_Z_NS)'

     n_gr_n2_rejected_NS=ncdf_vardef(cdfid,'grid_n_gr_n2_rejected_NS', [xgridid,ygridid,zgridid], /short)
       ncdf_attput, cdfid, n_gr_n2_rejected_NS, 'long_name', $
       'Number of bins with missing N2 in GR_N2 average at the same location as the Median reflectivity (grid_GR_Z_NS)'

     n_gr_expected_NS=ncdf_vardef(cdfid,'grid_n_gr_expected_NS', [xgridid,ygridid,zgridid], /short)
       ncdf_attput, cdfid, n_gr_expected_NS, 'long_name', $
       'Number of bins in GR_Z average at the same location as the Median reflectivity (grid_GR_Z_NS)'

     precipTotPSDparamHigh_NS=ncdf_vardef(cdfid,'grid_precipTotPSDparamHigh_NS', [xgridid,ygridid,zgridid])
       ncdf_attput, cdfid, precipTotPSDparamHigh_NS, 'long_name', $
       '2B-DPRGMI precipTotPSDparamHigh for NS swath at the same location as the Median reflectivity (grid_GR_Z_NS)'
       ncdf_attput, cdfid, precipTotPSDparamHigh_NS, 'units', 'mm_Dm'

     precipTotPSDparamLow_NS=ncdf_vardef(cdfid,'grid_precipTotPSDparamLow_NS', [nKuKa,xgridid,ygridid,zgridid])
       ncdf_attput, cdfid, precipTotPSDparamLow_NS, 'long_name', $
       '2B-DPRGMI precipTotPSDparamLow for NS swath at the same location as the Median reflectivity (grid_GR_Z_NS)'
       ncdf_attput, cdfid, precipTotPSDparamLow_NS, 'units', 'Nw_mu'

     precipTotRate_NS=ncdf_vardef(cdfid,'grid_precipTotRate_NS', [xgridid,ygridid,zgridid])
       ncdf_attput, cdfid, precipTotRate_NS, 'long_name', $
       '2B-DPRGMI precipTotRate for NS swath at the same location as the Median reflectivity (grid_GR_Z_NS)'
       ncdf_attput, cdfid, precipTotRate_NS, 'units', 'mm/hr'

     precipTotWaterCont_NS=ncdf_vardef(cdfid,'grid_precipTotWaterCont_NS', [xgridid,ygridid,zgridid])
       ncdf_attput, cdfid, precipTotWaterCont_NS, 'long_name', $
       '2B-DPRGMI precipTotWaterCont for NS swath  at the same location as the Median reflectivity (grid_GR_Z_NS)'
       ncdf_attput, cdfid, precipTotWaterCont_NS, 'units', 'g/m^3'

     n_precipTotPSDparamHigh_rejected_NS=ncdf_vardef(cdfid,'grid_n_precipTotPSDparamHigh_rejected_NS', [xgridid,ygridid,zgridid], /short)
       ncdf_attput, cdfid, n_precipTotPSDparamHigh_rejected_NS, 'long_name', $
       'Number of bins below rain_min in precipTotPSDparamHigh average for NS swath at the same location as the Median reflectivity (grid_GR_Z_NS)'

     n_precipTotPSDparamLow_rejected_NS=ncdf_vardef(cdfid,'grid_n_precipTotPSDparamLow_rejected_NS', [nKuKa,xgridid,ygridid,zgridid], /short)
       ncdf_attput, cdfid, n_precipTotPSDparamLow_rejected_NS, 'long_name', $
       'Number of bins below rain_min in precipTotPSDparamLow average for NS swath at the same location as the Median reflectivity (grid_GR_Z_NS)'

     n_precipTotRate_rejected_NS=ncdf_vardef(cdfid,'grid_n_precipTotRate_rejected_NS', [xgridid,ygridid,zgridid], /short)
       ncdf_attput, cdfid, n_precipTotRate_rejected_NS, 'long_name', $
       'Number of bins below rain_min in precipTotRate average for NS swath at the same location as the Median reflectivity (grid_GR_Z_NS)'

     n_precipTotWaterCont_rejected_NS=ncdf_vardef(cdfid,'grid_n_precipTotWaterCont_rejected_NS', [xgridid,ygridid,zgridid], /short)
       ncdf_attput, cdfid, n_precipTotWaterCont_rejected_NS, 'long_name', $
       'Number of bins below rain_min in precipTotWaterCont average for NS swath at the same location as the Median reflectivity (grid_GR_Z_NS)'

     precipitationType_NS=ncdf_vardef(cdfid,'grid_precipitationType_NS', [xgridid,ygridid], /short)
       ncdf_attput, cdfid, precipitationType_NS, 'long_name', $
       '2B-DPRGMI precipitationType for NS swath at the same location as the ground location of the Median reflectivity (grid_GR_Z_NS)'
       ncdf_attput, cdfid, precipitationType_NS, 'units', 'categorical'

     surfPrecipTotRate_NS=ncdf_vardef(cdfid,'grid_surfPrecipTotRate_NS', [xgridid,ygridid])
       ncdf_attput, cdfid, surfPrecipTotRate_NS, 'long_name', $
       '2B-DPRGMI surfPrecipTotRate for NS swath at the same location as the ground location of the Median reflectivity (grid_GR_Z_NS)'
       ncdf_attput, cdfid, surfPrecipTotRate_NS, 'units', 'mm/hr'

     surfaceElevation_NS=ncdf_vardef(cdfid,'grid_surfaceElevation_NS', [xgridid,ygridid])
       ncdf_attput, cdfid, surfaceElevation_NS, 'long_name', $
       '2B-DPRGMI surfaceElevation for NS swath at the same location as the ground location of the Median reflectivity (grid_GR_Z_NS)'
       ncdf_attput, cdfid, surfaceElevation_NS, 'units', 'm'

     zeroDegAltitude_NS=ncdf_vardef(cdfid,'grid_zeroDegAltitude_NS', [xgridid,ygridid])
       ncdf_attput, cdfid, zeroDegAltitude_NS, 'long_name', $
       '2B-DPRGMI zeroDegAltitude for NS swath at the same location as the ground location of the Median reflectivity (grid_GR_Z_NS)'
       ncdf_attput, cdfid, zeroDegAltitude_NS, 'units', 'm'

     zeroDegBin_NS=ncdf_vardef(cdfid,'grid_zeroDegBin_NS', [xgridid,ygridid], /short)
       ncdf_attput, cdfid, zeroDegBin_NS, 'long_name', $
       '2B-DPRGMI zeroDegBin for NS swath at the same location as the ground location of the Median reflectivity (grid_GR_Z_NS)'
       ncdf_attput, cdfid, zeroDegBin_NS, 'units', 'N/A'

     surfaceType_NS=ncdf_vardef(cdfid,'grid_surfaceType_NS', [xgridid,ygridid], /short)
       ncdf_attput, cdfid, surfaceType_NS, 'long_name', $
       '2B-DPRGMI surfaceType for NS swath at the same location as the ground location of the Median reflectivity (grid_GR_Z_NS)'
       ncdf_attput, cdfid, surfaceType_NS, 'units', 'categorical'

     phaseBinNodes_NS=ncdf_vardef(cdfid,'grid_phaseBinNodes_NS', [nPhsBnN,xgridid,ygridid], /short)
       ncdf_attput, cdfid, phaseBinNodes_NS, 'long_name', $
       '2B-DPRGMI phaseBinNodes for NS swath at the same location as the ground location of the Median reflectivity (grid_GR_Z_NS)'
       ncdf_attput, cdfid, phaseBinNodes_NS, 'units', 'N/A'

     DPRlatitude_NS=ncdf_vardef(cdfid,'grid_DPRlatitude_NS', [xgridid,ygridid])
       ncdf_attput, cdfid, DPRlatitude_NS, 'long_name', $
       'Latitude of DPR surface bin for NS swath at the same location as the ground location of the Median reflectivity (grid_GR_Z_NS)'
       ncdf_attput, cdfid, DPRlatitude_NS, 'units', 'degrees North'

     DPRlongitude_NS=ncdf_vardef(cdfid,'grid_DPRlongitude_NS', [xgridid,ygridid])
       ncdf_attput, cdfid, DPRlongitude_NS, 'long_name', $
       'Longitude of DPR surface bin for NS swath at the same location as the ground location of the Median reflectivity (grid_GR_Z_NS)'
       ncdf_attput, cdfid, DPRlongitude_NS, 'units', 'degrees East'

     scanNum_NS=ncdf_vardef(cdfid,'grid_scanNum_NS', [xgridid,ygridid], /short)
       ncdf_attput, cdfid, scanNum_NS, 'long_name', $
       'Product-relative zero-based DPR scan number for NS swath at the same location as the ground location of the Median reflectivity (grid_GR_Z_NS)'

     rayNum_NS=ncdf_vardef(cdfid,'grid_rayNum_NS', [xgridid,ygridid], /short)
       ncdf_attput, cdfid, rayNum_NS, 'long_name', $
       'Product-relative zero-based DPR ray number for NS swath at the same location as the ground location of the Median reflectivity (grid_GR_Z_NS)'

     ellipsoidBinOffset_NS=ncdf_vardef(cdfid,'grid_ellipsoidBinOffset_NS', [xgridid,ygridid])
       ncdf_attput, cdfid, ellipsoidBinOffset_NS, 'long_name', $
       '2B-DPRGMI ellipsoidBinOffset for NS swath at the same location as the ground location of the Median reflectivity (grid_GR_Z_NS)'
       ncdf_attput, cdfid, ellipsoidBinOffset_NS, 'units', 'm'

     lowestClutterFreeBin_NS=ncdf_vardef(cdfid,'grid_lowestClutterFreeBin_NS', [xgridid,ygridid], /short)
       ncdf_attput, cdfid, lowestClutterFreeBin_NS, 'long_name', $
       '2B-DPRGMI lowestClutterFreeBin for NS swath at the same location as the ground location of the Median reflectivity (grid_GR_Z_NS)'

     clutterStatus_NS=ncdf_vardef(cdfid,'grid_clutterStatus_NS', [xgridid,ygridid,zgridid], /short)
       ncdf_attput, cdfid, clutterStatus_NS, 'long_name', $
       'Matchup clutterStatus for NS swath at the same location as the ground location of the Median reflectivity (grid_GR_Z_NS)'

     precipitationFlag_NS=ncdf_vardef(cdfid,'grid_precipitationFlag_NS', [xgridid,ygridid], /short)
       ncdf_attput, cdfid, precipitationFlag_NS, 'long_name', $
       '2B-DPRGMI precipitationFlag for NS swath at the same location as the ground location of the Median reflectivity (grid_GR_Z_NS)'
       ncdf_attput, cdfid, precipitationFlag_NS, 'units', 'categorical'

     surfaceRangeBin_NS=ncdf_vardef(cdfid,'grid_surfaceRangeBin_NS', [xgridid,ygridid], /short)
       ncdf_attput, cdfid, surfaceRangeBin_NS, 'long_name', $
       '2B-DPRGMI surfaceRangeBin for NS swath at the same location as the ground location of the Median reflectivity (grid_GR_Z_NS)'

     correctedReflectFactor_NS=ncdf_vardef(cdfid,'grid_correctedReflectFactor_NS', [xgridid,ygridid,zgridid])
       ncdf_attput, cdfid, correctedReflectFactor_NS, 'long_name', $
       '2B-DPRGMI Corrected Reflectivity Factor for NS swath at the same location as the ground location of the Median reflectivity (grid_GR_Z_NS)'
       ncdf_attput, cdfid, correctedReflectFactor_NS, 'units', 'dBZ'

     pia_NS=ncdf_vardef(cdfid,'grid_pia_NS', [xgridid,ygridid])
       ncdf_attput, cdfid, pia_NS, 'long_name', $
       '2B-DPRGMI Path Integrated Attenuation for NS swath at the same location as the ground location of the Median reflectivity (grid_GR_Z_NS)'
       ncdf_attput, cdfid, pia_NS, 'units', 'dB'

     stormTopAltitude_NS=ncdf_vardef(cdfid,'grid_stormTopAltitude_NS', [xgridid,ygridid])
       ncdf_attput, cdfid, stormTopAltitude_NS, 'long_name', $
       '2B-DPRGMI stormTopAltitude for NS swath for NS swath at the same location as the ground location of the Median reflectivity (grid_GR_Z_NS)'
       ncdf_attput, cdfid, stormTopAltitude_NS, 'units', 'm'

     n_correctedReflectFactor_rejected_NS=ncdf_vardef(cdfid,'grid_n_correctedReflectFactor_rejected_NS', [xgridid,ygridid,zgridid], /short)
       ncdf_attput, cdfid, n_correctedReflectFactor_rejected_NS, 'long_name', $
       'Numbers of bins below DPR_dBZ_min in correctedReflectFactor average for NS swath at the same location as the ground location of the Median reflectivity (grid_GR_Z_NS)'

     n_dpr_expected_NS=ncdf_vardef(cdfid,'grid_n_dpr_expected_NS', [xgridid,ygridid,zgridid], /short)
       ncdf_attput, cdfid, n_dpr_expected_NS, 'long_name', $
       'Numbers of expected bins in DPR averages for NS swath at the same location as the ground location of the Median reflectivity (grid_GR_Z_NS)'

     ;Change the modes (you need to have this AFTER you define your variables, but BEFORE you actually write the data out!
     NCDF_CONTROL, cdfid, /ENDEF

     ;Write the data for every variable:
     ncdf_varput, cdfid, missing_int, grid_missing_int
     ncdf_varput, cdfid, missing_flt, grid_missing_flt
     ncdf_varput, cdfid, orig_filename, grid_orig_filename
     ncdf_varput, cdfid, orig_gridversion, grid_version
     ncdf_varput, cdfid, orig_count_fpdim_MS, grid_orig_count_fpdim_MS
     ncdf_varput, cdfid, orig_count_fpdim_NS, grid_orig_count_fpdim_NS
     ncdf_varput, cdfid, orig_radarname, grid_orig_radarname
     ncdf_varput, cdfid, orig_timedimids_MS, grid_timedimids_MS
     ncdf_varput, cdfid, orig_timedimids_NS, grid_timedimids_NS
     ncdf_varput, cdfid, xgrid_arr, grid_xgrid
     ncdf_varput, cdfid, ygrid_arr, grid_ygrid
     ncdf_varput, cdfid, zgrid_arr, grid_zgrid
     ncdf_varput, cdfid, latgrid_arr, grid_latitude_main
     ncdf_varput, cdfid, longrid_arr, grid_longitude_main
     ncdf_varput, cdfid, timeNearestApproach, grid_timeNearestApproach
     ncdf_varput, cdfid, atimeNearestApproach, grid_atimeNearestApproach
     ncdf_varput, cdfid, timeSweepStart, grid_timeSweepStart
     ncdf_varput, cdfid, atimeSweepStart, grid_atimeSweepStart
     ncdf_varput, cdfid, site_ID, grid_site_ID
     ncdf_varput, cdfid, site_lat, grid_site_lat
     ncdf_varput, cdfid, site_lon, grid_site_lon
     ncdf_varput, cdfid, site_elev, grid_site_elev
     ncdf_varput, cdfid, elevationAngle, grid_elevationAngle
     ncdf_varput, cdfid, rangeThreshold, grid_rangeThreshold
     ncdf_varput, cdfid, DPR_dBZ_min, grid_DPR_dBZ_min
     ncdf_varput, cdfid, GR_dBZ_min, grid_GR_dBZ_min
     ncdf_varput, cdfid, rain_min, grid_rain_min

     ;For the MS variables and NS variables that are only a function of the number of files used to create .nc file:
     ncdf_varput, cdfid, Year_MS, grid_Year_MS
     ncdf_varput, cdfid, Month_MS, grid_Month_MS
     ncdf_varput, cdfid, DayOfMonth_MS, grid_DayOfMonth_MS
     ncdf_varput, cdfid, Hour_MS, grid_Hour_MS
     ncdf_varput, cdfid, Minute_MS, grid_Minute_MS
     ncdf_varput, cdfid, Second_MS, grid_Second_MS
     ncdf_varput, cdfid, Millisecond_MS, grid_Millisecond_MS
     ncdf_varput, cdfid, startScan_MS, grid_startScan_MS
     ncdf_varput, cdfid, endScan_MS, grid_endScan_MS
     ncdf_varput, cdfid, numRays_MS, grid_numRays_MS
     ncdf_varput, cdfid, Year_NS, grid_Year_NS
     ncdf_varput, cdfid, Month_NS, grid_Month_NS
     ncdf_varput, cdfid, DayOfMonth_NS, grid_DayOfMonth_NS
     ncdf_varput, cdfid, Hour_NS, grid_Hour_NS
     ncdf_varput, cdfid, Minute_NS, grid_Minute_NS
     ncdf_varput, cdfid, Second_NS, grid_Second_NS
     ncdf_varput, cdfid, Millisecond_NS, grid_Millisecond_NS
     ncdf_varput, cdfid, startScan_NS, grid_startScan_NS
     ncdf_varput, cdfid, endScan_NS, grid_endScan_NS
     ncdf_varput, cdfid, numRays_NS, grid_numRays_NS

     ;For the MS variables that are a function of the actual grid:
     ncdf_varput, cdfid, latitude_MS, grid_latitude_MS
     ncdf_varput, cdfid, longitude_MS, grid_longitude_MS
     ncdf_varput, cdfid, topHeight_MS_MSL, grid_topHeight_MS_MSL
     ncdf_varput, cdfid, topHeight_MS, grid_topHeight_MS
     ncdf_varput, cdfid, bottomHeight_MS_MSL, grid_bottomHeight_MS_MSL
     ncdf_varput, cdfid, bottomHeight_MS, grid_bottomHeight_MS
     ncdf_varput, cdfid, GR_Z_MS, grid_GR_Z_MS
     ncdf_varput, cdfid, GR_Z_StdDev_MS, grid_GR_Z_StdDev_MS
     ncdf_varput, cdfid, GR_Z_Max_MS, grid_GR_Z_Max_MS
     ncdf_varput, cdfid, GR_Zdr_MS, grid_GR_Zdr_MS
     ncdf_varput, cdfid, GR_Zdr_StdDev_MS, grid_GR_Zdr_StdDev_MS
     ncdf_varput, cdfid, GR_Zdr_Max_MS, grid_GR_Zdr_Max_MS
     ncdf_varput, cdfid, GR_Kdp_MS, grid_GR_Kdp_MS
     ncdf_varput, cdfid, GR_Kdp_StdDev_MS, grid_GR_Kdp_StdDev_MS
     ncdf_varput, cdfid, GR_Kdp_Max_MS, grid_GR_Kdp_Max_MS
     ncdf_varput, cdfid, GR_RHOhv_MS, grid_GR_RHOhv_MS
     ncdf_varput, cdfid, GR_RHOhv_StdDev_MS, grid_GR_RHOhv_StdDev_MS
     ncdf_varput, cdfid, GR_RHOhv_Max_MS, grid_GR_RHOhv_Max_MS
     ncdf_varput, cdfid, GR_RC_rainrate_MS, grid_GR_RC_rainrate_MS
     ncdf_varput, cdfid, GR_RC_rainrate_StdDev_MS, grid_GR_RC_rainrate_StdDev_MS
     ncdf_varput, cdfid, GR_RC_rainrate_Max_MS, grid_GR_RC_rainrate_Max_MS
     ncdf_varput, cdfid, GR_RP_rainrate_MS, grid_GR_RP_rainrate_MS
     ncdf_varput, cdfid, GR_RP_rainrate_StdDev_MS, grid_GR_RP_rainrate_StdDev_MS
     ncdf_varput, cdfid, GR_RP_rainrate_Max_MS, grid_GR_RP_rainrate_Max_MS
     ncdf_varput, cdfid, GR_RR_rainrate_MS, grid_GR_RR_rainrate_MS
     ncdf_varput, cdfid, GR_RR_rainrate_StdDev_MS, grid_GR_RR_rainrate_StdDev_MS
     ncdf_varput, cdfid, GR_RR_rainrate_Max_MS, grid_GR_RR_rainrate_Max_MS
     ncdf_varput, cdfid, GR_HID_MS, grid_GR_HID_MS
     ncdf_varput, cdfid, GR_Dzero_MS, grid_GR_Dzero_MS
     ncdf_varput, cdfid, GR_Dzero_StdDev_MS, grid_GR_Dzero_StdDev_MS
     ncdf_varput, cdfid, GR_Dzero_Max_MS, grid_GR_Dzero_Max_MS
     ncdf_varput, cdfid, GR_Nw_MS, grid_GR_Nw_MS
     ncdf_varput, cdfid, GR_Nw_StdDev_MS, grid_GR_Nw_StdDev_MS
     ncdf_varput, cdfid, GR_Nw_Max_MS, grid_GR_Nw_Max_MS
     ncdf_varput, cdfid, GR_Dm_MS, grid_GR_Dm_MS
     ncdf_varput, cdfid, GR_Dm_StdDev_MS, grid_GR_Dm_StdDev_MS
     ncdf_varput, cdfid, GR_Dm_Max_MS, grid_GR_Dm_Max_MS
     ncdf_varput, cdfid, GR_N2_MS, grid_GR_N2_MS
     ncdf_varput, cdfid, GR_N2_StdDev_MS, grid_GR_N2_StdDev_MS
     ncdf_varput, cdfid, GR_N2_Max_MS, grid_GR_N2_Max_MS
     ncdf_varput, cdfid, GR_blockage_MS, grid_GR_blockage_MS
     ncdf_varput, cdfid, n_gr_z_rejected_MS, grid_n_gr_z_rejected_MS
     ncdf_varput, cdfid, n_gr_zdr_rejected_MS, grid_n_gr_zdr_rejected_MS
     ncdf_varput, cdfid, n_gr_kdp_rejected_MS, grid_n_gr_kdp_rejected_MS
     ncdf_varput, cdfid, n_gr_rhohv_rejected_MS, grid_n_gr_rhohv_rejected_MS
     ncdf_varput, cdfid, n_gr_rc_rejected_MS, grid_n_gr_rc_rejected_MS
     ncdf_varput, cdfid, n_gr_rp_rejected_MS, grid_n_gr_rp_rejected_MS
     ncdf_varput, cdfid, n_gr_rr_rejected_MS, grid_n_gr_rr_rejected_MS
     ncdf_varput, cdfid, n_gr_hid_rejected_MS, grid_n_gr_hid_rejected_MS
     ncdf_varput, cdfid, n_gr_dzero_rejected_MS, grid_n_gr_dzero_rejected_MS
     ncdf_varput, cdfid, n_gr_nw_rejected_MS, grid_n_gr_nw_rejected_MS
     ncdf_varput, cdfid, n_gr_dm_rejected_MS, grid_n_gr_dm_rejected_MS
     ncdf_varput, cdfid, n_gr_n2_rejected_MS, grid_n_gr_n2_rejected_MS
     ncdf_varput, cdfid, n_gr_expected_MS, grid_n_gr_expected_MS
     ncdf_varput, cdfid, precipTotPSDparamHigh_MS, grid_precipTotPSDparamHigh_MS
     ncdf_varput, cdfid, precipTotPSDparamLow_MS, grid_precipTotPSDparamLow_MS
     ncdf_varput, cdfid, precipTotRate_MS, grid_precipTotRate_MS
     ncdf_varput, cdfid, precipTotWaterCont_MS, grid_precipTotWaterCont_MS
     ncdf_varput, cdfid, n_precipTotPSDparamHigh_rejected_MS, grid_n_precipTotPSDparamHigh_rejected_MS
     ncdf_varput, cdfid, n_precipTotPSDparamLow_rejected_MS, grid_n_precipTotPSDparamLow_rejected_MS
     ncdf_varput, cdfid, n_precipTotRate_rejected_MS, grid_n_precipTotRate_rejected_MS
     ncdf_varput, cdfid, n_precipTotWaterCont_rejected_MS, grid_n_precipTotWaterCont_rejected_MS
     ncdf_varput, cdfid, precipitationType_MS, grid_precipitationType_MS
     ncdf_varput, cdfid, surfPrecipTotRate_MS, grid_surfPrecipTotRate_MS
     ncdf_varput, cdfid, surfaceElevation_MS, grid_surfaceElevation_MS
     ncdf_varput, cdfid, zeroDegAltitude_MS, grid_zeroDegAltitude_MS
     ncdf_varput, cdfid, zeroDegBin_MS, grid_zeroDegBin_MS
     ncdf_varput, cdfid, surfaceType_MS, grid_surfaceType_MS
     ncdf_varput, cdfid, phaseBinNodes_MS, grid_phaseBinNodes_MS
     ncdf_varput, cdfid, DPRlatitude_MS, grid_DPRlatitude_MS
     ncdf_varput, cdfid, DPRlongitude_MS, grid_DPRlongitude_MS
     ncdf_varput, cdfid, scanNum_MS, grid_scanNum_MS
     ncdf_varput, cdfid, rayNum_MS, grid_rayNum_MS
     ncdf_varput, cdfid, ellipsoidBinOffset_MS, grid_ellipsoidBinOffset_MS
     ncdf_varput, cdfid, lowestClutterFreeBin_MS, grid_lowestClutterFreeBin_MS
     ncdf_varput, cdfid, clutterStatus_MS, grid_clutterStatus_MS
     ncdf_varput, cdfid, precipitationFlag_MS, grid_precipitationFlag_MS
     ncdf_varput, cdfid, surfaceRangeBin_MS, grid_surfaceRangeBin_MS
     ncdf_varput, cdfid, correctedReflectFactor_MS, grid_correctedReflectFactor_MS
     ncdf_varput, cdfid, pia_MS, grid_pia_MS
     ncdf_varput, cdfid, stormTopAltitude_MS, grid_stormTopAltitude_MS
     ncdf_varput, cdfid, n_correctedReflectFactor_rejected_MS, grid_n_correctedReflectFactor_rejected_MS
     ncdf_varput, cdfid, n_dpr_expected_MS, grid_n_dpr_expected_MS

     ;For the NS variables that are a function of the actual grid:
     ncdf_varput, cdfid, latitude_NS, grid_latitude_NS
     ncdf_varput, cdfid, longitude_NS, grid_longitude_NS
     ncdf_varput, cdfid, topHeight_NS_MSL, grid_topHeight_NS_MSL
     ncdf_varput, cdfid, topHeight_NS, grid_topHeight_NS
     ncdf_varput, cdfid, bottomHeight_NS_MSL, grid_bottomHeight_NS_MSL
     ncdf_varput, cdfid, bottomHeight_NS, grid_bottomHeight_NS
     ncdf_varput, cdfid, GR_Z_NS, grid_GR_Z_NS
     ncdf_varput, cdfid, GR_Z_StdDev_NS, grid_GR_Z_StdDev_NS
     ncdf_varput, cdfid, GR_Z_Max_NS, grid_GR_Z_Max_NS
     ncdf_varput, cdfid, GR_Zdr_NS, grid_GR_Zdr_NS
     ncdf_varput, cdfid, GR_Zdr_StdDev_NS, grid_GR_Zdr_StdDev_NS
     ncdf_varput, cdfid, GR_Zdr_Max_NS, grid_GR_Zdr_Max_NS
     ncdf_varput, cdfid, GR_Kdp_NS, grid_GR_Kdp_NS
     ncdf_varput, cdfid, GR_Kdp_StdDev_NS, grid_GR_Kdp_StdDev_NS
     ncdf_varput, cdfid, GR_Kdp_Max_NS, grid_GR_Kdp_Max_NS
     ncdf_varput, cdfid, GR_RHOhv_NS, grid_GR_RHOhv_NS
     ncdf_varput, cdfid, GR_RHOhv_StdDev_NS, grid_GR_RHOhv_StdDev_NS
     ncdf_varput, cdfid, GR_RHOhv_Max_NS, grid_GR_RHOhv_Max_NS
     ncdf_varput, cdfid, GR_RC_rainrate_NS, grid_GR_RC_rainrate_NS
     ncdf_varput, cdfid, GR_RC_rainrate_StdDev_NS, grid_GR_RC_rainrate_StdDev_NS
     ncdf_varput, cdfid, GR_RC_rainrate_Max_NS, grid_GR_RC_rainrate_Max_NS
     ncdf_varput, cdfid, GR_RP_rainrate_NS, grid_GR_RP_rainrate_NS
     ncdf_varput, cdfid, GR_RP_rainrate_StdDev_NS, grid_GR_RP_rainrate_StdDev_NS
     ncdf_varput, cdfid, GR_RP_rainrate_Max_NS, grid_GR_RP_rainrate_Max_NS
     ncdf_varput, cdfid, GR_RR_rainrate_NS, grid_GR_RR_rainrate_NS
     ncdf_varput, cdfid, GR_RR_rainrate_StdDev_NS, grid_GR_RR_rainrate_StdDev_NS
     ncdf_varput, cdfid, GR_RR_rainrate_Max_NS, grid_GR_RR_rainrate_Max_NS
     ncdf_varput, cdfid, GR_HID_NS, grid_GR_HID_NS
     ncdf_varput, cdfid, GR_Dzero_NS, grid_GR_Dzero_NS
     ncdf_varput, cdfid, GR_Dzero_StdDev_NS, grid_GR_Dzero_StdDev_NS
     ncdf_varput, cdfid, GR_Dzero_Max_NS, grid_GR_Dzero_Max_NS
     ncdf_varput, cdfid, GR_Nw_NS, grid_GR_Nw_NS
     ncdf_varput, cdfid, GR_Nw_StdDev_NS, grid_GR_Nw_StdDev_NS
     ncdf_varput, cdfid, GR_Nw_Max_NS, grid_GR_Nw_Max_NS
     ncdf_varput, cdfid, GR_Dm_NS, grid_GR_Dm_NS
     ncdf_varput, cdfid, GR_Dm_StdDev_NS, grid_GR_Dm_StdDev_NS
     ncdf_varput, cdfid, GR_Dm_Max_NS, grid_GR_Dm_Max_NS
     ncdf_varput, cdfid, GR_N2_NS, grid_GR_N2_NS
     ncdf_varput, cdfid, GR_N2_StdDev_NS, grid_GR_N2_StdDev_NS
     ncdf_varput, cdfid, GR_N2_Max_NS, grid_GR_N2_Max_NS
     ncdf_varput, cdfid, GR_blockage_NS, grid_GR_blockage_NS
     ncdf_varput, cdfid, n_gr_z_rejected_NS, grid_n_gr_z_rejected_NS
     ncdf_varput, cdfid, n_gr_zdr_rejected_NS, grid_n_gr_zdr_rejected_NS
     ncdf_varput, cdfid, n_gr_kdp_rejected_NS, grid_n_gr_kdp_rejected_NS
     ncdf_varput, cdfid, n_gr_rhohv_rejected_NS, grid_n_gr_rhohv_rejected_NS
     ncdf_varput, cdfid, n_gr_rc_rejected_NS, grid_n_gr_rc_rejected_NS
     ncdf_varput, cdfid, n_gr_rp_rejected_NS, grid_n_gr_rp_rejected_NS
     ncdf_varput, cdfid, n_gr_rr_rejected_NS, grid_n_gr_rr_rejected_NS
     ncdf_varput, cdfid, n_gr_hid_rejected_NS, grid_n_gr_hid_rejected_NS
     ncdf_varput, cdfid, n_gr_dzero_rejected_NS, grid_n_gr_dzero_rejected_NS
     ncdf_varput, cdfid, n_gr_nw_rejected_NS, grid_n_gr_nw_rejected_NS
     ncdf_varput, cdfid, n_gr_dm_rejected_NS, grid_n_gr_dm_rejected_NS
     ncdf_varput, cdfid, n_gr_n2_rejected_NS, grid_n_gr_n2_rejected_NS
     ncdf_varput, cdfid, n_gr_expected_NS, grid_n_gr_expected_NS
     ncdf_varput, cdfid, precipTotPSDparamHigh_NS, grid_precipTotPSDparamHigh_NS
     ncdf_varput, cdfid, precipTotPSDparamLow_NS, grid_precipTotPSDparamLow_NS
     ncdf_varput, cdfid, precipTotRate_NS, grid_precipTotRate_NS
     ncdf_varput, cdfid, precipTotWaterCont_NS, grid_precipTotWaterCont_NS
     ncdf_varput, cdfid, n_precipTotPSDparamHigh_rejected_NS, grid_n_precipTotPSDparamHigh_rejected_NS
     ncdf_varput, cdfid, n_precipTotPSDparamLow_rejected_NS, grid_n_precipTotPSDparamLow_rejected_NS
     ncdf_varput, cdfid, n_precipTotRate_rejected_NS, grid_n_precipTotRate_rejected_NS
     ncdf_varput, cdfid, n_precipTotWaterCont_rejected_NS, grid_n_precipTotWaterCont_rejected_NS
     ncdf_varput, cdfid, precipitationType_NS, grid_precipitationType_NS
     ncdf_varput, cdfid, surfPrecipTotRate_NS, grid_surfPrecipTotRate_NS
     ncdf_varput, cdfid, surfaceElevation_NS, grid_surfaceElevation_NS
     ncdf_varput, cdfid, zeroDegAltitude_NS, grid_zeroDegAltitude_NS
     ncdf_varput, cdfid, zeroDegBin_NS, grid_zeroDegBin_NS
     ncdf_varput, cdfid, surfaceType_NS, grid_surfaceType_NS
     ncdf_varput, cdfid, phaseBinNodes_NS, grid_phaseBinNodes_NS
     ncdf_varput, cdfid, DPRlatitude_NS, grid_DPRlatitude_NS
     ncdf_varput, cdfid, DPRlongitude_NS, grid_DPRlongitude_NS
     ncdf_varput, cdfid, scanNum_NS, grid_scanNum_NS
     ncdf_varput, cdfid, rayNum_NS, grid_rayNum_NS
     ncdf_varput, cdfid, ellipsoidBinOffset_NS, grid_ellipsoidBinOffset_NS
     ncdf_varput, cdfid, lowestClutterFreeBin_NS, grid_lowestClutterFreeBin_NS
     ncdf_varput, cdfid, clutterStatus_NS, grid_clutterStatus_NS
     ncdf_varput, cdfid, precipitationFlag_NS, grid_precipitationFlag_NS
     ncdf_varput, cdfid, surfaceRangeBin_NS, grid_surfaceRangeBin_NS
     ncdf_varput, cdfid, correctedReflectFactor_NS, grid_correctedReflectFactor_NS
     ncdf_varput, cdfid, pia_NS, grid_pia_NS
     ncdf_varput, cdfid, stormTopAltitude_NS, grid_stormTopAltitude_NS
     ncdf_varput, cdfid, n_correctedReflectFactor_rejected_NS, grid_n_correctedReflectFactor_rejected_NS
     ncdf_varput, cdfid, n_dpr_expected_NS, grid_n_dpr_expected_NS

     NCDF_CLOSE, cdfid

     ;Clearing out the arrays to improve memory:
     grid_latitude_MS=0 & grid_longitude_MS=0 & grid_xCorners_MS=0 & grid_yCorners_MS=0
     grid_topHeight_MS=0 & grid_bottomHeight_MS=0 & grid_topHeight_MS_MSL=0 & grid_bottomHeight_MS_MSL=0
     grid_GR_Z_MS=0 & grid_GR_Z_StdDev_MS=0 & grid_GR_Z_Max_MS=0 & grid_GR_Zdr_MS=0 & grid_GR_Zdr_StdDev_MS=0
     grid_GR_Zdr_Max_MS=0 & grid_GR_Kdp_MS=0 & grid_GR_Kdp_StdDev_MS=0 & grid_GR_Kdp_Max_MS=0 
     grid_GR_RHOhv_MS=0 & grid_GR_RHOhv_StdDev_MS=0 & grid_GR_RHOhv_Max_MS=0 & grid_GR_RC_rainrate_MS=0
     grid_GR_RC_rainrate_StdDev_MS=0 & grid_GR_RC_rainrate_Max_MS=0 & grid_GR_RP_rainrate_MS=0 
     grid_GR_RP_rainrate_StdDev_MS=0 & grid_GR_RP_rainrate_Max_MS=0 & grid_GR_RR_rainrate_MS=0
     grid_GR_RR_rainrate_StdDev_MS=0 & grid_GR_RR_rainrate_Max_MS=0 & grid_GR_HID_MS=0 & grid_GR_Dzero_MS=0
     grid_GR_Dzero_StdDev_MS=0 & grid_GR_Dzero_Max_MS=0 & grid_GR_Nw_MS=0 & grid_GR_Nw_StdDev_MS=0
     grid_GR_Nw_Max_MS=0 & grid_GR_Dm_MS=0 & grid_GR_Dm_StdDev_MS=0 & grid_GR_Dm_Max_MS=0
     grid_GR_N2_MS=0 & grid_GR_N2_StdDev_MS=0 & grid_GR_N2_Max_MS=0 & grid_GR_blockage_MS=0
     grid_n_gr_z_rejected_MS=0 & grid_n_gr_zdr_rejected_MS=0 & grid_n_gr_kdp_rejected_MS=0
     grid_n_gr_rhohv_rejected_MS=0 & grid_n_gr_rc_rejected_MS=0 & grid_n_gr_rp_rejected_MS=0
     grid_n_gr_rr_rejected_MS=0 & grid_n_gr_hid_rejected_MS=0 & grid_n_gr_dzero_rejected_MS=0
     grid_n_gr_nw_rejected_MS=0 & grid_n_gr_dm_rejected_MS=0 & true_grid_n_gr_dm_rejected_MS=0
     grid_n_gr_n2_rejected_MS=0 & true_grid_n_gr_n2_rejected_MS=0 & grid_n_gr_expected_MS=0
     grid_precipTotPSDparamHigh_MS=0 & grid_precipTotPSDparamLow_MS=0 & grid_precipTotRate_MS=0
     grid_precipTotWaterCont_MS=0 & grid_n_precipTotPSDparamHigh_rejected_MS=0 
     grid_n_precipTotPSDparamLow_rejected_MS=0 & grid_n_precipTotRate_rejected_MS=0
     grid_n_precipTotWaterCont_rejected_MS=0 & grid_precipitationType_MS=0 & grid_surfPrecipTotRate_MS=0
     grid_surfaceElevation_MS=0 & grid_zeroDegAltitude_MS=0 & grid_zeroDegBin_MS=0
     grid_surfaceType_MS=0 & grid_phaseBinNodes_MS=0 & grid_DPRlatitude_MS=0 & grid_DPRlongitude_MS=0
     grid_scanNum_MS=0 & grid_rayNum_MS=0 & grid_ellipsoidBinOffset_MS=0 & grid_lowestClutterFreeBin_MS=0
     grid_clutterStatus_MS=0 & grid_precipitationFlag_MS=0 & grid_surfaceRangeBin_MS=0
     grid_correctedReflectFactor_MS=0 & grid_pia_MS=0 & grid_stormTopAltitude_MS=0
     grid_n_correctedReflectFactor_rejected_MS=0 & grid_n_dpr_expected_MS=0

     grid_latitude_NS=0 & grid_longitude_NS=0 & grid_xCorners_NS=0 & grid_yCorners_NS=0
     grid_topHeight_NS=0 & grid_bottomHeight_NS=0 & grid_topHeight_NS_MSL=0 & grid_bottomHeight_NS_MSL=0
     grid_GR_Z_NS=0 & grid_GR_Z_StdDev_NS=0 & grid_GR_Z_Max_NS=0 & grid_GR_Zdr_NS=0
     grid_GR_Zdr_StdDev_NS=0 & grid_GR_Zdr_Max_NS=0 & grid_GR_Kdp_NS=0 & grid_GR_Kdp_StdDev_NS=0
     grid_GR_Kdp_Max_NS=0 & grid_GR_RHOhv_NS=0 & grid_GR_RHOhv_StdDev_NS=0 & grid_GR_RHOhv_Max_NS=0
     grid_GR_RC_rainrate_NS=0 & grid_GR_RC_rainrate_StdDev_NS=0 & grid_GR_RC_rainrate_Max_NS=0
     grid_GR_RP_rainrate_NS=0 & grid_GR_RP_rainrate_StdDev_NS=0 & grid_GR_RP_rainrate_Max_NS=0
     grid_GR_RR_rainrate_NS=0 & grid_GR_RR_rainrate_StdDev_NS=0 & grid_GR_RR_rainrate_Max_NS=0
     grid_GR_HID_NS=0 & grid_GR_Dzero_NS=0 & grid_GR_Dzero_StdDev_NS=0 & grid_GR_Dzero_Max_NS=0
     grid_GR_Nw_NS=0 & grid_GR_Nw_StdDev_NS=0 & grid_GR_Nw_Max_NS=0 & grid_GR_Dm_NS=0
     grid_GR_Dm_StdDev_NS=0 & grid_GR_Dm_Max_NS=0 & grid_GR_N2_NS=0 & grid_GR_N2_StdDev_NS=0
     grid_GR_N2_Max_NS=0 & grid_GR_blockage_NS=0 & grid_n_gr_z_rejected_NS=0 & grid_n_gr_zdr_rejected_NS=0
     grid_n_gr_kdp_rejected_NS=0 & grid_n_gr_rhohv_rejected_NS=0 & grid_n_gr_rc_rejected_NS=0
     grid_n_gr_rp_rejected_NS=0 & grid_n_gr_rr_rejected_NS=0 & grid_n_gr_hid_rejected_NS=0 
     grid_n_gr_dzero_rejected_NS=0 & grid_n_gr_nw_rejected_NS=0 & grid_n_gr_dm_rejected_NS=0
     true_grid_n_gr_dm_rejected_NS=0 & grid_n_gr_n2_rejected_NS=0 & true_grid_n_gr_n2_rejected_NS=0
     grid_n_gr_expected_NS=0 & grid_precipTotPSDparamHigh_NS=0 & grid_precipTotPSDparamLow_NS=0
     grid_precipTotRate_NS=0 & grid_precipTotWaterCont_NS=0 & grid_n_precipTotPSDparamHigh_rejected_NS=0
     grid_n_precipTotPSDparamLow_rejected_NS=0 & grid_n_precipTotRate_rejected_NS=0 & grid_n_precipTotWaterCont_rejected_NS=0
     grid_precipitationType_NS=0 & grid_surfPrecipTotRate_NS=0 & grid_surfaceElevation_NS=0
     grid_zeroDegAltitude_NS=0 & grid_zeroDegBin_NS=0 & grid_surfaceType_NS=0 & grid_phaseBinNodes_NS=0
     grid_DPRlatitude_NS=0 & grid_DPRlongitude_NS=0 & grid_scanNum_NS=0 & grid_rayNum_NS=0
     grid_ellipsoidBinOffset_NS=0 & grid_lowestClutterFreeBin_NS=0 & grid_clutterStatus_NS=0
     grid_precipitationFlag_NS=0 & grid_surfaceRangeBin_NS=0 & grid_correctedReflectFactor_NS=0 & grid_pia_NS=0 
     grid_stormTopAltitude_NS=0 & grid_n_correctedReflectFactor_rejected_NS=0 & grid_n_dpr_expected_NS=0
     
     print, 'It is compressing the original file'
     ;To internally compress the file (the compressed file has a "_comp" extension):
     spawn, ' nccopy -d9 '+indir+'gridded_CONUS/'+strcompress(year[aa])+'/GRtoDPRGMI.gridded.CONUS.'+$
		    strcompress(filedate[0],/remove_all)+$
                    '.'+strcompress(grid_orbitnr,/remove_all)+'.V06A.1_3.15dBZ.nc  ' $
		    +indir+'gridded_CONUS/'+strcompress(year[aa])+'/GRtoDPRGMI.gridded.CONUS.'+$
                    strcompress(filedate[0],/remove_all)+$
                    '.'+strcompress(grid_orbitnr,/remove_all)+'.V06A.1_3.15dBZ_comp.nc'
     ;To gzip the file:
     spawn,  ' gzip -f '+indir+'gridded_CONUS/'+strcompress(year[aa])+'/GRtoDPRGMI.gridded.CONUS.'+$
                    strcompress(filedate[0],/remove_all)+$
                    '.'+strcompress(grid_orbitnr,/remove_all)+'.V06A.1_3.15dBZ_comp.nc'
     print, 'It is zipping the new compressed file'

     ;To remove the original file (that is VERY large):
     spawn, ' rm -f '+indir+'gridded_CONUS/'+strcompress(year[aa])+'/GRtoDPRGMI.gridded.CONUS.'+$
                    strcompress(filedate[0],/remove_all)+$
                    '.'+strcompress(grid_orbitnr,/remove_all)+'.V06A.1_3.15dBZ.nc  '

   endif ;For the file domain relative to CONUS domain test
  endfor ;dd number of unique orbits 
endfor ;aa ;The number of years

;stop ;Keeping this stop for in case someone wants to test things
end
