;===============================================================================
;+
; Copyright © 2009, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; pr_dpr_and_geo_match_x_sections.pro    Morris/SAIC/GPM_GV    March 2009
;
; DESCRIPTION
; -----------
; Driver for gen_pr_and_geo_match_x_sections (included).  Sets up user/default
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
; prpath       - local directory path to the original PR product files root
;                (in-common) directory.  Defaults to /data/prsubsets
;
; ufpath       - local directory path to the original GR radar UF file root
;                (in-common) directory.  Defaults to /data/gv_radar/finalQC_in
;
; use_db       - Binary parameter.  If set, then query the 'gpmgv' database to
;                find the PR 2A-25 product file that corresponds to the
;                geo_match netCDF file being rendered.  Otherwise, generate
;                a 'guess' of the filename pattern and search under the
;                directory prpath/2A25 (default mode)
;
; skip_2a25      - Binary parameter.  If set, then the full-vertical-resolution PR
;                cross sections from the 2A-25 data will NOT be plotted.  This
;                means the program can be run using only the geo_match netCDF
;                data files.
;
; pctAbvThresh - constraint on the percent of bins in the geometric-matching
;                volume that were above their respective thresholds, specified
;                at the time the geo-match dataset was created.  Essentially a
;                measure of "beam-filling goodness".  100 means use only those
;                matchup points where all the PR and GR bins in the volume
;                averages were above threshold (complete volume filled with
;                above threshold bin values).  0 means use all matchup points
;                available, with no regard for thresholds (the default, if no
;                pctAbvThresh value is specified)
;
; BBbyRay      - Binary parameter.  If set, then plot individual bright band
;                height lines for each ray in the optional full-resolution PR
;                2A-25 cross section plots, using each ray's BB height as
;                specified in the 2A-25 rangeBinNums variable.
;
; plotBBsep    - (Optional) binary parameter, indicates whether to plot a
;                delimiter between within-BB volumes and adjacent above and
;                below-BB volumes in PR and GR volume-match x-sections.
;
; bbwidth      - Height (km) above/below the mean bright band height within
;                which a sample touching (above) [below] this layer is
;                considered to be within (above) [below] the BB.  If not
;                specified, takes on the default value (0.750) defined in
;                fprep_geo_match_profiles().
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
; verbose      - Binary parameter.  If set, then print position coordinates for
;                user-selected x-sect locations on the PPIs, in terms of window
;                coordinates and computed 2A-25 data array scan,ray coordinates.
;
; INTERNAL MODULES
; ----------------
; 1) pr_and_geo_match_x_sections - Main driver procedure called by user.
;
; 2) gen_pr_and_geo_match_x_sections - Workhorse procedure to read data,
;                                      create plots, and allow interactive
;                                      selection of cross section locations on
;                                      the PR or GR PPI plots displayed.
;
; 3) plot_sweep_2_zbuf_4xsec - Generates a pseudo-PPI of scan and ray number to
;                              allow determination of cross section location
;                              in terms of the original 2A-25 array coordinates.
;
; 4) gv_z_s2ku_4xsec - Applies S-band to Ku-band adjustment to the copy of GR
;                      reflectivity to be rendered in current x-section.
;
; HISTORY
; -------
; 07/06/09 Morris, GPM GV, SAIC
; - Fixed handling of color table within interactive cursor loop in module
;   gen_pr_and_geo_match_x_sections.  Removed 'hot corners' from PR PPI.
; 07/09/09 Morris, GPM GV, SAIC
; - Added annotations to cross sections to indicate PctAbvThresh value and
;   GR calibration offset.  Added GVOFF keyword parameter for call to external
;   procedure 'plot_geo_match_xsections'.
; 07/20/09 Morris, GPM GV, SAIC
; - Changed call to rsl_colorbar to a call to vn_colorbar to fix error in color
;   bar labeling.
; 07/23/09 Morris, GPM GV, SAIC
; - Added capability to do S-to-Ku frequency adjustment to GR reflectivity.
;   Includes addition of new internal module, gv_z_s2ku_4xsec.
; 08/04/09 Morris, GPM GV, SAIC
; - Re-init color table before each call to plot_geo_match_xsections, now that
;   image count 128 has a conflicting redefinition in plot_pr_xsection.pro.
; 11/04/09 Morris, GPM GV, SAIC
; - Added output of 2A-25 Path-Integrated Attenuation (PIA) and ray locations
;   along x-section.  Enhanced pattern/title for manual file selections that
;   use DIALOG_PICKFILE in module 1.
; 11/13/09  Morris/GPM GV/SAIC
; -  Added parameter/value GET_ONLY='2A25' to call to find_pr_products() in
;    gen_pr_and_geo_match_x_sections to look for only the 2A25 product type
; 04/12/10  Morris/GPM GV/SAIC
; - Modified PPI pixmap/buffer code to plot over the maximum range of the data
;   as indicated in the netCDF file, rather than a fixed 125 km cutoff.
; 04/21/10  Morris/GPM GV/SAIC
; - Modified computation of the mean bright band height to exclude points with
;   obvious overestimates of BB height in the 2A25 rangeBinNums.  Separated this
;   code into a separate function usable by multiple programs.
; - Modified the logic to pick the sweep elevation to be displayed in the PPIs,
;   to override the elev2show parameter when there are fewer sweeps than this
;   in the radar volume.
; 04/30/10  Morris/GPM GV/SAIC
; - Modified logic to handle output from find_pr_products() to make the parsing
;   of values in the returned string non-position-dependent.
; 05/05/10 Morris, GPM GV, SAIC
; - Now calls FPREP_GEO_MATCH_PROFILES() to read netCDF file and prepare the
;   data fields, and compute the mean bright band height.
; - Fixed new bug introduced by use of FPREP_GEO_MATCH_PROFILES(), need to
;   extract the one-level, 1-D array rnTypeIn from sweep-level rnType array so
;   that blanked reflectivity sample locations still show in PPIs as hatching.
; 05/11/10  Morris/GPM GV/SAIC
; - Labeled windows with titles, changed GV acronym to GR.
; - Added 'AN' label to animation hot corner.  Made first user message specific
;   to NO_2A25 state.
; 05/12/10  Morris/GPM GV/SAIC
; - Added 'bbprox' as a parameter in call to plot_geo_match_xsections() to
;   support computation of X-section reflectivity differences by BB category.
; 05/13/10  Morris/GPM GV/SAIC
; - Fixed bug where procedure would crash if S-to-Ku 'hot corner' was selected
;   before a cross section was displayed, and changed user messages in this and
;   the two reflectivity adjustment hot buttons for such a situation.
; -5/28/10  Morris/GPM GV/SAIC
; - Added print command to output program version number.  Removed 'include'
;   declarations for plot_pr_xsection.pro and plot_geo_match_xsections.pro.
; 01/21/11  Morris/GPM GV/SAIC
; - Add BBBYRAY keyword option to enable/disable plot of ray-specific BB height
; - Add VERSION_PR option to search for file patterns according to the version
;   of PR products used in the PR-GR matchup files.
; 07/12/11  Morris/GPM GV/SAIC
; - Added logic to obtain PR 2A-25 filename from the matchup netCDF file, for
;   version 2.1 or later netCDF files.
; - Added call to get_gr_geo_match_rain_type() to compute GR-derived rain type
;   from vertical profiles of GR reflectivity (gvz_vpr field).  Use the
;   resulting rain type arrays in the GR PPI plot, and added to the parameters
;   in calls to plot_geo_match_xsections().
; 01/20/12  Morris/GPM GV/SAIC
; - Remove VERSION_PR parameter from call sequences.  Use the PR-GR matchup
;   file metadata to obtain the version of PR products used.
; 02/06/12  Morris/GPM GV/SAIC
; - Changed back to calling fprep_geo_match_profiles now that accumulated
;   changes from fprep_geo_match_profiles2_1 have been merged into it.
; - Changed logic to proceed with NO_2A25 reset to ON if it was originally OFF
;   and a 2A25 file was not found or manually selected.
; - Added PR product version to the legend information in the X-section plots.
; - Enhanced labeling of PR PPI panel on x-section location selector window.
; - Made the cross section endpoint 'A' and 'B' labels bigger and in shadow text
;   to increase visibility.
; - Modified output message describing the interactive options once a cross
;   section is displayed.
; - Added VERBOSE keyword to control cursor location selection information to be
;   printed or suppressed (default).
; - Eliminated routine messages from loadct().
; 02/06/12  Morris/GPM GV/SAIC
; - Changed program version to 1.2 in the startup message, to reflect multiple
;   enhancements.
; 07/26/12  Morris/GPM GV/SAIC
; - Added PLOTBBSEP parameter option to pass along to plot_geo_match_xsections()
;   to enable plotting of a separator delimiting sample volumes at the top and
;   bottom of the "within BB" layer.
; - Added BBWIDTH parameter to pass along to fprep_geo_match_profiles(),
;   plot_geo_match_xsections(), and plot_pr_xsection() to allow variable width
;   of BB influence used in determining bbProx category.
; 08/01/12  Morris/GPM GV/SAIC
; - Added HIDE_RNTYPE parameter to inhibit encoding of rain type (hash patterns)
;   in the PPI plots, and rain type color bars in the volume-match x-sections.
; 08/08/12  Morris/GPM GV/SAIC
; - Added option to automatically step through all the scans in the matchup area
;   and display a sequence of cross sections, scan by scan.
; 08/10/12  Morris/GPM GV/SAIC
; - Added PAUSE parameter to control dwell time between steps when automatically
;   displaying a sequence of cross sections for all scans in the matchup set.
; 08/14/12  Morris/GPM GV/SAIC
; - Replaced all calls to procedure plot_geo_match_xsections() with calls to
;   function plot_geo_match_xsections_zbuf(), and handled creation of windows to
;   display the returned z-buffers.
; 08/15/12  Morris/GPM GV/SAIC
; - Added CREF parameter to plot PPIs of Composite Reflectivity (highest
;   reflectivity in the vertical column) rather than for a fixed sweep elevation.
; - Replaced all calls to procedure plot_pr_xsection() with calls to
;   function plot_pr_xsection_zbuf(), and handled creation of windows to
;   display the returned z-buffers.
; - Changed program version to 2.0 in the startup message, to reflect multiple
;   major enhancements.
; 08/31/12  Morris/GPM GV/SAIC
; - Removed inadvertent non-ASCII characters from print statements text RE wait
;   time (pause) value override.
; 09/06/12  Morris/GPM GV/SAIC
; - Added ZOOMH parameter to explicitly control the width and location of how
;   the rays are plotted in the cross section window.  See PARAMETERS, above.
; - Added UNDEFINE procedure to support zoomh behaviors when switching from
;   cursor mode of x-section selection and automatic step-through mode.
; - Added LABEL_BY_RAYNUM parameter to explicitly control the type of label
;   plotted at the endpoints of the cross section.
; - Added a PRINT message to the terminal asking user to select a control file.
; 09/07/12  Morris/GPM GV/SAIC
; - Replaced FIXEDRAYS parameter with the STARTEND2SHOW parameter in calls to
;   plot_pr_xsection().
; 09/13/12  Morris/GPM GV/SAIC
; - Changed keyword NO_2A25 to SKIP_2A25.
;
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
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
; section location in terms of the original 2A-25 array coordinates.


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

