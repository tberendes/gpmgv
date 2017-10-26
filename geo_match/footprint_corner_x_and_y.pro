FUNCTION footprint_corner_x_and_y, scan, ray, xarr, yarr, nscans, nrays, $
                                    DO_PRINT = do_print

;+
; Copyright © 2008, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; DESCRIPTION:
; Given arrays of x and y center coordinates for a set of PR scans, and the
; scan and ray number to be evaluated, computes the x and y coordinates of
; the four corners of the PR footprint, in order of adjacency, such that the
; corner points represent an open polygon.  Do this by computing the midpoints
; of lines connecting the subject point's center to the center of its four
; diagonally-adjacent PR footprints in (scan,angle) space.  "Mirror" the
; edge and/or corner for where the subject point is on an edge or corner of
; the x or y arrays.
;
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-

IF N_ELEMENTS( do_print ) EQ 0 THEN do_print = 0  ; default to no print
IF ( scan LT 0 OR scan GE nscans ) THEN MESSAGE, "Illegal scan value specified."
IF ( ray LT 0 OR ray GE nrays ) THEN MESSAGE, "Illegal ray value specified."

xycorners = FLTARR(2,4)

; By default, start at preceding scan and ray, and increment ray first
; and scan second.  Only mirror dx and dy if/where needed.

; initialize the parameters defining 'normal' conditions (i.e., interior point)
extrap_scan = 0 & startscan = scan - 1 & endscan = scan + 1
extrap_ray = 0 & startray = ray - 1 & endray = ray + 1
rowsinhand = 3 & colsinhand = 3
subrowstart = 0 & subcolstart = 0

; figure out what edge(s) of the (ray,scan) arrays the point is along, and set
; the parameters
IF ( scan EQ 0 ) THEN BEGIN
   extrap_scan = 1
   startscan = scan
   endscan = scan+1
   subrowstart = 1
   subrow2fill = 0
ENDIF

IF ( scan EQ nscans-1 ) THEN BEGIN
   extrap_scan = 2
   startscan = scan - 1
   endscan = scan
;   subrowstart = 0
   subrow2fill = 2
ENDIF

IF ( ray EQ 0 ) THEN BEGIN
   extrap_ray = 10
   startray = ray
   endray = ray + 1
   subcolstart = 1
   subcol2fill = 0
ENDIF

IF ( ray EQ nrays-1 ) THEN BEGIN
   extrap_ray = 20
   startray = ray - 1
   endray = ray
;   subcolstart = 0
   subcol2fill = 2
ENDIF

subcase = extrap_scan + extrap_ray

IF ( do_print NE 0 ) THEN BEGIN
   print, "subcase: ", subcase
   print, "x points in hand:"
   print, xarr[startray:endray, startscan:endscan]
   print, "y points in hand:"
   print, yarr[startray:endray, startscan:endscan]
ENDIF

IF ( subcase EQ 0 ) THEN BEGIN          ; normal case, surrounding points all around
   pair = 0
   raydir = 1   ; flips direction to step, ray-wise, for polygon order
   FOR iscan = -1, 1, 2 DO BEGIN
      FOR iray = -1, 1, 2 DO BEGIN
         xcorner = (xarr[ray+raydir*iray,scan+iscan]+xarr[ray,scan])/2.0
         ycorner = (yarr[ray+raydir*iray,scan+iscan]+yarr[ray,scan])/2.0
         xycorners[*,pair] = [xcorner,ycorner]
         pair = pair + 1
      ENDFOR
   raydir = -raydir
   ENDFOR
