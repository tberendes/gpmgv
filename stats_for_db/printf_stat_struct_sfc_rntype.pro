;+
; Copyright © 2012, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
;  printf_stat_struct_sfc_rntype.pro   Morris/SAIC/GPM_GV      Dec 2012
;
;  SYNOPSIS:
;  printf_stat_struct_sfc_rntype, instats_all, source, version, orbit,
;                                 file_unit, SFCTYPE=sfctype, SUPPRESS=suppress
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
; 12/31/12  Morris/GPM GV/SAIC
; - Created from printf_stat_struct21dist3time.pro
;
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-

pro printf_stat_struct_sfc_rntype, instats, source, version, orbit, file_unit, $
                                   SFCTYPE=sfctype, SUPPRESS=suppress

    sfctype = 1 ;keyword_set(sfctype)
    suppress = 1 ;keyword_set(suppress)

    fmtstrPre = '("' + source  +  '|' 
    fmtstrPost = '",2("|",i0),6("|",f0.5),"|",i0)'

  
    stats = instats.stats_total
    stratif = 'Total'
    fmtstr = fmtstrPre + stratif + fmtstrPost
    IF ( suppress EQ 1 AND stats.N EQ 0 ) NE 1 THEN BEGIN
      printf, file_unit, FORMAT = fmtstr, version, orbit, $
         stats.AvgDif, stats.StdDev, stats.VAR1max, stats.VAR2max, $
         stats.VAR1avg, stats.VAR2avg, stats.N
    ENDIF

    stats = instats.stats_convocean
    IF ( suppress EQ 1 AND stats.N EQ 0 ) NE 1 THEN BEGIN
      IF (sfctype) THEN stratif = 'C_ocean' ELSE stratif = 'C_below'
      fmtstr = fmtstrPre + stratif + fmtstrPost
      printf, file_unit, FORMAT = fmtstr, version, orbit, $
         stats.AvgDif, stats.StdDev, stats.VAR1max, stats.VAR2max, $
         stats.VAR1avg, stats.VAR2avg, stats.N
    ENDIF

    stats = instats.stats_convland
    IF ( suppress EQ 1 AND stats.N EQ 0 ) NE 1 THEN BEGIN
      IF (sfctype) THEN stratif = 'C_land' ELSE stratif = 'C_in'
      fmtstr = fmtstrPre + stratif + fmtstrPost
      printf, file_unit, FORMAT = fmtstr, version, orbit, $
         stats.AvgDif, stats.StdDev, stats.VAR1max, stats.VAR2max, $
         stats.VAR1avg, stats.VAR2avg, stats.N
    ENDIF

    stats = instats.stats_convcoast
    IF ( suppress EQ 1 AND stats.N EQ 0 ) NE 1 THEN BEGIN
      IF (sfctype) THEN stratif = 'C_coast' ELSE stratif = 'C_above'
      fmtstr = fmtstrPre + stratif + fmtstrPost
      printf, file_unit, FORMAT = fmtstr, version, orbit, $
         stats.AvgDif, stats.StdDev, stats.VAR1max, stats.VAR2max, $
         stats.VAR1avg, stats.VAR2avg, stats.N
    ENDIF

    stats = instats.stats_stratocean
    IF ( suppress EQ 1 AND stats.N EQ 0 ) NE 1 THEN BEGIN
      IF (sfctype) THEN stratif = 'S_ocean' ELSE stratif = 'S_below'
      fmtstr = fmtstrPre + stratif + fmtstrPost
      printf, file_unit, FORMAT = fmtstr, version, orbit, $
         stats.AvgDif, stats.StdDev, stats.VAR1max, stats.VAR2max, $
         stats.VAR1avg, stats.VAR2avg, stats.N
    ENDIF

    stats = instats.stats_stratland
    IF ( suppress EQ 1 AND stats.N EQ 0 ) NE 1 THEN BEGIN
      IF (sfctype) THEN stratif = 'S_land' ELSE stratif = 'S_in'
      fmtstr = fmtstrPre + stratif + fmtstrPost
      printf, file_unit, FORMAT = fmtstr, version, orbit, $
         stats.AvgDif, stats.StdDev, stats.VAR1max, stats.VAR2max, $
         stats.VAR1avg, stats.VAR2avg, stats.N
    ENDIF

    stats = instats.stats_stratcoast
    IF ( suppress EQ 1 AND stats.N EQ 0 ) NE 1 THEN BEGIN
      IF (sfctype) THEN stratif = 'S_coast' ELSE stratif = 'S_above'
      fmtstr = fmtstrPre + stratif + fmtstrPost
      printf, file_unit, FORMAT = fmtstr, version, orbit, $
         stats.AvgDif, stats.StdDev, stats.VAR1max, stats.VAR2max, $
         stats.VAR1avg, stats.VAR2avg, stats.N
    ENDIF

end
