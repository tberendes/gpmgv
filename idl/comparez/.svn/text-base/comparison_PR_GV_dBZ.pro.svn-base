;+
; Copyright © 2008, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; AUTHOR:
;       Liang Liao
;       Caelum Research Corp.
;       Code 975, NASA/GSFC
;       Greenbelt, MD 20771
;       Phone: 301-614-5718
;       E-mail: lliao@priam.gsfc.nasa.gov
; HISTORY
;       Bob Morris, SAIC, GPM GV
;       Massively rewritten to read from netCDF gridfiles, do any height specified,
;       any site specified, etc.  Called from doSiteSpecificComparisons.pro in a
;       site-by-site loop.  2A54 Rain Type not available if REORDER is used to
;       create the GV netCDF grids, so we fudge it for now by using a copy of the
;       2A23/2A25 Rain Type.
;
;       Bob Morris, SAIC, GPM GV    March 2008
;       Now calling utility functions read_PR_netcdf(), read_GV_netcdf(), and
;       read_GV_REO_netcdf() to read data/metadata fields from the netCDF files.
;
;
; It only works for PR v6. 
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-

pro comparison_PR_GV_dBZ, Height, npairs, prfile, gvfile

; "include" file for PR/GV netCDF grid structs, now that we call read_XX_netcdf()
@grid_nc_structs.inc
; instantiate and initialize the structs
mygridstruc={grid_def_meta}
mysitestruc={gv_site_meta}

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

DBZ_MIN = 15
DBZ_MAX = 55
TRMM_TIME = ''
NEXRAD_TIME = ''
dayN = 0l & monthN = 0l & yearN = 0l & hh_gv = 0l & mm_gv = 0l & ss_gv = 0l

;Height = 3.0   ; Altitude above ground (km)

CASE fix(Height*10) of
   15: nHeight = 0
   30: nHeight = 1
   45: nHeight = 2
   60: nHeight = 3
   75: nHeight = 4
   90: nHeight = 5
 ELSE: STOP
ENDCASE

common PR_GV, rainType_2a23, rainType_2a54, dbz_1c21, dbz_2a25, dbz_2a55, oceanFlag, $
              epsilon,epsilon_0
              

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


table_0 = "./results/stratiform_mean_std_h"+string(height,format='(f3.1)')+"."+siteID+".tab"
table_1 = "./results/convective_mean_std_h"+string(height,format='(f3.1)')+"."+siteID+".tab"
table_2 = "./results/total_mean_std_h"+string(height,format='(f3.1)')+"."+siteID+".tab"
table_3 = "./results/overOcean_mean_std_h"+string(height,format='(f3.1)')+"."+siteID+".tab"
table_4 = "./results/overLand_mean_std_h"+string(height,format='(f3.1)')+"."+siteID+".tab"
table_5 = "./results/overMixedWaterLand_mean_std_h"+string(height,format='(f3.1)')+"."+siteID+".tab"

table_6 = "./results/cumulation_stratiform_mean_std_h"+string(height,format='(f3.1)')+"."+siteID+".tab"
table_7 = "./results/cumulation_convective_mean_std_h"+string(height,format='(f3.1)')+"."+siteID+".tab"
table_8 = "./results/cumulation_total_mean_std_h"+string(height,format='(f3.1)')+"."+siteID+".tab"
table_9 = "./results/cumulation_overOcean_mean_std_h"+string(height,format='(f3.1)')+"."+siteID+".tab"
table_10 = "./results/cumulation_overLand_mean_std_h"+string(height,format='(f3.1)')+"."+siteID+".tab"
table_11 = "./results/cumulation_overMixedWaterLand_mean_std_h"+string(height,format='(f3.1)')+"."+siteID+".tab"

table_12 = "./results/rainType_agreement."+siteID+".tab"
table_13 = "./results/standardError_h"+string(height,format='(f3.1)')+"."+siteID+".tab"
table_14 = "./results/bias_h"+string(height,format='(f3.1)')+"_stratiform."+siteID+".tab"
table_15 = "./results/bias_h"+string(height,format='(f3.1)')+"_convective."+siteID+".tab"
table_16 = "./results/bias_h"+string(height,format='(f3.1)')+"_total."+siteID+".tab"

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
xdist = findgen(75,75)
xdist = ((xdist mod 75.) - 37.) * 4.
ydist = TRANSPOSE(xdist)
dist = SQRT(xdist*xdist + ydist*ydist)
idxdist_gt100 = where(dist gt 100.)

nfile = -1
for i=0, npairs-1 do begin

;  LOOP OVER EACH SITE'S FILES.  SKIP IF NO GV DATA FILE
   if (gvfile[i] eq 'no_GV_file') then begin
      print, "Skipping - No GV file for PR file ", prfile[i]
      CONTINUE
   endif
   nfile = nfile + 1                      ; for common block

;  get unzipped copy of the netCDF file pair in current working directory
   flag = uncomp_file(prfile[i],prfile_2do)
   if(flag ne 'OK') then begin
       print,flag
       stop
       CONTINUE
   endif

   flag = uncomp_file(gvfile[i],gvfile_2do)
   if(flag ne 'OK') then begin
       print,flag
       stop
       CONTINUE
   endif

