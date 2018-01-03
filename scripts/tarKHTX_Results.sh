#!/bin/sh

# tar up the results files by level and site
cd /home/morris/swdev/idl/valnet/comparez/results
for level in 3.0
  do
    for site in KHTX
      do
        tarfile=/tmp/walt/StatResults.${level}km.${site}.tar
#        echo $tarfile  # testing
        echo ""
        tar cvf $tarfile *${level}*${site}*
    done
done
