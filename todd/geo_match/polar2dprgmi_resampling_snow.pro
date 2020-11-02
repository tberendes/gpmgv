;===============================================================================
;+
; Copyright © 2013, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; polar2dprgmi_resampling_snow.pro          Morris/SAIC/GPM_GV      May 2014
;
; DESCRIPTION
; -----------
; This file contains the DPRGMI-GR volume matching, data plotting, and score
; computations sections of the code for the procedure polar2dprgmi.  See file
; polar2dprgmi.pro for a description of the full procedure.
;
; NOTE: THIS FILE MUST BE "INCLUDED" INSIDE THE PROCEDURE polar2dprgmi, IT IS
;       NOT A COMPLETE IDL PROCEDURE AND CANNOT BE COMPILED OR RUN ON ITS OWN!
;
; HISTORY
; -------
; 5/2014 by Bob Morris, GPM GV (SAIC)
;  - Created from polar2dpr_resampling.pro.
; 10/15/14 Morris, GPM GV, SAIC
; - Added BAD_TO_ZERO parameter to call to mean_stddev_max_by_rules() to control
;   how below-badthresh values are handled in the averaging for Z.
; - Fixed bug where tocdf_n_dpr_expected was not populated for NS swath.
; 11/7/14 Morris, GPM GV, SAIC
; - Fixed situation where all DPR variables used dpr_dbz_min as their thresholds
;   for inclusion in the volume averages.  Does not affect precipTotPSDparamLow,
;   which has its separate hard-coded thresholds in the function in
;   get_precipTotPSDparamLow_avg.pro (need to update these with physical values)
; 11/10/14 by Bob Morris, GPM GV (SAIC)
;  - Added processing of GR RC and RP rainrate fields for version 1.1 file.
; 11/12/14 Morris, GPM GV, SAIC
; - Now computing DPRGMI gate numbers at GR beam height relative to fixed DPRGMI
;   bin number (80) at the ellipsoid.
; 03/16/15 by Bob Morris, GPM GV (SAIC)
;  - Add logic to map HID categories from HC field to the FH categories when
;    HC is contained in the radar UF file (DARW radar).
; 12/23/15 by Bob Morris, GPM GV (SAIC)
;  - Added processing of GR_blockage for version 1.2 file.
; 01/21/16 by Bob Morris, GPM GV (SAIC)
;  - Added ability to increase current LUT array sizes if they fill up, since
;    we now may use a much larger DPR area over which to average the GR bins.
;  - Changed arguments to get_dpr_layer_average() so that clutterStatus is done
;    only when computing Z averages.
; 04/19/16 by Bob Morris, GPM GV (SAIC)
;  - Activated and cleaned up tabulation of clutterStatus values.
;  - Use clutterStatus to set DPRGMI science values to missing where layer is
;    totally below lowest clutter-free bin.
; 07/11/16 by Bob Morris, GPM GV (SAIC)
;  - Added processing of GR Dm and N2 dual-pol fields for version 1.3 file.
;
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;===============================================================================

  ; Map this GV radar's data to the these DPR footprints, sweep by sweep, at the
  ;   locations where DPR rays intersect the elevation sweeps:
   PRINT, "Doing "+siteID+" matchups to ", instrumentID+' '+DPR_scantype+' swath.'


;  >>>>>>>>>>>>>> BEGINNING OF DPR-GR VOLUME MATCHING, ALL SWEEPS <<<<<<<<<<<<<<<

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
      IF have_gv_dm THEN $
         dm_sweep = rsl_get_sweep( dmvolume, SWEEP_INDEX=idx_uniq_elevs[ielev] )
      IF have_gv_n2 THEN $
         n2_sweep = rsl_get_sweep( n2volume, SWEEP_INDEX=idx_uniq_elevs[ielev] )
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

      skip_elev = 0
      IF azsign EQ 0 THEN BEGIN
