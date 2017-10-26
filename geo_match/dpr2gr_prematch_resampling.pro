;===============================================================================
;+
; Copyright © 2016, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; dpr2gr_prematch_resampling.pro          Morris/SAIC/GPM_GV      March 2016
;
; DESCRIPTION
; -----------
; This file contains the DPR-GR volume matching, data plotting, and score
; computations sections of the code for the procedure dpr2gr_prematch.  See
; file dpr2gr_prematch.pro for a description of the full procedure.
;
; NOTE: THIS FILE MUST BE "INCLUDED" INSIDE THE PROCEDURE dpr2gr_prematch.pro,
; IT IS *NOT* A COMPLETE IDL PROCEDURE AND CANNOT BE COMPILED OR RUN ON ITS OWN!
;
; HISTORY
; -------
; 3/2016 by Bob Morris, GPM GV (SAIC)
;  - Created from polar2dpr_resampling.pro.
;
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

     ; =========================================================================
     ; COMPUTE THE DPR AND GR REFLECTIVITY AND 3D RAIN RATE AVERAGES

     ; The LUTs are complete for this sweep, now do the resampling/averaging.
     ; Build the DPR-GR intersection "data cone" for the sweep, in DPR coordinates
     ; (horizontally) and within the vertical layer defined by the GV radar
     ; beam top/bottom:

      FOR jpr=0, numDPRrays-1 DO BEGIN
        ; init output variables defined/set in loop/if
         writeMISSING = 1
         dpr_gates_expected = 0UL      ; # DPR gates within the sweep vert. bounds
         n_meas_zgates_rejected = 0UL  ; # of above that are below DPR dBZ cutoff
         n_corr_zgates_rejected = 0UL  ; ditto, for corrected DPR Z
         n_corr_rgates_rejected = 0UL  ; # gates below DPR rainrate cutoff
         n_dpr_dm_gates_rejected = 0UL  ; # gates with missing Dm
         n_dpr_nw_gates_rejected = 0UL  ; # gates with missing Nw
         clutterStatus = 0UL           ; result of clutter proximity for volume

         dpr_index = dpr_master_idx[jpr]
         crankem = (dpr_echoes[jpr] NE 0B) AND $
                   (data_GR2DPR.TOPHEIGHT[jpr,ielev] GT 0.0) AND $
                   (data_GR2DPR.BOTTOMHEIGHT[jpr,ielev] GT 0.0)
;help, crankem, dpr_echoes[jpr], data_GR2DPR.BOTTOMHEIGHT[jpr,ielev], data_GR2DPR.TOPHEIGHT[jpr,ielev]
         IF ( dpr_index GE 0 AND crankem ) THEN BEGIN
              writeMissing = 0
              raydpr = data_GR2DPR.RAYNUM[jpr]
              scandpr = data_GR2DPR.SCANNUM[jpr]

              ; compute height above ellipsoid for computing DPR gates that
              ; intersect the GR beam boundaries.  Assume ellipsoid and geoid
              ; (MSL surface) are the same
               meantopMSL = data_GR2DPR.TOPHEIGHT[jpr,ielev] + siteElev
               meanbotmMSL = data_GR2DPR.BOTTOMHEIGHT[jpr,ielev] + siteElev
;help, ielev, raydpr, scandpr, dpr_index, meantopMSL, meanbotmMSL
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
;if dbz_meas_avg LT 0.0 then BEGIN
;help, dbz_meas_avg,topMeasGate, botmMeasGate,numDPRgates,scandpr, raydpr
;print, dbz_meas[topMeasGate:botmMeasGate, raydpr, scandpr]
;print, dbz_meas[(topMeasGate+botmMeasGate)/2, RAYDPR,SCANDPR]
;stop
;endif
               numDPRgates = 0
               clutterStatus = 0  ; get once for all 3 fields, same value applies
               dbz_corr_avg = get_dpr_layer_average(           $
                                    topCorrGate, botmCorrGate, $
                                    scandpr, raydpr, dbz_corr, $
                                    DBZSCALECORR, dpr_dbz_min, $
                                    numDPRgates, binClutterFreeBottom, $
                                    CLUTTERFLAG=clutterFlag, clutterStatus, $
                                    /LOGAVG )
               n_corr_zgates_rejected = dpr_gates_expected - numDPRgates

