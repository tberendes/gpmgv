;===============================================================================
;+
; Copyright © 2008, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; stratified_by_dist_stats_to_dbfile.pro   Morris/SAIC/GPM_GV      October 2007
;
; DESCRIPTION
; -----------
; Steps through the set of PR, GV, and GV-REORDER netCDF grids, and computes
; PR-GV reflectivity mean difference and its standard deviation, and PR and GV
; maximum and mean reflectivity. Statistical results are stratified by raincloud
; type (Convective, Stratiform) and vertical location w.r.t the bright band
; (above, within, below), and in total for all eligible points, for a total of 7
; permutations.  These 7 permutations are further stratified by the points'
; distance from the radar in 3 categories: 0-49km, 50-99km, and 100-150km, for a
; grand total of 21 raintype/location/range categories.  The results and their
; identifying metadata are written out to an ASCII, delimited text file in a
; format ready to be loaded into the table 'dbzdiff_stats_by_dist' in the
; 'gpmgv' database.
;
; PR-GV differences are computed separately for the 2A-55-based GV data and the
; REORDER-based GV data, for each height level in the grids, for each GV site,
; and for each orbit.
;
; PARAMETERS
; ----------
; None.
;
; FILES
; -----
; /data/tmp/StatsByDistToDB.unl      OUTPUT: Formatted ASCII text file holding
;                                            the computed, stratified PR-GV
;                                            reflectivity statistics and its
;                                            identifying metadata fields.
; /data/netcdf/PR/PRgrids*            INPUT: The set of site/orbit specific
;                                            PR netCDF grid files for which
;                                            stats are to be computed.  The set
;                                            of files used may be limited by
;                                            editing the file pattern specified
;                                            by the 'pathpr' internal variable.
; /data/netcdf/NEXRAD/GVgrids*        INPUT: The set of site/orbit specific GV
;                                            netCDF grid files (2A-5x based)
;                                            for which stats are to be computed.
;                                            For each eligible PR file, the
;                                            code attempts to find the matching
;                                            GV netCDF grid file.
;
; /data/netcdf/NEXRAD_REO/allYMD/GVgridsREO*
;                                     INPUT: The set of site/orbit specific GV
;                                            netCDF grid files (REORDER-based)
;                                            for which stats are to be computed.
;                                            For each eligible PR file, the
;                                            code attempts to find the matching
;                                            GV REO netCDF grid file.
;
; CALLS
; -----
; uncomp_file()    stratify_diffs21dist    printf_stat_struct21dist
;
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;===============================================================================

pro stratified_by_dist_stats_to_dbfile

dbfile = '/data/tmp/StatsByDistToDBnew100.unl'
OPENW, DBunit, dbfile, /GET_LUN

statsset = { event_stats, $
            AvgDif: -99.999, StdDev: -99.999, $
            PRmaxZ: -99.999, PRavgZ: -99.999, $
            GVmaxZ: -99.999, GVavgZ: -99.999, $
            N: 0L $
           }

allstats = { stats7ways, $
	    stats_total:       {event_stats}, $
            stats_convbelow:   {event_stats}, $
	    stats_convin:      {event_stats}, $
	    stats_convabove:   {event_stats}, $
	    stats_stratbelow:  {event_stats}, $
	    stats_stratin:     {event_stats}, $
	    stats_stratabove:  {event_stats}  $
           }

; We will make a copy of this structure variable for each level and GV type
; we process so that everything is re-initialized.
statsbydist = { stats21ways, $
              km_le_50:    {stats7ways}, $
              km_50_100:     {stats7ways}, $
              km_gt_100:   {stats7ways}, $
              pts_le_50:  0L, $
              pts_50_100:   0L, $
              pts_gt_100: 0L  $
             }

pathpr = '/data/netcdf/PR/PRgrids*'
pathgv = '/data/netcdf/NEXRAD/GVgrids'
pathgv2 = '/data/netcdf/NEXRAD_REO/allYMD/GVgridsREO'


prfiles = file_search(pathpr,COUNT=nf)
if nf gt 0 then begin

; Compute a radial distance array of 2-D netCDF grid dimensions
xdist = findgen(75,75)
xdist = ((xdist mod 75.) - 37.) * 4.
ydist = TRANSPOSE(xdist)
dist = SQRT(xdist*xdist + ydist*ydist)
idxnear=where(dist le 50.)
idxfar= where(dist gt 100.)

for fnum = 0, nf-1 do begin

