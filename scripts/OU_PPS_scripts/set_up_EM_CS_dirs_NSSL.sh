#!/bin/sh
#
################################################################################
#
# set_up_EM_CS_dirs_NSSL.sh      Morris/GPM GV/SAIC     Aug 2014
#
# Creates directory trees for GPM-era pre-release PPS orbit subset products.
#
# 03/29/16 - Limited to GPM and CONUS subset only, for NSSL version.
#
################################################################################

DATADIR=/oldeos/NASA_NMQ/satellite/data   # CHANGE THIS AS NEEDED, SEE get_PPS_CS_v4testdata_NSSL.sh
ORB=${DATADIR}/orbit_subset               # MUST BE SAME AS "CS_BASE" IN get_PPS_CS_v4testdata_NSSL.sh
if [ ! -s $ORB ]
  then
    echo "set_up_EM_CS_dirs_NSSL.sh:  Directory $ORB non-existent, please correct."
    exit 1
fi

cd $ORB
YYYY=`date -u +%Y`

# create the initial directory trees for the GPROF instruments/products
#for sat in TRMM/TMI GPM/GMI GCOMW1/AMSR2 F15/SSMIS F16/SSMIS F17/SSMIS F18/SSMIS METOPA/MHS NOAA18/MHS NOAA19/MHS
for sat in GPM/GMI
  do
    cd $ORB
    #satonly=`echo $sat | cut -f1 -d '/'`
    mkdir -p $sat
    cd $sat
    for alg in 2AGPROF
      do
        mkdir -p $alg
        cd $alg
        pwd
    done
done
cd $ORB

# create the GPM product tree for non-GPROF (DPR, Ka, Ku, DPRGMI)
for sat in GPM/DPR/2ADPR GPM/Ka/2AKa GPM/Ku/2AKu GPM/DPRGMI/2BDPRGMI
  do
    cd $ORB
    mkdir -p $sat
    cd $sat
    pwd
done
cd $ORB

exit
