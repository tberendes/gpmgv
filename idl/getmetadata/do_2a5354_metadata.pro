;+
; Copyright © 2011, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;
;-------------------------------------------------------------------------------
;
; do_2a5354_metadata.pro    Bob Morris, GPM GV (SAIC)    April 2011
;
;
; DESCRIPTION
; -----------
; Reads an interleaved, delimited text file listing PR 1C21 and 2A25 files,
; their orbit number and subset, and the number N of GV sites overpassed by
; the PR for the orbit on one line; followed by the event_ID, site ID, overpass
; time (ticks), latitude and longitude, and the 2A53 and 2A54 file pathnames
; of each overpassed site on 1:N separate lines, one site's data per line. 
; These sequences repeat for each PR orbit/subset whose matching GV data are to
; be processed in a run of this program (typically all those in a given day).
;
; - See do2A5xMetadata.sh script for how the delimited file is created in SQL.
;
; For each site overpass event, the GV files are gunzip'ped and procedures
; are called to open and read the files and extract the necessary metadata
; fileds from the 300x300 km grids of 2 km resolution centered on the radar
; site  The resulting GV metadata are tagged with the necessary database
; attributes and written separately to a delimited text file whose name is
; passed as a parameter from the IDL .bat invoking this procedure, which in turn
; extracted it from an environment variable set in the do2A5xMetadata.sh script.
;
;
; FILES
; -----
; PR_files_sites4gvMeta.${yymmdd}.txt (INPUT) - lists PR subset files,
;    their orbit, and information on the (one or more) overpassed NEXRAD
;    sites and their corresponding 2A5x radar site files, where YYMMDD is
;    the year, month, day of the parent script's run.  Full file pathname is
;    externally specified by the GVMETACONTROL environment variable's value, and
;    is can be whatever is desired as long as the file format is correct.
;
;    This control file has the following structure.  The block labels in
;    parentheses are not part of the file:
;
;       1C21_filename|2A25_filename|ORBIT_NUMBER|SUBSET|NSITES       (first block)
;       event_num_1|siteID_1|time1|siteLat_1|siteLon_1|2A53_filepath1|2A54_filepath1
;       event_num_2|siteID_2|time2|siteLat_2|siteLon_2|2A53_filepath2|2A54_filepath2
;         . 
;         .   repeats M = NSITES times [1..M]
;         . 
;       event_num_M|siteID_M|timeM|siteLat_M|siteLon_M|2A53_filepathM|2A54_filepathM
;       1C21_filename|2A25_filename|ORBIT_NUMBER|SUBSET|NSITES       (second block)
;       event_num_1|siteID_1|time1|siteLat_1|siteLon_1|2A53_filepath1|2A54_filepath1
;       event_num_2|siteID_2|time2|siteLat_2|siteLon_2|2A53_filepath2|2A54_filepath2
;         . 
;         .   repeats N = NSITES times [1..N]
;         . 
;       event_num_N|siteID_N|timeN|siteLat_N|siteLon_N|2A53_filepathN|2A54_filepathN
;
;   Thus, a "pattern block" is defined in the control file for each orbit/subset whose
;   data are to be processed: one row listing the two orbit subset PR filenames,
;   the orbit number, the number of sites to process for the orbit, and the PR subset
;   to which the PR files apply; followed by one-to-many rows listing the GV site
;   information for each site overpass "event" whose GV metadata will be produced.
;   Pattern block repeats for each ORBIT/SUBSET combination to be processed.
;   For a given orbit and subset combination there are NSITES sites overpassed, and
;   output GV metadata will be produced from the GV data files for each of these sites.
;
;   The 2A53_filepath is a partial pathname to the specific 2A53 HDF files.  The
;   'in-common' part of the path is prepended to the partial pathname to get the
;   complete file path.  The in-common path is specified in the include file
;   'environs.inc' as the variable GVDATA_ROOT.  A special value is defined for
;   the cases where no 2A5x data are available for the overpass event, but it is
;   still desired to produce gridded PR data for the site overpass.  In this
;   case, the file pathname value should be specified in the control file as
;   'no_2A53_file', without the quotes.  The same applies to the 2A54_filepath
;   except missing files are indicated by 'no_2A54_file' (sans quotes).
;
;   The event_num value is a unique number for each site overpass event within
;   the full GPM Validation Network prototype system, and is the database key
;   value which serves to identify both an overpassed ground site ID and the
;   orbit in which it is overpassed.  It is not used as part of the Primary
;   Key identifying the data values in the database, and thus is constrained to
;   being unique for a given site/orbit combination.
;
; 1C21.YYMMDD.ORBIT#.6.sub-GPMGV1.hdf.gz (UNUSED) - 1C21 data file, where YYMMDD
;    is the year/month/day and ORBIT# is the TRMM orbit number, as listed in the
;    PR_files_sites4gvMeta.YYMMDD.txt file.
;
; 2A25.YYMMDD.ORBIT#.6.sub-GPMGV1.hdf.gz (UNUSED) - As above, but for the PR 2A25
;    data file.
;
; GVDATA_ROOT/SITE/level_2/YYYY/gvs_2A-53-dc_SITE_MM-YYYY/2A53.YYMMDD.h(h).site.HDF.gz
;    (INPUT) - TRMM-GV-produced HDF data files to be processed, where SITE is
;    the NWS ID of the NEXRAD radar (e.g. KMLB), YYYY is the year of the data,
;    MM is the month of the data, YYMMDD.h(h) are the year-month-day and
;    nominal hour (1-24, one or two digits, rounded up) of the radar volume,
;    and "site" is the TRMM GV ID of the NEXRAD site, as listed (a partial
;    file pathname beginning with SITE) in the PR_files_sites4gvMeta.YYMMDD.txt
;    file.
;
; GVDATA_ROOT/SITE/level_2/YYYY/gvs_2A-54-dc_SITE_MM-YYYY/2A54.YYMMDD.h(h).site.HDF.gz
;    (INPUT) - As for the preceding file, but for the TRMM GV 2A-54 product.
;
; gvMetadata.YYMMDD.unl (OUTPUT) - ASCII delimited-text file containing the
;    metadata values extracted from the 2A54 and 2A53 elements for all the
;    overpassed NEXRAD sites and TRMM orbits processed in the run, where YYMMDD
;    is the year, month, day of the parent script's run.  Full file pathname is
;    externally specified by the DBOUTFILE environment variable's value, and
;    is can be whatever is desired as long as the file format is correct.
;
; The actual values of the file/path variables used above and within the body
; of this procedure, as listed below, must be defined in the "include" file
; 'environs.inc':
;
;   TMP_DIR  PRDATA_ROOT  GVDATA_ROOT
;
;
; ARGUMENTS
; -------------------------------
; 1) DBOUTFILE  - year, month, and day of parent script's run in YYMMDD format
; 2) EVENTFILE   - fully-qualified file pathname to INPUT CONTROL file
;
;
; CONSTRAINTS
; -----------
; 1) Program is expected to process one (UTC) day's data.  All orbits/overpass
;    events in the control file are expected to be for the date specified in
;    the DATESTAMP in the input filenames.
; 2) Working directory must be writeable, as the 2A5x files are
;    copied into this directory to be unzipped, and then the copy deleted. 
;
; HISTORY
; -------
; 04/18/2011 Morris        Created.
;
;-------------------------------------------------------------------------------
;-

