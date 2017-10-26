#!/bin/sh
############################################################################
#
# KWAJ_time.sh     Morris/SAIC, GPM GV     January 2007
#
# Process table in TSDIS Coincidence File to extract the overpass time
# for site 'KWAJ' for a given CT file of date = 'yymmdd' (Arg 1) and
# orbit 'nnnnn' (Arg 2).
#
# Files:
#   CT.yymmdd.6      (input; yymmdd specified as first argument)
#
###########################################################################

CTDIR=/data/coincidence_table
yymmdd=$1
orbit=$2

# sed command 1: remove trailing space(s) at end of lines
# sed command 2: replace spaces between fields with single | character
# sed command 3: replace T separator between date and time with a space

grep 'KWAJ' ${CTDIR}/CT.${yymmdd}.6 | grep $orbit | \
sed '
s/  *$//
s/  */|/g
s/\([0-9]\)T\([0-9]\)/\1 \2/g' | cut -f4 -d '|' # | OPTIONAL PIPE TO sed BELOW,
#sed -e 's/ /./' -e 's/-/./g' -e 's/:/./g'  # UNCOMMENT TO USE '.' BETWEEN ALL FIELDS

exit
