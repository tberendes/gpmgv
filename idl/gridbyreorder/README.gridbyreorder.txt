README file for ground radar resampling configuration and driver routines for 
the GPM GV Validation Network, for software written in IDL.

; Copyright © 2008, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;

These routines prepare a control file used as input by the radar resampling 
executable program 'qreou' (called REORDER), and run REORDER.  The program 
qreou is a separately-compiled C and FORTRAN language routine not included in 
this code set.  A shell script (e.g., reorder1CUF.sh) queries the gpmgv database
and builds a control file listing the sites and radar data files to be used as
input to REORDER.  The script passes the name of the control file to the IDL 
routines via the environment variable REO_1CUF_LIST, and invokes IDL and the
batch file reorderUF_multi.bat.  The IDL procedure reorder_1cuf_multi.pro is 
then compiled and run by the batch file.  This procedure opens and reads the 
control file specified by REO_1CUF_LIST, accesses an uncompressed copy of each 
of the 1CUF (Universal Format) files listed in the control file, and calls the 
procedure mk_qreo_multi.pro to build a REORDER control file for each 1CUF to be
processed.  The REORDER control file and the 1CUF file copy are renamed to 
fixed file names, and qreou is executed by reorder_1cuf_multi.pro for each case 
listed in the REO_1CUF_LIST control file.  

The REORDER control files produced by mk_qreo_multi.pro specify that the 
output grid should be written to a netCDF file.  The domain and resolution 
attributes of the grid fields in the REORDER radar resampling are set to be 
identical to those of the corresponding the PR and GV netCDF grids (see 
gridgen/README.gridgen.txt), as controlled by the values specified within 
mk_qreo_multi.pro.

The procedures reorder_1cuf_multi.pro and mk_qreo_multi.pro have logic to 
handle the differences between the UF files that have been provided for each 
radar currently known to the GPM GV Validation Network.

Files:
------
reorderUF_multi.bat
reorder_1cuf_multi.pro
mk_qreo_multi.pro
README.gridbyreorder.txt (this file)
------

Bob Morris, GPM GV (SAIC)
kenneth.r.morris@nasa.gov
August, 2008