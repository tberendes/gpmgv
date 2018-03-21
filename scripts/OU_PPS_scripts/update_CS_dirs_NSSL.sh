#!/bin/sh
#
################################################################################
#
# update_CS_dirs_NSSL.sh      Morris/GPM GV/SAIC     March 2014
#
# Updates directory trees for GPM-era PPS orbit subset products of interest to
# the GPM Validation Network operations at GSFC.  The first argument to this
# script ($1) is the partial path consisting of SATELLITE/INSTRUMENT/ALGORITHM
# in this slash-delimited format.  The path defined by ${ORB}/$1 is assumed to
# already exist.  the second argument is the new product version for which a new
# VERSION/SUBSETS subtree is to be created under ${ORB}$1.  Also always creates
# a subdirectory YYYY for the current calendar year under VERSION/SUBSETS.
#
#  HISTORY
#    03/10/15      - Morris - Added GPM subsets Guam, Hawaii, and SanJuanPR.
#    11/16/16      - Morris - Added GPM and constellation subset BrazilRadars.
#    03/29/16      - Morris - Limited to CONUS subset only for NSSL version.
#
################################################################################

DATADIR=/oldeos/NASA_NMQ/satellite/data   # CHANGE THIS AS NEEDED, SEE get_PPS_CS_data_NSSL.sh
ORB=${DATADIR}/orbit_subset               # MUST BE SAME AS "CS_BASE" IN get_PPS_CS_data_NSSL.sh
if [ ! -s $ORB ]
  then
    echo "update_CS_dirs_NSSL.sh:  Directory $ORB non-existent, please correct."
    exit 1
fi

cd $ORB
YYYY=`date -u +%Y`

umask 0002

# create the necessary directory trees for the satellite/instrument/product
for satInstrAlg in $1
  do
    if [ ! -s $ORB/$1 ]
      then
        echo "update_CS_dirs_NSSL.sh:  Directory $ORB/$1 non-existent, please correct."
        exit 1
    fi
    cd ${ORB}/$1
    satonly=`echo $satInstrAlg | cut -f1 -d '/'`
    # the new version(s) should be the 2nd argument to this script
    for version in $2
      do
        mkdir -p $version
        cd $version
        case $satonly in
           GPM )  subsets='CONUS' ;;
          TRMM )  subsets='CONUS' ;;
             * )  subsets='CONUS' ;;
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
