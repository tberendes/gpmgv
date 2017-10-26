;===============================================================================
;+
; Copyright © 2013, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; extrap_x_y_arrays.pro          Morris/SAIC/GPM_GV      March 2013
;
; DESCRIPTION
; -----------
; Given 2-D rectangular arrays of x- and y-coordinate values, defines new arrays
; with one more element all the way around the outside edges of the input arrays
; and lienarly extrapolates the interior values outward to the new array edges.
; Only considers the two points along the edges of the old arrays for the linear
; extrapolation.
;
; PARAMETERS
; ----------
; xarr          - Input 2-D array of actual x-coordinates.
; yarr          - Input 2-D array of actual y-coordinates.
; xarr_extrap   - Output 2-D array of actual and extrapolated x-coordinate
;                 values with 2 more rows/columns than xarr.
; yarr_extrap   - Output 2-D array of actual and extrapolated y-coordinate
;                 values with 2 more rows/columns than yarr.
;
; HISTORY
; -------
; 3/2013 by Bob Morris, GPM GV (SAIC)
;  - Created.
;
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;===============================================================================


PRO extrap_x_y_arrays, xarr, yarr, xarr_extrap, yarr_extrap

szx = SIZE(xarr)
if szx[0] NE 2 then message, 'xarr not 2-dimensional array.'
szy = SIZE(yarr)
if szy[0] NE 2 then message, 'yarr not 2-dimensional array.'
if szx[1] NE szy[1] OR szx[2] NE szy[2] then $
   message, 'xarr and yarr not same dimensions'
; define a new grid with a single new point all around its borders
xarr_extrap = FLTARR(szx[1]+2,szx[2]+2)
yarr_extrap = xarr_extrap
; insert the old grid into the center of the new grid
xarr_extrap[1,1] = xarr
yarr_extrap[1,1] = yarr

; linearly extrapolate xarr to the borders, minus the corner points
xarr_extrap[1:szx[1],0] = 2*xarr[*,0] - xarr[*,1]
xarr_extrap[1:szx[1],szx[2]+1] = 2*xarr[*,szx[2]-1] - xarr[*,szx[2]-2]
xarr_extrap[0,1:szx[2]] = 2*xarr[0,*] - xarr[1,*]
xarr_extrap[szx[1]+1,1:szx[2]] = 2*xarr[szx[1]-1,*] - xarr[szx[1]-2,*]
; linearly extrapolate xarr to the 4 corners
xarr_extrap[0,0] = 2*xarr_extrap[0,1] - xarr_extrap[0,2]
xarr_extrap[0,szx[2]+1] = 2*xarr_extrap[0,szx[2]] - xarr_extrap[0,szx[2]-1]
xarr_extrap[szx[1]+1,0] = 2*xarr_extrap[szx[1],0] - xarr_extrap[szx[1]-1,0]
xarr_extrap[szx[1]+1,szx[2]+1] = 2*xarr_extrap[szx[1],szx[2]+1] $
                                 - xarr_extrap[szx[1]-1,szx[2]+1]

; linearly extrapolate yarr to the borders, minus the corner points
yarr_extrap[1:szx[1],0] = 2*yarr[*,0] - yarr[*,1]
yarr_extrap[1:szx[1],szx[2]+1] = 2*yarr[*,szx[2]-1] - yarr[*,szx[2]-2]
yarr_extrap[0,1:szx[2]] = 2*yarr[0,*] - yarr[1,*]
yarr_extrap[szx[1]+1,1:szx[2]] = 2*yarr[szx[1]-1,*] - yarr[szx[1]-2,*]
; linearly extrapolate yarr to the 4 corners
yarr_extrap[0,0] = 2*yarr_extrap[0,1] - yarr_extrap[0,2]
yarr_extrap[0,szx[2]+1] = 2*yarr_extrap[0,szx[2]] - yarr_extrap[0,szx[2]-1]
yarr_extrap[szx[1]+1,0] = 2*yarr_extrap[szx[1],0] - yarr_extrap[szx[1]-1,0]
yarr_extrap[szx[1]+1,szx[2]+1] = 2*yarr_extrap[szx[1],szx[2]+1] $
                                 - yarr_extrap[szx[1]-1,szx[2]+1]

end
