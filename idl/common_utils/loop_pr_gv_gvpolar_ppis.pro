;+
; Copyright © 2009, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; loop_pr_gv_gvpolar_ppis.pro    Bob Morris (SAIC)    April 2009
;
; Produces animation loop of PPI or CAPPI plots of PR and GV reflectivity
; 'zdata' for the number of elevation angles specified in elevs2show.
; If plotting as PPIs, then the procedure attempts to interleave a full
; resolution ground radar (GV) PPI of data from the radar UF file with
; volume-matched PR and GV data from a geo_match netCDF file if UF data are
; available.  Otherwise only the PR and GV geo_match PPIs or CAPPIs are
; included.
;
; 04/12/10  Morris/GPM GV/SAIC
; - Modified PPI pixmap/buffer code to plot over the maximum range of the data
;   as indicated in the netCDF file, rather than a fixed 125 km cutoff.
; 08/14/12  Morris/GPM GV/SAIC
; - Modified title text for the PR and GR volume-match PPIs.
; - Added LATLON parameter to call to rsl_plotsweep2pixmap() to override RSL's
;   (D)DDMMSS Lat/Lon values.
; 07/12/13 Morris, GPM GV, SAIC
; - Added INSTRUMENT_ID keyword parameter and logic to handle either TRMM PR or
;   GPM DPR matchup netCDF data files.
; 07/01/15 Morris, GPM GV, SAIC
; - Added DPRGMI as a valid value for the INSTRUMENT_ID keyword parameter.
; - Actually use value of INSTRUMENT_ID to label plots in place of hard-coded
;   value = PR.
; - Replaced regular parameters ncfilepr and gv_base_dir with a single parameter
;   that is a structure type, holding scalars and pointers to data fields
;   already read from a matchup netCDF file.  Eliminates having this function
;   open and read the file again.
; 05/27/16 Morris, GPM GV, SAIC
; - Added option to plot geo-match data only as CAPPIs at caller-specified
;   height levels.
;
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;===============================================================================

FUNCTION loop_pr_gv_gvpolar_ppis, dataStruct, looprate, elevs2show, $
                                  CAPPI_HEIGHTS=cappi_heights, $
                                  INSTRUMENT_ID=instrument_id

; "Include" files for names, paths, structure definitions, etc.:
;@geo_match_nc_structs.inc

IF ( N_PARAMS() NE 3 ) THEN MESSAGE, 'Incorrect number of parameters, must be 3'

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
  xcorner = *dataStruct.xcorner
  ycorner = *dataStruct.ycorner
  pr_index = *dataStruct.pr_index

prtime = dataStruct.timeNearestApproach
gvbegin = (*dataStruct.mysweeps)[0].atimeSweepStart
print, "GV begin time = ",  gvbegin
ncap = N_ELEMENTS(cappi_heights)

