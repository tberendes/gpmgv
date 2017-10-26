#!/bin/sh
############################################################################
#
# new_CT_to_DB_DARW.sh     Morris/SAIC, GPM GV     March 2015
#
# Process tables in PPS Coincidence Files into a delimited format ready
# to be loaded into database (PostGRESQL), spreadsheet etc. 
# Use '|' as delimiters.  Only processes overpasses for site "DARW".  Must
# run selected commands in new_mosaicCTmatch.sql manually after this script
# finishes.
#
# Files/Arguments:
#   CT.bird.yyyymmdd.ddd.txt   Input; yyyymmdd.ddd varies by date, bird varies
#                              by satellite ID, e.g., TRMM, GPM, etc.
#   DARW_CT_bird.unl           Internal; delimited CT fields, stripped of
#                              headings, whitespace, and in a format ready to
#                              be loaded into database table.
#
#
###########################################################################

umask 0002

mydir="/data/gpmgv/coincidence_tables/"

# set the satellite ID
bird=GPM
outfile=${mydir}NOV14_CT_${bird}.unl
rm -v $outfile

for infile in `ls ${mydir}2015/*/*/CT.${bird}.*.txt`
  do

# sed command 1: delete 8 header lines of CT file
# sed command 2: remove trailing space(s) at end of lines
# sed command 3: remove spaces between values on a line
# sed command 4: delete all lines not ending with site code 'DARW'
# sed command 6: delete all lines ending with the site code 'KORA'
# sed command 7: replace comma between fields with a single | character
# sed command 8: replace T separator between date and time with a space
# sed command 9: append time zone ID "+00" to end of datetime string
# sed command 10: append "|" and bogus satellite ID to end of full line
# sed command 11: strip out the latitude field and its terminating "|"
# sed command 12: strip out the longitude field and its terminating "|"

sed '
1,8 d
s/  *$//
s/  *//g
/.*,PGUA$\|.*,TJUA$\|.*,PAEC$\|.*,PHMO$\|.*,PHKI/ !d
s/,/|/g
s/\([0-9]\)T\([0-9]\)/\1 \2/g
s/\([:][0-9][0-9][.][0-9]\)|/\1+00|/g
s/\(.*\)/\1|satellite/
s/\(-*[0-9][0-9]*[.][0-9][0-9]*|\)//2
s/\(-*[0-9][0-9]*[.][0-9][0-9]*|\)//2' <$infile  >>$outfile

done

# edit the outfile in place, replacing literal "satellite" with the satellite ID
# Can't do this substitution above, the !d gives an error with the double-quoted
# sed commands enclosure - why?
sed -i "s/satellite/$bird/g" $outfile

# ls -al $outfile
# head $outfile
# rm -v $outfile
echo "Load following .unl file from new_CT_to_DB_DARW.sh to database:" 
ls -al $outfile
#cat $outfile
#exit

echo "\copy ct_temp(orbit,proximity,overpass_time,radar_id,radar_name)\
 FROM '${outfile}' WITH DELIMITER '|'" | psql -a -d gpmgv

exit
