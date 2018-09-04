;===============================================================================
;+
; Copyright © 2016, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; geo_match_3d_comparisons.pro
; - Morris/SAIC/GPM_GV  January 2016
;
; DESCRIPTION
; -----------
; Performs a case-by-case statistical analysis of geometry-matched DPR and GR Z,
; Rainrate, or DSD variables from data contained in a GRtoDPR or GRtoDPRGMI
; geo-match netCDF file. Only data from the below-bright-band layer is analyzed
; for DSD.
;
; INTERNAL MODULES
; ----------------
; 1) geo_match_3d_comparisons - Main procedure called by user.  Checks
;                               input parameters and sets defaults.
;
; 2) geo_match_plots_prep - Workhorse procedure to read matchup data and call
;                           the necessary and optional routines to subset data,
;                           compute statistics; create vertical profiles, 
;                           histogram, scatter plots, and tabulations of 
;                           DPR-GR Z, RR, or DSD differences; and display DPR
;                           and GR reflectivity, rainrate, Dm, and Nw, and GR
;                           dual-pol field PPI plots in an animation sequence.
;
; 3) write_subset_to_text - See DESCRIPTION in prologue of procedure, below.
;
;
; NON-SYSTEM ROUTINES CALLED
; --------------------------
; 1) fprep_geo_match_profiles() (PR), fprep_dpr_geo_match_profiles() (DPR),
;    or fprep_dprgmi_geo_match_profiles() (DPRGMI)
; 2) select_geomatch_subarea() (optional)
; 3) render_rr_or_z_plots() (All) or render_dsd_plots() (DPR, DPRGMI only)
; 4) get_2aku_matching_footprint() (optional, DPRGMI only)
; 5) save_special_2a2b (optional, DPRGMI only)
;
;
; HISTORY
; -------
; 12/30/16 Morris, GPM GV, SAIC
; - Created from merger of geo_match_3d_rr_or_z_comparisons.pro and
;   geo_match_3d_dsd_comparisons.pro.  See their individual histories.
; 01/24/17 Morris, GPM GV, SAIC
; - Made modifications needed to overcome errors in analyzing PR matchup data
;   in merged routine.
; - Added NCFILELIST=ncfilelist keyword/parameter and logic to allow only
;   matchup files listed in an input file to be processed in a sequence.
; 03/24/17 Morris, GPM GV, SAIC
; - Added LAND_OCEAN=land_ocean keyword/value pair to filter analyzed samples by
;   underlying surface type.
; - Added check for attempts to analyze RR for the 2A-DPR MS scan type that does
;   not contain an RR field.
;
;
; EMAIL QUESTIONS OR COMMENTS AT:
;       https://pmm.nasa.gov/contact
;-
;===============================================================================
;
; MODULE 3:  write_subset_to_text
;
; DESCRIPTION
; -----------
; After a storm subset of data have been selected, takes subsetted arrays of the
; data and the 1-D indices of samples used in computation and display of the
; storm statistics, extracts the data values of these samples, and writes the
; values to a new text file whose pathname is provided as the TXTFILE parameter.
; Variables included in the output are latitude, longitude, and top and bottom
; height; DPR Z, Dm, and Nw; GR Z, Zdr, D0 or Dm, and Nw or N2.

pro write_subset_to_text, TXTFILE, data, idx_used

OPENW, txtunit, TXTFILE, /GET_LUN

; print the header
Dm0 = data.GR_DM_D0   ; for labeling GR D0/Dm variable used
Nw2 = data.GR_NW_N2   ; for labeling GR Nw/N2 variable used
printf, txtunit, $
        "  range_km  latitude longitude   top_hgt  botm_hgt   DPR_dBZ    GR_dBZ" + $
        "    DPR_Dm     GR_" + Dm0 + "    DPR_Nw     GR_" + Nw2 + "    GR_Zdr"
print, "  range_km  latitude longitude   top_hgt  botm_hgt   DPR_dBZ    GR_dBZ" + $
       "    DPR_Dm     GR_" + Dm0 + "    DPR_Nw     GR_" + Nw2 + "    GR_Zdr"

; print the data
fmtstr = "'(F10.3)'"
for i = 0, N_ELEMENTS(idx_used)-1 do begin
   ix = idx_used[i]
   printf, txtunit, $
           data.dist[ix], data.lat[ix], data.lon[ix], data.top[ix], data.botm[ix], $
           data.zcor[ix], data.gvz[ix], data.dpr_Dm[ix], data.Dzero[ix], $
           data.dpr_nw[ix], data.gr_dp_nw[ix], data.Zdr[ix], FORMAT='(11(" ",F9.3))'
   print, data.dist[ix], data.lat[ix], data.lon[ix], data.top[ix], data.botm[ix], $
          data.zcor[ix], data.gvz[ix], data.dpr_Dm[ix], data.Dzero[ix], $
          data.dpr_nw[ix], data.gr_dp_nw[ix], data.Zdr[ix], FORMAT='(12(" ",F9.3))'
endfor

FREE_LUN, txtunit    ; close the temp file for writing
end

;===============================================================================
;
; MODULE 2:  geo_match_plots_prep
;
; DESCRIPTION
; -----------
; Reads PR, DPR, or DPRGMI and GR Z, RR, Dm, Nw, other GR dual-polarization data
; and spatial fields from a user-selected geometry match netCDF file,
; builds index arrays of categories of range, rain type, bright band proximity
; (above, below, within), and an array of actual range. Depending on the data
; type 'xxx' to be analyzed (Z, RR, or DSD), calls either render_rr_or_z_plots()
; or render_dsd_plots() to compute statistics and produce profiles, histograms,
; scatter plots, and PPI displays of the data. Optionally calls the function
; select_geomatch_subarea() to allow the user to define a "storm subset" of
; the data to display and analyze.  If analyzing a subset of data and a value
; is given for the SAVE_DIR parameter, then the user will be prompted whether to
; save the subset data and other mandatory parameters to render_rr_or_z_plots()
; or render_dsd_plots() in an IDL binary SAVE file.  If analyzing DPRGMI data
; and SAVE_BY_RAY is set in addition to SAVE_DIR being defined, then the
; routines get_2aku_matching_footprint() and save_special_2a2b are optionally
; called, if user selects to proceed, to get additional variables from the
; original 2AKu file for the case and save a non-default set of variables to
; the binary SAVE file.

FUNCTION geo_match_plots_prep, ncfilepr, xxx, looprate, elevs2show, startelev, $
                               PPIorient, windowsize, pctabvthresh, PPIbyThresh, $
                               Z_PPIs, gvconvective, gvstratiform, hideTotals, $
                               hide_rntype, hidePPIs, pr_or_dpr, $
                               SWATH=swath_in, KUKA=KuKa_in, PS_DIR=ps_dir, $
                               S2KU=s2ku, ZR=zr_force, FORCEBB=forcebb_in, $
                               ALT_BB_HGT=alt_bb_hgt, DZEROFAC=dzerofac, $
                               DPR_Z_ADJUST=dpr_z_adjust, SITEBIASHASH=siteBiasHash, $
                               GR_RR_FIELD=gr_rr_field, GR_DM_FIELD=gr_dm_field, $
                               GR_NW_FIELD=gr_nw_field, B_W=b_w, BATCH=batch, $
                               MAX_RANGE=max_range, MAX_BLOCKAGE=max_blockage, $
                               Z_BLOCKAGE_THRESH=z_blockage_thresh, $
                               SUBSET_METHOD=submeth, MIN_FOR_SUBSET=subthresh, $
                               SAVE_DIR=save_dir, SAVE_BY_RAY=save_by_ray_in, $
                               STEP_MANUAL=step_manual, DECLUTTER=declutter_in, $
                               LAND_OCEAN=land_ocean

; "include" file for read_geo_match_netcdf() structs returned
@geo_match_nc_structs.inc

; "include" file for PR data constants
@pr_params.inc

declutter=KEYWORD_SET(declutter_in)
IF (pr_or_dpr NE 'DPR') THEN declutter=0     ; override unless processing DPR
forcebb=KEYWORD_SET(forcebb_in)
IF N_ELEMENTS( siteBiasHash ) GT 0 THEN adjust_grz = 1 ELSE adjust_grz = 0
IF N_ELEMENTS( dpr_z_adjust ) EQ 1 THEN adjust_dprz = 1 ELSE adjust_dprz = 0
save_by_ray = 0  ; only override this if analyzing DPRGMI and SAVE_BY_RAY is set

bname = file_basename( ncfilepr )
prlen = strlen( bname )
pctString = STRTRIM(STRING(FIX(pctabvthresh)),2)
parsed = STRSPLIT( bname, '.', /extract )
site = parsed[1]
yymmdd = parsed[2]
orbit = parsed[3]
version = parsed[4]

CASE pr_or_dpr OF
     'DPR' : BEGIN
               swath=parsed[6]
              ; 3-d rainrate not present in 2ADPR/MS, fail if RR analysis requested
               KuKa=parsed[5]
               instrument='_2A'+KuKa    ; label used in SAVE file names
               matchup_ver_str=parsed[7]
               IF KuKa EQ 'DPR' AND swath EQ 'MS' AND xxx EQ 'RR' THEN BEGIN
                  message, 'No 2A-DPR RR data for MS scan type, exiting.', /INFO
                  status = 2
                  goto, errorExit
               ENDIF
             END
      'PR' : BEGIN
               swath='NS'
               instrument='_'
               KuKa='Ku'
              ; leave this here for now, expect PR V08x version labels soon, though
               CASE version OF
                    '6' : version = 'V6'
                    '7' : version = 'V7'
                   ELSE : print, "Using PR version = ", version
               ENDCASE
               matchup_ver_str=parsed[5]
             END
  'DPRGMI' : BEGIN
               swath=swath_in
               KuKa=KuKa_in
               instrument='_'+KuKa
               matchup_ver_str=parsed[5]
               save_by_ray = KEYWORD_SET(save_by_ray_in)
             END
ENDCASE

; convert matchup_ver_str in the form N_n into floating N.n
parsedver = STRSPLIT( matchup_ver_str, '_', /extract )
IF N_ELEMENTS(parsedver) EQ 2 THEN BEGIN
   matchup_ver = FLOAT(parsedver[0]+'.'+parsedver[1])
ENDIF ELSE BEGIN
   matchup_ver = 0.0
   message, "Can't format matchup version from filename field " $
            + matchup_ver_str + ', filename ' + bname, /INFO
ENDELSE

; set up pointers for each field to be returned from fprep_geo_match_profiles()
ptr_geometa=ptr_new(/allocate_heap)
ptr_sweepmeta=ptr_new(/allocate_heap)
ptr_sitemeta=ptr_new(/allocate_heap)
ptr_fieldflags=ptr_new(/allocate_heap)
ptr_gvz=ptr_new(/allocate_heap)

; define pointer for GR rain rate only if not using Z-R rainrate
IF KEYWORD_SET(zr_force) EQ 0 THEN BEGIN
   IF pr_or_dpr EQ 'DPR' THEN BEGIN
      ; only define the pointer specific to the rain rate field to be used
      CASE gr_rr_field OF
         'RC' : BEGIN
                   ptr_gvrc=ptr_new(/allocate_heap)
                   ptr_pctgoodrcgv=ptr_new(/allocate_heap)
                END
         'RP' : BEGIN
                   ptr_gvrp=ptr_new(/allocate_heap)
                   ptr_pctgoodrpgv=ptr_new(/allocate_heap)
                END
         'RR' : BEGIN
                   ptr_gvrr=ptr_new(/allocate_heap)
                   ptr_pctgoodrrgv=ptr_new(/allocate_heap)
                END
         ELSE : BEGIN
                   ptr_gvrr=ptr_new(/allocate_heap)
                   ptr_pctgoodrrgv=ptr_new(/allocate_heap)
                END
      ENDCASE
   ENDIF ELSE BEGIN
      ptr_gvrr=ptr_new(/allocate_heap)     ; new for Version 2.2 PR matchup
      ptr_pctgoodrrgv=ptr_new(/allocate_heap)
   ENDELSE
