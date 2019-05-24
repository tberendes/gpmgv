;+
; Copyright © 2008, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; DESCRIPTION:
;       Produces stratified, tabular summaries of computed bias statistics
;       between TRMM PR reflectivity data and its ground radar counterpoint.
;       Writes output to supplied (via common) LUNs.
;
; AUTHOR:
;       Liang Liao
;       Caelum Research Corp.
;       Code 975, NASA/GSFC
;       Greenbelt, MD 20771
;       Phone: 301-614-5718
;       E-mail: lliao@priam.gsfc.nasa.gov
;
; HISTORY:
;       Bob Morris/GPM GV (SAIC), dates various
;       - Added titleing flexibility to allow any site's data to be tabulated
;         with correct labeling.
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-

pro statistics_table, Height=height, $
                      S_1c21=s_pr0, S_2a25=s_pr, S_2a55=s_gv, $
                      C_1c21=c_pr0, C_2a25=c_pr, C_2a55=c_gv, $
                      T_1c21=t_pr0, T_2a25=t_pr, T_2a55=t_gv, $
                      O_1c21=o_pr0, O_2a25=o_pr, O_2a55=o_gv, $ 
                      L_1c21=l_pr0, L_2a25=l_pr, L_2a55=l_gv, $
                      M_1c21=m_pr0, M_2a25=m_pr, M_2a55=m_gv
                
common time, TRMM_TIME, hh_gv, mm_gv, ss_gv, year, month, day
common groundSite, siteLong, siteLat, siteID
common nfile_record, nfile
common cumulation, s_npt, c_npt, t_npt, o_npt, l_npt, m_npt, $
                   s_pr0_tot, s_pr_tot, s_gv_tot, c_pr0_tot, c_pr_tot, c_gv_tot, $
                   t_pr0_tot, t_pr_tot, t_gv_tot, o_pr0_tot, o_pr_tot, o_gv_tot, $
                   l_pr0_tot, l_pr_tot, l_gv_tot, m_pr0_tot, m_pr_tot, m_gv_tot

;log_flag = 1  ; if not commented, non-linear process of 'mean_std' is performed.

mean_std, LOG=log_flag, s_pr0, MEAN=mean_s_pr0, STD=std_s_pr0
mean_std, LOG=log_flag, s_pr, MEAN=mean_s_pr, STD=std_s_pr
mean_std, LOG=log_flag, s_gv, MEAN=mean_s_gv, STD=std_s_gv

mean_std, LOG=log_flag, c_pr0, MEAN=mean_c_pr0, STD=std_c_pr0
mean_std, LOG=log_flag, c_pr, MEAN=mean_c_pr, STD=std_c_pr
mean_std, LOG=log_flag, c_gv, MEAN=mean_c_gv, STD=std_c_gv

mean_std, LOG=log_flag, t_pr0, MEAN=mean_t_pr0, STD=std_t_pr0
mean_std, LOG=log_flag, t_pr, MEAN=mean_t_pr, STD=std_t_pr
mean_std, LOG=log_flag, t_gv, MEAN=mean_t_gv, STD=std_t_gv

mean_std, LOG=log_flag, o_pr0, MEAN=mean_o_pr0, STD=std_o_pr0
mean_std, LOG=log_flag, o_pr, MEAN=mean_o_pr, STD=std_o_pr
mean_std, LOG=log_flag, o_gv, MEAN=mean_o_gv, STD=std_o_gv

mean_std, LOG=log_flag, l_pr0, MEAN=mean_l_pr0, STD=std_l_pr0
mean_std, LOG=log_flag, l_pr, MEAN=mean_l_pr, STD=std_l_pr
mean_std, LOG=log_flag, l_gv, MEAN=mean_l_gv, STD=std_l_gv

mean_std, LOG=log_flag, m_pr0, MEAN=mean_m_pr0, STD=std_m_pr0
mean_std, LOG=log_flag, m_pr, MEAN=mean_m_pr, STD=std_m_pr
mean_std, LOG=log_flag, m_gv, MEAN=mean_m_gv, STD=std_m_gv

if s_npt eq 0 then begin
   mean_s_pr0_tot=0.
   mean_s_pr_tot=0.
   mean_s_gv_tot=0.
   std_s_pr0_tot=0.
   std_s_pr_tot=0.
   std_s_gv_tot=0.
