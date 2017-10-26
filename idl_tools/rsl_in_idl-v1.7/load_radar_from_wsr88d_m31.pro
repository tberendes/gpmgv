; This file contains routines for processing Message Type 31, the digital
; radar message type introduced in WSR-88D Level II Build 10.

; Written by Bart Kelley, SSAI, August 2008


;*************************************;
;     wsr88d_define_named_structs     ;
;*************************************;

pro wsr88d_define_named_structs

; Data descriptions in the following data structures are from the "Interface
; Control Document for the RDA/RPG", Build 10.0 Draft, WSR-88D Radar Operations
; Center.

ray_hdr = {wsr88d_m31_rayhdr, $
    radar_id:bytarr(4), $
    ray_time:0UL, $ ; Data collection time in milliseconds past midnight GMT
    ray_date:0U,  $ ; Julian date - 2440586.5 (1/01/1970)
    azm_num:0U ,  $ ; Radial number within elevation scan
    azm:0.0,      $ ; Azimuth angle in degrees (0 to 359.956055)
    compression_code:0b, $ ; 0 = uncompressed, 1 = BZIP2, 2 = zlib
    spare:0b,      $ ; for word alignment
    radial_len:0U, $ ; radial length in bytes, including data header block
    azm_res:0b, $
    radial_status:0b,  $
    elev_num:0b,       $
    sector_cut_num:0b, $
    elev:0.0,          $ ; Elevation angle in degrees (-7.0 to 70.0)
    radial_spot_blanking:0b, $
    azm_indexing_mode:0b,    $
    data_block_count:0U,     $
    ; Data Block Pointers
    dbptr_vol_const:0UL,     $
    dbptr_elev_const:0UL,    $
    dbptr_radial_const:0UL,  $
    field_index:ulonarr(6)   $
}

data_hdr = {wsr88d_data_hdr, $
    dataname:bytarr(4), $
    reserved:0UL, $
    ngates:0U, $
    range_first_gate:0, $
    range_samp_interval:0, $
    thresh_not_overlayed:0, $
    snr_thresh:0, $
    controlflag:0b, $
    data_bits:0b, $
    scale:0.0, $
    offset:0.0 $
}

maxsweeps = 23

vcp_data = {wsr88d_vcp_data,  $
    vcp:0U, $
    num_cuts:0U, $
    vel_res:0.0, $
    pulse_width_code:0, $
    fixed_angle:fltarr(maxsweeps), $
    azim_rate:fltarr(maxsweeps),   $
    waveform:intarr(maxsweeps),    $
    super_res_ctrl:intarr(maxsweeps),  $
    surveil_prf_num:intarr(maxsweeps), $
    surveil_pulse_cnt:uintarr(maxsweeps), $
    doppler_prf_num:uintarr(maxsweeps),   $
    doppler_pulse_cnt:uintarr(maxsweeps), $
    short_pulse_width:0.0, $
    long_pulse_width:0.0   $
}
end

;*****************************;
;     wsr88d_get_vcp_data     ;
;*****************************;

pro wsr88d_get_vcp_data, vcpmsg, vcp_data

byteorder, vcpmsg, /sswap, /swap_if_little_endian 

vcp_data.vcp = vcpmsg[2]
vcp_data.num_cuts = vcpmsg[3]
vel_res_code = vcpmsg[5] / 256
if vel_res_code eq 2 then vcp_data.vel_res = 0.5 $
else if vel_res_code eq 4 then vcp_data.vel_res = 1.0
vcp_data.pulse_width_code = vcpmsg[5] and 255
; Get information for each sweep.
for i = 0, vcp_data.num_cuts-1 do begin
    offset = i*23
    vcp_data.fixed_angle[i] = vcpmsg[11+offset]/8.0*180./4096.0
    vcp_data.azim_rate[i] = vcpmsg[15+offset]/8.0*45./4096.0
    vcp_data.waveform[i] = vcpmsg[12+offset] and 255
    vcp_data.super_res_ctrl[i] = vcpmsg[13+offset] / 256
    vcp_data.surveil_prf_num[i] = vcpmsg[13+offset] and 255
    vcp_data.surveil_pulse_cnt[i] = vcpmsg[14+offset]
    vcp_data.doppler_prf_num[i] = vcpmsg[23+offset]
    vcp_data.doppler_pulse_cnt[i] = vcpmsg[24+offset]
