;+
; rsl_radar_to_cfradial
;
; This procedure writes data from the radar structure to a file in CfRadial
; format.
;
; Syntax:
;     rsl_radar_to_cfradial, radar [, cfradfile] [, FIELDS=fields] [, /GZIP]
;         [, /DAT1D] [, /DAT2D]
;
; Arguments:
;     radar:     a Radar data structure.
;     cfradfile: an optional argument containing the name of the CfRadial file.
;         If the the file name ends in '.gz', the file is compressed with
;         'gzip'.  If this argument is omitted, a file name is constructed in
;         the form: cfrad.SITE_YYYYMMDD_HHMMSS.nc.
;
; Keywords:
;     FIELDS:
;         String array containing the fields to be written to the output
;         file.  Default is all fields.  Fields are in the form of the
;         two-character field names used by RSL, such as 'DZ', 'VR', etc.
;     DAT1D:
;         Set this keyword to store field data in CfRadial as 1-D arrays.
;         By default, this function determines appropriate array dimension.
;     DAT2D:
;         Set this keyword to store data in CfRadial as 2-D arrays.
;         By default, this function determines appropriate array dimension.
;     GZIP: 
;         Set this keyword to compress the CfRadial file with 'gzip'.
;
; Written by: Bart Kelley, SSAI, October 2014
;
;**************************************************************************
;-
 
;********************************;
;     number_of_gates_varies     ;
;********************************;

function number_of_gates_varies, radar

; Return 1 (true) if the number of range gates per ray varies, 0 (false)
; if the number is constant.
;
; Method:
; Search sweeps for each field until either nbins difference is found or all
; fields have been searched.

compile_opt defint32, hidden

num_gates_vary = 0

; Get first ray with nbins gt 0.  Use that nbins value for comparison.
iray = 0
while radar.volume[0].sweep[0].ray[iray].h.nbins eq 0 do iray++
prev_nbins = radar.volume[0].sweep[0].ray[iray].h.nbins 

; Search for a ray having different number of bins.  Only one ray per sweep is
; checked.
for ivol = 0, radar.h.nvolumes-1 do begin
    for iswp = 1, radar.volume[ivol].h.nsweeps-1 do begin
        nbins = radar.volume[ivol].sweep[iswp].ray[iray].h.nbins
        if nbins ne 0 and nbins ne prev_nbins then begin
            num_gates_vary = 1
            break
        endif
    endfor ; sweeps
    if num_gates_vary then break
endfor ; vols

return, num_gates_vary
end


;********************************;
;     get_dimensions_for_cfr     ;
;********************************;

pro get_dimensions_for_cfr, radar, timedim, rangedim, sweepdim

compile_opt defint32, hidden

; Get ray count using first field.
nsweeps = radar.volume[0].h.nsweeps
timedim = total(long(radar.volume[0].sweep[0:nsweeps-1].h.nrays),/preserve_type)

; Determine maximum range bins using all fields in first sweep.
rangedim = 0L
gate_size = radar.volume[0].sweep[0].ray[0].h.gate_size
wsr88d = radar.h.vcp gt 0

if wsr88d then begin
    if gate_size eq 250 then $
        rangedim = long(radar.volume[0].sweep[0].ray[0].h.nbins) $
        else if gate_size eq 1000 then $
        rangedim = 4L * radar.volume[0].sweep[0].ray[0].h.nbins
endif else begin
    for ivol = 0,radar.h.nvolumes-1 do begin
        nrays = radar.volume[ivol].sweep[0].h.nrays
        rangedim = $
            rangedim > max(radar.volume[ivol].sweep[0].ray[0:nrays-1].h.nbins)
    endfor
endelse

; Get sweep count from first field
sweepdim = long(radar.volume[0].h.nsweeps)
end


;***********************************;
;     get_time_coverage_for_cfr     ;
;***********************************;

pro get_time_coverage_for_cfr, radar, tcovstart, tcovend

; Get start and end coverage times.  Times are returned as strings of the
; format 'yyyy-mm-ddThh:mm:ssZ'.

; Note: It is assumed that ray times are in chronological sequence.

compile_opt hidden

; Get time from first ray.
ivol = 0
; Get first ray with nonzero nbins.
while radar.volume[ivol].sweep[0].ray[0].h.nbins eq 0 do ivol++
rayhdr = radar.volume[ivol].sweep[0].ray[0].h
tcovstart = string(rayhdr.year,rayhdr.month,rayhdr.day,$
    rayhdr.hour,rayhdr.minute,fix(rayhdr.sec),$
    format='(i4,2("-",i02),"T",i02,2(":",i02),"Z")')

; Get time from last ray of last sweep.
nsweeps = radar.volume[0].h.nsweeps
lastray = radar.volume[0].sweep[nsweeps-1].h.nrays-1
ivol = 0
while radar.volume[ivol].sweep[nsweeps-1].ray[lastray].h.nbins eq 0 do ivol++
rayhdr = radar.volume[ivol].sweep[nsweeps-1].ray[lastray].h
tcovend = string(rayhdr.year,rayhdr.month,rayhdr.day,$
    rayhdr.hour,rayhdr.minute,fix(rayhdr.sec),$
    format='(i4,2("-",i02),"T",i02,2(":",i02),"Z")')
end


;*****************************;
;     get_field_selection     ;
;*****************************;

function get_field_selection, radar, fields

; Returns a structure containing a string array of selected fields and an
; array of corresponding volume indices.  The FIELDS keyword provides the
; field selection.  If FIELDS is undefined, all fields are selected.

compile_opt defint32, hidden

all_fields = radar.volume.h.field_type
missing = 0
if n_elements(fields) eq 0 then begin
    fieldlist = all_fields
    volindex = lindgen(n_elements(radar.volume))
endif else begin
    ; Check that selected fields are present in the radar structure.  Print any
    ; that are not.
    nfields = n_elements(fields)
    fieldlist = strarr(nfields)
    volindex = lonarr(nfields)
    ifield=0
    for i = 0, nfields-1 do begin
        thisfield = strupcase(fields[i])
        loc = where(all_fields eq thisfield)
        if loc[0] gt -1 then begin
            fieldlist[ifield] = thisfield
            volindex[ifield] = loc[0]
            ifield = ifield + 1
        endif else begin
            print, 'Selected field ',thisfield,' not found.'
            missing = missing + 1
        endelse
    endfor
    if ifield lt nfields then begin
        fieldlist = fieldlist[0:ifield-1]
        volindex = volindex[0:ifield-1]
    endif
