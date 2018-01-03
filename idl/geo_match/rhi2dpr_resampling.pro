;===============================================================================
;+
; Copyright © 2013, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; rhi2dpr_resampling.pro          Morris/SAIC/GPM_GV      August 2014
;
; DESCRIPTION
; -----------
; This file contains the DPR-GR volume matching, data plotting, and score
; computations sections of the code for the procedure rhi2dpr.  See file
; rhi2dpr.pro for a description of the full procedure.
;
; NOTE: THIS FILE MUST BE "INCLUDED" INSIDE THE PROCEDURE rhi2dpr, IT IS *NOT*
;       A COMPLETE IDL PROCEDURE AND CANNOT BE COMPILED OR RUN ON ITS OWN !!
;
; HISTORY
; -------
; 8/22/2014 by Bob Morris, GPM GV (SAIC)
;  - Created from polar2dpr_resampling.pro.
; 9/11/2014 by Bob Morris, GPM GV (SAIC)
;  - Slight modification to account for and allow isolated, discrete RHI
;    azimuth angles (wheel-spoke RHIs).
; 09/24/14 Morris, GPM GV, SAIC
; - Added BAD_TO_ZERO parameter to call to mean_stddev_max_by_rules() to control
;   how below-badthresh values are handled in the averaging for Z.
; 11/05/14 by Bob Morris, GPM GV (SAIC)
;  - Added processing of GR RC and RP rainrate fields for version 1.1 file.
; 03/17/15 by Bob Morris, GPM GV (SAIC)
;  - Use beam height above MSL and ELLIPSOID_BIN_DPR to compute DPR bin numbers
;    for GR beam overlap, ignoring binEllipsoid.
;  - Handle situation of no paramDSD field present in SLV group (2ADPR/MS).
;  - Add logic to map HID categories from HC field to the FH categories when
;    HC is contained in the radar UF file (DARW radar).
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;===============================================================================


;  >>>>>>>>>>>>>> BEGINNING OF DPR-GR VOLUME MATCHING, ALL SWEEPS <<<<<<<<<<<<<<<

   FOR ielev = 0, num_elevations_out - 1 DO BEGIN
      print, ""
      print, "Elevation: ", tocdf_elev_angle[ielev]

     ; read/get the number of rays in the sweep: nrays
      nrays = nrhi

     ; =========================================================================
     ; START PREPROCESSING ON THE SWEEP DATA

;      beam_width = radar.volume[z_vol_num].sweep[0].h.beam_width
     ; not-to-exceed difference between beam center azimuths (generous slop)
      azm_delta = beam_width * 1.25

     ; build an nrays-sized 1-D array of ray azimuths (float degrees), and
     ;   NRAYS+1 ray-edge az's, and matching arrays of sin(az) and cos(az)
      rayazms = rhiAzimuths
      sinrayazms = SIN( rayazms*!PI/180. )
      cosrayazms = COS( rayazms*!PI/180. )
      rayedgeazms = FLTARR(nrays+1)

     ; Figure out whether we are scanning CW (+az direction) or CCW
      azsign = 0
      FOR iray = 1, nrays-1 DO BEGIN
         azdiff = ABS(rayazms[iray-1]-rayazms[iray])
;         IF azdiff LT azm_delta AND azdiff GT 0.0 THEN BEGIN
         IF azdiff GT 0.0 THEN BEGIN  ; allow isolated, discrete rhi azimuths
            azsign = (rayazms[iray]-rayazms[iray-1])/azdiff
            BREAK  ; jump out of loop ASAP
         ENDIF
      ENDFOR
      IF azsign EQ 0 THEN BEGIN
         PRINT, "Error computing sweep direction, skipping this event!
         GOTO, nextGRfile
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
                rayedgeazms[iray]=rayazms[iray-1] + azsign * beam_width/2.0
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
             rayedgeazms[0] = rayazms[0] - azsign * beam_width / 2.0
          END

      ENDCASE

     ; The leading edge azimuth of the last ray is the trailing edge of the 1st
     ;   (already checked for an improper beam width result in above)
      rayedgeazms[nrays] = rayedgeazms[0]

      sinrayedgeazms = SIN( rayedgeazms*!PI/180. )
      cosrayedgeazms = COS( rayedgeazms*!PI/180. )

     ; get necessary sweep/ray/bin parameters
      beamwidth_radians = beam_width * !PI / 180.
