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
; PARAMETERS  (alphabetically listed)
; ----------
; alt_bb_hgt   - Manually-specified Bright Band Height (km) to be used if the
;                bright band height cannot be determined from the DPR data.
;
; BBbyRay      - Binary parameter.  If set, then plot individual bright band
;                height lines for each ray in the optional full-resolution PR
;                cross section plots, using each ray's BB height as
;                specified in the 2Axxx BBheight variable.
;
; bbwidth      - Height (km) above/below the mean bright band height within
;                which a sample touching (above) [below] this layer is
;                considered to be within (above) [below] the BB.  If not
;                specified, takes on the default value (0.750) defined in
;                fprep_dpr[gmi]_geo_match_profiles().
;
; cappi_anim - (Optional) binary parameter, if set to ON, then plot reflectivity
;              data on CAPPI (constant altitude PPI) surfaces rather than on the
;              conical sweep (PPI) surfaces in the optional PPI/CAPPI animation
;              window.  CAPPI height levels are hard-coded in the internal 
;              procedure, gen_dpr_and_geo_match_x_sections().  Default (OFF) is
;              to plot data on the native PPI surfaces.
;
; cref         - (Optional) binary parameter, if set to ON, then plot PPIs of
;                Composite Reflectivity (highest reflectivity in the vertical
;                column) rather than reflectivity at the fixed sweep elevation
;                'elev2show' within the cross-section selector window.
;
; declutter    - (Optional) binary parameter, if set to ON, then read and use
;                the clutterStatus variable to filter out clutter-flagged
;                volume match samples, regardless of pctAbvThresh status.
;
; DPR_Z_ADJUST   - Optional parameter.  Bias offset to be applied (added to) the
;                  DPR reflectivity values to account for the calibration offset
;                  between the DPR and ground radars in a global sense (same for
;                  all GR sites).  Positive (negative) value raises (lowers) the
;                  non-missing DPR reflectivity values.
;
; elev2show    - sweep number of PPIs to display, starting from 1 as the
;                lowest elevation angle in the volume.  Defaults to approximately
;                1/3 the way up the list of sweeps if unspecified
;
; flatpath     - Subdirectory name to use in place of the directory subtree
;                normally computed from the 2B-DPRGMI file name by the
;                parse_2a_filename function.
;
; gif_path     - Optional file directory specification to which an animated GIF
;                of the automated cross section sequence will be written if an
;                automated scan sequence is initiated.  If specified, then no
;                prompts are shown to the user in the automated sequence and the
;                sequence runs across the full matchup area in a rapid fashion,
;                ignoring the value of the "pause" parameter.
;
; GR_Z_ADJUST    - Optional parameter.  Pathname to a "|"-delimited text file
;                  containing the bias offset to be applied (added to) each
;                  ground radar site's reflectivity to correct the calibration
;                  offset between the DPR and ground radars in a site-specific
;                  sense.  Each line of the text file lists one site identifier
;                  and its bias offset value separated by the delimiter, e.g.:
;
;                  KMLB|2.89
;
;                  If no matching site entry is found in the file for a radar,
;                  then its reflectivity is not changed from the value in the
;                  matchup netCDF file.  The bias adjustment is applied AFTER
;                  the frequency adjustment if the S2KU parameter is set.
;
; hide_rntype  - (Optional) binary parameter, indicates whether to plot colored
;                bars along the top of the PR and GR cross-sections indicating
;                the PR and GR rain types identified for the given ray.
;
; KuKa_cmb     - designates which DPR instrument's data to analyze for the
;                DPRGMI matchup type.  Allowable values are 'Ku' and 'Ka'.  If
;                swath_cmb is 'NS' then KuKa_cmb must be 'Ku'.  If unspecified
;                or if in conflict with swath_cmb then the value will be
;                assigned to 'Ku' by default.
;
; label_by_raynum - parameter to explicitly control the type of label plotted
;                   at the endpoints of the cross section. If unset, uses the
;                   default legacy behavior to plot 'A' at the left/lowest ray
;                   to be plotted, and 'B' at the other right/highest ray.
;                   If set, then plots the actual ray numbers at the either end
;                   on the PPI location selector and the cross sections.
;
; matchup_type - Type of matchup data to be analyzed, either 'DPR' (GRtoDPR
;                matchup netCDF files) or 'DPRGMI' (GRtoDPRGMI matchup netCDF
;                files).  Also accepts 'CMB' as an alias for 'DPRGMI'.  Defaults
;                to 'DPR' if not specified.
;
; ncpath       - local directory path to the geo_match netCDF files' location.
;                Defaults to /data/netcdf/geo_match
;
; no_prompt    - method by which the next file in the set of files defined by
;                ncpath and sitefilter is selected. Binary parameter. If unset,
;                defaults to DialogPickfile (pop-up file selector)
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
; pause        - parameter to specify dwell time (fractional seconds) between
;                steps when automatically displaying a sequence of cross
;                sections for all scans in the matchup set. Default=1 sec.
;                Also defines the dwell time between frames in the animated GIF
;                when the animation sequence is written to a GIF file (see
;                gif_path parameter)
;
; plotBBsep    - (Optional) binary parameter, indicates whether to plot a
;                delimiter between within-BB volumes and adjacent above and
;                below-BB volumes in DPR and GR volume-match x-sections.
;
; prpath       - local directory path to the original DPR product files root
;                (in-common) directory.  Defaults to /data/prsubsets
;
; recall_ncpath - Binary parameter.  If set, assigns the last file path used to
;                 select a file in dialog_pickfile() to a user-defined system
;                 variable that stays in effect for the IDL session.  Also, if
;                 set and if the user variable exists from a previous selection,
;                 then the user variable will override the NCPATH parameter
;                 value on program startup.
;
; rhi_mode     - Binary parameter.  If set, then draw the cross sections along a
;                line anchored at one end at the ground radar location through a
;                point selected by the cursor, and extending to the edge of the
;                data coverage (max range or edge of the DPR swath).
;
; ray_mode     - Binary parameter.  If set, then draw the cross sections along a
;                line of constant DPR ray number (scan angle) rather than along
;                a line of constant scan number.
;
; show_orig    - Binary parameter.  If unset, then the full-vertical-resolution
;                cross sections from the original DPR data will NOT be plotted.
;                This means the program can be run using only the geo_match
;                netCDF data files.
;
; sitefilter   - file pattern which acts as the filter limiting the set of input
;                files shown in the file selector, or over which the program
;                will iterate. Mode of selecting the (next) file depends on the
;                no_prompt parameter. Default=*
;
; swath_cmb    - designates which swath (scan type) to analyze for the DPRGMI
;                matchup type.  Allowable values are 'MS' and 'NS' (default).
;
; ufpath       - local directory path to the original GR radar UF file root
;                (in-common) directory.  Defaults to
;                /data/gpmgv/gv_radar/finalQC_in
;
; verbose      - Binary parameter.  If set, then print position coordinates for
;                user-selected x-sect locations on the PPIs, in terms of window
;                coordinates and computed DPR data array scan,ray coordinates.
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
; 03/31/15  Morris/GPM GV/SAIC
; - Modified to output a merged PPI/location and geo-match cross section plot in
;   the same window when automatically stepping through a sequence of DPR scans.
; - Added GIF_PATH keyword parameter and logic to implement optional output of
;   an animated GIF of the merged PPI and geo-match cross section plots when
;   automatically stepping through the scans.
; - Defined this as Version 2.0 of the procedure.
; 04/01/15  Morris/GPM GV/SAIC
; - Fixed bug where idx2adj variable was not redefined for subset of RHI
;   footprints such that GR Z offsets and S-to-Ku adjustments were not made to
;   RHI samples.
; - Replaced all instances of skip_orig variable with show_orig, do not need two
;   variables with opposite meanings in one piece of code.
; 07/01/15 Morris, GPM GV, SAIC
; - Assembled data structure to pass to modified loop_pr_gv_gvpolar_ppis()
;   function so that the latter does not have to open and read the matchup
;   netCDF file again to get data to plot.
; 07/16/15 Morris, GPM GV, SAIC
; - Added DECLUTTER keyword option to filter out samples identified as ground
;   clutter affected.
; 08/19/15 Morris, GPM GV, SAIC
; - Fixed two bugs where IF check was done on undefined variable: verbose.
; 12/07/15 Morris, GPM GV, SAIC
; - Changed handling of path to original DPR files such that PR_ROOT_PATH
;   parameter is not ignored and can override hard-coded GPM_DATA_ROOT from the
;   environs.inc include file when it is specified.
; - Modified RHI mode to plot the RHI from the GR location to the cursor point,
;   regardless of intervening no-data points or any good-data points beyond the
;   selected point.  Fixes situation of cross section being truncated along the
;   selected radial.
; 01/15/16 Morris, GPM GV, SAIC
; - Reading ELLIPSOID_BIN_xxx fixed values from Include file and using it to
;   override the values in the binRealSurface array read from the 2A-DPR/Ka/Ku
;   file, since we need a bin value that is relative to the 0.0 MSL level.
; 02/22/16 Morris, GPM GV, SAIC
; - Added the capability to loop over the radial angles in RHI mode.  Moved
;   logic for computation of along-radial footprints to a separate function,
;   rhi_pr_indices(), to facilitate the looping without code duplication.
; 03/07/16 Morris, GPM GV, SAIC
; - Moved logic for computation of RHI ending footprints to a separate function
;   in the file rhi_endpoints.pro.
; - Updated prolog of the primary function gen_dpr_and_geo_match_x_sections()
;   to describe all hot corner features.
; 04/12/16 Morris, GPM GV, SAIC
; - Added the capability to create cross sections along the orbit track at a
;   user-selected constant ray number, rather than the default across-track at
;   a constant scan number.  Automatic scan is still restricted to either DPR
;   scans (cross-track plots) or RHI radial angles.
; 04/15/16 Morris, GPM GV, SAIC
; - Added the capability to auto-scan by DPR ray angle (ray number).
; 04/18/16 Morris, GPM GV, SAIC
; - Fixed bug in auto-scan in RHI_MODE when going directly to scanning mode. 
; 05/03/16 Morris, GPM GV, SAIC
; - Added logic to determine whether GR is inside or outside of DPR swath and
;   pass a new parameter to rhi_endpoints indicating this.
; 05/09/16 Morris, GPM GV, SAIC
; - Added full-resolution DPR data cross sections to the merged PPI/location and
;   geo-match cross section plot window for the step-through mode when SHOW_ORIG
;   parameter is set.
; - Now using Z-buffer instead of window/pixmap to create frames of the animated
;   GIF images to greatly speed up processing over remote connections.
; - Blanking out top and botm array elements where samples are below threshold
;   so that detection of empty frames for GIF image processing is more reliably
;   flagged in plot_geo_match_xsections_zbuf().
; - Moved call to get_gr_geo_match_rain_type() up in code sequence to before
;   where any blanking of top and botm array values occurs.
; - Added checks on existence of 2A[DPR|Ka|Ku] file in specified path before
;   trying to read it.  Report error and disable full-resolution plots if file
;   is not found or not readable by user.
; - Added DPR scan angle label to GR PPI panel if in RAY_MODE.
; - Fixed 3-scan offset between cursor and DPR data in manual cross section
;   selection of a DPR scan line.  Ouch.
; - Added location labeling to PPI images indicating the fixed ray number, 
;   fixed scan number, or fixed radial angle of the data in the cross section.
; 05/25/16 Morris, GPM GV, SAIC
; - Merged dprgmi_and_geo_match_x_sections.pro data preprocessing capabilities
;   into dpr_and_geo_match_x_sections.pro so that only one routine needs to be
;   maintained.  Added MATCHUP_TYPE parameter to specify matchup data type to
;   use, and SWATH_CMB and KUKA_CMB parameters to specify data subtype to
;   analyze for DPRGMI matchups.
; - Removed USE_DB parameter, never implemented this capability.
; - Added CAPPI_ANIM parameter to select newly-developed CAPPI display mode in
;   loop_pr_gv_gvpolar_ppis() function.
; 06/21/16 Morris, GPM GV, SAIC
; - Added default definition of bbwidth value if not provided as a parameter.
; - Added BBWIDTH=bbwidth specification to fprep_dpr[gmi]_geo_match_profiles()
;   calling parameters so that it is used consistently everywhere it applies.
; 09/28/16 Morris, GPM GV, SAIC
; - Added FLATPATH=flatpath keyword/value pair to override parsing of the 2B
;   file basename to get version/subset/yyyy/mm/dd subdirectories, and instead
;   just use flatpath value in place of these subdirectory components. 
; 11/22/16 Morris, GPM GV, SAIC
; - Added DPR_Z_ADJUST=dpr_z_adjust and GR_Z_ADJUST=gr_z_adjust keyword/value
;   pairs to support DPR and site-specific GR bias adjustments.
; 9/28/17 Morris, GPM GV, SAIC
; - Added test to prevent failure in case of an empty string value for the
;   GR_Z_ADJUST parameter.
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;===============================================================================

; MODULE #6

; extract the VN baseline path components "version/subset/year/month/day" from
; a 2A GPM filename, e.g., compose the path "V01D/CONUS/2014/04/20" from
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
;
; MODULE #2

pro gen_dpr_and_geo_match_x_sections, ncfilepr, pr_or_dpr, show_orig_in, $
                  ELEV2SHOW=elev2show, PCT_ABV_THRESH=pctAbvThresh, $
                  DPR_Z_ADJUST=dpr_z_adjust, GR_Z_ADJUST=gr_z_adjust, $
                  PR_ROOT_PATH=pr_root_path, UFPATH=ufpath, BBBYRAY=BBbyRay, $
                  PLOTBBSEP=plotBBsep, BBWIDTH=bbwidth, ALT_BB_HGT=alt_bb_hgt, $
                  CREF=cref, RHI_MODE=rhi_mode, RAY_MODE=ray_mode, $
                  HIDE_RNTYPE=hide_rntype, PAUSE=pause, ZOOMH=zoomh, $
                  LABEL_BY_RAYNUM=label_by_raynum, CAPPI_ANIM=cappi_anim, $
                  GIF_PATH=gif_path, DECLUTTER=declutter, VERBOSE=verbose, $
                  SWATH=swath_in, KUKA=KuKa_in, FLATPATH=flatpath

