;===============================================================================
;+
; Copyright © 2009, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; pr_and_geo_match_x_sections.pro    Morris/SAIC/GPM_GV    March 2009
;
; DESCRIPTION
; -----------
; Driver for gen_pr_and_geo_match_x_sections (included).  Sets up user/default
; parameters defining the displayed PPIs, and the method by which the next
; case is selected: either prompt the user to select the file, or just take the
; next one in the sequence.
;
; PARAMETERS
; ----------
; elev2show    - sweep number of PPIs to display, starting from 1 as the
;                lowest elevation angle in the volume.  Defaults to approximately
;                1/3 the way up the list of sweeps if unspecified
;
; ncpath       - local directory path to the geo_match netCDF files' location.
;                Defaults to /data/netcdf/geo_match
;
; prpath       - local directory path to the original PR product files root
;                (in-common) directory.  Defaults to /data/prsubsets
;
; ufpath       - local directory path to the original GV radar UF file root
;                (in-common) directory.  Defaults to /data/gv_radar/finalQC_in
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
; use_db       - Binary parameter.  If set, then query the 'gpmgv' database to
;                find the PR 2A-25 product file that corresponds to the
;                geo_match netCDF file being rendered.  Otherwise, generate
;                a 'guess' of the filename pattern and search under the
;                directory prpath/2A25 (default mode)
;
; pctAbvThresh - constraint on the percent of bins in the geometric-matching
;                volume that were above their respective thresholds, specified
;                at the time the geo-match dataset was created.  Essentially a
;                measure of "beam-filling goodness".  100 means use only those
;                matchup points where all the PR and GV bins in the volume
;                averages were above threshold (complete volume filled with
;                above threshold bin values).  0 means use all matchup points
;                available, with no regard for thresholds (the default, if no
;                pctAbvThresh value is specified)
;
; INTERNAL MODULES
; ----------------
; 1) pr_and_geo_match_x_sections - Main driver procedure called by user.
;
; 2) gen_pr_and_geo_match_x_sections - Workhorse procedure to read data,
;                                      create plots, and allow interactive
;                                      selection of cross section locations on
;                                      the PR or GV PPI plots displayed.
;
; 3) plot_sweep_2_zbuf_4xsec - Generates a pseudo-PPI of scan and ray number to
;                              allow determination of cross section location
;                              in terms of the original 2A-25 array coordinates.
;
; 4) gv_z_s2ku_4xsec - Applies S-band to Ku-band adjustment to the copy of GV
;                      reflectivity to be rendered in current x-section.
;
; HISTORY
; -------
; 07/06/09 Morris, GPM GV, SAIC
; - Fixed handling of color table within interactive cursor loop in module
;   gen_pr_and_geo_match_x_sections.  Removed 'hot corners' from PR PPI.
; 07/09/09 Morris, GPM GV, SAIC
; - Added annotations to cross sections to indicate PctAbvThresh value and
;   GV calibration offset.  Added GVOFF keyword parameter for call to external
;   procedure 'plot_geo_match_xsections'.
; 07/20/09 Morris, GPM GV, SAIC
; - Changed call to rsl_colorbar to a call to vn_colorbar to fix error in color
;   bar labeling.
; 07/23/09 Morris, GPM GV, SAIC
; - Added capability to do S-to-Ku frequency adjustment to GV reflectivity.
;   Includes addition of new internal module, gv_z_s2ku_4xsec.
; 08/04/09 Morris, GPM GV, SAIC
; - Re-init color table before each call to plot_geo_match_xsections, now that
;   image count 128 has a conflicting redefinition in plot_pr_xsection.pro.
; 11/04/09 Morris, GPM GV, SAIC
; - Added output of 2A-25 Path-Integrated Attenuation (PIA) and ray locations
;   along x-section.  Enhanced pattern/title for manual file selections that
;   use DIALOG_PICKFILE in module 1.
; 11/13/09  Morris/GPM GV/SAIC
; -  Added parameter/value GET_ONLY='2A25' to call to find_pr_products() in
;    gen_pr_and_geo_match_x_sections to look for only the 2A25 product type
; 04/12/10  Morris/GPM GV/SAIC
; - Modified PPI pixmap/buffer code to plot over the maximum range of the data
;   as indicated in the netCDF file, rather than a fixed 125 km cutoff.
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;===============================================================================

; MODULE #4

PRO gv_z_s2ku_4xsec, gvz, bbprox, idx2adj

; DESCRIPTION
; -----------
; Applies S-to-Ku frequency adjustment to GV reflectivity field 'gvz', according
; to proximity to Bright Band as defined in 'bbprox'.  Only modify the subset
; of points defined by array indices in 'idx2adj'.

