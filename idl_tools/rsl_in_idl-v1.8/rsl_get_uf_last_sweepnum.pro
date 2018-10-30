function rsl_get_uf_last_sweepnum, iunit

; Find sweep number of last sweep in a UF file.

nsweeps = -1

; Save position of file pointer.
point_lun, -iunit, prev_loc

; Get file size.
fs = fstat(iunit)

; Assume Fortran records.  Use last 4 bytes of file to get record size, then
; position to beginning of record and read it.

recsize=0L
buf=intarr(10)
point_lun, iunit, fs.size-4L
readu, iunit, recsize
byteorder, recsize, /lswap, /swap_if_little_endian
if recsize gt 0 and recsize lt fs.size then begin
    point_lun, iunit, fs.size-(recsize+4L)
    readu,iunit,buf
    ; Check for "UF" in first two bytes of record.  If it's there, then our
    ; assumption of Fortran records is correct and we can get the sweep number.
    if string(byte(buf,0,2)) eq 'UF' then begin
	nsweeps = buf[9]
	byteorder, nsweeps, /swap_if_little_endian
	goto, finished
    endif
endif

; If we get here, then these are not Fortran records.  We have to search for
; the beginning of last record.

; Make bufsize that should be large enough to capture last record of file.
; We can take another try if it isn't.

bufsize = 16000L
buf = bytarr(bufsize)

; Put a limit on number of searches.
maxtries = 3

charU = 85b
charF = 70b 
found = 0
itry = 1L
while not found and itry le maxtries do begin
    ; Back up to read into buf, making sure we're not past beginning of file.
    newpos = fs.size - itry*bufsize
    if newpos gt 0 then begin
        point_lun, iunit, newpos
    endif else begin
        nsweeps = -1
	goto, finished
    endelse
    readu, iunit, buf
    ; Find the beginning of the UF record by searching for 'U' followed by 'F'.
    ; We use bufsize-2 as end point because we check buf[i+1].
    for i=0L,bufsize-2 do begin
        if buf[i] eq charU and buf[i+1] eq charF then begin
	    found = 1
	    break
	endif
    endfor
    itry = itry + 1L
endwhile

; If "UF" string was found, get sweep number.
if found then begin
    offset = i + 9*2L
    nsweeps = fix(buf, offset)
    byteorder, nsweeps, /swap_if_little_endian
endif
finished:
point_lun, iunit, prev_loc ; Position to saved location.

; Is nsweeps a reasonable number?
if nsweeps gt 50 or nsweeps lt 1 then nsweeps = -1
return, nsweeps
end
