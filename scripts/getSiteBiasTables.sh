#!/bin/sh
###############################################################################
#
# getSiteBiasTables.sh    Morris/SAIC/GPM GV    Nov 2013
#
# DESCRIPTION:
# Queries the 'gpmgv' database tables 'zdiff_stats_by_dist_time_geov7' and
# zdiff_stats_by_dist_time_geo_s2kuv7 for each VN GV site and produces an
# HTML table of PR-GR mean bias by date for each site in a separate file.
#
# At this time, assumes that the tables have been populated with the latest
# stratified differences by external forces.
#
###############################################################################

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

TMP_DIR=${DATA_DIR}/tmp
LOG_DIR=${DATA_DIR}/logs
export LOG_DIR

rundate=`date -u +%y%m%d`
LOG_FILE=${LOG_DIR}/getSiteBiasTables.${rundate}.log
export LOG_FILE
BIN_DIR=${GV_BASE_DIR}/scripts
PATH=${PATH}:${BIN_DIR}
export BIN_DIR
export PATH
quote="'"

umask 0002

echo "Starting site bias table generation on $rundate." | tee $LOG_FILE
echo "========================================================"\
 | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE

# re-used file to hold output from database queries
DBTEMPFILE=${TMP_DIR}/getSiteBiasTables_dbtempfile
#
SITES=`psql -A -t -d gpmgv -c "select distinct radar_id from zdiff_stats_by_dist_time_geov7;"`

for SITE in `echo $SITES`
  do
    echo $SITE
    if [ -s  ${DBTEMPFILE} ] ; then rm -fv ${DBTEMPFILE} ; fi
#    echo "select a.radar_id as site, \
#    date_trunc('day',b.overpass_time at time zone 'UTC') as date, \
#    round((sum(meandiff*numpts)/sum(numpts))*100)/100 as pr_gr_diff, \
#    sum(numpts) as total from zdiff_stats_by_dist_time_geov7 a, overpass_event b \
#    where regime='S_above' and numpts>25 and a.orbit=b.orbit \
#    and a.radar_id=b.radar_id and a.radar_id = ${quote}${SITE}${quote} \
#    and percent_of_bins=100 group by 1,2 order by 1,2;" | psql gpmgv
    echo "select a.radar_id as site, \
      date_trunc('day',b.overpass_time at time zone 'UTC') as date, \
      round((sum(meandiff*numpts)/sum(numpts))*100)/100 as pr_gr_diff, \
      sum(numpts) as total, TEXT 'No' as dualpol into temp tempdiffstemp \
      from zdiff_stats_by_dist_time_geov7 a, overpass_event b, rainy100inside100 c \
      where regime='S_above' and numpts>0 \
      and a.orbit=b.orbit and a.orbit=c.orbit and a.radar_id=b.radar_id and \
      a.radar_id=c.radar_id and (pct_overlap_strat/100.)*num_overlap_rain_certain > 200 \
      and (pct_overlap_strat/10)>pct_overlap_conv and a.radar_id = ${quote}${SITE}${quote} \
      and percent_of_bins=100 group by 1,2 order by 1,2; \
      UPDATE tempdiffstemp set dualpol = 'Yes' where DATE(date) >= \
      (SELECT activation from dualpol_active where radar_id = ${quote}${SITE}${quote});
      \H \o ${DBTEMPFILE} \\\SELECT * from tempdiffstemp;" | psql gpmgv

    # reformat the headings and get rid of the "NN rows" line at the end,
    # and write to date-stamped html file
    if [ -s ${DBTEMPFILE} ]
      then
        fileout=${TMP_DIR}/${SITE}_Diffs_${rundate}.html
        cat $DBTEMPFILE | sed 's/site/ GV Site /' | sed 's/date/ Date /' \
         | sed 's/pr_gr_diff/ Mean PR-GR /' | sed 's/total/ Total /' \
         | sed 's/dualpol/Dual-Pol?/' | sed 's/ 00:00:00//' | grep -v 'p>' > $fileout
        rm -fv ${DBTEMPFILE}
        echo "Copying ${fileout} to hector"
        scp ${fileout} hector.gsfc.nasa.gov:/gvraid/ftp/gpm-validation/BiasInHTML
    fi
done

exit