ENDIF ELSE BEGIN
   ; define a 3x3 array around the point whose corners are being determined
   subxarr = FLTARR(3,3)
   subxarr[*,*] = 0.0
   subyarr = subxarr
   ; fill what we have
   subxarr[subcolstart,subrowstart] = xarr[startray:endray, startscan:endscan]
   subyarr[subcolstart,subrowstart] = yarr[startray:endray, startscan:endscan]

   IF ( do_print NE 0 ) THEN BEGIN
      print, "Pre-extrap. subxarr:"
      print, subxarr
      print, "Pre-extrap. subyarr:"
      print, subyarr
   ENDIF

   ; Extrapolate missing points in the 3x3 subarray

   IF ( extrap_scan NE 0 ) THEN BEGIN
      ; extrapolate from scans/rays we have, to subrow2fill
      rowsinhand = 2
      IF  ( extrap_ray NE 0 ) THEN colsinhand = 2
      ; extrapolate to subrow2fill, along columns with values
      FOR subcol = subcolstart, subcolstart + colsinhand - 1 DO BEGIN
         dxdrow = subxarr[subcol,subrowstart+1] - subxarr[subcol,subrowstart]
         dydrow = subyarr[subcol,subrowstart+1] - subyarr[subcol,subrowstart]
         CASE extrap_scan OF
           1: BEGIN
                subxarr[subcol,subrow2fill] = subxarr[subcol,subrowstart] - dxdrow
                subyarr[subcol,subrow2fill] = subyarr[subcol,subrowstart] - dydrow
           END
           2: BEGIN
                subxarr[subcol,subrow2fill] = subxarr[subcol,subrowstart+1] + dxdrow
                subyarr[subcol,subrow2fill] = subyarr[subcol,subrowstart+1] + dydrow
           END
         ENDCASE
      ENDFOR
   ENDIF

   IF ( extrap_ray NE 0 ) THEN BEGIN
      ; extrapolate from scans/rays we have, to subcol2fill
      colsinhand = 2
      IF  ( extrap_scan NE 0 ) THEN rowsinhand = 2
      ; extrapolate to subcol2fill, along rows with values
      FOR subrow = subrowstart, subrowstart + rowsinhand - 1 DO BEGIN
         dxdcol = subxarr[subcolstart+1,subrow] - subxarr[subcolstart,subrow]
         dydcol = subyarr[subcolstart+1,subrow] - subyarr[subcolstart,subrow]
         CASE extrap_ray OF
           10: BEGIN
                subxarr[subcol2fill,subrow] = subxarr[subcolstart,subrow] - dxdcol
                subyarr[subcol2fill,subrow] = subyarr[subcolstart,subrow] - dydcol
           END
           20: BEGIN
                subxarr[subcol2fill,subrow] = subxarr[subcolstart+1,subrow] + dxdcol
                subyarr[subcol2fill,subrow] = subyarr[subcolstart+1,subrow] + dydcol
           END
         ENDCASE
      ENDFOR
   ENDIF

   IF ( extrap_scan NE 0 AND extrap_ray NE 0 ) THEN BEGIN
      ; Deal with the subarr corner point not yet reassigned.  Extrapolate to
      ; it by going along the diagonal, using the original points we copied over
      ; to the subarrays.
      opp_col = 1 + (1-subcol2fill)
      opp_row = 1 + (1-subrow2fill)
      dx = subxarr[opp_col,opp_row] - subxarr[1,1]
      dy = subyarr[opp_col,opp_row] - subyarr[1,1]
      CASE subcase OF
        11:  BEGIN
               ; interpolate top-left
               subxarr[0,0] = subxarr[1,1] - dx
               subyarr[0,0] = subyarr[1,1] - dy
        END
        12:  BEGIN
               ; interpolate lower-left, subarr[0,2]
               subxarr[0,2] = subxarr[1,1] - dx
               subyarr[0,2] = subyarr[1,1] + dy
        END
        21:  BEGIN
               ; interpolate top-right, subarr[2,0]
               subxarr[2,0] = subxarr[1,1] + dx
               subyarr[2,0] = subyarr[1,1] - dy
        END
        22:  BEGIN
               ; interpolate lower-right, subarr[2,2]
               subxarr[2,2] = subxarr[1,1] - dx
               subyarr[2,2] = subyarr[1,1] - dy
        END
      ENDCASE
   ENDIF

   IF ( do_print NE 0 ) THEN BEGIN
      print, "Post-extrap. subxarr:"
      print, subxarr
      print, "Post-extrap. subyarr:"
      print, subyarr
   ENDIF

   pair = 0
   raydir = 1   ; flips direction to step, ray-wise, for polygon order
   FOR iscan = 0, 2, 2 DO BEGIN
      FOR iray = -1, 1, 2 DO BEGIN
         xcorner = (subxarr[1+raydir*iray,iscan]+subxarr[1,1])/2.0
         ycorner = (subyarr[1+raydir*iray,iscan]+subyarr[1,1])/2.0
         xycorners[*,pair] = [xcorner,ycorner]
         pair = pair + 1
      ENDFOR
   raydir = -raydir
   ENDFOR
ENDELSE

IF ( do_print NE 0 ) THEN BEGIN
   print, "xy corners:"
   print, xycorners
ENDIF

RETURN, xycorners
END
