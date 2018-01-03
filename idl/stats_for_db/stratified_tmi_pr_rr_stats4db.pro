;+
; stratified_tmi_pr_rr_stats4db.pro 
; - Morris/SAIC/GPM_GV   October 2012
;
; DESCRIPTION
; -----------
; Reads volume-matched TMI/GR and PR/GR fields from matching pairs of geo_match
; netCDF files, performs a spatial matching of the PR/GR data to the TMI/GR
; footprints, and computes rainrate differences for PR-GR, TMI-GR, and TMI-PR.
; GR rain rate is computed on a selected CAPPI surface using either a user-
; supplied or default set of Z-R coefficients.  GR reflectivity on the CAPPI
; surface is taken verbatim by default, or a set of bias adjustments in one of
; several forms may be specified (See GZADJUST parameter), and/or the GR Z
; values may have an S-to-Ku frequency adjustment applied prior to computing
; rainrate from Z.
;
; Statistical results are stratified by raincloud type (Convective, Stratiform)
; and underlying surface type (Land, Coast, Ocean), and in total for all
; eligible points, disregarding types, for a total of 7 permutations.  These 7
; permutations are further stratified by the points' distance from the radar in
; 3 categories: 0-49km, 50-99km, and (if present) 100-150km, for a grand total
; of 21 raintype/surface/range categories.  The results and their identifying
; metadata are written out to an ASCII, delimited text file in a format ready
; to be loaded into a table in the 'gpmgv' database.
;
; FILES
; -----
; TMI_PR_RR_StatsByDistToDB*.unl   OUTPUT: Formatted ASCII text file holding
;                                          the computed, stratified TMI-PR-GV
;                                          rainrate difference statistics and
;                                          their identifying metadata fields.
;                                          The full filename from * is generated
;                                          in-code, based on various parameter
;                                          values specified.
; GRtoPR*.nc, GRtoTMI*.nc           INPUT: The set of site/orbit specific
;                                          netCDF grid file pairs for which
;                                          stats are to be computed.  The
;                                          files used are controlled in code
;                                          by the file pattern specified for
;                                          the 'ncsitepath' parameter, or is the
;                                          list of files give by 'filematches'.
; See 'gzadjust' and 'filematches', below, for optional INPUT file descriptions.
;
; PARAMETERS
; ----------
;
; pctAbvThresh - constraint on the percent of bins in the geometric-matching
;                volume that were above their respective thresholds, specified
;                at the time the geo-match dataset was created.  Essentially a
;                measure of "beam-filling goodness".  100 means use only those
;                matchup points where all the PR and GV bins in the volume
;                averages were above threshold (complete volume filled with
;                above threshold bin values).  0 means use all matchup points
;                available, with no regard for thresholds.  Default=100
;
; s2ku          - Binary parameter, controls whether or not to apply the Liao/
;                 Meneghini S-band to Ku-band adjustment GV reflectivity.
;                 Default = no
;
; name_add      - String to be inserted into the output filename to identify a
;                 unique set of data, indicate parameter values used, etc.
;
; ncsitepath    - Pathname pattern to the geo_match netCDF files to be processed.
;                 Defaults to /data/netcdf/geo_match/GRtoTMI*.nc*
;
; filematches   - As an override to ncsitepath, is a file containing a list of
;                 GRtoTMI.* and GRtoPR.* geometry-match file pathname pairs to
;                 process.  Each line in the file contains the full pathnames of
;                 a matching GRtoTMI and GRtoPR file pair, separated by a '|'.
;
; outpath       - Directory to which statistics output file for database will be
;                 written.  If not specified, defaults to /data/tmp.
;
; bbwidth       - Height (km) above/below the mean bright band height within
;                 which a sample touching (above) [below] this layer is
;                 considered to be within (above) [below] the BB.  If not
;                 specified, takes on the default value (0.750) defined in
;                 fprep_geo_match_profiles().
;
; zrab          - A and B coefficients for the Z=aR^b Z-R relationship.  Either
;                 a 2-element array [A,B] with one set of coefficients to apply
;                 to all GR elements; or a single structure with 3 tags
;                 ('RTYPE','A','B') where RTYPE is ignored and A and B are
;                 applied to all GR elements; or an array of this type of
;                 structure with A and B specified separately for each rain type
;                 (RTYPE value: 0,1, or 2 for strat, conv, and other rain type).
;                 See vn_include/zr_coeff_kma.inc for an example of how the
;                 structure array is defined.
;
; cappi_height  - Height above ground at which the CAPPIs of PR and GR data are
;                 extracted and used for computation of GR rain rate, and for
;                 computation of output statistics.  Allowable values are those
;                 defined in the 'heights' array internal to the code.  If the
;                 cappi_height value is not in the heights array or if it is not
;                 specified, its value is overridden to heights[0].                 
;
; strict        - Binary parameter, if set then only those elements that overlap
;                 the CAPPI_HEIGHT level are accepted; otherwise, the sample
;                 whose center height is closest to the CAPPI level is taken.
;
; gzadjust      - Either a scalar dBZ bias correction to be added to the GR
;                 reflectivity, or the name of a file containing site-specific
;                 coefficients used to compute point-by-point GR corrections
;                 based on the PR value, where:
;                    (1)  gr_correction = coeff[0] + PR_dbz*coeff[1]
;                    (2)  corrected_gr_dbz = GR_dbz + gr_correction
;                 File contains a saved IDL HASH variable, where the keys are
;                 the GR station IDs and the values are the coeff arrays.
;
; radius        - Distance in km, defining a circle around each TMI footprint
;                 center.  Those PR/GR samples within this circle are spatially
;                 averaged to produce the matching PR rainrate for the TMI
;                 samples.  Default = 7 km.
;
; verbose       - Binary parameter.  If set, then print status diagnostics on
;                 Z-R coefficients supplied/applied and GR Z correction offset
;                 or coefficients.
;
; CALLS
; -----
; find_gr2pr4gr2tmi()
; matchup_prgr2tmigr_merged()
; z_r_rainrate()
; stratify_diffs21dist_geo2()
; printf_stat_struct21dist3time
;
; HISTORY
; -------
; 10/26/2012 Morris, GPM GV, SAIC
; - Created from stratified_by_dist_stats_to_dbfile_geo_match_ptr2_1.pro,
;   modified to compute 3-D rainrate differences.
; 11/02/12 Morris, GPM GV, SAIC
; - Added logic to filter out samples where rain rates are <= 0.0 (MISSING),
;   since the samples are still in the matchup data.
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;===============================================================================


