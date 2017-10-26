;===============================================================================
;+
; Copyright © 2011, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; catalog_1cuf_sweeps.pro      Morris/SAIC/GPM_GV      Jan 2011
;
; DESCRIPTION
; -----------
; Given a list of radar data files (1CUF or UF format assumed), steps through
; the list of files, extracting the list of elevation angles present in the
; radar volume scan and comparing the list of scan angles present to those sets
; already cataloged in the 'gpmgv' database.  Assumes that there will be a
; limited number of "standard" sweep elevation angle sets used over and over by
; the radars, to which the data file can be linked by the unique ID of the data
; file and the unique ID of the sweep elevation angle set (i.e., the Volume
; Coverage Pattern or VCP in WSR-88D lingo).  If a new set of elevation angles
; is found, these will be added to the database and a new unique ID will be
; assigned by the database (see the schema of the sweep_elev_list table in the
; gpmgv database).
;
; "Sameness" of the elevation angles between sets allows for a small amount of
; variation in the elevation values from radar volume to radar volume.  If two
; sets of elevation angles have the same number of elevations, and if the
; elevation angles at each sweep level are within +/-0.05 degrees, then the
; sweep sets are considered identical.  Otherwise a new elevation angle set will
; be defined and stored to the database.
;
; MODULES
; -------
; catalog_1cuf_sweeps  - main routine, take a list of 1CUF file pathnames and
;                        their database IDs, and catalogs them against the set
;                        of sweep angles in the radar volume.
; get_known_vcp_elevs  - given the ID of a sweep angle set, retrieves the array
;                        of numerical elevation angles defining the set.
; compare_elevations   - compares a list of elevation values against the sets of
;                        elevation angles already known to determine if it is
;                        the same as one of the known sets, within a threshold
;
; define_vcp_set       - write a new set of unique sweep angles to the database
;                        and returns the newly assigned database ID of the sweep
;                        angle set
;
; catalog_1cuf_vcp_set - writes the file-to-VCP set association to the database
;
; DATABASE TABLES
; ---------------
; gv_radar - Used by the calling script to assemble the list of 1CUF file
;            pathnames and their unique IDs (fileidnum attribute), passed to
;            catalog_1cuf_sweeps in the 'control_file', which links the 1CUF
;            fileIDnum to the ID of the sweep elevation set (i.e., VCP) and
;            stores the linkage in the database in the volume_sweep_elev table.
;            (READ)
;
; sweep_elev_list - Holds the unique IDs of the sweep elevation sets, the
;                   WSR-88D VCP number of the set (if any/known), the number
;                   of UNIQUE elevation angles in the sweep elevation set, and
;                   a comma-separated list of the elevation angles in the
;                   set in the form of a character string.  (READ/WRITE)
;
; sweep_elevs - Holds the individual elevation angle values (FLOAT) for each
;               sweep elevation set, tagged with the unique ID of the set.
;               Duplicate sweep elevations are ignored.  (READ/WRITE)
;
; volume_sweep_elev - Defines the linkage between the unique ID of the 1CUF data
;                     files and the unique ID of the sweep elevation sets.  Also
;                     indicates the presence/number of duplicate sweep elevation
;                     angles in the radar data volume. Some WSR-88D products
;                     have more than one instance of a given data field at a
;                     the same elevation, for the first few elevations. (WRITE)
;
; HISTORY
; -------
; 1/2011 by Bob Morris, GPM GV (SAIC)
;  - Created.
;
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;===============================================================================

function get_known_vcp_elevs, list_id, nelevs, elevslist, irow

quote="'"
command = 'echo "\t \a \\\select elev_angle from sweep_elevs where list_id=' $
          + list_id + ' order by 1;" | psql -q -d gpmgv'
SPAWN, command, dbresult, COUNT=n_in_vcp
IF ( n_in_vcp NE nelevs ) THEN BEGIN
   print, "In get_known_vcp_elevs(), inconsistent number of elevations in DB tables."
   return, 0
ENDIF ELSE BEGIN
  ; load the elevation values into elevslist row = irow
   FOR ielev = 0, n_in_vcp-1 DO BEGIN
      elevslist[irow, ielev] = FLOAT( dbresult[ielev] )
   ENDFOR
ENDELSE
return, 1
end

