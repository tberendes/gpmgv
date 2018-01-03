FUNCTION bin_corner_x_and_y, sinEdges, cosEdges, iray, ibin, cosElev, $
                             gndRanges, gateSpace, DO_PRINT = do_print

;+
; Copyright © 2008, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; DESCRIPTION:
; Given arrays of ray edge azimuth sin and cos and along-ground range, gate
; spacing, and cos(elevation) for a sweep, and the ray number and bin to be
; evaluated, computes the x and y coordinates of the surface projection of
; the four corners of the radar bin, in order of adjacency, such that the
; corner points represent an open polygon.
;
; HISTORY
; Nov. 2008    Morris/SAIC/GPM GV  - Modified bin ranges such that gndRanges
;                                    represents the center of the bin.
;
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-

IF N_ELEMENTS( do_print ) EQ 0 THEN do_print = 0  ; default to no print

xycorners = FLTARR(2,4)

; the assumption is that the gate ranges are at the center of the range bin
rwidth = gateSpace * cosElev
rbegin = gndRanges[ibin] - (0.5 * rwidth)
rend = rbegin + rwidth

xycorners[0,0] = rbegin * sinEdges[iray]    ;trailing edge x at bin near-end
xycorners[1,0] = rbegin * cosEdges[iray]    ;trailing edge y at bin near-end
xycorners[0,1] = rend * sinEdges[iray]      ;trailing edge x at bin far-end
xycorners[1,1] = rend * cosEdges[iray]      ;trailing edge y at bin far-end
xycorners[0,2] = rend * sinEdges[iray+1]    ;leading edge x at bin far-end
xycorners[1,2] = rend * cosEdges[iray+1]    ;leading edge y at bin far-end
xycorners[0,3] = rbegin * sinEdges[iray+1]  ;leading edge x at bin near-end
xycorners[1,3] = rbegin * cosEdges[iray+1]  ;leading edge y at bin near-end

IF ( do_print NE 0 ) THEN BEGIN
   print, "ray, bin = ", iray, ibin
   print, "gate_space * cosElev = ", gateSpace*cosElev
   print, "begin, end ranges = ", rbegin, rend
   print, "sin, cos of ray trailing edge angle = ", $
           sinEdges[iray], cosEdges[iray]
   print, "sin, cos of ray leading edge angle = ", $
           sinEdges[iray+1], cosEdges[iray+1]
   print, "xy corners:"
   print, xycorners
ENDIF

RETURN, xycorners
END
