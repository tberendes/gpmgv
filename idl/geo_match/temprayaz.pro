 status=get_rsl_radar('/data/gv_radar/finalQC_in/KAMX/1CUF/2008/0101/080101.19.MIAM.4.1850.uf.gz',radar)
 z_vol_num = get_site_specific_z_volume( 'KAMX', radar )
 num_elevations = get_sweep_elevs( z_vol_num, radar, elev_angle )
 zvolume = rsl_get_volume( radar, z_vol_num )

   FOR i = 0, num_elevations - 1 DO BEGIN
      sweep = rsl_get_sweep( zvolume, SWEEP_INDEX=i )
     ; read/get the number of rays in the sweep: nrays
      nrays = sweep.h.nrays

     ; build an nrays-sized 1-D array of ray azimuths (float degrees or rads), AND NRAYS+1
     ;   BETWEEN-RAY AZ'S, and matching arrays of precomputed sin(az) and cos(az)
      rayazms = rsl_get_azm_from_sweep( sweep )
      sinrayazms = SIN( rayazms*!PI/180. )
      cosrayazms = COS( rayazms*!PI/180. )
      rayedgeazms = FLTARR(nrays+1)
      azm_delta = ABS(sweep.h.beam_width) * 1.25  ; nominal difference between beam center azms
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

     ; Compute the leading edge of each ray as the mean center azimuth of it and the next ray:
      FOR iray = 1, nrays-1 DO BEGIN
         CASE 1 OF
             ABS(rayazms[iray-1]-rayazms[iray]) LT azm_delta  :  $
                rayedgeazms[iray] = ( rayazms[iray-1] + rayazms[iray] ) /2.
             rayazms[iray-1]-rayazms[iray] GT (360.0 - azm_delta)  :  BEGIN
                rayedgeazms[iray]=( rayazms[iray-1] + (rayazms[iray]+360.) ) /2.
                IF rayedgeazms[iray] GT 360. THEN rayedgeazms[iray] = rayedgeazms[iray] - 360.
             END
             rayazms[iray-1]-rayazms[iray] LT (azm_delta - 360.0)  :  BEGIN
                rayedgeazms[iray]=( (rayazms[iray-1]+360.) + rayazms[iray] ) / 2.
                IF rayedgeazms[iray] GT 360. THEN rayedgeazms[iray] = rayedgeazms[iray] - 360.
             END
         ELSE  :  BEGIN
                print, "Excessive beam gap for ray = ", iray
                rayedgeazms[iray] = rayazms[iray-1] + azsign * sweep.h.beam_width / 2.0
             END
         ENDCASE
      ENDFOR
     ; Compute the trailing edge azimuth of the first ray
      CASE 1 OF
          ABS(rayazms[nrays-1]-rayazms[0]) LT azm_delta  :  $
             rayedgeazms[0] = ( rayazms[nrays-1] + rayazms[0] ) /2.
          rayazms[nrays-1]-rayazms[0] GT (360.0 - azm_delta)  :  BEGIN
             rayedgeazms[0]=( rayazms[nrays-1] + (rayazms[0]+360.) ) /2.
             IF rayedgeazms[0] GT 360. THEN rayedgeazms[0] = rayedgeazms[0] - 360.
          END
          rayazms[nrays-1]-rayazms[0] LT (azm_delta - 360.0)  :  BEGIN
             rayedgeazms[0]=( (rayazms[nrays-1]+360.) + rayazms[0] ) / 2.
             IF rayedgeazms[0] GT 360. THEN rayedgeazms[0] = rayedgeazms[0] - 360.
          END
      ELSE  :  BEGIN
             print, "Excessive beam gap for ray = 0"
             rayedgeazms[0] = rayazms[0] - azsign * sweep.h.beam_width / 2.0
          END
      ENDCASE
     ; The leading edge azimuth of the last ray is the trailing edge of the first ray
      rayedgeazms[nrays] = rayedgeazms[0]

      sinrayedgeazms = SIN( rayedgeazms*!PI/180. )
      cosrayedgeazms = COS( rayedgeazms*!PI/180. )
   ENDFOR     ; each elevation sweep

nextGVfile:
END
