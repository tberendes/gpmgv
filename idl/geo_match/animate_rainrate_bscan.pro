;+
; Copyright © 2012, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; plot_rainrate_swath.pro
;
; DESCRIPTION
; -----------
; Produces raw cartesian plot of along-swath, volume-matched PR, COM,
; and TMI rainrate ('zdata'), in an animation window.
;
; PARAMETERS
; ----------
; tmipr_matchup - structure containing  along-swath, volume-matched PR, COM,
;                 and TMI rainrate fields and metadata fields
;
; precut        - binary keyword parameter, indicates whether the matchup data
;                 fields have already been pared down to the TMI footprints
;                 within the narrower PR swath (PRECUT=1), or all the TMI
;                 footprints in the TMI swath are included in the matchup data
;                 arrays (PRECUT=0, or unset/unspecified).
;
; HISTORY
; -------
; 12/12/12  Morris/GPM GV/SAIC
; - Created.
; 03/28/13  Morris/GPM GV/SAIC
; - Added logic to handle precut structure values received from updated matchup
;   routine.
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-

pro animate_rainrate_bscan, tmipr_matchup, PRECUT=precut

precut = KEYWORD_SET( precut )

IF (precut) THEN BEGIN
   sz = SIZE(tmipr_matchup.tmirain)
   nscans = sz[1]
   nrays = sz[2]
   min_scan = 0
   max_scan = nscans-1
   min_ray = 0
   max_ray = nrays-1
   IF WHERE(tag_names(tmipr_matchup) EQ 'MATCHUPMETA') NE -1 THEN BEGIN
      ; structure is from a read of the matchup netCDF file
      file2a12 = tmipr_matchup.filesmeta.file_2a12
      parsed = STRSPLIT(file2a12, '.', /EXTRACT)
      orbit = LONG(parsed(2))
      version = tmipr_matchup.matchupmeta.TRMM_version
   ENDIF ELSE BEGIN
      ; structure is from the matchup program
      orbit = tmipr_matchup.orbit
      version = tmipr_matchup.version
   ENDELSE
ENDIF ELSE BEGIN
   nscans = tmipr_matchup.max_scan - tmipr_matchup.min_scan + 1
   nrays = tmipr_matchup.max_ray - tmipr_matchup.min_ray +1
   min_scan = tmipr_matchup.min_scan
   max_scan = tmipr_matchup.max_scan
   min_ray = tmipr_matchup.min_ray
   max_ray = tmipr_matchup.max_ray
   orbit = tmipr_matchup.orbit
   version = tmipr_matchup.version
ENDELSE

; extract the samples in the common swath, and find the point by point max rain
; rate among TMI, PR, and COM, within this swath
tmiRain = tmipr_matchup.tmirain[min_scan:max_scan, min_ray:max_ray]
prRain = tmipr_matchup.prrain[min_scan:max_scan, min_ray:max_ray]
comRain = tmipr_matchup.comrain[min_scan:max_scan, min_ray:max_ray]

; find the highest single rain rate value in the common swath
PRINT, "MAX RR:  TMI, PR, COM:"
print, MAX(tmiRain), MAX(prRain), MAX(comRain)
MaxRR = MAX([MAX(tmiRain), MAX(prRain), MAX(comRain)])
;print, "Max of all: ", MaxRR

idxTMImiss = WHERE(tmiRain LT 0.0, ntmimiss)
idxPRmiss = WHERE(prRain LT 0.0, nprmiss)
idxCOMmiss = WHERE(comRain LT 0.0, ncommiss)

; scale rain rate from 0 to 250 BYTE counts, set MISSING to 255
scaleFac = 250.0/MaxRR
tmiRainImg = BYTE(tmiRain*scaleFac)
IF ntmimiss GT 0 THEN tmiRainImg[idxTMImiss] = 255b
prRainImg = BYTE(prRain*scaleFac)
IF nprmiss GT 0 THEN prRainImg[idxPRmiss] = 255b
comRainImg = BYTE(comRain*scaleFac)
IF ncommiss GT 0 THEN comRainImg[idxCOMmiss] = 255b

szorig = SIZE(tmiRainImg, /DIMENSIONS)
bigdim = szorig[0] > szorig[1]
imgscal = 800/bigdim > 1
nx = imgscal*szorig[0]
ny = imgscal*szorig[1]

tmiRainImg = REBIN(tmiRainImg, nx, ny, /SAMPLE)
device, decomposed=0
SET_PLOT, 'X'
device, decomposed=0
xinteranimate, set=[nx, ny, 4], /TRACK
WINDOW, 1, XSIZE=nx, YSIZE=ny, /pixmap
loadct,13
TV, tmiRainImg
   xinteranimate, frame = 0, window=1
;stop
prRainImg = REBIN(prRainImg, nx, ny, /SAMPLE)
TV, prRainImg
   xinteranimate, frame = 1, window=1
;stop
comRainImg = REBIN(comRainImg, nx, ny, /SAMPLE)
TV,comRainImg
   xinteranimate, frame = 2, window=1
TV, tmiRainImg
   xinteranimate, frame = 3, window=1
xinteranimate, 3, /BLOCK

;print, '' & print, "Done!"
end
