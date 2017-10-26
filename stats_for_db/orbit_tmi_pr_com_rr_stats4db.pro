;+
; orbit_tmi_pr_com_rr_stats4db.pro  - Morris/SAIC/GPM_GV   December 2012
;
; DESCRIPTION
; -----------
; Reads volume-matched TMI/PR/COM fields from along-orbit matchup netCDF
; files, and computes rainrate differences for PR-COM, TMI-PR, and TMI-COM.
; Statistical results are stratified by raincloud type (Convective, Stratiform)
; and underlying surface type (Land, Coast, Ocean), and in total for all
; eligible points, disregarding types, for a total of 7 permutations.  The
; results and their identifying metadata are written out to an ASCII, delimited
; text file in a format ready to be loaded into a table in the 'gpmgv' database.
;
; FILES
; -----
; TMI_PR_COM_Orbit_StatsToDB*.unl   OUTPUT: Formatted ASCII text file holding
;                                          the computed, stratified TMI-PR-GV
;                                          rainrate difference statistics and
;                                          their identifying metadata fields.
;                                          The full filename from * is generated
;                                          in-code, based on various parameter
;                                          values specified.
; PRtoTMI*.nc                       INPUT: The set of orbit specific netCDF
;                                          matchup files for which
;                                          stats are to be computed.  The
;                                          files used are controlled in code
;                                          by the file pattern specified for
;                                          the 'ncfilepath' parameter.
;
; PARAMETERS
; ----------
;
; name_add      - String to be inserted into the output filename to identify a
;                 unique set of data, indicate parameter values used, etc.
;
; ncfilepath    - Pathname pattern to the orbit-match netCDF files to be processed.
;                 Defaults to /data/netcdf/orbit_match/PRtoTMI*.nc*
;
; outpath       - Directory to which statistics output file for database will be
;                 written.  If not specified, defaults to /data/tmp.
;
; RRcut         - Rain rate threshold (mm/h), only samples with rainrates at or
;                 above RRcut are included in the statistics.  Default = 0.01 if
;                 not specified.  Is overridden by the value of "tmi_rain_min"
;                 in the netCDF matchup file if tmi_rain_min>RRcut.
;
; numPRthresh   - Minimum number of PR footprints needed to be volume-matched to
;                 a TMI footprint to allow a sample to be included in the
;                 statistics.  Those samples with fewer PR footprints mapped to
;                 the TMI footprint will be excluded.  Default = 3.
;
; pop_threshold - Probability of Precipitation threshold (percent).  Applies to
;                 over-ocean V7 data only.  Only samples with PoP values at or
;                 above pop_threshold are included in the statistics.
;                 Default = 50 if not specified.
;
; strict        - If set to 2 (highest), then only sample locations where
;                 all 3 data sources meet the RRcut threshold are included.
;                 If set to 1 (medium), only the two sources being compared
;                 must meet the RRcut threshold for a given sample location.
;                 If set to 0 (Loose) then, source by source, values below
;                 RRcut are set to 0, and any point where at least one of the
;                 two rainrate values being compared is above RRcut are
;                 included.  Default = 1
;
; regions       - Array of structures defining rectangular regions by lat/lon
;                 bounds and a descriptive name for the database.  If set, the
;                 data are subdivided by these regional boundaries and
;                 statistics are computed and output for each region.
;
; verbose       - Binary parameter.  If set, then print status diagnostics.
;
; CALLS
; -----
; stratify_diffs7_sfc_rntype()
; printf_stat_struct21dist3time
;
; HISTORY
; -------
; 12/28/2012 Morris, GPM GV, SAIC
; - Created.
; 5/1/2013 Morris, GPM GV, SAIC
; - Added REGIONS keywork parameter and data subsetting capability.
;
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;===============================================================================


pro orbit_tmi_pr_com_rr_stats4db, NAME_ADD=name_add,           $
                                  NCFILEPATH=ncfilepath,       $
                                  OUTPATH=outpath,             $
                                  RRCUT=RRcut,                 $
                                  numPRthresh=numPRthresh,     $
                                  POP_THRESHOLD=pop_threshold, $
                                  STRICT=strict,               $
                                  REGIONS=regions,             $
                                  VERBOSE=verbose

; define structures to hold stratified rainrate difference statistics
statsset = { event_stats, $
            AvgDif: -99.999, StdDev: -99.999, $
            VAR1max: -99.999, VAR1avg: -99.999, $
            VAR2max: -99.999, VAR2avg: -99.999, $
            N: 0L $
           }