; get the points with valid dBZs -- likewise, clip BB proximity array
 gvz2adj = gvz[idx2adj]
 bbprox4xsec = bbProx[idx2adj]

; grab the above and below BB points, respectively
 idxsnow4xsec = where( bbprox4xsec EQ 3, snocount )
 idxrain4xsec = where( bbprox4xsec EQ 1, rncount )

; adjust S-band reflectivity for above and below BB
 if snocount GT 0 then begin
  ; grab the above-bb points of the GV reflectivity
    gvz4snow = gvz2adj[idxsnow4xsec]
  ; perform the conversion and replace the original values
    gvz2adj[idxsnow4xsec] = s_band_to_ku_band( gvz4snow, 'S' )
 endif
 if rncount GT 0 then begin   ; adjust the below-BB points
    gvz4rain = gvz2adj[idxrain4xsec]
    gvz2adj[idxrain4xsec] = s_band_to_ku_band( gvz4rain, 'R' )
 endif

; copy back the rain/snow adjusted values
 gvz[idx2adj] = gvz2adj

end

;===============================================================================

; MODULE #3

FUNCTION plot_sweep_2_zbuf_4xsec, zdata, radar_lat, radar_lon, xpoly, ypoly, $
                            pr_index, nfootprints, ifram, MAXRNGKM=maxrngkm, $
                            WINSIZ=winsiz, NOCOLOR=nocolor, TITLE=title

; DESCRIPTION
; -----------
; Generates a pseudo-PPI of scan and ray number to allow determination of cross
; section location in terms of the original 2A-25 array coordinates.


;IF N_ELEMENTS( title ) EQ 0 THEN BEGIN
;  title = 'level ' + STRING(ifram+1)
;ENDIF
;print, title

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

IF N_ELEMENTS( maxrngkm ) EQ 1 THEN maxrange = ( FIX(maxrngkm) / 25 + 1 ) * 25.0 $
ELSE maxrange = 125. ; kilometers


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

vn_colorbar, 'CZ', charsize=charsize, color=color
ENDIF

; add image labels
;   xyouts, 5, ysize-15, title, CHARSIZE=charsize, COLOR=255, /DEVICE

bufout = TVRD()

; add a "hot corner" to the images to click on to initiate alignment check
bufout[0:20,0:20] = 254B
bailout:

return, bufout
end

;===============================================================================

; MODULE #2

pro gen_pr_and_geo_match_x_sections, ncfilepr, use_db, no_2a25, $
                  ELEV2SHOW=elev2show, PCT_ABV_THRESH=pctAbvThresh, $
                  PR_ROOT_PATH=pr_root_path, UFPATH=ufpath
