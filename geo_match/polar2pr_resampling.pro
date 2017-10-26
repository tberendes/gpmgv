;===============================================================================
;+
; Copyright © 2008, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; polar2pr_resampling.pro          Morris/SAIC/GPM_GV      September 2008
;
; DESCRIPTION
; -----------
; This file contains the PR-GV volume matching, data plotting, and score
; computations sections of the code for the procedure polar2pr.  See file
; polar2pr.pro for a description of the full procedure.
;
; NOTE: THIS FILE MUST BE "INCLUDED" INSIDE THE PROCEDURE polar2pr, IT IS *NOT*
;       A COMPLETE IDL PROCEDURE AND CANNOT BE COMPILED OR RUN ON ITS OWN !!
;
; HISTORY
; -------
; 9/2008 by Bob Morris, GPM GV (SAIC)
;  - Created.
; 10/2008 by Bob Morris, GPM GV (SAIC)
;  - Implemented selective PR footprint LUT/averages generation
; 2/6/2009 by Bob Morris, GPM GV (SAIC)
;  - Section break and in-line documentation enhancements
;  - Moved prcorners definition inside IF PLOT_BINS block
; 6/16/2010 by Bob Morris, GPM GV (SAIC)
;  - Replace meanBB calculation with call to get_mean_bb_height().
; 9/10/2010 by Bob Morris, GPM GV (SAIC)
;  - Account for 'siteElev' in computing PR gate numbers at a given beam height
;    above ground level.
; 11/11/10 by Bob Morris, GPM GV (SAIC)
;  - Compute variables 'threeDreflectMax' and 'threeDreflectStdDev' for GR
;    reflectivity.
; 05/10/11 by Bob Morris, GPM GV (SAIC)
;  - Fixed major bug where parallax-corrected PR footprint x and y values for
;    all elevations used only the corrections for the GR base scan, offsetting
;    the GR volume from the PR volume for off-nadir scans for sweeps other than
;    the base scan.  Found error in polar2tmi_resampling.pro by activating
;    PLOT_BINS and noting mismatch between TMI footprint and GR bins, where the
;    parallax is more extreme and obvious.
; 7/18/13 by Bob Morris, GPM GV (SAIC)
;  - Added processing of GR rainrate field from radar data files, when present.
; 7/26/13 by Bob Morris, GPM GV (SAIC)
;  - Added definition of rr_avg_gv, rr_stddev_gv, and rr_max_gv for case where
;    no above-threshold echoes exist in the PR ray.
; 8/12/13 by Bob Morris, GPM GV (SAIC)
;  - Fixed MAJOR bug where Z bscan data were being averaged for rain rate rather
;    than the RR bscan's data.
; 1/27/14 by Bob Morris, GPM GV (SAIC)
;  - Added processing of GR HID, D0, and Nw fields from radar data files, when
;    present.
; 2/7/14 by Bob Morris, GPM GV (SAIC)
;  - Added Max and StdDev variables and presence flags for Dzero and Nw fields
;    to the variables computed and written to the netCDF files.
; 2/11/14 by Bob Morris, GPM GV (SAIC)
;  - Added mean, maximum, and StdDev of Dual-pol variables Zdr, Kdp, and RHOhv,
;    along with their presence flags and UF IDs, for file version 2.3.
; 2/17/14 by Bob Morris, GPM GV (SAIC)
;  - Replace SRAIN_BELOW_THRESH with DR_KD_MISSING from radar_dp_parameters()
;    for Kdp, Zdr in no_echoes situation
;
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;===============================================================================

  ; Retrieve the desired radar volume(s) from the radar structure
   zvolume = rsl_get_volume( radar, z_vol_num )
   IF have_gv_zdr THEN zdrvolume = rsl_get_volume( radar, zdr_vol_num )
   IF have_gv_kdp THEN kdpvolume = rsl_get_volume( radar, kdp_vol_num )
   IF have_gv_rhohv THEN rhohvvolume = rsl_get_volume( radar, rhohv_vol_num )
   IF have_gv_rr THEN rrvolume = rsl_get_volume( radar, rr_vol_num )
   IF have_gv_hid THEN hidvolume = rsl_get_volume( radar, hid_vol_num )
   IF have_gv_dzero THEN dzerovolume = rsl_get_volume( radar, dzero_vol_num )
   IF have_gv_nw THEN nwvolume = rsl_get_volume( radar, nw_vol_num )

  ; Map this GV radar's data to the these PR footprints, sweep by sweep, at the
  ;   locations where PR rays intersect the elevation sweeps:

