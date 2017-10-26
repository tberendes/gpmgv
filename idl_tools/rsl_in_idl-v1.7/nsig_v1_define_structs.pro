pro nsig_v1_define_structs

; Define structures for SIGMET Version 1 Raw Product.
;
; These structures were adapted from RSL's nsig.h written by John Merrit of
; SM&A Corp.

NSIG_Structure_header = {NSIG_Structure_header, $
  id:0, $
  num_bytes:0L, $
  version:0, $
  spare:0, $
  flags:0 $
} ; NSIG_Structure_header

NSIG_Ymds_time = {NSIG_Ymds_time, $
  year:0, $
  month:0, $
  day:0, $
  sec:0L $
} ; NSIG_Ymds_time

nsig_ray_hdr = {nsig_ray_header, $
  begin_azm:0,  $ ; azimuth at beginning of ray
  begin_elev:0, $ ; elevation . . .
  end_azm:0,    $ ; azimuth at end of ray
  end_elev:0,   $ ; elevation . . .
  actual_nbins:0, $ ; actual number of bins in ray
  sec:0         $ ; seconds since start of sweep
} ; nsig_ray_header

NSIG_Product_end = {NSIG_Product_end, $
  part_name:bytarr(80), $
  data_time:{NSIG_Ymds_time}, $
  site_name:bytarr(16), $
  ahead_gms:0, $
  lat:0L, $
  lon:0L, $
  grnd_sea_ht:0, $
  rad_grnd_ht:0, $
  sig_proc:0, $
  prf:0L, $
  pulse_wd:0L, $
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
  label_unit:bytarr(12), $
  prod_seq:0, $
  color_num:intarr(16), $
  color_reject:0b, $
  color_unscan:0b, $
  color_over:0b, $
  spare:0b, $
  prod_max_rng:0L, $
  spare2:bytarr(18) $
} ; NSIG_Product_end

NSIG_Product_config = {NSIG_Product_config, $
   st_head:{NSIG_Structure_header}, $
   prod_code:0, $
   prod_time:{NSIG_Ymds_time}, $
   file_time:{NSIG_Ymds_time}, $
   schd_time:{NSIG_Ymds_time}, $
   schd_code:0, $
   sec_skip:0L, $
   user_name:bytarr(12), $
   file_name:bytarr(12), $
   task_name:bytarr(12), $
   spare_name:bytarr(12), $
   flag:0, $
   x_size:0L, $
   y_size:0L, $
   z_size:0L, $
   x_loc:0L, $
   y_loc:0L, $
   z_loc:0L, $
   max_rng:0L, $
   bits_item:0, $
   data_type:0, $
   data_start:0L, $
   data_step:0L, $
   num_col:0, $
  spare:bytarr(178) $
} ; NSIG_Product_config

NSIG_Ingest_summary = {NSIG_Ingest_summary, $
  file_name:bytarr(80), $
  num_file:0, $
  sum_size:0L, $
  start_time:{NSIG_Ymds_time}, $
  drive_name:bytarr(16), $
  size_ray_headers:0, $
  size_ext_ray_headers:0, $
  num_task_conf_tab:0, $
  size_device_status_tab:0, $
  gparam_size:0, $
  spare:bytarr(28), $
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
  spare2:bytarr(266) $
} ; NSIG_Ingest_summary

NSIG_Task_sched_info = {NSIG_Task_sched_info, $
  startt:0L, $
  stopt:0L, $
  skipt:0L, $
  time_last:0L, $
  time_used:0L, $
  day_last:0L, $
  iflag:0, $
  spare:bytarr(94) $
} ; NSIG_Task_sched_info

NSIG_Task_dsp_info = {NSIG_Task_dsp_info, $
  dsp_num:0, $
  dsp_type:0, $
  data_mask:0L, $
  aux_data_def:lonarr(32), $
  prf:0L, $
  pwid:0L, $
  prf_mode:0, $
  prf_delay:0, $
  agc_code:0, $
  samp_size:0, $
  gain_con_flag:0, $
  filter_name:bytarr(12), $
  f_num:0, $
  atten_gain:0, $
  spare:bytarr(150) $
} ; NSIG_Task_dsp_info