endelse
if missing gt 0 then begin
    print,'Available fields in this data:',all_fields
    print,'The following fields will be processed:',fieldlist
endif
return, {fieldlist:fieldlist, volindex:volindex}
end


function get_vr_indices_this_field, radar, iswp, vrfield

; For WSR-88D split cuts, get azimuth indices corresponding to reflectivity
; for given velocity field.

; Get azimuth of first reflectivity (DZ) ray.
dzazim = radar.volume[0].sweep[iswp].ray[0].h.azimuth

ivol = where(radar.volume.h.field_type eq vrfield, count)
if count eq 0 then return, -1
ivol = ivol[0]
; Find index of velocity field at approximatley the same azimuth as DZ.
vray = rsl_get_ray_from_sweep(radar.volume[ivol].sweep[iswp],dzazim,index=ivr)

; Load indices for DZ-synchronized VR azimuths.
nrays = radar.volume[0].sweep[iswp].h.nrays
vr_ind = intarr(nrays)
vr_ind[0] = indgen(nrays-ivr) + ivr
if ivr gt 0 then vr_ind[nrays-ivr] = indgen(ivr)

return, vr_ind
end


pro get_vr_indices, radar, iswp, vr_ind, v2_ind, v3_ind

; For WSR-88D split cuts, get azimuth indices corresponding to reflectivity
; for velocity fields.

vr_ind = get_vr_indices_this_field(radar, iswp, 'VR')

; For VCP 121, get indices for additional velocity fields V2 and V3.
; Because these don't occur in all split cuts, check that sweep number for these
; fields is positive. Empty sweeps are indicated by negative sweep number.
if radar.h.vcp eq 121 then begin
    ivol = where(radar.volume.h.field_type eq 'V2', count)
    if count gt 0 && radar.volume[ivol[0]].sweep[iswp].h.sweep_num gt 0 then $
        v2_ind = get_vr_indices_this_field(radar, iswp, 'V2')
    ivol = where(radar.volume.h.field_type eq 'V3', count)
    if count gt 0 && radar.volume[ivol[0]].sweep[iswp].h.sweep_num gt 0 then $
    v3_ind = get_vr_indices_this_field(radar, iswp, 'V3')
endif
end


;*****************************;
;     seconds_since_start     ;
;*****************************;

function seconds_since_start, ray, startdate, starttime

; Return the time for this ray in seconds since volume start.

adjust=0.d
thisdate=[ray.h.year, ray.h.month, ray.h.day]
; If day changes then set adjustment.
if ~ array_equal(startdate, thisdate) then begin
    ndays = julday(ray.h.month, ray.h.day, ray.h.year) - $
        julday(startdate[1], startdate[2], startdate[0])
    sec_in_day = 86400.d
    adjust = ndays * sec_in_day
endif
this_time = ray.h.hour*3600.d0+ray.h.minute*60.d0+ray.h.sec + adjust
return, this_time - starttime
end


;*******************************;
;     rsl_radar_to_cfradial     ;
;*******************************;

pro rsl_radar_to_cfradial, radar, cfradfile, fields=fields, gzip=gzip, $
    catch_error=catch_error, dat1d=dat1d, dat2d=dat2d

; Write radar data to file in CfRadial format.

compile_opt defint32

file_opened = 0
if n_elements(catch_error) eq 0 then catch_error = 1

; Error handler.
catch, errcode
if errcode ne 0 then begin
    catch, /cancel
    print
    print,!error_state.msg_prefix + !error_state.msg
    if !error_state.sys_msg ne '' then print, '  ' + !error_state.sys_msg
    if file_opened then ncdf_close, cfid
    return
endif
if not catch_error then catch, /cancel

; If the output CfRadial file name is not given, build it.
if n_elements(cfradfile) eq 0 then begin
    radarname =  strtrim(radar.h.radar_name, 2)
    if radarname eq '' then radarname = 'unknown'
    cfradfile = 'cfrad.' + radarname + $
        string(radar.h.year, radar.h.month, radar.h.day, radar.h.hour, $
        radar.h.minute, radar.h.sec, format='("_",i4,2i02,"_",3i02,".nc")')
endif

filename = cfradfile
; If filename extension is ".gz", remove it because gzip will add it.
gzpos = stregex(filename,'\.gz$')
if gzpos ne -1 then begin
    filename = strmid(filename,0,gzpos)
    gzip = 1
endif

cfid = ncdf_create(filename, /clobber)
file_opened = 1

; Define dimensions.

get_dimensions_for_cfr, radar, timedim, rangedim, sweepdim
timedimid = ncdf_dimdef(cfid,'time',timedim)
rangedimid = ncdf_dimdef(cfid,'range',rangedim)
sweepdimid = ncdf_dimdef(cfid,'sweep',sweepdim)
freqdimid = ncdf_dimdef(cfid,'frequency',1)
strshortid = ncdf_dimdef(cfid,'string_length_short',32)
strmediumid = ncdf_dimdef(cfid,'string_length_medium',64)
strlongid = ncdf_dimdef(cfid,'string_length_long',256)

spacing_is_constant = 'true'
range_first_gate = radar.volume[0].sweep[0].ray[0].h.range_bin1
gate_size = radar.volume[0].sweep[0].ray[0].h.gate_size
sel_fields = get_field_selection(radar, fields)
fieldlist = sel_fields.fieldlist
volindex = sel_fields.volindex
wsr88d = radar.h.vcp gt 0
; For WSR-88D, get range to first gate and gate size from velocity field.
; We do this because older datasets may have 1 km gate_size for reflectivity and
; 250 m for velocity, and we want the smaller.
if wsr88d then begin
    loc = where(fieldlist eq 'DZ',dzcount)
    loc = where(fieldlist eq 'VR',vrcount)
    vrvol = volindex[loc[0]]
    ; Range-to-first-gate and gate-size were assigned above with values from
    ; first field.  Velocity in WSR-88D is in the second or higher field.
    if dzcount + vrcount eq 2 then begin
        range_first_gate = radar.volume[vrvol].sweep[0].ray[0].h.range_bin1
        gate_size = radar.volume[vrvol].sweep[0].ray[0].h.gate_size
    endif