haveREO = 0
ncfilepr = prfiles(fnum)
bname = file_basename( ncfilepr )
prlen = strlen( bname )
gvpost = strmid( bname, 7, prlen)
ncfilegv = pathgv + gvpost
ncfilegv2 = pathgv2 + gvpost

parsed = strsplit(bname, '.', /EXTRACT)
orbit = parsed[3]

print, ncfilepr

; Get uncompressed copy of the found files
cpstatus = uncomp_file( ncfilepr, ncfile1 )
if(cpstatus eq 'OK') then begin
  cpstatus2 = uncomp_file( ncfilegv, ncfile2 )
  if(cpstatus2 eq 'OK') then begin
     ncid1 = NCDF_OPEN( ncfile1 )
     ncid2 = NCDF_OPEN( ncfile2 )

     siteID = ""
     NCDF_VARGET, ncid1, 'site_ID', siteIDbyte
     NCDF_VARGET, ncid1, 'site_lat', siteLat
     NCDF_VARGET, ncid1, 'site_lon', siteLong
     NCDF_VARGET, ncid1, 'timeNearestApproach', event_time
     NCDF_VARGET, ncid1, 'correctZFactor', dbzcor
;    The 2-D grids are of INT type
     NCDF_VARGET, ncid1, 'BBheight', BB_Hgt  ; now in meters! (if > 0)
;     NCDF_VARGET, ncid1, 'landOceanFlag', landoceanMap
;     NCDF_VARGET, ncid1, 'rainFlag', rainFlagMap
     NCDF_VARGET, ncid1, 'rainType', rainTypeMap

;    query 2A-55 netCDF file variables
        NCDF_VARGET, ncid2, 'threeDreflect', dbznex
        NCDF_VARGET, ncid2, 'beginTimeOfVolumeScan', event_time2

;    query REORDER netCDF file variables, if REO available
     cpstatusREO = uncomp_file( ncfilegv2, ncfilereo )
     if (cpstatusREO eq 'OK') then begin
        haveREO = 1                          ; initialize flag
        ncid3 = NCDF_OPEN( ncfilereo )
        NCDF_VARGET, ncid3, 'CZ', dbznexREO
        NCDF_VARGET, ncid3, 'base_time', event_timeREO
        NCDF_CLOSE, ncid3
        command4 = "rm " + ncfilereo
        spawn, command4
     endif else begin
        print, 'Cannot find GVREO netCDF file: ', ncfilegv2
        print, cpstatus2
     endelse

     siteID = string(siteIDbyte)
;     print, siteID, siteLat, siteLong, event_time, event_time2

     NCDF_CLOSE, ncid1
     command3 = "rm " + ncfile1
     spawn, command3

     NCDF_CLOSE, ncid2
     command4 = "rm " + ncfile2
     spawn, command4
  endif else begin
     print, 'Cannot find GV netCDF file: ', ncfilegv
     print, cpstatus2
     command3 = "rm -v " + ncfile1
     spawn, command3
     goto, nextFile
  endelse
endif else begin
  print, 'Cannot copy/unzip PR netCDF file: ', ncfilepr
  print, cpstatus
  command3 = "rm -v " + ncfile1
  spawn, command3
  goto, errorExit
endelse

; Convert BB height to level index 0-12, or -1 if missing/undefined
idxbbmiss = where(BB_Hgt le 0, countbbmiss)
if (countbbmiss gt 0) then BB_Hgt[idxbbmiss] = -1
idxbb = where(BB_Hgt gt 0, countbb)
if (countbb gt 0) then begin
;  Level below BB is affected if BB_Hgt is within 1000m above layer center,
;  so BB_HgtLo is lowest grid layer considered to be within the BB
   BB_HgtLo = (BB_Hgt[idxbb]-1001)/1500
;  Level above BB is affected if BB_Hgt is within 1000m below layer center,
;  so BB_HgtHi is highest grid layer considered to be within the BB
   BB_HgtHi = (BB_Hgt[idxbb]-500)/1500
   BB_HgtLo = BB_HgtLo < 12
   BB_HgtHi = BB_HgtHi < 12
endif else begin
   print, 'No valid Bright Band values in grid!  Skipping case.'
   goto, nextFile
endelse

; Set a distance array to one of three values: 0 for dist<=50km,
; 1 for 50km<dist<=100km, 2 for dist > 100km
distcat = indgen(75,75)
distcat[*,*] = 1
distcat[idxnear] = 0
distcat[idxfar] = 2

