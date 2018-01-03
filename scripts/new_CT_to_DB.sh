#!/bin/sh
############################################################################
#
# new_CT_to_DB.sh     Morris/SAIC, GPM GV     February 2014
#
# Process table in PPS Coincidence File into a delimited format ready
# to be loaded into database (PostGRESQL), spreadsheet etc. 
# Use '|' as delimiters.
#
# Files/Arguments:
#   CT.sat.yyyymmdd.ddd.txt   Input; yyyymmdd.ddd varies by date, sat varies
#                             by satellite ID, e.g., TRMM, GPM, etc.
#   CT.sat.yyyymmdd.ddd.unl   Input/Output; delimited CT fields, stripped of
#                             headings, whitespace, and in a format ready to
#                             be loaded into database table.
#
# The above filenames must be passed as fully-qualified file pathnames, and
# the file CT.sat.yyyymmdd.ddd.txt must exist.
#
###########################################################################

umask 0002

infile=$1
outfile=$2
# FOR TESTING ONLY:
#mydir=/home/morris/Desktop/
#myfile=CT.TRMM.20140227.058.txt
#myfile=CT.`date -u "+%y%m%d"`.6
#infile=${mydir}${myfile}
#outfile=`echo ${mydir}${myfile} | sed 's/.txt/.unl/'`

# get the satellite ID from the 1st line of the file (could get it from the
# $infile file basename)
bird=`head -1 $infile | cut -f1 -d ' '`

# sed command 1: delete 8 header lines of CT file
# sed command 2: remove trailing space(s) at end of lines
# sed command 3: remove spaces between values on a line
# sed command 4: delete all lines not ending with a site code like 'Kxxx', or 'PAIH'
# sed command 5: delete all lines ending with the site code 'KORA'
# sed command 6: replace comma between fields with a single | character
# sed command 7: replace T separator between date and time with a space
# sed command 8: append time zone ID "+00" to end of datetime string
# sed command 9: append "|" and bogus satellite ID to end of full line
# sed command 10: strip out the latitude field and its terminating "|"
# sed command 11: strip out the longitude field and its terminating "|"

sed '
1,8 d
s/  *$//
s/  *//g
/.*,K[A-Z]\{3\}$\|.*,PAIH/ !d
 /.*,KORA$/ d
s/,/|/g
s/\([0-9]\)T\([0-9]\)/\1 \2/g
s/\([:][0-9][0-9][.][0-9]\)|/\1+00|/g
s/\(.*\)/\1|satellite/
s/\(-*[0-9][0-9]*[.][0-9][0-9]*|\)//2
s/\(-*[0-9][0-9]*[.][0-9][0-9]*|\)//2' <$infile >$outfile

# edit the outfile in place, replacing literal "satellite" with the satellite ID
# Can't do this substitution above, the !d gives an error with the double-quoted
# sed commands enclosure - why?
sed -i "s/satellite/$bird/g" $outfile

ls -al $outfile
head $outfile
# rm -v $outfile

exit
