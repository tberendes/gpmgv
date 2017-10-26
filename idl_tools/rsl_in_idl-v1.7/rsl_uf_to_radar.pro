; Copyright (C) 2002-2003  NASA/TRMM Satellite Validation Office
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
; rsl_uf_to_radar
;
; Reads a Universal Format file and returns data in a Radar structure.
;
; Syntax:
;     radar = rsl_uf_to_radar(uf_file [, ERROR=variable]
;             [, FIELDS=string_array] [, MAXSWEEPS=integer] [, /CATCH_ERROR]
;             [, /KEEP_RADAR] [, /QUIET])
;    
;
; Inputs:
;     uf_file: UF file name
;
; Keyword parameters:
;     CATCH_ERROR:
;         Starting with version 1.4, this keyword is set by default.  If
;         an error occurs, control is returned to the calling program.
;         Set CATCH_ERROR to 0 to turn off error handler.
;     ERROR:
;         Assign a variable to this keyword to have a boolean error status
;         returned.  A value of 1 (true) means an error occurred,
;         0 means no error.
;     FIELDS:
;         String scalar or array containing fields to be processed.
;         Default: all fields.  Fields are in the form of the 2-character names
;         used by RSL and UF, such as 'DZ', 'VR', etc.
;     KEEP_RADAR:
;         Set this keyword to return the radar structure if an error
;         occurs.  If an error occurs and this is not set, function returns -1.
;     MAXBINS:
;         Maximum number of bins for rays in radar structure.
;     MAXSWEEPS:
;         Maximum number of sweeps to read.
;     QUIET:
;         Set this keyword to turn off progress reporting.
;
; Written by:  Bart Kelley, GMU, May 2002
;
; Based on the RSL program RSL_uf_to_radar by John Merritt of SM&A Corp.
;-
;***********************************************************************

;******************************;
;   load_radar_header_from_uf  ;
;******************************;

pro load_radar_header_from_uf, buf, radar

compile_opt hidden

radar.h.month = buf[26]
radar.h.day = buf[27]
year = buf[25]
; handle 2-digit years.
if year lt 1900 then $
    if year lt 80 then year = year + 2000 else year = year + 1900
radar.h.year = year
radar.h.hour = buf[28]
radar.h.minute = buf[29]
radar.h.sec = buf[30]
radar.h.radar_type = 'uf'
radar.h.radar_name=string(byte(buf[10:13],0,8))
radar.h.nvolumes=buf[buf[4]-1]
radar.h.latd = buf[18]
radar.h.latm = buf[19]
radar.h.lats = round(buf[20]/64.)
radar.h.lond = buf[21]
radar.h.lonm = buf[22]
radar.h.lons = round(buf[23]/64.)
radar.h.height = buf[24]
scan_mode = buf[34]
if scan_mode eq 1 then radar.h.scan_mode = 'PPI' $
else if scan_mode eq 3 then radar.h.scan_mode = 'RHI' $
else if scan_mode eq 6 then radar.h.scan_mode = 'Manual' 
end

;***************************;
;      load_ray_from_uf     ;
;***************************;

pro load_ray_from_uf, buf, iswp, radar, select_fields

compile_opt hidden

rsl_speed_of_light = 299792458.0
no_data_flag = radar.volume[0].h.no_data_flag

datahdr_start = buf[4]-1
nfields = buf[datahdr_start]
if nfields gt radar.h.nvolumes then message, string($
    f='("number of fields this record is greater than allocated for ' + $
    'radar structure.  nfields =",i4,", radar.h.nvolumes =",i4)', nfields,$
    radar.h.nvolumes)

year = buf[25]

; Handle 2-digit years.
if year lt 1900 then $
    if year lt 80 then year = year + 2000 else year = year + 1900

; Get data for each field.