;  >>>>>>>>>>>>>> BEGINNING OF PR-GV VOLUME MATCHING, ALL SWEEPS <<<<<<<<<<<<<<<

   FOR ielev = 0, num_elevations_out - 1 DO BEGIN
      print, ""
      print, "Elevation: ", tocdf_elev_angle[ielev]

     ; read in the sweep structure for the elevation
      sweep = rsl_get_sweep( zvolume, SWEEP_INDEX=idx_uniq_elevs[ielev] )
      IF have_gv_zdr THEN $
         zdr_sweep = rsl_get_sweep( zdrvolume, SWEEP_INDEX=idx_uniq_elevs[ielev] )
      IF have_gv_kdp THEN $
         kdp_sweep = rsl_get_sweep( kdpvolume, SWEEP_INDEX=idx_uniq_elevs[ielev] )
      IF have_gv_rhohv THEN $
         rhohv_sweep = rsl_get_sweep( rhohvvolume, SWEEP_INDEX=idx_uniq_elevs[ielev] )
      IF have_gv_rr THEN $
         rr_sweep = rsl_get_sweep( rrvolume, SWEEP_INDEX=idx_uniq_elevs[ielev] )
      IF have_gv_hid THEN hid_sweep = rsl_get_sweep( hidvolume, $
                                      SWEEP_INDEX=idx_uniq_elevs[ielev] )
      IF have_gv_dzero THEN dzero_sweep = rsl_get_sweep( dzerovolume, $
                                          SWEEP_INDEX=idx_uniq_elevs[ielev] )
      IF have_gv_nw THEN $
         nw_sweep = rsl_get_sweep( nwvolume, SWEEP_INDEX=idx_uniq_elevs[ielev] )
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
      IF have_gv_zdr THEN zdr_bscan = FLTARR(nbins,nrays)
      IF have_gv_kdp THEN kdp_bscan = FLTARR(nbins,nrays)
      IF have_gv_rhohv THEN rhohv_bscan = FLTARR(nbins,nrays)
      IF have_gv_rr THEN rr_bscan = FLTARR(nbins,nrays)
      IF have_gv_hid THEN hid_bscan = FLTARR(nbins,nrays)
      IF have_gv_dzero THEN dzero_bscan = FLTARR(nbins,nrays)
      IF have_gv_nw THEN nw_bscan = FLTARR(nbins,nrays)
     ; read each GV ray into the b-scan column
      FOR iray = 0, nrays-1 DO BEGIN
         ray = sweep.ray[iray]
         bscan[*,iray] = ray.range[0:nbins-1]      ; drop the 'padding' bins
         IF have_gv_zdr THEN BEGIN
            zdr_ray = zdr_sweep.ray[iray]
            zdr_bscan[*,iray] = zdr_ray.range[0:nbins-1]
         ENDIF
         IF have_gv_kdp THEN BEGIN
            kdp_ray = kdp_sweep.ray[iray]
            kdp_bscan[*,iray] = kdp_ray.range[0:nbins-1]
         ENDIF
         IF have_gv_rhohv THEN BEGIN
            rhohv_ray = rhohv_sweep.ray[iray]
            rhohv_bscan[*,iray] = rhohv_ray.range[0:nbins-1]
         ENDIF
         IF have_gv_rr THEN BEGIN
            rr_ray = rr_sweep.ray[iray]
            rr_bscan[*,iray] = rr_ray.range[0:nbins-1]
         ENDIF
         IF have_gv_hid THEN BEGIN
            hid_ray = hid_sweep.ray[iray]
            hid_bscan[*,iray] = hid_ray.range[0:nbins-1]
         ENDIF
         IF have_gv_dzero THEN BEGIN
            dzero_ray = dzero_sweep.ray[iray]
            dzero_bscan[*,iray] = dzero_ray.range[0:nbins-1]
         ENDIF
         IF have_gv_nw THEN BEGIN
            nw_ray = nw_sweep.ray[iray]
            nw_bscan[*,iray] = nw_ray.range[0:nbins-1]
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
          (max_ranges[ielev]+max_PR_footprint_diag_halfwidth), bins2do2 )
      maxGVbin2 = bins2do2 - 1 > 0
      maxGVbin = maxGVbin < maxGVbin2

     ; =========================================================================
     ; GENERATE THE GV-TO-PR LUTs FOR THIS SWEEP

     ; create arrays of (nrays*maxGVbin*4) to hold index of overlapping PR ray,
     ;    index of bscan bin, and bin-footprint overlap area (these comprise the
     ;    GV-to-PR many:many lookup table). These are 4 times the size of the
     ;    height/range clipped bscan array, such that a given bin can map to up
     ;    to 4 different PR footprints
      pridxlut = LONARR(nrays*maxGVbin*4)
      gvidxlut = ULONARR(nrays*maxGVbin*4)
      overlaplut = FLTARR(nrays*maxGVbin*4)
      lut_count = 0UL

     ; Do a 'nearest neighbor' analysis of the PR data to the b-scan coordinates
     ;    First, start populating the three GV-to-PR lookup table arrays:
     ;    GV_index, PR_subarr_index, GV_bin_width * distance_weighting

      gvidxall = LINDGEN(nbins, nrays)  ; indices into full bscan array

     ; compute GV bin center x,y's and max axis lengths for all bins/rays
     ;   in-range and below 20km:
      xbin = FLTARR(maxGVbin, nrays)
      ybin = FLTARR(maxGVbin, nrays)
;      GV_bin_max_axis_len = FLTARR(maxGVbin, nrays)
      FOR jray=0, nrays-1 DO BEGIN
         xbin[*,jray] = ground_range[0:maxGVbin-1] * sinrayazms[jray]
         ybin[*,jray] = ground_range[0:maxGVbin-1] * cosrayazms[jray]
;         GV_bin_max_axis_len[*,jray] = beam_diam[0:maxGVbin-1] > gate_space_gv
      ENDFOR

     ; trim the gvidxall array down to maxGVbin bins to match xbin, etc.
      gvidx = gvidxall[0:maxGVbin-1,*]


      IF KEYWORD_SET(plot_bins) AND (ielev EQ num_elevations_out/2 - 1) THEN BEGIN
         prcorners = FLTARR(2,4)               ;for current PR footprint's corners
         askagain = 50 < numPRrays-1 & nplotted = 0L   ;support bin plots bail-out
         WINDOW, xsize=400, ysize=xsize
         loadct,0
      ENDIF

      FOR jpr=0, numPRrays-1 DO BEGIN
         plotting = 0
         pr_index = pr_master_idx[jpr]
       ; only map GV to non-BOGUS PR points having one or more above-threshold
       ;   reflectivity bins in the PR ray
         IF ( pr_index GE 0 AND pr_echoes[jpr] NE 0B ) THEN BEGIN
           ; compute rough distance between PR footprint x,y and GV b-scan x,y;
           ; if either dX or dY is > max sep, then the footprints don't overlap
            max_sep = max_PR_footprint_diag_halfwidth ;+ GV_bin_max_axis_len
            rufdistx = ABS(pr_x_center[jpr,ielev]-xbin)  ; array of (maxGVbin, nrays)
            rufdisty = ABS(pr_y_center[jpr,ielev]-ybin)  ; ditto
            ruff_distance = rufdistx > rufdisty    ; ditto
            closebyidx1 = WHERE( ruff_distance LT max_sep, countclose1 )

            IF ( countclose1 GT 0 ) THEN BEGIN  ; any points pass rough distance check?
              ; check the GV reflectivity values for these bins to see if any
              ;   meet the min dBZ criterion; if none, skip the footprint
               idxcheck = WHERE( bscan[gvidx[closebyidx1]] GE 0.0, countZOK )
