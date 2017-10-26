#!/bin/sh

for file in `ls /home/morris/swdev/idl/rsl_in_idl`
  do
    if [ -f /home/morris/swdev/idl/NTR_Delivery_VisTools/src/$file ]
      then
        mv -v /home/morris/swdev/idl/NTR_Delivery_VisTools/src/$file /home/morris/swdev/idl/NTR_Delivery_VisTools/src/rsl_in_idl
    fi
done