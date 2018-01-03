;===============================================================================
;+
; Copyright © 2008, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; polar2tmi_resampling.pro          Morris/SAIC/GPM_GV      September 2008
;
; DESCRIPTION
; -----------
; This file contains the TMI-GV volume matching, data plotting, and score
; computations sections of the code for the procedure polar2tmi.  See file
; polar2tmi.pro for a description of the full procedure.
;
; NOTE: THIS FILE MUST BE "INCLUDED" INSIDE THE PROCEDURE polar2tmi, IT IS *NOT*
;       A COMPLETE IDL PROCEDURE AND CANNOT BE COMPILED OR RUN ON ITS OWN !!
;
; HISTORY
; -------
; 5/6/2011 by Bob Morris, GPM GV (SAIC)
;  - Created from polar2pr_resampling2.pro.
; 05/10/11 by Bob Morris, GPM GV (SAIC)
;  - Fixed major bug where parallax-corrected TMI footprint x and y values for
;    other GR elevations used only the corrections for the GR base scan,
;    offsetting the GR volume from the TMI scanning paths for GR sweeps other
;    than the base scan.  Inherited error from polar2pr_resampling2.pro.  Found
;    error by activating PLOT_BINS and noting mismatch between TMI footprint and
;    GR bins.
; 5/18/2011 by Bob Morris, GPM GV (SAIC)
;  - Added a second set of GR averaging calculations/variables for a strictly
;    vertical stack of GR samples above the TMI surface footprint (ignoring
;    parallax of TMI view angle).
; 8/20/13 - Renamed from polar2tmi_resampling.pro and modified to optionally
;    output a file listing the x-y-z corners/heights of the GR bins from the
;    PLOT_BINS option, for a subset of the sweeps and at one TMI footprint.
;    This ASCII text file is then used as input in iPlot in IDL to do a 3-D plot
;    of the samples mapped to the TMI footprint.
;
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;===============================================================================

  ; set up a multi-level array of 2A12 rainrate to match GV reflectivity array
  ; dimensions, if plotting PPIs
   IF keyword_set(plot_PPIs) THEN BEGIN
      toplot_2a12_srain = MAKE_ARRAY( $
         numTMIrays, num_elevations_out, /float, VALUE=FLOAT_RANGE_EDGE )
   ENDIF

   jpr2write = -1  ; re-initialize to not 'write' bin plots
   fileIsOpen = 0

  ; Retrieve the desired radar volume from the radar structure
   zvolume = rsl_get_volume( radar, z_vol_num )

  ; Map this GV radar's data to the these TMI footprints, sweep by sweep, at the
  ;   locations where TMI rays intersect the elevation sweeps:

