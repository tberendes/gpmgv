;+
; Copyright © 2016, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
;-------------------------------------------------------------------------------
; getMetadata2AGPROF.pro    Bob Morris, GPM GV (SAIC)    May 2016
;
; DESCRIPTION
;
; Reads delimited text file listing a 2A-GPROF file name, its orbit number,
; satelliteID, and the number of GV radar sites overpassed, followed by the ID,
; latitude, and longitude of each overpassed site on separate lines, one
; site's data per line.  These repeat for each file/orbit to be processed in
; a run of this program.  See get2AGPROFMeta.sh script for how the
; delimited file is created.
;
; For each file/orbit/site, the 2AGPROF HDF file is unzipped and extract2aGPROFmeta
; is called to open and read the file; generate the 300x300 km grid of 4 km
; resolution centered on the radar site lat/lon for the Rain Rate elements;
; extract metadata of the number of gridpoints of "rain certain" state; and
; write the site overpass event ID and the metadata IDs and values to
; separate lines in a database-compatible delimited text file.
;
; HISTORY
;
; Morris - May 11 2016 - Created from getMetadata2ADPR.pro.
;
; FILES
;
; tmpdirname/file2aGPROFsites.YYMMDD.txt (INPUT) - lists 2AGPROF file to process,
;    its orbit, and information on the overpassed NEXRAD sites, where YYMMDD
;    is the year, month, day of the parent script's run.  File pathname
;    is specified by the GETMYMETA environment variable's value.
;
; 2A-CS-CONUS.sat.imager.2AGPROF.YYYYMMDD-Shhmmss-Ehhmmss.ORBIT#.Vnn.HDF
;    HDF data file to be processed, where YYYYMMDD is the year/month/day, sat is
;    the satelliteID, imager is the instrument name, and ORBIT#.V are the
;    satellite orbit number and version, as listed (as full FILE PATHNAME)
;    in the file2aGPROFsites.YYMMDD.txt file.
;
; tmpdirname/2AGPROF_METADATA.YYMMDD.txt (OUTPUT) - delimited text file listing
;    the number of rain-certain gridpoints  for each site overpass, one value
;    per line, labeled with the overpass event_num and the ID of the metadata
;    value.  The YYMMDD is given by the RUNDATE environment variable's value.
;
; MANDATORY ENVIRONMENT VARIABLES
;
; 1) GETMYMETA - fully-qualified file pathname to INPUT file
;                'file2aGPROFsites.YYMMDD.txt'
; 2) RUNDATE   - year, month, and day of parent script's run in YYMMDD format
;
;
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;-------------------------------------------------------------------------------

pro getMetadata2AGPROF

common sample, start_sample,sample_range
common time, TRMM_TIME, hh_gv, mm_gv, ss_gv, year, month, day, orbit
common groundSite, event_num, siteID, siteLong, siteLat, nsites

Tbegin = SYSTIME(1)

; NEED SOME ERROR CHECKING ON THESE ENVIRONMENT VARIABLE VALUES (CHECK FOR
; NULLS)
; find, open the input file listing 2AGPROF HDF files and NEXRAD sites/lats/lons
FILES4META = GETENV("GETMYMETA")
OPENR, lun0, FILES4META, ERROR=err, /GET_LUN
tmpdirname = FILE_DIRNAME(FILES4META)
datadirpos = STRPOS(tmpdirname, '/tmp')
IF datadirpos GT 0 THEN datadirname = STRMID( tmpdirname, 0, datadirpos ) $
                   ELSE datadirname = tmpdirname

; create and open the OUTPUT file
DATESTAMP = GETENV("RUNDATE")
GPROFmetafile = tmpdirname+"/2AGPROF_METADATA."+DATESTAMP+".unl"
GET_LUN, UNLUNIT
OPENW, UNLUNIT, GPROFmetafile

; initialize the variables into which file records are read as strings
data4 = ''
event_site_lat_lon = ''