endfor

end

;********************************;
;      keep_this_vcp121_refl     ;
;********************************;

function keep_this_vcp121_refl, isweep 

; This function determines if the VCP 121 reflectivity sweep should be kept
; (it is a contiguous surveillance or batch sweep) or discarded (it is in a
; velocity sweep).
; Return 1 if sweep is to be kept, 0 otherwise.

case isweep of
    0: keep = 1
    4: keep = 1
    8: keep = 1
   11: keep = 1
   14: keep = 1
   16: keep = 1
   17: keep = 1
   18: keep = 1
   19: keep = 1
   else: keep = 0
endcase
return, keep
end

;********************************;
;      get_vcp121_fieldname      ;
;********************************;

function get_vcp121_fieldname, isweep, field

; Because VCP 121 has more than one velocity sweep in most of its split cuts,
; it is necessary to give the additional sweeps unique field names.  This also
; applies to spectrum width, which is included in the velocity sweeps.

if field ne 'VR' and field ne 'SW' then message, 'Unexpected field name = ' + $
    field, + ', expected VR or SW.'

; Each of these indices corresponds to the first velocity sweep of a split cut
; or a batch cut.  These sweeps will receive the standard field name, either
; 'VR' or 'SW'.
ContigDoppler1 = [1, 5, 8, 11, 14, 16, 17, 18, 19]
n = where(ContigDoppler1 eq isweep)
if n[0] ne -1 then begin
    newname = field
    return, newname
endif

case isweep of
    2: if field eq 'VR' then newname = 'V2' else newname = 'S2'
    3: if field eq 'VR' then newname = 'V3' else newname = 'S3' 
    6: if field eq 'VR' then newname = 'V2' else newname = 'S2'
    7: if field eq 'VR' then newname = 'V3' else newname = 'S3'
    9: if field eq 'VR' then newname = 'V2' else newname = 'S2'
   10: if field eq 'VR' then newname = 'V3' else newname = 'S3'
   12: if field eq 'VR' then newname = 'V2' else newname = 'S2'
   13: if field eq 'VR' then newname = 'V3' else newname = 'S3'
   15: if field eq 'VR' then newname = 'V2' else newname = 'S2'
endcase
return, newname
end

;********************************;
;     wsr88d_get_pulse_width     ;
;********************************;

pro wsr88d_get_pulse_width, non31msg, vcp_data
vcp_data.short_pulse_width = swap_endian(ulong(non31msg,1264,1), $
    /swap_if_little_endian) / 1000. ; Convert to microseconds.
vcp_data.long_pulse_width = swap_endian(ulong(non31msg,1268,1), $
    /swap_if_little_endian) / 1000.
end


;*************************************;
;     get_radar_struct_dimensions     ;
;*************************************;

pro get_radar_struct_dimensions, vcp_data, maxsweeps, maxrays, maxbins
maxsweeps = vcp_data.num_cuts
; Use super resolution control value to determine maxrays and maxbins.
superres = vcp_data.super_res_ctrl[0]
sres_az = superres and 1  ; 0.5 deg. azimuth width if set
if sres_az then maxrays = 720 else maxrays = 400
superres = ishft(superres, -1)
sres_bin = superres and 1
if sres_bin then maxbins = 1840 else maxbins = 1000
superres = ishft(superres, -1)
doppler_300k = superres and 1
if maxbins eq 1000 and doppler_300k then maxbins = 1200
end

;*******************;
;    read_msghdr    ;
;*******************;

