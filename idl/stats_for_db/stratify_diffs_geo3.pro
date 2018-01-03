;+
; Copyright © 2008, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
;  stratify_diffs_geo3.pro   Morris/SAIC/GPM_GV      October 2008
;
;  SYNOPSIS:
;  stratify_diffs_geo3, prdbz, gvdbz, raintype, bb, gvzmax, gvzstddev, stats_by_cat
;
;  DESCRIPTION:
;  Takes pre-filtered 1-D arrays of PR and GV reflectivity (dBZ), PR Rain Type,
;  point proximity with respect to  the Bright Band (if any), and a 'stats7ways'
;  structure to hold the computed statistics.  Computes mean and standard
;  deviation of the PR-GV differences, and the StdDev of PR and GV dBZ values,
;  for cases of all 6 permutations of rain type (convective and stratiform) and
;  gridpoint vertical location w.r.t. the Bright Band (above it, in it, or below
;  it), and in total for the level with no regard for rain type or Bright Band,
;  and fills the stats structure with these statistics.
;
; HISTORY
; -------
; 11/30/10  Morris/GPM GV/SAIC
; - Add processing of gvzmax and gvzstddev if Version 2 netcdf file.
;
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-

pro stratify_diffs_geo3, prdbz, gvdbz, raintype, bb, gvzmax, gvzstddev, stats_by_cat

numParams = N_Params()
if numParams ne 7 then message, 'Incorrect number of parameters given.'

; "include" file for PR data constants
@pr_params.inc

; stats for all points, regardless of raintype or proximity to bright band
stats_by_cat.stats_total.N = N_ELEMENTS(prdbz)
stats_by_cat.stats_total.AvgDif = MEAN(prdbz-gvdbz)
stats_by_cat.stats_total.PRstddevZ = STDDEV(prdbz)
stats_by_cat.stats_total.GVstddevZ = STDDEV(gvdbz)
stats_by_cat.stats_total.PRavgZ = MEAN(prdbz)
stats_by_cat.stats_total.GVavgZ = MEAN(gvdbz)
stats_by_cat.stats_total.StdDev = -99.999
if ( N_ELEMENTS(prdbz) gt 1 ) then $
   stats_by_cat.stats_total.StdDev = STDDEV(prdbz-gvdbz)
stats_by_cat.stats_total.GVabsmaxZ = MAX(gvzmax)
stats_by_cat.stats_total.GVmaxstddevZ = MAX(gvzstddev)