fieldnames = radar.volume.h.field_type
check_field = 0
if n_elements(select_fields) gt 0 then check_field = 1
phcount = 0 ; For Brazilian UF.
for ifield = 0, nfields-1 do begin

    ; Check fields for consistency, and make sure array index is correct.

    thisfieldname = string(byte(buf[datahdr_start+3+ifield*2],0,2))
    ; If we're selecting fields, discard this field if it's not in the list.
    if check_field then begin
       n = where(select_fields eq thisfieldname)
       if n[0] eq -1 then continue
    endif
    ; Get volume index for this field.
    ivol = where(fieldnames eq thisfieldname,count)
    if count eq 1 then ivol = ivol[0]
    ; For Brazilian UF (Jaraguar) with two PH fields.
    if count eq 2 and thisfieldname eq 'PH' then begin
        ivol = ivol[phcount]
        phcount = phcount + 1
    endif
    if ivol lt 0 then message,'record contains new field name not in ' + $
	'previous records: ' + thisfieldname

    ; Transfer data to structure.

    iray = radar.volume[ivol].sweep[iswp].h.nrays
    radar.volume[ivol].sweep[iswp].ray[iray].h.month = buf[26]
    radar.volume[ivol].sweep[iswp].ray[iray].h.day = buf[27]
    radar.volume[ivol].sweep[iswp].ray[iray].h.year = year
    radar.volume[ivol].sweep[iswp].ray[iray].h.hour = buf[28]
    radar.volume[ivol].sweep[iswp].ray[iray].h.minute = buf[29]
    radar.volume[ivol].sweep[iswp].ray[iray].h.sec = buf[30]
    radar.volume[ivol].sweep[iswp].ray[iray].h.ray_num = buf[7]
    radar.volume[ivol].sweep[iswp].ray[iray].h.elev = buf[33]/64.
    radar.volume[ivol].sweep[iswp].ray[iray].h.elev_num = buf[9]
    radar.volume[ivol].sweep[iswp].ray[iray].h.fix_angle = buf[35]/64.
    radar.volume[ivol].sweep[iswp].ray[iray].h.azim_rate = buf[36]/64.
    radar.volume[ivol].sweep[iswp].ray[iray].h.sweep_rate = buf[36]/64. * (60./360.)
    radar.volume[ivol].sweep[iswp].ray[iray].h.azimuth = -99999.0 ; initial value.
    fieldhdr_start = buf[datahdr_start+4+ifield*2]-1
    scale_factor = float(buf[fieldhdr_start+1])
    azimuth = buf[32]/64.
    if azimuth lt 0. then azimuth = azimuth + 360.
    radar.volume[ivol].sweep[iswp].ray[iray].h.azimuth = azimuth
    radar.volume[ivol].sweep[iswp].ray[iray].h.pulse_count = buf[fieldhdr_start+12]
    prt = buf[fieldhdr_start+17] * .000001 ; microseconds to seconds.
    radar.volume[ivol].sweep[iswp].ray[iray].h.prf = 1./prt
    radar.volume[ivol].sweep[iswp].ray[iray].h.pulse_width = $
	buf[fieldhdr_start+6] / rsl_speed_of_light * 1000000. ; microsec.
    radar.volume[ivol].sweep[iswp].ray[iray].h.range_bin1 = $
        buf[fieldhdr_start+2] * 1000 + buf[fieldhdr_start+3]
    radar.volume[ivol].sweep[iswp].ray[iray].h.gate_size = buf[fieldhdr_start+4]
    radar.volume[ivol].sweep[iswp].ray[iray].h.beam_width = buf[fieldhdr_start+7]/64.
    wavelength = buf[fieldhdr_start+11]/64.*.01
    radar.volume[ivol].sweep[iswp].ray[iray].h.wavelength = wavelength

    frequency = buf[fieldhdr_start+9]
    ; This corrects an error in prior rsl_in_idl where frequency was multiplied
    ; by 64.  Also, frequency is now converted from GHz to MHz for UF.
    if (frequency lt 1000.) then frequency = frequency/64. $
    else frequency = frequency/1000.
    radar.volume[ivol].sweep[iswp].ray[iray].h.frequency = frequency
    radar.volume[ivol].sweep[iswp].ray[iray].h.unam_rng = rsl_speed_of_light * prt*.5*.001 
    if thisfieldname eq 'VR' or thisfieldname eq 'VE' then $
	radar.volume[ivol].sweep[iswp].ray[iray].h.nyq_vel = $
	    buf[fieldhdr_start+19] / scale_factor
    nbins = buf[fieldhdr_start+5]
    radar.volume[ivol].sweep[iswp].ray[iray].h.nbins = nbins
    missing_data = buf[44]

    ; If Local Use Header is present and contains azimuth, use that
    ; azimuth for VR and SW. This is for WSR-88D, which runs separate
    ; scans for DZ and VR/SW at the lower elevations, which means DZ
    ; VR/SW and have different azimuths in the "same" ray.

    luh_len = buf[4] - buf[3]
    if luh_len eq 2 && (thisfieldname eq 'VR' || thisfieldname eq 'SW') $
      then begin
	luh_start = buf[3]-1
	azlabel = string(byte(buf[luh_start],0,2))
        if azlabel eq 'ZA' || azlabel eq 'AZ' then begin
	    azimuth = buf[luh_start+1]/64.
            if azimuth lt 0. then azimuth = azimuth + 360.
            radar.volume[ivol].sweep[iswp].ray[iray].h.azimuth = azimuth
	endif
    endif

    datastart = buf[fieldhdr_start]-1
    data = buf[datastart:datastart+nbins-1]
    range = fltarr(nbins)
    s = where(data eq missing_data)
    if size(s,/n_dimensions) gt 0 then range[s] = no_data_flag
    s = where(data ne missing_data)
    if size(s,/n_dimensions) gt 0 then range[s] = float(data[s]) / scale_factor
    radar.volume[ivol].sweep[iswp].ray[iray].range = range
    radar.volume[ivol].sweep[iswp].h.nrays = iray + 1