;      gate_space_gv = radar.volume[z_vol_num].sweep[0].ray[0].h.gate_size/1000.  ; units converted to km
     ; find the ray at this aligned elevation with the fewest number of bins,
     ; and size our b-scan arrays according to this value
      nbins=MIN(n_bins_filled[*,ielev])
      bin1test = range_bin1[0,ielev]
      idxbin1 = WHERE(range_bin1[*,ielev] NE bin1test, countdiffbin)
      IF countdiffbin NE 0 THEN MESSAGE, "Different range_bin1 value between azimuths."

     ; arrays to hold the along-ground range, beam height, and beam x-sect size
     ;   at each gate:
      ground_range = FLTARR(nbins)
      height = FLTARR(nbins)
      beam_diam = FLTARR(nbins)

     ; extract GR data arrays of [nbins,nrays] (distance vs angle 'b-scan')
     ; for each available GR field from the previously aligned "PPI" arrays
      bscan = z_ppi[0:nbins-1,*,ielev]      ; drop the 'padding' bins
      IF have_gv_zdr THEN zdr_bscan = zdr_ppi[0:nbins-1,*,ielev]
      IF have_gv_kdp THEN kdp_bscan = kdp_ppi[0:nbins-1,*,ielev]
      IF have_gv_rhohv THEN rhohv_bscan = rhohv_ppi[0:nbins-1,*,ielev]
      IF have_gv_rc THEN rc_bscan = rc_ppi[0:nbins-1,*,ielev]
      IF have_gv_rp THEN rp_bscan = rp_ppi[0:nbins-1,*,ielev]
      IF have_gv_rr THEN rr_bscan = rr_ppi[0:nbins-1,*,ielev]
      IF have_gv_hid THEN hid_bscan = hid_ppi[0:nbins-1,*,ielev]
      IF have_gv_dzero THEN dzero_bscan = dzero_ppi[0:nbins-1,*,ielev]
      IF have_gv_nw THEN nw_bscan = nw_ppi[0:nbins-1,*,ielev]

     ; build 1-D arrays of GR radial bin ground_range (float km), beam width,
     ;   and beam height from origin bin to max bin, each of size nbins (cut
     ;   this and the b-scan off at some radial distance threshold??) (all GR
     ;   radials for an elevation have the same distance from radar, height, and
     ;   width for a given bin #)
      thisrange = 0.0
      thisheight = 0.0
      FOR bin_index = 0, nbins-1 DO BEGIN
         ;rsl_get_gr_slantr_h, ray, bin_index, thisrange, $
         ;                          slant_range, thisheight
         slant_range = (bin1test / 1000.) + bin_index * gate_space_gv
         rsl_get_groundr_and_h, slant_range, mean_elevs[ielev], thisrange, thisheight
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
      pridxlut = LONARR(nrays*maxGRbin*4)
      gvidxlut = ULONARR(nrays*maxGRbin*4)
      overlaplut = FLTARR(nrays*maxGRbin*4)
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

      max_sep = max_DPR_footprint_diag_halfwidth  ; for ruff_distance thresholding
      max_sep_SQR = max_sep^2                     ; for truedist_SQR thresholding

      FOR jpr=0, numDPRrays-1 DO BEGIN
         plotting = 0
         dpr_index = dpr_master_idx[jpr]
       ; only map GR to non-BOGUS DPR points having one or more above-threshold
       ;   reflectivity bins in the DPR ray
         IF ( dpr_index GE 0 AND dpr_echoes[jpr] NE 0B ) THEN BEGIN
           ; compute rough distance between DPR footprint x,y and GR b-scan x,y;
           ; if either dX or dY is > max sep, then the footprints don't overlap
            ;max_sep = max_DPR_footprint_diag_halfwidth ;+ GR_bin_max_axis_len
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
                  ;truedist = sqrt( (dpr_x_center[jpr,ielev]-xbin[closebyidx1])^2  $
                  ;                +(dpr_y_center[jpr,ielev]-ybin[closebyidx1])^2 )
                  ;closebyidx = WHERE(truedist le max_sep, countclose )
                  truedist_SQR = (dpr_x_center[jpr,ielev]-xbin[closebyidx1])^2  $
                                +(dpr_y_center[jpr,ielev]-ybin[closebyidx1])^2
                  closebyidx = WHERE(truedist_SQR le max_sep_SQR, countclose )

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

                       ; write the lookup table values for this DPR-GR overlap pairing
                        pridxlut[lut_count] = dpr_index
                        gvidxlut[lut_count] = gvidx[closebyidx1[closebyidx[iclose]]]
                       ; use a Barnes-like gaussian weighting, using 2*max_sep as the
                       ;  effective radius of influence to increase the edge weights
                       ;  beyond pure linear-by-distance weighting
                        ;weighting = EXP( - (truedist[closebyidx[iclose]]/max_sep)^2 )
                        weighting = EXP( - (truedist_SQR[closebyidx[iclose]]/max_sep_SQR) )
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

      ENDFOR    ; pr footprints

     ; =========================================================================
     ; COMPUTE THE DPR AND GR REFLECTIVITY AND 3D RAIN RATE AVERAGES

     ; The LUTs are complete for this sweep, now do the resampling/averaging.
     ; Build the DPR-GR intersection "data cone" for the sweep, in DPR coordinates
     ; (horizontally) and within the vertical layer defined by the GV radar
     ; beam top/bottom:

      FOR jpr=0, numDPRrays-1 DO BEGIN
        ; init output variables defined/set in loop/if
         writeMISSING = 1
         countGRpts = 0UL              ; # GR bins mapped to this DPR footprint
         n_gr_points_rejected = 0UL    ; # of above that are below GR dBZ cutoff
         n_gr_zdr_points_rejected = 0UL     ; # of above that are MISSING Zdr
         n_gr_kdp_points_rejected = 0UL     ; # of above that are MISSING Kdp
         n_gr_rhohv_points_rejected = 0UL   ; # of above that are MISSING RHOhv
         n_gr_rc_points_rejected = 0UL ; # of above that are below GV RC cutoff
         n_gr_rp_points_rejected = 0UL ; # of above that are below GV RP cutoff
         n_gr_rr_points_rejected = 0UL ; # of above that are below GV RR cutoff
         n_gr_hid_points_rejected = 0UL    ; # of above with undetermined HID
         n_gr_dzero_points_rejected = 0UL  ; # of above that are MISSING D0
         n_gr_nw_points_rejected = 0UL     ; # of above that are MISSING Nw
         dpr_gates_expected = 0UL      ; # DPR gates within the sweep vert. bounds
         n_meas_zgates_rejected = 0UL  ; # of above that are below DPR dBZ cutoff
         n_corr_zgates_rejected = 0UL  ; ditto, for corrected DPR Z
         n_corr_rgates_rejected = 0UL  ; # gates below DPR rainrate cutoff
         n_dpr_dm_gates_rejected = 0UL  ; # gates with missing Dm
         n_dpr_nw_gates_rejected = 0UL  ; # gates with missing Nw
         clutterStatus = 0UL           ; result of clutter proximity for volume

         dpr_index = dpr_master_idx[jpr]

         IF ( dpr_index GE 0 AND dpr_echoes[jpr] NE 0B ) THEN BEGIN

           ; expand this DPR master index into its scan coordinates.  Use
           ;   BB_Hgt as the subscripted data array
            rayscan = ARRAY_INDICES( BB_Hgt, dpr_index )
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
                           Z_BELOW_THRESH, WEIGHTS=binvols, /LOG, /BAD_TO_ZERO)
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

              ; compute mean height above surface of GR beam top and beam bottom
              ;   for all GR points geometrically mapped to this DPR point
               meantop = MEAN( binhgts + bindepths/2.0 )
               meanbotm = MEAN( binhgts - bindepths/2.0 )
              ; compute height above ellipsoid for computing DPR gates that
              ; intersect the GR beam boundaries.  Assume ellipsoid and geoid
              ; (MSL surface) are the same
               meantopMSL = meantop + siteElev
               meanbotmMSL = meanbotm + siteElev

              ; make a copy of binRealSurface and set all values to the fixed
              ; bin number at the ellipsoid for the swath being processed.
               binEllipsoid = binRealSurface
               binEllipsoid[*,*] = ELLIPSOID_BIN_DPR

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
               dbz_meas_avg = get_dpr_layer_average(           $
                                    topMeasGate, botmMeasGate, $
                                    scandpr, raydpr, dbz_meas, $
                                    DBZSCALEMEAS, dpr_dbz_min, $
                                    numDPRgates, binClutterFreeBottom, /LOGAVG )
               n_meas_zgates_rejected = dpr_gates_expected - numDPRgates

               numDPRgates = 0
               clutterStatus = 0  ; get once for all 3 fields, same value applies
               dbz_corr_avg = get_dpr_layer_average(           $
                                    topCorrGate, botmCorrGate, $
                                    scandpr, raydpr, dbz_corr, $
                                    DBZSCALECORR, dpr_dbz_min, $
                                    numDPRgates, binClutterFreeBottom, $
                                    clutterStatus, /LOGAVG )
               n_corr_zgates_rejected = dpr_gates_expected - numDPRgates

               IF DO_RAIN_CORR THEN BEGIN
                  numDPRgates = 0
                  rain_corr_avg = get_dpr_layer_average(           $
                                    topCorrGate, botmCorrGate,  $
                                    scandpr, raydpr, rain_corr, $
                                    RAINSCALE, dpr_rain_min, $
                                    numDPRgates, binClutterFreeBottom )
                  n_corr_rgates_rejected = dpr_gates_expected - numDPRgates
               ENDIF ELSE BEGIN
                  ; we have no rain_corr field for this instrument/swath
                  rain_corr_avg = Z_MISSING
                  n_corr_rgates_rejected = dpr_gates_expected
               ENDELSE

               IF ( have_paramdsd ) THEN BEGIN
                  numDPRgates = 0
                  dpr_dm_avg = get_dpr_layer_average(                   $
                                     topMeasGate, botmMeasGate,         $
                                     scandpr, raydpr, dpr_Dm, 1.0, 0.1, $
                                     numDPRgates, binClutterFreeBottom )
                  n_dpr_dm_gates_rejected = dpr_gates_expected - numDPRgates

                  numDPRgates = 0
                  dpr_nw_avg = get_dpr_layer_average(                   $
                                     topMeasGate, botmMeasGate,         $
                                     scandpr, raydpr, dpr_Nw, 1.0, 1.0, $
                                     numDPRgates, binClutterFreeBottom )
                  n_dpr_nw_gates_rejected = dpr_gates_expected - numDPRgates
               ENDIF

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
               IF ( have_gv_hid ) THEN hid_hist = INTARR(n_hid_cats)
               dzero_avg_gv = SRAIN_BELOW_THRESH
               dzero_stddev_gv = SRAIN_BELOW_THRESH
               dzero_max_gv = SRAIN_BELOW_THRESH
               nw_avg_gv = SRAIN_BELOW_THRESH
               nw_stddev_gv = SRAIN_BELOW_THRESH
               nw_max_gv = SRAIN_BELOW_THRESH
               dbz_meas_avg = Z_BELOW_THRESH
               dbz_corr_avg = Z_BELOW_THRESH
               rain_corr_avg = SRAIN_BELOW_THRESH
               dpr_dm_avg = Z_BELOW_THRESH
               dpr_nw_avg = Z_BELOW_THRESH
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
                  tocdf_meas_dbz[jpr,ielev] = dbz_meas_avg
                  tocdf_corr_dbz[jpr,ielev] = dbz_corr_avg
                  tocdf_corr_rain[jpr,ielev] = rain_corr_avg
                  tocdf_dm[jpr,ielev] = dpr_dm_avg
                  tocdf_nw[jpr,ielev] = dpr_nw_avg
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
                          tocdf_meas_dbz[jpr,ielev] = FLOAT_OFF_EDGE
                          tocdf_corr_dbz[jpr,ielev] = FLOAT_OFF_EDGE
                          tocdf_corr_rain[jpr,ielev] = FLOAT_OFF_EDGE
                          tocdf_dm[jpr,ielev] = FLOAT_OFF_EDGE
                          tocdf_nw[jpr,ielev] = FLOAT_OFF_EDGE
                          tocdf_top_hgt[jpr,ielev] = FLOAT_OFF_EDGE
                          tocdf_botm_hgt[jpr,ielev] = FLOAT_OFF_EDGE
                       END
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
                          tocdf_meas_dbz[jpr,ielev] = Z_MISSING
                          tocdf_corr_dbz[jpr,ielev] = Z_MISSING
                          tocdf_corr_rain[jpr,ielev] = Z_MISSING
                          tocdf_dm[jpr,ielev] = Z_MISSING
                          tocdf_nw[jpr,ielev] = Z_MISSING
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
         tocdf_gr_expected[jpr,ielev] = UINT(countGRpts)
         tocdf_meas_z_rejected[jpr,ielev] = UINT(n_meas_zgates_rejected)
         tocdf_corr_z_rejected[jpr,ielev] = UINT(n_corr_zgates_rejected)
         tocdf_corr_r_rejected[jpr,ielev] = UINT(n_corr_rgates_rejected)
         tocdf_dpr_dm_rejected[jpr,ielev] = UINT(n_dpr_dm_gates_rejected)
         tocdf_dpr_nw_rejected[jpr,ielev] = UINT(n_dpr_nw_gates_rejected)
         tocdf_dpr_expected[jpr,ielev] = UINT(dpr_gates_expected)
         tocdf_clutterStatus[jpr,ielev] = UINT(clutterStatus)

      ENDFOR  ; each DPR subarray point: jpr=0, numDPRrays-1

     ; END OF DPR-TO-GR RESAMPLING, THIS SWEEP

     ; =========================================================================

     ; *********** OPTIONAL SCORE COMPUTATIONS FOR SWEEP ***********

      IF keyword_set(run_scores) THEN BEGIN

        IF ielev EQ 0 THEN BEGIN
          print,""
          idxBBdef = WHERE( tocdf_BB_Hgt GT 0.0 AND tocdf_rainType EQ 1, countBBdef )
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
          idx2score = WHERE( tocdf_corr_z_rejected[*,ielev] EQ 0 $
                        AND  tocdf_gr_rejected[*,ielev] EQ 0     $
                        AND  tocdf_dpr_expected[*,ielev] GT 0     $
                        AND  tocdf_top_hgt[*,ielev] LT meanBB-0.75, count2score )
          IF count2score gt 0 THEN BEGIN
