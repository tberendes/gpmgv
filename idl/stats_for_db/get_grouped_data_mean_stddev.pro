;+
; Copyright © 2014, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
;  get_grouped_data_mean_stddev.pro   Morris/SAIC/GPM_GV      September 2014
;
;  SYNOPSIS:
;  get_grouped_data_mean_stddev, distrib, bindbz, bindbzsq, meanz, numz
;
;
;  DESCRIPTION
;  -----------
;  Takes cumulative histograms of data values (Z), and the original and square
;  of the histogram bin values, and computes the grouped data mean and standard
;  deviation of the input data.  See accum_histograms_by_raintype.pro and
;  stats_by_dist_to_dbfile_dpr_pr_geo_match.pro for how the grouped data
;  histograms are computed.
;
;  PARAMETERS
;  ----------
;  distrib   - Histogram of frequency of occurrence of values defined by bindbz (INPUT)
;  bindbz    - Bin values into which data have been grouped/histogrammed (INPUT)
;  bindbzsq  - Square of bindbz, precomputed by caller for multiple calls (INPUT)
;  mean      - Computed mean value of the grouped data (I/O, optional)
;  numz      - Number of samples in the complete histogram distribution (I/O,
;              optional)
;
;  RETURNS
;  -------
;  stddev    - Computed POPULATION Standard Deviation of the grouped data
;
;  HISTORY
;  -------
;  09/16/2014  Morris/GPM GV/SAIC
;  - Created.
;
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-

FUNCTION get_grouped_data_mean_stddev, distrib, bindbz, bindbzsq, meanz, numz

   IF N_PARAMS() NE 3 AND N_PARAMS() NE 5 THEN message, "Incorrect # parameters"
   IF N_ELEMENTS(distrib) NE N_ELEMENTS(bindbz) $
      OR N_ELEMENTS(distrib) NE N_ELEMENTS(bindbzsq) $
      THEN message, "Mismatched input array sizes"

   N = TOTAL(distrib)        ; total number of samples tallied in histogram
   Sxf = TOTAL(distrib*bindbz)  ; sum of Z value times its frequency
   Sx2f = TOTAL(distrib*bindbzsq)  ; sum of Z value squared times frequency
   stddev = SQRT( (Sx2f - (Sxf^2 / N)) / N )
   IF N_PARAMS() EQ 5 THEN BEGIN
      meanz = Sxf/N
      numz = N
   ENDIF
   return, stddev

END
