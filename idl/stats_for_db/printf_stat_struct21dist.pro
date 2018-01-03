;+
; Copyright © 2008, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
;  printf_stat_struct21dist.pro   Morris/SAIC/GPM_GV      Nov 2007
;
;  SYNOPSIS:
;  printf_stat_struct21dist, instats_all, percent, source, siteID, orbit,
;                             level, file_unit
;
;  DESCRIPTION:
;  Prints the contents of a stats21ways structure and other passed parameters
;  needed to identify the statistical data values to a delimited text file of
;  a form suitable for loading into the 'gpmgv' database.  This version of
;  printf_stat_struct21* uses a stats21ways structure split out by distance
;  from the radar, represented as three distinct range categories.
;
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-

pro printf_stat_struct21dist, instats_all, pctAbv, source, siteID, orbit, $
                              level, file_unit

;fmtstrPre = '(i0,"'  +  '|'  +  source  +  '|'
fmtstrPre = '(2(i0,"|"),"'  +  source  +  '|'
fmtstrPost = '|",2(A0,"|"),f0.1,6("|",f0.5),"|",i0)'

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
  stratif = 'Total'
  fmtstr = fmtstrPre + stratif + fmtstrPost
  printf, file_unit, FORMAT = fmtstr, pctAbv, rangecat, siteID, orbit, (level+1)*1.5, $
         stats.AvgDif, stats.StdDev, stats.PRmaxZ, stats.GVmaxZ, $
         stats.PRavgZ, stats.GVavgZ, stats.N

  stats = instats.stats_convbelow
  stratif = 'C_below'
  fmtstr = fmtstrPre + stratif + fmtstrPost
  printf, file_unit, FORMAT = fmtstr, pctAbv, rangecat, siteID, orbit, (level+1)*1.5, $
         stats.AvgDif, stats.StdDev, stats.PRmaxZ, stats.GVmaxZ, $
         stats.PRavgZ, stats.GVavgZ, stats.N

  stats = instats.stats_convin
  stratif = 'C_in'
  fmtstr = fmtstrPre + stratif + fmtstrPost
  printf, file_unit, FORMAT = fmtstr, pctAbv, rangecat, siteID, orbit, (level+1)*1.5, $
         stats.AvgDif, stats.StdDev, stats.PRmaxZ, stats.GVmaxZ, $
         stats.PRavgZ, stats.GVavgZ, stats.N

  stats = instats.stats_convabove
  stratif = 'C_above'
  fmtstr = fmtstrPre + stratif + fmtstrPost
  printf, file_unit, FORMAT = fmtstr, pctAbv, rangecat, siteID, orbit, (level+1)*1.5, $
         stats.AvgDif, stats.StdDev, stats.PRmaxZ, stats.GVmaxZ, $
         stats.PRavgZ, stats.GVavgZ, stats.N

  stats = instats.stats_stratbelow
  stratif = 'S_below'
  fmtstr = fmtstrPre + stratif + fmtstrPost
  printf, file_unit, FORMAT = fmtstr, pctAbv, rangecat, siteID, orbit, (level+1)*1.5, $
       stats.AvgDif, stats.StdDev, stats.PRmaxZ, stats.GVmaxZ, $
       stats.PRavgZ, stats.GVavgZ, stats.N

  stats = instats.stats_stratin
  stratif = 'S_in'
  fmtstr = fmtstrPre + stratif + fmtstrPost
  printf, file_unit, FORMAT = fmtstr, pctAbv, rangecat, siteID, orbit, (level+1)*1.5, $
         stats.AvgDif, stats.StdDev, stats.PRmaxZ, stats.GVmaxZ, $
         stats.PRavgZ, stats.GVavgZ, stats.N

  stats = instats.stats_stratabove
  stratif = 'S_above'
  fmtstr = fmtstrPre + stratif + fmtstrPost
  printf, file_unit, FORMAT = fmtstr, pctAbv, rangecat, siteID, orbit, (level+1)*1.5, $
         stats.AvgDif, stats.StdDev, stats.PRmaxZ, stats.GVmaxZ, $
         stats.PRavgZ, stats.GVavgZ, stats.N

  ENDIF

endfor

end
