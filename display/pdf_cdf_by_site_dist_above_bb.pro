;+
; Copyright © 2008, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; pdf_cdf_by_site_dist_above_bb.pro
;-------------------------------------------------------------
; Generate both a Cumulative Density Function (CDF) and a
; Probability Density Funtion (PDF) plot of GV dBZ values at
; a set of ranges from the GV radar, for each height level in
; the GV netCDF grids.  Output is either to a Postscript file
; or to the display, as set by the do_ps variable.  The set of
; grids to process (sites/dates) is controlled by the filename
; pattern in the pathgv variable.  Both 2A55 and REORDER based
; grids are processed, into separate output plots.
;-------------------------------------------------------------
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-

pro pdf_cdf_by_site_dist_above_bb

do_ps = 1   ; set to 1 if postcript desired
orig_device = !d.name
if ( do_ps eq 0 ) then begin
   device, decomposed = 0, retain = 2
endif

; "include" file for PR data constants
@pr_params.inc

;##################################
bs = 1.
minz4hist = 18.
maxz4hist = 45.
;##################################

restore, '~/swdev/idl/valnet/BMcolors.tbl'
tvlct, red, green, blue

;pathpr='/data/netcdf/PR'
;pathgv='/data/netcdf/NEXRAD/GV'
;ncfilepr = dialog_pickfile(path=pathpr)
;while ncfilepr ne '' do begin
pathpr = '/data/netcdf/PR/PRgrids'
pathgv = '/data/netcdf/NEXRAD/GVgrids'
pathgv2 = '/data/netcdf/NEXRAD_REO/allYMD/GVgridsREO'

command = "ls "+ pathgv + "* | cut -f2 -d '.' | sort -u"
spawn, command, sitelist
nsites = N_ELEMENTS(sitelist)

if nsites gt 0 then begin

if (do_ps eq 1) then begin
    ps_fname = "/data/tmp/GV_Reflectivity_PDF_CDF_StratAbvBB"+".ps"
    set_plot, 'ps'
    device, /portrait, filename=ps_fname, /color, BITS=8
    !P.FONT=0 ; use the device fonts supplied by postscript
    chsz1 = 0.5 & chsz2 = 0.75 & thk = 2
endif else begin
    window, 0, xsize = 1200, ysize = 750
    chsz1 = 1 & chsz2 = 1.5 & thk = 1
endelse

for sitenum = 0, nsites-1 do begin
;for sitenum = 0, 0 do begin  ; testing, do first site only
gvfiles = file_search(pathgv+'*'+sitelist[sitenum]+'*',COUNT=nf)

if nf gt 0 then begin

; Compute a radial distance array of 2-D netCDF grid dimensions
xdist = findgen(75,75)
xdist = ((xdist mod 75.) - 37.) * 4.
ydist = TRANSPOSE(xdist)
dist = SQRT(xdist*xdist + ydist*ydist)

; Set a distance array to fixed values by distance category,
; for 20-km annular rings
distcat = indgen(75,75)
distcat[*,*] = 0
;for dcat = 1, 3 do begin
for dcat = 1, 2 do begin   ; to match database stats using >=100km category
  dstart = dcat * 50.0
  idxnear = where( dist ge dstart, countdist)
  if countdist gt 0 then distcat[idxnear] = dcat
endfor
;rangestr=['0-50 km', '50-100 km', '100-150 km']
rangestr=['0-50 km', '50-100 km', '>=100 km'] ; to match database stats using >=100km category

haveREOmatch = 0
initialized = 0     ; for histogram accums
initializedREO = 0  ; for REO histogram accums

for fnum = 0, nf-1 do begin

haveREO = 0
ncfilegv = gvfiles(fnum)
bname = file_basename( ncfilegv )
prlen = strlen( bname )
gvpost = strmid( bname, 7, prlen)
ncfilepr = pathpr + gvpost
ncfilegvREO = pathgv2 + gvpost
;print, ncfilepr
;print, ncfilegv
;print, ncfilegvREO