IF ncap EQ 0 THEN BEGIN
   do_cappi = 0
   have_uf = 0
   uf_file = dataStruct.uf_file
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
ENDIF ELSE BEGIN
   do_cappi = 1
   have_uf = 0           ; DISABLE UF PLOTS FOR CAPPI CASE, DEFERRED CAPABILITY
  ; get the additional geo-match fields needed to compute CAPPIs
   top = *dataStruct.top
   botm = *dataStruct.botm
   pr_index = *dataStruct.pr_index
  ; get the plotted variables mapped onto CAPPI surfaces
   gvzCAP = geo_match_to_fixed_heights( gvz, top, botm, cappi_heights, METHOD='STRICT')
   zcorCAP = geo_match_to_fixed_heights( zcor, top, botm, cappi_heights, METHOD='STRICT')
   pr_indexCAP = geo_match_to_fixed_heights( pr_index, top, botm, cappi_heights, METHOD='STRICT')

   IF (SIZE(gvzCAP, /TYPE) EQ 7) OR (SIZE(gvzCAP, /TYPE) EQ 7) $
      OR (SIZE(pr_indexCAP, /TYPE) EQ 7) THEN BEGIN
      message, "Error mapping geometry match data to fixed heights", /INFO
      GOTO, errorExit
   ENDIF ELSE BEGIN
     ; move CAPPI arrays back into original variables
      gvz = TEMPORARY(gvzCAP)  ; reassign and release "temporary" array
      zcor = TEMPORARY(zcorCAP)
      pr_index = TEMPORARY(pr_indexCAP)
   ENDELSE

   ; step through the cappi levels and find highest one with
   ; data of a plottable value (15 dBZ)
   ngoodcappi = 0
   FOR level = 0, ncap-1 DO BEGIN
      idxgood = WHERE( gvz[*,level] GE 15.0 OR zcor[*,level] GE 15.0, ngood )
      IF ngood GT 0 THEN ngoodcappi = level + 1
   ENDFOR
   IF ngoodcappi EQ 0 THEN BEGIN
      print, ''
      print, "Defined CAPPI levels: ", cappi_heights
      message, "No non-blank CAPPI images found, skipping animation.", /INFO
      print, ''
      GOTO, errorExit
   ENDIF ELSE BEGIN
      print, ''
      print, "Highest non-blank CAPPI level: ", $
             string(cappi_heights[ngoodcappi-1], FORMAT='(f0.1)'), ' km'
   ENDELSE

   ; use lowest-sweep's pixel outlines for each height level
   xCornerCAP=FLTARR(4,nfp,ncap)  ; for temporary use
   yCornerCAP=FLTARR(4,nfp,ncap)
   ; copy 1st level to ALL levels for "CAP" arrays
   FOR level = 0, ncap-1 DO BEGIN
      xCornerCAP[*,*,level] = xCorner[*,*,0]
      yCornerCAP[*,*,level] = yCorner[*,*,0]
   ENDFOR
   xCorner = TEMPORARY(xCornerCAP)  ; reassign and release "temporary" arrays
   yCorner = TEMPORARY(yCornerCAP)
ENDELSE


   ; instantiate animation widget
   windowsize = 400
   xsize = windowsize[0]
   ysize = xsize
   IF (do_cappi) THEN nframes = elevs2show < ngoodcappi $
      ELSE nframes = elevs2show < nswp
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
      IF do_cappi THEN BEGIN
         elevstr =  string( cappi_heights[ifram], FORMAT='(f0.1)' ) $
                    + " km level"
         print, "Assembling CAPPIs for " + elevstr
         prtitle = rad + " for "+elevstr
        ; take middle time of volume scan as GR data time
         gvtime = (*dataStruct.mysweeps)[nswp/2].timeSweepStart
      ENDIF ELSE BEGIN
         elevstr =  string((*dataStruct.mysweeps)[ifram].elevationAngle, FORMAT='(f0.1)') $
                    + " deg. sweep"
         print, "Assembling PPIs for " + elevstr
         prtitle = rad + " for "+elevstr
         gvtime = (*dataStruct.mysweeps)[ifram].timeSweepStart
      ENDELSE
      tdiff = FIX(prtime-gvtime) & tdiffstr = STRING(ABS(tdiff), FORMAT='(I0)')
      IF ( tdiff LE 0 ) THEN BEGIN
      timestr = ", " + tdiffstr + " secs. after " + rad
      ENDIF ELSE BEGIN
      timestr = ", " + tdiffstr + " secs. before " + rad
      ENDELSE
      ;print, "Time difference (sec), PR-GV: ", tdiffstr
      ;print, ""
      gvtitle = (*dataStruct.mysite).site_ID+" GR for "+elevstr+timestr

      myprbuf = plot_sweep_2_zbuf( zcor, (*dataStruct.mysite).site_lat, $
                             (*dataStruct.mysite).site_lon, xCorner, $
                             yCorner, pr_index, nfp, ifram, $
                             WINSIZ=windowsize, TITLE=prtitle, $
                             MAXRNGKM=dataStruct.rangeThreshold )
      mygvbuf = plot_sweep_2_zbuf( gvz, (*dataStruct.mysite).site_lat, $
                             (*dataStruct.mysite).site_lon, xCorner, $
                             yCorner, pr_index, nfp, ifram, $
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
