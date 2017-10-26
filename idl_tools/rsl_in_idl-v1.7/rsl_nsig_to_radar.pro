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
; rsl_nsig_to_radar
;
; Read a SIGMET Raw Product file and return data in a Radar structure.
;
; Syntax:
;     radar = rsl_nsig_to_radar(sigmet_raw_product_file
;                 [, ERROR=variable] [, MAXSWEEPS=integer] [, /CATCH_ERROR]
;                 [, FIELDS=string_array] [, /KEEP_RADAR] [, /QUIET])
;
; Inputs:
;     sigmet_raw_product_file: name of SIGMET Raw Product file.
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
;     FIELDS: string scalar or array containing fields to be processed.
;         Default: all fields.  Fields are of the form of the 2-character names
;         used by RSL and UF, such as 'DZ', 'VR', etc.
;     KEEP_RADAR:
;         Set this keyword to return the radar structure if an error
;         occurs.  If an error occurs and this is not set, -1 is returned.
;     MAXSWEEPS:
;         Maximum number of sweeps to read from volume scan.
;         Default: all sweeps.
;     QUIET: Set this keyword to turn off progress reporting.
;
; Return Value:
;     A radar structure is returned unless an error occurs, in which case
;     the return value is -1.
;
; Written by:  Bart Kelley, GMU, June 2003
;
; Adapted from the RSL nsig_to_radar programs written by John Merritt of SM&A
; Corporation and Paul Kucera, formerly of Applied Research Corporation.
;***********************************************************************
;-

;***************************;
;  nsig_convert_angle_long  ;
;***************************;

function nsig_convert_angle_long, bin_angle

; Convert binary angle in long integer (4 bytes) to degrees.

compile_opt hidden
max_bin_angle = 4294967296.0d ;  = 2^32
return, float(bin_angle/max_bin_angle * 360.0d)
end

;****************************;
;  nsig_convert_angle_short  ;
;****************************;

function nsig_convert_angle_short, bin_angle

; Convert binary angle in short integer (2 bytes) to degrees.

compile_opt hidden
max_bin_angle = 65536.0d ; = 2^16
return, float(bin_angle/max_bin_angle * 360.0d)
end

;***************************;
;        nsig_getkdp        ;
;***************************;

function nsig_getkdp, raydata, wavelen_cm

; Compute KDP (specific differential phase).

compile_opt hidden
kdp = fltarr(n_elements(raydata))
posvalues = where(raydata gt 128, poscnt)
negvalues = where(raydata lt 128, negcnt)
zerovalues = where(raydata eq 128, zerocnt)
if poscnt gt 0 then kdp(posvalues)= 0.25 * 600.^((raydata(posvalues)-129)/126.)
if negcnt gt 0 then kdp(negvalues) = -0.25*600.^((127-raydata(negvalues))/126.)
if zerocnt gt 0 then kdp(zerovalues) = 0.
return, kdp/wavelen_cm
end

;****************************;
;      nsig_get_ext_hdr      ;
;****************************;

function nsig_get_ext_hdr, nsig_ray, xh_size, needswap

; Get extended header information.

compile_opt hidden
common nsig_ver, nsig_ver
msec = long(nsig_ray.data,0)
; If byteswap is needed, first have to reverse the two-byte swap that was done
; when record was read, then do a four-byte swap.
if needswap then begin
    byteorder,msec,/sswap ; reverse the previous shortword swap.
    byteorder,msec,/lswap ; do a longword swap.
endif
if xh_size gt 20 then begin ; extended header v1
    ext_hdr = { $
      msec:0L,			$
      azm:0,			$
      elev:0,			$
      pitch:0.0,		$
      roll:0.0,			$
      heading:0.0,		$
      azm_rate:0.0,		$
      pitch_rate:0.0,		$
      roll_rate:0.0,		$
      heading_rate:0.0,		$
      lat:0.0,			$
      lon:0.0,			$
      alt:0,			$
      vel_east:0.0,		$
      vel_north:0.0,		$
      vel_up:0.0,		$
      radial_vel_corr:0.0	$
    }
    raydata = nsig_ray.data
    ext_hdr.azm = nsig_convert_angle_short(raydata[3])
    ext_hdr.elev = nsig_convert_angle_short(raydata[4])
    ext_hdr.pitch = nsig_convert_angle_short(raydata[7])
    ext_hdr.roll = nsig_convert_angle_short(raydata[8])
    ext_hdr.heading = nsig_convert_angle_short(raydata[9])
    ext_hdr.azm_rate = nsig_convert_angle_short(raydata[10])
    ext_hdr.pitch_rate = nsig_convert_angle_short(raydata[12])
    ext_hdr.roll_rate = nsig_convert_angle_short(raydata[13])
    if nsig_ver eq 2 then begin
        lat_offset = 28
        ext_hdr.heading_rate = raydata[18]
    endif else begin
        lat_offset = 30
        ext_hdr.heading_rate = raydata[14]
    endelse
    lat = long(raydata,lat_offset)
    lon = long(raydata,lat_offset+4)
    if needswap then begin
        ; reverse the shortword swap.
	byteorder, lat, /sswap
	byteorder, lon, /sswap
	; do longword swap.
	byteorder, lat, /lswap
	byteorder, lon, /lswap
    endif
    ext_hdr.lat = nsig_convert_angle_long(lat)
    ext_hdr.lon = nsig_convert_angle_long(lon)
    i = 19
    ext_hdr.alt = raydata[i]
    ext_hdr.vel_east = raydata[i+1]/100.
    ext_hdr.vel_north = raydata[i+2]/100.
    ext_hdr.vel_up = raydata[i+5]/100.
    ext_hdr.radial_vel_corr = raydata[i+7]/100.
