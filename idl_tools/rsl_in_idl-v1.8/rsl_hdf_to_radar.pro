; rsl_hdf_to_radar
;
; Reads one volume scan (VOS) from a 1C-51 HDF file and returns data in
; a Radar structure.
;
; Syntax:
;     radar = RSL_HDF_TO_RADAR(filename [, VOS_NUMBER=vosnumber ]
;                 [, /QUIET] [, ERROR=variable])
;
; Inputs:
;     filename: a string containing 1C-51 file name
; 
; Keyword parameters:
;     VOS_NUMBER: number of the VOS to be read from HDF, 1 to nVOS.
;         Default is to read first VOS in HDF file (VOS_NUMBER = 1). 
;     QUIET: Set this keyword to turn off progress reporting.
;     ERROR: Assign a variable to this keyword to have a boolean error status
;         returned.  A value of 1 (true) indicates an error occurred, 0 means
;         no error.
;
; Written by:  Bart Kelley, GMU, January 2002
;
; Based on the Radar Software Library (RSL) by John Merritt of SM&A Corp.,
; and RSL program RSL_hdf_to_radar by Mike Kolander of SSAI.
;***********************************************************************

;***************************;
;   load_headers_from_hdf   ;
;***************************;

pro load_headers_from_hdf, filehandle, vosnumber, sdid, nparms, nbins, radar

; Load header info for selected volume scan (VOS) from HDF into Radar structure.
;
; Inputs:
;     filehandle: file handle returned by call to HDF_OPEN.
;     vosnumber:  number corresponding to the VOS to be accessed.
;     sdid:       SDS ID returned by call to HDF_SD_START.
;     nparms:     number of radar parameters.
;     nbins:      number of bins in a ray.
;     radar:      radar structure (modified by this procedure).
;
; Written by:  Bart Kelley, GMU, January 2002
;***********************************************************************

RSL_SPEED_OF_LIGHT = 299792458.0

vosnum = strtrim(string(vosnumber),1) ; convert vos number to string.

; get info for VOS from volume descriptor.
ref = hdf_vd_find(filehandle, 'Volume_Descriptor' + vosnum)
voldesc = hdf_vd_attach(filehandle,ref)
nread = hdf_vd_read(voldesc, datetime, field='year,month,day,hour,minutes,second')
year = datetime[0]
;print,'YEAR=',year
radar.h.month = datetime[1]
radar.h.day = datetime[2]
radar.h.year = year
radar.h.hour = datetime[3]
radar.h.minute = datetime[4]
radar.h.sec = datetime[5]
radar.h.nvolumes = nparms
nread = hdf_vd_read(voldesc,projname,fi='projectName')
radar.h.project = string(projname)
hdf_vd_detach, voldesc

; get location info from TSDIS product specific metadata.
ref = hdf_vd_find(filehandle,'ArchiveMetadata.0')
metahandle = hdf_vd_attach(filehandle,ref)
nread = hdf_vd_read(metahandle,archivemeta)
radar.h.city = getmetaobject(archivemeta,'RadarCity')
radar.h.state = getmetaobject(archivemeta,'RadarState')
radar.h.country = getmetaobject(archivemeta,'RadarCountry')
hdf_vd_detach, metahandle

; get calibration constant.
ref = hdf_vd_find(filehandle,'Comment' + vosnum)
commenthandle = hdf_vd_attach(filehandle,ref)
nread = hdf_vd_read(commenthandle,comment,fi='commentField')
poszcal = strpos(comment,'-zCal') 
if poszcal eq -1 then message, "Could not find -zCal in Volume Comment"
reads,string(comment(poszcal+6:poszcal+11)),zcal
radar.volume.h.calibr_const = zcal
hdf_vd_detach, commenthandle

ref = hdf_vd_find(filehandle, 'Radar_Descriptor' + vosnum)
rdesc = hdf_vd_attach(filehandle,ref)
nread = hdf_vd_read(rdesc, radarname, field='RadarName')
radar.h.name = string(radarname)
radar.h.radar_name = string(radarname)

nread = hdf_vd_read(rdesc, radlat, field='RadarLatitude')
nread = hdf_vd_read(rdesc, radlon, field='RadarLongitude')
nread = hdf_vd_read(rdesc, radalt, field='RadarAltitude')

latpart = abs(radlat)
sign = fix(radlat/latpart)
radar.h.latd = sign * fix(floor(latpart))
latpart = (latpart - floor(latpart)) * 60.
radar.h.latm = sign * fix(floor(latpart))
latpart = (latpart - floor(latpart)) * 60.
radar.h.lats = sign * fix(round(latpart))

