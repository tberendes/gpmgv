;+
; Copyright © 2008, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; loop_pr_gv_gvpolar_ppis.pro    Bob Morris (SAIC)    April 2009
;
; Produces animation loop of PPI plot of PR and GV reflectivity 'zdata' for the
; number of elevation angles specified in elevs2show.  Interleaves a full
; resolution ground radar (GV) PPI of data from the radar UF file with
; volume-matched PR and GV data from a geo_match netCDF file if UF data are
; available, otherwise only the PR and GV geo_match PPIs are included.
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;===============================================================================

FUNCTION loop_pr_gv_optgvpolar_ppis, ncfilepr, gv_base_dir, looprate, elevs2show

; "Include" files for names, paths, structure definitions, etc.:
@geo_match_nc_structs.inc

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
  pr_index=lonarr(nfp)

  status = read_geo_match_netcdf( ncfile1,  dbzgv=gvz, dbzcor=zcor, $
                                  dbzraw=zraw, xCorners=xCorner, $
                                  yCorners=yCorner, pridx_long=pr_index )

  command3 = "rm -v " + ncfile1
  spawn, command3
endif else begin
  print, 'Cannot copy/unzip netCDF file: ', ncfilepr
  print, cpstatus
  command3 = "rm -v " + ncfile1
  spawn, command3
  goto, errorExit
endelse

prtime = mygeometa.timeNearestApproach
gvbegin = mysweeps[0].atimeSweepStart
print, "GV begin time = ",  gvbegin

have_uf = 0
uf_file = get_uf_pathname(ncfilepr, gvbegin, gv_base_dir)

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
   z_vol_num = get_site_specific_z_volume( mysite.site_id, radar, gv_z_field )
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
   nframes = elevs2show<mygeometa.num_sweeps
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

   ;FOR ifram=0,1 DO BEGIN
   FOR ifram=0,nframes-1 DO BEGIN
      gvtime = mysweeps[ifram].timeSweepStart
      tdiff = FIX(prtime-gvtime) & tdiffstr = STRING(ABS(tdiff), FORMAT='(I0)')
      IF ( tdiff LE 0 ) THEN BEGIN
      timestr = ", " + tdiffstr + " seconds after PR"
      ENDIF ELSE BEGIN
      timestr = ", " + tdiffstr + " seconds before PR"
      ENDELSE
      print, ""
      ;print, "Time difference (sec), PR-GV: ", tdiffstr
      ;print, ""
      elevstr =  string(mysweeps[ifram].elevationAngle, FORMAT='(f0.1)')
      prtitle = "PR for "+elevstr+" degree sweep"
      myprbuf = plot_sweep_2_zbuf( zcor, mysite.site_lat, mysite.site_lon, xCorner, $
                             yCorner, pr_index, mygeometa.num_footprints, ifram, $
                             WINSIZ=windowsize, TITLE=prtitle )
      gvtitle = mysite.site_ID+" GV for "+elevstr+" degree sweep"+timestr
      mygvbuf = plot_sweep_2_zbuf( gvz, mysite.site_lat, mysite.site_lon, xCorner, $
                             yCorner, pr_index, mygeometa.num_footprints, ifram, $
                             WINSIZ=windowsize, TITLE=gvtitle )
   IF (have_uf EQ 1) THEN BEGIN
      if size(zvolume,/n_dimensions) gt 0 then $
	  sweep = rsl_get_sweep(zvolume,mysweeps[ifram].elevationAngle ) $
      else begin
          print, 'Cannot find sweep ', ifram, ' in UF file, skipping sweep.'
	  goto, errorExit
      endelse
      if size(sweep,/n_dimensions) gt 0 then $
	  mygvbufhi = rsl_plotsweep2pixmap( sweep, radar.h, WINDOWSIZE=windowsize, _EXTRA=keywords) $
      else begin
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
   print, 'Click END ANIMATION button or close Animation window to proceed to next case:
   print, ''
   xinteranimate, looprate, /BLOCK

errorExit:
return,0
end
