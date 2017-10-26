function rsl_get_sweep, volume, elevation, sweep_index=sweepindex, $
     sweep_number=sweepnum, swpnum=swpnum, swpindex=swpindex


; RSL_GET_SWEEP returns one sweep of data in a structure.
;
; Syntax:
;     sweep = RSL_GET_SWEEP(volume, elevation [, SWEEP_INDEX=sweepindex]
;        [, SWEEP_NUMBER=sweepnumber])
;
; Inputs:
;     volume:    a volume structure.
;     elevation: elevation angle of the sweep to be returned.  If omitted,
;	         and neither of the keywords SWEEP_NUMBER or SWEEP_INDEX is
;                used, the base scan is returned.
;
; Keyword parameters:
;    SWEEP_INDEX: sweep index, where 0 is the base scan.  If both elevation
;                 and SWEEP_INDEX are given, elevation is used.
;    SWEEP_NUMBER:   sweep number, where 1 is the base scan.  If both elevation
;                 and SWEEP_NUMBER are given, elevation is used.
;
; Written by:  Bart Kelley, GMU, July 2002
; Modified by:  Bob Morris, SAIC, GPM GV, February 2009
; - Changed logic of comparison between diff and prevdiff, to handle radar
;   volumes with duplicate (but not exactly identical) sweep elevations, as in
;   some WSR-88D "split cut" multiple PRF scan strategies.  See FMH-11 Part C.
;   Only applies where elevation parameter is specified.  Returns first sweep
;   where elevation is an exact match to those in the sweep, or the sweep for
;   the elevation that is the closest match to input elevation.  In the case of
;   multiple sweeps at the same nominal elevation, the elevations are taken to
;   be at the same level (duplicates) only if within 0.05 degrees.
;

on_error, 2 ; on error, return to caller.

tagcheck = where(tag_names(volume) eq 'SWEEP')
if size(tagcheck,/n_dimensions) eq 0 then if tagcheck lt 0 then $
    message,'Argument 1 must be a Volume structure.'

; sweepindex and swpindex are synonyms, as are sweepnum and swpnum.
; if sweepnum (or swpnum) is given, it is converted to swpindex. 

if not keyword_set(swpindex) then swpindex = 0
if keyword_set(sweepindex) then swpindex = sweepindex
if keyword_set(swpnum) then swpindex = swpnum - 1
if keyword_set(sweepnum) then swpindex = sweepnum - 1

if n_elements(elevation) eq 0 then goto, finished

elev = volume.sweep.h.elev
prevdiff = abs(elevation - elev[0])

for i = 1, volume.h.nsweeps-1 do begin
    diff =  abs(elevation - elev[i]) 
    if diff lt prevdiff then begin
        prevdiff = diff
	swpindex = i
    endif else if diff gt (prevdiff+0.05) then goto, finished
endfor

finished: return, volume.sweep[swpindex]
end