;
;
; DESCRIPTION
; -----------
; Called from pr_and_geo_match_x_sections procedure (included in this file).
; Reads PR and GV reflectivity and spatial fields from a user-selected geo_match
; netCDF file, and builds a PPI of the data for a given elevation sweep.  Then
; allows a user to select a point on the image for which vertical cross
; sections along the PR scan line through the selected point will be plotted 
; from volume-matched PR and GV data, and if no_2a25 is 0, also plots cross
; sections of full-resolution PR data.
;
; Plots two labeled "hot corners" in the upper right of the GV PPI image.  When
; the user clicks in one of these hot corners and a cross section is already on
; the display, the GV geo-match reflectivity data is incremented or decremented
; by the labeled amount and the geo-match cross section and difference cross
; section are redrawn with the reflectivity offset applied to the GV data.  This
; offset remains in place as long as the current case is being displayed, and
; resets to zero when a new case is selected. 
;
; Also plots a 'hot corner' in the lower left corner of the GV PPI image.  When
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
  gvexp=intarr(nfp,nswp)
  gvrej=intarr(nfp,nswp)
  prexp=intarr(nfp,nswp)
  zrawrej=intarr(nfp,nswp)
  zcorrej=intarr(nfp,nswp)
  rainrej=intarr(nfp,nswp)

  status = read_geo_match_netcdf( ncfile1,  dbzgv=gvz, dbzcor=zcor, $
               gvexpect_int=gvexp, gvreject_int=gvrej, prexpect_int=prexp, $
               zrawreject_int=zrawrej, zcorreject_int=zcorrej, $
               rainreject_int=rainrej, dbzraw=zraw, xCorners=xCorner, $
               yCorners=yCorner, topHeight=top,  bottomHeight=botm, bbhgt=BB, $
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

; Reclassify rain types down to simple categories 1 (Stratiform), 2 (Convective),
;  or 3 (Other), where defined
idxrnpos = where(rntype ge 0, countrntype)
if (countrntype GT 0 ) then rntype[idxrnpos] = rntype[idxrnpos]/100

; convert bright band heights from m to km, where defined, and get mean BB hgt
BB = BB[idxpractual]
idxbbdef = where(bb GT 0.0 AND rntype[idxpractual] EQ 1, countBB)
if ( countBB GT 0 ) THEN BEGIN
;   meanbb_m = FIX(MEAN(bb[idxbbdef]))  ; in meters
;   meanbb = meanbb_m/1000.        ; in km
   bb2hist = bb[idxbbdef]/1000.  ; in km
   bs=0.2
   bbhist = HISTOGRAM(bb2hist, binsize=bs, locations=bbhiststart, reverse_indices=R)
   window,9,retain=2
   plot, [0.0,MAX(bbhiststart)>6.0],[0,FIX(MAX(bbhist))], $
                  /NODATA, COLOR = 255
   oplot, bbhiststart + bs/2.0, bbhist, COLOR = 255
   nbbmaxes=0
   nbbmaxesz=0
   IF N_ELEMENTS(bbhist) GT 2 THEN BEGIN
      idxbbmaxes = lclxtrem( bbhist, 2, /MAXIMA, COUNT=nbbmaxes, /POINT_ORDER )
      idxbbmaxsiz = lclxtrem( bbhist, 2, /MAXIMA, COUNT=nbbmaxesz )
      print, "Num. BB Maxima: ", nbbmaxes
      print, "BB maxima: ", bbhiststart[idxbbmaxes] + bs/2.
      i = idxbbmaxes[0]  ; histo bin of 1st maxima
      BBbin = bb2hist[ R[ R[i] : R[i+1]-1 ] ]
      print, "BB values in max bin 1: ", BBbin
      IF ( bbhist[idxbbmaxsiz[0]] / bbhist[idxbbmaxes[0]] LT 30. ) THEN BEGIN
         ; take the first peak in ascending height order as the mean BB height
          meanbb = MEAN(BBbin)
      ENDIF ELSE BEGIN
        ; look at the next maximum in data order, if any
         IF ( nbbmaxes GT 1 ) THEN BEGIN
            FOR imax = 1, nbbmaxes-1 DO BEGIN
               IF ( bbhist[idxbbmaxsiz[0]] / bbhist[idxbbmaxes[imax]] LT 30. ) THEN BEGIN
                  i = idxbbmaxes[imax]  ; histo bin of 1st maxima
                  BBbin = bb2hist[ R[ R[i] : R[i+1]-1 ] ]
                  print, "BB values in max bin ",imax+1,": ", BBbin
                  IF ( bbhist[idxbbmaxsiz[0]] / bbhist[idxbbmaxes[imax]] LT 30. ) THEN BEGIN
                     ; take the next peak in ascending height order as the mean BB height
                      meanbb = MEAN(BBbin)
                      break
                  ENDIF                  
               ENDIF
            ENDFOR
         ENDIF ELSE meanbb = MEAN(bb2hist)
      ENDELSE
      xyouts, meanbb, bbhist[idxbbmaxes[0]], '*', size=3
;      xyouts, bbhiststart[idxbbmaxes[0]], bbhist[idxbbmaxes[0]], '*', size=3
;      xyouts, MEAN(bb2hist), bbhist[idxbbmaxes[0]], '+', size=3
   ENDIF ELSE BEGIN
      print, "Too few points for Maxima routine: ", N_ELEMENTS(bbhist)
      meanbb = MEAN(bb2hist)
   ENDELSE
   print, 'Mean BB (km): ', meanbb
ENDIF ELSE BEGIN
   print, "No valid bright band heights, quitting case."
   goto, errorExit
ENDELSE

; build an array of proximity to the bright band: above (=3), within (=2), below (=1)
; -- define above (below) BB as bottom (top) of beam at least 500m above
;    (750m below) mean BB height

num_in_BB_Cat = LONARR(4)
bbProx = prexp
bbProx[*] = 0  ; re-init to Not Defined
idxabv = WHERE( botm GT (meanbb+0.500), countabv )
num_in_BB_Cat[3] = countabv
IF countabv GT 0 THEN bbProx[idxabv] = 3
idxblo = WHERE( top LT (meanbb-0.750), countblo )
num_in_BB_Cat[1] = countblo
IF countblo GT 0 THEN bbProx[idxblo] = 1
idxin = WHERE( (botm LE (meanbb+0.500)) AND (top GE (meanbb-0.750)), countin )
num_in_BB_Cat[2] = countin
IF countin GT 0 THEN bbProx[idxin] = 2

nframes = mygeometa.num_sweeps

;-------------------------------------------------

; PREPARE FIELDS NEEDED FOR PPI PLOTS AND GEO_MATCH CROSS SECTIONS:

; Now do the sweep-level arrays - have to build an array index of actual
; points over all the sweep levels
idx3d=long(gvexp)   ; take one of the 2D arrays, make it LONG type
idx3d[*,*] = 0L     ; initialize all points to 0
idx3d[idxpractual,0] = 1L      ; set the first sweep to 1 where non-bogus

; copy the first sweep to the other levels, and make the single-level arrays
; for categorical fields the same dimension as the sweep-level
rnTypeIn = rnType
IF ( nframes GT 1 ) THEN BEGIN  
   FOR iswp=1, nframes-1 DO BEGIN
      idx3d[*,iswp] = idx3d[*,0]
      rnType = [rnType, rnTypeIn]  ; concatenate another level's worth
   ENDFOR
ENDIF

; get the indices of all the non-bogus points in the 2D arrays
idxpractual2d = where( idx3d EQ 1L, countactual2d )
if (countactual2d EQ 0) then begin
  ; this shouldn't be able to happen
   print, "No non-bogus 2D data points, quitting case."
   goto, errorExit
endif

; blank out reflectivity for samples not meeting 'percent complete' threshold

IF ( pctAbvThresh GT 0.0 ) THEN BEGIN
   IF ( pctAbvThresh EQ 100.0 ) THEN BEGIN
    ; clip to the 'good' points, where ALL bins in average were above threshold
      idxallgood = WHERE( prexp GT 0 AND gvrej EQ 0 AND zcorrej EQ 0, countgood )
      if ( countgood GT 0 ) THEN BEGIN
         idx2plot=idxallgood
         n2plot=countgood
      endif ELSE BEGIN
         print, "No complete-volume points, quitting case."
         goto, errorExit
      endelse
   ENDIF ELSE BEGIN
    ; clip to the 'good' points, where 'pctAbvThresh' fraction of bins in average
    ; were above threshold
      idxexpgt0 = WHERE( prexp GT 0 AND gvexp GT 0, countexpgt0 )
      IF ( countexpgt0 EQ 0 ) THEN BEGIN
         print, "No valid volume-average points, quitting case."
         goto, errorExit
      ENDIF ELSE BEGIN
         pctgoodpr = 100.0 * FLOAT( prexp[idxexpgt0] - zcorrej[idxexpgt0] ) / prexp[idxexpgt0]
         pctgoodgv = 100.0 * FLOAT( gvexp[idxexpgt0] - gvrej[idxexpgt0] ) / gvexp[idxexpgt0]
         idxgoodpct = WHERE( pctgoodpr GE pctAbvThresh $
                        AND  pctgoodgv GE pctAbvThresh, countgoodpct )
         IF ( countgoodpct GT 0 ) THEN BEGIN
            idxgoodenuff = idxexpgt0[idxgoodpct]
            idx2plot=idxgoodenuff
            n2plot=countgoodpct
         ENDIF ELSE BEGIN
            print, "No complete-volume points, quitting case."
            goto, errorExit
         ENDELSE
      ENDELSE
   ENDELSE
  ; blank out reflectivity for all samples not meeting completeness thresholds
   idx3d[*,*] = 0L     ; initialize all points to 0
   idx3d[idx2plot] = 2L
   idx2blank = WHERE( idx3d EQ 0L, count2blank )
   IF ( count2blank GT 0 ) THEN BEGIN
     gvz[idx2blank] = 0.0
     zcor[idx2blank] = 0.0
   ENDIF
ENDIF

; get the indices of all remaining 'valid' GV points, so that we can
; do the interactive calibration adjustment on these only
idx2adj = WHERE( gvz GT 0.0 )

;-------------------------------------------------

; Determine the pathnames of the PR product files:

; -- parse ncfile1 to get the component fields: site, orbit number, YYMMDD
dataPR = FILE_BASENAME(ncfilepr)
parsed=STRSPLIT( dataPR, '.', /extract )
orbit = parsed[3]
DATESTAMP = parsed[2]      ; in YYMMDD format
ncsite = parsed[1]
print, dataPR, " ", orbit, " ", DATESTAMP, " ", ncsite
; put together a title field for the cross-sections
caseTitle25 = ncsite+'/'+DATESTAMP+', Orbit '+orbit
IF ( pctAbvThresh EQ 0.0 ) THEN BEGIN
   caseTitle = caseTitle25+", All Points"
ENDIF ELSE BEGIN
   caseTitle = caseTitle25+", "+STRING(pctAbvThresh,FORMAT='(i0)')+"% bins > Threshold"
ENDELSE

; Query the database for the PR filenames for this orbit/subset, if plotting
; full-resolution PR data cross sections:

IF ( no_2a25 NE 1 ) THEN BEGIN
   prfiles4 = ''
   status = find_pr_products(dataPR, PRDATA_ROOT, prfiles4, USE_DB=use_db, $
                             GET_ONLY='2A25')
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
   pia=FLTARR(3,RAYSPERSCAN,sample_range>1)

   status = read_pr_2a25_fields( file_2a25, DBZ=dbz_2a25, RAIN=rain_2a25,   $
                                 TYPE=rainType, SURFACE_RAIN=surfRain_2a25, $
                                 GEOL=geolocation, RANGE_BIN=rangeBinNums,  $
                                 RN_FLAG=rainFlag, PIA=pia )
   IF ( status NE 0 ) THEN BEGIN
      PRINT, ""
      PRINT, "ERROR reading fields from ", file_2a25
      PRINT, "Skipping events for orbit = ", orbit
      PRINT, ""
      GOTO, errorExit
   ENDIF
ENDIF

;-------------------------------------------------

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
                             rnTypeIn, WINSIZ=windowsize, TITLE=prtitle, $
                             MAXRNGKM=mygeometa.rangeThreshold )
