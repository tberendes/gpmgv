pro nsig_v2_define_structs

; Define structures for SIGMET Version 2 Raw Product.
;
; These structures were adapted from RSL's nsig.h written by John Merrit of
; SM&A Corp.

nsig_struct_head = {NSIG_Structure_header, $
  id:0, $
  version:0, $
  num_bytes:0L, $
  spare:0, $
  flags:0  $
} ; NSIG_Structure_header

nsig_ymds_time = {NSIG_Ymds_time, $
  sec_of_day:0L, $  ; seconds since midnight
  msec:0U,       $  ; milliseconds
  year:0,  $
  month:0, $
  day:0    $
} ; NSIG_Ymds_time

nsig_ray_hdr = {nsig_ray_header, $
  begin_azm:0U,    $ ; azimuth at beginning of ray
  begin_elev:0U,   $ ; elevation at beginning of ray
  end_azm:0U,      $ ; azimuth at end of ray
  end_elev:0U,     $ ; elevation at end of ray
  actual_nbins:0, $ ; actual number of bins in ray
  sec:0U          $ ; seconds since start of sweep
} ; nsig_ray_header

color_scale_def = {NSIG_Color_scale_def, $
  iflags:0L, $
  istart:0L, $
  istep:0L,  $
  icolcnt:0, $
  ipalette_num:0, $
  ilevel_seams:intarr(16) $
} ; NSIG_Color_scale_def

prod_config = {NSIG_Product_config, $
   st_head:{NSIG_Structure_header }, $
   prod_code:0, $
   isch:0, $
   isch_skip:0L, $
   prod_time:{NSIG_Ymds_time}, $
   file_time:{NSIG_Ymds_time}, $
   schd_time:{NSIG_Ymds_time}, $
   schd_code:0, $
   sec_skip:0L, $
   user_name:bytarr(12), $
   task_name:bytarr(12), $
   flag:0, $
   ixscale:0L, $
   iyscale:0L, $
   izscale:0L, $
   x_size:0L, $
   y_size:0L, $
   z_size:0L, $
   x_loc:0L,  $
   y_loc:0L,  $
   z_loc:0L,  $
   max_rng:0L, $
  irange_last_v20:0L, $
  ipad128x2:bytarr(2), $
  idata_out:0, $
  ipad132x12:bytarr(12), $
  idata_in:0, $
  ipad146x2:bytarr(2), $
  iradial_smooth:0, $
  iruns:0, $
  izr_const:0L, $
  izr_exp:0L, $
  ix_smooth:0, $
  iy_smooth:0, $
  psi:bytarr(80), $
  ipad244x28:bytarr(28), $
  colors:{NSIG_Color_scale_def} $
} ; NSIG_Product_config


nsig_prod_end = {NSIG_Product_end, $
  sprod_sitename:bytarr(16), $
  sprod_version:bytarr(8), $
  sing_version:bytarr(8), $
  data_time:{NSIG_Ymds_time}, $
  ipad44x46:bytarr(42), $
  site_name:bytarr(16), $
  ahead_gms:0, $
  lat:0L, $
  lon:0L, $
  grnd_sea_ht:0, $
  rad_grnd_ht:0, $
  prf:0L, $
  pulse_wd:0L, $
  sig_proc:0, $
  trg_rate:0, $
  num_samp:0, $
  clutter_file:bytarr(12), $
  num_filter:0, $
  wavelen:0L, $
  trunc_ht:0L, $
  rng_f_bin:0L, $
  rng_l_bin:0L, $
  num_bin:0L, $
  flag:0, $
  file_up:0, $
  label:bytarr(16,4), $
  ilog_filter_first:0, $
  ipad238x10:bytarr(10), $
  prod_seq:0, $
  color_num:intarr(16), $
  color_reject:0b, $
 ipad283x2:bytarr(3), $
  iresults_count:0, $
  ipad_end:bytarr(20) $
} ; NSIG_Product_end

nsig_ingest_summary = {NSIG_Ingest_summary, $
  file_name:bytarr(80), $
  num_file:0, $
    isweeps_done :0, $
  sum_size:0L, $
  start_time:{NSIG_Ymds_time}, $
  ipad100x12:bytarr(12), $
  size_ray_headers:0, $
  size_ext_ray_headers:0, $
 ib_task:0, $
  ipad_118x6:bytarr(6), $
  siris_version:bytarr(8), $
  ipad_132x18:bytarr(18), $
  site_name:bytarr(16), $
  time_zone:0, $
  lat_rad:0L, $
  lon_rad:0L, $
  grd_height:0, $
  ant_height:0, $
  azm_res:0, $
  ray_ind:0, $
  num_rays:0, $
  ant_alt:0L, $
  vel:lonarr(3), $
  ant_offset:lonarr(3), $
  spare2:bytarr(264) $
} ; NSIG_Ingest_summary