;               print, PR_index, pr_x_center[jpr,ielev], pr_y_center[jpr,ielev], countclose, countZOK

               IF ( countZOK GT 0 ) THEN BEGIN  ; any GV points above min dBZ?
                 ; test the actual center-to-center distance between PR and GV
                  truedist = sqrt( (pr_x_center[jpr,ielev]-xbin[closebyidx1])^2  $
                                  +(pr_y_center[jpr,ielev]-ybin[closebyidx1])^2 )
                  closebyidx = WHERE(truedist le max_sep, countclose )

                  IF ( countclose GT 0 ) THEN BEGIN  ; any points pass true dist check?

                    ; optional bin plotting stuff -- PR footprint
                     IF KEYWORD_SET(plot_bins) AND (ielev EQ num_elevations_out/2 - 1) THEN BEGIN
                       ; If plotting the footprint boundaries, extract this PR
                       ;   footprint's x and y corners arrays
                        prcorners[0,*] = pr_x_corners[*, jpr, ielev]
                        prcorners[1,*] = pr_y_corners[*, jpr, ielev]
                       ; set up plotting and bail-out stuff
                        xrange = [MEAN(prcorners[0,*])-5, MEAN(prcorners[0,*])+5]
                        yrange = [MEAN(prcorners[1,*])-5, MEAN(prcorners[1,*])+5]
                        plotting = 1
                        nplotted = nplotted + 1L
                       ; plot the PR footprint - close the polygon using concatenation
                        plot, [REFORM(prcorners[0,*]),REFORM(prcorners[0,0])], $
                              [REFORM(prcorners[1,*]),REFORM(prcorners[1,0])], $
                              xrange = xrange, yrange = yrange, xstyle=1, ystyle=1, $
                              THICK=1.5, /isotropic
                     ENDIF

                     FOR iclose = 0, countclose-1 DO BEGIN
                       ; get the bin,ray coordinates for the given bscan index
                        jbin = gvidx[ closebyidx1[closebyidx[iclose]] ] MOD nbins
                        jray = gvidx[ closebyidx1[closebyidx[iclose]] ] / nbins

                       ; write the lookup table values for this PR-GV overlap pairing
                        pridxlut[lut_count] = pr_index
                        gvidxlut[lut_count] = gvidx[closebyidx1[closebyidx[iclose]]]
                       ; use a Barnes-like gaussian weighting, using 2*max_sep as the
                       ;  effective radius of influence to increase the edge weights
                       ;  beyond pure linear-by-distance weighting
                        weighting = EXP( - (truedist[closebyidx[iclose]]/max_sep)^2 )
                        overlaplut[lut_count] = beam_diam[jbin] * weighting
                        lut_count = lut_count+1

                       ; optional bin plotting stuff -- GV bins
                        IF plotting EQ 1 THEN BEGIN
                          ; compute the bin corner (x,y) coords. (function)
                           gvcorners = bin_corner_x_and_y( sinrayedgeazms, cosrayedgeazms, $
                                         jray, jbin, cos_elev_angle[ielev], ground_range, $
                                         gate_space_gv, DO_PRINT=0 )
                          ; plot the GV polygon
                           oplot, [REFORM(gvcorners[0,*]),REFORM(gvcorners[0,0])], $
                                  [REFORM(gvcorners[1,*]),REFORM(gvcorners[1,*])], $
                                  LINESTYLE = 1, THICK=1.5
                        ENDIF
                     ENDFOR

                    ; optional bin plotting stuff
                     if plotting EQ 1 then begin     ; built-in delay to allow viewing plot
                        endtime = systime(1) + 1.25
                        while ( systime(1) LT endtime ) do begin
                           continue
                        endwhile
                     endif

                  ENDIF  ; countclose GT 0
               ENDIF     ; countZOK GT 0
            ENDIF        ; countclose1 GT 0
         ENDIF           ; pr_index ge 0 AND pr_echoes[jpr] NE 0B

        ; execute bin-plotting bailout option, if plotting is active
         IF KEYWORD_SET(plot_bins) AND (ielev EQ num_elevations_out/2 - 1) THEN BEGIN
         IF (nplotted EQ askagain) THEN BEGIN
            PRINT, ielev, askagain, KEYWORD_SET(plot_bins), ""
            PRINT, "Had enough yet? (Y/N)"
            reply = plot_bins_bailout()
            IF ( reply EQ 'Y' ) THEN plot_bins = 0
         ENDIF
         ENDIF
      ENDFOR    ; pr footprints

     ; =========================================================================
     ; COMPUTE THE PR AND GV REFLECTIVITY AND 3D RAIN RATE AVERAGES

     ; The LUTs are complete for this sweep, now do the resampling/averaging.
     ; Build the PR-GV intersection "data cone" for the sweep, in PR coordinates
     ; (horizontally) and within the vertical layer defined by the GV radar
     ; beam top/bottom:

      FOR jpr=0, numPRrays-1 DO BEGIN
        ; init output variables defined/set in loop/if
         writeMISSING = 1
         countGVpts = 0UL              ; # GV bins mapped to this PR footprint
         n_gv_points_rejected = 0UL    ; # of above that are below GV dBZ cutoff
         n_gv_zdr_points_rejected = 0UL     ; # of above that are MISSING Zdr
         n_gv_kdp_points_rejected = 0UL     ; # of above that are MISSING Kdp
         n_gv_rhohv_points_rejected = 0UL   ; # of above that are MISSING RHOhv
         n_gv_rr_points_rejected = 0UL ; # of above that are below GV RR cutoff
         n_gv_hid_points_rejected = 0UL    ; # of above with undetermined HID
         n_gv_dzero_points_rejected = 0UL  ; # of above that are MISSING D0
         n_gv_nw_points_rejected = 0UL     ; # of above that are MISSING Nw
         pr_gates_expected = 0UL       ; # PR gates within the sweep vert. bounds
         n_1c21_zgates_rejected = 0UL  ; # of above that are below PR dBZ cutoff
         n_2a25_zgates_rejected = 0UL  ; ditto, for corrected PR Z
         n_2a25_rgates_rejected = 0UL  ; # gates below PR rainrate cutoff

         pr_index = pr_master_idx[jpr]

         IF ( pr_index GE 0 AND pr_echoes[jpr] NE 0B ) THEN BEGIN

           ; expand this PR master index into its scan,ray coordinates.  Use
           ;   BB_Bins as the subscripted data array
            rayscan = ARRAY_INDICES( BB_Bins, pr_index )
            raypr = rayscan[1] & scanpr = rayscan[0]

           ; grab indices of all LUT points mapped to this PR sample:
            thisPRsLUTindices = WHERE( pridxlut EQ pr_index, countGVpts)

            IF ( countGVpts GT 0 ) THEN BEGIN    ; this should be a formality
               writeMissing = 0

              ; get indices of all bscan points mapped to this PR sample:
               thisPRsGVindices = gvidxlut[thisPRsLUTindices]
              ; convert the array of gv bscan 1-D indices into array of bin,ray coordinates
               binray = ARRAY_INDICES( bscan, thisPRsGVindices )

              ; compute bin volume of GV bins overlapping this PR footprint
               bindepths = beam_diam[binray[0,*]]  ; depends only on bin # of bscan point
               binhgts = height[binray[0,*]]       ; depends only on bin # of bscan point
               binvols = bindepths * overlaplut[thisPRsLUTindices]

               dbzvals = bscan[thisPRsGVindices]
               zgoodidx = WHERE( dbzvals GE dBZ_min, countGVgood )
               zbadidx = WHERE( dbzvals LT 0.0, countGVbad )
               n_gv_points_rejected = countGVpts - countGVgood

               IF ( countGVgood GT 0 ) THEN BEGIN
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

               IF have_gv_zdr THEN BEGIN
                 ; missing value in Zdr data from RSL is -32767
                 ; - other negative Zdr is OK, within reason
                  gvzdrvals = zdr_bscan[thisPRsGVindices]
                  gvzdrgoodidx = WHERE( gvzdrvals GE -20.0, countGVzdrgood )
                  gvzdrbadidx = WHERE( gvzdrvals LT -32760.0, countGVzdrbad )
                  n_gv_zdr_points_rejected = countGVpts - countGVzdrgood

                  IF ( countGVzdrgood GT 0 ) THEN BEGIN
                    ; compute unweighted GV Zdr average
                     zdr_avg_gv = MEAN( gvzdrvals[gvzdrgoodidx] )
                     zdr_max_gv = MAX( gvzdrvals[gvzdrgoodidx] )
                     IF N_ELEMENTS( gvzdrvals[gvzdrgoodidx] ) LT 2 $
                     THEN zdr_stddev_gv = 0.0 $
                     ELSE zdr_stddev_gv = STDDEV( gvzdrvals[gvzdrgoodidx] )