gvtitle = mysite.site_ID+" at "+elevstr+" deg., "+mysweeps[ifram].atimeSweepStart
mygvbuf = plot_sweep_2_zbuf( gvz, mysite.site_lat, mysite.site_lon, xCorner, $
                             yCorner, pr_index, mygeometa.num_footprints, ifram, $
                             rnTypeIn, WINSIZ=windowsize, TITLE=gvtitle, $
                             MAXRNGKM=mygeometa.rangeThreshold )

; add a "hot corner" to the GV image to click on to initiate alignment check
;myprbuf[0:20,0:20] = 254B
mygvbuf[0:20,0:20] = 254B
; add a hot corner to subtract 1 dBZ from GV and re-run x-sect differences
;myprbuf[windowsize-41:windowsize-22,windowsize-20:windowsize-1] = 253B
mygvbuf[windowsize-41:windowsize-22,windowsize-20:windowsize-1] = 253B
; add a hot corner to add 1 dBZ to GV and re-run x-sect differences
;myprbuf[windowsize-20:windowsize-1,windowsize-20:windowsize-1] = 252B
mygvbuf[windowsize-20:windowsize-1,windowsize-20:windowsize-1] = 252B
; add a hot corner to toggle between original and Ku-adjusted GV reflectivity
mygvbuf[windowsize-62:windowsize-43,windowsize-20:windowsize-1] = 251B