; -- We will make a copy of this structure variable for each source pair
;    processed so that everything is re-initialized.
allstats = { stats7ways, $
	     stats_total:       {event_stats}, $
	     stats_convocean:   {event_stats}, $
	     stats_convland:    {event_stats}, $
	     stats_convcoast:   {event_stats}, $
	     stats_stratocean:  {event_stats}, $
	     stats_stratland:   {event_stats}, $
	     stats_stratcoast:  {event_stats}  $
           }

IF (N_ELEMENTS(strict) NE 1) THEN strict = 1 $
ELSE IF strict LT 0 OR strict GT 2 THEN BEGIN
        print, "STRICT parameter must be 0, 1, or 2, value is: ", strict
        print, "Overriding to STRICT=1"
        strict = 1
     ENDIF

verbose = KEYWORD_SET(verbose)

IF ( N_ELEMENTS(pop_threshold) EQ 1 ) THEN BEGIN
  IF ( pop_threshold LT 0. OR pop_threshold GT 100. ) THEN BEGIN
     print, "PoP_threshold must lie between 0 and 100, value is: ", pop_threshold
     print, "Defaulting to 50.0 for pop_threshold."
     pop_threshold = 50.
  ENDIF
ENDIF ELSE BEGIN
   pop_threshold = 50.
ENDELSE

; TMI/GV rainrate lower cutoff of points to use in mean diff. calcs.
IF N_ELEMENTS(RRcut) NE 1 THEN BEGIN
   RRcut = 0.1
   print, "Setting default rainrate cutoff to ", $
          STRING(RRcut,FORMAT="(F0.2)"), " mm/h"
ENDIF
RRcut_orig = RRcut

; lower cutoff of mapped PR footprints to use in mean diff. calcs.
IF N_ELEMENTS(numPRthresh) NE 1 THEN BEGIN
   numPRthresh = 3
   print, "Setting numPR threshold to ", STRING(numPRthresh,FORMAT="(I0)")
ENDIF

IF N_ELEMENTS(outpath) NE 1 THEN BEGIN
   CASE GETENV('HOSTNAME') OF
      'ds1-gpmgv.gsfc.nasa.gov' : BEGIN
             datadirroot = '/data/gpmgv'
             outpath=datadirroot+'/tmp'
             END
      'ws1-gpmgv.gsfc.nasa.gov' : BEGIN
             datadirroot = '/data'
             outpath=datadirroot+'/tmp'
             END
      ELSE : BEGIN
             print, "Unknown system ID, setting outpath to user's home directory"
             outpath='~'
             END
   ENDCASE
   PRINT, "Assigning default output file path: ", outpath
ENDIF

strict_str = ['_Loose','_Paired','_Strict']
IF (N_ELEMENTS(name_add) EQ 1) THEN addme=name_add+strict_str[strict] $
ELSE addme=strict_str[strict]

IF (N_ELEMENTS(regions) EQ 0) THEN BEGIN
   regions = [ { region: "AllData", $
                 lat_lo:  -40.0, $
                 lat_hi:   40.0, $
                 lon_lo: -180.0, $
                 lon_hi:  180.0 } ]
ENDIF

dbfile = outpath+'/TMI_PR_COM_Orbit_StatsToDB'+addme+'.unl'
PRINT, "Write output to: ", dbfile
PRINT, ''

OPENW, DBunit, dbfile, /GET_LUN

print, 'ncfilepath=',ncfilepath
IF N_ELEMENTS(ncfilepath) EQ 1 THEN path_orbmatch=ncfilepath+'*' $
ELSE path_orbmatch = datadirroot+'/netcdf/orbit_match/PRtoTMI.*.nc*'
print, 'path_orbmatch = ', path_orbmatch
lastversionnum=0
lastorbitnum=0
lastncfile='NA'

orbmatch_files = file_search(path_orbmatch,COUNT=nf)
print, 'nfiles = ', STRING(nf, FORMAT='(I0)')
IF (nf LE 0) THEN BEGIN
   print, "" 
   print, "No files found for pattern = ", path_orbmatch
   print, " -- Exiting."
   GOTO, errorExit
ENDIF

