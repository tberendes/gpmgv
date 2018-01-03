#!/bin/sh

unfound=/home/morris/X_sect_NotFound.txt
infound=/home/morris/X_sect_Internal.txt
found2cp=/home/morris/X_sect_2tar.txt
look4me=/home/morris/X_sect_maybes.txt
rm -v $look4me
echo "Modules not in source tree:" > $unfound
echo "Modules internal to other files:" > $infound
echo "Modules to tar up for release:" > $found2cp
for file in `cat /home/morris/cross_sections_src.txt`
  do
   # see if the file is in the IDL dev tree
    ls -alR /home/morris/swdev/idl/dev | grep $file | grep -v '~'  2>&1 > /dev/null
    if [ $? == 0 ]
      then
        #echo "Found $file"
	file2get=`ls -al /home/morris/swdev/idl/dev/*/${file}.pro | grep -v walkthru`
	if [ $? == 0 ]
	  then
	    file2tar=`echo $file2get | cut -f9 -d' '`
	    cp -v $file2tar /home/morris/swdev/idl/x_section_src_pkg  | tee -a $found2cp
        fi
    else
       # see if the file is in the IDL rsl_in_idl tree
        ls -al /home/morris/swdev/idl/rsl_in_idl | grep $file | grep -v '~'  2>&1 > /dev/null
        if [ $? == 0 ]
          then
            #echo "Found $file"
            file2get=`ls -al /home/morris/swdev/idl/rsl_in_idl/${file}.pro`
            if [ $? == 0 ]
	      then
	        file2tar=`echo $file2get | cut -f9 -d' '`
	        cp -v $file2tar /home/morris/swdev/idl/x_section_src_pkg  | tee -a $found2cp
            fi
        else
          # tally to see if the module is internal to one of our found files
           echo $file >> $look4me
#	   parentfile=`grep ${file} /home/morris/swdev/idl/dev/*/*.pro | grep -Ei '(function |pro )'`
#           if [ $? == 0 ]
#              then
#                 echo $parentfile | grep ':'
#		 parent=`echo $parentfile | cut -f1 -d':'`
#                 echo '' | tee -a $infound
#                 echo "Found module ${file} in $parent" | tee -a $infound
#                 echo $parentfile | tee -a $infound
#		 parentbase=`basename $parent `
#                 grep ${parentbase} $found2cp
#                 echo ''
#           else
#                 parentfile=`grep ${file} /home/morris/swdev/idl/rsl_in_idl/*.pro | grep -Ei '(function |pro )'`
#                 if [ $? == 0 ]
#                   then
#                      parent=`echo $parentfile | cut -f1 -d':'`
#                      echo '' | tee -a $infound
#                      echo "Found module ${file} in ${parent}:" | tee -a $infound
#		      parentbase=`basename $parent`
#                      grep ${parentbase} $found2cp
#                      echo ''
#                 else
#                      echo ''
#                      echo "Not found: ${file}.pro" | tee -a $unfound
#                      echo ''
#                 fi
#           fi
        fi
    fi
done

for file in `cat $look4me`
  do
    parentfile=`grep ${file} /home/morris/swdev/idl/x_section_src_pkg/*.pro | grep -Ei '(function |pro )'`
    if [ $? == 0 ]
      then
#        echo $parentfile | grep ':'
        parent=`echo $parentfile | cut -f1 -d':'`
        echo '' | tee -a $infound
        echo "Found module ${file} in $parent" | tee -a $infound
        echo $parentfile | tee -a $infound
#        parentbase=`basename $parent `
#        grep ${parentbase} $found2cp
        echo ''
      else
        echo "Not found: ${file}.pro" | tee -a $unfound
        echo ''
    fi
done