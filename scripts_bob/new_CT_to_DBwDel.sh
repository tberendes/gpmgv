#!/bin/sh
############################################################################
#
# new_CT_to_DB.sh     Morris/SAIC, GPM GV     February 2014
#
# Process table in PPS Coincidence File into a delimited format ready
# to be loaded into database (PostGRESQL), spreadsheet etc. 
# Use '|' as delimiters.
#
# Files:
#   CT.sat.yyyymmdd.ddd.txt  (input; yyyymmdd.ddd varies by date, sat varies
#                             by satellite ID, e.g., TRMM, GPM, etc.)
#   CT.sat.yyyymmdd.ddd.unl  (output; delimited fields, stripped of
#                             headings, whitespace)
#
###########################################################################

umask 0002

mydir=/home/morris/Desktop/
myfile=CT.TRMM.20050111.011.txt
#myfile=CT.`date -u "+%y%m%d"`.6
infile=${mydir}${myfile}
outfile=`echo ${mydir}${myfile} | sed 's/.txt/.unl/'`
#infile=$1
#outfile=$2

# sed command 1: delete 9 header lines of CT file
# sed command 2: remove trailing space(s) at end of lines
# sed command 3: remove spaces between values on a line
# sed command 4: delete all lines not ending with a site code like 'Kxxx'
# sed command 5: delete all lines ending with the site code 'KWAJ'
# sed command 6: replace comma between fields with a single | character
# sed command 7: replace T separator between date and time with a space
# sed command 8: append time zone ID "+00" to end of datetime string

sed '
1,8 d
s/  *$//
s/  *//g
/.*,K[A-Z]\{3\}$/ !d
s/,/|/g
s/\([0-9]\)T\([0-9]\)/\1 \2/g
s/\([:][0-9][0-9]\)\(.[0-9]\)|/\1|/g' <$infile >$outfile

echo $outfile
more $outfile
rm -v $outfile

exit