pro stratified_tmi_pr_rr_stats4db, PCT_ABV_THRESH=pctAbvThresh,  $
                                   S2KU=s2ku,                    $
                                   NAME_ADD=name_add,            $
                                   NCSITEPATH=ncsitepath,        $
                                   FILEMATCHES=filematches,      $
                                   OUTPATH=outpath,              $
                                   BBWIDTH=bbwidth,              $
                                   ZRAB=zrab,                    $
                                   CAPPI_HEIGHT=cappi_height,    $
                                   STRICT=strict,                $
                                   GZADJUST=gzadjust,            $
                                   RADIUS=radius,                $
                                   VERBOSE=verbose

; "include" file for structures/values returned by matchup_prgr2tmigr_merged(),
; also "includes" pr_params.inc and grid_def.inc
@geo_match_nc_structs.inc


statsset = { event_stats, $
            AvgDif: -99.999, StdDev: -99.999, $
            PRmaxZ: -99.999, PRavgZ: -99.999, $
            GVmaxZ: -99.999, GVavgZ: -99.999, $
            GVabsmaxZ: -99.999, GVmaxstddevZ: -99.999, $
            N: 0L $
           }

; "below,in,above" take on the meaning "Ocean,Land,Coast" in this procedure, but
; we leave the tag names the same and redefine in printf_stat_struct21dist3time
allstats = { stats7ways, $
	    stats_total:       {event_stats}, $
            stats_convbelow:   {event_stats}, $
	    stats_convin:      {event_stats}, $
	    stats_convabove:   {event_stats}, $
	    stats_stratbelow:  {event_stats}, $
	    stats_stratin:     {event_stats}, $
	    stats_stratabove:  {event_stats}  $
           }

; We will make a copy of this structure variable for each level and GV type
; we process so that everything is re-initialized.
statsbydist = { stats21ways, $
              km_le_50:    {stats7ways}, $
              km_50_100:     {stats7ways}, $
              km_gt_100:   {stats7ways}, $
              pts_le_50:  0L, $
              pts_50_100:   0L, $
              pts_gt_100: 0L  $
             }


verbose = KEYWORD_SET(verbose)

; Decide which PR and GV points to include, based on percent of expected points
; in bin-averaged results that were above dBZ thresholds set when the matchups
; were done.  If unspecified, set to 100% of bins required (as before this code
; change).  If set to zero, include all points regardless of 'completeness' of
; the volume averages.

IF ( N_ELEMENTS(pctAbvThresh) NE 1 ) THEN BEGIN
   print, "Defaulting to 100 for PERCENT BINS ABOVE THRESHOLD."
   pctAbvThresh = 100
   pctAbvThreshF = FLOAT(pctAbvThresh)
