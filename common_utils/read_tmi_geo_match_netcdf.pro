;===============================================================================
;+
; Copyright © 2011, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; read_tmi_geo_match_netcdf.pro           Morris/SAIC/GPM_GV      June 2011
;
; DESCRIPTION
; -----------
; Reads caller-specified data and metadata from TMI-GR matchup netCDF files. 
; Returns status value: 0 if successful read, 1 if unsuccessful or internal
; errors or inconsistencies occur.  File must be read-ready (unzipped/
; uncompressed) before calling this function.
;
; PARAMETERS
; ----------
; ncfile               STRING, Full file pathname to netCDF matchup file (Input)
; matchupmeta          Structure holding general and algorithmic parameters (I/O)
; sweepsmeta           Array of Structures holding sweep elevation angles,
;                      and sweep start times in unix ticks and ascii text (I/O)
; sitemeta             Structure holding GR site location parameters (I/O)
; fieldFlags           Structure holding "data exists" flags for gridded TMI
;                        data variables (I/O)
; filesmeta            Structure holding TMI and GR file names used in matchup (I/O)
;                      -- See file geo_match_nc_structs.inc for definition of
;                         the above structures.
; GR_Z_along_TMI         FLOAT 2-D array of horizontally-averaged, QC'd GR
;                         reflectivity along TMI field of view (with parallax
;                         adjustments), dBZ (I/O)
; GR_Z_Max_along_TMI     FLOAT 2-D array, Maximum value of GR reflectivity
;                         bins included in GR_Z_along_TMI, dBZ (I/O)
; GR_Z_StdDev_along_TMI  FLOAT 2-D array, Standard Deviation of GR reflectivity
;                         bins included in GR_Z_along_TMI, dBZ (I/O)
; grexpect               INT number of GR radar bins geometrically mapped to
;                         matchup sample volume for GR_Z_along_TMI (I/O)
; grreject               INT number of bins below GR dBZ cutoff in above (I/O)
; GR_RR_along_TMI        FLOAT 2-D array of horizontally-averaged, QC'd GR
;                         rain rate along TMI field of view (with parallax
;                         adjustments), mm/h (I/O)
; GR_RR_Max_along_TMI    FLOAT 2-D array, Maximum value of GR rain rate
;                         bins included in GR_RR_along_TMI, mm/h (I/O)
; GR_RR_StdDev_along_TMI FLOAT 2-D array, Standard Deviation of GR rain rate
;                         bins included in GR_RR_along_TMI, mm/h (I/O)
; n_gr_rr_rejected     INT number of bins below GR rainrate cutoff in above (I/O)
; GR_Z_VPR             FLOAT 2-D array of horizontally-averaged, QC'd GR
;                       reflectivity along local vertical above TMI footprint, dBZ (I/O)
; GR_Z_Max_VPR         FLOAT 2-D array, Maximum value of GR reflectivity
;                       bins included in GR_Z_VPR, dBZ (I/O)
; GR_Z_StdDev_VPR      FLOAT 2-D array, Standard Deviation of GR reflectivity
;                       bins included in GR_Z_VPR, dBZ (I/O)
; n_gr_vpr_expected         INT number of GR radar bins geometrically mapped to
;                         matchup sample volume for GR_Z_VPR (I/O)
; n_gr_vpr_rejected         INT number of bins below GR dBZ cutoff in above (I/O)
; topHeight            FLOAT 2-D array of mean GR beam top along TMI field
;                        of view (with parallax adjustments) (I/O)
; bottomHeight         FLOAT 2-D array of mean GR beam bottoms along TMI field
;                        of view (with parallax adjustments) (I/O)
; topHeight_vpr        FLOAT 2-D array of mean GR beam top along local vertical
;                        above TMI footprint (I/O)
; bottomHeight_vpr     FLOAT 2-D array of mean GR beam bottoms along local vertical
;                        above TMI footprint (I/O)
; xCorners             FLOAT 3-D array of parallax-adjusted TMI footprint corner
;                        X-coordinates in km, 4 per footprint.(I/O)
; yCorners             FLOAT 3-D array of parallax-adjusted TMI footprint corner
;                        Y-coordinates in km, 4 per footprint.(I/O)
; latitude             FLOAT 2-D array of parallax-adjusted TMI footprint center
;                        latitude, degrees (I/O)
; longitude            FLOAT 2-D array of parallax-adjusted TMI footprint center
;                        longitude, degrees (I/O)
; TMIlatitude          FLOAT array of surface intersection TMI footprint center
;                        latitude, degrees (I/O)
; TMIlongitude         FLOAT array of surface intersection TMI footprint center
;                        longitude, degrees (I/O)
; surfaceRain          FLOAT array of TMI estimated rain rate at surface, mm/h (I/O)
; surfaceType          INT array of TMI 2A12 'surfaceType' flag, coded category (I/O)
; rainFlag             INT array of TMI rain/no-rain flag, category (I/O)
; dataFlag             INT array of TMI dataFlag values, category (I/O)
; PoP                  INT array of TMI Probability of Precipitation values,
;                        percent (I/O)
; freezingHeight       INT array of TMI 2A12 freezing height values, meters (I/O)
; rayIndex             INT array of TMI product ray,scan IDL array index,
;                        relative to the full 2A12 products (I/O)
;
; RETURNS
; -------
; status               INT - Status of call to function, 0=success, 1=failure
;
; HISTORY
; -------
; 06/01/11 by Bob Morris, GPM GV (SAIC)
;  - Created from read_geo_match_netcdf.pro.
; 06/16/11 by Bob Morris, GPM GV (SAIC)
;  - Filled in missing parameter definitions in the prologue.
; 01/20/12 by Bob Morris, GPM GV (SAIC)
;  - Added a check of the global attributes to make sure we have the correct
;    type of matchup netCDF file, since we have PRtoGR files also.
; 10/18/13 by Bob Morris, GPM GV (SAIC)
;  - Added ability to read GR rain rate variables from version 2.0 files.
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;===============================================================================

