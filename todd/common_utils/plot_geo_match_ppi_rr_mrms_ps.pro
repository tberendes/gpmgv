;===============================================================================
;+
; Copyright © 2014, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; plot_geo_match_ppi_rr_mrms_ps.pro      - Berendes/UAH June 2018
;
; DESCRIPTION
; -----------
; Modified version of plot_geo_match_ppi_anim_ps.pro for MRMS rain rate PPI
; Plots static or dynamic display of PPI images from geometry-match data fields
; passed as an array of pointers to their data arrays.  Plots to an on-screen
; window by default, and also to a previously-opened Postscript device if DO_PS
; is set.
;
; PARAMETERS
; ----------
; field_ids     - 1 or 2-D array of short IDs of the fields to be plotted,
;                 e.g., 'CZ', 'RR', and the like.  Dimensions of the array
;                 determine the arrangement of the PPIs in the output, where
;                 the first dimension is the number of PPIs across the plot,
;                 and the second dimension is the number of PPIs in the
;                 vertical.  These field IDs must already be defined in the
;                 external modules in loadcolortable.pro and vn_colobar.pro
;
; source_ids    - As above, but the sources of the data fields - e.g., 'PR'
;
; field_data    - As above, but an array of pointers to the actual data arrays
;                 to be rendered in the PPIs
;
; thresholded   - As above, but a flag (0 or 1) that indicates whether the data
;                 have been prefiltered based on percent above threshold values
;
; common_data   - Structure containing scalars, structures, and small data
;                 arrays that affect the appearance and content of the PPIs
;
; do_ps         - Binary parameter, controls whether to plot PPIs to Postscript
;
;
;
; NON-SYSTEM ROUTINES CALLED
; --------------------------
; 1) plot_sweep_2_zbuf()
;
;
; HISTORY
; -------
; 03/05/10 Morris, GPM GV, SAIC
; - Created by extracting logic from geo_match_3d_rainrate_comparisons.pro.
; 01/05/14 Morris, GPM GV, SAIC
; - Added user title to the XINTERANIMATE window, and specify value of MAXRNGKM
;   parameter in call to plot_sweep_2_zbuf(), from values in the common_data
;   parameter.
; 01/28/15 Morris, GPM GV, SAIC
; - Added SHOW_PPIS parameter to inhibit on-screen plotting of PPI image(s).
; 04/15/15 Morris, GPM GV, SAIC
; - Added STEP_MANUAL keyword parameter to do a manual step-through animation
;   rather than using XINTERANIMATE utility, to allow a cleaner screen capture.
;
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;===============================================================================
;

FUNCTION plot_sfc_var_to_zbuf, zdata, radar_lat, radar_lon, xpoly, ypoly, pr_index, $
                            nfootprints, rntype, MAXRNGKM=maxrngkm, $
                            WINSIZ=winsiz, TITLE=title, FIELD=field, $
                            BGWHITE=bgwhite, _EXTRA=EXTRA_KEYWORDS

; removed cref and ilev
IF N_ELEMENTS( title ) EQ 0 THEN BEGIN
  title = 'level sfc'
ENDIF
;print, title

; Declare function for color plotting.  It is in loadcolortable.pro.
forward_function mapcolors
SET_PLOT,'Z'
winsize = 525
IF ( N_ELEMENTS(winsiz) EQ 1 ) THEN winsize = winsiz
xsize = winsize & ysize = xsize

; colorbar is vertical and 20 pixels wide (10 pixel half-width) by default,
; set a value for its position on the right side, with a bit of clearance
colorbar_thickness = xsize/17
xpos = FLOAT(xsize-(colorbar_thickness*0.9))/xsize

; text/title position/size fit is based on default window size of 375, adjust
; for other window sizes via textfac multiplier
textfac = winsize/375.

DEVICE, SET_RESOLUTION = [xsize,ysize], SET_CHARACTER_SIZE=[8,12]
error = 0
charsize = 0.75*textfac

;ilev = 0  ; sweep # to plot


if keyword_set(bgwhite) then begin
    prev_background = !p.background
    !p.background = 255
endif
if !p.background eq 255 then color = 0

IF N_ELEMENTS( maxrngkm ) EQ 1 THEN maxrange = ( FIX(maxrngkm) / 25 + 1 ) * 25.0 $
ELSE maxrange = 125. ; kilometers
;print, 'maxrange, maxdatarange (km): ', maxrange, maxrngkm

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