; Build the corresponding PR scan and ray number buffers (not displayed):
pr_scan = pr_index & pr_ray = pr_index
idx2get = WHERE( pr_index GE 0 )
pridx2get = pr_index[idx2get]

; analyze the pr_index, decomposed into PR-product-relative scan and ray number
IF ( no_2a25 EQ 0 ) THEN BEGIN
  ; expand this subset of PR master indices into its scan,ray coordinates.  Use
  ;   rainFlag as the subscripted data array
;   print, 'using ARRAY_INDICES( rainFlag )'
   rayscan = ARRAY_INDICES( rainFlag, pridx2get )
   raypr = rayscan[1,*] & scanpr = rayscan[0,*]
ENDIF ELSE BEGIN
  ; derive the original number of scans in the file using the 'step' between
  ;   rays of the same scan - this **USUALLY** works, but is a bit of trickery
   print, ''
   print, 'Using trickery to derive scan and ray numbers, this may fail...'
   print, ''
  ; find the statistical mode of the pridx change from one point to the next
  ; -- this should be equal to the value of sample_range used to determine the
  ;    original pr_master_index values
  ; the following algorithm is documented at http://www.dfanning.com/code_tips/mode.html
   ngoodpr = n_elements(pridx2get)
   array= (ABS(pridx2get[0:ngoodpr-2]-pridx2get[1:ngoodpr-1]))
   array = array[Sort(array)]
   wh = where(array ne Shift(array,-1), cnt)
   if cnt eq 0 then mode = array[0] else begin
      void = Max(wh-[-1,wh], mxpos)
      mode = array[wh[mxpos]]
   endelse
   sample_range = mode
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

;idxtitle = "PR scan number"
myscanbuf = plot_sweep_2_zbuf_4xsec( pr_scan, mysite.site_lat, mysite.site_lon, $
                          xCorner, yCorner, pr_index, mygeometa.num_footprints, $
                          ifram, WINSIZ=windowsize, TITLE=idxtitle, /NOCOLOR, $
                          MAXRNGKM=mygeometa.rangeThreshold )
