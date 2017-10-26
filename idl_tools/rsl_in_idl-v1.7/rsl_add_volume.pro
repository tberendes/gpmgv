pro rsl_add_volume, radar, new_volume, field=field

; This procedure adds a new volume to an existing radar structure.
;
; Syntax
;     rsl_add_volume, radar [, new_volume] [, FIELD=string]
;
; Arguments
;     radar:      radar structure.  It is modified by this procedure.
;     new_volume: volume structure to be added to radar structure.  If omitted,
;                 a new volume without data will be added to radar structure.
;
; Keywords
;     FIELD: String naming new field.  If given, it replaces the field type
;            in the new volume header and sweep headers.
;
; Notes
;   The size of structures and arrays in new volume must not differ from
;   those in the target radar structure.
;
; Example 1
; Copy volume from radar, modify data, then add the modified volume to radar.
;
;   ; Copy an existing volume.
;   vol = rsl_get_volume(radar,'dz')
;
;   ; Modify data in vol.
;   vol.sweep.ray.range = . . .
;
;   ; Add vol to radar structure, naming the new field 'FZ'.
;   rsl_add_volume, radar, vol, field='FZ'
;
; Example 2
; Add a volume to radar first, then store data.
;
;   ; Add new volume to radar, and name the new field 'FZ'.
;   rsl_add_volume, radar, field='FZ'
;  
;   ; Modify data in new volume.
;   newvol = radar.h.nvolumes - 1
;   radar.volume[newvol].sweep.ray.range = . . .
;
; Written by Bart Kelley, July 2006
;******************************************************************************

; TODO check conformity of new volume's nsweeps, nrays, nbins.

if n_elements(field) ne 0 then new_field = strupcase(field)

; Check field type against those in radar.

if n_elements(new_volume) gt 0 then begin
    if n_elements(new_field) eq 0 then new_field = new_volume.h.field_type
    fields = rsl_get_fields(radar)
    w = where(fields eq new_field, count)
    if count gt 0 then begin
	message, 'Field type for new volume, "' + new_field + $
	    '", already exists in radar structure.  Volume not added',/continue
	return
    endif
endif

; Allocate new radar structure with space for new volume, and copy radar
; contents into the new radar structure.  Since we know how many actual sweeps
; are in the volume scan, we can save some memory by allocating only that many.

nvolumes = radar.h.nvolumes
nsweeps=radar.volume[0].h.nsweeps
dims = size(radar.volume.sweep.ray.range,/dimensions)
nrays = dims[1]
nbins = dims[0]
newradar = rsl_new_radar(nvolumes+1, nsweeps, nrays, nbins)
newradar.h = radar.h
newradar.volume[0:nvolumes-1].sweep = radar.volume.sweep[0:nsweeps-1]
newradar.volume[0:nvolumes-1].h = radar.volume.h

if n_elements(new_volume) gt 0 then begin
    newradar.volume[nvolumes].sweep = new_volume.sweep[0:nsweeps-1]
    newradar.volume[nvolumes].h = new_volume.h
endif

if n_elements(new_field) gt 0 then begin
    newradar.volume[nvolumes].h.field_type = new_field
    newradar.volume[nvolumes].sweep[0:nsweeps-1].h.field_type = new_field
endif

newradar.h.nvolumes = nvolumes + 1

radar = newradar
newradar = 0 ; To ensure memory is freed.
end