NSIG_Task_calib_info = {NSIG_Task_calib_info, $
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

NSIG_Task_range_info = {NSIG_Task_range_info, $
  rng_first:0L, $
  rng_last:0L, $
  num_bins:0, $
  num_rngbins:0, $
  var_bin_spacing:0, $
  binstep_in:0L, $
  binstep_out:0L, $
  bin_avg_flag:0, $
  spare:bytarr(136) $
} ; NSIG_Task_range_info

NSIG_Task_scan_info = {NSIG_Task_scan_info, $
  ant_scan_mode:0, $
  ang_res:0, $
  spare1:0, $
  num_swp:0, $
  beg_ang:0, $
  end_ang:0, $
  list:intarr(40), $
  spare3:bytarr(112) $
} ; NSIG_Task_scan_info

NSIG_Task_misc_info = {NSIG_Task_misc_info, $
  wavelength:0L, $
  serial_num:bytarr(16), $
  xmit_pwr:0L, $
  flag:0, $
  spare1:bytarr(24), $
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
  state:0, $
  spare:bytarr(222) $
} ; NSIG_Task_end_data

NSIG_Task_config = {NSIG_Task_config, $
  struct_head:{NSIG_Structure_header}, $
  sched_info:{NSIG_Task_sched_info}, $
  dsp_info:{NSIG_Task_dsp_info}, $
  calib_info:{NSIG_Task_calib_info}, $
  range_info:{NSIG_Task_range_info}, $
  scan_info:{NSIG_Task_scan_info}, $
  misc_info:{NSIG_Task_misc_info}, $
  end_data:{NSIG_Task_end_data} $
} ; NSIG_Task_config

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

NSIG_One_device = {NSIG_One_device, $
  status:0, $
  process:0, $
  user_name:bytarr(15), $
  nchar:0b, $
  spare:bytarr(10) $
} ; NSIG_One_device

NSIG_Device_status = {NSIG_Device_status, $
  struct_head:{NSIG_Structure_header}, $
  dsp_stat:replicate(NSIG_One_device,4), $
  ant_stat:replicate(NSIG_One_device,4), $
  outdev_stat:replicate(NSIG_One_device,12), $
  spare:bytarr(120) $
} ; NSIG_Device_status

NSIG_Ingest_data_header = {NSIG_Ingest_data_header, $
  struct_head:{NSIG_Structure_header}, $
  time:{NSIG_Ymds_time}, $
  data_type:0, $
  sweep_num:0, $
  num_rays_swp:0, $
  ind_ray_one:0, $
  num_rays_exp:0, $
  num_rays_act:0, $
  fix_ang:0, $
  bits_bin:0, $
  spare:bytarr(38)  $
} ; NSIG_Ingest_data_header

NSIG_Raw_prod_bhdr = {NSIG_Raw_prod_bhdr, $
  rec_num:0, $
  sweep_num:0, $
  ray_loc:0, $
  ray_num:0, $
  flags:0, $
  spare:0  $
} ; NSIG_Raw_prod_bhdr

NSIG_Record1 = {NSIG_Record1, $
  struct_head:{NSIG_Structure_header}, $
  prod_config:{NSIG_Product_config}, $
  prod_end:{NSIG_Product_end}, $
  spare:bytarr(5504) $
} ; NSIG_Record1


NSIG_Record2 = {NSIG_Record2, $
  struct_head:{NSIG_Structure_header}, $
  ingest_head:{NSIG_Ingest_summary}, $
  task_config:{NSIG_Task_config}, $
  device_stat:{NSIG_Device_status}, $
  dsp1:{NSIG_Gparam}, $
  dsp2:{NSIG_Gparam}, $
  spare:bytarr(1260) $
} ; NSIG_Record2

end
