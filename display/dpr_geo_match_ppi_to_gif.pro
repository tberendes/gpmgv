;===============================================================================
;+
; Copyright © 2015, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; dpr_geo_match_ppi_to_gif.pro    Morris/SAIC/GPM_GV    June 2015
;
; DESCRIPTION
; -----------
; Driver for dpr_geo_match_to_gif (included procedure).  Displays PPIs of
; geometry-matched DPR and GR reflectivity from a GRtoDPR matchup netCDF file,
; and optionally saves the PPI pairing as a GIF image.  Sets up user/default
; parameters defining the displayed PPIs, and the method by which the next
; case is selected: either prompt the user to select the file, or just take the
; next one in the sequence.
;
; If GIF images are produced they are written to the directory 'gif_path' and
; the filename is the same as the GRtoDPR file name, except with the filename
; extensions '.nc.gz' replaced by '.PPI_PctXX.gif', where XX is the pctAbvThresh
; value (one to three digits, 0 to 100).
;
;
; PARAMETERS  (alphabetically listed)
; ----------
; batch        - (Optional) binary parameter, if set to ON, and if 'gif_path'
;                and 'no_prompt' are also set, then the procedure automatically
;                steps through all the files defined by 'ncpath' and 'sitefilter'
;                and produces on-screen and GIF versions of the PPI images at 1
;                second intervals without user interaction required or allowed.
;
; cref         - (Optional) binary parameter, if set to ON, then plot PPIs of
;                Composite Reflectivity (highest reflectivity in the vertical
;                column) rather than reflectivity at the fixed sweep elevation
;                'elev2show' within the cross-section selector window.
;
; elev2show    - sweep number of PPIs to display, starting from 1 as the
;                lowest elevation angle in the volume.  Defaults to approximately
;                1/3 the way up the list of sweeps if unspecified.  Ignored if
;                'cref' parameter is set to ON.
;
; gif_path     - Optional file directory specification.  If specified, a GIF
;                image of the PPI pair will be written to this directory.
;
; hide_rntype  - (Optional) binary parameter, indicates whether to plot colored
;                bars along the top of the PR and GR cross-sections indicating
;                the PR and GR rain types identified for the given ray.
;
; ncpath       - Top-level directory under which to recursively search for
;                matchup netCDF files to be read and processed.  If not
;                specified, then a File Selector will be displayed with which
;                the user can select the starting path.
;
; no_prompt    - method by which the next file in the set of files defined by
;                ncpath and sitefilter is selected. Binary parameter. If unset,
;                defaults to DialogPickfile (pop-up file selector)
;
; pctAbvThresh - constraint on the percent of bins in the geometric-matching
;                volume that were above their respective thresholds, specified
;                at the time the geo-match dataset was created.  Essentially a
;                measure of "beam-filling goodness".  100 means plot only those
;                matchup points where all the DPR and GR bins in the volume
;                averages were above threshold (complete volume filled with
;                above threshold bin values).  0 means plot all matchup points
;                available, with no regard for thresholds (the default, if no
;                pctAbvThresh value is specified)
;
; pause        - parameter to specify dwell time (fractional seconds) between
;                steps when automatically displaying a sequence of cross
;                sections for all scans in the matchup set. Default=1 sec.
;                Also defines the dwell time between frames in the animated GIF
;                when the animation sequnce is written to a GIF file (see
;                gif_path parameter). NOT CURRENTLY USED, NO ANIMATED GIFs.
;
; sitefilter   - file pattern which acts as the filter limiting the set of input
;                files shown in the file selector, or over which the program
;                will iterate. Mode of selecting the (next) file depends on the
;                no_prompt parameter. Default = 'GRtoDPR.*.nc*'
;
;===============================================================================
; MODULE 2

pro dpr_geo_match_to_gif, ncfilepr, ELEV2SHOW=elev2show, $
                          PCT_ABV_THRESH=pctAbvThresh, CREF=cref, $
                          HIDE_RNTYPE=hide_rntype, PAUSE=pause, $
                          GIF_PATH=gif_path

; "Include" file for names, default paths, etc.:
@environs.inc
; "Include file for netCDF-read structs
@dpr_geo_match_nc_structs.inc

