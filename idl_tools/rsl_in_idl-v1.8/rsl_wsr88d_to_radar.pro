; Copyright (C) 2003  NASA/TRMM Satellite Validation Office
;
; This program is free software; you can redistribute it and/or modify
; it under the terms of the GNU General Public License as published by
; the Free Software Foundation; either version 2 of the License, or
; (at your option) any later version.
;
; This program is distributed in the hope that it will be useful,
; but WITHOUT ANY WARRANTY; without even the implied warranty of
; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
; GNU General Public License for more details.
;
; You should have received a copy of the GNU General Public License
; along with this program; if not, write to the Free Software
; Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
;**************************************************************************
;+
; rsl_wsr88d_to_radar
;
; Read a WSR-88D format file and return data in a Radar structure.
; 
; Syntax:
;     radar = rsl_wsr88d_to_radar(wsr88d_file [, siteid_or_header]
;                 [, /CATCH_ERROR] [, ERROR=variable] [, /KEEP_RADAR]
;                 [, /QUIET])
;
; Inputs:
;     wsr88d_file: name of WSR-88D file.
;     siteID_or_header:
;         a string containing either the 4-character WSR-88D site ID or
;         the name of a WSR-88D header file.  If omitted, program will
;         attempt to get site ID from file name.
;
; Keyword parameters:
;     CATCH_ERROR:
;         Starting with version 1.4, this keyword is set by default.  It
;         initiates an error handler that returns control to the calling
;         program if an error occurs.  Set CATCH_ERROR to 0 to turn off
;         error handler.
;     ERROR:
;         Set this keyword to a variable to return the error status.
;         A value of 1 is returned for error, 0 otherwise.
;     KEEP_RADAR:
;         Set this keyword to return the radar structure if an error
;         occurs.  If an error occurs and this is not set, -1 is returned.
;     QUIET: Set this keyword to turn off progress reporting.
;
; Written by:  Bart Kelley, GMU, January 2003
;
; Based on the RSL program RSL_wsr88d_to_radar by John Merritt of SM&A Corp.
;***********************************************************************
;-

;***************************;
;     read_wsr88d_title     ;
;***************************;

pro read_wsr88d_title, iunit, title_rec

; Read title record and perform byte swapping where needed.

compile_opt hidden

readu, iunit, title_rec
jdate = title_rec.jdate
msec = title_rec.msec
byteorder, jdate, /lswap, /swap_if_little_endian
byteorder, msec, /lswap, /swap_if_little_endian
title_rec.jdate = jdate
title_rec.msec = msec
end

;***************************;
;      read_wsr88d_rec      ;
;***************************;

pro read_wsr88d_rec, iunit, rec

; Read WSR-88D data record and perform integer byte swapping where needed.

compile_opt hidden

readu,iunit,rec
longwords = lonarr(3)
longwords[0] = long(rec(10:11),0)
longwords[1] = long(rec(14:15),0)
longwords[2] = long(rec(30:31),0)
data = rec(64:1215) ; save the data.  don't want to byte-swap it.
byteorder, rec, /sswap, /swap_if_little_endian
byteorder, longwords, /lswap, /swap_if_little_endian
rec[10:11] = fix(longwords(0),0,2)
rec[14:15] = fix(longwords(1),0,2)
rec[30:31] = fix(longwords(2),0,2)
rec[64:1215] = data
end


;***************************;
;  rsl_make_wsr88d_decoder  ;
;***************************;

function rsl_make_wsr88d_decoder, dir

; Attempt to make the wsr88d decoder by spawning "make" in given
; directory. Function returns full pathname of the executable if "make" is
; successful, or the null string ('') otherwise.

cd, dir, current=returndir
spawn,'make', exit_status=status 
if status eq 0 then decoder_path = dir + 'decode_ar2v' else decoder_path  = ''
cd, returndir
return, decoder_path
end

;***************************;
;     open_wsr88d_file      ;
;***************************;

function open_wsr88d_file, wsr88d_file, error

; This function opens the wsr88d file and returns unit number.

iunit = -99
compressed = 0

; If the file is compressed, uncompress it in a temporary file.
spawn, 'file -b ' + wsr88d_file, output
if strpos(output,'gzip') ge 0 then begin
    compressed = 1
    tmpfile = rsl_uncompress(wsr88d_file, error=error)
    if error eq 0 then openr, iunit, tmpfile, /get_lun, /delete
