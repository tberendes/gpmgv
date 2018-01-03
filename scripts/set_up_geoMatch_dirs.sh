#!/bin/sh
#
# set_up_CS_dirs.sh      Morris/GPM GV/SAIC     Feb 2015
#
# Creates directory trees for geo-match data files to sort by type and versions
# the GPM Validation Network operations at GSFC.
#
# 02/16/15 - Created.
#

DATADIR=/data/gpmgv
GEOMATCH=${DATADIR}/netcdf/geo_match
if [ -d $GEOMATCH ]
  then
    cd $GEOMATCH
  else
    echo "Directory $GEOMATCH does not exist!"
fi
pwd

#YYYY=`date -u +%Y`
YYYY=2014

# create the GPM product tree for non-GPROF (DPR, Ka, Ku, DPRGMI) GPM/2BDPRGMI
YYYY=2014
for sat in GPM/2ADPR/HS GPM/2ADPR/MS GPM/2ADPR/NS GPM/2AKa/HS GPM/2AKa/MS GPM/2AKu/NS
  do
    cd $GEOMATCH
    mkdir -p $sat
    cd $sat
    mkdir -p V03B/1_0/${YYYY}
    echo "Making directory $GEOMATCH/$sat/V03B/1_0/${YYYY}"
    ls -al $GEOMATCH/$sat/V03B/1_0/${YYYY}
done
cd $GEOMATCH

exit

# create the initial directory trees for the GPROF instruments/products
 #GCOMW1/AMSR2 F15/SSMIS F16/SSMIS F17/SSMIS F18/SSMIS METOPA/MHS NOAA18/MHS NOAA19/MHS
for sat in TRMM/TMI GPM/GMI
  do
    cd $GEOMATCH
    satonly=`echo $sat | cut -f1 -d '/'`
    mkdir -p $sat
    cd $sat
    for alg in 2AGPROF
      do
        mkdir -p $alg
        cd $alg
        # the new version(s) should be the argument to this script in the future
        for version in V03C V03D
          do
            mkdir -p $version
            cd $version
            case $version in
              V03C )  ncvers='1_0' ;;
              V03D )  ncvers='1_0 1_1' ;;
                 * )  ncvers='1_1' ;;
            esac
            for subset in `echo $ncvers`
              do
                mkdir -p ${subset}/${YYYY}
                echo "Making directory $GEOMATCH/$sat/$alg/$version/${subset}/${YYYY}"
                ls -al $GEOMATCH/$sat/$alg/$version/${subset}/${YYYY}
            done
            cd ..
        done
        cd ..
    done
done
cd $GEOMATCH


# create the TRMM legacy product tree for GRtoPR
for sat in TRMM/PR
  do
    cd $GEOMATCH
    mkdir -p $sat
    cd $sat
        for version in V06 V07
          do
            mkdir -p $version
            cd $version
            case $version in
               V06 )  ncvers='2_1' ;;
               V07 )  ncvers='2_1 3_1' ;;
                 * )  ncvers='3_1' ;;
            esac
            for subset in `echo $ncvers`
              do
                for YYYY in 2006 2007 2008 2009 2011 2012 2013 2014
                  do
                    mkdir -p ${subset}/${YYYY}
                    echo "Making directory $GEOMATCH/$sat/$version/${subset}/${YYYY}"
                    ls -al $GEOMATCH/$sat/$version/${subset}/${YYYY}
                done
            done
            cd ..
        done
        cd ..
done
cd $GEOMATCH

# create the TRMM legacy product tree for GRtoTMI
for sat in TRMM/TMI/2A12
  do
    cd $GEOMATCH
    mkdir -p $sat
    cd $sat
        for version in V06 V07
          do
            mkdir -p $version
            cd $version
            case $version in
               V06 )  ncvers='1_0' ;;
               V07 )  ncvers='1_0 2_0' ;;
                 * )  ncvers='2_0' ;;
            esac
            for subset in `echo $ncvers`
              do
                for YYYY in 2006 2007 2008 2009 2011 2012 2013 2014
                  do
                    mkdir -p ${subset}/${YYYY}
                    echo "Making directory $GEOMATCH/$sat/$version/${subset}/${YYYY}"
                    ls -al $GEOMATCH/$sat/$version/${subset}/${YYYY}
                done
            done
            cd ..
        done
        cd ..
done
cd $GEOMATCH

mkdir -p GPM/2BDPRGMI/V03C/1_1/${YYYY}
ls -al $GEOMATCH/GPM/2BDPRGMI/V03C/1_1/${YYYY}

exit
