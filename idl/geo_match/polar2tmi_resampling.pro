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
; 10/18/13 by Bob Morris, GPM GV (SAIC)
;  - Added processing of GR rainrate field from radar data files, when present.
;;
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

  ; Retrieve the desired radar volume from the radar structure
   zvolume = rsl_get_volume( radar, z_vol_num )
   IF have_gv_rr THEN rrvolume = rsl_get_volume( radar, rr_vol_num )

  ; Map this GV radar's data to the these TMI footprints, sweep by sweep, at the
  ;   locations where TMI rays intersect the elevation sweeps:

;  >>>>>>>>>>>>>> BEGINNING OF TMI-GV VOLUME MATCHING, ALL SWEEPS <<<<<<<<<<<<<<<

   FOR ielev = 0, num_elevations_out - 1 DO BEGIN
      print, ""
      print, "Elevation: ", tocdf_elev_angle[ielev]

     ; read in the sweep structure for the elevation
      sweep = rsl_get_sweep( zvolume, SWEEP_INDEX=idx_uniq_elevs[ielev] )
      IF have_gv_rr THEN $
         rr_sweep = rsl_get_sweep( rrvolume, SWEEP_INDEX=idx_uniq_elevs[ielev] )
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

     ; arrays to hold the along-ground range, beam height, and beam x-sect size
     ;   at each gate:
      ground_range = FLTARR(nbins)
      height = FLTARR(nbins)
      beam_diam = FLTARR(nbins)

     ; create a GV dbz data array of [nbins,nrays] (distance vs angle 'b-scan')
      bscan = FLTARR(nbins,nrays)
      IF have_gv_rr THEN rr_bscan = FLTARR(nbins,nrays)
     ; read each GV ray into the b-scan column
      FOR iray = 0, nrays-1 DO BEGIN
         ray = sweep.ray[iray]
         bscan[*,iray] = ray.range[0:nbins-1]      ; drop the 'padding' bins
         IF have_gv_rr THEN BEGIN
            rr_ray = rr_sweep.ray[iray]
            rr_bscan[*,iray] = rr_ray.range[0:nbins-1]
         ENDIF
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
      tmi_footprints_with_gr_echo=0

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
                                  [REFORM(gvcorners[1,*]),REFORM(gvcorners[1,*])], $
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
         IF ( nplotted EQ askagain ) THEN BEGIN
            PRINT, ielev, askagain, KEYWORD_SET(plot_bins), ""
            PRINT, "Had enough yet? (Y/N)"
            reply = plot_bins_bailout()
            IF ( reply EQ 'Y' ) THEN plot_bins = 0
         ENDIF
         ENDIF
      ENDFOR    ; TMI footprints

      print, "# TMI footprints in LUT: ", tmi_footprints_in_lut

     ; =========================================================================
     ; COMPUTE THE GV REFLECTIVITY AVERAGES

     ; The LUTs are complete for this sweep, now do the resampling/averaging.
     ; Build the TMI-GV intersection "data cone" for the sweep, in TMI coordinates
     ; (horizontally) and within the vertical layer defined by the GV radar
     ; beam top/bottom:

      FOR jpr=0, numTMIrays-1 DO BEGIN
        ; init output variables defined/set in loop/if
         writeMISSING = 1
         countGVpts = 0UL              ; # GV bins mapped to this TMI footprint
         n_gr_points_rejected = 0UL    ; # of above that are below GV dBZ cutoff
         n_gr_rr_points_rejected = 0UL ; # of above that are below GV RR cutoff
         TMI_gates_expected = 0UL       ; # TMI gates within the sweep vert. bounds

         TMI_index = TMI_master_idx[jpr]

         IF ( TMI_index GE 0 AND TMI_echoes[jpr] NE 0B ) THEN BEGIN

           ; expand this TMI master index into its scan,ray coordinates.  Use
           ;   surfaceType as the subscripted data array
            rayscan = ARRAY_INDICES( surfaceType, TMI_index )
            rayTMI = rayscan[1] & scanTMI = rayscan[0]

           ; grab indices of all LUT points mapped to this TMI sample:
            thisTMIsLUTindices = WHERE( pridxlut EQ TMI_index, countGVpts)

            IF ( countGVpts GT 0 ) THEN BEGIN    ; this should be a formality
               writeMissing = 0

              ; get indices of all bscan points mapped to this TMI sample:
               thisTMIsGVindices = gvidxlut[thisTMIsLUTindices]
              ; convert the array of gv bscan 1-D indices into array of bin,ray coordinates
               binray = ARRAY_INDICES( bscan, thisTMIsGVindices )

              ; compute bin volume of GV bins overlapping this TMI footprint
               bindepths = beam_diam[binray[0,*]]  ; depends only on bin # of bscan point
               binhgts = height[binray[0,*]]       ; depends only on bin # of bscan point
               binvols = bindepths * overlaplut[thisTMIsLUTindices]

               dbzvals = bscan[thisTMIsGVindices]
               zgoodidx = WHERE( dbzvals GE dBZ_min, countGVgood )
               zbadidx = WHERE( dbzvals LT 0.0, countGVbad )
               n_gr_points_rejected = countGVpts - countGVgood

               IF ( countGVgood GT 0 ) THEN BEGIN
                  tmi_footprints_with_gr_echo = tmi_footprints_with_gr_echo + 1
                 ; compute volume-weighted GV reflectivity average in Z space,
                 ;   then convert back to dBZ
                  IF ( countGVbad GT 0 ) THEN dbzvals[zbadidx] = 0.0
                  z_avg_gv = TOTAL( 10.^(0.1*dbzvals) * binvols ) $
                              / TOTAL( binvols )
                  dbz_avg_gv = 10.*ALOG10(z_avg_gv)
                  dbz_max_gv = MAX(dbzvals)
                 ; compute standard deviation of good GR gates in dBZ space
                  IF N_ELEMENTS(dbzvals) LT 2 THEN dbz_stddev_gv = 0.0 $
                  ELSE dbz_stddev_gv = STDDEV(dbzvals)
