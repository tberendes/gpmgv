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
; DESCRIPTION:
; Given matching data arrays of PR and GV radar reflectivity, rain type, and
; underlying surface type, produces multiple stratifications of the reflectivity
; data based broken out by rain type and surface type in new data arrays.
;  - The size of the input arrays is assumed to be fixed at 75x75 gridpoints (a
;    300x300 km grid of 4 km resolution).
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-

pro commonArea, S_1c21=s_pr0, S_2a25=s_pr, S_2a55=s_gv, $
                C_1c21=c_pr0, C_2a25=c_pr, C_2a55=c_gv, $
                T_1c21=t_pr0, T_2a25=t_pr, T_2a55=t_gv, $
                O_1c21=o_pr0, O_2a25=o_pr, O_2a55=o_gv, $ 
                L_1c21=l_pr0, L_2a25=l_pr, L_2a55=l_gv, $
                M_1c21=m_pr0, M_2a25=m_pr, M_2a55=m_gv
                
common PR_GV, rainType_2a23, rainType_2a54, dbz_1c21, dbz_2a25, dbz_2a55, oceanFlag , $
              epsilon,epsilon_0
common sample, start_sample,sample_range,num_range,dbz_min,dbz_max 
common cumulation, s_npt, c_npt, t_npt, o_npt, l_npt, m_npt, $
                   s_pr0_tot, s_pr_tot, s_gv_tot, c_pr0_tot, c_pr_tot, c_gv_tot, $
                   t_pr0_tot, t_pr_tot, t_gv_tot, o_pr0_tot, o_pr_tot, o_gv_tot, $
                   l_pr0_tot, l_pr_tot, l_gv_tot, m_pr0_tot, m_pr_tot, m_gv_tot  ,$
                   t_epsilon,t_epsilon0,o_epsilon,o_epsilon0,l_epsilon,l_epsilon0,$
                   m_epsilon,m_epsilon0,s_epsilon,s_epsilon0,c_epsilon,c_epsilon0
 
s_count = 0L
c_count = 0L
t_count = 0L
o_count = 0L
l_count = 0L
m_count = 0L

s_space0 = fltarr(5625)
c_space0 = fltarr(5625)
t_space0 = fltarr(5625)
o_space0 = fltarr(5625)
l_space0 = fltarr(5625)
m_space0 = fltarr(5625)

s_space = fltarr(5625)
c_space = fltarr(5625)
t_space = fltarr(5625)
o_space = fltarr(5625)
l_space = fltarr(5625)
m_space = fltarr(5625)

s_ground = fltarr(5625)
c_ground = fltarr(5625)
t_ground = fltarr(5625)
o_ground = fltarr(5625)
l_ground = fltarr(5625)
m_ground = fltarr(5625)

for i=0, 74 do begin
for j=0, 74 do begin
  
  if (dbz_1c21[i,j] ge (dbz_min)) and (dbz_1c21[i,j] le (dbz_max+30)) and $
     (dbz_2a25[i,j] ge (dbz_min)) and (dbz_2a55[i,j] ge (dbz_min-5.)) and $
    ;(dbz_2a25[i,j] ge (dbz_min)) and (dbz_2a55[i,j] ge (dbz_min-0.)) and $
     (dbz_2a25[i,j] le (dbz_max+30)) and (dbz_2a55[i,j] le (dbz_max+30)) then begin
     
    if (rainType_2a23[i,j] eq 1) and (rainType_2a54[i,j] eq 1) then begin
      
      s_space0[s_count] = dbz_1c21[i,j]
      s_space[s_count] = dbz_2a25[i,j]
      s_ground[s_count] = dbz_2a55[i,j]
      s_count = s_count + 1
      
      s_pr0_tot[s_npt] = dbz_1c21[i,j]
      s_pr_tot[s_npt] = dbz_2a25[i,j]
      s_gv_tot[s_npt] = dbz_2a55[i,j]
;      s_epsilon[s_npt]=epsilon[i,j]
;      s_epsilon0[s_npt]=epsilon_0[i,j]
      s_npt = s_npt + 1

    endif
    
    if (rainType_2a23[i,j] eq 2) and (rainType_2a54[i,j] eq 2) then begin
      
      c_space0[c_count] = dbz_1c21[i,j]
      c_space[c_count] = dbz_2a25[i,j]
      c_ground[c_count] = dbz_2a55[i,j]
      c_count = c_count + 1
      
      c_pr0_tot[c_npt] = dbz_1c21[i,j]
      c_pr_tot[c_npt] = dbz_2a25[i,j]
      c_gv_tot[c_npt] = dbz_2a55[i,j]
      
