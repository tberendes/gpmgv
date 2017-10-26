#!/bin/sh

for site in `ls /home/data/gpmgv/gv_radar/defaultQC_in/`
  do
    echo "rsync -rtv  /home/data/gpmgv/gv_radar/defaultQC_in/${site}/ \
 /media/usbdisk/data/gv_radar/defaultQC_in/$site"
done
for site in `ls /home/data/gpmgv/gv_radar/finalQC_in/`
  do
    echo "rsync -rtv  /home/data/gpmgv/gv_radar/finalQC_in/${site}/ \
 /media/usbdisk/data/gv_radar/finalQC_in/$site"
done
