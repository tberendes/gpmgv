;===============================================================================
;+
; Copyright © 2008, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; test_scan_meta.pro           Morris/SAIC/GPM_GV      August 2008
;
; DESCRIPTION
; -----------
; Test driver for procedure get_scan_slope_and_sense
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;===============================================================================

pro test_get_scan_slope

sMap = MAP_PROJ_INIT('AzimuthalEquidistant', CENTER_LONGITUDE=-90.0, CENTER_LATITUDE=35.0)

prlats=[[36., 35., 34.], [36.1, 35.1, 34.1]]
prlons = [[-88., -89., -90.],[-88., -89., -90.]]
raysperscan=3
scan_num=1
mscan=-99.
dysign=-99.

get_scan_slope_and_sense, smap, prlats, prlons, scan_num, raysperscan, mscan, dysign, /DO_PRINT

end