endif
range = range_first_gate + findgen(rangedim)*gate_size

if keyword_set(dat2d) then n_gates_vary = 'false'
if keyword_set(dat1d) then n_gates_vary = 'true'
if n_elements(n_gates_vary) eq 0 then begin
    if number_of_gates_varies(radar) then n_gates_vary = 'true' $
        else n_gates_vary = 'false'
endif

if n_gates_vary eq 'true' then begin
    ; Get total number of range bins in a field.
    nsweeps = sweepdim
    sweep_nrays = radar.volume[0].sweep[0:nsweeps-1].h.nrays
    n_points = 0L
    for i=0,nsweeps-1 do begin
        nbins_this_sweep = total( $
            long(radar.volume[0].sweep[i].ray[0:sweep_nrays[i]-1].h.nbins), $
            /preserve_type)
        if radar.volume[0].sweep[i].ray[0].h.gate_size eq 1000 && $
            gate_size eq 250 then nbins_this_sweep = nbins_this_sweep * 4L
        n_points = n_points + nbins_this_sweep
    endfor
    n_pointsid = ncdf_dimdef(cfid, 'n_points', n_points)
endif

; Define variables.


volnumid = ncdf_vardef(cfid,'volume_number',/long)
ncdf_attput,cfid,volnumid,'long_name','data_volume_index_number'
ncdf_attput,cfid,volnumid,'_FillValue',-9999L

pwid = ncdf_vardef(cfid,'pulse_width',timedimid,/float)
ncdf_attput,cfid,pwid,'standard_name','transmitter_pulse_width'
ncdf_attput,cfid,pwid,'units','seconds'
ncdf_attput,cfid,pwid,'meta_group','instrument_parameters'

scnrateid = ncdf_vardef(cfid,'scan_rate',timedimid,/float)
ncdf_attput,cfid,scnrateid,'long_name','antenna_angle_scan_rate'
ncdf_attput,cfid,scnrateid,'units','degrees per second'
ncdf_attput,cfid,scnrateid,'meta_group','instrument_parameters'

prtfill = -9999.
prtid = ncdf_vardef(cfid,'prt',timedimid,/float)
ncdf_attput,cfid,prtid,'standard_name','pulse_repetition_time'
ncdf_attput,cfid,prtid,'units','seconds'
ncdf_attput,cfid,prtid,'_FillValue',prtfill
ncdf_attput,cfid,prtid,'meta_group','instrument_parameters'

nyqid = ncdf_vardef(cfid,'nyquist_velocity',timedimid,/float)
ncdf_attput,cfid,nyqid,'standard_name','unambiguous_doppler_velocity'
ncdf_attput,cfid,nyqid,'units','meters per second'
ncdf_attput,cfid,nyqid,'meta_group','instrument_parameters'

; Define PRT and Nyquist variables for additional Doppler cuts that occur in
; VCP 121 split cuts.
extra_vel = where(stregex(fieldlist,'V[23]|S[23]',/boolean),count)
if count gt 0 then begin
    prtid = ncdf_vardef(cfid,'prt2',timedimid,/float)
    ncdf_attput,cfid,prtid,'standard_name','pulse_repetition_time'
    ncdf_attput,cfid,prtid,'units','seconds'
    ncdf_attput,cfid,prtid,'_FillValue',prtfill
    ncdf_attput,cfid,prtid,'meta_group','instrument_parameters'
    ncdf_attput,cfid,prtid,'comment','These are the PRT values for ' + $
        'velocity from the second Doppler cut in a VCP 121 split cut.'
    prtid = ncdf_vardef(cfid,'prt3',timedimid,/float)
    ncdf_attput,cfid,prtid,'standard_name','pulse_repetition_time'
    ncdf_attput,cfid,prtid,'units','seconds'
    ncdf_attput,cfid,prtid,'_FillValue',prtfill
    ncdf_attput,cfid,prtid,'meta_group','instrument_parameters'
    ncdf_attput,cfid,prtid,'comment','These are the PRT values for ' + $
        'velocity from the third Doppler cut in a VCP 121 split cut.'
    nyqid = ncdf_vardef(cfid,'nyquist_velocity2',timedimid,/float)
    ncdf_attput,cfid,nyqid,'standard_name','unambiguous_doppler_velocity'
    ncdf_attput,cfid,nyqid,'units','meters per second'
    ncdf_attput,cfid,nyqid,'meta_group','instrument_parameters'
    ncdf_attput,cfid,nyqid,'comment','These are the Nyquist values for ' + $
        'velocity from the second Doppler cut in a VCP 121 split cut.'
    nyqid = ncdf_vardef(cfid,'nyquist_velocity3',timedimid,/float)
    ncdf_attput,cfid,nyqid,'standard_name','unambiguous_doppler_velocity'
    ncdf_attput,cfid,nyqid,'units','meters per second'
    ncdf_attput,cfid,nyqid,'meta_group','instrument_parameters'
    ncdf_attput,cfid,nyqid,'comment','These are the Nyquist values for ' + $
        'velocity from the third Doppler cut in a VCP 121 split cut.'
endif

beamw_h_id = ncdf_vardef(cfid,'radar_beam_width_h',/float)
ncdf_attput,cfid,beamw_h_id,'standard_name','half_power_radar_beam_width_h_channel'
ncdf_attput,cfid,beamw_h_id,'units','degrees'
ncdf_attput,cfid,beamw_h_id,'meta_group','radar_parameters'

beamw_v_id = ncdf_vardef(cfid,'radar_beam_width_v',/float)
ncdf_attput,cfid,beamw_v_id,'standard_name','half_power_radar_beam_width_v_channel'
ncdf_attput,cfid,beamw_v_id,'units','degrees'
ncdf_attput,cfid,beamw_v_id,'meta_group','radar_parameters'

unambid = ncdf_vardef(cfid,'unambiguous_range',timedimid,/float)
ncdf_attput,cfid,unambid,'standard_name','unambiguous_range'
ncdf_attput,cfid,unambid,'units','meters'
ncdf_attput,cfid,unambid,'meta_group','instrument_parameters'

