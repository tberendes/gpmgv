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
; 4/2013  Morris GPM GV, SAIC
; - Added PATH keyword parameter to override the copy of 'file' to the working
;   directory.  Instead, copies file to 'path' directory when PATH is set.
; - Defined a nonvarying file name for the file copy in the hope that the disk
;   space management on ds1-gpmgv will be resolved.
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-

function uncomp_file_to_dir, file, new_file, PATH=path

    ; Define some unique, fixed name for the copy.  If path is not given, then
    ; copy the file to the working directory.  If special value 'host_default'
    ; is specified for 'path', then compute the host specific directory within
    ; which to make the file copy.  Otherwise, just make the file copy in the
    ; directory given by 'path' value.
    IF N_ELEMENTS(path) EQ 0 THEN new_base_file = './tEmP_FiLe_cOpY' $
    ELSE BEGIN
       IF PATH EQ 'host_default' THEN BEGIN
          CASE GETENV('HOSTNAME') OF
             'ds1-gpmgv.gsfc.nasa.gov' : tmp_dir = '/data/gpmgv/tmp'
             'ws1-gpmgv.gsfc.nasa.gov' : tmp_dir = '/data/tmp'
             ELSE : BEGIN
                    message, "Unknown system ID, setting tmp_dir to ~/data/tmp", /info
                    tmp_dir = '~/data/tmp'
                    END
          ENDCASE
          message, "Set host-specific tmp_dir : "+tmp_dir, /info
          new_base_file = tmp_dir + '/tEmP_FiLe_cOpY'
       ENDIF ELSE new_base_file = path + '/tEmP_FiLe_cOpY'
    ENDELSE
;
; *** parse the file name to determine the suffix or type (.gz or .Z)
;
    a = strsplit(file,'.',/extract)
    suffix = a(n_elements(a)-1)
;
; *** Deal with file compression state
;
    compressed = 1
    if(suffix ne 'gz' and suffix ne 'Z') then begin ; File is NOT compressed?
        ; check for compression: if compressed, 'gzip -l' output goes to result,
	; else output goes to errout
        command = "gzip -l " + file
        spawn, command, result, errout
        if ( n_elements(errout) eq 2 ) then begin
           if ( strpos(errout[1],'not in gzip') ne -1 ) then begin
	      print, file +" is not compressed."
              compressed = 0
              new_file_suffix = ""
           endif else begin
	      flag = "Can't determine compression state of " + file
	      return, flag
	   endelse
        endif else begin
           if ( n_elements(result) eq 2 ) then begin
              a = strsplit(result[1],' ',/extract)
              if ( a[1] ne -1 ) then begin
                 print, file +" IS gzip compressed, but not named as such!"
                 new_file_suffix = '.gz'
	      endif else begin
	         print, file +" IS unix compressed (.Z), but not named as such!"
                 new_file_suffix = '.Z'
	      endelse
           endif else begin
              flag = 'Unknown error decompressing file: ' + file
              return,flag
           endelse
	endelse
    endif else begin                                ; File is indicated as a compressed file
        new_file_suffix = '.'+suffix
    endelse

;
;   copy the file to new_base_file
;
    clone_copy = new_base_file+new_file_suffix
    FILE_COPY, [file], [clone_copy], /VERBOSE
;    command = 'cp -v ' + file + ' ' + clone_copy
;    spawn,command,exit_status=status
;    if(status ne 0) then begin
;        flag = 'Unable to copy file to: ' + clone_copy
;        return,flag
;    endif

    if (compressed EQ 1) then begin
       command = 'gzip -d ' + clone_copy
       spawn,command,exit_status=status
       if(status ne 0) then begin
           flag = 'Error decompressing file: ' + file
           return,flag
        endif
    endif

    new_file = new_base_file
    flag = 'OK'
    return,flag
    end