;  >>>>>>>>>>>>>> BEGINNING OF TMI-GV VOLUME MATCHING, ALL SWEEPS <<<<<<<<<<<<<<<

   FOR ielev = 0, num_elevations_out - 1 DO BEGIN
      print, ""
      print, "Elevation: ", tocdf_elev_angle[ielev]

     ; read in the sweep structure for the elevation
      sweep = rsl_get_sweep( zvolume, SWEEP_INDEX=idx_uniq_elevs[ielev] )
     ; read/get the number of rays in the sweep: nrays
      nrays = sweep.h.nrays

     ; =========================================================================
     ; START PREPROCESSING ON THE SWEEP DATA

     ; not-to-exceed difference between beam center azimuths (generous slop)
      azm_delta = ABS(sweep.h.beam_width) * 1.25

     ; build an nrays-sized 1-D array of ray azimuths (float degrees), and
     ;   NRAYS+1 ray-edge az's, and matching arrays of sin(az) and cos(az)
      rayazms = rsl_get_azm_from_sweep( sweep )
      sinrayazms = SIN( rayazms*!PI/180. )
      cosrayazms = COS( rayazms*!PI/180. )
      rayedgeazms = FLTARR(nrays+1)

     ; Figure out whether we are scanning CW (+az direction) or CCW
      azsign = 0
      FOR iray = 1, nrays-1 DO BEGIN
         azdiff = ABS(rayazms[iray-1]-rayazms[iray])
         IF azdiff LT azm_delta AND azdiff GT 0.0 THEN BEGIN
            azsign = (rayazms[iray]-rayazms[iray-1])/azdiff
            BREAK  ; jump out of loop ASAP
         ENDIF
      ENDFOR
      IF azsign EQ 0 THEN BEGIN
         PRINT, "Error computing sweep direction, skipping this event!
         GOTO, nextGVfile
      ENDIF

     ; Compute the leading edge of each ray as the mean center azimuth of it
     ; and the next ray, if the azimuth step is nominal.  Otherwise, use the
     ; stated ray azimuth and beam width to compute the edge.  Handle the wrap-
     ; around when crossing over at 0/360 degrees.
      FOR iray = 1, nrays-1 DO BEGIN
         CASE 1 OF
             ABS(rayazms[iray-1]-rayazms[iray]) LT azm_delta :  $
                rayedgeazms[iray] = ( rayazms[iray-1] + rayazms[iray] ) /2.

             rayazms[iray-1]-rayazms[iray] GT (360.0 - azm_delta) : BEGIN
                rayedgeazms[iray]=( rayazms[iray-1] + (rayazms[iray]+360.) ) /2.
                IF rayedgeazms[iray] GT 360. THEN $
                     rayedgeazms[iray] = rayedgeazms[iray] - 360.
                END

             rayazms[iray-1]-rayazms[iray] LT (azm_delta - 360.0) : BEGIN
                rayedgeazms[iray]=( (rayazms[iray-1]+360.) + rayazms[iray] ) / 2.
                IF rayedgeazms[iray] GT 360. THEN $
                     rayedgeazms[iray] = rayedgeazms[iray] - 360.
                END

         ELSE : BEGIN
                print, "Excessive beam gap for ray = ", iray
                rayedgeazms[iray]=rayazms[iray-1]+azsign*sweep.h.beam_width/2.0
                END

         ENDCASE
      ENDFOR

     ; Compute the trailing edge azimuth of the first ray
      CASE 1 OF

          ABS(rayazms[nrays-1]-rayazms[0]) LT azm_delta  :  $
             rayedgeazms[0] = ( rayazms[nrays-1] + rayazms[0] ) /2.

          rayazms[nrays-1]-rayazms[0] GT (360.0 - azm_delta)  :  BEGIN
             rayedgeazms[0]=( rayazms[nrays-1] + (rayazms[0]+360.) ) /2.
             IF rayedgeazms[0] GT 360. THEN rayedgeazms[0] = rayedgeazms[0]-360.
          END

          rayazms[nrays-1]-rayazms[0] LT (azm_delta - 360.0)  :  BEGIN
             rayedgeazms[0]=( (rayazms[nrays-1]+360.) + rayazms[0] ) / 2.
             IF rayedgeazms[0] GT 360. THEN rayedgeazms[0] = rayedgeazms[0]-360.
          END

      ELSE  :  BEGIN
             print, "Excessive beam gap for ray = 0"
             rayedgeazms[0] = rayazms[0] - azsign * sweep.h.beam_width / 2.0
          END

      ENDCASE

     ; The leading edge azimuth of the last ray is the trailing edge of the 1st
     ;   (already checked for an improper beam width result in above)
      rayedgeazms[nrays] = rayedgeazms[0]

      sinrayedgeazms = SIN( rayedgeazms*!PI/180. )
      cosrayedgeazms = COS( rayedgeazms*!PI/180. )

     ; get necessary sweep/ray/bin parameters
      nbins=sweep.ray[0].h.nbins
      beamwidth_radians = sweep.h.beam_width * !PI / 180.
      gate_space_gv = sweep.ray[0].h.gate_size/1000.  ; units converted to km
      cos_elev_angle_top = COS( (tocdf_elev_angle[ielev]+sweep.h.beam_width/2.0) * !DTOR )
      cos_elev_angle_botm = COS( (tocdf_elev_angle[ielev]-sweep.h.beam_width/2.0) * !DTOR )
      sin_elev_angle = SIN( tocdf_elev_angle[ielev] * !DTOR )

     ; arrays to hold the along-ground range, beam height, and beam x-sect size
     ;   at each gate:
      ground_range = FLTARR(nbins)
      ground_range_botm = FLTARR(nbins)
      ground_range_top = FLTARR(nbins)
      height = FLTARR(nbins)
      beam_diam = FLTARR(nbins)

     ; create a GV dbz data array of [nbins,nrays] (distance vs angle 'b-scan')
      bscan = FLTARR(nbins,nrays)
     ; read each GV ray into the b-scan column
      FOR iray = 0, nrays-1 DO BEGIN
         ray = sweep.ray[iray]
         bscan[*,iray] = ray.range[0:nbins-1]      ; drop the 'padding' bins
      ENDFOR

     ; build 1-D arrays of GV radial bin ground_range (float km), beam width,
     ;   and beam height from origin bin to max bin, each of size nbins (cut
     ;   this and the b-scan off at some radial distance threshold??) (all GV
     ;   radials for an elevation have the same distance from radar, height, and
     ;   width for a given bin #)
      thisrange = 0.0
      thisheight = 0.0
      FOR bin_index = 0, nbins-1 DO BEGIN
         rsl_get_gr_slantr_h, ray, bin_index, thisrange, $
                                   slant_range, thisheight
         ground_range[bin_index] = thisrange
         height[bin_index] = thisheight
        ; compute beam_diam[bin_index] from slant_range and beamwidth
         beam_diam[bin_index] = slant_range * beamwidth_radians
        ; figure ground range for top and bottom of the bins based on elev. angle, bin depth
         groundrangedelta = (beam_diam[bin_index]/2)*sin_elev_angle
         ground_range_botm[bin_index] = ground_range[bin_index] + groundrangedelta
         ground_range_top[bin_index] = ground_range[bin_index] - groundrangedelta
      ENDFOR
     ; cut the GV rays off where the beam center height > ~20km -- use a higher
     ; threshold than for the PR so that we get enough GV bins to cover the PR
     ; footprint's outer edges.  Could compute this threshold using elev angle,
     ; max_ranges[ielev], and the PR footprint extent...
      elevs_ok_idx = WHERE( height LE 20.25, bins2do)
      maxGVbin = bins2do - 1 > 0
     ; now cut the GV rays off by range or height, whichever is less
      bins_in_range_idx = WHERE( ground_range LT $
          (max_ranges[ielev]+max_TMI_footprint_diag_halfwidth), bins2do2 )
      maxGVbin2 = bins2do2 - 1 > 0
      maxGVbin = maxGVbin < maxGVbin2

     ; =========================================================================
     ; GENERATE THE GV-TO-TMI LUTs FOR THIS SWEEP

     ; create arrays of (nrays*maxGVbin*4) to hold index of overlapping TMI ray,
     ;    index of bscan bin, and bin-footprint overlap area (these comprise the
     ;    GV-to-TMI many:many lookup table)
      pridxlut = LONARR(nrays*maxGVbin*4)
      gvidxlut = ULONARR(nrays*maxGVbin*4)
      overlaplut = FLTARR(nrays*maxGVbin*4)
      lut_count = 0UL
      tmi_footprints_in_lut=0

     ; Do a 'nearest neighbor' analysis of the TMI data to the b-scan coordinates
     ;    First, start populating the three GV-to-TMI lookup table arrays:
     ;    GV_index, TMI_subarr_index, GV_bin_width * distance_weighting

      gvidxall = LINDGEN(nbins, nrays)  ; indices into full bscan array

     ; compute GV bin center x,y's for all bins/rays in-range and below 20km:
      xbin = FLTARR(maxGVbin, nrays)
      ybin = FLTARR(maxGVbin, nrays)
      FOR jray=0, nrays-1 DO BEGIN
         xbin[*,jray] = ground_range[0:maxGVbin-1] * sinrayazms[jray]
         ybin[*,jray] = ground_range[0:maxGVbin-1] * cosrayazms[jray]
      ENDFOR

     ; trim the gvidxall array down to maxGVbin bins to match xbin, etc.
      gvidx = gvidxall[0:maxGVbin-1,*]

      IF KEYWORD_SET(plot_bins) THEN BEGIN
         prcorners = FLTARR(2,4)               ;for current TMI footprint's corners
         askagain = 50 < numTMIrays-1 & nplotted = 0L   ;support bin plots bail-out
         WINDOW, 2, xsize=400, ysize=xsize
         loadct,0
         jpr2write = -1  ; index of footprint whose x/y/z is to be written to file
      ENDIF

      FOR jpr=0, numTMIrays-1 DO BEGIN
         plotting = 0
         TMI_index = TMI_master_idx[jpr]
       ; only map GV to non-BOGUS TMI points having one or more above-threshold
       ;   reflectivity bins in the TMI ray
         IF ( TMI_index GE 0 AND TMI_echoes[jpr] NE 0B ) THEN BEGIN
           ; Compute rough distance between TMI footprint x,y and GV b-scan x,y --
           ; if either dX or dY is > max sep, then the footprints don't overlap
            max_sep = max_TMI_footprint_diag_halfwidth
            rufdistx = ABS(TMI_x_center[jpr,ielev]-xbin)  ; array of (maxGVbin, nrays)
            rufdisty = ABS(TMI_y_center[jpr,ielev]-ybin)  ; ditto
            ruff_distance = rufdistx > rufdisty    ; ditto
            closebyidx1 = WHERE( ruff_distance LT max_sep, countclose1 )

            IF ( countclose1 GT 0 ) THEN BEGIN  ; any points pass rough distance check?
              ; check the GV reflectivity values for these bins to see if any
              ;   meet the min dBZ criterion; if none, skip the footprint
               idxcheck = WHERE( bscan[gvidx[closebyidx1]] GE 0.0, countZOK )
;               print, TMI_index, TMI_x_center[jpr,ielev], TMI_y_center[jpr,ielev], countclose, countZOK

               IF ( countZOK GT 0 ) THEN BEGIN  ; any GV points above min dBZ?
                 ; test the actual center-to-center distance between TMI and GV
                  truedist = sqrt( (TMI_x_center[jpr,ielev]-xbin[closebyidx1])^2  $
                                  +(TMI_y_center[jpr,ielev]-ybin[closebyidx1])^2 )
                  closebyidx = WHERE(truedist le max_sep, countclose )

                  IF ( countclose GT 0 ) THEN BEGIN  ; any points pass true dist check?
                     tmi_footprints_in_lut = tmi_footprints_in_lut + 1

                    ; optional bin plotting stuff -- TMI footprint
                     IF KEYWORD_SET(plot_bins)  THEN BEGIN
                       ; If plotting the footprint boundaries, extract this TMI
                       ;   footprint's x and y corners arrays
                        prcorners[0,*] = TMI_x_corners[*, jpr, ielev]
                        prcorners[1,*] = TMI_y_corners[*, jpr, ielev]
                       ; set up plotting and bail-out stuff
                        xrange = [MEAN(prcorners[0,*])-15, MEAN(prcorners[0,*])+15]
                        yrange = [MEAN(prcorners[1,*])-15, MEAN(prcorners[1,*])+15]
                        plotting = 1
                        nplotted = nplotted + 1L
                       ; plot the TMI footprint - close the polygon using concatenation
                        plot, [REFORM(prcorners[0,*]),REFORM(prcorners[0,0])], $
                              [REFORM(prcorners[1,*]),REFORM(prcorners[1,0])], $
                              xrange = xrange, yrange = yrange, xstyle=1, ystyle=1, $
                              THICK=1.5, /isotropic
                     ENDIF

                     FOR iclose = 0, countclose-1 DO BEGIN
                       ; get the bin,ray coordinates for the given bscan index
                        jbin = gvidx[ closebyidx1[closebyidx[iclose]] ] MOD nbins
                        jray = gvidx[ closebyidx1[closebyidx[iclose]] ] / nbins

                       ; write the lookup table values for this TMI-GV overlap pairing
                        pridxlut[lut_count] = TMI_index
                        gvidxlut[lut_count] = gvidx[closebyidx1[closebyidx[iclose]]]
                       ; use a Barnes-like gaussian weighting, using 2*max_sep as the
                       ;  effective radius of influence to increase the edge weights
                       ;  beyond pure linear-by-distance weighting
                        weighting = EXP( - (truedist[closebyidx[iclose]]/max_sep)^2 )
                        overlaplut[lut_count] = beam_diam[jbin] * weighting
                        lut_count = lut_count+1

                       ; optional bin plotting stuff -- GV bins
                        IF plotting EQ 1 THEN BEGIN
                          ; compute the GV bin corner (x,y) coords. (function)
                           gvcorners = bin_corner_x_and_y( sinrayedgeazms, cosrayedgeazms, $
                                         jray, jbin, cos_elev_angle[ielev], ground_range, $
                                         gate_space_gv, DO_PRINT=0 )
                          ; plot the GV bin polygon
                           oplot, [REFORM(gvcorners[0,*]),REFORM(gvcorners[0,0])], $
                                  [REFORM(gvcorners[1,*]),REFORM(gvcorners[1,0])], $
                                  LINESTYLE = 1, THICK=1.5
                        ENDIF
                     ENDFOR

                    ; optional bin plotting stuff
                     if plotting EQ 1 then begin     ; built-in delay to allow viewing plot
                        endtime = systime(1) + .75
                        while ( systime(1) LT endtime ) do begin
                           continue
                        endwhile
                     endif

                  ENDIF  ; countclose GT 0
               ENDIF     ; countZOK GT 0
            ENDIF        ; countclose1 GT 0
         ENDIF           ; TMI_index ge 0 AND TMI_echoes[jpr] NE 0B

        ; execute bin-plotting bailout option, if plotting is active
         IF KEYWORD_SET(plot_bins) THEN BEGIN
         IF ( nplotted MOD askagain EQ 0 ) THEN BEGIN
            PRINT, ielev, askagain, KEYWORD_SET(plot_bins), ""
            PRINT, "Had enough yet? (Y/N)"
            reply = plot_bins_bailout()
            IF ( reply EQ 'Y' ) THEN BEGIN
               plot_bins = 0
               WDELETE
            ENDIF
            IF reply eq 'W' THEN BEGIN
               jpr2write = jpr
               plot_bins = 0
            ENDIF
         ENDIF
         ENDIF

         IF jpr EQ jpr2write THEN BEGIN
            hgtGRcorners = FLTARR(4)
            half_beam_deep = FLTARR(4)

            ;======================== TMI outline part ===============================

            ; extract this TMI footprint's x and y corners arrays
            prcorners[0,*] = TMI_x_corners[*, jpr, ielev]
            prcorners[1,*] = TMI_y_corners[*, jpr, ielev]
            ; set up plotting and bail-out stuff
            xrange = [MEAN(prcorners[0,*])-15, MEAN(prcorners[0,*])+15]
            yrange = [MEAN(prcorners[1,*])-15, MEAN(prcorners[1,*])+15]
            ; plot the TMI footprint - close the polygon using concatenation
            plot, [REFORM(prcorners[0,*]),REFORM(prcorners[0,0])], $
                  [REFORM(prcorners[1,*]),REFORM(prcorners[1,0])], $
                  xrange = xrange, yrange = yrange, xstyle=1, ystyle=1, $
                  THICK=1.5, /isotropic
            IF ielev EQ 0 THEN BEGIN
               file3dout = '/tmp/file3d_out.txt'
               PRINT, "Write output to: ", file3dout
               OPENW, DBunit, file3dout, /GET_LUN
               fileIsOpen = 1
;               printf, DBunit, "binheight        X          Y"
               ; plot a line down the center of the TMI footprints from lowest
               ; elevation to be shown to the highest
               idxmaxelev = MAX(WHERE( (INDGEN(num_elevations_out)-1) MOD 3 EQ 0 ))
               ; start it from the surface
               printf, DBunit, 0.0, x_sfc[jpr], y_sfc[jpr]
               FOR iplotidx = 0, (idxmaxelev+1)<(num_elevations_out-1) DO BEGIN
                  rangeCtr = sqrt(TMI_x_center[jpr, iplotidx]^2+TMI_y_center[jpr, iplotidx]^2)
                  rsl_get_slantr_and_h, rangeCtr, tocdf_elev_angle[iplotidx], slantrCorn, binheight
                  printf, DBunit, binheight, TMI_x_center[jpr, iplotidx], TMI_y_center[jpr, iplotidx]
               ENDFOR
               printf, DBunit, binheight  ; write a "Missing" point to disconnect polys
               ; output footprint x/y/z surface corners
               prcornerssfcx = TMI_x_corners_sfc[*,jpr]
               prcornerssfcy = TMI_y_corners_sfc[*,jpr]
               FOR jcorn=0,4 DO BEGIN
                  icorn = jcorn MOD 4  ; to repeat 1st point at end, close off poly
                  printf, DBunit, 0.0, prcornerssfcx[icorn], prcornerssfcy[icorn]
               ENDFOR
               printf, DBunit, 0.0  ; write a "Missing" point to disconnect polys
            ENDIF

            ;======================== GR outline part ===============================

            IF ( countclose1 GT 0 ) THEN BEGIN  ; any points pass rough distance check?
              ; test the actual center-to-center distance between TMI and GV
               truedist = sqrt( (TMI_x_center[jpr,ielev]-xbin[closebyidx1])^2  $
                               +(TMI_y_center[jpr,ielev]-ybin[closebyidx1])^2 )
               closebyidx = WHERE(truedist le max_sep, countclose )
               IF ( countclose GT 0 ) THEN BEGIN  ; any points pass true dist check?
                  FOR iclose = 0, countclose-1 DO BEGIN
                      ; get the bin,ray coordinates for the given bscan index
                      jbin = gvidx[ closebyidx1[closebyidx[iclose]] ] MOD nbins
                      jray = gvidx[ closebyidx1[closebyidx[iclose]] ] / nbins
;                      binheight = height[jbin]       ; depends only on bin # of bscan point
                      gvcorners = bin_corner_x_and_y( sinrayedgeazms, cosrayedgeazms, $
                                     jray, jbin, cos_elev_angle[ielev], ground_range, $
                                     gate_space_gv, DO_PRINT=0 )

                      ; plot the GV bin polygon
                      oplot, [REFORM(gvcorners[0,*]),REFORM(gvcorners[0,0])], $
                             [REFORM(gvcorners[1,*]),REFORM(gvcorners[1,0])], $
                             LINESTYLE = 1, THICK=1.5
                      if (ielev-1) mod 3 eq 0 then begin   ; output every 3d sweep
                         gvcorners_botm = bin_corner_x_and_y( sinrayedgeazms, cosrayedgeazms, $
                                         jray, jbin, cos_elev_angle_botm, ground_range_botm, $
                                         gate_space_gv, DO_PRINT=0 )
                         FOR jcorn=0,4 DO BEGIN
                            icorn = jcorn MOD 4  ; to repeat 1st point at end, close off poly
                            ; get the height/depth of the corner points from their ranges
                            rangeCorn = sqrt(gvcorners[0,icorn]^2+gvcorners[1,icorn]^2)
                            rsl_get_slantr_and_h, rangeCorn, tocdf_elev_angle[ielev], slantrCorn, binheight
                            half_beam_deep[icorn] = slantrCorn * beamwidth_radians / 2.0
                            hgtGRcorners[icorn] = binheight
                            ; write out the bin outline bottoms
                            printf, DBunit, hgtGRcorners[icorn]-half_beam_deep[icorn], $
                                    gvcorners_botm[0,icorn], gvcorners_botm[1,icorn]
                         ENDFOR
                         printf, DBunit, binheight  ; write a "Missing" point to disconnect polys
                         gvcorners_top = bin_corner_x_and_y( sinrayedgeazms, cosrayedgeazms, $
                                          jray, jbin, cos_elev_angle_top, ground_range_top, $
                                          gate_space_gv, DO_PRINT=0 )
                         FOR jcorn=0,4 DO BEGIN
                            icorn = jcorn MOD 4  ; to repeat 1st point at end, close off poly
                            ; write out the bin outline tops
                            printf, DBunit, hgtGRcorners[icorn]+half_beam_deep[icorn], $
                                    gvcorners_top[0,icorn], gvcorners_top[1,icorn]
                         ENDFOR
                         printf, DBunit, binheight  ; write a "Missing" point to disconnect polys
                         FOR icorn=0,3 DO BEGIN
                            ; write out the bin outline sides
                            printf, DBunit, hgtGRcorners[icorn]-half_beam_deep[icorn], $
                                    gvcorners_botm[0,icorn], gvcorners_botm[1,icorn]
                            printf, DBunit, hgtGRcorners[icorn]+half_beam_deep[icorn], $
                                    gvcorners_top[0,icorn], gvcorners_top[1,icorn]
                            printf, DBunit, binheight  ; write a "Missing" point to disconnect
                         ENDFOR
                         printf, DBunit, binheight  ; write a "Missing" point to disconnect
                      endif
                  ENDFOR
                  if (ielev-1) mod 3 eq 0 then begin   ; output ray bounds every 3d sweep
                     ; identify 1st/last rays mapped to TMI footprint, draw line from radar
                     ; x/y/z (= 0,0,0) to these GR gates
                     jbinall = gvidx[closebyidx1[closebyidx]] MOD nbins
                     jrayall = gvidx[closebyidx1[closebyidx]] / nbins
                     jraymax = MAX( jrayall, MIN=jraymin)
                     idxraymax = WHERE( jrayall EQ jraymax )   ; all gates along max ray
                     idxraymin = WHERE( jrayall EQ jraymin )   ; all gates along min ray
;                     minbinmaxray = MIN(jbinall[idxraymax])    ; 1st bin along max ray
;                     minbinminray = MIN(jbinall[idxraymin])    ; 1st bin along min ray
                     if (ielev-1) eq 0 then begin
                        ; plot all GR ray center lines for this sweep
                        jraystart=jraymin
                        jrayend=jraymax
                     endif else begin
                        ; plot the GR ray center line for just the middle ray
                        jraystart=(jraymin + jraymax)/2
                        jrayend=jraystart
                     endelse
                     FOR jrayline = jraystart, jrayend DO BEGIN    ; to do all rays
                     ;jraymid = (jraymin + jraymax)/2              ; to do middle ray only
                     ;FOR jrayline = jraymid, jraymid DO BEGIN     ; to do middle ray only
                        ;minbinline=MIN( jbinall[WHERE( jrayall EQ jrayline )] )
                        minbinline=MAX(jbinall) + 3
                        gvcorners = bin_corner_x_and_y( sinrayedgeazms, cosrayedgeazms, $
                                  jrayline, minbinline, cos_elev_angle[ielev], ground_range, $
                                  gate_space_gv, DO_PRINT=0 )
                        rsl_get_slantr_and_h, ground_range[minbinline], $
                                  tocdf_elev_angle[ielev], slantr, binheight
                        printf, DBunit, 0.0, 0.0, 0.0
                        printf, DBunit, binheight, MEAN(gvcorners[0,*]), MEAN(gvcorners[1,*])
                        printf, DBunit, binheight  ; write a "Missing" point to disconnect polys
                     ENDFOR
              goto, skipthis
                     gvcorners = bin_corner_x_and_y( sinrayedgeazms, cosrayedgeazms, $
                                  jraymax, minbinmaxray, cos_elev_angle[ielev], ground_range, $
                                  gate_space_gv, DO_PRINT=0 )
                     rsl_get_slantr_and_h, ground_range[minbinmaxray], $
                                  tocdf_elev_angle[ielev], slantr, binheight
                     printf, DBunit, 0.0, 0.0, 0.0
                     printf, DBunit, binheight, MEAN(gvcorners[0,*]), MEAN(gvcorners[1,*])
                     printf, DBunit, binheight  ; write a "Missing" point to disconnect polys
                     gvcorners = bin_corner_x_and_y( sinrayedgeazms, cosrayedgeazms, $
                                  jraymin, minbinminray, cos_elev_angle[ielev], ground_range, $
                                  gate_space_gv, DO_PRINT=0 )
                     rsl_get_slantr_and_h, ground_range[minbinminray], $
                                  tocdf_elev_angle[ielev], slantr, binheight
                     printf, DBunit, 0.0, 0.0, 0.0
                     printf, DBunit, binheight, MEAN(gvcorners[0,*]), MEAN(gvcorners[1,*])
                     printf, DBunit, binheight  ; write a "Missing" point to disconnect polys
              skipthis:
                  endif
               ENDIF    ; countclose GT 0
            ENDIF       ; countclose1 GT 0
         ENDIF          ; jpr EQ jpr2write

      ENDFOR    ; TMI footprints

      print, "# TMI footprints in LUT: ", tmi_footprints_in_lut

     ; =========================================================================

     ; END OF TMI-TO-GV RESAMPLING, THIS SWEEP

    ; *********** OPTIONAL PPI PLOTTING FOR SWEEP **********

;      IF keyword_set(plot_PPIs) AND ielev LT 1 THEN BEGIN
      IF keyword_set(plot_PPIs) THEN BEGIN
         titleTMI = 'TMI at ' + TMI_dtime + ' UTC'
         titlegv = siteID+', Elevation = ' + STRING(elev_angle[ielev],FORMAT='(f4.1)') $
                +', '+ text_sweep_times[ielev]
         titles = [titleTMI, titlegv]
        ; make an array of same dimensions as GR averages for surface TMI rainrate
         toplot_2a12_srain = MAKE_ARRAY(numTMIrays, num_elevations_out, /float, VALUE=FLOAT_RANGE_EDGE)
        ; for display, scale TMI rainrate to between 15 and 57 (fit dBZ color scale)
         rr_scale = 42.0/MAX(tocdf_2a12_srain)
        ; plots the surface TMI rainrate regardless of GR elevation angle plotted
        ; -- insert TMI data into the current sweep elevation array position
         toplot_2a12_srain[*,ielev] = tocdf_2a12_srain
        ; only plots those GV points with average dBZs above PR_DBZ_MIN
         plot_elevation_gv_to_pr_z, toplot_2a12_srain*(toplot_2a12_srain GT 0.0)*rr_scale+14.99, $
               tocdf_gr_dbz*(tocdf_gr_dbz GE DBZ_MIN), sitelat, sitelon, $
               tocdf_x_poly, tocdf_y_poly, numTMIrays, ielev, TITLES=titles

         something = ""
         print, ''
;         READ, something, PROMPT='Hit Return to proceed to next level: '
      ENDIF

     ; =========================================================================
     ; =========================================================================

     ; GENERATE THE GV-TO-TMI LUTs FOR THIS SWEEP, ALONG LOCAL VERTICAL

     ; create arrays of (nrays*maxGVbin*4) to hold index of overlapping TMI ray,
     ;    index of bscan bin, and bin-footprint overlap area (these comprise the
     ;    GV-to-TMI many:many lookup table)
      pridxlut_vpr = LONARR(nrays*maxGVbin*4)
      gvidxlut_vpr = ULONARR(nrays*maxGVbin*4)
      overlaplut_vpr = FLTARR(nrays*maxGVbin*4)
      lut_count_vpr = 0UL

     ; Do a 'nearest neighbor' analysis of the TMI data to the b-scan coordinates
     ;    First, start populating the three GV-to-TMI lookup table arrays:
     ;    GV_index, TMI_subarr_index, GV_bin_width * distance_weighting

      gvidxall_vpr = LINDGEN(nbins, nrays)  ; indices into full bscan array

     ; compute GV bin center x,y's for all bins/rays in-range and below 20km: (ALREADY HAVE THESE)

     ; trim the gvidxall_vpr array down to maxGVbin bins to match xbin, etc.
      gvidx_vpr = gvidxall_vpr[0:maxGVbin-1,*]

      FOR jpr=0, numTMIrays-1 DO BEGIN
         plotting = 0
         TMI_index = TMI_master_idx[jpr]
       ; only map GV to non-BOGUS TMI points having one or more above-threshold
       ;   reflectivity bins in the TMI ray
         IF ( TMI_index GE 0 AND TMI_echoes[jpr] NE 0B ) THEN BEGIN
           ; Compute rough distance between TMI footprint x,y and GV b-scan x,y --
           ; if either dX or dY is > max sep, then the footprints don't overlap
            max_sep = max_TMI_footprint_diag_halfwidth
            rufdistx = ABS(x_sfc[jpr]-xbin)  ; array of (maxGVbin, nrays)
            rufdisty = ABS(y_sfc[jpr]-ybin)  ; ditto
            ruff_distance = rufdistx > rufdisty    ; ditto
            closebyidx1 = WHERE( ruff_distance LT max_sep, countclose1 )

            IF ( countclose1 GT 0 ) THEN BEGIN  ; any points pass rough distance check?
              ; check the GV reflectivity values for these bins to see if any
              ;   meet the min dBZ criterion; if none, skip the footprint
               idxcheck = WHERE( bscan[gvidx_vpr[closebyidx1]] GE 0.0, countZOK )
               IF ( countZOK GT 0 ) THEN BEGIN  ; any GV points above min dBZ?
                 ; test the actual center-to-center distance between TMI and GV
                  truedist = sqrt( (x_sfc[jpr]-xbin[closebyidx1])^2  $
                                  +(y_sfc[jpr]-ybin[closebyidx1])^2 )
                  closebyidx = WHERE(truedist le max_sep, countclose )

                  IF ( countclose GT 0 ) THEN BEGIN  ; any points pass true dist check?

                     FOR iclose = 0, countclose-1 DO BEGIN
                       ; get the bin,ray coordinates for the given bscan index
                        jbin = gvidx_vpr[ closebyidx1[closebyidx[iclose]] ] MOD nbins
                        jray = gvidx_vpr[ closebyidx1[closebyidx[iclose]] ] / nbins

                       ; write the lookup table values for this TMI-GV overlap pairing
                        pridxlut_vpr[lut_count_vpr] = TMI_index
                        gvidxlut_vpr[lut_count_vpr] = gvidx_vpr[closebyidx1[closebyidx[iclose]]]
                       ; use a Barnes-like gaussian weighting, using 2*max_sep as the
                       ;  effective radius of influence to increase the edge weights
                       ;  beyond pure linear-by-distance weighting
                        weighting = EXP( - (truedist[closebyidx[iclose]]/max_sep)^2 )
                        overlaplut_vpr[lut_count_vpr] = beam_diam[jbin] * weighting
                        lut_count_vpr = lut_count_vpr+1
                     ENDFOR
                  ENDIF  ; countclose GT 0
               ENDIF     ; countZOK GT 0
            ENDIF        ; countclose1 GT 0
         ENDIF           ; TMI_index ge 0 AND TMI_echoes[jpr] NE 0B

         IF jpr EQ jpr2write THEN BEGIN
            hgtGRcorners = FLTARR(4)

            ;======================== TMI outline part ===============================

            ; plot the TMI footprint outline at the surface only
            IF ielev EQ 0 THEN BEGIN
               file3doutVPR = '/tmp/file3d_outVPR.txt'
               PRINT, "Write output to: ", file3doutVPR
               OPENW, DBunitVPR, file3doutVPR, /GET_LUN
               fileIsOpen = 1
;               printf, DBunitVPR, "binheight        X          Y"
               ; plot a line down the center of the TMI footprints from lowest
               ; elevation to be shown to the highest
               idxmaxelev = MAX(WHERE( (INDGEN(num_elevations_out)-1) MOD 3 EQ 0 ))
               rangeCtr = sqrt(x_sfc[jpr]^2+y_sfc[jpr]^2)
               ; start it from the surface
               printf, DBunitVPR, 0.0, x_sfc[jpr], y_sfc[jpr]
               FOR iplotidx = 0, (idxmaxelev+1)<(num_elevations_out-1) DO BEGIN
                  rsl_get_slantr_and_h, rangeCtr, tocdf_elev_angle[iplotidx], slantrCorn, binheight
                  printf, DBunitVPR, binheight, x_sfc[jpr], y_sfc[jpr]
               ENDFOR
               printf, DBunitVPR, binheight  ; write a "Missing" point to disconnect polys
               ; output footprint x/y/z surface corners
               prcornerssfcx = TMI_x_corners_sfc[*,jpr]
               prcornerssfcy = TMI_y_corners_sfc[*,jpr]
               FOR jcorn=0,4 DO BEGIN
                  icorn = jcorn MOD 4  ; to repeat 1st point at end, close off poly
                  printf, DBunitVPR, 0.0, prcornerssfcx[icorn], prcornerssfcy[icorn]
               ENDFOR
               printf, DBunitVPR, 0.0  ; write a "Missing" point to disconnect polys
            ENDIF

            ;======================== GR outline part ===============================

            ; plot the GR bin outlines
            IF ( countclose1 GT 0 ) THEN BEGIN  ; any points pass rough distance check?
              ; test the actual center-to-center distance between TMI and GV
               truedist = sqrt( (x_sfc[jpr]-xbin[closebyidx1])^2  $
                               +(y_sfc[jpr]-ybin[closebyidx1])^2 )
               closebyidx = WHERE(truedist le max_sep, countclose )
               IF ( countclose GT 0 ) THEN BEGIN  ; any points pass true dist check?
                  FOR iclose = 0, countclose-1 DO BEGIN
                      ; get the bin,ray coordinates for the given bscan index
                      jbin = gvidx[ closebyidx1[closebyidx[iclose]] ] MOD nbins
                      jray = gvidx[ closebyidx1[closebyidx[iclose]] ] / nbins
;                      binheight = height[jbin]       ; depends only on bin # of bscan point
                      gvcorners = bin_corner_x_and_y( sinrayedgeazms, cosrayedgeazms, $
                                     jray, jbin, cos_elev_angle[ielev], ground_range, $
                                     gate_space_gv, DO_PRINT=0 )
                      if (ielev-1) mod 3 eq 0 then begin   ; output every 3d sweep
                         FOR jcorn=0,4 DO BEGIN
                             icorn = jcorn MOD 4  ; to repeat 1st point at end, close off poly
                             ; get the height of the corner points from their ranges
                             rangeCorn = sqrt(gvcorners[0,icorn]^2+gvcorners[1,icorn]^2)
                             rsl_get_slantr_and_h, rangeCorn, tocdf_elev_angle[ielev], slantrCorn, binheight
                             printf, DBunitVPR, binheight, gvcorners[0,icorn], gvcorners[1,icorn]
                             hgtGRcorners[icorn] = binheight
                         ENDFOR
                         printf, DBunitVPR, binheight  ; write a "Missing" point to disconnect polys
                      endif
                  ENDFOR
                  if (ielev-1) mod 3 eq 0 then begin   ; output ray bounds every 3d sweep
                     ; identify 1st/last rays mapped to TMI footprint, draw line from radar
                     ; x/y/z (= 0,0,0) to these GR gates
                     jbinall = gvidx[closebyidx1[closebyidx]] MOD nbins
                     jrayall = gvidx[closebyidx1[closebyidx]] / nbins
                     jraymax = MAX( jrayall, MIN=jraymin)
                     jraymid = (jraymin + jraymax)/2              ; to do middle ray only

                     if (ielev-1) eq 0 then begin
                        ; plot all GR ray center lines for this sweep
                        jraystart=jraymin
                        jrayend=jraymax
                     endif else begin
                        ; plot the GR ray center line for just the middle ray
                        jraystart=(jraymin + jraymax)/2
                        jrayend=jraystart
                     endelse
                     FOR jrayline = jraystart, jrayend DO BEGIN    ; to do all rays
                        minbinline=MAX(jbinall) + 3
;                     FOR jrayline = jraymid, jraymid DO BEGIN     ; to do middle ray only
;                        minbinline=MIN( jbinall[WHERE( jrayall EQ jrayline )] )
                        gvcorners = bin_corner_x_and_y( sinrayedgeazms, cosrayedgeazms, $
                                  jrayline, minbinline, cos_elev_angle[ielev], ground_range, $
                                  gate_space_gv, DO_PRINT=0 )
                        rsl_get_slantr_and_h, ground_range[minbinline], $
                                  tocdf_elev_angle[ielev], slantr, binheight
                        printf, DBunitVPR, 0.0, 0.0, 0.0
                        printf, DBunitVPR, binheight, MEAN(gvcorners[0,*]), MEAN(gvcorners[1,*])
                        printf, DBunitVPR, binheight  ; write a "Missing" point to disconnect polys
                     ENDFOR
                  endif
               ENDIF    ; countclose GT 0
            ENDIF       ; countclose1 GT 0
         ENDIF          ; jpr EQ jpr2write

      ENDFOR    ; TMI footprints

   ENDFOR     ; each elevation sweep: ielev = 0, num_elevations_out - 1

;  >>>>>>>>>>>>>>>>> END OF TMI-GV VOLUME MATCHING, ALL SWEEPS <<<<<<<<<<<<<<<<<<

   IF fileIsOpen EQ 1 THEN BEGIN
      FREE_LUN, DBunit
      FREE_LUN, DBunitVPR
   ENDIF
   IF plotting EQ 1 OR jpr2write NE -1 THEN WDELETE

;  ********** BEGIN OPTIONAL SCORE COMPUTATIONS, ALL SWEEPS ***************
   IF keyword_set(run_scores) THEN BEGIN

   ; overall scores, all sweeps
   print, ""
   print, "All Sweeps Combined:"
   PRINT, ""
   PRINT, "End of scores/processing for ", siteID
   PRINT, ""

   ENDIF  ; run_scores

; ************ END OPTIONAL SCORE COMPUTATIONS, ALL SWEEPS *****************
