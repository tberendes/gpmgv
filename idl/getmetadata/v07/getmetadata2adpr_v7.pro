;+
; Copyright © 2014, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
;-------------------------------------------------------------------------------
; getmetadata2adpr_v7.pro    Bob Morris, GPM GV (SAIC)    March 2014
;
; DESCRIPTION
;
; Reads delimited text file listing a 2ADPR or 2AKu file name, its orbit number,
; and the number of GPMGV NEXRAD sites overpassed by GPM, followed by the ID,
; latitude, and longitude of each overpassed site on separate lines, one
; site's data per line.  These repeat for each file/orbit to be processed in
; a run of this program.  See get2ADPRMeta.sh script for how the
; delimited file is created.
;
; For each file/orbit/site, the 2Axxx HDF file is unzipped and extract2aDPRmeta
; is called to open and read the file; generate the 300x300 km grid of 4 km
; resolution centered on the radar site lat/lon for the Rain Type, PrecipFlag,
; BBheight and qualityBB elements; extract metadata of the number of gridpoints
; of type Stratiform, Convective, Others, No Rain, Missing Data, bright band
; existence/height and "rain certain" state; and write the site overpass event
; ID and the metadata IDs and values values to separate lines in a database-
; compatible delimited text file.
;
; HISTORY
;
; Morris - Mar 31 2014 - Created from getMetadata2A23.pro.
;
; Berendes - June 15 2020 - modified for GPM V7.
;
; FILES
;
; tmpdirname/file2aDPRsites.YYMMDD.txt (INPUT) - lists 2ADPR/Ku file to process,
;    its orbit, and information on the overpassed NEXRAD sites, where YYMMDD
;    is the year, month, day of the parent script's run.  File pathname
;    is specified by the GETMYMETA environment variable's value.
;
; 2A-CS-CONUS.GPM.DPR.2ADPR.YYYYMMDD-Shhmmss-Ehhmmss.ORBIT#.Vnn.HDF - HDF data
;    file to be processed, where YYYYMMDD is the year/month/day and ORBIT#.V
;    are the GPM orbit number and version, as listed (as full FILE PATHNAME)
;    in the file2aDPRsites.YYMMDD.txt file.
;
; tmpdirname/2ADPR_METADATA.YYMMDD.txt (OUTPUT) - delimited text file listing
;    the number of gridpoints of type Stratiform, Convective, Others, No Rain,
;    and Missing Data for each site overpass, one value per line, labeled with
;    the overpass event_num and the ID of the metadata value.  The YYMMDD is
;    given by the RUNDATE environment variable's value.
;
; MANDATORY ENVIRONMENT VARIABLES
;
; 1) GETMYMETA - fully-qualified file pathname to INPUT file
;                'file2aDPRsites.YYMMDD.txt'
; 2) RUNDATE   - year, month, and day of parent script's run in YYMMDD format
;
;-------------------------------------------------------------------------------
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-

pro getMetadata2ADPR_v7

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
; find, open the input file listing 2ADPR HDF files and NEXRAD sites/lats/lons
FILES4META = GETENV("GETMYMETA")
print, "FILES4META "+FILES4META
OPENR, lun0, FILES4META, ERROR=err, /GET_LUN
tmpdirname = FILE_DIRNAME(FILES4META)
datadirpos = STRPOS(tmpdirname, '/tmp')
IF datadirpos GT 0 THEN datadirname = STRMID( tmpdirname, 0, datadirpos ) $
                   ELSE datadirname = tmpdirname

; create and open the OUTPUT file
DATESTAMP = GETENV("RUNDATE")
DPRmetafile = tmpdirname+"/2ADPR_METADATA."+DATESTAMP+".unl"
GET_LUN, UNLUNIT
OPENW, UNLUNIT, DPRmetafile

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

;  parse data4 into its component fields: 2ADPR file name,
;  orbit number, number of sites

   parsed=strsplit( data4, '|', /extract )

   origFileDPRName = parsed[0] ; 2ADPR filename as listed in/on the database/disk
;  check whether origFileDPRName is the full, existing pathname to the 2ADPR file
   IF FILE_TEST(origFileDPRName, /REGULAR) EQ 1 THEN BEGIN
      file_2aDPR = origFileDPRName
   ENDIF ELSE BEGIN
      print, "In getMetadata2ADPR, file 2ADPR not found: "+origFileDPRName
      goto, errorExit
   ENDELSE

   orbit = long( parsed[1] )
   nsites=fix( parsed[2] )
   print, ""
   print, file_2aDPR, "  ", orbit, nsites

; parse the file pathname to get the Instrument ID (DPR or Ku)
   parsed2a=strsplit( file_2aDPR, '/', /extract )
   Instrument = parsed2a[4]
; $$$$$$$$$$$$ commented this out for testing $$$$$$$$$$$$$$$$$$
;   IF (Instrument NE 'DPR' AND Instrument NE 'Ku' Instrument NE 'DPRX' AND Instrument NE 'KuX') THEN $
;      message, "Illegal data source '"+Instrument+"', only DPR or Ku allowed."

; Check status of file_2aDPR before proceeding - may need to pare down file
; extensions.
   havefile = find_alt_filename( file_2aDPR, found2aDPR )
   if ( havefile ) then begin
;     Get an uncompressed copy of the found file
      cpstatus = uncomp_file( found2aDPR, file_2do )
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

;        reinitialize the common variables and call extract2ADPRmeta_v7 to extract
;        the overpass metadata
         SAMPLE_RANGE=0
         START_SAMPLE=0
;         END_SAMPLE=0
         TRMM_TIME='00:00:00'

         status = extract2ADPRmeta_v7( file_2do, Instrument, dist, unlunit )

         if ( status NE 'OK' ) then begin
           print, "In getmetadata2aDPR_v7.pro, error in processing ", file_2do
         endif

;        Delete the temporary file copy
         print, "Remove 2aDPR file copy:"
         command = 'rm -fv ' + file_2do
;         print, command
         spawn, command
      endif else begin
         print, cpstatus
         goto, errorExit
      endelse
   endif else begin
      print, "Cannot find regular/compressed file " + file_2aDPR
      goto, errorExit
   endelse

EndWhile


errorExit:
CLOSE, lun0  &   FREE_LUN, lun0
FREE_LUN, UNLUNIT

;print
;print, "getMetadata2ADPR_v7 elapsed time in seconds: ", SYSTIME(1) - Tbegin
print
message, "Output metadata written to: "+DPRmetafile, /INFO
end
