pro wrap_pr_and_geo_match_x_sections

;SETENV, 'NCPATH=/data/netcdf/geo_match'
;SETENV, 'PRPATH=/data/prsubsets'
;SETENV, 'NO_PROMPT=1'
;SETENV, 'SITE=KWAJ'
;SETENV, 'USE_DB=1'

ncpath = GETENV("NCPATH")
print, 'ncpath: ', ncpath
prpath = GETENV("PRPATH")
print, 'prpath: ', prpath
no_prompt = FIX(GETENV("NO_PROMPT"))
print, 'no_prompt: ', no_prompt
sitefilter = GETENV("SITE")
print, 'sitefilter: ', sitefilter
use_db = FIX(GETENV("USE_DB"))
print, 'use_db: ', use_db

pr_and_geo_match_x_sections, SITE=sitefilter, NO_PROMPT=no_prompt, $
                             NCPATH=ncpath, PRPATH=prpath, USE_DB=use_db

end
