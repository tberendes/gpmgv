;===============================================================================
;+
; Copyright © 2014, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; dpr2gmi_driver.pro          Morris/SAIC/GPM_GV      January 2014
;
; DESCRIPTION
; -----------
; Driver routine for function dpr2gmi().  Queries the 'gpmgv' database to get
; a list of 2AGPROF file names for rainy cases, and calls dpr2gmi to generate
; GMI/DPR/[DPRGMI] rain rate matchups.  Has options to request that the data be
; written to a netCDF file, and optionally displayed on the screen as either a
; static display of the GMI rain rate, or as an animation of the GMI with its
; resolution-matched DPR and Combined 2B-DPRGMI rain rates, either on a map
; background or in a simple ray vs. scan image.  The user can specify the
; maximum radius from the nearest-neighbor GMI footprint center over which DPR
; samples are averaged to produce a resolution-matched volume to the GMI data.
;
; PARAMETERS
; ----------
; display   - binary parameter, select whether or not to display the matchup
;             data as images.  Default=0 (do not display)
; animate   - if DISPLAY parameter is set to ON (1), then ANIMATE specifies the
;             type of data display to be shown.  Options are 0 (static image of
;             GMI rainrate on a map), 1 (animation of alternating images of GMI,
;             DPR, and Combined DPR/GMI rain rate on a map), or 2 (as in [1], but
;             as a simple image in ray vs. scan coordinates, with no geography).
;             Default=0 (static GMI image)
; write2nc  - Binary parameter, determines whether the matchup data are to be
;             written to a netCDF file or just computed and held in memory for
;             optional display.  Default = 0 (no netCDF file output).
; radius    - Determines maximum center-to-center distance between a GMI surface
;             footprint and the surface footprint locations of the DPR samples
;             whose data values are to be averaged to produce a resolution
;             match to the GMI sample.
; path_out  - Override to the default path for the output netCDF files.  If
;             not specified, then the path will default to the directory
;             given by the combination of NCGRIDS_ROOT+PR_TMI_MATCH_NCDIR as
;             defined in the "include" file, environs.inc.
; files2agmi - Optional list of 2A-GPROF files to process, overrides database
;              query method normally used to build the list of files.
; print_times - Binary option.  If set, then the elapsed time required to
;               complete major components of the matchup will be printed to
;               the terminal.
; batch      - Binary option.  If set, then do NOT launch a GUI to select the
;              matching DPR or DPRGMI file when a match cannot be found, just
;              skip case (DPR not found) or Combined data matching (DPRGMI not
;              found).
;
;
; HISTORY
; -------
; 09/19/14 by Bob Morris, GPM GV (SAIC)
;  - Created from pr2tmi_nn_driver.pro
;
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;===============================================================================

; MODULE 3:  FUNCTION get_latest_version

; DESCRIPTION
; -----------

FUNCTION get_latest_version, product_path
   versions = FILE_SEARCH(product_path + '/V*')
   IF versions[0] EQ '' THEN BEGIN
      message, 'No valid version path specifications found under ' + $
               product_path, /INFO
      latest = ''
   ENDIF ELSE BEGIN
      IF N_ELEMENTS(versions) EQ 1 THEN latest = FILE_BASENAME(versions) $
      ELSE BEGIN
         versort = versions[REVERSE(SORT(versions))]
         latest = FILE_BASENAME(versort[0])
      ENDELSE
   ENDELSE

   IF STREGEX(latest, 'V[0-9]{2}[A-Z]?', /BOOLEAN) NE 1 THEN BEGIN
      message, "Not a valid PPS version specification '"+latest+"' under" + $
               product_path, /INFO
      latest = ''
   ENDIF

   return, latest
end

;===============================================================================

; MODULE 2:  FUNCTION find_dpr_for_gmi

