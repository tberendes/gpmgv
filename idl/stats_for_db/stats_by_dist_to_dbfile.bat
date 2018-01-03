sitelist = ['KAMX', 'KBMX', 'KBRO', 'KBYX', 'KCLX', 'KCRP', 'KDGX', 'KEVX', $
            'KFWS', 'KGRK', 'KHGX', 'KHTX', 'KJAX', 'KJGX', 'KLCH', 'KLIX', $
            'KMLB', 'KMOB', 'KSHV', 'KTBW', 'KTLH']

instrument='DPR' & versions='V03B.DPR.NS.1_1.'
;instrument='PR' & versions='7.3_0.'
s2ku = 1
IF (s2ku) then s2txt = 'S2Ku' else s2txt = 'OrigS'
IF instrument EQ 'DPR' THEN altbb='/data/tmp/GPM_rain_event_bb_km.txt'
bbrel=0

stats_by_dist_to_dbfile_dpr_pr_geo_match, INSTRUMENT=instrument, $
  PCT_ABV_THRESH=70, $
  GV_CONVECTIVE=0, $
  GV_STRATIFORM=0, $
  S2KU=s2ku, NAME_ADD='TRMMsitesRUCBB', $
  NCSITEPATH='/data/gpmgv/netcdf/geo_match/GRto'+instrument+'.K*.140*'+versions+'nc.gz', $
  SITELIST=sitelist, $
  OUTPATH='/data/tmp', $
  ALTFIELD=altfield, $
  BB_RELATIVE=bbrel, $
  DO_STDDEV=1, $
  PROFILE_SAVE='/data/tmp/GR_'+instrument+'_Profiles_'+s2txt+'_'+versions+'TRMMSitesRUCBB.txt', $
  ALT_BB_FILE=altbb