lonpart = abs(radlon)
sign = fix(radlon/lonpart)
radar.h.lond = sign * fix(floor(lonpart))
lonpart = (lonpart - floor(lonpart)) * 60.
radar.h.lonm = sign * fix(floor(lonpart))
lonpart = (lonpart - floor(lonpart)) * 60.
radar.h.lons = sign * fix(round(lonpart))

radar.h.height = fix(radalt * 1000.)

nread = hdf_vd_read(rdesc, beamwidth, fi='HorizontalBeamWith,VerticalBeamWith')
radar.volume.sweep.h.beam_width = beamwidth[0]
radar.volume.sweep.h.horz_half_bw = beamwidth[0] / 2.0
radar.volume.sweep.h.vert_half_bw = beamwidth[1] / 2.0
radar.volume.sweep.ray.h.beam_width = beamwidth[0]
nread = hdf_vd_read(rdesc, frequency, fi='Frequency1')
radar.volume.sweep.ray.h.frequency = frequency
if frequency ne 0 then wavelength = (RSL_SPEED_OF_LIGHT / frequency) * 1.0e-9 $
else wavelength = 0.0
radar.volume.sweep.ray.h.wavelength = wavelength
nread = hdf_vd_read(rdesc, nomscanrate, fi='NominalScanRate')
radar.volume.sweep.ray.h.azim_rate = nomscanrate
radar.volume.sweep.ray.h.sweep_rate = nomscanrate / 6.0
hdf_vd_detach, rdesc

ref = hdf_vd_find(filehandle,'Parameter_Descriptor' + vosnum + '_2')
parmdesc = hdf_vd_attach(filehandle,ref)
nread = hdf_vd_read(parmdesc,pulselength,field='PulseWidth')
radar.volume.sweep.ray.h.pulse_width = pulselength / 300.
hdf_vd_detach, parmdesc

ref = hdf_vd_find(filehandle,'Sweep_Info' + vosnum)
sweepinfo = hdf_vd_attach(filehandle,ref)
nread = hdf_vd_read(sweepinfo, sweepnos, field='SweepNumber')
nread = hdf_vd_read(sweepinfo,nrays,field='numOfRays')
nread = hdf_vd_read(sweepinfo,elev,field='FixedAngle')
hdf_vd_detach, sweepinfo
;print,sweepnos,nrays,elev
nsweeps = n_elements(sweepnos)
; Note: don't have to loop through volume array--IDL's array ops will assign to
; all.
radar.volume.h.nsweeps = nsweeps
radar.volume.sweep.h.sweep_num = sweepnos
radar.volume.sweep.h.elev = elev
radar.volume.sweep.h.nrays = nrays

ref = hdf_vd_find(filehandle,'Cell_Range_Vector' + vosnum + '_2')
rangehandle = hdf_vd_attach(filehandle,ref)
nread=hdf_vd_read(rangehandle, range, field='DistanceToCell')
radar.volume.sweep.ray.h.gate_size = fix(range[2] - range[1])
radar.volume.sweep.ray.h.range_bin1 = fix(range[0] - 0.5 * radar.volume.sweep.ray.h.gate_size)
hdf_vd_detach, rangehandle 

; get ray info

sdindex = hdf_sd_nametoindex(sdid,'Ray_Info_Integer' + vosnum)
datid = hdf_sd_select(sdid,sdindex)
hdf_sd_getdata, datid, rayinfo_int
sdindex = hdf_sd_nametoindex(sdid,'Ray_Info_Float' + vosnum)
datid = hdf_sd_select(sdid,sdindex)
hdf_sd_getdata, datid, rayinfo_flt

prevjday = 0

for i = 0, nsweeps-1 do begin
    radar.volume.sweep[i].ray.h.elev_num = i + 1
    radar.volume.sweep[i].ray.h.nbins = nbins[i]
    radar.volume.sweep[i].ray.h.fix_angle = elev[i]
    for j = 0, nrays[i]-1 do begin
	jday = rayinfo_int[1,j,i]
	if jday ne prevjday then begin
	    date = ymd(jday, year)
	    prevjday = jday
	endif
        radar.volume.sweep[i].ray[j].h.month = date.month
        radar.volume.sweep[i].ray[j].h.day = date.day
        radar.volume.sweep[i].ray[j].h.year = year
        radar.volume.sweep[i].ray[j].h.hour = rayinfo_int[2,j,i]
        radar.volume.sweep[i].ray[j].h.minute = rayinfo_int[3,j,i]
        radar.volume.sweep[i].ray[j].h.sec = float(rayinfo_int[4,j,i]) $
	    + float(rayinfo_int[5,j,i])
        radar.volume.sweep[i].ray[j].h.azimuth = rayinfo_flt[0,j,i]
        radar.volume.sweep[i].ray[j].h.ray_num = j + 1
        radar.volume.sweep[i].ray[j].h.elev = rayinfo_flt[1,j,i]
        radar.volume.sweep[i].ray[j].h.pulse_count = rayinfo_flt[2,j,i]
        prf = fix(rayinfo_flt[3,j,i])
        radar.volume.sweep[i].ray[j].h.prf = prf
        if prf ne 0 then radar.volume.sweep[i].ray[j].h.unam_rng = $
	    RSL_SPEED_OF_LIGHT / (2.0 * prf * 1000.) $
	else radar.volume.sweep[i].ray[j].h.unam_rng = 0.
        radar.volume.sweep[i].ray[j].h.nyq_vel = prf * wavelength / 4.0
    endfor