ENDIF ELSE BEGIN
   pctAbvThreshF = FLOAT(pctAbvThresh)
   IF ( pctAbvThreshF LT 0.0 OR pctAbvThreshF GT 100.0 ) THEN BEGIN
      print, "Invalid value for PCT_ABV_THRESH: ", pctAbvThresh, $
             ", must be between 0 and 100."
      print, "Defaulting to 100 for PERCENT BINS ABOVE THRESHOLD."
      pctAbvThreshF = 100.0
   ENDIF
END      

IF N_ELEMENTS(name_add) EQ 1 THEN $
   addme = '_'+STRTRIM(STRING(name_add),2) $
ELSE addme = ''

s2ku = KEYWORD_SET( s2ku )

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

IF ( s2ku ) THEN dbfile = outpath+'/TMI_PR_RR_StatsByDistToDB_Pct' $
                          +strtrim(string(pctAbvThresh),2)+addme+'_S2Ku.unl' $
ELSE dbfile = outpath+'/TMI_PR_RR_StatsByDistToDB_Pct' $
              +strtrim(string(pctAbvThresh),2)+addme+'_DefaultS.unl'

PRINT, "Write output to: ", dbfile
PRINT, ''
OPENW, DBunit, dbfile, /GET_LUN

IF N_ELEMENTS(zrab) EQ 0 THEN $
   print, "Z-R coefficients not provided, using default WSR-88D convective Z-R."

; SET UP TO ADJUST GR REFLECTIVITY IF CORRECTION INFO IS PROVIDED

; set up temporary database tag and GR dBZ correction value(s)
IF N_ELEMENTS(gzadjust) EQ 0 THEN BEGIN
   gzadd = 0.0
   print, "Applying default GR dBZ offset for Z-R: ", gzadd, " dBZ"
   dbtag = 'CAPI'
ENDIF ELSE BEGIN
  ; determine what type of adjustment parameter has been provided
   parmsz=size(gzadjust)
   parmtyp=parmsz[n_elements(parmsz)-2]
   CASE 1 OF
      parmtyp GT 0 AND parmtyp LT 6 : BEGIN
            gzadd = gzadjust
            print, "Applying GR dBZ offset for Z-R: ", gzadd, " dBZ"
            dbtag = 'ZOFF'
         END
      parmtyp EQ 7 : BEGIN
           ; restore the coefficients file provided
            restore, gzadjust, VERBOSE=verbose
           ; check for presence of the restored variable SITE_COEFF
            IF N_ELEMENTS( SITE_COEFF ) EQ 0 THEN BEGIN
               print, "ERROR: Supplied filename for gzadjust does not hold variable SITE_COEFF"
               goto, errorExit
            ENDIF ELSE BEGIN
              ; make sure SITE_COEFF is a HASH
               parmsz=size(SITE_COEFF)
               parmtyp=parmsz[n_elements(parmsz)-2]
               IF parmtyp NE 11 THEN BEGIN
                  print, "ERROR: SITE_COEFF variable in supplied filename for gzadjust not of type HASH."
                  goto, errorExit
               ENDIF ELSE dbtag = 'BYPR'
            ENDELSE
            ;dbtag = 'BYPR'
         END
      ELSE : BEGIN
         print, "ERROR: Supplied value for gzadjust not a scalar or string!"
         goto, errorExit
      END
   ENDCASE
ENDELSE

IF N_ELEMENTS(ncsitepath) EQ 1 THEN path_pr_tmi=ncsitepath+'*' $
ELSE path_pr_tmi = datadirroot+'/netcdf/geo_match/GRtoTMI.*.nc*'

lastsite='NA'
lastorbitnum=0
lastncfile='NA'

; Define the list of fixed-height levels for the vertical profile statistics
heights = [1.5,3.0,4.5,6.0,7.5,9.0,10.5,12.0,13.5,15.0,16.5,18.0,19.5]
hgtinterval = 1.5
;heights = [1.0,2.0,3.0,4.0,5.0,6.0,7.0,8.0,9.0,10.0,11.0,12.0,13.0,14.0,15.0,16.0,17.0,18.0]
;hgtinterval = 1.0


; find and assign CAPPI height whose data are to be included scatter and PDF plots
print, ""
ncappis=N_ELEMENTS(CAPPI_height)
IF ( ncappis EQ 0 ) THEN BEGIN
   print, "CAPPI_height value not specified, defaulting to lowest heights value: ", heights[0], " km"
   CAPPI_hght = heights[0]
   CAPPI_idx = 0
