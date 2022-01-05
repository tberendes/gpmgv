;===============================================================================
;+
; Copyright © 2014, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; polar2gmi_resampling_v7.pro          Morris/SAIC/GPM_GV      January 2014
;
; DESCRIPTION
; -----------
; This file contains the GMI-GV volume matching, data plotting, and score
; computations sections of the code for the procedure polar2gmi.  See file
; polar2gmi.pro for a description of the full procedure.
;
; NOTE: THIS FILE MUST BE "INCLUDED" INSIDE THE PROCEDURE polar2gmi, IT IS *NOT*
;       A COMPLETE IDL PROCEDURE AND CANNOT BE COMPILED OR RUN ON ITS OWN !!
;
; HISTORY
; -------
; 1/13/2014 by Bob Morris, GPM GV (SAIC)
;  - Created from polar2tmi_resampling2.pro.
; 3/21/2014 by Bob Morris, GPM GV (SAIC)
;  - Added processing of GR Zdr, Kdp, RHOhv, HID, D0, and Nw fields from radar
;    data files, when present.
;  - Extracted blocks of code to do mean/stdDev/Max into utility function
;    mean_stddev_max_by_rules() to reduce code duplication.
; 09/24/14 Morris, GPM GV, SAIC
; - Added BAD_TO_ZERO parameter to call to mean_stddev_max_by_rules() to control
;   how below-badthresh values are handled in the averaging for Z.
; 11/06/14 by Bob Morris, GPM GV (SAIC)
;  - Added processing of GR RC and RP rainrate fields for version 1.1 file.
; 03/16/15 by Bob Morris, GPM GV (SAIC)
;  - Add logic to map HID categories from HC field to the FH categories when
;    HC is contained in the radar UF file (DARW radar).
; 10/21/15 by Bob Morris, GPM GV (SAIC)
;  - Added ability to increase current LUT array sizes if they fill up.
; 11/13/15 by Bob Morris, GPM GV (SAIC)
;  - Added processing of GR_blockage for version 1.11 file.
;
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;===============================================================================

  ; set up a multi-level array of 2AGPROF rainrate to match GV reflectivity array
  ; dimensions, if plotting PPIs
   IF keyword_set(plot_PPIs) THEN BEGIN
      toplot_2a12_srain = MAKE_ARRAY( $
         numGMIrays, num_elevations_out, /float, VALUE=FLOAT_RANGE_EDGE )
   ENDIF

  ; Retrieve the desired radar volume(s) from the radar structure
   zvolume = rsl_get_volume( radar, z_vol_num )
   IF have_gv_zdr THEN zdrvolume = rsl_get_volume( radar, zdr_vol_num )
   IF have_gv_kdp THEN kdpvolume = rsl_get_volume( radar, kdp_vol_num )
   IF have_gv_rhohv THEN rhohvvolume = rsl_get_volume( radar, rhohv_vol_num )
   IF have_gv_rc THEN rcvolume = rsl_get_volume( radar, rc_vol_num )
   IF have_gv_rp THEN rpvolume = rsl_get_volume( radar, rp_vol_num )
   IF have_gv_rr THEN rrvolume = rsl_get_volume( radar, rr_vol_num )
   IF have_gv_hid THEN hidvolume = rsl_get_volume( radar, hid_vol_num )
   IF have_gv_dzero THEN dzerovolume = rsl_get_volume( radar, dzero_vol_num )
   IF have_gv_nw THEN nwvolume = rsl_get_volume( radar, nw_vol_num )

  ; Map this GV radar's data to the these GMI footprints, sweep by sweep, at the
  ;   locations where GMI rays intersect the elevation sweeps:

;  >>>>>>>>>>>>>> BEGINNING OF GMI-GV VOLUME MATCHING, ALL SWEEPS <<<<<<<<<<<<<<<

   FOR ielev = 0, num_elevations_out - 1 DO BEGIN
      print, ""
      print, "Elevation: ", tocdf_elev_angle[ielev]

     ; initialize the flags that control blockage calculation/assignment
      do_this_elev_blockage = 0
      ZERO_FILL = 0

     ; restore and preprocess any matching blockage file for this site/sweep
     ; if we have the data to do blockages
      IF do_blockage THEN BEGIN
         blkStruct = prep_blockage_parms( BlockFileBySweep, ielev, VERBOSE=0 )
        ; we expected to find the blockage file for the first sweep, so check
        ; whether that is so by the state of the blkStruct parameter
         IF (ielev EQ 0) AND (blkStruct.do_this_elev_blockage EQ 0) THEN BEGIN
           ; disable blockage calculations, leave output netCDF as initialized
            do_blockage = 0
           ; for now, consider this a fatal error
            message, 'Missing first sweep blockage file for site '+siteID
         ENDIF ELSE BEGIN
           ; reset the flag that says we have blockages available for this site
            IF have_gv_blockage EQ 0 THEN have_gv_blockage = 1
         ENDELSE
        ; grab the flags that tell us what to do, and the actual or bogus data
         do_this_elev_blockage = blkStruct.do_this_elev_blockage
         ZERO_FILL = blkStruct.ZERO_FILL
         blockage4swp = blkStruct.blockage
         blok_x = blkStruct.blok_x
         blok_y = blkStruct.blok_y
         blkStruct = ''
        ; copy the at-surface GMI x and y to this sweep level in the 2-D arrays
        ; for use in computing blockage along VPR path
         sfc_x_center[*,ielev] = x_sfc
         sfc_y_center[*,ielev] = y_sfc
      ENDIF

     ; read in the sweep structure for the elevation
      sweep = rsl_get_sweep( zvolume, SWEEP_INDEX=idx_uniq_elevs[ielev] )
      IF have_gv_zdr THEN $
         zdr_sweep = rsl_get_sweep( zdrvolume, SWEEP_INDEX=idx_uniq_elevs[ielev] )
      IF have_gv_kdp THEN $
         kdp_sweep = rsl_get_sweep( kdpvolume, SWEEP_INDEX=idx_uniq_elevs[ielev] )
      IF have_gv_rhohv THEN $
         rhohv_sweep = rsl_get_sweep( rhohvvolume, SWEEP_INDEX=idx_uniq_elevs[ielev] )
      IF have_gv_rc THEN $
         rc_sweep = rsl_get_sweep( rcvolume, SWEEP_INDEX=idx_uniq_elevs[ielev] )
      IF have_gv_rp THEN $
         rp_sweep = rsl_get_sweep( rpvolume, SWEEP_INDEX=idx_uniq_elevs[ielev] )
      IF have_gv_rr THEN $
         rr_sweep = rsl_get_sweep( rrvolume, SWEEP_INDEX=idx_uniq_elevs[ielev] )
      IF have_gv_hid THEN $
         hid_sweep = rsl_get_sweep( hidvolume, SWEEP_INDEX=idx_uniq_elevs[ielev] )
      IF have_gv_dzero THEN $
         dzero_sweep = rsl_get_sweep( dzerovolume, SWEEP_INDEX=idx_uniq_elevs[ielev] )
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
      IF have_gv_rc THEN rc_bscan = FLTARR(nbins,nrays)
      IF have_gv_rp THEN rp_bscan = FLTARR(nbins,nrays)
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
         IF have_gv_rc THEN BEGIN
            rc_ray = rc_sweep.ray[iray]
            rc_bscan[*,iray] = rc_ray.range[0:nbins-1]
         ENDIF
         IF have_gv_rp THEN BEGIN
            rp_ray = rp_sweep.ray[iray]
            rp_bscan[*,iray] = rp_ray.range[0:nbins-1]
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
          (max_ranges[ielev]+max_GMI_footprint_diag_halfwidth), bins2do2 )
      maxGVbin2 = bins2do2 - 1 > 0
      maxGVbin = maxGVbin < maxGVbin2

     ; =========================================================================
     ; GENERATE THE GV-TO-GMI LUTs FOR THIS SWEEP

     ; create arrays of (nrays*maxGVbin*4) to hold index of overlapping GMI ray,
     ;    index of bscan bin, and bin-footprint overlap area (these comprise the
     ;    GV-to-GMI many:many lookup table)
      lut_size = nrays*maxGVbin*4   ; initial size, might need to extend
      GMI_idxlut = LONARR(lut_size)
      GV_idxlut = ULONARR(lut_size)
      overlaplut = FLTARR(lut_size)
      lut_count = 0UL
      gmi_footprints_in_lut=0
      gmi_footprints_with_gr_echo=0

     ; Do a 'nearest neighbor' analysis of the GMI data to the b-scan coordinates
     ;    First, start populating the three GV-to-GMI lookup table arrays:
     ;    GV_index, GMI_subarr_index, GV_bin_width * distance_weighting

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
         prcorners = FLTARR(2,4)               ;for current GMI footprint's corners
         askagain = 50 < numGMIrays-1 & nplotted = 0L   ;support bin plots bail-out
         WINDOW, 2, xsize=400, ysize=xsize
         loadct,0
      ENDIF

      FOR jpr=0, numGMIrays-1 DO BEGIN
         plotting = 0
         GMI_index = GMI_master_idx[jpr]
       ; only map GV to non-BOGUS GMI points having one or more above-threshold
       ;   reflectivity bins in the GMI ray
         IF ( GMI_index GE 0 AND GMI_echoes[jpr] NE 0B ) THEN BEGIN
           ; Compute rough distance between GMI footprint x,y and GV b-scan x,y --
           ; if either dX or dY is > max sep, then the footprints don't overlap
            max_sep = max_GMI_footprint_diag_halfwidth
            rufdistx = ABS(GMI_x_center[jpr,ielev]-xbin)  ; array of (maxGVbin, nrays)
            rufdisty = ABS(GMI_y_center[jpr,ielev]-ybin)  ; ditto
            ruff_distance = rufdistx > rufdisty    ; ditto
            closebyidx1 = WHERE( ruff_distance LT max_sep, countclose1 )

            IF ( countclose1 GT 0 ) THEN BEGIN  ; any points pass rough distance check?
              ; check the GV reflectivity values for these bins to see if any
              ;   meet the min dBZ criterion; if none, skip the footprint
               idxcheck = WHERE( bscan[gvidx[closebyidx1]] GE 0.0, countZOK )
