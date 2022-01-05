.compile polar2dpr_hs_fs_v7.pro
resolve_all
save, /routines, file='polar2dpr_hs_fs_v7.sav'
.compile dpr2gr_prematch_v7.pro
resolve_all
save, /routines, file='dpr2gr_prematch_v7.sav'
.compile polar2dprgmi_v7.pro
resolve_all
save, /routines, file='polar2dprgmi_v7.sav'
.compile polar2gmi_v7.pro
resolve_all
save, /routines, file='polar2gmi_v7.sav'
; rhi won't work with v7, hasn't been ported to 
;.compile rhi2dpr.pro
;resolve_all
;save, /routines, file='rhi2dpr.sav'
