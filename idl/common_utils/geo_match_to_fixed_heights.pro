function geo_match_to_fixed_heights, gmfield, top, botm, fixedHeights, $
                                     METHOD=method_in

IF N_ELEMENTS( method_in ) NE 1 THEN method='NN' $
ELSE method=STRUPCASE(STRTRIM(method_in,2))

sz = SIZE(gmfield)
IF sz[0] NE 2 THEN BEGIN
   MESSAGE, "Wrong gmfield dimensions, expecting 2D array, got " $
            +strtrim(sz[0],1)+"D array.", /INFO
   return, 'Error'
ENDIF

nfp = sz[1]
nswp = sz[2]
ncappis = N_ELEMENTS(fixedHeights)

; define an output field with the number of sweeps dimension changed to the
; number of fixed heights
fieldtype = sz[ (sz[0]+1) ]
outfield = MAKE_ARRAY( nfp, ncappis, TYPE=fieldtype )

; get an array of 1-D indices for a level, identically repeated for each level,
; so that we can assign the CAPPI samples for each level to that CAPPI level's
; correct positions
idxByLev = LINDGEN(nfp,nswp) MOD nfp

samphgt = (top+botm)/2

FOR ifram=0,ncappis-1 DO BEGIN
  ; vertical offset from fixed height level to center of sample volumes
   hgtdiff = ABS( samphgt - fixedHeights[ifram] )
  ; ray by ray, which sample is closest to the CAPPI height level?
   CAPPIdist = MIN( hgtdiff, idxcappitemp, DIMENSION=2 )
   CASE method OF
     "STRICT" : BEGIN
                ; take the sample whose midpoint is nearest the CAPPI height
                ; but only if it overlaps the CAPPI height
                idxcappitemp2 = WHERE(top[idxcappitemp] GE fixedHeights[ifram] $
                                AND botm[idxcappitemp] LE fixedHeights[ifram], $
                                ncappisamp)
                IF ncappisamp GT 0 THEN idxcappi = idxcappitemp[idxcappitemp2] $
                ELSE idxcappi = -1L
                END
         "NN" : BEGIN
                ; take the closest sample to the CAPPI level, regardless
                ; of overlap or vertical distance away
                idxcappi = idxcappitemp
                ncappisamp = N_ELEMENTS(idxcappi)
                END
         ELSE : message, "Unknown METHOD parameter value: " + method
   ENDCASE

   IF ncappisamp GT 0 THEN outfield[idxByLev[idxcappi],ifram] = gmfield[idxcappi]
ENDFOR

return, outfield
end
