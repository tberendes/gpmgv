;+
; Copyright © 2017, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
;-------------------------------------------------------------------------------
; grid_2agprof_driver.pro    Bob Morris, GPM GV (SAIC)    Feb 2017
;
; DESCRIPTION
;
; Reads delimited text file listing a 2A-GPROF file name, its orbit number,
; satelliteID, and the number of GV radar sites overpassed, followed by the ID,
; latitude, and longitude of each overpassed site on separate lines, one
; site's data per line.  These repeat for each file/orbit to be processed in
; a run of this program.  See do_AnySite_AnyGPROF_RRgrids.sh script for how the
; delimited file is created.
;
; For each file/orbit/site, grid_2agprof_fields is called to open and read the
; 2AGPROF HDF file; generate the 300x300 km grid of 25 km resolution (default
; grid) centered on the radar site lat/lon for the Rain Rate elements; and
; write the gridded rain rate to a binary IDL Save file.  If RES_KM and NXNY
; are supplied, these values will be used in place of the default grid spacing
; and dimensions.  If NEAREST_NEIGHBOR is set, then this method of gridding will
; be used for rain rate, otherwise the GRIDDATA() interpolation method will be
; RADIAL_BASIS_FUNCTION with a natural spline fit.  If FIND_RAIN is set, then
; the grid file will be saved only if a sufficient fraction of grid points
; within 150 km range of the ground radar indicate rain rates above a fixed
; threshold.
;
;
; HISTORY
;
; Morris - Feb 22 2017 - Created from getMetadata2AGPROF.pro.
;
;
; FILES
;
; tmpdirname/file2aGPROFsites.YYMMDD.txt (INPUT) - lists 2AGPROF file to process,
;    its orbit, and information on the overpassed NEXRAD sites, where YYMMDD
;    is the year, month, day of the parent script's run.  File pathname
;    is specified by the FILES4META keyword parameter's value.
;
; 2A-CS-CONUS.sat.imager.2AGPROF.YYYYMMDD-Shhmmss-Ehhmmss.ORBIT#.Vnn.HDF
;    HDF data file to be processed, where YYYYMMDD is the year/month/day, sat is
;    the satelliteID, imager is the instrument name, and ORBIT#.V are the
;    satellite orbit number and version, as listed (as full FILE PATHNAME)
;    in the file2aGPROFsites.YYMMDD.txt file.
;
; outdir/RRgrid.SITE.YYYYMMDD.orbit.version.ADD.sav (OUTPUT) - binary
;    IDL Save file containing the gridded GPROF rain rate and other array
;    variables for a site overpass.  The YYYYMMDD Site, orbit, and version are
;    extracted from values in data fields and the GPROF filenames in the control
;    file.  The ADD field depends on the state of the NEAREST_NEIGHBOR and
;    RES_KM parameters (see add2sav in code).
;
;
; MANDATORY PARAMETERS
;
; 1) FILES4META - fully-qualified file pathname to INPUT control file
;                 'file2aGPROFsites.YYMMDD.txt'
; 2) outdir     - directory path to which the output Save files are written
;
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;-------------------------------------------------------------------------------

pro grid_2agprof_driver, FILES4META, outdir, RES_KM=res_km, NXNY=nxny, $
                         NEAREST_NEIGHBOR=nearest_neighbor, FIND_RAIN=find_rain

Tbegin = SYSTIME(1)

; add a '_NN' indicator to output Save file name if doing nearest neighbor,
; otherwise add '_RadFun' by default.  Describes gridding algorithm used.
IF KEYWORD_SET(nearest_neighbor) THEN add2sav='_NN' ELSE add2sav='_RadFun'

; Default: Compute a radial distance array for a 25-km-resolution 2-D grid of
; dimensions 13x13 points where x- and y-distance at center point is 0.0 km.
; Otherwise used supplied grid definition parameters.

; add alternate grid spacing label if res_km is supplied and differs from 25km
IF N_ELEMENTS(res_km) EQ 1 THEN res = FLOAT(res_km) ELSE res = 25.
IF res NE 25. THEN add2sav='_'+STRING(res, format='(I0)')+'km'+add2sav

