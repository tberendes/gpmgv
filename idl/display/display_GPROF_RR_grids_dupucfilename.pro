pro display_GPROF_RR_grids, FILEPATH=filepath, SITE=site, INTERACTIVE=interactive

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
   histImg = BYTSCL(RAINRATE)
   sh = SIZE(histImg, /DIMENSIONS)
   scale = 150/MAX(sh) + 1
   sh2 = sh*scale
   histImg = REBIN(histImg, sh2[0], sh2[1], /SAMPLE)
   winsiz = SIZE( histImg, /DIMENSIONS )
   histImg = CONGRID(histImg, winsiz[0]*2, winsiz[1]*2)
   winsiz = SIZE( histImg, /DIMENSIONS )
   LOADCT, 33, RGB=rgb, /SILENT 
   LOADCT, 33, /SILENT
   rgb[0,*]=255
   IF KEYWORD_SET(interactive) THEN BEGIN
      LOADCT, 33, /SILENT
      im=image(histImg, axis_style=2, xmajor=xmajor, ymajor=ymajor, xminor=4, $
               yminor=4, RGB_TABLE=rgb, BUFFER=buffer)
      haveImage=1
   ENDIF ELSE BEGIN
      device, decomposed=0
      TVLCT, rgb
      WINDOW, XSIZE=winsiz[0], YSIZE=winsiz[0]
      TV, histImg
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