; MODULE 2

FUNCTION sort_multi_d_array, orderidx, array2sort, sortdim

; re-sort a multi-dimensional array 'array2sort' along the dimension 'sortdim'
; in the order specified by 'orderidx'.  sortdim is 1-based, i.e., the first
; dimension is 1, 2nd is 2, ...

sz = SIZE(array2sort)
layers = N_ELEMENTS(orderidx)
IF ( layers EQ sz[sortdim] ) THEN BEGIN
   status=0

   CASE sz[0] OF
     2 : BEGIN
           temparr=array2sort
           FOR ndim = 0, layers-1 DO BEGIN
             CASE sortdim OF
                1 : array2sort[ndim,*]=temparr[orderidx[ndim],*]
                2 : array2sort[*,ndim]=temparr[*,orderidx[ndim]]
             ENDCASE
           ENDFOR
         END
     3 : BEGIN
           temparr=array2sort
           FOR ndim = 0, layers-1 DO BEGIN
             CASE sortdim OF
                1 : array2sort[ndim,*,*]=temparr[orderidx[ndim],*,*]
                2 : array2sort[*,ndim,*]=temparr[*,orderidx[ndim],*]
                3 : array2sort[*,*,ndim]=temparr[*,*,orderidx[ndim]]
             ENDCASE
           ENDFOR
         END
     ELSE : BEGIN
           print, 'ERROR from sort_multi_d_array() in read_tmi_geo_match_netcdf.pro:'
           print, 'Too many dimensions (', sz[0], ') in array to be sorted!'
           status=1
         END
   ENDCASE

ENDIF ELSE BEGIN
   print, 'ERROR from sort_multi_d_array() in read_tmi_geo_match_netcdf.pro:'
   print, 'Size of array dimension over which to sort does not match number of sort indices!'
   status=1
ENDELSE

return, status
end

;===============================================================================

; MODULE 1

FUNCTION read_tmi_geo_match_netcdf, ncfile,                                   $
   ; metadata structures/parameters
    matchupmeta=matchupmeta, sweepsmeta=sweepsmeta, sitemeta=sitemeta,        $
    fieldflags=fieldFlags, filesmeta=filesmeta,                               $

   ; threshold/data completeness parameters for vert/horiz averaged values:
    grexpect_int=grexpect, grreject_int=grreject,                             $
    gr_rr_reject_int=n_gr_rr_rejected,                                        $
    grexpect_vpr_int=n_gr_vpr_expected, grreject_vpr_int=n_gr_vpr_rejected,   $
    gr_rr_reject_vpr_int=n_gr_rr_vpr_rejected,                                $

   ; horizontally averaged GR values on sweeps, along-TMI and local vertical:
    dbzgv_viewed=GR_Z_along_TMI, dbzgv_vpr=GR_Z_VPR,                          $
    gvStdDev_viewed=GR_Z_StdDev_along_TMI, gvMax_viewed=GR_Z_Max_along_TMI,   $
    gvStdDev_vpr=GR_Z_StdDev_VPR, gvMax_vpr=GR_Z_Max_VPR,                     $
   ; as above, but for GR rain rate:
    rr_gv_viewed=GR_RR_along_TMI, rr_gv_vpr=GR_RR_VPR,                        $
    gvrrStdDev_viewed=GR_RR_StdDev_along_TMI,                                 $
    gvrrMax_viewed=GR_RR_Max_along_TMI, gvrrStdDev_vpr=GR_RR_StdDev_VPR,      $
    gvrrMax_vpr=GR_RR_Max_VPR,                                                $

   ; spatial parameters for TMI and GR values at sweep elevations:
    topHeight_viewed=topHeight, bottomHeight_viewed=bottomHeight,             $
    xCorners=xCorners, yCorners=yCorners,                                     $
    latitude=latitude, longitude=longitude,                                   $
    topHeight_vpr=topHeight_vpr, bottomHeight_vpr=bottomHeight_vpr,           $

   ; spatial parameters for TMI at earth surface level:
    TMIlatitude=TMIlatitude, TMIlongitude=TMIlongitude,                       $

   ; TMI science values at earth surface level, or as ray summaries:
    surfaceRain=surfaceRain, sfctype_int=surfaceType, rainflag_int=rainFlag,  $
    dataflag_int=dataFlag, PoP_int=PoP, freezingHeight_int=freezingHeight,    $
    tmi_idx_long=rayIndex

