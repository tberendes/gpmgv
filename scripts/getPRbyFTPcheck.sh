#!/bin/sh

cd ~/Desktop

for orbit in `ls 1C21* | cut -f3 -d '.'`
  do
    echo ORBIT: $orbit
    ls *${orbit}* | wc -l
done

