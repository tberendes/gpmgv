;===============================================================================
;+
; Copyright © 2014, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; dpr_and_geo_match_x_sections.pro    Morris/SAIC/GPM_GV    May 2014
;
; DESCRIPTION
; -----------
; Driver for gen_dpr_and_geo_match_x_sections (included).  Sets up user/default
; parameters defining the displayed PPIs, and the method by which the next
; case is selected: either prompt the user to select the file, or just take the
; next one in the sequence.
;
; PARAMETERS
; ----------
; elev2show    - sweep number of PPIs to display, starting from 1 as the
;                lowest elevation angle in the volume.  Defaults to approximately
;                1/3 the way up the list of sweeps if unspecified
;
; sitefilter   - file pattern which acts as the filter limiting the set of input
;                files shown in the file selector, or over which the program
;                will iterate. Mode of selecting the (next) file depends on the
;                no_prompt parameter. Default=*
;
; no_prompt    - method by which the next file in the set of files defined by
;                ncpath and sitefilter is selected. Binary parameter. If unset,
;                defaults to DialogPickfile (pop-up file selector)
;
; ncpath       - local directory path to the geo_match netCDF files' location.
;                Defaults to /data/netcdf/geo_match
;
; prpath       - local directory path to the original DPR product files root
;                (in-common) directory.  Defaults to /data/prsubsets
;
; ufpath       - local directory path to the original GR radar UF file root
;                (in-common) directory.  Defaults to /data/gv_radar/finalQC_in
;
; use_db       - Binary parameter.  If set, then query the 'gpmgv' database to
;                find the 2A(DPR|Ka|Ku|) product file that corresponds to the
;                geo_match netCDF file being rendered.  Otherwise, generate
;                a 'guess' of the filename pattern and search under the
;                directory prpath (default mode)
;
; show_orig    - Binary parameter.  If unset, then the full-vertical-resolution
;                cross sections from the original DPR data will NOT be plotted.
;                This means the program can be run using only the geo_match
;                netCDF data files.
;
; pctAbvThresh - constraint on the percent of bins in the geometric-matching
;                volume that were above their respective thresholds, specified
;                at the time the geo-match dataset was created.  Essentially a
;                measure of "beam-filling goodness".  100 means use only those
;                matchup points where all the DPR and GR bins in the volume
;                averages were above threshold (complete volume filled with
;                above threshold bin values).  0 means use all matchup points
;                available, with no regard for thresholds (the default, if no
;                pctAbvThresh value is specified)
;
; BBbyRay      - Binary parameter.  If set, then plot individual bright band
;                height lines for each ray in the optional full-resolution PR
;                cross section plots, using each ray's BB height as
;                specified in the 2Axxx BBheight variable.
;
; plotBBsep    - (Optional) binary parameter, indicates whether to plot a
;                delimiter between within-BB volumes and adjacent above and
;                below-BB volumes in DPR and GR volume-match x-sections.
;
; bbwidth      - Height (km) above/below the mean bright band height within
;                which a sample touching (above) [below] this layer is
;                considered to be within (above) [below] the BB.  If not
;                specified, takes on the default value (0.750) defined in
;                fprep_geo_match_profiles().
;
; alt_bb_hgt   - Manually-specified Bright Band Height (km) to be used if the
;                bright band height cannot be determined from the DPR data.
;
; hide_rntype  - (Optional) binary parameter, indicates whether to plot colored
;                bars along the top of the PR and GR cross-sections indicating
;                the PR and GR rain types identified for the given ray.
;
; cref         - (Optional) binary parameter, if set to ON, then plot PPIs of
;                Composite Reflectivity (highest reflectivity in the vertical
;                column) rather than reflectivity at the fixed sweep elevation
;                'elev2show' within the cross-section selector window.
;
; pause        - parameter to specify dwell time (fractional seconds) between
;                steps when automatically displaying a sequence of cross
;                sections for all scans in the matchup set. Default=1 sec.
;
; zoomh        - parameter to explicitly control the width and location of how
;                the rays are plotted in the cross section window.  Valid values
;                are 0, 1, or 2, where 0 means to configure the plot as if all 49
;                rays in a scan were present, regardless of the number of rays
;                in the overlap area for any scan, and plot each ray with a
;                fixed width and at a fixed location based on its ray number;
;                1 means to configure the plot according to the scan with the
;                most number of rays in the PR/GR overlap area, and plot each ray
;                with a fixed width, and at a fixed location based on ray number;
;                and 2 is the legacy behavior to individually configure the cross
;                section for each scan to be plotted according to the number of
;                rays in the overlap area (full zoom to fit the cross section
;                window, where the plotted ray width and location vary for each
;                scan).  If not set, then defaults to 2 (legacy behavior). The
;                automatic display of a sequence of cross sections temporarily
;                overrides the legacy behavior to that of a zoomh value of 1,
;                whether or not zoomh is actually set to 2 in the inputs.
;
; label_by_raynum - parameter to explicitly control the type of label plotted
;                   at the endpoints of the cross section. If unset, uses the
;                   default legacy behavior to plot 'A' at the left/lowest ray
;                   to be plotted, and 'B' at the other right/highest ray.
;                   If set, then plots the actual ray numbers at the either end
;                   on the PPI location selector and the cross sections.
;
; rhi_mode     - Binary parameter.  If set, then draw the cross sections along a
;                line anchored at one end at the ground radar location through a
;                point selected by the cursor, and extending to the edge of the
;                data coverage (max range or edge of the DPR swath).
;
; verbose      - Binary parameter.  If set, then print position coordinates for
;                user-selected x-sect locations on the PPIs, in terms of window
;                coordinates and computed DPR data array scan,ray coordinates.
;
; recall_ncpath - Binary parameter.  If set, assigns the last file path used to
;                 select a file in dialog_pickfile() to a user-defined system
;                 variable that stays in effect for the IDL session.  Also, if
;                 set and if the user variable exists from a previous selection,
;                 then the user variable will override the NCPATH parameter
;                 value on program startup.
;
; INTERNAL MODULES
; ----------------
; 1) dpr_and_geo_match_x_sections - Main driver procedure called by user.
;
; 2) gen_dpr_and_geo_match_x_sections - Workhorse procedure to read data,
;                                       create plots, and allow interactive
;                                       selection of cross section locations on
;                                       the DPR or GR PPI plots displayed.
;
; 3) plot_sweep_2_zbuf_4xsec - Generates a pseudo-PPI of scan and ray number to
;                              allow determination of cross section location
;                              in terms of the original DPR dataset array
;                              coordinates.
;
; 4) gv_z_s2ku_4xsec - Applies S-band to Ku-band adjustment to the copy of GR
;                      reflectivity to be rendered in current x-section.
;
; 5) undefine - Undefines an IDL variable 'varname' passed to it.
;
; 6) parse_2a_filename - Extract the version/subset/year/month/day components
;    from a 2A GPM filename
;
; HISTORY
; -------
; 07/12/13 Morris, GPM GV, SAIC
; - Created from pr_and_geo_match_x_sections.pro
; 04/30/14 Morris, GPM GV, SAIC
; - Added parse_2a_filename to build lower path elements to the original 2A
;   DPR/Ku/Ka data files.  Fixed logic to identify which file type was used.
; - Fixed scale factor for DPR/Ku/Ka reflectivity.
; 06/24/14 Morris, GPM GV, SAIC
; - Added capability to specify a mean bright band height to be used if one
;   cannot be extracted from the DPR bright band field in the matchup files.
; 08/05/14 Morris, GPM GV, SAIC
; - Fixed situation where scaledpr was undefined if immediately jumping to the
;   automated step-through of the DPR scans in the matchup area.
; 08/13/14 Morris, GPM GV, SAIC
; - Added preliminary version of the capability to plot a cross section along a
;   GR radial.
; 08/25/14 Morris, GPM GV, SAIC
; - Disabled auto-scan by DPR scan number when in RHI mode.  Adjusted user
;   "Next actions" messages to only list valid options for RHI mode.
; - Renamed internal procedure gen_pr_and_geo_match_x_sections to
;   gen_dpr_and_geo_match_x_sections to avoid possible conflicts when running
;   pr_and_geo_match_x_sections before/after this procedure.
; 03/12/15 Morris, GPM GV, SAIC
; - Fixed bug where BB_hgt array from the original DPR file was not cut out
;   along the RHI line before being passed to PLOT_DPR_XSECTION_ZBUF().
; - Added logic to reset path in dialog_pickfile to the last selected filepath
;   now that we have a complicated directory structure for matchup files.
; - Added RECALL_NCPATH keyword and logic to define a user-defined system
;   variable to remember and use the last-selected file path to override the
;   NCPATH and/or the default netCDF file path on startup of the procedure, if
;   the RECALL_NCPATH keyword is set and user system variable is defined in the
;   IDL session.
; - Defined this as Version 1.1 of the procedure.
;
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;===============================================================================

; MODULE #6

; extract the needed path version/subset/year/month/day from
; a 2A GPM filename, e.g., compose path = 'V01D/CONUS/2014/04/20' from
; 2A-CS-CONUS.GPM.Ku.V5-20140401.20140420-S082058-E082715.000804.V01D.HDF5

  FUNCTION parse_2a_filename, origFileName

  parsed = STRSPLIT(origFileName, '.', /EXTRACT)
  parsed2 = STRSPLIT(parsed[0], '-', /EXTRACT)
  subset = parsed2[2]
  version = parsed[6]
  yyyymmdd = STRMID(parsed[4],0,4)+'/'+STRMID(parsed[4],4,2)+'/'+STRMID(parsed[4],6,2)
  path = version+'/'+subset+'/'+yyyymmdd
  return, path

  end

;===============================================================================

; MODULE #5

; Undefines an IDL variable 'varname' passed to this procedure - this works
; because the TEMPORARY function returns a copy of the variable given as its
; argument, sets the argument variable to UNDEFINED, and frees its memory

PRO undefine, varname
On_Error, 1
IF N_PARAMS() EQ 0 THEN $
   message, 'One argument required to call UNDEFINE procedure'
tempvar = SIZE(TEMPORARY(varname))
end

;===============================================================================

; MODULE #4

PRO gv_z_s2ku_4xsec, gvz, bbprox, idx2adj

; DESCRIPTION
; -----------
; Applies S-to-Ku frequency adjustment to GR reflectivity field 'gvz', according
; to proximity to Bright Band as defined in 'bbprox'.  Only modify the subset
; of points defined by array indices in 'idx2adj'.

; get the points with valid dBZs -- likewise, clip BB proximity array
 gvz2adj = gvz[idx2adj]
 bbprox4xsec = bbProx[idx2adj]

; grab the above and below BB points, respectively
 idxsnow4xsec = where( bbprox4xsec EQ 3, snocount )
 idxrain4xsec = where( bbprox4xsec EQ 1, rncount )

; adjust S-band reflectivity for above and below BB
 if snocount GT 0 then begin
  ; grab the above-bb points of the GR reflectivity
    gvz4snow = gvz2adj[idxsnow4xsec]
  ; perform the conversion and replace the original values
    gvz2adj[idxsnow4xsec] = s_band_to_ku_band( gvz4snow, 'S' )
 endif
 if rncount GT 0 then begin   ; adjust the below-BB points
    gvz4rain = gvz2adj[idxrain4xsec]
    gvz2adj[idxrain4xsec] = s_band_to_ku_band( gvz4rain, 'R' )
 endif

; copy back the rain/snow adjusted values
 gvz[idx2adj] = gvz2adj

end

;===============================================================================

; MODULE #3

FUNCTION plot_sweep_2_zbuf_4xsec, zdata, radar_lat, radar_lon, xpoly, ypoly, $
                            pr_index, nfootprints, ifram, MAXRNGKM=maxrngkm, $
                            WINSIZ=winsiz, NOCOLOR=nocolor, TITLE=title

; DESCRIPTION
; -----------
; Generates a pseudo-PPI of scan and ray number to allow determination of cross
; section location in terms of the original DPR array coordinates.


;IF N_ELEMENTS( title ) EQ 0 THEN BEGIN
;  title = 'level ' + STRING(ifram+1)
;ENDIF
;print, title

