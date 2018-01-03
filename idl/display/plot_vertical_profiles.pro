PRO plot_vertical_profiles, cfile, sfile, DO_ADJ=do_adj, DO_PS=do_ps
On_IOError, IO_bailout ;  bailout if there is an error reading or writing a file

field_names = ['height','rdifcororg','rdifraworg','rdifcoradj','rdifrawadj', $
               'rdifcorraw','rrcor','rrraw','rrorg','rradj','zdifcororg','zdifcoradj', $
               'zdifraworg','zdifrawadj','zdifcorraw','zcor','zraw','zorg','zadj','n']

nfields = N_ELEMENTS( field_names )

chsiz = 1.0
fontset=-1
legspace=0.5
IF keyword_set(do_ps) THEN BEGIN
  ; generate the filename for postscript output
   dir_name = '/data/tmp'
   out_file = '/RR_profile_plot_woBB_TropZRpostAnom'
   timedate =  SYSTIME(0)
   timedate = STRMID(timedate,4,STRLEN(timedate)) ; time & date will be added to
   STRPUT, timedate, 'h', 6                       ; the output file name
   STRPUT, timedate, 'm', 9
   STRPUT, timedate, 's', 12
   STRPUT, timedate, 'y', 15
   timedate = STRCOMPRESS(timedate, /remove_all)  ; remove all blanks
   psoutfile = dir_name + out_file +'.ps' ;+ timedate + '.ps'
   entry_device = !d.name
   SET_PLOT, 'PS'
   DEVICE, /portrait, FILENAME=psoutfile, COLOR=1, BITS_PER_PIXEL=8, $
         xsize=8, ysize=4, xoffset=0.25, yoffset=0.25, /inches, /AVANTGARDE,/BOOK ;/times ;/helvetica ;,/bold
   !P.COLOR=0 ; make the title and axis annotation black
   !X.THICK=4 ; make the ticks thicker
   !Y.THICK=4 ; ditto
;   !P.FONT=0 ; use the device fonts supplied by postscript
   !P.Multi=[0,2,1,0,0]
   chsiz = 0.75
   fontset=0
   legspace=0.75
ENDIF

event_data = ''
nlevs = intarr(2)
nlevs[*] = 0
yhgt4label = findgen(11)*1.5

height=FLTARR(13,2) & rdifcororg=FLTARR(13,2) & rdifraworg=FLTARR(13,2) & rdifcoradj=FLTARR(13,2)
rdifrawadj=FLTARR(13,2) & rdifcorraw=FLTARR(13,2) & rrcor=FLTARR(13,2) & rrraw=FLTARR(13,2)
rrorg=FLTARR(13,2) & rradj=FLTARR(13,2) & zdifcororg=FLTARR(13,2) & zdifcoradj=FLTARR(13,2)
zdifraworg=FLTARR(13,2) & zdifrawadj=FLTARR(13,2) & zdifcorraw=FLTARR(13,2) & zcor=FLTARR(13,2)
zraw=FLTARR(13,2) & zorg=FLTARR(13,2) & zadj=FLTARR(13,2) & n=LONARR(13,2)

OPENR, r_lun, cfile, /GET_LUN, ERROR=err
;PRINT, 'error code', err
PRINT, ' '
PRINT, 'reading from file: ', cfile
PRINT, ' '

; read header info and un-interesting rows of the 1st record
a_line = ' '
;PRINT, 'reading header info'
;READF, r_lun, a_line ; skip the header info
;PRINT, '**header** ', a_line
WHILE (EOF(r_lun) NE 1) DO BEGIN  ; *****loop through all records*****
  READF, r_lun, event_data
  parsed = strsplit( event_data, '|', /extract )
  height[nlevs[0],0] = FLOAT(parsed[0])
  rdifcororg[nlevs[0],0] = FLOAT(parsed[1])
  rdifraworg[nlevs[0],0] = FLOAT(parsed[2])
  rdifcoradj[nlevs[0],0] = FLOAT(parsed[3])
  rdifrawadj[nlevs[0],0] = FLOAT(parsed[4])
  rdifcorraw[nlevs[0],0] = FLOAT(parsed[5])
  rrcor[nlevs[0],0] = FLOAT(parsed[6])
  rrraw[nlevs[0],0] = FLOAT(parsed[7])
  rrorg[nlevs[0],0] = FLOAT(parsed[8])
  rradj[nlevs[0],0] = FLOAT(parsed[9])
  zdifcororg[nlevs[0],0] = FLOAT(parsed[10])
  zdifcoradj[nlevs[0],0] = FLOAT(parsed[11])
  zdifraworg[nlevs[0],0] = FLOAT(parsed[12])
  zdifrawadj[nlevs[0],0] = FLOAT(parsed[13])
  zdifcorraw[nlevs[0],0] = FLOAT(parsed[14])
  zcor[nlevs[0],0] = FLOAT(parsed[15])
  zraw[nlevs[0],0] = FLOAT(parsed[16])
  zorg[nlevs[0],0] = FLOAT(parsed[17])
  zadj[nlevs[0],0] = FLOAT(parsed[18])
  n[nlevs[0],0] = LONG(parsed[19])
  nlevs[0] = nlevs[0]+1