endfor

end

;***************************;
;     store_sweep_header    ;
;***************************;

pro store_sweep_header, iswp, sweepnumber, radar

compile_opt hidden

radar.volume.sweep[iswp].h.sweep_num = sweepnumber
if radar.h.scan_mode ne 'RHI' then radar.volume.sweep[iswp].h.elev = $
    radar.volume[0].sweep[iswp].ray[0].h.fix_angle $
else radar.volume.sweep[iswp].h.elev = radar.volume[0].sweep[iswp].ray[0].h.elev
radar.volume.sweep[iswp].h.fixed_angle = $
    radar.volume[0].sweep[iswp].ray[0].h.fix_angle
radar.volume.sweep[iswp].h.beam_width = radar.volume[0].sweep[iswp].ray[0].h.beam_width 
radar.volume.sweep[iswp].h.vert_half_bw = radar.volume[0].sweep[iswp].ray[0].h.beam_width / 2.
radar.volume.sweep[iswp].h.horz_half_bw = radar.volume[0].sweep[iswp].ray[0].h.beam_width / 2.
radar.volume.sweep[iswp].h.field_type = radar.volume.h.field_type
end

;***************************;
;      read_uf_record       ;
;***************************;

pro read_uf_record, iunit, buf, error=error

;***********************************************************************
; Read a Universal Format record.  Byte swapping is performed if necessary.
;
; Syntax:
;     read_uf_record, iunit, buf
;
; Inputs:
;     iunit: logical unit number for UF file input.
;
; Outputs:
;     buf: contains one record from UF file.
;
; Written by:  Bart Kelley, GMU, May 2002
;
; Based on the RSL program uf_to_radar by John Merritt of SM&A Corp.
;***********************************************************************
; 

compile_opt hidden

error = 0

; Determine if record is a fortran unformatted record, which contains a 4-byte
; record length descriptor at the beginning and end of the record.
; Here's how we determine this:
; Read in the first 6 bytes of the record.
; The actual UF record begins with the string "UF".
; If first 2 bytes don't contain this string,
; we assume fortran records, but we still check for it in
; bytes 5 and 6 to be sure this is a valid UF file.

