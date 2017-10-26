#!/bin/sh
############################################################################
#
# CT_to_DBmore.sh     Morris/SAIC, GPM GV     Feb 2008
#
# Process table in TSDIS Coincidence File into a delimited format ready
# to be loaded into database (PostGRESQL), spreadsheet etc., for a select
# list of sites not previously processed.
# Use '|' as delimiters.
#
# Files:
#   CT.yymmdd.6      (input; yymmdd varies by date)
#   CT.yymmdd.6.unl  (output; delimited fields, stripped of headings)
#
###########################################################################

infile=$1
outfile=$2

# sed command 1: remove trailing space(s) at end of lines
# sed command 2: replace spaces between fields with single | character
# sed command 3: replace T separator between date and time with a space
# sed command 4: append time zone ID "+00" to end of datetime string

# process and append the one-off site overpasses to the .unl file
#grep -E '(DARW|RMOR)' $infile | sed '
grep -E '(KWAJ)' $infile | sed '
s/  *$//
s/  */|/g
s/\([0-9]\)T\([0-9]\)/\1 \2/g
s/\([.][0-9][0-9][0-9]\)|/\1+00|/g'  >>$outfile


#more $outfile

exit
