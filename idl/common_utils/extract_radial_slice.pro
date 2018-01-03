;===============================================================================
;+
; Copyright © 2014, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; extract_radial_slice.pro    Morris/SAIC/GPM_GV    August 2014
;
; DESCRIPTION
; -----------
; Extracts a subset of geometry-match or full-resolution DPR data along a line
; defined by an array of array indices (for geometry-match data) or matching
; arrays of scan and ray number (DPR data).  The indices are assumed to be for
; DPR footprints along a radial line extending outward from the ground radar,
; but in practice they can be any random collection of DPR footprints, as long
; as the indices are valid for the "data" array.
;
; If only the "data" and "arr1_Radial" parameters are given, then "data" is
; assumed to be geometry-match data in a 1-D or 2-D array, where arr1_Radial
; holds the indices of data to be extracted along the footprint dimension of the
; data array.  If arr2_Radial is also provided as an argument, then "data" is
; assumed to be 2A-DPR, 2A-Ka, or 2A-Ku data in either a 2-D or 3-D array,
; where arr1_Radial specifies the ray numbers of the PR footprints to be
; extracted, and arr2_Radial specifies the scan numbers of these footprints.
; See the inline comments for detail of these rules.
;
; PARAMETERS
; ----------
; data         - 1-D or 2-D array of geometry-match data, or a 2-D or 3-D
;                array of DPR level 2A data to be subsetted along the radial.
;
; arr1_Radial  - Array of 1-D indices into the geometry match data, or an array
;                of ray number for ray dimension of DPR 2A data.
;
; arr2_Radial  - Array of scan number for scan dimension of DPR 2A data. 
;                If this parameter is not present, "data" is taken to be
;                geometry-match data.  If present, "data" is taken to be DPR
;                level 2A data in ray,scan coordinates.
;
; HISTORY
; -------
; 08/12/14  Morris, GPM GV, SAIC
; - Created.
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;===============================================================================

FUNCTION extract_radial_slice, data, arr1_Radial, arr2_Radial
   s = size( data )
   ndims = s[0]
   type = s[ndims+1]
   nfoot = N_ELEMENTS(arr1_Radial)
   ; if we have only 2 parameters, then we have geo-match data where a 1-D
   ; index into the arrays is contained in arr1_Radial.  If 3, then we have
   ; original DPR data in ray/scan coordinates, where arr1_Radial is scan
   ; number and arr2_Radial is ray number
   CASE N_PARAMS() OF
      2 : BEGIN
          ; we have a 2-D array (nfp,nelev) or a 1-D array (nfp).  Create
          ; an empty output array with nfoot elements in place of nfp
          IF ndims EQ 2 then nelev=s[ndims]
          CASE type OF
             1 : IF ndims EQ 1 THEN outarr=BYTARR(nfoot) ELSE outarr=BYTARR(nfoot,nelev)
             2 : IF ndims EQ 1 THEN outarr=INTARR(nfoot) ELSE outarr=INTARR(nfoot,nelev)
             3 : IF ndims EQ 1 THEN outarr=LONARR(nfoot) ELSE outarr=LONARR(nfoot,nelev)
             4 : IF ndims EQ 1 THEN outarr=FLTARR(nfoot) ELSE outarr=FLTARR(nfoot,nelev)
             5 : IF ndims EQ 1 THEN outarr=DBLARR(nfoot) ELSE outarr=DBLARR(nfoot,nelev)
             ELSE : message, "Do not have a case for variable type code: "+STRING(type)
          ENDCASE
          IF ndims EQ 2 THEN outarr = data[arr1_Radial,*] $
          ELSE outarr = data[arr1_Radial]
          END
      3 : BEGIN
          ; we have a 3-D array (nbins,nrays,nscans) or a 2-D array (nrays,nscans).
          ; Create an empty output array with (nfoot,2) elements in place of
          ; (nrays,nscans) and fill both "scans" with the sliced data
          IF ndims EQ 3 then nbins=s[1]
          CASE type OF
             1 : IF ndims EQ 2 THEN outarr=BYTARR(nfoot,2) ELSE outarr=BYTARR(nbins,nfoot,2)
             2 : IF ndims EQ 2 THEN outarr=INTARR(nfoot,2) ELSE outarr=INTARR(nbins,nfoot,2)
             3 : IF ndims EQ 2 THEN outarr=LONARR(nfoot,2) ELSE outarr=LONARR(nbins,nfoot,2)
             4 : IF ndims EQ 2 THEN outarr=FLTARR(nfoot,2) ELSE outarr=FLTARR(nbins,nfoot,2)
             5 : IF ndims EQ 2 THEN outarr=DBLARR(nfoot,2) ELSE outarr=DBLARR(nbins,nfoot,2)
             ELSE : message, "Do not have a case for variable type code: "+STRING(type)
          ENDCASE
          FOR i = 0, nfoot-1 DO BEGIN
             IF ndims EQ 2 THEN outarr[i,0] = data[arr1_Radial[i],arr2_Radial[i]] $
             ELSE outarr[*,i,0] = data[*,arr1_Radial[i],arr2_Radial[i]]
          ENDFOR
          END
   ENDCASE
   return, outarr
end