;idxtitle = "PR ray number"
myraybuf = plot_sweep_2_zbuf_4xsec( pr_ray, mysite.site_lat, mysite.site_lon, $
                        xCorner, yCorner, pr_index, mygeometa.num_footprints, $
                        ifram, WINSIZ=windowsize, TITLE=idxtitle, /NOCOLOR, $
                        MAXRNGKM=mygeometa.rangeThreshold )

; add a "hot corner" matching the GV PPI image, to return special value to
; initiate "data alignment check" PPI animation loop
myscanbuf[0:20,0:20] = 254B
myraybuf[0:20,0:20] = 254B
; add a hot corner to subtract 1 dBZ from GV and re-run x-sect differences
myscanbuf[windowsize-41:windowsize-22,windowsize-20:windowsize-1] = 253B
myraybuf[windowsize-41:windowsize-22,windowsize-20:windowsize-1] = 253B
; add a hot corner to add 1 dBZ to GV and re-run x-sect differences
myscanbuf[windowsize-20:windowsize-1,windowsize-20:windowsize-1] = 252B
myraybuf[windowsize-20:windowsize-1,windowsize-20:windowsize-1] = 252B
; add a hot corner to toggle between original and Ku-adjusted GV reflectivity
myscanbuf[windowsize-62:windowsize-43,windowsize-20:windowsize-1] = 251B
myraybuf[windowsize-62:windowsize-43,windowsize-62:windowsize-1] = 251B


; Render the PR and GV PPI plot - we don't actually view the scan and ray buffers
SET_PLOT, 'X'
device, decomposed=0
TV, myprbuf, 0
TV, mygvbuf, 1

; Burn in the labels for the GV dBZ offset hot corners
;xyouts, xsize-40, ysize*2-13, color=0, "-1", /DEVICE, CHARSIZE=1
;xyouts, xsize-18, ysize*2-13, color=0, "+1", /DEVICE, CHARSIZE=1
xyouts, xsize-40, ysize-13, color=0, "-1", /DEVICE, CHARSIZE=1
xyouts, xsize-18, ysize-13, color=0, "+1", /DEVICE, CHARSIZE=1
xyouts, xsize-61, ysize-13, color=0, "K,S", /DEVICE, CHARSIZE=1
window, 1, xsize=xsize, ysize=ysize*2, xpos = 350, ypos=50, TITLE = title
Device, Copy=[0,0,xsize,ysize*2,0,0,0]

;-------------------------------------------------

; Let the user select the cross-section locations:
print, ''
print, 'Left click on a PPI point to display a cross section of PR,'
print, 'or Right click inside PPI to select another case:'
print, ''
!Mouse.Button=1
havewin2 = 0

; copy the PPI's color table
tvlct, rr,gg,bb,/get

; -- set values 122-127 as white, for labels and such
rr[122:127] = 255
gg[122:127] = 255
bb[122:127] = 255

; also set up upper-byte colors here, in case we don't call plot_pr_xsection
; where it is normally handled.
; -- load compressed color table 33 into LUT values 128-255
loadct, 33
tvlct, rrhi, gghi, bbhi, /get
FOR j = 1,127 DO BEGIN
   rr[j+128] = rrhi[j*2]
   gg[j+128] = gghi[j*2]
   bb[j+128] = bbhi[j*2]
ENDFOR

tvlct, rr,gg,bb
; copy the expanded PPI color table for re-loading in cursor loop when PPIs are
; redrawn
tvlct, rr,gg,bb,/get

gvzoff = 0.0
is_ku = 0