;               print, GMI_index, GMI_x_center[jpr,ielev], GMI_y_center[jpr,ielev], countclose, countZOK

               IF ( countZOK GT 0 ) THEN BEGIN  ; any GV points above min dBZ?
                 ; test the actual center-to-center distance between GMI and GV
                  truedist = sqrt( (GMI_x_center[jpr,ielev]-xbin[closebyidx1])^2  $
                                  +(GMI_y_center[jpr,ielev]-ybin[closebyidx1])^2 )
                  closebyidx = WHERE(truedist le max_sep, countclose )

                  IF ( countclose GT 0 ) THEN BEGIN  ; any points pass true dist check?
                     gmi_footprints_in_lut = gmi_footprints_in_lut + 1

                    ; optional bin plotting stuff -- GMI footprint
                     IF KEYWORD_SET(plot_bins)  THEN BEGIN
                       ; If plotting the footprint boundaries, extract this GMI
                       ;   footprint's x and y corners arrays
                        prcorners[0,*] = GMI_x_corners[*, jpr, ielev]
                        prcorners[1,*] = GMI_y_corners[*, jpr, ielev]
                       ; set up plotting and bail-out stuff
                        xrange = [MEAN(prcorners[0,*])-15, MEAN(prcorners[0,*])+15]
                        yrange = [MEAN(prcorners[1,*])-15, MEAN(prcorners[1,*])+15]
                        plotting = 1
                        nplotted = nplotted + 1L
                       ; plot the GMI footprint - close the polygon using concatenation
                        plot, [REFORM(prcorners[0,*]),REFORM(prcorners[0,0])], $
                              [REFORM(prcorners[1,*]),REFORM(prcorners[1,0])], $
                              xrange = xrange, yrange = yrange, xstyle=1, ystyle=1, $
                              THICK=1.5, /isotropic
                     ENDIF

                     FOR iclose = 0, countclose-1 DO BEGIN
                       ; get the bin,ray coordinates for the given bscan index
                        jbin = gvidx[ closebyidx1[closebyidx[iclose]] ] MOD nbins
                        jray = gvidx[ closebyidx1[closebyidx[iclose]] ] / nbins

                       ; check lut_count against lut array sizes and extend luts if needed
                        IF lut_count EQ lut_size THEN BEGIN
                           lut_size_ext = lut_size/10
                           lut_size = lut_size+lut_size_ext   ; extended size
                           GMI_idxlut_app = LONARR(lut_size_ext)
                           GV_idxlut_app = ULONARR(lut_size_ext)
                           overlaplut_app = FLTARR(lut_size_ext)
                           GMI_idxlut = [GMI_idxlut,GMI_idxlut_app]
                           GV_idxlut = [GV_idxlut,GV_idxlut_app]
                           overlaplut = [overlaplut,overlaplut_app]
                           print, "Extended SP LUT arrays by 10%"
                        ENDIF

                       ; write the lookup table values for this GMI-GV overlap pairing
                        GMI_idxlut[lut_count] = GMI_index
                        GV_idxlut[lut_count] = gvidx[closebyidx1[closebyidx[iclose]]]
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
         ENDIF           ; GMI_index ge 0 AND GMI_echoes[jpr] NE 0B

        ; execute bin-plotting bailout option, if plotting is active
         IF KEYWORD_SET(plot_bins) THEN BEGIN
         IF ( nplotted EQ askagain ) THEN BEGIN
            PRINT, ielev, askagain, KEYWORD_SET(plot_bins), ""
            PRINT, "Had enough yet? (Y/N)"
            reply = plot_bins_bailout()
            IF ( reply EQ 'Y' ) THEN plot_bins = 0
         ENDIF
         ENDIF
      ENDFOR    ; GMI footprints

      print, "# GMI footprints in LUT: ", gmi_footprints_in_lut

     ; =========================================================================
     ; COMPUTE THE GV REFLECTIVITY AVERAGES

     ; The LUTs are complete for this sweep, now do the resampling/averaging.
     ; Build the GMI-GV intersection "data cone" for the sweep, in GMI coordinates
     ; (horizontally) and within the vertical layer defined by the GV radar
     ; beam top/bottom:

      FOR jpr=0, numGMIrays-1 DO BEGIN
        ; init output variables defined/set in loop/if
         writeMISSING = 1
         countGVpts = 0UL              ; # GV bins mapped to this GMI footprint
         n_gr_points_rejected = 0UL    ; # of above that are below GV dBZ cutoff
         n_gr_zdr_points_rejected = 0UL     ; # of above that are MISSING Zdr
         n_gr_kdp_points_rejected = 0UL     ; # of above that are MISSING Kdp
         n_gr_rhohv_points_rejected = 0UL   ; # of above that are MISSING RHOhv
         n_gr_rc_points_rejected = 0UL ; # of above that are below GV RR cutoff
         n_gr_rp_points_rejected = 0UL ; # of above that are below GV RR cutoff
         n_gr_rr_points_rejected = 0UL ; # of above that are below GV RR cutoff
         n_gr_hid_points_rejected = 0UL    ; # of above with undetermined HID
         n_gr_dzero_points_rejected = 0UL  ; # of above that are MISSING D0
         n_gr_nw_points_rejected = 0UL     ; # of above that are MISSING Nw
         GMI_gates_expected = 0UL       ; # GMI gates within the sweep vert. bounds

         GMI_index = GMI_master_idx[jpr]

         IF ( GMI_index GE 0 AND GMI_echoes[jpr] NE 0B ) THEN BEGIN

           ; expand this GMI master index into its scan,ray coordinates.  Use
           ;   surfaceType as the subscripted data array
            rayscan = ARRAY_INDICES( surfaceType, GMI_index )
            rayGMI = rayscan[1] & scanGMI = rayscan[0]

           ; grab indices of all LUT points mapped to this GMI sample:
            thisGMIsLUTindices = WHERE( GMI_idxlut EQ GMI_index, countGVpts)

            IF ( countGVpts GT 0 ) THEN BEGIN    ; this should be a formality
               writeMissing = 0

              ; get indices of all bscan points mapped to this GMI sample:
               thisGMIsGVindices = GV_idxlut[thisGMIsLUTindices]
              ; convert the array of gv bscan 1-D indices into array of bin,ray coordinates
               binray = ARRAY_INDICES( bscan, thisGMIsGVindices )

              ; compute bin volume of GV bins overlapping this GMI footprint
               bindepths = beam_diam[binray[0,*]]  ; depends only on bin # of bscan point
               binhgts = height[binray[0,*]]       ; depends only on bin # of bscan point
               binvols = bindepths * overlaplut[thisGMIsLUTindices]

               dbzvals = bscan[thisGMIsGVindices]
               zgoodidx = WHERE( dbzvals GE dBZ_min, countGVgood )
               IF ( countGVgood GT 0 ) THEN $
                  gmi_footprints_with_gr_echo = gmi_footprints_with_gr_echo + 1
               altstats=mean_stddev_max_by_rules(dbzvals,'Z', dBZ_min, 0.0, $
                           Z_BELOW_THRESH, WEIGHTS=binvols, /LOG, /BAD_TO_ZERO)
               n_gr_points_rejected = altstats.rejects 
               dbz_avg_gv = altstats.mean
               dbz_stddev_gv = altstats.stddev
               dbz_max_gv = altstats.max

               IF have_gv_zdr THEN BEGIN
                  gvzdrvals = zdr_bscan[thisGMIsGVindices]
                  altstats=mean_stddev_max_by_rules(gvzdrvals,'ZDR', -20.0, $
                              -32760.0, SRAIN_BELOW_THRESH)
                  n_gr_zdr_points_rejected = altstats.rejects
                  zdr_avg_gv = altstats.mean
                  zdr_stddev_gv = altstats.stddev
                  zdr_max_gv = altstats.max
               ENDIF

               IF have_gv_kdp THEN BEGIN
                  gvkdpvals = kdp_bscan[thisGMIsGVindices]
                  altstats=mean_stddev_max_by_rules(gvkdpvals,'KDP', -20.0, $
                              -32760.0, SRAIN_BELOW_THRESH)
                  n_gr_kdp_points_rejected = altstats.rejects
                  kdp_avg_gv = altstats.mean
                  kdp_stddev_gv = altstats.stddev
                  kdp_max_gv = altstats.max
               ENDIF

               IF have_gv_rhohv THEN BEGIN
                  gvrhohvvals = rhohv_bscan[thisGMIsGVindices]
                  altstats=mean_stddev_max_by_rules(gvrhohvvals,'RHOHV', 0.0, $
                              0.0, SRAIN_BELOW_THRESH)
                  n_gr_rhohv_points_rejected = altstats.rejects
                  rhohv_avg_gv = altstats.mean
                  rhohv_stddev_gv = altstats.stddev
                  rhohv_max_gv = altstats.max
               ENDIF

               IF have_gv_rc THEN BEGIN
                  gvrcvals = rc_bscan[thisGMIsGVindices]
                  altstats=mean_stddev_max_by_rules(gvrcvals,'RR', GMI_RAIN_MIN, $
                              0.0, SRAIN_BELOW_THRESH, WEIGHTS=binvols)
                  n_gr_rc_points_rejected = altstats.rejects
                  rc_avg_gv = altstats.mean
                  rc_stddev_gv = altstats.stddev
                  rc_max_gv = altstats.max
               ENDIF

               IF have_gv_rp THEN BEGIN
                  gvrpvals = rp_bscan[thisGMIsGVindices]
                  altstats=mean_stddev_max_by_rules(gvrpvals,'RR', GMI_RAIN_MIN, $
                              0.0, SRAIN_BELOW_THRESH, WEIGHTS=binvols)
                  n_gr_rp_points_rejected = altstats.rejects
                  rp_avg_gv = altstats.mean
                  rp_stddev_gv = altstats.stddev
                  rp_max_gv = altstats.max
               ENDIF

               IF have_gv_rr THEN BEGIN
                  gvrrvals = rr_bscan[thisGMIsGVindices]
                  altstats=mean_stddev_max_by_rules(gvrrvals,'RR', GMI_RAIN_MIN, $
                              0.0, SRAIN_BELOW_THRESH, WEIGHTS=binvols)
                  n_gr_rr_points_rejected = altstats.rejects
                  rr_avg_gv = altstats.mean
                  rr_stddev_gv = altstats.stddev
                  rr_max_gv = altstats.max
               ENDIF

               IF have_gv_hid THEN BEGIN
                  gvhidvals = hid_bscan[thisGMIsGVindices]
                  gvhidgoodidx = WHERE( gvhidvals GE 0, countGVhidgood )
                  gvhidbadidx = WHERE( gvhidvals LT 0, countGVhidbad )
                  n_gv_hid_points_rejected = countGVpts - countGVhidgood

                  IF ( countGVhidgood GT 0 ) THEN BEGIN
                    ; compute HID histogram
                     hid4hist = gvhidvals[gvhidgoodidx]
                     hid_hist = HISTOGRAM(hid4hist, MIN=0, MAX=n_hid_cats-1)
                     hid_hist[0] = countGVhidbad  ;tally number of MISSING gates

                     IF gv_hid_field EQ 'HC' THEN BEGIN
                       ;print, "Regrouping DARW HC categories into the FH categories..."
                       ;
                       ; FH CATEGORY            Value
                       ; ===================    =====
                       ; Drizzle                   1
                       ; Rain                      2
                       ; Ice Crystals              3
                       ; Aggregates                4
                       ; Wet Snow                  5
                       ; Vertical Ice              6
                       ; Low Density Graupel       7
                       ; High Density Graupel      8
                       ; Hail                      9
                       ; Big Drops                10
                       ; missing              -32767.0
                       ;
                       ; HC Category: 0=No Precipitation, 1=Drizzle, 2=Rain, 
                       ;    3=Dry Low Density Snow, 4=Dry High Density Snow,
                       ;    5=Melting Snow, 6=Dry Graupel, 7=Wet Graupel,
                       ;    8=Hail less than 2 cm, 9=Hail greater than 2cm,
                       ;   10=Rain Hail Mix

                        hc_hist = hid_hist   ; make a copy
                        hid_hist[*] = 0      ; clear existing tallies
                        hidarr = [0,1,2,3,4,5,7,8]  ; map below categories to these FH
                        hcarr  = [0,1,2,3,4,5,6,7]  ; map these HC categories to above
                        hid_hist[hidarr] = hc_hist[hcarr]    ; matching defs.
                        hid_hist[9] = hc_hist[8]+hc_hist[9]  ; merge HC hail categories
                        hid_hist[11] = hc_hist[10]           ; Rain/Hail mix to new slot 11
                     ENDIF

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
                  gvdzerovals = dzero_bscan[thisGMIsGVindices]
                  altstats=mean_stddev_max_by_rules(gvdzerovals,'DZERO', 0.0, $
                              0.0, SRAIN_BELOW_THRESH)
                  n_gr_dzero_points_rejected = altstats.rejects
                  dzero_avg_gv = altstats.mean
                  dzero_stddev_gv = altstats.stddev
                  dzero_max_gv = altstats.max
               ENDIF

               IF have_gv_nw THEN BEGIN
                  gvnwvals = nw_bscan[thisGMIsGVindices]
                  altstats=mean_stddev_max_by_rules(gvnwvals,'NW', 0.0, $
                              0.0, SRAIN_BELOW_THRESH)
                  n_gr_nw_points_rejected = altstats.rejects
                  nw_avg_gv = altstats.mean
                  nw_stddev_gv = altstats.stddev
                  nw_max_gv = altstats.max
               ENDIF

               IF do_this_elev_blockage EQ 1 THEN BEGIN
                  compute_mean_blockage, ielev, jpr, tocdf_gr_blockage, $
                     blockage4swp, max_sep, gmi_x_center, gmi_y_center, $
                     blok_x, blok_y, ZERO_FILL=zero_fill
               ENDIF

              ; compute mean height above surface of GV beam top and beam bottom
              ;   for all GV points geometrically mapped to this GMI point
               meantop = MEAN( binhgts + bindepths/2.0 )
               meanbotm = MEAN( binhgts - bindepths/2.0 )
              ; compute height above ellipsoid for computing GMI gates that
              ; intersect the GR beam boundaries.  Assume ellipsoid and geoid
              ; (MSL surface) are the same
               meantopMSL = meantop + siteElev
               meanbotmMSL = meanbotm + siteElev
            ENDIF                  ; countGVpts GT 0

         ENDIF ELSE BEGIN          ; GMI_index GE 0 AND GMI_echoes[jpr] NE 0B

           ; case where no 2AGPROF GMI gates in the ray are above rain threshold,
           ;   set the averages to the BELOW_THRESH special values
	    IF ( GMI_index GE 0 AND GMI_echoes[jpr] EQ 0B ) THEN BEGIN
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
               rc_avg_gv = SRAIN_BELOW_THRESH
               rc_stddev_gv = SRAIN_BELOW_THRESH
               rc_max_gv = SRAIN_BELOW_THRESH
               rp_avg_gv = SRAIN_BELOW_THRESH
               rp_stddev_gv = SRAIN_BELOW_THRESH
               rp_max_gv = SRAIN_BELOW_THRESH
               rr_avg_gv = SRAIN_BELOW_THRESH
               rr_stddev_gv = SRAIN_BELOW_THRESH
               rr_max_gv = SRAIN_BELOW_THRESH
               hid_hist = INTARR(n_hid_cats)
               dzero_avg_gv = SRAIN_BELOW_THRESH
               dzero_stddev_gv = SRAIN_BELOW_THRESH
               dzero_max_gv = SRAIN_BELOW_THRESH
               nw_avg_gv = SRAIN_BELOW_THRESH
               nw_stddev_gv = SRAIN_BELOW_THRESH
               nw_max_gv = SRAIN_BELOW_THRESH
	       meantop = 0.0    ; should calculate something for this
	       meanbotm = 0.0   ; ditto
	    ENDIF
	 ENDELSE

     ; =========================================================================
     ; WRITE COMPUTED AVERAGES AND METADATA TO OUTPUT ARRAYS FOR NETCDF

         IF ( writeMissing EQ 0 )  THEN BEGIN
         ; normal rainy footprint, write computed science variables
                  tocdf_gr_dbz[jpr,ielev] = dbz_avg_gv
                  tocdf_gr_dbz_stddev[jpr,ielev] = dbz_stddev_gv
                  tocdf_gr_dbz_max[jpr,ielev] = dbz_max_gv
                  IF have_gv_zdr THEN BEGIN
                     tocdf_gr_zdr[jpr,ielev] = zdr_avg_gv
                     tocdf_gr_zdr_stddev[jpr,ielev] = zdr_stddev_gv
                     tocdf_gr_zdr_max[jpr,ielev] = zdr_max_gv
                  ENDIF
                  IF have_gv_kdp THEN BEGIN
                     tocdf_gr_kdp[jpr,ielev] = kdp_avg_gv
                     tocdf_gr_kdp_stddev[jpr,ielev] = kdp_stddev_gv
                     tocdf_gr_kdp_max[jpr,ielev] = kdp_max_gv
                  ENDIF
                  IF have_gv_rhohv THEN BEGIN
                     tocdf_gr_rhohv[jpr,ielev] = rhohv_avg_gv
                     tocdf_gr_rhohv_stddev[jpr,ielev] = rhohv_stddev_gv
                     tocdf_gr_rhohv_max[jpr,ielev] = rhohv_max_gv
                  ENDIF
                  IF have_gv_rc THEN BEGIN
                     tocdf_gr_rc[jpr,ielev] = rc_avg_gv
                     tocdf_gr_rc_stddev[jpr,ielev] = rc_stddev_gv
                     tocdf_gr_rc_max[jpr,ielev] = rc_max_gv
                  ENDIF
                  IF have_gv_rp THEN BEGIN
                     tocdf_gr_rp[jpr,ielev] = rp_avg_gv
                     tocdf_gr_rp_stddev[jpr,ielev] = rp_stddev_gv
                     tocdf_gr_rp_max[jpr,ielev] = rp_max_gv
                  ENDIF
                  IF have_gv_rr THEN BEGIN
                     tocdf_gr_rr[jpr,ielev] = rr_avg_gv
                     tocdf_gr_rr_stddev[jpr,ielev] = rr_stddev_gv
                     tocdf_gr_rr_max[jpr,ielev] = rr_max_gv
                  ENDIF
                  IF have_gv_hid THEN BEGIN
                     tocdf_gr_HID[*,jpr,ielev] = hid_hist
                  ENDIF
                  IF have_gv_dzero THEN BEGIN
                     tocdf_gr_dzero[jpr,ielev] = dzero_avg_gv
                     tocdf_gr_dzero_stddev[jpr,ielev] = dzero_stddev_gv
                     tocdf_gr_dzero_max[jpr,ielev] = dzero_max_gv
                  ENDIF
                  IF have_gv_nw THEN BEGIN
                     tocdf_gr_nw[jpr,ielev] = nw_avg_gv
                     tocdf_gr_nw_stddev[jpr,ielev] = nw_stddev_gv
                     tocdf_gr_nw_max[jpr,ielev] = nw_max_gv
                  ENDIF
                 ; NOTE: No need to write tocdf_gr_blockage, its valid values
                 ; get assigned in COMPUTE_MEAN_BLOCKAGE()
                  tocdf_top_hgt[jpr,ielev] = meantop
                  tocdf_botm_hgt[jpr,ielev] = meanbotm
         ENDIF ELSE BEGIN
            CASE GMI_index OF
                -1  :  BREAK
                      ; is range-edge point, science values in array were already
                      ;   initialized to special values for this, so do nothing
                -2  :  BEGIN
                      ; off-scan-edge point, set science values to special values
                          tocdf_gr_dbz[jpr,ielev] = FLOAT_OFF_EDGE
                          tocdf_gr_dbz_stddev[jpr,ielev] = FLOAT_OFF_EDGE
                          tocdf_gr_dbz_max[jpr,ielev] = FLOAT_OFF_EDGE
                          IF have_gv_zdr THEN BEGIN
                             tocdf_gr_zdr[jpr,ielev] = FLOAT_OFF_EDGE
                             tocdf_gr_zdr_stddev[jpr,ielev] = FLOAT_OFF_EDGE
                             tocdf_gr_zdr_max[jpr,ielev] = FLOAT_OFF_EDGE
                          ENDIF
                          IF have_gv_kdp THEN BEGIN
                             tocdf_gr_kdp[jpr,ielev] = FLOAT_OFF_EDGE
                             tocdf_gr_kdp_stddev[jpr,ielev] = FLOAT_OFF_EDGE
                             tocdf_gr_kdp_max[jpr,ielev] = FLOAT_OFF_EDGE
                          ENDIF
                          IF have_gv_rhohv THEN BEGIN
                             tocdf_gr_rhohv[jpr,ielev] = FLOAT_OFF_EDGE
                             tocdf_gr_rhohv_stddev[jpr,ielev] = FLOAT_OFF_EDGE
                             tocdf_gr_rhohv_max[jpr,ielev] = FLOAT_OFF_EDGE
                          ENDIF
                          IF have_gv_rc THEN BEGIN
                             tocdf_gr_rc[jpr,ielev] = FLOAT_OFF_EDGE
                             tocdf_gr_rc_stddev[jpr,ielev] = FLOAT_OFF_EDGE
                             tocdf_gr_rc_max[jpr,ielev] = FLOAT_OFF_EDGE
                          ENDIF
                          IF have_gv_rp THEN BEGIN
                             tocdf_gr_rp[jpr,ielev] = FLOAT_OFF_EDGE
                             tocdf_gr_rp_stddev[jpr,ielev] = FLOAT_OFF_EDGE
                             tocdf_gr_rp_max[jpr,ielev] = FLOAT_OFF_EDGE
                          ENDIF
                          IF have_gv_rr THEN BEGIN
                             tocdf_gr_rr[jpr,ielev] = FLOAT_OFF_EDGE
                             tocdf_gr_rr_stddev[jpr,ielev] = FLOAT_OFF_EDGE
                             tocdf_gr_rr_max[jpr,ielev] = FLOAT_OFF_EDGE
                          ENDIF
                          IF have_gv_dzero THEN BEGIN
                             tocdf_gr_dzero[jpr,ielev] = FLOAT_OFF_EDGE
                             tocdf_gr_dzero_stddev[jpr,ielev] = FLOAT_OFF_EDGE
                             tocdf_gr_dzero_max[jpr,ielev] = FLOAT_OFF_EDGE
                          ENDIF
                          IF have_gv_nw THEN BEGIN
                             tocdf_gr_Nw[jpr,ielev] = FLOAT_OFF_EDGE
                             tocdf_gr_Nw_stddev[jpr,ielev] = FLOAT_OFF_EDGE
                             tocdf_gr_Nw_max[jpr,ielev] = FLOAT_OFF_EDGE
                          ENDIF
                          IF do_this_elev_blockage EQ 1 THEN BEGIN
                             tocdf_gr_blockage[jpr,ielev] = FLOAT_OFF_EDGE
                          ENDIF
                          IF ielev EQ 0 THEN tocdf_2AGPROF_srain[jpr] = FLOAT_OFF_EDGE
                          tocdf_top_hgt[jpr,ielev] = FLOAT_OFF_EDGE
                          tocdf_botm_hgt[jpr,ielev] = FLOAT_OFF_EDGE
                       END
              ELSE  :  BEGIN
                      ; data internal issues, set science values to missing
                          tocdf_gr_dbz[jpr,ielev] = Z_MISSING
                          tocdf_gr_dbz_stddev[jpr,ielev] = Z_MISSING
                          tocdf_gr_dbz_max[jpr,ielev] = Z_MISSING
                          IF have_gv_zdr THEN BEGIN
                             tocdf_gr_zdr[jpr,ielev] = Z_MISSING
                             tocdf_gr_zdr_stddev[jpr,ielev] = Z_MISSING
                             tocdf_gr_zdr_max[jpr,ielev] = Z_MISSING
                          ENDIF
                          IF have_gv_kdp THEN BEGIN
                             tocdf_gr_kdp[jpr,ielev] = Z_MISSING
                             tocdf_gr_kdp_stddev[jpr,ielev] = Z_MISSING
                             tocdf_gr_kdp_max[jpr,ielev] = Z_MISSING
                          ENDIF
                          IF have_gv_rhohv THEN BEGIN
                             tocdf_gr_rhohv[jpr,ielev] = Z_MISSING
                             tocdf_gr_rhohv_stddev[jpr,ielev] = Z_MISSING
                             tocdf_gr_rhohv_max[jpr,ielev] = Z_MISSING
                          ENDIF
                          IF have_gv_rc THEN BEGIN
                             tocdf_gr_rc[jpr,ielev] = Z_MISSING
                             tocdf_gr_rc_stddev[jpr,ielev] = Z_MISSING
                             tocdf_gr_rc_max[jpr,ielev] = Z_MISSING
                          ENDIF
                          IF have_gv_rp THEN BEGIN
                             tocdf_gr_rp[jpr,ielev] = Z_MISSING
                             tocdf_gr_rp_stddev[jpr,ielev] = Z_MISSING
                             tocdf_gr_rp_max[jpr,ielev] = Z_MISSING
                          ENDIF
                          IF have_gv_rr THEN BEGIN
                             tocdf_gr_rr[jpr,ielev] = Z_MISSING
                             tocdf_gr_rr_stddev[jpr,ielev] = Z_MISSING
                             tocdf_gr_rr_max[jpr,ielev] = Z_MISSING
                          ENDIF
                          IF have_gv_dzero THEN BEGIN
                             tocdf_gr_dzero[jpr,ielev] = Z_MISSING
                             tocdf_gr_dzero_stddev[jpr,ielev] = Z_MISSING
                             tocdf_gr_dzero_max[jpr,ielev] = Z_MISSING
                          ENDIF
                          IF have_gv_nw THEN BEGIN
                             tocdf_gr_Nw[jpr,ielev] = Z_MISSING
                             tocdf_gr_Nw_stddev[jpr,ielev] = Z_MISSING
                             tocdf_gr_Nw_max[jpr,ielev] = Z_MISSING
                          ENDIF
                          IF do_this_elev_blockage EQ 1 THEN BEGIN
                             tocdf_gr_blockage[jpr,ielev] = Z_MISSING
                          ENDIF
                          IF ielev EQ 0 THEN tocdf_2AGPROF_srain[jpr] = Z_MISSING
                          tocdf_top_hgt[jpr,ielev] = Z_MISSING
                          tocdf_botm_hgt[jpr,ielev] = Z_MISSING
                       END
            ENDCASE
         ENDELSE

        ; assign the computed meta values to the output array slots
         tocdf_gr_z_rejected[jpr,ielev] = UINT(n_gr_points_rejected)
         IF have_gv_zdr THEN tocdf_gr_zdr_rejected[jpr,ielev] = UINT(n_gr_zdr_points_rejected)
         IF have_gv_kdp THEN tocdf_gr_kdp_rejected[jpr,ielev] = UINT(n_gr_kdp_points_rejected)
         IF have_gv_rhohv THEN tocdf_gr_rhohv_rejected[jpr,ielev] = UINT(n_gr_rhohv_points_rejected)
         IF have_gv_rc THEN tocdf_gr_rc_rejected[jpr,ielev] = UINT(n_gr_rc_points_rejected)
         IF have_gv_rp THEN tocdf_gr_rp_rejected[jpr,ielev] = UINT(n_gr_rp_points_rejected)
         IF have_gv_rr THEN tocdf_gr_rr_rejected[jpr,ielev] = UINT(n_gr_rr_points_rejected)
         IF have_gv_hid THEN tocdf_gr_hid_rejected[jpr,ielev] = UINT(n_gr_hid_points_rejected)
         IF have_gv_dzero THEN tocdf_gr_dzero_rejected[jpr,ielev] = UINT(n_gr_dzero_points_rejected)
         IF have_gv_nw THEN tocdf_gr_nw_rejected[jpr,ielev] = UINT(n_gr_nw_points_rejected)
         tocdf_gr_expected[jpr,ielev] = UINT(countGVpts)

      ENDFOR  ; each GMI subarray point: jpr=0, numGMIrays-1

      print, "# GMI footprints with GR echo: ", gmi_footprints_with_gr_echo

     ; =========================================================================

     ; END OF GMI-TO-GV RESAMPLING, THIS SWEEP

    ; *********** OPTIONAL PPI PLOTTING FOR SWEEP **********

