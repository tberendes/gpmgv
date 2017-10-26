;===============================================================================
;+
; Copyright © 2016, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; rhi_pr_indices.pro
;
; DESCRIPTION
; -----------
; Computes locations of satellite radar footprints along a radial line from the
; ground radar location to a second footprint.  THe endpoints are defined in
; terms of PPI image coordinates x_gr, y_gr, xppi, yppi. The product-relative
; scan and ray numbers of these image pixels are in myscanbuf, myraybuf, with
; and offset SCANOFF applied to the scan numbers to keep them in the 0-255
; range. The scan and ray number and pr_index value of each footprint along the
; RHI radial from the radar to the point at xppi, yppi, the number of footprints
; along the line, and the center x,y of the footprints at each end of the line
; are computed and returned in an anonymous structure.
;
; HISTORY
; -------
; 02/22/16 Morris, GPM GV, SAIC
; - Created from existing logic cut out of dpr_and_geo_match_x_sections.pro.
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;===============================================================================

FUNCTION rhi_pr_indices, myscanbuf, myraybuf, x_gr, y_gr, xppi, yppi, ysize, $
                         SCANOFF, pr_index_slice, RAYSPERSCAN

         numPRradial = 0       ; number of distinct PR footprints along GR radial
         numrayscanfalse = 0   ; # of sequential invalid ray/scan values along radial
         scanRadialTmp = intarr(100)   ; tally PR scans along radial
         rayRadialTmp = intarr(100)    ; tally PR rays along radial
         ; see if the point at the GR location is within the PR swath
         ; -- if so, then grab its scan and ray number as the starting point
         scanlast = myscanbuf[x_gr, y_gr]
         raylast = myraybuf[x_gr, y_gr]
         IF ( scanlast GT 2 AND scanlast LT 250B ) THEN BEGIN
            ; GR location is within a valid PR footprint, grab PR ray,scan
            scanRadialTmp[numPRradial] = scanlast
            rayRadialTmp[numPRradial] = raylast
            numPRradial++
         ENDIF  ; otherwise, start walking along radial until we find valid ray/scan
         ; - first, compute the equation of the line from the GR x,y to the cursor
         IF (x_gr NE xppi) THEN BEGIN
            ; slope is finite, compute the line parameters
            slope = FLOAT(y_gr-(yppi MOD ysize))/(x_gr-xppi)
            yintercept = y_gr - slope*x_gr
            IF KEYWORD_SET(VERBOSE) THEN print, "slope, intercept: ", slope, yintercept
            IF ABS(slope) GT 0.0001 THEN slopesign = slope/ABS(slope) $    ; positive or negative slope?
            ELSE BEGIN
               slope = 0.0001   ; avoid divide by zero
               slopesign = 0.0
            ENDELSE
            ; next, walk along the radial through the cursor point and find the
            ; unique, valid PR footprints along that line
            IF ABS(slope) GT 1.0 THEN BEGIN
               yend = yppi MOD ysize
               ; increment y, compute new x, and get scan and ray number
               IF (yppi MOD ysize) GT y_gr THEN BEGIN
;                  yend = 300    ; y-top of outer range ring
                  yinc = 1      ; step in +y direction
               ENDIF ELSE BEGIN
;                  yend = 42     ; y-bottom of outer range ring
                  yinc = -1     ; step in -y direction
               ENDELSE
               FOR ypix = y_gr, yend, yinc DO BEGIN
                  xpixf = (ypix-yintercept)/slope + 0.5*slopesign*yinc
                  xpix = FIX(xpixf)
                  scannext = myscanbuf[xpix,ypix]
                  raynext = myraybuf[xpix,ypix]
                  IF (scannext NE scanlast) OR (raynext NE raylast) THEN BEGIN
                     IF ( scannext GT 2 AND scannext LT 250B ) THEN BEGIN
                        ; new location is within a valid PR footprint, and is
                        ; different from last one found, grab PR ray,scan
                        scanRadialTmp[numPRradial] = scannext
                        rayRadialTmp[numPRradial] = raynext
                        numPRradial++
                        scanlast = scannext
                        raylast = raynext
                     ENDIF ELSE BEGIN
                       ; look side-to-side a bit in x to see if we get a hit
                       ; on a new footprint within some image pixel threshold