;                  print, "dbz_avg_gv = ", dbz_avg_gv
;                  print, "GV dBZs:"
;                  print, dbzvals[zgoodidx]
;                  print, binvols[zgoodidx]
               ENDIF ELSE BEGIN
                 ; handle where no GV Z values meet criteria
                  dbz_avg_gv = Z_BELOW_THRESH
                  dbz_stddev_gv = Z_BELOW_THRESH
                  dbz_max_gv = Z_BELOW_THRESH
               ENDELSE

               IF have_gv_rr THEN BEGIN
                  gvrrvals = rr_bscan[thisTMIsGVindices]
                  gvrrgoodidx = WHERE( gvrrvals GE TMI_RAIN_MIN, countGVRRgood )
                  gvrrbadidx = WHERE( gvrrvals LT 0.0, countGVRRbad )
                  n_gr_rr_points_rejected = countGVpts - countGVRRgood

                  IF ( countGVRRgood GT 0 ) THEN BEGIN
                    ; compute volume-weighted GV rainrate average
                     IF ( countGVRRbad GT 0 ) THEN gvrrvals[gvrrbadidx] = 0.0
                     rr_avg_gv = TOTAL( gvrrvals * binvols ) / TOTAL( binvols )
                     rr_max_gv = MAX(gvrrvals)
                    ; compute standard deviation of good GR gates
                     IF N_ELEMENTS(gvrrvals) LT 2 THEN rr_stddev_gv = 0.0 $
                     ELSE rr_stddev_gv = STDDEV(gvrrvals)