;            print, "Points below mean BB:"
             print, "BELOW BB Mean DPR-GR, Npts: ", MEAN( tocdf_corr_dbz[idx2score,ielev] $
                                   - tocdf_gr_dbz[idx2score,ielev] ), count2score
          ENDIF
          idx2score = WHERE( tocdf_corr_z_rejected[*,ielev] EQ 0 $
                        AND  tocdf_gr_rejected[*,ielev] EQ 0     $
                        AND  tocdf_dpr_expected[*,ielev] GT 0     $
                        AND  tocdf_botm_hgt[*,ielev] GT meanBB+0.75, count2score )
          IF count2score gt 0 THEN BEGIN
;             print, "Points above mean BB:"
             print, "ABOVE BB Mean DPR-GR, Npts: ", MEAN( tocdf_corr_dbz[idx2score,ielev] $
                                   - tocdf_gr_dbz[idx2score,ielev] ), count2score
          ENDIF
        ENDIF

        idx2score = WHERE( tocdf_corr_z_rejected[*,ielev] EQ 0 $
                      AND  tocdf_gr_rejected[*,ielev] EQ 0     $
                      AND  tocdf_dpr_expected[*,ielev] GT 0, count2score )
        IF count2score gt 0 THEN BEGIN
           print, "Mean DPR-GR, Npts with no regard to BB: ", $
              MEAN(tocdf_corr_dbz[idx2score,ielev]-tocdf_gr_dbz[idx2score,ielev]), count2score
        ENDIF ELSE BEGIN
           print, "Mean DPR-GR: no points meet criteria."
        ENDELSE

      ENDIF  ; keyword_set(run_scores)

    ; *********** OPTIONAL PPI PLOTTING FOR SWEEP **********

      IF keyword_set(plot_RHIs) THEN BEGIN
         titlepr = 'DPR at ' + dpr_dtime + ' UTC'
         titlegv = siteID+', Elevation = ' + STRING(tocdf_elev_angle[ielev],FORMAT='(f4.1)') $
                +', '+ text_sweep_times[0]
         titles = [titlepr, titlegv]

         plot_elevation_gv_to_pr_z, tocdf_corr_dbz, tocdf_gr_dbz, sitelat, $
            sitelon, tocdf_x_poly, tocdf_y_poly, numDPRrays, ielev, TITLES=titles
      ENDIF

     ; =========================================================================

   ENDFOR     ; each elevation sweep: ielev = 0, num_elevations_out - 1