; Declare function for color plotting.  It is in loadcolortable.pro.
forward_function mapcolors
SET_PLOT,'Z'
winsize = 525
IF ( N_ELEMENTS(winsiz) EQ 1 ) THEN winsize = winsiz
xsize = winsize & ysize = xsize
DEVICE, SET_RESOLUTION = [xsize,ysize], SET_CHARACTER_SIZE=[6,10]
error = 0
charsize = 0.75

;ilev = 0  ; sweep # to plot

nocolor = keyword_set(nocolor)  ; if set, don't map zdata to color ranges

IF N_ELEMENTS( maxrngkm ) EQ 1 THEN maxrange = ( FIX(maxrngkm) / 25 + 1 ) * 25.0 $
ELSE maxrange = 125. ; kilometers


; Get the map boundaries corresponding to maxrange.
maxrange_meters = maxrange * 1000.
meters_to_lat = 1. / 111177.
meters_to_lon =  1. / (111177. * cos(radar_lat * !dtor))

nb = radar_lat + maxrange_meters * meters_to_lat 
sb = radar_lat - maxrange_meters * meters_to_lat 
eb = radar_lon + maxrange_meters * meters_to_lon 
wb = radar_lon - maxrange_meters * meters_to_lon 

map_set, radar_lat, radar_lon, limit=[sb,wb,nb,eb],/grid, advance=advance, $
    charsize=charsize,color=color

npts = 4
x = fltarr(npts)
y = fltarr(npts)
lat = fltarr(npts)
lon = fltarr(npts)

ray = zdata[*]
inegidx = where( ray lt 0, countneg )
if countneg gt 0 then ray[inegidx] = 0.0

if keyword_set(bgwhite) then begin
    prev_background = !p.background
    !p.background = 255
endif
if !p.background eq 255 then color = 0

IF ( nocolor ) THEN BEGIN
   color_index = ray
ENDIF ELSE BEGIN
   loadcolortable, 'CZ', error
   if error then begin
       print, "error from loadcolortable"
       goto, bailout
   endif

   color_index = mapcolors(ray, 'CZ')
   if size(color_index,/n_dimensions) eq 0 then begin
       print, "error from mapcolors in PR array"
       goto, bailout
   endif
ENDELSE

for ifoot = 0, nfootprints-1 do begin
   IF ( pr_index[ifoot] LT 0 ) THEN CONTINUE
   x = xpoly[*,ifoot,ifram]
   y = ypoly[*,ifoot,ifram]
  ; Convert points to latitude and longitude coordinates.
   lon = radar_lon + meters_to_lon * x * 1000.
   lat = radar_lat + meters_to_lat * y * 1000.
   polyfill, lon, lat, color=color_index[ifoot],/data
endfor

IF ( nocolor NE 1 ) THEN BEGIN
map_grid, /label, lonlab=sb, latlab=wb, latalign=0.0,/noerase, $
    charsize=charsize, color=color
map_continents,/hires,/usa,/coasts,/countries, color=color

for range = 50.,maxrange,50. do $
    plot_range_rings2, range, radar_lon, radar_lat, color=color

vn_colorbar, 'CZ', charsize=charsize, color=color
ENDIF

; add image labels
;   xyouts, 5, ysize-15, title, CHARSIZE=charsize, COLOR=255, /DEVICE

bufout = TVRD()

bailout:

return, bufout
end

;===============================================================================

; MODULE #2

pro gen_dpr_and_geo_match_x_sections, ncfilepr, use_db, skip_orig_in, $
                  ELEV2SHOW=elev2show, PCT_ABV_THRESH=pctAbvThresh, $
                  PR_ROOT_PATH=pr_root_path, UFPATH=ufpath, BBBYRAY=BBbyRay, $
                  PLOTBBSEP=plotBBsep, BBWIDTH=bbwidth, $
                  ALT_BB_HGT=alt_bb_hgt, CREF=cref, RHI_MODE=rhi_mode, $
                  HIDE_RNTYPE=hide_rntype, PAUSE=pause, ZOOMH=zoomh, $
                  LABEL_BY_RAYNUM=label_by_raynum, VERBOSE=verbose
;
;
; DESCRIPTION
; -----------
; Called from dpr_and_geo_match_x_sections procedure (included in this file).
; Reads DPR and GR reflectivity and spatial fields from a selected geo_match
; netCDF file, and builds a PPI of the data for a given elevation sweep.  Then
; allows a user to select a point on the image for which vertical cross
; sections along the PR scan line through the selected point will be plotted 
; from volume-matched PR and GR data, and if skip_orig is 0, also plots cross
; sections of full-resolution PR data.
;
; Plots two labeled "hot corners" in the upper right of the GR PPI image.  When
; the user clicks in one of these hot corners and a cross section is already on
; the display, the GR geo-match reflectivity data is incremented or decremented
; by the labeled amount and the geo-match cross section and difference cross
; section are redrawn with the reflectivity offset applied to the GR data.  This
; offset remains in place as long as the current case is being displayed, and
; resets to zero when a new case is selected. 
;
; Also plots a 'hot corner' in the lower left corner of the GR PPI image.  When
; the user clicks in this hot corner, an animation sequence of volume-matched
; DPR and GR data and full-resolution GR data from the original radar UF file
; is generated, and permits the user to assess the quality of the geo-alignment
; between the DPR and GR data.
;

;COMMON sample, start_sample, sample_range, num_range, RAYSPERSCAN

; "Include" file for DPR-product-specific parameters (i.e., RAYSPERSCAN):
@dpr_params.inc
; "Include" file for names, default paths, etc.:
@environs.inc
; "Include file for netCDF-read structs
@geo_match_nc_structs.inc

!EXCEPT = 0   ; print errors when/where they occur (LINFIT reports problems as-used)

; Override default path to PR product files if specified in PR_ROOT_PATH
IF ( N_ELEMENTS( pr_root_path ) EQ 1 ) THEN BEGIN
   print, 'Overriding default path to DPR files: ', PRDATA_ROOT, ', to: ', $
          pr_root_path
   PRDATA_ROOT = pr_root_path
ENDIF

; set this module's skip_orig value to the passed-in value, as we may have reset
; it if the last 2Axxx file couldn't be found
skip_orig = skip_orig_in

; set up pointers for each field to be returned from fprep_dpr_geo_match_profiles()
ptr_geometa=ptr_new(/allocate_heap)
ptr_sweepmeta=ptr_new(/allocate_heap)
ptr_sitemeta=ptr_new(/allocate_heap)
ptr_filesmeta=ptr_new(/allocate_heap)
ptr_fieldflags=ptr_new(/allocate_heap)
ptr_gvz=ptr_new(/allocate_heap)
ptr_zcor=ptr_new(/allocate_heap)
ptr_top=ptr_new(/allocate_heap)
ptr_botm=ptr_new(/allocate_heap)
ptr_rnType=ptr_new(/allocate_heap)
ptr_pr_index=ptr_new(/allocate_heap)
ptr_xCorner=ptr_new(/allocate_heap)
ptr_yCorner=ptr_new(/allocate_heap)
ptr_bbProx=ptr_new(/allocate_heap)
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
  top=*ptr_top
  botm=*ptr_botm
  rntype=*ptr_rnType
  pr_index=*ptr_pr_index
  xcorner=*ptr_xCorner
  ycorner=*ptr_yCorner
  bbProx=*ptr_bbProx
  pctgoodpr=*ptr_pctgoodpr
  pctgoodgv=*ptr_pctgoodgv
    ptr_free,ptr_top
    ptr_free,ptr_botm
    ptr_free,ptr_rnType
    ptr_free,ptr_pr_index
    ptr_free,ptr_xCorner
    ptr_free,ptr_yCorner
    ptr_free,ptr_bbProx
    ptr_free,ptr_pctgoodpr
    ptr_free,ptr_pctgoodgv

nframes = mygeometa.num_sweeps
DPR_scantype = mygeometa.DPR_scantype
CASE STRUPCASE(DPR_scantype) OF
   'HS' : BEGIN
             RAYSPERSCAN = RAYSPERSCAN_HS
             GATE_SPACE = BIN_SPACE_HS
          END
   'MS' : BEGIN
             RAYSPERSCAN = RAYSPERSCAN_MS
             GATE_SPACE = BIN_SPACE_NS_MS
         END
   'NS' : BEGIN
             RAYSPERSCAN = RAYSPERSCAN_NS
             GATE_SPACE = BIN_SPACE_NS_MS
          END
   ELSE : message, "Illegal scan type '"+DPR_scantype+"'"
ENDCASE

;-------------------------------------------------

; PREPARE FIELDS NEEDED FOR PPI PLOTS AND GEO_MATCH CROSS SECTIONS:

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

; get the indices of all remaining 'valid' GR points, so that we can
; do the interactive calibration adjustment on these only
idx2adj = WHERE( gvz GT 0.0 )

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

; put together a title field for the cross-sections
verstring = STRTRIM( STRING(mygeometa.DPR_Version), 2 )
caseTitle25 = ncsite+'/'+DATESTAMP + ', '+verstring + ', Orbit '+orbit
IF ( pctAbvThresh EQ 0.0 ) THEN BEGIN
   caseTitle = caseTitle25+", All Points"
ENDIF ELSE BEGIN
   caseTitle = caseTitle25+", "+STRING(pctAbvThresh,FORMAT='(i0)')+ $
               "% bins > Threshold"
ENDELSE

; Identify the original DPR filename for this orbit/subset, if plotting
; full-resolution DPR data cross sections:

IF ( skip_orig NE 1 ) THEN BEGIN
   ; put the file names in the filesmeta struct into a searchable array
   dprFileMatch=[filesmeta.FILE_2ADPR, filesmeta.FILE_2AKA, $
                 filesmeta.FILE_2AKU, filesmeta.FILE_2BCOMB ]
;   startpath = '/data/gpmgv'
;   dprFileMatch = DIALOG_PICKFILE(PATH=startpath, $
;                                  FILTER='*GPM.'+freqName+'*'+orbit+'*', $
;                                  TITLE='Select a DPR/Ka/Ku file')

  ; find the matchup input filename with the expected non-missing pattern
  ; and, for now, set a default instrumentID and scan type
   nfoundDPR=0
   idxDPR = WHERE(STRMATCH(dprFileMatch,'2A*.GPM.DPR.*') EQ 1, countDPR)
   if countDPR EQ 1 THEN BEGIN
      origFileDPRName = dprFileMatch[idxDPR]
      Instrument_ID='DPR'
      nfoundDPR++
   ENDIF ELSE origFileDPRName='no_2ADPR_file'

   idxKU = WHERE(STRMATCH(dprFileMatch,'2A*.GPM.Ku.*') EQ 1, countKU)
   if countKU EQ 1 THEN BEGIN
       origFileKuName = dprFileMatch[idxKU]
      Instrument_ID='Ku'
      nfoundDPR++
   ENDIF ELSE origFileKuName='no_2AKU_file'

   idxKA = WHERE(STRMATCH(dprFileMatch,'2A*.GPM.Ka.*') EQ 1, countKA)
   if countKA EQ 1 THEN BEGIN
       origFileKaName = dprFileMatch[idxKA]
       Instrument_ID='Ka'
      nfoundDPR++
   ENDIF ELSE origFileKaName='no_2AKA_file'

   idxCMB = WHERE(STRMATCH(dprFileMatch,'2B*.GPM.COMB.*') EQ 1, countCMB)
   if countCMB EQ 1 THEN origFileCMBName = dprFileMatch[idxCMB] $
      ELSE origFileCMBName='no_2BCMB_file'

   IF ( origFileKaName EQ 'no_2AKA_file' AND $
        origFileKuName EQ 'no_2AKU_file' AND $
        origFileDPRName EQ 'no_2ADPR_file' ) THEN BEGIN
      skip_orig=1
      PRINT, ""
      message, "ERROR finding a 2A-DPR, 2A-KA , or 2A-KU file name", /INFO
      GOTO, skipdprread
   ENDIF

   IF nfoundDPR NE 1 THEN BEGIN
      skip_orig=1
      PRINT, ""
      message, "ERROR finding just one 2A-DPR, 2A-KA , or 2A-KU file name", /INFO
      GOTO, skipdprread
   ENDIF

  ; extract the needed path elements version, subset, year, month, and day from
  ; the 2A filename, e.g.,
  ; 2A-CS-CONUS.GPM.Ku.V5-20140401.20140420-S082058-E082715.000804.V01D.HDF5,
  ; and add the well-known (or local) paths to get the fully-qualified file names

   CASE Instrument_ID OF
      'DPR' : BEGIN
                 path_tail = parse_2a_filename( origFileDPRName )
                 file_2adpr = GPMDATA_ROOT+DIR_2ADPR+"/"+path_tail+'/'+origFileDPRName
