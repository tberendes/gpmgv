.reset
FILES4NC = '/data/tmp/GMI_files_sites4geoMatch.140822.txt'
.compile polar2gmi.pro
polar2gmi, FILES4NC, 100, GPM_ROOT='/data/gpmgv/orbit_subset', DIRGV='/data/gpmgv/gv_radar/finalQC_in', NC_DIR='/tmp/matchups', plot_ppi=0, flat=0

.reset
FILES4NC = '/data/tmp/COMB_files_sites4geoMatch.150123.txt'
.compile polar2dprgmi.pro
polar2dprgmi, FILES4NC, 100, GPM_ROOT='/data/gpmgv/orbit_subset', DIRCOMB='/.', DIRGV='/data/gpmgv/gv_radar/finalQC_in', NC_DIR='/tmp/matchups', plot_ppis=0, flat=0

.reset
FILES4NC = '/data/tmp/DPR_files_sites4geoMatch.2ADPR.NS.V03B.150217.txt'
polar2dpr, FILES4NC, 100, SCORES=0, GPM_ROOT='/data/gpmgv/orbit_subset', DIRGV='/data/gpmgv/gv_radar/finalQC_in', PLOT_PPIS=0, NC_DIR='/tmp/matchups',DIRDPR='/.', DIRKU='/.', DIRKA='/.', DIRCOMB='/.', FLAT=0

.reset
FILES4NC = '/data/tmp/PR_files_sites4geoMatch.140512.txt'   ; GPM-era PR file paths
polar2pr, FILES4NC, 100, /SCORES, PR_ROOT='/data/gpmgv/orbit_subset', DIRGV='/data/gpmgv/gv_radar/finalQC_in', PLOT_PPIS=0, NC_DIR='/tmp/matchups', DIR1C='/.',DIR23='/.',DIR2A='/.', DIR2B='/.', FLAT=0

FILES4NC = '/data/tmp/PR_files_sites4geoMatch.140128.txt'   ; legacy PR file paths
polar2pr, FILES4NC, 100, /SCORES, PR_ROOT='/data/gpmgv/prsubsets', DIRGV='/data/gpmgv/gv_radar/finalQC_in', PLOT_PPIS=0, NC_DIR='/tmp/matchups', DIR1C='/1C21', DIR23='/2A23', DIR2A='/2A25', DIR2B='/2B31', FLAT=0