; Values in array of BB proximity: 0 if below, 1 if within, 2 if above

 idxconvbelow = where(raintype eq RainType_convective and bb eq 0, $
                      countconvbelow)
 stats_by_cat.stats_convbelow.N = countconvbelow
 stats_by_cat.stats_convbelow.StdDev = -99.999
 if (countconvbelow gt 0) then begin
    stats_by_cat.stats_convbelow.AvgDif = $
        MEAN( prdbz[idxconvbelow] - gvdbz[idxconvbelow] )
    stats_by_cat.stats_convbelow.PRavgZ = MEAN( prdbz[idxconvbelow] )
    stats_by_cat.stats_convbelow.GVavgZ = MEAN( gvdbz[idxconvbelow] )
    if (countconvbelow gt 1) then stats_by_cat.stats_convbelow.StdDev = $
        STDDEV( prdbz[idxconvbelow] - gvdbz[idxconvbelow] )
    stats_by_cat.stats_convbelow.PRstddevZ = STDDEV( prdbz[idxconvbelow] )
    stats_by_cat.stats_convbelow.GVstddevZ = STDDEV( gvdbz[idxconvbelow] )
    stats_by_cat.stats_convbelow.GVabsmaxZ = MAX(gvzmax[idxconvbelow])
    stats_by_cat.stats_convbelow.GVmaxstddevZ = MAX(gvzstddev[idxconvbelow])
 endif else begin
    stats_by_cat.stats_convbelow.AvgDif = -99.999
    stats_by_cat.stats_convbelow.PRavgZ = -99.999
    stats_by_cat.stats_convbelow.GVavgZ = -99.999
    stats_by_cat.stats_convbelow.PRstddevZ = -99.999
    stats_by_cat.stats_convbelow.GVstddevZ = -99.999
    stats_by_cat.stats_convbelow.GVabsmaxZ = -99.999
    stats_by_cat.stats_convbelow.GVmaxstddevZ = -99.999
 endelse

 idxconvin = where(raintype eq RainType_convective and $
                   bb eq 1, countconvin)
 stats_by_cat.stats_convin.N = countconvin
 stats_by_cat.stats_convin.StdDev = -99.999
 if (countconvin gt 0) then begin
    stats_by_cat.stats_convin.AvgDif = $
        MEAN( prdbz[idxconvin] - gvdbz[idxconvin] )
    stats_by_cat.stats_convin.PRavgZ = MEAN( prdbz[idxconvin] )
    stats_by_cat.stats_convin.GVavgZ = MEAN( gvdbz[idxconvin] )
    if (countconvin gt 1) then stats_by_cat.stats_convin.StdDev = $
        STDDEV( prdbz[idxconvin] - gvdbz[idxconvin] )
    stats_by_cat.stats_convin.PRstddevZ = STDDEV( prdbz[idxconvin] )
    stats_by_cat.stats_convin.GVstddevZ = STDDEV( gvdbz[idxconvin] )
    stats_by_cat.stats_convin.GVabsmaxZ = MAX(gvzmax[idxconvin])
    stats_by_cat.stats_convin.GVmaxstddevZ = MAX(gvzstddev[idxconvin])
 endif else begin
    stats_by_cat.stats_convin.AvgDif = -99.999
    stats_by_cat.stats_convin.PRavgZ = -99.999
    stats_by_cat.stats_convin.GVavgZ = -99.999
    stats_by_cat.stats_convin.PRstddevZ = -99.999
    stats_by_cat.stats_convin.GVstddevZ = -99.999
    stats_by_cat.stats_convin.GVabsmaxZ = -99.999
    stats_by_cat.stats_convin.GVmaxstddevZ = -99.999
 endelse

 idxconvabove = where(raintype eq RainType_convective $
                      and bb eq 2, countconvabove)
 stats_by_cat.stats_convabove.N = countconvabove
 stats_by_cat.stats_convabove.StdDev = -99.999
 if (countconvabove gt 0) then begin
    stats_by_cat.stats_convabove.AvgDif = $
        MEAN( prdbz[idxconvabove] - gvdbz[idxconvabove] )
    stats_by_cat.stats_convabove.PRavgZ = MEAN( prdbz[idxconvabove] )
    stats_by_cat.stats_convabove.GVavgZ = MEAN( gvdbz[idxconvabove] )
    if (countconvabove gt 1) then stats_by_cat.stats_convabove.StdDev = $
        STDDEV( prdbz[idxconvabove] - gvdbz[idxconvabove] )
    stats_by_cat.stats_convabove.PRstddevZ = STDDEV( prdbz[idxconvabove] )
    stats_by_cat.stats_convabove.GVstddevZ = STDDEV( gvdbz[idxconvabove] )
    stats_by_cat.stats_convabove.GVabsmaxZ = MAX(gvzmax[idxconvabove])
    stats_by_cat.stats_convabove.GVmaxstddevZ = MAX(gvzstddev[idxconvabove])
 endif else begin
    stats_by_cat.stats_convabove.AvgDif = -99.999
    stats_by_cat.stats_convabove.PRavgZ = -99.999
    stats_by_cat.stats_convabove.GVavgZ = -99.999
    stats_by_cat.stats_convabove.PRstddevZ = -99.999
    stats_by_cat.stats_convabove.GVstddevZ = -99.999
    stats_by_cat.stats_convabove.GVabsmaxZ = -99.999
    stats_by_cat.stats_convabove.GVmaxstddevZ = -99.999
 endelse

 idxstratbelow = where(raintype eq RainType_stratiform and bb eq 0, $
                       countstratbelow)
 stats_by_cat.stats_stratbelow.N = countstratbelow
 stats_by_cat.stats_stratbelow.StdDev = -99.999
 if (countstratbelow gt 0) then begin
    stats_by_cat.stats_stratbelow.AvgDif = $
        MEAN( prdbz[idxstratbelow] - gvdbz[idxstratbelow] )
    stats_by_cat.stats_stratbelow.PRavgZ = MEAN( prdbz[idxstratbelow] )
    stats_by_cat.stats_stratbelow.GVavgZ = MEAN( gvdbz[idxstratbelow] )
    if (countstratbelow gt 1) then stats_by_cat.stats_stratbelow.StdDev = $
        STDDEV( prdbz[idxstratbelow] - gvdbz[idxstratbelow] )
    stats_by_cat.stats_stratbelow.PRstddevZ = STDDEV( prdbz[idxstratbelow] )
    stats_by_cat.stats_stratbelow.GVstddevZ = STDDEV( gvdbz[idxstratbelow] )
    stats_by_cat.stats_stratbelow.GVabsmaxZ = MAX(gvzmax[idxstratbelow])
    stats_by_cat.stats_stratbelow.GVmaxstddevZ = MAX(gvzstddev[idxstratbelow])
 endif else begin
    stats_by_cat.stats_stratbelow.AvgDif = -99.999
    stats_by_cat.stats_stratbelow.PRavgZ = -99.999
    stats_by_cat.stats_stratbelow.GVavgZ = -99.999
    stats_by_cat.stats_stratbelow.PRstddevZ = -99.999
    stats_by_cat.stats_stratbelow.GVstddevZ = -99.999
    stats_by_cat.stats_stratbelow.GVabsmaxZ = -99.999
    stats_by_cat.stats_stratbelow.GVmaxstddevZ = -99.999
 endelse

 idxstratin = where(raintype eq RainType_stratiform $
                    and bb eq 1, countstratin)
 stats_by_cat.stats_stratin.N = countstratin
 stats_by_cat.stats_stratin.StdDev = -99.999
 if (countstratin gt 0) then begin
    stats_by_cat.stats_stratin.AvgDif = $
        MEAN( prdbz[idxstratin] - gvdbz[idxstratin] )
    stats_by_cat.stats_stratin.PRavgZ = MEAN( prdbz[idxstratin] )
    stats_by_cat.stats_stratin.GVavgZ = MEAN( gvdbz[idxstratin] )
    if (countstratin gt 1) then stats_by_cat.stats_stratin.StdDev = $
        STDDEV( prdbz[idxstratin] - gvdbz[idxstratin] )
    stats_by_cat.stats_stratin.PRstddevZ = STDDEV( prdbz[idxstratin] )
    stats_by_cat.stats_stratin.GVstddevZ = STDDEV( gvdbz[idxstratin] )
    stats_by_cat.stats_stratin.GVabsmaxZ = MAX(gvzmax[idxstratin])
    stats_by_cat.stats_stratin.GVmaxstddevZ = MAX(gvzstddev[idxstratin])
 endif else begin
    stats_by_cat.stats_stratin.AvgDif = -99.999
    stats_by_cat.stats_stratin.PRavgZ = -99.999
    stats_by_cat.stats_stratin.GVavgZ = -99.999
    stats_by_cat.stats_stratin.PRstddevZ = -99.999
    stats_by_cat.stats_stratin.GVstddevZ = -99.999
    stats_by_cat.stats_stratin.GVabsmaxZ = -99.999
    stats_by_cat.stats_stratin.GVmaxstddevZ = -99.999
 endelse

 idxstratabove = where(raintype eq RainType_stratiform $
                       and bb eq 2, countstratabove)
 stats_by_cat.stats_stratabove.N = countstratabove
 stats_by_cat.stats_stratabove.StdDev = -99.999
 if (countstratabove gt 0) then begin
    stats_by_cat.stats_stratabove.AvgDif = $
        MEAN( prdbz[idxstratabove] - gvdbz[idxstratabove] )
    stats_by_cat.stats_stratabove.PRavgZ = MEAN( prdbz[idxstratabove] )
    stats_by_cat.stats_stratabove.GVavgZ = MEAN( gvdbz[idxstratabove] )
    if (countstratabove gt 1) then stats_by_cat.stats_stratabove.StdDev = $
        STDDEV( prdbz[idxstratabove] - gvdbz[idxstratabove] )
    stats_by_cat.stats_stratabove.PRstddevZ = STDDEV( prdbz[idxstratabove] )
    stats_by_cat.stats_stratabove.GVstddevZ = STDDEV( gvdbz[idxstratabove] )
    stats_by_cat.stats_stratabove.GVabsmaxZ = MAX(gvzmax[idxstratabove])
    stats_by_cat.stats_stratabove.GVmaxstddevZ = MAX(gvzstddev[idxstratabove])
 endif else begin
    stats_by_cat.stats_stratabove.AvgDif = -99.999
    stats_by_cat.stats_stratabove.PRavgZ = -99.999
    stats_by_cat.stats_stratabove.GVavgZ = -99.999
    stats_by_cat.stats_stratabove.PRstddevZ = -99.999
    stats_by_cat.stats_stratabove.GVstddevZ = -99.999
    stats_by_cat.stats_stratabove.GVabsmaxZ = -99.999
    stats_by_cat.stats_stratabove.GVmaxstddevZ = -99.999
 endelse

end
