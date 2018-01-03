;===============================================================================
;+
; Copyright © 2009, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; pr_and_geo_match_x_sects_w_check.pro    Morris/SAIC/GPM_GV    April 2009
;
; DESCRIPTION
; -----------
; Driver for gen_pr_and_geo_match_x_sects_w_check.  Sets up user/default
; parameters defining the displayed PPIs, and the method by which the next
; case is selected: either prompt the user to select the file, or just take the
; next one in the sequence.
;
; PARAMETERS
; ----------
; elevs2show   - sweep number of PPIs to display, starting from 1 as the
;                lowest elevation angle in the volume.  Defaults to approximately
;                1/3 the way up the list of sweeps if unspecified
;
; ncpath       - local directory path to the geo_match netCDF files' location.
;                Defaults to /data/netcdf/geo_match
;
; sitefilter   - file pattern which acts as the filter limiting the set of input
;                files shown in the file selector, or over which the program
;                will iterate. Mode of selecting the (next) file depends on the
;                no_prompt parameter. Default=*
;
; no_prompt    - method by which the next file in the set of files defined by
;                ncpath and sitefilter is selected. Binary parameter. If unset,
;                defaults to DialogPickfile (pop-up file selector)
;
; no_2a25      - Binary parameter.  If set, then the full-vertical-resolution PR
;                cross sections from the 2A-25 data will NOT be plotted.  This
;                means the program can be run using only the geo_match netCDF
;                data files.
;
; INTERNAL MODULES
; ----------------
; 1) pr_and_geo_match_x_sects_w_check - Main driver procedure called by user.
;
; 2) gen_pr_and_geo_match_x_sects_w_check - Workhorse procedure to read data,
;                                      create plots, and allow interactive
;                                      selection of cross section locations on
;                                      the PR or GV PPI plots displayed.
;
; 3) plot_sweep_2_zbuf_4xsec - Generates a pseudo-PPI of scan and ray number to
;                              allow determination of cross section location
;                              in terms of the original 2A-25 array coordinates.
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;===============================================================================

; MODULE #3

FUNCTION plot_sweep_2_zbuf_4xsec, zdata, radar_lat, radar_lon, xpoly, ypoly, $
                            pr_index, nfootprints, ifram, WINSIZ=winsiz, $
                            TITLE=title, NOCOLOR=nocolor

; DESCRIPTION
; -----------
; Generates a pseudo-PPI of scan and ray number to allow determination of cross
; section location in terms of the original 2A-25 array coordinates.


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

; add a "hot corner" to the images to click on to initiate alignment check
bufout[0:20,0:20] = 254B
bailout:

return, bufout
end

;===============================================================================

; MODULE #2

pro gen_pr_and_geo_match_x_sects_w_check, ncfilepr, use_db, no_2a25, $
                                 ELEV2SHOW=elev2show, PR_ROOT_PATH=pr_root_path
;
;
; DESCRIPTION
; -----------
; Called from pr_and_geo_match_x_sects_w_check procedure (included in this file).
; Reads PR and GV reflectivity and spatial fields from a user-selected geo_match
; netCDF file, and builds a PPI of the data for a given elevation sweep.  Then
; allows a user to select a point on the image for which vertical cross
; sections along the PR scan line through the selected point will be plotted, 
; from volume-matched PR and GV data, and if no_2a25 is 0, also plots cross
; sections of full-resolution PR data.
;
; Also plots a 'hot corner' in the lower left corner of the PPI images.  When
; the user clicks in this hot corner, an animation sequence of volume-matched
; PR and GV data and full-resolution GV data from the original radar UF file
; is generated, and permits the user to assess the quality of the geo-alignment
; between the PR and GV data.
;

COMMON sample, start_sample, sample_range, num_range, RAYSPERSCAN

; "Include" file for PR-product-specific parameters (i.e., RAYSPERSCAN):
@pr_params.inc
; "Include" file for names, default paths, etc.:
@environs.inc
; "Include file for netCDF-read structs
@geo_match_nc_structs.inc

