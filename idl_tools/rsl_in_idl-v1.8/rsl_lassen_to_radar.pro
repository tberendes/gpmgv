; rsl_lassen_to_radar
;
; Read Lassen formatted data and return it in the Radar structure.
;
; Syntax:
;     radar = rsl_lassen_to_radar(lassen_file [, /QUIET]
;                 [, ERROR=variable] )
;
; Inputs:
;     lassen_file: name of Lassen format radar data file.
;
; Keyword parameters:
;     QUIET: Set this keyword to turn off progress reporting.
;     ERROR: Assign a variable to this keyword to have a boolean error status
;         returned.  A value of 1 (true) indicates an error occurred, 0 means
;         no error.
;
; Written by:  Bart Kelley, GMU, April 2006
;
; Adapted from RSL lassen_to_radar.c and lassen.c, written by John Merritt of
; SM&A Corporation, which was partly based on programs by Michael Whimpey of 
; Bureau of Meteorology Research Centre (Australia).
;***********************************************************************


;******************************;
;       lassen_period          ;
;******************************;

function lassen_period, vol

; Returns the Lassen period for the volume date.  The Lassen period is simply
; a way to denote time periods in which different calibrations were used.

; Lassen periods.

BERRIMAH1 = 0
MCTEX_EARLY = 1
MCTEX = 2
BERRIMAH2 = 3
GUNN_PT = 4
GUNN_PT1 = 5
SCSMEX = 6
SCSMEX1 = 7

num_dates = 8

date_struct = {year:0, month:0, day:0, hour:0, minute:0, second:0}
period_begin = replicate(date_struct, num_dates)
mem_names = ['year', 'month', 'day', 'hour', 'minute', 'second']
period_begin[BERRIMAH1]   = create_struct(mem_names, 1992,  1,  1, 0, 0, 0)
period_begin[MCTEX_EARLY] = create_struct(mem_names, 1995, 11,  1, 0, 0, 0)
period_begin[MCTEX]       = create_struct(mem_names, 1995, 11, 25, 20, 5, 0)
period_begin[BERRIMAH2]   = create_struct(mem_names, 1996,  1,  1, 0, 0, 0)
period_begin[GUNN_PT]     = create_struct(mem_names, 1997, 10,  1, 0, 0, 0)
period_begin[GUNN_PT1]    = create_struct(mem_names, 1997, 11, 20, 3, 40, 0)
period_begin[SCSMEX]      = create_struct(mem_names, 1998,  5,  4, 0, 0, 0)
period_begin[SCSMEX1]     = create_struct(mem_names, 1998,  5, 17, 3, 47, 0)

; Determine which period the lassen volume belongs.   M. Whimpey 

vt = (vol.hdr.year-90) * 32140800UL
vt = vt + vol.hdr.month * 2678400UL
vt = vt + vol.hdr.day * 86400UL
vt = vt + vol.hdr.shour * 3600UL
vt = vt + vol.hdr.sminute * 60UL
vt = vt + vol.hdr.ssecond

for d=0,NUM_DATES-1 do begin
    dt = (period_begin[d].year-1990) * 32140800UL
    dt = dt + period_begin[d].month * 2678400UL
    dt = dt + period_begin[d].day * 86400UL
    dt = dt + period_begin[d].hour * 3600UL
    dt = dt + period_begin[d].minute * 60UL
    dt = dt + period_begin[d].second

    if vt lt dt then break
endfor

if d eq 0 then message, 'Error Vol date before first known', /continue
period = d-1
return, period
end

;******************************;
;     free_lassen_pointers     ;
;******************************;

pro free_lassen_pointers, vol

nsweeps = vol.hdr.numsweeps

for iswp = 0, nsweeps-1 do begin
    sweep = vol.sweep[iswp]
    nrays = (*sweep).hdr.numrays
    for iray = 0, nrays-1 do begin
        ptr_free, (*sweep).ray[iray]
    endfor
    ptr_free, sweep
endfor
end

;******************************;
;  get_lassen_sizes_for_radar  ;
;******************************;

pro get_lassen_sizes_for_radar, lassenvol, maxvols, nvols, nsweeps, nrays, nbins

nsweeps = lassenvol.hdr.numsweeps
nrays = 0
nbins = 0
nvols = 0
max_field_id = 0

; Get the largest quantity for each component.

