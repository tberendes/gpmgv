;+
; Copyright © 2008, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; comparison_PR_GV_dBZ_geo.pro   Morris/SAIC/GPM_GV   2008
;
; DESCRIPTION
; -----------
; Processes the set of geo-match netCDF files specified by the input
; parameters and produces summary statistics of PR-GV reflectivity bias,
; standard deviation and error, scatter plots, and reflectivity histograms.
; Output is to a set of ASCII text and Postscript files.
;
; HISTORY
;       Bob Morris, SAIC, GPM GV
;       Rewritten version of comparison_PR_GV_dBZ.pro, to read and process
;       geo_match netCDF files with data at random points and heights, as
;       opposed to the PR, GV, and GV-REO netCDF files having regularly-gridded
;       data.  Borrowed the logic to reorganize the random data into fixed
;       heights from stratified_by_dist_stats_to_dbfile_geo_match.pro.
;
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-

pro comparison_PR_GV_dBZ_geo, siteID_in, NCPATH=ncpath, DATES=datefilter

on_error, 3

; "include" file for structs returned by read_geo_match_netcdf()
@geo_match_nc_structs.inc

; "include" file for PR data constants
@pr_params.inc

if ( n_params() ne 1 ) then begin
   message, 'File pattern for netCDF files not provided!  Bye.'
endif

IF ( N_ELEMENTS(ncpath) NE 1 ) THEN BEGIN
   print, "Defaulting to /data/netcdf/geo_match for file path."
   pathpr = '/data/netcdf/geo_match'
ENDIF ELSE pathpr = ncpath

cd, '/home/morris/swdev/idl/dev/comparez'  ; since output files are relative to here

pathpr = pathpr + '/*' + siteID_in
IF ( N_ELEMENTS(datefilter) EQ 1 ) THEN BEGIN
   pathpr = pathpr + '.' + datefilter + '*'
ENDIF ELSE pathpr = pathpr + '*'
print, ""
print, "Filter for files to be processed = ", pathpr
print, ""

common sample, start_sample,sample_range,num_range,dbz_min,dbz_max
common time, TRMM_TIME, hh_gv, mm_gv, ss_gv, year, month, day
common groundSite, siteLong, siteLat, siteID
common cumulation, s_npt, c_npt, t_npt, o_npt, l_npt, m_npt, $
                   s_pr0_tot, s_pr_tot, s_gv_tot, c_pr0_tot, c_pr_tot, c_gv_tot, $
                   t_pr0_tot, t_pr_tot, t_gv_tot, o_pr0_tot, o_pr_tot, o_gv_tot, $
                   l_pr0_tot, l_pr_tot, l_gv_tot, m_pr0_tot, m_pr_tot, m_gv_tot, $
                   t_epsilon,t_epsilon0,o_epsilon,o_epsilon0,l_epsilon,l_epsilon0, $
                   m_epsilon,m_epsilon0,s_epsilon,s_epsilon0,c_epsilon,c_epsilon0
common nfile_record, nfile

common PR_GV, rainType_2a23, rainType_2a54, dbz_1c21, dbz_2a25, dbz_2a55, oceanFlag, $
              epsilon,epsilon_0

siteID = siteID_in
DBZ_MIN = 15
DBZ_MAX = 55
Heights2do = [3.0, 4.5, 6.0, 7.5]   ; Altitude above ground (km)
NHeights = N_ELEMENTS(Heights2do)

; do the Z comparisons for this site and height
for ilev = 0, N_ELEMENTS(Heights2do)-1 do begin
   Height = Heights2do[ilev]
   print, "Doing Height = ", HEIGHT

CASE fix(Height*10) of
   15: nHeight = 0
   30: nHeight = 1
   45: nHeight = 2
   60: nHeight = 3
   75: nHeight = 4
   90: nHeight = 5
 ELSE: STOP
ENDCASE

s_npt = 0L  &  c_npt = 0L  &  t_npt = 0L
s_pr0_tot = fltarr(100000)  &  s_pr_tot = fltarr(100000)  &  s_gv_tot = fltarr(100000)
c_pr0_tot = fltarr(100000)  &  c_pr_tot = fltarr(100000)  &  c_gv_tot = fltarr(100000)
t_pr0_tot = fltarr(100000)  &  t_pr_tot = fltarr(100000)  &  t_gv_tot = fltarr(100000)
t_epsilon=fltarr(100000)  & t_epsilon0=fltarr(100000)
s_epsilon=fltarr(100000)  & s_epsilon0=fltarr(100000)
c_epsilon=fltarr(100000)  & c_epsilon0=fltarr(100000)   