; DESCRIPTION
; -----------
; Given the directory path and file basename of a GMI 2A-GPROF file, searches
; for the corresponding (by site, date, orbit, PPS version) DPR file of the
; requested type (e.g., 2AKu) under a DPR-product-specific directory under the
; "common" GPM product directory, defined by convention as the next higher
; directory above GMI/2AGPROF.  If a matching DPR file of the requested type
; is not found, then the bogus file name "no_DPR_file" will be returned.
;
;
; PARAMETERS
; ----------
; gmi_filepath    - Fully-qualified pathname to the GMI file whose matching
;                   DPR file of type DPRtype is to be found.
;
; DPRtype         - Type of matching DPR file to be found: 2ADPR, 2AKa, 2AKu,
;                   or 2BDPRGMI.  The level specification (2A or 2B) part of
;                   the DPR type is optional, and DPRtype is case-insensitive.
;
; DPRpattern      - Search pattern for DPR file basename matching the GMI file.
;
; DPRversion_in   - PPS version of the DPR file to be matched up to the GMI.
;
;
; RETURNS
; -------
; file_dpr        - File name of the matching DPR file of type DPRtype, where
;                   DPRtype is one of the types 2ADPR, 2AKa, 2AKu, or 2BDPRGMI.
;                   Only one of the XXXX file types may be requested at a time.
;
;
; CONSTRAINTS
; -----------
; The DPR and GMI files must be stored in a file directory structure identical
; to the GPM Validation Network ftp data server from the satellite-specific
; subdirectory to the file basenames, as follows:
;
; satellite/             (GPM)
;   instrument/          (DPR, DPRGMI, Ka, Ku, GMI)
;     algorithm/         (2ADPR, 2AKa, 2AKu, 2BDPRGMI, 2AGPROF)
;       version/         (V03A, V03B, V04 etc.)
;         subset/        (AKradars, CONUS, KWAJ, KOREA, etc.)
;           year/        (2014, 2015,…)
;             month/     (01, 02, …, 12)
;               day/     (01, 02, …, 28, 29, 30, 31)
;                 (data files)
;
; Directory names are case-specific, as shown above.
;
;
; HISTORY
; -------
; 09/19/14  Morris/GPM GV/SAIC
; - Created.
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;===============================================================================

FUNCTION find_dpr_for_gmi, gmi_filepath, DPRtype, DPRpattern, DPRversion_in, $
                           BATCH=batch_in

batch = KEYWORD_SET(batch_in)  ; if set, skip manual file selection backup

CASE STRUPCASE(DPRtype) OF
        'DPR' : typedirs = 'GPM/DPR/2ADPR'
      '2ADPR' : typedirs = 'GPM/DPR/2ADPR'
         'KA' : typedirs = 'GPM/Ka/2AKa'
       '2AKA' : typedirs = 'GPM/Ka/2AKa'
         'KU' : typedirs = 'GPM/Ku/2AKu'
       '2AKU' : typedirs = 'GPM/Ku/2AKu'
     'DPRGMI' : typedirs = 'GPM/DPRGMI/2BDPRGMI'
   '2BDPRGMI' : typedirs = 'GPM/DPRGMI/2BDPRGMI'
         ELSE : message, "Illegal DPR type specification: "+DPRtype
ENDCASE

file_dpr = 'no_DPR_file'
gmi_pathonly = FILE_DIRNAME(gmi_filepath)
pathname_len = STRLEN(gmi_pathonly)
pathTypePos = STRPOS(gmi_pathonly, 'GPM/GMI/2AGPROF')

IF pathTypePos NE -1 THEN BEGIN
   file_dpr_pre = STRMID(gmi_pathonly, 0, pathTypePos)+typedirs
   IF DPRversion_in EQ 'GetLatest' THEN BEGIN
      DPRversion = get_latest_version(file_dpr_pre)
      IF DPRversion EQ '' THEN $
         message, "Can't find valid version under "+file_dpr_pre, /INFO $
      ELSE BEGIN
         message, "Found latest version "+DPRversion+" under "+file_dpr_pre, $
                  /INFO
         DPRversion_in = DPRversion  ; return found version in passed parameter
      ENDELSE
   ENDIF ELSE DPRversion = DPRversion_in

   IF DPRversion NE '' THEN BEGIN
      file_dpr_2match = file_dpr_pre+'/'+DPRversion+ $
          STRMID(gmi_pathonly, pathTypePos+20, pathname_len-(pathTypePos+20))+ $
          '/' + DPRpattern
      print, "file_dpr_2match: ", file_dpr_2match 
      IF FIND_ALT_FILENAME(file_dpr_2match, foundfile) NE 0 THEN $
         file_dpr = foundfile
   ENDIF
