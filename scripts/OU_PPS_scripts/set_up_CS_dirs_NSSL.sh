#!/bin/sh
#
################################################################################
#
# set_up_CS_dirs_NSSL.sh      Morris/GPM GV/SAIC     March 2014
#
# Creates directory trees for GPM-era PPS orbit subset products of interest to
# the GPM Validation Network operations at GSFC.
#
# 08/27/14 - Changed KORA subset name to KOREA
# 11/16/15 - Dropped F15/SSMIS and added METOPB/MHS
# 03/29/16 - Limited to GPM and CONUS subset only, for NSSL version.
#
################################################################################

DATADIR=/oldeos/NASA_NMQ/satellite/data   # CHANGE THIS AS NEEDED, SEE get_PPS_CS_data_NSSL.sh
ORB=${DATADIR}/orbit_subset               # MUST BE SAME AS "CS_BASE" IN get_PPS_CS_data_NSSL.sh
if [ ! -s $ORB ]
  then
    echo "set_up_CS_dirs_NSSL.sh:  Directory $ORB non-existent, please correct."
    exit 1
fi

cd $ORB
YYYY=`date -u +%Y`

# create the initial directory trees for the GPROF instruments/products
#for sat in TRMM/TMI GPM/GMI GCOMW1/AMSR2 F15/SSMIS F16/SSMIS F17/SSMIS F18/SSMIS METOPA/MHS NOAA18/MHS NOAA19/MHS
for sat in GPM/GMI
  do
    cd $ORB
    satonly=`echo $sat | cut -f1 -d '/'`
    mkdir -p $sat
    cd $sat
    for alg in 2AGPROF
      do
        mkdir -p $alg
        cd $alg
        # the new version(s) should be the argument to this script in the future
        for version in V04A
          do
            mkdir -p $version
            cd $version
            case $satonly in
               GPM )  subsets='CONUS' ;;
              TRMM )  subsets='CONUS' ;;  #placeholder
                 * )  subsets='CONUS' ;;  #placeholder
            esac
            for subset in `echo $subsets`
              do
                mkdir -p ${subset}/${YYYY}
                #echo "Making directory $ORB/$sat/$alg/$version/${subset}/${YYYY}"
                echo ${satonly}'|'${subset}
            done
        done
    done
done
cd $ORB

# create the TRMM legacy product tree for version 7, under new file name/path convention
#for sat in TRMM/TMI/2A12/V07 TRMM/PR/1C21/V07 TRMM/PR/2A23/V07 TRMM/PR/2A25/V07 TRMM/COMB/2B31/V07
#  do
#    cd $ORB
#    mkdir -p $sat
#    cd $sat
#    for subset in CONUS
#      do
        # at some point, make past years' directories and move old files here,
        # accounting for subset name differences
#        for year in $YYYY
#           do
#             mkdir -p ${subset}/${year}
             #echo "Making directory $ORB/$sat/${subset}/${year}"
#        done
#    done
#done
#cd $ORB

# create the GPM product tree for non-GPROF (DPR, Ka, Ku, DPRGMI)
for sat in GPM/DPR/2ADPR GPM/Ka/2AKa GPM/Ku/2AKu GPM/DPRGMI/2BDPRGMI
  do
    cd $ORB
    mkdir -p $sat
    cd $sat
    for version in V04A
      do
        mkdir -p $version
        cd $version
        for subset in CONUS
          do
            mkdir -p ${subset}/${YYYY}
            #echo "Making directory $ORB/$sat/$version/${subset}/${YYYY}"
        done
    done
done
cd $ORB

exit
