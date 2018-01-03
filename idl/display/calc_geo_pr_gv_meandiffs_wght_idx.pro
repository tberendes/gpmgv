;===============================================================================
;+
; Copyright © 2009, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; calc_geo_pr_gv_meandiffs_wght_idx.pro        Morris/SAIC/GPM_GV      February 2009
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
; mnprarr      computed layer-mean PR dBZ for all 13 levels (I/O)
; mngvarr      computed layer-mean GV dBZ for all 13 levels (I/O)
; havematch    flag, 1 if valid data exists at levelnum, 0 if none (I/O)
; diffstruc    structure to hold computed differences, counts, etc. (I/O)
; idx_used     indices which define the array subset of all PR and GV dBZs
;              and rain type values used in point-to-point difference
;              computations at this level, stored into passed array (I/O)
; voldepth     vertical depth of the pr_grid and gv_grid volumes (INPUT)
;
; HISTORY
; -------
; 02/18/09  Morris, GPM GV (SAIC) -- Changed nconv and nstrat checks to GE 0
;                                    from GE 1.  No Std Dev computations here.
; 05/07/09  Morris, GPM GV (SAIC) -- Add volume (sample depth) weighting of the
;                                    samples to reduce the influence of numerous
;                                    small volumes at short ranges.
; 05/27/10  Morris/GPM GV/SAIC    -- Now limits the computed results to within
;                                    100km by actually using passed 'distcutoff'
;                                    value rather than hard-coded criterion
;                                    of 'distcat LE 1'.
; 12/26/12  Morris/GPM GV/SAIC    -- Changed minz4hist and maxz4hist to be
;                                    dependent on dbzcutoff value, assumed to
;                                    be set according to Z vs. rainrate inputs.
; 08/15/13  Morris/GPM GV/SAIC    -- Removed unused 'bsize' parameter from call
;                                    sequence and body.
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;===============================================================================

pro calc_geo_pr_gv_meandiffs_wght_idx, pr_grid, gv_grid, raintype, distance, $
                              distcat, hgtcat, levelnum, dbzcutoff, $
                              distcutoff, mnprarr, mngvarr, havematch, $
                              diffstruc, idx_used, voldepth


;  "include" file for PR data constants
@pr_params.inc

is_z = dbzcutoff GE 5.0
IF is_z THEN BEGIN
   ; reflectivity fields assumed
   minz4hist = 15.
   maxz4hist = 55.
ENDIF ELSE BEGIN
   ; rain rate fields assumed
   minz4hist = dbzcutoff
   maxz4hist = 250.0
ENDELSE

; build array indices of input arrays, use as starting point to keep track of
; indices of subset of points used in calculations
idxall = LINDGEN( N_ELEMENTS(pr_grid) )

; identify the subset of points at this levelnum
idxathgt = WHERE( hgtcat EQ levelnum, countathgt )
dbzcorlev = pr_grid[idxathgt]
dbznexlev = gv_grid[idxathgt]
distlev = distcat[idxathgt]
raintypelev = raintype[idxathgt]
distancelev = distance[idxathgt]
idxByLev = idxall[idxathgt]
weightsByLev = voldepth[idxathgt]
; identify the set of points within 100 km
idx100km = where(distancelev le distcutoff, count100)
if (count100 gt 0) then begin
   dbzcor2diff = dbzcorlev[idx100km]
   dbznex2diff = dbznexlev[idx100km]
   raintype100 = raintypelev[idx100km]
   distance100 = distancelev[idx100km]
   idxBy100 = idxByLev[idx100km]
   weights = weightsByLev[idx100km]

;  Compute mean differences, as area/value weighted mean, between maxz4hist and minz4hist

   idxprwgt = WHERE(dbzcor2diff GE minz4hist AND dbzcor2diff LE maxz4hist, countprwgt)
   idxgvwgt = WHERE(dbznex2diff GE minz4hist AND dbznex2diff LE maxz4hist, countgvwgt)
   IF ( countprwgt GT 0 AND countgvwgt GT 0 ) THEN BEGIN
      IF is_z THEN BEGIN
         ; compute area-mean reflectivity difference
;         message, "Computing PR-GR reflectivity area-mean Z difference.", /INFORMATIONAL
         prmeanz = total(dbzcor2diff[idxprwgt]*weights[idxprwgt])/total(weights[idxprwgt])
         gvmeanz = total(dbznex2diff[idxgvwgt]*weights[idxgvwgt])/total(weights[idxgvwgt])
         diffstruc.AvgDifByHist = prmeanz - gvmeanz
      ENDIF ELSE BEGIN
         ; compute volumetric rainfall bias, TMI/PR
