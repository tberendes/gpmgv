#!/bin/sh
GEOGPM=/data/gpmgv/netcdf/grmatch/GPM/2ADPR
cd $GEOGPM
mkdir -p V05A
for pps_ver in V04A
  do
    cd ${GEOGPM}/${pps_ver}/1_0
    for year in `ls`
      do
        cd ${GEOGPM}/${pps_ver}/1_0/${year}
        pwd
        mkdir -p ${GEOGPM}/V05A/1_0/${year}
        oldpath=${GEOGPM}/${pps_ver}/1_0/${year}
        newpath=${GEOGPM}/V05A/1_0/${year}
        for file in `ls GRtoDPR_HS_MS_NS.*.V04A.1_0.nc*`
          do
            newfile=`echo $file | sed 's/V04A/V05A/g'`
            mv -v $file ${newpath}/$newfile
            echo "UPDATE geo_match_product SET pathname='${newpath}/${newfile}' \
 WHERE pathname='${oldpath}/${file}';" | psql -a -d gpmgv
#            echo "select * from geo_match_product \
 #                 WHERE pathname='${newpath}/${newfile}';" | psql -a -d gpmgv
                
        done
    done
done

exit