;                     print, "rr_avg_gv = ", rr_avg_gv
;                     print, "GV Rainrates:"
;                     print, gvrrvals[gvrrgoodidx]
;                     print, binvols[gvrrgoodidx]
                  ENDIF ELSE BEGIN
                    ; handle where no GV RR values meet criteria
                     rr_avg_gv = SRAIN_BELOW_THRESH
                     rr_stddev_gv = SRAIN_BELOW_THRESH
                     rr_max_gv = SRAIN_BELOW_THRESH
                  ENDELSE
               ENDIF

              ; compute mean height above surface of GV beam top and beam bottom
              ;   for all GV points geometrically mapped to this TMI point
               meantop = MEAN( binhgts + bindepths/2.0 )
               meanbotm = MEAN( binhgts - bindepths/2.0 )
              ; compute height above ellipsoid for computing TMI gates that
              ; intersect the GR beam boundaries.  Assume ellipsoid and geoid
              ; (MSL surface) are the same
               meantopMSL = meantop + siteElev
               meanbotmMSL = meanbotm + siteElev
            ENDIF                  ; countGVpts GT 0

         ENDIF ELSE BEGIN          ; TMI_index GE 0 AND TMI_echoes[jpr] NE 0B

           ; case where no 2A12 TMI gates in the ray are above rain threshold,
           ;   set the averages to the BELOW_THRESH special values
	    IF ( TMI_index GE 0 AND TMI_echoes[jpr] EQ 0B ) THEN BEGIN
               writeMissing = 0
               dbz_avg_gv = Z_BELOW_THRESH
               dbz_stddev_gv = Z_BELOW_THRESH
               dbz_max_gv = Z_BELOW_THRESH
               rr_avg_gv = SRAIN_BELOW_THRESH
               rr_stddev_gv = SRAIN_BELOW_THRESH
               rr_max_gv = SRAIN_BELOW_THRESH
	       meantop = 0.0    ; should calculate something for this
	       meanbotm = 0.0   ; ditto
	    ENDIF
	 ENDELSE

     ; =========================================================================
     ; WRITE COMPUTED AVERAGES AND METADATA TO OUTPUT ARRAYS FOR NETCDF

         IF ( writeMissing EQ 0 )  THEN BEGIN
         ; normal rainy footprint, write computed science variables
                  tocdf_gr_dbz[jpr,ielev] = dbz_avg_gv
                  tocdf_gr_stddev[jpr,ielev] = dbz_stddev_gv
                  tocdf_gr_max[jpr,ielev] = dbz_max_gv
                  IF have_gv_rr THEN BEGIN
                     tocdf_gr_rr[jpr,ielev] = rr_avg_gv
                     tocdf_gr_rr_stddev[jpr,ielev] = rr_stddev_gv
                     tocdf_gr_rr_max[jpr,ielev] = rr_max_gv
                  ENDIF
                  tocdf_top_hgt[jpr,ielev] = meantop
                  tocdf_botm_hgt[jpr,ielev] = meanbotm
         ENDIF ELSE BEGIN
            CASE TMI_index OF
                -1  :  BREAK
                      ; is range-edge point, science values in array were already
                      ;   initialized to special values for this, so do nothing
                -2  :  BEGIN
                      ; off-scan-edge point, set science values to special values
                          tocdf_gr_dbz[jpr,ielev] = FLOAT_OFF_EDGE
                          tocdf_gr_stddev[jpr,ielev] = FLOAT_OFF_EDGE
                          tocdf_gr_max[jpr,ielev] = FLOAT_OFF_EDGE
                          IF have_gv_rr THEN BEGIN
                             tocdf_gr_rr[jpr,ielev] = FLOAT_OFF_EDGE
                             tocdf_gr_rr_stddev[jpr,ielev] = FLOAT_OFF_EDGE
                             tocdf_gr_rr_max[jpr,ielev] = FLOAT_OFF_EDGE
                          ENDIF
                          IF ielev EQ 0 THEN tocdf_2a12_srain[jpr] = FLOAT_OFF_EDGE
                          tocdf_top_hgt[jpr,ielev] = FLOAT_OFF_EDGE
                          tocdf_botm_hgt[jpr,ielev] = FLOAT_OFF_EDGE
                       END
              ELSE  :  BEGIN
                      ; data internal issues, set science values to missing
                          tocdf_gr_dbz[jpr,ielev] = Z_MISSING
                          tocdf_gr_stddev[jpr,ielev] = Z_MISSING
                          tocdf_gr_max[jpr,ielev] = Z_MISSING
                          IF have_gv_rr THEN BEGIN
                             tocdf_gr_rr[jpr,ielev] = Z_MISSING
                             tocdf_gr_rr_stddev[jpr,ielev] = Z_MISSING
                             tocdf_gr_rr_max[jpr,ielev] = Z_MISSING
                          ENDIF
                          IF ielev EQ 0 THEN tocdf_2a12_srain[jpr] = Z_MISSING
                          tocdf_top_hgt[jpr,ielev] = Z_MISSING
                          tocdf_botm_hgt[jpr,ielev] = Z_MISSING
                       END
            ENDCASE
         ENDELSE

        ; assign the computed meta values to the output array slots
         tocdf_gr_rejected[jpr,ielev] = UINT(n_gr_points_rejected)
         IF have_gv_rr THEN tocdf_gr_rr_rejected[jpr,ielev] = UINT(n_gr_rr_points_rejected)
         tocdf_gr_expected[jpr,ielev] = UINT(countGVpts)

      ENDFOR  ; each TMI subarray point: jpr=0, numTMIrays-1

      print, "# TMI footprints with GR echo: ", tmi_footprints_with_gr_echo

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
;      xbin = FLTARR(maxGVbin, nrays)
;      ybin = FLTARR(maxGVbin, nrays)
;      FOR jray=0, nrays-1 DO BEGIN
;         xbin[*,jray] = ground_range[0:maxGVbin-1] * sinrayazms[jray]
;         ybin[*,jray] = ground_range[0:maxGVbin-1] * cosrayazms[jray]
;      ENDFOR

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

      ENDFOR    ; TMI footprints

     ; =========================================================================
     ; COMPUTE THE GV REFLECTIVITY AVERAGES, ALONG LOCAL VERTICAL

     ; The LUTs are complete for this sweep, now do the resampling/averaging.
     ; Build the TMI-GV intersection "data cone" for the sweep, in TMI coordinates
     ; (horizontally) and within the vertical layer defined by the GV radar
     ; beam top/bottom:

      FOR jpr=0, numTMIrays-1 DO BEGIN
        ; init output variables defined/set in loop/if
         writeMissing_vpr = 1
         countGVpts_vpr = 0UL              ; # GV bins mapped to this TMI footprint
         n_gr_vpr_points_rejected = 0UL    ; # of above that are below GV dBZ cutoff
         n_gr_rr_vpr_points_rejected = 0UL ; # of above that are below GV RR cutoff
         TMI_gates_expected = 0UL       ; # TMI gates within the sweep vert. bounds

         TMI_index = TMI_master_idx[jpr]

         IF ( TMI_index GE 0 AND TMI_echoes[jpr] NE 0B ) THEN BEGIN

           ; expand this TMI master index into its scan,ray coordinates.  Use
           ;   surfaceType as the subscripted data array
            rayscan = ARRAY_INDICES( surfaceType, TMI_index )
            rayTMI = rayscan[1] & scanTMI = rayscan[0]

           ; grab indices of all LUT points mapped to this TMI sample:
            thisTMIsLUTindices = WHERE( pridxlut_vpr EQ TMI_index, countGVpts_vpr)

            IF ( countGVpts_vpr GT 0 ) THEN BEGIN    ; this should be a formality
               writeMissing_vpr = 0

              ; get indices of all bscan points mapped to this TMI sample:
               thisTMIsGVindices = gvidxlut_vpr[thisTMIsLUTindices]
              ; convert the array of gv bscan 1-D indices into array of bin,ray coordinates
               binray = ARRAY_INDICES( bscan, thisTMIsGVindices )

              ; compute bin volume of GV bins overlapping this TMI footprint
               bindepths = beam_diam[binray[0,*]]  ; depends only on bin # of bscan point
               binhgts = height[binray[0,*]]       ; depends only on bin # of bscan point
               binvols = bindepths * overlaplut_vpr[thisTMIsLUTindices]

               dbzvals = bscan[thisTMIsGVindices]
               zgoodidx = WHERE( dbzvals GE dBZ_min, countGVgood )
               zbadidx = WHERE( dbzvals LT 0.0, countGVbad )
               n_gr_vpr_points_rejected = countGVpts_vpr - countGVgood

               IF ( countGVgood GT 0 ) THEN BEGIN
                 ; compute volume-weighted GV reflectivity average in Z space,
                 ;   then convert back to dBZ
                  IF ( countGVbad GT 0 ) THEN dbzvals[zbadidx] = 0.0
                  z_avg_gr_vpr = TOTAL( 10.^(0.1*dbzvals) * binvols ) $
                              / TOTAL( binvols )
                  dbz_avg_gr_vpr = 10.*ALOG10(z_avg_gr_vpr)
                  dbz_max_gr_vpr = MAX(dbzvals)
                 ; compute standard deviation of good GR gates in dBZ space
                  IF N_ELEMENTS(dbzvals) LT 2 THEN dbz_stddev_gr_vpr = 0.0 $
                  ELSE dbz_stddev_gr_vpr = STDDEV(dbzvals)