pro gen_pr_and_geo_match_x_sections, ncfilepr, use_db, skip_2a25_orig, $
                  ELEV2SHOW=elev2show, PCT_ABV_THRESH=pctAbvThresh, $
                  PR_ROOT_PATH=pr_root_path, UFPATH=ufpath, BBBYRAY=BBbyRay, $
                  PLOTBBSEP=plotBBsep, BBWIDTH=bbwidth, CREF=cref, $
                  HIDE_RNTYPE=hide_rntype, PAUSE=pause, ZOOMH=zoomh, $
                  LABEL_BY_RAYNUM=label_by_raynum, VERBOSE=verbose
;
;
; DESCRIPTION
; -----------
; Called from pr_and_geo_match_x_sections procedure (included in this file).
; Reads PR and GR reflectivity and spatial fields from a user-selected geo_match
; netCDF file, and builds a PPI of the data for a given elevation sweep.  Then
; allows a user to select a point on the image for which vertical cross
; sections along the PR scan line through the selected point will be plotted 
; from volume-matched PR and GR data, and if skip_2a25 is 0, also plots cross
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
; PR and GR data and full-resolution GR data from the original radar UF file
; is generated, and permits the user to assess the quality of the geo-alignment
; between the PR and GR data.
;

COMMON sample, start_sample, sample_range, num_range, RAYSPERSCAN

; "Include" file for PR-product-specific parameters (i.e., RAYSPERSCAN):
@dpr_params.inc
@pr_params.inc
; "Include" file for names, default paths, etc.:
@environs.inc
; "Include file for netCDF-read structs
@geo_match_nc_structs.inc

; Override default path to PR product files if specified in PR_ROOT_PATH
IF ( N_ELEMENTS( pr_root_path ) EQ 1 ) THEN BEGIN
   print, 'Overriding default path to PR files: ', PRDATA_ROOT, ', to: ', $
          pr_root_path
   PRDATA_ROOT = pr_root_path
ENDIF

; set this module's skip_2a25 value to the passed-in value, as we may have reset
; it if the last 2A25 file couldn't be found
skip_2a25 = skip_2a25_orig

; set up pointers for each field to be returned from fprep_geo_match_profiles()
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

; read the geometry-match variables and arrays from the file, and preprocess them
; to remove the 'bogus' PR ray positions.  Return a pointer to each variable read.

