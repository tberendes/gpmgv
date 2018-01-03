;===============================================================================
;+
; Copyright © 2016, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; extract_tc_channel_names.pro          Morris/SAIC/GPM_GV      July 2016
;
; DESCRIPTION
; -----------
; Takes a long multi-line string from the Tc_longname attribute for a data swath
; in a 1C-R-XCAL HDF5 data file and parses it to extract the name of each channel
; of brightness temperature data contained in the swath.  An example of the
; Tc_longname attribute, passed in the NamesStr parameter, is:
;
; Intercalibrated Tb for channels 
;                                 1) 166.0 GHz V-Pol 2) 166.0 GHz H-Pol
;                                 3) 183.31 +/-3 GHz V-Pol and 
;                                 4) 183.31 +/-7 GHz V-Pol
;
; without the preceding ';' characters in these comments.  We attempt to extract
; names like '166.0 GHz V-Pol' from the numbered list and write each name in
; swath/channel order to the string array Tc_Names, starting at array position
; given by idxstart.  The parameter 'nchan' give the number of channels of Tb
; data, which must be the same as the number of channel names defined in the
; NamesStr parameter.
;
; HISTORY
; -------
; 7/5/2016 by Bob Morris, GPM GV (SAIC)
;  - Created.
;
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;===============================================================================

FUNCTION extract_tc_channel_names, Tc_Names, NamesStr, idxstart, nchan

status = 0   ; initialize to SUCCESS

; find the start of the channel frequency listings defined by '1)'

nameslen = STRLEN( NamesStr )
idxchan1 = STRPOS( NamesStr, '1)' )
IF idxchan1 EQ -1 THEN BEGIN
   message, "Cannot find '1)' in NamesStr, cannot assign channel names", /INFO
   status = 1
ENDIF ELSE BEGIN
  ; extract from after '1)' to end of NamesStr by splitting on '1)' and taking
  ; the trailing half of the split [right and below of, and not including, '1)']
   allchnames = STRSPLIT( NamesStr, '1)', /regex, /extract )
  ; now split into individual substrings delimited by right parentheses ')'
   chnames = STRSPLIT( allchnames[1], ')', /extract )
  ; make sure the number of channel names is the same as expected (from nchan)
   IF N_ELEMENTS(chnames) EQ nchan THEN BEGIN
     ; find the end of each channel name, defined by '-Pol' (we hope)
      for i = 0, nchan-1 do begin
         chend = STRPOS( chnames[i], '-Pol' )
         IF chend NE -1 THEN BEGIN
           ; extract the channel name, including preceding whitespace left over
           ; from between the ')' and the numerical frequency value
            thischname = STRMID( chnames[i], 0, chend+4 )
            print, '"', STRTRIM(thischname, 2),'"',  i
           ; trim any leading/trailing whitespace and write to swath/channel
           ; slot in Tc_Names string array
            Tc_Names[idxstart+i] = STRTRIM(thischname, 2)
         ENDIF ELSE BEGIN
            print, "Failed to find '-Pol' in name string: ", chnames[i]
            status = 1
            BREAK
         ENDELSE
      endfor
   ENDIF ELSE BEGIN
      message, "Number of channel names differs from # of data channels", /INFO
      status = 1
   ENDELSE
ENDELSE

return, status
end