endif else begin
   mean_std, LOG=log_flag, s_pr0_tot[0:s_npt-1], MEAN=mean_s_pr0_tot, STD=std_s_pr0_tot
   mean_std, LOG=log_flag, s_pr_tot[0:s_npt-1], MEAN=mean_s_pr_tot, STD=std_s_pr_tot
   mean_std, LOG=log_flag, s_gv_tot[0:s_npt-1], MEAN=mean_s_gv_tot, STD=std_s_gv_tot
endelse

if c_npt eq 0 then begin
   mean_c_pr0_tot=0.
   mean_c_pr_tot=0.
   mean_c_gv_tot=0.
   std_c_pr0_tot=0.
   std_c_pr_tot=0.
   std_c_gv_tot=0.
endif else begin
   mean_std, LOG=log_flag, c_pr0_tot[0:c_npt-1], MEAN=mean_c_pr0_tot, STD=std_c_pr0_tot
   mean_std, LOG=log_flag, c_pr_tot[0:c_npt-1], MEAN=mean_c_pr_tot, STD=std_c_pr_tot
   mean_std, LOG=log_flag, c_gv_tot[0:c_npt-1], MEAN=mean_c_gv_tot, STD=std_c_gv_tot
endelse

if t_npt eq 0 then begin
   mean_t_pr0_tot=0.
   mean_t_pr_tot=0.
   mean_t_gv_tot=0.
   std_t_pr0_tot=0.
   std_t_pr_tot=0.
   std_t_gv_tot=0.
endif else begin
   mean_std, LOG=log_flag, t_pr0_tot[0:t_npt-1], MEAN=mean_t_pr0_tot, STD=std_t_pr0_tot
   mean_std, LOG=log_flag, t_pr_tot[0:t_npt-1], MEAN=mean_t_pr_tot, STD=std_t_pr_tot
   mean_std, LOG=log_flag, t_gv_tot[0:t_npt-1], MEAN=mean_t_gv_tot, STD=std_t_gv_tot
endelse   

if o_npt eq 0 then begin
   mean_o_pr0_tot=0.
   mean_o_pr_tot=0.
   mean_o_gv_tot=0.
   std_o_pr0_tot=0.
   std_o_pr_tot=0.
   std_o_gv_tot=0.
endif else begin
   mean_std, LOG=log_flag, o_pr0_tot[0:o_npt-1], MEAN=mean_o_pr0_tot, STD=std_o_pr0_tot
   mean_std, LOG=log_flag, o_pr_tot[0:o_npt-1], MEAN=mean_o_pr_tot, STD=std_o_pr_tot
   mean_std, LOG=log_flag, o_gv_tot[0:o_npt-1], MEAN=mean_o_gv_tot, STD=std_o_gv_tot
endelse   

if l_npt eq 0 then begin
   mean_l_pr0_tot=0.
   mean_l_pr_tot=0.
   mean_l_gv_tot=0.
   std_l_pr0_tot=0.
   std_l_pr_tot=0.
   std_l_gv_tot=0.
endif else begin
   mean_std, LOG=log_flag, l_pr0_tot[0:l_npt-1], MEAN=mean_l_pr0_tot, STD=std_l_pr0_tot
   mean_std, LOG=log_flag, l_pr_tot[0:l_npt-1], MEAN=mean_l_pr_tot, STD=std_l_pr_tot
   mean_std, LOG=log_flag, l_gv_tot[0:l_npt-1], MEAN=mean_l_gv_tot, STD=std_l_gv_tot
endelse   

if m_npt eq 0 then begin
   mean_m_pr0_tot=0.
   mean_m_pr_tot=0.
   mean_m_gv_tot=0.
   std_m_pr0_tot=0.
   std_m_pr_tot=0.
   std_m_gv_tot=0.
endif else begin
   mean_std, LOG=log_flag, m_pr0_tot[0:m_npt-1], MEAN=mean_m_pr0_tot, STD=std_m_pr0_tot
   mean_std, LOG=log_flag, m_pr_tot[0:m_npt-1], MEAN=mean_m_pr_tot, STD=std_m_pr_tot
   mean_std, LOG=log_flag, m_gv_tot[0:m_npt-1], MEAN=mean_m_gv_tot, STD=std_m_gv_tot