;      IF keyword_set(plot_PPIs) AND ielev LT 1 THEN BEGIN
      IF keyword_set(plot_PPIs) THEN BEGIN
         titleGMI = 'GMI at ' + GMI_dtime + ' UTC'
         titlegv = siteID+', Elevation = ' + STRING(elev_angle[ielev],FORMAT='(f4.1)') $
                +', '+ text_sweep_times[ielev]
         titles = [titleGMI, titlegv]
        ; make an array of same dimensions as GR averages for surface GMI rainrate
         toplot_2a12_srain = MAKE_ARRAY(numGMIrays, num_elevations_out, /float, VALUE=FLOAT_RANGE_EDGE)
        ; for display, scale GMI rainrate to between 15 and 57 (fit dBZ color scale)
         rr_scale = 42.0/MAX(tocdf_2AGPROF_srain)
        ; plots the surface GMI rainrate regardless of GR elevation angle plotted
        ; -- insert GMI data into the current sweep elevation array position
         toplot_2a12_srain[*,ielev] = tocdf_2AGPROF_srain
        ; only plots those GV points with average dBZs above PR_DBZ_MIN
         plot_elevation_gv_to_pr_z, toplot_2a12_srain*(toplot_2a12_srain GT 0.0)*rr_scale+14.99, $
               tocdf_gr_dbz*(tocdf_gr_dbz GE DBZ_MIN), sitelat, sitelon, $
               tocdf_x_poly, tocdf_y_poly, numGMIrays, ielev, TITLES=titles

         something = ""
         print, ''