;
; DESCRIPTION
; -----------
; Called from dpr_and_geo_match_x_sections procedure (included in this file).
; Reads DPR and GR reflectivity and spatial fields from a selected geo_match
; netCDF file, and builds a PPI of the data for a given elevation sweep.  Then
; allows a user to select a point on the image for which vertical cross
; sections along the DPR scan line through the selected point will be plotted 
; from volume-matched DPR and GR data, and if show_orig_in is 1, also plots
; cross sections of full-resolution DPR data.  If the keyword RAY_MODE is set,
; then the cross section will be along a line of constant DPR ray number of the
; ray at the selected point (constant scan angle). If the keyword RHI_MODE is
; set, then the cross section will be drawn along a radial line from the ground
; radar location to the selected point rather than along a DPR scan line or ray
; (overrides RAY_MODE).
;
; Plots three labeled "hot corners" in the upper right of the GR PPI image.  When
; the user clicks in one of the hot corners labeled '-1' or '+1' and a cross
; section is already on the display, the GR geo-match reflectivity data (dBZ) is
; incremented or decremented by the labeled amount, and the geo-match cross section
; and difference cross section are redrawn with the reflectivity offset applied
; to the GR data.  This offset remains in place as long as the current case is
; being displayed, and resets to zero when a new case is selected.  If the user
; clicks on the hot corner labeled 'K,S' then the S-band to Ku-band frequency
; adjustment is altermnately applied to, or removed from, the GR geo-match
; reflectivity data in the cross section and the DPR-GR difference cross section.
;
; Also plots two 'hot corners' in the lower left corner of the GR PPI image.  When
; the user clicks in the 'AN' hot corner, an animation sequence of volume-matched
; DPR and GR data and full-resolution GR data from the original radar UF file
; is generated, and permits the user to assess the quality of the geo-alignment
; between the DPR and GR data.  When the user clicks on the 'SC' hot corner, a new
; combination PPI and cross section window will be displayed and will allow the
; user to automatically or manually step through a sequence of cross sections for
; each DPR scan or RHI angle in the matchup data.  If a directory path is
; specified for GIF_PATH, then the program will progress automatically and rapidly
; through the sequence of cross sections and write each image to a frame of an
; animated GIF file whose name is based on the name of the matchup netCDF file.
;

;COMMON sample, start_sample, sample_range, num_range, RAYSPERSCAN

; "Include" file for DPR-product-specific parameters (i.e., RAYSPERSCAN):
@dpr_params.inc
; "Include" file for names, default paths, etc.:
@environs.inc
; "Include file for netCDF-read structs
@geo_match_nc_structs.inc

!EXCEPT = 0   ; print errors when/where they occur (LINFIT reports problems as-used)

declutter=KEYWORD_SET(declutter_in)
IF (pr_or_dpr NE 'DPR') THEN declutter=0     ; override unless processing DPR

; set this module's show_orig value to the passed-in value, as we may have reset
; it if the last 2Axxx file couldn't be found
show_orig = show_orig_in

; copied following block from geo_match_3d_rr_or_z_comparisons.pro, in case needed
bname = file_basename( ncfilepr )
pctString = STRTRIM(STRING(FIX(pctabvthresh)),2)
parsed = STRSPLIT( bname, '.', /extract )
site = parsed[1]
yymmdd = parsed[2]
orbit = parsed[3]
version = parsed[4]
CASE pr_or_dpr OF
     'DPR' : BEGIN
               swath=parsed[6]
               KuKa=parsed[5]
               instrument='_2A'+KuKa    ; label used in SAVE file names
             END
;      'PR' : BEGIN
;               swath='NS'
;               instrument='_'
;               KuKa='Ku'
;              ; leave this here for now, expect PR V08x version labels soon, though
;               CASE version OF
;                    '6' : version = 'V6'
;                    '7' : version = 'V7'
;                   ELSE : print, "Using PR version = ", version
;               ENDCASE
;             END
  'DPRGMI' : BEGIN
               swath=swath_in
               KuKa=KuKa_in
               instrument='_'+KuKa
             END
ENDCASE

; configure bias adjustment for GR and/or DPR

adjust_grz = 0  ; set flag to NOT try to adjust GR Z biases
IF N_ELEMENTS( gr_z_adjust ) EQ 1 THEN BEGIN
   IF gr_z_adjust NE '' THEN BEGIN
      IF FILE_TEST( gr_z_adjust ) THEN BEGIN
        ; read the site bias file and store site IDs and biases in a HASH variable
         siteBiasHash = site_bias_hash_from_file( gr_z_adjust )
         IF TYPENAME(siteBiasHash) EQ 'HASH' THEN BEGIN
            adjust_grz = 1  ; set flag to try to adjust GR Z biases
         ENDIF ELSE BEGIN
            print, "Problems with GR_Z_ADJUST file: ", gr_z_adjust
            entry = ''
            WHILE STRUPCASE(entry) NE 'C' AND STRUPCASE(entry) NE 'Q' DO BEGIN
               read, entry, PROMPT="Enter C to continue without GR " $
                                 + "site bias adjustment or Q to exit here: "
               CASE STRUPCASE(entry) OF
                   'C' : BEGIN
                           adjust_grz = 0  ; set flag to NOT try to adjust GR Z biases
                           break
                         END
                   'Q' : GOTO, errorExit
                  ELSE : print, "Invalid response, enter C or Q."
               ENDCASE
            ENDWHILE  
         ENDELSE       
      ENDIF ELSE message, "File '"+gr_z_adjust+"' for GR_Z_ADJUST not found."
   ENDIF
ENDIF

adjust_dprz = 0  ; set flag to NOT try to adjust DPR Z biases
IF N_ELEMENTS( dpr_z_adjust ) EQ 1 THEN BEGIN
   IF is_a_number( dpr_z_adjust ) THEN BEGIN
      dpr_z_adjust = FLOAT( dpr_z_adjust )  ; in case of STRING entry
      IF dpr_z_adjust GE -3.0 AND dpr_z_adjust LE 3.0 THEN BEGIN
         adjust_dprz = 1  ; set flag to try to adjust GR Z biases
       ENDIF ELSE BEGIN
         message, "DPR_Z_ADJUST value must be between -3.0 and 3.0 (dBZ)"
      ENDELSE
   ENDIF ELSE message, "DPR_Z_ADJUST value is not a number."
ENDIF


; set up pointers for each field to be returned from fprep_dpr_geo_match_profiles()
ptr_geometa=ptr_new(/allocate_heap)
ptr_sweepmeta=ptr_new(/allocate_heap)
ptr_sitemeta=ptr_new(/allocate_heap)
ptr_filesmeta=ptr_new(/allocate_heap)
ptr_fieldflags=ptr_new(/allocate_heap)
ptr_gvz=ptr_new(/allocate_heap)
ptr_zcor=ptr_new(/allocate_heap)
ptr_zraw=ptr_new(/allocate_heap)
ptr_top=ptr_new(/allocate_heap)
ptr_botm=ptr_new(/allocate_heap)
ptr_rnType=ptr_new(/allocate_heap)
ptr_pr_index=ptr_new(/allocate_heap)
ptr_xCorner=ptr_new(/allocate_heap)
ptr_yCorner=ptr_new(/allocate_heap)
ptr_bbProx=ptr_new(/allocate_heap)
ptr_pctgoodpr=ptr_new(/allocate_heap)
ptr_pctgoodgv=ptr_new(/allocate_heap)
IF KEYWORD_SET(declutter) THEN ptr_clutterStatus=ptr_new(/allocate_heap)

; define default value for bbwidth if not provided
IF N_ELEMENTS(bbwidth) NE 1 THEN bbwidth = 0.75   ; km

; structure to hold bright band variables
BBparms = {meanBB : -99.99, BB_HgtLo : -99, BB_HgtHi : -99}

; Define the list of fixed-height levels for the vertical profile statistics
heights = [1.5,3.0,4.5,6.0,7.5,9.0,10.5,12.0,13.5,15.0,16.5,18.0,19.5]

; define CAPPI heights array if plotting CAPPIs in animation loop
IF KEYWORD_SET(cappi_anim) THEN cappi_heights = heights

print, 'pctAbvThresh = ', pctAbvThresh

; read the geometry-match variables and arrays from the file, and preprocess
; them to remove the 'bogus' PR ray positions.  Return a pointer to each
; variable read or computed.

CASE pr_or_dpr OF
;  'PR' : BEGIN
;    PRINT, "READING MATCHUP FILE TYPE: ", pr_or_dpr
;    status = fprep_geo_match_profiles( ncfilepr, heights, $
;    PCT_ABV_THRESH=pctAbvThresh, S2KU=s2ku, PTRfieldflags=ptr_fieldflags, $
;    PTRgeometa=ptr_geometa, PTRsweepmeta=ptr_sweepmeta, PTRsitemeta=ptr_sitemeta, $
;    PTRGVZMEAN=ptr_gvz, PTRzcor=ptr_zcor, PTRzraw=ptr_zraw, PTRrain3d=ptr_rain3, $
;    PTRGVRRMEAN=ptr_gvrr, PTRGVMODEHID=ptr_BestHID, PTRGVDZEROMEAN=ptr_GR_DP_Dzero, $
;    PTRGVZDRMEAN=ptr_GR_DP_Zdr, PTRGVKDPMEAN=ptr_GR_DP_Kdp, PTRGVRHOHVMEAN=ptr_GR_DP_RHOhv, $
;    PTRtop=ptr_top, PTRbotm=ptr_botm, PTRlat=ptr_lat, PTRlon=ptr_lon, PTRpia=ptr_pia, $
;    PTRsfcrainpr=ptr_nearSurfRain, PTRsfcraincomb=ptr_nearSurfRain_Comb, $
;    PTRrainflag_int=ptr_rnFlag, PTRraintype_int=ptr_rnType, $
;    PTRxCorners=ptr_xCorner, PTRyCorners=ptr_yCorner, PTRbbProx=ptr_bbProx, $
;    PTRhgtcat=ptr_hgtcat, PTRdist=ptr_dist, PTRpridx_long=ptr_pr_index, $
;    PTRpctgoodpr=ptr_pctgoodpr, PTRpctgoodgv=ptr_pctgoodgv, $
;    PTRpctgoodrain=ptr_pctgoodrain, PTRpctgoodrrgv=ptr_pctgoodrrgv, BBPARMS=BBparms, $
;    ALT_BB_HGT=alt_bb_hgt )
;   END
  'DPR' : BEGIN
    PRINT, "READING MATCHUP FILE TYPE: ", pr_or_dpr
    status = fprep_dpr_geo_match_profiles( ncfilepr, heights, $
    PCT_ABV_THRESH=pctAbvThresh, S2KU=s2ku, PTRfieldflags=ptr_fieldflags, $
    PTRgeometa=ptr_geometa, PTRsweepmeta=ptr_sweepmeta, $
    PTRsitemeta=ptr_sitemeta, PTRfilesmeta=ptr_filesmeta, $
    PTRGVZMEAN=ptr_gvz, PTRzcor=ptr_zcor, PTRzraw=ptr_zraw, PTRrain3d=ptr_rain3, $
    PTRGVRCMEAN=ptr_gvrc, PTRGVRPMEAN=ptr_gvrp, PTRGVRRMEAN=ptr_gvrr, $
    PTRGVMODEHID=ptr_BestHID, PTRGVDZEROMEAN=ptr_GR_DP_Dzero, $
    PTRGVZDRMEAN=ptr_GR_DP_Zdr, PTRGVKDPMEAN=ptr_GR_DP_Kdp, PTRGVRHOHVMEAN=ptr_GR_DP_RHOhv, $
    PTRGVBLOCKAGE=ptr_GR_blockage, $
    PTRtop=ptr_top, PTRbotm=ptr_botm, PTRlat=ptr_lat, PTRlon=ptr_lon, PTRpia=ptr_pia, $
    PTRsfcrainpr=ptr_nearSurfRain, PTRsfcraincomb=ptr_nearSurfRain_Comb, $
    PTRrainflag_int=ptr_rnFlag, PTRraintype_int=ptr_rnType, $
    PTRxCorners=ptr_xCorner, PTRyCorners=ptr_yCorner, PTRbbProx=ptr_bbProx, $
    PTRhgtcat=ptr_hgtcat, PTRdist=ptr_dist, PTRpridx_long=ptr_pr_index, $
    PTRpctgoodpr=ptr_pctgoodpr, PTRpctgoodgv=ptr_pctgoodgv, $
    PTRpctgoodrain=ptr_pctgoodrain, PTRpctgoodrcgv=ptr_pctgoodrcgv, $
    PTRpctgoodrpgv=ptr_pctgoodrpgv, PTRpctgoodrrgv=ptr_pctgoodrrgv, $
    PTRclutterStatus=ptr_clutterStatus, BBWIDTH=bbwidth, BBPARMS=BBparms, $
    ALT_BB_HGT=alt_bb_hgt, FORCEBB=forcebb )
   END
  'DPRGMI' : BEGIN
    PRINT, "READING MATCHUP FILE TYPE: ", pr_or_dpr
    status = fprep_dprgmi_geo_match_profiles( ncfilepr, heights, $
    KUKA=KuKa, SCANTYPE=swath, PCT_ABV_THRESH=pctAbvThresh, S2KU=s2ku, $
    PTRfieldflags=ptr_fieldflags, PTRgeometa=ptr_geometa, $
    PTRsweepmeta=ptr_sweepmeta, PTRsitemeta=ptr_sitemeta, PTRfilesmeta=ptr_filesmeta, $
    PTRGVZMEAN=ptr_gvz, PTRzcor=ptr_zcor, PTRrain3d=ptr_rain3, $
    PTRGVRCMEAN=ptr_gvrc, PTRGVRPMEAN=ptr_gvrp, PTRGVRRMEAN=ptr_gvrr, $
    PTRGVMODEHID=ptr_BestHID, PTRGVDZEROMEAN=ptr_GR_DP_Dzero, $
    PTRGVZDRMEAN=ptr_GR_DP_Zdr, PTRGVKDPMEAN=ptr_GR_DP_Kdp, PTRGVRHOHVMEAN=ptr_GR_DP_RHOhv, $
    PTRtop=ptr_top, PTRbotm=ptr_botm, PTRlat=ptr_lat, PTRlon=ptr_lon, PTRpia=ptr_pia, $
    PTRsfcrainpr=ptr_nearSurfRain, PTRraintype_int=ptr_rnType, $
    PTRxCorners=ptr_xCorner, PTRyCorners=ptr_yCorner, PTRbbProx=ptr_bbProx, $
    PTRhgtcat=ptr_hgtcat, PTRdist=ptr_dist, PTRpridx_long=ptr_pr_index, $
    PTRpctgoodpr=ptr_pctgoodpr, PTRpctgoodgv=ptr_pctgoodgv, $
    PTRpctgoodrain=ptr_pctgoodrain, PTRpctgoodrcgv=ptr_pctgoodrcgv, $
    PTRpctgoodrpgv=ptr_pctgoodrpgv, PTRpctgoodrrgv=ptr_pctgoodrrgv, $
    BBWIDTH=bbwidth, BBPARMS=BBparms, ALT_BB_HGT=alt_bb_hgt )
   END
