;+
; Copyright © 2017, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-

PRO_DIR = getenv("IDL_PRO_DIR")
cd, PRO_DIR
print, "In IDL, PRO_DIR: ",PRO_DIR

control_file = GETENV("GETMYMETA")

outdir='/data/gpmgv/xfer/GMI_RR_Grids'
nearest_neighbor = 1
res_km = GETENV("RES_KM")
nxny = (150/res_km)*2 + 1
find_rain = FIX( GETENV("FIND_RAIN") )
help
;exit

.compile grid_2agprof_driver.pro
;restore, 'grid_2agprof_driver.sav'

grid_2agprof_driver, control_file, outdir, RES_KM=res_km, NXNY=nxny, $
                     NEAREST_NEIGHBOR=nearest_neighbor, FIND_RAIN=find_rain
