;===============================================================================
;+
; Copyright © 2016, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; rhi_endpoints.pro
;
; DESCRIPTION
; -----------
; Computes locations of satellite radar footprints at the ends of radial lines
; extending from the ground radar location to the outer edge of the matchup data
; area. The endpoints are defined in terms of the product-relative array indices
; (pr_index values) based on the scan and ray numbers of these footprints at
; the end of the RHI radials.
;
; The pr_index of the footprints at each end of these lines are computed and
; returned in an array.
;
; HISTORY
; -------
; 03/04/16 Morris, GPM GV, SAIC
; - Created from existing logic cut out of dpr_and_geo_match_x_sections.pro.
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;===============================================================================

FUNCTION rhi_endpoints, xCorner, yCorner, mygeometa, pr_index_slice, $
                        RAYSPERSCAN, is_rhi_data, gr_is_inside

   ; compute locations of endpoints of RHI scans around the outer edge of the
   ; matchup data for use in walking through all radials
   ; - take the x- and y-corner points for the lowest sweep and average them
   ;   to get the center x,y of each footprint
   xfpctr = MEAN(REFORM(xCorner[*,*,0]), DIMENSION=1)
   yfpctr = MEAN(REFORM(yCorner[*,*,0]), DIMENSION=1)
   ; compute the footprint distances from the radar
   fpdist = SQRT(xfpctr*xfpctr + yfpctr*yfpctr)

   ; compute scan and ray numbers of footprints in dataset, and their
   ; max and min values
   raypr = pr_index_slice MOD RAYSPERSCAN   ; for GPM
   scanpr = pr_index_slice/RAYSPERSCAN      ; for GPM
   raymax = MAX(raypr, MIN=raymin)
   scanmax = MAX(scanpr, MIN=scanmin)

   IF is_rhi_data NE 0 THEN BEGIN
     ; grab the samples that are within 4 km of the max range of the data, these
     ; should delineate all points around the edge
      idxdataedges = WHERE(fpdist GT (mygeometa.rangeThreshold-2.0), countedges1)

      IF countedges1 GT 0 THEN BEGIN
        ; this is necessary but not sufficient, as there may be more RHI
        ; radials present where the DPR swath cuts off the matchup area
        ; at distances < (mygeometa.rangeThreshold-2.0)
         pr_index_edges1 = pr_index_slice[idxdataedges]
         have_indices=1
      ENDIF ELSE BEGIN
        ; if the GR site is inside the swath then the data could just all be
        ; cut off by the edge of the DPR scan, so look for those.  If not, then
        ; we aren't going to find any endpoints.
         IF gr_is_inside NE 0 THEN have_indices=0 $
         ELSE message, "Can't find scan edge in matchup area."
      ENDELSE

     ; May have no samples at the max range of the data, or be cut off at
     ; one end or the other of the DPR scan, or both.  Find any scan edge(s)
     ; and get the angles for each such footprint
      countedges2 = 0   ; define count
      IF raymin EQ 0 AND raymax EQ (RAYSPERSCAN-1) THEN BEGIN
         message, "Deal with this later.", /info
        ; for now, just take footprints touching either edge
         idxedges = WHERE( (raypr EQ 0 OR raypr EQ (RAYSPERSCAN-1)) AND $
                          fpdist LE (mygeometa.rangeThreshold-2.0), countedges2 )
      ENDIF ELSE BEGIN
         IF raymin EQ 0 THEN BEGIN
           ; walk along scans/rays with ray numbers = 0
            idxedges = WHERE(raypr EQ 0 AND $
                             fpdist LE (mygeometa.rangeThreshold-2.0), countedges2)
         ENDIF ELSE BEGIN
            IF raymax EQ (RAYSPERSCAN-1) THEN BEGIN
              ; walk along scans/rays with ray numbers = RAYSPERSCAN-1
               idxedges = WHERE(raypr EQ (RAYSPERSCAN-1) AND $
                                fpdist LE (mygeometa.rangeThreshold-2.0), countedges2)
            ENDIF ELSE BEGIN
               IF have_indices EQ 0 THEN $
                  message, "Can't find scan edge in matchup area."
            ENDELSE
         ENDELSE
      ENDELSE
      IF countedges2 GT 0 THEN BEGIN
         IF have_indices THEN BEGIN
           ; append scan edge indices to max range indices
            pr_index_edges2 = [pr_index_edges1,pr_index_slice[idxedges]]
            idxalledges = [idxdataedges,idxedges]
            countedges = countedges1 + countedges2
         ENDIF ELSE BEGIN
           ; we only have scan edge indices at lesser ranges
            pr_index_edges2 = pr_index_slice[idxedges]
            idxalledges = idxedges
            countedges = countedges2
         ENDELSE
      ENDIF ELSE BEGIN
        ; we only have range edge indices
         IF have_indices THEN BEGIN
            pr_index_edges2 = pr_index_edges1
            idxalledges = idxdataedges
            countedges = countedges1
         ENDIF ELSE message, "Can't find endpoints in matchup area."
      ENDELSE

   ENDIF ELSE BEGIN

     ; Non-RHI data. Decide what to do based on whether GR is inside or outside
     ; of DPR swath.  If inside swath, just walk through each DPR scan and find
     ; and tally the sample(s) with the highest and lowest ray numbers.  If
     ; outside the swath, find out which scan side (ray 0 or ray RAYSPERSCAN-1)
     ; is closer to the GR.  If ray 0 (RAYSPERSCAN-1) is closer, then scan by
     ; scan, take the sample point with the maximum (minimum) ray number.

      IF gr_is_inside NE 0 THEN BEGIN
        ; GR site is inside swath, find first and last ray for each scan
         tallycase = 'IN'
      ENDIF ELSE BEGIN
        ; GR site is NOT inside swath, find only first or last ray for each scan
        ; depending on which edge of the swath is closest to the GR
         idxtemp = WHERE(raypr EQ 0, countzero)
         idxtemp = WHERE(raypr EQ (RAYSPERSCAN-1), countmaxray)
         if (countzero GT countmaxray) then begin
           ; ray 0 must be the closest to the radar, find max ray number for
           ; each scan and tally its pr index
            tallycase = 'MAX'
         endif else begin
           ; ray RAYSPERSCAN-1 is closest to radar, find min ray number for
           ; each scan and tally its pr index
            tallycase = 'MIN'
         endelse
      ENDELSE

      nscans = scanmax-scanmin+1
      idxdataedges = LONARR(nscans*2)
      pr_index_edges1 = idxdataedges
      nedges = 0
      for iscan = scanmin, scanmax do begin
         idxthisscan = WHERE(scanpr EQ iscan, countscan)
         if countscan eq 1 then begin
           ; only have one ray on scan, tally its pr index regardless of
           ; inside/outside of swath
            pr_index_edges1[nedges] = iscan*RAYSPERSCAN + raypr[idxthisscan]
            idxdataedges[nedges] = idxthisscan
            nedges = nedges + 1
         endif else begin
           ; tally pr index of first, last, or both of these ray number
           ; positions for scan based on GR location
            maxray4scan = MAX(raypr[idxthisscan], idxmax, MIN=minray4scan, $
                              SUBSCRIPT_MIN=idxmin)
            CASE tallycase OF
               'IN' : BEGIN
                        pr_index_edges1[nedges] = iscan*RAYSPERSCAN + minray4scan
                        idxdataedges[nedges] = idxthisscan[idxmin]
                        nedges = nedges + 1
                        pr_index_edges1[nedges] = iscan*RAYSPERSCAN + maxray4scan
                        idxdataedges[nedges] = idxthisscan[idxmax]
                        nedges = nedges + 1
                      END
              'MAX' : BEGIN
                        pr_index_edges1[nedges] = iscan*RAYSPERSCAN + maxray4scan
                        idxdataedges[nedges] = idxthisscan[idxmax]
                        nedges = nedges + 1
                      END
              'MIN' : BEGIN
                        pr_index_edges1[nedges] = iscan*RAYSPERSCAN + minray4scan
                        idxdataedges[nedges] = idxthisscan[idxmin]
                        nedges = nedges + 1
                      END
               ELSE : message, "Confusion in non-RHI-data logic!"
            ENDCASE
         endelse 
      endfor
      pr_index_edges2 = pr_index_edges1[0:nedges-1]
      idxalledges = idxdataedges[0:nedges-1]
      countedges = nedges
   ENDELSE

   ; compute the azimuths of these samples
   azedges = (180./!pi*atan(xfpctr[idxalledges],yfpctr[idxalledges]) + 360.) MOD 360.
   ; see whether we wrap around 360 degrees
   if (MAX(azedges)-MIN(azedges)) GT 355. THEN wrapped = 1 ELSE wrapped = 0
   idxsort = SORT(azedges)
   ; get edge footprint indices in order of increasing azimuth
   IF wrapped THEN BEGIN
     ; find the angular "gap" that indicates whether we have a limited wedge of
     ; azimuths that wraps through 360 degrees, or whether we just have a full
     ; circle of radials
      azgaps = azedges[idxsort[1:(countedges-1)]] - azedges[idxsort[0:(countedges-2)]]
      IF MAX(azgaps, idxgap) LT 5.0 THEN BEGIN
        ; full circle of radials, just put the pr_index values in azimuth order
         pr_index_edges = pr_index_edges2[idxsort]
      ENDIF ELSE BEGIN
        ; determine whether we have one gap or many gaps (bicycle-spoke RHIs)
         idxgaps = WHERE(azgaps GE 5.0, ngaps)
         IF ngaps GT 1 THEN BEGIN
           ; many gaps -- just punt and put the pr_index values in azimuth order
            pr_index_edges = pr_index_edges2[idxsort]
         ENDIF ELSE BEGIN
           ; we have one gap in the angle sequence, find the angle midway between
           ; the upper and lower angles defining the gap
            midgapaz = (azedges[idxsort[idxgap+1]] - azedges[idxsort[idxgap]])/2.
           ; grab the radials clockwise from the gap, up through 360 degrees
            idxhiaz = WHERE(azedges[idxsort] GT midgapaz, nhi)
            IF nhi EQ 0 THEN message, "Error in sequencing RHI radials."
           ; grab the radials counter-clockwise from the gap, from 0 degrees upwards
            idxloaz = WHERE(azedges[idxsort] LT midgapaz, nlo)
            IF nlo EQ 0 THEN message, "Error in sequencing RHI radials."
           ; append the sorted low-azimuth radials to the end of
           ; the sorted hi-azimuth radials, e.g., 357,358,359 then 0,1,2
            idxseq = [idxsort[idxhiaz],idxsort[idxloaz]]
            pr_index_edges = pr_index_edges2[idxseq]
         ENDELSE
      ENDELSE
   ENDIF ELSE BEGIN
     ; just put the pr_index values in azimuth order
      pr_index_edges = pr_index_edges2[idxsort]
   ENDELSE

return, pr_index_edges
end