ENDCASE

IF (status EQ 1) THEN GOTO, errorExit

; create local data field arrays/structures needed here, and free pointers
; we no longer need in order to free the memory held by these pointer variables
; - don't free the pointers we are including in a data structure to pass to
;   loop_pr_gv_gvpolar_ppis()

  mygeometa=*ptr_geometa
    ptr_free,ptr_geometa
  mysite=*ptr_sitemeta
;    ptr_free,ptr_sitemeta
  mysweeps=*ptr_sweepmeta
;    ptr_free,ptr_sweepmeta
  myflags=*ptr_fieldflags
    ptr_free,ptr_fieldflags
  filesmeta=*ptr_filesmeta
    ptr_free,ptr_filesmeta
  gvz=*ptr_gvz
;    ptr_free,ptr_gvz
  zcor=*ptr_zcor
;  no zraw in DPRGMI matchups, make copy of zcor
  IF pr_or_dpr EQ 'DPR' THEN zraw=*ptr_zraw ELSE zraw=zcor

;-------------------------------------------------------------

  ; Optional bias/offset adjustment of GR Z and DPR Z:
   IF adjust_grz THEN BEGIN
      IF siteBiasHash.HasKey( site ) THEN BEGIN
        ; adjust GR Z values based on supplied bias file
         grbias = siteBiasHash[ site ]
         absbias = ABS( grbias )
         IF absbias GE 0.1 THEN BEGIN
            IF grbias LT 0.0 THEN BEGIN
              ; downward-adjust Zc values above ABS(grbias) separately from
              ; those below to avoid setting positive values to below 0.0
               idx_z2adj=WHERE(gvz GT absbias, count2adj)
               IF count2adj GT 0 THEN gvz[idx_z2adj] = gvz[idx_z2adj]+grbias
               idx_z2adj=WHERE(gvz GT 0.0 AND gvz LE absbias, count2adj)
               IF count2adj GT 0 THEN gvz[idx_z2adj] = 0.0
            ENDIF ELSE BEGIN
              ; upward-adjust GR Z values that are above 0.0 dBZ only
               idx_z2adj=WHERE(gvz GT 0.0, count2adj)
               IF count2adj GT 0 THEN gvz[idx_z2adj] = gvz[idx_z2adj]+grbias
            ENDELSE
           ; replace pointed-to values with adjusted values
            *ptr_gvz = gvz
         ENDIF ELSE print, "Ignoring negligible GR site Z bias value for "+site
      ENDIF ELSE print, "Site bias value not found for "+site+", leaving GR Z unchanged."
   ENDIF

   IF adjust_dprz THEN BEGIN
      absbias = ABS( dpr_z_adjust )
      IF absbias GE 0.1 THEN BEGIN
         IF dpr_z_adjust LT 0.0 THEN BEGIN
           ; downward-adjust Zc values above ABS(grbias) separately from
           ; those below to avoid setting positive values to below 0.0
            idx_z2adj=WHERE(zcor GT absbias, count2adj)
            IF count2adj GT 0 THEN zcor[idx_z2adj] = zcor[idx_z2adj]+dpr_z_adjust
            idx_z2adj=WHERE(zcor GT 0.0 AND zcor LE absbias, count2adj)
            IF count2adj GT 0 THEN zcor[idx_z2adj] = 0.0
           ; also adjust Zmeas field
            idx_z2adj=WHERE(zraw GT absbias, count2adj)
            IF count2adj GT 0 THEN zraw[idx_z2adj] = zraw[idx_z2adj]+dpr_z_adjust
            idx_z2adj=WHERE(zraw GT 0.0 AND zraw LE absbias, count2adj)
            IF count2adj GT 0 THEN zraw[idx_z2adj] = 0.0
         ENDIF ELSE BEGIN
           ; upward-adjust Zc values that are above 0.0 dBZ only
            idx_z2adj=WHERE(zcor GT 0.0, count2adj)
            IF count2adj GT 0 THEN zcor[idx_z2adj] = zcor[idx_z2adj]+dpr_z_adjust
           ; also adjust Zmeas field
            idx_z2adj=WHERE(zraw GT 0.0, count2adj)
            IF count2adj GT 0 THEN zraw[idx_z2adj] = zraw[idx_z2adj]+dpr_z_adjust
         ENDELSE
        ; replace pointed-to values with adjusted values, pointer gets passed
        ; to loop_pr_gv_gvpolar_ppis() in a structure
         *ptr_zcor = zcor
         IF pr_or_dpr EQ 'DPR' THEN *ptr_zraw=zraw
      ENDIF ELSE print, "Ignoring negligible DPR Z bias value."
   ENDIF

;-------------------------------------------------------------

  gvz_in = gvz     ; 2nd copy for plotting as PPI
  zcor_in = zcor   ; 2nd copy for plotting as PPI
;    ptr_free,ptr_zcor
  top=*ptr_top
  botm=*ptr_botm
  rntype=*ptr_rnType
  pr_index=*ptr_pr_index
  xcorner=*ptr_xCorner
  ycorner=*ptr_yCorner
  bbProx=*ptr_bbProx
  pctgoodpr=*ptr_pctgoodpr
  pctgoodgv=*ptr_pctgoodgv
;    ptr_free,ptr_top
;    ptr_free,ptr_botm
    ptr_free,ptr_rnType
;    ptr_free,ptr_pr_index
;    ptr_free,ptr_xCorner
;    ptr_free,ptr_yCorner
    ptr_free,ptr_bbProx
    ptr_free,ptr_pctgoodpr
    ptr_free,ptr_pctgoodgv
  IF KEYWORD_SET(declutter) THEN BEGIN
     clutterStatus=*ptr_clutterStatus
     ptr_free,ptr_clutterStatus
  ENDIF

CASE pr_or_dpr OF
     'DPR' : BEGIN
               nfp = mygeometa.num_footprints
               nframes = mygeometa.num_sweeps
               DPR_scantype = mygeometa.DPR_scantype
               CASE STRUPCASE(DPR_scantype) OF
                  'HS' : BEGIN
                            RAYSPERSCAN = RAYSPERSCAN_HS
                            GATE_SPACE = BIN_SPACE_HS
                            ELLIPSOID_BIN = ELLIPSOID_BIN_HS
                         END
                  'MS' : BEGIN
                            RAYSPERSCAN = RAYSPERSCAN_MS
                            GATE_SPACE = BIN_SPACE_NS_MS
                            ELLIPSOID_BIN = ELLIPSOID_BIN_NS_MS
                        END
                  'NS' : BEGIN
                            RAYSPERSCAN = RAYSPERSCAN_NS
                            GATE_SPACE = BIN_SPACE_NS_MS
                            ELLIPSOID_BIN = ELLIPSOID_BIN_NS_MS
                         END
                  ELSE : message, "Illegal scan type '"+DPR_scantype+"'"
               ENDCASE
             END
  'DPRGMI' : BEGIN
               nframes = mygeometa.num_sweeps
               DPR_scantype = swath
               CASE STRUPCASE(DPR_scantype) OF
                  'MS' : BEGIN
                            nfp = mygeometa.num_footprints_MS
                            RAYSPERSCAN = RAYSPERSCAN_MS
                            GATE_SPACE = BIN_SPACE_DPRGMI
                        END
                  'NS' : BEGIN
                            nfp = mygeometa.num_footprints_NS
                            RAYSPERSCAN = RAYSPERSCAN_NS
                            GATE_SPACE = BIN_SPACE_DPRGMI
                         END
                  ELSE : message, "Illegal scan type '"+DPR_scantype+"'"
               ENDCASE
             END
ENDCASE

; get the partial pathname to the original ground radar data file and test for
; its existence
; - first, see if we have the partial path or just a file basename

IF FILE_DIRNAME(filesmeta.file_1cuf) EQ '.' THEN BEGIN
  ; all we have is a basename, try to format and find the full pathname
   grFileMatch = get_uf_pathname(ncfilepr, mysweeps[0].atimeSweepStart, $
                                 ufpath, UFBASE=filesmeta.file_1cuf)
ENDIF ELSE BEGIN
  ; presumably we have all the parts of the pathname below the ufpath directory
   grFileMatch = ufpath + '/' + filesmeta.file_1cuf
ENDELSE

IF FILE_TEST( grFileMatch ) EQ 0 THEN BEGIN
   print, "Unable to find original GR UF file: ", grFileMatch
   grFileMatch = 'Not found'
ENDIF

;-------------------------------------------------

; put together a data structure to be passed to loop_pr_gv_gvpolar_ppis() so
; that we don't have to read the matchup file again in that function

dataStruct = { mysite : ptr_sitemeta, $
               mysweeps : ptr_sweepmeta, $
               nfp : nfp, $
               nswp : nframes, $
               timeNearestApproach : mygeometa.timeNearestApproach, $
               rangeThreshold : mygeometa.rangeThreshold, $
               gvz : ptr_gvz, $
               zcor : ptr_zcor, $
               top : ptr_top, $
               botm : ptr_botm, $
               xCorner : ptr_xCorner, $
               yCorner : ptr_yCorner, $
               pr_index : ptr_pr_index, $
               uf_file : grFileMatch }

;-------------------------------------------------

; compute a rain type from the GR vertical profiles here, before we do any
; "blanking" of top and botm array values for below-threshold samples
meanBBgr = -99.99
gvrtype = get_gr_geo_match_rain_type( pr_index, gvz_in, top, botm, SINGLESCAN=0, $
                                      VERBOSE=0, MEANBB=meanBBgr )
; if rain type "hiding" is on, set all samples to "Other" rain type
hide_rntype = KEYWORD_SET( hide_rntype )
IF hide_rntype THEN BEGIN
gvrtype[*,*] = 3
print, '' & print, "Hiding rain type for GR." & print, ''
ENDIF

;-------------------------------------------------

; PREPARE FIELDS NEEDED FOR PPI PLOTS AND GEO_MATCH CROSS SECTIONS:

; blank out reflectivity for samples not meeting 'percent complete' threshold

IF ( pctAbvThresh GT 0.0 ) THEN BEGIN
  ; clip to the 'good' points, where 'pctAbvThresh' fraction of bins in average
  ; were above threshold
   IF KEYWORD_SET(declutter) THEN $
     ; also clip to uncluttered samples
      idxgoodenuff = WHERE( pctgoodpr GE pctAbvThresh $
                       AND  pctgoodgv GE pctAbvThresh $
                       AND  clutterStatus LT 10, countgoodpct ) $
   ELSE idxgoodenuff = WHERE( pctgoodpr GE pctAbvThresh $
                         AND  pctgoodgv GE pctAbvThresh, countgoodpct )
   IF ( countgoodpct GT 0 ) THEN BEGIN
      ;idxgoodenuff = idxexpgt0[idxgoodpct]
      ;idx2plot=idxgoodenuff
      n2plot=countgoodpct
   ENDIF ELSE BEGIN
      IF KEYWORD_SET(declutter) THEN $
         print, "No complete volumes based on PctAbvThresh and/or clutter, quitting case." $
      ELSE print, "No complete volumes based on PctAbvThresh, quitting case."
      goto, errorExit
   ENDELSE
  ; blank out reflectivity and top/bottom heights for all samples not meeting
  ; completeness thresholds
   idx3d = pr_index      ; just for creation/sizing
   idx3d[*,*] = 0L       ; initialize all points to 0 (blank-out flag)
   idx3d[idxgoodenuff] = 2L  ; points to keep
   idx2blank = WHERE( idx3d EQ 0L, count2blank )
   IF ( count2blank GT 0 ) THEN BEGIN
     IF KEYWORD_SET(verbose) THEN $
        PRINT, count2blank, " samples rejected as below percent threshold ", $
                            "and/or clutter-affected."
     gvz[idx2blank] = 0.0
     zcor[idx2blank] = 0.0
     top[idx2blank] = 0.0
     botm[idx2blank] = 0.0
   ENDIF
ENDIF ELSE BEGIN
  ; blank out reflectivity for clutter samples, if indicated
   IF KEYWORD_SET(declutter) THEN BEGIN
      idxgoodenuff = WHERE( clutterStatus LT 10, countgoodpct )
      IF ( countgoodpct GT 0 ) THEN BEGIN
         n2plot=countgoodpct
      ENDIF ELSE BEGIN
         print, "No complete-volume uncluttered points, quitting case."
         goto, errorExit
      ENDELSE
     ; blank out reflectivity and top/bottom for all cluttered samples
      idx3d = pr_index      ; just for creation/sizing
      idx3d[*,*] = 0L       ; initialize all points to 0 (blank-out flag)
      idx3d[idxgoodenuff] = 2L  ; points to keep
      idx2blank = WHERE( idx3d EQ 0L, count2blank )
      IF ( count2blank GT 0 ) THEN BEGIN
        IF KEYWORD_SET(verbose) THEN $
           PRINT, count2blank, " samples rejected as clutter-affected."
        gvz[idx2blank] = 0.0
        zcor[idx2blank] = 0.0
        top[idx2blank] = 0.0
        botm[idx2blank] = 0.0
      ENDIF
   ENDIF
ENDELSE

; get the indices of all remaining 'valid' GR points, so that we can
; do the interactive calibration adjustment on these only
idx2adj = WHERE( gvz GT 0.0 )

