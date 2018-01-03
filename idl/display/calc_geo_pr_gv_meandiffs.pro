;===============================================================================
;+
; Copyright © 2008, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; calc_geo_pr_gv_meandiffs.pro           Morris/SAIC/GPM_GV      September 2008
;
; DESCRIPTION
; -----------
; Takes arrays of PR and GV dBZs read from the geo_match netCDF files, height
; level category of the dBZ data points, corresponding arrays of Rain Type and
; distance category from the ground radar (expanded over the elevation sweeps of
; the GV radar to match up to the dBZ arrays), min dBZ and max Distance category
; thresholds, and a histogram bin size as inputs.  Computes mean differences
; between the PR and GV reflectivity two ways: (1) mean of point-to-point dBZ
; differences where both PR and GV points are at/above the threshold, and (2)
; difference between PR and GV layer-mean reflectivity for points between 15
; and 55 dBZ, inclusive, with no regard for PR-to-GV point matchups.  In either
; case, the data are restricted to those points within 100 km (hard coded)
; of the ground radar site.
;
; Future Enhancement:  Add optional keyword parameter for GV rain type, and
;   when set, force match between PR and GV rain type in computing differences
;   by rain type.  Get rid of hard-wired minz4hist, maxz4hist.
;
; PARAMETERS
; ----------
; pr_grid      array of PR reflectivity (INPUT)
; gv_grid      array of ground (GV) radar reflectivity (INPUT)
; raintype     array of PR-based Rain Type (INPUT)
; distance     array of PR point distances (km) from GV radar (INPUT)
; distcat      array of distance category from GV radar (INPUT)
; hgtcat       array of height level category (INPUT)
; levelnum     index of height level at which to compute (INPUT)
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
; rtyp_used    rain type values for pr_used and gv_used, stored into passed
;              array (I/O)
;
; HISTORY
; -------
; 02/18/09  Morris, GPM GV (SAIC) -- Changed nconv and nstrat checks to GE 0
;                                    from GE 1.  No Std Dev computations here.
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;===============================================================================

pro calc_geo_pr_gv_meandiffs, pr_grid, gv_grid, raintype, distance, distcat, $
                              hgtcat, levelnum, dbzcutoff, distcutoff, bsize, $
                              mnprarr, mngvarr, havematch, diffstruc, $
                              pr_used, gv_used, rtyp_used


;  "include" file for PR data constants
@pr_params.inc
minz4hist = 15.
maxz4hist = 55.

; identify the subset of points at this levelnum
idxathgt = WHERE( hgtcat EQ levelnum, countathgt )
dbzcorlev = pr_grid[idxathgt]
dbznexlev = gv_grid[idxathgt]
distlev = distcat[idxathgt]
raintypelev = raintype[idxathgt]
distancelev = distance[idxathgt]
; identify the set of points within 100 km
idx100km = where(distlev le 1, count100)
if (count100 gt 0) then begin
   dbzcor2diff = dbzcorlev[idx100km]
   dbznex2diff = dbznexlev[idx100km]
   raintype100 = raintypelev[idx100km]
   distance100 = distancelev[idx100km]

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
      idxpos2 = where(dbznx1 ge dbzcutoff, countpos2)
      diffstruc.fullcount = countpos2
      if (countpos2 gt 0) then begin
         dbzpr2 = dbzpr1[idxpos2]
         pr_used[0] = dbzpr2       ; return set of z's used in computing stats
         dbznx2 = dbznx1[idxpos2]
         gv_used[0] = dbznx2       ; return set of z's used in computing stats
         raintype2 = raintype1[idxpos2]
         rtyp_used[0] =  raintype2 ; ditto, for rain type points
         dist2 = dist1[idxpos2]
         havematch = 1
         diffstruc.meandiff = mean(dbzpr2-dbznx2)
         diffstruc.meandist = mean(dist2)
         diffstruc.maxpr = max(dbzpr2)
         diffstruc.maxgv = max(dbznx2)
         mnprarr[0,levelnum] = mean(dbzpr2)  ; for all points, ignoring raintype
         mngvarr[0,levelnum] = mean(dbznx2)

;        Repeat mean diff computations for points with Convective rain type
;        indicated in the PR, and for Stratiform rain type points only.

         idxconv = where( raintype2 eq RainType_convective, nconv )
         diffstruc.meandiffc = -99.999
         if (nconv gt 0) then begin
            dbzpr2c = dbzpr2[idxconv]
            dbznx2c = dbznx2[idxconv]
            diffstruc.meandiffc = mean(dbzpr2c-dbznx2c)
            diffstruc.countc = nconv
            mnprarr[2,levelnum] = mean(dbzpr2c)
            mngvarr[2,levelnum] = mean(dbznx2c)
         endif
         idxstrat = where( raintype2 eq RainType_stratiform, nstrat )
         diffstruc.meandiffs = -99.999
         if (nstrat gt 0) then begin
            dbzpr2s = dbzpr2[idxstrat]
            dbznx2s = dbznx2[idxstrat]
            diffstruc.meandiffs = mean(dbzpr2s-dbznx2s)
            diffstruc.counts = nstrat
            mnprarr[1,levelnum] = mean(dbzpr2s)
            mngvarr[1,levelnum] = mean(dbznx2s)
         endif
      endif
   endif
endif else begin
   print, "NOTE from calc_geo_pr_gv_meandiffs: no gridpoints found within distance cutoff in km: ", distcutoff
   print, "at ", (levelnum+1)*1.5, " km grid level."
endelse

end
