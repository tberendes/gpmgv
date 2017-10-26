#!/bin/sh

#cd /data/gpmgv/gv_radar/finalQC_in
cd /data/gpmgv/orbit_subset

#for file in `cat /tmp/COMB_radfile_list.txt`
for file in `cat /data/gpmgv/xfer/COMB_files_sites4geoMatch.Alaska.txt | grep HDF | cut -f7 -d '|'`
   do
#     tar -rvf  /data/gpmgv/xfer/COMB_CONUS_radar.tar  $file
      tar -rvf  /data/gpmgv/xfer/COMB_Alaska_2BDPRGMI.tar  $file
done

exit