; extract rain type for the first sweep to make the single-level array
; for PPI plots generated in plot_sweep_2_zbuf()
rnTypeIn = rnType[*,0]
; if rain type "hiding" is on, set all samples to "Other" rain type
IF hide_rntype THEN rnTypeIn[*,*] = 3

;-------------------------------------------------

; -- parse ncfile1 to get the component fields: site, orbit number, YYMMDD
dataPR = FILE_BASENAME(ncfilepr)
parsed=STRSPLIT( dataPR, '.', /extract )
frequency=parsed[5]        ; 'DPR', 'KA', or 'KU', from input GPM 2Axxx file
orbit = parsed[3]
DATESTAMP = parsed[2]      ; in YYMMDD format
ncsite = parsed[1]

; put the InstrumentID from the matchup filename or the
; KuKa parameter into its PPS designation
IF pr_or_dpr EQ 'DPR' THEN BEGIN
   frequency=parsed[5]     ; 'DPR', 'KA', or 'KU', from input GPM 2Axxx file
ENDIF ELSE BEGIN
   frequency=KuKa          ; 'KA', or 'KU', from input param.
   swathIDs = ['MS','MS','NS']
   instruments = ['Ku','Ka','Ku']
   ; indices for finding correct subarray in MS swath for 2BDPRGMI variables
   ; with the extra nKuKa dimension:
   idxKuKa = [0,1,0]
ENDELSE
CASE STRUPCASE(frequency) OF
    'KA' : freqName='Ka'
    'KU' : freqName='Ku'
   'DPR' : freqName='DPR'
    ELSE : freqName=''
ENDCASE

sourceLabel = freqName + "/" + STRUPCASE(DPR_scantype)

; examine file basename to find out whether we are looking at a true RHI matchup
; file or are just in RHI mode in the cross section definition
IF STRPOS(dataPR,'.RHI.') EQ -1 THEN is_rhi_data=0 ELSE is_rhi_data=1

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

; define a GIF file basename for this case
IF KEYWORD_SET(rhi_mode) THEN modeStr='_RadialStep' ELSE $
   IF KEYWORD_SET(ray_mode) THEN modeStr='_RayStep' ELSE modeStr='_ScanStep'
posdotnc = STRPOS(dataPR, '.nc', /REVERSE_SEARCH)
if posdotnc ne -1 $
   then gif_base = STRMID(datapr,0,posdotnc)+'.Xsec_Pct'+$
                   STRING(pctAbvThresh,FORMAT='(i0)')+modeStr+'.gif' $
   else message, "Can't find .nc substring in "+dataPR

; Identify the original DPR filename for this orbit/subset, if plotting
; full-resolution DPR data cross sections:

IF ( show_orig ) THEN BEGIN
;   startpath = '/data/gpmgv'
;   dprFileMatch = DIALOG_PICKFILE(PATH=startpath, $
;                                  FILTER='*GPM.'+freqName+'*'+orbit+'*', $
;                                  TITLE='Select a DPR/Ka/Ku file')

  ; find the matchup input filename with the expected non-missing pattern
  ; and, for now, set a default instrumentID and scan type
   nfoundDPR=0
   IF pr_or_dpr EQ 'DPR' THEN BEGIN
      ; put the file names in the filesmeta struct into a searchable array
      dprFileMatch=[filesmeta.FILE_2ADPR, filesmeta.FILE_2AKA, $
                    filesmeta.FILE_2AKU, filesmeta.FILE_2BCOMB ]
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

      IF ( origFileKaName EQ 'no_2AKA_file' AND $
           origFileKuName EQ 'no_2AKU_file' AND $
           origFileDPRName EQ 'no_2ADPR_file' ) THEN BEGIN
         show_orig=0
         PRINT, ""
         message, "ERROR finding a 2A-DPR, 2A-KA , or 2A-KU file name", /INFO
         PRINT, "Looked at: ", dprFileMatch
         GOTO, skipdprread
      ENDIF
   ENDIF ELSE BEGIN
      ; put the file name(s) in the filesmeta struct into a searchable array
      dprFileMatch=[ filesmeta.FILE_2BCOMB ]
      idxCMB = WHERE(STRMATCH(dprFileMatch,'2B*.GPM.DPRGMI.*') EQ 1, countCMB)
      if countCMB EQ 1 THEN BEGIN
         origFileCMBName = dprFileMatch[idxCMB]
         Instrument_ID='DPRGMI'
         nfoundDPR = countCMB
      endif ELSE origFileCMBName='no_2BCMB_file'

      IF ( origFileCMBName EQ 'no_2BCMB_file' ) THEN BEGIN
         show_orig=0
         PRINT, ""
         message, "ERROR finding a 2B-DPRGMI file name", /INFO
         PRINT, "Looked at: ", dprFileMatch
         GOTO, skipdprread
      ENDIF
   ENDELSE

   IF nfoundDPR NE 1 THEN BEGIN
      show_orig=0
      PRINT, ""
      message, "ERROR finding just one 2A-DPR/KA/KU or 2B-DPRGMI file name", /INFO
      GOTO, skipdprread
   ENDIF
 
; ***************************** Local configuration ****************************
   ; where provided, override file path default values from environs.inc:
    IF N_ELEMENTS(pr_root_path) EQ 1 THEN GPMDATA_ROOT = pr_root_path

; ***************************** Local configuration ****************************

  ; extract the needed path elements version, subset, year, month, and day from
  ; the 2A filename, e.g.,
  ; 2A-CS-CONUS.GPM.Ku.V5-20140401.20140420-S082058-E082715.000804.V01D.HDF5,
  ; and add the well-known (or local) paths to get the fully-qualified file names

   CASE Instrument_ID OF
      'DPR' : BEGIN
                 IF N_ELEMENTS(flatpath) EQ 1 THEN path_tail = flatpath $
                 ELSE path_tail = parse_2a_filename( origFileDPRName )
                 file_2adpr = GPMDATA_ROOT+DIR_2ADPR+"/"+path_tail+'/'+origFileDPRName
                 IF FILE_TEST(file_2adpr, /READ, /REGULAR) NE 1 THEN BEGIN
                    message, "Cannot find 2ADPR file "+file_2adpr, /INFO
                    print, "Disabling full-resolution DPR cross section panels."
                    print, ""
                    show_orig=0
                    GOTO, skipdprread
                 ENDIF ELSE print, "Reading DPR from ",file_2adpr
              END
       'Ku' : BEGIN
                 IF N_ELEMENTS(flatpath) EQ 1 THEN path_tail = flatpath $
                 ELSE path_tail = parse_2a_filename( origFileKuName )
                 file_2aku = GPMDATA_ROOT+DIR_2AKU+"/"+path_tail+"/"+origFileKuName
                 IF FILE_TEST(file_2aku, /READ, /REGULAR) NE 1 THEN BEGIN
                    message, "Cannot find 2AKu file "+file_2aku, /INFO
                    print, "Disabling full-resolution Ku-DPR cross section panels."
                    print, ""
                    show_orig=0
                    GOTO, skipdprread
                 ENDIF ELSE print, "Reading DPR from ",file_2aku
              END
       'Ka' : BEGIN
                 IF N_ELEMENTS(flatpath) EQ 1 THEN path_tail = flatpath $
                 ELSE path_tail = parse_2a_filename( origFileKaName )
                 file_2aka = GPMDATA_ROOT+DIR_2AKA+"/"+path_tail+"/"+origFileKaName
                 IF FILE_TEST(file_2aka, /READ, /REGULAR) NE 1 THEN BEGIN
                    message, "Cannot find 2AKa file "+file_2aka, /INFO
                    print, "Disabling full-resolution Ka-DPR cross section panels."
                    print, ""
                    show_orig=0
                    GOTO, skipdprread
                 ENDIF ELSE print, "Reading DPR from ",file_2aka
              END
   'DPRGMI' : BEGIN
                 IF N_ELEMENTS(flatpath) EQ 1 THEN path_tail = flatpath $
                 ELSE path_tail = parse_2a_filename( origFileCMBName )
                 file_2BCMB = GPMDATA_ROOT+DIR_COMB+"/"+path_tail+'/'+origFileCMBName
                 IF FILE_TEST(file_2BCMB, /READ, /REGULAR) NE 1 THEN BEGIN
                    message, "Cannot find 2BDPRGMI file "+file_2BCMB, /INFO
                    print, "Disabling full-resolution DPRGMI cross section panels."
                    print, ""
                    show_orig=0
                    GOTO, skipdprread
                 ENDIF ELSE print, "Reading DPRGMI from ",file_2BCMB
              END
   ENDCASE

   ; check Instrument_ID and DPR_scantype consistency
   CASE STRUPCASE(Instrument_ID) OF
       'KA' : BEGIN
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
   'DPRGMI' : BEGIN
                 ; 2BDPRGMI only has MS, NS scan/swath types
                 CASE STRUPCASE(DPR_scantype) OF
                    'MS' : 
                    'NS' : 
                    ELSE : message, "Illegal scan type '"+DPR_scantype+"'"
                 ENDCASE
                 dpr_data = read_2bcmb_hdf5(file_2BCMB, SCAN=DPR_scantype)
                 dpr_file_read = origFileCMBName
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

   IF pr_or_dpr EQ 'DPR' THEN BEGIN
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
         binRealSurface[*,*] = ELLIPSOID_BIN   ; reset to fixed bin of MSL surface
         binClutterFreeBottom = (*ptr_swath.PTR_PRE).binClutterFreeBottom
         localZenithAngle = (*ptr_swath.PTR_PRE).localZenithAngle
      ENDIF ELSE message, "Invalid pointer to PTR_PRE."

      IF PTR_VALID(ptr_swath.PTR_SLV) THEN BEGIN
         dbz_corr = (*ptr_swath.PTR_SLV).ZFACTORCORRECTED
      ENDIF ELSE message, "Invalid pointer to PTR_SLV."

      IF PTR_VALID(ptr_swath.PTR_SRT) THEN BEGIN
      ENDIF ELSE message, "Invalid pointer to PTR_SRT."

      IF PTR_VALID(ptr_swath.PTR_VER) THEN BEGIN
      ENDIF ELSE message, "Invalid pointer to PTR_VER."
   ENDIF ELSE BEGIN
      ; extract DPRGMI variables/arrays from struct pointers into variable names
      ; used in the DPR cross sections, for compatibility
      IF PTR_VALID(ptr_swath.PTR_DATASETS) THEN BEGIN
         dprlons = (*ptr_swath.PTR_DATASETS).LONGITUDE
         dprlats = (*ptr_swath.PTR_DATASETS).LATITUDE
         dbz_corr = (*ptr_swath.PTR_DATASETS).correctedReflectFactor  ;nKuKa
         dbz_meas = dbz_corr
         ptr_free, ptr_swath.PTR_DATASETS
      ENDIF ELSE message, "Invalid pointer to PTR_DATASETS."

      IF PTR_VALID(ptr_swath.PTR_Input) THEN BEGIN
         BB_hgt = (*ptr_swath.PTR_Input).zeroDegAltitude
         rainType = (*ptr_swath.PTR_Input).precipitationType      ; got to convert to TRMM
         surfaceRangeBin = (*ptr_swath.PTR_Input).surfaceRangeBin             ;nKuKa
         binClutterFreeBottom = (*ptr_swath.PTR_Input).lowestClutterFreeBin  ;nKuKa
         localZenithAngle = (*ptr_swath.PTR_Input).localZenithAngle
      ENDIF ELSE message, "Invalid pointer to PTR_Input."

      rainType = TEMPORARY(rainType)/100000L      ; truncate to TRMM 3-digit type
      ; deal with the nKuKa dimension in MS swath.  Get either the Ku or Ka
      ; subarray depending on where we are in the inner (swathID) loop
      IF ( DPR_scantype EQ 'MS' ) THEN BEGIN
         idxSwathInstrument = WHERE(swathIDs EQ DPR_scantype AND instruments EQ freqName)
         KKidx = idxKuKa[idxSwathInstrument]
         dbz_corr = REFORM(dbz_corr[KKidx,*,*,*])
         dbz_meas = dbz_corr
         binClutterFreeBottom = REFORM(binClutterFreeBottom[KKidx,*,*])
         surfaceRangeBin = REFORM(surfaceRangeBin[KKidx,*,*])
      ENDIF

      ; make a copy of surfaceRangeBin and set all values to the fixed
      ; bin number at the ellipsoid for DPRGMI setup.
      binRealSurface = surfaceRangeBin
      binRealSurface[*,*] = ELLIPSOID_BIN_DPRGMI
   ENDELSE

   ; free the memory/pointers in data structure
   free_ptrs_in_struct, dpr_data ;, /ver

   ; precompute the reuseable ray angle trig variables for parallax -- in GPM,
   ; we have the local zenith angle for every ray/scan (i.e., footprint)
   cos_inc_angle = COS( 3.1415926D * localZenithAngle / 180. )

  ; Optional bias/offset adjustment of DPR Z:
   IF adjust_dprz THEN BEGIN
      absbias = ABS( dpr_z_adjust )
      IF absbias GE 0.1 THEN BEGIN
         IF dpr_z_adjust LT 0.0 THEN BEGIN
           ; downward-adjust Zc values above ABS(grbias) separately from
           ; those below to avoid setting positive values to below 0.0
            idx_z2adj=WHERE(dbz_corr GT absbias, count2adj)
            IF count2adj GT 0 THEN dbz_corr[idx_z2adj] = dbz_corr[idx_z2adj]+dpr_z_adjust
            idx_z2adj=WHERE(dbz_corr GT 0.0 AND dbz_corr LE absbias, count2adj)
            IF count2adj GT 0 THEN dbz_corr[idx_z2adj] = 0.0
           ; also adjust Zmeas field
            idx_z2adj=WHERE(dbz_meas GT absbias, count2adj)
            IF count2adj GT 0 THEN dbz_meas[idx_z2adj] = dbz_meas[idx_z2adj]+dpr_z_adjust
            idx_z2adj=WHERE(dbz_meas GT 0.0 AND dbz_meas LE absbias, count2adj)
            IF count2adj GT 0 THEN dbz_meas[idx_z2adj] = 0.0
         ENDIF ELSE BEGIN
           ; upward-adjust Zc values that are above 0.0 dBZ only
            idx_z2adj=WHERE(dbz_corr GT 0.0, count2adj)
            IF count2adj GT 0 THEN dbz_corr[idx_z2adj] = dbz_corr[idx_z2adj]+dpr_z_adjust
           ; also adjust Zmeas field
            idx_z2adj=WHERE(dbz_meas GT 0.0, count2adj)
            IF count2adj GT 0 THEN dbz_meas[idx_z2adj] = dbz_meas[idx_z2adj]+dpr_z_adjust
         ENDELSE
      ENDIF ELSE print, "Ignoring negligible DPR Z bias value."
   ENDIF

   skipdprread:
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
   IF ( show_orig ) THEN BEGIN
      BB_hgtCopy = BB_hgt
      rainTypeCopy = rainType
      dbz_measCopy = dbz_meas
      dbz_corrCopy = dbz_corr
      binRealSurfaceCopy = binRealSurface
      binClutterFreeBottomCopy = binClutterFreeBottom
      cos_inc_angleCopy = cos_inc_angle
   ENDIF