;                     print, "zdr_avg_gv = ", zdr_avg_gv
;                     print, "GV Zdr values:"
;                     print, gvzdrvals[gvzdrgoodidx]
                  ENDIF ELSE BEGIN
                    ; handle where no GV zdr values meet criteria
                     zdr_avg_gv = SRAIN_BELOW_THRESH
                     zdr_stddev_gv = SRAIN_BELOW_THRESH
                     zdr_max_gv = SRAIN_BELOW_THRESH
                  ENDELSE
               ENDIF

               IF have_gv_kdp THEN BEGIN
                 ; missing value in Kdp data from RSL is -32767
                 ; - other negative Kdp is OK, within reason
                  gvkdpvals = kdp_bscan[thisPRsGVindices]
                  gvkdpgoodidx = WHERE( gvkdpvals GE -20.0, countGVkdpgood )
                  gvkdpbadidx = WHERE( gvkdpvals LT -32760.0, countGVkdpbad )
                  n_gv_kdp_points_rejected = countGVpts - countGVkdpgood

                  IF ( countGVkdpgood GT 0 ) THEN BEGIN
                    ; compute unweighted GV Kdp average
                     kdp_avg_gv = MEAN( gvkdpvals[gvkdpgoodidx] )
                     kdp_max_gv = MAX( gvkdpvals[gvkdpgoodidx] )
                     IF N_ELEMENTS( gvkdpvals[gvkdpgoodidx] ) LT 2 $
                     THEN kdp_stddev_gv = 0.0 $
                     ELSE kdp_stddev_gv = STDDEV( gvkdpvals[gvkdpgoodidx] )
;                     print, "kdp_avg_gv = ", kdp_avg_gv
;                     print, "GV Kdp values:"
;                     print, gvkdpvals[gvkdpgoodidx]
                  ENDIF ELSE BEGIN
                    ; handle where no GV kdp values meet criteria
                     kdp_avg_gv = SRAIN_BELOW_THRESH
                     kdp_stddev_gv = SRAIN_BELOW_THRESH
                     kdp_max_gv = SRAIN_BELOW_THRESH
                  ENDELSE
               ENDIF

               IF have_gv_rhohv THEN BEGIN
                 ; missing value in RHOhv data from RSL is -32767
                 ; - negative/zero RHOhv is also bad/missing
                  gvrhohvvals = rhohv_bscan[thisPRsGVindices]
                  gvrhohvgoodidx = WHERE( gvrhohvvals GT 0.0, countGVrhohvgood )
                  gvrhohvbadidx = WHERE( gvrhohvvals LE 0.0, countGVrhohvbad )
                  n_gv_rhohv_points_rejected = countGVpts - countGVrhohvgood

                  IF ( countGVrhohvgood GT 0 ) THEN BEGIN
                    ; compute unweighted GV RHOhv average
                     rhohv_avg_gv = MEAN( gvrhohvvals[gvrhohvgoodidx] )
                     rhohv_max_gv = MAX( gvrhohvvals[gvrhohvgoodidx] )
                     IF N_ELEMENTS( gvrhohvvals[gvrhohvgoodidx] ) LT 2 $
                     THEN rhohv_stddev_gv = 0.0 $
                     ELSE rhohv_stddev_gv = STDDEV( gvrhohvvals[gvrhohvgoodidx] )
;                     print, "rhohv_avg_gv = ", rhohv_avg_gv
;                     print, "GV RHOhv values:"
;                     print, gvrhohvvals[gvrhohvgoodidx]
                  ENDIF ELSE BEGIN
                    ; handle where no GV rhohv values meet criteria
                     rhohv_avg_gv = SRAIN_BELOW_THRESH
                     rhohv_stddev_gv = SRAIN_BELOW_THRESH
                     rhohv_max_gv = SRAIN_BELOW_THRESH
                  ENDELSE
               ENDIF

               IF have_gv_rr THEN BEGIN
                  gvrrvals = rr_bscan[thisPRsGVindices]
                  gvrrgoodidx = WHERE( gvrrvals GE PR_RAIN_MIN, countGVRRgood )
                  gvrrbadidx = WHERE( gvrrvals LT 0.0, countGVRRbad )
                  n_gv_rr_points_rejected = countGVpts - countGVRRgood

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

               IF have_gv_hid THEN BEGIN
                  gvhidvals = hid_bscan[thisPRsGVindices]
                  gvhidgoodidx = WHERE( gvhidvals GE 0, countGVhidgood )
                  gvhidbadidx = WHERE( gvhidvals LT 0, countGVhidbad )
                  n_gv_hid_points_rejected = countGVpts - countGVhidgood

                  IF ( countGVhidgood GT 0 ) THEN BEGIN
                    ; compute HID histogram
                     hid4hist = gvhidvals[gvhidgoodidx]
                     hid_hist = HISTOGRAM(hid4hist, MIN=0, MAX=n_hid_cats-1)
                     hid_hist[0] = countGVhidbad  ;tally number of MISSING gates
