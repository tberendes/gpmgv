;+
; Copyright © 2008, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; dbz_stats_with_image_loop.pro
;
; Produces PDF plot of PR and GV reflectivity at a selected level,
; as specified in an input control file.  Also produces a plot of
; area-average layer mean reflectivity vs. height for PR and GV, and
; displays PR and GV reflectivity images for all data levels in a
; separate image animation window.
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-

pro dbz_stats_with_image_loop

; "include" file for PR data constants
@pr_params.inc

; "include" file for PR/GV netCDF grid structs, for calling read_XX_netcdf
@grid_nc_structs.inc

;##################################

allowedheight = [1.5, 3.0, 4.5, 6.0, 7.5, 9.0, 10.5, 12.0, 13.5, 15.0, 16.5, 18.0, 19.5]
bs = 1.
minz4hist = 15.
maxz4hist = 55.
dbzcut = 18.
rangecut = 100.

the_struc = { diffsset, $
              meandiff: -99.999, meandist: -99.999, fullcount: 0L,  $
              maxpr: -99.999, maxgv: -99.999, $
              meandiffc: -99.999, countc: 0L, $
              meandiffs: -99.999, counts: 0L, $
              AvgDifByHist: -99.999 $
            }

mygridstruc={grid_def_meta}
mysitestruc={gv_site_meta}

;##################################
; hard-coded values used if skipping over control file

pathpr = '/data/netcdf/PR/PRgrids*KAMX*.06*'
pathgv = '/data/netcdf/NEXRAD/GVgrids'
pathgv2 = '/data/netcdf/NEXRAD_REO/allYMD/GVgridsREO'
height = 6.0
;##################################

; Open and read the control file specifying the local paths to the PR,
; GV (2A-55 based) and GVREO (REORDER-based) netCDF grid files.  The
; PR entry controls which NEXRAD site(s) is/are included in the sequence.


cd, CURRENT=cur_dir
;goto, skipctl          ;Uncommented only if NOT reading control file
filters = ['*.ctl']
ctlfile = dialog_pickfile(FILTER=filters, TITLE='Select control file to read', PATH='~')
;ctlfile = '~/statsDARW.ctl'
;ctlfile = '~/stats.ctl'
OPENR, ctlunit, ctlfile, /GET_LUN, ERROR = err
if ( err ne 0 ) then message, 'Unable to open control file: ' + ctlfile

hgtstr = ''
pathpr = ''
pathgv = ''
pathgv2 = ''
readf, ctlunit, hgtstr
readf, ctlunit, pathpr
readf, ctlunit, pathgv
readf, ctlunit, pathgv2
print, ''
print, 'Histogram plot height level: ', hgtstr + ' km'
print, 'Path/sitepattern to PR netCDF files: ', pathpr
print, 'Path/pattern to GV netCDF files: ', pathgv
print, 'Path/pattern to GV-REO netCDF files: ', pathgv2

height = float(hgtstr)

skipctl:

inhgtidx = WHERE(allowedheight eq height, counthgt)
if (counthgt ne 1) then begin
   print, ''
   print, '******************************************************************'
   print, ''
   print, 'Height value "', hgtstr, '" in control file not one of the grid height levels:'
   print, allowedheight, FORMAT='(12(f0.1, ", "),f0.1)'
   print, ''
   message, 'Fix height entry in control file and try again!'
endif
ourlev = FIX((height-1.5)/1.5)

print, 'Current working directory = ', cur_dir
print, ''
dir2pr = FILE_DIRNAME(pathpr)
if (dir2pr eq cur_dir) then $
  message, '.sav file must be in different directory than PR netCDF (.nc) data files!'
dir2gv = FILE_DIRNAME(pathgv)
if (dir2gv eq cur_dir) then $
  message, '.sav file must be in different directory than GV netCDF (.nc) data files!'
dir2gv2 = FILE_DIRNAME(pathpr)
if (dir2gv2 eq cur_dir) then $
  message, '.sav file must be in different directory than GV-REO netCDF (.nc) data files!'

prfiles = file_search(pathpr,COUNT=nf)

if nf eq 0 then begin
print, 'No PR netCDF files matching file pattern: ', pathpr
endif else begin