nsig_task_sched_info = {NSIG_Task_sched_info, $
  startt:0L, $
  stopt:0L, $
  skipt:0L, $
  time_last:0L, $
  time_used:0L, $
  day_last:0L, $
  iflag:0, $
  spare:bytarr(94) $
} ; NSIG_Task_sched_info

nsig_dsp_data_mask = {NSIG_dsp_data_mask, $ 
  mask_word_0:0UL, $ ; These contain bits set for data types recorded
  ext_hdr_type:0UL, $
  mask_word_1:0UL, $
  mask_word_2:0UL, $
  mask_word_3:0UL, $
  mask_word_4:0UL  $
}

nsig_task_dsp_mode = {NSIG_task_dsp_mode, $
  low_prf:0U, $ ; Hertz
  low_prf_frac:0U, $ ; Fraction part, scaled by 2**-16
  low_prf_sample_size:0, $
  low_prf_range_averaging:0, $ ; in bins
  thresh_refl_unfolding:0, $ ; Threshold for reflectivity unfolding in 1/100 dB
  thresh_vel_unfolding:0, $ ; Threshold for velocity unfolding in 1/100 dB
  thresh_sw_unfolding:0, $ ; Threshold for width unfolding in 1/100 dB
  spare:intarr(9) $
}

nsig_task_dsp_info = {NSIG_Task_dsp_info, $
  major_mode:0U, $
  dsp_type:0UL, $ ; (The length for this was wrong in manual, given as UINT2)
  data_mask_cur:{NSIG_dsp_data_mask}, $
  data_mask_orig:{NSIG_dsp_data_mask}, $
  task_dsp_mode:{NSIG_task_dsp_mode}, $
  spare:intarr(26), $
  prf:0L, $ ; Hertz
  pulse_width:0L, $ ; 1/100 microseconds
  prf_mode:0U, $
  dual_prf_delay:0, $
  agc_code:0U, $
  samp_size:0, $
  gain_con_flag:0U, $
  filter_name:bytarr(12), $
  idop_filter_first:0b, $
  ilog_filter_first:0b, $
  atten_gain:0, $
  igas_atten :0U, $
  clutter_map_flag:0U, $
  xmt_phase_seq:0U, $
  mask_confine_ray_hdr:0UL, $
  time_series_playback:0U, $
  spare1:0, $
  custom_ray_hdr_name:bytarr(16), $
  spare2:intarr(60) $
} ; NSIG_Task_dsp_info


nsig_task_calib_info = {NSIG_Task_calib_info, $
  slope:0, $
  noise:0, $
  clutr_corr:0, $
  sqi:0, $
  power:0, $
  spare1:bytarr(8), $
  cal_ref:0, $
  z_flag_unc:0, $
  z_flag_cor:0, $
  v_flag:0, $
  w_flag:0, $
  spare2:bytarr(8), $
  speckle:0, $
  slope_2:0, $
  cal_ref_2:0, $
  zdr_bias:0, $
  spare3:bytarr(276) $
} ; NSIG_Task_calib_info


nsig_task_range_info = {NSIG_Task_range_info, $
  rng_first:0L, $
  rng_last:0L, $
  ibin_last:0L, $
  num_bins:0, $
  num_rngbins:0, $
  var_bin_spacing:0, $
  binstep_in:0L, $
  binstep_out:0L, $
  bin_avg_flag:0, $
  spare:bytarr(132) $
} ; NSIG_Task_range_info


NSIG_Task_scan_info = {NSIG_Task_scan_info, $
  ant_scan_mode:0, $
  ang_res:0, $
 iscan_speed :0, $
  num_swp:0, $
  beg_ang:0, $
  end_ang:0, $
  list:intarr(40), $
  spare2:bytarr(116) $
} ; NSIG_Task_scan_info


NSIG_Task_misc_info = {NSIG_Task_misc_info, $
  wavelength:0L, $
  serial_num:bytarr(16), $
  xmit_pwr:0L, $
  flag:0, $
  ipolar:0, $
  itrunc:0L, $
  ipad32x18:bytarr(18), $
  display_parm1:0, $
  display_parm2:0, $
  product_flag:0, $
  spare2:bytarr(2), $
  truncation_height:0L, $
  nbytes_comments:0, $
  spare3:bytarr(256) $
} ; NSIG_Task_misc_info