status = 0

ncid1 = NCDF_OPEN( ncfile )
IF ( N_Elements(ncid1) EQ 0 ) THEN BEGIN
   print, "ERROR from read_tmi_geo_match_netcdf:"
   print, "File copy ", ncfile, " is not a valid netCDF file!"
   status = 1
   goto, ErrorExit
ENDIF

; determine the number of global attributes and check the name of the first one
; to verify that we have the correct type of file
attstruc=ncdf_inquire(ncid1)
IF ( attstruc.ngatts GT 0 ) THEN BEGIN
   typeversion = ncdf_attname(ncid1, 0, /global)
   IF ( typeversion NE 'TMI_Version' ) THEN BEGIN
      print, ''
      print, "ERROR from read_geo_match_netcdf:"
      print, "File copy ", ncfile, " is not a TMI-GR matchup file!"
      print, ''
      status = 1
      goto, ErrorExit
   ENDIF
ENDIF ELSE BEGIN
   print, ''
   print, "ERROR from read_geo_match_netcdf:"
   print, "File copy ", ncfile, " has no global attributes!"
   print, ''
   status = 1
   goto, ErrorExit
ENDELSE

; always determine the version of the matchup netCDF file first -- determines
; which variables can be retrieved
versid = NCDF_VARID(ncid1, 'version')
NCDF_ATTGET, ncid1, versid, 'long_name', vers_def_byte
vers_def = string(vers_def_byte)
IF ( vers_def ne 'Geo Match File Version' ) THEN BEGIN
   print, "ERROR from read_tmi_geo_match_netcdf:"
   print, "File copy ", ncfile, " is not a valid geo_match netCDF file!"
   status = 1
   goto, ErrorExit
ENDIF
NCDF_VARGET, ncid1, versid, ncversion

IF N_Elements(matchupmeta) NE 0 THEN BEGIN
     NCDF_VARGET, ncid1, 'timeNearestApproach', dtime
     matchupmeta.timeNearestApproach = dtime
     NCDF_VARGET, ncid1, 'atimeNearestApproach', txtdtimebyte
     matchupmeta.atimeNearestApproach = string(txtdtimebyte)
     matchupmeta.num_volumes = 1  ; only holds data for one GR volume scan
     zdimid = NCDF_DIMID(ncid1, 'elevationAngle')
     NCDF_DIMINQ, ncid1, zdimid, XDIMNAME, ncnz
     matchupmeta.num_sweeps = ncnz
     fpdimid = NCDF_DIMID(ncid1, 'fpdim')
     NCDF_DIMINQ, ncid1, fpdimid, FPDIMNAME, nprfp
     matchupmeta.num_footprints = nprfp
     NCDF_VARGET, ncid1, 'rangeThreshold', rngthresh
     matchupmeta.rangeThreshold = rngthresh
     NCDF_VARGET, ncid1, 'GR_dBZ_min', gvzmin
     matchupmeta.GV2TMI_dBZ_min = gvzmin
     NCDF_VARGET, ncid1, 'tmi_rain_min', rnmin
     matchupmeta.tmi_rain_min = rnmin
;     NCDF_VARGET, ncid1, versid, ncversion  ; already "got" this variable
     matchupmeta.nc_file_version = ncversion
     ncdf_attget, ncid1, 'TMI_Version', TMI_vers, /global
     matchupmeta.TMI_Version = TMI_vers
     ncdf_attget, ncid1, 'GR_UF_Z_field', gr_UF_field_byte, /global
     matchupmeta.GV_UF_Z_field = STRING(gr_UF_field_byte)