ENDIF

ptr_BestHID=ptr_new(/allocate_heap)       ; new for Version 2.3 GRtoPR matchup file
ptr_GR_DP_Dzero=ptr_new(/allocate_heap)   ; new for Version 2.3 matchup file
ptr_GR_DP_Zdr=ptr_new(/allocate_heap)     ; new for Version 2.3 matchup file
ptr_GR_DP_Kdp=ptr_new(/allocate_heap)     ; new for Version 2.3 matchup file
ptr_GR_DP_RHOhv=ptr_new(/allocate_heap)   ; new for Version 2.3 matchup file
ptr_zcor=ptr_new(/allocate_heap)
ptr_zraw=ptr_new(/allocate_heap)
ptr_rain3=ptr_new(/allocate_heap)
IF ( pr_or_dpr NE 'PR' ) THEN BEGIN
  ; only DPR or DPRGMI matchups provide Dm and Nw for satellite and ground radar
   ptr_GR_DP_Nw=ptr_new(/allocate_heap)      ; new for Version 2.3 matchup file
   ptr_dprdm=ptr_new(/allocate_heap)
   ptr_dprnw=ptr_new(/allocate_heap)
  ; define the pointers for, and try to read, the 2nd GR Dm and Nw fields, and
  ; the GR beam blockage field
   ptr_GR_DP_Dm=ptr_new(/allocate_heap)      ; new for Version 1.2 GRtoDPR matchup file
   ptr_GR_DP_N2=ptr_new(/allocate_heap)      ; ditto
   ptr_GR_blockage=ptr_new(/allocate_heap)
   ptr_pctgoodDprDm=ptr_new(/allocate_heap)
   ptr_pctgoodDprNw=ptr_new(/allocate_heap)
   IF KEYWORD_SET(declutter) THEN ptr_clutterStatus=ptr_new(/allocate_heap)
ENDIF
ptr_top=ptr_new(/allocate_heap)
ptr_botm=ptr_new(/allocate_heap)
ptr_lat=ptr_new(/allocate_heap)
ptr_lon=ptr_new(/allocate_heap)
ptr_pia=ptr_new(/allocate_heap)
ptr_nearSurfRain=ptr_new(/allocate_heap)
ptr_nearSurfRain_Comb=ptr_new(/allocate_heap)
; TAB 10/3/17
ptr_mrmsrrlow=ptr_new(/allocate_heap)
ptr_mrmsrrmed=ptr_new(/allocate_heap)
ptr_mrmsrrhigh=ptr_new(/allocate_heap)
ptr_mrmsrrveryhigh=ptr_new(/allocate_heap)
ptr_swerr1=ptr_new(/allocate_heap)
ptr_rnFlag=ptr_new(/allocate_heap)
ptr_rnType=ptr_new(/allocate_heap)
ptr_landOcean=ptr_new(/allocate_heap)
ptr_pr_index=ptr_new(/allocate_heap)
ptr_xCorner=ptr_new(/allocate_heap)
ptr_yCorner=ptr_new(/allocate_heap)
ptr_bbProx=ptr_new(/allocate_heap)
ptr_hgtcat=ptr_new(/allocate_heap)
ptr_dist=ptr_new(/allocate_heap)
ptr_pctgoodpr=ptr_new(/allocate_heap)
ptr_pctgoodgv=ptr_new(/allocate_heap)
ptr_pctgoodrain=ptr_new(/allocate_heap)

; structure to hold bright band variables
BBparms = {meanBB : -99.99, BB_HgtLo : -99, BB_HgtHi : -99}

; Define the list of fixed-height levels for the vertical profile statistics
IF xxx EQ 'DSD' THEN BEGIN
   heights = [1.,2.,3.,4.,5.,6.,7.,8.]
   hgtinterval = 1.0
ENDIF ELSE BEGIN
   ;heights = [1.5,3.0,4.5,6.0,7.5,9.0,10.5,12.0,13.5,15.0,16.5,18.0,19.5]
   ;hgtinterval = 1.5
   heights = [1.0,2.0,3.0,4.0,5.0,6.0,7.0,8.0,9.0,10.0,11.0,12.0,13.0,14.0,15.0,16.0,17.0,18.0]
   hgtinterval = 1.0
ENDELSE

print, 'pctAbvThresh = ', pctAbvThresh

; read the geometry-match variables and arrays from the file, and preprocess them
; to remove the 'bogus' PR ray positions.  Return a pointer to each variable read.

CASE pr_or_dpr OF
  'PR' : BEGIN
    PRINT, "INSTRUMENT: ", pr_or_dpr
    status = fprep_geo_match_profiles( ncfilepr, heights, $
    PCT_ABV_THRESH=pctAbvThresh, S2KU=s2ku, PTRfieldflags=ptr_fieldflags, $
    PTRgeometa=ptr_geometa, PTRsweepmeta=ptr_sweepmeta, PTRsitemeta=ptr_sitemeta, $
    PTRGVZMEAN=ptr_gvz, PTRzcor=ptr_zcor, PTRzraw=ptr_zraw, PTRrain3d=ptr_rain3, $
    PTRGVRRMEAN=ptr_gvrr, PTRGVMODEHID=ptr_BestHID, PTRGVDZEROMEAN=ptr_GR_DP_Dzero, $
    PTRGVZDRMEAN=ptr_GR_DP_Zdr, PTRGVKDPMEAN=ptr_GR_DP_Kdp, PTRGVRHOHVMEAN=ptr_GR_DP_RHOhv, $
    PTRtop=ptr_top, PTRbotm=ptr_botm, PTRlat=ptr_lat, PTRlon=ptr_lon, PTRpia=ptr_pia, $
    PTRsfcrainpr=ptr_nearSurfRain, PTRsfcraincomb=ptr_nearSurfRain_Comb, $
    PTRrainflag_int=ptr_rnFlag, PTRraintype_int=ptr_rnType, $
    PTRlandOcean_int=ptr_landOcean, $
    PTRxCorners=ptr_xCorner, PTRyCorners=ptr_yCorner, PTRbbProx=ptr_bbProx, $
    PTRhgtcat=ptr_hgtcat, PTRdist=ptr_dist, PTRpridx_long=ptr_pr_index, $
    PTRpctgoodpr=ptr_pctgoodpr, PTRpctgoodgv=ptr_pctgoodgv, $
    PTRpctgoodrain=ptr_pctgoodrain, PTRpctgoodrrgv=ptr_pctgoodrrgv, BBPARMS=BBparms, $
    ALT_BB_HGT=alt_bb_hgt )
 END
  'DPR' : BEGIN
    PRINT, "INSTRUMENT: ", pr_or_dpr
    ; TAB 10/2/17
    status = fprep_dpr_geo_match_profiles_mrms( ncfilepr, heights, $
    PCT_ABV_THRESH=pctAbvThresh, S2KU=s2ku, PTRfieldflags=ptr_fieldflags, $
    PTRgeometa=ptr_geometa, PTRsweepmeta=ptr_sweepmeta, PTRsitemeta=ptr_sitemeta, $
    PTRGVZMEAN=ptr_gvz, PTRzcor=ptr_zcor, PTRzraw=ptr_zraw, PTRrain3d=ptr_rain3, $
    PTRdprdm=ptr_dprDm, PTRdprnw=ptr_dprNw, PTRGVNWMEAN=ptr_GR_DP_Nw, $
    PTRGVRRMEAN=ptr_gvrr, PTRGVRCMEAN=ptr_gvrc, PTRGVRPMEAN=ptr_gvrp, $
    PTRGVMODEHID=ptr_BestHID, PTRGVDZEROMEAN=ptr_GR_DP_Dzero, $
    PTRGVDMMEAN=ptr_GR_DP_Dm, PTRGVN2MEAN=ptr_GR_DP_N2, $
    PTRGVZDRMEAN=ptr_GR_DP_Zdr, PTRGVKDPMEAN=ptr_GR_DP_Kdp, PTRGVRHOHVMEAN=ptr_GR_DP_RHOhv, $
    PTRGVBLOCKAGE=ptr_GR_blockage, $
    PTRtop=ptr_top, PTRbotm=ptr_botm, PTRlat=ptr_lat, PTRlon=ptr_lon, PTRpia=ptr_pia, $
    PTRsfcrainpr=ptr_nearSurfRain, PTRsfcraincomb=ptr_nearSurfRain_Comb, $
    PTRrainflag_int=ptr_rnFlag, PTRraintype_int=ptr_rnType, $
    PTRlandOcean_int=ptr_landOcean, $
    PTRxCorners=ptr_xCorner, PTRyCorners=ptr_yCorner, PTRbbProx=ptr_bbProx, $
    PTRhgtcat=ptr_hgtcat, PTRdist=ptr_dist, PTRpridx_long=ptr_pr_index, $
    PTRpctgoodpr=ptr_pctgoodpr, PTRpctgoodgv=ptr_pctgoodgv, $
    PTRpctgoodrain=ptr_pctgoodrain, PTRpctgoodrcgv=ptr_pctgoodrcgv, $
    PTRpctgoodrpgv=ptr_pctgoodrpgv, PTRpctgoodrrgv=ptr_pctgoodrrgv, $
    PTRpctgoodDprDm=ptr_pctgoodDprDm, PTRpctgoodDprNw=ptr_pctgoodDprNw, $
    PTRclutterStatus=ptr_clutterStatus, BBPARMS=BBparms, $
    ; TAB 10/2/17
    ; MRMS radar variables
    PTRmrmsrrlow=ptr_mrmsrrlow, $
    PTRmrmsrrmed=ptr_mrmsrrmed, $
    PTRmrmsrrhigh=ptr_mrmsrrhigh, $
    PTRmrmsrrveryhigh=ptr_mrmsrrveryhigh, $
    ; TAB 9/4/18
    ; SWERR varaibles
    PTRswerr1=ptr_swerr1, $
    ALT_BB_HGT=alt_bb_hgt, FORCEBB=forcebb )
 END
  'DPRGMI' : BEGIN
    PRINT, "INSTRUMENT: ", pr_or_dpr
    status = fprep_dprgmi_geo_match_profiles( ncfilepr, heights, $
    KUKA=KuKa, SCANTYPE=swath, PCT_ABV_THRESH=pctAbvThresh, S2KU=s2ku, $
    PTRfieldflags=ptr_fieldflags, PTRgeometa=ptr_geometa, $
    PTRsweepmeta=ptr_sweepmeta, PTRsitemeta=ptr_sitemeta, $
    PTRGVZMEAN=ptr_gvz, PTRzcor=ptr_zcor, PTRrain3d=ptr_rain3, $
    PTRdprdm=ptr_dprDm, PTRdprnw=ptr_dprNw, PTRGVNWMEAN=ptr_GR_DP_Nw, $
    PTRGVRRMEAN=ptr_gvrr, PTRGVRCMEAN=ptr_gvrc, PTRGVRPMEAN=ptr_gvrp, $
    PTRGVMODEHID=ptr_BestHID, PTRGVDZEROMEAN=ptr_GR_DP_Dzero, $
    PTRGVDMMEAN=ptr_GR_DP_Dm, PTRGVN2MEAN=ptr_GR_DP_N2, $
    PTRGVZDRMEAN=ptr_GR_DP_Zdr, PTRGVKDPMEAN=ptr_GR_DP_Kdp, PTRGVRHOHVMEAN=ptr_GR_DP_RHOhv, $
    PTRGVBLOCKAGE=ptr_GR_blockage, $
    PTRtop=ptr_top, PTRbotm=ptr_botm, PTRlat=ptr_lat, PTRlon=ptr_lon, PTRpia=ptr_pia, $
    PTRsfcrainpr=ptr_nearSurfRain, PTRraintype_int=ptr_rnType, $
    PTRlandOcean_int=ptr_landOcean, $
    PTRxCorners=ptr_xCorner, PTRyCorners=ptr_yCorner, PTRbbProx=ptr_bbProx, $
    PTRhgtcat=ptr_hgtcat, PTRdist=ptr_dist, PTRpridx_long=ptr_pr_index, $
    PTRpctgoodpr=ptr_pctgoodpr, PTRpctgoodgv=ptr_pctgoodgv, $
    PTRpctgoodrain=ptr_pctgoodrain, PTRpctgoodrcgv=ptr_pctgoodrcgv, $
    PTRpctgoodrpgv=ptr_pctgoodrpgv, PTRpctgoodrrgv=ptr_pctgoodrrgv, $
    PTRpctgoodDprDm=ptr_pctgoodDprDm, PTRpctgoodDprNw=ptr_pctgoodDprNw, $
    PTRclutterStatus=ptr_clutterStatus, BBPARMS=BBparms, $
    ALT_BB_HGT=alt_bb_hgt, FORCEBB=forcebb )
 END
