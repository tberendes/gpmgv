;===============================================================================
;+
; Copyright © 2015, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; prep_blockage_parms.pro           Morris/SAIC/GPM_GV      Nov 2015
;
; DESCRIPTION
; -----------
; Program to read and prepare ground radar beam blockage variables needed to
; compute mean GR beam blockage along a given sweep elevation.  Site- and
; elevation-specific beam blockage data are located in IDL SAVE files in a
; set of saved variables: site, elev, azimuths, ranges_out, blockage_out.
; Returns a structure with status variables, and, if indicated by the status,
; preprocessed arrays of beam blockage and x- and y-coordinate data for the
; blockage gates (1-deg. by 1-km polar data for 0-359 degrees and 1-230 km).
;
; Logic rules:
;
; - The 'do_this_elev_blockage' flag indicates to the caller that blockage
;   values are (are not) to be processed for this level if set to 1 (set to 0).
;
; - If set to 1, the 'ZERO_FILL' flag indicates to the caller that all the mean
;   blockage values for this level are to be set to 0.0 by default, with no need
;   to calculate the mean blockage over the satellite footprint. If set to 0,
;   then this indicates that the mean blockage values need to be calculated from
;   the data arrays returned in the structure (only if 'do_this_elev_blockage'
;   is set to 1).  ZERO_FILL has no meaning if 'do_this_elev_blockage' is 0.
;
; - If the blockage file BlockFileBySweep[ielev] exists, then:
;
;   1) If the blockage_out variable contains all zeroes (no blockage), then the
;      flag 'do_this_elev_blockage' is set to 1 (yes), the flag 'ZERO_FILL' is
;      set to 1, and these 2 flag variables are returned in the structure, 
;      along with bogus values for the other tag/value pairs in the structure,
;      or
;   2) If the blockage file contains non-zero blockages, then the blockages are
;      processed to replace the "1" values with the fractional blockage at outer
;      gate ranges, and the x- and y-coordinates of the range gates are computed
;      in km relative to the origin centered on the radar (range=0).  The
;      flag 'do_this_elev_blockage' is set to 1 (yes), the flag 'ZERO_FILL' is
;      set to 0, and all 5 of these variables are returned in the structure.
;
; - If the blockage file BlockFileBySweep[ielev] does not exist, then:
;
;   1) If the ielev value is zero (first sweep), then both the flags
;      'do_this_elev_blockage' and 'ZERO_FILL' are set to zero, an error message
;      is written, and these 2 flag variables are returned in the structure,
;      along with bogus values for the other tag/value pairs in the structure,
;      or
;   2) If the ielev value is greater than zero, then both the flags
;      'do_this_elev_blockage' and 'ZERO_FILL' are set to 1, and these two
;      variables are returned in the structure with bogus values for the other
;      tag/value pairs in the structure.  This is because blockage files
;      for levels above the first do not exist where there is no beam blockage
;      at these levels.
;
; PARAMETERS
; ----------
; BlockFileBySweep - Array of EXPECTED blockage SAVE file names for each
;                    elevation sweep of the radar volume being processed.  It is
;                    expected that the blockage file for the 0.5 degree sweep is
;                    always present, and that the first sweep in the volume is
;                    also nominally at 0.5 degrees.
; ielev            - Index of the sweep elevation whose blockage file is to be
;                    processed.  If zero, then we expect that the sweep and file
;                    are for 0.5 degrees, and that the SAVE file pathname given
;                    by BlockFileBySweep[0] exists.
; verbose          - Binary parameter, controls diagnostic PRINT statements.
;
; CONSTRAINTS
; -----------
; It is the responsibility of the calling program to prepare the list of
; POTENTIAL blockage file pathnames for each sweep elevation in the radar
; volume being processed, using the well-known file naming convention and the
; fixed list of blockage file elevation angles.
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;===============================================================================

function prep_blockage_parms, BlockFileBySweep, ielev, VERBOSE=verbose