pro do_2A5354_Metadata, EVENTFILE, DBOUTFILE

;common groundSite,   event_num, siteID, siteLong, siteLat, nsites

; "Include" files for constants, names, paths, etc.
@environs.inc
@grid_def.inc
@pr_params.inc

Tbegin = SYSTIME(1)

DBZ_MIN = 15

; find, open the input file listing the HDF files and NEXRAD sites/lats/lons

if ( DBOUTFILE eq '' ) then begin
   message, 'DBOUTFILE not set'
endif

if ( EVENTFILE eq '' ) then begin
   message, 'Control file pathname not set'
endif

inctlfile = file_search(EVENTFILE, COUNT=nf)
if ( nf NE 1 ) then begin
   message, 'Control file not found/not unique: ' + EVENTFILE
endif

; get the data's datestamp value from the control file name
ctlfilebase = FILE_BASENAME(EVENTFILE)
parsed = STRSPLIT(ctlfilebase, '.', /extract )
DATESTAMP = STRJOIN( parsed[1] )

; initialize the variables into which file records are read as strings
data4 = ''
event_site_lat_lon = ''


OPENR, lun0, EVENTFILE, ERROR=err, /GET_LUN
;
; Open the database file for writing
;
GET_LUN, UNLUNIT
OPENW, UNLUNIT, DBOUTFILE

While not (EOF(lun0)) Do Begin 

;  read the '|'-delimited input file record into a single string
   READF, lun0, data4

;  parse data4 into its component fields: 1C21 file name, 2A25 file name,
;  2B31 file name, orbit number, number of sites

   parsed=strsplit( data4, '|', /extract )
   origFile21Name = parsed[0] ; filename as listed in/on the database/disk
   origFile25Name = parsed[1] ; filename as listed in/on the database/disk
   orbit = long( parsed[2] )
   subset = parsed[3]
   nsites = fix( parsed[4] )

;
;  add the well-known paths to get the fully-qualified file names
   file_1c21 = PRDATA_ROOT+DIR_1C21+"/"+origFile21Name
   file_2a25 = PRDATA_ROOT+DIR_2A25+"/"+origFile25Name
;
   print, ""
   print, '================================================================'
   print, ""
   print, 'ORBIT: ', orbit, '    Qualifying overpass sites: ', nsites
;   print, 'PR files:  ', file_1c21
;   print, '           ', file_2a25
   print, ""
;

; -----------------------------------------------------------------------

;
   print, ""
   print, 'Process GV Metadata for each site overpassed for this orbit/filename'
   print, ""
;
   event_num = 0L
   siteID = ""
   event_time = 0.0D+0
   siteLat = -999.0
   siteLong = -999.0
   file_2a53 = ""
   file_2a54 = ""

   for i=0, nsites-1 do begin
;     read each overpassed site's information as a '|'-delimited string
      READF, lun0, event_site_lat_lon
