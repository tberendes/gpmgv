;+
; rsl_d3r_to_radar
;
; Read a D3R file and return data in a Radar structure.
; (D3R is short for Dual-frequency Dual-polarized Doppler Radar.)
;
; Syntax:
;     radar = rsl_d3r_to_radar(d3rfile [, FIELDS=string_array]
;                 [, ERROR=variable] [, /CATCH_ERROR] [, /KEEP_RADAR])
;
; Inputs:
;     d3rfile:  D3R sweep file in netCDF.
;
; Keyword parameters:
;     FIELDS:
;         String array containing fields to be processed (can be scalar string
;         for a single field). Default is all fields. Fields are in the form of
;         the 2-character names used by RSL and UF, such as 'DZ', 'VR', etc.
;     CATCH_ERROR:
;         This keyword is set by default.  If an error occurs, control is
;         returned to the calling program.  Set CATCH_ERROR to 0 to turn off
;         error handler.
;     ERROR:
;         Set this keyword to a variable to return the error status.
;         A value of 1 is returned for error, 0 otherwise.
;     KEEP_RADAR:
;         Set this keyword to return the radar structure if an error
;         occurs.  If an error occurs and this is not set, -1 is returned.
;     NOPRINT_SKIPPED_FIELDS:
;         Don't print messages about skipping unknown fields.
;
; Assumptions: File contains one sweep.
;
; Updated: 23 Feb 2017 by Stephanie M. Wingo
;	(1) updated filename parsing for 'ka' or 'ku' band label
;  	    to work with OLYMPEX campaign file names & fact that
;	    OLYMPEX Ku-band data do not include Kdp, CZ, CR fields
; Updated: 3 August 2016 by Bart Kelley
;       (1) Replace any 'NaN' or 'Inf' in data with the missing-data-value.
; Updated: 29 June 2016 by Stephanie M. Wingo
;	(1) modified value for "valid_nbins" --> now 266
; Updated: 27 June 2016 by Stephanie M. Wingo
;	(1) new field names, and must set fields base on Ka- or Ku-band
; Updated: 5 June 2016 by Stephanie M. Wingo
;	(1) rho hv field name changed to 'CopolarCorrelation'
;       (2) Kdp field not included in D3R .nc files
; Written by Bart Kelley, SSAI, July 2013
;-
;**************************************************************************

function rsl_d3r_to_radar, d3rfile, fields=fields, error=error, $
    catch_error=catch_error, keep_radar=keep_radar, $
    noprint_skipped_fields=noprint_skipped_fields

radar = -1
error = 0

if n_elements(catch_error) eq 0 then catch_error = 1
if n_elements(keep_radar) eq 0 then keep_radar = 0

; Error handler.
catch, errcode
if errcode ne 0 then begin
    catch, /cancel
    print,!error_state.msg_prefix+!error_state.msg
    if !error_state.sys_msg ne '' then print, '  '+!error_state.sys_msg
    error = 1
    if not keep_radar then radar = -1
    goto, finished
endif

; If CATCH_ERROR is 0, cancel the error handler.
if not catch_error then catch, /cancel

cfid = ncdf_open(d3rfile,/nowrite)
info = ncdf_inquire(cfid)
if info.ngatts gt 0 then begin
    ; Get global attributes.
    gattnames = strarr(info.ngatts)
    for i=0, info.ngatts-1 do begin
        gattnames[i] = ncdf_attname(cfid,i,/global)
    endfor
endif else gattnames = ''
loc = (where(strmatch(gattnames,'ScanType',/fold)))[0] ; gets first element
if loc ne -1 then begin
    ncdf_attget,cfid,gattnames[loc],scancode,/global 
    if scancode eq 2 then scanmode = 'PPI' $
        else if scancode eq 3 then scanmode = 'RHI' else scanmode = 'UNKNOWN'
endif else scanmode = ''
loc = (where(strmatch(gattnames,'SweepNumber',/fold)))[0]
if loc ne -1 then ncdf_attget,cfid,gattnames[loc],sweepnum,/global $
    else sweepnum = 1

; D3R data moment names in netCDF:
;   Reflectivity
;   Velocity
;   SpectralWidth
;   DifferentialReflectivity
;   DifferentialPhase (Phi)
;   CrossPolCorrelation (Rho) --> now called CopolarCorrelation
;   NormalizedCoherentPower (SQI)
;   CorrectedReflectivity --> only in Ku
;   CorrectedDifferentialReflectivity  --> only in Ku
;   SpecificPhase (KDP)  --> only in Ku, now called SpecificDifferentialPhase

; determine if this d3r file is for Ka- or Ku-band:
basename = file_basename(d3rfile, '.nc')
band = strmid(basename, 0, 2)   ;d3r filenames always begin w/ "ka" or "ku"
;print, '---D3R DATA FILE: ', d3rfile
;print, '--------basename: ', basename
;print, '------------band: ', band