ENDCASE

IF (status EQ 1) THEN BEGIN
   status=0          ; set up to do another case rather than exiting
   GOTO, errorExit
ENDIF

; create local data field arrays/structures needed here, and free pointers we
; no longer need to free the memory held by these pointer variables
; - Yes, we blindly assume most of these pointers and their data are defined
;   and valid, unless there is logic to test them (variables added in later
;   matchup file versions).

  mygeometa=*ptr_geometa
    ptr_free,ptr_geometa
;HELP, MYGEOMETA, /struct
  mysite=*ptr_sitemeta
    ptr_free,ptr_sitemeta
  mysweeps=*ptr_sweepmeta
    ptr_free,ptr_sweepmeta
  myflags=*ptr_fieldflags
    ptr_free,ptr_fieldflags
  gvz=*ptr_gvz
    ptr_free,ptr_gvz
  IF pr_or_dpr EQ 'DPRGMI' THEN BEGIN
     zraw=*ptr_zcor    ; make copy of Zcorrected so that zraw is defined
  ENDIF ELSE BEGIN
     zraw=*ptr_zraw
       ptr_free,ptr_zraw
  ENDELSE
  zcor=*ptr_zcor
    ptr_free,ptr_zcor

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
      ENDIF ELSE print, "Ignoring negligible DPR Z bias value."
   ENDIF

;-------------------------------------------------------------

  gvz_in = gvz     ; for plotting as PPI
  zcor_in = zcor   ; for plotting as PPI
  zraw_in = zraw   ; for plotting as PPI
    ptr_free,ptr_zcor
  rain3=*ptr_rain3
  rain3_in = rain3 ; for plotting as PPI
    ptr_free,ptr_rain3
  have_pia=0
  IF ptr_valid(ptr_pia) THEN BEGIN
     pia=*ptr_pia
     ptr_free,ptr_pia
     IF pr_or_dpr EQ 'DPR' THEN have_pia=myflags.have_piaFinal $
     ELSE have_pia=myflags.have_pia
  ENDIF ELSE pia = -1

  haveDm = 0
  IF ptr_valid(ptr_dprDm) THEN BEGIN
     dpr_dm=*ptr_dprDm
     dpr_dm_in=dpr_dm         ; 2nd copy, left untrimmed for PPI plots
     haveDm = 1
     ptr_free,ptr_dprDm
  ENDIF ELSE message, "No Dm field for DPR in netCDF file.", /INFO
  haveNw = 0
  IF ptr_valid(ptr_dprNw) THEN BEGIN
     IF pr_or_dpr NE 'DPRGMI' THEN BEGIN
       ; Convert DPR Nw from dBNw to log10(Nw).
        dpr_nw=*ptr_dprNw/10.    ; dBNw -> log10(Nw)
     ENDIF ELSE BEGIN
       ; DPRGMI Nw was already converted in fprep_dprgmi_geo_match_profiles()
       ; to GR Nw units of log10(Nw), with Nw in 1/m^3-mm, so use as-is
        dpr_nw=*ptr_dprNw
     ENDELSE
     dpr_nw_in=dpr_nw         ; 2nd copy, left untrimmed for PPI plots
     haveNw = 1
     ptr_free,ptr_dprNw
  ENDIF ELSE message, "No Nw field for DPR in netCDF file.", /INFO
; TAB 10/3/17
  havenearsurfrain = 0
  IF ptr_valid(ptr_nearsurfrain) THEN BEGIN
     nearsurfrain=*ptr_nearsurfrain
     havenearsurfrain = 1
     ptr_free,ptr_nearsurfrain
  ENDIF ELSE message, "No near surface RR field in netCDF file.", /INFO
  havemrms = 0
  IF ptr_valid(ptr_mrmsrrveryhigh) THEN BEGIN
     mrmsrr=*ptr_mrmsrrveryhigh
     havemrms = 1
     ptr_free,ptr_mrmsrrveryhigh
  ENDIF ELSE message, "No MRMS RR field in netCDF file.", /INFO
  haveswerr1 = 0
  IF ptr_valid(ptr_swerr1) THEN BEGIN
     swerr1=*ptr_swerr1
     haveswerr1 = 1
     ptr_free,ptr_swerr1
  ENDIF ELSE message, "No MRMS RR field in netCDF file.", /INFO
   ; initialize flag as to source of GR rain rate to use to "compute Z-R"
   have_gvrr = 0
   gvrr = -1
   pctgoodrrgv = -1
   rr_field_used = 'Z-R'

   IF pr_or_dpr NE 'PR' THEN BEGIN
      CASE gr_rr_field OF
         'RC' : IF ptr_valid(ptr_gvrc) THEN BEGIN
                  gvrr=*ptr_gvrc
                  gvrr_in = gvrr
                  ptr_free,ptr_gvrc
                  have_gvrr=myflags.have_GR_RC_rainrate
                  IF ptr_valid(ptr_pctgoodrcgv) THEN pctgoodrrgv=*ptr_pctgoodrcgv
                  rr_field_used = 'RC'
                ENDIF
         'RP' : IF ptr_valid(ptr_gvrp) THEN BEGIN
                  gvrr=*ptr_gvrp
                  gvrr_in = gvrr
                  ptr_free,ptr_gvrp
                  have_gvrr=myflags.have_GR_RP_rainrate
                  IF ptr_valid(ptr_pctgoodrpgv) THEN pctgoodrrgv=*ptr_pctgoodrpgv
                  rr_field_used = 'RP'
               ENDIF
         ELSE : IF ptr_valid(ptr_gvrr) THEN BEGIN
                  gvrr=*ptr_gvrr
                  gvrr_in = gvrr
                  ptr_free,ptr_gvrr
                  have_gvrr=myflags.have_GR_RR_rainrate
                  IF ptr_valid(ptr_pctgoodrrgv) THEN pctgoodrrgv=*ptr_pctgoodrrgv
                  rr_field_used = 'RR'
                ENDIF
      ENDCASE
   ENDIF ELSE BEGIN
     IF ptr_valid(ptr_gvrr) THEN BEGIN
        gvrr=*ptr_gvrr
        gvrr_in = gvrr ; for plotting as PPI
        ptr_free,ptr_gvrr
        have_gvrr=myflags.have_GR_rainrate   ; should just be 0 for version<2.2
        IF ptr_valid(ptr_pctgoodrrgv) THEN pctgoodrrgv=*ptr_pctgoodrrgv
        rr_field_used = 'RR'
     ENDIF
    ; define placeholders for DSD variables included in dataStruc
     dpr_dm = -1
     dpr_nw = -1
     gr_dp_nw = -1       ; data variable
     GR_NW_N2 = "N/A"    ; UF ID of gr_dp_nw
     pctgoodDprDm = -1
     pctgoodDprNw = -1
   ENDELSE

  haveHID = 0                          ; first check myflags values for all these?
  IF ptr_valid(ptr_BestHID) THEN BEGIN
     HIDcat=*ptr_BestHID
     haveHID = 1
     ptr_free,ptr_BestHID
  ENDIF ELSE HIDcat=-1

  haveD0 = 0
  Dzero = -1 & Dzero_in = -1    ; define something
  ; use Dm/D0 field specified by gr_dm_field parameter, as available
  ; -- calling program has made sure gr_dm_field parameter is defined
  ; -- if GR DM field is not available, then ptr_GR_DP_DM will point to NULL
  IF (gr_dm_field EQ 'DM') AND ptr_valid(ptr_GR_DP_DM) THEN BEGIN
    Dzero=*ptr_GR_DP_Dm     ; assign to Dzero variable, even if it's Dm
    Dzero_in=*ptr_GR_DP_Dm  ; 2nd copy, left untrimmed for PPI plots
    haveD0 = 1
    GR_DM_D0 = 'Dm'
    ptr_free,ptr_GR_DP_Dm
    IF ptr_valid(ptr_GR_DP_Dzero) THEN ptr_free,ptr_GR_DP_Dzero  ; not using field
  ENDIF ELSE BEGIN
    IF ptr_valid(ptr_GR_DP_Dzero) THEN BEGIN
       IF (gr_dm_field EQ 'DM') THEN $
          message, "Substituting D0 for unavailable DM field.", /INFO
       Dzero=*ptr_GR_DP_Dzero
       Dzero_in=*ptr_GR_DP_Dzero  ; 2nd copy, left untrimmed for PPI plots
       haveD0 = 1
       ptr_free,ptr_GR_DP_Dzero
       IF N_ELEMENTS( dzerofac ) EQ 1 THEN BEGIN