;      print, i+1, ": ", event_site_lat_lon
;     parse the delimited string into event_num, siteID, latitude, and
;     longitude fields
      parsed=strsplit( event_site_lat_lon, '|', /extract )
      event_num = long( parsed[0] )
      siteID = parsed[1]
      event_time = double( parsed[2] )
      siteLat = float( parsed[3] )
      siteLong = float( parsed[4] )
      file_2a53 = parsed[5]
      file_2a54 = parsed[6]
      print, '----------------------------------------------------------------'
      print, i+1, ": ", event_num, "  ", siteID, siteLat, siteLong
      print, i+1, ": ", file_2a53
      print, i+1, ": ", file_2a54

     ; (re)initialize metadata values to -999 (MISSING) for writing to db file
      countrain = -999              ;2A53 2km grid: Num Rain Certain
      nstrat = -999                 ;2A54 2km grid: Num Rain Type Stratiform
      nconv = -999                  ;2A54 2km grid: Num Rain Type Convective
     ; IDENTIFIERS metaID_53 and metaID_54 ARE DEFINED IN THE GPMGV DATABASE AS KEYS --
     ; - CAN'T CHANGE OR REDEFINE THEM HERE WITHOUT MATCHING DATABASE MODS.
      metaID_53 = 531005            ;'2A53 2km grid: Num Rain Certain'
      metaID_54 = [540001, 540002]  ;'2A54 2km grid: Num Rain Type [Stratiform,Convective]'
;
;     Check whether we have either a matching 2A-54 and 2A-53 data files for site
;     overpass.  If not then skip metadata creation for NEXRAD for the event.
;
      if file_2A54 eq 'no_2A54_file' OR file_2A53 eq 'no_2A53_file' then begin
         print, 'Skip reading, no 2A-53/54 data files for event_num = ', event_num
         print, ""
      endif else begin
;
;       Generate the GV metadata for this event
;
         gvfiles = strarr(2)
         gvfiles[0] = file_2a53
         gvfiles[1] = file_2a54
         FOR gvfilenum = 0, 1 do begin
          ; Prepare the 2A5x file for reading. Add the well-known path to get
          ; the fully-qualified file name.  Must copy the 2A-5x gzip'd file
          ; to working directory, don't have permissions to unzip them in-place.
;
            fileOrig_2a5x = GVDATA_ROOT + "/" + gvfiles[gvfilenum]
;           print, "Full 2A-5x file name: ", fileOrig_2a5x
            havefile = find_alt_filename( fileOrig_2a5x, found2a5x )
            if ( havefile ) then begin
;              Get an uncompressed copy of the found file
               cpstatus = uncomp_file( found2a5x, file_2do )
               if (cpstatus eq 'OK') then begin
;
;                  Read the rain rate/type fields from the files.
;
                  case gvfilenum of
                     0 : begin
                          ; just define with any value and dimension
                           rainRate=intarr(151,151) 
                          ; Read 2a53 raintype and volume scan times
                           print, "Reading 2A53 file ", file_2do
                           read_2a53, file_2do, RAIN=rainRate, hour, minute, second
                         end
                     1 : begin
                          ; just define with any value and dimension 
                           convStratFlag=intarr(151,151)
                          ; Read 2a54 raintype and volume scan times
                           print, "Reading 2A54 file ", file_2do
                           read_2a54, file_2do, STORMTYPE=convStratFlag, hour, minute, second
                           ;help, convStratFlag
                         end
                     else : print, 'Trouble with a capital T !!'
                  endcase

                ; Remove the temporary 2A-5x file copy
                  command = "rm -v " + file_2do
                  spawn,command

               endif else begin
                  print, cpstatus
                  goto, errorExit
               endelse
            endif else begin
               print, "Cannot find regular/compressed file " + fileOrig_2a5x
               goto, errorExit
            endelse
         ENDFOR

        ; extract metadata information from 2a53 file
         idxrain = WHERE( rainRate GT 0, countrain )

        ; extract metadata information from 2a54 file
        ; only look at points where rain rate is non-zero, else can have more
        ; rain type points than rainy
         nstrat = 0
         nconv = 0
         IF countrain GT 0 THEN BEGIN
            idxStratFlag = WHERE( convStratFlag[idxrain] EQ 1, nstrat )
            idxConvFlag = WHERE( convStratFlag[idxrain] EQ 2, nconv )
         ENDIF

      endelse  ; file_2A54 eq 'no_2A54_file' OR file_2A53 eq 'no_2A53_file'

     ; write good/missing metadata information to db file
      printf, UNLUNIT, format = '(2(i0,"|"),i0)', event_num, metaID_53, countrain
      printf, UNLUNIT, format = '(2(i0,"|"),i0)', event_num, metaID_54[0], nstrat
      printf, UNLUNIT, format = '(2(i0,"|"),i0)', event_num, metaID_54[1], nconv

   endfor  ; i=0, nsites-1

EndWhile   ; not (EOF(lun0)) (EVENTFILE loop)

errorExit:
FREE_LUN, UNLUNIT

print
print, "Elapsed time in seconds: ", SYSTIME(1) - Tbegin
print

END
