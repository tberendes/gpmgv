;+
; Copyright © 2008, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
;-------------------------------------------------------------------------------
; getMetadata2A23.pro    Bob Morris, GPM GV (SAIC)    October 2006
;
; DESCRIPTION
;
; Reads delimited text file listing a 2A23 file name, its orbit number, and
; the number of GPMGV NEXRAD sites overpassed by the PR, followed by the ID,
; latitude, and longitude of each overpassed site on separate lines, one
; site's data per line.  These repeat for each file/orbit to be processed in
; a run of this program.  See get2A23-25Meta.sh script for how the
; delimited file is created.
;
; For each file/orbit/site, the 2A23 HDF file is unzipped and extract2a23meta
; is called to open and read the file; generate the 300x300 km grid of 4 km
; resolution centered on the radar site lat/lon for the Rain Type element;
; extract a histogram of the number of gridpoints of type Stratiform,
; Convective, Others, No Rain, and Missing Data; and write the filename, site
; ID, orbit, and the five histogram values to a new line in a database-
; compatible delimited text file.
;
; "getMetadata2A23.pro" is based very loosely on Liang Liao's
;  "comparison_PR_GV_dBZ.pro" routine.
; "extract2a23meta.pro" is a highly-modified version of Liang's access2A25.pro
;  routine.
; "coordinateBtoA.pro" is slightly modified from Liang's routine (using
;  modified commons).
; "read_2a23_ppi.pro"  is a highly-modified version of Liang's routine.
; "distanceAandB.pro" is unmodified from Liang's version.
;
; HISTORY
;
; Morris - Feb 12 2008 - Added calls to find_alt_filename and uncomp_file
;                        to deal with '.Z' compressed HDF files from the
;                        DAAC for the DARW subset.
; Morris - Jul 8 2008  - Modified call to now-function access2a23, and deal
;                        with returned status.
; Morris - Jul 10 2008 - Modified to call function extract2a23meta() in place
;                        of access2a23() to compute metadata within 100km.
; Morris - Apr 16 2012 - Cleaned up, edited comments.
;                      - Use passed pathname GETMYMETA to find "well-known"
;                        directory paths to 2A23 and 2A25 data files.
; Morris - Mar 27 2014 - Checking whether we have full pathnames to 2A23 and
;                        2A25 data files in control file.
;
; FILES
;
; tmpdirname/file2a23sites.YYMMDD.txt (INPUT) - lists 2A23 files to process,
;    their orbit, and information on the overpassed NEXRAD sites, where YYMMDD
;    is the year, month, day of the parent script's run.  File pathname
;    is specified by the GETMYMETA environment variable's value.
;
; 2A23.[YY]YYMMDD.ORBIT#.V.sub-GPMGV1.hdf.gz (INPUT) - HDF data files to be
;    processed, where [YY]YYMMDD is the year/month/day and ORBIT#.V
;    are the TRMM orbit number and version, as listed (as FILE BASENAME only)
;    in the file2a23sites.YYMMDD.txt file.
; OR
; 2A-CS-CONUS.TRMM.PR.2A23.YYYYMMDD-Shhmmss-Ehhmmss.ORBIT#.V.HDF - as above,
;    but with the GPM-era PPS filename convention, and preceded by the full
;    path to the file.
;
; tmpdirname/2A23_HISTOGRAM.YYMMDD.txt (OUTPUT) - delimited text file listing
;    the number of gridpoints of type Stratiform, Convective, Others, No Rain,
;    and Missing Data for each site overpass, one value per line, labeled with
;    the overpass event_num and the ID of the metadata value.  The YYMMDD is
;    given by the RUNDATE environment variable's value.
;
; MANDATORY ENVIRONMENT VARIABLES
;
; 1) GETMYMETA - fully-qualified file pathname to INPUT file
;                'file2a23sites.YYMMDD.txt'
; 2) RUNDATE   - year, month, and day of parent script's run in YYMMDD format
;
;-------------------------------------------------------------------------------
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-

pro getMetadata2A23

common sample, start_sample,sample_range,num_range,dbz_min,dbz_max
common time, TRMM_TIME, hh_gv, mm_gv, ss_gv, year, month, day, orbit
common groundSite, event_num, siteID, siteLong, siteLat, nsites

Tbegin = SYSTIME(1)

; don't really need these 3 variables (currently)
DBZ_MIN = 15
DBZ_MAX = 55
Height = 3.0   ; Altitude above ground (km)