;===============================================================================

FUNCTION compare_elevations, tocdf_elev_angle, num_elevations_out, elevslist, nelevsvcp

; Compare a set of elevation angles in a volume to existing sets of elevations having
; the same number of sweeps.  If the elevation angles at every sweep level differ
; by less than 0.15 degrees, then call it a match between the current and existing
; set, and return the index of the existing set list; else return -1.  Only the first
; match to existing sets is found and returned.

matchset = -1

; find the sets with the same number of sweeps as the current volume
idxSameN = WHERE( nelevsvcp EQ num_elevations_out, countsame )
IF countsame GE 1 THEN BEGIN
   FOR iset = 0, countsame-1 DO BEGIN
      maxdiff = MAX( ABS(tocdf_elev_angle - elevslist[idxSameN[iset], 0:num_elevations_out-1]) )
      IF ( maxdiff LT 0.15 ) THEN BEGIN
         matchset = idxSameN[iset]
         print, "In compare_elevations() found match between sweep sets:"
         print, "Current: ", tocdf_elev_angle
         print, "Existing: ", REFORM(elevslist[idxSameN[iset], 0:num_elevations_out-1])
         print, ''
         BREAK
      ENDIF
   ENDFOR
ENDIF

return, matchset
end

;===============================================================================

FUNCTION define_vcp_set, VCP_CSV_text, tocdf_elev_angle, n_vcps
   print, "Defining new VCP set ", STRING(n_vcps, FORMAT='(I0)')
   quote = "'"
   idval = -1L
   tblvals = STRING(N_ELEMENTS(tocdf_elev_angle), FORMAT='(I0)')+', '+quote+VCP_CSV_text+quote
   command = 'echo "INSERT INTO sweep_elev_list(nsweeps,sweeplist) VALUES(' + tblvals + $
             ');" | psql -q -d gpmgv'
   print, command
   SPAWN, command
   command = 'echo "\t \a \\\SELECT list_id FROM sweep_elev_list WHERE sweeplist=' + $
             quote+VCP_CSV_text+quote + ';" | psql -q -d gpmgv'
   print, command
   SPAWN, command, dbresult, COUNT=n_list_ids
   IF ( n_list_ids EQ 1 ) THEN BEGIN
      print, "New List ID in DB = ", dbresult
      idval = LONG( dbresult )
      FOR iswp = 0, N_ELEMENTS(tocdf_elev_angle)-1 DO BEGIN
         tblvals2 = dbresult+', '+STRING(tocdf_elev_angle[iswp], FORMAT='(F0.2)')
         command = 'echo "INSERT INTO sweep_elevs VALUES(' + tblvals2 + ');" | psql -q -d gpmgv'
         print, command
         SPAWN, command
      ENDFOR
      command = 'echo "\t \a \\\SELECT count(*) FROM sweep_elevs WHERE list_id=' +dbresult+ $
                ';" | psql -q -d gpmgv'
      SPAWN, command, dbresult2, COUNT=nrows
      IF ( nrows EQ 1 ) THEN BEGIN
         IF ( FIX(dbresult2) NE N_ELEMENTS(tocdf_elev_angle) ) THEN BEGIN
            idval = -1
            message, "Incorrect number of rows in sweep_elevs for list_id = "+dbresult+": "+dbresult2
         ENDIF
      ENDIF ELSE message, "Incorrect number of columns returned from SQL call!"
   print
   ENDIF ELSE message, "Incorrect number of columns returned from SQL call!"
   return, idval
END

;===============================================================================

