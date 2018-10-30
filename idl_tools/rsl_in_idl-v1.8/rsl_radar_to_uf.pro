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
;

function get_field_list, radar, is_wsr88d, fields

; Get list of fields to process. If fields were selected, use those. Otherwise,
; use all fields.
 
nfields = n_elements(fields)
if nfields gt 0 then begin
    check_fields = strupcase(fields)
    sel_fields = strarr(nfields)
    ; Make sure selected fields are in radar structure.
    j = 0
    for i = 0, nfields-1 do begin
        loc = where(check_fields[i] eq radar.volume.h.field_type)
        if loc[0] ne -1 then begin
            sel_fields[j] = check_fields[i]
            j++
        endif
    endfor
    sel_fields = sel_fields[0:j-1]
endif else begin
    ; Select all fields by default.
    sel_fields = radar.volume.h.field_type
    sel_fields = sel_fields[where(sel_fields)] ; want non-empty field strings
endelse

if is_wsr88d && n_elements(sel_fields) gt 1 then begin
    ; Reorder WSR-88D fields so that if DZ,VR, and SW are present; DZ is first,
    ; VR is next-to-last, and SW is last.  This is necessary because we will
    ; align DZ and VR azimuths in split cuts.
    sel_fields = sel_fields[sort(sel_fields)]
    if sel_fields[1] eq 'DZ' then begin
        tmp = sel_fields[0]
        sel_fields[0] = sel_fields[1]
        sel_fields[1] = tmp
    endif
    lastel = n_elements(sel_fields)-1
    if sel_fields[lastel] eq 'VR' and sel_fields[lastel-1] eq 'SW' then begin
        tmp = sel_fields[lastel-1]
        sel_fields[lastel-1] = sel_fields[lastel]
        sel_fields[lastel] = tmp
    endif
endif

return, sel_fields
end


function is_split_cut, radar, iswp

; This function determines whether or not the WSR-88D sweep at index iswp is
; a split cut.  It does this by comparing the elevation and azimuth of a DZ and
; VR ray.  If the elevations are approximately the same and azimuths are
; different, it's a split cut.
;
; The function returns 1 (true) if sweep is a split cut, and 0 (false)
; otherwise.

is_split_cut = 0

; Check for special case of VCP 121.  Anything below sweep number 17 is a split
; cut.
if radar.h.vcp eq 121 then begin
    if radar.volume[0].sweep[iswp].h.sweep_num gt -1 then begin
        if radar.volume[0].sweep[iswp].h.sweep_num lt 17 then return, 1
    endif else begin  ; sweep_num less than 0
        print, 'rsl_radar_to_uf (is_split_cut):'
        print,'Volume index 0, sweep index,',iswp,': Sweep number =', $
            radar.volume[0].sweep[iswp].h.sweep_num 
        return, 0
    endelse
endif

ivol_dz = where(radar.volume.h.field_type eq 'DZ')
ivol_vr = where(radar.volume.h.field_type eq 'VR')
dzsweep = radar.volume[ivol_dz[0]].sweep[iswp]
vrsweep = radar.volume[ivol_vr[0]].sweep[iswp]

; Compare elevations for approximate sameness by multiplying their floating
; point values by 10 and taking integer difference.  If values differ, this is
; not a split cut.
if long(dzsweep.h.elev*10.) - long(vrsweep.h.elev*10.) ne 0 then return, 0

; Find a good DZ ray and VR ray for comparison (good meaning nbins gt 0).
iray = 0
found = 0
while not found do begin
    while dzsweep.ray[iray].h.nbins eq 0 do iray++
    if vrsweep.ray[iray].h.nbins ne 0 then found = 1 else iray++
endwhile

if vrsweep.ray[iray].h.azimuth - dzsweep.ray[iray].h.azimuth gt 5. then $
    is_split_cut = 1

return, is_split_cut
end


;***************************;
;      rsl_radar_to_uf      ;
;***************************;

pro rsl_radar_to_uf, radar, uf_file, fields=fields, compress=compress, $
    error=error, catch_error=catch_error, force_owrite=force_owrite