o_npt = 0L  &  l_npt = 0L  &  m_npt = 0L
o_pr0_tot = fltarr(100000)  &  o_pr_tot = fltarr(100000)  &  o_gv_tot = fltarr(100000)
l_pr0_tot = fltarr(100000)  &  l_pr_tot = fltarr(100000)  &  l_gv_tot = fltarr(100000)
m_pr0_tot = fltarr(100000)  &  m_pr_tot = fltarr(100000)  &  m_gv_tot = fltarr(100000)
o_epsilon=fltarr(100000)  & o_epsilon0=fltarr(100000)
l_epsilon=fltarr(100000)  & l_epsilon0=fltarr(100000)
m_epsilon=fltarr(100000)  & m_epsilon0=fltarr(100000)


table_0 = "./results/stratiform_mean_std_h"+string(height,format='(f3.1)')+"."+siteID+".geo.tab"
table_1 = "./results/convective_mean_std_h"+string(height,format='(f3.1)')+"."+siteID+".geo.tab"
table_2 = "./results/total_mean_std_h"+string(height,format='(f3.1)')+"."+siteID+".geo.tab"
table_3 = "./results/overOcean_mean_std_h"+string(height,format='(f3.1)')+"."+siteID+".geo.tab"
table_4 = "./results/overLand_mean_std_h"+string(height,format='(f3.1)')+"."+siteID+".geo.tab"
table_5 = "./results/overMixedWaterLand_mean_std_h"+string(height,format='(f3.1)')+"."+siteID+".geo.tab"

table_6 = "./results/cumulation_stratiform_mean_std_h"+string(height,format='(f3.1)')+"."+siteID+".geo.tab"
table_7 = "./results/cumulation_convective_mean_std_h"+string(height,format='(f3.1)')+"."+siteID+".geo.tab"
table_8 = "./results/cumulation_total_mean_std_h"+string(height,format='(f3.1)')+"."+siteID+".geo.tab"
table_9 = "./results/cumulation_overOcean_mean_std_h"+string(height,format='(f3.1)')+"."+siteID+".geo.tab"
table_10 = "./results/cumulation_overLand_mean_std_h"+string(height,format='(f3.1)')+"."+siteID+".geo.tab"
table_11 = "./results/cumulation_overMixedWaterLand_mean_std_h"+string(height,format='(f3.1)')+"."+siteID+".geo.tab"

table_12 = "./results/rainType_agreement."+siteID+".geo.tab"
table_13 = "./results/standardError_h"+string(height,format='(f3.1)')+"."+siteID+".geo.tab"
table_14 = "./results/bias_h"+string(height,format='(f3.1)')+"_stratiform."+siteID+".geo.tab"
table_15 = "./results/bias_h"+string(height,format='(f3.1)')+"_convective."+siteID+".geo.tab"
table_16 = "./results/bias_h"+string(height,format='(f3.1)')+"_total."+siteID+".geo.tab"

common lun, lun_0, lun_1, lun_2, lun_3, lun_4, lun_5, lun_6, lun_7, lun_8, lun_9, lun_10, lun_11

OPENW, lun_0, table_0, ERROR=err, /GET_LUN
OPENW, lun_1, table_1, ERROR=err, /GET_LUN
OPENW, lun_2, table_2, ERROR=err, /GET_LUN
OPENW, lun_3, table_3, ERROR=err, /GET_LUN
OPENW, lun_4, table_4, ERROR=err, /GET_LUN
OPENW, lun_5, table_5, ERROR=err, /GET_LUN
OPENW, lun_6, table_6, ERROR=err, /GET_LUN
OPENW, lun_7, table_7, ERROR=err, /GET_LUN
OPENW, lun_8, table_8, ERROR=err, /GET_LUN
OPENW, lun_9, table_9, ERROR=err, /GET_LUN
OPENW, lun_10, table_10, ERROR=err, /GET_LUN
OPENW, lun_11, table_11, ERROR=err, /GET_LUN

OPENW, lun_12, table_12, ERROR=err, /GET_LUN
OPENW, lun_13, table_13, ERROR=err, /GET_LUN
OPENW, lun_14, table_14, ERROR=err, /GET_LUN
OPENW, lun_15, table_15, ERROR=err, /GET_LUN
OPENW, lun_16, table_16, ERROR=err, /GET_LUN

