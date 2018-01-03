;===============================================================================
;+
; Copyright © 2009, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; find_pr_products.pro    Morris/SAIC/GPM_GV    March 2009
;
; DESCRIPTION
; -----------
; Determine the full pathnames of the PR product files corresponding to the
; given fully-qualified GeoMatch netCDF file pathname 'ncfile'.  Make a first
; attempt using the date stamp of the Geomatch metCDF file -- if fails, try
; with just a match to the orbit number.  The naming conventions for the
; various PR product subsets' files are handled in a CASE statement which
; switches based on the Site ID.  PR file types handled include 1C21, 2A23,
; 2A25, and 2B31.
;
; PARAMETERS
; ----------
; ncfile        - Fully-qualified pathname of the geo_match netCDF file whose
;                 corresponding PR product files are to be found.
; pr_data_root  - Common directory path under which all the PR Level 1 and 2
;                 products and their product-specific subdirectories are
;                 located (e.g., /data/prsubsets).
; pr_filenames  - String variable in which the four PR product file pathnames
;                 are returned as a '|'-delimited list.
; use_db        - Binary parameter.  If set, use an SQL query to the 'gpmgv'
;                 database in Postgresql to obtain the names of the PR files.
;                 Otherwise, use CASE statement to build a filename pattern to
;                 be searched to find the PR product files under pr_data_root.
; get_only      - Specifies file prefix of one specific PR file type to be
;                 found.  Other PR file types are ignored in the search.
; Version_PR    - TRMM Product Version of the PR files to be searched (6 or 7).
;
; HISTORY
; -------
; 07/23/09  Morris/GPM GV/SAIC
; -  Added logic to look for a file match with the date stamp wildcarded in
;    the file pattern.  Too many times the datestamp in the netCDF filename
;    is different than the one in the PR product filenames.   Applies only
;    when USE_DB=0 (not using database).
; 10/26/09  Morris/GPM GV/SAIC
; -  Added logic to allow manual selection of PR files when pr_data_root is
;    passed as the special value 'prompt', for looking at PPS v7 PR test data.
; 11/13/09  Morris/GPM GV/SAIC
; -  Added parameter GET_ONLY and logic to look for only the one product type
;    specified by the keyword value, if keyword is specified properly.
; 04/21/10  Morris/GPM GV/SAIC
; - Modified the SQL query to return default placeholder file names in the case
;   where a particular PR file type is not present.
; 04/29/10  Morris/GPM GV/SAIC
; -  Added 2A23 product to the list of file types to be able to find.
; 04/30/10  Morris/GPM GV/SAIC
; -  Set getXX flag to 0 when file successfully found, to prevent need to do
;    manual reselection of type XX if one/more other files are not found.
; 05/11/10  Morris/GPM GV/SAIC
; - Commented out or moved some diagnostic print statements.
; 01/21/11  Morris/GPM GV/SAIC
; - Add VERSION_PR option to search for specific PR file patterns according to
;   the version of PR products used in the PR-GR matchup files.  Adjusted the
;   DATESTAMP value to use for version 7 PR files, which have a 'YYYYMMDD'
;   datestamp format in the PR product file names, while version 6 used 'YYMMDD'.
; - Removed 'sub-GPMGV1' subset designator from default file patterns in ncsite
;   CASE switch.
; 02/08/12  Morris/GPM GV/SAIC
; - Added 'version' to the WHERE clause in the database query to avoid mismatch
;   between the matchup file PR version and the PR product file version when
;   querying the database for the PR product file list.
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;===============================================================================


FUNCTION find_pr_products, ncfile, pr_data_root, pr_filenames, USE_DB=use_db, $
                           GET_ONLY=get_only, VERSION_PR=Version_PR

; -- parse ncfile to get its component fields: orbit number, YYMMDD
dataPR = FILE_BASENAME(ncfile)
parsed=STRSPLIT( dataPR, '.', /extract )
orbit = parsed[3]
orbnum = LONG(orbit)
DATESTAMP = parsed[2]      ; in YYMMDD format
ncsite = parsed[1]
;print, dataPR, " ", orbit, " ", DATESTAMP, " ", ncsite

origFile21Name = 'no_1C21_file'
origFile23Name = 'no_2A23_file'
origFile25Name = 'no_2A25_file'
origFile31Name = 'no_2B31_file'
status = 0

IF ( N_ELEMENTS(get_only) NE 1 ) THEN BEGIN
   get21=1
   get23=1
   get25=1
   get31=1