ENDIF

;-------------------------------------------------

print, "Mean BB (AGL) from PR: ", STRING(BBparms.meanBB, FORMAT='(F0.1)') & print, ""

;-------------------------------------------------

; Set up the pixmap window for the PPI plots
windowsize = 350
xsize = windowsize[0]
ysize = xsize
IF ( pctAbvThresh GT 0 ) THEN title = STRING(pctAbvThresh,FORMAT='(i0)')+ $
                                      "% above-threshold samples shown" $
ELSE title = "All available samples shown"
window, 0, xsize=xsize, ysize=ysize*2, xpos = 75, TITLE = title, /PIXMAP

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
  ; check consistency between elev2show and actual number of sweeps present
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
                             yCorner, pr_index, nfp, ifram, $
                             rnTypeIn, WINSIZ=windowsize, TITLE=prtitle, $
                             MAXRNGKM=mygeometa.rangeThreshold, CREF=cref )

IF (cref) THEN gvtitle = mysite.site_ID+" Composite Ze, "+mysweeps[nframes/3].atimeSweepStart $
ELSE gvtitle = mysite.site_ID+" at "+elevstr+" deg., "+mysweeps[ifram].atimeSweepStart
mygvbuf = plot_sweep_2_zbuf( gvz, mysite.site_lat, mysite.site_lon, xCorner, $
                             yCorner, pr_index, nfp, ifram, $
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
;IF KEYWORD_SET(rhi_mode) EQ 0 THEN $
   mygvbuf[22:41,0:20] = 250B


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

; find lowest and highest scan and ray numbers in the overlap area, for later use
; in x-section plotting
raystartprmin = MIN( raypr )
rayendprmax = MAX( raypr )
scanstartprmin = scanoff  ; new, for RAY_MODE case
scanendprmax = scanmax

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
                          xCorner, yCorner, pr_index, nfp, ifram, $
                          WINSIZ=windowsize, TITLE=idxtitle, /NOCOLOR, $
                          MAXRNGKM=mygeometa.rangeThreshold )
;idxtitle = "PR ray number"
myraybuf = plot_sweep_2_zbuf_4xsec( pr_ray, mysite.site_lat, mysite.site_lon, $
                        xCorner, yCorner, pr_index, nfp, ifram, $
                        WINSIZ=windowsize, TITLE=idxtitle, /NOCOLOR, $
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
;IF KEYWORD_SET(rhi_mode) EQ 0 THEN BEGIN
   ; add a "hot corner" matching the GR PPI image, to return special value to
   ; initiate cross-section step-through animation
   myscanbuf[22:41,0:20] = 250B
   myraybuf[22:41,0:20] = 250B
;ENDIF

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
;IF KEYWORD_SET(rhi_mode) EQ 0 THEN $
   xyouts, 25, 7, color=0, "SC", /DEVICE, CHARSIZE=1
window, 1, xsize=xsize, ysize=ysize*2, xpos = 350, ypos=50, TITLE = title
Device, Copy=[0,0,xsize,ysize*2,0,0,0]

;-------------------------------------------------

IF KEYWORD_SET(rhi_mode) THEN BEGIN
  ; determine whether the ground radar is inside or outside of the DPR swath
  ; -- account for +3 offset and hot corner values
   IF (myscanbuf[x_gr, y_gr] GT 2 AND myscanbuf[x_gr, y_gr] LT 250B) THEN BEGIN
     ; we are "inside" the DPR swath, check whether we are on an edge ray.
     ; -- if so, then count it as NOT being inside the swath
      IF ( (myraybuf[x_gr, y_gr]-3) EQ 0 ) $
      OR ( (myraybuf[x_gr, y_gr]-3) EQ (RAYSPERSCAN-1) ) THEN gr_is_inside=0 $
      ELSE gr_is_inside=1
   ENDIF ELSE gr_is_inside=0
   ; grab one sweep of pr_index for later use in slicing along radial
   pr_index_slice = REFORM( pr_index[*,0] )
  ; compute the endpoints of all the radials in terms of DPR footprints
   pr_index_edges = rhi_endpoints( xCorner, yCorner, mygeometa, $
                                   pr_index_slice, RAYSPERSCAN, $
                                   gr_is_inside )
   ;print, "pr_index_edges: ", pr_index_edges
ENDIF

;-------------------------------------------------


; Let the user select the cross-section locations:
print, ''
print, '---------------------------------------------------------------------'
print, ''
print, ' > Left click on a PPI point to display a cross section of DPR and GR volume-match data'
IF ( show_orig ) THEN print, '   and full-vertical-resolution (125/250 m) DPR data,'
IF KEYWORD_SET(rhi_mode) EQ 0 THEN BEGIN
   print, " > or left click on the white square 'SC' at the lower right to step through"
   print, "   an animation sequence of cross sections for each DPR scan in the dataset,"
ENDIF ELSE BEGIN
   print, " > or left click on the white square 'SC' at the lower left to step through"
   print, "   an animation sequence of cross sections for each available radial."
ENDELSE
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
         IF ( show_orig ) THEN WDELETE, 3
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

         IF ( KEYWORD_SET(ray_mode) EQ 0 ) THEN BEGIN
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
           ; set the fixed product-relative scan number as both the start and end scan
            scanstartpr = scanNumpr & scanendpr = scanNumpr
            locatorLabel = "Scan "+STRING(scanNumpr+1, FORMAT='(I0)')
            IF KEYWORD_SET(verbose) THEN BEGIN
               print, "ray start, end: ", raystartpr+1, rayendpr+1  ; 1-based
               print, "idxmin, idxmax: ", idxmin, idxmax            ; 0-based
            ENDIF

           ; find the endpoints of the selected scan line on the PPI (pixmaps), and
           ; plot a line connecting the midpoints of the footprints at either end to
           ; show where the cross section will be generated
            idxlinebeg = WHERE( myscanbuf EQ scanNum and myraybuf EQ raystart, countbeg )
            idxlineend = WHERE( myscanbuf EQ scanNum and myraybuf EQ rayend, countend )
         ENDIF ELSE BEGIN
           ; DO THE CROSS SECTION ALONG DPR TRACK AT A CONSTANT LOOK ANGLE (RAY NUMBER)
           ; idxcurscan should also be the sweep-by-sweep locations of all the
           ; volume-matched footprints along the scan in the geo_match datasets,
           ; which are what we need later to plot the geo-match cross sections
            idxcurscan = WHERE( pr_ray EQ rayNum )
            pr_scans_for_ray = pr_scan[idxcurscan]
           ; the next two lines would be a bug if fprep_geo_match_profiles() hadn't already
           ; filtered out the negative values from the pr_index array used to initialize
           ; pr_scan and pr_ray, and we had a scan-edge-marked matchup data file from POLAR2PR
           ; -- as it stands, we're safe doing this
            scanstart = MIN( pr_scans_for_ray, idxmin, MAX=scanend, $
                            SUBSCRIPT_MAX=idxmax )
            scanstartpr = scanstart+scanoff-3L & scanendpr = scanend+scanoff- 3L
           ; set both the start and end ray to the fixed ray number
            raystartpr = rayNum-3L & rayendpr = rayNum-3L
           ; use actual zenith angle if available, or use 0.71 deg step if not
            IF ( show_orig ) THEN $
               angledeg=90.0-180/!PI*ACOS(cos_inc_angle[raystartpr,scanstartpr]) $
            ELSE angledeg = 90.0 + (rayendpr - RAYSPERSCAN/2)*0.71
            angledegSTR = STRING(angledeg, FORMAT='(F0.1)')
            locatorLabel = "Ray "+STRING(rayendpr+1, FORMAT='(I0)')+", "+ $
                            angledegSTR+" deg."
            IF KEYWORD_SET(verbose) THEN BEGIN
               print, "scan start, end: ", scanstartpr+1, scanendpr+1  ; 1-based
               print, "idxmin, idxmax: ", idxmin, idxmax            ; 0-based
               print, "Scan angle: ", angledegSTR, "  Ray number: ", $
                      STRING(rayendpr+1, FORMAT='(I0)'), " of ", $
                      STRING(RAYSPERSCAN, FORMAT='(I0)')
            ENDIF

           ; find the endpoints of the selected scan line on the PPI (pixmaps), and
           ; plot a line connecting the midpoints of the footprints at either end to
           ; show where the cross section will be generated
            idxlinebeg = WHERE( myscanbuf EQ scanstart and myraybuf EQ rayNum, countbeg )
            idxlineend = WHERE( myscanbuf EQ scanend and myraybuf EQ rayNum, countend )
         ENDELSE

         startxys = ARRAY_INDICES( myscanbuf, idxlinebeg )
         endxys = ARRAY_INDICES( myscanbuf, idxlineend )
         xbeg = MEAN( startxys[0,*] ) & xend = MEAN( endxys[0,*] )
         ybeg = MEAN( startxys[1,*] ) & yend = MEAN( endxys[1,*] )

      ENDIF ELSE BEGIN

        ; DO THE CROSS SECTION ALONG A GR RADIAL
        ; find the pr_index, scan, ray values for samples along the radial line
         RadialData = rhi_pr_indices( myscanbuf, myraybuf, x_gr, y_gr, xppi, yppi, $
                                      ysize, SCANOFF, pr_index_slice, RAYSPERSCAN )
         numPRradial = RadialData.numPRradial
         indexRadial = RadialData.indexRadial
         rayRadial = RadialData.rayRadial
         scanRadial = RadialData.scanRadial
         xbeg = RadialData.xbeg & xend = RadialData.xend
         ybeg = RadialData.ybeg & yend = RadialData.yend
         RadialData = 0
         angle = (180./!pi)*ATAN(xend-x_gr, yend-y_gr)
         IF angle LT 0.0 THEN angle = angle+360.0
         locatorLabel = STRING(angle, FORMAT='(F0.1)') + " deg. radial"

        ; extract a cross section of each of the plotted data arrays
        ; for PR footprints along the RHI
         gvz = extract_radial_slice(gvzCopy, indexRadial)
         zcor = extract_radial_slice(zcorCopy, indexRadial)
         top = extract_radial_slice(topCopy, indexRadial)
         botm = extract_radial_slice(botmCopy, indexRadial)
         rntypeIn = extract_radial_slice(rntypeCopy, indexRadial)  ; ???
         bbprox = extract_radial_slice(bbproxCopy, indexRadial)
         gvrtype = extract_radial_slice(gvrtypeCopy, indexRadial)
         idx2adj = WHERE(gvz GT 0.0)
        ; copy full-resolution DPR arrays only if plotting them
         IF ( show_orig ) THEN BEGIN
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
         scanstartpr = 0  &  scanendpr = 0  &  idxcurscan = LINDGEN(numPRradial)
         raystartpr = 0  &  idxmin = 0
         rayendpr = numPRradial-1  &  idxmax = numPRradial-1
         zoomh = 2                 ; override any other zoom mode
         label_by_raynum = 0       ; override any other label mode

        ; --------------------------------------------------------------------

      ENDELSE

      Device, Copy=[0,0,xsize,ysize*3,0,0,0]  ; erase the prior line, if any
     ; plot a line in the lower panel PPI connecting the midpoints of the
     ; footprints at either end to show where the cross section will be generated
      PLOTS, [xbeg, xend], [ybeg, yend], /DEVICE, COLOR=122, THICK=2
     ; now plot the line in the upper PPI panel
      PLOTS, [xbeg, xend], [ybeg+ysize, yend+ysize], /DEVICE, COLOR=122, THICK=2

     ; determine the labeling option in effect, and format labels accordingly
      IF ( label_by_raynum AND ray_mode EQ 0 ) THEN BEGIN
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

     ; add the label indicating the DPR/radial scan/angle to the PPIs
      XYOUTS, 32, ysize-42, locatorLabel, /DEVICE, COLOR=0, CHARSIZE=1.5, CHARTHICK=2
      XYOUTS, 30, ysize-40, locatorLabel, /DEVICE, COLOR=122, CHARSIZE=1.5, CHARTHICK=2
      XYOUTS, 32, ysize*2-42, locatorLabel, /DEVICE, COLOR=0, CHARSIZE=1.5, CHARTHICK=2
      XYOUTS, 30, ysize*2-40, locatorLabel, /DEVICE, COLOR=122, CHARSIZE=1.5, CHARTHICK=2

      IF ( ray_mode EQ 0 ) THEN BEGIN
        ; set up parameters to implement zoom behavior specified: if 1, then
        ; zoom to fattest part of overlap area, if 0 then configure to 49 rays, 
        ; if 2 then do legacy behavior (null values for parameters DATASTARTEND
        ; and PLOTBOUNDS)
         CASE zoomh OF
           0 : BEGIN
                  datastartend = [raystartpr,rayendpr]
                  plotbounds = [0, RAYSPERSCAN-1]
               END
           1 : BEGIN
                  datastartend = [raystartpr,rayendpr]
                  plotbounds = [raystartprmin,rayendprmax]
               END
           2 : BEGIN
                 ; undefine datastartend and plotbounds, if previously defined via override
                  IF label_by_raynum THEN datastartend = [raystartpr,rayendpr]
                  IF N_ELEMENTS(plotbounds) NE 0 THEN UNDEFINE, plotbounds
               END
         ENDCASE
      ENDIF ELSE BEGIN
         CASE zoomh OF
           0 : BEGIN
                  datastartend = [scanstartpr,scanendpr]
                  plotbounds = [scanstartprmin,scanendprmax]
               END
           1 : BEGIN
                  datastartend = [scanstartpr,scanendpr]
                  plotbounds = [scanstartprmin,scanendprmax]
               END
           2 : BEGIN
                 ; undefine plotbounds, if previously defined via override
                  datastartend = [scanstartpr,scanendpr]
                  IF N_ELEMENTS(plotbounds) NE 0 THEN UNDEFINE, plotbounds
               END
         ENDCASE
      ENDELSE

      IF ( show_orig ) THEN BEGIN
        ; generate the PR full-resolution vertical cross section plot
         meanBBmsl = BBparms.meanBB + mysite.site_elev   ; adjust back to MSL for 2A25 plot
         tvlct, rr, gg, bb
         olddevice = !D.NAME
         scaledpr=1.

         dprxsect_struct = plot_dpr_xsection_zbuf( scanstartpr, scanendpr, raystartpr, rayendpr, $
                              dbz_corr, meanBBmsl, scaledpr, cos_inc_angle, GATE_SPACE, $
                              binRealSurface, binClutterFreeBottom, BB_hgt, $
                              TITLE=caseTitle25, BBBYRAY=BBbyRay, BBWIDTH=bbwidth, $
                              PLOTBOUNDS=plotbounds, $
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
                                DATASTARTEND=datastartend, PLOTBOUNDS=plotbounds, $
                                LABEL_BY_RAYNUM=label_by_raynum, SOURCELABEL=sourceLabel)

      SET_PLOT, olddevice  ; reset the device type for rendering x-sections
      WINDOW, 5, xsize=xsect_struct.xs_prgr, ysize=xsect_struct.ys_prgr, ypos=50, $
              TITLE = TITLE_5
      TV, xsect_struct.PRGR_XSECT    ; plot the PR and GR geo-match x-sections

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
      print, "   animation loop of volume-match and full-resolution DPR and GR data."
      IF KEYWORD_SET(rhi_mode) EQ 0 THEN BEGIN
         print, " > Left click on the white square 'SC' at the lower left to step through"
         print, "   an animation sequence of cross sections for each DPR scan in the dataset."
      ENDIF ELSE BEGIN
         print, " > Left click on the white square 'SC' at the lower left to step through"
         print, "   an animation sequence of cross sections for each available radial."
      ENDELSE
      print, ' > Right click inside a PPI image to select another case.'
      print, ''

   ENDIF ELSE BEGIN   ; ( scanNum GT 2 AND scanNum LT 250B )

     ; only the lower (GR) image has hot corners, check whether cursor lies there
      IF ( yppi LE ysize ) THEN BEGIN
      CASE scanNum OF
         254B : BEGIN
                   IF KEYWORD_SET(cappi_anim) THEN loopframes = N_ELEMENTS(cappi_heights) $
                   ELSE loopframes = (ifram+1)*2 < nframes
                  ; set up for bailout prompt if animating too many PPIs
                   doodah = ""
                   IF loopframes GT 10 THEN BEGIN
                      PRINT, ''
                      PRINT, "Attempting to build animation loop for at least ", $
                              STRING(loopframes*2,FORMAT='(I0)'), ' frames!'
                      READ, doodah, $
                      PROMPT='Hit Return to skip animation loop, C to Continue: '
                   ENDIF ELSE doodah = "C"
                   IF STRUPCASE(doodah) EQ 'C' THEN $
                      status = loop_pr_gv_gvpolar_ppis(dataStruct, 3, $
                                   loopframes, CAPPI_HEIGHTS=cappi_heights, $
                                   INSTRUMENT_ID=pr_or_dpr)
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
                                DATASTARTEND=datastartend, PLOTBOUNDS=plotbounds, $
                                SOURCELABEL=sourceLabel)

                      SET_PLOT, olddevice  ; reset the device type for rendering x-sections
                      WINDOW, 5, xsize=xsect_struct.xs_prgr, ysize=xsect_struct.ys_prgr, $
                              ypos=50, TITLE = TITLE_5
                      TV, xsect_struct.PRGR_XSECT    ; plot the PR and GR geo-match x-sections
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
                                DATASTARTEND=datastartend, PLOTBOUNDS=plotbounds, $
                                LABEL_BY_RAYNUM=label_by_raynum, $
                                SOURCELABEL=sourceLabel )

                      SET_PLOT, olddevice  ; reset the device type for rendering x-sections
                      WINDOW, 5, xsize=xsect_struct.xs_prgr, ysize=xsect_struct.ys_prgr, $
                              ypos=50, TITLE = TITLE_5
                      TV, xsect_struct.PRGR_XSECT    ; plot the PR and GR geo-match x-sections
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
                                DATASTARTEND=datastartend, PLOTBOUNDS=plotbounds, $
                                SOURCELABEL=sourceLabel)

                      SET_PLOT, olddevice  ; reset the device type for rendering x-sections
                      WINDOW, 5, xsize=xsect_struct.xs_prgr, ysize=xsect_struct.ys_prgr, $
                              ypos=50, TITLE = TITLE_5
                      TV, xsect_struct.PRGR_XSECT    ; plot the PR and GR geo-match x-sections
                      WINDOW, 6, xsize=xsect_struct.xs_diff, ysize=xsect_struct.ys_diff, $
                              TITLE = DIFFTITLE
                     ; reset the color tables for the PR-GR difference x-section, and plot it
                      tvlct, xsect_struct.redct, xsect_struct.grnct, xsect_struct.bluct
                      TV, xsect_struct.DIFF_XSECT
                   ENDIF ELSE print, "NOTE: No cross section displayed", $
                                     " -- no S-to-Ku adjustments applied."
                END
         250B : BEGIN
                   print, ''
                   IF KEYWORD_SET(rhi_mode) THEN BEGIN
                      print, 'Stepping through cross sections of each radial in matchup dataset'
                      print, ''
                     ; get the list of scan and ray numbers of the pr_index
                     ; values at the endpoint of each radial to plot
                      raysedge = pr_index_edges MOD RAYSPERSCAN
                      scansedge = pr_index_edges/RAYSPERSCAN
                     ; walk through the radials once to find the max width in footprints
                     ; for sizing the geo-match and DPR cross section windows
                      n2do = N_ELEMENTS(pr_index_edges)
                      maxFPradials = 0
                      for scan2do = 0, n2do-1 DO BEGIN
                         ; find the endpoint of the selected RHI line on the PPI (pixmaps)
                         idxlineend = WHERE( myscanbuf EQ (scansedge[scan2do] - scanoff + 3L) and $
                                             myraybuf EQ (raysedge[scan2do] + 3L), countend )
                         endxys = ARRAY_INDICES( myscanbuf, idxlineend )
                         xppi = MEAN( endxys[0,*] )
                         yppi = MEAN( endxys[1,*] )
                         angle = (180./!pi)*ATAN(xppi-x_gr, yppi-y_gr)
                         IF angle LT 0.0 THEN angle = angle+360.0
