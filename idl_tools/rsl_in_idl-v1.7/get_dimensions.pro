function isnum, value

; Return true if value is an ASCII number.

return, value gt 47 and value lt 58
end

;---------------------------------------------------------------

pro getbins, comment, nbins

; Read through VOS Comment to get number of bins in a ray for each sweep.
;
; Input:
;    comment: comment string for the VOS.
;
; Output
;    nbins:   an array containing the number of bins in a ray for each sweep.
;
; Written by:  Bart Kelley, GMU, January 2002
;

nsweeps = 0
ncells = 0

pos = strpos(comment,'nSweep=')
if pos gt -1 then begin
    pos = pos + 7
    len = 0
    while isnum(comment(pos+len)) do len = len + 1
    reads, string(comment(pos:pos+len-1)),nsweeps
endif else goto, error

nbins = intarr(nsweeps)

for isweep = 0, nsweeps-1 do begin
    for i = 0, 1 do begin
        ncellprev = ncells
	pos = strpos(comment,'nCell_parm',pos)
	if pos gt -1 then begin
            pos = pos + 14 ; skip past "nCell_parm[n]="
	    len = 0
	    while isnum(comment(pos+len)) do len = len + 1
	    reads, string(comment(pos:pos+len-1)),ncells
	endif else goto, error
    endfor
    if ncellprev ne ncells then begin
        print, "Error (getbins): Number of bins are different between two"
	print, "parameters in same VOS.  Should be the same."
	print, "nbins previous parameter =",ncellprev
	print, "nbins this parameter =    ",ncells
	goto, error
    endif
    nbins[isweep] = ncells
endfor
return
error: message, 'VOS comment did not contain expected information'
end

;---------------------------------------------------------------

pro get_dimensions, filehandle, vosnum, nsweeps, nrays, nbins

; Get dimensions for Radar structure.
;
; Inputs:
;     filehandle: file handle returned by call to HDF_OPEN.
;     vosnum: string containing number of this VOS within HDF.
;
; Outputs:
;     nsweeps: number of sweeps in VOS.
;     nrays: an array of size Nsweeps containing the number of rays in each
;            sweep of VOS.
;     nbins: an array of size Nsweeps containing the number of bins per ray for
;            each sweep of VOS.

ref = hdf_vd_find(filehandle,'Sweep_Info' + vosnum)
sweepinfo = hdf_vd_attach(filehandle,ref)
nread = hdf_vd_read(sweepinfo, sweepnos, field='SweepNumber')
nread = hdf_vd_read(sweepinfo,nrays,field='numOfRays')
nsweeps = n_elements(sweepnos)
hdf_vd_detach, sweepinfo

ref = hdf_vd_find(filehandle,'Comment' + vosnum)
commenthandle = hdf_vd_attach(filehandle,ref)
nread = hdf_vd_read(commenthandle,comment,fi='commentField')
getbins, comment, nbins
hdf_vd_detach, commenthandle

end