for i = 0, nsweeps-1 do begin
    nrays = nrays > (*lassenvol.sweep[i]).hdr.numrays
    ray = (*lassenvol.sweep[i]).ray[0]
    nbins = nbins > (*ray).hdr.numgates
    nonzero_offs = where((*ray).hdr.offset)
    nvols = nvols > n_elements(nonzero_offs)
    max_field_id = max_field_id > max(nonzero_offs)
endfor
maxvols = max_field_id + 1

end

;******************************;
;   load_lassen_header_info    ;
;******************************;

pro load_lassen_header_info, lassenvol, radar

radar.h.month  = lassenvol.hdr.month
radar.h.day    = lassenvol.hdr.day
radar.h.year   = lassenvol.hdr.year + 1900
radar.h.hour   = lassenvol.hdr.shour
radar.h.minute = lassenvol.hdr.sminute
radar.h.sec    = lassenvol.hdr.ssecond
radar.h.radar_type = 'lassen'
radar.h.state = 'AU'
radar.h.radar_name = string(lassenvol.hdr.radar_name)
radar.h.name = string(lassenvol.hdr.site_name)

radar.h.latd = lassenvol.hdr.latdeg
radar.h.latm = lassenvol.hdr.latmin
radar.h.lats = lassenvol.hdr.latsec
if radar.h.latd lt 0 then begin
    if radar.h.latm gt 0 then radar.h.latm = -radar.h.latm
    if radar.h.lats gt 0 then radar.h.lats = -radar.h.lats
endif
radar.h.lond = lassenvol.hdr.londeg
radar.h.lonm = lassenvol.hdr.lonmin
radar.h.lons = lassenvol.hdr.lonsec
if radar.h.lond lt 0 then begin
    if radar.h.lonm gt 0 then radar.h.lonm = -radar.h.lonm
    if radar.h.lons gt 0 then radar.h.lons = -radar.h.lons
endif

radar.h.height  = lassenvol.hdr.antenna_height

end

;******************************;
;      load_lassen_rays        ;
;******************************;

; Note: This function is essentially a translation from C to IDL of the
; function lassen_load_sweep from lassen_to_radar.c.
; The original C program was written by John Merritt.

pro load_lassen_rays, sweep, iswp, period, freq, vol_prf, no_data, radar

TEST = 0 ; set to return unconverted data.
if TEST and iswp eq 0 then message,'Testing: no data conversion.',/information

; Calibration period flags.   M. Whimpey

BERRIMAH1 = 0
MCTEX_EARLY = 1
MCTEX = 2
BERRIMAH2 = 3
GUNN_PT = 4
GUNN_PT1 = 5
SCSMEX = 6
SCSMEX1 = 7

; Offsets:
; Lassen fields are stored in a constant order.  The offset array contains
; the starting locations of data for the corresponding fields within
; the ray as read from Lassen file.  When a field is not present, an offset
; of zero is used.
;
; Offset subscripts from lassen.h:

UZ  = 0
CZ  = 1
VEL  = 2
WID = 3
ZDR = 4
PHI = 5
RHO = 6
LDR = 7
KDP = 8
TIME = 9

rsl_speed_of_light = 299792458.0
beamwidth = 0.96

; Note: Lassen frequency is stored as MHz * 10

Vu = rsl_speed_of_light*(float(vol_prf)/10.)/(4.*float(freq)*100000.0)

maxvols = n_elements(radar.volume)

for iray = 0, (*sweep).hdr.numrays-1 do begin
    ray = (*sweep).ray[iray]
    offset = (*ray).hdr.offset
    numgates = (*ray).hdr.numgates

;   Get the subscripts of nonzero offsets.  Zero valued offsets represent
;   unused fields.

    nonzero_offs = where(offset)

