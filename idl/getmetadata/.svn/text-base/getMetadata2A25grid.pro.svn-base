;+
;-------------------------------------------------------------------------------
; getMetadata2A25grid.pro    Bob Morris, GPM GV (SAIC)    October 2006
;
; DESCRIPTION
;
; Reads delimited text file listing a 2A25 file name, its orbit number, and
; the number of GPMGV NEXRAD sites overpassed by the PR, followed by the ID,
; latitude, and longitude of each overpassed site on separate lines, one
; site's data per line.  These repeat for each file/orbit to be processed in
; a run of this program.  See getPRdaily.sh script for how the delimited
; file is created in SQL.
;
; For each file/orbit and site, the 2A25 HDF file is gunzip'ped and access2a25
; is called to open and read the file; generate the 300x300 km grid of 4 km
; resolution centered on the radar site lat/lon for the Rain Type element;
; extract a histogram of the number of gridpoints of type Stratiform,
; Convective, Others, No Rain, and Missing Data; and write the filename, site
; ID, orbit, and the five histogram values to a new line in a database-
; compatible delimited text file.
;
; "getMetadata.pro" is based very loosely on Liang Liao's
;  "comparison_PR_GV_dBZ.pro" routine.
; "access2A25.pro" is a highly-modified version of Liang's routine of the
;  same name.
; "coordinateBtoA.pro" is slightly modified from Liang's routine (using
;  modified commons).
; "read_2a25_ppi.pro" and "distanceAandB.pro" are unmodified from Liang's
;  versions.
;
; FILES
;
; /data/tmp/file2a23sites.YYMMDD.txt (INPUT) - lists 2A25 files to process,
;    their orbit, and information on the overpassed NEXRAD sites, where YYMMDD
;    is the year, month, day of the parent script's run.  File pathname
;    is specified by the GETMYMETA environment variable's value.
;
; /data/prsubsets/2A25/2A25.YYMMDD.ORBIT#.6.sub-GPMGV1.hdf.gz (INPUT) - HDF
;    data files to be processed, where YYMMDD is the year/month/day and ORBIT#
;    is the TRMM orbit number, as listed (as FILE BASENAME only) in the
;    file2a23sites.YYMMDD.txt file.
;
; /data/tmp/2A25_METADATA.YYMMDD.txt (OUTPUT) - delimited text file listing
;    the site overpass event_num, the ID of the metadata value (either of the
;    average height of the Bright Band, or the percent of the PR-NEXRAD
;    coincident area with defined bright band), and the metadata value itself.
;    The YYMMDD is given by the RUNDATE environment variable's value.
;
; MANDATORY ENVIRONMENT VARIABLES
;
; 1) GETMYMETA - fully-qualified file pathname to INPUT file
;                'file2a23sites.YYMMDD.txt'
; 2) RUNDATE   - year, month, and day of parent script's run in YYMMDD format
;
;-------------------------------------------------------------------------------
;-

pro getMetadata2A25grid

common sample, start_sample,sample_range,num_range,dbz_min,dbz_max
common time, TRMM_TIME, hh_gv, mm_gv, ss_gv, year, month, day, orbit
common groundSite, event_num, siteID, siteLong, siteLat, nsites
common sample_rain, RAIN_MIN, RAIN_MAX                  ; for access2A25

Tbegin = SYSTIME(1)

; don't really need these 3 variables (currently)
DBZ_MIN = 15
DBZ_MAX = 55
Height = 3.0   ; Altitude above ground (km)
;nAvgHeight=2                  ; for access2A25 - put in call??

; NEED SOME ERROR CHECKING ON THESE ENVIRONMENT VARIABLE VALUES (CHECK FOR
; NULLS)
; find, open the input file listing 2A25 HDF files and NEXRAD sites/lats/lons
FILES4META = GETENV("GETMYMETA")
OPENR, lun0, FILES4META, ERROR=err, /GET_LUN

