;===============================================================================
;+
; Copyright © 2015, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; plot_sweep_2_zbuf_4xsec.pro       - Morris/SAIC/GPM_GV     April 2015
;
; DESCRIPTION
; -----------
; Generates a pseudo-PPI of scan or ray number to allow determination of cross
; section or storm location in terms of the original PR/DPR array coordinates.
;
; PARAMETERS
; ----------
; zdata - Array of PR/DPR scan or ray number.  Only one or the other may be
;         analyzed in a call to this function.
;
; radar_lat, radar_lon - Lat and lon of the ground radar site, for mapping.
;
; xpoly, ypoly - (x,y) corner points of each zdata sample, km from the radar.
;                There are 4 corner points for each zdata sample.
;
; pr_index - 1-dimensional array indices of the zdata samples, relative to
;            their position in the full product arrays read from the PR/DPR
;            file used in the volume matching.
;
; nfootprints - number of samples in the zdata array.  Redundant but required.
;
; ifram - index of the vertical level to be used for the xpoly and ypoly data.
;
; maxrngkm - optional maximum range for the PPI plot, defaults to 125. if not
;            specified.
;
; winsiz - dimension (xsize and ysize, equal sizes) of the window to which the
;          data are to be mapped.  Defaults to 525 if unspecified.
;
; nocolor - Binary keyword, controls whether zdata values are mapped to a color
;           table or just used as is when mapping to zbuffer (default).
;           PROBABLY SHOULD BE REMOVED/DISABLED HERE AND IN CALLING CODE.
;
; title - unused parameter left here to make this function call compatible with
;         plot_sweep_2_zbuf( ).
;
;
; HISTORY
; -------
; 04/08/15 Morris, GPM GV, SAIC
; - Created by extracting this internal function from source code file
;   geo_match_3d_rr_or_z_comparisons.pro
;
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;===============================================================================
;

FUNCTION plot_sweep_2_zbuf_4xsec, zdata, radar_lat, radar_lon, xpoly, ypoly, $
                            pr_index, nfootprints, ifram, MAXRNGKM=maxrngkm, $
                            WINSIZ=winsiz, NOCOLOR=nocolor, TITLE=title


; Declare function for color plotting.  It is in loadcolortable.pro.
forward_function mapcolors
SET_PLOT,'Z'
winsize = 525
IF ( N_ELEMENTS(winsiz) EQ 1 ) THEN winsize = winsiz
xsize = winsize & ysize = xsize
DEVICE, SET_RESOLUTION = [xsize,ysize], SET_CHARACTER_SIZE=[6,10]
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

bailout:

return, bufout
end

