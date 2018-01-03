;===============================================================================
;+
; Copyright © 2008, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; read_geo_match_netcdf.pro           Morris/SAIC/GPM_GR      September 2008
;
; DESCRIPTION
; -----------
; Reads caller-specified data and metadata from PR-GR matchup netCDF files. 
; Returns status value: 0 if successful read, 1 if unsuccessful or internal
; errors or inconsistencies occur.  File must be read-ready (unzipped/
; uncompressed) before calling this function.
;
; PARAMETERS
; ----------
; ncfile               STRING, Full file pathname to PR netCDF grid file (Input)
; matchupmeta          Structure holding general and algorithmic parameters,
;                      including rainrate and reflectivity cutoffs (I/O)
; sweepsmeta           Array of Structures holding sweep elevation angles,
;                      and sweep start times in unix ticks and ascii text (I/O)
; sitemeta             Structure holding GR site location parameters (I/O)
; fieldFlags           Structure holding "data exists" flags for gridded PR
;                        data variables (I/O)
; filesmeta            Structure holding PR and GR file names used in matchup (I/O)
;                      -- See file geo_match_nc_structs.inc for definition of
;                         the above structures.
; threeDreflect        FLOAT 2-D array of horizontally-averaged, QC'd GR
;                        reflectivity, dBZ (I/O)
; threeDreflectMax     FLOAT 2-D array, Maximum value of GR reflectivity
;                      bins included in threeDreflect, dBZ (I/O)
; threeDreflectStdDev  FLOAT 2-D array, Standard Deviation of GR reflectivity
;                      bins included in threeDreflect, dBZ (I/O)
; GR_rainrate          FLOAT 2-D array of horizontally-averaged, QC'd GR
;                      rain rate, mm/h (I/O)
; GR_rainrateMax       FLOAT 2-D array, Maximum value of GR rain rate
;                      bins included in GR_rainrate, mm/h (I/O)
; GR_rainrateStdDev    FLOAT 2-D array, Standard Deviation of GR rain rate
;                      bins included in GR_rainrate, mm/h (I/O)
; GR_Zdr               FLOAT 2-D array of volume-matched GR mean Zdr
;                        (differential reflectivity)
; GR_ZdrMax            As above, but sample maximum of Zdr
; GR_ZdrStdDev         As above, but sample standard deviation of Zdr
; GR_Kdp               FLOAT 2-D array of volume-matched GR mean Kdp (specific
;                        differential phase)
; GR_KdpMax            As above, but sample maximum of Kdp
; GR_KdpStdDev         As above, but sample standard deviation of Kdp
; GR_RHOhv             FLOAT 2-D array of volume-matched GR mean RHOhv
;                        (co-polar correlation coefficient)
; GR_RHOhvMax          As above, but sample maximum of RHOhv
; GR_RHOhvStdDev       As above, but sample standard deviation of RHOhv
; GR_HID               FLOAT 2-D array of volume-matched GR Hydrometeor ID (HID)
;                         category (count of GR bins in each HID category)
; GR_Dzero             FLOAT 2-D array of volume-matched GR mean D0 (Median
;                        volume diameter)
; GR_DzeroMax          As above, but sample maximum of Dzero
; GR_DzeroStdDev       As above, but sample standard deviation of Dzero
; GR_Nw                FLOAT 2-D array of volume-matched GR mean Nw (Normalized
;                        intercept parameter)
; GR_NwMax             As above, but sample maximum of Nw
; GR_NwStdDev          As above, but sample standard deviation of Nw
; gvexpect             INT number of GR radar bins averaged for the above (I/O)
; gvreject             INT number of bins below GR dBZ cutoff in threeDreflect
;                        set of variables (I/O)
; gv_rr_reject         INT number of bins below rainrate cutoff in GR_rainrate
;                        set of variables (I/O)
; gv_zdr_reject        INT number of missing-data bins in GR_Zdr
;                        set of variables (I/O)
; gv_kdp_reject        INT number of missing-data bins in GR_Kdp
;                        set of variables (I/O)
; gv_RHOhv_reject      INT number of missing-data bins in GR_RHOhv
;                        set of variables (I/O)
; gv_hid_reject        INT number of missing-data bins in GR_HID
;                        set of variables (I/O)
; gv_Dzero_reject      INT number of missing-data bins in GR_Dzero
;                        set of variables (I/O)
; gv_Nw_reject         INT number of missing-data bins in GR_Nw
;                        set of variables (I/O)
; prexpect             INT number of PR radar bins averaged for dBZnormalSample,
;                        correctZfactor, and rain (I/O)
; dBZnormalSample      FLOAT 2-D array of vertically-averaged raw PR
;                        reflectivity, dBZ (I/O)
; zrawreject           INT number of PR bins below dBZ cutoff in above (I/O)
; correctZfactor       FLOAT 2-D array of vertically-averaged, attenuation-
;                        corrected PR reflectivity, dBZ (I/O)
; zcorreject           INT number of PR bins below dBZ cutoff in above (I/O)
; rain                 FLOAT 2-D array of vertically-averaged PR estimated rain
;                        rate, mm/h (I/O)
; rainreject           INT number of PR bins below rainrate cutoff in above (I/O)
; topHeight            FLOAT 2-D array of mean GR beam top over PR footprint
;                        (I/O)
; bottomHeight         FLOAT 2-D array of mean GR beam bottoms over PR footprint
;                        (I/O)
; xCorners             FLOAT 3-D array of parallax-adjusted PR footprint corner
;                        X-coordinates in km, 4 per footprint.(I/O)
; yCorners             FLOAT 3-D array of parallax-adjusted PR footprint corner
;                        Y-coordinates in km, 4 per footprint.(I/O)
; latitude             FLOAT 2-D array of parallax-adjusted PR footprint center
;                        latitude, degrees North (I/O)
; longitude            FLOAT 2-D array of parallax-adjusted PR footprint center
;                        longitude, degrees East (I/O)
; PRlatitude           FLOAT array of surface intersection PR footprint center
;                        latitude, degrees (I/O)
; PRlongitude          FLOAT array of surface intersection PR footprint center
;                        longitude, degrees (I/O)
; landOceanFlag        INT array of underlying surface type, category (I/O)
; nearSurfRain         FLOAT array of PR estimated rain rate at surface,
;                         mm/h (I/O)
; nearSurfRain_2b31    As above, but from combined PR/TMI algorithm of 2B-31
; BBheight             INT array of PR estimated bright band height,
;                         meters (I/O)
; BBstatus             INT array of PR bright band estimation status, coded
;                      category (I/O)
; status_2a23          INT array of PR 2A23 'status' flag, coded category (I/O)
; rainFlag             INT array of PR rain/no-rain flag, category (I/O)
; rainType             INT array of PR derived raincloud type, category (I/O)
; rayIndex             INT array of PR product ray,scan IDL array index,
;                        relative to the full 1C21/2A25/2B31 products (I/O)
;
; RETURNS
; -------
; status               INT - Status of call to function, 0=success, 1=failure
;
; HISTORY
; -------
; 04/12/10 Morris/SAIC/GPM-GV
; - Added sorting feature to handle out-of-order elevation sweeps in netCDF file
;   to prevent problems in cross section display generation when handling
;   overlap of samples, and within other routines when evaluating vertical
;   profiles along a PR ray.  Some sample data from KOUN were in alphabetical
;   order of elevation angle, rather than in ascending numerical order.
; 04/30/10 Morris/SAIC/GPM-GV
; - Fixed bug such that elements of sweepsmeta were not being resorted.
; 09/16/10 Morris/SAIC/GPM-GV
;  - Added reading of site_elev variable and addition to sitemeta structure to
;    support version 1.1 PR-GR matchup netCDF data files.
; 11/12/10 by Bob Morris, GPM GV (SAIC)
;  - Add reading of GR variables 'threeDreflectStdDev' and 'threeDreflectMax',
;    and 2A-23 product variables 'BBstatus' and 'status'.
; 03/28/11 by Bob Morris, GPM GV (SAIC)
;  - Add reading of PR/GR filename data from the version 2.1 matchup file and
;    populating of the filesmeta structure with the names.
; 01/20/12 by Bob Morris, GPM GV (SAIC)
;  - Added a check of the global attributes to make sure we have the correct
;    type of matchup netCDF file, now that we have TMItoGR files also.
; 7/23/13 by Bob Morris, GPM GV (SAIC)
;  - Added GR rainrate Mean/StdDev/Max data variables and presence flags and
;    gv_rr_reject variable, for file version 2.2.
; 1/27/14 by Bob Morris, GPM GV (SAIC)
;  - Added GR HID, D0, and Nw data variables and their presence flags and
;    corresponding gv_XXX_reject variables, for file version 2.3.
; 1/27/14 by Bob Morris, GPM GV (SAIC)
;  - Write new netCDF dimension variable value, num_HID_categories, to
;    matchupmeta structure.
; 2/13/14 by Bob Morris, GPM GV (SAIC)
;  - Added Max and StdDev for GR D0 and Nw data variables, and added Mean,
;    Max, StdDev and "n_rejected" for new GR variables Zdr, Kdp, and RHOhv.
;  - Added UF field ID tag/value pairs for RR, ZDR, KDP, RHOHV, HID, D0, and NW
;    to the matchup_meta structure.
; 2/17/14 by Bob Morris, GPM GV (SAIC)
;  - Actually added the remainder of the code to do what I described on 2/13/14.
; 4/30/14 by Bob Morris, GPM GV (SAIC)
;  - Reading new 'PPS_Version' global variable and writing to matchupmeta
;    structure.
;  - Removed reading have_XXX_Max and HAVE_XXX_StdDev GR variables and writing
;    values to structure PR_GV_FIELD_FLAGS where they are no longer defined.
; 6/9/14 by Bob Morris, GPM GV (SAIC)
;  - Renamed have_GR_DP_XXX tags to have_GR_XXX for compatibility with DPR
;    field_flags named structure "dpr_gr_field_flags".
; 07/15/14 by Bob Morris, GPM GV (SAIC)
;  - Renamed all Input/Output *GR_DP_* variables to *GR_*, removing the "DP_"
;    designators. Renamed all internal netCDF variable names for 3.0 or greater
;    in the same manner.
; 01/23/15 by Bob Morris, GPM GV (SAIC)
;  - Changed all version tests for 2.3 or greater to 3.0 or greater.  Replacing
;    all verion 2.3 matchup files with 3.0.
; 02/05/15 by Bob Morris, GPM GV (SAIC)
;  - Added PIA as a variable to be read from the version 3.1 matchup files.
; 04/16/15 by Bob Morris, GPM GV (SAIC)
;  - Added reading of have_PIA and writing out to field_flags structure for the
;    version 3.1 matchup files.
;
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
           print, 'ERROR from sort_multi_d_array() in read_geo_match_netcdf.pro:'
           print, 'Too many dimensions (', sz[0], ') in array to be sorted!'
           status=1
         END
   ENDCASE

