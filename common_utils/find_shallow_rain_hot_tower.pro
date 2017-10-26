;===============================================================================
;+
; Copyright © 2016, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; find_shallow_rain_hot_tower.pro    Morris/SAIC/GPM_GV    August 2016
;
; DESCRIPTION
; -----------
; Takes arrays of GR reflectivity data geometry-matched to GMI etc., top and
; bottom heights of the volumes, and the set of array indices pointing to the
; set of satellite instrument footprints under consideration, and an array of
; GR-based rain type; extracts vertical profiles of GR reflectivity for these
; footprints; and examines the vertical profiles to determine the existence of
; either points with stratiform and no more than 30 dBZ 1.5 km or more above
; the BB (shallow rain, flagged as Stratiform rain type), or convective with
; continuous 35 dBZ between the BB and 12 km (hot towers, flagged as Convective
; rain type).
;
; Locations where neither of these criteria are met are given a rain type value
; of Other.  Rain type category values are as defined in the file pr_params.inc.
;
; PARAMETERS
; ----------
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
; meanBB     - INPUT: Mean bright band height previously computed.
; rntype_in  - INPUT: Previously computed rain type category.
; singlescan - INPUT: Binary parameter, indicates whether idx_in points to rays
;              within one scan line of the TMI/PR, or to multiple scans/rays.
; verbose    - INPUT: Indicates whether and which diagnostic PRINT messages to
;              activate.
; meanBB     - INPUT: Mean bright band height previously computed.
;
; HISTORY
; -------
; 08/09/16 Morris, GPM GV, SAIC
; - Created from get_gr_geo_match_rain_type.pro
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;===============================================================================

FUNCTION find_shallow_rain_hot_tower, idx_in, gvz, top, botm, rntype_in, meanBB, $
                                      SINGLESCAN=singlescan, VERBOSE=verbose

@pr_params.inc   ; for GPM VN rain type category values

IF N_ELEMENTS( verbose ) EQ 0 THEN verbose=0   ; set to No Diagnostic Print

; figure out whether we have one scan line or multiple scan lines.  If
; multiple, then filter out any 'bogus' footprints

IF KEYWORD_SET( singlescan ) THEN BEGIN
   nfooties = N_ELEMENTS(idx_in)   ; # footprints under consideration
   idx2get = INDGEN( nfooties )    ; compute/return for all footprints
   idxscan = idx_in
   rainType = rntype_in
   rainTypeOut = MAKE_ARRAY( nfooties, /INTEGER, VALUE=RainType_no_rain )
ENDIF ELSE BEGIN
   ; May need to cut one layer out of idx_in and/or rntype_in, which may have
   ; been replicated over each sweep level
   Sidx = SIZE( idx_in )
   IF Sidx[0] EQ 2 THEN idxlevel = REFORM( idx_in[*,0] ) ELSE idxlevel = idx_in
   rainTypeOut = MAKE_ARRAY( N_ELEMENTS(idxlevel), /INTEGER, VALUE=RainType_no_rain )

   idxscan = WHERE( idxlevel GE 0 )   ; locations of non-bogus footprints
   nfooties = N_ELEMENTS(idxscan)     ; # footprints under consideration
   idx2get = idxscan                  ; compute/return for non-bogus footprints
   Sidx = SIZE( rntype_in )
  ; cut one layer out of rain type array (if needed), and subset to
  ; non-bogus footprints
   IF Sidx[0] EQ 2 THEN rainType = REFORM(rntype_in[idxscan,0]) $
      ELSE rainType = rntype_in[idxscan]
;   pridxscanray = idxlevel[idxscan]   ; pr_index or tmi_index values for above
ENDELSE

S = SIZE(gvz, /DIMENSIONS)
nvols = S[1]

; initialize the array of GR rain regimes to be computed
grRainType = MAKE_ARRAY( nfooties, /INTEGER, VALUE=RainType_no_rain )
; and an array of reflectivity found
BB_Z_ByRay = FLTARR(nfooties)