;                         PRINT, "Angle: ", STRING(angle, FORMAT='(F0.1)')
                         raystartlbl = 'A'
                         rayendlbl = 'B'
                        ; DO THE CROSS SECTION ALONG A GR RADIAL
                        ; find the pr_index, scan, ray values for samples along the radial line
                         RadialData = rhi_pr_indices( myscanbuf, myraybuf, x_gr, y_gr, xppi, yppi, $
                                                      ysize, SCANOFF, pr_index_slice, RAYSPERSCAN )
                         maxFPradials = maxFPradials > RadialData.numPRradial
                         RadialData = 0
                      endfor
                      plotbounds = [0, maxFPradials-1]
                   ENDIF ELSE BEGIN
                      IF ( ray_mode EQ 0 ) THEN BEGIN
                         print, "Stepping through cross sections of each DPR scan in matchup dataset"
                        ; set up parameters to implement zoom behavior specified: if 1, then
                        ; zoom to fattest part of overlap area, if 0 then configure to 49 rays, 
                        ; if 2 then override legacy behavior to same as 1. Define datastartend
                        ; scan-by-scan in FOR loop below.
                         IF zoomh GE 1 THEN plotbounds = [raystartprmin,rayendprmax] $
                         ELSE plotbounds = [0, RAYSPERSCAN-1]
                         n2do = scanmax-scanoff+1
                      ENDIF ELSE BEGIN
                         print, "Stepping through cross sections of each DPR ray angle"
                         plotbounds = [scanstartprmin,scanendprmax]  ; zoom to fattest part of overlap
                         n2do = rayendprmax-raystartprmin+1
                      ENDELSE
                   ENDELSE

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

                  ; specify a GIF file to write the animation frames to if GIF_PATH is defined
                   IF N_ELEMENTS(gif_path) EQ 1 THEN BEGIN
                      IF gif_path NE '' THEN BEGIN
                         gif_file = GIF_PATH+'/' + gif_base
                         have_gif = 0      ; flag, has GIF file been opened?
                      ENDIF
                   ENDIF
                  ; count of sequential "empty" cross sections, initialize to force skip of
                  ; GIF output until first non-empty frame is found
                   num_no_data = 2
                   askAgain = 1     ; flag to prompt for next scan in manual step mode

                   FOR scan2do = 0, n2do-1 DO BEGIN
                     ; destroy existing x-section windows 1st time through loop,
                     ; may need resizing
                      IF ( havewin2 EQ 1 AND scan2do EQ 0 ) THEN BEGIN
                         WDELETE, 5
                         WDELETE, 6
                         tvlct, rr, gg, bb
                      ENDIF

                      IF KEYWORD_SET(rhi_mode) THEN BEGIN
                         ; find the endpoint of the selected RHI line on the PPI (pixmaps)
                         idxlineend = WHERE( myscanbuf EQ (scansedge[scan2do] - scanoff + 3L) and $
                                             myraybuf EQ (raysedge[scan2do] + 3L), countend )
                         endxys = ARRAY_INDICES( myscanbuf, idxlineend )
                         xppi = MEAN( endxys[0,*] )
                         yppi = MEAN( endxys[1,*] )
                         angle = (180./!pi)*ATAN(xppi-x_gr, yppi-y_gr)
                         IF angle LT 0.0 THEN angle = angle+360.0
;                         PRINT, "Angle: ", STRING(angle, FORMAT='(F0.1)')
                         locatorLabel = STRING(angle, FORMAT='(F0.1)')+" deg. radial"
                         raystartlbl = 'A'
                         rayendlbl = 'B'
                        ; DO THE CROSS SECTION ALONG A GR RADIAL
                        ; find the pr_index, scan, ray values for samples along the radial line
                         RadialData = rhi_pr_indices( myscanbuf, myraybuf, x_gr, y_gr, xppi, yppi, $
                                                      ysize, SCANOFF, pr_index_slice, RAYSPERSCAN )
                         numPRradial = RadialData.numPRradial
                         indexRadial = RadialData.indexRadial
                         rayRadial = RadialData.rayRadial
                         scanRadial = RadialData.scanRadial
                         xbeg = RadialData.xbeg & xend = RadialData.xend
                         ybeg = RadialData.ybeg & yend = RadialData.yend
                        ; make a copy for those values modified before GIF loop
                         xbegGIF=xbeg & xendGIF=xend & ybegGIF=ybeg & yendGIF=yend
                         RadialData = 0

                        ; extract a cross section of each of the plotted data arrays
                        ; for PR footprints along the RHI
                         gvz = extract_radial_slice(gvzCopy, indexRadial)
                         zcor = extract_radial_slice(zcorCopy, indexRadial)
                         top = extract_radial_slice(topCopy, indexRadial)
                         botm = extract_radial_slice(botmCopy, indexRadial)
                         rntypeIn = extract_radial_slice(rntypeCopy, indexRadial)  ; ???
                         bbprox = extract_radial_slice(bbproxCopy, indexRadial)
                         gvrtype = extract_radial_slice(gvrtypeCopy, indexRadial)
                         idx2adj = WHERE(gvz GT 0.0)
                        ; copy full-resolution DPR arrays only if plotting them
                         IF ( show_orig ) THEN BEGIN
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
                         scanstartpr = 0  &  scanendpr = 0  &  idxcurscan = LINDGEN(numPRradial)
                         raystartpr = 0  &  idxmin = 0
                         rayendpr = numPRradial-1  &  idxmax = numPRradial-1
                         label_by_raynum = 0       ; override any other label mode
                        ; set values for DATASTARTEND parameter
                         datastartend=[raystartpr,rayendpr]
                      ENDIF ELSE BEGIN
                         IF ( KEYWORD_SET(ray_mode) EQ 0 ) THEN BEGIN
                           ; DO THE CROSS SECTION ALONG THE DPR SCAN LINE
                            scanNumpr = scanoff+scan2do
                            scanNum = scan2do + 3L
                            IF KEYWORD_SET(verbose) THEN $
                               print, "Product-relative scan number: ", scanNumpr+1

                           ; idxcurscan should also be the sweep-by-sweep locations of all the
                           ; volume-matched footprints along the scan in the geo_match datasets,
                           ; which are what we need later to plot the geo-match cross sections
                            idxcurscan = WHERE( pr_scan EQ scanNum )
                            pr_rays_in_scan = pr_ray[idxcurscan]
                            raystart = MIN( pr_rays_in_scan, idxmin, MAX=rayend, $
                                            SUBSCRIPT_MAX=idxmax )
                            raystartpr = raystart-3L & rayendpr = rayend-3L
                           ; set the fixed product-relative scan number as both the start and end scan
                            scanstartpr = scanNumpr & scanendpr = scanNumpr
                            locatorLabel = "Scan "+STRING(scanNumpr+1, FORMAT='(I0)')
                            IF KEYWORD_SET(verbose) THEN $
                               print, locatorLabel, ",  ray start, end: ", raystartpr, rayendpr
                           ; determine the labeling option in effect, and format labels accordingly
                            IF ( label_by_raynum ) THEN BEGIN
                               raystartlbl = STRING(raystartpr+1, FORMAT='(I0)')  ; 1-based for labels
                               rayendlbl = STRING(rayendpr+1, FORMAT='(I0)')
                            ENDIF ELSE BEGIN
                               raystartlbl = 'A'
                               rayendlbl = 'B'
                            ENDELSE
                           ; set values for DATASTARTEND parameter
                            datastartend=[raystartpr,rayendpr]
                         ENDIF ELSE BEGIN
                           ; DO THE CROSS SECTION ALONG DPR TRACK AT A CONSTANT LOOK ANGLE (RAY NUMBER)
                           ; idxcurscan should also be the sweep-by-sweep locations of all the
                           ; volume-matched footprints along the scan in the geo_match datasets,
                           ; which are what we need later to plot the geo-match cross sections
                            rayNum = raystartprmin+scan2do + 3L
                            idxcurscan = WHERE( pr_ray EQ rayNum )
                            pr_scans_for_ray = pr_scan[idxcurscan]
                           ; the next two lines would be a bug if fprep_geo_match_profiles() hadn't already
                           ; filtered out the negative values from the pr_index array used to initialize
                           ; pr_scan and pr_ray, and we had a scan-edge-marked matchup data file from POLAR2PR
                           ; -- as it stands, we're safe doing this
                            scanstart = MIN( pr_scans_for_ray, idxmin, MAX=scanend, $
                                            SUBSCRIPT_MAX=idxmax )
                            scanstartpr = scanstart+scanoff-3L & scanendpr = scanend+scanoff- 3L
                           ; set the fixed ray number as both the start and end ray
                            raystartpr = rayNum-3L & rayendpr = rayNum-3L
                            raystartlbl = 'L'
                            rayendlbl = 'H'
                           ; use actual zenith angle if available, or use 0.71 deg step if not
                            IF ( show_orig ) THEN $
                               angledeg=90.0-180/!PI*ACOS(cos_inc_angle[raystartpr,scanstartpr]) $
                            ELSE angledeg = 90.0 + (rayendpr - RAYSPERSCAN/2)*0.71
                            angledegSTR = STRING(angledeg, FORMAT='(F0.1)')
                            locatorLabel = "Ray "+STRING(rayendpr+1, FORMAT='(I0)')+", "+ $
                                            angledegSTR+" deg."
                            IF KEYWORD_SET(verbose) THEN BEGIN
                               print, "scan start, end: ", scanstartpr+1, scanendpr+1  ; 1-based
                               print, "idxmin, idxmax: ", idxmin, idxmax            ; 0-based
                               print, "Scan angle: ", angledegSTR
                            ENDIF
                           ; set values for DATASTARTEND parameter
                            datastartend=[scanstartpr,scanendpr]
                         ENDELSE
                      ENDELSE

                      Device, Copy=[0,0,xsize,ysize*3,0,0,0]  ; erase the prior line, if any

                      IF ( show_orig ) THEN BEGIN
                        ; generate the PR full-resolution vertical cross section plot
                        ; -- adjust back to MSL for full-res original data plot
                         meanBBmsl = BBparms.meanBB + mysite.site_elev
                         tvlct, rr, gg, bb
                         olddevice = !D.NAME
                         scaledpr=1.
                         dprxsect_struct = plot_dpr_xsection_zbuf( scanstartpr, scanendpr, $
                              raystartpr, rayendpr, dbz_corr, meanBBmsl, $
                              scaledpr, cos_inc_angle, GATE_SPACE, $
                              binRealSurface, binClutterFreeBottom, BB_hgt, $
                              TITLE=caseTitle25, BBBYRAY=BBbyRay, $
                              BBWIDTH=bbwidth, PLOTBOUNDS=plotbounds, $
                              LABEL_BY_RAYNUM=label_by_raynum, $
                              SOURCELABEL=sourceLabel, RHI_MODE=rhi_mode )

