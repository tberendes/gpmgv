#!/bin/sh
#
################################################################################
#
# update_CS_dirs_v4test.sh      Morris/GPM GV/SAIC     March 2015
#
# Updates non-operational Internal Test and Evaluation (ITE) directory trees for
# new ITE versions of GPM-era PPS orbit subset products of interest to
# the GPM Validation Network operations at GSFC.  The first argument to this
# script ($1) is the partial path consisting of SATELLITE/INSTRUMENT/ALGORITHM
# in this slash-delimited format.  The path defined by ${ORB}/$1 is assumed to
# already exist.  the second argument is the new product version for which a new
# VERSION/SUBSETS subtree is to be created under ${ORB}$1.
#
# Should be able to handle any new ITE versions, not just for V04 (ITE001-099).
#
#  HISTORY
#    03/10/15      - Morris - Added GPM subsets Guam, Hawaii, and SanJuanPR.
#    11/16/15      - Morris - Added GPM and constellation subset BrazilRadars.
#    02/12/16      - Morris - Added GPM and constellation subset Finland.
#    05/16/16      - Morris - Added remaining GPM subsets to constellation.
#
################################################################################

DATADIR=/data/emdata
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
           GPM )  subsets='AKradars BrazilRadars CONUS DARW KOREA KWAJ Guam Hawaii SanJuanPR Finland' ;;
          TRMM )  subsets='CONUS DARW KOREA KWAJ' ;;
             * )  subsets='AKradars BrazilRadars CONUS DARW KOREA KWAJ Guam Hawaii SanJuanPR Finland' ;;
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