;  >>>>>>>>>>>>>>>>> END OF DPR-GR VOLUME MATCHING, ALL SWEEPS <<<<<<<<<<<<<<<<<<



;  ********** BEGIN OPTIONAL SCORE COMPUTATIONS, ALL SWEEPS ***************
   IF keyword_set(run_scores) THEN BEGIN

   ; overall scores, all sweeps
   print, ""
   print, "All Sweeps Combined:"
   IF countBBdef GT 0 THEN BEGIN
;      meanBB = MEAN(tocdf_BB_Hgt[idxBBdef])/1000.  ; m to km
      print, ""
      print, "Mean BB: ", meanBB
      idx2score = WHERE( tocdf_corr_z_rejected EQ 0 $
                    AND  tocdf_gr_rejected EQ 0     $
                    AND  tocdf_dpr_expected GT 0     $
                    AND  tocdf_top_hgt LT meanBB-0.75, count2score )
      IF count2score gt 0 THEN BEGIN
         print, "BELOW BB Mean DPR-GR, Npts: ", MEAN( tocdf_corr_dbz[idx2score] $
                                   - tocdf_gr_dbz[idx2score] ), count2score
      ENDIF
      idx2score = WHERE( tocdf_corr_z_rejected EQ 0 $
                    AND  tocdf_gr_rejected EQ 0     $
                    AND  tocdf_dpr_expected GT 0     $
                    AND  tocdf_botm_hgt GT meanBB+0.75, count2score )
      IF count2score gt 0 THEN BEGIN
         print, "ABOVE BB Mean DPR-GR, Npts: ", MEAN( tocdf_corr_dbz[idx2score] $
                                   - tocdf_gr_dbz[idx2score] ), count2score
      ENDIF
   ENDIF ELSE BEGIN
      idx2score = WHERE( tocdf_corr_z_rejected EQ 0 $
                    AND  tocdf_gr_rejected EQ 0     $
                    AND  tocdf_dpr_expected GT 0, count2score )
;      print, "Points with no regard to mean BB:"
      if count2score gt 0 THEN BEGIN
      print, "Mean DPR-GR, Npts: ", MEAN(tocdf_corr_dbz[idx2score] $
                                - tocdf_gr_dbz[idx2score]), count2score
      ENDIF ELSE BEGIN
      print, "Mean DPR-GR: no points meet criteria."
      ENDELSE
   ENDELSE

   PRINT, ""
   PRINT, "End of scores/processing for ", siteID
   PRINT, ""

   ENDIF  ; run_scores

; ************ END OPTIONAL SCORE COMPUTATIONS, ALL SWEEPS *****************