endif else ext_hdr = {msec:0L} ; extended header v0

ext_hdr.msec = msec
return, ext_hdr
end ; nsig_get_ext_hdr

;****************************;
;       nsig_get_ray         ;
;****************************;

function nsig_get_ray, iunit, sweepnum, nbins, last_ray

; Get next ray from buffer and decompress its data.  The decompressed ray is
; returned.
;
; Note: Decompression is done on two-byte words, although actual data may be
; one-byte or two-byte values.
;
; TODO: Add notes on how a ray is read, including a table of decompression
; codes as in C version.

compile_opt hidden
common nsig_buffer, buf, pos, needswap 

datamask = '7fff'X ; used in decoding IRIS raw product data compression.
bhdrsize = 6
rayhdr_size = 6

ibin = 0
bufsize = n_elements(buf)
nremaining = 0
end_of_ray = 1
last_ray = 0

ray = intarr(rayhdr_size + nbins)
code = buf[pos]
if needswap then byteorder, code, /sswap
while code ne end_of_ray do begin
    if code lt 0 then begin ; this indicates data.
	nwords = code and datamask ; decode data count.
	; Put next N words into nsig_ray.
	; Handle case where current position + N exceeds buffer size.
	if pos + nwords ge bufsize then begin
	    nremaining = nwords
	    nwords = bufsize - (pos + 1) 
	    nremaining = nremaining - nwords
	endif
	if nwords gt 0 then begin
	    ray[ibin:ibin+nwords-1] = buf[pos+1:pos+nwords]
	    pos = pos + nwords
	    ibin = ibin + nwords
	endif
	if nremaining gt 0 then begin ; ray is continued in next buffer
	    readu, iunit, buf
	    bhdr = buf[0:5]
	    if needswap then byteorder, bhdr, /sswap
	    buf[0:5] = bhdr
	    if buf[1] ne sweepnum then message, string(sweepnum, buf[1], $
		format='("Sweep number changed from",i4," to",i4,'+ $
		       '" before ray processing completed.")')
	    pos = bhdrsize - 1
	    nwords = nremaining
	    ray[ibin:ibin+nwords-1] = buf[pos+1:pos+nwords]
	    pos = pos + nwords
	    ibin = ibin + nwords
	    nremaining = 0
	endif
    endif else if code gt 1 then begin
        ; Put N zeros into nsig_ray
	nwords = code
	ray[ibin:ibin+nwords-1] = 0
	ibin = ibin + nwords
    endif

    ; If end of buffer reached, read in next record.
    pos = pos + 1
    if pos eq bufsize then begin
	readu, iunit, buf
	bhdr = buf[0:5]
	if needswap then byteorder, bhdr, /sswap
	buf[0:5] = bhdr
	pos = bhdrsize
    endif
    code = buf[pos]
    if needswap then byteorder, code, /sswap
endwhile ; while not end of ray

pos = pos + 1
if pos eq bufsize then begin
    if not eof(iunit) then begin
	readu, iunit, buf
	bhdr = buf[0:5]
	if needswap then byteorder, bhdr, /sswap
	buf[0:5] = bhdr
	pos = bhdrsize
    endif else begin
        pos = pos - 1
	last_ray = 1
    endelse
endif
nsig_ray = {h:{nsig_ray_header}, data:intarr(n_elements(ray)-rayhdr_size)}
rayhdr = ray[0:5]
if needswap then byteorder, rayhdr, /sswap
nsig_ray.h.begin_azm =  rayhdr[0]
nsig_ray.h.begin_elev = rayhdr[1]
nsig_ray.h.end_azm =    rayhdr[2]
nsig_ray.h.end_elev =   rayhdr[3]
nsig_ray.h.actual_nbins = rayhdr[4]
nsig_ray.h.sec = rayhdr[5]
nsig_ray.data = ray[rayhdr_size:n_elements(ray)-1]
return, nsig_ray
end ; nsig_get_ray

;****************************;
;    nsig_sweep_to_radar     ;
;****************************;

function nsig_sweep_to_radar, iunit, isweep, nparams, rayinfo, xh_size, $
    ivol_dtype, radar

compile_opt hidden
common nsig_buffer, buf, pos, needswap 

rsl_speed_of_light = 299792458.0
azim_rate = 15.

; SIGMET Radar Data Type Constants
; For a complete list see "IRIS Programmer's Manual", section 3.8.
; The following were adapted from nsig.h (RSL in C).