ENDWHILE
PRINT, 'total number of Conv levels = ', nlevs[0], ' top height = ', height[nlevs[0]-1]

FREE_LUN, r_lun

IF keyword_set(do_ps) EQ 0  THEN BEGIN
   device, decomposed=0, RETAIN=2
   window, 0, xsize=500, ysize=500, $
     TITLE='Convective rainrate bias, PR/GR, derived from reflectivity.'
   thick_cor = 2 & thick_raw = 1
   line_orig = 0 & line_adj = 2
   color4orig = 255 & color4adj = 125
ENDIF ELSE BEGIN
   red = [  0, 255,   0, 255,   0, 255,   0, 255,   0, 127, 219, $
          255, 255, 112, 219, 127,   0, 255, 255,   0, 112, 219 ]
   grn = [  0,   0, 208, 255, 255,   0,   0,   0,   0, 219,   0, $
          187, 127, 219, 112, 127, 166, 171, 171, 112, 255,   0 ]
   blu = [  0, 191, 255,   0,   0,   0, 255, 171, 255, 219, 115, $
            0, 127, 147, 219, 127, 255, 127, 219,   0 ,  0, 255 ]
   tvlct, red, grn, blu, 0
   thick_cor = 6 & thick_raw = 2
   line_orig = 0 & line_adj = 2
   color4orig = 0 & color4adj = 0
ENDELSE

biascororg = rrcor[0:nlevs[0]-1,0]/rrorg[0:nlevs[0]-1,0]
biasraworg = rrraw[0:nlevs[0]-1,0]/rrorg[0:nlevs[0]-1,0]
biascoradj = rrcor[0:nlevs[0]-1,0]/rradj[0:nlevs[0]-1,0]
biasrawadj = rrraw[0:nlevs[0]-1,0]/rradj[0:nlevs[0]-1,0]
IF keyword_set(do_adj) THEN BEGIN
   biasmax = ((biascororg>biasraworg)>biascoradj)>biasrawadj
ENDIF ELSE BEGIN
   biasmax = biascororg>biasraworg
ENDELSE

PLOT, biascororg, height[0:nlevs[0]-1,0], XRANGE=[0.25,1.75], $
      YRANGE=[0.0,15.0], XSTYLE=1, ystyle = 1, xtitle='Convective Rainrate Bias, PR/GR', $
      ytickv=yhgt4label, yticks=15, yminor=0, ytitle='Height (km)', color=color4orig, $
      linestyle=line_orig, thick=thick_cor, font=fontset ;, charsize=chsiz , $
;      TITLE='Convective rainrate bias, PR/GR, derived from reflectivity.'  ;, $
OPLOT, biasraworg, height[0:nlevs[0]-1,0], thick=thick_raw, color=color4orig, $
       linestyle=line_orig

; plot the no-bias line (bias=1.0)
OPLOT, [1,1], [0.0,15.0], linestyle=1, thick=thick_adj, color=color4orig
; plot the number of points at each level just to the right of level's highest bias value
XYOUTS, biasmax+0.05, height[0:nlevs[0]-1,0], $
        '('+STRING(n[0:nlevs[0]-1,0], FORMAT='(I0)')+')', charsize=chsiz, font=fontset
