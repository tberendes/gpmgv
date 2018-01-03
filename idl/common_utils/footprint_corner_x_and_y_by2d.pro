;+
; Copyright © 2013, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; footprint_corner_x_and_y_by2d.pro       Morris/SAIC/GPM_GV     March 2013
;
; DESCRIPTION:
; Given properly extrapolated 2-D arrays of x and y center coordinates for a
; set of PR/TMI scans, computes the x and y coordinates of the four corners of
; the footprint, in order of adjacency, such that the corner points represent
; an open polygon.  Do this by computing the midpoints of lines connecting the
; subject point's center to the center of its four diagonally-adjacent
; footprints in (scan,angle) space.  The input x and y arrays must already have
; been extrapolated by one point all around by a call to extrap_x_y_arrays or
; have been directly extracted from a superset array, such that there is a one
; sample offset between the 'inner' points whose corners are calculated and
; their locations in the extracted/extrapolated arrays.  Caller must provide
; 3-D x- and y-arrays having dimensions (4,nscans,nrays) in which to return the
; results of the 4-corner calculations for the 'inner' points), where the
; extrapolated x- and y-arrays have dimensions (nscans+2,nrays+2).
;
; Resolves the situation where an orbit of data crosses the edge of the map
; such that there is a discontinuity in the x-location of the diagonally-
; adjacent footprints by setting a limit on the minimum or maximum corner
; x-value to the map minimum or maximum X value, depending on where the center
; of the footprint is located.  This edge-checking is skipped if map_min_x and
; map_max_x parameters are not given.
;
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-

PRO footprint_corner_x_and_y_by2d, xarr, yarr, xcorners, ycorners, $
                                   map_min_x, map_max_x, VERBOSE=verbose

do_print = KEYWORD_SET(do_print)  ; defaults to no print
verbose = KEYWORD_SET(verbose)
IF (N_PARAMS() NE 6) THEN EdgeCheck=0 ELSE EdgeCheck=1
IF (VERBOSE) THEN IF (EdgeCheck) THEN message, "Doing map edge checks.", /info $
                  ELSE message, "Skipping map edge checks.", /info

szx = SIZE(xarr)
if szx[0] NE 2 then message, 'xarr not 2-dimensional array.'
szy = SIZE(yarr)
if szy[0] NE 2 then message, 'yarr not 2-dimensional array.'
if szx[1] NE szy[1] OR szx[2] NE szy[2] then $
   message, 'xarr and yarr not same dimensions'
nscans_ext = szx[1]
nrays_ext = szx[2]

szx = SIZE(xcorners)
if szx[0] NE 3 then message, 'xcorners not 3-dimensional array.'
szy = SIZE(ycorners)
if szy[0] NE 3 then message, 'ycorners not 3-dimensional array.'
if szx[3] NE szy[3] OR szx[2] NE szy[2] then $
   message, 'xcorners and ycorners not same dimensions'
nscans = szx[2]
nrays = szx[3]
n_tmi_feet = nscans*nrays

IF ( nscans_ext NE (nscans+2) ) THEN MESSAGE, "Mismatched scan counts."
IF ( nrays_ext NE (nrays+2) ) THEN MESSAGE, "Mismatched ray counts."

  ; By default, start at preceding scan and ray, and increment ray first
   ; and scan second to walk around the 4 corners.
   corner = 0   ; 1st dimension of xcorners and ycorners
   raydir = 1   ; flips direction to step, ray-wise, for polygon order
   ; grab the values in the "inner" array one point in from the edges
   x_centers = xarr[1:nscans,1:nrays]
   y_centers = yarr[1:nscans,1:nrays]
   FOR iscan = -1, 1, 2 DO BEGIN
      FOR iray = -1, 1, 2 DO BEGIN
         ; take the midpoint between the 'centers' arrays and the array
         ; shifted one point diagonally from it
         xoff=xarr[1+iscan:nscans+iscan,1+raydir*iray:nrays+raydir*iray]
         yoff=yarr[1+iscan:nscans+iscan,1+raydir*iray:nrays+raydir*iray]
         ; compute the corner as the midpoint along the diagonal
         xdiag = ( xoff + x_centers )/2.0
         ydiag = ( yoff + y_centers )/2.0
         IF (EdgeCheck) THEN BEGIN
            ; find any x-points where we've gone across the map edge
            idx_wrapped = WHERE( ABS(xoff-x_centers) GT 100., nbad )
            if nbad gt 0 THEN BEGIN
            ; clip the corner depending on which map edge the center point
               ; is nearest to
               idx2fix = WHERE(x_centers[idx_wrapped] GT 0.0, n_east)
               if n_east GT 0 then xdiag[idx_wrapped[idx2fix]] = $
                (map_max_x+x_centers[idx_wrapped[idx2fix]])/2
               idx2fix = WHERE(x_centers[idx_wrapped] LT 0.0, n_west)
               if n_west GT 0 then xdiag[idx_wrapped[idx2fix]] = $
                   (map_min_x+x_centers[idx_wrapped[idx2fix]])/2
           endif
        ENDIF
        xCorners[corner, *, *] = xdiag
        yCorners[corner, *, *] = ydiag
        corner = corner + 1
      ENDFOR
      raydir = -raydir
   ENDFOR

END