;          message,  'Adjusting GR Dzero field by factor of '+STRING(dzerofac, $
;                    FORMAT='(F0.0)'), /INFO
          GR_DM_D0 = 'D0'
          idx2adj = WHERE(Dzero GT 0.0, count2adj)
          IF count2adj GT 0 THEN BEGIN
             adjdzero = Dzero[idx2adj] * dzerofac
             Dzero[idx2adj] = adjdzero
             Dzero_in[idx2adj] = adjdzero
          ENDIF
       ENDIF ELSE BEGIN
          message,  'Leaving GR Dzero field as-is.', /INFO
          GR_DM_D0 = 'D0'
       ENDELSE
    ENDIF ELSE message, "No Dzero field for GR in netCDF file.", /INFO
    IF ptr_valid(ptr_GR_DP_Dm) THEN ptr_free,ptr_GR_DP_Dm  ; not using field
  ENDELSE

  haveGR_Nw = 0
  gr_dp_nw = -1 & gr_dp_nw_in = -1
  ; use NW/N2 field specified by gr_nw_field parameter, as available
  ; -- calling program has made sure gr_nw_field parameter is defined
  ; -- if GR N2 field is not available, then ptr_GR_DP_N2 will point to NULL
  IF (gr_nw_field EQ 'N2') AND ptr_valid(ptr_GR_DP_N2) THEN BEGIN
    gr_dp_nw=*ptr_GR_DP_N2
    gr_dp_nw_in=*ptr_GR_DP_N2  ; 2nd copy, left untrimmed for PPI plots
    haveGR_Nw = 1
    GR_NW_N2 = 'N2'
    ptr_free,ptr_GR_DP_N2
    IF ptr_valid(ptr_GR_DP_Nw) THEN ptr_free,ptr_GR_DP_Nw  ; not using field
  ENDIF ELSE BEGIN
    IF ptr_valid(ptr_GR_DP_Nw) THEN BEGIN
       gr_dp_nw=*ptr_GR_DP_Nw
       gr_dp_nw_in=*ptr_GR_DP_Nw  ; 2nd copy, left untrimmed for PPI plots
       haveGR_Nw = 1
       GR_NW_N2 = 'NW'
       ptr_free,ptr_GR_DP_Nw
    ENDIF ELSE message, "No Nw field for GR in netCDF file.", /INFO
    IF ptr_valid(ptr_GR_DP_N2) THEN ptr_free,ptr_GR_DP_N2  ; not using field
  ENDELSE

  haveZdr = 0
  IF ptr_valid(ptr_GR_DP_Zdr) THEN BEGIN
     Zdr=*ptr_GR_DP_Zdr
     haveZdr = 1
     ptr_free,ptr_GR_DP_Zdr
  ENDIF ELSE Zdr=-1

  haveKdp = 0
  IF ptr_valid(ptr_GR_DP_Kdp) THEN BEGIN
     Kdp=*ptr_GR_DP_Kdp
     haveKdp = 1
     ptr_free,ptr_GR_DP_Kdp
  ENDIF ELSE Kdp=-1

  haveRHOhv = 0
  IF ptr_valid(ptr_GR_DP_RHOhv) THEN BEGIN
     RHOhv=*ptr_GR_DP_RHOhv
     haveRHOhv = 1
     ptr_free,ptr_GR_DP_RHOhv
  ENDIF ELSE RHOhv=-1
 
  have_GR_blockage = 0
  IF pr_or_dpr EQ 'DPR' AND ptr_valid(ptr_GR_blockage) THEN BEGIN
     have_GR_blockage=myflags.have_GR_blockage   ; should just be 0 for version<1.21
     GR_blockage=*ptr_GR_blockage
     ptr_free, ptr_GR_blockage
  ENDIF ELSE GR_blockage = -1

  top=*ptr_top
  botm=*ptr_botm
  lat=*ptr_lat
  lon=*ptr_lon
 ; just passing rnflag as rnType if DPRGMI, since we don't have that variable
 ; in that matchup product.  It's not used (as far as I can tell) so no big deal
  IF pr_or_dpr NE 'DPRGMI' THEN rnflag=*ptr_rnFlag ELSE  rnflag=*ptr_rnType
  rntype=*ptr_rnType
  landOcean=*ptr_landOcean
 ; convert landOcean values taken from DPR landSurfaceType from their 3-digit
 ; categories to a 1-digit category, except for Missing=-9999
  idx2conv = WHERE(landOcean GE 0, count2conv)
  IF count2conv GT 0 THEN BEGIN
     tempLO = landOcean[idx2conv]/100
     landOcean[temporary(idx2conv)] = temporary(tempLO)
  ENDIF
  pr_index=*ptr_pr_index
  xcorner=*ptr_xCorner
  ycorner=*ptr_yCorner
  bbProx=*ptr_bbProx
  dist=*ptr_dist
  hgtcat=*ptr_hgtcat
  pctgoodpr=*ptr_pctgoodpr
  pctgoodgv=*ptr_pctgoodgv
  pctgoodrain=*ptr_pctgoodrain
  if PTR_VALID(ptr_pctgoodDprDm) THEN BEGIN
     pctgoodDprDm=*ptr_pctgoodDprDm
     ptr_free,ptr_pctgoodDprDm
  endif
  if PTR_VALID(ptr_pctgoodDprNw) THEN BEGIN
     pctgoodDprNw=*ptr_pctgoodDprNw
     ptr_free,ptr_pctgoodDprNw
  endif
    ptr_free,ptr_top
    ptr_free,ptr_botm
    ptr_free,ptr_lat
    ptr_free,ptr_lon
    ptr_free,ptr_nearSurfRain
    ptr_free,ptr_nearSurfRain_Comb
; TAB 10/3/17
    ptr_free,ptr_mrmsrrlow
    ptr_free,ptr_mrmsrrmed
    ptr_free,ptr_mrmsrrhigh
    ptr_free,ptr_mrmsrrveryhigh
    ptr_free,ptr_swerr1    
    ptr_free,ptr_rnFlag
    ptr_free,ptr_rnType
    ptr_free,ptr_pr_index
    ptr_free,ptr_xCorner
    ptr_free,ptr_yCorner
    ptr_free,ptr_bbProx
    ptr_free,ptr_hgtcat
    ptr_free,ptr_dist
    ptr_free,ptr_pctgoodpr
    ptr_free,ptr_pctgoodgv
    ptr_free,ptr_pctgoodrain
  IF pr_or_dpr EQ 'DPR' AND KEYWORD_SET(declutter) THEN BEGIN
     clutterStatus=*ptr_clutterStatus
     ptr_free,ptr_clutterStatus
  ENDIF ELSE clutterStatus=0      ; just assign anything so it is defined
;  IF ptr_valid(ptr_pctgoodrrgv) THEN BEGIN
;     pctgoodrrgv=*ptr_pctgoodrrgv
;     ptr_free,ptr_pctgoodrrgv
;  ENDIF

; now that the pointers are freed, make sure we have all our Dm and Nw fields
IF pr_or_dpr NE 'PR' THEN BEGIN
   IF (haveDm+haveNw+haveD0+haveGR_Nw) NE 4 THEN $
      message, "Missing a mandatory Dm, D0, or Nw field, quitting."
ENDIF

; stuff the flags, structs, and data arrays into structures to pass along
; - at this point, they will all be copies of the originals and we can
;   butcher them as we please

haveIt = { have_gvrr : have_gvrr, $
           haveHID : haveHID, $
           haveDm : haveDm, $
           haveNw : haveNw, $
           haveD0 : haveD0, $
           haveGR_Nw : haveGR_Nw, $
           haveZdr : haveZdr, $
           haveKdp : haveKdp, $
           haveRHOhv : haveRHOhv, $
           have_pia : have_pia, $
           have_nearsurfrain : havenearsurfrain, $
           have_mrms : havemrms, $
           have_swerr1 : haveswerr1, $
           have_GR_blockage : have_GR_blockage }

dataStruc = { haveFlags : haveIt, $
              mygeometa : mygeometa, $
              mysite : mysite, $
              mysweeps : mysweeps, $
              gvz : gvz, $
              zraw : zraw, $
              zcor : zcor, $
              rain3 : rain3, $
              dpr_dm : dpr_Dm, $
              dpr_nw : dpr_nw, $
              gvrr : gvrr, $
              rr_field_used : rr_field_used, $
              Dzero : Dzero, $          ; data variable
              GR_DM_D0 : GR_DM_D0, $    ; UF ID of Dzero
              gr_dp_nw : gr_dp_nw, $    ; data variable
              GR_NW_N2 : GR_NW_N2, $    ; UF ID of gr_dp_nw
; TAB 10/3/17
              nearsurfrain : nearsurfrain, $ 
              mrmsrr : mrmsrr, $ 
              HIDcat : HIDcat, $
; TAB 9/4/18
              swerr1 : swerr1, $ 
              Zdr : Zdr, $
              Kdp : Kdp, $
              RHOhv : RHOhv, $
              GR_blockage : GR_blockage, $
              top : top, $
              botm : botm, $
              lat : lat, $
              lon : lon, $
              pia : pia, $
              rnflag : rnflag, $
              rntype : rntype, $
              landOcean : landOcean, $
              pr_index : pr_index, $
              xcorner : xcorner, $
              ycorner : ycorner, $
              bbProx : bbProx, $
              dist : dist, $
              hgtcat : hgtcat, $
              pctgoodpr : pctgoodpr, $
              pctgoodgv : pctgoodgv, $
              pctgoodrain : pctgoodrain, $
              pctgoodrrgv : pctgoodrrgv, $
              pctgoodDprDm : pctgoodDprDm, $
              pctgoodDprNw : pctgoodDprNw, $
              clutterStatus : clutterStatus, $
              BBparms : BBparms, $
              heights : heights, $
              hgtinterval : hgtinterval, $
              is_subset : 0, $
              DATESTAMP : yymmdd, $
              orbit : orbit, $
              version : version, $
              KuKa : KuKa, $
              swath : swath }

; - - - - - - - - - - - - - - - - - - - - - - -