; Compute a radial distance array of 2-D netCDF grid dimensions
;dist = SQRT(xdist*xdist + ydist*ydist)
;idxdist_gt100 = where(dist gt 100.)

nfile = -1
;for i=0, npairs-1 do begin
prfiles = file_search(pathpr,COUNT=nf)
if nf gt 0 then begin

for fnum = 0, nf-1 do begin

;  LOOP OVER EACH SITE'S FILES.
   nfile = nfile + 1                      ; for common block


; READ DATA AND DO Z COMPARISON

;   status = 1       ; initialize to FAILED
;   event_time=0.0D
;   siteLat = mysite.site_lat
;   siteLong = mysite.site_lon
;   event_time2=0.0D
TRMM_TIME = ''
NEXRAD_TIME = ''
dayN = 0l & monthN = 0l & yearN = 0l & hh_gv = 0l & mm_gv = 0l & ss_gv = 0l

ncfilepr = prfiles(fnum)
bname = file_basename( ncfilepr )
prlen = strlen( bname )
print, "PR netCDF file: ", ncfilepr

parsed = strsplit(bname, '.', /EXTRACT)
orbit = parsed[3]

; Get uncompressed copy of the found files
cpstatus = uncomp_file( ncfilepr, ncfile1 )
if ( cpstatus eq 'OK' ) then begin
  status = 1   ; init to FAILED

 ; initialize metadata structures and read metadata
  mygeometa={ geo_match_meta }
  mysweeps={ gv_sweep_meta }
  mysite={ gv_site_meta }
  myflags={ pr_gv_field_flags }
  status = read_geo_match_netcdf( ncfile1, matchupmeta=mygeometa, $
     sweepsmeta=mysweeps, sitemeta=mysite, fieldflags=myflags )

 ; create data field arrays of correct dimensions and read data fields
  nfp = mygeometa.num_footprints
  nswp = mygeometa.num_sweeps
  gvexp=intarr(nfp,nswp)
  gvrej=intarr(nfp,nswp)
  prexp=intarr(nfp,nswp)
  zrawrej=intarr(nfp,nswp)
  zcorrej=intarr(nfp,nswp)
  rainrej=intarr(nfp,nswp)
  gvz=intarr(nfp,nswp)
  zraw=fltarr(nfp,nswp)
  zcor=fltarr(nfp,nswp)
  rain3=fltarr(nfp,nswp)
  top=fltarr(nfp,nswp)
  botm=fltarr(nfp,nswp)
  lat=fltarr(nfp,nswp)
  lon=fltarr(nfp,nswp)
  bb=fltarr(nfp)
  rnflag=intarr(nfp)
  rntype=intarr(nfp)
  sfctyp=intarr(nfp)
  pr_index=lonarr(nfp)

  status = read_geo_match_netcdf( ncfile1, $
     gvexpect_int=gvexp, gvreject_int=gvrej, prexpect_int=prexp, $
     zrawreject_int=zrawrej, zcorreject_int=zcorrej, rainreject_int=rainrej, $
     dbzgv=gvz, dbzcor=zcor, dbzraw=zraw, rain3d=rain3, topHeight=top, $
     bottomHeight=botm, latitude=lat, longitude=lon, bbhgt=BB, $
     rainflag_int=rnFlag, raintype_int=rnType, sfctype_int=sfctyp, $
     pridx_long=pr_index )

  command3 = "rm " + ncfile1
  spawn, command3
endif else begin
  print, 'Cannot copy/unzip netCDF file: ', ncfilepr
  print, cpstatus
  command3 = "rm -v " + ncfile1
  spawn, command3
  goto, errorExit
endelse

siteLat = mysite.site_lat
siteLon = mysite.site_lon
siteID = string(mysite.site_id)
nsweeps = mygeometa.num_sweeps

;-------------------------------------------------------------
; clip the data fields down to the "actual footprint" points

; get array indices of the non-bogus footprints
idxpractual = where(pr_index GE 0L, countactual)
if (countactual EQ 0) then begin
   print, "No non-bogus data points, quitting case."
   goto, errorExit
endif