;+
;***********************************************************************
; Write the data from a Radar structure to a file in Universal Format.
;
; Syntax:
;     rsl_radar_to_uf, radar, uf_file [, FIELDS=string_array] [, /FORCE_OWRITE]
;         [, /COMPRESS] [, ERROR=variable]
;
; Arguments:
;     radar:    a Radar data structure.
;     uf_file:  a string expression containing the name of the output UF file
;               to be created.  If file name ends with '.gz', file will be
;               compressed using gzip.
; Keywords:
;     COMPRESS: Set this keyword to compress the UF file using gzip.  File name
;               suffix of '.gz' will also invoke file compression.
;
;     ERROR:    Set this keyword to a variable to return the error status.
;               A value of 1 is returned for error, 0 otherwise.
;
;     FIELDS:   string array (or scalar) containing the fields to be written
;               to the output file.  Default is all fields.  Fields are in the
;               form of the 2-character field names used by RSL, such as
;               'DZ', 'VR', etc.
;
;     FORCE_OWRITE: Set this keyword to overwrite an existing file regardless of
;                file permissions.  If not set, the file is overwritten if
;                permitted.
;
; Written by:  Bart Kelley, GMU, October 2002
;
; Based on the RSL program RSL_radar_to_uf by John Merritt of SM&A Corp.
;
; Method:
; In UF, each ray (record) contains data for all fields used, and rays are
; written in the order recorded (all rays for sweep 1, followed by all rays for
; sweep 2, and so on), whereas in the radar structure the data is organized by
; fields (called volumes), then by sweeps and rays.  The following pseudo code
; describes how the transformation from radar structure to UF is done.
;
; for each sweep in radar structure do
;     for each ray do
;        for each volume do
;          if ray exists for this volume, put its data into record
;          put data header info into record.
;        done for volumes
;        swap bytes if little endian machine.
;        write record with fortran record length descriptors.
;     done for ray
; done for sweep
;***********************************************************************
;-

; Set up error handler to be used with keyword CATCH_ERROR.  If CATCH_ERROR
; is 0, the error handler is canceled.

if n_elements(catch_error) eq 0 then catch_error = 1

catch, errcode
if errcode ne 0 then begin
    catch, /cancel
    print,!error_state.msg_prefix+!error_state.msg
    if !error_state.sys_msg ne '' then print, '  '+!error_state.sys_msg
    error = 1
    if n_elements(lunit) gt 0 then free_lun, lunit
    return
endif ; End of error handler
if not catch_error then catch, /cancel ; Cancel error handler.

; If UF file name is not given, build it.
if n_elements(uf_file) eq 0 then begin
    uf_file = strtrim(radar.h.name, 2) + string(radar.h.year, radar.h.month,  $
        radar.h.day, radar.h.hour, radar.h.minute, radar.h.sec,  $
        format='("_",i4,2i02,"_",3i02,".uf")')
endif

; If UF file ends in '.gz', compress is implied.
if keyword_set(compress) or strmid(uf_file,strlen(uf_file)-3) eq '.gz' then begin
    rsl_radar_to_uf_gzip, radar, uf_file, fields=fields, error=error, $
        force_owrite=force_owrite
    return
endif

rsl_speed_of_light = 299792458.0
no_data = fix(-32768)
do_opthdr = 1
locuhdr_len = 0
error = 0

; Get RSL-in-IDL version number (for UF header).
rsl_version, version=vnum, /quiet
if strlen(vnum) gt 3 then vnum = strjoin(strsplit(vnum,'.',/ext))
if vnum eq '' then vnum = '0.0'
while strlen(vnum) lt 3 do vnum = '0' + vnum
verstr = 'RSIDL' + vnum
if strlen(vnum) gt 3 then verstr = 'RIDL' + vnum
if strlen(verstr) gt 8 then verstr = strmid(verstr,0,8)

; If UF file exists, check that it's writable.  If not, and FORCE_OWRITE is set,
; attempt to change its write permission.

if file_test(uf_file) then begin
    if file_test(uf_file, /write) eq 0 then begin
        if keyword_set(force_owrite) then begin
            file_chmod, uf_file, /u_write
        endif else begin
            print
            print, 'rsl_radar_to_uf:'
            print, '  File ' + uf_file + ' exists but write permission ' + $
                'is denied.'
            print, '  If you are the file owner, you can set keyword ' + $
                'FORCE_OWRITE to overwrite.'
            print, 'Example:'
            print, '    rsl_radar_to_uf, radar, uffile, /force_owrite'
            error = 1
            return
        endelse
    endif
endif

openw, lunit, uf_file, /get_lun ; Open UF file for writing.

; Prepare character strings for storage in UF record: Convert to integer and
; do byte swapping on little endian machine.  Strings don't normally need to
; be byte-swapped, but later the entire record is byte-swapped, and this leaves
; them in correct order.

uf = fix(byte('UF'),0,1)
byteorder,uf,/sswap, /swap_if_little_endian
radarname = byte(radar.h.radar_name)
if n_elements(radarname) lt 8 then $
    radarname = [radarname,bytarr(8-n_elements(radarname))]
