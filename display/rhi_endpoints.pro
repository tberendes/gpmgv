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
; 04/28/16 Morris, GPM GV, SAIC
; - Fixed assignment of final countedges value.
; 05/03/16 Morris, GPM GV, SAIC
; - Added parameter gr_is_inside to support improved logic.
; - Widened the distance defining samples at the farthest range so that samples
;   were not missed, and added logic to filter out the extra samples that get
;   captured as a result.  Renamed some variables to differentiate methods of
;   finding radial endpoints.
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;===============================================================================

FUNCTION rhi_endpoints, xCorner, yCorner, mygeometa, pr_index_slice, $
                        RAYSPERSCAN, gr_is_inside

   ; compute locations of endpoints of RHI scans around the outer edge of the
   ; matchup data for use in walking through all radials
   ; - take the x- and y-corner points for the lowest sweep and average them
   ;   to get the center x,y of each footprint.  X and Y are km from the GR site
   xfpctr = MEAN(REFORM(xCorner[*,*,0]), DIMENSION=1)
   yfpctr = MEAN(REFORM(yCorner[*,*,0]), DIMENSION=1)

   ; compute the footprint distances from the ground radar
   fpdist = SQRT(xfpctr*xfpctr + yfpctr*yfpctr)

   ; grab the samples that are within 5 km of the max range of the data, this
   ; should delineate those points around the edge of coverage, and then some
   idxdataedges = WHERE(fpdist GT (mygeometa.rangeThreshold-5.0), countedges2)
   skipAzCheck = 0   ;flag whether to filter samples by azimuth increment at end

   IF countedges2 GT 0 THEN BEGIN
     ; this is necessary but not sufficient, as there may be more RHI
     ; radials present where the DPR swath cuts off the matchup area
     ; at distances < (mygeometa.rangeThreshold-5.0)
      pr_index_edges2 = pr_index_slice[idxdataedges]
      have_indices=1
   ENDIF ELSE BEGIN
     ; if the GR site is inside the swath then some or all the data could be
     ; cut off by the edge of the DPR scan, so set up to look for those.
     ; If not, then throw error, we aren't going to find any endpoints.
      IF gr_is_inside NE 0 THEN have_indices = 0 $
      ELSE message, "Can't find scan edge in matchup area."
   ENDELSE

   countedges = 0   ; set count of radials ending at edge of DPR scans

   IF gr_is_inside NE 0 THEN BEGIN
     ; May have no samples at the max range of the data, or be cut off at one
     ; end or the other of the DPR scan, or both. If GR site is within the
     ; DPR swath, then find any scan edge(s) and tally each such footprint

     ; -- analyze the pr_index, decomposed into DPR-product-relative
     ;    scan and ray number
      raypr = pr_index_slice MOD RAYSPERSCAN   ; for GPM
      ;scanpr = pr_index_slice/RAYSPERSCAN      ; for GPM

      raymax = MAX(raypr, MIN=raymin)
      IF raymin EQ 0 AND raymax EQ (RAYSPERSCAN-1) THEN BEGIN
         message, "Deal with this later.", /info
        ; for now, just take footprints touching either edge
         idxDPRedges = WHERE( (raypr EQ 0 OR raypr EQ (RAYSPERSCAN-1)) AND $
                              fpdist LE (mygeometa.rangeThreshold-5.0), $
                              countedges )
      ENDIF ELSE BEGIN
         IF raymin EQ 0 THEN BEGIN
           ; walk along scans/rays with ray numbers = 0
            idxDPRedges = WHERE( raypr EQ 0 AND $
                                 fpdist LE (mygeometa.rangeThreshold-5.0), $
                                 countedges )
         ENDIF ELSE BEGIN
            IF raymax EQ (RAYSPERSCAN-1) THEN BEGIN
              ; walk along scans/rays with ray numbers = RAYSPERSCAN-1
               idxDPRedges = WHERE( raypr EQ (RAYSPERSCAN-1) AND $
                                    fpdist LE (mygeometa.rangeThreshold-5.0), $
                                    countedges )
            ENDIF ELSE BEGIN
               IF have_indices EQ 0 THEN $
                  message, "Can't find scan edge in matchup area."
            ENDELSE
         ENDELSE
      ENDELSE
   ENDIF  ; gr_is_inside NE 0

   IF countedges GT 0 THEN BEGIN
      IF have_indices THEN BEGIN
        ; append scan edge indices to max range indices
         pr_index_edges1 = [pr_index_edges2,pr_index_slice[idxDPRedges]]
         idxalledges = [idxdataedges,idxDPRedges]
         countedges = countedges+countedges2
      ENDIF ELSE BEGIN
        ; we only have scan edge indices at lesser ranges
         pr_index_edges1 = pr_index_slice[idxDPRedges]
         idxalledges = idxDPRedges
         skipAzCheck = 1
      ENDELSE
   ENDIF ELSE BEGIN
     ; we only have range edge indices
      IF have_indices THEN BEGIN
         pr_index_edges1 = pr_index_edges2
         idxalledges = idxdataedges
         countedges = countedges2
      ENDIF ELSE message, "Can't find endpoints in matchup area."
   ENDELSE

   ; compute the azimuths and deltaAzimuths of these samples
   azedges = (180./!pi*atan(xfpctr[idxalledges],yfpctr[idxalledges]) + 360.) MOD 360.
   idxsort = SORT(azedges)
   azgaps = azedges[idxsort[1:(countedges-1)]] - azedges[idxsort[0:(countedges-2)]]
   maxgap = MAX(azgaps, idxgapmax, MIN=mingap, subscript_min=idxgapmin)

   ; see whether we wrap around 360 degrees
   if (MAX(azedges)-MIN(azedges)) GT 355. THEN wrapped = 1 ELSE wrapped = 0

   ; get edge footprint indices in order of increasing azimuth
   IF wrapped THEN BEGIN
     ; find the angular "gap" that indicates whether we have a limited wedge of
     ; azimuths that wraps through 360 degrees, or whether we just have a full
     ; circle of radials
      IF maxgap LT 5.0 THEN BEGIN
        ; full circle of radials, just put the pr_index values in azimuth order
         pr_index_edges = pr_index_edges1[idxsort]
      ENDIF ELSE BEGIN
        ; determine whether we have one gap or many gaps (bicycle-spoke RHIs)
         idxgaps = WHERE(azgaps GE 5.0, ngaps)
         IF ngaps GT 1 THEN BEGIN
           ; many gaps -- just punt and put the pr_index values in azimuth order
            pr_index_edges = pr_index_edges1[idxsort]
         ENDIF ELSE BEGIN
           ; we have one gap in the angle sequence, find the angle midway between
           ; the upper and lower angles defining the biggest gap
            midgapaz = azedges[idxsort[idxgapmax]] + maxgap/2.
           ; grab the radials clockwise from the gap, up through 360 degrees
            idxhiaz = WHERE(azedges[idxsort] GT midgapaz, nhi)
            IF nhi EQ 0 THEN message, "Error in sequencing RHI radials."
           ; grab the radials counter-clockwise from the gap, from 0 degrees upwards
            idxloaz = WHERE(azedges[idxsort] LT midgapaz, nlo)
            IF nlo EQ 0 THEN message, "Error in sequencing RHI radials."
           ; append the sorted low-azimuth radials to the end of
           ; the sorted hi-azimuth radials, e.g., 357,358,359 then 0,1,2
            idxseq = [idxsort[idxhiaz],idxsort[idxloaz]]
            pr_index_edges = pr_index_edges1[idxseq]
            idxsort = idxseq
         ENDELSE
      ENDELSE
   ENDIF ELSE BEGIN
     ; just put the pr_index values in azimuth order
      pr_index_edges = pr_index_edges1[idxsort]
   ENDELSE

  ; due to the variation in footprint ranges at the edge of the matchup area, we
  ; have to pick up some footprints that are inside the edge of coverage just to
  ; make sure we get all the edge points.  Walk through the samples and filter
  ; these "in between" footprints out based on their range and azimuth relative
  ; to the adjacent footprints' range and azimuth.  THIS STILL ISN'T PERFECT, IT
  ; SHOULD ONLY BE APPLIED TO THE RANGE-EDGE FOOTPRINTS, NOT THOSE ON THE DPR
  ; SCAN EDGE WHEN THERE IS A MIX.

   IF skipAzCheck EQ 1 THEN GOTO, skipIt  ; only scan edge samples present
   IF mingap GT 9.75 OR maxgap LT 0.25 THEN GOTO, skipIt  ; can't do HISTOGRAM

   azedges = azedges[idxsort]
   rngedges = fpdist[idxalledges]
   pr_index_edges1 = LONARR(countedges)
