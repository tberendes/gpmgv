#!/bin/sh
################################################################################
#
#  catalogQCradar.sh     Morris/SAIC/GPM GV     October 2006
#
#  DESCRIPTION
#    
#    Catalog the files uploaded by TRMM GV in the /data/gpmgv/gv_radar/finalQC_in
#    directory and load metadata for them into the PostGRESQL 'gpmgv' database
#    table 'gvradar'.
#
#  FILES
#   lsKXXXfinal_YYYY.new  (output; listing of current file pathnames in
#                          directory $DATA_DIR/gv_radar/finalQC_in/KXXX for
#                          year YYYY; XXX varies by radar site)
#   lsKXXXfinal_YYYY.old  (output; prior listing of file pathnames under
#                          directory above for year YYYY
#   lsKXXX_YYYY.diff  (output; difference between .new and .old files above;
#                      XXX varies by radar site)
#   finalQC_KxxxMeta.unl  (output; delimited fields, stripped of headings)
#                     
#  DATABASE
#    Loads data into 'gvradartemp' (temporarily) and 'gvradar' (permanently)
#    tables in 'gpmgv' database.  Logic is contained in SQL commands in file
#    catalogQCradar.sql, run in PostGRESQL via call to psql utility.
#
#  LOGS
#    Output for day's script run logged to daily log file
#    catalogQCradar.YYMMDD.log in /data/logs directory.
#
#  CONSTRAINTS
#    - User under which script is run must have access privileges to PostGRESQL
#      database 'gpmgv', SELECT/INSERT privileges on table 'gvradar', and
#      SELECT/INSERT/DELETE privileges on table 'gvradartemp'.  Utility
#      'psql' must be in user's $PATH.
#
#  HISTORY
#    07/09/2010, Morris, GPM GV
#    - Replaced hard-wired pathnames under /data/tmp with $TMP_DIR for running
#      on ds1-gpmgv with different file paths.
#    03/20/2012, Morris, GPM GV
#    - Modified parsing of hour and minute for 1CUF files to retain minutes
#      rather than truncating to hour.
#    06/18/2012, Morris, GPM GV
#    - Added automatic configuration of GV_BASE_DIR and DATA_DIR based on user
#      and machine IDs.  Modified Postgresql process count error messages.
#    08/29/2012, Morris, GPM GV
#    - Added logic to dbfileprep() 1CUF case to handle new Dual-pol file naming
#      convention.
#    08/07/2013, Morris, GPM GV
#    - Added logic to dbfileprep() to check for proper filename patterns and to
#      ignore 'images' products.
#    09/03/2013, Morris, GPM GV
#    - Added a "_YYYY" component to the lsKXXXfinal.* files to make them
#      year-specific to avoid huge 'diff' listings at year changeover.
#    11/08/13, Morris, GPM GV
#    - Changed redirect to DB_LOG_FILE from "| tee" to ">" to properly capture
#      psql ERROR messages.
#    01/16/14, Morris, GPM GV
#    - Fixing bug in years loop that excluded the first year from the difference
#      evaluations and loadfile preparations.
#    03/25/14, Morris, GPM GV
#    - Adding 'raw' file type to those cataloged in this script now that these
#      are included under the finalQC_in directory tree, and added new one-off
#      patterns for KING and KWAJ raw files.
#    August 2014   - Morris/SAIC/GPM GV
#    - Changed LOG_DIR to /data/logs and TMP_DIR to /data/tmp
#    September 2014   - Morris/SAIC/GPM GV
#    - Modified UF file pattern for dual-pol to include _rhi as optional file
#      name component for RHI volume scan mode.
#    November 2015   - Morris/SAIC/GPM GV
#    - Added Brazil radars file pattern to 1CUF and raw cases in dbfileprep().
#    January 2016 - Morris/SAIC/GPM GV - Added missing Brazil radar ID: JG1.
#    February 2016 - Morris/SAIC/GPM GV - Added missing Brazil radar ID: SF1.
#    October 2017 - Morris/SAIC/GPM GV - Allowing NPOL IDs from NPOL1 to NPOL9,
#                                        not just NPOL1.
#    May 2018 - Berendes - added .cf pattern to filenames
#    Sept 2018 - Berendes - added matching block for Reunion data
#
################################################################################

