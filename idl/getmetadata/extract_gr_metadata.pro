
;===============================================================================

; MODULE 2:  compute_average_and_n

FUNCTION compute_average_and_n, values_in, n_non_zero

; DESCRIPTION
; -----------
; Compute average of array elements included in values_in array, and the number
; of non-zero values ("n_non_zero") contained in the average.  This function
; used to do more, which is why it still exists.

meanval = MEAN(values_in)
idx_gt_zero = WHERE( values_in GT 0.0, n_non_zero)

return, meanval
end

;===============================================================================

; MODULE 1:  extract_gr_metadata

function extract_gr_metadata, file_1CUF, siteID

   range_threshold_km=220  ; >= diagonal distance from grid center to corner

  ; set up returned structure with metadata values
   parmstruct = { parm770199 : 0, $
                  parm771105 : 0, $
                  parm770101 : 0, $
                  parm770102 : 0, $
                  parm770103 : 0, $
                  meanBBhgt : -99.99 }

  ; copy/unzip/open the UF file and read the entire volume scan into an
  ;   RSL_in_IDL radar structure, and then close UF file and delete copy:

   status=get_rsl_radar(file_1CUF, radar)
   IF ( status NE 0 )  THEN BEGIN
      PRINT, ""
      message, "Error reading radar structure from file ", file_1CUF
      PRINT, ""
   ENDIF

  ; find the volume with the correct reflectivity field for the GR site/source,
  ;   and the ID of the field itself
   gv_z_field = ''
   z_vol_num = get_site_specific_z_volume( siteID, radar, gv_z_field )
   IF ( z_vol_num LT 0 )  THEN BEGIN
      PRINT, ""
      PRINT, "Error finding volume in radar structure from file ", file_1CUF
      PRINT, ""
   ENDIF

  ; Retrieve the desired radar volume from the radar structure
   zvolume = rsl_get_volume( radar, z_vol_num )
   print, "Done reading radar file, starting mapping to grid."

  ; get the number of elevation sweeps in the vol, and the array of elev angles
   num_elevations = get_sweep_elevs( z_vol_num, radar, elev_angle )
  ; make a copy of the array of elevations, from which we eliminate any
  ;   duplicate tilt angles for subsequent data processing/output