;   AzSet = FLTARR(countedges)
;   RngSet = AzSet
   nEdgeOK = 0
   lastAz = azedges[0]
   lastRng = rngedges[0]
  ; run a histogram of azimuths to identify the "typical" step to expect
   histAzGaps = HISTOGRAM(azgaps, BINS=0.25, MIN=0.25, MAX=9.75, LOCATIONS=azzes)
   histAzGapsMax = MAX(histAzGaps, azTypIdx)
   azTypGapMax = azzes[azTypIdx] * 0.6

  ; always grab the first footprint/lowest clockwise azimuth
   pr_index_edges1[nEdgeOK] = pr_index_edges[0]
;   AzSet[nEdgeOK] = azedges[0]
;   RngSet[nEdgeOK] = rngedges[0]
   nEdgeOK++
   
   for igap = 1, countedges-2 do begin
      IF (azedges[igap]-lastAz) GE azTypGapMax THEN BEGIN
        ; grab the current sample
         pr_index_edges1[nEdgeOK] = pr_index_edges[igap]
;         AzSet[nEdgeOK] = azedges[igap]
;         RngSet[nEdgeOK] = rngedges[igap]
         nEdgeOK++
         lastAz = azedges[igap]
         lastRng = rngedges[igap]
      ENDIF ELSE BEGIN
         IF rngedges[igap] GT lastRng THEN BEGIN
           ; if the difference between this azimuth and the prior one is less
           ; than the test value and this footprint is at greater range, then
           ; substitute this footprint's data for the prior one's tallied data
           ; (if prior one exists, i.e., if not the first time we are tallying
           ; a point, otherwise tally as the first point)
            IF (azedges[igap]-azedges[igap-1]) LT azTypGapMax THEN BEGIN
               pr_index_edges1[ (nEdgeOK-1) > 0 ] = pr_index_edges[igap]
;               AzSet[ (nEdgeOK-1) > 0 ] = azedges[igap]
;               RngSet[ (nEdgeOK-1) > 0 ] = rngedges[igap]
               nEdgeOK = nEdgeOK > 1
               lastAz = azedges[igap]
               lastRng = rngedges[igap]
            ENDIF
         ENDIF
      ENDELSE
   endfor

  ; always grab the last footprint/highest clockwise azimuth
   pr_index_edges1[nEdgeOK] = pr_index_edges[countedges-1]
;   AzSet[nEdgeOK] = azedges[countedges-1]
;   RngSet[nEdgeOK] = rngedges[countedges-1]

  ; trim to azimuth-step-filtered set of footprints
   pr_index_edges = pr_index_edges1[0:nEdgeOK]

;PRINT, AZSET[0:nEdgeOK]
;PRINT, RNGSET[0:nEdgeOK]

skipIt:
return, pr_index_edges
end