; Get uncompressed copy of the found files
cpstatus = uncomp_file( ncfilepr, ncfile1 )
if(cpstatus eq 'OK') then begin
  cpstatus2 = uncomp_file( ncfilegv, ncfile2 )
  if(cpstatus2 eq 'OK') then begin
     ncid1 = NCDF_OPEN( ncfile1 )
     ncid2 = NCDF_OPEN( ncfile2 )

     siteID = ""
     NCDF_VARGET, ncid2, 'site_ID', siteIDbyte
;     NCDF_VARGET, ncid1, 'site_lat', siteLat
;     NCDF_VARGET, ncid1, 'site_lon', siteLong
;     NCDF_VARGET, ncid1, 'timeNearestApproach', event_time
;     NCDF_VARGET, ncid1, 'landOceanFlag', landoceanMap
     NCDF_VARGET, ncid1, 'rainType', rainTypeMap
     NCDF_VARGET, ncid2, 'beginTimeOfVolumeScan', event_time2
     siteID = string(siteIDbyte)
;     print, siteID, siteLat, siteLong, event_time, event_time2

     NCDF_VARGET, ncid1, 'BBheight', BB_Hgt  ; now in meters! (if > 0)
     NCDF_VARGET, ncid1, 'correctZFactor', dbzcor
     NCDF_VARGET, ncid2, 'threeDreflect', dbznex

;    Convert BB height to level index 0-12, or -1 if missing/undefined
     idxbbmiss = where(BB_Hgt le 0, countbbmiss)
     if (countbbmiss gt 0) then BB_Hgt[idxbbmiss] = -1
     idxbb = where(BB_Hgt gt 0, countbb)
     if (countbb gt 0) then begin
;       Level below BB is affected if BB_Hgt is 1000m or less above layer center,
;       so BB_HgtLo is lowest grid layer considered to be within the BB
        BB_HgtLo = (BB_Hgt[idxbb]-1001)/1500
;       Level above BB is affected if BB_Hgt is 1000m or less below layer center,
;       so BB_HgtHi is highest grid layer considered to be within the BB
        BB_HgtHi = (BB_Hgt[idxbb]-500)/1500
        BB_HgtLo = BB_HgtLo < 12
        BB_HgtHi = BB_HgtHi < 12
     endif else begin
        print, 'No valid Bright Band values in grid!  Skipping case.'
        goto, nextFile
     endelse

     NCDF_CLOSE, ncid1
     command = "rm " + ncfile1
     spawn, command

     NCDF_CLOSE, ncid2
     command = "rm " + ncfile2
     spawn, command

;    query REORDER netCDF file variables, if REO available
     cpstatusREO = uncomp_file( ncfilegvREO, ncfile3 )
     if (cpstatusREO eq 'OK') then begin
        if (haveREOmatch eq 0 ) then begin
           firstREOfile = fnum
           haveREOmatch = 1                       ; initialize flag
        endif
        haveREO = 1
        ncid3 = NCDF_OPEN( ncfile3 )
        NCDF_VARGET, ncid3, 'CZ', dbznexREO
        NCDF_VARGET, ncid3, 'base_time', event_timeREO
        NCDF_CLOSE, ncid3
        command = "rm " + ncfile3
        spawn, command
     endif else begin
        print, 'Cannot find GVREO netCDF file: ', ncfilegvREO
        print, cpstatus2
     endelse
  endif else begin
     print, 'Cannot find GV netCDF file: ', ncfilegv
     print, cpstatus2
    command3 = "rm " + ncfile1
    spawn, command3
    goto, errorExit
  endelse
endif else begin
  print, 'Cannot copy/unzip PR netCDF file: ', ncfilepr
  print, cpstatus
  command3 = "rm " + ncfile1
  spawn, command3
  goto, nextFile
endelse

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

