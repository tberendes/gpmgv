;===============================================================================
;+
; Copyright © 2014, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; plot_geo_match_ppi_anim_ps.pro      - Morris/SAIC/GPM_GV  February 2014
;
; DESCRIPTION
; -----------
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
; step_in       - Flag and Rate value to toggle and control the alternative
;                 method of animation of PPI images.  If unset, animation is
;                 automated in an XINTERANIMATE window (default, legacy
;                 behavior).  If set to a non-zero value, then the PPI images
;                 will be stepped through under user control: either one at a
;                 time in forward or reverse, or in an automatic forward
;                 sequence where the pause, in seconds, between frames is
;                 defined by the step_manual value.  The automated sequence
;                 will only play one time in the latter mode, starting from
;                 the currently-displayed frame.
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

PRO plot_geo_match_ppi_anim_ps, field_ids, source_ids, field_data,    $
                                thresholded, common_data, DO_PS=do_ps,    $
                                SHOW_PPIS=show_ppis_in, STEP_MANUAL=step_in

plot2ps = KEYWORD_SET(do_ps)
show_ppis = KEYWORD_SET(show_ppis_in)
; if STEP value is set, then animate "manually" unless doing postscript
step=0
IF KEYWORD_SET(step_in) THEN BEGIN
   IF plot2ps THEN $
      print, "Disabling the manual-step animation for Postscript output mode." $
   ELSE step=step_in
ENDIF

IF ( common_data.nframes EQ 0 ) THEN GOTO, doNothing
do_pixmap=0
askagain=1
IF ( common_data.nframes GT 1 ) AND ( step EQ 0 ) THEN BEGIN
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

; only need this window if not in batch mode
IF ( show_ppis ) THEN window, 2, xsize=xsize*nx, ysize=ysize*ny, xpos = 75, $
                              TITLE = common_data.wintitle, PIXMAP=do_pixmap, RETAIN=retain

; instantiate animation widget, if multiple PPIs
IF common_data.nframes GT 1 AND show_ppis AND step EQ 0 THEN $
   xinteranimate, set=[xsize*nx, ysize*ny, common_data.nframes], /TRACK, $
                  TITLE = common_data.winTitle

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

FOR ifram=0,common_data.nframes-1 DO BEGIN
   orig_device = !D.NAME
   elevstr = string(common_data.mysweeps[ifram+common_data.startelev].elevationAngle, $
                    FORMAT='(f0.1)')
   FOR ippi = 0, nx*ny-1 DO BEGIN
      IF thresholded[ippi] THEN epilogue = elevstr+'!m'+STRING(37B)+" sweep, " $
         + '!m'+STRING("142B) + common_data.pctString+"% bins above threshold" $
      ELSE epilogue = elevstr+'!m'+STRING(37B)+" sweep, "+"all valid samples"
      ppiTitle = source_IDs[ippi]+" "+field_ids[ippi]+", "+epilogue
      buf = plot_sweep_2_zbuf( *(field_data[ippi]), common_data.site_lat, $
                               common_data.site_lon, common_data.xCorner, $
                               common_data.yCorner, common_data.pr_index, $
                               common_data.num_footprints, $
                               ifram+common_data.startelev, $
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
   IF common_data.nframes GT 1 AND show_ppis THEN BEGIN
      IF step GT 0 THEN BEGIN
         IF askagain THEN BEGIN
            wacca=''
            print, string(7B)   ; ring the bell/beep
            PRINT, ''
            PRINT, 'Enter B to step Back one frame,'
            PRINT, 'Hit Enter to show next frame,'
            PRINT, 'Enter A to step through All frames without prompt,'
            READ, wacca, PROMPT='or Enter Q to Quit: '
            CASE STRUPCASE(wacca) OF
               'Q' : goto, nomore
               'B' : BEGIN
                       IF ifram GT 0 THEN BEGIN
                          print, "Stepping to previous frame."
                          ifram = (ifram-2) > (-1)
                       ENDIF ELSE print, "Already at first frame, stepping to next."
                     END
               'A' : askAgain = 0
              ELSE : print, "Stepping to next frame."
            ENDCASE
         ENDIF ELSE WAIT, step
      ENDIF ELSE BEGIN
         xinteranimate, frame = ifram, window=2
      ENDELSE
   ENDIF
ENDFOR

nomore:

IF common_data.nframes GT 1 AND show_ppis THEN BEGIN
   IF step EQ 0 THEN BEGIN
      print, ''
      print, 'Click END ANIMATION button or close Animation window to proceed to next case:
      xinteranimate, common_data.looprate, /BLOCK
   ENDIF ELSE BEGIN
      print, "PPI sequence complete, proceeding to next case."
      print, string(7B)   ; ring the bell/beep
   ENDELSE
ENDIF

doNothing:

END
