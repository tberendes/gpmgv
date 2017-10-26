pro gen_pr_and_geo_match_x_sections, ncfilepr, ELEV2SHOW=elev2show
;
; DESCRIPTION
; Reads PR and GV reflectivity and spatial fields from a user-selected geo_match
; netCDF file, and builds a PPI of the data for a given elevation sweep.  Then
; allows a user to select a point on the image for which vertical cross
; sections of full-resolution PR data, volume-matched PR data, and volume-
; matched GV data will be plotted, along the PR scan line through the selected
; point.
;

COMMON sample, start_sample, sample_range, num_range, RAYSPERSCAN

; "Include" file for PR-product-specific parameters (i.e., RAYSPERSCAN):
@pr_params.inc
; "Include" file for names, paths, etc.:
@environs.inc
; "Include file for netCDF-read structs
@geo_match_nc_structs.inc

FORWARD_FUNCTION plot_sweep_2_zbuf_4xsec

; Get uncompressed copy of the found files
cpstatus = uncomp_file( ncfilepr, ncfile1 )
if(cpstatus eq 'OK') then begin
  status = 1   ; init to FAILED
  mygeometa={ geo_match_meta }
  mysweeps={ gv_sweep_meta }
  mysite={ gv_site_meta }
  myflags={ pr_gv_field_flags }
  status = read_geo_match_netcdf( ncfile1, matchupmeta=mygeometa, $
     sweepsmeta=mysweeps, sitemeta=mysite, fieldflags=myflags )

 ; create data field arrays of correct dimensions and read data fields
  nfp = mygeometa.num_footprints
  nswp = mygeometa.num_sweeps
  gvz=intarr(nfp,nswp)
  zraw=fltarr(nfp,nswp)
  zcor=fltarr(nfp,nswp)
  xcorner=fltarr(4,nfp,nswp)
  ycorner=fltarr(4,nfp,nswp)
  top=fltarr(nfp,nswp)
  botm=fltarr(nfp,nswp)
  bb=fltarr(nfp)
  rntype=intarr(nfp)
  pr_index=lonarr(nfp)

  status = read_geo_match_netcdf( ncfile1,  dbzgv=gvz, dbzcor=zcor, $
                                  dbzraw=zraw, xCorners=xCorner, $
                                  yCorners=yCorner, topHeight=top, $
                                  bottomHeight=botm, bbhgt=BB, $
                                  raintype_int=rnType, pridx_long=pr_index )

  command3 = "rm -v " + ncfile1
  spawn, command3
endif else begin
  print, 'Cannot copy/unzip netCDF file: ', ncfilepr
  print, cpstatus
  command3 = "rm -v " + ncfile1
  spawn, command3
  goto, errorExit
endelse

; get array indices of the non-bogus footprints
idxpractual = where(pr_index GE 0L, countactual)
if (countactual EQ 0) then begin
   print, "No non-bogus data points, quitting case."
   goto, errorExit
endif

; convert bright band heights from m to km, where defined, and get mean BB hgt
BB = BB[idxpractual]
idxbbdef = where(bb GT 0.0, countBB)
if ( countBB GT 0 ) THEN BEGIN
   meanbb_m = FIX(MEAN(bb[idxbbdef]))  ; in meters
   meanbb = meanbb_m/1000.        ; in km
   print, 'Mean BB (km): ', meanbb
ENDIF ELSE BEGIN
   print, "No valid bright band heights, quitting case."
   goto, errorExit
ENDELSE

nframes = mygeometa.num_sweeps


; PREP FIELDS NEEDED FOR PPI PLOTS:

; Reclassify rain types down to simple categories 1 (Stratiform), 2 (Convective),
;  or 3 (Other), where defined
idxrnpos = where(rntype ge 0, countrntype)
if (countrntype GT 0 ) then rntype(idxrnpos) = rntype(idxrnpos)/100