endif else begin
    ; Check for Nexrad/bzip2 compression.
    openr, iunit, wsr88d_file, /get_lun
    buf = bytarr(32)
    readu, iunit, buf
    magic = string(byte(buf,28,2))
    if magic eq 'BZ' then begin
        compressed = 1
        tmpfile = file_basename(wsr88d_file)
        tmpfile = tmpfile + '.' + 'tmp_' + strtrim(randomu(seed,/long),1)
        tmpdir = getenv('IDL_TMPDIR')
        if strmid(tmpdir,strlen(tmpdir)-1) ne '/' then tmpdir = tmpdir + '/'
        tmpfile = tmpdir + tmpfile
        ; Decode the file, writing to a temporary file.
        decoder_basename = 'decode_ar2v'
        ; Look for decoder first in rsl_in_idl directory, then PATH variable.
        dir=file_dirname(file_which('rsl_wsr88d_to_radar.pro'),/mark_directory)
        decoder = dir + 'decode_ar2v/' + decoder_basename
        if not file_test(decoder) then begin
            decoder = file_which(getenv('PATH'), decoder_basename)
        endif
        if not file_test(decoder) then begin
            print,'OPEN_WSR88D_FILE: decoder executable does not exist.'
            print,'Will attempt to make decoder in ' + dir + 'decode_ar2v/:'
            decoder = rsl_make_wsr88d_decoder(dir + 'decode_ar2v/')
            if file_test(decoder) then print, 'Successful.'
        endif
        if file_test(decoder) then begin
            cmd = decoder + ' ' + wsr88d_file + ' ' + tmpfile
            spawn, cmd, out, err
            if file_test(tmpfile) then openr, iunit, tmpfile, /get_lun, /delete
            if strlen(err) gt 0 then begin
                print, 'Message from spawn, "' + cmd + '":'
                print, err
            endif
        endif else begin
            error = 1
            message,"Can't find executable named " + decoder_basename + ".", $
                /informational
        endelse
    endif
endelse

if not compressed and not error then openr, iunit, wsr88d_file, /get_lun

return, iunit
end

;***************************;
;      get_vcp_params       ;
;***************************;

pro get_vcp_params, rec, azim_rate, fix_angle, pulse_width, pulse_count

; This procedure gets parameters dependent on Volume Coverage Pattern.

compile_opt hidden

rsl_speed_of_light = 299792458.0
rda_elev_num = rec[22]
vcp = rec[36]

; The following values are from RSL's wsr88d.c, and were originally provided
; by Dan Austin, formerly of Texas A&M.
; Thanks go to Patrick Gatlin of UAH for parameters for VCPs 211-221.
;
; The contents of these arrays are as follows:
; parms[0]   - VCP number
; parms[1]   - Pulse length
; parms[2-n] - triples consisting of fixed angle, pulse count, and azimuth rate,
;              for each Radar Data Acquisition (RDA) elevation.
;              Note that fixed angle and azimuth rate are encoded values.
;
; For example, for VCP 11 at RDA elevation 1:
;    fixed angle = parms[2] = 88
;    pulse count = parms[3] = 17
;    azimuth rate = parms[4] = 13600
; at RDA elevation 2:
;    fixed angle = parms[5] = 88
;    pulse count = parms[6] = 0
;    azimuth rate = parms[7] = 14000
;
; Code for unpacking these values follows CASE statement below.
;
; Note: two sweeps are made in each of the first two radar tilts in VCP 11 and
; VCP 21: the first for reflectivity, the second for velocity.  This means RDA
; elevation 2 is actually the second sweep of the first radar tilt.  For VCP 31
; and 32, two sweeps are made for the first *three* tilts.