USER_ID=`whoami`
case $USER_ID in
  morris ) GV_BASE_DIR=/home/morris/swdev ;;
  gvoper ) GV_BASE_DIR=/home/gvoper ;;
       * ) echo "User unknown, can't set GV_BASE_DIR!"
           exit 1 ;;
esac
echo "GV_BASE_DIR: $GV_BASE_DIR"

MACHINE=`hostname | cut -c1-3`
case $MACHINE in
  ds1 ) DATA_DIR=/data/gpmgv ;;
  ws1 ) DATA_DIR=/data ;;
    * ) echo "Host unknown, can't set DATA_DIR!"
        exit 1 ;;
esac
export DATA_DIR
echo "DATA_DIR: $DATA_DIR"

TMP_DIR=/data/tmp
QCDATADIR=${DATA_DIR}/gv_radar/finalQC_in
BIN_DIR=${GV_BASE_DIR}/scripts
PATH=${PATH}:${BIN_DIR}
LOG_DIR=/data/logs

SQL_BIN=${BIN_DIR}/catalogQCradar.sql
loadfile=${TMP_DIR}/finalQC_KxxxMeta.unl  # must be that same as in catalogQCradar.sql

rundate=`date -u +%y%m%d`
LOG_FILE=${LOG_DIR}/catalogQCradar.${rundate}.log
DB_LOG_FILE=${LOG_DIR}/catalogQCradarSQL.log
runtime=`date -u`

umask 0002

echo "=====================================================" | tee $LOG_FILE
echo " Catalog any new TRMM GVS final QC radar files as of " | tee -a $LOG_FILE
echo "        $runtime" | tee -a $LOG_FILE
echo "-----------------------------------------------------" | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE

pgproccount=`ps -ef | grep postgres | grep -v grep | wc -l`

if [ ${pgproccount} -lt 5 ]
  then
    echo "Message from catalogQCradar.sh cron job on ${runtime}:" \
      > /tmp/PG_MAIL_ERROR_MSG.txt
    echo "" >> /tmp/PG_MAIL_ERROR_MSG.txt
    echo "${pgproccount} Postgres processes active, should be 5 !!" \
      >> /tmp/PG_MAIL_ERROR_MSG.txt
    echo "NEED TO RESTART POSTGRESQL ON ${HOST}." >> /tmp/PG_MAIL_ERROR_MSG.txt
    mailx -s 'postgresql down on ds1-gpmgv' makofski@radar.gsfc.nasa.gov \
      -c todd.a.berendes@nasa.gov,denise.a.berendes@nasa.gov < /tmp/PG_MAIL_ERROR_MSG.txt
    cat /tmp/PG_MAIL_ERROR_MSG.txt | tee -a $LOG_FILE
    exit 1
  else
    echo "${pgproccount} Postgres processes active, should be 5." \
      | tee -a $LOG_FILE
    echo "" | tee -a $LOG_FILE
fi
#exit  #uncomment for just testing e-mail notifications