ENDIF ELSE print, "Can't find sequence 'GPM/GMI/2AGPROF' in GMI file pathname."

IF file_dpr EQ 'no_DPR_file' THEN BEGIN
   IF batch EQ 0 THEN BEGIN
      print, ''
      print, "Select a "+DPRtype+" file to match:"
      print, gmi_filepath
      print, ''
      dialogTitle="Select the "+DPRtype+" file to process:"
;      print, dialogTitle
;      print, ''
      parsed = STRSPLIT(FILE_BASENAME(gmi_filepath), '.', /EXTRACT)
      orbitstr = parsed[5]
      filterstr = '*.'+orbitstr+'.*'
      event_data = dialog_pickfile(path=file_dpr_pre, filter = filterstr, $
                                   TITLE=dialogTitle)
      IF event_data[0] NE '' THEN BEGIN
         file_dpr = event_data
         parsed = STRSPLIT(FILE_BASENAME(file_dpr), '.', /EXTRACT)
         dprorbitstr = parsed[5]
         IF dprorbitstr NE orbitstr THEN BEGIN
            message, "GMI Orbit "+orbitstr+' and '+DPRtype+' orbit '+dprorbitstr $
                     +' do not match!  Rejecting selection.', /INFO
            file_dpr = 'no_DPR_file'
         ENDIF
      ENDIF ELSE BEGIN
         print, 'No matching ', DPRtype, ' file selected.'
         file_dpr = 'no_DPR_file'
      ENDELSE
   ENDIF ELSE BEGIN
      print, 'No matching ', DPRtype, ' file selected, skipping in BATCH mode.'
      file_dpr = 'no_DPR_file'
   ENDELSE
ENDIF

return, file_dpr
end

;===============================================================================

pro dpr2gmi_driver, DISPLAY=display, WRITE2NC=write2nc, RADIUS=radius, $
                    PATH_OUT=path_out, ANIMATE=animate, FILES2AGMI=files2agmi, $
                    DPR_TYPE=DPR_type_in, DPR_SCANTYPE=DPR_scantype_in, $
                    DPR_VERSION=DPR_version_in, $
                    DPRGMI_VERSION=DPRGMI_version_in, BATCH=batch, $
                    PRINT_TIMES=print_times, SKIP_EXISTING=skip_existing

; "Include" file for names, paths, etc.:
@environs.inc

display = KEYWORD_SET(display)
write2nc = KEYWORD_SET(write2nc)

IF N_ELEMENTS(DPR_type_in) EQ 1 THEN BEGIN
   DPR_type = DPR_type_in
ENDIF ELSE BEGIN
   print, ''
   print, 'Defaulting to 2AKu for DPR product type.'
   DPR_type = 'Ku'
ENDELSE

IF N_ELEMENTS(DPR_scantype_in) EQ 1 THEN BEGIN
   CASE DPR_type OF
      'DPR' : BEGIN
              IF DPR_scantype_in NE 'HS' AND DPR_scantype_in NE 'MS' $
              AND DPR_scantype_in NE 'NS' THEN BEGIN
                 message, "Illegal DPR_SCANTYPE for 2A"+DPR_type+ $
                          ", must be HS, MS, or NS", /info
                 print, "Setting DPR_SCANTYPE to default of NS"
                 DPR_scantype = 'NS'
              ENDIF ELSE DPR_scantype = DPR_scantype_in
              END
       'Ka' : BEGIN
              IF DPR_scantype_in NE 'HS' AND DPR_scantype_in NE 'MS' THEN BEGIN
                 message, "Illegal DPR_SCANTYPE for 2A"+DPR_type+ $
                          ", must be HS or MS", /info
                 print, "Setting DPR_SCANTYPE to default of MS"
                 DPR_scantype = 'MS'
              ENDIF ELSE DPR_scantype = DPR_scantype_in
              END
       'Ku' : BEGIN
              IF DPR_scantype_in NE 'NS' THEN BEGIN
                 message, "Illegal DPR_SCANTYPE for 2A"+DPR_type+ $
                          ", must be NS", /info
                 print, "Setting DPR_SCANTYPE to default of NS"
                 DPR_scantype = 'NS'
              ENDIF ELSE DPR_scantype = DPR_scantype_in
              END
       ELSE : message, "Illegal DPR_TYPE, only DPR, Ka, or Ku are accepted."
   ENDCASE
