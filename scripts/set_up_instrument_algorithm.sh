#!/bin/sh
#
# set_up_instrument_algorithm.sh      Morris/GPM GV/SAIC     March 2014
#
# Creates satellite|instrument|product associations for GPM-era PPS products
# of interest to the GPM Validation Network operations at GSFC that align
# with the baseline directory structure where the products are stored in the
# VN file system.

unlfile=/home/morris/swdev/scripts/sat_instrument_algorithm.unl2
rm -v $unlfile

# create the entries for the GPROF instruments/products
for sat in TRMM/TMI GPM/GMI GCOMW1/AMSR2 F15/SSMIS F16/SSMIS F17/SSMIS F18/SSMIS METOPA/MHS NOAA18/MHS NOAA19/MHS
  do
    for alg in 2AGPROF
      do
        echo $sat'/'$alg | sed 's[/[|[g' | tee -a $unlfile
    done
done
cd $ORB

# create the entries for TRMM legacy product version 7
for sat in TRMM/TMI/2A12/V07 TRMM/PR/1C21/V07 TRMM/PR/2A23/V07 TRMM/PR/2A25/V07 TRMM/COMB/2B31/V07
  do
    echo $sat | cut -f1-3 -d '/' | sed 's[/[|[g' | tee -a $unlfile
done

# create the GPM product associations for non-GPROF (DPR, Ka, Ku, DPRGMI)
for sat in GPM/DPR/2ADPR GPM/Ka/2AKa GPM/Ku/2AKu GPM/DPRGMI/2BDPRGMI
  do
    echo $sat | sed 's[/[|[g' | tee -a $unlfile
done

echo ""
echo "Unload file:"
cat $unlfile

exit
