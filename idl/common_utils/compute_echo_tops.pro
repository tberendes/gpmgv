;===============================================================================
;+
; Copyright © 2016, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; compute_echo_tops.pro    Morris/SAIC/GPM_GV    September 2016
;
; DESCRIPTION
; -----------
; Takes arrays of GR reflectivity data geometry-matched to GMI etc., top and
; bottom heights of the volumes, and the set of array indices pointing to the
; set of satellite instrument footprints under consideration, an optional array
; of GPROF-based rain rate, and a reflectivity threshold defining the top of
; the storm; and examines the vertical profiles to determine the existence of
; the maximum echo top height where reflectivity finally falls below the 
; reflectivity threshold.  If the rain rate parameter is defined, then only
; columns where the GPROF rain rate is above 0.1 mm/h are considered.  Otherwise
; the echo tops are computed for all columns with at least one sample above the
; echo top reflectivity threshold.
;
; Locations where neither of these criteria are met are given an echo top value
; of 0.0.
;
; PARAMETERS
; ----------
; et_dbz     - INPUT: Reflectivity threshold defining the level of the echo top.
; idx_in     - INPUT: Indices into one level of the gvz, top, and botm arrays
;              indicating the points to be evaluated.  If SINGLESCAN is set,
;              then idx_in are the indices of one scan line of data.  If
;              SINGLESCAN is unset, then idx_in are the indices relative to the
;              full TMI or PR product, in terms of 1-D IDL indices of the full
;              2-D product array in the TRMM file in ray/scan coordinates (i.e.,
;              it is the pr_index or tmi_index variable from the matchup file.
; gvz        - INPUT: 2-D array of volume-matched Ground Radar reflectivity array
;              for each GR sweep level, averaged over the area of each PR or TMI
;              footprint.
; top        - INPUT: Top height of each sample in the gvz array, in km.
; bottom     - INPUT: Bottom height of each sample in the gvz array, in km.
; meanBB     - INPUT: Mean height of the bright band in the analysis area
; rnrate_in  - INPUT: Optional GPROF surface rain rate estimate of each sample
;              in the gvz array, replicated for each sample in the column.
;
; HISTORY
; -------
; 09/16/16 Morris, GPM GV, SAIC
; - Created from find_shallow_rain_hot_tower.pro
; 09/22/16 Morris, GPM GV, SAIC
; - Made rainrate an optional parameter.
;
; EMAIL QUESTIONS OR COMMENTS AT:
;       https://pmm.nasa.gov/contact
;-
;===============================================================================

FUNCTION compute_echo_tops, et_dbz, idx_in, gvz, top, botm, meanBB, $
                            RAINRATE=rnrate_in, VERBOSE=verbose

@pr_params.inc   ; for Z_BELOW_THRESH value

IF N_ELEMENTS( verbose ) EQ 0 THEN verbose=0   ; set to No Diagnostic Print

; May need to cut one layer out of idx_in and/or rnrate_in, which may have
; been replicated over each sweep level (i.e., if they are 2-D arrays)
Sidx = SIZE( idx_in )
IF Sidx[0] EQ 2 THEN idxlevel = REFORM( idx_in[*,0] ) ELSE idxlevel = idx_in

; initialize the returned array of echo top height
echoTopsOut = MAKE_ARRAY( N_ELEMENTS(idxlevel), /FLOAT, VALUE=Z_BELOW_THRESH )

; first filter out any 'bogus' footprints

idx2do = WHERE( idxlevel GE 0 )   ; locations of non-bogus footprints
nfooties = N_ELEMENTS(idx2do)     ; # footprints under consideration
;idx2do = idx2do                  ; compute/return for non-bogus footprints

IF N_ELEMENTS( rnrate_in ) NE 0 THEN BEGIN
   Sidx = SIZE( rnrate_in )
  ; cut one layer out of rain rate array (if needed), and subset to
  ; non-bogus footprints
   IF Sidx[0] EQ 2 THEN rainRate = REFORM(rnrate_in[idx2do,0]) $
      ELSE rainRate = rnrate_in[idx2do]
ENDIF

S = SIZE(gvz, /DIMENSIONS)
nvols = S[1]

; initialize the internal array of GR echo tops to be computed
grEchoTops = MAKE_ARRAY( nfooties, /FLOAT, VALUE=Z_BELOW_THRESH )

; cut out GR reflectivity and sample height for our subset of footprints
gvzprofiles = gvz[idx2do, *]
hgtprofiles = (top[idx2do, *] + botm[idx2do, *]) / 2
botmprofiles = botm[idx2do, *]

; compute a mean gradiant of reflectivity above the mean BB level (if defined)
; using all samples with valid Z.  Require at least 25 samples above the
; meanBB height for the gradient computation
haveMeanGrad=0  ; initialize flag assuming we couldn't compute mean gradient
IF meanBB GT 0.0 THEN BEGIN
   idx4grad = WHERE(hgtprofiles GT meanBB AND gvzprofiles GT 0.0, n4grad)
   IF n4grad GT 25 THEN BEGIN
      meanZgradFit = LINFIT(gvzprofiles[idx4grad], hgtprofiles[idx4grad])
      yinterceptMean = meanZgradFit[0]
      slopeMean = meanZgradFit[1]
      haveMeanGrad=1  ; reset flag to indicate we have mean gradient
      IF (verbose) THEN print, "Mean slope, intercept above BB: ", slopeMean, yinterceptMean
   ENDIF ELSE IF (verbose) THEN print, "Too few samples for gradient."
ENDIF ELSE IF (verbose) THEN print, "Mean BB undefined, cannot compute gradient."

FOR ifoot = 0, nfooties-1 DO BEGIN
  ; grab the individual profile at the footprint
   gvprofile_all=REFORM(gvzprofiles[ifoot,*])
   hgtprofile_all=REFORM(hgtprofiles[ifoot,*])
   botmprofile_all=REFORM(botmprofiles[ifoot,*])
  ; generate indices of the samples in this profile for later use
   idxProfileAll = INDGEN(nvols)

   IF N_ELEMENTS( rainRate ) NE 0 THEN BEGIN
     ; skip column locations where no significant rain is detected
      IF rainRate[idx2do[ifoot]] LT 0.1 THEN BEGIN
         IF (verbose) THEN BEGIN
            maxznorain = MAX(gvprofile_all, idxmaxz)
            IF maxznorain GT 0.0 THEN PRINT, "No rain in column with max Z = ", $
               maxznorain, " at height ", hgtprofile_all[idxmaxz]
         ENDIF
         CONTINUE
      ENDIF
   ENDIF

  ; Are there any reflectivity values at/above ET threshold in this profile?
   idxInCloud = WHERE(gvprofile_all GE et_dbz, countactual)
   IF (countactual EQ 0) THEN BEGIN
      IF verbose GT 0 THEN message, STRING(countactual, FORMAT='(I0)')+ $
                             " gvz values > ET_dBZ in footprint "+ $
                             STRING(ifoot+1, FORMAT='(I0)')+", skipping.", /INFO
      CONTINUE   ; leave profile as no ET height, skip to next ray
   ENDIF ELSE BEGIN
     ; find the highest sample with reflectivity at/above ET threshold, this
     ; will be the minimum possible value for the ET height computed from this
     ; profile
      et_min = MAX(hgtprofile_all[idxInCloud], idxMinET)
      Z_bottom = gvprofile_all[idxInCloud[idxMinET]]

     ; see whether there are any Z values above 0.0 but below threshold above
     ; the et_min level.  If so, then just linearly interpolate between the
     ; sample with the greatest Z value in this below threshold layer and the
     ; highest sample at/above threshold
      IF idxInCloud[idxMinET] LT (nvols-1) THEN BEGIN
        ; there are height levels above et_min level, see if any are above 0.0 dBZ
         idxAbv = idxProfileAll[ (idxInCloud[idxMinET]+1) : (nvols-1)]
         idxAbv2things = WHERE( gvprofile_all[idxAbv] GT 0.0, countAbv2 )
         IF countAbv2 GT 0 THEN BEGIN
           ; fit a line in (dBZ,height) space between the et_min height and the
           ; level of max Z found in the below-threshold layer above that level
            MaxZabv = MAX( gvprofile_all[idxAbv[idxAbv2things]], idxMaxZabv )
            hgtMaxZabv = hgtprofile_all[idxAbv[idxAbv2things[idxMaxZabv]]]
            slope = FLOAT(hgtMaxZabv-et_min)/(MaxZabv-Z_bottom)
            yintercept = hgtMaxZabv - slope*MaxZabv
            grEchoTops[ifoot] = slope*ET_dBZ + yintercept
            IF (verbose) THEN print, "slope above, intercept, grEchoTops: ", $
                                      slope, yintercept, grEchoTops[ifoot]
         ENDIF ELSE BEGIN
           ; use the mean gradient, if defined, to compute the ET height
            IF haveMeanGrad THEN BEGIN
               grEchoTops[ifoot] = ET_Min + slopeMean*(ET_dBZ-Z_bottom)
            IF (verbose) THEN print, "ET_Min, Z_bottom, grEchoTops from mean slope: ", $
                                      ET_Min, Z_bottom, grEchoTops[ifoot]
            ENDIF ELSE BEGIN
              ; Don't have a mean gradient and can't fit a line to points above
              ; et_min, so see whether we can compute the gradient of reflectivity
              ; at lower levels between the level of the max Z in the profile
              ; and the et_min level
               idxbelow = idxProfileAll[idxInCloud[0] : idxInCloud[idxMinET]]
               maxZbelow = MAX(gvprofile_all[idxbelow], idxmaxZbelow)
               hgtMaxZbelow = hgtprofile_all[idxbelow[idxMaxZbelow]]
               IF maxZbelow GT Z_bottom AND et_min GT hgtMaxZbelow THEN BEGIN
                 ; Z drops off with height, compute gradient and height of threshold Z
                  slope = FLOAT(et_min-hgtMaxZbelow)/(Z_bottom-MaxZbelow)
                  yintercept = et_min - slope*Z_bottom
                  grEchoTops[ifoot] = slope*ET_dBZ + yintercept
                  IF (verbose) THEN print, "slope below, intercept, grEchoTops: ", $
                                            slope, intercept, grEchoTops[ifoot]
               ENDIF ELSE BEGIN
              ; only one sample has Z at/above threshold, and we don't have a
              ; mean gradient to extrapolate to height of threshold Z.  Punt.
                  IF (verbose) THEN print, "Punted."
                  CONTINUE
               ENDELSE
            ENDELSE
         ENDELSE
      ENDIF ELSE BEGIN    ; for idxInCloud[idxMinET] LT (nvols-1)
        ; the highest valid point in the profile is at/above the threshold
        ; and there are no valid samples above it.  If available, use the mean
        ; gradient of Z to compute the echo top height at ET_dBZ
         IF haveMeanGrad THEN BEGIN
            grEchoTops[ifoot] = ET_Min + slopeMean*(ET_dBZ-Z_bottom)
            IF (verbose) THEN print, "ET_Min, Z_bottom, grEchoTops from mean slope: ", $
                                      ET_Min, Z_bottom, grEchoTops[ifoot]
         ENDIF ELSE BEGIN
            IF (verbose) THEN print, "Punted again."
            CONTINUE
         ENDELSE
      ENDELSE    ; for idxInCloud[idxMinET] LT (nvols-1)
   ENDELSE       ; for (countactual EQ 0)

ENDFOR

echoTopsOut[idx2do] = grEchoTops
RETURN, echoTopsOut
END
