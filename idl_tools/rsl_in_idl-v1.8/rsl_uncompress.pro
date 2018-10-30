function rsl_uncompress, infile, error=error

; This function takes a compressed input file and writes an uncompressed copy
; into the current directory, leaving the original file untouched.  A unique
; file name extension is added to the name of the new file to distinguish it
; from the original.  The function returns the name of this new file.  It is
; left to the calling procedure to dispose of the new file when finished.
;
; Note: this function uses 'gzip' to uncompress the file. If not installed on
; your machine, it is available at http://www.gnu.org'
;
; Syntax:
;     newfile = rsl_uncompress(compressed_file [, error=variable])
;
; Inputs:
;     compressed_file: name of compressed file.
;
; Keyword parameters:
;     ERROR: Assign a variable to this keyword to have a boolean error status
;            returned.  Returns 1 (true) for error, 0 (false) for no error.
;
; Written by:  Bart Kelley, GMU, August 2002
;
; Based on uncomp_uf_file by David B. Wolff
;***************************************************************************

badfile = -1
error = 0

; Make new file name.  Begin by stripping off path name.

newfile = strmid(infile,strpos(infile,'/',/reverse_search)+1)

; If file name extension indicates compressed file, strip it off.  Add unique
; file name extension containing a pseudo-random number to the new file name.

extnbegin = strpos(newfile,'.',/reverse_search)
fnamextn = strmid(newfile, extnbegin)
if fnamextn eq '.gz' or fnamextn eq '.z' or fnamextn eq '.Z' then $
    newfile = strmid(newfile, 0, extnbegin)
newfile = newfile + '.' + strtrim(long(randomu(seed)*100000.),1) + '_tmp'

tmpdir = getenv('IDL_TMPDIR')
newfile = tmpdir + newfile

; The following should never happen.
if newfile eq infile then begin
    message, 'Temporary file has same name as input: ' + newfile, /continue
    newfile = badfile
    error = 1
    goto, finished
endif

; Uncompress the input file, writing the result to a new file.

spawn, 'gzip -d -c -f ' + infile + '>' + newfile, stdout, errout
if size(errout,/n_dimensions) ne 0 then begin
    message, errout[0], /continue
    if n_elements(errout) gt 1 then $
        for i=1,n_elements(errout)-1 do print,'  ' + errout[i]
    error = 1
endif

finished: return, newfile
end
