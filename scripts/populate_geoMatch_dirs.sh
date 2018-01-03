#!/bin/sh
#
# set_up_CS_dirs.sh      Morris/GPM GV/SAIC     March 2014
#
# Creates directory trees for geo-match data files to sort by type and versions
# the GPM Validation Network operations at GSFC.
#
# 08/27/14 - Changed KORA subset name to KOREA

DATADIR=/data/gpmgv
GEOMATCH=${DATADIR}/netcdf/geo_match
if [ -d $GEOMATCH ]
  then
    cd $GEOMATCH
  else
    echo "Directory $GEOMATCH does not exist!"
fi
pwd

YYYY=`date -u +%Y`
YYYY=2014
YY=14

# create the GPM product tree for non-GPROF (DPR, Ka, Ku, DPRGMI) GPM/2BDPRGMI
YYYY=2014
YY=14
for sat in GPM/2ADPR/HS GPM/2ADPR/MS GPM/2ADPR/NS GPM/2AKa/HS GPM/2AKa/MS GPM/2AKu/NS
  do
    cd $GEOMATCH
    #mkdir -p $sat
    cd $sat
    version=V03B
    subset=1_0
    prodswath=`echo $sat | cut -f2-3 -d '/' | cut -c 3-8 | sed 's:/:.:' | tr [a-z] [A-Z]`
#    ls $GEOMATCH/GRtoDPR.*.${YY}*.${version}.${prodswath}.${subset}.nc* | head
    ls $GEOMATCH/GRtoDPR.*.${YY}*.${version}.${prodswath}.${subset}.nc* > /dev/null 2>&1
    if [ $? = 0 ]
      then
#        ls $GEOMATCH/GRtoDPR.*.${YY}*.${version}.${prodswath}.${subset}.nc* | head -2
        echo "Moving to directory $GEOMATCH/$sat/V03B/1_1/${YYYY}"
        mv -v $GEOMATCH/GRtoDPR.*.${YY}*.${version}.${prodswath}.${subset}.nc* \
              $GEOMATCH/$sat/$version/${subset}/${YYYY}
      else
        echo "No files for $GEOMATCH/GRtoDPR.*.${YY}*.${version}.${prodswath}.${subset}.nc*"
    fi
done
cd $GEOMATCH

exit

# create the initial directory trees for the GPROF instruments/products
 #GCOMW1/AMSR2 F15/SSMIS F16/SSMIS F17/SSMIS F18/SSMIS METOPA/MHS NOAA18/MHS NOAA19/MHS
for sat in TRMM/TMI GPM/GMI
  do
    cd $GEOMATCH
    satonly=`echo $sat | cut -f1 -d '/'`
    imager=`echo $sat | cut -f2 -d '/'`
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
                #mkdir -p ${subset}/${YYYY}
                #ls $GEOMATCH/GRtoGPROF.${satonly}.${imager}.*.${YY}*.${version}.${subset}.nc* | head
                echo "Moving to directory $GEOMATCH/$sat/$alg/$version/${subset}/${YYYY}"
                mv -v $GEOMATCH/GRtoGPROF.${satonly}.${imager}.*.${YY}*.${version}.${subset}.nc* \
                      $GEOMATCH/$sat/$alg/$version/${subset}/${YYYY}
            done
            cd ..
        done
        cd ..
    done
done
cd $GEOMATCH

#exit

# create the TRMM legacy product tree for GRtoPR
for sat in TRMM/PR
  do
    cd $GEOMATCH
    mkdir -p $sat
    cd $sat
        for version in 6 7
          do
            #mkdir -p $version
            cd V0$version
            case $version in
               6 )  ncvers='2_1' ;;
               7 )  ncvers='2_1 2_2 3_1' ;;
               * )  ncvers='3_1' ;;
            esac
            for subset in `echo $ncvers`
              do
                for YYYY in 2006 2007 2008 2009 2010 2011 2012 2013 2014
                  do
                    YY=`echo $YYYY | cut -c3-4`
                    ls $GEOMATCH/GRtoPR.*.${YY}*.V0${version}.${subset}.nc* > /dev/null 2>&1
                    if [ $? = 0 ]
                      then
                        #ls $GEOMATCH/GRtoPR.*.${YY}*.${version}.${subset}.nc*  | head -2
                        echo "Moving to directory $GEOMATCH/$sat/V0$version/${subset}/${YYYY}"
                        mv -v $GEOMATCH/GRtoPR.*.${YY}*.V0${version}.${subset}.nc* \
                              $GEOMATCH/$sat/V0$version/${subset}/${YYYY}
                      else
                        echo "No files for $GEOMATCH/GRtoPR.*.${YY}*.V0${version}.${subset}.nc*"
                    fi
                done
            done
            cd ..
        done
        cd ..
done
cd $GEOMATCH

#exit

# create the TRMM legacy product tree for GRtoTMI
for sat in TRMM/TMI/2A12
  do
    cd $GEOMATCH
    mkdir -p $sat
    cd $sat
        for version in 6 7
          do
            #mkdir -p $version
            cd V0$version
            case $version in
                 6 )  ncvers='1_0' ;;
                 7 )  ncvers='1_0 2_0' ;;
                 * )  ncvers='2_0' ;;
            esac
            for subset in `echo $ncvers`
              do
                for YYYY in 2006 2007 2008 2009 2010 2011 2012 2013 2014
                  do
                    YY=`echo $YYYY | cut -c3-4`
                    #mkdir -p ${subset}/${YYYY}
                    ls $GEOMATCH/GRtoTMI.*.${YY}*.${version}.${subset}.nc* > /dev/null 2>&1
                    if [ $? = 0 ]
                      then
                        #ls $GEOMATCH/GRtoTMI.*.${YY}*.${version}.${subset}.nc* | head -2
                        echo "Moving to directory $GEOMATCH/$sat/V0$version/${subset}/${YYYY}"
                        mv -v $GEOMATCH/GRtoTMI.*.${YY}*.${version}.${subset}.nc* \
                              $GEOMATCH/$sat/V0$version/${subset}/${YYYY}
                      else
                        echo "No files for $GEOMATCH/GRtoTMI.*.${YY}*.${version}.${subset}.nc*"
                    fi
                done
            done
            cd ..
        done
        cd ..
done
cd $GEOMATCH

exit

#mkdir -p GPM/2BDPRGMI/V03C/1_1/${YYYY}
ls -al $GEOMATCH/GPM/2BDPRGMI/V03C/1_1/${YYYY}

exit
