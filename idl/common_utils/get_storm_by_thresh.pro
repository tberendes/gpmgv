;===============================================================================
;+
; Copyright © 2015, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; get_storm_by_thresh.pro       Morris/SAIC/GPM_GV    April 2015
;
; DESCRIPTION
; -----------
; Identifies points in a "storm", defined as a contiguous area of Z or rain
; rate at and above a specified threshold.  Requires a data array to be used to
; identify the contiguous points, and matching arrays of (D)PR scan and ray
; number used to map these data array samples into a rectangular scan vs. ray
; data array that can be input to SEARCH2D.  The 1-D array index "idxstart"
; of an above-threshold begin point for the search must be provided.
;
; PARAMETERS
; ----------
; idxstart   - 1-D array index of the starting above-threshold sample around
;              which to search for contiguous above-threshold samples in "data"
; raynum     - The (D)PR ray number associated with each sample in "data"
; scannum    - As above, but scan number
; data       - The array of values to be searched for contiguous above-threshold
;              samples comprising a "storm cell"
; threshold  - The minimum "data" value to qualify a point as "in storm"
;
; HISTORY
; -------
; 04/09/15  Morris/GPM GV/SAIC
; - Created.
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;===============================================================================
;

FUNCTION get_storm_by_thresh, idxstart, raynum, scannum, data, threshold

; compute the 1-D indices for the input array points
idxInputs = LINDGEN(N_ELEMENTS(data))

; - we know for sure this scan/ray is an above-threshold sample
; find the scan number of the start point
thisScan = scannum[idxstart]
; find the ray sumber of the start point
thisRay = raynum[idxstart]

; PUT THE DATA INTO A RECTANGULAR ARRAY OF NORMALIZED RAY VS. SCAN

minScan = MIN(scannum, MAX=maxscan)
nscans = maxscan-minscan+1
minray = MIN(raynum, MAX=maxray)
nrays = maxray-minray+1
maxval = MAX(data)

; set up rectagular arrays to hold "idxInputs" and "data" values of the
; input arrays, rectangularly-mapped by their normalized ray and scan number
idxOfInput = LONARR(nscans,nrays)
idxOfInput[*,*] = -1L
values = FLTARR(nscans,nrays)

; walk through the input points and brute-force assign them to their locations
; in the rectangular arrays
for i = 0, N_ELEMENTS(data)-1 DO BEGIN
    scanidx=scannum[i]-minscan
    rayidx=raynum[i]-minray
    idxOfInput[scanidx, rayidx] = idxInputs[i]
    values[scanidx, rayidx] = data[i]
endfor

; find the location of the starting point relative to the rectangular array
xpos = scannum[idxstart]-minscan
ypos = raynum[idxstart]-minray

;if idxOfInput[xpos,ypos] NE idxstart THEN stop $
;else print, "idxOfInput[xpos,ypos], idxstart: ", idxOfInput[xpos,ypos], idxstart

; search the rectangular data array from the start point to find the contiguous
; area of above-threshold footprints.  Right now we don't allow a connection
; along a diagonal point-to-point of a single pixel (/DIAGONAL parameter unset)

storm2d = SEARCH2D(values, xpos, ypos, threshold, maxval)

return, idxOfInput[storm2d]
end