status = fprep_geo_match_profiles( ncfilepr, heights, $
    PCT_ABV_THRESH=pctAbvThresh, GV_CONVECTIVE=0, $
    GV_STRATIFORM=0, PTRfieldflags=ptr_fieldflags, PTRgeometa=ptr_geometa, $
    PTRsweepmeta=ptr_sweepmeta, PTRsitemeta=ptr_sitemeta, PTRfilesmeta=ptr_filesmeta, $
    PTRGVZ=ptr_gvz, PTRzcor=ptr_zcor, $
    PTRtop=ptr_top, PTRbotm=ptr_botm, $
    PTRraintype_int=ptr_rnType, PTRpridx_long=ptr_pr_index, $
    PTRxCorners=ptr_xCorner, PTRyCorners=ptr_yCorner, PTRbbProx=ptr_bbProx, $
    PTRpctgoodpr=ptr_pctgoodpr, $
    PTRpctgoodgv=ptr_pctgoodgv, PTRpctgoodrain=ptr_pctgoodrain, BBPARMS=BBparms, $
    BBWIDTH=bbwidth )

IF (status EQ 1) THEN GOTO, errorExit

; create local data field arrays/structures needed here, and free pointers we no longer need
; to free the memory held by these pointer variables
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
  gvz_in = gvz     ; for plotting as PPI
    ptr_free,ptr_gvz
  zcor=*ptr_zcor
  zcor_in = zcor   ; for plotting as PPI
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

; Determine the pathnames of the PR product files:

; -- parse ncfile1 to get the component fields: site, orbit number, YYMMDD
dataPR = FILE_BASENAME(ncfilepr)
parsed=STRSPLIT( dataPR, '.', /extract )
orbit = parsed[3]
DATESTAMP = parsed[2]      ; in YYMMDD format
ncsite = parsed[1]
print, dataPR, " ", orbit, " ", DATESTAMP, " ", ncsite
; put together a title field for the cross-sections
verstring = "V"+STRTRIM( STRING(mygeometa.PR_Version), 2 )
caseTitle25 = ncsite+'/'+DATESTAMP + ', '+verstring + ', Orbit '+orbit
IF ( pctAbvThresh EQ 0.0 ) THEN BEGIN
   caseTitle = caseTitle25+", All Points"
ENDIF ELSE BEGIN
   caseTitle = caseTitle25+", "+STRING(pctAbvThresh,FORMAT='(i0)')+"% bins > Threshold"
ENDELSE

; Identify the original DPR filename for this orbit/subset, if plotting
; full-resolution DPR data cross sections:
stop
IF ( skip_2a25 NE 1 ) THEN BEGIN
   file2get = PRDATA_ROOT+'/2A25/'+filesmeta.file_2a25
   File25Name = file_search(file2get,COUNT=nf)
   IF nf EQ 1 THEN BEGIN
      print, "Using 2A25 filename in matchup file: ", filesmeta.file_2a25
      file_2a25 = File25Name
   ENDIF ELSE BEGIN
      print, "Looking for matching 2A25 filename for matchup file: ", dataPR
      prfiles4 = ''
      status = find_pr_products( dataPR, PRDATA_ROOT, prfiles4, USE_DB=use_db, $
                                 GET_ONLY='2A25', VERSION_PR=mygeometa.PR_Version )
;      print, prfiles4
      parsepr = STRSPLIT( prfiles4, '|', /extract )
;      idx21 = WHERE(STRPOS(parsepr,'1C21') GT 0, count21)
;      if count21 EQ 1 THEN file_1c21 = STRTRIM(parsepr[idx21],2) ELSE file_1c21='no_1C21_file'
;      idx23 = WHERE(STRPOS(parsepr,'2A23') GT 0, count23)
;      if count23 EQ 1 THEN file_2a23 = STRTRIM(parsepr[idx23],2) ELSE file_2a23='no_2A23_file'
      idx25 = WHERE(STRPOS(parsepr,'2A25') GT 0, count25)
      if count25 EQ 1 THEN file_2a25 = STRTRIM(parsepr[idx25],2) ELSE file_2a25='no_2A25_file'
;      idx31 = WHERE(STRPOS(parsepr,'2B31') GT 0, count31)
;      if count31 EQ 1 THEN file_2b31 = STRTRIM(parsepr[idx31],2) ELSE file_2b31='no_2B31_file'
      IF ( status NE 0 AND file_2a25 EQ 'no_2A25_file' ) THEN BEGIN
         PRINT, ""
         PRINT, "ERROR finding 2A-25 product file."
         PRINT, "Proceeding with SKIP_2A25 set to ON, skipping 2A25 full-resolution plots."
         skip_2a25 = 1
       
         ;PRINT, "Skipping events for orbit = ", orbit
         PRINT, ""
         ;GOTO, errorExit
      ENDIF
   ENDELSE
ENDIF

IF ( skip_2a25 NE 1 ) THEN BEGIN
  ; initialize PR variables/arrays and read 2A25 fields
   SAMPLE_RANGE=0
   START_SAMPLE=0
   num_range = NUM_RANGE_2A25
   dbz_2a25=FLTARR(sample_range>1,1,num_range)
   rain_2a25 = FLTARR(sample_range>1,1,num_range)
   surfRain_2a25=FLTARR(sample_range>1,RAYSPERSCAN)
   geolocation=FLTARR(2,RAYSPERSCAN,sample_range>1)
   rangeBinNums=INTARR(sample_range>1,RAYSPERSCAN,7)
   rainFlag=INTARR(sample_range>1,RAYSPERSCAN)
   rainType=INTARR(sample_range>1,RAYSPERSCAN)
   pia=FLTARR(3,RAYSPERSCAN,sample_range>1)

   status = read_pr_2a25_fields( file_2a25, DBZ=dbz_2a25, RAIN=rain_2a25,   $
                                 TYPE=rainType, SURFACE_RAIN=surfRain_2a25, $
                                 GEOL=geolocation, RANGE_BIN=rangeBinNums,  $
                                 RN_FLAG=rainFlag, PIA=pia )
   IF ( status NE 0 ) THEN BEGIN
      PRINT, ""
      PRINT, "ERROR reading fields from ", file_2a25
      PRINT, "Skipping events for orbit = ", orbit
      PRINT, ""
      GOTO, errorExit
   ENDIF
ENDIF

