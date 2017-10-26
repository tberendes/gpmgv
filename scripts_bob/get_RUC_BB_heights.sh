#!/bin/sh
###############################################################################
#
# get_RUC_BB_heights.sh    Morris/SAIC/GPM GV    November 2014
#
# Takes the data file /data/tmp/rain_event_nominalAPP.txt output from the
# database query in get_rainy_overpass_nominal_hour.sql, finds the
# RUC sounding text file matching the each radar site and nominal datetime
# listed in the file, computes the interpolated height of the 0 deg. C level
# for each event, and outputs the radar site, orbit number, and freezing
# height in a delimited text file 'rain_event_bbAPP.txt'.  If the first level
# is below freezing, assigns freezing level height of 0.0.
#
# Runs on hector.gsfc.nasa.gov.  See files rain_event_nominalAPP.txt (INPUT),
# rain_event_bbAPP.txt (OUTPUT)
#
# Sequence:
# 1) On ds1-gpmgv, cd /data/tmp, ll rain_event*, find the latest/largest
#    rain_event_nominal*.txt file (e.g., rain_event_nominal.150130.txt).
#
# 2) Find the latest orbit number (2nd data field) in this file by running:
#
#    cat rain_event_nominal.150130.txt | cut -f2 -d '|' | sort -nu
#
#    which cuts the orbit number field out of the file and sorts it in
#    ascending numerical order, eliminating the duplicate orbit numbers.
#    You should get the same result if you run this command against the file
#    GPM_rain_event_bb_km.txt.
#
# 3) Edit the orbit numbers in both SELECT statements in the UNION query in
#    get_rainy_overpass_nominal_hour.sql to return site/orbit/times after
#    the latest orbit from (2).
#
# 4) Run the edited query in get_rainy_overpass_nominal_hour.sql under the psql
#    database utility.  Either start a 'psql gpmgv' session on the command line
#    and paste in the SQL command from the get_rainy_overpass_nominal_hour.sql
#    file, or (easier) run it from the unix prompt by entering the command:
#
#    psql -f get_rainy_overpass_nominal_hour.sql -d gpmgv
#
#    Check the timestamp and contents of the /data/tmp/rain_event_nominalAPP.txt
#    file output by the query to make sure it is new and lists orbits after the
#    one found and used in (2) and (3), above.  If it is OK, then ftp the
#    /data/tmp/rain_event_nominalAPP.txt to hector and, if needed, move it into
#    the /gvraid/ftp/gpm-validation directory.
#
# 5) Run <this> script on hector from the /gvraid/ftp/gpm-validation directory
#    where the file rain_event_nominalAPP.txt should now be located, as follows:
#
#  ./scripts/get_RUC_BB_heights.sh  rain_event_nominalAPP.txt  rain_event_bbAPP.txt
#
# 6) ftp the file /gvraid/ftp/gpm-validation directory/rain_event_bbAPP.txt to
#    the /data/tmp directory on ds1-gpmgv.
#
# 7) On ds1 in /data/tmp, cp the old datestamped rain_event_nominal.YYMMDD.txt
#    file to a current datestamped file, e.g. rain_event_nominal.150216.txt
#
# 8) append the new site/orbit/nominal data to the new datestamped file, e.g.:
#
#    cat rain_event_nominalAPP.txt >> rain_event_nominal.150216.txt
#
# 9) append the new site/orbit/BBhgt data to the GPM_rain_event_bb_km.txt file:
#
#    cat rain_event_bbAPP.txt >> GPM_rain_event_bb_km.txt
#
###############################################################################

SOUNDINGS_TOP_DIR=/gvraid/trmmgv/Soundings/RUC_Soundings/

siteTimesFile=$1
bbfile=$2
if [ -f $bbfile ]
  then
    rm -v $bbfile
fi

function findbblevel() {

  havebotm=0
  while read sndlevel
    do
      echo $sndlevel | grep '\.' > /dev/null
      if [ $? = 1 ]
        then
          continue
      fi
      hgttemp=`echo $sndlevel | grep '\.' | sed 's/  */ /g' | cut -f2-3 -d ' '`
      hgt=`echo $hgttemp | cut -f1 -d ' '`
      temp=`echo $hgttemp | cut -f2 -d ' '`
      echo $temp | grep '-' > /dev/null
      if [ $? = 1 ]
        then
          botmhgt=$hgt
          botmtemp=$temp
          havebotm=1
        else
          tophgt=$hgt
          toptemp=$temp
          break
      fi
  done < $1
  if [ $havebotm = 1 ]
    then
#      echo botmhgt, botmtemp, tophgt, toptemp: $botmhgt, $botmtemp, $tophgt, $toptemp
      dh=$(echo "scale = 4; $tophgt-$botmhgt" | bc)
      dt=$(echo "scale = 4; $toptemp-$botmtemp" | bc)
      bbHeight_km=$(echo "scale = 2; $tophgt - $toptemp * $dh / $dt" | bc)
      bbHeight=$(echo "scale = 2; $bbHeight_km / 1000.0" | bc)
    else
#      echo tophgt, toptemp: $tophgt, $toptemp
      bbHeight=$(echo "scale = 2; $tophgt / 1000.0" | bc)
  fi
#  echo bbHeight: $bbHeight
  local theHeight=$bbHeight
  echo "$theHeight"
  return
}

# begin main script

while read event
  do
    # parse the overpass event information to get needed fields
    site=`echo $event | cut -f1 -d '|'`
    #if [ $site != 'PAIH' ]
    #  then
    #    continue
    #fi
    orbit=`echo $event | cut -f2 -d '|'`
    year=`echo $event | cut -f3 -d '|' | cut -f1 -d '-'`
    mmdd=`echo $event | cut -f3 -d '|' | cut -f2-3 -d '-' | sed 's/-//' | cut -f1 -d' '`
    hh=`echo $event | cut -f2 -d ' ' | cut -f1 -d ':'`
    # format the matching sounding's file pathname
    sndfile=${SOUNDINGS_TOP_DIR}${year}/${mmdd}/${site}/${site}_${year}_${mmdd}_${hh}UTC.txt
    ls -al $sndfile > /dev/null
    if [ $? = 0 ]
      then
        # call function to compute the BB height (m)
        bb=`findbblevel $sndfile`
        echo "site, orbit, bbHeight: ${site}|${orbit}|${bb}"
        echo $bb | grep '\.' > /dev/null
        if [ $? = 0 ]
          then
            # write site, orbit, and bb Height to $bbfile as delimited text
            echo "${site}|${orbit}|${bb}" >> $bbfile
          else
            echo "No BB height computed, skip output this case:"
            echo $sndfile
        fi
    fi
done < $siteTimesFile

exit