NSIG_Task_end_data = {NSIG_Task_end_data, $
  major:0, $
  minor:0, $
  name:bytarr(12), $
  desc:bytarr(80), $
  ihybrid_count:0L, $
  state:0, $
 spare:bytarr(218) $
} ; NSIG_Task_end_data


nsig_task_config = {NSIG_Task_config, $
  struct_head:{NSIG_Structure_header}, $
  sched_info:{NSIG_Task_sched_info}, $
  dsp_info:{NSIG_Task_dsp_info}, $
  calib_info:{NSIG_Task_calib_info}, $
  range_info:{NSIG_Task_range_info}, $
  scan_info:{NSIG_Task_scan_info}, $
  misc_info:{NSIG_Task_misc_info}, $
  end_data:{NSIG_Task_end_data}, $
  comments:bytarr(720) $
} ; NSIG_Task_config

NSIG_One_device = {NSIG_One_device, $
  status:0L, $
  process:0L, $
  nuser_name:bytarr(16), $
  nchar:0b, $
  imode:0L, $
  spare:bytarr(8) $
} ; NSIG_One_device

NSIG_Device_status = {NSIG_Device_status, $
  struct_head:{NSIG_Structure_header}, $
  dsp_stat:replicate(NSIG_One_device,4), $
  ant_stat:replicate(NSIG_One_device,4), $
  outdev_stat:replicate(NSIG_One_device,12), $
  spare:bytarr(120) $
} ; NSIG_Device_status

NSIG_Rpv5_gparam = {NSIG_Rpv5_gparam, $
  revision:0, $
  num_bins:0, $
  cur_trig_p:0, $
  cur_tag1:0, $
  cur_tag2:0, $
  l_chan_noise:0, $
  i_chan_noise:0, $
  q_chan_noise:0, $
  lat_proc_status:0, $
  imm_proc_status:0, $
  diag_reg_a:0, $
  diag_reg_b:0, $
  num_pulses:0, $
  trig_c_low:0, $
  trig_c_high:0, $
  num_acq_bins:0, $
  num_pro_bins:0, $
  rng_off:0, $
  noise_rng:0, $
  noise_trg:0, $
  pulse_w_0:0, $
  pulse_w_1:0, $
  pulse_w_2:0, $
  pulse_w_3:0, $
  pulse_w_pat:0, $
  cur_wave_pw:0, $
  cur_trig_gen:0, $
  des_trig_gen:0, $
  prt_start:0, $
  prt_end:0, $
  proc_thr_flag:0, $
  log_con_slope:0, $
  log_noise_thr:0, $
  clu_cor_thr:0, $
  sqi_thr:0, $
  log_thr_w:0, $
  cal_ref:0, $
  q_i_cur_samp:0, $
  l_cur_samp:0, $
  rng_avr_cho:0, $
  spare1:intarr(3), $
  i_sqr_low:0, $
  i_sqr_high:0, $
  q_sqr_low:0, $
  q_sqr_high:0, $
  noise_mean:0, $
  noise_std:0, $
  spare2:intarr(15) $
} ; NSIG_Rpv5_gparam

NSIG_Gparam = {NSIG_Gparam, $
  struct_head:{NSIG_Structure_header}, $
  rpv5:{NSIG_Rpv5_gparam} $
} ; NSIG_Gparam

NSIG_Ingest_data_header = {NSIG_Ingest_data_header, $
  struct_head:{NSIG_Structure_header}, $
  time:{NSIG_Ymds_time}, $
  sweep_num:0, $
  num_rays_swp:0, $
  ind_ray_one:0, $
  num_rays_exp:0, $
  num_rays_act:0, $
  fix_ang:0, $
  bits_bin:0, $
  data_type:0, $
  spare:bytarr(36) $
} ; NSIG_Ingest_data_header
 
NSIG_Raw_prod_bhdr = {NSIG_Raw_prod_bhdr, $
  rec_num:0, $
  sweep_num:0, $
  ray_loc:0, $
  ray_num:0, $
  flags:0, $
  spare:0  $
} ; NSIG_Raw_prod_bhdr

nsig_record1 = {NSIG_Record1, $
    struct_head:{NSIG_Structure_header}, $
    prod_config:{NSIG_Product_config}, $
    prod_end:{NSIG_Product_end}, $
    spare:bytarr(5504) $
} ; NSIG_Record1

nsig_record2 = {NSIG_Record2, $
  struct_head:{NSIG_Structure_header},  $
  ingest_head:{NSIG_Ingest_summary}, $
  task_config:{NSIG_Task_config}, $
  device_stat:{NSIG_Device_status}, $
  dsp1:{NSIG_Gparam}, $
  dsp2:{NSIG_Gparam}, $
  spare:bytarr(2000)  $
} ; NSIG_Record2

end