################################################################################
function dbfileprep() {

# function formats file metadata into delimited text file, for loading into
# table 'gvradartemp' in 'gpmgv' database.  Takes 3 args: full file pathname,
# radar ID, and name of delimited text file to write output into

type=`echo $1 | cut -f1 -d'/'`
#echo "orig_type = $type"
pathless=`echo $1 | cut -f4 -d'/'`
sitepath=`echo $1 | cut -f1-3 -d'/'`
if [ "$type" = "level_2" ]
  then
     if [ $pathless = "options" ]
       then
         echo "Skipping file $1"
	 return
     fi
     type=`echo $pathless | cut -c1-4`
     year=`echo $1 | cut -f2 -d'/'`
     mmdd=`echo $pathless | cut -f2 -d'.' | cut -c3-6 | awk '{print \
           substr($1,1,2)"-"substr($1,3,2)}'`
     datestr=${year}'-'${mmdd}
  else
     datestr=`echo $1 | cut -f2-3 -d'/' | awk '{print \
              substr($1,1,4)"-"substr($1,6,2)"-"substr($1,8,2)}'`
fi
#echo "datatype = $type"
#echo "datestr = $datestr"
# nominal hour value in filename for 1CUF,1C51,2A54,2A55 runs from 1-24,
# convert to 00:00 to 23:00 for loading in database
case $type in
                1CUF )  echo $pathless | grep '_' > /dev/null
                        if [ $? = 0 ]
                          then
                            echo "Catalog DP file: $pathless"
                            # check the file pattern
                            echo $pathless | egrep '[A-Z]{4}_[0-9]{4}_[0-9]{4}_[0-9]{6}(_rhi)*\.(uf|cf|nc).*' > /dev/null
                            if [ $? = 1 ]
                              then
                                case $2 in
#  this needs to go in the "legacy" section since filename doesn't have 4 char pattern to start
#                                   Reunion )
#                                         # check the file pattern
#                                          echo $pathless | egrep 'Reunion_[0-9]{4}_[0-9]{4}_[0-9]{6}(_rhi)*\.(uf|cf)*' > /dev/null
#                                          if [ $? = 1 ]
#                                            then
#                                              echo "Bad Reunion filename: $pathless"
#                                              return
#                                            else
#                                              dtime=`echo $pathless | cut -f4 -d'_' | awk '{print \
#                                                     substr($1,1,2)":"substr($1,3,2)}'`
#                                          fi ;;
                                   NPOL )
                                         # check the file pattern
                                          echo $pathless | egrep '(npol|NPOL)[1-9]_[0-9]{4}_[0-9]{4}_[0-9]{6}(_rhi)*\.(uf|cf)*' > /dev/null
                                          if [ $? = 1 ]
                                            then
                                              echo "Bad NPOL DP 1CUF filename: $pathless"
                                              return
                                            else
                                              dtime=`echo $pathless | cut -f4 -d'_' | awk '{print \
                                                     substr($1,1,2)":"substr($1,3,2)}'`
                                          fi ;;
                                   DARW )
                                         # check the file pattern for CPol, only take those with "_PPI"
                                         #echo $pathless | egrep 'CPol+[_a-z]*[_0-9]*_PPI.(UF|CF).*' > /dev/null
                                         echo $pathless | egrep 'CPOL_[0-9]{4}_[0-9]{4}_[0-9]{6}.nc*' > /dev/null
                                         if [ $? = 1 ]
                                           then
                                             echo "Bad DARW (CPol) 1CUF filename: $pathless"
                                             return
                                           else
                                             #dtime=`echo $pathless | cut -f5 -d'_' | awk '{print \
                                             #       substr($1,1,2)":"substr($1,3,2)}'`
                                             dtime=`echo $pathless | cut -f4 -d'_' | awk '{print \
                                                    substr($1,1,2)":"substr($1,3,2)}'`
                                         fi ;;
                                    CP2 )
                                         # check the file pattern for CPol, only take those with "_PPI"
                                         echo $pathless | egrep 'CP2+[_a-z]*[_0-9]*_PPI.(UF|CF).*' > /dev/null
                                         if [ $? = 1 ]
                                           then
                                             echo "Bad CP2 (Brisbane) 1CUF filename: $pathless"
                                             return
                                           else
                                             dtime=`echo $pathless | cut -f5 -d'_' | awk '{print \
                                                    substr($1,1,2)":"substr($1,3,2)}'`
                                         fi ;;
