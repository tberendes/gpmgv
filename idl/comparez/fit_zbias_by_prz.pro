pro fit_zbias_by_prz, file

On_IOError, IO_bailout ;  bailout if there is an error reading or writing a file
OPENR, r_lun, file, /GET_LUN, ERROR=err
PRINT, 'error code', err

PRINT, ' '
PRINT, 'reading from file:'
PRINT, '   ', file
num_read = 0
lastSite = ' '
site_coeff = !null

a_line = ''
site = ''
zval = 0
bias = 0.0
nsamp = 0

WHILE (EOF(r_lun) NE 1) DO BEGIN  ; *****loop through all records*****
   READF, r_lun, a_line
   parsed = strsplit( a_line, /extract )
   site = parsed[0]
   zval = FLOAT(parsed[1])
   bias = FLOAT(parsed[2])
   nsamp = FIX(parsed[3])

   IF site EQ lastSite THEN BEGIN
     ; just concatenate new prz and bias values to arrays
      zvalarr = [zvalarr, REPLICATE(zval,nsamp)]
      biasarr = [biasarr, REPLICATE(bias,nsamp)]
   ENDIF ELSE BEGIN
      IF num_read GT 0 THEN BEGIN
        ; run the LINFIT for this site and report the coeff.
         coeff = LINFIT(zvalarr,biasarr)
         print, "Site coefficients: ", lastSite, coeff
         for prz = 20, 65, 5 do $
            print, "PR_Z, bias: ", prz, coeff[0]+prz*coeff[1]
        ; create, or add coeff to, hash table
         IF site_coeff EQ !null THEN site_coeff = HASH( lastSite, coeff ) $
         ELSE site_coeff[ lastSite ] = coeff
      ENDIF
     ; first record for site, (re)initialize arrays
      zvalarr = REPLICATE(zval,nsamp)
      biasarr = REPLICATE(bias,nsamp)
      lastSite = site
   ENDELSE
   num_read = num_read+1
ENDWHILE

; run the coeffs. for the last site's data
coeff = LINFIT(zvalarr,biasarr)
print, lastSite, coeff
for prz = 20, 65, 5 do print, "PR_Z, bias: ", prz, coeff[0]+prz*coeff[1]
IF site_coeff EQ !null THEN site_coeff = HASH( lastSite, coeff ) $
ELSE site_coeff[ lastSite ] = coeff

SAVE, filename='/data/gpmgv/tmp/KMA_SITE_BIAS_COEFF.sav', site_coeff
help, site_coeff

GOTO, skipto
IO_bailout: PRINT, '***** IO error encountered'
PRINT, !ERROR_STATE.MSG
PRINT, 'finished this many events: ', num_events
skipto: 

END