;###############################################################################
for fnum = 0, nf-1 do begin

have55 = 0  &  have55match = 0
haveREO = 0  &  haveREOmatch = 0
ncfilepr = prfiles(fnum)
bname = file_basename( ncfilepr )
prlen = strlen( bname )
gvpost = strmid( bname, 7, prlen)
ncfilegv = pathgv + gvpost
ncfilegvREO = pathgv2 + gvpost
print, "PR netCDF file: ", ncfilepr

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
     ENDIF
     have55 = 1
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
     ENDIF
     haveREO = 1                       ; initialize flag
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

; Process the PR/GV grid data

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

; MAKE THIS A FUNCTION !!!
;    Convert BB height to level index 0-12, or -1 if missing/undefined
     BB_HgtLo = -1
     BB_HgtHi = -1
     idxbbmiss = where(BB_Hgt le 0, countbbmiss)
     if (countbbmiss gt 0) then BB_Hgt[idxbbmiss] = -1
     idxbb = where(BB_Hgt gt 0, countbb)
     if (countbb gt 0) then begin
;       Level below BB is affected if BB_Hgt is 1000m or less above layer center,
;       so BB_HgtLo is lowest grid layer considered to be within the BB
        BB_mean = fix(mean(BB_Hgt[idxbb]))
        BB_mean_km = BB_mean/1000.
        BB_HgtLo = (BB_mean-1001)/1500
;       Level above BB is affected if BB_Hgt is 1000m or less below layer center,
;       so BB_HgtHi is highest grid layer considered to be within the BB
        BB_HgtHi = (BB_mean-500)/1500
        BB_HgtLo = BB_HgtLo < 12
        BB_HgtHi = BB_HgtHi < 12
;print, 'bblo, bbhi = ', BB_HgtLo, BB_HgtHi
     endif else begin
        print, 'No valid Bright Band values in grid!  Skipping case.'
        goto, nextFile
     endelse

; MAKE THIS A FUNCTION !!!
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

if ( have55 eq 1) then begin
   idxneg = where(dbznex lt 0.0, countnoz)
   if (countnoz gt 0) then begin
      dbznex[idxneg] = 0.0
      dbzcor[idxneg] = 0.0
      if (haveREO eq 1) then dbznexREO[idxneg] = 0.0
   endif
endif

if ( haveREO eq 1) then begin
   idxneg = where(dbznexREO lt 0.0, countnoz)
   if (countnoz gt 0) then begin
      if (have55 eq 1) then dbznex[idxneg] = 0.0
      dbzcor[idxneg] = 0.0
      dbznexREO[idxneg] = 0.0
   endif
endif

; Compute time diff between PR overpass and ground radar volume scan time

if (have55 eq 1) then begin
   tdiffstr = string(fix(event_time-event_time2), FORMAT='(i0)')
endif else begin
   if (haveREO eq 1) then begin
      tdiffstr = string(fix(event_time-event_timeREO), FORMAT='(i0)')
   endif else begin
      tdiffstr = 'UNKNOWN'
   endelse
endelse
tdiffline = 'Time Difference (sec): ' + tdiffstr

device, decomposed = 0
LOADCT, 33

; Print the conditional heading line for the PR-GV difference statistics table
print, ''
print, 'DISPLAYED LEVEL: ', (ourlev+1)*1.5
print, ''
print, '         *******  Mean Reflectivity Differences  ******

if (have55 eq 1 && haveREO eq 1) then begin

   print, ' Level | PR-2A55   AvgDist   PR MaxZ   GV MaxZ   NumPts |  PR-REO   AvgDist   PR MaxZ  REO MaxZ   NumPts'
   print, ' -----   -------   -------   -------   -------   ------    ------   -------   -------  --------   ------'

endif else begin

   if (have55 eq 1) then begin
      print, ' Level | PR-2A55   AvgDist   PR MaxZ   GV MaxZ   NumPts '
      print, ' -----   -------   -------   -------   -------   ------ '
   endif else begin
      print, ' Level |  PR-REO   AvgDist   PR MaxZ  REO MaxZ   NumPts '
      print, ' -----    ------   -------   -------   -------   ------ '
   endelse

endelse