; Compute at each level
for lev2get = 0, 12 do begin
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
         dbzpr2 = dbzpr1[idxpos2]
         dbznx2 = dbznx1[idxpos2]
        ; Do stratified differences: Total, and 
        ; above/below/within BB, Convective and Stratiform
         bb2Hi = bb1Hi[idxpos2]
         bb2Lo = bb1Lo[idxpos2]
         rntyp2 = rntyp1[idxpos2]
         distcat2 = distcat1[idxpos2]
         idxstratabove = where(rntyp2 eq RainType_stratiform and bb2Hi ne BB_MISSING $
                               and bb2Hi lt lev2get, countstratabove)
         if (countstratabove gt 0) then begin
           dbznexstratabove = dbznx2[idxstratabove]
           distcat2sa = distcat2[idxstratabove]

         ;  Pure histogram of GV Z, per range category:
           for dcat = 0, 2 do begin
              idxnear = where( distcat2sa eq dcat, countnear )
              if ( countnear gt 0 ) then begin
                 gvhist = histogram(dbznexstratabove[idxnear], min=minz4hist, max=maxz4hist, $
                          binsize = bs, locations = prhiststart)
                 if ( initialized eq 0 ) then begin
                     initialized = 1
                     zvals = prhiststart + (bs/2.0)
                     gvhist_accum = replicate( 0L, 3, N_ELEMENTS(gvhist) )
                 endif
                 gvhist_accum[dcat,*] = gvhist + gvhist_accum[dcat,*]
              endif
           endfor
         endif  ; countstratabove gt 0
      endif     ; countpos2 gt 0

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
            idxRstratabove = where(rntyp3 eq RainType_stratiform and bb3Hi ne BB_MISSING $
                                 and bb3Hi lt lev2get, countRstratabove)
            if (countRstratabove gt 0 ) then begin
               dbznexRstratabove = dbznx3[idxRstratabove]
               distcat3sa = distcat3[idxRstratabove]
               for dcat = 0, 2 do begin
                  idxnear = where( distcat3sa eq dcat, countnear )
                  if ( countnear gt 0 ) then begin
                     gvhistr = histogram(dbznexRstratabove[idxnear], min=minz4hist, max=maxz4hist, $
                               binsize = bs, locations = prhiststart)
                     if ( initializedREO eq 0 ) then begin
                        initializedREO = 1
                        gvhistr_accum = replicate( 0L, 3, N_ELEMENTS(gvhistr) )
                     endif
                     gvhistr_accum[dcat,*] = gvhistr + gvhistr_accum[dcat,*]
                  endif
               endfor
            endif  ; countRstratabove gt 0
         endif     ; countpos3 gt 0
      endif        ; haveREO eq 1

   endif  ; countpos1 gt 0

endfor ; lev2get loop

nextFile:
endfor

!P.Multi = [0,2,2,0,1]

ytextpos = 0.2 & ytextposr = 0.2
;if ( graph eq 'PDF' ) then begin
;   ytextpos = 0.9 & ytextposr = 0.4
   plotymaxt = dblarr(3)
   cdfall = double(gvhist_accum)
   npts = total(gvhist_accum, 2)
   for  dcat = 0,2 do begin
      plotymaxt[dcat] = 0.05D
      if (npts[dcat] gt 0) then $
         plotymaxt[dcat] = max(cdfall[dcat,*]) / npts[dcat]
   endfor
 if ( haveREOmatch eq 1) then begin
   plotymaxr = dblarr(3)
   cdfall = double(gvhistr_accum)
   nptsr = total(gvhistr_accum, 2)
   for dcat = 0,2 do begin
      plotymaxr[dcat] = 0.05D
      if (nptsr[dcat] gt 0) then $
         plotymaxr[dcat] = max(cdfall[dcat,*]) / nptsr[dcat]
   endfor
 endif
;endif
plotymax = plotymaxt > plotymaxr

hgtline = 'Above BB'

   npts = total(gvhist_accum, 2)
; PDFs
   cdf = double(gvhist_accum[0,*])
   cdf = cdf / npts[0] ;most
   plot, prhiststart, cdf, COLOR = 0, XTITLE='Reflectivity, dBZ', $
      YTITLE='Fraction of Points', YRANGE=[0,max(plotymax[*])], $ 
      TITLE = hgtline+", for 2A55, at "+siteID, CHARSIZE=chsz2, BACKGROUND = 8
   rangestring = rangestr[0]+', NumPoints = '+STRING(npts[0], FORMAT='(i0)')
   xyouts, 0.25, ytextpos, rangestring, COLOR = 0, /NORMAL, CHARSIZE=chsz1
   for dcat = 1, 2 do begin
      cdf = double(gvhist_accum[dcat,*])
      cdf = cdf / npts[dcat]
      oplot, prhiststart, cdf, COLOR = dcat, THICK=thk
      rangestring = rangestr[dcat]+', NumPoints = '+STRING(npts[dcat], FORMAT='(i0)')
      xyouts, 0.25, ytextpos-dcat*0.03, rangestring, COLOR = dcat, $
              /NORMAL, CHARSIZE=chsz1
   endfor
