#!/bin/sh
GEOGPM=/data/gpmgv/netcdf/geo_match/GPM
cd $GEOGPM
for prod in `ls | grep 2A`
  do
    cd ${GEOGPM}/${prod}
    for swath in `ls`
      do
        cd ${GEOGPM}/${prod}/${swath}/V04A/1_21
        for year in `ls`
          do
            cd ${GEOGPM}/${prod}/${swath}/V04A/1_21/${year}
            pwd
            dbpath=${GEOGPM}/${prod}/${swath}/V04A/1_21/${year}
            for file in `ls GRtoDPR.*.1_21.15dbzGRDPR_newDm.nc*`
             do
               newfile=`echo $file | sed 's/1_21.15dbzGRDPR_newDm.nc/1_21.nc/'`
               mv -v $file $newfile
               echo "UPDATE geo_match_product SET pathname='${dbpath}/${newfile}' \
 WHERE pathname='${dbpath}/${file}';" | psql -a -d gpmgv
#               echo "select * from geo_match_product \
#                     WHERE pathname='${dbpath}/${newfile}';" | psql -a -d gpmgv
                
            done
        done
    done
done

exit
