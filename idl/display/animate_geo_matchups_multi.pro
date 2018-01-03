pro animate_geo_matchups_multi, sweeplevel
;
; DESCRIPTION
; Reads PR and GV reflectivity and spatial fields from a user-selected geo_match
; netCDF file, and builds an animation loop of the data over the elevation
; sweeps in the dataset.  The animation works its way up through the
; elevation sweeps.
;

@geo_match_nc_structs.inc

IF ( N_PARAMS() EQ 1 ) THEN swp2show = sweeplevel ELSE swp2show = 2
;pathpr='/tmp'
pathpr='/data/netcdf/geo_match'
ncfilepr = dialog_pickfile(path=pathpr,filter='*Multi*')

while ncfilepr ne '' do begin

; Get uncompressed copy of the found files
cpstatus = uncomp_file( ncfilepr, ncfile1 )
if(cpstatus eq 'OK') then begin
  status = 1   ; init to FAILED
  mygeometa={ geo_match_meta }
  mysweeps={ gv_sweep_meta }
  mysite={ gv_site_meta }
  myflags={ pr_gv_field_flags }
  status = read_geo_match_netcdf_multi( ncfile1, matchupmeta=mygeometa, $
     sweepsmeta=mysweeps, sitemeta=mysite, fieldflags=myflags )
  nfp = mygeometa.num_footprints  ; # of PR rays in dataset (real+bogus)
  nswp = mygeometa.num_sweeps     ; # of GR elevation sweeps in dataset
  nvol = mygeometa.num_volumes    ; # of GR volume scans in dataset

  gvexp=intarr(nfp,nswp,nvol)
  gvrej=intarr(nfp,nswp,nvol)
  prexp=intarr(nfp,nswp)
  zrawrej=intarr(nfp,nswp)
  zcorrej=intarr(nfp,nswp)
  rainrej=intarr(nfp,nswp)
  gvz=intarr(nfp,nswp,nvol)
  zraw=fltarr(nfp,nswp)
  zcor=fltarr(nfp,nswp)
  rain3=fltarr(nfp,nswp)
  top=fltarr(nfp,nswp)
  botm=fltarr(nfp,nswp)
  lat=fltarr(nfp,nswp)
  lon=fltarr(nfp,nswp)
  bb=fltarr(nfp)
  nearSurfRain=fltarr(nfp)
  nearSurfRain_2b31=fltarr(nfp)
  rnflag=intarr(nfp)
  rntype=intarr(nfp)
  pr_index=lonarr(nfp)
  xcorner=fltarr(4,nfp,nswp)
  ycorner=fltarr(4,nfp,nswp)

  status = read_geo_match_netcdf_multi( ncfile1,  $
    gvexpect_int=gvexp, gvreject_int=gvrej, prexpect_int=prexp, $
    zrawreject_int=zrawrej, zcorreject_int=zcorrej, rainreject_int=rainrej, $
    dbzgv=gvz, dbzcor=zcor, dbzraw=zraw, rain3d=rain3, topHeight=top, $
    bottomHeight=botm, latitude=lat, longitude=lon, bbhgt=BB, $
    sfcrainpr=nearSurfRain, sfcraincomb=nearSurfRain_2b31, $
    rainflag_int=rnFlag, raintype_int=rnType, pridx_long=pr_index, $
    xCorners=xCorner, yCorners=yCorner )

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
windowsize = 375
xsize = windowsize[0]
ysize = xsize
nframes = nvol

window, 0, xsize=xsize, ysize=ysize*2, xpos = 75, TITLE = title, /PIXMAP
xinteranimate, set=[xsize, ysize*2, nframes], /TRACK

error = 0
loadcolortable, 'CZ', error
if error then begin
    print, "error from loadcolortable"
    goto, errorExit
endif

FOR ifram=0,nframes-1 DO BEGIN
elevstr =  string(mysweeps[swp2show].elevationAngle, FORMAT='(f0.1)')
prtitle = "PR for "+elevstr+" degree sweep, " + mygeometa.atimeNearestApproach
myprbuf = plot_sweep_2_zbuf( zcor, mysite.site_lat, mysite.site_lon, xCorner, $
                             yCorner, pr_index, mygeometa.num_footprints, swp2show, $
                             WINSIZ=windowsize, TITLE=prtitle )
gvtitle = mysite.site_ID+" "+elevstr+" degree sweep, " + mysweeps[swp2show,ifram].atimeSweepStart
mygvbuf = plot_sweep_2_zbuf( gvz[*,*,ifram], mysite.site_lat, mysite.site_lon, xCorner, $
                             yCorner, pr_index, mygeometa.num_footprints, swp2show, $
                             WINSIZ=windowsize, TITLE=gvtitle )
;print, "Finished zbuf pair ", ifram+1

SET_PLOT, 'X'
device, decomposed=0
TV, myprbuf, 0
TV, mygvbuf, 1
xinteranimate, frame = ifram, window=0
ENDFOR

print, ''
print, 'Click END ANIMATION button or close Animation window to proceed to next case:
print, ''
xinteranimate, 3, /BLOCK

ncfilepr = dialog_pickfile(path=pathpr,filter='*Multi*')
endwhile

errorExit:
end