AL1 | JG1 | MC1 | NT1 | PE1 | SF1 | ST1 | SV1 | TM1 )
                                         # check the file pattern for Brazil radars
                                         echo $pathless | egrep '[A-Z]{2}1_[0-9]{4}_[0-9]{4}_[0-9]{6}\.(uf|cf).*' > /dev/null
                                         if [ $? = 1 ]
                                           then
                                             echo "Bad BrazilRadars filename: $pathless"
                                             return
                                           else
                                             dtime=`echo $pathless | cut -f4 -d'_' | awk '{print \
                                                    substr($1,1,2)":"substr($1,3,2)}'`
                                         fi ;;
                                      * )
                                         echo "Bad/unrecognized $2 1CUF filename: $pathless"
                                         return ;;
                                esac
                              else
                                dtime=`echo $pathless | cut -f4 -d'_' | awk '{print \
                                       substr($1,1,2)":"substr($1,3,2)}'`
                            fi
                          else
                            echo "Catalog legacy 1CUF file: $pathless"
                            # check the file pattern
                            echo $pathless | egrep '[0-9]{6}\.[0-9][0-9]?\.[A-Z]{4}\.[0-9]\.[0-9]{4}\.(uf|cf).*' > /dev/null
                            if [ $? = 1 ]
                              then
                                echo "Bad legacy 1CUF filename: $pathless"
                                return
                              else
                                dtime=`echo $pathless | cut -f5 -d'.' | awk '{print \
                                       substr($1,1,2)":"substr($1,3,2)}'`
                            fi
                        fi ;;
  2A53 | 2A54 | 2A55 | 1C51 ) echo $pathless | \
                                egrep '(2A5[3-5]|1C51)\.[0-9]{6}\.[0-9][0-9]?\.[A-Z]{4}\.[0-9]\.HDF*' > /dev/null
                              if [ $? = 1 ]
                                then
                                  echo "Bad 2A5x or 1C51 filename: $pathless"
                                  return
                                else
                                  dtime=`echo $pathless | cut -f3 -d'.'`
		                  dtime=`expr $dtime - 1`
			          dtime=${dtime}":00"
                              fi ;;
#              images )  echo $pathless | grep 'gif' > /dev/null
#                        if [ $? = 0 ]
#                          then
#                            echo "Catalog GIF file: $pathless"
#                            dtime=`echo $pathless | cut -f2 -d'.' | awk '{print \
#                               substr($1,1,2)":"substr($1,3,2)}'`
#                          else
#                            echo "Catalog PNG file: $pathless"
#                            dtime=`echo $pathless | cut -f4 -d'_' | awk '{print \
#                                   substr($1,1,2)":"substr($1,3,2)}'`
#                        fi ;;
		 raw )  case $2 in
                           KING ) echo $pathless | grep '_' > /dev/null
                                  if [ $? = 0 ]
                                    then
                                      # have the full-volume file like WKR_201403122050_CONVOL.iri.gz
                                      echo $pathless | egrep 'WKR_[0-9]{12}_CONVOL\.**' > /dev/null
                                      if [ $? = 1 ]
                                        then
                                          echo "Bad raw KING filename: $pathless"
                                          return
                                        else
                                          dtime=`echo $pathless | cut -c13-16 | awk '{print \
                                            substr($1,1,2)":"substr($1,3,2)":00"}'`
                                      fi
                                    else
                                      # have the RHI file like WKR140312204431.RAWBWZY.gz
                                      echo "Ignoring file $1 in cataloging procedure."
                                      return
                                  fi ;;
                           KWAJ ) echo $pathless | egrep 'KWA[0-9]{12}\.RAW[0-9|A-Z]{4}\.**' > /dev/null
                                  if [ $? = 1 ]
                                    then
                                      echo "Bad raw KWAJ filename: $pathless"
                                      return
                                    else
                                      dtime=`echo $pathless | cut -c10-15 | awk '{print \
                                        substr($1,1,2)":"substr($1,3,2)":"substr($1,5,2)}'`
                                  fi ;;
AL1 | JG1 | MC1 | NT1 | PE1 | ST1 | SV1 | TM1 ) echo "Ignoring raw Brazil file: $pathless"
                                          return ;;
                              * ) echo $pathless | egrep '[A-Z]{4}[0-9]{8}_[0-9]{6}\.*' > /dev/null
                                  # check the file pattern
                                  if [ $? = 1 ]
                                    then
                                      echo "Bad raw (Archive Level II) filename: $pathless"
                                      return
                                    else
                                      dtime=`echo $pathless | cut -f2 -d'_' | awk '{print \
                                        substr($1,1,2)":"substr($1,3,2)":"substr($1,5,2)}'`
                                  fi ;;
                        esac ;;
                   * )  return ;;
