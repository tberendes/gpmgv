;+
; Copyright © 2008, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
;-------------------------------------------------------------------------------
; doSiteSpecificComparisons.pro    Bob Morris, GPM GV (SAIC)    January 2007
;
; DESCRIPTION
;
; Reads delimited text file listing a site name and the number of netcdf file
; pairs to process for the site, followed by the listing of the names of
; the file pairs on separate lines, one file pairing per line.  These repeat for
; each site to be processed in a run of this program.  See the script
; doSiteSpecificComparisons.sh for how the delimited file is created.
;
; FILES
;
; /data/tmp/doSiteSpecificComparisons.txt (INPUT) - lists sites/files to
;    process in this run.  File pathname is specified by the SSCFILES
;    environment variable's value.
;
; MANDATORY ENVIRONMENT VARIABLES
;
; 1) SSCFILES - fully-qualified file pathname to INPUT file
;                'doSiteSpecificComparisons.txt'
;
;-------------------------------------------------------------------------------
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-

pro doSiteSpecificComparisons

common PR_GV, rainType_2a23, rainType_2a54, dbz_1c21, dbz_2a25, dbz_2a55, $
              oceanFlag, epsilon, epsilon_0
common groundSite, siteLong, siteLat, siteID

Heights = [3.0, 4.5, 6.0, 7.5]   ; Altitude above ground (km)
NHeights = N_ELEMENTS(Heights)

cd, '/home/morris/swdev/idl/dev/comparez'  ; since output files are relative to here

; NEED SOME ERROR CHECKING ON THESE ENVIRONMENT VARIABLE VALUES (CHECK FOR
; NULLS)
;
; find, open the input file listing the NEXRAD sites and netCDF grid files
;
FILES4ZCOMP = GETENV("SSCFILES")
OPENR, lun0, FILES4ZCOMP, ERROR=err, /GET_LUN

; initialize the variable into which file records are read as strings
data2 = ''
filepr = ''

; create the output directory 'results' for the stats/plots
out_dir = './results'
spawn, 'mkdir -p ' + out_dir

While not (EOF(lun0)) Do Begin 
;  read the '|'-delimited input file record into a single string
   READF, lun0, data2

;  parse data2 into its component fields: site ID, number of file pairs

   parsed=strsplit( data2, '|', /extract )
   siteID = parsed[0]
   npairs=fix( parsed[1] )
   print, ""
   print, siteID, "  ", npairs

   prfile = strarr(npairs)    & prfile[*] = ""
   gvfile = strarr(npairs)    & gvfile[*] = ""

   for i=0, npairs-1 do begin

; NEED TO LOOP OVER EACH SITE'S FILES INSIDE comparison_PR_GV_dBZ.pro !!!!

      READF, lun0, filepr
;      print, i+1, ": ", filepr
;     parse the delimited string into two file pathnames
      parsed=strsplit( filepr, '|', /extract )
      prfile[i] = parsed[0]
      gvfile[i] = parsed[1]
      print, i+1, "   ", prfile[i], "   ", gvfile[i]

   endfor

; do the Z comparisons for this site and height
for ilev = 0, N_ELEMENTS(Heights)-1 do begin
   comparison_PR_GV_dBZ, Heights[ilev], npairs, prfile, gvfile
endfor

EndWhile

end

@comparison_PR_GV_dBZ.pro