print, "Reading DPR from ",file_2adpr
              END
       'Ku' : BEGIN
                 path_tail = parse_2a_filename( origFileKuName )
                 file_2aku = GPMDATA_ROOT+DIR_2AKU+"/"+path_tail+"/"+origFileKuName
print, "Reading DPR from ",file_2aku
              END
       'Ka' : BEGIN
                 path_tail = parse_2a_filename( origFileKaName )
                 file_2aka = GPMDATA_ROOT+DIR_2AKA+"/"+path_tail+"/"+origFileKaName
print, "Reading DPR from ",file_2aka
              END
   ENDCASE

   ; check Instrument_ID and DPR_scantype consistency
   CASE STRUPCASE(Instrument_ID) OF
       'KA' : BEGIN
                 ; do we have a 2AKA filename?
                 IF FILE_BASENAME(origFileKaName) EQ 'no_2AKA_file' THEN $
                    message, "KA specified on control file line, but no " + $
                             "valid 2A-KA file name: " + dataPR
                 ; 2AKA has only HS and MS scan/swath types
                 CASE STRUPCASE(DPR_scantype) OF
                    'HS' : 
                    'MS' : 
                    ELSE : message,"Illegal scan type '"+DPR_scantype+"' for KA"
                 ENDCASE
                 dpr_data = read_2akaku_hdf5(file_2aka, SCAN=DPR_scantype)
                 dpr_file_read = origFileKaName
              END
       'KU' : BEGIN
                 IF FILE_BASENAME(origFileKaName) EQ 'no_2AKU_file' THEN $
                    message, "KU specified on control file line, but no " + $
                             "valid 2A-KU file name: " + dataPR
                 ; 2AKU has only NS scan/swath type
                 CASE STRUPCASE(DPR_scantype) OF
                    'NS' : BEGIN
                              dpr_data = read_2akaku_hdf5(file_2aku, $
                                         SCAN=DPR_scantype)
                              dpr_file_read = origFileKuName
                           END
                    ELSE : message,"Illegal scan type '"+DPR_scantype+"' for KU"
                  ENDCASE            
              END
      'DPR' : BEGIN
                 IF FILE_BASENAME(origFileKaName) EQ 'no_2ADPR_file' THEN $
                    message, "DPR specified on control file line, but no " + $
                             "valid 2ADPR file name: " + dataPR
                 ; 2ADPR has all 3 scan/swath types
                 CASE STRUPCASE(DPR_scantype) OF
                    'HS' : 
                    'MS' : 
                    'NS' : 
                    ELSE : message, "Illegal scan type '"+DPR_scantype+"'"
                 ENDCASE
                 dpr_data = read_2adpr_hdf5(file_2adpr, SCAN=DPR_scantype)
                 dpr_file_read = origFileDPRName
              END
   ENDCASE

   ; check dpr_data structure for read failures
   IF SIZE(dpr_data, /TYPE) NE 8 THEN $
     message, "Error reading data from: "+dpr_file_read

   ; get the group structures for the specified scantype, tags vary by swathname
   CASE STRUPCASE(DPR_scantype) OF
      'HS' : ptr_swath = dpr_data.HS
      'MS' : ptr_swath = dpr_data.MS
      'NS' : ptr_swath = dpr_data.NS
   ENDCASE
   ; get the number of scans in the dataset
   SAMPLE_RANGE_DPR = ptr_swath.SWATHHEADER.NUMBERSCANSBEFOREGRANULE $
                    + ptr_swath.SWATHHEADER.NUMBERSCANSGRANULE $
                    + ptr_swath.SWATHHEADER.NUMBERSCANSAFTERGRANULE

   ; extract DPR variables/arrays from struct pointers
   IF PTR_VALID(ptr_swath.PTR_DATASETS) THEN BEGIN
      dprlons = (*ptr_swath.PTR_DATASETS).LONGITUDE
      dprlats = (*ptr_swath.PTR_DATASETS).LATITUDE
      ptr_free, ptr_swath.PTR_DATASETS
   ENDIF ELSE message, "Invalid pointer to PTR_DATASETS."

   IF PTR_VALID(ptr_swath.PTR_CSF) THEN BEGIN
      BB_hgt = (*ptr_swath.PTR_CSF).HEIGHTBB
      bbstatus = (*ptr_swath.PTR_CSF).QUALITYBB       ; got to convert to TRMM?
      rainType = (*ptr_swath.PTR_CSF).TYPEPRECIP      ; got to convert to TRMM?
   ENDIF ELSE message, "Invalid pointer to PTR_CSF."
   rainType = TEMPORARY(rainType)/100000L      ; truncate to TRMM 3-digit type

   IF PTR_VALID(ptr_swath.PTR_PRE) THEN BEGIN
      dbz_meas = (*ptr_swath.PTR_PRE).ZFACTORMEASURED
      binRealSurface = (*ptr_swath.PTR_PRE).BINREALSURFACE
      binClutterFreeBottom = (*ptr_swath.PTR_PRE).binClutterFreeBottom
      localZenithAngle = (*ptr_swath.PTR_PRE).localZenithAngle
   ENDIF ELSE message, "Invalid pointer to PTR_PRE."

   IF PTR_VALID(ptr_swath.PTR_SLV) THEN BEGIN
      dbz_corr = (*ptr_swath.PTR_SLV).ZFACTORCORRECTED
   ENDIF ELSE message, "Invalid pointer to PTR_SLV."

   IF PTR_VALID(ptr_swath.PTR_FLG) THEN BEGIN
      flagEcho = (*ptr_swath.PTR_FLG).flagEcho
      qualityData = (*ptr_swath.PTR_FLG).qualityData
   ENDIF ELSE message, "Invalid pointer to PTR_FLG."

   IF PTR_VALID(ptr_swath.PTR_SRT) THEN BEGIN
   ENDIF ELSE message, "Invalid pointer to PTR_SRT."

   IF PTR_VALID(ptr_swath.PTR_VER) THEN BEGIN
   ENDIF ELSE message, "Invalid pointer to PTR_VER."

   ; free the memory/pointers in data structure
   free_ptrs_in_struct, dpr_data ;, /ver

   ; precompute the reuseable ray angle trig variables for parallax -- in GPM,
   ; we have the local zenith angle for every ray/scan (i.e., footprint)
   cos_inc_angle = COS( 3.1415926D * localZenithAngle / 180. )

   skipdprread:
ENDIF

;-------------------------------------------------

; compute a rain type from the GR vertical profiles
meanBBgr = -99.99
gvrtype = get_gr_geo_match_rain_type( pr_index, gvz_in, top, botm, SINGLESCAN=0, $
                                      VERBOSE=0, MEANBB=meanBBgr )
; if rain type "hiding" is on, set all samples to "Other" rain type
IF hide_rntype THEN BEGIN
gvrtype[*,*] = 3
print, '' & print, "Hiding rain type for GR." & print, ''
ENDIF

;-------------------------------------------------

; make copies of the plot input arrays if doing RHI cross sections
IF KEYWORD_SET(rhi_mode) THEN BEGIN
   gvzCopy = gvz
   zcorCopy = zcor
   topCopy = top
   botmCopy = botm
   rntypeCopy = rntype
   bbproxCopy = bbprox
   gvrtypeCopy = gvrtype
   ; copy full-resolution DPR arrays only if plotting them
   IF ( skip_orig NE 1 ) THEN BEGIN
      BB_hgtCopy = BB_hgt
      rainTypeCopy = rainType
      dbz_measCopy = dbz_meas
      dbz_corrCopy = dbz_corr
      binRealSurfaceCopy = binRealSurface
      binClutterFreeBottomCopy = binClutterFreeBottom
      cos_inc_angleCopy = cos_inc_angle
   ENDIF
   ; grab one sweep of pr_index for later use in slicing along radial
   pr_index_slice = REFORM( pr_index[*,0] )
ENDIF

;-------------------------------------------------

print, "Mean BB (AGL) from PR: ", STRING(BBparms.meanBB, FORMAT='(F0.1)') & print, ""

;-------------------------------------------------

; Set up the pixmap window for the PPI plots
windowsize = 350
xsize = windowsize[0]
ysize = xsize
IF ( pctAbvThresh GT 0 ) THEN title0 = STRING(pctAbvThresh,FORMAT='(i0)')+ $
                                      "% above-threshold samples shown" $
ELSE title0 = "All available samples shown"
window, 0, xsize=xsize, ysize=ysize*2, xpos = 75, TITLE = title0, /PIXMAP

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
                             gvrtype, WINSIZ=windowsize, TITLE=gvtitle, $
                             MAXRNGKM=mygeometa.rangeThreshold, CREF=cref )
; grab 'clean' PPIs without burn-ins
myprbufClean = myprbuf
mygvbufClean = mygvbuf
myprbufClean[WHERE(myprbuf EQ 255b)] = 122b  ; set up for merged color tables
mygvbufClean[WHERE(mygvbuf EQ 255b)] = 122b

; add a "hot corner" to the GR image to click on to initiate alignment check
mygvbuf[0:20,0:20] = 254B
; add a hot corner to subtract 1 dBZ from GR and re-run x-sect differences
mygvbuf[windowsize-41:windowsize-22,windowsize-20:windowsize-1] = 253B
; add a hot corner to add 1 dBZ to GR and re-run x-sect differences
mygvbuf[windowsize-20:windowsize-1,windowsize-20:windowsize-1] = 252B
; add a hot corner to toggle between original and Ku-adjusted GR reflectivity
mygvbuf[windowsize-62:windowsize-43,windowsize-20:windowsize-1] = 251B
; add a "hot corner" to initiate cross-section step-through animation
IF KEYWORD_SET(rhi_mode) EQ 0 THEN mygvbuf[22:41,0:20] = 250B


;-------------------------------------------------

; Build the corresponding PR scan and ray number buffers (not displayed).  Need
; to cut one layer out of pr_index, which has been replicated over each sweep
; level by fprep_geo_match_profiles():
pr_scan = pr_index[*,0] & pr_ray = pr_index[*,0]
idx2get = WHERE( pr_index[*,0] GE 0 )  ; this should be ALL points if from fprep_geo_match_profiles()
pridx2get = pr_index[idx2get,0]

; analyze the pr_index, decomposed into DPR-product-relative scan and ray number
raypr = pridx2get MOD RAYSPERSCAN   ; for GPM
scanpr = pridx2get/RAYSPERSCAN      ; for GPM
scanoff = MIN(scanpr)
scanmax = MAX(scanpr)

; find lowest and highest ray numbers in the overlap area, for later use
; in x-section plotting
raystartprmin = MIN( raypr )
rayendprmax = MAX( raypr )

;   pr_index uses -1 for 'bogus' PR points (out-of-range PR footprints
;   just adjacent to the first/last in-range point of the scan), or -2 for
;   off-PR-scan-edge but still-in-range points.  Negative point values will be
;   reset to zero in plot_sweep_2_zbuf_4xsec(), so we will add 3 to the analyzed
;   values and readjust when we query the resulting pixmaps.  After analysis, 
;   anything with an unadjusted ray or scan value of zero should then be outside
;   the PPI/PR overlap area.
;   -- In actuality, any samples with negative pr_index have already been
;      removed within fprep_geo_match_profiles(), leaving only the 'actual'
;      data points at each level.  Morris, 9/5/2012
pr_scan[idx2get] = scanpr-scanoff  ; setting scan values for 'actual' points
pr_ray[idx2get] = raypr            ; ditto for ray values
pr_scan = pr_scan+3L & pr_ray = pr_ray+3L   ; offsetting all values for analysis

;idxtitle = "PR scan number"
myscanbuf = plot_sweep_2_zbuf_4xsec( pr_scan, mysite.site_lat, mysite.site_lon, $
                          xCorner, yCorner, pr_index, mygeometa.num_footprints, $
                          ifram, WINSIZ=windowsize, TITLE=idxtitle, /NOCOLOR, $
                          MAXRNGKM=mygeometa.rangeThreshold )