ENDIF ELSE BEGIN
   print, 'ERROR from sort_multi_d_array() in read_geo_match_netcdf.pro:'
   print, 'Size of array dimension over which to sort does not match number', $
          ' of sort indices!'
   status=1
ENDELSE

return, status
end

;===============================================================================

; MODULE 1

FUNCTION read_geo_match_netcdf, ncfile,                                       $
   ; metadata structures/parameters
    matchupmeta=matchupmeta, sweepsmeta=sweepsmeta, sitemeta=sitemeta,        $
    fieldflags=fieldFlags, filesmeta=filesmeta,                               $

   ; threshold/data completeness parameters for averaged/summarized values:
    gvexpect_int=gvexpect, gvreject_int=gvreject, prexpect_int=prexpect,      $
    zrawreject_int=zrawreject, zcorreject_int=zcorreject,                     $
    rainreject_int=rainreject, gv_rr_reject_int=gv_rr_reject,                 $
    gv_hid_reject_int=gv_hid_reject, gv_dzero_reject_int=gv_dzero_reject,     $
    gv_nw_reject_int=gv_nw_reject, gv_zdr_reject_int=gv_zdr_reject,           $
    gv_kdp_reject_int=gv_kdp_reject, gv_RHOhv_reject_int=gv_RHOhv_reject,     $

   ; horizontally (GV) and vertically (PR Z, rain) averaged values at elevs.:
    dbzgv=threeDreflect, dbzraw=dBZnormalSample, dbzcor=correctZfactor,       $
    rain3d=rain, gvStdDev=threeDreflectStdDev, gvMax=threeDreflectMax,        $
    rrgvMean=GR_rainrate, rrgvMax=GR_rainrateMax,                       $
    rrgvStdDev=GR_rainrateStdDev, dzerogvMean=GR_Dzero,                 $
    dzerogvMax=GR_DzeroMax, dzerogvStdDev=GR_DzeroStdDev,               $
    nwgvMean=GR_Nw, nwgvMax=GR_NwMax, nwgvStdDev=GR_NwStdDev,        $
    zdrgvMean=GR_Zdr, zdrgvMax=GR_ZdrMax, zdrgvStdDev=GR_ZdrStdDev,  $
    kdpgvMean=GR_Kdp, kdpgvMax=GR_KdpMax, kdpgvStdDev=GR_KdpStdDev,  $
    rhohvgvMean=GR_RHOhv, rhohvgvMax=GR_RHOhvMax,                       $
    rhohvgvStdDev=GR_RHOhvStdDev,                                          $   

   ; horizontally summarized GR Hydromet Identifier category at elevs.:
    hidgv=GR_HID,                                                          $

   ; spatial parameters for PR and GR values at sweep elevations:
    topHeight=topHeight, bottomHeight=bottomHeight, xCorners=xCorners,        $
    yCorners=yCorners, latitude=latitude, longitude=longitude,                $

   ; spatial parameters for PR at earth surface level:
    PRlatitude=PRlatitude, PRlongitude=PRlongitude,                           $

   ; PR science values at earth surface level, or as ray summaries:
    sfcrainpr=nearSurfRain, sfcraincomb=nearSurfRain_2b31, bbhgt=BBheight,    $
    sfctype_int=landOceanFlag, rainflag_int=rainFlag, raintype_int=rainType,  $
    pridx_long=rayIndex, status_2a23_int=status_2a23, BBstatus_int=bbstatus,  $
    PIA=pia