;         READ, something, PROMPT='Hit Return to proceed to next level: '
      ENDIF

     ; =========================================================================
     ; =========================================================================

     ; GENERATE THE GV-TO-GMI LUTs FOR THIS SWEEP, ALONG LOCAL VERTICAL

     ; create arrays of (nrays*maxGVbin*4) to hold index of overlapping GMI ray,
     ;    index of bscan bin, and bin-footprint overlap area (these comprise the
     ;    GV-to-GMI many:many lookup table)
      lut_size_vpr = nrays*maxGVbin*4   ; initial size, might need to extend
      GMI_idxlut_vpr = LONARR(lut_size_vpr)
      GV_idxlut_vpr = ULONARR(lut_size_vpr)
      overlaplut_vpr = FLTARR(lut_size_vpr)
      lut_count_vpr = 0UL

     ; Do a 'nearest neighbor' analysis of the GMI data to the b-scan coordinates
     ;    First, start populating the three GV-to-GMI lookup table arrays:
     ;    GV_index, GMI_subarr_index, GV_bin_width * distance_weighting

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

      FOR jpr=0, numGMIrays-1 DO BEGIN
         plotting = 0
         GMI_index = GMI_master_idx[jpr]
       ; only map GV to non-BOGUS GMI points having one or more above-threshold
       ;   reflectivity bins in the GMI ray
         IF ( GMI_index GE 0 AND GMI_echoes[jpr] NE 0B ) THEN BEGIN
           ; Compute rough distance between GMI footprint x,y and GV b-scan x,y --
           ; if either dX or dY is > max sep, then the footprints don't overlap
            max_sep = max_GMI_footprint_diag_halfwidth
            rufdistx = ABS(x_sfc[jpr]-xbin)  ; array of (maxGVbin, nrays)
            rufdisty = ABS(y_sfc[jpr]-ybin)  ; ditto
            ruff_distance = rufdistx > rufdisty    ; ditto
            closebyidx1 = WHERE( ruff_distance LT max_sep, countclose1 )

            IF ( countclose1 GT 0 ) THEN BEGIN  ; any points pass rough distance check?
              ; check the GV reflectivity values for these bins to see if any
              ;   meet the min dBZ criterion; if none, skip the footprint
               idxcheck = WHERE( bscan[gvidx_vpr[closebyidx1]] GE 0.0, countZOK )
               IF ( countZOK GT 0 ) THEN BEGIN  ; any GV points above min dBZ?
                 ; test the actual center-to-center distance between GMI and GV
                  truedist = sqrt( (x_sfc[jpr]-xbin[closebyidx1])^2  $
                                  +(y_sfc[jpr]-ybin[closebyidx1])^2 )
                  closebyidx = WHERE(truedist le max_sep, countclose )

                  IF ( countclose GT 0 ) THEN BEGIN  ; any points pass true dist check?

                     FOR iclose = 0, countclose-1 DO BEGIN
                       ; get the bin,ray coordinates for the given bscan index
                        jbin = gvidx_vpr[ closebyidx1[closebyidx[iclose]] ] MOD nbins
                        jray = gvidx_vpr[ closebyidx1[closebyidx[iclose]] ] / nbins

                       ; check lut_count against lut array sizes and extend luts if needed
                        IF lut_count_vpr EQ lut_size_vpr THEN BEGIN
                           lut_size_ext = lut_size_vpr/10
                           lut_size_vpr = lut_size_vpr+lut_size_ext   ; extended size
                           GMI_idxlut_app = LONARR(lut_size_ext)
                           GV_idxlut_app = ULONARR(lut_size_ext)
                           overlaplut_app = FLTARR(lut_size_ext)
                           GMI_idxlut_vpr = [GMI_idxlut_vpr,GMI_idxlut_app]
                           GV_idxlut_vpr = [GV_idxlut_vpr,GV_idxlut_app]
                           overlaplut_vpr = [overlaplut_vpr,overlaplut_app]
                           print, "Extended VPR LUT arrays by 10%"
                        ENDIF

                       ; write the lookup table values for this GMI-GV overlap pairing
                        GMI_idxlut_vpr[lut_count_vpr] = GMI_index
                        GV_idxlut_vpr[lut_count_vpr] = gvidx_vpr[closebyidx1[closebyidx[iclose]]]
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
         ENDIF           ; GMI_index ge 0 AND GMI_echoes[jpr] NE 0B

      ENDFOR    ; GMI footprints

     ; =========================================================================
     ; COMPUTE THE GV REFLECTIVITY AVERAGES, ALONG LOCAL VERTICAL

     ; The LUTs are complete for this sweep, now do the resampling/averaging.
     ; Build the GMI-GV intersection "data cone" for the sweep, in GMI coordinates
     ; (horizontally) and within the vertical layer defined by the GV radar
     ; beam top/bottom:

      FOR jpr=0, numGMIrays-1 DO BEGIN
        ; init output variables defined/set in loop/if
         writeMissing_vpr = 1
         countGVpts_vpr = 0UL              ; # GV bins mapped to this GMI footprint
         n_gr_vpr_points_rejected = 0UL    ; # of above that are below GV dBZ cutoff
         n_gr_zdr_vpr_points_rejected = 0UL     ; # of above that are MISSING Zdr
         n_gr_kdp_vpr_points_rejected = 0UL     ; # of above that are MISSING Kdp
         n_gr_rhohv_vpr_points_rejected = 0UL   ; # of above that are MISSING RHOhv
         n_gr_rc_vpr_points_rejected = 0UL ; # of above that are below GV RR cutoff
         n_gr_rp_vpr_points_rejected = 0UL ; # of above that are below GV RR cutoff
         n_gr_rr_vpr_points_rejected = 0UL ; # of above that are below GV RR cutoff
         n_gr_hid_vpr_points_rejected = 0UL    ; # of above with undetermined HID
         n_gr_dzero_vpr_points_rejected = 0UL  ; # of above that are MISSING D0
         n_gr_nw_vpr_points_rejected = 0UL     ; # of above that are MISSING Nw
         GMI_gates_expected = 0UL       ; # GMI gates within the sweep vert. bounds

         GMI_index = GMI_master_idx[jpr]

         IF ( GMI_index GE 0 AND GMI_echoes[jpr] NE 0B ) THEN BEGIN

           ; expand this GMI master index into its scan,ray coordinates.  Use
           ;   surfaceType as the subscripted data array
            rayscan = ARRAY_INDICES( surfaceType, GMI_index )
            rayGMI = rayscan[1] & scanGMI = rayscan[0]

           ; grab indices of all LUT points mapped to this GMI sample:
            thisGMIsLUTindices = WHERE( GMI_idxlut_vpr EQ GMI_index, countGVpts_vpr)

            IF ( countGVpts_vpr GT 0 ) THEN BEGIN    ; this should be a formality
               writeMissing_vpr = 0

              ; get indices of all bscan points mapped to this GMI sample:
               thisGMIsGVindices = GV_idxlut_vpr[thisGMIsLUTindices]
              ; convert the array of gv bscan 1-D indices into array of bin,ray coordinates
               binray = ARRAY_INDICES( bscan, thisGMIsGVindices )

              ; compute bin volume of GV bins overlapping this GMI footprint
               bindepths = beam_diam[binray[0,*]]  ; depends only on bin # of bscan point
               binhgts = height[binray[0,*]]       ; depends only on bin # of bscan point
               binvols = bindepths * overlaplut_vpr[thisGMIsLUTindices]

               dbzvals = bscan[thisGMIsGVindices]
               zgoodidx = WHERE( dbzvals GE dBZ_min, countGVgood )
               IF ( countGVgood GT 0 ) THEN $
                  gmi_footprints_with_gr_echo = gmi_footprints_with_gr_echo + 1
               altstats=mean_stddev_max_by_rules(dbzvals,'Z',dBZ_min, 0.0, $
                           Z_BELOW_THRESH, WEIGHTS=binvols, /LOG)
               n_gr_vpr_points_rejected = altstats.rejects 
               dbz_avg_gv_vpr = altstats.mean
               dbz_stddev_gv_vpr = altstats.stddev
               dbz_max_gv_vpr = altstats.max

               IF have_gv_zdr THEN BEGIN
                  gvzdrvals = zdr_bscan[thisGMIsGVindices]
                  altstats=mean_stddev_max_by_rules(gvzdrvals,'ZDR', -20.0, $
                              -32760.0, SRAIN_BELOW_THRESH)
                  n_gr_zdr_vpr_points_rejected = altstats.rejects
                  zdr_avg_gv_vpr = altstats.mean
                  zdr_stddev_gv_vpr = altstats.stddev
                  zdr_max_gv_vpr = altstats.max
               ENDIF

               IF have_gv_kdp THEN BEGIN
                  gvkdpvals = kdp_bscan[thisGMIsGVindices]
                  altstats=mean_stddev_max_by_rules(gvkdpvals,'KDP', -20.0, $
                              -32760.0, SRAIN_BELOW_THRESH)
                  n_gr_kdp_vpr_points_rejected = altstats.rejects
                  kdp_avg_gv_vpr = altstats.mean
                  kdp_stddev_gv_vpr = altstats.stddev
                  kdp_max_gv_vpr = altstats.max
               ENDIF

               IF have_gv_rhohv THEN BEGIN
                  gvrhohvvals = rhohv_bscan[thisGMIsGVindices]
                  altstats=mean_stddev_max_by_rules(gvrhohvvals,'RHOHV', 0.0, $
                              0.0, SRAIN_BELOW_THRESH)
                  n_gr_rhohv_vpr_points_rejected = altstats.rejects
                  rhohv_avg_gv_vpr = altstats.mean
                  rhohv_stddev_gv_vpr = altstats.stddev
                  rhohv_max_gv_vpr = altstats.max
               ENDIF

               IF have_gv_rc THEN BEGIN
                  gvrcvals = rc_bscan[thisGMIsGVindices]
                  altstats=mean_stddev_max_by_rules(gvrcvals,'RR', GMI_RAIN_MIN, $
                              0.0, SRAIN_BELOW_THRESH, WEIGHTS=binvols)
                  n_gr_rc_vpr_points_rejected = altstats.rejects
                  rc_avg_gv_vpr = altstats.mean
                  rc_stddev_gv_vpr = altstats.stddev
                  rc_max_gv_vpr = altstats.max
               ENDIF

               IF have_gv_rp THEN BEGIN
                  gvrpvals = rp_bscan[thisGMIsGVindices]
                  altstats=mean_stddev_max_by_rules(gvrpvals,'RR', GMI_RAIN_MIN, $
                              0.0, SRAIN_BELOW_THRESH, WEIGHTS=binvols)
                  n_gr_rp_vpr_points_rejected = altstats.rejects
                  rp_avg_gv_vpr = altstats.mean
                  rp_stddev_gv_vpr = altstats.stddev
                  rp_max_gv_vpr = altstats.max
               ENDIF

               IF have_gv_rr THEN BEGIN
                  gvrrvals = rr_bscan[thisGMIsGVindices]
                  altstats=mean_stddev_max_by_rules(gvrrvals,'RR', GMI_RAIN_MIN, $
                              0.0, SRAIN_BELOW_THRESH, WEIGHTS=binvols)
                  n_gr_rr_vpr_points_rejected = altstats.rejects
                  rr_avg_gv_vpr = altstats.mean
                  rr_stddev_gv_vpr = altstats.stddev
                  rr_max_gv_vpr = altstats.max
               ENDIF

               IF have_gv_hid THEN BEGIN
                  gvhidvals = hid_bscan[thisGMIsGVindices]
                  gvhidgoodidx = WHERE( gvhidvals GE 0, countGVhidgood )
                  gvhidbadidx = WHERE( gvhidvals LT 0, countGVhidbad )
                  n_gv_hid_vpr_points_rejected = countGVpts - countGVhidgood

                  IF ( countGVhidgood GT 0 ) THEN BEGIN
                    ; compute HID histogram
                     hid4hist = gvhidvals[gvhidgoodidx]
                     hid_hist_vpr = HISTOGRAM(hid4hist, MIN=0, MAX=n_hid_cats-1)
                     hid_hist_vpr[0] = countGVhidbad  ;tally number of MISSING gates