freqid = ncdf_vardef(cfid,'frequency',freqdimid,/float)
ncdf_attput,cfid,freqid,'standard_name','radiation_frequency'
ncdf_attput,cfid,freqid,'units','s-1'
ncdf_attput,cfid,freqid,'meta_group','instrument_parameters'

latid = ncdf_vardef(cfid,'latitude',/double)
ncdf_attput,cfid,latid,'standard_name','latitude'
ncdf_attput,cfid,latid,'units','degrees_north'

lonid = ncdf_vardef(cfid,'longitude',/double)
ncdf_attput,cfid,lonid,'standard_name','longitude'
ncdf_attput,cfid,lonid,'units','degrees_east'

altid = ncdf_vardef(cfid,'altitude',/double)
ncdf_attput,cfid,altid,'standard_name','altitude'
ncdf_attput,cfid,altid,'units','meters_above_mean_sea_level'

instypid = ncdf_vardef(cfid,'instrument_type',strshortid,/char)
ncdf_attput,cfid,instypid,'standard_name','type_of_instrument'
ncdf_attput,cfid,instypid,'options','radar, lidar'
ncdf_attput,cfid,instypid,'meta_group','instrument_parameters'
tmcovsttid = ncdf_vardef(cfid,'time_coverage_start',strshortid,/char)
ncdf_attput,cfid,tmcovsttid,'standard_name','data_volume_start_time_utc'
ncdf_attput,cfid,tmcovsttid,'comment','utc time of first ray in file'
tmcovendid = ncdf_vardef(cfid,'time_coverage_end',strshortid,/char)
ncdf_attput,cfid,tmcovendid,'standard_name','data_volume_end_time_utc'
ncdf_attput,cfid,tmcovendid,'comment','utc time of last ray in file'

timeid = ncdf_vardef(cfid,'time',timedimid,/double)
ncdf_attput,cfid,timeid,'standard_name','time'
ncdf_attput,cfid,timeid,'long_name','time in seconds since volume start'
; Note: actual start time for *units* attribute is filled in later.
ncdf_attput,cfid,timeid,'units','seconds since yyyy-mm-ddThh:mm:ssZ'
ncdf_attput,cfid,timeid,'calendar','standard'

rangeid = ncdf_vardef(cfid,'range',rangedimid,/float)
ncdf_attput,cfid,rangeid,'standard_name','projection_range_coordinate'
ncdf_attput,cfid,rangeid,'long_name','range_to_measurement_volume'
ncdf_attput,cfid,rangeid,'units','meters'
ncdf_attput,cfid,rangeid,'spacing_is_constant',spacing_is_constant
ncdf_attput,cfid,rangeid,'meters_to_center_of_first_gate',range_first_gate
ncdf_attput,cfid,rangeid,'meters_between_gates',gate_size
ncdf_attput,cfid,rangeid,'axis','radial_range_coordinate'

if n_gates_vary eq 'true' then begin
    ray_n_gatesid = ncdf_vardef(cfid,'ray_n_gates',timedimid,/long)
    ncdf_attput,cfid,ray_n_gatesid,'_FillValue',-9999L
    ray_start_indexid = ncdf_vardef(cfid,'ray_start_index',timedimid,/long)
    ncdf_attput,cfid,ray_start_indexid,'_FillValue',-9999L
endif

azimuthid = ncdf_vardef(cfid,'azimuth',timedimid,/float)
ncdf_attput,cfid,azimuthid,'standard_name','ray_azimuth_angle'
ncdf_attput,cfid,azimuthid,'long_name','azimuth_angle_from_true_north'
ncdf_attput,cfid,azimuthid,'units','degrees'
ncdf_attput,cfid,azimuthid,'axis','radial_azimuth_coordinate'

elevationid = ncdf_vardef(cfid,'elevation',timedimid,/float)
ncdf_attput,cfid,elevationid,'standard_name','ray_elevation_angle'
ncdf_attput,cfid,elevationid,'long_name','elevation_angle_from_horizontal_plane'
ncdf_attput,cfid,elevationid,'units','degrees'
ncdf_attput,cfid,elevationid,'axis','radial_elevation_coordinate'

sweepnumid = ncdf_vardef(cfid,'sweep_number',sweepdimid,/long)
ncdf_attput,cfid,sweepnumid,'standard_name','sweep_index_number_0_based'
sweepmodeid = ncdf_vardef(cfid,'sweep_mode',[strshortid,sweepdimid],/char)
ncdf_attput,cfid,sweepmodeid,'standard_name','scan_mode_for_sweep'
fixedangleid = ncdf_vardef(cfid,'fixed_angle',sweepdimid,/float)
ncdf_attput,cfid,fixedangleid,'standard_name','beam_target_fixed_angle'
ncdf_attput,cfid,fixedangleid,'units','degrees'
swpsttrayid = ncdf_vardef(cfid,'sweep_start_ray_index',sweepdimid,/long)
ncdf_attput,cfid,swpsttrayid,'standard_name','index_of_first_ray_in_sweep'
swpendrayid = ncdf_vardef(cfid,'sweep_end_ray_index',sweepdimid,/long)
ncdf_attput,cfid,swpendrayid,'standard_name','index_of_last_ray_in_sweep'

;TODO:
;  If platform is moving, include geo-reference variables (heading, roll, etc.).

sweep_mode = strarr(max(radar.volume.h.nsweeps))
;TODO: Add more sweep_mode options.
if radar.h.scan_mode eq 'PPI' then begin
    sweep_mode[*] = 'azimuth_surveillance'
endif else if radar.h.scan_mode eq 'RHI' then begin
    sweep_mode[*] = 'elevation_surveillance'
endif

nvols = n_elements(volindex)
fieldids = lonarr(nvols)
cfrfields = strarr(nvols)
packthis = intarr(nvols)
scalefac = fltarr(nvols)
addoff = fltarr(nvols)
fillval = intarr(nvols)

; Define data moments arrays, dimensioned n_points.

