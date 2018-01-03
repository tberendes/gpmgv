#!/bin/sh
################################################################################
#
#  loadCTfiles.sh     Morris/SAIC/GPM GV     August 2006
#
#  DESCRIPTION
#    
#    Process the 'CT.yymmdd.6' files resident in the /data/coincidence_table
#    directory with CT_to_DB.sh and load into the PostGRESQL 'test' database
#    table 'ct_temp'.  Prompt user for each file to see whether to load or skip.
#
#  FILES
#   CT.yymmdd.6      (input; yymmdd varies by date)
#   CT.yymmdd.6.unl  (output; delimited fields, stripped of headings)
#                     
#  DATABASE
#    Loads data into 'ct_temp' table in 'gpmgv' database, run in
#    PostGRESQL via call to psql utility.
#
#  LOGS
#    Output for day's script run logged to daily log file
#    RidgeMosaicCTMatch.YYMMDD.log in data/logs subdirectory.
#
#  CONSTRAINTS
#    - User under which script is run must have access privileges to PostGRESQL
#    database 'gpmgv', and SELECT and DELETE privileges on tables.  Utility
#    'psql' must be in user's $PATH.
#
################################################################################
#        1         2         3         4         5         6         7         8
#2345678901234567890123456789012345678901234567890123456789012345678901234567890

GV_BASE_DIR=/home/morris/swdev
DATA_DIR=/data
CT_DATA=${DATA_DIR}/coincidence_table
BIN_DIR=${GV_BASE_DIR}/scripts
PATH=${PATH}:${BIN_DIR}

for ctfile in `ls ${CT_DATA}/CT.*.6`
  do
    ctunlfile=`echo $ctfile | sed 's/.6$/.unl/'`
    echo "Create and load $ctunlfile to DB? (y or n): "
    read -r goforit
    if [ "$goforit" = 'y' ]
      then
        ${BIN_DIR}/CT_to_DB.sh  $ctfile $ctunlfile
        echo "Load following .unl file from CT_to_DB.sh to database:"
        ls -al $ctunlfile
        echo ""
        echo "\copy ct_temp FROM '${ctunlfile}' WITH DELIMITER '|'" \
          | psql -a -d gpmgv
    else
        echo "Skip processing of $ctfile."
    fi
    echo ""
done

exit