;                     print, "hid_hist_vpr = ", hid_hist_vpr
;                     print, "HID gate values:"
;                     print, gvhidvals[gvhidgoodidx]
                  ENDIF ELSE BEGIN
                    ; handle where no GV hid values meet criteria
                     hid_hist_vpr = INTARR(n_hid_cats)
                     hid_hist_vpr[0] = countGVhidbad  ;tally number of MISSING gates
                  ENDELSE
               ENDIF

               IF have_gv_dzero THEN BEGIN
                  gvdzerovals = dzero_bscan[thisGMIsGVindices]
                  altstats=mean_stddev_max_by_rules(gvdzerovals,'DZERO', 0.0, $
                              0.0, SRAIN_BELOW_THRESH)
                  n_gr_dzero_vpr_points_rejected = altstats.rejects
                  dzero_avg_gv_vpr = altstats.mean
                  dzero_stddev_gv_vpr = altstats.stddev
                  dzero_max_gv_vpr = altstats.max
               ENDIF

               IF have_gv_nw THEN BEGIN
                  gvnwvals = nw_bscan[thisGMIsGVindices]
                  altstats=mean_stddev_max_by_rules(gvnwvals,'NW', 0.0, $
                              0.0, SRAIN_BELOW_THRESH)
                  n_gr_nw_vpr_points_rejected = altstats.rejects
                  nw_avg_gv_vpr = altstats.mean
                  nw_stddev_gv_vpr = altstats.stddev
                  nw_max_gv_vpr = altstats.max
               ENDIF

               IF do_this_elev_blockage EQ 1 THEN BEGIN
                  compute_mean_blockage, ielev, jpr, tocdf_gr_blockage_VPR, $
                     blockage4swp, max_sep, sfc_x_center, sfc_y_center, $
                     blok_x, blok_y, ZERO_FILL=zero_fill
               ENDIF

              ; compute mean height above surface of GV beam top and beam bottom
              ;   for all GV points geometrically mapped to this GMI point
               meantop_vpr = MEAN( binhgts + bindepths/2.0 )
               meanbotm_vpr = MEAN( binhgts - bindepths/2.0 )
              ; compute height above ellipsoid for computing GMI gates that
              ; intersect the GR beam boundaries.  Assume ellipsoid and geoid
              ; (MSL surface) are the same
               meantopMSL_vpr = meantop_vpr + siteElev
               meanbotmMSL_vpr = meanbotm_vpr + siteElev
            ENDIF                  ; countGVpts_vpr GT 0

         ENDIF ELSE BEGIN          ; GMI_index GE 0 AND GMI_echoes[jpr] NE 0B

           ; case where no 2AGPROF GMI gates in the ray are above rain threshold,
           ;   set the averages to the BELOW_THRESH special values
	    IF ( GMI_index GE 0 AND GMI_echoes[jpr] EQ 0B ) THEN BEGIN
               writeMissing_vpr = 0
               dbz_avg_gv_vpr = Z_BELOW_THRESH
               dbz_stddev_gv_vpr = Z_BELOW_THRESH
               dbz_max_gv_vpr = Z_BELOW_THRESH
               zdr_avg_gv_vpr = DR_KD_MISSING  ; need special value for PPI display
               zdr_stddev_gv_vpr = DR_KD_MISSING
               zdr_max_gv_vpr = DR_KD_MISSING
               kdp_avg_gv_vpr = DR_KD_MISSING
               kdp_stddev_gv_vpr = DR_KD_MISSING
               kdp_max_gv_vpr = DR_KD_MISSING
               rhohv_avg_gv_vpr = SRAIN_BELOW_THRESH
               rhohv_stddev_gv_vpr = SRAIN_BELOW_THRESH
               rhohv_max_gv_vpr = SRAIN_BELOW_THRESH
               rc_avg_gv_vpr = SRAIN_BELOW_THRESH
               rc_stddev_gv_vpr = SRAIN_BELOW_THRESH
               rc_max_gv_vpr = SRAIN_BELOW_THRESH
               rp_avg_gv_vpr = SRAIN_BELOW_THRESH
               rp_stddev_gv_vpr = SRAIN_BELOW_THRESH
               rp_max_gv_vpr = SRAIN_BELOW_THRESH
               rr_avg_gv_vpr = SRAIN_BELOW_THRESH
               rr_stddev_gv_vpr = SRAIN_BELOW_THRESH
               rr_max_gv_vpr = SRAIN_BELOW_THRESH
               hid_hist_vpr = INTARR(n_hid_cats)
               dzero_avg_gv_vpr = SRAIN_BELOW_THRESH
               dzero_stddev_gv_vpr = SRAIN_BELOW_THRESH
               dzero_max_gv_vpr = SRAIN_BELOW_THRESH
               nw_avg_gv_vpr = SRAIN_BELOW_THRESH
               nw_stddev_gv_vpr = SRAIN_BELOW_THRESH
               nw_max_gv_vpr = SRAIN_BELOW_THRESH
	       meantop_vpr = 0.0    ; should calculate something for this
	       meanbotm_vpr = 0.0   ; ditto
	    ENDIF
	 ENDELSE

     ; =========================================================================
     ; WRITE COMPUTED AVERAGES AND METADATA TO OUTPUT ARRAYS FOR NETCDF

         IF ( writeMissing_vpr EQ 0 )  THEN BEGIN
         ; normal rainy footprint, write computed science variables
                  tocdf_gr_dbz_VPR[jpr,ielev] = dbz_avg_gv_vpr
                  tocdf_gr_dbz_stddev_VPR[jpr,ielev] = dbz_stddev_gv_vpr
                  tocdf_gr_dbz_Max_VPR[jpr,ielev] = dbz_max_gv_vpr
                  IF have_gv_zdr THEN BEGIN
                     tocdf_gr_zdr_VPR[jpr,ielev] = zdr_avg_gv_vpr
                     tocdf_gr_zdr_stddev_VPR[jpr,ielev] = zdr_stddev_gv_vpr
                     tocdf_gr_zdr_max_VPR[jpr,ielev] = zdr_max_gv_vpr
                  ENDIF
                  IF have_gv_kdp THEN BEGIN
                     tocdf_gr_kdp_VPR[jpr,ielev] = kdp_avg_gv_vpr
                     tocdf_gr_kdp_stddev_VPR[jpr,ielev] = kdp_stddev_gv_vpr
                     tocdf_gr_kdp_max_VPR[jpr,ielev] = kdp_max_gv_vpr
                  ENDIF
                  IF have_gv_rhohv THEN BEGIN
                     tocdf_gr_rhohv_VPR[jpr,ielev] = rhohv_avg_gv_vpr
                     tocdf_gr_rhohv_stddev_VPR[jpr,ielev] = rhohv_stddev_gv_vpr
                     tocdf_gr_rhohv_max_VPR[jpr,ielev] = rhohv_max_gv_vpr
                  ENDIF
                  IF have_gv_rc THEN BEGIN
                     tocdf_gr_rc_vpr[jpr,ielev] = rc_avg_gv_vpr
                     tocdf_gr_rc_stddev_vpr[jpr,ielev] = rc_stddev_gv_vpr
                     tocdf_gr_rc_max_vpr[jpr,ielev] = rc_max_gv_vpr
                  ENDIF
                  IF have_gv_rp THEN BEGIN
                     tocdf_gr_rp_vpr[jpr,ielev] = rp_avg_gv_vpr
                     tocdf_gr_rp_stddev_vpr[jpr,ielev] = rp_stddev_gv_vpr
                     tocdf_gr_rp_max_vpr[jpr,ielev] = rp_max_gv_vpr
                  ENDIF
                  IF have_gv_rr THEN BEGIN
                     tocdf_gr_rr_vpr[jpr,ielev] = rr_avg_gv_vpr
                     tocdf_gr_rr_stddev_vpr[jpr,ielev] = rr_stddev_gv_vpr
                     tocdf_gr_rr_max_vpr[jpr,ielev] = rr_max_gv_vpr
                  ENDIF
                  IF have_gv_hid THEN BEGIN
                     tocdf_gr_HID_VPR[*,jpr,ielev] = hid_hist_vpr
                  ENDIF
                  IF have_gv_dzero THEN BEGIN
                     tocdf_gr_dzero_VPR[jpr,ielev] = dzero_avg_gv_vpr
                     tocdf_gr_dzero_stddev_VPR[jpr,ielev] = dzero_stddev_gv_vpr
                     tocdf_gr_dzero_max_VPR[jpr,ielev] = dzero_max_gv_vpr
                  ENDIF
                  IF have_gv_nw THEN BEGIN
                     tocdf_gr_nw_VPR[jpr,ielev] = nw_avg_gv_vpr
                     tocdf_gr_nw_stddev_VPR[jpr,ielev] = nw_stddev_gv_vpr
                     tocdf_gr_nw_max_VPR[jpr,ielev] = nw_max_gv_vpr
                  ENDIF
                 ; NOTE: No need to write tocdf_gr_blockage_vpr, its valid values
                 ; get assigned in COMPUTE_MEAN_BLOCKAGE()
                  tocdf_top_hgt_vpr[jpr,ielev] = meantop_vpr
                  tocdf_botm_hgt_vpr[jpr,ielev] = meanbotm_vpr
         ENDIF ELSE BEGIN
            CASE GMI_index OF
                -1  :  BREAK
                      ; is range-edge point, science values in array were already
                      ;   initialized to special values for this, so do nothing
                -2  :  BEGIN
                      ; off-scan-edge point, set science values to special values
                          tocdf_gr_dbz_VPR[jpr,ielev] = FLOAT_OFF_EDGE
                          tocdf_gr_dbz_stddev_VPR[jpr,ielev] = FLOAT_OFF_EDGE
                          tocdf_gr_dbz_Max_VPR[jpr,ielev] = FLOAT_OFF_EDGE
                          IF have_gv_zdr THEN BEGIN
                             tocdf_gr_zdr_VPR[jpr,ielev] = FLOAT_OFF_EDGE
                             tocdf_gr_zdr_stddev_VPR[jpr,ielev] = FLOAT_OFF_EDGE
                             tocdf_gr_zdr_max_VPR[jpr,ielev] = FLOAT_OFF_EDGE
                          ENDIF
                          IF have_gv_kdp THEN BEGIN
                             tocdf_gr_kdp_VPR[jpr,ielev] = FLOAT_OFF_EDGE
                             tocdf_gr_kdp_stddev_VPR[jpr,ielev] = FLOAT_OFF_EDGE
                             tocdf_gr_kdp_max_VPR[jpr,ielev] = FLOAT_OFF_EDGE
                          ENDIF
                          IF have_gv_rhohv THEN BEGIN
                             tocdf_gr_rhohv_VPR[jpr,ielev] = FLOAT_OFF_EDGE
                             tocdf_gr_rhohv_stddev_VPR[jpr,ielev] = FLOAT_OFF_EDGE
                             tocdf_gr_rhohv_max_VPR[jpr,ielev] = FLOAT_OFF_EDGE
                          ENDIF
                          IF have_gv_rc THEN BEGIN
                             tocdf_gr_rc_VPR[jpr,ielev] = FLOAT_OFF_EDGE
                             tocdf_gr_rc_stddev_VPR[jpr,ielev] = FLOAT_OFF_EDGE
                             tocdf_gr_rc_max_VPR[jpr,ielev] = FLOAT_OFF_EDGE
                          ENDIF
                          IF have_gv_rp THEN BEGIN
                             tocdf_gr_rp_VPR[jpr,ielev] = FLOAT_OFF_EDGE
                             tocdf_gr_rp_stddev_VPR[jpr,ielev] = FLOAT_OFF_EDGE
                             tocdf_gr_rp_max_VPR[jpr,ielev] = FLOAT_OFF_EDGE
                          ENDIF
                          IF have_gv_rr THEN BEGIN
                             tocdf_gr_rr_VPR[jpr,ielev] = FLOAT_OFF_EDGE
                             tocdf_gr_rr_stddev_VPR[jpr,ielev] = FLOAT_OFF_EDGE
                             tocdf_gr_rr_max_VPR[jpr,ielev] = FLOAT_OFF_EDGE
                          ENDIF
                          IF have_gv_dzero THEN BEGIN
                             tocdf_gr_dzero_VPR[jpr,ielev] = FLOAT_OFF_EDGE
                             tocdf_gr_dzero_stddev_VPR[jpr,ielev] = FLOAT_OFF_EDGE
                             tocdf_gr_dzero_max_VPR[jpr,ielev] = FLOAT_OFF_EDGE
                          ENDIF
                          IF have_gv_nw THEN BEGIN
                             tocdf_gr_Nw_VPR[jpr,ielev] = FLOAT_OFF_EDGE
                             tocdf_gr_Nw_stddev_VPR[jpr,ielev] = FLOAT_OFF_EDGE
                             tocdf_gr_Nw_max_VPR[jpr,ielev] = FLOAT_OFF_EDGE
                          ENDIF
                          IF do_this_elev_blockage EQ 1 THEN BEGIN
                             tocdf_gr_blockage_VPR[jpr,ielev] = FLOAT_OFF_EDGE
                          ENDIF
