#!/bin/sh
#
# set_up_CS_dirs.sh      Morris/GPM GV/SAIC     March 2014
#
# Creates directory trees for GPM-era PPS orbit subset products of interest to
# the GPM Validation Network operations at GSFC.
#
# 11/16/15 - Created from set_up_CS_dirs.sh to just do Finland subset
#          - Dropped F15/SSMIS and added METOPB/MHS

DATADIR=/data/gpmgv
ORB=${DATADIR}/orbit_subset
cd $ORB
YYYY=`date -u +%Y`

umask 0002

# create the initial directory trees for the GMP GMI GPROF instruments/products
for sat in GPM/GMI
  do
    cd $ORB
    satonly=`echo $sat | cut -f1 -d '/'`
    #mkdir -p $sat
    cd $sat
    for alg in 2AGPROF
      do
        #mkdir -p $alg
        cd $alg
        # the new version(s) should be the argument to this script in the future
        for version in V03D
          do
            #mkdir -p $version
            cd $version
            case $satonly in
               GPM )  subsets='Finland' ;;
              TRMM )  subsets='Finland' ;;
                 * )  subsets='Finland' ;;
            esac
            for subset in `echo $subsets`
              do
                mkdir -p ${subset}/${YYYY}
                echo "Making directory $ORB/$sat/$alg/$version/${subset}/${YYYY}"
                echo ${satonly}'|'${subset}
            done
        done
    done
done
cd $ORB

# create the initial directory trees for the constellation GPROF instruments/products
for sat in GCOMW1/AMSR2 F16/SSMIS F17/SSMIS F18/SSMIS METOPA/MHS METOPB/MHS NOAA18/MHS NOAA19/MHS
  do
    cd $ORB
    satonly=`echo $sat | cut -f1 -d '/'`
    #mkdir -p $sat
    cd $sat
    for alg in 2AGPROF
      do
        #mkdir -p $alg
        cd $alg
        # the new version(s) should be the argument to this script in the future
        for version in V03C
          do
            #mkdir -p $version
            cd $version
            case $satonly in
               GPM )  subsets='Finland' ;;
              TRMM )  subsets='Finland' ;;
                 * )  subsets='Finland' ;;
            esac
            for subset in `echo $subsets`
              do
                mkdir -p ${subset}/${YYYY}
                echo "Making directory $ORB/$sat/$alg/$version/${subset}/${YYYY}"
                echo ${satonly}'|'${subset}
            done
        done
    done
done
cd $ORB

# create the GPM product tree for (DPR, Ka, Ku)
for sat in GPM/DPR/2ADPR GPM/Ka/2AKa GPM/Ku/2AKu
  do
    cd $ORB
    #mkdir -p $sat
    cd $sat
    for version in V04A
      do
        #mkdir -p $version
        cd $version
        for subset in Finland
          do
            mkdir -p ${subset}/${YYYY}
            echo "Making directory $ORB/$sat/$version/${subset}/${YYYY}"
        done
    done
done
cd $ORB


# create the GPM product tree for DPRGMI
for sat in GPM/DPRGMI/2BDPRGMI
  do
    cd $ORB
    #mkdir -p $sat
    cd $sat
    for version in V04A
      do
        #mkdir -p $version
        cd $version
        for subset in Finland
          do
            mkdir -p ${subset}/${YYYY}
            echo "Making directory $ORB/$sat/$version/${subset}/${YYYY}"
        done
    done
done
cd $ORB
exit