;-------------------------------------------------
   startpath = '/data/gpmgv'
   dprFileMatch = DIALOG_PICKFILE(PATH=startpath,FILTER='*GPM*'+orbit+'*', $
                                  TITLE='Select a DPR/Ka/Ku file')

  ; get filenames as listed in/on the database/disk
   idxDPR = WHERE(STRPOS(dprFileMatch,'2A.GPM.DPR') GE 0, countDPR)
   if countDPR EQ 1 THEN BEGIN
      origFileDPRName = dprFileMatch
      DPR_frequency='DPR'
      DPR_scantype = 'NS'
   ENDIF ELSE origFileDPRName='no_2ADPR_file'

   idxKU = WHERE(STRPOS(dprFileMatch,'2A.GPM.Ku') GE 0, countKU)
   if countKU EQ 1 THEN BEGIN
       origFileKuName = dprFileMatch
      DPR_frequency='Ku'
      DPR_scantype = 'NS'
   ENDIF ELSE origFileKuName='no_2AKU_file'

   idxKA = WHERE(STRPOS(dprFileMatch,'2A.GPM.Ka') GE 0, countKA)
   if countKA EQ 1 THEN BEGIN
       origFileKaName = dprFileMatch
       DPR_frequency='Ka'
       DPR_scantype = 'MS'
   ENDIF ELSE origFileKaName='no_2AKA_file'

   idxCMB = WHERE(STRPOS(dprFileMatch,'2B.GPM.COMB') GE 0, countCMB)
   if countCMB EQ 1 THEN origFileCMBName = dprFileMatch $
      ELSE origFileCMBName='no_2BCMB_file'

   IF ( origFileKaName EQ 'no_2AKA_file' AND $
        origFileKuName EQ 'no_2AKU_file' AND $
        origFileDPRName EQ 'no_2ADPR_file' ) THEN BEGIN
      PRINT, ""
      message, "ERROR finding a 2A-DPR, 2A-KA , or 2A-KU product file name"
   ENDIF

;  add the well-known (or local) paths to get the fully-qualified file names
   file_2adpr = origFileDPRName
   file_2aku  = origFileKuName
   file_2aka  = origFileKaName
   file_2bcmb = origFileCMBName

   ; check DPR_frequency and DPR_scantype consistency
   CASE STRUPCASE(DPR_frequency) OF
       'KA' : BEGIN
                 ; do we have a 2AKA filename?
                 IF FILE_BASENAME(origFileKaName) EQ 'no_2AKA_file' THEN $
                    message, "KA specified on control file line, but no " + $
                             "valid 2A-KA file name: " + dataPR
                 ; 2AKA has only HS and MS scan/swath types
                 CASE STRUPCASE(DPR_scantype) OF
                    'HS' : BEGIN
                              RAYSPERSCAN = RAYSPERSCAN_HS
                              GATE_SPACE = BIN_SPACE_HS
                           END
                    'MS' : BEGIN
                              RAYSPERSCAN = RAYSPERSCAN_MS
                              GATE_SPACE = BIN_SPACE_NS_MS
                           END
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
                              RAYSPERSCAN = RAYSPERSCAN_NS
                              GATE_SPACE = BIN_SPACE_NS_MS
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
                 dpr_data = read_2adpr_hdf5(file_2adpr, SCAN=DPR_scantype)
                 dpr_file_read = origFileDPRName
              END
   ENDCASE

   ; check dpr_data structure for read failures
   IF SIZE(dpr_data, /TYPE) NE 8 THEN $
     message, "Error reading data from: "+file_2adpr

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

   IF PTR_VALID(ptr_swath.PTR_PRE) THEN BEGIN
      dbz_1c21dpr = (*ptr_swath.PTR_PRE).ZFACTORMEASURED
      binRealSurface = (*ptr_swath.PTR_PRE).BINREALSURFACE
      binClutterFreeBottom = (*ptr_swath.PTR_PRE).binClutterFreeBottom
   ENDIF ELSE message, "Invalid pointer to PTR_PRE."

   IF PTR_VALID(ptr_swath.PTR_SLV) THEN BEGIN
      dbz_2a25dpr = (*ptr_swath.PTR_SLV).ZFACTORCORRECTED
   ENDIF ELSE message, "Invalid pointer to PTR_SLV."

   IF PTR_VALID(ptr_swath.PTR_SRT) THEN BEGIN
   ENDIF ELSE message, "Invalid pointer to PTR_SRT."

   IF PTR_VALID(ptr_swath.PTR_VER) THEN BEGIN
   ENDIF ELSE message, "Invalid pointer to PTR_VER."

   ; free the memory/pointers in data structure
   free_ptrs_in_struct, dpr_data ;, /ver

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

print, "Mean BB (AGL) from PR: ", STRING(BBparms.meanBB, FORMAT='(F0.1)') & print, ""

;-------------------------------------------------

; Set up the pixmap window for the PPI plots
windowsize = 350
xsize = windowsize[0]
ysize = xsize
IF ( pctAbvThresh GT 0 ) THEN title = STRING(pctAbvThresh,FORMAT='(i0)')+"% above-threshold samples shown" $
ELSE title = "All available samples shown"
window, 0, xsize=xsize, ysize=ysize*2, xpos = 75, TITLE = title, /PIXMAP

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
   prtitle = "PR "+verstring+" 2A-25 Composite Ze"
ENDIF ELSE BEGIN
   elevstr =  string(mysweeps[ifram].elevationAngle, FORMAT='(f0.1)')
   prtitle = "PR "+verstring+" 2A-25 Ze along "+mysite.site_ID+" "+elevstr+" degree sweep"
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

; add a "hot corner" to the GR image to click on to initiate alignment check
mygvbuf[0:20,0:20] = 254B
; add a hot corner to subtract 1 dBZ from GR and re-run x-sect differences
mygvbuf[windowsize-41:windowsize-22,windowsize-20:windowsize-1] = 253B
; add a hot corner to add 1 dBZ to GR and re-run x-sect differences
mygvbuf[windowsize-20:windowsize-1,windowsize-20:windowsize-1] = 252B
; add a hot corner to toggle between original and Ku-adjusted GR reflectivity
mygvbuf[windowsize-62:windowsize-43,windowsize-20:windowsize-1] = 251B
; add a "hot corner" to initiate cross-section step-through animation
mygvbuf[22:41,0:20] = 250B


;-------------------------------------------------

; Build the corresponding PR scan and ray number buffers (not displayed).  Need
; to cut one layer out of pr_index, which has been replicated over each sweep
; level by fprep_geo_match_profiles():
pr_scan = pr_index[*,0] & pr_ray = pr_index[*,0]
idx2get = WHERE( pr_index[*,0] GE 0 )  ; this should be ALL points if from fprep_geo_match_profiles()
pridx2get = pr_index[idx2get,0]

; analyze the pr_index, decomposed into PR-product-relative scan and ray number
IF ( skip_2a25 EQ 0 ) THEN BEGIN
  ; expand this subset of PR master indices into its scan,ray coordinates.  Use
  ;   rainFlag as the subscripted data array
;   print, 'using ARRAY_INDICES( rainFlag )'
   rayscan = ARRAY_INDICES( rainFlag, pridx2get )
   raypr = rayscan[1,*] & scanpr = rayscan[0,*]
ENDIF ELSE BEGIN
  ; derive the original number of scans in the file using the 'step' between
  ;   rays of the same scan - this **USUALLY** works, but is a bit of trickery
   print, 'Using trickery to derive scan and ray numbers, this may fail...'
   print, ''
  ; find the statistical mode of the pridx change from one point to the next
  ; -- this should be equal to the value of sample_range used to determine the
  ;    original pr_master_index values
  ; the following algorithm is documented at http://www.dfanning.com/code_tips/mode.html
   ngoodpr = n_elements(pridx2get)
   array= (ABS(pridx2get[0:ngoodpr-2]-pridx2get[1:ngoodpr-1]))
   array = array[Sort(array)]
   wh = where(array ne Shift(array,-1), cnt)
   if cnt eq 0 then mode = array[0] else begin
      void = Max(wh-[-1,wh], mxpos)
      mode = array[wh[mxpos]]
   endelse
   sample_range = mode
  ; expand this subset of PR master indices into its scan,ray coordinates.
   raypr = pridx2get/sample_range
   scanpr = pridx2get MOD sample_range