status = 0

ncid1 = NCDF_OPEN( ncfile )
IF ( N_Elements(ncid1) EQ 0 ) THEN BEGIN
   print, ''
   print, "ERROR from read_geo_match_netcdf:"
   print, "File copy ", ncfile, " is not a valid netCDF file!"
   print, ''
   status = 1
   goto, ErrorExit
ENDIF

; determine the number of global attributes and check the name of the first one
; to verify that we have the correct type of file
attstruc=ncdf_inquire(ncid1)
IF ( attstruc.ngatts GT 0 ) THEN BEGIN
   typeversion = ncdf_attname(ncid1, 0, /global)
   IF ( typeversion NE 'PR_Version' ) THEN BEGIN
      print, ''
      print, "ERROR from read_geo_match_netcdf:"
      print, "File copy ", ncfile, " is not a PR-GR matchup file!"
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
   print, "ERROR from read_geo_match_netcdf:"
   print, "File ", ncfile, " is not a valid geo_match netCDF file!"
   status = 1
   goto, ErrorExit
ENDIF
NCDF_VARGET, ncid1, versid, ncversion

IF N_Elements(matchupmeta) NE 0 THEN BEGIN
     NCDF_VARGET, ncid1, 'timeNearestApproach', dtime
     matchupmeta.timeNearestApproach = dtime
     NCDF_VARGET, ncid1, 'atimeNearestApproach', txtdtimebyte
     matchupmeta.atimeNearestApproach = string(txtdtimebyte)
     zdimid = NCDF_DIMID(ncid1, 'elevationAngle')
     NCDF_DIMINQ, ncid1, zdimid, XDIMNAME, ncnz
     matchupmeta.num_sweeps = ncnz
     fpdimid = NCDF_DIMID(ncid1, 'fpdim')
     NCDF_DIMINQ, ncid1, fpdimid, FPDIMNAME, nprfp
     matchupmeta.num_footprints = nprfp
     IF ncversion GE 3.0 THEN BEGIN
        hidimid = NCDF_DIMID(ncid1, 'hidim')
        NCDF_DIMINQ, ncid1, hidimid, HIDIMNAME, nhidcats
        matchupmeta.num_HID_categories = nhidcats
        ncdf_attget, ncid1, 'GV_UF_RR_field', gv_UF_field_byte, /global
        matchupmeta.GV_UF_RR_field = STRING(gv_UF_field_byte)
        ncdf_attget, ncid1, 'GV_UF_ZDR_field', gv_UF_field_byte, /global
        matchupmeta.GV_UF_ZDR_field = STRING(gv_UF_field_byte)
        ncdf_attget, ncid1, 'GV_UF_KDP_field', gv_UF_field_byte, /global
        matchupmeta.GV_UF_KDP_field = STRING(gv_UF_field_byte)
        ncdf_attget, ncid1, 'GV_UF_RHOHV_field', gv_UF_field_byte, /global
        matchupmeta.GV_UF_RHOHV_field = STRING(gv_UF_field_byte)
        ncdf_attget, ncid1, 'GV_UF_HID_field', gv_UF_field_byte, /global
        matchupmeta.GV_UF_HID_field = STRING(gv_UF_field_byte)
        ncdf_attget, ncid1, 'GV_UF_D0_field', gv_UF_field_byte, /global
        matchupmeta.GV_UF_D0_field = STRING(gv_UF_field_byte)
        ncdf_attget, ncid1, 'GV_UF_NW_field', gv_UF_field_byte, /global
        matchupmeta.GV_UF_NW_field = STRING(gv_UF_field_byte)
     ENDIF
     NCDF_VARGET, ncid1, 'rangeThreshold', rngthresh
     matchupmeta.rangeThreshold = rngthresh
     NCDF_VARGET, ncid1, 'PR_dBZ_min', przmin
     matchupmeta.PR_dBZ_min = przmin
     NCDF_VARGET, ncid1, 'GV_dBZ_min', gvzmin
     matchupmeta.GV_dBZ_min = gvzmin
     NCDF_VARGET, ncid1, 'rain_min', rnmin
     matchupmeta.rain_min = rnmin
;     NCDF_VARGET, ncid1, versid, ncversion  ; already "got" this variable
     matchupmeta.nc_file_version = ncversion
     ncdf_attget, ncid1, 'PR_Version', PR_vers, /global
     matchupmeta.PR_Version = PR_vers
     IF ncversion GE 3.0 THEN BEGIN
        ncdf_attget, ncid1, 'PPS_Version', PPS_vers_byte, /global
        matchupmeta.PPS_Version = STRING(PPS_vers_byte)
     ENDIF
     ncdf_attget, ncid1, 'GV_UF_Z_field', gv_UF_field_byte, /global
     matchupmeta.GV_UF_Z_field = STRING(gv_UF_field_byte)
ENDIF

IF N_Elements(sweepsmeta) NE 0 THEN BEGIN
     zdimid = NCDF_DIMID(ncid1, 'elevationAngle')
     NCDF_DIMINQ, ncid1, zdimid, XDIMNAME, ncnz  ; number of sweeps/elevs.
     NCDF_VARGET, ncid1, 'elevationAngle', nc_zlevels
     elevorder = SORT(nc_zlevels)
     ascorder = INDGEN(ncnz)
     sortflag=0
     IF TOTAL( ABS(elevorder-ascorder) ) NE 0 THEN BEGIN
        PRINT, 'read_geo_match_netcdf(): Elevation angles not in order! ', $
               'Resorting data.'
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
        PRINT, 'read_geo_match_netcdf(): Elevation angles not in order! ', $
               'Resorting data.'
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
    ; only have site_elev in Version 1.1 or later geo-match netCDF files
     IF ( ncversion GE 1.1 ) THEN BEGIN
        NCDF_VARGET, ncid1, 'site_elev', ncsiteElev
        sitemeta.site_elev = ncsiteElev
     ENDIF ELSE sitemeta.site_elev = 0.0