;idxtitle = "PR ray number"
myraybuf = plot_sweep_2_zbuf_4xsec( pr_ray, mysite.site_lat, mysite.site_lon, $
                        xCorner, yCorner, pr_index, mygeometa.num_footprints, $
                        ifram, WINSIZ=windowsize, TITLE=idxtitle, /NOCOLOR, $
                        MAXRNGKM=mygeometa.rangeThreshold )

; add a "hot corner" matching the GR PPI image, to return special value to
; initiate "data alignment check" PPI animation loop
myscanbuf[0:20,0:20] = 254B
myraybuf[0:20,0:20] = 254B
; add a hot corner to subtract 1 dBZ from GR and re-run x-sect differences
myscanbuf[windowsize-41:windowsize-22,windowsize-20:windowsize-1] = 253B
myraybuf[windowsize-41:windowsize-22,windowsize-20:windowsize-1] = 253B
; add a hot corner to add 1 dBZ to GR and re-run x-sect differences
myscanbuf[windowsize-20:windowsize-1,windowsize-20:windowsize-1] = 252B
myraybuf[windowsize-20:windowsize-1,windowsize-20:windowsize-1] = 252B
; add a hot corner to toggle between original and Ku-adjusted GR reflectivity
myscanbuf[windowsize-62:windowsize-43,windowsize-20:windowsize-1] = 251B
myraybuf[windowsize-62:windowsize-43,windowsize-20:windowsize-1] = 251B
IF KEYWORD_SET(rhi_mode) EQ 0 THEN BEGIN
   ; add a "hot corner" matching the GR PPI image, to return special value to
   ; initiate cross-section step-through animation
   myscanbuf[22:41,0:20] = 250B
   myraybuf[22:41,0:20] = 250B
ENDIF

;-------------------------------------------------

; Render the PR and GR PPI plot - we don't actually view the scan and ray buffers
SET_PLOT, 'X'
device, decomposed=0, RETAIN=2
;HELP, !D, /structure

TV, myprbuf, 0
TV, mygvbuf, 1

; Burn in the labels for the GR dBZ offset hot corners
xyouts, xsize-40, ysize-13, color=0, "-1", /DEVICE, CHARSIZE=1
xyouts, xsize-18, ysize-13, color=0, "+1", /DEVICE, CHARSIZE=1
xyouts, xsize-61, ysize-13, color=0, "K,S", /DEVICE, CHARSIZE=1
xyouts, 3, 7, color=0, "AN", /DEVICE, CHARSIZE=1
IF KEYWORD_SET(rhi_mode) EQ 0 THEN xyouts, 25, 7, color=0, "SC", /DEVICE, CHARSIZE=1
window, 1, xsize=xsize, ysize=ysize*2, xpos = 350, ypos=50, TITLE = title0
Device, Copy=[0,0,xsize,ysize*2,0,0,0]

;-------------------------------------------------

; Let the user select the cross-section locations:
print, ''
print, '---------------------------------------------------------------------'
print, ''
print, ' > Left click on a PPI point to display a cross section of DPR and GR volume-match data'
IF ( skip_orig NE 1 ) THEN print, '   and full-vertical-resolution (125/250 m) DPR data,'
IF KEYWORD_SET(rhi_mode) EQ 0 THEN BEGIN
   print, " > or left click on the white square 'SC' at the lower right to step through"
   print, "   an animation sequence of cross sections for each PR scan in the dataset,"
ENDIF
print, ' > or Right click inside PPI to select another case:'
print, ''
!Mouse.Button=1
havewin2 = 0

; copy the PPI's color table
tvlct, rr,gg,bb,/get

; -- set values 122-127 as white, for labels and such
rr[122:127] = 255
gg[122:127] = 255
bb[122:127] = 255

; also set up upper-byte colors here, in case we don't call plot_pr_xsection
; where it is normally handled.
; -- load compressed color table 33 into LUT values 128-255
loadct, 33, /SILENT
tvlct, rrhi, gghi, bbhi, /get
FOR j = 1,127 DO BEGIN
   rr[j+128] = rrhi[j*2]
   gg[j+128] = gghi[j*2]
   bb[j+128] = bbhi[j*2]
ENDFOR

tvlct, rr,gg,bb
; copy the expanded PPI color table for re-loading in cursor loop when PPIs are redrawn
tvlct, rr,gg,bb,/get

gvzoff = 0.0
is_ku = 0
TITLE_5 = sourceLabel+" & GR Vol. Match X-Sections"