; plot the legend
legstart=[14.1,14.1]
IF keyword_set(do_ps) EQ 0 THEN BEGIN
   oplot, [1.3,1.4],legstart,linestyle=line_orig, thick=thick_cor, color=color4orig
   XYOUTS, 1.42, legstart[0]-0.1, 'PRcor / GR', color=color4orig, charsize=chsiz, font=fontset
   oplot, [1.3,1.4],legstart-legspace, linestyle=line_orig, thick=thick_raw, color=color4orig
   XYOUTS, 1.42, legstart[0]-legspace-0.1, 'PRraw / GR', color=color4orig, charsize=chsiz, font=fontset
ENDIF

; plot the biases against adjusted GR, if indicated
IF keyword_set(do_adj) THEN BEGIN
   OPLOT, biascoradj, height[0:nlevs[0]-1,0], linestyle=line_adj, thick=thick_cor, color=color4adj ;125
   OPLOT, biasrawadj, height[0:nlevs[0]-1,0], linestyle=line_adj, thick=thick_raw, color=color4adj ;125
  ; plot the legend
   IF keyword_set(do_ps) EQ 0 THEN BEGIN
      oplot, [1.3,1.4],legstart-legspace*2, linestyle=line_adj, thick=thick_cor, color=color4adj ;125
      XYOUTS, 1.42, legstart[0]-legspace*2-0.1, 'PRcor / GRadj', color=color4adj, $
              charsize=chsiz, font=fontset ;, color=125
      oplot, [1.3,1.4],legstart-legspace*3, linestyle=line_adj, thick=thick_raw, color=color4adj ;125
      XYOUTS, 1.42, legstart[0]-legspace*3-0.1, 'PRraw / GRadj', color=color4adj, $
              charsize=chsiz, font=fontset ;, color=125
   ENDIF
ENDIF


OPENR, r_lun, sfile, /GET_LUN, ERROR=err
;PRINT, 'error code', err
PRINT, ' '
PRINT, 'reading from file: ', sfile
PRINT, ' '

; read header info and un-interesting rows of the 1st record
a_line = ' '
;PRINT, 'reading header info'
;READF, r_lun, a_line ; skip the header info
;PRINT, '**header** ', a_line
WHILE (EOF(r_lun) NE 1) DO BEGIN  ; *****loop through all records*****
  READF, r_lun, event_data
  parsed = strsplit( event_data, '|', /extract )
  height[nlevs[1],1] = FLOAT(parsed[0])
  rdifcororg[nlevs[1],1] = FLOAT(parsed[1])
  rdifraworg[nlevs[1],1] = FLOAT(parsed[2])
  rdifcoradj[nlevs[1],1] = FLOAT(parsed[3])
  rdifrawadj[nlevs[1],1] = FLOAT(parsed[4])
  rdifcorraw[nlevs[1],1] = FLOAT(parsed[5])
  rrcor[nlevs[1],1] = FLOAT(parsed[6])
  rrraw[nlevs[1],1] = FLOAT(parsed[7])
  rrorg[nlevs[1],1] = FLOAT(parsed[8])
  rradj[nlevs[1],1] = FLOAT(parsed[9])
  zdifcororg[nlevs[1],1] = FLOAT(parsed[10])
  zdifcoradj[nlevs[1],1] = FLOAT(parsed[11])
  zdifraworg[nlevs[1],1] = FLOAT(parsed[12])
  zdifrawadj[nlevs[1],1] = FLOAT(parsed[13])
  zdifcorraw[nlevs[1],1] = FLOAT(parsed[14])
  zcor[nlevs[1],1] = FLOAT(parsed[15])
  zraw[nlevs[1],1] = FLOAT(parsed[16])
  zorg[nlevs[1],1] = FLOAT(parsed[17])
  zadj[nlevs[1],1] = FLOAT(parsed[18])
  n[nlevs[1],1] = LONG(parsed[19])
  nlevs[1] = nlevs[1]+1
ENDWHILE
PRINT, 'total number of Strat levels = ', nlevs[1], ' top height = ', height[nlevs[1]-1]

FREE_LUN, r_lun

IF keyword_set(do_ps) EQ 0  THEN BEGIN
   device, decomposed=0, RETAIN=2
   window, 1, xsize=500, ysize=500, $
     TITLE='Stratiform rainrate bias, PR/GR, derived from reflectivity.'
ENDIF ;ELSE erase