ENDIF

IF N_Elements(fieldFlags) NE 0 THEN BEGIN
     NCDF_VARGET, ncid1, 'have_threeDreflect', have_threeDreflect
     fieldFlags.have_threeDreflect = have_threeDreflect
     IF ncversion GE 2.0 THEN BEGIN
        NCDF_VARGET, ncid1, 'have_BBstatus', have_BBstatus
        fieldFlags.have_BBstatus = have_BBstatus
        NCDF_VARGET, ncid1, 'have_status', have_status_2a23
        fieldFlags.have_status_2a23 = have_status_2a23
     ENDIF
     IF ncversion EQ 2.2 THEN BEGIN
        NCDF_VARGET, ncid1, 'have_GR_DP_rainrate', have_GR_rainrate
        fieldflags.have_GR_rainrate = have_GR_rainrate
     ENDIF
     IF ncversion GE 3.0 THEN BEGIN
        NCDF_VARGET, ncid1, 'have_GR_rainrate', have_GR_rainrate
        fieldflags.have_GR_rainrate = have_GR_rainrate
        NCDF_VARGET, ncid1, 'have_GR_Zdr', have_GR_Zdr
        fieldflags.have_GR_Zdr = have_GR_Zdr
        NCDF_VARGET, ncid1, 'have_GR_Kdp', have_GR_Kdp
        fieldflags.have_GR_Kdp = have_GR_Kdp
        NCDF_VARGET, ncid1, 'have_GR_RHOhv', have_GR_RHOhv
        fieldflags.have_GR_RHOhv = have_GR_RHOhv
        NCDF_VARGET, ncid1, 'have_GR_HID', have_GR_HID
        fieldflags.have_GR_HID = have_GR_HID
        NCDF_VARGET, ncid1, 'have_GR_Dzero', have_GR_Dzero
        fieldflags.have_GR_Dzero = have_GR_Dzero
        NCDF_VARGET, ncid1, 'have_GR_Nw', have_GR_Nw
        fieldflags.have_GR_Nw = have_GR_Nw
     ENDIF
     IF ncversion GE 3.1 THEN BEGIN
        NCDF_VARGET, ncid1, 'have_PIA', have_PIA
        fieldflags.have_PIA = have_PIA
     ENDIF
     NCDF_VARGET, ncid1, 'have_dBZnormalSample', have_dBZnormalSample
     fieldFlags.have_dBZnormalSample = have_dBZnormalSample
     NCDF_VARGET, ncid1, 'have_correctZFactor', have_correctZFactor
     fieldFlags.have_correctZFactor = have_correctZFactor
     NCDF_VARGET, ncid1, 'have_rain', have_rain
     fieldFlags.have_rain = have_rain
     NCDF_VARGET, ncid1, 'have_landOceanFlag', have_landOceanFlag
     fieldFlags.have_landOceanFlag = have_landOceanFlag
     NCDF_VARGET, ncid1, 'have_nearSurfRain', have_nearSurfRain
     fieldFlags.have_nearSurfRain = have_nearSurfRain
     NCDF_VARGET, ncid1, 'have_nearSurfRain_2b31', have_nearSurfRain_2b31
     fieldFlags.have_nearSurfRain_2b31 = have_nearSurfRain_2b31
     NCDF_VARGET, ncid1, 'have_BBheight', have_BBheight
     fieldFlags.have_BBheight = have_BBheight
     NCDF_VARGET, ncid1, 'have_rainFlag', have_rainFlag
     fieldFlags.have_rainFlag = have_rainFlag
     NCDF_VARGET, ncid1, 'have_rainType', have_rainType
     fieldFlags.have_rainType = have_rainType
ENDIF

; PR and GR filenames were added to the 2.1 version matchup file.  Read them and
; override the 'UNKNOWN' initial values in the structure, if 2.1 or higher.
IF N_Elements(filesmeta) NE 0 THEN BEGIN
   IF ( ncversion GE 2.1 ) THEN BEGIN
      ncdf_attget, ncid1, 'PR_1C21_file', PR_1C21_file_byte, /global
      filesmeta.file_1c21 = STRING(PR_1C21_file_byte)
      ncdf_attget, ncid1, 'PR_2A23_file', PR_2A23_file_byte, /global
      filesmeta.file_2a23 = STRING(PR_2A23_file_byte)
      ncdf_attget, ncid1, 'PR_2A25_file', PR_2A25_file_byte, /global
      filesmeta.file_2a25 = STRING(PR_2A25_file_byte)
      ncdf_attget, ncid1, 'PR_2B31_file', PR_2B31_file_byte, /global
      filesmeta.file_2b31 = STRING(PR_2B31_file_byte)
      ncdf_attget, ncid1, 'GR_file', GR_file_byte, /global
      filesmeta.file_1CUF = STRING(GR_file_byte)
   ENDIF ELSE BEGIN
      print, "In read_geo_match_netcdf(): filesmeta requested, file names ", $
             "not available in file version ", ncversion
   ENDELSE
ENDIF

IF N_Elements(gvexpect) NE 0 THEN BEGIN
     NCDF_VARGET, ncid1, 'n_gv_expected', gvexpect
     IF ( sortflag EQ 1 ) THEN BEGIN
        sort_status = sort_multi_d_array( elevorder, gvexpect, 2 )
        IF (sort_status EQ 1) THEN BEGIN
          status = sort_status
          goto, ErrorExit
        ENDIF
     ENDIF
ENDIF

IF N_Elements(gvreject) NE 0 THEN BEGIN
     NCDF_VARGET, ncid1, 'n_gv_rejected', gvreject
     IF ( sortflag EQ 1 ) THEN BEGIN
        sort_status = sort_multi_d_array( elevorder, gvreject, 2 )
        IF (sort_status EQ 1) THEN BEGIN
          status = sort_status
          goto, ErrorExit
        ENDIF
     ENDIF
ENDIF