endelse   


date=month+'/'+day+'/'+year

zero=""+string(0,format='(i1)')+""
;help,hh_gv, trmm_time, year, month, day, date
if hh_gv lt 10 then hrs_gv = zero+""+string(hh_gv,format='(i1)')+""
if hh_gv ge 10 then hrs_gv = ""+string(hh_gv,format='(i2)')+""

if mm_gv lt 10 then min_gv = zero+""+string(mm_gv,format='(i1)')+""
if mm_gv ge 10 then min_gv = ""+string(mm_gv,format='(i2)')+""

if ss_gv lt 10 then sec_gv = zero+""+string(ss_gv,format='(i1)')+""
if ss_gv ge 10 then sec_gv = ""+string(ss_gv,format='(i2)')+""

gv_time=hrs_gv+':'+min_gv+':'+sec_gv

common lun, lun_0, lun_1, lun_2, lun_3, lun_4, lun_5, lun_6, lun_7, lun_8, lun_9, lun_10, lun_11

if nfile eq 0 then begin
  PRINTF, lun_0, siteID, format='(6x,18x,"Statistical Results of Radar Reflectivities of TRMM PR and ",a0," GV")'
  PRINTF, lun_0, height, format='(6x,33x,"Rain Type = Stratiform, Height = ",f4.1," km")'
  PRINTF, lun_0, format='(6x,"_____________________________________________________________________________________________________________")'
  PRINTF, lun_0, '  '  &  PRINTF, lun_0, '  '
  PRINTF, lun_0, format='(6x,3x,4hDATE,6x,8hTIME(PR),4x,8hTIME(GV),7x,"MEAN(PR*,PR,GV)",11x,"STD(PR*,PR,GV)",6x,"CORR(PR*/PR-GV)",5x,"NPT")'
  PRINTF, lun_0, format='(6x,1x,"________",4x,"________",4x,"________",4x,"_____________________",4x,"_____________________",4x,"_____________",5x,"____")'
endif

nPoint = SIZE(s_pr,/dimension)  &  if nPoint[0] eq 1 then nPoint[0]=0
PRINTF, lun_0, date, trmm_time, gv_time, mean_s_pr0, mean_s_pr, mean_s_gv, $
        std_s_pr0, std_s_pr, std_s_gv, correlate(s_pr0,s_gv), correlate(s_pr,s_gv), nPoint, $
        format='(6x,1x,a8,4x,a8,4x,a8,4x,3(f5.2,3x),1x,3(f5.2,3x),1x,2(f5.3,3x),2x,i4)'
        
; -----------------------
        
if nfile eq 0 then begin
  PRINTF, lun_1, siteID, format='(6x,18x,"Statistical Results of Radar Reflectivities of TRMM PR and ",a0," GV")'
  PRINTF, lun_1, height, format='(6x,33x,"Rain Type = Convective, Height = ",f4.1," km")'
  PRINTF, lun_1, format='(6x,"_____________________________________________________________________________________________________________")'
  PRINTF, lun_1, '  ', '  '  &  PRINTF, lun_1, '  '
  PRINTF, lun_1, format='(6x,3x,4hDATE,6x,8hTIME(PR),4x,8hTIME(GV),7x,"MEAN(PR*,PR,GV)",11x,"STD(PR*,PR,GV)",6x,"CORR(PR*/PR-GV)",5x,"NPT")'
  PRINTF, lun_1, format='(6x,1x,"________",4x,"________",4x,"________",4x,"_____________________",4x,"_____________________",4x,"_____________",5x,"____")'
endif

nPoint = SIZE(c_pr,/dimension)  &  if nPoint[0] eq 1 then nPoint[0]=0
PRINTF, lun_1, date, trmm_time, gv_time, mean_c_pr0, mean_c_pr, mean_c_gv, $
        std_c_pr0, std_c_pr, std_c_gv, correlate(c_pr0,c_gv), correlate(c_pr,c_gv), nPoint, $
        format='(6x,1x,a8,4x,a8,4x,a8,4x,3(f5.2,3x),1x,3(f5.2,3x),1x,2(f5.3,3x),2x,i4)'
        