WHILE ( !Mouse.Button EQ 1 ) DO BEGIN
   WSet, 1
   CURSOR, xppi, yppi, /DEVICE, /DOWN
   IF ( !Mouse.Button NE 1 ) THEN BREAK
   print, "X: ", xppi, "  Y: ", yppi MOD ysize
   scanNum = myscanbuf[xppi, yppi MOD ysize]

   IF ( scanNum GT 2 AND scanNum LT 251B ) THEN BEGIN  ; account for +3 offset and hot corner values

      IF ( havewin2 EQ 1 ) THEN BEGIN
         IF ( no_2a25 NE 1 ) THEN WDELETE, 3
         WDELETE, 5
         WDELETE, 6
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

      IF ( no_2a25 NE 1 ) THEN BEGIN
        ; generate the PR full-resolution vertical cross section plot
         plot_pr_xsection, scanNumpr, raystartpr, rayendpr, dbz_2a25, meanbb, $
                        DBZSCALE2A25, rangeBinNums, TITLE=caseTitle25
        ; output the corresponding PIA values to the terminal
        ; (per Bringi request Nov'09)
;         print, ''
;         print, 'Raynumber, Latitude, Longitude, and PIA field from Point A to Point B:'
;         for ray2print = raystartpr, rayendpr do begin
;            print, ray2print, geolocation[0,ray2print,scanNumpr], $
;                geolocation[1,ray2print,scanNumpr], pia[0,ray2print,scanNumpr]
;         endfor
         print, ''
      ENDIF

     ; generate the PR and GV geo-match vertical cross sections
     ; -- with any indicated GV offset, and Ku conversion if indicated
      print, "Current GV offset = ", gvzoff, " dBZ"
      gvz4xsec = gvz
      gvz4xsec[idx2adj] = gvz4xsec[idx2adj] + gvzoff
      if is_ku EQ 1 then gv_z_s2ku_4xsec, gvz4xsec, bbprox, idx2adj
      tvlct, rr, gg, bb
      plot_geo_match_xsections, gvz4xsec, zcor, top, botm, meanbb, nframes, $
                                idxcurscan, idxmin, idxmax, TITLE=caseTitle, $
                                GVOFF=gvzoff, S2KU=is_ku

      havewin2 = 1  ; need to delete x-sect windows at end

      print, ''
      print, "Select another cross-section location in the image,"
      print, "or Left click on one of the labeled white squares to adjust the"
      print, "geo_match GV reflectivities by the indicated amount and re-draw,"
      print, "or Left click on the white square at the lower right to view"
      print, "an animation loop of volume-match and full-resolution PR and GV data,"
      print, 'or Right click inside PPI to select another case:'
   ENDIF ELSE BEGIN
     ; only the lower 9GV) image has hot corners, check whether cursor lies there
      IF ( yppi LE ysize ) THEN BEGIN
      CASE scanNum OF
         254B : status = loop_pr_gv_gvpolar_ppis(ncfilepr, ufpath, 3, ifram+1)
         253B : BEGIN
                   IF ( havewin2 EQ 1 ) THEN BEGIN
                      print, ""
                      print, "Lowering GV reflectivity 1.0 dBZ"
                      gvzoff = gvzoff - 1.0
                      print, "Current GV offset = ", gvzoff, " dBZ"
                      gvz4xsec = gvz
                      gvz4xsec[idx2adj] = gvz4xsec[idx2adj] + gvzoff
                      if is_ku EQ 1 then gv_z_s2ku_4xsec, gvz4xsec, bbprox, idx2adj
                      tvlct, rr, gg, bb
                      plot_geo_match_xsections, gvz4xsec, zcor, top, botm, meanbb, nframes, $
                                idxcurscan, idxmin, idxmax, TITLE=caseTitle, GVOFF=gvzoff, $
                                S2KU=is_ku
                   ENDIF ELSE print, "Point outside PR-PPI overlap area, choose another..."
                END
         252B : BEGIN
                   IF ( havewin2 EQ 1 ) THEN BEGIN
                      print, ""
                      print, "Raising GV reflectivity 1.0 dBZ"
                      gvzoff = gvzoff + 1.0
                      print, "Current GV offset = ", gvzoff, " dBZ"
                      gvz4xsec = gvz
                      gvz4xsec[idx2adj] = gvz4xsec[idx2adj] + gvzoff
                      if is_ku EQ 1 then gv_z_s2ku_4xsec, gvz4xsec, bbprox, idx2adj
                      tvlct, rr, gg, bb
                      plot_geo_match_xsections, gvz4xsec, zcor, top, botm, meanbb, nframes, $
                                idxcurscan, idxmin, idxmax, TITLE=caseTitle, GVOFF=gvzoff, $
                                S2KU=is_ku
                   ENDIF ELSE print, "Point outside PR-PPI overlap area, choose another..."
                END
         251B : BEGIN
                   gvz4xsec = gvz
                   gvz4xsec[idx2adj] = gvz4xsec[idx2adj] + gvzoff
                   if ( is_ku EQ 0 ) then begin
                      print, 'Converting S-band reflectivity to Ku-band equivalent.'
                      is_ku = 1
                      gv_z_s2ku_4xsec, gvz4xsec, bbprox, idx2adj
                   endif else begin
                      print, 'Restore S-band reflectivity from Ku-band equivalent.'
                      is_ku = 0
                   endelse
                   tvlct, rr, gg, bb
                   plot_geo_match_xsections, gvz4xsec, zcor, top, botm, meanbb, nframes, $
                          idxcurscan, idxmin, idxmax, TITLE=caseTitle, GVOFF=gvzoff, $
                          S2KU=is_ku
                END
         ELSE : print, "Point outside PR-PPI overlap area, choose another..."
      ENDCASE
      ENDIF ELSE print, "Point outside PR-PPI overlap area, choose another..."
   ENDELSE
