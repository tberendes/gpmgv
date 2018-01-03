;+
; Copyright © 2008, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
;  stratify_diffs_geo.pro   Morris/SAIC/GPM_GV      October 2008
;
;  SYNOPSIS:
;  stratify_diffs_geo, prdbz, gvdbz, raintype, bb, stats_by_cat
;
;  DESCRIPTION:
;  Takes pre-filtered 1-D arrays of PR and GV reflectivity (dBZ), PR Rain Type,
;  point proximity with respect to  the Bright Band (if any), and a 'stats7ways'
;  structure to hold the computed statistics.  Computes mean and standard
;  deviation of the PR-GV differences, and the maximum PR and GV dBZ values,
;  for cases of all 6 permutations of rain type (convective and stratiform) and
;  gridpoint vertical location w.r.t. the Bright Band (above it, in it, or below
;  it), and in total for the level with no regard for rain type or Bright Band,
;  and fills the stats structure with these statistics.
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-

pro stratify_diffs_geo, prdbz, gvdbz, raintype, bb, stats_by_cat

numParams = N_Params()
if numParams ne 5 then message, 'Incorrect number of parameters given.'

; "include" file for PR data constants
@pr_params.inc

; stats for all points, regardless of raintype or proximity to bright band
stats_by_cat.stats_total.N = N_ELEMENTS(prdbz)
stats_by_cat.stats_total.AvgDif = MEAN(prdbz-gvdbz)
stats_by_cat.stats_total.PRmaxZ = MAX(prdbz)
stats_by_cat.stats_total.GVmaxZ = MAX(gvdbz)
stats_by_cat.stats_total.PRavgZ = MEAN(prdbz)
stats_by_cat.stats_total.GVavgZ = MEAN(gvdbz)
stats_by_cat.stats_total.StdDev = -99.999
if ( N_ELEMENTS(prdbz) gt 1 ) then $
   stats_by_cat.stats_total.StdDev = STDDEV(prdbz-gvdbz)

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
    stats_by_cat.stats_convbelow.PRmaxZ = MAX( prdbz[idxconvbelow] )
    stats_by_cat.stats_convbelow.GVmaxZ = MAX( gvdbz[idxconvbelow] )
 endif else begin
    stats_by_cat.stats_convbelow.AvgDif = -99.999
    stats_by_cat.stats_convbelow.PRavgZ = -99.999
    stats_by_cat.stats_convbelow.GVavgZ = -99.999
    stats_by_cat.stats_convbelow.PRmaxZ = -99.999
    stats_by_cat.stats_convbelow.GVmaxZ = -99.999
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
    stats_by_cat.stats_convin.PRmaxZ = MAX( prdbz[idxconvin] )
    stats_by_cat.stats_convin.GVmaxZ = MAX( gvdbz[idxconvin] )
 endif else begin
    stats_by_cat.stats_convin.AvgDif = -99.999
    stats_by_cat.stats_convin.PRavgZ = -99.999
    stats_by_cat.stats_convin.GVavgZ = -99.999
    stats_by_cat.stats_convin.PRmaxZ = -99.999
    stats_by_cat.stats_convin.GVmaxZ = -99.999
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
    stats_by_cat.stats_convabove.PRmaxZ = MAX( prdbz[idxconvabove] )
    stats_by_cat.stats_convabove.GVmaxZ = MAX( gvdbz[idxconvabove] )
 endif else begin
    stats_by_cat.stats_convabove.AvgDif = -99.999
    stats_by_cat.stats_convabove.PRavgZ = -99.999
    stats_by_cat.stats_convabove.GVavgZ = -99.999
    stats_by_cat.stats_convabove.PRmaxZ = -99.999
    stats_by_cat.stats_convabove.GVmaxZ = -99.999
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
    stats_by_cat.stats_stratbelow.PRmaxZ = MAX( prdbz[idxstratbelow] )
    stats_by_cat.stats_stratbelow.GVmaxZ = MAX( gvdbz[idxstratbelow] )
 endif else begin
    stats_by_cat.stats_stratbelow.AvgDif = -99.999
    stats_by_cat.stats_stratbelow.PRavgZ = -99.999
    stats_by_cat.stats_stratbelow.GVavgZ = -99.999
    stats_by_cat.stats_stratbelow.PRmaxZ = -99.999
    stats_by_cat.stats_stratbelow.GVmaxZ = -99.999
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
    stats_by_cat.stats_stratin.PRmaxZ = MAX( prdbz[idxstratin] )
    stats_by_cat.stats_stratin.GVmaxZ = MAX( gvdbz[idxstratin] )
 endif else begin
    stats_by_cat.stats_stratin.AvgDif = -99.999
    stats_by_cat.stats_stratin.PRavgZ = -99.999
    stats_by_cat.stats_stratin.GVavgZ = -99.999
    stats_by_cat.stats_stratin.PRmaxZ = -99.999
    stats_by_cat.stats_stratin.GVmaxZ = -99.999
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
    stats_by_cat.stats_stratabove.PRmaxZ = MAX( prdbz[idxstratabove] )
    stats_by_cat.stats_stratabove.GVmaxZ = MAX( gvdbz[idxstratabove] )
 endif else begin
    stats_by_cat.stats_stratabove.AvgDif = -99.999
    stats_by_cat.stats_stratabove.PRavgZ = -99.999
    stats_by_cat.stats_stratabove.GVavgZ = -99.999
    stats_by_cat.stats_stratabove.PRmaxZ = -99.999
    stats_by_cat.stats_stratabove.GVmaxZ = -99.999
 endelse

end
