;===============================================================================
;+
; Copyright © 2009, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; check_geo_matchups_vs_uf.pro         Morris/SAIC/GPM_GV      February 2009
;
;
; DESCRIPTION
; Reads volume-matched PR and GV reflectivity and spatial fields from a
; user-selected geo_match netCDF file, and full-resolution GV reflectivity from
; the matching 1C-UF radar file, generates a plot of a PPI for each, and builds
; an animation loop of the data over the elevation sweeps in the dataset.  The
; animation sequence displays geo-match PR, full-res GV, and geo-match GV
; reflectivity fields in this order at each elevation level, and repeats the
; sequence, working its way up through N elevation sweeps, where N is determined
; by the 'elevs2show' parameter.
;
; PARAMETERS
; ----------
; looprate     - initial animation rate for the PPI animation loop on startup.
;                Defaults to 3 if unspecified or outside of allowed 0-100 range
;
; elevs2show   - number of PPIs to display in the PPI image animation, starting
;                with the lowest elevation angle in the volume. Defaults to 4
;                if unspecified
;
; ncpath       - local directory path to the geo_match netCDF files' location.
;                Defaults to '/data/netcdf/geo_match'
;
; ufpath       - prefix of local directory path to the 1C-UF radar data files'
;                location.  Defaults to '/data/gv_radar/finalQC_in'.
;                Remainder of path is generated in code from elements of the
;                geo_match netcdf filename, including:
;
;                SITEID/PRODUCT/YEAR/MMDD
;
;                where SITEID is the NWS site ID, which may differ from the
;                TRMM GV representation (e.g. KMLB [NWS] vs. MELB [TRMM GV],
;                and PRODUCT is either '1CUF' or '1CUF-cal'.  If the local 1CUF
;                file path uses the TRMM GV site ID, then the UF file will not
;                be found unless the TRMM GV site ID is also specified within
;                ufpath, e.g., '/data/gv_radar/finalQC_in/MELB'.
;              
; sitefilter   - file pattern which acts as the filter limiting the set of input
;                files showing up in the file selector or over which the program
;                will iterate, depending on the select mode parameter. Default=*
;
; no_prompt    - method by which the next file in the set of files defined by
;                ncpath and sitefilter is selected. Binary parameter. If unset,
;                defaults to DialogPickfile()
;
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;===============================================================================

pro check_geo_matchups_vs_uf, SPEED=looprate, ELEVS2SHOW=elevs2show, NCPATH=ncpath, $
                         UFPATH=ufpath, SITE=sitefilter, NO_PROMPT=no_prompt

; set up the loop speed for xinteranimate, 0<= speed <= 100
IF ( N_ELEMENTS(looprate) EQ 1 ) THEN BEGIN
  IF ( looprate LT 0 OR looprate GT 100 ) THEN looprate = 3
ENDIF ELSE BEGIN
   looprate = 3
ENDELSE

; set up the max # of sweeps to show in animation loop
IF ( N_ELEMENTS(elevs2show) NE 1 ) THEN BEGIN
   print, "Defaulting to 4 for the number of PPI levels to plot."
   elevs2show = 4
ENDIF ELSE BEGIN
   IF ( elevs2show LE 0 ) THEN BEGIN
      print, "Disabling PPI animation plot, ELEVS2SHOW <= 0"
      elevs2show = 0
   ENDIF
ENDELSE

IF ( N_ELEMENTS(ncpath) NE 1 ) THEN BEGIN
   print, "Defaulting to /data/netcdf/geo_match for netCDF file path."
   pathpr = '/data/netcdf/geo_match'
ENDIF ELSE pathpr = ncpath

IF ( N_ELEMENTS(ufpath) NE 1 ) THEN BEGIN
   print, "Defaulting to /data/gv_radar/finalQC_in for UF file path prefix."
   pathgv = '/data/gv_radar/finalQC_in'
ENDIF ELSE pathgv = ufpath

IF ( N_ELEMENTS(sitefilter) NE 1 ) THEN BEGIN
   print, "Defaulting to * for file pattern."
   ncfilepatt = '*'
ENDIF ELSE ncfilepatt = '*'+sitefilter+'*'


; Figure out how the next file to process will be obtained.  If no_prompt is
; set, then we will automatically loop over the file sequence.  Otherwise we
; will prompt the user for the next file with dialog_pickfile() (DEFAULT).

no_prompt = keyword_set(no_prompt)

IF (no_prompt) THEN BEGIN

   prfiles = file_search(pathpr+'/'+ncfilepatt,COUNT=nf)

   if nf eq 0 then begin
      print, 'No netCDF files matching file pattern: ', pathpr+'/'+ncfilepatt
   endif else begin
      for fnum = 0, nf-1 do begin
        ; set up for bailout prompt every 5 cases if animating PPIs w/o file prompt
         doodah = ""
         IF ( ((fnum+1) MOD 5) EQ 0 AND elevs2show GT 1 AND no_prompt ) THEN BEGIN $
             READ, doodah, $
             PROMPT='Hit Return to do next 5 cases, Q to Quit, D to Disable this bail-out option: '
             IF doodah EQ 'Q' OR doodah EQ 'q' THEN break
             IF doodah EQ 'D' OR doodah EQ 'd' THEN no_prompt=0   ; never ask again
         ENDIF
        ;
         ncfilepr = prfiles(fnum)
         action = 0
         action = loop_pr_gv_gvpolar_ppis( ncfilepr, pathgv, looprate, elevs2show )

         if (action) then break
      endfor
   endelse
ENDIF ELSE BEGIN
   ncfilepr = dialog_pickfile(path=pathpr, filter = ncfilepatt)
   while ncfilepr ne '' do begin
      action = 0
      action = loop_pr_gv_gvpolar_ppis( ncfilepr, pathgv, looprate, elevs2show )
      if (action) then break
      ncfilepr = dialog_pickfile(path=pathpr, filter = ncfilepatt)
   endwhile
ENDELSE

print, "" & print, "Done!"
END
