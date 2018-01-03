;+
; Copyright © 2014, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; animate_gpm_rainrate_bscan
;
; DESCRIPTION
; -----------
; Produces raw cartesian plot of along-swath, volume-matched DPR, COM,
; and GMI rainrate ('zdata'), in an animation window.
;
; PARAMETERS
; ----------
; dprgmi_matchup - structure containing  along-swath, volume-matched DPR, COM,
;                 and GMI rainrate fields and metadata fields
;
; precut        - binary keyword parameter, indicates whether the matchup data
;                 fields have already been pared down to the GMI footprints
;                 within the narrower DPR swath (PRECUT=1), or all the GMI
;                 footprints in the GMI swath are included in the matchup data
;                 arrays (PRECUT=0, or unset/unspecified).
;
; HISTORY
; -------
; 10/17/14  Morris/GPM GV/SAIC
; - Created from animate_rainrate_bscan.
;
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-

pro animate_gpm_rainrate_bscan, dprgmi_matchup, PRECUT=precut

precut = KEYWORD_SET( precut )

IF (precut) THEN BEGIN
   sz = SIZE(dprgmi_matchup.gmiRain)
   nscans = sz[1]
   nrays = sz[2]
   min_scan = 0
   max_scan = nscans-1
   min_ray = 0
   max_ray = nrays-1
   IF WHERE(tag_names(dprgmi_matchup) EQ 'MATCHUPMETA') NE -1 THEN BEGIN
      ; structure is from a read of the matchup netCDF file
      file2a12 = dprgmi_matchup.filesmeta.file_2agprof
      parsed = STRSPLIT(file2a12, '.', /EXTRACT)
      orbit = LONG(parsed(5))
      version = dprgmi_matchup.matchupmeta.PPS_version
   ENDIF ELSE BEGIN
      ; structure is from the matchup program
      orbit = dprgmi_matchup.orbit
      version = dprgmi_matchup.version
   ENDELSE
ENDIF ELSE BEGIN
   nscans = dprgmi_matchup.max_scan - dprgmi_matchup.min_scan + 1
   nrays = dprgmi_matchup.max_ray - dprgmi_matchup.min_ray +1
   min_scan = dprgmi_matchup.min_scan
   max_scan = dprgmi_matchup.max_scan
   min_ray = dprgmi_matchup.min_ray
   max_ray = dprgmi_matchup.max_ray
   orbit = dprgmi_matchup.orbit
   version = dprgmi_matchup.version
ENDELSE

; extract the samples in the common swath, and find the point by point max rain
; rate among GMI, DPR, and COM, within this swath
gmiRain = dprgmi_matchup.gmiRain[min_scan:max_scan, min_ray:max_ray]
prRain = dprgmi_matchup.prrain[min_scan:max_scan, min_ray:max_ray]
comRain = dprgmi_matchup.comrain[min_scan:max_scan, min_ray:max_ray]

; find the highest single rain rate value in the common swath
PRINT, "MAX RR:  GMI, DPR, COM:"
print, MAX(gmiRain), MAX(prRain), MAX(comRain)
MaxRR = MAX([MAX(gmiRain), MAX(prRain), MAX(comRain)])
;print, "Max of all: ", MaxRR

idxGMImiss = WHERE(gmiRain LT 0.0, ntmimiss)
idxPRmiss = WHERE(prRain LT 0.0, nprmiss)
idxCOMmiss = WHERE(comRain LT 0.0, ncommiss)

; scale rain rate from 0 to 250 BYTE counts, set MISSING to 255
scaleFac = 250.0/MaxRR
gmiRainImg = BYTE(gmiRain*scaleFac)
IF ntmimiss GT 0 THEN gmiRainImg[idxGMImiss] = 255b
prRainImg = BYTE(prRain*scaleFac)
IF nprmiss GT 0 THEN prRainImg[idxPRmiss] = 255b
comRainImg = BYTE(comRain*scaleFac)
IF ncommiss GT 0 THEN comRainImg[idxCOMmiss] = 255b

szorig = SIZE(gmiRainImg, /DIMENSIONS)
bigdim = szorig[0] > szorig[1]
imgscal = 800/bigdim > 1
nx = imgscal*szorig[0]
ny = imgscal*szorig[1]

gmiRainImg = REBIN(gmiRainImg, nx, ny, /SAMPLE)
device, decomposed=0
SET_PLOT, 'X'
device, decomposed=0
xinteranimate, set=[nx, ny, 4], /TRACK
WINDOW, 1, XSIZE=nx, YSIZE=ny, /pixmap
loadct,13
TV, gmiRainImg
   xinteranimate, frame = 0, window=1
;stop
prRainImg = REBIN(prRainImg, nx, ny, /SAMPLE)
TV, prRainImg
   xinteranimate, frame = 1, window=1
;stop
comRainImg = REBIN(comRainImg, nx, ny, /SAMPLE)
TV,comRainImg
   xinteranimate, frame = 2, window=1
TV, gmiRainImg
   xinteranimate, frame = 3, window=1
xinteranimate, 3, /BLOCK

;print, '' & print, "Done!"
end
