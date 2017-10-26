;+
; Copyright © 2016, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; loop_pr_gv_gvpolar_cappis.pro    Bob Morris (SAIC)    May 2016
;
; Produces animation loop of CAPPI plot of PR and GV reflectivity 'zdata' for
; the number of height levels specified in elevs2show. DEFERRED: Interleaves a
; full resolution ground radar (GV) PPI of data from the radar UF file with
; volume-matched PR and GV data from a geo_match netCDF file if UF data are
; available, otherwise only the PR and GV geo_match PPIs are included.
;
; 05/26/16 Morris, GPM GV, SAIC
; - CREATED from loop_pr_gv_gvpolar_ppis.pro, modified to do CAPPI plots.
;
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;===============================================================================

FUNCTION loop_pr_gv_gvpolar_cappis, dataStruct, looprate, elevs2show, heights, $
                                    INSTRUMENT_ID=instrument_id

; "Include" files for names, paths, structure definitions, etc.:
;@geo_match_nc_structs.inc

IF ( N_PARAMS() NE 4 ) THEN MESSAGE, 'Incorrect number of parameters, must be 4'

IF N_ELEMENTS( instrument_id ) EQ 1 THEN BEGIN
   CASE instrument_id OF
       'PR' : rad = instrument_id
      'DPR' : rad = instrument_id
   'DPRGMI' : rad = 'CMB'
       ELSE : message, "Unknown value for INSTRUMENT_ID: "+instrument_id
   ENDCASE
ENDIF ELSE rad = 'PR'   ; default to legacy behavior of using TRMM PR data

 ; create data field arrays of correct dimensions and read data fields
  nfp = dataStruct.nfp
  nswp = dataStruct.nswp
  gvz = *dataStruct.gvz
;  zraw = *(dataStruct.ptr_)
  zcor = *dataStruct.zcor
  top = *dataStruct.top
  botm = *dataStruct.botm
  xcorner = *dataStruct.xcorner
  ycorner = *dataStruct.ycorner
  pr_index = *dataStruct.pr_index

; get the plotted variables mapped onto CAPPI surfaces
gvzCAP = geo_match_to_fixed_heights( gvz, top, botm, heights)
zcorCAP = geo_match_to_fixed_heights( zcor, top, botm, heights)
pr_indexCAP = geo_match_to_fixed_heights( pr_index, top, botm, heights)

IF (SIZE(gvzCAP, /TYPE) EQ 7) OR (SIZE(gvzCAP, /TYPE) EQ 7) $
   OR (SIZE(pr_indexCAP, /TYPE) EQ 7) THEN BEGIN
   message, "Error mapping geometry match data to fixed heights", /INFO
   GOTO, errorExit
ENDIF

; use lowest-sweep's pixel outlines for each height level
nlevcorner = N_ELEMENTS(heights)
xCornerCAP=FLTARR(4,nfp,nlevcorner)  ; for temporary use
yCornerCAP=FLTARR(4,nfp,nlevcorner)
; copy 1st level to ALL levels for "CAP" arrays
FOR level = 0, nlevcorner-1 DO BEGIN
   xCornerCAP[*,*,level] = xCorner[*,*,0]
   yCornerCAP[*,*,level] = yCorner[*,*,0]
ENDFOR
xCorner = TEMPORARY(xCornerCAP)  ; reassign and release "temporary" arrays
yCorner = TEMPORARY(yCornerCAP)

prtime = dataStruct.timeNearestApproach
gvbegin = (*dataStruct.mysweeps)[0].atimeSweepStart
print, "GV begin time = ",  gvbegin

have_uf = 0
uf_file = 'Not found'  ;dataStruct.uf_file  ; DISABLING FULL-RES GR PLOT

if ( uf_file NE 'Not found' ) THEN BEGIN
; copy/unzip/open the UF file and read the entire volume scan into an
;   RSL_in_IDL radar structure, and then close UF file and delete copy:

   status=get_rsl_radar(uf_file, radar)
   IF ( status NE 0 )  THEN BEGIN
      PRINT, ""
      PRINT, "Error reading radar structure from file ", file_1CUF
      PRINT, ""
      GOTO, errorExit
   ENDIF

  ; find the volume with the correct reflectivity field for the GV site/source,
  ;   and the ID of the field itself
   gv_z_field = ''
   z_vol_num = get_site_specific_z_volume( (*dataStruct.mysite).site_id, radar, gv_z_field )
   IF ( z_vol_num LT 0 )  THEN BEGIN
      PRINT, ""
      PRINT, "Error finding volume in radar structure from file ", file_1CUF
      PRINT, ""
      GOTO, errorExit
   ENDIF

   ; Retrieve the desired radar volume from the radar structure
    zvolume = rsl_get_volume( radar, z_vol_num )
    IF ( SIZE(zvolume, /N_DIMENSIONS) EQ 0 ) THEN GOTO, errorExit
    have_uf = 1

