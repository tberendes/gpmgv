pro resample_250m_z, dbzvals, avg_250m_z, n_250m_z_reject, $
                     top, botm, cos_inc_angle, raynum, scannum, $
                     pr_index, binEllipsoid, dpr_dbz_min, $
                     N_250m_EXPECT=n_250m_expect

@dpr_params.inc

szGeo = SIZE(avg_250m_z, /DIMENSIONS)
num_elevations_out = szGeo[1]
numDPRrays = N_ELEMENTS(pr_index)

;  >>>>>>>>>>>>>> BEGINNING OF DPR-GR VOLUME MATCHING, ALL SWEEPS <<<<<<<<<<<<<<<

   FOR ielev = 0, num_elevations_out - 1 DO BEGIN
      print, ""
      FOR jpr=0, numDPRrays-1 DO BEGIN
        ; init output variables defined/set in loop/if
         writeMISSING = 1
         dpr_gates_expected = 0UL      ; # DPR gates within the sweep vert. bounds
         n_correctedReflectFactor_rejected = 0UL  ; # of above that are below DPR dBZ cutoff

         dpr_index = pr_index[jpr]

         IF ( dpr_index GE 0 ) THEN BEGIN
            raydpr = raynum[dpr_index]
            scandpr = scannum[dpr_index]
           ; determine if any 250-m gates in the column are non-missing
            idxgood=WHERE(dbzvals[*,raydpr,scandpr] GE dpr_dbz_min, ngood)
            IF ( ngood GT 0 ) THEN BEGIN
               meantopMSL = top[jpr,ielev]
               meanbotmMSL = botm[jpr,ielev]
               topGate = 0 & botmGate = 0
               topGate = dpr_gate_num_for_height(meantopMSL, BIN_SPACE_DPRGMI,  $
                             cos_inc_angle, raydpr, scandpr, binEllipsoid)
               botmGate = dpr_gate_num_for_height(meanbotmMSL, BIN_SPACE_DPRGMI, $
                              cos_inc_angle, raydpr, scandpr, binEllipsoid)
              ; number of DPR gates to be averaged in the vertical:
               dpr_gates_expected = botmGate - topGate + 1

              ; do layer averaging for 3-D DPR fields
               numDPRgates = 0
               avg_250m_z[jpr,ielev] = get_dpr_layer_average( topGate, botmGate, $
                                        scandpr, raydpr, dbzvals, $
                                        DBZSCALEMEAS, dpr_dbz_min,  numDPRgates, $
                                        numDPRgates )
               n_250m_z_reject[jpr,ielev] = dpr_gates_expected - numDPRgates
               IF N_ELEMENTS(n_250m_expect) NE 0 THEN $
                  n_250m_expect[jpr,ielev] = dpr_gates_expected
            ENDIF ELSE avg_250m_z[jpr,ielev] = Z_BELOW_THRESH
         ENDIF ELSE BEGIN
            IF dpr_index EQ -2 THEN avg_250m_z[jpr,ielev] = FLOAT_OFF_EDGE
         ENDELSE

      ENDFOR  ; each DPR subarray point: jpr=0, numDPRrays-1

     ; END OF DPR-TO-GR RESAMPLING, THIS SWEEP

   ENDFOR     ; each elevation sweep: ielev = 0, num_elevations_out - 1

;  >>>>>>>>>>>>>>>>> END OF DPR-GR VOLUME MATCHING, ALL SWEEPS <<<<<<<<<<<<<<<<<<

end