;                         title = "DPR Reflectivity, 125m gates"
                         SET_PLOT, olddevice
                         IF scan2do EQ 0 THEN $
                            WINDOW, 3, xsize=dprxsect_struct.xs_pr2, $
                                    ysize=dprxsect_struct.ys_pr2, $
                                    ypos=50, TITLE = title_3 $
                         ELSE WSET, 3
                         tvlct, dprxsect_struct.redct, dprxsect_struct.grnct, $
                                dprxsect_struct.bluct
                         TV, dprxsect_struct.PR2_XSECT
                         print, ''
                         columnsComb = 3         ; # columns in merged/GIF plot
                      ENDIF ELSE columnsComb = 2

                     ; generate the PR and GR geo-match vertical cross sections
                     ; -- with any indicated GR offset, and Ku conversion if indicated
                      IF scan2do EQ 0 THEN $
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
                                        DATASTARTEND=datastartend, PLOTBOUNDS=plotbounds, $
                                        LABEL_BY_RAYNUM=label_by_raynum, $
                                        SOURCELABEL=sourceLabel, /DIFFTEXT )

                     ; After creation, we just load new contents to existing windows for each
                     ; cross section in the sequence.  This way the window doesn't "flash" as
                     ; each new cross section is displayed, and is the reason for the change to
                     ; plotting the geo-match x-sections to the z-buffer rather than directly
                     ; to the X-window.
                      SET_PLOT, olddevice

                      difftitle = sourceLabel + "-GR Vol. Match Diffs."
                      IF scan2do EQ 0 THEN $
                         WINDOW, 6, xsize=xsect_struct.xs_diff, ysize=xsect_struct.ys_diff, $
                                    TITLE = difftitle $
                      ELSE WSET, 6
                      tvlct, xsect_struct.redct, xsect_struct.grnct, xsect_struct.bluct
                      TV, xsect_struct.DIFF_XSECT


                      ; set up a window that contains both the PPIs and the geo-match
                      ; cross sections together, and also the full-res plot if indicated
                      xsIncrement = (xsect_struct.xs_prgr > xsize)
                      xsComb = xsIncrement*columnsComb
                      ysComb = xsect_struct.ys_prgr > (ysize*2)
                      IF scan2do EQ 0 THEN $
                         window, 9, xsize=xsComb, ysize=ysComb, /pixmap, RETAIN=2 $
                      ELSE wset, 9
                      tvlct, rr, gg, bb
                      ; render the PPI selector and position annonations on the left side
                      TV, myprbufClean, 0, ysComb/2
                      TV, mygvbufClean, 0, 0
                      IF rhi_mode EQ 0 then begin
                        ; find the endpoints of the selected scan line on the PPI (pixmaps), and
                        ; plot a line connecting the midpoints of the footprints at either end to
                        ; show where the cross section will be generated
                         IF ( KEYWORD_SET(ray_mode) EQ 0 ) THEN BEGIN
                            idxlinebeg = WHERE( myscanbuf EQ scanNum $
                                                and myraybuf EQ raystart, countbeg )
                            idxlineend = WHERE( myscanbuf EQ scanNum $
                                                and myraybuf EQ rayend, countend )
                         ENDIF ELSE BEGIN
                            idxlinebeg = WHERE( myscanbuf EQ scanstart $
                                                and myraybuf EQ rayNum, countbeg )
                            idxlineend = WHERE( myscanbuf EQ scanend $
                                                and myraybuf EQ rayNum, countend )
                         ENDELSE
                         startxys = ARRAY_INDICES( myscanbuf, idxlinebeg )
                         endxys = ARRAY_INDICES( myscanbuf, idxlineend )
                         xbeg = MEAN( startxys[0,*] ) & xend = MEAN( endxys[0,*] )
                         ybeg = MEAN( startxys[1,*] ) & yend = MEAN( endxys[1,*] )
                        ; make a copy for those original values for use in GIF loop
                         xbegGIF=xbeg & xendGIF=xend & ybegGIF=ybeg & yendGIF=yend
                      ENDIF
                     ; plot scan number / ray number + angle / radial angle label on PPIs
                      XYOUTS, 32, ysize-42, locatorLabel, /DEVICE, COLOR=0, CHARSIZE=1.5, CHARTHICK=2
                      XYOUTS, 30, ysize-40, locatorLabel, /DEVICE, COLOR=122, CHARSIZE=1.5, CHARTHICK=2
                      XYOUTS, 32, ysize*2-42, locatorLabel, /DEVICE, COLOR=0, CHARSIZE=1.5, CHARTHICK=2
                      XYOUTS, 30, ysize*2-40, locatorLabel, /DEVICE, COLOR=122, CHARSIZE=1.5, CHARTHICK=2
                      PLOTS, [xbeg, xend], [ybeg, yend], /DEVICE, COLOR=122, THICK=2
                      XYOUTS, xbeg+1, ybeg-1, raystartlbl, /DEVICE, COLOR=0, $
                              CHARSIZE=2, CHARTHICK=2  ; underplot in black
                      XYOUTS, xend+1, yend-1, rayendlbl, /DEVICE, COLOR=0, $
                              CHARSIZE=2, CHARTHICK=2
                      XYOUTS, xbeg, ybeg, raystartlbl, /DEVICE, COLOR=122, $
                              CHARSIZE=2, CHARTHICK=2    ; overplot in white
                      XYOUTS, xend, yend, rayendlbl, /DEVICE, COLOR=122, $
                              CHARSIZE=2, CHARTHICK=2
                      ybeg = ybeg+ysize & yend = yend+ysize
                      PLOTS, [xbeg, xend], [ybeg, yend], /DEVICE, COLOR=122, THICK=2
                      XYOUTS, xbeg+1, ybeg-1, raystartlbl, /DEVICE, COLOR=0, $
                              CHARSIZE=2, CHARTHICK=2
                      XYOUTS, xend+1, yend-1, rayendlbl, /DEVICE, COLOR=0, $
                              CHARSIZE=2, CHARTHICK=2
                      XYOUTS, xbeg, ybeg, raystartlbl, /DEVICE, COLOR=122, $
                              CHARSIZE=2, CHARTHICK=2
                      XYOUTS, xend, yend, rayendlbl, /DEVICE, COLOR=122, $
                              CHARSIZE=2, CHARTHICK=2

                      ; render the geo-match cross sections on the right of the PPI plot
                      TV, xsect_struct.PRGR_XSECT, xsIncrement, $
                          (ysComb-xsect_struct.ys_prgr)/2

                      IF ( show_orig ) THEN BEGIN
                        ; render the PR full-resolution vertical cross section plot on the far right
                         TV, dprxsect_struct.PR2_XSECT, xsIncrement*2, $
                          (ysComb-xsect_struct.ys_prgr)/2
                      ENDIF

                     ; define and/or write to display window
                      IF scan2do EQ 0 THEN window, 5, xsize=xsComb, ysize=ysComb, TITLE=title_5 $
                      ELSE wset, 5
                      DEVICE, COPY=[0,0,xsComb,ysComb,0,0,9]
                      havewin2 = 1  ; need to delete x-sect windows at end
                      PRINT, '' & doodah = ''

                      IF N_ELEMENTS(gif_file) EQ 1 THEN BEGIN

                        ; write frames to display and GIF file in rapid sequence with no user prompt
                        ; -- if we get more than one empty cross section in a row, skip output
                        ;    of their GIF frame(s)
                         IF xsect_struct.no_data THEN $
                            num_no_data = num_no_data + xsect_struct.no_data $
                         ELSE num_no_data = 0
                         IF num_no_data LE 1 THEN BEGIN
                           ; define a Z-buffer rather than a WINDOW to hold the current
                           ; image frame, since we need to do TVRD() to get its contents,
                           ; and that is really slow in X-world over a remote connection!
                            olddevice = !D.NAME  ; grab the current device definition
                            SET_PLOT,'Z'
                            DEVICE, SET_RESOLUTION = [xsComb,ysComb], SET_CHARACTER_SIZE=[6,10]

                           ; render the PPI selector and position annonations on the left side
                            TV, myprbufClean, 0, ysComb/2
                            TV, mygvbufClean, 0, 0
                           ; reset the endpoints of the selected scan line on the PPI (pixmaps), and
                           ; plot a line connecting the midpoints of the footprints at either end to
                           ; show where the cross section is located
                            xbeg=xbegGIF & xend=xendGIF & ybeg=ybegGIF & yend=yendGIF
                            PLOTS, [xbeg, xend], [ybeg, yend], /DEVICE, COLOR=122, THICK=2
                            XYOUTS, xbeg+1, ybeg-1, raystartlbl, /DEVICE, COLOR=0, CHARSIZE=2, CHARTHICK=2
                            XYOUTS, xend+1, yend-1, rayendlbl, /DEVICE, COLOR=0, CHARSIZE=2, CHARTHICK=2
                            XYOUTS, xbeg, ybeg, raystartlbl, /DEVICE, COLOR=122, CHARSIZE=2, CHARTHICK=2
                            XYOUTS, xend, yend, rayendlbl, /DEVICE, COLOR=122, CHARSIZE=2, CHARTHICK=2
                            ybeg = ybeg+ysize & yend = yend+ysize
                            PLOTS, [xbeg, xend], [ybeg, yend], /DEVICE, COLOR=122, THICK=2
                            XYOUTS, xbeg+1, ybeg-1, raystartlbl, /DEVICE, COLOR=0, CHARSIZE=2, CHARTHICK=2
                            XYOUTS, xend+1, yend-1, rayendlbl, /DEVICE, COLOR=0, CHARSIZE=2, CHARTHICK=2
                            XYOUTS, xbeg, ybeg, raystartlbl, /DEVICE, COLOR=122, CHARSIZE=2, CHARTHICK=2
                            XYOUTS, xend, yend, rayendlbl, /DEVICE, COLOR=122, CHARSIZE=2, CHARTHICK=2
                           ; plot scan/ray number and/or angle label on PPIs
                            XYOUTS, 32, ysize-42, locatorLabel, /DEVICE, COLOR=0, CHARSIZE=1.5, CHARTHICK=2
                            XYOUTS, 30, ysize-40, locatorLabel, /DEVICE, COLOR=122, CHARSIZE=1.5, CHARTHICK=2
                            XYOUTS, 32, ysize*2-42, locatorLabel, /DEVICE, COLOR=0, CHARSIZE=1.5, CHARTHICK=2
                            XYOUTS, 30, ysize*2-40, locatorLabel, /DEVICE, COLOR=122, CHARSIZE=1.5, CHARTHICK=2

                            ; render the geo-match cross sections on the right of PPIs
                            TV, xsect_struct.PRGR_XSECT, xsIncrement, (ysComb-xsect_struct.ys_prgr)/2

                            IF ( show_orig ) THEN BEGIN
                              ; render the PR full-resolution cross sections on the far right
                               TV, dprxsect_struct.PR2_XSECT, xsIncrement*2, $
                                (ysComb-xsect_struct.ys_prgr)/2
                            ENDIF

                           ; grab the color table to use depending on whether modified for
                           ; full-res plots or not
 ;                           IF ( show_orig ) THEN BEGIN
 ;                              rrGIF = dprxsect_struct.redct
 ;                              ggGIF = dprxsect_struct.grnct
 ;                              bbGIF = dprxsect_struct.bluct
 ;                           ENDIF ELSE BEGIN
                               rrGIF = rr
                               ggGIF = gg
                               bbGIF = bb
 ;                           ENDELSE
                            WRITE_GIF, gif_file, TVRD(), rrGIF, ggGIF, bbGIF, $
                                       /MULTIPLE, DELAY=FIX(pause*100), REPEAT=0
                            have_gif = 1
                            print, "GIF frame done."
                            SET_PLOT, olddevice  ; reset to the previous device definition
                         ENDIF ELSE print, "Skipping empty cross section GIF frame."
                         WAIT, 0.25

                      ENDIF ELSE BEGIN     ; IF N_ELEMENTS(gif_file) EQ 1

                        ; not writing to GIF, prompt user what to do next unless
                        ; "A" mode (automatic scan) has been selected already
                         IF askagain THEN BEGIN
                            PRINT, 'Hit Return key to do next scan,'
                            PRINT, 'Enter A to step through All scans without prompt,'
                            PRINT, 'Enter B to step Back one scan,'
                            PRINT, 'Enter J to Jump forward 10 scans,'
                            READ, doodah, PROMPT='or Enter Q to Quit: '
                            CASE STRUPCASE(doodah) OF
                               'Q' : BEGIN
                                       ERASE
                                       xyouts, 20, yscomb/2, $
                                         "Cursor control is returned to PPI panels", $
                                         /DEVICE, COLOR=122, CHARSIZE=2, CHARTHICK=2
                                       GOTO, skipPlots
                                     END
                               'B' : scan2do = (scan2do-2)>(-1)
                               'J' : scan2do = (scan2do+9)<(n2do-1)
                               'A' : askAgain = 0
                              ELSE : print, "Stepping 1 DPR scan."
                            ENDCASE
                         ENDIF ELSE WAIT, pause

                      ENDELSE              ; IF N_ELEMENTS(gif_file) EQ 1

                   ENDFOR

                   IF N_ELEMENTS(gif_file) EQ 1 THEN WSET, 5
                  ; clear the multi-column window image and write message into it
                   ERASE
                   xyouts, 20, yscomb/2, "Cursor control is returned to PPI panels", $
                           /DEVICE, COLOR=122, CHARSIZE=2, CHARTHICK=2

                   IF N_ELEMENTS(gif_file) EQ 1 THEN BEGIN
                      IF have_gif THEN BEGIN
                         WRITE_GIF, /CLOSE
                         print, "GIF animation written to ", gif_file
                      ENDIF
                   ENDIF

   skipPlots:
                   WSET, 1     ; make PPI window active

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
                   print, "   animation loop of volume-match and full-resolution DPR and GR data."
                   IF KEYWORD_SET(rhi_mode) EQ 0 THEN BEGIN
                      print, " - Left click on the white square 'SC' at the lower left to step through"
                      print, "   an animation sequence of cross sections for each DPR scan in the dataset."
                   ENDIF ELSE BEGIN
                      print, " - Left click on the white square 'SC' at the lower left to step through"
                      print, "   an animation sequence of cross sections for each available radial."
                   ENDELSE
                   print, ' - Right click inside a PPI image to select another case.'
                   print, ''
                END
         ELSE : print, "Point outside DPR/", mysite.site_ID," overlap area, choose another..."
      ENDCASE
      ENDIF ELSE print, "Point outside DPR/", mysite.site_ID," overlap area, choose another..."

   ENDELSE   ; ( scanNum GT 2 AND scanNum LT 250B )