; set up pointers for each field to be returned from fprep_dpr_geo_match_profiles()
ptr_geometa=ptr_new(/allocate_heap)
ptr_sweepmeta=ptr_new(/allocate_heap)
ptr_sitemeta=ptr_new(/allocate_heap)
ptr_filesmeta=ptr_new(/allocate_heap)
ptr_fieldflags=ptr_new(/allocate_heap)
ptr_gvz=ptr_new(/allocate_heap)
ptr_zcor=ptr_new(/allocate_heap)
ptr_rnType=ptr_new(/allocate_heap)
ptr_pr_index=ptr_new(/allocate_heap)
ptr_xCorner=ptr_new(/allocate_heap)
ptr_yCorner=ptr_new(/allocate_heap)
ptr_pctgoodpr=ptr_new(/allocate_heap)
ptr_pctgoodgv=ptr_new(/allocate_heap)

; structure to hold bright band variables
BBparms = {meanBB : -99.99, BB_HgtLo : -99, BB_HgtHi : -99}

; Define the list of fixed-height levels for the vertical profile statistics
heights = [1.5,3.0,4.5,6.0,7.5,9.0,10.5,12.0,13.5,15.0,16.5,18.0,19.5]

print, 'pctAbvThresh = ', pctAbvThresh

; read the geometry-match variables and arrays from the file, and preprocess
; them to remove the 'bogus' PR ray positions.  Return a pointer to each
; variable read or computed.

status = fprep_dpr_geo_match_profiles( ncfilepr, $
   ; *** optional configuration/customization parameters ***
    heights, BBWIDTH=bbwidth, PCT_ABV_THRESH=pctAbvThresh, $
    GV_CONVECTIVE=0, GV_STRATIFORM=0, $
   ; *** matchup dataset metadata and global information ***
    PTRgeometa=ptr_geometa, PTRsweepmeta=ptr_sweepmeta, $
    PTRsitemeta=ptr_sitemeta, PTRfilesmeta=ptr_filesmeta, $
   ; *** science, geolocation, and derived datasets ***
    PTRfieldflags=ptr_fieldflags, PTRGVZMEAN=ptr_gvz, PTRzcor=ptr_zcor, $
    PTRtop=ptr_top, PTRbotm=ptr_botm, PTRbbProx=ptr_bbProx, $
    PTRxCorners=ptr_xCorner, PTRyCorners=ptr_yCorner, $
    PTRraintype_int=ptr_rnType, PTRpridx_long=ptr_pr_index, $
    PTRpctgoodpr=ptr_pctgoodpr, PTRpctgoodgv=ptr_pctgoodgv, $
    PTRpctgoodrain=ptr_pctgoodrain, BBPARMS=BBparms, ALT_BB_HGT=alt_bb_hgt )

IF (status EQ 1) THEN GOTO, errorExit

; create local data field arrays/structures needed here, and free pointers
; we no longer need in order to free the memory held by these pointer variables
  mygeometa=*ptr_geometa
    ptr_free,ptr_geometa
  mysite=*ptr_sitemeta
    ptr_free,ptr_sitemeta
  mysweeps=*ptr_sweepmeta
    ptr_free,ptr_sweepmeta
  myflags=*ptr_fieldflags
    ptr_free,ptr_fieldflags
  filesmeta=*ptr_filesmeta
    ptr_free,ptr_filesmeta
  gvz=*ptr_gvz
  gvz_in = gvz     ; 2nd copy for plotting as PPI
    ptr_free,ptr_gvz
  zcor=*ptr_zcor
  zcor_in = zcor   ; 2nd copy for plotting as PPI
    ptr_free,ptr_zcor
  rntype=*ptr_rnType
  pr_index=*ptr_pr_index
  xcorner=*ptr_xCorner
  ycorner=*ptr_yCorner
  pctgoodpr=*ptr_pctgoodpr
  pctgoodgv=*ptr_pctgoodgv
    ptr_free,ptr_rnType
    ptr_free,ptr_pr_index
    ptr_free,ptr_xCorner
    ptr_free,ptr_yCorner
    ptr_free,ptr_pctgoodpr
    ptr_free,ptr_pctgoodgv

