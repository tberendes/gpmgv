function wsr88d_get_site_info, siteid, site_file=input_site_file

; Get site info.

on_error, 2 ; on error, return to caller.

; If siteid is 4 characters long, it is assumed to be a valid siteid.
; If siteid is longer than 4 characters, assume it is a filename that contains
; the siteid embedded within its name.

fromfilename = 0
if strlen(siteid) gt 4 then begin
    fromfilename = 1
    uppercasename = strupcase(siteid) ; for matching later
endif

; Locate the WSR-88D site file.
default_site_file = 'wsr88d_locations.dat'
site_file = default_site_file
if n_elements(input_site_file) gt 0 then site_file = input_site_file
if ~ file_test(site_file) then site_file = file_which(site_file)
if site_file eq '' then begin
    if n_elements(input_site_file) gt 0 then site_file = input_site_file $
    else site_file = default_site_file
    print,'wsr88d_get_site_info: Site info file ' + site_file + ' not found.'
    return, -1
endif

openr, lunit, site_file, /get_lun

; Search for matching site id.
sitenum = 0L
site = ''
site_rec = ''
found = 0
while ~ found && ~ eof(lunit) do begin
    readf, lunit, site_rec
    items = strsplit(site_rec,/extract)
    sitenum = items[0]
    site = items[1]
    found = site eq siteid
    if fromfilename then if strpos(uppercasename,site) gt -1 then found = 1
endwhile
free_lun, lunit

if not found then begin
    print,'wsr88d_get_site_info: Site id '+ siteid +' not found in ' + $ 
        'file ' + site_file + '.'
    print,'To correct, add site information for this radar to ' + site_file +'.'
    return, -1
endif

city = items[2]
state = items[3]
lat_lon_ht = strjoin(items[4:*],' ')
latd=0 & latm=0 & lats=0 & lond=0 & lonm=0 & lons=0 & height=0L
reads, lat_lon_ht, latd, latm, lats, lond, lonm, lons, height
siteinfo={sitenum:sitenum, siteid:site, city:city, state:state, latd:latd,$
    latm:latm, lats:lats, lond:lond, lonm:lonm, lons:lons, height:height}
return,  siteinfo
end
