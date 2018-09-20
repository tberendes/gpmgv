#!/bin/sh
#
################################################################################
#
# update_CS_dirs_Reunion.sh      Morris/GPM GV/SAIC     Nov 2017
#
# Updates directory trees for GPM-era PPS orbit subset products of interest to
# the GPM Validation Network operations at GSFC.  The first argument to this
# script ($1) is the partial path consisting of SATELLITE/INSTRUMENT/ALGORITHM
# in this slash-delimited format.  The path defined by ${ORB}/$1 is assumed to
# already exist.  the second argument is the new product version for which a new
# VERSION/SUBSETS subtree is to be created under ${ORB}$1.
#
#  HISTORY
#    11/03/17      - Morris - Created from update_CS_dirs.sh, modified to do
#                             the Reunion subset only.
#
################################################################################

DATADIR=/data/gpmgv
ORB=${DATADIR}/orbit_subset
cd $ORB
YYYY=`date -u +%Y`

umask 0002

# create the necessary directory trees for the satellite/instrument/product
for satInstrAlg in $1
  do
    cd ${ORB}/$1
    satonly=`echo $satInstrAlg | cut -f1 -d '/'`
    # the new version(s) should be the 2nd argument to this script
    for version in $2
      do
        mkdir -p $version
        cd $version
        case $satonly in
           GPM )  subsets='Reunion' ;;
          TRMM )  subsets='Reunion' ;;
             * )  subsets='Reunion' ;;
        esac
        for subset in `echo $subsets`
          do
            mkdir -p ${subset}/${YYYY}
            echo "Making directory $ORB/$satInstrAlg/$version/${subset}/${YYYY}"
            #echo ${satonly}'|'${subset}
        done
    done
done

exit