IF FILE_TEST(BlockFileBySweep[ielev]) THEN BEGIN

   IF KEYWORD_SET(verbose) THEN BEGIN
      print, ''
      print, BlockFileBySweep[ielev]
   ENDIF
  ; found a blockage file for this site/elevation, restore its data and
  ; set up to compute blockage
   RESTORE, FILE=BlockFileBySweep[ielev], VERBOSE=verbose
   IF KEYWORD_SET(verbose) THEN $
      HELP, site, elev, azimuths, ranges_out, blockage_out
   do_this_elev_blockage = 1

  ; check the blockage file to see if any of the gate blockages are
  ; fractional ( 0.0 < value <= 1.0 ).  If yes, set up to compute
  ; the mean blockages, otherwise set ZERO_FILL flag to just set the
  ; mean blockages to 0.
   idxFractional = WHERE(blockage_out GT 0.0 AND blockage_out LE 1.0, nblock)

   IF nblock EQ 0 THEN BEGIN
      IF KEYWORD_SET(verbose) THEN $
         print, "In the ZERO_FILL situation by blockage values."
      ZERO_FILL = 1
   ENDIF ELSE BEGIN
      IF KEYWORD_SET(verbose) THEN $
         print, "Preparing data to compute mean blockage for footprints."
      ZERO_FILL = 0

     ; Preprocess the blockage values and replace the values of 1.0 (where the
     ; blocking object exists) with the value of the blocked fraction at the
     ; further ranges along the radial. If that blocked fraction can't be found,
     ; then just set the blocking object gates to zero.  In no case do we want
     ; to include flag values of 1.0 in the mean blocking calculations.
      blokdims = SIZE(blockage_out,/DIMENSIONS)  ; dims are [nranges, nradials]
      nrays = blokdims[1]
      ngates = blokdims[0]
      for irad = 0, nrays-1 do begin
         idxOnes = WHERE(blockage_out[*,irad] EQ 1.0, nOnes)
        ; check whether there are blockage object gates within the radial, with
        ; blockage fractional values at ranges beyond the object
         IF nOnes GT 0 AND MAX(idxOnes) LT (ngates-1) THEN BEGIN
           ; find the blockage fraction beyond the blocking object, and assign
           ; this fractional blockage to the blocking object flagged gates,
           ; assuming there is only one contiguous region of blocking object
           ; gates along the radial
            blockage_out[idxOnes,irad] = blockage_out[(MAX(idxOnes)+1),irad]
            ;print, "Az: ", azimuths[irad], ", setting ",nOnes, $
            ;    " middle gates of 1.0 to ",blockage_out[(MAX(idxOnes)+1),irad]
         ENDIF ELSE BEGIN
           ; if blocking object extends to the last gate in the blockage array,
           ; then just set the blocking object gates to 0.0 (no blockage)
            blockage_out[idxOnes,irad] = 0.0
           ;print, "Az: ", azimuths[irad], ", setting ",nOnes, $
           ;   " trailing gates of 1.0 to 0.0"
         ENDELSE
      endfor

     ; Precompute the geometric variables for the blockage gates...
     ; -- compute sin and cos of the set of angles from 0 to 359 degrees
     ;    for the rays in the blockage files
      sinBlokAz = SIN(azimuths*!DTOR)
      cosBlokAz = COS(azimuths*!DTOR)
     ; initalize x and y of the blockage bins as 1 to 230 km for every angle
      blok_x = FLOAT( LINDGEN(blokdims) MOD 230 ) + 1.0
      blok_y = blok_x
     ; multiply these 'unit vectors' by sin and cos of the angles 0-359 to get
     ; their x and y coordinates with the origin at the radar location.
     ; - Ignore the sweep elevation angle as we don't know whether the blockage
     ;   is computed in slant range or ground range
      for ibin = 0, 229 do begin
         blok_x[ibin,*] = sinBlokAz * blok_x[ibin,*]
         blok_y[ibin,*] = cosBlokAz * blok_y[ibin,*]
      endfor

   ENDELSE

ENDIF ELSE BEGIN

  ; We expect to always find a blockage file for the first sweep if we
  ; have a directory for this site.  Set both flags to zero if none is found
   IF ielev EQ 0 THEN BEGIN
      message, "Missing first sweep blockage file.", /INFO
      print, BlockFileBySweep & print, ''
      do_this_elev_blockage = 0
      ZERO_FILL = 0
   ENDIF ELSE BEGIN
      do_this_elev_blockage = 1
      ZERO_FILL = 1
   ENDELSE

ENDELSE

; define the structure to be returned to the caller based on the status flags

CASE (do_this_elev_blockage*10 + ZERO_FILL) OF
     0 : blkStruct = { do_this_elev_blockage : do_this_elev_blockage, $
                                   ZERO_FILL : ZERO_FILL, $
                                    blockage : -1, $
                                      blok_x : -1, $
                                      blok_y : -1 }
    10 : blkStruct = { do_this_elev_blockage : do_this_elev_blockage, $
                                   ZERO_FILL : ZERO_FILL, $
                                    blockage : blockage_out, $
                                      blok_x : blok_x, $
                                      blok_y : blok_y }
    11 : blkStruct = { do_this_elev_blockage : do_this_elev_blockage, $
                                   ZERO_FILL : ZERO_FILL, $
                                    blockage : -1, $
                                      blok_x : -1, $
                                      blok_y : -1 }
  ELSE : message, "Unexpected blockage status, check logic."
ENDCASE

return, blkStruct
end

