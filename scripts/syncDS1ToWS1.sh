#!/bin/sh
LOG_DIR=/data/gpmgv/logs
ymd=`date -u +%Y%m%d`
LOG_FILE=$LOG_DIR/syncToWS1.${ymd}.log
THESERVER=ws1-gpmgv.gsfc.nasa.gov

echo "" | tee $LOG_FILE
echo "===================================================" | tee -a $LOG_FILE
echo "       Do source sync-up with ws1 on $ymd." | tee -a $LOG_FILE
echo "---------------------------------------------------" | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE


echo " do /swdev backups with rsync:" | tee -a $LOG_FILE

# sync the "scripts" directory, only the .sh and .sql files (DON'T REMOVE THE --ignore_existing
# DIRECTIVE SINCE DIFFERENCE FOR FILES FOUND ON BOTH SYSTEMS MAY BE JUST THAT THE PATHS IN THE
# SCRIPTS ARE CUSTOMIZED TO THE HOST!)

rsync -rtvni --ignore-existing --include="*.sh" --include="*.sql" --exclude="*"\
 ${THESERVER}:\/home/morris/swdev/scripts/ /home/morris/swdev/scripts | tee -a $LOG_FILE 2>&1

# sync the idl source directories down only one level from "cm_snapshot/dev" (--exclude="*/*/" --include="*/"),
# no directories beginning with "." (--exclude=".*")
# and only the .pro and .inc files (--include="*/*.pro" --include="*/*.inc" --exclude="*").
# 1) Order of the include and exclude directives is critical.
# 2) Must do an "svn export file:///home/morris/CM/dev" in /home/morris/swdev/idl/cm_snapshot on ws1-gpmgv first,
#    to get the latest CM version of the idl source code

##### RUN MANUALLY ON 2/3/2012 ######
#rsync -rtvi --exclude=".*" --exclude="*/*/" --include="*/" --include="*/*.pro" --include="*/*.inc" --exclude="*" ${THESERVER}:\/home/morris/swdev/idl/cm_snapshot/dev/ /home/morris/swdev/idl/dev | tee -a $LOG_FILE 2>&1

exit