ENDIF ELSE BEGIN
   CASE STRUPCASE(get_only) OF
     '1C21' : BEGIN & get21=1 & get23=0 & get25=0 & get31=0 & END
     '2A23' : BEGIN & get21=0 & get23=1 & get25=0 & get31=0 & END
     '2A25' : BEGIN & get21=0 & get23=0 & get25=1 & get31=0 & END
     '2B31' : BEGIN & get21=0 & get23=0 & get25=0 & get31=1 & END
      ELSE  : BEGIN
                 print, 'In find_pr_products.pro: Illegal value for GET_ONLY: ', get_only
                 preprint = 'Returning default PR filenames in find_pr_products(): '
                 status=1
                 GOTO, DBerror
              END
   ENDCASE
ENDELSE

IF ( pr_data_root EQ 'prompt' ) THEN BEGIN
   cd, CURRENT=current
   startpath=current
   GOTO, manualSelect   ; have the user select files
ENDIF ELSE startpath=pr_data_root

IF ( N_ELEMENTS(Version_PR) NE 1 ) THEN BEGIN
  ; set the PR version pattern to '*'
   PRVER = '*'
   print, "Using PR version designator of '*' (any/all)"
   prver4db = ' '   ; clause addition for database query
ENDIF ELSE BEGIN
  ; use the version pattern provided
   PRVER = STRTRIM( STRING(Version_PR), 2 )
   print, "Using PR version designator provided: ", PRVER
   prver4db = ' and version = '+PRVER   ; clause addition for database query
ENDELSE

; make adjustments for the Version 7 TRMM filename convention, which uses a
; 4-digit year in the datestamp
IF ( PRVER EQ '7' AND STRLEN(DATESTAMP) EQ 6 ) THEN DATESTAMP = '20'+DATESTAMP

use_db = KEYWORD_SET( use_db )