; TEMPORARILY DISABLED BY LIMITS
                       foundpixoff=0
                       for pixoff=1,0 do begin
                           PRINT, "Looking off to the side by ", pixoff, " at y location ", ypix
                           pixoffs=[(-1)*pixoff,pixoff]
                           scancheck = [ myscanbuf[xpix+pixoffs[0],ypix], $
                                         myscanbuf[xpix+pixoffs[1],ypix] ]
                           idxhit = WHERE(scancheck GT 2 AND scancheck LT 250B, nhits)
                           IF nhits GT 0 THEN BEGIN
                             ; found a valid footprint, see if it is new
                              scannext = myscanbuf[xpix+pixoffs[idxhit],ypix]
                              raynext = myraybuf[xpix+pixoffs[idxhit],ypix]
                              IF (scannext NE scanlast) OR (raynext NE raylast) THEN BEGIN
                                ; new location is within a valid PR footprint, and is
                                ; different from last one found, grab PR ray,scan
                                 scanRadialTmp[numPRradial] = scannext
                                 rayRadialTmp[numPRradial] = raynext
                                 numPRradial++
                                 scanlast = scannext
                                 raylast = raynext
                                 foundpixoff=1
                                 BREAK   ; quit looking off to the side
                              ENDIF
                           ENDIF
                       endfor
;                       IF foundpixoff EQ 0 THEN BEGIN
                          ; check whether we have moved out of the range of valid
                          ; ray/scan values after being within (i.e., numPRradial>0)
                          ; - if so, then quit incrementing, we have our footprints
                          ; Note we can have isolated pixels in the raybuf and scanbuf
                          ; arrays that didn't get "filled" with the ray and scan
                          ; values, so we use numrayscanfalse checks to step past
                          ; these before bailing out of the loop.
;                          IF numPRradial GT 0 AND numrayscanfalse GT 1 THEN BREAK $
;                          ELSE numrayscanfalse++
;                        ENDIF
                     ENDELSE
                  ENDIF
               ENDFOR
            ENDIF ELSE BEGIN
               ; increment x, compute new y, and get scan and ray number
               xend=xppi
               IF xppi GT x_gr THEN BEGIN
;                  xend = 307     ; max x-right at outer range ring
                  xinc = 1
               ENDIF ELSE BEGIN
;                  xend = 42      ; min x-left at outer range ring
                  xinc = -1
               ENDELSE
               FOR xpix = x_gr, xend, xinc DO BEGIN
                  ypixf = yintercept + slope*xpix + 0.5*slopesign*xinc
                  ypix = FIX(ypixf)
                  scannext = myscanbuf[xpix,ypix]
                  raynext = myraybuf[xpix,ypix]
;HELP, xpix, ypix, raynext, scannext, raylast, scanlast
                  IF (scannext NE scanlast) OR (raynext NE raylast) THEN BEGIN
                     IF ( scannext GT 2 AND scannext LT 250B ) THEN BEGIN
                        ; new location is within a valid PR footprint, and is
                        ; different from last one found, grab PR ray,scan
                        scanRadialTmp[numPRradial] = scannext
                        rayRadialTmp[numPRradial] = raynext
                        numPRradial++
                        scanlast = scannext
                        raylast = raynext
                     ENDIF ;ELSE BEGIN
                        ; check whether we have moved out of the range of valid
                        ; ray/scan values after being within (i.e., numPRradial>0)
                        ; - if so, then quit incrementing, we have our footprints
;                        IF numPRradial GT 0 AND numrayscanfalse GT 1 THEN BREAK $
;                        ELSE numrayscanfalse++
;                     ENDELSE
                  ENDIF
               ENDFOR
            ENDELSE
         ENDIF ELSE BEGIN
            ; slope is infinite, just walk up/down in y-direction
            xpix = x_gr
            yend = yppi MOD ysize
            IF (yppi MOD ysize) GT y_gr THEN BEGIN
;               yend = 300    ; y-top of outer range ring
               yinc = 1      ; step in +y direction
            ENDIF ELSE BEGIN
;               yend = 42     ; y-bottom of outer range ring
               yinc = -1     ; step in -y direction
            ENDELSE
            FOR ypix = y_gr, yend, yinc DO BEGIN
               scannext = myscanbuf[xpix,ypix]
               raynext = myraybuf[xpix,ypix]
               IF (scannext NE scanlast) OR (raynext NE raylast) THEN BEGIN
                  IF ( scannext GT 2 AND scannext LT 250B ) THEN BEGIN
                     ; new location is within a valid PR footprint, and is
                     ; different from last one found, grab PR ray,scan
                     scanRadialTmp[numPRradial] = scannext
                     rayRadialTmp[numPRradial] = raynext
                     numPRradial++
                     scanlast = scannext
                     raylast = raynext
                  ENDIF ;ELSE BEGIN
                     ; check whether we have moved out of the range of valid
                     ; ray/scan values after being within (i.e., numPRradial>0)
                     ; - if so, then quit incrementing, we have our footprints