;               IF clutterStatus GE 10 $
;                  THEN print, "Clutter found at level,ray,scan ", ielev, raydpr, scandpr

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
         ENDIF ELSE BEGIN          ; dpr_index GE 0 AND dpr_echoes[jpr] NE 0B
           ; case where no corr DPR gates in the ray are above dBZ threshold,
           ; or sample heights are undefined due to no valid GR bins, set
           ; averages to BELOW_THRESH special value
            IF ( dpr_index GE 0 AND crankem EQ 0 ) THEN BEGIN
               writeMissing = 0
               dbz_meas_avg = Z_BELOW_THRESH
               dbz_corr_avg = Z_BELOW_THRESH
               rain_corr_avg = SRAIN_BELOW_THRESH
               IF ( have_paramdsd ) THEN BEGIN
                  dpr_dm_avg = Z_BELOW_THRESH
                  dpr_nw_avg = Z_BELOW_THRESH
               ENDIF
               ;meantop = 0.0    ; should calculate something for this
               ;meanbotm = 0.0   ; ditto
            ENDIF
         ENDELSE          ; ELSE for dpr_index GE 0 AND dpr_echoes[jpr] NE 0B

     ; =========================================================================
     ; WRITE COMPUTED AVERAGES AND METADATA TO OUTPUT ARRAYS FOR NETCDF

         IF ( writeMissing EQ 0 )  THEN BEGIN
         ; normal rainy footprint, write computed science variables
                  tocdf_meas_dbz[jpr,ielev] = dbz_meas_avg
                  tocdf_corr_dbz[jpr,ielev] = dbz_corr_avg
                  tocdf_corr_rain[jpr,ielev] = rain_corr_avg
                  IF ( have_paramdsd ) THEN BEGIN
                     tocdf_dm[jpr,ielev] = dpr_dm_avg
                     tocdf_nw[jpr,ielev] = dpr_nw_avg
                  ENDIF
         ENDIF ELSE BEGIN
            CASE dpr_index OF
                -1  :  BREAK
                      ; is range-edge point, science values in array were already
                      ;   initialized to special values for this, so do nothing
                -2  :  BEGIN
                      ; off-scan-edge point, set science values to special values
                          tocdf_meas_dbz[jpr,ielev] = FLOAT_OFF_EDGE
                          tocdf_corr_dbz[jpr,ielev] = FLOAT_OFF_EDGE
                          tocdf_corr_rain[jpr,ielev] = FLOAT_OFF_EDGE
                          tocdf_dm[jpr,ielev] = FLOAT_OFF_EDGE
                          tocdf_nw[jpr,ielev] = FLOAT_OFF_EDGE
                       END
              ELSE  :  BEGIN
                      ; data internal issues, set science values to missing
                          tocdf_meas_dbz[jpr,ielev] = Z_MISSING
                          tocdf_corr_dbz[jpr,ielev] = Z_MISSING
                          tocdf_corr_rain[jpr,ielev] = Z_MISSING
                          tocdf_dm[jpr,ielev] = Z_MISSING
                          tocdf_nw[jpr,ielev] = Z_MISSING
                       END
            ENDCASE
         ENDELSE

        ; assign the computed meta values to the output array slots
         tocdf_meas_z_rejected[jpr,ielev] = UINT(n_meas_zgates_rejected)
         tocdf_corr_z_rejected[jpr,ielev] = UINT(n_corr_zgates_rejected)
         tocdf_corr_r_rejected[jpr,ielev] = UINT(n_corr_rgates_rejected)
         IF ( have_paramdsd ) THEN BEGIN
            tocdf_dpr_dm_rejected[jpr,ielev] = UINT(n_dpr_dm_gates_rejected)
            tocdf_dpr_nw_rejected[jpr,ielev] = UINT(n_dpr_nw_gates_rejected)
         ENDIF
         tocdf_dpr_expected[jpr,ielev] = UINT(dpr_gates_expected)
         tocdf_clutterStatus[jpr,ielev] = UINT(clutterStatus)

      ENDFOR  ; each DPR subarray point: jpr=0, numDPRrays-1

     ; END OF DPR-TO-GR RESAMPLING, THIS SWEEP

     ; =========================================================================

    ; *********** OPTIONAL PPI PLOTTING FOR SWEEP **********

      IF keyword_set(plot_PPIs) THEN BEGIN
         titlepr = 'DPR at ' + dpr_dtime + ' UTC'
         titlegv = siteID+', Elevation = '$
                   + STRING(tocdf_elev_angle[ielev],FORMAT='(f4.1)') $
                   +', '+ mysweeps[ielev].ATIMESWEEPSTART
         titles = [titlepr, titlegv]

         plot_elevation_gv_to_pr_z, tocdf_corr_dbz, tocdf_gr_dbz, sitelat, $
            sitelon, tocdf_x_poly, tocdf_y_poly, numDPRrays, ielev, TITLES=titles

       ; if restricting plot to the 'best' DPR and GR sample points
         ;plot_elevation_gv_to_pr_z, tocdf_corr_dbz*(tocdf_corr_z_rejected EQ 0), $
         ;   tocdf_gr_dbz*(tocdf_gr_dbz GE dpr_dbz_min)*(tocdf_gr_rejected EQ 0), $
         ;   sitelat, sitelon, tocdf_x_poly, tocdf_y_poly, numDPRrays, ielev, TITLES=titles

       ; to plot a full-res radar PPI for this elevation sweep:
         ;rsl_plotsweep_from_radar, radar, ELEVATION=elev_angle[ielev], $
         ;                          VOLUME_INDEX=z_vol_num, /NEW_WINDOW, MAXRANGE=200
         ;stop
      ENDIF

     ; =========================================================================

   ENDFOR     ; each elevation sweep: ielev = 0, num_elevations_out - 1

;  >>>>>>>>>>>>>>>>> END OF DPR-GR VOLUME MATCHING, ALL SWEEPS <<<<<<<<<<<<<<<<<<

;  OPTIONAL SCORE COMPUTATIONS, ALL SWEEPS COMBINED
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
