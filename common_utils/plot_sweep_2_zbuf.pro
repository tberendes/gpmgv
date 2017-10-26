;+
; Copyright © 2008, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; plot_sweep_2_zbuf.pro
;
; Produces PPI plot of PR or GV reflectivity 'zdata' at a selected sweep
; elevation angle index 'ilev', in the form of an IDL Z-buffer.  Returns the
; Z-buffer as the return value.  If the CREF parameter is set, then ilev is
; ignored and instead the PPI is for the highest reflectivity for each PR ray
; location, taken over all the sweeps (i.e. Composite Reflectivity).
;
; HISTORY
; -------
; 07/20/09 Morris, GPM GV, SAIC
; - Replaced call to rsl_colorbar with call to vn_colorbar to fix error in color
;   bar labeling.
; 04/12/10  Morris/GPM GV/SAIC
; - Added optional keyword parameter MAXRNGKM for the maximum range of the data
;   as indicated in the netCDF file, to override the default 125 km cutoff.
; 06/03/11  Morris/GPM GV/SAIC
; - Added optional keyword parameter FIELD for plotting of Rain Rate on the PPI
; 01/24/12  Morris/GPM GV/SAIC
; - Added BGWHITE parameter to provide an option to plot white background, as
;   already present in code.
; - Fixed use of 'color' according to bgwhite setting.
; 08/10/12  Morris/GPM GV/SAIC
; - Added SET_CHARACTER_SIZE=[8,12] to DEVICE setup to reinitialize character
;   sizes that get reset in other plot routines now that we are using the
;   Z-buffer for x-section plots.
; 08/15/12  Morris/GPM GV/SAIC
; - Added CREF parameter to plot a PPI of Composite Reflectivity (highest
;   reflectivity in the vertical column) rather than at a fixed sweep elevation.
; 08/15/13  Morris/GPM GV/SAIC
; - Added _EXTRA parameter to pass non-default keyword values along to
;   map_continents procedure.
; 02/18/13  Morris/GPM GV/SAIC
; - Added exceptions for handling zero/negative values for Zdr, Kdp, D0, for
;   which such values are physically valid.
; 08/12/14  Morris/GPM GV/SAIC
; - Added plotting of a + marker at the radar location.
; 01/14/15  Morris/GPM GV/SAIC
; - Added logic to treat Dm like D0.
; 08/25/15  Morris/GPM GV/SAIC
; - Added unitscolor parameter to call to vn_colorbar so that units labels are
;   visible in Postscript/BGWHITE output.
; 08/15/16  Morris/GPM GV/SAIC
; - Added dRR to the list of fields ignored for setting negative values to zero,
;   and define a non-default colorbar_thickness parameter value for this field.
; - Modified rain type hatching patterns to finer lines.
; - Add xpos and colorbar_thickness to vn_colorbar optional calling parameters.
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-


FUNCTION plot_sweep_2_zbuf, zdata, radar_lat, radar_lon, xpoly, ypoly, pr_index, $
                            nfootprints, ilev, rntype, MAXRNGKM=maxrngkm, $
                            WINSIZ=winsiz, TITLE=title, FIELD=field, $
                            BGWHITE=bgwhite, CREF=cref, _EXTRA=EXTRA_KEYWORDS

IF N_ELEMENTS( title ) EQ 0 THEN BEGIN
  title = 'level ' + STRING(ilev)
ENDIF
;print, title

IF N_ELEMENTS( field ) EQ 0 THEN field = 'CZ'
cref = KEYWORD_SET(cref)

; Declare function for color plotting.  It is in loadcolortable.pro.
forward_function mapcolors
SET_PLOT,'Z'
winsize = 525
IF ( N_ELEMENTS(winsiz) EQ 1 ) THEN winsize = winsiz
xsize = winsize & ysize = xsize

; colorbar is vertical and 20 pixels wide (10 pixel half-width) by default,
; set a value for its position on the right side, with a bit of clearance
colorbar_thickness = xsize/17
IF field EQ 'dRR' THEN colorbar_thickness = xsize/13
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

IF (cref) THEN ray = MAX(zdata,DIMENSION=2) ELSE ray = zdata[*,ilev]
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

IF (cref) THEN xylev=0 ELSE xylev=ilev
for ifoot = 0, nfootprints-1 do begin
    if pr_index[ifoot] LT 0 THEN CONTINUE
    x = xpoly[*,ifoot,xylev]
    y = ypoly[*,ifoot,xylev]
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
