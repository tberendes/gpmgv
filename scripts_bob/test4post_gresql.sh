#!/bin/sh

pgproccount=`ps -ef | grep postgres | grep -v grep | wc -l`

if [ ${pgproccount} -lt 3 ]
  then
    thistime=`date -u`
    echo "Message from getPRdata.sh cron job on ${thistime}:" \
     > /tmp/PG_MAIL_ERROR_MSG.txt
    echo "" >> /tmp/PG_MAIL_ERROR_MSG.txt
    echo "${pgproccount} Postgres processes active, should be 3 !!" \
     >> /tmp/PG_MAIL_ERROR_MSG.txt
    echo "NEED TO RESTART POSTGRESQL ON ${HOST}." >> /tmp/PG_MAIL_ERROR_MSG.txt
    mailx -s 'postgresql down on ws1-gpmgv' krmorris@pop400.gsfc.nasa.gov \
     -c kenneth.r.morris@nasa.gov < /tmp/PG_MAIL_ERROR_MSG.txt
  else
    echo "${pgproccount} Postgres processes active, should be 3."
fi
exit