ENDIF ELSE BEGIN
    CASE DPR_type OF
      'DPR' : BEGIN
                 print, "No scan type specified, setting swath to default of NS"
                 DPR_scantype = 'NS'
              END
       'Ka' : BEGIN
                 print, "No scan type specified, setting swath to default of MS"
                 DPR_scantype = 'MS'
              END
       'Ku' : BEGIN
                 print, "No scan type specified, setting swath to default of NS"
                 DPR_scantype = 'NS'
              END
       ELSE : message, "Illegal DPR_TYPE, only DPR, Ka, or Ku are accepted."
   ENDCASE
ENDELSE

DPRGMItype = '2BDPRGMI'  ; hard-code only option

IF N_ELEMENTS(DPR_version_in) EQ 1 THEN BEGIN
   DPR_version = DPR_version_in
ENDIF ELSE BEGIN
   print, ''
   print, 'Defaulting to latest available for DPR product version.'
   DPR_version = 'GetLatest'
ENDELSE

IF N_ELEMENTS(DPRGMI_version_in) EQ 1 THEN BEGIN
   DPRGMI_version = DPRGMI_version_in
ENDIF ELSE BEGIN
   print, ''
   print, 'Defaulting to latest available for DPRGMI product version.'
   DPRGMI_version = 'GetLatest'
ENDELSE

IF N_ELEMENTS( animate ) NE 1 THEN BEGIN
   loopit = 0
ENDIF ELSE BEGIN
   CASE animate OF
      0 : loopit = 0
      1 : loopit = 1
      2 : loopit = 2
      ELSE : BEGIN
               print, "Invalid value for ANIMATE parameter, 0, 1, and 2 allowed."
               print, '0=no animation; 1=animate map; 2=animate ray/scan'
               print, "Setting to default, no animation."
             END
   ENDCASE
ENDELSE

print_times=KEYWORD_SET(print_times)

CASE GETENV('HOSTNAME') OF
   'ds1-gpmgv.gsfc.nasa.gov' : BEGIN
          datadirroot = '/data/gpmgv/orbit_subset/' ;GPM/GMI/2AGPROF/V03C/CONUS/2014'
          IF N_ELEMENTS(path_out) NE 1 THEN path_out=datadirroot+'/tmp'
          END
   'ws1-gpmgv.gsfc.nasa.gov' : BEGIN
          datadirroot = '/data/gpmgv/orbit_subset/'
          IF N_ELEMENTS(path_out) NE 1 THEN path_out=datadirroot+'/tmp'
          END
   ELSE : BEGIN
          print, "Unknown system ID, setting path_out to user's home directory"
          datadirroot = '~/data'
          IF N_ELEMENTS(path_out) NE 1 THEN path_out='~'
          END
ENDCASE
IF write2nc THEN PRINT, "Assigning default output file path: ", path_out

; set the default radius if one is not provided or is out-of-range
IF N_ELEMENTS(radius) EQ 0 THEN BEGIN
   print, "Setting maximum radius from GMI footprint to 14 km" & print, ""
   radius = 14.0
ENDIF ELSE BEGIN
   IF (radius LT 5.0) OR (radius GT 50.0) THEN BEGIN
      print, "Radius must be between 5.0 and 50.0 km, supplied value = ", radius
      print, "Setting maximum radius from GMI footprint to 14 km" & print, ""
      radius = 14.0
   ENDIF
ENDELSE

; WE DON'T CURRENTLY DO A DB QUERY TO GET OUR 2AGPROFGMI FILE LISTING --
; If files2agmi is single string, assume it's a file with a list of pathnames of 2AGPROF files, or
; if it's a 2-word string, assume it's an 'ls' command with a 2AGPROF file pattern, or
; if it is not provided, bring up a file selector

