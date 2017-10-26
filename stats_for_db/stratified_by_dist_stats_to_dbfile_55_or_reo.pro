;===============================================================================
;+
; Copyright © 2008, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; stratified_by_dist_stats_to_dbfile_55_or_reo.pro   Morris/SAIC/GPM_GV      October 2007
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
; /data/tmp/StatsByDistToDBnew100.unl  OUTPUT: Formatted ASCII text file holding
;                                              the computed, stratified PR-GV
;                                              reflectivity statistics and its
;                                              identifying metadata fields.
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
; gv_orbit_match()
;
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;===============================================================================

pro stratified_by_dist_stats_to_dbfile_55_or_reo

; "include" file for PR netCDF grid structs, now that we call read_pr_netcdf()
@grid_nc_structs.inc

mygridstruc={grid_def_meta}
mysitestruc={gv_site_meta}

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
pathgvREO = '/data/netcdf/NEXRAD_REO/allYMD/GVgridsREO'


prfiles = file_search(pathpr,COUNT=nf)
if nf gt 0 then begin

for fnum = 0, nf-1 do begin

have55 = 0  &  have55match = 0
haveREO = 0  &  haveREOmatch = 0
ncfilepr = prfiles(fnum)
bname = file_basename( ncfilepr )
prlen = strlen( bname )
gvpost = strmid( bname, 7, prlen)
ncfilegv = pathgv + gvpost
ncfilegvREO = pathgvREO + gvpost
print, "PR netCDF file: ", ncfilepr

parsed = strsplit(bname, '.', /EXTRACT)
orbit = parsed[3]

; Check whether one or the other of the GV files can be found for the
; orbit number indicated in the PR file name.  Now that we are sometimes
; using full-orbit PR products, the YYMMDD datestamp in the PR and GV file
; names may differ for a given orbit!

gvstatus = gv_orbit_match( ncfilepr, ncfilegv )
gvREOstatus = gv_orbit_match( ncfilepr, ncfilegvREO )

if ( (gvstatus NE 'OK') && (gvREOstatus NE 'OK') ) then begin
   print, ''
   print, "Skipping case for file ", bname, ", no matching GV files found!"
   GOTO, nextFile
endif

; Get uncompressed copy of the found files and read data fields

cpstatus = ''
cpstatus = uncomp_file( ncfilepr, ncfile1 )
if(cpstatus eq 'OK') then begin
; query 2A55-based netCDF file variables, if 2A55 available
  cpstatus2 = ''
  if(gvstatus EQ 'OK') then cpstatus2 = uncomp_file( ncfilegv, ncfile2 )
  if(cpstatus2 eq 'OK') then begin
     print, "GV netCDF file: ", ncfilegv
     status = 1       ; initialize to FAILED
     event_time2=0.0D
     mygrid=mygridstruc
     mysite=mysitestruc
     dbznex=fltarr(2)
     status = read_gv_netcdf( ncfile2, dtime=event_time2, gridmeta=mygrid, $
         sitemeta=mysite, dbz3d=dbznex )
     IF (status NE 0) THEN BEGIN
       print, "ERROR in reading GV netCDF file: ", ncfile2
       have55 = 0
     ENDIF ELSE BEGIN
       have55 = 1
     ENDELSE
     command = "rm  " + ncfile2
     spawn, command
  endif else begin
     print, 'Cannot find GV netCDF file: ', ncfilegv
     print, cpstatus2
  endelse
; query REORDER netCDF file variables, if REO available
  cpstatusREO = ''
  if(gvREOstatus EQ 'OK') then cpstatusREO = uncomp_file( ncfilegvREO, ncfile3 )
  if (cpstatusREO eq 'OK') then begin
     print, "GV-REO netCDF file: ", ncfilegvREO
     status = 1       ; initialize to FAILED
     event_timeREO=0.0D
     mygrid=mygridstruc
     mysite=mysitestruc
     dbznexREO=fltarr(2)
     status = read_gv_reo_netcdf( ncfile3, dtime=event_timeREO, gridmeta=mygrid, $
         sitemeta=mysite, dbz3d=dbznexREO )
     IF (status NE 0) THEN BEGIN
       print, "ERROR in reading GV REO netCDF file: ", ncfile3
       haveREO = 0
     ENDIF ELSE BEGIN
       haveREO = 1                       ; initialize flag
     ENDELSE
     command = "rm  " + ncfile3
     spawn, command
  endif else begin
     print, 'Cannot find GVREO netCDF file: ', ncfilegvREO
     print, cpstatusREO
  endelse
  if ( (have55 eq 1) || (haveREO eq 1) ) then begin
     status = 1       ; initialize to FAILED
     event_time=0.0D
     mygrid=mygridstruc
     mysite=mysitestruc
     dbzcor=fltarr(2)
     landoceanMap=intarr(2)
     BB_Hgt=intarr(2)
     rainTypeMap=intarr(2)
     status = read_pr_netcdf( ncfile1, dtime=event_time, gridmeta=mygrid, $
         sitemeta=mysite, dbz3d=dbzcor, sfctype2d_int=landoceanMap, $
         bbhgt2d_int=BB_Hgt, raintype2d_int=rainTypeMap )
     IF (status NE 0) THEN BEGIN
       print, "ERROR in reading PR netCDF file: ", ncfile1
       GOTO, readErrorPR
     ENDIF ELSE BEGIN
       command = "rm  " + ncfile1
       spawn, command
     ENDELSE
  endif else begin                     ; no GV files/data
    command3 = "rm  " + ncfile1
    spawn, command3
    goto, nextFile ;errorExit
  endelse