; copy the first sweep to the other levels, and make the single-level arrays
; for categorical fields the same dimension as the sweep-level
rnTypeIn = rnType
IF ( nframes GT 1 ) THEN BEGIN  
   FOR iswp=1, nframes-1 DO BEGIN
      rnType = [rnType, rnTypeIn]
   ENDFOR
ENDIF


; Determine the pathnames of the PR product files:

; -- parse ncfile1 to get its component fields: orbit number, YYMMDD
dataPR = FILE_BASENAME(ncfilepr)
parsed=STRSPLIT( dataPR, '.', /extract )
orbit = parsed[3]
DATESTAMP = parsed[2]      ; in YYMMDD format
ncsite = parsed[1]
print, dataPR, " ", orbit, " ", DATESTAMP, " ", ncsite
; put together a title field for the cross-sections
caseTitle = ncsite+' overpass case, day='+DATESTAMP+', Orbit='+orbit

; Query the gpmgv database for the PR filenames for this orbit/subset:
lcquote='''
sqlstr='echo "\t\a \\\select subset, file1c21, file2a25, file2b31 from collatedPRproductswsub where orbit='+orbit+' and radar_id='+lcquote+ncsite+lcquote+';" | psql -q gpmgv'
print, sqlstr
prfiles4=''
spawn, sqlstr, prfiles4
parsepr = STRSPLIT( prfiles4, '|', /extract )
origFile21Name = STRTRIM( parsepr[1], 2 )
origFile25Name = STRTRIM( parsepr[2], 2 )
origFile31Name = STRTRIM( parsepr[3], 2 )

; add the well-known (or local) paths to get the fully-qualified file names
file_1c21 = PRDATA_ROOT+DIR_1C21+"/"+origFile21Name & print, file_1c21
file_2a25 = PRDATA_ROOT+DIR_2A25+"/"+origFile25Name & print, file_2a25
file_2b31 = PRDATA_ROOT+DIR_2B31+"/"+origFile31Name & print, file_2b31

; initialize PR variables/arrays and read 2A25 fields
SAMPLE_RANGE=0
START_SAMPLE=0
num_range = NUM_RANGE_2A25
dbz_2a25=FLTARR(sample_range>1,1,num_range)
rain_2a25 = FLTARR(sample_range>1,1,num_range)
surfRain_2a25=FLTARR(sample_range>1,RAYSPERSCAN)
geolocation=FLTARR(2,RAYSPERSCAN,sample_range>1)
rangeBinNums=INTARR(sample_range>1,RAYSPERSCAN,7)
rainFlag=INTARR(sample_range>1,RAYSPERSCAN)
rainType=INTARR(sample_range>1,RAYSPERSCAN)
status = read_pr_2a25_fields( file_2a25, DBZ=dbz_2a25, RAIN=rain_2a25,   $
                              TYPE=rainType, SURFACE_RAIN=surfRain_2a25, $
                              GEOL=geolocation, RANGE_BIN=rangeBinNums,  $
                              RN_FLAG=rainFlag )
IF ( status NE 0 ) THEN BEGIN
   PRINT, ""
   PRINT, "ERROR reading fields from ", file_2a25
   PRINT, "Skipping events for orbit = ", orbit
   PRINT, ""
   GOTO, errorExit
ENDIF

; Set up the pixmap window for the PPI plots
windowsize = 300
xsize = windowsize[0]
ysize = xsize
window, 0, xsize=xsize, ysize=ysize*2, xpos = 75, TITLE = title, /PIXMAP

error = 0
loadcolortable, 'CZ', error
if error then begin
    print, "error from loadcolortable"
    goto, errorExit
endif

; If a sweep number is not specified, pick one about 1/3 of the way up:
IF ( N_ELEMENTS(elev2show) EQ 1 ) THEN ifram=elev2show-1>0 ELSE ifram=nframes/3
print, mysweeps[*].elevationAngle
; Build the PPI image buffers
elevstr =  string(mysweeps[ifram].elevationAngle, FORMAT='(f0.1)')
prtitle = "PR for "+elevstr+" degree sweep"
myprbuf = plot_sweep_2_zbuf( zcor, mysite.site_lat, mysite.site_lon, xCorner, $
                             yCorner, pr_index, mygeometa.num_footprints, ifram, $
                             rnTypeIn, WINSIZ=windowsize, TITLE=prtitle )
gvtitle = mysite.site_ID+" at "+elevstr+" deg., "+mysweeps[ifram].atimeSweepStart
mygvbuf = plot_sweep_2_zbuf( gvz, mysite.site_lat, mysite.site_lon, xCorner, $
                             yCorner, pr_index, mygeometa.num_footprints, ifram, $
                             rnTypeIn, WINSIZ=windowsize, TITLE=gvtitle )

; Build the corresponding PR scan and ray number buffers:

; analyze the pr_index, decomposed into PR-product-relative scan and ray number
pr_scan = pr_index & pr_ray = pr_index
idx2get = WHERE( pr_index GE 0 )
; expand this PR master index into its scan,ray coordinates.  Use
;   rainFlag as the subscripted data array
pridx2get = pr_index[idx2get]
rayscan = ARRAY_INDICES( rainFlag, pridx2get )
raypr = rayscan[1,*] & scanpr = rayscan[0,*]
scanoff = MIN(scanpr)

;   pr_index uses -1 for 'bogus' PR points (out-of-range PR footprints
;   just adjacent to the first/last in-range point of the scan), or -2 for
;   off-PR-scan-edge but still-in-range points.  Negative point values will be
;   reset to zero in plot_sweep_2_zbuf_4xsec(), so we will add 3 to the analyzed
;   values and readjust when we query the resulting pixmaps.  After analysis, 
;   anything with an unadjusted ray or scan value of zero should then be outside
;   the PPI/PR overlap area.
pr_scan[idx2get] = scanpr-scanoff  ; setting scan values for 'actual' points
pr_ray[idx2get] = raypr            ; ditto for ray values
pr_scan = pr_scan+3L & pr_ray = pr_ray+3L   ; offsetting all values for analysis

idxtitle = "PR scan number"
myscanbuf = plot_sweep_2_zbuf_4xsec( pr_scan, mysite.site_lat, mysite.site_lon, $
                          xCorner, yCorner, pr_index, mygeometa.num_footprints, $
                          ifram, WINSIZ=windowsize, TITLE=idxtitle, /NOCOLOR )
idxtitle = "PR ray number"
myraybuf = plot_sweep_2_zbuf_4xsec( pr_ray, mysite.site_lat, mysite.site_lon, $
                        xCorner, yCorner, pr_index, mygeometa.num_footprints, $
                        ifram, WINSIZ=windowsize, TITLE=idxtitle, /NOCOLOR )

; Render the PPI plots - we don't actually view the scan and ray buffers anymore
SET_PLOT, 'X'
device, decomposed=0
TV, myprbuf, 0
TV, mygvbuf, 1
window, 1, xsize=xsize, ysize=ysize*2, xpos = 350, TITLE = title
Device, Copy=[0,0,xsize,ysize*2,0,0,0]


; Let the user select the cross-section locations:
print, ''
print, 'Left click on a PPI point to display a cross section of PR,'
print, 'or Right click inside PPI to select another case:'
print, ''
!Mouse.Button=1
havewin2 = 0
; copy the PPI's color table for re-loading in cursor loop when PPIs are redrawn
tvlct, rr,gg,bb,/get

imgswpsep = BYTARR(3,3)  ; for now

WHILE ( !Mouse.Button EQ 1 ) DO BEGIN
   WSet, 1
   CURSOR, xppi, yppi, /DEVICE, /DOWN
   IF ( !Mouse.Button NE 1 ) THEN BREAK
   print, "X: ", xppi, "  Y: ", yppi MOD ysize
   scanNum = myscanbuf[xppi, yppi MOD ysize]

   IF ( scanNum GT 2 ) THEN BEGIN  ; accounting for +3 offset

      IF ( havewin2 EQ 1 ) THEN BEGIN
         WDELETE, 3
         WDELETE, 5
         tvlct, rr, gg, bb
      ENDIF
      scanNumpr = scanNum + scanoff - 3L
      print, "Product-relative scan number: ", scanNumpr
      rayNum = myraybuf[xppi, yppi MOD ysize]
      rayNumpr = rayNum - 3L
      print, "PR ray number: ", rayNumpr
     ; idxcurscan should also be the sweep-by-sweep locations of all the
     ; volume-matched footprints along the scan in the geo_match datasets,
     ; which are what we need later to plot the geo-match cross sections
      idxcurscan = WHERE( pr_scan EQ scanNum )
      pr_rays_in_scan = pr_ray[idxcurscan]
      raystart = MIN( pr_rays_in_scan, idxmin, MAX=rayend, $
                      SUBSCRIPT_MAX=idxmax )
      raystartpr = raystart-3L & rayendpr = rayend-3L
      print, "ray start, end: ", raystartpr, rayendpr

     ; find the endpoints of the selected scan line on the PPI (pixmaps), and
     ; plot a line connecting the midpoints of the footprints at either end to
     ; show where the cross section will be generated
      Device, Copy=[0,0,xsize,ysize*3,0,0,0]  ; erase the prior line, if any
      idxlinebeg = WHERE( myscanbuf EQ scanNum and myraybuf EQ raystart, countbeg )
      idxlineend = WHERE( myscanbuf EQ scanNum and myraybuf EQ rayend, countend )
      startxys = ARRAY_INDICES( myscanbuf, idxlinebeg )
      endxys = ARRAY_INDICES( myscanbuf, idxlineend )
      xbeg = MEAN( startxys[0,*] ) & xend = MEAN( endxys[0,*] )
      ybeg = MEAN( startxys[1,*] ) & yend = MEAN( endxys[1,*] )
      PLOTS, [xbeg, xend], [ybeg, yend], /DEVICE, COLOR=252, THICK=2
      XYOUTS, xbeg, ybeg, 'A', /DEVICE, COLOR=252, CHARSIZE=1.5, CHARTHICK=2
      XYOUTS, xend, yend, 'B', /DEVICE, COLOR=252, CHARSIZE=1.5, CHARTHICK=2
      ybeg = ybeg+ysize & yend = yend+ysize
      PLOTS, [xbeg, xend], [ybeg, yend], /DEVICE, COLOR=252, THICK=2
      XYOUTS, xbeg, ybeg, 'A', /DEVICE, COLOR=252, CHARSIZE=1.5, CHARTHICK=2
      XYOUTS, xend, yend, 'B', /DEVICE, COLOR=252, CHARSIZE=1.5, CHARTHICK=2
;      ybeg = ybeg+ysize & yend = yend+ysize
;      PLOTS, [xbeg, xend], [ybeg, yend], /DEVICE, COLOR=252, THICK=2

     ; generate the PR and GV geo-match vertical cross sections
      plot_geo_match_xsections2, gvz, zcor, top, botm, meanbb, nframes, $
                                idxcurscan, idxmin, idxmax, imgswpsep, $
                                TITLE=caseTitle
help, imgswpsep
     ; generate the PR full-resolution vertical cross section plot
      plot_pr_xsection2, scanNumpr, raystartpr, rayendpr, dbz_2a25, meanbb, $
                        DBZSCALE2A25, imgswpsep, TITLE=caseTitle
      havewin2 = 1

   ENDIF ELSE print, "Point outside PR-PPI overlap area, choose another..."
ENDWHILE

wdelete, 1
IF ( havewin2 EQ 1 ) THEN BEGIN
   WDELETE, 3
   WDELETE, 5
ENDIF

errorExit:
end

@plot_pr_xsection.pro
@plot_geo_match_xsections.pro

;===============================================================================

FUNCTION plot_sweep_2_zbuf_4xsec, zdata, radar_lat, radar_lon, xpoly, ypoly, $
                            pr_index, nfootprints, ifram, WINSIZ=winsiz, $
                            TITLE=title, NOCOLOR=nocolor

IF N_ELEMENTS( title ) EQ 0 THEN BEGIN
  title = 'level ' + STRING(ifram+1)
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

nocolor = keyword_set(nocolor)  ; if set, don't map zdata to color ranges

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

ray = zdata[*]
inegidx = where( ray lt 0, countneg )
if countneg gt 0 then ray[inegidx] = 0.0

if keyword_set(bgwhite) then begin
    prev_background = !p.background
    !p.background = 255
endif
if !p.background eq 255 then color = 0

IF ( nocolor ) THEN BEGIN
   color_index = ray
ENDIF ELSE BEGIN
   loadcolortable, 'CZ', error
   if error then begin
       print, "error from loadcolortable"
       goto, bailout
   endif

   color_index = mapcolors(ray, 'CZ')
   if size(color_index,/n_dimensions) eq 0 then begin
       print, "error from mapcolors in PR array"
       goto, bailout
   endif
ENDELSE

for ifoot = 0, nfootprints-1 do begin
   IF ( pr_index[ifoot] LT 0 ) THEN CONTINUE
   x = xpoly[*,ifoot,ifram]
   y = ypoly[*,ifoot,ifram]
  ; Convert points to latitude and longitude coordinates.
   lon = radar_lon + meters_to_lon * x * 1000.
   lat = radar_lat + meters_to_lat * y * 1000.
   polyfill, lon, lat, color=color_index[ifoot],/data
endfor

IF ( nocolor NE 1 ) THEN BEGIN
map_grid, /label, lonlab=sb, latlab=wb, latalign=0.0,/noerase, $
    charsize=charsize, color=color
map_continents,/hires,/usa,/coasts,/countries, color=color

for range = 50.,maxrange,50. do $
    plot_range_rings2, range, radar_lon, radar_lat, color=color

rsl_colorbar, 'CZ', charsize=charsize, color=color
ENDIF

; add image labels
   xyouts, 5, ysize-15, title, CHARSIZE=charsize, COLOR=255, /DEVICE

bufout = TVRD()
bailout:

return, bufout
end

;===============================================================================

pro pr_and_geo_match_x_sections2, ELEV2SHOW=elev2show, SITE=sitefilter, $
                                  NO_PROMPT=no_prompt

pathpr='/data/netcdf/geo_match'

IF ( N_ELEMENTS(sitefilter) NE 1 ) THEN BEGIN
   print, "Defaulting to * for file pattern."
   ncfilepatt = '*'
ENDIF ELSE ncfilepatt = '*'+sitefilter+'*'

; Figure out how the next file to process will be obtained.  If no_prompt is
; set, then we will automatically loop over the file sequence.  Otherwise we
; will prompt the user for the next file with dialog_pickfile() (DEFAULT).

no_prompt = keyword_set(no_prompt)

IF (no_prompt) THEN BEGIN

   prfiles = file_search(pathpr+'/'+ncfilepatt,COUNT=nf)

   if nf eq 0 then begin
      print, 'No netCDF files matching file pattern: ', pathpr+'/'+ncfilepatt
   endif else begin
      for fnum = 0, nf-1 do begin
        ; set up for bailout prompt every 5 cases if animating PPIs w/o file prompt
         doodah = ""
         IF fnum GT 0 THEN BEGIN
            READ, doodah, $
            PROMPT='Hit Return to do next case, Q to Quit: '
         ENDIF
         IF doodah EQ 'Q' OR doodah EQ 'q' THEN break
        ;
         ncfilepr = prfiles(fnum)
         gen_pr_and_geo_match_x_sections, ncfilepr, ELEV2SHOW=elev2show
      endfor
   endelse
ENDIF ELSE BEGIN
   ncfilepr = dialog_pickfile(path=pathpr, filter = ncfilepatt)
   while ncfilepr ne '' do begin
      gen_pr_and_geo_match_x_sections, ncfilepr, ELEV2SHOW=elev2show
      ncfilepr = dialog_pickfile(path=pathpr, filter = ncfilepatt)
   endwhile
ENDELSE

print, "" & print, "Done!"
END