ENDWHILE     ; ( !Mouse.Button EQ 1 )

wdelete, 1
IF N_ELEMENTS(hist_window) EQ 1 THEN wdelete, hist_window
IF ( havewin2 EQ 1 ) THEN BEGIN
   IF ( show_orig ) THEN BEGIN
      WDELETE, 3
;      WDELETE, 7
   ENDIF
   WDELETE, 5
   WDELETE, 6
ENDIF

errorExit:

; free the pointers from data structure passed to loop_pr_gv_gvpolar_ppis()
if ptr_valid(ptr_gvz) then ptr_free,ptr_gvz
if ptr_valid(ptr_zcor) then ptr_free,ptr_zcor
if ptr_valid(ptr_pr_index) then ptr_free,ptr_pr_index
if ptr_valid(ptr_xCorner) then ptr_free,ptr_xCorner
if ptr_valid(ptr_yCorner) then ptr_free,ptr_yCorner
if ptr_valid(ptr_top) then ptr_free,ptr_top
if ptr_valid(ptr_botm) then ptr_free,ptr_botm

end

;===============================================================================

; MODULE #1

pro dpr_and_geo_match_x_sections, ELEV2SHOW=elev2show, SITE=sitefilter, $
                                  MATCHUP_TYPE=matchup_type, $
                                  SWATH_CMB=swath_cmb, $
                                  KUKA_CMB=KuKa_cmb, $
                                  NO_PROMPT=no_prompt, NCPATH=ncpath,   $
                                  PRPATH=prpath, UFPATH=ufpath, FLATPATH=flatpath, $
                                  SHOW_ORIG=show_orig, PCT_ABV_THRESH=pctAbvThresh, $
                                  DPR_Z_ADJUST=dpr_z_adjust, GR_Z_ADJUST=gr_z_adjust, $
                                  BBBYRAY=BBbyRay, PLOTBBSEP=plotBBsep, $
                                  BBWIDTH=bbwidth, ALT_BB_HGT=alt_bb_hgt, $
                                  HIDE_RNTYPE=hide_rntype, CREF=cref, PAUSE=pause, $
                                  ZOOMH=zoomh, LABEL_BY_RAYNUM=label_by_raynum, $
                                  RHI_MODE=rhi_mode, RAY_MODE=ray_mode_in, $
                                  CAPPI_ANIM=cappi_anim, GIF_PATH=gif_path, $
                                  DECLUTTER=declutter, VERBOSE=verbose, $
                                  RECALL_NCPATH=recall_ncpath

; "Include" file for matchup file prefixes:
@environs.inc

print
print, "##########################################$#####"
print, "#  DPR_AND_GEO_MATCH_X_SECTIONS: Version 3.1   #"
print, "#  NASA/GSFC/GPM Ground Validation, Sep. 2017  #"
print, "################################################"
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

IF ( N_ELEMENTS(matchup_type) NE 1 ) THEN BEGIN
   print, "Defaulting to DPR for matchup_type."
   pr_or_dpr = 'DPR'
ENDIF ELSE BEGIN
   CASE STRUPCASE(matchup_type) OF
;      'PR' : pr_or_dpr = 'PR'
     'DPR' : pr_or_dpr = 'DPR'
     'CMB' : pr_or_dpr = 'DPRGMI'
  'DPRGMI' : pr_or_dpr = 'DPRGMI'
      ELSE : message, "Only allowed values for MATCHUP_TYPE are DPR, and CMB or DPRGMI"
   ENDCASE
ENDELSE

IF pr_or_dpr EQ 'DPRGMI' THEN BEGIN
   IF N_ELEMENTS(swath_cmb) NE 1 THEN BEGIN
      message, "No swath type specified for DPRGMI Combined, "+ $
               "defaulting to NS from Ku.", /INFO
      swath = 'NS'
      KUKA = 'Ku'
   ENDIF ELSE BEGIN
      CASE swath_cmb OF
        'MS' : BEGIN
                 swath = swath_cmb
                 IF N_ELEMENTS(KuKa_cmb) EQ 1 THEN BEGIN
                    CASE STRUPCASE(KuKa_cmb) OF
                      'KA' : KUKA = 'Ka'
                      'KU' : KUKA = 'Ku'
                      ELSE : BEGIN
                               message, "Only allowed values for KUKA_CMB are Ka or Ku.', /INFO
                               print, "Overriding KUKA_CMB value '", KuKa_cmb, $
                                      "' to Ku for MS swath."
                             END
                    ENDCASE
                 ENDIF ELSE BEGIN
                    print, "No KUKA_CMB value, using Ku data for MS swath by default."
                    KuKa = 'Ku'
                 ENDELSE
               END
        'NS' : BEGIN
                 swath = swath_cmb
                 IF N_ELEMENTS(KuKa_cmb) EQ 1 THEN BEGIN
                    IF STRUPCASE(KuKa_cmb) NE 'KU' THEN $
                       message, "Overriding KUKA_CMB to Ku for NS swath.", /INFO
                 ENDIF ELSE print, "Using Ku data for NS swath by default."
                 KuKa = 'Ku'
               END
        ELSE : message, "Illegal SWATH_CMB value for DPRGMI, only MS or NS allowed."
      ENDCASE
   ENDELSE
ENDIF


IF ( N_ELEMENTS(sitefilter) NE 1 ) THEN BEGIN
   CASE STRUPCASE(pr_or_dpr) OF
;      'PR' : ncfilepatt = 'GRtoPR.*'
     'DPR' : ncfilepatt = 'GRtoDPR.*'
  'DPRGMI' : ncfilepatt = 'GRtoDPRGMI.*'
   ENDCASE
   print, "Defaulting to "+ncfilepatt+" for file pattern."
ENDIF ELSE BEGIN
   CASE STRUPCASE(pr_or_dpr) OF
;      'PR' : BEGIN
;               IF STRPOS(sitefilter,GEO_MATCH_PRE) NE 0 THEN $
;                  ncfilepatt = GEO_MATCH_PRE+'*'+sitefilter+'*' $   ; add GR_to_PR* prefix
;               ELSE ncfilepatt = '*'+sitefilter+'*'                 ; already have standard prefix
;             END
     'DPR' : BEGIN
               IF STRPOS(sitefilter, DPR_GEO_MATCH_PRE) NE 0 THEN $
                  ncfilepatt = DPR_GEO_MATCH_PRE+'*'+sitefilter+'*' $
               ELSE ncfilepatt = '*'+sitefilter+'*'
             END
  'DPRGMI' : BEGIN
               IF STRPOS(sitefilter, COMB_GEO_MATCH_PRE) NE 0 THEN $
                  ncfilepatt = COMB_GEO_MATCH_PRE+'*'+sitefilter+'*' $
               ELSE ncfilepatt = '*'+sitefilter+'*'
             END
   ENDCASE
ENDELSE

; Set the show_orig flag.  Default (OFF) is to plot only geo-match cross section
; data from the netCDF files. If set to 1 (ON), then look for original DPR
; 2Axxx product file and plot cross section of full-res DPR data. 
show_orig = KEYWORD_SET( show_orig )

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
   IF ( show_orig ) THEN BEGIN
      print, "Using default for DPR product file path."
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

; set or override the flag for plotting along constant DPR ray number
; -- give precedence to RHI_MODE over RAY_MODE
IF KEYWORD_SET(ray_mode_in) THEN BEGIN
   IF (rhi_mode) THEN BEGIN
      message, "Overriding RAY_MODE with RHI_MODE.", /INFO
      ray_mode=0
   ENDIF ELSE ray_mode=1
ENDIF ELSE ray_mode=0

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
         gen_dpr_and_geo_match_x_sections, ncfilepr, pr_or_dpr, show_orig, $
                        ELEV2SHOW=elev2show, PCT_ABV_THRESH=pctAbvThresh, $
                        DPR_Z_ADJUST=dpr_z_adjust, GR_Z_ADJUST=gr_z_adjust, $
                        PR_ROOT_PATH=pathpr, UFPATH=pathgv, FLATPATH=flatpath, $
                        BBBYRAY=BBbyRay, PLOTBBSEP=plotBBsep, BBWIDTH=bbwidth, $
                        ALT_BB_HGT=alt_bb_hgt, CREF=cref, $
                        RHI_MODE=rhi_mode, RAY_MODE=ray_mode, $
                        HIDE_RNTYPE=hide_rntype, PAUSE=pause, ZOOMH=zoomh, $
                        LABEL_BY_RAYNUM=label_by_raynum, CAPPI_ANIM=cappi_anim, $
                        GIF_PATH=gif_path, DECLUTTER=declutter, VERBOSE=verbose, $
                        SWATH=swath, KUKA=KuKa
      endfor
   endelse
ENDIF ELSE BEGIN
   print, ''
   print, 'Select a GRtoDPR* netCDF file from the file selector.'
   ncfilepr = dialog_pickfile(path=pathgeo, filter = ncfilepatt, $
                              Title='Select a GRtoDPR* netCDF file:')
   while ncfilepr ne '' do begin
      gen_dpr_and_geo_match_x_sections, ncfilepr, pr_or_dpr, show_orig, $
                        ELEV2SHOW=elev2show, PCT_ABV_THRESH=pctAbvThresh, $
                        DPR_Z_ADJUST=dpr_z_adjust, GR_Z_ADJUST=gr_z_adjust, $
                        PR_ROOT_PATH=pathpr, UFPATH=pathgv, FLATPATH=flatpath, $
                        BBBYRAY=BBbyRay, PLOTBBSEP=plotBBsep, BBWIDTH=bbwidth, $
                        ALT_BB_HGT=alt_bb_hgt, CREF=cref, $
                        RHI_MODE=rhi_mode, RAY_MODE=ray_mode, $
                        HIDE_RNTYPE=hide_rntype, PAUSE=pause, ZOOMH=zoomh, $
                        LABEL_BY_RAYNUM=label_by_raynum, CAPPI_ANIM=cappi_anim, $
                        GIF_PATH=gif_path, DECLUTTER=declutter, VERBOSE=verbose, $
                        SWATH=swath, KUKA=KuKa

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

