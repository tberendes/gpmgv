.compile polar2dpr_hs_ms_ns_v7.pro
resolve_all
save, /routines, file='polar2dpr_hs_ms_ns_v7.sav'
.compile dpr2gr_prematch_v7.pro
resolve_all
save, /routines, file='dpr2gr_prematch_v7.sav'
.compile polar2dprgmi_v7.pro
resolve_all
save, /routines, file='polar2dprgmi_v7.sav'
;.compile polar2gmi.pro
;resolve_all
;save, /routines, file='polar2gmi.sav'
;.compile rhi2dpr.pro
;resolve_all
;save, /routines, file='rhi2dpr.sav'
