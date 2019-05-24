README file for GPM GV software for comparison of radar reflectivity between 
TRMM PR and ground radars, using gridded data contained in netCDF grid files.  

; Copyright © 2008, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;

Within the VN framework, a script (e.g., doSiteSpecificComparisons.sh) queries 
the gpmgv database to assemble a control file, and invokes IDL and the IDL 
batch file doSiteSpecificComparisons.bat to compile and run the main procedure, 
doSiteSpecificComparisons.pro.  The calling script provides the control file 
pathname to doSiteSpecificComparisons.pro via the environment variable SSCFILES.
The query parameters in the script determine whether the PR netCDF data is 
compared to: (a) the 2A-55-derived GV netCDF data, or (b) the REORDER-derived 
GV netCDF data.  Each of the GV types are stored in separate netCDF files.

The top level IDL procedure, doSiteSpecificComparisons.pro, opens, reads, and 
parses the control file to determine the set of site overpass events (as 
determined by the listed PR and GV netCDF file pairs to process) for which to 
compute reflectivity comparison statistics for a site, and calls the procedure 
comparison_PR_GV_dBZ.pro with the list of files to process for the site.  This 
is repeated for each site listed in the control file.  comparison_PR_GV_dBZ.pro 
reads the reflectivity and other grid fields from the PR and GV netCDF files, 
computes reflectivity difference statistics for the site, and produces a series 
of graphs and tabular summaries of the site-specific statistics.  The procedure 
common_area.pro is called to stratify the data by: (1) rain type, and (2) 
underlying surface type. The procedure statistics_table.pro produces tabular 
summaries of reflectivity statistics, which it writes to a text file.  The same 
is true for standardError_table.pro, except standard error is tabulated.  The 
procedure bias_table.pro produces tables of PR-GV reflectivity bias stratified 
by rain type and by underlying surface type.  Histograms of PR and GV 
reflectivity, ans scatter plots of PR vs. GV reflectivity, also stratified by 
rain type and by underlying surface type, are produced by plot_histogram.pro 
and plot_scaPoint.pro, respectively, which output the graphics to Postscript 
files.


Files:
------
doSiteSpecificComparisons.bat
doSiteSpecificComparisons.pro
comparison_PR_GV_dBZ.pro
commonArea.pro
statistics_table.pro
standardError_table.pro
standard_error.pro
bias_table.pro
plot_histogram.pro
plot_scaPoint.pro
bias.pro
mean_std.pro
README.comparez.txt (this file)
------

Bob Morris, GPM GV (SAIC)
kenneth.r.morris@nasa.gov
August, 2008