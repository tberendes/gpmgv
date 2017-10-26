#!/bin/sh
#
# set_up_EM_CS_dirs.sh      Morris/GPM GV/SAIC     Aug 2014
#
# Creates directory trees for GPM-era pre-release PPS orbit subset products.
#

DATADIR=/data/emdata
ORB=${DATADIR}/orbit_subset
cd $ORB
YYYY=`date -u +%Y`

umask 0002

# create the initial directory trees for the GPROF instruments/products
# - comment out if only creating tree for one new satellite
for sat in TRMM/TMI GPM/GMI GCOMW1/AMSR2 F15/SSMIS F16/SSMIS F17/SSMIS F18/SSMIS F19/SSMIS METOPA/MHS METOPB/MHS NOAA18/MHS NOAA19/MHS NPP/ATMS
#for sat in F19/SSMIS    # edit/uncomment if adding one new sat/instrument directory tree
  do
    cd $ORB
    #satonly=`echo $sat | cut -f1 -d '/'`
    mkdir -p $sat
    chmod a+w  $sat
#    cd $sat
    for alg in 1CRXCAL 2AGPROF
      do
        cd $ORB/$sat
        mkdir -p $alg
        chmod a+w  $alg
        cd $alg
        pwd
    done
done
exit    # uncomment if adding one new sat/instrument directory tree
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
