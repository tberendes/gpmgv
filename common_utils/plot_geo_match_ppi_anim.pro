PRO plot_geo_match_ppi_anim, field_ids, field_data, common_data, source_ids

IF ( common_data.nframes EQ 0 ) THEN GOTO, nextFile
do_pixmap=0
IF ( common_data.nframes GT 1 ) THEN BEGIN
   do_pixmap=1
   retain = 0
ENDIF ELSE retain = 2
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

window, 2, xsize=xsize*nx, ysize=ysize*ny, xpos = 75, TITLE = title, $
        PIXMAP=do_pixmap, RETAIN=retain

; instantiate animation widget, if multiple PPIs
IF common_data.nframes GT 1 THEN $
   xinteranimate, set=[xsize*nx, ysize*ny, common_data.nframes], /TRACK

error = 0
loadcolortable, 'CZ', error
if error then begin
    print, ''
    print, "In geo_match_z_plots: error from loadcolortable"
    something = ""
    READ, something, PROMPT='Hit Return to proceed to next case, Q to Quit: '
    goto, errorExit2
endif

IF common_data.pctString EQ '0' THEN epilogue = "all valid samples" $
ELSE epilogue = '!m'+STRING("142B)+common_data.pctString+"% of PR/GR bins above threshold"

FOR ifram=0,common_data.nframes-1 DO BEGIN
   orig_device = !D.NAME
   elevstr =  string(common_data.mysweeps[ifram+common_data.startelev].elevationAngle, FORMAT='(f0.1)')
   FOR ippi = 0, nx*ny-1 DO BEGIN
      ppiTitle = source_IDs[ippi]+" "+field_ids[ippi]+", for "+epilogue
      buf = plot_sweep_2_zbuf( *(field_data[ippi]), common_data.site_lat, $
                               common_data.site_lon, common_data.xCorner, $
                               common_data.yCorner, common_data.pr_index, $
                               common_data.mygeometa.num_footprints, $
                               ifram+common_data.startelev, common_data.rntype4ppi, $
                               WINSIZ=common_data.winSize, TITLE=ppiTitle, FIELD=field_ids[ippi] )
      SET_PLOT, 'X'
      device, decomposed=0
      TV, buf, ippi
      SET_PLOT, orig_device
   ENDFOR
   IF common_data.nframes GT 1 THEN xinteranimate, frame = ifram, window=2
ENDFOR

IF common_data.nframes GT 1 THEN BEGIN
   print, ''
   print, 'Click END ANIMATION button or close Animation window to proceed to next case:
   xinteranimate, common_data.looprate, /BLOCK
ENDIF

nextFile:
errorExit2:

END