; create and open the OUTPUT file
DATESTAMP = GETENV("RUNDATE")
metadatafile = "/data/tmp/2A25_METADATA."+DATESTAMP+".unl"
GET_LUN, UNLUNIT
OPENW, UNLUNIT, metadatafile ;, /APPEND

; initialize the variables into which file records are read as strings
data4 = ''
event_site_lat_lon = ''

While not (EOF(lun0)) Do Begin 

;  read the '|'-delimited input file record into a single string
   READF, lun0, data4

;  parse data4 into its component fields: 2A23 file name, 2A25 file name,
;  orbit number, number of sites

   parsed=strsplit( data4, '|', /extract )
   origFile23Name = parsed[0] ; filename as listed in/on the database/disk
;  add the well-known path to get the fully-qualified file name
   file_2a23 = "/data/prsubsets/2A23/"+origFile23Name  ; put path in ENV var.
   origFile25Name = parsed[1] ; filename as listed in/on the database/disk
   file_2a25 = "/data/prsubsets/2A25/"+origFile25Name  ; put path in ENV var.
   orbit = long( parsed[2] )
   nsites=fix( parsed[3] )
   print, ""
   print, file_2a25, "  ", orbit, nsites

; Check status of file_2a25 before proceeding - may need to pare down file
; extensions.
; - Are there better ways than this below to check if compressed (.Z, .gz,,
; etc.)?  This way relies on filename as listed in database, not actual file
; name on disk which may differ if file has been uncompressed already.
   dotgz25 = STRPOS( file_2a25, ".gz" )
   if (dotgz25 ne -1) then begin
      command = "gunzip " + file_2a25
      spawn,command
      file_2do = STRMID( file_2a25, 0, dotgz25 )
   endif else begin
      file_2do = file_2A25
   endelse

;  Process RainType metadata for each site overpassed for this orbit/filename.
;  Moved site-looping into access2A25 so that the HDF file only needs
;  to be opened and read once.  Put sites/lats/lons into an array of structs
;  and pass to access2A25.

   event_num = lonarr(nsites) & event_num[*] = 0L
   siteID = strarr(nsites)    & siteID[*] = ""
   siteLat = fltarr(nsites)   & siteLat[*] = -999.0
   siteLong = fltarr(nsites)  & siteLong[*] = -999.0

   for i=0, nsites-1 do begin
;     read each overpassed site's information as a '|'-delimited string
      READF, lun0, event_site_lat_lon
;      print, i+1, ": ", event_site_lat_lon
;     parse the delimited string into event_num, siteID, latitude, and
;     longitude fields
      parsed=strsplit( event_site_lat_lon, '|', /extract )
      event_num[i] = long( parsed[0] )
      siteID[i] = parsed[1]
      siteLat[i] = float( parsed[2] )
      siteLong[i] = float( parsed[3] )
;      print, i+1, ": ", event_num[i], "  ", siteID[i], siteLat[i], siteLong[i]
   endfor

;  reinitialize the common variables and call access2A25 to extract
;  the overpass metadata
   SAMPLE_RANGE=0
   START_SAMPLE=0
   END_SAMPLE=0
   TRMM_TIME='00:00:00'
   RAIN_MIN = 0.01
   RAIN_MAX = 60.

   access2A25grids, file=file_2do, unlout=UNLUNIT, Height=height, $
               nAvgHeight=2, dbz2A25=dbz_2a25, SURF_RAIN=surfRain, $
               RAIN=rain_2a25, RANGE_BIN_BB=BB_Hgt, FLAG_RAIN=rainFlagMap

;  re-gzip the file if it was originally gzip'ped
   if (dotgz25 ne -1) then begin
      command = "gzip " + file_2do
      spawn,command
   endif

EndWhile

CLOSE, lun0  &   FREE_LUN, lun0
FREE_LUN, UNLUNIT

print
print, "getMetadata2A25 elapsed time in seconds: ", SYSTIME(1) - Tbegin
print

stop
end

@access2A25grids.pro
@coordinateBtoA