ENDIF ELSE BEGIN
   print, "CAPPI level (km): ", CAPPI_height[0]
   CAPPI_hght = CAPPI_height[0]
   CAPPI_idx = WHERE(heights EQ CAPPI_hght, countcappidx)
   IF countcappidx EQ 0 THEN BEGIN
      print, "CAPPI_height value not valid, defaulting to lowest heights value: ", heights[0], " km"
      CAPPI_hght = heights[0]
      CAPPI_idx = 0
   ENDIF
ENDELSE
ncappis=1

print, ""
print, 'pctAbvThresh = ', pctAbvThresh

IF ( N_ELEMENTS(radius) NE 1 ) THEN BEGIN
   print, "Defaulting to 7.0 km for TMI radius."
   radius = 7.0
ENDIF ELSE BEGIN
   IF radius LT 3.0 OR radius GT 20.0 THEN BEGIN
      print, "RADIUS parameter must be between 3.0 and 20.0, value is ", radius
      print, "Defaulting to 7.0 km for TMI radius."
      radius = 7.0
   ENDIF
ENDELSE
print, ""

; BUILD LIST OF TMI/GR and (if file listing) PR/GR geo-matchup files to process

IF N_ELEMENTS(filematches) EQ 0 THEN BEGIN
   ; search for files matching supplied path/pattern
   pr_files = ''   ; initialize to empty string to avoid undefined error
   tmi_files = file_search(path_pr_tmi,COUNT=nf)
   IF (nf LE 0) THEN BEGIN
      print, "" 
      print, "No files found for pattern = ", path_pr_tmi
      print, " -- Exiting."
      GOTO, errorExit
   ENDIF
ENDIF ELSE BEGIN
   ; read filepathname pairs from supplied file
   command = 'wc -l ' + filematches             ; how many records in file?
   SPAWN, command, nf
   ; grab the word count value from the wc output, and convert characters to byte array
   parsed = STRSPLIT(nf, /extract )
   nfbyte = BYTE(parsed[0])
   ; convert byte array to single integer value
   nf = 0L
   FOR ibyte = 0, N_ELEMENTS(nfbyte)-1 DO BEGIN
      nf = nf + nfbyte[ibyte] * 10L^ibyte
   ENDFOR
   IF nf GT 0 THEN BEGIN
      ; read file names into these string arrays
      tmi_files = STRARR(nf)
      pr_files = STRARR(nf)
      dataPR = ''  ; initialize variable into which file records are read as strings
      npairs = 0
      ; open file for reading, and extract the matchup file pairs
      OPENR, lun0, filematches, ERROR=err, /GET_LUN
      WHILE NOT (EOF(lun0)) DO BEGIN 
         ; - read the '|'-delimited file record into a string, separate file
         ;   pathnames, and write to arrays if both files exist
         READF, lun0, dataPR
         parsed = STRSPLIT( dataPR, '|', /extract )
         dbtmifile = STRTRIM( parsed[0], 2 )
         dbprfile = STRTRIM( parsed[1], 2 )
         IF FILE_TEST(dbtmifile)+FILE_TEST(dbprfile) EQ 2 THEN BEGIN
            tmi_files[npairs] = dbtmifile
            pr_files[npairs] = dbprfile
            npairs++
         ENDIF ELSE BEGIN
            print, "Can't find one or both of files: ", dataPR
         ENDELSE
      ENDWHILE
      nf = npairs
      CLOSE, lun0
   ENDIF
ENDELSE

; ==============================================================================
;                             === MAIN LOOP ===
; ==============================================================================

; READ MATCHING TMI/GR and PR/GR geo-matchup files, GET MATCHED-UP DATA, and
; process and write rainrate difference statistics to database file.

FOR fnum = 0, nf-1 DO BEGIN

   tmi_ncfile = tmi_files(fnum)
   bname = file_basename( tmi_ncfile )
   path2ncs = file_dirname( tmi_ncfile )
   prlen = strlen( bname )
   print, "GeoMatch netCDF file: ", tmi_ncfile

   parsed = strsplit(bname, '.', /EXTRACT)
   site = parsed[1]
   orbit = parsed[3]
   orbitnum=FIX(orbit)

  ; if we are using the linear coefficient corrections to GR dBZ, check whether
  ; this site is defined in the HASH table
   IF dbtag EQ 'BYPR' THEN BEGIN
      IF SITE_COEFF.HasKey(site) EQ 0 THEN BEGIN
         print, "Site ", site, " not found in hash SITE_COEFF.  Sites are:"
         print, SITE_COEFF.Keys()
         print, "Skipping file: ", bname
         CONTINUE
         ;break
      ENDIF
   ENDIF
; set up to skip the non-calibrated KWAJ data files, else we get duplicates
   kwajver = parsed[4]
   skipping=0
