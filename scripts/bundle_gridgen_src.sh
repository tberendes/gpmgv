#!/bin/sh

for file in `cat /home/morris/gridgensrc.txt`
  do
    ls -alR /home/morris/swdev/idl/dev | grep $file | grep -v '~'  2>&1 > /dev/null
    if [ $? == 0 ]
      then
        #echo "Found $file"
	file2get=`ls -al /home/morris/swdev/idl/dev/*/$file | grep -v walkthru`
	if [ $? == 0 ]
	  then
	    file2tar=`echo $file2get | cut -f9 -d' '`
	    cp -v $file2tar /home/morris/swdev/idl/gridgen_for_OU
	fi
      else
        echo "Not found: $file"
    fi
done