;      c_epsilon[c_npt]=epsilon[i,j]
;      c_epsilon0[c_npt]=epsilon_0[i,j]
      c_npt = c_npt + 1

    endif
    
    t_space0[t_count] = dbz_1c21[i,j]
    t_space[t_count] = dbz_2a25[i,j]
    t_ground[t_count] = dbz_2a55[i,j]
    t_count = t_count + 1
    
    t_pr0_tot[t_npt] = dbz_1c21[i,j]
    t_pr_tot[t_npt] = dbz_2a25[i,j]
    t_gv_tot[t_npt] = dbz_2a55[i,j]
    
;    t_epsilon[t_npt]=epsilon[i,j]
;    t_epsilon0[t_npt]=epsilon_0[i,j]
    t_npt = t_npt + 1
    
; ..............................................

    if (oceanFlag[i,j] eq 0) then begin
      
      o_space0[o_count] = dbz_1c21[i,j]
      o_space[o_count] = dbz_2a25[i,j]
      o_ground[o_count] = dbz_2a55[i,j]
      o_count = o_count + 1
      
      o_pr0_tot[o_npt] = dbz_1c21[i,j]
      o_pr_tot[o_npt] = dbz_2a25[i,j]
      o_gv_tot[o_npt] = dbz_2a55[i,j]
      
;      o_epsilon[o_npt]=epsilon[i,j]
;      o_epsilon0[o_npt]=epsilon_0[i,j]
      o_npt = o_npt + 1
      
    endif
    
    if (oceanFlag[i,j] eq 10) then begin
      
      l_space0[l_count] = dbz_1c21[i,j]
      l_space[l_count] = dbz_2a25[i,j]
      l_ground[l_count] = dbz_2a55[i,j]
      l_count = l_count + 1
      
      l_pr0_tot[l_npt] = dbz_1c21[i,j]
      l_pr_tot[l_npt] = dbz_2a25[i,j]
      l_gv_tot[l_npt] = dbz_2a55[i,j]
      
;      l_epsilon[l_npt]=epsilon[i,j]
;      l_epsilon0[l_npt]=epsilon_0[i,j]
      l_npt = l_npt + 1
      
    endif
    
    if (oceanFlag[i,j] ne 0) and (oceanFlag[i,j] ne 10) then begin
      
      m_space0[m_count] = dbz_1c21[i,j]
      m_space[m_count] = dbz_2a25[i,j]
      m_ground[m_count] = dbz_2a55[i,j]
      m_count = m_count + 1
      
      m_pr0_tot[m_npt] = dbz_1c21[i,j]
      m_pr_tot[m_npt] = dbz_2a25[i,j]
      m_gv_tot[m_npt] = dbz_2a55[i,j]
      
;      m_epsilon[m_npt]=epsilon[i,j]
;      m_epsilon0[m_npt]=epsilon_0[i,j]
      m_npt = m_npt + 1
      
    endif

    
  endif
  
endfor
endfor

if s_count gt 0 then begin
   s_pr0 = s_space0[0:(s_count-1)]
   s_pr = s_space[0:(s_count-1)]
   s_gv = s_ground[0:(s_count-1)]
endif else begin
   s_pr0 = -99.
   s_pr = -99.
   s_gv = -99.
endelse 
 
if c_count gt 0 then begin
   c_pr0 = c_space0[0:(c_count-1)]
   c_pr = c_space[0:(c_count-1)]
   c_gv = c_ground[0:(c_count-1)]
endif else begin
   c_pr0 = -99.
   c_pr = -99.
   c_gv = -99.
endelse

if t_count gt 0 then begin
   t_pr0 = t_space0[0:(t_count-1)]
   t_pr = t_space[0:(t_count-1)]
   t_gv = t_ground[0:(t_count-1)]
endif else begin
   t_pr0 = -99.
   t_pr = -99.
   t_gv = -99.
endelse   

if o_count gt 0 then begin
   o_pr0 = o_space0[0:(o_count-1)]
   o_pr = o_space[0:(o_count-1)]
   o_gv = o_ground[0:(o_count-1)]
endif else begin
   o_pr0 = -99.
   o_pr = -99.
   o_gv = -99.
endelse

if l_count gt 0 then begin
   l_pr0 = l_space0[0:(l_count-1)]
   l_pr = l_space[0:(l_count-1)]
   l_gv = l_ground[0:(l_count-1)]
endif else begin
   l_pr0 = -99.
   l_pr = -99.
   l_gv = -99.
endelse   

if m_count gt 0 then begin
   m_pr0 = m_space0[0:(m_count-1)]
   m_pr = m_space[0:(m_count-1)]
   m_gv = m_ground[0:(m_count-1)]
endif else begin
   m_pr0 = -99.
   m_pr = -99.
   m_gv = -99.
endelse   
   
 
end