case vcp of
    11: parms=[11,514, 88,17,13600,88,0,14000,264,16,12664,264,0,14000,$
               440,6,11736,608,6,24760,784,6,24760,952,10,12712,$
               1128,10,12720,1368,0,18328,1584,0,18496,1824,0,18512,$
               2184,0,18544,2552,0,18576,3040,0,18640,3552,0,18712]
    12: parms= [12,514,91,15,15401,91,0,18204,164,15,15401,164,0,18204,$
                237,15,15401,237,0,18204,328,3,19297,437,3,20393,564,3,20393,$
		728,3,20393,928,3,20393,1165,0,20680,1456,0,20680,$
		1820,0,21033,2276,0,20929,2840,0,20929,3550,0,20929]
    21: parms=[21,514, 88,28,8256,88,0,8272,264,28,8256,264,0,8272,$
               440,8,7888, 608,8,7888,784,8,8160,1096,12,8160,1800,0,10640,$
	       2656,0,10432, 3552,0,10496]
   121: parms=[121,514,91,11,21336,91,0,21696,91,0,19952,91,0,15584,$
               264,11,21336,264,0,21696,264,0,19952,264,0,15584,437,6,13985,$
	       437,0,19952,437,0,15584,610,6,15729,610,0,19952,610,0,15584,$
	       783,6,11872,783,0,21481,1092,6,14712,1802,0,21481,2658,0,21696,$
	       3550,0,21696]
    31: parms=[31,516, 88,63,3672,88,0,3688,272,63,3672,272,0,3688,$
               456,63,3672,456,0,3688,640,0,3688,816,0,3688]
    32: parms=[32,514, 88,64,3616,88,0,3312,272,64,3616,272,0,3312,$
               456,11,2960,456,0,2960,640,11,2960,816,11,2960]
    211: parms=[211,514, 88,64,13600,88,64,14000,264,16,12664,264,0,14000,$
                440,6,11736,608,6,24760,784,6,24760,952,10,12712,$
                1128,10,12720,1368,0,18328,1584,0,18496,1824,0,18512,$  
                2184,0,18544,2552,0,18576,3040,0,18640,3552,0,18712]
    221: parms=[221,514, 88,64,8256,88,64,8272,264,28,8256,264,0,8272,$
                440,8,7888, 608,8,7888,784,8,8160,1096,12,8160,1800,0,10640,$
                2656,0,10432, 3552,0,10496]
    212: parms=[212,514, 91,15,15401,91,64,18204,164,15,15394,164,64,18204,$
                237,15,15401,237,64,18204,328,0,19399,437,0,19224,564,0,19224,$
                728,0,19224,928,0,20396,1165,0,20396,1456,0,20680,1820,0,21033,$
                2276,0,20929,2840,0,20929,3550,0,20929]
    else: parms=[0,0,0,0,0,0,0,0,0,0,0,0,0,0,  $
                 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,$
                 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,$
                 0,0,0,0,0,0,0,0,0]
endcase

; This code is also based on Dan Austin's in wsr88d.c.

fix_angle =   parms[(3*rda_elev_num)-1]/8.0*180./4096.0
pulse_count = parms[(3*rda_elev_num)]
azim_rate =   parms[(3*rda_elev_num)+1]/8.0*45./4096.0
pulse_width = parms[1]/(rsl_speed_of_light *1e-6)

end

;******************************;
;  load_radar_from_wsr88d_m1   ;
;******************************;

pro load_radar_from_wsr88d_m1, iunit, radar, quiet=quiet

compile_opt hidden

rsl_speed_of_light = 299792458.0
datahdr_start = 28
no_data = radar.volume[0].h.no_data_flag

begin_elev   = 0
intrm_radial = 1
end_elev     = 2
beginvos     = 3
endvos       = 4

sweepindex = intarr(3) ; Current sweep index for each field.
expect_new_elev = 0

; Read data records.

rec = intarr(1216)
endfile = 0
if not keyword_set(quiet) then quiet = 0
if not quiet then print, format='(/$,"Loading sweeps")'