;                     print, "hid_hist = ", hid_hist
;                     print, "HID gate values:"
;                     print, gvhidvals[gvhidgoodidx]
                  ENDIF ELSE BEGIN
                    ; handle where no GV hid values meet criteria
                     hid_hist = INTARR(n_hid_cats)
                     hid_hist[0] = countGVhidbad  ;tally number of MISSING gates
                  ENDELSE
               ENDIF

               IF have_gv_dzero THEN BEGIN
                 ; negative/zero D0 is bad/missing
                  gvdzerovals = dzero_bscan[thisPRsGVindices]
                  gvdzerogoodidx = WHERE( gvdzerovals GT 0.0, countGVD0good )
                  gvdzerobadidx = WHERE( gvdzerovals LE 0.0, countGVD0bad )
                  n_gv_dzero_points_rejected = countGVpts - countGVD0good

                  IF ( countGVD0good GT 0 ) THEN BEGIN
                    ; compute unweighted GV D0 average
                     dzero_avg_gv = MEAN( gvdzerovals[gvdzerogoodidx] )
                     dzero_max_gv = MAX( gvdzerovals[gvdzerogoodidx] )
                    ; compute standard deviation of good GR gates
                     IF N_ELEMENTS( gvdzerovals[gvdzerogoodidx] ) LT 2 $
                     THEN dzero_stddev_gv = 0.0 $
                     ELSE dzero_stddev_gv = STDDEV(gvdzerovals[gvdzerogoodidx])
;                     print, "dzero_avg_gv = ", dzero_avg_gv
;                     print, "GV D0 values:"
;                     print, gvdzerovals[gvdzerogoodidx]
                  ENDIF ELSE BEGIN
                    ; handle where no GV D0 values meet criteria
                     dzero_avg_gv = SRAIN_BELOW_THRESH
                     dzero_stddev_gv = SRAIN_BELOW_THRESH
                     dzero_max_gv = SRAIN_BELOW_THRESH
                  ENDELSE
               ENDIF

               IF have_gv_nw THEN BEGIN
                 ; negative/zero Nw is bad/missing
                  gvnwvals = nw_bscan[thisPRsGVindices]
                  gvnwgoodidx = WHERE( gvnwvals GT 0.0, countGVnwgood )
                  gvnwbadidx = WHERE( gvnwvals LE 0.0, countGVnwbad )
                  n_gv_nw_points_rejected = countGVpts - countGVnwgood

                  IF ( countGVnwgood GT 0 ) THEN BEGIN
                    ; compute unweighted GV Nw average
                     nw_avg_gv = MEAN( gvnwvals[gvnwgoodidx] )
                     nw_max_gv = MAX( gvnwvals[gvnwgoodidx] )
                     IF N_ELEMENTS( gvnwvals[gvnwgoodidx] ) LT 2 $
                     THEN nw_stddev_gv = 0.0 $
                     ELSE nw_stddev_gv = STDDEV( gvnwvals[gvnwgoodidx] )