ENDIF

IF N_Elements(sweepsmeta) NE 0 THEN BEGIN
     zdimid = NCDF_DIMID(ncid1, 'elevationAngle')
     NCDF_DIMINQ, ncid1, zdimid, XDIMNAME, ncnz  ; number of sweeps/elevs.
     NCDF_VARGET, ncid1, 'elevationAngle', nc_zlevels
     elevorder = SORT(nc_zlevels)
     ascorder = INDGEN(ncnz)
     sortflag=0
     IF TOTAL( ABS(elevorder-ascorder) ) NE 0 THEN BEGIN
        PRINT, 'read_tmi_geo_match_netcdf(): Elevation angles not in order! Resorting data.'
        sortflag=1
     ENDIF
     arr_structs = REPLICATE(sweepsmeta,ncnz)  ; need one struct per sweep/elev.
     arr_structs.elevationAngle = nc_zlevels[elevorder]
     NCDF_VARGET, ncid1, 'timeSweepStart', sweepticks
     arr_structs.timeSweepStart = sweepticks[elevorder]
     NCDF_VARGET, ncid1, 'atimeSweepStart', sweeptimetxtbyte
     arr_structs.atimeSweepStart = STRING(sweeptimetxtbyte[*,elevorder])
     sweepsmeta = arr_structs
ENDIF ELSE BEGIN
    ; always need to determine whether reordering of layers needs done
     zdimid = NCDF_DIMID(ncid1, 'elevationAngle')
     NCDF_DIMINQ, ncid1, zdimid, XDIMNAME, ncnz  ; number of sweeps/elevs.
     NCDF_VARGET, ncid1, 'elevationAngle', nc_zlevels
     elevorder = SORT(nc_zlevels)
     ascorder = INDGEN(ncnz)
     sortflag=0
     IF TOTAL( ABS(elevorder-ascorder) ) NE 0 THEN BEGIN
        PRINT, 'read_tmi_geo_match_netcdf(): Elevation angles not in order! Resorting data.'
        sortflag=1
     ENDIF
ENDELSE

IF N_Elements(sitemeta) NE 0 THEN BEGIN
     NCDF_VARGET, ncid1, 'site_lat', nclat
     sitemeta.site_lat = nclat
     NCDF_VARGET, ncid1, 'site_lon', nclon
     sitemeta.site_lon = nclon
     NCDF_VARGET, ncid1, 'site_ID', siteIDbyte
     sitemeta.site_id = string(siteIDbyte)
     NCDF_VARGET, ncid1, 'site_elev', ncsiteElev
     sitemeta.site_elev = ncsiteElev
ENDIF

IF N_Elements(fieldFlags) NE 0 THEN BEGIN
     NCDF_VARGET, ncid1, 'have_GR_Z_along_TMI', have_GR_Z_along_TMI
     fieldFlags.have_GR_Z_along_TMI = have_GR_Z_along_TMI
     NCDF_VARGET, ncid1, 'have_GR_Z_Max_along_TMI', have_GR_Z_Max_along_TMI
     fieldFlags.have_GR_Z_Max_along_TMI = have_GR_Z_Max_along_TMI
     NCDF_VARGET, ncid1, 'have_GR_Z_StdDev_along_TMI', have_GR_Z_StdDev_along_TMI
     fieldFlags.have_GR_Z_StdDev_along_TMI = have_GR_Z_StdDev_along_TMI
     NCDF_VARGET, ncid1, 'have_GR_Z_VPR', have_GR_Z_VPR
     fieldFlags.have_GR_Z_VPR = have_GR_Z_VPR
     NCDF_VARGET, ncid1, 'have_GR_Z_Max_VPR', have_GR_Z_Max_VPR
     fieldFlags.have_GR_Z_Max_VPR = have_GR_Z_Max_VPR
     NCDF_VARGET, ncid1, 'have_GR_Z_StdDev_VPR', have_GR_Z_StdDev_VPR
     fieldFlags.have_GR_Z_StdDev_VPR = have_GR_Z_StdDev_VPR
     IF ncversion GE 2.0 THEN BEGIN
        NCDF_VARGET, ncid1, 'have_GR_RR_along_TMI', have_GR_RR_along_TMI
        fieldFlags.have_GR_RR_along_TMI = have_GR_RR_along_TMI
        NCDF_VARGET, ncid1, 'have_GR_RR_Max_along_TMI', have_GR_RR_Max_along_TMI
        fieldFlags.have_GR_RR_Max_along_TMI = have_GR_RR_Max_along_TMI
        NCDF_VARGET, ncid1, 'have_GR_RR_StdDev_along_TMI', have_GR_RR_StdDev_along_TMI
        fieldFlags.have_GR_RR_StdDev_along_TMI = have_GR_RR_StdDev_along_TMI
        NCDF_VARGET, ncid1, 'have_GR_RR_VPR', have_GR_RR_VPR
        fieldFlags.have_GR_RR_VPR = have_GR_RR_VPR
        NCDF_VARGET, ncid1, 'have_GR_RR_Max_VPR', have_GR_RR_Max_VPR
        fieldFlags.have_GR_RR_Max_VPR = have_GR_RR_Max_VPR
        NCDF_VARGET, ncid1, 'have_GR_RR_StdDev_VPR', have_GR_RR_StdDev_VPR
        fieldFlags.have_GR_RR_StdDev_VPR = have_GR_RR_StdDev_VPR
     ENDIF
     NCDF_VARGET, ncid1, 'have_surfaceType', have_surfaceType
     fieldFlags.have_surfaceType = have_surfaceType
     NCDF_VARGET, ncid1, 'have_surfaceRain', have_surfaceRain
     fieldFlags.have_surfaceRain = have_surfaceRain
     NCDF_VARGET, ncid1, 'have_rainFlag', have_rainFlag
     fieldFlags.have_rainFlag = have_rainFlag
     NCDF_VARGET, ncid1, 'have_dataFlag', have_dataFlag
     fieldFlags.have_dataFlag = have_dataFlag
     NCDF_VARGET, ncid1, 'have_PoP', have_PoP
     fieldFlags.have_PoP = have_PoP
     NCDF_VARGET, ncid1, 'have_freezingHeight', have_freezingHeight
     fieldFlags.have_freezingHeight = have_freezingHeight