loadcolortable, field, error
if error then begin
    print, "error from loadcolortable"
    goto, bailout
endif
ray = zdata
;IF (cref) THEN ray = MAX(zdata,DIMENSION=2) ELSE ray = zdata[*,ilev]
; don't set negative values to zero for D0/Dm, DR and KD, dRR, negative or zero
;   value is valid or significant
IF (field NE 'DR' AND field NE 'KD' AND field NE 'D0' AND field NE 'Dm' AND $
    field NE 'dRR') THEN BEGIN
   inegidx = where( ray lt 0, countneg )
   if countneg gt 0 then ray[inegidx] = 0.0
ENDIF

color_index = mapcolors(ray, field)
if size(color_index,/n_dimensions) eq 0 then begin
    print, "error from mapcolors in PR array"
    goto, bailout
endif

; build 3 fill patterns: slanted, vertical, and solid
; array indices are opposite of what you might expect, 1=clear, 0=blackout
;npat = 4
;pat1 = [0b,1b,1b,0b]
npat = 3
pat1 = [1b,0b,1b]
horiz = BYTARR(npat,npat)
FOR j = 0, npat-1 DO BEGIN
    ;horiz[j,*] = BYTE(j MOD 2)*1B
    horiz[j,*] = pat1
ENDFOR

vertical = BYTARR(npat,npat)
FOR i = 0, npat-1 DO BEGIN
  ;vertical[*,i] = BYTE(i MOD 2)*1B
  vertical[*,i] = pat1
ENDFOR

solid = BYTARR(npat,npat)
solid[*,*] = 1B

;IF (cref) THEN xylev=0 ELSE xylev=ilev
for ifoot = 0, nfootprints-1 do begin
    if pr_index[ifoot] LT 0 THEN CONTINUE
    x = xpoly[*,ifoot,0]
    y = ypoly[*,ifoot,0]
;    x = xpoly[*,ifoot,xylev]
;    y = ypoly[*,ifoot,xylev]
   ; Convert points to latitude and longitude coordinates.
    lon = radar_lon + meters_to_lon * x * 1000.
    lat = radar_lat + meters_to_lat * y * 1000.
   ; Determine a fill pattern if rntype is provided
    IF N_ELEMENTS(rntype) GT 0 THEN BEGIN
       CASE rntype[ifoot] OF
         3 : pattern=solid      ; other
         2 : pattern=vertical   ; convective
         1 : pattern=horiz      ; stratiform
         ELSE : pattern=solid   ; not defined
       ENDCASE
       polyfill, lon, lat, /data,PATTERN=pattern*BYTE(color_index[ifoot])
    ENDIF ELSE polyfill, lon, lat, color=color_index[ifoot],/data
endfor

map_grid, /label, lonlab=sb, latlab=wb, latalign=0.0,/noerase, $
    charsize=charsize, color=color
map_continents, /hires, color=color, /usa , /rivers, _EXTRA=EXTRA_KEYWORDS ;e.g. /coasts, /countries

for range = 50.,maxrange,50. do $
    plot_range_rings2, range, radar_lon, radar_lat, color=color

vn_colorbar, field, charsize=charsize, color=255, unitscolor=color, XPOS=xpos, $
             thick=colorbar_thickness

; add image labels
xyouts, FIX(5*textfac), ysize-FIX(15*textfac), title, CHARSIZE=1*textfac, $
        COLOR=color, /DEVICE

; Label the radar location
oplot, [radar_lon], [radar_lat], psym=1, symsize=4, color=color

bufout = TVRD()
bailout:

return, bufout
end

;-
;===============================================================================
;
PRO plot_geo_match_ppi_rr_mrms_ps, field_ids, source_ids, field_data,    $
                                thresholded, common_data, DO_PS=do_ps,    $
                                SHOW_PPIS=show_ppis_in

plot2ps = KEYWORD_SET(do_ps)
show_ppis = KEYWORD_SET(show_ppis_in)

retain = 2
xsize=common_data.winSize & ysize=xsize
!P.MULTI=[0,1,1]

s = SIZE(field_ids)
ds = SIZE(field_data)
; check that array dimensions are the same
IF ARRAY_EQUAL( s[0:s[0]], ds[0:ds[0]] ) NE 1 THEN $
    message, "Unequal ID/data field dimensions."

