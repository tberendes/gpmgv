;===============================================================================
;+
; Copyright © 2016, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; save_special_2a2b.pro
; - Morris/SAIC/GPM_GV  December 2016
;
; DESCRIPTION
; -----------
; Creates an IDL "SAVE" file containing a fixed set of variables taken from a
; GRtoDPRGMI volume-match file and the matching 2A-Ku data file.  Spatial
; variables in the structures input to this procedure are expected to have been
; subsetted by the calling routine along a single DPR ray that a user has
; selected, but this procedure does not test or enforce that rule.  The SAVE
; file is intended to support the 2BDPRGMI algorithm developers, and is not for
; general use in data viewing and routine analysis.
;
; PARAMETERS
; ----------
; data2Bmatchup - Structure containing subsetted variables along a single DPR
;                 ray extracted from a GRtoDPRGMI matchup file.
;
; dataKu        - Structure containing subsetted variables along a single DPR
;                 ray extracted from the 2A-Ku file matching the GRtoDPRGMI
;                 orbit and PPS version.
;
; savfile       - IDL binary SAVE file to which selected variables pulled from
;                 the data2Bmatchup and dataKu structures will be saved.
;
; HISTORY
; -------
; 12/16/16 Morris, GPM GV, SAIC
; - Created.
;
; EMAIL QUESTIONS OR COMMENTS AT:
;       https://pmm.nasa.gov/contact
;-
;===============================================================================


pro save_special_2a2b, data2Bmatchup, dataKu, savfile

; extract the variables to be saved to the binary SAVE file and give them
; explicit names for the 2BCMB team to analyze

; get the variables extracted/derived from the matching 2AKu file
ray_2aku = dataKu.ray_2aku
scan_2aku = dataKu.scan_2aku
latitude_2aku = dataKu.latitude_2aku
longitude_2aku = dataKu.longitude_2aku
file_2aku = dataKu.file_2aku
stormTop_2aku = dataKu.stormTop2AKu
Zmeas250_2aku = dataKu.Zmeas250
maxZmeas250_2aku = dataKu.maxZmeas250
binClutterFree250_2aku = dataKu.binClutterFree250
Zmeas125_2aku = dataKu.Zmeas125
binClutterFree125_2aku = dataKu.binClutterFree2AKu
scanAngle_2aku = dataKu.scanAngle_2aku

; get the variables from the GR-2BCMB matchup file
; - eliminate degenerate leading dimension of size 1
gr_z_volmatch2b = REFORM(data2Bmatchup.gvz)
cmb_z_volmatch2b = REFORM(data2Bmatchup.zcor)
cmb_z_pctabvthresh_volmatch2b = REFORM(data2Bmatchup.pctgoodpr)
cmb_z_threshold = data2Bmatchup.mygeometa.DPR_DBZ_MIN
gr_z_pctabvthresh_volmatch2b = REFORM(data2Bmatchup.pctgoodgv)
gr_z_threshold = data2Bmatchup.mygeometa.GR_DBZ_MIN
gr_dm_volmatch2b = REFORM(data2Bmatchup.Dzero)
gr_dm_type = data2Bmatchup.GR_DM_D0
cmb_dm_volmatch2b = REFORM(data2Bmatchup.dpr_dm)
gr_nw_volmatch2b = REFORM(data2Bmatchup.gr_dp_nw)
gr_nw_type = data2Bmatchup.GR_NW_N2
cmb_nw_volmatch2b = REFORM(data2Bmatchup.dpr_nw)
raintype_volmatch2b = REFORM(data2Bmatchup.rntype)
bb_proximity_volmatch2b = REFORM(data2Bmatchup.bbProx)
top_hgt_volmatch2b = REFORM(data2Bmatchup.top)
bottom_hgt_volmatch2b = REFORM(data2Bmatchup.botm)
cmb_rainrate_volmatch2b = REFORM(data2Bmatchup.rain3)
gr_rainrate_volmatch2b = REFORM(data2Bmatchup.gvrr)
gr_rainrate_type = data2Bmatchup.rr_field_used
site_elev_km = data2Bmatchup.mysite.site_elev

message, "Saving 2B volume match and 2AKu variables to file "+savfile, /INFO
SAVE, FILE=savfile, $
      ray_2aku, $
      scan_2aku, $
      latitude_2aku, $
      longitude_2aku, $
      file_2aku, $
      stormTop_2aku, $
      Zmeas250_2aku, $
      maxZmeas250_2aku, $
      binClutterFree250_2aku, $
      Zmeas125_2aku, $
      binClutterFree125_2aku, $
      scanAngle_2aku, $
      gr_z_volmatch2b, $
      cmb_z_volmatch2b, $
      cmb_z_pctabvthresh_volmatch2b, $
      cmb_z_threshold, $
      gr_z_pctabvthresh_volmatch2b, $
      gr_z_threshold, $
      gr_dm_volmatch2b, $
      gr_dm_type, $
      cmb_dm_volmatch2b, $
      gr_nw_volmatch2b, $
      gr_nw_type, $
      cmb_nw_volmatch2b, $
      raintype_volmatch2b, $
      bb_proximity_volmatch2b, $
      top_hgt_volmatch2b, $
      bottom_hgt_volmatch2b, $
      cmb_rainrate_volmatch2b, $
      gr_rainrate_volmatch2b, $
      gr_rainrate_type, $
      site_elev_km

end
