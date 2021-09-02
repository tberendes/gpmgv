PRO get_scan_slope_and_sense, smap, prlats, prlons, scan_num, raysperscan, mscan, dysign, $
                              DO_PRINT = do_print

;=============================================================================
;+
; Copyright � 2008, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; get_scan_slope_and_sense.pro      Morris/SAIC/GPM_GV      August 2008
;
; DESCRIPTION
; -----------
; Compute slope and sign of dY/dAngle for a PR scan line projected onto
; a N-S aligned Cartesian coordinate system.  Assumes the center point
; of the scan is nadir-pointing.  NOTE:  slope is in (y,x) coordinate
; system, i.e., a line parallel to y-axis has slope of 0.0.
;
; HISTORY
; -------
; 8/14/07 - Morris/NASA/GSFC (SAIC), GPM GV:  Created.
;
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;=============================================================================

      IF N_ELEMENTS( do_print ) EQ 0 THEN do_print = 0  ; default to no print

;     Get X and Y at each endpoint of scan -- divide by 1000 for km

      XY_km = map_proj_forward( prlons[0,scan_num], prlats[0,scan_num], $
                                map_structure=smap ) / 1000.
      XX0 = XY_km[0] & YY0 = XY_km[1]

      XY_km = map_proj_forward( prlons[RAYSPERSCAN-1,scan_num], $
                                prlats[RAYSPERSCAN-1,scan_num], $
                                map_structure=smap ) / 1000.
      XXEND = XY_km[0] & YYEND = XY_km[1]

;     Compute the slope of the scan line in y,x space to avoid divide by zero
;     when XX0 eq XXEND (top or bottom of orbit).  Always have finite dY.
;     Thus, dx = mscan * dy
      mscan = ( XXEND - XX0 )/( YYEND - YY0 )
;     Need to know whether we are scanning in the +y or -y direction:
      dysign = ( YYEND - YY0 )/ABS( YYEND - YY0 ) ;+ if y increasing along sweep
      if (do_print eq 1 ) then begin
        print, "XX0, XX48, YY0, YY48, m, dysign, = ", $
               XX0, XXEND, YY0, YYEND, mscan, dysign
        print, "prlats = ",prlats
        print, "prlons = ",prlons
      endif
end