EXH    =  0 ; Extended header
UCR    =  1 ; Total power (dBZ) (1 byte)
CR     =  2 ; Reflectivity (dBZ) (1 byte)
VEL    =  3 ; Mean velocity (1 byte)
WID    =  4 ; Spectrum width (1 byte)
ZDR    =  5 ; Differential reflectivity (1 byte)
UCR2   =  8 ; Total power (dBZ)  (2 byte)
CR2    =  9 ; Reflectivity (dBZ) (2 byte)
VEL2   = 10 ; Mean velocity (2 byte)
WID2   = 11 ; Spectrum width (2 byte)
ZDR2   = 12 ; Differential reflectivity (2 byte)
KDP    = 14 ; Specific differential phase (degrees/kilometer) (1 byte)
KDP2   = 15 ; Specific differential phase (degrees/kilometer) (2 byte)
PHIDP  = 16 ; Differential phase angle (deg) (1 byte)
SQI    = 18 ; Signal Quality Index (1 byte)
RHOHV  = 19 ; Horizontal-Vertical power correlation coefficient (2 byte)
RHOHV2 = 20 ; Horizontal-Vertical power correlation coefficient (2 byte)
DBZC2  = 21 ; Corrected reflectivity (2 byte)
SQI2   = 23 ; Signal Quality Index (2 byte)
PHIDP2 = 24 ; Differential phase angle (deg) (2 byte)
ZDRC2  = 58 ; Corrected differential reflectivity (2 byte)
DBTV   = 62 ; Total power vertical channel (dBZ) (2 byte)
DBZV   = 64 ; Corrected reflectivity vertical channel (2 byte)
SNR    = 66 ; Signal to noise ratio (dB) (2 byte)

LDH    = 26 ; /* LDR H to V (2 byte) */
LDV    = 28 ; /* LDR V to H (2 byte) */
RHH    = 47 ; /* Rho H to V (2 byte) */
RHV    = 49 ; /* Rho V to H (2 byte) */
PHH    = 51 ; /* Phi H to V (2 byte) */
PHV    = 53 ; /* Phi V to H (2 byte) */

bhdr={nsig_raw_prod_bhdr}
ingest_data_hdr = replicate({nsig_ingest_data_header}, nparams)
len_hdrs = n_tags(bhdr,/length) + n_tags(ingest_data_hdr,/length) * nparams
len_hdrs = len_hdrs / 2L
firstdata = intarr(n_elements(buf) - len_hdrs) ; data of first record in sweep.
no_data = -32767.
bufsize = n_elements(buf) * 2

; Read headers at beginning of sweep.
readu, iunit, bhdr
readu, iunit, ingest_data_hdr
if needswap then byteorder, bhdr, /sswap
sec = ingest_data_hdr.time.sec_of_day
if needswap then byteorder, sec, /lswap
if needswap then byteorder, ingest_data_hdr, /sswap
if ingest_data_hdr[0].struct_head.id eq 0 then begin
    print ; new line
    message,'Invalid structure header ID = '+$
        strtrim(ingest_data_hdr[0].struct_head.id,1)+$
	' in sweep '+strtrim(isweep+1,1)+'. Processing ending for this file.',$
	/continue
    return, -1
endif

; Convert seconds since midnight to hours-minutes-seconds.  This is the time at
; beginning of sweep.
hour = sec/3600
minute = (sec - hour*3600L)/60L
seconds = float(sec - (hour*3600L + minute*60L))
; Add milliseconds to seconds.
low10bits =  '3FF'XU
msec = float(ingest_data_hdr.time.msec and low10bits)
; Note: C version of RSL doesn't add msec from ingest header.
seconds = seconds + msec/1000.

readu, iunit, firstdata
; Pad front of buf where headers would be and append firstdata to build record.
buf = [intarr(len_hdrs), firstdata]
; Copy bhdr information to buf (we need sweep number in buf).
for i = 0,5 do buf[i] = bhdr.(i)
pos = len_hdrs
sweepnum = bhdr.sweep_num
datatype = ingest_data_hdr.data_type
bits_per_bin = ingest_data_hdr.bits_bin
wavelen = rayinfo.wavelen_cm / 100. ; Convert to meters.
max_vel = (wavelen * rayinfo.prf)/4.
vel_factor1 = max_vel / 127. 
vel_factor2 = max_vel * (1.0 - 255./127.)


if isweep eq 0 then radar.volume.h.no_data_flag = no_data

end_of_sweep = 0
iray = -1