mnprarr = fltarr(13)
mngvarr = fltarr(13)
mnprarrREO = fltarr(13)
mngvarrREO = fltarr(13)
levsdata = 0
levsdataREO = 0
dbzcut = 18.0
rangecut = 100.0
prz4hist = fltarr(NX*NY)  ; PR dBZ values used for point-to-point mean diffs
gvz4hist = fltarr(NX*NY)  ; GV dBZ values used for point-to-point mean diffs

;# # # # # # # # # # # # # # # # # # # # # # # # #
; Compute a mean dBZ difference at each level

for lev2get = 0, 12 do begin
   thishgt = (lev2get+1)*1.5
   flag = ''
   prz4hist[*] = 0.0
   gvz4hist[*] = 0.0
   have55match = 0 & haveREOmatch = 0  ; = 0 if no PR-GV hits, 1 otherwise
   if (lev2get eq BB_HgtLo OR lev2get eq BB_HgtHi) then flag = ' @ BB'

  ; Compute the difference statistics at this level for each GV source
   if ( have55 eq 1) then begin
      diffstruc = the_struc
      get_pr_vs_gv_meandiffs, dbzcor, dbznex, rainTypeMap, $
                              dist, lev2get, dbzcut, rangecut, bs, $
                              mnprarr, mngvarr, have55match, diffstruc, $
                              prz4hist, gvz4hist
      if(have55match eq 1) then begin
         levsdata = levsdata + 1
        ; format level's stats for table output
         stats55 = STRING(diffstruc.meandiff, diffstruc.meandist, $
                          diffstruc.maxpr, diffstruc.maxgv, diffstruc.fullcount, $
                          FORMAT='(" ",4("   ",f7.3),"    ",i4)' )
         if ( thishgt eq height ) then begin
           ; extract/format level's stats for graphic plots output
            dbzpr2 = prz4hist[0:diffstruc.fullcount-1]
            dbzgv2 = gvz4hist[0:diffstruc.fullcount-1]
            mndifhstr = string(diffstruc.AvgDifByHist, FORMAT='(f0.3)')
            mndifstr = string(diffstruc.meandiff, diffstruc.fullcount, FORMAT='(f0.3," (",i0,")")')
            mndifstrc = string(diffstruc.meandiffc, diffstruc.countc, FORMAT='(f0.3," (",i0,")")')
            mndifstrs = string(diffstruc.meandiffs, diffstruc.counts, FORMAT='(f0.3," (",i0,")")')
            prz4hist[*] = 0.0
            gvz4hist[*] = 0.0
         endif
      endif
   endif
   if ( haveREO eq 1) then begin
      diffstruc = the_struc
      get_pr_vs_gv_meandiffs, dbzcor, dbznexREO,rainTypeMap,  $
                              dist, lev2get, dbzcut, rangecut, bs, $
                              mnprarrREO, mngvarrREO, haveREOmatch, diffstruc, $
                              prz4hist, gvz4hist
      if( haveREOmatch eq 1) then begin
         levsdataREO = levsdataREO + 1
        ; format level's stats for table output
         statsREO = STRING(diffstruc.meandiff, diffstruc.meandist, $
                           diffstruc.maxpr, diffstruc.maxgv, diffstruc.fullcount, $
                           FORMAT='(" ",4("   ",f7.3),"    ",i4)' )
         if ( thishgt eq height ) then begin
           ; extract/format level's stats for graphic plots output
            dbzpr3 = prz4hist[0:diffstruc.fullcount-1]
            dbzgv3 = gvz4hist[0:diffstruc.fullcount-1]
            mndifhstrREO = string(diffstruc.AvgDifByHist, FORMAT='(f0.3)')
            mndifstrREO = string(diffstruc.meandiff, diffstruc.fullcount, FORMAT='(f0.3," (",i0,")")')
            mndifstrcREO = string(diffstruc.meandiffc, diffstruc.countc, FORMAT='(f0.3," (",i0,")")')
            mndifstrsREO = string(diffstruc.meandiffs, diffstruc.counts, FORMAT='(f0.3," (",i0,")")')
         endif
      endif
   endif

  ; Plot the PDF graph for preselected level
   if ( thishgt eq height ) then begin
      hgtstr = string(thishgt, FORMAT='(f0.1)')
      hgtline = 'Height = ' + hgtstr + ' km'
      if ( have55match eq 0 && haveREOmatch eq 0 ) then begin
         print, ""
         print, "No valid data found for ", hgtline, ", skipping reflectivity histogram.
         Window, xsize=500, ysize=350
         !P.Multi=[0,1,1,0,0]
      endif else begin

       ; Build the PDF plots for 'thishgt' level
         Window, xsize=500, ysize=700
         !P.Multi=[0,1,2,0,0]

         if ( have55match eq 1) then begin