FUNCTION catalog_1cuf_vcp_set, list_id, event_num, n_duplicates
   ;print, "DB catalog line: "
   idstr = STRING(list_id, FORMAT='(I0)')
   idtxt = idstr + ", "
   volstr = STRING(event_num, FORMAT='(I0)')
   voltxt = volstr + ", "
   nduptxt = STRING(n_duplicates, FORMAT='(I0)')
   SQL = 'echo "INSERT INTO volume_sweep_elev VALUES (' + voltxt + idtxt + $
         nduptxt + ');" | psql -q -d gpmgv  2>&1'
   ;print, SQL
   spawn, SQL, result
   IF (STRPOS(result, 'ERROR') NE -1) THEN BEGIN
      print, "Query being attempted: ", SQL
      message, result
   ENDIF
   SQL2 = 'echo "\t \a \\\SELECT * FROM volume_sweep_elev WHERE fileidnum=' $
           +STRING(event_num, FORMAT='(I0)')+ ';" | psql -q -d gpmgv'
   ;print, sql2
   spawn, SQL2, result, COUNT=nrows
   IF ( nrows NE 1 ) THEN BEGIN
      print, 'Error in catalog_1cuf_vcp_set(), ', STRING(nrows, FORMAT='(I0)'), $
             ' rows inserted/returned:'
      FOR i = 0, nrows-1 DO BEGIN
         print, result[i]
      ENDFOR
   ENDIF ELSE print, "File ID ", volstr, " linked to sweep set ", idstr
   print
return, 0
end

;===============================================================================

pro catalog_1cuf_sweeps, control_file, in_base_dir, LIST_EXISTING=list_existing

; initialize the variables into which file records are read as strings
dataGV=""

; open and process control file, and generate the sweep elevation data
OPENR, lun0, control_file, ERROR=err, /GET_LUN

igv = 0
vcplist = STRARR(200)       ; ASCII list of elev angles in VCP
list_ids = LONARR(200)      ; database IDs of existing VCP lists
elevslist = FLTARR(200,40)  ; lists of unique elevation angles in VCP
nelevsvcp = FLTARR(200)     ; number of unique elevations in VCP
n_vcps = 0                  ; number of unique VCP defined/found
status = 0

; get data for any existing VCPs from DB
dbresult = ''
quote = "'"
command = 'echo "\t \a \\\select list_id, COALESCE(vcp_num, ' +quote+'N/A'+quote+ $
          '), nsweeps, sweeplist from sweep_elev_list order by 1;" | psql -q -d gpmgv'
SPAWN, command, dbresult, COUNT=n_vcps ; = N_ELEMENTS(dbresult)
IF ( n_vcps GT 0 ) THEN BEGIN
  ; parse the db table information and load to VCP arrays
   FOR idbrow = 0, n_vcps-1 DO BEGIN
      parsed = STRSPLIT( dbresult[idbrow], '|', COUNT=nparsed, /extract )
      IF nparsed EQ 4 THEN BEGIN
         list_id_txt = parsed[0]
         list_ids[idbrow] = LONG( list_id_txt )
         nelevsdb = FIX( parsed[2] )
         nelevsvcp[idbrow] = nelevsdb
         vcplist[idbrow] = parsed[3]
         irow2load = idbrow
         status=get_known_vcp_elevs( list_id_txt, nelevsdb, elevslist, irow2load )
         IF KEYWORD_SET(list_existing) THEN $
            PRINT, list_id_txt, ': ', REFORM(elevslist[irow2load,0:nelevsdb-1])
      ENDIF ELSE message, "Incorrect number of columns returned from SQL call!"
   ENDFOR
ENDIF ELSE print, "No existing VCPs found in sweep_elev_list table in DB."