;   Load ray header.

    nzo = nonzero_offs
    radar.volume[nzo].sweep[iswp].ray[iray].h.month = (*ray).hdr.month
    radar.volume[nzo].sweep[iswp].ray[iray].h.day = (*ray).hdr.day
    radar.volume[nzo].sweep[iswp].ray[iray].h.year = (*ray).hdr.year
    radar.volume[nzo].sweep[iswp].ray[iray].h.minute= (*ray).hdr.minute
    radar.volume[nzo].sweep[iswp].ray[iray].h.sec = (*ray).hdr.second
    radar.volume[nzo].sweep[iswp].ray[iray].h.azimuth = $
        float((*ray).hdr.vangle) * 360.0/16384.0
    radar.volume[nzo].sweep[iswp].ray[iray].h.elev = $
        float((*ray).hdr.fanglet) * 360.0/16384.0
    radar.volume[nzo].sweep[iswp].ray[iray].h.fix_angle = $
        float((*ray).hdr.fanglet) * 360.0/16384.0
    radar.volume[nzo].sweep[iswp].ray[iray].h.nbins = (*ray).hdr.numgates
    radar.volume[nzo].sweep[iswp].ray[iray].h.ray_num = iray + 1
    radar.volume[nzo].sweep[iswp].ray[iray].h.elev_num = (*ray).hdr.sweep
    radar.volume[nzo].sweep[iswp].ray[iray].h.range_bin1 = (*ray).hdr.rangeg1 
    radar.volume[nzo].sweep[iswp].ray[iray].h.gate_size = (*ray).hdr.gatewid
    radar.volume[nzo].sweep[iswp].ray[iray].h.frequency = freq * 1.0e-4 ; GHz
    radar.volume[nzo].sweep[iswp].ray[iray].h.wavelength = $
        rsl_speed_of_light / freq * 1.0e-5 ; meters
    prf = (*ray).hdr.prf/10
    radar.volume[nzo].sweep[iswp].ray[iray].h.prf = prf
    radar.volume[nzo].sweep[iswp].ray[iray].h.nyq_vel = prf * $
        radar.volume[nzo].sweep[iswp].ray[iray].h.wavelength / 4.0
    if prf ne 0 then radar.volume[nzo].sweep[iswp].ray[iray].h.unam_rng = $
        rsl_speed_of_light  / (2.0 * prf * 1000.0) ; km 
    radar.volume[nzo].sweep[iswp].ray[iray].h.pulse_width  = $
        (*ray).hdr.p_width * 0.05
    radar.volume[nzo].sweep[iswp].ray[iray].h.pulse_count = (*ray).hdr.n_pulses
    radar.volume[nzo].sweep[iswp].ray[iray].h.beam_width = beamwidth
    ;radar.volume[nzo].sweep[iswp].ray[iray].h.vel_res = ?
    ;radar.volume[nzo].sweep[iswp].ray[iray].h.sweep_rate = ?

;   Put ray data into an array padded to first offset.  (In the Lassen file
;   each ray is stored as a ray header followed by ray data, the first offset
;   being equal to the length of the ray header.)

    ray_data = [bytarr(offset[nonzero_offs[0]]), (*ray).data]

;   Fill ray for each field.
    for ivol = 0, maxvols-1 do begin
        if offset[ivol] eq 0 then continue
	;; TEST ray filling with unconverted data.
	;;radar.volume[ivol].sweep[iswp].ray[iray].range = $
	;;    ray_data[offset[ivol]:offset[ivol]+numgates-1]
	field_data = ray_data[offset[ivol]:offset[ivol]+numgates-1]
	ifield = ivol
	if ifield eq CZ then ifield = UZ ; same conversion.
	;;
	  if TEST then ifield = 10 ; for testing, skip conversion.
	;;
	case ifield of
	    UZ: begin
	        if period eq BERRIMAH1 then begin
                    radar_ray_data = (float(field_data) - 56.0)/2.0
		endif else begin
                    radar_ray_data = (float(field_data) - 64.0)/2.0
	        endelse
	    end
	    VEL: begin ; Velocity (VR)
	        if period eq BERRIMAH1 then begin
                    radar_ray_data =  float(Vu*(double(field_data)-128d)/128d)
		endif else if period eq SCSMEX then begin
                    radar_ray_data = $
		        float(Vu*(double(field_data xor 128)-128d)/127d)
		endif else begin
                    radar_ray_data =  float(Vu*(double(field_data)-128d)/127d)
		endelse
	    end
	    WID: begin ; Spectrum Width (SW)
		if period eq BERRIMAH1 then begin
                    radar_ray_data = float(Vu*double(field_data)/100.)
		endif else begin 
                    radar_ray_data = float(Vu*double(field_data)/256.)
		endelse
	    end
	    ZDR: begin ; ZD field
		if period lt MCTEX_EARLY then break
		if period le BERRIMAH2 then begin
		    radar_ray_data = (float(field_data) - 64.0)/21.25
		endif else begin
		    radar_ray_data = (float(field_data) - 128.0)*18./254.
		endelse
	    end
	    PHI: begin ; PhiDP (PH)
		if period lt MCTEX_EARLY then break
		if period le BERRIMAH2 then begin
		   radar_ray_data = (float(field_data) - 128.0)*32.0/127.0
		endif else if period eq GUNN_PT then begin
		    radar_ray_data = (float(field_data) - 64.5)*360.0/254.0
		endif else if period gt GUNN_PT then begin
		    radar_ray_data = (float(field_data) - 128.0)*180.0/254.0
		endif
		radar_ray_data = radar_ray_data + 90. ; make range 0 to 180 deg
	    end
	    RHO: begin ; RH field
		if period lt MCTEX_EARLY then break
		if period le BERRIMAH2 then begin
		    radar_ray_data = sqrt(float(field_data)/256.822 + 0.3108)
		endif else begin
		    radar_ray_data = ((float(field_data)-1.)*1.14/254.) + 0.01
		endelse
	    end
	    KDP: begin
	        radar_ray_data = float(field_data)
	    end
	    LDR: begin
	        radar_ray_data = (float(field_data) - 250.)/6.
	    end
	;; TODO: print a single message for any field not covered in the
	;; case-statement.
	else: radar_ray_data = float(field_data)
	endcase
	s = where(field_data eq 0, count)
	if not TEST then $
	if count gt 0 then radar_ray_data[s] = no_data
	radar.volume[ivol].sweep[iswp].ray[iray].range = radar_ray_data
    endfor ;  for each field
