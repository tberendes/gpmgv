#!/bin/sh
#
# move_EM_CS_dirs.sh      Morris/GPM GV/SAIC     August 2014
#
# Moves directory trees for pre-release GPM PPS orbit subset products to a
# non-public data subdirectory on ds1-gpmgv.

DATADIR=/data/gpmgv
NEWDATADIR=/data/emdata
ORB=${DATADIR}/orbit_subset
NEWORB=${NEWDATADIR}/orbit_subset
cd $ORB
YYYY=`date -u +%Y`

# move the pre-release directory trees for the GPROF instruments/products
for sat in TRMM/TMI GPM/GMI GCOMW1/AMSR2 F15/SSMIS F16/SSMIS F17/SSMIS F18/SSMIS METOPA/MHS NOAA18/MHS NOAA19/MHS
  do
    cd $ORB
    satonly=`echo $sat | cut -f1 -d '/'`
#    mkdir -p $sat
    cd $sat
    for alg in 2AGPROF
      do
#        mkdir -p $alg
        cd $alg
        pwd
        ls
        for version in V01A V01B V01D V02A
          do
            if [ -d $version ]
              then
                mv -v $version/ $NEWORB/$sat/$alg/$version/
            fi
        done
        ls $NEWORB/$sat/$alg
    done
done
cd $ORB

# move the GPM product tree for non-GPROF (DPR, Ka, Ku, DPRGMI)
for sat in GPM/DPR/2ADPR GPM/Ka/2AKa GPM/Ku/2AKu GPM/DPRGMI/2BDPRGMI
  do
    cd $ORB
#    mkdir -p $sat
    cd $sat
    pwd
    ls
    for version in V01A V01D V01E V01F V01G V02A V02B
      do
        if [ -d $version ]
          then
            mv -v $version/ $NEWORB/$sat/$version/
        fi
    done
    ls $NEWORB/$sat
done
cd $ORB

exit