endif else begin                       ; no or bad PR file
  print, 'Cannot copy/unzip PR netCDF file: ', ncfilepr
  print, cpstatus
  readErrorPR:
  command3 = "rm  " + ncfile1
  spawn, command3
  goto, errorExit
endelse

; Process the PR/GV grid metadata

siteID = mysite.site_id
siteLat = mysite.site_lat
siteLong = mysite.site_lon
NX = mygrid.nx
NY = mygrid.ny
gridspacex = mygrid.dx
gridspacey = mygrid.dy
print, siteID, siteLat, siteLong, event_time ;, event_time2

; Compute a radial distance array of 2-D netCDF grid dimensions
xdist = findgen(NX,NY)
xdist = ((xdist mod FLOAT(NX)) - FLOAT(NX/2)) * gridspacex
ydist = findgen(NY,NX)
ydist = ((ydist mod FLOAT(NY)) - FLOAT(NY/2)) * gridspacey
ydist = TRANSPOSE(ydist)
dist  = SQRT(xdist*xdist + ydist*ydist)/1000.  ; m to km
idxnear=where(dist le 50.)
idxfar= where(dist gt 100.)


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
distcat = indgen(NX,NY)
distcat[*,*] = 1
distcat[idxnear] = 0
distcat[idxfar] = 2

; Set grid point values in all reflectivity arrays values to 0.0 where any of
; the sources is missing, has no data, or was below min dBZ used in regriddding.

idxneg = where(dbzcor eq -9999.0, countnoz)
if (countnoz gt 0) then begin
   dbzcor[idxneg] = 0.0
   if (have55 eq 1) then dbznex[idxneg] = 0.0
   if (haveREO eq 1) then dbznexREO[idxneg] = 0.0
endif

idxneg = where(dbzcor eq -100.0, countbelowmin)
if (countbelowmin gt 0) then begin
   dbzcor[idxneg] = 0.0
   if (have55 eq 1) then dbznex[idxneg] = 0.0
   if (haveREO eq 1) then dbznexREO[idxneg] = 0.0
endif

; treat 2A55 and REORDER as separate cases
if ( have55 eq 1) then begin
   dbzcor_for55 = dbzcor
   idxneg = where(dbznex lt 0.0, countnoz)
   if (countnoz gt 0) then begin
      dbznex[idxneg] = 0.0
      dbzcor_for55[idxneg] = 0.0
   endif
endif

if ( haveREO eq 1) then begin
   dbzcor_forREO = dbzcor
   idxneg = where(dbznexREO lt 0.0, countnoz)
   if (countnoz gt 0) then begin
      dbzcor_forREO[idxneg] = 0.0
      dbznexREO[idxneg] = 0.0
   endif
endif

; Compute a mean dBZ difference at each level
levels_with_data55 = 0
levels_with_dataREO = 0
for lev2get = 0, 12 do begin
   thishgt = (lev2get+1)*1.5
   
   if (have55 eq 1) then begin
      dbzcor2diff = dbzcor_for55[*,*,lev2get]
      dbznex2diff = dbznex[*,*,lev2get]
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
            levels_with_data55 = levels_with_data55 + 1
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
;           Write Delimited Output for database, separate records for 2A55 and REO:
            printf_stat_struct21dist, this_statsbydist, '2A55', siteID, orbit, $
                                      lev2get, DBunit
         endif
      endif
   endif

   if ( haveREO eq 1) then begin
      dbzcor2diff = dbzcor_forREO[*,*,lev2get]
      dbznexREO2diff = dbznexREO[*,*,lev2get]
      idxpos1 = where(dbzcor2diff ge 18.0, countpos1)
      if (countpos1 gt 0) then begin
         dbzpr1 = dbzcor2diff[idxpos1]
         dbznxreo1 = dbznexREO2diff[idxpos1]
         bb1Hi = BB_HgtHi[idxpos1]
         bb1Lo = BB_HgtLo[idxpos1]
         rntyp1 = rainTypeMap[idxpos1]
         distcat1 = distcat[idxpos1]
         idxpos3 = where(dbznxreo1 gt 18.0, countpos3)
	 if (countpos3 gt 0) then begin
            levels_with_dataREO = levels_with_dataREO + 1
            dbzpr3 = dbzpr1[idxpos3]
            dbznx3 = dbznxreo1[idxpos3]
           ; Do above/below/within BB, Convective and Stratiform
            bb3Hi = bb1Hi[idxpos3]
            bb3Lo = bb1Lo[idxpos3]
            rntyp3 = rntyp1[idxpos3]
            distcat3 = distcat1[idxpos3]
            this_statsbydistREO = {stats21ways}
            stratify_diffs21dist, dbzpr3, dbznx3, rntyp3, bb3Lo, bb3Hi, $
                                  distcat3, lev2get, this_statsbydistREO
;           Write Delimited Output for database, separate records for 2A55 and REO:
            printf_stat_struct21dist, this_statsbydistREO, 'REOR', siteID, orbit, $
                                      lev2get, DBunit
	 endif
      endif
   endif

endfor

print, ''
if ( have55 eq 1) then begin
   print, 'Time Difference PR-GV: ', event_time-event_time2
endif else begin
   print, 'Time Difference PR-GV: ', event_time-event_timeREO
endelse
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