WHILE ( !Mouse.Button EQ 1 ) DO BEGIN
   WSet, 1
   CURSOR, xppi, yppi, /DEVICE, /DOWN
   IF ( !Mouse.Button NE 1 ) THEN BREAK
   IF KEYWORD_SET(verbose) THEN print, "X: ", xppi, "  Y: ", yppi MOD ysize
   scanNum = myscanbuf[xppi, yppi MOD ysize]
  ; account for +3 offset and hot corner values
   IF ( scanNum GT 2 AND scanNum LT 250B ) THEN BEGIN
      IF ( havewin2 EQ 1 ) THEN BEGIN
         IF ( skip_orig NE 1 ) THEN WDELETE, 3
         WDELETE, 5
         WDELETE, 6
         tvlct, rr, gg, bb
      ENDIF
      scanNumpr = scanNum + scanoff - 3L
      IF KEYWORD_SET(verbose) THEN print, $
         "Product-relative scan number: ", scanNumpr+1  ; 1-based

      rayNum = myraybuf[xppi, yppi MOD ysize]
      rayNumpr = rayNum - 3L
      IF KEYWORD_SET(verbose) THEN print, "DPR ray number: ", rayNumpr+1  ; 1-based

     IF KEYWORD_SET(rhi_mode) EQ 0 THEN BEGIN

     ; DO THE CROSS SECTION ALONG THE DPR SCAN LINE

     ; idxcurscan should also be the sweep-by-sweep locations of all the
     ; volume-matched footprints along the scan in the geo_match datasets,
     ; which are what we need later to plot the geo-match cross sections
      idxcurscan = WHERE( pr_scan EQ scanNum )
      pr_rays_in_scan = pr_ray[idxcurscan]

     ; the next two lines would be a bug if fprep_geo_match_profiles() hadn't already
     ; filtered out the negative values from the pr_index array used to initialize
     ; pr_scan and pr_ray, and we had a scan-edge-marked matchup data file from POLAR2PR
     ; -- as it stands, we're safe doing this
      raystart = MIN( pr_rays_in_scan, idxmin, MAX=rayend, $
                      SUBSCRIPT_MAX=idxmax )
      raystartpr = raystart-3L & rayendpr = rayend-3L
      IF KEYWORD_SET(verbose) THEN BEGIN
         print, "ray start, end: ", raystartpr+1, rayendpr+1  ; 1-based
         print, "idxmin, idxmax: ", idxmin, idxmax            ; 0-based
      ENDIF

     ; find the endpoints of the selected scan line on the PPI (pixmaps), and
     ; plot a line connecting the midpoints of the footprints at either end to
     ; show where the cross section will be generated
      idxlinebeg = WHERE( myscanbuf EQ scanNum and myraybuf EQ raystart, countbeg )
      idxlineend = WHERE( myscanbuf EQ scanNum and myraybuf EQ rayend, countend )
      startxys = ARRAY_INDICES( myscanbuf, idxlinebeg )
      endxys = ARRAY_INDICES( myscanbuf, idxlineend )
      xbeg = MEAN( startxys[0,*] ) & xend = MEAN( endxys[0,*] )
      ybeg = MEAN( startxys[1,*] ) & yend = MEAN( endxys[1,*] )

      ENDIF ELSE BEGIN
         ; DO THE CROSS SECTION ALONG A GR RADIAL
         numPRradial = 0       ; number of distinct PR footprints along GR radial
         numrayscanfalse = 0   ; # of sequential invalid ray/scan values along radial
         scanRadialTmp = intarr(100)   ; tally PR scans along radial
         rayRadialTmp = intarr(100)    ; tally PR rays along radial
         ; see if the point at the GR location is within the PR swath
         ; -- if so, then grab its scan and ray number as the starting point
         scanlast = myscanbuf[x_gr, y_gr]
         raylast = myraybuf[x_gr, y_gr]
         IF ( scanlast GT 2 AND scanlast LT 250B ) THEN BEGIN
            ; GR location is within a valid PR footprint, grab PR ray,scan
            scanRadialTmp[numPRradial] = scanlast
            rayRadialTmp[numPRradial] = raylast
            numPRradial++
         ENDIF  ; otherwise, start walking along radial until we find valid ray/scan
         ; - first, compute the equation of the line from the GR x,y to the cursor
         IF (x_gr NE xppi) THEN BEGIN
            ; slope is finite, compute the line parameters
            slope = FLOAT(y_gr-(yppi MOD ysize))/(x_gr-xppi)
            yintercept = y_gr - slope*x_gr
            IF KEYWORD_SET(VERBOSE) THEN print, "slope, intercept: ", slope, yintercept
            IF ABS(slope) GT 0.0001 THEN slopesign = slope/ABS(slope) $    ; positive or negative slope?
            ELSE BEGIN
               slope = 0.0001   ; avoid divide by zero
               slopesign = 0.0
            ENDELSE
            ; next, walk along the radial through the cursor point and find the
            ; unique, valid PR footprints along that line
            IF ABS(slope) GT 1.0 THEN BEGIN
               ; increment y, compute new x, and get scan and ray number
               IF (yppi MOD ysize) GT y_gr THEN BEGIN
                  yend = 300    ; y-top of outer range ring
                  yinc = 1      ; step in +y direction
               ENDIF ELSE BEGIN
                  yend = 42     ; y-bottom of outer range ring
                  yinc = -1     ; step in -y direction
               ENDELSE
               FOR ypix = y_gr, yend, yinc DO BEGIN
                  xpixf = (ypix-yintercept)/slope + 0.5*slopesign*yinc
                  xpix = FIX(xpixf)
                  scannext = myscanbuf[xpix,ypix]
                  raynext = myraybuf[xpix,ypix]
                  IF (scannext NE scanlast) OR (raynext NE raylast) THEN BEGIN
                     IF ( scannext GT 2 AND scannext LT 250B ) THEN BEGIN
                        ; new location is within a valid PR footprint, and is
                        ; different from last one found, grab PR ray,scan
                        scanRadialTmp[numPRradial] = scannext
                        rayRadialTmp[numPRradial] = raynext
                        numPRradial++
                        scanlast = scannext
                        raylast = raynext
                     ENDIF ELSE BEGIN
                        ; check whether we have moved out of the range of valid
                        ; ray/scan values after being within (i.e., numPRradial>0)
                        ; - if so, then quit incrementing, we have our footprints
                        ; Note we can have isolated pixels in the raybuf and scanbuf
                        ; arrays that didn't get "filled" with the ray and scan
                        ; values, so we use numrayscanfalse checks to step past
                        ; these before bailing out of the loop.
                        IF numPRradial GT 0 AND numrayscanfalse GT 1 THEN BREAK $
                        ELSE numrayscanfalse++
                     ENDELSE
                  ENDIF
               ENDFOR
            ENDIF ELSE BEGIN
               ; increment x, compute new y, and get scan and ray number
               IF xppi GT x_gr THEN BEGIN
                  xend = 307     ; max x-right at outer range ring
                  xinc = 1
               ENDIF ELSE BEGIN
                  xend = 42      ; min x-left at outer range ring
                  xinc = -1
               ENDELSE
               FOR xpix = x_gr, xend, xinc DO BEGIN
                  ypixf = yintercept + slope*xpix + 0.5*slopesign*xinc
                  ypix = FIX(ypixf)
                  scannext = myscanbuf[xpix,ypix]
                  raynext = myraybuf[xpix,ypix]
                  IF (scannext NE scanlast) OR (raynext NE raylast) THEN BEGIN
                     IF ( scannext GT 2 AND scannext LT 250B ) THEN BEGIN
                        ; new location is within a valid PR footprint, and is
                        ; different from last one found, grab PR ray,scan
                        scanRadialTmp[numPRradial] = scannext
                        rayRadialTmp[numPRradial] = raynext
                        numPRradial++
                        scanlast = scannext
                        raylast = raynext
                     ENDIF ELSE BEGIN
                        ; check whether we have moved out of the range of valid
                        ; ray/scan values after being within (i.e., numPRradial>0)
                        ; - if so, then quit incrementing, we have our footprints
                        IF numPRradial GT 0 AND numrayscanfalse GT 1 THEN BREAK $
                        ELSE numrayscanfalse++
                     ENDELSE
                  ENDIF
               ENDFOR
            ENDELSE
         ENDIF ELSE BEGIN
            ; slope is infinite, just walk up/down in y-direction
            xpix = x_gr
            IF (yppi MOD ysize) GT y_gr THEN BEGIN
               yend = 300    ; y-top of outer range ring
               yinc = 1      ; step in +y direction
            ENDIF ELSE BEGIN
               yend = 42     ; y-bottom of outer range ring
               yinc = -1     ; step in -y direction
            ENDELSE
            FOR ypix = y_gr, yend, yinc DO BEGIN
               scannext = myscanbuf[xpix,ypix]
               raynext = myraybuf[xpix,ypix]
               IF (scannext NE scanlast) OR (raynext NE raylast) THEN BEGIN
                  IF ( scannext GT 2 AND scannext LT 250B ) THEN BEGIN
                     ; new location is within a valid PR footprint, and is
                     ; different from last one found, grab PR ray,scan
                     scanRadialTmp[numPRradial] = scannext
                     rayRadialTmp[numPRradial] = raynext
                     numPRradial++
                     scanlast = scannext
                     raylast = raynext
                  ENDIF ELSE BEGIN
                     ; check whether we have moved out of the range of valid
                     ; ray/scan values after being within (i.e., numPRradial>0)
                     ; - if so, then quit incrementing, we have our footprints
                     IF numPRradial GT 0 THEN BREAK
                  ENDELSE
               ENDIF
            ENDFOR
         ENDELSE

         ; find the endpoints of the selected scan line on the PPI (pixmaps), and
         ; plot a line connecting the midpoints of the footprints at either end to
         ; show where the cross section will be generated
          idxlinebeg = WHERE( myscanbuf EQ scanRadialTmp[0] and $
                              myraybuf EQ rayRadialTmp[0], countbeg )
          idxlineend = WHERE( myscanbuf EQ scanRadialTmp[numPRradial-1] and $
                              myraybuf EQ rayRadialTmp[numPRradial-1], countend )
          startxys = ARRAY_INDICES( myscanbuf, idxlinebeg )
          endxys = ARRAY_INDICES( myscanbuf, idxlineend )
          xbeg = MEAN( startxys[0,*] ) & xend = MEAN( endxys[0,*] )
          ybeg = MEAN( startxys[1,*] ) & yend = MEAN( endxys[1,*] )
          angle = (180./!pi)*ATAN(xend-x_gr, yend-y_gr)
          IF angle LT 0.0 THEN angle = angle+360.0
          PRINT, "Angle: ", STRING(angle, FORMAT='(F0.1)')

          ; clip the two "tmp" arrays to the defined footprints, restore to
          ; product-relative indices, and compute pr_index values needed to
          ; extract radial x-section of geo-match data
          scanRadial = scanRadialTmp[0:numPRradial-1] + scanoff - 3L
          rayRadial = rayRadialTmp[0:numPRradial-1] - 3L
          pr_indexRadial = scanRadial*RAYSPERSCAN + rayRadial

          ; If we are walking nearly parallel to a PR scan or long a given PR ray,
          ; we can get a "sawtooth" effect in the scanbuf and raybuf arrays such
          ; that we go back-and-forth from a given footprint and thus include it
          ; in more than one position (duplicate PR_index values, not adjacent).
          ; Step through the pr_indexRadial values, look for unique values, and
          ; keep only these values
          
          ; get array indices of original, unsorted, non-unique pr_indexRadial values
          orig_idx = INDGEN(numPRradial)
          ; get sort order of pr_indexRadial
          idx_sorted_prindex = SORT(pr_indexRadial)
          sorted_orig_idx = orig_idx[idx_sorted_prindex]  ; reorder by ascend pr_index
          sorted_prindex = pr_indexRadial[idx_sorted_prindex]  ; ditto
          sorted_scanRadial = scanRadial[idx_sorted_prindex]   ; ditto
          sorted_rayRadial = rayRadial[idx_sorted_prindex]     ; ditto
          ; get indices of unique pr_indexRadial values in sorted array
          idx_uniq_sorted_prindex = UNIQ(sorted_prindex)
          ; grab the original array elements for the unique pr_indexRadial values only
          uniq_sorted_orig_idx = sorted_orig_idx[idx_uniq_sorted_prindex]
          uniq_sorted_prindex = sorted_prindex[idx_uniq_sorted_prindex]
          uniq_sorted_scanRadial = sorted_scanRadial[idx_uniq_sorted_prindex]
          uniq_sorted_rayRadial = sorted_rayRadial[idx_uniq_sorted_prindex]
          ; re-sort the uniq_sorted_prindex and ray and scan by the orig_idx value order
          pr_indexRadial = uniq_sorted_prindex[SORT(uniq_sorted_orig_idx)]
          scanRadial = uniq_sorted_scanRadial[SORT(uniq_sorted_orig_idx)]
          rayRadial = uniq_sorted_rayRadial[SORT(uniq_sorted_orig_idx)]
          IF KEYWORD_SET(verbose) THEN BEGIN
             print, ''
             print, "Duplicate footprints removed: ", numPRradial-N_ELEMENTS(pr_indexRadial)
             print, ''
          ENDIF
          numPRradial = N_ELEMENTS(pr_indexRadial)

          indexRadial = LONARR(numPRradial)
          FOR ifpslice = 0, numPRradial-1 DO BEGIN
             ; map the ray/scan location to its position in the geo-match
             ; data arrays via its pr_index value position
             indexRadial[ifpslice] = $
                WHERE( pr_index_slice EQ pr_indexRadial[ifpslice], countfpradial)
             IF countfpradial NE 1 THEN stop
          ENDFOR

          ; --------------------------------------------------------------------

          ; extract a cross section of each of the plotted data arrays
          ; for PR footprints along the RHI
          
          gvz = extract_radial_slice(gvzCopy, indexRadial)
          zcor = extract_radial_slice(zcorCopy, indexRadial)
          top = extract_radial_slice(topCopy, indexRadial)
          botm = extract_radial_slice(botmCopy, indexRadial)
          rntypeIn = extract_radial_slice(rntypeCopy, indexRadial)  ; ???
          bbprox = extract_radial_slice(bbproxCopy, indexRadial)
          gvrtype = extract_radial_slice(gvrtypeCopy, indexRadial)
          ; extract data from full-resolution DPR arrays only if plotting them
          IF ( skip_orig NE 1 ) THEN BEGIN
             BB_hgt = extract_radial_slice(BB_hgtCopy, rayRadial, scanRadial)
             rainType = extract_radial_slice(rainTypeCopy, rayRadial, scanRadial)
             dbz_meas = extract_radial_slice(dbz_measCopy, rayRadial, scanRadial)
             dbz_corr = extract_radial_slice(dbz_corrCopy, rayRadial, scanRadial)
             binRealSurface = extract_radial_slice(binRealSurfaceCopy, $
                                                   rayRadial, scanRadial)
             binClutterFreeBottom = extract_radial_slice(binClutterFreeBottomCopy, $
                                                         rayRadial, scanRadial)
             cos_inc_angle = extract_radial_slice(cos_inc_angleCopy, $
                                                  rayRadial, scanRadial)
          ENDIF

          ; set up plotting parameters for RHI_MODE using extracted X-sec arrays
          scanNumpr = 0  &  idxcurscan = LINDGEN(numPRradial)
          raystartpr = 0  &  idxmin = 0
          rayendpr = numPRradial-1  &  idxmax = numPRradial-1
          zoomh = 2                 ; override any other zoom mode
          label_by_raynum = 0       ; override any other label mode

          ; --------------------------------------------------------------------

      ENDELSE

      Device, Copy=[0,0,xsize,ysize*3,0,0,0]  ; erase the prior line, if any
     ; plot the X-sec line in the lower panel PPI
      PLOTS, [xbeg, xend], [ybeg, yend], /DEVICE, COLOR=122, THICK=2, $
             LINESTYLE=2
     ; now plot the line in the upper PPI panel
      PLOTS, [xbeg, xend], [ybeg+ysize, yend+ysize], /DEVICE, COLOR=122, $
             THICK=2, LINESTYLE=2

     ; determine the labeling option in effect, and format labels accordingly
      IF ( label_by_raynum ) THEN BEGIN
         leftlbl = STRING(raystartpr+1, FORMAT='(I0)')  ; 1-based for labels
         rightlbl = STRING(rayendpr+1, FORMAT='(I0)')
      ENDIF ELSE BEGIN
         leftlbl = 'A'
         rightlbl = 'B'
      ENDELSE
     ; underplot in black
      XYOUTS, xbeg+1, ybeg-1, leftlbl, /DEVICE, COLOR=0, CHARSIZE=2, CHARTHICK=2
      XYOUTS, xend+1, yend-1, rightlbl, /DEVICE, COLOR=0, CHARSIZE=2, CHARTHICK=2
     ; overplot in white
      XYOUTS, xbeg, ybeg, leftlbl, /DEVICE, COLOR=122, CHARSIZE=2, CHARTHICK=2
      XYOUTS, xend, yend, rightlbl, /DEVICE, COLOR=122, CHARSIZE=2, CHARTHICK=2

     ; now repeat labels for the upper PPI panel
      ybeg = ybeg+ysize & yend = yend+ysize
      XYOUTS, xbeg+1, ybeg-1, leftlbl, /DEVICE, COLOR=0, CHARSIZE=2, CHARTHICK=2
      XYOUTS, xend+1, yend-1, rightlbl, /DEVICE, COLOR=0, CHARSIZE=2, CHARTHICK=2
      XYOUTS, xbeg, ybeg, leftlbl, /DEVICE, COLOR=122, CHARSIZE=2, CHARTHICK=2
      XYOUTS, xend, yend, rightlbl, /DEVICE, COLOR=122, CHARSIZE=2, CHARTHICK=2

;IF KEYWORD_SET(rhi_mode) THEN GOTO, skipPlots

     ; set up parameters to implement zoom behavior specified: if 1, then
     ; zoom to fattest part of overlap area, if 0 then configure to 49 rays, 
     ; if 2 then do legacy behavior (null values for parameters RAYSTARTEND
     ; and STARTEND2SHOW)
      CASE zoomh OF
        0 : BEGIN
               raystartend = [raystartpr,rayendpr]
               startend2show = [0, RAYSPERSCAN-1]
            END
        1 : BEGIN
               raystartend = [raystartpr,rayendpr]
               startend2show = [raystartprmin,rayendprmax]
            END
        2 : BEGIN
              ; undefine raystartend and startend2show, if previously defined via override
               IF label_by_raynum THEN raystartend = [raystartpr,rayendpr]
               IF N_ELEMENTS(startend2show) NE 0 THEN UNDEFINE, startend2show
            END
      ENDCASE

      IF ( skip_orig NE 1 ) THEN BEGIN
        ; generate the PR full-resolution vertical cross section plot
         meanBBmsl = BBparms.meanBB + mysite.site_elev   ; adjust back to MSL for 2A25 plot
         tvlct, rr, gg, bb
         olddevice = !D.NAME
         scaledpr=1.