; Override default path to PR product files if specified in PR_ROOT_PATH
IF ( N_ELEMENTS( pr_root_path ) EQ 1 ) THEN BEGIN
   print, 'Overriding default path to PR files: ', PRDATA_ROOT, ', to: ', $
          pr_root_path
   PRDATA_ROOT = pr_root_path
ENDIF

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

; -- parse ncfile1 to get the component fields: site, orbit number, YYMMDD
dataPR = FILE_BASENAME(ncfilepr)
parsed=STRSPLIT( dataPR, '.', /extract )
orbit = parsed[3]
DATESTAMP = parsed[2]      ; in YYMMDD format
ncsite = parsed[1]
print, dataPR, " ", orbit, " ", DATESTAMP, " ", ncsite
; put together a title field for the cross-sections
caseTitle = ncsite+' overpass case, day='+DATESTAMP+', Orbit='+orbit

; Query the database for the PR filenames for this orbit/subset, if plotting
; full-resolution PR data cross sections:
IF ( no_2a25 NE 1 ) THEN BEGIN
   prfiles4 = ''
   status = find_pr_products(dataPR, PRDATA_ROOT, prfiles4, USE_DB=use_db)
   print, prfiles4
   parsepr = STRSPLIT( prfiles4, '|', /extract )
   file_1c21 = STRTRIM( parsepr[0], 2 )
   file_2a25 = STRTRIM( parsepr[1], 2 )
   file_2b31 = STRTRIM( parsepr[2], 2 )
   IF ( status NE 0 AND file_2a25 EQ 'no_2A25_file' ) THEN BEGIN
      PRINT, ""
      PRINT, "ERROR finding 2A-25 product file."
      PRINT, "Skipping events for orbit = ", orbit
      PRINT, ""
      GOTO, errorExit
   ENDIF

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
ENDIF
; Set up the pixmap window for the PPI plots
windowsize = 350
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

; Build the 'true' PPI image buffers
elevstr =  string(mysweeps[ifram].elevationAngle, FORMAT='(f0.1)')
prtitle = "PR for "+elevstr+" degree sweep"
myprbuf = plot_sweep_2_zbuf( zcor, mysite.site_lat, mysite.site_lon, xCorner, $
                             yCorner, pr_index, mygeometa.num_footprints, ifram, $
                             rnTypeIn, WINSIZ=windowsize, TITLE=prtitle )
gvtitle = mysite.site_ID+" at "+elevstr+" deg., "+mysweeps[ifram].atimeSweepStart
mygvbuf = plot_sweep_2_zbuf( gvz, mysite.site_lat, mysite.site_lon, xCorner, $
                             yCorner, pr_index, mygeometa.num_footprints, ifram, $
                             rnTypeIn, WINSIZ=windowsize, TITLE=gvtitle )

; add a "hot corner" to the images to click on to initiate alignment check
myprbuf[0:20,0:20] = 254B
mygvbuf[0:20,0:20] = 254B

; Build the corresponding PR scan and ray number buffers (not displayed):
pr_scan = pr_index & pr_ray = pr_index
idx2get = WHERE( pr_index GE 0 )
pridx2get = pr_index[idx2get]

; analyze the pr_index, decomposed into PR-product-relative scan and ray number
IF ( no_2a25 EQ 0 ) THEN BEGIN
  ; expand this subset of PR master indices into its scan,ray coordinates.  Use
  ;   rainFlag as the subscripted data array
   rayscan = ARRAY_INDICES( rainFlag, pridx2get )
   raypr = rayscan[1,*] & scanpr = rayscan[0,*]