endif   ; uf_file not "Not found"

   ; instantiate animation widget
   windowsize = 400
   xsize = windowsize[0]
   ysize = xsize
   nframes = elevs2show < N_ELEMENTS(heights)
   window, 10, xsize=xsize, ysize=ysize, xpos = 75, TITLE = title, /PIXMAP
   ;xinteranimate, set=[xsize, ysize, 4], /TRACK
   IF (have_uf EQ 1) THEN xinteranimate, set=[xsize, ysize, 4*nframes], /TRACK $
   ELSE xinteranimate, set=[xsize, ysize, 2*nframes], /TRACK

   error = 0
   loadcolortable, 'CZ', error
   if error then begin
       print, "error from loadcolortable"
       goto, errorExit
   endif

   print, ""
   ;FOR ifram=0,1 DO BEGIN
   FOR ifram=0,nframes-1 DO BEGIN
      gvtime = (*dataStruct.mysweeps)[0].timeSweepStart
      tdiff = FIX(prtime-gvtime) & tdiffstr = STRING(ABS(tdiff), FORMAT='(I0)')
      IF ( tdiff LE 0 ) THEN BEGIN
      timestr = ", " + tdiffstr + " secs. after " + rad
      ENDIF ELSE BEGIN
      timestr = ", " + tdiffstr + " secs. before " + rad
      ENDELSE
      ;print, "Time difference (sec), PR-GV: ", tdiffstr
      ;print, ""
      elevstr =  string( heights[ifram], FORMAT='(f0.1)' )
      print, "Assembling CAPPIs for " + elevstr + " km level"
      prtitle = rad + " for "+elevstr+" km level"
      myprbuf = plot_sweep_2_zbuf( zcorCAP, (*dataStruct.mysite).site_lat, $
                             (*dataStruct.mysite).site_lon, xCorner, $
                             yCorner, pr_indexCAP, nfp, ifram, $
                             WINSIZ=windowsize, TITLE=prtitle, $
                             MAXRNGKM=dataStruct.rangeThreshold )
      gvtitle = (*dataStruct.mysite).site_ID+" GR for "+elevstr+" deg. sweep"+timestr
      mygvbuf = plot_sweep_2_zbuf( gvzCAP, (*dataStruct.mysite).site_lat, $
                             (*dataStruct.mysite).site_lon, xCorner, $
                             yCorner, pr_indexCAP, nfp, ifram, $
                             WINSIZ=windowsize, TITLE=gvtitle, $
                             MAXRNGKM=dataStruct.rangeThreshold )
   IF (have_uf EQ 1) THEN BEGIN
      if size(zvolume,/n_dimensions) gt 0 then $
	  sweep = rsl_get_sweep(zvolume,(*dataStruct.mysweeps)[ifram].elevationAngle ) $
      else begin
          print, 'Cannot find sweep ', ifram, ' in UF file, skipping sweep.'
	  goto, errorExit
      endelse

      if size(sweep,/n_dimensions) gt 0 then begin
          latlon = [(*dataStruct.mysite).site_lat, (*dataStruct.mysite).site_lon]
	  mygvbufhi = rsl_plotsweep2pixmap( sweep, radar.h, WINDOWSIZE=windowsize, $
                               MAXRNGKM=dataStruct.rangeThreshold, LATLON=latlon)
      endif else begin
          print, 'Empty sweep ', ifram, ' in UF file, skipping sweep.'
	  goto, errorExit
      endelse
   ENDIF

      SET_PLOT, 'X'
      device, decomposed=0
      TV, myprbuf
   IF (have_uf EQ 1) THEN BEGIN
     ; include full-res GV PPI, and put PR PPI in at either end of elev. sequence
      xinteranimate, frame = ifram*4, window=10
      xinteranimate, frame = 3+ifram*4, window=10
      ;print, "Loaded pr frame ", ifram+1
      TV, mygvbufhi
      xinteranimate, frame = 1+ifram*4, window=10
      TV, mygvbuf
      xinteranimate, frame = 2+ifram*4, window=10
      ;print, "Loaded gv frame ", ifram+1
   ENDIF ELSE BEGIN
     ; loop between PR and GV vol-match PPIs only
      xinteranimate, frame = ifram*2, window=10
      TV, mygvbuf
      xinteranimate, frame = 1+ifram*2, window=10   
   ENDELSE
   
   ENDFOR

   print, ''
   print, 'Click END ANIMATION button or close Animation window to return to cross sections:
   print, ''
   xinteranimate, looprate, /BLOCK

errorExit:
return,0
end