;   idx_uniq_elevs = UNIQ(elev_angle)
   uniq_elev_angle = elev_angle
   idx_uniq_elevs = UNIQ_SWEEPS(elev_angle, uniq_elev_angle)

   tocdf_elev_angle = elev_angle[idx_uniq_elevs]
   num_elevations_out = N_ELEMENTS(tocdf_elev_angle)
   IF num_elevations NE num_elevations_out THEN BEGIN
      print, ""
      print, "Duplicate sweep elevations ignored!"
      print, "Original sweep elevations:"
      print, elev_angle
      print, "Unique sweep elevations to be processed/output"
      print, tocdf_elev_angle
   ENDIF

  ; precompute cos(elev) for later repeated use
   cos_elev_angle = COS( tocdf_elev_angle * !DTOR )

  ; restrict max range at each elevation to where beam center is 19.5 km or less
   max_ranges = FLTARR( num_elevations_out )
   FOR i = 0, num_elevations_out - 1 DO BEGIN
      rsl_get_slantr_and_h, range_threshold_km, tocdf_elev_angle[i], $
                            slant_range, max_ht_at_range
      IF ( max_ht_at_range LT 19.5 ) THEN BEGIN
         max_ranges[i] = range_threshold_km
      ENDIF ELSE BEGIN
         max_ranges[i] = get_range_km_at_beam_hgt_km(tocdf_elev_angle[i], 19.5)
      ENDELSE
   ENDFOR

  ; Get the times of the first ray in each sweep -- text_sweep_times will be
  ;   formatted as YYYY-MM-DD hh:mm:ss, e.g., '2008-07-09 00:10:56'
   num_times = get_sweep_times( z_vol_num, radar, dtimestruc )
   text_sweep_times = dtimestruc.textdtime  ; STRING array, human-readable
   ticks_sweep_times = dtimestruc.ticks     ; DOUBLE array, time in unix ticks
   IF num_elevations NE num_elevations_out THEN BEGIN
      ticks_sweep_times = ticks_sweep_times[idx_uniq_elevs]
      text_sweep_times =  text_sweep_times[idx_uniq_elevs]
   ENDIF

   ; Compute arrays of 2-D x- and y-grid coordinates
   dpr_master_idx = findgen(75,75)
   numDPRrays = N_ELEMENTS(dpr_master_idx)
   xdist = ((dpr_master_idx mod 75.) - 37.) * 4.
   ydist = TRANSPOSE(xdist)
   idxdist100 = WHERE( SQRT(xdist^2+ydist^2) LE 100. )
   dpr_master_idx = FIX(dpr_master_idx)

   ; set the default radius for match_2d
   radius=4.0

   ; define the 3-D grids for the grid-mapped GR Z and height data
   zgrid3d = FLTARR(num_elevations_out,75,75)
   maxzgrid3d = FLTARR(num_elevations_out,75,75)
   hgtgrid3d = FLTARR(num_elevations_out,75,75)
   topgrid3d = FLTARR(num_elevations_out,75,75)
   botmgrid3d = FLTARR(num_elevations_out,75,75)

   ; define the 2-D grids for each sweep's mappings
   GRinRadiusGrid2D = LONARR(75,75)
   GRmeanZGrid2D = FLTARR(75,75)
   GRmaxZGrid2D = FLTARR(75,75)
   GRmeanHgtGrid2D = FLTARR(75,75)
   GRmeanDepthGrid2D = FLTARR(75,75)
   GRcountNonZeroGrid2D = LONARR(75,75)

   maxGRinRadius = 0

   FOR ielev = 0, num_elevations_out - 1 DO BEGIN
      print, ""
      print, "Elevation: ", tocdf_elev_angle[ielev]
      GRinRadiusGrid2D[*,*] = 0L
      GRmeanZGrid2D[*,*] = 0.0
      GRmaxZGrid2D[*,*] = 0.0
      GRmeanHgtGrid2D[*,*] = 0.0
      GRmeanDepthGrid2D[*,*] = 0.0
      GRcountNonZeroGrid2D[*,*] = 0L

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

     ; read each GR ray into the b-scan column
      FOR iray = 0, nrays-1 DO BEGIN
         ray = sweep.ray[iray]
         bscan[*,iray] = ray.range[0:nbins-1]      ; drop the 'padding' bins
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
          (max_ranges[ielev]+4.0), bins2do2 )
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

     ; compute GR bin center x,y's for all bins/rays in-range and below 20km:
      xbin = FLTARR(maxGRbin, nrays)
      ybin = FLTARR(maxGRbin, nrays)
      FOR jray=0, nrays-1 DO BEGIN
         xbin[*,jray] = ground_range[0:maxGRbin-1] * sinrayazms[jray]
         ybin[*,jray] = ground_range[0:maxGRbin-1] * cosrayazms[jray]
      ENDFOR

     ; convert the 2D arrays to 1D vectors
      xbin=REFORM(xbin,N_ELEMENTS(xbin))
      ybin=REFORM(ybin,N_ELEMENTS(ybin))
      xdist=REFORM(xdist,N_ELEMENTS(xdist))
      ydist=REFORM(ydist,N_ELEMENTS(ydist))

     ; trim the bscan array down to maxGRbin bins to match xbin, etc.
      bscan2avg = bscan[0:maxGRbin-1,*]
     ; need this to reference back to height array
      gvidx2avg = gvidxall[0:maxGRbin-1,*]

     ; here is the code block for the fast spatial matchup - for each GR bin
     ; whose x and y are given by xbin, ybin, find the index of the nearest
     ; gridpoint (x,y)
      match_distance=1.0
      grid_cell_nearest_gr = match_2d( xbin, ybin, xdist, ydist, radius, $
                                 MATCH_DISTANCE=match_distance )
;      x1=0b & x2=0b & y1=0b & y2=0b  ; free arrays' memory
      print, ''
      print, "Max. GR-Grid distance (km): ", MAX( match_distance )
      print, ''
      match_distance = 0b  ; free array's memory


      ; check which GR bins have a grid cell linked to it
      GRbinIdxGridMapped = WHERE(grid_cell_nearest_gr GE 0, nGridmapped)
      IF nGridmapped EQ 0 THEN BEGIN
         message, "No Grid locations mapped to GR!"
      ENDIF ELSE BEGIN
         ; preset the negative values of Z to zero
         idxrainneg = WHERE(bscan2avg LT 0.0, nneg)
         IF nneg GT 0 THEN bscan2avg[idxrainneg] = 0.0
         idxrainneg = 0b    ; 'free' the memory

         ; pare list down to those with Grid_index values mapped to GR footprints
         Grid_idx_set = grid_cell_nearest_gr[GRbinIdxGridMapped]
         ; do a histogram of Grid_index within the defined values in Grid_idx_set
         Gridhist = HISTOGRAM(Grid_idx_set, LOCATIONS=Grididxvals, REVERSE_INDICES=R)
         ; get list of histo bins which have one or more GR indices mapped to them
         idxGridhistdef = WHERE(Gridhist GT 0, nGridmatchtrue)
         ; loop thru the mapped Grid_indexes, find those GR footprints mapped to each,
         ; and compute GR Z averages
         for iGrid = 0L, nGridmatchtrue-1 do begin
            ; get the Grid_index value itself
            this_Grid_idx = Grididxvals[idxGridhistdef[iGrid]]
            ; get GR array indices mapped to this Grid footprint via the
            ; reverse indices assigned to this bin/Grid index
            ibin1 = idxGridhistdef[iGrid]
            IF iGrid LT nGridmatchtrue-1 THEN ibin2 = idxGridhistdef[iGrid+1] $
            ELSE ibin2 = idxGridhistdef[iGrid] + 1
            ; get the indices of the Grid_idx_set elements mapped to this_Grid_idx
            RthisGrid = R[R[ibin1] : R[ibin2]-1]
            bscan_idx2avg = GRbinIdxGridMapped[ RthisGrid ]
            n_pr2avg = N_ELEMENTS(bscan_idx2avg)

            n_non_zero = 0                   ; number of non-zero GR values in average
            ; do the GR Z averages for footprints mapped to this Grid footprint
            GRinRadiusGrid2D[this_Grid_idx] = n_pr2avg
            ; do averages of GR Z and height, and non-zero count, by Grid footprint
            GRmeanZGrid2D[this_Grid_idx] = $
               compute_average_and_n( bscan2avg[bscan_idx2avg], n_non_zero )
            GRmaxZGrid2D[this_Grid_idx] = MAX( bscan2avg[bscan_idx2avg] )
            GRcountNonZeroGrid2D[this_Grid_idx] = n_non_zero
              ; using indices of all cropped bscan points mapped to this gridpoint,
              ; convert the array of full bscan 1-D indices into array of bin,ray coordinates
               binray = ARRAY_INDICES( bscan, gvidx2avg[bscan_idx2avg] )
              ; compute mean height of GR bins overlapping this DPR footprint
               binhgts = height[binray[0,*]]       ; depends only on bin # of bscan point
            GRmeanHgtGrid2D[this_Grid_idx] = $
               compute_average_and_n( binhgts, n_non_zero )
               binwidths = beam_diam[binray[0,*]]  ; depends only on bin # of bscan point
            GRmeanDepthGrid2D[this_Grid_idx] = $
               compute_average_and_n( binwidths, n_non_zero )
            IF n_pr2avg GT maxGRinRadius THEN maxGRinRadius = n_pr2avg