while not end_of_sweep do begin
    ivol = -1
    iray = iray + 1

    ; Get ray for each parameter (field).
    for iparam = 0, nparams-1 do begin
        nsig_ray = nsig_get_ray(iunit, sweepnum, rayinfo.numbins, last_ray)
	; If ray is extended header, get info and go to next parameter.
	if datatype[iparam] eq EXH then begin
	    ext_hdr = nsig_get_ext_hdr(nsig_ray, xh_size, needswap)
	    goto, NEXT
	endif
	ivol = where(datatype[iparam] eq ivol_dtype)
	if ivol[0] eq -1 then goto, NEXT
	if bits_per_bin[iparam] eq 8 then begin
	    raydata = byte(nsig_ray.data, 0, rayinfo.numbins) ; one-byte bins.
	endif else if bits_per_bin[iparam] eq 16 then begin
	    raydata = nsig_ray.data[0:rayinfo.numbins-1] ; two-byte bins.
	    ; Only two-byte data needs to be byte swapped.
	    if needswap then byteorder, raydata, /sswap
	endif else begin
	    message,'Invalid bin size: bits_per_bin = ' + $
	        strtrim(bits_per_bin[iparam],1),/continue
	    print,'Sigmet radar data type = ',strtrim(datatype[iparam],1)
	    return, -1
	endelse

	; Unpack data for this field and store in radar structure.
	; (Note: If adding a new field: Sigmet uses zero to indicate
	; no-data for all field types we currently use, but not not
	; for all Sigmet fields.  Check the Sigmet Programmer's Guide
	; before adding any new fields to make sure.)

	dataloc = where(raydata ne 0, datacnt) ; elements with data.
	zeroloc = where(raydata eq 0, zerocnt) ; elements with no data.

	if zerocnt gt 0 then $
	    radar.volume[ivol].sweep[isweep].ray[iray].range[zeroloc] = no_data
	if datacnt gt 0 then begin
	    case datatype[iparam] of
	      UCR: radar.volume[ivol].sweep[isweep].ray[iray].range[dataloc] = $
		     (float(raydata[dataloc])-64.)/2.
	      CR:  radar.volume[ivol].sweep[isweep].ray[iray].range[dataloc] = $
		    (float(raydata[dataloc])-64.)/2.
	      VEL: radar.volume[ivol].sweep[isweep].ray[iray].range[dataloc] = $
		     float(raydata[dataloc])*vel_factor1 + vel_factor2 
	      WID: radar.volume[ivol].sweep[isweep].ray[iray].range[dataloc] = $
		     (float(raydata[dataloc])/256.)*max_vel
	      ZDR: radar.volume[ivol].sweep[isweep].ray[iray].range[dataloc] = $
		     (float(raydata[dataloc])-128.)/16.
	      UCR2: radar.volume[ivol].sweep[isweep].ray[iray].range[dataloc]= $
		     (uint(raydata[dataloc])-32768.)/100.
	      CR2: radar.volume[ivol].sweep[isweep].ray[iray].range[dataloc] = $
		     (uint(raydata[dataloc])-32768.)/100.
	      VEL2: radar.volume[ivol].sweep[isweep].ray[iray].range[dataloc]= $
		     (uint(raydata[dataloc])-32768.)/100.
	      WID2: radar.volume[ivol].sweep[isweep].ray[iray].range[dataloc]= $
		     uint(raydata[dataloc])/100.
	      ZDR2: radar.volume[ivol].sweep[isweep].ray[iray].range[dataloc]= $
		     (uint(raydata[dataloc])-32768.)/100.
	      KDP: radar.volume[ivol].sweep[isweep].ray[iray].range[dataloc] = $
		     nsig_getkdp(raydata[dataloc], rayinfo.wavelen_cm)
	      KDP2: radar.volume[ivol].sweep[isweep].ray[iray].range[dataloc]= $
		     (uint(raydata[dataloc])-32768.)/100.
	      PHIDP: radar.volume[ivol].sweep[isweep].ray[iray].range[dataloc]=$
		       180.*(float(raydata[dataloc])-1.)/254.0
	      PHIDP2:radar.volume[ivol].sweep[isweep].ray[iray].range[dataloc]=$
		       360.*(uint(raydata[dataloc])-1.)/65534.0
	      PHH: radar.volume[ivol].sweep[isweep].ray[iray].range[dataloc]=$
		       360.*(uint(raydata[dataloc])-1.)/65534.0
	      PHV: radar.volume[ivol].sweep[isweep].ray[iray].range[dataloc]=$
		       360.*(uint(raydata[dataloc])-1.)/65534.0
	      RHOHV: radar.volume[ivol].sweep[isweep].ray[iray].range[dataloc]=$
		       sqrt((raydata[dataloc]-1)/253.)
	      RHOHV2:radar.volume[ivol].sweep[isweep].ray[iray].range[dataloc]=$
		       (uint(raydata[dataloc])-1)/65533.
              RHH: radar.volume[ivol].sweep[isweep].ray[iray].range[dataloc]=$
		       (uint(raydata[dataloc])-1)/65533.
              RHV: radar.volume[ivol].sweep[isweep].ray[iray].range[dataloc]=$
		       (uint(raydata[dataloc])-1)/65533.
	      LDH: radar.volume[ivol].sweep[isweep].ray[iray].range[dataloc]= $
		     (uint(raydata[dataloc])-32768.)/100.
	      LDV: radar.volume[ivol].sweep[isweep].ray[iray].range[dataloc]= $
		     (uint(raydata[dataloc])-32768.)/100.
	      DBZC2:radar.volume[ivol].sweep[isweep].ray[iray].range[dataloc] =$
		     (uint(raydata[dataloc])-32768.)/100.
	      SQI:   radar.volume[ivol].sweep[isweep].ray[iray].range[dataloc]=$
		       sqrt(float(raydata[dataloc]-1)/253.)
	      SQI2:  radar.volume[ivol].sweep[isweep].ray[iray].range[dataloc]=$
		       (uint(raydata[dataloc])-1)/65533.
	      ZDRC2:radar.volume[ivol].sweep[isweep].ray[iray].range[dataloc]= $
		     (uint(raydata[dataloc])-32768.)/100.
	      DBTV: radar.volume[ivol].sweep[isweep].ray[iray].range[dataloc]= $
		     (uint(raydata[dataloc])-32768.)/100.
	      DBZV: radar.volume[ivol].sweep[isweep].ray[iray].range[dataloc]= $
		     (uint(raydata[dataloc])-32768.)/100.
	       SNR: radar.volume[ivol].sweep[isweep].ray[iray].range[dataloc]= $
		     (uint(raydata[dataloc])-32768.)/100.
	      else: radar.volume[ivol].sweep[isweep].ray[iray].range[dataloc]=$
		      float(raydata[dataloc])
		    ; Note: hydrometeor class falls to this default, which is
		    ; alright since it is integer valued.
	    endcase
	endif
	; Store parameter-dependent (presumably) ray header items here.
	radar.volume[ivol].sweep[isweep].ray[iray].h.nbins = $
	    nsig_ray.h.actual_nbins
    NEXT:
    endfor ; nparams

    ; These ray header items are the same for all parameters.

    ; Compute mean azimuth angle.
    begin_azm = nsig_convert_angle_short(nsig_ray.h.begin_azm)
    end_azm =  nsig_convert_angle_short(nsig_ray.h.end_azm)
    if begin_azm gt end_azm then begin
        if begin_azm - end_azm gt 180. then end_azm = end_azm + 360.
    endif else if end_azm - begin_azm gt 180. then begin_azm = begin_azm + 360.
    mean_azm = (begin_azm + end_azm) / 2.
    if mean_azm gt 360. then mean_azm = mean_azm - 360.
    if mean_azm lt 0. then mean_azm = mean_azm + 360.
    ; If ray has no data then use a fill value for azimuth.
    if  radar.volume[0].sweep[isweep].ray[iray].h.nbins eq 0 then $
        mean_azm = -99999.0
    radar.volume.sweep[isweep].ray[iray].h.azimuth = mean_azm
    ; Compute mean elevation angle.
    begin_elev = nsig_convert_angle_short(nsig_ray.h.begin_elev)
    end_elev = nsig_convert_angle_short(nsig_ray.h.end_elev)
    if begin_elev gt end_elev then begin
        if begin_elev - end_elev gt 180. then begin_elev = begin_elev - 360.
    endif else if end_elev - begin_elev gt 180. then end_elev = end_elev - 360.
    mean_elev = (begin_elev + end_elev) / 2.
    if mean_elev gt 360. then mean_elev = mean_elev - 360.
   ;if mean_elev lt 0. then mean_elev = mean_elev + 360.
    radar.volume.sweep[isweep].ray[iray].h.elev = mean_elev

    nfields = n_elements(ivol_dtype)
    ing_indx = intarr(nfields)
    for i=0,nfields-1 do ing_indx[i] = where(ivol_dtype[i] eq datatype)
    radar.volume.sweep[isweep].ray[iray].h.month = ingest_data_hdr[ing_indx].time.month
    radar.volume.sweep[isweep].ray[iray].h.day   = ingest_data_hdr[ing_indx].time.day
    radar.volume.sweep[isweep].ray[iray].h.year  = ingest_data_hdr[ing_indx].time.year
    radar.volume.sweep[isweep].ray[iray].h.hour  = hour[ing_indx]
    radar.volume.sweep[isweep].ray[iray].h.minute= minute[ing_indx]
    radar.volume.sweep[isweep].ray[iray].h.sec = seconds[ing_indx] + nsig_ray.h.sec
    radar.volume.sweep[isweep].ray[iray].h.ray_num = iray + 1
    ; if extended header info is available, load it into ray.h.
    if n_elements(ext_hdr) gt 0 and xh_size gt 20 then begin
        radar.volume.sweep[isweep].ray[iray].h.pitch = ext_hdr.pitch
        radar.volume.sweep[isweep].ray[iray].h.roll  = ext_hdr.roll
        radar.volume.sweep[isweep].ray[iray].h.heading = ext_hdr.heading
        radar.volume.sweep[isweep].ray[iray].h.pitch_rate = ext_hdr.pitch_rate
        radar.volume.sweep[isweep].ray[iray].h.heading_rate=ext_hdr.heading_rate
        radar.volume.sweep[isweep].ray[iray].h.roll_rate = ext_hdr.roll_rate
        radar.volume.sweep[isweep].ray[iray].h.alt = ext_hdr.alt
        radar.volume.sweep[isweep].ray[iray].h.rvc = ext_hdr.radial_vel_corr
        radar.volume.sweep[isweep].ray[iray].h.vel_east = ext_hdr.vel_east
        radar.volume.sweep[isweep].ray[iray].h.vel_north = ext_hdr.vel_north
        radar.volume.sweep[isweep].ray[iray].h.vel_up = ext_hdr.vel_up
        radar.volume.sweep[isweep].ray[iray].h.lat = ext_hdr.lat
        radar.volume.sweep[isweep].ray[iray].h.lon = ext_hdr.lon
    endif
    if n_elements(ext_hdr) gt 0 then $
        radar.volume.sweep[isweep].ray[iray].h.sec = seconds[ing_indx] + $
	    ext_hdr.msec/1000.0
    if radar.volume[0].sweep[isweep].ray[iray].h.sec ge 60. then $
        rsl_fix_time, radar, isweep, iray

    ; Check for end of sweep conditions.
    if buf[pos] eq 0 or buf[1] ne sweepnum or last_ray then end_of_sweep = 1
