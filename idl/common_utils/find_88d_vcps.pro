;===============================================================================
function get_known_vcp_elevs, list_id, nelevs, elevslist, irow

quote="'"
command = 'echo "\t \a \\\select elev_angle from sweep_elevs where list_id=' $
          + list_id + ' order by 1;" | psql -q -d gpmgv'
SPAWN, command, dbresult, COUNT=n_in_vcp
IF ( n_in_vcp NE nelevs ) THEN BEGIN
   print, "In get_known_vcp_elevs(), inconsistent number of elevations in DB tables."
   print, "list_id: ", list_id, "  nelevs: ", nelevs, "  n_in_vcp: ", n_in_vcp
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

pro find_88d_vcps, numswp, SHOW_MISSES=show_misses, TESTONLY=testonly

IF N_PARAMS() NE 1 THEN message, "Must enter one argument, the number of sweeps in the VCP."

CASE numswp OF
   14 : BEGIN
        VCP = ['11','12']
        VCP_list_id = ['3', '4']  ; list_ids defining nominal VCP sweep elevations
        VCPtilts = [[0.5,1.5,2.4,3.4,4.3,5.3,6.2,7.5,8.7,10.0,12.0,14.0,16.7,19.5], $
                    [0.5,0.9,1.3,1.8,2.4,3.1,4.0,5.1,6.4,8.0,10.0,12.5,15.6,19.5]]
        ; most common values for these VCPs in data set (not as good a result as nominals) (list_id=[3,4])
        ;VCPtilts = [[0.48,1.45,2.42,3.34,4.31,5.23,6.20,7.52,8.70,10.02,12.00,14.02,16.70,19.52], $
        ;            [0.56,0.95,1.39,1.88,2.48,3.19,4.06,5.16,6.47, 8.05,10.06,12.53,15.64,19.56]]
        max_deg_diff = 0.15  ; cutoff elev. angle difference at/beyond which VCPs don't match
        END
    9 : BEGIN
        VCP=['21']
        VCP_list_id = ['1']
        VCPtilts = [0.5, 1.5, 2.4, 3.4, 4.3, 6.0, 9.9, 14.6, 19.5]
        ; most common values for these VCPs in data set (list_id=1)
        ;VCPtilts = [0.48, 1.45, 2.42, 3.34, 4.31, 6.02, 9.89, 14.59, 19.52]
        max_deg_diff = 0.15
        END
    5 : BEGIN
        VCP=['31']
        VCP_list_id = ['2']
        VCPtilts = [0.5, 1.5, 2.5, 3.5, 4.5]
        ; most common values for these VCPs in data set (list_id=2)
        ;VCPtilts = [0.48, 1.50, 2.50, 3.52, 4.48]
        max_deg_diff = 0.17
        END
 ELSE : BEGIN
        print, "Only allowed argument values are 5, 9, and 14.  Try again."
        GOTO, bail
        END
ENDCASE

igv = 0
vcplist = STRARR(200)       ; ASCII list of elev angles in VCP
list_ids = LONARR(200)      ; database IDs of existing VCP lists
list_id_txt = STRARR(200)  ; ASCII version of above
elevslist = FLTARR(200,40)  ; lists of unique elevation angles in VCP
nelevsvcp = FLTARR(200)     ; number of unique elevations in VCP
n_vcps = 0                  ; number of unique VCP defined/found
status = 0

; get data for any existing VCPs from DB
dbresult = ''
quote = "'"
command = 'echo "\t \a \\\select list_id, COALESCE(vcp_num, ' +quote+'N/A'+quote+ $
          '), nsweeps, sweeplist from sweep_elev_list;" | psql -q -d gpmgv'
SPAWN, command, dbresult, COUNT=n_vcps ; = N_ELEMENTS(dbresult)
IF ( n_vcps GT 0 ) THEN BEGIN
  ; parse the db table information and load to VCP arrays
   FOR idbrow = 0, n_vcps-1 DO BEGIN
      parsed = STRSPLIT( dbresult[idbrow], '|', COUNT=nparsed, /extract )
      IF nparsed EQ 4 THEN BEGIN
         list_id_txt[idbrow] = parsed[0]
         list_ids[idbrow] = LONG( list_id_txt[idbrow] )
         nelevsdb = FIX( parsed[2] )
         nelevsvcp[idbrow] = nelevsdb
         vcplist[idbrow] = parsed[3]
         irow2load = idbrow
         status=get_known_vcp_elevs( list_id_txt[idbrow], nelevsdb, elevslist, irow2load )
;PRINT, list_id_txt, ': ', REFORM(elevslist[irow2load,0:nelevsdb-1])
      ENDIF ELSE message, "Incorrect number of columns returned from SQL call!"
   ENDFOR
ENDIF ELSE print, "No existing VCPs found in sweep_elev_list table in DB."

FOR myVCP = 0, N_ELEMENTS(VCP)-1 DO BEGIN

tocdf_elev_angle = REFORM(VCPtilts[*,myVCP])
num_elevations_out = N_ELEMENTS(tocdf_elev_angle)
matchset = 0

; find the sets with the same number of sweeps as the current volume
idxSameN = WHERE( nelevsvcp EQ num_elevations_out, countsame )
IF countsame GE 1 THEN BEGIN
   print, countsame, ' sets have ', num_elevations_out, ' sweeps.'
   print, "In find_88d_vcps(), found match to VCP ", VCP[myVCP] ;STRING(VCP[myVCP],FORMAT='(I0)')
   print, "Nominal: ", tocdf_elev_angle
   print
   FOR iset = 0, countsame-1 DO BEGIN
      IF VCP_list_id[myVCP] NE list_id_txt[idxSameN[iset]] THEN BEGIN  ; skip "nominal" set itself
         maxdiff = MAX( ABS(tocdf_elev_angle - elevslist[idxSameN[iset], 0:num_elevations_out-1]) )
         IF KEYWORD_SET(show_misses) THEN print, "MAXDIFF: ", maxdiff,  "  THRESHOLD: ", max_deg_diff
         IF ( maxdiff LT max_deg_diff ) THEN BEGIN
            matchset = matchset + 1
            print, "Set # ",STRING(list_ids[idxSameN[iset]],FORMAT='(I0)'), ': ', $
                REFORM(elevslist[idxSameN[iset], 0:num_elevations_out-1])
            sqlupd = "UPDATE volume_sweep_elev set list_id=" + VCP_list_id[myVCP] + $
                  " WHERE list_id=" + list_id_txt[idxSameN[iset]] + ';'
;            print, sqlupd
            command = 'echo "' + sqlupd + '" | psql gpmgv'
            IF ( NOT KEYWORD_SET(testonly) ) THEN BEGIN
               print, command             ; list the unix command line w/SQL
               SPAWN, command, dbresult   ; run the unix command to update DB
            ENDIF ELSE print, "Test SQL: ", sqlupd
         ENDIF ELSE BEGIN
            IF KEYWORD_SET(show_misses) THEN print, "Not a match, set #", $
                   STRING(list_ids[idxSameN[iset]],FORMAT='(I0)'), ': ', $
                   REFORM(elevslist[idxSameN[iset], 0:num_elevations_out-1])
         ENDELSE
      ENDIF ELSE print, "Skipping self, set #", $
                   STRING(list_ids[idxSameN[iset]],FORMAT='(I0)'), ': ', $
                   REFORM(elevslist[idxSameN[iset], 0:num_elevations_out-1])
   ENDFOR
   print
   print, "Number of matching sets: ", matchset
   print
ENDIF

ENDFOR

bail:
end
