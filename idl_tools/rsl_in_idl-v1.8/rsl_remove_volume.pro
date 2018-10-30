pro rsl_remove_volume, radar, volspec, error=error

;+
; This procedure removes a volume from the radar structure.
;
; Syntax
;     rsl_remove_volume, radar, volspec [, ERROR=variable]
;
; Arguments
;    radar:   radar structure.  It is modified by this procedure.
;    volspec: either a field name or volume index indicating the volume to be
;             removed.
;
; Keywords
;    ERROR:   set this keyword to a variable to return error flag:
;             0 for no error, 1 for error.
;
; Written by:  Bart Kelley, SSAI, February, 2013
;***************************************************************************
;-

on_error, 2

error = 0

if n_elements(volspec) eq 0 then begin
    message,'Missing argument(s)',/informational
    print,'Usage: rsl_remove_volume, radar, volspec [, error=variable]'
    print,'radar:   radar structure.'
    print,'volspec: either a field name or volume index indicating the volume'
    print,'         to be removed.'
    print,'error:   set this keyword to a variable to return error flag:'
    print,'         0 for no error, 1 for error.'
    error = 1
    return
endif

; Make sure target field/volume exists.

if size(volspec,/tname) eq 'STRING' then begin
    field = strupcase(volspec)
    iremove = where(rsl_get_fields(radar) eq field)
    iremove = iremove[0]
    if iremove eq -1 then begin
        error = 1
        message,'Field "' + field + '" not found.'
    endif
endif else iremove = volspec

if iremove ge radar.h.nvolumes then begin
    error = 1
    message,'Volume index = ' + strtrim(iremove,1) + $
        ', exceeds maximum for this radar structure (' + $
        strtrim(radar.h.nvolumes-1,1) + ').'
endif

; Get dimensions for new radar.
dims = size(radar.volume.sweep.ray.range,/dimensions)
newradar = rsl_new_radar(radar.h.nvolumes-1, dims[2], dims[1], dims[0])

; Copy all but target volume to new radar.
tovol = 0
nsweeps =  max(radar.volume.h.nsweeps)
for fromvol = 0, radar.h.nvolumes-1 do begin
    if fromvol ne iremove then begin
        for i = 0, nsweeps-1 do begin
            newradar.volume[tovol].sweep[i] = radar.volume[fromvol].sweep[i]
        endfor
        newradar.volume[tovol].h = radar.volume[fromvol].h
        tovol++
    endif
endfor

newradar.h = radar.h
newradar.h.nvolumes = radar.h.nvolumes - 1
radar = newradar
newradar = 0 ; Clear memory.

end
