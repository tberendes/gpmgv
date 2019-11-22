README file for GPM GV software for extraction of descriptive metrics for TRMM 
PR overpasses of GPM Validation Network ground radar sites.  Metrics include
the areal coverage of rain at the site, and the percentages of convective and
stratiform rain type in the rain areas, and are stored in the 'gpmgv' database.
These procedures are of limited use outside of the gpmgv database environment.

; Copyright © 2008, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;

The top level IDL procedures are getMetadata2A23.pro and getMetadata2A25.pro, 
which are compiled and invoked under IDL by the get2A23MetaIDL.bat and 
get2A25MetaIDL.bat Batch files, respectively.  IDL and the batch files are
normally invoked by a set of bash shell scripts which query a database to
prepare a control file specifying the PR and GV products to be analyzed.  The
top level procedures extract two environment variables set by the shell scripts 
which specify the datestamp of the PR files to be processed and the location of 
the control file listing the PR files to process and the sites overpassed in 
the given orbit.  See the prologue of getMetadata2A23.pro for a description of 
these inputs and the master script for metadata extraction runs.

The procedures getMetadata2A23.pro and getMetadata2A25.pro read the input 
control file, obtain and uncompressed copy of the TRMM PR products listed in 
the control file, and call extract2a23meta.pro and extract2a25meta.pro,
respectively, to generate the required PR rain flag, type, and bright band 
height grids over the ground radar site locations listed in the control file. 
The domain and resolution attributes of the grid fields used here are identical 
to those of the VN's default PR and GV netCDF grids.  These grid definition 
parameters are hard coded in the extract2a2x.pro routines to use a 4 km 
horizontal grid spacing of 75x75 points over a 300x300 km domain centered on
the location of the overpassed ground radar site(s).  The grids computed in the
extract2a2x.pro routines are temporary, memory resident, and discarded once 
the necessary metadata computations are finished.  

Metadata values are computed: (1) over the full grid, and (2) for only those 
points within 100 km of the ground radar site.

The extract2a2x.pro routines compute the necessary site overpass metadata and 
write the results to a delimited text file with the associated key values 
needed to identify the metadata values in the 'gpmgv' postgresql database. 
The shell scripts then load the metadata files to the database once the IDL 
metadata extraction routines are complete.

This listing represents all configuration-managed routines in the getmetadata
directory, including both the VN baseline applications, and old and informal
applications.  Baseline application routines are indicated by a "*" after the
file name.  The baseline (operational) versions of these files are located on
the VN data server:

      ds1-gpmgv.gsfc.nasa.gov:/home/gvoper/idl/

Files:
------
access2A25grids.pro
access2A55.pro
access2a23.pro *
access2a25.pro *
extract2a23meta.pro *
extract2a25meta.pro *
get2A23MetaIDL.bat *
get2A25MetaIDL.bat *
get2A55MetaIDL.bat
get2A55Metadata.pro
getMetadata2A23.pro *
getMetadata2A25.pro *
getMetadata2A25grid.pro
get_gosan_rain_events_from_reo.pro
README.getmetadata.txt (this file)
-----

Bob Morris, GPM GV (SAIC)
kenneth.r.morris@nasa.gov
August, 2008
February, 2012 (Updated)
