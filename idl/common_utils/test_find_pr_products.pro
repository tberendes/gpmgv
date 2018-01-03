pro test_find_pr_products, NCDATA=ncdata, PRDATA_ROOT=prdata_root, USE_DB=use_db

IF ( N_ELEMENTS(NCDATA) NE 1 ) THEN BEGIN
   print, "Defaulting to /data/netcdf/geo_match for netCDF file path."
   print, ""
   NCDATA = '/data/netcdf/geo_match'
ENDIF

IF ( N_ELEMENTS(prdata_root) NE 1 ) THEN BEGIN
   print, "Defaulting to /data/prsubsets for PR file path."
   print, ""
   PRDATA_ROOT = '/data/prsubsets'
ENDIF

; Set use_db flag, default is to not use a Postgresql database query to obtain
; the PR product filenames matching the geo-match netCDF file for each case.
use_db = KEYWORD_SET( use_db )

dataPR = DIALOG_PICKFILE(PATH=NCDATA,TITLE='Select a netCDF file')
IF dataPR NE '' THEN BEGIN
   PRINT, "For Geo-Match netCDF file: ", dataPR
   PRINT, "Selecting all corresponding PR subset files:"
   status = find_pr_products(dataPR, PRDATA_ROOT, prfiles4, USE_DB=use_db)
   print, prfiles4
   IF ( status NE 1 ) THEN BEGIN
      parsepr = STRSPLIT( prfiles4, '|', /extract )
      idx21 = WHERE(STRPOS(parsepr,'1C21') GT 0, count21)
      if count21 EQ 1 THEN file_1c21 = STRTRIM(parsepr[idx21],2) ELSE file_1c21='no_1C21_file'
      idx23 = WHERE(STRPOS(parsepr,'2A23') GT 0, count23)
      if count23 EQ 1 THEN file_2a23 = STRTRIM(parsepr[idx23],2) ELSE file_2a23='no_2A23_file'
      idx25 = WHERE(STRPOS(parsepr,'2A25') GT 0, count25)
      if count25 EQ 1 THEN file_2a25 = STRTRIM(parsepr[idx25],2) ELSE file_2a25='no_2A25_file'
      idx31 = WHERE(STRPOS(parsepr,'2B31') GT 0, count31)
      if count31 EQ 1 THEN file_2b31 = STRTRIM(parsepr[idx31],2) ELSE file_2b31='no_2B31_file'
      PRINT, 'file_1c21 = ', file_1c21
      PRINT, 'file_2a23 = ', file_2a23
      PRINT, 'file_2a25 = ', file_2a25
      PRINT, 'file_2b31 = ', file_2b31
      PRINT, ""
   ENDIF

   PRINT, "Selecting 1C21 file:"
   status = find_pr_products(dataPR, PRDATA_ROOT, prfiles4, USE_DB=use_db, $
                             GET_ONLY='1C21')
   print, prfiles4
   parsepr = STRSPLIT( prfiles4, '|', /extract )
   idx21 = WHERE(STRPOS(parsepr,'1C21') GT 0, count21)
   if count21 EQ 1 THEN file_1c21 = STRTRIM(parsepr[idx21],2) ELSE file_1c21='no_1C21_file'
   IF ( status NE 0 AND file_1c21 EQ 'no_1C21_file' ) THEN BEGIN
      PRINT, ""
      PRINT, "ERROR finding 1C-21 product file."
      PRINT, ""
   ENDIF ELSE BEGIN
      PRINT, 'file_1c21 = ', file_1c21
      PRINT, ""
   ENDELSE

   PRINT, "Selecting 2A23 file:"
   status = find_pr_products(dataPR, PRDATA_ROOT, prfiles4, USE_DB=use_db, $
                             GET_ONLY='2A23')
   print, prfiles4
   parsepr = STRSPLIT( prfiles4, '|', /extract )
   idx23 = WHERE(STRPOS(parsepr,'2A23') GT 0, count23)
   if count23 EQ 1 THEN file_2a23 = STRTRIM(parsepr[idx23],2) ELSE file_2a23='no_2A23_file'
   IF ( status NE 0 AND file_2a23 EQ 'no_2A23_file' ) THEN BEGIN
      PRINT, ""
      PRINT, "ERROR finding 2A-23 product file."
      PRINT, ""
   ENDIF ELSE BEGIN
      PRINT, 'file_2a23 = ', file_2a23
      PRINT, ""
   ENDELSE

   PRINT, "Selecting 2A25 file:"
   status = find_pr_products(dataPR, PRDATA_ROOT, prfiles4, USE_DB=use_db, $
                             GET_ONLY='2A25')
   print, prfiles4
   parsepr = STRSPLIT( prfiles4, '|', /extract )
   idx25 = WHERE(STRPOS(parsepr,'2A25') GT 0, count25)
   if count25 EQ 1 THEN file_2a25 = STRTRIM(parsepr[idx25],2) ELSE file_2a25='no_2A25_file'
   IF ( status NE 0 AND file_2a25 EQ 'no_2A25_file' ) THEN BEGIN
      PRINT, ""
      PRINT, "ERROR finding 2A-25 product file."
      PRINT, ""
   ENDIF ELSE BEGIN
      PRINT, 'file_2a25 = ', file_2a25
      PRINT, ""
   ENDELSE

   PRINT, "Selecting 2B31 file:"
   status = find_pr_products(dataPR, PRDATA_ROOT, prfiles4, USE_DB=use_db, $
                             GET_ONLY='2B31')
   print, prfiles4
   parsepr = STRSPLIT( prfiles4, '|', /extract )
   idx31 = WHERE(STRPOS(parsepr,'2B31') GT 0, count31)
   if count31 EQ 1 THEN file_2b31 = STRTRIM(parsepr[idx31],2) ELSE file_2b31='no_2B31_file'
   IF ( status NE 0 AND file_2B31 EQ 'no_2B31_file' ) THEN BEGIN
      PRINT, ""
      PRINT, "ERROR finding 2B-31 product file."
      PRINT, ""
   ENDIF ELSE BEGIN
      PRINT, 'file_2b31 = ', file_2b31
      PRINT, ""
   ENDELSE
ENDIF ELSE print, "No netCDF file selected, exiting."

END
