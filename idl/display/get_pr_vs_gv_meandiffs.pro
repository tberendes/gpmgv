;===============================================================================
;+
; Copyright © 2008, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; get_pr_vs_gv_meandiffs.pro           Morris/SAIC/GPM_GV      February 2008
;
; DESCRIPTION
; -----------
; Takes 3-D arrays of PR and GV dBZs, corresponding 2-D arrays of Rain Type and
; distance from the ground radar (grid center), min dBZ and max Distance
; thresholds, and a histogram bin size as inputs.  Computes mean differences
; between the PR and GV reflectivity two ways: (1) mean of point-to-point dBZ
; differences where both PR and GV points are at/above the threshold, and (2)
; difference between PR and GV layer-mean reflectivity for points between 15
; and 55 dBZ, inclusive, with no regard for PR-to-GV point matchups.  In either
; case, the data are restricted to those gridpoints within 100 km (hard coded)
; of the ground radar site.
;
; Future Enhancement:  Add optional keyword parameter for GV rain type, and
;   when set, force match between PR and GV rain type in computing differences
;   by rain type.  Get rid of hard-wired minz4hist, maxz4hist.
;
; PARAMETERS
; ----------
; pr_grid      3-D grid of PR reflectivity (INPUT)
; gv_grid      3-D grid of ground (GV) radar reflectivity (INPUT)
; raintype     2-D grid of PR-based Rain Type (INPUT)
; distance     2-D grid of gridpoint distances (km) from GV radar (INPUT)
; levelnum     Z-index of 3-D grid for height at which to compute (INPUT)
; dbzcutoff    minimum dBZ to use in point-to-point differences  (INPUT)
; distcutoff   maximum gridpoint distance (km) from GV radar to be used (INPUT)
; bsize        size (dBZ) of bins to be used in IDL HISTOGRAM function (INPUT)
; mnprarr      computed layer-mean PR dBZ for all 13 levels (I/O)
; mngvarr      computed layer-mean GV dBZ for all 13 levels (I/O)
; havematch    flag, 1 if valid data exists at levelnum, 0 if none (I/O)
; diffstruc    structure to hold computed differences, counts, etc. (I/O)
; pr_used      set of all PR dBZs used in point-to-point difference
;              computations at this level, stored into passed array (I/O)
; gv_used      set of all GV dBZs used in point-to-point difference
;              computations at this level, stored into passed array (I/O)
;
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;===============================================================================

pro get_pr_vs_gv_meandiffs, pr_grid, gv_grid, raintype, distance, levelnum, $
                            dbzcutoff, distcutoff, bsize, $
                            mnprarr, mngvarr, havematch, diffstruc, $
                            pr_used, gv_used


;  "include" file for PR data constants
@pr_params.inc
minz4hist = 15.
maxz4hist = 55.

dbzcorlev = pr_grid[*,*,levelnum]
dbznexlev = gv_grid[*,*,levelnum]
idx100km = where(distance le 100.0, count100)
if (count100 gt 0) then begin
   dbzcor2diff = dbzcorlev[idx100km]
   dbznex2diff = dbznexlev[idx100km]
   raintype100 = raintype[idx100km]
   distance100 = distance[idx100km]

;  Compute histogram-based differences, as area/value weighted mean.
;  Is equivalent to a simple average if binsize=1:
   prhist = histogram(dbzcor2diff, min=minz4hist, max=maxz4hist, $
            binsize = bsize, locations = prhiststart)
   gvhist = histogram(dbznex2diff, min=minz4hist, max=maxz4hist, $
            binsize = bsize)
   zvals = prhiststart + (bsize/2.0)
   if (total(prhist) GT 0) then begin
      prmeanz = total(prhist*zvals)/total(prhist)
      if (total(gvhist) GT 0) then begin
         gvmeanz = total(gvhist*zvals)/total(gvhist)
         diffstruc.AvgDifByHist = prmeanz - gvmeanz
      endif
   endif

