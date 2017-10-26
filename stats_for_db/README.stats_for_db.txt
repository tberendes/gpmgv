README file for GPM GV software for comparison of radar reflectivity between 
TRMM PR and ground radars, using gridded data contained in netCDF grid files, 
with statistics written to a delimited file for loading into the 'gpmgv' 
database.  These procedures are of little use outside of the gpmgv database 
environment.


; Copyright © 2008, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;

In this set of IDL applications, the PR netCDF reflectivity data is 
compared to: (a) the 2A-55-derived GV netCDF data, and (b) the REORDER-derived 
GV netCDF data.  Each of the GV types are stored in separate netCDF files.

The top level IDL procedure, stratified_by_dist_stats_to_dbfile_55_or_reo.pro, 
walks through the list of PR netCDF files in the netcdf/PR directory; finds the 
matching GV and GV-REORDER netCDF file(s) for each PR netCDF file; copies, 
uncompresses, opens, and reads necessary data fields from each netCDF file; 
does some preprocessing and cleanup of the data fields; and calls the procedure 
stratify_diffs21dist to compute the reflectivity differences for the case.  The 
stratified reflectivity differences are then written to a delimited ASCII text 
file by printf_stat_struct21dist.pro, in a format ready to be loaded into the 
'gpmgv' database.  This sequence is repeated for each PR netCDF file.

Other top-level programs in the /stats_for_db directory perform similar 
functions, but for different stratifications of the data, or with different 
data constraints.  These procedures include:

- stratified_by_angle_stats_to_dbfile.pro
- stratified_by_dist_stats_to_dbfile.pro
- stratified_by_sfc_stats_to_dbfile.pro
- stratified_stats_to_dbfile.pro

Files:
------
stratified_by_dist_stats_to_dbfile_55_or_reo.pro
stratified_by_dist_stats_to_dbfile.pro
stratify_diffs21dist.pro
stratify_diffs.pro
printf_stat_struct21dist.pro
stratified_by_angle_stats_to_dbfile.pro
stratify_diffs21angle.pro
printf_stat_struct21angle.pro
stratified_by_sfc_stats_to_dbfile.pro
stratify_diffs21.pro
printf_stat_struct21.pro
stratified_stats_to_dbfile.pro
printf_stat_struct7.pro
README.stats_for_db.txt (this file)
------

Bob Morris, GPM GV (SAIC)
kenneth.r.morris@nasa.gov
August, 2008