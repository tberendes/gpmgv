pro check_geo_matchups
;
; DESCRIPTION
; Reads PR and GV reflectivity and spatial fields from a user-selected geo_match
; netCDF file, and builds an animation loop of the data over the elevation
; sweeps in the dataset.  The animation alternates between the PR and GV
; reflectivity fields at each elevation level, working its way up through the
; elevation sweeps.
;

@geo_match_nc_structs.inc
FORWARD_FUNCTION plot_sweep_2_zbuf

pathpr='/data/netcdf/geo_match'
ncfilepr = dialog_pickfile(path=pathpr)

while ncfilepr ne '' do begin

; Get uncompressed copy of the found files
cpstatus = uncomp_file( ncfilepr, ncfile1 )
if(cpstatus eq 'OK') then begin
  status = 1   ; init to FAILED
  mygeometa={ geo_match_meta }
  mysweeps={ gv_sweep_meta }
  mysite={ gv_site_meta }
  myflags={ pr_gv_field_flags }
  gvexp=intarr(2)
  gvrej=intarr(2)
  prexp=intarr(2)
  zrawrej=intarr(2)
  zcorrej=intarr(2)
  rainrej=intarr(2)
  gvz=intarr(2)
  zraw=fltarr(2)
  zcor=fltarr(2)
  rain3=fltarr(2)
  top=fltarr(2)
  botm=fltarr(2)
  xcorner=fltarr(2)
  ycorner=fltarr(2)

  status = read_geo_match_netcdf( ncfile1, matchupmeta=mygeometa, $
    sweepsmeta=mysweeps, sitemeta=mysite, fieldflags=myflags, $
    gvexpect_int=gvexp, gvreject_int=gvrej, prexpect_int=prexp, $
    zrawreject_int=zrawrej, zcorreject_int=zcorrej, rainreject_int=rainrej, $
    dbzgv=gvz, dbzcor=zcor, dbzraw=zraw, rain3d=rain3, topHeight=top, $
    bottomHeight=botm, xCorners=xCorner, yCorners=yCorner )

  command3 = "rm -v " + ncfile1
  spawn, command3
endif else begin
  print, 'Cannot copy/unzip netCDF file: ', ncfilepr
  print, cpstatus
  command3 = "rm -v " + ncfile1
  spawn, command3
  goto, errorExit
endelse

; instantiate animation widget
windowsize = 400
xsize = windowsize[0]
ysize = xsize
nframes = 5<mygeometa.num_sweeps
window, 0, xsize=xsize, ysize=ysize, xpos = 75, TITLE = title, /PIXMAP
;xinteranimate, set=[xsize, ysize, 4], /TRACK
xinteranimate, set=[xsize, ysize, 2*nframes], /TRACK

error = 0
loadcolortable, 'CZ', error
if error then begin
    print, "error from loadcolortable"
    goto, errorExit
endif

;FOR ifram=0,1 DO BEGIN
FOR ifram=0,nframes-1 DO BEGIN
elevstr =  string(mysweeps[ifram].elevationAngle, FORMAT='(f0.1)')
prtitle = "PR for "+elevstr+" degree sweep"
myprbuf = plot_sweep_2_zbuf( zcor, mysite.site_lat, mysite.site_lon, xCorner, $
                             yCorner, mygeometa.num_footprints, ifram, $
                             WINSIZ=windowsize, TITLE=prtitle )
gvtitle = mysite.site_ID+" GV for "+elevstr+" degree sweep"
mygvbuf = plot_sweep_2_zbuf( gvz, mysite.site_lat, mysite.site_lon, xCorner, $
                             yCorner, mygeometa.num_footprints, ifram, $
                             WINSIZ=windowsize, TITLE=gvtitle )
;print, "Finished zbuf pair ", ifram+1

SET_PLOT, 'X'
device, decomposed=0
TV, myprbuf
xinteranimate, frame = ifram*2, window=0
;print, "Loaded pr frame ", ifram+1
TV, mygvbuf
xinteranimate, frame = 1+ifram*2, window=0
;print, "Loaded gv frame ", ifram+1
ENDFOR

print, ''
print, 'Click END ANIMATION button or close Animation window to proceed to next case:
print, ''
xinteranimate, 0, /BLOCK

ncfilepr = dialog_pickfile(path=pathpr)
endwhile

errorExit:
end

FUNCTION plot_sweep_2_zbuf, zdata, radar_lat, radar_lon, xpoly, ypoly, $
                            nfootprints, ilev, WINSIZ=winsiz, TITLE=title

IF N_ELEMENTS( title ) EQ 0 THEN BEGIN
  title = 'level ' + STRING(ilev)
ENDIF
print, title
; Declare function for color plotting.  It is in loadcolortable.pro.
forward_function mapcolors
SET_PLOT,'Z'
winsize = 525
IF ( N_ELEMENTS(winsiz) EQ 1 ) THEN winsize = winsiz
xsize = winsize & ysize = xsize
DEVICE, SET_RESOLUTION = [xsize,ysize]
error = 0
charsize = 0.75

;ilev = 0  ; sweep # to plot


if keyword_set(bgwhite) then begin
    prev_background = !p.background
    !p.background = 255
endif
if !p.background eq 255 then color = 0

maxrange = 125. ; kilometers


; Get the map boundaries corresponding to maxrange.
maxrange_meters = maxrange * 1000.
meters_to_lat = 1. / 111177.
meters_to_lon =  1. / (111177. * cos(radar_lat * !dtor))

nb = radar_lat + maxrange_meters * meters_to_lat 
sb = radar_lat - maxrange_meters * meters_to_lat 
eb = radar_lon + maxrange_meters * meters_to_lon 
wb = radar_lon - maxrange_meters * meters_to_lon 

map_set, radar_lat, radar_lon, limit=[sb,wb,nb,eb],/grid, advance=advance, $
    charsize=charsize,color=color

npts = 4
x = fltarr(npts)
y = fltarr(npts)
lat = fltarr(npts)
lon = fltarr(npts)

loadcolortable, 'CZ', error
if error then begin
    print, "error from loadcolortable"
    goto, bailout
endif

ray = zdata[*,ilev]
inegidx = where( ray lt 0, countneg )
if countneg gt 0 then ray[inegidx] = 0.0

color_index = mapcolors(ray, 'CZ')
if size(color_index,/n_dimensions) eq 0 then begin
    print, "error from mapcolors in PR array"
    goto, bailout
endif

for ifoot = 0, nfootprints-1 do begin
x = xpoly[*,ifoot,7]
y = ypoly[*,ifoot,7]
; Convert points to latitude and longitude coordinates.
lon = radar_lon + meters_to_lon * x * 1000.
lat = radar_lat + meters_to_lat * y * 1000.
polyfill, lon, lat, color=color_index[ifoot],/data

endfor

map_grid, /label, lonlab=sb, latlab=wb, latalign=0.0,/noerase, $
    charsize=charsize, color=color
map_continents,/hires,/usa,/coasts,/countries, color=color

for range = 50.,maxrange,50. do $
    plot_range_rings2, range, radar_lon, radar_lat, color=color

rsl_colorbar, 'CZ', charsize=charsize, color=color

; add image labels
   xyouts, 5, ysize-15, title, CHARSIZE=1, COLOR=255, /DEVICE

bufout = TVRD()
bailout:

return, bufout
end