missing_data_value = radar.volume[0].h.no_data_flag
fillval_short = fix(-32768)
coordinates_attr = 'time range'
i = 0
for ivol = 0, nvols-1 do begin
    thisfield = fieldlist[ivol]
    case thisfield of
        'DZ': begin
            if n_gates_vary eq 'true' then begin
                fieldids[i] = ncdf_vardef(cfid,'DBZ',n_pointsid,/short)
            endif else begin
                fieldids[i] = ncdf_vardef(cfid,'DBZ',[rangedimid,timedimid],/short)
            endelse
            cfrfields[i] = 'DBZ'
            ncdf_attput,cfid,'DBZ','long_name','Reflectivity'
            ncdf_attput,cfid,'DBZ','standard_name', $
                'equivalent_reflectivity_factor'
            ncdf_attput,cfid,'DBZ','units','dBZ'
            packthis[i] = 1
            scalefac[i] = 0.01
            addoff[i] = 0.
            fillval[i] = fillval_short
            ncdf_attput,cfid,'DBZ','scale_factor',scalefac[i]
            ncdf_attput,cfid,'DBZ','add_offset',addoff[i]
            ncdf_attput,cfid,'DBZ','_FillValue',fillval[i]
            ncdf_attput,cfid,'DBZ','coordinates',coordinates_attr
            i++
        end
        'VR': begin
            if n_gates_vary eq 'true' then begin
                fieldids[i] = ncdf_vardef(cfid,'VEL',n_pointsid,/short)
            endif else begin
                fieldids[i] = ncdf_vardef(cfid,'VEL',[rangedimid,timedimid],/short)
            endelse
            cfrfields[i] = 'VEL'
            ncdf_attput,cfid,'VEL','long_name','Radial Velocity'
            ncdf_attput,cfid,'VEL','standard_name', $
                'radial_velocity_of_scatterers_away_from_instrument'
            ncdf_attput,cfid,'VEL','units','m/s'
            packthis[i] = 1
            scalefac[i] = 0.01
            addoff[i] = 0.
            fillval[i] = fillval_short
            ncdf_attput,cfid,'VEL','scale_factor',scalefac[i]
            ncdf_attput,cfid,'VEL','add_offset',addoff[i]
            ncdf_attput,cfid,'VEL','_FillValue',fillval[i]
            ncdf_attput,cfid,'VEL','coordinates',coordinates_attr
            i++
        end
        ; For V2, V3, defines CfRadial variables VEL2, VEL3.
        stregex(thisfield,'V[23]',/extract): begin
            varname = 'VEL' + strmid(thisfield,1)
            if n_gates_vary eq 'true' then begin
                fieldids[i] = ncdf_vardef(cfid,varname,n_pointsid,/short)
            endif else begin
                fieldids[i] = ncdf_vardef(cfid,varname,[rangedimid,timedimid],/short)
            endelse
            cfrfields[i] = varname
            ncdf_attput,cfid,varname,'long_name','Radial Velocity'
            ncdf_attput,cfid,varname,'standard_name', $
                'radial_velocity_of_scatterers_away_from_instrument'
            ncdf_attput,cfid,varname,'units','m/s'
            packthis[i] = 1
            scalefac[i] = 0.01
            addoff[i] = 0.
            fillval[i] = fillval_short
            ncdf_attput,cfid,varname,'scale_factor',scalefac[i]
            ncdf_attput,cfid,varname,'add_offset',addoff[i]
            ncdf_attput,cfid,varname,'_FillValue',fillval[i]
            ncdf_attput,cfid,varname,'coordinates',coordinates_attr
            if varname eq 'VEL2' then begin
                ncdf_attput,cfid,varname,'comment','This is velocity data ' + $
                'from the second Doppler cut in a VCP 121 split cut.'
            endif else begin
                ncdf_attput,cfid,varname,'comment','This is velocity data ' + $
                'from the third Doppler cut in a VCP 121 split cut.'
            endelse
            i++
        end
        'SW': begin
            if n_gates_vary eq 'true' then begin
                fieldids[i] = ncdf_vardef(cfid,'WIDTH',n_pointsid,/short)
            endif else begin
                fieldids[i] = ncdf_vardef(cfid,'WIDTH',[rangedimid,timedimid],/short)
            endelse
            cfrfields[i] = 'WIDTH'
            ncdf_attput,cfid,'WIDTH','long_name','Spectrum Width'
            ncdf_attput,cfid,'WIDTH','standard_name','doppler_spectrum_width'
            ncdf_attput,cfid,'WIDTH','units','m/s'
            packthis[i] = 1
            scalefac[i] = 0.01
            addoff[i] = 0.
            fillval[i] = fillval_short
            ncdf_attput,cfid,'WIDTH','scale_factor',scalefac[i]
            ncdf_attput,cfid,'WIDTH','add_offset',addoff[i]
            ncdf_attput,cfid,'WIDTH','_FillValue',fillval[i]
            ncdf_attput,cfid,'WIDTH','coordinates',coordinates_attr
            i++
        end
        ; For S2, S3, defines CfRadial variables WIDTH2, WIDTH3.
        stregex(thisfield,'S[23]',/extract): begin
            varname = 'WIDTH' + strmid(thisfield,1)
            if n_gates_vary eq 'true' then begin
                fieldids[i] = ncdf_vardef(cfid,varname,n_pointsid,/short)
            endif else begin
                fieldids[i] = ncdf_vardef(cfid,varname,[rangedimid,timedimid],/short)
            endelse
            cfrfields[i] = varname
            ncdf_attput,cfid,varname,'long_name','Spectrum Width'
            ncdf_attput,cfid,varname,'standard_name','doppler_spectrum_width'
            ncdf_attput,cfid,varname,'units','m/s'
            packthis[i] = 1
            scalefac[i] = 0.01
            addoff[i] = 0.
            fillval[i] = fillval_short
            ncdf_attput,cfid,varname,'scale_factor',scalefac[i]
            ncdf_attput,cfid,varname,'add_offset',addoff[i]
            ncdf_attput,cfid,varname,'_FillValue',fillval[i]
            ncdf_attput,cfid,varname,'coordinates',coordinates_attr
            if varname eq 'WIDTH2' then begin
                ncdf_attput,cfid,varname,'comment','This is spectrum width ' + $
                'data from the second Doppler cut in a VCP 121 split cut.'
            endif else begin
                ncdf_attput,cfid,varname,'comment','This is spectrum width ' + $
                'data from the third Doppler cut in a VCP 121 split cut.'
            endelse
            i++
        end
        'ZT': begin
            if n_gates_vary eq 'true' then begin
                fieldids[i] = ncdf_vardef(cfid,'DBZTOT',n_pointsid,/short)
            endif else begin
                fieldids[i] = ncdf_vardef(cfid,'DBZTOT',[rangedimid,timedimid],/short)
            endelse
            cfrfields[i] = 'DBZTOT'
            ncdf_attput,cfid,'DBZTOT','long_name','Uncorrected Reflectivity'
            ncdf_attput,cfid,'DBZTOT','units','dBZ'
            packthis[i] = 1
            scalefac[i] = 0.01
            addoff[i] = 0.
            fillval[i] = fillval_short
            ncdf_attput,cfid,'DBZTOT','scale_factor',scalefac[i]
            ncdf_attput,cfid,'DBZTOT','add_offset',addoff[i]
            ncdf_attput,cfid,'DBZTOT','_FillValue',fillval[i]
            ncdf_attput,cfid,'DBZTOT','coordinates',coordinates_attr
            i++
        end
        'DR': begin
            if n_gates_vary eq 'true' then begin
                fieldids[i] = ncdf_vardef(cfid,'ZDR',n_pointsid,/float)
            endif else begin
                fieldids[i] = ncdf_vardef(cfid,'ZDR',[rangedimid,timedimid],/float)
            endelse
            cfrfields[i] = 'ZDR'
            ncdf_attput,cfid,'ZDR','long_name','Differential Reflectivity'
            ncdf_attput,cfid,'ZDR','standard_name', $
                'log_differential_reflectivity_hv'
            ncdf_attput,cfid,'ZDR','units','dB'
            ncdf_attput,cfid,'ZDR','_FillValue',missing_data_value
            ncdf_attput,cfid,'ZDR','coordinates',coordinates_attr
            i++
        end
        'KD': begin
            if n_gates_vary eq 'true' then begin
                fieldids[i] = ncdf_vardef(cfid,'KDP',n_pointsid,/float)
            endif else begin
                fieldids[i] = ncdf_vardef(cfid,'KDP',[rangedimid,timedimid],/float)
            endelse
            cfrfields[i] = 'KDP'
            ncdf_attput,cfid,'KDP','long_name','Specific Differential Phase'
            ncdf_attput,cfid,'KDP','standard_name', $
                'specific_differential_phase_hv'
            ncdf_attput,cfid,'KDP','units','degrees/km'
            ncdf_attput,cfid,'KDP','_FillValue',missing_data_value
            ncdf_attput,cfid,'KDP','coordinates',coordinates_attr
            i++
        end
        'PH': begin
            if n_gates_vary eq 'true' then begin
                fieldids[i] = ncdf_vardef(cfid,'PHIDP',n_pointsid,/short)
            endif else begin
                fieldids[i] = ncdf_vardef(cfid,'PHIDP',[rangedimid,timedimid],/short)
            endelse
            cfrfields[i] = 'PHIDP'
            ncdf_attput,cfid,'PHIDP','long_name','Differential Phase'
            ncdf_attput,cfid,'PHIDP','standard_name','differential_phase_hv'
            ncdf_attput,cfid,'PHIDP','units','degrees'
            packthis[i] = 1
            maxval = 360.
            minval = 0.
            scalefac[i] = (maxval-minval)/(2^15-1) ; 2^15 = max short int
            addoff[i] = 0.
            fillval[i] = fillval_short
            ncdf_attput,cfid,'PHIDP','scale_factor',scalefac[i]
            ncdf_attput,cfid,'PHIDP','add_offset',addoff[i]
            ncdf_attput,cfid,'PHIDP','_FillValue',fillval[i]
            ncdf_attput,cfid,'PHIDP','coordinates',coordinates_attr
            i++
        end
        'RH': begin
            if n_gates_vary eq 'true' then begin
                fieldids[i] = ncdf_vardef(cfid,'RHOHV',n_pointsid,/short)
            endif else begin
                fieldids[i] = ncdf_vardef(cfid,'RHOHV',[rangedimid,timedimid],/short)
            endelse
            cfrfields[i] = 'RHOHV'
            ncdf_attput,cfid,'RHOHV','long_name','Correlation Coefficient'
            ncdf_attput,cfid,'RHOHV','standard_name', $
                'cross_correlation_ratio_hv'
            ncdf_attput,cfid,'RHOHV','units','none'
            packthis[i] = 1
            maxval = 1.
            minval = 0.
            scalefac[i] = (maxval-minval)/(2^15-1) ; 2^15 = max short int
            addoff[i] = 0.
            fillval[i] = fillval_short
            ncdf_attput,cfid,'RHOHV','scale_factor',scalefac[i]
            ncdf_attput,cfid,'RHOHV','add_offset',addoff[i]
            ncdf_attput,cfid,'RHOHV','_FillValue',fillval[i]
            ncdf_attput,cfid,'RHOHV','coordinates',coordinates_attr
            i++
        end
        'HC': begin
            if n_gates_vary eq 'true' then begin
                fieldids[i] = ncdf_vardef(cfid,'HCLASS',n_pointsid,/short)
            endif else begin
                fieldids[i] = ncdf_vardef(cfid,'HCLASS',[rangedimid,timedimid],/short)
            endelse
            cfrfields[i] = 'HCLASS'
            ncdf_attput,cfid,'HCLASS','long_name','HydroClass'
            ncdf_attput,cfid,'HCLASS','units','none'
            ncdf_attput,cfid,'HCLASS','_FillValue',fillval_short
            ncdf_attput,cfid,'HCLASS','coordinates',coordinates_attr
            i++
        end
        'SQ': begin
            if n_gates_vary eq 'true' then begin
                fieldids[i] = ncdf_vardef(cfid,'SQI',n_pointsid,/float)
            endif else begin
                fieldids[i] = ncdf_vardef(cfid,'SQI',[rangedimid,timedimid],/float)
            endelse
            cfrfields[i] = 'SQI'
            ncdf_attput,cfid,'SQI','long_name','Signal Quality Index'
            ncdf_attput,cfid,'SQI','standard_name','normalized_coherent_power'
            ncdf_attput,cfid,'SQI','units','none'
            ncdf_attput,cfid,'SQI','_FillValue',missing_data_value
            ncdf_attput,cfid,'SQI','coordinates',coordinates_attr
            i++
        end
        ; Unknown field name.
        else: begin
            if n_gates_vary eq 'true' then begin
                fieldids[i] = ncdf_vardef(cfid,thisfield,n_pointsid,/float)
            endif else begin
                fieldids[i] = ncdf_vardef(cfid,thisfield,[rangedimid,timedimid],/float)
            endelse
            cfrfields[i] = thisfield
            ncdf_attput,cfid,thisfield,'long_name',thisfield
            ncdf_attput,cfid,thisfield,'standard_name','unknown'
            ncdf_attput,cfid,thisfield,'units','unknown'
            ncdf_attput,cfid,thisfield,'_FillValue',missing_data_value
            ncdf_attput,cfid,thisfield,'coordinates',coordinates_attr
            i++
        end
    endcase