IF N_Elements(gv_rr_reject) NE 0 THEN BEGIN
   IF ncversion GE 2.2 THEN BEGIN
      NCDF_VARGET, ncid1, 'n_gv_rr_rejected', gv_rr_reject
      IF ( sortflag EQ 1 ) THEN BEGIN
         sort_status = sort_multi_d_array( elevorder, gv_rr_reject, 2 )
         IF (sort_status EQ 1) THEN BEGIN
           status = sort_status
           goto, ErrorExit
         ENDIF
      ENDIF
   ENDIF ELSE BEGIN
      print, "In read_geo_match_netcdf(): gv_rr_reject requested, ", $
             "not available in file version ", ncversion
   ENDELSE
ENDIF

IF N_Elements(gv_zdr_reject) NE 0 THEN BEGIN
   IF ncversion GE 3.0 THEN BEGIN
      NCDF_VARGET, ncid1, 'n_gv_zdr_rejected', gv_zdr_reject
      IF ( sortflag EQ 1 ) THEN BEGIN
         sort_status = sort_multi_d_array( elevorder, gv_zdr_reject, 2 )
         IF (sort_status EQ 1) THEN BEGIN
           status = sort_status
           goto, ErrorExit
         ENDIF
      ENDIF
   ENDIF ELSE BEGIN
      print, "In read_geo_match_netcdf(): gv_zdr_reject requested, ", $
             "not available in file version ", ncversion
   ENDELSE
ENDIF

IF N_Elements(gv_kdp_reject) NE 0 THEN BEGIN
   IF ncversion GE 3.0 THEN BEGIN
      NCDF_VARGET, ncid1, 'n_gv_kdp_rejected', gv_kdp_reject
      IF ( sortflag EQ 1 ) THEN BEGIN
         sort_status = sort_multi_d_array( elevorder, gv_kdp_reject, 2 )
         IF (sort_status EQ 1) THEN BEGIN
           status = sort_status
           goto, ErrorExit
         ENDIF
      ENDIF
   ENDIF ELSE BEGIN
      print, "In read_geo_match_netcdf(): gv_kdp_reject requested, ", $
             "not available in file version ", ncversion
   ENDELSE
ENDIF

IF N_Elements(gv_RHOhv_reject) NE 0 THEN BEGIN
   IF ncversion GE 3.0 THEN BEGIN
      NCDF_VARGET, ncid1, 'n_gv_rhohv_rejected', gv_RHOhv_reject
      IF ( sortflag EQ 1 ) THEN BEGIN
         sort_status = sort_multi_d_array( elevorder, gv_RHOhv_reject, 2 )
         IF (sort_status EQ 1) THEN BEGIN
           status = sort_status
           goto, ErrorExit
         ENDIF
      ENDIF
   ENDIF ELSE BEGIN
      print, "In read_geo_match_netcdf(): gv_RHOhv_reject requested, ", $
             "not available in file version ", ncversion
   ENDELSE
ENDIF

IF N_Elements(gv_hid_reject) NE 0 THEN BEGIN
   IF ncversion GE 3.0 THEN BEGIN
      NCDF_VARGET, ncid1, 'n_gv_hid_rejected', gv_hid_reject
      IF ( sortflag EQ 1 ) THEN BEGIN
         sort_status = sort_multi_d_array( elevorder, gv_hid_reject, 2 )
         IF (sort_status EQ 1) THEN BEGIN
           status = sort_status
           goto, ErrorExit
         ENDIF
      ENDIF
   ENDIF ELSE BEGIN
      print, "In read_geo_match_netcdf(): gv_hid_reject requested, ", $
             "not available in file version ", ncversion
   ENDELSE
ENDIF

IF N_Elements(gv_dzero_reject) NE 0 THEN BEGIN
   IF ncversion GE 3.0 THEN BEGIN
      NCDF_VARGET, ncid1, 'n_gv_dzero_rejected', gv_dzero_reject
      IF ( sortflag EQ 1 ) THEN BEGIN
         sort_status = sort_multi_d_array( elevorder, gv_dzero_reject, 2 )
         IF (sort_status EQ 1) THEN BEGIN
           status = sort_status
           goto, ErrorExit
         ENDIF
      ENDIF
   ENDIF ELSE BEGIN
      print, "In read_geo_match_netcdf(): gv_dzero_reject requested, ", $
             "not available in file version ", ncversion
   ENDELSE
ENDIF

IF N_Elements(gv_nw_reject) NE 0 THEN BEGIN
   IF ncversion GE 3.0 THEN BEGIN
      NCDF_VARGET, ncid1, 'n_gv_nw_rejected', gv_nw_reject
      IF ( sortflag EQ 1 ) THEN BEGIN
         sort_status = sort_multi_d_array( elevorder, gv_nw_reject, 2 )
         IF (sort_status EQ 1) THEN BEGIN
           status = sort_status
           goto, ErrorExit
         ENDIF
      ENDIF
   ENDIF ELSE BEGIN
      print, "In read_geo_match_netcdf(): gv_nw_reject requested, ", $
             "not available in file version ", ncversion
   ENDELSE
ENDIF

IF N_Elements(prexpect) NE 0 THEN BEGIN
     NCDF_VARGET, ncid1, 'n_pr_expected', prexpect
     IF ( sortflag EQ 1 ) THEN BEGIN
        sort_status = sort_multi_d_array( elevorder, prexpect, 2 )
        IF (sort_status EQ 1) THEN BEGIN
          status = sort_status
          goto, ErrorExit
        ENDIF
     ENDIF
ENDIF

IF N_Elements(zrawreject) NE 0 THEN BEGIN
     NCDF_VARGET, ncid1, 'n_1c21_z_rejected', zrawreject
     IF ( sortflag EQ 1 ) THEN BEGIN
        sort_status = sort_multi_d_array( elevorder, zrawreject, 2 )
        IF (sort_status EQ 1) THEN BEGIN
          status = sort_status
          goto, ErrorExit
        ENDIF
     ENDIF
ENDIF

IF N_Elements(zcorreject) NE 0 THEN BEGIN
     NCDF_VARGET, ncid1, 'n_2a25_z_rejected', zcorreject
     IF ( sortflag EQ 1 ) THEN BEGIN
        sort_status = sort_multi_d_array( elevorder, zcorreject, 2 )
        IF (sort_status EQ 1) THEN BEGIN
          status = sort_status
          goto, ErrorExit
        ENDIF
     ENDIF
ENDIF

IF N_Elements(rainreject) NE 0 THEN BEGIN
     NCDF_VARGET, ncid1, 'n_2a25_r_rejected', rainreject
     IF ( sortflag EQ 1 ) THEN BEGIN
        sort_status = sort_multi_d_array( elevorder, rainreject, 2 )
        IF (sort_status EQ 1) THEN BEGIN
          status = sort_status
          goto, ErrorExit
        ENDIF
     ENDIF