endwhile ; while not end of sweep

fix_angle = nsig_convert_angle_short(ingest_data_hdr[ing_indx].fix_ang)
; Convert negative azimuth angles to positive for RHI.
if radar.h.scan_mode eq 'RHI' then begin
    loc = where(fix_angle lt 0., negcnt)
    if negcnt gt 0 then fix_angle[loc] = fix_angle[loc] + 360.
endif

; Store ray header info.
radar.volume.sweep[isweep].ray.h.elev_num = sweepnum
radar.volume.sweep[isweep].ray.h.range_bin1 = rayinfo.rng_first_bin 
radar.volume.sweep[isweep].ray.h.gate_size = round(rayinfo.bin_size)
radar.volume.sweep[isweep].ray.h.vel_res = rayinfo.bin_size
radar.volume.sweep[isweep].ray.h.prf = rayinfo.prf
if rayinfo.prf ne 0 then radar.volume.sweep[isweep].ray.h.unam_rng = $
    rsl_speed_of_light / (2. * rayinfo.prf * 1000.)
radar.volume.sweep[isweep].ray.h.azim_rate = azim_rate 
radar.volume.sweep[isweep].ray.h.sweep_rate = azim_rate * 60./360.
radar.volume.sweep[isweep].ray.h.fix_angle = fix_angle[0]
radar.volume.sweep[isweep].ray.h.pulse_count = rayinfo.pulsecount
radar.volume.sweep[isweep].ray.h.pulse_width = rayinfo.pulsewidth
radar.volume.sweep[isweep].ray.h.beam_width = rayinfo.beamwidth
radar.volume.sweep[isweep].ray.h.frequency = rsl_speed_of_light / wavelen * 1e-9
radar.volume.sweep[isweep].ray.h.wavelength = wavelen
radar.volume.sweep[isweep].ray.h.nyq_vel = max_vel