endfor
fieldids = fieldids[0:i-1]
volindex = volindex[0:i-1]

; Set global attributes.
conventions = 'CF/Radial instrument_parameters radar_parameters'
ncdf_attput, cfid, 'Conventions', conventions, /global
title = ''
instrument_name = ''
if radar.h.vcp gt 0 then instrument_name = 'WSR-88D'
site_name = radar.h.radar_name
institution = ''
references = ''
source = ''
if radar.h.radar_type eq 'wsr88d' then source='WSR-88D Level II file'
if radar.h.radar_type eq 'nsig2' then source='Sigmet Raw file'
history = ''
comment = ''
platform_is_mobile = 'false'
; Note ncdf_attput must include /CHAR if value is empty string.
ncdf_attput, cfid, 'title', title, /char, /global
ncdf_attput, cfid, 'institution', institution, /char, /global
ncdf_attput, cfid, 'references', references, /char, /global
ncdf_attput, cfid, 'source', source, /char, /global
ncdf_attput, cfid, 'history', history, /char, /global
ncdf_attput, cfid, 'comment', comment, /char, /global
ncdf_attput, cfid, 'instrument_name', instrument_name, /char, /global
ncdf_attput, cfid, 'site_name', site_name, /char, /global
ncdf_attput, cfid, 'platform_is_mobile', platform_is_mobile, /char, /global
ncdf_attput, cfid, 'n_gates_vary', n_gates_vary, /global
; We'll give this a value later.
ncdf_attput, cfid, 'ray_times_increase', '     ', /char, /global
ncdf_attput, cfid, 'field_names', strjoin(cfrfields,', '), /char, /global