;                          IF ielev EQ 0 THEN tocdf_2AGPROF_srain[jpr] = FLOAT_OFF_EDGE
                          tocdf_top_hgt_vpr[jpr,ielev] = FLOAT_OFF_EDGE
                          tocdf_botm_hgt_vpr[jpr,ielev] = FLOAT_OFF_EDGE
                       END
              ELSE  :  BEGIN
                      ; data internal issues, set science values to missing
                          tocdf_gr_dbz_VPR[jpr,ielev] = Z_MISSING
                          tocdf_gr_dbz_stddev_VPR[jpr,ielev] = Z_MISSING
                          tocdf_gr_dbz_Max_VPR[jpr,ielev] = Z_MISSING
                          IF have_gv_zdr THEN BEGIN
                             tocdf_gr_zdr_VPR[jpr,ielev] = Z_MISSING
                             tocdf_gr_zdr_stddev_VPR[jpr,ielev] = Z_MISSING
                             tocdf_gr_zdr_max_VPR[jpr,ielev] = Z_MISSING
                          ENDIF
                          IF have_gv_kdp THEN BEGIN
                             tocdf_gr_kdp_VPR[jpr,ielev] = Z_MISSING
                             tocdf_gr_kdp_stddev_VPR[jpr,ielev] = Z_MISSING
                             tocdf_gr_kdp_max_VPR[jpr,ielev] = Z_MISSING
                          ENDIF
                          IF have_gv_rhohv THEN BEGIN
                             tocdf_gr_rhohv_VPR[jpr,ielev] = Z_MISSING
                             tocdf_gr_rhohv_stddev_VPR[jpr,ielev] = Z_MISSING
                             tocdf_gr_rhohv_max_VPR[jpr,ielev] = Z_MISSING
                          ENDIF
                          IF have_gv_rc THEN BEGIN
                             tocdf_gr_rc_VPR[jpr,ielev] = Z_MISSING
                             tocdf_gr_rc_stddev_VPR[jpr,ielev] = Z_MISSING
                             tocdf_gr_rc_max_VPR[jpr,ielev] = Z_MISSING
                          ENDIF
                          IF have_gv_rp THEN BEGIN
                             tocdf_gr_rp_VPR[jpr,ielev] = Z_MISSING
                             tocdf_gr_rp_stddev_VPR[jpr,ielev] = Z_MISSING
                             tocdf_gr_rp_max_VPR[jpr,ielev] = Z_MISSING
                          ENDIF
                          IF have_gv_rr THEN BEGIN
                             tocdf_gr_rr_VPR[jpr,ielev] = Z_MISSING
                             tocdf_gr_rr_stddev_VPR[jpr,ielev] = Z_MISSING
                             tocdf_gr_rr_max_VPR[jpr,ielev] = Z_MISSING
                          ENDIF
                          IF have_gv_dzero THEN BEGIN
                             tocdf_gr_dzero_VPR[jpr,ielev] = Z_MISSING
                             tocdf_gr_dzero_stddev_VPR[jpr,ielev] = Z_MISSING
                             tocdf_gr_dzero_max_VPR[jpr,ielev] = Z_MISSING
                          ENDIF
                          IF have_gv_nw THEN BEGIN
                             tocdf_gr_Nw_VPR[jpr,ielev] = Z_MISSING
                             tocdf_gr_Nw_stddev_VPR[jpr,ielev] = Z_MISSING
                             tocdf_gr_Nw_max_VPR[jpr,ielev] = Z_MISSING
                          ENDIF
                          IF do_this_elev_blockage EQ 1 THEN BEGIN
                             tocdf_gr_blockage_VPR[jpr,ielev] = Z_MISSING
                          ENDIF
