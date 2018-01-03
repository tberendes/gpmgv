#!/bin/sh

orblist30=""
orbs=0

for line in `cat /data/tmp/REO_METADATA.unl`
do
orbit=`echo $line | cut -f2 -d'|'`
count=`echo $line | cut -f3 -d '|'`
if [ `expr $count \> 199` = 1 ]
  then
    orblist30="${orblist30}${space}${orbit}"
    if [ `expr $orbs \= 10` = 1 ]
      then
        echo $orblist30
	orbs=0
	space=""
	orblist30=""
    else
        orbs=`expr $orbs + 1`
	space=" "
    fi
fi
done

exit