;                  print, "dbz_avg_gr_vpr = ", dbz_avg_gr_vpr
;                  print, "GV dBZs:"
;                  print, dbzvals[zgoodidx]
;                  print, binvols[zgoodidx]
               ENDIF ELSE BEGIN
                 ; handle where no GV Z values meet criteria
                  dbz_avg_gr_vpr = Z_BELOW_THRESH
                  dbz_stddev_gr_vpr = Z_BELOW_THRESH
                  dbz_max_gr_vpr = Z_BELOW_THRESH
               ENDELSE

               IF have_gv_rr THEN BEGIN
                  gvrrvals = rr_bscan[thisTMIsGVindices]
                  gvrrgoodidx = WHERE( gvrrvals GE TMI_RAIN_MIN, countGVRRgood )
                  gvrrbadidx = WHERE( gvrrvals LT 0.0, countGVRRbad )
                  n_gr_rr_vpr_points_rejected = countGVpts_vpr - countGVRRgood

                  IF ( countGVRRgood GT 0 ) THEN BEGIN
                    ; compute volume-weighted GV rainrate average
                     IF ( countGVRRbad GT 0 ) THEN gvrrvals[gvrrbadidx] = 0.0
                     rr_avg_gv_vpr = TOTAL( gvrrvals * binvols ) / TOTAL( binvols )
                     rr_max_gv_vpr = MAX(gvrrvals)
                    ; compute standard deviation of good GR gates
                     IF N_ELEMENTS(gvrrvals) LT 2 THEN rr_stddev_gv_vpr = 0.0 $
                     ELSE rr_stddev_gv_vpr = STDDEV(gvrrvals)