ncdf_control,cfid,/endef

latlon = rsl_get_radar_latlon(radar)
ncdf_varput,cfid,latid,latlon[0]
ncdf_varput,cfid,lonid,latlon[1]
ncdf_varput,cfid,altid,radar.h.height
ncdf_varput,cfid,instypid,'radar'

get_time_coverage_for_cfr,radar,tcovstart,tcovend
ncdf_varput,cfid,tmcovsttid,tcovstart
ncdf_varput,cfid,tmcovendid,tcovend
ncdf_attput,cfid,timeid,'units','seconds since ' + tcovstart

; Get numerical start time and date.
reads, tcovstart, year, month, day, hour, minute, second, format='(I4,5(X,I2))'
startdate = [year,month,day]
starttime = hour * 3600.d0 + minute * 60.d0 + second

ray_n_gates =  lonarr(timedim)
ray_start_index =  lonarr(timedim)
ray_start_index[0] = 0
azimuth = fltarr(timedim)
elevation = fltarr(timedim)
nsweeps = max(radar.volume.h.nsweeps)
sweep_number = lonarr(sweepdim)
sweep_start_ray_index = lonarr(sweepdim)
sweep_end_ray_index = lonarr(sweepdim)
fixed_angle = fltarr(sweepdim)
nyquist_vel =  fltarr(timedim)
pulse_width = fltarr(timedim)
scan_rate = fltarr(timedim)
prt = fltarr(timedim)
unamb_rng =  fltarr(timedim)
; Check for additional velocity fields (VCP 121) and allocate storage
; accordingly.
extra_vel = where(stregex(fieldlist,'V[23]|S[23]',/boolean),count)
if count gt 0 then begin
    prt2 = fltarr(timedim)
    prt3 = fltarr(timedim)
    nyquist_vel2 =  fltarr(timedim)
    nyquist_vel3 =  fltarr(timedim)
endif

; For WSR-88D, check for the possibility that only the velocity field was
; selected.  In that case, there's no need to do the split-cut manipulations.
vr_only = 0
if wsr88d then begin
    vrsw = where(stregex(fieldlist,'V[R23]|S[W23]',/boolean),count,$
        complement=non_vr)
    if count gt 0 && non_vr[0] eq -1 then vr_only = 1
endif

; Load moments arrays.

