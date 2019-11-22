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
; GR_files_sites4grMeta.${yymmdd}.txt (INPUT) - lists information on the (one
;    or more) overpassed NEXRAD sites and their corresponding 1CUF files, where
;    YYMMDD is the year, month, day of the parent script's run.  Full file
;    pathname is externally specified by the GVMETACONTROL environment variable
;    value, and is can be any pathname as long as the file format is correct.
;
;    This control file has the following structure.  The block labels in
;    parentheses are not part of the file:
;
;       event_num_1|siteID_1|1CUF_filepath1
;       event_num_2|siteID_2|1CUF_filepath2
;         . 
;         .   repeats NSITES times
;         . 
;
;   For a given day's control file there are NSITES site overpass events, and
;   output GR metadata will be produced from the UF data files for each event.
;
;   The 1CUF_filepath is a partial pathname to the specific 1CUF files.  The
;   'in-common' part of the path is prepended to the partial pathname to get the
;   complete file path.  The in-common path is specified in the include file
;   'environs.inc' as the variable GVDATA_ROOT.
;
;   The event_num value is a unique number for each site overpass event within
;   the full GPM Validation Network prototype system, and is the database key
;   value which serves to identify both an overpassed ground site ID and the
;   orbit in which it is overpassed.  It is not used as part of the Primary
;   Key identifying the data values in the database, and thus is constrained to
;   being unique for a given site/orbit combination.
;
; GVDATA_ROOT/SITE/1CUF/YYYY/MMDD/SITE_YYYY_MMDD.hhmmss.uf.gz
;    (INPUT) - Quality-controlled UF data files to be processed, where SITE is
;    the NWS ID of the NEXRAD radar (e.g. KMLB), YYYY is the year of the data,
;    MMMM is the month and day of the data, hhmmss is the start time of the
;    radar volume, and "site" is the ID of the NEXRAD site, as listed (a partial
;    file pathname beginning with SITE) in the GR_files_sites4grMeta.YYMMDD.txt
;    file.
;
; grMetadata.YYMMDD.unl (OUTPUT) - ASCII delimited-text file containing the
;    metadata values extracted from the gridded 1CUF reflectivity PPIs for all
;    the QC-ed NEXRAD files processed in the run, where YYMMDD
;    is the year, month, day of the parent script's run.  Full file pathname is
;    externally specified by the DBOUTFILE environment variable's value, and
;    is can be whatever is desired as long as the file format is correct.
;
; The actual values of the file/path variables used above and within the body
; of this procedure, as listed below, must be defined in the "include" file
; 'environs.inc':
;
;   TMP_DIR  GVDATA_ROOT
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
; 04/11/2014 Morris        Created from do_2A5354_Metadata.pro
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

; find, open the input file listing the UF files, site IDs, and event_nums

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

   event_num = 0L
   siteID = ""
   file_1CUF = ""

;     read each overpassed site's information as a '|'-delimited string
      READF, lun0, event_site_lat_lon
;      print, i+1, ": ", event_site_lat_lon
;     parse the delimited string into event_num, siteID, latitude, and
;     longitude fields
      parsed=strsplit( event_site_lat_lon, '|', /extract )
      event_num = long( parsed[0] )
      siteID = parsed[1]
      file_1CUF = parsed[2]
      print, '----------------------------------------------------------------'
      print, i+1, ": ", event_num, "  ", siteID, file_1CUF

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

EndWhile   ; not (EOF(lun0)) (EVENTFILE loop)

errorExit:
FREE_LUN, UNLUNIT

print
print, "Elapsed time in seconds: ", SYSTIME(1) - Tbegin
print

END
