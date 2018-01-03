#!/bin/sh
#
# set_up_KOREA_CS_dirs.sh      Morris/GPM GV/SAIC     March 2014
#
# Creates directory trees for GPM-era PPS orbit subset products of interest to
# the GPM Validation Network operations at GSFC, for the new KOREA subset only.

umask 0002

DATADIR=/data/gpmgv
ORB=${DATADIR}/orbit_subset
cd $ORB
YYYY=`date -u +%Y`

# create the initial directory trees for the GPROF instruments/products
for sat in GPM/GMI/2AGPROF GPM/DPRGMI/2BDPRGMI
  do
    cd $ORB
    satonly=`echo $sat | cut -f1 -d '/'`
   # mkdir -p $sat
    cd $sat
   # for alg in 2AGPROF 2BDPRGMI
   #   do
       # mkdir -p $alg
   #     cd $alg
        # the new version(s) should be the argument to this script in the future
        for version in V03D
          do
           # mkdir -p $version
            cd $version
            pwd
            case $satonly in
               GPM )  subsets='Brisbane' ;;
              TRMM )  subsets='KOREA' ;;
                 * )  subsets='KOREA' ;;
            esac
            for subset in `echo $subsets`
              do
                for YYYY in 2014 2015
                  do
                    mkdir -p ${subset}/${YYYY}
                    echo "Making directory $ORB/$sat/$alg/$version/${subset}/${YYYY}"
                    echo ''
                done
            done
            cd ..
        done
   # done
done
cd $ORB
exit

# create the GPM product tree for non-GPROF (DPR, Ka, Ku, DPRGMI)
for sat in GPM/DPR/2ADPR GPM/Ka/2AKa GPM/Ku/2AKu
  do
    cd $ORB
   # mkdir -p $sat
    cd $sat
    for version in V03B
      do
       # mkdir -p $version
        cd $version
        pwd
        for subset in Brisbane
          do
            for YYYY in 2014 2015
              do
                mkdir -p ${subset}/${YYYY}
                echo "Making directory $ORB/$sat/$version/${subset}/${YYYY}"
            done
        done
        cd ..
    done
done
cd $ORB

exit

# create the TRMM legacy product tree for version 7, under new file name/path convention
for sat in TRMM/TMI/2A12/V07 TRMM/PR/1C21/V07 TRMM/PR/2A23/V07 TRMM/PR/2A25/V07 TRMM/COMB/2B31/V07
  do
    cd $ORB
    mkdir -p $sat
    cd $sat
    for subset in KOREA
      do
        # at some point, make past years' directories and move old files here,
        # accounting for subset name differences
        for year in $YYYY
           do
             mkdir -p ${subset}/${year}
             #echo "Making directory $ORB/$sat/${subset}/${year}"
        done
    done
done
cd $ORB

exit
