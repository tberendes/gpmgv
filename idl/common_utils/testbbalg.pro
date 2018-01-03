pro testbbalg

heights = [1.5,3.0,4.5,6.0,7.5,9.0,10.5,12.0,13.5,15.0,16.5,18.0,19.5]
halfdepth=(heights[1]-heights[0])/2.0
halfdepth_m = FIX(halfdepth*1000.)

for meanbb = 0.0, 5.5, 0.1 DO BEGIN
   meanbb_m = FIX(meanbb*1000.)
;  Level below BB is affected if layer top is 500m or less below BB_Hgt, so
;  BB_HgtLo is index of lowest fixed-height layer considered to be within the BB
   ;BB_HgtLo = ((meanbb_m+500-FIX(heights[0]*1000)-halfdepth_m)>0)/(halfdepth_m*2)
   idxbelowbb = WHERE( (heights+halfdepth) LT (meanbb-0.5), countbelowbb )
   if (countbelowbb GT 0) THEN BB_HgtLo = (MAX(idxbelowbb) + 1) < (N_ELEMENTS(heights)-1) $
   else BB_HgtLo = 0
;  Level above BB is affected if BB_Hgt is 500m or less below layer bottom,
;  so BB_HgtHi is highest fixed-height layer considered to be within the BB
;  (see 'heights' array below)
   ;BB_HgtHi = ((meanbb_m+500-FIX(heights[0]*1000)+halfdepth_m)>0)/(halfdepth_m*2)
   idxabvbb = WHERE( (heights-halfdepth) GT (meanbb+0.5), countabvbb )
   if (countabvbb GT 0) THEN BB_HgtHi = (MIN(idxabvbb) - 1) > 0 $
   else if (meanbb GE (heights(N_ELEMENTS(heights)-1)-halfdepth) ) then $
   BB_HgtHi = (N_ELEMENTS(heights)-1) else BB_HgtHi = 0
   BB_HgtLo2 = BB_HgtLo < BB_HgtHi
;   bbparms.BB_HgtLo = BB_HgtLo
   BB_HgtHi2 = BB_HgtHi > BB_HgtLo
;   bbparms.BB_HgtHi = BB_HgtHi
;   print, 'Mean BB (km), bblo, bbhi = ', meanbb, heights[0]+halfdepth*2*BB_HgtLo, heights[0]+halfdepth*2*BB_HgtHi
   print, 'Mean BB (km), bblo2, bbhi2 = ', meanbb, heights[0]+halfdepth*2*BB_HgtLo2, heights[0]+halfdepth*2*BB_HgtHi2
ENDFOR
END