while not endfile do begin
    read_wsr88d_rec, iunit, rec
    radstat = rec[20] ; Get radial status (start/end elevation, start/end vos)
    msgtype = rec[7] and 15
    if msgtype ne 1 then goto, nextrec
    if radstat eq beginvos or radstat eq begin_elev then begin ; new sweep
	sweepnum = rec[22]
	if not quiet then print, format='($,i4)', sweepnum
        expect_new_elev = 0
    endif
    if expect_new_elev then goto, nextrec
    jul2cal, rec[16], month, day, year
    sec = long(rec[14:15],0)/1000.
    hour = fix(sec/3600.)
    minute = fix((sec - hour*3600.)/60.)
    sec = sec - hour*3600. - minute*60.
    vcp = rec[36] ; Volume Coverage Pattern
    case vcp of
	11: sweeprate = 16./5.
	21: sweeprate = 11./6.
	31: sweeprate = 8./10.
	32: sweeprate = 8./10.
	12: sweeprate = 17./4.2
	121:sweeprate = 20./5.5
	else: sweeprate = 0.
    endcase

    ; Load values for individual fields into radar structure.

    for ivol = 0,2 do begin
	; if number of gates for this field is 0, skip to next field 
	if ivol gt 0 then ngates = rec[28] else ngates = rec[27]
	if ngates eq 0 then goto, nextfield
	isweep = sweepindex[ivol]
	iray = radar.volume[ivol].sweep[isweep].h.nrays
	radar.volume[ivol].sweep[isweep].ray[iray].h.month = month
	radar.volume[ivol].sweep[isweep].ray[iray].h.day = day
	radar.volume[ivol].sweep[isweep].ray[iray].h.year = year
	radar.volume[ivol].sweep[isweep].ray[iray].h.hour = hour
	radar.volume[ivol].sweep[isweep].ray[iray].h.minute = minute
	radar.volume[ivol].sweep[isweep].ray[iray].h.sec = sec
	radar.volume[ivol].sweep[isweep].ray[iray].h.ray_num = rec[19] 
	radar.volume[ivol].sweep[isweep].ray[iray].h.sweep_rate = sweeprate
	radar.volume[ivol].sweep[isweep].ray[iray].h.elev_num = sweepnum
	elev =(rec[21]/8.)*(180./4096.)
	radar.volume[ivol].sweep[isweep].ray[iray].h.elev = elev
	radar.volume[ivol].sweep[isweep].ray[iray].h.unam_rng = rec[17]/10.
	if ivol gt 0 then rangeptr = 24 else rangeptr = 23
	radar.volume[ivol].sweep[isweep].ray[iray].h.range_bin1 = rec[rangeptr]
	radar.volume[ivol].sweep[isweep].ray[iray].h.gate_size = rec[rangeptr+2]
	azimuth = (rec[18]/8.)*(180./4096.)
	if azimuth lt 0. then azimuth = azimuth + 360. 
	radar.volume[ivol].sweep[isweep].ray[iray].h.azimuth = azimuth
	radar.volume[ivol].sweep[isweep].ray[iray].h.beam_width = .95
	radar.volume[ivol].sweep[isweep].ray[iray].h.nbins = ngates
	prf = rsl_speed_of_light /(2.*rec[17]*100.)
	radar.volume[ivol].sweep[isweep].ray[iray].h.prf = round(prf)
	nyq_vel = rec[44]/100.
	radar.volume[ivol].sweep[isweep].ray[iray].h.nyq_vel = nyq_vel 
	; code for wavelength and frequency is from RSL's wsr88d.c
	if prf eq 0. or nyq_vel eq 0. then wavelength = .1 $
	else wavelength = 4.* nyq_vel / prf
	radar.volume[ivol].sweep[isweep].ray[iray].h.wavelength = wavelength
	radar.volume[ivol].sweep[isweep].ray[iray].h.frequency = $
	    rsl_speed_of_light / wavelength * 1e-9
	get_vcp_params, rec, azim_rate, fix_angle, pulse_width, pulse_count
	radar.volume[ivol].sweep[isweep].ray[iray].h.azim_rate = azim_rate 
	radar.volume[ivol].sweep[isweep].ray[iray].h.fix_angle = fix_angle
	radar.volume[ivol].sweep[isweep].ray[iray].h.pulse_count = pulse_count 
	radar.volume[ivol].sweep[isweep].ray[iray].h.pulse_width = pulse_width 
	; get the data.
	velrescode = rec[35]
	dataptr = rec[ivol+32]
	data = byte(rec,datahdr_start+dataptr,ngates)
	s = where(data eq 0 or data eq 1)
	range  =  fltarr(ngates)
	if size(s,/n_dimensions) gt 0 then range[s] = no_data
	s = where(data gt 1)
	if size(s,/n_dimensions) gt 0 then $
	    if ivol eq 0 then range[s] = (float(data[s])-2.)/2.-32. $
	    else if ivol eq 2 then range[s] = (float(data[s])-2.)/2.-63.5 $
	    else if velrescode eq 2 then range[s] = (float(data[s])-2.)/2.-63.5 $
	    else range[s] = (float(data[s])-2.)/2.-127.
	radar.volume[ivol].sweep[isweep].ray[iray].range[0:ngates-1] = range
	radar.volume[ivol].sweep[isweep].h.nrays = iray + 1
	case velrescode of
	    2: velres = 0.5
	    4: velres = 1.0
	else: velres = 0.
	endcase
	radar.volume[ivol].sweep[isweep].ray[iray].h.vel_res = velres
    nextfield:
    endfor
    if radstat eq end_elev or radstat eq endvos then begin
	load_sweep_info_wsr88d, sweepindex, sweepnum, radar
	for ivol = 0,n_elements(sweepindex)-1 do begin
	    if radar.volume[ivol].sweep[sweepindex[ivol]].h.nrays ne 0 then $
	        sweepindex[ivol] = sweepindex[ivol] + 1
        endfor
        expect_new_elev = 1
    endif
    if radstat eq endvos then endfile = 1