DPR_scantype = mygeometa.DPR_scantype
nframes = mygeometa.num_sweeps
verstring = STRTRIM( STRING(mygeometa.DPR_Version), 2 )

;-------------------------------------------------

; PREPARE FIELDS NEEDED FOR PPI PLOTS:

; blank out reflectivity for samples not meeting 'percent complete' threshold

IF ( pctAbvThresh GT 0.0 ) THEN BEGIN
  ; clip to the 'good' points, where 'pctAbvThresh' fraction of bins in average
  ; were above threshold
   idxgoodenuff = WHERE( pctgoodpr GE pctAbvThresh $
                    AND  pctgoodgv GE pctAbvThresh, countgoodpct )
   IF ( countgoodpct GT 0 ) THEN BEGIN
      ;idxgoodenuff = idxexpgt0[idxgoodpct]
      ;idx2plot=idxgoodenuff
      n2plot=countgoodpct
   ENDIF ELSE BEGIN
      print, "No complete-volume points based on PctAbvThresh, quitting case."
      goto, errorExit
   ENDELSE
  ; blank out reflectivity for all samples not meeting completeness thresholds
   idx3d = pr_index      ; just for creation/sizing
   idx3d[*,*] = 0L       ; initialize all points to 0 (blank-out flag)
   idx3d[idxgoodenuff] = 2L  ; points to keep
   idx2blank = WHERE( idx3d EQ 0L, count2blank )
   IF ( count2blank GT 0 ) THEN BEGIN
     gvz[idx2blank] = 0.0
     zcor[idx2blank] = 0.0
   ENDIF
ENDIF

; extract rain type for the first sweep to make the single-level array
; for PPI plots generated in plot_sweep_2_zbuf()
rnTypeIn = rnType[*,0]
; if rain type "hiding" is on, set all samples to "Other" rain type
hide_rntype = KEYWORD_SET( hide_rntype )
IF hide_rntype THEN rnTypeIn[*,*] = 3

;-------------------------------------------------

; -- parse ncfile1 to get the component fields: site, orbit number, YYMMDD
dataPR = FILE_BASENAME(ncfilepr)
parsed=STRSPLIT( dataPR, '.', /extract )
frequency=parsed[5]        ; 'DPR', 'KA', or 'KU', from input GPM 2Axxx file
orbit = parsed[3]
DATESTAMP = parsed[2]      ; in YYMMDD format
ncsite = parsed[1]
; put the InstrumentID from the matchup filename into its PPS designation
CASE STRUPCASE(frequency) OF
    'KA' : freqName='Ka'
    'KU' : freqName='Ku'
   'DPR' : freqName='DPR'
    ELSE : freqName=''
ENDCASE
sourceLabel = freqName + "/" + STRUPCASE(DPR_scantype)
print, dataPR, " ", sourceLabel, " ", orbit, " ", DATESTAMP, " ", ncsite


; define a GIF file basename for this case
posdotnc = STRPOS(dataPR, '.nc', /REVERSE_SEARCH)
if posdotnc ne -1 $
   then gif_base = STRMID(datapr,0,posdotnc)+'.PPI_Pct'+$
                   STRING(pctAbvThresh,FORMAT='(i0)')+'.gif' $
   else message, "Can't file .nc substring in "+dataPR

; specify a GIF file to write the animation frames to if GIF_PATH is defined
IF N_ELEMENTS(gif_path) EQ 1 THEN BEGIN
   IF gif_path NE '' THEN BEGIN
      gif_file = GIF_PATH+'/' + gif_base
      have_gif = 0      ; flag, has GIF file been opened?
   ENDIF
ENDIF

;-------------------------------------------------

; Set up the pixmap window for the PPI plots
windowsize = 350
xsize = windowsize[0]
ysize = xsize
IF ( pctAbvThresh GT 0 ) THEN title = STRING(pctAbvThresh,FORMAT='(i0)')+ $
                                      "% above-threshold samples shown" $
