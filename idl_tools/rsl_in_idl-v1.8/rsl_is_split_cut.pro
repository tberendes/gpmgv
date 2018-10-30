function rsl_is_split_cut, radar, iswp

; This function determines if the WSR-88D sweep at index iswp is a split cut.
; It does this by comparing the elevation and azimuth of a DZ and VR ray.  If
; the elevations are approximately the same and azimuths are different, it's a
; split cut.
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
