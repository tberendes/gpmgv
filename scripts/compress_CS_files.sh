#!/bin/sh
#
# compress_CS_files.sh      Morris/GPM GV/SAIC     March 2014
#
# gzip files in directory trees for GPM-era PPS orbit subset products

DATADIR=/data/gpmgv
ORB=${DATADIR}/orbit_subset
cd $ORB
YYYY=`date -u +%Y`

# gzip files in the initial directory trees for the GPROF instruments/products
for sat in TRMM/TMI GPM/GMI GCOMW1/AMSR2 F15/SSMIS F16/SSMIS F17/SSMIS F18/SSMIS METOPA/MHS NOAA18/MHS NOAA19/MHS
  do
    cd $ORB
    satonly=`echo $sat | cut -f1 -d '/'`
    cd $sat
    for alg in 2AGPROF
      do
        cd $alg
        # the new version(s) should be the argument to this script in the future
        for version in `ls`
          do
            cd $version
            case $satonly in
               GPM )  subsets='AKradars CONUS DARW KORA KWAJ' ;;
              TRMM )  subsets='CONUS DARW KORA KWAJ' ;;
                 * )  subsets='CONUS KORA KWAJ NPOL' ;;
            esac
            for subset in `echo $subsets`
              do
                cd $ORB/$sat/$alg/$version/${subset}/${YYYY}
#                pwd
#                for file in `ls  */*/*.HDF5`
#                  do
#                    gzip $file
#                done
            done
        done
    done
done
cd $ORB

# gzip files in the TRMM legacy product tree for version 7, under new file name/path convention
for sat in TRMM/TMI/2A12/V07 TRMM/PR/1C21/V07 TRMM/PR/2A23/V07 TRMM/PR/2A25/V07 TRMM/COMB/2B31/V07
  do
#    cd $ORB
    for subset in CONUS DARW KORA KWAJ
      do
        cd $ORB/$sat/${subset}/${YYYY}
        pwd
        for file in `ls  */*/*.HDF`
          do
            # compress file if not already in gzip
            gzip -l $file > /dev/null 2>&1
            if [ $? = 1 ]
              then
                echo "Compressing $file with gzip"
                gzip $file
            fi
        done
    done
done
cd $ORB

# gzip files in the GPM product tree for non-GPROF (DPR, Ka, Ku, DPRGMI)
for sat in GPM/DPR/2ADPR GPM/Ka/2AKa GPM/Ku/2AKu GPM/DPRGMI/2BDPRGMI
  do
    cd $ORB/$sat
    for version in `ls`
      do
        cd $version
        for subset in AKradars CONUS DARW KORA KWAJ
          do
            cd $ORB/$sat/$version/${subset}/${YYYY}
#            pwd
#            for file in `ls  */*/*.HDF`
#              do
#                echo "gzip $file"
#            done
        done
    done
done

exit