ELSE title = "All available samples shown"
title=dataPR
window, 0, xsize=xsize*2, ysize=ysize, xpos = 75, TITLE = title ;, /PIXMAP

; hardwire the ground radar x and y coordinates in the window, don't know how to
; get these values from IDL based on the map projection setup vs. windowsize
x_gr = 175
y_gr = 170  ; close enough, can be 171 if southern hemisphere

error = 0
loadcolortable, 'CZ', error
if error then begin
    print, "error from loadcolortable"
    goto, errorExit
endif
tvlct, rr,gg,bb,/get

;-------------------------------------------------

; If a sweep number is not specified, pick one about 1/3 of the way up:
IF ( N_ELEMENTS(elev2show) EQ 1 ) THEN BEGIN
   IF (elev2show LE nframes) THEN ifram=elev2show-1>0 ELSE ifram=nframes-1>0
ENDIF ELSE ifram=nframes/3

; Build the 'true' PPI image buffers
cref = KEYWORD_SET(cref)
IF (cref) THEN BEGIN
   prtitle = frequency+"-band/"+DPR_scantype+"/"+verstring+" Composite Ze"
ENDIF ELSE BEGIN
   elevstr =  string(mysweeps[ifram].elevationAngle, FORMAT='(f0.1)')
   prtitle = frequency+"-band/"+DPR_scantype+"/"+verstring+ $
             " Ze along "+mysite.site_ID+" "+elevstr+" degree sweep"
ENDELSE
myprbuf = plot_sweep_2_zbuf( zcor, mysite.site_lat, mysite.site_lon, xCorner, $
                             yCorner, pr_index, mygeometa.num_footprints, ifram, $
                             rnTypeIn, WINSIZ=windowsize, TITLE=prtitle, $
                             MAXRNGKM=mygeometa.rangeThreshold, CREF=cref )

IF (cref) THEN gvtitle = mysite.site_ID+" Composite Ze, "+mysweeps[nframes/3].atimeSweepStart $
ELSE gvtitle = mysite.site_ID+" at "+elevstr+" deg., "+mysweeps[ifram].atimeSweepStart
mygvbuf = plot_sweep_2_zbuf( gvz, mysite.site_lat, mysite.site_lon, xCorner, $
                             yCorner, pr_index, mygeometa.num_footprints, ifram, $
                             rnTypeIn, WINSIZ=windowsize, TITLE=gvtitle, $
                             MAXRNGKM=mygeometa.rangeThreshold, CREF=cref )

; Render the PR and GR PPI plot
SET_PLOT, 'X'
device, decomposed=0, RETAIN=2

TV, myprbuf, 0
TV, mygvbuf, 1

IF N_ELEMENTS(gif_file) EQ 1 THEN BEGIN
   window, 1, xsize=xsize*2, ysize=ysize, TITLE = title, PIXMAP=1, RETAIN=2
   wset, 1
   loadct, 0, /SILENT
   TV, myprbuf, 0
   TV, mygvbuf, 1
   contents = TVRD()
   WRITE_GIF, gif_file, bytscl(contents), rr, gg, bb ;, /MULTIPLE, DELAY=FIX(pause*100), REPEAT=0
   WRITE_GIF, /CLOSE
   print, "GIF animation written to ", gif_file
ENDIF
WSET,0

errorExit:
end


;===============================================================================
; MODULE 1

pro dpr_geo_match_ppi_to_gif, ELEV2SHOW=elev2show, SITE=sitefilter, $
                              NO_PROMPT=no_prompt, NCPATH=ncpath, $
                              PCT_ABV_THRESH=pctAbvThresh, CREF=cref, $
                              HIDE_RNTYPE=hide_rntype, PAUSE=pause, $
                              GIF_PATH=gif_path, BATCH=batch

; "Include" file for matchup file prefixes:
@environs.inc

print

;  - No more default assignment of NCPATH if not specified, launch the File
;    Selector to specify the location in this case, starting from the default
;    location /data/gpmgv/netcdf/geo_match/GPM for DPR.
;
IF N_ELEMENTS(ncpath) EQ 0 THEN ncpath = $
   DIALOG_PICKFILE( PATH='/data/gpmgv/netcdf/geo_match/GPM', /DIRECTORY )
