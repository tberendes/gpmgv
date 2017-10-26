PRO_DIR = getenv("IDL_PRO_DIR")
cd, PRO_DIR
.compile getMetadata2A23.pro
cd, '/data/gpmgv/tmp'
getMetadata2A23
