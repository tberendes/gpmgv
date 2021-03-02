.compile polar2dpr_hs_ms_ns_v6.pro
resolve_all
save, /routines, file='polar2dpr_hs_ms_ns_v6.sav'
.compile dpr2gr_prematch_v6.pro
resolve_all
save, /routines, file='dpr2gr_prematch_v6.sav'
.compile polar2dprgmi_v6.pro
resolve_all
save, /routines, file='polar2dprgmi_v6.sav'
.compile polar2gmi.pro
resolve_all
save, /routines, file='polar2gmi.sav'
