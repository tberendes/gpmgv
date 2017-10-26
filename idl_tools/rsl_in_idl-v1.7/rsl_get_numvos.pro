function rsl_get_numvos, filename

; This function returns the number of volume scans in a TRMM GV HDF file.
; In the event of an error, function returns -1.

deletefile = 0
nvos = -1
tmpfile = filename
if is_compressed(filename[0]) then begin
    tmpfile = rsl_uncompress(filename[0])
    ; next line is a safeguard--we wouldn't want to delete a data file.
    if tmpfile eq filename then message, 'Temporary file name returned by'+$
        ' rsl_uncompress is same as original: ' + tmpfile
    deletefile = 1
endif

filehandle = hdf_open(tmpfile)
if filehandle lt 0 then begin
    message,'hdf_open was unable to open '+tmpfile,/continue
    goto, finished
endif
ref = hdf_vd_find(filehandle,'ArchiveMetadata.0')
metahandle = hdf_vd_attach(filehandle,ref)
nread = hdf_vd_read(metahandle,archivemeta)
nvos = getmetaobject(archivemeta,'NumberOfVOS')
hdf_vd_detach, metahandle
hdf_close, filehandle
finished:
if deletefile then spawn,'rm ' + tmpfile
return, long(nvos)
end
