;-------------------------------------------------------------------------------
;
; print_profile_from_sav.pro     Jan. 2016
;
; Takes a SAVE file from a run of stats_by_dist_to_dbfile_dpr_pr_geo_match.pro,
; RESTOREs its variables, and prints a formatted table of Total, Stratiform, and
; Convective DPR and GR mean reflectivity, GR-DPR bias, and N (# sample) at each
; height level.  Prints an optional title above the table of data, if its text
; string is provided as the TITLE parameter.  Prints an optional comma-separated
; values version of the table data below the formatted table if the CSV binary
; keyword parameter is set.
;
;-------------------------------------------------------------------------------

pro print_profile_from_sav, savfile, TITLE=title, CSV=csv
RESTORE, savfile
nlev = N_ELEMENTS(cprmnarr)

diff  = grmnarr-prmnarr
idx = where(grmnarr LT 0.0, countneg)
if countneg GT 0 then diff[idx] = grmnarr[idx]
sdiff = sgrmnarr-sprmnarr
idx = where(sgrmnarr LT 0.0, countneg)
if countneg GT 0 then sdiff[idx] = sgrmnarr[idx]
cdiff = cgrmnarr-cprmnarr
idx = where(cgrmnarr LT 0.0, countneg)
if countneg GT 0 then cdiff[idx] = cgrmnarr[idx]

if N_ELEMENTS(title) NE 0 THEN BEGIN
   print, ''
   print, title
endif
print, ''
print, ' Hgt. |         ANY/ALL               |         Stratiform            |          Convective           |
print, '------|-------------------------------|-------------------------------|------------- -----------------|
print, ' (km) |  DPR  :   GR  :  Bias :   N   |  DPR  :   GR  :  Bias :   N   |  DPR  :   GR  :  Bias :   N   |
print, '------|-------------------------------|-------------------------------|-------------------------------|

for i = 0, nlev-1 do begin
   print, hgtarr[i], prmnarr[i], grmnarr[i], diff[i], samples[i], $
          sprmnarr[i], sgrmnarr[i], sdiff[i], ssamples[i], $
          cprmnarr[i], cgrmnarr[i], cdiff[i], csamples[i], $
          FORMAT='(F5.1," | ",3(3(F5.1," : "),I5," | "))'
endfor

IF KEYWORD_SET(csv) THEN BEGIN
   print, '' & print, '' & print, 'CSV output:' & print, ''
   print, 'Height km,DPR Any,GR Any,Bias Any,N Any,DPR Strat,GR Strat,' + $
          'Bias Strat,N Strat,DPR Conv,GR Conv,Bias Conv,N Conv'
   for i = 0, nlev-1 do begin
      IF samples[i] GT 0 THEN $
         print, hgtarr[i], prmnarr[i], grmnarr[i], diff[i], samples[i], $
                sprmnarr[i], sgrmnarr[i], sdiff[i], ssamples[i], $
                cprmnarr[i], cgrmnarr[i], cdiff[i], csamples[i], $
                FORMAT='(F0.1,3(3(",", F0.1),",",I0))'
   endfor
   print, ''
ENDIF
end