;         message, "Computing TMI/PR rainrate bias.", /INFORMATIONAL
         prmeanz = total(dbzcor2diff[idxprwgt] ) ;*weights[idxprwgt])/total(weights[idxprwgt])
         gvmeanz = total(dbznex2diff[idxgvwgt] ) ;*weights[idxgvwgt])/total(weights[idxgvwgt])
         diffstruc.AvgDifByHist = prmeanz/gvmeanz
      ENDELSE
   ENDIF

;  Compute mean gridpoint difference for points where PR and GV are both above
;  input dBZ threshold "dbzcutoff".  Store qualifying points in supplied I/O
;  arrays "pr_used" and "gv_used".

   idxpos1 = where(dbzcor2diff ge dbzcutoff, countpos1)
;print, "    Number rejected as PR rainrate < ", dbzcutoff, ': ', count100-countpos1
   if (countpos1 gt 0) then begin
      dbzpr1 = dbzcor2diff[idxpos1]
      raintype1 = raintype100[idxpos1]
      dist1 = distance100[idxpos1]
      dbznx1 = dbznex2diff[idxpos1]
      idxUsed1 = idxBy100[idxpos1]
      weights1 = weights[idxpos1]
      idxpos2 = where(dbznx1 ge dbzcutoff, countpos2)
;print, "Additional rejected as GR rainrate < ", dbzcutoff, ': ', countpos1-countpos2
      diffstruc.fullcount = countpos2
      if (countpos2 gt 0) then begin
         dbzpr2 = dbzpr1[idxpos2]
;         pr_used[0] = dbzpr2       ; return set of z's used in computing stats
         dbznx2 = dbznx1[idxpos2]
;         gv_used[0] = dbznx2       ; return set of z's used in computing stats
         raintype2 = raintype1[idxpos2]
;         rtyp_used[0] =  raintype2 ; ditto, for rain type points
         dist2 = dist1[idxpos2]
         idx_used[0] = idxUsed1[idxpos2]  ; return indices of points used in computing stats
         weights2 = weights1[idxpos2]
         havematch = 1
         diffstruc.meandiff = total((dbzpr2-dbznx2)*weights2)/total(weights2)
         diffstruc.meandist = mean(dist2)
         diffstruc.maxpr = max(dbzpr2)
         diffstruc.maxgv = max(dbznx2)
         mnprarr[0,levelnum] = total(dbzpr2*weights2)/total(weights2) ; for all points, ignoring raintype
         mngvarr[0,levelnum] = total(dbznx2*weights2)/total(weights2)

;        Repeat mean diff computations for points with Convective rain type
;        indicated in the PR, and for Stratiform rain type points only.

         idxconv = where( raintype2 eq RainType_convective, nconv )
         diffstruc.meandiffc = -99.999
         if (nconv gt 0) then begin
            dbzpr2c = dbzpr2[idxconv]
            dbznx2c = dbznx2[idxconv]
            weights2c = weights2[idxconv]
            diffstruc.meandiffc = total((dbzpr2c-dbznx2c)*weights2c)/total(weights2c)
            diffstruc.countc = nconv
            mnprarr[2,levelnum] = total(dbzpr2c*weights2c)/total(weights2c)
            mngvarr[2,levelnum] = total(dbznx2c*weights2c)/total(weights2c)
         endif
         idxstrat = where( raintype2 eq RainType_stratiform, nstrat )
         diffstruc.meandiffs = -99.999
         if (nstrat gt 0) then begin
            dbzpr2s = dbzpr2[idxstrat]
            dbznx2s = dbznx2[idxstrat]
            weights2s = weights2[idxstrat]
            diffstruc.meandiffs = total((dbzpr2s-dbznx2s)*weights2s)/total(weights2s)
            diffstruc.counts = nstrat
            mnprarr[1,levelnum] = total(dbzpr2s*weights2s)/total(weights2s)
            mngvarr[1,levelnum] = total(dbznx2s*weights2s)/total(weights2s)
         endif
      endif
   endif
endif else begin
   print, "NOTE from calc_geo_pr_gv_meandiffs: no gridpoints found within distance cutoff in km: ", distcutoff
   print, "at ", (levelnum+1)*1.5, " km grid level."
endelse

end
