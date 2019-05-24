;+
; Copyright © 2008, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; DESCRIPTION:
;       Produces a tabular summary of previously-computed standard error
;       between TRMM PR data and its ground radar counterpoint.  Writes
;       output to supplied LUN.
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
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-

pro standardError_table, Height=height, LUN=lun, $
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

;standard_error, s_gv, s_pr, STD_ERROR=std_error_s
;standard_error, c_gv, c_pr, STD_ERROR=std_error_c
standard_error, t_gv, t_pr, STD_ERROR=std_error_t, $
                MIN=dbz_min, MAX=dbz_max, STD_SET=std_error_set_t
;standard_error, o_gv, o_pr, STD_ERROR=std_error_o
;standard_error, l_gv, l_pr, STD_ERROR=std_error_l
;standard_error, m_gv, m_pr, STD_ERROR=std_error_m

;standard_error, s_gv_tot[0:s_npt-1], s_pr_tot[0:s_npt-1], STD_ERROR=std_error_s_tot
;standard_error, c_gv_tot[0:c_npt-1], c_pr_tot[0:c_npt-1], STD_ERROR=std_error_c_tot
standard_error, t_gv_tot[0:t_npt-1], t_pr_tot[0:t_npt-1], STD_ERROR=std_error_t_tot, $
                MIN=dbz_min, MAX=dbz_max, STD_SET=std_error_set_t_tot
;standard_error, o_gv_tot[0:o_npt-1], o_pr_tot[0:o_npt-1], STD_ERROR=std_error_o_tot
;standard_error, l_gv_tot[0:l_npt-1], l_pr_tot[0:l_npt-1], STD_ERROR=std_error_l_tot
;standard_error, m_gv_tot[0:m_npt-1], m_pr_tot[0:m_npt-1], STD_ERROR=std_error_m_tot


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
  PRINTF, lun, format='(//)'
  PRINTF, lun, format='(5x,4x,"Standard Errors of the Estimated TRMM PR Radar Reflectivities")'
  PRINTF, lun, siteID, height, format='(5x,17x,"from ",a0," GV, Height = ",f4.1," km")'
  PRINTF, lun, format='(5x,"_____________________________________________________________________")'
  PRINTF, lun, '  '  &  PRINTF, lun, '  '
  PRINTF, lun, format='(6x,3x,4hDATE,6x,"10-20",3x,"20-30",3x,"30-40",3x,"40-50",3x," >50 ",3x," >10 ",4x,"NPT")'
  PRINTF, lun, format='(6x,1x,"________",4x,"_____",3x,"_____",3x,"_____",3x,"_____",3x,"_____",3x,"_____",3x,"_____")'
endif

nPoint = SIZE(t_pr,/dimension)  &  if nPoint[0] eq 1 then nPoint[0]=0 
PRINTF, lun, date, std_error_set_t, std_error_t, nPoint, $
        format='(6x,1x,a8,4x,6(f4.2,4x),1x,i4)'
        
total='Total'
if (nfile eq 23) or (nfile eq 44) then begin
      PRINTF, lun, '  '
      PRINTF, lun, total, std_error_set_t_tot, std_error_t_tot, t_npt, $
        format='(6x,2x,a5,6x,6(f4.2,4x),i5)'
      PRINTF, lun, '  '   
endif 
        
; -----------------------
        
end
                   
@standard_error.pro