ENDELSE

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
; add a "hot corner" matching the GR PPI image, to return special value to
; initiate cross-section step-through animation
myscanbuf[22:41,0:20] = 250B
myraybuf[22:41,0:20] = 250B

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
xyouts, 25, 7, color=0, "SC", /DEVICE, CHARSIZE=1
window, 1, xsize=xsize, ysize=ysize*2, xpos = 350, ypos=50, TITLE = title
Device, Copy=[0,0,xsize,ysize*2,0,0,0]

;-------------------------------------------------

; Let the user select the cross-section locations:
print, ''
print, 'Left click on a PPI point to display a cross section of PR and GR volume-match data'
IF ( skip_2a25 NE 1 ) THEN print, 'and full-vertical-resolution (250 m) PR 2A-25 data,'
print, "or left click on the white square 'SC' at the lower right to step through"
print, "an animation sequence of cross sections for each PR scan in the dataset,"
print, 'or Right click inside PPI to select another case:'
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

WHILE ( !Mouse.Button EQ 1 ) DO BEGIN
   WSet, 1
   CURSOR, xppi, yppi, /DEVICE, /DOWN
   IF ( !Mouse.Button NE 1 ) THEN BREAK
   IF KEYWORD_SET(verbose) THEN print, "X: ", xppi, "  Y: ", yppi MOD ysize
   scanNum = myscanbuf[xppi, yppi MOD ysize]

   IF ( scanNum GT 2 AND scanNum LT 250B ) THEN BEGIN  ; account for +3 offset and hot corner values

      IF ( havewin2 EQ 1 ) THEN BEGIN
         IF ( skip_2a25 NE 1 ) THEN WDELETE, 3
         WDELETE, 5
         WDELETE, 6
         tvlct, rr, gg, bb
      ENDIF

      scanNumpr = scanNum + scanoff - 3L
      IF KEYWORD_SET(verbose) THEN print, "Product-relative scan number: ", scanNumpr+1  ; 1-based

      rayNum = myraybuf[xppi, yppi MOD ysize]
      rayNumpr = rayNum - 3L
      IF KEYWORD_SET(verbose) THEN print, "PR ray number: ", rayNumpr+1  ; 1-based

; get the geolocation of this selected point so that we can find this same scan
; in the GPM test product
selectLat = geolocation[0, rayNumpr, scanNumpr]
selectLon = geolocation[1, rayNumpr, scanNumpr]
idxdpr = WHERE( ABS(dprlats-selectLat) LT 0.001 and ABS(dprlons-selectLon)  LT 0.001, countmatch)
IF countmatch EQ 1 THEN BEGIN
   dprrayscan = array_indices(dprlats,idxdpr)
   dprray = dprrayscan[0]
   dprscan = dprrayscan[1]
ENDIF

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
      Device, Copy=[0,0,xsize,ysize*3,0,0,0]  ; erase the prior line, if any
      idxlinebeg = WHERE( myscanbuf EQ scanNum and myraybuf EQ raystart, countbeg )
      idxlineend = WHERE( myscanbuf EQ scanNum and myraybuf EQ rayend, countend )
      startxys = ARRAY_INDICES( myscanbuf, idxlinebeg )
      endxys = ARRAY_INDICES( myscanbuf, idxlineend )
      xbeg = MEAN( startxys[0,*] ) & xend = MEAN( endxys[0,*] )
      ybeg = MEAN( startxys[1,*] ) & yend = MEAN( endxys[1,*] )
      PLOTS, [xbeg, xend], [ybeg, yend], /DEVICE, COLOR=122, THICK=2

     ; determine the labeling option in effect, and format labels accordingly
      IF ( label_by_raynum ) THEN BEGIN
         leftlbl = STRING(raystartpr+1, FORMAT='(I0)')  ; 1-based for labels
         rightlbl = STRING(rayendpr+1, FORMAT='(I0)')
      ENDIF ELSE BEGIN
         leftlbl = 'A'
         rightlbl = 'B'
      ENDELSE
      XYOUTS, xbeg+1, ybeg-1, leftlbl, /DEVICE, COLOR=0, CHARSIZE=2, CHARTHICK=2  ; underplot in black
      XYOUTS, xend+1, yend-1, rightlbl, /DEVICE, COLOR=0, CHARSIZE=2, CHARTHICK=2
      XYOUTS, xbeg, ybeg, leftlbl, /DEVICE, COLOR=122, CHARSIZE=2, CHARTHICK=2    ; overplot in white
      XYOUTS, xend, yend, rightlbl, /DEVICE, COLOR=122, CHARSIZE=2, CHARTHICK=2

     ; now repeat line/labels for the upper PPI panel
      ybeg = ybeg+ysize & yend = yend+ysize
      PLOTS, [xbeg, xend], [ybeg, yend], /DEVICE, COLOR=122, THICK=2
      XYOUTS, xbeg+1, ybeg-1, leftlbl, /DEVICE, COLOR=0, CHARSIZE=2, CHARTHICK=2
      XYOUTS, xend+1, yend-1, rightlbl, /DEVICE, COLOR=0, CHARSIZE=2, CHARTHICK=2
      XYOUTS, xbeg, ybeg, leftlbl, /DEVICE, COLOR=122, CHARSIZE=2, CHARTHICK=2
      XYOUTS, xend, yend, rightlbl, /DEVICE, COLOR=122, CHARSIZE=2, CHARTHICK=2

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

      IF ( skip_2a25 NE 1 ) THEN BEGIN
        ; generate the PR full-resolution vertical cross section plot
         meanBBmsl = BBparms.meanBB + mysite.site_elev   ; adjust back to MSL for 2A25 plot
         tvlct, rr, gg, bb
         olddevice = !D.NAME

         prxsect_struct = plot_pr_xsection_zbuf( scanNumpr, raystartpr, rayendpr, $
                              dbz_2a25, meanBBmsl, DBZSCALE2A25, rangeBinNums, $
                              TITLE=caseTitle25, BBBYRAY=BBbyRay, BBWIDTH=bbwidth, $
                              STARTEND2SHOW=startend2show, LABEL_BY_RAYNUM=label_by_raynum )

         title = "PR 2A-25 Reflectivity, 250m gates"
         SET_PLOT, olddevice
         WINDOW, 3, xsize=prxsect_struct.xs_pr2, ysize=prxsect_struct.ys_pr2, $
                    ypos=50, TITLE = title
         tvlct, prxsect_struct.redct, prxsect_struct.grnct, prxsect_struct.bluct
         TV, prxsect_struct.PR2_XSECT