;         dprxsect_struct = plot_dpr_xsection_zbuf_clut( scanNumpr, raystartpr, rayendpr, $
;                              dbz_corr, meanBBmsl, scaledpr, cos_inc_angle, GATE_SPACE, $
         dprxsect_struct = plot_dpr_xsection_zbuf_zczm( scanNumpr, raystartpr, rayendpr, $
                              dbz_corr, dbz_meas, meanBBmsl, scaledpr, cos_inc_angle, GATE_SPACE, $
                              binRealSurface, binClutterFreeBottom, BB_hgt, /PRPL_HZ, $
                              TITLE=caseTitle25, BBBYRAY=BBbyRay, BBWIDTH=bbwidth, $
                              STARTEND2SHOW=startend2show, FLAG_ECHO=flagEcho, $
                              LABEL_BY_RAYNUM=label_by_raynum, SOURCELABEL=sourceLabel )
         CASE DPR_scantype OF
            'HS' : title_3 = sourceLabel+" Reflectivity, 250m gates"
            ELSE : title_3 = sourceLabel+" Reflectivity, 125m gates"
         ENDCASE
         SET_PLOT, olddevice
         WINDOW, 3, xsize=dprxsect_struct.xs_pr2, ysize=dprxsect_struct.ys_pr2, $
                    ypos=50, TITLE = title_3
         tvlct, dprxsect_struct.redct, dprxsect_struct.grnct, dprxsect_struct.bluct
         TV, dprxsect_struct.PR2_XSECT

         print, ''
      ENDIF

     ; generate the PR and GR geo-match vertical cross sections
     ; -- with any indicated GR offset, and Ku conversion if indicated
      print, "Current GR offset = ", gvzoff, " dBZ"
      gvz4xsec = gvz
      gvz4xsec[idx2adj] = gvz4xsec[idx2adj] + gvzoff
      if is_ku EQ 1 then gv_z_s2ku_4xsec, gvz4xsec, bbprox, idx2adj
      tvlct, rr, gg, bb    ; reload the combined PPI/x-section color table
      olddevice = !D.NAME  ; grab the current device, since it will be redefined
                           ; in call to plot_geo_match_xsections_zbuf()

      xsect_struct = plot_geo_match_xsections_zbuf( gvz4xsec, zcor, top, botm, $
                                bbprox, BBparms.meanBB, nframes, $
                                idxcurscan, idxmin, idxmax, TITLE=caseTitle, $
                                GVOFF=gvzoff, S2KU=is_ku, PRAINTYPE=rnTypeIn, $
                                GRAINTYPE= gvrtype, PLOTBBSEP=plotBBsep, $
                                BBWIDTH=bbwidth, HIDE_RNTYPE=hide_rntype, $
                                RAYSTARTEND=raystartend, STARTEND2SHOW=startend2show, $
                                LABEL_BY_RAYNUM=label_by_raynum, SOURCELABEL=sourceLabel)
                         dprxsect_struct = plot_dpr_xsection_zbuf( scanNumpr, $
                              raystartpr, rayendpr, dbz_corr, meanBBmsl, $
                              scaledpr, cos_inc_angle, GATE_SPACE, $
                              binRealSurface, binClutterFreeBottom, BB_hgt, $
                              TITLE=caseTitle25, BBBYRAY=BBbyRay, BBWIDTH=bbwidth, $
                              STARTEND2SHOW=startend2show, FLAG_ECHO=flagEcho, $
                              LABEL_BY_RAYNUM=label_by_raynum, SOURCELABEL=sourceLabel )

      SET_PLOT, olddevice  ; reset the device type for rendering x-sections
      WINDOW, 5, xsize=dprxsect_struct.xs_pr2, ysize=dprxsect_struct.ys_pr2, ypos=50, $
              TITLE = TITLE_5
      TV, dprxsect_struct.PR2_XSECT    ; plot the PR and GR geo-match x-sections

      DIFFTITLE = sourceLabel + "-GR Vol. Match Diffs."
      WINDOW, 6, xsize=xsect_struct.xs_diff, ysize=xsect_struct.ys_diff, $
              TITLE = DIFFTITLE
     ; reset the color tables for the PR-GR difference x-section, and plot it
      tvlct, xsect_struct.redct, xsect_struct.grnct, xsect_struct.bluct
      TV, xsect_struct.DIFF_XSECT
      havewin2 = 1  ; need to delete x-sect windows at end

      print, ''
      print, '---------------------------------------------------------------------'
      print, ''
      print, "Next actions:"
      print, " > Left click in a PPI image for another cross-section location."
      print, " > Left click on a +1 or -1 labeled white square to adjust the"
      print, "   geo_match GR reflectivities by the indicated amount, and re-draw."
      print, " > Left click on the K,S labeled white square to toggle the S-band to"
      print, "   Ku-band adjustment to the geo-match GR reflectivities, and re-draw."
      print, " > Left click on the white square 'AN' at the lower left to display a PPI"
      print, "   animation loop of volume-match and full-resolution PR and GR data."
      IF KEYWORD_SET(rhi_mode) EQ 0 THEN BEGIN
         print, " > Left click on the white square 'SC' at the lower left to step through"
         print, "   an animation sequence of cross sections for each PR scan in the dataset."
      ENDIF
      print, ' > Right click inside a PPI image to select another case.'
      print, ''

   ENDIF ELSE BEGIN   ; ( scanNum GT 2 AND scanNum LT 250B )

     ; only the lower (GR) image has hot corners, check whether cursor lies there
      IF ( yppi LE ysize ) THEN BEGIN
      CASE scanNum OF
         254B : BEGIN
                   loopframes = (ifram+1)*2 < nframes
                  ; set up for bailout prompt if animating too many PPIs
                   doodah = ""
                   IF loopframes GT 10 THEN BEGIN
                      PRINT, ''
                      PRINT, "Attempting to build animation loop for ", $
                              STRING(loopframes,FORMAT='(I0)'), ' frames!'
                      READ, doodah, $
                      PROMPT='Hit Return to skip animation loop, C to Continue: '
                   ENDIF ELSE doodah = "C"
                   IF STRUPCASE(doodah) EQ 'C' THEN $
                      status = loop_pr_gv_gvpolar_ppis(ncfilepr, ufpath, 3, $
                                   loopframes, INSTRUMENT_ID='DPR')
                   GOTO, skipPlots  ; to print the Next action text
                END
         253B : BEGIN
                   IF ( havewin2 EQ 1 ) THEN BEGIN
                      print, ""
                      print, "Lowering GR reflectivity 1.0 dBZ"
                      gvzoff = gvzoff - 1.0
                      print, "Current GR offset = ", gvzoff, " dBZ"
                      gvz4xsec = gvz
                      gvz4xsec[idx2adj] = gvz4xsec[idx2adj] + gvzoff
                      if is_ku EQ 1 then gv_z_s2ku_4xsec, gvz4xsec, bbprox, idx2adj
                      tvlct, rr, gg, bb
                     ; grab the current device, since it will be redefined
                     ; in call to plot_geo_match_xsections_zbuf()
                      olddevice = !D.NAME

                      xsect_struct = plot_geo_match_xsections_zbuf( gvz4xsec, zcor, top, botm, $
                                bbprox, BBparms.meanBB, nframes, $
                                idxcurscan, idxmin, idxmax, TITLE=caseTitle, $
                                GVOFF=gvzoff, S2KU=is_ku, PRAINTYPE=rnTypeIn, $
                                GRAINTYPE= gvrtype, PLOTBBSEP=plotBBsep, $
                                BBWIDTH=bbwidth, HIDE_RNTYPE=hide_rntype, $
                                RAYSTARTEND=raystartend, STARTEND2SHOW=startend2show, $
                                SOURCELABEL=sourceLabel)
                         dprxsect_struct = plot_dpr_xsection_zbuf( scanNumpr, $
                              raystartpr, rayendpr, dbz_corr, meanBBmsl, $
                              scaledpr, cos_inc_angle, GATE_SPACE, $
                              binRealSurface, binClutterFreeBottom, BB_hgt, $
                              TITLE=caseTitle25, BBBYRAY=BBbyRay, BBWIDTH=bbwidth, $
                              STARTEND2SHOW=startend2show, FLAG_ECHO=flagEcho, $
                              LABEL_BY_RAYNUM=label_by_raynum, SOURCELABEL=sourceLabel )

                      SET_PLOT, olddevice  ; reset the device type for rendering x-sections
                      WINDOW, 5, xsize=dprxsect_struct.xs_pr2, ysize=dprxsect_struct.ys_pr2, $
                              ypos=50, TITLE = TITLE_5
                      TV, dprxsect_struct.PR2_XSECT    ; plot the PR and GR geo-match x-sections
                      WINDOW, 6, xsize=xsect_struct.xs_diff, ysize=xsect_struct.ys_diff, $
                              TITLE = DIFFTITLE
                     ; reset the color tables for the PR-GR difference x-section, and plot it
                      tvlct, xsect_struct.redct, xsect_struct.grnct, xsect_struct.bluct
                      TV, xsect_struct.DIFF_XSECT
                   ENDIF ELSE print, "NOTE:  No cross section displayed", $
                                     " -- no GR calibration adjustment applied."
                END
         252B : BEGIN
                   IF ( havewin2 EQ 1 ) THEN BEGIN
                      print, ""
                      print, "Raising GR reflectivity 1.0 dBZ"
                      gvzoff = gvzoff + 1.0
                      print, "Current GR offset = ", gvzoff, " dBZ"
                      gvz4xsec = gvz
                      gvz4xsec[idx2adj] = gvz4xsec[idx2adj] + gvzoff
                      if is_ku EQ 1 then gv_z_s2ku_4xsec, gvz4xsec, bbprox, idx2adj
                      tvlct, rr, gg, bb
                      olddevice = !D.NAME

                      xsect_struct = plot_geo_match_xsections_zbuf( gvz4xsec, zcor, $
                                top, botm, bbprox, BBparms.meanBB, nframes, $
                                idxcurscan, idxmin, idxmax, TITLE=caseTitle, $
                                GVOFF=gvzoff, S2KU=is_ku, PRAINTYPE=rnTypeIn, $
                                GRAINTYPE= gvrtype, PLOTBBSEP=plotBBsep, $
                                BBWIDTH=bbwidth, HIDE_RNTYPE=hide_rntype, $
                                RAYSTARTEND=raystartend, STARTEND2SHOW=startend2show, $
                                LABEL_BY_RAYNUM=label_by_raynum, $
                                SOURCELABEL=sourceLabel )
                         dprxsect_struct = plot_dpr_xsection_zbuf( scanNumpr, $
                              raystartpr, rayendpr, dbz_corr, meanBBmsl, $
                              scaledpr, cos_inc_angle, GATE_SPACE, $
                              binRealSurface, binClutterFreeBottom, BB_hgt, $
                              TITLE=caseTitle25, BBBYRAY=BBbyRay, BBWIDTH=bbwidth, $
                              STARTEND2SHOW=startend2show, FLAG_ECHO=flagEcho, $
                              LABEL_BY_RAYNUM=label_by_raynum, SOURCELABEL=sourceLabel )

                      SET_PLOT, olddevice  ; reset the device type for rendering x-sections
                      WINDOW, 5, xsize=dprxsect_struct.xs_pr2, ysize=dprxsect_struct.ys_pr2, $
                              ypos=50, TITLE = TITLE_5
                      TV, dprxsect_struct.PR2_XSECT    ; plot the PR and GR geo-match x-sections
                      WINDOW, 6, xsize=xsect_struct.xs_diff, ysize=xsect_struct.ys_diff, $
                              TITLE = DIFFTITLE
                     ; reset the color tables for the PR-GR difference x-section, and plot it
                      tvlct, xsect_struct.redct, xsect_struct.grnct, xsect_struct.bluct
                      TV, xsect_struct.DIFF_XSECT
                   ENDIF ELSE print, "NOTE: No cross section displayed", $
                                     " -- no GR calibration adjustment applied."
                END
         251B : BEGIN
                   IF ( havewin2 EQ 1 ) THEN BEGIN
                      gvz4xsec = gvz
                      gvz4xsec[idx2adj] = gvz4xsec[idx2adj] + gvzoff
                      if ( is_ku EQ 0 ) then begin
                         print, 'Converting S-band reflectivity to Ku-band equivalent.'
                         is_ku = 1
                         gv_z_s2ku_4xsec, gvz4xsec, bbprox, idx2adj
                      endif else begin
                         print, 'Restore S-band reflectivity from Ku-band equivalent.'
                         is_ku = 0
                      endelse
                      tvlct, rr, gg, bb
                      olddevice = !D.NAME

                      xsect_struct = plot_geo_match_xsections_zbuf( gvz4xsec, zcor, top, botm, $
                                bbprox, BBparms.meanBB, nframes, $
                                idxcurscan, idxmin, idxmax, TITLE=caseTitle, $
                                GVOFF=gvzoff, S2KU=is_ku, PRAINTYPE=rnTypeIn, $
                                GRAINTYPE= gvrtype, PLOTBBSEP=plotBBsep, $
                                BBWIDTH=bbwidth, HIDE_RNTYPE=hide_rntype, $
                                RAYSTARTEND=raystartend, STARTEND2SHOW=startend2show, $
                                SOURCELABEL=sourceLabel)
                         dprxsect_struct = plot_dpr_xsection_zbuf( scanNumpr, $
                              raystartpr, rayendpr, dbz_corr, meanBBmsl, $
                              scaledpr, cos_inc_angle, GATE_SPACE, $
                              binRealSurface, binClutterFreeBottom, BB_hgt, $
                              TITLE=caseTitle25, BBBYRAY=BBbyRay, BBWIDTH=bbwidth, $
                              STARTEND2SHOW=startend2show, FLAG_ECHO=flagEcho, $
                              LABEL_BY_RAYNUM=label_by_raynum, SOURCELABEL=sourceLabel )

                      SET_PLOT, olddevice  ; reset the device type for rendering x-sections
                      WINDOW, 5, xsize=dprxsect_struct.xs_pr2, ysize=dprxsect_struct.ys_pr2, $
                              ypos=50, TITLE = TITLE_5
                      TV, dprxsect_struct.PR2_XSECT    ; plot the PR and GR geo-match x-sections
                      WINDOW, 6, xsize=xsect_struct.xs_diff, ysize=xsect_struct.ys_diff, $
                              TITLE = DIFFTITLE
                     ; reset the color tables for the PR-GR difference x-section, and plot it
                      tvlct, xsect_struct.redct, xsect_struct.grnct, xsect_struct.bluct
                      TV, xsect_struct.DIFF_XSECT
                   ENDIF ELSE print, "NOTE: No cross section displayed", $
                                     " -- no S-to-Ku adjustments applied."
                END
         250B : BEGIN
                   IF KEYWORD_SET(rhi_mode) THEN BEGIN
                      print, ''
                      print, 'Option not valid for RHI-mode cross sections!'
                      print, ''
                      GOTO, skipPlots
                   ENDIF
                   print, "Stepping through cross sections of each PR scan in matchup dataset"
                   IF N_ELEMENTS(pause) NE 1 THEN BEGIN
                      print, "Setting wait time between scans to 1 second."
                      pause = 1.0
                   ENDIF ELSE BEGIN
                      IF pause LT 0.1 OR pause GT 10.0 THEN BEGIN
                         print, "Pause value must be between 0.1 and 10.0 ", $
                                "secs, value is: ", pause
                         print, "Setting wait time between scans to 1 second."
                         pause = 1.0
                      ENDIF
                   ENDELSE

                  ; set up parameters to implement zoom behavior specified: if 1, then
                  ; zoom to fattest part of overlap area, if 0 then configure to 49 rays, 
                  ; if 2 then override legacy behavior to same as 1. Define raystartend
                  ; scan-by-scan in FOR loop below.
                   IF zoomh GE 1 THEN startend2show = [raystartprmin,rayendprmax] $
                   ELSE startend2show = [0, RAYSPERSCAN-1]

                   FOR scanNumPR = scanoff, scanmax DO BEGIN
                     ; destroy existing x-section windows 1st time through loop,
                     ; may need resizing
                      IF ( havewin2 EQ 1 AND scanNumPR EQ scanoff ) THEN BEGIN
                         WDELETE, 5
                         WDELETE, 6
                         tvlct, rr, gg, bb
                      ENDIF

                      scanNum = scanNumpr - scanoff + 3L
                      IF KEYWORD_SET(verbose) THEN $
                         print, "Product-relative scan number: ", scanNumpr

                     ; idxcurscan should also be the sweep-by-sweep locations of all the
                     ; volume-matched footprints along the scan in the geo_match datasets,
                     ; which are what we need later to plot the geo-match cross sections
                      idxcurscan = WHERE( pr_scan EQ scanNum )
                      pr_rays_in_scan = pr_ray[idxcurscan]
                      raystart = MIN( pr_rays_in_scan, idxmin, MAX=rayend, $
                                      SUBSCRIPT_MAX=idxmax )
                      raystartpr = raystart-3L & rayendpr = rayend-3L
                      IF KEYWORD_SET(verbose) THEN $
                         print, "ray start, end: ", raystartpr, rayendpr
                     ; determine the labeling option in effect, and format labels accordingly
                      IF ( label_by_raynum ) THEN BEGIN
                         raystartlbl = STRING(raystartpr+1, FORMAT='(I0)')  ; 1-based for labels
                         rayendlbl = STRING(rayendpr+1, FORMAT='(I0)')
                      ENDIF ELSE BEGIN
                         raystartlbl = 'A'
                         rayendlbl = 'B'
                      ENDELSE

                     ; set values for RAYSTARTEND parameter
                      raystartend=[raystartpr,rayendpr]

                     ; find the endpoints of the selected scan line on the PPI (pixmaps), and
                     ; plot a line connecting the midpoints of the footprints at either end to
                     ; show where the cross section will be generated

                      Device, Copy=[0,0,xsize,ysize*3,0,0,0]  ; erase the prior line, if any

                      IF ( skip_orig NE 1 ) THEN BEGIN
                        ; generate the PR full-resolution vertical cross section plot
                        ; -- adjust back to MSL for full-res original data plot
                         meanBBmsl = BBparms.meanBB + mysite.site_elev
                         tvlct, rr, gg, bb
                         olddevice = !D.NAME
                         scaledpr=1.
                         dprxsect_struct = plot_dpr_xsection_zbuf_clut( scanNumpr, $
                              raystartpr, rayendpr, dbz_corr, meanBBmsl, $
                              scaledpr, cos_inc_angle, GATE_SPACE, $
                              binRealSurface, binClutterFreeBottom, BB_hgt, $
                              TITLE=caseTitle25, BBBYRAY=BBbyRay, BBWIDTH=bbwidth, $
                              STARTEND2SHOW=startend2show, FLAG_ECHO=flagEcho, $
                              LABEL_BY_RAYNUM=label_by_raynum, SOURCELABEL=sourceLabel )

;                         title = "DPR Reflectivity, 125m gates"
                         SET_PLOT, olddevice
                         IF scanNumPR EQ scanoff THEN $
                            WINDOW, 3, xsize=dprxsect_struct.xs_pr2, $
                                    ysize=dprxsect_struct.ys_pr2, $
                                    ypos=50, TITLE = title_3 $
                         ELSE WSET, 3
                         tvlct, dprxsect_struct.redct, dprxsect_struct.grnct, $
                                dprxsect_struct.bluct
                         TV, dprxsect_struct.PR2_XSECT
                         print, ''
                      ENDIF

                     ; generate the PR and GR geo-match vertical cross sections
                     ; -- with any indicated GR offset, and Ku conversion if indicated
                      print, "Current GR offset = ", gvzoff, " dBZ"
                      gvz4xsec = gvz
                      gvz4xsec[idx2adj] = gvz4xsec[idx2adj] + gvzoff
                      if is_ku EQ 1 then gv_z_s2ku_4xsec, gvz4xsec, bbprox, idx2adj
                      tvlct, rr, gg, bb
                      olddevice = !D.NAME

                      xsect_struct = plot_geo_match_xsections_zbuf( gvz4xsec, zcor, $
                                        top, botm, bbprox, BBparms.meanBB, nframes, $
                                        idxcurscan, idxmin, idxmax, TITLE=caseTitle, $
                                        GVOFF=gvzoff, S2KU=is_ku, PRAINTYPE=rnTypeIn, $
                                        GRAINTYPE= gvrtype, PLOTBBSEP=plotBBsep, $
                                        BBWIDTH=bbwidth, HIDE_RNTYPE=hide_rntype, $
                                        RAYSTARTEND=raystartend, STARTEND2SHOW=startend2show, $
                                        LABEL_BY_RAYNUM=label_by_raynum, SOURCELABEL=sourceLabel )
help, xsect_struct
         ; do a DPR plot with the negative attenuation area highlighted as "purple haze"
         dprxsect_struct = plot_dpr_xsection_zbuf_zczm( scanNumpr, raystartpr, rayendpr, $
                              dbz_corr, dbz_meas, meanBBmsl, scaledpr, cos_inc_angle, GATE_SPACE, $
                              binRealSurface, binClutterFreeBottom, BB_hgt, /PRPL_HZ, $
                              TITLE=caseTitle25, BBBYRAY=BBbyRay, BBWIDTH=bbwidth, $
                              STARTEND2SHOW=startend2show, FLAG_ECHO=flagEcho, $
                              LABEL_BY_RAYNUM=label_by_raynum, SOURCELABEL=sourceLabel )

         ; do another DPR plot with the Z values shown in the negative attenuation area
         dprxsect_struct2 = plot_dpr_xsection_zbuf_zczm( scanNumpr, raystartpr, rayendpr, $
                              dbz_corr, dbz_meas, meanBBmsl, scaledpr, cos_inc_angle, GATE_SPACE, $
                              binRealSurface, binClutterFreeBottom, BB_hgt, $
                              TITLE=caseTitle25, BBBYRAY=BBbyRay, BBWIDTH=bbwidth, $
                              STARTEND2SHOW=startend2show, FLAG_ECHO=flagEcho, $
                              LABEL_BY_RAYNUM=label_by_raynum, SOURCELABEL=sourceLabel, /SHOW_SFC_CLUTR )

                     ; After creation, we just load new contents to existing windows for each
                     ; cross section in the sequence.  This way the window doesn't "flash" as
                     ; each new cross section is displayed, and is the reason for the change to
                     ; plotting the geo-match x-sections to the z-buffer rather than directly
                     ; to the X-window.
                      SET_PLOT, olddevice

                      difftitle = sourceLabel + "-GR Vol. Match Diffs."
                      IF scanNumPR EQ scanoff THEN $
                         WINDOW, 6, xsize=xsect_struct.xs_diff, ysize=xsect_struct.ys_diff, $
                                    TITLE = difftitle $
                      ELSE WSET, 6
                      tvlct, xsect_struct.redct, xsect_struct.grnct, xsect_struct.bluct
                      TV, xsect_struct.DIFF_XSECT


                      ; set up a window that contains both the PPIs and the geo-match cross sections together
                      xsComb = (xsect_struct.xs_prgr > xsize)*4   ; set up side-by-side using 2X larger window
                      ysComb = xsect_struct.ys_prgr > (ysize*2)
                      IF scanNumPR EQ scanoff THEN window, 9, xsize=xsComb, ysize=ysComb, /pixmap $
                      ELSE wset, 9
                      tvlct, rr, gg, bb
                      ; render the PPI selector and position annonations in the middle left
                      TV, myprbufClean, xscomb*0, ysComb/2
                      TV, mygvbufClean, xscomb*0, 0
                     ; find the endpoints of the selected scan line on the PPI (pixmaps), and
                     ; plot a line connecting the midpoints of the footprints at either end to
                     ; show where the cross section will be generated
                      idxlinebeg = WHERE( myscanbuf EQ scanNum $
                                          and myraybuf EQ raystart, countbeg )
                      idxlineend = WHERE( myscanbuf EQ scanNum $
                                          and myraybuf EQ rayend, countend )
                      startxys = ARRAY_INDICES( myscanbuf, idxlinebeg )
                      endxys = ARRAY_INDICES( myscanbuf, idxlineend )
                      xbeg = MEAN( startxys[0,*] ) & xend = MEAN( endxys[0,*] )
                      ybeg = MEAN( startxys[1,*] ) & yend = MEAN( endxys[1,*] )
                      PLOTS, [xbeg, xend]+xscomb*0, [ybeg, yend], /DEVICE, COLOR=122, THICK=2,LINESTYLE=2
                      XYOUTS, xbeg+1+xscomb*0, ybeg-1, raystartlbl, /DEVICE, COLOR=0, $
                              CHARSIZE=2, CHARTHICK=2  ; underplot in black
                      XYOUTS, xend+1+xscomb*0, yend-1, rayendlbl, /DEVICE, COLOR=0, $
                              CHARSIZE=2, CHARTHICK=2
                      XYOUTS, xbeg+xscomb*0, ybeg, raystartlbl, /DEVICE, COLOR=122, $
                              CHARSIZE=2, CHARTHICK=2    ; overplot in white
                      XYOUTS, xend+xscomb*0, yend, rayendlbl, /DEVICE, COLOR=122, $
                              CHARSIZE=2, CHARTHICK=2
                      ybeg = ybeg+ysize & yend = yend+ysize
                      PLOTS, [xbeg, xend]+xscomb*0, [ybeg, yend], /DEVICE, COLOR=122, THICK=2,LINESTYLE=2
                      XYOUTS, xbeg+1+xscomb*0, ybeg-1, raystartlbl, /DEVICE, COLOR=0, $
                              CHARSIZE=2, CHARTHICK=2
                      XYOUTS, xend+1+xscomb*0, yend-1, rayendlbl, /DEVICE, COLOR=0, $
                              CHARSIZE=2, CHARTHICK=2
                      XYOUTS, xbeg+xscomb*0, ybeg, raystartlbl, /DEVICE, COLOR=122, $
                              CHARSIZE=2, CHARTHICK=2
                      XYOUTS, xend+xscomb*0, yend, rayendlbl, /DEVICE, COLOR=122, $
                              CHARSIZE=2, CHARTHICK=2
                      ; render the geo-match DPR and GR cross sections in the 2nd column
                      tv, xsect_struct.PRGR_XSECT, xsComb/4,(ysComb-xsect_struct.ys_prgr)/2
                      ; render the DPR cross sections on the right side
                      TV, dprxsect_struct.PR2_XSECT, (xsComb/4)*2, (ysComb-xsect_struct.ys_prgr)/2
                      TV, dprxsect_struct2.PR2_XSECT, (xsComb/4)*3, (ysComb-xsect_struct.ys_prgr)/2
                      title = title0+" / PR and GR Volume Match X-Sections"
                      IF scanNumPR EQ scanoff THEN window, 5, xsize=xsComb, ysize=ysComb, TITLE=title_5 $
                      ELSE wset, 5
                      DEVICE, COPY=[0,0,xsComb,ysComb,0,0,9]

                      havewin2 = 1  ; need to delete x-sect windows at end
                      WAIT, pause
;  IF scanNumPR EQ (scanoff+scanmax)/2 THEN WAIT,10   ;REMOVE FROM BASELINE FILE BEFORE CM COMMIT
                      PRINT, '' & doodah = ''
                      READ, doodah, PROMPT='Hit Return to do next scan, Q to Quit: '
                      IF STRUPCASE(doodah) EQ 'Q' THEN break
                      WSET, 1
                   ENDFOR
   skipPlots:

                   print, ''
                   print, '---------------------------------------------------------------------'
                   print, ''
                   print, "Next actions:"
                   print, " - Left click in a PPI image for another cross-section location."
                   print, " - Left click on a +1 or -1 labeled white square to adjust the"
                   print, "   geo_match GR reflectivities by the indicated amount, and re-draw."
                   print, " - Left click on the K,S labeled white square to toggle the S-band to"
                   print, "   Ku-band adjustment to the geo-match GR reflectivities, and re-draw."
                   print, " - Left click on the white square 'AN' at the lower left to display a PPI"
                   print, "   animation loop of volume-match and full-resolution PR and GR data."
                   IF KEYWORD_SET(rhi_mode) EQ 0 THEN BEGIN
                      print, " - Left click on the white square 'SC' at the lower left to step through"
                      print, "   an animation sequence of cross sections for each PR scan in the dataset."
                   ENDIF
                   print, ' - Right click inside a PPI image to select another case.'
                   print, ''
                END
         ELSE : print, "Point outside PR/", mysite.site_ID," overlap area, choose another..."
      ENDCASE
      ENDIF ELSE print, "Point outside PR/", mysite.site_ID," overlap area, choose another..."

   ENDELSE   ; ( scanNum GT 2 AND scanNum LT 250B )
ENDWHILE     ; ( !Mouse.Button EQ 1 )

wdelete, 1
IF N_ELEMENTS(hist_window) EQ 1 THEN wdelete, hist_window
IF ( havewin2 EQ 1 ) THEN BEGIN
   IF ( skip_orig NE 1 ) THEN BEGIN
      WDELETE, 3
;      WDELETE, 7
   ENDIF
   WDELETE, 5
   WDELETE, 6
ENDIF

errorExit:
end

;===============================================================================

; MODULE #1

pro dpr_and_geo_match_x_sections_merged, ELEV2SHOW=elev2show, SITE=sitefilter, $
                                  NO_PROMPT=no_prompt, NCPATH=ncpath,   $
                                  PRPATH=prpath, UFPATH=ufpath, USE_DB=use_db, $
                                  SHOW_ORIG=show_orig, PCT_ABV_THRESH=pctAbvThresh, $
                                  BBBYRAY=BBbyRay, PLOTBBSEP=plotBBsep, $
                                  BBWIDTH=bbwidth, ALT_BB_HGT=alt_bb_hgt, $
                                  HIDE_RNTYPE=hide_rntype, CREF=cref, PAUSE=pause, $
                                  ZOOMH=zoomh, LABEL_BY_RAYNUM=label_by_raynum, $
                                  RHI_MODE=rhi_mode, VERBOSE=verbose, $
                                  RECALL_NCPATH=recall_ncpath

; "Include" file for matchup file prefixes:
@environs.inc

print
print, "######################################################"
print, "#  DPR_AND_GEO_MATCH_X_SECTIONS_MERGED: Version 1.1  #"
print, "#     NASA/GSFC/GPM Ground Validation, Mar. 2015     #"
print, "######################################################"
print

print, ""
DEFSYSV, '!LAST_NCPATH', EXISTS = haveUserVar
IF KEYWORD_SET(recall_ncpath) AND (haveUserVar EQ 1) THEN BEGIN
   print, "Defaulting to last selected directory for file path:"
   print, !LAST_NCPATH
   print, ""
   pathgeo = !LAST_NCPATH
ENDIF ELSE BEGIN
   IF ( N_ELEMENTS(ncpath) NE 1 ) THEN BEGIN
      print, "Defaulting to /data/gpmgv/netcdf/geo_match for file path."
      pathgeo = '/data/gpmgv/netcdf/geo_match'
   ENDIF ELSE pathgeo = ncpath
ENDELSE

IF ( N_ELEMENTS(sitefilter) NE 1 ) THEN BEGIN
   print, "Defaulting to GRtoDPR.* for file pattern."
   print, ""
   ncfilepatt = 'GRtoDPR.*.nc*'
ENDIF ELSE BEGIN
   IF ( STRPOS(sitefilter, DPR_GEO_MATCH_PRE) NE 0 ) THEN $
      ncfilepatt = 'GRtoDPR.*'+sitefilter+'*' $   ; add GR_to_DPR.* prefix
   ELSE ncfilepatt = sitefilter+'*'              ; already have standard prefix
ENDELSE

; Set use_db flag, default is to not use a Postgresql database query to obtain
; the input DPR product filename matching the geo-match netCDF file for each case.
use_db = KEYWORD_SET( use_db )

; Set the skip_orig flag.  Default (ON) is to plot only geo-match cross section
; data from the netCDF files. If set to 0 (OFF), then look for original DPR
; 2Axxx product file and plot cross section of full-res DPR data. Skip_orig is
; the binary opposite of the show_orig keyword parameter
IF N_ELEMENTS( show_orig ) EQ 0 THEN skip_orig = 1 $
ELSE skip_orig = 1 - KEYWORD_SET( show_orig )

; Set the flag to control plotting of the ray-by-ray Bright Band heights in the
; DPR 2Axxx full-resolution cross sections
BBbyRay=KEYWORD_SET( BBbyRay )

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
END      

IF ( N_ELEMENTS(prpath) NE 1 ) THEN BEGIN
   IF ( skip_orig NE 1 ) THEN BEGIN
      print, "Using default for PR product file path."
      IF ( use_db NE 1 ) THEN $
         print, "DPR 2A-XXX files may not be found if this location is incorrect."
      print, ""
   ENDIF
ENDIF ELSE BEGIN
   pathpr = prpath
ENDELSE

IF ( N_ELEMENTS(ufpath) NE 1 ) THEN BEGIN
   print, "Defaulting to /data/gpmgv/gv_radar/finalQC_in for UF file path prefix."
   pathgv = '/data/gpmgv/gv_radar/finalQC_in'
ENDIF ELSE pathgv = ufpath

IF ( N_ELEMENTS(zoomh) NE 1 ) THEN BEGIN
   print, "Defaulting to 2 for ZOOMH parameter, Full Zoom-To-Fit of displayed DPR rays."
   zoomh = 2
ENDIF ELSE BEGIN
   SWITCH FIX(zoomh) OF
        0 :
        1 :
        2 : BEGIN
              zoomh = FIX(zoomh)
              break
            END
     ELSE : BEGIN
              print, ''
              print, "Invalid value for ZOOMH parameter, ", $
                     "must be 0, 1, or 2, value is: ", zoomh
              print, "Defaulting to 2 for ZOOMH parameter, ", $
                     "Full Zoom-To-Fit of displayed DPR rays."
              print, ''
              zoomh = 2
            END
   ENDSWITCH
ENDELSE

; set the flag for labeling the endpoints of the cross section line/plots
label_by_raynum = keyword_set(label_by_raynum)

; set the flag for plotting along an RHI rather than along a DPR scan
rhi_mode = keyword_set(rhi_mode)

; Figure out how the next file to process will be obtained.  If no_prompt is
; set, then we will automatically loop over the file sequence.  Otherwise we
; will prompt the user for the next file with dialog_pickfile() (DEFAULT).

no_prompt = keyword_set(no_prompt)

IF (no_prompt) THEN BEGIN

   prfiles = file_search(pathgeo+'/'+ncfilepatt,COUNT=nf)

   if nf eq 0 then begin
      print, 'No netCDF files matching file pattern: ', pathgeo+'/'+ncfilepatt
   endif else begin
      for fnum = 0, nf-1 do begin
        ; set up for bailout prompt every 5 cases if animating PPIs w/o file prompt
         doodah = ""
         IF fnum GT 0 THEN BEGIN
            PRINT, ''
            READ, doodah, $
            PROMPT='Hit Return to do next case, Q to Quit: '
         ENDIF
         IF doodah EQ 'Q' OR doodah EQ 'q' THEN break
        ;
         ncfilepr = prfiles(fnum)
         gen_dpr_and_geo_match_x_sections, ncfilepr, use_db, skip_orig, $
                        ELEV2SHOW=elev2show, PCT_ABV_THRESH=pctAbvThresh, $
                        PR_ROOT_PATH=pathpr, UFPATH=pathgv, BBBYRAY=BBbyRay, $
                        PLOTBBSEP=plotBBsep, BBWIDTH=bbwidth, $
                        ALT_BB_HGT=alt_bb_hgt, CREF=cref, RHI_MODE=rhi_mode, $
                        HIDE_RNTYPE=hide_rntype, PAUSE=pause, ZOOMH=zoomh, $
                        LABEL_BY_RAYNUM=label_by_raynum, VERBOSE=verbose
      endfor
   endelse
ENDIF ELSE BEGIN
   print, ''
   print, 'Select a GRtoDPR* netCDF file from the file selector.'
   ncfilepr = dialog_pickfile(path=pathgeo, filter = ncfilepatt, $
                              Title='Select a GRtoDPR* netCDF file:')
   while ncfilepr ne '' do begin
      gen_dpr_and_geo_match_x_sections, ncfilepr, use_db, skip_orig, $
                        ELEV2SHOW=elev2show, PCT_ABV_THRESH=pctAbvThresh, $
                        PR_ROOT_PATH=pathpr, UFPATH=pathgv, BBBYRAY=BBbyRay, $
                        PLOTBBSEP=plotBBsep, BBWIDTH=bbwidth, $
                        ALT_BB_HGT=alt_bb_hgt, CREF=cref, RHI_MODE=rhi_mode, $
                        HIDE_RNTYPE=hide_rntype, PAUSE=pause, ZOOMH=zoomh, $
                        LABEL_BY_RAYNUM=label_by_raynum, VERBOSE=verbose

      newpathgeo = FILE_DIRNAME(ncfilepr)  ; set the path to the last file's path
      IF KEYWORD_SET(recall_ncpath) THEN BEGIN
          IF (haveUserVar EQ 1) THEN !LAST_NCPATH = newpathgeo $
          ELSE DEFSYSV, '!LAST_NCPATH', newpathgeo
      ENDIF
      ncfilepr = dialog_pickfile(path=newpathgeo, filter = ncfilepatt, $
                                 Title='Select a GRtoDPR* netCDF file:')
   endwhile
ENDELSE

print, "" & print, "Done!"
END
