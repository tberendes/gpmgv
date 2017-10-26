#!/bin/sh
txt="p"
expr $txt + 1 > /dev/null 2>&1
if [ $? != 0 ]
  then
    echo "Not a number: " $txt
fi
exit