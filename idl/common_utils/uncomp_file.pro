;+
; Copyright © 2008, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; ****************************************************************
; * This routine performs the following functions:               *
; * 1) Copies the file to new name in the current directory: ./  *
; * 2) Determines if it is a compressed file by checking its     *
; *    suffix (if present) or its gzip status.                   *
; * 3) If it is not compressed, returns the filename in pwd      *
; * 4) It if is compressed, it uncompresses it and then          *
; *    returns the filename in the pwd.                          *
; ****************************************************************
; * Function written by: David B. Wolff, NASA/GSFC/912.1, SSAI   *
; * Modified by:         Bob Morris, NASA/GSFC/422.0, SAIC       *
; ****************************************************************
;
; HISTORY
; 04/21/2014 by Bob Morris GPM/GV/SAIC
; - Added VERBOSE keyword parameter put routine diagnostic messages under its
;   control.
; 03/10/2016 by Bob Morris GPM/GV/SAIC
; - Replaced TABs with spaces in file text.
; 11/29/16 by Bob Morris GPM/GV/SAIC
; - Added NOCOPY option to uncompress original file in place without making
;   a copy, returning uncompressed file pathname in new_file parameter.
;
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-

function uncomp_file, file, new_file, NOCOPY=nocopy, VERBOSE=verbose

    if KEYWORD_SET(nocopy) then begin
;      take the existing file pathname
       new_base_file = file
    endif else begin
;      copy the existing file to a unique new name
       newbaseprefix='tEmP_FiLe.'       ; some unique name
       new_base_file = newbaseprefix + FILE_BASENAME( file )
;
;      copy the original file to pwd/new_base_file
;
       command = 'cp ' + file + ' ./' + new_base_file
       spawn,command,exit_status=status
       if(status ne 0) then begin
           cd, CURRENT=c
           IF KEYWORD_SET(verbose) THEN print, "Copying to working directory:", c
           flag = 'Unable to copy file to pwd: ' + file
           return,flag
       endif
    endelse
;
; *** Now parse the file name to determine the suffix or type (.gz or .Z)
;
    a = strsplit(new_base_file,'.',/extract)
    suffix = a(n_elements(a)-1)
;
; *** Deal with file
;
    if(suffix ne 'gz' and suffix ne 'Z') then begin ; File is NOT compressed?
        new_file = new_base_file
        ; check for compression: if compressed, 'gzip -l' output goes to result,
        ; else output goes to errout
        command = "gzip -l " + new_file
        spawn, command, result, errout
        if ( n_elements(errout) eq 2 ) then begin
           if ( strpos(errout[1],'not in gzip') ne -1 ) then begin
              IF KEYWORD_SET(verbose) THEN print, file +" is not compressed."
           endif else begin
              flag = "Can't determine compression state of " + file
              return, flag
           endelse
        endif else begin
           if ( n_elements(result) eq 2 ) then begin
              a = strsplit(result[1],' ',/extract)
              if ( a[1] ne -1 ) then begin
                 print, file +" IS gzip compressed, but not named as such!"
                 zip_file = new_file + '.gz'
              endif else begin
                 print, file +" IS unix compressed (.Z), but not named as such!"
                 zip_file = new_file + '.Z'
              endelse
              command = 'mv -v ' + new_file + ' ' + zip_file
              spawn,command,exit_status=status
              command = 'gzip -fd ' + zip_file
              spawn,command,exit_status=status
              if(status ne 0) then begin
                  flag = 'Error decompressing file: ' + file
                  return,flag
              endif
           endif else begin
              flag = 'Unknown error decompressing file: ' + file
              return,flag
           endelse
        endelse
    endif else begin
;       Filename extension indicates compressed file
        command = 'gzip -fd ' + new_base_file
        spawn,command,exit_status=status
        if(status ne 0) then begin
            flag = 'Error decompressing file: ' + file
            return,flag
        endif
;       recompose the returned pathname without the .gz or .Z extension
        new_file = strjoin(a(0:n_elements(a)-2),'.')
        IF KEYWORD_SET(verbose) THEN message, "Decompressed file: "+new_file, /INFO
    endelse

    flag = 'OK'
    return,flag
    end