ENDIF ELSE BEGIN
  ; derive the original number of scans in the file using the 'step' between
  ;   rays of the same scan - this works, but is a bit of trickery
   ngoodpr = n_elements(pridx2get)
   sample_range = MIN(ABS(pridx2get[0:ngoodpr-2]-pridx2get[1:ngoodpr-1]))
  ; expand this subset of PR master indices into its scan,ray coordinates.
   raypr = pridx2get/sample_range
   scanpr = pridx2get MOD sample_range
ENDELSE

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

; add a "hot corner" matching the images, to return special value to initiate
; "data alignment check" PPI animation loop
myscanbuf[0:20,0:20] = 254B
myraybuf[0:20,0:20] = 254B

; Render the PPI plots - we don't actually view the scan and ray buffers anymore
SET_PLOT, 'X'
device, decomposed=0
TV, myprbuf, 0
TV, mygvbuf, 1
window, 1, xsize=xsize, ysize=ysize*2, xpos = 350, ypos=50, TITLE = title
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

; load compressed color table 33 into LUT values 128-255
loadct, 33
tvlct, rrhi, gghi, bbhi, /get
FOR j = 1,127 DO BEGIN
   rr[j+128] = rrhi[j*2]
   gg[j+128] = gghi[j*2]
   bb[j+128] = bbhi[j*2]
ENDFOR
; -- set values 122-127 as white, for labels and such
rr[122:127] = 255
gg[122:127] = 255
bb[122:127] = 255
tvlct, rr,gg,bb

WHILE ( !Mouse.Button EQ 1 ) DO BEGIN
   WSet, 1
   CURSOR, xppi, yppi, /DEVICE, /DOWN
   IF ( !Mouse.Button NE 1 ) THEN BREAK
   print, "X: ", xppi, "  Y: ", yppi MOD ysize
   scanNum = myscanbuf[xppi, yppi MOD ysize]

   IF ( scanNum GT 2 AND scanNum NE 254B ) THEN BEGIN  ; accounting for +3 offset

      IF ( havewin2 EQ 1 ) THEN BEGIN
         IF ( no_2a25 NE 1 ) THEN WDELETE, 3
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
      PLOTS, [xbeg, xend], [ybeg, yend], /DEVICE, COLOR=122, THICK=2
      XYOUTS, xbeg, ybeg, 'A', /DEVICE, COLOR=122, CHARSIZE=1.5, CHARTHICK=2
      XYOUTS, xend, yend, 'B', /DEVICE, COLOR=122, CHARSIZE=1.5, CHARTHICK=2
      ybeg = ybeg+ysize & yend = yend+ysize
      PLOTS, [xbeg, xend], [ybeg, yend], /DEVICE, COLOR=122, THICK=2
      XYOUTS, xbeg, ybeg, 'A', /DEVICE, COLOR=122, CHARSIZE=1.5, CHARTHICK=2
      XYOUTS, xend, yend, 'B', /DEVICE, COLOR=122, CHARSIZE=1.5, CHARTHICK=2
;      ybeg = ybeg+ysize & yend = yend+ysize
;      PLOTS, [xbeg, xend], [ybeg, yend], /DEVICE, COLOR=252, THICK=2

      IF ( no_2a25 NE 1 ) THEN BEGIN
        ; generate the PR full-resolution vertical cross section plot
         plot_pr_xsection, scanNumpr, raystartpr, rayendpr, dbz_2a25, meanbb, $
                           DBZSCALE2A25, TITLE=caseTitle
      ENDIF

     ; generate the PR and GV geo-match vertical cross sections
      plot_geo_match_xsections, gvz, zcor, top, botm, meanbb, nframes, $
                                idxcurscan, idxmin, idxmax, TITLE=caseTitle

      havewin2 = 1  ; need to delete x-sect windows at end

      print, ''
      print, "Select another cross-section location in the image,"
      print, "or Left click on the white square at the lower right to view"
      print, "an animation loop of volume-match and full-resolution PR and GV data,"
      print, 'or Right click inside PPI to select another case:'
   ENDIF ELSE BEGIN
      IF ( scanNum EQ 254B ) THEN $
         status = do_check_plots(ncfilepr, '/data/gv_radar/finalQC_in', 3, ifram) $
      ELSE print, "Point outside PR-PPI overlap area, choose another..."
   ENDELSE
