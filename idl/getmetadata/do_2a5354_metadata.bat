PRO_DIR = getenv("IDL_PRO_DIR")
cd, PRO_DIR
EVENTFILE = getenv("GVMETACONTROL")
DBOUTFILE = getenv("DBOUTFILE")
;.compile do_2a5354_metadata.pro
restore, file='do_2a5354_metadata.sav'
do_2a5354_metadata, EVENTFILE, DBOUTFILE