scaledpr=100.
;plot_dpr_xsection_bb2, dprscan, raystartpr, rayendpr, dbz_2a25dpr, meanbbmsl, scaledpr, $
;                      TITLE=caseTitle25, ALTWINDOW=7, SURFBIN=binRealSurface, $
;                      CLUTTERFREEBIN=binClutterFreeBottom

         dprxsect_struct = plot_dpr_xsection_zbuf( dprscan, raystartpr, rayendpr, $
                              dbz_2a25dpr, meanBBmsl, scaledpr, TITLE=caseTitle25, $
                              BBBYRAY=BBbyRay, BBWIDTH=bbwidth, $
                              STARTEND2SHOW=startend2show, $
                              LABEL_BY_RAYNUM=label_by_raynum, $
                              SURFBIN=binRealSurface, $
                              CLUTTERFREEBIN=binClutterFreeBottom )

         title = "DPR Reflectivity, 125m gates"
         SET_PLOT, olddevice
         WINDOW, 7, xsize=dprxsect_struct.xs_pr2, ysize=dprxsect_struct.ys_pr2, $
                    ypos=50, TITLE = title
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
                                LABEL_BY_RAYNUM=label_by_raynum )

      SET_PLOT, olddevice  ; reset the device type for rendering x-sections
      WINDOW, 5, xsize=xsect_struct.xs_prgr, ysize=xsect_struct.ys_prgr, ypos=50, $
              TITLE = "PR and GR Volume Match X-Sections"
      TV, xsect_struct.PRGR_XSECT    ; plot the PR and GR geo-match x-sections
      WINDOW, 6, xsize=xsect_struct.xs_diff, ysize=xsect_struct.ys_diff, $
              TITLE = "PR-GR Volume Match Differences"
     ; reset the color tables for the PR-GR difference x-section, and plot it
      tvlct, xsect_struct.redct, xsect_struct.grnct, xsect_struct.bluct
      TV, xsect_struct.DIFF_XSECT
      havewin2 = 1  ; need to delete x-sect windows at end

      print, ''
      print, '---------------------------------------------------------------------'
      print, ''
      print, "Next actions:"
      print, " - Left click in a PPI image for another cross-section location."
      print, " - Left click on a +1 or -1 labeled white square to adjust the"
      print, "   geo_match GR reflectivities by the indicated amount, and re-draw."
      print, " - Left click on the K,S labeled white square to toggle the S-band to"
      print, "   Ku-band adjustment to the geo-match GR reflectivities, and re-draw."
      print, " - Left click on the white square at the lower right to display a PPI"
      print, "   animation loop of volume-match and full-resolution PR and GR data."
      print, " - Left click on the white square 'SC' at the lower right to step through"
      print, "   an animation sequence of cross sections for each PR scan in the dataset."
      print, ' - Right click inside a PPI image to select another case.'
      print, ''

   ENDIF ELSE BEGIN   ; ( scanNum GT 2 AND scanNum LT 250B )

     ; only the lower (GR) image has hot corners, check whether cursor lies there
      IF ( yppi LE ysize ) THEN BEGIN
      CASE scanNum OF
         254B : status = loop_pr_gv_gvpolar_ppis(ncfilepr, ufpath, 3, (ifram+1)*2 < nframes)
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
                      olddevice = !D.NAME  ; grab the current device, since it will be redefined
                                           ; in call to plot_geo_match_xsections_zbuf()

                      xsect_struct = plot_geo_match_xsections_zbuf( gvz4xsec, zcor, top, botm, $
                                bbprox, BBparms.meanBB, nframes, $
                                idxcurscan, idxmin, idxmax, TITLE=caseTitle, $
                                GVOFF=gvzoff, S2KU=is_ku, PRAINTYPE=rnTypeIn, $
                                GRAINTYPE= gvrtype, PLOTBBSEP=plotBBsep, $
                                BBWIDTH=bbwidth, HIDE_RNTYPE=hide_rntype, $
                                RAYSTARTEND=raystartend, STARTEND2SHOW=startend2show)

                      SET_PLOT, olddevice  ; reset the device type for rendering x-sections
                      WINDOW, 5, xsize=xsect_struct.xs_prgr, ysize=xsect_struct.ys_prgr, ypos=50, $
                              TITLE = "PR and GR Volume Match X-Sections"
                      TV, xsect_struct.PRGR_XSECT    ; plot the PR and GR geo-match x-sections
                      WINDOW, 6, xsize=xsect_struct.xs_diff, ysize=xsect_struct.ys_diff, $
                              TITLE = "PR-GR Volume Match Differences"
                     ; reset the color tables for the PR-GR difference x-section, and plot it
                      tvlct, xsect_struct.redct, xsect_struct.grnct, xsect_struct.bluct
                      TV, xsect_struct.DIFF_XSECT
                   ENDIF ELSE print, "NOTE:  No cross section displayed -- no GR calibration adjustment applied."
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
                      olddevice = !D.NAME  ; grab the current device, since it will be redefined
                                           ; in call to plot_geo_match_xsections_zbuf()

                      xsect_struct = plot_geo_match_xsections_zbuf( gvz4xsec, zcor, top, botm, $
                                bbprox, BBparms.meanBB, nframes, $
                                idxcurscan, idxmin, idxmax, TITLE=caseTitle, $
                                GVOFF=gvzoff, S2KU=is_ku, PRAINTYPE=rnTypeIn, $
                                GRAINTYPE= gvrtype, PLOTBBSEP=plotBBsep, $
                                BBWIDTH=bbwidth, HIDE_RNTYPE=hide_rntype, $
                                RAYSTARTEND=raystartend, STARTEND2SHOW=startend2show, $
                                LABEL_BY_RAYNUM=label_by_raynum )

                      SET_PLOT, olddevice  ; reset the device type for rendering x-sections
                      WINDOW, 5, xsize=xsect_struct.xs_prgr, ysize=xsect_struct.ys_prgr, ypos=50, $
                              TITLE = "PR and GR Volume Match X-Sections"
                      TV, xsect_struct.PRGR_XSECT    ; plot the PR and GR geo-match x-sections
                      WINDOW, 6, xsize=xsect_struct.xs_diff, ysize=xsect_struct.ys_diff, $
                              TITLE = "PR-GR Volume Match Differences"
                     ; reset the color tables for the PR-GR difference x-section, and plot it
                      tvlct, xsect_struct.redct, xsect_struct.grnct, xsect_struct.bluct
                      TV, xsect_struct.DIFF_XSECT
                   ENDIF ELSE print, "NOTE: No cross section displayed -- no GR calibration adjustment applied."
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
                      olddevice = !D.NAME  ; grab the current device, since it will be redefined
                                           ; in call to plot_geo_match_xsections_zbuf()

                      xsect_struct = plot_geo_match_xsections_zbuf( gvz4xsec, zcor, top, botm, $
                                bbprox, BBparms.meanBB, nframes, $
                                idxcurscan, idxmin, idxmax, TITLE=caseTitle, $
                                GVOFF=gvzoff, S2KU=is_ku, PRAINTYPE=rnTypeIn, $
                                GRAINTYPE= gvrtype, PLOTBBSEP=plotBBsep, $
                                BBWIDTH=bbwidth, HIDE_RNTYPE=hide_rntype, $
                                RAYSTARTEND=raystartend, STARTEND2SHOW=startend2show)

                      SET_PLOT, olddevice  ; reset the device type for rendering x-sections
                      WINDOW, 5, xsize=xsect_struct.xs_prgr, ysize=xsect_struct.ys_prgr, ypos=50, $
                              TITLE = "PR and GR Volume Match X-Sections"
                      TV, xsect_struct.PRGR_XSECT    ; plot the PR and GR geo-match x-sections
                      WINDOW, 6, xsize=xsect_struct.xs_diff, ysize=xsect_struct.ys_diff, $
                              TITLE = "PR-GR Volume Match Differences"
                     ; reset the color tables for the PR-GR difference x-section, and plot it
                      tvlct, xsect_struct.redct, xsect_struct.grnct, xsect_struct.bluct
                      TV, xsect_struct.DIFF_XSECT
                   ENDIF ELSE print, "NOTE: No cross section displayed -- no S-to-Ku adjustments applied."
                END
         250B : BEGIN
                   print, "Stepping through cross sections of each PR scan in matchup dataset"
                   IF N_ELEMENTS(pause) NE 1 THEN BEGIN
                      print, "Setting wait time between scans to 1 second."
                      pause = 1.0
                   ENDIF ELSE BEGIN
                      IF pause LT 0.1 OR pause GT 10.0 THEN BEGIN
                         print, "Pause value must be between 0.1 and 10.0 secs, value is: ", pause
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
                     ; destroy existing x-section windows 1st time through loop, may need resizing
                      IF ( havewin2 EQ 1 AND scanNumPR EQ scanoff ) THEN BEGIN
                         IF ( skip_2a25 NE 1 ) THEN WDELETE, 3
                         WDELETE, 5
                         WDELETE, 6
                         tvlct, rr, gg, bb
                      ENDIF

                      scanNum = scanNumpr - scanoff + 3L
                      IF KEYWORD_SET(verbose) THEN print, "Product-relative scan number: ", scanNumpr

                     ; idxcurscan should also be the sweep-by-sweep locations of all the
                     ; volume-matched footprints along the scan in the geo_match datasets,
                     ; which are what we need later to plot the geo-match cross sections
                      idxcurscan = WHERE( pr_scan EQ scanNum )
                      pr_rays_in_scan = pr_ray[idxcurscan]
                      raystart = MIN( pr_rays_in_scan, idxmin, MAX=rayend, $
                                      SUBSCRIPT_MAX=idxmax )
                      raystartpr = raystart-3L & rayendpr = rayend-3L
                      IF KEYWORD_SET(verbose) THEN print, "ray start, end: ", raystartpr, rayendpr
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
                      idxlinebeg = WHERE( myscanbuf EQ scanNum and myraybuf EQ raystart, countbeg )
                      idxlineend = WHERE( myscanbuf EQ scanNum and myraybuf EQ rayend, countend )
                      startxys = ARRAY_INDICES( myscanbuf, idxlinebeg )
                      endxys = ARRAY_INDICES( myscanbuf, idxlineend )
                      xbeg = MEAN( startxys[0,*] ) & xend = MEAN( endxys[0,*] )
                      ybeg = MEAN( startxys[1,*] ) & yend = MEAN( endxys[1,*] )
                      PLOTS, [xbeg, xend], [ybeg, yend], /DEVICE, COLOR=122, THICK=2
                      XYOUTS, xbeg+1, ybeg-1, raystartlbl, /DEVICE, COLOR=0, CHARSIZE=2, CHARTHICK=2  ; underplot in black
                      XYOUTS, xend+1, yend-1, rayendlbl, /DEVICE, COLOR=0, CHARSIZE=2, CHARTHICK=2
                      XYOUTS, xbeg, ybeg, raystartlbl, /DEVICE, COLOR=122, CHARSIZE=2, CHARTHICK=2    ; overplot in white
                      XYOUTS, xend, yend, rayendlbl, /DEVICE, COLOR=122, CHARSIZE=2, CHARTHICK=2
                      ybeg = ybeg+ysize & yend = yend+ysize
                      PLOTS, [xbeg, xend], [ybeg, yend], /DEVICE, COLOR=122, THICK=2
                      XYOUTS, xbeg+1, ybeg-1, raystartlbl, /DEVICE, COLOR=0, CHARSIZE=2, CHARTHICK=2
                      XYOUTS, xend+1, yend-1, rayendlbl, /DEVICE, COLOR=0, CHARSIZE=2, CHARTHICK=2
                      XYOUTS, xbeg, ybeg, raystartlbl, /DEVICE, COLOR=122, CHARSIZE=2, CHARTHICK=2
                      XYOUTS, xend, yend, rayendlbl, /DEVICE, COLOR=122, CHARSIZE=2, CHARTHICK=2

                      IF ( skip_2a25 NE 1 ) THEN BEGIN
                        ; generate the PR full-resolution vertical cross section plot
                         meanBBmsl = BBparms.meanBB + mysite.site_elev   ; adjust back to MSL for 2A25 plot
                         tvlct, rr, gg, bb
                         olddevice = !D.NAME

                         prxsect_struct = plot_pr_xsection_zbuf( scanNumpr, raystartpr, rayendpr, $
                                              dbz_2a25, meanBBmsl, DBZSCALE2A25, rangeBinNums, $
                                              TITLE=caseTitle25, BBBYRAY=BBbyRay, BBWIDTH=bbwidth, $
                                              STARTEND2SHOW=startend2show, LABEL_BY_RAYNUM=label_by_raynum )
                         title = "PR 2A-25 Reflectivity, 250m gates"
                         SET_PLOT, olddevice
                         IF scanNumPR EQ scanoff THEN $
                            WINDOW, 3, xsize=prxsect_struct.xs_pr2, ysize=prxsect_struct.ys_pr2, $
                                    ypos=50, TITLE = title $
                         ELSE WSET, 3
                         tvlct, prxsect_struct.redct, prxsect_struct.grnct, prxsect_struct.bluct
                         TV, prxsect_struct.PR2_XSECT
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
                                        LABEL_BY_RAYNUM=label_by_raynum  )

                      title = "PR and GR Volume Match X-Sections"
                     ; After creation, we just load new contents to existing windows for each
                     ; cross section in the sequence.  This way the window doesn't "flash" as
                     ; each new cross section is displayed, and is the reason for the change to
                     ; plotting the geo-match x-sections to the z-buffer rather than directly
                     ; to the X-window.
                      SET_PLOT, olddevice
                      IF scanNumPR EQ scanoff THEN $
                         WINDOW, 5, xsize=xsect_struct.xs_prgr, ysize=xsect_struct.ys_prgr, $
                                 ypos=50, TITLE = title $
                      ELSE WSET, 5
                      TV, xsect_struct.PRGR_XSECT

                      title = "PR-GR Volume Match Differences"
                      IF scanNumPR EQ scanoff THEN $
                         WINDOW, 6, xsize=xsect_struct.xs_diff, ysize=xsect_struct.ys_diff, $
                                    TITLE = title $
                      ELSE WSET, 6
                      tvlct, xsect_struct.redct, xsect_struct.grnct, xsect_struct.bluct
                      TV, xsect_struct.DIFF_XSECT

                      havewin2 = 1  ; need to delete x-sect windows at end
                      WAIT, pause
