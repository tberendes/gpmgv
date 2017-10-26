;===============================================================================
;+
; Copyright © 2016, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; find_slant_path_intersections.pro    Bob Morris, GPM/GV/SAIC   September 2016
;
; DESCRIPTION
; -----------
; Takes arrays of precomputed radar echo top (ET) heights along vertical
; profiles, and the x and y corner boundaries and the x, y, and z center
; coordinates of an instrument (GMI) line of sight for views that intersect
; the surface at the lowest x and y corner points, and finds the highest echo
; top surface that the slant path intersects.  The algorithm outline is as
; follows:  For each slant path the algorithm identifies the nearby vertical
; profiles (within 35 km distance) and their ET heights, and interpolates the
; parallax-adjusted x and y of the line of sight at the ET height of each of the
; nearby profiles.  For each of these heights and the polygons defined by their
; x- and y-corners, the algorithm determines whether the adjusted slant-path
; (x,y) at that height lies within the polygon boundaries for that profile.  If
; more than one ET polygon is interected along the slant path, then the highest
; echo top is assigned to the slant path.  The ET polygon boundaries are taken
; as the slant-path corners at the lowest level in the corners arrays, where the
; corners arrays are of dimensions (ncorners, nprofiles, nlevels), and ncorners
; is fixed at 4 points.
;
; Returns an array of echo top heights for the slant-path columns of the same
; size as the input array of vertical-column echo top heights.  Also computes
; an optional set of array indices indicating the ET array position assigned to
; each slant path column (first array dimension).  That is, which VPR column
; position is mapped to each slant-path column, based on the slant path's
; intersection with VPR column's storm top.  This can be used to reposition the
; VPR column's GR rain rate to the GMI near-surface rain rate via a crude
; parallax offset estimate.
;
; HISTORY
; -------
; 09/2016 Morris, GPM GV, SAIC
; - Created.
;
;
; EMAIL QUESTIONS OR COMMENTS AT:
;       https://pmm.nasa.gov/contact
;-
;===============================================================================

FUNCTION find_slant_path_intersections, echotops, xcorners, ycorners, $
                                        xSlant, ySlant, topSlant, botmSlant, $
                                        VPR2SP_IDX=vpr2sp_idx

@pr_params.inc   ; INCLUDE file defining Z_BELOW_THRESH value

szs = SIZE(xSlant, /DIMENSIONS)
nfp = szs[0]
nlev = szs[1]

ETslant = REPLICATE( Z_BELOW_THRESH, nfp )
; initialize array of VPR column index mapped to each slantpath column index
vpr2sp_idx = REPLICATE( -1, nfp )

; compute the center x and y of the 3-D samples by averaging the 4 corners
ETx2d = MEAN( xcorners, DIMENSION=1 )
ETy2d = MEAN( ycorners, DIMENSION=1 )
; grab lowest level's values as the ET sample center points
ETx = REFORM(ETx2d[*,0])
ETy = REFORM(ETy2d[*,0])

; compute the center height of each slant-path sample
zSlant = (topSlant+botmSlant)/2.0

nETfound = 0
; walk through the slant-path columns one by one
for ifp = 0, nfp-1 do begin
  ; find vertical profiles within a threshold distance of the slant path
  ; -- take the middle sample along the slant path as its representative
  ;    (x,y) location for computing distance to nearby vertical profiles
   x0 = xSlant[ifp,(nlev/2)]
   y0 = ySlant[ifp,(nlev/2)]

  ; compute distance of all ET sample vertical columns from the representative
  ; slant path location
   dist = SQRT( (ETx-x0)^2 + (ETy-y0)^2 )

  ; find ET samples within 35 km of the mean slant path location AND having
  ; a defined echo top height
   idxETinRange = WHERE( dist LE 35.0 AND echotops GT 0.0, nInRange )

   thisETslant = 0.0    ; initialize maximum "found" ET intersected
   IF nInRange GT 0.0 THEN BEGIN
      ETs2check = echotops[idxETinRange]
      maxETinRange = MAX( ETs2check, MIN=minETinRange )
      idxZgood = WHERE( zSlant[ifp,*] GT 0.0, countZgood)
      IF countZgood GT 0 THEN BEGIN
         maxZinPath = MAX( zSlant[ifp,idxZgood], MIN=minZinPath )
      ENDIF ELSE BEGIN
;         print, "No good slant heights in profile, skipping."
         CONTINUE
      ENDELSE

     ; step through each of the ET heights and their polygons and see whether
     ; the parallax-adjusted slant path (x,y) falls within the polygon
      foundET = 0
      for jtop = 0, nInRange-1 do begin
        ; compute slant path (x,y) at ET height
         IF minZinPath LE ETs2check[jtop] $
         AND maxZinPath GE ETs2check[jtop] THEN BEGIN
           ; we can interpolate x and y between 2 existing slant path z levels
           ; -- find SP level immediately below ET
            idxunder = MAX( WHERE(zSlant[ifp,*] LE ETs2check[jtop]) )
           ; -- find SP level immediately above ET
            idxover = MIN( WHERE(zSlant[ifp,*] GE ETs2check[jtop]) )
            dz = zSlant[ifp,idxover] - zSlant[ifp,idxunder]
            fac = (ETs2check[jtop]-zSlant[ifp,idxunder]) / dz
           ; compute interpolated slant-path x and y at ET height
            xAtET=xSlant[ifp,idxunder]+(xSlant[ifp,idxover]-xSlant[ifp,idxunder])*fac
            yAtET=ySlant[ifp,idxunder]+(ySlant[ifp,idxover]-ySlant[ifp,idxunder])*fac
           ; check whether the interpolated point lies within the ET polygon
           ; defined by the lowest level of the corners arrays for this in-range
           ; footprint
           ; -- use D. Fanning's INSIDE function from Coyote Graphics library
            xpoly = REFORM(xcorners[*,idxETinRange[jtop],0])
            ypoly = REFORM(ycorners[*,idxETinRange[jtop],0])
            IF INSIDE(xAtET, yAtET, xpoly, ypoly) THEN BEGIN
              ; take the greater of the last intersected ET found and this ET
               IF ETs2check[jtop] GT thisETslant THEN BEGIN
                  thisETslant = ETs2check[jtop]
                  foundET = 1
;                  print, "Found ET of ",thisETslant," for footprint: ", ifp
                  idxfound = idxETinRange[jtop]
               ENDIF
            ENDIF
         ENDIF ;ELSE BEGIN
;            IF countZgood GT 1 THEN BEGIN
;               print, "Need to extrapolate beyond the range of slant path sample heights"
;            ENDIF ELSE print, "Cannot extrapolate slant path Z, only one point."
;            print, "maxETinRange, minETinRange, maxZinPath, minZinPath: ", $
;                    maxETinRange, minETinRange, maxZinPath, minZinPath
;         ENDELSE
      endfor
      IF foundET EQ 0 THEN BEGIN
;         print, "No ET intersection found for footprint: ", ifp
      ENDIF ELSE BEGIN
         ETslant[ifp] = thisETslant
         vpr2sp_idx[ifp] = idxfound   ; VPR column index mapped to the slantpath
         nETfound++
      ENDELSE
   ENDIF ELSE BEGIN
;      print, "No valid in-range ET samples for footprint: ", ifp
   ENDELSE
endfor

print, "Found ", STRING(nETfound, FORMAT='(I0)'), " echo tops for ", $
        STRING(nfp, FORMAT='(I0)'), " slant path profiles."
return, ETslant
end