IF ( use_db ) THEN BEGIN
  ; Query the gpmgv database for the PR filenames for this orbit/subset/version:
   preprint = 'From DB: '
   lcquote='''
   sqlstr='echo "\t\a \\\select subset, COALESCE(file1c21, '+lcquote+origFile21Name+lcquote+'), COALESCE(file2a23, '+lcquote+origFile23Name+lcquote+'), COALESCE(file2a25, '+lcquote+origFile25Name+lcquote+'), COALESCE(file2b31, '+lcquote+origFile31Name+lcquote+') from collatedPRproductswsub where orbit='+orbit+' and radar_id='+lcquote+ncsite+lcquote+prver4db+' and file2a25 is not null;" | psql -q gpmgv'
;   print, sqlstr
   prfiles4=''
   spawn, sqlstr, prfiles4
   IF ( prfiles4 NE '' ) THEN BEGIN
      parsepr = STRSPLIT( prfiles4, '|', /extract )
      filepatt21 = STRTRIM( parsepr[1], 2 )
      filepatt23 = STRTRIM( parsepr[2], 2 )
      filepatt25 = STRTRIM( parsepr[3], 2 )
      filepatt31 = STRTRIM( parsepr[4], 2 )
   ENDIF ELSE BEGIN
      print, 'Query returned no hits!  Query used:'
      print, sqlstr
      status = 1
      GOTO, DBerror
   ENDELSE
ENDIF ELSE BEGIN
   preprint = 'From file_search() in find_pr_products(): '
   CASE ncsite OF
     'CP2' : BEGIN
            pre21 = '1C21.'
            pre23 = '2A23.'
            pre25 = '2A25.'
            pre31 = '2B31.'
            filepatt21 = pre21+DATESTAMP+'.'+orbit+'.'+PRVER+'.HDF*'
            filepatt23 = pre23+DATESTAMP+'.'+orbit+'.'+PRVER+'.HDF*'
            filepatt25 = pre25+DATESTAMP+'.'+orbit+'.'+PRVER+'.HDF*'
            filepatt31 = pre31+DATESTAMP+'.'+orbit+'.'+PRVER+'.HDF*'
            filepatt21b = pre21+'*.'+orbit+'.'+PRVER+'.HDF*'
            filepatt23b = pre23+'*.'+orbit+'.'+PRVER+'.HDF*'
            filepatt25b = pre25+'*.'+orbit+'.'+PRVER+'.HDF*'
            filepatt31b = pre31+'*.'+orbit+'.'+PRVER+'.HDF*'
       END
     'RGSN' : BEGIN
; LIFE GOT MORE COMPLICATED WHEN TRMM VERSION 7 CAME ALONG FOR GPM_KMA SUBSETS,
; NEED A LOT MORE LOGIC HERE.
            IF orbnum LT 61979 THEN BEGIN
               pre21 = '1C21.'
               pre23 = '2A23.'
               pre25 = '2A25.'
               pre31 = '2B31.'
            ENDIF ELSE BEGIN
               pre21 = '1C21_GPM_KMA.'
               pre23 = '2A23_GPM_KMA.'
               pre25 = '2A25_GPM_KMA.'
               pre31 = '2B31_GPM_KMA.'
            ENDELSE
            filepatt21 = pre21+DATESTAMP+'.'+orbit+'.'+PRVER+'.HDF*'
            filepatt23 = pre23+DATESTAMP+'.'+orbit+'.'+PRVER+'.HDF*'
            filepatt25 = pre25+DATESTAMP+'.'+orbit+'.'+PRVER+'.HDF*'
            filepatt31 = pre31+DATESTAMP+'.'+orbit+'.'+PRVER+'.HDF*'
            filepatt21b = pre21+'*.'+orbit+'.'+PRVER+'.HDF*'
            filepatt23b = pre23+'*.'+orbit+'.'+PRVER+'.HDF*'
            filepatt25b = pre25+'*.'+orbit+'.'+PRVER+'.HDF*'
            filepatt31b = pre31+'*.'+orbit+'.'+PRVER+'.HDF*'
       END
     'DARW' : BEGIN
            filepatt21 = '1C21_CSI.'+DATESTAMP+'.'+orbit+'.DARW.6.HDF*'
            filepatt23 = '2A23_CSI.'+DATESTAMP+'.'+orbit+'.DARW.6.HDF*'
            filepatt25 = '2A25_CSI.'+DATESTAMP+'.'+orbit+'.DARW.6.HDF*'
            filepatt31 = '2B31_CSI.'+DATESTAMP+'.'+orbit+'.DARW.6.HDF*'
            filepatt21b = '1C21_CSI.'+'*.'+orbit+'.DARW.6.HDF*'
            filepatt23b = '2A23_CSI.'+'*.'+orbit+'.DARW.6.HDF*'
            filepatt25b = '2A25_CSI.'+'*.'+orbit+'.DARW.6.HDF*'
            filepatt31b = '2B31_CSI.'+'*.'+orbit+'.DARW.6.HDF*'
       END
     'KWAJ' : BEGIN
            filepatt21 = '1C21_CSI.'+DATESTAMP+'.'+orbit+'.KWAJ.6.HDF*'
            filepatt23 = '2A23_CSI.'+DATESTAMP+'.'+orbit+'.KWAJ.6.HDF*'
            filepatt25 = '2A25_CSI.'+DATESTAMP+'.'+orbit+'.KWAJ.6.HDF*'
            filepatt31 = '2B31_CSI.'+DATESTAMP+'.'+orbit+'.KWAJ.6.HDF*'
            filepatt21b = '1C21_CSI.'+'*.'+orbit+'.KWAJ.6.HDF*'
            filepatt23b = '2A23_CSI.'+'*.'+orbit+'.KWAJ.6.HDF*'
            filepatt25b = '2A25_CSI.'+'*.'+orbit+'.KWAJ.6.HDF*'
            filepatt31b = '2B31_CSI.'+'*.'+orbit+'.KWAJ.6.HDF*'
       END
      ELSE  : BEGIN
            filepatt21 = '1C21.'+DATESTAMP+'.'+orbit+'.'+PRVER+'.*'
            filepatt23 = '2A23.'+DATESTAMP+'.'+orbit+'.'+PRVER+'.*'
            filepatt25 = '2A25.'+DATESTAMP+'.'+orbit+'.'+PRVER+'.*'
            filepatt31 = '2B31.'+DATESTAMP+'.'+orbit+'.'+PRVER+'.*'
            filepatt21b = '1C21.'+'*.'+orbit+'.'+PRVER+'.*'
            filepatt23b = '2A23.'+'*.'+orbit+'.'+PRVER+'.*'
            filepatt25b = '2A25.'+'*.'+orbit+'.'+PRVER+'.*'
            filepatt31b = '2B31.'+'*.'+orbit+'.'+PRVER+'.*'
       END
   ENDCASE

ENDELSE

IF get21 EQ 1 THEN BEGIN
file2get = pr_data_root+'/1C21/'+filepatt21
File21Name = file_search(file2get,COUNT=nf)
CASE nf OF
   1 : begin
         origFile21Name = File21Name
         get21 = 0
       end
   0 : begin
         print, '1C21 file match not found: ', file2get, ', try by orbit only:'
         file2get = pr_data_root+'/1C21/'+filepatt21b
         File21Name = file_search(file2get,COUNT=nfb)
         if (nfb eq 1) then begin
            print, '1C21 file match found: ', file2get
            origFile21Name = File21Name
            get21 = 0
         endif else begin
            if (nfb eq 0) then print, '1C21 file match not found: ', file2get $
            else print, 'Unique 1C21 file match not found: ', file2get
            status = 1
         endelse
       end
   else : begin
         status = 1
         print, 'Unique 1C21 file match not found: ', file2get
       end
ENDCASE
ENDIF

IF get23 EQ 1 THEN BEGIN
file2get = pr_data_root+'/2A23/'+filepatt23
File23Name = file_search(file2get,COUNT=nf)
CASE nf OF
   1 : begin
         origFile23Name = File23Name
         get23 = 0
       end
   0 : begin
         print, '2A23 file match not found: ', file2get, ', try by orbit only:'
         file2get = pr_data_root+'/2A23/'+filepatt23b
         File23Name = file_search(file2get,COUNT=nfb)
         if (nfb eq 1) then begin
            print, '2A23 file match found: ', file2get
            origFile23Name = File23Name
            get23 = 0
         endif else begin
            if (nfb eq 0) then print, '2A23 file match not found: ', file2get $
            else print, 'Unique 2A23 file match not found: ', file2get
            status = 1
         endelse
       end
   else : begin
         status = 1
         print, 'Unique 2A23 file match not found: ', file2get
       end
ENDCASE
ENDIF

IF get25 EQ 1 THEN BEGIN
file2get = pr_data_root+'/2A25/'+filepatt25
File25Name = file_search(file2get,COUNT=nf)
CASE nf OF
   1 : begin
         origFile25Name = File25Name
         get25 = 0
       end
   0 : begin
         print, '2A25 file match not found: ', file2get, ', try by orbit only:'
         file2get = pr_data_root+'/2A25/'+filepatt25b
         File25Name = file_search(file2get,COUNT=nfb)
         if (nfb eq 1) then begin
            print, '2A25 file match found: ', file2get
            origFile25Name = File25Name
            get25 = 0
         endif else begin
            if (nfb eq 0) then print, '2A25 file match not found: ', file2get $
            else print, 'Unique 2A25 file match not found: ', file2get
            status = 1
         endelse
       end
   else : begin
         status = 1
         print, 'Unique 2A25 file match not found: ', file2get
       end
ENDCASE
ENDIF

IF get31 EQ 1 THEN BEGIN
file2get = pr_data_root+'/2B31/'+filepatt31
File31Name = file_search(file2get,COUNT=nf)
CASE nf OF
   1 : begin
         origFile31Name = File31Name
         get31 = 0
       end
   0 : begin
         print, '2B31 file match not found: ', file2get, ', try by orbit only:'
         file2get = pr_data_root+'/2B31/'+filepatt31b
         File31Name = file_search(file2get,COUNT=nfb)
         if (nfb eq 1) then begin
            print, '2B31 file match found: ', file2get
            origFile31Name = File31Name
            get31 = 0
         endif else begin
            if (nfb eq 0) then print, '2B31 file match not found: ', file2get $
            else print, 'Unique 2B31 file match not found: ', file2get
            status = 1
         endelse
       end
   else : begin
         status = 1
         print, 'Unique 2B31 file match not found: ', file2get
       end
ENDCASE
ENDIF

IF status EQ 0 THEN GOTO, skipManual

manualSelect:

status2=0
preprint = 'From manual file selections: '
IF (get21 EQ 1) THEN BEGIN
   file21 = DIALOG_PICKFILE(PATH=startpath,FILTER='*21*',TITLE='Select a 1C21 file')
   IF ( file21 NE '' ) THEN BEGIN
      startpath=FILE_DIRNAME(file21)
      origFile21Name=file21
   ENDIF ELSE status2=1
ENDIF

IF (get23 EQ 1) THEN BEGIN
   file23 = DIALOG_PICKFILE(PATH=startpath,FILTER='*23*',TITLE='Select a 2A23 file')
   IF ( file23 NE '' ) THEN BEGIN
       origFile23Name=file23
   ENDIF ELSE status2=1
ENDIF

IF (get25 EQ 1) THEN BEGIN
   file25 = DIALOG_PICKFILE(PATH=startpath,FILTER='*25*',TITLE='Select a 2A25 file')
   IF ( file25 NE '' ) THEN BEGIN
       origFile25Name=file25
   ENDIF ELSE status2=1
ENDIF

IF (get31 EQ 1) THEN BEGIN
   file31 = DIALOG_PICKFILE(PATH=startpath,FILTER='*31*',TITLE='Select a 2B31 file')
   IF ( file31 NE '' ) THEN BEGIN
        origFile31Name=file31
   ENDIF ELSE status2=1
ENDIF

status=status2

DBerror:
skipManual:

;print, preprint, origFile21Name, ', ',origFile23Name, ', ',origFile25Name, ', ',origFile31Name
pr_filenames = origFile21Name + '|' + origFile23Name + '|' + origFile25Name + '|' + origFile31Name

return, status

END