pro read_msghdr, iunit, msghdr, error

; Read in the message header.
; The message header consists of 8 short integers.  It is preceded by 12 bytes
; that are inserted by the WSR-88D RPG.  We read the RPG insert and the
; message header together, then extract the message header.

if eof(iunit) then begin
    error = 1
    return
endif

mhdr = uintarr(14) ; includes 6 ints inserted by RPG.
readu, iunit, mhdr
mhdr = mhdr[6:13]
byteorder, mhdr, /sswap, /swap_if_little_endian
msghdr = { $
    msg_size : mhdr[0],         $
    channel : mhdr[1] / 256,    $
    msg_type : mhdr[1] and 255, $
    id_seq : mhdr[2],           $
    nsegs : mhdr[6],            $
    segnum : mhdr[7]            $
}
end

;**********************************;
;     wsr88d_load_sweep_header     ;
;**********************************;

pro wsr88d_load_sweep_header, isweep, wsr88d_ray, vcp_data, radar

common rsl_wsr88d_indexes, vol_index, nvols, sweep_index

ray_hdr = wsr88d_ray.ray_hdr

startvol = 0
numvols = nvols

waveform = vcp_data.waveform[isweep]

for ivol = startvol, numvols-1 do begin
    this_field =  vol_index[ivol]
    ; These 2 tests are for VCP 121, where we can have V2, S2, V3, S3.
    if strcmp(this_field, 'V', 1) then this_field = 'VR'
    if strcmp(this_field, 'S', 1) then this_field = 'SW'
    ; If this is surveillance sweep (split-cut reflectivity), skip Doppler fields.
    if waveform eq 1 and (this_field eq 'VR' or this_field eq 'SW') then continue
    ; If this is Doppler sweep (split-cut VR|SW), skip non-Doppler fields.
    if waveform eq 2 and (this_field ne 'VR' and this_field ne 'SW') then continue
    this_sweep = sweep_index[ivol]
    if radar.volume[ivol].sweep[this_sweep].h.nrays eq 0 then continue
    radar.volume[ivol].sweep[this_sweep].h.sweep_num = ray_hdr.elev_num
    if ray_hdr.azm_res eq 1 then $
        radar.volume[ivol].sweep[this_sweep].h.beam_width = 0.5 $
    else radar.volume[ivol].sweep[this_sweep].h.beam_width = 1.0
    vert_half_bw = .5 * radar.volume[ivol].sweep[this_sweep].h.beam_width 
    radar.volume[ivol].sweep[this_sweep].h.vert_half_bw = vert_half_bw
    radar.volume[ivol].sweep[this_sweep].h.horz_half_bw = vert_half_bw
    radar.volume[ivol].sweep[this_sweep].h.elev = vcp_data.fixed_angle[isweep]
    radar.volume[ivol].sweep[this_sweep].h.fixed_angle = $
        vcp_data.fixed_angle[isweep]
    radar.volume[ivol].h.nsweeps = radar.volume[ivol].h.nsweeps + 1
endfor

end

;**************************;
;     get_m31_data_hdr     ;
;**************************;

function get_m31_data_hdr, data, dptr

data_hdr = {wsr88d_data_hdr}
i = dptr
data_hdr.dataname = byte(data,i,4)
data_hdr.reserved = ulong(data,i+4,1)
data_hdr.ngates = uint(data,i+8,1)
data_hdr.range_first_gate = fix(data,i+10)
data_hdr.range_samp_interval = fix(data,i+12)
data_hdr.thresh_not_overlayed = fix(data,i+14)
data_hdr.snr_thresh = fix(data,i+16)
data_hdr.controlflag = data[i+18]
data_hdr.data_bits = data[i+19]
data_hdr.scale = float(data,i+20,1)
data_hdr.offset = float(data,i+24,1)
swap_endian_inplace, data_hdr, /swap_if_little_endian
return, data_hdr
end

;**************************************;
;     get_wsr88d_unamb_and_nyq_vel     ;
;**************************************;

