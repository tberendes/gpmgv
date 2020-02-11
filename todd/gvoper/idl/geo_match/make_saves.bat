.compile polar2dpr_hs_ms_ns.pro
resolve_all
save, /routines, file='polar2dpr_hs_ms_ns.sav'
.compile dpr2gr_prematch.pro
resolve_all
save, /routines, file='dpr2gr_prematch.sav'
.compile polar2dprgmi.pro
resolve_all
save, /routines, file='polar2dprgmi.sav'
