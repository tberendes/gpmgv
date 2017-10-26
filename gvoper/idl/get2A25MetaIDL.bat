PRO_DIR = getenv("IDL_PRO_DIR")
cd, PRO_DIR
.compile getMetadata2A25.pro
cd, '/data/gpmgv/tmp'
getMetadata2A25
