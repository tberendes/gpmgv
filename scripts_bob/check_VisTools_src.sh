#!/bin/sh

look4me=/home/morris/StatsProg_maybes.txt
rm -v $look4me

cd /home/morris/swdev/idl/NTR_Delivery_VisTools_v1_1/src
for file in `ls *.pro`
  do
   # see if the file is in the IDL dev tree
    ls -alR /home/morris/swdev/idl/dev | grep $file | grep -v '~'  2>&1 > /dev/null
    if [ $? == 0 ]
      then
        echo "Found $file"
	file2get=`ls -al /home/morris/swdev/idl/dev/*/${file} | grep -v walkthru`
	if [ $? == 0 ]
	  then
	    file2diff=`echo $file2get | cut -f9 -d' '`
	    diff $file $file2diff > $look4me
            if [ -s $look4me ]
              then
                echo ""
                echo "File is different: "$file
                echo ""
                cat $look4me
                echo ""
            fi
        fi

    fi
done

rm -v $look4me
exit
