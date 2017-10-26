function getmetaobject, meta, objectname

; Returns a string containing the value for the specified object from a
; TSDIS metadata string.
;
; Input:
;    meta:        a string (or byte array) of TSDIS metadata.
;    objectname:  name of the metadata object whose value is to be returned.
;
; Example:
;    city = getmetaobject(archivemeta, 'RadarCity')
;
; Written by:  Bart Kelley, GMU, April 2002
;

doublequote = '"'

pos=strpos(meta,'OBJECT='+objectname)
if pos lt 0 then begin
    message,'WARNING: object '+objectname+' not found in TSDIS metadata', $
            /informational
    return,''
endif
pos=strpos(meta,'Value=',pos)
pos=pos+6
if strmid(meta,pos,1) eq doublequote then begin
    pos=pos+1
    stopchar=doublequote
endif else stopchar=';'
pos2= strpos(meta,stopchar,pos)
return, strmid(meta,pos,pos2-pos)
end
