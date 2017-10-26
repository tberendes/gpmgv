#!/bin/sh
############################################################################
#
# CT_to_DB.sh     Morris/SAIC, GPM GV     August 2006
#
# Process table in TSDIS Coincidence File into a delimited format ready
# to be loaded into database (PostGRESQL), spreadsheet etc. 
# Use '|' as delimiters.
#
# Files:
#   CT.yymmdd.6      (input; yymmdd varies by date)
#   CT.yymmdd.6.unl  (output; delimited fields, stripped of headings)
#
###########################################################################

umask 0002

#mydir=/Users/kennethmorris/Documents/GPM/GPM_GV/data/
#myfile=CT.`date -u "+%y%m%d"`.6
#infile=${mydir}${myfile}
#outfile=${mydir}${myfile}.unl
infile=$1
outfile=$2

# sed command 1: delete 9 header lines of CT file
# sed command 2: remove trailing space(s) at end of lines
# sed command 3: replace spaces between fields with single | character
# sed command 4: replace T separator between date and time with a space
# sed command 5: delete all lines where radar ID and Name aren't like 'Kxxx'
# sed command 6: append time zone ID "+00" to end of datetime string

sed '
1,9 d
s/  *$//
s/  */|/g
s/\([0-9]\)T\([0-9]\)/\1 \2/g
/^[0-9][0-9]*|K[A-Z]\{3\}|K[A-Z]\{3\}/ !d
s/\([.][0-9][0-9][0-9]\)|/\1+00|/g' <$infile >$outfile

# process and append the one-off site overpasses to the .unl file
grep -E '(DARW|RMOR|RGSN|KWAJ)' $infile | sed '
s/  *$//
s/  */|/g
s/\([0-9]\)T\([0-9]\)/\1 \2/g
s/\([.][0-9][0-9][0-9]\)|/\1+00|/g'  >>$outfile

#more $outfile

exit
