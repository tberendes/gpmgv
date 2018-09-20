#!/bin/sh
#
# set_up_CS_dirs_Reunion.sh      Morris/GPM GV/SAIC     Nov 2017
#
# Creates directory trees for GPM-era PPS orbit subset products of interest to
# the GPM Validation Network operations at GSFC.
#
# 08/27/14 - Changed KORA subset name to KOREA
# 11/16/15 - Dropped F15/SSMIS and added METOPB/MHS
# 06/29/16 - Added 1CRXCAL to imager products
# 08/05/16 - Added GPM subsets AUS-East, AUS-West, Tasmania
# 08/16/16 - Added NPP/ATMS to GPROF/XCAL tree, and umask for permissions
# 04/17/17 - Added F19/SSMIS to GPROF/XCAL tree, added "chmod a+w $sat"
# 10/10/17 - Added TRMM v8 tree creation at beginning and made V05A the default
#            version for all GPM-era setups
# 11/03/17 - Morris - Created from set_up_CS_dirs.sh, modified to do the dirs
#            for the GPM DPR-specific products only, for the Reunion subset only.

DATADIR=/data/gpmgv
ORB=${DATADIR}/orbit_subset
cd $ORB
YYYY=`date -u +%Y`

umask 0002

cd $ORB

# create the GPM product tree for non-GPROF (DPR, Ka, Ku)
for sat in GPM/DPR/2ADPR GPM/Ka/2AKa GPM/Ku/2AKu
  do
    cd $ORB
#    mkdir -p $sat
    cd $sat
    for version in V05A 
      do
        mkdir -p $version
        cd $version
        for subset in Reunion
          do
            mkdir -p ${subset}/${YYYY}
            echo "Making directory $ORB/$sat/$version/${subset}/${YYYY}"
        done
    done
done
cd $ORB

exit
