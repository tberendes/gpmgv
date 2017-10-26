function rsl_get_radar_site_info, radarname, sitefile=sitefile

; Return a structure containing information from gv_radar_site_info.data for
; this radar.
;
; Inputs:
;   radarname - the four-character radar site name.  It can be either TSDIS
;               or WSR-88D name.
;
; Keyword parameters:
;   sitefile - name of GV radar site information file. Default name is
;       ~/idl/rsl_in_idl/gv_radar_site_info.data.
;

if not keyword_set(sitefile) then sitefile = $
    findfile('~/idl/rsl_in_idl/'+'gv_radar_site_info.data')

openr, lun, sitefile, /get_lun

sitename = strupcase(radarname)
line = ''
found = 0
while not found do begin
    readf,lun,line
    if strmid(line,0,1) eq "#" then continue ; read through comments
    s=strsplit(line,',',/extract)
    if strtrim(s[0],2) eq sitename or strtrim(s[5],2) eq sitename then $
        found = 1
endwhile
free_lun, lun

siteinfo = { $
  tsdisname:strtrim(s[0],2),  $
  nexradname:strtrim(s[1],2), $
  city:strtrim(s[2],2),     $
  state:strtrim(s[3],2),    $
  country:strtrim(s[4],2),  $
  radarnum:strtrim(s[5],2),  $
  lat:float(s[6]),    $
  lon:float(s[7]),    $
  sprintid:fix(s[8])  $
}

return, siteinfo
end
