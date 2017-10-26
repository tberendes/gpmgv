pro rsl_plotrhi, radar, fieldname, field=fieldkw, $
        sweep_index=sweep_index, volume_index=volume_index, $
	_extra=keywords

; Plot RHI radar image.
;
; Syntax:
;     rsl_plotrhi, radar [, field] [, FIELD=string]
;	  [, SWEEP_INDEX=sweep_index] [, VOLUME_INDEX=volume_index]
;         [, MAXRANGE=value] [, MAXHEIGHT=value]
;         [, /NEW_WINDOW] [, WINDOWSIZE=windowsize]
;         [, LIKE_FIELD=string] [, ABOUT_FIELD=string]
;         [, TITLE=string] [, CHARSIZE=value]
;
; Arguments:
;    radar:     A radar structure.
;    field:     String specifying the radar data field to be plotted, for
;               example, 'DZ'.  Default is the first field stored.
;
; Keywords:
;    FIELD:       Same as field argument.  This keyword is provided for
;                 consistency with other routines.
;    MAXRANGE:    Maximum range to be plotted, in kilometers.  Default is 250.
;    MAXHEIGHT:   Maximum height to be plotted, in kilometers.  Default is 15.
;    NEW_WINDOW:  Set this to open a new plot window.
;    SWEEP_INDEX: Index of RHI sweep to be plotted, where zero is first RHI in
;                 volume.
;    TITLE:       Title to appear above plot.  Default is site name followed
;                 by date and time data was recorded.
;    VOLUME_INDEX: The index number of volume (0 to nvols-1) to select.  Default
;                  is 0.  If FIELD has a value, VOLUME_INDEX is ignored.
;    WINDOWSIZE:  Window size in pixels.  Windowsize may be scalar or a 2
;                 element array.  If scalar, this value is used for the
;                 x and y lengths.  If an array, the first element is the
;                 x length, the second the y length.
;    ABOUT_FIELD: Information about the field which will appear in TITLE.  This
;                 replaces the default field information, which is simply the
;                 field type, such as 'DZ' or 'VR'.
;    LIKE_FIELD:  String specifying the field type to use in selecting color
;                 table and data scaling.  This is necessary when the user
;                 has created a new field type not recognized by rsl_plotrhi.
;    CHARSIZE:    IDL graphics character size.  Default is 1.
;    BGWHITE:     Set this for white background.  Default is black.
;
; Written by Bart Kelley, SSAI, July 2007
; Modified by Bart Kelley, SSAI, August 2011:
;   This routine was reduced to a wrapper for rsl_plotrhi_sweep.pro, which
;   contains most of the original content. 
;***************************************************************************

on_error, 2  ; Return to calling routine.

if radar.h.scan_mode ne 'RHI' then begin
    message,'radar.h.scan_mode is ' + radar.h.scan_mode + ', should be RHI.', $
        /continue
    return
endif

; Get sweep for field.
if n_elements(sweep_index) eq 0 then sweep_index = 0
ivol = 0
if n_elements(volume_index) ne 0 then ivol = volume_index
if n_elements(fieldkw) ne 0 then field = strupcase(fieldkw)
if n_elements(fieldname) ne 0 then field = strupcase(fieldname)
if n_elements(field) ne 0 then begin
    ivol = where(radar.volume.h.field_type eq field)
    ivol = ivol[0]
endif
if ivol gt -1 then sweep = radar.volume[ivol].sweep[sweep_index] $
else begin
    message,'Field ' + field + ' not found.',/continue
    return
endelse

rsl_plotrhi_sweep, sweep, radar.h, _EXTRA=keywords

end