; Compute a radial distance array for a 4-km-resolution 2-D grid of
; dimensions 75x75 points where x- and y-distance at center point is 0.0 km
xdist = findgen(75,75)
xdist = ((xdist mod 75.) - 37.) * 4.
ydist = TRANSPOSE(xdist)
dist = SQRT(xdist*xdist + ydist*ydist)

While not (EOF(lun0)) Do Begin 

;  read the '|'-delimited input file record into a single string
   READF, lun0, data4

;  parse data4 into its component fields: 2AGPROF file name,
;  orbit number, number of sites

   parsed=strsplit( data4, '|', /extract )

   origFileGPROFName = parsed[0] ; 2AGPROF filename as listed in/on the database/disk
;  check whether origFileGPROFName is the full, existing pathname to the 2AGPROF file
   IF FILE_TEST(origFileGPROFName, /REGULAR) EQ 1 THEN BEGIN
      file_2aGPROF = origFileGPROFName
   ENDIF ELSE BEGIN
      print, "In getMetadata2AGPROF, file 2AGPROF not found: "+origFileGPROFName
      goto, errorExit
   ENDELSE

   orbit = long( parsed[1] )
   nsites=fix( parsed[2] )
   print, ""
   print, file_2aGPROF, "  ", orbit, nsites

; parse the file pathname to get the Satellite and Instrument IDs
   parsed2a=strsplit( file_2aGPROF, '/', /extract )
   Satellite = parsed2a[3]
   Instrument = parsed2a[4]

; replace GPM satellite ID with GMI instrument ID, we already use GPM to tag
; metadata values from the 2ADPR/2AKu product
   IF Satellite EQ 'GPM' THEN Satellite=Instrument

; Check status of file_2aGPROF before proceeding - may need to pare down file
; extensions.
   havefile = find_alt_filename( file_2aGPROF, found2aGPROF )
   if ( havefile ) then begin
;     Get an uncompressed copy of the found file
      cpstatus = uncomp_file( found2aGPROF, file_2do )
      if(cpstatus eq 'OK') then begin

;  Process RainType metadata for each site overpassed for this orbit/filename.
;  Put event#s/sites/lats/lons into array variables in groundSite COMMON.

         event_num = lonarr(nsites) & event_num[*] = 0L
         siteID = strarr(nsites)    & siteID[*] = ""
         siteLat = fltarr(nsites)   & siteLat[*] = -999.0
         siteLong = fltarr(nsites)  & siteLong[*] = -999.0

         for i=0, nsites-1 do begin
;           read each overpassed site's information as a '|'-delimited string
            READF, lun0, event_site_lat_lon
;            print, i+1, ": ", event_site_lat_lon
;           parse the delimited string into event_num, siteID, latitude, and longitude
            parsed=strsplit( event_site_lat_lon, '|', /extract )
            event_num[i] = long( parsed[0] )
            siteID[i] = parsed[1]
            siteLat[i] = float( parsed[2] )
            siteLong[i] = float( parsed[3] )
;            print, i+1, ": ", event_num[i], "  ", siteID[i], siteLat[i], siteLong[i]
         endfor

;        reinitialize the common variables and call extract2AGPROFmeta to extract
;        the overpass metadata
         SAMPLE_RANGE=0
         START_SAMPLE=0
;         END_SAMPLE=0
         TRMM_TIME='00:00:00'

         status = extract2AGPROFmeta( file_2do, Satellite, dist, unlunit )

         if ( status NE 'OK' ) then begin
           print, "In getmetadata2aGPROF.pro, error in processing ", file_2do
         endif

;        Delete the temporary file copy
         print, "Remove 2aGPROF file copy:"
         command = 'rm -fv ' + file_2do
;         print, command
         spawn, command
      endif else begin
         print, cpstatus
         goto, errorExit
      endelse
   endif else begin
      print, "Cannot find regular/compressed file " + file_2aGPROF
      goto, errorExit
   endelse

EndWhile


errorExit:
CLOSE, lun0  &   FREE_LUN, lun0
FREE_LUN, UNLUNIT

;print
;print, "getMetadata2AGPROF elapsed time in seconds: ", SYSTIME(1) - Tbegin
print
message, "Output metadata written to: "+GPROFmetafile, /INFO
end