nextrec: if eof(iunit) then endfile = 1
endwhile ; while not endfile

radar.h.vcp = vcp
if vcp gt 399 then begin
    print,format='(/"Warning: Unknown VCP =",i)',vcp
    radar.h.vcp = 0
endif
if not quiet then print ; Print newline at end of sweep numbers list.
end

;****************************;
;  load_headers_from_wsr88d  ;
;****************************;

pro load_headers_from_wsr88d, radar, siteinfo

compile_opt hidden

radar.h.number = siteinfo.sitenum
radar.h.name =   siteinfo.siteid
radar.h.radar_name = siteinfo.siteid
radar.h.city =   siteinfo.city
radar.h.state =  siteinfo.state
; If lat/lon degrees are negative, so are minutes and seconds.
if siteinfo.latd lt 0 then begin
    siteinfo.latm = -1 * abs(siteinfo.latm)
    siteinfo.lats = -1 * abs(siteinfo.lats)
endif
if siteinfo.lond lt 0 then begin
    siteinfo.lonm = -1 * abs(siteinfo.lonm)
    siteinfo.lons = -1 * abs(siteinfo.lons)
endif
radar.h.latd =   siteinfo.latd
radar.h.latm =   siteinfo.latm
radar.h.lats =   siteinfo.lats
radar.h.lond =   siteinfo.lond
radar.h.lonm =   siteinfo.lonm
radar.h.lons =   siteinfo.lons
radar.h.height = siteinfo.height
; Short and long pulse values are from RSL wsr88d_get_site.c.
radar.h.spulse = 1530
radar.h.lpulse = 4630 
radar.h.month =  radar.volume[0].sweep[0].ray[0].h.month
radar.h.day =    radar.volume[0].sweep[0].ray[0].h.day
radar.h.year =   radar.volume[0].sweep[0].ray[0].h.year
radar.h.hour =   radar.volume[0].sweep[0].ray[0].h.hour
radar.h.minute = radar.volume[0].sweep[0].ray[0].h.minute
radar.h.sec =    radar.volume[0].sweep[0].ray[0].h.sec
radar.h.radar_type = 'wsr88d'
radar.h.scan_mode = 'PPI'
end

;***************************;
;  load_sweep_info_wsr88d   ;
;***************************;

pro load_sweep_info_wsr88d, sweepindex, sweepnum, radar

compile_opt hidden

for ivol = 0, radar.h.nvolumes-1 do begin
    isweep = sweepindex[ivol]
    nrays = radar.volume[ivol].sweep[isweep].h.nrays
    if nrays gt 0 then begin
	nsweeps = radar.volume[ivol].h.nsweeps
	radar.volume[ivol].h.nsweeps = nsweeps + 1
	radar.volume[ivol].sweep[isweep].h.sweep_num = sweepnum
	s = where(radar.volume[ivol].sweep[isweep].ray.h.azimuth ne -99999.)
	;; NOTE: maybe use fixed angle instead of average angle.
	elev = total(radar.volume[ivol].sweep[isweep].ray[s].h.elev)/nrays
	radar.volume[ivol].sweep[isweep].h.elev = elev
    endif