pro get_wsr88d_unamb_and_nyq_vel, wsr88d_ray, unamb_rng, nyq_vel

ray_hdr = wsr88d_ray.ray_hdr
data = wsr88d_ray.radial
ptr = ray_hdr.dbptr_radial_const

; According to WSR-88D RDA/RPG document we can't be certain of pointer order,
; so make sure we have the Radial Constant Block.
found = 0
dataname = string(byte(data,ptr,ptr+3))
if dataname eq 'RRAD' then found = 1 $
else begin
    ; see if elev_const pointer actually points to radial_const.
    ptr = ray_hdr.dbptr_elev_const
    dataname = string(byte(data,ptr,ptr+3))
    if dataname eq 'RRAD' then found = 1 $
    else begin
        ; see if vol_const pointer actually points to radial_const.
        ptr = ray_hdr.dbptr_vol_const 
        dataname = string(byte(data,ptr,ptr+3))
        if dataname eq 'RRAD' then found = 1
    endelse
endelse

if found then begin
    unamb_rng = fix(data,ptr+6,1)
    unamb_rng = swap_endian(unamb_rng, /swap_if_little_endian) / 10.
    nyq_vel = fix(data,ptr+16,1)
    nyq_vel = swap_endian(nyq_vel, /swap_if_little_endian) / 100.
endif else begin
    unamb_rng = 0.0
    nyq_vel = 0.0
endelse

end

;*********************************;
;     load_m31_ray_into_radar     ;
;*********************************;

pro load_m31_ray_into_radar, wsr88d_ray, isweep, vcp_data, radar

; Load data into Radar ray structure.

common rsl_wsr88d_indexes, vol_index, nvols, sweep_index

rsl_speed_of_light = 299792458.0

ray_hdr = wsr88d_ray.ray_hdr
data = wsr88d_ray.radial
data_hdr_size = 28 ; bytes

get_wsr88d_unamb_and_nyq_vel, wsr88d_ray, unamb_rng, nyq_vel

; Waveform Types
surveillance =      1
doppler_w_ambres  = 2
doppler_no_ambres = 3
batch =             4

; Load each data field into Radar ray.

iray = ray_hdr.azm_num - 1
nfields = ray_hdr.data_block_count - 3 

