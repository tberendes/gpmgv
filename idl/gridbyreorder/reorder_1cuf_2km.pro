;+
;-------------------------------------------------------------------------------
; reorder_1cuf.pro    Bob Morris, GPM GV (SAIC)    March 2007
;
; DESCRIPTION
;
; Exectute NCAR's reorder on a supplied list of compressed UF files.
;
; Reads a delimited text file listing the overpass event number, radar ID,
; nominal volume scan time (truncated hour, UTC), latitude and longitude, and
; 1CUF file name for each qualifying event, one event's data per line.  This
; repeats for each event/file to be processed in a run of this program.
; See reorder1CUF.sh script for how the delimited file is created in SQL.
;
; For each file/site, a site/event specific REORDER control file is built,
; the matching 1CUF file is temp-copied and gunzip'ped and REORDER (qreou)
; is called to open and read the file and generate the 300x300 km grid of
; 4 km resolution centered on the radar site lat/lon for the reflectivity
; field of the ground radar.  The resulting netCDF file with the grids
; is renamed to a site/orbit/source-specific netCDF file and moved to a
; permanent directory.
;
; FILES
;
; /data/tmp/reorder/file1CUFtodo.YYMMDD.txt (INPUT) - lists files to process,
;       along with metadata about the event and radar site as noted above.
;       THE FORM OF THE FILE NAME IS CRUCIAL, YYMMDD MUST FALL BETWEEN THE
;       FIRST AND SECOND PERIOD (.) CHARACTERS!
;
; /data/netcdf/NEXRAD_REO/GVgrids.Kxxx.ORBIT.YYMMDD-HHMM.nc (OUTPUT) - netCDF
;    file holding the 3-D gridded reflectivity data for a given
;    overpassed NEXRAD site (Kxxx) and TRMM orbit number (ORBIT).
;    -- Kxxx is the WSR-88D siteID as read from the control file.
;    -- ORBIT is the TRMM orbit number as read from the control file.
;    -- YYMMDD is given by the RUNDATE environment variable's value.
;    -- HHMM is the hour and minute of the site overpass, from the control file.
;
; MANDATORY ENVIRONMENT VARIABLES
;
; REO_1CUF_LIST - fully-qualified file pathname to INPUT file
;                'file1CUFtodoYYMMDD.txt'
;
;-------------------------------------------------------------------------------
;-

pro reorder_1cuf_2km

    in_base_dir = '/data/gv_radar/finalQC_in/'  ;common root dir for UF files
    out_base_dir = '/data/netcdf/NEXRAD_REO/'   ;common root dir for output .nc files
    reo_temp_dir = '/data/tmp/reorder/'         ;runtime working dir
    reo_bin = '/home/morris/swdev/src/reorder/bin/qreou'  ;REORDER executable
    Tbegin = SYSTIME(1)
    cd, reo_temp_dir
    setenv, 'SCRATCH=/data/tmp/reorder'  ;REORDER env variable
; 
;   same control filename is reused/rewritten for each 1CUF file
;
    run_file = reo_temp_dir + 'reorder_temp.inp'
    print,'REORDER run file: ' + run_file

;   find, open the input file listing 1CUF files, NEXRAD sites/lats/lons, etc.
    FILES4NC = GETENV("REO_1CUF_LIST")
    OPENR, lun0, FILES4NC, ERROR=err, /GET_LUN
;   parse the filename to get yymmdd field
    FILES4NCparts = strsplit( file_basename(FILES4NC), '.', /extract )
    yymmdd = FILES4NCparts[1]
    
    out_dir  = out_base_dir + yymmdd
    print,'Out Dir: ' + out_dir
    spawn,'mkdir -p ' + out_dir
    out_base_path = out_dir + "/GVgridsREO."  ; prefix for output netCDF file
;
; *** Set up directories for REORDER
;
    log_dir = reo_temp_dir + 'LOG/'
    print,'LOG Dir: ' + log_dir
    spawn,'mkdir -p ' + log_dir

    print,'Creating junk file...'
    spawn,'touch junk'

;   initialize the variables into which file records are read as strings
    data8 = ''
    event_site_lat_lon = ''

    While not (EOF(lun0)) Do Begin 

;      read the '|'-delimited input file record into a single string
       READF, lun0, data8

;      parse data7 into its component fields: event_num, orbit number, siteID,
;      nominal datetime, site lat, site lon, 1CUF file unique pathname

       parsed=strsplit( data8, '|', /extract )
       event_num = long( parsed[0] )
       orbit = parsed[1]
       NXsiteID = parsed[2]    ; NOAA agency siteID
       pg_nominal = parsed[3]
       siteLat = parsed[4]
       siteLon = parsed[5]
       siteElev = parsed[6]
       origUFName = parsed[7] ; filename as listed in/on the database/disk
;      add the well-known path to get the fully-qualified file name
       file_1CUF = in_base_dir + origUFName
       base_1CUF = file_basename(file_1CUF)
       if ( base_1CUF eq 'no_1CUF_file' ) then begin
          print, "No 1CUF file for event = ", event_num, ", skipping."
          goto,next_file
       endif
;      get the individual file's date string from the file name, along with the TRMM
;      representation of the NEXRAD site ID
       parsed2 = strsplit( base_1CUF, '.', /extract )
       my_yymmdd = parsed2[0]
       siteID = parsed2[2]      ; TRMM GVS site ID
;      convert the Postgres datetime string into REORDER's format
       p3 = strsplit( pg_nominal, ' ', /extract )
       nominal = p3[1] + '-' + p3[2] + '-' + strmid( p3[4],2,3) + ',' + p3[3]
       print, ""
       print, "Gridding ", file_1CUF
       print, event_num,"  ",orbit,"  ",nominal,"  ",siteID,"  ",siteLat, "  ", siteLon

;
; *** Grid the files
;
       log_file = log_dir + siteID + "." + my_yymmdd + "." + orbit + ".log"
       cdf_file = out_base_path + NXsiteID + "." + my_yymmdd + "." + orbit + ".nc.gz"
       print, log_file
       print, cdf_file
;       get an unzipped copy of the UF file in current working directory
       flag = uncomp_file(file_1CUF,file)
       if(flag ne 'OK') then begin
           print,flag
           stop
           goto,next_file
       endif
       print,'<-- ' + file
;
; *** Now we have the UF file. We need to rename it to test.uf for 
; *** REORDER to work correctly.
;
       spawn,'mv ' + file + ' test.uf'
;
; *** Generate the control file
;
       mk_qreo2km, siteID, siteLon, siteLat, siteElev, nominal
;
; *** Issue the command to run REORDER
;
       command = reo_bin + " < " + run_file + "  > " + log_file
       print,"REORDER: " + command
       spawn,command
;
; *** REORDER will create a file of the form ddop.050901.000439.cdf
; *** We want to compress it and then mv it to our CDF directory
;
       spawn,'gzip ' + 'ddop.*.cdf'
       command = 'mv ddop.*.cdf.gz ' + cdf_file
       print,command
       spawn,command
       spawn,'rm test.uf'

next_file:
    EndWhile
    print,'Finished!'
    print
    print, "Elapsed time in seconds: ", SYSTIME(1) - Tbegin
    print

    end

@uncomp_file.pro
@mk_qreo2km.pro