fortran = 0
recbegin=intarr(3)
readu,iunit,recbegin

if string(byte(recbegin,0,2)) ne 'UF' then begin
    fortran = 1
    if string(byte(recbegin,4,2)) ne 'UF' then begin
        ; For Stacy B.'s multivolume UF.  Found that volume scans are separated
	; by 2 longword integers containing 0.  Since we read 6 of those 8
	; bytes into "recbegin", we need to read 2 more to get to the next
	; Fortran record.
	if total(recbegin) eq 0 then begin
	    spacer = 0
	    readu,iunit,spacer
	    readu,iunit,recbegin
	endif
	if string(byte(recbegin,4,2)) ne 'UF' then begin
	message, 'File is not UF',/continue
	error = 1
	return
	endif
    endif
endif

if fortran then begin
    ; Logical records begin and end with longword FORTRAN record descriptors.
    recsize = long(recbegin,0)
    byteorder, recsize, /lswap, /swap_if_little_endian
    if recsize gt 99999L or recsize lt 90 then begin
        message,'Recsize = ' + strtrim(recsize,1) + ' bytes is improbable.', $
	    /continue
	print,'The expected value is in the range of 2K to 10K bytes.'
	print,'A very large value might indicate that byte order is not big '+$
	    'endian as expected.'
	error = 1
	return
    endif
    ; Record's first 2-byte word was read with the first 6 bytes.
    buf=bytarr(recsize-2)
    readu,iunit,buf
    buf = [ byte(recbegin,4,2), buf ] ; Restore first two bytes of record.
    buf = fix(buf,0,recsize/2) ; Convert to int
    prevsize = recsize
    readu,iunit,recsize ; Read record length descriptor at end of record.
    byteorder, recsize, /lswap, /swap_if_little_endian

    ; Check that record length descriptors match.  If not, it might mean that
    ; these really aren't FORTRAN records, or this isn't a UF file.

    if recsize ne prevsize then begin
        msg = string(format='("FORTRAN record length descriptor "'+$
	',i0," at beginning of record does not match value ",i0,'+$
	'" at end of record.")', prevsize,recsize)
	message, msg, /continue
	error = 1
	return
    endif
endif else begin
    ; For records without FORTRAN descriptors.  Recsize is for 2-byte words.
    recsize = recbegin[1]
    byteorder, recsize, /sswap, /swap_if_little_endian
    buf=intarr(recsize-3)
    readu,iunit,buf
    buf = [recbegin, buf]
endelse

cbuf = buf ; copy buffer to preserve strings during byte-swapping.
byteorder, buf, /sswap, /swap_if_little_endian

; Restore character strings, which don't need to be swapped.
little_endian = not (buf[0] eq cbuf[0])
if little_endian then begin
    buf[0] = fix(cbuf,0,1)  ; string "UF"
    buf[10:17] = fix(cbuf,20,8); radar and site names
    buf[31] = fix(cbuf,62,1); time zone
    ; restore byte order in field names.
    dhfirst = buf[4]-1 ; position of first word of UF Data Header.
    for i = 0,buf[dhfirst]-1 do begin
        tmp = buf[dhfirst+3+i*2]
        byteorder, tmp, /sswap
        buf[dhfirst+3+i*2] = tmp
    endfor
endif
end

;***************************;
;     rsl_uf_to_radar       ;
;***************************;

function rsl_uf_to_radar, uf_file, quiet=quiet, error=error, $
    maxsweeps=maxsweeps, catch_error=catch_error, fields=fields, $
    maxbins=maxbins, keep_radar=keep_radar

radar = -1
error = 0

if n_elements(catch_error) eq 0 then catch_error = 1
if n_elements(keep_radar) eq 0 then keep_radar = 0

; Set up error handler to be used with keyword CATCH_ERROR.  If CATCH_ERROR
; is 0, the error handler is canceled.

