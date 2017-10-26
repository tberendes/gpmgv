#!/bin/sh
#
# set_up_CS_dirs.sh      Morris/GPM GV/SAIC     March 2014
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

DATADIR=/data/gpmgv
ORB=${DATADIR}/orbit_subset
cd $ORB
YYYY=`date -u +%Y`

umask 0002

# create the v8 (V05A) TRMM product tree for non-GPROF (PR/KU, PRTMI)
# - don't know yet if it will be PR/2APR or KU/2AKU, so do both
for sat in TRMM/PR/2APR TRMM/KU/2AKU TRMM/PRTMI/2BPRTMI
  do
    cd $ORB
    mkdir -p $sat
    cd $sat
    for version in V05A 
      do
        mkdir -p $version
        cd $version
        for subset in CONUS KWAJ AUS-East AUS-West
          do
            mkdir -p ${subset}/${YYYY}
            echo "Making directory $ORB/$sat/$version/${subset}/${YYYY}"
        done
    done
done
cd $ORB
#exit     # uncomment to just do TRMM v8 (V05A) and exit

# to create the initial directory trees for all the GPROF/XCAL instruments/products:
# create just one new satellite's GPROF/XCAL tree:
#for sat in F19/SSMIS
# TAB added all instruments/products back in
for sat in TRMM/TMI GPM/GMI GCOMW1/AMSR2 F15/SSMIS F16/SSMIS F17/SSMIS F18/SSMIS F19/SSMIS METOPA/MHS METOPB/MHS NOAA18/MHS NOAA19/MHS NPP/ATMS
  do
    cd $ORB
    satonly=`echo $sat | cut -f1 -d '/'`
    mkdir -p $sat
    chmod a+w  $sat
    #cd $sat
    for alg in 1CRXCAL 2AGPROF
      do
        cd $ORB/$sat
        mkdir -p $alg
        chmod a+w  $alg
        # the new version(s) should be the argument to this script in the future
        for version in V05A
          do
            cd $ORB/$sat/$alg
            mkdir -p $version
            chmod a+w  $version
            case $satonly in
               GPM )  subsets='AKradars BrazilRadars CONUS DARW KOREA KWAJ Guam Hawaii SanJuanPR Finland' ;;
              TRMM )  subsets='CONUS DARW KOREA KWAJ' ;;
                 * )  subsets='AKradars BrazilRadars CONUS DARW KOREA KWAJ Guam Hawaii SanJuanPR Finland' ;;
            esac
            for subset in `echo $subsets`
              do
                cd $ORB/$sat/$alg/$version
                mkdir -p ${subset}/${YYYY}
                #echo "Making directory $ORB/$sat/$alg/$version/${subset}/${YYYY}"
                chmod a+w  $subset
                chmod a+w  ${subset}/${YYYY}
                echo ${satonly}'|'${subset}
            done
        done
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
    for subset in CONUS DARW KOREA KWAJ
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

# create the GPM product tree for non-GPROF (DPR, Ka, Ku, DPRGMI)
for sat in GPM/DPR/2ADPR GPM/Ka/2AKa GPM/Ku/2AKu GPM/DPRGMI/2BDPRGMI
  do
    cd $ORB
    mkdir -p $sat
    cd $sat
    for version in V05A 
      do
        mkdir -p $version
        cd $version
        for subset in AKradars BrazilRadars CONUS DARW KOREA KWAJ Guam Hawaii SanJuanPR Finland AUS-East AUS-West Tasmania
          do
            mkdir -p ${subset}/${YYYY}
            #echo "Making directory $ORB/$sat/$version/${subset}/${YYYY}"
        done
    done
done
cd $ORB

exit
