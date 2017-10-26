FUNCTION get_sweep_times, z_vol_num, radar, datetimes

;=============================================================================
;+
; Copyright © 2008, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; get_sweep_times.pro      Morris/SAIC/GPM_GV      September 2008
;
; DESCRIPTION
; -----------
; Retrieves the number of sweeps (elevation tilts) and their 1st ray's
; datetimes from a 'radar' structure of the TRMM Radar Software Library.
; Returns the number of sweeps as the function return value, and returns
; an array of datetime structures in the datetimes parameter.  The TEXTDTIME
; element of the structure is a string formatted as YYYY-MM-DD hh:mm:ss,
; e.g., '2008-07-09 00:10:56'
;
; HISTORY
; -------
; 9/12/08 - Morris/NASA/GSFC (SAIC), GPM GV:  Created.
;
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;=============================================================================

nelevs = radar.volume[z_vol_num].h.nsweeps
all_yr = radar.volume[z_vol_num].sweep.ray[0].h.year
all_mo = radar.volume[z_vol_num].sweep.ray[0].h.month
all_dy = radar.volume[z_vol_num].sweep.ray[0].h.day
all_hh = radar.volume[z_vol_num].sweep.ray[0].h.hour
all_mm = radar.volume[z_vol_num].sweep.ray[0].h.minute
all_ss = radar.volume[z_vol_num].sweep.ray[0].h.sec

datetime = { YEAR:1970, MONTH:1, DAY:1, $
             HOUR:0,   MINUTE:0, SEC:0, $
             FRAC:0.0,  TICKS:0.0D,     $
             TEXTDTIME:'1970-01-01 00:00:00' }

datetimes = replicate(datetime, nelevs)

FOR i=0,nelevs-1 DO BEGIN
   datetimes[i].YEAR = all_yr[i]
   datetimes[i].MONTH = all_mo[i]
   datetimes[i].DAY = all_dy[i]
   datetimes[i].HOUR = all_hh[i]
   datetimes[i].MINUTE = all_mm[i]
   datetimes[i].SEC = all_ss[i]
   datetimes[i].TICKS = unixtime( all_yr[i],all_mo[i],all_dy[i], $
                                  all_hh[i],all_mm[i],all_ss[i] )
   datetimes[i].TEXTDTIME = STRING( all_yr[i],all_mo[i],all_dy[i], $
                                    all_hh[i],all_mm[i],all_ss[i], $
           FORMAT = '(i0,"-",i02,"-",i02," ",i02,":",i02,":",i02)' )
ENDFOR

RETURN, nelevs
END
