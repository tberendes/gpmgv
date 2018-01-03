;+
; Copyright © 2008, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; stratified_by_angle_stats_to_dbfile.pro   Morris/SAIC/GPM_GV      Nov 2007
;
; DESCRIPTION:
; Computes PR-GV reflectivity mean difference and standard deviation for 3
; categories of PR beam incidence angle:
;  - rays within +/- 8 rays from nadir
;  - rays within 9-16 rays from nadir
;  - rays >16 rays from nadir
;
; Results are stratified by permutation of height level (1.5-19.5 km), rain
; type (convective, stratiform), grid box proximity relative to bright band
; (above, within, below), incidence angle category, orbit, and GV site ID.
;
; Mean reflectivity differences are computed and output to a delimited ascii
; text file in a format compatible with loading to a PostGRESQL database table.
;
; Restrict the dataset to points within 100km of the GV radar, and where both
; PR and GV dBZ are 18 dBZ or greater.  Do stats separately for 2A55 and REORDER
; GV sources.
;
; Inputs are the previously-gridded PR and GV (2A-55 and REORDER) data in
; individual netCDF grid files, 75x75 points in the horizontal, with 13 vertical
; levels for the 3D grid fields.
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-

pro stratified_by_angle_stats_to_dbfile

dbfile = '/data/tmp/StatsByAngleToDB.unl'
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
statsbyangle = { stats21ways, $
              fromnadir_le_8:    {stats7ways}, $
              fromnadir_9_16:     {stats7ways}, $
              fromnadir_gt_16:   {stats7ways}, $
              pts_le_8:  0L, $
              pts_9_16:   0L, $
              pts_gt_16: 0L  $
             }

pathpr = '/data/netcdf/PR/PRgrids*K*'
pathgv = '/data/netcdf/NEXRAD/GVgrids'
pathgv2 = '/data/netcdf/NEXRAD_REO/allYMD/GVgridsREO'

; Build a list of PR netCDF files matching 'pathpr' pattern
prfiles = file_search(pathpr,COUNT=nf)
if nf gt 0 then begin

; Compute a radial distance array of 2-D netCDF grid dimensions
xdist = findgen(75,75)
xdist = ((xdist mod 75.) - 37.) * 4.
ydist = TRANSPOSE(xdist)
dist = SQRT(xdist*xdist + ydist*ydist)
idxnear=where(dist le 100.)    ; 2-D indices of gridpoints within 100 km of site

;loop over the list of PR netCDF files
for fnum = 0, nf-1 do begin
;for fnum = 0, 0 do begin       ;do only one file, for testing
haveREO = 0
ncfilepr = prfiles(fnum)
;build matching 2A-55 and REORDER based GV netCDF filenames
bname = file_basename( ncfilepr )
prlen = strlen( bname )
gvpost = strmid( bname, 7, prlen)
ncfilegv = pathgv + gvpost
ncfilegv2 = pathgv2 + gvpost

; extract orbit number from the PR file basename
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
     NCDF_VARGET, ncid1, 'rayIndex', rayIndexMap
     NCDF_VARGET, ncid1, 'rainType', rainTypeMap

;    query 2A-55 netCDF file variables
        NCDF_VARGET, ncid2, 'threeDreflect', dbznex
        NCDF_VARGET, ncid2, 'beginTimeOfVolumeScan', event_time2

;    query REORDER netCDF file variables, if REO available
     cpstatusREO = uncomp_file( ncfilegv2, ncfilereo )
     if (cpstatusREO eq 'OK') then begin
        haveREO = 1                          ; set REO existence flag
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

;    Convert BB height to level index 0-12, or -1 if missing/undefined
     idxbbmiss = where(BB_Hgt le 0, countbbmiss)
     if (countbbmiss gt 0) then BB_Hgt[idxbbmiss] = -1
     idxbb = where(BB_Hgt gt 0, countbb)
     if (countbb gt 0) then begin
;       Level below BB affected if BB_Hgt is 1000m or less above layer center,
;       so BB_HgtLo is lowest grid layer considered to be within the BB
        BB_HgtLo = (BB_Hgt[idxbb]-1001)/1500
;       Level above BB affected if BB_Hgt is 1000m or less below layer center,
;       so BB_HgtHi is highest grid layer considered to be within the BB
        BB_HgtHi = (BB_Hgt[idxbb]-500)/1500
        BB_HgtLo = BB_HgtLo < 12
        BB_HgtHi = BB_HgtHi < 12
     endif else begin
        print, 'No valid Bright Band values in grid!  Skipping case.'
        goto, nextFile
     endelse

     NCDF_CLOSE, ncid1
     command3 = "rm " + ncfile1
     spawn, command3

     NCDF_CLOSE, ncid2
     command4 = "rm " + ncfile2
     spawn, command4
  endif else begin
     print, 'Cannot find GV netCDF file: ', ncfilegv
     print, cpstatus2
     goto, nextFile
  endelse