if strlen(radar.h.name) eq 0 then $
    radarsite = radarname $
else begin
    radarsite = byte(radar.h.name)
    if n_elements(radarsite) lt 8 then $
        radarsite = [radarsite,bytarr(8-n_elements(radarsite))]
endelse
radarname=fix(radarname,0,4)
radarsite=fix(radarsite,0,4)
byteorder,radarname,/sswap, /swap_if_little_endian
byteorder,radarsite,/sswap, /swap_if_little_endian
tz = fix(byte('UT'),0,1)
byteorder,tz,/sswap, /swap_if_little_endian

nsweeps = max(radar.volume.h.nsweeps)

is_wsr88d = 0
if strcmp(radar.h.radar_type,'wsr88d',6,/fold_case) && $
    radar.h.vcp gt 0 then is_wsr88d = 1

field_list = get_field_list(radar, is_wsr88d, fields)

; Get volume indices for selected fields.
nselvols = n_elements(field_list)
volidx = intarr(nselvols)
for i = 0, n_elements(field_list)-1 do begin
    loc = where(field_list[i] eq radar.volume.h.field_type)
    volidx[i] = loc[0]
endfor


; Allocate UF buffer based on data quantity plus some extra for headers.
buf = intarr(1.5 * n_elements(radar.volume.sweep[0].ray[0].range))
dat = buf
nrec = 0L
sweepnum = 0

; Set merge_split_cuts flag if this is WSR-88D and velocity is selected and base
; velocity sweep is at same sweep index as reflectivity.
merge_split_cuts = 0
if is_wsr88d then begin
    ; Check for valid velocity data in sweep[0].  If it is there, then we are
    ; merging split cuts.
    s = where(field_list eq 'VR' or field_list eq 'SW')
    if s[0] ne -1 then begin
        merge_split_cuts = 1
        ivol_vr = where(radar.volume.h.field_type eq 'VR' or $
            radar.volume.h.field_type eq 'SW')
        ivol_vr = ivol_vr[0]
        if ivol_vr gt -1 then begin
            nrays = radar.volume[ivol_vr].sweep[0].h.nrays
            ; If sum of nbins over all rays is 0, then this is an empty sweep;
            ; don't merge.
            if nrays gt 0 && total( $
                radar.volume[ivol_vr].sweep[0].ray[0:nrays-1].h.nbins,/integer)$
                eq 0 then merge_split_cuts = 0
        endif else merge_split_cuts = 0
        ; Check the possibility that only VR and/or SW is selected.  In that
        ; case, no need to merge split cuts.
        if n_elements(s) eq n_elements(field_list) then merge_split_cuts = 0
    endif
endif

if radar.h.vcp eq 121 then print,'VCP 121 may take a while.'