for ifield = 0, nfields-1 do begin
    dptr = ray_hdr.field_index[ifield]
    ; Get data field header.
    data_hdr = get_m31_data_hdr(data, dptr)
    dp = dptr + data_hdr_size

    waveform = vcp_data.waveform[isweep]
    vcp = vcp_data.vcp
    ivol = -1

    ; Get volume index for this field.
    case string(data_hdr.dataname) of
       'DREF': begin
           ; We keep reflectivity only when it is from the surveillance scan of
           ; a split cut, or from the batch mode scans.  We keep it by setting
           ; the value of ivol; otherwise ivol retains its initial value of -1.
           if vcp ne 121 then begin
                if waveform eq surveillance or waveform eq batch or $
                     waveform eq doppler_no_ambres then ivol = 0
           endif else begin
               if keep_this_vcp121_refl(isweep) then ivol = 0
           endelse
       end
       'DVEL': begin
           this_fld_name = 'VR'
           if vcp eq 121 then begin
                ; For multiple velocity sweeps: Set this_fld_name to one of
                ; 'VR', 'V2' or 'V3'
                this_fld_name = get_vcp121_fieldname(isweep,'VR')
           endif
           ivol = where(vol_index eq this_fld_name)
           if ivol lt 0 then begin
               ivol = nvols
               vol_index[ivol] = this_fld_name
               nvols = nvols + 1
           endif
       end
       'DSW ': begin
           this_fld_name = 'SW'
           if vcp eq 121 then begin
               ; For multiple velocity sweeps: Set this_fld_name to one of 'SW',
               ; 'S2' or 'S3'
               this_fld_name = get_vcp121_fieldname(isweep,'SW')
           endif
           ivol = where(vol_index eq this_fld_name)
           if ivol lt 0 then begin
               ivol = nvols
               vol_index[ivol] = this_fld_name
               nvols = nvols + 1
           endif
       end
       'DZDR': begin
           ivol = where(vol_index eq 'DR')
           if ivol lt 0 then begin
               ivol = nvols
               vol_index[ivol] = 'DR'
               nvols = nvols + 1
           endif
       end
       'DPHI': begin
           ivol = where(vol_index eq 'PH')
           if ivol lt 0 then begin
               ivol = nvols
               vol_index[ivol] = 'PH'
               nvols = nvols + 1
           endif
       end
       'DRHO': begin
           ivol = where(vol_index eq 'RH')
           if ivol lt 0 then begin
               ivol = nvols
               vol_index[ivol] = 'RH'
               nvols = nvols + 1
           endif
       end
    endcase

    ngates = data_hdr.ngates
    offset = data_hdr.offset
    scale = data_hdr.scale

    ; If this field was assigned a volume index, load ray data.
    if ivol gt -1 then begin
        this_sweep = sweep_index[ivol]
        if data_hdr.data_bits eq 8 then begin
            raydata = data[dp:dp+ngates-1]
        endif $
        else if data_hdr.data_bits eq 16 then begin
            raydata = fix(data,dp,ngates)
            byteorder, raydata, /sswap, /swap_if_little_endian
        endif else raydata = data[dp:dp+ngates-1]
        s = where(raydata gt 1, count, complement=nodata, ncomplement=nodatacount)
        if count gt 0 then $
            radar.volume[ivol].sweep[this_sweep].ray[iray].range[s] = $
                (raydata[s] - offset) / scale  
        if nodatacount gt 0 then $
            radar.volume[ivol].sweep[this_sweep].ray[iray].range[nodata] = $
                radar.volume[ivol].h.no_data_flag

        ; Load ray header.
        jul2cal, ray_hdr.ray_date, month, day, year
        sec = ray_hdr.ray_time/1000.
        hour = fix(sec/3600.)
        minute = fix((sec - hour*3600.)/60.)
        sec = sec - hour*3600. - minute*60.
        radar.volume[ivol].sweep[this_sweep].ray[iray].h.month = month
        radar.volume[ivol].sweep[this_sweep].ray[iray].h.day = day
        radar.volume[ivol].sweep[this_sweep].ray[iray].h.year = year
        radar.volume[ivol].sweep[this_sweep].ray[iray].h.hour = hour
        radar.volume[ivol].sweep[this_sweep].ray[iray].h.minute = minute
        radar.volume[ivol].sweep[this_sweep].ray[iray].h.sec = sec
        radar.volume[ivol].sweep[this_sweep].ray[iray].h.azimuth = ray_hdr.azm
        radar.volume[ivol].sweep[this_sweep].ray[iray].h.ray_num = ray_hdr.azm_num
        radar.volume[ivol].sweep[this_sweep].ray[iray].h.elev = ray_hdr.elev
        radar.volume[ivol].sweep[this_sweep].ray[iray].h.elev_num = ray_hdr.elev_num
        if ray_hdr.azm_res eq 1 then $
            radar.volume[ivol].sweep[this_sweep].ray[iray].h.beam_width = 0.5 $
        else radar.volume[ivol].sweep[this_sweep].ray[iray].h.beam_width = 1.0
        radar.volume[ivol].sweep[this_sweep].ray[iray].h.prf = $
            rsl_speed_of_light/(2.*unamb_rng*1000.)
        radar.volume[ivol].sweep[this_sweep].ray[iray].h.range_bin1 = $
            data_hdr.range_first_gate
        radar.volume[ivol].sweep[this_sweep].ray[iray].h.gate_size =  $
            data_hdr.range_samp_interval
        radar.volume[ivol].sweep[this_sweep].ray[iray].h.azim_rate =  $
            vcp_data.azim_rate[isweep]
        radar.volume[ivol].sweep[this_sweep].ray[iray].h.sweep_rate =  $
            vcp_data.azim_rate[isweep] * 60./360. ; sweeps/minute
        radar.volume[ivol].sweep[this_sweep].ray[iray].h.fix_angle =  $
            vcp_data.fixed_angle[isweep]
        radar.volume[ivol].sweep[this_sweep].ray[iray].h.pulse_count =  $
            (ivol eq 0) ? vcp_data.surveil_pulse_cnt[isweep] : $
                vcp_data.doppler_pulse_cnt[isweep]
        if vcp_data.pulse_width_code eq 2 then $
            pulse_width = vcp_data.short_pulse_width $
        else if vcp_data.pulse_width_code eq 4 then $
            pulse_width = vcp_data.long_pulse_width $
        else pulse_width = 0.
        radar.volume[ivol].sweep[this_sweep].ray[iray].h.pulse_width = pulse_width
        radar.volume[ivol].sweep[this_sweep].ray[iray].h.vel_res = vcp_data.vel_res
        radar.volume[ivol].sweep[this_sweep].ray[iray].h.unam_rng = unamb_rng
        radar.volume[ivol].sweep[this_sweep].ray[iray].h.nyq_vel = nyq_vel 
        radar.volume[ivol].sweep[this_sweep].ray[iray].h.nbins = ngates
        wavelength = .1 ; m
        radar.volume[ivol].sweep[this_sweep].ray[iray].h.wavelength = wavelength
        radar.volume[ivol].sweep[this_sweep].ray[iray].h.frequency = $
                rsl_speed_of_light / wavelength * 1e-9
        ; Increment ray count in sweep header.
        radar.volume[ivol].sweep[this_sweep].h.nrays = ray_hdr.azm_num
    endif
