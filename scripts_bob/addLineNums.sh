#!/bin/sh

cd /home/morris/swdev/idl/valnet/walkthru

for file in `ls *.pro`
  do
    filepre=`echo $file | cut -f1 -d '.'`
    sed = $file | sed 'N; s/^/     /; s/ *\(.\{6,\}\)\n/\1  /' | tee ${filepre}.txt
done

exit
