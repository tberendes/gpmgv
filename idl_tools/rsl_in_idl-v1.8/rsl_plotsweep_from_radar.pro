pro rsl_plotsweep_from_radar, radar, elevation=elevation, field=field, $
        sweep_index=sweepindex, volume_index=volume_index,  $
	catch_error=catch_error, _EXTRA=keywords
;+
; rsl_plotsweep_from_radar
;
; Calls rsl_plotsweep to plot radar image for a sweep.  If elevation or sweep is
; not specified, the base scan is used by default.
;
; Syntax:
;     rsl_plotsweep_from_radar, radar [, ELEVATION=elevation] [, FIELD=field]
;	   [, SWEEP_INDEX=sweepindex] [, VOLUME_INDEX=volume_index]
;          [, /CATCH_ERROR] [, rsl_plotsweep keywords]
;
; Inputs:
;    radar:     a radar structure.
;
; Keyword parameters:
;    ELEVATION:
;        Elevation angle of the sweep to be plotted.  If omitted,
;        SWEEP_INDEX is used if given, otherwise base scan is used.
;    FIELD:
;        A string identifying the radar field to select, for example,
;        'DZ'.  If omitted, and VOLUME_INDEX does not have a value, the
;        first field in the volume structure is used.  If FIELD and
;        VOLUME_INDEX both have values, the value of FIELD is used.
;    SWEEP_INDEX:
;        Index of sweep to be plotted, where zero is the base scan
;        (default).  If both ELEVATION and SWEEP_INDEX are given,
;        ELEVATION is used.
;    VOLUME_INDEX: 
;        The index number of volume (0 to nvols-1) to select.  Default
;        is 0.  If FIELD has a value, VOLUME_INDEX is ignored.
;    CATCH_ERROR:
;        This keyword is set by default.  If an error occurs, control is
;        returned to the calling program.  Set CATCH_ERROR to 0 to turn off
;        error handler.
;    rsl_plotsweep keywords:
;        Keywords to be passed to rsl_plotsweep procedure.
;        See rsl_plotsweep.pro for descriptions.
;
; Written by:  Bart Kelley, GMU, May 2002
;-
;***********************************************************************

; Set error handler by default.
if n_elements(catch_error) eq 0 then catch_error = 1

; Error handler.
catch, errcode
if errcode ne 0 then begin
    catch, /cancel
    print,!error_state.msg_prefix+!error_state.msg
    if !error_state.sys_msg ne '' then print, '  '+!error_state.sys_msg
    return
endif
if catch_error eq 0 then catch, /cancel

volume_id = 0
volume = -1
sweep  = -1

if keyword_set(volume_index) then volume_id = volume_index
if keyword_set(field) then volume_id = field

volume = rsl_get_volume(radar, volume_id)
if size(volume,/n_dimensions) gt 0 then $
    sweep = rsl_get_sweep(volume, elevation, sweep_index=sweepindex)
if size(sweep,/n_dimensions) gt 0 then $
    rsl_plotsweep, sweep, radar.h, catch_error=catch_error, _EXTRA=keywords
end