endfor ; Field loop

end

;*****************************;
;     read_wsr88d_m31_ray     ;
;*****************************;

pro read_wsr88d_m31_ray, iunit, msg_size, wsr88d_ray

ray_hdr_size = 68 ; bytes
ray_hdr = {wsr88d_m31_rayhdr}
readu, iunit, ray_hdr
swap_endian_inplace, ray_hdr, /swap_if_little_endian
radial = bytarr(msg_size*2 - ray_hdr_size)
readu, iunit, radial
; Pad front of radial to size of header.  This keeps the data moment pointers
; accurate.
radial = [bytarr(ray_hdr_size), radial]
wsr88d_ray = {ray_hdr:ray_hdr, radial:radial}

end


;************************************;
;     load_radar_from_wsr88d_m31     ;
;************************************;

pro load_radar_from_wsr88d_m31, iunit, radar, quiet=quiet, dualpol=dualpol, $
    error=error, keep_sails=keep_sails

; Load WSR-88D Level II Message Type 31 data into radar structure.

; These sizes are the number of halfwords (16-bit integers) for each item.
msg_hdr_size = 8
rpg_size = 6

; WSR-88D Radial Status Values
NEW_ELEV =  0
INTERMED_RAY = 1
END_ELEV =  2
BEGIN_VOS = 3
END_VOS  =  4

; Define named structures.
wsr88d_define_named_structs
vcp_data = {wsr88d_vcp_data}

; Initialize
radar = -1
maxrays = 720
error = 0
end_of_vos = 0

common rsl_wsr88d_indexes, vol_index, nvols, sweep_index
nvols = 1   ; Number of volumes.
; Note: vol_index and sweep_index are initialized when VCP becomes known.
; This occurs when MSG 5 data is acquired below.

; Call swap_endian here only to print the compiler messages early in processing.
; Variable *end_of_vos* has value 0, so swapping has no effect.
swap_endian_inplace, end_of_vos, /swap_if_big_endian
end_of_vos = swap_endian(end_of_vos, /swap_if_big_endian)

; This is used for reading message types other than 31.
non31msg = uintarr(1216 - (msg_hdr_size + rpg_size))