ENDIF

IF N_Elements(threeDreflect) NE 0 THEN BEGIN
     NCDF_VARGET, ncid1, 'threeDreflect', threeDreflect
     IF ( sortflag EQ 1 ) THEN BEGIN
        sort_status = sort_multi_d_array( elevorder, threeDreflect, 2 )
        IF (sort_status EQ 1) THEN BEGIN
          status = sort_status
          goto, ErrorExit
        ENDIF
     ENDIF
ENDIF

IF N_Elements(threeDreflectMax) NE 0 THEN BEGIN
   IF ncversion GE 2.0 THEN BEGIN
      NCDF_VARGET, ncid1, 'threeDreflectMax', threeDreflectMax
      IF ( sortflag EQ 1 ) THEN BEGIN
         sort_status = sort_multi_d_array( elevorder, threeDreflectMax, 2 )
         IF (sort_status EQ 1) THEN BEGIN
           status = sort_status
           goto, ErrorExit
         ENDIF
      ENDIF
   ENDIF ELSE BEGIN
      print, "In read_geo_match_netcdf(): threeDreflectMax requested, ", $
             "not available in file version ", ncversion
   ENDELSE
ENDIF

IF N_Elements(threeDreflectStdDev) NE 0 THEN BEGIN
   IF ncversion GE 2.0 THEN BEGIN
      NCDF_VARGET, ncid1, 'threeDreflectStdDev', threeDreflectStdDev
      IF ( sortflag EQ 1 ) THEN BEGIN
         sort_status = sort_multi_d_array( elevorder, threeDreflectStdDev, 2 )
         IF (sort_status EQ 1) THEN BEGIN
           status = sort_status
           goto, ErrorExit
         ENDIF
      ENDIF
   ENDIF ELSE BEGIN
      print, "In read_geo_match_netcdf(): threeDreflectStdDev requested, ", $
             "not available in file version ", ncversion
   ENDELSE
ENDIF

IF N_Elements(GR_Zdr) NE 0 THEN BEGIN
   IF ncversion GE 3.0 THEN BEGIN
      NCDF_VARGET, ncid1, 'GR_Zdr', GR_Zdr
      IF ( sortflag EQ 1 ) THEN BEGIN
         sort_status = sort_multi_d_array( elevorder, GR_Zdr, 2 )
         IF (sort_status EQ 1) THEN BEGIN
           status = sort_status
           goto, ErrorExit
         ENDIF
      ENDIF
   ENDIF ELSE BEGIN
      print, "In read_geo_match_netcdf(): GR_Zdr requested, ", $
             "not available in file version ", ncversion
   ENDELSE
ENDIF

IF N_Elements(GR_ZdrMax) NE 0 THEN BEGIN
   IF ncversion GE 3.0 THEN BEGIN
      NCDF_VARGET, ncid1, 'GR_ZdrMax', GR_ZdrMax
      IF ( sortflag EQ 1 ) THEN BEGIN
         sort_status = sort_multi_d_array( elevorder, GR_ZdrMax, 2 )
         IF (sort_status EQ 1) THEN BEGIN
           status = sort_status
           goto, ErrorExit
         ENDIF
      ENDIF
   ENDIF ELSE BEGIN
      print, "In read_geo_match_netcdf(): GR_ZdrMax requested, ", $
             "not available in file version ", ncversion
   ENDELSE
ENDIF

IF N_Elements(GR_ZdrStdDev) NE 0 THEN BEGIN
   IF ncversion GE 3.0 THEN BEGIN
      NCDF_VARGET, ncid1, 'GR_ZdrStdDev', GR_ZdrStdDev
      IF ( sortflag EQ 1 ) THEN BEGIN
         sort_status = sort_multi_d_array( elevorder, GR_ZdrStdDev, 2 )
         IF (sort_status EQ 1) THEN BEGIN
           status = sort_status
           goto, ErrorExit
         ENDIF
      ENDIF
   ENDIF ELSE BEGIN
      print, "In read_geo_match_netcdf(): GR_ZdrStdDev requested, ", $
             "not available in file version ", ncversion
   ENDELSE
ENDIF

IF N_Elements(GR_Kdp) NE 0 THEN BEGIN
   IF ncversion GE 3.0 THEN BEGIN
      NCDF_VARGET, ncid1, 'GR_Kdp', GR_Kdp
      IF ( sortflag EQ 1 ) THEN BEGIN
         sort_status = sort_multi_d_array( elevorder, GR_Kdp, 2 )
         IF (sort_status EQ 1) THEN BEGIN
           status = sort_status
           goto, ErrorExit
         ENDIF
      ENDIF
   ENDIF ELSE BEGIN
      print, "In read_geo_match_netcdf(): GR_Kdp requested, ", $
             "not available in file version ", ncversion
   ENDELSE
ENDIF

IF N_Elements(GR_KdpMax) NE 0 THEN BEGIN
   IF ncversion GE 3.0 THEN BEGIN
      NCDF_VARGET, ncid1, 'GR_KdpMax', GR_KdpMax
      IF ( sortflag EQ 1 ) THEN BEGIN
         sort_status = sort_multi_d_array( elevorder, GR_KdpMax, 2 )
         IF (sort_status EQ 1) THEN BEGIN
           status = sort_status
           goto, ErrorExit
         ENDIF
      ENDIF
   ENDIF ELSE BEGIN
      print, "In read_geo_match_netcdf(): GR_KdpMax requested, ", $
             "not available in file version ", ncversion
   ENDELSE
ENDIF

IF N_Elements(GR_KdpStdDev) NE 0 THEN BEGIN
   IF ncversion GE 3.0 THEN BEGIN
      NCDF_VARGET, ncid1, 'GR_KdpStdDev', GR_KdpStdDev
      IF ( sortflag EQ 1 ) THEN BEGIN
         sort_status = sort_multi_d_array( elevorder, GR_KdpStdDev, 2 )
         IF (sort_status EQ 1) THEN BEGIN
           status = sort_status
           goto, ErrorExit
         ENDIF
      ENDIF
   ENDIF ELSE BEGIN
      print, "In read_geo_match_netcdf(): GR_KdpStdDev requested, ", $
             "not available in file version ", ncversion
   ENDELSE
ENDIF

IF N_Elements(GR_RHOhv) NE 0 THEN BEGIN
   IF ncversion GE 3.0 THEN BEGIN
      NCDF_VARGET, ncid1, 'GR_RHOhv', GR_RHOhv
      IF ( sortflag EQ 1 ) THEN BEGIN
         sort_status = sort_multi_d_array( elevorder, GR_RHOhv, 2 )
         IF (sort_status EQ 1) THEN BEGIN
           status = sort_status
           goto, ErrorExit
         ENDIF
      ENDIF
   ENDIF ELSE BEGIN
      print, "In read_geo_match_netcdf(): GR_RHOhv requested, ", $
             "not available in file version ", ncversion
   ENDELSE
