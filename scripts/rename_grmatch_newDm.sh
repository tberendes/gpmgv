#!/bin/sh
GEOGPM=/data/gpmgv/netcdf/grmatch/GPM/2ADPR
cd $GEOGPM
for pps_ver in `ls`
  do
    cd ${GEOGPM}/${pps_ver}/1_0
    for year in `ls`
      do
        cd ${GEOGPM}/${pps_ver}/1_0/${year}
        pwd
        dbpath=${GEOGPM}/${pps_ver}/1_0/${year}
        for file in `ls GRtoDPR_HS_MS_NS.*.1_0.15dbzGRDPR.nc*`
          do
            newfile=`echo $file | sed 's/1_0.15dbzGRDPR.nc/1_0.old_GR_Dm.nc/'`
            mv -v $file $newfile
            echo "UPDATE geo_match_product SET pathname='${dbpath}/${newfile}' \
 WHERE pathname='${dbpath}/${file}';" | psql -a -d gpmgv
#            echo "select * from geo_match_product \
 #                 WHERE pathname='${dbpath}/${newfile}';" | psql -a -d gpmgv
                
        done
    done
done

exit