; NEED SOME ERROR CHECKING ON THESE ENVIRONMENT VARIABLE VALUES (CHECK FOR
; NULLS)
; find, open the input file listing 2A23 HDF files and NEXRAD sites/lats/lons
FILES4META = GETENV("GETMYMETA")
OPENR, lun0, FILES4META, ERROR=err, /GET_LUN
tmpdirname = FILE_DIRNAME(FILES4META)
datadirpos = STRPOS(tmpdirname, '/tmp')
IF datadirpos GT 0 THEN datadirname = STRMID( tmpdirname, 0, datadirpos ) $
ELSE datadirname = tmpdirname

; create and open the OUTPUT file
DATESTAMP = GETENV("RUNDATE")
histofile = tmpdirname+"/2A23_HISTOGRAM."+DATESTAMP+".unl"
GET_LUN, UNLUNIT
OPENW, UNLUNIT, histofile ;, /APPEND

; initialize the variables into which file records are read as strings
data4 = ''
event_site_lat_lon = ''

; Compute a radial distance array of 2-D netCDF grid dimensions
xdist = findgen(75,75)
xdist = ((xdist mod 75.) - 37.) * 4.
ydist = TRANSPOSE(xdist)
dist = SQRT(xdist*xdist + ydist*ydist)

While not (EOF(lun0)) Do Begin 

;  read the '|'-delimited input file record into a single string
   READF, lun0, data4

;  parse data4 into its component fields: 2A23 file name, 2A25 file name,
;  orbit number, number of sites

   parsed=strsplit( data4, '|', /extract )

   origFile23Name = parsed[0] ; 2A23 filename as listed in/on the database/disk
;  check whether origFile23Name is the full, existing pathname to the 2A23 file
   IF FILE_TEST(origFile23Name, /REGULAR) EQ 1 THEN BEGIN
      file_2a23 = origFile23Name
   ENDIF ELSE BEGIN
   ;  add the well-known path to get the fully-qualified file name
      file23path = datadirname+"/prsubsets/2A23"
      IF FILE_TEST(file23path, /DIRECTORY) EQ 0 THEN BEGIN
         print, "In getMetadata2A23, file 2A23 path not found: "+file23path
         goto, errorExit
      ENDIF
      file_2a23 = file23path+'/'+origFile23Name  ; put path in ENV var.
   ENDELSE

   origFile25Name = parsed[1] ; 2A25 filename as listed in/on the database/disk
;  check whether origFile25Name is the full, existing pathname to the 2A25 file
   IF FILE_TEST(origFile25Name, /REGULAR) EQ 1 THEN BEGIN
      file_2a25 = origFile25Name
   ENDIF ELSE BEGIN
      file25path = datadirname+"/prsubsets/2A25"
      IF FILE_TEST(file25path, /DIRECTORY) EQ 0 THEN BEGIN
         print, "In getMetadata2A23, file 2A25 path not found: "+file25path
         goto, errorExit
      ENDIF
      file_2a25 = file25path+'/'+origFile25Name
   ENDELSE

   orbit = long( parsed[2] )
   nsites=fix( parsed[3] )
   print, ""
   print, file_2a23, "  ", orbit, nsites

; Check status of file_2a23 before proceeding - may need to pare down file
; extensions.
   havefile = find_alt_filename( file_2a23, found2a23 )
   if ( havefile ) then begin
;     Get an uncompressed copy of the found file
      cpstatus = uncomp_file( found2a23, file_2do )
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

;        reinitialize the common variables and call access2A23 to extract
;        the overpass metadata
         SAMPLE_RANGE=0
         START_SAMPLE=0
         END_SAMPLE=0
         TRMM_TIME='00:00:00'

         status = extract2A23meta( file_2do, dist, unlunit )

         if ( status NE 'OK' ) then begin
           print, "In getmetadata2a23.pro, error in processing ", file_2do
         endif

;        Delete the temporary file copy
         print, "Remove 2a23 file copy:"
         command = 'rm -fv ' + file_2do
;         print, command
         spawn, command
      endif else begin
         print, cpstatus
         goto, errorExit
      endelse
   endif else begin
      print, "Cannot find regular/compressed file " + file_2a23
      goto, errorExit
   endelse

EndWhile


errorExit:
CLOSE, lun0  &   FREE_LUN, lun0
FREE_LUN, UNLUNIT

print
print, "getMetadata2A23 elapsed time in seconds: ", SYSTIME(1) - Tbegin
print

end