; -----------------------
        
        
if nfile eq 0 then begin
  PRINTF, lun_2, siteID, format='(6x,18x,"Statistical Results of Radar Reflectivities of TRMM PR and ",a0," GV")'
  PRINTF, lun_2, height, format='(6x,45x,"Height = ",f4.1," km")'
  PRINTF, lun_2, format='(6x,"_____________________________________________________________________________________________________________")'
  PRINTF, lun_2, '  ', '  '  &  PRINTF, lun_2, '  '
  PRINTF, lun_2, format='(6x,3x,4hDATE,6x,8hTIME(PR),4x,8hTIME(GV),7x,"MEAN(PR*,PR,GV)",11x,"STD(PR*,PR,GV)",6x,"CORR(PR*/PR-GV)",5x,"NPT")'
  PRINTF, lun_2, format='(6x,1x,"________",4x,"________",4x,"________",4x,"_____________________",4x,"_____________________",4x,"_____________",5x,"____")'
endif

nPoint = SIZE(t_pr,/dimension)  &  if nPoint[0] eq 1 then nPoint[0]=0
PRINTF, lun_2, date, trmm_time, gv_time, mean_t_pr0, mean_t_pr, mean_t_gv, $
        std_t_pr0, std_t_pr, std_t_gv, correlate(t_pr0,t_gv), correlate(t_pr,t_gv), nPoint, $
        format='(6x,1x,a8,4x,a8,4x,a8,4x,3(f5.2,3x),1x,3(f5.2,3x),1x,2(f5.3,3x),2x,i4)'
        
; -----------------------

if nfile eq 0 then begin
  PRINTF, lun_3, siteID, format='(6x,18x,"Statistical Results of Radar Reflectivities of TRMM PR and ",a0," GV")'
  PRINTF, lun_3, height, format='(6x,40x,"over Ocean, Height = ",f4.1," km")'
  PRINTF, lun_3, format='(6x,"_____________________________________________________________________________________________________________")'
  PRINTF, lun_3, '  ', '  '  &  PRINTF, lun_3, '  '
  PRINTF, lun_3, format='(6x,3x,4hDATE,6x,8hTIME(PR),4x,8hTIME(GV),7x,"MEAN(PR*,PR,GV)",11x,"STD(PR*,PR,GV)",6x,"CORR(PR*/PR-GV)",5x,"NPT")'
  PRINTF, lun_3, format='(6x,1x,"________",4x,"________",4x,"________",4x,"_____________________",4x,"_____________________",4x,"_____________",5x,"____")'
endif

nPoint = SIZE(o_pr,/dimension)  &  if nPoint[0] eq 1 then nPoint[0]=0
PRINTF, lun_3, date, trmm_time, gv_time, mean_o_pr0, mean_o_pr, mean_o_gv, $
        std_o_pr0, std_o_pr, std_o_gv, correlate(o_pr0,o_gv), correlate(o_pr,o_gv), nPoint, $
        format='(6x,1x,a8,4x,a8,4x,a8,4x,3(f5.2,3x),1x,3(f5.2,3x),1x,2(f5.3,3x),2x,i4)'
        
; -----------------------

if nfile eq 0 then begin
  PRINTF, lun_4, siteID, format='(6x,18x,"Statistical Results of Radar Reflectivities of TRMM PR and ",a0," GV")'
  PRINTF, lun_4, height, format='(6x,40x,"over Land, Height = ",f4.1," km")'
  PRINTF, lun_4, format='(6x,"_____________________________________________________________________________________________________________")'
  PRINTF, lun_4, '  ', '  '  &  PRINTF, lun_4, '  '
  PRINTF, lun_4, format='(6x,3x,4hDATE,6x,8hTIME(PR),4x,8hTIME(GV),7x,"MEAN(PR*,PR,GV)",11x,"STD(PR*,PR,GV)",6x,"CORR(PR*/PR-GV)",5x,"NPT")'
  PRINTF, lun_4, format='(6x,1x,"________",4x,"________",4x,"________",4x,"_____________________",4x,"_____________________",4x,"_____________",5x,"____")'
endif