IF N_ELEMENTS(submeth) EQ 1 THEN BEGIN
  ; check that we have the necessary DSD fields present before attempting to
  ; subset variables in the save_by_ray mode
   IF save_by_ray THEN BEGIN
      IF (haveD0+haveGR_Nw+haveDm+haveNw) NE 4 THEN BEGIN
         message, "Missing Dm and/or Nw for DPR and/or GR, "+ $
                  "cannot subset and save.", /INFO
         status=1
         GOTO, errorExit
      ENDIF
   ENDIF
  ; define I/O parameter to hold indices of samples used in DSD stats computations
  ; in case user decides to print their values to a text file
   IF ( N_ELEMENTS(save_dir) EQ 1 ) THEN idx_used = -1
  ; start a loop to allow one or more subset areas to be selected by user
   more_cowbell = 'M'
   WHILE STRTRIM(STRUPCASE(more_cowbell),2) EQ 'M' DO BEGIN
     ; bring up the PPI location selector and cut out the area of interest
     ; - writes PPI images to Window #1
      dataStrucCopy = dataStruc  ; don't know why original gets hosed below
     ; set the field to use in case of threshold-by-value
      IF xxx EQ 'RR' THEN rr_or_z = 'RR' ELSE rr_or_z = 'Z'
      ; TODO
      ; TAB 9/4/18, currently this does not do anything with MRMS and/or SWERR variables
      ; need to implement
      dataStrucTrimmed = select_geomatch_subarea_mrms( hide_rntype, pr_or_dpr, $
                                                  startelev, dataStrucCopy, $
                                                  SUBSET_METHOD=submeth, $
                                                  RR_OR_Z=rr_or_z, $
                                                  RANGE_MAX=subthresh )

      IF size(dataStrucTrimmed, /TYPE) NE 8 THEN BEGIN
        ; set up to go to another case rather than to automatically quit, as
        ; user may just have right-clicked to skip storm selection. In these
        ; situations select_geomatch_subarea_mrms() should already have closed the
        ; PPI location window
         status = 0
         message, "Unable to run statistics for storm area, skipping case.",/info
         more_cowbell = 'q'
         ;wdelete, 1         ; should have already been done
         have_window1 = 0
      ENDIF ELSE BEGIN
         have_window1 = 1

         IF xxx EQ 'DSD' THEN BEGIN
            status = render_dsd_plots( looprate, elevs2show, startelev, $
                                PPIorient, windowsize, pctabvthresh, PPIbyThresh, $
                                Z_PPIs, gvconvective, gvstratiform, hideTotals, $
                                hide_rntype, hidePPIs, pr_or_dpr, dataStrucTrimmed, $
                                PS_DIR=ps_dir, B_W=b_w, S2KU=s2ku, ZR=zr_force, $
                                DZEROFAC=dzerofac, MAX_BLOCKAGE=max_blockage, $
                                Z_BLOCKAGE_THRESH=z_blockage_thresh, $
                                GR_RR_FIELD=gr_rr_field, BATCH=batch, $
                                MAX_RANGE=max_range, SUBSET_METHOD=submeth, $
                                MIN_FOR_SUBSET=subthresh, SAVE_DIR=save_dir, $
                                STEP_MANUAL=step_manual, DECLUTTER=declutter, $
                                IDX_USED=idx_used, LAND_OCEAN=land_ocean )
         ENDIF ELSE BEGIN
            status = render_rr_or_z_plots_mrms( xxx, looprate, elevs2show, startelev, $
                                PPIorient, windowsize, pctabvthresh, PPIbyThresh, $
                                gvconvective, gvstratiform, hideTotals, $
                                hide_rntype, hidePPIs, pr_or_dpr, dataStrucTrimmed, $
                                PS_DIR=ps_dir, B_W=b_w, S2KU=s2ku, ZR=zr_force, $
                                BATCH=batch, MAX_RANGE=max_range, $
                                MAX_BLOCKAGE=max_blockage, LAND_OCEAN=land_ocean, $
                                Z_BLOCKAGE_THRESH=z_blockage_thresh, $
                                STEP_MANUAL=step_manual, DECLUTTER=declutter )
         ENDELSE

         IF status EQ 0 THEN BEGIN
            wdelete, 1
            have_window1 = 0
            saveIt=0
            IF ( N_ELEMENTS(save_dir) EQ 1 ) THEN BEGIN
               doodah = ""
               PRINT, STRING(7B)  ; ring the terminal bell
               IF save_by_ray THEN BEGIN
                  usertxt = 'Get 2AKu profile and save variables to file?  Enter Y or N : '
               ENDIF ELSE BEGIN
                  usertxt = 'Save subset variables to file?  Enter Y or N : '
               ENDELSE
               WHILE (doodah NE 'Y' AND doodah NE 'N') DO BEGIN
                  READ, doodah, PROMPT=usertxt
                  doodah = STRTRIM(STRUPCASE(doodah),2)
                  CASE doodah OF
                    'Y' : saveIt=1
                    'N' : saveIt=0
                   ELSE : BEGIN
                            PRINT, STRING(7B)
                            PRINT, "Illegal response, enter Y or N."
                          END
                  ENDCASE
               ENDWHILE
            ENDIF

            IF ( saveIt ) THEN BEGIN
              ; set up IDL SAVE file path/name
               IF ( s2ku ) THEN add2nm = '_S2Ku' ELSE add2nm = ''
               IF datastrucTrimmed.is_subset THEN BEGIN
                 ; format the storm lat/lon position into a string to be added to the PS name
                  IF datastrucTrimmed.storm_lat LT 0.0 THEN hemi='S' ELSE hemi='N'
                  IF datastrucTrimmed.storm_lon LT 0.0 THEN ew='W' ELSE ew='E'
                  addpos='_'+STRING(ABS(datastrucTrimmed.storm_lat),FORMAT='(f0.2)')+hemi+'_'+ $
                         STRING(ABS(datastrucTrimmed.storm_lon),FORMAT='(f0.2)')+ew
                  add2nm = add2nm+addpos
               ENDIF
               SAVFILE = save_dir+'/'+site+'.'+yymmdd+'.'+orbit+"."+version+'.'+pr_or_dpr $
                        +instrument+'_'+swath+'.Pct'+pctString+add2nm+'_'+xxx+'.sav'

              ; Decide which variables to save.  By default, save those for the subset
              ; area analysis as originally designed.  If SAVE_BY_RAY is set, then get
              ; and save those variables requested by the 2BDPRGMI algorithm team at
              ; the single ray selected by the user

               IF save_by_ray THEN BEGIN
                 ; let user find the matching 2A-Ku file for this case and extract
                 ; the 250-m averaged reflectivity profile and the storm top height
                  dataKu = get_2aku_matching_footprint( datastrucTrimmed.storm_lat, $
                                             datastrucTrimmed.storm_lon, yymmdd, $
                                             orbit, version, STARTDIR=startdir )
                 ; JUST SAVE RETURNED STRUCT FOR NOW (TESTING),
                 ; ADD OTHER VARIABLES NEEDED BY 2BCMB DEVELOPERS LATER
                  IF size(dataKu, /TYPE) NE 8 THEN BEGIN
                     print, "No 2AKu file processed, skip saving subset variables to file."
                  ENDIF ELSE BEGIN
                     save_special_2a2b, datastrucTrimmed, dataKu, SAVFILE
                  ENDELSE
               ENDIF ELSE BEGIN
                  SAVE, ncfilepr, xxx, looprate, elevs2show, startelev, PPIorient, windowsize, $
                     pctabvthresh, PPIbyThresh, Z_PPIs, gvconvective, gvstratiform, hideTotals, $
                     hide_rntype, hidePPIs, pr_or_dpr, datastrucTrimmed, FILE=SAVFILE
               ENDELSE
               print, "Data saved to ", SAVFILE

              ; ask whether to save data in delimited text file unless doing
              ; SAVE_BY_RAY or analyzing anything but DSD (only applies to DSD)
               saveTxt=0
               IF save_by_ray OR xxx NE 'DSD' THEN BEGIN
                  doodah = "N"   ; disable prompt/read from terminal, set no-save
               ENDIF ELSE BEGIN
                  doodah = ""
                  PRINT, STRING(7B)  ; ring the terminal bell
               ENDELSE
               WHILE (doodah NE 'Y' AND doodah NE 'N') DO BEGIN
                  READ, doodah, PROMPT='Print subset variables to text file?  Enter Y or N : '
                  doodah = STRTRIM(STRUPCASE(doodah),2)
                  CASE doodah OF
                    'Y' : saveTxt=1
                    'N' : saveTxt=0
                   ELSE : BEGIN
                            PRINT, STRING(7B)   ; ring the bell
                            PRINT, "Illegal response, enter Y or N."
                          END
                  ENDCASE
               ENDWHILE
               IF ( saveTxt ) THEN BEGIN
                 ; set up text file path/name
                  TXTFILE = save_dir+'/'+site+'.'+yymmdd+'.'+orbit+"."+version+'.'+pr_or_dpr $
                           +instrument+'_'+swath+'.Pct'+pctString+add2nm+'_DSD_'+xxx+'.txt'
                  write_subset_to_text, TXTFILE, datastrucTrimmed, idx_used
               ENDIF
            ENDIF
            PRINT, '' & PRINT, STRING(7B)   ; ring the bell
            PRINT, 'Hit Return to select a different case, enter Q to quit, or'                  
            READ, more_cowbell, PROMPT='enter M to do More storm subsets for this case: '
            IF STRUPCASE(more_cowbell) EQ 'Q' THEN status=2    ; set up to exit
         ENDIF ELSE BEGIN
           ; got non-zero status from render_dsd_plots(), set up to exit WHILE loop
            IF status EQ 2 THEN BEGIN
              ; user selected "Q" to Quit in render_rr_or_z/dsd_plots()
               more_cowbell = 'q'
            ENDIF ELSE BEGIN
               PRINT, '' & PRINT, STRING(7B)   ; ring the bell
               PRINT, 'Hit Return to select a different case, enter Q to quit, or'                  
               READ, more_cowbell, PROMPT='enter M to do More storm subsets for this case: '
               IF STRUPCASE(more_cowbell) EQ 'Q' THEN status=2    ; set up to exit
            ENDELSE
         ENDELSE
      ENDELSE  ; case of user clicked to do valid subset selection
   ENDWHILE
   IF have_window1 THEN wdelete, 1
ENDIF ELSE BEGIN
   ; call the routine to produce the graphics and output, just doing entire area
   IF xxx EQ 'DSD' THEN BEGIN
      status = render_dsd_plots( looprate, elevs2show, startelev, $
                                 PPIorient, windowsize, pctabvthresh, PPIbyThresh, $
                                 Z_PPIs, gvconvective, gvstratiform, hideTotals, $
                                 hide_rntype, hidePPIs, pr_or_dpr, dataStruc, $
                                 PS_DIR=ps_dir, B_W=b_w, S2KU=s2ku, ZR=zr_force, $
                                 DZEROFAC=dzerofac, MAX_BLOCKAGE=max_blockage, $
                                 LAND_OCEAN=land_ocean, $
                                 Z_BLOCKAGE_THRESH=z_blockage_thresh, $
                                 GR_RR_FIELD=gr_rr_field, BATCH=batch, $
                                 MAX_RANGE=max_range, SUBSET_METHOD=submeth, $
                                 MIN_FOR_SUBSET=subthresh, SAVE_DIR=save_dir, $
                                 STEP_MANUAL=step_manual, DECLUTTER=declutter, $
                                 IDX_USED=idx_used )
   ENDIF ELSE BEGIN
      status = render_rr_or_z_plots_mrms( xxx, looprate, elevs2show, startelev, $
                                     PPIorient, windowsize, pctabvthresh, PPIbyThresh, $
                                     gvconvective, gvstratiform, hideTotals, hide_rntype, $
                                     hidePPIs, pr_or_dpr, dataStruc, PS_DIR=ps_dir, $
                                     B_W=b_w, S2KU=s2ku, ZR=zr_force, BATCH=batch, $
                                     MAX_RANGE=max_range, MAX_BLOCKAGE=max_blockage, $
                                     LAND_OCEAN=land_ocean, $
                                     Z_BLOCKAGE_THRESH=z_blockage_thresh, $
                                     STEP_MANUAL=step_manual, DECLUTTER=declutter )
   ENDELSE
ENDELSE

; - - - - - - - - - - - - - - - - - - - - - - -

errorExit:

return, status
end

