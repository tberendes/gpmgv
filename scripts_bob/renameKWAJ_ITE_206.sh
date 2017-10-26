#!/bin/sh

cd /tmp
#    for type in 1C21 2A23 2A25 2B31
#      do
#        cd ${type}
        for file in `ls KWAJ.*SCATR.pdf`
          do
            newfile=`echo $file | sed 's/SCATR/SCATR_v6/'`
            mv -v $file ${newfile}
#        done
#        cd ..
    done
exit