IF N_ELEMENTS( files2agmi ) NE 0 THEN BEGIN
   CASE N_ELEMENTS(STRSPLIT(files2agmi, ' ', /extract)) OF
         1 : SQLSTR='cat '+files2agmi ;;
         2 : SQLSTR=files2agmi ;;
      ELSE : message, 'Unable to process FILES2AGMI parameter: '+files2agmi ;;
   ENDCASE
   SPAWN, sqlstr, event_data, COUNT=num_events
ENDIF ELSE BEGIN
   Print, ""
   dialogTitle="Select the 2A-GPROF file(s) to process:"
   print, dialogTitle
   print, ''
   event_data = dialog_pickfile(path=datadirroot, filter = '*.GPROF*', $
                            TITLE=dialogTitle, /MULTIPLE_FILES)
   IF event_data[0] NE '' THEN num_events=N_ELEMENTS(event_data) ELSE num_events=0
;   quote="'"
;   SQLSTR='echo "\t \a \\\select a.filename from orbit_subset_product a join ' $
;          +'rain_by_orbit_swath b using (orbit, subset, version) where '       $
;          +'a.product_type = '+quote+'2AGPROF'+quote+' and a.sat_id='+quote+'GPM' $
;          +quote+' and (b.conv_ocean+b.strat_ocean) > 999 order by a.orbit;"'  $
;          +' | psql -q -d gpmgv'
ENDELSE

;print, sqlstr

IF ( num_events LT 1 ) THEN BEGIN
   message, "No files returned from DB query."
ENDIF ELSE BEGIN
  ; print the query statistics
   PRINT, ""  &  PRINT, 'total number of events = ', num_events  &  PRINT, ""
ENDELSE

IF write2nc EQ 0 and display EQ 0 THEN BEGIN
   PRINT, ''
   PRINT, "No file or display output specified, skipping matchups."
   PRINT, "Try again with DISPLAY and/or WRITE2NC values specified.  Bye!"
   PRINT, ''
   GOTO, noaction
ENDIF

skippedLast = 0  ; indicates whether we skipped case of pre-existing netCDF

for i = 0, (num_events-1) do begin

   ; set up bailout prompt for every 5th matchup and/or static image case
   doodah = ""
   IF i EQ 0 THEN GOTO, skipBail
   IF (display AND (i MOD 5 EQ 0)) OR (display AND (loopit EQ 0)) THEN BEGIN
      PRINT, ''
      READ, doodah, PROMPT='Hit Return to do next case, Q to Quit: '
   ENDIF
   IF doodah EQ 'Q' OR doodah EQ 'q' THEN break

   ; clear the prior static image, if it exists
   IF display AND (loopit EQ 0) AND (skippedLast EQ 0) THEN WDELETE, 1

   skipBail:

   print, event_data[i]
   gmi2AGFROFfile = event_data[i]
   ; if we have a filename with no path info, then prepend the well-known path
;   IF FILE_DIRNAME(event_data[i]) EQ '.' THEN $
;    IF N_ELEMENTS( files2agmi ) NE 0 THEN gmi2AGFROFfile = datadirroot+event_data[i] $
;    ELSE gmi2AGFROFfile = event_data[i]

   parsed = STRSPLIT(FILE_BASENAME(gmi2AGFROFfile), '.', /EXTRACT)
   parseddtime=STRSPLIT(parsed[4], '-', /EXTRACT)
   yymmdd = parseddtime[0]
   orbitstr = parsed[5]
   orbit = LONG(orbitstr)
;   TRMM_vers = LONG(parsed[3])
   TRMM_vers_str = parsed[6]
   parsedLevelSubset = STRSPLIT(parsed[0], '-', /EXTRACT)
   IF parsedLevelSubset[1] EQ 'CS' THEN subset = parsedLevelSubset[2] $
   ELSE subset = 'FullOrbit'
;  HELP, yymmdd, orbit, subset

   ; define the basic search pattern for the matching DPR file
   IF subset EQ 'FullOrbit' THEN $
      dpr_pattern = '*.'+yymmdd+'*.'+orbitstr+'.*' $
   ELSE dpr_pattern = '*'+subset+'*.'+yymmdd+'*.'+orbitstr+'.*'