;                     print, "nw_avg_gv = ", nw_avg_gv
;                     print, "GV NW values:"
;                     print, gvnwvals[gvnwgoodidx]
                  ENDIF ELSE BEGIN
                    ; handle where no GV nw values meet criteria
                     nw_avg_gv = SRAIN_BELOW_THRESH
                     nw_stddev_gv = SRAIN_BELOW_THRESH
                     nw_max_gv = SRAIN_BELOW_THRESH
                  ENDELSE
               ENDIF

              ; compute mean height above surface of GV beam top and beam bottom
              ;   for all GV points geometrically mapped to this PR point
               meantop = MEAN( binhgts + bindepths/2.0 )
               meanbotm = MEAN( binhgts - bindepths/2.0 )
              ; compute height above ellipsoid for computing PR gates that
              ; intersect the GR beam boundaries.  Assume ellipsoid and geoid
              ; (MSL surface) are the same
               meantopMSL = meantop + siteElev
               meanbotmMSL = meanbotm + siteElev

              ; find PR reflectivity gate #s bounding the top/bottom heights
               top1C21gate = 0 & botm1C21gate = 0
               top2A25gate = 0 & botm2A25gate = 0
               gate_num_for_height, meantopMSL, GATE_SPACE, cos_inc_angle,  $
                      raypr, scanpr, binS, rayStart,                     $
                      GATE1C21=top1C21gate, GATE2A25=top2A25gate
               gate_num_for_height, meanbotmMSL, GATE_SPACE, cos_inc_angle, $
                      raypr, scanpr, binS, rayStart,                     $
                      GATE1C21=botm1C21gate, GATE2A25=botm2A25gate

              ; number of PR gates to be averaged in the vertical:
               pr_gates_expected = botm2a25gate - top2a25gate + 1

              ; do layer averaging for 3-D PR fields
               numPRgates = 0
               dbz_1c21_avg = get_pr_layer_average(                  $
                                    top1C21gate, botm1C21gate,       $
                                    scanpr, raypr, dbz_1c21,         $
                                    DBZSCALE1C21, PR_DBZ_MIN,        $
                                    numPRgates, /LOGAVG )
               n_1c21_zgates_rejected = pr_gates_expected - numPRgates

               numPRgates = 0
               dbz_2a25_avg = get_pr_layer_average(                  $
                                    top2A25gate, botm2A25gate,       $
                                    scanpr, raypr, dbz_2a25,         $
                                    DBZSCALE2A25, PR_DBZ_MIN,        $
                                    numPRgates, /LOGAVG )
               n_2a25_zgates_rejected = pr_gates_expected - numPRgates

               numPRgates = 0
               rain_2a25_avg = get_pr_layer_average(                 $
                                    top2A25gate, botm2A25gate,       $
                                    scanpr, raypr, rain_2a25,        $
                                    DBZSCALE2A25, PR_RAIN_MIN,       $
                                    numPRgates )
               n_2a25_rgates_rejected = pr_gates_expected - numPRgates

            ENDIF                  ; countGVpts GT 0
         ENDIF ELSE BEGIN          ; pr_index GE 0 AND pr_echoes[jpr] NE 0B
           ; case where no 2A25 PR gates in the ray are above dBZ threshold,
           ;   set the averages to the BELOW_THRESH special values
	    IF ( pr_index GE 0 AND pr_echoes[jpr] EQ 0B ) THEN BEGIN
               writeMissing = 0
               dbz_avg_gv = Z_BELOW_THRESH
               dbz_stddev_gv = Z_BELOW_THRESH
               dbz_max_gv = Z_BELOW_THRESH
               zdr_avg_gv = DR_KD_MISSING  ; need special value for PPI display
               zdr_stddev_gv = DR_KD_MISSING
               zdr_max_gv = DR_KD_MISSING
               kdp_avg_gv = DR_KD_MISSING
               kdp_stddev_gv = DR_KD_MISSING
               kdp_max_gv = DR_KD_MISSING
               rhohv_avg_gv = SRAIN_BELOW_THRESH
               rhohv_stddev_gv = SRAIN_BELOW_THRESH
               rhohv_max_gv = SRAIN_BELOW_THRESH
               rr_avg_gv = SRAIN_BELOW_THRESH
               rr_stddev_gv = SRAIN_BELOW_THRESH
               rr_max_gv = SRAIN_BELOW_THRESH
               IF ( have_gv_hid ) THEN hid_hist = INTARR(n_hid_cats)
               dzero_avg_gv = SRAIN_BELOW_THRESH
               dzero_stddev_gv = SRAIN_BELOW_THRESH
               dzero_max_gv = SRAIN_BELOW_THRESH
               nw_avg_gv = SRAIN_BELOW_THRESH
               nw_stddev_gv = SRAIN_BELOW_THRESH
               nw_max_gv = SRAIN_BELOW_THRESH
               dbz_1c21_avg = Z_BELOW_THRESH
               dbz_2a25_avg = Z_BELOW_THRESH
               rain_2a25_avg = SRAIN_BELOW_THRESH
	       meantop = 0.0    ; should calculate something for this
	       meanbotm = 0.0   ; ditto
	    ENDIF
	 ENDELSE

     ; =========================================================================
     ; WRITE COMPUTED AVERAGES AND METADATA TO OUTPUT ARRAYS FOR NETCDF

         IF ( writeMissing EQ 0 )  THEN BEGIN
         ; normal rainy footprint, write computed science variables
                  tocdf_gv_dbz[jpr,ielev] = dbz_avg_gv
                  tocdf_gv_stddev[jpr,ielev] = dbz_stddev_gv
                  tocdf_gv_max[jpr,ielev] = dbz_max_gv
                  IF have_gv_zdr THEN BEGIN
                     tocdf_gv_zdr[jpr,ielev] = zdr_avg_gv
                     tocdf_gv_zdr_stddev[jpr,ielev] = zdr_stddev_gv
                     tocdf_gv_zdr_max[jpr,ielev] = zdr_max_gv
                  ENDIF
                  IF have_gv_kdp THEN BEGIN
                     tocdf_gv_kdp[jpr,ielev] = kdp_avg_gv
                     tocdf_gv_kdp_stddev[jpr,ielev] = kdp_stddev_gv
                     tocdf_gv_kdp_max[jpr,ielev] = kdp_max_gv
                  ENDIF
                  IF have_gv_rhohv THEN BEGIN
                     tocdf_gv_rhohv[jpr,ielev] = rhohv_avg_gv
                     tocdf_gv_rhohv_stddev[jpr,ielev] = rhohv_stddev_gv
                     tocdf_gv_rhohv_max[jpr,ielev] = rhohv_max_gv
                  ENDIF
                  IF have_gv_rr THEN BEGIN
                     tocdf_gv_rr[jpr,ielev] = rr_avg_gv
                     tocdf_gv_rr_stddev[jpr,ielev] = rr_stddev_gv
                     tocdf_gv_rr_max[jpr,ielev] = rr_max_gv
                  ENDIF
                  IF have_gv_hid THEN tocdf_gv_HID[*,jpr,ielev] = hid_hist
                  IF have_gv_dzero THEN BEGIN
                     tocdf_gv_dzero[jpr,ielev] = dzero_avg_gv
                     tocdf_gv_dzero_stddev[jpr,ielev] = dzero_stddev_gv
                     tocdf_gv_dzero_max[jpr,ielev] = dzero_max_gv
                  ENDIF
                  IF have_gv_nw THEN BEGIN
                     tocdf_gv_Nw[jpr,ielev] = nw_avg_gv
                     tocdf_gv_Nw_stddev[jpr,ielev] = nw_stddev_gv
                     tocdf_gv_Nw_max[jpr,ielev] = nw_max_gv
                  ENDIF
                  tocdf_1c21_dbz[jpr,ielev] = dbz_1c21_avg
                  tocdf_2a25_dbz[jpr,ielev] = dbz_2a25_avg
                  tocdf_2a25_rain[jpr,ielev] = rain_2a25_avg
                  tocdf_top_hgt[jpr,ielev] = meantop
                  tocdf_botm_hgt[jpr,ielev] = meanbotm
         ENDIF ELSE BEGIN
            CASE pr_index OF
                -1  :  BREAK
                      ; is range-edge point, science values in array were already
                      ;   initialized to special values for this, so do nothing
                -2  :  BEGIN
                      ; off-scan-edge point, set science values to special values
                          tocdf_gv_dbz[jpr,ielev] = FLOAT_OFF_EDGE
                          tocdf_gv_stddev[jpr,ielev] = FLOAT_OFF_EDGE
                          tocdf_gv_max[jpr,ielev] = FLOAT_OFF_EDGE
                          IF have_gv_zdr THEN BEGIN
                             tocdf_gv_zdr[jpr,ielev] = FLOAT_OFF_EDGE
                             tocdf_gv_zdr_stddev[jpr,ielev] = FLOAT_OFF_EDGE
                             tocdf_gv_zdr_max[jpr,ielev] = FLOAT_OFF_EDGE
                          ENDIF
                          IF have_gv_kdp THEN BEGIN
                             tocdf_gv_kdp[jpr,ielev] = FLOAT_OFF_EDGE
                             tocdf_gv_kdp_stddev[jpr,ielev] = FLOAT_OFF_EDGE
                             tocdf_gv_kdp_max[jpr,ielev] = FLOAT_OFF_EDGE
                          ENDIF
                          IF have_gv_rhohv THEN BEGIN
                             tocdf_gv_rhohv[jpr,ielev] = FLOAT_OFF_EDGE
                             tocdf_gv_rhohv_stddev[jpr,ielev] = FLOAT_OFF_EDGE
                             tocdf_gv_rhohv_max[jpr,ielev] = FLOAT_OFF_EDGE
                          ENDIF
                          IF have_gv_rr THEN BEGIN
                             tocdf_gv_rr[jpr,ielev] = FLOAT_OFF_EDGE
                             tocdf_gv_rr_stddev[jpr,ielev] = FLOAT_OFF_EDGE
                             tocdf_gv_rr_max[jpr,ielev] = FLOAT_OFF_EDGE
                          ENDIF
                          IF have_gv_dzero THEN BEGIN
                             tocdf_gv_dzero[jpr,ielev] = FLOAT_OFF_EDGE
                             tocdf_gv_dzero_stddev[jpr,ielev] = FLOAT_OFF_EDGE
                             tocdf_gv_dzero_max[jpr,ielev] = FLOAT_OFF_EDGE
                          ENDIF
                          IF have_gv_nw THEN BEGIN
                             tocdf_gv_Nw[jpr,ielev] = FLOAT_OFF_EDGE
                             tocdf_gv_Nw_stddev[jpr,ielev] = FLOAT_OFF_EDGE
                             tocdf_gv_Nw_max[jpr,ielev] = FLOAT_OFF_EDGE
                          ENDIF
                          tocdf_1c21_dbz[jpr,ielev] = FLOAT_OFF_EDGE
                          tocdf_2a25_dbz[jpr,ielev] = FLOAT_OFF_EDGE
                          tocdf_2a25_rain[jpr,ielev] = FLOAT_OFF_EDGE
                          tocdf_top_hgt[jpr,ielev] = FLOAT_OFF_EDGE
                          tocdf_botm_hgt[jpr,ielev] = FLOAT_OFF_EDGE
                       END
              ELSE  :  BEGIN
                      ; data internal issues, set science values to missing
                          tocdf_gv_dbz[jpr,ielev] = Z_MISSING
                          tocdf_gv_stddev[jpr,ielev] = Z_MISSING
                          tocdf_gv_max[jpr,ielev] = Z_MISSING
                          IF have_gv_zdr THEN BEGIN
                             tocdf_gv_zdr[jpr,ielev] = Z_MISSING
                             tocdf_gv_zdr_stddev[jpr,ielev] = Z_MISSING
                             tocdf_gv_zdr_max[jpr,ielev] = Z_MISSING
                          ENDIF
                          IF have_gv_kdp THEN BEGIN
                             tocdf_gv_kdp[jpr,ielev] = Z_MISSING
                             tocdf_gv_kdp_stddev[jpr,ielev] = Z_MISSING
                             tocdf_gv_kdp_max[jpr,ielev] = Z_MISSING
                          ENDIF
                          IF have_gv_rhohv THEN BEGIN
                             tocdf_gv_rhohv[jpr,ielev] = Z_MISSING
                             tocdf_gv_rhohv_stddev[jpr,ielev] = Z_MISSING
                             tocdf_gv_rhohv_max[jpr,ielev] = Z_MISSING
                          ENDIF
                          IF have_gv_rr THEN BEGIN
                             tocdf_gv_rr[jpr,ielev] = Z_MISSING
                             tocdf_gv_rr_stddev[jpr,ielev] = Z_MISSING
                             tocdf_gv_rr_max[jpr,ielev] = Z_MISSING
                          ENDIF
                          IF have_gv_dzero THEN BEGIN
                             tocdf_gv_dzero[jpr,ielev] = Z_MISSING
                             tocdf_gv_dzero_stddev[jpr,ielev] = Z_MISSING
                             tocdf_gv_dzero_max[jpr,ielev] = Z_MISSING
                          ENDIF
                          IF have_gv_nw THEN BEGIN
                             tocdf_gv_Nw[jpr,ielev] = Z_MISSING
                             tocdf_gv_Nw_stddev[jpr,ielev] = Z_MISSING
                             tocdf_gv_Nw_max[jpr,ielev] = Z_MISSING
                          ENDIF
                          tocdf_1c21_dbz[jpr,ielev] = Z_MISSING
                          tocdf_2a25_dbz[jpr,ielev] = Z_MISSING
                          tocdf_2a25_rain[jpr,ielev] = Z_MISSING
                          tocdf_top_hgt[jpr,ielev] = Z_MISSING
                          tocdf_botm_hgt[jpr,ielev] = Z_MISSING
                       END
            ENDCASE
         ENDELSE

        ; assign the computed meta values to the output array slots
         tocdf_gv_rejected[jpr,ielev] = UINT(n_gv_points_rejected)
         tocdf_gv_zdr_rejected[jpr,ielev] = UINT(n_gv_zdr_points_rejected)
         tocdf_gv_kdp_rejected[jpr,ielev] = UINT(n_gv_kdp_points_rejected)
         tocdf_gv_rhohv_rejected[jpr,ielev] = UINT(n_gv_rhohv_points_rejected)
         tocdf_gv_rr_rejected[jpr,ielev] = UINT(n_gv_rr_points_rejected)
         tocdf_gv_hid_rejected[jpr,ielev] = UINT(n_gv_hid_points_rejected)
         tocdf_gv_dzero_rejected[jpr,ielev] = UINT(n_gv_dzero_points_rejected)
         tocdf_gv_nw_rejected[jpr,ielev] = UINT(n_gv_nw_points_rejected)
         tocdf_gv_expected[jpr,ielev] = UINT(countGVpts)
         tocdf_1c21_z_rejected[jpr,ielev] = UINT(n_1c21_zgates_rejected)
         tocdf_2a25_z_rejected[jpr,ielev] = UINT(n_2a25_zgates_rejected)
         tocdf_2a25_r_rejected[jpr,ielev] = UINT(n_2a25_rgates_rejected)
         tocdf_pr_expected[jpr,ielev] = UINT(pr_gates_expected)

      ENDFOR  ; each PR subarray point: jpr=0, numPRrays-1

     ; END OF PR-TO-GV RESAMPLING, THIS SWEEP

     ; =========================================================================

     ; *********** OPTIONAL SCORE COMPUTATIONS FOR SWEEP ***********

      IF keyword_set(run_scores) THEN BEGIN

        IF ielev EQ 0 THEN BEGIN
          print,""
          idxBBdef = WHERE( tocdf_BB_Hgt GT 0.0 AND tocdf_rainType/100 EQ 1, countBBdef )
          IF countBBdef GT 0 THEN BEGIN
           ; convert bright band heights from m to km, where defined, and get mean BB hgt
           ; first, find the indices of stratiform rays with BB defined
            bb2hist = tocdf_BB_Hgt[idxBBdef]/1000.  ; with conversion to km
        ;    HELP,BB2HIST
            bs=0.2  ; bin width, in km, for HISTOGRAM in get_mean_bb_height()
        ;    hist_window = 9  ; uncomment to plot BB histogram and print diagnostics
           ; do some sorcery to find the best mean BB height estimate, in km
            meanbb = get_mean_bb_height( bb2hist, BS=bs, HIST_WINDOW=hist_window )
            print, "MEAN BB (km): ", meanBB
          ENDIF ELSE print, "No stratiform points with BB defined."
          print, ""
        ENDIF

        IF countBBdef GT 0 THEN BEGIN
          idx2score = WHERE( tocdf_2a25_z_rejected[*,ielev] EQ 0 $
                        AND  tocdf_gv_rejected[*,ielev] EQ 0     $
                        AND  tocdf_pr_expected[*,ielev] GT 0     $
                        AND  tocdf_top_hgt[*,ielev] LT meanBB-0.75, count2score )
          IF count2score gt 0 THEN BEGIN