endif else begin
  print, 'Cannot copy/unzip PR netCDF file: ', ncfilepr
  print, cpstatus
  command3 = "rm -v " + ncfile1
  spawn, command3
  goto, errorExit
endelse

;print, rayindexmap[*,37]
; Set angle array to one of three values: 0 for angle index within 8 of nadir,
; 1 for 8<angle<=16 from nadir, 2 for angle index > 16 from nadir.  Ray index
; runs from 0 to 48, with nadir at index=24.  Gridpoints with ray index = -1 are
; beyond the edge of the PR swath (i.e., PR data are missing)
ridxmiss = where(rayIndexMap lt 0, countmiss)
rayIndexMap = ABS(rayIndexMap - 24)
ridxnr = where(rayIndexMap lt 9, countnr)
ridxfar = where(rayIndexMap gt 16, countfar)
rayIndexMap[*,*] = 1
if (countfar gt 0) then rayIndexMap[ridxfar] = 2
if (countnr gt 0) then rayIndexMap[ridxnr] = 0
if (countmiss gt 0) then rayIndexMap[ridxmiss] = -1
;print, rayindexmap[*,37]

; Identify 3D gridpoints where PR and GV reflectivities are all non-missing by
; setting all other points' values to 0.0
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

; Pare down the 2-D fields to points within 100km of GV site

BB_HgtHiNr = BB_HgtHi[idxnear]
BB_HgtLoNr = BB_HgtLo[idxnear]
rainTypeMapNr = rainTypeMap[idxnear]
anglecatNr = rayIndexMap[idxnear]

; Compute a mean dBZ difference at each level
levels_with_data = 0
for lev2get = 0, 12 do begin
   thishgt = (lev2get+1)*1.5
   dbzcor2diff_lev = dbzcor[*,*,lev2get]
   dbzcor2diff = dbzcor2diff_lev[idxnear]  ; within 100 km of GV site
   dbznex2diff_lev = dbznex[*,*,lev2get]
   dbznex2diff = dbznex2diff_lev[idxnear]  ; within 100 km of GV site
   if ( haveREO eq 1) then begin
       dbznexREO2diff_lev = dbznexREO[*,*,lev2get]
       dbznexREO2diff = dbznexREO2diff_lev[idxnear]  ; within 100 km of GV site
   endif
   ; take only points where PR and GV dBZs are above PR detection thresholds
   idxpos1 = where(dbzcor2diff ge 18.0, countpos1)
   if (countpos1 gt 0) then begin
      dbzpr1 = dbzcor2diff[idxpos1]
      dbznx1 = dbznex2diff[idxpos1]
      bb1Hi = BB_HgtHiNr[idxpos1]
      bb1Lo = BB_HgtLoNr[idxpos1]
      rntyp1 = rainTypeMapNr[idxpos1]
      anglecat1 = anglecatNr[idxpos1]
      idxpos2 = where(dbznx1 gt 18.0, countpos2)
      if (countpos2 gt 0) then begin
         levels_with_data = levels_with_data + 1
         dbzpr2 = dbzpr1[idxpos2]
         dbznx2 = dbznx1[idxpos2]
         bb2Hi = bb1Hi[idxpos2]
         bb2Lo = bb1Lo[idxpos2]
         rntyp2 = rntyp1[idxpos2]
         anglecat2 = anglecat1[idxpos2]
        ; Make a copy of the initialized struct for passing to subprocedure
         this_statsbyangle = {stats21ways}
        ; Do stratified differences: Total, above/below/within BB,
        ; Convective and Stratiform, by angle category
         stratify_diffs21angle, dbzpr2, dbznx2, rntyp2, bb2Lo, bb2Hi, $
                                anglecat2, lev2get, this_statsbyangle
;print, allstats
      endif

     ; do separate PR/REORDER-based comparisons, if REO file available
      if ( haveREO eq 1) then begin
         dbznxreo = dbznexREO2diff[idxpos1]
	 idxpos3 = where(dbznxreo gt 18.0, countpos3)
	 if (countpos3 gt 0) then begin
            dbzpr3 = dbzpr1[idxpos3]
            dbznx3 = dbznxreo[idxpos3]
            bb3Hi = bb1Hi[idxpos3]
            bb3Lo = bb1Lo[idxpos3]
            rntyp3 = rntyp1[idxpos3]
            anglecat3 = anglecat1[idxpos3]
            this_statsbyangleREO = {stats21ways}
            stratify_diffs21angle, dbzpr3, dbznx3, rntyp3, bb3Lo, bb3Hi, $
                                   anglecat3, lev2get, this_statsbyangleREO
	 endif
      endif

;     Write Delimited Output for database, separate records for 2A55 and REO:
      printf_stat_struct21angle, this_statsbyangle, '2A55', siteID, orbit, $
                                 lev2get, DBunit

      if ( haveREO eq 1) then begin
         printf_stat_struct21angle, this_statsbyangleREO, 'REOR', siteID, $
	                            orbit, lev2get, DBunit
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

@stratify_diffs21angle.pro
@printf_stat_struct21angle.pro