biascororg = rrcor[0:nlevs[1]-1,1]/rrorg[0:nlevs[1]-1,1]
biasraworg = rrraw[0:nlevs[1]-1,1]/rrorg[0:nlevs[1]-1,1]
biascoradj = rrcor[0:nlevs[1]-1,1]/rradj[0:nlevs[1]-1,1]
biasrawadj = rrraw[0:nlevs[1]-1,1]/rradj[0:nlevs[1]-1,1]
IF keyword_set(do_adj) THEN BEGIN
   biasmax = ((biascororg>biasraworg)>biascoradj)>biasrawadj
ENDIF ELSE BEGIN
   biasmax = biascororg>biasraworg
ENDELSE

PLOT, biascororg, height[0:nlevs[0]-1,0], XRANGE=[0.25,1.75], $
      YRANGE=[0.0,15.0], XSTYLE=1, ystyle = 1, xtitle='Stratiform Rainrate Bias, PR/GR', $
      ytickv=yhgt4label, yticks=15, yminor=0, ytitle='Height (km)', color=color4orig, $
      linestyle=line_orig, thick=thick_cor, font=fontset ;, $
;      TITLE='Stratiform rainrate bias, PR/GR, derived from reflectivity.'  ;, $
OPLOT, biasraworg, height[0:nlevs[1]-1,0], thick=thick_raw, color=color4orig, $
       linestyle=line_orig

; plot the no-bias line (bias=1.0)
OPLOT, [1,1], [0.0,15.0], linestyle=1, thick=thick_adj, color=color4orig
; plot the number of points at each level just to the right of level's highest bias value
XYOUTS, biasmax+0.05, height[0:nlevs[1]-1,0], $
        '('+STRING(n[0:nlevs[1]-1,1], FORMAT='(I0)')+')', charsize=chsiz, font=fontset
; plot the legend
IF keyword_set(do_adj) THEN xlineends=[1.1,1.25] ELSE xlineends=[1.3,1.4]
oplot, xlineends,legstart,linestyle=line_orig, thick=thick_cor, color=color4orig
XYOUTS, xlineends[1]+0.02, legstart[0]-0.1, 'PRcor/GR', color=color4orig, charsize=chsiz, font=-1
oplot, xlineends,legstart-legspace, linestyle=line_orig, thick=thick_raw, color=color4orig
XYOUTS, xlineends[1]+0.02, legstart[0]-legspace-0.1, 'PRraw/GR', color=color4orig, charsize=chsiz, font=-1

; plot the biases against adjusted GR, if indicated
IF keyword_set(do_adj) THEN BEGIN
   OPLOT, biascoradj, height[0:nlevs[0]-1,0], linestyle=line_adj, thick=thick_cor, color=color4adj
   OPLOT, biasrawadj, height[0:nlevs[0]-1,0], linestyle=line_adj, thick=thick_raw, color=color4adj
   oplot, xlineends,legstart-legspace*2, linestyle=line_adj, thick=thick_cor, color=color4adj
   XYOUTS, xlineends[1]+0.02, legstart[0]-legspace*2-0.1, 'PRcor/GRadj', color=color4adj, $
           charsize=chsiz, font=-1
   oplot, xlineends,legstart-legspace*3, linestyle=line_adj, thick=thick_raw, color=color4adj ;125
   XYOUTS, xlineends[1]+0.02, legstart[0]-legspace*3-0.1, 'PRraw/GRadj', color=color4adj, $
           charsize=chsiz, font=-1
ENDIF

GOTO, skipto
IO_bailout: PRINT, '***** IO error encountered'
PRINT, !ERROR_STATE.MSG
PRINT, 'Error opening/reading file.  Exiting.'
GOTO, skipto
skipto: 

IF keyword_set(do_ps) THEN BEGIN
  DEVICE, /CLOSE_FILE
  SET_PLOT, entry_device
  ; try to convert it from PS to PDF, using ps2pdf utility
   if !version.OS_NAME eq 'Mac OS X' then ps_util_name = 'pstopdf' $
   else ps_util_name = 'ps2pdf'
   command1 = 'which '+ps_util_name
   spawn, command1, result, errout
   IF result NE '' THEN BEGIN
      print, 'Converting ', psoutfile, ' to PDF format.'
      command2 = ps_util_name+ ' ' + psoutfile
      spawn, command2, result, errout
      print, 'Removing Postscript version'
      command3 = 'rm -v '+psoutfile
      spawn, command3, result, errout
   ENDIF
ENDIF

end_it:
PRINT, 'finished'

END