;  print, dpr_pattern
   dpr_file = find_dpr_for_gmi( gmi2AGFROFfile, DPR_type, DPR_pattern, $
                                DPR_version, BATCH=batch )
   IF dpr_file EQ 'no_DPR_file' THEN BEGIN
      print, ''
      print, "Skipping this case, no matching "+DPR_type+" file found for: "
      print, FILE_BASENAME(gmi2AGFROFfile)
      print, ''
      CONTINUE
   ENDIF ELSE print, "dpr_file = ", dpr_file

   dprgmi_file = find_dpr_for_gmi( gmi2AGFROFfile, DPRGMItype, DPR_pattern, $
                                   DPRGMI_version, BATCH=batch )
   IF dprgmi_file EQ 'no_DPR_file' THEN BEGIN
      print, ''
      print, "Skipping 2B-DPRGMI matching for this case, no matching " $
             +DPRGMItype+" file found for: "
      print, FILE_BASENAME(gmi2AGFROFfile)
      print, ''
   ENDIF ELSE print, "dprgmi_file = ", dprgmi_file

   ; set up the output netCDF filename if we are writing one
;   ncfile_out = KEYWORD_SET( ncfile_out )
   IF write2nc THEN BEGIN
      ncfile_base = 'DPRtoGMI_NN.' + yymmdd + '.' + orbitstr + '.' $
                    + TRMM_vers_str + '.' + subset + '_' $
                    + DPR_type + '_' + DPR_scantype + '_' + DPR_version + '_' $
                    + STRING(radius, FORMAT="(f0.1)") + 'km.nc'
      IF N_ELEMENTS(path_out) EQ 0 THEN $
         ncfile_out = NCGRIDS_ROOT+PR_TMI_MATCH_NCDIR+'/'+ncfile_base $
      ELSE ncfile_out = path_out + '/' + ncfile_base
      print,"" & print,"Writing output to netCDF file: ",ncfile_out & print,""
      ; check whether the output file already exists in some form (gzip or not)
      IF FIND_ALT_FILENAME(ncfile_out+'.gz', foundfile) NE 0 $
      AND KEYWORD_SET(skip_existing) THEN BEGIN
         message, "Already have output file: "+foundfile, /info
         print, "Skipping netCDF file output for orbit ", orbit & print, ""
         skippedLast = 1
         continue
      ENDIF ELSE skippedLast = 0
   ENDIF

   IF (print_times) THEN BEGIN
      print, ''
      print, "Starting DPR-GMI matchup."
      timestart=systime(1)
   ENDIF

    ; set up the file pair to process and call dpr2gmi to do the matchup
    files2do = gmi2AGFROFfile + '|' + dpr_file
    datastructure = dpr2gmi( gmi2AGFROFfile, dpr_file, DPR_scantype, $
                               dprgmi_file, RADIUS=radius, $
                               NCFILE_OUT=ncfile_out) ;, PRINT_TIMES=print_times )

   IF (print_times) THEN BEGIN
      print, "Finished DPR-GMI matchup.  Elapsed seconds: ", systime(1)-timestart
   ENDIF

   szback = SIZE(datastructure, /TYPE)
   IF szback NE 8 THEN BEGIN
      print, "No DPR file match for case, skipping."
      continue
   ENDIF

   IF (display) THEN BEGIN
      IF (datastructure.min_scan GE 0 AND datastructure.max_scan GE 0) THEN BEGIN
         CASE loopit OF
           0 : plot_rainrate_swath, datastructure, ANIMATE=loopit, /PRECUT
           1 : plot_rainrate_swath, datastructure, ANIMATE=loopit, /PRECUT
           2 : animate_rainrate_bscan, datastructure, /PRECUT
         ENDCASE
      ENDIF ELSE BEGIN
         print, "No data to show, min_scan or max_scan out of range: ", $
                datastructure.min_scan, datastructure.max_scan
      ENDELSE
   ENDIF
endfor

IF (display) AND (loopit EQ 0) AND (skippedLast EQ 0) THEN BEGIN
   IF i EQ 1 AND num_events EQ 1 THEN BEGIN
      PRINT, ''
      READ, doodah, PROMPT='Hit Return to finish: '
   ENDIF
   WDELETE, 1
ENDIF

print, "Done!"

noaction:
end