;  IF scanNumPR EQ (scanoff+scanmax)/2 THEN WAIT,10   ;REMOVE FROM BASELINE FILE BEFORE CM COMMIT
                      WSET, 1
                   ENDFOR

                   print, ''
                   print, '---------------------------------------------------------------------'
                   print, ''
                   print, "Next actions:"
                   print, " - Left click in a PPI image for another cross-section location."
                   print, " - Left click on a +1 or -1 labeled white square to adjust the"
                   print, "   geo_match GR reflectivities by the indicated amount, and re-draw."
                   print, " - Left click on the K,S labeled white square to toggle the S-band to"
                   print, "   Ku-band adjustment to the geo-match GR reflectivities, and re-draw."
                   print, " - Left click on the white square 'AN' at the lower right to display a PPI"
                   print, "   animation loop of volume-match and full-resolution PR and GR data."
                   print, " - Left click on the white square 'SC' at the lower right to step through"
                   print, "   an animation sequence of cross sections for each PR scan in the dataset."
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
   IF ( skip_2a25 NE 1 ) THEN BEGIN
      WDELETE, 3
      WDELETE, 7
   ENDIF
   WDELETE, 5
   WDELETE, 6
ENDIF

errorExit:
end

;===============================================================================

; MODULE #1

pro pr_dpr_and_geo_match_x_sections, ELEV2SHOW=elev2show, SITE=sitefilter, $
                                 NO_PROMPT=no_prompt, NCPATH=ncpath,   $
                                 PRPATH=prpath, UFPATH=ufpath, USE_DB=use_db, $
                                 SKIP_2A25=skip_2a25, PCT_ABV_THRESH=pctAbvThresh, $
                                 BBBYRAY=BBbyRay, PLOTBBSEP=plotBBsep, $
                                 BBWIDTH=bbwidth, HIDE_RNTYPE=hide_rntype, $
                                 CREF=cref, PAUSE=pause, ZOOMH=zoomh, $
                                 LABEL_BY_RAYNUM=label_by_raynum, VERBOSE=verbose