; Store sweep header info.
radar.volume.sweep[isweep].h.field_type = radar.volume.h.field_type
radar.volume.sweep[isweep].h.sweep_num = sweepnum
radar.volume.sweep[isweep].h.fixed_angle = fix_angle
if radar.h.scan_mode ne 'RHI' then $
    radar.volume.sweep[isweep].h.elev = fix_angle $
    else radar.volume.sweep[isweep].h.elev = $
        radar.volume[0].sweep[isweep].ray[0].h.elev 
radar.volume.sweep[isweep].h.nrays = iray + 1
radar.volume.sweep[isweep].h.beam_width = rayinfo.beamwidth
radar.volume.sweep[isweep].h.vert_half_bw = rayinfo.beamwidth / 2.
radar.volume.sweep[isweep].h.horz_half_bw = rayinfo.beamwidth / 2.
radar.volume.h.nsweeps = radar.volume.h.nsweeps + 1

; If we have the first record of a new sweep, reposition file pointer to
; beginning of record so that we can reread it into header structures.
; buf[0] contains record number.
if buf[1] ne sweepnum and not eof(iunit) then point_lun, iunit, buf[0] * bufsize
return, 1 ; normal return
end ; nsig_sweep_to_radar

;****************************;
;   field_to_nsig_datatype   ;
;****************************;

function field_to_nsig_datatype, sel_fields, ivol_dtype, field_type

;**************************************************************************
; Get Sigmet data types for field types.
;
; Inputs:
;    sel_fields: A string scalar (or array) containing field type(s).  A field
;                type is the two-letter name for the field, such as DZ or VR.
;
;    ivol_dtype: An integer array containing Sigmet data types in this
;                volume scan.  Data type is the number Sigmet uses to identify
;                a field.
; 
; Return value:
;    An integer array containing data types for given fields.  If no
;    corresponding data types were found, -1 is returned.
;**************************************************************************

compile_opt hidden

sel_dtypes = intarr(n_elements(sel_fields))

; Get list of fields for given datatypes.
fieldnames = field_type[ivol_dtype]

; Match selected fields to datatypes.
j = 0
for i = 0, n_elements(sel_fields)-1 do begin
    index = where(sel_fields[i] eq fieldnames)
    if index[0] gt -1 then begin
        sel_dtypes[j] = ivol_dtype[index]
	j = j + 1
    endif
endfor
if j gt 0 then sel_dtypes = sel_dtypes[0:j-1] else sel_dtypes = -1
return, sel_dtypes
end

;***************************;
;     rsl_nsig_to_radar     ;
;***************************;

function rsl_nsig_to_radar, nsig_file, quiet=quiet, error=error, $
    catch_error=catch_error, keep_radar=keep_radar, maxsweeps=maxsweeps, $
    fields=fields

; Read a SIGMET raw product file and return data in a Radar structure.
;
;----------------------------------------------------------------------
; Note:
; The difference between SIGMET Version 1 and Version 2 is stated in the C
; version of rsl in CHANGES, section beginning, "v1.0 Began 04/19/96.
; Released: 8/18/96": 
;
;   . . . Version 2 files are generated on big-endian machines
;   (so far, SGI Iris computers), whereas, Version 1 files were
;   written on little-endian DEC computers.
;
; This should not be confused with SIGMET Raw Product Extended Header versions,
; which are v0 and v1, and have nothing to do with which platform the file is
; generated on.
;----------------------------------------------------------------------

common nsig_buffer, buf, pos, needswap
common nsig_ver, nsig_ver
nsig_blocksize_bytes = 6144
buf = intarr(nsig_blocksize_bytes / 2)