endfor
end

;***************************;
;    load_data_from_hdf     ;
;***************************;

pro load_data_from_hdf, filehandle, vosnumber, sdid, radar, quiet=quiet

; Load data for selected volume scan (VOS) from HDF into Radar structure.
;
; Inputs:
;     filehandle: file handle returned by call to HDF_OPEN.
;     vosnumber:  number corresponding to the VOS to be accessed.
;     sdid:       SDS ID returned by call to HDF_SD_START.
;     radar:      radar structure (modified by this procedure). 
;
; Written by:  Bart Kelley, GMU, January 2002

; Acknowledgement:
; Code for screening data and computing reflectivity values was adapted from
; RSL's hdf_to_radar.c, written by Mike Kolander of SSAI.
;***********************************************************************

vosnum = strtrim(string(vosnumber),1) ; convert vos number to string.

; Parm_Data contains all data for a particular parameter for the VOS,
; organized in an SDS array dimensioned ncell x nray x nsweep.

; Get QC mask
ref = hdf_vd_find(filehandle,'Parameter_Descriptor' + vosnum + '_1')
parmdesc = hdf_vd_attach(filehandle,ref)
nread = hdf_vd_read(parmdesc,parmname,field='NameOfParm')
hdf_vd_detach, parmdesc
if strpos(string(parmname),'QCMZ') lt 0 then $
    message,'Parameter name is ' + string(parmname) + '.  Expected QCMZ.'
parmdataname = 'Parm_Data1byte' + vosnum + '_1'
sdindex = hdf_sd_nametoindex(sdid,parmdataname)
datid = hdf_sd_select(sdid,sdindex)
hdf_sd_getdata,datid,qcmask

; Get QC data.
parmdataname = 'Parm_Data2byte' + vosnum + '_2'
sdindex = hdf_sd_nametoindex(sdid,parmdataname)
datid = hdf_sd_select(sdid,sdindex)
hdf_sd_getdata,datid,raydata

ref = hdf_vd_find(filehandle,'Parameter_Descriptor' + vosnum + '_2')
parmdesc = hdf_vd_attach(filehandle, ref)
nread = hdf_vd_read(parmdesc, parmname, field='NameOfParm')
nread = hdf_vd_read(parmdesc, no_data, field='DelOrMissingDataFlag')
if strpos(string(parmname),'QCZ') lt 0 then $
    message,'Parameter name is ' + string(parmname) + '.  Expected QCZ.'
nread = hdf_vd_read(parmdesc, offsetfactor, field='OffsetFactor')
nread = hdf_vd_read(parmdesc, scalefactor, field='ScaleFactor')
hdf_vd_detach, parmdesc

DZ=0
CZ=1

radar.volume[DZ].h.field_type = 'DZ'
radar.volume[DZ].h.no_data_flag = no_data
radar.volume[DZ].sweep.h.field_type = 'DZ'

radar.volume[CZ].h.field_type = 'CZ'
radar.volume[CZ].h.no_data_flag = no_data
radar.volume[CZ].sweep.h.field_type = 'CZ'

nsweeps = radar.volume[0].h.nsweeps
nrays = radar.volume[0].sweep.h.nrays
nbins = radar.volume[0].sweep.ray[0].h.nbins
calibr = radar.volume[DZ].h.calibr_const

; Convert data from HDF and store into radar structure

if not keyword_set(quiet) then quiet = 0
if not quiet then print, format='($,/"Loading sweep")'

X = 200. ; used with mask to compute reflectivity.
range=fltarr(n_elements(radar.volume[0].sweep[0].ray[0].range))