; overide default number of rows/columns in output grid if NXNY is given
; - nxny should always be an odd number so that center gridpoint is at the
;   ground radar location
IF N_ELEMENTS(nxny) EQ 1 THEN GridN = FIX(nxny) ELSE GridN = 13

; find, open the input file listing 2AGPROF HDF files and NEXRAD sites/lats/lons
OPENR, lun0, FILES4META, ERROR=err, /GET_LUN

; assign default output directory if no outdir value supplied
tmpdirname = FILE_DIRNAME(FILES4META)
IF N_ELEMENTS(outdir) EQ 1 THEN BEGIN
   IF FILE_TEST( outdir, /DIRECTORY, /WRITE) THEN BEGIN
      datadirname=outdir
   ENDIF ELSE BEGIN
      message, "Output directory "+outdir+" non-existent or non-writeable, " $
               + "defaulting output to "+tmpdirname, /INFO
      datadirname = tmpdirname
   ENDELSE
ENDIF ELSE datadirname = tmpdirname

; initialize the variables into which file records are read as strings
data4 = ''
event_site_lat_lon = ''

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
      print, "In grid_2agprof_driver, file 2AGPROF not found: "+origFileGPROFName
      goto, errorExit
   ENDELSE

   orbit = long( parsed[1] )
   nsites=fix( parsed[2] )
   print, ""
   print, file_2aGPROF, "  ", orbit, nsites

; parse the file pathname to get the Satellite and Instrument IDs
   parsed2a=strsplit( FILE_BASENAME(file_2aGPROF), '.', /extract )
   Satellite = parsed2a[1]
   Instrument = parsed2a[2]
   dateTimeStartEnd = parsed2a[4]
   dataDate = STRMID(dateTimeStartEnd, 0, 8)
   orbitStr = parsed2a[5]
   PPSvers = parsed2a[6]

;help, Satellite, Instrument, dataDate, orbitStr, PPSvers

; Check status of file_2aGPROF before proceeding - may need to pare down file
; extensions.  THIS WHOLE COPY/UNZIP/DELETE LOGIC SHOULD NOT REALLY APPLY TO
; THE NEW 2AGPROF HDF5 FILES THAT HAVE INTERNAL COMPRESSION, NOT gzip.  BUT IT'S
; SAFER PERHAPS.
   havefile = find_alt_filename( file_2aGPROF, found2aGPROF )
   if ( havefile ) then begin
;     Get an uncompressed copy of the found file
      cpstatus = uncomp_file( found2aGPROF, file_2do )
      if(cpstatus eq 'OK') then begin

;  Process RainType metadata for each site overpassed for this orbit/filename.
;  Put event#s/sites/lats/lons into array variables in groundSite COMMON.

         event_num = lonarr(nsites)
         siteID = strarr(nsites)
         siteLat = fltarr(nsites)   & siteLat[*] = -999.0
         siteLong = fltarr(nsites)  & siteLong[*] = -999.0
         savename = strarr(nsites)

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

           ; format the pathname of the output SAVE file containing the gridded variable(s)
            savename[i] = datadirname+'/RRgrid.'+Satellite+'.'+Instrument+'.' $
                          +siteID[i]+'.'+dataDate+'.'+orbitStr+'.'+PPSvers $
                          +add2sav+'.sav'

         endfor

         print, "savename: ", savename

;        call grid_2agprof_fields to produce the grids

         status = grid_2agprof_fields( file_2do, savename, Instrument, $
                                       res, GridN, siteID, siteLong, siteLat, $
                                       nsites, NEAREST_NEIGHBOR=nearest_neighbor, $
                                       FIND_RAIN=find_rain )

         if ( status NE 'OK' ) then begin
           print, "In grid_2agprof_driver.pro, error in processing ", file_2do
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

;print
;print, "grid_2agprof_driver elapsed time in seconds: ", SYSTIME(1) - Tbegin
print

end