; CDFs
   cdf = long(gvhist_accum[0,*])
   for i = 1, N_ELEMENTS( cdf )-1 do begin
      cdf[i] = cdf[i] + cdf[i-1]
   endfor
   cdf = cdf/npts[0]
   plot, prhiststart, cdf, COLOR = 0, XTITLE='Reflectivity, dBZ', $
      YTITLE='Cumulative Fraction of Points', YRANGE=[0,1], $ 
      CHARSIZE=chsz2, THICK=thk, BACKGROUND = 8
   for dcat = 1, 2 do begin
      cdf = long(gvhist_accum[dcat,*])
      for i = 1, N_ELEMENTS( cdf )-1 do begin
         cdf[i] = cdf[i] + cdf[i-1]
      endfor
      cdf = cdf/npts[dcat]
      oplot, prhiststart, cdf, COLOR = dcat, THICK=thk
   endfor

   if ( haveREOmatch eq 1) then begin
      npts = total(gvhistr_accum, 2)
   ; PDFs
      cdf = double(gvhistr_accum[0,*])
      cdf = cdf / npts[0] ;most
      plot, prhiststart, cdf, COLOR = 0, XTITLE='Reflectivity, dBZ', $
         YTITLE='Fraction of Points', YRANGE=[0,max(plotymax[*])], $ 
         TITLE = hgtline+", for REORDER, at "+siteID, CHARSIZE=chsz2, BACKGROUND = 8
      rangestring = rangestr[0]+', NumPoints = '+STRING(npts[0], FORMAT='(i0)')
      xyouts, 0.75, ytextposr, rangestring, COLOR = 0, /NORMAL, CHARSIZE=chsz1
      for dcat = 1, 2 do begin
         cdf = double(gvhistr_accum[dcat,*])
         cdf = cdf / npts[dcat]
         oplot, prhiststart, cdf, COLOR = dcat, THICK=thk
         rangestring = rangestr[dcat]+', NumPoints = '+STRING(npts[dcat], FORMAT='(i0)')
         xyouts, 0.75, ytextposr-dcat*0.03, rangestring, COLOR = dcat, $
                 /NORMAL, CHARSIZE=chsz1
      endfor
   ; CDFs
      cdf = long(gvhistr_accum[0,*])
      for i = 1, N_ELEMENTS( cdf )-1 do begin
         cdf[i] = cdf[i] + cdf[i-1]
      endfor
      cdf = cdf/npts[0]
      plot, prhiststart, cdf, COLOR = 0, XTITLE='Reflectivity, dBZ', $
         YTITLE='Cumulative Fraction of Points', YRANGE=[0,1], $ 
         CHARSIZE=chsz2, THICK=thk, BACKGROUND = 8
      for dcat = 1, 2 do begin
         cdf = long(gvhistr_accum[dcat,*])
         for i = 1, N_ELEMENTS( cdf )-1 do begin
            cdf[i] = cdf[i] + cdf[i-1]
         endfor
         cdf = cdf/npts[dcat]
         oplot, prhiststart, cdf, COLOR = dcat, THICK=thk
      endfor
   endif
   if (do_ps ne 1) then STOP

endif ; have file(s)
if (do_ps eq 1) then erase  ; start a new page

endfor  ; sitenum

if (do_ps eq 1) then begin
   device, /close_file
   set_plot, 'X'
   device, decomposed = 0, retain = 2
endif
set_plot, orig_device
endif   ; nsites gt 0
goto, ExitNormal;
errorExit: print, "No matching files found!"
ExitNormal:
if (do_ps ne 1) then wdelete, 0
print, 'Done!'
end
