;+
; Copyright © 2008, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
;  stratify_diffs21dist_geo.pro   Morris/SAIC/GPM_GV      September 2008
;
;  SYNOPSIS:
;  stratify_diffs21dist_geo, prdbz, gvdbz, raintype, BBcat, rangecat,
;                            stats_by_cat
;
;  DESCRIPTION:
;  Takes pre-filtered 1-D arrays of PR and GV reflectivity (dBZ), PR Rain Type,
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
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-

pro stratify_diffs21dist_geo, prdbz, gvdbz, raintype, BBcat, rangecat, $
                              stats_by_cat

numParams = N_Params()
if numParams ne 6 then message, 'Incorrect number of parameters given.'

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
   stratify_diffs_geo, prdbzO, gvdbzO, raintypeO, bbO, local_statsO
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
   stratify_diffs_geo, prdbzL, gvdbzL, raintypeL, bbL, local_statsL
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
   stratify_diffs_geo, prdbzC, gvdbzC, raintypeC, bbC, local_statsC
   stats_by_cat.km_gt_100 = local_statsC
endif

end

@stratify_diffs_geo.pro