pathgeo = ncpath[0]

IF ( N_ELEMENTS(sitefilter) NE 1 ) THEN BEGIN
   print, "Defaulting to GRtoDPR.* for file pattern."
   print, ""
   ncfilepatt = 'GRtoDPR.*.nc*'
ENDIF ELSE BEGIN
   IF ( STRPOS(sitefilter, DPR_GEO_MATCH_PRE) NE 0 ) THEN $
      ncfilepatt = 'GRtoDPR*'+sitefilter+'*' $   ; add GR_to_DPR* prefix
   ELSE ncfilepatt = sitefilter+'*'              ; already have standard prefix
ENDELSE

; Decide which DPR and GR points to include, based on percent of expected points
; in bin-averaged results that were above dBZ thresholds set when the matchups
; were done.  If unspecified or set to zero, include all points regardless of
; 'completeness' of the volume averages.

IF ( N_ELEMENTS(pctAbvThresh) NE 1 ) THEN BEGIN
   print, "Defaulting to 0 for PERCENT BINS ABOVE THRESHOLD."
   pctAbvThresh = 0.0
ENDIF ELSE BEGIN
   pctAbvThresh = FLOAT(pctAbvThresh)
   IF ( pctAbvThresh LT 0.0 OR pctAbvThresh GT 100.0 ) THEN BEGIN
      print, "Invalid value for PCT_ABV_THRESH: ", pctAbvThresh, $
             ", must be between 0 and 100."
      print, "Defaulting to 0 for PERCENT BINS ABOVE THRESHOLD."
      pctAbvThresh = 0.0
   ENDIF
ENDELSE

; Figure out how the next file to process will be obtained.  If no_prompt is
; set, then we will automatically loop over the file sequence.  Otherwise we
; will prompt the user for the next file with dialog_pickfile() (DEFAULT).

no_prompt = keyword_set(no_prompt)

IF (no_prompt) THEN BEGIN

   prfiles = file_search(pathgeo, ncfilepatt, COUNT=nf)

   if nf eq 0 then begin
      print, 'No netCDF files matching file pattern: ', pathgeo+'/'+ncfilepatt
   endif else begin
      IF KEYWORD_SET(gif_path) AND KEYWORD_SET(batch) THEN ask=0 ELSE ask=1
      for fnum = 0, nf-1 do begin
         IF ask THEN BEGIN
           ; set up for bailout prompt every 5 cases if animating PPIs w/o file prompt
            doodah = ""
            IF fnum GT 0 THEN BEGIN
               PRINT, ''
               READ, doodah, $
               PROMPT='Hit Return to do next case, Q to Quit: '
            ENDIF
            IF doodah EQ 'Q' OR doodah EQ 'q' THEN break
         ENDIF
        ;
         ncfilepr = prfiles(fnum)
         dpr_geo_match_to_gif, ncfilepr, ELEV2SHOW=elev2show, $
                               PCT_ABV_THRESH=pctAbvThresh, CREF=cref, $
                               HIDE_RNTYPE=hide_rntype, PAUSE=pause, $
                               GIF_PATH=gif_path
         IF ask EQ 0 THEN BEGIN
            command = 'sleep 1'
            spawn, command
         ENDIF
      endfor
   endelse
ENDIF ELSE BEGIN
   print, ''
   print, 'Select a GRtoDPR* netCDF file from the file selector.'
   ncfilepr = dialog_pickfile(path=pathgeo, filter = ncfilepatt, $
                              Title='Select a GRtoDPR* netCDF file:')
   while ncfilepr ne '' do begin
      dpr_geo_match_to_gif, ncfilepr, ELEV2SHOW=elev2show, $
                            PCT_ABV_THRESH=pctAbvThresh, CREF=cref, $
                            HIDE_RNTYPE=hide_rntype, PAUSE=pause, $
                            GIF_PATH=gif_path

      ncfilepr = dialog_pickfile(path=pathgeo, filter = ncfilepatt, $
                                 Title='Select a GRtoDPR* netCDF file:')
   endwhile
ENDELSE

WDELETE,0

print, "" & print, "Done!"
END
