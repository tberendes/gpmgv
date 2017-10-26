     ; Build the GV-to-PR lookup table (GV_index, PR_subarr_index, bin_overlap_area):
      numruff = 0UL
      gvidxall = INDGEN(nbins, nrays)  ; index into arrays of size (nbins,nrays)
      xbin = FLTARR(maxGVbin, nrays) ; only those bins in range/below 20km
      ybin = xbin
      GV_bin_max_axis_len = xbin

     ; compute bin center x,y's and max axis lengths for all bins/rays in range
      FOR jray=0, nrays-1 DO BEGIN
         xbin[*,jray] = ground_range[0:maxGVbin-1] * sinrayazms[jray]
         ybin[*,jray] = ground_range[0:maxGVbin-1] * cosrayazms[jray]
         GV_bin_max_axis_len[*,jray] = beam_diam[0:maxGVbin-1] > gate_space_gv
      ENDFOR

     ; trim the gvidxall array down to maxGVbin bins to match xbin, etc.
      gvidx = gvidxall[0:maxGVbin-1,*]

      prcorners = FLTARR(2,4)
      FOR jpr=0, numPRrays-1 DO BEGIN
         pr_index = pr_master_idx[jpr]
         IF ( pr_index GE 0 ) THEN BEGIN   ; skip over the BOGUS PR points
           ; if both (either?) dX and dY are > max sep, then the footprints can't overlap.
            max_sep = max_PR_footprint_diag_halfwidth + GV_bin_max_axis_len
           ; compute distance between PR footprint x,y and GV b-scan x,y (can do a rough dx and dy
           ;   distance test first if needed; both dx and dy need to be within a PR footprint width
           ;   or less)
            rufdistx = ABS(pr_x_center[jpr]-xbin)  ; array of (maxGVbin, nrays)
            rufdisty = ABS(pr_y_center[jpr]-ybin)  ; ditto
            ruff_distance = rufdistx > rufdisty    ; ditto
            closebyidx = WHERE( ruff_distance LT max_sep, countclose )
            IF ( countclose GT 0 ) THEN BEGIN
               FOR iclose = 0, countclose-1 DO BEGIN
numruff = numruff + 1UL
                 ; get the bin,ray coordinates for the bscan index
                  jbin = gvidx[ closebyidx[iclose] ] MOD nbins
                  jray = gvidx[ closebyidx[iclose] ] / nbins
                 ; compute the bin corner (x,y) coords. (function)
                  gvcorners = bin_corner_x_and_y( sinrayedgeazms, cosrayedgeazms, $
                                 jray, jbin, cos_elev_angle[ielev], ground_range, $
                                 gate_space_gv, DO_PRINT=0 )
                 ; extract this PR corners array
                  prcorners[0,*] = pr_x_corners[*, jpr, ielev]
                  prcorners[1,*] = pr_y_corners[*, jpr, ielev]
                 ; call SHAPE_OVERLAP to get the overlap polygon between the PR FP and the GV bin
                  overlap_poly = shape_overlap (gvcorners, prcorners, exists = exs)

                  IF ( exs EQ 1b ) THEN BEGIN
                    ; compute the area of the overlap polygon with area=POLY_AREA(X,Y)
                     overlap_area = POLY_AREA(overlap_poly[0,*], overlap_poly[1,*])
                    ; write the lookup table values for this PR-GV overlap pairing
                     pridxlut[lut_count] = pr_index
                     gvidxlut[lut_count] = gvidx[ closebyidx[iclose] ]
                     overlaplut[lut_count] = overlap_area
                     lut_count = lut_count+1
                  ENDIF
               ENDFOR
            ENDIF
         endif  ; pr_index ge 0
      ENDFOR    ; pr footprints
print, "numruff, lut_count = ", numruff, lut_count
stop