;  Compute mean gridpoint difference for points where PR and GV are both above
;  input dBZ threshold "dbzcutoff".  Store qualifying points in supplied I/O
;  arrays "pr_used" and "gv_used".

   idxpos1 = where(dbzcor2diff ge dbzcutoff, countpos1)
   if (countpos1 gt 0) then begin
      dbzpr1 = dbzcor2diff[idxpos1]
      raintype1 = raintype100[idxpos1]
      dist1 = distance100[idxpos1]
      dbznx1 = dbznex2diff[idxpos1]

     ; compute area mean PR reflectivity for convective and stratiform, ignoring GV
      idxconv = where( raintype1 eq RainType_convective, nconv )
      if (nconv gt 1) then PRareameanc = mean(dbzpr1[idxconv]) else PRareameanc = -99.999
      idxstrat = where( raintype1 eq RainType_stratiform, nstrat )
      if (nstrat gt 1) then PRareameans = mean(dbzpr1[idxstrat]) else PRareameans = -99.999

     ; compute area mean GV reflectivity for convective and stratiform, ignoring PR
      idxpos3 = where(dbznex2diff ge dbzcutoff, countpos3)
      if (countpos3 gt 0) then begin
         raintype3 = raintype100[idxpos3]
         dbznx3 = dbznex2diff[idxpos3]
         idxconv = where( raintype3 eq RainType_convective, nconv )
         if (nconv gt 1) then GVareameanc = mean(dbznx3[idxconv]) else GVareameanc = -99.999
         idxstrat = where( raintype3 eq RainType_stratiform, nstrat )
         if (nstrat gt 1) then GVareameans = mean(dbznx3[idxstrat]) else GVareameans = -99.999
         if (PRareameanc GT 0 AND GVareameanc GT 0) then $
            diffstruc.areameandiffc = PRareameanc-GVareameanc $
         else diffstruc.areameandiffc = -99.999
         if (PRareameans GT 0 AND GVareameans GT 0) then $
            diffstruc.areameandiffs = PRareameans-GVareameans $
         else diffstruc.areameandiffs = -99.999
      endif

      idxpos2 = where(dbznx1 ge dbzcutoff, countpos2)
      if (countpos2 gt 0) then begin
         diffstruc.fullcount = countpos2
         dbzpr2 = dbzpr1[idxpos2]
         pr_used[0] = dbzpr2       ; return set of z's used in computing stats
         dbznx2 = dbznx1[idxpos2]
         gv_used[0] = dbznx2       ; return set of z's used in computing stats
         dist2 = dist1[idxpos2]
         raintype2 = raintype1[idxpos2]
         havematch = 1
         diffstruc.meandiff = mean(dbzpr2-dbznx2)
         diffstruc.meandist = mean(dist2)
         diffstruc.maxpr = max(dbzpr2)
         diffstruc.maxgv = max(dbznx2)
         mnprarr[levelnum] = mean(dbzpr2)
         mngvarr[levelnum] = mean(dbznx2)

;        Repeat mean diff computations for points with Convective rain type
;        indicated in the PR, and for Stratiform rain type points only.

         idxconv = where( raintype2 eq RainType_convective, nconv )
         meandiffc = -99.999
         if (nconv gt 1) then begin
            dbzpr2c = dbzpr2[idxconv]
            dbznx2c = dbznx2[idxconv]
            diffstruc.meandiffc = mean(dbzpr2c-dbznx2c)
            ;diffstruc.areameandiffc = mean(dbzpr2c)-mean(dbznx2c)
            diffstruc.countc = nconv
         endif
         idxstrat = where( raintype2 eq RainType_stratiform, nstrat )
         meandiffs = -99.999
         if (nstrat gt 1) then begin
            dbzpr2s = dbzpr2[idxstrat]
            dbznx2s = dbznx2[idxstrat]
            diffstruc.meandiffs = mean(dbzpr2s-dbznx2s)
            ;diffstruc.areameandiffs = mean(dbzpr2s)-mean(dbznx2s)
            diffstruc.counts = nstrat
         endif
      endif
   endif
endif else begin
   print, "NOTE from get_pr_vs_gv_meandiffs: no gridpoints found within distance cutoff in km: ", distcutoff
   print, "at ", (levelnum+1)*1.5, " km grid level."
endelse

end