; Pare down the set of 3D gridpoints to those where each of the
; reflectivities is non-missing
idxneg = where(dbzcor eq -9999.0, countnoz)
if (countnoz gt 0) then dbzcor[idxneg] = 0.0
if (countnoz gt 0) then dbznex[idxneg] = 0.0
;if (countnoz gt 0) then distcat[idxneg] = -1
if (countnoz gt 0 and haveREO eq 1) then dbznexREO[idxneg] = 0.0
idxneg = where(dbzcor eq -100.0, countbelowmin)
if (countbelowmin gt 0) then dbzcor[idxneg] = 0.0
if (countbelowmin gt 0) then dbznex[idxneg] = 0.0
if (countbelowmin gt 0 and haveREO eq 1) then dbznexREO[idxneg] = 0.0
idxneg = where(dbznex lt 0.0, countnoz)
if (countnoz gt 0) then dbznex[idxneg] = 0.0
if (countnoz gt 0) then dbzcor[idxneg] = 0.0
if (countnoz gt 0 and haveREO eq 1) then dbznexREO[idxneg] = 0.0
if ( haveREO eq 1) then begin
   idxneg = where(dbznexREO lt 0.0, countnoz)
   if (countnoz gt 0) then dbznex[idxneg] = 0.0
   if (countnoz gt 0) then dbzcor[idxneg] = 0.0
   if (countnoz gt 0) then dbznexREO[idxneg] = 0.0
endif

; Compute a mean dBZ difference at each level
levels_with_data = 0
for lev2get = 0, 12 do begin
   thishgt = (lev2get+1)*1.5
   dbzcor2diff = dbzcor[*,*,lev2get]
   dbznex2diff = dbznex[*,*,lev2get]
   if ( haveREO eq 1) then dbznexREO2diff = dbznexREO[*,*,lev2get]
   idxpos1 = where(dbzcor2diff ge 18.0, countpos1)
   if (countpos1 gt 0) then begin
      dbzpr1 = dbzcor2diff[idxpos1]
      dbznx1 = dbznex2diff[idxpos1]
      bb1Hi = BB_HgtHi[idxpos1]
      bb1Lo = BB_HgtLo[idxpos1]
      rntyp1 = rainTypeMap[idxpos1]
      distcat1 = distcat[idxpos1]
      idxpos2 = where(dbznx1 gt 18.0, countpos2)
      if (countpos2 gt 0) then begin
         levels_with_data = levels_with_data + 1
         dbzpr2 = dbzpr1[idxpos2]
         dbznx2 = dbznx1[idxpos2]
        ; Do stratified differences: Total, and 
        ; above/below/within BB, Convective and Stratiform
         bb2Hi = bb1Hi[idxpos2]
         bb2Lo = bb1Lo[idxpos2]
         rntyp2 = rntyp1[idxpos2]
         distcat2 = distcat1[idxpos2]
         this_statsbydist = {stats21ways}
         stratify_diffs21dist, dbzpr2, dbznx2, rntyp2, bb2Lo, bb2Hi, distcat2, $
                               lev2get, this_statsbydist
      endif

      if ( haveREO eq 1) then begin
         dbznxreo = dbznexREO2diff[idxpos1]
	 idxpos3 = where(dbznxreo gt 18.0, countpos3)
	 if (countpos3 gt 0) then begin
            dbzpr3 = dbzpr1[idxpos3]
            dbznx3 = dbznxreo[idxpos3]
           ; Do above/below/within BB, Convective and Stratiform
            bb3Hi = bb1Hi[idxpos3]
            bb3Lo = bb1Lo[idxpos3]
            rntyp3 = rntyp1[idxpos3]
            distcat3 = distcat1[idxpos3]
            this_statsbydistREO = {stats21ways}
            stratify_diffs21dist, dbzpr3, dbznx3, rntyp3, bb3Lo, bb3Hi, $
                                  distcat3, lev2get, this_statsbydistREO
	 endif
      endif

;     Write Delimited Output for database, separate records for 2A55 and REO:
      printf_stat_struct21dist, this_statsbydist, '2A55', siteID, orbit, $
                                lev2get, DBunit

      if ( haveREO eq 1) then begin
         printf_stat_struct21dist, this_statsbydistREO, 'REOR', siteID, orbit, $
                                   lev2get, DBunit
      endif
   endif
endfor
print, ''
print, 'Time Difference PR-GV: ', event_time-event_time2
print, ''
print, '================================================'
print, ''

nextFile:
endfor
endif

print, 'Done!'
errorExit:

FREE_LUN, DBunit
end

@stratify_diffs21dist.pro
@printf_stat_struct21dist.pro
