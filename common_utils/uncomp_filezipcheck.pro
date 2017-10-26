	function uncomp_file,file,new_file
; **************************************************************
; * This routine performs the following functions:             *
; * 1) Copies the file to the current directory: ./            *
; * 2) Determines if it is a compressed file by checking its   *
; *    suffix.                                                 *
; * 3) If it is not compressed, returns the filename in pwd    *
; * 4) It if is compressed, it uncompresses it and then        *
; *    returns the filename in the pwd.                        *
; **************************************************************
; * Function written by: David B. Wolff, NASA/GSFC/912.1, SSAI *
; **************************************************************
;
; *** First, copy the file to pwd
;
    command = 'cp ' + file + ' ./'
    spawn,command,exit_status=status
    if(status ne 0) then begin
        flag = 'Unable to copy file to pwd: ' + file
        return,flag
    endif

    a = strsplit(file,'/',/extract)
    new_file = a(n_elements(a)-1)
;
; *** Now parse the file name to determine the suffix or type (.gz or .Z)
;
    a = strsplit(new_file,'.',/extract)
    suffix = a(n_elements(a)-1)
;
; *** Deal with file
;
    if(suffix ne 'gz' and suffix ne 'Z') then begin ; File is NOT compressed??
;        flag = 'File is NOT a compressed file.'
;       return,flag
       command = "gzip -l " + new_file
       spawn, command, result, errout
       a = strsplit(result[1],' ',/extract)
       if ( a[1] ne -1 ) then begin
          print, new_file +" IS compressed, but not named as such!"
          command = 'mv ' + new_file + ' ' + new_file + '.gz'
          spawn,command,exit_status=status
          command = 'gzip -fd ' + new_file + '.gz'
          spawn,command,exit_status=status
          if(status ne 0) then begin
              flag = 'Error decompressing file: ' + file
              return,flag
          endif
       endif
    endif else begin                                ; File is a compressed file
        command = 'gzip -fd ' + new_file
        spawn,command,exit_status=status
        if(status ne 0) then begin
            flag = 'Error decompressing file: ' + file
            return,flag
        endif
        new_file = strjoin(a(0:n_elements(a)-2),'.')
;        print,new_file
    endelse

    flag = 'OK'
    return,flag
    end