if band eq 'ku' then begin
d3r_fields = [ $
    'Reflectivity',  $
    'Velocity',  $
    'SpectralWidth', $
    'DifferentialReflectivity', $
    'DifferentialPhase', $
    'CopolarCorrelation', $
    'CorrectedReflectivity', $
    'CorrectedDifferentialReflectivity', $
    'SpecificDifferentialPhase', $
    'NormalizedCoherentPower' $
    ]
    
rsl_fields = [ $
    'DZ', $
    'VR', $
    'SW', $
    'DR', $
    'PH', $
    'RH', $
    'CZ', $
    'CR', $
    'KD', $
    'SQ'  $
    ]
endif
if band eq 'ka' then begin
d3r_fields = [ $
    'Reflectivity',  $
    'Velocity',  $
    'SpectralWidth', $
    'DifferentialReflectivity', $
    'DifferentialPhase', $
    'CopolarCorrelation', $
    ;'CorrectedReflectivity', $
    ;'CorrectedDifferentialReflectivity', $
    ;'SpecificDifferentialPhase', $
    'NormalizedCoherentPower' $
    ]
    
rsl_fields = [ $
    'DZ', $
    'VR', $
    'SW', $
    'DR', $
    'PH', $
    'RH', $
    ;'CZ', $
    ;'CR', $
    ;'KD', $
    'SQ'  $
    ]
endif
if band ne 'ka' and band ne 'ku' then begin

  ; first, try to see if file is from a field campaign:
  ;   have olympex campaign, can add others as needed
  prefix = strmid(basename, 0, 7)

  if prefix eq 'olympex' then begin
    band = strmid(basename, 12, 2)

    ; olympex D3R data do not contain KD, CZ, CR fields:
    if band eq 'ku' then begin
	d3r_fields = [ 'Reflectivity',  $
	    		'Velocity',  $
		    'SpectralWidth', $
		    'DifferentialReflectivity', $
		    'DifferentialPhase', $
		    'CopolarCorrelation', $
		    'NormalizedCoherentPower']
	rsl_fields = ['DZ', $
	   	 'VR', $
	   	 'SW', $
	    	 'DR', $
		 'PH', $
	    	 'RH', $
	    	 'SQ']
    endif
    if band eq 'ka' then begin
	d3r_fields = [ 'Reflectivity',  $
	    		'Velocity',  $
		    'SpectralWidth', $
		    'DifferentialReflectivity', $
		    'DifferentialPhase', $
		    'CopolarCorrelation', $
		    'NormalizedCoherentPower']
	rsl_fields = ['DZ', $
	   	 'VR', $
	   	 'SW', $
	    	 'DR', $
		 'PH', $
	    	 'RH', $
	    	 'SQ']
    endif
  endif else begin
  
  ; if not from a known campaign, issue notice to terminal:
  print, '----BAND NOT FOUND CORRECT OR FILENAME CONVENTION HAS CHANGED!'
  print, '-------must have ka or ku band for D3R data---'
  ; so don't set _fields values & when code below tries they DNE, stops
  endelse
endif




    
if n_elements(fields) gt 0 then selected_fields = strupcase(fields) $
    else selected_fields = rsl_fields

; Loop through data fields to determine the volume dimension for the radar
; structure.

nfields = 0
; Get variable ID for Reflectivity field.  Use this as starting loop index to
; get the IDs and names of the other fields.
reflid = ncdf_varid(cfid,'Reflectivity')
for id = reflid, info.nvars-1 do begin
    vinfo = ncdf_varinq(cfid,id)
    ; Check that this field is in list of recognized D3R fields.
    pos = where(d3r_fields eq vinfo.name, count)
    pos = pos[0]
    if count gt 0 then begin
        ; If D3R field has an RSL equivalent, and field is selected, increment
        ; field count. 
        if pos lt n_elements(rsl_fields) then begin
            this_rslfield = rsl_fields[pos]
            ; We don't care about "pos" here, just want the match count.
            pos = where(selected_fields eq this_rslfield, count)
            if count gt 0 then nfields++
        endif else begin
            print,'rsl_d3r_to_radar:',f='(/a)'
            print,"Can't match D3R field "+vinfo.name+" to any RSL field name."
            print,'Skipping.'
        endelse
    endif else begin
        if not keyword_set(noprint_skipped_fields) then begin
            print,'rsl_d3r_to_radar:',f='(/a)'
            print,"I don't know this D3R field: " + vinfo.name
            print,'Skipping.'
        endif
    endelse
endfor

; Get number of rays and range bins.
; Note: Currently, dimension for Radial is unlimited but contains a value.

for i = 0,info.ndims-1 do begin
    ncdf_diminq, cfid, i, name, size
    if name eq 'Radial' then nrays = size else $
        if name eq 'Gate' then nbins = size
endfor

nsweeps = 1

radar = rsl_new_radar(nfields, nsweeps, nrays, nbins)

; Get data for selected fields, put into radar structure.

for i = 0, n_elements(selected_fields)-1 do begin
    pos = where(rsl_fields eq selected_fields[i])
    this_field = d3r_fields[pos[0]]
    ncdf_varget, cfid, this_field, data 
    ; Replace any occurence of NaN or Inf with missing-data-value.
    s = where(~finite(data),count)
    if count gt 0 then data[s] = radar.volume[i].h.no_data_flag
    radar.volume[i].sweep[0].ray.range = data