nPoint = SIZE(l_pr,/dimension)  &  if nPoint[0] eq 1 then nPoint[0]=0
PRINTF, lun_4, date, trmm_time, gv_time, mean_l_pr0, mean_l_pr, mean_l_gv, $
        std_l_pr0, std_l_pr, std_l_gv, correlate(l_pr0,l_gv), correlate(l_pr,l_gv), nPoint, $
        format='(6x,1x,a8,4x,a8,4x,a8,4x,3(f5.2,3x),1x,3(f5.2,3x),1x,2(f5.3,3x),2x,i4)'
        
; -----------------------

if nfile eq 0 then begin
  PRINTF, lun_5, siteID, format='(6x,18x,"Statistical Results of Radar Reflectivities of TRMM PR and ",a0," GV")'
  PRINTF, lun_5, height, format='(6x,36x,"over Mixed Surface, Height = ",f4.1," km")'
  PRINTF, lun_5, format='(6x,"_____________________________________________________________________________________________________________")'
  PRINTF, lun_5, '  ', '  '  &  PRINTF, lun_5, '  '
  PRINTF, lun_5, format='(6x,3x,4hDATE,6x,8hTIME(PR),4x,8hTIME(GV),7x,"MEAN(PR*,PR,GV)",11x,"STD(PR*,PR,GV)",6x,"CORR(PR*/PR-GV)",5x,"NPT")'
  PRINTF, lun_5, format='(6x,1x,"________",4x,"________",4x,"________",4x,"_____________________",4x,"_____________________",4x,"_____________",5x,"____")'
endif

nPoint = SIZE(m_pr,/dimension)  &  if nPoint[0] eq 1 then nPoint[0]=0  
PRINTF, lun_5, date, trmm_time, gv_time, mean_m_pr0, mean_m_pr, mean_m_gv, $
        std_m_pr0, std_m_pr, std_m_gv, correlate(m_pr0,m_gv), correlate(m_pr,m_gv), nPoint, $
        format='(6x,1x,a8,4x,a8,4x,a8,4x,3(f5.2,3x),1x,3(f5.2,3x),1x,2(f5.3,3x),2x,i4)'
        
; -----------------------


;*****************************************

if nfile eq 0 then begin
  PRINTF, lun_6, siteID, format='(6x,18x,"Statistical Results of Radar Reflectivities of TRMM PR and ",a0," GV")'
  PRINTF, lun_6, height, format='(6x,33x,"Rain Type = Stratiform, Height = ",f4.1," km")'
  PRINTF, lun_6, format='(6x,43x,"(Cumulative Results)")'
  PRINTF, lun_6, format='(6x,"_____________________________________________________________________________________________________________")'
  PRINTF, lun_6, '  ', '  '  &  PRINTF, lun_6, '  '
  PRINTF, lun_6, format='(6x,3x,4hDATE,6x,8hTIME(PR),4x,8hTIME(GV),7x,"MEAN(PR*,PR,GV)",11x,"STD(PR*,PR,GV)",6x,"CORR(PR*/PR-GV)",5x,"NPT")'
  PRINTF, lun_6, format='(6x,1x,"________",4x,"________",4x,"________",4x,"_____________________",4x,"_____________________",4x,"_____________",5x,"_____")'
endif

if s_npt eq 0 then s_npt=1
PRINTF, lun_6, date, trmm_time, gv_time, mean_s_pr0_tot, mean_s_pr_tot, mean_s_gv_tot, std_s_pr0_tot, std_s_pr_tot, $
        std_s_gv_tot, correlate(s_pr0_tot[0:s_npt-1],s_gv_tot[0:s_npt-1]), correlate(s_pr_tot[0:s_npt-1],s_gv_tot[0:s_npt-1]), s_npt, $
        format='(6x,1x,a8,4x,a8,4x,a8,4x,3(f5.2,3x),1x,3(f5.2,3x),1x,2(f5.3,3x),2x,i5)'
        
; -----------------------
        
