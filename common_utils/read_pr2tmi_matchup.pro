;===============================================================================
;+
; Copyright © 2012, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
;    read_pr2tmi_matchup.pro           Morris/SAIC/GPM_GV      Dec. 2012
;
; DESCRIPTION
; -----------
; Wrapper for the function read_pr_tmi_swath_match_netcdf(), which reads
; caller-specified data from PR/TMI along-swath matchup netCDF files. Takes
; care of: copying and, if needed, uncompressing the netCDF file; opening and
; checking the netCDF files for errors; setting up the data arrays; reading the
; file variables; and loading the data into a structure to be returned to the
; caller.
;
; If the MERGE2A12 keyword is set, then additional science variables from the
; original TMI 2A-12 file used in the matchup are read from the 2A-12 file, 
; subsetted to the same set of TMI scans/rays as in the PR-TMI matchup, and 
; concatenated into the structure.  The reading, subsetting and concatenation 
; are performed by the procedure merge_2a12_to_pr_tmi_swath_match.  The merged 
; variables depend on the TRMM version of the 2A12 file.  Refer to the prologue
; of read_2a12_file.pro.
;
; PARAMETERS
; ----------
; filepath           - STRING, Full file pathname to netCDF matchup file (Input)
;
; merge2a12          - Binary keyword.  If set, then read/subset/concatenate
;                      additional TMI variables from the original 2A12 file to
;                      the returned structure.
;
; dirLoc2a12         - Directory in which to look for the 2A-12 file whose name
;                      is listed in the orbit match netCDF file.
;
; RETURNS
; -------
; matchup_struct     - Structure containing the metadata structures and scalar
;                      and array variables in the matchup file; or -1 if errors.
;
; HISTORY
; -------
; 12/17/12 by Bob Morris, GPM GV (SAIC)
;  - Created.
;
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;===============================================================================

function read_pr2tmi_matchup, filepath, MERGE2A12=merge2a12, $
                              DIRLOC2A12=dirLoc2a12

merge2a12 = KEYWORD_SET(merge2a12)

datastruc = -1  ; initialize return value for failures

cpstatus = uncomp_file( filepath, myfile )
if(cpstatus eq 'OK') then begin
  status = 1   ; init to FAILED
  mygeometa = get_geo_match_nc_struct( 'swathmatch' )
  myflags = get_geo_match_nc_struct( 'fields_swath' )
  myfiles =  get_geo_match_nc_struct( 'files' )
  status = read_pr_tmi_swath_match_netcdf( myfile, matchupmeta=mygeometa, $
     fieldflags=myflags, filesmeta=myfiles )

  if ( status NE 0 ) THEN BEGIN
    ; print, "Non-zero status returned from read_pr_tmi_swath_match_netcdf(): ", status
     GOTO, badfile
  endif

 ; create data field arrays of correct dimensions and read data fields
  nscan = mygeometa.num_scans
  nray = mygeometa.num_rays
  xcorner=fltarr(4,nscan,nray)
  ycorner=fltarr(4,nscan,nray)
  sfclat=fltarr(nscan,nray)
  sfclon=fltarr(nscan,nray)
  sfctyp=intarr(nscan,nray)
  sfcrain=fltarr(nscan,nray)
  rnflag=intarr(nscan,nray)
  dataflag=intarr(nscan,nray)
  PoP=intarr(nscan,nray)
  freezingHeight=intarr(nscan,nray)
  tmi_index=lonarr(nscan,nray)
  BBheight=intarr(nscan,nray)
  nearSurfRain=fltarr(nscan,nray)
  nearSurfRain_2b31=fltarr(nscan,nray)
  numPRinRadius=intarr(nscan,nray)
  numPRsfcRain=intarr(nscan,nray)
  numPRsfcRainCom=intarr(nscan,nray)
  numConvectiveType=intarr(nscan,nray)

  status = read_pr_tmi_swath_match_netcdf( myfile, $
    xCorners=xCorner, yCorners=yCorner, $
    TMIlatitude=sfclat, TMIlongitude=sfclon, $
    surfaceRain=sfcrain, sfctype_int=sfctyp, rainflag_int=rnFlag, $
    dataflag_int=dataFlag, freezingHeight_int=freezingHeight, $
    PoP_int=PoP, BBheight=BBheight, tmi_idx_long=tmi_index, $
    nearSurfRain_pr=nearSurfRain, nearSurfRain_2b31=nearSurfRain_2b31, $
    numPRinRadius_int=numPRinRadius, numPRsfcRain_int=numPRsfcRain, $
    numPRsfcRainCom_int=numPRsfcRainCom, numConvectiveType=numConvectiveType )

  badfile:
  command3 = "rm -v " + myfile
  spawn, command3
endif else begin
  print, 'Cannot copy/unzip geo_match netCDF file: ', filepath
  print, cpstatus
;  command3 = "rm -v " + myfile
;  spawn, command3
  goto, errorExit
endelse

if ( status NE 0 ) THEN BEGIN
   print, "Non-zero status returned from read_pr_tmi_swath_match_netcdf(): ", status
   GOTO, errorExit
endif

; define and fill the data structure with pr2tmi matchup fields
datastruc = {   matchupmeta : mygeometa, $
                 fieldflags : myflags, $
                  filesmeta : myfiles, $
                    tmirain : sfcRain, $
                 tmisfctype : sfctyp, $
                  tmirnflag : rnFlag, $
                tmidataflag : dataFlag, $
             freezingHeight : freezingHeight, $
                        PoP : PoP, $
                  tmi_index : tmi_index, $
                   BBheight : BBheight, $
                      numpr : numPRinRadius, $
                     prrain : nearSurfRain, $
                    numprrn : numPRsfcRain, $
                    comrain : nearSurfRain_2b31, $
                   numcomrn : numPRsfcRainCom, $
                  numprconv : numConvectiveType, $
                TMIlatitude : sfclat, $
               TMIlongitude : sfclon, $
                   xcorners : xCorner, $
                   ycorners : yCorner }

if ( merge2a12 ) then begin
   mergeStatus = 0
   merge_2a12_to_pr_tmi_swath_match, datastruc, mergeStatus, DIRLOC2A12=dirLoc2a12
   if mergeStatus NE 0  THEN BEGIN
      print, "Non-zero status returned from merge_2a12_to_pr_tmi_swath_match: ", mergeStatus
      GOTO, errorExit
   endif
endif

errorExit:

; return the structure to the caller
return, datastruc

END
