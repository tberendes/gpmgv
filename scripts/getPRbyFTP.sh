#!/bin/sh

cd ~/Desktop
outfile=FTPcommands.txt
rm $outfile
for orbit in `ls 1C21* | cut -f3 -d '.'`
  do
    for file in `ls wget*.pl`
      do
        grep $orbit $file | tee -a $outfile
    done
done

