pro struct_fortran2idl, infile, BATDIR=batdir

; reformats PPS TKIO FORTRAN structure definitions in a text file to IDL structures
if n_elements(infile) eq 0 then begin
   filters = ['structs*.txt']
   infile = dialog_pickfile(FILTER=filters, TITLE='Select control file to read', $
       PATH='/home/morris/swdev/idl/dev/product_structs')
   IF (infile EQ '') THEN GOTO, userQuit
endif

IF N_ELEMENTS(batdir) NE 0 THEN BEGIN
   ; want to write out a .bat file with the structure definition commands
   IF batdir EQ '.' THEN outdir=FILE_DIRNAME(infile) ELSE outdir=batdir
   batfile=FILE_BASENAME(infile)
   txtpos = STRPOS(batfile, '.txt')
   IF txtpos EQ -1 THEN message, "no .txt extension on input file: "+infile
   batfile = outdir + '/' + STRMID(batfile, 0, txtpos) + '.bat'
   print, "batfile = ", batfile
   writebat=1
ENDIF ELSE writebat=0

OPENR, lun0, infile, ERROR=err, /GET_LUN
line=''
started=0
; read the entire file and build up a single array of 'words'
WHILE NOT (EOF(lun0)) DO BEGIN 
   READF, lun0, line
   parsed1=STRSPLIT( line, /extract )
   IF (started) THEN parsed=[parsed,parsed1] ELSE parsed=[parsed1]
   started=1
ENDWHILE
CLOSE, lun0
;print, parsed

IF (writebat) THEN OPENW, batunit, batfile, /GET_LUN

   FOR iword=0, N_ELEMENTS(parsed)-1 DO BEGIN
      CASE parsed[iword] OF
         "STRUCTURE" : BEGIN
                     ; it is the beginning of a structure definition, grab the name
                     posSlash = STRPOS(parsed[iword+1], '/')
                     nchars = StrPOS(parsed[iword+1], '/', /REVERSE_SEARCH) - posSlash - 1
                     sname = STRMID(parsed[iword+1], posSlash+1, nchars)
                     print, sname+' = { '+sname+', $'
                     IF (writebat) THEN printf, batunit, sname+' = { '+sname+', $'
                     iword = iword+1
                     goto, noPrint
                  END
         "BYTE" : BEGIN
                     idltype='0b'
                     idlarrtype='BYTARR'
                     nextWord = iword+1
                  END
         "CHARACTER" : BEGIN
                     idltype='0b'
                     idlarrtype='BYTARR'
                     nextWord = iword+1
                  END
         "INTEGER*2" : BEGIN
                     idltype='0'
                     idlarrtype='INTARR'
                     nextWord = iword+1
                  END
         "INTEGER*4" : BEGIN
                     idltype='0l'
                     idlarrtype='LONARR'
                     nextWord = iword+1
                  END
         "REAL*4" : BEGIN
                     idltype='0.0'
                     idlarrtype='FLTARR'
                     nextWord = iword+1
                  END
         "REAL*8" : BEGIN
                     idltype='0.0d'
                     idlarrtype='DBLARR'
                     nextWord = iword+1
                  END
         "RECORD" : BEGIN
                     idltype = STRMID(parsed[iword+1], 1, STRLEN(parsed[iword+1])-2)
                     parsed[iword+1] = parsed[iword+2]
                     nextWord = iword+2
                  END
          "END" : BEGIN
                     ; it is the end of a structure definition
                     print, ' }' & print, ""
                     IF (writebat) THEN BEGIN
                        printf, batunit, ' }'
                        printf, batunit, ""
                     ENDIF
                     iword = iword+1
                     GOTO, noPrint
                  END
         ELSE : message, "Undefined FORTRAN type: "+parsed[iword]
      ENDCASE
      IF parsed[nextWord+1] NE 'END' THEN tail = ', $' ELSE tail = ' $'
;      print, 'tail: ', tail
      posOpenParen = STRPOS( parsed[iword+1], "(" )
      IF posOpenParen EQ -1 THEN BEGIN
         print, "  ", parsed[iword+1], " : ", idltype, tail
         IF (writebat) THEN printf, batunit, "  ", parsed[iword+1], " : ", idltype, tail
      ENDIF ELSE BEGIN
         dims = STRMID(parsed[iword+1], posOpenParen+1, $
                       STRLEN(parsed[iword+1])-posOpenParen-2)
         name = STRMID(parsed[iword+1], 0, posOpenParen)
         print, "  ", name, " : ", idlarrtype+"("+dims+")", tail
         IF (writebat) THEN printf, batunit, "  ", name, " : ", idlarrtype+"("+dims+")", tail
      ENDELSE
      iword = nextWord
      noPrint:
   ENDFOR

IF (writebat) THEN BEGIN
   CLOSE, batunit
   command = 'ls -al '+batfile
   SPAWN, command, results, errout
   print, results
ENDIF

userQuit:
END