; cut out GR reflectivity and sample height for our subset of footprints
gvzprofiles = gvz[idxscan, *]
hgtprofiles = (top[idxscan, *] + botm[idxscan, *]) / 2
botmprofiles = botm[idxscan, *]

FOR ifoot = 0, nfooties-1 DO BEGIN

;   IF verbose GT 0 THEN $
;      print, "===================== RAY ", STRING(ifoot+1, FORMAT='(I0)'), " ====================="
  ; grab the individual profile at the footprint
   gvprofile_all=REFORM(gvzprofiles[ifoot,*])
   hgtprofile_all=REFORM(hgtprofiles[ifoot,*])
   botmprofile_all=REFORM(botmprofiles[ifoot,*])

  ; compute max height of the samples, so that we can skip column
  ; locations where no data exist above the bright band layer
   IF MAX(botmprofile_all) LT (meanBB+0.5) THEN CONTINUE

  ; do we have any actual reflectivity values in this profile?  If so, grab just
  ; these samples for evaluation
   idxactual = WHERE(gvprofile_all GT 10.0, countactual)
   IF (countactual LT 2) THEN BEGIN
      IF verbose GT 0 THEN message, STRING(countactual, FORMAT='(I0)')+ $
                             " gvz values > 10 dBZ in ray "+ $
                             STRING(ifoot+1, FORMAT='(I0)')+", skipping.", /INFO
      CONTINUE   ; leave profile as No Rain, skip to next ray
   ENDIF ELSE BEGIN
      gvprofile = gvprofile_all[idxactual]
      hgtprofile = hgtprofile_all[idxactual]
      botmprofile = botmprofile_all[idxactual]
   ENDELSE

  ; look for the 35 dBZ convective from BB to 12 km cases
   idxbb12 = WHERE(hgtprofile GE meanBB AND hgtprofile LE 12.0, nbb12)
   IF nbb12 GT 0 AND MAX(hgtprofile) GE 12.0 THEN BEGIN
     ; if any samples in the BB-to-12-km layer are below 35 dBZ then it's not
     ; a "hot tower", skip this profile.  Otherwise flag it in the grRainType
     ; array as RainType_convective (2)
      idx35z = WHERE(gvprofile[idxbb12] LT 35.0, n2low)
      IF n2low EQ 0 THEN BEGIN
         grRainType[ifoot] = RainType_convective
         IF verbose GT 0 THEN print, "Convective 35 dBZ from BB to 12 km, RAY ", $
                                     STRING(ifoot+1, FORMAT='(I0)')
         CONTINUE   ; skip to next ray
      ENDIF
   ENDIF


  ; look for the stratiform / under 30 dBZ above 1.5 km above BB
   IF rainType[ifoot] EQ RainType_stratiform THEN BEGIN
      idxabv = WHERE(hgtprofile GE (meanBB+1.5), nabv)
      IF nabv GT 0 THEN BEGIN
         IF MAX(gvprofile[idxabv]) LE 30.0 THEN BEGIN
            grRainType[ifoot] = RainType_stratiform
            IF verbose GT 0 THEN print, "Stratiform >= 1.5 km above BB < 30 dBZ, RAY ", $
                                        STRING(ifoot+1, FORMAT='(I0)')
         ENDIF
      ENDIF ELSE BEGIN
        ; if >10 dBZ layer reaches the BB and is less than 30 dBZ at the top,
        ; also flag this as shallow convective
         IF hgtprofile[countactual-1] GE meanBB $
         AND gvprofile[countactual-1] LE 30.0 THEN BEGIN
            grRainType[ifoot] = RainType_stratiform
            IF verbose GT 0 THEN print, "Stratiform at BB < 30 dBZ, RAY ", $
                                        STRING(ifoot+1, FORMAT='(I0)')
         ENDIF ELSE IF verbose GT 0 THEN $
                       print, "No stratiform samples >= 1.5 km above BB, RAY ", $
                              STRING(ifoot+1, FORMAT='(I0)')
      ENDELSE
   ENDIF

ENDFOR

rainTypeOut[idx2get] = grRainType
RETURN, rainTypeOut
END