;            print, "Points below mean BB:"
             print, "BELOW BB Mean PR-GV, Npts: ", MEAN( tocdf_2a25_dbz[idx2score,ielev] $
                                   - tocdf_gv_dbz[idx2score,ielev] ), count2score
          ENDIF
          idx2score = WHERE( tocdf_2a25_z_rejected[*,ielev] EQ 0 $
                        AND  tocdf_gv_rejected[*,ielev] EQ 0     $
                        AND  tocdf_pr_expected[*,ielev] GT 0     $
                        AND  tocdf_botm_hgt[*,ielev] GT meanBB+0.75, count2score )
          IF count2score gt 0 THEN BEGIN
;             print, "Points above mean BB:"
             print, "ABOVE BB Mean PR-GV, Npts: ", MEAN( tocdf_2a25_dbz[idx2score,ielev] $
                                   - tocdf_gv_dbz[idx2score,ielev] ), count2score
          ENDIF
        ENDIF

        idx2score = WHERE( tocdf_2a25_z_rejected[*,ielev] EQ 0 $
                      AND  tocdf_gv_rejected[*,ielev] EQ 0     $
                      AND  tocdf_pr_expected[*,ielev] GT 0, count2score )
        IF count2score gt 0 THEN BEGIN
           print, "Mean PR-GV, Npts with no regard to BB: ", $
              MEAN(tocdf_2a25_dbz[idx2score,ielev]-tocdf_gv_dbz[idx2score,ielev]), count2score
        ENDIF ELSE BEGIN
           print, "Mean PR-GV: no points meet criteria."
        ENDELSE

      ENDIF  ; keyword_set(run_scores)

    ; *********** OPTIONAL PPI PLOTTING FOR SWEEP **********

      IF keyword_set(plot_PPIs) THEN BEGIN
         titlepr = 'PR at ' + pr_dtime + ' UTC'
         titlegv = siteID+', Elevation = ' + STRING(elev_angle[ielev],FORMAT='(f4.1)') $
                +', '+ text_sweep_times[ielev]
         titles = [titlepr, titlegv]
        ; only plots those GV points with average dBZs above PR_DBZ_MIN
         plot_elevation_gv_to_pr_z, tocdf_2a25_dbz, tocdf_gv_dbz*(tocdf_gv_dbz GE PR_DBZ_MIN), $
               sitelat, sitelon, tocdf_x_poly, tocdf_y_poly, numPRrays, ielev, TITLES=titles

       ; if restricting plot to the 'best' PR and GV sample points
         ;plot_elevation_gv_to_pr_z, tocdf_2a25_dbz*(tocdf_2a25_z_rejected EQ 0), $
         ;                           tocdf_gv_dbz*(tocdf_gv_dbz GE PR_DBZ_MIN)*(tocdf_gv_rejected EQ 0), $
         ;                           sitelat, sitelon, $
         ;                           tocdf_x_poly, tocdf_y_poly, numPRrays, ielev, TITLES=titles
       ; to plot a full-res radar PPI for this elevation sweep:
         ;rsl_plotsweep_from_radar, radar, ELEVATION=elev_angle[ielev], $
         ;                          VOLUME_INDEX=z_vol_num, /NEW_WINDOW, MAXRANGE=200
         ;stop
      ENDIF

     ; =========================================================================

   ENDFOR     ; each elevation sweep: ielev = 0, num_elevations_out - 1