read_msghdr, iunit, msghdr

if keyword_set(dualpol) then maxvols = 6 else maxvols = 3
isweep = 0
nrays = 0

if not keyword_set(quiet) then quiet = 0
if not quiet then print, format='(/$,"Loading sweeps")'

while not end_of_vos do begin
    if msghdr.msg_type eq 31 then begin
        msg_size = msghdr.msg_size - msg_hdr_size

        read_wsr88d_m31_ray, iunit, msg_size, wsr88d_ray

        ; Check for unexpected sweep change.
        if wsr88d_ray.ray_hdr.radial_status eq NEW_ELEV then begin
            ; If previous sweep not complete then issue warning message and
            ; update counters.
            if wsr88d_ray.ray_hdr.elev_num ne isweep+1 then begin
                print
                message,'Warning: previous sweep ended unexpectedly.', $
                    /informational
                print, f='("new elev_num = ",I)', wsr88d_ray.ray_hdr.elev_num
                print, f='("nrays previous sweep = ",I)', nrays
                ; Temporarily decrement elev_num in ray header for use in
                ; updating previous sweep's header.
                elev_num = wsr88d_ray.ray_hdr.elev_num
                wsr88d_ray.ray_hdr.elev_num = elev_num - 1
                ; Update header of previous sweep.
                wsr88d_load_sweep_header, isweep, wsr88d_ray, vcp_data, radar
                ; Restore correct elev_num to ray header.
                wsr88d_ray.ray_hdr.elev_num = elev_num
                if not quiet then $
                    print, format='($,i4)', wsr88d_ray.ray_hdr.elev_num-1
                isweep = isweep + 1
                ; Increment sweep indexes for fields.
                for i = 0, nvols-1 do begin
                    if radar.volume[i].sweep[sweep_index[i]].h.nrays gt 0 then $
                        sweep_index[i] = sweep_index[i] + 1
                endfor
            endif
            ; Write informational message when this occasional problem occurs:
            ; radial status indicates new sweep but elev_num hasn't changed.
            ; Apparently sweep is restarted before completion. The restarted
            ; sweep has been observed to complete a full rotation.
            if prev_ray.ray_hdr.elev_num eq wsr88d_ray.ray_hdr.elev_num $
                then begin
                print,format='(/"load_radar_from_wsr88d_m31: Warning: ' + $
                    'Level II abnormality detected (VCP",i3,"):")', vcp_data.vcp
                print,'Radial status indicates new sweep but elev_num has ' + $
                    'not changed.'
                ;print previous and current elev_num, elev, azm_num, azm.
                print,prev_ray.ray_hdr.elev_num, prev_ray.ray_hdr.elev, $
                    prev_ray.ray_hdr.azm_num, prev_ray.ray_hdr.azm, $
                    format='("Previous record: elev_num",i3,' + $
                    '", elev",f8.4,", azm_num",i4,", azm",f8.3)'
                print,wsr88d_ray.ray_hdr.elev_num, wsr88d_ray.ray_hdr.elev, $
                    wsr88d_ray.ray_hdr.azm_num, wsr88d_ray.ray_hdr.azm, $
                    format='("Current record:  elev_num",i3,' + $
                    '", elev",f8.4,", azm_num",i4,", azm",f8.3)'
            endif
            nrays = 0
        endif

        load_m31_ray_into_radar, wsr88d_ray, isweep, vcp_data, radar
        nrays = nrays + 1
        ;;; TESTING ;;;
        if nrays gt 720 then print,'nrays=',nrays,', azm_num=', $
            wsr88d_ray.ray_hdr.azm_num,', elev_num=',wsr88d_ray.ray_hdr.elev_num

        ; Check for end of sweep/vos.
        if wsr88d_ray.ray_hdr.radial_status eq END_ELEV then begin
            wsr88d_load_sweep_header, isweep, wsr88d_ray, vcp_data, radar
            if not quiet then $
                print, format='($,i4)', wsr88d_ray.ray_hdr.elev_num
            isweep = isweep + 1
            ; Increment sweep indexes for fields.
            for i = 0, nvols-1 do begin
                if radar.volume[i].sweep[sweep_index[i]].h.nrays gt 0 then $
                    sweep_index[i] = sweep_index[i] + 1
            endfor
        endif
        if wsr88d_ray.ray_hdr.radial_status eq END_VOS then begin
            wsr88d_load_sweep_header, isweep, wsr88d_ray, vcp_data, radar
            if not quiet then $
                print, format='($,i4)', wsr88d_ray.ray_hdr.elev_num
            end_of_vos = 1
        endif
        prev_ray = wsr88d_ray
    endif else begin  ; Message type is not 31
        readu, iunit, non31msg
        if msghdr.msg_type eq 5 then begin
            ; Get Volume Coverage Pattern (VCP) information. Use this to
            ; determine sizes for radar structure.
            wsr88d_get_vcp_data, non31msg, vcp_data
            get_radar_struct_dimensions, vcp_data, maxsweeps, maxrays, maxbins
            if vcp_data.vcp eq 121 then maxvols = maxvols + 4
            ; Initialize arrays in common block *indexes* whose size depends
            ; on the number of fields.
            vol_index = strarr(maxvols)  ; Field types associated with volumes.
            sweep_index = intarr(maxvols); Current sweep index for each volume.
            vol_index[0] = 'DZ'     ; First volume is always reflectivity.
            if size(radar,/tname) ne 'STRUCT' then $
                radar = rsl_new_radar(maxvols, maxsweeps, maxrays, maxbins)
            radar.h.vcp = vcp_data.vcp
            radar.volume.h.no_data_flag = -32767.
        endif
        if msghdr.msg_type eq 18 and msghdr.segnum eq 1 then $
            wsr88d_get_pulse_width, non31msg, vcp_data
    endelse

    ; Read next message header.
    if not end_of_vos then read_msghdr, iunit, msghdr, error
    if error then begin
        wsr88d_load_sweep_header, isweep, wsr88d_ray, vcp_data, radar
        if eof(iunit) then begin
            message, 'Unexpected end of file',/continue
            print, 'Sweep number:',isweep+1
            print, 'Last ray read:',wsr88d_ray.ray_hdr.azm_num
        endif
        end_of_vos = 1
    endif