esac

# add preceding zero to hour if needed.  First cut hh out of hh or hh:mm string
dthr=`echo $dtime | cut -f1 -d':'`
# if hh < 10 AND length_of_hh_string = 1 THEN PREPEND '0' to timestring
if [ `expr $dthr \< 10` = 1  -a  ${#dthr} = 1  ]
  then
     dtime='0'$dtime
fi

dtimestr=${datestr}' '${dtime}"+00"
echo "${type}|$2|${dtimestr}|${sitepath}|${pathless}" >> $3
return
}
################################################################################

# Begin script

rm -v $loadfile

# get today's YYYYMMDD, extract year
ymd=`date -u +%Y%m%d`
yend=`echo $ymd | cut -c1-4`

# get YYYYMMDD for 30 days ago, extract year
ymdstart=`offset_date $ymd -30`
ystart=`echo $ymdstart | cut -c1-4`

# after 30 days we will no longer try to catalog last year's files, 
# as $ystart will be the current year, the same as $yend
if [ "$ystart" != "$yend" ]
  then
    years="${ystart} ${yend}"
  else
    years=${yend}
fi

echo ""

for yr2do in $years
  do
    echo "Year to do = $yr2do" | tee -a $LOG_FILE
done

for Kxxx in `ls $QCDATADIR`
#for Kxxx in KTLH              # for testing, just do one site
  do
    echo "" | tee -a $LOG_FILE
    echo "<<<< Processing received files for site $Kxxx >>>>"\
      | tee -a $LOG_FILE

    cd $QCDATADIR/$Kxxx

# List the directory tree recursively.  If a directory, set $strip to the
# directory path.  If a regular file under directory $strip, then output the
# file pathname relative to current directory to a line in file $tmpfile

    for yr2do in $years
      do
        # MADE THESE LISTING FILES YEAR-SPECIFIC SO THAT WHEN WE QUIT LISTING
        # THE PRIOR YEAR WE DON'T GET ALL LAST YEAR'S FILES AS "NEW"

        # This file will hold a listing of files in tree at time of this run:
        tmpfile=${TMP_DIR}/ls${Kxxx}final_${yr2do}.new

        # This file holds the listing of files in tree at time of prior run:
        tmpfileold=${TMP_DIR}/ls${Kxxx}final_${yr2do}.old

        # This file will hold the 'diff tmpfile tmpfileold' command output:
        tmpfilediff=${TMP_DIR}/ls${Kxxx}final_${yr2do}.diff

        # Move last run's tmpfile (if any) to be the 'old' file
        if [ -f $tmpfile ]
          then
            echo ""
	    mv -fv $tmpfile $tmpfileold | tee -a $LOG_FILE 2>&1
	    echo "" | tee -a $LOG_FILE
        fi

        # Create empty 'old' file if no prior tmpfile:
        if [ ! -f $tmpfileold ]
          then
            touch $tmpfileold
        fi

        for file in `ls -R */$yr2do`
          do
            # a directory under which files or immediate subdirs are about
            # to be listed has a ':' at the end of the name, replace with '/'
            # and save for prepending to any regular files listed under it
            echo $file | grep ':' > /dev/null 2>&1
            if [ $? = 0 ]
              then
                # is a directory with files under it, prepare the path
                subdir=`echo $file | sed 's|:|/|'`
              else
                # is this a regular file or just a subdirectory?
                if [ -f ${subdir}${file} ]
                  then
                    # is regular file, add path and write to $tmpfile
                    echo ${subdir}${file} >> $tmpfile
                fi
            fi
        done

      # difference the old and new file listings to see what's been added to (or
      # unexpectedly removed from or changed in) the local directory tree since last
      # time script was run

          diff $tmpfileold $tmpfile | sed 's/^[<>] //' > $tmpfilediff
          additions='f'

      # walk thru the diff file and take action depending on filename or diff command
          for entry in `cat $tmpfilediff`
            do
              # skip divider lines in diff output
            	if [ "$entry" = "---" ]
                then
                  continue
              fi
	      # skip log_Kxxx.txt files in site root directory
            	echo $entry | grep "log_${Kxxx}.txt" > /dev/null 2>&1
	      if [ $? = 0 ]
                then
                  echo "Skipping log file $entry" | tee -a $LOG_FILE
	          continue
              fi
              echo $entry | grep "^[0-9][0-9]*a[0-9][0-9]*" > /dev/null 2>&1
              if [ $? = 0 ]
                then
                  echo "" | tee -a $LOG_FILE
	          echo "begin block of additions: $entry" | tee -a $LOG_FILE
	          additions='t'
                else
                  echo $entry | grep "^[0-9][0-9]*,*[0-9]*d[0-9][0-9]*"\
	             > /dev/null 2>&1
	          if [ $? = 0 ]
                    then
                      echo ""
	            	echo "UPLOAD ERROR? - begin block of deletions: $entry"\
	            	 | tee -a $LOG_FILE
	              additions='f'
	            else
	              # any more cases other than "c"hange in diff?  TBD
                      echo $entry | grep "^[0-9][0-9]*,*[0-9]*c[0-9][0-9]*"\
	                 > /dev/null 2>&1
	              if [ $? = 0 ]
                        then
                          echo ""
	            	    echo "UPLOAD ERROR? - begin block of changes: $entry"\
	            	     | tee -a $LOG_FILE
	                  additions='f'
	                else
	                  # Finally gets here if a file (i.e., not a 'diff' string)
		          file=`echo $entry`
	                  if [ "$additions" = 't' ]
	                    then
                              echo "Catalog new file:" | tee -a $LOG_FILE
		            	echo "$file" | tee -a $LOG_FILE
		              dbfileprep $file $Kxxx $loadfile | tee -a $LOG_FILE
	                    else
                              echo "Ignoring deleted/changed file:"\
                               | tee -a $LOG_FILE
		            	echo "$file" | tee -a $LOG_FILE
	                  fi
	              fi
	          fi
              fi
          done
    done
done

echo "" | tee -a $LOG_FILE

if [ -s $loadfile ]
  then
    echo "" | tee -a $LOG_FILE
    echo "Loading catalog of new files to database.  New file count:" | tee -a $LOG_FILE
    wc -l $loadfile | tee -a $LOG_FILE
    echo "" | tee -a $LOG_FILE
    cp -v $loadfile ${loadfile}.${rundate}.sav | tee -a $LOG_FILE 2>&1
    if [ -s $SQL_BIN ]
      then
        echo "\i $SQL_BIN" | psql -a -d gpmgv > $DB_LOG_FILE 2>&1
	if [ ! -s $DB_LOG_FILE ]
	  then
            echo "FATAL: SQL log file $DB_LOG_FILE empty or not found!"\
              | tee -a $LOG_FILE
	    echo "Saving catalog file:"
	    mv -v $loadfile ${loadfile}.${rundate}.sav | tee -a $LOG_FILE 2>&1
            exit 1
	fi
	cat $DB_LOG_FILE >> $LOG_FILE
	grep -i ERROR $DB_LOG_FILE > /dev/null
	if  [ $? = 0 ]
	  then
	    echo "Error loading file to database.  Saving catalog file:"\
	     | tee -a $LOG_FILE
	    mv -v $loadfile ${loadfile}.${rundate}.sav | tee -a $LOG_FILE 2>&1
	fi
      else
        echo "FATAL: SQL command file $SQL_BIN empty or not found!"\
          | tee -a $LOG_FILE
	echo "Saving catalog file:"
	mv -v $loadfile ${loadfile}.${rundate}.sav | tee -a $LOG_FILE 2>&1
        exit 1
    fi
  else
    echo "No new file catalog info to load to database for this run."\
     | tee -a $LOG_FILE
fi

echo "" | tee -a $LOG_FILE
echo "Script complete, exiting." | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE
exit