;   IF ( site EQ 'KWAJ' and kwajver NE 'cal' ) THEN skipping=1
;   IF ( site EQ 'KWAJ' and STRPOS(bname, 'v') NE -1 ) THEN skipping=1
;   IF ( site EQ 'KMLB' and STRPOS(bname, 'v') NE -1 ) THEN skipping=1
   IF ( STRPOS(bname, 'Multi') NE -1 ) THEN skipping=1
   IF ( skipping EQ 1 ) THEN BEGIN
      print, "Skipping file: ", bname
      CONTINUE
   ENDIF

; skip duplicate orbit for given site
   IF ( site EQ lastsite AND orbitnum EQ lastorbitnum ) THEN BEGIN
      print, ""
      print, "Skipping duplicate site/orbit file ", bname, ", last file done was ", lastncfile
      CONTINUE
   ENDIF

   IF N_ELEMENTS(filematches) EQ 0 THEN gr2prfile = find_gr2pr4gr2tmi(path2ncs, bname) $
   ELSE gr2prfile = pr_files[fnum]
   IF gr2prfile EQ '' THEN break
   matchupStruct = matchup_prgr2tmigr_merged(tmi_ncfile, gr2prfile, heights, $
                                             CAPPI_idx, radius, pctAbvThresh)
;stop
   szstruc = size(matchupStruct)
   sztype = szstruc[szstruc[0] + 1]
   IF sztype NE 8 THEN BEGIN   ; i.e., matchupStruct EQ "NO DATA"
      print, matchupStruct + " Error returned from matchup_prgr2tmigr(), exiting."
      break
   ENDIF

;   IF (status EQ 1) THEN GOTO, nextFile

   mygeometa=matchupStruct.metaparms.geometa
   mysite=matchupStruct.metaparms.sitemeta
   mysweeps=matchupStruct.metaparms.sweepmeta

   gvz=matchupStruct.dataparms.gvz
   gvzmax=matchupStruct.dataparms.tmi_gvzmax
   gvzstddev=matchupStruct.dataparms.tmi_gvzstddev
   tmi_sfcrain = matchupStruct.dataparms.tmi_sfcrain
;   zraw=matchupStruct.dataparms.zraw
   zcor=matchupStruct.dataparms.zcor
   rain3=matchupStruct.dataparms.rain3
   nearSurfRain=matchupStruct.dataparms.nearSurfRain
;   nearSurfRain_2b31=matchupStruct.dataparms.nearSurfRain_2b31
   top=matchupStruct.dataparms.tmi_top
   botm=matchupStruct.dataparms.tmi_botm
   tmi_sfctyp=matchupStruct.dataparms.tmi_sfctyp
   rntypeStrat=matchupStruct.dataparms.rnTypeStrat
   rntypeConv=matchupStruct.dataparms.rnTypeConv
;   bbProx=temporary(*ptr_bbProx)
;   hgtcat=temporary(*ptr_hgtcat)
   dist=matchupStruct.dataparms.tmi_dist_3d
   pctgoodpr=matchupStruct.dataparms.pctgoodpr
   pctgoodgv=matchupStruct.dataparms.pctgoodgv
;   pctgoodrain=matchupStruct.dataparms.pctgoodrain

; extract some needed values from the metadata structures
   site_lat = mysite.site_lat
   site_lon = mysite.site_lon
   siteID = string(mysite.site_id)
   nsweeps = mygeometa.num_sweeps
   pr_time = mygeometa.timeNearestApproach
  ; get the array of sweep times
   gr_times = mysweeps.timeSweepStart
  ; compute the mean time difference between the PR and GR -- take a sweep
  ; at 1/3 the way through the volume as the GR time
   timediff = gr_times[nsweeps/3]-pr_time
  ; adjust tmi_sfctyp values from 10,20,30 to categories 0,1,2 (Ocean,Land,Coast)
  ; - GRtoTMI matchup files use the 2-digit V7 surface type convention for V6 also
   tmi_sfctyp=tmi_sfctyp/10-1

