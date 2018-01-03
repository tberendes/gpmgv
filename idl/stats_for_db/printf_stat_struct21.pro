;+
; Copyright © 2008, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
;  printf_stat_struct21.pro   Morris/SAIC/GPM_GV      Aug 2007
;
;  SYNOPSIS:
;  printf_stat_struct21, instats_all, source, siteID, orbit, level, file_unit
;
;  DESCRIPTION:
;  Prints the contents of a stats21ways structure and other passed parameters
;  needed to identify the statistical data values to a delimited text file of
;  a form suitable for loading into the 'gpmgv' database.  This version of
;  printf_stat_struct21* uses a stats21ways structure split out by underlying
;  surface type.
;
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-

pro printf_stat_struct21, instats_all, source, siteID, orbit, level, file_unit

for isfc = 0,2 do begin

  numpts = 0L

  CASE isfc OF
     0: BEGIN
           instats = instats_all.by_land
           numpts = instats_all.pts_land
           sftype = 'Land'
        END
     1: BEGIN
           instats = instats_all.by_sea
           numpts = instats_all.pts_sea
           sftype = 'Ocean'
        END
     2: BEGIN
           instats = instats_all.by_coast
           numpts = instats_all.pts_coast
           sftype = 'Coast'
        END
     ELSE:
  ENDCASE

  IF numpts GT 0L THEN BEGIN

  stats = instats.stats_total
  stratif = 'Total'
  fmtstr = '("' + sftype + '|' + source + '|' + stratif + '|",2(A0,"|"),f0.1,6("|",f0.5),"|",i0)'
  printf, file_unit, FORMAT = fmtstr, siteID, orbit, (level+1)*1.5, $
         stats.AvgDif, stats.StdDev, stats.PRmaxZ, stats.GVmaxZ, $
         stats.PRavgZ, stats.GVavgZ, stats.N

  stats = instats.stats_convbelow
  stratif = 'C_below'
  fmtstr = '("' + sftype + '|' + source + '|' + stratif + '|",2(A0,"|"),f0.1,6("|",f0.5),"|",i0)'
  printf, file_unit, FORMAT = fmtstr, siteID, orbit, (level+1)*1.5, $
         stats.AvgDif, stats.StdDev, stats.PRmaxZ, stats.GVmaxZ, $
         stats.PRavgZ, stats.GVavgZ, stats.N

  stats = instats.stats_convin
  stratif = 'C_in'
  fmtstr = '("' + sftype + '|' + source + '|' + stratif + '|",2(A0,"|"),f0.1,6("|",f0.5),"|",i0)'
  printf, file_unit, FORMAT = fmtstr, siteID, orbit, (level+1)*1.5, $
         stats.AvgDif, stats.StdDev, stats.PRmaxZ, stats.GVmaxZ, $
         stats.PRavgZ, stats.GVavgZ, stats.N

  stats = instats.stats_convabove
  stratif = 'C_above'
  fmtstr = '("' + sftype + '|' + source + '|' + stratif + '|",2(A0,"|"),f0.1,6("|",f0.5),"|",i0)'
  printf, file_unit, FORMAT = fmtstr, siteID, orbit, (level+1)*1.5, $
         stats.AvgDif, stats.StdDev, stats.PRmaxZ, stats.GVmaxZ, $
         stats.PRavgZ, stats.GVavgZ, stats.N

  stats = instats.stats_stratbelow
  stratif = 'S_below'
  fmtstr = '("' + sftype + '|' + source + '|' + stratif + '|",2(A0,"|"),f0.1,6("|",f0.5),"|",i0)'
  printf, file_unit, FORMAT = fmtstr, siteID, orbit, (level+1)*1.5, $
       stats.AvgDif, stats.StdDev, stats.PRmaxZ, stats.GVmaxZ, $
       stats.PRavgZ, stats.GVavgZ, stats.N

  stats = instats.stats_stratin
  stratif = 'S_in'
  fmtstr = '("' + sftype + '|' + source + '|' + stratif + '|",2(A0,"|"),f0.1,6("|",f0.5),"|",i0)'
  printf, file_unit, FORMAT = fmtstr, siteID, orbit, (level+1)*1.5, $
         stats.AvgDif, stats.StdDev, stats.PRmaxZ, stats.GVmaxZ, $
         stats.PRavgZ, stats.GVavgZ, stats.N

  stats = instats.stats_stratabove
  stratif = 'S_above'
  fmtstr = '("' + sftype + '|' + source + '|' + stratif + '|",2(A0,"|"),f0.1,6("|",f0.5),"|",i0)'
  printf, file_unit, FORMAT = fmtstr, siteID, orbit, (level+1)*1.5, $
         stats.AvgDif, stats.StdDev, stats.PRmaxZ, stats.GVmaxZ, $
         stats.PRavgZ, stats.GVavgZ, stats.N

  ENDIF

endfor

end