ENDIF

; Read TMI and GR filenames and override the 'UNKNOWN' initial values in the structure
IF N_Elements(filesmeta) NE 0 THEN BEGIN
      ncdf_attget, ncid1, 'TMI_2A12_file', TMI_2A12_file_byte, /global
      filesmeta.file_2a12 = STRING(TMI_2A12_file_byte)
      ncdf_attget, ncid1, 'GR_file', GR_file_byte, /global
      filesmeta.file_1CUF = STRING(GR_file_byte)
ENDIF

IF N_Elements(grexpect) NE 0 THEN BEGIN
     NCDF_VARGET, ncid1, 'n_gr_expected', grexpect
     IF ( sortflag EQ 1 ) THEN BEGIN
        sort_status = sort_multi_d_array( elevorder, grexpect, 2 )
        IF (sort_status EQ 1) THEN BEGIN
          status = sort_status
          goto, ErrorExit
        ENDIF
     ENDIF
ENDIF

IF N_Elements(grreject) NE 0 THEN BEGIN
     NCDF_VARGET, ncid1, 'n_gr_rejected', grreject
     IF ( sortflag EQ 1 ) THEN BEGIN
        sort_status = sort_multi_d_array( elevorder, grreject, 2 )
        IF (sort_status EQ 1) THEN BEGIN
          status = sort_status
          goto, ErrorExit
        ENDIF
     ENDIF
ENDIF

IF N_Elements(n_gr_vpr_expected) NE 0 THEN BEGIN
     NCDF_VARGET, ncid1, 'n_gr_vpr_expected', n_gr_vpr_expected
     IF ( sortflag EQ 1 ) THEN BEGIN
        sort_status = sort_multi_d_array( elevorder, n_gr_vpr_expected, 2 )
        IF (sort_status EQ 1) THEN BEGIN
          status = sort_status
          goto, ErrorExit
        ENDIF
     ENDIF
ENDIF

IF N_Elements(n_gr_vpr_rejected) NE 0 THEN BEGIN
     NCDF_VARGET, ncid1, 'n_gr_vpr_rejected', n_gr_vpr_rejected
     IF ( sortflag EQ 1 ) THEN BEGIN
        sort_status = sort_multi_d_array( elevorder, n_gr_vpr_rejected, 2 )
        IF (sort_status EQ 1) THEN BEGIN
          status = sort_status
          goto, ErrorExit
        ENDIF
     ENDIF
ENDIF

IF N_Elements(GR_Z_along_TMI) NE 0 THEN BEGIN
     NCDF_VARGET, ncid1, 'GR_Z_along_TMI', GR_Z_along_TMI
     IF ( sortflag EQ 1 ) THEN BEGIN
        sort_status = sort_multi_d_array( elevorder, GR_Z_along_TMI, 2 )
        IF (sort_status EQ 1) THEN BEGIN
          status = sort_status
          goto, ErrorExit
        ENDIF
     ENDIF