;           nperGridray[rayGrid[this_Grid_idx]] = $
;              nperGridray[rayGrid[this_Grid_idx]] + n_pr2avg
         endfor
      ENDELSE
      ; copy the 2D grid to the 3D grid layer for this elevation sweep
      zgrid3d[ielev,*,*] = GRmeanZGrid2D
      maxzgrid3d[ielev,*,*] = GRmaxZGrid2D
      hgtgrid3d[ielev,*,*] = GRmeanHgtGrid2D
      topgrid3d[ielev,*,*] = GRmeanHgtGrid2D + GRmeanDepthGrid2D/2.0
      botmgrid3d[ielev,*,*] = GRmeanHgtGrid2D - GRmeanDepthGrid2D/2.0
   ENDFOR
   print, "Done mapping sweeps to grid, start extracting 2km CAPPI and metadata."
   hgtdiff = ABS( hgtgrid3d - 2.0 )

  ; column by column, which sample is closest to the CAPPI height level?
   CAPPIdist = MIN( hgtdiff, idxcappi, DIMENSION=1 )
  ; extract the Z CAPPI grid
   gvzCAP = zgrid3d[idxcappi]
  ; compute the rain rate from Z-R relationship
   gvrrCAP = z_r_rainrate(gvzCAP)
  ; count the number of gridpoints with rain rate >= 0.1 mm/h
   idxrainy = WHERE( gvrrCAP GE 0.1, countrainy )
  ; derive a rough rain type at rainy points from the max Z profiles
   meanbb=0
   rntype=get_gridded_gr_rain_type(idxrainy, maxzgrid3d, topgrid3d, botmgrid3d, $
                                   MEANBB=meanBB, VERBOSE=1)

  ; metadata_parameter values to compute and assign here:
  ; ============================================================================
  ;    771105 | INTEGER   | GR 4km grid: Num Rain Certain inside 100km
  ;    770199 | INTEGER   | GR 4km grid: Num Gridpoints inside 100km
  ;    770101 | INTEGER   | GR 4km grid: Num Rain Type Stratiform inside 100km
  ;    770102 | INTEGER   | GR 4km grid: Num Rain Type Convective inside 100km
  ;    770103 | INTEGER   | GR 4km grid: Num Rain Type Other inside 100km
  ; ============================================================================

  ; put the computed rain type on a full grid
   rntypgrid=intarr(75,75)
   rntypgrid[idxrainy]=rntype

  ; get the counts of Total, Rainy, Rainy Convective, Rainy Stratiform,
  ; and Rainy Other Raintype gridpoints within 100 km, and assign to strucure
  ; elements

   parmstruct.parm770199 = N_ELEMENTS(idxdist100)
   idxRain = WHERE( gvrrCAP[idxdist100] GE 0.1, n )
   parmstruct.parm771105 = n
   idxStrat = WHERE( rntypgrid[idxdist100] EQ 1, n )
   parmstruct.parm770101 = n
   idxConv = WHERE( rntypgrid[idxdist100] EQ 2, n )
   parmstruct.parm770102 = n
   idxOther = WHERE( rntypgrid[idxdist100] EQ 3, n )
   parmstruct.parm770103 = n

  ; assign meanBB to structure element
   parmstruct.meanBBhgt = meanBB

   stop
   nextGRfile:

   return, parmstruct
end
