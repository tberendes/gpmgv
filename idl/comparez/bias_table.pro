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
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-

pro bias_table, Height=height, LUN1=lun1, LUN2=lun2, LUN3=lun3, $
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

dbz_min=[10., 20., 30., 40., 50.]
dbz_max=[20., 30., 40., 50., 100.]

bias, s_gv, s_pr, BIAS=bias_s, $
      MIN=dbz_min, MAX=dbz_max, STD_SET=bias_set_s, nPoint_SET=nCount_set_s

bias, c_gv, c_pr, BIAS=bias_c, $
      MIN=dbz_min, MAX=dbz_max, STD_SET=bias_set_c, nPoint_SET=nCount_set_c

bias, t_gv, t_pr, BIAS=bias_t, $
      MIN=dbz_min, MAX=dbz_max, STD_SET=bias_set_t, nPoint_SET=nCount_set_t

bias, s_gv_tot[0:s_npt-1], s_pr_tot[0:s_npt-1], BIAS=bias_s_tot, $
      MIN=dbz_min, MAX=dbz_max, STD_SET=bias_set_s_tot, nPoint_SET=nCount_set_tot_s

bias, c_gv_tot[0:c_npt-1], c_pr_tot[0:c_npt-1], BIAS=bias_c_tot, $
      MIN=dbz_min, MAX=dbz_max, STD_SET=bias_set_c_tot, nPoint_SET=nCount_set_tot_c

bias, t_gv_tot[0:t_npt-1], t_pr_tot[0:t_npt-1], BIAS=bias_t_tot, $
      MIN=dbz_min, MAX=dbz_max, STD_SET=bias_set_t_tot, nPoint_SET=nCount_set_tot_t

date=month+'/'+day+'/'+year

zero=""+string(0,format='(i1)')+""
 
if hh_gv lt 10 then hrs_gv = zero+""+string(hh_gv,format='(i1)')+""
if hh_gv ge 10 then hrs_gv = ""+string(hh_gv,format='(i2)')+""

if mm_gv lt 10 then min_gv = zero+""+string(mm_gv,format='(i1)')+""
if mm_gv ge 10 then min_gv = ""+string(mm_gv,format='(i2)')+""

if ss_gv lt 10 then sec_gv = zero+""+string(ss_gv,format='(i1)')+""
if ss_gv ge 10 then sec_gv = ""+string(ss_gv,format='(i2)')+""

gv_time=hrs_gv+':'+min_gv+':'+sec_gv

if nfile eq 0 then begin

  PRINTF, lun1, format='(//)'
  PRINTF, lun1, siteID, format='(5x,5x,"Mean Differences of the PR and ",a0," Radar Reflectivities")'
  PRINTF, lun1, height, format='(5x,11x,"PR Rain Type = Stratiform, Height = ",f4.1," km")'
  PRINTF, lun1, format='(5x,"_____________________________________________________________________")'
  PRINTF, lun1, format='(//)'
  PRINTF, lun1, format='(6x,3x,4hDATE,6x,"10-20",3x,"20-30",3x,"30-40",3x,"40-50",3x," >50 ",3x," >10 ",4x,"NPT")'
  PRINTF, lun1, format='(6x,1x,"________",4x,"_____",3x,"_____",3x,"_____",3x,"_____",3x,"_____",3x,"_____",3x,"_____")'

  PRINTF, lun2, format='(//)'
  PRINTF, lun2, siteID, format='(5x,5x,"Mean Differences of the PR and ",a0," Radar Reflectivities")'
  PRINTF, lun2, height, format='(5x,11x,"PR Rain Type = Convective, Height = ",f4.1," km")'
  PRINTF, lun2, format='(5x,"_____________________________________________________________________")'
  PRINTF, lun2, format='(//)'
  PRINTF, lun2, format='(6x,3x,4hDATE,6x,"10-20",3x,"20-30",3x,"30-40",3x,"40-50",3x," >50 ",3x," >10 ",4x,"NPT")'
  PRINTF, lun2, format='(6x,1x,"________",4x,"_____",3x,"_____",3x,"_____",3x,"_____",3x,"_____",3x,"_____",3x,"_____")'
  
  PRINTF, lun3, format='(//)'
  PRINTF, lun3, siteID, format='(5x,5x,"Mean Differences of the PR and ",a0," Radar Reflectivities")'
  PRINTF, lun3, height, format='(5x,12x,"PR Rain Type = Either, Height = ",f4.1," km")'
  PRINTF, lun3, format='(5x,"_____________________________________________________________________")'
  PRINTF, lun3, format='(//)'
  PRINTF, lun3, format='(6x,3x,4hDATE,6x,"10-20",3x,"20-30",3x,"30-40",3x,"40-50",3x," >50 ",3x," >10 ",4x,"NPT")'
  PRINTF, lun3, format='(6x,1x,"________",4x,"_____",3x,"_____",3x,"_____",3x,"_____",3x,"_____",3x,"_____",3x,"_____")'

endif

nPoint = SIZE(s_pr,/dimension)  &  if nPoint[0] eq 1 then nPoint[0]=0 
PRINTF, lun1, date, bias_set_s, bias_s, nPoint, $
        format='(6x,1x,a8,4x,6(f5.2,3x),1x,i4)'
;PRINTF, lun1, nCount_set_s, $
;        format='(6x,1x,8x,4x,5(1x,i4,3x),2x)'        
;PRINTF, lun1, ' '

nPoint = SIZE(c_pr,/dimension)  &  if nPoint[0] eq 1 then nPoint[0]=0 
PRINTF, lun2, date, bias_set_c, bias_c, nPoint, $
        format='(6x,1x,a8,4x,6(f5.2,3x),1x,i4)'
;PRINTF, lun2, nCount_set_c, $
;        format='(6x,1x,8x,4x,5(1x,i4,3x),2x)'        
;PRINTF, lun2, ' '
        
nPoint = SIZE(t_pr,/dimension)  &  if nPoint[0] eq 1 then nPoint[0]=0 
PRINTF, lun3, date, bias_set_t, bias_t, nPoint, $
        format='(6x,1x,a8,4x,6(f5.2,3x),1x,i4)'
;PRINTF, lun3, nCount_set_t, $
;        format='(6x,1x,8x,4x,5(1x,i4,3x),2x)'        
;PRINTF, lun3, ' '
        
total='Total'
if (nfile eq 23) or (nfile eq 44) then begin

      PRINTF, lun1, '  '
      PRINTF, lun1, total, bias_set_s_tot, bias_s_tot, s_npt, $
        format='(6x,2x,a5,6x,6(f5.2,3x),i5)'
;      PRINTF, lun1, nCount_set_tot_s, $
;        format='(6x,1x,8x,3x,5(1x,i5,2x),2x)'  
;      PRINTF, lun1, '  '
      
      PRINTF, lun2, '  '
      PRINTF, lun2, total, bias_set_c_tot, bias_c_tot, c_npt, $
        format='(6x,2x,a5,6x,6(f5.2,3x),i5)'
;      PRINTF, lun2, nCount_set_tot_c, $
;        format='(6x,1x,8x,3x,5(1x,i5,2x),2x)'  
;      PRINTF, lun2, '  '

      PRINTF, lun3, '  '
      PRINTF, lun3, total, bias_set_t_tot, bias_t_tot, t_npt, $
        format='(6x,2x,a5,6x,6(f5.2,3x),i5)'
;      PRINTF, lun3, nCount_set_tot_t, $
;        format='(6x,1x,8x,3x,5(1x,i5,2x),2x)'  
;      PRINTF, lun3, '  '

endif   
        
; -----------------------
        
end
                   
@bias.pro