; READ DATA AND DO Z COMPARISON

   status = 1       ; initialize to FAILED
   event_time=0.0D
   mygrid=mygridstruc
   mysite=mysitestruc
   dbzcor=fltarr(2)
   dbzraw=fltarr(2)
   oceanFlag=intarr(2)
   rainType_2a23=intarr(2)
   status = read_pr_netcdf( prfile_2do, dtime=event_time, gridmeta=mygrid, $
       sitemeta=mysite, dbzraw3d=dbzraw, dbz3d=dbzcor, $
       sfctype2d_int=oceanFlag, raintype2d_int=rainType_2a23 )
   command = "rm  " + prfile_2do
   spawn, command
   IF (status NE 0) THEN BEGIN
     print, "ERROR in reading PR netCDF file: ", prfile_2do
     command = "rm " + gvfile_2do
     spawn, command
     CONTINUE
   ENDIF
   siteLat = mysite.site_lat
   siteLong = mysite.site_lon

   status = 1       ; initialize to FAILED
   event_time2=0.0D
   mygrid=mygridstruc
   mysite=mysitestruc
   dbznex=fltarr(2)
; check for GV netCDF file type via name convention: *_REO* => REORDER
   gvreo = STRPOS( gvfile[i], "_REO" )
   if (gvreo ne -1) then begin
; query REORDER netCDF file variables
     status = read_gv_reo_netcdf(gvfile_2do, dtime=event_time2, dbz3d=dbznex)
     command = "rm  " + gvfile_2do
     spawn, command
     IF (status NE 0) THEN BEGIN
       print, "ERROR in reading GV REO netCDF file: ", gvfile_2do
       CONTINUE
     ENDIF
;     fudge the 2A54 rain type for REORDER grids
      rainType_2a54 = rainType_2a23
   endif else begin
; query 2A-5x netCDF file variables
     rainType_2a54=intarr(2)
     status = read_gv_netcdf( gvfile_2do, dtime=event_time2, gridmeta=mygrid, $
         sitemeta=mysite, dbz3d=dbznex, raintype2d_int=rainType_2a54 )
     command = "rm  " + gvfile_2do
     spawn, command
     IF (status NE 0) THEN BEGIN
       print, "ERROR in reading GV netCDF file: ", gvfile_2do
       CONTINUE
     ENDIF
   endelse

   ; grab the Z data for the selected Height level.  THIS IS WHERE WE WOULD DO ANY
   ; ALINGMENT OF REFLECTIVITY DATA BETWEEN pr AND gv ARRAYS.  MAKE IT A CALL TO A
   ; SEPARATE ALIGNMENT PROCEDURE.  ALIGN dbznex TO dbzcor.
   dbz_1c21 = dbzraw[*,*,nHeight]
   dbz_2a25 = dbzcor[*,*,nHeight]
   dbz_2a55 = dbznex[*,*,nHeight]

   ; set the Z values beyond 100km range to a missing value so they will be
   ; ignored in the comparisons
   dbz_1c21[idxdist_gt100] = -77.
   dbz_2a25[idxdist_gt100] = -77.
   dbz_2a55[idxdist_gt100] = -77.

   ; scale the oceanFlag as commonArea expects
   oceanFlag = oceanFlag * 10

   TRMM_DATETIME = SYSTIME(0, event_time, /UTC)  ; e.g., Thu Jan  1 00:01:00 1970
   timeparts=strsplit(TRMM_DATETIME, '  *', /extract)
   TRMM_TIME=timeparts[3]                    ; i.e., the HH:MM:SS field
   NEXRAD_TIME = SYSTIME(0, event_time2, /UTC)
   unix2datetime, event_time2, yearN, monthN, dayN, hh_gv, mm_gv, ss_gv
   year = STRING(yearN-((yearN/100)*100), FORMAT='(i02)')
   month = STRING(monthN, FORMAT='(i02)')
   day = STRING(dayN, FORMAT='(i02)')

;  Need to include groundSite common in, or pass in siteID to, these
;  bad boys so that the headings in the products are not hard-wired
;  to Melbourne FL.

   commonArea,  S_1c21=s_pr0, S_2a25=s_pr, S_2a55=s_gv, $
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
                      
endfor

plot_scaPoint, "./results/dbzSca_h"+string(height,format='(f3.1)')+"."+siteID+".ps", $
                siteID, Height=height
plot_histogram, "./results/dbz_histogram_h"+string(height,format='(f3.1)')+"."+siteID+".ps", $
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
 
end

@uncomp_file.pro
@read_pr_netcdf.pro
@read_gv_reo_netcdf.pro
@read_gv_netcdf.pro
@unix2datetime.pro
@commonArea.pro
;@remove_path.pro
@plot_scaPoint.pro
@plot_histogram.pro
@statistics_table.pro
@standardError_table.pro
@bias_table.pro
