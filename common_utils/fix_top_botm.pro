pro fix_top_botm, savefile
if n_params() eq 0 THEN $
   restore, '/tmp/KABR.140817.2650.V03B.DPR_2ADPR_NS.Pct10_46.11N_98.30W_Z.sav' $
ELSE restore, savefile

top = DATASTRUCTRIMMED.top
botm = DATASTRUCTRIMMED.botm
s = size(top, /dim)

for ifp = 0, s[0]-1 do begin
   for iswp = 1, s[1]-1 do begin
      if (botm[ifp,iswp] GT 0.0 and top[ifp,iswp-1] gt 0.0) then begin
         if botm[ifp,iswp] LT top[ifp,iswp-1] then begin
            ; overlaps, set this top and botm value to the midpoint between them
            mid = (botm[ifp,iswp] + top[ifp,iswp-1])/2.0
print, "ifp, iswp, botm, top, mid: ",ifp, iswp, botm[ifp,iswp],top[ifp,iswp-1], mid
            botm[ifp,iswp] = mid
            top[ifp,iswp-1] = mid
         endif
      endif
   endfor
endfor

DATASTRUCTRIMMED.top = top
DATASTRUCTRIMMED.botm = botm
data_structure=DATASTRUCTRIMMED
save, data_structure, file='/tmp/KABR.140817.2650.V03B.DPR_2ADPR_NS.Pct10_unoverlap.sav'

end