;                          IF ielev EQ 0 THEN tocdf_2AGPROF_srain[jpr] = Z_MISSING
                          tocdf_top_hgt_vpr[jpr,ielev] = Z_MISSING
                          tocdf_botm_hgt_vpr[jpr,ielev] = Z_MISSING
                       END
            ENDCASE
         ENDELSE

        ; assign the computed meta values to the output array slots
         tocdf_gr_z_VPR_rejected[jpr,ielev] = UINT(n_gr_vpr_points_rejected)
         IF have_gv_zdr THEN tocdf_gr_zdr_VPR_rejected[jpr,ielev] = $
                             UINT(n_gr_zdr_vpr_points_rejected)
         IF have_gv_kdp THEN tocdf_gr_kdp_VPR_rejected[jpr,ielev] = $
                             UINT(n_gr_kdp_vpr_points_rejected)
         IF have_gv_rhohv THEN tocdf_gr_rhohv_VPR_rejected[jpr,ielev] = $
                             UINT(n_gr_rhohv_vpr_points_rejected)
         IF have_gv_rc THEN tocdf_gr_rc_VPR_rejected[jpr,ielev] = $
                             UINT(n_gr_rc_vpr_points_rejected)
         IF have_gv_rp THEN tocdf_gr_rp_VPR_rejected[jpr,ielev] = $
                             UINT(n_gr_rp_vpr_points_rejected)
         IF have_gv_rr THEN tocdf_gr_rr_VPR_rejected[jpr,ielev] = $
                             UINT(n_gr_rr_vpr_points_rejected)
         IF have_gv_hid THEN tocdf_gr_hid_VPR_rejected[jpr,ielev] = $
                             UINT(n_gr_hid_vpr_points_rejected)
         IF have_gv_dzero THEN tocdf_gr_dzero_VPR_rejected[jpr,ielev] = $
                             UINT(n_gr_dzero_vpr_points_rejected)
         IF have_gv_nw THEN tocdf_gr_nw_VPR_rejected[jpr,ielev] = $
                             UINT(n_gr_nw_vpr_points_rejected)
         tocdf_gr_vpr_expected[jpr,ielev] = UINT(countGVpts_vpr)

      ENDFOR    ; GMI footprints

     ; =========================================================================

   ENDFOR     ; each elevation sweep: ielev = 0, num_elevations_out - 1

;  >>>>>>>>>>>>>>>>> END OF GMI-GV VOLUME MATCHING, ALL SWEEPS <<<<<<<<<<<<<<<<<<



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