endfor
beamwidth = radar.volume[0].sweep[isweep].ray[0].h.beam_width
radar.volume.sweep[isweep].h.beam_width = beamwidth
radar.volume.sweep[isweep].h.vert_half_bw = beamwidth  / 2.
radar.volume.sweep[isweep].h.horz_half_bw = beamwidth  / 2.
end

;***************************;
;    rsl_wsr88d_to_radar    ;
;***************************;

function rsl_wsr88d_to_radar, wsr88d_file, siteid_or_header, quiet=quiet, $
    error=error, catch_error=catch_error, keep_radar=keep_radar, _extra=extra

; Read a WSR-88D format file and return data in a Radar structure.

maxsweeps = 20
maxrays = 400
maxbins = 1000
nfields = 3

radar = -1
error = 0

; Set up error handler to be used with keyword CATCH_ERROR. If CATCH_ERROR
; is 0, the error handler is canceled.

if n_elements(catch_error) eq 0 then catch_error = 1
if n_elements(keep_radar) eq 0 then keep_radar = 0

catch, errcode ; Error handler begins here.
if errcode ne 0 then begin
    catch, /cancel
    print,!error_state.msg_prefix+!error_state.msg
    if !error_state.sys_msg ne '' then print, '  '+!error_state.sys_msg
    error = 1
    if not keep_radar then radar = -1
    goto, finished
endif

if not catch_error then catch, /cancel ; Cancel error handler.
; Get information for the radar header based on site ID.  siteid argument can be
; true 4 character site id or name of a WSR-88D header file.  if header file is
; given, site id will be read from it.  if siteid is omitted, program will
; attempt to get it from wsr88d file name.

; I store filename in a string array and use the first element of array for
; passing it to other routines.  This way filename string is passed by value.

filename = [wsr88d_file, '']

if n_elements(siteid_or_header) eq 0 then sitename = filename[0] $
else if strlen(siteid_or_header) gt 4 then begin
    wsr88d_header = wsr88d_read_tape_header(siteid_or_header)
    sitename = wsr88d_header.siteid
endif else sitename = siteid_or_header

siteinfo = wsr88d_get_site_info(sitename)
if size(siteinfo,/tname) ne 'STRUCT' then goto, finished

iunit = open_wsr88d_file(wsr88d_file, error)
if error or iunit lt 0 then goto, finished

; Read Archive II header (first 24 bytes of file).  Use version number to
; determine the expected data message type.  Message type 1 is legacy format,
; 31 is Build 10 or greater.

title_rec = {archive_filename:bytarr(12),jdate:0L,msec:0L,unused:0L}
read_wsr88d_title, iunit, title_rec
version = string(title_rec.archive_filename[0:7])
vnum = 0
if strcmp(version,'AR2V',4) then begin
    reads, version, vnum, format='(4x,I4)'
    if vnum gt 1 then expected_msgtype = 31 else expected_msgtype = 1
endif $
else if version eq 'ARCHIVE2' then expected_msgtype = 1 $
else begin
    message,'Unknown Level 2 volume identifier: ' + version, /informational
    goto, finished
endelse

; Dualpol implementation began with version 6.
if vnum gt 5 then dualpol = 1 else dualpol = 0

; Call jul2cal here to avoid compiler message interfering with job report.
jul2cal, 0

; Select routine for loading radar structure depending on expected data
; message type.
			
if expected_msgtype eq 31 then begin
    load_radar_from_wsr88d_m31, iunit, radar, quiet=quiet, error=error, $
	dualpol=dualpol, _extra=extra
endif else begin
    radar = rsl_new_radar(nfields, maxsweeps, maxrays, maxbins)
    radar.h.nvolumes = nfields
    radar.volume.h.no_data_flag = -32767.
    load_radar_from_wsr88d_m1, iunit, radar, quiet=quiet
    radar.volume.h.field_type = ['DZ','VR','SW']
    radar.volume[0].sweep.h.field_type = 'DZ'
    radar.volume[1].sweep.h.field_type = 'VR'
    radar.volume[2].sweep.h.field_type = 'SW'
endelse

if not error then load_headers_from_wsr88d, radar, siteinfo

finished:
if n_elements(iunit) ne 0 then if iunit gt 0 then free_lun, iunit
if size(radar,/n_dimensions) eq 0 then error = 1
if error then begin
    print, 'Error occurred while processing ' + wsr88d_file + '.'
    if not keep_radar then radar = -1
endif

return, radar
end
