;+
; Copyright © 2008, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
;  stratify_diffs21angle.pro   Morris/SAIC/GPM_GV      November 2007
;
;  SYNOPSIS:
;  stratify_diffs21angle, prdbz, gvdbz, raintype, bbLo, bbHi, anglecat, level_idx,
;                    stats_by_cat
;
;  DESCRIPTION:
;  Takes pre-filtered 1-D arrays of PR and GV reflectivity (dBZ), PR Rain Type,
;  predetermined array indices of the lowest and highest 3-D grid levels
;  considered to be within the bounds of the Bright Band (if any), the 
;  matching array of PR view angle category (near, middle, far), the array
;  index of the current 3-D grid level being processed, and a 'stats21ways'
;  structure to hold the computed statistics.  Computes mean and standard
;  deviation of the PR-GV differences, and the maximum PR and GV dBZ values,
;  for cases of all 6 permutations of rain type (convective and stratiform) and
;  gridpoint vertical location w.r.t. the Bright Band (above it, in it, or below
;  it), and in total for the level with no regard for rain type or Bright Band,
;  separately for each angle category, and fills the stats21ways structure with
;  these statistics.
;  This routine prepares input array subsets split out by view angle category,
;  and then calls stratify_diffs to do the statistics computations in total and
;  split out by the 6 permutations of raintype and BB location.
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-

pro stratify_diffs21angle, prdbz, gvdbz, raintype, bbLo, bbHi, anglecat, $
                           level_idx, stats_by_cat

numParams = N_Params()
if numParams ne 8 then message, 'Incorrect number of parameters given.'

; "include" file for PR data constants
@pr_params.inc

nearidx = where (anglecat EQ 0, countnear)
stats_by_cat.pts_le_8 = countnear
local_statsO = {stats7ways}        ; need a local copy, can't pass struct element
if (countnear GT 0) then begin
   prdbzO = prdbz[nearidx]
   gvdbzO = gvdbz[nearidx]
   raintypeO = raintype[nearidx]
   bbLoO = bbLo[nearidx]
   bbHiO = bbHi[nearidx]
   stratify_diffs, prdbzO, gvdbzO, raintypeO, bbLoO, bbHiO, $
                   level_idx, local_statsO
   stats_by_cat.fromnadir_le_8 = local_statsO
endif

midrngidx = where (anglecat EQ 1, countmidrng)
stats_by_cat.pts_9_16 = countmidrng
local_statsL = {stats7ways}
if (countmidrng GT 0) then begin
   prdbzL = prdbz[midrngidx]
   gvdbzL = gvdbz[midrngidx]
   raintypeL = raintype[midrngidx]
   bbLoL = bbLo[midrngidx]
   bbHiL = bbHi[midrngidx]
   stratify_diffs, prdbzL, gvdbzL, raintypeL, bbLoL, bbHiL, $
                   level_idx, local_statsL
   stats_by_cat.fromnadir_9_16 = local_statsL
endif

faridx = where (anglecat EQ 2, countfar)
stats_by_cat.pts_gt_16 = countfar
local_statsC = {stats7ways}
if (countfar GT 0) then begin
   prdbzC = prdbz[faridx]
   gvdbzC = gvdbz[faridx]
   raintypeC = raintype[faridx]
   bbLoC = bbLo[faridx]
   bbHiC = bbHi[faridx]
   stratify_diffs, prdbzC, gvdbzC, raintypeC, bbLoC, bbHiC, $
                   level_idx, local_statsC
   stats_by_cat.fromnadir_gt_16 = local_statsC
endif

end

@stratify_diffs.pro