ENDIF

IF N_Elements(GR_RHOhvMax) NE 0 THEN BEGIN
   IF ncversion GE 3.0 THEN BEGIN
      NCDF_VARGET, ncid1, 'GR_RHOhvMax', GR_RHOhvMax
      IF ( sortflag EQ 1 ) THEN BEGIN
         sort_status = sort_multi_d_array( elevorder, GR_RHOhvMax, 2 )
         IF (sort_status EQ 1) THEN BEGIN
           status = sort_status
           goto, ErrorExit
         ENDIF
      ENDIF
   ENDIF ELSE BEGIN
      print, "In read_geo_match_netcdf(): GR_RHOhvMax requested, ", $
             "not available in file version ", ncversion
   ENDELSE
ENDIF

IF N_Elements(GR_RHOhvStdDev) NE 0 THEN BEGIN
   IF ncversion GE 3.0 THEN BEGIN
      NCDF_VARGET, ncid1, 'GR_RHOhvStdDev', GR_RHOhvStdDev
      IF ( sortflag EQ 1 ) THEN BEGIN
         sort_status = sort_multi_d_array( elevorder, GR_RHOhvStdDev, 2 )
         IF (sort_status EQ 1) THEN BEGIN
           status = sort_status
           goto, ErrorExit
         ENDIF
      ENDIF
   ENDIF ELSE BEGIN
      print, "In read_geo_match_netcdf(): GR_RHOhvStdDev requested, ", $
             "not available in file version ", ncversion
   ENDELSE
ENDIF

IF N_Elements(GR_rainrate) NE 0 THEN BEGIN
   IF ncversion GE 2.2 THEN BEGIN
      IF ncversion EQ 2.2 $
         THEN NCDF_VARGET, ncid1, 'GR_DP_rainrate', GR_rainrate $
         ELSE NCDF_VARGET, ncid1, 'GR_rainrate', GR_rainrate
      IF ( sortflag EQ 1 ) THEN BEGIN
         sort_status = sort_multi_d_array( elevorder, GR_rainrate, 2 )
         IF (sort_status EQ 1) THEN BEGIN
           status = sort_status
           goto, ErrorExit
         ENDIF
      ENDIF
   ENDIF ELSE BEGIN
      print, "In read_geo_match_netcdf(): GR_rainrate requested, ", $
             "not available in file version ", ncversion
   ENDELSE
ENDIF

IF N_Elements(GR_rainrateMax) NE 0 THEN BEGIN
   IF ncversion GE 2.2 THEN BEGIN
      IF ncversion EQ 2.2 $
         THEN NCDF_VARGET, ncid1, 'GR_DP_rainrateMax', GR_rainrateMax $
         ELSE NCDF_VARGET, ncid1, 'GR_rainrateMax', GR_rainrateMax 
      IF ( sortflag EQ 1 ) THEN BEGIN
         sort_status = sort_multi_d_array( elevorder, GR_rainrateMax, 2 )
         IF (sort_status EQ 1) THEN BEGIN
           status = sort_status
           goto, ErrorExit
         ENDIF
      ENDIF
   ENDIF ELSE BEGIN
      print, "In read_geo_match_netcdf(): GR_rainrateMax requested, ", $
             "not available in file version ", ncversion
   ENDELSE
ENDIF

IF N_Elements(GR_rainrateStdDev) NE 0 THEN BEGIN
   IF ncversion GE 2.2 THEN BEGIN
      IF ncversion EQ 2.2 $
         THEN NCDF_VARGET, ncid1, 'GR_DP_rainrateStdDev', GR_rainrateStdDev $
         ELSE NCDF_VARGET, ncid1, 'GR_rainrateStdDev', GR_rainrateStdDev
      IF ( sortflag EQ 1 ) THEN BEGIN
         sort_status = sort_multi_d_array( elevorder, GR_rainrateStdDev, 2 )
         IF (sort_status EQ 1) THEN BEGIN
           status = sort_status
           goto, ErrorExit
         ENDIF
      ENDIF
   ENDIF ELSE BEGIN
      print, "In read_geo_match_netcdf(): GR_rainrateStdDev requested, ", $
             "not available in file version ", ncversion
   ENDELSE
ENDIF

IF N_Elements(GR_HID) NE 0 THEN BEGIN
   IF ncversion GE 3.0 THEN BEGIN
      NCDF_VARGET, ncid1, 'GR_HID', GR_HID
      IF ( sortflag EQ 1 ) THEN BEGIN
         sort_status = sort_multi_d_array( elevorder, GR_HID, 3 )
         IF (sort_status EQ 1) THEN BEGIN
           status = sort_status
           goto, ErrorExit
         ENDIF
      ENDIF
   ENDIF ELSE BEGIN
      print, "In read_geo_match_netcdf(): GR_HID requested, ", $
             "not available in file version ", ncversion
   ENDELSE
ENDIF

IF N_Elements(GR_Dzero) NE 0 THEN BEGIN
   IF ncversion GE 3.0 THEN BEGIN
      NCDF_VARGET, ncid1, 'GR_Dzero', GR_Dzero
      IF ( sortflag EQ 1 ) THEN BEGIN
         sort_status = sort_multi_d_array( elevorder, GR_Dzero, 2 )
         IF (sort_status EQ 1) THEN BEGIN
           status = sort_status
           goto, ErrorExit
         ENDIF
      ENDIF
   ENDIF ELSE BEGIN
      print, "In read_geo_match_netcdf(): GR_Dzero requested, ", $
             "not available in file version ", ncversion
   ENDELSE
ENDIF

IF N_Elements(GR_DzeroMax) NE 0 THEN BEGIN
   IF ncversion GE 3.0 THEN BEGIN
      NCDF_VARGET, ncid1, 'GR_DzeroMax', GR_DzeroMax
      IF ( sortflag EQ 1 ) THEN BEGIN
         sort_status = sort_multi_d_array( elevorder, GR_DzeroMax, 2 )
         IF (sort_status EQ 1) THEN BEGIN
           status = sort_status
           goto, ErrorExit
         ENDIF
      ENDIF
   ENDIF ELSE BEGIN
      print, "In read_geo_match_netcdf(): GR_DzeroMax requested, ", $
             "not available in file version ", ncversion
   ENDELSE
ENDIF