;=========================================================================

   ; compute a dominant rain type from set of PR 2A25 rain types mapped to TMI footprints
   rntype = INTARR(matchupStruct.dataparms.numTMIsfc, nsweeps)
   temptypepr = INTARR(matchupStruct.dataparms.numTMIsfc) & temptypepr[*] = -1
   idxprnonzero = WHERE( matchupStruct.dataparms.numPRsfc GT 0, countnonzero )
   IF countnonzero GT 0 THEN BEGIN
      pctConvPR = FLOAT(rnTypeConv[idxprnonzero]) / matchupStruct.dataparms.numPRsfc[idxprnonzero]
      idxthistype = WHERE(pctConvPR LE 0.3, countthistype)
      if countthistype GT 0 THEN temptypepr[idxprnonzero[idxthistype]] = 1     ; stratiform
      idxthistype = WHERE(pctConvPR GT 0.3 AND pctConvPR LE 0.7, countthistype)
      if countthistype GT 0 THEN temptypepr[idxprnonzero[idxthistype]] = 3     ; other/mixed
      idxthistype = WHERE(pctConvPR GT 0.7)
      if countthistype GT 0 THEN temptypepr[idxprnonzero[idxthistype]] = 2     ; convective
   ENDIF

   ; copy the single-level rain type fields to each level of 2-D array
   FOR level = 0, nsweeps-1 DO BEGIN
      rnType[*,level] = temptypepr
   ENDFOR
   ; append the surface-level fields to make them have 'nsweeps' levels
   nearSurfRainApp=nearSurfRain
   tmi_sfcrainApp=tmi_sfcrain
   tmi_sfctypApp=tmi_sfctyp
   FOR level = 1, nsweeps-1 DO BEGIN
      tmi_sfcrain=[tmi_sfcrain,tmi_sfcrainApp]
      nearSurfRain=[nearSurfRain,nearSurfRainApp]
      tmi_sfctyp=[tmi_sfctyp,tmi_sfctypApp]
   ENDFOR
   tmi_sfcrain=REFORM(tmi_sfcrain, matchupStruct.dataparms.numTMIsfc, nsweeps)
   nearSurfRain=REFORM(nearSurfRain, matchupStruct.dataparms.numTMIsfc, nsweeps)
   tmi_sfctyp=REFORM(tmi_sfctyp, matchupStruct.dataparms.numTMIsfc, nsweeps)

   ; build an array of proximity to the bright band: above=3, within=2, below=1
   ; -- define above (below) BB as bottom (top) of beam at least 0.750 km above
   ;    (0.750 kmm below) mean BB height (by default), or "bbwidth" km above/below
   ;    if BBWIDTH is specified

   IF ( N_ELEMENTS(bbwidth) NE 1 ) THEN BEGIN
      bbwidth=0.750
   ENDIF ELSE BEGIN
      IF bbwidth GE 100.0 THEN BEGIN
         print, "Assuming meters for bbwidth value provided: ", $
                 bbwidth, ", converting to km."
         bbwidth = bbwidth/1000.0
      ENDIF
      IF bbwidth GT 2.0 OR bbwidth LT 0.2 THEN BEGIN
         print, "Overriding outlier bbwidth value:", $
                 bbwidth, " km to 0.750 km"
         bbwidth=0.750
      ENDIF
   ENDELSE
   num_in_BB_Cat = LONARR(4)
   bbProx = rnType   ; for a starter
   bbProx[*] = 0  ; re-init to Not Defined
   idxabv = WHERE( botm GT (matchupStruct.bbparms.meanbb+bbwidth), countabv )
   num_in_BB_Cat[3] = countabv
   IF countabv GT 0 THEN bbProx[idxabv] = 3
   idxblo = WHERE( top LT (matchupStruct.bbparms.meanbb-bbwidth), countblo )
   num_in_BB_Cat[1] = countblo
   IF countblo GT 0 THEN bbProx[idxblo] = 1
   idxin = WHERE( (botm LE (matchupStruct.bbparms.meanbb+bbwidth)) $
             AND (top GE (matchupStruct.bbparms.meanbb-bbwidth)), countin )
   num_in_BB_Cat[2] = countin
   IF countin GT 0 THEN bbProx[idxin] = 2

;=========================================================================

  ; compute the indices of samples at the CAPPI height level

   samphgt = (top+botm)/2
   hgtdiff = ABS( samphgt - CAPPI_hght )

  ; ray by ray, which sample is closest to the CAPPI height level?

   strict = KEYWORD_SET( strict )
   CAPPIdist = MIN( hgtdiff, idxcappitemp, DIMENSION=2 )
   IF strict THEN BEGIN
     ; take the sample whose midpoint is nearest the CAPPI height but only if it
     ; overlaps the CAPPI height
      idxcappitemp2 = WHERE(top[idxcappitemp] GE CAPPI_hght $
                            AND botm[idxcappitemp] LE CAPPI_hght, ncappisamp)
      IF ncappisamp GT 0 THEN idxcappi = idxcappitemp[idxcappitemp2] ELSE break
   ENDIF ELSE BEGIN
     ; take the closest sample to the CAPPI level, regardless of overlap or
     ; vertical distance away
      idxcappi = idxcappitemp
      ncappisamp = N_ELEMENTS(idxcappi)
   ENDELSE

;=========================================================================

