;+
; Copyright © 2008, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
;  stratify_diffs21.pro   Morris/SAIC/GPM_GV      August 2007
;
;  SYNOPSIS:
;  stratify_diffs21, prdbz, gvdbz, raintype, bbLo, bbHi, sfctype, level_idx, stats_by_cat
;
;  DESCRIPTION:
;  Takes pre-filtered 1-D arrays of PR and GV reflectivity (dBZ), PR Rain Type,
;  predetermined array indices of the lowest and highest 3-D grid levels
;  considered to be within the bounds of the Bright Band (if any), the 
;  matching array of underlying earth surface type (landoceanflag), the array
;  index of the current 3-D grid level being processed, and a 'stats21ways'
;  structure to hold the computed statistics.  Computes mean and standard
;  deviation of the PR-GV differences, and the maximum PR and GV dBZ values,
;  for cases of all 6 permutations of rain type (convective and stratiform) and
;  gridpoint vertical location w.r.t. the Bright Band (above it, in it, or below
;  it), and in total for the level with no regard for rain type or Bright Band,
;  separately for each underlying surface type, and fills the stats21ways
;  structure with these statistics.  Calls stratify_diffs to do the split-outs
;  by site, raintype, BB location, etc., and the statistics computations.
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-

pro stratify_diffs21, prdbz, gvdbz, raintype, bbLo, bbHi, sfctype, $
                      level_idx, stats_by_cat

numParams = N_Params()
if numParams ne 8 then message, 'Incorrect number of parameters given.'

; "include" file for PR data constants
@pr_params.inc

; Information on 1C21 Land/Ocean Flag:
; -1 = (Gridpoint not coincident with PR - not a 1C21 value)
;  0 = water
;  1 = land
;  2 = coast
;  3 = water, with large attenuation
;  4 = land/coast, with large attenuation

oceanidx = where (sfctype EQ 0 OR sfctype EQ 3, countocean)
stats_by_cat.pts_sea = countocean
local_statsO = {stats7ways}        ; need a local copy, can't pass struct element
if (countocean GT 0) then begin
   prdbzO = prdbz[oceanidx]
   gvdbzO = gvdbz[oceanidx]
   raintypeO = raintype[oceanidx]
   bbLoO = bbLo[oceanidx]
   bbHiO = bbHi[oceanidx]
   stratify_diffs, prdbzO, gvdbzO, raintypeO, bbLoO, bbHiO, $
                   level_idx, local_statsO
   stats_by_cat.by_sea = local_statsO
endif

landidx = where (sfctype EQ 1 OR sfctype EQ 4, countland)
stats_by_cat.pts_land = countland
local_statsL = {stats7ways}
if (countland GT 0) then begin
   prdbzL = prdbz[landidx]
   gvdbzL = gvdbz[landidx]
   raintypeL = raintype[landidx]
   bbLoL = bbLo[landidx]
   bbHiL = bbHi[landidx]
   stratify_diffs, prdbzL, gvdbzL, raintypeL, bbLoL, bbHiL, $
                   level_idx, local_statsL
   stats_by_cat.by_land = local_statsL
endif

coastidx = where (sfctype EQ 2, countcoast)
stats_by_cat.pts_coast = countcoast
local_statsC = {stats7ways}
if (countcoast GT 0) then begin
   prdbzC = prdbz[coastidx]
   gvdbzC = gvdbz[coastidx]
   raintypeC = raintype[coastidx]
   bbLoC = bbLo[coastidx]
   bbHiC = bbHi[coastidx]
   stratify_diffs, prdbzC, gvdbzC, raintypeC, bbLoC, bbHiC, $
                   level_idx, local_statsC
   stats_by_cat.by_coast = local_statsC
endif

end

@stratify_diffs.pro