KWAJ_BEAMWIDTH = 1.0
MIT_BEAMWIDTH  = 1.65
TOGA_BEAMWIDTH = 1.65
DEFAULT_BEAMWIDTH = 1.0

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
    message,'Error occurred while processing file '+nsig_file+'.',/informational
    error = 1
    if not keep_radar then radar = -1
    goto, finished
endif
if not catch_error then catch, /cancel ; Cancel error handler.

iunit = rsl_open_radar_file(nsig_file, error=error)
if error then goto, finished

; Read first 2 bytes and test to determine nsig version.
nsigid = bytarr(2)
readu, iunit, nsigid
if (nsigid[0] eq 0 and nsigid[1] eq 27) or $
    (nsigid[0] eq 27 and nsigid[1] eq 0) then nsig_ver = 2 $
else if (nsigid[0] eq 7 and nsigid[1] eq 0) or $
        (nsigid[0] eq 0 and nsigid[1] eq 7) then nsig_ver = 1 $
else begin
    message, 'First two bytes of file do not contain valid Sigmet ID',/continue
    goto, finished
endelse
point_lun, iunit, 0 ; rewind file

; Define version dependent structures.
if nsig_ver eq 2 then nsig_v2_define_structs else nsig_v1_define_structs

; Determine if byte-swapping is needed.  This is necessary if data was
; written on a machine with different endian than current one.
big_endian_data = nsigid[0] eq 0 and nsigid[1] gt 6
big_endian_1 = bytarr(4)
big_endian_1[3] = 1
big_endian_machine = long(big_endian_1,0) eq 1L
needswap = big_endian_data xor big_endian_machine

; Read header records (first 2 records).
product_hdr = {nsig_record1}
readu, iunit, product_hdr
ingest_hdr = {nsig_record2}
readu, iunit, ingest_hdr

; Before doing 2-byte swapping on record, extract all 4-byte and string values
; needed.
masks = ulonarr(5)
masks[0] = ingest_hdr.task_config.dsp_info.data_mask_cur.mask_word_0
masks[1] = ingest_hdr.task_config.dsp_info.data_mask_cur.mask_word_1
masks[2] = ingest_hdr.task_config.dsp_info.data_mask_cur.mask_word_2
masks[3] = ingest_hdr.task_config.dsp_info.data_mask_cur.mask_word_3
masks[4] = ingest_hdr.task_config.dsp_info.data_mask_cur.mask_word_4
sec = ingest_hdr.ingest_head.start_time.sec_of_day
radar_lat = ingest_hdr.ingest_head.lat_rad
radar_lon = ingest_hdr.ingest_head.lon_rad
pulsewidth = product_hdr.prod_end.pulse_wd     ; pulse width (micro sec x 100)
prf = product_hdr.prod_end.prf                 ; pulse repetition frequency
wavelen = product_hdr.prod_end.wavelen         ; wavelength (cm x 100)
numbins = product_hdr.prod_end.num_bin         ; number of bins in ray
rng_first_bin = product_hdr.prod_end.rng_f_bin ; range first bin (cm)
rng_last_bin = product_hdr.prod_end.rng_l_bin  ; range last bin (cm)

if needswap then $
    byteorder, masks, sec, pulsewidth, prf, wavelen, numbins, $
        rng_first_bin, rng_last_bin, radar_lat, radar_lon, /lswap

pulsewidth =  pulsewidth/100.0
wavelen = wavelen/100.0
rng_first_bin = rng_first_bin/100.0
rng_last_bin = rng_last_bin/100.0
bin_size = (rng_last_bin - rng_first_bin)/numbins
sitename = strtrim(string(product_hdr.prod_end.site_name))
case strmid(strupcase(sitename),0,3) of
    "KWA": beamwidth = 1.0   ; Kwajalein
    "MIT": beamwidth = 1.65  ; MIT
    "TOG": beamwidth = 1.65  ; TOGA
    else:  beamwidth = 1.0   ; Default
endcase
rayinfo = {pulsewidth:pulsewidth, prf:prf, pulsecount:0, beamwidth:beamwidth, $
           wavelen_cm:wavelen, numbins:numbins, rng_first_bin:rng_first_bin, $
	   bin_size:bin_size}
radar_lat = nsig_convert_angle_long(radar_lat)
radar_lon = nsig_convert_angle_long(radar_lon)

; Byte-swap 2-byte words in headers.
if needswap then begin
    byteorder, product_hdr, /sswap
    byteorder, ingest_hdr, /sswap
endif

rayinfo.pulsecount = product_hdr.prod_end.num_samp

; Count the "on" bits in data masks to get number of parameters.
nparams = 0
datatype = intarr(30) ; should be more than enough.
j = 0
for imask = 0, n_elements(masks)-1 do begin
    data_mask = masks(imask)
    for i = 0,31 do begin
	if ishft(data_mask,-i) and 1L then begin
	    nparams = nparams + 1
	    datatype[j] = i + 32*imask  ; cumulative bit number for masks.
	    j = j + 1
	endif
    endfor
endfor

; Map Sigmet data types to volume indexes in radar structure.
ivol_dtype = datatype[where(datatype ne 0)]