; Optional data clipping based on percent completeness of the volume averages:

; Decide which PR and GV points to include, based on percent of expected points
; in bin-averaged results that were above dBZ thresholds set when the matchups
; were done.  If unspecified or set to zero, include all points regardless of
; 'completeness' of the volume averages, as long as there was at least one valid
; gate value in the sample average.


   IF ( pctAbvThreshF GT 0.0 ) THEN BEGIN
       ; clip to the 'good' points, where 'pctAbvThreshF' fraction of bins in average
       ; were above threshold
      idxgoodenuff = WHERE( pctgoodpr[idxcappi] GE pctAbvThreshF $
                       AND  pctgoodgv[idxcappi] GE pctAbvThreshF $
                       AND  tmi_sfcrain[idxcappi] GT 0.0 $
                       AND  nearSurfRain[idxcappi] GT 0.0, countgoodpct )
   ENDIF ELSE BEGIN
      idxgoodenuff = WHERE( pctgoodpr[idxcappi] GT 0.0 AND pctgoodgv[idxcappi] GT 0.0 $
                       AND  tmi_sfcrain[idxcappi] GT 0.0 $
                       AND  nearSurfRain[idxcappi] GT 0.0, countgoodpct )
   ENDELSE

      IF ( countgoodpct GT 0 ) THEN BEGIN
          dbznexlev = gvz[idxcappi[idxgoodenuff]]
;          zrawlev = zraw[idxcappi[idxgoodenuff]]
          dbzcorlev = zcor[idxcappi[idxgoodenuff]]
          rain3lev = rain3[idxcappi[idxgoodenuff]]
          toplev = top[idxcappi[idxgoodenuff]]
          botmlev = botm[idxcappi[idxgoodenuff]]
;          rnFlaglev = rnFlag[idxcappi[idxgoodenuff]]
          rainTypelev = rnType[idxcappi[idxgoodenuff]]
          nearSurfRainlev = nearSurfRain[idxcappi[idxgoodenuff]]
          tmi_sfcrainlev = tmi_sfcrain[idxcappi[idxgoodenuff]]
          tmi_sfctyplev = tmi_sfctyp[idxcappi[idxgoodenuff]]
          distlev = dist[idxcappi[idxgoodenuff]]
          bbProx = bbProx[idxcappi[idxgoodenuff]]
          gvzmaxlev = gvzmax[idxcappi[idxgoodenuff]]
          gvzstddevlev = gvzstddev[idxcappi[idxgoodenuff]]
      ENDIF ELSE BEGIN
          print, "No complete-volume points, quitting case."
          goto, nextFile
      ENDELSE

;-------------------------------------------------------------

; CONVERT GR REFLECTIVITY TO RAIN RATE USING Z-R RELATIONSHIP

  ; if we are using the linear coefficient corrections to GR dBZ, 
  ; compute the correction array
   IF dbtag EQ 'BYPR' THEN BEGIN
      IF (verbose) THEN print, ''
      IF (verbose) THEN print, "Using ", site, $
          "-specific linear fit coefficients on PR Z to adjust GR Z bias."
      prz_coeff = SITE_COEFF[site]
      gzadd = prz_coeff[0] + prz_coeff[1] * dbzcorlev
   ENDIF

IF (verbose) THEN print, ''