FOR fnum = 0, nf-1 DO BEGIN

   orb_ncfile = orbmatch_files(fnum)
   bname = file_basename( orb_ncfile )
   path2ncs = file_dirname( orb_ncfile )
   prlen = strlen( bname )
   print, "GeoMatch netCDF file: ", orb_ncfile

   parsed = strsplit(bname, '.', /EXTRACT)
   version = parsed[3]
   versionnum = FIX(version)
   orbit = parsed[2]
   orbitnum=FIX(orbit)

   ; skip duplicate orbit for given version
   IF ( versionnum EQ lastversionnum AND orbitnum EQ lastorbitnum ) THEN BEGIN
      print, ""
      print, "Skipping duplicate version/orbit file ", bname, $
             ", last file done was ", lastncfile
      CONTINUE
   ENDIF

   data = read_pr2tmi_matchup(orb_ncfile)

   szstruc = size(data)
   sztype = szstruc[szstruc[0] + 1]
   IF sztype NE 8 THEN BEGIN   ; i.e., data EQ "NO DATA"
      print, data + " Error returned from read_pr2tmi_matchup(), exiting."
      break
   ENDIF

   idxnumpr = WHERE(data.numpr GE numPRthresh, numprabvthresh)
   IF numPRabvthresh EQ 0 THEN BEGIN
      print, "No samples with required number of PR footprints: ", $
             STRING(numPRthresh,FORMAT="(I0)"), ", quitting."
      break
   ENDIF ELSE BEGIN
      IF verbose THEN print, "Number of samples with >= ", $
                              STRING(numPRthresh,FORMAT="(I0)"), $
                              " PR footprints: ", $
                              STRING(numPRabvthresh,FORMAT="(I0)")
   ENDELSE

   ; use greater of RRmin input parameter or matchup data threshold as the
   ; rainrate cutoff for computations
   IF verbose AND data.matchupmeta.tmi_rain_min GT RRcut_orig THEN $
      PRINT, "Overriding RRcut value: ",RRcut_orig," to tmi_rain_min value:", $
             data.matchupmeta.tmi_rain_min, " in matchup file."
   RRcut = RRcut_orig > data.matchupmeta.tmi_rain_min

   IF ( data.matchupmeta.trmm_version EQ 7 ) THEN BEGIN
      idxpopmiss = WHERE( data.PoP GT 100, npopmiss )
      IF npopmiss GT 0 THEN data.PoP[idxpopmiss] = -99   ; restore PoP "Missing value"
      idxpopok = WHERE( data.PoP GE pop_threshold, countpopok )
      idxtmirain = WHERE( data.tmirain GE RRcut, nsfcrainy )
      IF verbose THEN BEGIN
         print, ''
         FMTSTR='("#TMI footprints GE ",I0,"% PoP = ", I0, '+ $
                '", #footprints > ",F0.3," mm/h: ", I0, '+ $
                '", #footprints = ", I0)'
         print, pop_threshold, countpopok, RRcut, nsfcrainy, $
                N_ELEMENTS(data.PoP), FORMAT=FMTSTR
      ENDIF
   ENDIF

   ; some variables we might need in a later version of the procedure
;   nscans = data.matchupmeta.num_scans
;   nrays = data.matchupmeta.num_rays
;   center_lat = data.matchupmeta.centerLat
;   center_lon = data.matchupmeta.centerLon
;   mapp = data.matchupmeta.Map_Projection
;   radius = data.matchupmeta.averaging_radius