time = dblarr(timedim)
itime = 0L ; ray index.
velindex = where(fieldlist eq 'VR')
velindex = velindex[0]
splitcut = 0
for iswp = 0, nsweeps-1 do begin
    iray = 0
    nrays = radar.volume[volindex[0]].sweep[iswp].h.nrays
    sweep_number[iswp] = radar.volume[volindex[0]].sweep[iswp].h.sweep_num-1
    fixed_angle[iswp] = radar.volume[volindex[0]].sweep[iswp].ray[0].h.fix_angle
    sweep_start_ray_index[iswp] = itime
    if wsr88d && ~ vr_only then splitcut = rsl_is_split_cut(radar,iswp)
    if splitcut then get_vr_indices, radar, iswp, iray_vr, iray_v2, iray_v3
    while iray lt nrays do begin
        for ifield = 0, n_elements(fieldids)-1 do begin
            ivol = volindex[ifield]
            ray = radar.volume[ivol].sweep[iswp].ray[iray]
            thisfield = fieldlist[ifield]
            if splitcut && stregex(thisfield,'V[R23]|S[W23]',/boolean) $
                then begin
                ; Use ray offset for WSR-88D splitcut velocity, spectrum width.
                case thisfield of
                    stregex(thisfield,'VR|SW',/extract): begin
                        vrray_offset = iray_vr[iray]
                    end
                    stregex(thisfield,'V2|S2',/extract): begin
                        vrray_offset = iray_v2[iray]
                    end
                    stregex(thisfield,'V3|S3',/extract): begin
                        vrray_offset = iray_v3[iray]
                    end
                endcase
                ray=radar.volume[ivol].sweep[iswp].ray[vrray_offset]
            endif
            nbins = ray.h.nbins
            if wsr88d then begin
                ; If ray gate size eq 1000 m (legacy DZ), rebin for 250 m.
                if ray.h.gate_size eq 1000 and gate_size eq 250 then begin
                    raydata=fltarr(4L*nbins)
                    j=0
                    for i=0,ray.h.nbins-1 do begin
                        raydata[j:j+3]=ray.range[i]
                        j = j + 4
                    endfor
                endif else raydata=ray.range[0:nbins-1]
            endif else raydata=ray.range[0:nbins-1]
            if packthis[ifield] then begin
                loc = where(raydata ne missing_data_value,complement=locmissing)
                if loc[0] ne -1 then raydata = fix( $
                    round((raydata-addoff[ifield])/scalefac[ifield]))
                if locmissing[0] ne -1 then raydata[locmissing]= fillval[ifield]
            endif
            if thisfield eq 'HC' then begin
                ; Convert HydroClass to short integer, packing unnecessary.
                loc = where(raydata ne missing_data_value,complement=locmissing)
                if loc[0] ne -1 then raydata = fix(round(raydata))
                if locmissing[0] ne -1 then raydata[locmissing]= fillval_short
            endif
            if n_gates_vary eq 'true' then begin
                ncdf_varput, cfid, fieldids[ifield], raydata, $
                    offset=ray_start_index[itime]
            endif else begin
                ncdf_varput, cfid, fieldids[ifield], raydata, $
                    offset=[0,itime]
            endelse
            ; Use first field for metadata.
            if ifield eq 0 then begin
                ray_n_gates[itime] = nbins
                azimuth[itime] =  ray.h.azimuth
                elevation[itime] =  ray.h.elev
                pulse_width[itime] = ray.h.pulse_width
                scan_rate[itime] = ray.h.azim_rate
                prt[itime] = ray.h.prf ne 0. ? 1./ray.h.prf : prtfill
                nyquist_vel[itime] = ray.h.nyq_vel
                unamb_rng[itime] = ray.h.unam_rng * 1000. ; km to m
                time[itime] = seconds_since_start(ray,startdate,starttime)
            endif
            ; Use PRT and Nyquist from VEL fields.
            if thisfield eq 'VR' then begin
                prt[itime] = ray.h.prf ne 0. ? 1./ray.h.prf : prtfill
                nyquist_vel[itime] = ray.h.nyq_vel
            endif
            ; PRT and Nyquist for VCP 121 additional Doppler cuts.
            if thisfield eq 'V2' then begin
                prt2[itime] = ray.h.prf ne 0. ? 1./ray.h.prf : prtfill
                nyquist_vel2[itime] = ray.h.nyq_vel
            endif
            if thisfield eq 'V3' then begin
                prt3[itime] = ray.h.prf ne 0. ? 1./ray.h.prf : prtfill
                nyquist_vel3[itime] = ray.h.nyq_vel
            endif
        endfor ; ifield
        iray = iray + 1
        itime = itime + 1
        if itime lt timedim then ray_start_index[itime] = $
            ray_start_index[itime-1]+ray_n_gates[itime-1]
    endwhile ; iray lt nrays
    sweep_end_ray_index[iswp] = itime-1
endfor ; iswp

ncdf_varput,cfid,'time',time
ncdf_varput,cfid,'range',range
if n_gates_vary eq 'true' then begin
    ncdf_varput,cfid,'ray_start_index',ray_start_index
    ncdf_varput,cfid,'ray_n_gates',ray_n_gates
endif
ncdf_varput,cfid,'azimuth',azimuth
ncdf_varput,cfid,'elevation',elevation
ncdf_varput,cfid,'sweep_number',sweep_number
ncdf_varput,cfid,'fixed_angle',fixed_angle
ncdf_varput,cfid,'sweep_start_ray_index',sweep_start_ray_index
ncdf_varput,cfid,'sweep_end_ray_index',sweep_end_ray_index
ncdf_varput,cfid,'sweep_mode',sweep_mode
ncdf_varput,cfid,'pulse_width',pulse_width
ncdf_varput,cfid,'scan_rate',scan_rate
ncdf_varput,cfid,'prt',prt
if n_elements(prt2) gt 0 then ncdf_varput,cfid,'prt2',prt2
if n_elements(prt3) gt 0 then ncdf_varput,cfid,'prt3',prt3
ncdf_varput,cfid,'nyquist_velocity',nyquist_vel
if n_elements(nyquist_vel2) gt 0 then $
    ncdf_varput,cfid,'nyquist_velocity2',nyquist_vel2
if n_elements(nyquist_vel3) gt 0 then $
    ncdf_varput,cfid,'nyquist_velocity3',nyquist_vel3
ncdf_varput,cfid,'unambiguous_range',unamb_rng
ncdf_varput,cfid,'radar_beam_width_h',radar.volume[0].sweep[0].h.beam_width
ncdf_varput,cfid,'radar_beam_width_v',radar.volume[0].sweep[0].h.beam_width
; Ray header stores frequency in gigahertz. Convert to hertz for CfRadial.
ncdf_varput,cfid,'frequency',radar.volume[0].sweep[0].ray[0].h.frequency * $
    1.0e+9
ncdf_attget,cfid,'volume_number','_FillValue',vnumfill
ncdf_varput,cfid,'volume_number',vnumfill

; Determine whether or not ray times increase.  Times from first sweep suffice.
timesamp = time[sweep_start_ray_index[0]:sweep_end_ray_index[0]]
sorti = sort(timesamp)
if array_equal(timesamp, timesamp[sorti]) then $
    ncdf_attput, cfid, 'ray_times_increase', 'true', /char, /global $
else ncdf_attput, cfid, 'ray_times_increase', 'false', /char, /global

ncdf_close, cfid
file_opened = 0
if keyword_set(gzip) then spawn, 'gzip -f ' + filename

end