ENDIF

IF N_Elements(GR_Z_Max_along_TMI) NE 0 THEN BEGIN
   NCDF_VARGET, ncid1, 'GR_Z_Max_along_TMI', GR_Z_Max_along_TMI
   IF ( sortflag EQ 1 ) THEN BEGIN
      sort_status = sort_multi_d_array( elevorder, GR_Z_Max_along_TMI, 2 )
      IF (sort_status EQ 1) THEN BEGIN
        status = sort_status
        goto, ErrorExit
      ENDIF
   ENDIF
ENDIF

IF N_Elements(GR_Z_StdDev_along_TMI) NE 0 THEN BEGIN
   NCDF_VARGET, ncid1, 'GR_Z_StdDev_along_TMI', GR_Z_StdDev_along_TMI
   IF ( sortflag EQ 1 ) THEN BEGIN
      sort_status = sort_multi_d_array( elevorder, GR_Z_StdDev_along_TMI, 2 )
      IF (sort_status EQ 1) THEN BEGIN
        status = sort_status
        goto, ErrorExit
      ENDIF
   ENDIF
ENDIF

IF N_Elements(GR_Z_VPR) NE 0 THEN BEGIN
     NCDF_VARGET, ncid1, 'GR_Z_VPR', GR_Z_VPR
     IF ( sortflag EQ 1 ) THEN BEGIN
        sort_status = sort_multi_d_array( elevorder, GR_Z_VPR, 2 )
        IF (sort_status EQ 1) THEN BEGIN
          status = sort_status
          goto, ErrorExit
        ENDIF
     ENDIF
ENDIF

IF N_Elements(GR_Z_Max_VPR) NE 0 THEN BEGIN
   NCDF_VARGET, ncid1, 'GR_Z_Max_VPR', GR_Z_Max_VPR
   IF ( sortflag EQ 1 ) THEN BEGIN
      sort_status = sort_multi_d_array( elevorder, GR_Z_Max_VPR, 2 )
      IF (sort_status EQ 1) THEN BEGIN
        status = sort_status
        goto, ErrorExit
      ENDIF
   ENDIF
ENDIF

IF N_Elements(GR_Z_StdDev_VPR) NE 0 THEN BEGIN
   NCDF_VARGET, ncid1, 'GR_Z_StdDev_VPR', GR_Z_StdDev_VPR
   IF ( sortflag EQ 1 ) THEN BEGIN
      sort_status = sort_multi_d_array( elevorder, GR_Z_StdDev_VPR, 2 )
      IF (sort_status EQ 1) THEN BEGIN
        status = sort_status
        goto, ErrorExit
      ENDIF
   ENDIF
ENDIF

IF N_Elements(n_gr_rr_rejected) NE 0 THEN BEGIN
   IF ncversion GE 2.0 THEN BEGIN
     NCDF_VARGET, ncid1, 'n_gr_rr_rejected', n_gr_rr_rejected
     IF ( sortflag EQ 1 ) THEN BEGIN
        sort_status = sort_multi_d_array( elevorder, n_gr_rr_rejected, 2 )
        IF (sort_status EQ 1) THEN BEGIN
          status = sort_status
          goto, ErrorExit
        ENDIF
     ENDIF
   ENDIF ELSE message, "Variable 'n_gr_rr_rejected' not supported in " + $
                       "file version "+string(ncversion, FORMAT='(F3.1)'), /INFO
ENDIF

IF N_Elements(n_gr_rr_vpr_rejected) NE 0 THEN BEGIN
   IF ncversion GE 2.0 THEN BEGIN
     NCDF_VARGET, ncid1, 'n_gr_rr_vpr_rejected', n_gr_rr_vpr_rejected
     IF ( sortflag EQ 1 ) THEN BEGIN
        sort_status = sort_multi_d_array( elevorder, n_gr_rr_vpr_rejected, 2 )
        IF (sort_status EQ 1) THEN BEGIN
          status = sort_status
          goto, ErrorExit
        ENDIF
     ENDIF
   ENDIF ELSE message, "Variable 'n_gr_rr_vpr_rejected' not supported in " + $
                       "file version "+string(ncversion, FORMAT='(F3.1)'), /INFO
ENDIF

