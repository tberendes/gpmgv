README file for GPM GV software for creation of TRMM PR and ground radar netCDF
grid files.  

; Copyright © 2008, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;

The top level IDL procedure is get_pr_and_gv_ncgrids.pro, which is 
compiled and invoked in IDL by the get_pr_and_gv_ncgrids.bat Batch file, which
itself is normally invoked by a bash shell script which queries a database to
prepare a control file specifying the PR and GV products to be analyzed.  The
batch file extracts two environment variables set by the shell script and 
passes their values as input parameters to the get_pr_and_gv_ncgrids.pro 
procedure.  See the prologue of get_pr_and_gv_ncgrids.pro for a description of 
these inputs.

The procedure get_pr_and_gv_ncgrids.pro reads the input control file, reads 
data fields from the TRMM PR products listed in the control file, and calls
generate_pr_ncgrids.pro to generate the required PR netCDF grids over the
ground radar site locations listed in the control file. It then calls the
procedures generate_2a55_ncgrids.pro, generate_2a54_ncgrids.pro, and
generate_2a53_ncgrids.pro to generate the matching ground radar (GV) netCDF grid
files, taking the TRMM GV products 2A-55, 2A-54, and 2A-53, respectively, as
the input data sources.

The PR and GV netCDF files that are written to are created by the procedures 
gen_pr_netcdf_template.pro and gen_gv_netcdf_template.pro, which is invoked by
get_pr_and_gv_ncgrids.pro.  These empty 'template' netCDF files are copied and
renamed to a site/event specific name, and handed off to the grid generation
routines 'generate_XX_ncgrids.pro' (described above) to be populated with data.
The domain and resolution attributes of the grid fields in the netCDF files are
identical between the PR and GV netCDF grids, and are controlled by the values 
specified in the INCLUDE file 'grid_def.inc'.  These grid definition parameters
have a dependency on the TRMM GV products 2A-5x, which contain data in already
gridded form, and which (normally) are simply resampled from 2 km to 4 km
horizontal resolution for output to the GV netCDF files.

Files:
------
get_pr_and_gv_ncgrids.bat
get_pr_and_gv_ncgrids.pro
gen_pr_netcdf_template.pro
gen_gv_netcdf_template.pro
generate_pr_ncgrids.pro
generate_2a55_ncgrids.pro
generate_2a54_ncgrids.pro
generate_2a53_ncgrids.pro
README.gridgen.txt (this file)
------

Bob Morris, GPM GV (SAIC)
kenneth.r.morris@nasa.gov
August, 2008