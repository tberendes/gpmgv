#!/bin/sh

# Moves previously-downloaded PR product files in TRMM's directory structure
# into their respective baseline directories.

GV_BASE_DIR=/home/morris/swdev
DATA_DIR=/data
PR_DATA_DIR=${DATA_DIR}/prsubsets
TMP_DIR=${DATA_DIR}/TRMMGV_tmp
#LOG_DIR=${DATA_DIR}/logs
#BIN_DIR=${GV_BASE_DIR}/scripts
DIR_PRE="/TRMM_"
DIR_POST="_CSI_KWAJ/"

#rundate=`date -u +%y%m%d`

for type in 1C21 2A23 2A25 2B31
  do
    PRODUCT_DIR=${PR_DATA_DIR}/${type}
    cd ${TMP_DIR}${DIR_PRE}${type}${DIR_POST}
    for year in `ls`
      do
        cd $year
        for day in `ls`
          do
            cd $day
#            pwd
#            ls ${type}*.Z
#            echo "mv -v ${type}*.Z $PRODUCT_DIR"
            mv -v ${type}*.Z $PRODUCT_DIR
            cd ..
        done
        cd ..
    done
done
exit