IF N_Elements(GR_RR_along_TMI) NE 0 THEN BEGIN
   IF ncversion GE 2.0 THEN BEGIN
     NCDF_VARGET, ncid1, 'GR_RR_along_TMI', GR_RR_along_TMI
     IF ( sortflag EQ 1 ) THEN BEGIN
        sort_status = sort_multi_d_array( elevorder, GR_RR_along_TMI, 2 )
        IF (sort_status EQ 1) THEN BEGIN
          status = sort_status
          goto, ErrorExit
        ENDIF
     ENDIF
   ENDIF ELSE message, "Variable 'GR_RR_along_TMI' not supported in " + $
                       "file version "+string(ncversion, FORMAT='(F3.1)'), /INFO
ENDIF

IF N_Elements(GR_RR_Max_along_TMI) NE 0 THEN BEGIN
   IF ncversion GE 2.0 THEN BEGIN
     NCDF_VARGET, ncid1, 'GR_RR_Max_along_TMI', GR_RR_Max_along_TMI
     IF ( sortflag EQ 1 ) THEN BEGIN
        sort_status = sort_multi_d_array( elevorder, GR_RR_Max_along_TMI, 2 )
        IF (sort_status EQ 1) THEN BEGIN
          status = sort_status
          goto, ErrorExit
        ENDIF
     ENDIF
   ENDIF ELSE message, "Variable 'GR_RR_Max_along_TMI' not supported in " + $
                       "file version "+string(ncversion, FORMAT='(F3.1)'), /INFO
ENDIF

IF N_Elements(GR_RR_StdDev_along_TMI) NE 0 THEN BEGIN
   IF ncversion GE 2.0 THEN BEGIN
     NCDF_VARGET, ncid1, 'GR_RR_StdDev_along_TMI', GR_RR_StdDev_along_TMI
     IF ( sortflag EQ 1 ) THEN BEGIN
        sort_status = sort_multi_d_array( elevorder, GR_RR_StdDev_along_TMI, 2 )
        IF (sort_status EQ 1) THEN BEGIN
          status = sort_status
          goto, ErrorExit
        ENDIF
     ENDIF
   ENDIF ELSE message, "Variable 'GR_RR_StdDev_along_TMI' not supported in " + $
                       "file version "+string(ncversion, FORMAT='(F3.1)'), /INFO
ENDIF

IF N_Elements(GR_RR_VPR) NE 0 THEN BEGIN
   IF ncversion GE 2.0 THEN BEGIN
     NCDF_VARGET, ncid1, 'GR_RR_VPR', GR_RR_VPR
     IF ( sortflag EQ 1 ) THEN BEGIN
        sort_status = sort_multi_d_array( elevorder, GR_RR_VPR, 2 )
        IF (sort_status EQ 1) THEN BEGIN
          status = sort_status
          goto, ErrorExit
        ENDIF
     ENDIF
   ENDIF ELSE message, "Variable 'GR_RR_VPR' not supported in " + $
                       "file version "+string(ncversion, FORMAT='(F3.1)'), /INFO
ENDIF

IF N_Elements(GR_RR_Max_VPR) NE 0 THEN BEGIN
   IF ncversion GE 2.0 THEN BEGIN
     NCDF_VARGET, ncid1, 'GR_RR_Max_VPR', GR_RR_Max_VPR
     IF ( sortflag EQ 1 ) THEN BEGIN
        sort_status = sort_multi_d_array( elevorder, GR_RR_Max_VPR, 2 )
        IF (sort_status EQ 1) THEN BEGIN
          status = sort_status
          goto, ErrorExit
        ENDIF
     ENDIF
   ENDIF ELSE message, "Variable 'GR_RR_Max_VPR' not supported in " + $
                       "file version "+string(ncversion, FORMAT='(F3.1)'), /INFO
ENDIF

IF N_Elements(GR_RR_StdDev_VPR) NE 0 THEN BEGIN
   IF ncversion GE 2.0 THEN BEGIN
     NCDF_VARGET, ncid1, 'GR_RR_StdDev_VPR', GR_RR_StdDev_VPR
     IF ( sortflag EQ 1 ) THEN BEGIN
        sort_status = sort_multi_d_array( elevorder, GR_RR_StdDev_VPR, 2 )
        IF (sort_status EQ 1) THEN BEGIN
          status = sort_status
          goto, ErrorExit
        ENDIF
     ENDIF
   ENDIF ELSE message, "Variable 'GR_RR_StdDev_VPR' not supported in " + $
                       "file version "+string(ncversion, FORMAT='(F3.1)'), /INFO
ENDIF

IF N_Elements(topHeight) NE 0 THEN BEGIN
     NCDF_VARGET, ncid1, 'topHeight', topHeight
     IF ( sortflag EQ 1 ) THEN BEGIN
        sort_status = sort_multi_d_array( elevorder, topHeight, 2 )
        IF (sort_status EQ 1) THEN BEGIN
          status = sort_status
          goto, ErrorExit
        ENDIF
     ENDIF
