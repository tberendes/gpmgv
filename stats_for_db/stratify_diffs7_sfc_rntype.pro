;+
; Copyright © 2012, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
;  stratify_diffs7_sfc_rntype.pro   Morris/SAIC/GPM_GV      Dec. 2012
;
;  SYNOPSIS:
;  stratify_diffs7_sfc_rntype, RRarr1st, RRarr2nd, raintype, sfctype,
;                              stats_by_cat
;
;  DESCRIPTION:
;  Takes two pre-filtered arrays of rain rate to be differenced, matching
;  arrays of Rain Type and underlying surface type, and a 'stats7ways'
;  structure to hold the computed statistics.  Computes mean and standard
;  deviation of the rainrate differences, and the maximum rainrate values,
;  for cases of all 6 permutations of rain type (convective and stratiform) and
;  underlying surface type (Ocean, Coast, Land), and in total with no regard for
;  rain or surface type, and fills the stats7ways structure with these
;  statistics.  Calls run_stats() to do the statistics computations.
;
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-

pro run_stats, RRarr1, RRarr2, the_struc
   the_struc.N = N_ELEMENTS(RRarr1)
   the_struc.AvgDif = MEAN(RRarr1-RRarr2)
   IF the_struc.N GT 1 THEN BEGIN
      rr_moments = MOMENT(RRarr1-RRarr2, VARIANCE=variance, /DOUBLE)
      IF variance GT 0.01 THEN the_struc.StdDev = SQRT(variance) $
      ELSE the_struc.StdDev = variance
   ENDIF
   the_struc.VAR1max = MAX(RRarr1)
   the_struc.VAR2max = MAX(RRarr2)
   the_struc.VAR1avg = MEAN(RRarr1)
   the_struc.VAR2avg = MEAN(RRarr2)
end



pro stratify_diffs7_sfc_rntype, RRarr1st, RRarr2nd, raintype, sfctype, $
                                stats_by_cat

   numParams = N_Params()
   if numParams ne 5 then message, 'Incorrect number of parameters given.'

   ; "include" file for PR data constants
   @pr_params.inc

   ; do the unstratified differences
   local_stats = {event_stats}        ; need a local copy, can't pass struct element
   run_stats, RRarr1st, RRarr2nd, local_stats
   stats_by_cat.stats_total = local_stats

   ; do the convective differences, by surface type
   idxSeaC = where (raintype eq RainType_convective and sfctype EQ 1, countSeaC)
   local_statsOC = {event_stats}        ; need a local copy, can't pass struct element
   if (countSeaC GT 0) then begin
      RRarr1stOC = RRarr1st[idxSeaC]
      RRarr2ndOC = RRarr2nd[idxSeaC]
;      raintypeOC = raintype[idxSeaC]
      run_stats, RRarr1stOC, RRarr2ndOC, local_statsOC
      stats_by_cat.stats_convocean = local_statsOC
   endif

   idxLandC = where (raintype eq RainType_convective and sfctype EQ 2, countLandC)
   local_statsLC = {event_stats}
   if (countLandC GT 0) then begin
      RRarr1stLC = RRarr1st[idxLandC]
      RRarr2ndLC = RRarr2nd[idxLandC]
;      raintypeLC = raintype[idxLandC]
      run_stats, RRarr1stLC, RRarr2ndLC, local_statsLC
      stats_by_cat.stats_convland = local_statsLC
   endif

   idxCoastC = where (raintype eq RainType_convective and sfctype EQ 3, countCoastC)
   local_statsCC = {event_stats}
   if (countCoastC GT 0) then begin
      RRarr1stCC = RRarr1st[idxCoastC]
      RRarr2ndCC = RRarr2nd[idxCoastC]
;      raintypeCC = raintype[idxCoastC]
      run_stats, RRarr1stCC, RRarr2ndCC, local_statsCC
      stats_by_cat.stats_convcoast = local_statsCC
   endif

   ; do the stratiform differences, by surface type
   idxSeaS = where (raintype eq RainType_stratiform and sfctype EQ 1, countSeaS)
   local_statsOS = {event_stats}        ; need a local copy, can't pass struct element
   if (countSeaS GT 0) then begin
      RRarr1stOS = RRarr1st[idxSeaS]
      RRarr2ndOS = RRarr2nd[idxSeaS]
;      raintypeOS = raintype[idxSeaS]
      run_stats, RRarr1stOS, RRarr2ndOS, local_statsOS
      stats_by_cat.stats_stratocean = local_statsOS
   endif

   idxLandS = where (raintype eq RainType_stratiform and sfctype EQ 2, countLandS)
   local_statsLS = {event_stats}
   if (countLandS GT 0) then begin
      RRarr1stLS = RRarr1st[idxLandS]
      RRarr2ndLS = RRarr2nd[idxLandS]
;      raintypeLS = raintype[idxLandS]
      run_stats, RRarr1stLS, RRarr2ndLS, local_statsLS
      stats_by_cat.stats_stratland = local_statsLS
   endif

   idxCoastS = where (raintype eq RainType_stratiform and sfctype EQ 3, countCoastS)
   local_statsCS = {event_stats}
   if (countCoastS GT 0) then begin
      RRarr1stCS = RRarr1st[idxCoastS]
      RRarr2ndCS = RRarr2nd[idxCoastS]
;      raintypeCS = raintype[idxCoastS]
      run_stats, RRarr1stCS, RRarr2ndCS, local_statsCS
      stats_by_cat.stats_stratcoast = local_statsCS
   endif

end