if nfile eq 0 then begin
  PRINTF, lun_7, siteID, format='(6x,18x,"Statistical Results of Radar Reflectivities of TRMM PR and ",a0," GV")'
  PRINTF, lun_7, height, format='(6x,33x,"Rain Type = Convective, Height = ",f4.1," km")'
  PRINTF, lun_7, format='(6x,43x,"(Cumulative Results)")'
  PRINTF, lun_7, format='(6x,"_____________________________________________________________________________________________________________")'
  PRINTF, lun_7, '  ', '  '  &  PRINTF, lun_7, '  '
  PRINTF, lun_7, format='(6x,3x,4hDATE,6x,8hTIME(PR),4x,8hTIME(GV),7x,"MEAN(PR*,PR,GV)",11x,"STD(PR*,PR,GV)",6x,"CORR(PR*/PR-GV)",5x,"NPT")'
  PRINTF, lun_7, format='(6x,1x,"________",4x,"________",4x,"________",4x,"_____________________",4x,"_____________________",4x,"_____________",5x,"_____")'
endif

if c_npt eq 0 then c_npt=1
PRINTF, lun_7, date, trmm_time, gv_time, mean_c_pr0_tot, mean_c_pr_tot, mean_c_gv_tot, std_c_pr0_tot, std_c_pr_tot, $
        std_c_gv_tot, correlate(c_pr0_tot[0:c_npt-1],c_gv_tot[0:c_npt-1]), correlate(c_pr_tot[0:c_npt-1],c_gv_tot[0:c_npt-1]), c_npt, $
        format='(6x,1x,a8,4x,a8,4x,a8,4x,3(f5.2,3x),1x,3(f5.2,3x),1x,2(f5.3,3x),2x,i5)'
        
; -----------------------
        
        
if nfile eq 0 then begin
  PRINTF, lun_8, siteID, format='(6x,18x,"Statistical Results of Radar Reflectivities of TRMM PR and ",a0," GV")'
  PRINTF, lun_8, height, format='(6x,45x,"Height = ",f4.1," km")'
  PRINTF, lun_8, format='(6x,43x,"(Cumulative Results)")'
  PRINTF, lun_8, format='(6x,"_____________________________________________________________________________________________________________")'
  PRINTF, lun_8, '  ', '  '  &  PRINTF, lun_8, '  '
  PRINTF, lun_8, format='(6x,3x,4hDATE,6x,8hTIME(PR),4x,8hTIME(GV),7x,"MEAN(PR*,PR,GV)",11x,"STD(PR*,PR,GV)",6x,"CORR(PR*/PR-GV)",5x,"NPT")'
  PRINTF, lun_8, format='(6x,1x,"________",4x,"________",4x,"________",4x,"_____________________",4x,"_____________________",4x,"_____________",5x,"_____")'
endif

if t_npt eq 0 then t_npt=1
PRINTF, lun_8, date, trmm_time, gv_time, mean_t_pr0_tot, mean_t_pr_tot, mean_t_gv_tot, std_t_pr0_tot, std_t_pr_tot, $
        std_t_gv_tot, correlate(t_pr0_tot[0:t_npt-1],t_gv_tot[0:t_npt-1]), correlate(t_pr_tot[0:t_npt-1],t_gv_tot[0:t_npt-1]), t_npt, $
        format='(6x,1x,a8,4x,a8,4x,a8,4x,3(f5.2,3x),1x,3(f5.2,3x),1x,2(f5.3,3x),2x,i5)'
        
; -----------------------

if nfile eq 0 then begin
  PRINTF, lun_9, siteID, format='(6x,18x,"Statistical Results of Radar Reflectivities of TRMM PR and ",a0," GV")'
  PRINTF, lun_9, height, format='(6x,40x,"over Ocean, Height = ",f4.1," km")'
  PRINTF, lun_9, format='(6x,43x,"(Cumulative Results)")'
  PRINTF, lun_9, format='(6x,"_____________________________________________________________________________________________________________")'
  PRINTF, lun_9, '  ', '  '  &  PRINTF, lun_9, '  '
  PRINTF, lun_9, format='(6x,3x,4hDATE,6x,8hTIME(PR),4x,8hTIME(GV),7x,"MEAN(PR*,PR,GV)",11x,"STD(PR*,PR,GV)",6x,"CORR(PR*/PR-GV)",5x,"NPT")'
  PRINTF, lun_9, format='(6x,1x,"________",4x,"________",4x,"________",4x,"_____________________",4x,"_____________________",4x,"_____________",5x,"_____")'
endif