endfor

; Put time in ray headers.

year=0
month=0
day=0
hour=0
minute=0
sec=0.
ncdf_varget, cfid, 'Time', time
; Convert time to string type for SPAWN.
time = string(time,f='(i0)')
for i = 0, nrays-1 do begin 
    spawn,'date -u +"%Y %m %d %H %M %S" -d @'+time[i], datestr
    reads,datestr,year,month,day,hour,minute,sec
    radar.volume.sweep.ray[i].h.year = year
    radar.volume.sweep.ray[i].h.month = month
    radar.volume.sweep.ray[i].h.day = day
    radar.volume.sweep.ray[i].h.hour = hour
    radar.volume.sweep.ray[i].h.minute = minute
    radar.volume.sweep.ray[i].h.sec = sec
endfor

; For ray headers, adjust nbins to the number of valid bins as of July 16, 2013.
; This number is subject to change.
;valid_nbins = 255
valid_nbins = 266
nbins = nbins < valid_nbins ; Use the lesser of the two values.

; Load headers.

radar.volume[0:nfields-1].h.field_type = selected_fields
radar.volume[0:nfields-1].sweep.h.field_type = selected_fields
radar.volume.h.nsweeps = nsweeps
radar.volume.sweep.h.sweep_num = sweepnum
radar.volume.sweep.h.nrays = nrays
radar.volume.sweep.ray.h.nbins = nbins
ncdf_varget, cfid, 'Azimuth', data
radar.volume.sweep.ray.h.azimuth = data
ncdf_varget, cfid, 'Elevation', data
radar.volume.sweep.ray.h.elev = data
ncdf_varget,cfid,'GateWidth', data
radar.volume.sweep.ray.h.gate_size = data/1000.
ncdf_varget,cfid,'StartRange',data
; If StartRange contains infinitesimal values, replace with 0.
s = where(data lt 1.e-20,count)
if count gt 0 then data[s] = 0.
radar.volume.sweep.ray.h.range_bin1 = data/1000.
s = where(radar.volume.h.field_type eq 'VR',count)
if count gt 0 then radar.volume[s[0]].sweep.ray.h.nyq_vel = 25.
beam_width = 1.
radar.volume.sweep.ray.h.beam_width = beam_width
; Determine scan mode if it was not in the netCDF file.
if scanmode eq '' then begin
    if variance(radar.volume[0].sweep[0].ray.h.azimuth) gt $
        variance(radar.volume[0].sweep[0].ray.h.elev) then $
        scanmode = 'PPI' $
        else scanmode = 'RHI'
endif
radar.h.scan_mode = scanmode
if radar.h.scan_mode ne 'RHI' then begin
    radar.volume.sweep.ray.h.fix_angle = radar.volume[0].sweep.ray[0].h.elev
endif else begin
    radar.volume.sweep.ray.h.fix_angle = radar.volume[0].sweep.ray[0].h.azimuth
endelse
radar.volume.sweep.h.fixed_angle = radar.volume[0].sweep.ray[0].h.fix_angle
radar.volume.sweep.h.beam_width = beam_width
radar.volume.sweep.h.vert_half_bw = beam_width/2.
radar.volume.sweep.h.horz_half_bw = beam_width/2.
if radar.h.scan_mode ne 'RHI' then radar.volume.sweep.h.elev = $
    radar.volume[0].sweep.ray[0].h.elev

; Load radar header.
ncdf_attget,cfid,'Time',starttime,/global
spawn,'date -u +"%Y %m %d %H %M %S" -d @'+string(starttime,f='(i0)'), datestr
reads,datestr,year,month,day,hour,minute,sec
radar.h.year = year
radar.h.month = month
radar.h.day = day
radar.h.hour = hour
radar.h.minute = minute
radar.h.sec = sec
ncdf_attget,cfid,'RadarName',radarname,/global
radarname = string(radarname)
radar.h.name = radarname
radar.h.radar_name = radarname
radar.h.radar_type = 'D3R'
ncdf_attget,cfid,'Latitude',radarlat,/global
ncdf_attget,cfid,'Longitude',radarlon,/global
; Convert radar coordinates to degrees-minutes-seconds.
lat = abs(radarlat)
if radarlat ge 0. then sign = 1 else sign = -1
latd = fix(lat)
latm = fix((lat - latd) * 60.)
lats= round(((lat - latd) * 60. - latm) * 60.)
radar.h.latd = sign * latd
radar.h.latm = sign * latm
radar.h.lats = sign * lats
lon = abs(radarlon)
if radarlon ge 0. then sign = 1 else sign = -1
lond = fix(lon)
lonm = fix((lon - lond) * 60.)
lons= round(((lon - lond) * 60. - lonm) * 60.)
radar.h.lond = sign * lond
radar.h.lonm = sign * lonm
radar.h.lons = sign * lons

finished:
ncdf_close, cfid
return, radar
end