; This array contains RSL field types corresponding to the SIGMET field types.
; Sigmet uses numbers to identify their fields, and each SIGMET field number
; serves as an index for an RSL field type.  For example, the number for 1-byte
; velocity is 3, which is the subscript for 'VR'.  You may notice the element at
; subscript 10 is also 'VR'; this is the SIGMET field number for 2-byte
; velocity.  Question marks (?) are used for fields that are not currently used
; in rsl.
; The SIGMET data type constants are defined in this file in the procedure
; nsig_sweep_to_radar.  To find them in your editor, use the search string
; "Data Type Constants".
                                                                        ;sub#
field_type = ['?','ZT','DZ','VR','SW','DR','?','?','ZT','DZ','VR','SW', $ ;11
              'DR','?','KD','KD','PH','?','SQ','RH','RH','C2','?','SQ', $ ;23
	      'PH','?','LDH','?','LDV','?','?','?','?','?','?','?', $     ;35
	       '?','?','?','?','?','?','?','?','?','?','?','RHH', $       ;47
	       '?','RHV','?','PHH','?','PHV','?','HC','HC','?','DC','?', $ ;59
	       '?','?','TV','?','ZV','?','SN']

nselect = n_elements(fields)
if nselect gt 0 then begin
    sel_fields = strupcase(fields)
    ivol_dtype = field_to_nsig_datatype(sel_fields, ivol_dtype, field_type)
endif
if ivol_dtype[0] lt 0 then begin
    if not keyword_set(quiet) then message,'No selected fields were found.', $
        /continue
    goto, finished
endif

nfields = n_elements(ivol_dtype)

; Make sure all fields are recognized.
for i = 0, nfields-1 do begin
    unknown_field = 0
    j = ivol_dtype[i]
    if j lt n_elements(field_type) then begin
        if field_type[j] eq '?' then unknown_field = 1
    endif else unknown_field = 1
    if unknown_field then message, string(j, format = $
        '("Unknown Sigmet radar data type",i4,' + $
        '"--will store raw data.")'), /informational
endfor

nsweeps = ingest_hdr.task_config.scan_info.num_swp
if keyword_set(maxsweeps) then nsweeps = maxsweeps
nrays = ingest_hdr.ingest_head.num_rays

radar = rsl_new_radar(nfields,nsweeps,nrays,numbins)

; Convert seconds since midnight to hours-minutes-seconds.
hour = sec/3600
minute = (sec - hour*3600L)/60L
seconds = float(sec - (hour*3600L + minute*60L))

radar.h.month = ingest_hdr.ingest_head.start_time.month
radar.h.year = ingest_hdr.ingest_head.start_time.year
radar.h.day = ingest_hdr.ingest_head.start_time.day
radar.h.hour = hour
radar.h.minute = minute
radar.h.sec = seconds
if nsig_ver eq 2 then radar.h.radar_type = 'nsig2' $
else radar.h.radar_type = 'nsig' 

; Convert radar coordinates to degrees-minutes-seconds.
lat = abs(radar_lat)
if radar_lat ge 0. then sign = 1 else sign = -1
latd = fix(lat)
latm = fix((lat - latd) * 60.)
lats= round(((lat - latd) * 60. - latm) * 60.)
radar.h.latd = sign * latd
radar.h.latm = sign * latm
radar.h.lats = sign * lats

lon = abs(radar_lon)
if radar_lon ge 0. then sign = 1 else sign = -1
lond = fix(lon)
lonm = fix((lon - lond) * 60.)
lons= round(((lon - lond) * 60. - lonm) * 60.)
radar.h.lond = sign * lond
radar.h.lonm = sign * lonm
radar.h.lons = sign * lons

radar.h.name = sitename
radar.h.radar_name = sitename
radar.h.height = product_hdr.prod_end.grnd_sea_ht + $
    product_hdr.prod_end.rad_grnd_ht 

scan_mode = ingest_hdr.task_config.scan_info.ant_scan_mode
scan_label = ['Invalid','PPI Sector','RHI','Manual','PPI Continuous','File']
if scan_label[scan_mode] eq 'PPI Continuous' then begin
    radar.h.scan_mode = 'PPI'
endif else begin
    if keyword_set(quiet) eq 0 then $
        print, 'Antenna scan mode = ', scan_label[scan_mode]
    radar.h.scan_mode = scan_label[scan_mode]
endelse

; Save the number of "scheduled" sweeps to compare with the number of sweeps
; successfully read in.
radar.h.sched_sweeps = ingest_hdr.task_config.scan_info.num_swp

radar.volume[0:nfields-1].h.field_type = field_type[ivol_dtype]
; Load sweeps.
xh_size = ingest_hdr.ingest_head.size_ext_ray_headers
if keyword_set(quiet) then doprint = 0 else doprint = 1
if doprint then print, format='($,/"Loading sweep")'
for isweep = 0, nsweeps-1 do begin
    if doprint then print, format='($,i4)', isweep + 1
    status = nsig_sweep_to_radar(iunit,isweep, nparams, rayinfo, xh_size, $
        ivol_dtype, radar)
    if eof(iunit) or status lt 0 then break
endfor
if doprint then print ; Print newline after using '$' format code.
if status lt 0 then begin
    if not keep_radar then radar = -1
    error = 1
    goto, finished
endif

radar.h.nvolumes = nfields

if nfields eq 0 then begin
    if not keep_radar then radar = -1
    error = 1
endif

finished: if iunit gt 0 then free_lun, iunit
if size(radar,/n_dimensions) eq 0 then error = 1
return, radar
end ; rsl_nsig_to_radar
