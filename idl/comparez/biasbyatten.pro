pro biasbyatten

restore, file='/tmp/hist9MELB.0star.sav'
bblevstr = ['  N/A ', 'Below BB', 'Within BB', 'Above BB']
typestr = ['Other ', 'Stratiform, ', 'Convective, ']

step=2
for i=0,2,step do begin     ;row, count from bottom -- also, bbprox type

  proxim = i+1     ; 1=' Below', 2='Within', 3=' Above'

  for j=0,1 do begin   ;column, count from left; also, strat/conv raintype index
    raincat = j+1   ; 1=Stratiform, 2=Convective

   ; extract the histogram for this raintype/bbprox combination
    subtitle = typestr[raincat]+bblevstr[proxim]
    combo = raincat*10 + i
    CASE combo OF
       10 : biasByAtten = REFORM(hist9[0,*,*])    ; strat/below
       11 : biasByAtten = REFORM(hist9[1,*,*])    ; strat/within
       12 : biasByAtten = REFORM(hist9[2,*,*])    ; strat/above
       20 : biasByAtten = REFORM(hist9[3,*,*])    ; conv/below
       21 : biasByAtten = REFORM(hist9[4,*,*])    ; conv/within
       22 : biasByAtten = REFORM(hist9[5,*,*])    ; conv/above
       30 : biasByAtten = REFORM(hist9[6,*,*])    ; other/below
       31 : biasByAtten = REFORM(hist9[7,*,*])    ; other/within
       32 : biasByAtten = REFORM(hist9[8,*,*])    ; other/above
    ENDCASE

   ; extract the points to be plotted (non-zero histogram total)
    idxnotzero = WHERE(biasByAtten GT 0, npts)
    IF ( npts GT 0 ) THEN BEGIN
      ; get the positions of the non-zero values in the histo array
       xypos = ARRAY_INDICES(biasByAtten, idxnotzero)
      ; convert the indices back to histogram bin physical values
       atten = REFORM(xypos[1,*])/10.0-5.0   ; 0.1dBZ steps starting from -5.0
       biasprgr = REFORM(xypos[0,*])/10.0-20.0  ; 0.1dBZ steps from -20.0 to 20.0
      ; get the sorted, unique indices in the attenuation dimension
       arrayatten = REFORM(xypos[1,*])
       uniqattenidx = arrayatten[UNIQ(arrayatten, SORT(arrayatten))]
      ; convert to their physical attenuation values
       uniqattenvals = uniqattenidx/10.-5.
       n_atten_defined = N_ELEMENTS(uniqattenvals)
       meanbiasperatten = FLTARR(n_atten_defined)
      ; walk through the unique attenuation positions and compute mean bias for each
       for iatten = 0, n_atten_defined-1 DO BEGIN
         ; grab this column of histo counts
          histobias = REFORM(biasByAtten[*,uniqattenidx[iatten]])
          idxbiasnotzero = WHERE(histobias GT 0L, nbiases)
          biasprgr = idxbiasnotzero/10.0-20.0
          meanbiasperatten[iatten]=TOTAL(histobias[idxbiasnotzero]*biasprgr)/TOTAL(histobias[idxbiasnotzero])
       endfor
    ENDIF
print, bblevstr[proxim],' : ', typestr[raincat],' : A,B = ', linfit(UNIQATTENVALS,MEANBIASPERATTEN)
  endfor
endfor

end