ENDWHILE

wdelete, 1
IF ( havewin2 EQ 1 ) THEN BEGIN
   IF ( no_2a25 NE 1 ) THEN WDELETE, 3
   WDELETE, 5
ENDIF

errorExit:
end

@plot_pr_xsection.pro
@plot_geo_match_xsections.pro

;===============================================================================

; MODULE #1

pro pr_and_geo_match_x_sects_w_check, ELEV2SHOW=elev2show, SITE=sitefilter, $
                                 NO_PROMPT=no_prompt, NCPATH=ncpath,   $
                                 PRPATH=prpath, USE_DB=use_db, NO_2A25=no_2a25

print, ""

IF ( N_ELEMENTS(ncpath) NE 1 ) THEN BEGIN
   print, "Defaulting to /data/netcdf/geo_match for netCDF file path."
   print, ""
   pathgeo = '/data/netcdf/geo_match'
ENDIF ELSE pathgeo = ncpath

IF ( N_ELEMENTS(sitefilter) NE 1 ) THEN BEGIN
   print, "Defaulting to * for file pattern."
   print, ""
   ncfilepatt = '*'
ENDIF ELSE ncfilepatt = '*'+sitefilter+'*'

; Set use_db flag, default is to not use a Postgresql database query to obtain
; the PR 2A25 product filename matching the geo-match netCDF file for each case.
use_db = KEYWORD_SET( use_db )

; Set the no_2a25 flag.  Default is to look for original PR 2A-25 product file
; and plot cross section of full-res PR data.  If set, then plot only geo-match
; cross section data from the netCDF files.
no_2a25 = KEYWORD_SET( no_2a25 )

IF ( N_ELEMENTS(prpath) NE 1 ) THEN BEGIN
   print, "Using default for PR product file path."
   IF ( use_db NE 1 ) THEN $
      print, "PR 2A-25 files may not be found if this location is incorrect."
   print, ""
ENDIF ELSE BEGIN
   pathpr = prpath
ENDELSE

; Figure out how the next file to process will be obtained.  If no_prompt is
; set, then we will automatically loop over the file sequence.  Otherwise we
; will prompt the user for the next file with dialog_pickfile() (DEFAULT).

no_prompt = keyword_set(no_prompt)

IF (no_prompt) THEN BEGIN

   prfiles = file_search(pathgeo+'/'+ncfilepatt,COUNT=nf)

   if nf eq 0 then begin
      print, 'No netCDF files matching file pattern: ', pathgeo+'/'+ncfilepatt
   endif else begin
      for fnum = 0, nf-1 do begin
        ; set up for bailout prompt every 5 cases if animating PPIs w/o file prompt
         doodah = ""
         IF fnum GT 0 THEN BEGIN
            PRINT, ''
            READ, doodah, $
            PROMPT='Hit Return to do next case, Q to Quit: '
         ENDIF
         IF doodah EQ 'Q' OR doodah EQ 'q' THEN break
        ;
         ncfilepr = prfiles(fnum)
         gen_pr_and_geo_match_x_sects_w_check, ncfilepr, use_db, no_2a25, $
                                      ELEV2SHOW=elev2show, PR_ROOT_PATH=pathpr
      endfor
   endelse
ENDIF ELSE BEGIN
   ncfilepr = dialog_pickfile(path=pathgeo, filter = ncfilepatt)
   while ncfilepr ne '' do begin
      gen_pr_and_geo_match_x_sects_w_check, ncfilepr, use_db, no_2a25, $
                                   ELEV2SHOW=elev2show, PR_ROOT_PATH=pathpr
      ncfilepr = dialog_pickfile(path=pathgeo, filter = ncfilepatt)
   endwhile
ENDELSE

print, "" & print, "Done!"
END
