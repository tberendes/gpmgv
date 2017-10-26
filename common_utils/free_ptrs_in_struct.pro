;+
; Copyright © 2013, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; free_ptrs_in_struct.pro         Bob Morris, GPM GV/SAIC   June 2013
;
; DESCRIPTION
; Given a structure or pointer as input, recursively walks through the
; structure and/or pointer references and frees pointers from the lowest level
; up through the highest level, and optionally reports on the amount of memory
; freed as a result.  The input structure still exists with all the non-pointer
; values left unchanged, and all the structure-level pointers in an invalid
; state.
;
; PARAMETERS
; ----------
; ptrStruct  -- input structure or pointer to be traversed
; prefix     -- String, name of the current structure element or pointer level.
;               Should be left unspecified in first call to this procedure
;               from the external external function or procedure, and is only
;               specified in internal recursive calls to this procedure
; memdiff    -- Long, value describing the amount of memory freed as a result
;               of freeing the pointers in prtStruct
; accum      -- Binary keyword, controls whether to accumulate memdiff (=1),
;               or initialize from starting memory (=0).  Should be UNSET in
;               first call from the external function or procedure, and is only
;               set to ON (=1) in internal recursive calls to this procedure,
;               free_ptrs_in_struct.pro
; verbose    -- Binary keyword, controls whether to suppress diagnostic
;               messages (DEFAULT) or output them (if set to ON [=1])
;
; HISTORY
; -------
; 06/06/13  Morris/GPM GV/SAIC
; - Created.
; 06/28/13  Morris/GPM GV/SAIC
; - Put output of message in case of invalid pointer under VERBOSE control.
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-

PRO free_ptrs_in_struct, ptrStruct, prefix, MEMDIFF=memdiff, ACCUM=accum, $
                         VERBOSE=verbose

speak = KEYWORD_SET(verbose)

; determine whether to init or increment memdiff
addmore = KEYWORD_SET(accum)

IF N_ELEMENTS(prefix) EQ 0 THEN BEGIN
   ; get the name of the passed variable as a string
   prefix = SCOPE_VARNAME(ptrStruct, LEVEL=-1)
ENDIF
lastprefix = prefix
IF speak THEN print, '' 
IF speak THEN print, "Processing ", prefix

; make sure we've been given a structure (Type 8) or a pointer (Type 10)
intype = SIZE(ptrStruct, /TYPE)
IF (intype NE 8) AND (intype NE 10) THEN BEGIN
   typename = SIZE(ptrStruct, /TNAME)
   message, "Input parameter must be pointer or structure, is type "+typename, $
            /INFO
   GOTO, skipIt
ENDIF

; grab current IDL memory usage, prior to freeing pointers
IF N_ELEMENTS(memdiff) NE 0 THEN memstart = MEMORY(/CURRENT)

IF intype EQ 10 THEN BEGIN
   IF ptr_valid(ptrStruct) THEN BEGIN
      ; if it's a valid pointer, and it doesn't point to another pointer or
      ; structure, then just go ahead and free it.  Otherwise, must recurse
      ; through next level(s) before freeing it
      totype = SIZE(*ptrStruct, /TYPE)
      IF speak THEN print, "Type pointed to is ", SIZE(*ptrStruct, /TNAME)
      IF (totype NE 8) AND (totype NE 10) THEN BEGIN
         IF speak THEN print, "Free the pointer now."
      ENDIF ELSE BEGIN
         IF speak THEN print, "Recursing to next level(s)."
         lastprefix2 = prefix
         prefix = '(*'+prefix+')'
         free_ptrs_in_struct, *ptrStruct, prefix, MEMDIFF=memdiff, ACCUM=1, $
                              VERBOSE=speak
         prefix = lastprefix2
      ENDELSE   
      IF speak THEN print, '' 
      IF speak THEN print, "Freeing pointer: ", prefix
      ptr_free, ptrStruct
      IF N_ELEMENTS(memdiff) NE 0 THEN BEGIN
         IF (addmore) THEN memdiff = memdiff+memstart-MEMORY(/current) $
                      ELSE memdiff = memstart-MEMORY(/current)
         IF speak THEN print, "MEMDIFF: ", memdiff
      ENDIF
   ENDIF ELSE IF speak THEN $
                 message, "Invalid pointer: '"+prefix+"', skipping.", /INFO
ENDIF ELSE BEGIN
   ; it's a structure, work through its elements recursively
   tags = tag_names(ptrStruct)
   lasttype = intype
   for itag = 0, n_tags(ptrStruct)-1 do begin
      ; determine the element type; if it's pointer or struct, call this
      ; routine recursively to deal with it
      tagname = tags[itag]
      valtype = SIZE(ptrStruct.(itag), /TYPE)
      typename = SIZE(ptrStruct.(itag), /TNAME)
      IF (valtype EQ 8) OR (valtype EQ 10) THEN BEGIN
         IF speak THEN print, ''
         IF speak THEN print, prefix+'.'+tagname+' is type '+typename+ $
                              ', recursing.'
         prefix=prefix+'.'+tagname
         this_ptrStruc = ptrStruct.(itag)
         free_ptrs_in_struct, ptrStruct.(itag), prefix, MEMDIFF=memdiff, $
                              VERBOSE=speak, ACCUM=1
         prefix=lastprefix
      ENDIF ELSE BEGIN
         IF speak THEN print, 'Skipping '+prefix+'.'+tagname+ $
                              ', type = '+typename
      ENDELSE
      lasttype = valtype
   endfor
ENDELSE

skipIt:
end
