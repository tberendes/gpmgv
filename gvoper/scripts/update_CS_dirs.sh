#!/bin/sh
#
################################################################################
#
# update_CS_dirs.sh      Morris/GPM GV/SAIC     March 2014
#
# Updates directory trees for GPM-era PPS orbit subset products of interest to
# the GPM Validation Network operations at GSFC.  The first argument to this
# script ($1) is the partial path consisting of SATELLITE/INSTRUMENT/ALGORITHM
# in this slash-delimited format.  The path defined by ${ORB}/$1 is assumed to
# already exist.  the second argument is the new product version for which a new
# VERSION/SUBSETS subtree is to be created under ${ORB}$1.
#
#  HISTORY
#    03/10/15      - Morris - Added GPM subsets Guam, Hawaii, and SanJuanPR.
#    11/16/16      - Morris - Added GPM and constellation subset BrazilRadars.
#    03/29/16      - Morris - Added GPM and constellation subset Finland.
#    08/05/16      - Morris - Added GPM subsets AUS-East, AUS-West, Tasmania
#    02/16/17      - Morris - Removed constellation subset NPOL and added
#                             constellation subsets AKradars, DARW, Guam,
#                             Hawaii, SanJuanPR as in update_CS_dirs_v4test.sh.
#    10/02/17      - Morris - Removed TRMM subsets KOREA and DARW, and added
#                             TRMM subsets AUS-East and AUS-West for V05A/v8.
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
           GPM )  subsets='AKradars BrazilRadars CONUS DARW KOREA KWAJ Guam Hawaii SanJuanPR Finland AUS-East AUS-West Tasmania' ;;
          TRMM )  subsets='CONUS KWAJ AUS-East AUS-West' ;;
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