endwhile ; not end of vos

finished:
if not quiet then print ; Print newline at end of sweep numbers list.
radar.volume[0:nvols-1].h.field_type = vol_index[0:nvols-1]
for i = 0, nvols-1 do begin
    radar.volume[i].sweep.h.field_type = vol_index[i]
endfor

; For VCPs 12 and 212, check for presence of SAILS inserted sweeps and remove
; them unless keyword KEEP_SAILS was specified.

max_sails_sweeps = 3
if (radar.h.vcp eq 12 || radar.h.vcp eq 212) and not keyword_set(keep_sails) $
    then begin
    remove_list = intarr(max_sails_sweeps) - 1 ; Initialize with -1.
    j = 0
    for iswp = 1, radar.volume[0].h.nsweeps-1 do begin
        if radar.volume[0].sweep[iswp].h.elev lt $
            radar.volume[0].sweep[iswp-1].h.elev then begin
            remove_list[j] = iswp
            j = j + 1
        endif
    endfor
    nremove = j
    if nremove gt 0 then begin
        if not quiet then begin
            index_word = (nremove gt 1) ? 'indices' : 'index'
            print,f='($,"Removing SAILS sweeps at ' + index_word + ' ")'
            for i = 0,nremove-1 do begin
                print,remove_list[i], $
                    format=(nremove-i gt 1 ? '($,i0,", ")' : '(i0)')
            endfor
        endif
        rsl_remove_sweep, radar, remove_list, nremove
    endif
endif ; VCP 12 and 212
end