;                     IF numPRradial GT 0 THEN BREAK
;                  ENDELSE
               ENDIF
            ENDFOR
         ENDELSE

         ; find the endpoints of the selected scan line on the PPI (pixmaps)
          idxlinebeg = WHERE( myscanbuf EQ scanRadialTmp[0] and $
                              myraybuf EQ rayRadialTmp[0], countbeg )
          idxlineend = WHERE( myscanbuf EQ scanRadialTmp[numPRradial-1] and $
                              myraybuf EQ rayRadialTmp[numPRradial-1], countend )
          startxys = ARRAY_INDICES( myscanbuf, idxlinebeg )
          endxys = ARRAY_INDICES( myscanbuf, idxlineend )
          xbeg = MEAN( startxys[0,*] ) & xend = MEAN( endxys[0,*] )
          ybeg = MEAN( startxys[1,*] ) & yend = MEAN( endxys[1,*] )
          angle = (180./!pi)*ATAN(xend-x_gr, yend-y_gr)
          IF angle LT 0.0 THEN angle = angle+360.0
          PRINT, "Angle: ", STRING(angle, FORMAT='(F0.1)')

          ; clip the two "tmp" arrays to the defined footprints, restore to
          ; product-relative indices, and compute pr_index values needed to
          ; extract radial x-section of geo-match data
          scanRadial = scanRadialTmp[0:numPRradial-1] + scanoff - 3L
          rayRadial = rayRadialTmp[0:numPRradial-1] - 3L
          pr_indexRadial = scanRadial*RAYSPERSCAN + rayRadial

          ; If we are walking nearly parallel to a PR scan or along a given PR ray,
          ; we can get a "sawtooth" effect in the scanbuf and raybuf arrays such
          ; that we go back-and-forth from a given footprint and thus include it
          ; in more than one position (duplicate PR_index values, not adjacent).
          ; Step through the pr_indexRadial values, look for unique values, and
          ; keep only these values
          
          ; get array indices of original, unsorted, non-unique pr_indexRadial values
          orig_idx = INDGEN(numPRradial)
          ; get sort order of pr_indexRadial
          idx_sorted_prindex = SORT(pr_indexRadial)
          sorted_orig_idx = orig_idx[idx_sorted_prindex]  ; reorder by ascend pr_index
          sorted_prindex = pr_indexRadial[idx_sorted_prindex]  ; ditto
          sorted_scanRadial = scanRadial[idx_sorted_prindex]   ; ditto
          sorted_rayRadial = rayRadial[idx_sorted_prindex]     ; ditto
          ; get indices of unique pr_indexRadial values in sorted array
          idx_uniq_sorted_prindex = UNIQ(sorted_prindex)
          ; grab the original array elements for the unique pr_indexRadial values only
          uniq_sorted_orig_idx = sorted_orig_idx[idx_uniq_sorted_prindex]
          uniq_sorted_prindex = sorted_prindex[idx_uniq_sorted_prindex]
          uniq_sorted_scanRadial = sorted_scanRadial[idx_uniq_sorted_prindex]
          uniq_sorted_rayRadial = sorted_rayRadial[idx_uniq_sorted_prindex]
          ; re-sort the uniq_sorted_prindex and ray and scan by the orig_idx value order
          pr_indexRadial = uniq_sorted_prindex[SORT(uniq_sorted_orig_idx)]
          scanRadial = uniq_sorted_scanRadial[SORT(uniq_sorted_orig_idx)]
          rayRadial = uniq_sorted_rayRadial[SORT(uniq_sorted_orig_idx)]
          IF KEYWORD_SET(verbose) THEN BEGIN
             print, ''
             print, "Duplicate footprints removed: ", numPRradial-N_ELEMENTS(pr_indexRadial)
             print, ''
          ENDIF
          numPRradial = N_ELEMENTS(pr_indexRadial)

          indexRadial = LONARR(numPRradial)
          FOR ifpslice = 0, numPRradial-1 DO BEGIN
             ; map the ray/scan location to its position in the geo-match
             ; data arrays via its pr_index value position
             indexRadial[ifpslice] = $
                WHERE( pr_index_slice EQ pr_indexRadial[ifpslice], countfpradial)
             IF countfpradial NE 1 THEN stop
          ENDFOR

return, { numPRradial : numPRradial, indexRadial : indexRadial, $
           scanRadial : scanRadial,    rayRadial : rayRadial, $
           xbeg:xbeg, xend:xend, ybeg:ybeg, yend:yend }
end