CASE s[0] OF
    0 : message, "No field IDs passed, can't plot anything."
    1 : BEGIN
          ; set up the orientation of the PPIs - side-by-side, or vertical
          IF (common_data.PPIorient) THEN BEGIN
             nx = 1
             ny = s[1]
          ENDIF ELSE BEGIN
             nx = s[1]
             ny = 1
          ENDELSE
        END
    2 : BEGIN
          nx = s[1]
          ny = s[2]
        END
 ELSE : message, "Too many subpanel dimensions, max=2."
ENDCASE

; only need this window if not in batch mode
IF ( show_ppis ) THEN window, 2, xsize=xsize*nx, ysize=ysize*ny, xpos = 75, $
                              TITLE = common_data.wintitle, PIXMAP=do_pixmap, RETAIN=retain

IF common_data.pctString EQ '0' THEN epilogue = "all valid samples" $
ELSE epilogue = '!m'+STRING("142B)+common_data.pctString $
                +"% of PR/GR bins above threshold"

IF plot2ps THEN BEGIN  ; set up to plot the PPIs to the postscript file
   bgwhite = 1
;         maxdim = nx > ny ? nx : ny
;         ps_size = 10/maxdim
  ; figure out how to fit within an 8x10 inch area
  ; and the locations in which the PPIs are to be positioned
   IF nx GT ny THEN BEGIN
      ps_size = 10.0/nx < 7.5/ny
      xborder = (7.5-ps_size*ny)/2.0
      yborder = (10.0-ps_size*nx)/2.0
      ippi_pos = indgen(nx,ny)
      xoffsets = xborder+(ippi_pos/nx)*ps_size
      yoffsets = yborder+(ny-(ippi_pos MOD nx))*ps_size
   ENDIF ELSE BEGIN
      ps_size = 10.0/ny < 7.5/nx
      xborder = (8.0-ps_size*nx)/2.0
      yborder = (10.0-ps_size*ny)/2.0
      ippi_pos = indgen(nx,ny)
      xoffsets = xborder+((ippi_pos MOD nx)*ps_size)
      yoffsets = 10.0-yborder-(ippi_pos/nx+1)*ps_size
   ENDELSE
ENDIF ELSE bgwhite = 0


;FOR ifram=0,common_data.nframes-1 DO BEGIN

   orig_device = !D.NAME
;   elevstr = 'Sfc'
   FOR ippi = 0, nx*ny-1 DO BEGIN
      if source_IDs[ippi] NE 'DPR' and source_IDs[ippi] NE 'MRMS' then $ 
         elevstr = 'lowest' else elevstr = 'sfc'
      IF thresholded[ippi] THEN epilogue = elevstr+'!m'+STRING(37B)+" sweep, " $
         + '!m'+STRING("142B) + common_data.pctString+"% bins above threshold" $
      ELSE epilogue = elevstr+'!m'+STRING(37B)+" sweep, "+"all valid samples"
      ppiTitle = source_IDs[ippi]+" "+field_ids[ippi]+", "+epilogue
      buf = plot_sfc_var_to_zbuf( *(field_data[ippi]), common_data.site_lat, $
                               common_data.site_lon, common_data.xCorner, $
                               common_data.yCorner, common_data.pr_index, $
                               common_data.num_footprints, $
                               common_data.rntype4ppi, $
                               MAXRNGKM=common_data.rangeThreshold, $
                               WINSIZ=common_data.winSize, $
                               TITLE=ppiTitle, FIELD=field_ids[ippi], $
                               BGWHITE=bgwhite )
      IF ( show_ppis ) THEN BEGIN
         SET_PLOT, 'X'
         device, decomposed=0
         TV, buf, ippi
         SET_PLOT, orig_device
      ENDIF
      IF plot2ps THEN BEGIN  ; plot the PPIs to the postscript file
         set_plot,/copy,'ps'
         IF ippi EQ 0 THEN erase
         TV, buf, xoffsets[ippi], yoffsets[ippi], xsize=ps_size, $
             ysize=ps_size, /inches
        ;print, ppiTitle
        ;print, 'ippi, xoffsets, yoffsets: ', ippi, xoffsets[ippi], yoffsets[ippi]
         SET_PLOT, orig_device
      ENDIF
   ENDFOR
;ENDFOR

END