;            prhist = histogram(dbzpr2, min=minz4hist, max=maxz4hist, binsize = bs, $
            prhist = histogram(dbzpr2, min=dbzcut, max=maxz4hist, binsize = bs, $
                               locations = prhiststart)
;            nxhist = histogram(dbzgv2, min=minz4hist, max=maxz4hist, binsize = bs)
            nxhist = histogram(dbzgv2, min=dbzcut, max=maxz4hist, binsize = bs)
            plot, prhiststart, prhist, COLOR = 100, $
                  XTITLE=hgtstr+' km Reflectivity, dBZ', $
                  YTITLE='Number of Gridpoints', $
                  YRANGE=[0,FIX((MAX(prhist)>MAX(nxhist))*1.1)], $
                  TITLE = strmid( bname, 8, prlen-14), CHARSIZE=1
            xyouts, 0.19, 0.95, 'PR', COLOR = 100, /NORMAL, CHARSIZE=1
            plots, [0.14,0.18], [0.955,0.955], COLOR = 100, /NORMAL
            xyouts, 0.6,0.925, hgtline, COLOR = 100, /NORMAL, CHARSIZE=1.5
            xyouts, 0.6,0.675, tdiffline, COLOR = 100, /NORMAL, CHARSIZE=1
            mndifline = 'PR-2A55 Bias: ' + mndifstr
            mndifhline = 'PR-2A55 Histo Bias: ' + mndifhstr
            mndiflinec = 'PR-2A55 Bias(Conv): ' + mndifstrc
            mndiflines = 'PR-2A55 Bias(Strat): ' + mndifstrs
            oplot, prhiststart, nxhist, COLOR = 200
            xyouts, 0.19, 0.925, '2A-55', COLOR = 200, /NORMAL, CHARSIZE=1
            plots, [0.14,0.18], [0.93,0.93], COLOR = 200, /NORMAL
            xyouts, 0.6,0.875, mndifline, COLOR = 100, /NORMAL, CHARSIZE=1
            xyouts, 0.6,0.85, mndifhline, COLOR = 100, /NORMAL, CHARSIZE=1
            xyouts, 0.6,0.825, mndiflinec, COLOR = 100, /NORMAL, CHARSIZE=1
            xyouts, 0.6,0.8, mndiflines, COLOR = 100, /NORMAL, CHARSIZE=1
         endif
         if ( haveREOmatch eq 1) then begin
            mndiflineREO = 'PR-REO Bias: ' + mndifstrREO
            mndifhlineREO = 'PR-REO Histo Bias: ' + mndifhstrREO
            mndiflinecREO = 'PR-REO Bias(Conv): ' + mndifstrcREO
            mndiflinesREO = 'PR-REO Bias(Strat): ' + mndifstrsREO
;            prhist = histogram(dbzpr3, min=minz4hist, max=maxz4hist, binsize = bs, $
            prhist = histogram(dbzpr3, min=dbzcut, max=maxz4hist, binsize = bs, $
                               locations = prhiststart)
;            nxhist = histogram(dbzgv3, min=minz4hist, max=maxz4hist, binsize = bs)
            nxhist = histogram(dbzgv3, min=dbzcut, max=maxz4hist, binsize = bs)
            if ( have55match eq 1) then begin
	       oplot, prhiststart, prhist, COLOR = 100, LINESTYLE=2
	    endif else begin
               plot, prhiststart, prhist, COLOR = 100, $
                     XTITLE=hgtstr+' km Reflectivity, dBZ', $
                     YTITLE='Number of Gridpoints', $
                     YRANGE=[0,FIX((MAX(prhist)>MAX(nxhist))*1.1)], $
                     TITLE = strmid( bname, 8, prlen-14), CHARSIZE=1, LINESTYLE=2
;              xyouts, 0.19, 0.95, 'PR', COLOR = 100, /NORMAL, CHARSIZE=1
;              plots, [0.14,0.18], [0.955,0.955], COLOR = 100, /NORMAL
               xyouts, 0.6,0.925, hgtline, COLOR = 100, /NORMAL, CHARSIZE=1.5
               xyouts, 0.6,0.675, tdiffline, COLOR = 100, /NORMAL, CHARSIZE=1
	    endelse
            oplot, prhiststart, nxhist, COLOR = 200, LINESTYLE=2
            xyouts, 0.19, 0.9, 'PR-REO', COLOR = 100, /NORMAL, CHARSIZE=1
            plots, [0.14,0.18], [0.905,0.905], COLOR = 100, /NORMAL, LINESTYLE=2
            xyouts, 0.19, 0.875, 'REORD', COLOR = 200, /NORMAL, CHARSIZE=1
            plots, [0.14,0.18], [0.88,0.88], COLOR = 200, /NORMAL, LINESTYLE=2
            xyouts, 0.60, 0.775, mndiflineREO, COLOR = 100, /NORMAL, CHARSIZE=1
            xyouts, 0.60, 0.75, mndifhlineREO, COLOR = 100, /NORMAL, CHARSIZE=1
            xyouts, 0.6,0.725, mndiflinecREO, COLOR = 100, /NORMAL, CHARSIZE=1
            xyouts, 0.6,0.7, mndiflinesREO, COLOR = 100, /NORMAL, CHARSIZE=1
         endif
         if (flag ne '') then xyouts, 0.6,0.65,'Bright Band Affected', $
                              COLOR = 100, /NORMAL, CHARSIZE=1
      endelse ; if ( (have55match eq 1) || (haveREOmatch eq 1) )
   endif  ; if thishgt eq height

  ; print the level's statistics to the table
   if ( (have55match eq 1) && (haveREOmatch eq 1) ) then begin
      print, (lev2get+1)*1.5, stats55, statsREO, flag, FORMAT='(" ",f4.1,a0,a0," ",a0)'
   endif else begin
      if (haveREOmatch eq 1) then print, (lev2get+1)*1.5, statsREO, flag, $
                                         FORMAT='(" ",f4.1,a0," ",a0)'
      if (have55match eq 1) then print, (lev2get+1)*1.5, stats55, flag, $
                                        FORMAT='(" ",f4.1,a0," ",a0)'
   endelse

endfor  ;lev2get loop over all grid levels
;# # # # # # # # # # # # # # # # # # # # # # # # #

print, ''

; Build the mean Z profile plot panel

levsdata = levsdata > levsdataREO
if (levsdata eq 0) then begin
   print, "No valid data levels found for reflectivity!"
   goto, nextFile
endif

h2plot = (findgen(levsdata) + 1) * 1.5
prmnz2plot = mnprarr[0:levsdata-1]
if ( have55 eq 1 ) then begin
   gvmnz2plot = mngvarr[0:levsdata-1]
   plot, prmnz2plot, h2plot, COLOR = 100, XRANGE=[15,40], YRANGE=[0,15], $
      YTICKINTERVAL=1.5, YMINOR=1, $
      XTITLE='Level Mean Reflectivity, dBZ', YTITLE='Height Level, km'
   oplot, gvmnz2plot, h2plot, COLOR = 200
endif
if ( haveREO eq 1 ) then begin
   gvmnz2plotREO = mngvarrREO[0:levsdata-1]
   if ( have55 eq 0) then begin
      prmnz2plot = mnprarrREO[0:levsdata-1]
      plot, prmnz2plot, h2plot, COLOR = 100, XRANGE=[15,40], $
            YRANGE=[0,15], YTICKINTERVAL=1.5, YMINOR=1, LINESTYLE=2, $
            XTITLE='Level Mean Reflectivity, dBZ', YTITLE='Height Level, km'
   endif
   oplot, gvmnz2plotREO, h2plot, COLOR = 200, LINESTYLE=2
endif

xvals = [15,40] & yvals = [height, height]
plots, xvals, yvals, COLOR = 100, LINESTYLE=1
xvalsleg1 = [32,34] & yvalsleg1 = 14
plots, xvalsleg1, yvalsleg1, COLOR = 100, LINESTYLE=1
XYOutS, 34.5, 13.9, 'Stats Height', COLOR = 100, CHARSIZE=1
xvalsbb = [15,40] & yvalsbb = [BB_mean_km, BB_mean_km]
plots, xvalsbb, yvalsbb, COLOR = 100, LINESTYLE=2, THICK=3
yvalsleg2 = 13
plots, xvalsleg1, yvalsleg2, COLOR = 100, LINESTYLE=2, THICK=3
XYOutS, 34.5, 12.9, 'Mean BB Hgt', COLOR = 100, CHARSIZE=1

if ( levsdata LT 2 ) then goto, skipAnim

; Build the multi-level reflectivity images animation loop

; Set up the map parameters
pi=3.14159
deglatperkm=1/111.1
deglonperkm=deglatperkm/cos(siteLat*(pi/180.))
lathi = siteLat + 150 * deglatperkm
latlo = siteLat - 150 * deglatperkm
lonhi = siteLong + 150 * deglonperkm
lonlo = siteLong - 150 * deglonperkm

; Set up for 100 km range ring burn-in to images
dist2 = dist
idxrr100 = where (dist lt 100.)  ; everything inside 100 km to 300
dist2[idxrr100] = 300.
idxrr100 = where( dist gt 104.)  ; everything outside 104 km to 300
dist2[idxrr100] = 300.
idxrr100 = where ( dist2 lt 300. )  ; index of everything between 100 and 104 km

; to burn in a color bar, 0-64 dBZ
barx=128 & bary = 10
bar65 = bindgen(barx,bary)             ; a 128x10 pixel bar
bar65 = bar65 MOD byte(barx)           ; make all values between 0 and 127
idxrestore = where(bar65 eq 0B)        ; to restore values of 0
idxbrk=where( (bar65 mod 10B) eq 0B )  ; to mark every 5 dBZ
bar65[idxbrk] = bar65[idxbrk]+64B      ; offset the color at 5 dbz breaks
bar65 = bar65 mod byte(barx)           ; restore 0-127 range
bar65[idxrestore] = 0B                 ; restore 0 dBZ values
; set bar values to 0-64 dBZ range, image scaled to dBZ*4
bar65 = bar65*2B

; set up windows for image generation/copying
nimgs = 2  ; number of images in the vertical stack
if ( haveREO eq 1 && have55 eq 1 ) then nimgs = 3
ybarhgt = 50           ; height of image section reserved for colorbar
xsz1 = 225             ; width of image window
ysz1 = xsz1*nimgs      ; height of image window for map overlaid images
ysz2 = ysz1 + ybarhgt  ; height of image window for map overlaid images plus colorbar
WINDOW, 2, xsize=xsz1, ysize=ysz2, /PIXMAP  ; holds the below, plus the colorbar
WINDOW, 1, xsize=xsz1, ysize=ysz1, /PIXMAP  ; holds the images w. map overlays
TVLCT, 255,255,255,253 ; set map overlay color to white
TVLCT, 100,100,100,255 ; set range ring overlay color to gray100

; instantiate animation widget
tophgtstr =  string(levsdata*1.5, FORMAT='(f0.1)')
xinteranimate, set=[xsz1, ysz2, levsdata], /TRACK, $
               TITLE = strmid( bname, 8, prlen-14) + '   1.5-'+tophgtstr+' km'

; build the mapped images 3-row multiplot
for imglev=0, levsdata-1 do begin
  imghgtstr = string( imglev*1.5 + 1.5, FORMAT='(f0.1)') + ' km'
  if ( haveREO eq 1) then begin
     imgtemp = dbznexREO[*,*,imglev]*4.0  ; copy image array
     imgtemp[idxrr100] = 255.             ; burn in 100km range ring
     !P.MULTI=[1,1,nimgs]
     map_set, siteLat, siteLong, /azimuthal, limit=[latlo, lonlo, lathi, lonhi], /isotropic
     image = map_image(imgtemp,x0,y0,xsize,ysize,latmin=latlo,lonmin=lonlo,$
     latmax=lathi,lonmax=lonhi,compress=1)
     tvscl,image,x0,y0,xsize=xsize,ysize=ysize
     map_grid, color=253, label = 2, thick = 2
     map_continents, /hires, /usa, /coasts, color=253, thick = 1
  endif

  if ( have55 eq 1 ) then begin
     imgtemp = dbznex[*,*,imglev]*4.0  ; copy image array
     imgtemp[idxrr100] = 255.             ; burn in 100km range ring
     if ( haveREO eq 1) then begin
       !P.MULTI=[2,1,nimgs]
     endif else begin
       !P.MULTI=[1,1,nimgs]
     endelse
     map_set, siteLat, siteLong, /azimuthal, limit=[latlo, lonlo, lathi, lonhi], /isotropic, /noerase
     image = map_image(imgtemp,x0,y0,xsize,ysize,latmin=latlo,lonmin=lonlo,$
     latmax=lathi,lonmax=lonhi,compress=1)
     tvscl,image,x0,y0,xsize=xsize,ysize=ysize
     map_grid, color=253, label = 2, thick = 2
     map_continents, /hires, /usa, /coasts, color=253, thick = 1
  endif

  imgtemp = dbzcor[*,*,imglev]*4.0  ; copy image array
  imgtemp[idxrr100] = 255.             ; burn in 100km range ring
  !P.MULTI=[nimgs,1,nimgs]
  map_set, siteLat, siteLong, /azimuthal, limit=[latlo, lonlo, lathi, lonhi], /isotropic, /noerase
  image = map_image(imgtemp,x0,y0,xsize,ysize,latmin=latlo,lonmin=lonlo,$
  latmax=lathi,lonmax=lonhi,compress=1)
  tvscl,image,x0,y0,xsize=xsize,ysize=ysize
  map_grid, color=253, label = 2, thick = 2
  map_continents, /hires, /usa, /coasts, color=253, thick = 1

; add image labels
   xyouts, 5, ysz1-10, 'PR', CHARSIZE=1, COLOR=128, /DEVICE
   if ( have55 eq 1 ) then begin
      xyouts, 5, ysz1-10-225, '2A55 GV', CHARSIZE=1, COLOR=128, /DEVICE
      if ( haveREO eq 1) then xyouts, 5, ysz1-10-225*2, 'REORDER GV', CHARSIZE=1, COLOR=128, /DEVICE
   endif else begin
      xyouts, 5, ysz1-10-225, 'REORDER GV', CHARSIZE=1, COLOR=128, /DEVICE
   endelse

; copy images and color bar to window 2, and window 2 to animation loop
  WSET, 2
  DEVICE, COPY = [0, 0, xsz1, ysz1, 0, ybarhgt, 1]  ; copy images, leave room at bottom
  blankout = bytarr(xsz1,ybarhgt)
  blankout[*,*] = 255B
  TV, blankout, 0, 0
  TV, bar65, (xsz1-barx)/2, ybarhgt-bary-5
  xyouts, (xsz1-barx)/2 - 3, ybarhgt-bary-20, '0', CHARSIZE=1, COLOR=128, /DEVICE
  xyouts, xsz1/2 - 5, ybarhgt-bary-20, 'dBZ', CHARSIZE=1, COLOR=128, /DEVICE
  xyouts, (xsz1-barx)/2+barx-3, ybarhgt-bary-20, '64', CHARSIZE=1, COLOR=128, /DEVICE
  xyouts, xsz1/2 - 15, ybarhgt-bary-35, imghgtstr, CHARSIZE=1, COLOR=128, /DEVICE

;stop
  xinteranimate, frame = imglev, window=2
  erase
  WSET,1  ; do a new set of images in window 1
endfor

print, ''
print, 'Click END ANIMATION button or close Animation window to proceed to next case:
print, ''
xinteranimate, 2, /BLOCK

WDELETE, 1,2

skipAnim:
WDELETE, 0

nextFile:
endfor
;###############################################################################
endelse

print, 'Done!'
errorExit:
end