;  >>>>>>>>>>>>>>>>> END OF PR-GV VOLUME MATCHING, ALL SWEEPS <<<<<<<<<<<<<<<<<<



;  ********** BEGIN OPTIONAL SCORE COMPUTATIONS, ALL SWEEPS ***************
   IF keyword_set(run_scores) THEN BEGIN

   ; overall scores, all sweeps
   print, ""
   print, "All Sweeps Combined:"
   IF countBBdef GT 0 THEN BEGIN
;      meanBB = MEAN(tocdf_BB_Hgt[idxBBdef])/1000.  ; m to km
      print, ""
      print, "Mean BB: ", meanBB
      idx2score = WHERE( tocdf_2a25_z_rejected EQ 0 $
                    AND  tocdf_gv_rejected EQ 0     $
                    AND  tocdf_pr_expected GT 0     $
                    AND  tocdf_top_hgt LT meanBB-0.75, count2score )
      IF count2score gt 0 THEN BEGIN
         print, "BELOW BB Mean PR-GV, Npts: ", MEAN( tocdf_2a25_dbz[idx2score] $
                                   - tocdf_gv_dbz[idx2score] ), count2score
      ENDIF
      idx2score = WHERE( tocdf_2a25_z_rejected EQ 0 $
                    AND  tocdf_gv_rejected EQ 0     $
                    AND  tocdf_pr_expected GT 0     $
                    AND  tocdf_botm_hgt GT meanBB+0.75, count2score )
      IF count2score gt 0 THEN BEGIN
         print, "ABOVE BB Mean PR-GV, Npts: ", MEAN( tocdf_2a25_dbz[idx2score] $
                                   - tocdf_gv_dbz[idx2score] ), count2score
      ENDIF
   ENDIF ELSE BEGIN
      idx2score = WHERE( tocdf_2a25_z_rejected EQ 0 $
                    AND  tocdf_gv_rejected EQ 0     $
                    AND  tocdf_pr_expected GT 0, count2score )
;      print, "Points with no regard to mean BB:"
      if count2score gt 0 THEN BEGIN
      print, "Mean PR-GV, Npts: ", MEAN(tocdf_2a25_dbz[idx2score] $
                                - tocdf_gv_dbz[idx2score]), count2score
      ENDIF ELSE BEGIN
      print, "Mean PR-GV: no points meet criteria."
      ENDELSE
   ENDELSE


   ; do scores for the traditional 1.5-19.5 km levels, 1.5 km thick:
   ;FOR ihgt = 1.5, 19.5, 1.5 DO BEGIN
   ;   top = ihgt+0.75
   ;   botm = ihgt-0.75
   ;   idx2score = WHERE( tocdf_2a25_z_rejected EQ 0 $
   ;                 AND  tocdf_gv_rejected EQ 0     $
   ;                 AND  tocdf_pr_expected GT 0     $
   ;                 AND  tocdf_top_hgt LE top       $
   ;                 AND  tocdf_botm_hgt GT botm, count2score )
   ;   if count2score gt 0 THEN BEGIN
   ;   print, "Height, Mean PR-GV, Npts: ", ihgt, $
   ;           MEAN(tocdf_2a25_dbz[idx2score]-tocdf_gv_dbz[idx2score]), count2score
   ;   ENDIF ELSE BEGIN
   ;   print, "Mean PR-GV: no points meet criteria."
   ;   ENDELSE
   ;ENDFOR

   PRINT, ""
   PRINT, "End of scores/processing for ", siteID
   PRINT, ""

   ENDIF  ; run_scores

; ************ END OPTIONAL SCORE COMPUTATIONS, ALL SWEEPS *****************