for k = 0, nsweeps - 1 do begin
    if not quiet then print, format='($,i4)', k+1
    for j = 0, nrays[k] - 1 do begin
	; Store missing-or-deleted data flags.
        s = where(raydata[*,j,k] eq no_data)
	if size(s,/n_dimensions) gt 0 then range[s] = raydata[s,j,k]
	; Compute Reflectivity (DZ).
        s = where(raydata[*,j,k] ne no_data)
	if size(s,/n_dimensions) gt 0 then $
	   range[s] = ((raydata[s,j,k] - offsetFactor) / scaleFactor) - $
                                       calibr + X * qcmask[s,j,k]
        radar.volume[DZ].sweep[k].ray[j].range = range
	; Compute QC'ed Reflectivity (CZ).
        maskon = where(qcmask[*,j,k] eq 1)
	if size(maskon,/n_dimensions) gt 0 then range[maskon] = no_data
	if size(s,/n_dimensions) gt 0 then maskoff = where(qcmask[s,j,k] eq 0)
	if size(maskoff,/n_dimensions) gt 0 then range[s[maskoff]] = $
		     (raydata[s[maskoff],j,k] - offsetFactor) / scaleFactor
        radar.volume[CZ].sweep[k].ray[j].range = range
    endfor ; rays (j)
endfor ; sweeps (k)
if not quiet then print, "   Done"
end

;***************************;
;      rsl_hdf_to_radar     ;
;***************************;

function rsl_hdf_to_radar, filename, vos_number = vosnumber, quiet=quiet, $
    error=error

; Reads one volume scan (VOS) from a 1C-51 HDF file and returns data in
; a Radar structure.
;
; Syntax:
;     radar = RSL_HDF_TO_RADAR(filename [, VOS_NUMBER=vosnumber ]
;                 [, /QUIET] [, ERROR=variable])
;
; Inputs:
;     filename: a string containing 1C-51 file name
; 
; Keyword parameters:
;     VOS_NUMBER: number of the VOS to be read from HDF, 1 to nVOS.
;         Default is to read first VOS in HDF file (VOS_NUMBER = 1). 
;     QUIET: Set this keyword to turn off progress reporting.
;     ERROR: Assign a variable to this keyword to have a boolean error status
;         returned.  A value of 1 (true) indicates an error occurred reading
;         radar data into the structure; 0 means no error.
;
; Written by:  Bart Kelley, GMU, January 2002
;
; Based on the Radar Software Library (RSL) by John Merritt of SM&A Corp.,
; and RSL program RSL_hdf_to_radar by Mike Kolander of SSAI.
;***********************************************************************

on_error, 2

maxrays = 400
maxbins = 1000
radar =  -1
error = 0

if not keyword_set(vosnumber) then vosnumber = 1
vosnum = strtrim(vosnumber,1) ; convert vos number to string.

work_file = filename
if is_compressed(filename) then work_file = rsl_uncompress(filename)

filehandle = hdf_open(work_file)
if filehandle lt 0 then begin
    message,'hdf_open was unable to open '+work_file,/continue
    goto, finished
endif

; Check for empty granule.
vglone = hdf_vg_lone(filehandle)
vghandle = hdf_vg_attach(filehandle, vglone[0])
hdf_vg_gettrs,vghandle,tag,ref ; get tags and ref numbers for this vgroup
if size(tag,/n_dimensions) eq 0 then if tag eq -1 then begin
    message,filename + ' is empty granule',/informational
    goto, finished
endif

; Get specified VOS
if not keyword_set(quiet) then print, "Accessing VOS ", vosnum

ref = hdf_vd_find(filehandle, 'Radar_Descriptor' + vosnum)
if ref eq 0 then message, 'VOS ' + vosnum + ' does not exist'
rdesc_handle = hdf_vd_attach(filehandle,ref)
nread = hdf_vd_read(rdesc_handle, nparms, fi='NumOfParmDesc')
;print, 'nparms=',nparms
if nparms ne 2 then message, 'nparms = ' + strtrim(nparms,1) + $
    ': expected 2 parameters for 1C-51'
hdf_vd_detach, rdesc_handle

sdid = hdf_sd_start(work_file)

get_dimensions, filehandle, vosnum, nsweeps, nrays, nbins

radar = rsl_new_radar(nparms, nsweeps, maxrays > max(nrays), maxbins > max(nbins))

; Load header information into Radar structure.
load_headers_from_hdf, filehandle, vosnumber, sdid, nparms, nbins, radar

; Load parameter data into Radar structure.
load_data_from_hdf, filehandle, vosnumber, sdid, radar, quiet= quiet

hdf_sd_end, sdid
finished:
if filehandle gt -1 then hdf_close, filehandle
if work_file ne filename then spawn, 'rm ' + work_file

if size(radar,/n_dimensions) eq 0 then error = 1
return, radar
end