for iswp = 0, nsweeps-1 do begin
    sweepnum = sweepnum + 1
    maxrays = max(radar.volume.sweep[iswp].h.nrays)
    raynum = 0

    ; Check for WSR-88D split cut.
    iray_vr = -1
    merge_this_split_cut = 0
    if merge_split_cuts && is_split_cut(radar, iswp) then begin
        merge_this_split_cut = 1
    endif
    if merge_this_split_cut then begin
        ivol_vr = where(radar.volume.h.field_type eq 'VR' or $
            radar.volume.h.field_type eq 'SW')
        ; Check that the number of rays for VR and DZ are the same.  If not,
        ; set a flag to explicitly match each VR ray azimuth to DZ.
        ; Volume[0] is always DZ in WSR-88D.
        if (radar.volume[0].sweep[iswp].h.nrays ne $
            radar.volume[ivol_vr[0]].sweep[iswp].h.nrays) || $
            radar.h.vcp eq 121 then begin
            check_all_vr_rays = 1
        endif else check_all_vr_rays = 0
    endif
    ; End of split-cut part.

    for iray = 0, maxrays-1 do begin
        ; Search fields for a ray to use for header data, one with nbins > 0.
        ; If none found, skip the record building/writing process for this ray.
        havevol = -1
        for i = 0,nselvols-1 do begin
            if radar.volume[volidx[i]].sweep[iswp].ray[iray].h.nbins gt 0 $
                then begin
                havevol = volidx[i]
                break
            endif
        endfor
        if havevol eq -1 then continue
        ray = radar.volume[havevol].sweep[iswp].ray[iray]
         
        ; Put mandatory header into record.
        replicate_inplace,buf,0
        replicate_inplace,dat,0
        buf[0] = uf
        buf[6] = 1 
        buf[8] = 1
        buf[9] = sweepnum
        buf[10:13] = radarname
        buf[14:17] = radarsite
        buf[18] = radar.h.latd
        buf[19] = radar.h.latm
        buf[20] = round(radar.h.lats * 64.)
        buf[21] = radar.h.lond
        buf[22] = radar.h.lonm
        buf[23] = round(radar.h.lons * 64.)


        ; Get lat and lon from ray if available (usually not).
        lat = ray.h.lat
        lon = ray.h.lon
        if lat ne 0.0 then begin
            sign = long(abs(lat)/lat)
            lat = abs(lat)
            latd=floor(lat)
            latm=floor((lat-latd) * 60.)
            lats=floor(((lat-latd) * 60. - latm) * 60.)
            lats=round(lats * 64.)
            buf[18] = sign * latd
            buf[19] = sign * latm
            buf[20] = sign * lats
        endif
        if lon ne 0.0 then begin
            sign = long(abs(lon)/lon)
            lon = abs(lon)
            lond=floor(lon)
            lonm=floor((lon-lond) * 60.)
            lons=floor(((lon-lond) * 60. - lonm) * 60.)
            lons=round(lons * 64.)
            buf[21] = sign * lond
            buf[22] = sign * lonm
            buf[23] = sign * lons
        endif
        buf[24] = radar.h.height
        buf[25] = ray.h.year mod 100
        buf[26] = ray.h.month
        buf[27] = ray.h.day
        buf[28] = ray.h.hour
        buf[29] = ray.h.minute
        buf[30] = ray.h.sec
        buf[31] = tz
        buf[32] = round(ray.h.azimuth * 64.)
        buf[33] = round(ray.h.elev * 64.)
        scan_mode = 1  ; Use PPI as default.
        if radar.h.scan_mode eq 'RHI' then scan_mode = 3 $
        else if radar.h.scan_mode eq 'Manual' then scan_mode = 6
        buf[34] = scan_mode
        buf[35]= round(radar.volume[havevol[0]].sweep[iswp].h.fixed_angle * 64.)
        buf[36] = round(ray.h.azim_rate * 64.)
        if buf[36] eq 0 then buf[36] = round(ray.h.sweep_rate * (360./60.)*64.)
        ; Generation date in UTC.
        caldat, systime(/julian,/utc), month, day, year
        buf[37] = year mod 100
        buf[38] = month
        buf[39] = day
        tmpbuf = fix(byte(verstr),0,4)
        byteorder, tmpbuf, /sswap, /swap_if_little_endian
        buf[40:43] = tmpbuf
        buf[44] = no_data
        mandihdr_len = 45

        ; Write optional header only once.
        opthdr_len = 0
        if do_opthdr then begin
            do_opthdr = 0
            tmpbuf = fix(byte('TRMMGVUF'),0,4)
            byteorder, tmpbuf, /sswap, /swap_if_little_endian
            buf[45:48] = tmpbuf
            buf[49:50] = no_data
            buf[51] = ray.h.hour
            buf[52] = ray.h.minute
            buf[53] = ray.h.sec
            tmpbuf = fix(byte('RADAR_UF'),0,4)
            byteorder, tmpbuf, /sswap, /swap_if_little_endian
            buf[54:57] = tmpbuf
            buf[58] = 2
            opthdr_len = 14
        endif

        ; Start of data header.
        dh_start = mandihdr_len + opthdr_len + locuhdr_len
        nfields = 0
        indx = 0L ; data buffer index
        indxdh = dh_start + 3L ; data header index

        ; Get data from selected fields for this ray.
        for ifield = 0, n_elements(field_list)-1 do begin
            ivol = volidx[ifield]
            fieldname = radar.volume[ivol].h.field_type
            ray = radar.volume[ivol].sweep[iswp].ray[iray]
            ; For split cuts, if field is VR or SW, get ray whose azimuth
            ; matches current DZ azimuth.
            if merge_this_split_cut && $
                stregex(fieldname,'V[R23]|S[W23]',/boolean) then begin
                if iray_vr lt 0 || check_all_vr_rays then begin
                    ; Find VR azimuth that matches DZ azimuth.
                    dz_azim = radar.volume[0].sweep[iswp].ray[iray].h.azimuth
                    if dz_azim lt -999. then continue
                    ray = rsl_get_ray_from_sweep( $
                        radar.volume[ivol].sweep[iswp],dz_azim,index=iray_vr)
                    ; If matching azimuth not found, skip to next ray.
                    if iray_vr lt 0 then continue
                endif else ray = radar.volume[ivol].sweep[iswp].ray[iray_vr]
            endif
            ; If ray has data, copy it into UF record.
            if ray.h.nbins ne 0 then begin
                nfields = nfields + 1
                tmpbuf = fix(byte(fieldname),0,1)
                byteorder, tmpbuf, /sswap, /swap_if_little_endian
                buf[indxdh] = tmpbuf 
                buf[indxdh + 1] = indx
                indxdh = indxdh + 2
                scale_factor = 100
                ; Change scale factor for PH and RR to prevent short-integer
                ; wraparound when value > 327.67
                if fieldname eq 'PH' or fieldname eq 'RR' then scale_factor = 10
                ; Make field header.
                dat[indx+1] = scale_factor
                dat[indx+2] = ray.h.range_bin1/1000
                dat[indx+3] = ray.h.range_bin1 - dat[indx+2]*1000
                dat[indx+4] = round(ray.h.gate_size)
                dat[indx+5] = ray.h.nbins
                dat[indx+6] = round(ray.h.pulse_width*rsl_speed_of_light/1.0e6)
                dat[indx+7] = round(ray.h.beam_width * 64.)
                dat[indx+8] = dat[7]
                dat[indx+9] = round(ray.h.frequency * 1000.); Convert GHz to MHz
                dat[indx+10] = 0 ; horizontal polarization
                dat[indx+11] = round(ray.h.wavelength * 100. * 64.)
                dat[indx+12] = ray.h.pulse_count
                dat[indx+13] = fix(byte('  '),0,1)
                dat[indx+14:indx+15] = no_data
                if fieldname eq 'DZ' or fieldname eq 'ZT' or $
                    fieldname eq 'CZ' then dat[indx+16] = $
                        round(radar.volume[ivol].h.calibr_const * 100.) $
                else dat[indx+16] = fix(byte('  '),0,1)
                if ray.h.prf ne 0 then dat[indx+17] = round(1./ray.h.prf*1.0e6) $
                else dat[indx+17] = no_data
                dat[indx+18] = 16
                datastart = indx+19
                if fieldname eq 'VR' or fieldname eq 'VE' then begin
                    dat[indx+19] = ray.h.nyq_vel * 100.
                    dat[indx+20] = 1
                    datastart = datastart + 2
                endif
                dat[indx] = datastart
                ; Put data for this field into buffer.
                nbins = ray.h.nbins
                raydata = ray.range[0:nbins-1] * float(dat[indx+1])
                s = where(ray.range[0:nbins-1] eq $
                    radar.volume[ivol].h.no_data_flag)
                if size(s,/n_dimensions) gt 0 then raydata[s] = no_data
                indx = datastart
                dat[indx:indx+nbins-1] = round(raydata)
                indx = indx + nbins
            endif
        endfor ; fields

        ; Compute offsets and build UF record.
        if indx eq 0 then continue
        datalen = indx
        buf[[dh_start,dh_start+2]] = nfields
        buf[dh_start+1] = 1 ; number of records for ray.
        datahdr_len = 3 + 2*nfields
        data_start = dh_start + datahdr_len
        buf[data_start:data_start + datalen-1] = dat[0:datalen-1]
        for i = 0, nfields-1 do begin
            indxdh = dh_start + 4 + i*2
            buf[indxdh] = buf[indxdh] + data_start + 1
            fldhdr_start = buf[indxdh] - 1
            buf[fldhdr_start] = buf[fldhdr_start] + data_start + 1
        endfor

        recordlen = data_start + datalen
        buf[1] = recordlen
        buf[2] = mandihdr_len + 1
        buf[3] = mandihdr_len + opthdr_len + 1
        buf[4] = dh_start + 1
        nrec = nrec + 1
        buf[5] = nrec
        raynum = raynum + 1
        buf[7] = raynum
            
        ; Swap bytes if this is little endian machine.
        byteorder, buf,/sswap, /swap_if_little_endian
        recordlen_bytes = recordlen * 2L
        byteorder, recordlen_bytes , /lswap, /swap_if_little_endian
        ; Write UF record as a fortran record. This means writing a longword
        ; record length before and after the record.
        writeu, lunit, recordlen_bytes
        writeu, lunit, buf[0:recordlen-1]
        writeu, lunit, recordlen_bytes
        if merge_this_split_cut then begin
            iray_vr++
            if iray_vr ge radar.volume[ivol_vr[0]].sweep[iswp].h.nrays then $
                iray_vr = -1 ; will force index lookup for next iteration.
        endif
    endfor ; rays
endfor ; sweeps
free_lun, lunit

end