ENDWHILE

wdelete, 1
wdelete, 9
IF ( havewin2 EQ 1 ) THEN BEGIN
   IF ( no_2a25 NE 1 ) THEN WDELETE, 3
   WDELETE, 5
   WDELETE, 6
ENDIF

errorExit:
end

@plot_pr_xsection.pro
@plot_geo_match_xsections.pro

;===============================================================================

; MODULE #1

pro pr_and_geo_match_x_sections, ELEV2SHOW=elev2show, SITE=sitefilter, $
                                 NO_PROMPT=no_prompt, NCPATH=ncpath,   $
                                 PRPATH=prpath, UFPATH=ufpath, USE_DB=use_db, $
                                 NO_2A25=no_2a25, PCT_ABV_THRESH=pctAbvThresh

print, ""

IF ( N_ELEMENTS(ncpath) NE 1 ) THEN BEGIN
   print, "Defaulting to /data/netcdf/geo_match for netCDF file path."
   print, ""
   pathgeo = '/data/netcdf/geo_match'
ENDIF ELSE pathgeo = ncpath

IF ( N_ELEMENTS(sitefilter) NE 1 ) THEN BEGIN
   print, "Defaulting to * for file pattern."
   print, ""
   ncfilepatt = 'GRtoPR*.nc*'
ENDIF ELSE ncfilepatt = 'GRtoPR*'+sitefilter+'*'

; Set use_db flag, default is to not use a Postgresql database query to obtain
; the PR 2A25 product filename matching the geo-match netCDF file for each case.
use_db = KEYWORD_SET( use_db )

; Set the no_2a25 flag.  Default is to look for original PR 2A-25 product file
; and plot cross section of full-res PR data.  If set, then plot only geo-match
; cross section data from the netCDF files.
no_2a25 = KEYWORD_SET( no_2a25 )

; Decide which PR and GV points to include, based on percent of expected points
; in bin-averaged results that were above dBZ thresholds set when the matchups
; were done.  If unspecified or set to zero, include all points regardless of
; 'completeness' of the volume averages.

IF ( N_ELEMENTS(pctAbvThresh) NE 1 ) THEN BEGIN
   print, "Defaulting to 0 for PERCENT BINS ABOVE THRESHOLD."
   pctAbvThresh = 0.0
ENDIF ELSE BEGIN
   pctAbvThresh = FLOAT(pctAbvThresh)
   IF ( pctAbvThresh LT 0.0 OR pctAbvThresh GT 100.0 ) THEN BEGIN
      print, "Invalid value for PCT_ABV_THRESH: ", pctAbvThresh, $
             ", must be between 0 and 100."
      print, "Defaulting to 0 for PERCENT BINS ABOVE THRESHOLD."
      pctAbvThresh = 0.0
   ENDIF
END      

IF ( N_ELEMENTS(prpath) NE 1 ) THEN BEGIN
   IF ( no_2a25 NE 1 ) THEN BEGIN
      print, "Using default for PR product file path."
      IF ( use_db NE 1 ) THEN $
         print, "PR 2A-25 files may not be found if this location is incorrect."
      print, ""
   ENDIF
ENDIF ELSE BEGIN
   pathpr = prpath
ENDELSE

IF ( N_ELEMENTS(ufpath) NE 1 ) THEN BEGIN
   print, "Defaulting to /data/gv_radar/finalQC_in for UF file path prefix."
   pathgv = '/data/gv_radar/finalQC_in'
ENDIF ELSE pathgv = ufpath

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
         gen_pr_and_geo_match_x_sections, ncfilepr, use_db, no_2a25, $
                        ELEV2SHOW=elev2show, PCT_ABV_THRESH=pctAbvThresh, $
                        PR_ROOT_PATH=pathpr, UFPATH=pathgv
      endfor
   endelse
ENDIF ELSE BEGIN
   ncfilepr = dialog_pickfile(path=pathgeo, filter = ncfilepatt, Title='Select a GR_to_PR* netCDF file:')
   while ncfilepr ne '' do begin
      gen_pr_and_geo_match_x_sections, ncfilepr, use_db, no_2a25, $
                        ELEV2SHOW=elev2show, PCT_ABV_THRESH=pctAbvThresh, $
                        PR_ROOT_PATH=pathpr, UFPATH=pathgv
      ncfilepr = dialog_pickfile(path=pathgeo, filter = ncfilepatt)
   endwhile
ENDELSE

print, "" & print, "Done!"
END
