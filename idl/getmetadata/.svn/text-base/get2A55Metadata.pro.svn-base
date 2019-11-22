;+
;-------------------------------------------------------------------------------
; get2A55Metadata.pro    Bob Morris, GPM GV (SAIC)    November 2006
;
; DESCRIPTION
;
; Reads delimited text file listing a 2A55 file name, its NEXRAD site ID, one
; site file's data per line.  These repeat for each file to be processed in
; a run of this program.  See doAll2A55Meta.sh script for how the
; delimited file is created.
;
; For each file, the 2A55 HDF file is gunzip'ped and access2a55
; is called to open and read the file; read the 300x300 km grids of 2 km
; resolution centered on the radar site lat/lon for the reflectivity element;
; extract a 
;  and write the filename, site
; ID, orbit, and the values to a new line in a database-
; compatible delimited text file.
;
; "get2A55Metadata.pro" is based very loosely on Liang Liao's
;  "comparison_PR_GV_dBZ.pro" routine.
; "access2A55.pro" is a highly-modified version of Liang's routine of the
;  same name.
; "read_2a55.pro" and "remove_path.pro" are unmodified from Liang's
;  versions.
;
; FILES
;
; /data/tmp/file2a55sites.YYMMDD.txt (INPUT) - lists 2A55 files to process,
;    their orbit, and information on the overpassed NEXRAD sites, where YYMMDD
;    is the year, month, day of the parent script's run.  File pathname
;    is specified by the GETMYMETA environment variable's value.
;
; 2A55.YYMMDD.(H)H.Kxxx.5.HDF.gz (INPUT) - HDF format, 2km 3-D gridded NEXRAD
;    data files to be processed, where YYMMDD is the year/month/day, (H)H is the
;    hour (1 or 2 digits), Kxxx is the NEXRAD site ID, as listed (as FILE
;    BASENAME only) in the file2a55sites.YYMMDD.txt file.
;
; /data/tmp/2A55_HISTOGRAM.YYMMDD.txt (OUTPUT) - delimited text file listing
;    the number of gridpoints of type Stratiform, Convective, Others, No Rain,
;    and Missing Data for each site overpass, one value per line, labeled with
;    the overpass event_num and the ID of the metadata value.  The YYMMDD is
;    given by the RUNDATE environment variable's value.
;
; MANDATORY ENVIRONMENT VARIABLES
;
; 1) GETMYMETA - fully-qualified file pathname to INPUT file
;                'file2a55sites.YYMMDD.txt'
; 2) RUNDATE   - year, month, and day of parent script's run in YYMMDD format
;
;-------------------------------------------------------------------------------
;-

pro get2A55Metadata

common sample, start_sample,sample_range,num_range,dbz_min,dbz_max
common time, TRMM_TIME, hh_gv, mm_gv, ss_gv, year, month, day; orbit
common groundSite, event_num, siteID, siteLong, siteLat, nsites


DBZ_MIN = 15
DBZ_MAX = 55
Height = 3.0   ; Altitude above ground (km)

CASE fix(Height*10) of

   15: nHeight = 0
   30: nHeight = 1
   45: nHeight = 2
   60: nHeight = 3
   75: nHeight = 4
   90: nHeight = 5
   
ELSE: STOP

ENDCASE


; NEED SOME ERROR CHECKING ON THESE ENVIRONMENT VARIABLE VALUES (CHECK FOR
; NULLS)
; find, open the input file listing 2A55 HDF files and NEXRAD sites
FILES4META = GETENV("GETMYMETA")
OPENR, lun0, FILES4META, ERROR=err, /GET_LUN

; create and open the OUTPUT file
DATESTAMP = GETENV("RUNDATE")
dbloadfile = "/data/tmp/2A55_VOLUMES."+DATESTAMP+".unl"
GET_LUN, UNLUNIT
OPENW, UNLUNIT, dbloadfile ;, /APPEND

; initialize the variables into which file records are read as strings
data4 = ''
;event_site_lat_lon = ''

While not (EOF(lun0)) Do Begin 

;  read the '|'-delimited input file record into a single string
   READF, lun0, data4

;  parse data4 into its component fields: site ID, 2A55 file pathname

   parsed=strsplit( data4, '/', /extract )
   siteID = parsed[0] ; filename as listed in/on the database/disk
;   origFile55Name = parsed[1] ; filename as listed in/on the database/disk
;  add the well-known path to get the fully-qualified file name
   file_2a55 = "/data/gv_radar/finalQC_in/"+data4
   print, siteID, "  ", file_2a55

; Check status of file_2a55 before proceeding - may need to pare down file
; extensions.
; - Are there better ways than this below to check if compressed (.Z, .gz,,
; etc.)?  This way relies on filename as listed in database, not actual file
; name on disk which may differ if file has been uncompressed already.
   dotgz = STRPOS( file_2a55, ".gz" )
   if (dotgz ne -1) then begin
      command = "gunzip " + file_2a55
      spawn,command
      file_2do = STRMID( file_2a55, 0, dotgz )
   endif else begin
      file_2do = file_2A55
   endelse

;  Process metadata for site for this filename.

;  reinitialize the common variables and call access2A55 to extract
;  the overpass metadata
   SAMPLE_RANGE=0
   START_SAMPLE=0
   END_SAMPLE=0
   TRMM_TIME='00:00:00'
   nvol = 0 ; for testing
   access2A55, file=file_2do, unlout=UNLUNIT, $
               VOL=nvol, nHeight=nHeight, Avg=1, $
;               dbz2A55=dbz_2a55, $
               Hour=hh_gv, Min=mm_gv, Sec=ss_gv, $
               Year=year, Month=month, Day=day
   

;  re-gzip the file if it was originally gzip'ped
   if (dotgz ne -1) then begin
      command = "gzip " + file_2do
      spawn,command
   endif

EndWhile

CLOSE, lun0  &   FREE_LUN, lun0
FREE_LUN, UNLUNIT

stop
end

@access2A55.pro