if o_npt eq 0 then o_npt=1
PRINTF, lun_9, date, trmm_time, gv_time, mean_o_pr0_tot, mean_o_pr_tot, mean_o_gv_tot, std_o_pr0_tot, std_o_pr_tot, $
        std_o_gv_tot, correlate(o_pr0_tot[0:o_npt-1],o_gv_tot[0:o_npt-1]), correlate(o_pr_tot[0:o_npt-1],o_gv_tot[0:o_npt-1]), o_npt, $
        format='(6x,1x,a8,4x,a8,4x,a8,4x,3(f5.2,3x),1x,3(f5.2,3x),1x,2(f5.3,3x),2x,i5)'
        
; -----------------------

if nfile eq 0 then begin
  PRINTF, lun_10, siteID, format='(6x,18x,"Statistical Results of Radar Reflectivities of TRMM PR and ",a0," GV")'
  PRINTF, lun_10, height, format='(6x,40x,"over Land, Height = ",f4.1," km")'
  PRINTF, lun_10, format='(6x,43x,"(Cumulative Results)")'
  PRINTF, lun_10, format='(6x,"_____________________________________________________________________________________________________________")'
  PRINTF, lun_10, '  ', '  '  &  PRINTF, lun_10, '  '
  PRINTF, lun_10, format='(6x,3x,4hDATE,6x,8hTIME(PR),4x,8hTIME(GV),7x,"MEAN(PR*,PR,GV)",11x,"STD(PR*,PR,GV)",6x,"CORR(PR*/PR-GV)",5x,"NPT")'
  PRINTF, lun_10, format='(6x,1x,"________",4x,"________",4x,"________",4x,"_____________________",4x,"_____________________",4x,"_____________",5x,"_____")'
endif

if l_npt eq 0 then l_npt=1
PRINTF, lun_10, date, trmm_time, gv_time, mean_l_pr0_tot, mean_l_pr_tot, mean_l_gv_tot, std_l_pr0_tot, std_l_pr_tot, $
        std_l_gv_tot, correlate(l_pr0_tot[0:l_npt-1],l_gv_tot[0:l_npt-1]), correlate(l_pr_tot[0:l_npt-1],l_gv_tot[0:l_npt-1]), l_npt, $
        format='(6x,1x,a8,4x,a8,4x,a8,4x,3(f5.2,3x),1x,3(f5.2,3x),1x,2(f5.3,3x),2x,i5)'
        
; -----------------------

if nfile eq 0 then begin
  PRINTF, lun_11, siteID, format='(6x,18x,"Statistical Results of Radar Reflectivities of TRMM PR and ",a0," GV")'
  PRINTF, lun_11, height, format='(6x,36x,"over Mixed Surface, Height = ",f4.1," km")'
  PRINTF, lun_11, format='(6x,43x,"(Cumulative Results)")'
  PRINTF, lun_11, format='(6x,"_____________________________________________________________________________________________________________")'
  PRINTF, lun_11, '  ', '  '  &  PRINTF, lun_11, '  '
  PRINTF, lun_11, format='(6x,3x,4hDATE,6x,8hTIME(PR),4x,8hTIME(GV),7x,"MEAN(PR*,PR,GV)",11x,"STD(PR*,PR,GV)",6x,"CORR(PR*/PR-GV)",5x,"NPT")'
  PRINTF, lun_11, format='(6x,1x,"________",4x,"________",4x,"________",4x,"_____________________",4x,"_____________________",4x,"_____________",5x,"_____")'
endif

if m_npt eq 0 then m_npt=1
PRINTF, lun_11, date, trmm_time, gv_time, mean_m_pr0_tot, mean_m_pr_tot, mean_m_gv_tot, std_m_pr0_tot, std_m_pr_tot, $
        std_m_gv_tot, correlate(m_pr0_tot[0:m_npt-1],m_gv_tot[0:m_npt-1]), correlate(m_pr_tot[0:m_npt-1],m_gv_tot[0:m_npt-1]), m_npt, $
        format='(6x,1x,a8,4x,a8,4x,a8,4x,3(f5.2,3x),1x,3(f5.2,3x),1x,2(f5.3,3x),2x,i5)'
        
; -----------------------


        
end
                   
