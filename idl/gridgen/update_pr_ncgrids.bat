PRO_DIR = getenv("IDL_PRO_DIR")
cd, PRO_DIR
cd, '..'
DATESTAMP = GETENV("RUNDATE")
FILES4NC = GETENV("GETMYGRIDS")
update_pr_ncgrids, DATESTAMP, FILES4NC