ENDIF

IF N_Elements(bottomHeight) NE 0 THEN BEGIN
     NCDF_VARGET, ncid1, 'bottomHeight', bottomHeight
     IF ( sortflag EQ 1 ) THEN BEGIN
        sort_status = sort_multi_d_array( elevorder, bottomHeight, 2 )
        IF (sort_status EQ 1) THEN BEGIN
          status = sort_status
          goto, ErrorExit
        ENDIF
     ENDIF
ENDIF

IF N_Elements(topHeight_vpr) NE 0 THEN BEGIN
     NCDF_VARGET, ncid1, 'topHeight_vpr', topHeight_vpr
     IF ( sortflag EQ 1 ) THEN BEGIN
        sort_status = sort_multi_d_array( elevorder, topHeight_vpr, 2 )
        IF (sort_status EQ 1) THEN BEGIN
          status = sort_status
          goto, ErrorExit
        ENDIF
     ENDIF
ENDIF

IF N_Elements(bottomHeight_vpr) NE 0 THEN BEGIN
     NCDF_VARGET, ncid1, 'bottomHeight_vpr', bottomHeight_vpr
     IF ( sortflag EQ 1 ) THEN BEGIN
        sort_status = sort_multi_d_array( elevorder, bottomHeight_vpr, 2 )
        IF (sort_status EQ 1) THEN BEGIN
          status = sort_status
          goto, ErrorExit
        ENDIF
     ENDIF
ENDIF

IF N_Elements(xCorners) NE 0 THEN BEGIN
     NCDF_VARGET, ncid1, 'xCorners', xCorners
     IF ( sortflag EQ 1 ) THEN BEGIN
        sort_status = sort_multi_d_array( elevorder, xCorners, 3 )
        IF (sort_status EQ 1) THEN BEGIN
          status = sort_status
          goto, ErrorExit
        ENDIF
     ENDIF
ENDIF

IF N_Elements(yCorners) NE 0 THEN BEGIN
     NCDF_VARGET, ncid1, 'yCorners', yCorners
     IF ( sortflag EQ 1 ) THEN BEGIN
        sort_status = sort_multi_d_array( elevorder, yCorners, 3 )
        IF (sort_status EQ 1) THEN BEGIN
          status = sort_status
          goto, ErrorExit
        ENDIF
     ENDIF
ENDIF

IF N_Elements(latitude) NE 0 THEN BEGIN
     NCDF_VARGET, ncid1, 'latitude', latitude
     IF ( sortflag EQ 1 ) THEN BEGIN
        sort_status = sort_multi_d_array( elevorder, latitude, 2 )
        IF (sort_status EQ 1) THEN BEGIN
          status = sort_status
          goto, ErrorExit
        ENDIF
     ENDIF
ENDIF

IF N_Elements(longitude) NE 0 THEN BEGIN
     NCDF_VARGET, ncid1, 'longitude', longitude
     IF ( sortflag EQ 1 ) THEN BEGIN
        sort_status = sort_multi_d_array( elevorder, longitude, 2 )
        IF (sort_status EQ 1) THEN BEGIN
          status = sort_status
          goto, ErrorExit
        ENDIF
     ENDIF
ENDIF

IF N_Elements(TMIlatitude) NE 0 THEN $
     NCDF_VARGET, ncid1, 'TMIlatitude', TMIlatitude

IF N_Elements(TMIlongitude) NE 0 THEN $
     NCDF_VARGET, ncid1, 'TMIlongitude', TMIlongitude

IF N_Elements(surfaceRain) NE 0 THEN $
     NCDF_VARGET, ncid1, 'surfaceRain', surfaceRain

IF N_Elements(surfaceType) NE 0 THEN $
     NCDF_VARGET, ncid1, 'surfaceType', surfaceType

IF N_Elements(rainFlag) NE 0 THEN $
     NCDF_VARGET, ncid1, 'rainFlag', rainFlag

IF N_Elements(dataFlag) NE 0 THEN $
     NCDF_VARGET, ncid1, 'dataFlag', dataFlag

IF N_Elements(PoP) NE 0 THEN $
     NCDF_VARGET, ncid1, 'PoP', PoP

IF N_Elements(freezingHeight) NE 0 THEN $
     NCDF_VARGET, ncid1, 'freezingHeight', freezingHeight

IF N_Elements(rayIndex) NE 0 THEN $
     NCDF_VARGET, ncid1, 'rayIndex', rayIndex

ErrorExit:
NCDF_CLOSE, ncid1

RETURN, status
END
