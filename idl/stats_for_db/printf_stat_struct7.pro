;+
; Copyright © 2008, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
;  printf_stat_struct.pro   Morris/SAIC/GPM_GV      May 2007
;
;  SYNOPSIS:
;  printf_stat_struct, instats, source, siteID, orbit, level, file_unit
;
;  DESCRIPTION:
;  Prints the contents of a stats7ways structure and other passed parameters
;  needed to identify the statistical data values to a delimited text file of
;  a form suitable for loading into the 'gpmgv' database.
;
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-

pro printf_stat_struct7, instats, source, siteID, orbit, level, file_unit

stats = instats.stats_total
stratif = 'Total'
fmtstr = '("' + source + '|' + stratif + '|",2(A0,"|"),f0.1,6("|",f0.5),"|",i0)'
printf, file_unit, FORMAT = fmtstr, siteID, orbit, (level+1)*1.5, $
       stats.AvgDif, stats.StdDev, stats.PRmaxZ, stats.GVmaxZ, $
       stats.PRavgZ, stats.GVavgZ, stats.N

stats = instats.stats_convbelow
stratif = 'C_below'
fmtstr = '("' + source + '|' + stratif + '|",2(A0,"|"),f0.1,6("|",f0.5),"|",i0)'
printf, file_unit, FORMAT = fmtstr, siteID, orbit, (level+1)*1.5, $
       stats.AvgDif, stats.StdDev, stats.PRmaxZ, stats.GVmaxZ, $
       stats.PRavgZ, stats.GVavgZ, stats.N

stats = instats.stats_convin
stratif = 'C_in'
fmtstr = '("' + source + '|' + stratif + '|",2(A0,"|"),f0.1,6("|",f0.5),"|",i0)'
printf, file_unit, FORMAT = fmtstr, siteID, orbit, (level+1)*1.5, $
       stats.AvgDif, stats.StdDev, stats.PRmaxZ, stats.GVmaxZ, $
       stats.PRavgZ, stats.GVavgZ, stats.N

stats = instats.stats_convabove
stratif = 'C_above'
fmtstr = '("' + source + '|' + stratif + '|",2(A0,"|"),f0.1,6("|",f0.5),"|",i0)'
printf, file_unit, FORMAT = fmtstr, siteID, orbit, (level+1)*1.5, $
       stats.AvgDif, stats.StdDev, stats.PRmaxZ, stats.GVmaxZ, $
       stats.PRavgZ, stats.GVavgZ, stats.N

stats = instats.stats_stratbelow
stratif = 'S_below'
fmtstr = '("' + source + '|' + stratif + '|",2(A0,"|"),f0.1,6("|",f0.5),"|",i0)'
printf, file_unit, FORMAT = fmtstr, siteID, orbit, (level+1)*1.5, $
       stats.AvgDif, stats.StdDev, stats.PRmaxZ, stats.GVmaxZ, $
       stats.PRavgZ, stats.GVavgZ, stats.N

stats = instats.stats_stratin
stratif = 'S_in'
fmtstr = '("' + source + '|' + stratif + '|",2(A0,"|"),f0.1,6("|",f0.5),"|",i0)'
printf, file_unit, FORMAT = fmtstr, siteID, orbit, (level+1)*1.5, $
       stats.AvgDif, stats.StdDev, stats.PRmaxZ, stats.GVmaxZ, $
       stats.PRavgZ, stats.GVavgZ, stats.N

stats = instats.stats_stratabove
stratif = 'S_above'
fmtstr = '("' + source + '|' + stratif + '|",2(A0,"|"),f0.1,6("|",f0.5),"|",i0)'
printf, file_unit, FORMAT = fmtstr, siteID, orbit, (level+1)*1.5, $
       stats.AvgDif, stats.StdDev, stats.PRmaxZ, stats.GVmaxZ, $
       stats.PRavgZ, stats.GVavgZ, stats.N

end