; "Include" file for matchup file prefixes:
@environs.inc

print
print, "###############################################"
print, "#  PR_AND_GEO_MATCH_X_SECTIONS: Version 2.0   #"
print, "#  NASA/GSFC/GPM Ground Validation, Aug. 2012 #"
print, "###############################################"
print

IF ( N_ELEMENTS(ncpath) NE 1 ) THEN BEGIN
   print, "Defaulting to /data/gpmgv/netcdf/geo_match for netCDF file path."
   print, ""
   pathgeo = '/data/gpmgv/netcdf/geo_match'
ENDIF ELSE pathgeo = ncpath

IF ( N_ELEMENTS(sitefilter) NE 1 ) THEN BEGIN
   print, "Defaulting to * for file pattern."
   print, ""
   ncfilepatt = 'GRtoPR*.nc*'
ENDIF ELSE BEGIN
   IF ( STRPOS(sitefilter, GEO_MATCH_PRE) NE 0 ) THEN $
      ncfilepatt = 'GRtoPR*'+sitefilter+'*' $
   ELSE ncfilepatt = sitefilter+'*'
ENDELSE

; Set use_db flag, default is to not use a Postgresql database query to obtain
; the PR 2A25 product filename matching the geo-match netCDF file for each case.
use_db = KEYWORD_SET( use_db )

; Set the skip_2a25 flag.  Default (ON) is to plot only geo-match cross section
; data from the netCDF files. If set to 0 (OFF), then look for original PR
; 2A-25 product file and plot cross section of full-res PR data. 
IF N_ELEMENTS( skip_2a25 ) EQ 0 THEN skip_2a25 = 1 $
ELSE skip_2a25 = KEYWORD_SET( skip_2a25 )

; Set the flag to control plotting of the ray-by-ray Bright Band heights in the
; PR 2A-25 full-resolution cross sections
BBbyRay=KEYWORD_SET( BBbyRay )

; Decide which PR and GR points to include, based on percent of expected points
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
   IF ( skip_2a25 NE 1 ) THEN BEGIN
      print, "Using default for PR product file path."
      IF ( use_db NE 1 ) THEN $
         print, "PR 2A-25 files may not be found if this location is incorrect."
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
   print, "Defaulting to 2 for ZOOMH parameter, Full Zoom-To-Fit of displayed PR rays."
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
                     "Full Zoom-To-Fit of displayed PR rays."
              print, ''
              zoomh = 2
            END
   ENDSWITCH
ENDELSE

; set the flag for labeling the endpoints of the cross section line/plots
label_by_raynum = keyword_set(label_by_raynum)

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
         gen_pr_and_geo_match_x_sections, ncfilepr, use_db, skip_2a25, $
                        ELEV2SHOW=elev2show, PCT_ABV_THRESH=pctAbvThresh, $
                        PR_ROOT_PATH=pathpr, UFPATH=pathgv, BBBYRAY=BBbyRay, $
                        PLOTBBSEP=plotBBsep, BBWIDTH=bbwidth, CREF=cref, $
                        HIDE_RNTYPE=hide_rntype, PAUSE=pause, ZOOMH=zoomh, $
                        LABEL_BY_RAYNUM=label_by_raynum, VERBOSE=verbose
      endfor
   endelse
ENDIF ELSE BEGIN
   print, ''
   print, 'Select a GRtoPR* netCDF file from the file selector.'
   ncfilepr = dialog_pickfile(path=pathgeo, filter = ncfilepatt, Title='Select a GRtoPR* netCDF file:')
   while ncfilepr ne '' do begin
      gen_pr_and_geo_match_x_sections, ncfilepr, use_db, skip_2a25, $
                        ELEV2SHOW=elev2show, PCT_ABV_THRESH=pctAbvThresh, $
                        PR_ROOT_PATH=pathpr, UFPATH=pathgv, BBBYRAY=BBbyRay, $
                        PLOTBBSEP=plotBBsep, BBWIDTH=bbwidth, CREF=cref, $
                        HIDE_RNTYPE=hide_rntype, PAUSE=pause, ZOOMH=zoomh, $
                        LABEL_BY_RAYNUM=label_by_raynum, VERBOSE=verbose
      ncfilepr = dialog_pickfile(path=pathgeo, filter = ncfilepatt)
   endwhile
ENDELSE

print, "" & print, "Done!"
END
