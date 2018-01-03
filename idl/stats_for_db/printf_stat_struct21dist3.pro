;+
; Copyright © 2008, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
;  printf_stat_struct21dist3.pro   Morris/SAIC/GPM_GV      Nov 2007
;
;  SYNOPSIS:
;  printf_stat_struct21dist3, instats_all, percent, source, siteID, orbit,
;                             level, heights, file_unit
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
; 1/11/11  Morris/GPM GV/SAIC
; - Add heights as a passed parameter rather than computing via hard-coding.
; 9/10/2014  Morris/GPM GV/SAIC
; - Added option not to output lines where num. samples in category is zero.
;
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-

pro printf_stat_struct21dist3, instats_all, pctAbv, source, siteID, orbit, $
                               level, heights, file_unit, $
                               SUPRESS_ZERO=suppress_zero, DO_STDDEV=do_stddev

skipPrintZeroes=KEYWORD_SET(suppress_zero)
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
    IF ((stats.N EQ 0)+skipPrintZeroes) NE 2 THEN BEGIN 
      stratif = 'Total'
      fmtstr = fmtstrPre + stratif + fmtstrPost
      IF KEYWORD_SET(do_stddev) THEN BEGIN 
         PRmaxORstddev = stats.PRstddevZ
         GVmaxORstddev = stats.GVstddevZ
      ENDIF ELSE BEGIN
         PRmaxORstddev = stats.PRmaxZ
         GVmaxORstddev = stats.GVmaxZ
      ENDELSE
      printf, file_unit, FORMAT = fmtstr, pctAbv, rangecat, siteID, orbit, $
         heights[level], stats.AvgDif, stats.StdDev, PRmaxORstddev, GVmaxORstddev, $
         stats.PRavgZ, stats.GVavgZ, stats.GVabsmaxZ, stats.GVmaxstddevZ, stats.N
    ENDIF

    stats = instats.stats_convbelow
    IF ((stats.N EQ 0)+skipPrintZeroes) NE 2 THEN BEGIN 
      stratif = 'C_below'
      fmtstr = fmtstrPre + stratif + fmtstrPost
      IF KEYWORD_SET(do_stddev) THEN BEGIN 
         PRmaxORstddev = stats.PRstddevZ
         GVmaxORstddev = stats.GVstddevZ
      ENDIF ELSE BEGIN
         PRmaxORstddev = stats.PRmaxZ
         GVmaxORstddev = stats.GVmaxZ
      ENDELSE
      printf, file_unit, FORMAT = fmtstr, pctAbv, rangecat, siteID, orbit, $
         heights[level], stats.AvgDif, stats.StdDev, PRmaxORstddev, GVmaxORstddev, $
         stats.PRavgZ, stats.GVavgZ, stats.GVabsmaxZ, stats.GVmaxstddevZ, stats.N
    ENDIF

    stats = instats.stats_convin
    IF ((stats.N EQ 0)+skipPrintZeroes) NE 2 THEN BEGIN 
      stratif = 'C_in'
      fmtstr = fmtstrPre + stratif + fmtstrPost
      IF KEYWORD_SET(do_stddev) THEN BEGIN 
         PRmaxORstddev = stats.PRstddevZ
         GVmaxORstddev = stats.GVstddevZ
      ENDIF ELSE BEGIN
         PRmaxORstddev = stats.PRmaxZ
         GVmaxORstddev = stats.GVmaxZ
      ENDELSE
      printf, file_unit, FORMAT = fmtstr, pctAbv, rangecat, siteID, orbit, $
         heights[level], stats.AvgDif, stats.StdDev, PRmaxORstddev, GVmaxORstddev, $
         stats.PRavgZ, stats.GVavgZ, stats.GVabsmaxZ, stats.GVmaxstddevZ, stats.N
    ENDIF

    stats = instats.stats_convabove
    IF ((stats.N EQ 0)+skipPrintZeroes) NE 2 THEN BEGIN 
      stratif = 'C_above'
      fmtstr = fmtstrPre + stratif + fmtstrPost
      IF KEYWORD_SET(do_stddev) THEN BEGIN 
         PRmaxORstddev = stats.PRstddevZ
         GVmaxORstddev = stats.GVstddevZ
      ENDIF ELSE BEGIN
         PRmaxORstddev = stats.PRmaxZ
         GVmaxORstddev = stats.GVmaxZ
      ENDELSE
      printf, file_unit, FORMAT = fmtstr, pctAbv, rangecat, siteID, orbit, $
         heights[level], stats.AvgDif, stats.StdDev, PRmaxORstddev, GVmaxORstddev, $
         stats.PRavgZ, stats.GVavgZ, stats.GVabsmaxZ, stats.GVmaxstddevZ, stats.N
    ENDIF

    stats = instats.stats_stratbelow
    IF ((stats.N EQ 0)+skipPrintZeroes) NE 2 THEN BEGIN 
      stratif = 'S_below'
      fmtstr = fmtstrPre + stratif + fmtstrPost
      IF KEYWORD_SET(do_stddev) THEN BEGIN 
         PRmaxORstddev = stats.PRstddevZ
         GVmaxORstddev = stats.GVstddevZ
      ENDIF ELSE BEGIN
         PRmaxORstddev = stats.PRmaxZ
         GVmaxORstddev = stats.GVmaxZ
      ENDELSE
      printf, file_unit, FORMAT = fmtstr, pctAbv, rangecat, siteID, orbit, $
       heights[level], stats.AvgDif, stats.StdDev, PRmaxORstddev, GVmaxORstddev, $
       stats.PRavgZ, stats.GVavgZ, stats.GVabsmaxZ, stats.GVmaxstddevZ, stats.N
    ENDIF

    stats = instats.stats_stratin
    IF ((stats.N EQ 0)+skipPrintZeroes) NE 2 THEN BEGIN 
      stratif = 'S_in'
      fmtstr = fmtstrPre + stratif + fmtstrPost
      IF KEYWORD_SET(do_stddev) THEN BEGIN 
         PRmaxORstddev = stats.PRstddevZ
         GVmaxORstddev = stats.GVstddevZ
      ENDIF ELSE BEGIN
         PRmaxORstddev = stats.PRmaxZ
         GVmaxORstddev = stats.GVmaxZ
      ENDELSE
      printf, file_unit, FORMAT = fmtstr, pctAbv, rangecat, siteID, orbit, $
         heights[level], stats.AvgDif, stats.StdDev, PRmaxORstddev, GVmaxORstddev, $
         stats.PRavgZ, stats.GVavgZ, stats.GVabsmaxZ, stats.GVmaxstddevZ, stats.N
    ENDIF

    stats = instats.stats_stratabove
    IF ((stats.N EQ 0)+skipPrintZeroes) NE 2 THEN BEGIN 
      stratif = 'S_above'
      fmtstr = fmtstrPre + stratif + fmtstrPost
      IF KEYWORD_SET(do_stddev) THEN BEGIN 
         PRmaxORstddev = stats.PRstddevZ
         GVmaxORstddev = stats.GVstddevZ
      ENDIF ELSE BEGIN
         PRmaxORstddev = stats.PRmaxZ
         GVmaxORstddev = stats.GVmaxZ
      ENDELSE
      printf, file_unit, FORMAT = fmtstr, pctAbv, rangecat, siteID, orbit, $
         heights[level], stats.AvgDif, stats.StdDev, PRmaxORstddev, GVmaxORstddev, $
         stats.PRavgZ, stats.GVavgZ, stats.GVabsmaxZ, stats.GVmaxstddevZ, stats.N
    ENDIF

  ENDIF

endfor

end