WHILE NOT (EOF(lun0)) DO BEGIN 

  ; read and parse the control file GV site ID, lat, lon, elev, filename, etc.
  ;  - read each overpassed site's information as a '|'-delimited string
   READF, lun0, dataGV

  ; parse dataGV into its component fields: event_num, orbit number, siteID,
  ; overpass datetime, time in ticks, site lat, site lon, site elev,
  ; 1CUF file unique pathname

   nparsed = 0
   parsed=STRSPLIT( dataGV, '|', COUNT=nparsed, /extract )
   IF nparsed NE 3 THEN MESSAGE, "Incorrect number of fields in GV control file string."
   siteID = parsed[0]
   origUFName = parsed[1]   ; filename as listed in/on the database/disk
   event_num = parsed[2]    ; fileID
  ; adding the well-known (or local) path to get the fully-qualified file name:
   base_1CUF = file_basename(origUFName)
   file_1CUF = in_base_dir + "/" + siteID + "/" + origUFName

   PRINT, ""
   PRINT, '----------------------------------------------------------------'
   PRINT, event_num, ", ", siteID, ", ",  file_1CUF
   PRINT, ""

  ; copy/unzip/open the UF file and read the entire volume scan into an
  ;   RSL_in_IDL radar structure, and then close UF file and delete copy:

   status=get_rsl_radar(file_1CUF, radar)
   IF ( status NE 0 )  THEN BEGIN
      PRINT, ""
      PRINT, "Error reading radar structure from file ", file_1CUF
      PRINT, ""
      keeper=0
      GOTO, nextGVfile
   ENDIF

  ; find the volume with the correct reflectivity field for the GV site/source,
  ;   and the ID of the field itself
   gv_z_field = ''
   z_vol_num = get_site_specific_z_volume( siteID, radar, gv_z_field )
   IF ( z_vol_num LT 0 )  THEN BEGIN
      PRINT, ""
      PRINT, "Error finding volume in radar structure from file ", file_1CUF
      PRINT, ""
      keeper=0
      GOTO, nextGVfile
   ENDIF

  ; get the number of elevation sweeps in the vol, and the array of elev angles
   num_elevations = get_sweep_elevs( z_vol_num, radar, elev_angle )

  ; make a copy of the array of elevations, from which we eliminate any
  ;   duplicate tilt angles for subsequent data processing/output
   uniq_elev_angle = elev_angle
   idx_uniq_elevs = UNIQ_SWEEPS(elev_angle, uniq_elev_angle)

   tocdf_elev_angle = elev_angle[idx_uniq_elevs]

   num_elevations_out = N_ELEMENTS(tocdf_elev_angle)
   n_duplicates = num_elevations - num_elevations_out
   IF n_duplicates NE 0 THEN print, "Duplicate sweep elevations found!"

   elevorder = SORT(tocdf_elev_angle)
   ascorder = INDGEN(num_elevations_out)
   sortflag=0
   IF TOTAL( ABS(elevorder-ascorder) ) NE 0 THEN BEGIN
      PRINT, 'read_geo_match_netcdf(): Elevation angles not in order! Resorting data.'
      sortflag=1
      tocdf_elev_angle = tocdf_elev_angle[elevorder]
   ENDIF

   VCP_CSV_text = ''
   comma = ', '
   FOR iswp = 0, num_elevations_out-1 DO BEGIN
      IF iswp EQ num_elevations_out-1 THEN comma = ''
      VCP_CSV_text = VCP_CSV_text + STRING(tocdf_elev_angle[iswp], FORMAT='(F0.2)') + comma
   ENDFOR
   print, "VCP_CSV_text = ", VCP_CSV_text

   identical = WHERE( vcplist EQ VCP_CSV_text, counthavevcp )
   IF (counthavevcp EQ 0) THEN BEGIN
     ; no match to exact elevations, check whether individual elevations are "close enough"
      matchsetidx = compare_elevations( tocdf_elev_angle, num_elevations_out, $
                                        elevslist, nelevsvcp )
      IF matchsetidx EQ -1 THEN BEGIN
         new_list_id = define_vcp_set( VCP_CSV_text, tocdf_elev_angle, n_vcps )
         list_ids[n_vcps] = new_list_id
         vcplist[n_vcps] = VCP_CSV_text
         elevslist[n_vcps, 0:num_elevations_out-1] = tocdf_elev_angle
         nelevsvcp[n_vcps] = num_elevations_out
         n_vcps = n_vcps+1
         catstatus = catalog_1cuf_vcp_set( new_list_id, event_num, n_duplicates )
      ENDIF ELSE BEGIN
         print, "Found near-enough match by checking elevation values."
         catstatus = catalog_1cuf_vcp_set( list_ids[matchsetidx], event_num, n_duplicates )
      ENDELSE
   ENDIF ELSE BEGIN
     ; have exact match based on text of vcplist, catalog the linkage to file
      print, "Found match to list ID # ", STRING(list_ids[identical], FORMAT='(I0)')
      catstatus = catalog_1cuf_vcp_set( list_ids[identical], event_num, n_duplicates )
   ENDELSE

   igv = igv+1
   nextGVfile:

ENDWHILE    ; each GV site for orbit

IF KEYWORD_SET(list_existing) THEN BEGIN
   $print, ''
   print, "List of VCPs found:"
   FOR ivcp = 0, n_vcps-1 DO BEGIN
      print, STRING( list_ids[ivcp], FORMAT='(I0," : ")' ), vcplist[ivcp]
   ENDFOR
ENDIF

END