;                     print, "rr_avg_gv_vpr = ", rr_avg_gv_vpr
;                     print, "GV_vpr Rainrates:"
;                     print, gvrrvals[gvrrgoodidx]
;                     print, binvols[gvrrgoodidx]
                  ENDIF ELSE BEGIN
                    ; handle where no GV RR values meet criteria
                     rr_avg_gv_vpr = SRAIN_BELOW_THRESH
                     rr_stddev_gv_vpr = SRAIN_BELOW_THRESH
                     rr_max_gv_vpr = SRAIN_BELOW_THRESH
                  ENDELSE
               ENDIF

              ; compute mean height above surface of GV beam top and beam bottom
              ;   for all GV points geometrically mapped to this TMI point
               meantop_vpr = MEAN( binhgts + bindepths/2.0 )
               meanbotm_vpr = MEAN( binhgts - bindepths/2.0 )
              ; compute height above ellipsoid for computing TMI gates that
              ; intersect the GR beam boundaries.  Assume ellipsoid and geoid
              ; (MSL surface) are the same
               meantopMSL_vpr = meantop_vpr + siteElev
               meanbotmMSL_vpr = meanbotm_vpr + siteElev
            ENDIF                  ; countGVpts_vpr GT 0

         ENDIF ELSE BEGIN          ; TMI_index GE 0 AND TMI_echoes[jpr] NE 0B

           ; case where no 2A12 TMI gates in the ray are above rain threshold,
           ;   set the averages to the BELOW_THRESH special values
	    IF ( TMI_index GE 0 AND TMI_echoes[jpr] EQ 0B ) THEN BEGIN
               writeMissing_vpr = 0
               dbz_avg_gr_vpr = Z_BELOW_THRESH
               dbz_stddev_gr_vpr = Z_BELOW_THRESH
               dbz_max_gr_vpr = Z_BELOW_THRESH
               rr_avg_gv_vpr = SRAIN_BELOW_THRESH
               rr_stddev_gv_vpr = SRAIN_BELOW_THRESH
               rr_max_gv_vpr = SRAIN_BELOW_THRESH
	       meantop_vpr = 0.0    ; should calculate something for this
	       meanbotm_vpr = 0.0   ; ditto
	    ENDIF
	 ENDELSE

     ; =========================================================================
     ; WRITE COMPUTED AVERAGES AND METADATA TO OUTPUT ARRAYS FOR NETCDF

         IF ( writeMissing_vpr EQ 0 )  THEN BEGIN
         ; normal rainy footprint, write computed science variables
                  tocdf_gr_vpr_dbz[jpr,ielev] = dbz_avg_gr_vpr
                  tocdf_gr_StdDev_VPR[jpr,ielev] = dbz_stddev_gr_vpr
                  tocdf_gr_Max_VPR[jpr,ielev] = dbz_max_gr_vpr
                  IF have_gv_rr THEN BEGIN
                     tocdf_gr_rr_vpr[jpr,ielev] = rr_avg_gv_vpr
                     tocdf_gr_rr_stddev_vpr[jpr,ielev] = rr_stddev_gv_vpr
                     tocdf_gr_rr_max_vpr[jpr,ielev] = rr_max_gv_vpr
                  ENDIF
                  tocdf_top_hgt_vpr[jpr,ielev] = meantop_vpr
                  tocdf_botm_hgt_vpr[jpr,ielev] = meanbotm_vpr
         ENDIF ELSE BEGIN
            CASE TMI_index OF
                -1  :  BREAK
                      ; is range-edge point, science values in array were already
                      ;   initialized to special values for this, so do nothing
                -2  :  BEGIN
                      ; off-scan-edge point, set science values to special values
                          tocdf_gr_vpr_dbz[jpr,ielev] = FLOAT_OFF_EDGE
                          tocdf_gr_StdDev_VPR[jpr,ielev] = FLOAT_OFF_EDGE
                          tocdf_gr_Max_VPR[jpr,ielev] = FLOAT_OFF_EDGE
                          IF have_gv_rr THEN BEGIN
                             tocdf_gr_rr_VPR[jpr,ielev] = FLOAT_OFF_EDGE
                             tocdf_gr_rr_stddev_VPR[jpr,ielev] = FLOAT_OFF_EDGE
                             tocdf_gr_rr_max_VPR[jpr,ielev] = FLOAT_OFF_EDGE
                          ENDIF