endfor ; each ray

end

;******************************;
;     load_lassen_sweeps       ;
;******************************;

pro load_lassen_sweeps, lassenvol, period, radar, quiet

lassfield = ['UZ','CZ','Vel','Wid','Zdr','Phi','Rho','Ldr','Kdp','Time']
rslfield =  ['ZT','DZ','VR','SW','ZD','PH','RH','LR','KD','TI']

nsweeps = lassenvol.hdr.numsweeps
freq = lassenvol.hdr.freq
prf =  lassenvol.hdr.prf
no_data = -32767.

if keyword_set(quiet) then doprint = 0 else doprint = 1

if doprint then print, format='($,/"Loading sweep")'

for iswp = 0, nsweeps-1 do begin
    sweep = lassenvol.sweep[iswp]
    if doprint then print, format='($,i4)', iswp + 1
    load_lassen_rays, sweep, iswp, period, freq, prf, no_data, radar

;    Get field IDs from first ray.
    offset = (*(*sweep).ray[0]).hdr.offset
    volindex = where(offset)

;    Load radar sweep header.
    radar.volume.sweep[iswp].h.sweep_num = (*sweep).hdr.sweepnum
    radar.volume.sweep[iswp].h.elev = (*sweep).hdr.fangle * 360.0/16384.0
    radar.volume[volindex].sweep[iswp].h.field_type = rslfield[volindex]
    radar.volume[volindex].sweep[iswp].h.nrays = (*sweep).hdr.numrays
    beamwidth = radar.volume[volindex].sweep[iswp].ray[0].h.beam_width
    radar.volume[volindex].sweep[iswp].h.beam_width = beamwidth
    radar.volume[volindex].sweep[iswp].h.vert_half_bw = beamwidth/2.
    radar.volume[volindex].sweep[iswp].h.horz_half_bw = beamwidth/2.
    radar.volume[volindex].h.nsweeps = radar.volume[volindex].h.nsweeps + 1 
endfor ; sweeps

radar.volume.h.field_type = radar.volume.sweep[0].h.field_type
radar.volume.h.no_data_flag = no_data
if doprint then print ; Print newline after using '$' format code.
end

;******************************;
;     rsl_lassen_to_radar      ;
;******************************;

function rsl_lassen_to_radar, lassenfile, error=error, quiet=quiet

; Read Lassen formatted data and return it in the Radar structure.
;

on_error, 2

radar = -1
error = 0
if not keyword_set(quiet) then quiet = 0

rsl_read_lassen_file, lassenfile, lassenvol, error
if error then goto, finished

period = lassen_period(lassenvol)
if period lt 0 then begin
    error = 1
    goto, finished
endif

get_lassen_sizes_for_radar, lassenvol, maxvols, nvols, nsweeps, nrays, nbins
radar = rsl_new_radar(maxvols, nsweeps, nrays, nbins)
radar.h.nvolumes = nvols
load_lassen_header_info, lassenvol, radar
load_lassen_sweeps, lassenvol, period, radar, quiet

finished: free_lassen_pointers, lassenvol
return, radar
end
