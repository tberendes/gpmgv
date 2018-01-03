geo_match_3d_comparisons, ANALYSIS_TYPE='DSD',  MATCHUP_TYPE='DPR', $
   SWATH_CMB=swath_cmb,  KUKA_CMB=KuKa_cmb, $
   SPEED=looprate,  ELEVS2SHOW=1.3, $
   NCPATH='/data/gpmgv/netcdf/geo_match/GPM/2ADPR/NS/V05A/1_21/2014', $
   SITE='K*', $
   NCFILELIST=ncfilelist, $
   NO_PROMPT = 0, $
   PPI_VERTICAL=ppi_vertical,  PPI_SIZE=ppi_size, $
   PCT_ABV_THRESH=90, $
   DPR_Z_ADJUST=dpr_z_adjust_in,  GR_Z_ADJUST=gr_z_adjust, $
   MAX_RANGE=max_range_in, $
   MAX_BLOCKAGE=10,   Z_BLOCKAGE_THRESH=z_blockage_thresh_in, $
   SHOW_THRESH_PPI=show_thresh_ppi,  Z_ONLY_PPI=z_only_ppi, $
   GV_CONVECTIVE=gv_convective, GV_STRATIFORM=gv_stratiform, $
   ALT_BB_HGT='/data/tmp/GPM_rain_event_bb_km.txt',  FORCEBB=forcebb, $
   HIDE_TOTALS=1,  HIDE_RNTYPE=1,  HIDE_PPIS=1, $
;   PS_DIR='/data/gpmgv/xfer/V4_V5_stuff',  B_W = 0,  BATCH = 1, $
   S2KU = 1, $
   USE_ZR = 0, $
   DZERO_ADJ = dzero_adj, $
   GR_RR_FIELD = 'RR',  GR_DM_FIELD = 'DM',  GR_NW_FIELD = 'N2', $
   RECALL_NCPATH = 1, $
   SUBSET_METHOD = subset_method,  MIN_FOR_SUBSET = min_for_subset, $
   SAVE_DIR = save_dir,  SAVE_BY_RAY = 0, $
   STEP_MANUAL = 0, $
   DECLUTTER = 0, $
   LAND_OCEAN = land_ocean_in

; swath_cmb    - designates which swath (scan type) to analyze for the DPRGMI
;                matchup type.  Allowable values are 'MS' and 'NS' (default).
;
; KuKa_cmb     - designates which DPR instrument's data to analyze for the
;                DPRGMI matchup type.  Allowable values are 'Ku' and 'Ka'  If
;                swath_cmb is 'NS' then KuKa_cmb must be 'Ku'.  If unspecified
;                or if in conflict with with swath_cmb then the value will be
;                assigned to 'Ku' by default.
;
; analysis_type - indicates which type of data variables to be analyzed: Z (for
;                 reflectivity, 'RR' (for rain rate), or 'DSD' (DSD paramaters).
;
; matchup_type - indicates which satellite radar is to be the source of the
;                matchup data to be analyzed.  Allowable values are 'DPR'
;                and 'DPRGMI' or 'CMB'.  Default='DPR'. 'CMB' is an alias for 'DPRGMI'.
;
; land_ocean_in - (Optional) STRING parameter, limits the samples included in
;                 the analysis to those with a single underlying surface type.
;                 Allowable values are 'L' (Land), 'O' (Ocean), 'C' (Coast), 
;                 'I' (Inland Water), or 'A' (Any - disables filtering).