;                          IF ielev EQ 0 THEN tocdf_2a12_srain[jpr] = FLOAT_OFF_EDGE
                          tocdf_top_hgt_vpr[jpr,ielev] = FLOAT_OFF_EDGE
                          tocdf_botm_hgt_vpr[jpr,ielev] = FLOAT_OFF_EDGE
                       END
              ELSE  :  BEGIN
                      ; data internal issues, set science values to missing
                          tocdf_gr_vpr_dbz[jpr,ielev] = Z_MISSING
                          tocdf_gr_StdDev_VPR[jpr,ielev] = Z_MISSING
                          tocdf_gr_Max_VPR[jpr,ielev] = Z_MISSING
                          IF have_gv_rr THEN BEGIN
                             tocdf_gr_rr_VPR[jpr,ielev] = Z_MISSING
                             tocdf_gr_rr_stddev_VPR[jpr,ielev] = Z_MISSING
                             tocdf_gr_rr_max_VPR[jpr,ielev] = Z_MISSING
                          ENDIF
;                          IF ielev EQ 0 THEN tocdf_2a12_srain[jpr] = Z_MISSING
                          tocdf_top_hgt_vpr[jpr,ielev] = Z_MISSING
                          tocdf_botm_hgt_vpr[jpr,ielev] = Z_MISSING
                       END
            ENDCASE
         ENDELSE

        ; assign the computed meta values to the output array slots
         tocdf_gr_vpr_rejected[jpr,ielev] = UINT(n_gr_vpr_points_rejected)
         IF have_gv_rr THEN tocdf_gr_rr_VPR_rejected[jpr,ielev] = UINT(n_gr_rr_vpr_points_rejected)
         tocdf_gr_vpr_expected[jpr,ielev] = UINT(countGVpts_vpr)

      ENDFOR    ; TMI footprints

     ; =========================================================================

   ENDFOR     ; each elevation sweep: ielev = 0, num_elevations_out - 1

;  >>>>>>>>>>>>>>>>> END OF TMI-GV VOLUME MATCHING, ALL SWEEPS <<<<<<<<<<<<<<<<<<



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