;------------------------
; Clip single-level field first (don't need BB replicated to all sweeps):
BB = BB[idxpractual]

;------------------------
; Now do the sweep-level arrays - have to build an array index of actual
; points, replicated over all the sweep levels
idx3d=long(gvexp)   ; take one of the 2D arrays, make it LONG type
idx3d[*,*] = 0L     ; initialize all points to 0

; set the first sweep level's values to 1 where non-bogus
idx3d[idxpractual,0] = 1L
  
; copy the first sweep to the other levels, and make the single-level arrays
; for categorical fields the same dimension as the sweep-levels', using IDL's
; array concatenation feature
rnFlagApp = rnFlag
rnTypeApp = rnType
sfTypeApp = sfctyp
IF ( nsweeps GT 1 ) THEN BEGIN  
   FOR iswp=1, nsweeps-1 DO BEGIN
      idx3d[*,iswp] = idx3d[*,0]
      rnFlag = [rnFlag, rnFlagApp]  ; concatenate another level's worth
      rnType = [rnType, rnTypeApp]
      sfctyp = [sfctyp, sfTypeApp]
   ENDFOR
ENDIF

; get the indices of all the non-bogus points in the multi-level arrays
idxpractual2d = where( idx3d EQ 1L, countactual2d )
if (countactual2d EQ 0) then begin
  ; this shouldn't be able to happen
   print, "No non-bogus 2D data points, quitting case."
   goto, errorExit
endif

; clip the sweep-level arrays to the non-bogus point set
gvexp = gvexp[idxpractual2d]
gvrej = gvrej[idxpractual2d]
prexp = prexp[idxpractual2d]
zrawrej = zrawrej[idxpractual2d]
zcorrej = zcorrej[idxpractual2d]
rainrej = rainrej[idxpractual2d]
gvz = gvz[idxpractual2d]
zraw = zraw[idxpractual2d]
zcor = zcor[idxpractual2d]
rain3 = rain3[idxpractual2d]
top = top[idxpractual2d]
botm = botm[idxpractual2d]
lat = lat[idxpractual2d]
lon = lon[idxpractual2d]
rnFlag = rnFlag[idxpractual2d]
rnType = rnType[idxpractual2d]
sfctyp = sfctyp[idxpractual2d]
;-------------------------------------------------------------

; Further clip the sweep-level arrays to the points with reflectivity averages
; where all input bins met the predefined dBZ cutoff criterion

idxgoodz = WHERE( gvexp GT 0 AND prexp GT 0 AND gvrej EQ 0 AND zcorrej EQ 0, $
                  countgoodz )
if (countgoodz EQ 0) then begin
   print, "No qualifying PR or GV Z-average data points, quitting case."
   goto, nextFile
endif

gvexp = gvexp[idxgoodz]
gvrej = gvrej[idxgoodz]
prexp = prexp[idxgoodz]
zrawrej = zrawrej[idxgoodz]
zcorrej = zcorrej[idxgoodz]
rainrej = rainrej[idxgoodz]
gvz = gvz[idxgoodz]
zraw = zraw[idxgoodz]
zcor = zcor[idxgoodz]
rain3 = rain3[idxgoodz]
top = top[idxgoodz]
botm = botm[idxgoodz]
lat = lat[idxgoodz]
lon = lon[idxgoodz]
rnFlag = rnFlag[idxgoodz]
rnType = rnType[idxgoodz]
sfctyp = sfctyp[idxgoodz]

;-------------------------------------------------------------

; reclassify rain types down to simple categories 1, 2, or 3, where defined
idxrnpos = where(rntype ge 0, countrntype)
if (countrntype GT 0 ) then rntype(idxrnpos) = rntype(idxrnpos)/100

; convert bright band heights from m to km, where defined, and get mean BB hgt
idxbbdef = where(bb GT 0.0, countBB)
if ( countBB GT 0 ) THEN BEGIN
;***********************
;BB PARMS NOT USED IN THIS CODE!!
;***********************
   meanbb_m = FIX(MEAN(bb[idxbbdef]))  ; in meters
;   meanbb = meanbb_m/1000.        ; in km
;  Level below BB is affected if BB_Hgt is within 1000m above layer center,
;  so BB_HgtLo is index of lowest layer considered to be within the BB
   BB_HgtLo = (meanbb_m-1001)/1500
;  Level above BB is affected if BB_Hgt is 1000m or less below layer center,
;  so BB_HgtHi is index of highest layer considered to be within the BB
;   BB_HgtHi = (meanbb_m-500)/1500
;   BB_HgtLo = BB_HgtLo < 12
;   BB_HgtHi = BB_HgtHi < 12
;print, 'Mean BB (km), bblo, bbhi = ', meanbb, BB_HgtLo, BB_HgtHi
ENDIF ELSE BEGIN
   print, "No valid bright band heights, quitting case."
   goto, nextFile
ENDELSE

; build an array of ranges, range categories from the GV radar
; initialize a gv-centered map projection for the ll<->xy transformations:
sMap = MAP_PROJ_INIT( 'Azimuthal Equidistant', center_latitude=site_lat, $
                      center_longitude=site_lon )
XY_km = map_proj_forward( lon, lat, map_structure=smap ) / 1000.
dist = SQRT( XY_km[0,*]^2 + XY_km[1,*]^2 )

; array of range categories: 0 for 0<=r<50, 1 for 50<=r<100, 2 for r>=100, etc.
;   (for now we only have points roughly inside 100km, so limit to 2 categs.)
distcat = ( FIX(dist) / 50 ) < 1

; build an array of height category for the traditional VN levels
hgtcat = distcat  ; for a starter
hgtcat[*] = -99   ; re-initialize to -99
beamhgt = botm    ; for a starter, to build array of center of beam
heights = [1.5,3.0,4.5,6.0,7.5,9.0,10.5,12.0,13.5,15.0,16.5,18.0,19.5]
nhgtcats = N_ELEMENTS(heights)
num_in_hgt_cat = LONARR( nhgtcats )
halfdepth = 0.75
idxhgtdef = where( botm GT halfdepth AND top GT halfdepth, counthgtdef )
IF ( counthgtdef GT 0 ) THEN BEGIN
   beamhgt[idxhgtdef] = (top[idxhgtdef]+botm[idxhgtdef])/2
   hgtcat[idxhgtdef] = FIX((beamhgt[idxhgtdef]-halfdepth)/(halfdepth*2.0))
   idx2low = where( beamhgt[idxhgtdef] LT halfdepth, n2low )
   if n2low GT 0 then hgtcat[idxhgtdef[idx2low]] = -1

;   FOR i=0, nhgtcats-1 DO BEGIN
      hgtstr =  string(heights[nHeight], FORMAT='(f0.1)')
      idxhgt = where(hgtcat EQ nHeight, counthgts)
      num_in_hgt_cat[nHeight] = counthgts
      if ( counthgts GT 0 ) THEN BEGIN
         print, "HEIGHT = "+hgtstr+" km: npts = ", counthgts, " min = ", $
            min(beamhgt[idxhgt]), " max = ", max(beamhgt[idxhgt])
      endif else begin
         print, "HEIGHT = "+hgtstr+" km: npts = ", counthgts
      endelse
;   ENDFOR
ENDIF ELSE BEGIN
   maxbeamtop = max( (top+botm)/2.0 )
   print, ""
   print, "Highest beam midpoint = ", maxbeamtop
   print, "No valid beam heights, quitting case."
   print, ""
   goto, nextFile
ENDELSE


   ; grab the Z data for the selected Height level.  THIS IS WHERE WE WOULD DO ANY
   ; ALINGMENT OF REFLECTIVITY DATA BETWEEN pr AND gv ARRAYS.  MAKE IT A CALL TO A
   ; SEPARATE ALIGNMENT PROCEDURE.  ALIGN dbznex TO dbzcor.
   idx_at_hgt = WHERE( hgtcat EQ nHeight, counthgts )
   if ( counthgts lt 1 ) then goto, nextFile
   dbz_1c21 = zraw[idx_at_hgt]
   dbz_2a25 = zcor[idx_at_hgt]
   dbz_2a55 = gvz[idx_at_hgt]

   ; set the Z values beyond 100km range to a missing value so they will be
   ; ignored in the comparisons
;   dbz_1c21[idxdist_gt100] = -77.
;   dbz_2a25[idxdist_gt100] = -77.
;   dbz_2a55[idxdist_gt100] = -77.

   ; scale the oceanFlag as commonArea expects
   oceanFlag = sfctyp[idx_at_hgt] * 10

   rainType_2a23 = rnType[idx_at_hgt]
   rainType_2a54 = rainType_2a23

   TRMM_DATETIME = mygeometa.ATIMENEARESTAPPROACH  ; e.g., '2006-08-08 15:06:28'
   timeparts=strsplit(TRMM_DATETIME, '  *', /extract)
   TRMM_TIME=timeparts[1]                    ; i.e., the HH:MM:SS field
   NEXRAD_TIME = mysweeps[0].ATIMESWEEPSTART
   event_time2 = mysweeps[0].TIMESWEEPSTART
   unix2datetime, event_time2, yearN, monthN, dayN, hh_gv, mm_gv, ss_gv
   year = STRING(yearN-((yearN/100)*100), FORMAT='(i02)')
   month = STRING(monthN, FORMAT='(i02)')
   day = STRING(dayN, FORMAT='(i02)')

;  Need to include groundSite common in, or pass in siteID to, these
;  bad boys so that the headings in the products are not hard-wired
;  to Melbourne FL.

   common_area_1d,  S_1c21=s_pr0, S_2a25=s_pr, S_2a55=s_gv, $
                C_1c21=c_pr0, C_2a25=c_pr, C_2a55=c_gv, $
                T_1c21=t_pr0, T_2a25=t_pr, T_2a55=t_gv, $
                O_1c21=o_pr0, O_2a25=o_pr, O_2a55=o_gv, $ 
                L_1c21=l_pr0, L_2a25=l_pr, L_2a55=l_gv, $
                M_1c21=m_pr0, M_2a25=m_pr, M_2a55=m_gv 
               
   statistics_table,  Height=height, $
                      S_1c21=s_pr0, S_2a25=s_pr, S_2a55=s_gv, $
                      C_1c21=c_pr0, C_2a25=c_pr, C_2a55=c_gv, $
                      T_1c21=t_pr0, T_2a25=t_pr, T_2a55=t_gv, $
                      O_1c21=o_pr0, O_2a25=o_pr, O_2a55=o_gv, $ 
                      L_1c21=l_pr0, L_2a25=l_pr, L_2a55=l_gv, $
                      M_1c21=m_pr0, M_2a25=m_pr, M_2a55=m_gv
                      
   standardError_table, Height=height, LUN=lun_13, $
                      S_1c21=s_pr0, S_2a25=s_pr, S_2a55=s_gv, $
                      C_1c21=c_pr0, C_2a25=c_pr, C_2a55=c_gv, $
                      T_1c21=t_pr0, T_2a25=t_pr, T_2a55=t_gv, $
                      O_1c21=o_pr0, O_2a25=o_pr, O_2a55=o_gv, $ 
                      L_1c21=l_pr0, L_2a25=l_pr, L_2a55=l_gv, $
                      M_1c21=m_pr0, M_2a25=m_pr, M_2a55=m_gv
                                            
   bias_table, Height=height, LUN1=lun_14, LUN2=lun_15, LUN3=lun_16, $
                      S_1c21=s_pr0, S_2a25=s_pr, S_2a55=s_gv, $
                      C_1c21=c_pr0, C_2a25=c_pr, C_2a55=c_gv, $
                      T_1c21=t_pr0, T_2a25=t_pr, T_2a55=t_gv, $
                      O_1c21=o_pr0, O_2a25=o_pr, O_2a55=o_gv, $ 
                      L_1c21=l_pr0, L_2a25=l_pr, L_2a55=l_gv, $
                      M_1c21=m_pr0, M_2a25=m_pr, M_2a55=m_gv

nextFile:
endfor
endif

plot_scaPoint, "./results/dbzSca_h"+string(height,format='(f3.1)')+"."+siteID+".geo.ps", $
                siteID, Height=height
plot_histogram, "./results/dbz_histogram_h"+string(height,format='(f3.1)')+"."+siteID+".geo.ps", $
                 siteID, Height=height

CLOSE, lun_0  &   FREE_LUN, lun_0
CLOSE, lun_1  &   FREE_LUN, lun_1
CLOSE, lun_2  &   FREE_LUN, lun_2
CLOSE, lun_3  &   FREE_LUN, lun_3
CLOSE, lun_4  &   FREE_LUN, lun_4
CLOSE, lun_5  &   FREE_LUN, lun_5
CLOSE, lun_6  &   FREE_LUN, lun_6
CLOSE, lun_7  &   FREE_LUN, lun_7
CLOSE, lun_8  &   FREE_LUN, lun_8
CLOSE, lun_9  &   FREE_LUN, lun_9
CLOSE, lun_10  &   FREE_LUN, lun_10
CLOSE, lun_11  &   FREE_LUN, lun_11
CLOSE, lun_12  &   FREE_LUN, lun_12
CLOSE, lun_13  &   FREE_LUN, lun_13
CLOSE, lun_14  &   FREE_LUN, lun_14
CLOSE, lun_15  &   FREE_LUN, lun_15
CLOSE, lun_16  &   FREE_LUN, lun_16

endfor  ; Heights loop

errorExit:
end

@uncomp_file.pro
@read_pr_netcdf.pro
@read_gv_reo_netcdf.pro
@read_gv_netcdf.pro
@unix2datetime.pro
@common_area_1d.pro
@plot_scaPoint.pro
@plot_histogram.pro
@statistics_table.pro
@standardError_table.pro
@bias_table.pro