;         PRINT, "Error computing sweep direction, skipping this event!
;         GOTO, nextGRfile
; TAB 11/27/18 added this logic to skip bad sweeps in DARW data
         PRINT, "Error computing sweep direction, skipping this elevation, writing missing values...
         skip_elev = 1
         goto, skip_sweep
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

     ; create a GR dbz data array of [nbins,nrays] (distance vs angle 'b-scan')
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
      IF have_gv_dm THEN dm_bscan = FLTARR(nbins,nrays)
      IF have_gv_n2 THEN n2_bscan = FLTARR(nbins,nrays)

     ; read each GR ray into the b-scan column
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
         IF have_gv_dm THEN BEGIN
            dm_ray = dm_sweep.ray[iray]
            dm_bscan[*,iray] = dm_ray.range[0:nbins-1]
         ENDIF
         IF have_gv_n2 THEN BEGIN
            n2_ray = n2_sweep.ray[iray]
            n2_bscan[*,iray] = n2_ray.range[0:nbins-1]
         ENDIF
      ENDFOR

     ; build 1-D arrays of GR radial bin ground_range (float km), beam width,
     ;   and beam height from origin bin to max bin, each of size nbins (cut
     ;   this and the b-scan off at some radial distance threshold??) (all GR
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
     ; cut the GR rays off where the beam center height > ~20km -- use a higher
     ; threshold than for the DPR so that we get enough GR bins to cover the DPR
     ; footprint's outer edges.  Could compute this threshold using elev angle,
     ; max_ranges[ielev], and the DPR footprint extent...
      elevs_ok_idx = WHERE( height LE 20.25, bins2do)
      maxGRbin = bins2do - 1 > 0
     ; now cut the GR rays off by range or height, whichever is less
      bins_in_range_idx = WHERE( ground_range LT $
          (max_ranges[ielev]+max_DPR_footprint_diag_halfwidth), bins2do2 )
      maxGRbin2 = bins2do2 - 1 > 0
      maxGRbin = maxGRbin < maxGRbin2

     ; =========================================================================
     ; GENERATE THE GR-TO-DPR LUTs FOR THIS SWEEP

     ; create arrays of (nrays*maxGRbin*4) to hold index of overlapping DPR ray,
     ;    index of bscan bin, and bin-footprint overlap area (these comprise the
     ;    GR-to-DPR many:many lookup table). These are 4 times the size of the
     ;    height/range clipped bscan array, such that a given bin can map to up
     ;    to 4 different DPR footprints
      lut_size = nrays*maxGRbin*4   ; initial size, might need to extend
      pridxlut = LONARR(lut_size)
      gvidxlut = ULONARR(lut_size)
      overlaplut = FLTARR(lut_size)
      lut_count = 0UL

     ; Do a 'nearest neighbor' analysis of the DPR data to the b-scan coordinates
     ;    First, start populating the three GR-to-DPR lookup table arrays:
     ;    GR_index, DPR_subarr_index, GR_bin_width * distance_weighting

      gvidxall = LINDGEN(nbins, nrays)  ; indices into full bscan array

     ; compute GR bin center x,y's and max axis lengths for all bins/rays
     ;   in-range and below 20km:
      xbin = FLTARR(maxGRbin, nrays)
      ybin = FLTARR(maxGRbin, nrays)
;      GR_bin_max_axis_len = FLTARR(maxGRbin, nrays)
      FOR jray=0, nrays-1 DO BEGIN
         xbin[*,jray] = ground_range[0:maxGRbin-1] * sinrayazms[jray]
         ybin[*,jray] = ground_range[0:maxGRbin-1] * cosrayazms[jray]
;         GR_bin_max_axis_len[*,jray] = beam_diam[0:maxGRbin-1] > gate_space_gv
      ENDFOR

     ; trim the gvidxall array down to maxGRbin bins to match xbin, etc.
      gvidx = gvidxall[0:maxGRbin-1,*]


      IF KEYWORD_SET(plot_bins) AND (ielev EQ num_elevations_out/2 - 1) THEN BEGIN
         prcorners = FLTARR(2,4)               ;for current DPR footprint's corners
         askagain = 50 < numDPRrays-1 & nplotted = 0L   ;support bin plots bail-out
         WINDOW, xsize=400, ysize=xsize
         loadct,0
      ENDIF

      FOR jpr=0, numDPRrays-1 DO BEGIN
         plotting = 0
         dpr_index = dpr_master_idx[jpr]
       ; only map GR to non-BOGUS DPR points having one or more above-threshold
       ;   reflectivity bins in the DPR ray
         IF ( dpr_index GE 0 AND dpr_echoes[jpr] NE 0B ) THEN BEGIN
           ; compute rough distance between DPR footprint x,y and GR b-scan x,y;
           ; if either dX or dY is > max sep, then the footprints don't overlap
            max_sep = max_DPR_footprint_diag_halfwidth
            rufdistx = ABS(dpr_x_center[jpr,ielev]-xbin)  ; array of (maxGRbin, nrays)
            rufdisty = ABS(dpr_y_center[jpr,ielev]-ybin)  ; ditto
            ruff_distance = rufdistx > rufdisty    ; ditto
            closebyidx1 = WHERE( ruff_distance LT max_sep, countclose1 )

            IF ( countclose1 GT 0 ) THEN BEGIN  ; any points pass rough distance check?
              ; check the GR reflectivity values for these bins to see if any
              ;   meet the min dBZ criterion; if none, skip the footprint
               idxcheck = WHERE( bscan[gvidx[closebyidx1]] GE 0.0, countZOK )
;               print, DPR_index, dpr_x_center[jpr,ielev], $
;                      dpr_y_center[jpr,ielev], countclose, countZOK

               IF ( countZOK GT 0 ) THEN BEGIN  ; any GR points above min dBZ?
                 ; test the actual center-to-center distance between DPR and GR
                  truedist = sqrt( (dpr_x_center[jpr,ielev]-xbin[closebyidx1])^2  $
                                  +(dpr_y_center[jpr,ielev]-ybin[closebyidx1])^2 )
                  closebyidx = WHERE(truedist le max_sep, countclose )

                  IF ( countclose GT 0 ) THEN BEGIN  ; any points pass true dist check?

                    ; optional bin plotting stuff -- DPR footprint
                     IF KEYWORD_SET(plot_bins) $
                     AND (ielev EQ num_elevations_out/2 - 1) THEN BEGIN
                       ; If plotting the footprint boundaries, extract this DPR
                       ;   footprint's x and y corners arrays
                        prcorners[0,*] = dpr_x_corners[*, jpr, ielev]
                        prcorners[1,*] = dpr_y_corners[*, jpr, ielev]
                       ; set up plotting and bail-out stuff
                        xrange = [MEAN(prcorners[0,*])-5, MEAN(prcorners[0,*])+5]
                        yrange = [MEAN(prcorners[1,*])-5, MEAN(prcorners[1,*])+5]
                        plotting = 1
                        nplotted = nplotted + 1L
                       ; plot the DPR footprint - close the polygon using concatenation
                        plot, [REFORM(prcorners[0,*]),REFORM(prcorners[0,0])], $
                              [REFORM(prcorners[1,*]),REFORM(prcorners[1,0])], $
                              xrange = xrange, yrange = yrange, xstyle=1, ystyle=1, $
                              THICK=1.5, /isotropic
                     ENDIF

                     FOR iclose = 0, countclose-1 DO BEGIN
                       ; get the bin,ray coordinates for the given bscan index
                        jbin = gvidx[ closebyidx1[closebyidx[iclose]] ] MOD nbins
                        jray = gvidx[ closebyidx1[closebyidx[iclose]] ] / nbins

                       ; check lut_count against lut array sizes and extend luts if needed,
                       ; since we now can have a variable radius of influence
                        IF lut_count EQ lut_size THEN BEGIN
                           lut_size_ext = lut_size/5
                           lut_size = lut_size+lut_size_ext   ; extended size
                           pridxlut_app = LONARR(lut_size_ext)
                           gvidxlut_app = ULONARR(lut_size_ext)
                           overlaplut_app = FLTARR(lut_size_ext)
                           pridxlut = [pridxlut,pridxlut_app]
                           gvidxlut = [gvidxlut,gvidxlut_app]
                           overlaplut = [overlaplut,overlaplut_app]
                           print, "Extended LUT arrays by 20%"
                        ENDIF

                       ; write the lookup table values for this DPR-GR overlap pairing
                        pridxlut[lut_count] = dpr_index
                        gvidxlut[lut_count] = gvidx[closebyidx1[closebyidx[iclose]]]
                       ; use a Barnes-like gaussian weighting, using 2*max_sep as the
                       ;  effective radius of influence to increase the edge weights
                       ;  beyond pure linear-by-distance weighting
                        weighting = EXP( - (truedist[closebyidx[iclose]]/max_sep)^2 )
                        overlaplut[lut_count] = beam_diam[jbin] * weighting
                        lut_count = lut_count+1

                       ; optional bin plotting stuff -- GR bins
                        IF plotting EQ 1 THEN BEGIN
                          ; compute the bin corner (x,y) coords. (function)
                           gvcorners = bin_corner_x_and_y( sinrayedgeazms, cosrayedgeazms, $
                                         jray, jbin, cos_elev_angle[ielev], ground_range, $
                                         gate_space_gv, DO_PRINT=0 )
                          ; plot the GR polygon
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
         ENDIF           ; dpr_index ge 0 AND dpr_echoes[jpr] NE 0B

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
     ; COMPUTE THE DPR AND GR REFLECTIVITY AND 3D RAIN RATE AVERAGES

     ; The LUTs are complete for this sweep, now do the resampling/averaging.
     ; Build the DPR-GR intersection "data cone" for the sweep, in DPR coordinates
     ; (horizontally) and within the vertical layer defined by the GV radar
     ; beam top/bottom:

; TAB 11/27/18 added this logic to skip bad sweeps in DARW data
    ; come here if sweep is missing and write out missing values at end of this loop
	skip_sweep:

      FOR jpr=0, numDPRrays-1 DO BEGIN
        ; init output variables defined/set in loop/if
         writeMISSING = 1
         countGRpts = 0UL              ; # GR bins mapped to this DPR footprint
         n_gr_points_rejected = 0UL    ; # of above that are below GR dBZ cutoff
         n_gr_zdr_points_rejected = 0UL     ; # of above that are MISSING Zdr
         n_gr_kdp_points_rejected = 0UL     ; # of above that are MISSING Kdp
         n_gr_rhohv_points_rejected = 0UL   ; # of above that are MISSING RHOhv
         n_gr_rc_points_rejected = 0UL ; # of above that are below GV RR cutoff
         n_gr_rp_points_rejected = 0UL ; # of above that are below GV RR cutoff
         n_gr_rr_points_rejected = 0UL ; # of above that are below GV RR cutoff
         n_gr_hid_points_rejected = 0UL    ; # of above with undetermined HID
         n_gr_dzero_points_rejected = 0UL  ; # of above that are MISSING D0
         n_gr_nw_points_rejected = 0UL     ; # of above that are MISSING Nw
         n_gr_dm_points_rejected = 0UL     ; # of above that are MISSING Dm
         n_gr_n2_points_rejected = 0UL     ; # of above that are MISSING N2
         n_gr_swedp_points_rejected = 0UL     ; # of above that are missing swe
         n_gr_swe25_points_rejected = 0UL     ; # of above that are missing swe
         n_gr_swe50_points_rejected = 0UL     ; # of above that are missing swe
         n_gr_swe75_points_rejected = 0UL     ; # of above that are missing swe
         n_gr_swemqt_points_rejected = 0UL     ; # of above that are missing swe
         n_gr_swemrms_points_rejected = 0UL     ; # of above that are missing swe
         dpr_gates_expected = 0UL      ; # DPR gates within the sweep vert. bounds
         n_correctedReflectFactor_rejected = 0UL  ; # of above that are below DPR dBZ cutoff
         n_precipTotPSDparamHigh_rejected = 0UL  ; ditto, for corrected DPR Z
         n_precipTotPSDparamLow_rejected = 0UL  ; # gates below DPR rainrate cutoff
         n_precipTotRate_rejected = 0UL
         n_precipTotWaterCont_rejected = 0UL
         n_precipTotWaterContSigma_rejected = 0UL
         n_cloudLiqWaterCont_rejected = 0UL
         n_cloudIceWaterCont_rejected = 0UL
         clutterStatus = 0UL           ; result of clutter-free proximity for volume

; TAB 11/27/18 added this logic to skip bad sweeps in DARW data
	     if skip_elev NE 1 then begin
         	dpr_index = dpr_master_idx[jpr]
	     endif else begin
	     	dpr_index = -3 ; cause to fall into missing data block later
	     endelse

         IF ( dpr_index GE 0 AND dpr_echoes[jpr] NE 0B ) THEN BEGIN

           ; expand this DPR master index into its scan coordinates.  Use
           ;   surfaceType as the subscripted data array
            rayscan = ARRAY_INDICES( surfaceType, dpr_index )
            raydpr = rayscan[0] & scandpr = rayscan[1]

           ; grab indices of all LUT points mapped to this DPR sample:
            thisPRsLUTindices = WHERE( pridxlut EQ dpr_index, countGRpts)

            IF ( countGRpts GT 0 ) THEN BEGIN    ; this should be a formality
               writeMissing = 0

              ; get indices of all bscan points mapped to this DPR sample:
               thisPRsGRindices = gvidxlut[thisPRsLUTindices]
              ; convert the array of gv bscan 1-D indices into array of bin,ray coordinates
               binray = ARRAY_INDICES( bscan, thisPRsGRindices )

              ; compute bin volume of GR bins overlapping this DPR footprint
               bindepths = beam_diam[binray[0,*]]  ; depends only on bin # of bscan point
               binhgts = height[binray[0,*]]       ; depends only on bin # of bscan point
               binvols = bindepths * overlaplut[thisPRsLUTindices]

               dbzvals = bscan[thisPRsGRindices]
               zgoodidx = WHERE( dbzvals GE dBZ_min, countGRgood )
               altstats=mean_stddev_max_by_rules(dbzvals,'Z', dBZ_min, 0.0, $
                           Z_BELOW_THRESH, WEIGHTS=binvols, /LOG, BAD_TO_ZERO=1)
               n_gr_points_rejected = altstats.rejects 
               dbz_avg_gv = altstats.mean
               dbz_stddev_gv = altstats.stddev
               dbz_max_gv = altstats.max

               IF have_gv_zdr THEN BEGIN
                  gvzdrvals = zdr_bscan[thisPRsGRindices]
                  altstats=mean_stddev_max_by_rules(gvzdrvals,'ZDR', -20.0, $
                              -32760.0, SRAIN_BELOW_THRESH)
                  n_gr_zdr_points_rejected = altstats.rejects
                  zdr_avg_gv = altstats.mean
                  zdr_stddev_gv = altstats.stddev
                  zdr_max_gv = altstats.max
               ENDIF

               IF have_gv_kdp THEN BEGIN
                  gvkdpvals = kdp_bscan[thisPRsGRindices]
                  altstats=mean_stddev_max_by_rules(gvkdpvals,'KDP', -20.0, $
                              -32760.0, SRAIN_BELOW_THRESH)
                  n_gr_kdp_points_rejected = altstats.rejects
                  kdp_avg_gv = altstats.mean
                  kdp_stddev_gv = altstats.stddev
                  kdp_max_gv = altstats.max
               ENDIF

               IF have_gv_rhohv THEN BEGIN
                  gvrhohvvals = rhohv_bscan[thisPRsGRindices]
                  altstats=mean_stddev_max_by_rules(gvrhohvvals,'RHOHV', 0.0, $
                              0.0, SRAIN_BELOW_THRESH)
                  n_gr_rhohv_points_rejected = altstats.rejects
                  rhohv_avg_gv = altstats.mean
                  rhohv_stddev_gv = altstats.stddev
                  rhohv_max_gv = altstats.max
               ENDIF

               IF have_gv_rc THEN BEGIN
                  gvrcvals = rc_bscan[thisPRsGRindices]
                  altstats=mean_stddev_max_by_rules(gvrcvals,'RR', dpr_rain_min, $
                              0.0, SRAIN_BELOW_THRESH, WEIGHTS=binvols)
                  n_gr_rc_points_rejected = altstats.rejects
                  rc_avg_gv = altstats.mean
                  rc_stddev_gv = altstats.stddev
                  rc_max_gv = altstats.max
               ENDIF

               IF have_gv_rp THEN BEGIN
                  gvrpvals = rp_bscan[thisPRsGRindices]
                  altstats=mean_stddev_max_by_rules(gvrpvals,'RR', dpr_rain_min, $
                              0.0, SRAIN_BELOW_THRESH, WEIGHTS=binvols)
                  n_gr_rp_points_rejected = altstats.rejects
                  rp_avg_gv = altstats.mean
                  rp_stddev_gv = altstats.stddev
                  rp_max_gv = altstats.max
               ENDIF

               IF have_gv_rr THEN BEGIN
                  gvrrvals = rr_bscan[thisPRsGRindices]
                  altstats=mean_stddev_max_by_rules(gvrrvals,'RR', dpr_rain_min, $
                              0.0, SRAIN_BELOW_THRESH, WEIGHTS=binvols)
                  n_gr_rr_points_rejected = altstats.rejects
                  rr_avg_gv = altstats.mean
                  rr_stddev_gv = altstats.stddev
                  rr_max_gv = altstats.max
               ENDIF

               IF have_gv_hid THEN BEGIN
                  gvhidvals = hid_bscan[thisPRsGRindices]
                  gvhidgoodidx = WHERE( gvhidvals GE 0, countGVhidgood )
                  gvhidbadidx = WHERE( gvhidvals LT 0, countGVhidbad )
                  n_gv_hid_points_rejected = N_ELEMENTS(gvhidvals) - countGVhidgood

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
                  gvdzerovals = dzero_bscan[thisPRsGRindices]
                  altstats=mean_stddev_max_by_rules(gvdzerovals,'DZERO', 0.0, $
                              0.0, SRAIN_BELOW_THRESH)
                  n_gr_dzero_points_rejected = altstats.rejects
                  dzero_avg_gv = altstats.mean
                  dzero_stddev_gv = altstats.stddev
                  dzero_max_gv = altstats.max
               ENDIF

               IF have_gv_nw THEN BEGIN
                  gvnwvals = nw_bscan[thisPRsGRindices]
                  altstats=mean_stddev_max_by_rules(gvnwvals,'NW', 0.0, $
                              0.0, SRAIN_BELOW_THRESH)
                  n_gr_nw_points_rejected = altstats.rejects
                  nw_avg_gv = altstats.mean
                  nw_stddev_gv = altstats.stddev
                  nw_max_gv = altstats.max
               ENDIF

               IF have_gv_dm THEN BEGIN
                  gvdmvals = dm_bscan[thisPRsGRindices]
                  altstats=mean_stddev_max_by_rules(gvdmvals,'DZERO', 0.0, $
                              0.0, SRAIN_BELOW_THRESH)
                  n_gr_dm_points_rejected = altstats.rejects
                  dm_avg_gv = altstats.mean
                  dm_stddev_gv = altstats.stddev
                  dm_max_gv = altstats.max
               ENDIF

               IF have_gv_n2 THEN BEGIN
                  gvn2vals = n2_bscan[thisPRsGRindices]
                  altstats=mean_stddev_max_by_rules(gvn2vals,'NW', 0.0, $
                              0.0, SRAIN_BELOW_THRESH)
                  n_gr_n2_points_rejected = altstats.rejects
                  n2_avg_gv = altstats.mean
                  n2_stddev_gv = altstats.stddev
                  n2_max_gv = altstats.max
               ENDIF

               IF do_this_elev_blockage EQ 1 THEN BEGIN
                  compute_mean_blockage, ielev, jpr, tocdf_gr_blockage, $
                     blockage4swp, max_sep, dpr_x_center, dpr_y_center,$
                     blok_x, blok_y, ZERO_FILL=zero_fill
               ENDIF

              ; compute mean height above surface of GR beam top and beam bottom
              ;   for all GR points geometrically mapped to this DPR point
               meantop = MEAN( binhgts + bindepths/2.0 )
               meanbotm = MEAN( binhgts - bindepths/2.0 )
              ; compute height above ellipsoid for computing DPR gates that
              ; intersect the GR beam boundaries.  Assume ellipsoid and geoid
              ; (MSL surface) are the same
               meantopMSL = meantop + siteElev
               meanbotmMSL = meanbotm + siteElev

              ; make a copy of surfaceRangeBin and set all values to the fixed
              ; bin number at the ellipsoid for DPRGMI setup.
               binEllipsoid = surfaceRangeBin
               binEllipsoid[*,*] = ELLIPSOID_BIN_DPRGMI
              ; find DPR reflectivity gate #s bounding the top/bottom heights
               topMeasGate = 0 & botmMeasGate = 0
               topCorrGate = 0 & botmCorrGate = 0
               topCorrGate = dpr_gate_num_for_height(meantopMSL, GATE_SPACE,  $
                             cos_inc_angle, raydpr, scandpr, binEllipsoid)
               topMeasGate=topCorrGate
               botmCorrGate = dpr_gate_num_for_height(meanbotmMSL, GATE_SPACE, $
                              cos_inc_angle, raydpr, scandpr, binEllipsoid)
               botmMeasGate=botmCorrGate

              ; number of DPR gates to be averaged in the vertical:
               dpr_gates_expected = botmCorrGate - topCorrGate + 1

              ; do layer averaging for 3-D DPR fields
               numDPRgates = 0
              ; - clutterStatus already initialized, get once for all 3-D fields
              ;   in this call, same value applies to all
               correctedReflectFactor_avg = get_dpr_layer_average(           $
                                    topMeasGate, botmMeasGate,               $
                                    scandpr, raydpr, correctedReflectFactor, $
                                    DBZSCALEMEAS, dpr_dbz_min, numDPRgates,  $
                                    lowestClutterFreeBin, clutterStatus,     $
                                    /LOGAVG )

              ; If the averaging layer bins are not totally below the
              ; lowestClutterFreeBin (clutterStatus of 0 or 1), then proceed
              ; with layer averages. Otherwise set layer average values to
              ; missing and set n_rejected to n_expected.

               IF clutterStatus NE 2 THEN BEGIN
                 ; OK to proceed with averages, etc.
                  n_correctedReflectFactor_rejected = dpr_gates_expected - numDPRgates

                  numDPRgates = 0
                  precipTotPSDparamHigh_avg = get_dpr_layer_average(           $
                                       topCorrGate, botmCorrGate,              $
                                       scandpr, raydpr, precipTotPSDparamHigh, $
                                       1.0, 0.0,                               $
                                       numDPRgates, lowestClutterFreeBin )
                  n_precipTotPSDparamHigh_rejected = dpr_gates_expected - numDPRgates

                  precipTotPSDparamLow_avg = FLTARR(nPSDlo)
                  n_precipTotPSDparamLow_rejected = INTARR(nPSDlo)
                  psdlo_results = get_precipTotPSDparamLow_avg(            $
                                    topCorrGate, botmCorrGate,             $
                                    scandpr, raydpr, precipTotPSDparamLow, $
                                    PSDparamLowNode, [1.0,1.0], [-9999.0,-3.0] )
                  FOR psdidx=0,nPSDlo-1 DO BEGIN
                     precipTotPSDparamLow_avg[psdidx] = psdlo_results.params_avg[psdidx]
                     n_precipTotPSDparamLow_rejected[psdidx] = dpr_gates_expected - $
                        psdlo_results.num_in_avg[psdidx]
                  ENDFOR

                  numDPRgates = 0
                  precipTotRate_avg = get_dpr_layer_average(           $
                                       topCorrGate, botmCorrGate,      $
                                       scandpr, raydpr, precipTotRate, $
                                       1.0, dpr_rain_min,              $
                                       numDPRgates, lowestClutterFreeBin )
                  n_precipTotRate_rejected = dpr_gates_expected - numDPRgates

                  numDPRgates = 0
                  precipTotWaterCont_avg = get_dpr_layer_average(           $
                                       topCorrGate, botmCorrGate,           $
                                       scandpr, raydpr, precipTotWaterCont, $
                                       1.0, 0.0,                            $
                                       numDPRgates, lowestClutterFreeBin )
                  n_precipTotWaterCont_rejected = dpr_gates_expected - numDPRgates
                  
                  numDPRgates = 0
                  precipTotWaterContSigma_avg = get_dpr_layer_average(           $
                                       topCorrGate, botmCorrGate,           $
                                       scandpr, raydpr, precipTotWaterContSigma, $
                                       1.0, 0.0,                            $
                                       numDPRgates, lowestClutterFreeBin )
                  n_precipTotWaterContSigma_rejected = dpr_gates_expected - numDPRgates
                  
                  numDPRgates = 0
                  cloudLiqWaterCont_avg = get_dpr_layer_average(           $
                                       topCorrGate, botmCorrGate,           $
                                       scandpr, raydpr, cloudLiqWaterCont, $
                                       1.0, 0.0,                            $
                                       numDPRgates, lowestClutterFreeBin )
                  n_cloudLiqWaterCont_rejected = dpr_gates_expected - numDPRgates
                  
                  numDPRgates = 0
                  cloudIceWaterCont_avg = get_dpr_layer_average(           $
                                       topCorrGate, botmCorrGate,           $
                                       scandpr, raydpr, cloudIceWaterCont, $
                                       1.0, 0.0,                            $
                                       numDPRgates, lowestClutterFreeBin )
                  n_cloudIceWaterCont_rejected = dpr_gates_expected - numDPRgates
                  

               ENDIF ELSE BEGIN
                 ; all bins to average are below lowestClutterFreeBin
                  correctedReflectFactor_avg = Z_BELOW_THRESH
                  n_correctedReflectFactor_rejected = dpr_gates_expected
                  precipTotPSDparamHigh_avg = SRAIN_BELOW_THRESH
                  n_precipTotPSDparamHigh_rejected = dpr_gates_expected
                  precipTotPSDparamLow_avg = FLTARR(nPSDlo)
                  precipTotPSDparamLow_avg[*] = SRAIN_BELOW_THRESH
                  n_precipTotPSDparamLow_rejected = INTARR(nPSDlo)
                  n_precipTotPSDparamLow_rejected[*] = dpr_gates_expected
                  precipTotRate_avg = SRAIN_BELOW_THRESH
                  n_precipTotRate_rejected = dpr_gates_expected
                  precipTotWaterCont_avg = SRAIN_BELOW_THRESH
                  precipTotWaterContSigma_avg = SRAIN_BELOW_THRESH
                  cloudLiqWaterCont_avg = SRAIN_BELOW_THRESH
                  cloudIceWaterCont_avg = SRAIN_BELOW_THRESH
                  n_precipTotWaterCont_rejected = dpr_gates_expected
                  n_precipTotWaterContSigma_rejected = dpr_gates_expected
                  n_cloudLiqWaterCont_rejected = dpr_gates_expected
                  n_cloudIceWaterCont_rejected = dpr_gates_expected
               ENDELSE             ; clutterStatus NE 2


               
;***********
;	 
;	  TAB 8/15/18 
;	  this is the new stuff for snow rate, Walt's original request:
;	 
;	 	Todd, I would like to compute the snowfall water equivalent rate in the VN data using one of the new polarimetric relationships 
;	 	suggested by Bukocvic et al (2017).  To do this, we will need to use the matched ground-radar volumes themselves, compute the 
;	 	snowfall rate in the gates, then rematch those to get the averages at the DPR pixel scale.  So, the logic would look like this
; 
;			1.      If the altitude of the comparison (radar and DPR) is below 1.5 km and;
;
;			2.      If the given radar gate is associated with snow (we can use MRMS identification of snow at 
;					the surface as a guide and we could use the HID variable from the radar)-  
;
;				a.      Compute a snowfall rate.
;
;    variables required for algorithm:
;    ZC = dbzvals
;    KD = gvkdpvals 
;    HID = hid_bscan (gvhidvals)
;    height = meantop (AGL)
;    modify a version of mean_stddev_max_by_rules to compute snowfall rate
;
;                	i.  Use KDP and Z from the ground radar (KD and ZC):  S = 1.53 * KDP^0.68 * Z^0.29   (here Z is in linear 
;                		units, so need to convert to linear units by taking Z = 10^(Zdbz/10)   where Zdbz is the radar reflectivity 
;                		that is in the ground radar file (because it is in units of dBZ).
;                   ii.  Having computed the snowfall rate- go back and do the footprint matching to the DPR for the given pixel.
;
;			3.      Make the same plots we make for rainfall rate comparisons with the DPR and Ground Radars- but for snow. 
;
; 		Collectively, this will allow us to create a new snowfall dataset for use by algorithm folks as well.  The key (and sometimes 
; 		tricky part) will be the conservative approach we take to ensuring that we are actually computing the Z-S relationship for a 
; 		pixel/radar gate producing snow, and snow that is at or at least very close to, the surface.    I think we could fold in some 
; 		surface model analysis data from the RUC or HRRR as well- but that would be a bit more work.  Since the MRMS already does this 
; 		by default, and since you have that matched to pixels � we could just use its hydrometeor type as our guide (then we are implicitly 
; 		identifying radar pixels in snow).
;
;		Do you see what I�m talking about here?  It will be very cool and useful.  Might take us an iteration or two- but I think we can 
;		and should do this.  I would like to take a crack at it very soon (not while you are on vacation, obviously)- before the PMM 
;		Science Team meeting week of October 7.  I would like to see if we can�t get something of a preliminary GR-DPR comparison done 
;		with snow in the VN before that (it should not be that complicated- just lots of crunching).
;
;		One iteration might be playing with the Z-S a little bit (KDP,Z) � but I need to verify something in this paper first.  For now, 
;		I think we could use this relationship I show above (works for Colorado and Oklahoma).
;
;		Cheers,
;		Walt
;
;  Response:
;
;		Walt,
;
;		Ok, I think I see what you are after for computing GR snowfall rate, but how do we get the snowfall rate for DPR?
;
;		This code will require modification of Bob's IDL GR-DPR volume matching program, which I have just started to look 
;		at for the beam filling stuff (printing out gate values).  I think I'm starting to figure out that code, so I have 
;		a fairly good idea how to do this.
;
;		Unfortunately, the Java MRMS matching code that I have already written is a post-processing step and operates on 
;		the VN volume matches after the volume averaging of GR and DPR has already been performed by Bob's IDL programs.  
;		If we want to use MRMS during the IDL matchup of the GR gates with DPR, I will probably have to develop an IDL version 
;		of the MRMS matchup code to integrate into Bob's code.  I think Stephanie has written some IDL code to read and retrieve 
;		values from the MRMS files, so maybe she could share that with me? 
;
;		I think this should be doable for your Oct. meeting if I can get some focused time to work on it.
;
;		Todd
;
;  Response:
;
;		Ok- thanks.  With DPR � just assume that if the GR says it is snowing, so should the DPR for now- and then you just 
;		use the same precip rate variable you would anyway (Same for 2BCMB).   There is a precip type/snow flag in the DPR 
;		data file as well��but again, if we go conservative, and rely on MRMS, then the DPR precip rate will almost always be snow.  
;		We could also filter on the zerodegreebin in the DPR data files, or surfaceairTemp in the 2BCMB ietc....- but, I think I�d 
;		like to be consistent with MRMS.
;
;		Now there is also the GPROF (GMI) and combined algorithms as well.  GPROF has a �temp2mindex� that is the temperature 
;		at 2 m (in K) used for selecting profiles- so that would also be another potential way of discriminating on our own- but 
;		not sure that is read into the matching routine.   For GMI- the variable will be �frozenPrecipitation� this is the snowfall 
;		rate we want to use there.
;
;		I wonder if you could run the MRMS in post-processing now, then when you do that, create a database file you can read in 
;		that has the precip phase information in it that the DPR-GR matching software would use? (kind of a �reference�).  The other 
;		option is to go with the GR HID variable- if classified as frozen (wet snow/dry snow/low-density graupel)- then it is called 
;		�snow� and the Z-S is applied.  We *could* try that first if the MRMS route looks a little to daunting to play with (but, I 
;		think using the MRMS would be better).
;
;		Walt

;  second method from Pierre:
;		Todd- here are the equations from Pierre for the relationships to use in VN for his PQPE approach (this is different from 
;       the polarimetric estimator you are coding up now- but, maybe easier as it is straight up reflectivity as opposed to using 
;       the other pol variables). Remember that you have to use the linear Z (not log units (dBZ)) for this; i.e., Z = 10^(dbz/10)  
;       to get the snowfall rates-��actually, that�s true for the polarimetric estimation as well (but I think I already mentioned that).			 
;		
;		The quantiles are good to compute as well as one could make the lower and upper quantile scatter plots as well to 
;       illustrate uncertainty in the estimate.
;		
;		Cheers,
;		Walt
;
;		From: pierre kirstetter [mailto:pierre.kirstetter@noaa.gov]
;		Sent: Tuesday, September 04, 2018 4:40 PM
;		To: Petersen, Walter A. (MSFC-ST11) <walt.petersen@nasa.gov>
;		Subject: Re: FW: cold-seasons comparison project
;		
;		Walt,
;		
;		Here are the relations derived from the PQPE. I provide the equation for the conditional expectation, this is the one 
;       that can be used in place of the 75S^2 relation. I provide also the equations for the conditional quantiles 25% and 75% 
;       to bound the expectation. It means that 50% of the conditional distribution of rates (conditioned on the MRMS reflectivity Z) 
;       should fall between these two curves.
;		
;		    expectation: Z = 59.5 R^2.57 or R = 0.204 Z^0.389
;		    quantile 25%: Z=255 R^2.42 or R = 0.101 Z^0.413
;		    quantile 75%: Z=33.3 R^2.58 or R = 0.257 Z^0.388   
;		
;		Please let me know if you have any question. Apologies for the delay.
;		
;		Best
;		Pierre  


               IF have_gv_swe THEN BEGIN
               	  
               	  skip_swe=0
        	  	  ; use rain rate (prefer rc) for non-snow values
               	  ; start with RC rain rates
               	  if have_gv_rc then begin
               	  	rain_rej=n_gr_rc_points_rejected
               	  	rain_avg=rc_avg_gv
          		    rain_stddev = rc_stddev_gv
          		    rain_max = rc_max_gv
               	  endif else if have_gv_rp then begin
               	  	rain_rej=n_gr_rp_points_rejected
               	  	rain_avg=rp_avg_gv
          		    rain_stddev = rp_stddev_gv
          		    rain_max = rp_max_gv
               	  endif else if have_gv_rr then begin 
               	  	rain_rej=n_gr_rr_points_rejected
               	  	rain_avg=rr_avg_gv
          		    rain_stddev = rr_stddev_gv
          		    rain_max = rr_max_gv
               	  endif else begin
               	  	   PRINT, "Error no Rain Rate values, skipping this event!
 					   GOTO, nextGRfile
               	  endelse
 
               	  ; process only matchups that are below 1.5km
               	  if (meantop le 1.5 ) then begin
					  ; compute snow index 
               	      snow_index = where((gvhidvals ge 3) and (gvhidvals le 7), num_snow)
               	      notsnow_index = where( ((gvhidvals lt 3) and (gvhidvals gt 0)) or (gvhidvals gt 7), num_notsnow)
	               	  gvkdp_z_posind = where(dbzvals ge 0 and gvkdpvals ge 0, num_gvkdp_z_posind)	               	  
               	  	  if num_snow eq 0 then begin
               	  	  
               	  	  	  n_gr_swedp_points_rejected = rain_rej
                  		  swedp_avg_gv = rain_avg
                  		  swedp_stddev_gv = rain_stddev
                  		  swedp_max_gv = rain_max
               	  	      
               	  	  	  n_gr_swe25_points_rejected = rain_rej
                  		  swe25_avg_gv = rain_avg
                  		  swe25_stddev_gv = rain_stddev
                  		  swe25_max_gv = rain_max
               	  	      
               	  	  	  n_gr_swe50_points_rejected = rain_rej
                  		  swe50_avg_gv = rain_avg
                  		  swe50_stddev_gv = rain_stddev
                  		  swe50_max_gv = rain_max
               	  	      
               	  	  	  n_gr_swe75_points_rejected = rain_rej
                  		  swe75_avg_gv = rain_avg
                  		  swe75_stddev_gv = rain_stddev
                  		  swe75_max_gv = rain_max
               	  	      
               	  	  	  n_gr_swemqt_points_rejected = rain_rej
                  		  swemqt_avg_gv = rain_avg
                  		  swemqt_stddev_gv = rain_stddev
                  		  swemqt_max_gv = rain_max
               	  	      
               	  	  	  n_gr_swemrms_points_rejected = rain_rej
                  		  swemrms_avg_gv = rain_avg
                  		  swemrms_stddev_gv = rain_stddev
                  		  swemrms_max_gv = rain_max
               	  	      
               	  	  	  skip_swe=1
               	  	  endif
               	  
               	  endif else begin
 	                  n_gr_swedp_points_rejected = Z_MISSING
	                  swedp_avg_gv = Z_MISSING
	                  swedp_stddev_gv = Z_MISSING
	                  swedp_max_gv = Z_MISSING
	                  
  	                  n_gr_swe25_points_rejected = Z_MISSING
	                  swe25_avg_gv = Z_MISSING
	                  swe25_stddev_gv = Z_MISSING
	                  swe25_max_gv = Z_MISSING

  	                  n_gr_swe50_points_rejected = Z_MISSING
	                  swe50_avg_gv = Z_MISSING
	                  swe50_stddev_gv = Z_MISSING
	                  swe50_max_gv = Z_MISSING

  	                  n_gr_swe75_points_rejected = Z_MISSING
	                  swe75_avg_gv = Z_MISSING
	                  swe75_stddev_gv = Z_MISSING
	                  swe75_max_gv = Z_MISSING
	                  
  	                  n_gr_swemqt_points_rejected = Z_MISSING
	                  swemqt_avg_gv = Z_MISSING
	                  swemqt_stddev_gv = Z_MISSING
	                  swemqt_max_gv = Z_MISSING
	                  
  	                  n_gr_swemrms_points_rejected = Z_MISSING
	                  swemrms_avg_gv = Z_MISSING
	                  swemrms_stddev_gv = Z_MISSING
	                  swemrms_max_gv = Z_MISSING
	                  
               	  	  skip_swe=1
               	  endelse
               	  
               	  if not skip_swe then begin
               
	               	  ; start with RC rain rates
	                  ; use RC rain rate (prefered, then RP, and RR) where snow is not detected
	               	  if have_gv_rc then begin
	               	  	rainvals=gvrcvals
	               	  endif else if have_gv_rp then begin
	               	  	rainvals=gvrpvals
	               	  endif else if have_gv_rr then begin 
	               	  	rainvals=gvrrvals
	               	  endif else begin
	               	  	   PRINT, "Error no Rain Rate values, skipping this event!
     					   GOTO, nextGRfile
	               	  endelse
		              Z=dbzvals
		              zposind = where(Z ge 0, num_zposind)
		              if num_zposind gt 0 then begin
		                  Z[zposind] = 10^(Z[zposind]/10)
		              
		                  ; Pierre's methods
		                  
		                  swe25=rainvals
		               	  swe25[zposind] = 0.101 * Z[zposind]^0.413
		                  ; use rain rate where snow is not detected
		                  if num_notsnow gt 0 then $
		                  		swe25 [notsnow_index]=rainvals[notsnow_index]
		                  altstats=mean_stddev_max_by_rules(swe25,'RR', dpr_rain_min, $
		                              0.0, SRAIN_BELOW_THRESH, WEIGHTS=binvols)
	           	  	  	  n_gr_swe25_points_rejected = altstats.rejects
	              		  swe25_avg_gv = altstats.mean
	              		  swe25_stddev_gv = altstats.stddev
	              		  swe25_max_gv = altstats.max
	           	  	      
	           	  	      swe50=rainvals
		               	  swe50[zposind] = 0.204 * Z[zposind]^0.389
		                  ; use RP rain rate where snow is not detected
		                  if num_notsnow gt 0 then $
		                  		swe50 [notsnow_index]=rainvals[notsnow_index]
		                  altstats=mean_stddev_max_by_rules(swe50,'RR', dpr_rain_min, $
		                              0.0, SRAIN_BELOW_THRESH, WEIGHTS=binvols)
	           	  	  	  n_gr_swe50_points_rejected = altstats.rejects
	              		  swe50_avg_gv = altstats.mean
	              		  swe50_stddev_gv = altstats.stddev
	              		  swe50_max_gv = altstats.max
	           	  	      
	            	  	  swe75=rainvals
	 	               	  swe75[zposind] = 0.257 * Z[zposind]^0.388
		                  ; use RP rain rate where snow is not detected
		                  if num_notsnow gt 0 then $
		                  		swe75 [notsnow_index]=rainvals[notsnow_index]
	 	                  altstats=mean_stddev_max_by_rules(swe75,'RR', dpr_rain_min, $
		                              0.0, SRAIN_BELOW_THRESH, WEIGHTS=binvols)	                              
	           	  	  	  n_gr_swe75_points_rejected = altstats.rejects
	              		  swe75_avg_gv = altstats.mean
	              		  swe75_stddev_gv = altstats.stddev
	              		  swe75_max_gv = altstats.max
	              		  		              	              		  	
	              		  ; Marquette relationship		              
							;Z=180S^2.0    or more usefully,
							;S = .0745*Z^0.5   (same deal with Z- it needs to be converted from its 
							; dBZ value to linear units- i.e., Z = 10^(dBZ/10))
	            	  	  swemqt=rainvals
	 	               	  swemqt[zposind] = 0.0745 * Z[zposind]^0.5
		                  ; use RP rain rate where snow is not detected
		                  if num_notsnow gt 0 then $
		                  		swemqt [notsnow_index]=rainvals[notsnow_index]
	 	                  altstats=mean_stddev_max_by_rules(swemqt,'RR', dpr_rain_min, $
		                              0.0, SRAIN_BELOW_THRESH, WEIGHTS=binvols)	                              
	           	  	  	  n_gr_swemqt_points_rejected = altstats.rejects
	              		  swemqt_avg_gv = altstats.mean
	              		  swemqt_stddev_gv = altstats.stddev
	              		  swemqt_max_gv = altstats.max
	              		  
	              		  ; MRMS relationship
							;S = Z^0.5 * 0.1155   (which should be the same as Z = 75 S^2)�.
							;and Z in linear units
	            	  	  swemrms=rainvals
	 	               	  swemrms[zposind] = 0.1155 * Z[zposind]^0.5
		                  ; use RP rain rate where snow is not detected
		                  if num_notsnow gt 0 then $
		                  		swemrms [notsnow_index]=rainvals[notsnow_index]
	 	                  altstats=mean_stddev_max_by_rules(swemrms,'RR', dpr_rain_min, $
		                              0.0, SRAIN_BELOW_THRESH, WEIGHTS=binvols)	                              
	           	  	  	  n_gr_swemrms_points_rejected = altstats.rejects
	              		  swemrms_avg_gv = altstats.mean
	              		  swemrms_stddev_gv = altstats.stddev
	              		  swemrms_max_gv = altstats.max

	               		  if (num_gvkdp_z_posind GT 0)  then begin
			               	  
			               	  ; compute swerr for snow bins using formula
			               	  swedp=rainvals  ; use rain rate where snow is not detected
			               	  ; original equation
			               	  ;swedp[gvkdp_z_posind] = 1.53 * gvkdpvals[gvkdp_z_posind]^0.68 * Z[gvkdp_z_posind]^0.29
			               	  ; fixed equation 10/2/18
	;Todd- this is a screw up on my part��������
	;I should have given you this equation for the S(KDP, Z)
	;
	;S = 1.48 * KDP^0.61 * Z^0.33
	;
	;Note that the multiplier and exponents are slightly different than what you are currently using.    But, we need to use this one.    
	;My guess is that there should not be a huge difference, but,��.
	;Can you just insert this fix and re run what you just did?  I�m really sorry�������..
	;Cheers,
	;Walt
			               	  swedp[gvkdp_z_posind] = 1.48 * gvkdpvals[gvkdp_z_posind]^0.61 * Z[gvkdp_z_posind]^0.33
			               	  ;Z = 10^(dbzvals/10)	               	  
			               	  ;swedp = 1.53 * gvkdpvals^0.68 * Z^0.29
			                  ;swedp [notsnow_index]=Z_MISSING
			                  ; use RC rain rate (prefered, then RP, and RR) where snow is not detected
			                  ; set any non-snow values back to rain values
			                  if num_notsnow gt 0 then $
			                  	  	swedp [notsnow_index]=rainvals[notsnow_index]
			                  
			                  altstats=mean_stddev_max_by_rules(swedp,'RR', dpr_rain_min, $
			                              0.0, SRAIN_BELOW_THRESH, WEIGHTS=binvols)
			                  n_gr_swedp_points_rejected = altstats.rejects
			                  swedp_avg_gv = altstats.mean
			                  swedp_stddev_gv = altstats.stddev
			                  swedp_max_gv = altstats.max
		                  endif else begin
	               	  	  	  n_gr_swedp_points_rejected = rain_rej
	                  		  swedp_avg_gv = rain_avg
	                  		  swedp_stddev_gv = rain_stddev
	                  		  swedp_max_gv = rain_max
		                  endelse

	                  endif else begin
	 	                  n_gr_swedp_points_rejected = Z_MISSING
		                  swedp_avg_gv = Z_MISSING
		                  swedp_stddev_gv = Z_MISSING
		                  swedp_max_gv = Z_MISSING

	           	  	  	  n_gr_swe25_points_rejected = Z_MISSING
	              		  swe25_avg_gv = Z_MISSING
	              		  swe25_stddev_gv = Z_MISSING
	              		  swe25_max_gv = Z_MISSING

	           	  	  	  n_gr_swe50_points_rejected = Z_MISSING
	              		  swe50_avg_gv = Z_MISSING
	              		  swe50_stddev_gv = Z_MISSING
	              		  swe50_max_gv = Z_MISSING

	           	  	  	  n_gr_swe75_points_rejected = Z_MISSING
	              		  swe75_avg_gv = Z_MISSING
	              		  swe75_stddev_gv = Z_MISSING
	              		  swe75_max_gv = Z_MISSING

	           	  	  	  n_gr_swemqt_points_rejected = Z_MISSING
	              		  swemqt_avg_gv = Z_MISSING
	              		  swemqt_stddev_gv = Z_MISSING
	              		  swemqt_max_gv = Z_MISSING

	           	  	  	  n_gr_swemrms_points_rejected = Z_MISSING
	              		  swemrms_avg_gv = Z_MISSING
	              		  swemrms_stddev_gv = Z_MISSING
	              		  swemrms_max_gv = Z_MISSING
	                  endelse	                 	                  
                  endif ; not skip_swe
;                  endif else begin
;                  
; 	                  n_gr_swedp_points_rejected = Z_MISSING
;	                  swedp_avg_gv = Z_MISSING
;	                  swedp_stddev_gv = Z_MISSING
;	                  swedp_max_gv = Z_MISSING
;	                  
;  	                  n_gr_swe25_points_rejected = Z_MISSING
;	                  swe25_avg_gv = Z_MISSING
;	                  swe25_stddev_gv = Z_MISSING
;	                  swe25_max_gv = Z_MISSING
;
;  	                  n_gr_swe50_points_rejected = Z_MISSING
;	                  swe50_avg_gv = Z_MISSING
;	                  swe50_stddev_gv = Z_MISSING
;	                  swe50_max_gv = Z_MISSING
;
;  	                  n_gr_swe75_points_rejected = Z_MISSING
;	                  swe75_avg_gv = Z_MISSING
;	                  swe75_stddev_gv = Z_MISSING
;	                  swe75_max_gv = Z_MISSING
;                  endelse

               ENDIF ; have_gv_swe

            ENDIF                  ; countGRpts GT 0

         ENDIF ELSE BEGIN          ; dpr_index GE 0 AND dpr_echoes[jpr] NE 0B
           ; case where no corr DPR gates in the ray are above dBZ threshold,
           ;   set the averages to the BELOW_THRESH special values
            IF ( dpr_index GE 0 AND dpr_echoes[jpr] EQ 0B ) THEN BEGIN
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
               swedp_avg_gv = SRAIN_BELOW_THRESH
               swedp_stddev_gv = SRAIN_BELOW_THRESH
               swedp_max_gv = SRAIN_BELOW_THRESH
               swe25_avg_gv = SRAIN_BELOW_THRESH
               swe25_stddev_gv = SRAIN_BELOW_THRESH
               swe25_max_gv = SRAIN_BELOW_THRESH
               swe50_avg_gv = SRAIN_BELOW_THRESH
               swe50_stddev_gv = SRAIN_BELOW_THRESH
               swe50_max_gv = SRAIN_BELOW_THRESH
               swe75_avg_gv = SRAIN_BELOW_THRESH
               swe75_stddev_gv = SRAIN_BELOW_THRESH
               swe75_max_gv = SRAIN_BELOW_THRESH
               swemqt_avg_gv = SRAIN_BELOW_THRESH
               swemqt_stddev_gv = SRAIN_BELOW_THRESH
               swemqt_max_gv = SRAIN_BELOW_THRESH
               swemrms_avg_gv = SRAIN_BELOW_THRESH
               swemrms_stddev_gv = SRAIN_BELOW_THRESH
               swemrms_max_gv = SRAIN_BELOW_THRESH
               IF ( have_gv_hid ) THEN hid_hist = INTARR(n_hid_cats)
               dzero_avg_gv = SRAIN_BELOW_THRESH
               dzero_stddev_gv = SRAIN_BELOW_THRESH
               dzero_max_gv = SRAIN_BELOW_THRESH
               nw_avg_gv = SRAIN_BELOW_THRESH
               nw_stddev_gv = SRAIN_BELOW_THRESH
               nw_max_gv = SRAIN_BELOW_THRESH
               dm_avg_gv = SRAIN_BELOW_THRESH
               dm_stddev_gv = SRAIN_BELOW_THRESH
               dm_max_gv = SRAIN_BELOW_THRESH
               n2_avg_gv = SRAIN_BELOW_THRESH
               n2_stddev_gv = SRAIN_BELOW_THRESH
               n2_max_gv = SRAIN_BELOW_THRESH
               correctedReflectFactor_avg = Z_BELOW_THRESH
               precipTotPSDparamHigh_avg = SRAIN_BELOW_THRESH
               precipTotPSDparamLow_avg = FLTARR(nPSDlo)
               precipTotPSDparamLow_avg[*] = SRAIN_BELOW_THRESH
               precipTotRate_avg = SRAIN_BELOW_THRESH
               precipTotWaterCont_avg = SRAIN_BELOW_THRESH
               precipTotWaterContSigma_avg = SRAIN_BELOW_THRESH
               cloudLiqWaterCont_avg = SRAIN_BELOW_THRESH
               cloudIceWaterCont_avg = SRAIN_BELOW_THRESH
               meantop = 0.0    ; should calculate something for this
               meanbotm = 0.0   ; ditto
            ENDIF
         ENDELSE          ; dpr_index GE 0 AND dpr_echoes[jpr] NE 0B

     ; =========================================================================
     ; WRITE COMPUTED AVERAGES AND METADATA TO OUTPUT ARRAYS FOR NETCDF

         IF ( writeMissing EQ 0 )  THEN BEGIN
         ; normal rainy footprint, write computed science variables
                  tocdf_gr_dbz[jpr,ielev] = dbz_avg_gv
                  tocdf_gr_stddev[jpr,ielev] = dbz_stddev_gv
                  tocdf_gr_max[jpr,ielev] = dbz_max_gv
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
                  IF have_gv_swe THEN BEGIN
                     tocdf_gr_swedp[jpr,ielev] = swedp_avg_gv
                     tocdf_gr_swedp_stddev[jpr,ielev] = swedp_stddev_gv
                     tocdf_gr_swedp_max[jpr,ielev] = swedp_max_gv
                     tocdf_gr_swe25[jpr,ielev] = swe25_avg_gv
                     tocdf_gr_swe25_stddev[jpr,ielev] = swe25_stddev_gv
                     tocdf_gr_swe25_max[jpr,ielev] = swe25_max_gv
                     tocdf_gr_swe50[jpr,ielev] = swe50_avg_gv
                     tocdf_gr_swe50_stddev[jpr,ielev] = swe50_stddev_gv
                     tocdf_gr_swe50_max[jpr,ielev] = swe50_max_gv
                     tocdf_gr_swe75[jpr,ielev] = swe75_avg_gv
                     tocdf_gr_swe75_stddev[jpr,ielev] = swe75_stddev_gv
                     tocdf_gr_swe75_max[jpr,ielev] = swe75_max_gv
                     tocdf_gr_swemqt[jpr,ielev] = swemqt_avg_gv
                     tocdf_gr_swemqt_stddev[jpr,ielev] = swemqt_stddev_gv
                     tocdf_gr_swemqt_max[jpr,ielev] = swemqt_max_gv
                     tocdf_gr_swemrms[jpr,ielev] = swemrms_avg_gv
                     tocdf_gr_swemrms_stddev[jpr,ielev] = swemrms_stddev_gv
                     tocdf_gr_swemrms_max[jpr,ielev] = swemrms_max_gv
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
                  IF have_gv_dm THEN BEGIN
                     tocdf_gr_dm[jpr,ielev] = dm_avg_gv
                     tocdf_gr_dm_stddev[jpr,ielev] = dm_stddev_gv
                     tocdf_gr_dm_max[jpr,ielev] = dm_max_gv
                  ENDIF
                  IF have_gv_n2 THEN BEGIN
                     tocdf_gr_n2[jpr,ielev] = n2_avg_gv
                     tocdf_gr_n2_stddev[jpr,ielev] = n2_stddev_gv
                     tocdf_gr_n2_max[jpr,ielev] = n2_max_gv
                  ENDIF
                 ; NOTE: No need to write tocdf_gr_blockage, its valid values
                 ; get assigned in COMPUTE_MEAN_BLOCKAGE()
                  IF DPR_scantype EQ 'MS' THEN BEGIN
                     tocdf_correctedReflectFactor[idxKuKa[swathID],jpr,ielev] = $
                       correctedReflectFactor_avg
                     tocdf_clutterStatus[idxKuKa[swathID],jpr,ielev] = UINT(clutterStatus)
                  ENDIF ELSE BEGIN
                     tocdf_correctedReflectFactor[jpr,ielev] = $
                          correctedReflectFactor_avg
                     tocdf_clutterStatus[jpr,ielev] = UINT(clutterStatus)
                  ENDELSE
                  tocdf_precipTotPSDparamHigh[jpr,ielev] = precipTotPSDparamHigh_avg
                  tocdf_precipTotPSDparamLow[*,jpr,ielev] = precipTotPSDparamLow_avg
                  tocdf_precipTotRate[jpr,ielev] = precipTotRate_avg
                  tocdf_precipTotWaterCont[jpr,ielev] = precipTotWaterCont_avg
                  tocdf_precipTotWaterContSigma[jpr,ielev] = precipTotWaterContSigma_avg
                  tocdf_cloudLiqWaterCont[jpr,ielev] = cloudLiqWaterCont_avg
                  tocdf_cloudIceWaterCont[jpr,ielev] = cloudIceWaterCont_avg
                  tocdf_top_hgt[jpr,ielev] = meantop
                  tocdf_botm_hgt[jpr,ielev] = meanbotm
         ENDIF ELSE BEGIN
            CASE dpr_index OF
                -1  :  BREAK
                      ; is range-edge point, science values in array were already
                      ;   initialized to special values for this, so do nothing
                -2  :  BEGIN
                      ; off-scan-edge point, set science values to special values
                          tocdf_gr_dbz[jpr,ielev] = FLOAT_OFF_EDGE
                          tocdf_gr_stddev[jpr,ielev] = FLOAT_OFF_EDGE
                          tocdf_gr_max[jpr,ielev] = FLOAT_OFF_EDGE
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
                          IF have_gv_swe THEN BEGIN
                             tocdf_gr_swedp[jpr,ielev] = FLOAT_OFF_EDGE
                             tocdf_gr_swedp_stddev[jpr,ielev] = FLOAT_OFF_EDGE
                             tocdf_gr_swedp_max[jpr,ielev] = FLOAT_OFF_EDGE
                             tocdf_gr_swe25[jpr,ielev] = FLOAT_OFF_EDGE
                             tocdf_gr_swe25_stddev[jpr,ielev] = FLOAT_OFF_EDGE
                             tocdf_gr_swe25_max[jpr,ielev] = FLOAT_OFF_EDGE
                             tocdf_gr_swe50[jpr,ielev] = FLOAT_OFF_EDGE
                             tocdf_gr_swe50_stddev[jpr,ielev] = FLOAT_OFF_EDGE
                             tocdf_gr_swe50_max[jpr,ielev] = FLOAT_OFF_EDGE
                             tocdf_gr_swe75[jpr,ielev] = FLOAT_OFF_EDGE
                             tocdf_gr_swe75_stddev[jpr,ielev] = FLOAT_OFF_EDGE
                             tocdf_gr_swe75_max[jpr,ielev] = FLOAT_OFF_EDGE
                             tocdf_gr_swemqt[jpr,ielev] = FLOAT_OFF_EDGE
                             tocdf_gr_swemqt_stddev[jpr,ielev] = FLOAT_OFF_EDGE
                             tocdf_gr_swemqt_max[jpr,ielev] = FLOAT_OFF_EDGE
                             tocdf_gr_swemrms[jpr,ielev] = FLOAT_OFF_EDGE
                             tocdf_gr_swemrms_stddev[jpr,ielev] = FLOAT_OFF_EDGE
                             tocdf_gr_swemrms_max[jpr,ielev] = FLOAT_OFF_EDGE
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
                          IF have_gv_dm THEN BEGIN
                             tocdf_gr_dm[jpr,ielev] = FLOAT_OFF_EDGE
                             tocdf_gr_dm_stddev[jpr,ielev] = FLOAT_OFF_EDGE
                             tocdf_gr_dm_max[jpr,ielev] = FLOAT_OFF_EDGE
                          ENDIF
                          IF have_gv_n2 THEN BEGIN
                             tocdf_gr_N2[jpr,ielev] = FLOAT_OFF_EDGE
                             tocdf_gr_N2_stddev[jpr,ielev] = FLOAT_OFF_EDGE
                             tocdf_gr_N2_max[jpr,ielev] = FLOAT_OFF_EDGE
                          ENDIF
                          IF do_this_elev_blockage EQ 1 THEN BEGIN
                             tocdf_gr_blockage[jpr,ielev] = FLOAT_OFF_EDGE
                          ENDIF
                          IF DPR_scantype EQ 'MS' THEN $
                             tocdf_correctedReflectFactor[idxKuKa[swathID],jpr,ielev] $
                                 = FLOAT_OFF_EDGE $
                          ELSE tocdf_correctedReflectFactor[jpr,ielev] = FLOAT_OFF_EDGE
                          tocdf_precipTotPSDparamHigh[jpr,ielev] = FLOAT_OFF_EDGE
                          tocdf_precipTotPSDparamLow[*,jpr,ielev] = FLOAT_OFF_EDGE
                          tocdf_precipTotRate[jpr,ielev] = FLOAT_OFF_EDGE
                          tocdf_precipTotWaterCont[jpr,ielev] = FLOAT_OFF_EDGE
                          tocdf_precipTotWaterContSigma[jpr,ielev] = FLOAT_OFF_EDGE
                          tocdf_cloudLiqWaterCont[jpr,ielev] = FLOAT_OFF_EDGE
                          tocdf_cloudIceWaterCont[jpr,ielev] = FLOAT_OFF_EDGE
                          tocdf_top_hgt[jpr,ielev] = FLOAT_OFF_EDGE
                          tocdf_botm_hgt[jpr,ielev] = FLOAT_OFF_EDGE
                       END
; TAB 11/27/18 This is where bad sweeps in DARW data should be handled
              ELSE  :  BEGIN
                      ; data internal issues, set science values to missing
                          tocdf_gr_dbz[jpr,ielev] = Z_MISSING
                          tocdf_gr_stddev[jpr,ielev] = Z_MISSING
                          tocdf_gr_max[jpr,ielev] = Z_MISSING
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
                          IF have_gv_swe THEN BEGIN
                             tocdf_gr_swedp[jpr,ielev] = Z_MISSING
                             tocdf_gr_swedp_stddev[jpr,ielev] = Z_MISSING
                             tocdf_gr_swedp_max[jpr,ielev] = Z_MISSING
                             tocdf_gr_swe25[jpr,ielev] = Z_MISSING
                             tocdf_gr_swe25_stddev[jpr,ielev] = Z_MISSING
                             tocdf_gr_swe25_max[jpr,ielev] = Z_MISSING
                             tocdf_gr_swe50[jpr,ielev] = Z_MISSING
                             tocdf_gr_swe50_stddev[jpr,ielev] = Z_MISSING
                             tocdf_gr_swe50_max[jpr,ielev] = Z_MISSING
                             tocdf_gr_swe75[jpr,ielev] = Z_MISSING
                             tocdf_gr_swe75_stddev[jpr,ielev] = Z_MISSING
                             tocdf_gr_swe75_max[jpr,ielev] = Z_MISSING
                             tocdf_gr_swemqt[jpr,ielev] = Z_MISSING
                             tocdf_gr_swemqt_stddev[jpr,ielev] = Z_MISSING
                             tocdf_gr_swemqt_max[jpr,ielev] = Z_MISSING
                             tocdf_gr_swemrms[jpr,ielev] = Z_MISSING
                             tocdf_gr_swemrms_stddev[jpr,ielev] = Z_MISSING
                             tocdf_gr_swemrms_max[jpr,ielev] = Z_MISSING
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
                          IF have_gv_dm THEN BEGIN
                             tocdf_gr_dm[jpr,ielev] = Z_MISSING
                             tocdf_gr_dm_stddev[jpr,ielev] = Z_MISSING
                             tocdf_gr_dm_max[jpr,ielev] = Z_MISSING
                          ENDIF
                          IF have_gv_n2 THEN BEGIN
                             tocdf_gr_N2[jpr,ielev] = Z_MISSING
                             tocdf_gr_N2_stddev[jpr,ielev] = Z_MISSING
                             tocdf_gr_N2_max[jpr,ielev] = Z_MISSING
                          ENDIF
                          IF do_this_elev_blockage EQ 1 THEN BEGIN
                             tocdf_gr_blockage[jpr,ielev] = Z_MISSING
                          ENDIF
                          IF DPR_scantype EQ 'MS' THEN $
                             tocdf_correctedReflectFactor[idxKuKa[swathID],jpr,ielev] $
                                 = Z_MISSING $
                          ELSE tocdf_correctedReflectFactor[jpr,ielev] = Z_MISSING
                          tocdf_precipTotPSDparamHigh[jpr,ielev] = Z_MISSING
                          tocdf_precipTotPSDparamLow[*,jpr,ielev] = Z_MISSING
                          tocdf_precipTotRate[jpr,ielev] = Z_MISSING
                          tocdf_precipTotWaterCont[jpr,ielev] = Z_MISSING
                          tocdf_precipTotWaterContSigma[jpr,ielev] = Z_MISSING
                          tocdf_cloudLiqWaterCont[jpr,ielev] = Z_MISSING
                          tocdf_cloudIceWaterCont[jpr,ielev] = Z_MISSING
                          tocdf_top_hgt[jpr,ielev] = Z_MISSING
                          tocdf_botm_hgt[jpr,ielev] = Z_MISSING
                       END
            ENDCASE
         ENDELSE

        ; assign the computed meta values to the output array slots
         tocdf_gr_rejected[jpr,ielev] = UINT(n_gr_points_rejected)
         IF have_gv_zdr THEN tocdf_gr_zdr_rejected[jpr,ielev] = $
                               UINT(n_gr_zdr_points_rejected)
         IF have_gv_kdp THEN tocdf_gr_kdp_rejected[jpr,ielev] = $
                               UINT(n_gr_kdp_points_rejected)
         IF have_gv_rhohv THEN tocdf_gr_rhohv_rejected[jpr,ielev] = $
                               UINT(n_gr_rhohv_points_rejected)
         IF have_gv_rc THEN tocdf_gr_rc_rejected[jpr,ielev] = $
                               UINT(n_gr_rc_points_rejected)
         IF have_gv_rp THEN tocdf_gr_rp_rejected[jpr,ielev] = $
                               UINT(n_gr_rp_points_rejected)
         IF have_gv_rr THEN tocdf_gr_rr_rejected[jpr,ielev] = $
                               UINT(n_gr_rr_points_rejected)
         IF have_gv_hid THEN tocdf_gr_hid_rejected[jpr,ielev] = $
                               UINT(n_gr_hid_points_rejected)
         IF have_gv_dzero THEN tocdf_gr_dzero_rejected[jpr,ielev] = $
                               UINT(n_gr_dzero_points_rejected)
         IF have_gv_nw THEN tocdf_gr_nw_rejected[jpr,ielev] = $
                               UINT(n_gr_nw_points_rejected)
         IF have_gv_dm THEN tocdf_gr_dm_rejected[jpr,ielev] = $
                               UINT(n_gr_dm_points_rejected)
         IF have_gv_n2 THEN tocdf_gr_n2_rejected[jpr,ielev] = $
                               UINT(n_gr_n2_points_rejected)
         IF have_gv_swe THEN tocdf_gr_swedp_rejected[jpr,ielev] = $
                               UINT(n_gr_swedp_points_rejected)
         IF have_gv_swe THEN tocdf_gr_swe25_rejected[jpr,ielev] = $
                               UINT(n_gr_swe25_points_rejected)
         IF have_gv_swe THEN tocdf_gr_swe50_rejected[jpr,ielev] = $
                               UINT(n_gr_swe50_points_rejected)
         IF have_gv_swe THEN tocdf_gr_swe75_rejected[jpr,ielev] = $
                               UINT(n_gr_swe75_points_rejected)
         IF have_gv_swe THEN tocdf_gr_swemqt_rejected[jpr,ielev] = $
                               UINT(n_gr_swemqt_points_rejected)
         IF have_gv_swe THEN tocdf_gr_swemrms_rejected[jpr,ielev] = $
                               UINT(n_gr_swemrms_points_rejected)
         tocdf_gr_expected[jpr,ielev] = UINT(countGRpts)
         IF DPR_scantype EQ 'MS' THEN BEGIN
            tocdf_n_correctedReflectFactor_rejected[idxKuKa[swathID],jpr,ielev] = $
               UINT(n_correctedReflectFactor_rejected)
            tocdf_n_dpr_expected[idxKuKa[swathID],jpr,ielev] = $
               UINT(dpr_gates_expected)
         ENDIF ELSE BEGIN
            tocdf_n_correctedReflectFactor_rejected[jpr,ielev] = $
               UINT(n_correctedReflectFactor_rejected)
            tocdf_n_dpr_expected[jpr,ielev] = UINT(dpr_gates_expected)
         ENDELSE
         tocdf_n_precipTotPSDparamHigh_rejected[jpr,ielev] = $
                               UINT(n_precipTotPSDparamHigh_rejected)
         tocdf_n_precipTotPSDparamLow_rejected[*,jpr,ielev] = $
                               UINT(n_precipTotPSDparamLow_rejected)
         tocdf_n_precipTotRate_rejected[jpr,ielev] = $
                               UINT(n_precipTotRate_rejected)
         tocdf_n_precipTotWaterCont_rejected[jpr,ielev] = $
                               UINT(n_precipTotWaterCont_rejected)
         tocdf_n_precipTotWaterContSigma_rejected[jpr,ielev] = $
                               UINT(n_precipTotWaterContSigma_rejected)
         tocdf_n_cloudLiqWaterCont_rejected[jpr,ielev] = $
                               UINT(n_cloudLiqWaterCont_rejected)
         tocdf_n_cloudIceWaterCont_rejected[jpr,ielev] = $
                               UINT(n_cloudIceWaterCont_rejected)

      ENDFOR  ; each DPR subarray point: jpr=0, numDPRrays-1

     ; END OF DPR-TO-GR RESAMPLING, THIS SWEEP

     ; =========================================================================

     ; *********** OPTIONAL SCORE COMPUTATIONS FOR SWEEP ***********

      IF keyword_set(run_scores) THEN BEGIN
        IF DPR_scantype EQ 'NS' THEN BEGIN
          idx2score = WHERE( tocdf_n_correctedReflectFactor_rejected[*,ielev] EQ 0 $
                        AND  tocdf_gr_rejected[*,ielev] EQ 0     $
                        AND  tocdf_n_dpr_expected[*,ielev] GT 0, count2score )
          IF count2score gt 0 THEN BEGIN
             print, "Mean DPR-GR, Npts with no regard to BB: ", $
                MEAN(tocdf_correctedReflectFactor[idx2score,ielev]- $
                     tocdf_gr_dbz[idx2score,ielev]), count2score
          ENDIF ELSE BEGIN
             print, "Mean DPR-GR: no points meet criteria."
          ENDELSE
        ENDIF   ; DPR_scantype EQ 'NS'
      ENDIF     ; keyword_set(run_scores)

    ; *********** OPTIONAL PPI PLOTTING FOR SWEEP **********

      IF keyword_set(plot_PPIs) THEN BEGIN
         titlepr = instrumentID+' '+DPR_scantype+' DPRGMI at ' + dpr_dtime + ' UTC'
         titlegv = siteID+', Elevation = ' + STRING(elev_angle[ielev],FORMAT='(f4.1)') $
                +', '+ text_sweep_times[ielev]
         titles = [titlepr, titlegv]

         IF DPR_scantype EQ 'MS' THEN BEGIN
            plot_elevation_gv_to_pr_z, $
                REFORM(tocdf_correctedReflectFactor[idxKuKa[swathID],*,*]), $
                tocdf_gr_dbz, sitelat, sitelon, tocdf_x_poly, tocdf_y_poly, $
                numDPRrays, ielev, TITLES=titles
         ENDIF ELSE BEGIN
            plot_elevation_gv_to_pr_z, tocdf_correctedReflectFactor, tocdf_gr_dbz, $
                sitelat, sitelon, tocdf_x_poly, tocdf_y_poly, $
                numDPRrays, ielev, TITLES=titles
         ENDELSE
      ENDIF

     ; =========================================================================

   ENDFOR     ; each elevation sweep: ielev = 0, num_elevations_out - 1

;  >>>>>>>>>>>>>>>>> END OF DPR-GR VOLUME MATCHING, ALL SWEEPS <<<<<<<<<<<<<<<<<<



;  ********** BEGIN OPTIONAL SCORE COMPUTATIONS, ALL SWEEPS ***************
   IF keyword_set(run_scores) AND DPR_scantype EQ 'NS' THEN BEGIN

   ; overall scores, all sweeps
   print, ""
   print, "All Sweeps Combined:"
      idx2score = WHERE( tocdf_n_correctedReflectFactor_rejected EQ 0 $
                    AND  tocdf_gr_rejected EQ 0     $
                    AND  tocdf_n_dpr_expected GT 0, count2score )
;      print, "Points with no regard to mean BB:"
      if count2score gt 0 THEN BEGIN
      print, "Mean DPR-GR, Npts: ", MEAN(tocdf_correctedReflectFactor[idx2score] $
                                - tocdf_gr_dbz[idx2score]), count2score
      ENDIF ELSE BEGIN
      print, "Mean DPR-GR: no points meet criteria."
      ENDELSE

   PRINT, ""
   PRINT, "End of scores/processing for ", siteID
   PRINT, ""

   ENDIF  ; run_scores

; ************ END OPTIONAL SCORE COMPUTATIONS, ALL SWEEPS *****************
