pro display_gprof_rr_grids, FILEPATH=filepath, SITE=site, MAX_DIST=max_dist, $
                            INTERACTIVE=interactive

; Reads gridded GPROF rainrate arrays stored in IDL Save files and plots the
; rainrate field as an image.  If INTERACTIVE is set then the IDL IMAGE
; object function is used to plot the image.  Otherwise the IDL Direct Graphics
; procedure TV is used to plot the image in an IDL WINDOW.

if n_elements(filepath) eq 0 then path = '.' else path=filepath
if n_elements(site) eq 0 then filters = 'RRgrid.*.sav' $
else filters = 'RRgrid.*.'+site+'*.sav'

doodah = 'doodah'
haveImage=0

WHILE (STRUPCASE(doodah) NE 'Q') DO BEGIN

   rr_grid_file=dialog_pickfile(FILTER=filters, $
                                TITLE='Select RRgrid file to read', $
                                PATH=path)

   IF (rr_grid_file EQ '') THEN BREAK


;restore, file='/data/tmp/RRgrid.GPM.GMI.KWAJ.20150307.005796.ITE111.sav'

   restore, file=rr_grid_file
   PRINT, "Plotting from ", rr_grid_file
   IF N_ELEMENTS(max_dist) EQ 1 THEN BEGIN
      idx2blank = WHERE(dist GT max_dist, count2blank)
      IF count2blank GT 0 THEN RAINRATE[idx2blank] = 0.0
   ENDIF
   maxrr = MAX(RAINRATE, MIN=minrr)
   meanrr = MEAN(RAINRATE)
   PRINT, "Mean, Max, Min GPROF RR: ", meanrr, maxrr, minrr
   CASE 1 OF
                        maxrr LT 10. : scale = 25
       maxrr GE 10. and maxrr LT 25. : scale = 10
       maxrr GE 25. and maxrr LT 50. : scale = 5
                        maxrr GE 50. : scale = 1
                                ELSE : scale = 1
   ENDCASE
   histImg = BYTE(RAINRATE) ;*scale)
   sh = SIZE(histImg, /DIMENSIONS)
   scale = 150/MAX(sh) + 1
   sh2 = sh*scale
;   histImg = REBIN(histImg, sh2[0], sh2[1], /SAMPLE)
;   winsiz = SIZE( histImg, /DIMENSIONS )
;   histImg = CONGRID(histImg, winsiz[0]*2, winsiz[1]*2)
   histImg = CONGRID(histImg, sh2[0]*2, sh2[1]*2, /CENTER)
   winsiz = SIZE( histImg, /DIMENSIONS )
   LOADCT, 33, RGB=rgb, /SILENT 
   LOADCT, 33, /SILENT
   rgb[0,*]=255
;   loadcolortable, 'RR'
   IF KEYWORD_SET(interactive) THEN BEGIN
      LOADCT, 33, /SILENT
      im=image(histImg, axis_style=2, xmajor=xmajor, ymajor=ymajor, xminor=4, $
               yminor=4, RGB_TABLE=rgb, BUFFER=buffer, TITLE=FILE_BASENAME(rr_grid_file))
      haveImage=1
   ENDIF ELSE BEGIN
      forward_function mapcolors
      device, decomposed=0
      loadcolortable, 'RR'
      RR_Img = mapcolors(histImg, 'RR')
;      TVLCT, rgb
      WINDOW, XSIZE=winsiz[0], YSIZE=winsiz[0], TITLE=FILE_BASENAME(rr_grid_file)
      TV, RR_Img
      haveImage=2
   ENDELSE

   ;doodah = 'doodah'
   READ, doodah, PROMPT='Hit Return to do next case, Q to Quit: '
   ;IF doodah EQ 'Q' OR doodah EQ 'q' THEN break

   CASE haveImage OF
       1 : im.close
       2 : wdelete
    ELSE : 
   ENDCASE

ENDWHILE

END

