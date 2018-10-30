function wsr88d_read_tape_header, headerfile

; Return information from WSR-88D header file.

on_error, 2 ; on error, return to caller.

; Structure was adapted from wsr88d.c, written by John Merritt.

headerinfo = {archive2:string(' ',f='(a8)'),$ 
    siteid:string(' ',f='(a4)'),$  
    tape_num:string(' ',f='(a6)'),$
    b1:string(' ',f='(a1)'),$   
    date:string(' ',f='(a9)'),$
    b2:string(' ',f='(a1)'),$   
    time:string(' ',f='(a8)'),$
    b3:string(' ',f='(a1)'),$ 
    data_center:string(' ',f='(a5)'),$
    wban_num:string(' ',f='(a5)'),$
    tape_mode:string(' ',f='(a5)'),$
    volume_num:string(' ',f='(a5)'),$
    b4:string(' ',f='(a6)')$ 
}

openr, iunit, headerfile, /get_lun
filestat = fstat(iunit)
if filestat.size eq 31616 then begin ; it's a tape header
    readu,iunit,headerinfo
    if headerinfo.archive2 ne 'ARCHIVE2' then $
        message,'Header file contents begin: "'+ headerinfo.archive2 + $
	    '".  Valid WSR-88D header begins with "ARCHIVE2"',/inform
endif $
else message,'File size is not 31616 bytes -- is not a valid header.',/inform

free_lun,iunit
return,headerinfo
end