catch, errcode
if errcode ne 0 then begin
    catch, /cancel
    print
    print,!error_state.msg_prefix+!error_state.msg
    if !error_state.sys_msg ne '' then print, '  '+!error_state.sys_msg
    message,'Error occurred while processing file '+uf_file+'.',/informational
    error = 1
    if not keep_radar then radar = -1
    goto, finished
endif
if not catch_error then catch, /cancel ; Cancel error handler.

iunit = rsl_open_radar_file(uf_file, error=error)
if error then goto, finished

if not keyword_set(quiet) then quiet = 0
firstrecord = 1

; If MAXSWEEPS is unset, get its value from UF.
if n_elements(maxsweeps) eq 0 then begin
    maxsweeps = rsl_get_uf_last_sweepnum(iunit)
    if maxsweeps lt 0 then maxsweeps = 25
endif
maxrays = 800
if n_elements(maxbins) eq 0 then maxbins = 1000
wsr88d_dz_maxbins = 1832
wsr88d_vr_maxbins = 1192
no_data_flag = -32767.
iswp = 0

check_field = 0
if n_elements(fields) gt 0 then begin
    select_fields = strupcase(fields)
    check_field = 1
endif

while not eof(iunit) do begin
    read_uf_record, iunit, buf, error=readerr
    if readerr then begin
        error = 1
	goto, finished
    endif

    datahdr_start = buf[4]-1

    ; If this is first record of UF, get information on data quantities
    ; and do initialization tasks.

    if firstrecord then begin
        nfields = buf[datahdr_start]
        fieldnames = strarr(nfields)
	j = 0
        for ifield = 0, nfields-1 do begin
	    this_field = string(byte(buf[datahdr_start+3+ifield*2],0,2))
	    if not check_field then begin
		fieldnames[j] = this_field
	    endif else begin
		n = where(select_fields eq this_field)
		if n[0] eq -1 then continue
		fieldnames[j] = this_field
	    endelse
	    j = j + 1
	endfor
        fieldnames = fieldnames[0:j-1]
	nfields = n_elements(fieldnames)
        fieldhdr_start = buf[datahdr_start+4] - 1
	maxbins = buf[fieldhdr_start + 5] > maxbins
        ; This next line ensures enough bins for all wsr88d fields.
        if maxbins eq wsr88d_vr_maxbins then maxbins = wsr88d_dz_maxbins
	nsweeps = maxsweeps - buf[9] + 1
	radar = rsl_new_radar(nfields, nsweeps, maxrays, maxbins)
	load_radar_header_from_uf, buf, radar
	radar.volume.h.field_type = fieldnames
	radar.volume.h.no_data_flag = no_data_flag
	sweepnumber = buf[9]
	vosnumber = buf[6]
	if not quiet then print, format='($,/"Loading sweep",i4)', sweepnumber
	firstrecord=0
    endif ; firstrecord

    ; If new sweep, store header information for previous sweep.

    if sweepnumber ne buf[9] or vosnumber ne buf[6] then begin
	if buf[9] gt maxsweeps then break
	store_sweep_header, iswp, sweepnumber, radar
	iswp = iswp + 1
	sweepnumber = buf[9]
	vosnumber = buf[6]
	if not quiet then print, format='($,i4)', sweepnumber
    endif

    ; Store data for this ray into structure.
    load_ray_from_uf, buf, iswp, radar, select_fields
endwhile

store_sweep_header, iswp, sweepnumber, radar
radar.volume.h.nsweeps = iswp + 1
radar.h.nvolumes = nfields
; For Brazilian UF (Jaraguar) with two PH fields.
s = where(fieldnames eq 'PH',count)
if count eq 2 then begin
    phvol2 = s[1]
    radar.volume[phvol2].h.field_type = 'P2'
    radar.volume[phvol2].sweep.h.field_type = 'P2'
endif
if not quiet then print,'  Done'
finished:
free_lun, iunit
if size(radar,/n_dimensions) eq 0 then error = 1
return, radar
end