;-------------------------------------------------

   ; compute a rain type from the PR convective fraction

   rntype = data.numprrn & rntype[*,*] = -1      ; Initialize a 2-D rainType array to 'missing'
   idxposrn = WHERE(data.numprrn GT 0, countnonzero)  ; prevent division by zero
   IF countnonzero GT 0 THEN BEGIN
      convFrac = FLOAT(data.numprconv[idxposrn])/data.numprrn[idxposrn]
      idxthistype = WHERE(convFrac LE 0.3, countthistype)
      if countthistype GT 0 THEN rntype[idxposrn[idxthistype]] = 1     ; stratiform
      idxthistype = WHERE(convFrac GT 0.3 AND convFrac LE 0.7, countthistype)
      if countthistype GT 0 THEN rntype[idxposrn[idxthistype]] = 3     ; other/mixed
      idxthistype = WHERE(convFrac GT 0.7)
      if countthistype GT 0 THEN rntype[idxposrn[idxthistype]] = 2     ; convective
   ENDIF

   ; reassign surface type values (10,20,30) to (1,2,3).
   sfcCat = data.tmisfcType/10
   ; get info from array of surface type
   num_over_SfcType = LONARR(4)
   idxmix = WHERE( sfcCat EQ 3, countmix )  ; Coast
   num_over_SfcType[3] = countmix
   idxsea = WHERE( sfcCat EQ 1, countsea )  ; Ocean
   num_over_SfcType[1] = countsea
   idxland = WHERE( sfcCat EQ 2, countland )    ; Land
   num_over_SfcType[2] = countland
   ; blank out oceanic TMI rain where PoP is below threshold, if V7
   IF ( data.matchupmeta.trmm_version EQ 7 ) THEN BEGIN
      idxrainyPoPbloThresh = WHERE( data.tmiRain[idxsea] GE RRcut $
                             and data.pop[idxsea] lt pop_threshold, countpop2blank )
      IF countpop2blank GT 0 THEN data.tmiRain[idxsea[idxrainyPoPbloThresh]] = -99.
      IF verbose THEN print, "Number of below-PoP-threshold values blanked: ", $
         STRING(countpop2blank, FORMAT='(I0)')
   ENDIF

   IF strict EQ 2 THEN BEGIN
      ; grab the subset of samples that meet the rainrate cutoff threshold
      ; for all 3 sources in common
      idxrrabvthresh = WHERE( data.tmiRain GE RRcut AND data.prRain GE RRcut $
                              AND data.comRain GE RRcut, num_abv )
      IF num_abv GT 0 THEN BEGIN
         sfcRain = data.tmiRain[idxrrabvthresh]
         NrSfcRain = data.prRain[idxrrabvthresh]
         NrSfcRainCom = data.comRain[idxrrabvthresh]
         sfcCatCut = sfcCat[idxrrabvthresh]
         rntypeCut = rntype[idxrrabvthresh]
         latCut = data.TMIlatitude[idxrrabvthresh]
         lonCut = data.TMIlongitude[idxrrabvthresh]
         numPRcut = data.numpr[idxrrabvthresh]
      ENDIF
   ENDIF

   IF strict EQ 0 THEN BEGIN
      ; set below-RRcut rainrates to zero, source-by-source
      sfcRain1 = data.tmiRain
      NrSfcRain1 = data.prRain
      NrSfcRainCom1 = data.comRain
      idxblothresh = WHERE( sfcRain1 LT RRcut, numblo )
      if (numblo GT 0) THEN sfcRain1[idxblothresh] = 0.0
      idxblothresh = WHERE( NrSfcRain1 LT RRcut, numblo )
      if (numblo GT 0) THEN NrSfcRain1[idxblothresh] = 0.0
      idxblothresh = WHERE( NrSfcRainCom1 LT RRcut, numblo )
      if (numblo GT 0) THEN NrSfcRainCom1[idxblothresh] = 0.0
   ENDIF

  ; Do 3 sets of differences: PR-Combined, TMI-Combined, TMI-PR
   sets = ['PRCO','TMCO','TMPR']

   FOR iset = 0,2 DO BEGIN
      dbtag = sets[iset]
      this_orbstats = {stats7ways}

      IF strict EQ 0 THEN BEGIN
         ; grab the subset of samples where either/both source rainrates > RRcut
         CASE dbtag OF
           'PRCO' : idxrrabvthresh = WHERE( NrSfcRain1 GE RRcut $
                             OR NrSfcRainCom1 GE RRcut, num_abv )
           'TMCO' : idxrrabvthresh = WHERE( sfcRain1 GE RRcut $
                             OR NrSfcRainCom1 GE RRcut, num_abv )
           'TMPR' : idxrrabvthresh = WHERE( sfcRain1 GE RRcut $
                             OR NrSfcRain1 GE RRcut, num_abv )
         ENDCASE
         IF num_abv GT 0 THEN BEGIN
            sfcRain = sfcRain1[idxrrabvthresh]
            NrSfcRain = NrSfcRain1[idxrrabvthresh]
            NrSfcRainCom = NrSfcRainCom1[idxrrabvthresh]
            sfcCatCut = sfcCat[idxrrabvthresh]
            rntypeCut = rntype[idxrrabvthresh]
            latCut = data.TMIlatitude[idxrrabvthresh]
            lonCut = data.TMIlongitude[idxrrabvthresh]
            numPRcut = data.numpr[idxrrabvthresh]
         ENDIF
      ENDIF
         
      IF strict EQ 1 THEN BEGIN
         ; grab the subset of samples that meet the rainrate cutoff threshold
         ; for the current two sources only
         CASE dbtag OF
           'PRCO' : idxrrabvthresh = WHERE( data.prRain GE RRcut $
                             AND data.comRain GE RRcut, num_abv )
           'TMCO' : idxrrabvthresh = WHERE( data.tmiRain GE RRcut $
                             AND data.comRain GE RRcut, num_abv )
           'TMPR' : idxrrabvthresh = WHERE( data.tmiRain GE RRcut $
                             AND data.prRain GE RRcut, num_abv )
         ENDCASE
         IF num_abv GT 0 THEN BEGIN
            sfcRain = data.tmiRain[idxrrabvthresh]
            NrSfcRain = data.prRain[idxrrabvthresh]
            NrSfcRainCom = data.comRain[idxrrabvthresh]
            sfcCatCut = sfcCat[idxrrabvthresh]
            rntypeCut = rntype[idxrrabvthresh]
            latCut = data.TMIlatitude[idxrrabvthresh]
            lonCut = data.TMIlongitude[idxrrabvthresh]
            numPRcut = data.numpr[idxrrabvthresh]
         ENDIF
      ENDIF

      ; extract each regional data subset in turn, and see if orbit overlaps it

      IF num_abv GT 0 THEN BEGIN
         nregions = N_ELEMENTS( regions )
         IF verbose AND iset EQ 0 THEN print, ""
         for ireg = 0, nregions-1 do begin
            idxbylat = WHERE(latCut GE regions[ireg].lat_lo AND $
                             latCut LE regions[ireg].lat_hi, nbylat)
            if nbylat GT 0 then begin
               idxbylon = WHERE(lonCut[idxbylat] GE regions[ireg].lon_lo AND $
                                lonCut[idxbylat] LE regions[ireg].lon_hi, nbylon)
               if nbylon GT 0 then begin
                  idxreg = idxbylat[idxbylon]
               endif else begin
                  IF verbose AND iset EQ 0 THEN BEGIN
                     print, "No samples in region '" + regions[ireg].region+ "' by lon bounds"
                     print, ""
                  ENDIF
                  continue
               endelse
            endif else begin
               IF verbose AND iset EQ 0 THEN BEGIN
                  print, "No samples in region '" + regions[ireg].region+ "' by lat bounds"
                  print, ""
               ENDIF
               continue
            endelse

            ; finally, apply the numPR threshold to the regional subset
            idxnumpr = WHERE(numPRcut[idxreg] GE numPRthresh, numprabvthresh)
            IF numPRabvthresh EQ 0 THEN BEGIN
               print, dbtag, ", No samples with required number of PR footprints = ", $
                      STRING(numPRthresh,FORMAT="(I0)"), "in region '", $
                      regions[ireg].region, "'"
               continue
            ENDIF ELSE BEGIN
               IF verbose THEN print, dbtag, ", Number of samples with >= ", $
                                      STRING(numPRthresh,FORMAT="(I0)"), $
                                      " PR footprints in region '", $
                                      regions[ireg].region, "': ", $
                                      STRING(numPRabvthresh,FORMAT="(I0)")
            ENDELSE
            ; Compute mean rainrate differences for given source pair,
            ; stratified by surface and rain type
            CASE dbtag OF
               'PRCO' : stratify_diffs7_sfc_rntype, NrSfcRain[idxnumpr], NrSfcRainCom[idxnumpr], $
                            rntypeCut[idxnumpr], sfcCatCut[idxnumpr], this_orbstats
               'TMCO' : stratify_diffs7_sfc_rntype, sfcRain[idxnumpr], NrSfcRainCom[idxnumpr], $
                            rntypeCut[idxnumpr], sfcCatCut[idxnumpr], this_orbstats
               'TMPR' : stratify_diffs7_sfc_rntype, sfcRain[idxnumpr], NrSfcRain[idxnumpr], $
                            rntypeCut[idxnumpr], sfcCatCut[idxnumpr], this_orbstats
            ENDCASE

            ; Write Delimited Output to file formatted for loading to database
            dbtagout = dbtag + "|" + regions[ireg].region
            printf_stat_struct_sfc_rntype, this_orbstats, dbtagout, versionnum, $
                                           orbit, DBunit, /SFCTYPE, /SUPPRESS

            IF verbose AND iset EQ 0 THEN BEGIN
               print, "Region '" + regions[ireg].region+ "', ", $
                      "Samples = ", STRING(this_orbstats.stats_total.n, FORMAT='(I0)')
               print, ""
;               print, dbtag, ", STATS_STRATOCEAN:"
;               help, this_orbstats.STATS_stratocean, /structure
            ENDIF
         endfor
      ENDIF
   ENDFOR

;-------------------------------------------------------------

   nextFile:
   lastorbitnum=orbitnum
   lastncfile=bname
   lastversionnum=versionnum

ENDFOR

errorExit:
FREE_LUN, DBunit

command = 'ls -al '+dbfile
spawn, command, result
print, result

end