;===============================================================================
;
; MODULE 1:  geo_match_3d_comparisons
;
; DESCRIPTION
; -----------
; Driver for the geo_match_plots_prep function (included).  Sets up user/default
; parameters defining the plots and animations, and the method by which the next
; case is selected: either prompt the user to select the file, or just take the
; next one in the sequence.
;
; PARAMETERS
; ----------
; analysis_type - indicates which type of data variables to be analyzed: Z (for
;                 reflectivity, 'RR' (for rain rate), or 'DSD' (DSD paramaters).
;
; matchup_type - indicates which satellite radar is to be the source of the
;                matchup data to be analyzed.  Allowable values are 'DPR'
;                and 'DPRGMI' or 'CMB'.  Default='DPR'.  If a mismatch occurs
;                between MATCHUP_TYPE and the type of matchup file selected for
;                processing then an error occurs.  In the case of DPR, the
;                matchup to GR can be for any of the 2AKa, 2AKu, or 2ADPR
;                products, for any swath type.  'CMB' is an alias for 'DPRGMI'.
;
; looprate     - initial animation rate for the PPI animation loop on startup.
;                Defaults to 3 if unspecified or outside of allowed 0-100 range
;
; elevs2show   - number of PPIs to display in the PPI image animation, starting
;                at a specifed elevation angle in the volume, in the form 'N.s',
;                where N is the number of PPIs to show, and s is the starting
;                sweep (1-based, where 1 = first). Disables PPI plot if N <= 0,
;                static plot if N = 1. Defaults to N=7.1 if unspecified.  If s
;                is zero or if only N is specified, then s = 1.
;
; ncpath       - local directory path to the geo_match netCDF files' location.
;                Defaults to /data/netcdf/geo_match
;
; sitefilter   - file pattern which acts as the filter limiting the set of input
;                files showing up in the file selector or over which the program
;                will iterate, depending on the select mode parameter. Default=*
;
; ncfilelist   - complete pathname to a text file listing complete pathnames of
;                the matchup files to be processed.  If specified, then
;                ncpath and sitefilter will be ignored, and the behavior will be
;                as if no_prompt is set to on, i.e., the procedure will
;                automatically process each listed file in sequence.  The files
;                in the listing must be compatible with the matchup_type value
;
; no_prompt    - method by which the next file in the set of files defined by
;                ncpath and sitefilter is selected. Binary parameter. If unset,
;                defaults to DialogPickfile()
;
; ppi_vertical - controls orientation for PPI plot/animation subpanels. Binary 
;                parameter. If unset, or if SHOW_THRESH_PPI is On, then defaults
;                to horizontal (PR PPI to left of GR PPI).  If set, then PR PPI
;                is plotted above the GR PPI
;
; ppi_size     - size in pixels of each subpanel in PPI plot.  Default=375
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
; DPR_Z_ADJUST   - Optional parameter.  Bias offset to be applied (added to) the
;                  DPR reflectivity values to account for the calibration offset
;                  between the DPR and ground radars in a global sense (same for
;                  all GR sites).  Positive (negative) value raises (lowers) the
;                  non-missing DPR reflectivity values.
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
; max_blockage_in - Maximum fractional GR beam blockage to allow in samples to
;                   be included in the mean difference calculations.  If value
;                   is between 0.0 and 1.0 it is treated as the fraction of
;                   blockage.  If value is greater than 1 and <= 100, it is
;                   treated as percent blockage and is converted to a fractional
;                   amount.  Disables beam blockage checking if not specified,
;                   if resulting fractional amount is 1.0 (100%), or if matchup
;                   file does not contain the GR_blockage variable.
;
; z_blockage_thresh_in - optional parameter to limit samples included in the
;                        comparisons by beam blockage, as implied by a Z dropoff
;                        between the second and first sweeps.  Is ignored in the
;                        presence of valid MAX_BLOCKAGE value AND presence of
;                        GR_blockage data.
;
; show_thresh_ppi - Binary parameter, controls whether to create and display a
;                   2nd set of PPIs plotting only those PR and GR points meeting
;                   the pctAbvThresh constraint.  If set to On, then ppi_vertical
;                   defaults to horizontal (PR on left, GR on right)
;
; z_only_ppi    - Binary parameter, if set then only reflectivity PPIs are shown
;
; gv_convective - GR reflectivity threshold at/above which GR data are considered
;                 to be of Convective Rain Type.  Default = 35.0 if not specified.
;                 If set to <= 0, then GR reflectivity is ignored in evaluating
;                 whether PR-indicated Stratiform Rain Type matches GR type.
;
; gv_stratiform - GR reflectivity threshold at/below which GR data are considered
;                 to be of Stratiform Rain Type.  Default = 25.0 if not specified.
;                 If set to <= 0, then GR reflectivity is ignored in evaluating
;                 whether PR-indicated Convective Rain Type matches GR type.
;
; alt_bb_hgt    - Manually-specified Bright Band Height (km) to be used if the
;                 bright band height cannot be determined from the DPR data.
;
; forcebb       - Binary parameter, controls whether to override the bright band
;                 height from the satellite radar with the value supplied by the
;                 alt_bb_hgt parameter.
;
; hide_totals   - Binary parameter, controls whether to show (default) or hide
;                 the PDF and profile plots for rain type = "Any".
;
; hide_rntype   - (Optional) binary parameter, indicates whether to suppress
;                 hatching in the PPI plots indicating the PR rain type
;                 identified for the given ray.  Default=show hatching
;
; hide_ppis     - Binary parameter, controls whether to show (default) or hide
;                 the PPI plots/animations.
;
; ps_dir        - Directory to which postscript output will be written.  If not
;                 specified, output is directed only to the screen.
;
; b_w           - Binary parameter, controls whether to plot PDFs in Postscript
;                 file in color (default) or in black-and-white.
;
; batch         - Binary parameter, controls whether to plot anything to display
;                 in Postscript mode.
;
; s2ku          - Binary parameter, controls whether or not to apply the Liao/
;                 Meneghini S-band to Ku-band adjustment to GR reflectivity.
;                 Default = no
;
; use_zr        - Binary parameter, controls whether or not to override the gvrr
;                 (GR rain rate) field in the geo-match netCDF file with a Z-R
;                 derived rain rate
;
; dzero_adj     - Bias adjustment to apply to the GR Dzero field to match it to
;                 the DPR Dm field.  Suggested value is 1.05.  Ignored if DM
;                 field is being used as the GR source for Dm.
;
; gr_rr_field_in - UF field ID of the GR rain rate estimate source to be used:
;                  RC (Cifelli), RP (PolZR), or RR (DROPS, default). Ignored if
;                  USE_ZR parameter is set.
;
; gr_dm_field_in - UF field ID of the GR Dm source to use: D0 or DM (default)
;
; gr_nw_field_in - UF field ID of the GR Nw source to use: N2 or NW (default)
;
; recall_ncpath - Binary parameter.  If set, assigns the last file path used to
;                 select a file in dialog_pickfile() to a user-defined system
;                 variable that stays in effect for the IDL session.  Also, if
;                 set and if the user variable exists from a previous selection,
;                 then the user variable will override the NCPATH parameter
;                 value on program startup.
;
; subset_method - Method to use to select subset areas from the matchup data:
;                 'D' = select an area within a cutoff distance (defined by the
;                       'min_for_subset' parameter) from a user-selected point.
;                 'V' = select an area of contiguous data values around the
;                       user-selected start location that are at/above the
;                       'min_for_subset' value.  The data value to be
;                       thresholded is defined by the 'analysis_type' parameter,
;                       and the threshold applies to the highest data value
;                       in the vertical column along the PR/DPR ray (e.g., to
;                       the composite reflectivity).  If either the PR/DPR or
;                       the matching ground radar value exceeds the threshold,
;                       then the data for that ray will be included in the
;                       subset area.
;                  If subset_method is unspecified then the analysis will be
;                  performed over the entire domain of the matchup dataset.
;
; min_for_subset - Threshold value to be used to define points to be included
;                  in a user-selected subset area.  If subset_method is 'D',
;                  then min_for_subset is a distance in km, with a default
;                  value of 20 km.  If subset_method is 'V', then the
;                  parameter units and its default value are defined by the
;                  analysis_type in effect.  This parameter is ignored if no
;                  value is specified for subset_method.
;
; save_by_ray    - Optional binary parameter.  If set, then overrides values of
;                  both subset_method and min_for_subset such that the user is
;                  prompted to select a subset area, and a subset area of only
;                  one footprint (one DPR ray) is selected when the user clicks
;                  on a location.  Sets subset_method='D' and min_for_subset=3.
;                  KEYWORD ONLY APPLIES WHEN MATCHUP_TYPE='DPRGMI', IS IGNORED
;                  FOR OTHER MATCHUP_TYPE SETTINGS.
;
; save_dir       - Optional directory specification to which the subsetted
;                  variables in a structure will be saved in an IDL SAVE file
;                  if the user chooses to save them.
;
; step_manual   - Flag and Rate value to toggle and control the alternative
;                 method of animation of PPI images.  If unset, animation is
;                 automated in an XINTERANIMATE window (default, legacy
;                 behavior).  If set to a non-zero value, then the PPI images
;                 will be stepped through under user control: either one at a
;                 time in forward or reverse, or in an automatic forward
;                 sequence where the pause, in seconds, between frames is
;                 defined by the step_manual value.  The automated sequence
;                 will only play one time in the latter mode, starting from
;                 the currently-displayed frame.
;
; declutter     - (Optional) binary parameter, if set to ON, then read and use
;                 the clutterStatus variable to filter out clutter-flagged
;                 volume match samples, regardless of pctAbvThresh status.
; land_ocean_in - (Optional) STRING parameter, limits the samples included in
;                 the analysis to those with a single underlying surface type.
;                 Allowable values are 'L' (Land), 'O' (Ocean), 'C' (Coast), 
;                 'I' (Inland Water), or 'A' (Any - disables filtering).

pro geo_match_3d_comparisons_mrms, ANALYSIS_TYPE=analysis_type, $
                              MATCHUP_TYPE=matchup_type, $
                              SWATH_CMB=swath_cmb, $
                              KUKA_CMB=KuKa_cmb, $
                              SPEED=looprate, $
                              ELEVS2SHOW=elevs2show, $
                              NCPATH=ncpath, $
                              SITE=sitefilter, $
                              NCFILELIST=ncfilelist, $
                              NO_PROMPT=no_prompt, $
                              PPI_VERTICAL=ppi_vertical, $
                              PPI_SIZE=ppi_size, $
                              PCT_ABV_THRESH=pctAbvThresh, $
                              DPR_Z_ADJUST=dpr_z_adjust_in, $
                              GR_Z_ADJUST=gr_z_adjust, $
                              MAX_RANGE=max_range_in, $
                              MAX_BLOCKAGE=max_blockage_in, $
                              Z_BLOCKAGE_THRESH=z_blockage_thresh_in, $
                              SHOW_THRESH_PPI=show_thresh_ppi, $
                              Z_ONLY_PPI=z_only_ppi, $
                              GV_CONVECTIVE=gv_convective, $
                              GV_STRATIFORM=gv_stratiform, $
                              ALT_BB_HGT=alt_bb_hgt, $
                              FORCEBB=forcebb, $
                              HIDE_TOTALS=hide_totals, $
                              HIDE_RNTYPE=hide_rntype, $
                              HIDE_PPIS=hide_ppis, $
                              PS_DIR=ps_dir, $
                              B_W=b_w, $
                              BATCH=batch, $
                              S2KU = s2ku, $
                              USE_ZR = use_zr, $
                              DZERO_ADJ = dzero_adj, $
                              GR_RR_FIELD=gr_rr_field_in, $
                              GR_DM_FIELD=gr_dm_field_in, $
                              GR_NW_FIELD=gr_nw_field_in, $
                              RECALL_NCPATH=recall_ncpath, $
                              SUBSET_METHOD=subset_method, $
                              MIN_FOR_SUBSET=min_for_subset, $
                              SAVE_DIR=save_dir, $
                              SAVE_BY_RAY=save_by_ray_in, $
                              STEP_MANUAL=step_manual, $
                              DECLUTTER=declutter, $
                              LAND_OCEAN=land_ocean_in


IF ( N_ELEMENTS(matchup_type) NE 1 ) THEN BEGIN
   print, "Defaulting to DPR for matchup_type type."
   pr_or_dpr = 'DPR'
ENDIF ELSE BEGIN
   CASE STRUPCASE(matchup_type) OF
      'PR' : pr_or_dpr = 'PR'
     'DPR' : pr_or_dpr = 'DPR'
     'CMB' : pr_or_dpr = 'DPRGMI'
  'DPRGMI' : pr_or_dpr = 'DPRGMI'
      ELSE : message, "Only allowed values for MATCHUP_TYPE are PR, DPR, and CMB or DPRGMI"
   ENDCASE
ENDELSE

; determine whether to compute Z, Rainrate, or DSD statistics
IF ( N_ELEMENTS(analysis_type) NE 1 ) THEN BEGIN
   print, "Defaulting to Z for comparison element."
   xxx = 'Z'
ENDIF ELSE BEGIN
   CASE STRUPCASE(analysis_type) OF
       'Z' : xxx = 'Z'
      'RR' : xxx = 'RR'
     'DSD' : xxx = 'DSD'
      ELSE : message, "Only allowed values for ANALYSIS_TYPE are Z, RR, or DSD"
   ENDCASE
ENDELSE

IF xxx EQ 'DSD' AND pr_or_dpr EQ 'PR' THEN BEGIN
   print, ''
   message, "ANALYSIS_TYPE 'DSD' not valid for MATCHUP_TYPE 'PR'."
ENDIF
; need to rethink the save_by_ray "special constraint by matchup type"
save_by_ray = 0    ; enabled only if analyzing DPRGMI and SAVE_BY_RAY is set

IF pr_or_dpr EQ 'DPRGMI' THEN BEGIN
   save_by_ray = KEYWORD_SET(save_by_ray_in)
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
ENDIF ELSE BEGIN
   IF KEYWORD_SET(save_by_ray_in) THEN print, "Ignoring SAVE_BY_RAY setting for ", $
                                              pr_or_dpr, " matchup type."
ENDELSE

;save_by_ray = 1  ; for testing

; override or initialize subset_method and subthresh if SAVE_BY_RAY is set
IF save_by_ray THEN BEGIN
   submeth = 'D'
   subthresh = 3.0  ; try to grab just one footprint
ENDIF ELSE BEGIN
   IF N_ELEMENTS( subset_method ) EQ 1 THEN BEGIN
      CASE STRUPCASE(subset_method) OF
       'D' : BEGIN
               submeth = 'D'
               IF N_ELEMENTS(min_for_subset) NE 1 THEN BEGIN
                  print, "Setting a default subset area radius of 20km"
                  subthresh = 20.
               ENDIF ELSE subthresh = min_for_subset
             END
       'V' : BEGIN
               submeth = 'V'
               IF N_ELEMENTS(min_for_subset) NE 1 THEN BEGIN
                  CASE xxx OF
                   'RR' : BEGIN
                            print, "Setting a default subset threshold of 1 mm/h"
                            subthresh = 1.
                          END
                   ELSE : BEGIN
                            print, "Setting a default subset threshold of 30 dBZ"
                            subthresh = 30.
                          END
                  ENDCASE
               ENDIF ELSE subthresh = min_for_subset
             END
        '' : BREAK   ; silently ignore empty string
      ELSE : message, "Only allowed values for SUBSET_METHOD are D "+ $
                      "(distance) and V (value)"
      ENDCASE
   ENDIF
ENDELSE

IF N_ELEMENTS(submeth) EQ 1 AND N_ELEMENTS(save_dir) EQ 1 THEN BEGIN
  ; check for existence of save_dir, if not empty string
   IF save_dir NE '' THEN BEGIN
      IF FILE_TEST(save_dir, /DIRECTORY) THEN real_save_dir = save_dir $
      ELSE MESSAGE, "SAVE_DIR directory "+save_dir+ $
                     " does not exist, disabling SAVE files.", /INFO
   ENDIF
ENDIF

; set up the loop speed for xinteranimate, 0<= speed <= 100
IF ( N_ELEMENTS(looprate) EQ 1 ) THEN BEGIN
  IF ( looprate LT 0 OR looprate GT 100 ) THEN looprate = 3
ENDIF ELSE BEGIN
   looprate = 3
ENDELSE

; set up the starting and max # of sweeps to show in animation loop
IF ( N_ELEMENTS(elevs2show) NE 1 ) THEN BEGIN
   print, "Defaulting to 7 for the number of PPI levels to plot, ", $
          "starting with the first."
   elevs2show = 7
   startelev = 0
ENDIF ELSE BEGIN
   IF ( elevs2show LE 0 ) THEN BEGIN
      print, "Disabling PPI animation plot, ELEVS2SHOW <= 0"
      elevs2show = 0
      startelev = 0
   ENDIF ELSE BEGIN
     ; determine whether an INT or a FLOAT was specified
      e2sType = SIZE( elevs2show, /TYPE )
      CASE e2sType OF
        2 : startelev = 0          ; an integer elevs2show was input
        4 : BEGIN                  ; a FLOAT elevs2show was input
              etemp = elevs2show+.00001   ; make temp copy
              elevs2show = FIX( etemp )   ; extract the whole part as elevs2show
             ; extract the tenths part as the starting sweep number
              startelev = ( FIX( (etemp - elevs2show)*10.0 ) - 1 ) > 0
            END
      ENDCASE
      print, "PPIs to plot = ", elevs2show, ", Starting sweep = ", startelev + 1
   ENDELSE
ENDELSE

print, ""
DEFSYSV, '!LAST_NCPATH', EXISTS = haveUserVar
IF KEYWORD_SET(recall_ncpath) AND (haveUserVar EQ 1) THEN BEGIN
   print, "Defaulting to last selected directory for file path:"
   print, !LAST_NCPATH
   print, ""
   pathpr = !LAST_NCPATH
ENDIF ELSE BEGIN
   IF ( N_ELEMENTS(ncpath) NE 1 ) THEN BEGIN
      print, "Defaulting to /data/gpmgv/netcdf/geo_match for file path."
      pathpr = '/data/gpmgv/netcdf/geo_match'
   ENDIF ELSE pathpr = ncpath
ENDELSE

IF ( N_ELEMENTS(sitefilter) NE 1 ) THEN BEGIN
   print, "Defaulting to * for file pattern."
   ncfilepatt = '*'
ENDIF ELSE ncfilepatt = '*'+sitefilter+'*'

PPIorient = keyword_set(ppi_vertical)
PPIbyThresh = keyword_set(show_thresh_ppi)
Z_PPIs = keyword_set(z_only_ppi)
;RR_PPI = keyword_set(ppi_is_rr)
hideTotals = keyword_set(hide_totals)
hideRntype = keyword_set(hide_rntype)
hidePPIs = keyword_set(hide_ppis)
b_w = keyword_set(b_w)
do_batch = keyword_set(batch)
s2ku = keyword_set(s2ku)
zr_force = keyword_set(use_zr)

IF ( N_ELEMENTS(ppi_size) NE 1 ) THEN BEGIN
   print, "Defaulting to 375 for PPI size."
   ppi_size = 375
ENDIF

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

; configure bias adjustment for GR and/or DPR

IF N_ELEMENTS( gr_z_adjust ) EQ 1 THEN BEGIN
   IF FILE_TEST( gr_z_adjust ) THEN BEGIN
     ; read the site bias file and store site IDs and biases in a HASH variable
      site_bias_hash_status = site_bias_hash_from_file( gr_z_adjust )
      IF TYPENAME(site_bias_hash_status) EQ 'HASH' THEN BEGIN
        ; define passed parameter, undefine returned value
         siteBiasHash = TEMPORARY(site_bias_hash_status)
      ENDIF ELSE BEGIN
         print, "Problems with GR_Z_ADJUST file: ", gr_z_adjust
         entry = ''
         WHILE STRUPCASE(entry) NE 'C' AND STRUPCASE(entry) NE 'Q' DO BEGIN
            read, entry, PROMPT="Enter C to continue without GR site bias adjustment " $
                   + "or Q to exit here: "
            CASE STRUPCASE(entry) OF
                'C' : BEGIN
                        break
                      END
                'Q' : GOTO, earlyExit
               ELSE : print, "Invalid response, enter C or Q."
            ENDCASE
         ENDWHILE  
      ENDELSE       
   ENDIF ELSE message, "File '"+gr_z_adjust+"' for GR_Z_ADJUST not found."
ENDIF

IF N_ELEMENTS( dpr_z_adjust_in) EQ 1 THEN BEGIN
   IF is_a_number( dpr_z_adjust_in ) THEN BEGIN
      dpr_z_adjustF = FLOAT( dpr_z_adjust_in )  ; in case of STRING entry
      IF dpr_z_adjustF GE -3.0 AND dpr_z_adjustF LE 3.0 THEN BEGIN
         dpr_z_adjust = dpr_z_adjustF  ; define passed parameter
       ENDIF ELSE BEGIN
         message, "DPR_Z_ADJUST value must be between -3.0 and 3.0 (dBZ)"
      ENDELSE
   ENDIF ELSE message, "DPR_Z_ADJUST value is not a number."
ENDIF


IF N_ELEMENTS(max_blockage_in) EQ 1 THEN BEGIN
   IF is_a_number(max_blockage_in) THEN BEGIN
      IF max_blockage_in LT 0 OR max_blockage_in GT 100 THEN BEGIN
         message, "Illegal MAX_BLOCKAGE value, must be between 0 and 100."
      ENDIF ELSE BEGIN
         IF max_blockage_in GT 1 THEN BEGIN
            max_blockage = max_blockage_in/100.
            print, "Converted MAX_BLOCKAGE percent to fractional amount: ", $
                   STRING(max_blockage, FORMAT='(F0.2)')
         ENDIF ELSE max_blockage = FLOAT(max_blockage_in)
      ENDELSE
    ENDIF ELSE BEGIN
         message, "Illegal MAX_BLOCKAGE, must be a number between 0 and 100."
    ENDELSE
ENDIF

IF N_ELEMENTS(z_blockage_thresh_in) EQ 1 THEN BEGIN
   IF is_a_number(z_blockage_thresh_in) THEN BEGIN
      z_blockage_f = FLOAT(z_blockage_thresh_in)
      IF z_blockage_f LT 0.5 OR z_blockage_f GT 3.0 THEN BEGIN
         help, z_blockage_thresh_in
         message, "Out of range Z_BLOCKAGE_THRESH value, " + $
                  "must be between 0.5 and 3.0 (dBZ)"
      ENDIF ELSE z_blockage_thresh = z_blockage_f
   ENDIF ELSE BEGIN
      help, z_blockage_thresh_in
      message, "Illegal Z_BLOCKAGE_THRESH type, " + $
               "must be a number between 0.5 and 3.0"
   ENDELSE
ENDIF

; Set up filtering by underlying surface type.  Convert textual type into an
; integer category that matches the original 2A landSurfaceType values that
; are reduced to a 1-digit value: 0=Ocean, 1=Land, 2=Coast, 3=Inland_Water

IF N_ELEMENTS(land_ocean_in) NE 0 THEN BEGIN
  ; check that we have a string
   IF SIZE( land_ocean_in, /TYPE ) EQ 7 THEN BEGIN
     ; grab the first character of the parameter value
      CASE STRUPCASE( STRMID(land_ocean_in, 0, 1) ) OF
         'A' : print, "Accepting any Land Surface Type."
         'C' : land_ocean = 2
         'I' : land_ocean = 3
         'L' : land_ocean = 1
         'O' : land_ocean = 0
        ELSE : message, "Illegal LAND_OCEAN value, must be either 'L' (Land), " $
                        +"'O' (Ocean), 'C' (Coast), 'I' (Inland Water), or 'A' (Any)."
      ENDCASE
   ENDIF ELSE message, "Illegal LAND_OCEAN type, must be STRING value 'L' (Land), " $
                        +"'O' (Ocean), 'C' (Coast), 'I' (Inland Water), or 'A' (Any)."
ENDIF

; Set up for the PR-GR rain type matching based on GR reflectivity

IF ( N_ELEMENTS(gv_Convective) NE 1 ) THEN BEGIN
   print, "Disabling GR Convective floor threshold."
   gvConvective = 0.0
ENDIF ELSE BEGIN
   gvConvective = FLOAT(gv_Convective)
ENDELSE

IF ( N_ELEMENTS(gv_Stratiform) NE 1 ) THEN BEGIN
   print, "Disabling GR Stratiform ceiling threshold."
   gvStratiform = 0.0
ENDIF ELSE BEGIN
   gvStratiform = FLOAT(gv_Stratiform)
ENDELSE

; set up the Dzero adjustment, if valid factor is provided
IF ( N_ELEMENTS(dzero_adj) EQ 1 ) THEN BEGIN
   IF dzero_adj GE 0.9 AND dzero_adj LE 1.1 THEN BEGIN
      dzerofac = dzero_adj
   ENDIF ELSE BEGIN
      print, ""
      print, "Out of range value for dzero_adj: ", dzero_adj
      print, "Must lie between 0.9 and 1.1, leaving GR Dzero unmodified."
      print, ""
   ENDELSE
ENDIF

; set up for Postscript vs. On-Screen output
IF ( N_ELEMENTS( ps_dir ) NE 1 || ps_dir EQ "" ) THEN BEGIN
   print, "Defaulting to screen output for scatter plot."
   ps_dir = ''
ENDIF ELSE BEGIN
   mydirstruc = FILE_INFO( ps_dir )
   IF (mydirstruc.directory) THEN print, "Postscript files will be written to: ", ps_dir $
   ELSE BEGIN
      MESSAGE, "Directory "+ps_dir+" specified for PS_DIR does not exist, exiting."
   ENDELSE
ENDELSE

IF zr_force EQ 0 THEN BEGIN
   IF N_ELEMENTS( gr_rr_field_in ) EQ 1 THEN BEGIN
      CASE gr_rr_field_in OF
         'RC' : gr_rr_field = gr_rr_field_in
         'RP' : gr_rr_field = gr_rr_field_in
         'RR' : gr_rr_field = gr_rr_field_in
         ELSE : BEGIN
                print, "Illegal value for GR_RR_FIELD: ", gr_rr_field_in, $
                       ", allowed values are RC, RP, and RR only."
                print, " - Setting GR_RR_FIELD value to RR (for DROPS)."
                gr_rr_field = 'RR'
                END
      ENDCASE
      IF pr_or_dpr EQ 'PR' AND gr_rr_field NE 'RR' THEN BEGIN
         print, gr_rr_field + " rain rate field not supported for " + pr_or_dpr
         print, " - Setting GR_RR_FIELD value to RR (for DROPS)."
         gr_rr_field = 'RR'
      ENDIF
   ENDIF ELSE BEGIN
      print, "No value supplied for GR_RR_FIELD, and not using Z-R rainrate."
      print, "Setting GR_RR_FIELD value to RR (for DROPS)."
      gr_rr_field = 'RR'
   ENDELSE
ENDIF

; check D0/Dm and Nw/N2 parameter configurations against matchup_type
; -- let child process deal with selection vs. matchup version

;IF pr_or_dpr EQ 'DPR' THEN BEGIN
   IF N_ELEMENTS( gr_dm_field_in ) EQ 1 THEN BEGIN
      CASE STRUPCASE(gr_dm_field_in) OF
         'D0' : gr_dm_field = STRUPCASE(gr_dm_field_in)
         'DM' : gr_dm_field = STRUPCASE(gr_dm_field_in)
         ELSE : BEGIN
                print, "Illegal value for GR_DM_FIELD: ", gr_dm_field_in, $
                       ", allowed values are D0 and DM only."
                print, " - Setting GR_DM_FIELD value to DM."
                gr_dm_field = 'DM'
                END
      ENDCASE
   ENDIF ELSE BEGIN
      print, "No value supplied for GR_DM_FIELD, setting value to DM."
      gr_dm_field = 'DM'
   ENDELSE

   IF N_ELEMENTS( gr_nw_field_in ) EQ 1 THEN BEGIN
      CASE STRUPCASE(gr_nw_field_in) OF
         'NW' : gr_nw_field = STRUPCASE(gr_nw_field_in)
         'N2' : gr_nw_field = STRUPCASE(gr_nw_field_in)
         ELSE : BEGIN
                print, "Illegal value for GR_NW_FIELD: ", gr_nw_field_in, $
                       ", allowed values are NW and N2 only."
                print, " - Setting GR_NW_FIELD value to NW."
                gr_nw_field = 'NW'
                END
      ENDCASE
   ENDIF ELSE BEGIN
      print, "No value supplied for GR_NW_FIELD, setting value to NW."
      gr_nw_field = 'NW'
   ENDELSE
;ENDIF ELSE BEGIN
;   IF gr_dm_field_in NE 'D0' THEN BEGIN
;      print, gr_dm_field_in + " D0/Dm field not supported for " + pr_or_dpr
;      print, " - Setting GR_DM_FIELD value to D0."
;   ENDIF
;   gr_dm_field = 'D0'

;   IF gr_nw_field_in NE 'NW' THEN BEGIN
;      print, gr_nw_field_in + " Nw field not supported for " + pr_or_dpr
;      print, " - Setting GR_NW_FIELD value to NW."
;   ENDIF
;   gr_nw_field = 'NW'
;ENDELSE

; specify whether to skip graphical PPI output to screen in Postscript mode
IF ( PS_DIR NE '' AND KEYWORD_SET(batch) ) THEN do_batch=1 ELSE do_batch=0

; Figure out how the next file to process will be obtained.  If no_prompt is
; set, or if ncfilelist is provided and has one or more entries, then we will
; automatically loop over the file sequence.  Otherwise we will prompt the
; user for the next file with dialog_pickfile() (DEFAULT).

IF N_ELEMENTS(ncfilelist) EQ 1 THEN BEGIN
   IF FILE_TEST(ncfilelist) EQ 1 THEN BEGIN
     ; find out how many files are listed in the file 'ncfilelist'
      nf = FILE_LINES(ncfilelist)
      IF (nf LE 0) THEN BEGIN
         print, "" 
         message, "No entries in ncfilelist: " + ncfilelist, /INFO
         print, " -- Exiting."
         GOTO, earlyExit
      ENDIF ELSE BEGIN
         no_prompt = 1
         haveList = 1
      ENDELSE
   ENDIF ELSE BEGIN
      print, "" 
      message, "NCFILELIST file does not exist: " + ncfilelist, /INFO
      print, " -- Exiting."
      GOTO, earlyExit
   ENDELSE
ENDIF ELSE BEGIN
   no_prompt = keyword_set(no_prompt)
   haveList = 0
ENDELSE

IF (no_prompt) THEN BEGIN
   IF haveList EQ 1 THEN BEGIN
     ; read the listing file to get the file pathnames to be processed
      prfiles = STRARR(nf)
      OPENR, ncunit, ncfilelist, ERROR=err, /GET_LUN
      ; initialize the variables into which file records are read as strings
      dataPR = ''
      ncnum=0
      WHILE NOT (EOF(ncunit)) DO BEGIN 
        ; get GRtoPR filename
         READF, ncunit, dataPR
         ncfull = STRTRIM(dataPR,2)
         IF FILE_TEST(ncfull, /REGULAR) THEN BEGIN
            prfiles[ncnum] = ncfull
            ncnum++
         ENDIF ELSE message, "File "+ncfull+" does not exist!", /INFO
      ENDWHILE  ; each matchup file to process in control file
      CLOSE, ncunit
      nf = ncnum
      IF (nf LE 0) THEN BEGIN
         print, "" 
         message, "No files listed in "+ncfilelist+" were found.", /INFO
         print, " -- Exiting."
         GOTO, earlyExit
      ENDIF
;   IF STREGEX(prfiles[0], '.6.') EQ -1 THEN verstr='_v7' ELSE verstr='_v6'
   ENDIF ELSE BEGIN
     ; search for files meeting the path/name criteria
      prfiles = file_search(pathpr, ncfilepatt, COUNT=nf)
      IF (nf LE 0) THEN BEGIN
         print, "" 
         print, "No files found for pattern = ", pathpr
         print, " -- Exiting."
         GOTO, earlyExit
      ENDIF
   ENDELSE

   IF ( do_batch ) THEN BEGIN
      print, ''
      print, 'Processing all cases in Postscript batch mode.'
      print, ''
   ENDIF
   for fnum = 0, nf-1 do begin
      IF NOT ( do_batch ) THEN BEGIN
        ; set up for bailout prompt every 5 cases if no_prompt
         doodah = ""
         IF ( ((fnum+1) MOD 5) EQ 0 AND no_prompt ) THEN BEGIN $
             READ, doodah, $
             PROMPT='Hit Return to do next 5 cases, Q to Quit, D to Disable this bail-out option: '
             IF doodah EQ 'Q' OR doodah EQ 'q' THEN break
             IF doodah EQ 'D' OR doodah EQ 'd' THEN no_prompt=0   ; never ask again
         ENDIF
      ENDIF
     ;
      ncfilepr = prfiles(fnum)
      action = 0
      action = geo_match_plots_prep( ncfilepr, xxx, looprate, elevs2show, startelev, $
                                     PPIorient, ppi_size, pctAbvThresh, PPIbyThresh, $
                                     DPR_Z_ADJUST=dpr_z_adjust, SITEBIASHASH=siteBiasHash, $
                                     Z_PPIs, gvconvective, gvstratiform, hideTotals, $
                                     hideRntype, hidePPIs, pr_or_dpr, $
                                     ALT_BB_HGT=alt_bb_hgt, FORCEBB=forcebb, $
                                     PS_DIR=ps_dir, B_W=b_w, S2KU=s2ku, ZR=zr_force, $
                                     DZEROFAC=dzerofac, GR_RR_FIELD=gr_rr_field, $
                                     GR_DM_FIELD=gr_dm_field, GR_NW_FIELD=gr_nw_field, $
                                     BATCH=do_batch, MAX_RANGE=max_range_in, $
                                     MAX_BLOCKAGE=max_blockage, $
                                     Z_BLOCKAGE_THRESH=z_blockage_thresh, $
                                     SUBSET_METHOD=submeth, MIN_FOR_SUBSET=subthresh, $
                                     SAVE_DIR=real_save_dir, SAVE_BY_RAY=save_by_ray, $
                                     STEP_MANUAL=step_manual, SWATH=swath, KUKA=KuKa, $
                                     DECLUTTER=declutter, LAND_OCEAN=land_ocean )

      if (action EQ 2) then break
   endfor
ENDIF ELSE BEGIN
   ncfilepr = dialog_pickfile(path=pathpr, filter = ncfilepatt)
   while ncfilepr ne '' do begin
      action = 0
      action=geo_match_plots_prep( ncfilepr, xxx, looprate, elevs2show, startelev, $
                                   PPIorient, ppi_size, pctAbvThresh, PPIbyThresh, $
                                   DPR_Z_ADJUST=dpr_z_adjust, SITEBIASHASH=siteBiasHash, $
                                   Z_PPIs, gvconvective, gvstratiform, hideTotals, $
                                   hideRntype, hidePPIs, pr_or_dpr, $
                                   ALT_BB_HGT=alt_bb_hgt, FORCEBB=forcebb, $
                                   PS_DIR=ps_dir, B_W=b_w, S2KU=s2ku, ZR=zr_force, $
                                   DZEROFAC=dzerofac, GR_RR_FIELD=gr_rr_field, $
                                   GR_DM_FIELD=gr_dm_field, GR_NW_FIELD=gr_nw_field, $
                                   BATCH=do_batch, MAX_RANGE=max_range_in, $
                                   MAX_BLOCKAGE=max_blockage, $
                                   Z_BLOCKAGE_THRESH=z_blockage_thresh, $
                                   SUBSET_METHOD=submeth, MIN_FOR_SUBSET=subthresh, $
                                   SAVE_DIR=real_save_dir, SAVE_BY_RAY=save_by_ray, $
                                   STEP_MANUAL=step_manual, SWATH=swath, KUKA=KuKa, $
                                   DECLUTTER=declutter, LAND_OCEAN=land_ocean )
      if (action EQ 2) then break
      newpathpr = FILE_DIRNAME(ncfilepr)  ; set the path to the last file's path
      IF KEYWORD_SET(recall_ncpath) THEN BEGIN
         ; define/assign new default path for session as user system variable
          IF (haveUserVar EQ 1) THEN !LAST_NCPATH = newpathpr $
          ELSE DEFSYSV, '!LAST_NCPATH', newpathpr
      ENDIF
      ncfilepr = dialog_pickfile(path=newpathpr, filter = ncfilepatt)
   endwhile
ENDELSE

earlyExit:
print, "" & print, "Done!"
END
