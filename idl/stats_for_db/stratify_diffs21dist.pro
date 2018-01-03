;+
; Copyright © 2008, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
;  stratify_diffs21dist.pro   Morris/SAIC/GPM_GV      March 2007
;
;  SYNOPSIS:
;  stratify_diffs21dist, prdbz, gvdbz, raintype, bbLo, bbHi, rangecat,
;                        level_idx, stats_by_cat
;
;  DESCRIPTION:
;  Takes pre-filtered 1-D arrays of PR and GV reflectivity (dBZ), PR Rain Type,
;  predetermined array indices of the lowest and highest 3-D grid levels
;  considered to be within the bounds of the Bright Band (if any), the 
;  matching array of range category (near, middle, far), the array
;  index of the current 3-D grid level being processed, and a 'stats21ways'
;  structure to hold the computed statistics.  Computes mean and standard
;  deviation of the PR-GV differences, and the maximum PR and GV dBZ values,
;  for cases of all 6 permutations of rain type (convective and stratiform) and
;  gridpoint vertical location w.r.t. the Bright Band (above it, in it, or below
;  it), and in total for the level with no regard for rain type or Bright Band,
;  separately for each distance category, and fills the stats21ways
;  structure with these statistics.  Calls stratify_diffs to do the split-outs
;  by site, raintype, BB location, etc., and the statistics computations.
;
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-

pro stratify_diffs21dist, prdbz, gvdbz, raintype, bbLo, bbHi, rangecat, $
                          level_idx, stats_by_cat

numParams = N_Params()
if numParams ne 8 then message, 'Incorrect number of parameters given.'

; "include" file for PR data constants
@pr_params.inc

nearidx = where (rangecat EQ 0, countnear)
stats_by_cat.pts_le_50 = countnear
local_statsO = {stats7ways}        ; need a local copy, can't pass struct element
if (countnear GT 0) then begin
   prdbzO = prdbz[nearidx]
   gvdbzO = gvdbz[nearidx]
   raintypeO = raintype[nearidx]
   bbLoO = bbLo[nearidx]
   bbHiO = bbHi[nearidx]
   stratify_diffs, prdbzO, gvdbzO, raintypeO, bbLoO, bbHiO, $
                   level_idx, local_statsO
   stats_by_cat.km_le_50 = local_statsO
endif

midrngidx = where (rangecat EQ 1, countmidrng)
stats_by_cat.pts_50_100 = countmidrng
local_statsL = {stats7ways}
if (countmidrng GT 0) then begin
   prdbzL = prdbz[midrngidx]
   gvdbzL = gvdbz[midrngidx]
   raintypeL = raintype[midrngidx]
   bbLoL = bbLo[midrngidx]
   bbHiL = bbHi[midrngidx]
   stratify_diffs, prdbzL, gvdbzL, raintypeL, bbLoL, bbHiL, $
                   level_idx, local_statsL
   stats_by_cat.km_50_100 = local_statsL
endif

faridx = where (rangecat EQ 2, countfar)
stats_by_cat.pts_gt_100 = countfar
local_statsC = {stats7ways}
if (countfar GT 0) then begin
   prdbzC = prdbz[faridx]
   gvdbzC = gvdbz[faridx]
   raintypeC = raintype[faridx]
   bbLoC = bbLo[faridx]
   bbHiC = bbHi[faridx]
   stratify_diffs, prdbzC, gvdbzC, raintypeC, bbLoC, bbHiC, $
                   level_idx, local_statsC
   stats_by_cat.km_gt_100 = local_statsC
endif

end

@stratify_diffs.pro
