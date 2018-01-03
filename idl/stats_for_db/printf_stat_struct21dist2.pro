;+
; Copyright © 2008, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
;  printf_stat_struct21dist2.pro   Morris/SAIC/GPM_GV      Nov 2007
;
;  SYNOPSIS:
;  printf_stat_struct21dist2, instats_all, percent, source, siteID, orbit,
;                             level, file_unit
;
;  DESCRIPTION:
;  Prints the contents of a stats21ways structure and other passed parameters
;  needed to identify the statistical data values to a delimited text file of
;  a form suitable for loading into the 'gpmgv' database.  This version of
;  printf_stat_struct21* uses a stats21ways structure split out by distance
;  from the radar, represented as three distinct range categories.
;
; HISTORY
; -------
; 11/30/10  Morris/GPM GV/SAIC
; - Add processing of gvzmax and gvzstddev if Version 2 netcdf file.
; 06/18/14  Morris/GPM GV/SAIC
; - Limit printing to those combinations with non-zero sample counts.
;
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-

pro printf_stat_struct21dist2, instats_all, pctAbv, source, siteID, orbit, $
                              level, file_unit

;fmtstrPre = '(i0,"'  +  '|'  +  source  +  '|'
fmtstrPre = '(2(i0,"|"),"'  +  source  +  '|'
fmtstrPost = '|",2(A0,"|"),f0.1,8("|",f0.5),"|",i0)'

for isfc = 0,2 do begin

  numpts = 0L

  CASE isfc OF
     0: BEGIN
           instats = instats_all.km_le_50
           numpts = instats_all.pts_le_50
           rangecat = 0
        END
     1: BEGIN
           instats = instats_all.km_50_100
           numpts = instats_all.pts_50_100
           rangecat = 1
        END
     2: BEGIN
           instats = instats_all.km_gt_100
           numpts = instats_all.pts_gt_100
           rangecat = 2
        END
     ELSE:
  ENDCASE

  IF numpts GT 0L THEN BEGIN
  
  stats = instats.stats_total
  IF stats.N GT 0 THEN BEGIN
  stratif = 'Total'
  fmtstr = fmtstrPre + stratif + fmtstrPost
  printf, file_unit, FORMAT = fmtstr, pctAbv, rangecat, siteID, orbit, (level+1)*1.5, $
         stats.AvgDif, stats.StdDev, stats.PRmaxZ, stats.GVmaxZ, $
         stats.PRavgZ, stats.GVavgZ, stats.GVabsmaxZ, stats.GVmaxstddevZ, stats.N
  ENDIF

  stats = instats.stats_convbelow
  IF stats.N GT 0 THEN BEGIN
  stratif = 'C_below'
  fmtstr = fmtstrPre + stratif + fmtstrPost
  printf, file_unit, FORMAT = fmtstr, pctAbv, rangecat, siteID, orbit, (level+1)*1.5, $
         stats.AvgDif, stats.StdDev, stats.PRmaxZ, stats.GVmaxZ, $
         stats.PRavgZ, stats.GVavgZ, stats.GVabsmaxZ, stats.GVmaxstddevZ, stats.N
  ENDIF

  stats = instats.stats_convin
  IF stats.N GT 0 THEN BEGIN
  stratif = 'C_in'
  fmtstr = fmtstrPre + stratif + fmtstrPost
  printf, file_unit, FORMAT = fmtstr, pctAbv, rangecat, siteID, orbit, (level+1)*1.5, $
         stats.AvgDif, stats.StdDev, stats.PRmaxZ, stats.GVmaxZ, $
         stats.PRavgZ, stats.GVavgZ, stats.GVabsmaxZ, stats.GVmaxstddevZ, stats.N
  ENDIF

  stats = instats.stats_convabove
  IF stats.N GT 0 THEN BEGIN
  stratif = 'C_above'
  fmtstr = fmtstrPre + stratif + fmtstrPost
  printf, file_unit, FORMAT = fmtstr, pctAbv, rangecat, siteID, orbit, (level+1)*1.5, $
         stats.AvgDif, stats.StdDev, stats.PRmaxZ, stats.GVmaxZ, $
         stats.PRavgZ, stats.GVavgZ, stats.GVabsmaxZ, stats.GVmaxstddevZ, stats.N
  ENDIF

  stats = instats.stats_stratbelow
  IF stats.N GT 0 THEN BEGIN
  stratif = 'S_below'
  fmtstr = fmtstrPre + stratif + fmtstrPost
  printf, file_unit, FORMAT = fmtstr, pctAbv, rangecat, siteID, orbit, (level+1)*1.5, $
       stats.AvgDif, stats.StdDev, stats.PRmaxZ, stats.GVmaxZ, $
       stats.PRavgZ, stats.GVavgZ, stats.GVabsmaxZ, stats.GVmaxstddevZ, stats.N
  ENDIF

  stats = instats.stats_stratin
  IF stats.N GT 0 THEN BEGIN
  stratif = 'S_in'
  fmtstr = fmtstrPre + stratif + fmtstrPost
  printf, file_unit, FORMAT = fmtstr, pctAbv, rangecat, siteID, orbit, (level+1)*1.5, $
         stats.AvgDif, stats.StdDev, stats.PRmaxZ, stats.GVmaxZ, $
         stats.PRavgZ, stats.GVavgZ, stats.GVabsmaxZ, stats.GVmaxstddevZ, stats.N
  ENDIF

  stats = instats.stats_stratabove
  IF stats.N GT 0 THEN BEGIN
  stratif = 'S_above'
  fmtstr = fmtstrPre + stratif + fmtstrPost
  printf, file_unit, FORMAT = fmtstr, pctAbv, rangecat, siteID, orbit, (level+1)*1.5, $
         stats.AvgDif, stats.StdDev, stats.PRmaxZ, stats.GVmaxZ, $
         stats.PRavgZ, stats.GVavgZ, stats.GVabsmaxZ, stats.GVmaxstddevZ, stats.N
  ENDIF

  ENDIF

endfor

end
