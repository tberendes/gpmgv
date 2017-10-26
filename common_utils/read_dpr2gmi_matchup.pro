;===============================================================================
;+
; Copyright © 2014, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
;    read_dpr2gmi_matchup.pro           Morris/SAIC/GPM_GV      Oct. 2014
;
; DESCRIPTION
; -----------
; Wrapper for the function read_dpr_gmi_swath_match_netcdf(), which reads
; caller-specified data from DPR/GMI along-swath matchup netCDF files. Takes
; care of: copying and, if needed, uncompressing the netCDF file; opening and
; checking the netCDF files for errors; setting up the data arrays; reading the
; file variables; and loading the data into a structure to be returned to the
; caller.
;
; If the MERGE2AGPROF keyword is set, then additional science variables from the
; original TMI 2AGPROF file used in the matchup are read from the 2AGPROF file, 
; subsetted to the same set of TMI scans/rays as in the PR-TMI matchup, and 
; concatenated into the structure.  The reading, subsetting and concatenation 
; are performed by the procedure merge_2a12_to_pr_tmi_swath_match.
;
; PARAMETERS
; ----------
; filepath           - STRING, Full file pathname to netCDF matchup file (Input)
;
; merge2AGPROF       - Binary keyword.  If set, then read/subset/concatenate
;                      additional TMI variables from the original 2AGPROF file to
;                      the returned structure.
;
; dirLoc2AGPROF      - Directory in which to look for the 2AGPROF file whose name
;                      is listed in the orbit match netCDF file.
;
; RETURNS
; -------
; matchup_struct     - Structure containing the metadata structures and scalar
;                      and array variables in the matchup file; or -1 if errors.
;
; HISTORY
; -------
; 10/16/14 by Bob Morris, GPM GV (SAIC)
;  - Created from read_pr2tmi_matchup.pro
;
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;===============================================================================

function read_dpr2gmi_matchup, filepath, MERGE2AGPROF=merge2AGPROF, $
                               DIRLOC2AGPROF=dirLoc2AGPROF

@gpm_orbit_match_nc_structs.inc

merge2AGPROF = KEYWORD_SET(merge2AGPROF)

datastruc = -1  ; initialize return value for failures

cpstatus = uncomp_file( filepath, myfile )
if(cpstatus eq 'OK') then begin
  status = 1   ; init to FAILED
  mygeometa = swath_match_meta
  myflags = field_flags_swath_gpm
  myfiles =  files_meta_swath_gpm
  status = read_dpr_gmi_swath_match_netcdf( myfile, matchupmeta=mygeometa, $
     fieldflags=myflags, filesmeta=myfiles )

  if ( status NE 0 ) THEN BEGIN
    ; print, "Non-zero status returned from read_dpr_gmi_swath_match_netcdf(): ", status
     GOTO, badfile
  endif

 ; create data field arrays of correct dimensions and read data fields
  nscan = mygeometa.num_scans
  nray = mygeometa.num_rays
  xcorners=fltarr(4,nscan,nray)
  ycorners=fltarr(4,nscan,nray)
  GMIlatitude=fltarr(nscan,nray)
  GMIlongitude=fltarr(nscan,nray)
  surfaceType=intarr(nscan,nray)
  surfacePrecipitation=fltarr(nscan,nray)
  rnflag=intarr(nscan,nray)
  pixelStatus=intarr(nscan,nray)
  PoP=intarr(nscan,nray)
  rayIndex=lonarr(nscan,nray)
  BBheight=intarr(nscan,nray)
  precipRateSurface=fltarr(nscan,nray)
  surfRain_2BDPRGMI=fltarr(nscan,nray)
  numPRinRadius=intarr(nscan,nray)
  numPRsfcRain=intarr(nscan,nray)
  numDPRGMIsfcRain=intarr(nscan,nray)
  numConvectiveType=intarr(nscan,nray)
  numPRrainy=intarr(nscan,nray)

  status = read_dpr_gmi_swath_match_netcdf( myfile, $
   ; data completeness parameters for averaged values:
    numPRinRadius_int=numPRinRadius, numPRsfcRain_int=numPRsfcRain,           $
    numDPRGMIsfcRain_int=numDPRGMIsfcRain,                                    $

   ; averaged/summed DPR values at GMI footprint locations:
    precipRateSurface_pr=precipRateSurface,                                   $
    surfRain_2BDPRGMI=surfRain_2BDPRGMI,                                      $
    numConvectiveType_int=numConvectiveType, numPRrainy_int=numPRrainy,       $
    xCorners=xCorners, yCorners=yCorners,                                     $
    GMIlatitude=GMIlatitude, GMIlongitude=GMIlongitude,                       $

   ; GMI science values at earth surface level, or as ray summaries:
    surfacePrecipitation=surfacePrecipitation, sfctype_int=surfaceType,       $
    pixelStatus_int=pixelStatus, PoP_int=PoP, BBheight=BBheight,              $
    gmi_idx_long=rayIndex )

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
   print, "Non-zero status returned from read_dpr_gmi_swath_match_netcdf(): ", status
   GOTO, errorExit
endif

; define and fill the data structure with dpr2gmi matchup fields
datastruc = {   matchupmeta : mygeometa, $
                 fieldflags : myflags, $
                  filesmeta : myfiles, $
                    gmirain : surfacePrecipitation, $
                 gmisfctype : surfaceType, $
                gmidataflag : pixelStatus, $
                        PoP : PoP, $
                  gmi_index : rayIndex, $
                   BBheight : BBheight, $
                      numpr : numPRinRadius, $
                     prrain : precipRateSurface, $
                    numprrn : numPRsfcRain, $
                    comrain : surfRain_2BDPRGMI, $
                   numcomrn : numDPRGMIsfcRain, $
                  numprconv : numConvectiveType, $
                 numprrainy : numPRrainy, $
                GMIlatitude : GMIlatitude, $
               GMIlongitude : GMIlongitude, $
                   xcorners : xCorners, $
                   ycorners : yCorners }

;if ( merge2AGPROF ) then begin
;   mergeStatus = 0
;   merge_2a12_to_pr_tmi_swath_match, datastruc, mergeStatus, DIRLOC2AGPROF=dirLoc2AGPROF
;   if mergeStatus NE 0  THEN BEGIN
;      print, "Non-zero status returned from merge_2a12_to_pr_tmi_swath_match: ", mergeStatus
;      GOTO, errorExit
;   endif
;endif

errorExit:

; return the structure to the caller
return, datastruc

END