IF N_ELEMENTS(zrab) NE 0 THEN BEGIN
   zrsize = SIZE(zrab)
   zrndims = zrsize[0]
   IF zrndims GT 0 THEN zrdims = zrsize[1:zrndims] ELSE zrdims=0
   zrtype = zrsize[zrndims+1]

   IF zrtype NE 8 THEN BEGIN
      IF zrdims[0] EQ 2 THEN BEGIN
         IF (verbose) THEN print, "Using supplied Z-R coefficients: ", zrab
         zra = zrab[0] & zrb = zrab[1]
         gvrrlev = z_r_rainrate(dbznexlev+gzadd, ZRA=zra, ZRB=zrb)
      ENDIF ELSE BEGIN
         print, "Wrong number of Z-R coefficients, expect 2, given ", zrdims[0]
         print, "Using DEFAULT WSR-88D Z-R RELATIONSHIP"
         gvrrlev = z_r_rainrate(dbznexlev+gzadd)
      ENDELSE
   ENDIF ELSE BEGIN
     ; we've been give Z-R coefficients in form of structure(s)
     ; -- is it the right kind of structure?
      CASE zrdims[0] OF
            0 : BEGIN    ; this should never happen
                  print, "Using DEFAULT WSR-88D Z-R RELATIONSHIP"
                  gvrrlev = z_r_rainrate(dbznexlev+gzadd)
                END
            1 : BEGIN
                 ; we've been given one set of A and B, use it for all samples
                  IF (verbose) THEN print, "Using supplied Z-R coefficients structure: ", zrab
                  zra = zrab.a & zrb = zrab.b
                  gvrrlev = z_r_rainrate(dbznexlev+gzadd, ZRA=zra, ZRB=zrb)
                END
            3 : BEGIN
                 ; walk through the supplied raintype/coefficient structures and
                 ; compute GR rainrate using A and B for each rain type
                  IF (verbose) THEN print, "Using supplied Z-R coefficients, by rain type: ", zrab
                  gvrrlev = FLTARR(N_ELEMENTS(dbznexlev))
                  FOR iset=0,2 DO BEGIN
                     IF (verbose) THEN print, "Applying Z-R for rain type code, A, and B = ", zrab[iset]
                     idx4type = WHERE( rainTypelev EQ zrab[iset].rtype, n4type )
                     IF (verbose) THEN print, "No. samples = ", n4type
                     IF n4type GT 0 THEN BEGIN
                        dbznexlev_type = dbznexlev[idx4type]
                        gzadd_type = gzadd[idx4type]
                        zra = zrab[iset].a & zrb = zrab[iset].b
                        gvrrlev_type = z_r_rainrate(dbznexlev_type+gzadd_type, ZRA=zra, ZRB=zrb)
                        gvrrlev[idx4type] = gvrrlev_type
                     ENDIF
                  ENDFOR
                END
         ELSE : BEGIN
                  print, "ILLEGAL ZRAB PARAMETER. Using DEFAULT WSR-88D Z-R RELATIONSHIP."
                  gvrrlev = z_r_rainrate(dbznexlev+gzadd)
                END
      ENDCASE
   ENDELSE

ENDIF ELSE BEGIN
  ; we've been given no Z-R coefficients, use 88D defaults
   IF (verbose) THEN print, "Z-R coefficients not provided, using DEFAULT WSR-88D Z-R RELATIONSHIP."
   gvrrlev = z_r_rainrate(dbznexlev+gzadd)
ENDELSE

; build an array of BB proximity: 0 if below, 1 if within, 2 if above
;#######################################################################################
; NOTE THESE CATEGORY NUMBERS ARE ONE LOWER THAN THOSE IN FPREP_GEO_MATCH_PROFILES() !!
;#######################################################################################
   BBproxlev = BBprox - 1


; build an array of range categories from the GV radar, using ranges previously
; computed from lat and lon by fprep_geo_match_profiles():
; - range categories: 0 for 0<=r<50, 1 for 50<=r<100, 2 for r>=100, etc.
;   (for now we only have points roughly inside 100km, so limit to 2 categs.)
   distcatlev = ( FIX(distlev) / 50 ) < 1

  ; Do 3 sets of differences: PR-GR, TMI-GR, TMI-PR
   sets = ['PRGR','TMGR','TMPR']

   FOR iset = 0,2 DO BEGIN
     ; Compute a mean dBZ difference at CAPPI level for given source pair
      dbtag = sets[iset]
      this_statsbydist = {stats21ways}
      CASE dbtag OF
         'PRGR' : stratify_diffs21dist_geo2, nearSurfRainlev, gvrrlev, $
                            raintypelev, tmi_sfctyplev, distcatlev, $
                            gvzmaxlev, gvzstddevlev, this_statsbydist
         'TMGR' : stratify_diffs21dist_geo2, tmi_sfcrainlev, gvrrlev, $
                            raintypelev, tmi_sfctyplev, distcatlev, $
                            gvzmaxlev, gvzstddevlev, this_statsbydist
         'TMPR' : stratify_diffs21dist_geo2, tmi_sfcrainlev, nearSurfRainlev, $
                            raintypelev, tmi_sfctyplev, distcatlev, $
                            gvzmaxlev, gvzstddevlev, this_statsbydist
      ENDCASE
     ; Write Delimited Output for database
      printf_stat_struct21dist3time, this_statsbydist, pctAbvThresh, dbtag, $
                                     siteID, orbit, 0, CAPPI_hght, timediff, $
                                     DBunit, /SFCTYPE, /SUPPRESS
   ENDFOR

;-------------------------------------------------------------

   nextFile:
   lastorbitnum=orbitnum
   lastncfile=bname
   lastsite=site

ENDFOR    ; end of loop over fnum = 0, nf-1

; ==============================================================================
;                          === MAIN LOOP END ===
; ==============================================================================


print, ''
print, 'Done!'

errorExit:

FREE_LUN, DBunit
print, ''
print, 'Output file status:'
command = 'ls -al ' + dbfile
spawn, command
print, ''

end
