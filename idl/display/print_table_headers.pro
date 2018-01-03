;===============================================================================
;+
; Copyright © 2015, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; print_table_headers.pro       - Morris/SAIC/GPM_GV     May 2015
;
; DESCRIPTION
; -----------
; Given the IDs of two data sources being compared and the type of variable
; whose statistics were computed (intype), formats and prints a standard table
; header to go above the scores to be printed later.  If the PS_UNIT keyword is
; used, then the table header test is also printed to the postscript file unit
; specified as the keyword value.
;
; HISTORY
; -------
; 04/09/15  Morris/GPM GV/SAIC
; - Created by extracting existing function from the source code file
;   geo_match_3d_dsd_comparisons.pro and adding the field type ZR from the same
;   routine as defined in geo_match_3d_rr_or_z_comparisons.pro.  Now the same
;   function applies to both procedures.
; 09/23/15  Morris/GPM GV/SAIC
; - Modified to just use Dm as the label for intype of Dm or D0, as DPR is
;   always Dm and GR may be either.
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;===============================================================================
;

pro print_table_headers, var1, var2, intype, BB_LAYERS=bb_layers, $
                         PS_UNIT=tempunit

IF N_ELEMENTS(tempunit) EQ 1 THEN do_ps=1 ELSE do_ps=0

; pad field type to 2 chars as needed
CASE intype OF
    'Z' : BEGIN
          type=intype+' '
          texttype = 'Mean Reflectivity '
          END
   'Dm' : BEGIN
          type=intype
          texttype = 'Mean Drop Diameter (Dm, in mm) '
          END
   'NW' : BEGIN
          type='Nw'
          texttype = 'Mean Normalized Intercept Parameter ( log10(Nw) ) '
          END
   'D0' : BEGIN
          type='Dm'
          texttype = 'Mean Drop Diameter (Dm, in mm) '
          END
   'RR' : BEGIN
          type=intype
          texttype = 'Mean Rain Rate (mm/h) '
          END
   'ZR' : BEGIN
          type=intype
          texttype = 'Mean Rain Rate (mm/h) '
          END
   ELSE : message, 'illegal value for intype, must be Z, RR, ZR, Dm, Nw, or D0'
ENDCASE

; set up spacing based on lengths of var1 and var2
CASE (STRLEN(var1)*10+STRLEN(var2)) OF
   22 : BEGIN
           diffvar = ' '+var1+'-'+var2
           maxvars = ' '+ var1 + 'Max'+type+'   '+ var2 +'Max'+type
        END
   23 : BEGIN
           diffvar = var1+'-'+var2
           maxvars = ' '+ var1 + 'Max'+type+'  '+ var2 +'Max'+type
        END
   32 : BEGIN
           diffvar = var1+'-'+var2
           maxvars = var1 + 'Max'+type+'   '+ var2 +'Max'+type
        END
   ELSE : message, 'illegal string lengths for var1 and var2, must sum to 4 or 5'
ENDCASE

IF N_ELEMENTS(bb_layers) EQ 0 THEN BEGIN
   ; print the header for stats broken out by CAPPI levels and rain type
   print, '' & IF (do_ps EQ 1) THEN printf, tempunit, ''
   textout = texttype+'Statistics grouped by fixed height levels (km):'
   print, textout & IF (do_ps EQ 1) THEN printf, tempunit, textout
   print, '' & IF (do_ps EQ 1) THEN printf, tempunit, ''
   textout = ' Vert. |   Any Rain Type  |    Stratiform    |' $
             +'    Convective     |     Dataset Statistics      |'
   print, textout & IF (do_ps EQ 1) THEN printf, tempunit, textout
   textout = ' Layer | '+diffvar+'    NumPts | '+diffvar+'    NumPts |' $
             +' '+diffvar+'    NumPts  | AvgDist  '+maxvars+' |'
   print, textout & IF (do_ps EQ 1) THEN printf, tempunit, textout
   textout = ' ----- | -------   ------ | -------   ------ |' $
             +' -------   ------  | -------  --------  -------- |'
   print, textout & IF (do_ps EQ 1) THEN printf, tempunit, textout

ENDIF ELSE BEGIN
   ; print the header for stats broken out by BB proximity
   print, '' & IF (do_ps EQ 1) THEN printf, tempunit, ''
   print, '' & IF (do_ps EQ 1) THEN printf, tempunit, ''
   textout = texttype+'Statistics grouped by proximity to Bright Band:'
   print, textout & IF (do_ps EQ 1) THEN printf, tempunit, textout
   print, '' & IF (do_ps EQ 1) THEN printf, tempunit, ''
   textout = 'Surface|   Any Rain Type  |    Stratiform    |' $
             +'    Convective     |     Dataset Statistics      |'
   print, textout & IF (do_ps EQ 1) THEN printf, tempunit, textout
   textout = ' type  | '+diffvar+'    NumPts | '+diffvar+'    NumPts |' $
             +' '+diffvar+'    NumPts  | AvgDist  '+maxvars+' |'
   print, textout & IF (do_ps EQ 1) THEN printf, tempunit, textout
   textout = ' ----- | -------   ------ | -------   ------ |' $
             +' -------   ------  | -------  --------  -------- |'
   print, textout & IF (do_ps EQ 1) THEN printf, tempunit, textout

ENDELSE

end