IF N_Elements(GR_DzeroStdDev) NE 0 THEN BEGIN
   IF ncversion GE 3.0 THEN BEGIN
      NCDF_VARGET, ncid1, 'GR_DzeroStdDev', GR_DzeroStdDev
      IF ( sortflag EQ 1 ) THEN BEGIN
         sort_status = sort_multi_d_array( elevorder, GR_DzeroStdDev, 2 )
         IF (sort_status EQ 1) THEN BEGIN
           status = sort_status
           goto, ErrorExit
         ENDIF
      ENDIF
   ENDIF ELSE BEGIN
      print, "In read_geo_match_netcdf(): GR_DzeroStdDev requested, ", $
             "not available in file version ", ncversion
   ENDELSE
ENDIF

IF N_Elements(GR_Nw) NE 0 THEN BEGIN
   IF ncversion GE 3.0 THEN BEGIN
      NCDF_VARGET, ncid1, 'GR_Nw', GR_Nw
      IF ( sortflag EQ 1 ) THEN BEGIN
         sort_status = sort_multi_d_array( elevorder, GR_Nw, 2 )
         IF (sort_status EQ 1) THEN BEGIN
           status = sort_status
           goto, ErrorExit
         ENDIF
      ENDIF
   ENDIF ELSE BEGIN
      print, "In read_geo_match_netcdf(): GR_Nw requested, ", $
             "not available in file version ", ncversion
   ENDELSE
ENDIF

IF N_Elements(GR_NwMax) NE 0 THEN BEGIN
   IF ncversion GE 3.0 THEN BEGIN
      NCDF_VARGET, ncid1, 'GR_NwMax', GR_NwMax
      IF ( sortflag EQ 1 ) THEN BEGIN
         sort_status = sort_multi_d_array( elevorder, GR_NwMax, 2 )
         IF (sort_status EQ 1) THEN BEGIN
           status = sort_status
           goto, ErrorExit
         ENDIF
      ENDIF
   ENDIF ELSE BEGIN
      print, "In read_geo_match_netcdf(): GR_NwMax requested, ", $
             "not available in file version ", ncversion
   ENDELSE
ENDIF

IF N_Elements(GR_NwStdDev) NE 0 THEN BEGIN
   IF ncversion GE 3.0 THEN BEGIN
      NCDF_VARGET, ncid1, 'GR_NwStdDev', GR_NwStdDev
      IF ( sortflag EQ 1 ) THEN BEGIN
         sort_status = sort_multi_d_array( elevorder, GR_NwStdDev, 2 )
         IF (sort_status EQ 1) THEN BEGIN
           status = sort_status
           goto, ErrorExit
         ENDIF
      ENDIF
   ENDIF ELSE BEGIN
      print, "In read_geo_match_netcdf(): GR_NwStdDev requested, ", $
             "not available in file version ", ncversion
   ENDELSE
ENDIF

IF N_Elements(dBZnormalSample) NE 0 THEN BEGIN
     NCDF_VARGET, ncid1, 'dBZnormalSample', dBZnormalSample
     IF ( sortflag EQ 1 ) THEN BEGIN
        sort_status = sort_multi_d_array( elevorder, dBZnormalSample, 2 )
        IF (sort_status EQ 1) THEN BEGIN
          status = sort_status
          goto, ErrorExit
        ENDIF
     ENDIF
ENDIF

IF N_Elements(correctZFactor) NE 0 THEN BEGIN
     NCDF_VARGET, ncid1, 'correctZFactor', correctZfactor
     IF ( sortflag EQ 1 ) THEN BEGIN
        sort_status = sort_multi_d_array( elevorder, correctZfactor, 2 )
        IF (sort_status EQ 1) THEN BEGIN
          status = sort_status
          goto, ErrorExit
        ENDIF
     ENDIF
ENDIF

IF N_Elements(rain) NE 0 THEN BEGIN
     NCDF_VARGET, ncid1, 'rain', rain
     IF ( sortflag EQ 1 ) THEN BEGIN
        sort_status = sort_multi_d_array( elevorder, rain, 2 )
        IF (sort_status EQ 1) THEN BEGIN
          status = sort_status
          goto, ErrorExit
        ENDIF
     ENDIF
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

IF N_Elements(PRlatitude) NE 0 THEN $
     NCDF_VARGET, ncid1, 'PRlatitude', PRlatitude

IF N_Elements(PRlongitude) NE 0 THEN $
     NCDF_VARGET, ncid1, 'PRlongitude', PRlongitude

IF N_Elements(nearSurfRain) NE 0 THEN $
     NCDF_VARGET, ncid1, 'nearSurfRain', nearSurfRain

IF N_Elements(nearSurfRain_2b31) NE 0 THEN $
     NCDF_VARGET, ncid1, 'nearSurfRain_2b31', nearSurfRain_2b31

IF N_Elements(BBheight) NE 0 THEN $
     NCDF_VARGET, ncid1, 'BBheight', BBheight  ; now in meters! (if > 0)

IF N_Elements(landOceanFlag) NE 0 THEN $
     NCDF_VARGET, ncid1, 'landOceanFlag', landoceanFlag

IF N_Elements(rainFlag) NE 0 THEN $
     NCDF_VARGET, ncid1, 'rainFlag', rainFlag

IF N_Elements(rainType) NE 0 THEN $
     NCDF_VARGET, ncid1, 'rainType', rainType

IF N_Elements(rayIndex) NE 0 THEN $
     NCDF_VARGET, ncid1, 'rayIndex', rayIndex

IF N_Elements(BBstatus) NE 0 THEN BEGIN
   IF ncversion GE 2.0 THEN BEGIN
      NCDF_VARGET, ncid1, 'BBstatus', BBstatus
   ENDIF ELSE BEGIN
      print, "In read_geo_match_netcdf(): BBstatus requested, ", $
             "not available in file version ", ncversion
   ENDELSE
ENDIF

IF N_Elements(status_2a23) NE 0 THEN BEGIN
   IF ncversion GE 2.0 THEN BEGIN
      NCDF_VARGET, ncid1, 'status', status_2a23
   ENDIF ELSE BEGIN
      print, "In read_geo_match_netcdf(): 2A23 status requested, ", $
             "not available in file version ", ncversion
   ENDELSE
ENDIF

IF N_Elements(pia) NE 0 THEN BEGIN
   IF ncversion GE 3.1 THEN BEGIN
      NCDF_VARGET, ncid1, 'PIA', pia
   ENDIF ELSE BEGIN
      print, "In read_geo_match_netcdf(): PIA requested, ", $
             "not available in file version ", ncversion
   ENDELSE
ENDIF

ErrorExit:
NCDF_CLOSE, ncid1

RETURN, status
END
