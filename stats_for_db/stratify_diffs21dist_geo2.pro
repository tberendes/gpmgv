;+
; Copyright © 2008, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
;  stratify_diffs21dist_geo2.pro   Morris/SAIC/GPM_GV      September 2008
;
;  SYNOPSIS:
;  stratify_diffs21dist_geo2, prdbz, gvdbz, raintype, BBcat, rangecat,
;                             gvzmaxlev, gvzstddevlev, stats_by_cat
;
;  DESCRIPTION:
;  Takes pre-filtered 1-D arrays of PR and GV reflectivity (dBZ), PR Rain Type,
;  GR Maximum Z per sample, GR Standard Deviation of Z per sample,
;  point proximity with respect to the Bright Band, the matching array
;  of range category (near, middle, far), and a 'stats21ways' structure
;  to hold the computed statistics.  Computes mean and standard deviation
;  of the PR-GV reflectivity differences, and the maximum PR and GV dBZ values,
;  for cases of all 6 permutations of rain type (convective and stratiform) and
;  gridpoint vertical location w.r.t. the Bright Band (above it, in it, or below
;  it), and in total for the level with no regard for rain type or Bright Band,
;  separately for each distance category, and fills the stats21ways structure
;  with these statistics.  Calls stratify_diffs_geo to do the split-outs
;  by site, raintype, BB location, etc., and the statistics computations.
;
; HISTORY
; -------
; 11/30/10  Morris/GPM GV/SAIC
; - Add processing of gvzmax and gvzstddev if Version 2 netcdf file.
; 9/15/2014  Morris/GPM GV/SAIC
; - Added DO_STDDEV parameter to compute StdDev of PR and GR Z instead of max.
;
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-

pro stratify_diffs21dist_geo2, prdbz, gvdbz, raintype, BBcat, rangecat, $
                               gvzmax, gvzstddev, stats_by_cat, $
                               DO_STDDEV=do_stddev

numParams = N_Params()
if numParams ne 8 then message, 'Incorrect number of parameters given.'

; "include" file for PR data constants
;@pr_params.inc

nearidx = where (rangecat EQ 0, countnear)
stats_by_cat.pts_le_50 = countnear
local_statsO = {stats7ways}       ; need a local copy, can't pass struct element
if (countnear GT 0) then begin
   prdbzO = prdbz[nearidx]
   gvdbzO = gvdbz[nearidx]
   raintypeO = raintype[nearidx]
   bbO = BBcat[nearidx]
   gvzmaxO = gvzmax[nearidx]
   gvzstddevO = gvzstddev[nearidx]
   IF KEYWORD_SET(do_stddev) $
      THEN stratify_diffs_geo3, prdbzO, gvdbzO, raintypeO, bbO, gvzmaxO, $
                                gvzstddevO, local_statsO $
      ELSE stratify_diffs_geo2, prdbzO, gvdbzO, raintypeO, bbO, gvzmaxO, $
                                gvzstddevO, local_statsO
   stats_by_cat.km_le_50 = local_statsO
endif

midrngidx = where (rangecat EQ 1, countmidrng)
stats_by_cat.pts_50_100 = countmidrng
local_statsL = {stats7ways}
if (countmidrng GT 0) then begin
   prdbzL = prdbz[midrngidx]
   gvdbzL = gvdbz[midrngidx]
   raintypeL = raintype[midrngidx]
   bbL = BBcat[midrngidx]
   gvzmaxL = gvzmax[midrngidx]
   gvzstddevL = gvzstddev[midrngidx]
   IF KEYWORD_SET(do_stddev) $
      THEN stratify_diffs_geo3, prdbzL, gvdbzL, raintypeL, bbL, gvzmaxL, $
                                gvzstddevL, local_statsL $
      ELSE stratify_diffs_geo2, prdbzL, gvdbzL, raintypeL, bbL, gvzmaxL, $
                                gvzstddevL, local_statsL
   stats_by_cat.km_50_100 = local_statsL
endif

faridx = where (rangecat EQ 2, countfar)
stats_by_cat.pts_gt_100 = countfar
local_statsC = {stats7ways}
if (countfar GT 0) then begin
   prdbzC = prdbz[faridx]
   gvdbzC = gvdbz[faridx]
   raintypeC = raintype[faridx]
   bbC = BBcat[faridx]
   gvzmaxC = gvzmax[faridx]
   gvzstddevC = gvzstddev[faridx]
   IF KEYWORD_SET(do_stddev) $
      THEN stratify_diffs_geo3, prdbzC, gvdbzC, raintypeC, bbC, gvzmaxC, $
                                gvzstddevC, local_statsC $
      ELSE stratify_diffs_geo2, prdbzC, gvdbzC, raintypeC, bbC, gvzmaxC, $
                                gvzstddevC, local_statsC 
   stats_by_cat.km_gt_100 = local_statsC
endif

end
