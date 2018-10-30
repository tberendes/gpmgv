function get_parmnames_hdf, filename

; This function returns a string array containing the names of radar parameters
; in the given TRMM GV HDF file.
;
; Written by:  Bart Kelley, GMU, May 2002

filehandle = hdf_open(filename)
vosnum='1'
; get number of parameters
ref = hdf_vd_find(filehandle, 'Radar_Descriptor' + vosnum)
if ref eq 0 then message, 'VOS ' + vosnum + ' does not exist'
raddesc = hdf_vd_attach(filehandle,ref)
nread = hdf_vd_read(raddesc, nparms, fi='NumOfParmDesc')
;print, 'nparms=',nparms
parmnames = strarr(nparms)
hdf_vd_detach, raddesc

for i = 1, nparms do begin
    ref = hdf_vd_find(filehandle,'Parameter_Descriptor' + vosnum + $
       string(i, format='("_",i0)'))
    parmdesc = hdf_vd_attach(filehandle,ref)
    nread = hdf_vd_read(parmdesc,parmname,field='NameOfParm')
    parmnames[i-1] = string(parmname)
    hdf_vd_detach, parmdesc
endfor

hdf_close, filehandle
return, parmnames
end
